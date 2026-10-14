extends RefCounted
## Keypad layouts for each mode and the catalog of the f(x) functions panel.
##
## Each key: id (action), label, insert (text typed), optional label2/insert2
## (the "2nd" function, shown as a small hint on the key), style (theme type
## variation) and tip/tip2 (tooltip translation keys).

const MODES := ["simple", "scientific", "programmer", "converter"]

const SIMPLE := { "columns": 4, "keys": [
	{ "id": "clear", "label": "AC", "style": "ClearButton", "tip": "TIP_CLEAR" },
	{ "id": "back", "label": "", "icon": "res://assets/icons/backspace.svg", "style": "ClearButton", "tip": "TIP_BACKSPACE" },
	{ "id": "percent", "label": "%", "insert": "%", "style": "FunctionButton", "tip": "TIP_PERCENT" },
	{ "id": "div", "label": "÷", "insert": "÷", "style": "OperatorButton", "tip": "TIP_DIV" },
	{ "id": "7", "label": "7", "insert": "7", "style": "DigitButton" },
	{ "id": "8", "label": "8", "insert": "8", "style": "DigitButton" },
	{ "id": "9", "label": "9", "insert": "9", "style": "DigitButton" },
	{ "id": "mul", "label": "×", "insert": "×", "style": "OperatorButton", "tip": "TIP_MUL" },
	{ "id": "4", "label": "4", "insert": "4", "style": "DigitButton" },
	{ "id": "5", "label": "5", "insert": "5", "style": "DigitButton" },
	{ "id": "6", "label": "6", "insert": "6", "style": "DigitButton" },
	{ "id": "sub", "label": "−", "insert": "−", "style": "OperatorButton", "tip": "TIP_SUB" },
	{ "id": "1", "label": "1", "insert": "1", "style": "DigitButton" },
	{ "id": "2", "label": "2", "insert": "2", "style": "DigitButton" },
	{ "id": "3", "label": "3", "insert": "3", "style": "DigitButton" },
	{ "id": "add", "label": "+", "insert": "+", "style": "OperatorButton", "tip": "TIP_ADD" },
	{ "id": "neg", "label": "±", "style": "DigitButton", "tip": "TIP_NEGATE" },
	{ "id": "0", "label": "0", "insert": "0", "style": "DigitButton" },
	{ "id": "dot", "label": ".", "insert": ".", "style": "DigitButton", "tip": "TIP_DECIMAL" },
	{ "id": "equals", "label": "=", "style": "EqualsButton", "tip": "TIP_EQUALS" },
] }

