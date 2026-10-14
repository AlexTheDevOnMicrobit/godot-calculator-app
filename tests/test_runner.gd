extends SceneTree
## Headless unit tests for the evaluator.
## Run: godot --headless --path . --script res://tests/test_runner.gd

const Evaluator := preload("res://scripts/evaluator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	var ev := Evaluator.new()

	# Basic arithmetic & precedence
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

	# Powers, roots, factorial, percent, modulo
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
	_value(ev, "50%", 0.5)
	_value(ev, "200×10%", 20.0)
	_value(ev, "10 mod 3", 1.0)
	_value(ev, "−7 mod 3", 2.0)
	_value(ev, "abs(−4.5)", 4.5)

	# Constants, implicit multiplication, scientific notation
	_value(ev, "π", PI)
	_value(ev, "2π", TAU)
	_value(ev, "e", exp(1.0))
	_value(ev, "3(4+1)", 15.0)
	_value(ev, "(1+1)(2+2)", 8.0)
	_value(ev, "1.5E3", 1500.0)
	_value(ev, "2E−3", 0.002)
	_value(ev, "(2+3", 5.0) # auto-closed parenthesis

	# Logarithms & exponentials
	_value(ev, "log(1000)", 3.0)
	_value(ev, "ln(e)", 1.0)
	_value(ev, "e^(2)", exp(2.0))
	_value(ev, "10^(2)", 100.0)

	# Trigonometry (degrees)
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

	# Trigonometry (radians)
	ev.angle_mode = Evaluator.AngleMode.RAD
	_value(ev, "sin(π/2)", 1.0)
	_value(ev, "cos(π)", -1.0)
	_value(ev, "atan(1)", PI / 4.0)
	ev.angle_mode = Evaluator.AngleMode.DEG

	# Ans & rand
	ev.last_answer = 42.0
	_value(ev, "Ans+1", 43.0)
	_value(ev, "2Ans", 84.0)
	var r: Dictionary = ev.evaluate("rand")
	_check(r["ok"] and r["value"] >= 0.0 and r["value"] < 1.0, "rand in [0, 1)")

	# Errors
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

	# Formatting
	_format(0.0, ".", "0")
	_format(3.0, ".", "3")
	_format(-2.5, ".", "-2.5")
	_format(2.5, ",", "2,5")
	_format(0.1 + 0.2, ".", "0.3")
	_format(1.0 / 3.0, ".", "0.333333333333")
	_format(123456789.0, ".", "123456789")
	_format(1e20, ".", "1E20")
	_format(1.5e-12, ".", "1.5E-12")
	_format(PI, ".", "3.14159265359")

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _value(ev, expr: String, expected: float) -> void:
	var r: Dictionary = ev.evaluate(expr)
	_check(r["ok"] and is_equal_approx(r["value"], expected),
		"%s = %s (got %s, ok=%s, err=%s)" % [expr, expected, r["value"], r["ok"], r["error"]])


func _error(ev, expr: String, expected_error: String) -> void:
	var r: Dictionary = ev.evaluate(expr)
	_check(not r["ok"] and r["error"] == expected_error,
		"%s -> %s (got ok=%s, err=%s)" % [expr, expected_error, r["ok"], r["error"]])


func _format(value: float, sep: String, expected: String) -> void:
	var got := Evaluator.format_number(value, sep)
	_check(got == expected, "format(%s) = %s (got %s)" % [value, expected, got])


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: " + label)
