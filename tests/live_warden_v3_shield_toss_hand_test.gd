extends "res://tests/live_warden_pool_heavy_hand_test.gd"
## Reuse physical input and genuine scene/deck fixture helpers only.

const TOSSES := ["warden_v3_rim_toss", "warden_v3_rim_toss_plus",
	"warden_v3_shield_toss", "warden_v3_shield_toss_plus"]
var global_expected: Array = []


func _oracle(id: String, position: int, snapshot: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(snapshot[11])
	rng.state = int(snapshot[12])
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(snapshot[0])
	deck.hand.assign(snapshot[1])
	deck.discard_pile.assign(snapshot[2])
	deck.combat_state.player_turn_active = bool(snapshot[4])
	deck.combat_state.energy = int(snapshot[5])
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((snapshot[6] as Array).duplicate(true))
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	enemies._enemies.assign((snapshot[7] as Array).duplicate(true))
	var owner: Dictionary = {}
	for hero in party.get_heroes():
		if hero.id == "warden":
			owner = hero
	var event := CombatWardenV3ShieldTossCards.new().play_card(deck, party, enemies,
		id, position, owner.get("statuses", {}), enemies.get_enemy(position).get("statuses", {}))
	return {"event": event, "hand": deck.hand, "discard": deck.discard_pile,
		"energy": deck.energy, "heroes": party.get_heroes(), "enemies": enemies.get_enemies()}


func _guard_global() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 87231
	global_expected.clear()
	for index in range(8):
		global_expected.append(rng.randi())
	seed(87231)


func _check_global() -> void:
	for expected in global_expected:
		_check(randi() == expected, "global RNG unchanged during live gameplay")


func _toss_play(id: String, keyboard: bool, position: int, block: int, middle: bool) -> void:
	if not await _start(id):
		return
	if position == 3:
		_third_enemy()
	if middle:
		var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
		_check(swap.ok, "authentic owner swap to middle")
		app.party._heroes.assign(swap.heroes)
	var owner_position := 2 if middle else 1
	_check(app.party.get_hero(owner_position).id == "warden", "live owner identity")
	app.party._heroes[owner_position - 1].block = 0
	_check(app.party.gain_block(owner_position, block), "set authoritative Warden Block")
	_check(app.party.gain_block(3, 19), "another hero's Block is irrelevant")
	app.party._heroes[owner_position - 1]["statuses"] = {"weak": 1}
	_check(app.enemies.apply_statuses({position: {"exposed": 1}})
		and app.enemies.gain_block(position, 4), "live defender status and Block")
	await _frames()
	_guard_global()
	var panel := _panel(id)
	var definition: Dictionary = presenter._definition(id)
	_check(definition.id == id and definition.owner == "warden" and definition.cost == 1
		and definition.from_positions == [1, 2] and definition.to_positions == [1, 2, 3]
		and definition.effects.get("bonus_damage", 0) == (2 if id == TOSSES[1] else 3 if id == TOSSES[3] else 0),
		"exact catalog identity, cost, source/target pips and printed bonus")
	var before := _state()
	if keyboard:
		_check(await _key_select(id), "keyboard selects actual held copy")
	else:
		await _click(panel)
	_check(presenter._armed == panel, "genuine panel armed")
	var quote: Dictionary = presenter._target_preview(id)
	_check(quote.playable and quote.requires_selection
		and quote.target_positions.has(position), "live legal target forecast")
	var oracle := _oracle(id, position, before)
	_check(oracle.event.ok and oracle.event.owner_block == block,
		"paid oracle binds exact own Block")
	var expected_damage := int(floor((block + oracle.event.bonus_damage) * 0.75 * 1.5))
	_check(oracle.event.damage == expected_damage, "independent Block bonus status rounding")
	_check(presenter.current_forecast == quote
		and presenter.cue.text.contains("%d: %d damage" % [position, expected_damage]),
		"visible forecast matches exact committed rule")
	var metadata = app.get_node("LiveSupportHand")._metadata
	_check(metadata.get_facts(panel).known
		and metadata.get_facts(panel).rules.contains("own Block")
		and panel.tooltip_text.contains("current Block")
		and not panel.tooltip_text.contains("not described")
		and metadata.visual_state(panel).playable, "real card face and legal visual state")
	if not keyboard:
		_check(metadata.visual_state(panel).hovered, "physical hover highlights real toss face")
	_check(_state() == before, "selection and forecasts wholly read only")
	if keyboard:
		await _keyboard(KEY_1 + position - 1)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])
	_check(presenter.last_event == oracle.event, "live commit equals paid service")
	_check(app.deck.hand == oracle.hand and app.deck.discard_pile == oracle.discard
		and app.deck.energy == oracle.energy and app.deck.energy == int(before[3]) - 1,
		"one exact payment and discard")
	_check(app.party.get_heroes() == oracle.heroes and app.enemies.get_enemies() == oracle.enemies,
		"complete rosters match oracle; owner Block retained")
	_check(app.deck.draw_pile == before[0] and app.deck._rng.state == before[12], "seeded RNG and draw unchanged")
	var after := _state()
	await _keyboard(KEY_1 + position - 1)
	_check(_state() == after, "consumed receipt cannot replay")
	_check_global()
	await _return()


