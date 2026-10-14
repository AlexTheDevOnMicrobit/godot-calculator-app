extends RefCounted
## Test suite shared by the headless test runner (CI) and the in-app
## "On-screen tests" panel, so the exact same checks run on every device.

const Evaluator := preload("res://scripts/evaluator.gd")
const ExpressionEditor := preload("res://scripts/expression_editor.gd")
const MathFormat := preload("res://scripts/math_format.gd")
const ProgrammerEvaluator := preload("res://scripts/programmer_evaluator.gd")
const Units := preload("res://scripts/units.gd")
const Knowledge := preload("res://scripts/knowledge.gd")
const Keypads := preload("res://scripts/keypads.gd")

var passed := 0
var failed := 0
var failures: PackedStringArray = []
var sections: Array = [] # [{ "name": String, "passed": int, "total": int }]

var _section_passed := 0
var _section_total := 0


## Runs every section and returns self (for chaining).
func run() -> RefCounted:
	_section("Arithmetic", _test_arithmetic)
	_section("Scientific", _test_scientific)
	_section("Trigonometry", _test_trigonometry)
	_section("Errors", _test_errors)
	_section("Formatting", _test_formatting)
	_section("Input rules", _test_input_rules)
	_section("Functions", _test_functions)
	_section("Fractions", _test_fractions)
	_section("LaTeX", _test_latex)
	_section("Programmer", _test_programmer)
	_section("Converter", _test_converter)
	_section("Knowledge", _test_knowledge)
	_section("Translations", _test_translations)
	return self


func total() -> int:
	return passed + failed


# --- Sections --------------------------------------------------------------

func _test_arithmetic() -> void:
	var ev := Evaluator.new()
	_value(ev, "1+2", 3.0)
	_value(ev, "2+3×4", 14.0)
	_value(ev, "(2+3)×4", 20.0)
	_value(ev, "10÷4", 2.5)
	_value(ev, "7−10", -3.0)
	_value(ev, "2*3/4", 1.5)
	_value(ev, "−5+2", -3.0)
	_value(ev, "2×−3", -6.0)
	_value(ev, "0.1+0.2", 0.3)
	_value(ev, "1,5+1", 2.5)
	_value(ev, ".5×2", 1.0)
	_value(ev, "3(4+1)", 15.0)
	_value(ev, "(1+1)(2+2)", 8.0)
	_value(ev, "(1+1)2", 4.0)
	_value(ev, "(2+3", 5.0) # auto-closed parenthesis
	_value(ev, "50%", 0.5)
	_value(ev, "200×10%", 20.0)
	_value(ev, "10 mod 3", 1.0)
	_value(ev, "−7 mod 3", 2.0)
	ev.last_answer = 42.0
	_value(ev, "Ans+1", 43.0)
	_value(ev, "2Ans", 84.0)


func _test_scientific() -> void:
	var ev := Evaluator.new()
	_value(ev, "2^10", 1024.0)
	_value(ev, "2^3^2", 512.0)
	_value(ev, "−2^2", -4.0)
	_value(ev, "(−2)^2", 4.0)
	_value(ev, "2^(−1)", 0.5)
	_value(ev, "√(16)", 4.0)
	_value(ev, "√9+1", 4.0)
	_value(ev, "∛(−27)", -3.0)
	_value(ev, "(−8)^(1/3)", -2.0)
	_value(ev, "5!", 120.0)
	_value(ev, "0!", 1.0)
	_value(ev, "abs(−4.5)", 4.5)
	_value(ev, "π", PI)
	_value(ev, "2π", TAU)
	_value(ev, "e", exp(1.0))
	_value(ev, "1.5E3", 1500.0)
	_value(ev, "2E−3", 0.002)
	_value(ev, "log(1000)", 3.0)
	_value(ev, "ln(e)", 1.0)
	_value(ev, "e^(2)", exp(2.0))
	_value(ev, "10^(2)", 100.0)
	var r := ev.evaluate("rand")
	_check(r["ok"] and r["value"] >= 0.0 and r["value"] < 1.0, "rand in [0, 1)")


