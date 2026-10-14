extends SceneTree
## Headless UI integration test: loads the main scene and simulates numeric
## keypad, keyboard and button input, menus, settings, layouts and languages.
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
	_main._set_mode("scientific")
	_main.feedback.sound_enabled = false
	_main.layout = "portrait" # the headless viewport is square: force the phone layout
	_main._update_layout()

	_test_basics()
	_test_scientific()
	_test_programmer()
	_test_converter()
	_test_pages()
	_test_layouts()
	_test_languages()
	_main._clear_history()
	_key(KEY_ESCAPE)


func _test_basics() -> void:
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

	# NumLock off: the keypad sends Home/Right/... but the physical key is KP_x
	_key(KEY_ESCAPE)
	for pair in [[KEY_HOME, KEY_KP_7], [KEY_KP_MULTIPLY, KEY_KP_MULTIPLY], [KEY_RIGHT, KEY_KP_6], [KEY_ENTER, KEY_KP_ENTER]]:
		_physical_key(pair[0], pair[1])
	_check(_main.result_label.text == "42", "numpad with NumLock off: 7×6 = 42 (got '%s')" % _main.result_label.text)

	# Continue from the result with an operator
	_key(KEY_KP_DIVIDE)
	_key(KEY_KP_8)
	_key(KEY_ENTER)
	_check(_main.result_label.text == "5.25", "Ans÷8 = 5.25 (got '%s')" % _main.result_label.text)

	# Decimal point typed twice, operator replacement, grouping
	_key(KEY_ESCAPE)
	for k in [KEY_KP_1, KEY_KP_PERIOD, KEY_KP_PERIOD, KEY_KP_5, KEY_KP_SUBTRACT, KEY_KP_PERIOD, KEY_KP_2, KEY_KP_5, KEY_KP_ENTER]:
		_key(k)
	_check(_main.result_label.text == "1.25", "1.5-0.25 = 1.25 (got '%s')" % _main.result_label.text)
	_typed(["8", "+", "*", "2", "="])
	_check(_main.result_label.text == "16", "8+×2 → 8×2 = 16 (got '%s')" % _main.result_label.text)
	_typed(["1", "2", "3", "4", "5", "6", "7", "+", "0", "="])
	_check(_main.result_label.text == "1,234,567", "grouped result (got '%s')" % _main.result_label.text)

	# Errors
	_typed(["1", "/", "0", "="])
	_check(_main.result_label.text == "Division by zero", "division by zero message (got '%s')" % _main.result_label.text)
	_char("5")
	_check(_main.error_key == "", "typing clears the error")

	# Basic mode: ±
	_main._set_mode("simple")
	_key(KEY_ESCAPE)
	for id in ["5", "neg", "add", "8", "equals"]:
		_press(id)
	_check(_main.result_label.text == "3", "Basic: −5+8 = 3 (got '%s')" % _main.result_label.text)
	_main._set_mode("scientific")


