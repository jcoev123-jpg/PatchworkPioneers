extends "res://tests/live_support_hand_test.gd"
## Real mounted SupportHand dispatch to the battle's single Warden Taunt authority.
const TAUNTS := CombatWardenV3TauntCards.CARDS


func _begin_taunt(id: String, bound: bool = false, shove: bool = false) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 35791
	_check(app._start_battle(), "authentic battle UI mounts before the Taunt fixture")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 35791
	app.deck = CombatDeck.new([id, id, "warden_brace", "tinker_tune_up", "seamstress_mend"], rng)
	app.run_rng = rng
	app.party = CombatParty.new([
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30},
		{"id": "tinker", "name": "Tinker", "max_hp": 26}])
	var definitions := [
		{"id": "taunt_one", "name": "Taunt One", "max_hp": 45},
		{"id": "taunt_two", "name": "Taunt Two", "max_hp": 45},
		{"id": "taunt_three", "name": "Taunt Three", "max_hp": 45}]
	if bound:
		definitions[0]["intent"] = {"target": "lowest_living_hp",
			"actions": [{"weight": 1, "type": "attack", "amount": 9, "hits": 2}]}
		definitions[1]["intent"] = {"target": "lowest_living_hp",
			"actions": [{"weight": 1, "type": "attack", "amount": 5}]}
		definitions[2]["intent"] = {"target": "front",
			"actions": [{"weight": 1, "type": "block", "amount": 2}]}
	if shove and bound:
		definitions[0]["intent"] = {"target": "front",
			"actions": [{"weight": 1, "type": "shove", "amount": 0, "direction": 1}]}
		definitions[1]["intent"] = {"target": "lowest_living_hp",
			"actions": [{"weight": 1, "type": "attack", "amount": 19, "hits": 2}]}
	app.enemies = CombatEnemies.new(definitions)
	var schedule: Array = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 9,
			"hits": 2, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 5, "target_position": 2}]},
		{"enemy_position": 3, "pattern": [{"type": "block", "amount": 2}]}]
	if shove:
		schedule = [
			{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0,
				"target_position": 1, "direction": 1}]},
			{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 19,
				"hits": 2, "target_position": 3}]},
			{"enemy_position": 3, "pattern": [{"type": "block", "amount": 2}]}]
	app.enemy_intents = CombatEnemyIntents.new(schedule)
	_check(app.party.is_valid() and app.enemies.is_valid() and app.enemy_intents.is_valid(),
		"real three-hero and three-enemy actors and legal multi-hit intent exist")
	if bound:
		_check(app.enemy_intents.bind_battle(app.enemies, app.party, rng),
			"authentic weighted targets bind and cache against this actual fight")
	app.enemy_attacks = app.enemy_intents.get_intents()
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	_check(app.round_flow.begin_fight() and app.deck.hand.count(id) == 2
		and app.deck.energy == 3 and app.party.get_hero(1).block == 6,
		"real round flow opens one paid hand and true Warden opening Block")
	app._refresh_intents()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"authenticated Taunt card has an actual live clickable/focusable hand panel")
	return panel


func _complete() -> void:
	app.free()
	await _frames()


func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.battle_result.get_outcome(),
		app.round_flow._taunt_service.has_pending_taunt(),
		app.round_flow._taunt_service.get_pending_taunt_card_id()]


