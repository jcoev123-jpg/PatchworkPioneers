extends SceneTree
## M02 gate: one seeded mounted timeline plus scene-free transactional proof.
var failures: Array[String] = []
var checks := 0
var app
var attack
var trace: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _click(control: Control) -> void:
	_check(is_instance_valid(control), "required physical input control exists")
	if not is_instance_valid(control):
		return
	_check(control.is_visible_in_tree() and root.get_visible_rect().encloses(control.get_global_rect()),
		"whole physical control visible at 1280x720")
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _state() -> Dictionary:
	return {"hand": app.deck.hand.duplicate(), "draw": app.deck.draw_pile.duplicate(),
		"discard": app.deck.discard_pile.duplicate(), "energy": app.deck.energy,
		"active": app.deck.turn_active, "party": app.party.get_heroes(),
		"enemies": app.enemies.get_enemies(), "intents": app.enemy_intents.get_intents(),
		"announced": app.enemy_attacks.duplicate(true), "turn": app.enemy_intents._turn_index,
		"seed": app.run_rng.seed, "rng": app.run_rng.state,
		"opening": app.round_flow._opening_block._consumed,
		"tinker": attack._play._tinker._consumed, "started": app.round_flow._started,
		"outcome": app.battle_result.get_outcome(), "closed": app._battle_closed,
		"gold": app.session_gold}


func _expect(expected: Dictionary, label: String) -> void:
	_check(_state() == expected, label + ": entire independent expected snapshot")
	trace.append(_state())


func _supply(cards: Array[String]) -> void:
	for id in cards:
		_check(not StarterCards.new().get_definition(id).is_empty()
			or not M02PositionCards.new().get_definition(id).is_empty(), "only authored held cards")
	app.deck.hand.assign(cards)
	app._refresh_hand()
	await _frames()
	_check(app.hand_view.get_child_count() == cards.size(), "supplied cards actually mounted")


func _paid(expected: Dictionary, id: String, cost: int) -> void:
	expected.hand.erase(id)
	expected.discard.append(id)
	expected.energy -= cost


func _move(id: String, keyboard: bool) -> void:
	var expected := _state()
	var origin := 1 if id == "warden_backstep" else 2
	var destination := 3 - origin
	var actor: Dictionary = expected.party[origin - 1]
	expected.party[origin - 1] = expected.party[destination - 1]
	expected.party[destination - 1] = actor
	for i in range(3):
		expected.party[i].position = i + 1
	_paid(expected, id, 1)
	var panel: Control = app.hand_view.get_child(0)
	if keyboard:
		app.end_turn_button.grab_focus()
		await _key(KEY_UP)
		_check(panel.has_focus(), "physical Up reaches held swap")
		await _key(KEY_SPACE)
	else:
		await _click(panel)
	_expect(expected, id)
	var targeting := CombatAttackTargeting.new()
	_check(targeting.get_preview(app.deck, app.party, app.enemies, "warden_shield_bash").playable
		== (destination == 1 and app.deck.energy >= 2), "immediate ID-owned Bash origin legality")
	_check(not app.round_flow._opening_block.apply(), "opening passive cannot grant twice after swap")
	_expect(expected, "repeat opening passive has no charge or Block")


func _hit(id: String, target: int, damages: Array, keyboard: bool) -> void:
	var expected := _state()
	_check(not app.deck.hand.is_empty() and app.deck.hand[0] == id,
		"exact authored attack is held at mounted index zero")
	if "--inject-wrong-damage" in OS.get_cmdline_user_args():
		expected.enemies[0].hp -= 1
	var definition := StarterCards.new().get_definition(id)
	_paid(expected, id, definition.cost)
	if definition.owner == "tinker":
		expected.tinker = true
	var hits: Array = []
	for item in damages:
		var position: int = item[0]
		var damage: int = item[1]
		var enemy: Dictionary = expected.enemies[position - 1]
		var absorbed: int = mini(enemy.block, damage)
		var lost: int = mini(enemy.hp, damage - absorbed)
		enemy.block -= absorbed
		enemy.hp -= lost
		var added := {}
		if id == "seamstress_prick":
			added = {"bleed": 3} # Authored 2 plus Seamstress's +1 passive.
		elif id == "warden_shield_bash":
			added = {"weak": 1}
		for status in added:
			if not enemy.has("statuses"):
				enemy.statuses = {}
			enemy.statuses[status] = enemy.statuses.get(status, 0) + added[status]
		hits.append({"position": position, "damage": damage, "block_absorbed": absorbed,
			"hp_loss": lost, "statuses": added})
	var panel: Control = app.hand_view.get_child(0)
	var callback: Callable = attack._bindings[panel].input
	if keyboard:
		await _key(KEY_P)
		_check(attack._armed == panel, "physical P arms exact held attack")
	else:
		await _click(panel)
	if target > 0:
		if keyboard:
			await _key(KEY_1 if target == 1 else KEY_2)
		else:
			await _click(app.get_node("LiveEnemyRoster")._labels[target - 1])
	elif keyboard:
		await _key(KEY_ENTER)
	_expect(expected, "physical " + id)
	_check(attack.last_event == {"ok": true, "hits": hits}, "independent damage/on-hit events " + id)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	callback.call(event)
	await _frames()
	_expect(expected, "stale attack callback cannot charge/discard twice")


