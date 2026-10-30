extends "res://tests/live_warden_pool_heavy_hand_test.gd"
## Real app.tscn hand input and detached paid-service oracle for both Rivet printings.

const RIVETS := ["warden_v3_rivet_pummel", "warden_v3_rivet_pummel_plus"]


func _snapshot() -> Dictionary:
	return {"game": _state(), "pins": presenter._pinned._pinner_by_position.duplicate(true)}


func _oracle_rivet(id: String, position: int, before: Dictionary) -> Dictionary:
	var snapshot: Array = before.game
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
	var pinned := CombatPinned.new()
	pinned._pinner_by_position = before.pins.duplicate(true)
	var event := CombatWardenV3RivetCards.new().play_card(deck, party, enemies,
		pinned, id, position)
	if event.get("ok", false):
		# The mounted presenter adds original positions for downstream observers.
		for hit in event.hits:
			hit["position"] = position
	return {"event": event, "draw": deck.draw_pile, "hand": deck.hand,
		"discard": deck.discard_pile, "energy": deck.energy,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"pins": pinned._pinner_by_position.duplicate(true), "seed": rng.seed, "rng": rng.state}


func _successful(id: String, position: int, middle: bool, keyboard: bool,
		scenario: String = "") -> void:
	if not await _start(id):
		return
	if middle:
		var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
		_check(swap.ok, "Warden can move to legal middle seat")
		if swap.ok:
			app.party._heroes.assign(swap.heroes)
	var seat := 2 if middle else 1
	_check(app.party.get_hero(seat).id == "warden"
		and app.party.get_hero(seat).hp > 0, "genuine living owner in seat 1 or 2")
	_check(app.enemies.get_enemy(position).hp > 0, "genuine living original enemy slot")
	if scenario == "weak_exposed":
		app.party._heroes[seat - 1]["statuses"] = {"weak": 1}
		_check(app.enemies.apply_statuses({position: {"exposed": 1}})
			and app.enemies.gain_block(position, 4), "seed real Weak, Exposed and Block")
	elif scenario == "cross":
		_check(presenter._pinned.pin_enemy(app.enemies, position, "seamstress"),
			"independent other-hero Pin exists before cast")
	elif scenario == "same":
		_check(presenter._pinned.pin_enemy(app.enemies, position, "warden"),
			"same-hero Pin exists before cast")
	elif scenario == "lethal":
		var remaining: int = int(app.enemies.get_enemy(position).hp)
		_check(remaining > 2 and app.enemies.apply_damage(position, remaining - 2),
			"first-strike lethal precondition with two HP")
	elif scenario == "block":
		_check(app.enemies.gain_block(position, 5), "real Block exceeds first printed hit")
	elif scenario == "copies":
		app.deck.draw_pile.append(id)
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.count(id) == 2,
			"two physically drawn copies before one cast")
		app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and presenter._eligible(panel), "real physical Rivet panel eligible")
	var definition: Dictionary = presenter._definition(id)
	_check(definition.get("id") == id and definition.get("owner") == "warden"
		and definition.get("cost") == 2 and definition.get("target_kind") == "enemy_single"
		and definition.get("from_positions") == [1, 2]
		and definition.get("to_positions") == [1, 2]
		and definition.get("effects", {}).get("hits") == 2
		and definition.get("effects", {}).get("pinned") == true,
		"authenticated canonical two-hit 2-energy Pin printing")
	if keyboard:
		_check(await _key_select(id), "keyboard P selects the actual held Rivet card")
	else:
		await _click(panel)
	_check(presenter._armed == panel and presenter._eligible(panel),
		"physical card actually selected")
	var before := _snapshot()
	var quote: Dictionary = presenter._target_preview(id)
	var oracle := _oracle_rivet(id, position, before)
	_check(oracle.event.get("ok", false), "detached paid Rivet oracle accepts authentic fixture")
	_check(quote.playable and quote.requires_selection
		and quote.target_positions.has(position)
		and not quote.target_positions.has(3)
		and presenter.current_forecast == quote,
		"live read-only per-slot forecast offers exact target window")
	if oracle.event.get("ok", false):
		var forecast_hit: Dictionary = {}
		for hit in quote.hits:
			if hit.position == position:
				forecast_hit = hit
		_check(not forecast_hit.is_empty(), "selected slot has an actual forecast record")
		if not forecast_hit.is_empty():
			var event: Dictionary = oracle.event
			_check(forecast_hit.hit_count == event.hit_count
				and forecast_hit.first_damage == event.hits[0].damage
				and forecast_hit.second_damage == (event.hits[1].damage if event.hit_count > 1 else 0)
				and forecast_hit.hp_after == event.target_hp
				and forecast_hit.block_after == event.target_block
				and forecast_hit.applies_pinned == event.pinned
				and forecast_hit.pin_bonus == event.hits[0].pin_bonus,
				"independent oracle proves two strikes, Block, HP, lethal stop and Pin rider")
	_check(presenter.cue.text.contains(" | 2 energy")
		and presenter.cue.text.contains("Two printed hits")
		and presenter.cue.text.contains("Pin survivor"),
		"visible strip explains cost, strikes and Pin")
	if scenario == "weak_exposed":
		_check(presenter.cue.text.contains("Weak 1")
			and presenter.cue.text.contains("Exposed 1"),
			"visible quote identifies real attacking and defending statuses")
	_check(_snapshot() == before, "all hover, selection and forecast paths are state/RNG pure")
	if keyboard:
		await _keyboard(KEY_1 + position - 1)
	else:
		var labels: Array = app.get_node("LiveEnemyRoster")._labels
		_check(labels.size() >= position, "actual clickable enemy slot exists")
		if labels.size() >= position:
			await _click(labels[position - 1])
	_check(presenter.last_event == oracle.event, "mounted receipt equals detached paid resolver plus positions")
	_check(app.party.get_heroes() == oracle.heroes
		and app.enemies.get_enemies() == oracle.enemies
		and presenter._pinned._pinner_by_position == oracle.pins,
		"mounted complete actors and shared Pin map equal detached oracle")
	_check(app.deck.hand == oracle.hand and app.deck.discard_pile == oracle.discard
		and app.deck.draw_pile == oracle.draw and app.deck.energy == oracle.energy,
		"mounted exact piles and energy match detached oracle")
	_check(app.deck.energy == int(before.game[3]) - 2
		and app.deck.hand.count(id) == int(before.game[1].count(id)) - 1
		and app.deck.discard_pile.count(id) == int(before.game[2].count(id)) + 1,
		"one payment and exactly one held copy discarded")
	_check(app.deck._rng == app.run_rng and app.deck._rng.seed == oracle.seed
		and app.deck._rng.state == oracle.rng and app.deck._rng.state == int(before.game[12]),
		"seeded run RNG untouched through confirmed attacks")
	_check(presenter.last_event.get("ok", false) and presenter.last_event.hits.size() > 0,
		"confirmed play publishes nonvacuous hit receipts")
	if presenter.last_event.get("ok", false):
		for hit in presenter.last_event.hits:
			_check(hit.position == position and hit.damage > 0
				and hit.hp_loss >= 0 and hit.block_absorbed >= 0,
				"each confirmed strike carries original target position once")
	var after := _snapshot()
	await _keyboard(KEY_1 + position - 1)
	_check(_snapshot() == after, "consumed pending choice cannot replay")
	_check(app.deck.turn_active and app.battle_result.can_continue()
		and is_instance_valid(app.hand_view) and presenter._deck == app.deck,
		"real post-cast refresh keeps genuine battle playable")
	# Exercise real subsequent end-turn/hand refresh once, not only a rules service.
	if scenario == "block":
		var turn_before: int = app.enemy_intents._turn_index
		await _click(app.end_turn_button)
		_check(app.deck != null and app.enemy_intents._turn_index > turn_before
			and is_instance_valid(app.hand_view) and presenter._deck == app.deck,
			"real End Turn advances phase and mounts refreshed next hand")
	await _return()


