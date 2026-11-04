class_name StitchedTurnOrderRibbon
extends Control
## Read-only S5 turn tags: this display never asks the battle to roll or advance.
## Nine fixed-sized places accommodate four heroes, four foes and a boss's extra turn.

const TAG_WIDTH := 73.0
const TAG_HEIGHT := 42.0
const TAG_GAP := 4.0
const MAX_TAGS := 9
const PLATE_PATH := "res://assets/paper/ui/hud_name_plate.png"
const AMBER := Color("e4b76a")
const BONE := Color("f0ddc0")
const MUTED := Color("c7b4a1")
const ROSTER := preload("res://scripts/live_enemy_roster.gd")

var displayed_entries: Array[Dictionary] = []
var _tags: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	var plate: Texture2D = load(PLATE_PATH) if ResourceLoader.exists(PLATE_PATH, "Texture2D") else null
	for index in range(MAX_TAGS):
		var tag := Control.new()
		tag.name = "TurnTag%d" % (index + 1)
		tag.position = Vector2(index * (TAG_WIDTH + TAG_GAP), 0)
		tag.size = Vector2(TAG_WIDTH, TAG_HEIGHT)
		tag.mouse_filter = Control.MOUSE_FILTER_STOP
		tag.focus_mode = Control.FOCUS_NONE
		add_child(tag)

		var frame := NinePatchRect.new()
		frame.name = "SewnPlate"
		frame.texture = plate
		frame.size = tag.size
		frame.patch_margin_left = 10
		frame.patch_margin_right = 10
		frame.patch_margin_top = 8
		frame.patch_margin_bottom = 8
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(frame)

		var portrait := TextureRect.new()
		portrait.name = "ActorPortrait"
		portrait.position = Vector2(4, 4)
		portrait.size = Vector2(33, 34)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(portrait)

		var fallback := Label.new()
		fallback.name = "NameFallback"
		fallback.position = Vector2(3, 5)
		fallback.size = Vector2(36, 32)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.clip_text = true
		fallback.add_theme_font_size_override("font_size", 11)
		fallback.add_theme_color_override("font_color", BONE)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(fallback)

		var rank := Label.new()
		rank.name = "SideRank"
		rank.position = Vector2(39, 2)
		rank.size = Vector2(30, 19)
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank.add_theme_font_size_override("font_size", 17)
		rank.add_theme_color_override("font_color", BONE)
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(rank)

		var marker := Label.new()
		marker.name = "NowMarker"
		marker.position = Vector2(36, 22)
		marker.size = Vector2(34, 16)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 12)
		marker.add_theme_color_override("font_color", AMBER)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(marker)
		_tags.append({"root": tag, "frame": frame, "portrait": portrait,
			"fallback": fallback, "rank": rank, "marker": marker})
		tag.hide()


## Entries are supplied from public StitchedRules.turn_order() and get_unit().
## The original order and repeated IDs are preserved; only dead/lost entries vanish.
## The caller supplies an empty actor ID or is_over=true to clear NOW at battle end.
func show_order(entries: Array, acting_id: String, is_over: bool) -> void:
	displayed_entries.clear()
	for raw in entries:
		if not raw is Dictionary:
			continue
		var unit: Dictionary = raw
		if unit.is_empty() or bool(unit.get("dead", false)) or bool(unit.get("lost", false)):
			continue
		if str(unit.get("side", "")) == "foe" and int(unit.get("hp", 0)) <= 0:
			continue
		displayed_entries.append(unit.duplicate(true))
	for index in range(_tags.size()):
		var tag: Dictionary = _tags[index]
		var control: Control = tag["root"]
		if index >= displayed_entries.size():
			control.hide()
			control.tooltip_text = ""
			tag["portrait"].texture = null
			continue
		var unit: Dictionary = displayed_entries[index]
		var id := str(unit.get("id", ""))
		var full_name := str(unit.get("name", id))
		var side := str(unit.get("side", ""))
		var rank := int(unit.get("rank", 0))
		var code := ("H" if side == "hero" else "F") + str(rank)
		control.tooltip_text = "%s · %s rank %d" % [full_name, "Hero" if side == "hero" else "Foe", rank]
		tag["rank"].text = code
		var active := not is_over and not acting_id.is_empty() and id == acting_id
		tag["marker"].text = "NOW" if active else ("HERO" if side == "hero" else "FOE")
		tag["marker"].add_theme_color_override("font_color", AMBER if active else MUTED)
		tag["frame"].modulate = Color(1, 0.87, 0.67) if active else Color(0.85, 0.82, 0.78)
		# Never substitute a rank-mate's art or a generic enemy for an unknown ID.
		var path := str(ROSTER.art_paths(id).get("idle", ""))
		var texture: Texture2D = load(path) if not path.is_empty() and ResourceLoader.exists(path, "Texture2D") else null
		tag["portrait"].texture = texture
		tag["portrait"].visible = texture != null
		tag["fallback"].visible = texture == null
		tag["fallback"].text = full_name.substr(0, 6)
		control.show()


func tag_at(index: int) -> Control:
	if index < 0 or index >= _tags.size():
		return null
	return _tags[index]["root"]


func portrait_at(index: int) -> TextureRect:
	if index < 0 or index >= _tags.size():
		return null
	return _tags[index]["portrait"]


func marker_at(index: int) -> Label:
	if index < 0 or index >= _tags.size():
		return null
	return _tags[index]["marker"]
