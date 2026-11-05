extends SceneTree
## Independent deterministic SceneTree test of Mark status cues on the mounted turn-order ribbon.
## Does not import or construct StitchedRules.

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
	print("stitched_s5_mark_cue_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _mount() -> Dictionary:
	var host := Control.new()
	host.name = "GothicMarkHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var ribbon := StitchedTurnOrderRibbon.new()
	ribbon.position = Vector2(120, 22)
	host.add_child(ribbon)
	return {"host": host, "ribbon": ribbon}


func _sample_hero() -> Dictionary:
	return {
		"id": "warden",
		"name": "Warden",
		"side": "hero",
		"rank": 1,
		"hp": 24,
		"max_hp": 24,
		"speed": 3,
		"dodge": 10,
		"prot": 15,
		"fray": 20,
		"resolve": "",
		"hanging": false,
		"dead": false,
		"lost": false,
		"parts": {
			"head": {"torn": false},
			"arms": {"torn": false},
			"torso": {"torn": false},
			"legs": {"torn": false},
		},
		"statuses": {},
	}


func _sample_foe() -> Dictionary:
	return {
		"id": "unknown_scuttler_id_no_art",
		"name": "Lantern Scuttler",
		"side": "foe",
		"rank": 2,
		"hp": 14,
		"max_hp": 14,
		"speed": 5,
		"dodge": 5,
		"prot": 0,
		"dead": false,
		"lost": false,
		"statuses": {},
	}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var mounted := _mount()
	var host: Control = mounted["host"]
	var ribbon: StitchedTurnOrderRibbon = mounted["ribbon"]
	await process_frame

	_check(host.theme != null and ribbon.get_child_count() == 9,
		"precondition: mounted ribbon has nine reusable tags and Gothic theme")

	var hero := _sample_hero()
	var foe := _sample_foe()

	# --- AC1: Positive native-int mark yields MARK and truthful tooltip ---
	hero["statuses"] = {"mark": 2}
	foe["statuses"] = {"mark": 1}

	_check(StitchedTurnStatusCues.cue(hero) == "MARK", "AC1: hero with native positive mark 2 yields MARK cue")
	_check(StitchedTurnStatusCues.cue(foe) == "MARK", "AC1: foe with native positive mark 1 yields MARK cue")

	var hero_tip := StitchedTurnStatusCues.tooltip(hero)
	var foe_tip := StitchedTurnStatusCues.tooltip(foe)
	_check(hero_tip.contains("Warden") and hero_tip.contains("Hero rank 1") and
		hero_tip.contains("HP: 24 / 24") and hero_tip.contains("SPEED: 3") and
		hero_tip.contains("Statuses: mark 2") and
		hero_tip.contains("Marked: mark-hunting abilities gain their authored bonus damage."),
		"AC1: hero tooltip retains name, rank, HP, stats, sorted status counter and mark-hunting explanation")
	_check(foe_tip.contains("Lantern Scuttler") and foe_tip.contains("Foe rank 2") and
		foe_tip.contains("HP: 14 / 14") and
		foe_tip.contains("Statuses: mark 1") and
		foe_tip.contains("Marked: mark-hunting abilities gain their authored bonus damage."),
		"AC1: foe tooltip retains name, rank, HP, sorted status counter and mark-hunting explanation")

	ribbon.show_order([hero, foe], "", false)
	_check(ribbon.displayed_entries.size() == 2, "AC1: ribbon displays two entries")
	_check(ribbon.marker_at(0).text == "MARK" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC1: mounted hero tag 0 displays MARK marker in muted parchment")
	_check(ribbon.marker_at(1).text == "MARK" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC1: mounted foe tag 1 displays MARK marker in muted parchment")
	_check(ribbon.portrait_at(1).texture == null and
		ribbon.tag_at(1).get_node("NameFallback").visible and
		ribbon.tag_at(1).get_node("NameFallback").text.begins_with("Lant"),
		"AC1: unmapped foe ID exercises name fallback without borrowing art")

	# Hover and keyboard focus disclosure assertions
	var tag_hero := ribbon.tag_at(0)
	var tag_foe := ribbon.tag_at(1)
	_check(tag_hero.tooltip_text == hero_tip and tag_foe.tooltip_text == foe_tip,
		"AC1: mounted controls receive pure cue tooltip text")

	tag_hero.mouse_entered.emit()
	_check(tag_hero.get_node("FocusTooltip").visible and
		tag_hero.get_node("FocusTooltip/TooltipText").text == hero_tip,
		"AC1: hero mouse hover displays complete tooltip with mark explanation")
	tag_hero.mouse_exited.emit()
	_check(not tag_hero.get_node("FocusTooltip").visible, "AC1: mouse exit hides hero tooltip")

	tag_foe.grab_focus()
	await process_frame
	_check(tag_foe.has_focus() and tag_foe.get_node("FocusTooltip").visible and
		tag_foe.get_node("FocusTooltip/TooltipText").text == foe_tip,
		"AC1: foe keyboard focus displays complete tooltip with mark explanation")
	tag_foe.release_focus()
	_check(not tag_foe.get_node("FocusTooltip").visible, "AC1: keyboard blur hides foe tooltip")

	# --- AC2: NOW precedence, turn progression, is_over clearing, no stale text or extra nodes ---
	# Hero becomes current actor
	ribbon.show_order([hero, foe], str(hero["id"]), false)
	_check(ribbon.marker_at(0).text == "NOW" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC2: acting marked hero marker is amber NOW")
	_check(ribbon.marker_at(1).text == "MARK", "AC2: nonacting marked foe remains MARK")

	# Foe becomes current actor
	ribbon.show_order([hero, foe], str(foe["id"]), false)
	_check(ribbon.marker_at(0).text == "MARK" and
		ribbon.marker_at(0).get_theme_color("font_color") == StitchedTurnOrderRibbon.MUTED,
		"AC2: previous actor returns to MARK when turn advances")
	_check(ribbon.marker_at(1).text == "NOW" and
		ribbon.marker_at(1).get_theme_color("font_color") == StitchedTurnOrderRibbon.AMBER,
		"AC2: active foe displays amber NOW")

	# is_over = true clears NOW and returns to MARK
	ribbon.show_order([hero, foe], str(foe["id"]), true)
	_check(ribbon.marker_at(0).text == "MARK" and ribbon.marker_at(1).text == "MARK",
		"AC2: is_over=true clears NOW for all actors, returning MARK")
	_check(ribbon.get_child_count() == 9, "AC2: no additional nodes created across updates")

	# --- AC3: Non-positive/malformed mark fails closed; precedence over lower fallback; higher cues win ---
	# Non-positive or wrong-type mark values
	for invalid_mark in [0, -1, -5, "2", 2.0, 1.5, "mark", null, []]:
		var h_neg := _sample_hero()
		var f_neg := _sample_foe()
		h_neg["statuses"] = {"mark": invalid_mark}
		f_neg["statuses"] = {"mark": invalid_mark}
		_check(StitchedTurnStatusCues.cue(h_neg) == "HERO",
			"AC3: invalid mark %s yields HERO fallback" % str(invalid_mark))
		_check(StitchedTurnStatusCues.cue(f_neg) == "FOE",
			"AC3: invalid mark %s yields FOE fallback" % str(invalid_mark))
		_check(not StitchedTurnStatusCues.tooltip(h_neg).contains("Marked:"),
			"AC3: invalid mark %s does not add mark explanation to hero tooltip" % str(invalid_mark))
		_check(not StitchedTurnStatusCues.tooltip(f_neg).contains("Marked:"),
			"AC3: invalid mark %s does not add mark explanation to foe tooltip" % str(invalid_mark))

	# Missing mark
	var h_empty := _sample_hero()
	h_empty["statuses"] = {}
	_check(StitchedTurnStatusCues.cue(h_empty) == "HERO", "AC3: missing mark yields HERO")
	_check(not StitchedTurnStatusCues.tooltip(h_empty).contains("Marked:"), "AC3: missing mark has no mark line")

	# Precedence with higher priority cues (Mark is positive 2 in all of these)
	# 1. Hanging wins over MARK
	var h_hang := _sample_hero()
	h_hang["statuses"] = {"mark": 2}
	h_hang["hanging"] = true
	_check(StitchedTurnStatusCues.cue(h_hang) == "SEAM", "AC3: hanging overrides mark -> SEAM")
	var hang_tip := StitchedTurnStatusCues.tooltip(h_hang)
	_check(hang_tip.contains("Statuses: mark 2") and hang_tip.contains("Marked:") and
		hang_tip.contains("Hanging by a Thread"), "AC3: hanging tooltip keeps mark status and explanation")

	# 2. Positive stun wins over MARK
	var h_stun := _sample_hero()
	h_stun["statuses"] = {"mark": 2, "stun": 1}
	_check(StitchedTurnStatusCues.cue(h_stun) == "STUN", "AC3: stun overrides mark -> STUN")
	_check(StitchedTurnStatusCues.tooltip(h_stun).contains("Statuses: mark 2, stun 1") and
		StitchedTurnStatusCues.tooltip(h_stun).contains("Marked:"),
		"AC3: stun tooltip discloses both mark and stun")

	# 3. Torn parts win over MARK
	var h_torn := _sample_hero()
	h_torn["statuses"] = {"mark": 2}
	h_torn["parts"]["head"]["torn"] = true
	_check(StitchedTurnStatusCues.cue(h_torn) == "TORN", "AC3: torn parts override mark -> TORN")
	_check(StitchedTurnStatusCues.tooltip(h_torn).contains("Torn parts: Head") and
		StitchedTurnStatusCues.tooltip(h_torn).contains("Statuses: mark 2"),
		"AC3: torn tooltip discloses torn parts and mark")

	# 4. Resolve wins over MARK
	var h_resolve := _sample_hero()
	h_resolve["statuses"] = {"mark": 2}
	h_resolve["resolve"] = "steadfast"
	_check(StitchedTurnStatusCues.cue(h_resolve) == "STFD", "AC3: steadfast resolve overrides mark -> STFD")
	_check(StitchedTurnStatusCues.tooltip(h_resolve).contains("Resolve: steadfast") and
		StitchedTurnStatusCues.tooltip(h_resolve).contains("Statuses: mark 2"),
		"AC3: resolve tooltip discloses resolve and mark")

	# 5. Fray >= 100 wins over MARK for hero
	var h_fray := _sample_hero()
	h_fray["statuses"] = {"mark": 2}
	h_fray["fray"] = 100
	_check(StitchedTurnStatusCues.cue(h_fray) == "FRAY", "AC3: hero fray >= 100 overrides mark -> FRAY")
	_check(StitchedTurnStatusCues.tooltip(h_fray).contains("FRAY: 100 / 200") and
		StitchedTurnStatusCues.tooltip(h_fray).contains("Statuses: mark 2"),
		"AC3: fray tooltip discloses fray and mark")

	# Foe spoofing hero fray or resolve still gets MARK if marked, never FRAY or resolve cue
	var f_spoof := _sample_foe()
	f_spoof["statuses"] = {"mark": 2}
	f_spoof["fray"] = 150
	f_spoof["resolve"] = "bitter"
	_check(StitchedTurnStatusCues.cue(f_spoof) == "MARK", "AC3: foe spoofing fray/resolve gets MARK cue")
	_check(not StitchedTurnStatusCues.tooltip(f_spoof).contains("FRAY:") and
		not StitchedTurnStatusCues.tooltip(f_spoof).contains("Resolve:"),
		"AC3: foe tooltip does not disclose spoofed fray or resolve")

	# 6. Positive Bleed wins over MARK
	var h_bld_mark := _sample_hero()
	h_bld_mark["statuses"] = {"mark": 2, "bleed": 3}
	var f_bld_mark := _sample_foe()
	f_bld_mark["statuses"] = {"mark": 1, "bleed": 2}
	_check(StitchedTurnStatusCues.cue(h_bld_mark) == "BLD", "AC3: hero positive bleed overrides mark -> BLD")
	_check(StitchedTurnStatusCues.cue(f_bld_mark) == "BLD", "AC3: foe positive bleed overrides mark -> BLD")
	var h_bld_tip := StitchedTurnStatusCues.tooltip(h_bld_mark)
	_check(h_bld_tip.contains("Statuses: bleed 3, mark 2") and
		h_bld_tip.contains("Marked: mark-hunting abilities gain their authored bonus damage."),
		"AC3: bleed+mark tooltip retains both counters and the mark explanation")

	# 7. Absent and LOST entries do not leave stale displayed tags
	var dead_hero := _sample_hero()
	dead_hero["dead"] = true
	dead_hero["statuses"] = {"mark": 2}
	var lost_foe := _sample_foe()
	lost_foe["lost"] = true
	lost_foe["statuses"] = {"mark": 2}
	var marked_survivor := _sample_foe()
	marked_survivor["statuses"] = {"mark": 1}
	ribbon.show_order([dead_hero, marked_survivor, lost_foe], "", false)
	_check(ribbon.displayed_entries.size() == 1, "AC3: dead and lost entries are filtered out")
	_check(ribbon.marker_at(0).text == "MARK", "AC3: marked survivor displays MARK")
	_check(not ribbon.tag_at(1).visible and ribbon.tag_at(1).tooltip_text.is_empty() and
		ribbon.marker_at(1).text.is_empty(),
		"AC3: hidden tag 1 has no stale actor, tooltip or marker text")

	# --- AC4: No mutations, no RNG consumption, pure projection ---
	var original_hero := _sample_hero()
	original_hero["statuses"] = {"mark": 2}
	var original_foe := _sample_foe()
	original_foe["statuses"] = {"mark": 1}

	var hero_copy := original_hero.duplicate(true)
	var foe_copy := original_foe.duplicate(true)

	seed(639201)
	var expected_rng := randi()
	seed(639201)

	for _i in range(5):
		ribbon.show_order([hero_copy, foe_copy], str(hero_copy["id"]), false)
		tag_hero.mouse_entered.emit()
		tag_hero.mouse_exited.emit()
		tag_hero.grab_focus()
		tag_hero.release_focus()
		ribbon.show_order([hero_copy, foe_copy], "", false)
		tag_foe.mouse_entered.emit()
		tag_foe.mouse_exited.emit()

	_check(randi() == expected_rng, "AC4: projection, hover and focus consume zero global RNG")
	_check(hero_copy == original_hero and foe_copy == original_foe,
		"AC4: caller dictionaries are completely untouched after repeated updates")
	_check(ribbon.get_child_count() == 9, "AC4: tag count remains exactly nine with zero added nodes")

	host.free()
	_finish()
