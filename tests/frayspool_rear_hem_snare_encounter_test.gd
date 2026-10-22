extends SceneTree

## Deterministic headless coverage for the authored Frayspool Rear Hem Snare M04
## normal Fight: three-source positional pressure encounter authored as JSON.
##
## Roster:
##   Source 1: Fray Scavenger (14 HP)
##   Source 2: Button Guard (16 HP)
##   Source 3: Spool Stalker (14 HP)
##
## Beat 1: Scavenger shoves Seamstress 2->3 (swapping Seamstress and Tinker),
##         Guard attacks position 2 (now Tinker) for 4,
##         Stalker applies Bleed 2 to position 3 (now Seamstress).

const ENCOUNTER_PATH := "res://data/encounters/frayspool_rear_hem_snare.json"
const ENCOUNTER_ID := "frayspool_rear_hem_snare"
const SPOOLCORD_PATH := "res://data/encounters/spoolcord_triad_relay.json"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const MAP_SEED := 4271

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_verify_ac1_schedule_parsing_and_intents()
	_verify_ac2_beat_1_execution_and_detached_bleed()
	_verify_ac3_beat_2_and_3_fresh_fixtures()
	_verify_ac4_run_map_selection_roster_and_downed_rejection()

	if failures.is_empty():
		print("frayspool_rear_hem_snare_encounter_test: PASS (%d checks)" % checks)
		quit(0)
		return

	for failure in failures:
		push_error(failure)
		printerr(failure)
	print("frayspool_rear_hem_snare_encounter_test: FAIL (%d failures)" % failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	_check(FileAccess.file_exists(path), "File must exist: %s" % path)
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	_check(file != null, "File must open: %s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	return absf(value) <= 9007199254740991.0 and floorf(value) == value


func _all_numeric_leaves_integral(value: Variant) -> bool:
	if value is float:
		return not is_nan(value) and not is_inf(value) and absf(value) <= 9007199254740991.0 and floorf(value) == value
	if value is Array:
		var arr: Array = value
		for item in arr:
			if not _all_numeric_leaves_integral(item):
				return false
		return true
	if value is Dictionary:
		var dict: Dictionary = value
		for key in dict:
			if not _all_numeric_leaves_integral(dict[key]):
				return false
		return true
	return true


func _count_numeric_leaves(value: Variant) -> int:
	if value is float or value is int:
		return 1
	var total: int = 0
	if value is Array:
		var arr: Array = value
		for item in arr:
			total += _count_numeric_leaves(item)
		return total
	if value is Dictionary:
		var dict: Dictionary = value
		for key in dict:
			total += _count_numeric_leaves(dict[key])
		return total
	return total


func _load_json_array(path: String) -> Array:
	var text: String = _read_text(path)
	if text.is_empty():
		return []
	var parser: JSON = JSON.new()
	var err: Error = parser.parse(text)
	_check(err == OK, "Expected valid JSON in %s" % path)
	if err != OK or not parser.data is Array:
		_check(false, "Expected top-level JSON Array in %s" % path)
		return []
	var arr: Array = parser.data
	return arr.duplicate(true)


func _find_unique_by_id(records: Array, id: String, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			var dict: Dictionary = record
			matches.append(dict.duplicate(true))
	_check(
		matches.size() == 1,
		"Expected exactly 1 record with id=%s in %s, found %d" % [id, label, matches.size()]
	)
	if matches.size() != 1:
		return {}
	return matches[0]


func _coerce_catalog_actor(raw: Dictionary, label: String) -> Dictionary:
	var copy: Dictionary = raw.duplicate(true)
	var id_val: Variant = copy.get("id")
	var name_val: Variant = copy.get("name")
	var art_val: Variant = copy.get("art_path")
	_check(id_val is String and not String(id_val).is_empty(), "%s must have nonempty String id" % label)
	_check(name_val is String and not String(name_val).is_empty(), "%s must have nonempty String name" % label)
	_check(art_val is String and not String(art_val).is_empty(), "%s must have nonempty String art_path" % label)
	var max_hp: Variant = copy.get("max_hp")
	_check(_is_integral_number(max_hp), "%s max_hp must be integral" % label)
	if _is_integral_number(max_hp):
		copy["max_hp"] = int(max_hp)
	return copy


func _build_catalog_party() -> CombatParty:
	var hero_catalog: Array = _load_json_array(HERO_CATALOG_PATH)
	var warden: Dictionary = _coerce_catalog_actor(_find_unique_by_id(hero_catalog, "warden", HERO_CATALOG_PATH), "warden")
	var seamstress: Dictionary = _coerce_catalog_actor(_find_unique_by_id(hero_catalog, "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker: Dictionary = _coerce_catalog_actor(_find_unique_by_id(hero_catalog, "tinker", HERO_CATALOG_PATH), "tinker")
	return CombatParty.new([warden, seamstress, tinker])


func _build_catalog_enemies() -> CombatEnemies:
	var enemy_catalog: Array = _load_json_array(ENEMY_CATALOG_PATH)
	var scavenger: Dictionary = _coerce_catalog_actor(_find_unique_by_id(enemy_catalog, "fray_scavenger", ENEMY_CATALOG_PATH), "fray_scavenger")
	var guard: Dictionary = _coerce_catalog_actor(_find_unique_by_id(enemy_catalog, "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	var stalker: Dictionary = _coerce_catalog_actor(_find_unique_by_id(enemy_catalog, "spool_stalker", ENEMY_CATALOG_PATH), "spool_stalker")
	return CombatEnemies.new([scavenger, guard, stalker])


func _expected_pattern_1() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "attack", "amount": 2, "target_position": 1},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 2},
		{"type": "block", "amount": 4},
		{"type": "buff", "amount": 2},
	]


func _expected_pattern_3() -> Array:
	return [
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "attack", "amount": 4, "target_position": 2},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
		{"enemy_position": 3, "pattern": _expected_pattern_3()},
	]


func _expected_beat_1_intents() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 2, "enemy_position": 2},
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "bleed", "enemy_position": 3},
	]


