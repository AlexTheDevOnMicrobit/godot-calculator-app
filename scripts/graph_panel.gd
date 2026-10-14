extends VBoxContainer
## Graph mode: the plot, a one-line readout, the Y1…Y6 selector with the
## tools menu, and the editor line of the selected function ("Y1 = …").
## The keypad types into the selected function; the graph updates live.

signal changed
signal table_requested
signal functions_requested
signal feedback(ok: bool)

const GraphView := preload("res://scripts/graph_view.gd")
const MathView := preload("res://scripts/math_view.gd")
const ExpressionEditor := preload("res://scripts/expression_editor.gd")
const Evaluator := preload("res://scripts/evaluator.gd")

const COUNT := 6
const COLORS := [Color("#4c9aff"), Color("#ff6b6b"), Color("#3ecf8e"), Color("#b37feb"), Color("#ffb35c"), Color("#2ec4c6")]

enum Tool { TRACE, ZEROS, MINIMUM, MAXIMUM, INTERSECTION, INTEGRAL, TABLE, ZOOM_STANDARD, ZOOM_FIT, ZOOM_TRIG, ZOOM_IN, ZOOM_OUT }

var editors: Array = [] # ExpressionEditor per function
var active := 0
var decimal_separator := "."

var graph: Control
var readout: Label
var _chips: Array = []
var _tools_button: Button
var _tools_menu: PopupMenu
var _editor_label: Label
var _editor_view: Control
var _tokens: Array = [] # last valid compiled tokens per function
var _errors: Array = []
var _integral_bounds: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for i in COUNT:
		var editor := ExpressionEditor.new()
		editors.append(editor)
		_tokens.append([])
		_errors.append(false)

	graph = GraphView.new()
	graph.name = "Graph"
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(0, 160)
	graph.traced.connect(func(_index, _x): _show_trace())
	graph.picked.connect(_on_picked)
	graph.view_changed.connect(func(): changed.emit())
	add_child(graph)

	readout = Label.new()
	readout.name = "Readout"
	readout.theme_type_variation = &"MutedLabel"
	readout.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	readout.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	readout.custom_minimum_size = Vector2(0, 20)
	readout.add_theme_font_size_override("font_size", 13)
	add_child(readout)

	var bar := HBoxContainer.new()
	bar.name = "FunctionBar"
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)
	var group := ButtonGroup.new()
	for i in COUNT:
		var chip := Button.new()
		chip.name = "Y%d" % (i + 1)
		chip.text = "Y%d" % (i + 1)
		chip.toggle_mode = true
		chip.button_group = group
		chip.focus_mode = Control.FOCUS_NONE
		chip.theme_type_variation = &"ChipButton"
		chip.custom_minimum_size = Vector2(38, 32)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chip.add_theme_font_size_override("font_size", 13)
		# The selected function: filled with its colour.
		var selected := StyleBoxFlat.new()
		selected.bg_color = COLORS[i]
		selected.set_corner_radius_all(10)
		for state in ["pressed", "hover_pressed"]:
			chip.add_theme_stylebox_override(state, selected)
		chip.pressed.connect(select.bind(i))
		bar.add_child(chip)
		_chips.append(chip)
	var fx := Button.new()
	fx.name = "FxButton"
	fx.text = "f(x)"
	fx.tooltip_text = "TIP_FX"
	fx.focus_mode = Control.FOCUS_NONE
	fx.theme_type_variation = &"IconButton"
	fx.custom_minimum_size = Vector2(40, 32)
	fx.pressed.connect(func(): functions_requested.emit())
	bar.add_child(fx)
	_tools_button = Button.new()
	_tools_button.name = "ToolsButton"
	_tools_button.text = "⋯"
	_tools_button.tooltip_text = "GRAPH_TOOLS"
	_tools_button.focus_mode = Control.FOCUS_NONE
	_tools_button.theme_type_variation = &"IconButton"
	_tools_button.custom_minimum_size = Vector2(40, 32)
	_tools_button.add_theme_font_size_override("font_size", 22)
	_tools_button.pressed.connect(show_tools)
	bar.add_child(_tools_button)

	var row := HBoxContainer.new()
	row.name = "EditorRow"
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_editor_label = Label.new()
	_editor_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_editor_label.theme_type_variation = &"TitleLabel"
	_editor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_editor_label)
	_editor_view = MathView.new()
	_editor_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_view.custom_minimum_size = Vector2(0, 40)
	_editor_view.font_size_max = 24
	_editor_view.font_size_min = 12
	_editor_view.alignment = 0
	_editor_view.show_caret = true
	row.add_child(_editor_view)

	_tools_menu = PopupMenu.new()
	_tools_menu.name = "ToolsMenu"
	_tools_menu.add_check_item("GRAPH_TRACE", Tool.TRACE)
	_tools_menu.add_separator()
	_tools_menu.add_item("GRAPH_ZEROS", Tool.ZEROS)
	_tools_menu.add_item("GRAPH_MINIMUM", Tool.MINIMUM)
	_tools_menu.add_item("GRAPH_MAXIMUM", Tool.MAXIMUM)
	_tools_menu.add_item("GRAPH_INTERSECTION", Tool.INTERSECTION)
	_tools_menu.add_item("GRAPH_INTEGRAL", Tool.INTEGRAL)
	_tools_menu.add_item("GRAPH_TABLE", Tool.TABLE)
	_tools_menu.add_separator()
	_tools_menu.add_item("ZOOM_STANDARD", Tool.ZOOM_STANDARD)
	_tools_menu.add_item("ZOOM_FIT", Tool.ZOOM_FIT)
	_tools_menu.add_item("ZOOM_TRIG", Tool.ZOOM_TRIG)
	_tools_menu.add_item("ZOOM_IN", Tool.ZOOM_IN)
	_tools_menu.add_item("ZOOM_OUT", Tool.ZOOM_OUT)
	_tools_menu.id_pressed.connect(use_tool)
	add_child(_tools_menu)
	select(0)


