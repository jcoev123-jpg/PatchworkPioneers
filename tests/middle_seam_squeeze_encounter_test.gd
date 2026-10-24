extends SceneTree
const WEIGHTED = preload("res://tests/weighted_roster_assert.gd")
## Standalone M03 authored Fight: Middle-Seam Squeeze.
##
## Two authored three-beat cycles resolved through the real shared parser,
## CombatEnemyIntents and CombatEnemyPhase services. This is data-layer content:
## the encounter is intentionally NOT registered in
## data/encounters/m03_typed_battle_pools.json, and no live run/Fight route
## reaches it yet. Registering it in the typed catalog and exercising an actual
## routed live entry remains a separate later task.
##
## The run has one shared deck/hand for heroes in positions 1 front, 2 middle
## and 3 back. Fixed intent cycles never draw randomness; only RunMap and the
## one-entry encounter selection may consume the run RNG.

const ENCOUNTER_ID := "middle_seam_squeeze"
const ENCOUNTER_PATH := "res://data/encounters/middle_seam_squeeze.json"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const BOBBIN_PATH := "res://data/encounters/bobbin_skirmish.json"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const STARTER_ENEMIES_PATH := "res://data/enemies/starter_enemies.json"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const DECK_PATH := "res://data/cards/starter_deck.json"
const SEED_VALUE := 20261021
const FAIL_CLOSED_SEED := 90210
const GLOBAL_SEED := 24680
const DECK_SEED := 70707
const RUN_RNG_SEED := 314159

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_file_and_roster()
	_test_intent_cycle()
	_test_real_phase_sequence()
	_test_slain_downed_and_rejections()
	_test_selector_pick_replay_cache()
	if failures.is_empty():
		print("middle_seam_squeeze_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("middle_seam_squeeze_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact authored schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "block", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "attack", "amount": 2, "target_position": 1}]},
	]


func _starter_expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
	]


func _bobbin_expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1}]},
	]


## Full announcement for one combined beat, ascending source position.
func _announced(beat: int) -> Array:
	var announced: Array = []
	for entry in _expected():
		var pattern: Array = entry["pattern"]
		var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
		action["enemy_position"] = entry["enemy_position"]
		announced.append(action)
	return announced


