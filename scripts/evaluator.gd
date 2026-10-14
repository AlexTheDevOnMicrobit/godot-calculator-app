extends RefCounted
## Expression evaluator (recursive-descent parser) with complex numbers,
## the variable x and the numeric tools of a graphing calculator.
##
## Grammar (lowest to highest precedence):
##   expression := term (("+" | "-") term)*
##   term       := unary (("*" | "/" | "mod" | <implicit>) unary)*
##   unary      := ("+" | "-") unary | power
##   power      := postfix ("^" unary)?          (right associative)
##   postfix    := primary ("!" | "%")*
##   primary    := NUMBER | CONSTANT | x | FUNCTION "(" args ")" | "(" expression ")"
##   args       := expression (";" expression)*
##
## Values are complex numbers stored as [re, im] (64-bit floats; Godot's
## Vector2 is only 32-bit). Complex results appear when the expression uses i,
## or when complex results are allowed (settings) and e.g. √(−4) is computed;
## otherwise such results are reported as ERR_NONREAL, like a TI-84 in REAL mode.
##
## "Special" functions (deriv, integral, sum, solve, fmin, fmax) receive their
## first argument unevaluated: an expression of x evaluated many times.

enum AngleMode { DEG, RAD }

const ERR_SYNTAX := "ERR_SYNTAX"
const ERR_DIV_ZERO := "ERR_DIV_ZERO"
const ERR_DOMAIN := "ERR_DOMAIN"
const ERR_OVERFLOW := "ERR_OVERFLOW"
const ERR_NONREAL := "ERR_NONREAL"
const ERR_NO_SOLUTION := "ERR_NO_SOLUTION"

## Function name -> [minimum, maximum] number of arguments.
const FUNCTIONS := {
	"sin": [1, 1], "cos": [1, 1], "tan": [1, 1], "asin": [1, 1], "acos": [1, 1], "atan": [1, 1],
	"sinh": [1, 1], "cosh": [1, 1], "tanh": [1, 1], "asinh": [1, 1], "acosh": [1, 1], "atanh": [1, 1],
	"ln": [1, 1], "log": [1, 1], "sqrt": [1, 1], "cbrt": [1, 1], "abs": [1, 1], "exp": [1, 1],
	"floor": [1, 1], "ceil": [1, 1], "round": [1, 2], "ipart": [1, 1], "fpart": [1, 1], "int": [1, 1],
	"frac": [2, 2], "root": [2, 2], "logb": [2, 2], "nCr": [2, 2], "nPr": [2, 2], "gcd": [2, 2],
	"lcm": [2, 2], "randint": [2, 2], "min": [2, 2], "max": [2, 2], "remainder": [2, 2],
	"conj": [1, 1], "real": [1, 1], "imag": [1, 1], "arg": [1, 1],
	"gamma": [1, 1], "normalpdf": [1, 3], "normalcdf": [2, 4], "invnorm": [1, 3],
	"binompdf": [3, 3], "binomcdf": [3, 3], "poissonpdf": [2, 2], "poissoncdf": [2, 2],
	"randnorm": [2, 2], "randbin": [2, 2],
	# Special forms: first argument is an expression of x.
	"deriv": [2, 2], "integral": [3, 3], "sum": [3, 3], "prod": [3, 3], "solve": [2, 2],
	"fmin": [3, 3], "fmax": [3, 3],
}
const SPECIAL := ["deriv", "integral", "sum", "prod", "solve", "fmin", "fmax"]
const CONSTANTS := ["pi", "phi", "e", "Ans", "rand", "i", "x"]
const EPSILON := 1e-12
const MAX_FACTORIAL := 170
const GOLDEN_RATIO := 1.6180339887498949
const MAX_SUM_TERMS := 100000

var angle_mode: AngleMode = AngleMode.DEG
var last_answer: float = 0.0
var last_answer_im: float = 0.0
## Allow complex results even when the expression doesn't contain i.
var allow_complex := false

var _tokens: Array = []
var _pos: int = 0
var _error: String = ""
var _uses_i := false
var _x = null # value of x ([re, im]) or null when x is not defined
var _words: Array = [] # known identifiers, longest first
var _depth := 0 # nesting of special forms (deriv(integral(...)))
var _child_cache = null


func _init() -> void:
	_words = FUNCTIONS.keys() + CONSTANTS + ["mod"]
	_words.sort_custom(func(a, b): return a.length() > b.length())


## Evaluates [param text]. Returns { "ok", "value" (real part), "im", "error" }.
func evaluate(text: String) -> Dictionary:
	var compiled := compile(text)
	if not compiled["ok"]:
		return { "ok": false, "value": 0.0, "im": 0.0, "error": compiled["error"] }
	return evaluate_compiled(compiled["tokens"])


