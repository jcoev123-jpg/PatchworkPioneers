extends SceneTree

## Deterministic headless coverage for the authored Spool Snare Relay encounter:
## slot-1 Spool Stalker opens the front line with a delayed Exposed setup while
## slot-2 Button Guard punishes the back line with Weak, over a fixed three-beat
## cycle. Data/service only: this file never wires the encounter into live play.

const ENCOUNTER_PATH := "res://data/encounters/spool_snare_relay.json"
const ENCOUNTER_ID := "spool_snare_relay"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const RNG_SEED := 2026102167

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_intent_cycle_and_copies()
	_test_real_phase_sequence()
	_test_owner_turn_status_batch()
	_test_double_replay()
	_test_negative_rejections()
	if failures.is_empty():
		print("spool_snare_relay_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("spool_snare_relay_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 2, "target_position": 1, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "attack", "amount": 2, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak"},
			{"type": "block", "amount": 2}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "exposed",
			"enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak",
			"enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 3, "enemy_position": 1},
		{"type": "block", "amount": 2, "enemy_position": 2}]


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _load_json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		return []
	return _normalize_json(parsed)


## Godot's JSON parser yields whole numbers as floats; the real model services
## require ints for max_hp, so authored fixtures are normalized exactly.
func _normalize_json(data) -> Variant:
	if data is Array:
		var result: Array = []
		for item in data:
			result.append(_normalize_json(item))
		return result
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			var value = data[key]
			if value is float and value == int(value):
				value = int(value)
			else:
				value = _normalize_json(value)
			result[key] = value
		return result
	if data is float and data == int(data):
		return int(data)
	return data


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


## One source record, located by its own enemy_position (never by list order).
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
		"entry %d has a %d-beat cycle" % [position, expected_actions.size()])
	if not pattern is Array or pattern.size() != expected_actions.size():
		return
	for index in range(expected_actions.size()):
		_check(pattern[index] == expected_actions[index],
			"entry %d beat %d is exactly %s" % [position, index + 1,
				JSON.stringify(expected_actions[index])])


