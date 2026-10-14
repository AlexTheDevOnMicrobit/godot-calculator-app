extends Control
## Main calculator screen: builds the keypad, handles mouse/touch, keyboard
## and numeric keypad input, history, memory, language and settings.

const Evaluator := preload("res://scripts/evaluator.gd")

const SETTINGS_PATH := "user://settings.cfg"
const MAX_HISTORY := 50
const RESULT_FONT_MAX := 44
const RESULT_FONT_MIN := 18

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
	{ "id": "back", "label": "⌫", "style": "ClearButton", "tip": "TIP_BACKSPACE" },
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

## Insertions that continue the previous result (prefixed with "Ans").
const CONTINUATION_INSERTS := ["+", "−", "×", "÷", "^", "^2", "^3", "^(−1)", "!", "%", "mod"]

## Multi-character tokens removed in one go by backspace (longest first).
const BACKSPACE_TOKENS := [
	"asin(", "acos(", "atan(", "sin(", "cos(", "tan(", "log(", "abs(",
	"ln(", "rand", "Ans", "mod", "^(−1)", "√(", "∛(", "e^(", "10^(",
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
	"p": "pi", "e": "e", "a": "ans",
}

## Numeric keypad keycodes -> key id (works with or without unicode).
const KEYPAD_SHORTCUTS := {
	KEY_KP_0: "0", KEY_KP_1: "1", KEY_KP_2: "2", KEY_KP_3: "3", KEY_KP_4: "4",
	KEY_KP_5: "5", KEY_KP_6: "6", KEY_KP_7: "7", KEY_KP_8: "8", KEY_KP_9: "9",
	KEY_KP_PERIOD: "dot", KEY_KP_ADD: "add", KEY_KP_SUBTRACT: "sub",
	KEY_KP_MULTIPLY: "mul", KEY_KP_DIVIDE: "div", KEY_KP_ENTER: "equals",
}

var evaluator := Evaluator.new()
var expression := ""
var just_evaluated := false
var error_key := "" # translation key of the error currently displayed
var second_active := false
var memory := 0.0
var history: Array = [] # Array of { "expr": String, "value": float }
var language := "en"
var settings_path := SETTINGS_PATH

var _buttons := {} # id -> Button
var _key_defs := {} # id -> Dictionary
var _message_tween: Tween

@onready var title_label: Label = %Title
@onready var angle_button: Button = %AngleButton
@onready var history_button: Button = %HistoryButton
@onready var language_button: Button = %LanguageButton
@onready var angle_label: Label = %AngleLabel
@onready var second_label: Label = %SecondLabel
@onready var memory_label: Label = %MemoryLabel
@onready var message_label: Label = %MessageLabel
@onready var expression_label: Label = %ExpressionLabel
@onready var result_label: Label = %ResultLabel
@onready var keypad: GridContainer = %Keypad
@onready var history_panel: PanelContainer = %HistoryPanel
@onready var history_list: ItemList = %HistoryList
@onready var history_empty: Label = %HistoryEmpty
@onready var clear_history_button: Button = %ClearHistoryButton


func _ready() -> void:
	randomize()
	_load_settings()
	_build_keypad()

	angle_button.pressed.connect(_toggle_angle_mode)
	history_button.toggled.connect(_set_history_visible)
	language_button.pressed.connect(_toggle_language)
	history_list.item_clicked.connect(_on_history_item_clicked)
	clear_history_button.pressed.connect(_clear_history)
	result_label.resized.connect(_fit_result_font)

	DisplayServer.window_set_min_size(Vector2i(340, 560))
	TranslationServer.set_locale(language)
	_refresh_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_all()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()


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
		button.custom_minimum_size = Vector2(52, 44)
		button.tooltip_text = def.get("tip", "")
		if def["id"] == "second":
			button.toggle_mode = true
		button.pressed.connect(_on_key_pressed.bind(def["id"]))
		keypad.add_child(button)
		_buttons[def["id"]] = button
		_key_defs[def["id"]] = def


func _on_key_pressed(id: String) -> void:
	var def: Dictionary = _key_defs[id]
	if id != "second":
		error_key = ""
	match id:
		"second":
			_set_second(not second_active)
			return
		"equals":
			_evaluate()
		"clear":
			_clear()
		"back":
			_backspace()
		"mc":
			memory = 0.0
			_save_settings()
		"mr":
			_insert(_number_for_insert(memory))
		"mplus", "mminus":
			var value = _current_value()
			if value != null:
				memory += value if id == "mplus" else -value
				_save_settings()
		_:
			var text: String = def.get("insert2", def["insert"]) if second_active else def["insert"]
			_insert(text)
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


# --- Expression editing ----------------------------------------------------

func _insert(text: String) -> void:
	if just_evaluated:
		just_evaluated = false
		if text in CONTINUATION_INSERTS:
			expression = "Ans"
		else:
			expression = ""
	expression += text


func _backspace() -> void:
	if just_evaluated:
		just_evaluated = false
		return
	for token in BACKSPACE_TOKENS:
		if expression.ends_with(token):
			expression = expression.left(expression.length() - token.length())
			return
	expression = expression.left(expression.length() - 1)


func _clear() -> void:
	expression = ""
	just_evaluated = false


func _evaluate() -> void:
	if expression.strip_edges() == "":
		return
	var result := evaluator.evaluate(expression)
	if not result["ok"]:
		_show_error(result["error"])
		return
	evaluator.last_answer = result["value"]
	history.push_front({ "expr": expression, "value": result["value"] })
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	just_evaluated = true
	_save_settings()
	_refresh_history()


