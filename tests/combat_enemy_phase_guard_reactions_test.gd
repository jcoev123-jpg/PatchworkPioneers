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
	_test_guard_redirect_enrage_bonus()
	_test_skips_and_rollback()
	_test_dodge_direct_one_shot()
	_test_dodge_guard_redirect()
	_test_dodge_untouched_tokens()
	_test_dodge_invalid_and_replay()
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


func _enrage_enemies(definitions: Array) -> CombatEnemies:
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == definitions.size(),
		"precondition: real Enrage roster keeps its original source slots")
	return enemies


## AC2: a living Enrage source's stored +2-per-stack bonus lands exactly once,
## inside the base the existing status formula scales, while a genuine paid Guard
## redirect keeps its unchanged event contract, actual recipient and Thorns.
func _test_guard_redirect_enrage_bonus() -> void:
	# 5 announced + three stored stacks * 2 = 11, absorbed whole by Draw Fire's
	# twelve Block: exactly one bonus, and no Thorns was paid for.
	var party := _party()
	var enemies := _enrage_enemies([{"id": "patch-imp", "max_hp": 18,
		"enrage": true, "enrage_stacks": 3}])
	_check(enemies.get_enemy(1).get("enrage") == true
		and enemies.get_enemy(1).get("enrage_stacks") == 3,
		"AC2 precondition: the living source really stores three Enrage stacks")
	var deck := _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and reactions.is_guarding() and party.get_hero(1).block == 12,
		"AC2 precondition: authentic paid Draw Fire guards with twelve Block")
	var rng_before: int = deck._rng.state
	var source_record: Dictionary = enemies._enemies[0]
	var result: Dictionary = phase.execute_phase(party, enemies, [_attack(1, 5, 2)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 2, true, 1, true, 0)]},
		"AC2: the Enrage beat redirected by Guard keeps the exact reaction event")
	_check(party.get_hero(1).hp == 40 and party.get_hero(1).block == 1
		and party.get_hero(2).hp == 30,
		"AC2: the +6 bonus lands once, so twelve Block leaves exactly one Block")
	_check(enemies.get_enemy(1) == source_record and is_same(enemies._enemies[0], source_record),
		"AC2: the phase neither awards a stack nor rewrites the source record")
	_check(deck._rng.state == rng_before and reactions.is_guarding(),
		"AC2: the redirect consumes no RNG and keeps the Guarding mode")

	# A paid Counter-stitch keeps its unchanged Thorns retaliation on top.
	party = _party()
	enemies = _enrage_enemies([{"id": "patch-imp", "max_hp": 18,
		"enrage": true, "enrage_stacks": 2}])
	deck = _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	reactions = CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and reactions.play_from_hand(deck, party, "warden_counter_stitch")
		and party.get_hero(1).block == 17 and reactions.get_thorns() == 3,
		"AC2 precondition: authentic paid modes with 17 Block and Thorns 3")
	rng_before = deck._rng.state
	result = phase.execute_phase(party, enemies, [_attack(1, 5, 2)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 2, true, 1, true, 3)]},
		"AC2: the redirected Enrage beat keeps its unchanged retaliation receipt")
	_check(party.get_hero(1).hp == 40 and party.get_hero(1).block == 8
		and party.get_hero(2).hp == 30,
		"AC2: nine boosted damage is absorbed once by the seventeen Block")
	_check(enemies.get_enemy(1).hp == 15 and reactions.get_thorns() == 3
		and deck._rng.state == rng_before,
		"AC2: Thorns still retaliates exactly once and keeps its mode and RNG")

	# The bonus is part of the base the existing Exposed adjustment scales.
	party = _party()
	enemies = _enrage_enemies([{"id": "patch-imp", "max_hp": 18,
		"enrage": true, "enrage_stacks": 3}])
	deck = _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	reactions = CombatWardenGuardReactions.new()
	party._heroes[0]["statuses"] = {"exposed": 2}
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and party.get_hero(1).block == 12
		and party.get_hero(1).statuses == {"exposed": 2},
		"AC2 precondition: authentic twelve Block on a genuinely Exposed Warden")
	rng_before = deck._rng.state
	result = phase.execute_phase(party, enemies, [_attack(1, 5, 3)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 3, true, 1, true, 0)]},
		"AC2: an Exposed Guard redirect keeps the exact announced/actual receipt")
	# (5 + 3 * 2) * 3/2 = 16.5 -> 16 after twelve Block: four real HP lost.
	_check(party.get_hero(1).hp == 36 and party.get_hero(1).block == 0
		and party.get_hero(3).hp == 26,
		"AC2: the status adjustment scales the already-boosted base exactly once")
	_check(deck._rng.state == rng_before and enemies.get_enemy(1).hp == 18,
		"AC2: the Exposed redirect consumes no RNG and takes no Thorns")