## Exact events the real phase executor must publish for one beat.
func _events_for(beat: int) -> Array:
	var events := [
		[
			{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
		],
		[
			{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
		],
		[
			{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
		],
	]
	return events[beat % events.size()]


func _read_text(path: String) -> String:
	_check(FileAccess.file_exists(path), "authored file exists: " + path)
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored file opens: " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## JSON numbers arrive as floats; normalize only finite, integral values.
## Non-integral drift stays a float so the real validators reject it.
func _normalize(value: Variant) -> Variant:
	if value is float:
		if is_finite(value) and floorf(value) == value:
			return int(value)
		return value
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_normalize(item))
		return items
	if value is Dictionary:
		var record: Dictionary = {}
		for key in value:
			record[key] = _normalize(value[key])
		return record
	return value


func _load_json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	_check(parsed is Array, path + " parses as a JSON array")
	if not parsed is Array:
		return []
	return _normalize(parsed)


func _parse_schedule(path: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(path))


func _unique_by(records: Array, field: String, id: Variant, label: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get(field) == id:
			matches.append(record)
	_check(matches.size() == 1, label + ": exactly one " + field + "=" + str(id))
	return {} if matches.size() != 1 else matches[0].duplicate(true)


func _positions_of(announced: Array) -> Array:
	var positions: Array = []
	for action in announced:
		positions.append(action.get("enemy_position"))
	return positions


func _build_party() -> CombatParty:
	var heroes := _load_json(PARTY_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_unique_by(heroes, "id", id, "authored hero").duplicate(true))
	return CombatParty.new(definitions)


func _build_enemies() -> CombatEnemies:
	# Slot 1 is the unchanged Guard Ragling from the starter catalog; slot 2 is
	# the unchanged Spool Stalker from the run catalog.
	var guard := _unique_by(_load_json(STARTER_ENEMIES_PATH), "id",
		"ragling_guard", "authored Guard Ragling")
	var stalker := _unique_by(_load_json(RUN_ENEMIES_PATH), "id",
		"spool_stalker", "authored Spool Stalker")
	return CombatEnemies.new([guard.duplicate(true), stalker.duplicate(true)])


func _fixture_ok(party: CombatParty, enemies: CombatEnemies, prefix: String) -> bool:
	var valid := party.is_valid() and enemies.is_valid()
	_check(valid, prefix + ": real authored party and enemy roster are valid")
	if not valid:
		return false
	var hero_ids := ["warden", "seamstress", "tinker"]
	var hero_hp := [40, 30, 26]
	for index in range(3):
		var hero := party.get_hero(index + 1)
		_check(hero.get("id") == hero_ids[index] and hero.get("hp") == hero_hp[index]
			and hero.get("max_hp") == hero_hp[index] and hero.get("block") == 0
			and hero.get("position") == index + 1,
			prefix + ": slot %d is %s at full HP with zero Block"
				% [index + 1, hero_ids[index]])
	_check(enemies.get_enemies().size() == 2, prefix + ": exactly two enemy sources")
	var guard := enemies.get_enemy(1)
	_check(guard.get("id") == "ragling_guard" and guard.get("hp") == 12
		and guard.get("max_hp") == 12 and guard.get("block") == 0
		and guard.get("position") == 1
		and guard.get("art_path") == "res://assets/paper/enemies/ragling_guard.png",
		prefix + ": slot 1 is the 12 HP Guard Ragling with its authored art")
	var stalker := enemies.get_enemy(2)
	_check(stalker.get("id") == "spool_stalker" and stalker.get("hp") == 14
		and stalker.get("max_hp") == 14 and stalker.get("block") == 0
		and stalker.get("position") == 2
		and stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
		prefix + ": slot 2 is the 14 HP Spool Stalker with its authored art")
	return true


func _build_deck(deck_rng: RandomNumberGenerator) -> CombatDeck:
	var raw := _load_json(DECK_PATH)
	var ids: Array[String] = []
	for entry in raw:
		_check(entry is String and not entry.is_empty(), "starter deck card id is a String")
		if not entry is String or entry.is_empty():
			return null
		ids.append(entry)
	return CombatDeck.new(ids, deck_rng)


func _deck_state(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(),
		deck.discard_pile.duplicate(), deck.energy, deck.turn_active]


func _statuses_empty(party: CombatParty, enemies: CombatEnemies) -> bool:
	for hero in party.get_heroes():
		var hero_statuses: Variant = hero.get("statuses", {})
		if not hero_statuses is Dictionary or not hero_statuses.is_empty():
			return false
	for enemy in enemies.get_enemies():
		var enemy_statuses: Variant = enemy.get("statuses", {})
		if not enemy_statuses is Dictionary or not enemy_statuses.is_empty():
			return false
	return true


func _check_hero(party: CombatParty, position: int, id: String, hp: int,
		block: int, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("id") == id and hero.get("hp") == hp and hero.get("block") == block,
		"%s: hero %d is %s at %d HP / %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, hero.get("id"),
				hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int,
		block: int, label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s at %d HP / %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"),
				enemy.get("hp"), enemy.get("block")])


## AC1: the on-disk file, shared parser, exact actions, roster identity and the
## two named earlier schedules.
func _test_authored_file_and_roster() -> void:
	var text := _read_text(ENCOUNTER_PATH)
	if text.is_empty():
		return
	var parser := JSON.new()
	_check(parser.parse(text) == OK, "middle_seam_squeeze is valid JSON")
	var raw = parser.data
	_check(raw is Array and raw.size() == 2, "disc holds exactly two source records")
	if not raw is Array or raw.size() != 2:
		return
	_check(_normalize(raw) == _expected(),
		"raw authored JSON is exactly the required two three-beat sources")
	for raw_definition in raw:
		_check(raw_definition is Dictionary and raw_definition.size() == 2
			and raw_definition.has("enemy_position") and raw_definition.has("pattern"),
			"each raw source carries only enemy_position and pattern")
		if not raw_definition is Dictionary:
			continue
		var raw_pattern = raw_definition.get("pattern")
		_check(raw_pattern is Array and raw_pattern.size() == 3,
			"each raw source pattern holds exactly three beats")
		if not raw_pattern is Array:
			continue
		for raw_action in raw_pattern:
			var kind = raw_action.get("type") if raw_action is Dictionary else null
			if kind == "block":
				_check(raw_action.size() == 2 and raw_action.has("amount")
					and not raw_action.has("target_position"),
					"raw Block actions carry only type and amount")
			else:
				_check(kind == "attack" and raw_action is Dictionary
					and raw_action.size() == 3 and raw_action.has("amount")
					and raw_action.has("target_position"),
					"raw attacks carry exactly type, amount and hero target")

	# The shared parser, not JSON.parse_string, is the authority under test.
	var parsed := RunFightEncounterSelection._parse_schedule_text(text)
	_check(parsed == _expected(), "shared parser returns the exact authored schedule")
	_check(parsed.size() == 2, "the encounter authors its own two sources")
	if parsed.size() != 2:
		return
	for definition in parsed:
		_check(definition.get("enemy_position") is int,
			"parsed enemy_position is an integer, not a float")
		for action in definition["pattern"]:
			_check(action.get("amount") is int, "parsed amount is an integer")
			if action.get("type") == "attack":
				_check(action.get("target_position") is int,
					"parsed attack target_position is an integer")
				_check(action.size() == 3, "parsed attacks carry no unexpected keys")
			else:
				_check(action.get("type") == "block" and action.size() == 2,
					"parsed Blocks are untargeted with no unexpected keys")
	var intents := CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), "CombatEnemyIntents accepts the exact new schedule")
	for beat in range(4):
		var announced := intents.get_intents()
		_check(announced == _announced(beat),
			"beat %d announces the exact authored pair" % beat)
		_check(_positions_of(announced) == [1, 2],
			"beat %d announces slot 1 then slot 2" % beat)
		if beat < 3:
			_check(intents.advance_turn(), "beat %d advances all three-beat cycles" % beat)
	_check(intents.get_intents() == _announced(0), "beat 3 repeats beat 0")

	# Roster identity: unchanged authored definitions from both catalogs.
	var guard_record := _unique_by(_load_json(STARTER_ENEMIES_PATH), "id",
		"ragling_guard", "starter catalog")
	var stalker_record := _unique_by(_load_json(RUN_ENEMIES_PATH), "id",
		"spool_stalker", "run catalog")
	_check(WEIGHTED.project(guard_record) == {"id": "ragling_guard", "name": "Guard Ragling",
		"max_hp": 12, "art_path": "res://assets/paper/enemies/ragling_guard.png"},
		"Guard Ragling normalized definition is the unchanged starter record")
	_check(WEIGHTED.project(stalker_record) == {"id": "spool_stalker", "name": "Spool Stalker",
		"max_hp": 14, "art_path": "res://assets/paper/enemies/spool_stalker.png"},
		"Spool Stalker normalized definition is the unchanged run record")
	_check(guard_record.get("max_hp") is int and stalker_record.get("max_hp") is int,
		"both normalized max_hp values are integers")
	var party := _build_party()
	var enemies := CombatEnemies.new([guard_record.duplicate(true), stalker_record.duplicate(true)])
	_check(_fixture_ok(party, enemies, "AC1 roster"),
		"the two unchanged catalog records form the intended slot 1/2 roster")

	# The named earlier schedules keep their complete ordered records. Only
	# presence and content are checked: no global total or ordered catalog list.
	var starter := _parse_schedule(STARTER_PATH)
	_check(starter == _starter_expected(), "starter_attacks keeps its complete schedule")
	_check(_unique_by(starter, "enemy_position", 1, "starter_attacks source").get("pattern")
		== _starter_expected()[0]["pattern"],
		"starter_attacks source 1 keeps all three ordered attacks")
	_check(_unique_by(starter, "enemy_position", 2, "starter_attacks source").get("pattern")
		== _starter_expected()[1]["pattern"],
		"starter_attacks source 2 keeps its Block")
	_check(CombatEnemyIntents.new(starter).is_valid(), "starter_attacks still validates")
	var bobbin := _parse_schedule(BOBBIN_PATH)
	_check(bobbin == _bobbin_expected(), "bobbin_skirmish keeps its complete schedule")
	_check(_unique_by(bobbin, "enemy_position", 1, "bobbin_skirmish source").get("pattern")
		== _bobbin_expected()[0]["pattern"],
		"bobbin_skirmish source 1 keeps its ordered attack/block/attack")
	_check(_unique_by(bobbin, "enemy_position", 2, "bobbin_skirmish source").get("pattern")
		== _bobbin_expected()[1]["pattern"],
		"bobbin_skirmish source 2 keeps its ordered attack/block")
	_check(CombatEnemyIntents.new(bobbin).is_valid(), "bobbin_skirmish still validates")
	_check(_read_text(ENCOUNTER_PATH) == text,
		"the authored new file is unchanged after all parser reads")


