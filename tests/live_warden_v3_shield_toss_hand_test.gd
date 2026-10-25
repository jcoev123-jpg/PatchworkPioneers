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


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	_check(presenter != null and app.deck == null, "real mounted title and battle presenter")
	if presenter != null:
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