func _refusal(scenario: String) -> void:
	var id: String = TOSSES[1]
	if not await _start(id):
		return
	var panel := _panel(id)
	await _click(panel)
	_check(presenter._armed == panel, "negative starts armed " + scenario)
	match scenario:
		"energy":
			app.deck.combat_state.energy = 0
		"downed":
			_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "owner actually downed")
		"from":
			app.party._heroes.reverse()
			for index in range(3):
				app.party._heroes[index].position = index + 1
			_check(app.party.get_hero(3).id == "warden" and app.party.is_valid(), "living owner in illegal FROM")
		"dead":
			_check(app.enemies.apply_damage(2, 10000) and app.enemies.is_slain(2), "target actually dead")
		"absent":
			_check(app.deck.discard_played(id) and not app.deck.hand.has(id), "held card actually removed")
		"statuses":
			app.party._heroes[0]["statuses"] = {"weak": -1}
		"defender":
			app.enemies._enemies[1]["statuses"] = {"exposed": -1}
		"cancel":
			await _keyboard(KEY_ESCAPE)
		"rebuild":
			app._refresh_hand()
			await _frames()
			_check(not presenter._bindings.has(panel), "old physical copy unbound")
		"turn":
			app.deck.combat_state.player_turn_active = false
	await _frames()
	_guard_global()
	var before := _state()
	var quote: Dictionary = presenter._target_preview(id)
	if scenario in ["dead", "defender"]:
		_check(quote.playable and not quote.target_positions.has(2), "invalid target excluded, living target retained")
	elif scenario not in ["cancel", "rebuild"]:
		_check(not quote.playable, "service preflight refuses " + scenario)
	var current := _panel(id)
	if current != null and scenario not in ["dead", "defender", "cancel", "rebuild"]:
		_check(not app.get_node("LiveSupportHand")._metadata.visual_state(current).get("playable", false), "invalid face dimmed " + scenario)
	await _keyboard(KEY_2)
	await _click(app.get_node("LiveEnemyRoster")._labels[1])
	_check(_state() == before, "both physical input refusals wholly inert " + scenario)
	_check_global()
	await _return()


func _receipts() -> void:
	var id: String = TOSSES[2]
	if not await _start(id):
		return
	var panel := _panel(id)
	await _click(panel)
	_guard_global()
	for issue in ["target", "hand", "index", "deck", "map", "turn", "token", "session"]:
		var before := _state()
		var last: Dictionary = presenter.last_event.duplicate(true)
		var session: Array = presenter._session.duplicate()
		presenter._armed = panel
		presenter._queued = true
		if issue == "session":
			presenter._session = []
		presenter._commit(panel, id, 2, presenter._token - (1 if issue == "token" else 0),
			app.party, app.enemies, app.battle_result, app.run_rng,
			presenter._turn + (1 if issue == "turn" else 0),
			"replaced_enemy" if issue == "target" else app.enemies.get_enemy(2).id,
			panel.get_index() + (1 if issue == "index" else 0),
			null if issue == "deck" else app.deck,
			[] if issue == "hand" else app.deck.hand.duplicate(),
			RefCounted.new() if issue == "map" else app.run_map, presenter._pinned)
		_check(_state() == before and presenter.last_event == last, "stale receipt inert " + issue)
		presenter._session = session
		presenter._queued = false
	_check_global()
	await _return()


