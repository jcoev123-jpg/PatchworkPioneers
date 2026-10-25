extends SceneTree
## Phase-level Warden reaction handoff, exercised through paid seeded cards.

var checks: int = 0
var failures: Array[String] = []
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_draw_fire_variants()
	_test_counter_stitch_variants()
	_test_joint_modes_and_turn_boundary()
	_test_guard_redirect_drain()
	_test_skips_and_rollback()
	if failures.is_empty():
		print("combat_enemy_phase_guard_reactions_test: PASS (", checks, " checks)")
	else:
		for message: String in failures:
			printerr(message)
		print("combat_enemy_phase_guard_reactions_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)


func _party() -> CombatParty:
	var definitions: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	_check(definitions is Array, "precondition: real starter hero JSON loaded")
	# Godot's JSON parser represents numeric JSON values as float, whereas
	# CombatParty's definition contract requires integral max_hp.
	var authored: Array = []
	if definitions is Array:
		for record_v: Variant in definitions:
			if record_v is Dictionary:
				var record: Dictionary = record_v.duplicate(true)
				if record.get("max_hp") is float or record.get("max_hp") is int:
					record["max_hp"] = int(record["max_hp"])
				authored.append(record)
	var party := CombatParty.new(authored)
	_check(party.is_valid() and party.get_hero(1).id == "warden"
		and party.get_hero(1).max_hp == 40 and party.get_hero(2).id == "seamstress"
		and party.get_hero(3).id == "tinker", "precondition: three correctly positioned heroes")
	_check(CombatStartingBlock.new(party).apply()
		and party.get_hero(1).block == 6, "precondition: authentic opening Warden Block")
	return party


func _enemies(hps: Array[int]) -> CombatEnemies:
	var definitions: Array = []
	for index: int in range(hps.size()):
		definitions.append({"id": "rag-" + str(index + 1), "max_hp": hps[index]})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(),
		"precondition: real enemy roster with original source slots")
	for index: int in range(hps.size()):
		_check(enemies.get_enemy(index + 1).hp == hps[index], "precondition: enemy HP authored")
	return enemies


func _deck(held_cards: Array[String]) -> CombatDeck:
	_check(held_cards.size() == 5, "precondition: hand fixture has exactly five cards")
	var rng := RandomNumberGenerator.new()
	rng.seed = 131006
	var deck := CombatDeck.new(held_cards, rng)
	_check(deck.start_turn() and deck.hand.size() == 5 and deck.energy == 3,
		"precondition: actual seeded five-card draw and three shared energy")
	for id: String in held_cards:
		_check(deck.hand.has(id), "precondition: paid card exists in real hand: " + id)
	return deck


func _hit(source: int, announced: int, applied: bool, actual: int,
		redirected: bool, thorns_damage: int) -> Dictionary:
	return {"type": "attack", "enemy_position": source, "target_position": announced,
		"applied": applied, "actual_target_position": actual, "redirected": redirected,
		"retaliation_damage": thorns_damage, "retaliatory_damage": thorns_damage}


func _attack(source: int, amount: int, target: int) -> Dictionary:
	return {"type": "attack", "enemy_position": source, "amount": amount,
		"target_position": target}


func _block(source: int, amount: int) -> Dictionary:
	return {"type": "block", "enemy_position": source, "amount": amount}