func _test_scientific() -> void:
	# sin via keyboard, backspace removes a whole function
	_typed(["s", "3", "0", ")", "="])
	_check(_main.result_label.text == "0.5", "sin(30) = 0.5 (got '%s')" % _main.result_label.text)
	_key(KEY_ESCAPE)
	_char("s")
	_key(KEY_BACKSPACE)
	_check(_main.editor.text == "", "backspace removes 'sin(' (got '%s')" % _main.editor.text)

	# 2nd functions
	_key(KEY_ESCAPE)
	for id in ["second", "sin", "1", "equals"]:
		_press(id)
	_check(_main.result_label.text == "90", "sin⁻¹(1) = 90 (got '%s')" % _main.result_label.text)
	_check(not _main.second_active, "2nd released after use")
	_key(KEY_ESCAPE)
	for id in ["8", "second", "ans"]:
		_press(id)
	_check(_main.editor.text == "−8", "2nd + Ans = ± (got '%s')" % _main.editor.text)

	# Templates with → (Right arrow), ⇄ fraction
	_key(KEY_ESCAPE)
	_press("frac")
	_press("1")
	_key(KEY_RIGHT)
	_press("4")
	_key(KEY_RIGHT)
	_press("add")
	_press("second")
	_press("power") # 2nd xʸ = ⁿ√x
	_press("3")
	_key(KEY_RIGHT)
	_press("8")
	_key(KEY_RIGHT)
	_check(_main.editor.text == "frac(1;4)+root(3;8)", "templates typed (got '%s')" % _main.editor.text)
	_press("equals")
	_check(_main.result_label.text == "2.25", "¼ + ∛8 = 2.25 (got '%s')" % _main.result_label.text)
	_press("sd")
	_check(_main.result_math.visible and _main.result_math.text == "frac(9;4)", "⇄ shows 9/4 (got '%s')" % _main.result_math.text)
	_press("sd")
	_check(_main.result_label.visible and not _main.result_math.visible, "⇄ back to decimal")

	# Memory lives in the f(x) panel
	_key(KEY_ESCAPE)
	_main._on_function_chosen("@mc")
	_press("5")
	_main._on_function_chosen("@mplus")
	_main._on_function_chosen("@mplus")
	_press("clear")
	_main._on_function_chosen("@mr")
	_press("equals")
	_check(_main.result_label.text == "10", "memory = 10 (got '%s')" % _main.result_label.text)
	_check(_main.memory_label.visible, "memory indicator visible")
	_main._on_function_chosen("@mc")
	_check(not _main.memory_label.visible, "memory indicator hidden after MC")

	# f(x) panel
	_key(KEY_ESCAPE)
	_press("fx")
	_check(_main.functions_view.visible and _main.functions_list.get_child_count() > 0, "f(x) opens the functions panel")
	_main._on_function_chosen("nCr(")
	for id in ["5", "next", "2", "next", "equals"]:
		_press(id)
	_check(_main.result_label.text == "10", "nCr(5, 2) = 10 (got '%s')" % _main.result_label.text)

	# Display menu: copy, copy as LaTeX, paste LaTeX
	_typed(["f", "1"])
	_key(KEY_RIGHT)
	_typed_more(["2"])
	_key(KEY_RIGHT)
	_typed_more(["+", "r", "9"])
	_key(KEY_RIGHT)
	_key(KEY_ENTER)
	_main._on_display_menu(_main.DisplayAction.COPY_LATEX)
	_check(_main._last_copied == "\\frac{1}{2} + \\sqrt{9} = 3.5", "copy as LaTeX (got '%s')" % _main._last_copied)
	_main._on_display_menu(_main.DisplayAction.COPY)
	_check(_main._last_copied == "3.5", "copy result (got '%s')" % _main._last_copied)
	_ctrl_key(KEY_C, true)
	_check(_main._last_copied.begins_with("\\frac"), "Ctrl+Shift+C copies LaTeX")
	_key(KEY_ESCAPE)
	_main._paste("\\frac{3}{4}\\times 4 + \\sqrt[3]{27}")
	_press("equals")
	_check(_main.result_label.text == "6", "pasted LaTeX evaluates to 6 (got '%s')" % _main.result_label.text)

	# Angle unit from the display
	_main.angle_button.emit_signal("pressed")
	_check(_main.evaluator.angle_mode == 1 and _main.angle_button.text == "RAD", "tapping DEG switches to RAD")
	_main.angle_button.emit_signal("pressed")

	# Precision
	_main._set_precision(1) # 2 decimals
	_typed(["2", "/", "3", "="])
	_check(_main.result_label.text == "0.67", "precision 2 → 0.67 (got '%s')" % _main.result_label.text)
	_main._set_precision(0)