## Tokenizes [param text] once (for graphs and repeated evaluation).
## Returns { "ok", "tokens", "error", "uses_x" }.
func compile(text: String) -> Dictionary:
	_error = ""
	var tokens := _tokenize(text)
	if _error == "" and tokens.is_empty():
		_error = ERR_SYNTAX
	var uses_x := false
	for t in tokens:
		if t["type"] == "const" and t["value"] == "x":
			uses_x = true
	return { "ok": _error == "", "tokens": tokens, "error": _error, "uses_x": uses_x }


## Evaluates compiled tokens, with x = [param x] when given.
func evaluate_compiled(tokens: Array, x = null) -> Dictionary:
	var result = _run(tokens, [float(x), 0.0] if x != null else null)
	if _error != "":
		return { "ok": false, "value": 0.0, "im": 0.0, "error": _error }
	return { "ok": true, "value": result[0], "im": result[1], "error": "" }


## Fast path for graphs: real value of f(x), or NAN when undefined / complex.
func evaluate_real(tokens: Array, x: float) -> float:
	var result = _run(tokens, [x, 0.0])
	if _error != "" or absf(result[1]) > EPSILON * maxf(1.0, absf(result[0])):
		return NAN
	return result[0]


func _run(tokens: Array, x):
	_error = ""
	_pos = 0
	_tokens = tokens
	_x = x
	_uses_i = false
	for t in tokens:
		if t["type"] == "const" and t["value"] == "i":
			_uses_i = true
	var value = _parse_expression()
	if _error == "" and _pos < _tokens.size():
		_error = ERR_SYNTAX
	if _error != "":
		return [0.0, 0.0]
	if is_nan(value[0]) or is_inf(value[0]) or is_nan(value[1]) or is_inf(value[1]):
		_error = ERR_OVERFLOW
		return [0.0, 0.0]
	var re: float = value[0]
	var im: float = value[1]
	# Rounding noise: e^(iπ) = −1 + 1.2e−16 i  ->  −1
	if absf(im) < EPSILON * maxf(1.0, absf(re)):
		im = 0.0
	if absf(re) < (EPSILON * absf(im) if im != 0.0 else EPSILON * 1e-3):
		re = 0.0
	return [re, im]


func _complex_ok() -> bool:
	return allow_complex or _uses_i


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
				elif FUNCTIONS.has(word) or FUNCTIONS.has(word.to_lower()):
					tokens.append({ "type": "func", "value": word if FUNCTIONS.has(word) else word.to_lower() })
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
				"𝑖":
					tokens.append({ "type": "const", "value": "i" })
				_:
					_error = ERR_SYNTAX
					return []
			i += 1
	return tokens


func _longest_word(run: String) -> String:
	var best := ""
	for word in _words:
		if run.begins_with(word):
			best = word
			break
	# Case-insensitive function names typed on a keyboard: normalCdf, invNorm...
	var lower := run.to_lower()
	for word in FUNCTIONS:
		if word.length() > maxi(best.length(), 3) and lower.begins_with(word):
			best = run.substr(0, word.length())
	return best


static func is_letter(c: String) -> bool:
	var code := c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


# --- Complex arithmetic ----------------------------------------------------

static func _c(re: float, im: float = 0.0) -> Array:
	return [re, im]


static func _is_real(z: Array) -> bool:
	return z[1] == 0.0


func _add(a: Array, b: Array) -> Array:
	return [a[0] + b[0], a[1] + b[1]]


func _sub(a: Array, b: Array) -> Array:
	return [a[0] - b[0], a[1] - b[1]]


func _mul(a: Array, b: Array) -> Array:
	if a[1] == 0.0 and b[1] == 0.0:
		return [a[0] * b[0], 0.0]
	return [a[0] * b[0] - a[1] * b[1], a[0] * b[1] + a[1] * b[0]]


func _div(a: Array, b: Array) -> Array:
	if b[0] == 0.0 and b[1] == 0.0:
		_error = ERR_DIV_ZERO
		return [0.0, 0.0]
	if a[1] == 0.0 and b[1] == 0.0:
		return [a[0] / b[0], 0.0]
	var d: float = b[0] * b[0] + b[1] * b[1]
	return [(a[0] * b[0] + a[1] * b[1]) / d, (a[1] * b[0] - a[0] * b[1]) / d]


func _modulus(z: Array) -> float:
	return sqrt(z[0] * z[0] + z[1] * z[1]) if z[1] != 0.0 else absf(z[0])


func _exp(z: Array) -> Array:
	var r := exp(z[0])
	if z[1] == 0.0:
		return [r, 0.0]
	return [r * cos(z[1]), r * sin(z[1])]


