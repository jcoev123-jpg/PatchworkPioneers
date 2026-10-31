extends "res://tests/live_support_hand_test.gd"
## Real App scene / held-card input versus an independent Harvest Fright resolver.
## Covers authored positions, status-adjusted hits, Block, Fear, refusal and replay.

const IDS := ["scarecrow_harvest_fright", "scarecrow_harvest_fright_plus"]


func _begin(id: String, seat: int = 2, dead_rear: bool = false,
		energy: int = 3, last_foe: bool = false) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 406
	_check(app._start_battle(), "shipped App enters real combat")
	presenter = app.get_node_or_null("LiveAreaAttackAction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 406
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.size() == 5
		and app.deck.hand.count(id) == 2 and app.deck.energy == 3,
		"real five-card draw has two genuinely held printings and three energy")
	app.deck.combat_state.energy = energy
	var heroes: Array = [
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "scarecrow", "name": "Scarecrow",
		"max_hp": 34, "statuses": {"weak": 1, "cannot_buff_next_turn": true}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "front", "max_hp": 21, "statuses": {"bleed": 2}},
		{"id": "middle", "max_hp": 30, "statuses": {"exposed": 2, "tangled": 1}},
		{"id": "rear", "max_hp": 24, "statuses": {"weak": 1, "riposte": 2}}])
	_check(app.party.is_valid() and app.enemies.is_valid()
		and app.party.get_hero(seat).id == "scarecrow"
		and app.party.get_hero(seat).hp > 0
		and app.enemies.get_enemies().size() == 3,
		"living Scarecrow in actual seat and three valid original enemy slots")
	_check(app.enemies.gain_block(1, 2) and app.enemies.gain_block(2, 4),
		"real Block on first two targets before attacking")
	if last_foe:
		_check(app.enemies.apply_damage(2, 100) and app.enemies.apply_damage(3, 24),
			"terminal witness has one genuinely living foe")
		app.enemies._enemies[0].hp = 1
		app.enemies._enemies[0].block = 0
	elif dead_rear:
		_check(app.enemies.apply_damage(3, 24), "third original slot slain before cast")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter != null
		and presenter._bindings.has(panel), "real held card belongs to mounted area adapter")
	return panel


func _deck_state(deck: CombatDeck) -> Dictionary:
	return {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "exhausted": deck.exhausted.duplicate(),
		"energy": deck.energy, "turn": deck.turn_active,
		"combat_energy": deck.combat_state.energy,
		"combat_turn": deck.combat_state.player_turn_active}


func _battle_state(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		rng: RandomNumberGenerator) -> Dictionary:
	return {"deck": _deck_state(deck), "heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(), "rng_seed": rng.seed, "rng_state": rng.state,
		"deck_rng_state": deck._rng.state}


func _state() -> Dictionary:
	return {"combat": _battle_state(app.deck, app.party, app.enemies, app.run_rng),
		"intents": app.enemy_intents.get_intents(),
		"turn_index": app.enemy_intents._turn_index,
		"attacks": app.enemy_attacks.duplicate(true),
		"outcome": app.battle_result.get_outcome(),
		"closed": app._battle_closed, "wallet": app.session_gold}


func _oracle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var deck := CombatDeck.new([], rng)
	rng.state = app.run_rng.state
	deck.draw_pile = app.deck.draw_pile.duplicate()
	deck.hand = app.deck.hand.duplicate()
	deck.discard_pile = app.deck.discard_pile.duplicate()
	deck.exhausted = app.deck.exhausted.duplicate()
	deck.combat_state.energy = app.deck.energy
	deck.combat_state.player_turn_active = app.deck.turn_active
	var party := CombatParty.new(app.party.get_heroes())
	party._heroes = app.party.get_heroes()
	var enemies := CombatEnemies.new(app.enemies.get_enemies())
	enemies._enemies = app.enemies.get_enemies()
	return {"deck": deck, "party": party, "enemies": enemies, "rng": rng}