func _check_hero(party: CombatParty, position: int, hp: int, block: int, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("hp") == hp and hero.get("block") == block,
		"%s: hero %d has %d HP and %d Block (got %d/%d)"
			% [label, position, hp, block, hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


## Exactly one authored record per required stable ID, never a first-match lookup.
func _unique_by_id(entries: Array, id: String) -> Dictionary:
	var matches: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("id") == id:
			matches.append(entry)
	_check(matches.size() == 1, "exactly one catalog record: " + id)
	return {} if matches.is_empty() else matches[0].duplicate(true)


func _build_authored_party() -> CombatParty:
	var heroes := _load_json(PARTY_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var record := _unique_by_id(heroes, id)
		_check(record.get("max_hp") is int, "hero %s max_hp is an int after coercion" % id)
		definitions.append(record)
	return CombatParty.new(definitions)


func _build_authored_enemies() -> CombatEnemies:
	var enemies := _load_json(ENEMY_PATH)
	var definitions: Array = []
	for id in ["spool_stalker", "button_guard"]:
		var record := _unique_by_id(enemies, id)
		_check(record.get("max_hp") is int, "enemy %s max_hp is an int after coercion" % id)
		definitions.append(record)
	return CombatEnemies.new(definitions)


## AC1: the shipped file is exactly the prescribed two-source, three-beat schedule.
func _test_authored_schedule_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw: Variant = JSON.parse_string(_read_text(ENCOUNTER_PATH))
	_check(raw is Array and raw.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	var parsed := _parsed()
	_check(parsed == _expected(), "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has exactly two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, _expected()[0]["pattern"])
	_check_entry(parsed, 2, _expected()[1]["pattern"])
	# The canonical parser coerces every JSON whole number to a real int.
	for entry in parsed:
		_check(entry.get("enemy_position") is int,
			"parsed enemy_position is an int, not a JSON float")
		var pattern: Array = entry["pattern"]
		for action in pattern:
			_check(action.get("amount") is int,
				"parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"parsed beat target_position is an int, not a JSON float")

	# The reused normal enemies exist exactly once with their shipped stats and art references.
	var roster := _load_json(ENEMY_PATH)
	for expected_actor in [{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14},
			{"id": "button_guard", "name": "Button Guard", "max_hp": 16}]:
		var record := _unique_by_id(roster, expected_actor["id"])
		_check(record.get("name") == expected_actor["name"]
			and record.get("max_hp") == expected_actor["max_hp"],
			"shipped enemy %s is %s with %d max HP"
				% [expected_actor["id"], expected_actor["name"], expected_actor["max_hp"]])
		_check(record.get("art_path") is String and not String(record.get("art_path", "")).is_empty(),
			"shipped enemy %s keeps its existing art reference" % expected_actor["id"])

	var party := _build_authored_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")

	# This schedule is distinct from the other authored schedules, identified by their own data.
	var others := [
		"res://data/encounters/starter_attacks.json",
		"res://data/encounters/patchwork_behemoth.json",
		"res://data/encounters/exposed_hem_pincer.json"]
	for path in others:
		var other := RunFightEncounterSelection._parse_schedule_text(_read_text(path))
		_check(CombatEnemyIntents.new(other).is_valid(), "existing schedule still valid: " + path)
		_check(other != parsed, "spool_snare_relay differs from " + path)


## AC1: three announced beats in ascending source order, then an exact repeat,
## with no RNG consumption and no aliasing of caller data.
func _test_intent_cycle_and_copies() -> void:
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.get_intents() == _first_intents(), "beat 1 announces the exact first beats")
	_check(intents.advance_turn(), "advance to beat 2")
	_check(intents.get_intents() == _second_intents(), "beat 2 announces the exact second beats")
	_check(intents.advance_turn(), "advance to beat 3")
	_check(intents.get_intents() == _third_intents(), "beat 3 announces the exact third beats")
	_check(intents.advance_turn(), "advance past the third beat")
	_check(intents.get_intents() == _first_intents(),
		"beat 4 repeats the first announced intents exactly")

	# Announcements are always source-ordered, slot 1 before slot 2.
	for beat in range(4):
		var announced := intents.get_intents()
		_check(announced.size() == 2 and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"announcement %d lists slot 1 then slot 2" % (beat + 1))
		intents.advance_turn()

	# The whole fixed cycle, viewed and advanced, draws no global RNG.
	seed(20261021)
	var baseline := randi()
	seed(20261021)
	var probe := CombatEnemyIntents.new(definitions)
	for beat in range(7):
		probe.get_intents()
		probe.advance_turn()
	_check(randi() == baseline, "constructing, viewing and advancing this schedule draws no global RNG")
	seed(20261021)
	var without_extra := randi()
	seed(20261021)
	randi()
	_check(randi() != without_extra, "the global RNG probe detects an injected extra draw")

	# Returned announcements and the parsed source cannot alias the selector's state.
	var snapshot_selector := CombatEnemyIntents.new(_expected().duplicate(true))
	var snapshot := snapshot_selector.get_intents()
	_check(snapshot == _first_intents(), "snapshot is the exact first announced beats")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(snapshot_selector.get_intents() == _first_intents(),
		"mutating a returned announcement cannot alter later intents")
	_check(definitions == _expected(), "parsed schedule starts from its prescribed source")
	var isolated := CombatEnemyIntents.new(definitions)
	var parsed_pattern: Array = definitions[0]["pattern"]
	parsed_pattern[0]["amount"] = 7
	_check(isolated.get_intents() == _first_intents(),
		"mutating the parsed source cannot alter an independently constructed intent selector")


## AC2: the authored beats resolve through the real services against the real
## party and roster in an ISOLATED three-phase fixture: one advance_turn between
## beats and deliberately no interleaved player turns (no Block reset, no owner
## status ticking between these phases).
func _test_real_phase_sequence() -> void:
	var roster_catalog := _load_json(ENEMY_PATH)
	var roster_snapshot := roster_catalog.duplicate(true)
	var party_catalog := _load_json(PARTY_PATH)
	var party_snapshot := party_catalog.duplicate(true)
	var definitions := _parsed()
	var definitions_snapshot := definitions.duplicate(true)

	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"hero IDs are exactly warden/seamstress/tinker at slots 1/2/3")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "start")
	_check_enemy(enemies, 2, "button_guard", 16, 0, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, 40, 6, "opening")
	_check(not opening.apply(), "opening Block cannot be applied twice")

	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.get_intents() == _first_intents(), "beat 1 announces Exposed then attack")

	# Beat 1: slot 1 Exposed 2 on Warden; slot 2 attack 2 -> Seamstress 30 -> 28.
	var beat1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(beat1.get("ok") == true, "beat 1 phase succeeds")
	_check(beat1.get("events") == [
		{"type": "debuff", "enemy_position": 1, "target_position": 1, "status": "exposed",
			"applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		"beat 1 events: slot-1 Exposed then slot-2 attack, both applied")
	_check(scheduler.get_intents() == _first_intents(),
		"phase execution never advances the scheduler on its own")
	_check_hero(party, 1, 40, 6, "beat 1")
	_check_hero(party, 2, 28, 0, "beat 1")
	_check_hero(party, 3, 26, 0, "beat 1")
	_check(party.get_hero(1).get("statuses", {}) == {"exposed": 2},
		"beat 1 Warden carries exactly Exposed 2")
	_check(party.get_hero(2).get("statuses", {}) == {} and party.get_hero(3).get("statuses", {}) == {},
		"beat 1 only the debuffed hero carries a status")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "beat 1")
	_check_enemy(enemies, 2, "button_guard", 16, 0, "beat 1")

	_check(scheduler.advance_turn(), "explicit advance to beat 2")

	# Beat 2: slot 1 attack 3 into Exposed 2 -> floor(3 * 1.5) = 4; Block 6 -> 2, HP stays 40.
	# Slot 2 Weak 2 on Tinker.
	var beat2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(beat2.get("ok") == true, "beat 2 phase succeeds")
	_check(beat2.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 3, "status": "weak",
			"applied": true}],
		"beat 2 events: slot-1 exposed-boosted attack then slot-2 Weak, both applied")
	_check(scheduler.get_intents() == _second_intents(),
		"phase execution never advances the scheduler on its own")
	_check_hero(party, 1, 40, 2, "beat 2")
	_check_hero(party, 2, 28, 0, "beat 2")
	_check_hero(party, 3, 26, 0, "beat 2")
	_check(party.get_hero(1).get("statuses", {}) == {"exposed": 2},
		"beat 2 Warden still carries Exposed 2: the isolated ledger ticks no owner turns")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 2},
		"beat 2 Tinker carries exactly Weak 2")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "beat 2")
	_check_enemy(enemies, 2, "button_guard", 16, 0, "beat 2")

	_check(scheduler.advance_turn(), "explicit advance to beat 3")

	# Beat 3: slot 1 attack 2 -> Tinker 26 -> 24 (Weak never reduces incoming damage);
	# slot 2 block 2 grants Button Guard 2 Block.
	var beat3 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(beat3.get("ok") == true, "beat 3 phase succeeds")
	_check(beat3.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true}],
		"beat 3 events: slot-1 back-line attack then slot-2 self Block, both applied")
	_check(scheduler.get_intents() == _third_intents(),
		"phase execution never advances the scheduler on its own")
	_check_hero(party, 1, 40, 2, "beat 3")
	_check_hero(party, 2, 28, 0, "beat 3")
	_check_hero(party, 3, 24, 0, "beat 3")
	_check(party.get_hero(1).get("statuses", {}) == {"exposed": 2},
		"beat 3 Warden still carries exactly Exposed 2")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 2},
		"beat 3 Tinker still carries exactly Weak 2")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "beat 3")
	_check_enemy(enemies, 2, "button_guard", 16, 2, "beat 3")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(2).get("hp") == 16,
		"neither enemy's HP changes over the whole relay")

	_check(scheduler.advance_turn(), "explicit advance past the third beat")
	_check(scheduler.get_intents() == _first_intents(),
		"after exactly three advances the schedule announces its first beats again")

	# The authored schedule and both shared catalogs are untouched by the fixture.
	_check(definitions == definitions_snapshot,
		"the parsed schedule records are unchanged by intent construction and phase execution")
	_check(_load_json(ENEMY_PATH) == roster_snapshot and roster_catalog == roster_snapshot,
		"the shared normal-enemy catalog records are unchanged by the fixture")
	_check(_load_json(PARTY_PATH) == party_snapshot and party_catalog == party_snapshot,
		"the shared starter-party catalog records are unchanged by the fixture")


