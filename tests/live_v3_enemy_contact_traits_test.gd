extends SceneTree
## Shipped catalog flags, real scene/round-flow admission, and read-only sewn cues.
## No test-only enemy IDs, UI stand-ins or replacement gameplay implementation.

const ORACLE := preload("res://tests/floor_band_oracle.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _snapshot(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.draw_pile.duplicate(true),
		app.deck.hand.duplicate(true), app.deck.discard_pile.duplicate(true),
		app.deck.energy, app.deck.turn_active, app.run_rng.seed, app.run_rng.state,
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index,
		app.enemy_attacks.duplicate(true), app.battle_result.get_outcome(),
		app.run_map.get_floors(), app.run_map.get_route(),
		app.run_map.get_legal_choices(), app.encounter_id,
		app.get("run_wallet").get_state() if app.get("run_wallet") != null
			and app.get("run_wallet").has_method("get_state") else null]


func _tag(stage, slot: int) -> PanelContainer:
	return stage._status_tags[slot - 1]


func _caption(stage, slot: int) -> String:
	return (_tag(stage, slot).get_node("Caption") as Label).text


func _pure_refresh(app, stage, reason: String) -> void:
	var before := _snapshot(app)
	var global_seed := 374281
	seed(global_seed)
	var expected_global := randi()
	seed(global_seed)
	for i in range(5):
		stage._sync_battle()
		stage._refresh()
	_check(_snapshot(app) == before and randi() == expected_global,
		reason + ": refreshing never changes actor state, deck, announcements, route, wallet, run or global RNG")


func _click(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(),
		"real visible mouse control is available")
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
		await process_frame


