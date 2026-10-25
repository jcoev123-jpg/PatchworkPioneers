extends SceneTree

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_ordered_specials()
	_test_status_sensitive_attacks()
	_test_two_turn_mixed_phase()
	_test_dead_sources_and_downed_targets()
	_test_policy_targets()
	_test_enrage_attack_bonus()
	_test_enrage_status_and_replay()
	_test_enrage_legacy_and_fail_closed()
	_test_drain_after_confirmed_hit()
	_test_drain_inert_and_fail_closed()
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


## Two authored-policy sources; the executor only retargets when the caller
## declares the announcements battle-bound, so they keep the exact published
## action shape.
func _policy_enemies(policy: String) -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "ragling-a", "max_hp": 12,
			"intent": {"target": policy, "actions": [{"type": "block", "amount": 1}]}},
		{"id": "ragling-b", "max_hp": 15,
			"intent": {"target": policy, "actions": [{"type": "block", "amount": 1}]}}])
	_check(enemies.is_valid(), "precondition: two authored-policy sources")
	return enemies


## AC3: a cached policy announcement whose hero is down before its beat falls
## back to a deterministic living target, without fresh RNG. A legacy schedule
## keeps its exact original inert-target behavior even over the same roster.
func _test_policy_targets() -> void:
	var party := _party()
	var enemies := _policy_enemies("lowest_living_hp")
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"precondition: announced middle hero is already downed")
	var result := phase.execute_phase(party, enemies, [_attack(1, 5, 2)], null, true)
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true}]},
		"downed announced target falls back to the policy`s living choice")
	_check(party.get_hero(3)["hp"] == 21 and party.get_hero(1)["hp"] == 40,
		"only the fallback target loses the announced damage")
	_check(not party.get_hero(3).has("statuses"),
		"fallback applies no statuses of its own")

	# A hero downed by an earlier action in the same batch also falls back.
	party = _party()
	enemies = _policy_enemies("front")
	result = phase.execute_phase(party, enemies, [_attack(1, 99, 1), _attack(2, 5, 1)], null, true)
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}]},
		"same-batch lethal hit makes the later announced target fall back to the next living hero")
	_check(party.is_downed(1) and party.get_hero(2)["hp"] == 25,
		"the fallback attack lands on the living middle hero after the lethal hit")

	# An announced debuff retargets the fallen hero instead of failing.
	party = _party()
	enemies = _policy_enemies("front")
	result = phase.execute_phase(party, enemies, [_attack(1, 99, 1),
		{"type": "debuff", "enemy_position": 2, "amount": 2, "target_position": 1, "status": "weak"}],
		null, true)
	_check(result.get("ok") == true and result["events"].size() == 2
		and result["events"][1]["target_position"] == 2 and result["events"][1]["status"] == "weak",
		"policy debuff retargets a hero downed earlier in the same batch")
	_check(party.is_downed(1) and party.get_hero(2).get("statuses", {}) == {"weak": 2},
		"the status lands on the living fallback hero only")

	# A policy shove keeps its authored push when a living neighbour exists.
	party = _party()
	enemies = _policy_enemies("front")
	_check(party.apply_damage(1, 40), "precondition: only the front hero is downed")
	result = phase.execute_phase(party, enemies, [{"type": "shove", "enemy_position": 1,
		"amount": 0, "target_position": 1, "direction": 1}], null, true)
	_check(result.get("ok") == true and result["events"][0]["applied"] == true
		and result["events"][0]["target_position"] == 2
		and result["events"][0]["direction"] == 1,
		"fallback shove pushes the front living neighbour toward the back")
	_check(party.get_hero(2)["id"] == "tinker" and party.get_hero(3)["id"] == "seamstress",
		"the fallback shove swaps the two living heroes and keeps fixed slots")
	# With no living neighbour at all the announced beat is inert, not a failure.
	party = _party()
	enemies = _policy_enemies("front")
	_check(party.apply_damage(1, 40) and party.apply_damage(2, 30),
		"precondition: only the back hero still lives")
	var alone := party.get_heroes()
	result = phase.execute_phase(party, enemies, [{"type": "shove", "enemy_position": 1,
		"amount": 0, "target_position": 1, "direction": 1}], null, true)
	_check(result.get("ok") == true and result["events"][0]["applied"] == false
		and party.get_heroes() == alone,
		"a policy shove with no living neighbour stays an inert ordered beat")
	# A legacy schedule over the same authored roster never retargets: only the
	# bound scheduler's own announcements opt into the policy fallback.
	party = _party()
	enemies = _policy_enemies("front")
	_check(party.apply_damage(2, 30), "precondition: legacy schedule target downed")
	var legacy_roster := phase.execute_phase(party, enemies, [_attack(1, 5, 2)])
	_check(legacy_roster == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false}]}
		and party.get_hero(2)["hp"] == 0 and party.get_hero(1)["hp"] == 40,
		"a legacy schedule keeps its exact announced target on a policy roster")
	# A roster without authored intentions keeps the exact legacy inert target.
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(2, 30), "precondition: legacy roster target downed")
	var legacy := phase.execute_phase(party, _enemies(), [_attack(1, 5, 2)], null, true)
	_check(legacy == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false}]},
		"a roster without an authored policy never retargets")
	# A forged extra key is still rejected atomically by the action contract.
	party = _party()
	enemies = _policy_enemies("front")
	var heroes_before := party.get_heroes()
	var enemy_before := enemies.get_enemies()
	var forged := _attack(1, 5, 1)
	forged["extra"] = 1
	_check(phase.execute_phase(party, enemies, [forged], null, true) == {"ok": false, "events": []}
		and party.get_heroes() == heroes_before and enemies.get_enemies() == enemy_before,
		"a forged announcement rejects without mutations")


