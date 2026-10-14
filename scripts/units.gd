extends RefCounted
## Unit definitions for the Converter mode.
## Each unit: [symbol, english name, french name, factor to the category's
## base unit]. Temperature uses offsets (see convert()).

const CATEGORIES := {
	"length": { "en": "Length", "fr": "Longueur", "units": [
		["mm", "Millimeter", "Millimètre", 0.001],
		["cm", "Centimeter", "Centimètre", 0.01],
		["m", "Meter", "Mètre", 1.0],
		["km", "Kilometer", "Kilomètre", 1000.0],
		["in", "Inch", "Pouce", 0.0254],
		["ft", "Foot", "Pied", 0.3048],
		["yd", "Yard", "Yard", 0.9144],
		["mi", "Mile", "Mile", 1609.344],
		["nmi", "Nautical mile", "Mille marin", 1852.0],
	] },
	"mass": { "en": "Mass", "fr": "Masse", "units": [
		["mg", "Milligram", "Milligramme", 0.000001],
		["g", "Gram", "Gramme", 0.001],
		["kg", "Kilogram", "Kilogramme", 1.0],
		["t", "Tonne", "Tonne", 1000.0],
		["oz", "Ounce", "Once", 0.028349523125],
		["lb", "Pound", "Livre", 0.45359237],
		["st", "Stone", "Stone", 6.35029318],
	] },
	"temperature": { "en": "Temperature", "fr": "Température", "units": [
		["°C", "Celsius", "Celsius", 1.0],
		["°F", "Fahrenheit", "Fahrenheit", 1.0],
		["K", "Kelvin", "Kelvin", 1.0],
	] },
	"area": { "en": "Area", "fr": "Surface", "units": [
		["mm²", "Square millimeter", "Millimètre carré", 0.000001],
		["cm²", "Square centimeter", "Centimètre carré", 0.0001],
		["m²", "Square meter", "Mètre carré", 1.0],
		["a", "Are", "Are", 100.0],
		["ha", "Hectare", "Hectare", 10000.0],
		["km²", "Square kilometer", "Kilomètre carré", 1000000.0],
		["in²", "Square inch", "Pouce carré", 0.00064516],
		["ft²", "Square foot", "Pied carré", 0.09290304],
		["ac", "Acre", "Acre", 4046.8564224],
	] },
	"volume": { "en": "Volume", "fr": "Volume", "units": [
		["mL", "Milliliter", "Millilitre", 0.001],
		["cL", "Centiliter", "Centilitre", 0.01],
		["L", "Liter", "Litre", 1.0],
		["m³", "Cubic meter", "Mètre cube", 1000.0],
		["tsp", "Teaspoon (US)", "Cuillère à café (US)", 0.00492892159375],
		["tbsp", "Tablespoon (US)", "Cuillère à soupe (US)", 0.01478676478125],
		["cup", "Cup (US)", "Tasse (US)", 0.2365882365],
		["fl oz", "Fluid ounce (US)", "Once liquide (US)", 0.0295735295625],
		["gal", "Gallon (US)", "Gallon (US)", 3.785411784],
		["gal UK", "Gallon (UK)", "Gallon (UK)", 4.54609],
	] },
	"speed": { "en": "Speed", "fr": "Vitesse", "units": [
		["m/s", "Meter per second", "Mètre par seconde", 1.0],
		["km/h", "Kilometer per hour", "Kilomètre par heure", 1.0 / 3.6],
		["mph", "Mile per hour", "Mile par heure", 0.44704],
		["kn", "Knot", "Nœud", 1852.0 / 3600.0],
		["ft/s", "Foot per second", "Pied par seconde", 0.3048],
	] },
	"time": { "en": "Time", "fr": "Temps", "units": [
		["ms", "Millisecond", "Milliseconde", 0.001],
		["s", "Second", "Seconde", 1.0],
		["min", "Minute", "Minute", 60.0],
		["h", "Hour", "Heure", 3600.0],
		["d", "Day", "Jour", 86400.0],
		["wk", "Week", "Semaine", 604800.0],
		["yr", "Year (365.25 d)", "Année (365,25 j)", 31557600.0],
	] },
	"data": { "en": "Data", "fr": "Données", "units": [
		["bit", "Bit", "Bit", 0.125],
		["B", "Byte", "Octet", 1.0],
		["kB", "Kilobyte", "Kilooctet", 1000.0],
		["MB", "Megabyte", "Mégaoctet", 1000000.0],
		["GB", "Gigabyte", "Gigaoctet", 1000000000.0],
		["TB", "Terabyte", "Téraoctet", 1000000000000.0],
		["KiB", "Kibibyte", "Kibioctet", 1024.0],
		["MiB", "Mebibyte", "Mébioctet", 1048576.0],
		["GiB", "Gibibyte", "Gibioctet", 1073741824.0],
	] },
	"angle": { "en": "Angle", "fr": "Angle", "units": [
		["°", "Degree", "Degré", PI / 180.0],
		["rad", "Radian", "Radian", 1.0],
		["grad", "Gradian", "Grade", PI / 200.0],
		["tr", "Turn", "Tour", TAU],
	] },
	"energy": { "en": "Energy", "fr": "Énergie", "units": [
		["J", "Joule", "Joule", 1.0],
		["kJ", "Kilojoule", "Kilojoule", 1000.0],
		["cal", "Calorie", "Calorie", 4.184],
		["kcal", "Kilocalorie", "Kilocalorie", 4184.0],
		["Wh", "Watt-hour", "Wattheure", 3600.0],
		["kWh", "Kilowatt-hour", "Kilowattheure", 3600000.0],
	] },
	"pressure": { "en": "Pressure", "fr": "Pression", "units": [
		["Pa", "Pascal", "Pascal", 1.0],
		["kPa", "Kilopascal", "Kilopascal", 1000.0],
		["bar", "Bar", "Bar", 100000.0],
		["atm", "Atmosphere", "Atmosphère", 101325.0],
		["psi", "Pound per sq. inch", "Livre par pouce carré", 6894.757293168],
		["mmHg", "Millimeter of mercury", "Millimètre de mercure", 133.322387415],
	] },
}

