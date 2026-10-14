extends Control
## Main screen. Four modes (Basic, Scientific, Programmer, Converter), a
## textbook-style display and a side sheet for history, functions, settings,
## basic knowledge, help and the on-screen tests.
##
## Layouts: "portrait" (keypad under the display, sheets replace the keypad),
## "wide" (history docked next to the keypad) and "landscape" (display on the
## left, keypad on the right). Keypads and sheets are built on first use.

const Evaluator := preload("res://scripts/evaluator.gd")
const ExpressionEditor := preload("res://scripts/expression_editor.gd")
const ProgrammerEvaluator := preload("res://scripts/programmer_evaluator.gd")
const MathFormat := preload("res://scripts/math_format.gd")
const Keypads := preload("res://scripts/keypads.gd")
const Settings := preload("res://scripts/settings.gd")
const Feedback := preload("res://scripts/feedback.gd")
const SelfTest := preload("res://scripts/self_test.gd")

const DARK_THEME := preload("res://assets/theme/dark_theme.tres")
const LIGHT_THEME := preload("res://assets/theme/light_theme.tres")
const CHEVRON_RIGHT := preload("res://assets/icons/chevron_right.svg")

const MAX_HISTORY := 50
const RESULT_FONT_MAX := 52
const RESULT_FONT_MIN := 18
const WIDE_LAYOUT_WIDTH := 720.0
const LANDSCAPE_RATIO := 1.15
const BASE_MARGIN := 12
const SAVE_DELAY := 0.4
## Key height for which the theme font sizes are designed.
const KEY_DESIGN_HEIGHT := 60.0

const MODE_KEYS := {
	"simple": "MODE_SIMPLE", "scientific": "MODE_SCIENTIFIC",
	"programmer": "MODE_PROGRAMMER", "converter": "MODE_CONVERTER",
}
const LANGUAGE_NAMES := {
	"en": "English", "fr": "Français", "es": "Español", "de": "Deutsch", "it": "Italiano", "pt": "Português",
}
## Font size of each key style (see tools/generate_themes.py), scaled with the key size.
const KEY_FONT_SIZES := {
	"DigitButton": 26, "FunctionButton": 19, "OperatorButton": 28, "ClearButton": 20,
	"EqualsButton": 30, "ToggleButton": 18,
}
const BASE_NAMES := { 16: "HEX", 10: "DEC", 8: "OCT", 2: "BIN" }
const BASE_ORDER := [16, 10, 8, 2]

## Keyboard characters -> action. "key:" triggers a keypad key, otherwise the
## text is inserted (so shortcuts work in every mode, even without the key).
const CHAR_ACTIONS := {
	".": "key:dot", ",": "key:dot",
	"+": "+", "-": "−", "*": "×", "x": "×", "/": "÷", ":": "÷",
	"^": "^(", "(": "(", ")": ")", "!": "!", "%": "%", ";": ";",
	"=": "key:equals",
	"s": "sin(", "c": "cos(", "t": "tan(", "l": "ln(", "g": "log(", "r": "√(",
	"p": "π", "e": "e", "a": "Ans", "f": "frac(",
	"h": "history", "k": "knowledge",
	"&": "&", "|": "|", "~": "~", "<": "<<", ">": ">>",
}
## Text the programmer mode accepts from the keyboard (besides digits).
const PROGRAMMER_INSERTS := ["+", "−", "×", "÷", "(", ")", "&", "|", "~", "<<", ">>", "Ans"]

## Numeric keypad keycodes -> key id (works with or without NumLock).
const KEYPAD_SHORTCUTS := {
	KEY_KP_0: "0", KEY_KP_1: "1", KEY_KP_2: "2", KEY_KP_3: "3", KEY_KP_4: "4",
	KEY_KP_5: "5", KEY_KP_6: "6", KEY_KP_7: "7", KEY_KP_8: "8", KEY_KP_9: "9",
	KEY_KP_PERIOD: "dot", KEY_KP_ADD: "add", KEY_KP_SUBTRACT: "sub",
	KEY_KP_MULTIPLY: "mul", KEY_KP_DIVIDE: "div", KEY_KP_ENTER: "equals",
}

## Help page keyboard table: [keys, description key]
const SHORTCUTS := [
	["0–9  + − × ÷  ^", "SC_DIGITS"], ["Enter  =", "SC_ENTER"], ["⌫  Esc", "SC_EDIT"], ["→", "SC_NEXT"],
	["S C T L G R F", "SC_FUNCTIONS"], ["H  K  F4", "SC_PANELS"], ["F7  Ctrl+1…4", "SC_MODES"],
	["Ctrl+C  Ctrl+⇧+C  Ctrl+V", "SC_COPY"], ["F2", "SC_ANGLE"],
]
const HELP_TOPICS := ["MODES", "TEMPLATES", "SECOND", "DISPLAY", "TOOLS"]

enum DisplayAction { COPY, COPY_LATEX, PASTE }

var evaluator := Evaluator.new()
var editor := ExpressionEditor.new()
var programmer := ProgrammerEvaluator.new()
var programmer_editor := ExpressionEditor.new()
var math_format := MathFormat.new()
var settings := Settings.new()
var feedback: Feedback
var mode := "scientific"
var error_key := "" # translation key of the error currently displayed
var second_active := false
var show_fraction := false # ⇄: show the result as a fraction
var side_page := "" # "", "history", "functions", "settings", "knowledge", "help" or "tests"
var layout := "portrait" # "portrait", "wide" or "landscape"

var _keypads := {} # mode -> GridContainer (built on first use)
var _buttons := {} # mode -> { id -> Button }
var _key_defs := {} # mode -> { id -> Dictionary }
var _base_buttons := {} # base -> Button
var _setting_controls := {} # setting name -> Control(s)
var _built_pages := {} # page -> locale it was built for
var _preview_cache := { "text": null, "result": {} }
var _message_tween: Tween
var _shake_tween: Tween
var _save_timer: Timer
var _last_copied := "" # what the last copy put in the clipboard (for tests)
var _startup_ms := 0