func _enrage_roster(definitions: Array) -> CombatEnemies:
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == definitions.size(),
		"precondition: real Enrage roster occupies its authored living slots")
	return enemies


## AC1: a living Enrage source's stored stacks add exactly +2 per stack to its
## own announced attack before any status modifier, and the beat awards nothing.
func _test_enrage_attack_bonus() -> void:
	for stacks in [0, 1, 2, 3]:
		var party := _party()
		var enemies := _enrage_roster([
			{"id": "patch-imp", "max_hp": 20, "enrage": true, "enrage_stacks": stacks},
			{"id": "ragling-a", "max_hp": 15}])
		_check(enemies.get_enemy(1).get("enrage") == true
			and enemies.get_enemy(1).get("enrage_stacks") == stacks
			and not enemies.get_enemy(2).has("enrage"),
			"AC1 precondition: source 1 authors Enrage at " + str(stacks)
				+ " stacks and source 2 authors none")
		_check(party.gain_block(1, 20) and party.gain_block(2, 20),
			"AC1 precondition: both announced recipients carry real absorbing Block")
		var warden: Dictionary = party._heroes[0]
		var seamstress: Dictionary = party._heroes[1]
		var source_record: Dictionary = enemies._enemies[0]
		var sibling_record: Dictionary = enemies._enemies[1]
		var intents := [_attack(2, 5, 2), _attack(1, 5, 1)]
		var input := intents.duplicate(true)
		var result := phase.execute_phase(party, enemies, intents)
		_check(result == {"ok": true, "events": [
			_event("attack", 1, true, 1), _event("attack", 2, true, 2)]},
			"AC1: an Enrage beat keeps the exact ordered ordinary event shape")
		_check(party.get_hero(1)["block"] == 20 - (5 + stacks * 2)
			and party.get_hero(1)["hp"] == 40,
			"AC1: the Enrage source really deals " + str(5 + stacks * 2)
				+ " before any status modifier")
		_check(party.get_hero(2)["block"] == 15 and party.get_hero(2)["hp"] == 30,
			"AC1: the non-Enrage sibling still deals exactly its announced five")
		_check(enemies.get_enemy(1) == source_record
			and enemies.get_enemy(2) == sibling_record,
			"AC1: the phase awards no stack and touches neither roster record")
		_check(is_same(party._heroes[0], warden) and is_same(party._heroes[1], seamstress),
			"AC1: publication keeps the original hero dictionaries")
		_check(intents == input, "AC1: the caller announcements are never rewritten")

	# An Enrage source without an explicit count really starts at zero stacks.
	var missing_party := _party()
	var missing := _enrage_roster([{"id": "patch-imp", "max_hp": 20, "enrage": true}])
	_check(missing.get_enemy(1).get("enrage") == true
		and not missing.get_enemy(1).has("enrage_stacks"),
		"AC1 precondition: Enrage metadata without a stored count")
	_check(missing_party.gain_block(1, 9), "AC1 precondition: real absorbing Block")
	_check(phase.execute_phase(missing_party, missing, [_attack(1, 5, 1)])
		== {"ok": true, "events": [_event("attack", 1, true, 1)]}
		and missing_party.get_hero(1)["block"] == 4 and missing_party.get_hero(1)["hp"] == 40,
		"AC1: an absent stack count means zero stacks and the plain announced five")

	# A slain Enrage source is skipped without bonus, damage or stack churn.
	var dead_party := _party()
	var dead := _enrage_roster([{"id": "patch-imp", "max_hp": 12,
		"enrage": true, "enrage_stacks": 2}])
	_check(dead.apply_damage(1, 12) and dead.is_slain(1),
		"AC1 precondition: the Enrage source is genuinely slain")
	var slain: Dictionary = dead.get_enemy(1)
	_check(phase.execute_phase(dead_party, dead, [_attack(1, 5, 1)])
		== {"ok": true, "events": [_event("attack", 1, false, 1)]}
		and dead_party.get_hero(1)["hp"] == 40 and dead.get_enemy(1) == slain,
		"AC1: a slain Enrage source is skipped without its stored bonus")


