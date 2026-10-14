extends RefCounted
## Scientific expression evaluator (recursive-descent parser).
##
## Grammar (lowest to highest precedence):
##   expression := term (("+" | "-") term)*
##   term       := unary (("*" | "/" | "mod" | <implicit>) unary)*
##   unary      := ("+" | "-") unary | power
##   power      := postfix ("^" unary)?          (right associative)
##   postfix    := primary ("!" | "%")*
##   primary    := NUMBER | CONSTANT | FUNCTION "(" args ")" | "(" expression ")"
##   args       := expression (";" expression)*
##
## Display symbols (×, ÷, −, π, φ, √, ∛) are accepted as well as their ASCII
## forms. Missing closing parentheses at the end of the input are tolerated.

enum AngleMode { DEG, RAD }

const ERR_SYNTAX := "ERR_SYNTAX"
const ERR_DIV_ZERO := "ERR_DIV_ZERO"
const ERR_DOMAIN := "ERR_DOMAIN"
const ERR_OVERFLOW := "ERR_OVERFLOW"

## Function name -> number of arguments.
const FUNCTIONS := {
	"sin": 1, "cos": 1, "tan": 1, "asin": 1, "acos": 1, "atan": 1,
	"sinh": 1, "cosh": 1, "tanh": 1, "asinh": 1, "acosh": 1, "atanh": 1,
	"ln": 1, "log": 1, "sqrt": 1, "cbrt": 1, "abs": 1, "exp": 1,
	"floor": 1, "ceil": 1, "round": 1,
	"frac": 2, "root": 2, "logb": 2, "nCr": 2, "nPr": 2, "gcd": 2, "lcm": 2, "randint": 2,
}
const CONSTANTS := ["pi", "phi", "e", "Ans", "rand"]
const EPSILON := 1e-12
const MAX_FACTORIAL := 170
const GOLDEN_RATIO := 1.6180339887498949

var angle_mode: AngleMode = AngleMode.DEG
var last_answer: float = 0.0

var _tokens: Array = []
var _pos: int = 0
var _error: String = ""
var _words: Array = [] # known identifiers, longest first


func _init() -> void:
	_words = FUNCTIONS.keys() + CONSTANTS + ["mod"]
	_words.sort_custom(func(a, b): return a.length() > b.length())


## Evaluates [param text]. Returns { "ok": bool, "value": float, "error": String }.
func evaluate(text: String) -> Dictionary:
	_error = ""
	_pos = 0
	_tokens = _tokenize(text)
	if _error != "":
		return _fail()
	if _tokens.is_empty():
		_error = ERR_SYNTAX
		return _fail()

	var value := _parse_expression()
	if _error == "" and _pos < _tokens.size():
		_error = ERR_SYNTAX
	if _error != "":
		return _fail()
	if is_nan(value) or is_inf(value):
		_error = ERR_OVERFLOW
		return _fail()
	if absf(value) < EPSILON * 1e-3:
		value = 0.0
	return { "ok": true, "value": value, "error": "" }


func _fail() -> Dictionary:
	return { "ok": false, "value": 0.0, "error": _error }


# --- Tokenizer -------------------------------------------------------------

func _tokenize(text: String) -> Array:
	var tokens: Array = []
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == " " or c == " " or c == " ":
			i += 1
		elif c.is_valid_int() or c == "." or c == ",":
			var start := i
			var seen_dot := false
			while i < n and (text[i].is_valid_int() or text[i] == "." or text[i] == ","):
				if text[i] == "." or text[i] == ",":
					if seen_dot:
						_error = ERR_SYNTAX
						return []
					seen_dot = true
				i += 1
			# Scientific notation: 1.5E10, 2E-3
			if i < n and text[i] == "E":
				var j := i + 1
				if j < n and (text[j] == "+" or text[j] == "-" or text[j] == "−"):
					j += 1
				if j < n and text[j].is_valid_int():
					while j < n and text[j].is_valid_int():
						j += 1
					i = j
				else:
					_error = ERR_SYNTAX
					return []
			var literal := text.substr(start, i - start).replace(",", ".").replace("−", "-")
			if literal == ".":
				_error = ERR_SYNTAX
				return []
			tokens.append({ "type": "num", "value": literal.to_float() })
		elif is_letter(c):
			var start := i
			while i < n and is_letter(text[i]):
				i += 1
			# Split a run of letters into known words: "esin" -> e, sin
			var run := text.substr(start, i - start)
			while run != "":
				var word := _longest_word(run)
				if word == "":
					_error = ERR_SYNTAX
					return []
				run = run.substr(word.length())
				if word == "mod":
					tokens.append({ "type": "op", "value": "mod" })
				elif FUNCTIONS.has(word):
					tokens.append({ "type": "func", "value": word })
				else:
					tokens.append({ "type": "const", "value": word })
		else:
			match c:
				"+":
					tokens.append({ "type": "op", "value": "+" })
				"-", "−":
					tokens.append({ "type": "op", "value": "-" })
				"*", "×", "·":
					tokens.append({ "type": "op", "value": "*" })
				"/", "÷":
					tokens.append({ "type": "op", "value": "/" })
				"^":
					tokens.append({ "type": "op", "value": "^" })
				"!":
					tokens.append({ "type": "op", "value": "!" })
				"%":
					tokens.append({ "type": "op", "value": "%" })
				"(":
					tokens.append({ "type": "lparen" })
				")":
					tokens.append({ "type": "rparen" })
				";":
					tokens.append({ "type": "sep" })
				"π":
					tokens.append({ "type": "const", "value": "pi" })
				"φ":
					tokens.append({ "type": "const", "value": "phi" })
				"√":
					tokens.append({ "type": "func", "value": "sqrt" })
				"∛":
					tokens.append({ "type": "func", "value": "cbrt" })
				_:
					_error = ERR_SYNTAX
					return []
			i += 1
	return tokens