## AC1: exact announcement timeline, ascending source order, wrap and isolation.
func _test_intent_cycle() -> void:
	var parsed := _parse_schedule(ENCOUNTER_PATH)
	_check(not parsed.is_empty(), "real authored file parses into intent definitions")
	if parsed.is_empty():
		return
	var pristine := parsed.duplicate(true)
	var first := CombatEnemyIntents.new(parsed)
	var second := CombatEnemyIntents.new(parsed.duplicate(true))
	_check(first.is_valid() and second.is_valid(),
		"two independent schedulers accept the real parsed schedule")
	if not first.is_valid() or not second.is_valid():
		return

	seed(GLOBAL_SEED)
	var global_expected := randi()
	seed(GLOBAL_SEED)
	for beat in range(7):
		var expected_beat := _announced(beat)
		var announced := first.get_intents()
		var echoed := second.get_intents()
		_check(announced == expected_beat and echoed == expected_beat,
			"beat %d matches the independent authored announcement" % beat)
		_check(announced.size() == 2 and _positions_of(announced) == [1, 2],
			"beat %d announces exactly one action per source in ascending order" % beat)
		_check(first.get_intents() == announced,
			"beat %d repeated read does not advance the schedule" % beat)
		var dirty := announced.duplicate(true)
		dirty[0]["type"] = "block"
		dirty[0]["amount"] = 999
		dirty[1]["enemy_position"] = 3
		dirty.append({"type": "attack", "amount": 7, "target_position": 1,
			"enemy_position": 3})
		_check(first.get_intents() == expected_beat and second.get_intents() == expected_beat,
			"beat %d returned announcements are independent copies" % beat)
		if beat < 6:
			_check(first.advance_turn() and second.advance_turn(),
				"beat %d advances each scheduler exactly once" % beat)
	_check(first.get_intents() == _announced(6),
		"the seventh announcement repeats the authored cycle")
	_check(parsed == pristine, "the caller's parsed definitions are unchanged")
	_check(_parse_schedule(ENCOUNTER_PATH) == pristine,
		"re-reading the authored file still yields the same complete schedule")
	_check(randi() == global_expected,
		"the full announcement/advance cycle consumes no global RNG")
	seed(GLOBAL_SEED)
	var without_extra := randi()
	seed(GLOBAL_SEED)
	randi()
	_check(randi() != without_extra, "the global RNG probe detects an injected draw")

	var supplied := RandomNumberGenerator.new()
	supplied.seed = RUN_RNG_SEED
	var supplied_state := supplied.state
	var supplied_probe := CombatEnemyIntents.new(_expected().duplicate(true))
	supplied_probe.get_intents()
	supplied_probe.advance_turn()
	supplied_probe.get_intents()
	_check(supplied.state == supplied_state,
		"intent stepping does not consume a supplied seeded RNG")


