extends "res://tests/live_support_hand_test.gd"

const IDS := ["scarecrow_fork_jab", "scarecrow_fork_jab_plus",
	"scarecrow_pitchfork_prick", "scarecrow_pitchfork_prick_plus"]
var _last_result: Array = []

func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "mounted battle starts")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two genuine drawn copies")
	app.deck.combat_state.energy = 6
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25, "statuses": {"dodge_next_attack": 1}}]
	heroes.insert(seat - 1, {"id": "scarecrow", "name": "Scarecrow", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "tangled", "name": "Tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1, "blind_next_attack": 1, "cannot_buff_next_turn": true}},
		{"id": "untangled", "name": "Blocked", "max_hp": 50, "statuses": {"bleed": 2, "blind_next_attack": 1, "cannot_buff_next_turn": true}},
		{"id": "rear", "name": "Rear", "max_hp": 50, "statuses": {"tangled": 3}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "real valid rosters")
	_check(app.enemies.gain_block(1, 2) and app.enemies.gain_block(2, 20), "partial and full Block fixtures")
	_check(app.party.get_hero(seat).id == "scarecrow" and app.enemies.get_enemy(2).block == 20,
		"non-vacuous owner seat and real Block preconditions")
	var ally_seat: int = 3 if seat != 3 else 2
	_check(app.party.get_hero(ally_seat).statuses.get("dodge_next_attack") == 1
		and app.enemies.get_enemy(1).statuses.get("blind_next_attack") == 1
		and app.enemies.get_enemy(1).statuses.get("cannot_buff_next_turn") == true
		and app.enemies.get_enemy(2).statuses.get("blind_next_attack") == 1
		and app.enemies.get_enemy(2).statuses.get("cannot_buff_next_turn") == true,
		"authentic mixed dodge, blind and fear preconditions")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel), "authentic panel bound by mounted adapter")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _arm_pitchfork(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(presenter._pending.get("choosing", false) and presenter._targets.size() > 0,
		"real enemy selection armed")


func _success(id: String, seat: int, input: int) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	var meta = presenter._metadata
	var definition := CombatScarecrowPitchforkCards.new()._catalog_definition(id)
	_check(not definition.is_empty() and definition.effects.damage > 0 and definition.effects.bleed > 0,
		"authentic nonempty damage/Bleed definition")
	var facts: Dictionary = meta.get_facts(panel)
	_check(facts.known and facts.owner == "scarecrow" and facts.owner_text == "Scarecrow"
		and facts.cost == 1 and meta.definition(id) == definition, "exact catalog metadata")
	_check(facts.from_text == "From " + meta._positions([1, 2])
		and facts.target_text == "To enemy " + meta._positions([1, 2])
		and meta.short_line(id) == CardShortRules.line(definition)
		and panel.tooltip_text.contains("Bleed %d" % definition.effects.bleed)
		and panel.tooltip_text.contains("%d" % definition.effects.damage)
		and meta.visual_state(panel).playable, "honest cost, damage, Bleed, positions and enabled face")
	for held in app.hand_view.get_children():
		if held.get_child(0).text == id:
			_check(held.gui_input.get_connections().size() == 1 and presenter._bindings.has(held),
				"one authenticated callback per identical held panel")
	var before := _pool_state()
	var target := 1 if input == 0 else 2
	var expected: Dictionary = app.enemies.get_enemy(target).duplicate(true)
	var damage: int = definition.effects.damage
	if target == 1:
		damage = int(floor(damage * 1.5)) + 2
	var absorbed: int = mini(expected.block, damage)
	expected.block -= absorbed
	expected.hp -= damage - absorbed
	var expected_bleed: int = int(expected.statuses.get("bleed", 0)) + int(definition.effects.bleed)
	expected.statuses.bleed = expected_bleed
	await _arm_pitchfork(panel, input != 0)
	_check(_pool_state() == before, "arming preserves complete state and RNG")
	_check(presenter._targets.size() == 2 and presenter.help_label.text.contains("(1-2)"),
		"only authored enemy slots offered")
	var labels: Array = app.get_node("LiveEnemyRoster")._labels
	_check(not presenter._targets.has(labels[2]), "living slot three is illegal")
	await _keyboard(KEY_3)
	_check(_pool_state() == before, "illegal slot key cannot spend")
	var target_panel: Control = labels[target - 1]
	var callback: Callable = presenter._targets[target_panel].callback
	if input == 0:
		await _mouse(target_panel)
	elif input == 1:
		target_panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		root.push_input(_key(KEY_2), true)
		root.push_input(_key(KEY_2), true)
		root.push_input(_key(KEY_2, false), true)
		await _frames()
	_check(app.enemies.get_enemy(target) == expected, "exact independent Block, HP and printed Bleed result")
	var expected_hand: Array = before[1].duplicate()
	expected_hand.erase(id)
	var expected_discard: Array = before[2].duplicate()
	expected_discard.append(id)
	_check(app.deck.hand == expected_hand and app.deck.discard_pile == expected_discard
		and app.deck.draw_pile == before[0] and app.deck.energy == before[3] - 1,
		"one energy and exactly one held copy paid without drawing")
	_check(app.party.get_heroes() == before[5] and app.run_rng.state == before[11], "party and RNG preserved")
	for slot in [1, 2, 3]:
		if slot != target:
			_check(app.enemies.get_enemy(slot) == before[6][slot - 1], "other enemies unchanged")
	var ally_seat_pos: int = 3 if seat != 3 else 2
	_check(app.party.get_hero(ally_seat_pos).statuses.get("dodge_next_attack") == 1,
		"unrelated ally Dodge token is not spent by pitchfork card")
	_check(app.enemies.get_enemy(target).statuses.get("blind_next_attack") == 1
		and app.enemies.get_enemy(target).statuses.get("cannot_buff_next_turn") == true,
		"unrelated target Blind and Fear statuses are not spent by pitchfork card")
	_check(presenter._pending.is_empty() and app.end_turn_button.has_focus(), "receipt consumed and focus restored")
	var roster = app.get_node("LiveEnemyRoster")
	var meter = app.get_node("LiveCombatMeters").row.get_child(3 + target - 1)
	_check(roster._status_tags[target - 1].visible
		and roster._status_tags[target - 1].tooltip_text.contains("Bleed %d" % expected_bleed)
		and meter.hp_text.text == "%d/%d" % [expected.hp, expected.max_hp]
		and meter.hp_bar.value == expected.hp and meter.block_badge.visible == (expected.block > 0)
		and meter.block_text.text == (str(expected.block) if expected.block > 0 else ""),
		"real enemy HP and status HUD refreshed")
	_check(presenter.energy_label.text == str(app.deck.energy)
		and app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size()), "energy and piles refreshed")
	var remaining := _pool_panel(id)
	_check(remaining != null and meta.get_facts(remaining).known
		and meta.short_line(id) == CardShortRules.line(definition), "remaining copy retains genuine information")
	var after := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == after and app.deck.hand.count(id) == 1, "retired target cannot spend remaining copy")
	_last_result = after.duplicate(true)
	await _dispose()


