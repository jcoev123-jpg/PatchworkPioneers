extends SceneTree

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_ordered_specials()
	_test_status_sensitive_attacks()
	_test_two_turn_mixed_phase()
	_test_dead_sources_and_downed_targets()
	_test_rejections()
	_test_replay_and_empty()
	if failures.is_empty():
		print("combat_enemy_phase_test: PASS (", checks, " checks)")
	else:
		for message in failures:
			printerr(message)
		print("combat_enemy_phase_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"precondition: three actual hero slots")
	return party


func _enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "ragling-a", "max_hp": 12},
		{"id": "ragling-b", "max_hp": 15}])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2
		and enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(2)["hp"] == 15,
		"precondition: two independent occupied enemy slots")
	return enemies


func _attack(source: int, amount: int, target: int) -> Dictionary:
	return {"type": "attack", "enemy_position": source,
		"amount": amount, "target_position": target}


func _block(source: int, amount: int) -> Dictionary:
	return {"type": "block", "enemy_position": source, "amount": amount}


func _event(kind: String, source: int, applied: bool, target: int = 0) -> Dictionary:
	var event := {"type": kind, "enemy_position": source, "applied": applied}
	if kind == "attack":
		event["target_position"] = target
	return event


func _scheduler() -> CombatEnemyIntents:
	# Reverse author order to ensure the public scheduler uses source positions.
	var scheduler := CombatEnemyIntents.new([
		{"enemy_position": 2, "pattern": [
			{"type": "block", "amount": 4},
			{"type": "attack", "amount": 5, "target_position": 2}]},
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 9, "target_position": 1},
			{"type": "block", "amount": 3}]}])
	_check(scheduler.is_valid() and scheduler.get_intents().size() == 2,
		"precondition: two genuine independently cycling enemy intents")
	return scheduler


func _test_two_turn_mixed_phase() -> void:
	_check(phase.has_method("execute_phase"), "public phase method exists")
	var party := _party()
	var enemies := _enemies()
	var scheduler := _scheduler()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden receives real opening Block 6 service")
	var turn_zero := scheduler.get_intents()
	var initial_intents := turn_zero.duplicate(true)
	_check(turn_zero == [_attack(1, 9, 1), _block(2, 4)],
		"turn zero announces one attack and one Block from real scheduler")
	# Also prove phase sorts an independently shuffled input without editing it.
	turn_zero.reverse()
	var shuffled := turn_zero.duplicate(true)
	var result := phase.execute_phase(party, enemies, turn_zero)
	_check(result == {"ok": true, "events": [
		_event("attack", 1, true, 1), _event("block", 2, true)]},
		"AC1: mixed actions resolve in source 1-then-2 order")
	_check(party.get_hero(1)["hp"] == 37 and party.get_hero(1)["block"] == 0
		and party.get_hero(2)["hp"] == 30 and party.get_hero(3)["hp"] == 26,
		"AC1: six Block absorbs first six of nine, Warden falls to 37 HP")
	_check(enemies.get_enemy(1)["block"] == 0 and enemies.get_enemy(2)["block"] == 4
		and enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(2)["hp"] == 15,
		"AC1: only source 2 gains exactly four enemy Block")
	_check(turn_zero == shuffled and scheduler.get_intents() == initial_intents,
		"phase never modifies caller records or advances scheduler")
	var first_heroes := party.get_heroes()
	var first_enemies := enemies.get_enemies()
	_check(scheduler.advance_turn(), "only caller advances the fixed-cycle scheduler")
	_check(party.get_heroes() == first_heroes and enemies.get_enemies() == first_enemies,
		"advancing announcements alone cannot alter combat state")
	var turn_one := scheduler.get_intents()
	_check(turn_one == [_block(1, 3), _attack(2, 5, 2)],
		"AC2: next announced mix changes both enemies' kinds")
	var original := turn_one.duplicate(true)
	result = phase.execute_phase(party, enemies, turn_one)
	_check(result == {"ok": true, "events": [
		_event("block", 1, true), _event("attack", 2, true, 2)]},
		"AC2: second phase dispatches Block and attack exactly once")
	_check(party.get_hero(1)["hp"] == 37 and party.get_hero(1)["block"] == 0
		and party.get_hero(2)["hp"] == 25 and party.get_hero(2)["block"] == 0
		and party.get_hero(3)["hp"] == 26,
		"AC2: Seamstress falls from 30 to 25 without unintended reset or damage")
	_check(enemies.get_enemy(1)["block"] == 3 and enemies.get_enemy(2)["block"] == 4,
		"AC2: enemy 1 gains three Block; prior enemy 2 Block persists")
	_check(turn_one == original and scheduler.get_intents() == original,
		"AC2: phase neither changes announced inputs nor advances the turn")
	_check(scheduler.advance_turn() and scheduler.get_intents() == initial_intents,
		"only an explicit second caller advance wraps the authored pattern")