func _longest_word(run: String) -> String:
	for word in _words:
		if run.begins_with(word):
			return word
	return ""


static func is_letter(c: String) -> bool:
	var code := c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


# --- Parser ----------------------------------------------------------------

func _peek() -> Dictionary:
	return _tokens[_pos] if _pos < _tokens.size() else {}


func _peek_is(type: String, value = null) -> bool:
	var t := _peek()
	if t.is_empty() or t["type"] != type:
		return false
	return value == null or t.get("value") == value


## A number may follow ")" or a constant implicitly ((2)3, π2), never another number.
func _previous_allows_number() -> bool:
	if _pos == 0:
		return false
	var previous: Dictionary = _tokens[_pos - 1]
	return previous["type"] == "rparen" or previous["type"] == "const"


func _parse_expression() -> float:
	var value := _parse_term()
	while _error == "" and (_peek_is("op", "+") or _peek_is("op", "-")):
		var op: String = _tokens[_pos]["value"]
		_pos += 1
		var rhs := _parse_term()
		value = value + rhs if op == "+" else value - rhs
	return value


func _parse_term() -> float:
	var value := _parse_unary()
	while _error == "":
		var op := ""
		if _peek_is("op", "*") or _peek_is("op", "/") or _peek_is("op", "mod"):
			op = _tokens[_pos]["value"]
			_pos += 1
		elif _peek_is("const") or _peek_is("func") or _peek_is("lparen") or (_peek_is("num") and _previous_allows_number()):
			op = "*" # implicit multiplication: 2π, 3(4+1), 2sin(30), (1+1)2
		else:
			break
		var rhs := _parse_unary()
		if _error != "":
			break
		match op:
			"*":
				value *= rhs
			"/":
				if rhs == 0.0:
					_error = ERR_DIV_ZERO
					return 0.0
				value /= rhs
			"mod":
				if rhs == 0.0:
					_error = ERR_DIV_ZERO
					return 0.0
				value = fposmod(value, rhs) if rhs > 0.0 else -fposmod(-value, -rhs)
	return value


func _parse_unary() -> float:
	if _peek_is("op", "-"):
		_pos += 1
		return -_parse_unary()
	if _peek_is("op", "+"):
		_pos += 1
		return _parse_unary()
	return _parse_power()


func _parse_power() -> float:
	var base := _parse_postfix()
	if _error == "" and _peek_is("op", "^"):
		_pos += 1
		var exponent := _parse_unary()
		if _error != "":
			return 0.0
		return _power(base, exponent)
	return base


func _power(base: float, exponent: float) -> float:
	if base == 0.0 and exponent < 0.0:
		_error = ERR_DIV_ZERO
		return 0.0
	if base < 0.0 and exponent != floorf(exponent):
		# Allow odd roots of negatives, e.g. (-8)^(1/3)
		var inv := 1.0 / exponent
		if absf(inv - roundf(inv)) < 1e-9 and int(roundf(inv)) % 2 != 0:
			return -pow(-base, exponent)
		_error = ERR_DOMAIN
		return 0.0
	return pow(base, exponent)


func _parse_postfix() -> float:
	var value := _parse_primary()
	while _error == "":
		if _peek_is("op", "!"):
			_pos += 1
			value = _factorial(value)
		elif _peek_is("op", "%"):
			_pos += 1
			value /= 100.0
		else:
			break
	return value