func _ln(z: Array) -> Array:
	if z[1] == 0.0 and z[0] > 0.0:
		return [log(z[0]), 0.0]
	if z[0] == 0.0 and z[1] == 0.0:
		_error = ERR_DOMAIN
		return [0.0, 0.0]
	if not _complex_ok():
		_error = ERR_NONREAL
		return [0.0, 0.0]
	return [log(_modulus(z)), atan2(z[1], z[0])]


func _sqrt(z: Array) -> Array:
	if z[1] == 0.0:
		if z[0] >= 0.0:
			return [sqrt(z[0]), 0.0]
		if not _complex_ok():
			_error = ERR_NONREAL
			return [0.0, 0.0]
		return [0.0, sqrt(-z[0])]
	var r := _modulus(z)
	var re := sqrt((r + z[0]) / 2.0)
	var im := sqrt((r - z[0]) / 2.0)
	return [re, im if z[1] >= 0.0 else -im]


func _sin(z: Array) -> Array:
	return [sin(z[0]) * cosh(z[1]), cos(z[0]) * sinh(z[1])]


func _cos(z: Array) -> Array:
	return [cos(z[0]) * cosh(z[1]), -sin(z[0]) * sinh(z[1])]


func _pow(base: Array, exponent: Array) -> Array:
	if _is_real(base) and _is_real(exponent):
		var b: float = base[0]
		var e: float = exponent[0]
		if b == 0.0 and e < 0.0:
			_error = ERR_DIV_ZERO
			return [0.0, 0.0]
		if b < 0.0 and e != floorf(e):
			# Odd roots of negatives stay real: (−8)^(1/3) = −2
			var inv := 1.0 / e
			if absf(inv - roundf(inv)) < 1e-9 and int(roundf(inv)) % 2 != 0:
				return [-pow(-b, e), 0.0]
			if not _complex_ok():
				_error = ERR_NONREAL
				return [0.0, 0.0]
		else:
			return [pow(b, e), 0.0]
	if base[0] == 0.0 and base[1] == 0.0:
		return [0.0, 0.0]
	# Integer powers of complex numbers: repeated multiplication (exact for i²)
	if _is_real(exponent) and exponent[0] == floorf(exponent[0]) and absf(exponent[0]) <= 64.0:
		var result := [1.0, 0.0]
		for _k in int(absf(exponent[0])):
			result = _mul(result, base)
		return result if exponent[0] >= 0.0 else _div([1.0, 0.0], result)
	var saved := allow_complex
	allow_complex = true
	var result := _exp(_mul(exponent, _ln(base)))
	allow_complex = saved
	return result


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


func _parse_expression() -> Array:
	var value := _parse_term()
	while _error == "" and (_peek_is("op", "+") or _peek_is("op", "-")):
		var op: String = _tokens[_pos]["value"]
		_pos += 1
		var rhs := _parse_term()
		value = _add(value, rhs) if op == "+" else _sub(value, rhs)
	return value


func _parse_term() -> Array:
	var value := _parse_unary()
	while _error == "":
		var op := ""
		if _peek_is("op", "*") or _peek_is("op", "/") or _peek_is("op", "mod"):
			op = _tokens[_pos]["value"]
			_pos += 1
		elif _peek_is("const") or _peek_is("func") or _peek_is("lparen") or (_peek_is("num") and _previous_allows_number()):
			op = "*" # implicit multiplication: 2π, 3(4+1), 2sin(30), (1+1)2, 2x, 3i
		else:
			break
		var rhs := _parse_unary()
		if _error != "":
			break
		match op:
			"*":
				value = _mul(value, rhs)
			"/":
				value = _div(value, rhs)
			"mod":
				var a := _real_arg(value)
				var b := _real_arg(rhs)
				if _error != "":
					break
				if b == 0.0:
					_error = ERR_DIV_ZERO
					break
				value = [fposmod(a, b) if b > 0.0 else -fposmod(-a, -b), 0.0]
	return value


func _parse_unary() -> Array:
	if _peek_is("op", "-"):
		_pos += 1
		var v := _parse_unary()
		return [-v[0], -v[1] if v[1] != 0.0 else 0.0] # never −0 (atan2 would flip sides)
	if _peek_is("op", "+"):
		_pos += 1
		return _parse_unary()
	return _parse_power()


func _parse_power() -> Array:
	var base := _parse_postfix()
	if _error == "" and _peek_is("op", "^"):
		_pos += 1
		var exponent := _parse_unary()
		if _error != "":
			return [0.0, 0.0]
		return _pow(base, exponent)
	return base


func _parse_postfix() -> Array:
	var value := _parse_primary()
	while _error == "":
		if _peek_is("op", "!"):
			_pos += 1
			value = [_factorial(_real_arg(value)), 0.0]
		elif _peek_is("op", "%"):
			_pos += 1
			value = [value[0] / 100.0, value[1] / 100.0]
		else:
			break
	return value