## AC2: real starting Block, real player-turn resets, and the exact three beats
## plus the repeat, with statuses, starter deck and seeded RNG unchanged.
func _test_real_phase_sequence() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC2 fixture"):
		return
	var deck_rng := RandomNumberGenerator.new()
	deck_rng.seed = DECK_SEED
	var deck := _build_deck(deck_rng)
	_check(deck != null, "real starter deck instantiates from the authored card IDs")
	if deck == null:
		return
	var deck_before := _deck_state(deck)
	var deck_rng_before := deck_rng.state
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = RUN_RNG_SEED
	var run_rng_before := run_rng.state

	var scheduler := CombatEnemyIntents.new(_parse_schedule(ENCOUNTER_PATH))
	_check(scheduler.is_valid(), "AC2: real schedule drives the real enemy phase")
	var phase := CombatEnemyPhase.new()
	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "Warden's real opening +6 Block applies once")
	_check_hero(party, 1, "warden", 40, 6, "opening Block")
	_check(not starting_block.apply(), "the opening Block cannot be granted twice")
	_check_hero(party, 1, "warden", 40, 6, "opening Block remains a single grant")

	var hero_ledger := [
		[[40, 4], [30, 0], [24, 0]],
		[[40, 0], [26, 0], [24, 0]],
		[[38, 0], [26, 0], [24, 0]],
		[[36, 0], [26, 0], [22, 0]],
	]
	var enemy_ledger := [
		[[12, 0], [14, 0]],
		[[12, 0], [14, 0]],
		[[12, 2], [14, 0]],
		[[12, 2], [14, 0]],
	]
	var hero_ids := ["warden", "seamstress", "tinker"]
	var enemy_ids := ["ragling_guard", "spool_stalker"]
	var run_state_before_beats := run_rng.state

	seed(GLOBAL_SEED)
	var global_expected := randi()
	seed(GLOBAL_SEED)
	for beat in range(4):
		if beat > 0:
			_check(party.start_player_turn(), "beat %d: real player-turn Block reset" % beat)
			for position in range(1, 4):
				_check(party.get_hero(position).get("block") == 0,
					"beat %d: hero %d Block reset to zero" % [beat, position])
		var announced := scheduler.get_intents()
		var expected_beat := _announced(beat)
		_check(announced == expected_beat, "beat %d uses the exact authored announcement" % beat)
		_check(_positions_of(announced) == [1, 2],
			"beat %d resolves ascending source order" % beat)
		var untouched := announced.duplicate(true)
		var result := phase.execute_phase(party, enemies, announced)
		_check(result == {"ok": true, "events": _events_for(beat)},
			"beat %d publishes the exact ordered events" % beat)
		_check(announced == untouched and scheduler.get_intents() == expected_beat,
			"beat %d phase does not mutate or auto-advance its clock" % beat)
		for position in range(1, 4):
			_check_hero(party, position, hero_ids[position - 1],
				hero_ledger[beat][position - 1][0], hero_ledger[beat][position - 1][1],
				"beat %d" % beat)
		for position in range(1, 3):
			_check_enemy(enemies, position, enemy_ids[position - 1],
				enemy_ledger[beat][position - 1][0], enemy_ledger[beat][position - 1][1],
				"beat %d" % beat)
		_check(_statuses_empty(party, enemies),
			"beat %d leaves every actor's statuses empty" % beat)
		_check(_deck_state(deck) == deck_before and deck_rng.state == deck_rng_before,
			"beat %d leaves the shared starter deck and its RNG unchanged" % beat)
		_check(run_rng.state == run_state_before_beats,
			"beat %d leaves the supplied run RNG unchanged" % beat)
		if beat < 3:
			_check(scheduler.advance_turn(), "beat %d advances the fixed clock once" % beat)

	# The named AC2 checkpoints, restated from the executed ledger.
	_check(hero_ledger[0][0] == [40, 4] and hero_ledger[0][2] == [24, 0],
		"beat 0 splits 2 damage into the Warden's 6 Block and the Tinker's HP")
	_check(hero_ledger[1][1] == [26, 0],
		"beat 1 lands both ordered 2-damage attacks on the middle Seamstress")
	_check(hero_ledger[2][0] == [38, 0] and enemy_ledger[2][0] == [12, 2],
		"beat 2 gives the Guard Ragling 2 Block while returning pressure to the front")
	_check(_events_for(3) == _events_for(0) and _announced(3) == _announced(0),
		"beat 3 replays beat 0's announcement and effects")
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"hero IDs remain in their authored slots 1/2/3")
	_check(enemies.get_enemy(1).get("id") == "ragling_guard"
		and enemies.get_enemy(2).get("id") == "spool_stalker",
		"enemy identities remain Guard Ragling then Spool Stalker")
	_check(_statuses_empty(party, enemies)
		and _deck_state(deck) == deck_before
		and deck_rng.state == deck_rng_before
		and run_rng.state == run_state_before_beats
		and scheduler.get_intents() == _announced(0),
		"after the full cycle statuses, deck, both RNGs and the clock are unchanged")
	_check(randi() == global_expected,
		"the complete four-beat phase sequence draws no global RNG")