func _dispose() -> void:
	app.free()
	await _frames()


func _face(panel: Control, id: String) -> void:
	var definition := ScarecrowPoolCards.new().get_definition(id)
	var face: Dictionary = presenter.face_text(panel)
	var damage := 6 if id == IDS[1] else 4
	var weak := 3 if id == IDS[1] else 2
	_check(CombatScarecrowHarvestFrightCards.new().is_supported_card(id)
		and presenter._definition(id) == definition
		and definition.target_kind == "enemy_all" and definition.cost == 3
		and definition.effects == {"damage": damage, "weak": weak,
			"cannot_buff_next_turn": true},
		"authentic linked base/+ catalog definitions are used directly")
	_check(face.get("name") == definition.display_name
		and face.get("cost") == "3 energy" and face.get("owner") == "Scarecrow"
		and face.get("effect", "").contains("Deal %d" % damage)
		and face.get("effect", "").contains("Weak %d" % weak)
		and face.get("effect", "").contains("Fear"),
		"mounted sewn face shows name, energy, owner, damage, Weak and Fear")
	_check(face.get("from_pips") == [true, true, true]
		and face.get("to_pips") == [true, true, true]
		and face.get("thread") == true, "authored hero 1-3 and enemy 1-3 connected pips")
	var hint: String = panel.tooltip_text
	_check(hint.contains("Scarecrow") and hint.contains(definition.display_name)
		and hint.contains("3 energy") and hint.contains("From 1,2,3")
		and hint.contains("enemies 1,2,3")
		and hint.contains("%d base attack damage" % damage)
		and hint.contains("Weak %d" % weak)
		and hint.contains("next-turn Fear") and hint.contains("Block")
		and hint.contains("no target choice"), "tooltip describes entire authored attack")
	var names: Array[String] = []
	for child in presenter.face_children(panel):
		names.append(String(child.name))
	_check(names.has("CardName") and names.has("Cost") and names.has("Owner")
		and names.has("Effect") and names.has("Positions") and names.has("From1")
		and names.has("To3"), "card face and position markers are actual mounted nodes")
	_check(panel.get_child(0) is Label and panel.get_child(0).text == id
		and panel.gui_input.get_connections().size() == 1
		and panel.focus_mode == Control.FOCUS_ALL and presenter.button == null,
		"one genuine hand input owner, no standalone action or target picker")


func _activate(panel: Control, mode: String) -> void:
	if mode == "mouse":
		await _mouse(panel)
	else:
		panel.grab_focus()
		_check(panel.has_focus(), "real hand panel acquires keyboard focus")
		var key: Key = KEY_ENTER if mode == "enter" else KEY_SPACE
		root.push_input(_key(key), true)
		root.push_input(_key(key, true, true), true)
		root.push_input(_key(key, false), true)
		await _frames()


