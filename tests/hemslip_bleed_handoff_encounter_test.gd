extends SceneTree

## Deterministic headless coverage for the authored Hemslip Bleed Handoff M04
## Fight: slot 1 Seam Ripper (18 HP) and slot 2 Button Guard (16 HP).
##
## Source 1 shoves the front line back into the middle, source 2 hands Bleed
## over to whoever now stands in the middle, then both press and guard.
## Data/service only: this lane owns the authored schedule and its regression.
## Registering the encounter in the published typed Fight pools and the live
## routed battle is later work and is deliberately not claimed here.

const ENCOUNTER_PATH := "res://data/encounters/hemslip_bleed_handoff.json"
const ENCOUNTER_ID := "hemslip_bleed_handoff"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const NEEDLELACE_PATH := "res://data/encounters/needlelace_wearline.json"
const HEMKNOT_PATH := "res://data/encounters/hemknot_weakguard.json"
const MAP_SEED := 4271

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_verify_ac1_authored_schedule()
	_verify_ac2_selection_and_roster()
	_verify_ac3_three_beats()
	_verify_ac4_rejected_shove_and_companions()
	if failures.is_empty():
		print("hemslip_bleed_handoff_encounter_test: PASS (", checks, " checks)")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
		printerr(failure)
	print("hemslip_bleed_handoff_encounter_test: FAIL (", failures.size(), " failures)")
	quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Whole numbers can arrive from the JSON parser as floats. Integrality is
## proved BEFORE any int coercion, so a fractional catalog value can never be
## truncated into a legal actor.
func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	return absf(value) <= 9007199254740991.0 and floorf(value) == value


## Every numeric leaf must be integral BEFORE any int coercion, so a
## fractional authored value can never be truncated into a legal action.
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


## How many numeric leaves the parsed JSON really holds, so an integrality
## audit cannot pass on a numeric-free document.
func _count_numeric_leaves(value: Variant) -> int:
	if value is float or value is int:
		return 1
	var total := 0
	if value is Array:
		for item in value:
			total += _count_numeric_leaves(item)
		return total
	if value is Dictionary:
		for key in value:
			total += _count_numeric_leaves(value[key])
		return total
	return total


func _load_json_array(path: String) -> Array:
	var text := _read_text(path)
	if text.is_empty():
		_check(false, "Expected a readable JSON file: " + path)
		return []
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Array:
		_check(false, "Expected a top-level JSON array in: " + path)
		return []
	var parsed: Array = parser.data
	return parsed.duplicate(true)


## The single catalog record with this id, looked up by id and never by
## position, so another coder adding a catalog entry cannot break this test.
func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record.duplicate(true))
	_check(matches.size() == 1, "Catalog holds exactly one record named " + id)
	if matches.size() != 1:
		return {}
	var found: Dictionary = matches[0]
	return found


func _hero_by_id(party: CombatParty, id: String) -> Dictionary:
	for hero in party.get_heroes():
		if hero.get("id") == id:
			return hero
	return {}


## The authored schedule, written out by hand rather than copied from the
## file under test.
func _expected_pattern_1() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
		{"type": "attack", "amount": 3, "target_position": 2},
		{"type": "attack", "amount": 4, "target_position": 1},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
		{"type": "block", "amount": 3},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
	]


## The exact full announcement of every beat, written out by hand.
func _expected_beat_1() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 1, "direction": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed", "enemy_position": 2},
	]


func _expected_beat_2() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
		{"type": "block", "amount": 3, "enemy_position": 2},
	]


func _expected_beat_3() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak", "enemy_position": 2},
	]


## The exact ordered phase events of every beat, written out by hand.
func _expected_beat_1_events() -> Array:
	return [
		{"type": "shove", "enemy_position": 1, "applied": true, "target_position": 1, "direction": 1},
		{"type": "debuff", "enemy_position": 2, "applied": true, "target_position": 2, "status": "bleed"},
	]


func _expected_beat_2_events() -> Array:
	return [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2},
		{"type": "block", "enemy_position": 2, "applied": true},
	]


func _expected_beat_3_events() -> Array:
	return [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "applied": true, "target_position": 3, "status": "weak"},
	]


