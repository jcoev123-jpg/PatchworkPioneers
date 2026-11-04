extends "res://tests/live_support_hand_test.gd"

const TURRET := CombatTinkerV3TurretCards.CARDS


## A real mounted battle whose back-seat Tinker holds two copies of `id`. Every enemy announces a plain
## Block, so a genuine End Turn harms no hero; "kill" leaves one attacker alive at `kill_hp`, "hound" is the
## catalog Spoolback Hound alone, and "status" is one ordinary living enemy behind 2 Block.
func _begin(id: String, mode: String = "plain", kill_hp: int = 3) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 357
	_check(app._start_battle(), "real mounted battle starts")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 357
	app.deck = CombatDeck.new([id, id, "warden_strike", "warden_brace", "seamstress_mend"], rng)
	app.run_rng = rng
	app.party = CombatParty.new([{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30},
		{"id": "tinker", "name": "Tinker", "max_hp": 26}])
	app.enemies = CombatEnemies.new([
		{"id": "first", "name": "First", "max_hp": 40},
		{"id": "second", "name": "Second", "max_hp": 40},
		{"id": "third", "name": "Third", "max_hp": 40}])
	if mode == "hound":
		app.enemies = CombatEnemies.new([_catalog_hound()])
	elif mode == "status":
		app.enemies = CombatEnemies.new([{"id": "first", "name": "First", "max_hp": 40}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "Tinker seated third and a valid enemy roster")
	var second: Array = [{"type": "block", "amount": 1}]
	if mode == "kill":
		_check(app.enemies.apply_damage(1, 40) and app.enemies.apply_damage(3, 40)
			and app.enemies.apply_damage(2, 40 - kill_hp), "kill fixture leaves one attacker alive")
		second = [{"type": "attack", "amount": 5, "target_position": 1}]
	else:
		_check(app.enemies.gain_block(1, 2), "first enemy begins with Block")
	app.enemy_intents = CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]},
		{"enemy_position": 2, "pattern": second},
		{"enemy_position": 3, "pattern": [{"type": "block", "amount": 1}]}])
	if mode == "hound":
		app.enemy_intents = CombatEnemyIntents.new([
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 7, "target_position": 1}]}])
	if mode == "status":
		app.enemy_intents = CombatEnemyIntents.new([
			{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}])
	_check(app.enemy_intents.is_valid(), "announced enemy schedule is valid")
	app.enemy_attacks = app.enemy_intents.get_intents()
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	_check(app.round_flow.begin_fight() and app.deck.hand.count(id) == 2 and app.deck.energy == 3,
		"the real round flow opens the fight: five cards drawn at three energy")
	app._refresh_intents()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"real illustrated hand binds the exact held turret card")
	return panel


func _model_state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.battle_result.get_outcome(), app._battle_closed,
		app.round_flow.get_turrets() if app.round_flow != null else null]


func _dispose() -> void:
	app.free()
	await _frames()


func _hp() -> Array:
	return app.enemies.get_enemies().map(func(enemy): return enemy.hp)


func _play(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	await _frames()


func _mouse_half(control: Control, pressed: bool) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)


func _press_end_turn(keyboard: bool) -> void:
	if app.end_turn_button.disabled:
		await _frames()
	if keyboard:
		app.end_turn_button.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(app.end_turn_button)
	await _frames()


## Independent oracle for one accepted End Turn: each live turret ticks in deployment order through the real
## resolver on detached enemies with a copy of the run RNG, then the next hand is drawn from that copy.
## Returns [enemy HP, shot targets, next hand, final RNG state, tick receipts].
func _oracle() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var roster: Array[Dictionary] = app.enemies.get_enemies()
	var enemies := CombatEnemies.new(roster)
	enemies._enemies.assign(roster.duplicate(true))
	var resolver := CombatTinkerV3TurretCards.new()
	var targets: Array[int] = []
	var receipts: Array[Dictionary] = []
	for state in app.round_flow.get_turrets():
		var receipt: Dictionary = resolver.tick_turret(state, enemies, rng)
		_check(receipt.ok, "oracle tick is legal")
		targets.append(int(receipt.get("target_position", -1)))
		receipts.append(receipt)
	var none: Array[String] = []
	var next := CombatDeck.new(none, rng)
	next.draw_pile.assign(app.deck.draw_pile)
	next.discard_pile.assign(app.deck.discard_pile + app.deck.hand)
	next.start_turn()
	return [enemies.get_enemies().map(func(enemy): return enemy.hp), targets, next.hand.duplicate(),
		rng.state, receipts]


