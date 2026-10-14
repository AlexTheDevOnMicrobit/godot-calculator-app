extends Control
## Main calculator screen: builds the keypad, handles mouse/touch, keyboard
## and numeric keypad input, history, memory, settings, themes, feedback
## (sounds / vibration) and the on-screen tests panel.

const Evaluator := preload("res://scripts/evaluator.gd")
const ExpressionEditor := preload("res://scripts/expression_editor.gd")
const Settings := preload("res://scripts/settings.gd")
const Feedback := preload("res://scripts/feedback.gd")
const SelfTest := preload("res://scripts/self_test.gd")

const DARK_THEME := preload("res://assets/theme/dark_theme.tres")
const LIGHT_THEME := preload("res://assets/theme/light_theme.tres")

const MAX_HISTORY := 50
const RESULT_FONT_MAX := 48
const RESULT_FONT_MIN := 18
## Above this width, the side panel (history / settings) is docked next to the keypad.
const WIDE_LAYOUT_WIDTH := 720.0
const BASE_MARGIN := 14

## Keypad definition (5 columns). Each key:
##   id: action id, label/insert: primary function, label2/insert2: "2nd" function,
##   style: theme type variation, tip/tip2: tooltip translation keys.
const KEYS := [
	{ "id": "second", "label": "2nd", "style": "ToggleButton", "tip": "TIP_SECOND" },
	{ "id": "pi", "label": "π", "insert": "π", "style": "FunctionButton", "tip": "TIP_PI" },
	{ "id": "e", "label": "e", "insert": "e", "style": "FunctionButton", "tip": "TIP_E" },
	{ "id": "lparen", "label": "(", "insert": "(", "style": "FunctionButton", "tip": "TIP_LPAREN" },
	{ "id": "rparen", "label": ")", "insert": ")", "style": "FunctionButton", "tip": "TIP_RPAREN" },

	{ "id": "sin", "label": "sin", "insert": "sin(", "label2": "sin⁻¹", "insert2": "asin(", "style": "FunctionButton", "tip": "TIP_SIN", "tip2": "TIP_ASIN" },
	{ "id": "cos", "label": "cos", "insert": "cos(", "label2": "cos⁻¹", "insert2": "acos(", "style": "FunctionButton", "tip": "TIP_COS", "tip2": "TIP_ACOS" },
	{ "id": "tan", "label": "tan", "insert": "tan(", "label2": "tan⁻¹", "insert2": "atan(", "style": "FunctionButton", "tip": "TIP_TAN", "tip2": "TIP_ATAN" },
	{ "id": "ln", "label": "ln", "insert": "ln(", "label2": "eˣ", "insert2": "e^(", "style": "FunctionButton", "tip": "TIP_LN", "tip2": "TIP_EXP" },
	{ "id": "log", "label": "log", "insert": "log(", "label2": "10ˣ", "insert2": "10^(", "style": "FunctionButton", "tip": "TIP_LOG", "tip2": "TIP_POW10" },

	{ "id": "square", "label": "x²", "insert": "^2", "label2": "x³", "insert2": "^3", "style": "FunctionButton", "tip": "TIP_SQUARE", "tip2": "TIP_CUBE" },
	{ "id": "power", "label": "xʸ", "insert": "^", "label2": "mod", "insert2": "mod", "style": "FunctionButton", "tip": "TIP_POWER", "tip2": "TIP_MOD" },
	{ "id": "sqrt", "label": "√", "insert": "√(", "label2": "∛", "insert2": "∛(", "style": "FunctionButton", "tip": "TIP_SQRT", "tip2": "TIP_CBRT" },
	{ "id": "fact", "label": "x!", "insert": "!", "label2": "|x|", "insert2": "abs(", "style": "FunctionButton", "tip": "TIP_FACT", "tip2": "TIP_ABS" },
	{ "id": "inv", "label": "1/x", "insert": "^(−1)", "label2": "Rand", "insert2": "rand", "style": "FunctionButton", "tip": "TIP_INV", "tip2": "TIP_RAND" },

	{ "id": "mc", "label": "MC", "style": "MemoryButton", "tip": "TIP_MC" },
	{ "id": "mr", "label": "MR", "style": "MemoryButton", "tip": "TIP_MR" },
	{ "id": "mplus", "label": "M+", "style": "MemoryButton", "tip": "TIP_MPLUS" },
	{ "id": "mminus", "label": "M−", "style": "MemoryButton", "tip": "TIP_MMINUS" },
	{ "id": "percent", "label": "%", "insert": "%", "style": "FunctionButton", "tip": "TIP_PERCENT" },

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
	{ "id": "dot", "label": ".", "insert": ".", "style": "DigitButton", "tip": "TIP_DECIMAL" },
	{ "id": "exp", "label": "EXP", "insert": "E", "style": "FunctionButton", "tip": "TIP_EXPONENT" },
	{ "id": "ans", "label": "Ans", "insert": "Ans", "style": "FunctionButton", "tip": "TIP_ANS" },
	{ "id": "equals", "label": "=", "style": "EqualsButton", "tip": "TIP_EQUALS" },
]