func _parse_primary() -> Array:
	var t := _peek()
	if t.is_empty():
		_error = ERR_SYNTAX
		return [0.0, 0.0]
	match t["type"]:
		"num":
			_pos += 1
			return [t["value"], 0.0]
		"const":
			_pos += 1
			match t["value"]:
				"pi":
					return [PI, 0.0]
				"phi":
					return [GOLDEN_RATIO, 0.0]
				"e":
					return [exp(1.0), 0.0]
				"Ans":
					return [last_answer, last_answer_im]
				"rand":
					return [randf(), 0.0]
				"i":
					return [0.0, 1.0]
				"x":
					if _x == null:
						_error = ERR_SYNTAX
						return [0.0, 0.0]
					return _x
		"lparen":
			_pos += 1
			var inner := _parse_expression()
			_expect_rparen()
			return inner
		"func":
			_pos += 1
			var name: String = t["value"]
			if name in SPECIAL:
				return _parse_special(name)
			var arity: Array = FUNCTIONS[name]
			var args: Array = []
			if _peek_is("lparen"):
				_pos += 1
				args.append(_parse_expression())
				while _error == "" and _peek_is("sep"):
					_pos += 1
					args.append(_parse_expression())
				_expect_rparen()
			elif arity[0] == 1:
				# √9, sin30 : function applied to the next postfix-level operand
				args.append(_parse_postfix())
			if _error != "":
				return [0.0, 0.0]
			if args.size() < arity[0] or args.size() > arity[1]:
				_error = ERR_SYNTAX
				return [0.0, 0.0]
			return _apply_function(name, args)
	_error = ERR_SYNTAX
	return [0.0, 0.0]


func _expect_rparen() -> void:
	if _error != "":
		return
	if _peek_is("rparen"):
		_pos += 1
	elif _pos < _tokens.size():
		_error = ERR_SYNTAX
	# else: end of input, auto-close the parenthesis


# --- Math ------------------------------------------------------------------

func _to_radians(v: float) -> float:
	return deg_to_rad(v) if angle_mode == AngleMode.DEG else v


func _from_radians(v: float) -> float:
	return rad_to_deg(v) if angle_mode == AngleMode.DEG else v


func _snap(v: float) -> float:
	if absf(v) < EPSILON:
		return 0.0
	if absf(v - roundf(v)) < EPSILON:
		return roundf(v)
	return v


## Real value of a function argument (sets ERR_DOMAIN for complex numbers).
func _real_arg(z: Array) -> float:
	if z[1] != 0.0:
		if _error == "":
			_error = ERR_DOMAIN
		return 0.0
	return z[0]


func _domain_error() -> Array:
	_error = ERR_DOMAIN
	return [0.0, 0.0]


func _r(v: float) -> Array:
	return [v, 0.0]


func _apply_function(name: String, args: Array) -> Array:
	var z: Array = args[0]
	# Functions defined on complex numbers
	match name:
		"abs":
			return _r(_modulus(z))
		"conj":
			return [z[0], -z[1]]
		"real":
			return _r(z[0])
		"imag":
			return _r(z[1])
		"arg":
			if z[0] == 0.0 and z[1] == 0.0:
				return _domain_error()
			return _r(_snap(_from_radians(atan2(z[1], z[0]))))
		"sqrt":
			return _sqrt(z)
		"exp":
			return _exp(z)
		"ln":
			return _ln(z)
		"log":
			var l := _ln(z)
			return _r(_snap(l[0] / log(10.0))) if l[1] == 0.0 else [l[0] / log(10.0), l[1] / log(10.0)]
		"sin", "cos", "tan":
			if not _is_real(z):
				# Complex arguments are always in radians.
				if name == "sin":
					return _sin(z)
				if name == "cos":
					return _cos(z)
				return _div(_sin(z), _cos(z))
		"sinh", "cosh", "tanh":
			if not _is_real(z):
				var ez := _exp(z)
				var emz := _exp([-z[0], -z[1]])
				var s := [(ez[0] - emz[0]) / 2.0, (ez[1] - emz[1]) / 2.0]
				var c := [(ez[0] + emz[0]) / 2.0, (ez[1] + emz[1]) / 2.0]
				return s if name == "sinh" else (c if name == "cosh" else _div(s, c))
		"frac":
			return _div(args[0], args[1])
	# Everything else works on real numbers.
	var reals: Array[float] = []
	for a in args:
		reals.append(_real_arg(a))
	if _error != "":
		return [0.0, 0.0]
	var v = _apply_real(name, reals)
	return v if v is Array else _r(v)


