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
	_check(count > 0 and ribbon.displayed_entries.size() == count,
		"precondition: measured cue layout contains every expected entry")
	for i in range(count):
		var tag := ribbon.tag_at(i)
		var bounds := tag.get_global_rect()
		_check(tag.visible and bounds.size.x >= 69 and bounds.size.y == 42 and
			(i == 0 or bounds.position.x - prior_right >= 8.0) and
			bounds.end.x <= ribbon.global_position.x + 690 and
			bounds.position.x >= 0 and bounds.end.x <= 1280 and bounds.position.y >= 0 and bounds.end.y <= 720,
			"%d-slot turn tag %d has adaptive width, height 42, is ordered and fits 1280x720" % [count, i])
		var rank: Label = tag.get_node("SideRank")
		var cue := ribbon.marker_at(i)
		var frame: NinePatchRect = tag.get_node("SewnPlate")
		_check(frame.get_global_rect() == bounds and frame.texture == load("res://assets/paper/ui/panel_felt.png") and
			frame.self_modulate.a == 1.0 and frame.modulate == Color.WHITE and
			bounds.encloses(rank.get_global_rect()) and bounds.encloses(cue.get_global_rect()) and
			not rank.get_global_rect().intersects(cue.get_global_rect()),
			"slot %d rank and cue sit in separate cells on opaque dark fabric" % i)
		for label: Label in [rank, cue]:
			var size := label.get_theme_font_size("font_size")
			var font := label.get_theme_font("font")
			var ink := label.get_theme_color("font_color")
			_check(not label.text.is_empty() and size >= 10 and
				font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= label.size.x - 2.0 and
				font.get_height(size) <= label.size.y and
				(ink.srgb_to_linear().get_luminance() + 0.05) / (frame.self_modulate.srgb_to_linear().get_luminance() + 0.05) >= 4.5,
				"slot %d full %s text fits and contrasts against even the brightest tinted fabric texel" % [i, label.name])
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

	# Six real public-unit-shaped snapshots copied from StitchedRules.get_heroes() with documented resolves.
	var base_heroes: Array = battle.get_heroes()
	var resolve_specs := [
		{"trait": "steadfast", "cue": "STFD", "fray": 45, "terms": ["+10%", "party -2 fray/turn", "floor end", "45"]},
		{"trait": "frantic", "cue": "FRNT", "fray": 110, "terms": ["30%", "random legal ability", "random legal target", "clears under 50 fray"]},
		{"trait": "hollow", "cue": "HOLL", "fray": 115, "terms": ["30%", "forced pass", "clears under 50 fray"]},
		{"trait": "bitter", "cue": "BITR", "fray": 120, "terms": ["+4 fray/turn", "adjacent ally", "clears under 50 fray"]},
		{"trait": "reckless", "cue": "RECK", "fray": 125, "terms": ["ignore Guard", "step forward", "clears under 50 fray"]},
		{"trait": "cowering", "cue": "COWR", "fray": 130, "terms": ["step backward", "30%", "melee", "clears under 50 fray"]},
	]
	var resolve_snapshots: Array = []
	var seen_cues: Dictionary = {}
	for i in range(resolve_specs.size()):
		var spec: Dictionary = resolve_specs[i]
		var unit_copy: Dictionary = base_heroes[i % base_heroes.size()].duplicate(true)
		var trait_name := str(spec["trait"])
		var expected_cue := str(spec["cue"])
		unit_copy["fray"] = int(spec["fray"])
		unit_copy["resolve"] = trait_name
		resolve_snapshots.append(unit_copy)
		var actual_cue := StitchedTurnStatusCues.cue(unit_copy)
		seen_cues[actual_cue] = true
		_check(actual_cue == expected_cue and actual_cue.length() <= 4,
			"resolve %s yields distinct <=4-char cue %s (fray %d)" % [trait_name, expected_cue, int(spec["fray"])])
		var lines := StitchedTurnStatusCues.tooltip_lines(unit_copy)
		var resolve_line_idx := lines.find("Resolve: " + trait_name)
		_check(resolve_line_idx >= 0 and resolve_line_idx + 1 < lines.size(),
			"resolve %s retains Resolve: <trait> line followed by one concise effect line" % trait_name)
		var effect_line := lines[resolve_line_idx + 1] if (resolve_line_idx >= 0 and resolve_line_idx + 1 < lines.size()) else ""
		var tip := StitchedTurnStatusCues.tooltip(unit_copy)
		var all_terms := true
		for term in spec["terms"]:
			if not effect_line.contains(str(term)) or not tip.contains(str(term)):
				all_terms = false
		_check(all_terms, "resolve %s tooltip effect line accurately states documented numbers/rules" % trait_name)
	_check(seen_cues.size() == 6, "all six documented resolves have distinct short cues")

	ribbon.show_order(resolve_snapshots, "", false)
	_check(ribbon.displayed_entries.size() == 6 and ribbon.get_child_count() == 9,
		"mounted ribbon projects all six resolved hero snapshots without adding nodes")
	_check_fit(ribbon, 6)
	for i in range(resolve_snapshots.size()):
		var spec: Dictionary = resolve_specs[i]
		var expected_cue := str(spec["cue"])
		var expected_tip := StitchedTurnStatusCues.tooltip(resolve_snapshots[i])
		var tag := ribbon.tag_at(i)
		var marker := ribbon.marker_at(i)
		_check(marker.text == expected_cue and marker.text.length() <= 4 and
			marker.size.x == tag.get_node("SideRank").size.x and marker.size.x >= 34.0 and
			marker.get_theme_font("font").get_string_size(expected_cue, HORIZONTAL_ALIGNMENT_LEFT, -1,
				marker.get_theme_font_size("font_size")).x <= marker.size.x - 2.0 and
			marker.get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
			"mounted slot %d displays complete <=4-char resolve cue %s inside its measured marker" % [i, expected_cue])
		tag.grab_focus()
		await process_frame
		var focus_tip := str(tag.get_node("FocusTooltip/TooltipText").text)
		_check(tag.has_focus() and tag.get_node("FocusTooltip").visible and
			focus_tip == tag.tooltip_text and tag.tooltip_text == expected_tip,
			"mounted slot %d keyboard focus exposes exact resolve tooltip" % i)
		tag.release_focus()
		tag.mouse_entered.emit()
		var hover_tip := str(tag.get_node("FocusTooltip/TooltipText").text)
		_check(tag.get_node("FocusTooltip").visible and hover_tip == focus_tip and hover_tip == expected_tip,
			"mounted slot %d mouse hover exposes the exact same resolve tooltip as keyboard focus" % i)
		tag.mouse_exited.emit()
		_check(not tag.get_node("FocusTooltip").visible,
			"mounted slot %d hover exit hides resolve tooltip" % i)

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
		info.contains("Resolve: bitter") and info.contains("+4 fray/turn") and
		info.contains("Torn parts: Head, Arms") and
		info.contains("damaging zero-HP hit") and
		info.contains("tears a remaining arm, leg or head") and
		info.contains("losing the head means LOST") and
		info.contains("heal above zero ends Hanging") and
		info.contains("resets accumulated hits") and
		not info.contains("67%") and not info.contains("33%") and not info.contains("seam hold") and
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
	_check(StitchedTurnStatusCues.cue(hero) == "STUN", "positive stun overrides torn, resolve and fray")
	hero["statuses"]["stun"] = 0
	_check(StitchedTurnStatusCues.cue(hero) == "TORN", "multiple torn equipped parts beat resolve and high fray")
	hero["parts"]["head"]["torn"] = false
	hero["parts"]["arms"]["torn"] = false
	_check(StitchedTurnStatusCues.cue(hero) == "BITR", "known bitter resolve precedes numeric fray warning")
	hero["resolve"] = ""
	_check(StitchedTurnStatusCues.cue(hero) == "FRAY", "fray above 100 with blank resolve is warned")
	hero["fray"] = 100
	_check(StitchedTurnStatusCues.cue(hero) == "FRAY", "threshold 100 is inclusive")
	hero["fray"] = 99
	_check(StitchedTurnStatusCues.cue(hero) == "MARK", "positive mark follows fray in precedence before generic HERO")
	hero["statuses"]["mark"] = 0
	_check(StitchedTurnStatusCues.cue(hero) == "HERO" and
		not StitchedTurnStatusCues.tooltip(hero).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(hero).contains("Steadfast") and
		not StitchedTurnStatusCues.tooltip(hero).contains("Unravelled"),
		"blank-resolve hero at fray 99 gets HERO and no invented benefit")
	foe["resolve"] = "bitter"
	foe["statuses"] = {"stun": 2}
	foe["fray"] = 150
	_check(StitchedTurnStatusCues.cue(foe) == "STUN", "foe stun is real, foe fray is never a hero warning")
	foe["statuses"] = {"stun": 0}
	_check(StitchedTurnStatusCues.cue(foe) == "FOE" and
		not StitchedTurnStatusCues.tooltip(foe).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(foe).contains("Unravelled") and
		not StitchedTurnStatusCues.tooltip(foe).contains("+4 fray"),
		"zero stun and foe spoofing bitter yield FOE with no resolve trait or bonus")

	# Genuine public hero/foe Bleed cue, tooltip fidelity, and priority over side fallbacks.
	var bld_hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	var bld_foe: Dictionary = battle.get_foes()[0].duplicate(true)
	var unrelated: Dictionary = battle.get_heroes()[1].duplicate(true)

	bld_hero["statuses"] = {"bleed": 3}
	bld_foe["statuses"] = {"bleed": 3}

	var hero_tip := StitchedTurnStatusCues.tooltip(bld_hero)
	var foe_tip := StitchedTurnStatusCues.tooltip(bld_foe)
	_check(StitchedTurnStatusCues.cue(bld_hero) == "BLD", "bleeding hero returns BLD cue")
	_check(StitchedTurnStatusCues.cue(bld_foe) == "BLD", "bleeding foe returns BLD cue")
	_check(hero_tip.contains("Statuses: bleed 3") and
		hero_tip.contains(str(bld_hero["name"])) and hero_tip.contains("HP: %s / %s" % [str(bld_hero["hp"]), str(bld_hero["max_hp"])]) and
		hero_tip.contains("SPEED:") and hero_tip.contains("DODGE:") and hero_tip.contains("PROT:"),
		"bleeding hero tooltip contains bleed 3 and all normal metadata")
	_check(foe_tip.contains("Statuses: bleed 3") and
		foe_tip.contains(str(bld_foe["name"])) and foe_tip.contains("HP: %s / %s" % [str(bld_foe["hp"]), str(bld_foe["max_hp"])]) and
		foe_tip.contains("SPEED:") and foe_tip.contains("DODGE:") and foe_tip.contains("PROT:"),
		"bleeding foe tooltip contains bleed 3 and all normal metadata")

	# Check 1 and 3 as positive; 0, -1, "3", 1.5, missing and non-Dictionary statuses must not trigger BLD.
	for pos in [1, 3]:
		bld_hero["statuses"] = {"bleed": pos}
		bld_foe["statuses"] = {"bleed": pos}
		_check(StitchedTurnStatusCues.cue(bld_hero) == "BLD", "hero bleed %d triggers BLD" % pos)
		_check(StitchedTurnStatusCues.cue(bld_foe) == "BLD", "foe bleed %d triggers BLD" % pos)

	for non_pos in [0, -1, "3", 1.5]:
		var h_test: Dictionary = bld_hero.duplicate(true)
		var f_test: Dictionary = bld_foe.duplicate(true)
		h_test["statuses"] = {"bleed": non_pos}
		f_test["statuses"] = {"bleed": non_pos}
		_check(StitchedTurnStatusCues.cue(h_test) == "HERO", "hero non-positive bleed %s yields HERO" % str(non_pos))
		_check(StitchedTurnStatusCues.cue(f_test) == "FOE", "foe non-positive bleed %s yields FOE" % str(non_pos))

	var h_missing: Dictionary = bld_hero.duplicate(true)
	var f_missing: Dictionary = bld_foe.duplicate(true)
	h_missing["statuses"] = {}
	f_missing["statuses"] = {}
	_check(StitchedTurnStatusCues.cue(h_missing) == "HERO", "hero missing bleed yields HERO")
	_check(StitchedTurnStatusCues.cue(f_missing) == "FOE", "foe missing bleed yields FOE")

	for bad_statuses in [null, "bleed 3", 3, [3]]:
		var h_bad: Dictionary = bld_hero.duplicate(true)
		var f_bad: Dictionary = bld_foe.duplicate(true)
		h_bad["statuses"] = bad_statuses
		f_bad["statuses"] = bad_statuses
		_check(StitchedTurnStatusCues.cue(h_bad) == "HERO", "hero non-Dictionary statuses %s yields HERO" % str(bad_statuses))
		_check(StitchedTurnStatusCues.cue(f_bad) == "FOE", "foe non-Dictionary statuses %s yields FOE" % str(bad_statuses))

	# Hero and foe overlaps: hanging gives SEAM, stun gives STUN, torn gives TORN, resolved hero gives resolve cue, high-FRAY hero gives FRAY.
	var h_overlap: Dictionary = bld_hero.duplicate(true)
	h_overlap["statuses"] = {"bleed": 3}
	h_overlap["hanging"] = true
	_check(StitchedTurnStatusCues.cue(h_overlap) == "SEAM", "hanging hero with bleed yields SEAM")
	h_overlap["hanging"] = false
	h_overlap["statuses"] = {"bleed": 3, "stun": 1}
	_check(StitchedTurnStatusCues.cue(h_overlap) == "STUN", "stunned hero with bleed yields STUN")
	h_overlap["statuses"] = {"bleed": 3}
	h_overlap["parts"]["head"]["torn"] = true
	_check(StitchedTurnStatusCues.cue(h_overlap) == "TORN", "torn hero with bleed yields TORN")
	h_overlap["parts"]["head"]["torn"] = false
	h_overlap["resolve"] = "steadfast"
	_check(StitchedTurnStatusCues.cue(h_overlap) == "STFD", "resolved hero with bleed yields resolve cue")
	h_overlap["resolve"] = ""
	h_overlap["fray"] = 120
	_check(StitchedTurnStatusCues.cue(h_overlap) == "FRAY", "high-FRAY hero with bleed yields FRAY")

	var f_overlap: Dictionary = bld_foe.duplicate(true)
	f_overlap["statuses"] = {"bleed": 3}
	f_overlap["hanging"] = true
	_check(StitchedTurnStatusCues.cue(f_overlap) == "SEAM", "hanging foe with bleed yields SEAM")
	f_overlap["hanging"] = false
	f_overlap["statuses"] = {"bleed": 3, "stun": 2}
	_check(StitchedTurnStatusCues.cue(f_overlap) == "STUN", "stunned foe with bleed yields STUN")
	f_overlap["statuses"] = {"bleed": 3}
	f_overlap["parts"] = {"head": {"torn": true}}
	_check(StitchedTurnStatusCues.cue(f_overlap) == "TORN", "torn foe with bleed yields TORN")

	# A foe with spoofed hero resolve or fray still gets BLD if genuinely bleeding, never a hero-only marker.
	var f_spoofed: Dictionary = bld_foe.duplicate(true)
	f_spoofed["statuses"] = {"bleed": 3}
	f_spoofed["resolve"] = "bitter"
	f_spoofed["fray"] = 150
	_check(StitchedTurnStatusCues.cue(f_spoofed) == "BLD",
		"foe with spoofed hero resolve and fray gets BLD when genuinely bleeding")
	f_spoofed["statuses"] = {"bleed": 0}
	_check(StitchedTurnStatusCues.cue(f_spoofed) == "FOE" and
		StitchedTurnStatusCues.cue(f_spoofed) != "BITR" and
		StitchedTurnStatusCues.cue(f_spoofed) != "FRAY" and
		StitchedTurnStatusCues.cue(f_spoofed) != "HERO",
		"foe with spoofed hero resolve and fray gets FOE when not bleeding, never hero-only marker")

	# Mounted ribbon display with two bleeding public copies and an unrelated actor:
	bld_hero["statuses"] = {"bleed": 3}
	bld_foe["statuses"] = {"bleed": 3}
	unrelated["statuses"] = {}
	var hero_id := str(bld_hero["id"])
	var foe_id := str(bld_foe["id"])
	var unrel_id := str(unrelated["id"])
	var bld_entries := [bld_hero, bld_foe, unrelated]

	# Hero acting: hero NOW, foe BLD, unrelated HERO
	ribbon.show_order(bld_entries, hero_id, false)
	_check(ribbon.displayed_entries.size() == 3, "ribbon shows three units")
	_check(ribbon.marker_at(0).text == "NOW" and ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"acting bleeding hero shows amber NOW")
	_check(ribbon.marker_at(1).text == "BLD" and ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"nonacting bleeding foe shows muted BLD")
	_check(ribbon.marker_at(2).text == "HERO", "nonacting unrelated hero shows HERO")

	# Hover and keyboard focus must still show the exact same tooltip, including the Bleed counter.
	var tag_hero := ribbon.tag_at(0)
	var expected_hero_tip := StitchedTurnStatusCues.tooltip(bld_hero)
	_check(tag_hero.tooltip_text == expected_hero_tip and tag_hero.tooltip_text.contains("bleed 3"),
		"acting bleeding hero tag tooltip preserves bleed 3 and metadata")
	tag_hero.grab_focus()
	await process_frame
	_check(tag_hero.has_focus() and tag_hero.get_node("FocusTooltip").visible and
		tag_hero.get_node("FocusTooltip/TooltipText").text == expected_hero_tip,
		"acting bleeding hero keyboard focus exposes tooltip with bleed 3")
	tag_hero.release_focus()
	tag_hero.mouse_entered.emit()
	_check(tag_hero.get_node("FocusTooltip").visible and
		tag_hero.get_node("FocusTooltip/TooltipText").text == expected_hero_tip,
		"acting bleeding hero mouse hover exposes tooltip with bleed 3")
	tag_hero.mouse_exited.emit()
	_check(not tag_hero.get_node("FocusTooltip").visible, "hero hover exit hides tooltip")

	var tag_foe := ribbon.tag_at(1)
	var expected_foe_tip := StitchedTurnStatusCues.tooltip(bld_foe)
	_check(tag_foe.tooltip_text == expected_foe_tip and tag_foe.tooltip_text.contains("bleed 3"),
		"nonacting bleeding foe tag tooltip preserves bleed 3 and metadata")
	tag_foe.grab_focus()
	await process_frame
	_check(tag_foe.has_focus() and tag_foe.get_node("FocusTooltip").visible and
		tag_foe.get_node("FocusTooltip/TooltipText").text == expected_foe_tip,
		"nonacting bleeding foe keyboard focus exposes tooltip with bleed 3")
	tag_foe.release_focus()
	tag_foe.mouse_entered.emit()
	_check(tag_foe.get_node("FocusTooltip").visible and
		tag_foe.get_node("FocusTooltip/TooltipText").text == expected_foe_tip,
		"nonacting bleeding foe mouse hover exposes tooltip with bleed 3")
	tag_foe.mouse_exited.emit()
	_check(not tag_foe.get_node("FocusTooltip").visible, "foe hover exit hides tooltip")

	# Acting ID changes to foe: hero Bleed warning returns as BLD, foe shows NOW
	ribbon.show_order(bld_entries, foe_id, false)
	_check(ribbon.marker_at(0).text == "BLD" and ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"previously acting hero returns to BLD marker when turn passes")
	_check(ribbon.marker_at(1).text == "NOW" and ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"foe now acting shows NOW marker")
	_check(ribbon.marker_at(2).text == "HERO", "unrelated hero remains HERO")

	# Acting ID changes to unrelated actor: both bleeding actors show BLD
	ribbon.show_order(bld_entries, unrel_id, false)
	_check(ribbon.marker_at(0).text == "BLD", "bleeding hero shows BLD when third party acts")
	_check(ribbon.marker_at(1).text == "BLD", "bleeding foe shows BLD when third party acts")
	_check(ribbon.marker_at(2).text == "NOW", "acting third party shows NOW")

	# Remove Bleed and show_order again: generic HERO/FOE returns and no stale text remains.
	var clean_hero: Dictionary = bld_hero.duplicate(true)
	var clean_foe: Dictionary = bld_foe.duplicate(true)
	clean_hero["statuses"] = {}
	clean_foe["statuses"] = {}
	ribbon.show_order([clean_hero, clean_foe, unrelated], "", false)
	_check(ribbon.marker_at(0).text == "HERO", "cleared hero returns to generic HERO")
	_check(ribbon.marker_at(1).text == "FOE", "cleared foe returns to generic FOE")
	_check(ribbon.marker_at(2).text == "HERO", "unrelated hero returns to generic HERO")
	_check(not ribbon.tag_at(0).tooltip_text.contains("bleed"), "cleared hero tooltip has no stale bleed text")
	_check(not ribbon.tag_at(1).tooltip_text.contains("bleed"), "cleared foe tooltip has no stale bleed text")
	_check(not ribbon.tag_at(0).get_node("FocusTooltip/TooltipText").text.contains("bleed"),
		"cleared hero focus tooltip has no stale bleed text")
	_check(not ribbon.tag_at(1).get_node("FocusTooltip/TooltipText").text.contains("bleed"),
		"cleared foe focus tooltip has no stale bleed text")
	_check(ribbon.get_child_count() == 9, "retains exact nine reusable tags")

	# Genuine public hero/foe Blind and Tangled cues, tooltip fidelity, mounted layout and precedence.
	var blind_hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	var blind_foe: Dictionary = battle.get_foes()[0].duplicate(true)
	var tangled_hero: Dictionary = battle.get_heroes()[1].duplicate(true)
	var tangled_foe: Dictionary = battle.get_foes()[1].duplicate(true)
	var dual_hero: Dictionary = battle.get_heroes()[2].duplicate(true)
	var neutral_hero: Dictionary = battle.get_heroes()[3].duplicate(true)

	blind_hero["statuses"] = {"blind": 1}
	blind_foe["statuses"] = {"blind": 1}
	tangled_hero["statuses"] = {"tangled": 2}
	tangled_foe["statuses"] = {"tangled": 2}
	dual_hero["statuses"] = {"blind": 1, "tangled": 2}
	neutral_hero["statuses"] = {}

	# AC1: Pure cue assertions for blind and tangled on hero and foe
	_check(StitchedTurnStatusCues.cue(blind_hero) == "BLND", "AC1: hero with blind 1 yields BLND cue")
	_check(StitchedTurnStatusCues.cue(blind_foe) == "BLND", "AC1: foe with blind 1 yields BLND cue")
	_check(StitchedTurnStatusCues.cue(tangled_hero) == "TNGL", "AC1: hero with tangled 2 yields TNGL cue")
	_check(StitchedTurnStatusCues.cue(tangled_foe) == "TNGL", "AC1: foe with tangled 2 yields TNGL cue")
	_check(StitchedTurnStatusCues.cue(dual_hero) == "BLND", "AC1/AC2: coexisting blind and tangled returns BLND cue")

	# AC2: Tooltip disclosure lines and accurate explanation
	var tip_b_hero := StitchedTurnStatusCues.tooltip(blind_hero)
	var tip_b_foe := StitchedTurnStatusCues.tooltip(blind_foe)
	var tip_t_hero := StitchedTurnStatusCues.tooltip(tangled_hero)
	var tip_t_foe := StitchedTurnStatusCues.tooltip(tangled_foe)
	var tip_dual := StitchedTurnStatusCues.tooltip(dual_hero)

	_check(tip_b_hero.contains("Statuses: blind 1") and
		tip_b_hero.contains("Blind: next attack misses; consumed on that attack."),
		"AC2: blind hero tooltip contains sorted status and documented blind explanation")
	_check(tip_b_foe.contains("Statuses: blind 1") and
		tip_b_foe.contains("Blind: next attack misses; consumed on that attack."),
		"AC2: blind foe tooltip contains sorted status and documented blind explanation")
	_check(tip_t_hero.contains("Statuses: tangled 2") and
		tip_t_hero.contains("Tangled: cannot move or be moved by its side; attacks gain +2 damage."),
		"AC2: tangled hero tooltip contains sorted status and documented tangled explanation")
	_check(tip_t_foe.contains("Statuses: tangled 2") and
		tip_t_foe.contains("Tangled: cannot move or be moved by its side; attacks gain +2 damage."),
		"AC2: tangled foe tooltip contains sorted status and documented tangled explanation")

	var dual_lines := StitchedTurnStatusCues.tooltip_lines(dual_hero)
	var dual_status_idx := dual_lines.find("Statuses: blind 1, tangled 2")
	var dual_blind_idx := dual_lines.find("Blind: next attack misses; consumed on that attack.")
	var dual_tangled_idx := dual_lines.find("Tangled: cannot move or be moved by its side; attacks gain +2 damage.")
	_check(dual_status_idx >= 0 and dual_blind_idx > dual_status_idx and dual_tangled_idx > dual_blind_idx,
		"AC2: coexisting blind and tangled preserves both effects in sorted tooltip disclosure")

	# Mounted ribbon display with blind, tangled, coexisting, and neutral units
	var status_entries := [blind_hero, tangled_foe, dual_hero, neutral_hero]
	ribbon.show_order(status_entries, str(neutral_hero["id"]), false)
	_check(ribbon.displayed_entries.size() == 4, "mounted ribbon shows 4 status test entries")
	_check(ribbon.marker_at(0).text == "BLND" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC1: nonacting blind hero marker is muted BLND")
	_check(ribbon.marker_at(1).text == "TNGL" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC1: nonacting tangled foe marker is muted TNGL")
	_check(ribbon.marker_at(2).text == "BLND" and
		ribbon.marker_at(2).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC1/AC2: coexisting unit marker is muted BLND")
	_check(ribbon.marker_at(3).text == "NOW" and
		ribbon.marker_at(3).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC3: active neutral hero marker is amber NOW")

	# AC1 font-fitting measurement on mounted marker cells at 1280x720
	for idx in range(3):
		var tag := ribbon.tag_at(idx)
		var marker := ribbon.marker_at(idx)
		var font := marker.get_theme_font("font")
		var font_size := marker.get_theme_font_size("font_size")
		var text := marker.text
		_check(marker.size.x >= 34.0 and
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= marker.size.x - 2.0 and
			font.get_height(font_size) <= marker.size.y,
			"AC1: slot %d marker %s fits its measured gothic cell without clipping" % [idx, text])

	# AC2: Equal tooltip on hover and keyboard focus without added nodes
	for idx in range(3):
		var tag := ribbon.tag_at(idx)
		var expected_tip := StitchedTurnStatusCues.tooltip(status_entries[idx])
		_check(tag.tooltip_text == expected_tip, "slot %d tag tooltip_text matches pure tooltip" % idx)
		tag.grab_focus()
		await process_frame
		_check(tag.has_focus() and tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == expected_tip,
			"AC2: slot %d keyboard focus exposes exact complete tooltip" % idx)
		tag.release_focus()
		_check(not tag.get_node("FocusTooltip").visible, "slot %d blur hides tooltip" % idx)
		tag.mouse_entered.emit()
		_check(tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == expected_tip,
			"AC2: slot %d mouse hover exposes identical tooltip to keyboard focus" % idx)
		tag.mouse_exited.emit()
		_check(not tag.get_node("FocusTooltip").visible, "slot %d mouse exit hides tooltip" % idx)
	_check(ribbon.get_child_count() == 9, "AC2: ribbon node count preserved at 9 without added nodes")

	# AC3: Active NOW transitions, actor changes, is_over, and status clearing
	# Blind hero becomes actor
	ribbon.show_order(status_entries, str(blind_hero["id"]), false)
	_check(ribbon.marker_at(0).text == "NOW" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC3: active blind hero marker becomes amber NOW")
	_check(ribbon.marker_at(1).text == "TNGL" and ribbon.marker_at(2).text == "BLND",
		"AC3: nonacting markers remain TNGL and BLND")

	# Tangled foe becomes actor
	ribbon.show_order(status_entries, str(tangled_foe["id"]), false)
	_check(ribbon.marker_at(0).text == "BLND" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC3: previous actor returns to BLND on turn transition")
	_check(ribbon.marker_at(1).text == "NOW" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC3: tangled foe becomes amber NOW")

	# Battle is_over returns true: NOW is superseded and accurate cues return
	ribbon.show_order(status_entries, str(tangled_foe["id"]), true)
	_check(ribbon.marker_at(0).text == "BLND" and ribbon.marker_at(1).text == "TNGL" and
		ribbon.marker_at(2).text == "BLND" and ribbon.marker_at(3).text == "HERO",
		"AC3: is_over=true clears NOW and returns truthful status markers")

	# Removal of Blind and Tangled returns generic HERO/FOE and clears tooltips
	var cleared_b := blind_hero.duplicate(true)
	var cleared_t := tangled_foe.duplicate(true)
	var cleared_d := dual_hero.duplicate(true)
	cleared_b["statuses"] = {}
	cleared_t["statuses"] = {}
	cleared_d["statuses"] = {}
	ribbon.show_order([cleared_b, cleared_t, cleared_d], "", false)
	_check(ribbon.marker_at(0).text == "HERO" and ribbon.marker_at(1).text == "FOE" and
		ribbon.marker_at(2).text == "HERO",
		"AC3: status clearing returns generic HERO/FOE cues")
	for idx in range(3):
		var tag := ribbon.tag_at(idx)
		_check(not tag.tooltip_text.contains("blind") and not tag.tooltip_text.contains("tangled") and
			not tag.tooltip_text.contains("Blind:") and not tag.tooltip_text.contains("Tangled:"),
			"AC3: slot %d tooltip contains no stale blind or tangled text after clearing" % idx)
		_check(not tag.get_node("FocusTooltip/TooltipText").text.contains("blind") and
			not tag.get_node("FocusTooltip/TooltipText").text.contains("tangled"),
			"AC3: slot %d focus tooltip contains no stale text after clearing" % idx)

	# AC3: Overlapping precedence checks:
	# SEAM > STUN > TORN > hero resolve > hero FRAY >=100 > BLD > BLND > TNGL > MARK > HERO/FOE
	for target_dict in [blind_hero.duplicate(true), tangled_hero.duplicate(true)]:
		var st_name: String = "blind" if target_dict["statuses"].has("blind") else "tangled"
		var over: Dictionary = target_dict.duplicate(true)
		over["hanging"] = true
		_check(StitchedTurnStatusCues.cue(over) == "SEAM", "AC3: SEAM overrides %s" % st_name)
		over["hanging"] = false
		over["statuses"]["stun"] = 1
		_check(StitchedTurnStatusCues.cue(over) == "STUN", "AC3: STUN overrides %s" % st_name)
		over["statuses"]["stun"] = 0
		over["parts"]["head"]["torn"] = true
		_check(StitchedTurnStatusCues.cue(over) == "TORN", "AC3: TORN overrides %s" % st_name)
		over["parts"]["head"]["torn"] = false
		over["resolve"] = "steadfast"
		_check(StitchedTurnStatusCues.cue(over) == "STFD", "AC3: hero resolve overrides %s" % st_name)
		over["resolve"] = ""
		over["fray"] = 120
		_check(StitchedTurnStatusCues.cue(over) == "FRAY", "AC3: hero fray >= 100 overrides %s" % st_name)
		over["fray"] = 40
		over["statuses"]["bleed"] = 2
		_check(StitchedTurnStatusCues.cue(over) == "BLD", "AC3: BLD overrides %s" % st_name)

	# BLND > TNGL > MARK
	var blnd_tngl := blind_hero.duplicate(true)
	blnd_tngl["statuses"] = {"blind": 1, "tangled": 1}
	_check(StitchedTurnStatusCues.cue(blnd_tngl) == "BLND", "AC3: BLND overrides TNGL")

	var blnd_mark := blind_hero.duplicate(true)
	blnd_mark["statuses"] = {"blind": 1, "mark": 2}
	_check(StitchedTurnStatusCues.cue(blnd_mark) == "BLND", "AC3: BLND overrides MARK")

	var tngl_mark := tangled_hero.duplicate(true)
	tngl_mark["statuses"] = {"tangled": 1, "mark": 2}
	_check(StitchedTurnStatusCues.cue(tngl_mark) == "TNGL", "AC3: TNGL overrides MARK")

	var mark_only := blind_hero.duplicate(true)
	mark_only["statuses"] = {"mark": 2}
	_check(StitchedTurnStatusCues.cue(mark_only) == "MARK", "AC3: MARK overrides HERO")

	# Foe spoofing hero resolve or fray gets BLND / TNGL, never hero cues
	var f_spoof_b := blind_foe.duplicate(true)
	f_spoof_b["statuses"] = {"blind": 1}
	f_spoof_b["resolve"] = "bitter"
	f_spoof_b["fray"] = 150
	_check(StitchedTurnStatusCues.cue(f_spoof_b) == "BLND", "AC3: foe spoofing hero resolve/fray gets BLND")
	_check(not StitchedTurnStatusCues.tooltip(f_spoof_b).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(f_spoof_b).contains("FRAY:"),
		"AC3: foe with blind does not disclose spoofed resolve or fray")

	var f_spoof_t := tangled_foe.duplicate(true)
	f_spoof_t["statuses"] = {"tangled": 2}
	f_spoof_t["resolve"] = "bitter"
	f_spoof_t["fray"] = 150
	_check(StitchedTurnStatusCues.cue(f_spoof_t) == "TNGL", "AC3: foe spoofing hero resolve/fray gets TNGL")
	_check(not StitchedTurnStatusCues.tooltip(f_spoof_t).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(f_spoof_t).contains("FRAY:"),
		"AC3: foe with tangled does not disclose spoofed resolve or fray")

	# Genuine public hero/foe Stun, Guard and Stun Resist cues and tooltip disclosure (AC1, AC2, AC3, AC4)
	var real_hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	var real_foe: Dictionary = battle.get_foes()[0].duplicate(true)
	var real_ally: Dictionary = battle.get_heroes()[1].duplicate(true)
	var ally_target_id := str(real_ally["id"])

	# AC1: Hero and foe with positive Stun
	var s_hero := real_hero.duplicate(true)
	var s_foe := real_foe.duplicate(true)
	s_hero["statuses"] = {"stun": 1}
	s_foe["statuses"] = {"stun": 2}

	_check(StitchedTurnStatusCues.cue(s_hero) == "STUN", "AC1: hero with positive stun 1 yields STUN cue")
	_check(StitchedTurnStatusCues.cue(s_foe) == "STUN", "AC1: foe with positive stun 2 yields STUN cue")

	var s_hero_tip := StitchedTurnStatusCues.tooltip(s_hero)
	var s_foe_tip := StitchedTurnStatusCues.tooltip(s_foe)
	_check(s_hero_tip.contains("Statuses: stun 1") and s_hero_tip.contains(StitchedTurnStatusCues.STUN_EXPLANATION),
		"AC1: stunned hero tooltip explains that Stun skips next turn and resists next")
	_check(s_foe_tip.contains("Statuses: stun 2") and s_foe_tip.contains(StitchedTurnStatusCues.STUN_EXPLANATION),
		"AC1: stunned foe tooltip explains that Stun skips next turn and resists next")

	ribbon.show_order([s_hero, s_foe], "", false)
	_check(ribbon.displayed_entries.size() == 2, "AC1: mounted ribbon shows 2 stunned units")

	for idx in range(2):
		var tag := ribbon.tag_at(idx)
		var exp_tip := s_hero_tip if idx == 0 else s_foe_tip
		var side_label := "hero" if idx == 0 else "foe"
		_check(tag.tooltip_text == exp_tip, "AC1: %s tag tooltip_text matches pure tooltip" % side_label)
		tag.grab_focus()
		await process_frame
		_check(tag.has_focus() and tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == exp_tip,
			"AC1: %s keyboard focus reveals exact tooltip with Stun explanation" % side_label)
		tag.release_focus()
		_check(not tag.get_node("FocusTooltip").visible, "AC1: %s release focus hides tooltip" % side_label)
		tag.mouse_entered.emit()
		_check(tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == exp_tip,
			"AC1: %s mouse hover reveals exact tooltip matching keyboard focus" % side_label)
		tag.mouse_exited.emit()
		_check(not tag.get_node("FocusTooltip").visible, "AC1: %s mouse exit hides tooltip" % side_label)

	# AC2: Hero with positive Guard and assigned guard_target
	var g_hero := real_hero.duplicate(true)
	g_hero["statuses"] = {"guard": 2, "guard_target": ally_target_id}

	var g_lines := StitchedTurnStatusCues.tooltip_lines(g_hero)
	var g_tip := StitchedTurnStatusCues.tooltip(g_hero)
	_check(g_tip.contains("Statuses: guard 2"),
		"AC2: guarding hero tooltip contains sorted guard 2 status counter")
	_check(g_tip.contains(StitchedTurnStatusCues.GUARD_EXPLANATION),
		"AC2: guarding hero tooltip explains intercepting hits while thread is joined")
	_check(not g_tip.contains(ally_target_id) and not g_tip.contains("guard_target"),
		"AC2: guarding hero tooltip does not invent ally target lookup or leak raw guard_target")

	ribbon.show_order([g_hero], "", false)
	var g_tag := ribbon.tag_at(0)
	_check(g_tag.tooltip_text == g_tip, "AC2: guarding hero tag tooltip_text matches pure tooltip")
	g_tag.grab_focus()
	await process_frame
	var g_focus_text := str(g_tag.get_node("FocusTooltip/TooltipText").text)
	_check(g_tag.has_focus() and g_tag.get_node("FocusTooltip").visible and g_focus_text == g_tip,
		"AC2: guarding hero keyboard focus exposes complete Guard disclosure")
	g_tag.release_focus()
	g_tag.mouse_entered.emit()
	var g_hover_text := str(g_tag.get_node("FocusTooltip/TooltipText").text)
	_check(g_tag.get_node("FocusTooltip").visible and g_hover_text == g_tip and g_hover_text == g_focus_text,
		"AC2: guarding hero hover and keyboard focus are in full parity")
	g_tag.mouse_exited.emit()

	# Clear Guard and refresh: prior explanation disappears
	var g_cleared := real_hero.duplicate(true)
	g_cleared["statuses"] = {}
	ribbon.show_order([g_cleared], "", false)
	_check(not ribbon.tag_at(0).tooltip_text.contains("guard") and
		not ribbon.tag_at(0).tooltip_text.contains("Guard:"),
		"AC2: cleared guard removes guard counter and explanation from tag tooltip")
	_check(not ribbon.tag_at(0).get_node("FocusTooltip/TooltipText").text.contains("guard") and
		not ribbon.tag_at(0).get_node("FocusTooltip/TooltipText").text.contains("Guard:"),
		"AC2: cleared guard leaves no stale text in FocusTooltip")

	# Existing MARK / BLIND / TANGLED explanations remain unaltered with Guard
	var combo_hero := real_hero.duplicate(true)
	combo_hero["statuses"] = {"guard": 2, "mark": 1, "blind": 1, "tangled": 1}
	var combo_tip := StitchedTurnStatusCues.tooltip(combo_hero)
	_check(combo_tip.contains(StitchedTurnStatusCues.GUARD_EXPLANATION) and
		combo_tip.contains(StitchedTurnStatusCues.MARK_EXPLANATION) and
		combo_tip.contains(StitchedTurnStatusCues.BLIND_EXPLANATION) and
		combo_tip.contains(StitchedTurnStatusCues.TANGLED_EXPLANATION),
		"AC2: guard coexisting with mark, blind and tangled preserves all existing explanations")

	# AC3: Temporary stun_resist following consumed Stun, combined statuses, invalid values
	var r_hero := real_hero.duplicate(true)
	r_hero["statuses"] = {"stun_resist": 1}
	var r_tip := StitchedTurnStatusCues.tooltip(r_hero)
	_check(r_tip.contains("Statuses: stun_resist 1") and
		r_tip.contains(StitchedTurnStatusCues.STUN_RESIST_EXPLANATION),
		"AC3: positive stun_resist explains that unit refuses further stun until next turn begins")
	_check(not r_tip.contains(StitchedTurnStatusCues.STUN_EXPLANATION) and
		not r_tip.contains(StitchedTurnStatusCues.GUARD_EXPLANATION),
		"AC3: stun_resist unit does not disclose Stun or Guard explanations")

	# Combined Stun + Guard + stun_resist
	var tri_hero := real_hero.duplicate(true)
	tri_hero["statuses"] = {"stun": 1, "guard": 2, "stun_resist": 1}
	var tri_lines := StitchedTurnStatusCues.tooltip_lines(tri_hero)
	var tri_tip := StitchedTurnStatusCues.tooltip(tri_hero)
	var tri_status_idx := tri_lines.find("Statuses: guard 2, stun 1, stun_resist 1")
	var tri_stun_idx := tri_lines.find(StitchedTurnStatusCues.STUN_EXPLANATION)
	var tri_guard_idx := tri_lines.find(StitchedTurnStatusCues.GUARD_EXPLANATION)
	var tri_resist_idx := tri_lines.find(StitchedTurnStatusCues.STUN_RESIST_EXPLANATION)
	_check(tri_status_idx >= 0 and tri_stun_idx > tri_status_idx and
		tri_guard_idx > tri_status_idx and tri_resist_idx > tri_status_idx,
		"AC3: combined stun+guard+resist produces sorted status counter line followed by all three explanations")

	# Fail-closed checks for stun, guard, stun_resist
	for inv in [0, -1, -3, 1.5, 2.0, "1", "stun", null, [], {}]:
		var h_fail := real_hero.duplicate(true)
		var f_fail := real_foe.duplicate(true)
		h_fail["statuses"] = {"stun": inv, "guard": inv, "stun_resist": inv}
		f_fail["statuses"] = {"stun": inv, "guard": inv, "stun_resist": inv}
		_check(StitchedTurnStatusCues.cue(h_fail) == "HERO",
			"AC3: invalid stun/guard/resist %s yields HERO" % str(inv))
		_check(StitchedTurnStatusCues.cue(f_fail) == "FOE",
			"AC3: invalid stun/guard/resist %s yields FOE" % str(inv))
		var h_fail_tip := StitchedTurnStatusCues.tooltip(h_fail)
		var f_fail_tip := StitchedTurnStatusCues.tooltip(f_fail)
		_check(not h_fail_tip.contains("Stun:") and not h_fail_tip.contains("Guard:") and
			not h_fail_tip.contains("Stun Resist:") and not h_fail_tip.contains("Statuses:"),
			"AC3: invalid stun/guard/resist %s produces no hero explanations or counters" % str(inv))
		_check(not f_fail_tip.contains("Stun:") and not f_fail_tip.contains("Guard:") and
			not f_fail_tip.contains("Stun Resist:") and not f_fail_tip.contains("Statuses:"),
			"AC3: invalid stun/guard/resist %s produces no foe explanations or counters" % str(inv))

	# Precedence: SEAM > STUN > TORN > resolve > FRAY > other cues
	var p_hero := real_hero.duplicate(true)
	p_hero["hanging"] = true
	p_hero["statuses"] = {"stun": 1, "guard": 2, "stun_resist": 1}
	_check(StitchedTurnStatusCues.cue(p_hero) == "SEAM", "AC3: SEAM overrides STUN, Guard and stun_resist")

	p_hero["hanging"] = false
	p_hero["parts"]["head"]["torn"] = true
	_check(StitchedTurnStatusCues.cue(p_hero) == "STUN", "AC3: STUN overrides TORN parts")

	p_hero["parts"]["head"]["torn"] = false
	p_hero["resolve"] = "steadfast"
	_check(StitchedTurnStatusCues.cue(p_hero) == "STUN", "AC3: STUN overrides steadfast resolve")

	p_hero["resolve"] = ""
	p_hero["fray"] = 120
	_check(StitchedTurnStatusCues.cue(p_hero) == "STUN", "AC3: STUN overrides high FRAY >= 100")

	p_hero["fray"] = 20
	p_hero["statuses"] = {"stun": 1, "bleed": 3, "blind": 1, "tangled": 1, "mark": 1}
	_check(StitchedTurnStatusCues.cue(p_hero) == "STUN", "AC3: STUN overrides bleed, blind, tangled, mark")

	# Unit with Guard or stun_resist only (no STUN) falls back to normal role cues
	var g_only_hero := real_hero.duplicate(true)
	g_only_hero["statuses"] = {"guard": 2}
	_check(StitchedTurnStatusCues.cue(g_only_hero) == "HERO", "AC3: guard-only hero has HERO cue (guard adds no marker cue)")

	var r_only_hero := real_hero.duplicate(true)
	r_only_hero["statuses"] = {"stun_resist": 1}
	_check(StitchedTurnStatusCues.cue(r_only_hero) == "HERO", "AC3: stun_resist-only hero has HERO cue (resist adds no marker cue)")

	# AC4 (lane4), AC5 (lane4), AC6 (lane4): Weak and Exposed status cues, tooltip inspection copy, precedence, damage multipliers and fail-closed checks
	var we_hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	var we_foe: Dictionary = battle.get_foes()[0].duplicate(true)
	we_hero["statuses"] = {"weak": 1}
	we_foe["statuses"] = {"exposed": 2}

	# AC4: Distinct <=4-character cues WEAK and EXPD on genuine public hero/foe unit snapshots
	var we_hero_cue := StitchedTurnStatusCues.cue(we_hero)
	var we_foe_cue := StitchedTurnStatusCues.cue(we_foe)
	_check(we_hero_cue == "WEAK" and we_hero_cue.length() <= 4,
		"AC4: public hero with positive native int weak 1 yields WEAK cue")
	_check(we_foe_cue == "EXPD" and we_foe_cue.length() <= 4,
		"AC4: public foe with positive native int exposed 2 yields EXPD cue")

	# Inverted roles: foe with weak, hero with exposed
	var we_foe_weak: Dictionary = battle.get_foes()[1].duplicate(true)
	var we_hero_expd: Dictionary = battle.get_heroes()[1].duplicate(true)
	we_foe_weak["statuses"] = {"weak": 3}
	we_hero_expd["statuses"] = {"exposed": 1}
	_check(StitchedTurnStatusCues.cue(we_foe_weak) == "WEAK",
		"AC4: public foe with positive weak 3 yields WEAK cue")
	_check(StitchedTurnStatusCues.cue(we_hero_expd) == "EXPD",
		"AC4: public hero with positive exposed 1 yields EXPD cue")

	# AC4: Accurate readable tooltip explanations with exact sorted status counters and metadata
	var we_hero_tip := StitchedTurnStatusCues.tooltip(we_hero)
	var we_foe_tip := StitchedTurnStatusCues.tooltip(we_foe)
	_check(we_hero_tip.contains("Statuses: weak 1") and
		we_hero_tip.contains(StitchedTurnStatusCues.WEAK_EXPLANATION) and
		not we_hero_tip.contains("Exposed:") and
		we_hero_tip.contains(str(we_hero["name"])) and
		we_hero_tip.contains("HP: %s / %s" % [str(we_hero["hp"]), str(we_hero["max_hp"])]),
		"AC4: weak hero tooltip discloses sorted weak 1 status counter and accurate explanation without exposed")
	_check(we_foe_tip.contains("Statuses: exposed 2") and
		we_foe_tip.contains(StitchedTurnStatusCues.EXPOSED_EXPLANATION) and
		not we_foe_tip.contains("Weak:") and
		we_foe_tip.contains(str(we_foe["name"])) and
		we_foe_tip.contains("HP: %s / %s" % [str(we_foe["hp"]), str(we_foe["max_hp"])]),
		"AC4: exposed foe tooltip discloses sorted exposed 2 status counter and accurate explanation without weak")

	# AC4: Mounted ribbon marker and tooltip with mouse-hover and keyboard-focus equal disclosures
	var we_entries := [we_hero, we_foe]
	ribbon.show_order(we_entries, "", false)
	_check(ribbon.displayed_entries.size() == 2, "AC4: ribbon displays 2 weak/exposed entries")
	_check(ribbon.marker_at(0).text == "WEAK" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC4: mounted hero tag 0 displays WEAK marker in muted color")
	_check(ribbon.marker_at(1).text == "EXPD" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC4: mounted foe tag 1 displays EXPD marker in muted color")

	for idx in range(2):
		var tag := ribbon.tag_at(idx)
		var exp_tip := we_hero_tip if idx == 0 else we_foe_tip
		var cue_text := "WEAK" if idx == 0 else "EXPD"
		var marker := ribbon.marker_at(idx)
		var font := marker.get_theme_font("font")
		var font_sz := marker.get_theme_font_size("font_size")
		_check(marker.size.x >= 34.0 and
			font.get_string_size(cue_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x <= marker.size.x - 2.0 and
			font.get_height(font_sz) <= marker.size.y,
			"AC4: slot %d marker %s fits measured gothic cell without clipping" % [idx, cue_text])
		_check(tag.tooltip_text == exp_tip, "AC4: slot %d tooltip_text matches pure tooltip" % idx)
		tag.grab_focus()
		await process_frame
		_check(tag.has_focus() and tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == exp_tip,
			"AC4: slot %d keyboard focus reveals exact tooltip for %s" % [idx, cue_text])
		tag.release_focus()
		_check(not tag.get_node("FocusTooltip").visible, "AC4: slot %d blur hides tooltip" % idx)
		tag.mouse_entered.emit()
		_check(tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == exp_tip,
			"AC4: slot %d mouse hover reveals identical tooltip to keyboard focus" % idx)
		tag.mouse_exited.emit()
		_check(not tag.get_node("FocusTooltip").visible, "AC4: slot %d mouse exit hides tooltip" % idx)

	# AC5 (lane4): Inspectable text contents, dual coexistence on one unit, and damage modifier cross-checks
	_check(StitchedTurnStatusCues.WEAK_EXPLANATION.contains("-25%") and
		StitchedTurnStatusCues.WEAK_EXPLANATION.contains("outgoing direct attack damage") and
		StitchedTurnStatusCues.WEAK_EXPLANATION.contains("rounded down"),
		"AC5: Weak explanation text specifies outgoing direct attack damage -25% (rounded down)")
	_check(StitchedTurnStatusCues.EXPOSED_EXPLANATION.contains("+50%") and
		StitchedTurnStatusCues.EXPOSED_EXPLANATION.contains("incoming direct attack damage") and
		StitchedTurnStatusCues.EXPOSED_EXPLANATION.contains("rounded down"),
		"AC5: Exposed explanation text specifies incoming direct attack damage +50% (rounded down)")

	# Dual coexistence on one detached unit: WEAK short cue wins, both explanations disclosed
	var dual_we: Dictionary = battle.get_heroes()[0].duplicate(true)
	dual_we["statuses"] = {"weak": 1, "exposed": 2}
	_check(StitchedTurnStatusCues.cue(dual_we) == "WEAK",
		"AC5: coexisting weak and exposed yields deterministic short cue WEAK")

	var dual_we_tip := StitchedTurnStatusCues.tooltip(dual_we)
	var dual_we_lines := StitchedTurnStatusCues.tooltip_lines(dual_we)
	var we_status_idx := dual_we_lines.find("Statuses: exposed 2, weak 1")
	var we_weak_idx := dual_we_lines.find(StitchedTurnStatusCues.WEAK_EXPLANATION)
	var we_expd_idx := dual_we_lines.find(StitchedTurnStatusCues.EXPOSED_EXPLANATION)
	var we_comb_idx := dual_we_lines.find(StitchedTurnStatusCues.COMBINED_WEAK_EXPOSED_EXPLANATION)
	_check(we_status_idx >= 0 and we_weak_idx > we_status_idx and we_expd_idx > we_weak_idx and we_comb_idx > we_expd_idx,
		"AC5: dual weak+exposed tooltip discloses sorted status counts, both explanations, and combined x9/8 notice")

	# Cross-check declared multipliers using current unchanged StitchedRules.damage_after_modifiers
	# 1. Base 8, no MARK/PROT/Tangled -> Weak alone on attacker: floor(8 * 3/4) = 6
	var dmg_weak_only := StitchedRules.damage_after_modifiers(8, {"weak": 1}, {}, false, 0, 0)
	_check(dmg_weak_only == 6, "AC5: base 8 with Weak alone reduces by 25% to 6")
	# 2. Base 8, no MARK/PROT/Tangled -> Exposed alone on target: floor(8 * 3/2) = 12
	var dmg_expd_only := StitchedRules.damage_after_modifiers(8, {}, {"exposed": 1}, false, 0, 0)
	_check(dmg_expd_only == 12, "AC5: base 8 with Exposed alone increases by 50% to 12")
	# 3. Base 8, no MARK/PROT/Tangled -> Both (Weak on attacker, Exposed on target): floor(8 * 9/8) = 9
	var dmg_both_8 := StitchedRules.damage_after_modifiers(8, {"weak": 1}, {"exposed": 1}, false, 0, 0)
	_check(dmg_both_8 == 9, "AC5: base 8 with Weak attacker and Exposed target yields floor(8 * 9/8) = 9")
	# 4. Base 9 both -> floor(81/8) = 10 (proves single combined floor: floor(9*3/4)=6, floor(6*3/2)=9 != 10)
	var dmg_both_9 := StitchedRules.damage_after_modifiers(9, {"weak": 1}, {"exposed": 1}, false, 0, 0)
	_check(dmg_both_9 == 10, "AC5: base 9 with both yields floor(81/8) = 10, proving single-floor combined x9/8")
	# 5. Combined x9/8 precedes Tangled (+2) and PROT:
	var dmg_tangled_prot := StitchedRules.damage_after_modifiers(8, {"weak": 1}, {"exposed": 1, "tangled": 1}, false, 0, 10)
	_check(dmg_tangled_prot == 10, "AC5: combined 9/8 applies once before Tangled +2 and PROT reduction")

	# AC6 (lane4): Precedence and fail-closed checks
	# Priority order: SEAM > STUN > TORN > resolve > FRAY >= 100 > BLD > BLND > TNGL > MARK > WEAK > EXPD > HERO/FOE
	var prev_hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	prev_hero["statuses"] = {"weak": 1, "exposed": 1}

	# 1. SEAM overrides WEAK and EXPD
	prev_hero["hanging"] = true
	_check(StitchedTurnStatusCues.cue(prev_hero) == "SEAM", "AC6: hanging overrides weak/exposed -> SEAM")
	prev_hero["hanging"] = false

	# 2. STUN overrides WEAK and EXPD
	prev_hero["statuses"]["stun"] = 1
	_check(StitchedTurnStatusCues.cue(prev_hero) == "STUN", "AC6: stun overrides weak/exposed -> STUN")
	prev_hero["statuses"]["stun"] = 0

	# 3. TORN overrides WEAK and EXPD
	prev_hero["parts"]["head"]["torn"] = true
	_check(StitchedTurnStatusCues.cue(prev_hero) == "TORN", "AC6: torn parts override weak/exposed -> TORN")
	prev_hero["parts"]["head"]["torn"] = false

	# 4. Resolve overrides WEAK and EXPD
	prev_hero["resolve"] = "steadfast"
	_check(StitchedTurnStatusCues.cue(prev_hero) == "STFD", "AC6: resolve overrides weak/exposed -> STFD")
	prev_hero["resolve"] = ""

	# 5. Fray >= 100 overrides WEAK and EXPD for hero
	prev_hero["fray"] = 100
	_check(StitchedTurnStatusCues.cue(prev_hero) == "FRAY", "AC6: hero fray >= 100 overrides weak/exposed -> FRAY")
	prev_hero["fray"] = 40

	# 6. BLD overrides WEAK and EXPD
	prev_hero["statuses"]["bleed"] = 2
	_check(StitchedTurnStatusCues.cue(prev_hero) == "BLD", "AC6: bleed overrides weak/exposed -> BLD")
	prev_hero["statuses"]["bleed"] = 0

	# 7. BLND overrides WEAK and EXPD
	prev_hero["statuses"]["blind"] = 1
	_check(StitchedTurnStatusCues.cue(prev_hero) == "BLND", "AC6: blind overrides weak/exposed -> BLND")
	prev_hero["statuses"]["blind"] = 0

	# 8. TNGL overrides WEAK and EXPD
	prev_hero["statuses"]["tangled"] = 1
	_check(StitchedTurnStatusCues.cue(prev_hero) == "TNGL", "AC6: tangled overrides weak/exposed -> TNGL")
	prev_hero["statuses"]["tangled"] = 0

	# 9. MARK overrides WEAK and EXPD
	prev_hero["statuses"]["mark"] = 1
	_check(StitchedTurnStatusCues.cue(prev_hero) == "MARK", "AC6: mark overrides weak/exposed -> MARK")
	prev_hero["statuses"]["mark"] = 0

	# 10. WEAK overrides EXPD
	_check(StitchedTurnStatusCues.cue(prev_hero) == "WEAK", "AC6: weak overrides exposed -> WEAK")

	# 11. EXPD overrides generic HERO/FOE
	prev_hero["statuses"]["weak"] = 0
	_check(StitchedTurnStatusCues.cue(prev_hero) == "EXPD", "AC6: exposed overrides generic HERO -> EXPD")

	var exp_foe: Dictionary = battle.get_foes()[0].duplicate(true)
	exp_foe["statuses"] = {"exposed": 1}
	_check(StitchedTurnStatusCues.cue(exp_foe) == "EXPD", "AC6: exposed overrides generic FOE -> EXPD")

	# Foe spoofing hero resolve or fray gets WEAK/EXPD, never hero cues
	var f_spoof_we: Dictionary = battle.get_foes()[0].duplicate(true)
	f_spoof_we["statuses"] = {"weak": 1}
	f_spoof_we["resolve"] = "bitter"
	f_spoof_we["fray"] = 150
	_check(StitchedTurnStatusCues.cue(f_spoof_we) == "WEAK", "AC6: foe spoofing resolve/fray gets WEAK cue")
	_check(not StitchedTurnStatusCues.tooltip(f_spoof_we).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(f_spoof_we).contains("FRAY:"),
		"AC6: foe with weak does not disclose spoofed resolve or fray")

	# Active NOW transitions and is_over behavior for weak/exposed units
	ribbon.show_order(we_entries, str(we_hero["id"]), false)
	_check(ribbon.marker_at(0).text == "NOW" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC6: active weak hero shows amber NOW")
	_check(ribbon.marker_at(1).text == "EXPD" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC6: nonacting exposed foe shows muted EXPD")

	ribbon.show_order(we_entries, str(we_foe["id"]), false)
	_check(ribbon.marker_at(0).text == "WEAK" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC6: weak hero returns to muted WEAK when foe acts")
	_check(ribbon.marker_at(1).text == "NOW" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC6: acting exposed foe shows amber NOW")

	ribbon.show_order(we_entries, str(we_foe["id"]), true)
	_check(ribbon.marker_at(0).text == "WEAK" and ribbon.marker_at(1).text == "EXPD",
		"AC6: is_over=true clears NOW and returns truthful WEAK and EXPD markers")

	# Status clearing returns generic HERO/FOE with clean tooltips
	var cleared_we_h := we_hero.duplicate(true)
	var cleared_we_f := we_foe.duplicate(true)
	cleared_we_h["statuses"] = {}
	cleared_we_f["statuses"] = {}
	ribbon.show_order([cleared_we_h, cleared_we_f], "", false)
	_check(ribbon.marker_at(0).text == "HERO" and ribbon.marker_at(1).text == "FOE",
		"AC6: cleared units return to generic HERO and FOE cues")
	for idx in range(2):
		var tag := ribbon.tag_at(idx)
		_check(not tag.tooltip_text.contains("weak") and not tag.tooltip_text.contains("exposed") and
			not tag.tooltip_text.contains("Weak:") and not tag.tooltip_text.contains("Exposed:"),
			"AC6: slot %d tag tooltip contains no stale weak or exposed text" % idx)
		_check(not tag.get_node("FocusTooltip/TooltipText").text.contains("weak") and
			not tag.get_node("FocusTooltip/TooltipText").text.contains("exposed") and
			not tag.get_node("FocusTooltip/TooltipText").text.contains("Weak:") and
			not tag.get_node("FocusTooltip/TooltipText").text.contains("Exposed:"),
			"AC6: slot %d focus tooltip contains no stale weak or exposed text" % idx)

	# Fail-closed checks: zero, negative, float, string, null, array, dict
	for inv in [0, -1, -3, 1.5, 2.0, "1", "weak", null, [], {}]:
		var h_we_inv: Dictionary = battle.get_heroes()[0].duplicate(true)
		var f_we_inv: Dictionary = battle.get_foes()[0].duplicate(true)
		h_we_inv["statuses"] = {"weak": inv, "exposed": inv}
		f_we_inv["statuses"] = {"weak": inv, "exposed": inv}
		_check(StitchedTurnStatusCues.cue(h_we_inv) == "HERO",
			"AC6: invalid weak/exposed %s yields HERO fallback" % str(inv))
		_check(StitchedTurnStatusCues.cue(f_we_inv) == "FOE",
			"AC6: invalid weak/exposed %s yields FOE fallback" % str(inv))
		var h_tip := StitchedTurnStatusCues.tooltip(h_we_inv)
		var f_tip := StitchedTurnStatusCues.tooltip(f_we_inv)
		_check(not h_tip.contains("Weak:") and not h_tip.contains("Exposed:") and not h_tip.contains("weak") and not h_tip.contains("exposed"),
			"AC6: invalid weak/exposed %s produces no hero explanations or counters" % str(inv))
		_check(not f_tip.contains("Weak:") and not f_tip.contains("Exposed:") and not f_tip.contains("weak") and not f_tip.contains("exposed"),
			"AC6: invalid weak/exposed %s produces no foe explanations or counters" % str(inv))

	# Non-Dictionary statuses fail closed
	for bad_st in [null, "weak 1", 1, [1]]:
		var h_bad: Dictionary = battle.get_heroes()[0].duplicate(true)
		h_bad["statuses"] = bad_st
		_check(StitchedTurnStatusCues.cue(h_bad) == "HERO",
			"AC6: non-Dictionary statuses %s yields HERO fallback" % str(bad_st))
		var h_bad_tip := StitchedTurnStatusCues.tooltip(h_bad)
		_check(not h_bad_tip.contains("Weak:") and not h_bad_tip.contains("Exposed:"),
			"AC6: non-Dictionary statuses %s produces no weak or exposed explanations" % str(bad_st))

	# AC4: Tooltip fits existing 304x218 NinePatchRect at 1280x720 without resizing
	var test_tag := ribbon.tag_at(0)
	var help_box: NinePatchRect = test_tag.get_node("FocusTooltip")
	var help_text: Label = test_tag.get_node("FocusTooltip/TooltipText")
	_check(help_box.size == Vector2(304, 218),
		"AC4: FocusTooltip NinePatchRect preserves 304x218 dimensions without resizing")
	_check(help_text.size == Vector2(280, 198),
		"AC4: TooltipText label inside FocusTooltip preserves 280x198 text bounds")

	var tip_font := help_text.get_theme_font("font")
	var tip_font_sz := help_text.get_theme_font_size("font_size")
	for fit_unit in [s_hero, s_foe, g_hero, r_hero, tri_hero, we_hero, we_foe, dual_we]:
		var text_to_measure := StitchedTurnStatusCues.tooltip(fit_unit)
		var measured_sz := tip_font.get_multiline_string_size(text_to_measure, HORIZONTAL_ALIGNMENT_LEFT, help_text.size.x, tip_font_sz)
		_check(measured_sz.y <= help_text.size.y,
			"AC4: tooltip for %s fits inside 280x198 text area (measured height %d <= %d)" %
			[fit_unit.get("name", fit_unit.get("id")), int(measured_sz.y), int(help_text.size.y)])

	_check(battle.state_snapshot() == snapshot and battle.rng_state() == rng,
		"AC4: battle snapshot and RNG state are byte-for-byte unaffected by status cue assertions")

	# S7 (lane4): Guard, Riposte and Thorns status cues, tooltips, mounted ribbon and precedence
	var s7_hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	var s7_foe: Dictionary = battle.get_foes()[0].duplicate(true)
	var s7_ally: Dictionary = battle.get_heroes()[1].duplicate(true)
	var s7_ally_id: String = str(s7_ally["id"])
	var s7_hero_id: String = str(s7_hero["id"])
	var s7_foe_id: String = str(s7_foe["id"])

	# AC1: Hero Guard with statuses.guard=2 and guard_target equal to a different allied public ID
	var grd_hero := s7_hero.duplicate(true)
	grd_hero["statuses"] = {"guard": 2}
	grd_hero["guard_target"] = s7_ally_id

	_check(StitchedTurnStatusCues.cue(grd_hero) == "GRD" and StitchedTurnStatusCues.cue(grd_hero).length() <= 4,
		"AC1: public hero with positive int guard 2 and ally guard_target yields GRD cue")
	var grd_tip := StitchedTurnStatusCues.tooltip(grd_hero)
	_check(grd_tip.contains("Statuses: guard 2") and
		grd_tip.contains(StitchedTurnStatusCues.GUARD_EXPLANATION) and
		not grd_tip.contains(s7_ally_id) and not grd_tip.contains("guard_target"),
		"AC1: guard hero tooltip discloses 'guard 2' and interceptor/thread explanation without leaking raw developer ID")

	# AC1 Mounted ribbon: nonacting tag displays GRD, active tag displays NOW
	var s7_unrelated: Dictionary = battle.get_heroes()[2].duplicate(true)
	var s7_unrelated_id := str(s7_unrelated["id"])
	ribbon.show_order([grd_hero, s7_unrelated], s7_unrelated_id, false)
	_check(ribbon.displayed_entries.size() == 2, "AC1: ribbon shows 2 units")
	_check(ribbon.marker_at(0).text == "GRD" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC1: nonactive guard tag displays muted GRD marker")
	_check(ribbon.marker_at(1).text == "NOW" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC1: active tag displays amber NOW")

	# Switch actor to guarding hero: displays NOW
	ribbon.show_order([grd_hero, s7_unrelated], s7_hero_id, false)
	_check(ribbon.marker_at(0).text == "NOW" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC1: active guard hero marker displays amber NOW")

	# AC1 Negative guard checks: foe, missing guard_target, empty guard_target, self guard_target, non-positive
	var grd_foe := s7_foe.duplicate(true)
	grd_foe["statuses"] = {"guard": 2}
	grd_foe["guard_target"] = str(battle.get_foes()[1]["id"])
	_check(StitchedTurnStatusCues.cue(grd_foe) == "FOE",
		"AC1: foe with forged guard status does not advertise itself as a hero guardian (yields FOE)")

	var grd_self := s7_hero.duplicate(true)
	grd_self["statuses"] = {"guard": 2}
	grd_self["guard_target"] = s7_hero_id
	_check(StitchedTurnStatusCues.cue(grd_self) == "HERO",
		"AC1: hero with guard_target equal to self yields HERO fallback")

	var grd_blank := s7_hero.duplicate(true)
	grd_blank["statuses"] = {"guard": 2}
	grd_blank["guard_target"] = ""
	_check(StitchedTurnStatusCues.cue(grd_blank) == "HERO",
		"AC1: hero with blank guard_target yields HERO fallback")

	var grd_missing := s7_hero.duplicate(true)
	grd_missing["statuses"] = {"guard": 2}
	grd_missing.erase("guard_target")
	_check(StitchedTurnStatusCues.cue(grd_missing) == "HERO",
		"AC1: hero with missing guard_target yields HERO fallback")

	# AC2: Hero and foe with Riposte and Thorns (1 and 3)
	for val in [1, 3]:
		var rip_h := s7_hero.duplicate(true)
		var rip_f := s7_foe.duplicate(true)
		rip_h["statuses"] = {"riposte": val}
		rip_f["statuses"] = {"riposte": val}
		_check(StitchedTurnStatusCues.cue(rip_h) == "RIP" and StitchedTurnStatusCues.cue(rip_h).length() <= 4,
			"AC2: hero with riposte %d yields RIP cue" % val)
		_check(StitchedTurnStatusCues.cue(rip_f) == "RIP" and StitchedTurnStatusCues.cue(rip_f).length() <= 4,
			"AC2: foe with riposte %d yields RIP cue" % val)

		var rip_h_tip := StitchedTurnStatusCues.tooltip(rip_h)
		var rip_f_tip := StitchedTurnStatusCues.tooltip(rip_f)
		_check(rip_h_tip.contains("Statuses: riposte %d" % val) and
			rip_h_tip.contains(StitchedTurnStatusCues.RIPOSTE_EXPLANATION) and
			rip_h_tip.contains("retaliation on a confirmed hit by a surviving target, ignoring PROT"),
			"AC2: hero riposte %d tooltip contains counter and retaliation explanation" % val)
		_check(rip_f_tip.contains("Statuses: riposte %d" % val) and
			rip_f_tip.contains(StitchedTurnStatusCues.RIPOSTE_EXPLANATION) and
			rip_f_tip.contains("retaliation on a confirmed hit by a surviving target, ignoring PROT"),
			"AC2: foe riposte %d tooltip contains counter and retaliation explanation" % val)

		var thrn_h := s7_hero.duplicate(true)
		var thrn_f := s7_foe.duplicate(true)
		thrn_h["statuses"] = {"thorns": val}
		thrn_f["statuses"] = {"thorns": val}
		_check(StitchedTurnStatusCues.cue(thrn_h) == "THRN" and StitchedTurnStatusCues.cue(thrn_h).length() <= 4,
			"AC2: hero with thorns %d yields THRN cue" % val)
		_check(StitchedTurnStatusCues.cue(thrn_f) == "THRN" and StitchedTurnStatusCues.cue(thrn_f).length() <= 4,
			"AC2: foe with thorns %d yields THRN cue" % val)

		var thrn_h_tip := StitchedTurnStatusCues.tooltip(thrn_h)
		var thrn_f_tip := StitchedTurnStatusCues.tooltip(thrn_f)
		_check(thrn_h_tip.contains("Statuses: thorns %d" % val) and
			thrn_h_tip.contains(StitchedTurnStatusCues.THORNS_EXPLANATION) and
			thrn_h_tip.contains("retaliation on a confirmed hit by a surviving target, ignoring PROT"),
			"AC2: hero thorns %d tooltip contains counter and retaliation explanation" % val)
		_check(thrn_f_tip.contains("Statuses: thorns %d" % val) and
			thrn_f_tip.contains(StitchedTurnStatusCues.THORNS_EXPLANATION) and
			thrn_f_tip.contains("retaliation on a confirmed hit by a surviving target, ignoring PROT"),
			"AC2: foe thorns %d tooltip contains counter and retaliation explanation" % val)

	# AC2: Mounted ribbon projection for Guard, Riposte and Thorns in order
	var mount_grd := s7_hero.duplicate(true)
	mount_grd["statuses"] = {"guard": 2}
	mount_grd["guard_target"] = s7_ally_id
	var mount_rip := s7_foe.duplicate(true)
	mount_rip["statuses"] = {"riposte": 1}
	var mount_thrn := s7_ally.duplicate(true)
	mount_thrn["statuses"] = {"thorns": 3}
	var mount_entries := [mount_grd, mount_rip, mount_thrn]

	ribbon.show_order(mount_entries, "", false)
	_check(ribbon.displayed_entries.size() == 3, "AC2: ribbon displays 3 counterattack/guard entries")
	_check(ribbon.marker_at(0).text == "GRD" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC2: tag 0 displays muted GRD marker")
	_check(ribbon.marker_at(1).text == "RIP" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC2: tag 1 displays muted RIP marker")
	_check(ribbon.marker_at(2).text == "THRN" and
		ribbon.marker_at(2).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC2: tag 2 displays muted THRN marker")

	# AC4 font-fitting check on the new markers
	for idx in range(3):
		var marker := ribbon.marker_at(idx)
		var font := marker.get_theme_font("font")
		var font_sz := marker.get_theme_font_size("font_size")
		var text := marker.text
		_check(marker.size.x >= 34.0 and
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x <= marker.size.x - 2.0 and
			font.get_height(font_sz) <= marker.size.y,
			"AC4: slot %d marker %s fits measured gothic cell without clipping" % [idx, text])

	# AC4: Focus and hover parity on the new markers
	for idx in range(3):
		var tag := ribbon.tag_at(idx)
		var exp_tip := StitchedTurnStatusCues.tooltip(mount_entries[idx])
		_check(tag.tooltip_text == exp_tip, "AC4: slot %d tooltip_text matches pure tooltip" % idx)
		tag.grab_focus()
		await process_frame
		_check(tag.has_focus() and tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == exp_tip,
			"AC4: slot %d keyboard focus reveals exact tooltip" % idx)
		tag.release_focus()
		_check(not tag.get_node("FocusTooltip").visible, "AC4: slot %d blur hides tooltip" % idx)
		tag.mouse_entered.emit()
		_check(tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == exp_tip,
			"AC4: slot %d mouse hover reveals identical tooltip to keyboard focus" % idx)
		tag.mouse_exited.emit()
		_check(not tag.get_node("FocusTooltip").visible, "AC4: slot %d mouse exit hides tooltip" % idx)

	# Actor cycling across GRD, RIP, THRN: prove prior marker returns (no stale NOW)
	var grd_id := str(mount_grd["id"])
	var rip_id := str(mount_rip["id"])
	var thrn_id := str(mount_thrn["id"])

	# GRD acts
	ribbon.show_order(mount_entries, grd_id, false)
	_check(ribbon.marker_at(0).text == "NOW" and ribbon.marker_at(1).text == "RIP" and ribbon.marker_at(2).text == "THRN",
		"AC3: GRD actor shows NOW, other nonacting markers are RIP and THRN")

	# RIP acts: GRD returns!
	ribbon.show_order(mount_entries, rip_id, false)
	_check(ribbon.marker_at(0).text == "GRD" and ribbon.marker_at(1).text == "NOW" and ribbon.marker_at(2).text == "THRN",
		"AC3: prior GRD marker returns with no stale NOW when RIP acts")

	# THRN acts: RIP returns!
	ribbon.show_order(mount_entries, thrn_id, false)
	_check(ribbon.marker_at(0).text == "GRD" and ribbon.marker_at(1).text == "RIP" and ribbon.marker_at(2).text == "NOW",
		"AC3: prior RIP marker returns with no stale NOW when THRN acts")

	# Unrelated acts: THRN returns!
	ribbon.show_order(mount_entries, s7_unrelated_id, false)
	_check(ribbon.marker_at(0).text == "GRD" and ribbon.marker_at(1).text == "RIP" and ribbon.marker_at(2).text == "THRN",
		"AC3: all three return when unrelated unit acts")

	# Battle is over: clears NOW, truthful markers return
	ribbon.show_order(mount_entries, grd_id, true)
	_check(ribbon.marker_at(0).text == "GRD" and ribbon.marker_at(1).text == "RIP" and ribbon.marker_at(2).text == "THRN",
		"AC3: is_over=true clears NOW and returns truthful GRD, RIP, THRN markers")

	# Status clearing: generic HERO/FOE returns and no stale text
	var cleared_grd := mount_grd.duplicate(true)
	var cleared_rip := mount_rip.duplicate(true)
	var cleared_thrn := mount_thrn.duplicate(true)
	cleared_grd["statuses"] = {}
	cleared_grd["guard_target"] = ""
	cleared_rip["statuses"] = {}
	cleared_thrn["statuses"] = {}
	ribbon.show_order([cleared_grd, cleared_rip, cleared_thrn], "", false)
	_check(ribbon.marker_at(0).text == "HERO" and ribbon.marker_at(1).text == "FOE" and ribbon.marker_at(2).text == "HERO",
		"AC3: cleared statuses return generic HERO and FOE cues")
	for idx in range(3):
		var tag := ribbon.tag_at(idx)
		_check(not tag.tooltip_text.contains("guard") and not tag.tooltip_text.contains("riposte") and not tag.tooltip_text.contains("thorns") and
			not tag.tooltip_text.contains("Guard:") and not tag.tooltip_text.contains("Riposte:") and not tag.tooltip_text.contains("Thorns:"),
			"AC3: slot %d tag tooltip contains no stale guard/riposte/thorns text" % idx)

	# AC3: Overlapping precedence order
	# SEAM > STUN > TORN > hero Resolve > hero FRAY >=100 > BLD > GRD > RIP > THRN > BLND/TNGL/MARK/WEAK/EXPD > generic HERO/FOE
	var multi_h := s7_hero.duplicate(true)
	multi_h["guard_target"] = s7_ally_id

	# GRD > RIP > THRN
	multi_h["statuses"] = {"guard": 2, "riposte": 1, "thorns": 1}
	_check(StitchedTurnStatusCues.cue(multi_h) == "GRD", "AC3: GRD wins over RIP and THRN")
	var multi_tip := StitchedTurnStatusCues.tooltip(multi_h)
	_check(multi_tip.contains("Statuses: guard 2, riposte 1, thorns 1") and
		multi_tip.contains(StitchedTurnStatusCues.GUARD_EXPLANATION) and
		multi_tip.contains(StitchedTurnStatusCues.RIPOSTE_EXPLANATION) and
		multi_tip.contains(StitchedTurnStatusCues.THORNS_EXPLANATION),
		"AC3: priority GRD marker does not hide other counters or explanations from full tooltip")

	# RIP > THRN
	multi_h["statuses"] = {"riposte": 1, "thorns": 2}
	_check(StitchedTurnStatusCues.cue(multi_h) == "RIP", "AC3: RIP wins over THRN")

	# Higher warnings beat GRD, RIP, THRN:
	# BLD > GRD
	multi_h["statuses"] = {"bleed": 1, "guard": 2, "riposte": 1, "thorns": 1}
	_check(StitchedTurnStatusCues.cue(multi_h) == "BLD", "AC3: BLD overrides GRD, RIP, THRN")

	# FRAY >= 100 > BLD
	multi_h["fray"] = 100
	_check(StitchedTurnStatusCues.cue(multi_h) == "FRAY", "AC3: FRAY >= 100 overrides BLD, GRD, RIP, THRN")
	multi_h["fray"] = 20

	# Resolve > FRAY
	multi_h["resolve"] = "steadfast"
	_check(StitchedTurnStatusCues.cue(multi_h) == "STFD", "AC3: Resolve overrides BLD, GRD, RIP, THRN")
	multi_h["resolve"] = ""

	# TORN > Resolve
	multi_h["parts"]["head"]["torn"] = true
	_check(StitchedTurnStatusCues.cue(multi_h) == "TORN", "AC3: TORN overrides BLD, GRD, RIP, THRN")
	multi_h["parts"]["head"]["torn"] = false

	# STUN > TORN
	multi_h["statuses"]["stun"] = 1
	_check(StitchedTurnStatusCues.cue(multi_h) == "STUN", "AC3: STUN overrides BLD, GRD, RIP, THRN")
	multi_h["statuses"]["stun"] = 0

	# SEAM > STUN
	multi_h["hanging"] = true
	_check(StitchedTurnStatusCues.cue(multi_h) == "SEAM", "AC3: SEAM overrides STUN, BLD, GRD, RIP, THRN")
	multi_h["hanging"] = false

	# GRD, RIP, THRN beat lower statuses BLND, TNGL, MARK, WEAK, EXPD:
	multi_h["statuses"] = {"thorns": 2, "blind": 1, "tangled": 1, "mark": 1, "weak": 1, "exposed": 1}
	_check(StitchedTurnStatusCues.cue(multi_h) == "THRN", "AC3: THRN overrides BLND, TNGL, MARK, WEAK, EXPD")

	multi_h["statuses"]["riposte"] = 1
	_check(StitchedTurnStatusCues.cue(multi_h) == "RIP", "AC3: RIP overrides THRN, BLND, TNGL, MARK, WEAK, EXPD")

	multi_h["statuses"]["guard"] = 2
	_check(StitchedTurnStatusCues.cue(multi_h) == "GRD", "AC3: GRD overrides RIP, THRN, BLND, TNGL, MARK, WEAK, EXPD")

	# Foe spoofing resolve/fray gets RIP/THRN
	var f_spoof_rt := s7_foe.duplicate(true)
	f_spoof_rt["resolve"] = "bitter"
	f_spoof_rt["fray"] = 150
	f_spoof_rt["statuses"] = {"riposte": 1}
	_check(StitchedTurnStatusCues.cue(f_spoof_rt) == "RIP", "AC3: foe spoofing resolve/fray gets RIP cue")
	_check(not StitchedTurnStatusCues.tooltip(f_spoof_rt).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(f_spoof_rt).contains("FRAY:"),
		"AC3: foe with riposte does not disclose spoofed resolve or fray")

	f_spoof_rt["statuses"] = {"thorns": 2}
	_check(StitchedTurnStatusCues.cue(f_spoof_rt) == "THRN", "AC3: foe spoofing resolve/fray gets THRN cue")

	# Fail-closed checks on guard, riposte, thorns: nonpositive or wrongly typed
	for inv in [0, -1, -3, 1.5, 2.0, "1", "riposte", null, [], {}]:
		var h_fail_grt := s7_hero.duplicate(true)
		var f_fail_grt := s7_foe.duplicate(true)
		h_fail_grt["guard_target"] = s7_ally_id
		h_fail_grt["statuses"] = {"guard": inv, "riposte": inv, "thorns": inv}
		f_fail_grt["statuses"] = {"guard": inv, "riposte": inv, "thorns": inv}
		_check(StitchedTurnStatusCues.cue(h_fail_grt) == "HERO",
			"AC3: invalid guard/riposte/thorns %s yields HERO fallback" % str(inv))
		_check(StitchedTurnStatusCues.cue(f_fail_grt) == "FOE",
			"AC3: invalid guard/riposte/thorns %s yields FOE fallback" % str(inv))
		var h_tip := StitchedTurnStatusCues.tooltip(h_fail_grt)
		var f_tip := StitchedTurnStatusCues.tooltip(f_fail_grt)
		_check(not h_tip.contains("Guard:") and not h_tip.contains("Riposte:") and not h_tip.contains("Thorns:") and
			not h_tip.contains("guard") and not h_tip.contains("riposte") and not h_tip.contains("thorns"),
			"AC3: invalid guard/riposte/thorns %s produces no explanations or counters" % str(inv))
		_check(not f_tip.contains("Guard:") and not f_tip.contains("Riposte:") and not f_tip.contains("Thorns:") and
			not f_tip.contains("guard") and not f_tip.contains("riposte") and not f_tip.contains("thorns"),
			"AC3: invalid foe guard/riposte/thorns %s produces no explanations or counters" % str(inv))

	# Non-Dictionary statuses fail closed
	for bad_st in [null, "riposte 1", 1, [1]]:
		var h_bad: Dictionary = s7_hero.duplicate(true)
		h_bad["guard_target"] = s7_ally_id
		h_bad["statuses"] = bad_st
		_check(StitchedTurnStatusCues.cue(h_bad) == "HERO",
			"AC3: non-Dictionary statuses %s yields HERO fallback" % str(bad_st))
		var h_bad_tip := StitchedTurnStatusCues.tooltip(h_bad)
		_check(not h_bad_tip.contains("Guard:") and not h_bad_tip.contains("Riposte:") and not h_bad_tip.contains("Thorns:"),
			"AC3: non-Dictionary statuses %s produces no explanations" % str(bad_st))

	# AC4: Tooltip fits inside 280x198 text bounds for all new combinations
	var clean_dual := s7_hero.duplicate(true)
	clean_dual["statuses"] = {"guard": 2, "riposte": 1}
	clean_dual["guard_target"] = s7_ally_id
	var clean_dual_rt := s7_foe.duplicate(true)
	clean_dual_rt["statuses"] = {"riposte": 1, "thorns": 2}
	for fit_unit in [grd_hero, mount_rip, mount_thrn, clean_dual, clean_dual_rt]:
		var text_to_measure := StitchedTurnStatusCues.tooltip(fit_unit)
		var measured_sz := tip_font.get_multiline_string_size(text_to_measure, HORIZONTAL_ALIGNMENT_LEFT, help_text.size.x, tip_font_sz)
		_check(measured_sz.y <= help_text.size.y,
			"AC4: tooltip for %s fits inside 280x198 text area (measured height %d <= %d)" %
			[fit_unit.get("name", fit_unit.get("id")), int(measured_sz.y), int(help_text.size.y)])

	# AC4: Zero, negative, float, string, missing, malformed status values fail closed
	for invalid_val in [0, -1, -3, 1.5, 2.0, "1", "blind", null, [], {}]:
		var h_inv := blind_hero.duplicate(true)
		var f_inv := blind_foe.duplicate(true)
		h_inv["statuses"] = {"blind": invalid_val, "tangled": invalid_val}
		f_inv["statuses"] = {"blind": invalid_val, "tangled": invalid_val}
		_check(StitchedTurnStatusCues.cue(h_inv) == "HERO",
			"AC4: invalid blind/tangled %s yields HERO fallback" % str(invalid_val))
		_check(StitchedTurnStatusCues.cue(f_inv) == "FOE",
			"AC4: invalid blind/tangled %s yields FOE fallback" % str(invalid_val))
		var h_inv_tip := StitchedTurnStatusCues.tooltip(h_inv)
		var f_inv_tip := StitchedTurnStatusCues.tooltip(f_inv)
		_check(not h_inv_tip.contains("blind") and not h_inv_tip.contains("tangled") and
			not h_inv_tip.contains("Blind:") and not h_inv_tip.contains("Tangled:"),
			"AC4: invalid blind/tangled %s invents no hero condition" % str(invalid_val))
		_check(not f_inv_tip.contains("blind") and not f_inv_tip.contains("tangled") and
			not f_inv_tip.contains("Blind:") and not f_inv_tip.contains("Tangled:"),
			"AC4: invalid blind/tangled %s invents no foe condition" % str(invalid_val))

	for invalid_resolve in ["unknown", "STEADFAST", "Bitter", "panic", 99, null, ["steadfast"]]:
		var invalid_hero: Dictionary = battle.get_heroes()[1].duplicate(true)
		invalid_hero["fray"] = 45
		invalid_hero["resolve"] = invalid_resolve
		var invalid_tip := StitchedTurnStatusCues.tooltip(invalid_hero)
		_check(StitchedTurnStatusCues.cue(invalid_hero) == "HERO" and
			not invalid_tip.contains("Resolve:") and
			not invalid_tip.contains("Steadfast") and
			not invalid_tip.contains("Unravelled") and
			not invalid_tip.contains("+10%"),
			"invalid resolve %s at 45 fray falls back to HERO without invented trait or bonus" % str(invalid_resolve))
		invalid_hero["fray"] = 100
		_check(StitchedTurnStatusCues.cue(invalid_hero) == "FRAY",
			"invalid resolve %s at 100 fray falls back to numeric FRAY warning" % str(invalid_resolve))

	# Malformed optional fields may not masquerade as 0, a stun or torn equipment.
	var sparse := {"id":"never_mapped_art","name":"Unknown Stitch","side":"hero","rank":4,
		"hp":9,"max_hp":19,"speed":"bad","fray":"100","resolve":0,
		"statuses":{"stun":"2","bleed":0,"mark":-1,"blind":0,"tangled":"bad"},"parts":{"head":{"torn":"true"}}}
	_check(StitchedTurnStatusCues.cue(sparse) == "HERO" and
		StitchedTurnStatusCues.torn_slots(sparse).is_empty() and
		StitchedTurnStatusCues.tooltip(sparse).contains("HP: 9 / 19") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("SPEED") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("DODGE") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("FRAY") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Statuses:") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Blind:") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Tangled:") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Stun:") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Guard:") and
		not StitchedTurnStatusCues.tooltip(sparse).contains("Stun Resist:"),
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
		var boss_snapshot := boss.state_snapshot()
		var boss_rng := boss.rng_state()
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
		_check(boss.turn_order().size() == 8 and boss.state_snapshot() == boss_snapshot and boss.rng_state() == boss_rng,
			"boss public order remains present after view projection")

	# Every existing cue must remain complete at the narrowest nine-tag capacity.
	var all_cues: Array = resolve_snapshots.duplicate(true)
	for status in ["stun", "bleed", "rot", "riposte", "thorns", "blind", "tangled", "mark", "weak", "exposed", "regen"]:
		var sample: Dictionary = battle.get_heroes()[0].duplicate(true)
		sample.statuses = {status: 2}
		all_cues.append(sample)
	var sample_grd: Dictionary = battle.get_heroes()[0].duplicate(true)
	sample_grd.statuses = {"guard": 2}
	sample_grd["guard_target"] = str(battle.get_heroes()[1]["id"])
	all_cues.append(sample_grd)
	for state in ["hanging", "torn", "fray"]:
		var sample: Dictionary = battle.get_heroes()[0].duplicate(true)
		if state == "hanging":
			sample.hanging = true
		elif state == "torn":
			sample.parts.head.torn = true
		else:
			sample.fray = 100
		all_cues.append(sample)
	all_cues.append(hero)
	all_cues.append(battle.get_heroes()[0])
	all_cues.append(battle.get_foes()[0])
	for sample: Dictionary in all_cues:
		var crowded: Array = []
		for i in range(9):
			crowded.append(sample.duplicate(true))
		ribbon.show_order(crowded, "", false)
		_check_fit(ribbon, 9)
		for i in range(9):
			_check(ribbon.marker_at(i).text == StitchedTurnStatusCues.cue(sample) and
				ribbon.tag_at(i).tooltip_text == StitchedTurnStatusCues.tooltip(sample),
				"nine-tag capacity preserves full %s cue and exact tooltip at slot %d" % [StitchedTurnStatusCues.cue(sample), i])

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

	# S14 (lane4): Accurate Hanging and Regeneration turn-status tooltips (AC1, AC2, AC3)
	var s14_test_tag := ribbon.tag_at(0)
	var s14_help_text: Label = s14_test_tag.get_node("FocusTooltip/TooltipText")
	var s14_tip_font := s14_help_text.get_theme_font("font")
	var s14_tip_font_sz := s14_help_text.get_theme_font_size("font_size")

	# AC1: Public four-doll StitchedRules hero snapshots at HP 0, hanging=true and death_hits in 0..2
	var four_heroes: Array = battle.get_heroes()
	for h_idx in range(four_heroes.size()):
		for dh in [0, 1, 2]:
			var d_hero: Dictionary = four_heroes[h_idx].duplicate(true)
			d_hero["hp"] = 0
			d_hero["hanging"] = true
			d_hero["death_hits"] = dh
			var d_snapshot := d_hero.duplicate(true)

			# SEAM marker priority
			_check(StitchedTurnStatusCues.cue(d_hero) == "SEAM",
				"AC1: hero %d at HP 0 hanging=true death_hits=%d gives SEAM cue" % [h_idx, dh])

			var d_tip := StitchedTurnStatusCues.tooltip(d_hero)
			_check(d_tip.contains(StitchedTurnStatusCues.HANGING_EXPLANATION),
				"AC1: hero %d death_hits=%d tooltip contains full truthful HANGING_EXPLANATION" % [h_idx, dh])
			_check(d_tip.contains("a damaging zero-HP hit tears a remaining arm, leg or head") and
				d_tip.contains("losing the head means LOST") and
				d_tip.contains("A heal above zero ends Hanging and resets accumulated hits"),
				"AC1: hero %d death_hits=%d describes arm/leg/head loss, head=LOST, and heal ending Hanging" % [h_idx, dh])
			_check(not d_tip.contains("67%") and not d_tip.contains("33%") and not d_tip.contains("seam hold"),
				"AC1: hero %d death_hits=%d contains no obsolete 67%%/33%% seam-check claims" % [h_idx, dh])

			# Verify input snapshot was not mutated
			_check(d_hero == d_snapshot, "AC1: caller snapshot was not mutated by cue or tooltip")

			# Mounted ribbon equivalence under keyboard focus and mouse hover
			ribbon.show_order([d_hero], "", false)
			var h_tag := ribbon.tag_at(0)
			_check(ribbon.marker_at(0).text == "SEAM", "AC1: mounted ribbon slot 0 displays SEAM marker")
			_check(h_tag.tooltip_text == d_tip, "AC1: mounted tag tooltip_text matches pure tooltip")

			h_tag.grab_focus()
			await process_frame
			_check(h_tag.has_focus() and h_tag.get_node("FocusTooltip").visible and
				h_tag.get_node("FocusTooltip/TooltipText").text == d_tip,
				"AC1: hero %d death_hits=%d keyboard focus exposes exact death-door tooltip" % [h_idx, dh])
			h_tag.release_focus()
			_check(not h_tag.get_node("FocusTooltip").visible, "AC1: blur hides tooltip")

			h_tag.mouse_entered.emit()
			_check(h_tag.get_node("FocusTooltip").visible and
				h_tag.get_node("FocusTooltip/TooltipText").text == d_tip,
				"AC1: hero %d death_hits=%d mouse hover exposes identical tooltip to focus" % [h_idx, dh])
			h_tag.mouse_exited.emit()
			_check(not h_tag.get_node("FocusTooltip").visible, "AC1: hover exit hides tooltip")

			# Font bounds check inside 280x198 box
			var d_measured := s14_tip_font.get_multiline_string_size(d_tip, HORIZONTAL_ALIGNMENT_LEFT, s14_help_text.size.x, s14_tip_font_sz)
			_check(d_measured.y <= s14_help_text.size.y,
				"AC1: hero %d death_hits=%d tooltip fits inside 280x198 bounds (%d <= %d)" % [h_idx, dh, int(d_measured.y), int(s14_help_text.size.y)])

	# AC2: Live-shaped hero or foe statuses dictionary with regen=2
	var live_hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	var live_foe: Dictionary = battle.get_foes()[0].duplicate(true)
	live_hero["statuses"] = {"regen": 2}
	live_foe["statuses"] = {"regen": 2}

	var hero_reg_snapshot := live_hero.duplicate(true)
	var foe_reg_snapshot := live_foe.duplicate(true)

	_check(StitchedTurnStatusCues.cue(live_hero) == "REGN", "AC2: hero with regen 2 yields REGN cue")
	_check(StitchedTurnStatusCues.cue(live_foe) == "REGN", "AC2: foe with regen 2 yields REGN cue")

	var live_h_tip := StitchedTurnStatusCues.tooltip(live_hero)
	var live_f_tip := StitchedTurnStatusCues.tooltip(live_foe)

	_check(live_h_tip.contains("Statuses: regen 2"), "AC2: hero tooltip contains Statuses: regen 2 counter")
	_check(live_f_tip.contains("Statuses: regen 2"), "AC2: foe tooltip contains Statuses: regen 2 counter")

	_check(live_h_tip.contains(StitchedTurnStatusCues.REGEN_EXPLANATION),
		"AC2: hero tooltip contains exact REGEN_EXPLANATION")
	_check(live_f_tip.contains(StitchedTurnStatusCues.REGEN_EXPLANATION),
		"AC2: foe tooltip contains exact REGEN_EXPLANATION")

	for check_tip in [live_h_tip, live_f_tip]:
		_check(check_tip.contains("restores exactly 2 HP") and
			check_tip.contains("at the affected unit's turn start") and
			check_tip.contains("capped at max HP") and
			check_tip.contains("before Bleed") and
			check_tip.contains("consumes one turn") and
			check_tip.contains("can bring a Hanging doll above 0"),
			"AC2: tooltip explains 2 HP restore, turn start, max HP cap, before Bleed, consumes 1 turn, brings Hanging doll above 0")

	_check(live_hero == hero_reg_snapshot, "AC2: hero input dictionary was not mutated")
	_check(live_foe == foe_reg_snapshot, "AC2: foe input dictionary was not mutated")

	# Mounted ribbon equivalence for hero and foe with regen=2
	ribbon.show_order([live_hero, live_foe], "", false)
	for reg_idx in range(2):
		var reg_unit: Dictionary = live_hero if reg_idx == 0 else live_foe
		var reg_exp_tip: String = live_h_tip if reg_idx == 0 else live_f_tip
		var reg_tag := ribbon.tag_at(reg_idx)
		var exp_marker := "REGN"
		_check(ribbon.marker_at(reg_idx).text == exp_marker, "AC2: slot %d displays %s marker" % [reg_idx, exp_marker])
		_check(reg_tag.tooltip_text == reg_exp_tip, "AC2: slot %d tooltip_text matches pure tooltip" % reg_idx)

		reg_tag.grab_focus()
		await process_frame
		_check(reg_tag.has_focus() and reg_tag.get_node("FocusTooltip").visible and
			reg_tag.get_node("FocusTooltip/TooltipText").text == reg_exp_tip,
			"AC2: slot %d keyboard focus reveals exact regen tooltip" % reg_idx)
		reg_tag.release_focus()
		_check(not reg_tag.get_node("FocusTooltip").visible, "AC2: slot %d blur hides tooltip" % reg_idx)

		reg_tag.mouse_entered.emit()
		_check(reg_tag.get_node("FocusTooltip").visible and
			reg_tag.get_node("FocusTooltip/TooltipText").text == reg_exp_tip,
			"AC2: slot %d mouse hover reveals identical tooltip to keyboard focus" % reg_idx)
		reg_tag.mouse_exited.emit()
		_check(not reg_tag.get_node("FocusTooltip").visible, "AC2: slot %d hover exit hides tooltip" % reg_idx)

		var reg_measured := s14_tip_font.get_multiline_string_size(reg_exp_tip, HORIZONTAL_ALIGNMENT_LEFT, s14_help_text.size.x, s14_tip_font_sz)
		_check(reg_measured.y <= s14_help_text.size.y,
			"AC2: slot %d regen tooltip fits inside 280x198 bounds (%d <= %d)" % [reg_idx, int(reg_measured.y), int(s14_help_text.size.y)])

	# AC2: With regen=0 or negative or absent, no Regeneration explanation appears
	for non_pos_val in [0, -1, -3]:
		var h_non_pos: Dictionary = battle.get_heroes()[0].duplicate(true)
		var f_non_pos: Dictionary = battle.get_foes()[0].duplicate(true)
		h_non_pos["statuses"] = {"regen": non_pos_val}
		f_non_pos["statuses"] = {"regen": non_pos_val}
		var h_np_tip := StitchedTurnStatusCues.tooltip(h_non_pos)
		var f_np_tip := StitchedTurnStatusCues.tooltip(f_non_pos)
		_check(not h_np_tip.contains("Regeneration:") and not h_np_tip.contains("regen"),
			"AC2: hero with non-positive regen %d displays no Regeneration explanation or counter" % non_pos_val)
		_check(not f_np_tip.contains("Regeneration:") and not f_np_tip.contains("regen"),
			"AC2: foe with non-positive regen %d displays no Regeneration explanation or counter" % non_pos_val)

	var h_absent: Dictionary = battle.get_heroes()[0].duplicate(true)
	h_absent["statuses"] = {}
	_check(not StitchedTurnStatusCues.tooltip(h_absent).contains("Regeneration:"),
		"AC2: hero with absent regen displays no Regeneration explanation")

	for inv_regen in ["2", 2.0, null, [], {}]:
		var h_inv_r: Dictionary = battle.get_heroes()[0].duplicate(true)
		h_inv_r["statuses"] = {"regen": inv_regen}
		var inv_tip := StitchedTurnStatusCues.tooltip(h_inv_r)
		_check(not inv_tip.contains("Regeneration:") and not inv_tip.contains("regen"),
			"AC2: invalid regen %s fails closed without explanation or counter" % str(inv_regen))

	# AC2: Unit with both regen and bleed proves wording mentions regen before bleed
	var dual_rb: Dictionary = battle.get_heroes()[0].duplicate(true)
	dual_rb["statuses"] = {"regen": 2, "bleed": 1}
	var dual_rb_tip := StitchedTurnStatusCues.tooltip(dual_rb)
	_check(StitchedTurnStatusCues.cue(dual_rb) == "BLD",
		"AC2: hero with regen and bleed yields BLD cue (bleed cue priority unchanged)")
	_check(dual_rb_tip.contains("Statuses: bleed 1, regen 2"),
		"AC2: sorted status overview lists bleed 1 before regen 2")
	_check(dual_rb_tip.contains(StitchedTurnStatusCues.REGEN_EXPLANATION),
		"AC2: coexisting regen and bleed displays Regeneration explanation")
	_check(dual_rb_tip.contains("before Bleed"),
		"AC2: Regeneration wording explicitly mentions healing occurs before Bleed ticks")

	# AC3: Overlapping Hanging, Stun, Torn, FRAY, Bleed and Regeneration
	var over_unit: Dictionary = battle.get_heroes()[0].duplicate(true)
	over_unit["statuses"] = {"regen": 2}

	# Hanging overrides regen -> SEAM
	over_unit["hp"] = 0
	over_unit["hanging"] = true
	_check(StitchedTurnStatusCues.cue(over_unit) == "SEAM", "AC3: SEAM overrides regen")
	var over_h_tip := StitchedTurnStatusCues.tooltip(over_unit)
	_check(over_h_tip.contains(StitchedTurnStatusCues.HANGING_EXPLANATION) and
		over_h_tip.contains(StitchedTurnStatusCues.REGEN_EXPLANATION) and
		over_h_tip.contains("Statuses: regen 2"),
		"AC3: hanging unit with regen displays both Hanging and Regen explanations in tooltip")

	# STUN overrides regen -> STUN
	over_unit["hanging"] = false
	over_unit["hp"] = 10
	over_unit["statuses"] = {"regen": 2, "stun": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "STUN", "AC3: STUN overrides regen")
	var over_s_tip := StitchedTurnStatusCues.tooltip(over_unit)
	_check(over_s_tip.contains(StitchedTurnStatusCues.STUN_EXPLANATION) and
		over_s_tip.contains(StitchedTurnStatusCues.REGEN_EXPLANATION) and
		over_s_tip.contains("Statuses: regen 2, stun 1"),
		"AC3: stun + regen displays sorted counters and both explanations")

	# TORN overrides regen -> TORN
	over_unit["statuses"] = {"regen": 2}
	over_unit["parts"]["head"]["torn"] = true
	_check(StitchedTurnStatusCues.cue(over_unit) == "TORN", "AC3: TORN overrides regen")
	over_unit["parts"]["head"]["torn"] = false

	# Resolve overrides regen -> STFD
	over_unit["resolve"] = "steadfast"
	_check(StitchedTurnStatusCues.cue(over_unit) == "STFD", "AC3: resolve overrides regen")
	over_unit["resolve"] = ""

	# FRAY >= 100 overrides regen -> FRAY
	over_unit["fray"] = 120
	_check(StitchedTurnStatusCues.cue(over_unit) == "FRAY", "AC3: FRAY >= 100 overrides regen")
	over_unit["fray"] = 20

	# Bleed overrides regen -> BLD
	over_unit["statuses"] = {"regen": 2, "bleed": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "BLD", "AC3: BLD overrides regen")

	# Regen overrides Guard -> REGN
	var ally_guardian_id: String = str(battle.get_heroes()[1]["id"])
	over_unit["statuses"] = {"regen": 2, "guard": 2}
	over_unit["guard_target"] = ally_guardian_id
	_check(StitchedTurnStatusCues.cue(over_unit) == "REGN", "AC3: REGN overrides GRD")

	# Regen overrides Riposte -> REGN
	over_unit["guard_target"] = ""
	over_unit["statuses"] = {"regen": 2, "riposte": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "REGN", "AC3: REGN overrides RIP")

	# Regen overrides Thorns -> REGN
	over_unit["statuses"] = {"regen": 2, "thorns": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "REGN", "AC3: REGN overrides THRN")

	# Regen overrides Blind -> REGN
	over_unit["statuses"] = {"regen": 2, "blind": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "REGN", "AC3: REGN overrides BLND")

	# Regen overrides Tangled -> REGN
	over_unit["statuses"] = {"regen": 2, "tangled": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "REGN", "AC3: REGN overrides TNGL")

	# Regen overrides Mark -> REGN
	over_unit["statuses"] = {"regen": 2, "mark": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "REGN", "AC3: REGN overrides MARK")

	# Regen overrides Weak -> REGN
	over_unit["statuses"] = {"regen": 2, "weak": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "REGN", "AC3: REGN overrides WEAK")

	# Regen overrides Exposed -> REGN
	over_unit["statuses"] = {"regen": 2, "exposed": 1}
	_check(StitchedTurnStatusCues.cue(over_unit) == "REGN", "AC3: REGN overrides EXPD")

	# S15 (lane4): Distinct Rot and Regeneration turn-order status cues (AC1, AC2, AC3, AC4)
	await _test_s15_rot_and_regen_cues(battle, ribbon)

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


func _test_s15_rot_and_regen_cues(battle: StitchedRules, ribbon: StitchedTurnOrderRibbon) -> void:
	# Public hero and foe unit snapshots
	var base_hero: Dictionary = battle.get_heroes()[0].duplicate(true)
	var base_foe: Dictionary = battle.get_foes()[0].duplicate(true)
	var neutral_hero: Dictionary = battle.get_heroes()[1].duplicate(true)
	neutral_hero["statuses"] = {}

	# AC1 & AC2: Direct deterministic unit-copy assertions
	# Test {"rot":1}, {"rot":2}, {"regen":1}, {"regen":3}, {"rot":2,"regen":2}, {"bleed":2,"regen":1}, {"bleed":2,"rot":1}
	var test_cases := [
		{"statuses": {"rot": 1}, "exp": "ROT", "desc": "rot 1"},
		{"statuses": {"rot": 2}, "exp": "ROT", "desc": "rot 2"},
		{"statuses": {"regen": 1}, "exp": "REGN", "desc": "regen 1"},
		{"statuses": {"regen": 3}, "exp": "REGN", "desc": "regen 3"},
		{"statuses": {"rot": 2, "regen": 2}, "exp": "ROT", "desc": "rot 2 with regen 2 (ROT wins)"},
		{"statuses": {"bleed": 2, "regen": 1}, "exp": "BLD", "desc": "bleed 2 with regen 1 (BLD wins over REGN)"},
		{"statuses": {"bleed": 2, "rot": 1}, "exp": "ROT", "desc": "bleed 2 with rot 1 (ROT wins over BLD)"},
		{"statuses": {"rot": 1, "bleed": 2, "regen": 2}, "exp": "ROT", "desc": "rot 1, bleed 2, regen 2 (ROT wins)"},
	]

	for tc: Dictionary in test_cases:
		var st: Dictionary = tc["statuses"]
		var exp_cue: String = str(tc["exp"])
		var desc: String = str(tc["desc"])

		var h := base_hero.duplicate(true)
		var f := base_foe.duplicate(true)
		h["statuses"] = st.duplicate(true)
		f["statuses"] = st.duplicate(true)

		var h_cue := StitchedTurnStatusCues.cue(h)
		var f_cue := StitchedTurnStatusCues.cue(f)
		_check(h_cue == exp_cue and h_cue.length() <= 4, "AC1/AC2: hero %s yields cue %s" % [desc, exp_cue])
		_check(f_cue == exp_cue and f_cue.length() <= 4, "AC1/AC2: foe %s yields cue %s" % [desc, exp_cue])

	# AC3: Priority order checks above ROT:
	# Hanging "SEAM" > Stun "STUN" > torn "TORN" > resolve > FRAY >= 100 > ROT > BLD > REGN
	for combo in [{"rot": 2}, {"regen": 2}, {"rot": 2, "regen": 2}]:
		var h_pri := base_hero.duplicate(true)
		var f_pri := base_foe.duplicate(true)
		h_pri["statuses"] = combo.duplicate(true)
		f_pri["statuses"] = combo.duplicate(true)

		# Hanging -> SEAM
		h_pri["hanging"] = true
		h_pri["hp"] = 0
		_check(StitchedTurnStatusCues.cue(h_pri) == "SEAM", "AC3: SEAM overrides %s" % str(combo))
		h_pri["hanging"] = false
		h_pri["hp"] = 10

		f_pri["hanging"] = true
		f_pri["hp"] = 0
		_check(StitchedTurnStatusCues.cue(f_pri) == "SEAM", "AC3: foe SEAM overrides %s" % str(combo))
		f_pri["hanging"] = false
		f_pri["hp"] = 10

		# Stun -> STUN
		h_pri["statuses"]["stun"] = 1
		_check(StitchedTurnStatusCues.cue(h_pri) == "STUN", "AC3: STUN overrides %s" % str(combo))
		h_pri["statuses"].erase("stun")

		f_pri["statuses"]["stun"] = 1
		_check(StitchedTurnStatusCues.cue(f_pri) == "STUN", "AC3: foe STUN overrides %s" % str(combo))
		f_pri["statuses"].erase("stun")

		# Torn -> TORN
		h_pri["parts"]["head"]["torn"] = true
		_check(StitchedTurnStatusCues.cue(h_pri) == "TORN", "AC3: TORN overrides %s" % str(combo))
		h_pri["parts"]["head"]["torn"] = false

		f_pri["parts"] = {"head": {"torn": true}}
		_check(StitchedTurnStatusCues.cue(f_pri) == "TORN", "AC3: foe TORN overrides %s" % str(combo))
		f_pri["parts"] = {}

		# Hero Resolve -> resolve cue
		h_pri["resolve"] = "steadfast"
		_check(StitchedTurnStatusCues.cue(h_pri) == "STFD", "AC3: resolve overrides %s" % str(combo))
		h_pri["resolve"] = ""

		# Hero FRAY >= 100 -> FRAY
		h_pri["fray"] = 100
		_check(StitchedTurnStatusCues.cue(h_pri) == "FRAY", "AC3: hero FRAY 100 overrides %s" % str(combo))
		h_pri["fray"] = 99
		var expected_under_fray := "ROT" if combo.has("rot") else "REGN"
		_check(StitchedTurnStatusCues.cue(h_pri) == expected_under_fray, "AC3: hero fray 99 reveals %s" % expected_under_fray)
		h_pri["fray"] = 20

	# Foe spoofing resolve or fray: returns ROT or REGN, never hero cues
	var f_spoof_rot := base_foe.duplicate(true)
	f_spoof_rot["statuses"] = {"rot": 2}
	f_spoof_rot["resolve"] = "bitter"
	f_spoof_rot["fray"] = 150
	_check(StitchedTurnStatusCues.cue(f_spoof_rot) == "ROT", "AC3: foe spoofing resolve/fray gets ROT")
	_check(not StitchedTurnStatusCues.tooltip(f_spoof_rot).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(f_spoof_rot).contains("FRAY:"),
		"AC3: foe with rot does not disclose spoofed resolve or fray")

	var f_spoof_reg := base_foe.duplicate(true)
	f_spoof_reg["statuses"] = {"regen": 2}
	f_spoof_reg["resolve"] = "bitter"
	f_spoof_reg["fray"] = 150
	_check(StitchedTurnStatusCues.cue(f_spoof_reg) == "REGN", "AC3: foe spoofing resolve/fray gets REGN")
	_check(not StitchedTurnStatusCues.tooltip(f_spoof_reg).contains("Resolve:") and
		not StitchedTurnStatusCues.tooltip(f_spoof_reg).contains("FRAY:"),
		"AC3: foe with regen does not disclose spoofed resolve or fray")

	# AC3: Rot overrides ordinary status cues: guard, riposte, thorns, blind, tangled, mark, weak, exposed
	var rot_all := base_hero.duplicate(true)
	rot_all["statuses"] = {
		"rot": 1,
		"guard": 2,
		"riposte": 1,
		"thorns": 1,
		"blind": 1,
		"tangled": 1,
		"mark": 1,
		"weak": 1,
		"exposed": 1,
		"regen": 1,
	}
	rot_all["guard_target"] = str(neutral_hero["id"])
	_check(StitchedTurnStatusCues.cue(rot_all) == "ROT", "AC3: ROT overrides guard, riposte, thorns, blind, tangled, mark, weak, exposed")

	# AC3: Non-positive and malformed values fail closed
	for st_key in ["rot", "regen"]:
		for non_pos in [0, -1, -3, 1.5, 2.0, "2", st_key, null, [], {}]:
			var h_np := base_hero.duplicate(true)
			var f_np := base_foe.duplicate(true)
			h_np["statuses"] = {st_key: non_pos}
			f_np["statuses"] = {st_key: non_pos}
			_check(StitchedTurnStatusCues.cue(h_np) == "HERO", "AC3: hero %s=%s yields HERO" % [st_key, str(non_pos)])
			_check(StitchedTurnStatusCues.cue(f_np) == "FOE", "AC3: foe %s=%s yields FOE" % [st_key, str(non_pos)])
			var h_tip := StitchedTurnStatusCues.tooltip(h_np)
			var f_tip := StitchedTurnStatusCues.tooltip(f_np)
			_check(not h_tip.contains(st_key) and not f_tip.contains(st_key),
				"AC3: invalid %s=%s produces no tooltip counter or explanation" % [st_key, str(non_pos)])

		# Non-Dictionary statuses fail closed
		for bad_statuses in [null, "%s 2" % st_key, 2, [2]]:
			var h_bad := base_hero.duplicate(true)
			var f_bad := base_foe.duplicate(true)
			h_bad["statuses"] = bad_statuses
			f_bad["statuses"] = bad_statuses
			_check(StitchedTurnStatusCues.cue(h_bad) == "HERO", "AC3: hero non-Dictionary statuses %s yields HERO" % str(bad_statuses))
			_check(StitchedTurnStatusCues.cue(f_bad) == "FOE", "AC3: foe non-Dictionary statuses %s yields FOE" % str(bad_statuses))

	# AC3: Preservation of ROT_EXPLANATION, REGEN_EXPLANATION, and tooltip content
	_check(StitchedTurnStatusCues.ROT_EXPLANATION == "Rot (mildew): loses 2 HP at each of its turn starts, ignoring PROT; heals on it mend half.",
		"AC3: ROT_EXPLANATION constant preserved exactly")
	_check(StitchedTurnStatusCues.REGEN_EXPLANATION == "Regeneration: restores exactly 2 HP at the affected unit's turn start, capped at max HP, before Bleed, consumes one turn, and can bring a Hanging doll above 0.",
		"AC3: REGEN_EXPLANATION constant preserved exactly")

	var rot_hero := base_hero.duplicate(true)
	rot_hero["statuses"] = {"rot": 2}
	var rot_tip := StitchedTurnStatusCues.tooltip(rot_hero)
	_check(rot_tip.contains("Statuses: rot 2") and rot_tip.contains(StitchedTurnStatusCues.ROT_EXPLANATION) and
		not rot_tip.contains("Regeneration:"),
		"AC3: rot hero tooltip discloses sorted rot 2 counter and ROT_EXPLANATION without Regeneration")

	var regen_hero := base_hero.duplicate(true)
	regen_hero["statuses"] = {"regen": 2}
	var regen_tip := StitchedTurnStatusCues.tooltip(regen_hero)
	_check(regen_tip.contains("Statuses: regen 2") and regen_tip.contains(StitchedTurnStatusCues.REGEN_EXPLANATION) and
		not regen_tip.contains("Rot (mildew):"),
		"AC3: regen hero tooltip discloses sorted regen 2 counter and REGEN_EXPLANATION without Rot")

	var combo_hero := base_hero.duplicate(true)
	combo_hero["statuses"] = {"rot": 1, "regen": 2}
	var combo_tip := StitchedTurnStatusCues.tooltip(combo_hero)
	var combo_lines := StitchedTurnStatusCues.tooltip_lines(combo_hero)
	var status_line_idx := combo_lines.find("Statuses: regen 2, rot 1")
	var regen_idx := combo_lines.find(StitchedTurnStatusCues.REGEN_EXPLANATION)
	var rot_idx := combo_lines.find(StitchedTurnStatusCues.ROT_EXPLANATION)
	_check(status_line_idx >= 0 and regen_idx > status_line_idx and rot_idx > regen_idx,
		"AC3: combined rot and regen discloses alphabetical status list and both explanations")

	# AC4: Mounted ribbon exercise
	var rot_unit := base_hero.duplicate(true)
	rot_unit["statuses"] = {"rot": 2}
	var reg_unit := base_foe.duplicate(true)
	reg_unit["statuses"] = {"regen": 3}
	var combo_unit := base_hero.duplicate(true)
	combo_unit["id"] = "combo_unit_test"
	combo_unit["name"] = "Combo Hero"
	combo_unit["statuses"] = {"rot": 1, "regen": 2}
	var neutral_unit := base_foe.duplicate(true)
	neutral_unit["id"] = "neutral_foe_test"
	neutral_unit["name"] = "Neutral Foe"
	neutral_unit["statuses"] = {}

	var rot_id := str(rot_unit["id"])
	var reg_id := str(reg_unit["id"])
	var combo_id := str(combo_unit["id"])
	var neutral_id := str(neutral_unit["id"])

	var entries := [rot_unit, reg_unit, combo_unit, neutral_unit]

	# Inactive show_order: inactive slots show ROT, REGN, ROT, FOE
	ribbon.show_order(entries, "", false)
	_check(ribbon.displayed_entries.size() == 4, "AC4: ribbon displays 4 entries")
	_check(ribbon.marker_at(0).text == "ROT" and ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC4: slot 0 marker is muted ROT")
	_check(ribbon.marker_at(1).text == "REGN" and ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC4: slot 1 marker is muted REGN")
	_check(ribbon.marker_at(2).text == "ROT" and ribbon.marker_at(2).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC4: slot 2 marker is muted ROT for combo rot+regen")
	_check(ribbon.marker_at(3).text == "FOE" and ribbon.marker_at(3).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC4: slot 3 marker is muted FOE")

	# Parity of tooltip under hover and keyboard focus
	for i in range(3):
		var tag := ribbon.tag_at(i)
		var exp_tooltip := StitchedTurnStatusCues.tooltip(entries[i])
		_check(tag.tooltip_text == exp_tooltip, "AC4: slot %d tag tooltip_text matches pure tooltip" % i)

		tag.grab_focus()
		await process_frame
		_check(tag.has_focus() and tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == exp_tooltip,
			"AC4: slot %d keyboard focus exposes exact tooltip" % i)
		tag.release_focus()
		_check(not tag.get_node("FocusTooltip").visible, "AC4: slot %d blur hides tooltip" % i)

		tag.mouse_entered.emit()
		_check(tag.get_node("FocusTooltip").visible and
			tag.get_node("FocusTooltip/TooltipText").text == exp_tooltip,
			"AC4: slot %d mouse hover exposes identical tooltip" % i)
		tag.mouse_exited.emit()
		_check(not tag.get_node("FocusTooltip").visible, "AC4: slot %d hover exit hides tooltip" % i)

	# Active actor: rot_unit acts -> NOW
	ribbon.show_order(entries, rot_id, false)
	_check(ribbon.marker_at(0).text == "NOW" and ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC4: acting rot unit marker displays amber NOW")
	_check(ribbon.marker_at(1).text == "REGN" and ribbon.marker_at(2).text == "ROT",
		"AC4: inactive markers remain REGN and ROT when rot unit acts")

	# Active actor: reg_unit acts -> rot returns to ROT, reg is NOW
	ribbon.show_order(entries, reg_id, false)
	_check(ribbon.marker_at(0).text == "ROT" and ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC4: rot unit returns to muted ROT when turn passes")
	_check(ribbon.marker_at(1).text == "NOW" and ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC4: acting regen unit displays amber NOW")

	# Active actor: neutral_unit acts -> both show their status cues
	ribbon.show_order(entries, neutral_id, false)
	_check(ribbon.marker_at(0).text == "ROT" and ribbon.marker_at(1).text == "REGN" and ribbon.marker_at(2).text == "ROT",
		"AC4: rot and regen markers displayed while neutral acts")
	_check(ribbon.marker_at(3).text == "NOW", "AC4: acting neutral unit shows NOW")

	# is_over = true: clears NOW and shows accurate markers
	ribbon.show_order(entries, reg_id, true)
	_check(ribbon.marker_at(0).text == "ROT" and ribbon.marker_at(1).text == "REGN" and
		ribbon.marker_at(2).text == "ROT" and ribbon.marker_at(3).text == "FOE",
		"AC4: is_over=true clears NOW and returns truthful ROT, REGN, FOE markers")

	# Clearing statuses returns generic HERO/FOE
	var cleared_rot := rot_unit.duplicate(true)
	var cleared_reg := reg_unit.duplicate(true)
	cleared_rot["statuses"] = {}
	cleared_reg["statuses"] = {}
	ribbon.show_order([cleared_rot, cleared_reg], "", false)
	_check(ribbon.marker_at(0).text == "HERO" and ribbon.marker_at(1).text == "FOE",
		"AC4: cleared units return to generic HERO and FOE cues")
	_check(not ribbon.tag_at(0).tooltip_text.contains("rot") and not ribbon.tag_at(0).tooltip_text.contains("Rot"),
		"AC4: cleared rot unit tag tooltip has no stale rot text")
	_check(not ribbon.tag_at(1).tooltip_text.contains("regen") and not ribbon.tag_at(1).tooltip_text.contains("Regeneration"),
		"AC4: cleared regen unit tag tooltip has no stale regen text")