## AC1/AC3: a living fixed-slot hero's armed one-shot Dodge makes exactly one
## legal incoming attack miss through the real no-Guard helper, spending that
## token and leaving HP, Block and unrelated statuses alone; the next hit lands
## through ordinary Block-before-HP. No token, zero damage and a malformed token
## keep their old contract.
func _test_dodge_direct_one_shot() -> void:
	var party := _party()
	party._heroes[1]["statuses"] = {"dodge_next_attack": 1, "bleed": 2}
	_check(party.gain_block(2, 4), "AC1 precondition: protected ally really has four Block")
	var seamstress: Dictionary = party._heroes[1]
	var warden_before: Dictionary = party.get_hero(1)
	var tinker_before: Dictionary = party.get_hero(3)
	var resolver := CombatEnemyAttacks.new()
	var result: Dictionary = resolver.execute_attacks(party,
		[_attack(1, 7, 2), _attack(2, 9, 2)])
	_check(result == {"ok": true, "events": [
		{"enemy_position": 1, "target_position": 2, "applied": false},
		{"enemy_position": 2, "target_position": 2, "applied": true}]},
		"AC1: the first fixed-slot hit misses on Dodge, the second hit lands")
	_check(party.get_hero(2)["statuses"] == {"bleed": 2},
		"AC1: the miss spends exactly one Dodge and keeps its unrelated Bleed")
	_check(party.get_hero(2)["hp"] == 25 and party.get_hero(2)["block"] == 0,
		"AC1: the miss keeps four Block, then the second hit absorbs it before HP")
	_check(party.get_hero(1) == warden_before and party.get_hero(3) == tinker_before,
		"AC1: no other hero's HP, Block or statuses change")
	_check(is_same(party._heroes[1], seamstress),
		"AC1: the spent token is erased from the authoritative hero record")

	# A legal zero-damage attempt still spends the armed one-shot token.
	party = _party()
	party._heroes[2]["statuses"] = {"dodge_next_attack": 1}
	result = resolver.execute_attacks(party, [_attack(1, 0, 3)])
	_check(result == {"ok": true, "events": [
		{"enemy_position": 1, "target_position": 3, "applied": false}]}
		and not party.get_hero(3)["statuses"].has("dodge_next_attack")
		and party.get_hero(3)["hp"] == 26 and party.get_hero(3)["block"] == 0,
		"AC3: a valid zero-damage attempt consumes the one-shot Dodge")
	result = resolver.execute_attacks(party, [_attack(1, 0, 3)])
	_check(result == {"ok": true, "events": [
		{"enemy_position": 1, "target_position": 3, "applied": true}]},
		"AC3: without a token the same zero-damage attempt applies as before")

	# A hero with no Dodge keeps the ordinary hit and its own statuses.
	var plain := _party()
	plain._heroes[1]["statuses"] = {"weak": 2}
	result = resolver.execute_attacks(plain, [_attack(1, 7, 2)])
	_check(result == {"ok": true, "events": [
		{"enemy_position": 1, "target_position": 2, "applied": true}]}
		and plain.get_hero(2)["hp"] == 23
		and plain.get_hero(2)["statuses"] == {"weak": 2},
		"AC3: a hero without a Dodge token takes the ordinary hit and keeps its statuses")

	# An empty status map is the same ordinary hit, with nothing invented.
	var empty := _party()
	empty._heroes[2]["statuses"] = {}
	result = resolver.execute_attacks(empty, [_attack(1, 3, 3)])
	_check(result == {"ok": true, "events": [
		{"enemy_position": 1, "target_position": 3, "applied": true}]}
		and empty.get_hero(3)["hp"] == 23 and empty.get_hero(3)["statuses"] == {},
		"AC3: an empty-status fixture takes the ordinary hit and stays empty")

	# A malformed token fails the whole batch before any hit lands.
	var bad_party := _party()
	bad_party._heroes[0]["statuses"] = {"dodge_next_attack": 2, "weak": 1}
	var bad_before: Array = bad_party.get_heroes()
	_check(resolver.execute_attacks(bad_party, [_attack(1, 5, 1), _attack(2, 5, 2)])
		== {"ok": false, "events": []} and bad_party.get_heroes() == bad_before,
		"AC3: a malformed Dodge token rejects the batch without collateral damage")


