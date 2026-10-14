extends RefCounted
## User preferences, memory and history, persisted in a ConfigFile.

enum ThemeMode { AUTO, DARK, LIGHT }

const DEFAULT_PATH := "user://settings.cfg"
const MODES := ["simple", "scientific", "programmer", "converter"]
const LANGUAGES := ["en", "fr", "es", "de", "it", "pt"]
## Precision setting: -1 = automatic, otherwise number of decimals.
const PRECISIONS := [-1, 2, 4, 6, 8]

var path := DEFAULT_PATH
var language := "en"
var mode := "scientific"
var angle_mode := 0 # Evaluator.AngleMode
var theme_mode: ThemeMode = ThemeMode.AUTO
var precision := -1
var sound := true
var vibration := true
var memory := 0.0
var last_answer := 0.0
var history: Array = [] # Array of { "expr": String, "value": float }
var programmer_base := 10
var converter := {} # ConverterView state


func load_settings() -> void:
	var os_language := OS.get_locale_language() if OS.get_locale_language() in LANGUAGES else "en"
	var config := ConfigFile.new()
	if config.load(path) != OK:
		language = os_language
		return
	language = config.get_value("app", "language", os_language)
	if language not in LANGUAGES:
		language = os_language
	mode = config.get_value("app", "mode", "scientific")
	if mode not in MODES:
		mode = "scientific"
	angle_mode = int(config.get_value("app", "angle_mode", 0))
	theme_mode = clampi(int(config.get_value("app", "theme_mode", ThemeMode.AUTO)), 0, 2) as ThemeMode
	precision = int(config.get_value("app", "precision", -1))
	if precision not in PRECISIONS:
		precision = -1
	sound = bool(config.get_value("app", "sound", true))
	vibration = bool(config.get_value("app", "vibration", true))
	memory = float(config.get_value("app", "memory", 0.0))
	last_answer = float(config.get_value("app", "last_answer", 0.0))
	var saved_history = config.get_value("app", "history", [])
	history = saved_history if saved_history is Array else []
	programmer_base = int(config.get_value("programmer", "base", 10))
	if programmer_base not in [2, 8, 10, 16]:
		programmer_base = 10
	var saved_converter = config.get_value("converter", "state", {})
	converter = saved_converter if saved_converter is Dictionary else {}


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("app", "language", language)
	config.set_value("app", "mode", mode)
	config.set_value("app", "angle_mode", angle_mode)
	config.set_value("app", "theme_mode", theme_mode)
	config.set_value("app", "precision", precision)
	config.set_value("app", "sound", sound)
	config.set_value("app", "vibration", vibration)
	config.set_value("app", "memory", memory)
	config.set_value("app", "last_answer", last_answer)
	config.set_value("app", "history", history)
	config.set_value("programmer", "base", programmer_base)
	config.set_value("converter", "state", converter)
	config.save(path)
