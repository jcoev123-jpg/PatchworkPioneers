extends "res://tests/live_support_hand_test.gd"
## Real app.tscn hand-to-enemy Button Fist integration, with independent paid oracles.
const IDS := ["button_golem_starter_button_fist", "button_golem_starter_button_fist_plus"]
const PRINTED := [5, 7]
const BLOCK := [2, 3]

## Test-side forgery: a rewritten printed effect is rejected by both mounted faces.
class ForgedFist extends "res://scripts/combat_button_golem_fist_cards.gd":
	var altered: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		if card_id == "button_golem_starter_button_fist":
			return altered.duplicate(true)
		return ButtonGolemStarterCards.new().get_definition(card_id)

func _begin(id: String, seat: int = 1) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 461
	_check(app._start_battle(), "real app.tscn battle entered")
	presenter = app.get_node("LiveAttackPreview")
	var rng := RandomNumberGenerator.new()
	rng.seed = 461
	var cards: Array[String] = [id, "warden_brace", "tinker_tune_up",
		"seamstress_darning", "warden_brace"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.size() == 5
		and app.deck.hand.count(id) == 1, "one authentic Fist held in a real five-card hand")
	var heroes: Array = [
		{"id": "warden", "name": "Warden", "max_hp": 40, "statuses": {}},
		{"id": "tinker", "name": "Tinker", "max_hp": 25, "statuses": {}},
		{"id": "button_golem", "name": "Button Golem", "max_hp": 48,
			"statuses": {"weak": 1}},
	]
	var golem: Dictionary = heroes.pop_back()
	heroes.insert(seat - 1, golem)
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "button_guard", "max_hp": 50, "statuses": {"exposed": 1, "tangled": 2}},
		{"id": "spool_stalker", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "seam_ripper", "max_hp": 50, "statuses": {"exposed": 1}}])
	_check(app.party.is_valid() and app.enemies.is_valid()
		and app.party.get_hero(seat).id == "button_golem"
		and app.enemies.get_enemies().size() == 3, "three genuine original enemy slots, Golem at chosen seat")
	_check(app.enemies.gain_block(2, 3), "middle foe owns 3 Block")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel: Control = _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree()
		and presenter._bindings.has(panel), "physical held panel bound by real LiveAttackPreview")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.battle_result.get_outcome(), presenter.last_event.duplicate(true),
		presenter._pinned._pinner_by_position.duplicate(true) if presenter._pinned != null else {},
		presenter._unravel._gauges.duplicate(true) if presenter._unravel != null else {},
		app.run_seed, app.run_map]


## A second, wholly detached battle with exactly the current deck, actors and seed state.
## Constructor shuffle never advances the MOUNTED RNG, and the copied RNG is reset after it.
func _paid_oracle(id: String, target: int) -> Dictionary:
	var copied_rng := RandomNumberGenerator.new()
	copied_rng.seed = app.run_rng.seed
	var copied_deck := CombatDeck.new(app.deck.hand.duplicate(), copied_rng)
	copied_deck.hand = app.deck.hand.duplicate()
	copied_deck.draw_pile = app.deck.draw_pile.duplicate()
	copied_deck.discard_pile = app.deck.discard_pile.duplicate()
	copied_deck.combat_state.energy = app.deck.energy
	copied_deck.combat_state.player_turn_active = app.deck.turn_active
	copied_rng.state = app.run_rng.state
	var copied_party := CombatParty.new(app.party.get_heroes())
	copied_party._heroes = app.party.get_heroes()
	var copied_enemies := CombatEnemies.new(app.enemies.get_enemies())
	copied_enemies._enemies = app.enemies.get_enemies()
	var paid := CombatButtonGolemFistCards.new().play_card(
		copied_deck, copied_party, copied_enemies, id, target)
	return {"event": paid, "heroes": copied_party.get_heroes(),
		"enemies": copied_enemies.get_enemies(), "hand": copied_deck.hand,
		"draw": copied_deck.draw_pile, "discard": copied_deck.discard_pile,
		"energy": copied_deck.energy, "rng": copied_rng.state}


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		await _keyboard(KEY_ESCAPE)
		await _keyboard(KEY_P)
	else:
		await _mouse(panel)
	_check(presenter._armed == panel, "physical Fist armed by selected input")


func _slot(target: int, keyboard: bool) -> void:
	if keyboard:
		await _keyboard([KEY_1, KEY_2, KEY_3][target - 1])
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])


