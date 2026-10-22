extends SceneTree

## Deterministic headless coverage for the authored Hemhook Exposed Swap
## encounter (published in the real production M04 Fight pool):
##   enemy_position 1 (Spool Stalker): beat 1 shove, beat 2 Block 2, beat 3 attack 3.
##   enemy_position 2 (Seam Ripper): beat 1 Exposed 1, beat 2 attack 4, beat 3 self-Block 2.
##   enemy_position 3 (Fray Scavenger): beat 1 attack 4, beat 2 attack 3, beat 3 attack 4.
## Beat 1 swaps the front Warden (1) with the middle Seamstress (2) BEFORE the
## Exposed debuff lands, so the Seamstress - not the Warden - carries Exposed 1
## and eats floor(4 * 1.5) = 6 damage while the Warden keeps his opening 6 Block.
## The source/phase fixture complements real routed production entry coverage.

const ENCOUNTER_PATH := "res://data/encounters/hemhook_exposed_swap.json"
const ENCOUNTER_ID := "hemhook_exposed_swap"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const TYPED_POOLS_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const FIXED_SEED := 20261022

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_ac1_authored_schedule_and_intents()
	_test_ac2_first_phase_with_typed_roster()
	_test_ac3_slain_source_and_torn_target()
	if failures.is_empty():
		print("hemhook_exposed_swap_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("hemhook_exposed_swap_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "file must open: " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _normalize(data: Variant) -> Variant:
	if data is Array:
		var result: Array = []
		for item in data:
			result.append(_normalize(item))
		return result
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			result[key] = _normalize(data[key])
		return result
	if data is float and is_finite(data) and floorf(data) == data:
		return int(data)
	return data


func _load_catalog(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		_check(false, "catalog must be a JSON Array: " + path)
		return []
	return _normalize(parsed)


## Exactly one record with this id: a first-match lookup would hide duplicates.
func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "catalog holds exactly one record named " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


## The authored prescription, copied verbatim from the brief.
func _expected_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
				{"type": "block", "amount": 2},
				{"type": "attack", "amount": 3, "target_position": 1}
			]
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
				{"type": "attack", "amount": 4, "target_position": 2},
				{"type": "buff", "amount": 2}
			]
		},
		{
			"enemy_position": 3,
			"pattern": [
				{"type": "attack", "amount": 4, "target_position": 1},
				{"type": "attack", "amount": 3, "target_position": 3},
				{"type": "attack", "amount": 4, "target_position": 2}
			]
		}
	]


func _expected_beat(beat_index: int) -> Array:
	var actions: Array = []
	for definition in _expected_definitions():
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat_index % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


func _expected_events(beat_index: int) -> Array:
	var events: Array = []
	for intent in _expected_beat(beat_index):
		var event := {
			"type": intent["type"],
			"enemy_position": intent["enemy_position"],
			"applied": true
		}
		for field in ["target_position", "status", "direction"]:
			if intent.has(field):
				event[field] = intent[field]
		events.append(event)
	return events


## The three shipped heroes in their shipped slots, with the real opening Block.
func _build_party() -> CombatParty:
	var heroes := _load_catalog(HERO_CATALOG_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "the three shipped heroes build a valid CombatParty")
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "the real opening Block service grants the Warden 6 Block")
	return party