## AC2: the Enrage bonus is added BEFORE the existing Weak/Exposed adjustment,
## so the real formula floors once from the increased base. AC1: identical
## fixtures repeat exactly, and one real battle-bound scheduler draw is the
## only run-RNG consumption around the phase.
func _test_enrage_status_and_replay() -> void:
	# [stacks, source Weak, defender Exposed, expected Warden HP]
	# base = 5 + 2*stacks; Weak floors *3/4, Exposed *3/2, both *9/8.
	var cases: Array = [
		[0, true, false, 37], [3, true, false, 32],
		[0, false, true, 33], [3, false, true, 24],
		[0, true, true, 35], [3, true, true, 28]]
	for entry in cases:
		var party := _party()
		var enemies := _enrage_roster([{"id": "patch-imp", "max_hp": 20,
			"enrage": true, "enrage_stacks": entry[0]}])
		if entry[1]:
			_check(enemies.apply_statuses({1: {"weak": 2}}),
				"AC2 precondition: the Enrage source really carries Weak")
		if entry[2]:
			party._heroes[0]["statuses"] = {"exposed": 2}
			_check(party.get_hero(1)["statuses"] == {"exposed": 2},
				"AC2 precondition: the announced Warden really carries Exposed")
		var label := "AC2: base " + str(5 + int(entry[0]) * 2) + " weak=" + str(entry[1]) \
			+ " exposed=" + str(entry[2])
		var result := phase.execute_phase(party, enemies, [_attack(1, 5, 1)])
		_check(result == {"ok": true, "events": [_event("attack", 1, true, 1)]},
			label + ": the adjusted beat keeps the ordinary event shape")
		_check(party.get_hero(1)["hp"] == entry[3],
			label + ": the bonus sits inside the base the status formula scales")

	# AC1: identical literal announcements repeat their exact outcome.
	var expected_events: Dictionary = {}
	var expected_heroes: Array = []
	var expected_enemies: Array = []
	for repetition in range(3):
		var party := _party()
		var enemies := _enrage_roster([
			{"id": "patch-imp", "max_hp": 20, "enrage": true, "enrage_stacks": 2},
			{"id": "ragling-a", "max_hp": 15}])
		var result := phase.execute_phase(party, enemies,
			[_attack(1, 5, 2), _attack(2, 5, 1)])
		_check(result == {"ok": true, "events": [
			_event("attack", 1, true, 2), _event("attack", 2, true, 1)]},
			"AC1 replay: ordered Enrage then plain beats keep exact events")
		_check(party.get_hero(1)["hp"] == 35 and party.get_hero(2)["hp"] == 21,
			"AC1 replay: nine from the Enrage source and five from its sibling")
		if repetition == 0:
			expected_events = result.duplicate(true)
			expected_heroes = party.get_heroes()
			expected_enemies = enemies.get_enemies()
		else:
			_check(result == expected_events and party.get_heroes() == expected_heroes
				and enemies.get_enemies() == expected_enemies,
				"AC1 replay: an identical fixture repeats its exact phase outcome")

	# AC1: a genuine battle-bound scheduler really draws on the seeded run RNG;
	# the Enrage phase itself must consume none of it and repeat exactly.
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = 515151
	var weighted: Array = [
		{"id": "patch-imp", "max_hp": 20, "enrage": true, "enrage_stacks": 1,
			"intent": {"target": "random",
				"actions": [{"weight": 1, "type": "attack", "amount": 5}]}},
		{"id": "ragling-a", "max_hp": 15,
			"intent": {"target": "random",
				"actions": [{"weight": 1, "type": "attack", "amount": 5}]}}]
	var seeded_party := _party()
	var seeded_enemies := _enrage_roster(weighted)
	var scheduler := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 5, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 5, "target_position": 1}]}])
	_check(scheduler.is_valid(), "AC1 precondition: valid legacy pattern scheduler")
	var seed_state := run_rng.state
	_check(scheduler.bind_battle(seeded_enemies, seeded_party, run_rng),
		"AC1 precondition: real weighted announcements bound to the seeded run RNG")
	_check(run_rng.state != seed_state,
		"AC1 precondition: the two random target policies really draw on the run RNG")
	var announcements := scheduler.get_intents()
	var drawn_state := run_rng.state
	var first := phase.execute_phase(seeded_party, seeded_enemies, announcements, null, true)
	_check(first.get("ok") == true and run_rng.state == drawn_state,
		"AC1: the seeded phase consumes no run RNG beyond the announcement draw")
	var seeded_heroes := seeded_party.get_heroes()
	var replay_party := _party()
	var replay_enemies := _enrage_roster(weighted)
	var second := phase.execute_phase(replay_party, replay_enemies, announcements, null, true)
	_check(second == first and replay_party.get_heroes() == seeded_heroes,
		"AC1: the same fixed-seed announcements replay the same exact phase")