## AC3: slain source, downed Tinker and fail-closed malformed input.
func _test_slain_downed_and_rejections() -> void:
	var phase := CombatEnemyPhase.new()

	# A slain Guard Ragling still emits its unapplied event while the living
	# Spool Stalker acts, on both its attack beat and its Block beat.
	var slain_party := _build_party()
	var slain_enemies := _build_enemies()
	if not _fixture_ok(slain_party, slain_enemies, "slain source"):
		return
	var slain_scheduler := CombatEnemyIntents.new(_parse_schedule(ENCOUNTER_PATH))
	_check(slain_scheduler.is_valid(), "slain-source schedule precondition valid")
	_check(slain_enemies.apply_damage(1, 12) and slain_enemies.is_slain(1)
		and not slain_enemies.is_slain(2), "the Guard Ragling is slain, the Stalker lives")
	var slain_attack := phase.execute_phase(slain_party, slain_enemies,
		slain_scheduler.get_intents())
	_check(slain_attack == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]},
		"the slain source's attack is unapplied while the survivor hits the rear")
	_check_hero(slain_party, 1, "warden", 40, 0, "slain attack")
	_check_hero(slain_party, 2, "seamstress", 30, 0, "slain attack")
	_check_hero(slain_party, 3, "tinker", 24, 0, "slain attack")
	_check_enemy(slain_enemies, 1, "ragling_guard", 0, 0, "slain attack")
	_check_enemy(slain_enemies, 2, "spool_stalker", 14, 0, "slain attack")
	_check(slain_scheduler.get_intents() == _announced(0),
		"the phase does not advance the slain-source clock")
	_check(slain_scheduler.advance_turn() and slain_scheduler.advance_turn(),
		"the caller advances to the guard Block beat")
	var slain_block := phase.execute_phase(slain_party, slain_enemies,
		slain_scheduler.get_intents())
	_check(slain_block == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}]},
		"the slain source gains no Block while the survivor returns to the front")
	_check_enemy(slain_enemies, 1, "ragling_guard", 0, 0, "slain block")
	_check_enemy(slain_enemies, 2, "spool_stalker", 14, 0, "slain block")
	_check_hero(slain_party, 1, "warden", 38, 0, "slain block")
	_check_hero(slain_party, 3, "tinker", 24, 0, "slain block")

	# A downed Tinker is neither damaged nor silently retargeted.
	var downed_party := _build_party()
	var downed_enemies := _build_enemies()
	if not _fixture_ok(downed_party, downed_enemies, "downed target"):
		return
	_check(downed_party.apply_damage(3, 26) and downed_party.is_downed(3),
		"the Tinker at slot 3 is downed before the opening beat")
	var downed_scheduler := CombatEnemyIntents.new(_parse_schedule(ENCOUNTER_PATH))
	var downed_result := phase.execute_phase(downed_party, downed_enemies,
		downed_scheduler.get_intents())
	_check(downed_result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": false}]},
		"the attack on the downed Tinker is unapplied and never redirected")
	_check_hero(downed_party, 1, "warden", 38, 0, "downed target")
	_check_hero(downed_party, 2, "seamstress", 30, 0, "downed target")
	_check_hero(downed_party, 3, "tinker", 0, 0, "downed target")
	_check_enemy(downed_enemies, 1, "ragling_guard", 12, 0, "downed target")
	_check_enemy(downed_enemies, 2, "spool_stalker", 14, 0, "downed target")
	_check(_statuses_empty(downed_party, downed_enemies),
		"a downed target gains no implicit status")

	# Rejections must not partially apply an earlier valid action.
	var clean_party := _build_party()
	var clean_enemies := _build_enemies()
	if not _fixture_ok(clean_party, clean_enemies, "rejection fixture"):
		return
	var clean_scheduler := CombatEnemyIntents.new(_parse_schedule(ENCOUNTER_PATH))
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = RUN_RNG_SEED
	var run_state := run_rng.state
	var party_before := clean_party.get_heroes()
	var enemies_before := clean_enemies.get_enemies()
	var clock_before := clean_scheduler.get_intents()
	seed(GLOBAL_SEED)
	var global_expected := randi()
	seed(GLOBAL_SEED)
	var bad_target := [
		{"type": "block", "enemy_position": 1, "amount": 2},
		{"type": "attack", "enemy_position": 2, "amount": 2, "target_position": 4},
	]
	var bad_target_copy := bad_target.duplicate(true)
	_check(phase.execute_phase(clean_party, clean_enemies, bad_target)
		== {"ok": false, "events": []},
		"an invalid later target rejects the entire phase")
	_check(clean_party.get_heroes() == party_before
		and clean_enemies.get_enemies() == enemies_before,
		"the invalid target applies no partial party or enemy mutation")
	_check(bad_target == bad_target_copy and clean_scheduler.get_intents() == clock_before,
		"the invalid target leaves caller actions and the clock intact")
	_check(randi() == global_expected and run_rng.state == run_state,
		"the invalid target consumes no global or supplied RNG")

	seed(GLOBAL_SEED)
	global_expected = randi()
	seed(GLOBAL_SEED)
	var duplicate_source := [
		{"type": "attack", "enemy_position": 1, "amount": 2, "target_position": 1},
		{"type": "block", "enemy_position": 1, "amount": 2},
	]
	var duplicate_copy := duplicate_source.duplicate(true)
	_check(phase.execute_phase(clean_party, clean_enemies, duplicate_source)
		== {"ok": false, "events": []},
		"a duplicate enemy source rejects the entire phase")
	_check(clean_party.get_heroes() == party_before
		and clean_enemies.get_enemies() == enemies_before,
		"the duplicate source applies no partial party or enemy mutation")
	_check(duplicate_source == duplicate_copy
		and clean_scheduler.get_intents() == clock_before,
		"the duplicate source leaves caller actions and the clock intact")
	_check(randi() == global_expected and run_rng.state == run_state,
		"the duplicate source consumes no global or supplied RNG")

	# Malformed authored variants fail closed through the canonical parser.
	var valid := _parse_schedule(ENCOUNTER_PATH)
	var pristine_text := _read_text(ENCOUNTER_PATH)
	_check(not valid.is_empty() and CombatEnemyIntents.new(valid).is_valid(),
		"malformed-input fixtures start from the real valid schedule")
	var broken_texts := [
		"{bad", "[]",
		JSON.stringify([valid[0], valid[0]]),
		JSON.stringify([{"enemy_position": 1, "pattern": []}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 2}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 2, "target_position": 2}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "heal", "amount": 2}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": -2, "target_position": 1}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1.5, "pattern": [
			{"type": "block", "amount": 2}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 2.5}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 1.5}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": "2"}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 2, "extra": 1}]}, valid[1]]),
	]
	for index in range(broken_texts.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(broken_texts[index]).is_empty(),
			"malformed local schedule %d is rejected without partial data" % index)
	_check(_read_text(ENCOUNTER_PATH) == pristine_text
		and _parse_schedule(ENCOUNTER_PATH) == valid,
		"malformed local copies never alter the valid authored file")


