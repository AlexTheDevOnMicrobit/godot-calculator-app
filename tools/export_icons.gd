extends SceneTree
## Rasterizes the SVG icons into the PNG sizes required by the Android, Web
## (PWA) and Windows exports. Then run tools/make_ico.py for the Windows .ico.
## Run from the project root:
##   godot --headless --path . --script res://tools/export_icons.gd

## [source SVG, output PNG, size in pixels]
const OUTPUTS := [
	["res://icon.svg", "res://assets/android/icon_192.png", 192],
	["res://assets/android/icon_foreground.svg", "res://assets/android/icon_foreground_432.png", 432],
	["res://assets/android/icon_background.svg", "res://assets/android/icon_background_432.png", 432],
	# Web app (PWA) icons
	["res://icon.svg", "res://assets/web/icon_144.png", 144],
	["res://icon.svg", "res://assets/web/icon_180.png", 180],
	["res://icon.svg", "res://assets/web/icon_512.png", 512],
	# Sources for the Windows .ico (tools/make_ico.py)
	["res://icon.svg", "res://assets/windows/icon_256.png", 256],
	["res://icon.svg", "res://assets/windows/icon_128.png", 128],
	["res://icon.svg", "res://assets/windows/icon_64.png", 64],
	["res://icon.svg", "res://assets/windows/icon_48.png", 48],
	["res://icon.svg", "res://assets/windows/icon_32.png", 32],
	["res://icon.svg", "res://assets/windows/icon_16.png", 16],
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
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output[1]).get_base_dir())
		image.save_png(ProjectSettings.globalize_path(output[1]))
		print("wrote ", output[1], " ", image.get_size())
	quit()