@onready var background: PanelContainer = %Background
@onready var margin: MarginContainer = %Margin
@onready var mode_button: Button = %ModeButton
@onready var history_button: Button = %HistoryButton
@onready var menu_button: Button = %MenuButton
@onready var content: HBoxContainer = %Content
@onready var left_column: VBoxContainer = %LeftColumn
@onready var display: VBoxContainer = %Display
@onready var display_spacer: Control = %DisplaySpacer
@onready var angle_button: Button = %AngleButton
@onready var second_label: Label = %SecondLabel
@onready var memory_label: Label = %MemoryLabel
@onready var base_label: Label = %BaseLabel
@onready var message_label: Label = %MessageLabel
@onready var expression_view: Control = %ExpressionView
@onready var result_label: Label = %ResultLabel
@onready var result_math: Control = %ResultMath
@onready var base_rows: VBoxContainer = %BaseRows
@onready var converter_view: VBoxContainer = %ConverterView
@onready var body: HBoxContainer = %Body
@onready var keypads: MarginContainer = %Keypads
@onready var side_panel: PanelContainer = %SidePanel
@onready var history_view: VBoxContainer = %HistoryView
@onready var functions_view: VBoxContainer = %FunctionsView
@onready var settings_view: VBoxContainer = %SettingsView
@onready var knowledge_view: VBoxContainer = %KnowledgeView
@onready var help_view: VBoxContainer = %HelpView
@onready var tests_view: VBoxContainer = %TestsView
@onready var history_list: ItemList = %HistoryList
@onready var history_empty: Label = %HistoryEmpty
@onready var clear_history_button: Button = %ClearHistoryButton
@onready var functions_list: VBoxContainer = %FunctionsList
@onready var settings_list: VBoxContainer = %SettingsList
@onready var knowledge_list: VBoxContainer = %KnowledgeList
@onready var help_list: VBoxContainer = %HelpList
@onready var tests_summary: Label = %TestsSummary
@onready var tests_report: RichTextLabel = %TestsReport
@onready var display_menu: PopupMenu = %DisplayMenu
@onready var mode_menu: PopupMenu = %ModeMenu


func _ready() -> void:
	randomize()
	settings.load_settings()
	mode = settings.mode
	evaluator.angle_mode = settings.angle_mode as Evaluator.AngleMode
	evaluator.last_answer = settings.last_answer
	programmer.base = settings.programmer_base
	programmer_editor.programmer = true

	feedback = Feedback.new()
	feedback.name = "Feedback"
	add_child(feedback)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)
	_build_base_rows()
	_build_menus()

	mode_button.pressed.connect(_show_mode_menu)
	history_button.pressed.connect(_toggle_page.bind("history"))
	menu_button.pressed.connect(_toggle_page.bind("settings"))
	angle_button.pressed.connect(_toggle_angle_mode)
	display.gui_input.connect(_on_display_input)
	history_list.item_clicked.connect(_on_history_item_clicked)
	clear_history_button.pressed.connect(_clear_history)
	knowledge_list.value_chosen.connect(_on_knowledge_value)
	%RunTestsButton.pressed.connect(_run_self_test)
	%TestSoundButton.pressed.connect(func(): feedback.preview(Feedback.Kind.RESULT))
	%TestVibrationButton.pressed.connect(func(): Input.vibrate_handheld(300))
	%TestVibrationButton.disabled = not Feedback.can_vibrate()
	for view in [history_view, functions_view, settings_view, knowledge_view, help_view, tests_view]:
		view.get_node("Header/CloseButton").pressed.connect(_close_page)
		if view.has_node("Header/BackButton"):
			view.get_node("Header/BackButton").pressed.connect(_open_page.bind("settings"))
	converter_view.changed.connect(_save)
	result_label.resized.connect(_fit_result_font)
	get_viewport().size_changed.connect(_on_viewport_resized)

	DisplayServer.window_set_min_size(Vector2i(320, 480))
	TranslationServer.set_locale(settings.language)
	_apply_language_formats()
	converter_view.set_state(settings.converter)
	_apply_theme()
	_apply_feedback_settings()
	_set_mode(mode, false)
	_on_viewport_resized()
	_refresh_all()
	_startup_ms = Time.get_ticks_msec()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			if is_node_ready():
				_refresh_all()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if is_node_ready():
				_flush_save()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			# The system theme may have changed while the app was in background.
			if is_node_ready() and settings.theme_mode == Settings.ThemeMode.AUTO:
				_apply_theme()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button: sub-page -> settings -> close, then quit.
			if side_page in ["knowledge", "help", "tests"]:
				_open_page("settings")
			elif side_page != "":
				_close_page()
			else:
				_flush_save()
				get_tree().quit()


# --- Modes -----------------------------------------------------------------

func _build_menus() -> void:
	for i in Keypads.MODES.size():
		mode_menu.add_radio_check_item(MODE_KEYS[Keypads.MODES[i]], i)
	mode_menu.id_pressed.connect(func(id):
		feedback.play(Feedback.Kind.KEY)
		_set_mode(Keypads.MODES[id]))
	display_menu.add_item("COPY", DisplayAction.COPY)
	display_menu.add_item("COPY_LATEX", DisplayAction.COPY_LATEX)
	display_menu.add_separator()
	display_menu.add_item("PASTE", DisplayAction.PASTE)
	display_menu.id_pressed.connect(_on_display_menu)


func _show_mode_menu() -> void:
	for i in Keypads.MODES.size():
		mode_menu.set_item_checked(i, Keypads.MODES[i] == mode)
	var rect := mode_button.get_global_rect()
	mode_menu.popup(Rect2i(Vector2i(rect.position + Vector2(0, rect.size.y + 4)), Vector2i(220, 0)))


func _set_mode(new_mode: String, animate := true) -> void:
	if second_active:
		_set_second(false)
	mode = new_mode
	settings.mode = new_mode
	_ensure_keypad(new_mode)
	for keypad_mode in _keypads:
		_keypads[keypad_mode].visible = keypad_mode == new_mode
	mode_button.text = MODE_KEYS[new_mode]
	var calculator := new_mode in ["simple", "scientific"]
	display.visible = new_mode != "converter"
	converter_view.visible = new_mode == "converter"
	base_rows.visible = new_mode == "programmer"
	angle_button.visible = new_mode == "scientific"
	base_label.visible = false
	display.tooltip_text = "DISPLAY_TOOLTIP" if calculator else ""
	if side_page == "functions" and new_mode != "scientific":
		_close_page()
	error_key = ""
	_save()
	_update_layout()
	_refresh_display()
	if animate:
		var keypad: Control = _keypads[new_mode]
		keypad.modulate.a = 0.0
		create_tween().tween_property(keypad, "modulate:a", 1.0, 0.15)