func _test_programmer() -> void:
	_main._set_mode("programmer")
	_main._set_base(10)
	_key(KEY_ESCAPE)
	for id in ["2", "5", "5", "and", "1", "5", "equals"]:
		_press(id)
	_check(_main.result_label.text == "15", "255 AND 15 = 15 (got '%s')" % _main.result_label.text)
	_main._set_base(16)
	_check(_main.programmer_editor.text == "F", "switching to HEX keeps the value (got '%s')" % _main.programmer_editor.text)
	_check(_main._buttons["programmer"]["base"].text == "HEX", "base key shows HEX")
	_char("a")
	_check(_main.programmer_editor.text == "FA", "typing 'a' in HEX (got '%s')" % _main.programmer_editor.text)
	_char("s")
	_check(_main.programmer_editor.text == "FA", "'s' (sin) is rejected in programmer mode")
	_main._set_base(2)
	_check(_main._buttons["programmer"]["2"].disabled and _main.programmer_editor.text == "11111010",
		"BIN: digit 2 disabled, value kept (got '%s')" % _main.programmer_editor.text)
	_check(_main._base_buttons[16].text.ends_with("FA"), "HEX row shows FA (got '%s')" % _main._base_buttons[16].text)
	_main._set_base(10)
	_main._set_mode("scientific")


func _test_converter() -> void:
	_main._set_mode("converter")
	_main.converter_view.set_state({ "category": "temperature", "from": 0, "to": 1, "value": "0" })
	for id in ["1", "0", "0"]:
		_press(id)
	_check(_main.converter_view.result_text() == "212", "100 °C = 212 °F (got '%s')" % _main.converter_view.result_text())
	_press("swap")
	_check(_main.converter_view.value_text == "212" and _main.converter_view.result_text() == "100", "swap: 212 °F = 100 °C")
	_key(KEY_ENTER)
	_check(_main._last_copied == "100", "Enter copies the converted value (got '%s')" % _main._last_copied)
	_key(KEY_ESCAPE)
	_check(_main.converter_view.value_text == "0", "Esc clears the converter")
	_main._set_mode("scientific")


func _test_pages() -> void:
	# History
	_char("h")
	_check(_main.side_panel.visible and _main.history_view.visible and not _main.keypads.visible, "history sheet shown")
	_char("h")
	_check(not _main.side_panel.visible and _main.keypads.visible, "keypad shown again")

	# Settings (built on first use) and sub-pages
	_key(KEY_F4)
	_check(_main.settings_view.visible and _main._setting_controls.has("theme"), "settings page built and shown")
	_main._setting_controls["theme"][2].emit_signal("pressed") # Dark
	_check(_main.theme == _main.DARK_THEME and _main.settings.theme_mode == 1, "settings: dark theme")
	_main._setting_controls["theme"][1].emit_signal("pressed") # Light
	_check(_main.theme == _main.LIGHT_THEME and _main.settings.theme_mode == 2, "settings: light theme")
	_main._setting_controls["sound"].button_pressed = false
	_check(not _main.settings.sound and not _main.feedback.sound_enabled, "settings: sound switch off")
	_main._setting_controls["angle"][1].emit_signal("pressed")
	_check(_main.evaluator.angle_mode == 1 and _main.angle_button.text == "RAD", "settings: radians")
	_main._setting_controls["angle"][0].emit_signal("pressed")
	_key(KEY_F6)
	_check(_main.theme == _main.DARK_THEME, "F6 toggles the theme")

	_main.settings_list.get_node("HelpRow").emit_signal("pressed")
	_check(_main.help_view.visible and _main.help_list.get_child_count() > 10, "help page shown")
	_main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(_main.settings_view.visible, "back from help returns to settings")
	_main.settings_list.get_node("KnowledgeRow").emit_signal("pressed")
	_check(_main.knowledge_view.visible and _main.knowledge_list.section_count() == 12, "knowledge page from settings")
	_main._on_knowledge_value("144")
	_check(_main.editor.text.ends_with("144") and not _main.side_panel.visible, "tapping 12² inserts 144")
	_char("k")
	_check(_main.knowledge_view.visible, "K opens the knowledge page")
	_main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not _main.side_panel.visible, "back twice closes the sheet")

	# On-screen tests
	_main._open_page("tests")
	_main._run_self_test()
	_check(_main.tests_summary.text.begins_with("✓"), "on-screen tests pass (got '%s')" % _main.tests_summary.text)
	_main._close_page()

	# Mode menu
	_main._show_mode_menu()
	_main.mode_menu.id_pressed.emit(0)
	_check(_main.mode == "simple" and _main.mode_button.text == "MODE_SIMPLE", "mode menu → Basic")
	_main.mode_menu.hide()
	_ctrl_key(KEY_2)
	_check(_main.mode == "scientific", "Ctrl+2 → Scientific")

	# Settings persisted (saves are debounced: flush first)
	_main._flush_save()
	var saved = load("res://scripts/settings.gd").new()
	saved.path = TEST_SETTINGS
	saved.load_settings()
	_check(saved.sound == false and saved.language == "en" and saved.history.size() > 0 and saved.mode == "scientific",
		"settings saved to disk")