const SCIENTIFIC := { "columns": 5, "keys": [
	{ "id": "second", "label": "2nd", "style": "ToggleButton", "tip": "TIP_SECOND" },
	{ "id": "pi", "label": "π", "insert": "π", "label2": "e", "insert2": "e", "style": "FunctionButton", "tip": "TIP_PI", "tip2": "TIP_E" },
	{ "id": "next", "label": "→", "style": "FunctionButton", "tip": "TIP_NEXT" },
	{ "id": "lparen", "label": "(", "insert": "(", "style": "FunctionButton", "tip": "TIP_LPAREN" },
	{ "id": "rparen", "label": ")", "insert": ")", "style": "FunctionButton", "tip": "TIP_RPAREN" },

	{ "id": "sin", "label": "sin", "insert": "sin(", "label2": "sin⁻¹", "insert2": "asin(", "style": "FunctionButton", "tip": "TIP_SIN", "tip2": "TIP_ASIN" },
	{ "id": "cos", "label": "cos", "insert": "cos(", "label2": "cos⁻¹", "insert2": "acos(", "style": "FunctionButton", "tip": "TIP_COS", "tip2": "TIP_ACOS" },
	{ "id": "tan", "label": "tan", "insert": "tan(", "label2": "tan⁻¹", "insert2": "atan(", "style": "FunctionButton", "tip": "TIP_TAN", "tip2": "TIP_ATAN" },
	{ "id": "ln", "label": "ln", "insert": "ln(", "label2": "eˣ", "insert2": "e^(", "style": "FunctionButton", "tip": "TIP_LN", "tip2": "TIP_EXP" },
	{ "id": "log", "label": "log", "insert": "log(", "label2": "10ˣ", "insert2": "10^(", "style": "FunctionButton", "tip": "TIP_LOG", "tip2": "TIP_POW10" },

	{ "id": "square", "label": "x²", "insert": "^2", "label2": "x³", "insert2": "^3", "style": "FunctionButton", "tip": "TIP_SQUARE", "tip2": "TIP_CUBE" },
	{ "id": "power", "label": "xʸ", "insert": "^(", "label2": "ⁿ√x", "insert2": "root(", "style": "FunctionButton", "tip": "TIP_POWER", "tip2": "TIP_NROOT" },
	{ "id": "sqrt", "label": "√", "insert": "√(", "label2": "∛", "insert2": "∛(", "style": "FunctionButton", "tip": "TIP_SQRT", "tip2": "TIP_CBRT" },
	{ "id": "frac", "label": "a⁄b", "insert": "frac(", "label2": "|x|", "insert2": "abs(", "style": "FunctionButton", "tip": "TIP_FRAC", "tip2": "TIP_ABS" },
	{ "id": "sd", "label": "S⇔D", "label2": "1/x", "insert2": "^(−1)", "style": "FunctionButton", "tip": "TIP_SD", "tip2": "TIP_INV" },

	{ "id": "mc", "label": "MC", "style": "MemoryButton", "tip": "TIP_MC" },
	{ "id": "mr", "label": "MR", "style": "MemoryButton", "tip": "TIP_MR" },
	{ "id": "mplus", "label": "M+", "style": "MemoryButton", "tip": "TIP_MPLUS" },
	{ "id": "mminus", "label": "M−", "style": "MemoryButton", "tip": "TIP_MMINUS" },
	{ "id": "fx", "label": "f(x)", "style": "ToggleButton", "tip": "TIP_FX" },

	{ "id": "7", "label": "7", "insert": "7", "style": "DigitButton" },
	{ "id": "8", "label": "8", "insert": "8", "style": "DigitButton" },
	{ "id": "9", "label": "9", "insert": "9", "style": "DigitButton" },
	{ "id": "back", "label": "", "icon": "res://assets/icons/backspace.svg", "style": "ClearButton", "tip": "TIP_BACKSPACE" },
	{ "id": "clear", "label": "AC", "style": "ClearButton", "tip": "TIP_CLEAR" },

	{ "id": "4", "label": "4", "insert": "4", "style": "DigitButton" },
	{ "id": "5", "label": "5", "insert": "5", "style": "DigitButton" },
	{ "id": "6", "label": "6", "insert": "6", "style": "DigitButton" },
	{ "id": "mul", "label": "×", "insert": "×", "style": "OperatorButton", "tip": "TIP_MUL" },
	{ "id": "div", "label": "÷", "insert": "÷", "style": "OperatorButton", "tip": "TIP_DIV" },

	{ "id": "1", "label": "1", "insert": "1", "style": "DigitButton" },
	{ "id": "2", "label": "2", "insert": "2", "style": "DigitButton" },
	{ "id": "3", "label": "3", "insert": "3", "style": "DigitButton" },
	{ "id": "add", "label": "+", "insert": "+", "style": "OperatorButton", "tip": "TIP_ADD" },
	{ "id": "sub", "label": "−", "insert": "−", "style": "OperatorButton", "tip": "TIP_SUB" },

	{ "id": "0", "label": "0", "insert": "0", "style": "DigitButton" },
	{ "id": "dot", "label": ".", "insert": ".", "label2": "EXP", "insert2": "E", "style": "DigitButton", "tip": "TIP_DECIMAL", "tip2": "TIP_EXPONENT" },
	{ "id": "neg", "label": "±", "label2": "%", "insert2": "%", "style": "DigitButton", "tip": "TIP_NEGATE", "tip2": "TIP_PERCENT" },
	{ "id": "ans", "label": "Ans", "insert": "Ans", "label2": "x!", "insert2": "!", "style": "FunctionButton", "tip": "TIP_ANS", "tip2": "TIP_FACT" },
	{ "id": "equals", "label": "=", "style": "EqualsButton", "tip": "TIP_EQUALS" },
] }

const PROGRAMMER := { "columns": 5, "keys": [
	{ "id": "A", "label": "A", "insert": "A", "style": "DigitButton" },
	{ "id": "B", "label": "B", "insert": "B", "style": "DigitButton" },
	{ "id": "and", "label": "AND", "insert": "&", "style": "FunctionButton", "tip": "TIP_AND" },
	{ "id": "or", "label": "OR", "insert": "|", "style": "FunctionButton", "tip": "TIP_OR" },
	{ "id": "clear", "label": "AC", "style": "ClearButton", "tip": "TIP_CLEAR" },

	{ "id": "C", "label": "C", "insert": "C", "style": "DigitButton" },
	{ "id": "D", "label": "D", "insert": "D", "style": "DigitButton" },
	{ "id": "xor", "label": "XOR", "insert": "⊕", "style": "FunctionButton", "tip": "TIP_XOR" },
	{ "id": "not", "label": "NOT", "insert": "~", "style": "FunctionButton", "tip": "TIP_NOT" },
	{ "id": "back", "label": "", "icon": "res://assets/icons/backspace.svg", "style": "ClearButton", "tip": "TIP_BACKSPACE" },

	{ "id": "E", "label": "E", "insert": "E", "style": "DigitButton" },
	{ "id": "F", "label": "F", "insert": "F", "style": "DigitButton" },
	{ "id": "shl", "label": "<<", "insert": "<<", "style": "FunctionButton", "tip": "TIP_SHL" },
	{ "id": "shr", "label": ">>", "insert": ">>", "style": "FunctionButton", "tip": "TIP_SHR" },
	{ "id": "div", "label": "÷", "insert": "÷", "style": "OperatorButton", "tip": "TIP_DIV" },

	{ "id": "7", "label": "7", "insert": "7", "style": "DigitButton" },
	{ "id": "8", "label": "8", "insert": "8", "style": "DigitButton" },
	{ "id": "9", "label": "9", "insert": "9", "style": "DigitButton" },
	{ "id": "lparen", "label": "(", "insert": "(", "style": "FunctionButton", "tip": "TIP_LPAREN" },
	{ "id": "mul", "label": "×", "insert": "×", "style": "OperatorButton", "tip": "TIP_MUL" },

	{ "id": "4", "label": "4", "insert": "4", "style": "DigitButton" },
	{ "id": "5", "label": "5", "insert": "5", "style": "DigitButton" },
	{ "id": "6", "label": "6", "insert": "6", "style": "DigitButton" },
	{ "id": "rparen", "label": ")", "insert": ")", "style": "FunctionButton", "tip": "TIP_RPAREN" },
	{ "id": "sub", "label": "−", "insert": "−", "style": "OperatorButton", "tip": "TIP_SUB" },

	{ "id": "1", "label": "1", "insert": "1", "style": "DigitButton" },
	{ "id": "2", "label": "2", "insert": "2", "style": "DigitButton" },
	{ "id": "3", "label": "3", "insert": "3", "style": "DigitButton" },
	{ "id": "mod", "label": "mod", "insert": "mod", "style": "FunctionButton", "tip": "TIP_MOD" },
	{ "id": "add", "label": "+", "insert": "+", "style": "OperatorButton", "tip": "TIP_ADD" },

	{ "id": "neg", "label": "±", "style": "DigitButton", "tip": "TIP_NEGATE" },
	{ "id": "0", "label": "0", "insert": "0", "style": "DigitButton" },
	{ "id": "ans", "label": "Ans", "insert": "Ans", "style": "FunctionButton", "tip": "TIP_ANS" },
	{ "id": "base", "label": "BASE", "style": "ToggleButton", "tip": "TIP_BASE" },
	{ "id": "equals", "label": "=", "style": "EqualsButton", "tip": "TIP_EQUALS" },
] }

