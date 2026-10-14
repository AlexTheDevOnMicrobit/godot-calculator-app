extends SceneTree
## Headless unit tests (math engine, formatting, input rules).
## The same suite runs on device from Settings → On-screen tests.
## Run: godot --headless --path . --script res://tests/test_runner.gd

const SelfTest := preload("res://scripts/self_test.gd")


func _initialize() -> void:
	var suite = SelfTest.new().run()
	for section in suite.sections:
		print("%-14s %d / %d" % [section["name"], section["passed"], section["total"]])
	for failure in suite.failures:
		printerr("FAIL: " + failure)
	print("\n%d passed, %d failed" % [suite.passed, suite.failed])
	quit(1 if suite.failed > 0 else 0)