func _apply_real(name: String, args: Array[float]):
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
		"cbrt":
			var root := pow(absf(x), 1.0 / 3.0)
			return _snap(-root if x < 0.0 else root)
		"floor", "int":
			return floorf(x)
		"ceil":
			return ceilf(x)
		"round":
			if args.size() == 1:
				return roundf(x)
			var factor := pow(10.0, clampf(roundf(args[1]), 0.0, 12.0))
			return roundf(x * factor) / factor
		"ipart":
			return float(int(x)) if absf(x) < 9e18 else x
		"fpart":
			return x - (float(int(x)) if absf(x) < 9e18 else x)
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
				return float(g)
			return 0.0 if g == 0 else absf(x * args[1]) / g
		"min":
			return minf(x, args[1])
		"max":
			return maxf(x, args[1])
		"remainder":
			if args[1] == 0.0:
				_error = ERR_DIV_ZERO
				return 0.0
			return x - args[1] * float(int(x / args[1]))
		"randint":
			if not _is_integer(x) or not _is_integer(args[1]) or x > args[1]:
				return _domain_error()
			return float(randi_range(int(x), int(args[1])))
		"gamma":
			return _gamma(x)
		"normalpdf":
			var mu := args[1] if args.size() > 1 else 0.0
			var sigma := args[2] if args.size() > 2 else 1.0
			if sigma <= 0.0:
				return _domain_error()
			var u := (x - mu) / sigma
			return exp(-0.5 * u * u) / (sigma * sqrt(TAU))
		"normalcdf":
			var mu := args[2] if args.size() > 2 else 0.0
			var sigma := args[3] if args.size() > 3 else 1.0
			if sigma <= 0.0:
				return _domain_error()
			return _phi((args[1] - mu) / sigma) - _phi((x - mu) / sigma)
		"invnorm":
			var mu := args[1] if args.size() > 1 else 0.0
			var sigma := args[2] if args.size() > 2 else 1.0
			if x <= 0.0 or x >= 1.0 or sigma <= 0.0:
				return _domain_error()
			return mu + sigma * _inverse_normal(x)
		"binompdf", "binomcdf":
			var n := x
			var p := args[1]
			var k := args[2]
			if not _is_integer(n) or n < 0.0 or p < 0.0 or p > 1.0:
				return _domain_error()
			if name == "binompdf":
				return _binomial_pmf(int(n), p, k)
			var total := 0.0
			for j in range(0, int(floorf(minf(k, n))) + 1):
				total += _binomial_pmf(int(n), p, j)
			return minf(total, 1.0)
		"poissonpdf", "poissoncdf":
			var mu := x
			var k := args[1]
			if mu <= 0.0:
				return _domain_error()
			if name == "poissonpdf":
				return _poisson_pmf(mu, k)
			var total := 0.0
			for j in range(0, int(floorf(k)) + 1):
				total += _poisson_pmf(mu, j)
			return minf(total, 1.0)
		"randnorm":
			if args[1] <= 0.0:
				return _domain_error()
			return x + args[1] * _inverse_normal(clampf(randf(), 1e-12, 1.0 - 1e-12))
		"randbin":
			if not _is_integer(x) or x < 0.0 or args[1] < 0.0 or args[1] > 1.0:
				return _domain_error()
			var successes := 0
			for _t in int(x):
				if randf() < args[1]:
					successes += 1
			return float(successes)
	_error = ERR_SYNTAX
	return 0.0


## n-th root of x (index first, like the ⁿ√x template).
func _nth_root(x: float, n: float):
	if n == 0.0:
		return _domain_error()
	if x < 0.0:
		if _is_integer(n) and int(n) % 2 != 0:
			return _snap(-pow(-x, 1.0 / n))
		if _complex_ok():
			return _pow([x, 0.0], [1.0 / n, 0.0])
		_error = ERR_NONREAL
		return 0.0
	return _snap(pow(x, 1.0 / n))


func _combinatorics(name: String, n: float, r: float):
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


func _is_integer(v: float) -> bool:
	return v == floorf(v) and absf(v) < 9.0e15


func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


## x! for integers, Γ(x + 1) otherwise (0.5! = √π / 2).
func _factorial(v: float) -> float:
	if v > MAX_FACTORIAL:
		_error = ERR_OVERFLOW
		return 0.0
	if v == floorf(v):
		if v < 0.0:
			_error = ERR_DOMAIN
			return 0.0
		var result := 1.0
		for i in range(2, int(v) + 1):
			result *= i
		return result
	var g = _gamma(v + 1.0)
	return g if g is float else 0.0


## Gamma function (Lanczos approximation, reflection for x < 0.5).
func _gamma(v: float):
	if v <= 0.0 and v == floorf(v):
		return _domain_error()
	if v < 0.5:
		return PI / (sin(PI * v) * _gamma_positive(1.0 - v))
	return _gamma_positive(v)