func _end(keyboard: bool) -> void:
	var expected := _state()
	# Independent owner-end arithmetic; no production status/damage helper computes expectations.
	for side in [expected.party, expected.enemies]:
		for actor in side:
			var statuses: Dictionary = actor.get("statuses", {})
			actor.hp = maxi(0, actor.hp - statuses.get("bleed", 0))
			for status in statuses.keys():
				statuses[status] -= 1
				if statuses[status] == 0:
					statuses.erase(status)
	# Starter phase: enemy 1 attacks for 1, enemy 2 gains 1 Block.
	var victim: Dictionary = expected.party[expected.intents[0].target_position - 1]
	var damage := 0 if app.enemies.get_enemy(1).get("statuses", {}).get("weak", 0) > 0 else 1
	var absorbed: int = mini(victim.block, damage)
	victim.block -= absorbed
	victim.hp -= damage - absorbed
	expected.enemies[1].block += 1
	for hero in expected.party:
		hero.block = 0
	expected.discard.append_array(expected.hand)
	expected.hand = []
	_check(expected.draw.size() >= 5, "authored supplied draw requires no reshuffle")
	for i in range(5):
		expected.hand.append(expected.draw.pop_back())
	expected.energy = 3
	expected.turn += 1
	expected.intents[0].target_position = expected.turn % 3 + 1
	expected.announced = expected.intents.duplicate(true)
	expected.tinker = false
	if keyboard:
		app.end_turn_button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(app.end_turn_button)
	_expect(expected, "physical End Turn: owner ticks, Block bypass, expiration, piles and latch reset")


func _reject_move(label: String) -> void:
	var before := _state()
	await _click(app.hand_view.get_child(0))
	_expect(before, label + " atomic no-spend rejection")


