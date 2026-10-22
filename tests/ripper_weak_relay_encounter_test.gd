extends SceneTree
## Standalone M04 Fight regression for the unregistered encounter
## "ripper_weak_relay" (Seam Ripper + Fray Scavenger).
##
## Scope: this encounter is a local, data-only encounter. It is bound here in
## a singleton Fight pool and a local roster map, so the shared typed battle
## pools, the app flow and every other encounter stay untouched.
##
## The test drives the real services only:
##   RunFightEncounterSelection._parse_schedule_text -> authored schedule
##   CombatEnemyIntents                           -> fixed-cycle announcements
##   CombatEnemyPhase                             -> staged, published phase
##   RunMap / RunFightEncounterSelection          -> seeded opening Fight
##   RunTypedBattleRoster                         -> real catalog roster

const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const RIPPER_PATH := "res://data/encounters/ripper_weak_relay.json"
const FRONT_HEM_PIVOT_PATH := "res://data/encounters/front_hem_pivot.json"
const FRONTSEAM_BLEED_PUNCTURE_PATH := "res://data/encounters/frontseam_bleed_puncture.json"
const ENCOUNTER_ID := "ripper_weak_relay"
const MAP_SEED := 4271

var failures: Array[String] = []


func _init() -> void:
	_verify_failure_harness()
	_run_all_checks()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("ripper_weak_relay_encounter_test passed")
	quit(0)


func _check(condition: bool, message: String, sink: Array[String] = failures) -> void:
	if not condition:
		sink.append(message)


func _verify_failure_harness() -> void:
	var probe_failures: Array[String] = []
	_check(false, "deliberate failure probe", probe_failures)
	if probe_failures.size() != 1 or probe_failures[0] != "deliberate failure probe":
		failures.append("Failure harness did not record a deliberately failing check.")


# --- shared helpers -------------------------------------------------------

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
		_check(false, "Expected top-level JSON Array in %s" % path)
		return []
	return parser.data.duplicate(true)


## Locate a record by a stable key and require EXACTLY one match, so a
## duplicated record can never pass as the intended one.
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
	_check(_is_integral_number(max_hp), "%s max_hp must be integral" % label)
	if _is_integral_number(max_hp):
		copy["max_hp"] = int(max_hp)
	return copy


## The local binding for this unregistered encounter. It is not a shared
## catalog and is never registered into live routed play.
func _local_roster_map() -> Dictionary:
	return {ENCOUNTER_ID: ["seam_ripper", "fray_scavenger"]}


## The singleton local Fight pool: {"ripper_weak_relay": <authored schedule>}.
func _local_fight_pool() -> Dictionary:
	return {ENCOUNTER_ID: RIPPER_PATH}


## The same pool under the node-type key select_current_battle expects.
func _local_typed_pool() -> Dictionary:
	return {"Fight": _local_fight_pool()}


func _build_catalog_party(hero_catalog: Array) -> CombatParty:
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	return CombatParty.new([warden, seamstress, tinker])


func _assemble_local_enemies(definitions: Array) -> CombatEnemies:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions.duplicate(true),
	}
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice,
		_local_roster_map(),
		[ENEMY_CATALOG_PATH]
	)
	_check(assembled.get("ok", false), "RunTypedBattleRoster.assemble must succeed for the local ripper_weak_relay fixture.")
	if not assembled.get("ok", false):
		return CombatEnemies.new([])
	return assembled["enemies"]


# --- authored schedule expectations ---------------------------------------

func _expected_pattern_1() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "block", "amount": 3},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 2},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		{"type": "attack", "amount": 3, "target_position": 2},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
	]


func _expected_beat_1_intents() -> Array[Dictionary]:
	return [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak", "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 2},
	]


func _expected_beat_2_intents() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 2},
	]


func _expected_beat_3_intents() -> Array[Dictionary]:
	return [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 2},
	]


## The full announced timeline of the fixed cycle: beats 1, 2, 3 and the
## wraparound back to beat 1, plus one more beat past the wrap.
func _expected_intent_timeline() -> Array:
	return [
		_expected_beat_1_intents(),
		_expected_beat_2_intents(),
		_expected_beat_3_intents(),
		_expected_beat_1_intents(),
		_expected_beat_2_intents(),
	]