func _success(id: String, seat: int, target: int, keyboard: bool,
		outcome: String = "ordinary") -> void:
	var panel: Control = await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	if outcome == "absorbed":
		_check(app.enemies.gain_block(target, 100), "full absorption configured")
	elif outcome == "lethal":
		app.enemies._enemies[target - 1].hp = 1
		app.enemies._enemies[target - 1].block = 0
	var index := IDS.find(id)
	var metadata = app.get_node("LiveSupportHand")._metadata
	metadata._update_visual(panel)
	var facts: Dictionary = metadata.get_facts(panel)
	var authored: Dictionary = ButtonGolemStarterCards.new().get_definition(id)
	_check(not authored.is_empty() and metadata.definition(id) == authored
		and presenter._definition(id) == authored, "both mounted faces equal authenticated complete starter record")
	_check(facts.known and facts.owner == "button_golem" and facts.cost == 1
		and facts.from_text.contains("1") and facts.from_text.contains("2")
		and authored.from_positions == [1, 2] and authored.to_positions == [1, 2]
		and authored.target_kind == "enemy_single"
		and panel.gui_input.get_connections().size() == 1
		and metadata.visual_state(panel).playable, "enabled genuine 1-energy face, source/target pips and GUI binding")
	_check(metadata.short_line(id).contains("self Block")
		and metadata.short_line(id).contains(str(BLOCK[index]))
		and metadata.base_effect_text(id).contains("Golem (self) gains %d Block" % BLOCK[index])
		and authored.effects == {"damage": PRINTED[index], "block_self": BLOCK[index]},
		"printed self Block visible, not target damage or healing")
	var before := _state()
	await _hover(panel)
	var preview: Dictionary = presenter.current_forecast.duplicate(true)
	var quote: Dictionary = presenter._target_preview(id)
	_check(preview == quote and preview.get("playable", false)
		and preview.target_positions == [1, 2] and preview.hits.size() == 2
		and preview.owner_position == seat and preview.block_gained == BLOCK[index],
		"read-only picker exactly offers original front and middle")
	_check(presenter.cue.text.contains("Golem gains %d self Block" % BLOCK[index])
		and presenter.cue.text.contains("1 energy"), "live cue publishes self Block and cost")
	var resolver := CombatButtonGolemFistCards.new()
	for position in [1, 2]:
		var preflight: Dictionary = resolver._prepare(app.deck, app.party, app.enemies, id, position)
		var detached: Dictionary = _paid_oracle(id, position)
		var hit: Dictionary = preview.hits[position - 1]
		_check(preflight.get("ok", false) and detached.event.get("ok", false)
			and hit.position == position and hit.damage == detached.event.damage
			and hit.block_absorbed == detached.event.block_absorbed
			and hit.hp_loss == detached.event.hp_loss
			and hit.block_gained == preflight.block_gained
			and hit.block_after == detached.enemies[position - 1].block
			and hit.hp_after == detached.enemies[position - 1].hp,
			"pure per-original-slot forecast equals detached preflight/paid oracle")
	_check(_state() == before, "forecast/hover untouched full battle, piles, gauges and RNG")
	await _arm(panel, keyboard)
	_check(_state() == before, "arming selector is pure")
	await _slot(3, keyboard)
	_check(_state() == before and presenter._armed == panel,
		"third original enemy slot never offered nor paid")
	var expected: Dictionary = _paid_oracle(id, target)
	var target_id: String = app.enemies.get_enemy(target).id
	var old_token: int = presenter._token
	var original_hand: Array = app.deck.hand.duplicate()
	var original_index: int = panel.get_index()
	await _slot(target, keyboard)
	var paid: Dictionary = presenter.last_event
	var detached: Dictionary = expected.event
	_check(paid.get("ok", false) and paid.reason == "applied"
		and paid.card_id == id and paid.owner_position == seat and paid.target_position == target
		and paid.printed_damage == PRINTED[index] and paid.block_gained == BLOCK[index]
		and paid.cost == 1 and paid.energy_spent == 1
		and paid.damage == detached.damage
		and paid.block_absorbed == detached.block_absorbed and paid.hp_loss == detached.hp_loss,
		"one authentic paid Fist receipt, exact adjusted strike and printed self Block")
	_check(paid.get("hits", []).size() == 1 and paid.hits[0].damage == paid.damage,
		"exactly one real confirmed-hit receipt forwarded to observers")
	_check(app.party.get_heroes() == expected.heroes
		and app.enemies.get_enemies() == expected.enemies
		and app.deck.hand == expected.hand and app.deck.draw_pile == expected.draw
		and app.deck.discard_pile == expected.discard and app.deck.energy == expected.energy
		and app.run_rng.state == expected.rng, "one energy/copy spent; detached resolver matches every actor, pile and RNG")
	_check(presenter._armed == null and app.hand_view.get_child_count() == 4
		and app.hand_view.get_child(0).get_child(0) is Label,
		"hand and enemy/party meters refreshed after confirmed hit")
	var settled := _state()
	presenter._commit(panel, id, target, old_token, app.party, app.enemies,
		app.battle_result, app.run_rng, presenter._turn, target_id, original_index,
		app.deck, original_hand, app.run_map, presenter._pinned, presenter._unravel)
	presenter._queue_attack(target)
	await _frames()
	_check(_state() == settled, "retired held copy cannot be paid a second time")
	await _dispose()