## A focused typed Fight selection through the production selector and the
## roster bridge; the full shipped pool is exercised separately by the
## published-pressure Fight regression.
func _typed_choice() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXED_SEED
	var map := RunMap.new()
	_check(map.generate(rng), "the seeded run map generates")
	var fight_id := ""
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			fight_id = node_id
			break
	_check(not fight_id.is_empty(), "the seeded map offers a legal Fight node")
	_check(map.choose_node(fight_id), "the legal Fight node is chosen")
	_check(map.get_current_node_id() == fight_id
		and map.get_node(fight_id).get("type") == "Fight",
		"the current route node is the chosen Fight")
	var choice := RunFightEncounterSelection.new().select_current_battle(map, rng, {
		"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}})
	_check(choice.get("success", false), "the test-local Fight pool selects the authored encounter")
	_check(choice.get("node_type") == "Fight", "the selection reports a Fight node")
	_check(choice.get("encounter_id") == ENCOUNTER_ID,
		"the selection is the hemhook_exposed_swap encounter")
	_check(choice.get("definitions", []) == _expected_definitions(),
		"the selection returns the exact authored schedule")
	return choice


func _assemble(choice: Dictionary) -> Dictionary:
	return RunTypedBattleRoster.new().assemble(
		choice,
		{ENCOUNTER_ID: ["spool_stalker", "seam_ripper", "fray_scavenger"]},
		[ENEMY_CATALOG_PATH]
	)


## AC1: the authored JSON holds exactly the three prescribed sources, the
## production parser accepts it, the intent service validates it and announces
## beats 1, 2, 3 and then beat 1 again.
func _test_ac1_authored_schedule_and_intents() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "the authored schedule file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID " + ENCOUNTER_ID)
	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw_json: Variant = JSON.parse_string(raw_text)
	_check(raw_json is Array, "the authored file is a top-level JSON array with no extra root keys")
	_check(raw_json is Array and raw_json.size() == 3,
		"the authored file holds exactly this encounter's three source records")
	for record in raw_json:
		_check(record is Dictionary and record.size() == 2
			and record.has("enemy_position") and record.has("pattern"),
			"every source record carries only enemy_position and pattern")
		_check(record.get("pattern") is Array and record["pattern"].size() == 3,
			"every source record repeats exactly three beats")

	var loaded := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(loaded == _expected_definitions(),
		"the production parser returns exactly the prescribed three-source schedule")
	_check(loaded.size() == 3, "the parsed schedule holds exactly three sources")
	for position in [1, 2, 3]:
		var matches: Array = []
		for definition in loaded:
			if definition.get("enemy_position") == position:
				matches.append(definition)
		_check(matches.size() == 1, "exactly one parsed source at enemy_position %d" % position)
		if matches.size() == 1:
			_check(matches[0]["pattern"] == _expected_definitions()[position - 1]["pattern"],
				"source %d holds the exact authored beat records" % position)
	for definition in loaded:
		_check(definition.get("enemy_position") is int,
			"the parsed enemy_position is an int, not a JSON float")
		for action in definition["pattern"]:
			_check(action.get("amount") is int, "the parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"the parsed beat target_position is an int, not a JSON float")
			if action.has("direction"):
				_check(action.get("direction") is int,
					"the parsed beat direction is an int, not a JSON float")

	var intents := CombatEnemyIntents.new(loaded)
	_check(intents.is_valid(), "CombatEnemyIntents validates the authored schedule")
	_check(intents.get_intents() == _expected_beat(0),
		"beat 1 announces the exact three actions in slot order")
	_check(intents.advance_turn(), "advance to beat 2")
	_check(intents.get_intents() == _expected_beat(1),
		"beat 2 announces the exact three actions in slot order")
	_check(intents.advance_turn(), "advance to beat 3")
	_check(intents.get_intents() == _expected_beat(2),
		"beat 3 announces the exact three actions in slot order")
	_check(intents.advance_turn(), "advance to beat 4")
	_check(intents.get_intents() == _expected_beat(0), "beat 4 repeats beat 1 exactly")

	# Require the exact production binding, not merely a test-local choice.
	var pools: Variant = JSON.parse_string(_read_text(TYPED_POOLS_PATH))
	_check(pools is Dictionary and pools.get("Fight") is Dictionary,
		"the shipped typed battle pool parses with a Fight pool")
	if pools is Dictionary and pools.get("Fight") is Dictionary:
		_check(pools["Fight"].get(ENCOUNTER_ID) == {
			"schedule": ENCOUNTER_PATH,
			"enemy_ids": ["spool_stalker", "seam_ripper", "fray_scavenger"]},
			"Hemhook has the exact production Fight schedule and ordered roster")


## AC2: the real first enemy phase over the shipped heroes and the shipped
## enemies, driven by the typed roster this encounter assembles.
func _test_ac2_first_phase_with_typed_roster() -> void:
	var choice := _typed_choice()
	if not choice.get("success", false):
		return
	var assembled := _assemble(choice)
	_check(assembled.get("ok") == true,
		"RunTypedBattleRoster.assemble binds the local encounter to the shipped enemy catalog")
	if not assembled.get("ok", false):
		return
	_check(assembled.get("node_type") == "Fight", "the assembled roster keeps the Fight node type")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID,
		"the assembled roster keeps the authored encounter ID")
	_check(assembled.get("definitions") == _expected_definitions(),
		"the assembled roster keeps the exact authored definitions")
	var enemies: CombatEnemies = assembled.get("enemies")
	_check(enemies != null and enemies.is_valid(),
		"the assembled roster is a valid CombatEnemies")
	if enemies == null or not enemies.is_valid():
		return
	var roster := _load_catalog(ENEMY_CATALOG_PATH)
	for slot in [[1, "spool_stalker", 14], [2, "seam_ripper", 18], [3, "fray_scavenger", 14]]:
		var position: int = slot[0]
		var id: String = slot[1]
		var hp: int = slot[2]
		var record := _record_by_id(roster, id)
		var enemy := enemies.get_enemy(position)
		_check(enemy.get("id") == id and enemy.get("position") == position
			and enemy.get("max_hp") == hp and enemy.get("hp") == hp
			and enemy.get("block") == 0,
			"assembled slot %d is the shipped %s with %d HP" % [position, id, hp])
		_check(enemy.get("name") == record.get("name")
			and enemy.get("art_path") == record.get("art_path"),
			"assembled slot %d keeps the shipped name and art path" % position)

	var party := _build_party()
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 6,
		"the Warden starts at hero position 1 with 40 HP and 6 opening Block")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0,
		"the Seamstress starts at hero position 2 with 30 HP")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0,
		"the Tinker starts at hero position 3 with 26 HP")

	var intents := CombatEnemyIntents.new(assembled["definitions"])
	_check(intents.is_valid(), "the assembled schedule drives real cyclic intents")
	var announced := intents.get_intents()
	_check(announced == _expected_beat(0), "the first announced beat is the authored beat 1")

	seed(FIXED_SEED)
	var rng_before := randi()
	seed(FIXED_SEED)
	var result := phase.execute_phase(party, enemies, announced)
	_check(randi() == rng_before, "the enemy phase draws no global RNG")
	_check(result == {"ok": true, "events": _expected_events(0)},
		"beat 1 succeeds with the shove, the Exposed debuff and the 4 attack, in source order")

	var heroes := party.get_heroes()
	_check(heroes[0].get("id") == "seamstress" and heroes[0].get("position") == 1,
		"the swapped Seamstress now occupies hero position 1")
	_check(heroes[1].get("id") == "warden" and heroes[1].get("position") == 2,
		"the swapped Warden now occupies hero position 2")
	_check(heroes[2].get("id") == "tinker" and heroes[2].get("position") == 3,
		"the Tinker keeps hero position 3")
	_check(heroes[0].get("hp") == 24 and heroes[0].get("block") == 0,
		"the front Seamstress took floor(4 * 1.5) = 6 damage (30 to 24)")
	_check(heroes[0].get("statuses", {}).get("exposed", 0) == 1,
		"the front Seamstress carries Exposed 1")
	_check(heroes[1].get("hp") == 40 and heroes[1].get("block") == 6,
		"the middle Warden keeps 40 HP and his 6 opening Block")
	_check(heroes[1].get("statuses", {}).get("exposed", 0) == 0,
		"the Warden carries no Exposed 1")
	_check(heroes[2].get("hp") == 26 and heroes[2].get("block") == 0,
		"the rear Tinker is untouched at 26 HP")
	var seamstress := _record_by_id(_load_catalog(HERO_CATALOG_PATH), "seamstress")
	_check(heroes[0].get("name") == seamstress.get("name")
		and heroes[0].get("max_hp") == seamstress.get("max_hp")
		and heroes[0].get("art_path") == seamstress.get("art_path"),
		"the swapped hero keeps every unrelated shipped record field")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("hp") == 18 and enemies.get_enemy(2).get("block") == 0
		and enemies.get_enemy(3).get("hp") == 14 and enemies.get_enemy(3).get("block") == 0,
		"beat 1 leaves every enemy at full HP with 0 Block")