func apply_colors(text: Color, muted: Color, accent: Color) -> void:
	graph.axis_color = Color(text, 0.5)
	graph.grid_color = Color(text, 0.07)
	graph.label_color = Color(muted, 0.9)
	graph.accent_color = accent
	graph.points_color = accent
	_editor_view.color = text
	_editor_view.muted_color = muted
	_editor_view.accent_color = accent
	graph.queue_redraw()


# --- Editing ---------------------------------------------------------------

func active_editor():
	return editors[active]


func select(index: int) -> void:
	active = clampi(index, 0, COUNT - 1)
	graph.trace_index = active
	for i in COUNT:
		_chips[i].set_pressed_no_signal(i == active)
	_refresh_editor()
	if graph.trace_enabled:
		_show_trace()


## Inserts text in the selected function. Returns false if rejected.
func insert(text: String) -> bool:
	var editor = active_editor()
	editor.just_evaluated = false
	var ok: bool = editor.insert(text)
	_after_edit()
	return ok


## Keypad actions that are not plain insertions.
func press(id: String) -> bool:
	var editor = active_editor()
	var ok := true
	match id:
		"back":
			ok = editor.backspace()
		"clear":
			ok = not editor.is_empty()
			editor.clear()
			graph.markers.clear()
			graph.shade = {}
		"next":
			ok = editor.next_slot()
		"enter":
			# Next function (like moving down in the Y= editor).
			select((active + 1) % COUNT)
			return true
		"neg":
			ok = editor.negate()
	_after_edit()
	return ok


func _after_edit() -> void:
	_compile(active)
	_push_functions()
	_refresh_editor()
	changed.emit()


