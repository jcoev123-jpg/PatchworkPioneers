extends SceneTree
## Focused, deterministic regression for the standalone M04 encounter
## rearhook_markshift (Seam Ripper at enemy position 1, Button Guard at 2).
## Beat 1 marks the back Tinker Exposed 1 before the Button Guard's 4-damage
## attack lands on her: floor(4 * 1.5) = 6, so 26 -> 20 in this zero-Block
## service fixture. Beat 2 swaps the back Tinker with the middle Seamstress
## (Tinker now middle, Seamstress now back) and the Button Guard gains 3 Block.
## Beat 3 hits the front Warden for an unmodified 3 (40 -> 37) and Weak-marks
## the Tinker now in the middle. The three CombatEnemyPhase calls are
## deliberately isolated: no player turn or owner-turn status tick runs
## between them, so Exposed 1 legitimately remains on its actor here.
## This fixture is NOT registered in the live Fight pool or map; that wiring
## is a later task. Everything below drives the real schedule parser, intent
## cycle, enemy-phase resolver and typed-roster bridge.

const ENCOUNTER_PATH := "res://data/encounters/rearhook_markshift.json"
const ENCOUNTER_ID := "rearhook_markshift"
const PRIOR_PATH := "res://data/encounters/hemhook_exposed_swap.json"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const FIXED_SEED := 20261022

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_verify_failure_harness()
	var hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var definitions := _verify_ac1_authored_schedule_and_intents(hero_catalog, enemy_catalog)
	_verify_ac2_isolated_three_beat_phase(definitions, hero_catalog, enemy_catalog)
	_verify_ac3_typed_assembly_and_fail_closed(definitions, hero_catalog, enemy_catalog)
	if failures.is_empty():
		print("rearhook_markshift_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("rearhook_markshift_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String, sink: Array[String] = failures) -> void:
	checks += 1
	if not condition:
		sink.append(message)


## An assertion helper that silently stopped recording failures would make
## every later check vacuous, so prove the sink actually receives one.
func _verify_failure_harness() -> void:
	var probe_failures: Array[String] = []
	_check(false, "deliberate failure probe", probe_failures)
	if probe_failures.size() != 1 or probe_failures[0] != "deliberate failure probe":
		failures.append("Failure harness did not record a deliberately failing check.")


func _read_text(path: String) -> String:
	_check(FileAccess.file_exists(path), "Expected file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "Expected file to open: %s" % path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	return absf(value) <= 9007199254740991.0 and floorf(value) == value


func _load_json_array(path: String) -> Array:
	var text := _read_text(path)
	if text.is_empty():
		return []
	var parser := JSON.new()
	var err := parser.parse(text)
	_check(err == OK, "Expected valid JSON in %s" % path)
	if err != OK or not parser.data is Array:
		_check(false, "Expected a top-level JSON Array in %s" % path)
		return []
	return parser.data.duplicate(true)


func _find_unique_by_key(records: Array, key: String, expected_value: Variant, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for record in records:
		if record is Dictionary and record.get(key) == expected_value:
			matches.append(record.duplicate(true))
	_check(
		matches.size() == 1,
		"Expected exactly 1 record with %s=%s in %s, found %d" % [key, str(expected_value), label, matches.size()]
	)
	if matches.size() != 1:
		return {}
	return matches[0]


func _coerce_catalog_actor(raw: Dictionary, label: String) -> Dictionary:
	var copy := raw.duplicate(true)
	_check(copy.get("id") is String and not String(copy["id"]).is_empty(), "%s must have a nonempty String id" % label)
	_check(copy.get("name") is String and not String(copy["name"]).is_empty(), "%s must have a nonempty String name" % label)
	_check(copy.get("art_path") is String and not String(copy["art_path"]).is_empty(), "%s must have a nonempty String art_path" % label)
	var max_hp: Variant = copy.get("max_hp")
	_check(_is_integral_number(max_hp), "%s max_hp must be an integral number" % label)
	if _is_integral_number(max_hp):
		copy["max_hp"] = int(max_hp)
	return copy


func _catalog_actor(catalog: Array, catalog_path: String, id: String) -> Dictionary:
	return _coerce_catalog_actor(_find_unique_by_key(catalog, "id", id, catalog_path), id)


## The three shipped heroes in their shipped slots, with no combat-start Block:
## this test exercises a pure enemy-phase service, not the Warden passive.
func _build_catalog_party(hero_catalog: Array) -> CombatParty:
	return CombatParty.new([
		_catalog_actor(hero_catalog, HERO_CATALOG_PATH, "warden"),
		_catalog_actor(hero_catalog, HERO_CATALOG_PATH, "seamstress"),
		_catalog_actor(hero_catalog, HERO_CATALOG_PATH, "tinker"),
	])


## The two reused shipped enemies in the authored order: slot 1 Seam Ripper,
## slot 2 Button Guard. Stats stay exactly as authored in the enemy catalog.
func _build_catalog_enemies(enemy_catalog: Array) -> CombatEnemies:
	return CombatEnemies.new([
		_catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "seam_ripper"),
		_catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "button_guard"),
	])


