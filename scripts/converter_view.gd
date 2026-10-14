extends VBoxContainer
## Converter mode display: category, "from" unit and value typed on the
## keypad, "to" unit and the converted value (updated live).

signal changed

const Units := preload("res://scripts/units.gd")
const Evaluator := preload("res://scripts/evaluator.gd")

const MAX_DIGITS := 15

var category := "length"
var from_unit := 2
var to_unit := 3
var value_text := "1"
var decimal_separator := "."
var group_separator := ","
var precision := -1

var _category_option: OptionButton
var _from_option: OptionButton
var _to_option: OptionButton
var _from_value: Label
var _to_value: Label


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_category_option = _option("OptionButton")
	_category_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_category_option.custom_minimum_size = Vector2(180, 38)
	_category_option.item_selected.connect(_on_category_selected)
	add_child(_category_option)
	_spacer(10)

	_from_option = _option("FlatOptionButton")
	_from_option.item_selected.connect(func(index):
		from_unit = index
		_refresh_values())
	_from_value = _value_label()
	add_child(_from_option)
	add_child(_from_value)
	_spacer(8)

	_to_option = _option("FlatOptionButton")
	_to_option.item_selected.connect(func(index):
		to_unit = index
		_refresh_values())
	_to_value = _value_label()
	_to_value.theme_type_variation = &"ResultLabel"
	add_child(_to_option)
	add_child(_to_value)
	refresh()


func _option(variation: String) -> OptionButton:
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.theme_type_variation = variation
	option.custom_minimum_size = Vector2(0, 34)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	option.fit_to_longest_item = false
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return option


func _spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	add_child(spacer)


func _value_label() -> Label:
	var label := Label.new()
	label.theme_type_variation = &"ValueLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.clip_text = true
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return label


## Rebuilds the option lists (after a language or category change).
func refresh() -> void:
	if _category_option == null:
		return
	_category_option.clear()
	var ids := Units.category_ids()
	for id in ids:
		_category_option.add_item(tr(Units.category_name_key(id)))
	_category_option.select(ids.find(category))
	for option in [_from_option, _to_option]:
		option.clear()
		for i in Units.unit_count(category):
			option.add_item("%s  ·  %s" % [Units.unit_symbol(category, i), tr(Units.unit_name_key(category, i))])
	from_unit = clampi(from_unit, 0, Units.unit_count(category) - 1)
	to_unit = clampi(to_unit, 0, Units.unit_count(category) - 1)
	_from_option.select(from_unit)
	_to_option.select(to_unit)
	_refresh_values()


func _on_category_selected(index: int) -> void:
	category = Units.category_ids()[index]
	from_unit = Units.DEFAULTS[category][0]
	to_unit = Units.DEFAULTS[category][1]
	refresh()


func value() -> float:
	var text := value_text.replace("−", "-")
	return text.to_float() if text.is_valid_float() else 0.0


func result() -> float:
	return Units.convert(category, value(), from_unit, to_unit)


func result_text(grouped := true) -> String:
	var out := Evaluator.format_number(result(), decimal_separator, group_separator if grouped else "", precision)
	return out.replace("-", "−")


func _refresh_values() -> void:
	if _from_value == null:
		return
	var shown := value_text.replace(".", decimal_separator)
	_from_value.text = shown + " " + Units.unit_symbol(category, from_unit)
	_to_value.text = result_text() + " " + Units.unit_symbol(category, to_unit)
	changed.emit()


## Handles a converter keypad key. Returns false if the key was rejected.
func press(id: String) -> bool:
	var accepted := true
	match id:
		"back":
			value_text = value_text.left(value_text.length() - 1)
			if value_text in ["", "−"]:
				value_text = "0"
		"clear":
			value_text = "0"
		"neg":
			value_text = value_text.substr(1) if value_text.begins_with("−") else "−" + value_text
			if value_text == "−0":
				value_text = "0"
		"dot":
			accepted = not value_text.contains(".")
			if accepted:
				value_text += "."
		"swap":
			# The converted value becomes the new input, in the swapped unit.
			var converted := Evaluator.format_number(result(), ".")
			if not converted.contains("E") and converted != "—":
				value_text = converted.replace("-", "−")
			var previous := to_unit
			to_unit = from_unit
			from_unit = previous
			_from_option.select(from_unit)
			_to_option.select(to_unit)
		_:
			if id.length() == 1 and id.is_valid_int():
				var digits := value_text.replace("−", "").replace(".", "")
				accepted = digits.length() < MAX_DIGITS
				if accepted:
					if value_text == "0":
						value_text = id
					elif value_text == "−0":
						value_text = "−" + id
					else:
						value_text += id
			else:
				accepted = false
	_refresh_values()
	return accepted


func get_state() -> Dictionary:
	return { "category": category, "from": from_unit, "to": to_unit, "value": value_text }


func set_state(state: Dictionary) -> void:
	var saved_category: String = state.get("category", "length")
	category = saved_category if Units.CATEGORIES.has(saved_category) else "length"
	from_unit = int(state.get("from", Units.DEFAULTS[category][0]))
	to_unit = int(state.get("to", Units.DEFAULTS[category][1]))
	value_text = str(state.get("value", "1"))
	if not value_text.replace("−", "-").is_valid_float():
		value_text = "1"
	refresh()