func _refusal(id: String, scenario: String) -> void:
	if not await _start(id):
		return
	var panel := _panel(id)
	await _click(panel)
	_check(presenter._armed == panel, "refusal starts from real selected card " + scenario)
	var target := 2
	match scenario:
		"energy_zero", "energy_one":
			app.deck.combat_state.energy = 0 if scenario == "energy_zero" else 1
			_check(app.deck.energy < 2, "actual energy underfunded")
		"unheld":
			_check(app.deck.discard_played(id) and not app.deck.hand.has(id),
				"real held copy removed")
		"downed":
			_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1),
				"owner genuinely downed")
		"seat3":
			app.party._heroes.reverse()
			for index in range(3):
				app.party._heroes[index].position = index + 1
			_check(app.party.is_valid() and app.party.get_hero(3).id == "warden",
				"living Warden genuinely in forbidden third seat")
		"dead":
			_check(app.enemies.apply_damage(2, 10000) and app.enemies.is_slain(2),
				"original target genuinely dead")
		"third":
			_third_enemy()
			target = 3
			_check(app.enemies.get_enemy(3).hp > 0, "third-slot target genuinely alive")
		"bad_owner_status":
			app.party._heroes[0]["statuses"] = {"weak": -1}
		"bad_enemy_status":
			app.enemies._enemies[1]["statuses"] = {"cannot_buff_next_turn": false}
		"bad_pin":
			presenter._pinned._pinner_by_position[2] = "unknown"
		"cancel":
			await _keyboard(KEY_ESCAPE)
			_check(presenter._armed == null, "Escape cancelled pending selection")
		"rebuild":
			app._refresh_hand()
			await _frames()
			_check(not presenter._bindings.has(panel), "stale hand panel really retired")
		"turn":
			app.deck.combat_state.player_turn_active = false
		"battle":
			app._battle_closed = true
	await _frames()
	var before := _snapshot()
	var last: Dictionary = presenter.last_event.duplicate(true)
	var quote: Dictionary = presenter._target_preview(id)
	if scenario in ["dead", "third"]:
		_check(quote.playable and not quote.target_positions.has(target),
			"living other targets remain but illegal original slot excluded")
	elif scenario not in ["cancel", "rebuild"]:
		_check(not quote.playable, "invalid full transaction preflight refuses " + scenario)
	await _keyboard(KEY_1 + target - 1)
	var labels: Array = app.get_node("LiveEnemyRoster")._labels
	if labels.size() >= target:
		await _click(labels[target - 1])
	_check(_snapshot() == before and presenter.last_event == last,
		"refused physical keyboard/pointer input never spends or mutates " + scenario)
	if scenario == "battle":
		app._battle_closed = false
	await _return()


