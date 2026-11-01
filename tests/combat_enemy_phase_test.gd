extends SceneTree

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_two_hits_and_blind()
	_test_four_catalog_phase_and_refusals()
	_test_ordered_specials()
	_test_fear_buff_dispatch()
	_test_status_sensitive_attacks()
	_test_two_turn_mixed_phase()
	_test_dead_sources_and_downed_targets()
	_test_lethal_batch_inert_specials()
	_test_policy_targets()
	_test_enrage_attack_bonus()
	_test_enrage_status_and_replay()
	_test_enrage_legacy_and_fail_closed()
	_test_enrage_fourth_slot_opt_in()
	_test_drain_after_confirmed_hit()
	_test_drain_inert_and_fail_closed()
	_test_rejections()
	_test_replay_and_empty()
	_test_riposte_confirmed_hits_and_block()
	_test_riposte_multi_hit_and_guard_redirect()
	_test_riposte_skips_misses_and_rollback()
	_test_eyelet_guard_thorns()
	_test_ram_charge_fail_closed()
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


func _test_fear_buff_dispatch() -> void:
	var party := _party()
	var enemies := _enemies()
	_check(enemies.gain_block(1, 2) and party.gain_block(1, 2),
		"Fear phase starts with real enemy and hero Block")
	enemies._enemies[0]["statuses"] = {"cannot_buff_next_turn": true, "weak": 2}
	var expected_enemies := enemies.get_enemies()
	var expected_party := party.get_heroes()
	expected_party[0]["block"] = 0
	expected_party[0]["hp"] = 37
	var actions := [_attack(2, 5, 1), {"type": "buff", "enemy_position": 1, "amount": 3}]
	var before_actions := actions.duplicate(true)
	seed(353)
	var expected_rng := randi()
	seed(353)
	var result := phase.execute_phase(party, enemies, actions)
	_check(result == {"ok": true, "events": [
		_event("buff", 1, false), _event("attack", 2, true, 1)]},
		"real phase dispatch skips feared self-buff and executes later attack in source order")
	_check(party.get_heroes() == expected_party and enemies.get_enemies() == expected_enemies
		and actions == before_actions and randi() == expected_rng,
		"phase attack consumes two Block and three HP; Fear/Weak, enemy Block and other actors stay intact")


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


## A genuine lethal batch that downs the party's last hero still publishes: a
## later hero-targeted snip/debuff has nothing left to change, so it stays inert
## instead of rejecting the authentic turn. A downed target beside a living ally
## keeps failing closed.
func _test_lethal_batch_inert_specials() -> void:
	var snip := {"type": "snip_block", "enemy_position": 2, "amount": 0, "target_position": 1}
	var debuff := {"type": "debuff", "enemy_position": 2, "amount": 2,
		"target_position": 1, "status": "weak"}
	for later in [snip, debuff]:
		var wiped_party := _party()
		var foe_roster := _enemies()
		_check(wiped_party.apply_damage(2, 30) and wiped_party.apply_damage(3, 26)
			and wiped_party.is_downed(2) and wiped_party.is_downed(3)
			and not wiped_party.is_defeated(),
			"precondition: exactly one living hero remains for the lethal beat")
		var foes := foe_roster.get_enemies()
		var result := phase.execute_phase(wiped_party, foe_roster, [_attack(1, 99, 1), later])
		_check(result.get("ok", false) and result.get("events", []).size() == 2
			and result["events"][0] == _event("attack", 1, true, 1)
			and result["events"][1].get("type") == later["type"]
			and result["events"][1].get("applied") == false,
			"lethal last-hero attack publishes with the later special inert: " + str(later["type"]))
		var warden: Dictionary = wiped_party.get_hero(1)
		_check(warden["hp"] == 0 and warden["block"] == 0
			and wiped_party.is_defeated() and not warden.has("statuses")
			and foe_roster.get_enemies() == foes,
			"the inert special neither revives, buffs nor snips after the wipe: " + str(later["type"]))
	# Contrast: with living allies left, a special aimed at a hero downed by an
	# earlier beat of the same batch still fails closed without publishing.
	var party := _party()
	var enemies := _enemies()
	_check(not party.is_defeated(), "precondition: three living heroes for the guarded batch")
	var before := [party.get_heroes(), enemies.get_enemies()]
	_check(not phase.execute_phase(party, enemies, [_attack(1, 99, 1), snip]).get("ok", true)
		and [party.get_heroes(), enemies.get_enemies()] == before,
		"a special aimed at a hero downed this batch still fails closed while allies live")


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


func _phase_four_distinct_enrage_roster(marshal_stacks: int = 2) -> CombatEnemies:
	var wanted := ["fray_scavenger", "button_guard", "spool_hexer", "needle_marshal"]
	var found := {}
	for path in ["res://data/enemies/run_enemies.json", "res://data/enemies/m04_elites.json"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array:
			for entry in parsed:
				if entry is Dictionary and entry.get("id") in wanted and not found.has(entry.get("id")):
					var actor: Dictionary = entry.duplicate(true)
					actor["max_hp"] = int(actor["max_hp"])
					found[actor["id"]] = actor
	var records: Array = []
	for id in wanted:
		_check(found.has(id), "precondition: authentic enemy %s loaded" % id)
		records.append(found[id].duplicate(true))
	if records.size() == 4:
		records[3]["enrage_stacks"] = marshal_stacks
	var enemies := CombatEnemies.new(records, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.is_valid() and enemies.get_capacity() == 4 and enemies.get_enemies().size() == 4,
		"precondition: four-capacity roster with four distinct living IDs")
	return enemies


## AC3: real enemy-phase effect from fourth-slot Needle Marshal in an explicit
## four-capacity fight, Block-before-HP, ordered trace, replay, and zero extra stack/RNG.
func _test_enrage_fourth_slot_opt_in() -> void:
	# Case 1: Hero Block >= 9 (Warden starts with 12 Block, 40 HP).
	# Needle Marshal at slot 4 with 2 stacks deals 5 + 4 = 9 damage.
	var party := _party()
	var enemies := _phase_four_distinct_enrage_roster(2)
	_check(party.gain_block(1, 12), "AC3 precondition: Warden gains 12 block (>= 9)")
	_check(enemies.get_enemy(4).get("id") == "needle_marshal"
		and enemies.get_enemy(4).get("enrage") == true
		and enemies.get_enemy(4).get("enrage_stacks") == 2,
		"AC3 precondition: fourth-slot Needle Marshal has 2 Enrage stacks")
	var peer1_before: Dictionary = enemies.get_enemy(1)
	var peer2_before: Dictionary = enemies.get_enemy(2)
	var peer3_before: Dictionary = enemies.get_enemy(3)
	var slot4_before: Dictionary = enemies.get_enemy(4)
	var intents := [_attack(4, 5, 1)]
	var input := intents.duplicate(true)

	var result := phase.execute_phase(party, enemies, intents)
	_check(result == {"ok": true, "events": [_event("attack", 4, true, 1)]},
		"AC3: slot-4 Enrage attack produces single applied attack event")
	_check(party.get_hero(1)["block"] == 3 and party.get_hero(1)["hp"] == 40,
		"AC3: hero Block >= 9 absorbs 9 damage (12 - 9 = 3), HP intact at 40")
	_check(enemies.get_enemy(4) == slot4_before and enemies.get_enemy(4).get("enrage_stacks") == 2,
		"AC3: slot 4 awards no extra stack during enemy phase and mutates nothing")
	_check(enemies.get_enemy(1) == peer1_before
		and enemies.get_enemy(2) == peer2_before
		and enemies.get_enemy(3) == peer3_before,
		"AC3: three peer enemies in slots 1-3 remain completely untouched")
	_check(intents == input, "AC3: caller announcements are never rewritten")

	# Case 2: Insufficient Block (Warden starts with 4 Block, 40 HP).
	# 9 damage arrives: 4 absorbed by Block (0 remaining), 5 lost from HP (40 -> 35).
	party = _party()
	enemies = _phase_four_distinct_enrage_roster(2)
	_check(party.gain_block(1, 4), "AC3 precondition: Warden gains 4 block (< 9)")
	result = phase.execute_phase(party, enemies, [_attack(4, 5, 1)])
	_check(result.get("ok") == true and result["events"].size() == 1
		and result["events"][0]["applied"] == true,
		"AC3: attack event applied with insufficient block")
	_check(party.get_hero(1)["block"] == 0 and party.get_hero(1)["hp"] == 35,
		"AC3: exact HP loss witnessed when Block insufficient (4 absorbed, 5 HP loss -> 35 HP)")

	# Case 3: Zero Block direct HP loss.
	party = _party()
	enemies = _phase_four_distinct_enrage_roster(2)
	result = phase.execute_phase(party, enemies, [_attack(4, 5, 2)])
	_check(party.get_hero(2)["block"] == 0 and party.get_hero(2)["hp"] == 21,
		"AC3: zero Block loses exactly 9 HP (30 -> 21 on middle hero)")

	# Case 4: Ordered trace with peers in source-slot order.
	# Slot 2 announces attack 4 on hero 2; Slot 4 announces attack 5 (+4 = 9) on hero 1.
	party = _party()
	enemies = _phase_four_distinct_enrage_roster(2)
	_check(party.gain_block(1, 10) and party.gain_block(2, 10),
		"AC3 precondition: heroes 1 and 2 gain 10 block each")
	var mixed_intents := [_attack(4, 5, 1), _attack(2, 4, 2)]
	var ordered_res := phase.execute_phase(party, enemies, mixed_intents)
	_check(ordered_res == {"ok": true, "events": [
		_event("attack", 2, true, 2),
		_event("attack", 4, true, 1)]},
		"AC3: phase executes in source-slot order (slot 2 then slot 4)")
	_check(party.get_hero(2)["block"] == 6 and party.get_hero(2)["hp"] == 30,
		"AC3: peer slot 2 deals exactly its un-enraged 4 damage (10 - 4 = 6 block)")
	_check(party.get_hero(1)["block"] == 1 and party.get_hero(1)["hp"] == 40,
		"AC3: slot 4 deals enraged 9 damage (10 - 9 = 1 block)")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(3).get("hp") == 24,
		"AC3: non-acting peer records in slots 1 and 3 are untouched")

	# Case 5: Independent deterministic replay (3 repetitions).
	var expected_res: Dictionary = {}
	var expected_h: Array = []
	var expected_e: Array = []
	for rep in range(3):
		var rep_party := _party()
		var rep_enemies := _phase_four_distinct_enrage_roster(2)
		_check(rep_party.gain_block(1, 10) and rep_party.gain_block(2, 10),
			"AC3 replay precondition: block assigned")
		var rep_res := phase.execute_phase(rep_party, rep_enemies, [_attack(2, 4, 2), _attack(4, 5, 1)])
		_check(rep_res == {"ok": true, "events": [
			_event("attack", 2, true, 2), _event("attack", 4, true, 1)]},
			"AC3 replay: iteration %d produces exact ordered events" % rep)
		if rep == 0:
			expected_res = rep_res.duplicate(true)
			expected_h = rep_party.get_heroes()
			expected_e = rep_enemies.get_enemies()
		else:
			_check(rep_res == expected_res and rep_party.get_heroes() == expected_h
				and rep_enemies.get_enemies() == expected_e,
				"AC3 replay: iteration %d identically matches first run" % rep)

	# Case 6: RNG isolation (seeded RandomNumberGenerator and global randi).
	var rng := RandomNumberGenerator.new()
	rng.seed = 66551
	var rng_before := rng.state
	seed(54321)
	var global_before := randi()
	seed(54321)
	party = _party()
	enemies = _phase_four_distinct_enrage_roster(2)
	phase.execute_phase(party, enemies, [_attack(4, 5, 1)])
	_check(rng.state == rng_before and randi() == global_before,
		"AC3: slot 4 Enrage enemy phase consumes zero local or global RNG")

	# Case 7: Rejection of invalid fifth position and negatives.
	party = _party()
	enemies = _phase_four_distinct_enrage_roster(2)
	var h_before := party.get_heroes()
	var e_before := enemies.get_enemies()
	seed(11223)
	var g_before_pos5 := randi()
	seed(11223)
	var pos5_res := phase.execute_phase(party, enemies, [_attack(5, 5, 1)])
	_check(pos5_res == {"ok": false, "events": []},
		"AC4: announcement from position 5 rejected fail-closed")
	_check(party.get_heroes() == h_before and enemies.get_enemies() == e_before,
		"AC4: rejected position 5 announcement leaves party and enemies completely untouched")
	_check(randi() == g_before_pos5,
		"AC4: rejected position 5 announcement consumes no RNG")

	# Slain slot 4 is skipped: applied = false, no damage, no stacks
	_check(enemies.apply_damage(4, 28) and enemies.is_slain(4),
		"AC4 precondition: fourth-slot Needle Marshal slain")
	var slain_res := phase.execute_phase(party, enemies, [_attack(4, 5, 1)])
	_check(slain_res == {"ok": true, "events": [_event("attack", 4, false, 1)]}
		and party.get_hero(1)["hp"] == 40,
		"AC4: slain slot 4 Enrage source is skipped with applied: false and no damage")


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