func _cycle_mode() -> void:
	var index := Keypads.MODES.find(mode)
	_set_mode(Keypads.MODES[(index + 1) % Keypads.MODES.size()])


# --- Keypads ---------------------------------------------------------------

## Builds the keypad of [param keypad_mode] the first time it is needed.
func _ensure_keypad(keypad_mode: String) -> void:
	if _keypads.has(keypad_mode):
		return
	var keypad_layout := Keypads.layout(keypad_mode)
	var grid := GridContainer.new()
	grid.name = "Keypad_" + keypad_mode
	grid.columns = keypad_layout["columns"]
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	keypads.add_child(grid)
	_keypads[keypad_mode] = grid
	_buttons[keypad_mode] = {}
	_key_defs[keypad_mode] = {}
	for def in keypad_layout["keys"]:
		var button := Button.new()
		button.name = "Key_" + def["id"]
		button.text = def["label"]
		button.theme_type_variation = def["style"]
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(40, 36)
		button.tooltip_text = def.get("tip", "")
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.clip_text = true
		if def.has("icon"):
			button.icon = load(def["icon"])
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.toggle_mode = def["id"] == "second"
		button.pressed.connect(_on_key_pressed.bind(def["id"]))
		button.button_down.connect(_animate_press.bind(button, true))
		button.button_up.connect(_animate_press.bind(button, false))
		grid.add_child(button)
		_buttons[keypad_mode][def["id"]] = button
		_key_defs[keypad_mode][def["id"]] = def
	grid.resized.connect(_scale_keypad.bind(keypad_mode))
	if keypad_mode == "programmer":
		_update_digit_keys()


## Adapts the key labels to the key size (small phones, landscape, tablets).
func _scale_keypad(keypad_mode: String) -> void:
	var grid: GridContainer = _keypads[keypad_mode]
	var rows := ceili(float(grid.get_child_count()) / grid.columns)
	var key_height := (grid.size.y - 8.0 * (rows - 1)) / rows
	var key_width := (grid.size.x - 8.0 * (grid.columns - 1)) / grid.columns
	var factor := clampf(minf(key_height / KEY_DESIGN_HEIGHT, key_width / 70.0), 0.65, 1.3)
	for button in grid.get_children():
		button.pivot_offset = button.size / 2.0
		var base_size: int = KEY_FONT_SIZES.get(String(button.theme_type_variation), 20)
		button.add_theme_font_size_override("font_size", int(base_size * factor))


func _on_key_pressed(id: String) -> void:
	match mode:
		"converter":
			if id == "copy":
				_copy_result()
				return
			feedback.play(Feedback.Kind.KEY if converter_view.press(id) else Feedback.Kind.ERROR)
		"programmer":
			_programmer_key(id)
		_:
			_calculator_key(id)


func _calculator_key(id: String) -> void:
	var def: Dictionary = _key_defs[mode].get(id, {})
	if id != "second":
		error_key = ""
	var accepted := true
	var use_second := second_active and def.has("label2")
	match id:
		"second":
			if not _buttons[mode].has("second"):
				return
			_set_second(not second_active)
			feedback.play(Feedback.Kind.KEY)
			return
		"equals":
			accepted = _evaluate()
		"clear":
			editor.clear()
			show_fraction = false
		"back":
			accepted = editor.backspace()
			show_fraction = false
		"next":
			accepted = editor.next_slot()
		"fx":
			_set_second(false)
			_toggle_page("functions")
			feedback.play(Feedback.Kind.KEY)
			return
		"sd":
			accepted = editor.insert(def["insert2"]) if use_second else _toggle_fraction()
		"neg":
			accepted = editor.negate()
		"ans":
			accepted = editor.negate() if use_second else editor.insert("Ans")
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
			if def.is_empty():
				return
			accepted = editor.insert(def["insert2"] if use_second and def.has("insert2") else def["insert"])
			if accepted:
				show_fraction = false
	if id != "equals":
		feedback.play(Feedback.Kind.KEY if accepted else Feedback.Kind.ERROR)
	if second_active:
		_set_second(false)
	_refresh_display()


## Inserts text typed on the keyboard or chosen in a panel.
func _insert_text(text: String) -> void:
	error_key = ""
	var target := programmer_editor if mode == "programmer" else editor
	var accepted := target.insert(text)
	if accepted:
		show_fraction = false
	feedback.play(Feedback.Kind.KEY if accepted else Feedback.Kind.ERROR)
	_refresh_display()


func _set_second(active: bool) -> void:
	second_active = active
	if not _buttons.has(mode) or not _buttons[mode].has("second"):
		second_active = false
		second_label.visible = false
		return
	_buttons[mode]["second"].set_pressed_no_signal(active)
	for id in _key_defs[mode]:
		var def: Dictionary = _key_defs[mode][id]
		if def.has("label2"):
			var button: Button = _buttons[mode][id]
			button.text = def["label2"] if active else def["label"]
			button.tooltip_text = def.get("tip2", def.get("tip", "")) if active else def.get("tip", "")
	second_label.visible = active


# --- Calculator evaluation -------------------------------------------------

func _evaluate() -> bool:
	if editor.is_empty() or editor.just_evaluated:
		return false
	var result := evaluator.evaluate(editor.text)
	if not result["ok"]:
		_show_error(result["error"])
		return false
	editor.text += ")".repeat(maxi(editor.open_parens(), 0)) # close what was left open
	evaluator.last_answer = result["value"]
	settings.last_answer = result["value"]
	# A plain number ("12") is not worth an history entry.
	if not editor.text.replace("−", "-").is_valid_float():
		settings.history.push_front({ "expr": editor.text, "value": result["value"] })
		if settings.history.size() > MAX_HISTORY:
			settings.history.resize(MAX_HISTORY)
		_add_history_item(settings.history[0])
	editor.just_evaluated = true
	show_fraction = false
	feedback.play(Feedback.Kind.RESULT)
	_save()
	return true


## ⇄: switches the result between decimal and fraction form.
func _toggle_fraction() -> bool:
	if not editor.just_evaluated:
		if editor.is_empty() or not _evaluate():
			return false
	if Evaluator.to_fraction(evaluator.last_answer).is_empty():
		return false
	show_fraction = not show_fraction
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


