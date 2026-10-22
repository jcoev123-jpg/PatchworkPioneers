extends SceneTree

## Deterministic headless coverage for the authored Spoolgate Exposed Pivot
## encounter (standalone M04 Fight content; NOT registered in the live pool):
##   enemy_position 1 (Spool Stalker): beat 1 Exposed 1, beat 2 shove, beat 3 attack 3.
##   enemy_position 2 (Button Guard):  beat 1 attack 4, beat 2 attack 4, beat 3 Block 3.
## Beat 1 marks the front Warden Exposed 1 BEFORE the base-4 hit, so it deals
## floor(4 * 1.5) = 6 and consumes his whole 6 opening Block (40 HP stays 40).
## Beat 2 shoves the Warden (1) back into the Seamstress (2), so the Guard's
## base-4 hit lands on the new front Seamstress (30 -> 26), not the Warden.
## Beat 3 hits the rear Tinker for 3 (26 -> 23) and the Guard banks 3 Block.
## A pre-downed Warden fails the whole beat-1 phase closed. No live wiring,
## pool entry or UI here.

const ENCOUNTER_PATH := "res://data/encounters/spoolgate_exposed_pivot.json"
const ENCOUNTER_ID := "spoolgate_exposed_pivot"
const BUTTONRAIL_PATH := "res://data/encounters/buttonrail_frontshift.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const FIXED_SEED := 20261022

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_ac1_authored_schedule_and_intents()
	_test_ac2_three_fresh_beats()
	_test_ac2_downed_warden_negative()
	_test_ac3_typed_selection_and_roster()
	if failures.is_empty():
		print("spoolgate_exposed_pivot_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("spoolgate_exposed_pivot_encounter_test: FAIL (", failures.size(), " failures)")
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


func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "catalog holds exactly one record named " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _all_numeric_leaves_integral(value: Variant) -> bool:
	if value is float:
		return not is_nan(value) and not is_inf(value) \
			and absf(value) <= 9007199254740991.0 and floorf(value) == value
	if value is Array:
		for item in value:
			if not _all_numeric_leaves_integral(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not _all_numeric_leaves_integral(value[key]):
				return false
		return true
	return true


## The authored prescription, copied verbatim from the brief.
func _expected_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
				{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
				{"type": "attack", "amount": 3, "target_position": 3}
			]
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "attack", "amount": 4, "target_position": 1},
				{"type": "attack", "amount": 4, "target_position": 1},
				{"type": "block", "amount": 3}
			]
		}
	]


## The existing Buttonrail Frontshift schedule, verbatim, so this test protects it.
func _expected_buttonrail_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
				{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
				{"type": "block", "amount": 3}
			]
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "attack", "amount": 3, "target_position": 1},
				{"type": "attack", "amount": 4, "target_position": 3},
				{"type": "attack", "amount": 2, "target_position": 2}
			]
		}
	]


func _expected_beat(definitions: Array, beat_index: int) -> Array:
	var actions: Array = []
	for definition in definitions:
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat_index % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


func _expected_events(definitions: Array, beat_index: int) -> Array:
	var events: Array = []
	for intent in _expected_beat(definitions, beat_index):
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


func _source_record(definitions: Array, position: int) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("enemy_position") == position:
			matches.append(definition)
	_check(matches.size() == 1, "exactly one source record at enemy_position %d" % position)
	return matches[0] if matches.size() == 1 else {}


## The three shipped heroes at 40/30/26 HP, with the real Warden opening Block.
func _build_party() -> CombatParty:
	var heroes := _load_catalog(HERO_CATALOG_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "the three shipped heroes build a valid CombatParty")
	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "CombatStartingBlock applies the Warden's opening Block")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("block") == 6,
		"the Warden holds 6 opening Block")
	_check(party.get_hero(2).get("block") == 0 and party.get_hero(3).get("block") == 0,
		"the other heroes hold no opening Block")
	return party


## The two named shipped enemies, source slot 1 = Spool Stalker, slot 2 = Button Guard.
func _build_enemies() -> CombatEnemies:
	var roster := _load_catalog(ENEMY_CATALOG_PATH)
	var definitions: Array = []
	for id in ["spool_stalker", "button_guard"]:
		definitions.append(_record_by_id(roster, id))
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid(), "the two shipped enemies build a valid CombatEnemies")
	return enemies