func _test_two_hits_and_blind() -> void:
	var action := {"enemy_position": 1, "type": "attack", "amount": 8,
		"hits": 2, "target_position": 3}
	var parsed := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var wasp: Dictionary = {}
	for actor in parsed:
		if actor.id == "needle_wasp":
			wasp = actor
	_check(not wasp.is_empty() and wasp.intent.actions[1].hits == 2,
		"genuine Wasp authors a two-hit attack")
	if wasp.is_empty():
		return
	for floor_number in [1, 5, 9]:
		var total: int = RunNormalAttackFloorScaling.scale_normal_attack(8, floor_number).amount
		_check(total == {1: 8, 5: 10, 9: 12}[floor_number], "fixed expected scaled total")
		var party := _party()
		var enemies := CombatEnemies.new([wasp])
		var hit := action.duplicate(true)
		hit.amount = total
		_check(party.gain_block(3, total / 2), "first hit has exact absorbing Block")
		var result := phase.execute_phase(party, enemies, [hit])
		_check(result.ok and result.events.size() == 2 and result.events[0].applied
			and result.events[1].applied and party.get_hero(3).hp == 26 - total / 2
			and party.get_hero(3).block == 0 and party.get_hero(3).statuses == {"bleed": 1},
			"floor %d splits total once; only second HP-losing hit bleeds" % floor_number)
	var party := _party()
	var enemies := CombatEnemies.new([wasp])
	enemies._enemies[0].statuses = {"blind_next_attack": 1, "weak": 2}
	var source: Dictionary = enemies._enemies[0]
	for nonattack in [{"enemy_position": 1, "type": "block", "amount": 1},
		{"enemy_position": 1, "type": "buff", "amount": 1},
		{"enemy_position": 1, "type": "debuff", "amount": 1, "status": "bleed", "target_position": 1}]:
		_check(phase.execute_phase(party, enemies, [nonattack]).ok
			and enemies.get_enemy(1).statuses.has("blind_next_attack"), "nonattacks preserve Blind")
	_check(CombatStatusTurnBatch.new().tick_side("enemies", enemies.get_enemies()).actors[0].statuses
		== {"blind_next_attack": 1, "weak": 1}, "owner tick preserves armed Blind")
	var before := party.get_heroes()
	var result := phase.execute_phase(party, enemies, [action])
	_check(result.ok and result.events.size() == 1 and not result.events[0].applied
		and party.get_heroes() == before and enemies.get_enemy(1).statuses == {"weak": 2}
		and is_same(source, enemies._enemies[0]), "Blind misses entire attack and publishes once")
	_check(phase.execute_phase(party, enemies, [action]).ok and party.get_hero(3).hp == 20
		and party.get_hero(3).statuses.bleed == 2, "next two-hit attack lands under Weak")
	for value in [true, 1.0, "1", -1, 2, null, [], {}]:
		party = _party()
		enemies = CombatEnemies.new([wasp])
		enemies._enemies[0].statuses = {"blind_next_attack": value}
		var snapshot := [party.get_heroes(), enemies.get_enemies()]
		_check(phase.execute_phase(party, enemies, [action]) == {"ok": false, "events": []}
			and snapshot == [party.get_heroes(), enemies.get_enemies()], "malformed Blind is atomic")
	# A later runtime overflow must roll back both earlier hits and Blind spend.
	party = _party()
	enemies = _enemies()
	enemies._enemies[0].statuses = {"blind_next_attack": 1}
	party._heroes[0].statuses = {"bleed": CombatStatuses.MAX_INT}
	var snapshot := [party.get_heroes(), enemies.get_enemies()]
	_check(phase.execute_phase(party, enemies, [action, {"enemy_position": 2,
		"type": "debuff", "amount": 1, "status": "bleed", "target_position": 1}])
		== {"ok": false, "events": []} and snapshot == [party.get_heroes(), enemies.get_enemies()],
		"later overflow rolls back earlier Blind consumption")
	for value in [1, 3, true, 2.0, "2", null]:
		var malformed := action.duplicate(true)
		malformed.hits = value
		_check(phase.execute_phase(party, enemies, [malformed]) == {"ok": false, "events": []}
			and snapshot == [party.get_heroes(), enemies.get_enemies()], "malformed hits roll back")
	party = _party()
	enemies = CombatEnemies.new([wasp])
	_check(party.apply_damage(3, 26), "down announced hero before policy fallback")
	var result_fallback := phase.execute_phase(party, enemies, [action], null, true)
	_check(result_fallback.ok and result_fallback.events.size() == 2
		and result_fallback.events[0].target_position == 2
		and result_fallback.events[1].target_position == 2 and party.get_hero(2).hp == 22,
		"two hits preserve lowest-living fallback target")
	for skipped in ["slain", "downed"]:
		party = _party()
		enemies = CombatEnemies.new([wasp])
		enemies._enemies[0].statuses = {"blind_next_attack": 1}
		if skipped == "slain":
			_check(enemies.apply_damage(1, 22), "slay source before skipped beat")
		else:
			_check(party.apply_damage(3, 26), "down target before legacy skipped beat")
		var skipped_before := [party.get_heroes(), enemies.get_enemies()]
		_check(phase.execute_phase(party, enemies, [action]).ok
			and skipped_before == [party.get_heroes(), enemies.get_enemies()],
			"inert " + skipped + " beat preserves Blind")
	# Without Blind the same late failure also rolls back both landed strikes.
	party = _party()
	enemies = _enemies()
	party._heroes[0].statuses = {"bleed": CombatStatuses.MAX_INT}
	snapshot = [party.get_heroes(), enemies.get_enemies()]
	_check(phase.execute_phase(party, enemies, [action, {"enemy_position": 2,
		"type": "debuff", "amount": 1, "status": "bleed", "target_position": 1}])
		== {"ok": false, "events": []} and snapshot == [party.get_heroes(), enemies.get_enemies()],
		"later overflow rolls back both earlier landed hits")



func _riposte_party(duelist_seat: int = 2) -> CombatParty:
	var definitions: Array = [
		{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26},
	]
	definitions.insert(duelist_seat - 1, {"id": "rag_duelist", "max_hp": 30})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3
		and party.get_hero(duelist_seat)["id"] == "rag_duelist"
		and party.get_hero(duelist_seat)["hp"] == 30,
		"precondition: three-hero party with Rag Duelist at seat " + str(duelist_seat))
	return party


func _riposte_deck(card_id: String, seed_value: int = 9101) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cards: Array[String] = [
		card_id, "warden_strike", "warden_brace", "tinker_pop_shot", "tinker_scrap_bomb"
	]
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.turn_active
		and deck.energy == CombatState.TURN_ENERGY and deck.hand.size() == 5
		and deck.hand.has(card_id),
		"precondition: 5-card hand with 3 energy holding " + card_id)
	return deck


func _guard_event(source: int, announced: int, applied: bool, actual: int,
		redirected: bool, thorns_damage: int) -> Dictionary:
	return {
		"type": "attack",
		"enemy_position": source,
		"target_position": announced,
		"applied": applied,
		"actual_target_position": actual,
		"redirected": redirected,
		"retaliation_damage": thorns_damage,
		"retaliatory_damage": thorns_damage,
	}


