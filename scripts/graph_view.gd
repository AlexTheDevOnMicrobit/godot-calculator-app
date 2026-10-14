extends Control
## Function plotter: grid, axes and labels, curves of up to 6 functions,
## data points, trace cursor, markers (zeros, extrema, intersections) and a
## shaded integral. Pan with a drag, zoom with the wheel / a pinch / a
## trackpad gesture. In trace mode, a drag moves the cursor along a curve.

signal view_changed
signal traced(index: int, x: float)
signal picked(x: float) # tap while a pick (integral bound) is requested

const Evaluator := preload("res://scripts/evaluator.gd")

## One entry per function: { "tokens": Array, "color": Color } (empty tokens = hidden).
var functions: Array = []
## Scatter data: [[x, y], ...] drawn as dots.
var points: PackedVector2Array = []
var points_color := Color(1, 0.6, 0.2)
var markers: Array = [] # [{ "x", "y", "color" }]
var shade := {} # { "index", "a", "b" } integral area
var x_min := -10.0
var x_max := 10.0
var y_min := -10.0
var y_max := 10.0
var trace_enabled := false
var trace_index := 0
var trace_x := 0.0
var picking := false
var axis_color := Color(1, 1, 1, 0.55)
var grid_color := Color(1, 1, 1, 0.07)
var label_color := Color(1, 1, 1, 0.5)
var accent_color := Color.ORANGE

var evaluator := Evaluator.new()

var _samples := {} # function index -> PackedVector2Array (graph coordinates, NAN = gap)
var _samples_key := ""
var _touches := {} # finger index -> position
var _pinch_distance := 0.0
var _dragging := false
var _drag_moved := false
var _press_position := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	evaluator.angle_mode = Evaluator.AngleMode.RAD # graphs are in radians
	resized.connect(queue_redraw)


func set_functions(list: Array) -> void:
	functions = list
	_samples_key = ""
	queue_redraw()


func set_window(new_x_min: float, new_x_max: float, new_y_min: float, new_y_max: float) -> void:
	if new_x_max - new_x_min < 1e-9 or new_y_max - new_y_min < 1e-9:
		return
	if new_x_max - new_x_min > 1e9 or new_y_max - new_y_min > 1e9:
		return
	x_min = new_x_min
	x_max = new_x_max
	y_min = new_y_min
	y_max = new_y_max
	queue_redraw()
	view_changed.emit()


func value_at(index: int, x: float) -> float:
	if index < 0 or index >= functions.size() or functions[index]["tokens"].is_empty():
		return NAN
	return evaluator.evaluate_real(functions[index]["tokens"], x)


# --- Coordinates -----------------------------------------------------------

func to_screen(p: Vector2) -> Vector2:
	return Vector2((p.x - x_min) / (x_max - x_min) * size.x, (y_max - p.y) / (y_max - y_min) * size.y)


func to_graph(s: Vector2) -> Vector2:
	return Vector2(x_min + s.x / size.x * (x_max - x_min), y_max - s.y / size.y * (y_max - y_min))


func _screen_x(x: float) -> float:
	return (x - x_min) / (x_max - x_min) * size.x


func _screen_y(y: float) -> float:
	return (y_max - y) / (y_max - y_min) * size.y


# --- Zoom & pan ------------------------------------------------------------

func zoom(factor: float, center: Vector2 = Vector2(-1, -1)) -> void:
	var c := to_graph(center if center.x >= 0.0 else size / 2.0)
	set_window(c.x + (x_min - c.x) * factor, c.x + (x_max - c.x) * factor,
		c.y + (y_min - c.y) * factor, c.y + (y_max - c.y) * factor)


func pan_pixels(delta: Vector2) -> void:
	var dx := -delta.x / size.x * (x_max - x_min)
	var dy := delta.y / size.y * (y_max - y_min)
	set_window(x_min + dx, x_max + dx, y_min + dy, y_max + dy)


## Standard window, keeping square units when possible.
func zoom_standard() -> void:
	_set_square_window(0.0, 0.0, 10.0)


func zoom_trig() -> void:
	set_window(-2.0 * PI, 2.0 * PI, -4.0, 4.0)


## Square units around (cx, cy), half-width [param half_x] on the x axis.
func _set_square_window(cx: float, cy: float, half_x: float) -> void:
	var ratio := size.y / size.x if size.x > 0.0 else 1.0
	set_window(cx - half_x, cx + half_x, cy - half_x * ratio, cy + half_x * ratio)