func _input_card(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	await _frames()


func _end(keyboard: bool) -> void:
	if keyboard:
		app.end_turn_button.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(app.end_turn_button)
	await _frames()


func _successful(id: String, keyboard: bool, bound: bool = false) -> Array:
	var panel := await _begin_taunt(id, bound)
	if panel == null:
		await _complete()
		return []
	var printed: Dictionary = TAUNTS[id]
	var before := _state()
	var original_intents: Array = app.enemy_intents.get_intents()
	await _input_card(panel, keyboard)
	var expected_cost: int = printed.cost
	var gain: int = int(printed.get("block", printed.get("block_all", 0)))
	_check(app.deck.energy == 3 - expected_cost and app.deck.hand.count(id) == 1
		and app.deck.discard_pile.count(id) == 1 and app.deck.draw_pile == before[0][0],
		id + ": exactly one held authentic card paid and discarded, no shuffle")
	_check(app.round_flow._taunt_service.has_pending_taunt()
		and app.round_flow._taunt_service.get_pending_taunt_card_id() == id
		and app.run_rng.state == before[0][7]
		and app.enemy_intents.get_intents() == original_intents,
		id + ": one Taunt armed without touching cached attacks or RNG")
	var heroes: Array = app.party.get_heroes()
	for pos in range(1, 4):
		var amount: int = gain if (printed.target_kind == "party_all" or pos == 1) else 0
		_check(heroes[pos - 1].block == (6 if pos == 1 else 0) + amount,
			id + ": exact printed self / living-party Block at seat " + str(pos))
	_check(app.enemies.get_enemy(3).block == 0, "third enemy begins without Block")
	if expected_cost == 2:
		var second: Control = _panel(id)
		_check(second != null, id + ": second identical card remains genuinely held")
		var too_poor := _state()
		await _input_card(second, not keyboard)
		_check(_state() == too_poor, id + ": underfunded second play does not spend, discard or refresh Taunt")
	var before_end: Array = app.party.get_heroes()
	await _end(not keyboard)
	var damage: int = 14
	var warden_block: int = before_end[0].block
	_check(app.party.get_hero(1).hp == 40 - maxi(0, damage - warden_block)
		and app.party.get_hero(2).hp == 30 and app.party.get_hero(3).hp == 26,
		id + ": real End Turn redirects both first-enemy hits plus second attack")
	_check(app.enemies.get_enemy(3).block == 2,
		id + ": non-attack Block remains at its exact authored amount")
	_check(app.enemy_intents.get_intents() != [] and app.run_rng.state != -1
		and app.enemy_attacks == app.enemy_intents.get_intents()
		and not app.round_flow._taunt_service.has_pending_taunt(),
		id + ": committed enemy phase expires Taunt, not the original announcements")
	var hp_after: int = app.party.get_hero(1).hp
	await _end(keyboard)
	_check(app.party.get_hero(1).hp == hp_after and app.party.get_hero(2).hp == 25
		and app.party.get_hero(3).hp == 17
		and not app.round_flow._taunt_service.has_pending_taunt(),
		id + ": the following phase obeys original targets with no leaked Taunt")
	var trace := _state()
	await _complete()
	return trace


func _refusals(id: String) -> void:
	var panel := await _begin_taunt(id)
	if panel == null:
		await _complete()
		return
	var before := _state()
	app.deck.combat_state.energy = 0
	var poor := _state()
	await _input_card(panel, true)
	_check(_state() == poor, "insufficient energy preserves HP, piles, Block, latch and RNG: " + id)
	app.deck.combat_state.energy = 3
	app.party._heroes[0]["id"] = "other_owner"
	var owner := _state()
	await _input_card(panel, false)
	_check(_state() == owner, "wrong owner refuses without any mutation: " + id)
	app.party._heroes[0]["id"] = "warden"
	_check(_state() == before, "negative fixture restores exactly the same valid battle")
	# A panel armed against a changed hand or a foreign scheduler is inert.
	var panel_index: int = panel.get_index()
	app.deck.hand[panel_index] = "warden_brace"
	var stale_hand := _state()
	await _input_card(panel, true)
	_check(_state() == stale_hand, "stale hand panel refuses with exact no-spend snapshot")
	app.deck.hand[panel_index] = id
	var genuine_intents: CombatEnemyIntents = app.enemy_intents
	app.enemy_intents = CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}])
	var foreign := _state()
	await _input_card(panel, false)
	_check(_state() == foreign, "foreign battle scheduler cannot authorize an old hand panel")
	app.enemy_intents = genuine_intents
	_check(_state() == before, "restored live hand and battle match exact seed and latch")
	# A stale announcement fails End Turn without spending Taunt or mutating actors.
	await _input_card(panel, false)
	_check(app.round_flow._taunt_service.has_pending_taunt(), "genuine card arms the latch before negative turn")
	var cached: Array = app.enemy_attacks.duplicate(true)
	app.enemy_attacks[0]["amount"] = 999
	var stale := _state()
	await _end(false)
	_check(_state() == stale, "stale announcement refuses before phase/energy/RNG/expiry")
	app.enemy_attacks = cached
	# A genuinely invalid multi-hit action is also rejected in detached preflight.
	app.enemy_intents._definitions[0]["pattern"][0]["target_position"] = 99
	app.enemy_attacks = app.enemy_intents.get_intents()
	var bad := _state()
	await _end(true)
	_check(_state() == bad and app.round_flow._taunt_service.has_pending_taunt(),
		"invalid executable action refuses the entire turn with Taunt still armed")
	app.enemy_intents._definitions[0]["pattern"][0]["target_position"] = 3
	app.enemy_attacks = app.enemy_intents.get_intents()
	await _end(false)
	_check(not app.round_flow._taunt_service.has_pending_taunt(),
		"accepted retry after refusal completes the original Taunt exactly once")
	await _complete()


func _downed_bound(id: String) -> void:
	var panel := await _begin_taunt(id, true)
	if panel == null:
		await _complete()
		return
	var originals: Array = app.enemy_intents.get_intents()
	_check(originals[0].target_position == 3 and originals[1].target_position == 3,
		"bound seeded announcements actually choose the initially living Tinker")
	await _input_card(panel, true)
	_check(app.party.apply_damage(3, 99) and app.party.is_downed(3)
		and not app.party.is_defeated(), "announced original recipient is genuinely downed")
	var hero_before: Dictionary = app.party.get_hero(1)
	await _end(false)
	_check(app.party.get_hero(2).hp == 30 and app.party.get_hero(3).hp == 0
		and app.party.get_hero(1).hp < hero_before.hp + 1,
		"policy fallback from downed announced hero is redirected to living Warden")
	_check(not app.round_flow._taunt_service.has_pending_taunt()
		and originals[0].target_position == 3,
		"bound fallback consumes Taunt without rewriting prior intent cache")
	await _complete()