static func _gamma_positive(v: float) -> float:
	return exp(log_gamma(v))


## ln Γ(x) for x > 0 (Lanczos, g = 7, n = 9: about 15 significant digits).
static func log_gamma(v: float) -> float:
	const G := [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
		-176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
		1.5056327351493116e-7]
	v -= 1.0
	var a: float = G[0]
	var t := v + 7.5
	for i in range(1, 9):
		a += G[i] / (v + i)
	return 0.5 * log(TAU) + (v + 0.5) * log(t) - t + log(a)


## Standard normal cumulative distribution Φ(z).
static func _phi(z: float) -> float:
	return 0.5 * erfc(-z / sqrt(2.0))


## Complementary error function (series for small |x|, continued fraction otherwise).
static func erfc(v: float) -> float:
	if v < 0.0:
		return 2.0 - erfc(-v)
	if v < 2.5:
		# erf(x) = 2/√π Σ (−1)ⁿ x^(2n+1) / (n! (2n+1))
		var term := v
		var total := v
		var x2 := v * v
		for n in range(1, 80):
			term *= -x2 / n
			var delta := term / (2 * n + 1)
			total += delta
			if absf(delta) < 1e-17 * absf(total):
				break
		return 1.0 - total * 2.0 / sqrt(PI)
	# Continued fraction (Lentz) for erfc(x) = exp(−x²)/√π · 1/(x + 1/2/(x + 1/(x + 3/2/(x + …))))
	var tiny := 1e-300
	var f := v
	var c := v
	var d := 0.0
	for k in range(1, 200):
		var a := k / 2.0
		d = v + a * d
		d = tiny if absf(d) < tiny else d
		c = v + a / c
		c = tiny if absf(c) < tiny else c
		d = 1.0 / d
		var delta := c * d
		f *= delta
		if absf(delta - 1.0) < 1e-16:
			break
	return exp(-v * v) / (f * sqrt(PI))