func _success(id: String, seat: int, mode: String, dead_rear: bool = false,
		energy: int = 3) -> void:
	var panel := await _begin(id, seat, dead_rear, energy)
	if panel == null:
		await _dispose()
		return
	_face(panel, id)
	var expected := _oracle()
	var prior := _state()
	var preview := CombatScarecrowHarvestFrightCards.new()._prepare(
		expected.deck, expected.party, expected.enemies, id, 0)
	_check(preview.get("ok", false) and preview.get("owner_position") == seat
		and preview.get("targets") == ([1, 2] if dead_rear else [1, 2, 3])
		and preview.get("energy_before") == energy,
		"read-only independent admission names actual owner and living printed slots")
	var receipt := CombatScarecrowHarvestFrightCards.new().play_card(
		expected.deck, expected.party, expected.enemies, id, 0)
	_check(receipt.get("ok", false) and receipt.get("target_position") == 0
		and receipt.get("energy_spent") == 3
		and receipt.get("hits", []).size() == (2 if dead_rear else 3),
		"separate paid resolver yields full multi-hit receipt")
	if not receipt.get("ok", false):
		await _dispose()
		return
	var previous_callback: Callable = presenter._bindings[panel].callback
	seed(40691)
	var global_expected := randi()
	seed(40691)
	await _activate(panel, mode)
	_check(presenter.last_event == receipt,
		"live hand commit returns the independent resolver's complete paid receipt")
	_check(_battle_state(app.deck, app.party, app.enemies, app.run_rng)
		== _battle_state(expected.deck, expected.party, expected.enemies, expected.rng),
		"whole real battle: draw, hand, discard, exhaust, energy, all heroes, all foes and RNG match oracle")
	_check(_state().intents == prior.intents
		and _state().turn_index == prior.turn_index
		and _state().attacks == prior.attacks
		and _state().wallet == prior.wallet and randi() == global_expected,
		"successful nonterminal attack preserves intentions, gold, seeded and global RNG")
	_check(app.deck.energy == energy - 3
		and app.deck.discard_pile.count(id) == 1
		and app.deck.hand.count(id) == 1
		and app.deck.exhausted.count(id) == 0,
		"3 energy and exactly one genuine copy discarded, second copy remains")
	var observed: Array = app.enemies.get_enemies()
	var prior_foes: Array = prior.combat.enemies
	var expected_weak := 3 if id == IDS[1] else 2
	for i in range(3):
		if dead_rear and i == 2:
			_check(observed[i] == prior_foes[i], "original dead rear slot unchanged")
		else:
			var survived: bool = int(observed[i].hp) > 0
			_check(observed[i].statuses.get("cannot_buff_next_turn", false) == survived
				and (int(observed[i].statuses.get("weak", 0))
					== int(prior_foes[i].statuses.get("weak", 0)) + expected_weak if survived
					else not observed[i].statuses.has("cannot_buff_next_turn")),
				"only surviving authored enemy %d gets Weak and literal Fear" % (i + 1))
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()]
		and app.get_node("LiveSupportHand").energy_label.text == str(app.deck.energy)
		and app.hand_view.get_child_count() == app.deck.hand.size()
		and app.battle_result.can_continue() and not app._battle_closed,
		"mounted hand, pile, energy and still-active outcome refreshed")
	var state_after := _state()
	previous_callback.call(_press())
	await _frames()
	_check(_state() == state_after, "retired duplicate callback cannot spend another copy")
	if energy == 6:
		var second := _panel(id)
		_check(second != null and second != panel and presenter._bindings.has(second),
			"second held card is rebound with a fresh single listener")
		if second != null:
			var second_oracle := _oracle()
			var second_receipt := CombatScarecrowHarvestFrightCards.new().play_card(
				second_oracle.deck, second_oracle.party, second_oracle.enemies, id, 0)
			_check(second_receipt.get("ok", false), "second authentic paid card is still eligible")
			await _activate(second, "enter")
			_check(presenter.last_event == second_receipt and app.deck.hand.count(id) == 0
				and app.deck.discard_pile.count(id) == 2
				and _battle_state(app.deck, app.party, app.enemies, app.run_rng)
				== _battle_state(second_oracle.deck, second_oracle.party,
					second_oracle.enemies, second_oracle.rng),
				"two independent held inputs each commit exactly once against oracle")
	await _dispose()


