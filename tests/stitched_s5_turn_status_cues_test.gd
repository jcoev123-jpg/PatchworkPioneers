extends SceneTree
## Pure S5 cues mounted under the Gothic theme, projected from real public rules units.
## No StitchedBattleScreen or app dependency.

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_turn_status_cues_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _preview() -> Dictionary:
	var file := FileAccess.open("res://data/stitched/s2_preview.json", FileAccess.READ)
	if file == null:
		return {}
	var json: Variant = JSON.parse_string(file.get_as_text())
	if json is Dictionary:
		return json
	return {}


func _from_order(battle: StitchedRules) -> Array:
	var entries: Array = []
	for id in battle.turn_order():
		entries.append(battle.get_unit(str(id)))
	return entries


func _mount() -> Dictionary:
	var host := Control.new()
	host.name = "GothicRibbonHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var ribbon := StitchedTurnOrderRibbon.new()
	ribbon.position = Vector2(120, 22)
	host.add_child(ribbon)
	return {"host": host, "ribbon": ribbon}


func _expect_slot(ribbon: StitchedTurnOrderRibbon, i: int, unit: Dictionary) -> void:
	var tag := ribbon.tag_at(i)
	var id := str(unit["id"])
	var side := str(unit["side"])
	var rank := int(unit["rank"])
	var art := str(ROSTER.art_paths(id).get("idle", ""))
	var has_art := not art.is_empty() and ResourceLoader.exists(art, "Texture2D")
	_check(tag.visible and str(ribbon.displayed_entries[i]["id"]) == id and
		tag.get_node("SideRank").text == (("H" if side == "hero" else "F") + str(rank)) and
		tag.tooltip_text.contains(str(unit["name"])) and
		tag.tooltip_text.contains(("%s rank %d" % [side.capitalize(), rank])) and
		tag.tooltip_text.contains("HP: %s / %s" % [str(unit["hp"]), str(unit["max_hp"])]) and
		tag.tooltip_text.contains("SPEED:") and tag.tooltip_text.contains("DODGE:") and
		tag.tooltip_text.contains("PROT:"),
		"public queue slot %d preserves ID, side/rank, full name and complete real stats" % i)
	_check(ribbon.portrait_at(i).visible == has_art and
		(ribbon.portrait_at(i).texture == load(art) if has_art else ribbon.portrait_at(i).texture == null) and
		tag.get_node("NameFallback").visible == not has_art,
		"slot %d owns its exact portrait or own name fallback" % i)