## Inverse of Φ (Acklam's rational approximation + one Halley refinement).
static func _inverse_normal(p: float) -> float:
	const A := [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
		1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
	const B := [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
		6.680131188771972e+01, -1.328068155288572e+01]
	const C := [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
		-2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
	const D := [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00]
	var x: float
	if p < 0.02425:
		var q := sqrt(-2.0 * log(p))
		x = (((((C[0] * q + C[1]) * q + C[2]) * q + C[3]) * q + C[4]) * q + C[5]) / ((((D[0] * q + D[1]) * q + D[2]) * q + D[3]) * q + 1.0)
	elif p > 1.0 - 0.02425:
		var q := sqrt(-2.0 * log(1.0 - p))
		x = -(((((C[0] * q + C[1]) * q + C[2]) * q + C[3]) * q + C[4]) * q + C[5]) / ((((D[0] * q + D[1]) * q + D[2]) * q + D[3]) * q + 1.0)
	else:
		var q := p - 0.5
		var r := q * q
		x = (((((A[0] * r + A[1]) * r + A[2]) * r + A[3]) * r + A[4]) * r + A[5]) * q / (((((B[0] * r + B[1]) * r + B[2]) * r + B[3]) * r + B[4]) * r + 1.0)
	var e := _phi(x) - p
	var u := e * sqrt(TAU) * exp(x * x / 2.0)
	return x - u / (1.0 + x * u / 2.0)


static func _binomial_pmf(n: int, p: float, k: float) -> float:
	if k != floorf(k) or k < 0.0 or k > n:
		return 0.0
	if p == 0.0:
		return 1.0 if k == 0.0 else 0.0
	if p == 1.0:
		return 1.0 if k == n else 0.0
	var log_c := log_gamma(n + 1.0) - log_gamma(k + 1.0) - log_gamma(n - k + 1.0)
	return exp(log_c + k * log(p) + (n - k) * log(1.0 - p))


static func _poisson_pmf(mu: float, k: float) -> float:
	if k != floorf(k) or k < 0.0:
		return 0.0
	return exp(k * log(mu) - mu - log_gamma(k + 1.0))


# --- Special forms (numeric calculus) ---------------------------------------

## deriv(f; a), integral(f; a; b), sum(f; a; b), prod(f; a; b), solve(f; guess),
## fmin(f; a; b), fmax(f; a; b) — f is an expression of x.
func _parse_special(name: String) -> Array:
	if not _peek_is("lparen"):
		_error = ERR_SYNTAX
		return [0.0, 0.0]
	_pos += 1
	# Capture the tokens of the first argument (up to ";" at depth 0).
	var start := _pos
	var depth := 0
	while _pos < _tokens.size():
		var t: Dictionary = _tokens[_pos]
		if t["type"] == "lparen":
			depth += 1
		elif t["type"] == "rparen":
			if depth == 0:
				break
			depth -= 1
		elif t["type"] == "sep" and depth == 0:
			break
		_pos += 1
	var body := _tokens.slice(start, _pos)
	if body.is_empty():
		_error = ERR_SYNTAX
		return [0.0, 0.0]
	var bounds: Array[float] = []
	while _error == "" and _peek_is("sep"):
		_pos += 1
		bounds.append(_real_arg(_parse_expression()))
	_expect_rparen()
	if _error != "":
		return [0.0, 0.0]
	var arity: Array = FUNCTIONS[name]
	if bounds.size() + 1 < arity[0] or bounds.size() + 1 > arity[1]:
		_error = ERR_SYNTAX
		return [0.0, 0.0]
	if _depth > 3:
		_error = ERR_OVERFLOW
		return [0.0, 0.0]
	var value = _numeric(name, body, bounds)
	return value if value is Array else [value, 0.0]


## Evaluates f(x) for the special forms with a nested evaluator (reused).
func _f(body: Array, x: float) -> float:
	if _child_cache == null:
		_child_cache = _child()
	_child_cache.angle_mode = angle_mode
	return _child_cache.evaluate_real(body, x)


## ∫ f(x) dx from a to b for compiled tokens (graph tools).
func integral_of(tokens: Array, a: float, b: float) -> float:
	_error = ""
	return _snap_relative(_integrate(tokens, a, b))


## f'(x) for compiled tokens (graph trace).
func derivative_of(tokens: Array, x: float) -> float:
	var h := 1e-4 * maxf(1.0, absf(x))
	return _snap_relative((-_f(tokens, x + 2 * h) + 8 * _f(tokens, x + h) - 8 * _f(tokens, x - h) + _f(tokens, x - 2 * h)) / (12 * h))


func _child():
	var sub = get_script().new()
	sub.angle_mode = angle_mode
	sub.last_answer = last_answer
	sub.last_answer_im = last_answer_im
	sub.allow_complex = false
	sub._depth = _depth + 1
	return sub


func _numeric(name: String, body: Array, bounds: Array[float]):
	match name:
		"deriv":
			var a := bounds[0]
			var h := 1e-4 * maxf(1.0, absf(a))
			# Five-point stencil: error O(h⁴)
			var d := (-_f(body, a + 2 * h) + 8 * _f(body, a + h) - 8 * _f(body, a - h) + _f(body, a - 2 * h)) / (12 * h)
			return _checked(_snap_relative(d))
		"integral":
			return _checked(_snap_relative(_integrate(body, bounds[0], bounds[1])))
		"sum", "prod":
			if not _is_integer(bounds[0]) or not _is_integer(bounds[1]) or bounds[1] - bounds[0] > MAX_SUM_TERMS:
				return _domain_error()
			var total := 0.0 if name == "sum" else 1.0
			var k := bounds[0]
			while k <= bounds[1]:
				var v: float = _f(body, k)
				total = total + v if name == "sum" else total * v
				k += 1.0
			return _checked(total)
		"solve":
			return _solve(body, bounds[0])
		"fmin", "fmax":
			var found := _extremum(body, bounds[0], bounds[1], name == "fmax")
			return _checked(_snap_relative(found))
	return 0.0


func _checked(v: float):
	if is_nan(v) or is_inf(v):
		return _domain_error()
	return v


func _snap_relative(v: float) -> float:
	var r := roundf(v)
	if absf(v - r) < 1e-9 * maxf(1.0, absf(v)):
		return r
	return v


## Adaptive Simpson integration.
func _integrate(body: Array, a: float, b: float) -> float:
	if a == b:
		return 0.0
	var fa := _f(body, a)
	var fb := _f(body, b)
	var m := (a + b) / 2.0
	var fm := _f(body, m)
	var whole := (b - a) / 6.0 * (fa + 4.0 * fm + fb)
	return _simpson(body, a, b, fa, fm, fb, whole, 1e-11, 18)


func _simpson(body: Array, a: float, b: float, fa: float, fm: float, fb: float, whole: float, tolerance: float, depth: int) -> float:
	var m := (a + b) / 2.0
	var lm := (a + m) / 2.0
	var rm := (m + b) / 2.0
	var flm := _f(body, lm)
	var frm := _f(body, rm)
	var left := (m - a) / 6.0 * (fa + 4.0 * flm + fm)
	var right := (b - m) / 6.0 * (fm + 4.0 * frm + fb)
	var delta := left + right - whole
	if depth <= 0 or absf(delta) <= 15.0 * tolerance:
		return left + right + delta / 15.0
	return _simpson(body, a, m, fa, flm, fm, left, tolerance / 2.0, depth - 1) \
		+ _simpson(body, m, b, fm, frm, fb, right, tolerance / 2.0, depth - 1)


## Root of f near [param guess]: secant steps, then a bracketing scan + bisection.
func _solve(body: Array, guess: float):
	var x0 := guess
	var x1 := guess + maxf(1e-3, absf(guess) * 1e-3)
	var f0 := _f(body, x0)
	var f1 := _f(body, x1)
	for _i in 60:
		if is_nan(f0) or is_nan(f1) or f1 == f0:
			break
		var x2 := x1 - f1 * (x1 - x0) / (f1 - f0)
		x0 = x1
		f0 = f1
		x1 = x2
		f1 = _f(body, x1)
		if absf(f1) < 1e-13 or absf(x1 - x0) < 1e-14 * maxf(1.0, absf(x1)):
			if absf(f1) < 1e-7:
				return _snap_relative(x1)
			break
	# Scan outwards from the guess for a sign change, then bisect.
	var step := maxf(0.1, absf(guess) * 0.05)
	for k in 400:
		for direction in [1.0, -1.0]:
			var a: float = guess + direction * k * step
			var b: float = a + direction * step
			var fa := _f(body, a)
			var fb := _f(body, b)
			if not is_nan(fa) and not is_nan(fb) and (fa == 0.0 or fa * fb < 0.0):
				return _snap_relative(bisect(func(v): return _f(body, v), minf(a, b), maxf(a, b)))
	_error = ERR_NO_SOLUTION
	return 0.0


## Root of [param f] in [a, b] where f changes sign (bisection).
static func bisect(f: Callable, a: float, b: float) -> float:
	var fa: float = f.call(a)
	if fa == 0.0:
		return a
	for _i in 200:
		var m := (a + b) / 2.0
		var fm: float = f.call(m)
		if fm == 0.0 or (b - a) / 2.0 < 1e-15 * maxf(1.0, absf(m)):
			return m
		if (fm < 0.0) == (fa < 0.0):
			a = m
			fa = fm
		else:
			b = m
	return (a + b) / 2.0


## x where f is smallest (or largest) on [a, b]: sampling + golden-section search.
func _extremum(body: Array, a: float, b: float, maximum: bool) -> float:
	if a > b:
		var t := a
		a = b
		b = t
	var sign := -1.0 if maximum else 1.0
	var best_x := a
	var best := INF
	const SAMPLES := 200
	for k in SAMPLES + 1:
		var x := a + (b - a) * k / SAMPLES
		var v := sign * _f(body, x)
		if not is_nan(v) and v < best:
			best = v
			best_x = x
	var lo := maxf(a, best_x - (b - a) / SAMPLES)
	var hi := minf(b, best_x + (b - a) / SAMPLES)
	return golden_section(func(v): return sign * _f(body, v), lo, hi)


## Minimum of a unimodal function on [a, b].
static func golden_section(f: Callable, a: float, b: float) -> float:
	var ratio := (sqrt(5.0) - 1.0) / 2.0
	var c := b - ratio * (b - a)
	var d := a + ratio * (b - a)
	var fc: float = f.call(c)
	var fd: float = f.call(d)
	for _i in 120:
		if absf(b - a) < 1e-12 * maxf(1.0, absf(c)):
			break
		if fc < fd:
			b = d
			d = c
			fd = fc
			c = b - ratio * (b - a)
			fc = f.call(c)
		else:
			a = c
			c = d
			fc = fd
			d = a + ratio * (b - a)
			fd = f.call(d)
	return (a + b) / 2.0


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


## Formats a complex number: "3 + 4i" (rectangular) or "5∠53.13°" (polar).
static func format_complex(re: float, im: float, polar: bool, degrees: bool, decimal_sep: String = ".",
		group_sep: String = "", fixed: int = -1) -> String:
	if im == 0.0 and not polar:
		return format_number(re, decimal_sep, group_sep, fixed)
	if polar:
		var r := sqrt(re * re + im * im)
		var theta := atan2(im, re)
		if degrees:
			theta = rad_to_deg(theta)
		var angle := format_number(theta, decimal_sep, group_sep, fixed)
		return format_number(r, decimal_sep, group_sep, fixed) + "∠" + angle + ("°" if degrees else "")
	var imag_abs := absf(im)
	var imag_text := "" if imag_abs == 1.0 else format_number(imag_abs, decimal_sep, group_sep, fixed)
	if re == 0.0:
		return ("-" if im < 0.0 else "") + imag_text + "i"
	return format_number(re, decimal_sep, group_sep, fixed) + (" - " if im < 0.0 else " + ") + imag_text + "i"


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
