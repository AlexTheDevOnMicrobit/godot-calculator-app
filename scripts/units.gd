extends RefCounted
## Unit definitions for the Converter mode.
## Each unit: [symbol, name translation key, factor to the category's base
## unit]. Temperature uses offsets (see convert()). Names are translated with
## tr() (translations/translations.csv).

const CATEGORIES := {
	"length": { "name": "CAT_LENGTH", "units": [
		["mm", "U_MM", 0.001],
		["cm", "U_CM", 0.01],
		["m", "U_M", 1.0],
		["km", "U_KM", 1000.0],
		["in", "U_IN", 0.0254],
		["ft", "U_FT", 0.3048],
		["yd", "U_YD", 0.9144],
		["mi", "U_MI", 1609.344],
		["nmi", "U_NMI", 1852.0],
	] },
	"mass": { "name": "CAT_MASS", "units": [
		["mg", "U_MG", 0.000001],
		["g", "U_G", 0.001],
		["kg", "U_KG", 1.0],
		["t", "U_T", 1000.0],
		["oz", "U_OZ", 0.028349523125],
		["lb", "U_LB", 0.45359237],
		["st", "U_ST", 6.35029318],
	] },
	"temperature": { "name": "CAT_TEMPERATURE", "units": [
		["°C", "U_C", 1.0],
		["°F", "U_F", 1.0],
		["K", "U_K", 1.0],
	] },
	"area": { "name": "CAT_AREA", "units": [
		["mm²", "U_MM2", 0.000001],
		["cm²", "U_CM2", 0.0001],
		["m²", "U_M2", 1.0],
		["a", "U_A", 100.0],
		["ha", "U_HA", 10000.0],
		["km²", "U_KM2", 1000000.0],
		["in²", "U_IN2", 0.00064516],
		["ft²", "U_FT2", 0.09290304],
		["ac", "U_AC", 4046.8564224],
	] },
	"volume": { "name": "CAT_VOLUME", "units": [
		["mL", "U_ML", 0.001],
		["cL", "U_CL", 0.01],
		["L", "U_L", 1.0],
		["m³", "U_M3", 1000.0],
		["tsp", "U_TSP", 0.00492892159375],
		["tbsp", "U_TBSP", 0.01478676478125],
		["cup", "U_CUP", 0.2365882365],
		["fl oz", "U_FLOZ", 0.0295735295625],
		["gal", "U_GAL", 3.785411784],
		["gal UK", "U_GALUK", 4.54609],
	] },
	"speed": { "name": "CAT_SPEED", "units": [
		["m/s", "U_MPS", 1.0],
		["km/h", "U_KMH", 1.0 / 3.6],
		["mph", "U_MPH", 0.44704],
		["kn", "U_KN", 1852.0 / 3600.0],
		["ft/s", "U_FPS", 0.3048],
	] },
	"time": { "name": "CAT_TIME", "units": [
		["ms", "U_MSEC", 0.001],
		["s", "U_S", 1.0],
		["min", "U_MIN", 60.0],
		["h", "U_H", 3600.0],
		["d", "U_D", 86400.0],
		["wk", "U_WK", 604800.0],
		["yr", "U_YR", 31557600.0],
	] },
	"data": { "name": "CAT_DATA", "units": [
		["bit", "U_BIT", 0.125],
		["B", "U_BYTE", 1.0],
		["kB", "U_KB", 1000.0],
		["MB", "U_MB", 1000000.0],
		["GB", "U_GB", 1000000000.0],
		["TB", "U_TB", 1000000000000.0],
		["KiB", "U_KIB", 1024.0],
		["MiB", "U_MIB", 1048576.0],
		["GiB", "U_GIB", 1073741824.0],
	] },
	"angle": { "name": "CAT_ANGLE", "units": [
		["°", "U_DEG", PI / 180.0],
		["rad", "U_RAD", 1.0],
		["grad", "U_GRAD", PI / 200.0],
		["tr", "U_TURN", TAU],
	] },
	"energy": { "name": "CAT_ENERGY", "units": [
		["J", "U_J", 1.0],
		["kJ", "U_KJ", 1000.0],
		["cal", "U_CAL", 4.184],
		["kcal", "U_KCAL", 4184.0],
		["Wh", "U_WH", 3600.0],
		["kWh", "U_KWH", 3600000.0],
	] },
	"pressure": { "name": "CAT_PRESSURE", "units": [
		["Pa", "U_PA", 1.0],
		["kPa", "U_KPA", 1000.0],
		["bar", "U_BAR", 100000.0],
		["atm", "U_ATM", 101325.0],
		["psi", "U_PSI", 6894.757293168],
		["mmHg", "U_MMHG", 133.322387415],
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


static func category_name_key(category: String) -> String:
	return CATEGORIES[category]["name"]


## Translation key of the unit's name.
static func unit_name_key(category: String, index: int) -> String:
	return CATEGORIES[category]["units"][index][1]


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
	return value * units[from][2] / units[to][2]