func _check_fit(ribbon: StitchedTurnOrderRibbon, count: int) -> void:
	var prior_right := -1.0
	for i in range(count):
		var tag := ribbon.tag_at(i)
		var bounds := tag.get_global_rect()
		_check(tag.visible and bounds.size == Vector2(73, 42) and bounds.position.x >= prior_right and
			bounds.position.x >= 0 and bounds.end.x <= 1280 and bounds.position.y >= 0 and bounds.end.y <= 720,
			"%d-slot turn tag %d is 73x42, ordered and fits 1280x720" % [count, i])
		prior_right = bounds.end.x


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var config := _preview()
	_check(not config.is_empty() and config.get("mode") == "stitched" and
		config.get("heroes") is Array and config["heroes"].size() == 4 and
		config.get("foes") is Array and config["foes"].size() == 3,
		"precondition: unmodified real S2 preview defines four heroes and three foes")
	if config.is_empty():
		_finish()
		return
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)) and created.get("battle") is StitchedRules,
		"precondition: StitchedRules.create accepts real S2 JSON")
	if not created.get("ok", false):
		_finish()
		return
	var battle: StitchedRules = created["battle"]
	var entries := _from_order(battle)
	_check(entries.size() == 7 and battle.get_heroes().size() == 4 and
		battle.get_foes().size() == 3 and battle.turn_order().size() == 7,
		"precondition: genuine seeded 4v3 turn order has seven units")
	var mounted := _mount()
	var host: Control = mounted["host"]
	var ribbon: StitchedTurnOrderRibbon = mounted["ribbon"]
	await process_frame
	_check(host.theme != null and ribbon.get_child_count() == 9 and
		ribbon.tag_at(0) != null and ribbon.tag_at(8) != null,
		"Gothic mounted ribbon has exactly nine reusable tag roots")

	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	seed(872345)
	var expected_global := randi()
	seed(872345)
	ribbon.show_order(entries, battle.current_actor_id(), battle.is_over())
	_check(ribbon.displayed_entries.size() == battle.turn_order().size(),
		"all real public IDs are projected in rolled order without a fake actor")
	for i in range(entries.size()):
		_expect_slot(ribbon, i, entries[i])
		_check(ribbon.marker_at(i).text ==
			("NOW" if str(entries[i]["id"]) == battle.current_actor_id()
			else ("HERO" if entries[i]["side"] == "hero" else "FOE")),
			"slot %d NOW or base marker follows public acting ID" % i)
	_check_fit(ribbon, 7)
	for i in range(7, 9):
		_check(not ribbon.tag_at(i).visible and ribbon.tag_at(i).tooltip_text.is_empty(),
			"unused tag %d is hidden and tooltip-free" % i)

	# Exercise keyboard and hover on exactly the same public tooltip; no battle-screen mount.
	var first := ribbon.tag_at(0)
	_check(first.focus_mode == Control.FOCUS_ALL, "each tag accepts keyboard focus")
	first.grab_focus()
	await process_frame
	_check(first.has_focus() and first.get_node("FocusTooltip").visible and
		first.get_node("FocusTooltip/TooltipText").text == first.tooltip_text and
		first.tooltip_text.contains(str(entries[0]["name"])),
		"keyboard focus opens sewn-art readable tooltip with the same complete text")
	first.release_focus()
	first.mouse_entered.emit()
	_check(first.get_node("FocusTooltip").visible and
		first.get_node("FocusTooltip/TooltipText").text == first.tooltip_text,
		"mouse hover exposes exactly the same tooltip as keyboard")
	first.mouse_exited.emit()
	_check(not first.get_node("FocusTooltip").visible, "hover exit clears expanded information")

	# Projection units are deep copies: seams, states, parts and overlap cannot affect authority.
	var hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	var foe: Dictionary = battle.get_foes()[0].duplicate(true)
	hero["hp"] = 0
	hero["hanging"] = true
	hero["fray"] = 145
	hero["resolve"] = "bitter"
	hero["statuses"] = {"weak": 0, "mark": 2, "stun": 1, "guard": 3, "bleed": -1}
	hero["parts"]["head"]["torn"] = true
	hero["parts"]["arms"]["torn"] = true
	_check(StitchedTurnStatusCues.cue(hero) == "SEAM", "SEAM wins overlapping stun, torn and high fray")
	var info := StitchedTurnStatusCues.tooltip(hero)
	_check(info.contains("HP: 0 / ") and info.contains("FRAY: 145 / 200") and
		info.contains("Resolve: bitter") and info.contains("Torn parts: Head, Arms") and
		info.contains("67% seam hold / 33% hero lost") and
		info.contains("Statuses: guard 3, mark 2, stun 1") and
		not info.contains("weak 0") and not info.contains("bleed -1"),
		"complete seam warning, genuine resolve, ordered torn slots and sorted positive counters")
	ribbon.show_order([hero, foe], str(foe["id"]), false)
	_check(ribbon.displayed_entries.size() == 2 and
		ribbon.marker_at(0).text == "SEAM" and ribbon.marker_at(1).text == "NOW" and
		ribbon.tag_at(0).tooltip_text == info and ribbon.tag_at(0).visible,
		"0-HP hanging hero remains and NOW overrides another actor's normal state")
	ribbon.show_order([hero], str(hero["id"]), false)
	_check(ribbon.marker_at(0).text == "NOW" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"acting hanging hero shows amber NOW over SEAM")
	ribbon.show_order([hero], str(hero["id"]), true)
	_check(ribbon.marker_at(0).text == "SEAM", "finished view clears NOW without losing truthful SEAM")

	hero["hanging"] = false
	_check(StitchedTurnStatusCues.cue(hero) == "STUN", "positive stun overrides torn and fray")
	hero["statuses"]["stun"] = 0
	_check(StitchedTurnStatusCues.cue(hero) == "TORN", "multiple torn equipped parts beat high fray")
	hero["parts"]["head"]["torn"] = false
	hero["parts"]["arms"]["torn"] = false
	_check(StitchedTurnStatusCues.cue(hero) == "FRAY", "fray exactly above 100 is warned")
	hero["fray"] = 100
	_check(StitchedTurnStatusCues.cue(hero) == "FRAY", "threshold 100 is inclusive")
	hero["fray"] = 99
	_check(StitchedTurnStatusCues.cue(hero) == "HERO", "fray 99 gets no premature warning")
	foe["statuses"] = {"stun": 2}
	foe["fray"] = 150
	_check(StitchedTurnStatusCues.cue(foe) == "STUN", "foe stun is real, foe fray is never a hero warning")
	foe["statuses"] = {"stun": 0}
	_check(StitchedTurnStatusCues.cue(foe) == "FOE", "zero stun and foe fray yield FOE")

	# Malformed optional fields may not masquerade as 0, a stun or torn equipment.
	var sparse := {"id":"never_mapped_art","name":"Unknown Stitch","side":"hero","rank":4,
		"hp":9,"max_hp":19,"speed":"bad","fray":"100","resolve":0,
		"statuses":{"stun":"2","bleed":0,"mark":-1},"parts":{"head":{"torn":"true"}}}
	_check(StitchedTurnStatusCues.cue(sparse) == "HERO" and
		StitchedTurnStatusCues.torn_slots(sparse).is_empty() and
		StitchedTurnStatusCues.tooltip(sparse).contains("HP: 9 / 19") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("SPEED") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("DODGE") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("FRAY") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Statuses:") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Resolve:"),
		"malformed/missing fields fail closed, without fabricated numeric stats or conditions")
	_check(StitchedTurnStatusCues.cue({"id":"empty"}) == "" and
		StitchedTurnStatusCues.tooltip({"id":"empty"}) == "empty",
		"unknown empty unit does not fabricate a side, rank or numeric state")
	ribbon.show_order([sparse, {"id":"nameless", "side":"foe", "rank":2}], "", false)
	_check(ribbon.portrait_at(0).texture == null and
		ribbon.tag_at(0).get_node("NameFallback").visible and
		ribbon.tag_at(0).tooltip_text.contains("Unknown Stitch") and
		ribbon.displayed_entries.size() == 2 and
		ribbon.tag_at(1).visible and not ribbon.tag_at(1).tooltip_text.contains("HP:"),
		"unknown ID never borrows art and missing foe HP is not invented as zero/dead")

	# Derive the duplicate boss queue from a second genuine StitchedRules.create session.
	var boss_config := config.duplicate(true)
	boss_config["foes"][0]["is_boss"] = true
	boss_config["foes"][0]["turns_per_round"] = 2
	var boss_result := StitchedRules.create(boss_config)
	_check(bool(boss_result.get("ok", false)), "precondition: legal two-turn boss in copied S2 preview")
	if boss_result.get("ok", false):
		var boss: StitchedRules = boss_result["battle"]
		var boss_entries := _from_order(boss)
		var boss_id := str(boss.get_foes()[0]["id"])
		var boss_occurrences := 0
		for member in boss_entries:
			if member.get("id") == boss_id:
				boss_occurrences += 1
		_check(boss.turn_order().size() == 8 and boss_occurrences == 2,
			"real seeded boss turn_order returns distinct duplicate ID slots")
		var fourth: Dictionary = boss.get_foes()[2].duplicate(true)
		fourth["id"] = "new_fourth_no_art"
		fourth["name"] = "Fourth Foe"
		fourth["rank"] = 4
		boss_entries.append(fourth)
		ribbon.show_order(boss_entries, boss_id, false)
		_check(ribbon.displayed_entries.size() == 9 and
			ribbon.tag_at(8).visible and ribbon.get_child_count() == 9 and
			ribbon.portrait_at(8).texture == null,
			"legal public boss order plus unknown fourth foe occupies all nine reusable tags")
		var highlighted := 0
		for i in range(9):
			if str(ribbon.displayed_entries[i]["id"]) == boss_id:
				highlighted += int(ribbon.marker_at(i).text == "NOW")
				_check(ribbon.marker_at(i).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
					"each repeated boss NOW cue has the original amber highlight")
		_check(highlighted == 2, "both occurrences of boss ID are NOW, no deduplication")
		_check_fit(ribbon, 9)
		_check(boss.turn_order().size() == 8 and boss.rng_state() == boss.rng_state(),
			"boss public order remains present after view projection")

	# Negative filters and refresh: hiding never leaves stale tooltips or condition labels.
	var dead := hero.duplicate(true)
	dead["dead"] = true
	var lost := hero.duplicate(true)
	lost["lost"] = true
	var zero_foe := foe.duplicate(true)
	zero_foe["hp"] = 0
	var remaining := hero.duplicate(true)
	remaining["hanging"] = true
	remaining["hp"] = 0
	ribbon.show_order([dead, zero_foe, remaining, lost], "", false)
	_check(ribbon.displayed_entries.size() == 1 and ribbon.tag_at(0).visible and
		ribbon.marker_at(0).text == "SEAM" and not ribbon.tag_at(1).visible and
		ribbon.tag_at(1).tooltip_text.is_empty() and
		ribbon.tag_at(1).get_node("FocusTooltip/TooltipText").text.is_empty(),
		"dead/lost and 0-HP foe vanish, hanging 0-HP hero stays and stale text clears")
	ribbon.show_order([], "", true)
	_check(ribbon.displayed_entries.is_empty() and ribbon.get_child_count() == 9 and
		not ribbon.tag_at(0).visible and ribbon.tag_at(0).tooltip_text.is_empty() and
		not ribbon.tag_at(0).get_node("FocusTooltip").visible and
		ribbon.marker_at(0).text.is_empty(),
		"reset hides stale cues, portrait, focus overlay and tooltips without new tag nodes")

	for repetition in range(4):
		ribbon.show_order(entries, battle.current_actor_id(), battle.is_over())
		ribbon.tag_at(0).mouse_entered.emit()
		ribbon.tag_at(0).mouse_exited.emit()
		ribbon.tag_at(0).grab_focus()
		ribbon.tag_at(0).release_focus()
	_check(battle.state_snapshot() == snapshot and battle.rng_state() == rng and
		randi() == expected_global and ribbon.get_child_count() == 9 and
		ribbon.displayed_entries.size() == 7,
		"repeated projection, focus and hover mutate no battle snapshot, parts, receipts, or RNG")
	host.free()
	_finish()