## AC3: absent/false Enrage metadata keeps the legacy contract, while malformed
## flag or stack metadata rejects a whole mixed batch before publication.
func _test_enrage_legacy_and_fail_closed() -> void:
	for definition in [
			{"id": "patch-imp", "max_hp": 20},
			{"id": "patch-imp", "max_hp": 20, "enrage": false},
			{"id": "patch-imp", "max_hp": 20, "enrage": false, "enrage_stacks": 3}]:
		var party := _party()
		var enemies := _enrage_roster([definition])
		_check(not enemies.get_enemy(1).get("enrage", false),
			"AC3 precondition: no active Enrage flag: " + str(definition))
		_check(party.gain_block(1, 12), "AC3 precondition: real absorbing Block")
		var source_record: Dictionary = enemies._enemies[0]
		var result := phase.execute_phase(party, enemies, [_attack(1, 5, 1)])
		_check(result == {"ok": true, "events": [_event("attack", 1, true, 1)]}
			and party.get_hero(1)["block"] == 7 and party.get_hero(1)["hp"] == 40,
			"AC3: a non-Enrage source deals its plain announced five: " + str(definition))
		_check(enemies.get_enemy(1) == source_record,
			"AC3: leftover stacks on a non-Enrage source gain and change nothing")

	seed(8181)
	var next_global := randi()
	seed(8181)
	var malformed: Array = []
	for flag in [1, 0, "true", 1.0, null, [], {}]:
		malformed.append({"enrage": flag})
	for stacks in [-1, 4, 5, 1.5, "2", true, null, []]:
		malformed.append({"enrage": true, "enrage_stacks": stacks})
	for extra in malformed:
		var party := _party()
		var second := {"id": "ragling-a", "max_hp": 15}
		second.merge(extra, true)
		var enemies := CombatEnemies.new([
			{"id": "patch-imp", "max_hp": 20, "enrage": true, "enrage_stacks": 1}, second])
		var key: String = extra.keys()[0]
		_check(enemies.is_valid() and enemies.get_enemy(2).has(key)
			and enemies.get_enemy(2)[key] == extra[key],
			"AC3 precondition: a living later source really carries malformed Enrage "
				+ key + " " + str(extra[key]))
		_check(party.gain_block(1, 6) and party.gain_block(2, 6),
			"AC3 precondition: nontrivial real Block on both recipients")
		var intents := [_attack(1, 5, 1), _attack(2, 5, 2)]
		var input := intents.duplicate(true)
		var heroes_before := party.get_heroes()
		var roster_before := enemies.get_enemies()
		_check(phase.execute_phase(party, enemies, intents) == {"ok": false, "events": []},
			"AC3: malformed Enrage metadata rejects the whole mixed batch " + str(extra))
		_check(party.get_heroes() == heroes_before and enemies.get_enemies() == roster_before
			and party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 6
			and intents == input,
			"AC3: the earlier legal Enrage attack is rolled back with the batch "
				+ str(extra))
		_check(phase.execute_phase(party, enemies, []) == {"ok": false, "events": []}
			and party.get_heroes() == heroes_before and enemies.get_enemies() == roster_before,
			"AC3: malformed metadata fails before any beat is staged " + str(extra))
	_check(randi() == next_global, "AC3: rejected malformed Enrage batches consume no RNG")