func _test_trigonometry() -> void:
	var ev := Evaluator.new()
	ev.angle_mode = Evaluator.AngleMode.DEG
	_value(ev, "sin(30)", 0.5)
	_value(ev, "cos(60)", 0.5)
	_value(ev, "sin(180)", 0.0)
	_value(ev, "tan(45)", 1.0)
	_value(ev, "asin(1)", 90.0)
	_value(ev, "acos(0)", 90.0)
	_value(ev, "atan(1)", 45.0)
	_value(ev, "2sin(30)", 1.0)
	_error(ev, "tan(90)", Evaluator.ERR_DOMAIN)
	ev.angle_mode = Evaluator.AngleMode.RAD
	_value(ev, "sin(π/2)", 1.0)
	_value(ev, "cos(π)", -1.0)
	_value(ev, "atan(1)", PI / 4.0)


func _test_errors() -> void:
	var ev := Evaluator.new()
	_error(ev, "1÷0", Evaluator.ERR_DIV_ZERO)
	_error(ev, "5 mod 0", Evaluator.ERR_DIV_ZERO)
	_error(ev, "√(−1)", Evaluator.ERR_DOMAIN)
	_error(ev, "ln(0)", Evaluator.ERR_DOMAIN)
	_error(ev, "asin(2)", Evaluator.ERR_DOMAIN)
	_error(ev, "(−1)!", Evaluator.ERR_DOMAIN)
	_error(ev, "2.5!", Evaluator.ERR_DOMAIN)
	_error(ev, "171!", Evaluator.ERR_OVERFLOW)
	_error(ev, "10^(400)", Evaluator.ERR_OVERFLOW)
	_error(ev, "", Evaluator.ERR_SYNTAX)
	_error(ev, "2+", Evaluator.ERR_SYNTAX)
	_error(ev, "×3", Evaluator.ERR_SYNTAX)
	_error(ev, "1..2", Evaluator.ERR_SYNTAX)
	_error(ev, "2)", Evaluator.ERR_SYNTAX)
	_error(ev, "foo(2)", Evaluator.ERR_SYNTAX)
	_error(ev, "()", Evaluator.ERR_SYNTAX)
	_error(ev, "2 3", Evaluator.ERR_SYNTAX)


func _test_formatting() -> void:
	_format(0.0, ".", "", "0")
	_format(3.0, ".", "", "3")
	_format(-2.5, ".", "", "-2.5")
	_format(2.5, ",", "", "2,5")
	_format(0.1 + 0.2, ".", "", "0.3")
	_format(1.0 / 3.0, ".", "", "0.333333333333")
	_format(123456789.0, ".", "", "123456789")
	_format(1e20, ".", "", "1E20")
	_format(1.5e-12, ".", "", "1.5E-12")
	_format(PI, ".", "", "3.14159265359")
	_format(1234567.5, ".", ",", "1,234,567.5")
	_format(-1234.5, ",", " ", "-1 234,5")
	_format(999.0, ".", ",", "999")


