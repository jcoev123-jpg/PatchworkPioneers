extends "res://tests/live_support_hand_test.gd"
## Real App scene / held-card input versus the independent Crow Flock resolver.
##
## Both authored printings are played from a genuine five-card shared hand with a
## living Scarecrow in seat 2 or 3: the paid service charges two energy, discards
## exactly the held copy, adds the printed Weak to every living enemy in slots 1-3
## and arms the literal one-turn Fear flag. The mounted metadata face must be
## enabled by the real area presenter's own admission only, stay dim on every
## refusal and never grow a second input owner, action button or target picker.

const IDS := ["scarecrow_crow_flock", "scarecrow_crow_flock_plus"]


## One real mounted battle: five genuinely drawn cards (two Crow Flock copies),
## the requested Scarecrow seat, three original enemy slots with different Weak
## stacks, one Blocked foe and one genuinely slain rear slot.
func _begin(id: String, seat: int = 2, energy: int = 3) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 416
	_check(app._start_battle(), "shipped App enters real combat")
	presenter = app.get_node_or_null("LiveAreaAttackAction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 416
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.size() == 5
		and app.deck.hand.count(id) == 2,
		"real five-card draw has two genuine held printings")
	app.deck.combat_state.energy = energy
	var heroes: Array = [
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "scarecrow", "name": "Scarecrow",
		"max_hp": 34, "statuses": {"weak": 1, "dodge_next_attack": 1}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "front", "max_hp": 21, "statuses": {"bleed": 2}},
		{"id": "middle", "max_hp": 30, "statuses": {"exposed": 2, "weak": 1}},
		{"id": "rear", "max_hp": 24, "statuses": {"weak": 3, "riposte": 2}}])
	_check(app.party.is_valid() and app.enemies.is_valid()
		and app.party.get_hero(seat).id == "scarecrow"
		and app.party.get_hero(seat).hp > 0
		and app.enemies.get_enemies().size() == 3,
		"living Scarecrow in actual seat and three valid original enemy slots")
	_check(app.enemies.gain_block(1, 2) and app.enemies.gain_block(2, 4),
		"real Block on the first two living targets before the flock")
	_check(app.enemies.apply_damage(3, 24), "third original slot genuinely slain before cast")
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


## An independent logical clone of the live battle, never a product of the UI.
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


func _weak(id: String) -> int:
	return 2 if id == IDS[1] else 1


## Both mounted faces (the sewn cue and the shared metadata face), their pips,
## the tooltip, one single input owner and the genuine catalog record.
func _face(panel: Control, id: String) -> void:
	var definition := ScarecrowPoolCards.new().get_definition(id)
	var meta = app.get_node("LiveSupportHand")._metadata
	var face: Dictionary = presenter.face_text(panel)
	var weak := _weak(id)
	_check(CombatScarecrowCrowFlockCards.new().is_supported_card(id)
		and presenter._definition(id) == definition
		and meta.definition(id) == definition
		and definition.owner == "scarecrow" and definition.cost == 2
		and definition.target_kind == "enemy_all"
		and definition.from_positions == [2, 3]
		and definition.to_positions == [1, 2, 3]
		and definition.starting_copies == 0 and definition.reward_eligible == (id == IDS[0])
		and definition.effects == {"weak": weak, "cannot_buff_next_turn": true},
		"authentic Scarecrow pool record feeds both mounted faces")
	_check(face.get("name") == definition.display_name
		and face.get("cost") == "2 energy" and face.get("owner") == "Scarecrow"
		and face.get("effect", "").contains("Weak %d" % weak)
		and face.get("effect", "").contains("Fear"),
		"sewn cue shows name, 2 energy, Scarecrow owner, Weak and Fear")
	_check(face.get("from_pips") == [false, true, true]
		and face.get("to_pips") == [true, true, true]
		and face.get("thread") == true,
		"authored hero 2-3 source pips and connected enemy 1-3 targets")
	var facts: Dictionary = meta.get_facts(panel)
	_check(facts.get("known", false) and facts.get("owner") == "scarecrow"
		and facts.get("owner_text") == "Scarecrow" and facts.get("cost") == 2
		and facts.get("rules") == "Weak %d to all. Fear to all." % weak,
		"shared metadata face keeps the authentic Weak and Fear line")
	_check(meta.short_line(id) == "Weak %d to all. Fear to all." % weak,
		"metadata short line prints the printed Weak and the Fear keyword")
	var hint: String = panel.tooltip_text
	_check(hint.contains("Scarecrow") and hint.contains(definition.display_name)
		and hint.contains("2 energy") and hint.contains("From 2,3")
		and hint.contains("enemies 1,2,3") and hint.contains("Weak %d" % weak)
		and hint.contains("next-turn Fear") and hint.contains("cannot buff")
		and hint.contains("no target choice"), "tooltip describes the entire authored cast")
	var meta_hint: String = meta.base_effect_text(id)
	_check(meta_hint.contains("Scarecrow") and meta_hint.contains("2 energy")
		and meta_hint.contains("From 2–3") and meta_hint.contains("All enemies 1–3")
		and meta_hint.contains("BASE apply Weak %d to each living enemy" % weak),
		"metadata tooltip quotes the same authored cost, slots and Weak amount")
	var names: Array[String] = []
	for child in presenter.face_children(panel):
		names.append(String(child.name))
	_check(names.has("CardName") and names.has("Cost") and names.has("Owner")
		and names.has("Effect") and names.has("Positions") and names.has("From2")
		and names.has("To3"), "card face and position markers are actual mounted nodes")
	_check(panel.get_child(0) is Label and panel.get_child(0).text == id
		and panel.gui_input.get_connections().size() == 1
		and panel.focus_mode == Control.FOCUS_ALL and presenter.button == null,
		"one genuine hand input owner, no standalone action or target picker")
	var support = app.get_node("LiveSupportHand")
	_check(not support._bindings.has(panel) and support._pending.is_empty()
		and support._targets.is_empty(),
		"the shared support presenter adds no second callback or target selection")


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