## Value of the current expression (or last result), null if invalid.
func _current_value() -> Variant:
	if just_evaluated or expression == "":
		return evaluator.last_answer
	var result := evaluator.evaluate(expression)
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
	_refresh_display()


func _refresh_display() -> void:
	expression_label.text = _pretty(expression) if not just_evaluated else _pretty(expression) + " ="
	result_label.remove_theme_color_override("font_color")
	if error_key != "":
		result_label.text = tr(error_key)
		result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	elif just_evaluated:
		result_label.text = _format(evaluator.last_answer)
	elif expression == "":
		result_label.text = "0"
	else:
		# Live preview while typing
		var preview := evaluator.evaluate(expression)
		result_label.text = _format(preview["value"]) if preview["ok"] else ""
		result_label.add_theme_color_override("font_color", Color(0.6, 0.64, 0.72))
	memory_label.visible = memory != 0.0
	_fit_result_font()


func _show_error(key: String) -> void:
	just_evaluated = false
	error_key = key
	_refresh_display()


func _pretty(text: String) -> String:
	var pretty := text
	for pair in [["asin(", "sin⁻¹("], ["acos(", "cos⁻¹("], ["atan(", "tan⁻¹("], ["mod", " mod "], ["abs(", "|x|("]]:
		pretty = pretty.replace(pair[0], pair[1])
	return pretty.replace(".", _decimal_separator())


func _format(value: float) -> String:
	return Evaluator.format_number(value, _decimal_separator()).replace("-", "−")


func _decimal_separator() -> String:
	return "," if language == "fr" else "."


func _fit_result_font() -> void:
	var font := result_label.get_theme_font("font")
	var available := result_label.size.x
	if available <= 0.0:
		return
	var font_size := RESULT_FONT_MAX
	while font_size > RESULT_FONT_MIN and font.get_string_size(result_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 2
	result_label.add_theme_font_size_override("font_size", font_size)


func _flash(button: Button) -> void:
	button.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(button, "modulate", Color.WHITE, 0.18)


func _show_message(key: String) -> void:
	message_label.text = tr(key)
	message_label.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.0)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


# --- Settings: angle, language, history ------------------------------------

func _toggle_angle_mode() -> void:
	evaluator.angle_mode = Evaluator.AngleMode.RAD if evaluator.angle_mode == Evaluator.AngleMode.DEG else Evaluator.AngleMode.DEG
	_refresh_angle()
	_refresh_display()
	_save_settings()


func _refresh_angle() -> void:
	var key := "ANGLE_DEG" if evaluator.angle_mode == Evaluator.AngleMode.DEG else "ANGLE_RAD"
	angle_button.text = key
	angle_label.text = tr(key)


func _toggle_language() -> void:
	language = "en" if language == "fr" else "fr"
	TranslationServer.set_locale(language)
	_save_settings()


func _set_history_visible(visible_: bool) -> void:
	history_panel.visible = visible_
	keypad.visible = not visible_
	history_button.set_pressed_no_signal(visible_)


func _refresh_history() -> void:
	history_list.clear()
	for entry in history:
		history_list.add_item("%s = %s" % [_pretty(entry["expr"]), _format(entry["value"])])
	history_empty.visible = history.is_empty()
	clear_history_button.disabled = history.is_empty()


func _on_history_item_clicked(index: int, _at: Vector2, _button: int) -> void:
	var entry: Dictionary = history[index]
	expression = entry["expr"]
	evaluator.last_answer = entry["value"]
	just_evaluated = true
	_set_history_visible(false)
	_refresh_display()


func _clear_history() -> void:
	history.clear()
	_refresh_history()
	_save_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	var os_language := "fr" if OS.get_locale_language() == "fr" else "en"
	if config.load(settings_path) != OK:
		language = os_language
		return
	language = config.get_value("app", "language", os_language)
	evaluator.angle_mode = config.get_value("app", "angle_mode", Evaluator.AngleMode.DEG)
	memory = config.get_value("app", "memory", 0.0)
	evaluator.last_answer = config.get_value("app", "last_answer", 0.0)
	history = config.get_value("app", "history", [])


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("app", "language", language)
	config.set_value("app", "angle_mode", evaluator.angle_mode)
	config.set_value("app", "memory", memory)
	config.set_value("app", "last_answer", evaluator.last_answer)
	config.set_value("app", "history", history)
	config.save(settings_path)


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
			DisplayServer.clipboard_set(result_label.text.replace("−", "-"))
			_show_message("COPIED")
		"paste":
			_paste(DisplayServer.clipboard_get())
		"angle":
			_toggle_angle_mode()
		"history":
			_set_history_visible(not history_panel.visible)
		"language":
			_toggle_language()
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
		KEY_TAB:
			return "second"
	if event.unicode == 0:
		return ""
	var character := String.chr(event.unicode).to_lower()
	if character == "h":
		return "history"
	return CHAR_SHORTCUTS.get(character, "")


func _paste(text: String) -> void:
	var cleaned := text.strip_edges().replace(" ", "")
	if cleaned == "":
		return
	if not evaluator.evaluate(cleaned)["ok"]:
		_show_error("ERR_SYNTAX")
		return
	_insert(cleaned.replace("-", "−").replace("*", "×").replace("/", "÷"))
	_show_message("PASTED")
	_refresh_display()