func _test_input_rules() -> void:
	_typed(["2", "+", "×"], "2×")
	_typed(["2", "×", "−"], "2×−")
	_typed(["2", "×", "−", "+"], "2+")
	_typed(["(", "×"], "(")
	_typed([".", "5"], "0.5")
	_typed(["1", ".", "2", "."], "1.2")
	_typed([")"], "")
	_typed(["(", "2", ")", ")"], "(2)")
	_typed(["0", "5"], "5")
	_typed(["1", "0", "0"], "100")
	_typed(["×"], "Ans×")
	_typed(["!"], "Ans!")
	_typed(["2", "E", "−", "3"], "2E−3")
	_typed(["E"], "")
	_typed(["2", "E", "+"], "2E")
	_typed(["sin(", "×"], "sin(")
	_typed(["sin(", "3", "0", ")"], "sin(30)")
	_typed(["2", "^(", "1", "0"], "2^(10")
	_typed(["frac(", ";"], "frac(")
	_typed(["frac(", "1", ";", "2", ";"], "frac(1;2")
	_typed(["2", "frac("], "2×frac(")
	_typed(["sin(", "3", "0", ";"], "sin(30")
	_typed(["frac(", "1", "→", "2", "→"], "frac(1;2)")
	_typed(["2", "^(", "3", "→", "+", "1"], "2^(3)+1")
	_typed(["root(", "3", "→"], "root(3;")
	_typed(["→"], "")
	_typed(["5", "±"], "−5")
	_typed(["−", "5", "±"], "5")
	_typed(["2", "−", "3", "±"], "2+3")
	_typed(["2", "+", "3", "±"], "2−3")
	_typed(["2", "×", "3", "±"], "2×−3")
	_typed(["±"], "−")

	var editor := ExpressionEditor.new()
	for token in ["2", "+", "sin("]:
		editor.insert(token)
	editor.backspace()
	_check(editor.text == "2+", "backspace removes 'sin(' (got '%s')" % editor.text)
	editor.text = "Ans"
	editor.just_evaluated = true
	editor.insert("5")
	_check(editor.text == "5", "digit after result starts a new expression (got '%s')" % editor.text)
	editor.text = "Ans"
	editor.just_evaluated = true
	editor.insert("+")
	_check(editor.text == "Ans+", "operator after result continues with Ans (got '%s')" % editor.text)


func _test_functions() -> void:
	var ev := Evaluator.new()
	_value(ev, "frac(3;4)", 0.75)
	_value(ev, "root(3;27)", 3.0)
	_value(ev, "root(3;−8)", -2.0)
	_value(ev, "root(4;16)", 2.0)
	_value(ev, "logb(2;8)", 3.0)
	_value(ev, "nCr(5;2)", 10.0)
	_value(ev, "nCr(52;5)", 2598960.0)
	_value(ev, "nPr(5;2)", 20.0)
	_value(ev, "gcd(12;18)", 6.0)
	_value(ev, "lcm(4;6)", 12.0)
	_value(ev, "floor(2.7)", 2.0)
	_value(ev, "ceil(2.1)", 3.0)
	_value(ev, "round(2.5)", 3.0)
	_value(ev, "asinh(0)", 0.0)
	_value(ev, "acosh(1)", 0.0)
	_value(ev, "atanh(0.5)", 0.5 * log(3.0))
	_value(ev, "φ", (1.0 + sqrt(5.0)) / 2.0)
	_value(ev, "2^(1+2)", 8.0)
	_value(ev, "esin(90)", exp(1.0))
	_value(ev, "2frac(1;2)", 1.0)
	var r := ev.evaluate("randint(1;6)")
	_check(r["ok"] and r["value"] >= 1.0 and r["value"] <= 6.0 and r["value"] == floorf(r["value"]), "randint(1;6)")
	_error(ev, "root(2;−4)", Evaluator.ERR_DOMAIN)
	_error(ev, "logb(1;5)", Evaluator.ERR_DOMAIN)
	_error(ev, "nCr(2;5)", Evaluator.ERR_DOMAIN)
	_error(ev, "frac(1;0)", Evaluator.ERR_DIV_ZERO)
	_error(ev, "frac(1)", Evaluator.ERR_SYNTAX)
	_error(ev, "sin(1;2)", Evaluator.ERR_SYNTAX)
	_format(2.0 / 3.0, ".", "", "0.666666666667")
	var fixed := Evaluator.format_number(PI, ".", "", 2)
	_check(fixed == "3.14", "fixed precision 2 (got %s)" % fixed)
	fixed = Evaluator.format_number(-0.001, ",", "", 2)
	_check(fixed == "0,00", "fixed precision avoids -0 (got %s)" % fixed)


