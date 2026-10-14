extends VBoxContainer
## "Basic knowledge" page: number tables, constants, formulas and rules.
## Built lazily the first time it is shown (and again when the language
## changes). Tapping a number emits value_chosen with the text to insert.

signal value_chosen(insert: String)

const Knowledge := preload("res://scripts/knowledge.gd")
const MathView := preload("res://scripts/math_view.gd")

var language := "en"
var decimal_separator := "."
var group_separator := ","
var math_color := Color.WHITE
var muted_color := Color(1, 1, 1, 0.5)
var accent_color := Color.ORANGE

var _built_for := ""
var _math_views: Array = []


## Builds the content if needed (first display or new language).
func ensure_built() -> void:
	if _built_for == language:
		return
	_built_for = language
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_math_views.clear()
	add_theme_constant_override("separation", 8)
	for section in Knowledge.SECTIONS:
		_add_title(Knowledge.text(Knowledge.TITLES[section], language))
		if Knowledge.NOTES.has(section):
			_add_note(Knowledge.text(Knowledge.NOTES[section], language))
		call("_build_" + section)


## Re-colors the formulas after a theme change.
func apply_colors(text_color: Color, muted: Color, accent: Color) -> void:
	math_color = text_color
	muted_color = muted
	accent_color = accent
	for view in _math_views:
		if is_instance_valid(view):
			view.color = text_color
			view.muted_color = muted
			view.accent_color = accent


func section_count() -> int:
	var count := 0
	for child in get_children():
		if child is Label and child.theme_type_variation == &"HeaderLabel":
			count += 1
	return count


# --- Building blocks -------------------------------------------------------

func _add_title(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = &"HeaderLabel"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", 17)
	if get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		add_child(spacer)
	add_child(label)


func _add_note(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(label)
	return label


func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	return grid


## A tappable chip: "label" shown, [param insert] typed in the calculator.
func _chip(parent: Control, label: String, insert: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"SegmentButton"
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.add_theme_font_size_override("font_size", 14)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(func(): value_chosen.emit(insert))
	parent.add_child(button)
	return button


func _math(parent: Control, expression: String, font_size: int, alignment := 0) -> Control:
	var view: Control = MathView.new()
	view.font_size_max = font_size
	view.font_size_min = 11
	view.alignment = alignment
	view.custom_minimum_size = Vector2(0, font_size * 1.6)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.decimal_separator = decimal_separator
	view.list_separator = "; " if language == "fr" else ", "
	view.color = math_color
	view.muted_color = muted_color
	view.accent_color = accent_color
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.text = expression
	parent.add_child(view)
	_math_views.append(view)
	return view


func _formula_list(entries: Array) -> void:
	for entry in entries:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		add_child(box)
		var caption := Label.new()
		caption.text = entry[2] if language == "fr" else entry[1]
		caption.theme_type_variation = &"SectionLabel"
		caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.add_child(caption)
		_math(box, entry[0], 22)


func _number(value: int) -> String:
	return Knowledge.grouped(value, group_separator)


# --- Sections --------------------------------------------------------------

func _build_squares() -> void:
	var grid := _grid(3)
	for n in range(1, 31):
		_chip(grid, "%d² = %s" % [n, _number(n * n)], str(n * n))


func _build_cubes() -> void:
	var grid := _grid(3)
	for n in range(1, 16):
		_chip(grid, "%d³ = %s" % [n, _number(n * n * n)], str(n * n * n))


func _build_primes() -> void:
	var grid := _grid(6)
	for p in Knowledge.primes_below(200):
		_chip(grid, str(p), str(p))


func _build_pi() -> void:
	var digits := Knowledge.PI_DIGITS.replace(".", decimal_separator)
	var label := _add_note(digits)
	label.theme_type_variation = &"Label"
	label.add_theme_font_size_override("font_size", 16)
	_add_note("« " + Knowledge.text(Knowledge.PI_MNEMONIC, language) + " »")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_chip(row, "π", "π")
	_chip(row, "2π", "2π")
	_chip(row, "π⁄2", "frac(π;2)")
	_chip(row, "π²", "π^2")


func _build_constants() -> void:
	var grid := _grid(2)
	var evaluator := preload("res://scripts/evaluator.gd").new()
	for constant in Knowledge.CONSTANTS:
		var value: float = evaluator.evaluate(constant[1])["value"]
		var shown := String.num(value, 10).replace(".", decimal_separator)
		var name: String = constant[3] if language == "fr" else constant[2]
		var chip := _chip(grid, "%s ≈ %s" % [constant[0], shown], constant[1])
		chip.tooltip_text = name
	_add_note("e = " + Knowledge.E_DIGITS.replace(".", decimal_separator))


func _build_powers2() -> void:
	var grid := _grid(3)
	for n in range(0, 21):
		_chip(grid, "2^%d = %s" % [n, _number(1 << n)], str(1 << n))


func _build_factorials() -> void:
	var grid := _grid(2)
	for n in range(0, 16):
		var value := Knowledge.factorial(n)
		_chip(grid, "%d! = %s" % [n, _number(value)], str(value))


func _build_trig() -> void:
	var grid := _grid(4)
	grid.add_theme_constant_override("v_separation", 2)
	for header in ["", "sin", "cos", "tan"]:
		var label := Label.new()
		label.text = header
		label.theme_type_variation = &"SectionLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
	for row in Knowledge.TRIG:
		var angle := Label.new()
		angle.text = row[0]
		angle.theme_type_variation = &"MutedLabel"
		angle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		angle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		grid.add_child(angle)
		for i in range(1, 4):
			var view := _math(grid, row[i], 18, 1)
			view.custom_minimum_size = Vector2(0, 46)


func _build_identities() -> void:
	_formula_list(Knowledge.IDENTITIES)


func _build_geometry() -> void:
	_formula_list(Knowledge.GEOMETRY)


func _build_divisibility() -> void:
	for rule in Knowledge.DIVISIBILITY:
		var label := Label.new()
		var by := "Divisible par %s si " if language == "fr" else "Divisible by %s if "
		label.text = (by % rule[0]) + (rule[2] if language == "fr" else rule[1]) + "."
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.add_theme_font_size_override("font_size", 15)
		add_child(label)


func _build_prefixes() -> void:
	var grid := _grid(3)
	for prefix in Knowledge.PREFIXES:
		_chip(grid, "%s  %s" % [prefix[0], prefix[1]], "10^(%s)" % str(prefix[2]).replace("-", "−")) \
			.tooltip_text = "10^%d" % prefix[2]