## A catalog actor with its whole-number max_hp normalized, and its
## authored identity and art path preserved.
func _coerce_catalog_actor(raw: Dictionary, label: String) -> Dictionary:
	var copy := raw.duplicate(true)
	var id_value: Variant = copy.get("id")
	var name_value: Variant = copy.get("name")
	var art_value: Variant = copy.get("art_path")
	_check(id_value is String and not String(id_value).is_empty(),
		"%s must have a nonempty String id" % label)
	_check(name_value is String and not String(name_value).is_empty(),
		"%s must have a nonempty String name" % label)
	_check(art_value is String and not String(art_value).is_empty(),
		"%s must have a nonempty String art_path" % label)
	var max_hp: Variant = copy.get("max_hp")
	_check(_is_integral_number(max_hp), "%s max_hp must be integral" % label)
	if _is_integral_number(max_hp):
		copy["max_hp"] = int(max_hp)
	return copy


func _build_party() -> CombatParty:
	var catalog := _load_json_array(HERO_CATALOG_PATH)
	return CombatParty.new([
		_coerce_catalog_actor(_record_by_id(catalog, "warden"), "warden"),
		_coerce_catalog_actor(_record_by_id(catalog, "seamstress"), "seamstress"),
		_coerce_catalog_actor(_record_by_id(catalog, "tinker"), "tinker"),
	])


func _build_enemies() -> CombatEnemies:
	var catalog := _load_json_array(ENEMY_CATALOG_PATH)
	return CombatEnemies.new([
		_coerce_catalog_actor(_record_by_id(catalog, "seam_ripper"), "seam_ripper"),
		_coerce_catalog_actor(_record_by_id(catalog, "button_guard"), "button_guard"),
	])


## The full state of one hero slot: identity, HP, Block and status ownership.
func _check_hero(party: CombatParty, position: int, id: String, hp: int, block: int,
		statuses: Dictionary, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("id") == id,
		"%s: hero slot %d holds %s" % [label, position, id])
	_check(hero.get("hp") == hp,
		"%s: %s has %d HP" % [label, id, hp])
	_check(hero.get("block") == block,
		"%s: %s has %d Block" % [label, id, block])
	_check(hero.get("statuses", {}) == statuses,
		"%s: %s owns statuses %s" % [label, id, str(statuses)])


## AC1: the authored file holds exactly the two prescribed sources, the
## real parser normalizes its integral numbers, and the real intent service
## announces the authored 1/2/3/1 cycle.
func _verify_ac1_authored_schedule() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"AC1: the authored hemslip_bleed_handoff encounter exists")
	var text := _read_text(ENCOUNTER_PATH)
	_check(not text.is_empty(), "AC1: the authored encounter file is readable")
	if text.is_empty():
		return

	# The raw document is proved integral BEFORE any int coercion, and it
	# really holds its fourteen numeric fields, so the audit cannot pass
	# on a numeric-free document.
	var raw: Variant = JSON.parse_string(text)
	_check(raw is Array, "AC1: the raw authored text parses into a JSON array")
	_check(raw is Array and _all_numeric_leaves_integral(raw),
		"AC1: every authored numeric field is integral before any int coercion")
	_check(raw is Array and _count_numeric_leaves(raw) == 14,
		"AC1: the authored document really holds its fourteen numeric fields")
	_check(raw is Array and raw.size() == 2,
		"AC1: the authored schedule holds exactly two enemy sources")

	var definitions := RunFightEncounterSelection._parse_schedule_text(text)
	_check(definitions.size() == 2, "AC1: the real parser returns two definitions")
	_check(definitions == _expected_definitions(),
		"AC1: the normalized schedule matches the prescribed schedule exactly")
	for definition in definitions:
		var source: Dictionary = definition
		_check(source.get("enemy_position") is int,
			"AC1: a parsed enemy_position is an int after normalization")
		var pattern: Array = source.get("pattern", [])
		_check(pattern.size() == 3, "AC1: each source runs a three-beat cycle")
		for action in pattern:
			var record: Dictionary = action
			_check(record.get("amount") is int,
				"AC1: a parsed amount is an int after normalization")
			if record.has("target_position"):
				_check(record.get("target_position") is int,
					"AC1: a parsed target_position is an int after normalization")
			if record.has("direction"):
				_check(record.get("direction") is int,
					"AC1: a parsed direction is an int after normalization")

	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "AC1: the authored schedule passes the real intent validator")
	_check(intents.get_intents() == _expected_beat_1(),
		"AC1: beat 1 announces the shove and the Bleed handoff in source order")
	_check(intents.advance_turn(), "AC1: the intent service advances to beat 2")
	_check(intents.get_intents() == _expected_beat_2(),
		"AC1: beat 2 announces the middle attack and the rear Block")
	_check(intents.advance_turn(), "AC1: the intent service advances to beat 3")
	_check(intents.get_intents() == _expected_beat_3(),
		"AC1: beat 3 announces the front attack and the backline Weak")
	_check(intents.advance_turn(), "AC1: the intent service advances to beat 4")
	_check(intents.get_intents() == _expected_beat_1(),
		"AC1: beat 4 wraps around to the beat 1 announcement, proving a cycle")

	# A fractional drift must be refused, never truncated into a legal beat.
	var fractional := _expected_definitions()
	fractional[0]["pattern"][1]["amount"] = 3.5
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(fractional)).is_empty(),
		"AC1: a fractional authored amount is refused instead of truncated")


