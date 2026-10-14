extends RefCounted
## Holds the expression being typed and applies "smart" input rules so that
## the user can't easily build an invalid expression:
##   - consecutive operators replace each other (2+× -> 2×)
##   - a single decimal point per number, ".5" becomes "0.5"
##   - ")" only when a parenthesis is open
##   - an operator typed first continues the last answer (× -> Ans×)
##   - "05" becomes "5"
##   - templates (xʸ, fraction, ⁿ√x, log_b) are filled slot by slot with
##     next_slot() (→ key): it moves to the next argument or leaves the slot
## Every insert returns false when the input was rejected.

const MAX_LENGTH := 200

## Binary operators (the minus sign is handled separately: it is also unary).
const BINARY_OPS := ["+", "×", "÷", "^", "^(", "mod", "&", "|", "⊕", "<<", ">>"]
## Operators applied to the value on their left.
const POSTFIX_OPS := ["!", "%", "^2", "^3", "^(−1)"]
## Insertions that continue the previous result (prefixed with "Ans").
const CONTINUATION_INSERTS := ["+", "−", "×", "÷", "^", "^(", "^2", "^3", "^(−1)", "!", "%", "mod",
	"&", "|", "⊕", "<<", ">>"]
## Multi-argument functions (name -> arity); others take one argument.
const MULTI_ARG := { "frac": 2, "root": 2, "logb": 2, "nCr": 2, "nPr": 2, "gcd": 2, "lcm": 2, "randint": 2 }
## Multi-character tokens removed in one go by backspace (sorted longest first).
const BACKSPACE_TOKENS := [
	"randint(", "asinh(", "acosh(", "atanh(", "floor(", "round(", "^(−1)",
	"asin(", "acos(", "atan(", "sinh(", "cosh(", "tanh(", "frac(", "root(", "logb(", "ceil(",
	"sin(", "cos(", "tan(", "log(", "abs(", "exp(", "nCr(", "nPr(", "gcd(", "lcm(",
	"10^(", "rand", "ln(", "Ans", "mod", "e^(", "√(", "∛(", "^(", "<<", ">>",
]
const HEX_DIGITS := "ABCDEF"

var text := ""
var just_evaluated := false
## Programmer mode: A-F are digits, no decimal point / scientific notation.
var programmer := false


func clear() -> void:
	text = ""
	just_evaluated = false


func is_empty() -> bool:
	return text == ""


## Inserts [param token] (a key insert string). Returns false if rejected.
func insert(token: String) -> bool:
	if just_evaluated:
		just_evaluated = false
		text = "Ans" if token in CONTINUATION_INSERTS else ""

	if text.length() + token.length() > MAX_LENGTH:
		return false

	if token in BINARY_OPS:
		return _insert_binary(token)
	if token == "−" or token == "~":
		return _insert_unary(token)
	if token in POSTFIX_OPS:
		return _insert_postfix(token)
	match token:
		".":
			return _insert_decimal()
		")":
			return _insert_rparen()
		";":
			return _insert_separator()
		"E":
			if programmer:
				return _insert_digit(token)
			return _insert_exponent()
		"frac(":
			# 2 then a⁄b: show "2 × ½", not a mixed number that would read as 2½
			if _trailing_number() != "":
				text += "×"
			text += token
			return true
	if token.length() == 1 and (token.is_valid_int() or (programmer and token in HEX_DIGITS)):
		return _insert_digit(token)
	text += token
	return true


## Removes the last token. Returns false if there was nothing to remove.
func backspace() -> bool:
	if just_evaluated:
		just_evaluated = false
		return true
	if text == "":
		return false
	for token in BACKSPACE_TOKENS:
		if text.ends_with(token):
			text = text.left(text.length() - token.length())
			return true
	text = text.left(text.length() - 1)
	return true


## → key: moves to the next slot of the innermost template — the next
## argument of a multi-argument function (";") or out of the slot (")").
func next_slot() -> bool:
	if just_evaluated or open_parens() <= 0:
		return false
	var open := innermost_open()
	if MULTI_ARG.get(open["name"], 1) > open["args"]:
		return _insert_separator()
	if text.ends_with("(") or text.ends_with(";") or _ends_with_operator():
		return false
	text += ")"
	return true


