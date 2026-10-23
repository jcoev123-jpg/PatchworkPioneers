extends SceneTree
func _init():
	var script = load("res://scripts/run_rest_patch_resew_options.gd")
	if not script:
		print("FAILED TO LOAD run_rest_patch_resew_options.gd")
	else:
		print("LOADED OK run_rest_patch_resew_options.gd")
	quit()