func _drain_roster(definitions: Array) -> CombatEnemies:
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == definitions.size(),
		"precondition: real Drain roster occupies its authored slots")
	return enemies


## AC1: the real staged phase heals a living wound-carrying Drain source by
## exactly the HP its own one confirmed hit removed, after Block, once.
func _test_drain_after_confirmed_hit() -> void:
	var party := _party()
	var enemies := _drain_roster([
		{"id": "bobbin-bat", "max_hp": 12, "drain": true},
		{"id": "ragling-a", "max_hp": 15}])
	_check(enemies.get_enemy(1).get("drain") == true and enemies.get_enemy(1).max_hp == 12,
		"AC1 precondition: living source 1 authors boolean drain")
	_check(enemies.apply_damage(1, 4) and enemies.get_enemy(1).hp == 8,
		"AC1 precondition: Drain source is genuinely wounded by four")
	party._heroes[2]["statuses"] = {"bleed": 2}
	_check(enemies.apply_statuses({2: {"weak": 1}}),
		"AC1 precondition: unrelated actors carry real statuses")
	var source_record: Dictionary = enemies._enemies[0]
	var other_record: Dictionary = enemies._enemies[1]
	var warden_record: Dictionary = party._heroes[0]
	var tinker_record: Dictionary = party._heroes[2]
	var result := phase.execute_phase(party, enemies, [_attack(1, 3, 2)])
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true}]},
		"AC1: a Drain beat keeps the exact ordinary attack event shape")
	_check(party.get_hero(2).hp == 27 and party.get_hero(2).block == 0,
		"AC1: the real recipient really loses the three dispatched HP")
	_check(enemies.get_enemy(1).hp == 11,
		"AC1: Drain restores exactly the three HP its hit removed, once")
	_check(is_same(enemies._enemies[0], source_record)
		and is_same(enemies._enemies[1], other_record)
		and is_same(party._heroes[0], warden_record)
		and is_same(party._heroes[2], tinker_record),
		"AC1: publication preserves every actor dictionary identity")
	_check(party.get_hero(1).hp == 40 and enemies.get_enemy(2).hp == 15
		and enemies.get_enemy(2).block == 0
		and enemies.get_enemy(2).statuses == {"weak": 1}
		and party.get_hero(3).statuses == {"bleed": 2},
		"AC1: unrelated HP, Block and statuses stay untouched")
	_check(enemies.get_enemy(1).get("drain") == true
		and enemies.get_enemy(1).max_hp == 12 and enemies.get_enemy(1).position == 1,
		"AC1: healing preserves source identity, position and metadata")

	# The heal is capped by the source's missing HP, never overhealing.
	party = _party()
	enemies = _drain_roster([{"id": "bobbin-bat", "max_hp": 12, "drain": true},
		{"id": "ragling-a", "max_hp": 15}])
	_check(enemies.apply_damage(1, 8) and enemies.get_enemy(1).hp == 4
		and enemies.get_enemy(1).max_hp == 12,
		"AC1 precondition: source is missing eight of twelve HP")
	result = phase.execute_phase(party, enemies, [_attack(1, 10, 2)])
	_check(party.get_hero(2).hp == 20,
		"AC1: the recipient genuinely loses ten HP in that one hit")
	_check(enemies.get_enemy(1).hp == 12 and enemies.get_enemy(1).hp <= enemies.get_enemy(1).max_hp,
		"AC1: Drain heals min(HP loss, missing HP) and never overheals")

	# Block absorbs first; only the real post-Block HP loss is healed.
	party = _party()
	enemies = _drain_roster([{"id": "bobbin-bat", "max_hp": 12, "drain": true}])
	_check(enemies.apply_damage(1, 6) and enemies.get_enemy(1).hp == 6
		and party.gain_block(2, 5),
		"AC1 precondition: wounded source and a five-Block recipient")
	result = phase.execute_phase(party, enemies, [_attack(1, 8, 2)])
	_check(party.get_hero(2).hp == 27 and party.get_hero(2).block == 0,
		"AC1: five Block absorbs first and three HP are really lost")
	_check(enemies.get_enemy(1).hp == 9,
		"AC1: Drain heals the three post-Block HP loss, not the eight nominal")

	# Two genuine Drain sources in one staged phase heal independently.
	party = _party()
	enemies = _drain_roster([
		{"id": "bobbin-bat", "max_hp": 12, "drain": true},
		{"id": "bobbin-moth", "max_hp": 15, "drain": true}])
	_check(enemies.apply_damage(1, 5) and enemies.apply_damage(2, 10)
		and enemies.get_enemy(1).hp == 7 and enemies.get_enemy(2).hp == 5,
		"AC1 precondition: two wounded Drain sources")
	result = phase.execute_phase(party, enemies, [_attack(2, 3, 3), _attack(1, 4, 2)])
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]},
		"AC1: two Drain beats keep the exact ordered ordinary events")
	_check(party.get_hero(2).hp == 26 and party.get_hero(3).hp == 23,
		"AC1: each recipient really loses its own announced damage")
	_check(enemies.get_enemy(1).hp == 11 and enemies.get_enemy(2).hp == 8,
		"AC1: each source heals from its own hit only, exactly once per beat")