## Live preview, cached: the display refreshes more often than the text changes.
func _preview(text: String) -> Dictionary:
	if _preview_cache["text"] != text:
		_preview_cache = { "text": text, "result": evaluator.evaluate(text) }
	return _preview_cache["result"]


# --- Programmer mode -------------------------------------------------------

func _build_base_rows() -> void:
	var group := ButtonGroup.new()
	for base in BASE_ORDER:
		var button := Button.new()
		button.name = "Base_" + BASE_NAMES[base]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"BaseRowButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(0, 26)
		button.pressed.connect(func():
			feedback.play(Feedback.Kind.KEY)
			_set_base(base))
		base_rows.add_child(button)
		_base_buttons[base] = button


func _programmer_key(id: String) -> void:
	error_key = ""
	var accepted := true
	match id:
		"equals":
			accepted = _evaluate_programmer()
		"clear":
			programmer_editor.clear()
		"back":
			accepted = programmer_editor.backspace()
		"neg":
			accepted = programmer_editor.negate()
		"base":
			_set_base(BASE_ORDER[(BASE_ORDER.find(programmer.base) + 1) % BASE_ORDER.size()])
		_:
			var def: Dictionary = _key_defs["programmer"].get(id, {})
			if def.is_empty():
				return
			var insert: String = def["insert"]
			if insert.length() == 1 and ProgrammerEvaluator.DIGITS.find(insert) >= programmer.base:
				accepted = false # digit not valid in this base
			else:
				accepted = programmer_editor.insert(insert)
	if id != "equals":
		feedback.play(Feedback.Kind.KEY if accepted else Feedback.Kind.ERROR)
	_refresh_display()


func _evaluate_programmer() -> bool:
	if programmer_editor.is_empty() or programmer_editor.just_evaluated:
		return false
	var result := programmer.evaluate(programmer_editor.text)
	if not result["ok"]:
		_show_error(result["error"])
		return false
	programmer_editor.text += ")".repeat(maxi(programmer_editor.open_parens(), 0))
	programmer.last_answer = result["value"]
	programmer_editor.just_evaluated = true
	feedback.play(Feedback.Kind.RESULT)
	return true


## Current programmer value (result, or live value of the expression), null if invalid.
func _programmer_value() -> Variant:
	if programmer_editor.just_evaluated:
		return programmer.last_answer
	if programmer_editor.is_empty():
		return 0
	var result := programmer.evaluate(programmer_editor.text)
	return result["value"] if result["ok"] else null


func _set_base(base: int) -> void:
	var value = _programmer_value()
	var had_input := not programmer_editor.is_empty()
	programmer.base = base
	settings.programmer_base = base
	if value == null or not had_input:
		programmer_editor.clear()
	else:
		# Keep the current value, written in the new base.
		programmer.last_answer = value
		programmer_editor.text = ProgrammerEvaluator.format_int(value, base, false)
		if value < 0 and base == 10:
			programmer_editor.text = "−" + programmer_editor.text.substr(1)
		programmer_editor.just_evaluated = false
	_update_digit_keys()
	_save()
	_refresh_display()


## Digits that don't exist in the current base are disabled; the base key
## shows the current base.
func _update_digit_keys() -> void:
	if not _buttons.has("programmer"):
		return
	for id in _buttons["programmer"]:
		var def: Dictionary = _key_defs["programmer"][id]
		var insert: String = def.get("insert", "")
		if insert.length() == 1 and ProgrammerEvaluator.DIGITS.find(insert) >= 0:
			_buttons["programmer"][id].disabled = ProgrammerEvaluator.DIGITS.find(insert) >= programmer.base
	_buttons["programmer"]["base"].text = BASE_NAMES[programmer.base]


# --- Display ---------------------------------------------------------------

func _refresh_all() -> void:
	DisplayServer.window_set_title(tr("APP_TITLE"))
	_set_second(second_active)
	_refresh_angle()
	_refresh_history()
	_update_digit_keys()
	converter_view.refresh()
	# Pages are rebuilt (in the new language) next time they are shown.
	if side_page in ["settings", "help", "knowledge", "functions"]:
		_ensure_page_built(side_page)
	_refresh_display()


func _refresh_display() -> void:
	memory_label.visible = settings.memory != 0.0 and mode in ["simple", "scientific"]
	result_label.remove_theme_color_override("font_color")
	result_label.visible = true
	result_math.visible = false
	if mode == "converter":
		return
	if mode == "programmer":
		_refresh_programmer_display()
		_fit_result_font()
		return

	expression_view.text = editor.text + ("=" if editor.just_evaluated else "")
	expression_view.show_caret = not editor.just_evaluated and error_key == ""
	expression_view.color = get_theme_color("muted" if editor.just_evaluated else "text", "App")
	if error_key != "":
		result_label.text = tr(error_key)
		result_label.add_theme_color_override("font_color", get_theme_color("error", "App"))
	elif editor.just_evaluated:
		var fraction := Evaluator.to_fraction(evaluator.last_answer) if show_fraction else []
		if not fraction.is_empty():
			result_math.text = ("−" if fraction[0] < 0 else "") + "frac(%d;%d)" % [absi(fraction[0]), fraction[1]]
			result_math.visible = true
			result_label.visible = false
		else:
			result_label.text = _format(evaluator.last_answer, true)
	elif editor.is_empty():
		result_label.text = "0"
		result_label.add_theme_color_override("font_color", get_theme_color("preview", "App"))
	elif editor.text.contains("rand"):
		result_label.text = "" # no live preview for random numbers
	else:
		var preview := _preview(editor.text)
		result_label.text = _format(preview["value"], true) if preview["ok"] else ""
		result_label.add_theme_color_override("font_color", get_theme_color("preview", "App"))
	_fit_result_font()


func _refresh_programmer_display() -> void:
	expression_view.text = programmer_editor.text + ("=" if programmer_editor.just_evaluated else "")
	expression_view.show_caret = not programmer_editor.just_evaluated and error_key == ""
	expression_view.color = get_theme_color("muted" if programmer_editor.just_evaluated else "text", "App")
	var value = _programmer_value()
	if error_key != "":
		result_label.text = tr(error_key)
		result_label.add_theme_color_override("font_color", get_theme_color("error", "App"))
	elif value == null:
		result_label.text = ""
	else:
		result_label.text = ProgrammerEvaluator.format_int(value, programmer.base)
		if not programmer_editor.just_evaluated:
			result_label.add_theme_color_override("font_color", get_theme_color("preview", "App"))
	for base in _base_buttons:
		var button: Button = _base_buttons[base]
		var digits := "—" if value == null else ProgrammerEvaluator.format_int(value, base)
		button.text = "%s   %s" % [BASE_NAMES[base], digits]
		button.set_pressed_no_signal(base == programmer.base)


