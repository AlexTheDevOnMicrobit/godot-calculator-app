extends SceneTree
## Rasterizes the SVG icons into the PNG sizes required by the Android export.
## Run from the project root:
##   godot --headless --path . --script res://tools/export_icons.gd

const OUTPUTS := [
	["res://icon.svg", "res://assets/android/icon_192.png", 192],
	["res://assets/android/icon_foreground.svg", "res://assets/android/icon_foreground_432.png", 432],
	["res://assets/android/icon_background.svg", "res://assets/android/icon_background_432.png", 432],
]


func _initialize() -> void:
	for output in OUTPUTS:
		var svg := FileAccess.get_file_as_string(output[0])
		var image := Image.new()
		# Scale relative to the SVG's own width attribute.
		var base_width := 128.0 if output[0] == "res://icon.svg" else 432.0
		var error := image.load_svg_from_string(svg, output[2] / base_width)
		if error != OK:
			printerr("Failed to rasterize ", output[0])
			quit(1)
			return
		image.save_png(ProjectSettings.globalize_path(output[1]))
		print("wrote ", output[1], " ", image.get_size())
	quit()
