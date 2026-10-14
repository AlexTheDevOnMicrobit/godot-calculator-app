extends Node
## Audio and haptic feedback (key clicks, result chime, error buzz).
## Sounds are small WAV files in assets/sounds, vibration only on mobile.

enum Kind { KEY, RESULT, ERROR }

const SOUNDS := {
	Kind.KEY: preload("res://assets/sounds/click.wav"),
	Kind.RESULT: preload("res://assets/sounds/result.wav"),
	Kind.ERROR: preload("res://assets/sounds/error.wav"),
}
const VIBRATION_MS := { Kind.KEY: 12, Kind.RESULT: 25, Kind.ERROR: 60 }

var sound_enabled := true
var vibration_enabled := true

var _players := {}


func _ready() -> void:
	for kind in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = SOUNDS[kind]
		player.volume_db = -8.0
		player.max_polyphony = 4
		add_child(player)
		_players[kind] = player


func play(kind: Kind) -> void:
	if sound_enabled:
		_players[kind].play()
	if vibration_enabled and can_vibrate():
		Input.vibrate_handheld(VIBRATION_MS[kind])


## Plays a sound even when sounds are turned off (sound test).
func preview(kind: Kind) -> void:
	_players[kind].play()


static func can_vibrate() -> bool:
	return OS.has_feature("mobile")