func _show_error(key: String) -> void:
	editor.just_evaluated = false
	programmer_editor.just_evaluated = false
	error_key = key
	feedback.play(Feedback.Kind.ERROR)
	_shake(display)
	_refresh_display()


func _uses_decimal_comma() -> bool:
	return settings.language != "en"


func _decimal_separator() -> String:
	return "," if _uses_decimal_comma() else "."


func _group_separator() -> String:
	return " " if _uses_decimal_comma() else ","


func _format(value: float, grouped := false) -> String:
	var group := _group_separator() if grouped else ""
	return Evaluator.format_number(value, _decimal_separator(), group, settings.precision).replace("-", "−")


func _apply_language_formats() -> void:
	var list_separator := "; " if _uses_decimal_comma() else ", "
	for view in [expression_view, result_math]:
		view.decimal_separator = _decimal_separator()
		view.list_separator = list_separator
	converter_view.decimal_separator = _decimal_separator()
	converter_view.group_separator = _group_separator()
	converter_view.precision = settings.precision
	knowledge_list.language = settings.language
	knowledge_list.decimal_separator = _decimal_separator()
	knowledge_list.group_separator = _group_separator()
	knowledge_list.list_separator = list_separator


func _fit_result_font() -> void:
	var font := result_label.get_theme_font("font")
	var available := result_label.size.x
	if available <= 0.0:
		return
	var largest := RESULT_FONT_MAX if layout != "landscape" else RESULT_FONT_MAX + 12
	# Binary search on the font size (the text width grows with the size).
	var low := RESULT_FONT_MIN
	var high := largest
	while low < high:
		var middle := (low + high + 1) / 2
		if font.get_string_size(result_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, middle).x <= available:
			low = middle
		else:
			high = middle - 1
	result_label.add_theme_font_size_override("font_size", low)


## Tap on the display: copy / copy as LaTeX / paste menu.
func _on_display_input(event: InputEvent) -> void:
	if mode not in ["simple", "scientific"]:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var has_value := editor.just_evaluated or not editor.is_empty()
		display_menu.set_item_disabled(display_menu.get_item_index(DisplayAction.COPY), not has_value)
		display_menu.set_item_disabled(display_menu.get_item_index(DisplayAction.COPY_LATEX), editor.is_empty())
		display_menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i(220, 0)))
		accept_event()


func _on_display_menu(id: int) -> void:
	match id:
		DisplayAction.COPY:
			_copy_result()
		DisplayAction.COPY_LATEX:
			_copy_latex()
		DisplayAction.PASTE:
			if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
				_paste(DisplayServer.clipboard_get())


# --- Animations ------------------------------------------------------------

