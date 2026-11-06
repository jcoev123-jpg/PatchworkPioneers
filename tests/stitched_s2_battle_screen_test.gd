extends SceneTree
## Mounted, public-entry S2 test: not a made-up test-only action bridge.
const BOOT := preload("res://scripts/live_web_playtest_boot.gd")
const ROSTER_STAGE := preload("res://scripts/live_enemy_roster.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _spawn() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	return app


func _stage(app) -> StitchedBattleScreen:
	var boot := root.get_node("LiveWebPlaytestBoot")
	_check(await boot.enter_preview(app, "stitched_battle"), "public query entry mounts a Stitched session")
	return boot.stitched_view


func _rank_key(stage: StitchedBattleScreen) -> String:
	for key in stage.legal_targets():
		return key
	return ""


func _painted_bounds(puppet: Control) -> Rect2:
	var local: Rect2 = puppet.posed_actor_rect()
	return Rect2(puppet.global_position + local.position, local.size)


func _figure_click(stage: StitchedBattleScreen, key: String) -> void:
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	stage._figure_hits[key].gui_input.emit(mouse)


func _fray_full(value: int) -> String:
	return ("FRAY %d/200" % value
		+ " | 100 FRAY: resolve threshold (STEADFAST or UNRAVELLED)."
		+ " | 200 FRAY: COMES APART (HANGING, or LOST if already HANGING).")


func _check_rank_font(label: Label, note: String) -> void:
	var face: Font = label.get_theme_font("font")
	var actual_size := label.get_theme_font_size("font_size")
	_check(face is FontVariation and (face as FontVariation).base_font == StitchedBattleChrome.RANK_FONT and label.has_theme_font_override("font")
		and actual_size >= 13 and label.size.y == 14.0 and label.scale.y == 1.0
		and not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
		note + " binds genuine 13px-or-larger font with an unscaled, unclipped caption slot")
	if face != null:
		var measured := face.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, actual_size)
		_check(measured.x * label.scale.x <= label.size.x - 1.0
			and measured.y >= 13.0 and measured.y <= 14.0
			and label.get_global_rect().size.y == 14.0
			and label.get_global_rect().end.y <= 544.0,
			note + " has measured visible width/height inside the genuine y530..544 underfoot band")