func _unavailable(mode: String) -> void:
	var panel := await _begin(IDS[0], 3 if mode == "seat" else 2)
	if panel == null:
		await _dispose()
		return
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"owner": app.party.apply_damage(2, 999)
		"missing": app.party._heroes[1].id = "seamstress"
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"targets":
			_check(app.enemies.apply_damage(1, 999) and app.enemies.apply_damage(2, 999)
				and app.enemies.get_enemy(3).hp > 0, "only out-of-range enemy remains alive")
		"status": app.enemies._enemies[1].statuses = []
	app._refresh_intents()
	presenter._metadata._update_visual(panel)
	_check(not presenter._metadata.visual_state(panel).playable, "disabled face before input: " + mode)
	var callback: Callable = presenter._bindings[panel]
	if mode == "targets":
		app._observe_battle_result()
	var before := _pool_state()
	if mode == "targets":
		callback.call(_press())
		await _frames()
	else:
		await _mouse(panel)
	_check(_pool_state() == before and presenter._pending.is_empty(), "unavailable card cannot arm or spend: " + mode)
	await _dispose()


func _living_keys() -> void:
	for slot in [1, 2]:
		var panel := await _begin(IDS[1])
		var dead_slot: int = 3 - slot
		_check(app.enemies.apply_damage(dead_slot, 999), "genuinely slain target")
		app._refresh_intents()
		await _arm_pitchfork(panel, true)
		var labels: Array = app.get_node("LiveEnemyRoster")._labels
		_check(presenter._targets.size() == 1 and presenter._targets.has(labels[slot - 1])
			and not presenter._targets.has(labels[dead_slot - 1]), "only living legal target offered")
		var before := _pool_state()
		await _keyboard(KEY_1 if dead_slot == 1 else KEY_2)
		await _mouse(labels[2])
		_check(_pool_state() == before, "dead shortcut and illegal mouse target preserve all state")
		await _keyboard(KEY_1 if slot == 1 else KEY_2)
		_check(app.deck.hand.count(IDS[1]) == 1 and app.enemies.get_enemy(slot).statuses.get("bleed", 0) >= 2,
			"both legal living shortcuts commit")
		await _dispose()