func _hero_record(id: String) -> Dictionary:
	return _record_by_id(_load_catalog(HERO_CATALOG_PATH), id)


func _enemy_record(id: String) -> Dictionary:
	return _record_by_id(_load_catalog(ENEMY_CATALOG_PATH), id)


## One fresh fixture per beat: a real party, real enemies and the real scheduler.
func _run_beat(definitions: Array, beat_index: int) -> Dictionary:
	var party := _build_party()
	var enemies := _build_enemies()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents validates the authored schedule")
	for step in range(beat_index):
		_check(intents.advance_turn(), "advance to beat %d" % (step + 2))
	var announced := intents.get_intents()
	_check(announced == _expected_beat(definitions, beat_index),
		"beat %d announces the exact authored actions" % (beat_index + 1))
	var result := phase.execute_phase(party, enemies, announced)
	return {
		"result": result,
		"party": party,
		"enemies": enemies,
		"heroes": party.get_heroes(),
		"enemy_state": enemies.get_enemies(),
		"announced": announced,
	}


## AC1: the authored JSON holds exactly the two prescribed sources and six
## actions, the production parser accepts it, the intent service validates it and
## announces beats 1, 2, 3 and then beat 1 again; the existing Buttonrail
## Frontshift schedule still parses unchanged.
func _test_ac1_authored_schedule_and_intents() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "the authored schedule file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID " + ENCOUNTER_ID)
	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw_json: Variant = JSON.parse_string(raw_text)
	_check(raw_json is Array, "the authored file is a top-level JSON array")
	_check(raw_json is Array and raw_json.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	_check(_all_numeric_leaves_integral(raw_json),
		"every numeric leaf of the raw file is integral before coercion")
	var raw_action_count := 0
	if raw_json is Array:
		for raw_definition in raw_json:
			if raw_definition is Dictionary and raw_definition.get("pattern") is Array:
				raw_action_count += raw_definition["pattern"].size()
	_check(raw_action_count == 6, "the authored file defines exactly six actions")

	var loaded := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(loaded == _expected_definitions(),
		"the production parser returns exactly the prescribed two-source schedule")
	_check(loaded.size() == 2, "the parsed schedule holds exactly two sources")
	_check(CombatEnemyIntents.new(loaded).is_valid(),
		"CombatEnemyIntents validates the authored schedule")

	for position in [1, 2]:
		var record := _source_record(loaded, position)
		_check(record.size() == 2 and record.has("enemy_position") and record.has("pattern"),
			"source %d carries only enemy_position and pattern" % position)
		var pattern = record.get("pattern")
		_check(pattern is Array and pattern.size() == 3,
			"source %d repeats exactly three beats" % position)
	_check(_source_record(loaded, 1).get("pattern") == _expected_definitions()[0]["pattern"],
		"source 1 holds the exact Exposed / shove / attack beat records")
	_check(_source_record(loaded, 2).get("pattern") == _expected_definitions()[1]["pattern"],
		"source 2 holds the exact 4 / 4 / Block beat records")
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
	_check(intents.is_valid(), "CombatEnemyIntents validates the parsed schedule")
	_check(intents.get_intents() == _expected_beat(loaded, 0),
		"beat 1 announces the Exposed debuff then the base-4 attack")
	_check(intents.advance_turn(), "advance to beat 2")
	_check(intents.get_intents() == _expected_beat(loaded, 1),
		"beat 2 announces the shove then the base-4 attack")
	_check(intents.advance_turn(), "advance to beat 3")
	_check(intents.get_intents() == _expected_beat(loaded, 2),
		"beat 3 announces the rear attack then the Guard Block")
	_check(intents.advance_turn(), "advance to beat 4")
	_check(intents.get_intents() == _expected_beat(loaded, 0), "beat 4 repeats beat 1 exactly")

	var fetched := intents.get_intents()
	fetched[0]["amount"] = 999
	fetched.append({"type": "invented"})
	_check(intents.get_intents() == _expected_beat(loaded, 0),
		"mutating an announced intent cannot change later announcements")

	# The named older authored encounter still parses unchanged, beat by beat.
	_check(FileAccess.file_exists(BUTTONRAIL_PATH), "buttonrail_frontshift.json still exists")
	var buttonrail := RunFightEncounterSelection._parse_schedule_text(_read_text(BUTTONRAIL_PATH))
	_check(buttonrail == _expected_buttonrail_definitions(),
		"buttonrail_frontshift.json still parses to its exact authored schedule")
	_check(buttonrail.size() == 2, "buttonrail_frontshift.json still holds two sources")
	_check(CombatEnemyIntents.new(buttonrail).is_valid(),
		"buttonrail_frontshift.json still validates in CombatEnemyIntents")
	_check(buttonrail != loaded, "the new schedule is distinct from buttonrail_frontshift")


## AC2: each authored beat runs on its own fresh canonical fixture through the
## real CombatEnemyPhase, with the Warden's real 6 opening Block.
func _test_ac2_three_fresh_beats() -> void:
	seed(FIXED_SEED)
	var rng_before := randi()
	seed(FIXED_SEED)
	var beat1 := _run_beat(_expected_definitions(), 0)
	var beat2 := _run_beat(_expected_definitions(), 1)
	var beat3 := _run_beat(_expected_definitions(), 2)
	_check(randi() == rng_before, "the three enemy phases draw no global RNG")

	# Fixture preconditions, asserted on the fresh beat-1 fight before its phase.
	var pre_party := _build_party()
	_check(pre_party.get_hero(1).get("id") == "warden" and pre_party.get_hero(1).get("hp") == 40
		and pre_party.get_hero(1).get("block") == 6,
		"Warden starts at position 1 with 40 HP and 6 opening Block")
	_check(pre_party.get_hero(2).get("id") == "seamstress" and pre_party.get_hero(2).get("hp") == 30
		and pre_party.get_hero(2).get("block") == 0,
		"Seamstress starts at position 2 with 30 HP and 0 Block")
	_check(pre_party.get_hero(3).get("id") == "tinker" and pre_party.get_hero(3).get("hp") == 26
		and pre_party.get_hero(3).get("block") == 0,
		"Tinker starts at position 3 with 26 HP and 0 Block")
	var pre_enemies := _build_enemies()
	_check(pre_enemies.get_enemy(1).get("id") == "spool_stalker"
		and pre_enemies.get_enemy(1).get("max_hp") == 14 and pre_enemies.get_enemy(1).get("hp") == 14
		and pre_enemies.get_enemy(1).get("block") == 0,
		"enemy slot 1 is the shipped Spool Stalker with 14 max HP")
	_check(pre_enemies.get_enemy(2).get("id") == "button_guard"
		and pre_enemies.get_enemy(2).get("max_hp") == 16 and pre_enemies.get_enemy(2).get("hp") == 16
		and pre_enemies.get_enemy(2).get("block") == 0,
		"enemy slot 2 is the shipped Button Guard with 16 max HP")

	# ------------------------------------------------------------------
	# Beat 1: Exposed 1 lands on the front Warden BEFORE the base-4 attack,
	# so the hit is floor(4 * 1.5) = 6 and consumes his whole opening Block.
	# ------------------------------------------------------------------
	_check(beat1["result"] == {"ok": true, "events": _expected_events(_expected_definitions(), 0)},
		"beat 1 succeeds with the Exposed debuff then the Guard attack")
	var events1: Array = beat1["result"].get("events", [])
	_check(events1.size() == 2, "beat 1 emits exactly two ordered events")
	_check(events1.size() == 2 and events1[0].get("applied") == true and events1[1].get("applied") == true,
		"beat 1 events are both applied")
	var heroes1: Array = beat1["heroes"]
	_check(heroes1[0].get("id") == "warden" and heroes1[0].get("position") == 1
		and heroes1[0].get("hp") == 40 and heroes1[0].get("block") == 0,
		"beat 1: the Warden's 6 opening Block absorbs all 6 damage, so he stays at 40 HP and 0 Block")
	_check(heroes1[0].get("statuses", {}) == {"exposed": 1},
		"beat 1: the Warden still carries Exposed 1 until his owner-turn tick")
	_check(heroes1[1].get("id") == "seamstress" and heroes1[1].get("hp") == 30
		and heroes1[1].get("block") == 0,
		"beat 1: the Seamstress is untouched at 30 HP and 0 Block")
	_check(heroes1[2].get("id") == "tinker" and heroes1[2].get("hp") == 26
		and heroes1[2].get("block") == 0,
		"beat 1: the Tinker is untouched at 26 HP and 0 Block")
	var foes1: Array = beat1["enemy_state"]
	_check(foes1[0].get("id") == "spool_stalker" and foes1[0].get("hp") == 14
		and foes1[0].get("block") == 0,
		"beat 1: the Spool Stalker is unchanged at 14 HP and 0 Block")
	_check(foes1[1].get("id") == "button_guard" and foes1[1].get("hp") == 16
		and foes1[1].get("block") == 0,
		"beat 1: the Button Guard is unchanged at 16 HP and 0 Block")

	# The detached owner-turn tick expires Exposed 1 without touching the fixture.
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", beat1["party"].get_heroes())
	_check(tick.get("ok", false), "the detached hero owner-turn tick succeeds")
	if tick.get("ok", false):
		var ticked: Array = tick.get("actors", [])
		_check(ticked.size() == 3 and ticked[0].get("statuses", {}) == {},
			"the owner-turn tick expires the Warden's Exposed 1")
		_check(ticked[0].get("hp") == 40 and ticked[0].get("block") == 0,
			"the owner-turn tick proposes no other Warden change")
	_check(beat1["party"].get_heroes() == heroes1,
		"the detached owner-turn tick does not mutate the authoritative party")
	_check(beat1["party"].get_hero(1).get("statuses", {}) == {"exposed": 1},
		"the authoritative Warden still carries Exposed 1 after the detached tick")

	# ------------------------------------------------------------------
	# Beat 2: the shove exchanges Warden (1) and Seamstress (2) BEFORE the
	# Guard's base-4 attack, so the new front Seamstress falls 30 -> 26.
	# ------------------------------------------------------------------
	_check(beat2["result"] == {"ok": true, "events": _expected_events(_expected_definitions(), 1)},
		"beat 2 succeeds with the shove then the Guard attack")
	var heroes2: Array = beat2["heroes"]
	_check(heroes2[0].get("id") == "seamstress" and heroes2[0].get("position") == 1,
		"beat 2: the Seamstress now occupies hero position 1")
	_check(heroes2[1].get("id") == "warden" and heroes2[1].get("position") == 2,
		"beat 2: the Warden now occupies hero position 2")
	_check(heroes2[2].get("id") == "tinker" and heroes2[2].get("position") == 3,
		"beat 2: the Tinker keeps hero position 3")
	_check(heroes2[0].get("hp") == 26 and heroes2[0].get("block") == 0,
		"beat 2: the displaced front Seamstress took the 4 damage (30 to 26)")
	_check(heroes2[1].get("hp") == 40 and heroes2[1].get("block") == 6,
		"beat 2: the Warden keeps 40 HP and his untouched 6 opening Block")
	_check(heroes2[2].get("hp") == 26 and heroes2[2].get("block") == 0,
		"beat 2: the rear Tinker is untouched at 26 HP")
	_check(heroes2[0].get("statuses", {}).is_empty() and heroes2[1].get("statuses", {}).is_empty(),
		"beat 2: no status lands in this beat")
	var seamstress_record := _hero_record("seamstress")
	_check(heroes2[0].get("name") == seamstress_record.get("name")
		and heroes2[0].get("max_hp") == seamstress_record.get("max_hp")
		and heroes2[0].get("art_path") == seamstress_record.get("art_path"),
		"beat 2: the swapped Seamstress keeps every unrelated record field")
	var warden_record := _hero_record("warden")
	_check(heroes2[1].get("name") == warden_record.get("name")
		and heroes2[1].get("max_hp") == warden_record.get("max_hp")
		and heroes2[1].get("art_path") == warden_record.get("art_path"),
		"beat 2: the swapped Warden keeps every unrelated record field")
	var foes2: Array = beat2["enemy_state"]
	_check(foes2[0].get("id") == "spool_stalker" and foes2[0].get("hp") == 14
		and foes2[0].get("block") == 0,
		"beat 2: the Spool Stalker is unchanged at 14 HP and 0 Block")
	_check(foes2[1].get("id") == "button_guard" and foes2[1].get("hp") == 16
		and foes2[1].get("block") == 0,
		"beat 2: the Button Guard is unchanged at 16 HP and 0 Block")

	# ------------------------------------------------------------------
	# Beat 3: the Stalker hits the rear Tinker 26 -> 23, then the Guard banks 3 Block.
	# ------------------------------------------------------------------
	_check(beat3["result"] == {"ok": true, "events": _expected_events(_expected_definitions(), 2)},
		"beat 3 succeeds with the rear attack then the Guard Block")
	var heroes3: Array = beat3["heroes"]
	_check(heroes3[0].get("id") == "warden" and heroes3[0].get("hp") == 40
		and heroes3[0].get("block") == 6,
		"beat 3: the Warden is untouched at 40 HP and 6 opening Block")
	_check(heroes3[1].get("id") == "seamstress" and heroes3[1].get("hp") == 30,
		"beat 3: the Seamstress is untouched at 30 HP")
	_check(heroes3[2].get("id") == "tinker" and heroes3[2].get("position") == 3
		and heroes3[2].get("hp") == 23 and heroes3[2].get("block") == 0,
		"beat 3: the rear Tinker took 3 damage (26 to 23)")
	var foes3: Array = beat3["enemy_state"]
	_check(foes3[0].get("id") == "spool_stalker" and foes3[0].get("hp") == 14
		and foes3[0].get("block") == 0,
		"beat 3: the Spool Stalker stays at 14 HP and 0 Block")
	_check(foes3[1].get("id") == "button_guard" and foes3[1].get("hp") == 16
		and foes3[1].get("block") == 3,
		"beat 3: the Button Guard banks exactly 3 Block and keeps 16 HP")
	var guard_record := _enemy_record("button_guard")
	_check(foes3[1].get("name") == guard_record.get("name")
		and foes3[1].get("max_hp") == guard_record.get("max_hp")
		and foes3[1].get("art_path") == guard_record.get("art_path"),
		"beat 3: the Button Guard keeps every unrelated record field")


## AC2 negative: a pre-downed Warden makes the first Exposed debuff illegal, so
## the whole beat-1 phase rejects with no publication and no Guard attack.
func _test_ac2_downed_warden_negative() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(party.apply_damage(1, 46),
		"the Warden is downed through his 6 Block and 40 HP for the negative case")
	_check(party.is_downed(1), "precondition: the Warden is downed")
	_check(party.get_hero(1).get("hp") == 0 and party.get_hero(1).get("block") == 0,
		"precondition: the Warden holds 0 HP and 0 Block")
	_check(enemies.get_enemy(2).get("block") == 0,
		"precondition: the Button Guard holds 0 Block")

	var debuff_action: Dictionary = _expected_beat(_expected_definitions(), 0)[0]
	_check(debuff_action.get("type") == "debuff",
		"the beat-1 source-1 action really is the Exposed debuff")
	var special := CombatEnemySpecialActions.new().execute_actions(party, enemies, [debuff_action])
	_check(special == {"ok": false, "events": []},
		"the Exposed debuff alone fails closed on the downed Warden")

	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var intents := CombatEnemyIntents.new(_expected_definitions())
	var result := phase.execute_phase(party, enemies, intents.get_intents())
	_check(result == {"ok": false, "events": []},
		"the beat-1 phase rejects with ok=false and empty events")
	_check(party.get_heroes() == before_party,
		"the authoritative party is unchanged after the rejected phase")
	_check(enemies.get_enemies() == before_enemies,
		"the authoritative enemy roster is unchanged after the rejected phase")
	_check(party.get_hero(2).get("hp") == 30,
		"the rejected phase never let the Guard attack reach the Seamstress")
	_check(enemies.get_enemy(2).get("block") == 0,
		"the rejected phase never granted the Guard Block")


## AC3: a legal seeded RunMap Fight selects this encounter through a test-local
## pool with a stable cache, and the typed roster bridge binds the shipped IDs.
func _test_ac3_typed_selection_and_roster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXED_SEED
	var map := RunMap.new()
	_check(map.generate(rng), "the seeded run map generates")

	var fight_id := ""
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			fight_id = String(node_id)
			break
	_check(not fight_id.is_empty(), "the seeded map offers a legal Fight node")
	_check(map.choose_node(fight_id), "the legal Fight node is chosen")
	_check(map.get_current_node_id() == fight_id
		and map.get_node(fight_id).get("type") == "Fight",
		"the current route node is the chosen Fight")

	var pool := {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}
	var selector := RunFightEncounterSelection.new()
	var state_before := rng.state
	var choice := selector.select_current_battle(map, rng, pool)
	var state_after := rng.state
	_check(choice.get("success", false), "the test-local pool selects the authored Fight")
	_check(choice.get("node_type") == "Fight", "the selection reports a Fight node")
	_check(choice.get("encounter_id") == ENCOUNTER_ID,
		"the selection is the spoolgate_exposed_pivot encounter")
	_check(choice.get("definitions", []) == _expected_definitions(),
		"the selection returns the exact authored schedule")

	# The selector spends exactly the pool's single candidate draw and nothing
	# else: an oracle run from the same seed reaches the same RNG state.
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = FIXED_SEED
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng), "the oracle map generates")
	_check(oracle_map.choose_node(fight_id), "the oracle map chooses the same Fight node")
	_check(state_before == oracle_rng.state, "the run RNG state before selection matches the oracle")
	oracle_rng.randi_range(0, 0)
	_check(state_after == oracle_rng.state,
		"the first selection spends exactly the pool's single candidate draw")

	var cached := selector.select_current_battle(map, rng, pool)
	_check(cached == choice, "the cached selection repeats the same choice")
	_check(rng.state == state_after, "the cached selection draws no further RNG")

	# A fresh same-seed run reproduces the selection and the RNG state.
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = FIXED_SEED
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng), "the replayed seeded map generates")
	_check(replay_map.choose_node(fight_id), "the replayed map chooses the same Fight node")
	var replay_choice := RunFightEncounterSelection.new().select_current_battle(replay_map, replay_rng, pool)
	_check(replay_choice == choice, "a fresh same-seed run selects the same encounter")
	_check(replay_rng.state == rng.state, "a fresh same-seed run leaves the same RNG state")

	# The typed roster bridge binds the shipped IDs in source order.
	var roster_service := RunTypedBattleRoster.new()
	var choice_snapshot := choice.duplicate(true)
	var assembled := roster_service.assemble(
		choice, {ENCOUNTER_ID: ["spool_stalker", "button_guard"]}, [ENEMY_CATALOG_PATH])
	_check(assembled.get("ok") == true,
		"RunTypedBattleRoster.assemble binds the local encounter to the run enemy catalog")
	_check(assembled.get("node_type") == "Fight", "the assembled roster keeps the Fight node type")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID,
		"the assembled roster keeps the authored encounter ID")
	_check(assembled.get("definitions", []) == _expected_definitions(),
		"the assembled roster keeps the exact authored definitions")
	var bridged: Variant = assembled.get("enemies")
	_check(bridged is CombatEnemies and bridged.is_valid(),
		"the assembled roster is a valid CombatEnemies")
	if bridged is CombatEnemies:
		_check(bridged.get_enemies().size() == 2, "the assembled roster holds exactly two enemies")
		var stalker: Dictionary = bridged.get_enemy(1)
		_check(stalker.get("id") == "spool_stalker" and stalker.get("name") == "Spool Stalker"
			and stalker.get("max_hp") == 14 and stalker.get("hp") == 14
			and stalker.get("block") == 0 and stalker.get("position") == 1,
			"assembled slot 1 is the shipped Spool Stalker with 14 HP")
		_check(stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
			"assembled slot 1 keeps the shipped Spool Stalker art path")
		var guard: Dictionary = bridged.get_enemy(2)
		_check(guard.get("id") == "button_guard" and guard.get("name") == "Button Guard"
			and guard.get("max_hp") == 16 and guard.get("hp") == 16
			and guard.get("block") == 0 and guard.get("position") == 2,
			"assembled slot 2 is the shipped Button Guard with 16 HP")
		_check(guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
			"assembled slot 2 keeps the shipped Button Guard art path")
		_check(bridged.get_enemies() == _build_enemies().get_enemies(),
			"the bridged roster equals the roster built straight from the shipped catalog")

	# A mismatched roster mapping fails closed and never mutates the valid choice.
	var short_roster := roster_service.assemble(
		choice, {ENCOUNTER_ID: ["spool_stalker"]}, [ENEMY_CATALOG_PATH])
	_check(short_roster.get("ok") == false,
		"a roster with one enemy for two sources is rejected")
	var unknown_roster := roster_service.assemble(
		choice, {ENCOUNTER_ID: ["spool_stalker", "unknown_enemy"]}, [ENEMY_CATALOG_PATH])
	_check(unknown_roster.get("ok") == false, "a roster with an unknown enemy ID is rejected")
	var missing_roster := roster_service.assemble(choice, {}, [ENEMY_CATALOG_PATH])
	_check(missing_roster.get("ok") == false, "a roster missing the encounter ID is rejected")
	_check(choice == choice_snapshot, "the rejected rosters leave the valid selection unchanged")
