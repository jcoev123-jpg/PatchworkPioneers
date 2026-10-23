extends SceneTree
const WEIGHTED = preload("res://tests/weighted_roster_assert.gd")

## Deterministic headless coverage for the authored Spindle Rear Tag M03 Fight
## encounter: slot 1 Button Guard shoves hero position 2 toward rear (+1), then
## gains 3 Block, then attacks front for 4; slot 2 Spool Stalker inflicts
## Exposed 1 on rear position 3, then attacks rear position 3 for base 3, then
## buffs for 2 Block. Data/service layer only: no typed-pool or live wiring is
## read or modified here.

const ENCOUNTER_PATH := "res://data/encounters/spindle_rear_tag.json"
const ENCOUNTER_ID := "spindle_rear_tag"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const HEM_SNARE_PATH := "res://data/encounters/two_needle_hem_snare.json"

const HERO_SPECS := [
	{"id": "warden", "name": "Warden", "max_hp": 40, "art_path": "res://assets/paper/heroes/warden.png"},
	{"id": "seamstress", "name": "Seamstress", "max_hp": 30, "art_path": "res://assets/paper/heroes/seamstress.png"},
	{"id": "tinker", "name": "Tinker", "max_hp": 26, "art_path": "res://assets/paper/heroes/tinker.png"},
]

const ENEMY_SPECS := [
	{"id": "button_guard", "name": "Button Guard", "max_hp": 16, "art_path": "res://assets/paper/enemies/button_guard.png"},
	{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14, "art_path": "res://assets/paper/enemies/spool_stalker.png"},
]

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_catalog()
	_test_companion_schedules_still_valid()
	_test_intent_cycle()
	_test_three_phase_real_execution()
	_test_slain_shover_skips_movement()
	_test_downed_shove_participant_rejects_phase()
	_test_parser_and_validator_rejections()
	_test_double_fixture_replay()
	if failures.is_empty():
		print("spindle_rear_tag_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("spindle_rear_tag_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "buff", "amount": 2}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1,
			"enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed",
			"enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2}]


## Literal resolution events through the real phase services.
func _first_events() -> Array:
	return [
		{"type": "shove", "enemy_position": 1, "applied": true,
			"target_position": 2, "direction": 1},
		{"type": "debuff", "enemy_position": 2, "applied": true,
			"target_position": 3, "status": "exposed"}]


func _second_events() -> Array:
	return [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3}]


func _third_events() -> Array:
	return [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 1},
		{"type": "buff", "enemy_position": 2, "applied": true}]