func _opening_fight(map: RunMap) -> String:
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			return candidate
	return ""


func _map_with_fight(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	_check(map.generate(rng), "seeded RunMap generates for the selector fixture")
	var fight_id := _opening_fight(map)
	_check(not fight_id.is_empty() and map.get_legal_choices().has(fight_id),
		"the generated map offers a real legal opening Fight")
	return {"rng": rng, "map": map, "fight_id": fight_id}


func _snapshot(map: RunMap, rng: RandomNumberGenerator,
		picker: RunFightEncounterSelection) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"current": map.get_current_node_id(),
		"choices": map.get_legal_choices(),
		"floor": map.get_current_floor(),
		"rng": rng.state,
		"cache": picker._selected.duplicate(true),
		"bound": picker._bound_map,
	}


func _reject(map: RunMap, rng: RandomNumberGenerator, picker: RunFightEncounterSelection,
		pool: Dictionary, label: String,
		supplied_rng: RandomNumberGenerator = null) -> void:
	var before := _snapshot(map, rng, picker)
	var answer := picker.select_current_fight(map, supplied_rng, pool)
	_check(answer == {"success": false}, label + ": rejected with no encounter")
	_check(_snapshot(map, rng, picker) == before,
		label + ": map, run RNG, binding and cache all unchanged")