## AC1 & AC4: Every authentic Rag Duelist Riposte N card deals exactly N retaliation
## through enemy Block then HP on each confirmed positive-damage hit on a living
## pre-hit defender—even when hero Block absorbs the whole hit or the hit downs
## the defender—while keeping Riposte N unchanged during the phase.
func _test_riposte_confirmed_hits_and_block() -> void:
	var riposte_service := CombatRagDuelistRiposteCards.new()
	var card_specs: Array = [
		["rag_duelist_cape_parry", 4, 2, [1, 2, 3]],
		["rag_duelist_cape_parry_plus", 6, 3, [1, 2, 3]],
		["rag_duelist_cape_guard", 5, 3, [1, 2, 3]],
		["rag_duelist_cape_guard_plus", 7, 4, [1, 2, 3]],
		["rag_duelist_duelist_reprise", 0, 5, [1, 2]],
		["rag_duelist_duelist_reprise_plus", 0, 7, [1, 2]],
	]
	for spec: Array in card_specs:
		var card_id: String = spec[0]
		var expected_block: int = spec[1]
		var expected_riposte: int = spec[2]
		var seats: Array = spec[3]
		for seat_v in seats:
			var seat: int = int(seat_v)
			var party := _riposte_party(seat)
			var deck := _riposte_deck(card_id, 9200 + seat)
			var enemies := _enemies()
			_check(enemies.gain_block(1, 2) and enemies.gain_block(2, 3),
				"AC1 precondition: enemy 1 has 2 Block, enemy 2 has 3 Block for " + card_id)
			var rng_before: int = deck._rng.state
			var play_res: Dictionary = riposte_service.play_card(deck, party, card_id)
			_check(play_res.get("ok", false)
				and deck.energy == 2 and deck.discard_pile == [card_id]
				and party.get_hero(seat)["block"] == expected_block
				and party.get_hero(seat)["statuses"] == {"riposte": expected_riposte}
				and deck._rng.state == rng_before,
				"AC1 precondition: paid " + card_id + " at seat " + str(seat)
					+ " sets Block " + str(expected_block) + " and Riposte " + str(expected_riposte))
			var hero_ref: Dictionary = party._heroes[seat - 1]
			var enemy_ref: Dictionary = enemies._enemies[0]
			var enemy2_before: Dictionary = enemies.get_enemy(2)
			var incoming := 6
			var result := phase.execute_phase(party, enemies, [_attack(1, incoming, seat)])
			_check(result == {"ok": true, "events": [_event("attack", 1, true, seat)]},
				"AC1/AC4: " + card_id + " phase keeps exact ordinary attack event shape")
			var absorbed_by_hero: int = mini(expected_block, incoming)
			var expected_hero_block: int = expected_block - absorbed_by_hero
			var expected_hero_hp: int = 30 - (incoming - absorbed_by_hero)
			_check(party.get_hero(seat)["block"] == expected_hero_block
				and party.get_hero(seat)["hp"] == expected_hero_hp
				and party.get_hero(seat)["statuses"] == {"riposte": expected_riposte},
				"AC1: " + card_id + " hero Block absorbs first and Riposte N remains unchanged")
			var absorbed_by_enemy: int = mini(2, expected_riposte)
			var expected_enemy_block: int = 2 - absorbed_by_enemy
			var expected_enemy_hp: int = 12 - (expected_riposte - absorbed_by_enemy)
			_check(enemies.get_enemy(1)["block"] == expected_enemy_block
				and enemies.get_enemy(1)["hp"] == expected_enemy_hp
				and enemies.get_enemy(2) == enemy2_before,
				"AC1: " + card_id + " deals exact Riposte " + str(expected_riposte)
					+ " through enemy Block then HP without touching enemy 2")
			_check(is_same(party._heroes[seat - 1], hero_ref)
				and is_same(enemies._enemies[0], enemy_ref)
				and deck._rng.state == rng_before,
				"AC1: " + card_id + " preserves actor dictionary identities and RNG")
			# Owner-turn boundary (not CombatEnemyPhase) expires Riposte N completely.
			var batch_tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
			_check(batch_tick.get("ok", false)
				and batch_tick["actors"][seat - 1]["statuses"] == {},
				"AC1: CombatStatusTurnBatch expires Riposte " + str(expected_riposte) + " after phase")

	# Full hero Block absorption still triggers Riposte N and suppresses enemy Drain/Sting.
	var blocked_party := _riposte_party(2)
	var blocked_deck := _riposte_deck("rag_duelist_cape_guard_plus", 9301)
	var blocked_enemies := CombatEnemies.new([
		{"id": "stinger-bat", "max_hp": 14, "drain": true, "bleed_on_attack": true},
		{"id": "bystander", "max_hp": 15},
	])
	_check(blocked_enemies.is_valid()
		and blocked_enemies.apply_damage(1, 5)
		and blocked_enemies.gain_block(1, 1)
		and blocked_enemies.get_enemy(1)["hp"] == 9,
		"AC1 precondition: wounded Drain+Sting enemy with 1 Block and 9 HP")
	_check(riposte_service.play_card(blocked_deck, blocked_party, "rag_duelist_cape_guard_plus").get("ok", false)
		and blocked_party.get_hero(2)["block"] == 7
		and blocked_party.get_hero(2)["statuses"] == {"riposte": 4},
		"AC1 precondition: Cape Guard+ grants 7 Block and Riposte 4")
	var blocked_res := phase.execute_phase(blocked_party, blocked_enemies, [_attack(1, 5, 2)])
	_check(blocked_res == {"ok": true, "events": [_event("attack", 1, true, 2)]},
		"AC1: fully blocked hit is still an applied positive-damage attack")
	_check(blocked_party.get_hero(2)["hp"] == 30
		and blocked_party.get_hero(2)["block"] == 2
		and blocked_party.get_hero(2)["statuses"] == {"riposte": 4},
		"AC1: hero Block absorbs all 5 damage; HP stays 30, no Bleed added, Riposte 4 intact")
	_check(blocked_enemies.get_enemy(1)["block"] == 0
		and blocked_enemies.get_enemy(1)["hp"] == 6,
		"AC1: enemy takes 4 Riposte (1 Block + 3 HP -> 6 HP) and heals 0 Drain on blocked hit")

	# A hit that downs the previously living Riposte hero still counters once;
	# a subsequent enemy targeting that now-downed slot is skipped without a second counter.
	var lethal_party := _riposte_party(1)
	var lethal_deck := _riposte_deck("rag_duelist_duelist_reprise_plus", 9302)
	var lethal_enemies := _enemies()
	_check(lethal_party.apply_damage(1, 26) and lethal_party.get_hero(1)["hp"] == 4
		and lethal_enemies.gain_block(1, 2) and lethal_enemies.gain_block(2, 1),
		"AC1 precondition: living Rag Duelist at 4 HP; enemies carry Block")
	_check(riposte_service.play_card(lethal_deck, lethal_party, "rag_duelist_duelist_reprise_plus").get("ok", false)
		and lethal_party.get_hero(1)["statuses"] == {"riposte": 7},
		"AC1 precondition: Duelist Reprise+ sets Riposte 7 on 4-HP front hero")
	var lethal_res := phase.execute_phase(lethal_party, lethal_enemies,
		[_attack(2, 6, 1), _attack(1, 9, 1)])
	_check(lethal_res == {"ok": true, "events": [
		_event("attack", 1, true, 1),
		_event("attack", 2, false, 1)]},
		"AC1: lethal first hit applies; second hit on now-downed hero is skipped")
	_check(lethal_party.is_downed(1) and lethal_party.get_hero(1)["hp"] == 0
		and lethal_party.get_hero(1)["statuses"] == {"riposte": 7},
		"AC1: downed hero retains pre-tick status dictionary")
	_check(lethal_enemies.get_enemy(1)["block"] == 0 and lethal_enemies.get_enemy(1)["hp"] == 7
		and lethal_enemies.get_enemy(2)["block"] == 1 and lethal_enemies.get_enemy(2)["hp"] == 15,
		"AC1: enemy 1 takes 7 Riposte (2 Block + 5 HP) from lethal hit; skipped enemy 2 takes 0")

	# Enemy revive_once semantics stay intact when Riposte deals lethal retaliation.
	var revive_party := _riposte_party(2)
	var revive_deck := _riposte_deck("rag_duelist_duelist_reprise", 9303)
	var revive_enemies := CombatEnemies.new([
		{"id": "wraith-a", "max_hp": 11, "revive_once": true},
		{"id": "wraith-b", "max_hp": 11, "revive_once": true, "revived": true},
	])
	_check(revive_enemies.is_valid()
		and revive_enemies.apply_damage(1, 8) and revive_enemies.get_enemy(1)["hp"] == 3
		and not revive_enemies.get_enemy(1).get("revived", false)
		and revive_enemies.apply_damage(2, 8) and revive_enemies.get_enemy(2)["hp"] == 3
		and revive_enemies.get_enemy(2).get("revived", false),
		"AC1/AC4 precondition: unrevived and already-revived foes both at 3 HP")
	_check(riposte_service.play_card(revive_deck, revive_party, "rag_duelist_duelist_reprise").get("ok", false),
		"AC1/AC4 precondition: Riposte 5 active on Rag Duelist")
	var revive_res := phase.execute_phase(revive_party, revive_enemies,
		[_attack(1, 5, 2), _attack(2, 5, 2)])
	_check(revive_res == {"ok": true, "events": [
		_event("attack", 1, true, 2),
		_event("attack", 2, true, 2)]},
		"AC1/AC4: both wraith attacks resolve in source order")
	_check(revive_enemies.get_enemy(1)["hp"] == 6
		and revive_enemies.get_enemy(1).get("revived") == true
		and not revive_enemies.is_slain(1),
		"AC1/AC4: first lethal Riposte triggers revive_once to ceil(11/2)=6 HP and latches revived")
	_check(revive_enemies.get_enemy(2)["hp"] == 0
		and revive_enemies.get_enemy(2).get("revived") == true
		and revive_enemies.is_slain(2),
		"AC1/AC4: already-revived enemy slain by Riposte stays at 0 HP")