## Explicit literal actor snapshots after opening Block and after each beat.
func _expected_heroes_opening() -> Array[Dictionary]:
	return [
		{"id": "warden", "name": "Warden", "max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1, "hp": 40, "block": 6},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 2, "hp": 30, "block": 0},
		{"id": "tinker", "name": "Tinker", "max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 3, "hp": 26, "block": 0},
	]


func _expected_heroes_beat_1() -> Array[Dictionary]:
	return [
		{"id": "warden", "name": "Warden", "max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1, "hp": 40, "block": 6},
		{"id": "tinker", "name": "Tinker", "max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 2, "hp": 26, "block": 0},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 3, "hp": 30, "block": 0, "statuses": {"exposed": 1}},
	]


func _expected_heroes_beat_2() -> Array[Dictionary]:
	return [
		{"id": "warden", "name": "Warden", "max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1, "hp": 40, "block": 6},
		{"id": "tinker", "name": "Tinker", "max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 2, "hp": 26, "block": 0},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 3, "hp": 26, "block": 0, "statuses": {"exposed": 1}},
	]


func _expected_heroes_beat_3() -> Array[Dictionary]:
	return [
		{"id": "warden", "name": "Warden", "max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1, "hp": 40, "block": 2},
		{"id": "tinker", "name": "Tinker", "max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 2, "hp": 26, "block": 0},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 3, "hp": 26, "block": 0, "statuses": {"exposed": 1}},
	]


func _expected_enemies_with_block(block_1: int, block_2: int) -> Array[Dictionary]:
	return [
		{"id": "button_guard", "name": "Button Guard", "max_hp": 16,
			"art_path": "res://assets/paper/enemies/button_guard.png",
			"position": 1, "hp": 16, "block": block_1},
		{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14,
			"art_path": "res://assets/paper/enemies/spool_stalker.png",
			"position": 2, "hp": 14, "block": block_2},
	]


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Normalize whole-number JSON floats to ints after verifying integrality.
func _load_records(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	_check(parsed is Array and not parsed.is_empty(), "catalog parses as a non-empty Array: " + path)
	if not parsed is Array:
		return []
	var records: Array = []
	for entry in parsed:
		if not entry is Dictionary or not entry.has("max_hp"):
			return []
		var record: Dictionary = entry.duplicate(true)
		var hp: Variant = record["max_hp"]
		if hp is float:
			if is_nan(hp) or is_inf(hp) or hp <= 0 or hp > 9007199254740991.0 \
					or floorf(hp) != hp:
				return []
			record["max_hp"] = int(hp)
		elif not hp is int or hp <= 0:
			return []
		records.append(record)
	return records


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


## Locate one entry by enemy_position without assuming list order or shared catalog counts.
func _unique_entry(entries: Array, position: int) -> Dictionary:
	var matches: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("enemy_position") == position:
			matches.append(entry)
	_check(matches.size() == 1, "exactly one entry at enemy_position %d" % position)
	return {} if matches.is_empty() else matches[0]


func _check_entry(entries: Array, position: int, expected_actions: Array) -> void:
	var entry := _unique_entry(entries, position)
	_check(entry.size() == 2 and entry.has("enemy_position") and entry.has("pattern"),
		"entry %d has exactly enemy_position and pattern" % position)
	var pattern = entry.get("pattern")
	_check(pattern is Array and pattern.size() == expected_actions.size(),
		"entry %d has exactly %d actions" % [position, expected_actions.size()])
	if not pattern is Array or pattern.size() != expected_actions.size():
		return
	for index in range(expected_actions.size()):
		_check(pattern[index] == expected_actions[index],
			"entry %d beat %d is exactly %s" % [position, index + 1,
				JSON.stringify(expected_actions[index])])


func _check_hero(party: CombatParty, position: int, id: String, name: String,
		hp: int, max_hp: int, block: int, statuses: Dictionary, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("id") == id and hero.get("name") == name
		and hero.get("position") == position
		and hero.get("hp") == hp and hero.get("max_hp") == max_hp
		and hero.get("block") == block
		and hero.get("statuses", {}) == statuses,
		"%s: hero %d is %s (%s) at %d/%d HP, %d Block, %s (got %s)"
			% [label, position, id, name, hp, max_hp, block, statuses, JSON.stringify(hero)])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, name: String,
		hp: int, max_hp: int, block: int, label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("name") == name
		and enemy.get("position") == position
		and enemy.get("hp") == hp and enemy.get("max_hp") == max_hp
		and enemy.get("block") == block
		and enemy.get("statuses", {}) == {},
		"%s: enemy %d is %s (%s) with %d/%d HP and %d Block (got %s)"
			% [label, position, id, name, hp, max_hp, block, JSON.stringify(enemy)])


func _record(records: Array, id: String, label: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "%s %s appears exactly once" % [label, id])
	return {} if matches.is_empty() else matches[0].duplicate(true)


func _build_party() -> CombatParty:
	var records := _load_records(PARTY_PATH)
	var definitions: Array = []
	for spec in HERO_SPECS:
		definitions.append(_record(records, spec["id"], "authored hero"))
	return CombatParty.new(definitions)


func _build_enemies() -> CombatEnemies:
	var records := _load_records(ENEMY_PATH)
	var definitions: Array = []
	for spec in ENEMY_SPECS:
		definitions.append(_record(records, spec["id"], "authored enemy"))
	return CombatEnemies.new(definitions)


## AC1: Existing Button Guard 16 HP and Spool Stalker 14 HP occupy sources 1/2;
## parser, validator and announcement/cycle inspection prove the exact schedule
## without assertions about shared catalog counts/order.
func _test_authored_schedule_and_catalog() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw := _read_text(ENCOUNTER_PATH)
	var raw_json: Variant = JSON.parse_string(raw)
	_check(raw_json is Array and raw_json.size() == 2,
		"the authored file holds this encounter's two source records")
	var parsed := _parsed()
	var expected := _expected()
	_check(parsed == expected, "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has two sources")
	var positions: Array[int] = []
	for entry in parsed:
		if entry is Dictionary and entry.get("enemy_position") is int:
			positions.append(entry["enemy_position"])
	positions.sort()
	_check(positions == [1, 2], "the parsed schedule has unique source positions 1 and 2")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() accepts the parsed schedule")
	_check_entry(parsed, 1, expected[0]["pattern"])
	_check_entry(parsed, 2, expected[1]["pattern"])

	# Verify integral coercion across enemy_position, amount, target_position, and direction.
	for entry in parsed:
		_check(entry.get("enemy_position") is int,
			"parsed enemy_position is an int, not a JSON float")
		var pattern: Array = entry["pattern"]
		_check(pattern.size() == 3,
			"source %d has the three-action cycle" % entry["enemy_position"])
		for action in pattern:
			_check(action.get("amount") is int,
				"parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"parsed beat target_position is an int, not a JSON float")
			if action.has("direction"):
				_check(action.get("direction") is int,
					"parsed beat direction is an int, not a JSON float")

	_check(parsed[0]["pattern"][0] == {"type": "shove", "amount": 0,
		"target_position": 2, "direction": 1},
		"Button Guard beat 1 is shove target 2 direction +1")
	_check(parsed[0]["pattern"][1] == {"type": "block", "amount": 3},
		"Button Guard beat 2 is block 3")
	_check(parsed[0]["pattern"][2] == {"type": "attack", "amount": 4, "target_position": 1},
		"Button Guard beat 3 is attack 4 on position 1")
	_check(parsed[1]["pattern"][0] == {"type": "debuff", "amount": 1,
		"target_position": 3, "status": "exposed"},
		"Spool Stalker beat 1 is Exposed 1 on position 3")
	_check(parsed[1]["pattern"][1] == {"type": "attack", "amount": 3, "target_position": 3},
		"Spool Stalker beat 2 is attack 3 on position 3")
	_check(parsed[1]["pattern"][2] == {"type": "buff", "amount": 2},
		"Spool Stalker beat 3 is buff 2")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"the literal prescription validates in CombatEnemyIntents")
	_check(_read_text(ENCOUNTER_PATH) == raw,
		"authored encounter file bytes remain untouched after validation")

	# Verify individual enemy definitions from run_enemies.json without checking catalog totals/order.
	var enemy_records := _load_records(ENEMY_PATH)
	var button_guard := _record(enemy_records, "button_guard", "authored enemy")
	var spool_stalker := _record(enemy_records, "spool_stalker", "authored enemy")
	_check(button_guard.get("id") == "button_guard"
		and button_guard.get("name") == "Button Guard"
		and button_guard.get("max_hp") == 16 and button_guard.get("max_hp") is int
		and button_guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"shipped button_guard is Button Guard with 16 int max_hp and preserved art_path")
	_check(spool_stalker.get("id") == "spool_stalker"
		and spool_stalker.get("name") == "Spool Stalker"
		and spool_stalker.get("max_hp") == 14 and spool_stalker.get("max_hp") is int
		and spool_stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
		"shipped spool_stalker is Spool Stalker with 14 int max_hp and preserved art_path")

	var enemies := _build_enemies()
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"authored two-enemy roster is valid")
	_check(WEIGHTED.project(enemies.get_enemies()) == _expected_enemies_with_block(0, 0),
		"constructed enemy roster matches Button Guard (slot 1, 16 HP) and Spool Stalker (slot 2, 14 HP)")
	_check_enemy(enemies, 1, "button_guard", "Button Guard", 16, 16, 0, "start")
	_check_enemy(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 0, "start")

	# Verify individual hero definitions from starter_party.json.
	var hero_records := _load_records(PARTY_PATH)
	for spec in HERO_SPECS:
		var hero_rec := _record(hero_records, spec["id"], "authored hero")
		_check(hero_rec.get("id") == spec["id"]
			and hero_rec.get("name") == spec["name"]
			and hero_rec.get("max_hp") == spec["max_hp"]
			and hero_rec.get("max_hp") is int
			and hero_rec.get("art_path") == spec["art_path"],
			"shipped hero %s is %s with %d int max_hp and preserved art_path"
				% [spec["id"], spec["name"], spec["max_hp"]])

	var party := _build_party()
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"shipped starter party builds a valid three-hero party")
	_check_hero(party, 1, "warden", "Warden", 40, 40, 0, {}, "start")
	_check_hero(party, 2, "seamstress", "Seamstress", 30, 30, 0, {}, "start")
	_check_hero(party, 3, "tinker", "Tinker", 26, 26, 0, {}, "start")

	# Verify snapshot isolation on party and enemies.
	var party_copy := party.get_heroes()
	party_copy[0]["hp"] = 1
	party_copy[1]["statuses"] = {"exposed": 9}
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("statuses", {}) == {},
		"mutating returned party snapshot does not alter live party")
	var enemies_copy := enemies.get_enemies()
	enemies_copy[0]["block"] = 99
	_check(enemies.get_enemy(1).get("block") == 0,
		"mutating returned enemy snapshot does not alter live enemies")


## Existing companion schedules remain valid, checked by their own source slots.
func _test_companion_schedules_still_valid() -> void:
	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
	_check_entry(starter, 1, [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3}])
	_check_entry(starter, 2, [{"type": "block", "amount": 1}])
	_check(CombatEnemyIntents.new(starter).is_valid(),
		"starter_attacks.json still validates in CombatEnemyIntents")

	var snare := RunFightEncounterSelection._parse_schedule_text(_read_text(HEM_SNARE_PATH))
	_check_entry(snare, 1, [
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"},
		{"type": "attack", "amount": 2, "target_position": 2},
		{"type": "block", "amount": 2}])
	_check_entry(snare, 2, [
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "attack", "amount": 2, "target_position": 1}])
	_check(CombatEnemyIntents.new(snare).is_valid(),
		"two_needle_hem_snare.json still validates in CombatEnemyIntents")


## AC1/AC3: three announced beats in ascending source order, then exact wraparound,
## with independent returned snapshots and zero RNG usage.
func _test_intent_cycle() -> void:
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "parsed schedule builds a valid CombatEnemyIntents")
	_check(intents.get_intents() == _first_intents(), "beat 1 announces shove + exposed debuff")
	_check(intents.get_intents() == _first_intents(),
		"repeated get_intents() calls do not advance the cycle")
	_check(intents._turn_index == 0, "turn_index remains 0 before advance_turn()")

	var mutated := intents.get_intents()
	mutated[0]["type"] = "block"
	mutated[0]["amount"] = 99
	mutated.append({"enemy_position": 3, "type": "buff", "amount": 5})
	_check(intents.get_intents() == _first_intents() and intents._turn_index == 0,
		"mutating returned intents array cannot alter subsequent announcements")

	var expected_cycle: Array = [
		_first_intents(), _second_intents(), _third_intents(),
		_first_intents(), _second_intents(), _third_intents()]
	for step in range(expected_cycle.size()):
		var announced := intents.get_intents()
		_check(announced == expected_cycle[step],
			"cycle step %d announces exact expected intents" % (step + 1))
		_check(announced.size() == 2
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"cycle step %d orders source 1 before source 2" % (step + 1))
		_check(intents._turn_index == step,
			"cycle step %d has _turn_index == %d" % [step + 1, step])
		_check(intents.advance_turn(), "advance_turn() succeeds at step %d" % (step + 1))

	_check(definitions == _expected(), "schedule definitions array was not mutated by cycling")

	# Verify zero global RNG consumption across construction, announcement, and advancement.
	seed(20261022)
	var expected_global := randi()
	seed(20261022)
	var probe := CombatEnemyIntents.new(_parsed())
	for turn in range(6):
		probe.get_intents()
		probe.advance_turn()
	_check(randi() == expected_global,
		"CombatEnemyIntents cycle consumes no global RNG")
	seed(20261022)
	var control_draw := randi()
	seed(20261022)
	randi()
	_check(randi() != control_draw, "global RNG probe detects an extra draw")


## AC2 & AC3: Execute all three beats in sequence through CombatStartingBlock and
## CombatEnemyPhase without intervening owner-turn ticks or player-turn Block resets.
func _test_three_phase_real_execution() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	var warden_ref: Dictionary = party._heroes[0]
	var seamstress_ref: Dictionary = party._heroes[1]
	var tinker_ref: Dictionary = party._heroes[2]

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "CombatStartingBlock grants Warden 6 Block once")
	_check(not opening.apply(), "CombatStartingBlock refuses a second apply()")
	_check(party.get_heroes() == _expected_heroes_opening(),
		"opening party snapshot is Warden 40/6, Seamstress 30/0, Tinker 26/0")
	_check(WEIGHTED.project(enemies.get_enemies()) == _expected_enemies_with_block(0, 0),
		"opening enemy snapshot is Button Guard 16/0, Spool Stalker 14/0")

	# Verify Exposed math directly: base 3 with Exposed 1 is floor(3 * 1.5) = 4.
	_check(CombatStatuses.new().adjusted_attack_damage(3, {}, {"exposed": 1}) == 4,
		"Exposed 1 increases base 3 attack damage to floor(4.5) = 4")

	var scheduler := CombatEnemyIntents.new(_parsed())
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var rng_before := rng.state
	seed(20261022)
	var expected_global := randi()
	seed(20261022)

	# --- BEAT 1 (AC2) ---
	var intents_1: Array = scheduler.get_intents()
	var intents_1_copy: Array = intents_1.duplicate(true)
	_check(intents_1 == _first_intents(),
		"AC2: beat 1 announces Button Guard shove (2, +1) and Spool Stalker Exposed 1 on slot 3")
	var result_1 := phase.execute_phase(party, enemies, intents_1)
	_check(result_1 == {"ok": true, "events": _first_events()},
		"AC2: beat 1 resolves shove then Exposed debuff in ascending source order")
	_check(intents_1 == intents_1_copy and scheduler._turn_index == 0
		and scheduler.get_intents() == _first_intents(),
		"AC2: beat 1 execution does not mutate caller intents or advance scheduler")
	_check(party.get_heroes() == _expected_heroes_beat_1(),
		"AC2: after beat 1, Tinker is at slot 2 (26/0, no status) and Seamstress is at slot 3 (30/0, Exposed 1)")
	_check_hero(party, 1, "warden", "Warden", 40, 40, 6, {}, "AC2 beat 1")
	_check_hero(party, 2, "tinker", "Tinker", 26, 26, 0, {}, "AC2 beat 1")
	_check_hero(party, 3, "seamstress", "Seamstress", 30, 30, 0, {"exposed": 1}, "AC2 beat 1")
	_check(WEIGHTED.project(enemies.get_enemies()) == _expected_enemies_with_block(0, 0),
		"AC2: both enemies remain at 16/0 and 14/0 after beat 1")
	_check(is_same(party._heroes[0], warden_ref)
		and is_same(party._heroes[1], tinker_ref)
		and is_same(party._heroes[2], seamstress_ref),
		"AC2: shove preserves original live hero dictionary references in new slots")
	_check(rng.state == rng_before, "AC2: beat 1 leaves seeded RNG state unchanged")

	# --- BEAT 2 (AC3) ---
	_check(scheduler.advance_turn() and scheduler._turn_index == 1,
		"AC3: caller advances scheduler to beat 2")
	var intents_2: Array = scheduler.get_intents()
	var intents_2_copy: Array = intents_2.duplicate(true)
	_check(intents_2 == _second_intents(),
		"AC3: beat 2 announces Button Guard Block 3 and Spool Stalker attack 3 on slot 3")
	var result_2 := phase.execute_phase(party, enemies, intents_2)
	_check(result_2 == {"ok": true, "events": _second_events()},
		"AC3: beat 2 resolves Button Guard Block 3 then Spool Stalker attack on slot 3")
	_check(intents_2 == intents_2_copy and scheduler._turn_index == 1,
		"AC3: beat 2 execution does not mutate caller intents or advance scheduler")
	_check(party.get_heroes() == _expected_heroes_beat_2(),
		"AC3: after beat 2, exposed rear Seamstress loses 4 HP (30 -> 26) and keeps Exposed 1")
	_check_hero(party, 1, "warden", "Warden", 40, 40, 6, {}, "AC3 beat 2")
	_check_hero(party, 2, "tinker", "Tinker", 26, 26, 0, {}, "AC3 beat 2")
	_check_hero(party, 3, "seamstress", "Seamstress", 26, 30, 0, {"exposed": 1}, "AC3 beat 2")
	_check(WEIGHTED.project(enemies.get_enemies()) == _expected_enemies_with_block(3, 0),
		"AC3: after beat 2, Button Guard has 16 HP / 3 Block and Spool Stalker has 14 HP / 0 Block")
	_check_enemy(enemies, 1, "button_guard", "Button Guard", 16, 16, 3, "AC3 beat 2")
	_check_enemy(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 0, "AC3 beat 2")
	_check(rng.state == rng_before, "AC3: beat 2 leaves seeded RNG state unchanged")

	# --- BEAT 3 & WRAP (AC3) ---
	_check(scheduler.advance_turn() and scheduler._turn_index == 2,
		"AC3: caller advances scheduler to beat 3")
	var intents_3: Array = scheduler.get_intents()
	var intents_3_copy: Array = intents_3.duplicate(true)
	_check(intents_3 == _third_intents(),
		"AC3: beat 3 announces Button Guard attack 4 on slot 1 and Spool Stalker buff 2")
	var result_3 := phase.execute_phase(party, enemies, intents_3)
	_check(result_3 == {"ok": true, "events": _third_events()},
		"AC3: beat 3 resolves front attack 4 then Spool Stalker self-buff 2")
	_check(intents_3 == intents_3_copy and scheduler._turn_index == 2,
		"AC3: beat 3 execution does not mutate caller intents or advance scheduler")
	_check(party.get_heroes() == _expected_heroes_beat_3(),
		"AC3: after beat 3, Warden's 6 opening Block absorbs 4 damage leaving 2 Block and 40 HP")
	_check_hero(party, 1, "warden", "Warden", 40, 40, 2, {}, "AC3 beat 3")
	_check_hero(party, 2, "tinker", "Tinker", 26, 26, 0, {}, "AC3 beat 3")
	_check_hero(party, 3, "seamstress", "Seamstress", 26, 30, 0, {"exposed": 1}, "AC3 beat 3")
	_check(WEIGHTED.project(enemies.get_enemies()) == _expected_enemies_with_block(3, 2),
		"AC3: after beat 3, Button Guard has 16 HP / 3 Block and Spool Stalker has 14 HP / 2 Block")
	_check_enemy(enemies, 1, "button_guard", "Button Guard", 16, 16, 3, "AC3 beat 3")
	_check_enemy(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 2, "AC3 beat 3")

	_check(scheduler.advance_turn() and scheduler._turn_index == 3
		and scheduler.get_intents() == _first_intents(),
		"AC3: advancing after beat 3 wraps announcements back to beat 1")
	_check(randi() == expected_global and rng.state == rng_before,
		"AC2/AC3: full three-beat execution consumes no global or seeded RNG")

	# Verify that owner-turn status aging is a separate service (CombatStatusTurnBatch)
	# and was NOT performed by CombatEnemyPhase.
	var party_after_beat_3 := party.get_heroes()
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(tick.get("ok") == true
		and tick.get("actors", [])[2].get("id") == "seamstress"
		and tick.get("actors", [])[2].get("hp") == 26
		and tick.get("actors", [])[2].get("statuses", {}) == {},
		"detached owner-turn tick ages Seamstress's Exposed 1 -> 0 without HP loss")
	_check(party.get_heroes() == party_after_beat_3,
		"detached owner-turn tick does not mutate authoritative CombatParty")


## AC4: Slain shover before beat 1 skips movement while living Spool Stalker
## marks the unshifted rear Tinker at position 3.
func _test_slain_shover_skips_movement() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"slain-shover fixture applies Warden opening Block 6")
	_check(enemies.apply_damage(1, 16) and enemies.is_slain(1)
		and enemies.get_enemy(1).get("hp") == 0
		and not enemies.is_slain(2) and enemies.get_enemy(2).get("hp") == 14,
		"AC4 precondition: real enemies.apply_damage(1, 16) slays Button Guard while Spool Stalker lives")
	var slain_guard_before: Dictionary = enemies.get_enemy(1)
	var scheduler := CombatEnemyIntents.new(_parsed())
	var intents: Array = scheduler.get_intents()
	var intents_before: Array = intents.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var rng_before := rng.state
	seed(20261022)
	var expected_global := randi()
	seed(20261022)

	var result := phase.execute_phase(party, enemies, intents)
	_check(randi() == expected_global and rng.state == rng_before,
		"AC4: slain-shover beat 1 consumes no global or seeded RNG")
	_check(result == {"ok": true, "events": [
		{"type": "shove", "enemy_position": 1, "applied": false,
			"target_position": 2, "direction": 1},
		{"type": "debuff", "enemy_position": 2, "applied": true,
			"target_position": 3, "status": "exposed"}]},
		"AC4: slain Button Guard skips shove (applied: false) and living Spool Stalker applies Exposed 1")
	_check_hero(party, 1, "warden", "Warden", 40, 40, 6, {}, "AC4 slain shover beat 1")
	_check_hero(party, 2, "seamstress", "Seamstress", 30, 30, 0, {}, "AC4 slain shover beat 1")
	_check_hero(party, 3, "tinker", "Tinker", 26, 26, 0, {"exposed": 1}, "AC4 slain shover beat 1")
	_check(enemies.get_enemy(1) == slain_guard_before and enemies.is_slain(1),
		"AC4: slain Button Guard remains at position 1 with 0 HP / 0 Block")
	_check_enemy(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 0, "AC4 slain shover beat 1")
	_check(intents == intents_before and scheduler._turn_index == 0,
		"AC4: slain-shover phase leaves caller intents and scheduler turn_index untouched")

	# Follow up with beat 2 on the same slain-shover fixture: slain Button Guard skips
	# Block 3, while living Spool Stalker attacks Exposed Tinker at position 3 for 4 (26 -> 22 HP).
	_check(scheduler.advance_turn(), "advance slain-shover fixture to beat 2")
	var result_2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result_2 == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3}]},
		"AC4: in beat 2, slain Button Guard skips Block while living Stalker hits rear Tinker")
	_check_hero(party, 2, "seamstress", "Seamstress", 30, 30, 0, {}, "AC4 slain shover beat 2")
	_check_hero(party, 3, "tinker", "Tinker", 22, 26, 0, {"exposed": 1}, "AC4 slain shover beat 2")
	_check(enemies.get_enemy(1) == slain_guard_before,
		"AC4: slain Button Guard gains no Block on beat 2")