const CONVERTER := { "columns": 4, "keys": [
	{ "id": "7", "label": "7", "style": "DigitButton" },
	{ "id": "8", "label": "8", "style": "DigitButton" },
	{ "id": "9", "label": "9", "style": "DigitButton" },
	{ "id": "back", "label": "", "icon": "res://assets/icons/backspace.svg", "style": "ClearButton", "tip": "TIP_BACKSPACE" },
	{ "id": "4", "label": "4", "style": "DigitButton" },
	{ "id": "5", "label": "5", "style": "DigitButton" },
	{ "id": "6", "label": "6", "style": "DigitButton" },
	{ "id": "clear", "label": "AC", "style": "ClearButton", "tip": "TIP_CLEAR" },
	{ "id": "1", "label": "1", "style": "DigitButton" },
	{ "id": "2", "label": "2", "style": "DigitButton" },
	{ "id": "3", "label": "3", "style": "DigitButton" },
	{ "id": "swap", "label": "⇅", "style": "OperatorButton", "tip": "TIP_SWAP" },
	{ "id": "neg", "label": "±", "style": "DigitButton", "tip": "TIP_NEGATE" },
	{ "id": "0", "label": "0", "style": "DigitButton" },
	{ "id": "dot", "label": ".", "style": "DigitButton", "tip": "TIP_DECIMAL" },
	{ "id": "copy", "label": "⧉", "style": "EqualsButton", "tip": "TIP_COPY" },
] }

## f(x) panel: [category translation key, [[label, insert], ...]]
const FUNCTION_CATALOG := [
	["FX_TRIG", [["sin", "sin("], ["cos", "cos("], ["tan", "tan("], ["sin⁻¹", "asin("], ["cos⁻¹", "acos("], ["tan⁻¹", "atan("],
		["sinh", "sinh("], ["cosh", "cosh("], ["tanh", "tanh("], ["sinh⁻¹", "asinh("], ["cosh⁻¹", "acosh("], ["tanh⁻¹", "atanh("]]],
	["FX_POWERS", [["x²", "^2"], ["x³", "^3"], ["xʸ", "^("], ["x⁻¹", "^(−1)"], ["eˣ", "e^("], ["10ˣ", "10^("],
		["√", "√("], ["∛", "∛("], ["ⁿ√x", "root("]]],
	["FX_LOG", [["ln", "ln("], ["log", "log("], ["log_b", "logb("]]],
	["FX_COMBI", [["x!", "!"], ["nCr", "nCr("], ["nPr", "nPr("], ["gcd", "gcd("], ["lcm", "lcm("], ["mod", "mod"]]],
	["FX_NUMBERS", [["|x|", "abs("], ["round", "round("], ["floor", "floor("], ["ceil", "ceil("], ["a⁄b", "frac("], ["%", "%"]]],
	["FX_RANDOM", [["Rand", "rand"], ["RandInt", "randint("]]],
	["FX_CONSTANTS", [["π", "π"], ["e", "e"], ["φ", "φ"], ["Ans", "Ans"]]],
]


static func layout(mode: String) -> Dictionary:
	match mode:
		"simple":
			return SIMPLE
		"programmer":
			return PROGRAMMER
		"converter":
			return CONVERTER
	return SCIENTIFIC
