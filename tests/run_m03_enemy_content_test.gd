extends SceneTree

const BOSS_PATH := "res://data/encounters/patchwork_behemoth.json"
const EXPECTED := [
	{"type": "attack", "amount": 2, "target_position": 1},
	{"type": "block", "amount": 3},
	{"type": "attack", "amount": 2, "target_position": 3},
	{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
	{"type": "attack", "amount": 2, "target_position": 2},
]
var failures: Array[String] = []
var checks := 0
var catalog: Array = []


func _initialize() -> void:
	_test_catalogs()
	_test_cycle()
	_test_typed_boss_defeat()
	_test_inert_and_invalid()
	_test_earlier_encounter()
	for failure in failures:
		printerr(failure)
	print("run_m03_enemy_content_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_records(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Array and not parsed.is_empty(), "nonempty authored array: " + path)
	if not parsed is Array:
		return []
	for record in parsed:
		if record is Dictionary:
			_check(RunFightEncounterSelection._coerce_integral_field(record, "max_hp"), "integral authored HP")
	return parsed


func _record(id: String) -> Dictionary:
	var matches: Array = catalog.filter(func(entry: Dictionary) -> bool: return entry.get("id") == id)
	_check(matches.size() == 1, "exactly one catalog record: " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _boss() -> CombatEnemies:
	var enemies := CombatEnemies.new([_record("patchwork_behemoth")])
	_check(enemies.is_valid(), "authored boss is a valid roster")
	return enemies


func _party() -> CombatParty:
	var records := _load_records("res://data/heroes/starter_party.json")
	var ordered: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matches: Array = records.filter(func(entry: Dictionary) -> bool: return entry.get("id") == id)
		_check(matches.size() == 1, "unique authored hero " + id)
		if matches.size() == 1:
			ordered.append(matches[0])
	var party := CombatParty.new(ordered)
	_check(party.is_valid(), "valid three-hero fixture")
	return party


func _schedule() -> Array:
	var result := RunFightEncounterSelection._parse_schedule_text(FileAccess.get_file_as_string(BOSS_PATH))
	_check(result == [{"enemy_position": 1, "pattern": EXPECTED}], "on-disk single-source exact boss cycle")
	return result


func _rng_start() -> int:
	seed(58003)
	var expected := randi()
	seed(58003)
	return expected


func _test_catalogs() -> void:
	var required_by_path := {
		"starter_enemies": ["ragling", "ragling_guard"],
		"run_enemies": ["fray_scavenger", "button_guard", "spool_stalker", "seam_ripper"],
		"boss": ["patchwork_behemoth"],
	}
	for path in ["starter_enemies", "run_enemies", "boss"]:
		var records := _load_records("res://data/enemies/" + path + ".json")
		for id in required_by_path[path]:
			_check(records.filter(func(entry: Dictionary) -> bool: return entry.get("id") == id).size() == 1,
				"required ID appears exactly once in its authored file: " + id)
		catalog.append_array(records)
	var before := catalog.duplicate(true)
	var ids: Array = []
	var names: Array = []
	for entry in catalog:
		_check(entry.get("id") is String and not entry.id.is_empty() and entry.id not in ids, "unique nonempty enemy ID")
		_check(entry.get("name") is String and not entry.name.is_empty() and entry.name not in names, "unique readable enemy name")
		ids.append(entry.get("id"))
		names.append(entry.get("name"))
	var required := {
		"ragling": ["Ragling", 12], "ragling_guard": ["Guard Ragling", 12],
		"fray_scavenger": ["Fray Scavenger", 14], "button_guard": ["Button Guard", 16],
		"spool_stalker": ["Spool Stalker", 14], "seam_ripper": ["Seam Ripper", 18],
		"patchwork_behemoth": ["Patchwork Behemoth", 42],
	}
	for id in required:
		var entry := _record(id)
		_check(entry.get("name") == required[id][0] and entry.get("max_hp") == required[id][1]
			and entry.get("max_hp") is int, "authored identity and integer HP: " + id)
		var rng_expected := _rng_start()
		var first := CombatEnemies.new([entry])
		var second := CombatEnemies.new([entry])
		_check(first.is_valid() and second.is_valid(), "construct independent rosters: " + id)
		var original := first.get_enemies()
		var copy := first.get_enemies()
		copy[0].hp = 0
		entry.max_hp = 999
		_check(first.get_enemies() == original and second.get_enemies() == original, "constructor/read snapshot isolation: " + id)
		_check(first.apply_damage(1, 1), "first instance takes damage")
		_check(second.get_enemies() == original, "other instance unaffected")
		_check(randi() == rng_expected, "construction and reads use no RNG")
	_check(catalog == before, "complete old/new catalogs remain unchanged")


func _test_cycle() -> void:
	var history: Array = []
	for replay in range(2):
		var party := _party()
		var enemies := _boss()
		var definitions := _schedule()
		var scheduler := CombatEnemyIntents.new(definitions)
		_check(scheduler.is_valid(), "boss scheduler validates")
		definitions[0].pattern[0].amount = 999
		var expected_heroes := party.get_heroes()
		var expected_enemies := enemies.get_enemies()
		var observed: Array = []
		var rng_expected := _rng_start()
		for step in range(10):
			var expected: Dictionary = EXPECTED[step % 5].duplicate(true)
			expected.enemy_position = 1
			var announced := scheduler.get_intents()
			_check(announced == [expected], "exact announcement at step %d" % step)
			var copy := scheduler.get_intents()
			copy[0].amount = 999
			_check(scheduler.get_intents() == announced, "announcement isolation")
			var result := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
			var event := expected.duplicate(true)
			event.erase("amount")
			event.applied = true
			_check(result == {"ok": true, "events": [event]}, "exact ordered phase event at step %d" % step)
			match step % 5:
				0: expected_heroes[0].hp -= 2
				1: expected_enemies[0].block += 3
				2: expected_heroes[2].hp -= 2
				3: expected_heroes[1]["statuses"] = {"weak": int(step / 5) + 1}
				4: expected_heroes[1].hp -= 2
			_check(party.get_heroes() == expected_heroes, "complete expected party transition at step %d" % step)
			_check(enemies.get_enemies() == expected_enemies, "complete expected boss transition at step %d" % step)
			_check(scheduler.get_intents() == announced, "executor does not advance timeline")
			observed.append([announced, result, party.get_heroes(), enemies.get_enemies()])
			_check(scheduler.advance_turn(), "advance one beat")
		_check(randi() == rng_expected, "entire boss timeline consumes no RNG")
		var opening: Dictionary = EXPECTED[0].duplicate(true)
		opening.enemy_position = 1
		_check(scheduler.get_intents() == [opening], "exact wraparound after ten steps")
		if replay == 0:
			history = observed
		else:
			_check(observed == history, "independent deterministic ten-step replay")


func _battle_snapshot(party: CombatParty, enemies: CombatEnemies, deck: CombatDeck,
		intents: CombatEnemyIntents, flow: CombatRoundFlow, rng: RandomNumberGenerator) -> Dictionary:
	return {"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"turn_active": deck.turn_active, "intents": intents.get_intents(),
		"turn_index": intents._turn_index, "outcome": flow.get_outcome(), "rng": rng.state}


func _play_typed_boss() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 83003
	var map := RunMap.new()
	map.generate(rng)
	for floor_index in range(12):
		var legal := map.get_legal_choices()
		_check(not legal.is_empty(), "Boss route has a legal next floor")
		if legal.is_empty():
			return {}
		_check(map.choose_node(legal[0]), "public map choice commits floor %d" % (floor_index + 1))
	_check(map.get_current_floor() == 12 and map.get_node(map.get_current_node_id()).get("type") == "Boss",
		"real seeded map reaches the typed floor-12 Boss")
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
	_check(entry.get("success") == true and entry.get("node_type") == "Boss"
		and entry.get("encounter_id") == "patchwork_behemoth", "public typed entry selects the shipped Boss")
	if not entry.get("success", false):
		return {}
	var enemies: CombatEnemies = entry.enemies
	var intents: CombatEnemyIntents = entry.intents
	_check(enemies.is_valid() and intents.is_valid() and entry.definitions == _schedule(),
		"typed entry provides real valid actors and exact five-beat schedule")
	var party := _party()
	var initial := party.get_heroes()
	for index in range(3):
		_check(initial[index].hp == [40, 30, 26][index] and initial[index].hp == initial[index].max_hp
			and initial[index].block == 0, "authored hero starts at unmodified full HP")
	var cards: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	_check(cards is Array and cards.size() >= CombatDeck.TURN_DRAW, "real authored starter deck can deal a hand")
	if not cards is Array or cards.size() < CombatDeck.TURN_DRAW:
		return {}
	var card_ids: Array[String] = []
	card_ids.assign(cards)
	var deck := CombatDeck.new(card_ids, rng)
	var result := CombatBattleResult.new(party, enemies)
	var flow := CombatRoundFlow.new(deck, party, enemies, intents, result)
	_check(flow.begin_fight(), "real seeded deck/round flow begins Boss fight")
	_check(party.get_hero(1).block == 6 and deck.hand.size() == CombatDeck.TURN_DRAW
		and deck.turn_active and result.can_continue(), "opening hand and one-shot Warden Block are live")
	var trace: Array = [_battle_snapshot(party, enemies, deck, intents, flow, rng)]
	var turns := 0
	var skipped_downed_weak := false
	while result.can_continue() and turns < 160:
		var announced := intents.get_intents()
		var before := party.get_heroes()
		var expected_hp: Array = [before[0].hp, before[1].hp, before[2].hp]
		var action: Dictionary = announced[0]
		if action.type == "attack":
			var index: int = action.target_position - 1
			expected_hp[index] = maxi(0, expected_hp[index] - maxi(0, 2 - int(before[index].block)))
		var downed_weak: bool = action.type == "debuff" and party.is_downed(2)
		_check(deck.turn_active and deck.energy == CombatState.TURN_ENERGY
			and deck.hand.size() == CombatDeck.TURN_DRAW, "no-card turn retains full energy and real dealt hand")
		var ended := flow.end_turn()
		_check(ended, "legal no-card End Turn succeeds at turn %d" % (turns + 1))
		if not ended:
			break
		turns += 1
		for index in range(3):
			_check(party.get_hero(index + 1).hp == expected_hp[index],
				"only announced attack changes HP at turn %d slot %d" % [turns, index + 1])
		_check(enemies.get_enemy(1).hp == 42, "no-card run never damages the Boss")
		if downed_weak:
			skipped_downed_weak = true
			_check(party.get_hero(2).hp == 0 and party.get_hero(2).get("statuses", {}) == {},
				"Weak on an already downed middle hero is inert without stalling the round")
		trace.append(_battle_snapshot(party, enemies, deck, intents, flow, rng))
	_check(turns == 101 and turns <= 160 and skipped_downed_weak,
		"authored full-HP party naturally falls in 101 End Turns, including downed Weak beats")
	_check(party.is_defeated() and party.is_downed(1) and party.is_downed(2) and party.is_downed(3)
		and flow.get_outcome() == CombatBattleResult.DEFEAT and result.is_finished()
		and not result.can_continue(), "authoritative result latches party DEFEAT")
	_check(not deck.turn_active and deck.hand.is_empty() and deck.energy == 0
		and intents._turn_index == turns - 1, "lethal End Turn closes hand without advancing or dealing another turn")
	var terminal := _battle_snapshot(party, enemies, deck, intents, flow, rng)
	for attempt in range(2):
		_check(not flow.end_turn() and not flow.begin_fight(), "terminal flow rejects continuation and restart")
		_check(flow.observe_result() == CombatBattleResult.DEFEAT
			and _battle_snapshot(party, enemies, deck, intents, flow, rng) == terminal,
			"terminal calls preserve all actors, deck piles, energy, scheduler, outcome and RNG")
	return {"trace": trace, "floors": map.get_floors(), "route": map.get_route(), "rng": rng.state}


func _test_typed_boss_defeat() -> void:
	var expected_global := _rng_start()
	var first := _play_typed_boss()
	_check(randi() == expected_global, "entire typed Boss no-card run uses no global RNG")
	expected_global = _rng_start()
	var second := _play_typed_boss()
	_check(randi() == expected_global, "fresh Boss replay uses no global RNG")
	_check(not first.is_empty() and first.get("trace", []).size() == 102
		and second == first, "fresh seeded run repeats every authoritative turn, deck and RNG state")


func _assert_phase_unchanged(party: CombatParty, enemies: CombatEnemies, actions: Array, expected: Dictionary) -> void:
	var heroes_before := party.get_heroes()
	var enemies_before := enemies.get_enemies()
	var input_before := actions.duplicate(true)
	var rng_expected := _rng_start()
	_check(CombatEnemyPhase.new().execute_phase(party, enemies, actions) == expected, "inert/rejected phase result")
	_check(party.get_heroes() == heroes_before and enemies.get_enemies() == enemies_before, "entire authoritative actors unchanged")
	_check(actions == input_before, "caller actions unchanged")
	_check(randi() == rng_expected, "inert/rejected phase consumes no RNG")


func _test_inert_and_invalid() -> void:
	var party := _party()
	var boss := _boss()
	var heroes_before := party.get_heroes()
	var valid_before := boss.get_enemies()
	# Verify the global-stream sentinel detects a deliberately injected draw.
	var sentinel := _rng_start()
	randi()
	_check(randi() != sentinel, "RNG sentinel detects an extra global draw")
	for bad in [{"id": "", "max_hp": 42}, {"id": 7, "max_hp": 42},
		{"id": "bad", "max_hp": 0}, {"id": "bad", "max_hp": 42.5},
		{"name": "missing ID", "max_hp": 42}]:
		var input: Array = [_record("patchwork_behemoth"), bad]
		var before := input.duplicate(true)
		var rng_expected := _rng_start()
		var invalid := CombatEnemies.new(input)
		_check(not invalid.is_valid() and invalid.get_enemies().is_empty(), "invalid enemy definition rejected atomically")
		_check(input == before and boss.get_enemies() == valid_before, "invalid construction leaves inputs/actors unchanged")
		_check(randi() == rng_expected, "invalid enemy construction consumes no RNG")
	var duplicate := [_record("patchwork_behemoth"), _record("patchwork_behemoth")]
	var rng_expected := _rng_start()
	var invalid := CombatEnemies.new(duplicate)
	_check(not invalid.is_valid() and invalid.get_enemies().is_empty(), "duplicate enemy IDs rejected")
	_check(randi() == rng_expected, "duplicate enemy IDs consume no RNG")
	_check(duplicate == [_record("patchwork_behemoth"), _record("patchwork_behemoth")]
		and party.get_heroes() == heroes_before and boss.get_enemies() == valid_before,
		"duplicate rejection preserves definitions and all surviving actors")
	_assert_phase_unchanged(party, invalid, [], {"ok": false, "events": []})
	for text in ["{", "{}", "[]",
		'[{"enemy_position":1.5,"pattern":[{"type":"block","amount":3}]}]',
		JSON.stringify(_schedule() + _schedule())]:
		rng_expected = _rng_start()
		_check(RunFightEncounterSelection._parse_schedule_text(text).is_empty(), "invalid source schedule rejected")
		_check(randi() == rng_expected and party.get_heroes() == heroes_before
			and boss.get_enemies() == valid_before, "source schedule rejection preserves actors/RNG")
	for bad_action in [
		{"type": "attack", "amount": 2.5, "target_position": 1},
		{"type": "block", "amount": -1}, {"type": "block", "amount": "3"},
		{"type": "attack", "amount": 2, "target_position": 1.5},
		{"type": "attack", "amount": 2, "target_position": 0},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "invented"},
		{"type": "debuff", "amount": 0, "target_position": 2, "status": "weak"},
		{"type": "block", "amount": 3, "target_position": 1},
		{"type": "unknown", "amount": 2}, {"type": "attack", "target_position": 1},
	]:
		var schedule := _schedule()
		schedule[0].pattern.append(bad_action)
		var before := schedule.duplicate(true)
		rng_expected = _rng_start()
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(schedule)).is_empty(), "malformed/fractional JSON schedule rejected")
		var rejected := CombatEnemyIntents.new(schedule)
		_check(not rejected.is_valid() and rejected.get_intents().is_empty() and not rejected.advance_turn(), "invalid scheduler inert")
		_check(schedule == before and randi() == rng_expected, "rejected schedule unchanged and no RNG spent")
		var malformed: Dictionary = bad_action.duplicate(true)
		malformed.enemy_position = 1
		_assert_phase_unchanged(party, boss, [malformed], {"ok": false, "events": []})
		# A valid staged Block must also roll back when a later source is malformed.
		var pair := CombatEnemies.new([_record("patchwork_behemoth"), _record("ragling")])
		malformed.enemy_position = 2
		_assert_phase_unchanged(party, pair, [{"enemy_position": 1, "type": "block", "amount": 3}, malformed], {"ok": false, "events": []})
	_check(boss.apply_damage(1, 42) and boss.is_slain(1), "real authored boss slain")
	for action in EXPECTED:
		var announced: Dictionary = action.duplicate(true)
		announced.enemy_position = 1
		var event := announced.duplicate(true)
		event.erase("amount")
		event.applied = false
		_assert_phase_unchanged(party, boss, [announced], {"ok": true, "events": [event]})
	for beat in [0, 2, 3, 4]:
		var downed_party := _party()
		var action: Dictionary = EXPECTED[beat].duplicate(true)
		var target: int = action.target_position
		_check(downed_party.apply_damage(target, 100) and downed_party.is_downed(target), "target actually downed")
		action.enemy_position = 1
		var result := {"ok": false, "events": []}
		if action.type == "attack":
			result = {"ok": true, "events": [{"type": "attack", "enemy_position": 1, "target_position": target, "applied": false}]}
		_assert_phase_unchanged(downed_party, _boss(), [action], result)


func _test_earlier_encounter() -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(FileAccess.get_file_as_string("res://data/encounters/bobbin_skirmish.json"))
	var expected := [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 2}, {"type": "block", "amount": 1}, {"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 1, "target_position": 1}, {"type": "block", "amount": 1}]},
	]
	_check(definitions == expected, "Bobbin Skirmish complete ordered source cycles preserved")
	_check(CombatEnemyIntents.new(definitions).is_valid(), "Bobbin Skirmish still validates")
	_check(CombatEnemies.new([_record("ragling"), _record("ragling_guard")]).is_valid(), "both named earlier Raglings still validate")