func _route_action(id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	_check(false, "required connected control exists: " + id)
	return null


func _quick_fixture() -> Dictionary:
	for value in range(1, 300):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			for next in map.get_node(first).outgoing:
				if map.get_node(next).type != "Fight":
					continue
				map.choose_node(first)
				var entry := RunAuthoredBattleEntry.new().entry_current_battle(
					map, rng, RunFightEncounterSelection.new())
				if entry.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": first, "path": [next]}
				map.undo_choice(first, [])
	return {}


func _bind_needle(owner: String = "warden") -> bool:
	var definitions: Array = RunAuthoredPatchDefinitions.load_definitions()
	_check(definitions.any(func(item): return item.get("id") == "needle_echo" and item.get("slot") == "HEAD"),
		"authored Needle Echo HEAD record exists")
	app.run_trinkets.append("needle_echo")
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or not carry.is_valid():
		return false
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	if not wardrobe.is_valid():
		return false
	var sewn: Dictionary = wardrobe.sew("needle_echo", owner, "HEAD",
		"live_needle_echo_sew", wardrobe.get_snapshot())
	var expected := wardrobe.get_snapshot()
	_check(sewn.get("ok", false) and expected.worn[owner].HEAD == "needle_echo"
		and carry.can_bind_wardrobe(wardrobe, carry.torn, expected)
		and carry.bind_wardrobe(wardrobe, carry.torn, expected),
		"authentic worn HEAD Needle receipt bound to actual carryover")
	return sewn.get("ok", false) and carry._wardrobe == wardrobe


func _enter_needle_fight(fixture: Dictionary, pool_cards: Array[String] = []) -> bool:
	app.heirloom_unlocked = true
	app.run_seed = fixture.seed
	await _click(app.route_button)
	await _click(_route_action(fixture.fight))
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999), "settle predecessor")
	app._observe_battle_result()
	await _frames()
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	_check(app.route_view != null and app.party_carryover is RunTornCarryover,
		"route view ready for needle sewing")
	if not _bind_needle("warden"):
		return false
	for card_id in pool_cards:
		app.run_deck.append(card_id)
		app.run_deck.append(card_id)
	await _click(_route_action(fixture.path.back()))
	await _frames()
	_check(app.battle_view != null and app.battle_view.is_visible_in_tree()
		and app.deck != null and app.deck.turn_active,
		"second Fight entered with sewn Needle Echo")
	return app.battle_view != null and app.deck != null


func _draw_to_hand(id: String) -> bool:
	if not app.deck.hand.has(id):
		app.deck.draw_pile.append(id)
		_check(app.deck.draw_extra(1) == 1, "card drawn to hand: " + id)
		app._refresh_hand()
		await _frames()
	return app.deck.hand.has(id)