## AC2: the real selector picks the local Fight on a fixed-seed map, the
## cached re-query spends no RNG, a same-seed run replays the same choice,
## and the real roster service assembles the two catalog enemies.
func _verify_ac2_selection_and_roster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	var map := RunMap.new()
	_check(map.generate(rng), "AC2: the fixed-seed run map generates")

	var fight_id := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty() and map.get_legal_choices().has(fight_id),
		"AC2: a real legal opening Fight exists on the seeded map")
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id), "AC2: the route chooses the legal opening Fight")
	_check(map.get_current_node_id() == fight_id
		and map.get_node(fight_id).get("type") == "Fight",
		"AC2: the current node is the chosen Fight")

	# A local singleton Fight pool: the published typed pools stay untouched.
	var pool := {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}
	var selector := RunFightEncounterSelection.new()
	var choice: Dictionary = selector.select_current_battle(map, rng, pool)
	_check(choice.get("success", false) == true,
		"AC2: the real selector picks the local Fight")
	_check(choice.get("node_type") == "Fight", "AC2: the selected node type is Fight")
	_check(choice.get("encounter_id") == ENCOUNTER_ID,
		"AC2: the selected encounter is hemslip_bleed_handoff")
	_check(choice.get("definitions") == _expected_definitions(),
		"AC2: the selection carries the exact authored schedule")

	# The cached re-query returns the same choice and spends no extra RNG.
	var state_after_first: int = rng.state
	var cached: Dictionary = selector.select_current_battle(map, rng, pool)
	_check(cached == choice, "AC2: the cached re-query returns the same choice")
	_check(rng.state == state_after_first,
		"AC2: the cached re-query consumes no extra selection RNG")
	# An empty local pool fails closed on a fresh draw, so the cached answer
	# proves the cache answered and no new selection draw was spent.
	var cached_empty: Dictionary = selector.select_current_battle(map, rng, {"Fight": {}})
	_check(cached_empty == choice,
		"AC2: the cached choice is served without any new selection draw")
	_check(rng.state == state_after_first,
		"AC2: the cached re-query leaves the run RNG untouched")

	# A fresh same-seed run replays an equivalent choice.
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = MAP_SEED
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng), "AC2: the same-seed replay map generates")
	_check(replay_map.get_floors() == map.get_floors(),
		"AC2: the same seed rebuilds the same graph")
	_check(replay_map.choose_node(fight_id),
		"AC2: the replay map chooses the same legal opening Fight")
	var replay_choice: Dictionary = RunFightEncounterSelection.new().select_current_battle(
		replay_map, replay_rng, pool)
	_check(replay_choice == choice, "AC2: the same seed yields an equivalent choice")
	_check(replay_rng.state == rng.state,
		"AC2: the same seed consumes the same selection RNG")

	# The real roster service assembles the local binding.
	var assembled: Dictionary = RunTypedBattleRoster.new().assemble(
		choice, {ENCOUNTER_ID: ["seam_ripper", "button_guard"]}, [ENEMY_CATALOG_PATH])
	_check(assembled.get("ok", false) == true,
		"AC2: RunTypedBattleRoster assembles the local Fight binding")
	_check(assembled.get("node_type") == "Fight", "AC2: the assembled node type is Fight")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID,
		"AC2: the assembled encounter id is hemslip_bleed_handoff")
	var roster: Variant = assembled.get("enemies")
	_check(roster is CombatEnemies, "AC2: the assembled roster is a CombatEnemies instance")
	if roster is CombatEnemies:
		var enemies: CombatEnemies = roster
		var slot_1 := enemies.get_enemy(1)
		var slot_2 := enemies.get_enemy(2)
		_check(slot_1.get("id") == "seam_ripper" and slot_1.get("hp") == 18
			and slot_1.get("max_hp") == 18,
			"AC2: enemy slot 1 is Seam Ripper with 18 HP")
		_check(slot_2.get("id") == "button_guard" and slot_2.get("hp") == 16
			and slot_2.get("max_hp") == 16,
			"AC2: enemy slot 2 is Button Guard with 16 HP")