func _expected_beat_2_intents() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 1},
		{"type": "block", "amount": 4, "enemy_position": 2},
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 3},
	]


func _expected_beat_3_intents() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2},
		{"type": "attack", "amount": 4, "target_position": 2, "enemy_position": 3},
	]


## AC1: Parser normalizes numeric values and CombatEnemyIntents announces 1/2/3/wrap cycle.
## Also validates that earlier spoolcord_triad_relay.json continues parsing unchanged.
func _verify_ac1_schedule_parsing_and_intents() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "AC1: Encounter file exists: %s" % ENCOUNTER_PATH)
	var raw_text: String = _read_text(ENCOUNTER_PATH)
	_check(not raw_text.is_empty(), "AC1: Encounter file is readable")
	if raw_text.is_empty():
		return

	var raw_json: Variant = JSON.parse_string(raw_text)
	_check(raw_json is Array, "AC1: Raw JSON is a top-level Array")
	if not raw_json is Array:
		return
	var raw_array: Array = raw_json
	_check(_all_numeric_leaves_integral(raw_array), "AC1: All numeric leaves are integral before coercion")
	_check(_count_numeric_leaves(raw_array) == 20, "AC1: Exactly 20 numeric fields present in raw JSON")
	_check(raw_array.size() == 3, "AC1: Raw JSON has exactly 3 source definitions")

	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions.size() == 3, "AC1: Parsed schedule has 3 source definitions")
	_check(definitions == _expected_definitions(), "AC1: Parsed schedule matches expected 3-source definitions exactly")

	for def_item in definitions:
		var def_dict: Dictionary = def_item
		_check(def_dict.get("enemy_position") is int, "AC1: Parsed enemy_position is int")
		var pattern: Array = def_dict.get("pattern", [])
		_check(pattern.size() == 3, "AC1: Pattern has exactly 3 actions")
		for action_item in pattern:
			var act: Dictionary = action_item
			_check(act.get("amount") is int, "AC1: Action amount is int")
			if act.has("target_position"):
				_check(act.get("target_position") is int, "AC1: target_position is int")
			if act.has("direction"):
				_check(act.get("direction") is int, "AC1: direction is int")

	var intents: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "AC1: CombatEnemyIntents accepts frayspool_rear_hem_snare schedule")
	_check(intents.get_intents() == _expected_beat_1_intents(), "AC1: Beat 1 announces source-ordered shove, attack, debuff")
	_check(intents.advance_turn(), "AC1: Advance to Beat 2 succeeds")
	_check(intents.get_intents() == _expected_beat_2_intents(), "AC1: Beat 2 announces source-ordered attack, block, attack")
	_check(intents.advance_turn(), "AC1: Advance to Beat 3 succeeds")
	_check(intents.get_intents() == _expected_beat_3_intents(), "AC1: Beat 3 announces source-ordered attack, buff, attack")
	_check(intents.advance_turn(), "AC1: Advance 3 to wrap succeeds")
	_check(intents.get_intents() == _expected_beat_1_intents(), "AC1: Advance 3 wraps to exact Beat 1 intents")

	# Positive control: spoolcord_triad_relay.json continues parsing unchanged
	_check(FileAccess.file_exists(SPOOLCORD_PATH), "AC1: spoolcord_triad_relay.json exists")
	var spoolcord_text: String = _read_text(SPOOLCORD_PATH)
	var spoolcord_defs: Array = RunFightEncounterSelection._parse_schedule_text(spoolcord_text)
	_check(spoolcord_defs.size() == 3, "AC1: spoolcord_triad_relay parses into 3 definitions")
	var spoolcord_intents: CombatEnemyIntents = CombatEnemyIntents.new(spoolcord_defs)
	_check(spoolcord_intents.is_valid(), "AC1: spoolcord_triad_relay remains valid in CombatEnemyIntents")


