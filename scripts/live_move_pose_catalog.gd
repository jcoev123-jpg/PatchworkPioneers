class_name LiveMovePoseCatalog
extends RefCounted
## Presentation-only named moves. No live caller yet; never resolves combat.
## Invalid lookups return {}; valid receipts retain the name even if art falls back.
## `art` is a checked named texture path or the caller's established attack path.

const MANIFEST_PATH := "res://data/art/move_poses.json"
const ATTACK_POSES := ["attack", "attack2", "attack3", "attack4"]
const ENEMY_KINDS := ["attack", "block", "buff", "debuff", "shove", "snip_block", "summon", "steal_gold"]

var _loaded := false
var _manifest: Dictionary = {}


func lookup_enemy(id: String, action: Variant, attack_art: String) -> Dictionary:
	_ensure_loaded()
	if not action is Dictionary:
		return {}
	# Announced actions carry slot metadata; validate the actual combat action
	# separately without altering the caller's snapshot or its optional move.
	var base: Dictionary = action.duplicate(true)
	base.erase("move")
	base.erase("enemy_position")
	if not CombatEnemyIntents.valid_action(base):
		return {}
	var kind: String = base["type"]
	var pose := "attack" if kind == "attack" else "skill"
	if action.has("move"):
		if not action["move"] is String:
			return {}
		pose = action["move"]
	if (kind == "attack" and pose not in ATTACK_POSES) \
			or (kind != "attack" and pose != "skill"):
		return {}
	return _receipt("enemies", id, pose, kind, attack_art)


## Hero roles are the manifest's card-role contract: attack, block, or skill.
## Hero attacks keep their established pose; only block/skill have named entries.
func lookup_hero(id: String, role: String, attack_art: String) -> Dictionary:
	_ensure_loaded()
	if role not in ["block", "skill"]:
		return {}
	return _receipt("heroes", id, "guard" if role == "block" else "skill", role, attack_art)


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true # Failed reads are cached too.
	var parsed: Variant = _read_manifest()
	if parsed is Dictionary:
		_manifest = parsed.duplicate(true)


func _read_manifest() -> Variant:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _art_available(path: String) -> bool:
	return ResourceLoader.exists(path, "Texture2D")


func _receipt(group: String, id: String, pose: String, kind: String,
		attack_art: String) -> Dictionary:
	var actors: Variant = _manifest.get(group)
	if not actors is Dictionary:
		return {}
	var actor: Variant = actors.get(id)
	if not actor is Dictionary:
		return {}
	var entry: Variant = actor.get(pose)
	if not entry is Dictionary:
		return {}
	var title: Variant = entry.get("name")
	var art: Variant = entry.get("art")
	var covers: Variant = entry.get("covers")
	if not title is String or title.strip_edges().is_empty() \
			or not art is String or not art.begins_with("res://") \
			or not art.ends_with(".png") or art.strip_edges() != art \
			or not covers is Array or covers.is_empty():
		return {}
	var allowed: Array = ENEMY_KINDS if group == "enemies" else ["block", "skill"]
	for covered in covers:
		if not covered is String or covered not in allowed:
			return {}
		if pose in ATTACK_POSES and covered != "attack":
			return {}
		if group == "enemies" and pose == "skill" and covered == "attack":
			return {}
		if group == "heroes" and covered != ("block" if pose == "guard" else "skill"):
			return {}
	if kind not in covers:
		return {}
	var available := _art_available(art)
	return {"name": title, "pose": pose, "covers": covers.duplicate(true),
		"named_art": art, "art": art if available else attack_art,
		"art_available": available, "fallback_used": not available}