## AC2: Multi-hit attacks trigger Riposte N separately on each confirmed hit; an
## attacker killed by a counter cannot land its remaining hits; Guard redirection
## uses the actual hit defender (not the announced target) without double-counting
## Guard's own Thorns retaliation.
func _test_riposte_multi_hit_and_guard_redirect() -> void:
	var riposte_service := CombatRagDuelistRiposteCards.new()

	# 1. Two-hit attack where enemy survives Hit 1 and takes two separate Riposte counters.
	var party := _riposte_party(3)
	var deck := _riposte_deck("rag_duelist_cape_parry_plus", 9401)
	var enemies := CombatEnemies.new([
		{"id": "needle_wasp", "max_hp": 16, "bleed_on_attack": true}
	])
	_check(enemies.is_valid() and enemies.gain_block(1, 2),
		"AC2 precondition: two-hit Wasp with 2 Block and 16 HP")
	_check(riposte_service.play_card(deck, party, "rag_duelist_cape_parry_plus").get("ok", false)
		and party.get_hero(3)["block"] == 6
		and party.get_hero(3)["statuses"] == {"riposte": 3},
		"AC2 precondition: Cape Parry+ at seat 3 sets Block 6 and Riposte 3")
	var two_hit := {"enemy_position": 1, "type": "attack", "amount": 10, "hits": 2, "target_position": 3}
	var res := phase.execute_phase(party, enemies, [two_hit])
	_check(res == {"ok": true, "events": [
		_event("attack", 1, true, 3),
		_event("attack", 1, true, 3)]},
		"AC2: both hits of multi-hit attack land and emit standard events")
	# Hit 1 deals 5 (absorbed by 6 Block -> 1 Block left, 30 HP, no Bleed); Riposte 3 -> consumes 2 Block + 1 HP (15 HP).
	# Hit 2 deals 5 (consumes 1 Block + 4 HP -> 26 HP, inflicts Bleed 1); Riposte 3 -> consumes 3 HP (12 HP).
	_check(party.get_hero(3)["hp"] == 26 and party.get_hero(3)["block"] == 0
		and party.get_hero(3)["statuses"] == {"riposte": 3, "bleed": 1},
		"AC2: first hit blocked, second hit deals HP loss + Bleed 1 while preserving Riposte 3")
	_check(enemies.get_enemy(1)["block"] == 0 and enemies.get_enemy(1)["hp"] == 12,
		"AC2: two confirmed hits trigger two separate Riposte 3 counters (2 Block + 4 HP lost)")

	# 2. Multi-hit attack where Hit 1's Riposte counter kills the attacker: Hit 2 does not land.
	var kill_party := _riposte_party(2)
	var kill_deck := _riposte_deck("rag_duelist_cape_guard_plus", 9402)
	var kill_enemies := CombatEnemies.new([
		{"id": "fragile_wasp", "max_hp": 12, "bleed_on_attack": true, "drain": true}
	])
	_check(kill_enemies.is_valid()
		and kill_enemies.apply_damage(1, 9)
		and kill_enemies.gain_block(1, 1)
		and kill_enemies.get_enemy(1)["hp"] == 3,
		"AC2 precondition: multi-hit attacker has 1 Block and 3 HP (4 effective HP <= Riposte 4)")
	_check(riposte_service.play_card(kill_deck, kill_party, "rag_duelist_cape_guard_plus").get("ok", false),
		"AC2 precondition: Cape Guard+ grants 7 Block and Riposte 4")
	var kill_action := {"enemy_position": 1, "type": "attack", "amount": 18, "hits": 2, "target_position": 2}
	var kill_res := phase.execute_phase(kill_party, kill_enemies, [kill_action])
	_check(kill_res == {"ok": true, "events": [
		_event("attack", 1, true, 2),
		_event("attack", 1, false, 2)]},
		"AC2: Hit 1 lands and slays source via Riposte 4; Hit 2 is skipped (applied: false)")
	_check(kill_enemies.is_slain(1) and kill_enemies.get_enemy(1)["hp"] == 0
		and kill_enemies.get_enemy(1)["block"] == 0,
		"AC2: attacker killed by Hit 1 Riposte stays slain at 0 HP without Drain")
	_check(kill_party.get_hero(2)["hp"] == 28 and kill_party.get_hero(2)["block"] == 0
		and kill_party.get_hero(2)["statuses"] == {"riposte": 4},
		"AC2: defender takes only Hit 1 (9 vs 7 Block -> 28 HP), no Sting from slain source, no Hit 2")

	# 3. Multi-hit attack where Hit 1 downs the Riposte defender: Hit 1 counters, Hit 2 skips.
	var down_party := _riposte_party(2)
	var down_deck := _riposte_deck("rag_duelist_duelist_reprise", 9403)
	var down_enemies := CombatEnemies.new([{"id": "wasp", "max_hp": 16}])
	_check(down_party.apply_damage(2, 27) and down_party.get_hero(2)["hp"] == 3,
		"AC2 precondition: Rag Duelist at 3 HP before two-hit attack")
	_check(riposte_service.play_card(down_deck, down_party, "rag_duelist_duelist_reprise").get("ok", false),
		"AC2 precondition: Duelist Reprise sets Riposte 5")
	var down_res := phase.execute_phase(down_party, down_enemies,
		[{"enemy_position": 1, "type": "attack", "amount": 8, "hits": 2, "target_position": 2}])
	_check(down_res == {"ok": true, "events": [
		_event("attack", 1, true, 2),
		_event("attack", 1, false, 2)]},
		"AC2: Hit 1 downs defender; Hit 2 against now-downed defender is skipped")
	_check(down_party.is_downed(2) and down_enemies.get_enemy(1)["hp"] == 11,
		"AC2: only Hit 1 triggers Riposte 5 (16 -> 11 HP); skipped Hit 2 does not counter")

	# 4. Guard redirection: announced target has Riposte 5, actual recipient (Warden) does not.
	var guard_party := _riposte_party(2)
	var guard_deck := _riposte_deck("rag_duelist_duelist_reprise", 9404)
	var guard_enemies := _enemies()
	var reactions := CombatWardenGuardReactions.new()
	var warden_catalog := WardenPoolCards.new()
	_check(reactions.apply_committed_card(warden_catalog.get_definition("warden_draw_fire"), guard_party)
		and reactions.apply_committed_card(warden_catalog.get_definition("warden_counter_stitch"), guard_party)
		and reactions.is_guarding() and reactions.get_thorns() == 3
		and guard_party.get_hero(1)["block"] == 11,
		"AC2 precondition: Warden at pos 1 has Guarding, Thorns 3, and 11 Block")
	_check(riposte_service.play_card(guard_deck, guard_party, "rag_duelist_duelist_reprise").get("ok", false)
		and guard_party.get_hero(2)["statuses"] == {"riposte": 5},
		"AC2 precondition: Rag Duelist at pos 2 has Riposte 5")
	var guard_res := phase.execute_phase(guard_party, guard_enemies,
		[_attack(1, 6, 2), _attack(2, 4, 1)], reactions)
	_check(guard_res == {"ok": true, "events": [
		_guard_event(1, 2, true, 1, true, 3),
		_guard_event(2, 1, true, 1, false, 3)]},
		"AC2: attack aimed at Riposte ally redirects to Warden with exact reaction event")
	_check(guard_party.get_hero(1)["block"] == 1 and guard_party.get_hero(1)["hp"] == 40
		and guard_party.get_hero(2)["hp"] == 30
		and guard_party.get_hero(2)["statuses"] == {"riposte": 5},
		"AC2: Warden absorbs both hits (11 -> 1 Block); bypassed Rag Duelist takes no hit")
	_check(guard_enemies.get_enemy(1)["hp"] == 9 and guard_enemies.get_enemy(2)["hp"] == 12,
		"AC2: enemies take only Warden's Thorns 3 (not bypassed ally's Riposte 5, no double-count)")

	# 5. Guard reaction service active WITHOUT Guarding redirect: direct hit on Riposte ally
	# counters with Riposte N while direct hit on Warden counters with Thorns.
	var unguarded_party := _riposte_party(2)
	var unguarded_deck := _riposte_deck("rag_duelist_cape_guard_plus", 9405)
	var unguarded_enemies := _enemies()
	var thorns_only := CombatWardenGuardReactions.new()
	_check(thorns_only.apply_committed_card(warden_catalog.get_definition("warden_counter_stitch"), unguarded_party)
		and not thorns_only.is_guarding() and thorns_only.get_thorns() == 3,
		"AC2 precondition: Warden has Thorns 3 without Guarding")
	_check(riposte_service.play_card(unguarded_deck, unguarded_party, "rag_duelist_cape_guard_plus").get("ok", false)
		and unguarded_party.get_hero(2)["block"] == 7
		and unguarded_party.get_hero(2)["statuses"] == {"riposte": 4},
		"AC2 precondition: Rag Duelist at pos 2 has 7 Block and Riposte 4")
	var unguarded_res := phase.execute_phase(unguarded_party, unguarded_enemies,
		[_attack(1, 5, 2), _attack(2, 4, 1)], thorns_only)
	_check(unguarded_res == {"ok": true, "events": [
		_guard_event(1, 2, true, 2, false, 0),
		_guard_event(2, 1, true, 1, false, 3)]},
		"AC2: reaction-mode events keep Thorns receipt separate from Riposte")
	_check(unguarded_party.get_hero(2)["block"] == 2 and unguarded_party.get_hero(2)["hp"] == 30
		and unguarded_enemies.get_enemy(1)["hp"] == 8
		and unguarded_enemies.get_enemy(2)["hp"] == 12,
		"AC2: enemy 1 takes Riposte 4 from hitting Rag Duelist; enemy 2 takes Thorns 3 from hitting Warden")

	# 6. Guard redirection onto a guarding defender who ALSO carries Riposte N:
	# the actual hit defender's Riposte N triggers on the redirected hit.
	var redirect_riposte_party := _riposte_party(2)
	var redirect_enemies := _enemies()
	var redirect_guard := CombatWardenGuardReactions.new()
	_check(redirect_guard.apply_committed_card(warden_catalog.get_definition("warden_draw_fire"), redirect_riposte_party)
		and redirect_guard.is_guarding() and redirect_guard.get_thorns() == 0,
		"AC2 precondition: Warden at pos 1 is Guarding with 6 Block and 0 Thorns")
	redirect_riposte_party._heroes[0]["statuses"] = {"riposte": 4}
	var redirect_res := phase.execute_phase(redirect_riposte_party, redirect_enemies,
		[_attack(1, 5, 3)], redirect_guard)
	_check(redirect_res == {"ok": true, "events": [
		_guard_event(1, 3, true, 1, true, 0)]},
		"AC2: attack aimed at pos 3 redirects to pos 1")
	_check(redirect_riposte_party.get_hero(1)["block"] == 1
		and redirect_riposte_party.get_hero(1)["hp"] == 40
		and redirect_enemies.get_enemy(1)["hp"] == 8,
		"AC2: redirected actual recipient at pos 1 counters with her Riposte 4 (12 -> 8 HP)")

	# 7. Earlier shove in the same phase swaps Rag Duelist into the attacked slot:
	# the actual post-shove recipient at that slot determines Riposte.
	var shove_party := _riposte_party(2)
	var shove_deck := _riposte_deck("rag_duelist_cape_guard", 9406)
	var shove_enemies := _enemies()
	_check(riposte_service.play_card(shove_deck, shove_party, "rag_duelist_cape_guard").get("ok", false)
		and shove_party.get_hero(2)["block"] == 5
		and shove_party.get_hero(2)["statuses"] == {"riposte": 3},
		"AC2 precondition: Rag Duelist at pos 2 has Block 5 and Riposte 3")
	var shove_res := phase.execute_phase(shove_party, shove_enemies, [
		{"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 1, "direction": 1},
		_attack(2, 4, 1),
	])
	_check(shove_res.get("ok", false)
		and shove_party.get_hero(1)["id"] == "rag_duelist"
		and shove_party.get_hero(1)["block"] == 1
		and shove_party.get_hero(1)["hp"] == 30
		and shove_enemies.get_enemy(2)["hp"] == 12,
		"AC2: after shove moves Rag Duelist to pos 1, attack on pos 1 hits her and triggers Riposte 3")


## AC3 & AC4: Blind/Dodge misses, slain sources, pre-downed recipients, zero adjusted
## damage, missing/zero Riposte and malformed inputs trigger no counter and change no
## RNG/unrelated state; rejected phases roll back all staged changes atomically.
func _test_riposte_skips_misses_and_rollback() -> void:
	var riposte_service := CombatRagDuelistRiposteCards.new()
	var dodge_service := CombatRagDuelistDodgeCards.new()

	# 1. Blind miss on single and multi-hit attacks against Riposte hero: no counter.
	var blind_party := _riposte_party(2)
	var blind_deck := _riposte_deck("rag_duelist_duelist_reprise_plus", 9501)
	var blind_enemies := CombatEnemies.new([
		{"id": "wasp", "max_hp": 16, "bleed_on_attack": true}
	])
	_check(riposte_service.play_card(blind_deck, blind_party, "rag_duelist_duelist_reprise_plus").get("ok", false),
		"AC3 precondition: Rag Duelist has Riposte 7")
	blind_enemies._enemies[0]["statuses"] = {"blind_next_attack": 1}
	var blind_party_before := blind_party.get_heroes()
	var blind_res := phase.execute_phase(blind_party, blind_enemies,
		[{"enemy_position": 1, "type": "attack", "amount": 10, "hits": 2, "target_position": 2}])
	_check(blind_res == {"ok": true, "events": [_event("attack", 1, false, 2)]}
		and blind_party.get_heroes() == blind_party_before
		and blind_enemies.get_enemy(1)["hp"] == 16
		and blind_enemies.get_enemy(1)["statuses"] == {},
		"AC3: Blind miss consumes Blind, deals 0 damage, and triggers 0 Riposte")

	# 2. Dodge miss on Riposte hero: first hit misses (0 Riposte), second hit lands (triggers Riposte).
	var dodge_party := _riposte_party(2)
	var dodge_rng := RandomNumberGenerator.new()
	dodge_rng.seed = 9502
	var dodge_cards: Array[String] = [
		"rag_duelist_cape_slip", "rag_duelist_duelist_reprise",
		"warden_strike", "warden_brace", "tinker_pop_shot"
	]
	var dodge_deck := CombatDeck.new(dodge_cards, dodge_rng)
	_check(dodge_deck.start_turn()
		and dodge_service.play_card(dodge_deck, dodge_party, "rag_duelist_cape_slip").get("ok", false)
		and riposte_service.play_card(dodge_deck, dodge_party, "rag_duelist_duelist_reprise").get("ok", false)
		and dodge_party.get_hero(2)["statuses"] == {"dodge_next_attack": 1, "riposte": 5},
		"AC3 precondition: paid Cape Slip + Duelist Reprise arm both Dodge 1 and Riposte 5")
	var dodge_enemies := _enemies()
	var dodge_rng_before: int = dodge_deck._rng.state
	var dodge_res := phase.execute_phase(dodge_party, dodge_enemies,
		[_attack(1, 7, 2), _attack(2, 6, 2)])
	_check(dodge_res == {"ok": true, "events": [
		_event("attack", 1, false, 2),
		_event("attack", 2, true, 2)]},
		"AC3: enemy 1 misses on Dodge; enemy 2 lands after Dodge is spent")
	_check(dodge_party.get_hero(2)["hp"] == 24
		and dodge_party.get_hero(2)["statuses"] == {"riposte": 5}
		and dodge_enemies.get_enemy(1)["hp"] == 12
		and dodge_enemies.get_enemy(2)["hp"] == 10
		and dodge_deck._rng.state == dodge_rng_before,
		"AC3: Dodge-missed enemy 1 takes 0 Riposte; landing enemy 2 takes 5 Riposte (15 -> 10 HP)")

	# 3. Slain source and pre-downed recipient trigger no Riposte.
	var skip_party := _riposte_party(2)
	var skip_deck := _riposte_deck("rag_duelist_duelist_reprise", 9503)
	var skip_enemies := _enemies()
	_check(riposte_service.play_card(skip_deck, skip_party, "rag_duelist_duelist_reprise").get("ok", false),
		"AC3 precondition: Rag Duelist has Riposte 5")
	_check(skip_enemies.apply_damage(1, 12) and skip_enemies.is_slain(1)
		and skip_party.apply_damage(2, 30) and skip_party.is_downed(2),
		"AC3 precondition: enemy 1 is slain and Rag Duelist at pos 2 is pre-downed")
	var skip_party_before := skip_party.get_heroes()
	var skip_enemies_before := skip_enemies.get_enemies()
	var skip_res := phase.execute_phase(skip_party, skip_enemies,
		[_attack(1, 8, 1), _attack(2, 8, 2)])
	_check(skip_res == {"ok": true, "events": [
		_event("attack", 1, false, 1),
		_event("attack", 2, false, 2)]}
		and skip_party.get_heroes() == skip_party_before
		and skip_enemies.get_enemies() == skip_enemies_before,
		"AC3: slain attacker and pre-downed Riposte target produce no counter or state mutation")

	# 4. Zero adjusted damage (both literal 0 amount and Weak-attenuated 1 -> 0) triggers no Riposte.
	var zero_party := _riposte_party(2)
	var zero_deck := _riposte_deck("rag_duelist_cape_parry", 9504)
	var zero_enemies := _enemies()
	_check(riposte_service.play_card(zero_deck, zero_party, "rag_duelist_cape_parry").get("ok", false)
		and zero_enemies.apply_statuses({2: {"weak": 1}}),
		"AC3 precondition: Rag Duelist has Block 4 + Riposte 2; enemy 2 has Weak 1")
	var zero_party_before := zero_party.get_heroes()
	var zero_enemies_before := zero_enemies.get_enemies()
	# Enemy 1 attacks for 0; Enemy 2 attacks for 1 while Weak (floor(1 * 3/4) == 0).
	var zero_res := phase.execute_phase(zero_party, zero_enemies,
		[_attack(1, 0, 2), _attack(2, 1, 2)])
	_check(zero_res == {"ok": true, "events": [
		_event("attack", 1, true, 2),
		_event("attack", 2, true, 2)]}
		and zero_party.get_heroes() == zero_party_before
		and zero_enemies.get_enemies() == zero_enemies_before,
		"AC3: zero nominal and Weak-attenuated zero-damage attempts do not trigger Riposte")

	# 5. Missing or zero Riposte triggers no counter.
	for statuses in [{}, {"riposte": 0}, {"riposte": 0, "exposed": 1}]:
		var inert_party := _riposte_party(2)
		var inert_enemies := _enemies()
		inert_party._heroes[1]["statuses"] = statuses.duplicate(true)
		var inert_res := phase.execute_phase(inert_party, inert_enemies, [_attack(1, 4, 2)])
		_check(inert_res == {"ok": true, "events": [_event("attack", 1, true, 2)]}
			and inert_enemies.get_enemy(1)["hp"] == 12,
			"AC3: absent or zero Riposte deals 0 retaliation: " + str(statuses))

	# 6. Malformed Riposte statuses and invalid later beats fail closed without partial commit.
	seed(9595)
	var expected_global_rng := randi()
	seed(9595)
	for bad_val in [-1, 1.5, "3", true, false, null, [], {}]:
		var bad_party := _riposte_party(2)
		var bad_enemies := _enemies()
		bad_party._heroes[1]["statuses"] = {"riposte": bad_val}
		var bad_before := [bad_party.get_heroes(), bad_enemies.get_enemies()]
		_check(phase.execute_phase(bad_party, bad_enemies, [_attack(1, 4, 2)])
			== {"ok": false, "events": []}
			and [bad_party.get_heroes(), bad_enemies.get_enemies()] == bad_before,
			"AC3: malformed Riposte value fails closed with no mutation: " + str(bad_val))

	# Late-beat failure after an earlier staged Riposte kill/revive rolls back everything.
	var rollback_party := _riposte_party(2)
	var rollback_deck := _riposte_deck("rag_duelist_duelist_reprise_plus", 9505)
	var rollback_enemies := CombatEnemies.new([
		{"id": "wraith", "max_hp": 10, "revive_once": true},
		{"id": "blocker", "max_hp": 15},
	])
	_check(riposte_service.play_card(rollback_deck, rollback_party, "rag_duelist_duelist_reprise_plus").get("ok", false)
		and rollback_enemies.apply_damage(1, 6) and rollback_enemies.get_enemy(1)["hp"] == 4
		and rollback_enemies.gain_block(2, CombatEnemies.MAX_INT - 2),
		"AC3 precondition: enemy 1 will revive from Riposte 7 on beat 1; enemy 2 will overflow Block on beat 2")
	var rollback_hero_ref: Dictionary = rollback_party._heroes[1]
	var rollback_enemy_ref: Dictionary = rollback_enemies._enemies[0]
	var rollback_before := [
		rollback_party.get_heroes(),
		rollback_enemies.get_enemies(),
		rollback_deck._rng.state,
	]
	var rollback_intents := [_attack(1, 5, 2), _block(2, 3)]
	var rollback_intents_copy := rollback_intents.duplicate(true)
	_check(phase.execute_phase(rollback_party, rollback_enemies, rollback_intents)
		== {"ok": false, "events": []}
		and [
			rollback_party.get_heroes(),
			rollback_enemies.get_enemies(),
			rollback_deck._rng.state,
		] == rollback_before
		and rollback_intents == rollback_intents_copy
		and is_same(rollback_party._heroes[1], rollback_hero_ref)
		and is_same(rollback_enemies._enemies[0], rollback_enemy_ref),
		"AC3: late Block overflow rolls back earlier staged Riposte damage and revival latch")
	_check(randi() == expected_global_rng, "AC3: rejected Riposte batches consume no global RNG")

	# 7. Deterministic replay of a mixed Riposte + multi-hit + Block phase.
	var replay_traces: Array = []
	for rep in range(3):
		var rep_party := _riposte_party(2)
		var rep_deck := _riposte_deck("rag_duelist_cape_guard", 9506)
		var rep_enemies := CombatEnemies.new([
			{"id": "wasp", "max_hp": 14, "bleed_on_attack": true},
			{"id": "raider", "max_hp": 12, "enrage": true, "enrage_stacks": 1},
		])
		_check(rep_enemies.gain_block(1, 2)
			and riposte_service.play_card(rep_deck, rep_party, "rag_duelist_cape_guard").get("ok", false),
			"AC4 replay precondition")
		var rng_state_before: int = rep_deck._rng.state
		var rep_res := phase.execute_phase(rep_party, rep_enemies, [
			{"enemy_position": 1, "type": "attack", "amount": 6, "hits": 2, "target_position": 2},
			_attack(2, 5, 2),
		])
		_check(rep_res.get("ok", false) and rep_deck._rng.state == rng_state_before,
			"AC4: mixed Riposte phase succeeds without RNG consumption")
		replay_traces.append([rep_res, rep_party.get_heroes(), rep_enemies.get_enemies()])
	_check(replay_traces[0] == replay_traces[1] and replay_traces[1] == replay_traces[2],
		"AC4: identical Riposte phase fixtures replay deterministically")
	# Enemy 1 (2 hits of 3) and Enemy 2 (1 hit of 5+2=7) all hit living Rag Duelist (Riposte 3):
	# Enemy 1 takes 3 + 3 = 6 Riposte (2 Block + 4 HP -> 10 HP); Enemy 2 takes 3 Riposte (12 -> 9 HP).
	_check(replay_traces[0][2][0]["hp"] == 10 and replay_traces[0][2][0]["block"] == 0
		and replay_traces[0][2][1]["hp"] == 9
		and replay_traces[0][1][1]["hp"] == 22 and replay_traces[0][1][1]["block"] == 0
		and replay_traces[0][1][1]["statuses"] == {"riposte": 3, "bleed": 1},
		"AC4: exact multi-source Riposte, Enrage, Bleed, Block and HP outcomes verified")


const EYELET_SCRIPT = preload("res://scripts/combat_button_golem_eyelet_guard_cards.gd")
const EYELET_SPECS := [
	["button_golem_eyelet_guard", 6, 2],
	["button_golem_eyelet_guard_plus", 9, 3],
]


## A real three-hero party whose Button Golem really occupies `seat`, plus a real
## seeded deck holding the requested Eyelet printing at one energy.
func _eyelet_fixture(card_id: String, seat: int, seed_value: int) -> Array:
	var definitions: Array = [
		{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26}]
	definitions.insert(seat - 1, {"id": "button_golem", "max_hp": 30})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(seat)["id"] == "button_golem"
		and party.get_hero(seat)["hp"] == 30,
		"precondition: living Button Golem really occupies seat " + str(seat))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cards: Array[String] = [card_id, "warden_strike", "warden_brace",
		"tinker_pop_shot", "tinker_scrap_bomb"]
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.has(card_id) and deck.hand.count(card_id) == 1,
		"precondition: the shared hand really holds one " + card_id + " and 3 energy")
	var eyelet = EYELET_SCRIPT.new()
	var armed: Dictionary = eyelet.play_card(deck, party, card_id)
	var printed: Array = []
	for spec: Array in EYELET_SPECS:
		if spec[0] == card_id:
			printed = spec
	_check(not printed.is_empty() and armed.get("ok", false)
		and party.get_hero(seat)["block"] == int(printed[1])
		and eyelet.is_armed() and eyelet.get_armed_thorns() == int(printed[2]),
		"precondition: the paid " + card_id + " armed " + str(printed[2])
			+ " Thorns on seat " + str(seat))
	return [party, deck, eyelet, printed]