## AC2: Beat 1 runs against real catalogs with Warden +6 starting Block.
## Shove exchanges Seamstress (2->3) and Tinker (3->2), Guard hits new slot-2 Tinker for 4 (26->22),
## Stalker applies Bleed 2 to new slot-3 Seamstress.
## Detached CombatStatusTurnBatch demonstrates two-step Bleed owner ticks without party mutation.
func _verify_ac2_beat_1_execution_and_detached_bleed() -> void:
	var party: CombatParty = _build_catalog_party()
	var enemies: CombatEnemies = _build_catalog_enemies()
	_check(party.is_valid(), "AC2: Catalog party is valid")
	_check(enemies.is_valid(), "AC2: Catalog enemies are valid")
	if not party.is_valid() or not enemies.is_valid():
		return

	# Start-of-combat passive grants 6 Block once via CombatStartingBlock
	var starting_block: CombatStartingBlock = CombatStartingBlock.new(party)
	_check(starting_block.apply(), "AC2: CombatStartingBlock.apply() succeeds")
	_check(not starting_block.apply(), "AC2: Second CombatStartingBlock.apply() fails closed (one-shot)")

	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6, "AC2: Opening slot 1 Warden 40 HP / 6 Block")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0, "AC2: Opening slot 2 Seamstress 30 HP / 0 Block")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0, "AC2: Opening slot 3 Tinker 26 HP / 0 Block")

	_check(enemies.get_enemy(1).get("id") == "fray_scavenger" and enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0, "AC2: Opening enemy 1 Fray Scavenger 14 HP / 0 Block")
	_check(enemies.get_enemy(2).get("id") == "button_guard" and enemies.get_enemy(2).get("hp") == 16 and enemies.get_enemy(2).get("block") == 0, "AC2: Opening enemy 2 Button Guard 16 HP / 0 Block")
	_check(enemies.get_enemy(3).get("id") == "spool_stalker" and enemies.get_enemy(3).get("hp") == 14 and enemies.get_enemy(3).get("block") == 0, "AC2: Opening enemy 3 Spool Stalker 14 HP / 0 Block")

	var phase: CombatEnemyPhase = CombatEnemyPhase.new()
	var beat_1_result: Dictionary = phase.execute_phase(party, enemies, _expected_beat_1_intents())
	var expected_beat_1_events: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 2, "direction": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
		{"type": "debuff", "enemy_position": 3, "target_position": 3, "status": "bleed", "applied": true},
	]
	_check(beat_1_result == {"ok": true, "events": expected_beat_1_events}, "AC2: Beat 1 execute_phase resolves shove, attack, debuff in source order")

	# Warden remains 40 HP / 6 Block
	var h1: Dictionary = party.get_hero(1)
	_check(h1.get("id") == "warden" and h1.get("position") == 1 and h1.get("hp") == 40 and h1.get("block") == 6 and h1.get("statuses", {}) == {}, "AC2: Warden at slot 1 remains 40 HP / 6 Block / no statuses")

	# Tinker swapped to slot 2 and took 4 damage: 26 -> 22 HP
	var h2: Dictionary = party.get_hero(2)
	_check(h2.get("id") == "tinker" and h2.get("position") == 2 and h2.get("hp") == 22 and h2.get("block") == 0 and h2.get("statuses", {}) == {}, "AC2: Tinker swapped to slot 2, took 4 damage: 22 HP / 0 Block / no statuses")

	# Seamstress swapped to slot 3 and received Bleed 2 without immediate HP loss: 30 HP
	var h3: Dictionary = party.get_hero(3)
	_check(h3.get("id") == "seamstress" and h3.get("position") == 3 and h3.get("hp") == 30 and h3.get("block") == 0 and h3.get("statuses") == {"bleed": 2}, "AC2: Seamstress swapped to slot 3, 30 HP / 0 Block / Bleed 2")

	# Enemies remain 14 / 16 / 14 HP and 0 Block
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0, "AC2: Enemy 1 Fray Scavenger remains 14 HP / 0 Block")
	_check(enemies.get_enemy(2).get("hp") == 16 and enemies.get_enemy(2).get("block") == 0, "AC2: Enemy 2 Button Guard remains 16 HP / 0 Block")
	_check(enemies.get_enemy(3).get("hp") == 14 and enemies.get_enemy(3).get("block") == 0, "AC2: Enemy 3 Spool Stalker remains 14 HP / 0 Block")

	# Detached CombatStatusTurnBatch: Seamstress Bleed 2 -> 2 HP loss (30->28, counter 2->1), then tick 1 (28->27, counter removed)
	var party_snapshot_heroes: Array = party.get_heroes()
	var batch: CombatStatusTurnBatch = CombatStatusTurnBatch.new()
	var tick1: Dictionary = batch.tick_side("heroes", party.get_heroes())
	_check(tick1.get("ok") == true, "AC2: Detached tick 1 succeeds")
	var actors1: Array = tick1.get("actors", [])
	_check(actors1.size() == 3, "AC2: Detached tick 1 returns 3 actors")
	if actors1.size() == 3:
		var a1_s3: Dictionary = actors1[2]
		_check(a1_s3.get("id") == "seamstress" and a1_s3.get("hp") == 28 and a1_s3.get("statuses") == {"bleed": 1}, "AC2: Tick 1: Seamstress 30->28 HP, Bleed 2->1")
		var a1_s1: Dictionary = actors1[0]
		_check(a1_s1.get("id") == "warden" and a1_s1.get("hp") == 40 and a1_s1.get("block") == 6, "AC2: Tick 1: Warden untouched at 40 HP / 6 Block")
		var a1_s2: Dictionary = actors1[1]
		_check(a1_s2.get("id") == "tinker" and a1_s2.get("hp") == 22, "AC2: Tick 1: Tinker untouched at 22 HP")
	var events1: Array = tick1.get("events", [])
	_check(events1 == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "tinker", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "seamstress", "bleed_hp_loss": 2},
	], "AC2: Tick 1 events report 2 Bleed HP loss on Seamstress")

	var tick2: Dictionary = batch.tick_side("heroes", actors1)
	_check(tick2.get("ok") == true, "AC2: Detached tick 2 succeeds")
	var actors2: Array = tick2.get("actors", [])
	_check(actors2.size() == 3, "AC2: Detached tick 2 returns 3 actors")
	if actors2.size() == 3:
		var a2_s3: Dictionary = actors2[2]
		_check(a2_s3.get("id") == "seamstress" and a2_s3.get("hp") == 27 and a2_s3.get("statuses", {}) == {}, "AC2: Tick 2: Seamstress 28->27 HP, Bleed removed")
	var events2: Array = tick2.get("events", [])
	_check(events2 == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "tinker", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "seamstress", "bleed_hp_loss": 1},
	], "AC2: Tick 2 events report 1 Bleed HP loss on Seamstress")

	# Authoritative party unmutated by detached ticks
	_check(party.get_heroes() == party_snapshot_heroes, "AC2: Detached ticks did not mutate authoritative CombatParty")
	_check(party.get_hero(3).get("hp") == 30 and party.get_hero(3).get("statuses") == {"bleed": 2}, "AC2: Seamstress in authoritative party still holds 30 HP / Bleed 2")


