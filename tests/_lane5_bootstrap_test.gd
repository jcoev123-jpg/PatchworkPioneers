extends SceneTree
## Lane bootstrap scratch (deleted after use): the connector cannot run
## `godot --headless --import`, so this regenerates the missing .godot
## engine state for this fresh worktree from inside the engine itself.

const ART_PNG := "res://assets/paper/backgrounds/rest_camp.png"
const ART_CTEX := "res://.godot/imported/rest_camp.png-e4b9dd17e9d0fd52cbce9e8e5d46da81.ctex"
const CLASS_CACHE := "res://.godot/global_script_class_cache.cfg"


func _initialize() -> void:
	_build_class_cache()
	_build_art_ctex()
	print("bootstrap complete")
	quit()


func _collect_scripts(base: String, into: Array[String]) -> void:
	var dir := DirAccess.open(base)
	if dir == null:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if not item.begins_with("."):
			if dir.current_is_dir():
				_collect_scripts(base.path_join(item), into)
			elif item.ends_with(".gd"):
				into.append(base.path_join(item))
		item = dir.get_next()
	dir.list_dir_end()


func _script_entry(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var script_class := ""
	var base_class := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("class_name"):
			var rest := line.substr("class_name".length()).strip_edges().replace("\t", " ")
			script_class = rest.get_slice(" ", 0)
		elif line.begins_with("extends"):
			base_class = line.substr("extends".length()).strip_edges().get_slice(" ", 0)
		if script_class != "" and base_class != "":
			break
	file.close()
	if script_class == "" or base_class == "" or not script_class.is_valid_identifier():
		return {}
	# A quoted or res:// path extends is never a global base class name.
	if base_class.begins_with("\"") or base_class.begins_with("res://"):
		base_class = "RefCounted"
	return {
		"base": StringName(base_class),
		"class": StringName(script_class),
		"icon": "",
		"is_abstract": false,
		"is_tool": false,
		"language": StringName("GDScript"),
		"path": path,
	}


func _build_class_cache() -> void:
	var scripts: Array[String] = []
	_collect_scripts("res://", scripts)
	var entries: Array[Dictionary] = []
	for script_path in scripts:
		var entry := _script_entry(script_path)
		if not entry.is_empty():
			entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return String(a["class"]) < String(b["class"]))
	var cache := ConfigFile.new()
	cache.set_value("", "list", entries)
	var err := cache.save(CLASS_CACHE)
	print("bootstrap scripts_scanned=", scripts.size(), " classes=", entries.size(), " cache_save_err=", err)


func _build_art_ctex() -> void:
	var image := Image.new()
	var err := image.load(ART_PNG)
	print("bootstrap png_load_err=", err, " png_size=", image.get_size())
	if err != OK:
		return
	var texture := ImageTexture.create_from_image(image)
	DirAccess.make_dir_recursive_absolute("res://.godot/imported")
	var save_err := ResourceSaver.save(texture, ART_CTEX)
	print("bootstrap ctex_save_err=", save_err)
	var exists_check := ResourceLoader.exists(ART_PNG, "Texture2D")
	var loaded := load(ART_PNG)
	print("bootstrap exists=", exists_check, " loaded=", loaded,
		" path=", loaded.resource_path if loaded != null else "null",
		" type=", loaded.get_class() if loaded != null else "null")

