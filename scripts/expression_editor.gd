extends RefCounted
## Holds the expression being typed and applies "smart" input rules so that
## the user can't easily build an invalid expression:
##   - consecutive operators replace each other (2+× -> 2×)
##   - a single decimal point per number, ".5" becomes "0.5"
##   - ")" only when a parenthesis is open
##   - an operator typed first continues the last answer (× -> Ans×)
##   - "05" becomes "5"
## Every insert returns false when the input was rejected.

const MAX_LENGTH := 160

## Binary operators (the minus sign is handled separately: it is also unary).
const BINARY_OPS := ["+", "×", "÷", "^", "mod"]
## Operators applied to the value on their left.
const POSTFIX_OPS := ["!", "%", "^2", "^3", "^(−1)"]
## Insertions that continue the previous result (prefixed with "Ans").
const CONTINUATION_INSERTS := ["+", "−", "×", "÷", "^", "^2", "^3", "^(−1)", "!", "%", "mod"]
## Multi-character tokens removed in one go by backspace.
const BACKSPACE_TOKENS := [
	"asin(", "acos(", "atan(", "sin(", "cos(", "tan(", "log(", "abs(",
	"ln(", "rand", "Ans", "mod", "^(−1)", "√(", "∛(", "e^(", "10^(",
]

var text := ""
var just_evaluated := false


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
	if token == "−":
		return _insert_minus()
	if token in POSTFIX_OPS:
		return _insert_postfix(token)
	match token:
		".":
			return _insert_decimal()
		")":
			return _insert_rparen()
		"E":
			return _insert_exponent()
	if token.length() == 1 and token.is_valid_int():
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


## Number of "(" not yet closed (functions like "sin(" included).
func open_parens() -> int:
	return text.count("(") - text.count(")")


# --- Rules -----------------------------------------------------------------

func _insert_binary(op: String) -> bool:
	if text == "":
		text = "Ans" + op
		return true
	if text.ends_with("E"):
		return false
	var original := text
	_strip_trailing_operators()
	if text == "" or text.ends_with("("):
		text = original
		return false
	text += op
	return true


func _insert_minus() -> bool:
	# Unary minus is allowed after "(", "×", "÷", "^", "mod" or at the start.
	if text.ends_with("−") or text.ends_with("+"):
		text = text.left(text.length() - 1)
	text += "−"
	return true


func _insert_postfix(op: String) -> bool:
	if text == "":
		text = "Ans" + op
		return true
	if _ends_with_operator() or text.ends_with("("):
		return false
	text += op
	return true


func _insert_decimal() -> bool:
	var number := _trailing_number()
	if number.contains(".") or number.contains("E"):
		return false
	text += "." if number != "" else "0."
	return true


func _insert_rparen() -> bool:
	if open_parens() <= 0 or text.ends_with("(") or _ends_with_operator():
		return false
	text += ")"
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
	for op in BINARY_OPS + ["−", "E"]:
		if text.ends_with(op):
			return true
	return false


func _strip_trailing_operators() -> void:
	var changed := true
	while changed and text != "":
		changed = false
		for op in BINARY_OPS + ["−"]:
			if text.ends_with(op):
				text = text.left(text.length() - op.length())
				changed = true


## The number being typed at the end of the expression ("12.5", "3E", "").
func _trailing_number() -> String:
	var i := text.length()
	while i > 0:
		var c := text[i - 1]
		if c.is_valid_int() or c == "." or c == "E":
			i -= 1
		elif (c == "−" or c == "-") and i >= 2 and text[i - 2] == "E":
			i -= 1
		else:
			break
	return text.substr(i)
