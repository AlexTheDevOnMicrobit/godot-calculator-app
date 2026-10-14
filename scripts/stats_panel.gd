extends VBoxContainer
## Statistics mode: Data (X / Y lists), Results (1-Var, 2-Var, regressions)
## and Plot (scatter + regression curve) tabs. The keypad types into the
## selected cell; ↵ moves to the next one.

signal changed
signal message(key: String)

const Stats := preload("res://scripts/stats.gd")
const GraphView := preload("res://scripts/graph_view.gd")
const Evaluator := preload("res://scripts/evaluator.gd")

const ANALYSES := ["one_var", "two_var", "linear", "quadratic", "exponential", "power", "logarithmic"]
const ANALYSIS_KEYS := {
	"one_var": "STATS_ONE_VAR", "two_var": "STATS_TWO_VAR", "linear": "REG_LINEAR",
	"quadratic": "REG_QUADRATIC", "exponential": "REG_EXPONENTIAL", "power": "REG_POWER",
	"logarithmic": "REG_LOGARITHMIC",
}
const VISIBLE_ROWS_EXTRA := 1 # empty row at the end to add data
const MAX_ROWS := 500

var xs: Array = [] # values as text ("" = empty cell)
var ys: Array = []
var row := 0
var column := 0 # 0 = X, 1 = Y
var analysis := "linear"
var tab := 0 # 0 data, 1 results, 2 plot
var decimal_separator := "."
var group_separator := ","

var _tabs: Array = []
var _pages: Array = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _analysis_option: OptionButton
var _results: RichTextLabel
var _plot: Control
var _cells: Array = [] # [row][column] -> Button
var _clear_armed := false
var _colors := { "text": Color.WHITE, "muted": Color.GRAY, "accent": Color.ORANGE }


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	var group := ButtonGroup.new()
	for i in 3:
		var button := Button.new()
		button.text = ["STATS_DATA", "STATS_RESULTS", "STATS_PLOT"][i]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"SegmentButton"
		button.custom_minimum_size = Vector2(0, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_tab.bind(i))
		bar.add_child(button)
		_tabs.append(button)

	# Data page
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_grid)

	# Results page
	var results_page := VBoxContainer.new()
	results_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_page.add_theme_constant_override("separation", 8)
	add_child(results_page)
	_analysis_option = OptionButton.new()
	_analysis_option.focus_mode = Control.FOCUS_NONE
	_analysis_option.custom_minimum_size = Vector2(0, 38)
	for id in ANALYSES:
		_analysis_option.add_item(ANALYSIS_KEYS[id])
	_analysis_option.item_selected.connect(func(index):
		analysis = ANALYSES[index]
		refresh_results()
		changed.emit())
	results_page.add_child(_analysis_option)
	_results = RichTextLabel.new()
	_results.bbcode_enabled = true
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results.focus_mode = Control.FOCUS_NONE
	_results.selection_enabled = true
	_results.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	results_page.add_child(_results)

	# Plot page
	_plot = GraphView.new()
	_plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_plot)

	_pages = [_scroll, results_page, _plot]
	show_tab(0)


func apply_colors(text: Color, muted: Color, accent: Color) -> void:
	_colors = { "text": text, "muted": muted, "accent": accent }
	_plot.axis_color = Color(text, 0.5)
	_plot.grid_color = Color(text, 0.07)
	_plot.label_color = Color(muted, 0.9)
	_plot.points_color = accent
	_plot.accent_color = accent
	if is_node_ready():
		refresh_results()


func show_tab(index: int) -> void:
	tab = index
	for i in _pages.size():
		_pages[i].visible = i == index
		_tabs[i].set_pressed_no_signal(i == index)
	match index:
		0:
			_rebuild_table()
		1:
			refresh_results()
		2:
			_refresh_plot()


# --- Data table ------------------------------------------------------------

func _row_count() -> int:
	return mini(maxi(xs.size(), ys.size()) + VISIBLE_ROWS_EXTRA, MAX_ROWS)


func _rebuild_table() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cells.clear()
	for header in ["#", "X", "Y"]:
		var label := Label.new()
		label.text = header
		label.theme_type_variation = &"SectionLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if header != "#" else Control.SIZE_FILL
		_grid.add_child(label)
	for r in _row_count():
		var index := Label.new()
		index.text = str(r + 1)
		index.theme_type_variation = &"MutedLabel"
		index.custom_minimum_size = Vector2(28, 0)
		index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		index.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_grid.add_child(index)
		var cells := []
		for c in 2:
			var cell := Button.new()
			cell.toggle_mode = true
			cell.focus_mode = Control.FOCUS_NONE
			cell.theme_type_variation = &"SegmentButton"
			cell.custom_minimum_size = Vector2(0, 34)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			cell.pressed.connect(select_cell.bind(r, c))
			_grid.add_child(cell)
			cells.append(cell)
		_cells.append(cells)
	_refresh_cells()