func _test_draw_fire_variants() -> void:
	for id: String in ["warden_draw_fire", "warden_draw_fire_plus"]:
		var expected_extra_block: int = 6 if id == "warden_draw_fire" else 8
		var party := _party()
		var enemies := _enemies([12, 15, 18])
		var deck := _deck([id, "warden_counter_stitch", "warden_hold_the_line",
			"warden_iron_hem", "warden_quick_darn"])
		var reactions := CombatWardenGuardReactions.new()
		_check(enemies.apply_statuses({1: {"weak": 2}}),
			"AC1 precondition: source 1 actually has Weak")
		party._heroes[0]["statuses"] = {"exposed": 2}
		party._heroes[1]["statuses"] = {"weak": 2}
		_check(party.get_hero(1).statuses == {"exposed": 2}
			and party.get_hero(2).statuses == {"weak": 2},
			"AC1 precondition: Warden Exposed differs from announced ally's statuses")
		var original_warden: Dictionary = party._heroes[0]
		var original_enemy: Dictionary = enemies._enemies[0]
		_check(reactions.play_from_hand(deck, party, id),
			"AC1: play authentic " + id + " from held hand")
		_check(party.get_hero(1).block == 6 + expected_extra_block
			and reactions.is_guarding() and reactions.get_thorns() == 0
			and deck.energy == 2 and deck.discard_pile == [id],
			"AC1: " + id + " spends once, applies exact Block and Guarding")
		var state_before: int = deck._rng.state
		var announcements := CombatEnemyIntents.new([
			{"enemy_position": 3, "pattern": [{"type": "block", "amount": 5}]},
			{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 10,
				"target_position": 1}]},
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 8,
				"target_position": 2}]}])
		_check(announcements.is_valid(), "AC1 precondition: real valid intent scheduler")
		var input: Array[Dictionary] = announcements.get_intents()
		_check(input.size() == 3 and input[0].enemy_position == 1,
			"AC1 precondition: three announced actions ordered by real scheduler")
		input.reverse()
		var input_before: Array = input.duplicate(true)
		var events: Dictionary = phase.execute_phase(party, enemies, input, reactions)
		_check(events == {"ok": true, "events": [
			_hit(1, 2, true, 1, true, 0),
			_hit(2, 1, true, 1, false, 0),
			{"type": "block", "enemy_position": 3, "applied": true}]},
			"AC1: " + id + " actual target and source order, no announcement rewrite")
		# 8 Weak + Warden Exposed => floor(8 * 9/8) = 9.
		# 10 + Warden Exposed => 15, for 24 total vs 12/14 Block.
		_check(party.get_hero(1).hp == (28 if expected_extra_block == 6 else 30)
			and party.get_hero(1).block == 0,
			"AC1: damage calculated from redirected Warden's Exposed, not ally's Weak")
		_check(party.get_hero(2).hp == 30 and party.get_hero(3).hp == 26
			and party.get_hero(2).statuses == {"weak": 2},
			"AC1: announced ally never takes redirected hit or changes statuses")
		_check(enemies.get_enemy(1).hp == 12 and enemies.get_enemy(2).hp == 15
			and enemies.get_enemy(3).block == 5,
			"AC1: enemy block in slot 3 persists; no Thorns in Guard-only case")
		_check(is_same(party._heroes[0], original_warden)
			and is_same(enemies._enemies[0], original_enemy),
			"AC1: publication keeps original actor dictionaries")
		_check(input == input_before and announcements.get_intents()[0].enemy_position == 1
			and deck._rng.state == state_before and reactions.is_guarding(),
			"AC1: no RNG, caller schedule, or Guarding-mode consumption")


func _test_counter_stitch_variants() -> void:
	for id: String in ["warden_counter_stitch", "warden_counter_stitch_plus"]:
		var thorns: int = 3 if id == "warden_counter_stitch" else 4
		var block_gain: int = 5 if thorns == 3 else 7
		var party := _party()
		var enemies := _enemies([4, 9, 8])
		var deck := _deck([id, "warden_draw_fire", "warden_iron_hem",
			"warden_hold_the_line", "warden_quick_darn"])
		var reactions := CombatWardenGuardReactions.new()
		_check(reactions.play_from_hand(deck, party, id) and not reactions.is_guarding()
			and reactions.get_thorns() == thorns
			and party.get_hero(1).block == 6 + block_gain
			and deck.energy == 2, "AC2: paid " + id + " authors Block and Thorns")
		var state_before: int = deck._rng.state
		var input := [_block(3, 2), _attack(2, 7, 2), _attack(1, 6, 1)]
		var events: Dictionary = phase.execute_phase(party, enemies, input, reactions)
		_check(events == {"ok": true, "events": [
			_hit(1, 1, true, 1, false, thorns),
			_hit(2, 2, true, 2, false, 0),
			{"type": "block", "enemy_position": 3, "applied": true}]},
			"AC2: " + id + " Thorns retaliates only for a hit on the Warden")
		_check(party.get_hero(1).hp == 40 and party.get_hero(1).block == block_gain
			and party.get_hero(2).hp == 23 and party.get_hero(3).hp == 26,
			"AC2: authored Block absorbs hit while ally receives unguarded damage")
		_check(enemies.get_enemy(1).hp == 4 - thorns
			and enemies.is_slain(1) == (thorns == 4)
			and enemies.get_enemy(2).hp == 9 and enemies.get_enemy(3).block == 2,
			"AC2: retaliation persists in source 1 original roster slot")
		_check(reactions.get_thorns() == thorns and deck._rng.state == state_before,
			"AC2: Thorns duration and seeded RNG unchanged by phase")