func _animate_press(button: Button, down: bool) -> void:
	var tween := button.create_tween()
	if down:
		tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	else:
		tween.tween_property(button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Visual feedback when a key is triggered from the keyboard.
func _flash(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	button.scale = Vector2(0.95, 0.95)
	button.modulate = Color(1.3, 1.3, 1.3)
	var tween := button.create_tween().set_parallel()
	tween.tween_property(button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color.WHITE, 0.18)


func _shake(control: Control) -> void:
	if _shake_tween and _shake_tween.is_running():
		return
	var origin := control.position.x
	_shake_tween = create_tween()
	for offset in [-6.0, 5.0, -3.0, 2.0, 0.0]:
		_shake_tween.tween_property(control, "position:x", origin + offset, 0.04)


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.4)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


# --- Layout & side sheet ---------------------------------------------------

func _on_viewport_resized() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > viewport_size.y * LANDSCAPE_RATIO:
		layout = "landscape"
	elif viewport_size.x >= WIDE_LAYOUT_WIDTH:
		layout = "wide"
	else:
		layout = "portrait"
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
	var open_page := side_page
	if open_page in ["knowledge", "help", "tests"] and page == "settings":
		open_page = "settings" # the menu button closes settings sub-pages too
	if open_page == page and not (layout == "wide" and page == "history"):
		_close_page()
	else:
		_open_page(page)


func _open_page(page: String) -> void:
	var was_visible := side_panel.visible
	side_page = page
	_ensure_page_built(page)
	_update_layout()
	if not was_visible or layout != "wide":
		side_panel.modulate.a = 0.0
		create_tween().tween_property(side_panel, "modulate:a", 1.0, 0.15)


func _close_page() -> void:
	side_page = ""
	_update_layout()


## Moves the keypad and the sheet between containers for each layout.
func _place(node: Control, parent: Control, index: int) -> void:
	if node.get_parent() != parent:
		node.reparent(parent, false)
	parent.move_child(node, mini(index, parent.get_child_count() - 1))


func _update_layout() -> void:
	var page := side_page
	if layout == "wide" and page == "":
		page = "history" # docked history on wide screens
	if layout == "landscape":
		_place(keypads, content, 1)
		_place(side_panel, left_column, 2)
		keypads.size_flags_stretch_ratio = 1.15
		body.visible = false
	else:
		_place(keypads, body, 0)
		_place(side_panel, body, 1)
		keypads.size_flags_stretch_ratio = 1.5
		body.visible = true
	side_panel.visible = page != ""
	keypads.visible = layout != "portrait" or page == ""
	# The display takes the free height when nothing else needs it.
	var display_expands := layout == "landscape" and page == ""
	display.size_flags_vertical = Control.SIZE_EXPAND_FILL if display_expands else Control.SIZE_FILL
	converter_view.size_flags_vertical = display.size_flags_vertical
	display_spacer.visible = display_expands
	expression_view.font_size_max = 34 if layout == "landscape" else 26
	expression_view.queue_redraw()
	for view in [history_view, functions_view, settings_view, knowledge_view, help_view, tests_view]:
		view.visible = view.name.to_lower().begins_with(page) and page != ""
	history_view.get_node("Header/CloseButton").visible = layout != "wide"
	history_button.set_pressed_no_signal(page == "history")
	menu_button.set_pressed_no_signal(page in ["settings", "knowledge", "help", "tests"])


func _ensure_page_built(page: String) -> void:
	var locale := TranslationServer.get_locale()
	if _built_pages.get(page, "") == locale:
		return
	_built_pages[page] = locale
	match page:
		"settings":
			_build_settings_page()
		"functions":
			_build_functions_page()
		"help":
			_build_help_page()
		"knowledge":
			knowledge_list.language = settings.language
			knowledge_list.ensure_built()


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- Functions page (f(x)) -------------------------------------------------

func _build_functions_page() -> void:
	_clear_children(functions_list)
	for category in Keypads.FUNCTION_CATALOG:
		var label := Label.new()
		label.theme_type_variation = &"SectionLabel"
		label.text = category[0]
		functions_list.add_child(label)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		functions_list.add_child(grid)
		for entry in category[1]:
			var button := Button.new()
			button.text = entry[0]
			button.focus_mode = Control.FOCUS_NONE
			button.theme_type_variation = &"ChipButton"
			button.custom_minimum_size = Vector2(0, 40)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.pressed.connect(_on_function_chosen.bind(entry[1]))
			grid.add_child(button)


func _on_function_chosen(insert: String) -> void:
	if insert.begins_with("@"):
		_calculator_key(insert.substr(1)) # memory, ±
	else:
		_insert_text(insert)
	if layout == "portrait":
		_close_page()


## A value tapped on the knowledge page goes into the calculator.
func _on_knowledge_value(insert: String) -> void:
	if mode not in ["simple", "scientific"]:
		_set_mode("scientific")
	# After a number or ")", multiply instead of gluing digits together.
	if not editor.just_evaluated and editor.text != "":
		var last := editor.text[editor.text.length() - 1]
		if last.is_valid_int() or last in [")", "π", "e", "φ", "s", "!", "%"]:
			editor.insert("×")
	_insert_text(insert)
	_show_message(tr("INSERTED"))
	if layout != "wide":
		_close_page()


# --- Settings page ---------------------------------------------------------

func _section(title: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"SectionLabel"
	label.text = title
	if settings_list.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		settings_list.add_child(spacer)
	settings_list.add_child(label)


func _segmented(setting: String, options: Array, selected: int) -> void:
	var group := ButtonGroup.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	settings_list.add_child(row)
	var buttons := []
	for i in options.size():
		var button := Button.new()
		button.text = options[i]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == selected
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"SegmentButton"
		button.custom_minimum_size = Vector2(0, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_setting_chosen.bind(setting, i))
		row.add_child(button)
		buttons.append(button)
	_setting_controls[setting] = buttons


func _switch(setting: String, text: String, on: bool, enabled := true) -> void:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.disabled = not enabled
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(value: bool): _on_setting_chosen(setting, 0 if value else 1))
	settings_list.add_child(check)
	_setting_controls[setting] = check


func _list_button(text: String, page: String) -> void:
	var button := Button.new()
	button.text = text
	button.name = page.capitalize() + "Row"
	button.icon = CHEVRON_RIGHT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"ListButton"
	button.pressed.connect(func():
		feedback.play(Feedback.Kind.KEY)
		_open_page(page))
	settings_list.add_child(button)


func _build_settings_page() -> void:
	_clear_children(settings_list)
	_setting_controls.clear()
	_section("SECTION_APPEARANCE")
	_segmented("theme", ["THEME_AUTO", "THEME_LIGHT", "THEME_DARK"],
		[0, 2, 1][settings.theme_mode])

	_section("LANGUAGE")
	var languages := OptionButton.new()
	languages.name = "LanguageOption"
	languages.focus_mode = Control.FOCUS_NONE
	languages.custom_minimum_size = Vector2(0, 40)
	languages.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for code in Settings.LANGUAGES:
		languages.add_item(LANGUAGE_NAMES[code])
	languages.select(Settings.LANGUAGES.find(settings.language))
	languages.item_selected.connect(func(index): _on_setting_chosen("language", index))
	settings_list.add_child(languages)
	_setting_controls["language"] = languages

	_section("SECTION_CALCULATION")
	_segmented("angle", ["DEGREES", "RADIANS"], evaluator.angle_mode)
	_section("PRECISION")
	_segmented("precision", ["PREC_AUTO", "2", "4", "6", "8"], Settings.PRECISIONS.find(settings.precision))

	_section("SECTION_FEEDBACK")
	_switch("sound", "SOUND", settings.sound)
	var mobile := Feedback.can_vibrate()
	_switch("vibration", "VIBRATION" if mobile else "VIBRATION_MOBILE_ONLY", settings.vibration, mobile)

	_section("SECTION_MORE")
	_list_button("KNOWLEDGE", "knowledge")
	_list_button("HELP", "help")
	_list_button("SELF_TEST", "tests")

	var about := Label.new()
	about.name = "AboutLabel"
	about.theme_type_variation = &"MutedLabel"
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	about.text = tr("ABOUT_TEXT") % [ProjectSettings.get_setting("application/config/version", "?"),
		Engine.get_version_info()["string"]]
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	settings_list.add_child(spacer)
	settings_list.add_child(about)


## Keeps the settings controls in sync when a setting changes elsewhere.
func _sync_settings_page() -> void:
	if not _setting_controls.has("theme"):
		return
	var selected := {
		"theme": [0, 2, 1][settings.theme_mode],
		"angle": evaluator.angle_mode,
		"precision": Settings.PRECISIONS.find(settings.precision),
	}
	for setting in selected:
		var buttons: Array = _setting_controls[setting]
		for i in buttons.size():
			buttons[i].set_pressed_no_signal(i == selected[setting])
	_setting_controls["sound"].set_pressed_no_signal(settings.sound)
	_setting_controls["vibration"].set_pressed_no_signal(settings.vibration)


func _on_setting_chosen(setting: String, index: int) -> void:
	feedback.play(Feedback.Kind.KEY)
	match setting:
		"theme":
			_set_theme_mode([Settings.ThemeMode.AUTO, Settings.ThemeMode.LIGHT, Settings.ThemeMode.DARK][index])
		"language":
			_set_language(Settings.LANGUAGES[index])
		"angle":
			_set_angle_mode(index)
		"precision":
			_set_precision(index)
		"sound":
			settings.sound = index == 0
			_apply_feedback_settings()
			_save()
		"vibration":
			settings.vibration = index == 0
			_apply_feedback_settings()
			_save()


func _toggle_angle_mode() -> void:
	_set_angle_mode(1 - evaluator.angle_mode)
	feedback.play(Feedback.Kind.KEY)


func _set_angle_mode(angle: int) -> void:
	evaluator.angle_mode = angle as Evaluator.AngleMode
	settings.angle_mode = angle
	_preview_cache["text"] = null
	_refresh_angle()
	_sync_settings_page()
	_refresh_display()
	_save()


func _refresh_angle() -> void:
	angle_button.text = "DEG" if evaluator.angle_mode == Evaluator.AngleMode.DEG else "RAD"


func _toggle_theme() -> void:
	_set_theme_mode(Settings.ThemeMode.LIGHT if _is_dark() else Settings.ThemeMode.DARK)


func _set_theme_mode(theme_mode: int) -> void:
	settings.theme_mode = theme_mode as Settings.ThemeMode
	_apply_theme()
	_sync_settings_page()
	_save()


func _is_dark() -> bool:
	match settings.theme_mode:
		Settings.ThemeMode.DARK:
			return true
		Settings.ThemeMode.LIGHT:
			return false
	return DisplayServer.is_dark_mode() if DisplayServer.is_dark_mode_supported() else true


func _apply_theme() -> void:
	theme = DARK_THEME if _is_dark() else LIGHT_THEME
	RenderingServer.set_default_clear_color(get_theme_color("bg", "App"))
	for view in [expression_view, result_math]:
		view.color = get_theme_color("text", "App")
		view.muted_color = get_theme_color("muted", "App")
		view.accent_color = get_theme_color("accent", "App")
	knowledge_list.apply_colors(get_theme_color("text", "App"), get_theme_color("muted", "App"),
		get_theme_color("accent", "App"))
	_refresh_display()


func _set_language(language: String) -> void:
	settings.language = language
	_apply_language_formats()
	TranslationServer.set_locale(language)
	_save()


func _set_precision(index: int) -> void:
	settings.precision = Settings.PRECISIONS[index]
	converter_view.precision = settings.precision
	converter_view.refresh()
	_refresh_history()
	_sync_settings_page()
	_refresh_display()
	_save()


func _apply_feedback_settings() -> void:
	feedback.sound_enabled = settings.sound
	feedback.vibration_enabled = settings.vibration


# --- Help page -------------------------------------------------------------

func _build_help_page() -> void:
	_clear_children(help_list)
	for topic in HELP_TOPICS:
		var title := Label.new()
		title.theme_type_variation = &"TitleLabel"
		title.text = "HELP_%s_T" % topic
		help_list.add_child(title)
		var text := Label.new()
		text.theme_type_variation = &"MutedLabel"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = "HELP_" + topic
		help_list.add_child(text)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		help_list.add_child(spacer)
	var keyboard := Label.new()
	keyboard.theme_type_variation = &"TitleLabel"
	keyboard.text = "HELP_KEYBOARD_T"
	help_list.add_child(keyboard)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	help_list.add_child(grid)
	for shortcut in SHORTCUTS:
		var keys := Label.new()
		keys.text = shortcut[0]
		keys.theme_type_variation = &"StatusLabel"
		keys.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		keys.custom_minimum_size = Vector2(120, 0)
		keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(keys)
		var description := Label.new()
		description.text = shortcut[1]
		description.theme_type_variation = &"MutedLabel"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(description)


# --- History ---------------------------------------------------------------

func _history_text(entry: Dictionary) -> String:
	return "%s = %s" % [_linear(entry["expr"]), _format(entry["value"], true)]


## One-line form of an expression for lists ("3⁄4 + ³√27").
func _linear(text: String) -> String:
	var separator := "; " if _uses_decimal_comma() else ", "
	return math_format.to_linear(text, separator).replace(".", _decimal_separator())


func _refresh_history() -> void:
	history_list.clear()
	for entry in settings.history:
		var index := history_list.add_item(_history_text(entry))
		history_list.set_item_tooltip(index, _linear(entry["expr"]))
	_update_history_state()


## Adds the newest entry at the top without rebuilding the whole list.
func _add_history_item(entry: Dictionary) -> void:
	var index := history_list.add_item(_history_text(entry))
	history_list.set_item_tooltip(index, _linear(entry["expr"]))
	history_list.move_item(index, 0)
	while history_list.item_count > MAX_HISTORY:
		history_list.remove_item(history_list.item_count - 1)
	_update_history_state()


func _update_history_state() -> void:
	history_empty.visible = settings.history.is_empty()
	history_list.visible = not settings.history.is_empty()
	clear_history_button.visible = not settings.history.is_empty()


func _on_history_item_clicked(index: int, _at: Vector2, _mouse_button: int) -> void:
	var entry: Dictionary = settings.history[index]
	if mode not in ["simple", "scientific"]:
		_set_mode("scientific")
	editor.text = entry["expr"]
	editor.just_evaluated = true
	evaluator.last_answer = entry["value"]
	error_key = ""
	show_fraction = false
	feedback.play(Feedback.Kind.KEY)
	if layout != "wide":
		_close_page()
	_refresh_display()


func _clear_history() -> void:
	settings.history.clear()
	_refresh_history()
	feedback.play(Feedback.Kind.KEY)
	_save()


# --- On-screen tests -------------------------------------------------------

func _run_self_test() -> void:
	var started := Time.get_ticks_usec()
	var suite = SelfTest.new().run()
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
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
	lines.append("[color=#%s]%.1f ms[/color]" % [muted, elapsed_ms])
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
		"Window: %dx%d · viewport %dx%d · %s" % [
			DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
			get_viewport_rect().size.x, get_viewport_rect().size.y, layout],
		"Locale: %s · Renderer: %s" % [OS.get_locale(), ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")],
		"GPU: %s" % RenderingServer.get_video_adapter_name(),
		"Dark mode: %s · Vibration: %s" % [
			str(DisplayServer.is_dark_mode()) if DisplayServer.is_dark_mode_supported() else "n/a",
			"yes" if Feedback.can_vibrate() else "no"],
		"Startup: %d ms · Memory: %.1f MB · FPS: %d" % [_startup_ms, OS.get_static_memory_usage() / 1048576.0, Engine.get_frames_per_second()],
		"Godot %s" % Engine.get_version_info()["string"],
	])


