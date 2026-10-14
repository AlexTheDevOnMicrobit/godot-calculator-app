extends RefCounted
## Turns the linear expression typed on the keypad into a math tree used for
## the "textbook" display (fractions, roots, exponents...), and converts
## between expressions and LaTeX.
##
## The parser is tolerant: unfinished input ("√(2+", "frac(1;") gives open
## nodes, empty slots become placeholders and a caret marks where the next
## key will go.
##
## Node shapes (Dictionaries):
##   { "type": "row", "items": [node...] }
##   { "type": "text", "text": String, "kind": "num" | "op" | "name" | "symbol" }
##   { "type": "sup", "row": row }                 (attached to the previous item)
##   { "type": "paren", "row": row, "closed": bool }
##   { "type": "abs", "row": row, "closed": bool }
##   { "type": "root", "row": row, "index": row | null, "closed": bool }
##   { "type": "frac", "num": row, "den": row, "closed": bool }
##   { "type": "func", "name": String, "args": [row...], "closed": bool }
##   { "type": "logb", "base": row, "arg": row, "closed": bool }
##   { "type": "caret" }

const OPERATORS := ["+", "−", "-", "×", "÷", "mod", "&", "|", "⊕", "<<", ">>", "~", "=", "±"]
const NAMED := {
	"asin": "sin⁻¹", "acos": "cos⁻¹", "atan": "tan⁻¹",
	"asinh": "sinh⁻¹", "acosh": "cosh⁻¹", "atanh": "tanh⁻¹",
}
## Every word the parser knows (longest first), see Evaluator.FUNCTIONS.
const WORDS := [
	"randint", "asinh", "acosh", "atanh", "floor", "round",
	"asin", "acos", "atan", "sinh", "cosh", "tanh", "sqrt", "cbrt", "frac",
	"root", "logb", "ceil", "rand", "sin", "cos", "tan", "abs", "exp", "nCr",
	"nPr", "gcd", "lcm", "log", "mod", "Ans", "phi", "pi", "ln", "e",
]

var _text := ""
var _pos := 0
var _with_caret := false
var _caret_row = null


# --- Expression -> tree ----------------------------------------------------

## Parses [param text]. With [param with_caret], a caret node is added at the
## end of the innermost unfinished slot.
func parse(text: String, with_caret: bool = false) -> Dictionary:
	_text = text
	_pos = 0
	_with_caret = with_caret
	_caret_row = null
	var root := _parse_row([])
	while _pos < _text.length(): # stray ")" or ";" at top level
		root["items"].append(_text_node(_text[_pos], "symbol"))
		_pos += 1
		root["items"].append_array(_parse_row([])["items"])
	if with_caret:
		if _caret_row == null:
			_caret_row = root
		_caret_row["items"].append({ "type": "caret" })
	return root


func _row() -> Dictionary:
	return { "type": "row", "items": [] }


func _text_node(text: String, kind: String) -> Dictionary:
	return { "type": "text", "text": text, "kind": kind }


func _at_end() -> bool:
	return _pos >= _text.length()


func _parse_row(stops: Array) -> Dictionary:
	var row := _row()
	while not _at_end():
		var c := _text[_pos]
		if c in stops:
			return row
		row["items"].append(_parse_item(row))
	# Reached the end of the input inside this row: innermost open slot.
	if _caret_row == null:
		_caret_row = row
	return row


func _parse_item(row: Dictionary) -> Dictionary:
	var c := _text[_pos]
	if c.is_valid_int() or c == "." or c == ",":
		return _parse_number()
	if c == "^":
		_pos += 1
		return { "type": "sup", "row": _parse_exponent() }
	if c == "(":
		_pos += 1
		var inner := _parse_row([")"])
		return { "type": "paren", "row": inner, "closed": _consume(")") }
	if c == "√" or c == "∛":
		_pos += 1
		var index = null
		if c == "∛":
			index = _row()
			index["items"].append(_text_node("3", "num"))
		if _consume("("):
			var radicand := _parse_row([")"])
			return { "type": "root", "row": radicand, "index": index, "closed": _consume(")") }
		var single := _row()
		if not _at_end():
			single["items"].append(_parse_item(single))
		return { "type": "root", "row": single, "index": index, "closed": true }
	if c == "π":
		_pos += 1
		return _text_node("π", "name")
	if c == "φ":
		_pos += 1
		return _text_node("φ", "name")
	if c == "<" or c == ">":
		var op := _text.substr(_pos, 2)
		_pos += 2 if op in ["<<", ">>"] else 1
		return _text_node(op, "op")
	if c in OPERATORS:
		_pos += 1
		return _text_node("−" if c == "-" else c, "op")
	if _is_letter(c):
		return _parse_word()
	_pos += 1
	return _text_node(c, "symbol")


