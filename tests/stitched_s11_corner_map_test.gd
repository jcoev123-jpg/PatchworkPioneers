extends SceneTree
## Owner combat job 5 (docs/COMBAT_JOBS.md): the corner route map, its room states,
## and the hovered foe taking the same corner in a mounted corridor fight.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _run() -> void:
	await _component_checks()
	await _mounted_checks()
	for line in failures:
		printerr("FAIL " + line)
	print("%d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _component_checks() -> void:
	var map := StitchedCornerMap.new(Rect2(968, 542, 306, 170))
	root.add_child(map)
	await process_frame
	var records := [
		{"id": "f02_n0", "type": "Fight", "position": 0, "floor": 2},
		{"id": "f02_n1", "type": "Campfire", "position": 1, "floor": 2},
		{"id": "f02_n2", "type": "Peddler", "position": 2, "floor": 2},
	]
	map.present_floor(2, records, ["f02_n0"], "f02_n0")
	_check(map.map_holder.get_child_count() == 3, "one column per room of the floor")
	_check(map.title_label.text.contains("FLOOR 02 OF 12"), "the title names the floor")
	var here: Control = map.map_holder.get_node("Room_f02_n0")
	_check(here.get_node("Icon").modulate == StitchedCornerMap.HERE, "the current room carries the here tint")
	_check(here.has_node("HereMark"), "the candle marks the room the party stands in")
	var ahead: Control = map.map_holder.get_node("Room_f02_n1")
	_check(not ahead.has_node("HereMark"), "an ahead room carries no candle")
	_check(ahead.get_node("Icon").modulate == StitchedCornerMap.FUTURE, "an alternate room has the unchosen tint")
	_check(ahead.get_node("Icon").tooltip_text.contains("alternate route")
		and not ahead.has_node("Seam_f02_n1") and not map.map_holder.get_node("Room_f02_n2").has_node("Seam_f02_n2"),
		"same-floor alternatives never imply a real onward corridor")
	map.present_floor(2, records, ["f02_n0"], "f02_n0")
	_check(map.map_holder.get_child_count() == 3, "an unchanged route does not rebuild the row")
	var next_floor := [
		{"id": "f03_n0", "type": "Event", "position": 0, "floor": 3},
		{"id": "f03_n1", "type": "Elite", "position": 1, "floor": 3},
	]
	var linked := records.duplicate(true)
	linked[0]["outgoing"] = ["f03_n1"]
	linked[1]["outgoing"] = ["f03_n0"]
	# Real crossed edges, not guessed lines between parallel rooms.
	map.present_floor(2, linked, ["f02_n0"], "f02_n0", next_floor)
	await process_frame
	_check(map.map_holder.has_node("Next_f03_n0") and map.map_holder.has_node("Next_f03_n1"),
		"the following floor is visible below the current rooms")
	var next_icon: Sprite2D = map.map_holder.get_node("Next_f03_n1")
	_check(next_icon.texture != null and next_icon.texture.get_width() * next_icon.scale.x <= 30.1
		and next_icon.texture.get_height() * next_icon.scale.y <= 30.1,
		"next-floor art must fit within 30 pixels (texture %s, scale %s)" % [
			str(next_icon.texture), str(next_icon.scale)])
	_check(map.map_holder.has_node("Seam_f02_n0_f03_n1")
		and map.map_holder.has_node("Seam_f02_n1_f03_n0"),
		"only actual outgoing edges join the two floors, including crossings")
	_check(not map.map_holder.has_node("Seam_f02_n2_f03_n0")
		and not map.map_holder.has_node("Seam_f02_n0_f02_n1"),
		"no imagined cross-floor or same-floor link is shown")
	var seam: Sprite2D = map.map_holder.get_node("Seam_f02_n0_f03_n1")
	_check(seam.texture != null and seam.scale.x > 0.0 and seam.scale.y > 0.0,
		"links are rendered with bounded image-backed thread art or the felt fallback")
	# Rebuild when the same node IDs carry a different real connection graph.
	linked[0]["outgoing"] = ["f03_n0"]
	map.present_floor(2, linked, ["f02_n0"], "f02_n0", next_floor)
	await process_frame
	_check(map.map_holder.has_node("Seam_f02_n0_f03_n0")
		and not map.map_holder.has_node("Seam_f02_n0_f03_n1"),
		"the route stamp responds to changed outgoing connections")
	map.present_floor(2, records, ["f02_n0"], "f02_n0")
	await process_frame
	_check(not map.map_holder.has_node("Next_f03_n0"),
		"the final floor or a missing next-floor record leaves no fictitious exits")
	map.show_foe("Moth Scribe", PackedStringArray(["Foe · rank 2", "Health 9 / 12"]))
	_check(map.foe_body.visible and not map.map_holder.visible, "a hovered foe takes the corner")
	_check(map.title_label.text == "Moth Scribe", "the foe's own name heads the card")
	_check(map.foe_body.text.contains("Health 9 / 12"), "the foe card carries its lines")
	# A four-line foe summary becomes seven or more rendered lines once long
	# move and resistance names wrap. The active-status line must still fit.
	map.show_foe("Felt Bulwark", PackedStringArray([
		"Foe · rank 1", "Health 15 / 18",
		"Moves: Felt Slam, Bulwark Pad, Button Shelter",
		"Resists stun 50%, bleed 20%, rot 10%, move 60%, debuff 20%",
		"Now: BLEED 2", ]))
	await process_frame
	_check(map.foe_body.get_visible_line_count() == map.foe_body.get_line_count()
		and map.foe_body.size.y <= map.size.y - 34.0,
		"wrapped foe moves and resistances display the final status line inside the fixed corner")
	_check(map.foe_body.text.ends_with("Now: BLEED 2"),
		"dense foe details preserve their live status rather than discarding it")
	map.show_foe("Patchwork Behemoth", PackedStringArray([
		"Boss · rank 1", "Health 45 / 50",
		"Moves: Behemoth Maul, Stuffing Hurl, Rope Lash, Stitch Ward",
		"Resists stun 45%, bleed 40%, rot 40%, move 70%, debuff 45%",
		"Now: BLEED 1", ]))
	await process_frame
	_check(map.foe_body.get_visible_line_count() == map.foe_body.get_line_count(),
		"boss move and resistance rows fit without hiding current Bleed")
	_check(map.foe_body.get_theme_font_size("font_size") >= 13,
		"the expanded corner keeps standard boss details readable")
	# A genuinely crowded boss must still scale down rather than cut off statuses.
	map.show_foe("Patchwork Behemoth", PackedStringArray([
		"Boss · rank 1", "Health 45 / 50",
		"Moves: Behemoth Maul, Stuffing Hurl, Rope Lash, Stitch Ward, Hemquake, Needlestorm, Thread Snare",
		"Resists stun 45%, bleed 40%, rot 40%, move 70%, debuff 45%, blind 30%, mark 40%",
		"Now: BLEED 1, GUARD 2, MARK 1", ]))
	await process_frame
	_check(map.foe_body.get_theme_font_size("font_size") < 15
		and map.foe_body.get_line_count() * map.foe_body.get_line_height() <= map.foe_body.size.y,
		"very long boss details adapt without clipping the status line (font %d, lines %d, height %d, room %.0f)" % [
			map.foe_body.get_theme_font_size("font_size"), map.foe_body.get_line_count(),
			map.foe_body.get_line_height(), map.foe_body.size.y])
	# An ordinary three-foe encounter still needs its full resistance readout,
	# without shrinking the existing fixed corner to the boss-only tiny size.
	map.show_foe("Crochet Hook Harrier", PackedStringArray([
		"Foe · rank 1", "Health 22 / 26", "Moves: Hook Drag, Harry",
		"Resists stun 25%, bleed 35%, rot 20%, move 20%, debuff 25%",
		"Now: BLEED 1", ]))
	await process_frame
	_check(map.foe_body.get_theme_font_size("font_size") >= 13,
		"a regular foe's full details use a readable font")
	_check(map.foe_body.get_visible_line_count() == map.foe_body.get_line_count(),
		"the legible foe summary still fits above the map's lower edge")
	map.show_foe("Moth Scribe", PackedStringArray(["Foe · rank 2", "Health 9 / 12"]))
	_check(map.foe_body.get_theme_font_size("font_size") == 15,
		"a short foe card recovers the regular readable font size")
	map.show_map()
	_check(not map.foe_body.visible and map.map_holder.visible, "the road map returns with the pointer")
	_check(map.title_label.text.contains("FLOOR 02 OF 12"), "the map title returns with the map")
	map.queue_free()
	await process_frame


func _mounted_checks() -> void:
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "authentic seeded preview begins")
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	_check(fight != null and fight.corner_map != null, "the corridor fight carries a corner map")
	await process_frame
	# Job 5: the information corner must sit BELOW the foe HP plates and BESIDE
	# the shortened ability bar, never across an actionable button or fight text.
	var corner := fight.corner_map.get_rect()
	var bottom: Control = fight.get_node("BottomBar")
	var rail := bottom.get_rect()
	var rail_clears_health := true
	for plate in fight.plates.values():
		if plate.visible and rail.intersects(plate.get_rect()):
			rail_clears_health = false
	_check(rail.position.y <= StitchedCorridorFight.BAR_TOP - 40.0
		and rail.end.y <= 720.0 and rail_clears_health,
		"deeper felt command rail fits below every HP plate without clipping the screen")
	_check(corner.position.x >= bottom.get_rect().end.x and corner.position.y >= 540.0
		and corner.end.x <= 1280.0 and corner.end.y <= 720.0,
		"the fight map occupies the lower-right free corner inside the screen")
	var free_of_plates := true
	for plate in fight.plates.values():
		if plate.visible and corner.intersects(plate.get_rect()):
			free_of_plates = false
	_check(free_of_plates, "the information corner does not cover any living HP plate")
	var free_of_actions := true
	for button in fight.part_buttons.values():
		if corner.intersects(button.get_rect()):
			free_of_actions = false
	_check(free_of_actions and not corner.intersects(fight.more_button.get_rect())
		and not corner.intersects(fight.continue_button.get_rect())
		and not corner.intersects(fight.log_label.get_rect()),
		"the map leaves abilities, More, Continue and the fight log unobscured")
	_check(bottom.get_rect().encloses(fight.more_button.get_rect()),
		"More stays inside the shortened bottom bar")
	fight.set_more_open(true)
	_check(fight.more_panel.visible and not fight.corner_map.visible,
		"the More tray hides the lower-right information corner")
	fight.set_more_open(false)
	_check(fight.corner_map.visible, "closing More restores the lower-right corner")
	fight.present_corner_map(null)
	_check(fight.fight_kind.is_empty(), "a fight without a run keeps its kind word empty")
	var foe_rank := -1
	for rank in range(1, 5):
		var unit: Dictionary = screen._unit_at("foe", rank)
		if not unit.is_empty() and not bool(unit.get("dead", false)):
			foe_rank = rank
			break
	_check(foe_rank > 0, "a living foe stands in the preview")
	var foe: Dictionary = screen._unit_at("foe", foe_rank)
	fight.hovered = "foe_" + str(foe_rank)
	fight._update_corner_foe()
	var text := fight.corner_map.foe_body.text
	_check(fight.corner_map.foe_body.visible, "hovering a foe swaps the corner card in")
	_check(text.contains("Health %d / %d" % [int(foe.get("hp", 0)), int(foe.get("max_hp", 0))]),
		"the foe card shows its live health")
	var names_move := false
	for ability in foe.get("abilities", []):
		if text.contains(str(ability.get("name", ""))):
			names_move = true
			break
	_check(names_move, "the foe card names the foe's moves")
	_check(text.contains("rank %d" % foe_rank), "the foe card names the foe's rank")
	_check(fight._foe_hover_lit == "foe_" + str(foe_rank), "the hovered foe holds the spotlight")
	fight.hovered = ""
	fight._update_corner_foe()
	_check(not fight.corner_map.foe_body.visible, "leaving the foe brings the map back")
	_check(fight._foe_hover_lit.is_empty(), "the hover spotlight eases back")
	_check(fight._foe_hover_return != null, "a departing hovered foe has a return tween")
	fight.hovered = "foe_" + str(foe_rank)
	fight._update_corner_foe()
	_check(fight._foe_hover_return == null and fight._foe_hover_return_key.is_empty(),
		"re-hovering a returning foe cancels its stale zoom tween")
	fight._clear_foe_spotlight()
	_check(fight.stage.figure_nodes["foe_" + str(foe_rank)].scale == Vector3.ONE
		and fight._foe_hover_return == null and fight._foe_hover_lit.is_empty(),
		"starting a held beat restores the foe scale and clears hover tweens")
	fight.hovered = "hero_1"
	fight._update_corner_foe()
	_check(not fight.corner_map.foe_body.visible, "a hovered doll keeps the road map in the corner")
	_check(fight._foe_hover_lit.is_empty(), "a doll never takes the foe spotlight")
	root.remove_child(screen)
	screen.queue_free()
	await process_frame