func _parse_primary() -> float:
	var t := _peek()
	if t.is_empty():
		_error = ERR_SYNTAX
		return 0.0
	match t["type"]:
		"num":
			_pos += 1
			return t["value"]
		"const":
			_pos += 1
			match t["value"]:
				"pi":
					return PI
				"phi":
					return GOLDEN_RATIO
				"e":
					return exp(1.0)
				"Ans":
					return last_answer
				"rand":
					return randf()
		"lparen":
			_pos += 1
			var inner := _parse_expression()
			_expect_rparen()
			return inner
		"func":
			_pos += 1
			var name: String = t["value"]
			var arity: int = FUNCTIONS[name]
			var args: Array[float] = []
			if _peek_is("lparen"):
				_pos += 1
				args.append(_parse_expression())
				while _error == "" and _peek_is("sep"):
					_pos += 1
					args.append(_parse_expression())
				_expect_rparen()
			elif arity == 1:
				# √9, sin30 : function applied to the next postfix-level operand
				args.append(_parse_postfix())
			if _error != "":
				return 0.0
			if args.size() != arity:
				_error = ERR_SYNTAX
				return 0.0
			return _apply_function(name, args)
	_error = ERR_SYNTAX
	return 0.0


func _expect_rparen() -> void:
	if _error != "":
		return
	if _peek_is("rparen"):
		_pos += 1
	elif _pos < _tokens.size():
		_error = ERR_SYNTAX
	# else: end of input, auto-close the parenthesis


# --- Math ------------------------------------------------------------------

func _to_radians(x: float) -> float:
	return deg_to_rad(x) if angle_mode == AngleMode.DEG else x


func _from_radians(x: float) -> float:
	return rad_to_deg(x) if angle_mode == AngleMode.DEG else x


func _snap(x: float) -> float:
	if absf(x) < EPSILON:
		return 0.0
	if absf(x - roundf(x)) < EPSILON:
		return roundf(x)
	return x


func _domain_error() -> float:
	_error = ERR_DOMAIN
	return 0.0


func _apply_function(name: String, args: Array[float]) -> float:
	var x := args[0]
	match name:
		"sin":
			return _snap(sin(_to_radians(x)))
		"cos":
			return _snap(cos(_to_radians(x)))
		"tan":
			var r := _to_radians(x)
			if absf(_snap(cos(r))) == 0.0:
				return _domain_error()
			return _snap(tan(r))
		"asin":
			return _domain_error() if x < -1.0 or x > 1.0 else _snap(_from_radians(asin(x)))
		"acos":
			return _domain_error() if x < -1.0 or x > 1.0 else _snap(_from_radians(acos(x)))
		"atan":
			return _snap(_from_radians(atan(x)))
		"sinh":
			return sinh(x)
		"cosh":
			return cosh(x)
		"tanh":
			return tanh(x)
		"asinh":
			return log(x + sqrt(x * x + 1.0))
		"acosh":
			return _domain_error() if x < 1.0 else log(x + sqrt(x * x - 1.0))
		"atanh":
			return _domain_error() if x <= -1.0 or x >= 1.0 else 0.5 * log((1.0 + x) / (1.0 - x))
		"ln":
			return _domain_error() if x <= 0.0 else log(x)
		"log":
			return _domain_error() if x <= 0.0 else _snap(log(x) / log(10.0))
		"sqrt":
			return _domain_error() if x < 0.0 else sqrt(x)
		"cbrt":
			var root := pow(absf(x), 1.0 / 3.0)
			return _snap(-root if x < 0.0 else root)
		"abs":
			return absf(x)
		"exp":
			return exp(x)
		"floor":
			return floorf(x)
		"ceil":
			return ceilf(x)
		"round":
			return roundf(x)
		"frac":
			if args[1] == 0.0:
				_error = ERR_DIV_ZERO
				return 0.0
			return x / args[1]
		"root":
			return _nth_root(args[1], x)
		"logb":
			if x <= 0.0 or x == 1.0 or args[1] <= 0.0:
				return _domain_error()
			return _snap(log(args[1]) / log(x))
		"nCr", "nPr":
			return _combinatorics(name, x, args[1])
		"gcd", "lcm":
			if not _is_integer(x) or not _is_integer(args[1]):
				return _domain_error()
			var g := _gcd(absi(int(x)), absi(int(args[1])))
			if name == "gcd":
				return g
			return 0.0 if g == 0 else absf(x * args[1]) / g
		"randint":
			if not _is_integer(x) or not _is_integer(args[1]) or x > args[1]:
				return _domain_error()
			return randi_range(int(x), int(args[1]))
	_error = ERR_SYNTAX
	return 0.0