func _parse_number() -> Dictionary:
	var start := _pos
	while not _at_end() and (_text[_pos].is_valid_int() or _text[_pos] in [".", ","]):
		_pos += 1
	# Scientific notation 2E−3 stays in the number.
	if not _at_end() and _text[_pos] == "E":
		_pos += 1
		if not _at_end() and _text[_pos] in ["−", "-", "+"]:
			_pos += 1
		while not _at_end() and _text[_pos].is_valid_int():
			_pos += 1
	return _text_node(_text.substr(start, _pos - start), "num")


func _parse_word() -> Dictionary:
	var word := ""
	for candidate in WORDS:
		if _text.substr(_pos, candidate.length()) == candidate:
			word = candidate
			break
	if word == "":
		# Unknown letter (hex digit in programmer mode, typo...): keep as text.
		var start := _pos
		while not _at_end() and _is_letter(_text[_pos]):
			_pos += 1
		return _text_node(_text.substr(start, _pos - start), "num")
	_pos += word.length()
	match word:
		"pi":
			return _text_node("π", "name")
		"phi":
			return _text_node("φ", "name")
		"e", "Ans", "rand":
			return _text_node(word, "name")
		"mod":
			return _text_node("mod", "op")
	# Functions
	if not _consume("("):
		return _text_node(NAMED.get(word, word), "name")
	match word:
		"sqrt":
			var radicand := _parse_row([")"])
			return { "type": "root", "row": radicand, "index": null, "closed": _consume(")") }
		"cbrt":
			var radicand := _parse_row([")"])
			var three := _row()
			three["items"].append(_text_node("3", "num"))
			return { "type": "root", "row": radicand, "index": three, "closed": _consume(")") }
		"abs":
			var inner := _parse_row([")"])
			return { "type": "abs", "row": inner, "closed": _consume(")") }
	var args := _parse_args()
	var closed := _consume(")")
	match word:
		"frac":
			return { "type": "frac", "num": args[0], "den": _arg(args, 1), "closed": closed }
		"root":
			return { "type": "root", "index": args[0], "row": _arg(args, 1), "closed": closed }
		"logb":
			return { "type": "logb", "base": args[0], "arg": _arg(args, 1), "closed": closed }
	return { "type": "func", "name": NAMED.get(word, word), "args": args, "closed": closed }


## Arguments separated by ";" up to the closing parenthesis.
func _parse_args() -> Array:
	var args := [_parse_row([")", ";"])]
	while _consume(";"):
		args.append(_parse_row([")", ";"]))
	return args


## Missing argument: an empty row (shown as a placeholder).
func _arg(args: Array, index: int) -> Dictionary:
	return args[index] if index < args.size() else _row()


func _parse_exponent() -> Dictionary:
	if _consume("("):
		var inner := _parse_row([")"])
		_consume(")")
		return inner
	var row := _row()
	if _at_end():
		if _caret_row == null:
			_caret_row = row
		return row
	var c := _text[_pos]
	if c == "−" or c == "-": # x^−1
		_pos += 1
		row["items"].append(_text_node("−", "op"))
		if _at_end():
			return row
	row["items"].append(_parse_item(row))
	return row


func _consume(c: String) -> bool:
	if not _at_end() and _text[_pos] == c:
		_pos += 1
		return true
	return false


func _is_letter(c: String) -> bool:
	var code := c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


# --- Tree -> one-line text (history) ---------------------------------------

const SUPERSCRIPTS := {
	"0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷",
	"8": "⁸", "9": "⁹", "−": "⁻", "-": "⁻", "+": "⁺", "(": "⁽", ")": "⁾", "n": "ⁿ",
}
const SUBSCRIPTS := {
	"0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
}


## Readable one-line form: "frac(3;4)+root(3;27)" -> "3⁄4 + ³√27".
func to_linear(text: String, list_separator: String = ", ") -> String:
	return _linear_row(parse(text), list_separator).strip_edges()


func _linear_row(row: Dictionary, sep: String) -> String:
	var out := ""
	var previous = null
	for item in row["items"]:
		if item["type"] == "text" and item["kind"] == "op":
			var unary: bool = item["text"] in ["−", "~"] and (previous == null \
				or (previous["type"] == "text" and previous["kind"] == "op"))
			out += item["text"] if unary else " " + item["text"] + " "
		else:
			out += _linear_item(item, sep)
		previous = item
	return out


## Wraps in parentheses unless the row is a single simple item.
func _linear_group(row: Dictionary, sep: String) -> String:
	var inner := _linear_row(row, sep).strip_edges()
	if row["items"].size() == 1 and row["items"][0]["type"] in ["text", "paren", "abs"]:
		return inner
	return "(" + inner + ")"


func _script(row: Dictionary, table: Dictionary, sep: String) -> String:
	var plain := _linear_row(row, sep).replace(" ", "")
	var out := ""
	for c in plain:
		if not table.has(c):
			return ""
		out += table[c]
	return out