func _refuse(mode: String, queued: bool) -> void:
	var seat := 3 if mode == "back_seat" else 1
	var panel: Control = await _begin(IDS[0], seat)
	if panel == null:
		await _dispose()
		return
	if seat != 3:
		await _arm(panel, true)
	else:
		await _frames()
	if queued:
		if seat != 3:
			presenter._queue_attack(1)
			_check(presenter._queued, "real Fist was queued before stale invalidation")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"downed": app.party.apply_damage(1, 999)
		"hand": app.deck.discard_played(IDS[0])
		"hand_order": app.deck.hand.reverse()
		"dead": app.enemies.apply_damage(1, 999)
		"enemy_id": app.enemies._enemies[0].id = "replacement_enemy"
		"slot3": pass
		"back_seat": pass
		"status": app.enemies._enemies[0].statuses = {"weak": -1}
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"turn": app.enemy_intents.advance_turn()
		"panel": app._refresh_hand()
		"battle": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"roster": app.enemies = CombatEnemies.new(app.enemies.get_enemies())
		"rng":
			app.run_rng = RandomNumberGenerator.new()
			app.run_rng.seed = 462
		"label": panel.get_child(0).text = IDS[1]
	var before := _state()
	var meta = app.get_node("LiveSupportHand")._metadata
	if not queued and mode in ["energy", "downed", "back_seat", "hand", "slot3"]:
		if is_instance_valid(panel) and meta._bindings.has(panel):
			meta._update_visual(panel)
		if mode != "slot3":
			_check(not meta.visual_state(panel).get("playable", false),
				"unplayable Fist is dimmed by mounted metadata: " + mode)
	if not queued:
		if mode not in ["enemy_id"]:
			await _slot(3 if mode == "slot3" else 1, true)
	else:
		await _frames()
	_check(_state() == before, "invalid / stale target leaves all state unchanged: %s queued=%s" % [mode, str(queued)])
	if mode != "slot3":
		var settled := _state()
		presenter._queue_attack(1)
		await _frames()
		_check(_state() == settled, "rejected card cannot replay after invalidation: " + mode)
	await _dispose()


func _dead_middle() -> void:
	var panel: Control = await _begin(IDS[1], 2)
	app.enemies.apply_damage(2, 999)
	await _hover(panel)
	_check(presenter.current_forecast.target_positions == [1]
		and presenter.current_forecast.hits.size() == 1
		and presenter.current_forecast.hits[0].position == 1, "slain middle omitted without compacting slot three")
	await _arm(panel, true)
	var before := _state()
	await _slot(2, true)
	await _slot(3, true)
	_check(_state() == before, "dead middle and living rear cannot be struck")
	await _dispose()


func _unknown() -> void:
	var metadata = app.get_node("LiveSupportHand")._metadata
	for id in ["button_golem_starter_button_fist_plus_plus", "button_golem_starter_loose_pop",
			"button_golem_button_knuckle", "button_fist", ""]:
		_check(not presenter._fist.is_supported_card(id)
			and presenter._fist.printed_definition(id).is_empty(),
			"foreign and forged Fist IDs never enter Fist resolver: " + id)
	_check(metadata.definition("button_golem_starter_button_fist_plus_plus").is_empty()
		and presenter._definition("button_golem_starter_button_fist_plus_plus").is_empty(),
		"forged Fist ID has no live card face")


func _forged_record() -> void:
	var panel: Control = await _begin(IDS[0], 1)
	if panel == null:
		await _dispose()
		return
	var forged := ForgedFist.new()
	forged.altered = ButtonGolemStarterCards.new().get_definition(IDS[0])
	forged.altered.effects["damage"] = 99
	_check(forged.printed_definition(IDS[0]).is_empty(),
		"rewritten authored damage is not an authentic Fist printing")
	presenter._fist = forged
	var metadata = app.get_node("LiveSupportHand")._metadata
	metadata._fist = forged
	_check(presenter._definition(IDS[0]).is_empty()
		and metadata.definition(IDS[0]).is_empty()
		and not presenter._target_preview(IDS[0]).playable,
		"forged record cannot enter either mounted face or legal target picker")
	var before := _state()
	await _arm(panel, true)
	await _slot(1, true)
	_check(_state() == before and app.deck.hand.has(IDS[0]),
		"forged mounted held record pays no energy, strike or Block")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for seat in [1, 2]:
			for target in [1, 2]:
				for keyboard in [false, true]:
					await _success(id, seat, target, keyboard)
	for id in IDS:
		await _success(id, 1, 1, true, "absorbed")
		await _success(id, 2, 1, false, "lethal")
	for mode in ["energy", "downed", "hand", "hand_order", "dead", "enemy_id",
			"slot3", "back_seat", "status", "inactive", "closed", "turn",
			"panel", "battle", "roster", "rng", "label"]:
		for queued in [false, true]:
			if (mode == "slot3" and queued) or (mode == "enemy_id" and not queued):
				continue  # Stale identity is only a refusal after a target ID is queued.
			await _refuse(mode, queued)
	await _dead_middle()
	await _forged_record()
	var panel: Control = await _begin(IDS[0])
	if panel != null:
		_unknown()
	await _dispose()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_button_golem_fist_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