# --- Persistence -----------------------------------------------------------

## Saves after a short delay so that fast typing doesn't hit the disk each time.
func _save() -> void:
	if _save_timer and _save_timer.is_inside_tree():
		_save_timer.start()


func _flush_save() -> void:
	if _save_timer:
		_save_timer.stop()
	settings.angle_mode = evaluator.angle_mode
	settings.last_answer = evaluator.last_answer
	settings.converter = converter_view.get_state()
	settings.save()


# --- Keyboard & numeric keypad ---------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event := event as InputEventKey
	var action := _action_for_event(key_event)
	if action == "":
		return
	get_viewport().set_input_as_handled()
	if key_event.echo and action != "key:back":
		return
	match action:
		"copy":
			_copy_result()
		"copy_latex":
			_copy_latex()
		"paste":
			if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
				_paste(DisplayServer.clipboard_get())
		"angle":
			if mode == "scientific":
				_toggle_angle_mode()
		"history", "knowledge", "settings":
			_toggle_page(action)
		"language":
			var index := Settings.LANGUAGES.find(settings.language)
			_set_language(Settings.LANGUAGES[(index + 1) % Settings.LANGUAGES.size()])
		"theme":
			_toggle_theme()
		"mode":
			_cycle_mode()
		_:
			if action.begins_with("mode:"):
				_set_mode(action.substr(5))
			elif action.begins_with("key:"):
				var id := action.substr(4)
				if _buttons[mode].has(id):
					_flash(_buttons[mode][id])
				_on_key_pressed(id)
			elif mode == "programmer" and action not in PROGRAMMER_INSERTS:
				feedback.play(Feedback.Kind.ERROR)
			elif mode != "converter":
				_flash_insert(action)
				_insert_text(action)


