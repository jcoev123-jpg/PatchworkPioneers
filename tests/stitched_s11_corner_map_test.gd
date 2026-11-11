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
	var map := StitchedCornerMap.new(Rect2(972, 400, 304, 180))
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
	map.show_foe("Moth Scribe", PackedStringArray(["Foe · rank 2", "Health 9 / 12"]))
	_check(map.foe_body.visible and not map.map_holder.visible, "a hovered foe takes the corner")
	_check(map.title_label.text == "Moth Scribe", "the foe's own name heads the card")
	_check(map.foe_body.text.contains("Health 9 / 12"), "the foe card carries its lines")
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
