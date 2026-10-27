extends "res://tests/live_seamstress_v3_cleansing_hand_test.gd"

const HEMS := ["seamstress_v3_shielding_hem", "seamstress_v3_shielding_hem_plus",
	"seamstress_v3_patchwork_poultice", "seamstress_v3_patchwork_poultice_plus"]


func _hem_case(id: String, key: Key, target: int, capped: bool) -> void:
	if not await _begin(id):
		return
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.count(id) == 2, "two genuinely held copies expose duplicate-payment bugs")
	app._refresh_hand()
	await _frames()
	_check(app.party.apply_damage(target, 1 if capped else 12), "genuinely wounded ally")
	app._refresh_party()
	await _frames()
	var definition: Dictionary = presenter._metadata.definition(id)
	_check(not definition.is_empty(), "authenticated catalog printing")
	var panel := _pool_panel(id)
	var facts: Dictionary = presenter._metadata.get_facts(panel)
	_check(facts.known and facts.cost == definition.cost and facts.owner == "seamstress"
		and panel.tooltip_text.contains("%d Block" % definition.effects.block)
		and panel.tooltip_text.contains("heal %d HP" % definition.effects.heal), "printed face and capped ally effect")
	var before := _pool_state()
	# Independent real service instance and detached models, never the UI service.
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var cards: Array[String] = []
	cards.assign(app.deck.hand + app.deck.draw_pile + app.deck.discard_pile)
	var oracle := CombatDeck.new(cards, rng)
	oracle.start_turn()
	oracle.hand.assign(app.deck.hand)
	oracle.draw_pile.assign(app.deck.draw_pile)
	oracle.discard_pile.assign(app.deck.discard_pile)
	oracle.combat_state.energy = app.deck.energy
	rng.state = app.run_rng.state
	var allies := CombatParty.new(app.party.get_heroes())
	for i in range(3):
		allies._heroes[i] = app.party._heroes[i].duplicate(true)
	var receipt := CombatSeamstressV3HemCards.new().play_card(oracle, allies, id, target)
	_check(receipt.get("ok", false), "independent paid oracle accepted real preconditions")
	_check(receipt.get("block") == definition.effects.block and receipt.get("heal") == definition.effects.heal
		and allies.get_hero(target).hp == mini(before[5][target - 1].max_hp, before[5][target - 1].hp + definition.effects.heal)
		and allies.get_hero(target).block == before[5][target - 1].block + definition.effects.block
		and rng.state == app.run_rng.state, "oracle agrees with printed capped effects and consumes no RNG")
	var expected: Array = before.duplicate(true)
	expected[1] = oracle.hand.duplicate()
	expected[2] = oracle.discard_pile.duplicate()
	expected[3] = oracle.energy
	expected[5] = allies.get_heroes()
	if key == KEY_NONE:
		await _arm(id, false)
	else:
		panel.grab_focus()
		await _keyboard(key)
	_check(presenter._pending.get("choosing", false) and presenter._targets.size() == 3, "real living ally picker")
	_check(_pool_state() == before, "picker is read only")
	if not presenter._targets.has(app.hero_panels[target - 1]):
		await _pool_return()
		return
	var retired: Callable = presenter._targets[app.hero_panels[target - 1]].callback
	if key == KEY_NONE:
		await _mouse(app.hero_panels[target - 1])
	else:
		app.hero_panels[target - 1].grab_focus()
		await _keyboard(key)
	_check(_pool_state() == expected, "live result equals independent service; enemies RNG and other heroes unchanged: " + id)
	_check(presenter._pending.is_empty(), "commit clears receipt")
	retired.call(_press())
	await _frames()
	_check(_pool_state() == expected, "duplicate click cannot repay")
	await _pool_return()


func _hem_refusal(mode: String) -> void:
	var id: String = HEMS[2]
	if not await _begin(id):
		return
	_check(app.party.apply_damage(1, 12), "refusal target healable")
	await _arm(id, false)
	_check(presenter._targets.has(app.hero_panels[0]), "nonvacuous live callback")
	if not presenter._targets.has(app.hero_panels[0]):
		await _pool_return()
		return
	var callback: Callable = presenter._targets[app.hero_panels[0]].callback
	# Queue real input but change its authority before the deferred commit.
	callback.call(_press())
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"target": _check(app.party.apply_damage(1, 10000), "target torn")
		"owner": _check(app.party.apply_damage(2, 10000), "owner torn")
		"seat":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			_check(swap.ok, "legal movement to illegal owner seat")
			app.party._heroes.assign(swap.heroes)
			app._refresh_intents()
		"hand": _check(app.deck.discard_played(id), "held copy removed")
		"panel": app._refresh_hand()
		"turn": app.deck.combat_state.player_turn_active = false
		"turn_receipt": app.enemy_intents._turn_index += 1
		"battle_receipt": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"battle": app._battle_closed = true
		"identity": app.party._heroes[0].id = "replacement"
		"invalid": presenter._pending.target.position = 4
		"escape": root.push_input(_key(KEY_ESCAPE), true)
		"cancel": presenter.cancel_button.pressed.emit()
	var before := _pool_state()
	await _frames()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(), "refusal and replay inert including piles RNG: " + mode)
	await _pool_return()


func _admission(mode: String) -> void:
	var id: String = HEMS[2]
	if not await _begin(id):
		return
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"owner": _check(app.party.apply_damage(2, 10000), "owner really downed before input")
		"seat":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			_check(swap.ok, "real swap before input")
			app.party._heroes.assign(swap.heroes)
			app._refresh_intents()
		"target": _check(app.party.apply_damage(1, 10000), "target really downed before picker")
	var before := _pool_state()
	await _mouse(_pool_panel(id))
	if mode == "target":
		_check(presenter._pending.get("choosing", false) and presenter._targets.size() == 2
			and not presenter._targets.has(app.hero_panels[0]), "downed target excluded; other living allies offered")
		await _mouse(app.hero_panels[0])
		await _keyboard(KEY_ESCAPE)
	else:
		_check(presenter._pending.is_empty(), "illegal card never arms: " + mode)
	_check(_pool_state() == before, "admission refusal preserves complete state: " + mode)
	await _pool_return()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveSupportHand")
	for id in HEMS:
		for key in [KEY_NONE, KEY_ENTER, KEY_SPACE]:
			for target in [1, 2, 3]:
				await _hem_case(id, key, target, target != 1)
	for mode in ["energy", "target", "owner", "seat", "hand", "panel", "turn", "turn_receipt", "battle_receipt", "battle", "identity", "invalid", "escape", "cancel"]:
		await _hem_refusal(mode)
	for mode in ["energy", "owner", "seat", "target"]:
		await _admission(mode)
	app.queue_free()
	await _frames()
	_finish()