## Default "from" / "to" units (indices) for each category.
const DEFAULTS := {
	"length": [2, 3], "mass": [2, 5], "temperature": [0, 1], "area": [2, 4],
	"volume": [2, 6], "speed": [1, 2], "time": [3, 2], "data": [3, 4],
	"angle": [0, 1], "energy": [3, 1], "pressure": [2, 3],
}


static func category_ids() -> Array:
	return CATEGORIES.keys()


static func unit_count(category: String) -> int:
	return CATEGORIES[category]["units"].size()


static func category_name(category: String, language: String) -> String:
	return CATEGORIES[category][language]


static func unit_label(category: String, index: int, language: String) -> String:
	var unit: Array = CATEGORIES[category]["units"][index]
	return "%s — %s" % [unit[0], unit[2] if language == "fr" else unit[1]]


static func unit_symbol(category: String, index: int) -> String:
	return CATEGORIES[category]["units"][index][0]


## Converts [param value] from unit [param from] to unit [param to].
static func convert(category: String, value: float, from: int, to: int) -> float:
	var units: Array = CATEGORIES[category]["units"]
	if category == "temperature":
		var kelvin: float = value
		match units[from][0]:
			"°C":
				kelvin = value + 273.15
			"°F":
				kelvin = (value - 32.0) * 5.0 / 9.0 + 273.15
		match units[to][0]:
			"°C":
				return kelvin - 273.15
			"°F":
				return (kelvin - 273.15) * 9.0 / 5.0 + 32.0
		return kelvin
	return value * units[from][3] / units[to][3]