func _test_heirloom_toss_suite() -> void:
	var fixture := _quick_fixture()
	_check(not fixture.is_empty(), "quick fixture found")
	if fixture.is_empty():
		return
	if not await _enter_needle_fight(fixture, [TOSSES[2], TOSSES[3]]):
		_check(false, "failed to enter needle fight")
		return
	var hand = app.get_node("LiveSupportHand")
	var rules: CombatHeirloomPatchTriggers = hand._heirloom
	_check(rules != null and rules._party == app.party
		and rules._enemies == app.enemies and rules._pinned == presenter._pinned,
		"AC1: Heirloom triggers active in live support hand")

	# Setup: Pin Enemy 1, grant Warden 5 Block, apply Weak(1) to Warden, Exposed(1) to Enemy 1.
	# Enemy 1 has 4 Block, 30 HP.
	_check(presenter._pinned.pin_enemy(app.enemies, 1, "warden"), "pinned enemy 1")
	app.party._heroes[0].block = 0
	_check(app.party.gain_block(1, 5), "warden holds 5 block")
	app.party._heroes[0]["statuses"] = {"weak": 1}
	app.enemies._enemies[0].block = 0
	_check(app.enemies.gain_block(1, 4), "enemy 1 holds 4 block")
	app.enemies._enemies[0]["statuses"] = {"exposed": 1}

	# --- AC1/AC2: Starter plus card (warden_v3_rim_toss_plus, +2 bonus) via Mouse Click ---
	var toss_plus: String = TOSSES[1]
	_check(await _draw_to_hand(toss_plus), "drawn toss plus to hand")
	var forecast: Dictionary = presenter._resolve_attack(app.party, app.enemies, toss_plus, 0, true)
	var hit1: Dictionary = {}
	for h in forecast.get("hits", []):
		if h.get("position") == 1:
			hit1 = h
	_check(forecast.playable and hit1.get("damage") == 7,
		"AC1: toss forecast previews base 7 damage without latching needle quote")
	_check(rules._needle_used == false, "AC1: forecast did NOT consume Needle Echo latch")

	var enemy_block_before: int = app.enemies.get_enemy(1).block
	var enemy_hp_before: int = app.enemies.get_enemy(1).hp
	var energy_before: int = app.deck.energy

	_guard_global()
	var panel := _panel(toss_plus)
	_check(panel != null and presenter._eligible(panel), "toss plus panel eligible")
	await _click(panel)
	_check(presenter._armed == panel, "mouse armed toss plus")
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	await _frames()

	# With Needle Echo: raw 5 + 2 + 1 = 8; floor(8 * 1.125) = 9!
	# 4 absorbed by Block, 5 dealt to HP.
	_check(presenter.last_event.damage == 9, "AC2: committed damage is 9 (status applied to raw+1)")
	_check(presenter.last_event.block_absorbed == 4, "AC2: 4 absorbed by enemy Block")
	_check(presenter.last_event.hp_loss == 5, "AC2: 5 lost from enemy HP")
	_check(app.enemies.get_enemy(1).block == enemy_block_before - 4, "AC2: enemy Block reduced by 4")
	_check(app.enemies.get_enemy(1).hp == enemy_hp_before - 5, "AC2: enemy HP reduced by 5")
	_check(app.party.get_hero(1).block == 5, "AC2: Warden Block never spent")
	_check(app.deck.energy == energy_before - 1, "AC2: exactly 1 energy charged")
	_check(app.deck.discard_pile.has(toss_plus), "AC2: card discarded")
	_check_global()
	_check(rules._needle_used == true, "AC3: positive-contact hit consumed Needle Echo")

	# --- AC3: Second paid toss same turn receives NO repeat +1 (keyboard confirm) ---
	var toss_base: String = TOSSES[0] # warden_v3_rim_toss
	_check(await _draw_to_hand(toss_base), "drawn base rim toss to hand")
	app.deck.combat_state.energy = 2
	# Enemy 1 has 0 block now. Raw = 5 + 0 = 5. floor(5 * 1.125) = 5.
	enemy_hp_before = app.enemies.get_enemy(1).hp
	_check(await _key_select(toss_base), "keyboard armed base rim toss")
	await _keyboard(KEY_1)
	await _frames()
	_check(presenter.last_event.damage == 5, "AC3: second toss receives NO repeat +1 (5 damage, not 6)")
	_check(presenter.last_event.hp_loss == 5, "AC3: 5 damage to HP")
	_check(app.enemies.get_enemy(1).hp == enemy_hp_before - 5, "AC3: enemy HP decreased by 5")
	_check(rules._needle_used == true, "AC3: needle latch remains used")

	# --- AC3: Turn boundary restores Needle Echo ---
	await _click(app.end_turn_button)
	await _frames()
	_check(app.deck.turn_active and app.enemy_intents._turn_index > 0, "next turn active")
	rules = hand.current_attack_heirloom(app.deck, app.party)
	_check(rules != null and not rules._needle_used, "AC3: next player turn restored Needle Echo latch")

	# --- AC3: Zero-contact hit does NOT consume Needle Echo ---
	_check(presenter._pinned.pin_enemy(app.enemies, 1, "warden"), "re-pin enemy 1")
	app.party._heroes[0].block = 0
	app.party._heroes[0]["statuses"] = {"weak": 1}
	app.enemies._enemies[0]["statuses"] = {}
	_check(await _draw_to_hand(toss_base), "drawn base toss")
	# Raw with needle: 0 + 0 + 1 = 1. Weak: floor(1 * 0.75) = 0.
	panel = _panel(toss_base)
	await _click(panel)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	await _frames()
	_check(presenter.last_event.damage == 0, "AC3: hit dealt 0 damage")
	_check(rules._needle_used == false, "AC3: zero-contact hit did NOT consume Needle Echo")

	# --- AC3: Fully Block-absorbed hit DOES consume Needle Echo ---
	app.party._heroes[0].block = 0
	_check(app.party.gain_block(1, 6), "warden holds 6 block")
	app.party._heroes[0]["statuses"] = {}
	app.enemies._enemies[0]["statuses"] = {}
	_check(app.enemies.gain_block(1, 25), "enemy 1 holds 25 block")
	var toss_pool: String = TOSSES[2] # warden_v3_shield_toss
	_check(await _draw_to_hand(toss_pool), "drawn shield toss")
	# Raw with needle: 6 + 0 + 1 = 7. All 7 absorbed by enemy Block.
	enemy_block_before = app.enemies.get_enemy(1).block
	enemy_hp_before = app.enemies.get_enemy(1).hp
	panel = _panel(toss_pool)
	await _click(panel)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	await _frames()
	_check(presenter.last_event.damage == 7, "AC3: damage is 7")
	_check(presenter.last_event.block_absorbed == 7 and presenter.last_event.hp_loss == 0,
		"AC3: all 7 absorbed by enemy Block")
	_check(app.enemies.get_enemy(1).block == enemy_block_before - 7, "AC3: enemy Block reduced by 7")
	_check(app.enemies.get_enemy(1).hp == enemy_hp_before, "AC3: enemy HP untouched")
	_check(rules._needle_used == true, "AC3: fully Block-absorbed hit consumed Needle Echo")

	# --- Pool upgraded card: warden_v3_shield_toss_plus in subsequent turn ---
	await _click(app.end_turn_button)
	await _frames()
	rules = hand.current_attack_heirloom(app.deck, app.party)
	_check(rules != null and not rules._needle_used, "turn boundary reset needle")
	_check(presenter._pinned.pin_enemy(app.enemies, 1, "warden"), "re-pin enemy 1")
	app.party._heroes[0].block = 0
	_check(app.party.gain_block(1, 7), "warden holds 7 block")
	app.party._heroes[0]["statuses"] = {}
	app.enemies._enemies[0]["statuses"] = {}
	app.enemies._enemies[0].block = 0
	app.enemies._enemies[0].hp = 18
	var toss_pool_plus: String = TOSSES[3] # warden_v3_shield_toss_plus (+3 bonus)
	_check(await _draw_to_hand(toss_pool_plus), "drawn shield toss plus")
	# Raw with needle: 7 + 3 + 1 = 11. All to HP.
	enemy_hp_before = app.enemies.get_enemy(1).hp
	panel = _panel(toss_pool_plus)
	await _click(panel)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	await _frames()
	_check(presenter.last_event.damage == 11, "AC2/AC3: pool plus toss deals 11 (7 + 3 + 1)")
	_check(presenter.last_event.hp_loss == 11, "AC2: 11 damage to HP")
	_check(app.enemies.get_enemy(1).hp == enemy_hp_before - 11, "AC2: enemy HP reduced by 11")
	_check(rules._needle_used == true, "AC3: needle consumed")

	await _click(app.return_button)
	await _frames()
	_check(app.deck == null, "returned to title")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	_check(presenter != null and app.deck == null, "real mounted title and battle presenter")
	if presenter != null:
		await _test_heirloom_toss_suite()
		for index in range(TOSSES.size()):
			await _toss_play(TOSSES[index], false, 1, 7, false)
			await _toss_play(TOSSES[index], true, 3, 5, true)
		await _toss_play(TOSSES[0], true, 2, 0, false)
		for scenario in ["energy", "downed", "from", "dead", "absent", "statuses", "defender", "cancel", "rebuild", "turn"]:
			await _refusal(scenario)
		await _receipts()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_warden_v3_shield_toss_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