func _verify_stage_art(stage: StitchedBattleScreen, foe_count: int = 3) -> void:
	var backdrop = stage.get_node_or_null("SharedStitchedBackdrop")
	_check(backdrop is ROSTER_STAGE.StageBackdrop and backdrop.has_image() and
		backdrop.stage_texture.resource_path == stage.stage_path() and
		backdrop.get_global_rect() == Rect2(0, 60, 1280, 500),
		"public 1280x720 battle paints one full-width stage from y60 to y560")
	var actual := 0
	var first_foot := -1.0
	var plate_texture: Texture2D = load("res://assets/paper/ui/panel_felt.png")
	var visible_art: Array[Dictionary] = []
	var name_rows: Array[Rect2] = []
	var hp_rows: Array[Rect2] = []
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var key: String = side + "_" + str(rank)
			var puppet: Control = stage._puppets[key]
			var hit: Control = stage._figure_hits[key]
			var foot: NinePatchRect = stage._foot_plates[key]
			var tag: Button = stage._seat_buttons[key]
			var duplicate: Label = stage._labels[key]
			var meters: Dictionary = stage._rank_meters[key]
			var meter_root: Control = meters["root"]
			var hp: ProgressBar = meters["hp"]
			var readout: Label = meters["hp_text"]
			var painted := _painted_bounds(puppet)
			var unit := stage._unit_at(side, rank)
			if unit.is_empty():
				_check(not puppet.visible and not hit.visible and not foot.visible
					and not meter_root.visible and not duplicate.visible,
					"empty %s R%d has no figure, mouse hotspot, ghost text or meter" % [side, rank])
				continue
			actual += 1
			visible_art.append({"key": key, "rect": painted})
			var texture: Texture2D = puppet.current_texture()
			var aspect_limited_height := 0.0
			if texture != null and texture.get_width() > 0:
				aspect_limited_height = (puppet.size.x - 8.0) * float(texture.get_height()) / float(texture.get_width())
			_check(puppet.visible and texture != null and puppet.size.x == 170.0
				and painted.size.y >= minf(240.0, aspect_limited_height) * 0.85
				and painted.size.y <= 280.0
				and painted.position.y >= 194.0 and painted.end.y <= 503.0
				and painted.position.x >= 0.0 and painted.end.x <= 1280.0,
				"%s R%d keeps its genuine aspect-fitted figure large within its 150px rank" % [side, rank])
			var rest_foot: float = puppet.global_position.y + puppet.foot_line()
			_check((first_foot < 0.0 or absf(first_foot - rest_foot) < 0.1)
				and absf(rest_foot - painted.end.y) < 7.0,
				"%s R%d actor art rests on the same fixed line through idle breathing" % [side, rank])
			first_foot = rest_foot
			_check(hit.visible and hit.focus_mode == Control.FOCUS_ALL
				and hit.get_global_rect().position.distance_to(painted.position) < 6.0
				and hit.size.distance_to(painted.size) < 6.0,
				"%s R%d has keyboard/pointer target only across actual posed art" % [side, rank])
			_check(foot.visible and foot.texture == plate_texture
				and foot.get_global_rect().size == Vector2(170, 50)
				and foot.get_global_rect().position.y == 505.0
				and foot.get_global_rect().position.x >= 0.0
				and foot.get_global_rect().end.x <= 1280.0
				and foot.get_global_rect().end.y <= 557.0
				and not foot.get_global_rect().intersects(painted),
				"%s R%d enlarged sewn foot plate clears figure and lower action panel" % [side, rank])
			var name_rect := tag.get_global_rect()
			var meter_rect := meter_root.get_global_rect()
			var caption_rect := readout.get_global_rect()
			var fill_rect := hp.get_global_rect()
			var frame: NinePatchRect = meter_root.get_node("HPFillSewnFrame")
			_check_rank_font(readout, "%s rank %d HP" % [side, rank])
			var fill_style := hp.get_theme_stylebox("fill") as StyleBoxTexture
			_check(tag.visible and meter_root.visible and not duplicate.visible
				and duplicate.text.is_empty() and tag.focus_mode == Control.FOCUS_ALL
				and tag.clip_text and not readout.clip_text
				and tag.get_theme_font_size("font_size") >= 16
				and readout.get_theme_font_size("font_size") >= 13
				and name_rect.size.x >= 145.0 and meter_rect.size.x == 170.0
				and name_rect.size.y >= 22.0 and meter_rect.size.y == 24.0
				and foot.get_global_rect().encloses(name_rect)
				and foot.get_global_rect().encloses(meter_rect)
				and not name_rect.intersects(meter_rect)
				and not caption_rect.intersects(fill_rect)
				and frame.texture == load("res://assets/paper/ui/hud_bar_frame.png")
				and fill_style != null and fill_style.texture == load("res://assets/paper/ui/reward_button.png")
				and frame.get_global_rect().size.y >= fill_rect.size.y
				and hp.value == float(unit["hp"]) and hp.max_value == float(unit["max_hp"])
				and readout.text == ("HP %d" % int(unit["hp"]) if side == "hero" else "HP %d/%d" % [int(unit["hp"]), int(unit["max_hp"])])
				and hp.tooltip_text == "HP %d/%d" % [int(unit["hp"]), int(unit["max_hp"])]
				and tag.tooltip_text.contains(str(unit["name"])),
				"%s R%d has exactly one framed HP meter row and readable name/status inspection" % [side, rank])
			if side == "hero":
				var fray: ProgressBar = meters["fray"]
				var fray_text: Label = meters["fray_text"]
				_check_rank_font(fray_text, "hero rank %d FRAY" % rank)
				var fray_frame: NinePatchRect = meter_root.get_node("FrayFillSewnFrame")
				var fray_fill := fray.get_theme_stylebox("fill") as StyleBoxTexture
				_check(fray.max_value == 200.0 and fray.value == float(unit["fray"])
					and fray_text.text == "FRAY %d" % int(unit["fray"])
					and fray.tooltip_text == _fray_full(int(unit["fray"]))
					and meter_root.tooltip_text.contains(_fray_full(int(unit["fray"])))
					and not fray_text.get_global_rect().intersects(fray_frame.get_global_rect())
					and not caption_rect.intersects(fray_text.get_global_rect())
					and fray_fill != null and fray_fill.texture == load("res://assets/paper/ui/reward_button.png")
					and fray_frame.texture == load("res://assets/paper/ui/hud_bar_frame.png"),
					"hero R%d keeps independently legible framed FRAY caption and fill" % rank)
			name_rows.append(name_rect)
			hp_rows.append(caption_rect)
			_check(puppet.facing == (1.0 if side == "hero" else -1.0),
				"%s R%d faces the opposing rank line" % [side, rank])
		for rank in range(1, 4):
			var front: Control = stage._puppets[side + "_" + str(rank)]
			var back: Control = stage._puppets[side + "_" + str(rank + 1)]
			if not front.visible or not back.visible:
				continue
			var a := _painted_bounds(front)
			var b := _painted_bounds(back)
			_check((a.get_center().x > b.get_center().x if side == "hero" else a.get_center().x < b.get_center().x)
				and absf(a.get_center().x - b.get_center().x - (150.0 if side == "hero" else -150.0)) < 6.0,
				"%s ranks %d/%d face correct direction with 150px centre spacing" % [side, rank, rank + 1])
	for i in range(visible_art.size()):
		for j in range(i + 1, visible_art.size()):
			var a: Rect2 = visible_art[i]["rect"]
			var b: Rect2 = visible_art[j]["rect"]
			var intersection := a.intersection(b)
			var shared := intersection.size.x * intersection.size.y
			var smaller := minf(a.size.x * a.size.y, b.size.x * b.size.y)
			_check(smaller > 0.0 and shared <= 0.15 * smaller + 0.1,
				"%s / %s actual posed figures overlap at most 15 percent" % [
					visible_art[i]["key"], visible_art[j]["key"]])
	for i in range(name_rows.size()):
		for j in range(i + 1, name_rows.size()):
			_check(not name_rows[i].intersects(name_rows[j])
				and not hp_rows[i].intersects(hp_rows[j]),
				"rank %d / %d names and HP text surfaces never obscure one another" % [i, j])
	var front_hero := _painted_bounds(stage._puppets["hero_1"])
	var front_foe := _painted_bounds(stage._puppets["foe_1"])
	_check(front_hero.end.x + 24.0 <= front_foe.position.x
		and stage._foot_plates["hero_1"].get_global_rect().end.x <
			stage._foot_plates["foe_1"].get_global_rect().position.x,
		"front ranks and large underfoot plates leave a genuine central aisle")
	var heading_hero := false
	var heading_foe := false
	for child in stage.get_children():
		if child is Label:
			heading_hero = heading_hero or child.text.contains("HEROES  ·  back 4 to front 1")
			heading_foe = heading_foe or child.text.contains("FOES  ·  front 1 to back 4")
	_check(heading_hero and heading_foe, "rank headings use supported plain-word directions")
	_check(actual == 4 + foe_count,
		"non-vacuous 4 hero and %d foe authentic figures occupy public ranks" % foe_count)
	_check(stage._target_buttons.size() == 8 and stage._turn_ribbon != null
		and stage._candle_meter != null and stage._action_buttons["pass"].position.y >= 640
		and stage._labels["preview"].position.y >= 610,
		"accessible rank controls, sewn order, candle, forecast and actions remain mounted")


func _verify_fourth_foe(stage: StitchedBattleScreen) -> void:
	# The existing post-summon fixture: admit a distinct authored ragling into
	# actual combat rank four, then restore the pristine public preview.
	var battle := stage.battle
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var original: Dictionary = battle.get_foes()[2]
	var extra: Dictionary = battle._units[str(original["id"])].duplicate(true)
	extra["id"] = "ragling"
	extra["name"] = "Ragling"
	extra["rank"] = 4
	battle._units[extra["id"]] = extra
	stage._refresh()
	_check(battle.get_foes().size() == 4 and stage._puppets["foe_4"].visible
		and stage._foe_tickets[4].visible, "genuine fourth foe has art, target and intent")
	_verify_stage_art(stage, 4)
	battle._units.erase(extra["id"])
	stage._refresh()
	_check(battle.state_snapshot() == snapshot and battle.rng_state() == rng
		and not stage._puppets["foe_4"].visible and not stage._foe_tickets[4].visible,
		"restoring 4v3 fixture removes fourth-rank figure and intent without RNG changes")


