extends "res://tests/live_support_hand_test.gd"
## Mounted status-only Rag Duelist Snare: real hand/picker, authentic paid resolver,
## original enemy slots, no speculative damage and fail-closed deferred input.

const IDS := ["rag_duelist_tattered_snare", "rag_duelist_tattered_snare_plus"]
const ADDED := [2, 3]


func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 372
	_check(app._start_battle(), "real battle opens")
	presenter = app.get_node("LiveAttackPreview")
	var rng := RandomNumberGenerator.new()
	rng.seed = 372
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two authentic drawn copies")
	app.deck.combat_state.energy = 1
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "rag_duelist", "name": "Rag Duelist", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "front", "max_hp": 30, "statuses": {"tangled": 2, "bleed": 1}},
		{"id": "middle", "max_hp": 40, "statuses": {"tangled": 1, "exposed": 1}},
		{"id": "back", "max_hp": 50, "statuses": {"weak": 2}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "genuine populated rosters")
	_check(app.enemies.gain_block(2, 5), "middle enemy begins with Block")
	for position in [1, 2, 3]:
		_check(app.party.apply_damage(position, position) and app.party.gain_block(position, position + 1),
			"distinct living hero HP and Block")
	_check(app.party.get_hero(seat).id == "rag_duelist" and app.party.get_hero(seat).hp > 0
		and app.enemies.get_enemy(2).block == 5, "non-vacuous owner and target preconditions")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"real held Snare panel owns the mounted input callback")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.battle_result.get_outcome(), presenter.last_event.duplicate(true)]


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		await _keyboard(KEY_ESCAPE)
		await _keyboard(KEY_P)
	else:
		await _mouse(panel)
	_check(presenter._armed == panel, "original hand instance armed")


func _success(id: String, seat: int, target: int, keyboard: bool) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	var added: int = ADDED[IDS.find(id)]
	var metadata = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = metadata.get_facts(panel)
	_check(facts.get("known", false) and facts.get("cost") == 1 and facts.get("owner") == "rag_duelist"
		and metadata.definition(id) == presenter._snare._catalog_definition(id)
		and metadata.short_line(id) == "Tangled %d." % added
		and metadata.visual_state(panel).get("playable", false),
		"catalog face, exact Tangled count and service-backed enabled state")
	var before := _state()
	await _hover(panel)
	var quote: Dictionary = presenter.current_forecast.duplicate(true)
	_check(quote.get("playable", false) and quote.get("requires_selection", false)
		and quote.get("target_positions", []) == [1, 2, 3] and quote.get("targets", []).size() == 3
		and presenter.cue.text.contains("Tangled")
		and presenter.cue.text.contains("1 energy") and not presenter.cue.text.contains("damage"),
		"pure original-slot status forecast, without fabricated hit")
	if quote.get("targets", []).size() == 3:
		_check(quote.targets[target - 1].tangled_added == added
			and quote.targets[target - 1].tangled_after ==
			int(app.enemies.get_enemy(target).get("statuses", {}).get("tangled", 0)) + added,
			"preflight computes the exact additive Tangled forecast")
	_check(_state() == before, "hover leaves all resources, actors and RNG untouched")
	await _arm(panel, keyboard)
	_check(_state() == before, "arming never mutates combat")
	var enemies_before: Array = app.enemies.get_enemies()
	var heroes_before: Array = app.party.get_heroes()
	var hand: Array = app.deck.hand.duplicate()
	var discard: Array = app.deck.discard_pile.duplicate()
	var draw: Array = app.deck.draw_pile.duplicate()
	var rng_state: int = app.run_rng.state
	var pin_before: Dictionary = presenter._pinned._pinner_by_position.duplicate(true)
	# A genuine existing pin must not be consumed by a non-attack cast.
	_check(presenter._pinned.pin_enemy(app.enemies, target, "warden"), "seed actual Pinned token")
	pin_before = presenter._pinned._pinner_by_position.duplicate(true)
	var callback: Callable = presenter._bindings[panel].input
	var replay_args: Array = [panel, id, target, presenter._token, app.party, app.enemies,
		app.battle_result, app.run_rng, presenter._turn, app.enemies.get_enemy(target).id,
		panel.get_index(), app.deck, app.deck.hand.duplicate(), app.run_map,
		presenter._pinned, presenter._unravel]
	if keyboard:
		await _keyboard(KEY_1 if target == 1 else KEY_2 if target == 2 else KEY_3)
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])
	var receipt: Dictionary = presenter.last_event
	_check(receipt.get("ok", false) and receipt.get("card_id") == id
		and receipt.get("cost") == 1 and receipt.get("target_position") == target
		and receipt.get("owner_position") == seat and receipt.get("tangled_added") == added
		and not receipt.has("damage") and not receipt.has("hits"),
		"one genuine status-only paid resolver receipt")
	var target_statuses: Dictionary = enemies_before[target - 1].get("statuses", {}).duplicate()
	target_statuses["tangled"] = int(target_statuses.get("tangled", 0)) + added
	enemies_before[target - 1]["statuses"] = target_statuses
	hand.erase(id)
	discard.append(id)
	_check(app.enemies.get_enemies() == enemies_before and app.party.get_heroes() == heroes_before,
		"exact target stack added; other statuses, enemies, HP, Block, positions and heroes unchanged")
	_check(app.deck.energy == 0 and app.deck.hand == hand and app.deck.discard_pile == discard
		and app.deck.draw_pile == draw and app.run_rng.state == rng_state
		and presenter._pinned._pinner_by_position == pin_before,
		"one spend and discard, no RNG draw or Pinned consumption")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [draw.size(), discard.size()]
		and app.get_node("LiveSupportHand").energy_label.text == "0" and _pool_panel(id) != null,
		"post-cast live HUD and surviving duplicate panel refreshed")
	var settled := _state()
	callback.call(_press())
	presenter._commit.callv(replay_args)
	presenter._queue_attack(target)
	await _frames()
	_check(_state() == settled and presenter._armed == null,
		"retired hand instance and duplicate input cannot pay or apply twice")
	await _dispose()