func _test_joint_modes_and_turn_boundary() -> void:
	var party := _party()
	var enemies := _enemies([3, 8, 9])
	var deck := _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and reactions.play_from_hand(deck, party, "warden_counter_stitch")
		and deck.energy == 1 and party.get_hero(1).block == 17
		and reactions.is_guarding() and reactions.get_thorns() == 3,
		"AC2: distinct paid cards activate simultaneous Guarding and Thorns")
	party._heroes[0]["statuses"] = {"exposed": 2}
	_check(enemies.apply_statuses({1: {"weak": 2}}),
		"AC2 precondition: source 1 Weak while target Warden Exposed")
	var originals: Array = enemies._enemies.duplicate()
	var rng_before: int = deck._rng.state
	var actions := [_attack(3, 4, 1), _attack(2, 8, 3), _attack(1, 8, 2)]
	var result: Dictionary = phase.execute_phase(party, enemies, actions, reactions)
	_check(result == {"ok": true, "events": [
		_hit(1, 2, true, 1, true, 3),
		_hit(2, 3, true, 1, true, 3),
		_hit(3, 1, true, 1, false, 3)]},
		"AC2: simultaneous Guarding redirects two allied hits; all actual hits retaliate")
	# Three sequential hits: 9 + 12 + 6 = 27, first 17 absorbed.
	_check(party.get_hero(1).hp == 30 and party.get_hero(1).block == 0
		and party.get_hero(2).hp == 30 and party.get_hero(3).hp == 26,
		"AC2: independent three-source trace consumes 17 Block and 10 Warden HP")
	_check(enemies.get_enemy(1).hp == 0 and enemies.get_enemy(2).hp == 5
		and enemies.get_enemy(3).hp == 6 and enemies.is_slain(1),
		"AC2: lethal first retaliator remains slain in original roster slot")
	_check(is_same(enemies._enemies[0], originals[0]) and is_same(enemies._enemies[1], originals[1])
		and deck._rng.state == rng_before and reactions.is_guarding()
		and reactions.get_thorns() == 3,
		"AC2: persistent IDs and modes survive publish; no phase RNG use")
	_check(reactions.begin_player_turn() and not reactions.is_active()
		and not reactions.is_guarding() and reactions.get_thorns() == 0,
		"AC2: explicit next-player-turn boundary, not phase, clears both modes")
	var post: Dictionary = phase.execute_phase(party, enemies, [_attack(2, 4, 2)], reactions)
	_check(post == {"ok": true, "events": [_hit(2, 2, true, 2, false, 0)]}
		and party.get_hero(2).hp == 26 and enemies.get_enemy(2).hp == 5,
		"AC2: expired reaction instance allows direct ally hit without retaliation")