## Keyboard shortcuts on characters (unicode) -> key id.
const CHAR_SHORTCUTS := {
	"0": "0", "1": "1", "2": "2", "3": "3", "4": "4",
	"5": "5", "6": "6", "7": "7", "8": "8", "9": "9",
	".": "dot", ",": "dot",
	"+": "add", "-": "sub", "*": "mul", "x": "mul", "/": "div", ":": "div",
	"^": "power", "(": "lparen", ")": "rparen", "!": "fact", "%": "percent",
	"=": "equals",
	"s": "sin", "c": "cos", "t": "tan", "l": "ln", "g": "log", "r": "sqrt",
	"p": "pi", "e": "e", "a": "ans", "h": "history",
}

## Numeric keypad keycodes -> key id (works with or without unicode).
const KEYPAD_SHORTCUTS := {
	KEY_KP_0: "0", KEY_KP_1: "1", KEY_KP_2: "2", KEY_KP_3: "3", KEY_KP_4: "4",
	KEY_KP_5: "5", KEY_KP_6: "6", KEY_KP_7: "7", KEY_KP_8: "8", KEY_KP_9: "9",
	KEY_KP_PERIOD: "dot", KEY_KP_ADD: "add", KEY_KP_SUBTRACT: "sub",
	KEY_KP_MULTIPLY: "mul", KEY_KP_DIVIDE: "div", KEY_KP_ENTER: "equals",
}

## Settings panel rows: setting name -> [label key, option keys...]
const SETTING_ROWS := [
	["theme", "THEME", ["THEME_AUTO", "THEME_DARK", "THEME_LIGHT"]],
	["language", "LANGUAGE", ["LANG_EN", "LANG_FR"]],
	["angle", "ANGLE_UNIT", ["DEGREES", "RADIANS"]],
	["sound", "SOUND", ["ON", "OFF"]],
	["vibration", "VIBRATION", ["ON", "OFF"]],
]
const LANGUAGES := ["en", "fr"]

var evaluator := Evaluator.new()
var editor := ExpressionEditor.new()
var settings := Settings.new()
var feedback: Feedback
var error_key := "" # translation key of the error currently displayed
var second_active := false
var side_page := "" # "", "history", "settings" or "tests"

var _buttons := {} # id -> Button
var _key_defs := {} # id -> Dictionary
var _setting_buttons := {} # setting name -> Array[Button]
var _message_tween: Tween
var _shake_tween: Tween
var _wide := false