func _local_roster_map() -> Dictionary:
	return {ENCOUNTER_ID: ["seam_ripper", "button_guard"]}


func _expected_pattern_1() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
		{"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
		{"type": "attack", "amount": 3, "target_position": 1},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 3},
		{"type": "block", "amount": 3},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
	]


func _expected_beat(beat_index: int) -> Array[Dictionary]:
	var intents: Array[Dictionary] = []
	for definition in _expected_definitions():
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat_index % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		intents.append(action)
	return intents


func _expected_six_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for beat_index in [0, 1, 2]:
		actions.append_array(_expected_beat(beat_index))
	return actions


func _expected_events(beat_index: int) -> Array:
	var events: Array = []
	for intent in _expected_beat(beat_index):
		var event := {"type": intent["type"], "enemy_position": intent["enemy_position"], "applied": true}
		for field in ["target_position", "status", "direction"]:
			if intent.has(field):
				event[field] = intent[field]
		events.append(event)
	return events


func _check_actor_fields(actor: Dictionary, expected: Dictionary, label: String) -> void:
	_check(not actor.is_empty(), label + ": actor must exist.")
	for key in expected:
		if key == "statuses":
			_check(
				actor.get("statuses", {}) == expected[key],
				"%s: statuses must be %s, got %s" % [label, str(expected[key]), str(actor.get("statuses", {}))]
			)
		else:
			_check(
				actor.get(key) == expected[key],
				"%s: %s must be %s, got %s" % [label, key, str(expected[key]), str(actor.get(key))]
			)


