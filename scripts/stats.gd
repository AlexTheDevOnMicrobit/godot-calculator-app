extends RefCounted
## Statistics: one- and two-variable summaries and regressions (like the
## 1-Var Stats, 2-Var Stats and *Reg commands of a TI-84).

## Regression kinds: id -> [equation shown, needs x > 0, needs y > 0]
const REGRESSIONS := {
	"linear": ["y = ax + b", false, false],
	"quadratic": ["y = ax² + bx + c", false, false],
	"exponential": ["y = a·bˣ", false, true],
	"power": ["y = a·xᵇ", true, true],
	"logarithmic": ["y = a + b·ln x", true, false],
}


## n, mean, Σx, Σx², Sx (sample), σx (population), min, Q1, median, Q3, max.
static func one_var(xs: PackedFloat64Array) -> Dictionary:
	var n := xs.size()
	if n == 0:
		return {}
	var total := 0.0
	var squares := 0.0
	for x in xs:
		total += x
		squares += x * x
	var mean := total / n
	var deviation := 0.0
	for x in xs:
		deviation += (x - mean) * (x - mean)
	var sorted := Array(xs)
	sorted.sort()
	var lower := sorted.slice(0, n / 2)
	var upper := sorted.slice((n + 1) / 2, n)
	return {
		"n": n, "mean": mean, "sum": total, "sum_squares": squares,
		"sx": sqrt(deviation / (n - 1)) if n > 1 else NAN,
		"sigma": sqrt(deviation / n),
		"min": sorted[0], "q1": _median(lower) if not lower.is_empty() else sorted[0],
		"median": _median(sorted), "q3": _median(upper) if not upper.is_empty() else sorted[-1],
		"max": sorted[-1],
	}


static func _median(sorted: Array) -> float:
	var n := sorted.size()
	if n % 2 == 1:
		return sorted[n / 2]
	return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0


## Two-variable summary: means, sums, standard deviations, Σxy, r.
static func two_var(xs: PackedFloat64Array, ys: PackedFloat64Array) -> Dictionary:
	var n := mini(xs.size(), ys.size())
	if n == 0:
		return {}
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for k in n:
		sx += xs[k]
		sy += ys[k]
		sxx += xs[k] * xs[k]
		syy += ys[k] * ys[k]
		sxy += xs[k] * ys[k]
	var mx := sx / n
	var my := sy / n
	var vx := sxx - n * mx * mx
	var vy := syy - n * my * my
	var cov := sxy - n * mx * my
	return {
		"n": n, "mean_x": mx, "mean_y": my, "sum_x": sx, "sum_y": sy,
		"sum_x2": sxx, "sum_y2": syy, "sum_xy": sxy,
		"sx": sqrt(vx / (n - 1)) if n > 1 else NAN, "sy": sqrt(vy / (n - 1)) if n > 1 else NAN,
		"r": cov / sqrt(vx * vy) if vx > 0.0 and vy > 0.0 else NAN,
	}


## Fits a regression. Returns { "ok", "coefficients": {a, b, c?}, "r2", "r"?,
## "expression" (in x, for the graph) } or { "ok": false, "error" }.
static func regression(kind: String, xs: PackedFloat64Array, ys: PackedFloat64Array) -> Dictionary:
	var n := mini(xs.size(), ys.size())
	var needs: Array = REGRESSIONS[kind]
	if n < (3 if kind == "quadratic" else 2):
		return { "ok": false, "error": "STATS_NOT_ENOUGH" }
	var tx := PackedFloat64Array()
	var ty := PackedFloat64Array()
	for k in n:
		if (needs[1] and xs[k] <= 0.0) or (needs[2] and ys[k] <= 0.0):
			return { "ok": false, "error": "STATS_POSITIVE" }
		tx.append(log(xs[k]) if kind in ["power", "logarithmic"] else xs[k])
		ty.append(log(ys[k]) if kind in ["exponential", "power"] else ys[k])
	var result := {}
	match kind:
		"quadratic":
			var c := _polyfit2(tx, ty)
			if c.is_empty():
				return { "ok": false, "error": "STATS_SINGULAR" }
			result = { "a": c[2], "b": c[1], "c": c[0] }
		_:
			var fit := _linear_fit(tx, ty)
			if fit.is_empty():
				return { "ok": false, "error": "STATS_SINGULAR" }
			match kind:
				"linear":
					result = { "a": fit[0], "b": fit[1] }
				"exponential": # ln y = ln a + x ln b
					result = { "a": exp(fit[1]), "b": exp(fit[0]) }
				"power": # ln y = ln a + b ln x
					result = { "a": exp(fit[1]), "b": fit[0] }
				"logarithmic": # y = a + b ln x
					result = { "a": fit[1], "b": fit[0] }
	var expression := expression_of(kind, result)
	# r² on the original data (TI reports it on the transformed data for
	# exp / pwr; on the original data here, which is what users compare).
	var evaluator = preload("res://scripts/evaluator.gd").new()
	evaluator.angle_mode = 1
	var tokens: Array = evaluator.compile(expression)["tokens"]
	var mean_y := 0.0
	for k in n:
		mean_y += ys[k]
	mean_y /= n
	var ss_res := 0.0
	var ss_tot := 0.0
	for k in n:
		var predicted: float = evaluator.evaluate_real(tokens, xs[k])
		ss_res += (ys[k] - predicted) * (ys[k] - predicted)
		ss_tot += (ys[k] - mean_y) * (ys[k] - mean_y)
	var answer := { "ok": true, "coefficients": result, "expression": expression,
		"r2": 1.0 - ss_res / ss_tot if ss_tot > 0.0 else 1.0 }
	if kind == "linear":
		answer["r"] = two_var(xs, ys)["r"]
	return answer