func _test_layouts() -> void:
	_main.layout = "landscape"
	_main._update_layout()
	_check(_main.keypads.get_parent() == _main.content and _main.keypads.visible, "landscape: keypad on the right")
	_check(_main.display.size_flags_vertical == Control.SIZE_EXPAND_FILL, "landscape: display fills the left column")
	_main._open_page("history")
	_check(_main.side_panel.get_parent() == _main.left_column and _main.keypads.visible, "landscape: sheet under the display")
	_main._close_page()
	_main.layout = "wide"
	_main._update_layout()
	_check(_main.keypads.get_parent() == _main.body and _main.history_view.visible and _main.keypads.visible,
		"wide: history docked next to the keypad")
	_main.layout = "portrait"
	_main._update_layout()
	_check(not _main.side_panel.visible and _main.keypads.visible, "portrait: keypad only")

	# Keys adapt their font size to their height
	var grid: GridContainer = _main._keypads["scientific"]
	grid.size = Vector2(300, 280)
	_main._scale_keypad("scientific")
	var small: int = grid.get_child(15).get_theme_font_size("font_size")
	grid.size = Vector2(400, 560)
	_main._scale_keypad("scientific")
	var large: int = grid.get_child(15).get_theme_font_size("font_size")
	_check(small < large, "key font scales with the key size (%d < %d)" % [small, large])


func _test_languages() -> void:
	var expected := { "fr": "Scientifique", "es": "Científica", "de": "Wissenschaftlich", "it": "Scientifica", "pt": "Científica" }
	for language in expected:
		_main._set_language(language)
		_check(_main.tr("MODE_SCIENTIFIC") == expected[language], "%s: mode name translated" % language)
		_typed(["1", "/", "4", "="])
		_check(_main.result_label.text == "0,25", "%s: decimal comma (got '%s')" % [language, _main.result_label.text])
	_main._set_language("fr")
	_typed(["1", "/", "0", "="])
	_check(_main.result_label.text == "Division par zéro", "French error (got '%s')" % _main.result_label.text)
	_main._open_page("knowledge")
	var title: Label = _main.knowledge_list.get_child(0)
	_check(title.text == "Carrés parfaits", "knowledge page rebuilt in French (got '%s')" % title.text)
	_main._close_page()
	_main._set_language("en")


# --- Input helpers ---------------------------------------------------------

func _typed(chars: Array) -> void:
	_key(KEY_ESCAPE)
	_typed_more(chars)


func _typed_more(chars: Array) -> void:
	for ch in chars:
		_char(ch)


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


func _ctrl_key(keycode: Key, shift := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.ctrl_pressed = true
	ev.shift_pressed = shift
	ev.pressed = true
	_main._unhandled_input(ev)


func _char(ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.unicode = ch.unicode_at(0)
	_main._unhandled_input(ev)


func _press(id: String) -> void:
	_main._buttons[_main.mode][id].emit_signal("pressed")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: " + label)
