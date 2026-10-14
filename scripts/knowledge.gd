extends RefCounted
## Content of the "Basic knowledge" page: number tables (generated), constants,
## formulas (written in the calculator's expression syntax and drawn by
## math_view.gd) and short rules, in English and French.

const PI_DIGITS := "3.14159265358979323846264338327950288419716939937510"
const E_DIGITS := "2.71828182845904523536028747135266249775724709369995"

## Section ids in display order.
const SECTIONS := [
	"squares", "cubes", "primes", "pi", "constants", "powers2", "factorials",
	"trig", "identities", "geometry", "divisibility", "prefixes",
]

const TITLES := {
	"squares": ["Perfect squares", "Carrés parfaits"],
	"cubes": ["Perfect cubes", "Cubes parfaits"],
	"primes": ["Prime numbers (under 200)", "Nombres premiers (moins de 200)"],
	"pi": ["Pi (π)", "Pi (π)"],
	"constants": ["Useful constants", "Constantes utiles"],
	"powers2": ["Powers of 2", "Puissances de 2"],
	"factorials": ["Factorials", "Factorielles"],
	"trig": ["Trigonometric values", "Valeurs trigonométriques"],
	"identities": ["Algebra", "Algèbre"],
	"geometry": ["Geometry", "Géométrie"],
	"divisibility": ["Divisibility rules", "Critères de divisibilité"],
	"prefixes": ["Unit prefixes", "Préfixes des unités"],
}

const NOTES := {
	"squares": ["n² = n × n. Tap a value to use it.", "n² = n × n. Touchez une valeur pour l'utiliser."],
	"primes": ["A prime number has exactly two divisors: 1 and itself.",
		"Un nombre premier a exactement deux diviseurs : 1 et lui-même."],
	"pi": ["Ratio of a circle's circumference to its diameter. Mnemonic (letters per word = digits):",
		"Rapport entre le périmètre d'un cercle et son diamètre. Moyen mnémotechnique (lettres par mot = chiffres) :"],
	"factorials": ["n! = 1 × 2 × … × n, and 0! = 1.", "n! = 1 × 2 × … × n, et 0! = 1."],
}

const PI_MNEMONIC := [
	"How I want a drink, alcoholic of course, after the heavy lectures involving quantum mechanics.",
	"Que j'aime à faire apprendre un nombre utile aux sages ! Immortel Archimède, artiste ingénieur…",
]

## [symbol, value inserted, English name, French name]
const CONSTANTS := [
	["π", "π", "Pi", "Pi"],
	["e", "e", "Euler's number", "Nombre d'Euler"],
	["φ", "φ", "Golden ratio", "Nombre d'or"],
	["√2", "√(2)", "Square root of 2", "Racine de 2"],
	["√3", "√(3)", "Square root of 3", "Racine de 3"],
	["ln 2", "ln(2)", "Natural log of 2", "Logarithme népérien de 2"],
]

## Angle (degrees), sin, cos, tan — exact values.
const TRIG := [
	["0°", "0", "1", "0"],
	["30°", "frac(1;2)", "frac(√(3);2)", "frac(√(3);3)"],
	["45°", "frac(√(2);2)", "frac(√(2);2)", "1"],
	["60°", "frac(√(3);2)", "frac(1;2)", "√(3)"],
	["90°", "1", "0", "—"],
]

## Formulas: [expression, English caption, French caption]
const IDENTITIES := [
	["(a+b)^2=a^2+2ab+b^2", "Square of a sum", "Carré d'une somme"],
	["(a−b)^2=a^2−2ab+b^2", "Square of a difference", "Carré d'une différence"],
	["(a+b)(a−b)=a^2−b^2", "Difference of squares", "Différence de deux carrés"],
	["Δ=b^2−4ac", "Discriminant of ax² + bx + c", "Discriminant de ax² + bx + c"],
	["x=frac(−b±√(Δ);2a)", "Roots of ax² + bx + c = 0", "Solutions de ax² + bx + c = 0"],
	["a^(m)×a^(n)=a^(m+n)", "Product of powers", "Produit de puissances"],
	["sin^2(x)+cos^2(x)=1", "Pythagorean identity", "Identité de Pythagore"],
]

const GEOMETRY := [
	["a^2+b^2=c^2", "Pythagoras (right triangle)", "Pythagore (triangle rectangle)"],
	["A=πr^2", "Area of a disc", "Aire d'un disque"],
	["P=2πr", "Circumference of a circle", "Périmètre d'un cercle"],
	["A=frac(b×h;2)", "Area of a triangle", "Aire d'un triangle"],
	["A=L×l", "Area of a rectangle", "Aire d'un rectangle"],
	["V=frac(4;3)πr^3", "Volume of a sphere", "Volume d'une boule"],
	["V=πr^2h", "Volume of a cylinder", "Volume d'un cylindre"],
]

const DIVISIBILITY := [
	["2", "the last digit is even (0, 2, 4, 6, 8)", "le dernier chiffre est pair (0, 2, 4, 6, 8)"],
	["3", "the sum of the digits is divisible by 3", "la somme des chiffres est divisible par 3"],
	["4", "the last two digits form a multiple of 4", "les deux derniers chiffres forment un multiple de 4"],
	["5", "the last digit is 0 or 5", "le dernier chiffre est 0 ou 5"],
	["9", "the sum of the digits is divisible by 9", "la somme des chiffres est divisible par 9"],
	["10", "the last digit is 0", "le dernier chiffre est 0"],
	["11", "the alternating sum of the digits is divisible by 11", "la somme alternée des chiffres est divisible par 11"],
]

## [symbol, name, power of ten]
const PREFIXES := [
	["T", "tera", 12], ["G", "giga", 9], ["M", "mega / méga", 6], ["k", "kilo", 3],
	["h", "hecto", 2], ["da", "deca / déca", 1], ["d", "deci / déci", -1], ["c", "centi", -2],
	["m", "milli", -3], ["µ", "micro", -6], ["n", "nano", -9], ["p", "pico", -12],
]


static func text(pair: Array, language: String) -> String:
	return pair[1] if language == "fr" and pair.size() > 1 else pair[0]


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