## ± key: changes the sign of the number being typed (or of the result).
func negate() -> bool:
	if just_evaluated:
		just_evaluated = false
		text = "−Ans"
		return true
	var operand := _trailing_operand()
	if operand == "":
		if text == "" or text.ends_with("(") or text.ends_with(";") or _ends_with_operator():
			return _insert_unary("−")
		return false
	var start := text.length() - operand.length()
	var before := text.left(start)
	if before.ends_with("−"):
		var previous := before.left(before.length() - 1)
		if previous == "" or previous.ends_with("(") or previous.ends_with(";") or _is_operator_end(previous):
			before = previous # unary minus: remove it
		else:
			before = previous + "+" # a − 3 -> a + 3
	elif before.ends_with("+"):
		before = before.left(before.length() - 1) + "−"
	else:
		before += "−"
	text = before + operand
	return true


## Number of "(" not yet closed (functions like "sin(" included).
func open_parens() -> int:
	return text.count("(") - text.count(")")


## Innermost unclosed "(": { "name": function name or "", "args": arguments started }.
func innermost_open() -> Dictionary:
	var depth := 0
	var separators := 0
	var i := text.length() - 1
	while i >= 0:
		var c := text[i]
		if c == ")":
			depth += 1
		elif c == "(":
			if depth == 0:
				var j := i
				while j > 0 and _is_letter(text[j - 1]):
					j -= 1
				return { "name": text.substr(j, i - j), "args": separators + 1 }
			depth -= 1
		elif c == ";" and depth == 0:
			separators += 1
		i -= 1
	return { "name": "", "args": 0 }


# --- Rules -----------------------------------------------------------------

func _insert_binary(op: String) -> bool:
	if text == "":
		text = "Ans" + op
		return true
	if text.ends_with("E") and not programmer:
		return false
	var original := text
	_strip_trailing_operators()
	if text == "" or text.ends_with("(") or text.ends_with(";"):
		text = original
		return false
	text += op
	return true


func _insert_unary(op: String) -> bool:
	# Unary minus / NOT are allowed after "(", an operator or at the start.
	if op == "−" and (text.ends_with("−") or text.ends_with("+")):
		text = text.left(text.length() - 1)
	elif op == "~" and text.ends_with("~"):
		text = text.left(text.length() - 1) # ~~x == x
		return true
	elif op == "~" and text != "" and not (text.ends_with("(") or _ends_with_operator()):
		return false
	text += op
	return true


func _insert_postfix(op: String) -> bool:
	if text == "":
		text = "Ans" + op
		return true
	if _ends_with_operator() or text.ends_with("(") or text.ends_with(";"):
		return false
	text += op
	return true


func _insert_decimal() -> bool:
	if programmer:
		return false
	var number := _trailing_number()
	if number.contains(".") or number.contains("E"):
		return false
	text += "." if number != "" else "0."
	return true


func _insert_rparen() -> bool:
	if open_parens() <= 0 or text.ends_with("(") or text.ends_with(";") or _ends_with_operator():
		return false
	text += ")"
	return true


func _insert_separator() -> bool:
	var open := innermost_open()
	if MULTI_ARG.get(open["name"], 1) <= open["args"]:
		return false
	if text.ends_with("(") or text.ends_with(";") or _ends_with_operator():
		return false
	text += ";"
	return true


func _insert_exponent() -> bool:
	var number := _trailing_number()
	if number == "" or number.contains("E") or number.ends_with("."):
		return false
	text += "E"
	return true


func _insert_digit(digit: String) -> bool:
	var number := _trailing_number()
	if number == "0":
		text = text.left(text.length() - 1) # "05" -> "5"
	text += digit
	return true


func _ends_with_operator() -> bool:
	return _is_operator_end(text)


func _is_operator_end(value: String) -> bool:
	for op in BINARY_OPS + ["−", "~"]:
		if value.ends_with(op):
			return true
	return value.ends_with("E") and not programmer


func _strip_trailing_operators() -> void:
	var changed := true
	while changed and text != "":
		changed = false
		for op in BINARY_OPS + ["−", "~"]:
			if text.ends_with(op):
				text = text.left(text.length() - op.length())
				changed = true


## The number being typed at the end of the expression ("12.5", "3E", "").
func _trailing_number() -> String:
	var i := text.length()
	while i > 0:
		var c := text[i - 1]
		if c.is_valid_int() or (not programmer and (c == "." or c == "E")) or (programmer and c in HEX_DIGITS):
			i -= 1
		elif not programmer and (c == "−" or c == "-") and i >= 2 and text[i - 2] == "E":
			i -= 1
		else:
			break
	var number := text.substr(i)
	# "Ans" ends with no digit; in programmer mode "A" of "Ans" is not a digit.
	return number


## Number or constant at the end (what ± applies to).
func _trailing_operand() -> String:
	for constant in ["Ans", "π", "φ", "e"]:
		if text.ends_with(constant) and not (constant == "e" and programmer):
			return constant
	return _trailing_number()


func _is_letter(c: String) -> bool:
	var code := c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