## AC4: Downed shove participant (either slot 2 Seamstress or slot 3 Tinker)
## rejects the entire beat atomically with no move, no Exposed, and no RNG change.
func _test_downed_shove_participant_rejects_phase() -> void:
	for downed_slot in [2, 3]:
		var party := _build_party()
		var enemies := _build_enemies()
		_check(CombatStartingBlock.new(party).apply(),
			"downed-slot-%d fixture applies Warden opening Block 6" % downed_slot)
		var lethal_hp: int = party.get_hero(downed_slot).get("hp", 0)
		_check(party.apply_damage(downed_slot, lethal_hp) and party.is_downed(downed_slot)
			and party.get_hero(downed_slot).get("hp") == 0,
			"AC4 precondition: real party.apply_damage downs shove participant at slot %d" % downed_slot)
		var party_before: Array = party.get_heroes()
		var enemies_before: Array = enemies.get_enemies()
		var scheduler := CombatEnemyIntents.new(_parsed())
		var intents: Array = scheduler.get_intents()
		var intents_before: Array = intents.duplicate(true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261022
		var rng_before := rng.state
		seed(20261022)
		var expected_global := randi()
		seed(20261022)

		var result := phase.execute_phase(party, enemies, intents)
		_check(randi() == expected_global and rng.state == rng_before,
			"AC4: rejected phase with downed slot %d consumes no global or seeded RNG" % downed_slot)
		_check(result == {"ok": false, "events": []},
			"AC4: downed shove participant at slot %d rejects the entire phase atomically" % downed_slot)
		_check(party.get_heroes() == party_before,
			"AC4: rejected phase with downed slot %d leaves all hero positions, HP, Block and statuses unchanged"
				% downed_slot)
		_check(party.get_hero(2).get("id") == "seamstress"
			and party.get_hero(3).get("id") == "tinker"
			and party.get_hero(2).get("statuses", {}) == {}
			and party.get_hero(3).get("statuses", {}) == {},
			"AC4: neither Seamstress nor Tinker moves or receives Exposed when slot %d is downed"
				% downed_slot)
		_check(enemies.get_enemies() == enemies_before,
			"AC4: rejected phase with downed slot %d leaves enemy roster unchanged" % downed_slot)
		_check(intents == intents_before and scheduler._turn_index == 0
			and scheduler.get_intents() == _first_intents(),
			"AC4: rejected phase leaves caller intents and scheduler untouched")

	# Late-source rollback check: when source 1 stages a legal shove on living slots 1 & 2,
	# and source 2 attempts to apply Exposed 1 to downed Tinker at slot 3, the entire
	# phase rejects atomically and rolls back source 1's staged shove!
	var rollback_party := _build_party()
	var rollback_enemies := _build_enemies()
	_check(CombatStartingBlock.new(rollback_party).apply(),
		"late-rollback fixture applies Warden opening Block 6")
	_check(rollback_party.apply_damage(3, 26) and rollback_party.is_downed(3),
		"late-rollback precondition: rear Tinker is downed while slots 1 & 2 live")
	var rollback_party_before: Array = rollback_party.get_heroes()
	var rollback_enemies_before: Array = rollback_enemies.get_enemies()
	var staged_then_invalid: Array = [
		{"type": "shove", "amount": 0, "target_position": 1, "direction": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed", "enemy_position": 2}]
	var staged_copy: Array = staged_then_invalid.duplicate(true)
	var rollback_result := phase.execute_phase(rollback_party, rollback_enemies, staged_then_invalid)
	_check(rollback_result == {"ok": false, "events": []}
		and rollback_party.get_heroes() == rollback_party_before
		and rollback_enemies.get_enemies() == rollback_enemies_before
		and staged_then_invalid == staged_copy,
		"AC4: late debuff on downed slot 3 rolls back earlier staged shove on slots 1 & 2")

	# Positive control: when non-participant Warden at slot 1 is downed, beat 1 still succeeds!
	var control_party := _build_party()
	var control_enemies := _build_enemies()
	_check(CombatStartingBlock.new(control_party).apply(),
		"control fixture applies Warden opening Block 6")
	_check(control_party.apply_damage(1, 46) and control_party.is_downed(1),
		"control precondition: front Warden is downed while middle/rear shove participants live")
	var control_result := phase.execute_phase(
		control_party, control_enemies, CombatEnemyIntents.new(_parsed()).get_intents())
	_check(control_result == {"ok": true, "events": _first_events()},
		"control: beat 1 succeeds when the downed hero (slot 1) is not a shove/debuff participant")
	_check_hero(control_party, 1, "warden", "Warden", 0, 40, 0, {}, "control beat 1")
	_check_hero(control_party, 2, "tinker", "Tinker", 26, 26, 0, {}, "control beat 1")
	_check_hero(control_party, 3, "seamstress", "Seamstress", 30, 30, 0, {"exposed": 1}, "control beat 1")


func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC4: Validate malformed LOCAL COPIES (duplicate source, illegal shove destination,
## illegal debuff status, etc.) while original valid file and restored controls pass.
func _test_parser_and_validator_rejections() -> void:
	var pristine := _read_text(ENCOUNTER_PATH)

	var duplicate_source := _expected().duplicate(true)
	duplicate_source[1]["enemy_position"] = 1

	var illegal_shove_high := _with_beat(1, 0,
		{"type": "shove", "amount": 0, "target_position": 3, "direction": 1})
	var illegal_shove_low := _with_beat(1, 0,
		{"type": "shove", "amount": 0, "target_position": 1, "direction": -1})
	var illegal_shove_amount := _with_beat(1, 0,
		{"type": "shove", "amount": 1, "target_position": 2, "direction": 1})
	var illegal_debuff_status := _with_beat(2, 0,
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "poison"})
	var illegal_debuff_zero := _with_beat(2, 0,
		{"type": "debuff", "amount": 0, "target_position": 3, "status": "exposed"})

	var cases: Array = [
		{
			"label": "duplicate enemy_position 1",
			"data": duplicate_source,
			"control": _expected(),
		},
		{
			"label": "illegal shove destination 3 + 1 = 4",
			"data": illegal_shove_high,
			"control": _with_beat(1, 0,
				{"type": "shove", "amount": 0, "target_position": 3, "direction": -1}),
		},
		{
			"label": "illegal shove destination 1 + (-1) = 0",
			"data": illegal_shove_low,
			"control": _with_beat(1, 0,
				{"type": "shove", "amount": 0, "target_position": 1, "direction": 1}),
		},
		{
			"label": "nonzero shove amount 1",
			"data": illegal_shove_amount,
			"control": _expected(),
		},
		{
			"label": "illegal debuff status poison",
			"data": illegal_debuff_status,
			"control": _with_beat(2, 0,
				{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"}),
		},
		{
			"label": "zero debuff amount 0",
			"data": illegal_debuff_zero,
			"control": _expected(),
		},
	]

	for entry_case in cases:
		var data: Array = entry_case["data"]
		var untouched: Array = data.duplicate(true)
		_check(data != _expected(),
			"AC4 negative: %s differs from the valid schedule" % entry_case["label"])
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(data)).is_empty(),
			"AC4 negative: %s is rejected by RunFightEncounterSelection._parse_schedule_text"
				% entry_case["label"])
		_check(data == untouched,
			"AC4 negative: parser rejection does not mutate local copy for %s" % entry_case["label"])
		var intents := CombatEnemyIntents.new(data)
		_check(not intents.is_valid() and intents.get_intents().is_empty(),
			"AC4 negative: %s is rejected by CombatEnemyIntents" % entry_case["label"])
		_check(data == untouched,
			"AC4 negative: CombatEnemyIntents rejection does not mutate local copy for %s"
				% entry_case["label"])

		var control: Array = entry_case["control"]
		_check(control != data,
			"AC4 control: %s control differs from rejected local copy" % entry_case["label"])
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(control)) == control,
			"AC4 control: %s with only the offending field restored parses" % entry_case["label"])
		_check(CombatEnemyIntents.new(control).is_valid(),
			"AC4 control: %s with only the offending field restored validates" % entry_case["label"])

	# Fractional float probes in JSON text (per LESSONS.md #20).
	for fractional_json in [
		'[{"enemy_position":1.5,"pattern":[{"type":"block","amount":3}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"block","amount":3.5}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"shove","amount":0,"target_position":2.5,"direction":1}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"shove","amount":0,"target_position":2,"direction":0.5}]}]',
		"{", "[]", "{}", "not json",
	]:
		_check(RunFightEncounterSelection._parse_schedule_text(fractional_json).is_empty(),
			"AC4 negative: non-integral or malformed JSON text is rejected: %s" % fractional_json)

	_check(_read_text(ENCOUNTER_PATH) == pristine,
		"AC4 negative control: on-disk spindle_rear_tag.json was never modified")
	_check(_parsed() == _expected() and CombatEnemyIntents.new(_parsed()).is_valid(),
		"AC4 negative control: original valid file still parses and validates")


func _run_seeded_replay(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rng_before := rng.state
	var party := _build_party()
	var enemies := _build_enemies()
	var opening_applied := CombatStartingBlock.new(party).apply()
	var opening_heroes := party.get_heroes()
	var opening_enemies := enemies.get_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())

	var announced: Array = []
	var results: Array = []
	var hero_snapshots: Array = []
	var enemy_snapshots: Array = []
	var turn_indices: Array = []

	for beat in range(3):
		turn_indices.append(scheduler._turn_index)
		var current_intents := scheduler.get_intents()
		announced.append(current_intents)
		results.append(phase.execute_phase(party, enemies, current_intents))
		hero_snapshots.append(party.get_heroes())
		enemy_snapshots.append(enemies.get_enemies())
		scheduler.advance_turn()

	return {
		"opening": opening_applied,
		"opening_heroes": opening_heroes,
		"opening_enemies": opening_enemies,
		"announced": announced,
		"results": results,
		"hero_snapshots": hero_snapshots,
		"enemy_snapshots": enemy_snapshots,
		"turn_indices": turn_indices,
		"wrapped_turn_index": scheduler._turn_index,
		"wrapped_announcement": scheduler.get_intents(),
		"rng_before": rng_before,
		"rng_after": rng.state,
	}


## AC5: Two fresh equal-seed fixtures produce identical complete announcement,
## event and actor-state traces AND match the explicit AC2/AC3 snapshots with no RNG drift.
func _test_double_fixture_replay() -> void:
	seed(20261022)
	var expected_global := randi()
	seed(20261022)
	var replay_a := _run_seeded_replay(20261022)
	var replay_b := _run_seeded_replay(20261022)
	_check(randi() == expected_global,
		"AC5: running two full three-beat replays consumes no global RNG")

	# Verify replay_a against explicit literal snapshots at every step first.
	_check(replay_a["opening"] == true,
		"AC5: replay fixture applies Warden opening Block 6 once")
	_check(replay_a["opening_heroes"] == _expected_heroes_opening()
		and WEIGHTED.project(replay_a["opening_enemies"]) == _expected_enemies_with_block(0, 0),
		"AC5: replay opening snapshots match explicit literal actors")
	_check(replay_a["announced"] == [_first_intents(), _second_intents(), _third_intents()],
		"AC5: replay announcements match all three literal beats")
	_check(replay_a["results"] == [
		{"ok": true, "events": _first_events()},
		{"ok": true, "events": _second_events()},
		{"ok": true, "events": _third_events()}],
		"AC5: replay phase results match all three literal event traces")
	_check(replay_a["hero_snapshots"] == [
		_expected_heroes_beat_1(),
		_expected_heroes_beat_2(),
		_expected_heroes_beat_3()],
		"AC5: replay hero snapshots match explicit AC2 (beat 1) and AC3 (beats 2-3) states")
	_check(WEIGHTED.project(replay_a["enemy_snapshots"]) == [
		_expected_enemies_with_block(0, 0),
		_expected_enemies_with_block(3, 0),
		_expected_enemies_with_block(3, 2)],
		"AC5: replay enemy snapshots match explicit AC2 (beat 1) and AC3 (beats 2-3) states")
	_check(replay_a["turn_indices"] == [0, 1, 2]
		and replay_a["wrapped_turn_index"] == 3
		and replay_a["wrapped_announcement"] == _first_intents(),
		"AC5: replay turn indices and wraparound announcement match explicit literals")
	_check(replay_a["rng_before"] == replay_a["rng_after"],
		"AC5: seeded RandomNumberGenerator state has zero drift across the replay")

	# Verify both independent equal-seed replays are identical across every trace field.
	_check(replay_a == replay_b,
		"AC5: two independent equal-seed fixtures produce identical complete traces and RNG states")