func _test_fractions() -> void:
	_fraction(0.75, [3, 4])
	_fraction(-1.0 / 3.0, [-1, 3])
	_fraction(22.0 / 7.0, [22, 7])
	_fraction(0.1 + 0.2, [3, 10])
	_fraction(2.0, [])
	_fraction(PI, [])
	_fraction(sqrt(2.0), [])


func _test_latex() -> void:
	var mf := MathFormat.new()
	_latex(mf, "frac(1;2)+√(16)", "\\frac{1}{2} + \\sqrt{16}")
	_latex(mf, "root(3;8)×2^(10)", "\\sqrt[3]{8} \\times 2^{10}")
	_latex(mf, "sin(30)÷π", "\\sin\\left(30\\right) \\div \\pi")
	_latex(mf, "abs(−2)", "\\left|-2\\right|")
	_latex(mf, "nCr(5;2)", "\\binom{5}{2}")
	_latex(mf, "logb(2;8)", "\\log_{2}\\left(8\\right)")
	_latex(mf, "asin(1)", "\\arcsin\\left(1\\right)")
	_from_latex(mf, "\\frac{1}{2}+\\sqrt{16}", 4.5)
	_from_latex(mf, "$2^{10}$", 1024.0)
	_from_latex(mf, "\\sqrt[3]{27} \\cdot 2", 6.0)
	_from_latex(mf, "\\binom{5}{2}", 10.0)
	_from_latex(mf, "\\left|-3\\right| \\times 2", 6.0)
	_from_latex(mf, "\\log_{2}\\left(8\\right)", 3.0)
	_from_latex(mf, "2\\pi", TAU)
	# Round trip: expression -> LaTeX -> expression
	for expr in ["frac(1;3)+root(3;8)", "2^(3)×√(9)", "abs(−5)+nCr(4;2)"]:
		var ev := Evaluator.new()
		var back := mf.latex_to_expression(mf.to_latex(expr))
		var a := ev.evaluate(expr)
		var b := ev.evaluate(back)
		_check(b["ok"] and is_equal_approx(a["value"], b["value"]), "LaTeX round trip %s → %s" % [expr, back])
	# One-line form used by the history
	for pair in [["frac(3;4)+root(3;27)", "3⁄4 + ³√27"], ["sin(30)×2^(3)", "sin(30) × 2³"],
			["2^(−1)", "2⁻¹"], ["logb(2;8)", "log₂(8)"], ["√(2+3)", "√(2 + 3)"], ["nCr(5;2)", "nCr(5, 2)"],
			["frac(1+2;3)", "(1 + 2)⁄3"], ["−5+abs(−2)", "−5 + |−2|"]]:
		var got := mf.to_linear(pair[0])
		_check(got == pair[1], "linear %s = %s (got %s)" % [pair[0], pair[1], got])
	# Display tree: unfinished templates keep placeholders and a caret
	var tree := mf.parse("frac(1;", true)
	_check(tree["items"][0]["type"] == "frac" and tree["items"][0]["den"]["items"][0]["type"] == "caret",
		"caret in the empty denominator of frac(1;")
	tree = mf.parse("√(2+", true)
	_check(tree["items"][0]["type"] == "root" and not tree["items"][0]["closed"], "open root for √(2+")
	tree = mf.parse("2^(", true)
	_check(tree["items"][1]["type"] == "sup" and tree["items"][1]["row"]["items"][0]["type"] == "caret",
		"caret in the exponent of 2^(")


