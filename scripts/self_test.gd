extends RefCounted
## Test suite shared by the headless test runner (CI) and the in-app
## "On-screen tests" panel, so the exact same checks run on every device.

const Evaluator := preload("res://scripts/evaluator.gd")
const ExpressionEditor := preload("res://scripts/expression_editor.gd")

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
		editor.insert(token)
	_check(editor.text == expected, "typing %s → '%s' (got '%s')" % [" ".join(tokens), expected, editor.text])


func _check(condition: bool, label: String) -> void:
	_section_total += 1
	if condition:
		passed += 1
		_section_passed += 1
	else:
		failed += 1
		failures.append(label)
