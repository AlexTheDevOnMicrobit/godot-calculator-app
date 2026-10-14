extends SceneTree
## Headless UI integration test: loads the main scene and simulates
## numeric keypad, keyboard and button input.
## Run: godot --headless --path . --script res://tests/test_ui.gd

const TEST_SETTINGS := "user://test_settings.cfg"

var _passed := 0
var _failed := 0
var _main: Control


func _initialize() -> void:
	DirAccess.remove_absolute(TEST_SETTINGS)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.settings_path = TEST_SETTINGS # never touch the user's real settings
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _main == null or not _main.is_node_ready():
		return false
	_run()
	DirAccess.remove_absolute(TEST_SETTINGS)
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
	return true


func _run() -> void:
	_main._toggle_language() if _main.language == "fr" else null
	_main.evaluator.angle_mode = 0 # DEG

	# Numeric keypad: 12 + 30 * 2 Enter
	_key(KEY_ESCAPE)
	for k in [KEY_KP_1, KEY_KP_2, KEY_KP_ADD, KEY_KP_3, KEY_KP_0, KEY_KP_MULTIPLY, KEY_KP_2]:
		_key(k)
	_check(_main.result_label.text == "72", "live preview shows 72 (got '%s')" % _main.result_label.text)
	_key(KEY_KP_ENTER)
	_check(_main.just_evaluated and _main.result_label.text == "72", "KP_ENTER evaluates to 72")
	_check(_main.history.size() >= 1, "history recorded")

	# Continue from result with an operator: Ans ÷ 8 = 9
	_key(KEY_KP_DIVIDE)
	_key(KEY_KP_8)
	_key(KEY_ENTER)
	_check(_main.result_label.text == "9", "Ans÷8 = 9 (got '%s')" % _main.result_label.text)

	# Keypad decimal + subtract: 1.5 - 0.25
	_key(KEY_ESCAPE)
	for k in [KEY_KP_1, KEY_KP_PERIOD, KEY_KP_5, KEY_KP_SUBTRACT, KEY_KP_0, KEY_KP_PERIOD, KEY_KP_2, KEY_KP_5, KEY_KP_ENTER]:
		_key(k)
	_check(_main.result_label.text == "1.25", "1.5-0.25 = 1.25 (got '%s')" % _main.result_label.text)

	# Typed characters: s 3 0 ) =  -> sin(30) = 0.5
	_key(KEY_ESCAPE)
	for ch in ["s", "3", "0", ")", "="]:
		_char(ch)
	_check(_main.result_label.text == "0.5", "sin(30) via keyboard = 0.5 (got '%s')" % _main.result_label.text)

	# Backspace removes whole function token
	_key(KEY_ESCAPE)
	_char("s")
	_key(KEY_BACKSPACE)
	_check(_main.expression == "", "backspace removes 'sin(' (got '%s')" % _main.expression)

	# Buttons: 2nd + sin -> asin(1) = 90
	_key(KEY_ESCAPE)
	_press("second")
	_press("sin")
	_press("1")
	_press("equals")
	_check(_main.result_label.text == "90", "sin⁻¹(1) = 90 (got '%s')" % _main.result_label.text)
	_check(not _main.second_active, "2nd released after use")

	# Error display
	_key(KEY_ESCAPE)
	for ch in ["1", "/", "0"]:
		_char(ch)
	_key(KEY_ENTER)
	_check(_main.result_label.text == "Division by zero", "division by zero message (got '%s')" % _main.result_label.text)

	# Memory: 5 M+ M+ MR = 10
	_key(KEY_ESCAPE)
	_press("mc")
	_press("5")
	_press("mplus")
	_press("mplus")
	_press("clear")
	_press("mr")
	_press("equals")
	_check(_main.result_label.text == "10", "memory = 10 (got '%s')" % _main.result_label.text)
	_press("mc")

	# Language switch to French: decimal comma + translated errors
	_main._toggle_language()
	_check(TranslationServer.get_locale().begins_with("fr"), "locale is fr")
	_check(_main.title_label.tr(_main.title_label.text) == "Calculatrice scientifique", "title translated")
	_key(KEY_ESCAPE)
	for k in [KEY_KP_1, KEY_KP_DIVIDE, KEY_KP_4, KEY_KP_ENTER]:
		_key(k)
	_check(_main.result_label.text == "0,25", "French decimal comma (got '%s')" % _main.result_label.text)
	_key(KEY_ESCAPE)
	for ch in ["1", "/", "0", "="]:
		_char(ch)
	_check(_main.result_label.text == "Division par zéro", "French error (got '%s')" % _main.result_label.text)
	_main._toggle_language()

	# History panel toggle
	_char("h")
	_check(_main.history_panel.visible and not _main.keypad.visible, "history panel shown")
	_char("h")
	_check(not _main.history_panel.visible and _main.keypad.visible, "keypad shown again")

	_main._clear_history()
	_key(KEY_ESCAPE)


func _key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	var unicode_map := {
		KEY_KP_0: "0", KEY_KP_1: "1", KEY_KP_2: "2", KEY_KP_3: "3", KEY_KP_4: "4",
		KEY_KP_5: "5", KEY_KP_6: "6", KEY_KP_7: "7", KEY_KP_8: "8", KEY_KP_9: "9",
		KEY_KP_ADD: "+", KEY_KP_SUBTRACT: "-", KEY_KP_MULTIPLY: "*", KEY_KP_DIVIDE: "/", KEY_KP_PERIOD: ".",
	}
	if unicode_map.has(keycode):
		ev.unicode = unicode_map[keycode].unicode_at(0)
	_main._unhandled_input(ev)


func _char(ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.unicode = ch.unicode_at(0)
	_main._unhandled_input(ev)


func _press(id: String) -> void:
	_main._buttons[id].emit_signal("pressed")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: " + label)
