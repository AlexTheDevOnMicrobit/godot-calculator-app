extends RefCounted
## Integer evaluator for the Programmer mode (64-bit signed integers).
##
## Numbers are written in the current base (2, 8, 10 or 16, hex digits A-F).
## Precedence (lowest to highest), like C:
##   |   ⊕ (xor)   &   << >>   + −   × ÷ mod   unary − ~   ( )

const ERR_SYNTAX := "ERR_SYNTAX"
const ERR_DIV_ZERO := "ERR_DIV_ZERO"

const BASES := { "HEX": 16, "DEC": 10, "OCT": 8, "BIN": 2 }
const DIGITS := "0123456789ABCDEF"

var base := 10
var last_answer := 0

var _tokens: Array = []
var _pos := 0
var _error := ""


## Returns { "ok": bool, "value": int, "error": String }.
func evaluate(text: String) -> Dictionary:
	_error = ""
	_pos = 0
	_tokens = _tokenize(text)
	if _error == "" and _tokens.is_empty():
		_error = ERR_SYNTAX
	var value := 0
	if _error == "":
		value = _parse_or()
		if _error == "" and _pos < _tokens.size():
			_error = ERR_SYNTAX
	if _error != "":
		return { "ok": false, "value": 0, "error": _error }
	return { "ok": true, "value": value, "error": "" }


func _tokenize(text: String) -> Array:
	var tokens: Array = []
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == " ":
			i += 1
			continue
		if text.substr(i, 3) == "Ans":
			tokens.append({ "type": "num", "value": last_answer })
			i += 3
			continue
		if DIGITS.find(c) >= 0:
			var value := 0
			while i < text.length() and DIGITS.find(text[i]) >= 0:
				var digit := DIGITS.find(text[i])
				if digit >= base:
					_error = ERR_SYNTAX
					return []
				value = value * base + digit
				i += 1
			tokens.append({ "type": "num", "value": value })
			continue
		if text.substr(i, 3) == "mod":
			tokens.append({ "type": "op", "value": "mod" })
			i += 3
			continue
		if text.substr(i, 2) in ["<<", ">>"]:
			tokens.append({ "type": "op", "value": text.substr(i, 2) })
			i += 2
			continue
		match c:
			"+", "&", "|", "⊕", "~":
				tokens.append({ "type": "op", "value": c })
			"−", "-":
				tokens.append({ "type": "op", "value": "-" })
			"×", "*":
				tokens.append({ "type": "op", "value": "*" })
			"÷", "/":
				tokens.append({ "type": "op", "value": "/" })
			"(":
				tokens.append({ "type": "lparen" })
			")":
				tokens.append({ "type": "rparen" })
			_:
				_error = ERR_SYNTAX
				return []
		i += 1
	return tokens


func _peek_op(values: Array) -> String:
	if _pos < _tokens.size() and _tokens[_pos]["type"] == "op" and _tokens[_pos]["value"] in values:
		return _tokens[_pos]["value"]
	return ""


func _binary(next: Callable, ops: Array) -> int:
	var value: int = next.call()
	while _error == "":
		var op := _peek_op(ops)
		if op == "":
			break
		_pos += 1
		var rhs: int = next.call()
		match op:
			"|":
				value = value | rhs
			"⊕":
				value = value ^ rhs
			"&":
				value = value & rhs
			"<<":
				value = value << clampi(rhs, 0, 63)
			">>":
				value = value >> clampi(rhs, 0, 63)
			"+":
				value += rhs
			"-":
				value -= rhs
			"*":
				value *= rhs
			"/", "mod":
				if rhs == 0:
					_error = ERR_DIV_ZERO
					return 0
				value = value / rhs if op == "/" else value % rhs
	return value


func _parse_or() -> int:
	return _binary(_parse_xor, ["|"])


func _parse_xor() -> int:
	return _binary(_parse_and, ["⊕"])


func _parse_and() -> int:
	return _binary(_parse_shift, ["&"])


func _parse_shift() -> int:
	return _binary(_parse_sum, ["<<", ">>"])


func _parse_sum() -> int:
	return _binary(_parse_product, ["+", "-"])


func _parse_product() -> int:
	return _binary(_parse_unary, ["*", "/", "mod"])


func _parse_unary() -> int:
	var op := _peek_op(["-", "~", "+"])
	if op != "":
		_pos += 1
		var value := _parse_unary()
		match op:
			"-":
				return -value
			"~":
				return ~value
		return value
	return _parse_primary()


func _parse_primary() -> int:
	if _pos >= _tokens.size():
		_error = ERR_SYNTAX
		return 0
	var t: Dictionary = _tokens[_pos]
	_pos += 1
	if t["type"] == "num":
		return t["value"]
	if t["type"] == "lparen":
		var inner := _parse_or()
		if _pos < _tokens.size() and _tokens[_pos]["type"] == "rparen":
			_pos += 1
		elif _pos < _tokens.size():
			_error = ERR_SYNTAX
		return inner
	_error = ERR_SYNTAX
	return 0


## Formats [param value] in [param to_base]. Negative numbers use two's
## complement (64-bit) in HEX / OCT / BIN. Digits are grouped for readability.
static func format_int(value: int, to_base: int, grouped: bool = true) -> String:
	if to_base == 10:
		var text := str(absi(value))
		if grouped:
			var out := ""
			while text.length() > 3:
				out = "," + text.right(3) + out
				text = text.left(text.length() - 3)
			text = text + out
		return ("-" if value < 0 else "") + text
	var digits := String.num_uint64(value, to_base, true)
	if not grouped:
		return digits
	var size := 4 if to_base != 8 else 3
	var out := ""
	while digits.length() > size:
		out = " " + digits.right(size) + out
		digits = digits.left(digits.length() - size)
	return digits + out
