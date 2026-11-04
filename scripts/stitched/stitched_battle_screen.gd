class_name StitchedBattleScreen
extends Control
## S2's isolated, mounted preview. The StitchedRules session is the only combat authority.
## The shipped card map/hand is neither entered nor replaced by this opt-in screen.

signal exit_requested

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const SLOTS := ["head", "arms", "torso", "legs"]
const INK := Color("0d1016")
const PANEL := Color("11151edc")
const PAPER := Color("f0ddc0")
const MUTED := Color("c7b4a1")
const ACCENT := Color("e4b76a")
const ERROR := Color("ffa9a0")
const MAX_FOE_STEPS := 28

var battle: StitchedRules
var config: Dictionary = {}
var parts: Dictionary = {}
var reduced_motion := false
var receipts: Array[Dictionary] = []
var last_receipt: Dictionary = {}
var _selected_part := ""
var _target_ranks: Dictionary = {}
var _seat_buttons: Dictionary = {}
var _puppets: Dictionary = {}
var _part_buttons: Dictionary = {}
var _action_buttons: Dictionary = {}
var _target_buttons: Dictionary = {}
var _labels: Dictionary = {}
var _notice := ""
var _portrait_font: Font
var _pose_catalog := LiveMovePoseCatalog.new()
var _pose_manifest: Dictionary = {}
var _displayed_actor := ""

static func read_preview() -> Dictionary:
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func begin(data: Dictionary = {}) -> bool:
	if battle != null or is_inside_tree():
		return false
	config = data.duplicate(true) if not data.is_empty() else read_preview()
	if str(config.get("mode", "")) != "stitched" or not config.get("heroes") is Array or not config.get("foes") is Array:
		return false
	# Export presets intentionally omit tests/. An inline validated representative
	# catalog travels with the Web preview instead of depending on test fixtures.
	var catalog: Dictionary = StitchedParts.build_catalog(config.get("parts", []))
	if not bool(catalog.get("ok", false)):
		return false
	var payload := config.duplicate(true)
	payload["parts"] = catalog["parts"]
	var result := StitchedRules.create(payload)
	if not bool(result.get("ok", false)):
		return false
	battle = result["battle"]
	parts = catalog["by_id"]
	reduced_motion = bool(ProjectSettings.get_setting("patchwork/reduced_motion", false))
	return true


func _ready() -> void:
	if battle == null or not battle.is_valid():
		return
	name = "StitchedBattleScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_build_screen()
	_drive_foes()
	_refresh()
	if _action_buttons.has("pass"):
		_action_buttons["pass"].grab_focus()