func _refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	await _arm_pitchfork(panel, true)
	var target: Control = app.get_node("LiveEnemyRoster")._labels[0]
	var callback: Callable = presenter._targets[target].callback
	if queued:
		callback.call(_press())
		_check(presenter._pending.get("queued", false), "actual commit deferred")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"downed": app.party.apply_damage(2, 999)
		"missing": app.party._heroes[1].id = "seamstress"
		"seat":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[2]
			app.party._heroes[2] = hero
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"dead": app.enemies.apply_damage(1, 999)
		"identity": app.enemies._enemies[0].id = "replacement"
		"replacement": app.enemies._enemies[0] = app.enemies._enemies[0].duplicate(true)
		"status": app.enemies._enemies[0].statuses = {"exposed": -1}
		"inactive": app.deck.combat_state.player_turn_active = false
		"turn": app.enemy_intents.advance_turn()
		"closed": app._battle_closed = true
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"deck":
			var rng := RandomNumberGenerator.new()
			rng.seed = 8
			app.deck = CombatDeck.new([IDS[0]], rng)
			app.deck.start_turn()
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = IDS[1]
		"escape":
			root.push_input(_key(KEY_ESCAPE), true)
			root.push_input(_key(KEY_ESCAPE, false), true)
		"cancel": presenter.cancel_button.pressed.emit()
	# Settle presentation-only forecasts for externally changed fixture state.
	app._refresh_intents()
	var before := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(), "complete no-spend rejection: " + mode)
	callback.call(_press())
	await _frames()
	_check(_pool_state() == before, "rejected receipt cannot replay: " + mode)
	await _dispose()