func _refresh_cells() -> void:
	for r in _cells.size():
		for c in 2:
			var list: Array = xs if c == 0 else ys
			var text: String = list[r] if r < list.size() else ""
			var cell: Button = _cells[r][c]
			cell.text = text.replace(".", decimal_separator) + ("|" if r == row and c == column else "")
			cell.set_pressed_no_signal(r == row and c == column)


func select_cell(r: int, c: int) -> void:
	row = clampi(r, 0, MAX_ROWS - 1)
	column = clampi(c, 0, 1)
	if tab != 0:
		show_tab(0)
	if row >= _cells.size():
		_rebuild_table()
	_refresh_cells()
	_scroll_to_row()


func _scroll_to_row() -> void:
	if row < _cells.size():
		var cell: Button = _cells[row][column]
		await get_tree().process_frame
		if is_instance_valid(cell) and _scroll.is_ancestor_of(cell):
			_scroll.ensure_control_visible(cell)


func _cell_text() -> String:
	var list: Array = xs if column == 0 else ys
	return list[row] if row < list.size() else ""


func _set_cell_text(text: String) -> void:
	var list: Array = xs if column == 0 else ys
	while list.size() <= row:
		list.append("")
	list[row] = text
	# Drop empty rows at the end.
	while not xs.is_empty() and xs.size() > 0 and xs[-1] == "" and (ys.size() < xs.size() or ys[xs.size() - 1] == ""):
		xs.pop_back()
	while not ys.is_empty() and ys[-1] == "" and ys.size() > xs.size():
		ys.pop_back()


## Keypad action. Returns false if rejected.
func press(id: String) -> bool:
	if id != "clear_all":
		_clear_armed = false
	if tab != 0 and id not in ["clear_all"]:
		show_tab(0)
	var text := _cell_text()
	var ok := true
	match id:
		"back":
			ok = text != ""
			_set_cell_text(text.left(text.length() - 1))
		"neg":
			if text.ends_with("E"):
				_set_cell_text(text + "-") # exponent sign: 1E-3
			else:
				_set_cell_text(text.substr(1) if text.begins_with("-") else "-" + text)
		"dot":
			ok = not text.contains(".") and not text.contains("E")
			if ok:
				_set_cell_text(text + ("." if text not in ["", "-"] else "0."))
		"exp":
			ok = text != "" and text != "-" and not text.contains("E")
			if ok:
				_set_cell_text(text + "E")
		"enter":
			_commit()
			if column == 0:
				column = 1
			else:
				column = 0
				row += 1
		"up":
			_commit()
			ok = row > 0
			row = maxi(row - 1, 0)
		"down":
			_commit()
			ok = row < _row_count() - 1
			row = mini(row + 1, _row_count() - 1)
		"switch":
			_commit()
			column = 1 - column
		"delete_row":
			ok = row < maxi(xs.size(), ys.size())
			if row < xs.size():
				xs.remove_at(row)
			if row < ys.size():
				ys.remove_at(row)
		"clear_all":
			if not _clear_armed:
				_clear_armed = true
				message.emit("STATS_CLEAR_CONFIRM")
				return true
			_clear_armed = false
			xs.clear()
			ys.clear()
			row = 0
			column = 0
		_:
			if id.length() == 1 and id.is_valid_int():
				ok = text.length() < 16
				if ok:
					if text == "0":
						text = ""
					elif text == "-0":
						text = "-"
					_set_cell_text(text + id)
			else:
				ok = false
	if _row_count() != _cells.size() or row >= _cells.size():
		_rebuild_table()
	else:
		_refresh_cells()
	_scroll_to_row()
	changed.emit()
	return ok


## Normalizes the cell text ("1." -> "1", "1E" -> "1").
func _commit() -> void:
	var text := _cell_text()
	if text == "" :
		return
	var cleaned := text.trim_suffix("E").trim_suffix("E-")
	if cleaned in ["-", "", "0."]:
		cleaned = "0" if cleaned == "0." else ""
	if cleaned.ends_with("."):
		cleaned = cleaned.trim_suffix(".")
	_set_cell_text(cleaned)