@onready var margin: MarginContainer = %Margin
@onready var title_label: Label = %Title
@onready var angle_button: Button = %AngleButton
@onready var theme_button: Button = %ThemeButton
@onready var history_button: Button = %HistoryButton
@onready var settings_button: Button = %SettingsButton
@onready var display: PanelContainer = %Display
@onready var angle_label: Label = %AngleLabel
@onready var second_label: Label = %SecondLabel
@onready var memory_label: Label = %MemoryLabel
@onready var message_label: Label = %MessageLabel
@onready var expression_label: Label = %ExpressionLabel
@onready var result_label: Label = %ResultLabel
@onready var keypad: GridContainer = %Keypad
@onready var side_panel: PanelContainer = %SidePanel
@onready var history_view: VBoxContainer = %HistoryView
@onready var settings_view: VBoxContainer = %SettingsView
@onready var tests_view: VBoxContainer = %TestsView
@onready var history_list: ItemList = %HistoryList
@onready var history_empty: Label = %HistoryEmpty
@onready var clear_history_button: Button = %ClearHistoryButton
@onready var settings_list: VBoxContainer = %SettingsList
@onready var tests_summary: Label = %TestsSummary
@onready var tests_report: RichTextLabel = %TestsReport


func _ready() -> void:
	randomize()
	settings.load_settings()
	evaluator.angle_mode = settings.angle_mode as Evaluator.AngleMode
	evaluator.last_answer = settings.last_answer

	feedback = Feedback.new()
	feedback.name = "Feedback"
	add_child(feedback)

	_build_keypad()
	_build_settings_panel()

	angle_button.pressed.connect(_toggle_angle_mode)
	theme_button.pressed.connect(_toggle_theme)
	history_button.pressed.connect(_toggle_page.bind("history"))
	settings_button.pressed.connect(_toggle_page.bind("settings"))
	history_list.item_clicked.connect(_on_history_item_clicked)
	clear_history_button.pressed.connect(_clear_history)
	%RunTestsButton.pressed.connect(_run_self_test)
	%TestSoundButton.pressed.connect(func(): feedback._players[Feedback.Kind.RESULT].play())
	%TestVibrationButton.pressed.connect(func(): Input.vibrate_handheld(300))
	%TestVibrationButton.disabled = not Feedback.can_vibrate()
	for view in [history_view, settings_view, tests_view]:
		view.get_node("Header/CloseButton").pressed.connect(_close_page)
	result_label.resized.connect(_fit_result_font)
	get_viewport().size_changed.connect(_on_viewport_resized)

	DisplayServer.window_set_min_size(Vector2i(340, 600))
	TranslationServer.set_locale(settings.language)
	_apply_theme()
	_apply_feedback_settings()
	_on_viewport_resized()
	_refresh_all()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			if is_node_ready():
				_refresh_all()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save()
		NOTIFICATION_APPLICATION_PAUSED:
			_save()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			# The system theme may have changed while the app was in background.
			if is_node_ready() and settings.theme_mode == Settings.ThemeMode.AUTO:
				_apply_theme()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button: close the open panel first, then quit.
			if side_page != "":
				_close_page()
			else:
				_save()
				get_tree().quit()


# --- Keypad ----------------------------------------------------------------

func _build_keypad() -> void:
	for def in KEYS:
		var button := Button.new()
		button.name = "Key_" + def["id"]
		button.text = def["label"]
		button.theme_type_variation = def["style"]
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(52, 46)
		button.tooltip_text = def.get("tip", "")
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
		if def.has("icon"):
			button.icon = load(def["icon"])
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if def["id"] == "second":
			button.toggle_mode = true
		button.pressed.connect(_on_key_pressed.bind(def["id"]))
		button.button_down.connect(_animate_press.bind(button, true))
		button.button_up.connect(_animate_press.bind(button, false))
		button.resized.connect(func(): button.pivot_offset = button.size / 2.0)
		keypad.add_child(button)
		_buttons[def["id"]] = button
		_key_defs[def["id"]] = def


