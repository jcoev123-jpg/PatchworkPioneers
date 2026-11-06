extends SceneTree
## S5 presentation-only turn queue regression; a real StitchedBattleScreen owns every live projection.

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
var failures: Array[String] = []
var checks := 0


class ArrivalBattle extends StitchedBattleScreen:
	var observe: Callable

	func _refresh() -> void:
		super._refresh()
		if observe.is_valid():
			observe.call(self)


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _mount() -> Dictionary:
	var host := Control.new()
	host.name = "GothicBattleHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var stage := StitchedBattleScreen.new()
	var config := StitchedBattleScreen.read_preview()
	_check(stage.begin(config), "precondition: valid seeded Stitched S2 preview begins")
	host.add_child(stage)
	return {"host": host, "stage": stage}


func _living_round_entries(battle: StitchedRules) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id in battle.turn_order():
		var unit := battle.get_unit(str(id))
		if unit.is_empty() or bool(unit.get("dead", false)) or bool(unit.get("lost", false)):
			continue
		if str(unit.get("side", "")) == "foe" and int(unit.get("hp", 0)) <= 0:
			continue
		entries.append(unit)
	return entries


func _verify_order(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var ribbon: StitchedTurnOrderRibbon = stage._turn_ribbon
	var expected := _living_round_entries(battle)
	_check(expected.size() >= 6 and ribbon.displayed_entries.size() == expected.size(),
		"precondition: populated S2 round is projected without omitted or added actors")
	for i in range(expected.size()):
		var unit: Dictionary = expected[i]
		var tag := ribbon.tag_at(i)
		var picture := ribbon.portrait_at(i)
		var marker := ribbon.marker_at(i)
		var actor_id := str(unit["id"])
		var rank := int(unit["rank"])
		var side := str(unit["side"])
		var full_name := str(unit["name"])
		var art_path := str(ROSTER.art_paths(actor_id).get("idle", ""))
		var has_art := not art_path.is_empty() and ResourceLoader.exists(art_path, "Texture2D")
		_check(str(ribbon.displayed_entries[i]["id"]) == actor_id and tag.visible and
			tag.get_node("SideRank").text == (("H" if side == "hero" else "F") + str(rank)) and
			tag.tooltip_text.contains(full_name) and tag.tooltip_text.contains(side.capitalize()) and
			tag.tooltip_text.contains("rank %d" % rank),
			"queue slot %d preserves public actor ID, H/F rank, full name and side/rank tooltip" % i)
		_check(picture.visible == has_art and
			(picture.texture == load(art_path) if has_art else picture.texture == null) and
			tag.get_node("NameFallback").visible == not has_art,
			"queue slot %d uses its own existing canonical idle image, otherwise a visible name fallback" % i)
		var active := not battle.is_over() and actor_id == battle.current_actor_id()
		_check((marker.text == "NOW") == active and
			(marker.get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER if active else true),
			"queue slot %d identifies only the authoritative acting ID in amber" % i)
	for i in range(expected.size(), StitchedTurnOrderRibbon.MAX_TAGS):
		_check(not ribbon.tag_at(i).visible, "unused tag %d has no stale actor" % i)


func _text_fits(label: Label) -> bool:
	if label.text.is_empty():
		return false
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x - 1.0 and (
		font.get_height(font_size) <= label.size.y)


func _check_disclosure(ribbon: StitchedTurnOrderRibbon, index: int, full_name: String, detail: String = "") -> void:
	var tag := ribbon.tag_at(index)
	var tip: NinePatchRect = tag.get_node("FocusTooltip")
	var detail_label: Label = tip.get_node("TooltipText")
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(tag.visible and tag.tooltip_text.contains(full_name) and
		detail_label.text == tag.tooltip_text and (detail.is_empty() or detail_label.text.contains(detail)),
		"slot %d retains full public actor/status text in both disclosure channels" % index)
	tag.mouse_entered.emit()
	_check(tip.visible and screen.encloses(tip.get_global_rect()) and
		tip.get_global_rect().encloses(detail_label.get_global_rect()) and
		detail_label.get_minimum_size().y <= detail_label.size.y and
		detail_label.get_visible_line_count() == detail_label.get_line_count(),
		"slot %d mouse hover shows the complete on-screen Gothic sewn tooltip" % index)
	tag.mouse_exited.emit()
	_check(not tip.visible, "slot %d mouse leave closes the hover tooltip" % index)
	tag.grab_focus()
	_check(tag.has_focus() and tip.visible and screen.encloses(tip.get_global_rect()) and
		tip.get_global_rect().encloses(detail_label.get_global_rect()) and
		detail_label.get_minimum_size().y <= detail_label.size.y and
		detail_label.get_visible_line_count() == detail_label.get_line_count(),
		"slot %d keyboard focus discloses the same complete on-screen tooltip" % index)
	tag.release_focus()
	_check(not tip.visible, "slot %d keyboard blur closes its tooltip" % index)


func _check_geometry(ribbon: StitchedTurnOrderRibbon, count: int, stage: StitchedBattleScreen) -> void:
	var top_band := Rect2(Vector2(12, 10), Vector2(1256, 82))
	var stage_area := Rect2(Vector2(0, 95), Vector2(1280, 360))
	var round_rect := Rect2(stage._labels["round"].global_position, stage._labels["round"].size)
	var candle_rect := Rect2(stage._labels["candle"].global_position, stage._labels["candle"].size)
	var order_rect := Rect2(stage._labels["order"].global_position, stage._labels["order"].size)
	var previous_right := -1.0
	_check(ribbon.displayed_entries.size() == count and count > 0 and
		ribbon.tag_at(count - 1).visible,
		"precondition: populated %d-slot layout exposes every actor" % count)
	for i in range(count):
		var tag := ribbon.tag_at(i)
		var rect := tag.get_global_rect()
		_check(tag.visible and rect.size.x >= 69 and rect.size.y == 42 and top_band.encloses(rect) and
			Rect2(ribbon.global_position, Vector2(690, 42)).encloses(rect) and
			tag.get_node("SewnPlate").get_global_rect() == rect and
			not rect.intersects(stage_area) and not rect.intersects(round_rect) and
			not rect.intersects(candle_rect) and not rect.intersects(order_rect) and
			(i == 0 or rect.position.x - previous_right >= 8.0),
			"tag %d in %d-slot layout fits top band without hitting stage/round/candle/header" % [i, count])
		var portrait: TextureRect = tag.get_node("ActorPortrait")
		var fallback: Label = tag.get_node("NameFallback")
		var rank: Label = tag.get_node("SideRank")
		var marker: Label = tag.get_node("NowMarker")
		var face_rect := portrait.get_global_rect() if portrait.visible else fallback.get_global_rect()
		var rank_rect := rank.get_global_rect()
		var cue_rect := marker.get_global_rect()
		_check(portrait.get_global_rect() == fallback.get_global_rect() and
			face_rect.size.x >= 24.0 and rank_rect.size.x >= 34.0,
			"tag %d retains readable portrait and text cells at every capacity" % i)
		_check(portrait.visible != fallback.visible and rect.encloses(face_rect) and
			rect.encloses(rank_rect) and rect.encloses(cue_rect) and
			not face_rect.intersects(rank_rect) and not face_rect.intersects(cue_rect) and
			not rank_rect.intersects(cue_rect) and
			face_rect.end.x + 3.0 <= rank_rect.position.x and
			rank_rect.end.y + 2.0 <= cue_rect.position.y,
			"tag %d portrait/fallback, rank and status occupy disjoint measured sewn-chip cells" % i)
		_check(rank.clip_text and marker.clip_text and _text_fits(rank) and _text_fits(marker) and
			marker.get_theme_font_size("font_size") >= 10 and
			(marker.text == "NOW" or marker.text == StitchedTurnStatusCues.cue(ribbon.displayed_entries[i])) and
			(fallback.visible == false or (fallback.clip_text and _text_fits(fallback))),
			"tag %d measured Gothic glyphs fit rank, NOW/status and name fallback labels without clipping" % i)
		var fabric: NinePatchRect = tag.get_node("SewnPlate")
		var tint := fabric.self_modulate
		# Even a white fabric texel cannot exceed this opaque tint's luminance.
		var foreground := marker.get_theme_color("font_color")
		_check(fabric.texture == load("res://assets/paper/ui/panel_felt.png") and
			fabric.modulate == Color.WHITE and tint.a == 1.0 and
			(foreground.srgb_to_linear().get_luminance() + 0.05) / (tint.srgb_to_linear().get_luminance() + 0.05) >= 4.5 and
			rank.get_theme_color("font_color") == StitchedTurnOrderRibbon.BONE and
			foreground == (StitchedTurnOrderRibbon.AMBER if marker.text == "NOW" else StitchedTurnOrderRibbon.BONE),
			"tag %d uses dark fabric with high-contrast bone text and amber NOW" % i)
		previous_right = rect.end.x
	_check(previous_right <= ribbon.global_position.x + 690 and previous_right <= 1260,
		"%d-slot ribbon ends within its allocation and before right top-band edge" % count)


func _observe_arrival(stage: StitchedBattleScreen, count: int, evidence: Array) -> void:
	if not evidence.is_empty():
		return
	var battle := stage.battle
	var ribbon := stage._turn_ribbon
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 4 and
		battle.turn_order().size() == count and ribbon.displayed_entries.size() == count and
		battle.current_actor_id() == StitchedRules.WALK_MIMIC_ID,
		"precondition: real mounted %d-turn 4v4 arrival before automatic ambush action" % count)
	_verify_order(stage)
	_check_geometry(ribbon, count, stage)
	var boss_slots := 0
	for i in range(ribbon.displayed_entries.size()):
		var unit: Dictionary = ribbon.displayed_entries[i]
		if unit.id == "fray_scavenger":
			boss_slots += 1
		_check_disclosure(ribbon, i, str(unit.name))
	_check(boss_slots == (2 if count == 9 else 1),
		"real %d-turn order preserves every repeated boss slot" % count)
	_check(battle.state_snapshot() == snapshot and battle.rng_state() == rng and stage.receipts.is_empty(),
		"inspection of real arrival projection spends no turn, receipt or RNG")
	evidence.append({"snapshot": snapshot, "rng": rng, "entries": ribbon.displayed_entries.duplicate(true)})