## Every living printed target's Weak grows by exactly the authored amount and
## its Fear flag is the literal boolean true. Other statuses, HP and Block inside
## the living slots never change, and the slain slot keeps every field.
func _targets(id: String, prior_foes: Array, dead_rear: bool = true) -> void:
	var observed: Array = app.enemies.get_enemies()
	var weak := _weak(id)
	for index in range(3):
		if dead_rear and index == 2:
			_check(observed[index] == prior_foes[index], "original slain rear slot unchanged")
			continue
		var after: Dictionary = observed[index]
		var before: Dictionary = prior_foes[index]
		_check(int(after.hp) == int(before.hp) and int(after.block) == int(before.block)
			and after.id == before.id and int(after.position) == int(before.position),
			"living enemy %d keeps HP, Block and slot identity" % (index + 1))
		var after_statuses: Dictionary = after.statuses.duplicate(true)
		var before_statuses: Dictionary = before.statuses.duplicate(true)
		_check(after_statuses.get("cannot_buff_next_turn") == true
			and typeof(after_statuses.get("cannot_buff_next_turn")) == TYPE_BOOL,
			"living enemy %d holds one literal boolean Fear" % (index + 1))
		_check(int(after_statuses.get("weak", 0))
			== int(before_statuses.get("weak", 0)) + weak,
			"living enemy %d stacks exactly the printed Weak %d" % [index + 1, weak])
		after_statuses.erase("cannot_buff_next_turn")
		after_statuses.erase("weak")
		before_statuses.erase("cannot_buff_next_turn")
		before_statuses.erase("weak")
		_check(after_statuses == before_statuses,
			"living enemy %d keeps every other status untouched" % (index + 1))


