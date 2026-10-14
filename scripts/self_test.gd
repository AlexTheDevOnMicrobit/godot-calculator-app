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
const Stats := preload("res://scripts/stats.gd")

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
	_section("Complex numbers", _test_complex)
	_section("Calculus", _test_calculus)
	_section("Probability", _test_probability)
	_section("Statistics", _test_statistics)
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
	_error(ev, "√(−1)", Evaluator.ERR_NONREAL)
	_error(ev, "ln(0)", Evaluator.ERR_DOMAIN)
	_error(ev, "asin(2)", Evaluator.ERR_DOMAIN)
	_error(ev, "(−1)!", Evaluator.ERR_DOMAIN)
	_error(ev, "(−3)!", Evaluator.ERR_DOMAIN)
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
	_typed(["x", "2"], "x×2")
	_typed(["2", "i", "3"], "2i×3")
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
	_error(ev, "root(2;−4)", Evaluator.ERR_NONREAL)
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


func _test_complex() -> void:
	var ev := Evaluator.new()
	_complex(ev, "(2+3i)(1−i)", 5.0, 1.0)
	_complex(ev, "i^2", -1.0, 0.0)
	_complex(ev, "i^3", 0.0, -1.0)
	_complex(ev, "(1+i)/(1−i)", 0.0, 1.0)
	_complex(ev, "√(−4)+0i", 0.0, 2.0) # an i in the input allows complex results
	_complex(ev, "e^(iπ)", -1.0, 0.0)
	_complex(ev, "conj(1+2i)", 1.0, -2.0)
	_complex(ev, "2i×3i", -6.0, 0.0)
	_value(ev, "abs(3+4i)", 5.0)
	_value(ev, "real(3+4i)", 3.0)
	_value(ev, "imag(3+4i)", 4.0)
	_value(ev, "arg(i)", 90.0)
	_error(ev, "√(−4)", Evaluator.ERR_NONREAL) # Real mode
	_error(ev, "(3+i)!", Evaluator.ERR_DOMAIN)
	ev.allow_complex = true
	_complex(ev, "√(−4)", 0.0, 2.0)
	_complex(ev, "ln(−1)", 0.0, PI)
	_complex(ev, "(−8)^(1/4)", 1.189207115, 1.189207115)
	_complex(ev, "sin(i)", 0.0, sinh(1.0))
	ev.last_answer = 1.0
	ev.last_answer_im = 2.0
	_complex(ev, "Ans×i", -2.0, 1.0)
	var text := Evaluator.format_complex(3.0, 4.0, false, true)
	_check(text == "3 + 4i", "format 3 + 4i (got %s)" % text)
	text = Evaluator.format_complex(0.0, -1.0, false, true)
	_check(text == "-i", "format -i (got %s)" % text)
	text = Evaluator.format_complex(1.5, -2.0, false, true, ",")
	_check(text == "1,5 - 2i", "format 1,5 - 2i (got %s)" % text)
	text = Evaluator.format_complex(0.0, 2.0, true, true)
	_check(text == "2∠90°", "format polar 2∠90° (got %s)" % text)


