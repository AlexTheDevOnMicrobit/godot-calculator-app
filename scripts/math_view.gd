extends Control
## Draws an expression in "textbook" form: stacked fractions, radicals with a
## bar over the radicand (and an index for ⁿ√x), superscript exponents,
## parentheses / absolute value bars that grow with their content, empty-slot
## placeholders and a blinking caret.
##
## The expression is parsed by math_format.gd and laid out into a flat list
## of draw commands, cached until the text, size or font changes.

const MathFormat := preload("res://scripts/math_format.gd")

@export var font_size_max := 26
@export var font_size_min := 14
## Draw the content in bold (used for results).
@export var bold := false

var text := "":
	set(value):
		if value != text:
			text = value
			_invalidate()
var show_caret := false:
	set(value):
		if value != show_caret:
			show_caret = value
			_caret_on = true
			_invalidate()
var decimal_separator := ".":
	set(value):
		decimal_separator = value
		_invalidate()
var list_separator := ", ":
	set(value):
		list_separator = value
		_invalidate()
var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()
var muted_color := Color(1, 1, 1, 0.4):
	set(value):
		muted_color = value
		queue_redraw()
var accent_color := Color.ORANGE:
	set(value):
		accent_color = value
		queue_redraw()

var _format := MathFormat.new()
var _layout := {}
var _layout_key := ""
var _caret_on := true
var _blink: Timer
var _font: Font


func _ready() -> void:
	clip_contents = true
	_blink = Timer.new()
	_blink.wait_time = 0.53
	_blink.timeout.connect(func():
		_caret_on = not _caret_on
		if show_caret:
			queue_redraw())
	add_child(_blink)
	_blink.start()
	resized.connect(_invalidate)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_invalidate()


func _invalidate() -> void:
	_layout_key = ""
	queue_redraw()


## Width the expression needs at the largest font size (for tests / layout).
func content_width() -> float:
	_ensure_layout()
	return _layout.get("w", 0.0)


func _ensure_layout() -> void:
	var key := "%s|%s|%d|%s" % [text, show_caret, int(size.x), decimal_separator]
	if key == _layout_key and not _layout.is_empty():
		return
	_layout_key = key
	_font = get_theme_font("bold_font", "RichTextLabel") if bold else get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	var tree := _format.parse(text, show_caret)
	var font_size := font_size_max
	_layout = _layout_row(tree, font_size)
	while _layout["w"] > size.x and font_size > font_size_min:
		font_size -= 2
		_layout = _layout_row(tree, font_size)
	var needed: float = _layout["asc"] + _layout["desc"] + 4.0
	if needed > custom_minimum_size.y:
		custom_minimum_size.y = needed