func _verify_ac1_authored_schedule_and_intents(hero_catalog: Array, enemy_catalog: Array) -> Array:
	# Reused shipped actors, checked by stable ID (never a catalog total or list order).
	var ripper := _catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "seam_ripper")
	var guard := _catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "button_guard")
	_check(
		ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18
		and ripper.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
		"Catalog Seam Ripper must keep name, 18 max_hp and art_path."
	)
	_check(
		guard.get("name") == "Button Guard" and guard.get("max_hp") == 16
		and guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"Catalog Button Guard must keep name, 16 max_hp and art_path."
	)
	_check(
		_catalog_actor(hero_catalog, HERO_CATALOG_PATH, "warden").get("max_hp") == 40
		and _catalog_actor(hero_catalog, HERO_CATALOG_PATH, "seamstress").get("max_hp") == 30
		and _catalog_actor(hero_catalog, HERO_CATALOG_PATH, "tinker").get("max_hp") == 26,
		"Catalog heroes must keep their 40/30/26 max_hp."
	)

	# The authored file is one top-level two-source array ordered by position.
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "The authored schedule file must exist.")
	_check(
		ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"The schedule file name must carry the canonical encounter ID " + ENCOUNTER_ID
	)
	var raw := _load_json_array(ENCOUNTER_PATH)
	_check(raw.size() == 2, "rearhook_markshift.json must be a top-level array of exactly 2 sources.")
	var raw_positions: Array[int] = []
	for raw_definition in raw:
		if not raw_definition is Dictionary:
			_check(false, "Each rearhook source must be a Dictionary.")
			continue
		_check(raw_definition.size() == 2, "Each rearhook source may contain only enemy_position and pattern.")
		_check(
			raw_definition.has("enemy_position") and raw_definition.has("pattern"),
			"Each rearhook source must have enemy_position and pattern."
		)
		_check(_is_integral_number(raw_definition.get("enemy_position")), "Raw enemy_position must be integral.")
		if _is_integral_number(raw_definition.get("enemy_position")):
			raw_positions.append(int(raw_definition["enemy_position"]))
		var raw_pattern: Variant = raw_definition.get("pattern")
		_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern must repeat exactly three beats.")
		if raw_pattern is Array:
			for raw_action in raw_pattern:
				_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
				if raw_action is Dictionary:
					_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
					if raw_action.has("target_position"):
						_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")
					if raw_action.has("direction"):
						_check(_is_integral_number(raw_action.get("direction")), "Raw direction must be integral.")
	_check(raw_positions == [1, 2], "Authored sources must be ordered by ascending enemy_position 1, 2.")

	# The production parser normalizes the authored JSON to exactly these beats.
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	_check(definitions.size() == 2, "Production parser must return exactly the two authored sources.")
	_check(definitions == _expected_definitions(), "Parsed definitions must equal the prescribed two-source schedule.")
	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, ENCOUNTER_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, ENCOUNTER_PATH)
	_check(source_1.get("pattern") == _expected_pattern_1(), "Source 1 must be the Seam Ripper Exposed/shove/attack pattern.")
	_check(source_2.get("pattern") == _expected_pattern_2(), "Source 2 must be the Button Guard attack/Block/Weak pattern.")
	for parsed_source in definitions:
		_check(typeof(parsed_source.get("enemy_position")) == TYPE_INT, "Parsed enemy_position must have TYPE_INT.")
		for parsed_action in parsed_source.get("pattern", []):
			_check(typeof(parsed_action.get("amount")) == TYPE_INT, "Parsed amount must have TYPE_INT.")
			if parsed_action.has("target_position"):
				_check(typeof(parsed_action.get("target_position")) == TYPE_INT, "Parsed target_position must have TYPE_INT.")
			if parsed_action.has("direction"):
				_check(typeof(parsed_action.get("direction")) == TYPE_INT, "Parsed direction must have TYPE_INT.")

	# The real intent service validates all six actions in source order and wraps.
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate the authored rearhook schedule.")
	var announced: Array[Dictionary] = []
	announced.append_array(intents.get_intents())
	_check(intents.get_intents() == _expected_beat(0), "Beat 1 must announce the Exposed mark, then the 4-damage rear attack.")
	_check(intents.advance_turn(), "advance_turn() from beat 1 to beat 2 must succeed.")
	announced.append_array(intents.get_intents())
	_check(intents.get_intents() == _expected_beat(1), "Beat 2 must announce the rear shove, then the Button Guard's Block 3.")
	_check(intents.advance_turn(), "advance_turn() from beat 2 to beat 3 must succeed.")
	announced.append_array(intents.get_intents())
	_check(intents.get_intents() == _expected_beat(2), "Beat 3 must announce the front attack 3, then the Weak mark.")
	_check(announced == _expected_six_actions(), "Beats 1-3 must announce exactly six actions in source order.")
	_check(intents.advance_turn(), "advance_turn() past beat 3 must succeed.")
	_check(intents.get_intents() == _expected_beat(0), "A fourth selection must wrap back to beat 1 exactly.")
	_check(intents.get_intents() == _expected_beat(0), "Repeated reads after wrap must not advance implicitly.")

	# The named earlier example still parses; never assert a global catalog total.
	var prior_definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(PRIOR_PATH))
	_check(not prior_definitions.is_empty(), "The earlier hemhook_exposed_swap.json must still parse.")
	_check(CombatEnemyIntents.new(prior_definitions).is_valid(), "The earlier hemhook schedule must remain valid for intents.")
	for position in [1, 2, 3]:
		var prior_source := _find_unique_by_key(prior_definitions, "enemy_position", position, PRIOR_PATH)
		_check(
			prior_source.get("pattern") is Array and prior_source["pattern"].size() == 3,
			"The earlier hemhook source %d must still have a 3-beat pattern." % position
		)
	return definitions