func _test_calculus() -> void:
	var ev := Evaluator.new()
	_value(ev, "deriv(x^2;3)", 6.0)
	_value(ev, "deriv(x^3;2)", 12.0)
	_value(ev, "integral(x^2;0;3)", 9.0)
	_value(ev, "integral(1/x;1;e)", 1.0)
	_value(ev, "sum(x;1;100)", 5050.0)
	_value(ev, "sum(1/x^2;1;1000)", 1.6439345666815615)
	_value(ev, "prod(x;1;5)", 120.0)
	_value(ev, "solve(x^2−2;1)", sqrt(2.0))
	_value(ev, "solve(x^3−x−1;0)", 1.324717957244746)
	_value(ev, "fmin(x^2−4x;0;5)", 2.0)
	_value(ev, "fmax(−(x−1)^2;−5;5)", 1.0)
	_value(ev, "integral(deriv(x^2;x);0;1)", 1.0) # nested special forms
	ev.angle_mode = Evaluator.AngleMode.RAD
	_value(ev, "solve(cos(x)−x;0)", 0.7390851332151607)
	_value(ev, "integral(sin(x);0;π)", 2.0)
	_error(ev, "solve(x^2+1;0)", Evaluator.ERR_NO_SOLUTION)
	_error(ev, "x+1", Evaluator.ERR_SYNTAX) # x is only defined inside functions and graphs
	var compiled := ev.compile("x^2+1")
	_check(compiled["ok"] and compiled["uses_x"], "compile x^2+1 uses x")
	_check(is_equal_approx(ev.evaluate_real(compiled["tokens"], 3.0), 10.0), "f(3) = 10")
	_check(is_nan(ev.evaluate_real(ev.compile("√(x)")["tokens"], -1.0)), "√(−1) is NAN on a graph")
	_value(ev, "ipart(−3.7)", -3.0)
	_value(ev, "fpart(3.75)", 0.75)
	_value(ev, "int(−3.7)", -4.0)
	_value(ev, "min(3;5)", 3.0)
	_value(ev, "max(3;5)", 5.0)
	_value(ev, "remainder(7;3)", 1.0)
	_value(ev, "round(3.14159;2)", 3.14)
	_value(ev, "gamma(5)", 24.0)
	_value(ev, "0.5!", sqrt(PI) / 2.0)


func _test_probability() -> void:
	var ev := Evaluator.new()
	_value(ev, "normalpdf(0)", 0.3989422804014327)
	_value(ev, "normalcdf(−1;1)", 0.6826894921370859)
	_value(ev, "normalcdf(−1.96;1.96)", 0.9500042097035593)
	_value(ev, "normalcdf(90;110;100;10)", 0.6826894921370859)
	_value(ev, "invNorm(0.975)", 1.959963984540054)
	_value(ev, "invNorm(0.5;10;2)", 10.0)
	_value(ev, "binompdf(10;0.5;5)", 0.24609375)
	_value(ev, "binomcdf(10;0.5;5)", 0.623046875)
	_value(ev, "poissonpdf(3;2)", 0.22404180765538775)
	_value(ev, "poissoncdf(3;2)", 0.42319008112684353)
	var r := ev.evaluate("randBin(10;0.5)")
	_check(r["ok"] and r["value"] >= 0.0 and r["value"] <= 10.0, "randBin(10, 0.5) in 0…10")
	r = ev.evaluate("randNorm(0;1)")
	_check(r["ok"] and absf(r["value"]) < 10.0, "randNorm(0, 1)")