func _verify_worn_layout(stage: StitchedBattleScreen) -> void:
	var actor := stage.battle.get_unit(stage.battle.current_actor_id())
	_check(actor.get("side") == "hero" and stage._part_headings.size() == 4,
		"precondition: public app mounts four headings for the active hero")
	for slot in StitchedBattleScreen.SLOTS:
		var worn: Dictionary = actor["parts"][slot]
		var ability := StitchedParts.ability_at_tier(stage.parts[str(worn["id"])], int(worn["tier"]))
		var button: Button = stage._part_buttons[slot]
		var heading: Label = stage._part_headings[slot]
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		_check(button.text == ability["name"] and font_size >= 14 and
			font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8 <= button.size.x and
			font.get_height(font_size) <= button.size.y and not button.clip_text and
			button.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and
			heading.text == slot.to_upper() + " " + str(StitchedPartActionCues.ROMAN[int(worn["tier"])]),
			"public app theme retains complete readable worn ability and separate slot/tier")
		_check(not heading.get_global_rect().intersects(button.get_global_rect()) and
			not button.get_global_rect().intersects(stage._labels["preview"].get_global_rect()) and
			not button.get_global_rect().intersects(stage._part_help_buttons[slot].get_global_rect()),
			"public mounted heading, ability, inspection and digest have separate bounds")


func _choose_legal(stage: StitchedBattleScreen, through_figure: bool) -> Dictionary:
	var actor := stage.battle.get_unit(stage.battle.current_actor_id())
	if actor.is_empty() or stage.battle.current_side() != "hero":
		return {}
	for slot in StitchedBattleScreen.SLOTS:
		var button: Button = stage._part_buttons[slot]
		if button.disabled:
			continue
		var pristine := stage.battle.state_snapshot()
		var rng := stage.battle.rng_state()
		var receipts := stage.receipts.duplicate(true)
		if through_figure:
			await _mouse_activate(button)
		else:
			await _keyboard_activate(button)
		_check(stage._selected_part == slot and stage.battle.state_snapshot() == pristine
			and stage.battle.rng_state() == rng and stage.receipts == receipts,
			"real mouse/keyboard worn ability selection changes only the selected slot")
		var key := _rank_key(stage)
		if key.is_empty():
			continue
		var parts: Dictionary = actor["parts"]
		var before := stage.receipts.size()
		if through_figure:
			_check(stage._figure_hits[key].visible, "real lit figure has an enabled click surface")
			_figure_click(stage, key)
		else:
			_check(not stage._target_buttons[key].disabled, "keyboard rank button enables only real legal target")
			await _keyboard_activate(stage._target_buttons[key])
		var receipt: Dictionary = stage.receipts[before] if stage.receipts.size() > before else {}
		_check(bool(receipt.get("ok", false)), "legal figure or keyboard rank activation commits an authored ability")
		_check(stage.receipts.size() > before and stage.receipts[before].get("actor") == actor["id"] and
			stage.receipts[before].get("part") == parts[slot]["id"],
			"part action delegates exactly once, with the real acting part and receipt")
		var commits := 0
		for entry in stage.receipts.slice(before):
			if entry.get("action") == "ability" and entry.get("actor") == actor["id"]:
				commits += 1
		_check(commits == 1, "native worn and target activation dispatches the hero ability once")
		return receipt
	return {}