func _denial(reason: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	var old: Callable = presenter._bindings[panel].callback
	if queued:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(not presenter._pending.is_empty(), "physical pending input before " + reason)
	match reason:
		"downed":
			app.party._heroes[1].hp = 0
		"wrong_owner":
			app.party._heroes[1].id = "lantern_monk"
		"duplicate_owner":
			app.party._heroes[0].id = "scarecrow"
		"energy":
			app.deck.combat_state.energy = 2
		"unheld":
			_check(app.deck.hand.count(IDS[0]) == 2,
				"unheld refusal begins with both genuine held copies")
			app.deck.hand.erase(IDS[0])
			app.deck.hand.erase(IDS[0])
			_check(not app.deck.hand.has(IDS[0]), "unheld scenario actually removed all copies")
		"forged":
			panel.get_child(0).text = "scarecrow_harvest_fright_forged"
		"other_printing":
			panel.get_child(0).text = IDS[1]
		"bad_fear":
			app.enemies._enemies[1].statuses["cannot_buff_next_turn"] = 1
		"overflow":
			app.enemies._enemies[1].statuses["weak"] = CombatEnemies.MAX_INT
		"hidden":
			app.battle_view.hide()
		"closed":
			app._battle_closed = true
		"inactive":
			app.deck.combat_state.player_turn_active = false
		"turn":
			app.enemy_intents.advance_turn()
		"panel":
			app._refresh_hand()
		"result":
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"deck":
			app.deck = CombatDeck.new([IDS[0]], app.run_rng)
		"rng":
			app.run_rng = RandomNumberGenerator.new()
		"deck_rng":
			app.deck._rng = RandomNumberGenerator.new()
		"intents":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
	var before := _state()
	var prior_event: Dictionary = presenter.last_event.duplicate(true)
	seed(40637)
	var global_expected := randi()
	seed(40637)
	old.call(_press())
	await _frames()
	_check(_state() == before and presenter.last_event == prior_event
		and presenter._pending.is_empty() and randi() == global_expected,
		"no state, piles, wallet or RNG mutation on " + reason
		+ (" after pending input" if queued else " before input"))
	await _dispose()


func _stale_session() -> void:
	var panel := await _begin(IDS[1])
	if panel == null:
		await _dispose()
		return
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var before := _battle_state(old_deck, old_party, old_enemies, old_rng)
	var old: Callable = presenter._bindings[panel].callback
	panel.grab_focus()
	root.push_input(_key(KEY_SPACE), true)
	_check(not presenter._pending.is_empty(), "physical pending receipt exists before returning to title")
	app.return_button.pressed.emit()
	old.call(_press())
	await _frames()
	_check(_battle_state(old_deck, old_party, old_enemies, old_rng) == before,
		"retired pending request cannot alter original battle or RNG after Return")
	_check(app._start_battle(), "a distinct new live battle begins")
	await _frames()
	var fresh := _state()
	old.call(_press())
	old.call(_key(KEY_ENTER))
	await _frames()
	_check(_state() == fresh, "old panel's mouse and keyboard input never reaches new session")
	await _dispose()


func _terminal() -> void:
	var panel := await _begin(IDS[1], 1, false, 3, true)
	if panel == null:
		await _dispose()
		return
	var gold_rng := RandomNumberGenerator.new()
	gold_rng.seed = app.run_rng.seed
	gold_rng.state = app.run_rng.state
	var gold := gold_rng.randi_range(10, 20)
	await _activate(panel, "mouse")
	_check(presenter.last_event.get("ok", false)
		and presenter.last_event.get("targets") == [1]
		and app.enemies.is_victorious()
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app._battle_closed and not app.deck.turn_active
		and app.end_turn_button.disabled, "final paid cast updates real battle outcome")
	_check(app.session_gold == gold and app.run_rng.state == gold_rng.state,
		"only real victory award uses battle RNG, and pays once")
	var after := _state()
	app._observe_battle_result()
	await _frames()
	_check(_state() == after, "terminal replay/re-observation cannot award twice")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		for seat in [1, 2, 3]:
			for mode in ["mouse", "enter", "space"]:
				await _success(id, seat, mode)
		await _success(id, 2, "mouse", true)
		await _success(id, 2, "enter", false, 6)
	await _terminal()
	await _stale_session()
	for reason in ["downed", "wrong_owner", "duplicate_owner", "energy", "unheld",
			"forged", "other_printing", "bad_fear", "overflow", "hidden", "closed",
			"inactive", "turn", "panel", "result", "deck", "rng", "deck_rng", "intents"]:
		for queued in [false, true]:
			await _denial(reason, queued)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_scarecrow_harvest_fright_hand_test: %d checks, %d failures" % [
		checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