func _draw() -> void:
	_ensure_layout()
	if _layout.is_empty():
		return
	var total_height: float = _layout["asc"] + _layout["desc"]
	var origin := Vector2(size.x - _layout["w"], (size.y - total_height) / 2.0 + _layout["asc"])
	for cmd in _layout["cmds"]:
		var col: Color = color
		match cmd.get("tone", "normal"):
			"muted":
				col = muted_color
			"accent":
				col = accent_color
		var offset: Vector2 = origin + cmd["at"]
		match cmd["kind"]:
			"text":
				draw_string(_font, offset, cmd["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, cmd["size"], col)
			"line":
				draw_line(offset, origin + cmd["to"], col, cmd["width"], true)
			"poly":
				var points := PackedVector2Array()
				for p in cmd["points"]:
					points.append(origin + p)
				draw_polyline(points, col, cmd["width"], true)
			"box":
				draw_rect(Rect2(offset, cmd["size_v"]), col, false, 1.5)
			"caret":
				if show_caret and _caret_on:
					draw_rect(Rect2(offset, cmd["size_v"]), accent_color)


# --- Layout ----------------------------------------------------------------
# Every layout function returns { "w", "asc", "desc", "cmds" } with commands
# relative to (left, baseline). Y grows downwards, so "up" is negative.

func _box(w: float, asc: float, desc: float, cmds: Array = []) -> Dictionary:
	return { "w": w, "asc": asc, "desc": desc, "cmds": cmds }


func _shift(cmds: Array, by: Vector2) -> Array:
	var out := []
	for cmd in cmds:
		var c: Dictionary = cmd.duplicate()
		c["at"] = c["at"] + by
		if c.has("to"):
			c["to"] = c["to"] + by
		if c.has("points"):
			var pts := []
			for p in c["points"]:
				pts.append(p + by)
			c["points"] = pts
		out.append(c)
	return out


func _text_box(value: String, font_size: int, tone := "normal") -> Dictionary:
	var w := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _box(w, _font.get_ascent(font_size) * 0.8, _font.get_descent(font_size),
		[{ "kind": "text", "at": Vector2.ZERO, "text": value, "size": font_size, "tone": tone }])


func _placeholder(font_size: int) -> Dictionary:
	var w := font_size * 0.55
	var h := font_size * 0.72
	return _box(w + 4.0, h, font_size * 0.04,
		[{ "kind": "box", "at": Vector2(2.0, -h), "size_v": Vector2(w, h), "tone": "muted" }])


func _layout_row(row: Dictionary, font_size: int) -> Dictionary:
	var items: Array = row["items"]
	var only_caret: bool = items.size() == 1 and items[0]["type"] == "caret"
	if items.is_empty() or only_caret:
		var empty := _placeholder(font_size)
		if only_caret:
			empty["cmds"].append(_caret_cmd(Vector2(2.0, 0.0), font_size))
		return empty
	var x := 0.0
	var asc := _font.get_ascent(font_size) * 0.8
	var desc := _font.get_descent(font_size)
	var cmds := []
	var previous: Dictionary = {}
	var previous_box: Dictionary = {}
	for item in items:
		if item["type"] == "sup":
			var exp_size := maxi(int(font_size * 0.68), 10)
			var exponent := _layout_row(item["row"], exp_size)
			var base_asc: float = previous_box.get("asc", font_size * 0.6)
			var raise: float = base_asc * 0.55 + exponent["desc"]
			cmds.append_array(_shift(exponent["cmds"], Vector2(x + 1.0, -raise)))
			asc = maxf(asc, raise + exponent["asc"])
			desc = maxf(desc, exponent["desc"] - raise)
			x += exponent["w"] + 2.0
			previous = item
			continue
		var box := _layout_item(item, font_size)
		var pad := 0.0
		if item["type"] == "text" and item["kind"] == "op":
			var unary: bool = item["text"] in ["−", "~"] and (previous.is_empty() \
				or (previous["type"] == "text" and previous["kind"] == "op"))
			if not unary:
				pad = font_size * 0.18
		x += pad
		cmds.append_array(_shift(box["cmds"], Vector2(x, 0.0)))
		x += box["w"] + pad
		asc = maxf(asc, box["asc"])
		desc = maxf(desc, box["desc"])
		previous = item
		previous_box = box
	return _box(x, asc, desc, cmds)


func _caret_cmd(at: Vector2, font_size: int) -> Dictionary:
	var h := font_size * 0.9
	return { "kind": "caret", "at": at + Vector2(0.0, -h * 0.82), "size_v": Vector2(2.0, h) }


func _layout_item(node: Dictionary, font_size: int) -> Dictionary:
	match node["type"]:
		"text":
			var value: String = node["text"]
			if node["kind"] == "num":
				value = value.replace(".", decimal_separator).replace(",", decimal_separator)
			return _text_box(value, font_size)
		"caret":
			return _box(4.0, font_size * 0.75, font_size * 0.15, [_caret_cmd(Vector2(1.0, 0.0), font_size)])
		"paren":
			return _wrap(_layout_row(node["row"], font_size), font_size, "(", ")" if node["closed"] else "", not node["closed"])
		"abs":
			return _wrap(_layout_row(node["row"], font_size), font_size, "|", "|", not node["closed"])
		"root":
			return _layout_root(node, font_size)
		"frac":
			return _layout_frac(node, font_size)
		"func":
			var name := _text_box(node["name"], font_size)
			var args := _layout_args(node["args"], font_size)
			var wrapped := _wrap(args, font_size, "(", ")" if node["closed"] else "", not node["closed"])
			return _concat([name, wrapped])
		"logb":
			var log_box := _text_box("log", font_size)
			var base := _layout_row(node["base"], maxi(int(font_size * 0.62), 10))
			var drop: float = font_size * 0.25 + base["asc"] * 0.5
			var base_box := _box(base["w"] + 1.0, maxf(0.0, base["asc"] - drop), base["desc"] + drop,
				_shift(base["cmds"], Vector2(1.0, drop)))
			var arg := _wrap(_layout_row(node["arg"], font_size), font_size, "(", ")" if node["closed"] else "", not node["closed"])
			return _concat([log_box, base_box, arg])
	return _box(0.0, 0.0, 0.0)


func _concat(boxes: Array) -> Dictionary:
	var x := 0.0
	var asc := 0.0
	var desc := 0.0
	var cmds := []
	for box in boxes:
		cmds.append_array(_shift(box["cmds"], Vector2(x, 0.0)))
		x += box["w"]
		asc = maxf(asc, box["asc"])
		desc = maxf(desc, box["desc"])
	return _box(x, asc, desc, cmds)


func _layout_args(args: Array, font_size: int) -> Dictionary:
	var boxes := []
	for i in args.size():
		if i > 0:
			boxes.append(_text_box(list_separator, font_size, "muted"))
		boxes.append(_layout_row(args[i], font_size))
	return _concat(boxes)


## Surrounds [param inner] with delimiters that grow with its height.
## An unclosed group shows a faded closing delimiter.
func _wrap(inner: Dictionary, font_size: int, open: String, close: String, ghost_close: bool) -> Dictionary:
	var line_height := (_font.get_ascent(font_size) * 0.8 + _font.get_descent(font_size)) * 1.15
	var height: float = inner["asc"] + inner["desc"]
	var tall := height > line_height
	var close_char := close if close != "" else (")" if open == "(" else "|")
	var parts := []
	if not tall:
		parts.append(_text_box(open, font_size))
		parts.append(inner)
		if close != "" or ghost_close:
			parts.append(_text_box(close_char, font_size, "normal" if close != "" else "muted"))
		return _concat(parts)
	var w := font_size * 0.32
	var top: float = -inner["asc"] - 2.0
	var bottom: float = inner["desc"] + 2.0
	var stroke := maxf(1.5, font_size * 0.07)
	var open_box := _box(w, -top, bottom, [_delimiter(open, w, top, bottom, stroke, "normal")])
	var close_box := _box(w, -top, bottom, [_delimiter(close_char, w, top, bottom, stroke,
		"normal" if close != "" else "muted")])
	parts.append(open_box)
	parts.append(inner)
	if close != "" or ghost_close:
		parts.append(close_box)
	return _concat(parts)


func _delimiter(kind: String, w: float, top: float, bottom: float, stroke: float, tone: String) -> Dictionary:
	var points := []
	if kind == "|":
		points = [Vector2(w * 0.5, top), Vector2(w * 0.5, bottom)]
	else:
		var left := kind == "("
		var x_edge := w * 0.75 if left else w * 0.25
		var x_belly := w * 0.2 if left else w * 0.8
		for i in 9:
			var t := i / 8.0
			var y := lerpf(top, bottom, t)
			var bulge := sin(t * PI)
			points.append(Vector2(lerpf(x_edge, x_belly, bulge), y))
	return { "kind": "poly", "at": Vector2.ZERO, "points": points, "width": stroke, "tone": tone }


func _layout_root(node: Dictionary, font_size: int) -> Dictionary:
	var radicand := _layout_row(node["row"], font_size)
	var stroke := maxf(1.5, font_size * 0.06)
	var gap := font_size * 0.12
	var top: float = -(radicand["asc"] + gap + stroke)
	var bottom: float = radicand["desc"]
	var sign_w := font_size * 0.55
	var mid := lerpf(top, bottom, 0.62)
	var x0 := 0.0
	var cmds := []
	var asc := -top
	if node["index"] != null:
		var index := _layout_row(node["index"], maxi(int(font_size * 0.58), 10))
		x0 = maxf(0.0, index["w"] - sign_w * 0.45)
		var index_baseline := mid - font_size * 0.08
		cmds.append_array(_shift(index["cmds"], Vector2(x0 + sign_w * 0.4 - index["w"], index_baseline)))
		asc = maxf(asc, -index_baseline + index["asc"])
	var end: float = x0 + sign_w + radicand["w"] + font_size * 0.12
	cmds.append({ "kind": "poly", "at": Vector2.ZERO, "width": stroke, "tone": "normal", "points": [
		Vector2(x0, mid + font_size * 0.04), Vector2(x0 + sign_w * 0.18, mid - font_size * 0.03),
		Vector2(x0 + sign_w * 0.45, bottom), Vector2(x0 + sign_w, top), Vector2(end, top)] })
	cmds.append_array(_shift(radicand["cmds"], Vector2(x0 + sign_w + font_size * 0.04, 0.0)))
	return _box(end + 2.0, asc, bottom + 2.0, cmds)


func _layout_frac(node: Dictionary, font_size: int) -> Dictionary:
	var inner_size := maxi(int(font_size * 0.85), 12)
	var num := _layout_row(node["num"], inner_size)
	var den := _layout_row(node["den"], inner_size)
	var axis := font_size * 0.3
	var gap := font_size * 0.12
	var stroke := maxf(1.5, font_size * 0.06)
	var pad := font_size * 0.12
	var w := maxf(num["w"], den["w"]) + pad * 2.0
	var num_baseline: float = -(axis + gap + num["desc"])
	var den_baseline: float = -axis + gap + stroke + den["asc"]
	var cmds := []
	cmds.append_array(_shift(num["cmds"], Vector2((w - num["w"]) / 2.0, num_baseline)))
	cmds.append_array(_shift(den["cmds"], Vector2((w - den["w"]) / 2.0, den_baseline)))
	cmds.append({ "kind": "line", "at": Vector2(pad * 0.5, -axis), "to": Vector2(w - pad * 0.5, -axis),
		"width": stroke, "tone": "normal" })
	return _box(w + 2.0, -num_baseline + num["asc"], den_baseline + den["desc"], cmds)