func _verify_status_readout(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var saved_units: Dictionary = {}
	for unit_id in battle._units:
		saved_units[unit_id] = battle._units[unit_id].duplicate(true)
	var saved_heaps: Array = battle._heaps.duplicate(true)
	var ordinary_log := str(stage._labels["log"].text)
	var foe_1_id := str(stage._unit_at("foe", 1).get("id", ""))
	var hero_1_id := str(stage._unit_at("hero", 1).get("id", ""))
	var hero_2_id := str(stage._unit_at("hero", 2).get("id", ""))
	_check(not foe_1_id.is_empty() and not hero_1_id.is_empty() and not hero_2_id.is_empty(),
		"precondition: mounted 4v3 fight has living actors in foe_1, hero_1 and hero_2")
	var foe_1: Dictionary = battle._units[foe_1_id]
	var hero_1: Dictionary = battle._units[hero_1_id]
	var hero_2: Dictionary = battle._units[hero_2_id]
	foe_1["statuses"] = {"bleed": 3, "weak": 2, "mark": 1, "stun": 1,
		"thorns": 4, "tangled": 2, "blind": 1, "riposte": 3, "exposed": 0}
	hero_1["statuses"] = {"guard": 2, "stun_resist": 1, "exposed": 2, "tangled": 0}
	hero_1["dodge_buff"] = {"amount": 8, "turns": 2, "skip": false}
	hero_2["hp"] = 0
	hero_2["fray"] = 150
	hero_2["hanging"] = true
	hero_2["statuses"] = {}
	stage._refresh()
	var view_snapshot := battle.state_snapshot()
	var view_rng := battle.rng_state()
	var view_receipts := stage.receipts.size()
	_check(stage._labels["log"].text == ordinary_log,
		"passive refresh without seat hover or focus preserves the ordinary action message")
	_check(stage._seat_buttons["foe_1"].text.contains("R1") and
		stage._seat_buttons["foe_1"].text.contains(str(foe_1["name"])) and
		stage._rank_meters["foe_1"]["root"].visible and
		stage._rank_meters["foe_1"]["hp_text"].text == "HP %d/%d" % [int(foe_1["hp"]), int(foe_1["max_hp"])] and
		stage._rank_meters["foe_1"]["hp"].value == float(foe_1["hp"]) and
		not stage._labels["foe_1"].visible and stage._labels["foe_1"].text.is_empty() and
		stage._seat_buttons["foe_1"].tooltip_text.contains("BLEED 3") and
		stage._seat_buttons["foe_1"].tooltip_text.contains("WEAK 2") and
		stage._seat_buttons["foe_1"].tooltip_text.contains("STUN 1") and
		stage._seat_buttons["foe_1"].tooltip_text.contains("MARK 1") and
		not stage._seat_buttons["foe_1"].tooltip_text.contains("EXPOSED"),
		"foe_1 has only HP meter text; full counted status remains in rank tooltip")
	# Pointer hover over foe_1 seat.
	stage._seat_buttons["foe_1"].mouse_entered.emit()
	var foe_detail := str(stage._labels["log"].text)
	_check(foe_detail == stage.status_detail("foe", 1) and
		foe_detail.contains("R1") and foe_detail.contains(str(foe_1["name"])) and
		foe_detail.contains("HP %d/%d" % [int(foe_1["hp"]), int(foe_1["max_hp"])]) and
		foe_detail.contains("BLEED 3") and foe_detail.contains("WEAK 2") and
		foe_detail.contains("STUN 1") and foe_detail.contains("MARK 1") and
		foe_detail.contains("THORNS 4") and foe_detail.contains("TANGLED 2") and
		foe_detail.contains("BLIND 1") and foe_detail.contains("RIPOSTE 3") and
		not foe_detail.contains("EXPOSED") and not foe_detail.contains("DODGE") and
		not foe_detail.contains("HANGING"),
		"mouse hover on foe_1 shows full counted status summary in the side detail log without zero/foreign statuses")
	_check(battle.state_snapshot() == view_snapshot and battle.rng_state() == view_rng and
		stage.receipts.size() == view_receipts,
		"mouse hover inspection spends no turn, changes no snapshot and consumes no RNG")
	stage._seat_buttons["foe_1"].mouse_exited.emit()
	stage._figure_hits["foe_1"].mouse_entered.emit()
	_check(stage._status_disclosure.visible and
		stage._status_disclosure_label.text == stage.status_detail("foe", 1) and
		stage._figure_hits["foe_1"].tooltip_text.contains("BLEED 3"),
		"real figure hover offers complete sewn status disclosure, not only clipped plate text")
	stage._figure_hits["foe_1"].mouse_exited.emit()
	_check(not stage._status_disclosure.visible,
		"figure exit dismisses the status disclosure without spending action/RNG")
	_check(stage._labels["log"].text == ordinary_log,
		"leaving hovered seat restores the prior ordinary action message")
	# Keyboard focus over hero_1 seat (Guard 2, Stun Resist 1, Dodge +8 / 2 turns).
	stage._figure_hits["hero_1"].grab_focus()
	_check(stage._figure_hits["hero_1"].has_focus() and stage._status_disclosure.visible
		and stage._status_disclosure_label.text == stage.status_detail("hero", 1),
		"keyboard figure focus exposes the same full status as hovering the painted actor")
	stage._seat_buttons["hero_1"].grab_focus()
	var hero_1_detail := str(stage._labels["log"].text)
	_check(stage._seat_buttons["hero_1"].has_focus() and
		hero_1_detail == stage.status_detail("hero", 1) and
		hero_1_detail.contains("R1") and hero_1_detail.contains(str(hero_1["name"])) and
		hero_1_detail.contains("HP %d/%d" % [int(hero_1["hp"]), int(hero_1["max_hp"])]) and
		hero_1_detail.contains("GUARD 2") and hero_1_detail.contains("STUN RESIST 1") and
		hero_1_detail.contains("EXPOSED 2") and hero_1_detail.contains("DODGE +8 / 2 turns") and
		stage._status_disclosure.visible and stage._status_disclosure_label.text == hero_1_detail and
		stage._rank_meters["hero_1"]["hp_text"].text.begins_with("HP ") and
		stage._rank_meters["hero_1"]["fray_text"].text.begins_with("FRAY ") and
		not stage._labels["hero_1"].visible and
		not hero_1_detail.contains("TANGLED") and not hero_1_detail.contains("BLEED") and
		not hero_1_detail.contains("HANGING"),
		"keyboard focus on hero_1 shows GUARD 2, STUN RESIST 1 and temporary DODGE +8 / 2 turns")
	_check(battle.state_snapshot() == view_snapshot and battle.rng_state() == view_rng and
		stage.receipts.size() == view_receipts,
		"keyboard focus inspection spends no turn, changes no snapshot and consumes no RNG")
	stage._action_buttons["pass"].grab_focus()
	_check(stage._labels["log"].text == ordinary_log,
		"moving keyboard focus off the rank seat restores the prior action message")
	# Separate Hanging fixture on hero_2.
	stage._seat_buttons["hero_2"].mouse_entered.emit()
	var hero_2_detail := str(stage._labels["log"].text)
	_check(hero_2_detail == stage.status_detail("hero", 2) and
		hero_2_detail.contains("R2") and hero_2_detail.contains(str(hero_2["name"])) and
		hero_2_detail.contains("HP 0/%d" % int(hero_2["max_hp"])) and
		hero_2_detail.contains("FRAY 150/200") and hero_2_detail.contains("HANGING") and
		stage._rank_meters["hero_2"]["hp"].value == 0.0 and
		stage._rank_meters["hero_2"]["hp_text"].text == "HANGING" and
		stage._rank_meters["hero_2"]["fray"].value == 150.0 and
		stage._rank_meters["hero_2"]["fray_text"].text == "FRAY 150" and
		stage._rank_meters["hero_2"]["fray"].tooltip_text == _fray_full(150) and
		stage._rank_meters["hero_2"]["root"].visible and
		not stage._labels["hero_2"].visible and
		not hero_2_detail.contains("DODGE") and not hero_2_detail.contains("GUARD"),
		"Hanging hero fixture exposes HP 0, FRAY 150 and HANGING state in seat and detail readout")
	_check(battle.state_snapshot() == view_snapshot and battle.rng_state() == view_rng and
		stage.receipts.size() == view_receipts,
		"viewing Hanging seat preserves battle snapshot, RNG and receipt count")
	stage._seat_buttons["hero_2"].mouse_exited.emit()
	# Second high-FRAY witness runs on the public mounted route.
	hero_2["fray"] = 199
	stage._refresh()
	var high_fray: Dictionary = stage._rank_meters["hero_2"]
	_check(high_fray["hp_text"].text == "HANGING"
		and high_fray["fray_text"].text == "FRAY 199"
		and high_fray["fray"].value == 199.0
		and high_fray["fray"].max_value == 200.0
		and high_fray["fray"].tooltip_text == _fray_full(199)
		and high_fray["root"].tooltip_text.contains(_fray_full(199))
		and high_fray["fray_text"].get_theme_color("font_color") == StitchedBattleChrome.AMBER,
		"public HANGING / FRAY 199 retains legible glance and exact status")
	_check_rank_font(high_fray["fray_text"], "public FRAY 199")
	_check_rank_font(high_fray["hp_text"], "public HANGING")
	stage._seat_buttons["hero_2"].grab_focus()
	_check(stage._seat_buttons["hero_2"].has_focus()
		and stage.status_detail("hero", 2).contains("FRAY 199/200")
		and stage._status_disclosure_label.text.contains("FRAY 199/200"),
		"keyboard focus retains full high-FRAY 199/200 disclosure")
	stage._action_buttons["pass"].grab_focus()
	_check(battle.rng_state() == view_rng and stage.receipts.size() == view_receipts,
		"high-FRAY and focus inspection spend no RNG or action")
	# Zero/removed statuses and expired/absent dodge_buff disappear on refresh.
	stage._seat_buttons["hero_1"].mouse_entered.emit()
	hero_1["statuses"]["guard"] = 0
	hero_1["statuses"]["exposed"] = 0
	hero_1["statuses"].erase("stun_resist")
	hero_1["dodge_buff"] = {"amount": 8, "turns": 0, "skip": false}
	foe_1["statuses"] = {"bleed": 0}
	foe_1["statuses"].erase("weak")
	hero_2["hanging"] = false
	hero_2["hp"] = int(hero_2["max_hp"])
	hero_2["fray"] = 0
	var cleared_snapshot := battle.state_snapshot()
	var cleared_rng := battle.rng_state()
	stage._refresh()
	_check(stage._labels["log"].text.contains("STATUS: none") and
		not stage._labels["log"].text.contains("GUARD") and
		not stage._labels["log"].text.contains("STUN RESIST") and
		not stage._labels["log"].text.contains("DODGE") and
		not stage.status_detail("hero", 1).contains("GUARD") and
		not stage.status_detail("hero", 1).contains("STUN RESIST") and
		not stage.status_detail("hero", 1).contains("DODGE") and
		not stage.status_detail("foe", 1).contains("BLEED") and
		not stage.status_detail("foe", 1).contains("WEAK") and
		not stage._labels["hero_1"].visible and not stage._labels["foe_1"].visible and
		stage._rank_meters["hero_2"]["hp_text"].text == "HP %d" % int(hero_2["hp"]) and
		stage._rank_meters["hero_2"]["fray"].value == 0.0 and
		not stage.status_detail("hero", 2).contains("HANGING"),
		"zero/removed statuses, expired temporary Dodge and cleared Hanging disappear on refresh")
	_check(battle.state_snapshot() == cleared_snapshot and battle.rng_state() == cleared_rng and
		stage.receipts.size() == view_receipts,
		"refreshing after status expiry spends no turn, snapshot or RNG")
	stage._seat_buttons["hero_1"].mouse_exited.emit()
	# Empty rank (foe_4) and scrap heap never leak stale or phantom status text.
	stage._seat_buttons["foe_4"].mouse_entered.emit()
	var empty_detail := str(stage._labels["log"].text)
	_check(not stage._figure_hits["foe_4"].visible and not stage._foot_plates["foe_4"].visible,
		"vacant fourth foe rank has no misleading artwork, plate or active mouse hotspot")
	_check(not stage._labels["foe_4"].visible and stage._labels["foe_4"].text.is_empty() and
		not stage._rank_meters["foe_4"]["root"].visible and
		empty_detail.contains("R4") and empty_detail.contains("EMPTY") and
		empty_detail.contains("STATUS: none") and
		not empty_detail.contains("BLEED") and not empty_detail.contains("GUARD") and
		not empty_detail.contains("DODGE") and not empty_detail.contains("HANGING"),
		"empty fourth foe rank is unambiguous and leaks no stale status text")
	battle._heaps.append({
		"id": "heap:test_scavenger", "side": "heap", "rank": 4,
		"hp": 9, "max_hp": 9, "foe_id": foe_1_id, "statuses": {"bleed": 4, "mark": 2},
	})
	var heap_snapshot := battle.state_snapshot()
	var heap_rng := battle.rng_state()
	stage._refresh()
	var heap_detail := str(stage._labels["log"].text)
	_check(not stage._figure_hits["foe_4"].visible and stage._foot_plates["foe_4"].visible
		and not stage._rank_meters["foe_4"]["root"].visible and stage._labels["foe_4"].visible,
		"heap-only fourth rank has a sewn scrap readout without a false living-foe meter")
	_check(stage._labels["foe_4"].text == "SCRAP 9 HP" and
		heap_detail.contains("R4") and heap_detail.contains("Scrap heap") and
		heap_detail.contains("SCRAP 9 HP") and heap_detail.contains("STATUS: none") and
		not heap_detail.contains("BLEED") and not heap_detail.contains("MARK"),
		"scrap heap rank displays heap HP and STATUS: none without phantom statuses")
	_check(battle.state_snapshot() == heap_snapshot and battle.rng_state() == heap_rng and
		stage.receipts.size() == view_receipts,
		"inspecting empty and scrap-heap seats preserves snapshot, RNG and receipt count")
	stage._seat_buttons["foe_4"].mouse_exited.emit()
	var before_heap_click := battle.state_snapshot()
	var heap_rng_before := battle.rng_state()
	_figure_click(stage, "foe_4")
	_check(before_heap_click == battle.state_snapshot() and heap_rng_before == battle.rng_state()
		and stage.receipts.size() == view_receipts,
		"heap-only rank-four figure activation is fail-closed and consumes no seeded RNG")
	_check(stage._labels["log"].text == ordinary_log,
		"exiting empty/heap rank seat restores the prior action message")
	for unit_id in saved_units:
		battle._units[unit_id] = saved_units[unit_id]
	battle._heaps = saved_heaps
	stage._refresh()


func _mouse_activate(button: Button) -> void:
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = button.get_global_rect().get_center()
		click.pressed = down
		root.push_input(click, true)
	await process_frame


func _keyboard_activate(button: Button) -> void:
	button.grab_focus()
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = down
		root.push_input(key, true)
	await process_frame


func _verify_turn_action_cues(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var baseline := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipts := stage.receipts.duplicate(true)
	var acting_id := battle.current_actor_id()
	var original_order := battle._order.duplicate()
	var original_index := battle._turn_index
	var original_cut := battle._thread_cuts.duplicate(true)
	var original_boss := battle._boss_encounter
	var original_outcome := battle._outcome
	var heroes := battle.get_heroes()
	var foes := battle.get_foes()
	_check(heroes.size() == 4 and foes.size() == 3 and battle.current_side() == "hero"
		and not battle.is_over() and not battle.is_boss_encounter(),
		"precondition: mounted public S2 four-versus-three has a live non-boss hero action")
	var front: Dictionary = {}
	var next: Dictionary = {}
	for hero in heroes:
		if int(hero["rank"]) == 1:
			front = hero
		elif int(hero["rank"]) == 2:
			next = hero
	_check(not front.is_empty() and not next.is_empty(),
		"precondition: two living adjacent front-rank heroes exist")
	if front.is_empty() or next.is_empty():
		return
	var front_id := str(front["id"])
	var next_id := str(next["id"])
	battle._order[battle._turn_index] = front_id
	stage._refresh()
	var front_move: Button = stage._action_buttons["move_front"]
	var back_move: Button = stage._action_buttons["move_back"]
	var re_tie: Button = stage._action_buttons["re_tie"]
	var pass_button: Button = stage._action_buttons["pass"]
	var retreat: Button = stage._action_buttons["retreat"]
	_check(front_move.disabled and front_move.tooltip_text.contains("rank 0")
		and not back_move.disabled and back_move.tooltip_text.contains(str(next["name"]))
		and back_move.tooltip_text.contains("Swap") and back_move.tooltip_text.contains("Spends")
		and re_tie.disabled and re_tie.tooltip_text.contains("intact")
		and not pass_button.disabled and pass_button.tooltip_text.contains("Spend")
		and not retreat.disabled and retreat.tooltip_text.contains("75%")
		and retreat.tooltip_text.contains("+15 fray") and retreat.tooltip_text.contains("no rewards")
		and retreat.tooltip_text.contains("Failure spends"),
		"rank-one hero shows true edge/adjacent swap, intact-thread, Pass and full Retreat outcomes")
	var focus_snapshot := battle.state_snapshot()
	var focus_rng := battle.rng_state()
	pass_button.release_focus()
	front_move.mouse_entered.emit()
	_check(stage._labels["preview"].text.contains("Move front") or
		stage._labels["preview"].tooltip_text.contains("rank 0"),
		"blocked Move displays the current edge reason on hover")
	front_move.mouse_exited.emit()
	back_move.grab_focus()
	_check(back_move.has_focus() and stage._labels["preview"].tooltip_text.contains("Swap"),
		"keyboard action focus exposes actual adjacent swap consequence")
	back_move.release_focus()
	stage._refresh()
	_check(battle.state_snapshot() == focus_snapshot and battle.rng_state() == focus_rng
		and stage.receipts == receipts,
		"hover, keyboard focus and repeated action refresh preserve snapshot, RNG and receipts")
	# A TANGLED actor is blocked by the same move gate as the real command.
	var original_status: Dictionary = battle._units[front_id]["statuses"].duplicate(true)
	battle._units[front_id]["statuses"]["tangled"] = 1
	stage._refresh()
	_check(back_move.disabled and back_move.tooltip_text.contains("tangled")
		and not bool(stage.submit_move(1).get("ok")),
		"authoritative tangled-movement refusal has matching blocked Move tooltip")
	battle._units[front_id]["statuses"] = original_status
	# A cut on the actor forbids both directions, offers Re-tie and cannot be
	# circumvented by invoking a disabled native button's original signal.
	battle._thread_cuts[front_id] = 1
	stage._refresh()
	var cut_snapshot := battle.state_snapshot()
	var cut_rng := battle.rng_state()
	_check(back_move.disabled and back_move.tooltip_text.contains("thread cut")
		and re_tie.disabled == false and re_tie.tooltip_text.contains("snipped")
		and re_tie.tooltip_text.contains("spends"),
		"authoritative actor cut blocks movement and offers accurate Re-tie help")
	back_move.pressed.emit()
	_check(battle.state_snapshot() == cut_snapshot and battle.rng_state() == cut_rng
		and stage.receipts == receipts,
		"forced disabled Move signal fails closed with no state or RNG spend")
	battle._thread_cuts = original_cut.duplicate(true)
	# Rules currently permit stepping into a rank vacated by a lost hero.
	# Surface that real behavior instead of inventing an unsupported legal gate.
	var saved_ally: Dictionary = battle._units[next_id].duplicate(true)
	battle._units[next_id]["lost"] = true
	stage._refresh()
	_check(not back_move.disabled and back_move.tooltip_text.contains("empty rank 2")
		and back_move.tooltip_text.contains("no living ally"),
		"vacant neighbor uses the actual StitchedRules move legality, not a fictitious swap")
	battle._units[next_id] = saved_ally
	# Enemy turn and victory are fail-closed even when an existing pressed
	# callback is emitted manually; no listeners are duplicated.
	battle._order[battle._turn_index] = str(foes[0]["id"])
	stage._refresh()
	_check(battle.current_side() == "foe" and
		front_move.disabled and back_move.disabled and re_tie.disabled
		and pass_button.disabled and retreat.disabled
		and pass_button.tooltip_text.contains("enemy turn") and retreat.tooltip_text.contains("enemy turn"),
		"enemy turn suppresses every hero command with a current explanation")
	var enemy_snapshot := battle.state_snapshot()
	var enemy_rng := battle.rng_state()
	pass_button.pressed.emit()
	retreat.pressed.emit()
	_check(battle.state_snapshot() == enemy_snapshot and battle.rng_state() == enemy_rng
		and stage.receipts == receipts, "forced enemy-turn buttons cannot dispatch hero actions")
	battle._order[battle._turn_index] = front_id
	battle._boss_encounter = true
	stage._refresh()
	var boss_snapshot := battle.state_snapshot()
	var boss_rng := battle.rng_state()
	_check(retreat.disabled and retreat.tooltip_text.contains("boss encounter")
		and retreat.tooltip_text.contains("75%") and not pass_button.disabled,
		"boss disables Retreat while retaining its odds/consequences and legal Pass")
	retreat.pressed.emit()
	_check(battle.state_snapshot() == boss_snapshot and battle.rng_state() == boss_rng
		and stage.receipts == receipts, "boss Retreat press refuses before any seeded roll")
	battle._boss_encounter = original_boss
	battle._outcome = "victory"
	stage._refresh()
	_check(battle.is_over() and front_move.disabled and back_move.disabled
		and re_tie.disabled and pass_button.disabled and retreat.disabled
		and re_tie.tooltip_text.contains("battle ended"),
		"ended battle refuses all five controls and clears stale turn availability")
	battle._outcome = original_outcome
	battle._order = original_order
	battle._turn_index = original_index
	battle._thread_cuts = original_cut
	stage._refresh()
	_check(battle.current_actor_id() == acting_id and battle.state_snapshot() == baseline
		and battle.rng_state() == rng and stage.receipts == receipts,
		"restored real actor has pristine snapshot, seeded RNG and receipts after all cue probes")
	_check(stage._action_buttons["re_tie"].disabled
		and not stage._action_buttons["pass"].disabled
		and not stage._action_buttons["retreat"].disabled,
		"all stale thread, boss and enemy-turn explanations clear after the actor is restored")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var boot = root.get_node_or_null("LiveWebPlaytestBoot")
	_check(boot != null, "Web startup boot autoload exists")
	_check(BOOT.SCREENS.has("stitched_battle") and
		boot.screen_from_query("?screen=stitched_battle") == "stitched_battle" and
		boot.screen_from_query("?screen=stitched_battle&screen=battle") == "",
		"only the exact, unambiguous public query is admitted")
	_check(not ProjectSettings.has_setting("patchwork/combat_mode"), "S2 needs no retired combat setting")
	var configured_theme_path := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	var configured_theme := load(configured_theme_path) as Theme
	_check(configured_theme_path == "res://assets/fonts/patchwork_theme.tres"
		and configured_theme != null and configured_theme.default_font == StitchedBattleChrome.RANK_FONT
		and configured_theme != load("res://themes/gothic_theme.tres"),
		"precondition: ACTUAL project mounts patchwork theme, not rejected Gothic default")
	var config := StitchedBattleScreen.read_preview()
	_check(str(config.get("mode", "")) == "stitched" and config.get("heroes", []).size() == 4 and
		config.get("foes", []).size() == 3, "representative seed and real 4v3 inputs exist")
	var shipped_catalog := StitchedParts.build_catalog(config.get("parts", []))
	_check(bool(shipped_catalog.get("ok", false)) and not config.has("parts_path") and
		shipped_catalog.get("by_id", {}).has("warden_head_iron_helm") and
		shipped_catalog.get("by_id", {}).has("any_arm_red_thread"),
		"Web S2 data ships its own validated part entries; excluded test fixtures are not needed")
	var copy: Array = []
	for repetition in range(2):
		var app := _spawn()
		await process_frame
		var global_seed := 204915
		seed(global_seed)
		var expected_global := randi()
		seed(global_seed)
		var stage: StitchedBattleScreen = await _stage(app)
		if stage == null:
			app.free()
			continue
		await process_frame
		var battle := stage.battle
		_check(stage.theme == null and stage.get_theme_font("font") == configured_theme.default_font
			and (stage._rank_meters["hero_1"]["hp_text"].get_theme_font("font") as FontVariation).base_font == StitchedBattleChrome.RANK_FONT,
			"public screen inherits configured patchwork theme, with only local rank fonts")
		_check(battle != null and battle.is_valid() and battle.get_heroes().size() == 4 and
			battle.get_foes().size() == 3 and stage._puppets.size() == 8,
			"mounted stage is seeded 4v3 with 8 potential stage ranks")
		_verify_stage_art(stage)
		_verify_fourth_foe(stage)
		_verify_worn_layout(stage)
		_verify_turn_action_cues(stage)
		_check(stage._unit_at("foe", 4).is_empty() and
			stage._seat_buttons.has("foe_4") and not stage._puppets["foe_4"].visible,
			"fourth foe rank is empty, available only for a later summon")
		_check(stage.is_visible_in_tree() and not app.title_view.is_visible_in_tree() and
			app.run_map == null and app.deck == null and app.run_rng == null and app.run_deck.is_empty(),
			"public entry displays S2 without entering card battle or constructing card resources")
		_check(stage._labels["round"].text.contains("ROUND") and
			stage._labels["order"].text.contains("TURN ORDER") and
			stage._labels["candle"].text.contains("CANDLE") and
			stage._labels["stats"].text.contains("Fray") and
			stage._action_buttons["pass"].is_visible_in_tree(),
			"full round/order/candle/HP/fray/action overlays mounted at 1280x720")
		_check(randi() == expected_global, "public mounting consumes no global RNG")
		var pristine := battle.state_snapshot()
		var rng := battle.rng_state()
		_check(not (await boot.enter_preview(app, "stitched_battle")) and battle.state_snapshot() == pristine,
			"re-entering an already active preview rejects without rolls")
		_check(not bool(stage.submit_part("missing_part", 1).get("ok")) and
			not bool(stage.submit_part("missing_part", 5).get("ok")) and
			not bool(stage.submit_target("foe", 0).get("ok")) and
			not bool(stage.submit_target("foe", 5).get("ok")) and
			not bool(stage.submit_move(0).get("ok")) and
			not bool(stage.submit_re_tie().get("ok")),
			"wrong part, out-of-bounds rank, invalid move and unsnipped Re-tie fail closed")
		_check(battle.state_snapshot() == pristine and battle.rng_state() == rng,
			"every rejected action preserves complete authoritative state and RNG")
		var actor := battle.get_unit(battle.current_actor_id())
		_check(str(actor.get("side", "")) == "hero", "preview advances initial foe turns to a live hero")
		# Hover/selection is pure, including disabled-range calculations and repeated UI refresh.
		var selected := false
		for slot in StitchedBattleScreen.SLOTS:
			if stage.select_part(slot):
				selected = true
				for i in range(4):
					stage._refresh()
					var key := _rank_key(stage)
					if not key.is_empty():
						_check(stage.legal_targets().has(key), "preview exposes only actual legal target masks")
				break
		_check(selected and battle.state_snapshot() == pristine and battle.rng_state() == rng,
			"part selection and repeated hover previews spend no turn or RNG")
		var chosen_key := _rank_key(stage)
		var selected_slot_before := stage._selected_part
		var illegal_witness := 0
		for key in stage._figure_hits:
			if not stage._puppets[key].visible or stage.legal_targets().has(key):
				continue
			illegal_witness += 1
			_check(stage._target_buttons[key].disabled and
				stage._puppets[key].modulate == Color.WHITE,
				"unlit occupied %s has no keyboard activation or amber art highlight" % key)
			_figure_click(stage, key)
		_check(illegal_witness > 0 and battle.state_snapshot() == pristine
			and battle.rng_state() == rng and stage.receipts.is_empty(),
			"illegal figure clicks cannot spend a turn, roll or create a receipt")
		stage._selected_part = ""
		stage._refresh()
		_figure_click(stage, chosen_key)
		_check(stage.legal_targets().is_empty() and battle.state_snapshot() == pristine
			and battle.rng_state() == rng and stage.receipts.is_empty(),
			"unselected formerly legal figure cannot commit or spend RNG")
		_check(stage.select_part(selected_slot_before),
			"reselecting a real worn part restores the authentic legal target mask")
		_verify_status_readout(stage)
		_check(battle.state_snapshot() == pristine and battle.rng_state() == rng,
			"status readout fixture cleanup leaves pristine snapshot and RNG intact")
		# A torn equipped seam disables its own action, with no effect on the action receipt.
		var selected_slot := stage._selected_part
		if not selected_slot.is_empty():
			var worn: Dictionary = battle._units[battle.current_actor_id()]["parts"][selected_slot]
			worn["torn"] = true
			var torn_snapshot := battle.state_snapshot()
			stage._refresh()
			_figure_click(stage, chosen_key)
			_check(not stage.select_part(selected_slot) and
				not bool(stage.submit_part(str(worn["id"]), 1).get("ok")) and
				battle.state_snapshot() == torn_snapshot and battle.rng_state() == rng
				and stage.receipts.is_empty(),
				"torn worn part and stale figure hit cannot spend a turn or roll")
			worn["torn"] = false
			stage._refresh()
		# Snipped thread blocks swaps; Re-tie is only enabled with an actual authoritative cut.
		battle._thread_cuts[battle.current_actor_id()] = int(actor["rank"])
		var cut_snapshot := battle.state_snapshot()
		_check(not bool(stage.submit_move(1).get("ok")) and battle.state_snapshot() == cut_snapshot,
			"snipped thread refuses crossing without changing state or RNG")
		stage._refresh()
		_check(not stage._action_buttons["re_tie"].disabled and stage.battle.thread_cuts().has(battle.current_actor_id()),
			"Re-tie is enabled only for an authoritative snipped thread")
		var retie_before := stage.receipts.size()
		var retie_actor := battle.current_actor_id()
		await _keyboard_activate(stage._action_buttons["re_tie"])
		var retie: Dictionary = stage.receipts[retie_before] if stage.receipts.size() > retie_before else {}
		var retie_commits := 0
		for index in range(retie_before, stage.receipts.size()):
			if stage.receipts[index].get("action") == "re_tie" and stage.receipts[index].get("actor") == retie_actor:
				retie_commits += 1
		_check(bool(retie.get("ok", false)) and retie_commits == 1 and
			stage.receipts[retie_before].get("action") == "re_tie" and
			not battle.thread_cuts().has(str(retie.get("actor", ""))),
			"real keyboard Re-tie dispatches exactly once, clears the cut and spends the acting turn")
		var receipt_log := str(stage._labels["log"].text)
		var post_retie_snapshot := battle.state_snapshot()
		var post_retie_rng := battle.rng_state()
		var post_retie_receipts := stage.receipts.size()
		stage._seat_buttons["hero_1"].mouse_entered.emit()
		_check(stage._labels["log"].text == stage.status_detail("hero", 1) and
			stage._labels["log"].text != receipt_log,
			"hovering a seat after a committed turn inspects that seat's status detail")
		stage._seat_buttons["hero_1"].mouse_exited.emit()
		_check(stage._labels["log"].text == receipt_log and
			battle.state_snapshot() == post_retie_snapshot and
			battle.rng_state() == post_retie_rng and
			stage.receipts.size() == post_retie_receipts,
			"ending seat inspection restores the committed action receipt without spending RNG or turns")
		# Repeatable public trace: the same entrance and the same approved action sequence.
		stage.set_reduced_motion(true)
		_check(stage.reduced_motion and stage._puppets["hero_1"].is_processing() == false,
			"reduced motion suppresses puppet idle/attack tweens without changing combat")
		_check(stage.battle.current_side() == "hero", "foe AI returns control to heroes using legal authored abilities or Pass")
		_check(not (await _choose_legal(stage, repetition == 0)).is_empty(),
			"real mounted part resolves through both figure click and keyboard rank activation")
		var after := battle.state_snapshot()
		_check(stage.receipts.size() > 1 and battle.rng_state() == int(after["rng_state"]),
			"recorded action and foe responses have one seeded authoritative RNG state")
		if repetition == 0:
			copy = [after, stage.receipts.duplicate(true)]
		else:
			_check(copy.size() == 2 and copy[0] == after and copy[1] == stage.receipts,
				"independent public entries replay identical state, RNG and ordered receipts")
		stage._action_buttons["help"].pressed.emit()
		_check(stage._action_buttons["exit"].is_visible_in_tree(),
			"public preview exposes Back to title through Help & settings")
		stage._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(boot.stitched_view == null and app.title_view.is_visible_in_tree() and
			app.run_map == null and app.deck == null, "exit unmounts isolated S2 and restores original title")
		var reopened: StitchedBattleScreen = await _stage(app)
		_check(reopened != null and reopened != stage and reopened.battle.is_valid() and
			reopened.battle.get_heroes().size() == 4, "re-entering after exit starts a fresh seeded Stitched session")
		if reopened != null and reopened.battle.current_side() == "hero":
			var direction := -1 if reopened._can_move(-1) else 1
			var move_before := reopened.receipts.size()
			var move_button: Button = reopened._action_buttons["move_front" if direction == -1 else "move_back"]
			_check(not move_button.disabled, "precondition: selected native Move has live authority")
			await _mouse_activate(move_button)
			var move_receipt: Dictionary = reopened.receipts[move_before] if reopened.receipts.size() > move_before else {}
			var hero_moves := 0
			for receipt_index in range(move_before, reopened.receipts.size()):
				if reopened.receipts[receipt_index].get("action") == "move" and reopened.receipts[receipt_index].get("actor") == move_receipt.get("actor"):
					hero_moves += 1
			_check(bool(move_receipt.get("ok", false)) and hero_moves == 1
				and move_receipt.get("action") == "move",
				"one genuine mouse click on sewn Move commits exactly one real rank swap")
			var pass_before := reopened.receipts.size()
			var passing_actor := reopened.battle.current_actor_id()
			var pass_button: Button = reopened._action_buttons["pass"]
			_check(not pass_button.disabled, "precondition: Pass is enabled for next live hero")
			await _keyboard_activate(pass_button)
			var pass_receipt: Dictionary = reopened.receipts[pass_before] if reopened.receipts.size() > pass_before else {}
			var hero_passes := 0
			for receipt_index in range(pass_before, reopened.receipts.size()):
				if reopened.receipts[receipt_index].get("action") == "pass" and reopened.receipts[receipt_index].get("actor") == passing_actor:
					hero_passes += 1
			_check(bool(pass_receipt.get("ok", false)) and hero_passes == 1
				and pass_receipt.get("action") == "pass",
				"one keyboard Enter on sewn Pass commits exactly one spent hero turn")
			var retreat_before := reopened.receipts.size()
			var retreat_rng := reopened.battle.rng_state()
			_check(not reopened._action_buttons["retreat"].disabled,
				"precondition: real non-boss Retreat is enabled")
			await _mouse_activate(reopened._action_buttons["retreat"])
			var retreat_receipt: Dictionary = reopened.receipts[retreat_before] if reopened.receipts.size() > retreat_before else {}
			var hero_retreats := 0
			for receipt_index in range(retreat_before, reopened.receipts.size()):
				if reopened.receipts[receipt_index].get("action") == "retreat":
					hero_retreats += 1
			_check(bool(retreat_receipt.get("ok", false)) and hero_retreats == 1
				and retreat_receipt.get("action") == "retreat"
				and reopened.battle.rng_state() != retreat_rng,
				"one real Retreat click rolls seeded authority once and records success/failure")
		boot.exit_stitched_preview(app)
		await process_frame
		_check(app.title_view.is_visible_in_tree() and boot.stitched_view == null and
			not ProjectSettings.has_setting("patchwork/combat_mode"),
			"exiting S2 restores title, unmounts preview and leaves retired setting absent")
		app.free()
		await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s2_battle_screen_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
