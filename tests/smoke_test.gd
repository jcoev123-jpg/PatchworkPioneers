extends SceneTree
## Boots the main scene and checks the title screen is shown.

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/app.tscn")
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var ok := true
	if app.title_label == null or app.title_label.text != "Patchwork Pioneers":
		push_error("title missing")
		ok = false
	if app.start_button == null or app.start_button.text != "Start run":
		push_error("start button missing")
		ok = false
	print("smoke_test: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