func _test_skips_and_rollback() -> void:
	var party := _party()
	var enemies := _enemies([5, 8, 9])
	var deck := _deck(["warden_draw_fire_plus", "warden_counter_stitch_plus",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire_plus")
		and reactions.play_from_hand(deck, party, "warden_counter_stitch_plus")
		and party.get_hero(1).block == 21 and reactions.get_thorns() == 4
		and reactions.is_guarding(),
		"AC3 precondition: both + paid cards, 6+8+7 Block and Thorns 4")
	_check(enemies.apply_damage(1, 5) and enemies.is_slain(1)
		and party.apply_damage(3, 26) and party.is_downed(3),
		"AC3 precondition: first source slain and an announced ally already downed")
	var before_party: Array = party.get_heroes()
	var state_before: int = deck._rng.state
	var events: Dictionary = phase.execute_phase(party, enemies,
		[_block(3, 2), _attack(2, 20, 3), _attack(1, 7, 2)], reactions)
	_check(events == {"ok": true, "events": [
		_hit(1, 2, false, 2, false, 0),
		_hit(2, 3, false, 3, false, 0),
		{"type": "block", "enemy_position": 3, "applied": true}]},
		"AC3: slain source and downed announced target never redirect or retaliate")
	_check(party.get_heroes() == before_party and enemies.get_enemy(1).hp == 0
		and enemies.get_enemy(3).block == 2 and deck._rng.state == state_before,
		"AC3: skipped attacks leave live heroes intact, remaining source acts")
	# A downed Warden cannot intercept; living allies remain attackable.
	var party_down := _party()
	var enemies_down := _enemies([5])
	var deck_down := _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var reactions_down := CombatWardenGuardReactions.new()
	_check(reactions_down.play_from_hand(deck_down, party_down, "warden_draw_fire")
		and reactions_down.play_from_hand(deck_down, party_down, "warden_counter_stitch")
		and party_down.apply_damage(1, 100) and party_down.is_downed(1),
		"AC3 precondition: guarding Warden is now genuinely downed")
	var fallen: Dictionary = phase.execute_phase(party_down, enemies_down,
		[_attack(1, 5, 2)], reactions_down)
	_check(fallen == {"ok": true, "events": [_hit(1, 2, true, 2, false, 0)]}
		and party_down.get_hero(2).hp == 25 and enemies_down.get_enemy(1).hp == 5,
		"AC3: downed Warden cannot guard/retaliate for living ally")

	# Late delegated overflow after an earlier staged redirect + lethal retaliation.
	var rollback_party := _party()
	var rollback_enemies := _enemies([3, 7])
	var rollback_deck := _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var rollback_reactions := CombatWardenGuardReactions.new()
	_check(rollback_reactions.play_from_hand(rollback_deck, rollback_party, "warden_draw_fire")
		and rollback_reactions.play_from_hand(rollback_deck, rollback_party, "warden_counter_stitch")
		and rollback_enemies.gain_block(2, CombatEnemies.MAX_INT - 2),
		"AC3 precondition: live paid modes and later source close to Block overflow")
	var roster_originals: Array = rollback_enemies._enemies.duplicate()
	var hero_originals: Array = rollback_party._heroes.duplicate()
	var snapshot: Array = [rollback_party.get_heroes(), rollback_enemies.get_enemies(),
		rollback_deck.hand.duplicate(), rollback_deck.discard_pile.duplicate(),
		rollback_deck.energy, rollback_deck._rng.state]
	var bad_result: Dictionary = phase.execute_phase(rollback_party, rollback_enemies,
		[_block(2, 3), _attack(1, 5, 2)], rollback_reactions)
	_check(bad_result == {"ok": false, "events": []},
		"AC3: late Block overflow rejects full staged redirect/retaliation")
	_check([rollback_party.get_heroes(), rollback_enemies.get_enemies(),
		rollback_deck.hand, rollback_deck.discard_pile, rollback_deck.energy,
		rollback_deck._rng.state] == snapshot,
		"AC3: no partial HP/Block, discard, energy or seeded RNG publish on failure")
	_check(is_same(rollback_party._heroes[0], hero_originals[0])
		and is_same(rollback_enemies._enemies[0], roster_originals[0])
		and rollback_reactions.is_guarding() and rollback_reactions.get_thorns() == 3,
		"AC3: failed phase retains live IDs and reaction modes")
	var invalid_actions: Array = [
		[_attack(1, 5, 2), _attack(2, 4, 4)],
		[_attack(1, 5, 2), _attack(1, 3, 1)],
		[_attack(1, 5, 2), {"type": "debuff", "enemy_position": 2,
			"target_position": 1, "status": "invalid", "amount": 1}],
	]
	for actions: Array in invalid_actions:
		var prev: Array = [rollback_party.get_heroes(), rollback_enemies.get_enemies()]
		var rejected: Dictionary = phase.execute_phase(rollback_party, rollback_enemies,
			actions, rollback_reactions)
		_check(rejected == {"ok": false, "events": []} and prev == [
			rollback_party.get_heroes(), rollback_enemies.get_enemies()]
			and rollback_deck._rng.state == snapshot[5],
			"AC3: invalid/stale target, duplicate source or forged action rejected atomically")
	# Existing 3-arg shape is checked exhaustively by combat_enemy_phase_test.gd.
	var default_result: Dictionary = phase.execute_phase(rollback_party,
		rollback_enemies, [_attack(1, 1, 2)])
	_check(default_result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2}]},
		"AC3: no-reaction three-arg event contains no new reaction-only keys")


func _drain_enemies(hps: Array[int], drain_flags: Array) -> CombatEnemies:
	var definitions: Array = []
	for index: int in range(hps.size()):
		var definition := {"id": "bobbin-" + str(index + 1), "max_hp": hps[index]}
		if index < drain_flags.size():
			definition["drain"] = drain_flags[index]
		definitions.append(definition)
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(),
		"precondition: real Drain roster with original source slots")
	return enemies