## AC2: a real End Turn's staged phase retaliates the armed 2/3 Thorns against the
## ORIGINAL attacker for each confirmed positive-damage hit on the pre-hit-living
## Golem — even a fully Block-absorbed hit — from every legal seat and printing,
## while misses, other heroes, non-attacks, a torn bearer and an unarmed fight
## never retaliate. Events, actor identity, slot order, revival and RNG stay exact.
func _test_eyelet_guard_thorns() -> void:
	for spec: Array in EYELET_SPECS:
		var card_id: String = spec[0]
		var block: int = spec[1]
		var thorns: int = spec[2]
		for seat in [1, 2, 3]:
			var fixture := _eyelet_fixture(card_id, seat, 9700 + seat)
			var party: CombatParty = fixture[0]
			var enemies := _enemies()
			var eyelet = fixture[2]
			_check(enemies.gain_block(1, 1),
				card_id + " seat " + str(seat) + ": attacker carries one real Block")
			var golem_ref: Dictionary = party._heroes[seat - 1]
			var enemy_ref: Dictionary = enemies._enemies[0]
			var other_ref: Dictionary = enemies._enemies[1]
			var result := phase.execute_phase(party, enemies, [_attack(1, 4, seat)],
				null, false, eyelet)
			_check(result == {"ok": true, "events": [_event("attack", 1, true, seat)]},
				card_id + " seat " + str(seat) + ": the beat keeps the ordinary event shape")
			_check(party.get_hero(seat)["hp"] == 30 and party.get_hero(seat)["block"] == block - 4,
				card_id + " seat " + str(seat) + ": hero Block absorbs first, no HP loss")
			_check(enemies.get_enemy(1)["block"] == 0
				and enemies.get_enemy(1)["hp"] == 12 - (thorns - 1),
				card_id + " seat " + str(seat) + ": attacker takes exactly " + str(thorns)
					+ " Thorns through its Block")
			_check(enemies.get_enemy(2) == other_ref,
				card_id + " seat " + str(seat) + ": a non-attacking sibling takes nothing")
			_check(is_same(party._heroes[seat - 1], golem_ref)
				and is_same(enemies._enemies[0], enemy_ref),
				card_id + " seat " + str(seat) + ": actor dictionaries keep their identity")
			_check(not party.get_hero(seat).get("statuses", {}).has("thorns")
				and eyelet.is_armed() and eyelet.get_armed_thorns() == thorns,
				card_id + " seat " + str(seat)
					+ ": armed Thorns stays fight state, never a hero status")

			# A fully Block-absorbed contact still retaliates exactly once.
			var absorbed := _eyelet_fixture(card_id, seat, 9704 + seat)
			var absorbed_party: CombatParty = absorbed[0]
			var absorbed_eyelet = absorbed[2]
			var absorbed_enemies := _enemies()
			_check(absorbed_party.gain_block(seat, 3),
				card_id + " seat " + str(seat) + ": bearer gains three extra Block")
			var absorb_res := phase.execute_phase(absorbed_party, absorbed_enemies,
				[_attack(1, block + 3, seat)], null, false, absorbed_eyelet)
			_check(absorb_res == {"ok": true, "events": [_event("attack", 1, true, seat)]}
				and absorbed_party.get_hero(seat)["hp"] == 30
				and absorbed_party.get_hero(seat)["block"] == 0,
				card_id + " seat " + str(seat) + ": the whole hit is Block-absorbed")
			_check(absorbed_enemies.get_enemy(1)["hp"] == 12 - thorns,
				card_id + " seat " + str(seat)
					+ ": a Block-absorbed confirmed hit still takes " + str(thorns))

			# A hit that downs the Golem still quotes the PRE-hit living bearer,
			# because the arming was live when the contact really happened.
			var lethal := _eyelet_fixture(card_id, seat, 9760 + seat)
			var lethal_party: CombatParty = lethal[0]
			var lethal_enemies := _enemies()
			var lethal_res := phase.execute_phase(lethal_party, lethal_enemies,
				[_attack(1, 60, seat)], null, false, lethal[2])
			_check(lethal_res == {"ok": true, "events": [_event("attack", 1, true, seat)]}
				and lethal_party.is_downed(seat) and lethal_party.get_hero(seat)["hp"] == 0,
				card_id + " seat " + str(seat) + ": the announced hit really tears the Golem")
			_check(lethal_enemies.get_enemy(1)["hp"] == 12 - thorns,
				card_id + " seat " + str(seat) + ": a hit that tears the pre-hit-living bearer"
					+ " still retaliates " + str(thorns))

			# Two hits of one announced attack retaliate independently.
			var multi := _eyelet_fixture(card_id, seat, 9707 + seat)
			var multi_party: CombatParty = multi[0]
			var multi_enemies := _enemies()
			var multi_res := phase.execute_phase(multi_party, multi_enemies,
				[{"enemy_position": 1, "type": "attack", "amount": 6, "hits": 2,
					"target_position": seat}], null, false, multi[2])
			_check(multi_res == {"ok": true, "events": [
				_event("attack", 1, true, seat), _event("attack", 1, true, seat)]},
				card_id + " seat " + str(seat) + ": both hits resolve in order")
			_check(multi_enemies.get_enemy(1)["hp"] == 12 - thorns * 2,
				card_id + " seat " + str(seat) + ": each confirmed hit retaliates "
					+ str(thorns) + " separately")

			# A Blind miss, a zero-damage hit and a non-attack never retaliate.
			var miss := _eyelet_fixture(card_id, seat, 9710 + seat)
			var miss_enemies := _enemies()
			miss_enemies._enemies[0]["statuses"] = {"blind_next_attack": 1}
			var miss_res := phase.execute_phase(miss[0], miss_enemies,
				[_attack(1, 4, seat)], null, false, miss[2])
			_check(miss_res.get("ok", false) and not miss_res["events"][0]["applied"]
				and miss_enemies.get_enemy(1)["hp"] == 12
				and miss_enemies.get_enemy(1)["block"] == 0
				and miss_enemies.get_enemy(1)["statuses"] == {},
				card_id + " seat " + str(seat) + ": a Blind miss takes no Thorns")
			var zero := _eyelet_fixture(card_id, seat, 9713 + seat)
			var zero_enemies := _enemies()
			var zero_res := phase.execute_phase(zero[0], zero_enemies,
				[_attack(1, 0, seat)], null, false, zero[2])
			_check(zero_res.get("ok", false) and zero_res["events"][0]["applied"]
				and zero_enemies.get_enemy(1)["hp"] == 12,
				card_id + " seat " + str(seat) + ": a zero-damage hit takes no Thorns")
			var idle := _eyelet_fixture(card_id, seat, 9716 + seat)
			var idle_enemies := _enemies()
			var idle_res := phase.execute_phase(idle[0], idle_enemies,
				[_block(1, 2)], null, false, idle[2])
			_check(idle_res.get("ok", false) and idle_enemies.get_enemy(1)["hp"] == 12
				and idle_enemies.get_enemy(1)["block"] == 2,
				card_id + " seat " + str(seat) + ": a non-attack beat takes no Thorns")

			# A hit on another hero, a pre-downed bearer and an unarmed fight stay inert.
			var other_seat: int = 1 if seat != 1 else 3
			var elsewhere := _eyelet_fixture(card_id, seat, 9719 + seat)
			var elsewhere_enemies := _enemies()
			var elsewhere_res := phase.execute_phase(elsewhere[0], elsewhere_enemies,
				[_attack(1, 4, other_seat)], null, false, elsewhere[2])
			_check(elsewhere_res.get("ok", false)
				and elsewhere_enemies.get_enemy(1)["hp"] == 12,
				card_id + " seat " + str(seat) + ": a hit on another hero takes no Thorns")
			var torn := _eyelet_fixture(card_id, seat, 9722 + seat)
			_check(torn[0].apply_damage(seat, 999) and torn[0].is_downed(seat),
				card_id + " seat " + str(seat) + ": the armed bearer is genuinely torn")
			var torn_enemies := _enemies()
			var torn_res := phase.execute_phase(torn[0], torn_enemies,
				[_attack(1, 4, seat)], null, false, torn[2])
			_check(torn_res.get("ok", false) and not torn_res["events"][0]["applied"]
				and torn_enemies.get_enemy(1)["hp"] == 12,
				card_id + " seat " + str(seat) + ": a torn bearer takes and deals no Thorns")
			var unarmed := _eyelet_fixture(card_id, seat, 9725 + seat)
			var unarmed_enemies := _enemies()
			var unarmed_phase := phase.execute_phase(unarmed[0], unarmed_enemies,
				[_attack(1, 4, seat)], null, false, EYELET_SCRIPT.new())
			_check(unarmed_phase.get("ok", false)
				and unarmed_enemies.get_enemy(1)["hp"] == 12,
				card_id + " seat " + str(seat) + ": an unarmed fight takes no Thorns")

	# A Guard redirect takes the hit AWAY from the armed bearer: no Thorns, and the
	# original Thorns receipt still belongs to the Warden reaction alone.
	var redirect_fixture := _eyelet_fixture("button_golem_eyelet_guard", 2, 9731)
	var redirect_party: CombatParty = redirect_fixture[0]
	var redirect_eyelet = redirect_fixture[2]
	var redirect_enemies := _enemies()
	var reactions := CombatWardenGuardReactions.new()
	var warden_catalog := WardenPoolCards.new()
	_check(reactions.apply_committed_card(warden_catalog.get_definition("warden_draw_fire"),
		redirect_party) and reactions.is_guarding() and reactions.get_thorns() == 0,
		"precondition: the Warden really Guards with no Thorns of her own")
	var redirect_res := phase.execute_phase(redirect_party, redirect_enemies,
		[_attack(1, 4, 2)], reactions, false, redirect_eyelet)
	_check(redirect_res == {"ok": true, "events": [_guard_event(1, 2, true, 1, true, 0)]},
		"a redirected hit keeps the exact Guard receipt with zero retaliation")
	_check(redirect_enemies.get_enemy(1)["hp"] == 12
		and redirect_party.get_hero(1)["hp"] == 40,
		"the redirected hit lands on the Warden and never on the armed Golem")

	# Expedition 2: the attacker dies to real Thorns and its once-only revival keeps
	# its original slot and latch through the same staged publication.
	var revive_fixture := _eyelet_fixture("button_golem_eyelet_guard_plus", 1, 9732)
	var revive_party: CombatParty = revive_fixture[0]
	var revive_eyelet = revive_fixture[2]
	var revive_enemies := CombatEnemies.new([
		{"id": "wraith", "max_hp": 2, "revive_once": true},
		{"id": "bystander", "max_hp": 15}])
	_check(revive_enemies.is_valid() and not revive_enemies.get_enemy(1).get("revived", false),
		"precondition: an unrevived two-HP wraith occupies the attacking slot")
	var revive_res := phase.execute_phase(revive_party, revive_enemies,
		[_attack(1, 2, 1)], null, false, revive_eyelet)
	_check(revive_res == {"ok": true, "events": [_event("attack", 1, true, 1)]},
		"a lethal Thorns retaliation still publishes the ordinary attack event")
	_check(revive_enemies.get_enemy(1)["position"] == 1
		and revive_enemies.get_enemy(1)["hp"] == 1
		and revive_enemies.get_enemy(1).get("revived") == true
		and not revive_enemies.is_slain(1),
		"Thorns kills the attacker once: it revives in its own slot with its latch")

	# RNG: a committed Eyelet phase draws nothing, and a rejected one publishes none
	# of its staged damage.
	seed(9741)
	var next_global := randi()
	seed(9741)
	var rng_fixture := _eyelet_fixture("button_golem_eyelet_guard", 1, 9742)
	var rng_party: CombatParty = rng_fixture[0]
	var rng_eyelet = rng_fixture[2]
	var rng_enemies := _enemies()
	_check(phase.execute_phase(rng_party, rng_enemies, [_attack(1, 5, 1)],
		null, false, rng_eyelet).get("ok", false) and randi() == next_global,
		"a committed Eyelet phase consumes no RNG")
	var rollback_fixture := _eyelet_fixture("button_golem_eyelet_guard", 1, 9743)
	var rollback_party: CombatParty = rollback_fixture[0]
	var rollback_eyelet = rollback_fixture[2]
	var rollback_enemies := _enemies()
	_check(rollback_enemies.gain_block(2, CombatEnemies.MAX_INT - 2),
		"precondition: the later source's Block is at exact capacity")
	var rollback_before := [rollback_party.get_heroes(), rollback_enemies.get_enemies()]
	var rollback_res := phase.execute_phase(rollback_party, rollback_enemies,
		[_attack(1, 5, 1), _block(2, 4)], null, false, rollback_eyelet)
	_check(rollback_res == {"ok": false, "events": []}
		and [rollback_party.get_heroes(), rollback_enemies.get_enemies()] == rollback_before,
		"a later failure rolls back the earlier staged Thorns damage completely")
	_check(rollback_eyelet.is_armed() and rollback_eyelet.get_armed_thorns() == 2,
		"a rejected phase leaves the armed mode untouched for the retry")
	var retry_res := phase.execute_phase(rollback_party, rollback_enemies,
		[_attack(1, 5, 1)], null, false, rollback_eyelet)
	_check(retry_res.get("ok", false) and rollback_enemies.get_enemy(1)["hp"] == 10,
		"the accepted retry still retaliates the same two Thorns")