## Expression of the fitted curve, in the calculator syntax (variable x).
static func expression_of(kind: String, c: Dictionary) -> String:
	var a := _num(c["a"])
	var b := _num(c["b"])
	match kind:
		"linear":
			return "%s×x%s" % [a, _signed(c["b"])]
		"quadratic":
			return "%s×x^2%s×x%s" % [a, _signed(c["b"]), _signed(c["c"])]
		"exponential":
			return "%s×%s^x" % [a, b]
		"power":
			return "%s×x^%s" % [a, b]
		"logarithmic":
			return "%s%s×ln(x)" % [a, _signed(c["b"])]
	return ""


## "+2" / "−0.5": a coefficient after another term.
static func _signed(v: float) -> String:
	var text := _num(absf(v))
	return ("−" if v < 0.0 else "+") + text


static func _num(v: float) -> String:
	var text := String.num(v, 12)
	if text.begins_with("-"):
		return "(" + text.replace("-", "−") + ")"
	if text.contains("e"):
		return "(" + text + ")"
	return text


## Least squares y = slope·x + intercept. Returns [slope, intercept].
static func _linear_fit(xs: PackedFloat64Array, ys: PackedFloat64Array) -> Array:
	var n := xs.size()
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	for k in n:
		sx += xs[k]
		sy += ys[k]
		sxx += xs[k] * xs[k]
		sxy += xs[k] * ys[k]
	var d := n * sxx - sx * sx
	if absf(d) < 1e-300:
		return []
	var slope := (n * sxy - sx * sy) / d
	return [slope, (sy - slope * sx) / n]


## Least squares y = c0 + c1·x + c2·x² (normal equations, Gaussian elimination).
static func _polyfit2(xs: PackedFloat64Array, ys: PackedFloat64Array) -> Array:
	var s := PackedFloat64Array([0, 0, 0, 0, 0])
	var t := PackedFloat64Array([0, 0, 0])
	for k in xs.size():
		var p := 1.0
		for j in 5:
			s[j] += p
			if j < 3:
				t[j] += p * ys[k]
			p *= xs[k]
	var m := [[s[0], s[1], s[2], t[0]], [s[1], s[2], s[3], t[1]], [s[2], s[3], s[4], t[2]]]
	return solve_linear(m)


## Solves an augmented n×(n+1) system (partial pivoting). [] if singular.
static func solve_linear(m: Array) -> Array:
	var n := m.size()
	for col in n:
		var pivot := col
		for row in range(col + 1, n):
			if absf(m[row][col]) > absf(m[pivot][col]):
				pivot = row
		if absf(m[pivot][col]) < 1e-12:
			return []
		var tmp = m[col]
		m[col] = m[pivot]
		m[pivot] = tmp
		for row in range(col + 1, n):
			var factor: float = m[row][col] / m[col][col]
			for k in range(col, n + 1):
				m[row][k] -= factor * m[col][k]
	var x := []
	x.resize(n)
	for row in range(n - 1, -1, -1):
		var total: float = m[row][n]
		for k in range(row + 1, n):
			total -= m[row][k] * x[k]
		x[row] = total / m[row][row]
	return x
