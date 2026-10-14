extends SceneTree
## Headless UI integration test: loads the main scene and simulates
## numeric keypad, keyboard and button input, settings, themes and panels.
## Run: godot --headless --path . --script res://tests/test_ui.gd

const TEST_SETTINGS := "user://test_settings.cfg"

var _passed := 0
var _failed := 0
var _main: Control


func _initialize() -> void:
	DirAccess.remove_absolute(TEST_SETTINGS)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.settings.path = TEST_SETTINGS # never touch the user's real settings
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
	_main._set_language("en")
	_main._set_angle_mode(0) # DEG
	_main.feedback.sound_enabled = false
	_main._wide = false # force the phone layout
	_main._update_layout()

	# Numeric keypad: 12 + 30 * 2 Enter
	_key(KEY_ESCAPE)
	for k in [KEY_KP_1, KEY_KP_2, KEY_KP_ADD, KEY_KP_3, KEY_KP_0, KEY_KP_MULTIPLY, KEY_KP_2]:
		_key(k)
	_check(_main.result_label.text == "72", "live preview shows 72 (got '%s')" % _main.result_label.text)
	_key(KEY_KP_ENTER)
	_check(_main.editor.just_evaluated and _main.result_label.text == "72", "KP_ENTER evaluates to 72")
	_check(_main.settings.history.size() == 1, "history recorded")
	_key(KEY_KP_ENTER)
	_check(_main.settings.history.size() == 1, "pressing = twice doesn't duplicate history")

	# NumLock off: the keypad sends Home/Right/End... but the physical key is KP_x
	_key(KEY_ESCAPE)
	for pair in [[KEY_HOME, KEY_KP_7], [KEY_KP_MULTIPLY, KEY_KP_MULTIPLY], [KEY_RIGHT, KEY_KP_6], [KEY_ENTER, KEY_KP_ENTER]]:
		_physical_key(pair[0], pair[1])
	_check(_main.result_label.text == "42", "numpad with NumLock off: 7×6 = 42 (got '%s')" % _main.result_label.text)

	# Continue from result with an operator: Ans ÷ 8 = 9
	_key(KEY_KP_DIVIDE)
	_key(KEY_KP_8)
	_key(KEY_ENTER)
	_check(_main.result_label.text == "5.25", "Ans÷8 = 42÷8 = 5.25 (got '%s')" % _main.result_label.text)

	# Keypad decimal + subtract, double decimal point rejected: 1.5 - 0.25
	_key(KEY_ESCAPE)
	for k in [KEY_KP_1, KEY_KP_PERIOD, KEY_KP_PERIOD, KEY_KP_5, KEY_KP_SUBTRACT, KEY_KP_PERIOD, KEY_KP_2, KEY_KP_5, KEY_KP_ENTER]:
		_key(k)
	_check(_main.result_label.text == "1.25", "1.5-0.25 = 1.25 (got '%s')" % _main.result_label.text)

	# Operator replacement: 8 + × 2 = 16
	_key(KEY_ESCAPE)
	for ch in ["8", "+", "*", "2", "="]:
		_char(ch)
	_check(_main.result_label.text == "16", "8+×2 → 8×2 = 16 (got '%s')" % _main.result_label.text)

	# Thousands grouping in the result
	_key(KEY_ESCAPE)
	for ch in ["1", "2", "3", "4", "5", "6", "7", "+", "0", "="]:
		_char(ch)
	_check(_main.result_label.text == "1,234,567", "grouped result (got '%s')" % _main.result_label.text)

	# Typed characters: s 3 0 ) =  -> sin(30) = 0.5
	_key(KEY_ESCAPE)
	for ch in ["s", "3", "0", ")", "="]:
		_char(ch)
	_check(_main.result_label.text == "0.5", "sin(30) via keyboard = 0.5 (got '%s')" % _main.result_label.text)

	# Backspace removes whole function token
	_key(KEY_ESCAPE)
	_char("s")
	_key(KEY_BACKSPACE)
	_check(_main.editor.text == "", "backspace removes 'sin(' (got '%s')" % _main.editor.text)

	# Buttons: 2nd + sin -> asin(1) = 90
	_key(KEY_ESCAPE)
	for id in ["second", "sin", "1", "equals"]:
		_press(id)
	_check(_main.result_label.text == "90", "sin⁻¹(1) = 90 (got '%s')" % _main.result_label.text)
	_check(not _main.second_active, "2nd released after use")

	# Error display
	_key(KEY_ESCAPE)
	for ch in ["1", "/", "0"]:
		_char(ch)
	_key(KEY_ENTER)
	_check(_main.result_label.text == "Division by zero", "division by zero message (got '%s')" % _main.result_label.text)
	_char("5")
	_check(_main.error_key == "", "typing clears the error")

	# Memory: 5 M+ M+ MR = 10
	_key(KEY_ESCAPE)
	for id in ["mc", "5", "mplus", "mplus", "clear", "mr", "equals"]:
		_press(id)
	_check(_main.result_label.text == "10", "memory = 10 (got '%s')" % _main.result_label.text)
	_check(_main.memory_label.visible, "memory indicator visible")
	_press("mc")
	_check(not _main.memory_label.visible, "memory indicator hidden after MC")

	# Language switch to French: decimal comma, grouping, translated errors
	_main._set_language("fr")
	_check(TranslationServer.get_locale().begins_with("fr"), "locale is fr")
	_check(_main.tr("APP_TITLE") == "Calculatrice scientifique", "title translated")
	_key(KEY_ESCAPE)
	for k in [KEY_KP_1, KEY_KP_DIVIDE, KEY_KP_4, KEY_KP_ENTER]:
		_key(k)
	_check(_main.result_label.text == "0,25", "French decimal comma (got '%s')" % _main.result_label.text)
	_key(KEY_ESCAPE)
	for ch in ["1", "/", "0", "="]:
		_char(ch)
	_check(_main.result_label.text == "Division par zéro", "French error (got '%s')" % _main.result_label.text)
	_main._set_language("en")

	# Themes
	_main._set_theme_mode(1) # DARK
	_check(_main.theme == _main.DARK_THEME, "dark theme applied")
	_char("e") # make sure the display refreshes with the theme colors
	_key(KEY_F6)
	_check(_main.theme == _main.LIGHT_THEME and _main.settings.theme_mode == 2, "F6 switches to light theme")
	_key(KEY_F6)
	_check(_main.theme == _main.DARK_THEME, "F6 switches back to dark theme")
	_main._set_theme_mode(0) # AUTO
	_check(_main.theme != null, "auto theme resolves to a theme")

	# Panels (narrow layout)
	_char("h")
	_check(_main.side_panel.visible and _main.history_view.visible and not _main.keypad.visible, "history panel shown")
	_char("h")
	_check(not _main.side_panel.visible and _main.keypad.visible, "keypad shown again")
	_key(KEY_F4)
	_check(_main.settings_view.visible, "settings panel shown (F4)")
	_main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not _main.side_panel.visible, "back button closes the panel")

	# Settings panel buttons
	_key(KEY_F4)
	_main._setting_buttons["angle"][1].emit_signal("pressed")
	_check(_main.evaluator.angle_mode == 1 and _main.angle_button.text == "RAD", "settings: radians")
	_main._setting_buttons["angle"][0].emit_signal("pressed")
	_main._setting_buttons["sound"][1].emit_signal("pressed")
	_check(not _main.feedback.sound_enabled and not _main.settings.sound, "settings: sound off")
	_main._setting_buttons["language"][1].emit_signal("pressed")
	_check(_main.settings.language == "fr", "settings: French")
	_main._setting_buttons["language"][0].emit_signal("pressed")

	# On-screen tests panel
	_main.settings_list.get_node("OpenTestsButton").emit_signal("pressed")
	_check(_main.tests_view.visible, "tests panel shown")
	_main._run_self_test()
	_check(_main.tests_summary.text.begins_with("✓"), "on-screen tests pass (got '%s')" % _main.tests_summary.text)
	_main._close_page()

	# Settings persisted
	var saved = load("res://scripts/settings.gd").new()
	saved.path = TEST_SETTINGS
	saved.load_settings()
	_check(saved.sound == false and saved.language == "en" and saved.history.size() > 0, "settings saved to disk")

	# Wide layout docks the history next to the keypad
	_main._wide = true
	_main._update_layout()
	_check(_main.keypad.visible and _main.history_view.visible, "wide layout shows keypad + history")
	_main._wide = false
	_main._update_layout()

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


func _physical_key(keycode: Key, physical: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = physical
	ev.pressed = true
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