## AC3: owner-turn status aging and the pure damage floors, asserted SEPARATELY from
## the isolated three-beat ledger above (which deliberately ticks no owner turns).
func _test_owner_turn_status_batch() -> void:
	var party := _build_authored_party()
	_check(CombatStartingBlock.new(party).apply(), "status-batch precondition: Warden Block 6")
	var heroes := party.get_heroes()
	for hero in heroes:
		hero["statuses"] = {"exposed": 2, "weak": 2}
	var original := heroes.duplicate(true)
	var hp_block_before: Array = []
	for hero in heroes:
		hp_block_before.append([hero["hp"], hero["block"]])

	var batch := CombatStatusTurnBatch.new()
	var first := batch.tick_side("heroes", heroes)
	_check(first.get("ok") == true, "owner-turn tick 1 succeeds")
	var after_first: Array = first.get("actors", [])
	_check(after_first.size() == CombatParty.PARTY_SIZE, "tick 1 returns the full party")
	var tick_events: Array = first.get("events", [])
	_check(tick_events == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0}],
		"tick 1 events name the exact hero IDs at their exact slots, with no Bleed loss")
	for index in range(after_first.size()):
		var actor: Dictionary = after_first[index]
		_check(actor.get("statuses", {}) == {"exposed": 1, "weak": 1},
			"tick 1: hero %d ages Exposed 2 -> 1 and Weak 2 -> 1" % (index + 1))
		_check(actor.get("hp") == hp_block_before[index][0]
			and actor.get("block") == hp_block_before[index][1],
			"tick 1: hero %d HP and Block are unchanged without Bleed" % (index + 1))
	_check(heroes == original, "tick 1 never mutates the caller's hero snapshots")

	var second := batch.tick_side("heroes", after_first)
	_check(second.get("ok") == true, "owner-turn tick 2 succeeds")
	var after_second: Array = second.get("actors", [])
	_check(after_second.size() == CombatParty.PARTY_SIZE, "tick 2 returns the full party")
	for index in range(after_second.size()):
		var actor: Dictionary = after_second[index]
		_check(actor.get("statuses", {}) == {},
			"tick 2: hero %d Exposed and Weak both expire at zero" % (index + 1))
		_check(actor.get("hp") == hp_block_before[index][0]
			and actor.get("block") == hp_block_before[index][1],
			"tick 2: hero %d HP and Block remain unchanged" % (index + 1))
	_check(after_first != original, "tick 1 output differs from the input: the statuses really aged")
	# GDScript arrays compare by value, so prove independence by mutating the
	# returned actor dictionaries and re-reading the untouched input snapshots.
	after_first[0]["statuses"] = {"bleed": 9}
	_check(heroes == original, "mutating tick 1 output cannot alias back into the input snapshots")
	_check(original[0].get("statuses", {}) == {"exposed": 2, "weak": 2},
		"deep-copy nonmutation: the input snapshots keep Exposed 2 and Weak 2")
	for event in first.get("events", []):
		_check(event.get("bleed_hp_loss") == 0,
			"no Bleed HP loss on a positive-status-only owner turn")

	# Pure CombatStatuses floor calculations, independent of any ledger.
	var rules := CombatStatuses.new()
	var defender := {"exposed": 2}
	var attacker := {"weak": 2}
	var defender_snapshot := defender.duplicate(true)
	var attacker_snapshot := attacker.duplicate(true)
	_check(rules.adjusted_attack_damage(3, {}, defender) == 4,
		"floor(3 * 1.5) = 4: 3 attack into Exposed deals 4")
	_check(rules.adjusted_attack_damage(5, attacker, {}) == 3,
		"floor(5 * 0.75) = 3: 5 attack from Weak deals 3")
	_check(rules.adjusted_attack_damage(3, {}, {"exposed": 1}) == 4,
		"one Exposed stack already floors a 3 attack to 4")
	_check(rules.adjusted_attack_damage(5, {"weak": 1}, {}) == 3,
		"one Weak stack already floors a 5 attack to 3")
	_check(rules.adjusted_attack_damage(3, {}, {}) == 3
		and rules.adjusted_attack_damage(5, {}, {}) == 5,
		"control: unchanged floors leave 3 and 5 alone without any status")
	_check(defender == defender_snapshot and attacker == attacker_snapshot,
		"the pure damage calculation never mutates caller status dictionaries")