func _on_key_pressed(id: String) -> void:
	var def: Dictionary = _key_defs[id]
	if id != "second":
		error_key = ""
	var accepted := true
	match id:
		"second":
			_set_second(not second_active)
			feedback.play(Feedback.Kind.KEY)
			return
		"equals":
			accepted = _evaluate()
		"clear":
			editor.clear()
		"back":
			accepted = editor.backspace()
		"mc":
			settings.memory = 0.0
			_save()
		"mr":
			accepted = editor.insert(_number_for_insert(settings.memory))
		"mplus", "mminus":
			var value = _current_value()
			accepted = value != null
			if accepted:
				settings.memory += value if id == "mplus" else -value
				_save()
				_show_message("M = " + _format(settings.memory))
		_:
			var text: String = def.get("insert2", def["insert"]) if second_active else def["insert"]
			accepted = editor.insert(text)
	if id != "equals":
		feedback.play(Feedback.Kind.KEY if accepted else Feedback.Kind.ERROR)
	if second_active:
		_set_second(false)
	_refresh_display()


func _set_second(active: bool) -> void:
	second_active = active
	_buttons["second"].set_pressed_no_signal(active)
	for id in _key_defs:
		var def: Dictionary = _key_defs[id]
		if def.has("label2"):
			_buttons[id].text = def["label2"] if active else def["label"]
			_buttons[id].tooltip_text = def.get("tip2", def.get("tip", "")) if active else def.get("tip", "")
	second_label.visible = active


# --- Evaluation ------------------------------------------------------------

func _evaluate() -> bool:
	if editor.is_empty() or editor.just_evaluated:
		return false
	var result := evaluator.evaluate(editor.text)
	if not result["ok"]:
		_show_error(result["error"])
		return false
	evaluator.last_answer = result["value"]
	settings.last_answer = result["value"]
	# A plain number ("12") is not worth an history entry.
	if not editor.text.replace("−", "-").is_valid_float():
		settings.history.push_front({ "expr": editor.text, "value": result["value"] })
		if settings.history.size() > MAX_HISTORY:
			settings.history.resize(MAX_HISTORY)
	editor.just_evaluated = true
	feedback.play(Feedback.Kind.RESULT)
	_save()
	_refresh_history()
	return true


## Value of the current expression (or last result), null if invalid.
func _current_value() -> Variant:
	if editor.just_evaluated or editor.is_empty():
		return evaluator.last_answer
	var result := evaluator.evaluate(editor.text)
	if result["ok"]:
		return result["value"]
	_show_error(result["error"])
	return null


func _number_for_insert(value: float) -> String:
	var text := Evaluator.format_number(value).replace("-", "−")
	return "(" + text + ")" if value < 0.0 or text.contains("E") else text


# --- Display ---------------------------------------------------------------

func _refresh_all() -> void:
	DisplayServer.window_set_title(tr("APP_TITLE"))
	_set_second(second_active)
	_refresh_angle()
	_refresh_history()
	_refresh_settings_panel()
	_refresh_display()


func _refresh_display() -> void:
	var expr := _pretty(editor.text)
	expression_label.text = expr + " =" if editor.just_evaluated else expr
	result_label.remove_theme_color_override("font_color")
	if error_key != "":
		result_label.text = tr(error_key)
		result_label.add_theme_color_override("font_color", get_theme_color("error", "App"))
	elif editor.just_evaluated:
		result_label.text = _format(evaluator.last_answer, true)
	elif editor.is_empty():
		result_label.text = "0"
	elif editor.text.contains("rand"):
		result_label.text = "" # no live preview for random numbers
	else:
		var preview := evaluator.evaluate(editor.text)
		result_label.text = _format(preview["value"], true) if preview["ok"] else ""
		result_label.add_theme_color_override("font_color", get_theme_color("preview", "App"))
	memory_label.visible = settings.memory != 0.0
	_fit_result_font()