func _test_statistics() -> void:
	var one := Stats.one_var(PackedFloat64Array([2, 4, 4, 4, 5, 5, 7, 9]))
	_close(one["mean"], 5.0, "mean = 5")
	_close(one["sigma"], 2.0, "σx = 2")
	_close(one["sx"], 2.138089935299395, "Sx = 2.138")
	_close(one["median"], 4.5, "median = 4.5")
	_close(one["q1"], 4.0, "Q1 = 4")
	_close(one["q3"], 6.0, "Q3 = 6")
	_check(one["n"] == 8 and one["min"] == 2.0 and one["max"] == 9.0, "n, min, max")
	var odd := Stats.one_var(PackedFloat64Array([1, 2, 3, 4, 5, 6, 7]))
	_check(odd["q1"] == 2.0 and odd["median"] == 4.0 and odd["q3"] == 6.0, "quartiles of 1…7 (TI method)")
	var xs := PackedFloat64Array([1, 2, 3, 4, 5])
	var ys := PackedFloat64Array([2.1, 3.9, 6.2, 7.8, 10.1])
	var lin := Stats.regression("linear", xs, ys)
	_check(lin["ok"], "linear regression")
	_close(lin["coefficients"]["a"], 1.99, "LinReg a = 1.99")
	_close(lin["coefficients"]["b"], 0.05, "LinReg b = 0.05")
	_close(lin["r"], 0.998651755568966, "LinReg r = 0.99865")
	var two := Stats.two_var(xs, ys)
	_close(two["mean_y"], 6.02, "ȳ = 6.02")
	var exact := func(kind: String, f: Callable, x_values: Array) -> Dictionary:
		var x_list := PackedFloat64Array(x_values)
		var y_list := PackedFloat64Array()
		for x in x_list:
			y_list.append(f.call(x))
		return Stats.regression(kind, x_list, y_list)
	var quad: Dictionary = exact.call("quadratic", func(x): return x * x + 1.0, [0, 1, 2, 3, 4])
	_close(quad["coefficients"]["a"], 1.0, "QuadReg a = 1")
	_close(quad["coefficients"]["c"], 1.0, "QuadReg c = 1")
	_close(quad["r2"], 1.0, "QuadReg r² = 1")
	var expo: Dictionary = exact.call("exponential", func(x): return 3.0 * pow(2.0, x), [0, 1, 2, 3])
	_close(expo["coefficients"]["a"], 3.0, "ExpReg a = 3")
	_close(expo["coefficients"]["b"], 2.0, "ExpReg b = 2")
	var power: Dictionary = exact.call("power", func(x): return 2.0 * pow(x, 3.0), [1, 2, 3, 4])
	_close(power["coefficients"]["a"], 2.0, "PwrReg a = 2")
	_close(power["coefficients"]["b"], 3.0, "PwrReg b = 3")
	var logarithmic: Dictionary = exact.call("logarithmic", func(x): return 1.0 + 2.0 * log(x), [1, 2, 3, 4])
	_close(logarithmic["coefficients"]["a"], 1.0, "LnReg a = 1")
	_close(logarithmic["coefficients"]["b"], 2.0, "LnReg b = 2")
	var bad := Stats.regression("power", PackedFloat64Array([-1, 2]), PackedFloat64Array([1, 2]))
	_check(not bad["ok"] and bad["error"] == "STATS_POSITIVE", "PwrReg needs x > 0")
	var few := Stats.regression("quadratic", PackedFloat64Array([1, 2]), PackedFloat64Array([1, 2]))
	_check(not few["ok"], "QuadReg needs 3 points")
	var ev := Evaluator.new()
	var r := ev.evaluate(lin["expression"].replace("x", "2"))
	_check(r["ok"] and is_equal_approx(r["value"], 4.03), "regression expression evaluates (got %s)" % r["value"])


func _complex(ev, expr: String, re: float, im: float) -> void:
	var r: Dictionary = ev.evaluate(expr)
	_check(r["ok"] and absf(r["value"] - re) < 1e-9 and absf(r["im"] - im) < 1e-9,
		"%s = %s + %si (got %s + %si, %s)" % [expr, re, im, r["value"], r["im"], r["error"]])


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
	for topic in ["MODES", "TEMPLATES", "SECOND", "DISPLAY", "TOOLS", "GRAPH", "STATS", "COMPLEX"]:
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
		"MODE_GRAPH", "MODE_STATS", "COMPLEX_FORMAT", "CPX_REAL", "CPX_RECT", "CPX_POLAR", "ERR_NONREAL",
		"ERR_NO_SOLUTION", "GRAPH_EMPTY", "GRAPH_INTEGRAL", "GRAPH_INTERSECTION", "GRAPH_MAXIMUM", "GRAPH_MINIMUM",
		"GRAPH_NONE", "GRAPH_PICK_LOWER", "GRAPH_PICK_UPPER", "GRAPH_TABLE", "GRAPH_TOOLS", "GRAPH_TRACE",
		"GRAPH_ZEROS", "REG_EXPONENTIAL", "REG_LINEAR", "REG_LOGARITHMIC", "REG_POWER", "REG_QUADRATIC",
		"STATS_CLEAR_CONFIRM", "STATS_DATA", "STATS_NOT_ENOUGH", "STATS_ONE_VAR", "STATS_PLOT", "STATS_POSITIVE",
		"STATS_RESULTS", "STATS_SINGULAR", "STATS_TWO_VAR", "ZOOM_FIT", "ZOOM_IN", "ZOOM_OUT", "ZOOM_STANDARD",
		"ZOOM_TRIG",
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