## Replay the whole cycle from a fresh instance, comparing complete outputs
## at every step (including the wraparound state).
func _intents_timeline(definitions: Array) -> Array:
	var intents := CombatEnemyIntents.new(definitions)
	var timeline: Array = []
	if not intents.is_valid():
		return timeline
	for _beat in range(5):
		timeline.append(intents.get_intents())
		intents.advance_turn()
	return timeline


func _run_all_checks() -> void:
	var raw_hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var raw_enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var raw_ripper := _load_json_array(RIPPER_PATH)
	var hero_catalog_snapshot := raw_hero_catalog.duplicate(true)
	var enemy_catalog_snapshot := raw_enemy_catalog.duplicate(true)
	var ripper_snapshot := raw_ripper.duplicate(true)

	_verify_ac1_authored_schedule_and_catalogs(raw_hero_catalog, raw_enemy_catalog, raw_ripper)
	_verify_ac2_seeded_selection_assembly_cache_and_replay()
	_verify_ac3_three_beat_ledger_and_events(raw_hero_catalog)
	_verify_ac4_atomic_shove_rejection_and_prior_schedules(raw_hero_catalog)

	_check(raw_hero_catalog == hero_catalog_snapshot, "Hero catalog snapshot must remain unmutated after all checks.")
	_check(raw_enemy_catalog == enemy_catalog_snapshot, "Enemy catalog snapshot must remain unmutated after all checks.")
	_check(_load_json_array(RIPPER_PATH) == ripper_snapshot, "Authored ripper_weak_relay.json on disk must remain unmutated after all checks.")


# --- AC1: the authored schedule -------------------------------------------