## AC3: Independent fresh fixtures for Beat 2 and Beat 3.
## Beat 2: deals 3 to slot-3 Tinker (26->23), grants 4 Block to Button Guard, Stalker attacks Warden for 3 (40 HP, Block 6->3).
## Beat 3: attacks Warden for 2 (40 HP, Block 6->4), grants Button Guard 2 Block via buff, attacks Seamstress for 4 (30->26).
func _verify_ac3_beat_2_and_3_fresh_fixtures() -> void:
	var phase: CombatEnemyPhase = CombatEnemyPhase.new()

	# --- Beat 2 fresh fixture ---
	var party2: CombatParty = _build_catalog_party()
	var enemies2: CombatEnemies = _build_catalog_enemies()
	_check(CombatStartingBlock.new(party2).apply(), "AC3: Warden opening Block applied on fresh Beat 2 fixture")

	var beat_2_result: Dictionary = phase.execute_phase(party2, enemies2, _expected_beat_2_intents())
	var expected_beat_2_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 1, "applied": true},
	]
	_check(beat_2_result == {"ok": true, "events": expected_beat_2_events}, "AC3: Beat 2 resolves attack, block, attack in source order")

	# Warden at slot 1 took 3 damage to Block: 40 HP, Block 6 -> 3
	var h1_b2: Dictionary = party2.get_hero(1)
	_check(h1_b2.get("id") == "warden" and h1_b2.get("hp") == 40 and h1_b2.get("block") == 3 and h1_b2.get("statuses", {}) == {}, "AC3: Beat 2 Warden at slot 1: 40 HP / 3 Block / no statuses")

	# Seamstress at slot 2 unhurt: 30 HP / 0 Block
	var h2_b2: Dictionary = party2.get_hero(2)
	_check(h2_b2.get("id") == "seamstress" and h2_b2.get("hp") == 30 and h2_b2.get("block") == 0 and h2_b2.get("statuses", {}) == {}, "AC3: Beat 2 Seamstress at slot 2: 30 HP / 0 Block / no statuses")

	# Tinker at slot 3 took 3 damage: 26 -> 23 HP
	var h3_b2: Dictionary = party2.get_hero(3)
	_check(h3_b2.get("id") == "tinker" and h3_b2.get("hp") == 23 and h3_b2.get("block") == 0 and h3_b2.get("statuses", {}) == {}, "AC3: Beat 2 Tinker at slot 3: 23 HP / 0 Block / no statuses")

	# Button Guard at slot 2 gained 4 Block; others have 0 Block; all HP 14/16/14
	_check(enemies2.get_enemy(1).get("hp") == 14 and enemies2.get_enemy(1).get("block") == 0, "AC3: Beat 2 Enemy 1 Fray Scavenger 14 HP / 0 Block")
	_check(enemies2.get_enemy(2).get("hp") == 16 and enemies2.get_enemy(2).get("block") == 4, "AC3: Beat 2 Enemy 2 Button Guard 16 HP / 4 Block")
	_check(enemies2.get_enemy(3).get("hp") == 14 and enemies2.get_enemy(3).get("block") == 0, "AC3: Beat 2 Enemy 3 Spool Stalker 14 HP / 0 Block")

	# --- Beat 3 fresh fixture ---
	var party3: CombatParty = _build_catalog_party()
	var enemies3: CombatEnemies = _build_catalog_enemies()
	_check(CombatStartingBlock.new(party3).apply(), "AC3: Warden opening Block applied on fresh Beat 3 fixture")

	var beat_3_result: Dictionary = phase.execute_phase(party3, enemies3, _expected_beat_3_intents())
	var expected_beat_3_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "buff", "enemy_position": 2, "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 2, "applied": true},
	]
	_check(beat_3_result == {"ok": true, "events": expected_beat_3_events}, "AC3: Beat 3 resolves attack, buff, attack in source order")

	# Warden at slot 1 took 2 damage to Block: 40 HP, Block 6 -> 4
	var h1_b3: Dictionary = party3.get_hero(1)
	_check(h1_b3.get("id") == "warden" and h1_b3.get("hp") == 40 and h1_b3.get("block") == 4 and h1_b3.get("statuses", {}) == {}, "AC3: Beat 3 Warden at slot 1: 40 HP / 4 Block / no statuses")

	# Seamstress at slot 2 took 4 damage: 30 -> 26 HP
	var h2_b3: Dictionary = party3.get_hero(2)
	_check(h2_b3.get("id") == "seamstress" and h2_b3.get("hp") == 26 and h2_b3.get("block") == 0 and h2_b3.get("statuses", {}) == {}, "AC3: Beat 3 Seamstress at slot 2: 26 HP / 0 Block / no statuses")

	# Tinker at slot 3 unhurt: 26 HP / 0 Block
	var h3_b3: Dictionary = party3.get_hero(3)
	_check(h3_b3.get("id") == "tinker" and h3_b3.get("hp") == 26 and h3_b3.get("block") == 0 and h3_b3.get("statuses", {}) == {}, "AC3: Beat 3 Tinker at slot 3: 26 HP / 0 Block / no statuses")

	# Button Guard at slot 2 gained 2 Block via buff; others have 0 Block; all HP 14/16/14
	_check(enemies3.get_enemy(1).get("hp") == 14 and enemies3.get_enemy(1).get("block") == 0, "AC3: Beat 3 Enemy 1 Fray Scavenger 14 HP / 0 Block")
	_check(enemies3.get_enemy(2).get("hp") == 16 and enemies3.get_enemy(2).get("block") == 2, "AC3: Beat 3 Enemy 2 Button Guard 16 HP / 2 Block")
	_check(enemies3.get_enemy(3).get("hp") == 14 and enemies3.get_enemy(3).get("block") == 0, "AC3: Beat 3 Enemy 3 Spool Stalker 14 HP / 0 Block")


