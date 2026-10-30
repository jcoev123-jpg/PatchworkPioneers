extends SceneTree
## Both genuine floor-twelve Boss choices, single-actor binding, replay, packets,
## mounted two-hit announcement, and a settled real-map Colossus victory.

var failures: Array[String] = []
var checks := 0
var witnesses: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _seeded(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for floor in range(RunMap.FLOOR_COUNT):
		var choices := map.get_legal_choices()
		if choices.is_empty() or not map.choose_node(choices[0]):
			return {}
	if map.get_current_floor() != 12 or map.get_node(map.get_current_node_id()).get("type") != "Boss":
		return {}
	var selector := RunFightEncounterSelection.new()
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
	return {"seed": seed_value, "entry_rng": rng.state, "map": map, "rng": rng, "selector": selector, "entry": entry}


func _party() -> CombatParty:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	if not records is Array:
		return CombatParty.new([])
	for hero in records:
		hero.max_hp = int(hero.max_hp)
	return CombatParty.new(records)


func _boss_cases() -> void:
	# The real route and the sorted three-choice pool determine witnesses;
	# never assume the old two-choice selection indices remain fixed.
	for value in range(1, 501):
		var candidate := _seeded(value)
		if candidate.is_empty() or not candidate.entry.get("success", false):
			continue
		var id: String = candidate.entry.encounter_id
		if not witnesses.has(id):
			witnesses[id] = candidate
		if witnesses.size() == 3:
			break
	var expected_hp := {"patchwork_behemoth": 84,
		"sewing_machine_colossus": 96, "moth_queen": 90}
	_check(witnesses.size() == 3, "three independent authentic final-Boss seed witnesses exist")
	for expected in expected_hp:
		_check(witnesses.has(expected), "real final-node seed selects " + expected)
		if not witnesses.has(expected):
			continue
		var fixture: Dictionary = witnesses[expected]
		var entry: Dictionary = fixture.entry
		var roster: Array = entry.enemies.get_enemies()
		_check(roster.size() == 1 and roster[0].id == expected
			and roster[0].hp == expected_hp[expected]
			and roster[0].max_hp == expected_hp[expected]
			and entry.definitions.size() == 1
			and entry.definitions[0].enemy_position == 1,
			"one canonical Boss actor and one-position schedule: " + expected)
		var pool: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/encounters/m03_typed_battle_pools.json"))["Boss"]
		var ids: Array = pool.keys()
		ids.sort()
		var oracle := RandomNumberGenerator.new()
		oracle.seed = fixture.seed
		var oracle_map := RunMap.new()
		_check(oracle_map.generate(oracle), "independent Boss map oracle generated")
		for floor in range(RunMap.FLOOR_COUNT):
			var choices := oracle_map.get_legal_choices()
			if choices.is_empty() or not oracle_map.choose_node(choices[0]):
				_check(false, "independent Boss route commits floor")
				break
		var expected_choice: String = ids[oracle.randi_range(0, ids.size() - 1)]
		_check(expected_choice == expected and oracle.state == fixture.entry_rng,
			"sorted three-way selector consumes exactly one seeded RNG choice")
		var current_state: int = fixture.rng.state
		var cached: Dictionary = fixture.selector._selected.duplicate(true)
		var repeated := RunAuthoredBattleEntry.new().entry_current_battle(
			fixture.map, fixture.rng, fixture.selector)
		_check(repeated.get("success", false) and repeated.encounter_id == expected
			and repeated.definitions == entry.definitions
			and repeated.enemies.get_enemies() == roster
			and fixture.rng.state == current_state and fixture.selector._selected == cached,
			"full actor/schedule/cache/RNG re-entry replay for " + expected)
		var party := _party()
		_check(party.is_valid() and entry.intents.bind_battle(entry.enemies, party, fixture.rng)
			and entry.intents.get_intents().size() == 1
			and not CombatEnemyIntents._weighted_slot(1, roster[0].intent).is_empty(),
			"authentic weighted Boss action binds for " + expected)


func _alternate_refusal() -> void:
	var fixture: Dictionary = witnesses.get("sewing_machine_colossus", {})
	if fixture.is_empty():
		_check(false, "negative fixture has a real selected Boss")
		return
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/encounters/m03_typed_battle_pools.json"))
	_check(registry is Dictionary and registry.get("Boss", {}).size() >= 3,
		"negative fixture contains both independent Boss alternatives")
	if not registry is Dictionary:
		return
	var altered: Dictionary = registry.duplicate(true)
	altered["Boss"]["patchwork_behemoth"]["enemy_ids"] = ["absent_boss"]
	var state: int = fixture.rng.state
	var cached: Dictionary = fixture.selector._selected.duplicate(true)
	var rejected := RunAuthoredBattleEntry.new()._entry_from_data(
		fixture.map, fixture.rng, fixture.selector, altered)
	_check(not rejected.get("success", false) and fixture.rng.state == state
		and fixture.selector._selected == cached,
		"invalid nonselected Boss candidate refuses atomically before RNG/cache")
	var bad_queen: Dictionary = registry.duplicate(true)
	bad_queen["Boss"]["moth_queen"]["enemy_ids"] = ["moth_swarm"]
	var rejected_queen := RunAuthoredBattleEntry.new()._entry_from_data(
		fixture.map, fixture.rng, fixture.selector, bad_queen)
	_check(not rejected_queen.get("success", false) and fixture.rng.state == state
		and fixture.selector._selected == cached,
		"forged Queen catalog binding fails before any RNG or cache mutation")
	var bad_schedule: Dictionary = registry.duplicate(true)
	bad_schedule["Boss"]["moth_queen"]["schedule"] = "res://data/encounters/starter_attacks.json"
	var rejected_schedule := RunAuthoredBattleEntry.new()._entry_from_data(
		fixture.map, fixture.rng, fixture.selector, bad_schedule)
	_check(not rejected_schedule.get("success", false) and fixture.rng.state == state
		and fixture.selector._selected == cached,
		"noncanonical Queen schedule fails before any RNG or cache mutation")


func _packets_and_badge() -> void:
	var fixture: Dictionary = _seeded(witnesses.get("sewing_machine_colossus", {}).get("seed", 0))
	if fixture.is_empty() or not fixture.entry.get("success", false):
		_check(false, "real Colossus packet fixture is selected")
		return
	var enemies: CombatEnemies = fixture.entry.enemies
	var intents: CombatEnemyIntents = fixture.entry.intents
	var party := _party()
	_check(party.is_valid() and enemies.is_valid() and
		enemies.get_enemy(1).id == "sewing_machine_colossus"
		and intents.bind_battle(enemies, party, fixture.rng),
		"Colossus binds authentic weighted intent to real party")
	if not intents.is_bound():
		return
	var action: Dictionary = {}
	for turn in range(32):
		var shown := intents.get_intents()
		if shown.size() == 1 and shown[0].get("type") == "attack":
			action = shown[0]
			break
		if not intents.advance_turn():
			break
	_check(action.get("hits") == 2 and action.get("amount") == 24
		and action.get("target_position") == 1,
		"genuine seeded Colossus announces its authored two-packet front attack")
	if action.is_empty() or action.get("hits") != 2:
		return
	var badge := LiveEnemyIntentBadge.new()
	root.add_child(badge)
	badge.size = Vector2(LiveEnemyIntentBadge.BADGE_WIDTH, LiveEnemyIntentBadge.BADGE_HEIGHT)
	badge.show_intent(action, false, false, CombatEnemyIntents.policy_for(enemies, 1))
	_check(badge.hit_count == 2 and badge.hit_damage == 12
		and badge.amount == 24 and badge.readable_text.contains("24")
		and badge.tooltip_text.contains("two"),
		"mounted shipped intent badge identifies both real hit packets")
	var original_hp: int = party.get_hero(1).hp
	_check(original_hp == 40 and party.gain_block(1, 7),
		"front hero starts alive with genuine Block before both packets")
	var resolved := CombatEnemyPhase.new().execute_phase(
		party, enemies, [action], null, true)
	_check(resolved.get("ok", false) and resolved.get("events", []).size() == 2
		and resolved.events[0].applied and resolved.events[1].applied,
		"one real Colossus announcement produces two applied phase events")
	_check(party.get_hero(1).block == 0 and party.get_hero(1).hp == 23
		and party.get_hero(2).hp == 30 and party.get_hero(3).hp == 26,
		"first 12-damage packet consumes seven Block, second deals its own twelve")
	# Existing Warden reactions run for each Colossus packet, not once per
	# announcement: one living Warden and one authentic Colossus, no stand-ins.
	var reacting_party := _party()
	var reacting_boss := CombatEnemies.new(fixture.entry.enemies.get_enemies())
	var reactions := CombatWardenGuardReactions.new()
	reactions.guarding = true
	reactions.thorns = 3
	_check(reacting_party.is_valid() and reacting_boss.is_valid()
		and reacting_boss.get_enemy(1).hp == 96 and reacting_party.get_hero(1).hp == 40,
		"Colossus reaction test begins with real living Warden and 96-HP attacker")
	var countered := CombatEnemyPhase.new().execute_phase(
		reacting_party, reacting_boss, [action], reactions, true)
	_check(countered.get("ok", false) and countered.get("events", []).size() == 2
		and countered.events[0].applied and countered.events[1].applied
		and countered.events[0].get("retaliation_damage", -1) == 3
		and countered.events[1].get("retaliation_damage", -1) == 3
		and reacting_party.get_hero(1).hp == 16 and reacting_boss.get_enemy(1).hp == 90,
		"both twelve-point hits independently trigger real Warden Thorns 3")
	badge.queue_free()


## Find a full legal route that really selects Colossus after all earlier
## Fight/Elite entries consume their own seeded selection and band draws.
func _routed_colossus_seed() -> int:
	for value in range(1, 501):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var selector := RunFightEncounterSelection.new()
		var valid := true
		for floor in range(RunMap.FLOOR_COUNT):
			var legal := map.get_legal_choices()
			if legal.is_empty() or not map.choose_node(legal[0]):
				valid = false
				break
			var kind: String = map.get_node(map.get_current_node_id()).get("type")
			if kind not in ["Fight", "Elite", "Boss"]:
				continue
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
			if not entry.get("success", false):
				valid = false
				break
			if kind == "Boss" and entry.encounter_id == "sewing_machine_colossus":
				return value
	return -1


func _routed_victory() -> void:
	var seed_value := _routed_colossus_seed()
	var fixture: Dictionary = _seeded(seed_value) if seed_value > 0 else {}
	if fixture.is_empty():
		_check(false, "victory route has authentic seeded final Colossus witness")
		return
	var map: RunMap = fixture.map
	# Re-enact the connected public route with independent authentic battle models.
	var rng := RandomNumberGenerator.new()
	rng.seed = fixture.seed
	var live_map := RunMap.new()
	_check(live_map.generate(rng) and live_map.get_floors() == map.get_floors(),
		"terminal replay starts from a genuinely identical seeded map")
	var latch := RunActBattleOutcome.new(live_map)
	var selector := RunFightEncounterSelection.new()
	var finished_boss := false
	for floor in range(12):
		var legal := live_map.get_legal_choices()
		if legal.is_empty() or not live_map.choose_node(legal[0]):
			_check(false, "each routed node remains a legal connected choice")
			return
		var kind: String = live_map.get_node(live_map.get_current_node_id()).get("type")
		if kind not in ["Fight", "Elite", "Boss"]:
			continue
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(live_map, rng, selector)
		_check(entry.get("success", false), "routed battle is an authenticated selected entry")
		if not entry.get("success", false):
			return
		var party := _party()
		var enemies: CombatEnemies = entry.enemies
		var result := CombatBattleResult.new(party, enemies)
		_check(party.is_valid() and enemies.is_valid()
			and result.get_outcome() == CombatBattleResult.ACTIVE
			and latch.begin_current_battle(result), "real battle begins ACTIVE before victory")
		for source in range(1, enemies.get_enemies().size() + 1):
			var hp: int = enemies.get_enemy(source).hp
			_check(hp > 0 and enemies.apply_damage(source, hp),
				"living routed combatant takes genuine lethal damage")
		_check(result.evaluate() == CombatBattleResult.VICTORY and
			latch.settle_current_battle(), "observed genuine victory settles selected node")
		if kind == "Boss":
			finished_boss = entry.encounter_id == "sewing_machine_colossus" 				and enemies.get_enemies().size() == 1 and enemies.is_victorious()
	_check(finished_boss and live_map.is_complete()
		and latch.get_state().run_status == RunActBattleOutcome.VICTORY,
		"single Colossus death settles ordinary twelve-floor terminal victory without Boss loot")


func _run() -> void:
	_boss_cases()
	_alternate_refusal()
	_packets_and_badge()
	_routed_victory()
	for failure in failures:
		printerr(failure)
	print("v3_boss_seed_choice_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
