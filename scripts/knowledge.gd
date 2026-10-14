extends RefCounted
## Content of the "Basic knowledge" page: number tables (generated), constants,
## formulas (written in the calculator's expression syntax and drawn by
## math_view.gd) and short rules. Texts are translation keys (tr()).

const PI_DIGITS := "3.14159265358979323846264338327950288419716939937510"
const E_DIGITS := "2.71828182845904523536028747135266249775724709369995"

## Section ids in display order.
const SECTIONS := [
	"squares", "cubes", "primes", "pi", "constants", "powers2", "factorials",
	"trig", "algebra", "geometry", "divisibility", "prefixes",
]

## Section id -> title translation key.
const TITLES := {
	"squares": "KB_SQUARES", "cubes": "KB_CUBES", "primes": "KB_PRIMES", "pi": "KB_PI",
	"constants": "KB_CONSTANTS", "powers2": "KB_POWERS2", "factorials": "KB_FACTORIALS",
	"trig": "KB_TRIG", "algebra": "KB_ALGEBRA", "geometry": "KB_GEOMETRY",
	"divisibility": "KB_DIVISIBILITY", "prefixes": "KB_PREFIXES",
}

## Section id -> note translation key.
const NOTES := {
	"squares": "KB_NOTE_SQUARES", "primes": "KB_NOTE_PRIMES", "pi": "KB_NOTE_PI",
	"factorials": "KB_NOTE_FACTORIALS",
}

const PI_MNEMONIC := "KB_PI_MNEMONIC"

## [symbol, value inserted, name translation key]
const CONSTANTS := [
	["π", "π", "KB_C_PI"],
	["e", "e", "KB_C_E"],
	["φ", "φ", "KB_C_PHI"],
	["√2", "√(2)", "KB_C_SQRT2"],
	["√3", "√(3)", "KB_C_SQRT3"],
	["ln 2", "ln(2)", "KB_C_LN2"],
]

## Angle (degrees), sin, cos, tan — exact values.
const TRIG := [
	["0°", "0", "1", "0"],
	["30°", "frac(1;2)", "frac(√(3);2)", "frac(√(3);3)"],
	["45°", "frac(√(2);2)", "frac(√(2);2)", "1"],
	["60°", "frac(√(3);2)", "frac(1;2)", "√(3)"],
	["90°", "1", "0", "—"],
]

## Formulas: [expression, caption translation key]
const ALGEBRA := [
	["(a+b)^2=a^2+2ab+b^2", "KB_F_SUM2"],
	["(a−b)^2=a^2−2ab+b^2", "KB_F_DIFF2"],
	["(a+b)(a−b)=a^2−b^2", "KB_F_SQUARES"],
	["Δ=b^2−4ac", "KB_F_DELTA"],
	["x=frac(−b±√(Δ);2a)", "KB_F_ROOTS"],
	["a^(m)×a^(n)=a^(m+n)", "KB_F_POWERS"],
	["sin^2(x)+cos^2(x)=1", "KB_F_PYTHAGOREAN_ID"],
]

const GEOMETRY := [
	["a^2+b^2=c^2", "KB_F_PYTHAGORAS"],
	["A=πr^2", "KB_F_DISC"],
	["P=2πr", "KB_F_CIRCLE"],
	["A=frac(b×h;2)", "KB_F_TRIANGLE"],
	["A=L×l", "KB_F_RECTANGLE"],
	["V=frac(4;3)πr^3", "KB_F_SPHERE"],
	["V=πr^2h", "KB_F_CYLINDER"],
]

## [divisor, rule translation key] — shown with KB_DIV_FORMAT.
const DIVISIBILITY := [
	["2", "KB_DIV_2"], ["3", "KB_DIV_3"], ["4", "KB_DIV_4"], ["5", "KB_DIV_5"],
	["9", "KB_DIV_9"], ["10", "KB_DIV_10"], ["11", "KB_DIV_11"],
]

## [symbol, name, power of ten] (SI names are the same in every language).
const PREFIXES := [
	["T", "tera", 12], ["G", "giga", 9], ["M", "mega", 6], ["k", "kilo", 3],
	["h", "hecto", 2], ["da", "deca", 1], ["d", "deci", -1], ["c", "centi", -2],
	["m", "milli", -3], ["µ", "micro", -6], ["n", "nano", -9], ["p", "pico", -12],
]


## Prime numbers below [param limit] (sieve of Eratosthenes).
static func primes_below(limit: int) -> PackedInt32Array:
	var composite := PackedByteArray()
	composite.resize(limit)
	var primes := PackedInt32Array()
	for n in range(2, limit):
		if composite[n] == 0:
			primes.append(n)
			for multiple in range(n * n, limit, n):
				composite[multiple] = 1
	return primes


static func factorial(n: int) -> int:
	var result := 1
	for i in range(2, n + 1):
		result *= i
	return result


## Digits of a whole number grouped by three ("1 307 674 368 000").
static func grouped(value: int, separator: String) -> String:
	var digits := str(value)
	var out := ""
	while digits.length() > 3:
		out = separator + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return digits + out