# --- Results ---------------------------------------------------------------

## Valid numbers of a list (and of both lists, paired, for 2-variable analyses).
func _numbers(list: Array) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	for text in list:
		if str(text).is_valid_float():
			values.append(float(text))
	return values


func _pairs() -> Array:
	var px := PackedFloat64Array()
	var py := PackedFloat64Array()
	for r in mini(xs.size(), ys.size()):
		if str(xs[r]).is_valid_float() and str(ys[r]).is_valid_float():
			px.append(float(xs[r]))
			py.append(float(ys[r]))
	return [px, py]


func _fmt(v: float) -> String:
	if is_nan(v):
		return "—"
	return Evaluator.format_number(v, decimal_separator, group_separator).replace("-", "−")


func _line(label: String, value: String) -> String:
	return "[color=#%s]%s[/color]  %s" % [_colors["muted"].to_html(false), label, value]


func refresh_results() -> void:
	if _results == null:
		return
	_analysis_option.select(ANALYSES.find(analysis))
	var lines: PackedStringArray = []
	match analysis:
		"one_var":
			var one := Stats.one_var(_numbers(xs))
			if one.is_empty():
				lines.append(tr("STATS_NOT_ENOUGH"))
			else:
				for item in [["n", one["n"]], ["x̄", one["mean"]], ["Σx", one["sum"]], ["Σx²", one["sum_squares"]],
						["Sx", one["sx"]], ["σx", one["sigma"]], ["minX", one["min"]], ["Q1", one["q1"]],
						["Med", one["median"]], ["Q3", one["q3"]], ["maxX", one["max"]]]:
					lines.append(_line(item[0], _fmt(float(item[1]))))
		"two_var":
			var pairs := _pairs()
			var two := Stats.two_var(pairs[0], pairs[1])
			if two.is_empty():
				lines.append(tr("STATS_NOT_ENOUGH"))
			else:
				for item in [["n", two["n"]], ["x̄", two["mean_x"]], ["ȳ", two["mean_y"]], ["Σx", two["sum_x"]],
						["Σy", two["sum_y"]], ["Σx²", two["sum_x2"]], ["Σy²", two["sum_y2"]], ["Σxy", two["sum_xy"]],
						["Sx", two["sx"]], ["Sy", two["sy"]], ["r", two["r"]]]:
					lines.append(_line(item[0], _fmt(float(item[1]))))
		_:
			var fit := regression()
			if not fit["ok"]:
				lines.append(tr(fit["error"]))
			else:
				lines.append("[b]%s[/b]" % Stats.REGRESSIONS[analysis][0])
				var coefficients: Dictionary = fit["coefficients"]
				for name in ["a", "b", "c"]:
					if coefficients.has(name):
						lines.append(_line(name, _fmt(coefficients[name])))
				lines.append(_line("r²", _fmt(fit["r2"])))
				if fit.has("r"):
					lines.append(_line("r", _fmt(fit["r"])))
	_results.text = "\n".join(lines)


func regression() -> Dictionary:
	var pairs := _pairs()
	return Stats.regression(analysis, pairs[0], pairs[1])


func _refresh_plot() -> void:
	var pairs := _pairs()
	var points := PackedVector2Array()
	if analysis == "one_var":
		var values := _numbers(xs)
		for k in values.size():
			points.append(Vector2(k + 1, values[k]))
	else:
		for k in pairs[0].size():
			points.append(Vector2(pairs[0][k], pairs[1][k]))
	_plot.points = points
	var functions := []
	if analysis not in ["one_var", "two_var"]:
		var fit := regression()
		if fit["ok"]:
			functions.append({ "tokens": _plot.evaluator.compile(fit["expression"])["tokens"], "color": _colors["accent"] })
	_plot.set_functions(functions)
	await get_tree().process_frame
	_plot.zoom_data()


# --- State -----------------------------------------------------------------

func get_state() -> Dictionary:
	return { "x": xs.duplicate(), "y": ys.duplicate(), "analysis": analysis }


func set_state(state: Dictionary) -> void:
	xs = Array(state.get("x", [])).map(func(v): return str(v))
	ys = Array(state.get("y", [])).map(func(v): return str(v))
	analysis = state.get("analysis", "linear")
	if analysis not in ANALYSES:
		analysis = "linear"
	row = 0
	column = 0
	if is_node_ready():
		show_tab(tab)