## AC4: RunMap selection on legal Fight node, cached choice without RNG consumption,
## typed roster assembly and negative mapping rejections,
## and atomic rejection when Tinker is downed at 0 HP before Beat 1 shove.
func _verify_ac4_run_map_selection_roster_and_downed_rejection() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	var map: RunMap = RunMap.new()
	_check(map.generate(rng), "AC4: RunMap generates with seed")

	var fight_id: String = ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty(), "AC4: Legal opening Fight node found on map")
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id), "AC4: choose_node succeeds on legal Fight node")

	var local_pool: Dictionary = {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}
	var selector: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var choice: Dictionary = selector.select_current_battle(map, rng, local_pool)
	_check(choice.get("success") == true, "AC4: select_current_battle succeeds")
	_check(choice.get("node_type") == "Fight", "AC4: Selected node_type is Fight")
	_check(choice.get("encounter_id") == ENCOUNTER_ID, "AC4: Selected encounter_id is frayspool_rear_hem_snare")
	_check(choice.get("definitions") == _expected_definitions(), "AC4: Selected definitions match expected schedule")

	# Repeating selection returns identical cached choice without consuming run RNG
	var rng_state_before: int = rng.state
	var cached_choice: Dictionary = selector.select_current_battle(map, rng, local_pool)
	_check(cached_choice == choice, "AC4: Repeated selection returns identical choice")
	_check(rng.state == rng_state_before, "AC4: Repeated selection consumes zero run RNG")

	# RunTypedBattleRoster.assemble with local mapping
	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var local_mapping: Dictionary = {ENCOUNTER_ID: ["fray_scavenger", "button_guard", "spool_stalker"]}
	var assembled: Dictionary = roster_service.assemble(choice, local_mapping, [ENEMY_CATALOG_PATH])
	_check(assembled.get("ok") == true, "AC4: RunTypedBattleRoster.assemble succeeds for local mapping")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID, "AC4: Assembled encounter_id matches")
	var roster_variant: Variant = assembled.get("enemies")
	_check(roster_variant is CombatEnemies, "AC4: Assembled enemies is CombatEnemies instance")
	if roster_variant is CombatEnemies:
		var enemies: CombatEnemies = roster_variant
		_check(enemies.get_enemy(1).get("id") == "fray_scavenger" and enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("max_hp") == 14, "AC4: Assembled enemy 1 is Fray Scavenger 14/14 HP")
		_check(enemies.get_enemy(2).get("id") == "button_guard" and enemies.get_enemy(2).get("hp") == 16 and enemies.get_enemy(2).get("max_hp") == 16, "AC4: Assembled enemy 2 is Button Guard 16/16 HP")
		_check(enemies.get_enemy(3).get("id") == "spool_stalker" and enemies.get_enemy(3).get("hp") == 14 and enemies.get_enemy(3).get("max_hp") == 14, "AC4: Assembled enemy 3 is Spool Stalker 14/14 HP")

	# Mismatched local roster mapping rejects
	_check(roster_service.assemble(choice, {ENCOUNTER_ID: ["fray_scavenger", "button_guard"]}, [ENEMY_CATALOG_PATH]) == {"ok": false}, "AC4: Rejects roster with wrong count")
	_check(roster_service.assemble(choice, {ENCOUNTER_ID: ["fray_scavenger", "button_guard", "button_guard"]}, [ENEMY_CATALOG_PATH]) == {"ok": false}, "AC4: Rejects roster with duplicate enemy ID")
	_check(roster_service.assemble(choice, {ENCOUNTER_ID: ["fray_scavenger", "button_guard", "unknown_enemy"]}, [ENEMY_CATALOG_PATH]) == {"ok": false}, "AC4: Rejects roster with unknown enemy ID")
	_check(roster_service.assemble(choice, {"mismatched_id": ["fray_scavenger", "button_guard", "spool_stalker"]}, [ENEMY_CATALOG_PATH]) == {"ok": false}, "AC4: Rejects roster with mismatched encounter ID key")

	# Negative test: Tinker already downed at 0 HP before Beat 1 shove
	var downed_party: CombatParty = _build_catalog_party()
	var downed_enemies: CombatEnemies = _build_catalog_enemies()
	_check(CombatStartingBlock.new(downed_party).apply(), "AC4: Warden Block applied on downed fixture")

	# Down Tinker (destination of 2->3 shove) at slot 3 before Beat 1
	_check(downed_party.apply_damage(3, 26), "AC4: Down Tinker with 26 damage")
	_check(downed_party.is_downed(3), "AC4: Precondition: destination hero Tinker at slot 3 is downed (0 HP)")
	_check(not downed_party.is_downed(2), "AC4: Precondition: mover hero Seamstress at slot 2 is alive (30 HP)")
	_check(not downed_party.is_downed(1), "AC4: Precondition: Warden at slot 1 is alive (40 HP)")

	var heroes_snapshot: Array = downed_party.get_heroes()
	var enemies_snapshot: Array = downed_enemies.get_enemies()
	var local_test_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	local_test_rng.seed = 887766
	var test_rng_state_before: int = local_test_rng.state

	var phase: CombatEnemyPhase = CombatEnemyPhase.new()
	var downed_res: Dictionary = phase.execute_phase(downed_party, downed_enemies, _expected_beat_1_intents())
	_check(downed_res == {"ok": false, "events": []}, "AC4: Shove targeting downed neighbor atomically rejects entire phase as {ok: false, events: []}")
	_check(downed_party.get_heroes() == heroes_snapshot, "AC4: Rejected phase leaves party completely unmutated")
	_check(downed_enemies.get_enemies() == enemies_snapshot, "AC4: Rejected phase leaves enemies completely unmutated")
	_check(local_test_rng.state == test_rng_state_before, "AC4: Rejected phase leaves RNG snapshot unmutated")