func _test_programmer() -> void:
	var pe := ProgrammerEvaluator.new()
	pe.base = 10
	_int(pe, "12&10", 8)
	_int(pe, "12|3", 15)
	_int(pe, "12⊕10", 6)
	_int(pe, "~0", -1)
	_int(pe, "1<<10", 1024)
	_int(pe, "1024>>3", 128)
	_int(pe, "7÷2", 3)
	_int(pe, "7 mod 3", 1)
	_int(pe, "2+3×4", 14)
	_int(pe, "(2+3)×4", 20)
	_int(pe, "1|2&3", 3) # & binds tighter than |
	pe.base = 16
	_int(pe, "FF", 255)
	_int(pe, "FF+1", 256)
	_int(pe, "A×A", 100)
	pe.last_answer = 5
	_int(pe, "Ans+A", 15)
	pe.base = 2
	_int(pe, "1010+1", 11)
	var r := pe.evaluate("102")
	_check(not r["ok"], "digit 2 rejected in binary")
	pe.base = 10
	r = pe.evaluate("1÷0")
	_check(not r["ok"] and r["error"] == ProgrammerEvaluator.ERR_DIV_ZERO, "integer division by zero")
	_check(ProgrammerEvaluator.format_int(255, 16) == "FF", "255 = FF")
	_check(ProgrammerEvaluator.format_int(255, 2) == "1111 1111", "255 = 1111 1111")
	_check(ProgrammerEvaluator.format_int(-1, 16, false) == "FFFFFFFFFFFFFFFF", "-1 = FFFF… (two's complement)")
	_check(ProgrammerEvaluator.format_int(1234567, 10) == "1,234,567", "DEC grouping")
	_check(ProgrammerEvaluator.format_int(8, 8) == "10", "8 = 10 (octal)")
	var editor := ExpressionEditor.new()
	editor.programmer = true
	for token in ["F", "F", "&", "0", "F"]:
		editor.insert(token)
	_check(editor.text == "FF&F", "hex digits typed in programmer mode (got '%s')" % editor.text)


func _test_converter() -> void:
	_close(Units.convert("length", 1.0, 3, 7), 0.621371192, "1 km = 0.621 mi")
	_close(Units.convert("length", 12.0, 4, 5), 1.0, "12 in = 1 ft")
	_close(Units.convert("temperature", 100.0, 0, 1), 212.0, "100 °C = 212 °F")
	_close(Units.convert("temperature", 0.0, 2, 0), -273.15, "0 K = −273.15 °C")
	_close(Units.convert("temperature", -40.0, 1, 0), -40.0, "−40 °F = −40 °C")
	_close(Units.convert("mass", 1.0, 2, 5), 2.20462262, "1 kg = 2.2046 lb")
	_close(Units.convert("speed", 36.0, 1, 0), 10.0, "36 km/h = 10 m/s")
	_close(Units.convert("data", 1.0, 8, 4), 1.073741824, "1 GiB = 1.0737 GB")
	_close(Units.convert("angle", 180.0, 0, 1), PI, "180° = π rad")
	_close(Units.convert("time", 2.0, 3, 2), 120.0, "2 h = 120 min")
	_close(Units.convert("pressure", 1.0, 3, 0), 101325.0, "1 atm = 101325 Pa")
	_close(Units.convert("energy", 1.0, 3, 0), 4184.0, "1 kcal = 4184 J")
	for category in Units.category_ids():
		var defaults: Array = Units.DEFAULTS[category]
		_check(defaults[0] < Units.unit_count(category) and defaults[1] < Units.unit_count(category),
			"default units exist for " + category)


func _test_knowledge() -> void:
	var primes := Knowledge.primes_below(200)
	_check(primes.size() == 46, "46 primes under 200 (got %d)" % primes.size())
	_check(primes[0] == 2 and primes[primes.size() - 1] == 199, "primes from 2 to 199")
	_check(Knowledge.primes_below(100).size() == 25, "25 primes under 100")
	_check(Knowledge.factorial(10) == 3628800, "10! = 3628800")
	_check(Knowledge.grouped(1307674368000, " ") == "1 307 674 368 000", "15! grouped")
	_check(Knowledge.PI_DIGITS.begins_with(str(PI).left(10)), "π digits match Godot's PI")
	var ev := Evaluator.new()
	var mf := MathFormat.new()
	for entry in Knowledge.CONSTANTS:
		_check(ev.evaluate(entry[1])["ok"], "constant %s evaluates" % entry[0])
	for row in Knowledge.TRIG:
		for i in range(1, 4):
			if row[i] != "—":
				var r := ev.evaluate(row[i])
				_check(r["ok"], "trig value %s evaluates" % row[i])
	# sin / cos table matches the evaluator (degrees)
	for row in Knowledge.TRIG:
		var angle: String = row[0].trim_suffix("°")
		_check(is_equal_approx(ev.evaluate(row[1])["value"], ev.evaluate("sin(" + angle + ")")["value"]), "sin(%s°) = %s" % [angle, row[1]])
		_check(is_equal_approx(ev.evaluate(row[2])["value"], ev.evaluate("cos(" + angle + ")")["value"]), "cos(%s°) = %s" % [angle, row[2]])
	# Formulas parse into a math tree without stray symbols
	for entry in Knowledge.ALGEBRA + Knowledge.GEOMETRY:
		var tree := mf.parse(entry[0])
		_check(tree["items"].size() > 2, "formula %s parses" % entry[0])