## AC2/AC3: with a real paid Guard redirect the one-shot Dodge belongs to the
## hero who actually takes the hit. A missed redirected beat is neither a Thorns
## trigger nor a Bleed/Drain hit, and a bypassed ally's token stays armed.
func _test_dodge_guard_redirect() -> void:
	var party := _party()
	var enemies := _drain_enemies([12, 15], [true, false])
	enemies._enemies[0]["bleed_on_attack"] = true
	_check(enemies.apply_damage(1, 8) and enemies.get_enemy(1).hp == 4
		and enemies.get_enemy(1).get("drain") == true
		and enemies.get_enemy(1).get("bleed_on_attack") == true,
		"AC2 precondition: living wounded source authors Drain and Bleed")
	var deck := _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and reactions.play_from_hand(deck, party, "warden_counter_stitch")
		and party.get_hero(1).block == 17 and reactions.is_guarding()
		and reactions.get_thorns() == 3 and deck.energy == 1,
		"AC2 precondition: authentic paid Guarding, Thorns 3 and 17 Block")
	party._heroes[0]["statuses"] = {"dodge_next_attack": 1}
	party._heroes[1]["statuses"] = {"dodge_next_attack": 1}
	var rng_before: int = deck._rng.state
	var source_one: Dictionary = enemies._enemies[0]
	var result: Dictionary = phase.execute_phase(party, enemies,
		[_attack(1, 18, 2), _attack(2, 6, 3)], reactions)
	_check(result == {"ok": true, "events": [
		_hit(1, 2, false, 1, true, 0),
		_hit(2, 3, true, 1, true, 3)]},
		"AC2: the redirected Dodge beat misses, the next redirect lands with Thorns")
	_check(party.get_hero(1)["statuses"] == {} and party.get_hero(1)["hp"] == 40
		and party.get_hero(1)["block"] == 11,
		"AC2: the real recipient spends her Dodge, takes no HP or Block loss to the miss, and no Bleed")
	_check(party.get_hero(2)["statuses"] == {"dodge_next_attack": 1}
		and party.get_hero(2)["hp"] == 30,
		"AC2: the bypassed announced ally never loses her armed Dodge")
	_check(enemies.get_enemy(1).hp == 4 and enemies.get_enemy(2).hp == 12
		and is_same(enemies._enemies[0], source_one),
		"AC2: a missed Drain/Bleed bite neither heals nor damages its source")
	_check(deck._rng.state == rng_before and reactions.is_guarding()
		and reactions.get_thorns() == 3,
		"AC2: the Dodge miss draws no RNG and consumes no reaction mode")

	# An unguarded ally who is the announced target dodges for herself.
	party = _party()
	party._heroes[2]["statuses"] = {"dodge_next_attack": 1}
	enemies = _drain_enemies([12], [true])
	_check(enemies.apply_damage(1, 4) and enemies.get_enemy(1).hp == 8,
		"AC2 precondition: wounded Drain source for the unguarded ally")
	deck = _deck(["warden_counter_stitch", "warden_draw_fire",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	reactions = CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_counter_stitch")
		and not reactions.is_guarding() and reactions.get_thorns() == 3,
		"AC2 precondition: paid Thorns without Guarding")
	rng_before = deck._rng.state
	result = phase.execute_phase(party, enemies, [_attack(1, 9, 3)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 3, false, 3, false, 0)]},
		"AC2: an unguarded Dodge-armed ally evades the enemy hit herself")
	_check(party.get_hero(3)["statuses"] == {} and party.get_hero(3)["hp"] == 26
		and enemies.get_enemy(1).hp == 8 and deck._rng.state == rng_before,
		"AC2: her own token is spent and no Thorns or Drain follows the miss")