func _linear_item(node: Dictionary, sep: String) -> String:
	match node["type"]:
		"text":
			return node["text"]
		"sup":
			var small := _script(node["row"], SUPERSCRIPTS, sep)
			return small if small != "" else "^" + _linear_group(node["row"], sep)
		"paren":
			return "(" + _linear_row(node["row"], sep).strip_edges() + ")"
		"abs":
			return "|" + _linear_row(node["row"], sep).strip_edges() + "|"
		"root":
			var index := ""
			if node["index"] != null:
				index = _script(node["index"], SUPERSCRIPTS, sep)
				if index == "":
					index = "(" + _linear_row(node["index"], sep) + ")"
			return index + "√" + _linear_group(node["row"], sep)
		"frac":
			return _linear_group(node["num"], sep) + "⁄" + _linear_group(node["den"], sep)
		"logb":
			var base := _script(node["base"], SUBSCRIPTS, sep)
			if base == "":
				base = "_" + _linear_group(node["base"], sep)
			return "log" + base + "(" + _linear_row(node["arg"], sep).strip_edges() + ")"
		"func":
			var args: PackedStringArray = []
			for arg in node["args"]:
				args.append(_linear_row(arg, sep).strip_edges())
			return node["name"] + "(" + sep.join(args) + ")"
	return ""


# --- Tree -> LaTeX ---------------------------------------------------------

const LATEX_FUNCTIONS := {
	"sin": "\\sin", "cos": "\\cos", "tan": "\\tan", "sinh": "\\sinh", "cosh": "\\cosh",
	"tanh": "\\tanh", "ln": "\\ln", "log": "\\log", "exp": "\\exp", "gcd": "\\gcd",
	"sin⁻¹": "\\arcsin", "cos⁻¹": "\\arccos", "tan⁻¹": "\\arctan",
}


## LaTeX source for an expression (decimal point "." as LaTeX expects).
func to_latex(text: String) -> String:
	return _latex_row(parse(text)).strip_edges()


func _latex_row(row: Dictionary) -> String:
	var out := ""
	var previous = null
	for item in row["items"]:
		var unary: bool = item["type"] == "text" and item["text"] == "−" \
			and (previous == null or (previous["type"] == "text" and previous["kind"] == "op"))
		out += "-" if unary else _latex_item(item)
		previous = item
	return out


func _latex_group(row: Dictionary) -> String:
	return "{" + _latex_row(row) + "}"


func _latex_item(node: Dictionary) -> String:
	match node["type"]:
		"text":
			var text: String = node["text"]
			match text:
				"×":
					return " \\times "
				"÷":
					return " \\div "
				"−":
					return " - "
				"+":
					return " + "
				"mod":
					return " \\bmod "
				"±":
					return " \\pm "
				"=":
					return " = "
				"π":
					return "\\pi "
				"φ":
					return "\\varphi "
				"%":
					return "\\%"
				"Ans", "rand":
					return "\\mathrm{" + text + "}"
			if node["kind"] == "num":
				return text.replace(",", ".")
			if LATEX_FUNCTIONS.has(text):
				return LATEX_FUNCTIONS[text] + " "
			if text.length() > 1 and node["kind"] == "name":
				return "\\operatorname{" + text + "}"
			return text
		"sup":
			return "^" + _latex_group(node["row"])
		"paren":
			return "\\left(" + _latex_row(node["row"]) + "\\right)"
		"abs":
			return "\\left|" + _latex_row(node["row"]) + "\\right|"
		"root":
			if node["index"] != null:
				return "\\sqrt[" + _latex_row(node["index"]) + "]" + _latex_group(node["row"])
			return "\\sqrt" + _latex_group(node["row"])
		"frac":
			return "\\frac" + _latex_group(node["num"]) + _latex_group(node["den"])
		"logb":
			return "\\log_" + _latex_group(node["base"]) + "\\left(" + _latex_row(node["arg"]) + "\\right)"
		"func":
			var name: String = node["name"]
			var args: PackedStringArray = []
			for arg in node["args"]:
				args.append(_latex_row(arg))
			match name:
				"nCr":
					return "\\binom" + "{" + args[0] + "}{" + (args[1] if args.size() > 1 else "") + "}"
				"floor":
					return "\\left\\lfloor " + args[0] + " \\right\\rfloor"
				"ceil":
					return "\\left\\lceil " + args[0] + " \\right\\rceil"
			var command: String = LATEX_FUNCTIONS.get(name, "\\operatorname{" + name + "}")
			return command + "\\left(" + ", ".join(args) + "\\right)"
	return ""


# --- LaTeX -> expression ---------------------------------------------------