## n-th root of x (index first, like the ⁿ√x template).
func _nth_root(x: float, n: float) -> float:
	if n == 0.0:
		return _domain_error()
	if x < 0.0:
		if _is_integer(n) and int(n) % 2 != 0:
			return _snap(-pow(-x, 1.0 / n))
		return _domain_error()
	return _snap(pow(x, 1.0 / n))


func _combinatorics(name: String, n: float, r: float) -> float:
	if not _is_integer(n) or not _is_integer(r) or n < 0.0 or r < 0.0 or r > n:
		return _domain_error()
	var k := int(r)
	if name == "nCr":
		k = mini(k, int(n) - k)
	var result := 1.0
	for i in k:
		result *= (n - i)
		if name == "nCr":
			result /= (i + 1)
	return roundf(result)


func _is_integer(x: float) -> bool:
	return x == floorf(x) and absf(x) < 9.0e15


func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


func _factorial(x: float) -> float:
	if x < 0.0 or x != floorf(x):
		return _domain_error()
	if x > MAX_FACTORIAL:
		_error = ERR_OVERFLOW
		return 0.0
	var result := 1.0
	for i in range(2, int(x) + 1):
		result *= i
	return result


# --- Formatting ------------------------------------------------------------

## Formats a number for display (max ~12 significant digits, scientific
## notation for very large/small values). [param decimal_sep] is "." or ",",
## [param group_sep] (optional) separates thousands: "1,234,567.5".
## [param fixed] >= 0 forces that many decimals (precision setting).
static func format_number(value: float, decimal_sep: String = ".", group_sep: String = "", fixed: int = -1) -> String:
	if is_nan(value) or is_inf(value):
		return "—"
	if value == 0.0 and fixed < 0:
		return "0"
	var a := absf(value)
	var text: String
	if a != 0.0 and (a >= 1e15 or (a < 1e-9 and fixed < 0)):
		var exponent := int(floor(log(a) / log(10.0)))
		var mantissa := value / pow(10.0, exponent)
		# Correct rounding drift (e.g. 9.9999999 -> 10)
		if absf(mantissa) >= 10.0:
			mantissa /= 10.0
			exponent += 1
		text = _trim(String.num(mantissa, 10)) + "E" + str(exponent)
	else:
		if fixed >= 0:
			text = ("%." + str(fixed) + "f") % value
			if text.begins_with("-") and text.to_float() == 0.0:
				text = text.substr(1) # no "-0.00"
		else:
			var int_digits := int(floor(log(a) / log(10.0))) + 1
			var decimals := clampi(12 - int_digits, 0, 12)
			text = _trim(String.num(value, decimals))
		if group_sep != "":
			text = _group_thousands(text, group_sep)
	return text.replace(".", decimal_sep)


static func _group_thousands(text: String, group_sep: String) -> String:
	var sign := ""
	if text.begins_with("-"):
		sign = "-"
		text = text.substr(1)
	var parts := text.split(".")
	var int_part: String = parts[0]
	var grouped := ""
	while int_part.length() > 3:
		grouped = group_sep + int_part.right(3) + grouped
		int_part = int_part.left(int_part.length() - 3)
	grouped = int_part + grouped
	return sign + grouped + ("." + parts[1] if parts.size() > 1 else "")


static func _trim(s: String) -> String:
	if s.contains(".") and not s.contains("E"):
		s = s.rstrip("0").rstrip(".")
	return s


## Best rational approximation of [param value] (continued fractions).
## Returns [numerator, denominator] or [] when no exact-looking fraction exists.
static func to_fraction(value: float, max_denominator: int = 100000) -> Array:
	if is_nan(value) or is_inf(value) or value == floorf(value) or absf(value) > 1e12:
		return []
	var sign := -1 if value < 0.0 else 1
	var x := absf(value)
	var h0 := 0
	var h1 := 1
	var k0 := 1
	var k1 := 0
	var rest := x
	for _i in 40:
		var a := int(floorf(rest))
		var h2 := a * h1 + h0
		var k2 := a * k1 + k0
		if k2 > max_denominator:
			break
		h0 = h1
		h1 = h2
		k0 = k1
		k1 = k2
		if absf(float(h1) / k1 - x) <= 5e-13 * maxf(1.0, x):
			return [sign * h1, k1]
		var f := rest - a
		if f < 1e-15:
			break
		rest = 1.0 / f
	return []