## AC3: a slain Spool Stalker skips only its own shove, and a torn Warden at
## slot 1 makes the beat-1 shove fail the whole phase closed.
func _test_ac3_slain_source_and_torn_target() -> void:
	var choice := _typed_choice()
	if not choice.get("success", false):
		return

	# Alternative first beat: the Spool Stalker dies before the phase, so
	# the Warden keeps hero position 1 and eats the adjusted 6 into his Block.
	var assembled := _assemble(choice)
	_check(assembled.get("ok", true),
		"the slain-source fixture assembles its typed roster")
	if not assembled.get("ok", false):
		return
	var enemies: CombatEnemies = assembled.get("enemies")
	var party := _build_party()
	_check(enemies.apply_damage(1, 14) and enemies.is_slain(1),
		"the Spool Stalker is slain before the first beat")
	_check(party.get_hero(1).get("block") == 6,
		"the Warden opens the slain-source fixture with his 6 Block")
	var intents := CombatEnemyIntents.new(assembled["definitions"])
	var result := phase.execute_phase(party, enemies, intents.get_intents())
	_check(result == {"ok": true, "events": [
		{"type": "shove", "enemy_position": 1, "applied": false,
			"target_position": 1, "direction": 1},
		{"type": "debuff", "enemy_position": 2, "applied": true,
			"target_position": 1, "status": "exposed"},
		{"type": "attack", "enemy_position": 3, "applied": true,
			"target_position": 1}]},
		"the slain source is skipped while both living sources still act")
	var heroes := party.get_heroes()
	_check(heroes[0].get("id") == "warden" and heroes[0].get("position") == 1
		and heroes[0].get("hp") == 40 and heroes[0].get("block") == 0,
		"the Warden stays at hero position 1 with 40 HP; his 6 Block absorbed the 6 damage")
	_check(heroes[0].get("statuses", {}).get("exposed", 0) == 1,
		"the Warden carries the Exposed 1 aimed at hero position 1")
	_check(heroes[1].get("id") == "seamstress" and heroes[1].get("position") == 2
		and heroes[1].get("hp") == 30 and heroes[1].get("block") == 0,
		"the Seamstress stays at hero position 2 with 30 HP")
	_check(heroes[2].get("id") == "tinker" and heroes[2].get("position") == 3
		and heroes[2].get("hp") == 26 and heroes[2].get("block") == 0,
		"the Tinker keeps hero position 3 with 26 HP")

	# Invalid case: a torn Warden at slot 1 makes the beat-1 shove illegal, so
	# the whole phase fails closed without any later event or state change.
	var torn_party := _build_party()
	var torn_enemies: CombatEnemies = _assemble(choice)["enemies"]
	var warden := torn_party.get_hero(1)
	_check(torn_party.apply_damage(1, warden.get("max_hp") + warden.get("block")),
		"the front Warden is torn before the first beat")
	_check(torn_party.is_downed(1) and torn_party.get_hero(1).get("position") == 1,
		"the torn Warden stays in his own slot")
	_check(not CombatPositionSwaps.preview_adjacent_swap(torn_party, 1, 1).get("ok", false),
		"a torn hero cannot be shoved")
	var before_party := torn_party.get_heroes()
	var before_enemies := torn_enemies.get_enemies()
	var torn_intents := CombatEnemyIntents.new(assembled["definitions"])
	seed(FIXED_SEED)
	var rng_before := randi()
	seed(FIXED_SEED)
	var torn_result := phase.execute_phase(torn_party, torn_enemies, torn_intents.get_intents())
	_check(randi() == rng_before, "the rejected phase draws no global RNG")
	_check(torn_result == {"ok": false, "events": []},
		"the shove of a torn hero fails the whole phase closed")
	_check(torn_party.get_heroes() == before_party,
		"the rejected phase leaves the party unchanged")
	_check(torn_enemies.get_enemies() == before_enemies,
		"the rejected phase leaves the enemy roster unchanged")