func _refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0], 3 if mode == "seat" else 2)
	if panel == null:
		await _dispose()
		return
	var metadata = app.get_node("LiveSupportHand")._metadata
	if mode != "seat":
		await _arm(panel, true)
	if queued and mode != "seat" and mode != "bad_slot":
		presenter._queue_attack(1)
		_check(presenter._queued, "real original target queued before stale transition: " + mode)
	match mode:
		"seat":
			_check(not metadata.visual_state(panel).get("playable", false)
				and not presenter._target_preview(IDS[0]).get("playable", false),
				"seat three cannot offer a status cast")
		"downed": app.party.apply_damage(2, 999)
		"energy": app.deck.combat_state.energy = 0
		"dead": app.enemies.apply_damage(1, 999)
		"overflow": app.enemies._enemies[0].statuses["tangled"] = CombatStatuses.MAX_INT
		"bad_slot": pass
		"owner": app.party._heroes[1].id = "other"
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"hand_order": app.deck.hand.reverse()
		"target_id": app.enemies._enemies[0].id = "new_enemy"
		"target_missing":
			app.enemies = CombatEnemies.new([{"id": "replacement", "max_hp": 35}])
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"party": app.party = CombatParty.new([{"id":"warden","max_hp":30}, {"id":"rag_duelist","max_hp":30}])
		"turn": app.enemy_intents.advance_turn()
		"closed": app._battle_closed = true
		"hidden": app.battle_view.hide()
		"inactive": app.deck.combat_state.player_turn_active = false
		"rng":
			app.run_rng = RandomNumberGenerator.new()
			app.run_rng.seed = 373
		"deck":
			app.deck = CombatDeck.new([IDS[0]], app.run_rng)
			app.deck.start_turn()
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = IDS[1]
		"cancel": await _keyboard(KEY_ESCAPE)
	if mode in ["energy", "downed", "owner"]:
		metadata._update_visual(panel)
		_check(not metadata.visual_state(panel).get("playable", false)
			and not presenter._target_preview(IDS[0]).get("playable", false),
			"affordability and living-owner failures dim the genuine card: " + mode)
	var before := _state()
	if mode == "bad_slot":
		presenter._queue_attack(0)
		presenter._queue_attack(4)
	elif not queued and mode != "seat":
		await _keyboard(KEY_1)
	elif mode == "seat":
		await _mouse(panel)
		await _keyboard(KEY_1)
	await _frames()
	_check(_state() == before, "no mutation or payment for " + mode + " queued=" + str(queued))
	if mode == "bad_slot":
		await _keyboard(KEY_ESCAPE)
	var settled := _state()
	presenter._queue_attack(1)
	await _frames()
	_check(_state() == settled, "rejected target cannot later replay " + mode)
	await _dispose()


func _dead_slot_keeps_identity() -> void:
	var panel := await _begin(IDS[1], 1)
	if panel == null:
		await _dispose()
		return
	app.enemies.apply_damage(2, 999)
	await _hover(panel)
	_check(presenter.current_forecast.get("target_positions", []) == [1, 3],
		"slain middle enemy omitted without compacting original slots")
	await _arm(panel, true)
	var before := _state()
	await _keyboard(KEY_2)
	_check(_state() == before, "dead slot shortcut inert")
	await _keyboard(KEY_3)
	_check(presenter.last_event.get("ok", false)
		and presenter.last_event.get("target_position") == 3
		and app.enemies.get_enemy(3).get("statuses", {}).get("tangled") == 3,
		"slot three retains its identity and exact plus Tangled")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for seat in [1, 2]:
			for target in [1, 2, 3]:
				for keyboard in [false, true]:
					await _success(id, seat, target, keyboard)
	for mode in ["seat", "downed", "energy", "dead", "overflow", "bad_slot",
		"owner", "hand", "hand_order", "target_id", "target_missing", "session",
		"party", "turn", "closed", "hidden", "inactive", "rng", "deck", "panel", "label", "cancel"]:
		for queued in [false, true]:
			if mode == "target_id" and not queued:
				continue # Replacing an ID before selection is a new, legally selectable foe.
			await _refuse(mode, queued)
	await _dead_slot_keeps_identity()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_rag_duelist_tattered_snare_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