## AC3: three real enemy phases against the living starter party with the
## Warden's real start-of-combat Block.
func _verify_ac3_three_beats() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(party.is_valid(), "AC3: the catalog starter party is valid")
	_check(enemies.is_valid(), "AC3: the catalog enemy roster is valid")
	if not party.is_valid() or not enemies.is_valid():
		return

	# The opening Block is granted exactly once.
	_check(CombatStartingBlock.new(party).apply(),
		"AC3: the Warden's start-of-combat Block is granted once")
	_check_hero(party, 1, "warden", 40, 6, {}, "AC3 opening")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "AC3 opening")
	_check_hero(party, 3, "tinker", 26, 0, {}, "AC3 opening")
	_check(enemies.get_enemy(1).get("id") == "seam_ripper"
		and enemies.get_enemy(1).get("hp") == 18,
		"AC3: enemy slot 1 is the 18 HP Seam Ripper")
	_check(enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16,
		"AC3: enemy slot 2 is the 16 HP Button Guard")

	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "AC3: the authored schedule instantiates the real intent service")
	var phase := CombatEnemyPhase.new()

	# Beat 1: the shove exchanges the front and middle heroes, then source 2
	# hands Bleed 2 to whoever now stands in the middle.
	var beat_1 := intents.get_intents()
	_check(beat_1 == _expected_beat_1(), "AC3: beat 1 announces the authored actions")
	var result_1 := phase.execute_phase(party, enemies, beat_1)
	_check(result_1 == {"ok": true, "events": _expected_beat_1_events()},
		"AC3: beat 1 resolves the shove and the Bleed in source order")
	_check_hero(party, 1, "seamstress", 30, 0, {}, "AC3 after beat 1")
	_check_hero(party, 2, "warden", 40, 6, {"bleed": 2}, "AC3 after beat 1")
	_check_hero(party, 3, "tinker", 26, 0, {}, "AC3 after beat 1")
	_check(_hero_by_id(party, "warden").get("statuses") == {"bleed": 2},
		"AC3: after beat 1 the Bleed 2 belongs to the Warden, who now stands in the middle")
	_check(_hero_by_id(party, "seamstress").get("statuses", {}) == {},
		"AC3: after beat 1 the Seamstress owns no status")
	_check(_hero_by_id(party, "tinker").get("statuses", {}) == {},
		"AC3: after beat 1 the Tinker owns no status")

	# Beat 2: the 3 damage is absorbed by the Warden's own Block, and the
	# rear source guards itself.
	_check(intents.advance_turn(), "AC3: the intents advance to beat 2")
	var beat_2 := intents.get_intents()
	_check(beat_2 == _expected_beat_2(), "AC3: beat 2 announces the authored actions")
	var result_2 := phase.execute_phase(party, enemies, beat_2)
	_check(result_2 == {"ok": true, "events": _expected_beat_2_events()},
		"AC3: beat 2 resolves the attack and the Block in source order")
	_check_hero(party, 1, "seamstress", 30, 0, {}, "AC3 after beat 2")
	_check_hero(party, 2, "warden", 40, 3, {"bleed": 2}, "AC3 after beat 2")
	_check_hero(party, 3, "tinker", 26, 0, {}, "AC3 after beat 2")
	_check(enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("block") == 3
		and enemies.get_enemy(2).get("hp") == 16,
		"AC3: after beat 2 the Button Guard holds 3 Block and 16 HP")
	_check(enemies.get_enemy(1).get("block") == 0,
		"AC3: after beat 2 the Seam Ripper still holds no Block")

	# Beat 3: the front line takes 4 damage and the backline is weakened.
	_check(intents.advance_turn(), "AC3: the intents advance to beat 3")
	var beat_3 := intents.get_intents()
	_check(beat_3 == _expected_beat_3(), "AC3: beat 3 announces the authored actions")
	var result_3 := phase.execute_phase(party, enemies, beat_3)
	_check(result_3 == {"ok": true, "events": _expected_beat_3_events()},
		"AC3: beat 3 resolves the attack and the Weak in source order")
	_check_hero(party, 1, "seamstress", 26, 0, {}, "AC3 after beat 3")
	_check_hero(party, 2, "warden", 40, 3, {"bleed": 2}, "AC3 after beat 3")
	_check_hero(party, 3, "tinker", 26, 0, {"weak": 1}, "AC3 after beat 3")
	_check(_hero_by_id(party, "tinker").get("statuses") == {"weak": 1},
		"AC3: after beat 3 the Weak 1 belongs to the Tinker")
	_check(enemies.get_enemy(2).get("block") == 3,
		"AC3: after beat 3 the Button Guard keeps its 3 Block")

	# Beat 4 repeats the beat 1 announcement: a cycle, not a fourth action.
	_check(intents.advance_turn(), "AC3: the intents advance to beat 4")
	_check(intents.get_intents() == _expected_beat_1(),
		"AC3: beat 4 announces the beat 1 actions again")


