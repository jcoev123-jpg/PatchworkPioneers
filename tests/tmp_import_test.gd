extends SceneTree

func _initialize() -> void:
	var out := []
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], out, true)
	print("import rc=", rc, " lines=", out.size())
	quit(0)
