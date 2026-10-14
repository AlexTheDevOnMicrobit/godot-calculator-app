extends RefCounted
## User preferences, memory and history, persisted in a ConfigFile.

enum ThemeMode { AUTO, DARK, LIGHT }

const DEFAULT_PATH := "user://settings.cfg"

var path := DEFAULT_PATH
var language := "en"
var angle_mode := 0 # Evaluator.AngleMode
var theme_mode: ThemeMode = ThemeMode.AUTO
var sound := true
var vibration := true
var memory := 0.0
var last_answer := 0.0
var history: Array = [] # Array of { "expr": String, "value": float }


func load_settings() -> void:
	var os_language := "fr" if OS.get_locale_language() == "fr" else "en"
	var config := ConfigFile.new()
	if config.load(path) != OK:
		language = os_language
		return
	language = config.get_value("app", "language", os_language)
	if language not in ["en", "fr"]:
		language = "en"
	angle_mode = int(config.get_value("app", "angle_mode", 0))
	theme_mode = clampi(int(config.get_value("app", "theme_mode", ThemeMode.AUTO)), 0, 2) as ThemeMode
	sound = bool(config.get_value("app", "sound", true))
	vibration = bool(config.get_value("app", "vibration", true))
	memory = float(config.get_value("app", "memory", 0.0))
	last_answer = float(config.get_value("app", "last_answer", 0.0))
	var saved_history = config.get_value("app", "history", [])
	history = saved_history if saved_history is Array else []


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("app", "language", language)
	config.set_value("app", "angle_mode", angle_mode)
	config.set_value("app", "theme_mode", theme_mode)
	config.set_value("app", "sound", sound)
	config.set_value("app", "vibration", vibration)
	config.set_value("app", "memory", memory)
	config.set_value("app", "last_answer", last_answer)
	config.set_value("app", "history", history)
	config.save(path)