func _stale_receipts(id: String) -> void:
	if not await _start(id):
		return
	var panel := _panel(id)
	await _click(panel)
	_check(presenter._armed == panel and app.enemies.get_enemy(2).hp > 0,
		"queued receipt has genuine live panel and target identity")
	for issue in ["target", "hand", "index", "deck", "map", "turn", "token", "session", "pin"]:
		var before := _snapshot()
		var last: Dictionary = presenter.last_event.duplicate(true)
		var original_session: Array = presenter._session.duplicate()
		presenter._armed = panel
		presenter._queued = true
		if issue == "session":
			presenter._session = []
		presenter._commit(panel, id, 2,
			presenter._token - (1 if issue == "token" else 0),
			app.party, app.enemies, app.battle_result, app.run_rng,
			presenter._turn + (1 if issue == "turn" else 0),
			"replacement" if issue == "target" else app.enemies.get_enemy(2).id,
			panel.get_index() + (1 if issue == "index" else 0),
			null if issue == "deck" else app.deck,
			[] if issue == "hand" else app.deck.hand.duplicate(),
			RefCounted.new() if issue == "map" else app.run_map,
			null if issue == "pin" else presenter._pinned)
		_check(_snapshot() == before and presenter.last_event == last,
			"stale " + issue + " callback cannot spend, consume Pin or publish")
		presenter._session = original_session
		presenter._queued = false
	await _keyboard(KEY_ESCAPE)
	var cancelled := _snapshot()
	await _keyboard(KEY_2)
	_check(_snapshot() == cancelled, "cancelled queued receipt stays inert")
	await _return()


## Replace the actual foe identity between selection and a queued confirmation.
## A fresh valid enemy occupying the same slot must not inherit the old receipt.
func _replaced_identity(id: String) -> void:
	if not await _start(id):
		return
	var panel := _panel(id)
	await _click(panel)
	var old_id: String = app.enemies.get_enemy(2).id
	_check(not old_id.is_empty() and presenter._target_preview(id).target_positions.has(2),
		"replacement fixture begins with a real eligible original foe")
	app.enemies._enemies[1]["id"] = "replacement_for_rivet"
	_check(app.enemies.is_valid() and app.enemies.get_enemy(2).id != old_id,
		"enemy is genuinely replaced at the same original slot")
	var before := _snapshot()
	var last: Dictionary = presenter.last_event.duplicate(true)
	presenter._armed = panel
	presenter._queued = true
	presenter._commit(panel, id, 2, presenter._token,
		app.party, app.enemies, app.battle_result, app.run_rng,
		presenter._turn, old_id, panel.get_index(), app.deck,
		app.deck.hand.duplicate(), app.run_map, presenter._pinned)
	_check(_snapshot() == before and presenter.last_event == last,
		"replaced enemy identity rejects pending hit without payment, Pin or RNG")
	app.enemies._enemies[1]["id"] = old_id
	await _return()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "genuine app scene available")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	_check(presenter != null and app.deck == null, "live presenter starts on title")
	if presenter != null:
		for id in RIVETS:
			await _successful(id, 1, false, false, "block")
			await _successful(id, 2, true, true, "weak_exposed")
			await _successful(id, 2, false, false, "cross")
			await _successful(id, 1, true, true, "same")
			await _successful(id, 2, false, true, "lethal")
		await _successful(RIVETS[0], 1, false, false, "copies")
		for scenario in ["energy_zero", "energy_one", "unheld", "downed", "seat3",
				"dead", "third", "bad_owner_status", "bad_enemy_status", "bad_pin",
				"cancel", "rebuild", "turn", "battle"]:
			await _refusal(RIVETS[0] if scenario in ["energy_zero", "unheld", "dead",
				"third", "bad_owner_status", "cancel", "turn"] else RIVETS[1], scenario)
		await _stale_receipts(RIVETS[0])
		await _stale_receipts(RIVETS[1])
		await _replaced_identity(RIVETS[0])
		await _replaced_identity(RIVETS[1])
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_warden_v3_rivet_pummel_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