func _test_dead_sources_and_downed_targets() -> void:
	var party := _party()
	var enemies := _enemies()
	var scheduler := _scheduler()
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1)
		and not enemies.is_slain(2), "precondition: source 1 slain and source 2 living")
	var dead_before := enemies.get_enemy(1)
	var first := scheduler.get_intents()
	var result := phase.execute_phase(party, enemies, first)
	_check(result == {"ok": true, "events": [
		_event("attack", 1, false, 1), _event("block", 2, true)]},
		"dead first attacker is skipped but living second blocker executes")
	_check(party.get_heroes() == _party_snapshot() and enemies.get_enemy(1) == dead_before
		and enemies.get_enemy(2)["block"] == 4,
		"dead source cannot damage heroes or gain Block")
	_check(scheduler.advance_turn(), "caller advances dead-source fixture")
	result = phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result == {"ok": true, "events": [
		_event("block", 1, false), _event("attack", 2, true, 2)]},
		"dead Block skipped; living second attacker still acts")
	_check(enemies.get_enemy(1) == dead_before and enemies.get_enemy(2)["block"] == 4
		and party.get_hero(2)["hp"] == 25,
		"dead source is inert in either kind, living source applies attack")

	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(2, 30) and party.is_downed(2)
		and party.gain_block(3, 7), "precondition: downed target and protected other hero")
	var hero_before := party.get_heroes()
	result = phase.execute_phase(party, enemies, [_block(2, 4), _attack(1, 9, 2)])
	_check(result == {"ok": true, "events": [
		_event("attack", 1, false, 2), _event("block", 2, true)]},
		"attack against downed slot is not retargeted; living Block still works")
	_check(party.get_heroes() == hero_before and enemies.get_enemy(2)["block"] == 4,
		"no healing, retargeting, HP or Block changes for any hero")
	_check(enemies.apply_damage(1, 12) and enemies.apply_damage(2, 19)
		and enemies.is_slain(1) and enemies.is_slain(2),
		"precondition: both enemies truly slain even through prior Block")
	var all_dead := enemies.get_enemies()
	hero_before = party.get_heroes()
	result = phase.execute_phase(party, enemies, [_block(2, 3), _attack(1, 100, 1)])
	_check(result == {"ok": true, "events": [
		_event("attack", 1, false, 1), _event("block", 2, false)]},
		"all slain sources produce ordered skipped events")
	_check(party.get_heroes() == hero_before and enemies.get_enemies() == all_dead,
		"all-slain phase is entirely nonmutating")

	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(1, 31), "precondition: first later hit will down Warden")
	result = phase.execute_phase(party, enemies, [_attack(2, 5, 1), _attack(1, 9, 1)])
	_check(result == {"ok": true, "events": [
		_event("attack", 1, true, 1), _event("attack", 2, false, 1)]},
		"sequential living attacks respect earlier lethal damage, with no retarget")
	_check(party.is_downed(1) and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["hp"] == 26,
		"second attack cannot revive or damage another hero after first lethal hit")


func _party_snapshot() -> Array:
	# Full untouched starter party, for the slain-attacker check.
	return CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}]).get_heroes()


func _reject(name: String, intents: Array) -> void:
	var party := _party()
	var enemies := _enemies()
	_check(party.apply_damage(3, 2) and party.gain_block(1, 6)
		and enemies.apply_damage(1, 2) and enemies.gain_block(2, 3),
		name + ": rejection precondition has nontrivial HP and Block")
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var before_intents := intents.duplicate(true)
	_check(phase.execute_phase(party, enemies, intents) == {"ok": false, "events": []},
		name + ": invalid batch fails closed")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		name + ": no partial mutation of any hero or enemy")
	_check(intents == before_intents, name + ": caller dictionaries/ordering untouched")


