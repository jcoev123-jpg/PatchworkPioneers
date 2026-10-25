extends SceneTree
## Scene-backed contract: both readouts come from the same genuine enemy record,
## while previews, intent labels, combat state and RNG remain unchanged.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _frames() -> void:
	for index in range(6):
		await process_frame


func _state(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(true),
		app.deck.draw_pile.duplicate(true), app.deck.discard_pile.duplicate(true),
		app.deck.energy, app.deck.turn_active, app.run_rng.state,
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index,
		app.enemy_attacks.duplicate(true), app.battle_result.get_outcome(),
		app.run_map.get_current_node_id() if app.run_map != null else "",
		app.get("run_wallet").get_state() if app.get("run_wallet") != null and app.get("run_wallet").has_method("get_state") else null]


func _chip_pool(meter: CombatActorMeter) -> Array:
	var flow := meter.get_node_or_null("Padding/Content/StatusButtons") as HFlowContainer
	return flow.get_children() if flow != null else []


func _visible_chips(meter: CombatActorMeter) -> Array[String]:
	var texts: Array[String] = []
	for chip in _chip_pool(meter):
		if chip.visible:
			texts.append(chip.text)
	return texts


func _tag(roster, slot: int) -> PanelContainer:
	if roster._thorns_tags.size() < slot:
		return null
	return roster._thorns_tags[slot - 1]