func _show_error(key: String) -> void:
	editor.just_evaluated = false
	error_key = key
	feedback.play(Feedback.Kind.ERROR)
	_shake(display)
	_refresh_display()


func _pretty(text: String) -> String:
	var pretty := text
	for pair in [["asin(", "sin⁻¹("], ["acos(", "cos⁻¹("], ["atan(", "tan⁻¹("], ["mod", " mod "], ["abs(", "abs("]]:
		pretty = pretty.replace(pair[0], pair[1])
	return pretty.replace(".", _decimal_separator())


func _format(value: float, grouped := false) -> String:
	var group := ""
	if grouped:
		group = "\u202F" if settings.language == "fr" else ","
	return Evaluator.format_number(value, _decimal_separator(), group).replace("-", "−")


func _decimal_separator() -> String:
	return "," if settings.language == "fr" else "."


func _fit_result_font() -> void:
	var font := result_label.get_theme_font("font")
	var available := result_label.size.x
	if available <= 0.0:
		return
	var font_size := RESULT_FONT_MAX
	while font_size > RESULT_FONT_MIN and font.get_string_size(result_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 2
	result_label.add_theme_font_size_override("font_size", font_size)


# --- Animations ------------------------------------------------------------

func _animate_press(button: Button, down: bool) -> void:
	var tween := button.create_tween()
	if down:
		tween.tween_property(button, "scale", Vector2(0.94, 0.94), 0.06)
	else:
		tween.tween_property(button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Visual feedback when a key is triggered from the keyboard.
func _flash(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	button.scale = Vector2(0.94, 0.94)
	button.modulate = Color(1.35, 1.35, 1.35)
	var tween := button.create_tween().set_parallel()
	tween.tween_property(button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color.WHITE, 0.2)


func _shake(control: Control) -> void:
	if _shake_tween and _shake_tween.is_running():
		return
	var origin := control.position.x
	_shake_tween = create_tween()
	for offset in [-8.0, 7.0, -5.0, 3.0, 0.0]:
		_shake_tween.tween_property(control, "position:x", origin + offset, 0.04)


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.2)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


# --- Layout & side panel ---------------------------------------------------

func _on_viewport_resized() -> void:
	_wide = get_viewport_rect().size.x >= WIDE_LAYOUT_WIDTH
	_apply_safe_area()
	_update_layout()


## Keeps content out of notches / status bar / gesture area on mobile.
func _apply_safe_area() -> void:
	var insets := [0.0, 0.0, 0.0, 0.0] # left, top, right, bottom
	if OS.has_feature("mobile"):
		var window_size := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if window_size.x > 0.0 and safe.size.x > 0.0:
			var ratio := get_viewport_rect().size.x / window_size.x
			insets = [safe.position.x * ratio, safe.position.y * ratio,
				(window_size.x - safe.end.x) * ratio, (window_size.y - safe.end.y) * ratio]
	for i in 4:
		var side: String = ["left", "top", "right", "bottom"][i]
		margin.add_theme_constant_override("margin_" + side, BASE_MARGIN + int(maxf(insets[i], 0.0)))


func _toggle_page(page: String) -> void:
	if side_page == page and not (_wide and page == "history"):
		_close_page()
	else:
		_open_page(page)


func _open_page(page: String) -> void:
	var was_visible := side_panel.visible
	side_page = page
	_update_layout()
	if not was_visible or not _wide:
		side_panel.modulate.a = 0.0
		create_tween().tween_property(side_panel, "modulate:a", 1.0, 0.15)


func _close_page() -> void:
	side_page = ""
	_update_layout()


func _update_layout() -> void:
	var page := side_page
	if _wide and page == "":
		page = "history" # docked history on wide screens
	title_label.text = "APP_TITLE" if _wide else "APP_TITLE_SHORT"
	side_panel.visible = page != ""
	keypad.visible = _wide or page == ""
	history_view.visible = page == "history"
	settings_view.visible = page == "settings"
	tests_view.visible = page == "tests"
	history_view.get_node("Header/CloseButton").visible = not _wide
	history_button.set_pressed_no_signal(page == "history")
	settings_button.set_pressed_no_signal(page == "settings" or page == "tests")


# --- Settings: angle, theme, language, feedback ----------------------------

func _toggle_angle_mode() -> void:
	_set_angle_mode(1 - evaluator.angle_mode)
	feedback.play(Feedback.Kind.KEY)


func _set_angle_mode(mode: int) -> void:
	evaluator.angle_mode = mode as Evaluator.AngleMode
	settings.angle_mode = mode
	_refresh_angle()
	_refresh_settings_panel()
	_refresh_display()
	_save()


func _refresh_angle() -> void:
	var text := "DEG" if evaluator.angle_mode == Evaluator.AngleMode.DEG else "RAD"
	angle_button.text = text
	angle_label.text = text


func _toggle_theme() -> void:
	_set_theme_mode(Settings.ThemeMode.LIGHT if _is_dark() else Settings.ThemeMode.DARK)
	feedback.play(Feedback.Kind.KEY)


func _set_theme_mode(mode: int) -> void:
	settings.theme_mode = mode as Settings.ThemeMode
	_apply_theme()
	_refresh_settings_panel()
	_save()


func _is_dark() -> bool:
	match settings.theme_mode:
		Settings.ThemeMode.DARK:
			return true
		Settings.ThemeMode.LIGHT:
			return false
	return DisplayServer.is_dark_mode() if DisplayServer.is_dark_mode_supported() else true


func _apply_theme() -> void:
	var dark := _is_dark()
	theme = DARK_THEME if dark else LIGHT_THEME
	theme_button.text = "☀" if dark else "☾"
	RenderingServer.set_default_clear_color(get_theme_color("bg_bottom", "App"))
	_refresh_display()


func _set_language(language: String) -> void:
	settings.language = language
	TranslationServer.set_locale(language)
	_save()


func _apply_feedback_settings() -> void:
	feedback.sound_enabled = settings.sound
	feedback.vibration_enabled = settings.vibration


func _build_settings_panel() -> void:
	for row in SETTING_ROWS:
		var setting: String = row[0]
		var label := Label.new()
		label.name = setting.capitalize() + "Label"
		label.theme_type_variation = &"SectionLabel"
		label.text = row[1]
		settings_list.add_child(label)

		var group := ButtonGroup.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		settings_list.add_child(hbox)
		_setting_buttons[setting] = []
		for i in row[2].size():
			var button := Button.new()
			button.text = row[2][i]
			button.toggle_mode = true
			button.button_group = group
			button.focus_mode = Control.FOCUS_NONE
			button.theme_type_variation = &"SegmentButton"
			button.custom_minimum_size = Vector2(0, 40)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_on_setting_chosen.bind(setting, i))
			hbox.add_child(button)
			_setting_buttons[setting].append(button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	settings_list.add_child(spacer)
	var tests_button := Button.new()
	tests_button.name = "OpenTestsButton"
	tests_button.text = "SELF_TEST"
	tests_button.focus_mode = Control.FOCUS_NONE
	tests_button.theme_type_variation = &"ToggleButton"
	tests_button.custom_minimum_size = Vector2(0, 44)
	tests_button.pressed.connect(_open_page.bind("tests"))
	settings_list.add_child(tests_button)

	var about_title := Label.new()
	about_title.theme_type_variation = &"SectionLabel"
	about_title.text = "ABOUT"
	settings_list.add_child(about_title)
	var about := Label.new()
	about.name = "AboutLabel"
	about.theme_type_variation = &"MutedLabel"
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	settings_list.add_child(about)


func _refresh_settings_panel() -> void:
	if _setting_buttons.is_empty():
		return
	var selected := {
		"theme": settings.theme_mode,
		"language": LANGUAGES.find(settings.language),
		"angle": evaluator.angle_mode,
		"sound": 0 if settings.sound else 1,
		"vibration": 0 if settings.vibration else 1,
	}
	for setting in selected:
		var buttons: Array = _setting_buttons[setting]
		for i in buttons.size():
			buttons[i].set_pressed_no_signal(i == selected[setting])
	settings_list.get_node("VibrationLabel").text = "VIBRATION" if Feedback.can_vibrate() else "VIBRATION_MOBILE_ONLY"
	settings_list.get_node("AboutLabel").text = tr("ABOUT_TEXT") % [
		ProjectSettings.get_setting("application/config/version", "?"),
		Engine.get_version_info()["string"],
	]


func _on_setting_chosen(setting: String, index: int) -> void:
	feedback.play(Feedback.Kind.KEY)
	match setting:
		"theme":
			_set_theme_mode(index)
		"language":
			_set_language(LANGUAGES[index])
		"angle":
			_set_angle_mode(index)
		"sound":
			settings.sound = index == 0
			_apply_feedback_settings()
			_save()
		"vibration":
			settings.vibration = index == 0
			_apply_feedback_settings()
			_save()


# --- History ---------------------------------------------------------------

func _refresh_history() -> void:
	history_list.clear()
	for entry in settings.history:
		var index := history_list.add_item("%s = %s" % [_pretty(entry["expr"]), _format(entry["value"], true)])
		history_list.set_item_tooltip(index, _pretty(entry["expr"]))
	history_empty.visible = settings.history.is_empty()
	history_list.visible = not settings.history.is_empty()
	clear_history_button.disabled = settings.history.is_empty()


func _on_history_item_clicked(index: int, _at: Vector2, _mouse_button: int) -> void:
	var entry: Dictionary = settings.history[index]
	editor.text = entry["expr"]
	editor.just_evaluated = true
	evaluator.last_answer = entry["value"]
	error_key = ""
	feedback.play(Feedback.Kind.KEY)
	if not _wide:
		_close_page()
	_refresh_display()


func _clear_history() -> void:
	settings.history.clear()
	_refresh_history()
	_save()


# --- On-screen tests -------------------------------------------------------

func _run_self_test() -> void:
	var suite = SelfTest.new().run()
	var ok: bool = suite.failed == 0
	tests_summary.text = ("✓ " if ok else "✗ ") + tr("SELF_TEST_RESULT") % [suite.passed, suite.total()]
	tests_summary.add_theme_color_override("font_color", get_theme_color("success" if ok else "error", "App"))
	var success := get_theme_color("success", "App").to_html(false)
	var error := get_theme_color("error", "App").to_html(false)
	var muted := get_theme_color("muted", "App").to_html(false)
	var lines: PackedStringArray = []
	for section in suite.sections:
		var color := success if section["passed"] == section["total"] else error
		lines.append("[color=#%s]●[/color] %s  [color=#%s]%d / %d[/color]" % [color, section["name"], muted, section["passed"], section["total"]])
	if not suite.failures.is_empty():
		lines.append("\n[b]%s[/b]" % tr("SELF_TEST_FAILURES"))
		for failure in suite.failures:
			lines.append("[color=#%s]✗[/color] %s" % [error, failure])
	lines.append("\n[b]%s[/b]" % tr("DEVICE"))
	for line in _device_info():
		lines.append("[color=#%s]%s[/color]" % [muted, line])
	tests_report.text = "\n".join(lines)
	feedback.play(Feedback.Kind.RESULT if ok else Feedback.Kind.ERROR)


func _device_info() -> PackedStringArray:
	var screen := DisplayServer.screen_get_size()
	return PackedStringArray([
		"OS: %s %s" % [OS.get_name(), OS.get_version()],
		"Model: %s" % OS.get_model_name(),
		"Screen: %dx%d · %d dpi · scale %.2f" % [screen.x, screen.y, DisplayServer.screen_get_dpi(), DisplayServer.screen_get_scale()],
		"Window: %dx%d · viewport %dx%d" % [
			DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
			get_viewport_rect().size.x, get_viewport_rect().size.y],
		"Locale: %s · Renderer: %s" % [OS.get_locale(), ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")],
		"GPU: %s" % RenderingServer.get_video_adapter_name(),
		"Dark mode: %s · Vibration: %s" % [
			str(DisplayServer.is_dark_mode()) if DisplayServer.is_dark_mode_supported() else "n/a",
			"yes" if Feedback.can_vibrate() else "no"],
		"Godot %s" % Engine.get_version_info()["string"],
	])


# --- Persistence -----------------------------------------------------------

func _save() -> void:
	settings.angle_mode = evaluator.angle_mode
	settings.last_answer = evaluator.last_answer
	settings.save()


# --- Keyboard & numeric keypad ---------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event := event as InputEventKey
	var id := _key_id_for_event(key_event)
	if id == "":
		return
	get_viewport().set_input_as_handled()
	if key_event.echo and id != "back":
		return
	match id:
		"copy":
			_copy_result()
		"paste":
			_paste(DisplayServer.clipboard_get())
		"angle":
			_toggle_angle_mode()
		"history":
			_toggle_page("history")
		"settings":
			_toggle_page("settings")
		"language":
			_set_language("en" if settings.language == "fr" else "fr")
		"theme":
			_toggle_theme()
		_:
			if _buttons.has(id):
				_flash(_buttons[id])
			_on_key_pressed(id)


func _key_id_for_event(event: InputEventKey) -> String:
	var keycode := event.keycode
	if event.ctrl_pressed or event.meta_pressed:
		match keycode:
			KEY_C:
				return "copy"
			KEY_V:
				return "paste"
		return ""
	# Physical key first: the numeric keypad always types digits, even with
	# NumLock off (where it would otherwise send Home, arrows, End...).
	if KEYPAD_SHORTCUTS.has(event.physical_keycode):
		return KEYPAD_SHORTCUTS[event.physical_keycode]
	if KEYPAD_SHORTCUTS.has(keycode):
		return KEYPAD_SHORTCUTS[keycode]
	match keycode:
		KEY_ENTER:
			return "equals"
		KEY_BACKSPACE:
			return "back"
		KEY_ESCAPE, KEY_DELETE:
			return "clear"
		KEY_F2:
			return "angle"
		KEY_F3:
			return "language"
		KEY_F4:
			return "settings"
		KEY_F6:
			return "theme"
		KEY_TAB:
			return "second"
	if event.unicode == 0:
		return ""
	return CHAR_SHORTCUTS.get(String.chr(event.unicode).to_lower(), "")


func _copy_result() -> void:
	var value = null
	if editor.just_evaluated:
		value = evaluator.last_answer
	elif not editor.is_empty() and error_key == "":
		var preview := evaluator.evaluate(editor.text)
		if preview["ok"]:
			value = preview["value"]
	if value == null:
		feedback.play(Feedback.Kind.ERROR)
		return
	DisplayServer.clipboard_set(Evaluator.format_number(value, _decimal_separator()))
	_show_message(tr("COPIED"))


func _paste(text: String) -> void:
	var cleaned := text.strip_edges().replace(" ", "").replace("\u202F", "").replace("\u00A0", "")
	if cleaned == "":
		return
	if not evaluator.evaluate(cleaned)["ok"]:
		_show_error("ERR_SYNTAX")
		return
	cleaned = cleaned.replace(",", ".").replace("-", "−").replace("*", "×").replace("/", "÷")
	if editor.just_evaluated:
		editor.clear()
	editor.text += cleaned
	error_key = ""
	_show_message(tr("PASTED"))
	_refresh_display()