func _check_live_arrivals() -> void:
	for count in [8, 9]:
		var replay: Array = []
		for attempt in range(2):
			var host := Control.new()
			host.size = Vector2(1280, 720)
			host.theme = load("res://themes/gothic_theme.tres")
			root.add_child(host)
			var stage := ArrivalBattle.new()
			var config := StitchedBattleScreen.read_preview()
			config.walk_mimic = true
			if count == 9:
				config.foes[0].is_boss = true
				config.foes[0].turns_per_round = 2
			var evidence: Array = []
			stage.observe = _observe_arrival.bind(count, evidence)
			_check(stage.begin(config), "precondition: legal live arrival starts with %d public slots" % count)
			host.add_child(stage)
			await process_frame
			_check(evidence.size() == 1 and not stage.receipts.is_empty() and
				stage.battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty() and
				stage._turn_ribbon.displayed_entries.size() == count - 1 and
				not stage._turn_ribbon.tag_at(count - 1).visible and
				stage._turn_ribbon.tag_at(count - 1).tooltip_text.is_empty(),
				"real ambush commits then clears its vacated disclosure slot")
			_verify_order(stage)
			_check_geometry(stage._turn_ribbon, count - 1, stage)
			if attempt == 0:
				replay = evidence.duplicate(true)
			else:
				_check(not evidence.is_empty() and evidence == replay,
					"seeded %d-turn mounted arrival replays the identical order, state and RNG" % count)
			host.free()