## AC3: seeded local one-entry selection, cache/replay, no combat draws, and
## fail-closed negatives.
func _test_selector_pick_replay_cache() -> void:
	var start := _map_with_fight(SEED_VALUE)
	var rng: RandomNumberGenerator = start["rng"]
	var map: RunMap = start["map"]
	var fight_id: String = start["fight_id"]
	if fight_id.is_empty():
		return
	var picker := RunFightEncounterSelection.new()
	var pool := {ENCOUNTER_ID: ENCOUNTER_PATH}

	# Every rejection must fail closed before consuming run RNG or binding.
	_reject(RunMap.new(), rng, picker, pool, "ungenerated map", rng)
	_reject(map, rng, picker, pool, "legal but unchosen opening Fight", rng)
	_check(map.choose_node(fight_id) and map.get_current_node_id() == fight_id
		and map.get_node(fight_id).get("type") == "Fight",
		"the chosen CURRENT node is the real offered Fight")
	_reject(map, rng, picker, pool, "null run RNG")
	_reject(map, rng, picker, {}, "empty candidate pool", rng)
	_reject(map, rng, picker,
		{"absent": "res://data/encounters/no_such_middle_seam_fight.json"},
		"missing candidate file", rng)
	_reject(map, rng, picker, {"bad": "res://data/enemies/starter_enemies.json"},
		"candidate outside the encounter directory", rng)
	_reject(map, rng, picker,
		{"bad": "res://data/encounters/../enemies/starter_enemies.json"},
		"noncanonical candidate path", rng)
	_reject(map, rng, picker, {ENCOUNTER_ID: ENCOUNTER_PATH,
		"broken": "res://data/encounters/unknown_middle_seam_fight.json"},
		"a malformed later candidate rejects the whole pool", rng)
	_reject(map, rng, picker, {"bad": null}, "non-string candidate path", rng)
	_reject(map, rng, picker, {1: ENCOUNTER_PATH}, "non-string encounter ID", rng)
	_reject(map, rng, picker, {"": ENCOUNTER_PATH}, "empty encounter ID", rng)
	_check(picker._selected.is_empty() and picker._bound_map == null,
		"no rejected attempt bound the selector or cached a choice")

	# Independent same-seed oracle: identical map, same Fight, one sorted choice.
	var oracle := _map_with_fight(SEED_VALUE)
	var oracle_rng: RandomNumberGenerator = oracle["rng"]
	var oracle_map: RunMap = oracle["map"]
	_check(oracle_map.get_floors() == map.get_floors() and oracle["fight_id"] == fight_id,
		"the same-seed oracle reaches the identical graph and Fight")
	_check(oracle_map.choose_node(fight_id), "the oracle chooses the same real Fight")
	var ids: Array = pool.keys()
	ids.sort()
	_check(ids == [ENCOUNTER_ID], "the local Fight pool holds exactly this encounter")
	var choice_id: String = ids[oracle_rng.randi_range(0, ids.size() - 1)]
	var expected_state := oracle_rng.state
	_check(choice_id == ENCOUNTER_ID, "the one-entry oracle choice can only be this encounter")

	var floors_before := map.get_floors()
	var route_before := map.get_route()
	var current_before := map.get_current_node_id()
	var choices_before := map.get_legal_choices()
	seed(GLOBAL_SEED)
	var global_expected := randi()
	seed(GLOBAL_SEED)
	var answer := picker.select_current_fight(map, rng, pool)
	_check(randi() == global_expected, "selection leaves the Godot global RNG undrawn")
	_check(answer == {"success": true, "encounter_id": ENCOUNTER_ID,
		"definitions": _expected()},
		"the real selector returns the exact new ID and full parsed actions")
	_check(rng.state == expected_state,
		"selection spends exactly the oracle's single choice draw state")
	_check(map.get_floors() == floors_before and map.get_route() == route_before
		and map.get_current_node_id() == current_before
		and map.get_legal_choices() == choices_before,
		"selection never advances or re-chooses the map route")
	var after_pick := rng.state
	var pristine := answer.duplicate(true)

	# A fresh, independent same-seed run selects the same result and state.
	var replay := _map_with_fight(SEED_VALUE)
	var replay_rng: RandomNumberGenerator = replay["rng"]
	var replay_map: RunMap = replay["map"]
	_check(replay_map.get_floors() == map.get_floors()
		and replay["fight_id"] == fight_id, "the replay reaches the identical real Fight")
	_check(replay_map.choose_node(fight_id), "the replay chooses that Fight")
	var replay_answer := RunFightEncounterSelection.new().select_current_fight(
		replay_map, replay_rng, pool)
	_check(replay_answer == answer and replay_rng.state == rng.state,
		"a fresh independent seeded run replays the same choice and RNG state")

	# The selected definitions feed the real fixed scheduler.
	var selected_intents := CombatEnemyIntents.new(answer.get("definitions", []))
	_check(selected_intents.is_valid()
		and selected_intents.get_intents() == _announced(0),
		"selected definitions instantiate the real position-ordered scheduler")

	# Fixed combat beats after selection consume neither the run nor global RNG.
	var combat_party := _build_party()
	var combat_enemies := _build_enemies()
	if not _fixture_ok(combat_party, combat_enemies, "selected combat"):
		return
	var combat_phase := CombatEnemyPhase.new()
	var combat_clock := CombatEnemyIntents.new(answer.get("definitions", []))
	var run_state_before_combat := rng.state
	seed(GLOBAL_SEED)
	var combat_global_expected := randi()
	seed(GLOBAL_SEED)
	for beat in range(3):
		if beat > 0:
			_check(combat_party.start_player_turn(),
				"selected combat beat %d player-turn reset" % beat)
		var result := combat_phase.execute_phase(combat_party, combat_enemies,
			combat_clock.get_intents())
		_check(result == {"ok": true, "events": _events_for(beat)},
			"selected combat beat %d resolves the exact authored events" % beat)
		_check(combat_clock.get_intents() == _announced(beat),
			"selected combat beat %d leaves its clock unadvanced" % beat)
		if beat < 2:
			_check(combat_clock.advance_turn(),
				"selected combat beat %d advances once by the caller" % beat)
	_check(randi() == combat_global_expected,
		"selected fixed combat beats draw no global RNG")
	_check(rng.state == run_state_before_combat,
		"selected fixed combat beats draw no run RNG")

	# Cached re-query spends no second draw, even with no supplied pool.
	var cached := picker.select_current_fight(map, rng, {})
	_check(cached == pristine and rng.state == after_pick,
		"cached re-query returns the same choice with zero extra RNG")
	answer["encounter_id"] = "mutated"
	answer["success"] = false
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"][0]["pattern"][0]["type"] = "invented"
	answer["definitions"].clear()
	cached["definitions"][0]["pattern"][0]["target_position"] = 2
	cached["definitions"].append({"fake": true})
	_check(answer != pristine, "the returned choice really was mutated by the caller")
	var again := picker.select_current_fight(map, rng, pool)
	_check(again == pristine and again.get("definitions", []) == _expected(),
		"two earlier caller mutations cannot alter the later cached read")
	_check(rng.state == after_pick,
		"mutating and re-reading the cache consumes zero run RNG")