func _success(id: String, seat: int, mode: String, energy: int = 3) -> void:
	var panel := await _begin(id, seat, energy)
	if panel == null:
		await _dispose()
		return
	_face(panel, id)
	var expected := _oracle()
	var prior := _state()
	var preview := CombatScarecrowCrowFlockCards.new()._prepare(
		expected.deck, expected.party, expected.enemies, id, 0)
	_check(preview.get("ok", false) and preview.get("owner_position") == seat
		and preview.get("targets") == [1, 2] and preview.get("energy_before") == energy
		and preview.get("weak") == _weak(id),
		"read-only independent admission names the seat, live targets and printed Weak")
	var receipt := CombatScarecrowCrowFlockCards.new().play_card(
		expected.deck, expected.party, expected.enemies, id, 0)
	var applied: Array = receipt.get("applied", [])
	_check(receipt.get("ok", false) and receipt.get("target_position") == 0
		and receipt.get("cost") == 2 and receipt.get("targets") == [1, 2]
		and applied.size() == 2,
		"separate paid resolver yields the complete Weak/Fear receipt")
	for entry in applied:
		_check(bool(entry.get("fear_applied", false))
			and int(entry.get("weak_after", -1)) == int(entry["weak_before"]) + _weak(id),
			"oracle receipt proves Weak stacked and Fear armed on a living target")
	if not receipt.get("ok", false):
		await _dispose()
		return
	var meta = app.get_node("LiveSupportHand")._metadata
	_check(meta.visual_state(panel).playable and presenter._eligible(panel, id),
		"real mounted admission enables the genuine face")
	var previous_callback: Callable = presenter._bindings[panel].callback
	seed(41691)
	var global_expected := randi()
	seed(41691)
	await _activate(panel, mode)
	_check(presenter.last_event == receipt,
		"live hand commit returns the independent resolver's complete paid receipt")
	_check(_battle_state(app.deck, app.party, app.enemies, app.run_rng)
		== _battle_state(expected.deck, expected.party, expected.enemies, expected.rng),
		"whole real battle: draw, hand, discard, exhaust, energy, heroes, foes and RNG match oracle")
	var now := _state()
	_check(now.intents == prior.intents and now.turn_index == prior.turn_index
		and now.attacks == prior.attacks and now.wallet == prior.wallet
		and now.outcome == prior.outcome and now.closed == prior.closed
		and randi() == global_expected,
		"successful non-damaging cast preserves intents, outcome, gold and seeded RNG")
	_check(app.deck.energy == energy - 2
		and app.deck.discard_pile.count(id) == 1
		and app.deck.hand.count(id) == 1
		and app.deck.exhausted.count(id) == 0,
		"2 energy and exactly one genuine copy discarded, the second copy remains")
	_check(app.party.get_heroes() == prior.combat.heroes, "the acting party is unchanged")
	_targets(id, prior.combat.enemies)
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()]
		and app.get_node("LiveSupportHand").energy_label.text == str(app.deck.energy)
		and app.hand_view.get_child_count() == app.deck.hand.size()
		and app.battle_result.can_continue() and not app._battle_closed,
		"mounted hand, pile, energy and still-active outcome refreshed")
	var state_after := _state()
	previous_callback.call(_press())
	await _frames()
	_check(_state() == state_after,
		"retired duplicate callback cannot spend the remaining copy")
	_check(not is_instance_valid(panel) or not presenter._bindings.has(panel),
		"the retired first panel is no longer bound")
	if energy == 4:
		var second := _panel(id)
		_check(second != null and second != panel and presenter._bindings.has(second)
			and second.gui_input.get_connections().size() == 1,
			"second held copy is rebound with a fresh single listener")
		if second != null:
			_check(meta.visual_state(second).playable and presenter._eligible(second, id),
				"second separately affordable copy is genuinely enabled")
			var weak_before_second: Array = []
			for index in range(3):
				weak_before_second.append(int(app.enemies.get_enemies()[index].statuses.get("weak", 0)))
			var second_oracle := _oracle()
			var second_receipt := CombatScarecrowCrowFlockCards.new().play_card(
				second_oracle.deck, second_oracle.party, second_oracle.enemies, id, 0)
			_check(second_receipt.get("ok", false),
				"second authentic paid card is still eligible")
			var before_second := _state()
			await _activate(second, "enter")
			_check(presenter.last_event == second_receipt and app.deck.hand.count(id) == 0
				and app.deck.discard_pile.count(id) == 2
				and _battle_state(app.deck, app.party, app.enemies, app.run_rng)
				== _battle_state(second_oracle.deck, second_oracle.party,
					second_oracle.enemies, second_oracle.rng),
				"two independent held inputs each commit exactly once against oracle")
			_check(app.party.get_heroes() == before_second.combat.heroes,
				"the second cast still leaves the party untouched")
			var foes: Array = prior.combat.enemies
			for index in range(2):
				var statuses: Dictionary = app.enemies.get_enemies()[index].statuses
				_check(int(statuses.get("weak", 0))
					== int(foes[index].statuses.get("weak", 0)) + _weak(id) * 2
					and statuses.get("cannot_buff_next_turn") == true
					and typeof(statuses.get("cannot_buff_next_turn")) == TYPE_BOOL
					and int(weak_before_second[index]) + _weak(id) == int(statuses.get("weak", 0)),
					"second copy stacks Weak again and only re-arms one boolean Fear")
			_check(app.enemies.get_enemies()[2] == foes[2],
				"replaying the flock never touches the slain rear slot")
	await _dispose()