## AC1 and AC2: a paid live deployment, then three accepted End Turns of seeded shots and no fourth.
func _success(id: String, keyboard: bool) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var damage: int = int(TURRET[id].damage)
	var enemies_before: Array = app.enemies.get_enemies()
	var party_before: Array = app.party.get_heroes()
	var draw_before: Array = app.deck.draw_pile.duplicate()
	var rng_before: int = app.run_rng.state
	await _play(panel, keyboard)
	_check(app.deck.energy == 1 and app.deck.hand.count(id) == 1 and app.deck.discard_pile.count(id) == 1
		and app.deck.draw_pile == draw_before, id + ": exactly one held copy is paid for 2 energy and discarded")
	_check(app.enemies.get_enemies() == enemies_before and app.party.get_heroes() == party_before
		and app.run_rng.state == rng_before, id + ": deployment deals no immediate damage and draws no RNG")
	var turrets: Array = app.round_flow.get_turrets()
	_check(turrets.size() == 1 and turrets[0].card_id == id and turrets[0].remaining == 3
		and turrets[0].damage == damage, id + ": one independent three-beat turret is registered")
	_check(presenter._pending.is_empty() and presenter.energy_label.text.contains("1"),
		id + ": the request clears and the HUD energy refreshes")
	var second := _panel(id)
	_check(second != null and second != panel, id + ": the hand rebuilds with the remaining copy")
	# The remaining copy cannot be afforded: no second deployment, no spend.
	var before := _model_state()
	await _play(second, not keyboard)
	_check(_model_state() == before, id + ": an underfunded second copy cannot pay or register")
	var heroes_hp: Array = party_before.map(func(hero): return hero.hp)
	for beat in range(3):
		var label := "%s beat %d" % [id, beat + 1]
		var oracle := _oracle()
		var shot := _hp()
		_check(app.enemy_attacks == app.enemy_intents.get_intents() and not app.end_turn_button.disabled,
			label + ": the real End Turn is available with the announced batch current")
		await _press_end_turn(keyboard == (beat % 2 == 0))
		_check(app.deck.turn_active and app.deck.energy == 3, label + ": the accepted End Turn opens the next turn")
		_check(_hp() == oracle[0] and oracle[1].size() == 1 and oracle[1][0] in [1, 2, 3],
			label + ": exactly one seeded shot lands on a living enemy through Block before enemies act")
		_check(app.deck.hand == oracle[2] and app.run_rng.state == oracle[3],
			label + ": the shot draws from the shared run RNG before the next hand")
		var loss: int = shot[oracle[1][0] - 1] - _hp()[oracle[1][0] - 1]
		_check(loss >= 0 and loss <= damage, label + ": the shot deals the printed damage less Block")
		var left: Array = app.round_flow.get_turrets()
		_check(left.size() == (0 if beat == 2 else 1) and (beat == 2 or left[0].remaining == 2 - beat),
			label + ": one beat is spent and the third retires the turret")
		_check(app.party.get_heroes().map(func(hero): return hero.hp) == heroes_hp,
			label + ": the Block-only enemy turn harms no hero")
	var hp_after := _hp()
	var rng_oracle := _oracle()
	await _press_end_turn(keyboard)
	_check(rng_oracle[1].is_empty() and _hp() == hp_after and app.run_rng.state == rng_oracle[3],
		id + ": no fourth shot and no fourth RNG draw")
	await _dispose()


## A turret kill of the last living enemy wins before that enemy retaliates and leaves no pending turret.
func _kill(id: String, keyboard: bool) -> void:
	var damage: int = int(TURRET[id].damage)
	var panel := await _begin(id, "kill", damage)
	if panel == null:
		await _dispose()
		return
	await _play(panel, keyboard)
	_check(app.round_flow.get_turrets().size() == 1, id + ": kill fixture deploys one turret")
	var warden_hp: int = app.party.get_hero(1).hp
	_check(app.enemy_attacks[1].type == "attack", id + ": the last living enemy announces an attack")
	await _press_end_turn(keyboard)
	_check(app.enemies.is_victorious() and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app._battle_closed, id + ": the end-of-turn shot slays the last enemy and closes the battle")
	_check(app.party.get_hero(1).hp == warden_hp, id + ": the slain attacker never retaliates")
	_check(app.round_flow == null or app.round_flow.get_turrets().is_empty(),
		id + ": the closed battle keeps no pending turret")
	await _dispose()