## AC3/AC4: Guard moves the attempted hit away from the armed ally without
## spending her token, and skipped beats keep every token exactly as armed.
func _test_dodge_untouched_tokens() -> void:
	var party := _party()
	party._heroes[1]["statuses"] = {"dodge_next_attack": 1}
	var enemies := _enemies([12, 9])
	var deck := _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and reactions.is_guarding() and party.get_hero(1).block == 12,
		"AC3 precondition: authentic paid Guard with twelve Block")
	var result: Dictionary = phase.execute_phase(party, enemies, [_attack(1, 8, 2)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 2, true, 1, true, 0)]},
		"AC3: Guard redirects the hit away from the armed ally")
	_check(party.get_hero(2)["statuses"] == {"dodge_next_attack": 1}
		and party.get_hero(2)["hp"] == 30,
		"AC3: the bypassed ally's one-shot Dodge stays armed")
	_check(party.get_hero(1)["block"] == 4 and party.get_hero(1)["hp"] == 40,
		"AC3: the Warden takes the redirected hit normally (12 -> 4 Block)")

	# A slain source never resolves its beat, so an armed token is untouched.
	party = _party()
	party._heroes[1]["statuses"] = {"dodge_next_attack": 1}
	enemies = _enemies([5])
	_check(enemies.apply_damage(1, 5) and enemies.is_slain(1),
		"AC4 precondition: the attacking source is genuinely slain")
	reactions = CombatWardenGuardReactions.new()
	var before: Array = party.get_heroes()
	result = phase.execute_phase(party, enemies, [_attack(1, 12, 2)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 2, false, 2, false, 0)]}
		and party.get_heroes() == before,
		"AC4: a slain source's skipped attack cannot spend the armed Dodge")

	# A downed recipient's beat is skipped with her token intact.
	party = _party()
	party._heroes[2]["statuses"] = {"dodge_next_attack": 1}
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"AC4 precondition: the armed Tinker is genuinely downed")
	enemies = _enemies([9])
	before = party.get_heroes()
	result = phase.execute_phase(party, enemies, [_attack(1, 9, 3)], reactions)
	_check(result == {"ok": true, "events": [_hit(1, 3, false, 3, false, 0)]}
		and party.get_heroes() == before,
		"AC4: a downed recipient's skipped attack keeps her Dodge armed")
	_check(CombatEnemyAttacks.new().execute_attacks(party, [_attack(1, 4, 3)]) ==
		{"ok": true, "events": [
			{"enemy_position": 1, "target_position": 3, "applied": false}]}
		and party.get_hero(3)["statuses"] == {"dodge_next_attack": 1},
		"AC4: the direct helper also skips a downed recipient without spending Dodge")


## AC3/AC6: invalid late input spends nothing, and the identical seed replays
## the exact same ordered miss/landing trace with untouched RNG.
func _test_dodge_invalid_and_replay() -> void:
	# A malformed later attack leaves an earlier armed Dodge unspent.
	var direct_party := _party()
	direct_party._heroes[1]["statuses"] = {"dodge_next_attack": 1}
	var direct_before: Array = direct_party.get_heroes()
	_check(CombatEnemyAttacks.new().execute_attacks(direct_party,
		[_attack(1, 5, 2), _attack(1, 3, 2)]) == {"ok": false, "events": []}
		and direct_party.get_heroes() == direct_before,
		"AC3: a duplicate late source rejects before the legal Dodge miss is spent")

	var party := _party()
	party._heroes[1]["statuses"] = {"dodge_next_attack": 1}
	var enemies := _enemies([12, 9])
	var deck := _deck(["warden_draw_fire", "warden_counter_stitch",
		"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(deck, party, "warden_draw_fire")
		and reactions.is_guarding(),
		"AC3 precondition: authentic paid Guard before the invalid batch")
	var before: Array = [party.get_heroes(), enemies.get_enemies(), deck._rng.state,
		deck.hand.duplicate(), deck.energy, reactions.is_guarding(), reactions.get_thorns()]
	var rejected: Dictionary = phase.execute_phase(party, enemies,
		[_attack(1, 8, 2), _attack(2, 4, 4)], reactions)
	_check(rejected == {"ok": false, "events": []}
		and [party.get_heroes(), enemies.get_enemies(), deck._rng.state,
			deck.hand, deck.energy, reactions.is_guarding(), reactions.get_thorns()] == before
		and party.get_hero(2)["statuses"] == {"dodge_next_attack": 1},
		"AC3: a malformed late attack rejects atomically and never spends Dodge")

	var traces: Array = []
	for repetition: int in range(2):
		var replay_party := _party()
		replay_party._heroes[0]["statuses"] = {"dodge_next_attack": 1}
		var replay_enemies := _enemies([12, 9])
		var replay_deck := _deck(["warden_draw_fire", "warden_counter_stitch",
			"warden_iron_hem", "warden_hold_the_line", "warden_quick_darn"])
		var replay_reactions := CombatWardenGuardReactions.new()
		_check(replay_reactions.play_from_hand(replay_deck, replay_party, "warden_draw_fire"),
			"AC6 precondition: identical seeded Guard fixture")
		var replay_rng: int = replay_deck._rng.state
		var replay_result: Dictionary = phase.execute_phase(replay_party, replay_enemies,
			[_attack(1, 8, 2), _attack(2, 6, 3)], replay_reactions)
		traces.append([replay_result, replay_party.get_heroes(), replay_enemies.get_enemies(),
			replay_deck._rng.state, replay_rng])
	_check(traces.size() == 2 and traces[0] == traces[1]
		and traces[0][0] == {"ok": true, "events": [
			_hit(1, 2, false, 1, true, 0), _hit(2, 3, true, 1, true, 0)]}
		and traces[0][4] == traces[0][3],
		"AC6: identical seed replays the same Dodge miss and landing hit, RNG untouched")