func _verify_ac2_isolated_three_beat_phase(definitions: Array, hero_catalog: Array, enemy_catalog: Array) -> void:
	var party := _build_catalog_party(hero_catalog)
	var enemies := _build_catalog_enemies(enemy_catalog)
	_check(party.is_valid(), "A fresh catalog CombatParty must be valid.")
	_check(
		enemies.is_valid() and enemies.get_enemies().size() == 2,
		"A fresh typed CombatEnemies must hold exactly the two authored enemy slots."
	)
	# Zero-Block service fixture: no CombatStartingBlock and no statuses anywhere.
	_check_actor_fields(party.get_hero(1), {
		"id": "warden", "name": "Warden", "max_hp": 40,
		"art_path": "res://assets/paper/heroes/warden.png",
		"position": 1, "hp": 40, "block": 0, "statuses": {},
	}, "Opening slot 1")
	_check_actor_fields(party.get_hero(2), {
		"id": "seamstress", "name": "Seamstress", "max_hp": 30,
		"art_path": "res://assets/paper/heroes/seamstress.png",
		"position": 2, "hp": 30, "block": 0, "statuses": {},
	}, "Opening slot 2")
	_check_actor_fields(party.get_hero(3), {
		"id": "tinker", "name": "Tinker", "max_hp": 26,
		"art_path": "res://assets/paper/heroes/tinker.png",
		"position": 3, "hp": 26, "block": 0, "statuses": {},
	}, "Opening slot 3")
	_check_actor_fields(enemies.get_enemy(1), {
		"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18,
		"art_path": "res://assets/paper/enemies/seam_ripper.png",
		"position": 1, "hp": 18, "block": 0,
	}, "Opening enemy 1")
	_check_actor_fields(enemies.get_enemy(2), {
		"id": "button_guard", "name": "Button Guard", "max_hp": 16,
		"art_path": "res://assets/paper/enemies/button_guard.png",
		"position": 2, "hp": 16, "block": 0,
	}, "Opening enemy 2")

	# Actor dictionaries, not board slots, carry identities across the shove.
	var warden: Dictionary = party._heroes[0]
	var seamstress: Dictionary = party._heroes[1]
	var tinker: Dictionary = party._heroes[2]

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1: the Seam Ripper marks the back Tinker Exposed 1, then the Button
	# Guard's 4-damage attack becomes floor(4 * 3/2) = 6 against her open HP.
	_check(intents.get_intents() == _expected_beat(0), "Phase beat 1 announcement must match the schedule.")
	seed(FIXED_SEED)
	var rng_before := randi()
	seed(FIXED_SEED)
	var beat_1 := phase.execute_phase(party, enemies, intents.get_intents())
	_check(randi() == rng_before, "The enemy phase must not draw global RNG.")
	_check(
		beat_1 == {"ok": true, "events": _expected_events(0)},
		"Beat 1 must resolve both sources in order: Exposed 1 then the 4-damage attack, got %s" % str(beat_1)
	)
	_check_actor_fields(party.get_hero(1), {
		"id": "warden", "position": 1, "hp": 40, "block": 0, "statuses": {},
	}, "After Beat 1 slot 1")
	_check_actor_fields(party.get_hero(2), {
		"id": "seamstress", "position": 2, "hp": 30, "block": 0, "statuses": {},
	}, "After Beat 1 slot 2")
	_check_actor_fields(party.get_hero(3), {
		"id": "tinker", "name": "Tinker", "max_hp": 26,
		"art_path": "res://assets/paper/heroes/tinker.png",
		"position": 3, "hp": 20, "block": 0, "statuses": {"exposed": 1},
	}, "After Beat 1 slot 3")
	_check(is_same(party._heroes[2], tinker), "The marked rear hero must remain the same Tinker actor dictionary.")
	_check_actor_fields(enemies.get_enemy(1), {
		"id": "seam_ripper", "position": 1, "hp": 18, "block": 0,
	}, "After Beat 1 enemy 1")
	_check_actor_fields(enemies.get_enemy(2), {
		"id": "button_guard", "position": 2, "hp": 16, "block": 0,
	}, "After Beat 1 enemy 2")
	_check(intents.advance_turn(), "Advance from phase beat 1 to beat 2 must succeed.")

	# Beat 2: the Seam Ripper pulls the Tinker from slot 3 into slot 2, so the
	# Seamstress moves to slot 3; the Button Guard then gains 3 Block.
	_check(intents.get_intents() == _expected_beat(1), "Phase beat 2 announcement must match the schedule.")
	var beat_2 := phase.execute_phase(party, enemies, intents.get_intents())
	_check(
		beat_2 == {"ok": true, "events": _expected_events(1)},
		"Beat 2 must resolve the rear shove then the Block 3 in source order, got %s" % str(beat_2)
	)
	_check_actor_fields(party.get_hero(1), {
		"id": "warden", "position": 1, "hp": 40, "block": 0, "statuses": {},
	}, "After Beat 2 slot 1")
	_check_actor_fields(party.get_hero(2), {
		"id": "tinker", "name": "Tinker", "max_hp": 26,
		"art_path": "res://assets/paper/heroes/tinker.png",
		"position": 2, "hp": 20, "block": 0, "statuses": {"exposed": 1},
	}, "After Beat 2 slot 2")
	_check_actor_fields(party.get_hero(3), {
		"id": "seamstress", "name": "Seamstress", "max_hp": 30,
		"art_path": "res://assets/paper/heroes/seamstress.png",
		"position": 3, "hp": 30, "block": 0, "statuses": {},
	}, "After Beat 2 slot 3")
	_check(
		is_same(party._heroes[1], tinker) and is_same(party._heroes[2], seamstress),
		"The shove must move the same actor dictionaries, so Exposed follows the Tinker rather than the slot."
	)
	_check(is_same(party._heroes[0], warden), "The front Warden must keep his actor dictionary through the shove.")
	_check_actor_fields(enemies.get_enemy(1), {
		"id": "seam_ripper", "position": 1, "hp": 18, "block": 0,
	}, "After Beat 2 enemy 1")
	_check_actor_fields(enemies.get_enemy(2), {
		"id": "button_guard", "position": 2, "hp": 16, "block": 3,
	}, "After Beat 2 enemy 2")
	_check(intents.advance_turn(), "Advance from phase beat 2 to beat 3 must succeed.")

	# Beat 3: the Seam Ripper hits the untouched front Warden for 3 (40 -> 37),
	# then the Button Guard Weak-marks the Tinker now in slot 2.
	_check(intents.get_intents() == _expected_beat(2), "Phase beat 3 announcement must match the schedule.")
	var beat_3 := phase.execute_phase(party, enemies, intents.get_intents())
	_check(
		beat_3 == {"ok": true, "events": _expected_events(2)},
		"Beat 3 must resolve the front attack then the Weak mark in source order, got %s" % str(beat_3)
	)
	_check_actor_fields(party.get_hero(1), {
		"id": "warden", "position": 1, "hp": 37, "block": 0, "statuses": {},
	}, "After Beat 3 slot 1")
	_check_actor_fields(party.get_hero(2), {
		"id": "tinker", "position": 2, "hp": 20, "block": 0, "statuses": {"exposed": 1, "weak": 1},
	}, "After Beat 3 slot 2")
	_check_actor_fields(party.get_hero(3), {
		"id": "seamstress", "position": 3, "hp": 30, "block": 0, "statuses": {},
	}, "After Beat 3 slot 3")
	_check(
		is_same(party._heroes[1], tinker) and is_same(party._heroes[2], seamstress)
		and is_same(party._heroes[0], warden),
		"All three phase calls must leave the same hero actor dictionaries in their final slots."
	)
	_check_actor_fields(enemies.get_enemy(1), {
		"id": "seam_ripper", "position": 1, "hp": 18, "block": 0,
	}, "After Beat 3 enemy 1")
	_check_actor_fields(enemies.get_enemy(2), {
		"id": "button_guard", "position": 2, "hp": 16, "block": 3,
	}, "After Beat 3 enemy 2")
	_check(intents.advance_turn(), "Advance after phase beat 3 must succeed.")
	_check(intents.get_intents() == _expected_beat(0), "The fourth selection must repeat the beat 1 action shapes.")