func _panel(rect: Rect2, tint: Color = PANEL) -> ColorRect:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = tint
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _label(text: String, rect: Rect2, font_size: int = 18, color: Color = PAPER, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _portrait_font != null:
		label.add_theme_font_override("font", _portrait_font)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(title: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_focus_color", ACCENT)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _build_screen() -> void:
	var font_path := "res://assets/fonts/LondrinaSolid-Regular.ttf"
	if ResourceLoader.exists(font_path):
		_portrait_font = load(font_path) as Font
	_panel(Rect2(0, 0, 1280, 720), INK)
	var stage_path := ROSTER.stage_backdrop_path("Fight", 0)
	if ResourceLoader.exists(stage_path, "Texture2D"):
		var backdrop := TextureRect.new()
		backdrop.texture = load(stage_path)
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.position = Vector2(0, 95)
		backdrop.size = Vector2(1280, 360)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop)
	_panel(Rect2(0, 95, 1280, 360), Color(0.045, 0.05, 0.075, 0.38))
	_panel(Rect2(12, 10, 1256, 82))
	_panel(Rect2(12, 447, 1256, 262))
	_panel(Rect2(20, 458, 222, 242), Color("1a1b23ed"))
	_panel(Rect2(250, 458, 774, 242), Color("1a1b23ed"))
	_panel(Rect2(1032, 458, 228, 242), Color("1a1b23ed"))
	_label("STITCHED  /  " + str(config.get("title", "A frayed fray")), Rect2(26, 13, 420, 28), 26, ACCENT)
	_labels["round"] = _label("", Rect2(454, 13, 190, 28), 21)
	_labels["order"] = _label("", Rect2(454, 45, 760, 35), 18, MUTED)
	_labels["candle"] = _label("", Rect2(1008, 10, 242, 33), 20, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("4 HERO RANKS  •  rear to front", Rect2(40, 113, 520, 32), 20, ACCENT)
	_label("4 FOE RANKS  •  front to rear", Rect2(705, 113, 535, 32), 20, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_labels["hero"] = _label("", Rect2(28, 468, 204, 34), 22, ACCENT)
	_labels["stats"] = _label("", Rect2(28, 505, 200, 140), 18)
	_labels["thread"] = _label("", Rect2(28, 652, 204, 40), 17, ERROR)
	_label("SEWN ABILITIES · CHOOSE A PART, THEN A LIT RANK", Rect2(264, 462, 750, 28), 19, ACCENT)
	for index in range(4):
		var slot: String = SLOTS[index]
		_part_buttons[slot] = _button(slot.capitalize(), Rect2(266 + index * 187, 496, 178, 44),
			func(): select_part(slot))
	_labels["preview"] = _label("", Rect2(266, 542, 740, 48), 18, MUTED)
	_action_buttons["move_front"] = _button("Move front", Rect2(266, 594, 135, 38), func(): submit_move(-1))
	_action_buttons["move_back"] = _button("Move back", Rect2(409, 594, 135, 38), func(): submit_move(1))
	_action_buttons["re_tie"] = _button("Re-tie", Rect2(552, 594, 135, 38), func(): submit_re_tie())
	_action_buttons["pass"] = _button("Pass turn", Rect2(695, 594, 150, 38), func(): submit_pass())
	_action_buttons["retreat"] = _button("Retreat", Rect2(852, 594, 155, 38), func(): submit_retreat())
	for index in range(4):
		var hero_rank := index + 1
		_target_buttons["hero_" + str(hero_rank)] = _button("Ally %d" % hero_rank,
			Rect2(266 + index * 91, 647, 86, 38), func(): submit_target("hero", hero_rank))
		_target_buttons["foe_" + str(hero_rank)] = _button("Foe %d" % hero_rank,
			Rect2(643 + index * 91, 647, 86, 38), func(): submit_target("foe", hero_rank))
	_labels["log"] = _label("Choose a sewn part or another turn action.", Rect2(1042, 468, 208, 125), 18, MUTED)
	_labels["log"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_labels["log"].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var toggle := CheckButton.new()
	toggle.text = "Reduce motion"
	toggle.position = Vector2(1045, 597)
	toggle.size = Vector2(202, 36)
	toggle.button_pressed = reduced_motion
	toggle.add_theme_font_size_override("font_size", 17)
	toggle.toggled.connect(set_reduced_motion)
	add_child(toggle)
	_action_buttons["exit"] = _button("Back to title", Rect2(1043, 650, 208, 42), func(): exit_requested.emit())
	# Seats stay present even when empty or later filled by a summon.
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var px: float = (516.0 - rank * 124.0) if side == "hero" else (646.0 + (rank - 1) * 126.0)
			_seat(side, rank, px)
	# Pose manifest is optional: it only selects authored pixels, never a game action.
	var pose_file := FileAccess.open(LiveMovePoseCatalog.MANIFEST_PATH, FileAccess.READ)
	if pose_file != null:
		var data: Variant = JSON.parse_string(pose_file.get_as_text())
		if data is Dictionary:
			_pose_manifest = data


func _seat(side: String, rank: int, x: float) -> void:
	var key := side + "_" + str(rank)
	var seat_panel := ColorRect.new()
	seat_panel.position = Vector2(x, 164)
	seat_panel.size = Vector2(116, 275)
	seat_panel.color = Color(0.075, 0.07, 0.095, 0.48)
	seat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seat_panel)
	var puppet := ROSTER.Puppet.new()
	puppet.position = Vector2(x + 4, 194)
	puppet.size = Vector2(108, 178)
	puppet.stage_height = 178
	puppet.slot = rank
	puppet.facing = 1.0 if side == "hero" else -1.0
	add_child(puppet)
	_puppets[key] = puppet
	var tag := _button("%s %d · empty" % [side.capitalize(), rank], Rect2(x, 373, 116, 36),
		func(): submit_target(side, rank))
	_seat_buttons[key] = tag
	_labels[key] = _label("", Rect2(x - 3, 411, 122, 25), 16, PAPER, HORIZONTAL_ALIGNMENT_CENTER)


func _unit_at(side: String, rank: int) -> Dictionary:
	if battle == null:
		return {}
	for unit in battle.get_heroes() if side == "hero" else battle.get_foes():
		if int(unit["rank"]) == rank and not bool(unit["lost"]) and not bool(unit["dead"]):
			return unit
	return {}


func _heap_at(rank: int) -> Dictionary:
	if battle == null:
		return {}
	for heap in battle.get_heaps():
		if int(heap["rank"]) == rank:
			return heap
	return {}


func _art_for(id: String) -> Dictionary:
	var paths := ROSTER.art_paths(id)
	var images: Dictionary = {}
	for kind in paths:
		var path: String = paths[kind]
		if ResourceLoader.exists(path, "Texture2D"):
			images[kind] = load(path)
	return images


func _sync_puppet(key: String, unit: Dictionary) -> void:
	var puppet: Variant = _puppets[key]
	var id := str(unit.get("id", ""))
	if puppet.actor_id != id:
		puppet.bind_actor(id, _art_for(id))
	if not unit.is_empty():
		puppet.fallen = bool(unit.get("dead", false)) or bool(unit.get("lost", false))
		puppet.scale = Vector2.ONE * (1.10 if id == battle.current_actor_id() else 1.0)
	else:
		puppet.fallen = false
		puppet.scale = Vector2.ONE
	puppet.visible = not id.is_empty()
	puppet.set_process(not reduced_motion)
	puppet.queue_redraw()


func _refresh() -> void:
	if battle == null:
		return
	var acting := battle.get_unit(battle.current_actor_id())
	var hero_turn := battle.current_side() == "hero" and not battle.is_over()
	_labels["round"].text = "ROUND %d  ·  %s" % [battle.round_number(), battle.outcome().to_upper()]
	var order: Array[String] = []
	for id in battle.turn_order():
		var unit := battle.get_unit(str(id))
		if not unit.is_empty():
			order.append(("%s%s" % ["● " if id == battle.current_actor_id() else "· ", str(unit["name"])]))
	_labels["order"].text = "TURN ORDER   " + "   ".join(order)
	var band: Dictionary = battle.candle_band()
	_labels["candle"].text = "CANDLE  %d / 100  ·  %s" % [battle.candle(), str(band.get("name", "glowing")).capitalize()]
	_labels["hero"].text = str(acting.get("name", "Battle ended"))
	if acting.is_empty():
		_labels["stats"].text = "Outcome: " + battle.outcome().capitalize()
	else:
		_labels["stats"].text = "Rank %d  ·  %s\nHP %d / %d\nFray %d / 200\nSpeed %d   Dodge %d\nACC %+d   PROT %d%%\nResolve: %s" % [
			int(acting["rank"]), str(acting["side"]).capitalize(), int(acting["hp"]), int(acting["max_hp"]),
			int(acting["fray"]), int(acting["speed"]), int(acting["dodge"]), int(acting["acc"]),
			int(acting["prot"]), str(acting.get("resolve", "none")) if not str(acting.get("resolve", "")).is_empty() else "steady"]
	var cuts: Dictionary = battle.thread_cuts()
	var cut_names := PackedStringArray()
	for id in cuts:
		cut_names.append(str(id))
	_labels["thread"].text = "THREAD CUT: " + (", ".join(cut_names) if not cut_names.is_empty() else "none")
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var key: String = str(side) + "_" + str(rank)
			var unit := _unit_at(side, rank)
			_sync_puppet(key, unit)
			var button: Button = _seat_buttons[key]
			var heap := _heap_at(rank) if side == "foe" and unit.is_empty() else {}
			button.text = "R%d  %s" % [rank, str(unit.get("name", "Scrap heap" if not heap.is_empty() else "—"))]
			var flags: Array[String] = []
			if not unit.is_empty():
				if int(unit.get("fray", 0)) > 0:
					flags.append("FRAY %d" % int(unit["fray"]))
				for status in unit.get("statuses", {}):
					if int(unit["statuses"][status]) > 0:
						flags.append(str(status).to_upper())
				if bool(unit.get("hanging", false)):
					flags.append("HANGING")
			_labels[key].text = ("HP %d/%d" % [int(unit["hp"]), int(unit["max_hp"])] if not unit.is_empty() else ("SCRAP %d HP" % int(heap.get("hp", 0)) if not heap.is_empty() else "EMPTY")) + (" · " + ",".join(flags) if not flags.is_empty() else "")
	_target_ranks.clear()
	for slot in SLOTS:
		var button: Button = _part_buttons[slot]
		var equipped: Dictionary = acting.get("parts", {}).get(slot, {})
		var id := str(equipped.get("id", ""))
		var definition: Dictionary = parts.get(id, {})
		var can_use := hero_turn and _valid_part(acting, equipped)
		button.disabled = not can_use
		button.text = (str(definition.get("name", slot.capitalize())) if not id.is_empty() else slot.capitalize()) + (" [TORN]" if bool(equipped.get("torn", false)) else "")
		if slot == _selected_part and not can_use:
			_selected_part = ""
	if hero_turn and not _selected_part.is_empty():
		var selected: Dictionary = acting["parts"][_selected_part]
		var ability: Dictionary = StitchedParts.ability_at_tier(parts[str(selected["id"])], int(selected["tier"]))
		for rank in range(1, 5):
			var targets: Array = battle._legal_targets(acting, ability, rank)
			if not targets.is_empty():
				var side := "hero" if str(targets[0]["side"]) == "hero" else "foe"
				_target_ranks[side + "_" + str(rank)] = true
		_labels["preview"].text = _preview_text(acting, ability)
	else:
		_labels["preview"].text = "Select a legal part to see its range, hit chance and damage. No RNG spent."
	for key in _seat_buttons:
		_seat_buttons[key].disabled = not _target_ranks.has(key)
	for key in _target_buttons:
		_target_buttons[key].disabled = not _target_ranks.has(key)
	_action_buttons["move_front"].disabled = not hero_turn or not _can_move(-1)
	_action_buttons["move_back"].disabled = not hero_turn or not _can_move(1)
	_action_buttons["re_tie"].disabled = not hero_turn or not cuts.has(str(acting.get("id", "")))
	_action_buttons["pass"].disabled = not hero_turn
	_action_buttons["retreat"].disabled = not hero_turn or battle.is_boss_encounter()
	_labels["log"].text = _notice if not _notice.is_empty() else "Choose a sewn ability, a move, or Pass.\nEach committed action uses the seeded battle rules."


func _valid_part(actor: Dictionary, equipped: Dictionary) -> bool:
	var id := str(equipped.get("id", ""))
	if id.is_empty() or bool(equipped.get("torn", false)) or not parts.has(id):
		return false
	var ability: Dictionary = StitchedParts.ability_at_tier(parts[id], int(equipped["tier"]))
	if ability.is_empty() or not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) or not battle._self_move_gate(actor, ability).is_empty():
		return false
	for rank in range(1, 5):
		if not battle._legal_targets(actor, ability, rank).is_empty():
			return true
	return false


func _can_move(direction: int) -> bool:
	if battle == null or battle.current_side() != "hero":
		return false
	var actor := battle.get_unit(battle.current_actor_id())
	return not actor.is_empty() and bool(battle._shift_valid(actor, direction).get("ok", false))


func _preview_text(actor: Dictionary, ability: Dictionary) -> String:
	var rank_labels: Array[String] = []
	var detail := ""
	for rank in range(1, 5):
		var targets: Array = battle._legal_targets(actor, ability, rank)
		if targets.is_empty():
			continue
		rank_labels.append(str(rank))
		var target: Dictionary = targets[0]
		if detail.is_empty():
			var chance := StitchedRules.hit_chance(int(ability["acc"]) + int(actor["acc"]),
				int(target.get("dodge", 0)), int(actor["miss_streak"]))
			detail = " · HIT %d%% · DMG %d–%d" % [chance, int(ability["dmg"][0]) + int(actor["dmg_bonus"]), int(ability["dmg"][1]) + int(actor["dmg_bonus"])]
	if rank_labels.is_empty():
		return str(ability["name"]) + " · no legal targets"
	return str(ability["name"]) + " · target ranks " + ", ".join(rank_labels) + detail


func select_part(slot: String) -> bool:
	var actor := battle.get_unit(battle.current_actor_id()) if battle != null else {}
	if battle == null or battle.current_side() != "hero" or not slot in SLOTS or not _valid_part(actor, actor.get("parts", {}).get(slot, {})):
		return false
	_selected_part = slot
	_refresh()
	return true


func legal_targets() -> Dictionary:
	return _target_ranks.duplicate(true)


func submit_target(side: String, rank: int) -> Dictionary:
	var key := side + "_" + str(rank)
	if not _target_ranks.has(key) or _selected_part.is_empty():
		return {"ok": false, "error": "target is not legal"}
	var actor := battle.get_unit(battle.current_actor_id())
	if actor.is_empty() or not actor["parts"].has(_selected_part):
		return {"ok": false, "error": "no acting part"}
	return submit_part(str(actor["parts"][_selected_part]["id"]), rank)


func submit_part(part_id: String, rank: int) -> Dictionary:
	var actor := battle.get_unit(battle.current_actor_id()) if battle != null else {}
	if battle == null or battle.current_side() != "hero" or rank < 1 or rank > 4:
		return {"ok": false, "error": "not an active hero rank"}
	var equipped: Dictionary = battle._equipment(actor, part_id)
	if not _valid_part(actor, equipped):
		return {"ok": false, "error": "part unavailable or torn"}
	var ability: Dictionary = StitchedParts.ability_at_tier(parts[part_id], int(equipped["tier"]))
	if battle._legal_targets(actor, ability, rank).is_empty():
		return {"ok": false, "error": "illegal target"}
	return _commit(battle.use_part(part_id, rank))


func submit_move(direction: int) -> Dictionary:
	if not _can_move(direction):
		return {"ok": false, "error": "move blocked"}
	return _commit(battle.move(direction))


func submit_re_tie() -> Dictionary:
	if battle == null or battle.current_side() != "hero" or not battle.thread_cuts().has(battle.current_actor_id()):
		return {"ok": false, "error": "thread is intact"}
	return _commit(battle.re_tie())


func submit_pass() -> Dictionary:
	if battle == null or battle.current_side() != "hero":
		return {"ok": false, "error": "not a hero turn"}
	return _commit(battle.pass_turn())


func submit_retreat() -> Dictionary:
	if battle == null or battle.current_side() != "hero" or battle.is_boss_encounter():
		return {"ok": false, "error": "retreat unavailable"}
	return _commit(battle.retreat())


func _commit(receipt: Dictionary) -> Dictionary:
	if not bool(receipt.get("ok", false)):
		return receipt
	_record(receipt)
	_selected_part = ""
	_drive_foes()
	_refresh()
	return receipt


func _drive_foes() -> void:
	if battle == null:
		return
	var iterations := 0
	while not battle.is_over() and battle.current_side() == "foe" and iterations < MAX_FOE_STEPS:
		iterations += 1
		var actor := battle.get_unit(battle.current_actor_id())
		var receipt: Dictionary = {}
		# Rotate through the foe's authored kit by round before falling back to any
		# legal move. This exposes snip/debuff skills without guessing combat state.
		var authored: Array = actor.get("abilities", [])
		var offset := (battle.round_number() - 1) % maxi(1, authored.size())
		for step in range(authored.size()):
			var ability: Dictionary = authored[(offset + step) % authored.size()]
			if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) or not battle._self_move_gate(actor, ability).is_empty():
				continue
			for rank in range(1, 5):
				if battle._legal_targets(actor, ability, rank).is_empty():
					continue
				receipt = battle.use_foe_ability(str(ability["id"]), rank)
				if bool(receipt.get("ok", false)):
					break
			if bool(receipt.get("ok", false)):
				break
		if not bool(receipt.get("ok", false)):
			receipt = battle.pass_turn()
		if not bool(receipt.get("ok", false)):
			break
		_record(receipt)


func _record(receipt: Dictionary) -> void:
	last_receipt = receipt.duplicate(true)
	receipts.append(last_receipt.duplicate(true))
	var actor_id := str(receipt.get("actor", ""))
	var action := str(receipt.get("action", ""))
	var log := "%s · %s" % [actor_id.replace("_", " ").capitalize(), action.replace("_", " ").capitalize()]
	if action == "ability":
		log += "\n" + str(receipt.get("ability", ""))
		for result in receipt.get("results", []):
			log += "\n→ " + str(result.get("target", "")) + "  " + str(result.get("damage", result.get("hit", "")))
	_notice = log + "\nRound %d · %s" % [battle.round_number(), battle.outcome().capitalize()]
	if reduced_motion:
		return
	var actor := battle.get_unit(actor_id)
	if not actor.is_empty():
		var actor_key := str(actor["side"]) + "_" + str(actor["rank"])
		if _puppets.has(actor_key):
			var puppet: Variant = _puppets[actor_key]
			if action == "ability":
				_apply_named_pose(puppet, actor_id, str(receipt.get("ability", "")), str(actor["side"]))
				puppet.trigger_attack(0.32)
	for result in receipt.get("results", []):
		var target := battle.get_unit(str(result.get("target", "")))
		if target.is_empty():
			continue
		var key := str(target["side"]) + "_" + str(target["rank"])
		if _puppets.has(key):
			_puppets[key].trigger_recoil(0.28)


func _apply_named_pose(puppet: Variant, id: String, ability_id: String, side: String) -> void:
	var actor := battle.get_unit(id)
	var move := "attack"
	if side == "hero":
		for part in actor.get("parts", {}).values():
			var item: Dictionary = parts.get(str(part["id"]), {})
			var ability: Dictionary = StitchedParts.ability_at_tier(item, int(part["tier"]))
			if str(ability.get("id", "")) == ability_id:
				move = str(ability.get("move", "attack"))
				break
	else:
		for ability in actor.get("abilities", []):
			if str(ability["id"]) == ability_id:
				move = str(ability.get("move", "attack"))
				break
	var group := "heroes" if side == "hero" else "enemies"
	var entry: Dictionary = _pose_manifest.get(group, {}).get(id, {}).get(move, {})
	var path := str(entry.get("art", ""))
	if path.begins_with("res://") and ResourceLoader.exists(path, "Texture2D"):
		puppet.attack_texture = load(path)
	else:
		var fallback := str(ROSTER.art_paths(id).get("attack", ""))
		puppet.attack_texture = load(fallback) if ResourceLoader.exists(fallback, "Texture2D") else null


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for puppet in _puppets.values():
		if reduced_motion:
			puppet.cancel_attack()
			puppet.cancel_recoil()
			puppet.cancel_fall()
		puppet.set_process(not reduced_motion)
	if battle != null:
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_selected_part = ""
		_refresh()
		get_viewport().set_input_as_handled()