func _pure_proof() -> void:
	var heroes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/starter_enemies.json"))
	for actor in heroes + definitions:
		_check(actor.max_hp == floor(actor.max_hp), "authored HP integral before normalization")
		actor.max_hp = int(actor.max_hp)
	var party := CombatParty.new(heroes)
	var enemies := CombatEnemies.new(definitions)
	_check(party.is_valid() and enemies.is_valid(), "scene-free actual authored actors valid")
	if not party.is_valid() or not enemies.is_valid():
		return
	party._heroes[0]["statuses"] = {"bleed": 3, "weak": 1}
	party.gain_block(1, 6)
	var rules := CombatEnemySpecialActions.new()
	var shove := {"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 1, "direction": 1}
	var original := party.get_heroes()
	var foes := enemies.get_enemies()
	var expected := original.duplicate(true)
	expected[0] = original[1].duplicate(true)
	expected[1] = original[0].duplicate(true)
	expected[0].position = 1
	expected[1].position = 2
	var result := rules.execute_actions(party, enemies, [shove])
	_check(result == {"ok": true, "events": [{"type": "shove", "enemy_position": 1,
		"applied": true, "target_position": 1, "direction": 1}]}
		and party.get_heroes() == expected and enemies.get_enemies() == foes,
		"scene-free shove preserves exact ID-bound counters, HP and Block")
	for bad in [{"type": "buff", "enemy_position": 2, "amount": -1},
		{"type": "shove", "enemy_position": 2, "amount": 0, "target_position": 3, "direction": 1},
		{"type": "debuff", "enemy_position": 2, "amount": 1, "target_position": 0, "status": "weak"}]:
		var actions := [shove, bad]
		var input := actions.duplicate(true)
		_check(rules.execute_actions(party, enemies, actions) == {"ok": false, "events": []}
			and party.get_heroes() == expected and enemies.get_enemies() == foes and actions == input,
			"malformed later action/invalid destination/target rejects whole valid-first batch")
	party.apply_damage(2, 10000)
	var downed := party.get_heroes()
	_check(rules.execute_actions(party, enemies, [shove]) == {"ok": false, "events": []}
		and party.get_heroes() == downed and enemies.get_enemies() == foes, "scene-free downed shove atomic")


func _timeline(alternate: bool) -> Array:
	trace = []
	app.run_seed = 42
	await _click(app.start_button)
	_check(app.deck != null and app.party != null and app.enemies != null and app.round_flow != null,
		"seed 42 title creates actual session services")
	if app.deck == null:
		return []
	attack = app.get_node("LiveAttackPreview")
	trace.append(_state())
	_check(app.deck.energy == 3 and app.deck.turn_active and app.party.get_hero(1).block == 6
		and app.party.get_hero(1).id == "warden" and not attack._play._tinker._consumed,
		"clean opening energy, formation and passive latches")
	# Legal test preconditions: authored supplied cards, ample Block, no balance edits.
	app.enemies.gain_block(1, 40)
	app.enemies.gain_block(2, 40)
	app.party._heroes[0]["statuses"] = {"bleed": 3}
	app.deck.draw_pile.clear()
	for i in range(20):
		app.deck.draw_pile.append("warden_strike")
	await _supply(["warden_backstep", "warden_advance", "seamstress_prick", "warden_shield_bash"])
	await _move("warden_backstep", alternate)
	_check(app.party.get_hero(2).statuses == {"bleed": 3} and app.party.get_hero(1).id == "seamstress",
		"ID-owned Bleed travels with Warden, all three slots occupied")
	await _move("warden_advance", not alternate)
	await _hit("seamstress_prick", 1, [[1, 3]], alternate)
	_check(app.enemies.get_enemy(1).statuses == {"bleed": 3}, "held Prick persists authored two plus passive one Bleed")
	await _end(false)
	_check(app.party.get_hero(1).hp == 37 and app.party.get_hero(1).block == 0
		and app.party.get_hero(1).statuses == {"bleed": 2}, "hero Bleed bypassed opening six Block")
	await _supply(["warden_shield_bash"])
	await _hit("warden_shield_bash", 1, [[1, 8]], alternate)
	_check(app.enemies.get_enemy(1).statuses == {"bleed": 2, "weak": 1}, "Bash persists Weak alongside remaining Bleed")
	await _end(true)
	_check(app.enemies.get_enemy(1).hp == 7 and app.enemies.get_enemy(1).block == 29
		and app.enemies.get_enemy(1).statuses == {"bleed": 1}, "enemy owner Bleed bypasses Block, Weak expires exactly")
	# Explicit Exposed test fixture: no shipped card grants it. Weak belongs to Tinker by ID.
	app.party._heroes[2]["statuses"] = {"weak": 1}
	app.enemies.apply_statuses({1: {"exposed": 1}})
	await _supply(["tinker_pop_shot", "tinker_scrap_bomb"])
	var before := _state()
	_check(attack._play.play_attack(app.deck, app.party, app.enemies, "tinker_pop_shot", 0)
		== {"ok": false, "hits": []}, "invalid selected target rejected before first attack")
	_check(attack._play.play_attack(app.deck, app.party, app.enemies, "tinker_pop_shot", 3)
		== {"ok": false, "hits": []}, "absent enemy slot rejected before first attack")
	_expect(before, "invalid target keeps first-attack bonus and full state")
	await _hit("tinker_pop_shot", 1, [[1, 9]], not alternate) # floor((5+3)*3/4*3/2).
	await _hit("tinker_scrap_bomb", 0, [[1, 4], [2, 3]], not alternate) # no second +3; floor once.
	await _end(false)
	await _supply(["warden_advance"])
	await _reject_move("illegal front origin")
	await _supply(["warden_backstep"])
	app.deck.combat_state.energy = 0
	await _reject_move("zero energy")
	app.deck.combat_state.energy = 3
	var roster: Array = app.party.get_heroes()
	app.party.apply_damage(2, 10000)
	await _reject_move("downed neighbor")
	app.party._heroes.assign(roster.duplicate(true))
	app.party.apply_damage(1, 10000)
	await _reject_move("downed owner")
	app.party._heroes.assign(roster.duplicate(true))
	await _end(true)
	_check(app.party.get_hero(1).statuses == {} and app.enemies.get_enemy(1).statuses == {}
		and app.party.get_hero(3).statuses == {} and app.enemies.get_enemy(1).hp == 6,
		"three/two/one owner Bleed ticks expire; Weak and Exposed expire once")
	# Legal lethal-status precondition: last living enemy at 1 HP with Bleed 1.
	app.enemies.apply_damage(2, 10000)
	app.enemies._enemies[0].hp = 1
	app.enemies.apply_statuses({1: {"bleed": 1}})
	await _click(app.end_turn_button)
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY and app._battle_closed
		and not app.deck.turn_active and app.end_turn_button.disabled
		and app.enemies.get_enemy(1).hp == 0, "lethal owner status closes combat")
	before = _state()
	_check(not app.round_flow.end_turn(), "terminal coordinator refuses another turn")
	_check(attack._play.play_attack(app.deck, app.party, app.enemies, "warden_strike", 1)
		== {"ok": false, "hits": []}, "terminal attack refuses spend")
	await _key(KEY_P)
	await _key(KEY_1)
	_expect(before, "terminal physical and service actions frozen")
	await _click(app.return_button)
	_check(app.deck == null and app.party == null and app.enemies == null and app.start_button.has_focus(),
		"physical return releases session and focuses title")
	return trace.duplicate(true)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	seed(55042)
	var next := randi()
	seed(55042)
	_pure_proof()
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var first := await _timeline(false)
	var second := await _timeline(true)
	_check(not first.is_empty() and first == second, "fresh physical title restart seed-42 full snapshots replay exactly")
	_check(randi() == next, "entire mounted and scene-free gate consumes no global RNG")
	app.free()
	for failure in failures:
		printerr(failure)
	print("live_m02_gate_regression_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