func _compile(index: int) -> void:
	var text: String = editors[index].text
	if text.strip_edges() == "":
		_tokens[index] = []
		_errors[index] = false
		return
	# Keep the last valid curve while the expression is being typed ("x+").
	var compiled: Dictionary = graph.evaluator.compile(text)
	if compiled["ok"]:
		graph.evaluator.evaluate_real(compiled["tokens"], 0.5)
		compiled["ok"] = graph.evaluator._error != Evaluator.ERR_SYNTAX
	if compiled["ok"]:
		_tokens[index] = compiled["tokens"]
		_errors[index] = false
	else:
		_errors[index] = true


func _push_functions() -> void:
	var list := []
	for i in COUNT:
		list.append({ "tokens": _tokens[i], "color": COLORS[i] })
	graph.set_functions(list)


func _refresh_editor() -> void:
	_editor_label.text = "Y%d =" % (active + 1)
	_editor_label.add_theme_color_override("font_color", COLORS[active])
	_editor_view.decimal_separator = decimal_separator
	_editor_view.text = editors[active].text
	for i in COUNT:
		var empty: bool = editors[i].is_empty()
		_chips[i].add_theme_color_override("font_color", COLORS[i] if not empty else Color(COLORS[i], 0.45))
		_chips[i].add_theme_color_override("font_pressed_color", Color.WHITE)
		_chips[i].add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	if _errors[active] and not editors[active].is_empty():
		readout.text = tr("ERR_SYNTAX")


# --- Tools -----------------------------------------------------------------

func show_tools() -> void:
	_tools_menu.set_item_checked(_tools_menu.get_item_index(Tool.TRACE), graph.trace_enabled)
	var rect := _tools_button.get_global_rect()
	_tools_menu.popup(Rect2i(Vector2i(rect.position + Vector2(rect.size.x - 240, -8 - 12 * 36)), Vector2i(240, 0)))


func use_tool(id: int) -> void:
	graph.picking = false
	var index := active
	var has_curve: bool = not _tokens[index].is_empty()
	match id:
		Tool.TRACE:
			graph.trace_enabled = not graph.trace_enabled
			if graph.trace_enabled:
				graph.set_trace((graph.x_min + graph.x_max) / 2.0)
			else:
				readout.text = ""
				graph.queue_redraw()
			return
		Tool.ZOOM_STANDARD:
			graph.zoom_standard()
			return
		Tool.ZOOM_FIT:
			graph.zoom_fit()
			return
		Tool.ZOOM_TRIG:
			graph.zoom_trig()
			return
		Tool.ZOOM_IN:
			graph.zoom(0.5)
			return
		Tool.ZOOM_OUT:
			graph.zoom(2.0)
			return
		Tool.TABLE:
			table_requested.emit()
			return
	if not has_curve:
		readout.text = tr("GRAPH_EMPTY")
		feedback.emit(false)
		return
	graph.markers.clear()
	graph.shade = {}
	match id:
		Tool.ZEROS:
			var zeros: Array = graph.find_zeros(index)
			for x in zeros:
				graph.markers.append({ "x": x, "y": 0.0, "color": COLORS[index] })
			_list_result("GRAPH_ZEROS", zeros.map(func(x): return "x = " + _fmt(x)))
		Tool.MINIMUM, Tool.MAXIMUM:
			var found: Array = graph.find_extrema(index, id == Tool.MAXIMUM)
			for p in found:
				graph.markers.append({ "x": p[0], "y": p[1], "color": COLORS[index] })
			_list_result("GRAPH_MINIMUM" if id == Tool.MINIMUM else "GRAPH_MAXIMUM",
				found.map(func(p): return "(%s ; %s)" % [_fmt(p[0]), _fmt(p[1])]))
		Tool.INTERSECTION:
			var all := []
			for other in COUNT:
				if other != index and not _tokens[other].is_empty():
					for p in graph.find_intersections(index, other):
						graph.markers.append({ "x": p[0], "y": p[1], "color": COLORS[other] })
						all.append("(%s ; %s)" % [_fmt(p[0]), _fmt(p[1])])
			_list_result("GRAPH_INTERSECTION", all)
		Tool.INTEGRAL:
			_integral_bounds.clear()
			graph.picking = true
			readout.text = tr("GRAPH_PICK_LOWER")
	graph.queue_redraw()