## AC3: with a genuine paid Guard redirect, Drain reads the actual recipient's
## post-Block Warden HP loss, not the announced ally or the nominal damage, and
## a source slain by lethal Thorns retaliation in that same beat stays slain.
func _test_guard_redirect_drain() -> void:
	var party := _party()
	var enemies := _drain_enemies([12, 15], [true, false])
	_check(enemies.apply_damage(1, 8) and enemies.get_enemy(1).hp == 4
		and enemies.get_enemy(1).get("drain") == true,
		"AC3 precondition: living source 1 is wounded and authors Drain")
	var deck := _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and reactions.is_guarding() and party.get_hero(1).block == 12
		and deck.energy == 2,
		"AC3 precondition: authentic paid Draw Fire guards with twelve Block")
	var rng_before: int = deck._rng.state
	var result: Dictionary = phase.execute_phase(party, enemies,
		[_attack(1, 18, 2)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 2, true, 1, true, 0)]},
		"AC3: the redirected Drain beat keeps the exact reaction event shape")
	_check(party.get_hero(1).hp == 34 and party.get_hero(1).block == 0
		and party.get_hero(2).hp == 30 and party.get_hero(3).hp == 26,
		"AC3: twelve Block absorbs twelve, so only the redirected Warden loses six HP")
	_check(enemies.get_enemy(1).hp == 10 and enemies.get_enemy(2).hp == 15,
		"AC3: Drain heals the redirected Warden's eight->six loss, not the announced slot")
	_check(deck._rng.state == rng_before and reactions.is_guarding()
		and reactions.get_thorns() == 0,
		"AC3: Drain draws no RNG and never consumes Guarding")

	# A redirected hit fully swallowed by the Warden's Block heals nothing.
	party = _party()
	enemies = _drain_enemies([12], [true])
	_check(enemies.apply_damage(1, 8) and enemies.get_enemy(1).hp == 4,
		"AC3 precondition: wounded Drain source for the blocked redirect")
	deck = _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	reactions = CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and party.get_hero(1).block == 12,
		"AC3 precondition: authentic paid guard with twelve Block")
	rng_before = deck._rng.state
	result = phase.execute_phase(party, enemies, [_attack(1, 10, 2)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 2, true, 1, true, 0)]}
		and party.get_hero(1).hp == 40 and party.get_hero(1).block == 2
		and party.get_hero(2).hp == 30,
		"AC3: a redirected hit fully absorbed by Block removes no HP")
	_check(enemies.get_enemy(1).hp == 4 and deck._rng.state == rng_before,
		"AC3: a fully blocked redirect heals no Drain and consumes no RNG")

	# Lethal Thorns retaliation during the same resolution: the source dies and
	# Drain must not resurrect it even though the hero really lost HP.
	party = _party()
	enemies = _drain_enemies([12], [true])
	_check(enemies.apply_damage(1, 8) and enemies.get_enemy(1).hp == 4,
		"AC3 precondition: Drain source will die to four Thorns")
	deck = _deck(["warden_counter_stitch_plus", "warden_draw_fire",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	reactions = CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_counter_stitch_plus")
		and reactions.get_thorns() == 4 and party.get_hero(1).block == 13,
		"AC3 precondition: authentic paid Counter-stitch+ authors Thorns 4 and 13 Block")
	rng_before = deck._rng.state
	result = phase.execute_phase(party, enemies, [_attack(1, 20, 1)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 1, true, 1, false, 4)]},
		"AC3: the lethal retaliation beat keeps its exact reaction event")
	_check(party.get_hero(1).hp == 33 and party.get_hero(1).block == 0,
		"AC3: the Warden really loses seven HP after her Block")
	_check(enemies.is_slain(1) and enemies.get_enemy(1).hp == 0
		and enemies.get_enemy(1).max_hp == 12,
		"AC3: Thorns-slain Drain source stays slain instead of healing back")
	_check(deck._rng.state == rng_before and reactions.get_thorns() == 4,
		"AC3: the lethal retaliation consumes no RNG and keeps its mode")

	# A surviving Thorns hit still heals the real HP the hero lost.
	party = _party()
	enemies = _drain_enemies([15], [true])
	_check(enemies.apply_damage(1, 6) and enemies.get_enemy(1).hp == 9,
		"AC3 precondition: Drain source survives four Thorns at nine HP")
	deck = _deck(["warden_counter_stitch_plus", "warden_draw_fire",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	reactions = CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_counter_stitch_plus")
		and reactions.get_thorns() == 4,
		"AC3 precondition: authentic paid Thorns 4")
	result = phase.execute_phase(party, enemies, [_attack(1, 20, 1)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 1, true, 1, false, 4)]}
		and party.get_hero(1).hp == 33,
		"AC3: the surviving retaliation beat applies its usual damage and Thorns")
	_check(enemies.get_enemy(1).hp == 12,
		"AC3: Drain heals the seven hero HP lost, after Thorns damage, once")