## Fits the y range to the visible functions (and the data points).
func zoom_fit() -> void:
	var lo := INF
	var hi := -INF
	for index in functions.size():
		if functions[index]["tokens"].is_empty():
			continue
		for k in 201:
			var x := x_min + (x_max - x_min) * k / 200.0
			var y := value_at(index, x)
			if is_finite(y):
				lo = minf(lo, y)
				hi = maxf(hi, y)
	for p in points:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	if not is_finite(lo) or not is_finite(hi):
		return
	# Ignore extreme values (asymptotes): clamp the range to a sane height.
	if hi - lo < 1e-9:
		lo -= 1.0
		hi += 1.0
	var margin := (hi - lo) * 0.08
	set_window(x_min, x_max, lo - margin, hi + margin)


## Fits both axes to the data points.
func zoom_data() -> void:
	if points.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := (hi - lo).max(Vector2(1.0, 1.0))
	set_window(lo.x - span.x * 0.1, hi.x + span.x * 0.1, lo.y - span.y * 0.15, hi.y + span.y * 0.15)


func _gui_input(event: InputEvent) -> void:
	# Touch: one finger pans (or traces), two fingers pinch-zoom.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_press_position = event.position
			_drag_moved = false
		else:
			_touches.erase(event.index)
			if _touches.is_empty() and not _drag_moved:
				_tap(event.position)
		_pinch_distance = _touch_distance()
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var distance := _touch_distance()
			if _pinch_distance > 0.0 and distance > 0.0:
				zoom(_pinch_distance / distance, _touch_center())
			_pinch_distance = distance
			pan_pixels(event.relative / 2.0)
		elif event.position.distance_to(_press_position) > 6.0 or _drag_moved:
			_drag_moved = true
			if trace_enabled:
				_trace_at(event.position.x)
			else:
				pan_pixels(event.relative)
		accept_event()
	# Mouse (desktop); events emulated from touch are ignored (handled above).
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom(0.85, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom(1.0 / 0.85, event.position)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = true
					_drag_moved = false
					_press_position = event.position
				else:
					_dragging = false
					if not _drag_moved:
						_tap(event.position)
		accept_event()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _dragging:
		if event.position.distance_to(_press_position) > 4.0:
			_drag_moved = true
		if _drag_moved:
			if trace_enabled:
				_trace_at(event.position.x)
			else:
				pan_pixels(event.relative)
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom(1.0 / event.factor, event.position)
		accept_event()
	elif event is InputEventPanGesture:
		pan_pixels(-event.delta * 8.0)
		accept_event()


func _touch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var values := _touches.values()
	return (values[0] as Vector2).distance_to(values[1])


func _touch_center() -> Vector2:
	var values := _touches.values()
	return ((values[0] as Vector2) + (values[1] as Vector2)) / 2.0


func _tap(position: Vector2) -> void:
	if picking:
		picked.emit(to_graph(position).x)
	elif trace_enabled:
		_trace_at(position.x)


func _trace_at(screen_x: float) -> void:
	trace_x = to_graph(Vector2(screen_x, 0.0)).x
	queue_redraw()
	traced.emit(trace_index, trace_x)


func set_trace(x: float) -> void:
	trace_x = x
	queue_redraw()
	traced.emit(trace_index, trace_x)


# --- Drawing ---------------------------------------------------------------

## A "nice" grid step (1, 2 or 5 × 10ⁿ) for about [param target] pixels.
static func nice_step(span: float, pixels: float, target: float = 70.0) -> float:
	if pixels <= 0.0 or span <= 0.0:
		return 1.0
	var raw := span / pixels * target
	var magnitude := pow(10.0, floorf(log(raw) / log(10.0)))
	for factor in [1.0, 2.0, 5.0, 10.0]:
		if raw <= factor * magnitude:
			return factor * magnitude
	return 10.0 * magnitude


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var font := get_theme_default_font()
	var font_size := 11
	var step_x := nice_step(x_max - x_min, size.x)
	var step_y := nice_step(y_max - y_min, size.y)
	# Grid
	var x := ceilf(x_min / step_x) * step_x
	while x <= x_max:
		var sx := _screen_x(x)
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), grid_color, 1.0)
		x += step_x
	var y := ceilf(y_min / step_y) * step_y
	while y <= y_max:
		var sy := _screen_y(y)
		draw_line(Vector2(0, sy), Vector2(size.x, sy), grid_color, 1.0)
		y += step_y
	# Axes (or the nearest edge when the axis is off-screen)
	var axis_y := clampf(_screen_y(0.0), 0.0, size.y - 1.0)
	var axis_x := clampf(_screen_x(0.0), 0.0, size.x - 1.0)
	if y_min <= 0.0 and y_max >= 0.0:
		draw_line(Vector2(0, axis_y), Vector2(size.x, axis_y), axis_color, 1.5)
	if x_min <= 0.0 and x_max >= 0.0:
		draw_line(Vector2(axis_x, 0), Vector2(axis_x, size.y), axis_color, 1.5)
	# Labels
	x = ceilf(x_min / step_x) * step_x
	while x <= x_max:
		if absf(x) > step_x * 0.01:
			var text := _label(x, step_x)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var ly := clampf(axis_y + 14.0, 12.0, size.y - 4.0)
			draw_string(font, Vector2(_screen_x(x) - w / 2.0, ly), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
		x += step_x
	y = ceilf(y_min / step_y) * step_y
	while y <= y_max:
		if absf(y) > step_y * 0.01:
			var text := _label(y, step_y)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var lx := clampf(axis_x - w - 4.0, 2.0, size.x - w - 2.0)
			draw_string(font, Vector2(lx, _screen_y(y) + 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
		y += step_y
	_draw_shade()
	_draw_curves()
	_draw_points()
	_draw_markers(font)
	_draw_trace()


static func _label(value: float, step: float) -> String:
	var decimals := maxi(0, -int(floorf(log(step) / log(10.0))))
	if absf(value) >= 1e6 or (absf(value) < 1e-4 and value != 0.0):
		return Evaluator.format_number(value)
	return String.num(value, decimals)


func _sample_all() -> void:
	var key := "%s|%s|%s|%s|%s|%d" % [x_min, x_max, y_min, y_max, size, functions.size()]
	if key == _samples_key:
		return
	_samples_key = key
	_samples.clear()
	var columns := int(size.x / 1.5) + 2
	for index in functions.size():
		if functions[index]["tokens"].is_empty():
			continue
		var values := PackedVector2Array()
		values.resize(columns + 1)
		for k in columns + 1:
			var gx := x_min + (x_max - x_min) * k / columns
			values[k] = Vector2(gx, value_at(index, gx))
		_samples[index] = values


func _draw_curves() -> void:
	_sample_all()
	var limit := size.y * 4.0
	for index in _samples:
		var color: Color = functions[index]["color"]
		var segment := PackedVector2Array()
		var previous := Vector2(NAN, NAN)
		for p in _samples[index]:
			if not is_finite(p.y):
				_flush(segment, color)
				segment = PackedVector2Array()
				previous = Vector2(NAN, NAN)
				continue
			var s := Vector2(_screen_x(p.x), clampf(_screen_y(p.y), -limit, limit))
			# Asymptote: a huge jump between two neighbours (tan, 1/x...)
			if is_finite(previous.y) and absf(s.y - previous.y) > size.y * 1.5 and (s.y < 0.0 or s.y > size.y or previous.y < 0.0 or previous.y > size.y):
				_flush(segment, color)
				segment = PackedVector2Array()
			segment.append(s)
			previous = s
		_flush(segment, color)


func _flush(segment: PackedVector2Array, color: Color) -> void:
	if segment.size() >= 2:
		draw_polyline(segment, color, 2.5, true)
	elif segment.size() == 1:
		draw_circle(segment[0], 1.5, color)


func _draw_points() -> void:
	for p in points:
		var s := to_screen(p)
		if s.x >= -10.0 and s.x <= size.x + 10.0 and s.y >= -10.0 and s.y <= size.y + 10.0:
			draw_circle(s, 4.5, points_color)


func _draw_shade() -> void:
	if shade.is_empty() or shade["index"] >= functions.size():
		return
	var color: Color = functions[shade["index"]]["color"]
	color.a = 0.25
	var a: float = minf(shade["a"], shade["b"])
	var b: float = maxf(shade["a"], shade["b"])
	var axis := clampf(_screen_y(0.0), -size.y, size.y * 2.0)
	var steps := 160
	for k in steps:
		var x0 := a + (b - a) * k / steps
		var x1 := a + (b - a) * (k + 1) / steps
		var y0 := value_at(shade["index"], x0)
		var y1 := value_at(shade["index"], x1)
		if not is_finite(y0) or not is_finite(y1):
			continue
		var polygon := PackedVector2Array([
			Vector2(_screen_x(x0), axis), Vector2(_screen_x(x0), clampf(_screen_y(y0), -size.y, size.y * 2.0)),
			Vector2(_screen_x(x1), clampf(_screen_y(y1), -size.y, size.y * 2.0)), Vector2(_screen_x(x1), axis)])
		draw_colored_polygon(polygon, color)


func _draw_markers(font: Font) -> void:
	for marker in markers:
		var s := to_screen(Vector2(marker["x"], marker["y"]))
		if s.x < -8.0 or s.x > size.x + 8.0 or s.y < -8.0 or s.y > size.y + 8.0:
			continue
		draw_circle(s, 6.0, marker.get("color", accent_color))
		draw_circle(s, 3.0, Color.WHITE)


func _draw_trace() -> void:
	if not trace_enabled or trace_index >= functions.size() or functions[trace_index]["tokens"].is_empty():
		return
	var y := value_at(trace_index, trace_x)
	var sx := _screen_x(trace_x)
	draw_line(Vector2(sx, 0), Vector2(sx, size.y), Color(accent_color, 0.35), 1.0)
	if is_finite(y):
		var s := Vector2(sx, _screen_y(y))
		draw_line(Vector2(0, s.y), Vector2(size.x, s.y), Color(accent_color, 0.35), 1.0)
		draw_circle(s, 7.0, functions[trace_index]["color"])
		draw_circle(s, 3.5, Color.WHITE)


# --- Analysis --------------------------------------------------------------

## x where f changes sign in the visible window (bisection on each change).
func find_zeros(index: int, a: float = NAN, b: float = NAN) -> Array:
	return _roots(func(x): return value_at(index, x), x_min if is_nan(a) else a, x_max if is_nan(b) else b)


## Intersections of two functions in the visible window: [[x, y], ...]
func find_intersections(i: int, j: int) -> Array:
	var result := []
	for x in _roots(func(v): return value_at(i, v) - value_at(j, v), x_min, x_max):
		result.append([x, value_at(i, x)])
	return result


## Local minima (or maxima) in the visible window: [[x, y], ...]
func find_extrema(index: int, maximum: bool) -> Array:
	var sign := -1.0 if maximum else 1.0
	var f := func(x): return sign * value_at(index, x)
	var n := 400
	var xs := []
	var ys := []
	for k in n + 1:
		var x := x_min + (x_max - x_min) * k / n
		xs.append(x)
		ys.append(f.call(x))
	var result := []
	for k in range(1, n):
		var y0: float = ys[k - 1]
		var y1: float = ys[k]
		var y2: float = ys[k + 1]
		if is_finite(y0) and is_finite(y1) and is_finite(y2) and y1 <= y0 and y1 < y2:
			var x := Evaluator.golden_section(f, xs[k - 1], xs[k + 1])
			var y := value_at(index, x)
			if is_finite(y) and absf(y) < 1e12:
				result.append([x, y])
	return result


func _roots(f: Callable, a: float, b: float) -> Array:
	var n := 400
	var result := []
	var previous_x := a
	var previous_y: float = f.call(a)
	for k in range(1, n + 1):
		var x := a + (b - a) * k / n
		var y: float = f.call(x)
		if is_finite(previous_y) and is_finite(y):
			if previous_y == 0.0:
				_add_root(result, previous_x)
			elif previous_y * y < 0.0:
				var root := Evaluator.bisect(f, previous_x, x)
				# A sign change through an asymptote (1/x) is not a zero.
				if absf(f.call(root)) < 1e-6 * maxf(1.0, maxf(absf(previous_y), absf(y))):
					_add_root(result, root)
		previous_x = x
		previous_y = y
	if is_finite(previous_y) and previous_y == 0.0:
		_add_root(result, previous_x)
	return result


static func _add_root(list: Array, x: float) -> void:
	var snapped := roundf(x) if absf(x - roundf(x)) < 1e-9 else x
	if list.is_empty() or absf(list[-1] - snapped) > 1e-9:
		list.append(snapped)