func _downed_warden_fallback() -> void:
	var id := "warden_v3_iron_challenge"
	var panel := await _begin_taunt(id, true)
	if panel == null:
		await _complete()
		return
	await _input_card(panel, true)
	_check(app.round_flow._taunt_service.has_pending_taunt()
		and app.party.apply_damage(1, 999) and app.party.is_downed(1)
		and not app.party.is_defeated(), "pending Taunt has genuinely downed Warden and surviving allies")
	await _end(false)
	_check(app.party.get_hero(1).hp == 0 and app.party.get_hero(2).hp == 30
		and app.party.get_hero(3).hp == 12,
		"downed Warden cannot redirect; both authored attacks use living announced target")
	_check(not app.round_flow._taunt_service.has_pending_taunt(),
		"committed fallback turn consumes pending Taunt even when Warden is downed")
	await _complete()


func _shove_live() -> void:
	# The first enemy moves the living Warden to seat 2; the next one
	# announces a DIFFERENT seat. Both attacks and movement use the real
	# mounted hand -> round-flow -> enemy-executor path.
	for bound in [false, true]:
		var id := "warden_v3_iron_challenge"
		var panel := await _begin_taunt(id, bound, true)
		if panel == null:
			await _complete()
			continue
		var announced: Array = app.enemy_intents.get_intents()
		_check(announced.size() == 3 and announced[0].type == "shove"
			and announced[0].target_position == 1 and announced[0].direction == 1
			and announced[1].type == "attack" and announced[1].hits == 2
			and announced[1].target_position == 3 and app.party.get_hero(1).id == "warden"
			and app.party.get_hero(1).hp == 40 and app.party.get_hero(2).hp == 30
			and app.party.get_hero(3).hp == 26,
			"shove case has real living heroes, first-seat Warden, distinct cached target and two hits")
		await _input_card(panel, true)
		_check(app.round_flow._taunt_service.has_pending_taunt()
			and app.deck.energy == 2 and app.deck.discard_pile.count(id) == 1
			and app.party.get_hero(1).block == 9
			and app.enemy_intents.get_intents() == announced,
			"paid mounted Taunt arms exactly once with original announcements untouched")
		# Make the second beat invalid after an otherwise legal shove. The
		# refused phase must leave ALL authoritative resources intact.
		if bound:
			app.enemy_intents._cache[1].amount = -1
		else:
			app.enemy_intents._definitions[1].pattern[0].amount = -1
		var refused := _state()
		_check(not app.round_flow.end_turn() and _state() == refused
			and app.round_flow._taunt_service.has_pending_taunt(),
			"rejected shove/attack phase preserves exact HP, Block, piles, RNG and Taunt")
		if bound:
			app.enemy_intents._cache[1].amount = 19
		else:
			app.enemy_intents._definitions[1].pattern[0].amount = 19
		_check(app.enemy_intents.get_intents() == announced,
			"failed phase preserves unmodified cached source announcement on retry")
		await _end(false)
		_check(app.party.get_hero(1).id == "seamstress"
			and app.party.get_hero(2).id == "warden"
			and app.party.get_hero(2).hp == 30 and app.party.get_hero(2).block == 0
			and app.party.get_hero(1).hp == 30 and app.party.get_hero(3).hp == 26,
			"shove commits before redirected 19-point double-hit on Warden now in seat 2")
		_check(app.enemies.get_enemy(3).block == 2
			and not app.round_flow._taunt_service.has_pending_taunt()
			and not app.round_flow._taunt_service.complete_enemy_turn(),
			"third enemy non-attack still executes and completed phase expires Taunt only once")
		await _complete()


func _retirement() -> void:
	var id := "warden_v3_iron_challenge"
	var panel := await _begin_taunt(id)
	if panel == null:
		await _complete()
		return
	await _input_card(panel, false)
	var prior: CombatRoundFlow = app.round_flow
	_check(prior._taunt_service.has_pending_taunt(), "first fight really owns an armed Taunt")
	app._return_to_title()
	_check(not prior._taunt_service.has_pending_taunt() and app.round_flow == null,
		"Return retires the old service before a new fight")
	_check(app._start_battle() and app.round_flow != prior
		and not app.round_flow._taunt_service.has_pending_taunt(),
		"a subsequent genuine mounted battle has an independent empty Taunt")
	await _complete()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	for id in TAUNTS:
		var first := await _successful(id, false)
		var replay := await _successful(id, true)
		_check(not first.is_empty() and first == replay,
			id + ": mouse and keyboard paths replay same-seed HP, piles, latch and RNG")
		await _refusals(id)
	await _shove_live()
	await _downed_bound("warden_v3_iron_challenge")
	await _downed_warden_fallback()
	await _retirement()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_warden_v3_taunt_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