func _list_result(title_key: String, items: Array) -> void:
	if items.is_empty():
		readout.text = tr(title_key) + " : " + tr("GRAPH_NONE")
		feedback.emit(false)
	else:
		readout.text = tr(title_key) + " : " + "   ".join(items.slice(0, 4)) + (" …" if items.size() > 4 else "")
		feedback.emit(true)


func _on_picked(x: float) -> void:
	_integral_bounds.append(x)
	graph.markers.append({ "x": x, "y": graph.value_at(active, x), "color": COLORS[active] })
	if _integral_bounds.size() == 1:
		readout.text = tr("GRAPH_PICK_UPPER")
		graph.queue_redraw()
		return
	graph.picking = false
	var a: float = minf(_integral_bounds[0], _integral_bounds[1])
	var b: float = maxf(_integral_bounds[0], _integral_bounds[1])
	show_integral(a, b)


## Shades and computes ∫ f(x) dx on [a, b] for the selected function.
func show_integral(a: float, b: float) -> void:
	var value: float = graph.evaluator.integral_of(_tokens[active], a, b)
	graph.shade = { "index": active, "a": a, "b": b }
	readout.text = "∫ [%s ; %s] = %s" % [_fmt(a), _fmt(b), _fmt(value)]
	graph.queue_redraw()
	feedback.emit(is_finite(value))


func _show_trace() -> void:
	if not graph.trace_enabled:
		return
	var x: float = graph.trace_x
	if _tokens[active].is_empty():
		readout.text = "x = " + _fmt(x)
		return
	var y: float = graph.value_at(active, x)
	var slope: float = graph.evaluator.derivative_of(_tokens[active], x)
	readout.text = "Y%d   x = %s   y = %s   dy/dx = %s" % [active + 1, _fmt(x), _fmt(y), _fmt(slope)]


func _fmt(v: float) -> String:
	if not is_finite(v):
		return "—"
	# Numerical answers are only accurate to ~1e-7 of the window: hide the noise.
	var span := maxf(graph.x_max - graph.x_min, graph.y_max - graph.y_min)
	var step := pow(10.0, floorf(log(span * 1e-7) / log(10.0)))
	if absf(v) < 1e12:
		v = snappedf(v, step)
	return Evaluator.format_number(v if absf(v) > step else 0.0, decimal_separator).replace("-", "−").left(12)


# --- Table of values -------------------------------------------------------

## Rows for the table page: [[x, [y1, y2, ...]], ...] for the non-empty functions.
func table(start: float, step: float, rows: int) -> Dictionary:
	var used := []
	for i in COUNT:
		if not _tokens[i].is_empty():
			used.append(i)
	var data := []
	for r in rows:
		var x := start + r * step
		if absf(x) < step * 1e-9:
			x = 0.0
		var values := []
		for i in used:
			values.append(graph.value_at(i, x))
		data.append([x, values])
	return { "functions": used, "rows": data }


# --- State -----------------------------------------------------------------

func get_state() -> Dictionary:
	var texts := []
	for editor in editors:
		texts.append(editor.text)
	return { "functions": texts, "window": [graph.x_min, graph.x_max, graph.y_min, graph.y_max], "active": active }


func set_state(state: Dictionary) -> void:
	var texts: Array = state.get("functions", [])
	for i in COUNT:
		editors[i].text = str(texts[i]) if i < texts.size() else ""
		_compile(i)
	_push_functions()
	var window: Array = state.get("window", [])
	if window.size() == 4:
		graph.set_window(window[0], window[1], window[2], window[3])
	select(int(state.get("active", 0)))