func _verify_ac3_typed_assembly_and_fail_closed(
	definitions: Array, hero_catalog: Array, enemy_catalog: Array
) -> void:
	# One positive test-local Fight choice through the real roster bridge. The
	# encounter is deliberately absent from the shipped typed Fight pool.
	var choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions,
	}
	var choice_before := choice.duplicate(true)
	var roster_map := _local_roster_map()
	var roster_before := roster_map.duplicate(true)
	var assembled := RunTypedBattleRoster.new().assemble(choice, roster_map, [ENEMY_CATALOG_PATH])
	_check(choice == choice_before, "RunTypedBattleRoster.assemble must not mutate the caller's typed choice.")
	_check(roster_map == roster_before, "RunTypedBattleRoster.assemble must not mutate the caller's roster map.")
	_check(
		assembled.get("ok") == true and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID,
		"RunTypedBattleRoster.assemble must accept the test-local rearhook Fight choice."
	)
	_check(assembled.get("definitions") == definitions, "The assembled schedule must equal the parsed rearhook schedule.")
	var typed_enemies: Variant = assembled.get("enemies")
	_check(
		typed_enemies is CombatEnemies and typed_enemies.is_valid()
		and typed_enemies.get_enemies().size() == 2,
		"The assembled roster must be a valid two-enemy CombatEnemies."
	)
	if typed_enemies is CombatEnemies:
		_check_actor_fields(typed_enemies.get_enemy(1), {
			"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18,
			"art_path": "res://assets/paper/enemies/seam_ripper.png",
			"position": 1, "hp": 18, "block": 0,
		}, "Assembled enemy 1")
		_check_actor_fields(typed_enemies.get_enemy(2), {
			"id": "button_guard", "name": "Button Guard", "max_hp": 16,
			"art_path": "res://assets/paper/enemies/button_guard.png",
			"position": 2, "hp": 16, "block": 0,
		}, "Assembled enemy 2")

	# Focused fail-closed regression: on beat 2 a downed participant in the
	# authored rear shove (torn Tinker OR torn Seamstress) must reject the whole
	# phase, moving nobody and never granting the Button Guard's staged 3 Block.
	for down_position in [2, 3]:
		var position: int = down_position
		var party := _build_catalog_party(hero_catalog)
		var enemies := _build_catalog_enemies(enemy_catalog)
		var lethal: int = 30 if position == 2 else 26
		var other: int = 3 if position == 2 else 2
		_check(
			party.apply_damage(position, lethal) and party.is_downed(position),
			"Precondition: downing the beat-2 shove participant at slot %d must succeed." % position
		)
		_check(
			not party.is_downed(other),
			"Precondition: the adjacent shove participant at slot %d must stay alive." % other
		)
		_check(
			not CombatPositionSwaps.preview_adjacent_swap(party, 3, -1).get("ok", true),
			"A downed participant at slot %d must make the beat-2 rear shove illegal." % position
		)
		var party_before := party.get_heroes()
		var enemies_before := enemies.get_enemies()
		var fail_intents := CombatEnemyIntents.new(definitions)
		_check(fail_intents.advance_turn(), "Move the failing fixture to the authored beat 2.")
		var beat_2 := fail_intents.get_intents()
		_check(beat_2 == _expected_beat(1), "The failing fixture must announce the authored shove plus Block 3.")
		_check(
			CombatEnemyPhase.new().execute_phase(party, enemies, beat_2) == {"ok": false, "events": []},
			"A downed participant at slot %d must fail the entire beat-2 phase closed." % position
		)
		_check(
			party.get_heroes() == party_before,
			"Rejected beat 2 with downed slot %d must leave every hero snapshot unchanged." % position
		)
		_check(
			enemies.get_enemies() == enemies_before,
			"Rejected beat 2 with downed slot %d must leave the enemy roster unchanged." % position
		)
		_check(
			enemies.get_enemy(2).get("block") == 0,
			"Rejected beat 2 with downed slot %d must not grant the Button Guard Block 3." % position
		)
		_check(
			fail_intents.get_intents() == beat_2,
			"Rejected beat 2 with downed slot %d must not advance the intent cycle." % position
		)