func _flash_insert(insert: String) -> void:
	for id in _key_defs[mode]:
		if _key_defs[mode][id].get("insert", "") == insert:
			_flash(_buttons[mode][id])
			return


func _action_for_event(event: InputEventKey) -> String:
	var keycode := event.keycode
	if event.ctrl_pressed or event.meta_pressed:
		match keycode:
			KEY_C:
				return "copy_latex" if event.shift_pressed else "copy"
			KEY_V:
				return "paste"
			KEY_1, KEY_2, KEY_3, KEY_4:
				return "mode:" + Keypads.MODES[keycode - KEY_1]
		return ""
	# Physical key first: the numeric keypad always types digits, even with
	# NumLock off (where it would otherwise send Home, arrows, End...).
	if KEYPAD_SHORTCUTS.has(event.physical_keycode):
		return "key:" + KEYPAD_SHORTCUTS[event.physical_keycode]
	if KEYPAD_SHORTCUTS.has(keycode):
		return "key:" + KEYPAD_SHORTCUTS[keycode]
	match keycode:
		KEY_ENTER:
			return "key:copy" if mode == "converter" else "key:equals"
		KEY_BACKSPACE:
			return "key:back"
		KEY_ESCAPE, KEY_DELETE:
			return "key:clear"
		KEY_RIGHT:
			return "key:next"
		KEY_F2:
			return "angle"
		KEY_F3:
			return "language"
		KEY_F4:
			return "settings"
		KEY_F6:
			return "theme"
		KEY_F7:
			return "mode"
		KEY_F8:
			return "knowledge"
		KEY_TAB:
			return "key:second"
	if event.unicode == 0:
		return ""
	var character := String.chr(event.unicode)
	if character.is_valid_int():
		return "key:" + character
	if mode == "programmer" and programmer.base == 16 and character.to_upper() in ["A", "B", "C", "D", "E", "F"]:
		return "key:" + character.to_upper()
	if mode == "converter":
		match character:
			"-":
				return "key:neg"
			".", ",":
				return "key:dot"
		return ""
	return CHAR_ACTIONS.get(character.to_lower(), "")


func _copy_result() -> void:
	var text := ""
	match mode:
		"converter":
			text = converter_view.result_text(false)
		"programmer":
			var value = _programmer_value()
			if value != null and error_key == "":
				text = ProgrammerEvaluator.format_int(value, programmer.base, false)
		_:
			if editor.just_evaluated:
				text = Evaluator.format_number(evaluator.last_answer, _decimal_separator(), "", settings.precision)
			elif not editor.is_empty() and error_key == "":
				var preview := _preview(editor.text)
				if preview["ok"]:
					text = Evaluator.format_number(preview["value"], _decimal_separator(), "", settings.precision)
	if text == "":
		feedback.play(Feedback.Kind.ERROR)
		return
	_set_clipboard(text.replace("−", "-"))
	_show_message(tr("COPIED"))


## Copies the expression (and its result) as LaTeX.
func _copy_latex() -> void:
	if editor.is_empty() or mode not in ["simple", "scientific"]:
		feedback.play(Feedback.Kind.ERROR)
		return
	var latex := math_format.to_latex(editor.text)
	if editor.just_evaluated:
		var fraction := Evaluator.to_fraction(evaluator.last_answer) if show_fraction else []
		var result := ""
		if fraction.is_empty():
			result = Evaluator.format_number(evaluator.last_answer, ".", "", settings.precision)
			if result.contains("E"):
				var parts := result.split("E")
				result = parts[0] + " \\times 10^{" + parts[1] + "}"
		else:
			result = ("-" if fraction[0] < 0 else "") + "\\frac{%d}{%d}" % [absi(fraction[0]), fraction[1]]
		latex += " = " + result
	_set_clipboard(latex)
	feedback.play(Feedback.Kind.KEY)
	_show_message(tr("LATEX_COPIED"))


func _set_clipboard(text: String) -> void:
	_last_copied = text
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)


## Pastes a number, an expression or LaTeX (\frac{1}{2}, \sqrt{2}...).
func _paste(text: String) -> void:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return
	if mode == "programmer" or mode == "converter":
		feedback.play(Feedback.Kind.ERROR)
		return
	if cleaned.contains("\\") or cleaned.contains("{") or cleaned.begins_with("$"):
		cleaned = math_format.latex_to_expression(cleaned)
	cleaned = cleaned.replace(" ", "").replace(" ", "").replace(" ", "")
	if cleaned == "" or not evaluator.evaluate(cleaned)["ok"]:
		_show_error("ERR_SYNTAX")
		return
	cleaned = cleaned.replace(",", ".").replace("-", "−").replace("*", "×").replace("/", "÷")
	if editor.just_evaluated:
		editor.clear()
	editor.text += cleaned
	error_key = ""
	_show_message(tr("PASTED"))
	_refresh_display()