func _verify_ac1_authored_schedule_and_catalogs(hero_catalog: Array, enemy_catalog: Array, raw_ripper: Array) -> void:
	# 1. The two required starters exist by ID (no catalog totals are asserted).
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	_check(warden.get("max_hp") == 40, "Catalog Warden must keep 40 max_hp.")
	_check(seamstress.get("max_hp") == 30, "Catalog Seamstress must keep 30 max_hp.")
	_check(tinker.get("max_hp") == 26, "Catalog Tinker must keep 26 max_hp.")

	# 2. The two named run enemies exist by ID (no catalog totals are asserted).
	var ripper := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "seam_ripper", ENEMY_CATALOG_PATH), "seam_ripper")
	var scavenger := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "fray_scavenger", ENEMY_CATALOG_PATH), "fray_scavenger")
	_check(
		ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18
		and ripper.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
		"Catalog Seam Ripper must keep its name, 18 max_hp, and art_path."
	)
	_check(
		scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14
		and scavenger.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
		"Catalog Fray Scavenger must keep its name, 14 max_hp, and art_path."
	)

	# 3. The authored file itself: exactly two source slots, three actions each,
	#    with integral numeric fields before any coercion.
	_check(raw_ripper.size() == 2, "ripper_weak_relay.json must contain exactly 2 enemy source definitions.")
	for raw_def in raw_ripper:
		_check(raw_def is Dictionary, "Each raw definition in ripper_weak_relay.json must be a Dictionary.")
		if not raw_def is Dictionary:
			continue
		_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
		var raw_pattern: Variant = raw_def.get("pattern", [])
		_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern in ripper_weak_relay.json must be a 3-action Array.")
		if not raw_pattern is Array:
			continue
		for raw_action in raw_pattern:
			_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
			if not raw_action is Dictionary:
				continue
			_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
			if raw_action.has("target_position"):
				_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")
			if raw_action.has("direction"):
				_check(_is_integral_number(raw_action.get("direction")), "Raw direction must be integral.")

	# 4. The production parser must accept the file and normalize it.
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(RIPPER_PATH))
	_check(definitions.size() == 2, "RunFightEncounterSelection._parse_schedule_text must return 2 definitions for ripper_weak_relay.")
	for parsed_def in definitions:
		_check(typeof(parsed_def.get("enemy_position")) == TYPE_INT, "Parsed enemy_position must be TYPE_INT after coercion.")
		var parsed_pattern: Array = parsed_def.get("pattern", [])
		for parsed_action in parsed_pattern:
			_check(typeof(parsed_action.get("amount")) == TYPE_INT, "Parsed action amount must be TYPE_INT after coercion.")
			if parsed_action.has("target_position"):
				_check(typeof(parsed_action.get("target_position")) == TYPE_INT, "Parsed target_position must be TYPE_INT after coercion.")
			if parsed_action.has("direction"):
				_check(typeof(parsed_action.get("direction")) == TYPE_INT, "Parsed direction must be TYPE_INT after coercion.")

	# 5. The exact per-source actions, located by source position (unique match).
	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, RIPPER_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, RIPPER_PATH)
	_check(source_1.get("pattern") == _expected_pattern_1(), "Source 1 pattern must be weak 1 on slot 3, attack 4 on slot 1, block 3.")
	_check(source_2.get("pattern") == _expected_pattern_2(), "Source 2 pattern must be attack 3 on slot 2, shove +1 on slot 2, attack 3 on slot 2.")
	_check(definitions == _expected_definitions(), "Normalized ripper_weak_relay definitions must match the canonical schedule.")

	# 6. The named source IDs are bound to the two source slots, in order.
	var roster_map := _local_roster_map()
	_check(roster_map.size() == 1 and roster_map.has(ENCOUNTER_ID), "The local roster map must bind exactly ripper_weak_relay.")
	var bound_ids: Array = roster_map.get(ENCOUNTER_ID, [])
	_check(bound_ids == ["seam_ripper", "fray_scavenger"], "ripper_weak_relay must bind Seam Ripper to source 1 and Fray Scavenger to source 2.")

	# 7. The fixed-cycle announcements: 1 / 2 / 3 / 1 cadence, complete outputs.
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate the ripper_weak_relay definitions.")
	var timeline := _intents_timeline(definitions)
	_check(timeline == _expected_intent_timeline(), "ripper_weak_relay intents must cycle 1/2/3/1 with exact per-beat actions.")
	_check(_intents_timeline(definitions) == timeline, "A fresh CombatEnemyIntents must replay the identical 1/2/3/1 timeline.")

	# 8. Malformed, fractional and illegal authored data must fail closed.
	var invalid_cases: Array[Dictionary] = [
		{"label": "malformed JSON syntax", "json": '[{"enemy_position": 1, "pattern": ['},
		{"label": "fractional attack amount 3.5", "json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3.5, "target_position": 2}]}]'},
		{"label": "fractional debuff amount 1.5", "json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1.5, "target_position": 3, "status": "weak"}]}]'},
		{"label": "fractional target_position 2.5", "json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3, "target_position": 2.5}]}]'},
		{"label": "fractional enemy_position 1.5", "json": '[{"enemy_position": 1.5, "pattern": [{"type": "block", "amount": 3}]}]'},
		{"label": "fractional shove direction 0.5", "json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 0.5}]}]'},
		{"label": "unsupported status frail", "json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 3, "status": "frail"}]}]'},
		{"label": "negative attack amount", "json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": -3, "target_position": 2}]}]'},
		{"label": "duplicate enemy_position 1", "json": '[{"enemy_position": 1, "pattern": [{"type": "block", "amount": 3}]}, {"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}]'},
		{"label": "target_position 4 out of range", "json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3, "target_position": 4}]}]'},
	]
	for entry in invalid_cases:
		_check(
			RunFightEncounterSelection._parse_schedule_text(entry["json"]).is_empty(),
			"RunFightEncounterSelection._parse_schedule_text must reject %s." % entry["label"]
		)

	# 9. The authored file is still valid after all negative probes.
	var rechecked := RunFightEncounterSelection._parse_schedule_text(_read_text(RIPPER_PATH))
	_check(
		rechecked == _expected_definitions() and CombatEnemyIntents.new(rechecked).is_valid(),
		"The authored ripper_weak_relay.json must remain valid after all negative parser probes."
	)


# --- AC2: seeded selection, assembly, caching and replay -------------------

func _find_legal_fight(map: RunMap) -> String:
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			return node_id
	return ""


func _verify_ac2_seeded_selection_assembly_cache_and_replay() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	var map := RunMap.new()
	_check(map.generate(rng), "Seeded RunMap.generate(rng) must succeed for seed %d." % MAP_SEED)
	var fight_id := _find_legal_fight(map)
	_check(not fight_id.is_empty(), "Seeded RunMap must expose a legal opening Fight node.")
	_check(map.choose_node(fight_id), "Choosing the legal opening Fight node must succeed.")
	_check(map.get_current_node_id() == fight_id, "The current node must be the chosen opening Fight.")
	_check(map.get_node(fight_id).get("type") == "Fight", "The chosen opening node must have type Fight.")

	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, _local_typed_pool())
	var rng_after_select := rng.state
	_check(choice.get("success") == true, "select_current_battle must succeed on the chosen opening Fight node.")
	_check(choice.get("node_type") == "Fight", "The selected battle must be typed as a Fight.")
	_check(choice.get("encounter_id") == ENCOUNTER_ID, "The singleton local Fight pool must select ripper_weak_relay.")
	_check(choice.get("definitions") == _expected_definitions(), "The selection must carry the canonical ripper_weak_relay definitions.")

	# The roster is assembled from the real catalogs by ID, not by index.
	var assembled := RunTypedBattleRoster.new().assemble(choice, _local_roster_map(), [ENEMY_CATALOG_PATH])
	_check(assembled.get("ok") == true, "RunTypedBattleRoster.assemble must succeed for the selected ripper_weak_relay fight.")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID, "The assembled roster must report the ripper_weak_relay ID.")
	var assembled_enemies: Variant = assembled.get("enemies")
	_check(assembled_enemies is CombatEnemies and assembled_enemies.is_valid(), "The assembled roster must be a valid CombatEnemies instance.")
	if assembled_enemies is CombatEnemies:
		var slot_1: Dictionary = assembled_enemies.get_enemy(1)
		var slot_2: Dictionary = assembled_enemies.get_enemy(2)
		_check(
			slot_1.get("id") == "seam_ripper" and slot_1.get("position") == 1
			and slot_1.get("max_hp") == 18 and slot_1.get("hp") == 18 and slot_1.get("block") == 0,
			"Slot 1 must be Seam Ripper with 18/18 HP and 0 Block."
		)
		_check(
			slot_2.get("id") == "fray_scavenger" and slot_2.get("position") == 2
			and slot_2.get("max_hp") == 14 and slot_2.get("hp") == 14 and slot_2.get("block") == 0,
			"Slot 2 must be Fray Scavenger with 14/14 HP and 0 Block."
		)
		_check(
			assembled_enemies.get_enemies().size() == 2,
			"The assembled ripper_weak_relay roster must hold exactly its 2 named source slots."
		)

	# A repeated selection is cached: no extra RNG draw, even when the pool
	# would advance the RNG if the answer were not cached.
	var two_entry_pool := {
		"Fight": {
			ENCOUNTER_ID: RIPPER_PATH,
			"front_hem_pivot": FRONT_HEM_PIVOT_PATH,
		}
	}
	_check(two_entry_pool["Fight"].size() == 2, "The cache probe pool must offer two candidates.")
	var cached := selector.select_current_battle(map, rng, two_entry_pool)
	_check(cached == choice, "A repeated select_current_battle on the same node must return the cached choice.")
	_check(rng.state == rng_after_select, "A cached selection must consume no additional RNG draw.")

	# Prove that the no-draw assertion above is not vacuous: an uncached
	# two-entry selection really does advance the run RNG.
	var probe_rng := RandomNumberGenerator.new()
	probe_rng.seed = MAP_SEED
	var probe_map := RunMap.new()
	probe_map.generate(probe_rng)
	var probe_fight := _find_legal_fight(probe_map)
	probe_map.choose_node(probe_fight)
	var probe_before := probe_rng.state
	RunFightEncounterSelection.new().select_current_battle(probe_map, probe_rng, two_entry_pool)
	_check(probe_rng.state != probe_before, "An uncached two-entry selection must advance the run RNG.")

	# The same seed replays the same selection and the same roster.
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = MAP_SEED
	var replay_map := RunMap.new()
	replay_map.generate(replay_rng)
	var replay_fight := _find_legal_fight(replay_map)
	replay_map.choose_node(replay_fight)
	var replay_choice := RunFightEncounterSelection.new().select_current_battle(replay_map, replay_rng, _local_typed_pool())
	_check(replay_choice == choice, "A same-seed replay must select the same ripper_weak_relay fight.")
	var replay_roster := RunTypedBattleRoster.new().assemble(replay_choice, _local_roster_map(), [ENEMY_CATALOG_PATH])
	_check(replay_roster.get("ok") == true, "A same-seed replay must reassemble the ripper_weak_relay roster.")
	var replay_enemies: Variant = replay_roster.get("enemies")
	_check(replay_enemies is CombatEnemies, "A same-seed replay must rebuild a CombatEnemies roster.")
	if replay_enemies is CombatEnemies:
		_check(
			replay_enemies.get_enemy(1).get("id") == "seam_ripper"
			and replay_enemies.get_enemy(1).get("hp") == 18
			and replay_enemies.get_enemy(2).get("id") == "fray_scavenger"
			and replay_enemies.get_enemy(2).get("hp") == 14,
			"A same-seed replay must rebuild the identical 2-enemy ripper_weak_relay roster."
		)


# --- AC3: three real enemy-phase beats -------------------------------------

func _verify_ac3_three_beat_ledger_and_events(hero_catalog: Array) -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(RIPPER_PATH))
	_check(definitions == _expected_definitions(), "The parsed ripper_weak_relay definitions must be canonical before the beats run.")

	var party := _build_catalog_party(hero_catalog)
	var enemies := _assemble_local_enemies(definitions)
	_check(party.is_valid(), "The catalog party must be a valid CombatParty.")
	_check(enemies.is_valid(), "The assembled roster must be a valid CombatEnemies.")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "CombatStartingBlock.apply() must grant the Warden 6 opening Block.")
	_check(not starting_block.apply(), "A second CombatStartingBlock.apply() must fail closed as one-shot.")
	_check(
		party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 6 and party.get_hero(1).get("statuses", {}) == {},
		"Opening slot 1 must be the Warden with 40/40 HP, 6 Block and no statuses."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {},
		"Opening slot 2 must be the Seamstress with 30/30 HP, 0 Block and no statuses."
	)
	_check(
		party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses", {}) == {},
		"Opening slot 3 must be the Tinker with 26/26 HP, 0 Block and no statuses."
	)

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1: source 1 applies Weak 1 to the Tinker (slot 3); source 2 hits
	# the Seamstress (slot 2) for 3.
	var beat_1_announced := intents.get_intents()
	_check(beat_1_announced == _expected_beat_1_intents(), "Beat 1 must announce weak 1 on slot 3 and a 3-damage hit on slot 2.")
	var beat_1 := phase.execute_phase(party, enemies, beat_1_announced)
	_check(
		beat_1 == {"ok": true, "events": [
			{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "weak", "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
		]},
		"Beat 1 must publish the weak debuff and the attack in ascending source order."
	)
	_check(
		party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 6 and party.get_hero(1).get("statuses", {}) == {},
		"After beat 1 the Warden must keep 40 HP, 6 Block and no statuses."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 27
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {},
		"After beat 1 the Seamstress must have 27 HP, 0 Block and no statuses."
	)
	_check(
		party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses") == {"weak": 1},
		"After beat 1 the Tinker must have 26 HP, 0 Block and Weak 1."
	)
	_check(
		enemies.get_enemy(1).get("hp") == 18 and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("hp") == 14 and enemies.get_enemy(2).get("block") == 0,
		"After beat 1 both enemies must be unchanged at 18/0 and 14/0 HP/Block."
	)

	# Beat 2: source 1 hits the front slot for 4 (absorbed by the Warden's
	# Block); source 2 shoves slot 2 back, swapping Seamstress and Tinker.
	_check(intents.advance_turn(), "Advancing the intents from beat 1 to beat 2 must succeed.")
	var beat_2_announced := intents.get_intents()
	_check(beat_2_announced == _expected_beat_2_intents(), "Beat 2 must announce a 4-damage hit on slot 1 and a +1 shove on slot 2.")
	var beat_2 := phase.execute_phase(party, enemies, beat_2_announced)
	_check(
		beat_2 == {"ok": true, "events": [
			{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
			{"type": "shove", "enemy_position": 2, "target_position": 2, "direction": 1, "applied": true},
		]},
		"Beat 2 must publish the front attack and the shove in ascending source order."
	)
	_check(
		party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 2
		and party.get_hero(1).get("statuses", {}) == {},
		"After beat 2 the Warden must keep 40 HP with 2 Block (4 absorbed) and no statuses."
	)
	_check(
		party.get_hero(2).get("id") == "tinker" and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 26 and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses") == {"weak": 1},
		"After beat 2 the Tinker must hold slot 2 with 26 HP and Weak 1 carried by the hero."
	)
	_check(
		party.get_hero(3).get("id") == "seamstress" and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 27 and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After beat 2 the Seamstress must hold slot 3 with 27 HP, 0 Block and no statuses."
	)
	_check(
		enemies.get_enemy(1).get("hp") == 18 and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("hp") == 14 and enemies.get_enemy(2).get("block") == 0,
		"After beat 2 both enemies must still be unchanged at 18/0 and 14/0 HP/Block."
	)

	# Beat 3: source 1 gains 3 Block; source 2 hits the now-middle Tinker.
	_check(intents.advance_turn(), "Advancing the intents from beat 2 to beat 3 must succeed.")
	var beat_3_announced := intents.get_intents()
	_check(beat_3_announced == _expected_beat_3_intents(), "Beat 3 must announce 3 Block and a 3-damage hit on slot 2.")
	var beat_3 := phase.execute_phase(party, enemies, beat_3_announced)
	_check(
		beat_3 == {"ok": true, "events": [
			{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
		]},
		"Beat 3 must publish the enemy Block and the attack in ascending source order."
	)
	_check(
		party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 2 and party.get_hero(1).get("statuses", {}) == {},
		"After beat 3 the Warden must keep 40 HP, 2 Block and no statuses."
	)
	_check(
		party.get_hero(2).get("id") == "tinker" and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 23 and party.get_hero(2).get("statuses") == {"weak": 1},
		"After beat 3 the Tinker must be at 23 HP in slot 2 and still hold Weak 1."
	)
	_check(
		party.get_hero(3).get("id") == "seamstress" and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 27 and party.get_hero(3).get("statuses", {}) == {},
		"After beat 3 the Seamstress must still have 27 HP in slot 3."
	)
	_check(
		enemies.get_enemy(1).get("id") == "seam_ripper" and enemies.get_enemy(1).get("hp") == 18
		and enemies.get_enemy(1).get("block") == 3
		and enemies.get_enemy(2).get("id") == "fray_scavenger" and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 0,
		"After beat 3 the Seam Ripper must hold 3 Block and the Fray Scavenger must be unchanged."
	)

	# The fixed cycle wraps back to the first beat.
	_check(intents.advance_turn(), "Advancing the intents after beat 3 must succeed.")
	_check(intents.get_intents() == _expected_beat_1_intents(), "The announcements must wrap from beat 3 back to beat 1.")

	# Weak reduces that hero's own attack damage by 25%, rounded down.
	_check(
		CombatStatuses.new().adjusted_attack_damage(4, {"weak": 1}, {}) == 3,
		"A Weak 1 hero must deal 3 damage from a 4-damage attack."
	)
	_check(
		CombatStatuses.new().adjusted_attack_damage(3, {"weak": 1}, {}) == 2,
		"A Weak 1 hero must deal 2 damage from a 3-damage attack, rounded down."
	)
	_check(
		CombatStatuses.new().adjusted_attack_damage(3, {}, {}) == 3,
		"A hero without Weak must deal its unmodified damage."
	)

	# The owner-turn expiry of Weak is a detached batch result, applied at the
	# hero owner-turn boundary; the raw phases above must not age it.
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(tick.get("ok") == true, "The hero owner-turn batch must accept the post-beat-3 roster.")
	var ticked: Array = tick.get("actors", [])
	_check(ticked.size() == 3, "The owner-turn batch must return one detached actor per hero.")
	if ticked.size() == 3:
		_check(ticked[1].get("id") == "tinker" and ticked[1].get("statuses", {}) == {},
			"The owner-turn tick must expire the Tinker's Weak 1 in its detached result.")
		_check(ticked[1].get("hp") == 23, "The owner-turn tick must keep the Ticker's 23 HP in its detached result.")
	_check(
		party.get_hero(2).get("statuses") == {"weak": 1},
		"The detached owner-turn tick must not age the authoritative party's Weak 1."
	)


# --- AC4: atomic rejection and the named earlier schedules ------------------

func _verify_ac4_atomic_shove_rejection_and_prior_schedules(hero_catalog: Array) -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(RIPPER_PATH))
	var party := _build_catalog_party(hero_catalog)
	var enemies := _assemble_local_enemies(definitions)
	_check(CombatStartingBlock.new(party).apply(), "The opening Block must apply on the downed-destination fixture.")

	# Fixture preconditions: the mover (Seamstress, slot 2) stays alive while
	# the shove destination (Tinker, slot 3) is downed.
	_check(party.apply_damage(3, 26), "Downing the Tinker at slot 3 must succeed.")
	_check(
		party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
		and not party.is_downed(2),
		"The shove mover in slot 2 must stay alive before the phase runs."
	)
	_check(
		party.get_hero(3).get("id") == "tinker" and party.is_downed(3),
		"The shove destination in slot 3 must be the downed Tinker before the phase runs."
	)

	var phase := CombatEnemyPhase.new()
	var beat_2_announced := _expected_beat_2_intents()
	var heroes_before := party.get_heroes()
	var enemies_before := enemies.get_enemies()
	var rejected := phase.execute_phase(party, enemies, beat_2_announced)
	_check(
		rejected == {"ok": false, "events": []},
		"A shove into a downed destination must reject the whole beat with {ok: false, events: []}."
	)
	_check(
		party.get_heroes() == heroes_before,
		"The rejected beat must leave the authoritative party snapshot unchanged."
	)
	_check(
		enemies.get_enemies() == enemies_before,
		"The rejected beat must leave the authoritative enemy snapshot unchanged."
	)
	_check(
		party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"The rejected beat must roll back the earlier staged 4-damage front hit on the Warden."
	)

	# Independent illegal displacements fail closed on the same fixture.
	var illegal_displacements: Array[Dictionary] = [
		{
			"label": "shove direction 0",
			"intents": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 0, "enemy_position": 2}],
		},
		{
			"label": "shove target_position 4",
			"intents": [{"type": "shove", "amount": 0, "target_position": 4, "direction": 1, "enemy_position": 2}],
		},
		{
			"label": "shove target_position 0",
			"intents": [{"type": "shove", "amount": 0, "target_position": 0, "direction": 1, "enemy_position": 2}],
		},
	]
	for entry in illegal_displacements:
		var result := phase.execute_phase(party, enemies, entry["intents"])
		_check(
			result == {"ok": false, "events": []},
			"CombatEnemyPhase must reject %s." % entry["label"]
		)
		_check(
			party.get_heroes() == heroes_before and enemies.get_enemies() == enemies_before,
			"The rejected %s must leave both authoritative snapshots intact." % entry["label"]
		)

	# The named earlier schedules must still parse and validate; no totals or
	# ordered catalog claims are made about them.
	var hem_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(FRONT_HEM_PIVOT_PATH))
	_check(hem_defs.size() == 2, "front_hem_pivot.json must still parse into 2 source definitions.")
	var hem_1 := _find_unique_by_key(hem_defs, "enemy_position", 1, FRONT_HEM_PIVOT_PATH)
	var hem_2 := _find_unique_by_key(hem_defs, "enemy_position", 2, FRONT_HEM_PIVOT_PATH)
	_check(
		hem_1.get("pattern") == [
			{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 3},
		],
		"front_hem_pivot.json source 1 must keep its exact three-action pattern."
	)
	_check(
		hem_2.get("pattern") == [
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "buff", "amount": 2},
		],
		"front_hem_pivot.json source 2 must keep its exact three-action pattern."
	)
	_check(CombatEnemyIntents.new(hem_defs).is_valid(), "front_hem_pivot.json must remain valid in CombatEnemyIntents.")

	var seam_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(FRONTSEAM_BLEED_PUNCTURE_PATH))
	_check(seam_defs.size() == 2, "frontseam_bleed_puncture.json must still parse into 2 source definitions.")
	var seam_1 := _find_unique_by_key(seam_defs, "enemy_position", 1, FRONTSEAM_BLEED_PUNCTURE_PATH)
	var seam_2 := _find_unique_by_key(seam_defs, "enemy_position", 2, FRONTSEAM_BLEED_PUNCTURE_PATH)
	_check(
		seam_1.get("pattern") == [
			{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "block", "amount": 2},
		],
		"frontseam_bleed_puncture.json source 1 must keep its exact three-action pattern."
	)
	_check(
		seam_2.get("pattern") == [
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "buff", "amount": 3},
			{"type": "attack", "amount": 5, "target_position": 2},
		],
		"frontseam_bleed_puncture.json source 2 must keep its exact three-action pattern."
	)
	_check(CombatEnemyIntents.new(seam_defs).is_valid(), "frontseam_bleed_puncture.json must remain valid in CombatEnemyIntents.")