## Every translation key used by the app exists, non-empty, in every language.
func _test_translations() -> void:
	var keys := _used_translation_keys()
	var locales := TranslationServer.get_loaded_locales()
	for language in ["en", "fr", "es", "de", "it", "pt"]:
		_check(language in locales, "language %s loaded" % language)
		var translation := TranslationServer.get_translation_object(language)
		if translation == null or translation.locale != language:
			continue
		var missing: PackedStringArray = []
		for key in keys:
			if String(translation.get_message(key)) == "":
				missing.append(key)
		_check(missing.is_empty(), "%s: all %d keys translated (missing: %s)" % [language, keys.size(), ", ".join(missing)])
	# Formats with placeholders keep the same number of %s / %d in every language.
	for key in ["ABOUT_TEXT", "SELF_TEST_RESULT", "KB_DIV_FORMAT"]:
		var expected := String(TranslationServer.get_translation_object("en").get_message(key)).count("%")
		for language in ["fr", "es", "de", "it", "pt"]:
			var translation := TranslationServer.get_translation_object(language)
			if translation and translation.locale == language:
				_check(String(translation.get_message(key)).count("%") == expected, "%s placeholders in %s" % [key, language])


## Keys referenced by the data scripts (units, knowledge, keypads, help...).
func _used_translation_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	for category in Units.category_ids():
		keys.append(Units.category_name_key(category))
		for i in Units.unit_count(category):
			keys.append(Units.unit_name_key(category, i))
	keys.append_array(Knowledge.TITLES.values())
	keys.append_array(Knowledge.NOTES.values())
	keys.append(Knowledge.PI_MNEMONIC)
	keys.append("KB_DIV_FORMAT")
	for entry in Knowledge.CONSTANTS:
		keys.append(entry[2])
	for entry in Knowledge.ALGEBRA + Knowledge.GEOMETRY + Knowledge.DIVISIBILITY:
		keys.append(entry[1])
	for mode in Keypads.MODES:
		for key in Keypads.layout(mode)["keys"]:
			for field in ["tip", "tip2"]:
				if key.has(field):
					keys.append(key[field])
	for category in Keypads.FUNCTION_CATALOG:
		keys.append(category[0])
	for topic in ["MODES", "TEMPLATES", "SECOND", "DISPLAY", "TOOLS"]:
		keys.append("HELP_%s_T" % topic)
		keys.append("HELP_" + topic)
	keys.append_array(PackedStringArray([
		"APP_TITLE", "MODE_SIMPLE", "MODE_SCIENTIFIC", "MODE_PROGRAMMER", "MODE_CONVERTER", "MODE_TOOLTIP",
		"HISTORY", "HISTORY_TOOLTIP", "HISTORY_EMPTY", "CLEAR_HISTORY", "MENU_TOOLTIP", "SETTINGS", "FUNCTIONS",
		"KNOWLEDGE", "HELP", "SELF_TEST", "CLOSE", "BACK", "COPY", "COPY_LATEX", "PASTE", "COPIED", "LATEX_COPIED",
		"PASTED", "INSERTED", "ANGLE_TOOLTIP", "DISPLAY_TOOLTIP", "ERR_SYNTAX", "ERR_DIV_ZERO", "ERR_DOMAIN",
		"ERR_OVERFLOW", "SECTION_APPEARANCE", "THEME_AUTO", "THEME_LIGHT", "THEME_DARK", "LANGUAGE",
		"SECTION_CALCULATION", "DEGREES", "RADIANS", "PRECISION", "PREC_AUTO", "SECTION_FEEDBACK", "SOUND",
		"VIBRATION", "VIBRATION_MOBILE_ONLY", "SECTION_MORE", "ABOUT_TEXT", "SELF_TEST_HINT", "SELF_TEST_RUN",
		"SELF_TEST_RESULT", "SELF_TEST_FAILURES", "DEVICE", "TEST_SOUND", "TEST_VIBRATION", "HELP_KEYBOARD_T",
		"SC_DIGITS", "SC_ENTER", "SC_EDIT", "SC_NEXT", "SC_FUNCTIONS", "SC_PANELS", "SC_MODES", "SC_COPY", "SC_ANGLE",
	]))
	return keys