func _test_rejections() -> void:
	var party := _party()
	var enemies := _enemies()
	_check(phase.execute_phase(null, enemies, [_block(1, 2)]) == {"ok": false, "events": []},
		"null party rejected")
	_check(enemies.get_enemies() == _enemies_snapshot(), "null party leaves live roster alone")
	_check(phase.execute_phase(party, null, [_attack(1, 2, 1)]) == {"ok": false, "events": []},
		"null enemies rejected")
	_check(party.get_heroes() == _party_snapshot(), "null enemies leaves live party alone")
	var invalid_party := CombatParty.new([])
	var invalid_enemies := CombatEnemies.new([])
	_check(not invalid_party.is_valid() and not invalid_enemies.is_valid(),
		"precondition: deliberately invalid combat models")
	_check(phase.execute_phase(invalid_party, enemies, [_block(1, 1)]) ==
		{"ok": false, "events": []} and enemies.get_enemies() == _enemies_snapshot(),
		"invalid party leaves valid enemies unchanged")
	_check(phase.execute_phase(party, invalid_enemies, [_attack(1, 1, 1)]) ==
		{"ok": false, "events": []} and party.get_heroes() == _party_snapshot(),
		"invalid roster leaves valid party unchanged")

	var bad_entries: Array = [
		null, {}, [], "attack", 23,
		{"enemy_position": 2, "amount": 4},
		{"type": "block", "enemy_position": 2},
		{"type": "attack", "enemy_position": 2, "amount": 5},
		{"type": "block", "enemy_position": 2, "amount": 4, "target_position": 1},
		{"type": "attack", "enemy_position": 2, "amount": 5, "target_position": 2, "extra": 1},
		{"type": "block", "enemy_position": 2, "amount": 4, "extra": true},
		{"type": "heal", "enemy_position": 2, "amount": 3},
		{"type": 1, "enemy_position": 2, "amount": 3},
		{"type": null, "enemy_position": 2, "amount": 3},
		{"type": "attack", "enemy_position": 1, "amount": 5, "target_position": 2},
		_attack(3, 1, 1),
		_block(0, 1),
		_block(-1, 1),
		_attack(2, -1, 1),
		_block(2, -1),
		_attack(2, 5, 0),
		_attack(2, 5, 4)]
	for field in ["enemy_position", "amount", "target_position"]:
		for value in [null, true, false, "2", 2.0, [], {}]:
			var attack := _attack(2, 5, 2)
			attack[field] = value
			bad_entries.append(attack)
		if field != "target_position":
			for value in [null, true, false, "2", 2.0, [], {}]:
				var block := _block(2, 4)
				block[field] = value
				bad_entries.append(block)
	for bad in bad_entries:
		_reject("invalid second action " + str(bad), [_attack(1, 9, 1), bad])
	_reject("duplicate attack and Block sources", [_attack(1, 9, 1), _block(1, 4)])
	_reject("out-of-roster second source", [_attack(1, 9, 1), _block(3, 4)])

	party = _party()
	enemies = _enemies()
	_check(party.gain_block(1, 6)
		and enemies.gain_block(2, CombatEnemies.MAX_INT - 3),
		"precondition: second living enemy near maximum Block")
	var heroes_before := party.get_heroes()
	var enemies_before := enemies.get_enemies()
	var overflow := [_attack(1, 9, 1), _block(2, 4)]
	var original := overflow.duplicate(true)
	_check(phase.execute_phase(party, enemies, overflow) == {"ok": false, "events": []},
		"AC4: late living-source Block overflow rejects entire mixed batch")
	_check(party.get_heroes() == heroes_before and enemies.get_enemies() == enemies_before,
		"AC4: earlier valid attack cannot partially land before Block overflow")
	_check(overflow == original, "overflow rejection does not alter input")


func _enemies_snapshot() -> Array:
	return CombatEnemies.new([
		{"id": "ragling-a", "max_hp": 12},
		{"id": "ragling-b", "max_hp": 15}]).get_enemies()


func _test_replay_and_empty() -> void:
	var expected_events: Array = []
	var expected_heroes: Array = []
	var expected_enemies: Array = []
	var expected_schedule: Array = []
	for repetition in range(4):
		var party := _party()
		var enemies := _enemies()
		var scheduler := _scheduler()
		var opening := CombatStartingBlock.new(party)
		_check(opening.apply(), "replay begins with real opening Block service")
		var events: Array = []
		events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		_check(scheduler.advance_turn(), "replay explicitly advances scheduler once")
		events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		var snapshot_heroes := party.get_heroes()
		var snapshot_enemies := enemies.get_enemies()
		var snapshot_schedule := scheduler.get_intents()
		_check(events == [
			{"ok": true, "events": [_event("attack", 1, true, 1), _event("block", 2, true)]},
			{"ok": true, "events": [_event("block", 1, true), _event("attack", 2, true, 2)]}],
			"replay produces exact expected per-phase events")
		_check(snapshot_heroes[0]["hp"] == 37 and snapshot_heroes[1]["hp"] == 25
			and snapshot_heroes[2]["hp"] == 26
			and snapshot_enemies[0]["block"] == 3 and snapshot_enemies[1]["block"] == 4,
			"replay snapshots are independently asserted before comparison")
		if repetition == 0:
			expected_events = events.duplicate(true)
			expected_heroes = snapshot_heroes
			expected_enemies = snapshot_enemies
			expected_schedule = snapshot_schedule
		else:
			_check(events == expected_events and snapshot_heroes == expected_heroes
				and snapshot_enemies == expected_enemies and snapshot_schedule == expected_schedule,
				"identical fresh combat models and scheduler replay deterministically")
		_check(phase.execute_phase(party, enemies, []) == {"ok": true, "events": []}
			and party.get_heroes() == snapshot_heroes
			and enemies.get_enemies() == snapshot_enemies
			and scheduler.get_intents() == snapshot_schedule,
			"empty valid batch is harmless and never advances scheduler")