## AC4: a downed destination hero rejects the shove, the phase fails
## without applying the later Bleed or touching any state, and the earlier
## authored encounters still parse.
func _verify_ac4_rejected_shove_and_companions() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(party.is_valid() and enemies.is_valid(),
		"AC4: the negative fixture builds a valid party and roster")
	if not party.is_valid() or not enemies.is_valid():
		return
	_check(CombatStartingBlock.new(party).apply(),
		"AC4: the negative fixture grants the opening Block")
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"AC4: the Seamstress in slot 2 is really downed before beat 1")
	_check(party.get_hero(1).get("id") == "warden" and not party.is_downed(1),
		"AC4: the moving Warden in slot 1 is alive, so the swap rule itself is tested")

	var party_before := party.get_heroes()
	var enemies_before := enemies.get_enemies()
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var intents := CombatEnemyIntents.new(definitions)
	var beat_1 := intents.get_intents()
	_check(beat_1 == _expected_beat_1(), "AC4: the negative fixture announces beat 1")

	var result := CombatEnemyPhase.new().execute_phase(party, enemies, beat_1)
	_check(result == {"ok": false, "events": []},
		"AC4: the rejected shove fails the whole phase with no events")
	_check(party.get_heroes() == party_before,
		"AC4: the rejected phase leaves the whole party snapshot unchanged")
	_check(enemies.get_enemies() == enemies_before,
		"AC4: the rejected phase leaves the whole enemy snapshot unchanged")
	_check(_hero_by_id(party, "warden").get("statuses", {}) == {},
		"AC4: the later source-2 Bleed is not applied after the rejected shove")
	_check(intents.get_intents() == _expected_beat_1(),
		"AC4: the rejected phase does not advance or corrupt the scheduler")

	# The earlier authored encounters still parse; no catalogue total or
	# ordered list is asserted anywhere in this test.
	for entry in [["needlelace_wearline", NEEDLELACE_PATH],
			["hemknot_weakguard", HEMKNOT_PATH]]:
		var id: String = entry[0]
		var path: String = entry[1]
		_check(FileAccess.file_exists(path),
			"AC4: the named earlier encounter " + id + " still exists")
		var previous := RunFightEncounterSelection._parse_schedule_text(_read_text(path))
		_check(previous.size() == 2,
			"AC4: the named earlier encounter " + id + " still parses with two sources")
		_check(CombatEnemyIntents.new(previous).is_valid(),
			"AC4: the named earlier encounter " + id + " still passes the intent validator")