# --- Helpers ---------------------------------------------------------------

func _section(name: String, callable: Callable) -> void:
	_section_passed = 0
	_section_total = 0
	callable.call()
	sections.append({ "name": name, "passed": _section_passed, "total": _section_total })


func _value(ev, expr: String, expected: float) -> void:
	var r: Dictionary = ev.evaluate(expr)
	_check(r["ok"] and is_equal_approx(r["value"], expected),
		"%s = %s (got %s, %s)" % [expr, expected, r["value"], r["error"]])


func _error(ev, expr: String, expected_error: String) -> void:
	var r: Dictionary = ev.evaluate(expr)
	_check(not r["ok"] and r["error"] == expected_error,
		"%s → %s (got ok=%s, %s)" % [expr, expected_error, r["ok"], r["error"]])


func _format(value: float, decimal_sep: String, group_sep: String, expected: String) -> void:
	var got := Evaluator.format_number(value, decimal_sep, group_sep)
	_check(got == expected, "format(%s) = %s (got %s)" % [value, expected, got])


func _typed(tokens: Array, expected: String) -> void:
	var editor := ExpressionEditor.new()
	for token in tokens:
		match token:
			"→":
				editor.next_slot()
			"±":
				editor.negate()
			_:
				editor.insert(token)
	_check(editor.text == expected, "typing %s → '%s' (got '%s')" % [" ".join(tokens), expected, editor.text])


func _fraction(value: float, expected: Array) -> void:
	var got := Evaluator.to_fraction(value)
	_check(got == expected, "fraction(%s) = %s (got %s)" % [value, expected, got])


func _latex(mf, expr: String, expected: String) -> void:
	var got: String = mf.to_latex(expr)
	_check(got == expected, "LaTeX of %s = %s (got %s)" % [expr, expected, got])


func _from_latex(mf, latex: String, expected: float) -> void:
	var expr: String = mf.latex_to_expression(latex)
	var r: Dictionary = Evaluator.new().evaluate(expr)
	_check(r["ok"] and is_equal_approx(r["value"], expected), "LaTeX %s → %s = %s (got %s)" % [latex, expr, expected, r["value"]])


func _int(pe, expr: String, expected: int) -> void:
	var r: Dictionary = pe.evaluate(expr)
	_check(r["ok"] and r["value"] == expected, "[base %d] %s = %d (got %s, %s)" % [pe.base, expr, expected, r["value"], r["error"]])


func _close(got: float, expected: float, label: String) -> void:
	_check(absf(got - expected) <= 1e-6 * maxf(1.0, absf(expected)), "%s (got %s)" % [label, got])


func _check(condition: bool, label: String) -> void:
	_section_total += 1
	if condition:
		passed += 1
		_section_passed += 1
	else:
		failed += 1
		failures.append(label)