## A direct input on an obsolete/rejected mounted panel, after an optional
## physically queued press, must leave the complete battle and RNG untouched.
func _denial(reason: String, queued: bool) -> void:
	var panel := await _begin(IDS[0], 2, 3)
	if panel == null:
		await _dispose()
		return
	var old: Callable = presenter._bindings[panel].callback
	if queued:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(not presenter._pending.is_empty(), "physical pending input before " + reason)
	match reason:
		"energy":
			app.deck.combat_state.energy = 1
		"unheld":
			_check(app.deck.hand.count(IDS[0]) == 2,
				"unheld refusal begins with both genuine held copies")
			app.deck.hand.erase(IDS[0])
			app.deck.hand.erase(IDS[0])
			_check(not app.deck.hand.has(IDS[0]), "unheld scenario actually removed all copies")
		"forged":
			panel.get_child(0).text = "scarecrow_crow_flock_forged"
		"other_printing":
			panel.get_child(0).text = IDS[1]
		"downed":
			app.party._heroes[1].hp = 0
		"seat1":
			app.party._heroes[0].id = "scarecrow"
			app.party._heroes[1].id = "warden"
		"wrong_owner":
			app.party._heroes[1].id = "lantern_monk"
		"bad_fear":
			app.enemies._enemies[1].statuses["cannot_buff_next_turn"] = 1
		"overflow":
			app.enemies._enemies[1].statuses["weak"] = CombatEnemies.MAX_INT
		"roster":
			app.enemies._enemies[0].position = 5
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
		"intents":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
	# Settle the HUD's legitimate response to the changed fixture before input.
	app._refresh_intents()
	if reason != "panel":
		var meta = app.get_node("LiveSupportHand")._metadata
		meta._update_visual(panel)
		_check(not meta.visual_state(panel).playable,
			"unavailable mounted face stays dim: " + reason)
		if reason == "bad_fear":
			_check(app.deck.energy >= 2 and app.party.get_hero(2).id == "scarecrow",
				"dim face is not explained by generic energy or owner alone")
	var before := _state()
	var prior_event: Dictionary = presenter.last_event.duplicate(true)
	seed(41637)
	var global_expected := randi()
	seed(41637)
	old.call(_press())
	old.call(_key(KEY_ENTER))
	await _frames()
	_check(_state() == before and presenter.last_event == prior_event
		and presenter._pending.is_empty() and randi() == global_expected,
		"no state, piles, wallet or RNG mutation on " + reason
		+ (" after pending input" if queued else " before input"))
	await _dispose()


## Returning to the title and starting another battle retires the old panel and
## its queued receipt completely.
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
	_check(not presenter._pending.is_empty(),
		"physical pending receipt exists before returning to title")
	app.return_button.pressed.emit()
	old.call(_press())
	await _frames()
	_check(_battle_state(old_deck, old_party, old_enemies, old_rng) == before,
		"retired pending request cannot alter the original battle or RNG after Return")
	_check(app._start_battle(), "a distinct new live battle begins")
	await _frames()
	var fresh := _state()
	old.call(_press())
	old.call(_key(KEY_ENTER))
	await _frames()
	_check(_state() == fresh, "old panel's mouse and keyboard input never reaches the new session")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		await _success(id, 2, "mouse")
		await _success(id, 3, "enter")
		await _success(id, 3, "space")
		await _success(id, 2, "enter", 4)
	await _stale_session()
	for reason in ["energy", "unheld", "forged", "other_printing", "downed", "seat1",
			"wrong_owner", "bad_fear", "overflow", "roster", "hidden", "closed",
			"inactive", "turn", "panel", "result", "deck", "rng", "intents"]:
		for queued in [false, true]:
			await _denial(reason, queued)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_scarecrow_crow_flock_hand_test: %d checks, %d failures" % [
		checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