## AC2: every non-hit or non-Drain state stays inert without resurrecting,
## and malformed authored metadata rejects the phase before any staging.
func _test_drain_inert_and_fail_closed() -> void:
	# A fully blocked hit is applied but removes no HP, so it heals nothing.
	var party := _party()
	var enemies := _drain_roster([{"id": "bobbin-bat", "max_hp": 12, "drain": true}])
	_check(enemies.apply_damage(1, 6) and enemies.get_enemy(1).hp == 6
		and party.gain_block(2, 20),
		"AC2 precondition: wounded Drain source and a fully blocking recipient")
	var result := phase.execute_phase(party, enemies, [_attack(1, 5, 2)])
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true}]},
		"AC2: a fully blocked Drain beat is still one applied attack")
	_check(party.get_hero(2).hp == 30 and party.get_hero(2).block == 15
		and enemies.get_enemy(1).hp == 6,
		"AC2: Block-absorbed damage never heals Drain")

	# A real zero-damage hit removes no HP either.
	party = _party()
	enemies = _drain_roster([{"id": "bobbin-bat", "max_hp": 12, "drain": true}])
	_check(enemies.apply_damage(1, 6) and enemies.get_enemy(1).hp == 6,
		"AC2 precondition: wounded source for a zero-damage beat")
	result = phase.execute_phase(party, enemies, [_attack(1, 0, 2)])
	_check(result.get("ok") == true and result["events"][0].applied == true
		and party.get_hero(2).hp == 30 and enemies.get_enemy(1).hp == 6,
		"AC2: a confirmed zero-damage hit heals nothing")

	# A downed announced recipient makes the beat inert: no damage, no heal.
	party = _party()
	enemies = _drain_roster([{"id": "bobbin-bat", "max_hp": 12, "drain": true}])
	_check(enemies.apply_damage(1, 6) and party.apply_damage(2, 30)
		and party.is_downed(2),
		"AC2 precondition: wounded source and a genuinely downed recipient")
	result = phase.execute_phase(party, enemies, [_attack(1, 9, 2)])
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false}]}
		and party.is_downed(2) and enemies.get_enemy(1).hp == 6,
		"AC2: a skipped beat can never fabricate damage or a Drain heal")

	# A full-HP Drain source has no missing HP to restore.
	party = _party()
	enemies = _drain_roster([{"id": "bobbin-bat", "max_hp": 12, "drain": true}])
	result = phase.execute_phase(party, enemies, [_attack(1, 5, 2)])
	_check(party.get_hero(2).hp == 25 and enemies.get_enemy(1).hp == 12,
		"AC2: a full-HP Drain source heals nothing and keeps its maximum")

	# Absent and explicit-false Drain are valid non-Drain content.
	for flag in [null, false]:
		party = _party()
		var definition := {"id": "bobbin-bat", "max_hp": 12}
		if flag != null:
			definition["drain"] = flag
		enemies = _drain_roster([definition])
		_check(enemies.apply_damage(1, 6) and enemies.get_enemy(1).hp == 6,
			"AC2 precondition: valid non-Drain source wounded by six")
		result = phase.execute_phase(party, enemies, [_attack(1, 5, 2)])
		_check(result == {"ok": true, "events": [
			{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true}]}
			and party.get_hero(2).hp == 25 and enemies.get_enemy(1).hp == 6,
			"AC2: a valid non-Drain source (" + str(flag) + ") heals nothing")

	# An already-slain Drain source stays slain and inert.
	party = _party()
	enemies = _drain_roster([{"id": "bobbin-bat", "max_hp": 12, "drain": true}])
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1),
		"AC2 precondition: the Drain source is already slain")
	var slain: Dictionary = enemies.get_enemy(1)
	result = phase.execute_phase(party, enemies, [_attack(1, 9, 1)])
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false}]}
		and enemies.get_enemy(1) == slain and enemies.is_slain(1)
		and party.get_hero(1).hp == 40,
		"AC2: a slain Drain source never acts, heals or resurrects")

	# Malformed Drain metadata fails the phase before staging, exactly like the
	# bleeding sting, even when that slot itself does not act.
	for invalid in [1, 0, "true", 1.0, null, [], {}]:
		party = _party()
		enemies = CombatEnemies.new([
			{"id": "bobbin-bat", "max_hp": 12, "drain": invalid},
			{"id": "ragling-a", "max_hp": 15}])
		_check(enemies.is_valid() and enemies.get_enemy(1).has("drain")
			and enemies.get_enemy(2).hp == 15,
			"AC4 precondition: live roster carries malformed drain metadata")
		var intents := [_attack(2, 4, 1)]
		var input := intents.duplicate(true)
		var heroes_before := party.get_heroes()
		var roster_before := enemies.get_enemies()
		_check(phase.execute_phase(party, enemies, intents) == {"ok": false, "events": []}
			and party.get_heroes() == heroes_before
			and enemies.get_enemies() == roster_before and intents == input,
			"AC4: malformed drain metadata rejects the whole phase atomically: "
				+ str(invalid))
		_check(phase.execute_phase(party, enemies, []) == {"ok": false, "events": []}
			and party.get_heroes() == heroes_before
			and enemies.get_enemies() == roster_before,
			"AC4: malformed metadata fails before any beat is staged: " + str(invalid))