const LATEX_TO_TEXT := {
	"\\times": "×", "\\cdot": "×", "\\div": "÷", "\\pi": "π", "\\varphi": "φ", "\\phi": "φ",
	"\\bmod": "mod", "\\mod": "mod", "\\%": "%",
	"\\arcsin": "asin", "\\arccos": "acos", "\\arctan": "atan",
	"\\sinh": "sinh", "\\cosh": "cosh", "\\tanh": "tanh",
	"\\sin": "sin", "\\cos": "cos", "\\tan": "tan", "\\ln": "ln", "\\log": "log", "\\exp": "exp",
	"\\gcd": "gcd",
}

var _latex := ""
var _lpos := 0


## Best-effort conversion of LaTeX (\frac, \sqrt, ^{}, \binom, \left|...) into
## a calculator expression. Returns "" when the input can't be understood.
func latex_to_expression(latex: String) -> String:
	_latex = latex.strip_edges().trim_prefix("$$").trim_suffix("$$").trim_prefix("$").trim_suffix("$")
	_latex = _latex.replace("\\left", "").replace("\\right", "").replace("\\,", "").replace("\\!", "")
	_latex = _latex.replace("\\dfrac", "\\frac").replace("\\tfrac", "\\frac")
	_lpos = 0
	var result := _latex_sequence("")
	return result.replace(" ", "").replace("-", "−").replace("*", "×").replace("/", "÷")


func _latex_sequence(stop: String) -> String:
	var out := ""
	while _lpos < _latex.length():
		var c := _latex[_lpos]
		if stop != "" and c == stop:
			return out
		if c == "{":
			_lpos += 1
			out += "(" + _latex_sequence("}") + ")"
			_lpos += 1
		elif c == "\\":
			out += _latex_command()
		elif c == "^":
			_lpos += 1
			out += "^" + _latex_argument()
		elif c == "|":
			_lpos += 1
			out += "abs(" + _latex_sequence("|") + ")"
			_lpos += 1
		elif c == ",":
			out += ";"
			_lpos += 1
		else:
			out += c
			_lpos += 1
	return out


## One argument: a {group} (parenthesised unless trivial) or a single char.
func _latex_argument(parenthesise := true) -> String:
	while _lpos < _latex.length() and _latex[_lpos] == " ":
		_lpos += 1
	if _lpos >= _latex.length():
		return ""
	if _latex[_lpos] == "{":
		_lpos += 1
		var inner := _latex_sequence("}")
		_lpos += 1
		if not parenthesise or (inner.is_valid_float() and not inner.begins_with("-")):
			return inner
		return "(" + inner + ")"
	if _latex[_lpos] == "\\":
		return _latex_command()
	var c := _latex[_lpos]
	_lpos += 1
	return c


func _latex_command() -> String:
	var start := _lpos
	_lpos += 1
	while _lpos < _latex.length() and _is_letter(_latex[_lpos]):
		_lpos += 1
	if _lpos == start + 1 and _lpos < _latex.length(): # \% \{ ...
		_lpos += 1
	var command := _latex.substr(start, _lpos - start)
	match command:
		"\\frac":
			var num := _latex_argument(false)
			var den := _latex_argument(false)
			return "frac(" + num + ";" + den + ")"
		"\\binom":
			var n := _latex_argument(false)
			var k := _latex_argument(false)
			return "nCr(" + n + ";" + k + ")"
		"\\sqrt":
			if _lpos < _latex.length() and _latex[_lpos] == "[":
				_lpos += 1
				var index := _latex_sequence("]")
				_lpos += 1
				return "root(" + index + ";" + _latex_argument(false) + ")"
			return "√(" + _latex_argument(false) + ")"
		"\\log":
			if _lpos < _latex.length() and _latex[_lpos] == "_":
				_lpos += 1
				var base := _latex_argument(false)
				var arg := ""
				if _lpos < _latex.length() and _latex[_lpos] == "(":
					_lpos += 1
					arg = _latex_sequence(")")
					_lpos += 1
				else:
					arg = _latex_argument(false)
				return "logb(" + base + ";" + arg + ")"
			return "log"
		"\\lfloor":
			var inner := _latex_until("\\rfloor")
			return "floor(" + inner + ")"
		"\\lceil":
			var inner := _latex_until("\\rceil")
			return "ceil(" + inner + ")"
		"\\mathrm", "\\operatorname", "\\text":
			return _latex_argument(false)
	return LATEX_TO_TEXT.get(command, "")


func _latex_until(end: String) -> String:
	var index := _latex.find(end, _lpos)
	if index < 0:
		index = _latex.length()
	var saved := _latex
	var inner_source := _latex.substr(_lpos, index - _lpos)
	var after := index + end.length()
	_latex = inner_source
	_lpos = 0
	var inner := _latex_sequence("")
	_latex = saved
	_lpos = after
	return inner
