extends SceneTree

## One-time lane worktree setup: performs the brief's required
## "godot --headless --path . --import" using the running engine binary and
## the project's own absolute path, then verifies the global class cache.
## Temporary helper; deleted before DONE.

func _initialize() -> void:
    var exe := OS.get_executable_path()
    var root := ProjectSettings.globalize_path("res://")
    print("import worktree: ", root)
    var output: Array = []
    var rc := OS.execute(exe, ["--headless", "--path", root, "--import"], output)
    var lines := PackedStringArray()
    for entry in output:
        lines.append(str(entry))
    var text := "\n".join(lines)
    if text.length() > 1500:
        text = "..." + text.substr(text.length() - 1500)
    print(text)
    var cache := root.path_join(".godot/global_script_class_cache.cfg")
    print("import exit code: ", rc)
    print("global class cache present: ", FileAccess.file_exists(cache))
    quit(0 if rc == 0 and FileAccess.file_exists(cache) else 1)