## AC4: two fresh fixtures with an independent seeded RNG reproduce the whole
## three-beat timeline exactly and consume no randomness.
func _play_three_beats() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var rng_state_before := rng.state
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "replay precondition: Warden opening Block applies")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var events: Array = []
	for beat in range(3):
		events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		_check(scheduler.advance_turn(), "replay advance after beat %d" % (beat + 1))
	return {"events": events, "heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"repeating": scheduler.get_intents(), "rng_state": rng.state,
		"rng_state_before": rng_state_before}


func _test_double_replay() -> void:
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var first := _play_three_beats()
	_check(randi() == expected_global, "the three real authored phases draw no global RNG")
	var second := _play_three_beats()
	_check(first["events"].size() == 3 and second["events"].size() == 3,
		"each replay resolved exactly three enemy phases")
	for run in [first, second]:
		_check(run["events"][0].get("ok") == true and run["events"][1].get("ok") == true
			and run["events"][2].get("ok") == true, "each replay beat succeeds")
		_check(run["rng_state"] == run["rng_state_before"],
			"an independent seeded RNG is unchanged by the whole fixture")
	_check(first["events"] == second["events"],
		"two independently constructed replays produce identical phase results")
	_check(first["heroes"] == second["heroes"] and first["enemies"] == second["enemies"],
		"two independently constructed replays end in identical party and enemy state")
	# Literal end state, so two equally broken runs cannot satisfy the comparisons above.
	_check(first["heroes"][0]["id"] == "warden" and first["heroes"][0]["hp"] == 40
		and first["heroes"][0]["block"] == 2 and first["heroes"][0].get("statuses", {}) == {"exposed": 2}
		and first["heroes"][1]["id"] == "seamstress" and first["heroes"][1]["hp"] == 28
		and first["heroes"][1].get("statuses", {}) == {}
		and first["heroes"][2]["id"] == "tinker" and first["heroes"][2]["hp"] == 24
		and first["heroes"][2].get("statuses", {}) == {"weak": 2},
		"replay end state is Warden 40/2 Exposed 2, Seamstress 28/0, Tinker 24/0 Weak 2")
	_check(first["enemies"][0]["id"] == "spool_stalker" and first["enemies"][0]["hp"] == 14
		and first["enemies"][0]["block"] == 0
		and first["enemies"][1]["id"] == "button_guard" and first["enemies"][1]["hp"] == 16
		and first["enemies"][1]["block"] == 2,
		"replay end state is Spool Stalker 14/0 and Button Guard 16/2")
	_check(first["repeating"] == _first_intents() and second["repeating"] == _first_intents(),
		"both replays return to the first announced intents on beat 4")


