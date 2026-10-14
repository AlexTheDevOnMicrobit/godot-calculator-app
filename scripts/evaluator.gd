extends RefCounted
## Scientific expression evaluator (recursive-descent parser).
##
## Grammar (lowest to highest precedence):
##   expression := term (("+" | "-") term)*
##   term       := unary (("*" | "/" | "mod" | <implicit>) unary)*
##   unary      := ("+" | "-") unary | power
##   power      := postfix ("^" unary)?          (right associative)
##   postfix    := primary ("!" | "%")*
##   primary    := NUMBER | CONSTANT | FUNCTION "(" expression ")" | "(" expression ")"
##
## Display symbols (×, ÷, −, π, √, ∛) are accepted as well as their ASCII forms.
## Missing closing parentheses at the end of the input are tolerated.

enum AngleMode { DEG, RAD }

const ERR_SYNTAX := "ERR_SYNTAX"
const ERR_DIV_ZERO := "ERR_DIV_ZERO"
const ERR_DOMAIN := "ERR_DOMAIN"
const ERR_OVERFLOW := "ERR_OVERFLOW"

const FUNCTIONS := [
	"sin", "cos", "tan", "asin", "acos", "atan",
	"sinh", "cosh", "tanh",
	"ln", "log", "sqrt", "cbrt", "abs", "exp",
]
const CONSTANTS := ["pi", "e", "Ans", "rand"]
const EPSILON := 1e-12
const MAX_FACTORIAL := 170

var angle_mode: AngleMode = AngleMode.DEG
var last_answer: float = 0.0

var _tokens: Array = []
var _pos: int = 0
var _error: String = ""


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
		if c == " ":
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
		elif _is_letter(c):
			var start := i
			while i < n and _is_letter(text[i]):
				i += 1
			var word := text.substr(start, i - start)
			if word == "mod":
				tokens.append({ "type": "op", "value": "mod" })
			elif word in FUNCTIONS:
				tokens.append({ "type": "func", "value": word })
			elif word in CONSTANTS:
				tokens.append({ "type": "const", "value": word })
			else:
				_error = ERR_SYNTAX
				return []
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
				"π":
					tokens.append({ "type": "const", "value": "pi" })
				"√":
					tokens.append({ "type": "func", "value": "sqrt" })
				"∛":
					tokens.append({ "type": "func", "value": "cbrt" })
				_:
					_error = ERR_SYNTAX
					return []
			i += 1
	return tokens


func _is_letter(c: String) -> bool:
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
	return base


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
			var arg: float
			if _peek_is("lparen"):
				_pos += 1
				arg = _parse_expression()
				_expect_rparen()
			else:
				# √9, sin30 : function applied to the next postfix-level operand
				arg = _parse_postfix()
			if _error != "":
				return 0.0
			return _apply_function(t["value"], arg)
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


func _apply_function(name: String, x: float) -> float:
	match name:
		"sin":
			return _snap(sin(_to_radians(x)))
		"cos":
			return _snap(cos(_to_radians(x)))
		"tan":
			var r := _to_radians(x)
			if absf(_snap(cos(r))) == 0.0:
				_error = ERR_DOMAIN
				return 0.0
			return _snap(tan(r))
		"asin":
			if x < -1.0 or x > 1.0:
				_error = ERR_DOMAIN
				return 0.0
			return _snap(_from_radians(asin(x)))
		"acos":
			if x < -1.0 or x > 1.0:
				_error = ERR_DOMAIN
				return 0.0
			return _snap(_from_radians(acos(x)))
		"atan":
			return _snap(_from_radians(atan(x)))
		"sinh":
			return sinh(x)
		"cosh":
			return cosh(x)
		"tanh":
			return tanh(x)
		"ln":
			if x <= 0.0:
				_error = ERR_DOMAIN
				return 0.0
			return log(x)
		"log":
			if x <= 0.0:
				_error = ERR_DOMAIN
				return 0.0
			return _snap(log(x) / log(10.0))
		"sqrt":
			if x < 0.0:
				_error = ERR_DOMAIN
				return 0.0
			return sqrt(x)
		"cbrt":
			var root := pow(absf(x), 1.0 / 3.0)
			return _snap(-root if x < 0.0 else root)
		"abs":
			return absf(x)
		"exp":
			return exp(x)
	_error = ERR_SYNTAX
	return 0.0


func _factorial(x: float) -> float:
	if x < 0.0 or x != floorf(x):
		_error = ERR_DOMAIN
		return 0.0
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
static func format_number(value: float, decimal_sep: String = ".", group_sep: String = "") -> String:
	if is_nan(value) or is_inf(value):
		return "—"
	if value == 0.0:
		return "0"
	var a := absf(value)
	var text: String
	if a >= 1e15 or a < 1e-9:
		var exponent := int(floor(log(a) / log(10.0)))
		var mantissa := value / pow(10.0, exponent)
		# Correct rounding drift (e.g. 9.9999999 -> 10)
		if absf(mantissa) >= 10.0:
			mantissa /= 10.0
			exponent += 1
		text = _trim(String.num(mantissa, 10)) + "E" + str(exponent)
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