## AC3: authentic charge preconditions, forged metadata, Blind, slain source,
## stale amount and a failed later beat never publish a phantom charge.
func _test_ram_charge_fail_closed() -> void:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var ram: Dictionary = {}
	for item in records:
		if item.get("id") == "spindle_ram":
			ram = item.duplicate(true)
	_check(not ram.is_empty() and ram.get("charge") == true
		and ram.get("intent", {}).get("actions", []).size() == 3,
		"AC3 precondition: real authored Ram and shove/Block/attack alternatives")
	if ram.is_empty():
		return
	ram["intent"]["actions"] = [ram["intent"]["actions"][2]]
	var control := {"id": "control", "max_hp": 16,
		"intent": {"target": "front", "actions": [
			{"type": "block", "amount": 3, "weight": 1}]}}
	var party := _party()
	var enemies := CombatEnemies.new([ram, control])
	var rng := RandomNumberGenerator.new()
	rng.seed = 690
	var scheduler := CombatEnemyIntents.new([{"enemy_position": 1,
		"pattern": [{"type": "block", "amount": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}])
	_check(enemies.is_valid() and scheduler.bind_battle(enemies, party, rng),
		"AC3 precondition: two occupied sources, genuine bound schedule and seeded RNG")
	if not scheduler.is_bound():
		return
	var windup := scheduler.get_intents()
	_check(windup.size() == 2 and windup[0].get("amount") == 0
		and windup[0].get("target_position") == 1 and windup[1].get("type") == "block",
		"AC3 precondition: unarmed Ram attack followed by valid separate Block actor")
	var rng_before := rng.state
	# The later Block overflows only after the Ram's staged wind-up.
	_check(enemies.gain_block(2, CombatEnemies.MAX_INT),
		"AC3 precondition: real later source holds maximal Block")
	var before_heroes := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	_check(phase.execute_phase(party, enemies, windup, null, true)
		== {"ok": false, "events": []}
		and party.get_heroes() == before_heroes
		and enemies.get_enemies() == before_enemies
		and rng.state == rng_before,
		"AC3: later failed Block rolls back the earlier wind-up and all party/actor state")
	_check(enemies.apply_damage(2, 0), "AC3 precondition: actor still present after refusal")
	# Replace the later action with a harmless valid attack to isolate Charge.
	var solo := [windup[0]]
	var malformed: Array = [
		{"charge": "true"},
		{"charge": 1},
		{"charge": false},
		{"charge_pending": true},
		{"charge_pending": {}},
		{"charge_pending": {"amount": 7, "target_position": 1}},
		{"charge_pending": {"amount": 8, "target_position": 4}},
		{"charge_pending": {"amount": 8, "target_position": 1, "extra": 0}}]
	for extra in malformed:
		var bad := CombatEnemies.new([ram])
		for field in extra:
			bad._enemies[0][field] = extra[field]
		var heroes := party.get_heroes()
		var actors := bad.get_enemies()
		var original_rng := rng.state
		_check(phase.execute_phase(party, bad, solo, null, true)
			== {"ok": false, "events": []}
			and party.get_heroes() == heroes and bad.get_enemies() == actors
			and rng.state == original_rng,
			"AC3: malformed Charge flag or stored strike fails closed " + str(extra))
	var other := CombatEnemies.new([control])
	other._enemies[0]["charge"] = true
	_check(phase.execute_phase(party, other, [_block(1, 3)]).get("ok") == false
		and not other.get_enemy(1).has("charge_pending"),
		"AC3: a non-Ram actor cannot forge a Charge keyword")
	var tampered := windup[0].duplicate(true)
	tampered["amount"] = 8
	before_heroes = party.get_heroes()
	var fresh := CombatEnemies.new([ram])
	before_enemies = fresh.get_enemies()
	_check(phase.execute_phase(party, fresh, [tampered], null, true).get("ok") == false
		and fresh.get_enemies() == before_enemies and party.get_heroes() == before_heroes,
		"AC3: stale unarmed eight-damage intent cannot bypass the telegraph")

	# AC1: Real Spindle Ram with Blind 1 retains Blind and stores charge_pending on unarmed Charge wind-up
	var blind_party := _party()
	_check(blind_party.gain_block(1, 6), "AC1 precondition: Warden carries 6 opening Block")
	var blind_heroes_before := blind_party.get_heroes()
	var blind_enemies := CombatEnemies.new([ram])
	blind_enemies._enemies[0]["statuses"] = {"blind_next_attack": 1}
	var blind_scheduler := CombatEnemyIntents.new([{"enemy_position": 1,
		"pattern": [{"type": "block", "amount": 1}]}])
	var blind_rng := RandomNumberGenerator.new()
	blind_rng.seed = 690
	_check(blind_scheduler.bind_battle(blind_enemies, blind_party, blind_rng),
		"AC1 precondition: genuine Ram bound with seeded scheduler")
	var announced_windup := blind_scheduler.get_intents()
	_check(announced_windup.size() == 1 and announced_windup[0] == {"type": "attack",
		"amount": 0, "target_position": 1, "enemy_position": 1},
		"AC1: battle-bound scheduler announces actual unarmed Charge {type: attack, amount: 0, target_position: 1}")
	var blind_rng_before := blind_rng.state
	var warden_record: Dictionary = blind_party._heroes[0]
	var ram_record: Dictionary = blind_enemies._enemies[0]
	var windup_res := phase.execute_phase(blind_party, blind_enemies, announced_windup, null, true)
	_check(windup_res == {"ok": true, "events": [{"type": "wind_up", "enemy_position": 1,
		"target_position": 1, "damage": 0, "applied": true}]},
		"AC1: unarmed Charge executes staged wind_up event with damage 0")
	_check(blind_party.get_heroes() == blind_heroes_before
		and blind_party.get_hero(1)["hp"] == 40 and blind_party.get_hero(1)["block"] == 6
		and blind_enemies.get_enemy(1).get("charge_pending") == {"amount": 8, "target_position": 1}
		and blind_enemies.get_enemy(1).get("statuses", {}) == {"blind_next_attack": 1}
		and blind_rng.state == blind_rng_before,
		"AC1: wind-up skips damage, arms charge_pending {amount: 8, target_position: 1}, retains Blind 1, no HP/Block/RNG change")
	_check(is_same(blind_party._heroes[0], warden_record) and is_same(blind_enemies._enemies[0], ram_record),
		"AC1: hero and enemy dictionary identities preserved")
	# Independently prove CombatStatuses / CombatStatusTurnBatch retains one-shot Blind across enemy owner-turn boundary
	var ticked := CombatStatusTurnBatch.new().tick_side("enemies", blind_enemies.get_enemies())
	_check(ticked.get("ok", false)
		and ticked["actors"][0].get("statuses", {}) == {"blind_next_attack": 1},
		"AC1: CombatStatusTurnBatch retains one-shot Blind across enemy owner-turn boundary")

	# AC2: Authentic armed follow-up announces 20, Blind consumes and cancels the entire strike
	_check(blind_scheduler.advance_turn() and blind_rng.state == blind_rng_before,
		"AC2: advancing genuine scheduler consumes no extra run RNG")
	var announced_strike := blind_scheduler.get_intents()
	_check(announced_strike.size() == 1 and announced_strike[0] == {"type": "attack",
		"amount": 20, "target_position": 1, "enemy_position": 1},
		"AC2: genuine scheduler announces floor(8 * 2.5) = 20 charged attack")
	var strike_res := phase.execute_phase(blind_party, blind_enemies, announced_strike, null, true)
	_check(strike_res == {"ok": true, "events": [{"type": "attack", "enemy_position": 1,
		"target_position": 1, "applied": false}]},
		"AC2: still-active Blind makes entire attempted 20-damage strike miss (applied: false)")
	_check(blind_party.get_heroes() == blind_heroes_before
		and blind_party.get_hero(1)["hp"] == 40 and blind_party.get_hero(1)["block"] == 6
		and not blind_enemies.get_enemy(1).has("charge_pending")
		and not blind_enemies.get_enemy(1).get("statuses", {}).has("blind_next_attack")
		and blind_rng.state == blind_rng_before,
		"AC2: miss consumes Blind and charge_pending latch exactly once, no hero HP/Block or RNG change")

	# AC2: Subsequent Ram attack must begin another WIND UP rather than replaying 20 damage
	_check(blind_scheduler.advance_turn() and blind_rng.state == blind_rng_before,
		"AC2: advancing scheduler after blinded strike consumes no RNG")
	var turn3_intents := blind_scheduler.get_intents()
	_check(turn3_intents.size() == 1 and turn3_intents[0] == {"type": "attack",
		"amount": 0, "target_position": 1, "enemy_position": 1},
		"AC2: subsequent attack begins another WIND UP (amount 0) rather than replaying 20 damage")
	var turn3_res := phase.execute_phase(blind_party, blind_enemies, turn3_intents, null, true)
	_check(turn3_res.get("ok", false) and turn3_res.get("events", [])[0].get("type") == "wind_up"
		and blind_enemies.get_enemy(1).get("charge_pending") == {"amount": 8, "target_position": 1},
		"AC2: subsequent attack executes as WIND UP and re-arms charge_pending")

	# AC2: Unblinded Ram 0 -> 20 cycle to ensure neither damage nor scaling regresses
	var unblind_party := _party()
	var unblind_enemies := CombatEnemies.new([ram])
	var unblind_scheduler := CombatEnemyIntents.new([{"enemy_position": 1,
		"pattern": [{"type": "block", "amount": 1}]}])
	var unblind_rng := RandomNumberGenerator.new()
	unblind_rng.seed = 693
	_check(unblind_scheduler.bind_battle(unblind_enemies, unblind_party, unblind_rng),
		"unblinded Ram binds battle")
	var unblind_w1 := unblind_scheduler.get_intents()
	_check(unblind_w1[0].get("amount") == 0, "unblinded Ram announces 0")
	var unblind_res1 := phase.execute_phase(unblind_party, unblind_enemies, unblind_w1, null, true)
	_check(unblind_res1.get("ok") and unblind_res1["events"][0]["type"] == "wind_up"
		and unblind_party.get_hero(1)["hp"] == 40
		and unblind_enemies.get_enemy(1).get("charge_pending") == {"amount": 8, "target_position": 1},
		"unblinded Ram winds up 0, deals 0 damage, and arms 8")
	_check(unblind_scheduler.advance_turn(), "advance unblinded Ram")
	var unblind_w2 := unblind_scheduler.get_intents()
	_check(unblind_w2[0].get("amount") == 20, "unblinded Ram announces 20")
	var unblind_res2 := phase.execute_phase(unblind_party, unblind_enemies, unblind_w2, null, true)
	_check(unblind_res2.get("ok") and unblind_res2["events"][0]["applied"] == true
		and unblind_party.get_hero(1)["hp"] == 20
		and not unblind_enemies.get_enemy(1).has("charge_pending"),
		"unblinded Ram strike delivers 20 damage (Warden 40 -> 20 HP) and clears charge_pending")

	# AC2: Legacy floor-scaled 9 -> 22 charge witness
	var scaled_party := _party()
	var scaled_ram: Dictionary = ram.duplicate(true)
	scaled_ram["intent"] = RunDifficulty.scale_intent(scaled_ram["intent"], 1)
	var scaled_enemies := CombatEnemies.new([scaled_ram])
	var scaled_scheduler := CombatEnemyIntents.new([{"enemy_position": 1,
		"pattern": [{"type": "block", "amount": 1}]}])
	var scaled_rng := RandomNumberGenerator.new()
	scaled_rng.seed = 694
	_check(scaled_scheduler.bind_battle(scaled_enemies, scaled_party, scaled_rng),
		"scaled Ram binds battle")
	var scaled_w1 := scaled_scheduler.get_intents()
	_check(scaled_w1[0].get("amount") == 0, "scaled Ram announces 0")
	var scaled_res1 := phase.execute_phase(scaled_party, scaled_enemies, scaled_w1, null, true)
	_check(scaled_res1.get("ok") and scaled_res1["events"][0]["type"] == "wind_up"
		and scaled_enemies.get_enemy(1).get("charge_pending") == {"amount": 9, "target_position": 1},
		"scaled Ram winds up 0 and arms 9")
	_check(scaled_scheduler.advance_turn(), "advance scaled Ram")
	var scaled_w2 := scaled_scheduler.get_intents()
	_check(scaled_w2[0].get("amount") == 22, "scaled Ram announces floor(9 * 2.5) = 22")
	var scaled_res2 := phase.execute_phase(scaled_party, scaled_enemies, scaled_w2, null, true)
	_check(scaled_res2.get("ok") and scaled_res2["events"][0]["applied"] == true
		and scaled_party.get_hero(1)["hp"] == 18
		and not scaled_enemies.get_enemy(1).has("charge_pending"),
		"scaled Ram delivers 22 damage (Warden 40 -> 18 HP) and clears charge_pending")

	# AC4: Malformed Blind tokens on Ram fail closed without mutation
	for bad_blind in [true, 1.0, "1", -1, 2, null, [], {}]:
		var mal_party := _party()
		var mal_enemies := CombatEnemies.new([ram])
		mal_enemies._enemies[0]["statuses"] = {"blind_next_attack": bad_blind}
		var mal_heroes_before := mal_party.get_heroes()
		var mal_enemies_before := mal_enemies.get_enemies()
		_check(phase.execute_phase(mal_party, mal_enemies, solo, null, true) == {"ok": false, "events": []}
			and mal_party.get_heroes() == mal_heroes_before
			and mal_enemies.get_enemies() == mal_enemies_before,
			"malformed Blind token on Ram rejects fail-closed: " + str(bad_blind))

	# AC4: A forged near-hit cannot spend or bypass an authentic pending strike.
	var ready := CombatEnemies.new([ram])
	_check(phase.execute_phase(blind_party, ready, solo, null, true).get("ok")
		and ready.get_enemy(1).get("charge_pending", {}).get("amount") == 8,
		"AC4 precondition: a real unblinded wind-up stored a valid attack")
	var bad_strike := [_attack(1, 19, 1)]
	before_heroes = blind_party.get_heroes()
	before_enemies = ready.get_enemies()
	_check(phase.execute_phase(blind_party, ready, bad_strike, null, true)
		== {"ok": false, "events": []}
		and blind_party.get_heroes() == before_heroes
		and ready.get_enemies() == before_enemies,
		"AC4: stale held amount fails closed without spending the actor latch")

	# AC4: Slain Ram cannot strike or mutate state
	var dead := CombatEnemies.new([ram])
	_check(phase.execute_phase(blind_party, dead, solo, null, true).get("ok")
		and dead.get_enemy(1).has("charge_pending")
		and dead.apply_damage(1, 30) and dead.is_slain(1),
		"AC4 precondition: armed Ram is genuinely dead before release")
	before_heroes = blind_party.get_heroes()
	var strike := [_attack(1, 20, 1)]
	var slain_receipt := phase.execute_phase(blind_party, dead, strike, null, true)
	_check(slain_receipt.get("ok") and slain_receipt.get("events", [])[0].get("applied") == false
		and blind_party.get_heroes() == before_heroes and dead.get_enemy(1).get("hp") == 0,
		"AC4: dead Ram has no strike, no HP mutation or resurrection")

## Two actual normal catalogs feed these weighted combat actors. No test-only
## action shapes replace their authored choices or target policies.
func _phase_four_authored_normals() -> Array:
	var wanted := ["moth_swarm", "button_guard", "spool_stalker", "ragling_guard"]
	var found := {}
	for catalog_path in ["res://data/enemies/run_enemies.json",
			"res://data/enemies/starter_enemies.json"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		if not parsed is Array:
			return []
		for entry in parsed:
			if entry is Dictionary and entry.get("id") in wanted:
				var actor: Dictionary = entry.duplicate(true)
				actor["max_hp"] = int(actor["max_hp"])
				found[actor["id"]] = actor
	var records: Array = []
	for id in wanted:
		if not found.has(id):
			return []
		records.append(found[id])
	return records


func _four_phase_scheduler() -> CombatEnemyIntents:
	var slots: Array = []
	for position in range(1, 5):
		slots.append({"enemy_position": position, "pattern": [
			{"type": "block", "amount": 1}]})
	return CombatEnemyIntents.new(slots)


func _test_four_catalog_phase_and_refusals() -> void:
	var authored := _phase_four_authored_normals()
	_check(authored.size() == 4, "AC2 precondition: four distinct actors loaded from real normal catalogs")
	if authored.size() != 4:
		return
	var enemies := CombatEnemies.new(authored, 4)
	var party := _party()
	var rng := RandomNumberGenerator.new()
	rng.seed = 422407
	var scheduler := _four_phase_scheduler()
	_check(enemies.is_valid() and enemies.get_capacity() == 4
		and scheduler.is_valid() and scheduler.bind_battle(enemies, party, rng)
		and scheduler.get_intents().size() == 4,
		"AC2 precondition: four authenticated living source slots bind their weighted policies")
	if not scheduler.is_bound():
		return
	_check(party.gain_block(1, 12) and enemies.gain_block(4, 3)
		and enemies.apply_statuses({4: {"weak": 1}})
		and enemies.get_enemy(4).id == "ragling_guard",
		"AC2 precondition: real front Block and fourth-slot enemy Block/Weak exist")
	var announced := scheduler.get_intents()
	var enemy_before := enemies.get_enemies()
	var hero_before := party.get_heroes()
	var state_before := rng.state
	var references := [enemies._enemies[0], enemies._enemies[1],
		enemies._enemies[2], enemies._enemies[3]]
	# A forged fourth action cannot spend a status, one weighted draw, HP or Block.
	var forged := announced.duplicate(true)
	forged[3]["amount"] = -1
	_check(not phase.execute_phase(party, enemies, forged, null, true).ok
		and enemies.get_enemies() == enemy_before
		and party.get_heroes() == hero_before and rng.state == state_before,
		"AC3: invalid fourth beat rejects before any actor/state/RNG mutation")
	var invented := announced.duplicate(true)
	invented.append({"type": "block", "amount": 4, "enemy_position": 5})
	_check(not phase.execute_phase(party, enemies, invented, null, true).ok
		and enemies.get_enemies() == enemy_before and party.get_heroes() == hero_before
		and rng.state == state_before,
		"AC3: nonexistent fifth source is rejected atomically")
	# Reverse the caller array: execution still uses the authentic source slots.
	var reversed := announced.duplicate(true)
	reversed.reverse()
	var trace := phase.execute_phase(party, enemies, reversed, null, true)
	var ordered: bool = bool(trace.get("ok", false)) and trace.get("events", []).size() == 4
	if ordered:
		for index in range(4):
			ordered = ordered and trace["events"][index].enemy_position == index + 1
			ordered = ordered and trace["events"][index].type == announced[index].type
	_check(ordered and announced.size() == 4 and reversed.size() == 4,
		"AC2: all four original authored weighted beats execute once in slot order")
	_check(rng.state == state_before and scheduler.get_intents() == announced
		and announced[3].enemy_position == 4
		and enemies.get_enemy(4).get("statuses", {}).get("weak") == 1
		and enemies.get_enemy(4).get("hp") == enemy_before[3].hp
		and is_same(enemies._enemies[3], references[3]),
		"AC2/AC3: fourth source keeps its own identity/Weak/HP and phase consumes no RNG")
	_check(party.get_heroes() != hero_before or enemies.get_enemies() != enemy_before,
		"AC2: a nonempty genuine four-source phase writes actual combat results")
	# Independent same-seed replay reaches the identical real phase, including
	# fourth-slot statuses, Block changes and the complete ordered event trace.
	var replay_party := _party()
	var replay_enemies := CombatEnemies.new(authored, 4)
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 422407
	var replay_scheduler := _four_phase_scheduler()
	_check(replay_scheduler.bind_battle(replay_enemies, replay_party, replay_rng)
		and replay_party.gain_block(1, 12)
		and replay_enemies.gain_block(4, 3)
		and replay_enemies.apply_statuses({4: {"weak": 1}})
		and replay_scheduler.get_intents() == announced,
		"AC3 precondition: second authentic four-source fight announces exact seeded choices")
	var replay_trace := phase.execute_phase(
		replay_party, replay_enemies, replay_scheduler.get_intents(), null, true)
	_check(replay_trace == trace and replay_enemies.get_enemies() == enemies.get_enemies()
		and replay_party.get_heroes() == party.get_heroes() and replay_rng.state == rng.state,
		"AC3: independent seeded four-source phase replays exact events, statuses, HP, Block and RNG")
	# Slay the fourth real source: it stays in slot four but its next announced
	# action is skipped; the first three living actors still resolve.
	var next_party := _party()
	var slain_enemies := CombatEnemies.new(authored, 4)
	var slain_rng := RandomNumberGenerator.new()
	slain_rng.seed = 422407
	var slain_scheduler := _four_phase_scheduler()
	_check(slain_scheduler.bind_battle(slain_enemies, next_party, slain_rng)
		and slain_enemies.apply_damage(4, 1000) and slain_enemies.is_slain(4)
		and slain_enemies.get_enemy(4).id == "ragling_guard",
		"AC2 precondition: fourth authentic source is slain but retains its slot")
	var dead_announcement := slain_scheduler.get_intents()
	var dead_state := slain_rng.state
	var dead_result := phase.execute_phase(next_party, slain_enemies, dead_announcement, null, true)
	_check(dead_result.get("ok", false) and dead_result.get("events", []).size() == 4
		and not dead_result["events"][3].applied and slain_enemies.is_slain(4)
		and slain_rng.state == dead_state,
		"AC2: slain fourth beat is inert; three other sources still execute")
	# The genuine Moth Swarm can summon only into a free opted-in slot. Search
	# successive cached authored phases with one fixed seed, never forge summon.
	var birth_party := _party()
	var birth_enemies := CombatEnemies.new([authored[0], authored[1], authored[2]], 4)
	var birth_rng := RandomNumberGenerator.new()
	birth_rng.seed = 422408
	var birth_slots: Array = []
	for position in range(1, 4):
		birth_slots.append({"enemy_position": position, "pattern": [
			{"type": "block", "amount": 1}]})
	var birth_schedule := CombatEnemyIntents.new(birth_slots)
	_check(birth_enemies.is_valid()
		and birth_schedule.bind_battle(birth_enemies, birth_party, birth_rng),
		"AC2 precondition: three genuine authored living sources have room for one birth")
	var found_summon := false
	for turn in range(80):
		var preview := birth_schedule.get_intents()
		if preview.size() == 3 and preview[0].type == "summon":
			found_summon = true
			break
		if not birth_schedule.advance_turn():
			break
	_check(found_summon, "AC2: seeded authentic mother chooses its authored summon alternative")
	if not found_summon:
		return
	var birth_actions := birth_schedule.get_intents()
	var birth_rng_before := birth_rng.state
	var born := phase.execute_phase(birth_party, birth_enemies, birth_actions, null, true)
	_check(born.get("ok", false) and born.get("events", []).size() == 3
		and born["events"][0].type == "summon" and born["events"][0].applied
		and born["events"][0].get("spawn_position") == 4
		and birth_enemies.get_enemies().size() == 4
		and birth_enemies.get_enemy(4).id == CombatEnemies.BROODLING_ID
		and birth_enemies.get_enemy(4).hp == 8 and birth_rng.state == birth_rng_before,
		"AC2: authored summon commits fourth child after all three current-phase beats")
	_check(birth_schedule.get_intents().size() == 3 and birth_schedule.advance_turn()
		and birth_schedule.get_intents().size() == 4
		and birth_schedule.get_intents()[3].enemy_position == 4,
		"AC2: newborn cannot act in its birth phase; it first receives next-phase intent")
	var born_before := birth_enemies.get_enemies()
	var full_rng := birth_rng.state
	var blocked_birth := birth_enemies.stage_broodling(1)
	_check(blocked_birth == {"ok": true, "spawned": false}
		and birth_enemies.get_enemies() == born_before and birth_rng.state == full_rng,
		"AC3: a full opted-in roster refuses another birth without RNG, latch or state mutation")
	# Non-opt-in rosters cannot impersonate four by injecting the same content.
	var default_four := CombatEnemies.new(authored)
	var deny_rng := RandomNumberGenerator.new()
	deny_rng.seed = 422409
	var deny_state := deny_rng.state
	var deny_result := phase.execute_phase(_party(), default_four, announced, null, true)
	_check(not default_four.is_valid() and not deny_result.ok
		and deny_rng.state == deny_state,
		"AC3: default three-actor battle refuses a detached four-source phase")