func _inspect(stage, slot: int, trait_caption: String, rule_text: String, reason: String) -> void:
	var tag := _tag(stage, slot)
	var badge: LiveEnemyIntentBadge = stage._badges[slot - 1]
	_check(tag.visible and _caption(stage, slot).contains(trait_caption)
		and tag.tooltip_text.contains(rule_text) and badge.tooltip_text.contains(rule_text),
		reason + ": visible sewn passive and full stage/action hover rule")
	_check(tag.mouse_filter == Control.MOUSE_FILTER_PASS
		and (tag.get_node("Caption") as Label).mouse_filter == Control.MOUSE_FILTER_IGNORE
		and tag.focus_mode == Control.FOCUS_NONE
		and badge.source_position == slot,
		reason + ": status plaque does not consume target click or keyboard focus")
	var puppet: Control = stage._puppets[CombatParty.PARTY_SIZE + slot - 1]
	var rect := tag.get_global_rect()
	_check(tag.is_visible_in_tree() and rect.has_area()
		and puppet.get_global_rect().grow(0.5).encloses(rect)
		and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect)
		and not rect.intersects(badge.get_global_rect())
		and not rect.intersects(stage._thorns_tags[slot - 1].get_global_rect())
		and not rect.intersects(puppet.get_global_transform() * puppet.tag_band()),
		reason + ": plaque fits source art band, away from name, HP, thorns and intent")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var records: Dictionary = ORACLE.records()
	var biter: Dictionary = records.get("thread_biter", {})
	var wasp: Dictionary = records.get("needle_wasp", {})
	var ordinary: Dictionary = records.get("fray_scavenger", {})
	_check(biter.get("id") == "thread_biter" and biter.get("max_hp") == 15
		and biter.get("drain") is bool and biter.get("drain") == true
		and biter.get("intent", {}).get("target") == "lowest_living_hp"
		and wasp.get("id") == "needle_wasp" and wasp.get("max_hp") == 22
		and wasp.get("bleed_on_attack") is bool and wasp.get("bleed_on_attack") == true
		and wasp.get("intent", {}).get("target") == "lowest_living_hp"
		and ordinary.get("id") == "fray_scavenger"
		and not ordinary.has("drain") and not ordinary.has("bleed_on_attack"),
		"authentic shipped actor IDs, true booleans, HP, targets and unflagged neighbor")
	_check(ORACLE.band_ids(1).has("thread_biter") and ORACLE.band_ids(5).has("needle_wasp"),
		"both authored enemies are eligible in their actual live Fight floor bands")
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real mounted App scene loads")
	if scene == null or biter.is_empty() or wasp.is_empty() or ordinary.is_empty():
		_finish()
		return
	# Select an actual legal Fight on the shipped map. The production _start_battle
	# entry admits three unmodified catalog records and binds CombatRoundFlow,
	# CombatEnemyIntents, app stage and the same party/deck/run RNG. Mixed low/mid
	# actors are intentionally tested together via this narrow entry seam; we
	# check each actor's real floor-band eligibility separately above.
	var witness := 0
	for candidate in range(1, 90):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var route := RunMap.new()
		if not route.generate(rng):
			continue
		for node in route.get_legal_choices():
			if route.get_node(node).get("type") == "Fight":
				witness = candidate
				break
		if witness != 0:
			break
	_check(witness > 0, "seeded map contains a genuinely legal Fight entry")
	if witness == 0:
		_finish()
		return
	var app = scene.instantiate()
	app.run_seed = witness
	root.add_child(app)
	await _frames()
	app._open_route()
	await _frames()
	var fight_node := ""
	for node in app.run_map.get_legal_choices():
		if app.run_map.get_node(node).get("type") == "Fight":
			fight_node = node
			break
	_check(not fight_node.is_empty() and app.run_map.choose_node(fight_node),
		"live generated route chooses a legal Fight before admission")
	if fight_node.is_empty():
		app.free()
		_finish()
		return
	var chosen: Array = [biter, wasp, ordinary]
	var model := CombatEnemies.new(chosen)
	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string("res://data/encounters/triple_spool_pinch.json"))
	_check(model.is_valid() and definitions.size() == 3
		and CombatEnemyIntents.new(definitions).is_valid(),
		"real authored triple-schedule and canonical CombatEnemies definitions admitted")
	app._clear_route_view()
	_check(app._start_battle(app.run_rng, definitions, model),
		"production start battle admits catalog actors and starts a real round flow")
	await _frames()
	var stage = app.get_node("LiveEnemyRoster")
	_check(app.party is CombatParty and app.deck is CombatDeck
		and stage.enemies == app.enemies and app.round_flow._started
		and app.round_flow._enemies == app.enemies
		and app.round_flow._intents == app.enemy_intents
		and app.enemy_intents.is_bound() and app.enemy_intents._enemies == app.enemies
		and stage._badges.size() == 3 and stage._status_tags.size() == 3
		and stage._puppets.size() == CombatParty.PARTY_SIZE + 3,
		"real bound scene, three actor puppets, two passives and original flow/scheduler")
	if stage._badges.size() != 3 or not app.enemy_intents.is_bound():
		app.free()
		_finish()
		return
	var drain_help: String = LiveEnemyIntentBadge.CONTACT_HELP["drain"]
	var sting_help: String = LiveEnemyIntentBadge.CONTACT_HELP["bleed_on_attack"]
	_check(drain_help.contains("HP actually lost") and drain_help.contains("missing HP")
		and drain_help.contains("Guard") and drain_help.contains("Block")
		and drain_help.contains("skipped") and drain_help.contains("slain")
		and sting_help.contains("Bleed 1") and sting_help.contains("actual recipient")
		and sting_help.contains("Guard") and sting_help.contains("Block")
		and sting_help.contains("skipped") and sting_help.contains("slain")
		and sting_help.contains("announced Bleed debuff"),
		"full rules distinguish real HP loss, redirected Guard, Block, skip, source survival, separate debuff")
	for i in range(3):
		_check(app.enemies.get_enemy(i + 1).id == chosen[i].id
			and stage._puppets[CombatParty.PARTY_SIZE + i].actor_id == chosen[i].id,
			"each mounted puppet matches its active catalog source " + chosen[i].id)
	_inspect(stage, 1, "Drain", drain_help, "Thread Biter")
	_inspect(stage, 2, "Bleeding Sting", sting_help, "Needle Wasp")
	_check(not _tag(stage, 3).visible and _caption(stage, 3).is_empty()
		and not stage._badges[2].tooltip_text.contains("Passive (")
		and not _caption(stage, 1).contains("Bleeding Sting")
		and not _caption(stage, 2).contains("Drain"),
		"unflagged and other flagged sources never borrow another actor's passive")
	_pure_refresh(app, stage, "authentic initial battle")
	# The weighted scheduler's OWN announcements, never a preview or a fabricated
	# button, must retain their raw amount/target and separate Bleed-2 action.
	var saw_biter_attack := false
	var saw_biter_block := false
	var saw_wasp_attack := false
	var saw_wasp_debuff := false
	for turn in range(100):
		var actions: Array[Dictionary] = app.enemy_intents.get_intents()
		var b: Dictionary = actions[0]
		var w: Dictionary = actions[1]
		stage._refresh()
		var b_badge: LiveEnemyIntentBadge = stage._badges[0]
		var w_badge: LiveEnemyIntentBadge = stage._badges[1]
		_check(b_badge.intent_type == b.type and w_badge.intent_type == w.type
			and b_badge.amount == b.amount and w_badge.amount == w.amount
			and b_badge.tooltip_text.contains(drain_help)
			and w_badge.tooltip_text.contains(sting_help)
			and b_badge.policy_cue == ("Aim low HP" if b.type in ["attack", "debuff"] else "")
			and w_badge.policy_cue == ("Aim low HP" if w.type in ["attack", "debuff"] else ""),
			"authoritative announcements keep exact action, amount and target policy")
		if b.type == "attack":
			saw_biter_attack = saw_biter_attack or (b.amount == 3
				and b_badge.target_position == b.get("target_position"))
		if b.type == "block":
			saw_biter_block = saw_biter_block or (b.amount == 2
				and b_badge.readable_text == "Block +2"
				and b_badge.tooltip_text.contains("Passive (not the announced action)"))
		if w.type == "attack":
			saw_wasp_attack = saw_wasp_attack or (w.amount == 8
				and w_badge.target_position == w.get("target_position"))
		if w.type == "debuff":
			saw_wasp_debuff = saw_wasp_debuff or (w.amount == 2
				and w.get("status") == "bleed" and w_badge.readable_text.contains("Bleed 2")
				and w_badge.tooltip_text.begins_with("Bleed 2 to")
				and w_badge.tooltip_text.contains("Bleed 1")
				and w_badge.tooltip_text.contains("separate from an announced Bleed debuff"))
		if saw_biter_attack and saw_biter_block and saw_wasp_attack and saw_wasp_debuff:
			break
		_check(app.enemy_intents.advance_turn(), "real weighted scheduler advances to next authored announcement")
	_check(saw_biter_attack and saw_biter_block and saw_wasp_attack and saw_wasp_debuff,
		"all 3/2 and 8/Bleed-2 authored attack/nonattack alternatives occurred naturally")
	_pure_refresh(app, stage, "advanced weighted intentions")
	# Both flags on the same authentic, admitted enemy record must share a short
	# extra row with prior statuses, not replace original Bleed/Weak labels.
	app.enemies._enemies[0]["bleed_on_attack"] = true
	_check(app.enemies.apply_statuses({1: {"bleed": 2, "weak": 1, "exposed": 1}}),
		"existing real combat-status API preserves mixed status stacks")
	stage._refresh()
	_inspect(stage, 1, "Bleeding Sting", sting_help, "dual-passive genuine source")
	_check(_caption(stage, 1).contains("Drain") and _caption(stage, 1).contains("Bleed 2")
		and _caption(stage, 1).contains("Weak 1") and _caption(stage, 1).contains("Exposed 1")
		and _tag(stage, 1).tooltip_text.contains(drain_help)
		and stage._badges[0].tooltip_text.contains(sting_help),
		"both traits coexist in the old sewn plaque with timed status captions")
	_pure_refresh(app, stage, "dual traits and timed statuses")
	# Malformed/nonboolean metadata is *not* truthy, and both traits clear
	# independently as soon as the current authoritative record changes.
	for value in [false, "true", 1, 1.0, null]:
		app.enemies._enemies[0]["drain"] = value
		app.enemies._enemies[0]["bleed_on_attack"] = value
		stage._refresh()
		_check(not _caption(stage, 1).contains("Drain")
			and not _caption(stage, 1).contains("Bleeding Sting")
			and not stage._badges[0].tooltip_text.contains("Passive ("),
			"false/nonboolean flag has no invented trait: " + str(value))
	app.enemies._enemies[0].erase("drain")
	app.enemies._enemies[0].erase("bleed_on_attack")
	stage._refresh()
	_check(not _caption(stage, 1).contains("Drain")
		and not _caption(stage, 1).contains("Bleeding Sting")
		and not stage._badges[0].tooltip_text.contains("Passive ("),
		"missing flags remove old passive help from active source")
	app.enemies._enemies[0]["drain"] = true
	stage._refresh()
	_check(_caption(stage, 1).contains("Drain") and not _caption(stage, 1).contains("Bleeding Sting"),
		"restored strict Drain works without the sting flag")
	# A mutated identity within the old admitted model is not a fresh fight.
	# The renderer updates puppet art, but only the originally admitted ID can
	# carry this mounted battle's contact ability.
	app.enemies._enemies[0]["id"] = "old_fight_identity"
	stage._refresh()
	_check(not _caption(stage, 1).contains("Drain")
		and not stage._badges[0].tooltip_text.contains("Passive ("),
		"stale view identity cannot authorize a live passive")
	app.enemies._enemies[0]["id"] = "thread_biter"
	stage._refresh()
	_check(_caption(stage, 1).contains("Drain"), "restored admitted actor identity restores trait")
	app._battle_closed = true
	stage._refresh()
	_check(not _caption(stage, 1).contains("Drain")
		and not stage._badges[0].tooltip_text.contains("Passive ("),
		"closed battle clears trait and badge even before stage unmount")
	app._battle_closed = false
	stage._refresh()
	_check(_caption(stage, 1).contains("Drain"),
		"valid still-bound battle may show original trait again")
	# Source death must suppress stage and hover even with stale saved booleans.
	_check(app.enemies.apply_damage(1, app.enemies.get_enemy(1).hp),
		"real damage API slays current source")
	stage._refresh()
	_check(not _caption(stage, 1).contains("Drain")
		and not stage._badges[0].tooltip_text.contains("Passive (")
		and stage._badges[0].readable_text == "SLAIN",
		"slain source can never heal or show previous passive")
	# Test target input through the passive plaque while the other source lives.
	var selected := false
	for i in range(app.deck.hand.size()):
		if app.deck.hand[i] in ["warden_strike", "seamstress_prick", "tinker_pop_shot"]:
			await _click(app.hand_view.get_child(i) as Control)
			selected = true
			break
	_check(selected, "authentic held targeted attack selected by physical card button")
	if selected:
		var hand_before: int = app.deck.hand.size()
		var energy_before: int = app.deck.energy
		await _click(_tag(stage, 2))
		_check(app.deck.hand.size() < hand_before and app.deck.energy < energy_before,
			"click through living Wasp passive plaque dispatches the real selected-card target")
	# Reusing the same battle view for a different roster must dispose the old
	# instances; without a newly admitted round flow it cannot authenticate
	# even a different genuine, true-flagged catalog actor.
	var old_badge_id: int = stage._badges[1].get_instance_id()
	var replacement := CombatEnemies.new([ordinary, biter, wasp])
	_check(replacement.is_valid(), "same-count replacement uses only real catalog actors")
	app.enemies = replacement
	app._refresh_enemy_roster()
	await _frames()
	_check(stage.enemies == replacement and not is_instance_id_valid(old_badge_id)
		and stage._badges.size() == 3 and not _tag(stage, 2).visible
		and not _tag(stage, 3).visible
		and not stage._badges[1].tooltip_text.contains("Passive (")
		and not stage._badges[2].tooltip_text.contains("Passive ("),
		"rebound roster with stale round-flow authority has no leaked passive cues or hover")
	var old_stage_id: int = _tag(stage, 2).get_instance_id()
	app.return_button.pressed.emit()
	await _frames()
	_check(stage._status_tags.is_empty() and stage._badges.is_empty()
		and not is_instance_id_valid(old_stage_id),
		"return destroys old passive stage and stale hover")
	_check(app._start_battle(), "fresh standalone battle enters via shipped app")
	await _frames()
	_check(stage.enemies == app.enemies and stage._badges.size() == 2
		and _caption(stage, 1).find("Drain") == -1
		and _caption(stage, 1).find("Bleeding Sting") == -1
		and not stage._badges[0].tooltip_text.contains("Passive ("),
		"fresh battle cannot inherit either authored passive or old source")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_v3_enemy_contact_traits_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