func _malformed_tokens() -> void:
	var cases: Array[Dictionary] = [
		{"name": "dodge_true", "status": {"dodge_next_attack": true}},
		{"name": "dodge_neg", "status": {"dodge_next_attack": -1}},
		{"name": "dodge_2", "status": {"dodge_next_attack": 2}},
		{"name": "blind_true", "status": {"blind_next_attack": true}},
		{"name": "blind_float", "status": {"blind_next_attack": 1.0}},
		{"name": "blind_2", "status": {"blind_next_attack": 2}},
		{"name": "fear_false", "status": {"cannot_buff_next_turn": false}},
		{"name": "fear_int", "status": {"cannot_buff_next_turn": 1}},
		{"name": "fear_string", "status": {"cannot_buff_next_turn": "true"}},
		{"name": "counted_neg", "status": {"exposed": -1}},
		{"name": "unknown_key", "status": {"unknown_status": 1}},
	]
	for case in cases:
		var panel := await _begin(IDS[0])
		if panel == null:
			await _dispose()
			return
		await _arm_pitchfork(panel, true)
		var target: Control = app.get_node("LiveEnemyRoster")._labels[0]
		var callback: Callable = presenter._targets[target].callback
		app.enemies._enemies[0].statuses = case["status"]
		app._refresh_intents()
		var before := _pool_state()
		callback.call(_press())
		await _frames()
		_check(_pool_state() == before and presenter._pending.is_empty(),
			"malformed status refuses BEFORE mutation: " + case["name"])
		callback.call(_press())
		await _frames()
		_check(_pool_state() == before,
			"rejected malformed receipt cannot replay: " + case["name"])
		await _dispose()

	var hero_cases: Array[Dictionary] = [
		{"name": "hero_dodge_bool", "status": {"dodge_next_attack": true}},
		{"name": "hero_dodge_2", "status": {"dodge_next_attack": 2}},
		{"name": "hero_blind_float", "status": {"blind_next_attack": 1.0}},
		{"name": "hero_fear_false", "status": {"cannot_buff_next_turn": false}},
		{"name": "hero_fear_int", "status": {"cannot_buff_next_turn": 1}},
		{"name": "hero_unknown", "status": {"bogus_status": 1}},
	]
	for case in hero_cases:
		var panel := await _begin(IDS[0])
		if panel == null:
			await _dispose()
			return
		await _arm_pitchfork(panel, true)
		var target: Control = app.get_node("LiveEnemyRoster")._labels[0]
		var callback: Callable = presenter._targets[target].callback
		app.party._heroes[0].statuses = case["status"]
		app._refresh_intents()
		var before := _pool_state()
		callback.call(_press())
		await _frames()
		_check(_pool_state() == before and presenter._pending.is_empty(),
			"hero malformed status refuses BEFORE mutation: " + case["name"])
		callback.call(_press())
		await _frames()
		_check(_pool_state() == before,
			"rejected hero malformed receipt cannot replay: " + case["name"])
		await _dispose()


func _mixed_status_continuation() -> void:
	var panel := await _begin(IDS[0], 2)
	if panel == null:
		await _dispose()
		return
	await _arm_pitchfork(panel, false)
	var target1: Control = app.get_node("LiveEnemyRoster")._labels[0]
	var callback1: Callable = presenter._targets[target1].callback
	callback1.call(_press())
	await _frames()
	_check(app.deck.hand.count(IDS[0]) == 1 and app.deck.energy == 5,
		"first genuine play succeeded")
	_check(app.enemies.get_enemy(1).statuses.get("bleed", 0) == 1,
		"printed Bleed applied to enemy 1")
	var e1: Dictionary = app.enemies.get_enemy(1).statuses
	var e2: Dictionary = app.enemies.get_enemy(2).statuses
	var ally: Dictionary = app.party.get_hero(3).statuses
	_check(ally.get("dodge_next_attack") == 1,
		"unrelated ally Dodge remains 1 after valid hit")
	_check(e1.get("blind_next_attack") == 1,
		"unrelated target Blind remains 1 after valid hit")
	_check(e1.get("cannot_buff_next_turn") == true,
		"unrelated target Fear remains true after valid hit")
	_check(e2.get("blind_next_attack") == 1,
		"unrelated enemy 2 Blind remains 1 after valid hit")
	_check(e2.get("cannot_buff_next_turn") == true,
		"unrelated enemy 2 Fear remains true after valid hit")

	var fear_test := CombatStatuses.new().can_apply_buff(e1)
	_check(fear_test.get("ok", false) and fear_test.get("allowed") == false,
		"Fear lock remains functional for buff consumer")
	var dodge_test := CombatStatuses.new().dodge_project_for_attempt(ally, true)
	_check(dodge_test.get("ok", false) and dodge_test.get("miss") == true
		and not dodge_test.get("statuses", {}).has("dodge_next_attack"),
		"Dodge remains functional for attack consumer")

	var panel2 := _pool_panel(IDS[0])
	_check(panel2 != null, "second held copy panel exists")
	await _arm_pitchfork(panel2, true)
	var target2: Control = app.get_node("LiveEnemyRoster")._labels[1]
	var callback2: Callable = presenter._targets[target2].callback
	app.enemies._enemies[1].statuses["cannot_buff_next_turn"] = 1
	app._refresh_intents()
	var post_valid_state := _pool_state()
	callback2.call(_press())
	await _frames()
	_check(_pool_state() == post_valid_state and presenter._pending.is_empty(),
		"malformed token on enemy 2 refuses after earlier valid hit")
	callback2.call(_press())
	await _frames()
	_check(_pool_state() == post_valid_state,
		"rejected post-valid receipt cannot replay")

	app.enemies._enemies[1].statuses = {"bleed": 2, "blind_next_attack": 1, "cannot_buff_next_turn": true}
	app._refresh_intents()
	panel2 = _pool_panel(IDS[0])
	await _arm_pitchfork(panel2, true)
	callback2 = presenter._targets[target2].callback
	callback2.call(_press())
	await _frames()
	_check(app.deck.hand.count(IDS[0]) == 0 and app.deck.energy == 4,
		"second genuine copy paid successfully")
	var e2_after: Dictionary = app.enemies.get_enemy(2)
	_check(e2_after.hp == 50 and e2_after.block == 16,
		"full Block absorption on enemy 2: hp 50, block 16")
	_check(e2_after.statuses.get("bleed", 0) == 3,
		"printed Bleed 1 lands through full Block absorption (2 -> 3)")
	_check(e2_after.statuses.get("blind_next_attack") == 1
		and e2_after.statuses.get("cannot_buff_next_turn") == true,
		"unrelated Blind and Fear on enemy 2 remain intact after second hit")
	_check(app.party.get_hero(3).statuses.get("dodge_next_attack") == 1,
		"unrelated ally Dodge remains intact after second hit")
	await _dispose()