## Deep copy of the prescription with one beat replaced in place.
func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC4: a downed Weak target rejects the WHOLE second beat after the first
## source's Exposed-boosted attack was staged, and malformed schedules fail closed.
func _test_negative_rejections() -> void:
	# A negative-amount debuff schedule fails the canonical parser and the validator.
	var malformed: Array = []
	malformed.append({"label": "slot-1 Exposed amount -1",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": -1, "target_position": 1,
			"status": "exposed"})})
	malformed.append({"label": "slot-2 Weak amount -1",
		"data": _with_beat(2, 1, {"type": "debuff", "amount": -1, "target_position": 3,
			"status": "weak"})})
	malformed.append({"label": "slot-1 Exposed amount 0",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 0, "target_position": 1,
			"status": "exposed"})})
	for entry_case in malformed:
		_check(RunFightEncounterSelection._parse_schedule_text(
			JSON.stringify(entry_case["data"])).is_empty(),
			"negative: " + entry_case["label"] + " is rejected by the JSON loader")
		_check(not CombatEnemyIntents.new(entry_case["data"]).is_valid(),
			"negative: " + entry_case["label"] + " is rejected by the intent validator")
	# Controls, so the rejections above cannot pass vacuously.
	_check(_parsed() == _expected(), "negative: the unmodified authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"negative: the unmodified prescription is still a valid schedule")

	# Before beat 2, down Tinker: slot 2's Weak on a downed hero rejects the whole phase.
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: opening Block applied")
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.get_intents() == _first_intents(), "negative: beat 1 announced")
	var opening_beat := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(opening_beat.get("ok") == true, "negative: beat 1 succeeds before downing Tinker")
	_check(scheduler.advance_turn(), "negative: advance to the beat-2 intents")
	_check(party.apply_damage(3, 26) and party.is_downed(3), "negative: Tinker is downed at 0 HP")
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var intents := scheduler.get_intents()
	var intents_input := intents.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var rng_state_before := rng.state
	var result := phase.execute_phase(party, enemies, intents)
	_check(result == {"ok": false, "events": []},
		"negative: Weak on downed Tinker rejects the whole beat-2 phase")
	_check(party.get_heroes() == before_party,
		"negative: no partial attack damage, Block loss or status mutation survives")
	_check(party.get_hero(1).get("block") == 6 and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("statuses", {}) == {"exposed": 2},
		"negative: Warden keeps Block 6, HP 40 and Exposed 2 after the rejected beat")
	_check(enemies.get_enemies() == before_enemies,
		"negative: enemy Block and HP are untouched by the rejected beat")
	_check(intents == intents_input, "negative: a rejected phase leaves caller intents untouched")
	_check(scheduler.get_intents() == _second_intents(),
		"negative: a rejected phase causes no intent progression")
	_check(rng.state == rng_state_before, "negative: a rejected phase consumes no RNG")

	# Control twin: the identical beat-2 fixture with a living Tinker applies source 1's
	# attack for 4 (Block 6 -> 2), proving the rejection above was fail-closed, not vacuous.
	var control_party := _build_authored_party()
	var control_enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(control_party).apply(), "control: opening Block applied")
	var control_scheduler := CombatEnemyIntents.new(_parsed())
	_check(phase.execute_phase(control_party, control_enemies,
		control_scheduler.get_intents()).get("ok") == true, "control: beat 1 succeeds")
	_check(control_scheduler.advance_turn(), "control: advance to beat 2")
	var control := phase.execute_phase(control_party, control_enemies,
		control_scheduler.get_intents())
	_check(control.get("ok") == true, "control: beat 2 succeeds with a living Tinker")
	_check(control.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 3, "status": "weak",
			"applied": true}],
		"control: the same beat-2 events apply when Tinker lives")
	_check_hero(control_party, 1, 40, 2, "control")
	_check(control_party.get_hero(3).get("statuses", {}) == {"weak": 2}, "control: Tinker Weak 2")