## No pending turret survives into another fight; the new fight's End Turn fires nothing.
func _no_leak(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	await _play(panel, false)
	var old_flow = app.round_flow
	_check(old_flow.get_turrets().size() == 1, id + ": leak fixture deploys one turret")
	app.return_button.pressed.emit()
	await _frames()
	_check(app._start_battle(), id + ": replacement battle starts")
	await _frames()
	_check(app.round_flow != null and not is_same(app.round_flow, old_flow)
		and app.round_flow.get_turrets().is_empty(), id + ": the next fight's round flow holds no turret")
	await _dispose()


## A refused End Turn fires and spends nothing; the retried accepted End Turn fires once.
func _failed_end_turn(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	await _play(panel, true)
	var announced: Array = app.enemy_attacks.duplicate(true)
	app.enemy_attacks = [{"enemy_position": 1, "type": "block", "amount": 9}]
	var before := _model_state()
	await _press_end_turn(false)
	_check(_model_state() == before, id + ": a refused End Turn fires no shot, spends no beat and draws no RNG")
	app.enemy_attacks = announced
	var oracle := _oracle()
	await _press_end_turn(true)
	_check(_hp() == oracle[0] and app.run_rng.state == oracle[3]
		and app.round_flow.get_turrets()[0].remaining == 2, id + ": the retried End Turn fires once")
	await _dispose()


## The exact hits CombatStatuses' canonical rule makes from each printed base (3 and 4): Exposed 1 floors
## 4.5 to 4 (6 for 4), Tangled N>0 adds its flat +2 once whatever N is, and both combine to 6 or 8.
func _status_expectations() -> Dictionary:
	return {
		"tinker_v3_wind_up_turret": {"plain": 3, "tangled": 5, "exposed": 4, "both": 6},
		"tinker_v3_wind_up_turret_plus": {"plain": 4, "tangled": 6, "exposed": 6, "both": 8},
	}


## The expectation row a status map selects: only already-present Exposed/Tangled can change a shot.
func _status_case(statuses: Dictionary) -> String:
	var exposed: int = int(statuses.get("exposed", 0))
	var tangled: int = int(statuses.get("tangled", 0))
	if exposed > 0 and tangled > 0:
		return "both"
	if exposed > 0:
		return "exposed"
	if tangled > 0:
		return "tangled"
	return "plain"


## The status map one enemy owner-turn boundary leaves behind (Bleed/Weak/Exposed/Tangled count down once).
func _aged_statuses(statuses: Dictionary) -> Dictionary:
	var aged: Dictionary = {}
	for name in ["bleed", "weak", "exposed", "tangled"]:
		var count: int = int(statuses.get(name, 0))
		if count > 1:
			aged[name] = count - 1
	return aged


## A genuine paid service deployment plus a real single living enemy at 40 HP behind 2 Block carrying
## `statuses`. Returns [pending state, enemies, run RNG, deck, party].
func _status_fixture(id: String, statuses: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 357
	var deck := CombatDeck.new([id, id, "warden_strike", "warden_brace", "seamstress_mend"], rng)
	_check(deck.start_turn() and deck.hand.count(id) == 2 and deck.energy == 3,
		id + ": the service fixture opens a real five-card hand at three energy")
	var party := CombatParty.new([{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30},
		{"id": "tinker", "name": "Tinker", "max_hp": 26}])
	var deploy: Dictionary = CombatTinkerV3TurretCards.new().play_card(deck, party, id, 0)
	_check(deploy.get("ok") == true and CombatTinkerV3TurretCards.is_pending_instance(deploy.get("state")),
		id + ": the service fixture really pays for and registers a turret")
	var enemies := CombatEnemies.new([{"id": "first", "name": "First", "max_hp": 40}])
	_check(enemies.is_valid() and enemies.gain_block(1, 2),
		id + ": the single-enemy service roster is valid and starts behind 2 Block")
	if not statuses.is_empty():
		enemies._enemies[0]["statuses"] = statuses.duplicate(true)
	return [deploy.get("state", {}), enemies, rng, deck, party]


## AC1 and AC2 at the service level: one authentic paid turret fires once at a single already-status-bearing
## living enemy behind 2 Block; the hit is CombatStatuses' canonical adjustment of the printed base, applied
## through Block before HP, and the statuses are read but never consumed.
func _status_service(id: String) -> void:
	var expected: Dictionary = _status_expectations()[id]
	var base: int = int(TURRET[id].damage)
	var rules := CombatStatuses.new()
	var cases: Array = [
		["no statuses", {}, expected["plain"]],
		["zero Tangled", {"tangled": 0}, expected["plain"]],
		["Tangled 1", {"tangled": 1}, expected["tangled"]],
		["Tangled 2", {"tangled": 2}, expected["tangled"]],
		["Exposed 1", {"exposed": 1}, expected["exposed"]],
		["Exposed 1 and Tangled 1", {"exposed": 1, "tangled": 1}, expected["both"]],
		["Exposed 1 and Tangled 2", {"exposed": 1, "tangled": 2}, expected["both"]],
	]
	for case in cases:
		var statuses: Dictionary = case[1]
		var expected_damage: int = int(case[2])
		var label := "%s service %s" % [id, case[0]]
		var fixture := _status_fixture(id, statuses)
		var state: Dictionary = fixture[0]
		var enemies: CombatEnemies = fixture[1]
		var rng: RandomNumberGenerator = fixture[2]
		var statuses_before: Dictionary = enemies.get_enemy(1).get("statuses", {}).duplicate(true)
		var state_before: Dictionary = state.duplicate(true)
		var rng_before: int = rng.state
		_check(int(enemies.get_enemy(1).get("block")) == 2 and int(enemies.get_enemy(1).get("hp")) == 40,
			label + ": the witness really starts at 40 HP behind 2 Block")
		_check(CombatTinkerV3TurretCards.turret_definition(id).get("effects", {})
			.get("turret", {}).get("damage") == base,
			label + ": the printed catalogue still carries its own base damage")
		var hit: Dictionary = CombatTinkerV3TurretCards.new().tick_turret(state, enemies, rng)
		_check(hit.get("ok") == true and hit.get("reason") == "ticked", label + ": the tick is accepted")
		_check(hit.get("damage") == expected_damage and hit.get("stored_damage") == base,
			label + ": the shot deals " + str(expected_damage) + " from the printed " + str(base))
		_check(rules.adjusted_attack_damage(base, {}, statuses) == expected_damage,
			label + ": CombatStatuses itself computes the same once-only adjustment")
		_check(hit.get("target_position") == 1 and hit.get("target_id") == "first"
			and hit.get("target_statuses") == statuses_before,
			label + ": the sole living enemy is chosen and its status map is quoted")
		_check(hit.get("block_absorbed") == mini(2, expected_damage)
			and hit.get("hp_loss") == expected_damage - mini(2, expected_damage),
			label + ": Block absorbs the first 2 before any HP loss")
		_check(hit.get("enemy_block_before") == 2 and hit.get("enemy_hp_before") == 40
			and hit.get("damage_dealt") == expected_damage,
			label + ": the receipt quotes the pre-hit record and accounts for the whole hit")
		var after: Dictionary = enemies.get_enemy(1)
		_check(after.get("block") == 0 and after.get("hp") == 40 - (expected_damage - 2),
			label + ": exactly " + str(expected_damage - 2) + " HP is lost after 2 Block")
		_check(after.get("statuses", {}) == statuses_before,
			label + ": the shot reads the statuses and never consumes them")
		_check(state == state_before and hit.get("state", {}).get("remaining") == 2,
			label + ": the caller's instance is untouched and exactly one beat is spent")
		_check(rng.state == rng_before and hit.get("rng_consumed") == false,
			label + ": a sole living target costs no RNG")


## AC3 at the service level: a malformed living target status map refuses the whole tick before the target
## RNG, Block, HP or a remaining-beat decrement, and leaves the paid instance and roster exactly as paid.
func _status_refusal(id: String) -> void:
	for bad in [{"exposed": "1"}, {"tangled": -1}, {"exposed": 1.0}, {"weak": true},
			{"poison": 1}, {"dodge_next_attack": 2}, {"cannot_buff_next_turn": false}, [],
			{"tangled": 1, "blind_next_attack": "1"}]:
		var fixture := _status_fixture(id, {})
		var state: Dictionary = fixture[0]
		var enemies: CombatEnemies = fixture[1]
		var rng: RandomNumberGenerator = fixture[2]
		enemies._enemies[0]["statuses"] = bad
		var state_before: Dictionary = state.duplicate(true)
		var roster_before: Array = enemies.get_enemies()
		var rng_before: int = rng.state
		var hit: Dictionary = CombatTinkerV3TurretCards.new().tick_turret(state, enemies, rng)
		var label := "%s bad statuses %s" % [id, str(bad)]
		_check(hit.get("ok") == false and hit.get("reason") == "malformed_statuses",
			label + ": the tick is refused")
		_check(state == state_before and state.get("remaining") == 3, label + ": no beat is spent")
		_check(enemies.get_enemies() == roster_before, label + ": Block, HP and the bad map are untouched")
		_check(int(enemies.get_enemy(1).get("hp")) == 40 and int(enemies.get_enemy(1).get("block")) == 2,
			label + ": no HP and no Block change")
		_check(rng.state == rng_before, label + ": the target RNG is never drawn")


## AC3: a status-adjusted confirmed shot is still exactly one Enrage stack on the catalog Spoolback Hound,
## with the status read but not consumed.
func _status_enrage(id: String) -> void:
	var fixture := _status_fixture(id, {})
	var state: Dictionary = fixture[0]
	var rng: RandomNumberGenerator = fixture[2]
	var enemies := CombatEnemies.new([_catalog_hound()])
	_check(enemies.is_valid() and enemies.get_enemy(1).get("enrage") == true
		and enemies.gain_block(1, 2), id + ": the Enrage status fixture is the catalog Hound behind 2 Block")
	enemies._enemies[0]["statuses"] = {"tangled": 1}
	var expected: int = int(_status_expectations()[id]["tangled"])
	var hit: Dictionary = CombatTinkerV3TurretCards.new().tick_turret(state, enemies, rng)
	_check(hit.get("ok") == true and hit.get("damage") == expected
		and hit.get("block_absorbed") == 2 and hit.get("hp_loss") == expected - 2,
		id + ": the status-adjusted shot still lands through Block first")
	_check(enemies.get_enemy(1).get("enrage_stacks") == 1
		and enemies.get_enemy(1).get("hp") == 28 - (expected - 2)
		and enemies.get_enemy(1).get("statuses") == {"tangled": 1},
		id + ": one status-adjusted positive shot commits exactly one Enrage stack and consumes no status")


## AC1 and AC2 on the real mounted path: one accepted End Turn fires the authentic turret at a single
## already-status-bearing living enemy behind 2 Block, before that enemy's announced Block action.
func _status_mounted(id: String, statuses: Dictionary, keyboard: bool) -> void:
	var case_name := _status_case(statuses)
	var expected: int = int(_status_expectations()[id][case_name])
	var panel := await _begin(id, "status")
	if panel == null:
		await _dispose()
		return
	app.enemies._enemies[0]["statuses"] = statuses.duplicate(true)
	var label := "%s mounted %s" % [id, case_name]
	await _play(panel, keyboard)
	_check(app.round_flow.get_turrets().size() == 1 and app.deck.energy == 1,
		label + ": the held turret is paid and registered through the real hand")
	var enemy: Dictionary = app.enemies.get_enemy(1)
	_check(enemy.get("hp") == 40 and enemy.get("block") == 2 and enemy.get("statuses") == statuses,
		label + ": the witness starts at 40 HP behind 2 Block with its statuses already present")
	var oracle := _oracle()
	var receipt: Dictionary = oracle[4][0]
	await _press_end_turn(keyboard)
	_check(app.deck.turn_active and _hp() == oracle[0],
		label + ": the accepted End Turn lands the oracle's exact HP")
	_check(oracle[1] == [1] and receipt.get("damage") == expected and receipt.get("block_absorbed") == 2,
		label + ": the shot deals " + str(expected) + " and only the first 2 Block are absorbed")
	_check(receipt.get("hp_loss") == expected - 2
		and app.enemies.get_enemy(1).get("hp") == 40 - (expected - 2),
		label + ": exactly " + str(expected - 2) + " HP is lost after Block")
	_check(app.enemies.get_enemy(1).get("block") == 1,
		label + ": the enemy's own announced Block lands only after the fuller shot")
	_check(receipt.get("rng_consumed") == false and receipt.get("target_statuses") == statuses,
		label + ": the sole living target costs no RNG and its statuses are read once")
	_check(app.enemies.get_enemy(1).get("statuses") == _aged_statuses(statuses),
		label + ": the turret consumes no status; only the enemy owner-turn boundary ages one")
	_check(app.deck.hand == oracle[2] and app.run_rng.state == oracle[3],
		label + ": the shot precedes the same seeded next hand")
	var left: Array = app.round_flow.get_turrets()
	_check(left.size() == 1 and left[0].remaining == 2 and left[0].damage == int(TURRET[id].damage)
		and left[0].card_id == id, label + ": one beat is spent and the printed base stays stored")
	await _dispose()


## AC3 on the mounted path: a malformed target status map refuses the real End Turn with no shot, no spent
## beat, no HP/Block change and no RNG draw.
func _status_mounted_refusal(id: String) -> void:
	var panel := await _begin(id, "status")
	if panel == null:
		await _dispose()
		return
	await _play(panel, false)
	app.enemies._enemies[0]["statuses"] = {"tangled": "2"}
	var before := _model_state()
	await _press_end_turn(false)
	_check(app.enemies.get_enemy(1).get("hp") == 40 and app.enemies.get_enemy(1).get("block") == 2,
		id + ": a refused mounted End Turn leaves the witness HP and Block untouched")
	_check(_model_state() == before and app.round_flow.get_turrets().size() == 1
		and app.round_flow.get_turrets()[0].remaining == 3,
		id + ": a malformed target status map refuses the mounted End Turn with no shot, beat or RNG")
	await _dispose()


## AC3: stale, displaced, unheld, underfunded, closed or forged requests never pay, register or draw.
## Stage 0 mutates before the press; stage 1 mutates while the press is armed and waiting for release;
## stage 2 mutates after a keyboard accept is queued but before its deferred activation.
func _reject(id: String, mode: String, stage: int) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var source: Callable = presenter._bindings[panel]
	if stage == 1:
		_mouse_half(panel, true)
		_check(not presenter._pending.is_empty(), "the press arms one pending turret request")
	elif stage == 2:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
	match mode:
		"energy": app.deck.combat_state.energy = 1
		"downed": app.party.apply_damage(3, 1000)
		"missing": app.party._heroes[2].id = "scarecrow"
		"displaced":
			var middle: Dictionary = app.party._heroes[1]
			var back: Dictionary = app.party._heroes[2]
			app.party._heroes[1] = back
			app.party._heroes[2] = middle
			app.party._heroes[1].position = 2
			app.party._heroes[2].position = 3
		"unheld":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"forged": panel.get_child(0).text = "tinker_v3_wind_up_turret_fake"
		"end_turn": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"result": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"flow": app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
		"ended":
			for position in [1, 2, 3]:
				app.enemies.apply_damage(position, 1000)
			# The app's own observer closes the won battle; the stale request must still spend nothing.
			app.battle_result.evaluate()
			app._observe_battle_result()
		"invalid_turret":
			var forged: Dictionary = CombatTinkerV3TurretCards.new().play_card(app.deck, app.party, id, 0).state
			app.round_flow._turrets.append(forged.merged({"damage": 99}, true))
		"rebuild": app._refresh_hand()
		"hero_replaced": app.party._heroes[0] = app.party._heroes[0].duplicate(true)
		"rng": app.run_rng.randi()
		"cancel": presenter.cancel_button.pressed.emit()
		"escape": await _keyboard(KEY_ESCAPE)
	var before := _model_state()
	if stage == 0:
		source.call(_press())
		_mouse_half(panel if is_instance_valid(panel) else app.end_turn_button, false)
	elif stage == 1:
		_mouse_half(panel if is_instance_valid(panel) else app.end_turn_button, false)
	else:
		root.push_input(_key(KEY_ENTER, false), true)
	await _frames()
	await _frames()
	_check(_model_state() == before and presenter._pending.is_empty(),
		"%s: invalid or cancelled %s at stage %d does not pay, register, fire or draw RNG" % [id, mode, stage])
	await _dispose()


## Mouse and keyboard cancellation leave no trace, a retired callback is inert, and a fresh retry pays once.
func _cancel_retry(id: String, keyboard: bool) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var source: Callable = presenter._bindings[panel]
	var before := _model_state()
	_mouse_half(panel, true)
	if keyboard:
		await _keyboard(KEY_ESCAPE)
	else:
		presenter.cancel_button.pressed.emit()
	_mouse_half(panel, false)
	await _frames()
	_check(_model_state() == before and presenter._pending.is_empty(),
		id + ": a cancelled turret request spends nothing")
	await _play(_panel(id), keyboard)
	_check(app.deck.energy == 1 and app.round_flow.get_turrets().size() == 1,
		id + ": a fresh retry pays once and registers one turret")
	before = _model_state()
	source.call(_press())
	_mouse_half(app.end_turn_button, false)
	await _frames()
	_check(_model_state() == before, id + ": a duplicate retired callback cannot pay or register again")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var keyboard := false
	for id: String in TURRET:
		_status_service(id)
		_status_refusal(id)
		_status_enrage(id)
		for statuses in [{}, {"tangled": 2}, {"exposed": 1}, {"exposed": 1, "tangled": 1}]:
			var statuses_map: Dictionary = statuses
			await _status_mounted(id, statuses_map, keyboard if statuses.is_empty() else not keyboard)
		await _status_mounted_refusal(id)
		await _success(id, keyboard)
		await _success(id, not keyboard)
		await _hound(id, keyboard)
		await _hound(id, not keyboard)
		await _kill(id, keyboard)
		await _no_leak(id)
		await _failed_end_turn(id)
		await _cancel_retry(id, false)
		await _cancel_retry(id, true)
		for mode in ["energy", "downed", "missing", "displaced", "unheld", "forged", "end_turn",
				"closed", "result", "flow", "ended", "invalid_turret", "rebuild"]:
			for stage in [0, 1, 2]:
				await _reject(id, mode, stage)
		# A replaced hero record or an advanced RNG is only stale for an already armed request.
		for mode in ["hero_replaced", "rng", "cancel", "escape"]:
			for stage in [1, 2]:
				await _reject(id, mode, stage)
		keyboard = not keyboard
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_tinker_v3_turret_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## The authored catalog Spoolback Hound (enrage: true), with JSON's float max_hp normalized as the app does.
func _catalog_hound() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary and entry.get("id") == "spoolback_hound":
				var hound: Dictionary = entry.duplicate(true)
				hound["max_hp"] = int(hound["max_hp"])
				return hound
	return {}


## Cycle 363 AC1: a real held turret played by mouse or keyboard, then real End Turns against the catalog Hound
## (2 Block at the start): every shot adds one Enrage stack before the Hound's attack, which gains +2 per stack.
func _hound(id: String, keyboard: bool) -> void:
	var panel := await _begin(id, "hound")
	if panel == null:
		await _dispose()
		return
	var damage: int = int(TURRET[id].damage)
	_check(app.enemies.get_enemy(1).get("enrage") == true and app.enemies.get_enemy(1).get("block") == 2,
		id + ": the live roster is the catalog Spoolback Hound behind 2 Block")
	await _play(panel, keyboard)
	_check(app.round_flow.get_turrets().size() == 1 and app.deck.energy == 1,
		id + ": the held turret is paid and registered through the real hand")
	var hp: int = 28
	for beat in range(2):
		var label := "%s Hound beat %d" % [id, beat + 1]
		var oracle := _oracle()
		app.party._heroes[0]["block"] = 0
		var warden: int = app.party.get_hero(1).hp
		await _press_end_turn(keyboard == (beat % 2 == 0))
		hp -= damage - (2 if beat == 0 else 0)
		var hound: Dictionary = app.enemies.get_enemy(1)
		_check(app.deck.turn_active and _hp() == oracle[0] and hound.hp == hp and app.run_rng.state == oracle[3],
			label + ": the shot lands through Block exactly as the resolver rules")
		_check(hound.get("enrage_stacks") == beat + 1, label + ": the shot adds exactly one Enrage stack")
		_check(warden - app.party.get_hero(1).hp == 7 + 2 * (beat + 1),
			label + ": the Hound's attack that turn gains +2 per stack")
	await _dispose()