func _assert_warning(app, roster, meters, amount: int, visible: bool) -> void:
	var tag := _tag(roster, 1)
	var meter := meters.row.get_child(3) as CombatActorMeter
	_check(tag != null and meter != null and _chip_pool(meter).size() == 4,
		"real mounted enemy puppet and exact four reusable status controls")
	if tag == null or meter == null:
		return
	var name := tag.get_node_or_null("Caption") as Button
	var actual := "Thorns %d" % amount if visible else ""
	var texts := _visible_chips(meter)
	var thorn_chips := 0
	for chip in _chip_pool(meter):
		if chip.visible and chip.text.begins_with("Thorns"):
			thorn_chips += 1
			_check(chip.text == actual
				and chip.tooltip_text == ("Thorns %d: Each confirmed positive-damage hit on this enemy deals %d damage back to its attacking hero, even if enemy Block absorbs that hit. Hero Block absorbs the retaliation before HP. Misses, failed plays, zero-damage attacks and previews do not retaliate." % [amount, amount]),
				"exact source N and rule qualifications, including absorbed enemy and hero Block")
	_check(tag.visible == visible and name != null and name.text == actual
		and thorn_chips == (1 if visible else 0),
		"same authoritative enemy amount controls both the stage and ribbon text")
	_check(not texts.has("Thorns %d" % amount) if not visible else texts.has(actual),
		"hazard chip absent/present with exact current amount")
	_check(tag.mouse_filter == Control.MOUSE_FILTER_IGNORE and tag.focus_mode == Control.FOCUS_NONE
		and (name == null or name.mouse_filter == Control.MOUSE_FILTER_IGNORE),
		"passive stage label cannot consume target or keyboard actions")
	_check(not (_visible_chips(meters.row.get_child(0) as CombatActorMeter)).has(actual)
		and roster._puppets[0].get_node_or_null("EnemyThorns1") == null,
		"hero can never acquire an invented Thorns warning")
	if visible:
		var puppet = roster._puppets[3]
		var rect := Rect2(tag.position, tag.size)
		_check(tag.get_parent() == puppet and tag.is_visible_in_tree()
			and rect.has_area() and puppet.art_band().encloses(rect)
			and not rect.intersects(puppet.tag_band()),
			"stitched warning stays in its own puppet art band, clear of pinned name and HP")
		var intent: Control = roster._badges[0]
		_check(not intent.is_visible_in_tree() or not tag.get_global_rect().intersects(
			intent.get_global_rect()), "passive patch never covers the separate announced intent")
		_check(name.get_theme_font_size("font_size") >= 12
			and tag.size.x >= name.get_minimum_size().x
			and not tag.clip_contents,
			"thorns patch retains readable complete label")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene can be loaded")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await _frames()
	var roster = app.get_node_or_null("LiveEnemyRoster")
	var meters = app.get_node_or_null("LiveCombatMeters")
	_check(roster != null and meters != null and is_instance_valid(app.start_button),
		"genuine stage presenters and Start Run are mounted")
	if roster == null or meters == null:
		app.free()
		_finish()
		return
	_check(app._start_battle(), "real standalone battle admitted")
	await _frames()
	_check(app.party != null and app.enemies != null and app.deck != null
		and app.run_rng != null and roster.enemies == app.enemies
		and meters._enemies == app.enemies and meters.row.get_child_count() == 5
		and roster._labels.size() == 2 and roster._badges.size() == 2
		and roster._thorns_tags.size() == 2,
		"both genuine mounted views are bound to the exact active combat authorities")
	if app.enemies == null or roster._thorns_tags.size() != 2:
		app.free()
		_finish()
		return
	var intents: Array = app.enemy_intents.get_intents()
	var intent_texts: Array[String] = []
	for badge in roster._badges:
		intent_texts.append(badge.get_node("Caption").text if badge.has_node("Caption") else badge.tooltip_text)
	# A legitimate top-level Thorns fixture lives on an existing, real authority
	# record; the renderer never fabricates a new enemy or runs combat rules.
	app.enemies._enemies[0]["thorns"] = 2
	_check(app.enemies.get_enemy(1).get("thorns") == 2
		and app.enemies.get_enemy(2).get("thorns", 0) == 0,
		"the real enemy ledger, not a fake UI snapshot, owns Thorns 2")
	_check(app.enemies.apply_statuses({1: {"bleed": 2, "weak": 1, "exposed": 2}}),
		"real status API accepts the exact three-status stack")
	var seed_rng: int = app.run_rng.state
	var before := _state(app)
	seed(481516)
	var expected_global := randi()
	seed(481516)
	await _frames()
	_assert_warning(app, roster, meters, 2, true)
	var enemy_meter := meters.row.get_child(3) as CombatActorMeter
	_check(_visible_chips(enemy_meter) == ["Bleed 2", "Weak 1", "Exposed 2", "Thorns 2"],
		"four distinct status/hazard chips stay ordered after the ordinary timed statuses")
	var ordinary_tooltip := "Statuses: Bleed 2 · Weak 1 · Exposed 2\nWeak: -25% attack damage\nExposed: +50% attack damage taken"
	var chips := _chip_pool(enemy_meter)
	for index in range(3):
		_check(chips[index].tooltip_text.begins_with(ordinary_tooltip)
			and not chips[index].tooltip_text.contains("Each confirmed positive-damage hit"),
			"ordinary status hover retains its own unchanged full text")
	var ids: Array[int] = []
	for chip in chips:
		ids.append(chip.get_instance_id())
	var tag_id := _tag(roster, 1).get_instance_id()
	var intent_ids: Array[int] = []
	for badge in roster._badges:
		intent_ids.append(badge.get_instance_id())
	for repeat in range(5):
		roster._refresh()
		meters._sync_battle()
		await process_frame
		_check(_visible_chips(enemy_meter) == ["Bleed 2", "Weak 1", "Exposed 2", "Thorns 2"]
			and _tag(roster, 1).get_instance_id() == tag_id
			and _chip_pool(enemy_meter).map(func(c): return c.get_instance_id()) == ids,
			"refresh uses one stable patch and four identical chip controls")
	_check(_state(app) == before and app.run_rng.state == seed_rng and randi() == expected_global,
		"every UI-only refresh leaves HP, Block, statuses, wallet, route, deck, intents, seeded/global RNG unchanged")
	_check(app.enemy_intents.get_intents() == intents
		and roster._badges.map(func(b): return b.get_instance_id()) == intent_ids,
		"Thorns is not a scheduled intent; live original intent controls persist")
	_check(_tag(roster, 2).get_node("Caption").text.is_empty()
		and not _tag(roster, 2).visible,
		"unaffected enemy has no invented contact hazard")
	# Zero, absent and invalid values all clear the same reusable tag and chip.
	for value in [0, -1, "2", true, 1.5]:
		app.enemies._enemies[0]["thorns"] = value
		await _frames()
		_assert_warning(app, roster, meters, 2, false)
	app.enemies._enemies[0].erase("thorns")
	await _frames()
	_assert_warning(app, roster, meters, 2, false)
	app.enemies._enemies[0]["thorns"] = 2
	await _frames()
	_assert_warning(app, roster, meters, 2, true)
	_check(app.enemies.apply_damage(1, app.enemies.get_enemy(1)["hp"]),
		"authoritative enemy is genuinely slain")
	await _frames()
	_assert_warning(app, roster, meters, 2, false)
	_check(_visible_chips(enemy_meter).has("SLAIN")
		and not _visible_chips(enemy_meter).has("Thorns 2"),
		"slain enemy retains fallen warning but has no active Thorns")
	var old_tag_id := _tag(roster, 1).get_instance_id()
	# Real return and fresh standalone admission: old stage and ribbon controls
	# are disposed, so neither a stale tag nor a borrowed old Thorns is visible.
	app.return_button.pressed.emit()
	await _frames()
	_check(roster._thorns_tags.is_empty() and meters.row == null
		and not is_instance_id_valid(old_tag_id),
		"return tears down the entire old hazard presentation")
	_check(app._start_battle(), "second genuine battle is admitted")
	await _frames()
	_check(roster.enemies == app.enemies and app.enemies.get_enemy(1).get("thorns", 0) == 0
		and roster._thorns_tags.size() == app.enemies.get_enemies().size()
		and not is_instance_id_valid(old_tag_id),
		"fresh battle rebinds cleanly without retaining prior enemy passive")
	_assert_warning(app, roster, meters, 2, false)
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_v3_enemy_thorns_stage_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