func _check_live_death() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var config := StitchedBattleScreen.read_preview()
	# Legal fragile encounter fixture; all attacks still use authored hero parts.
	for foe in config.foes:
		foe.max_hp = 1
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(config), "precondition: real fragile encounter starts")
	host.add_child(stage)
	await process_frame
	var death_id := ""
	for step in range(24):
		if stage.battle.is_over() or not death_id.is_empty():
			break
		var accepted := false
		for slot in ["head", "arms", "torso", "legs"]:
			if not stage.select_part(slot):
				continue
			for key: String in stage.legal_targets():
				if not key.begins_with("foe_"):
					continue
				var last := stage._turn_ribbon.displayed_entries.size() - 1
				stage._turn_ribbon.tag_at(last).mouse_entered.emit()
				_check(stage._turn_ribbon.tag_at(last).get_node("FocusTooltip").visible,
					"precondition: vacated end slot has an open hover disclosure before attack")
				var target_rank := int(key.trim_prefix("foe_"))
				var target_id := ""
				var target_slot := -1
				for i in range(stage._turn_ribbon.displayed_entries.size()):
					var unit: Dictionary = stage._turn_ribbon.displayed_entries[i]
					if unit.side == "foe" and unit.rank == target_rank:
						target_id = str(unit.id)
						target_slot = i
				_check(target_slot >= 0, "precondition: advertised foe target owns a live ribbon slot")
				var target_tag := stage._turn_ribbon.tag_at(target_slot)
				target_tag.mouse_entered.emit()
				_check(target_tag.get_node("FocusTooltip").visible and
					target_tag.tooltip_text == StitchedTurnStatusCues.tooltip(stage.battle.get_unit(target_id)),
					"precondition: actual targeted foe's complete disclosure is open before attack")
				var receipt := stage.submit_target("foe", target_rank)
				_check(receipt.get("ok", false), "real selected part accepts its advertised foe target")
				if stage.battle.get_unit(target_id).get("dead", false):
					if target_tag.visible:
						var survivor: Dictionary = stage._turn_ribbon.displayed_entries[target_slot]
						_check(survivor.id != target_id and
							target_tag.tooltip_text == StitchedTurnStatusCues.tooltip(survivor) and
							target_tag.get_node("FocusTooltip/TooltipText").text == target_tag.tooltip_text,
							"dead foe's hovered slot now discloses its exact surviving actor")
					else:
						_check(target_tag.tooltip_text.is_empty() and not target_tag.get_node("FocusTooltip").visible,
							"dead foe's vacated hovered slot clears its disclosure")
				accepted = bool(receipt.get("ok", false))
				break
			if accepted:
				break
		if not accepted:
			_check(stage.submit_pass().get("ok", false), "real Pass reaches another attacking hero")
		for foe in stage.battle.get_foes():
			if foe.dead:
				death_id = str(foe.id)
	_check(not death_id.is_empty() and stage.battle.get_unit(death_id).get("dead", false),
		"non-vacuous public hero action actually kills a foe")
	var ribbon := stage._turn_ribbon
	_check(ribbon.displayed_entries.size() == 6 and not ribbon.tag_at(6).visible and
		ribbon.tag_at(6).tooltip_text.is_empty() and ribbon.marker_at(6).text.is_empty() and
		ribbon.portrait_at(6).texture == null and not ribbon.tag_at(6).get_node("FocusTooltip").visible,
		"real foe death compacts the mounted ribbon and clears the vacated open disclosure")
	for unit in ribbon.displayed_entries:
		_check(unit.id != death_id, "real dead foe is absent from every surviving tag")
	_verify_order(stage)
	_check_geometry(ribbon, 6, stage)
	host.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var data := _mount()
	var host: Control = data["host"]
	var stage: StitchedBattleScreen = data["stage"]
	await process_frame
	if stage.battle == null or stage._turn_ribbon == null:
		_check(false, "precondition: mounted real screen has StitchedRules and ribbon")
		_finish()
		return
	var battle := stage.battle
	var ribbon: StitchedTurnOrderRibbon = stage._turn_ribbon
	_check(host.theme != null and ribbon.is_ancestor_of(ribbon.tag_at(0)) and
		stage._labels["order"].text == "TURN ORDER" and
		battle.get_heroes().size() == 4 and battle.get_foes().size() == 3 and
		stage._puppets.size() == 8 and ribbon.get_child_count() == 9,
		"actual theme-bearing screen mounts a 4v3 seeded fight and a nine-place ribbon")
	_check(battle.turn_order().size() == 7 and battle.current_side() == "hero",
		"precondition: seven authoritative round slots and a live hero following automatic foe turns")
	_verify_order(stage)
	_check_geometry(ribbon, 7, stage)
	for i in range(ribbon.displayed_entries.size()):
		_check_disclosure(ribbon, i, str(ribbon.displayed_entries[i]["name"]))

	# Observe every passive path with both independent RNG streams snapshotted.
	seed(515273)
	var expected_global := randi()
	seed(515273)
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipts := stage.receipts.size()
	for repetition in range(3):
		stage._refresh()
		for i in range(ribbon.displayed_entries.size()):
			ribbon.tag_at(i).grab_focus()
			ribbon.tag_at(i).release_focus()
			ribbon.tag_at(i).mouse_entered.emit()
			ribbon.tag_at(i).mouse_exited.emit()
	stage.set_reduced_motion(true)
	stage.set_reduced_motion(false)
	_check(battle.state_snapshot() == snapshot and battle.rng_state() == rng and
		stage.receipts.size() == receipts and randi() == expected_global,
		"refresh, tooltips, hover and reduced motion are all state, action and local/global RNG free")
	_verify_order(stage)

	# Extra permitted foe rank and a repeated boss-action slot. This is view-only:
	# the battle's public seven-slot authority is not altered or rerolled.
	var nine: Array = _living_round_entries(battle)
	var last_foe: Dictionary = battle.get_foes().back().duplicate(true)
	last_foe["id"] = "author_fourth_foe_without_art"
	last_foe["name"] = "Unknown Fourth Lanternmaker Who Carries Mended Bells"
	last_foe["rank"] = 4
	last_foe["statuses"] = {"bleed": 2}
	nine.append(last_foe)
	ribbon.show_order(nine, battle.current_actor_id(), false)
	_check(ribbon.displayed_entries.size() == 8 and ribbon.tag_at(7).get_node("SideRank").text == "F4" and
		ribbon.portrait_at(7).texture == null and not ribbon.tag_at(8).visible,
		"eight-slot projection retains fourth foe fallback without a stale ninth tag")
	_check_geometry(ribbon, 8, stage)
	for i in range(8):
		_check_disclosure(ribbon, i, str(ribbon.displayed_entries[i]["name"]))
	var repeated: Dictionary = battle.get_foes().front()
	nine.append(repeated.duplicate(true))
	var repeated_id := str(repeated["id"])
	ribbon.show_order(nine, repeated_id, false)
	_check(ribbon.displayed_entries.size() == 9 and
		str(ribbon.displayed_entries[8]["id"]) == repeated_id and
		ribbon.tag_at(8).tooltip_text == ribbon.tag_at(nine.find(repeated)).tooltip_text and
		ribbon.tag_at(7).get_node("NameFallback").visible and
		ribbon.tag_at(7).get_node("SideRank").text == "F4" and
		ribbon.portrait_at(7).texture == null,
		"fourth foe lacks borrowed art and a second authored boss slot remains distinct")
	_check_geometry(ribbon, 9, stage)
	_check(ribbon.marker_at(7).text == "BLD" and
		ribbon.tag_at(7).tooltip_text.contains("Statuses: bleed 2"),
		"unmapped ninth-capacity foe keeps the existing legible BLD cue and full bleed tooltip")
	for i in range(9):
		_check_disclosure(ribbon, i, str(ribbon.displayed_entries[i]["name"]),
			"Statuses: bleed 2" if i == 7 else "")
	_check(ribbon.marker_at(8).text == "NOW" and
		ribbon.marker_at(nine.find(repeated)).text == "NOW",
		"repeated actor is highlighted by authoritative actor ID without peeking at turn index")

	# Dead and lost tokens are excluded without shuffling the survivors.
	var dead: Dictionary = nine[0].duplicate(true)
	var lost: Dictionary = nine[1].duplicate(true)
	dead["dead"] = true
	lost["lost"] = true
	var defeated: Dictionary = nine[7].duplicate(true)
	defeated["hp"] = 0
	var filtered: Array = [{}, dead, nine[2], lost, defeated, nine[3]]
	ribbon.show_order(filtered, str(dead["id"]), false)
	_check(ribbon.displayed_entries.size() == 2 and
		str(ribbon.displayed_entries[0]["id"]) == str(nine[2]["id"]) and
		str(ribbon.displayed_entries[1]["id"]) == str(nine[3]["id"]) and
		ribbon.marker_at(0).text != "NOW" and not ribbon.tag_at(2).visible,
		"empty/lost/dead/zero-HP entries disappear, order holds, dead actor cannot remain active")
	_check_geometry(ribbon, 2, stage)
	for i in range(2):
		_check_disclosure(ribbon, i, str(ribbon.displayed_entries[i]["name"]))
	ribbon.show_order([{"id":"unmapped_no_art","name":"Lost Button Doll of the Unravelled Archive",
		"side":"foe","rank":3,"hp":12,"statuses":{"bleed":3}}], "", false)
	_check(ribbon.displayed_entries.size() == 1 and ribbon.portrait_at(0).texture == null and
		ribbon.tag_at(0).get_node("NameFallback").text.begins_with("Lost") and
		ribbon.tag_at(0).tooltip_text.contains("Lost Button Doll of the Unravelled Archive") and
		ribbon.marker_at(0).text == "BLD" and not ribbon.tag_at(1).visible,
		"unmapped canonical ID has visible name/rank fallback and full tooltip, no portrait substitution")
	_check_geometry(ribbon, 1, stage)
	_check_disclosure(ribbon, 0, "Lost Button Doll of the Unravelled Archive", "Statuses: bleed 3")
	ribbon.show_order(nine, repeated_id, true)
	var any_now := false
	for i in range(9):
		any_now = any_now or ribbon.marker_at(i).text == "NOW"
	_check(not any_now and ribbon.displayed_entries.size() == 9,
		"completed projection keeps valid history but clears every active-turn marker")

	_check(battle.state_snapshot() == snapshot and battle.rng_state() == rng and
		stage.receipts.size() == receipts,
		"synthetic nine, double boss, dead, lost, unknown and complete views never touch combat authority")
	stage._refresh()
	_verify_order(stage)

	# Real committed action makes the screen refresh from the new public order.
	var previous := battle.state_snapshot()
	var previous_actor := battle.current_actor_id()
	var accepted := stage.submit_pass()
	_check(bool(accepted.get("ok", false)) and stage.receipts.size() > receipts and
		battle.state_snapshot() != previous,
		"real public Pass spends one live hero action and advances seeded combat")
	_verify_order(stage)
	_check_geometry(ribbon, ribbon.displayed_entries.size(), stage)
	_check(battle.current_actor_id() != previous_actor,
		"precondition: committed Pass reaches a different real actor")
	var former_now := 0
	for i in range(ribbon.displayed_entries.size()):
		if ribbon.displayed_entries[i].id == previous_actor:
			former_now += 1
			_check(ribbon.marker_at(i).text == StitchedTurnStatusCues.cue(battle.get_unit(previous_actor)),
				"former real actor loses NOW and restores its authoritative status cue")
	_check(former_now == 1, "changed-turn check exercises the former acting tag")
	# Real public fray transitions change a nonacting hero's cue, then remove LOST.
	var frayed_id := ""
	for unit in ribbon.displayed_entries:
		if unit.side == "hero" and unit.id != battle.current_actor_id():
			frayed_id = str(unit.id)
			break
	_check(not frayed_id.is_empty(), "precondition: a living nonacting hero can receive a real fray event")
	var hanging := battle.apply_fray_event(frayed_id, 200)
	_check(hanging.get("ok", false) and hanging.get("transition") == "hanging" and
		battle.get_unit(frayed_id).hanging, "real fray event reaches Hanging before testing SEAM")
	stage._refresh()
	var seams := 0
	for i in range(ribbon.displayed_entries.size()):
		if ribbon.displayed_entries[i].id == frayed_id:
			seams += 1
			_check(ribbon.marker_at(i).text == "SEAM" and
				ribbon.tag_at(i).tooltip_text == StitchedTurnStatusCues.tooltip(battle.get_unit(frayed_id)),
				"real changed status projects SEAM with the complete unchanged public tooltip")
	_check(seams == 1, "real Hanging witness remains in the order exactly once")
	var last_slot := ribbon.displayed_entries.size() - 1
	ribbon.tag_at(last_slot).grab_focus()
	ribbon.tag_at(last_slot).mouse_entered.emit()
	_check(ribbon.tag_at(last_slot).get_node("FocusTooltip").visible,
		"precondition: last occupied slot has an open disclosure before LOST compacts the queue")
	var lost_result := battle.apply_fray_event(frayed_id, 200)
	_check(lost_result.get("ok", false) and lost_result.get("transition") == "lost" and
		battle.get_unit(frayed_id).lost, "second real fray event loses the Hanging hero")
	stage._refresh()
	_verify_order(stage)
	_check_geometry(ribbon, 6, stage)
	_check(not ribbon.tag_at(last_slot).visible and ribbon.tag_at(last_slot).tooltip_text.is_empty() and
		ribbon.marker_at(last_slot).text.is_empty() and ribbon.portrait_at(last_slot).texture == null and
		not ribbon.tag_at(last_slot).get_node("FocusTooltip").visible and
		ribbon.tag_at(last_slot).get_node("FocusTooltip/TooltipText").text.is_empty(),
		"real LOST refresh clears the vacated actor, portrait, marker and open mouse/keyboard disclosure")
	for unit in ribbon.displayed_entries:
		_check(unit.id != frayed_id, "real LOST actor never remains among projected survivors")

	# A new valid session must reconstruct tags from its own public round.
	host.free()
	var again := _mount()
	var fresh_host: Control = again["host"]
	var fresh_stage: StitchedBattleScreen = again["stage"]
	await process_frame
	_check(fresh_stage.battle != battle and fresh_stage._turn_ribbon != ribbon and
		fresh_stage._turn_ribbon.displayed_entries.size() == 7,
		"remount creates a fresh authoritative queue with no stale fourth or duplicate slot")
	_verify_order(fresh_stage)
	_check_geometry(fresh_stage._turn_ribbon, 7, fresh_stage)
	fresh_host.free()
	await _check_live_arrivals()
	await _check_live_death()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_turn_order_ribbon_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