func _attacker_weak_and_status_formula() -> void:
	var panel := await _begin(IDS[0], 2)
	if panel == null:
		await _dispose()
		return
	app.party._heroes[1].statuses = {"weak": 1}
	app._refresh_party()
	await _arm_pitchfork(panel, false)
	var target1: Control = app.get_node("LiveEnemyRoster")._labels[0]
	var callback: Callable = presenter._targets[target1].callback
	callback.call(_press())
	await _frames()
	var enemy1: Dictionary = app.enemies.get_enemy(1)
	_check(enemy1.block == 0 and enemy1.hp == 46,
		"Weak + Exposed + Tangled exact formula: base 4 -> 6 damage, 2 Block absorbed, 4 HP loss")
	_check(enemy1.statuses.get("bleed", 0) == 1, "printed Bleed 1 added")
	_check(enemy1.statuses.get("blind_next_attack") == 1
		and enemy1.statuses.get("cannot_buff_next_turn") == true,
		"target Blind and Fear preserved with Weak attacker")
	_check(app.party.get_hero(3).statuses.get("dodge_next_attack") == 1,
		"ally Dodge preserved with Weak attacker")
	_check(app.party.get_hero(2).statuses.get("weak") == 1,
		"attacker Weak preserved without spending")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for seat in [1, 2]:
			for input in [0, 1, 2]:
				await _success(id, seat, input)
	for mode in ["seat", "energy", "owner", "missing", "hand", "targets", "status"]:
		await _unavailable(mode)
	await _living_keys()
	await _success(IDS[2], 2, 2)
	var replay := _last_result.duplicate(true)
	await _success(IDS[2], 2, 2)
	_check(_last_result == replay, "entire mounted seeded sequence replays exactly")
	for mode in ["energy", "downed", "missing", "seat", "hand", "dead", "identity", "replacement", "status",
		"inactive", "turn", "closed", "session", "deck", "panel", "label", "escape", "cancel"]:
		for queued in [false, true]:
			await _refuse(mode, queued)
	await _malformed_tokens()
	await _mixed_status_continuation()
	await _attacker_weak_and_status_formula()
	_finish()