func _test_status_sensitive_attacks() -> void:
	for special in ["shove", "debuff"]:
		var party := _party()
		var enemies := CombatEnemies.new([
			{"id": "first", "max_hp": 12}, {"id": "second", "max_hp": 15},
			{"id": "third", "max_hp": 10}])
		_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
			"status fixture has three living ordered sources")
		var warden: Dictionary = party._heroes[0]
		var seamstress: Dictionary = party._heroes[1]
		var blocker: Dictionary = enemies._enemies[2]
		warden["statuses"] = {"weak": 2}
		seamstress["statuses"] = {"exposed": 2}
		enemies._enemies[1]["statuses"] = {"weak": 2}
		_check(party.gain_block(1, 2) and party.gain_block(2, 2), "status fixture has real absorption")
		var first := {"type": "shove", "enemy_position": 1, "amount": 0,
			"target_position": 1, "direction": 1} if special == "shove" else {
			"type": "debuff", "enemy_position": 1, "amount": 2,
			"target_position": 1, "status": "exposed"}
		var actions := [_block(3, 4), _attack(2, 5, 1), first]
		var input := actions.duplicate(true)
		var result := phase.execute_phase(party, enemies, actions)
		var first_event := first.duplicate(true)
		first_event.erase("amount")
		first_event["applied"] = true
		_check(result == {"ok": true, "events": [first_event,
			_event("attack", 2, true, 1), _event("block", 3, true)]},
			"special, adjusted attack and Block preserve exact public event order")
		# floor(5 * 3/4 * 3/2) = 5, rather than floor(floor(5 * 3/4) * 3/2) = 4.
		_check(party.get_hero(1).hp == (27 if special == "shove" else 37)
			and party.get_hero(1).block == 0 and party.get_hero(2).block == 2
			and party.get_hero(2).hp == (40 if special == "shove" else 30)
			and party.get_hero(3).hp == 26 and enemies.get_enemy(3).block == 4,
			"attack uses current actor statuses after " + special + " and floors once through two Block")
		_check(is_same(party._heroes[0], seamstress if special == "shove" else warden)
			and is_same(party._heroes[1], warden if special == "shove" else seamstress)
			and is_same(enemies._enemies[2], blocker), "successful commit preserves original actor dictionaries")
		_check(warden.statuses == ({"weak": 2} if special == "shove" else {"weak": 2, "exposed": 2})
			and seamstress.statuses == {"exposed": 2} and actions == input,
			"statuses stay actor-bound and caller intents remain unchanged")
		# Fail after a staged special and attack, not just during up-front validation.
		_check(enemies.gain_block(3, CombatEnemies.MAX_INT - 4), "later Block reaches exact capacity")
		var before := [party.get_heroes(), enemies.get_enemies()]
		_check(phase.execute_phase(party, enemies, actions) == {"ok": false, "events": []}
			and [party.get_heroes(), enemies.get_enemies()] == before,
			"late delegated overflow rolls back staged special, statuses, positions and damage")
		_check(is_same(party._heroes[0], seamstress if special == "shove" else warden)
			and is_same(enemies._enemies[2], blocker), "rejection retains dictionary identity")


func _test_ordered_specials() -> void:
	var party := _party()
	var enemies := _enemies()
	party._heroes[0]["statuses"] = {"weak": 2}
	var shove := {"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 1, "direction": 1}
	var debuff := {"type": "debuff", "enemy_position": 2, "amount": 2, "target_position": 1, "status": "exposed"}
	_check(phase.execute_phase(party, enemies, [debuff, shove]).ok, "mixed phase sorts source order")
	_check(party.get_hero(1).id == "seamstress" and party.get_hero(1).statuses == {"exposed": 2}
		and party.get_hero(2).statuses == {"weak": 2}, "swap then bind preserves actor statuses")
	var before := [party.get_heroes(), enemies.get_enemies()]
	_check(not phase.execute_phase(party, enemies, [shove, shove]).ok
		and [party.get_heroes(), enemies.get_enemies()] == before, "duplicate mixed source atomic")
	_check(not phase.execute_phase(party, enemies, [_attack(1, 999, 1), debuff]).ok
		and [party.get_heroes(), enemies.get_enemies()] == before, "earlier lethal attack makes late debuff illegal atomically")
	_check(not phase.execute_phase(party, enemies, [_attack(1, 1, 1), {"type": "shove", "enemy_position": 2,
		"amount": 0, "target_position": 3, "direction": 1}]).ok
		and [party.get_heroes(), enemies.get_enemies()] == before, "late illegal shove atomic")
