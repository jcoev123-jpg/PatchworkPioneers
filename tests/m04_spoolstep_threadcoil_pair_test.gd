extends SceneTree
## Authentic standalone Fight admission, ordered intent phases and seeded replay.

const ENCOUNTER_DIR := "res://data/encounters/"
const ENEMY_CATALOG := "res://data/enemies/run_enemies.json"
const HERO_CATALOG := "res://data/heroes/starter_party.json"
const IDS := ["spoolstep_crossguard", "threadcoil_backpress"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_DIR + "hemdrag_relay.json"),
		"older hemdrag_relay schedule is still present")
	_check(FileAccess.file_exists(ENCOUNTER_DIR + "frayhem_bleedtrap.json"),
		"older frayhem_bleedtrap schedule is still present")
	for id in IDS:
		_test_schedule(id)
		_test_battle_and_replay(id)
		_test_slain_source(id)
	if failures.is_empty():
		print("m04_spoolstep_threadcoil_pair_test: PASS (", checks, " checks)")
	else:
		for message in failures:
			printerr(message)
		print("m04_spoolstep_threadcoil_pair_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _expected(id: String) -> Array:
	if id == "spoolstep_crossguard":
		return [
			{"enemy_position": 1, "pattern": [
				{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
				{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
				{"type": "attack", "amount": 3, "target_position": 3},
				{"type": "block", "amount": 2}]},
			{"enemy_position": 2, "pattern": [
				{"type": "attack", "amount": 3, "target_position": 1},
				{"type": "attack", "amount": 3, "target_position": 3},
				{"type": "block", "amount": 3},
				{"type": "buff", "amount": 2}]},
			{"enemy_position": 3, "pattern": [
				{"type": "block", "amount": 2},
				{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
				{"type": "attack", "amount": 4, "target_position": 2},
				{"type": "attack", "amount": 3, "target_position": 1}]},
		]
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "attack", "amount": 2, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "buff", "amount": 2},
			{"type": "attack", "amount": 3, "target_position": 3}]},
		{"enemy_position": 3, "pattern": [
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 1}]},
	]


func _order(id: String) -> Array:
	if id == "spoolstep_crossguard":
		return ["spool_stalker", "button_guard", "seam_ripper"]
	return ["fray_scavenger", "spool_stalker", "button_guard"]


func _hp(id: String) -> Array:
	return [14, 16, 18] if id == "spoolstep_crossguard" else [14, 14, 16]


func _text(path: String) -> String:
	_check(FileAccess.file_exists(path), "authored file exists: " + path)
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored file opens: " + path)
	if file == null:
		return ""
	var result := file.get_as_text()
	file.close()
	return result


func _expected_actions(id: String, beat: int) -> Array:
	var result: Array = []
	for definition in _expected(id):
		var action: Dictionary = definition["pattern"][beat % 4].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		result.append(action)
	return result


func _expected_events(actions: Array, slain_position: int = 0) -> Array:
	var events: Array = []
	for action in actions:
		var event: Dictionary = {
			"type": action["type"], "enemy_position": action["enemy_position"],
			"applied": action["enemy_position"] != slain_position}
		for field in ["target_position", "status", "direction"]:
			if action.has(field):
				event[field] = action[field]
		events.append(event)
	return events


func _test_schedule(id: String) -> void:
	var parsed: Array = RunFightEncounterSelection._parse_schedule_text(
		_text(ENCOUNTER_DIR + id + ".json"))
	var expected := _expected(id)
	_check(parsed == expected, id + ": exact three source records and all twelve action dictionaries")
	_check(parsed.size() == 3, id + ": exactly three real sourced patterns")
	var positions: Array = []
	for definition in parsed:
		positions.append(definition["enemy_position"])
		_check(definition["pattern"].size() == 4,
			id + ": source %s independently cycles four beats" % definition["enemy_position"])
		for action in definition["pattern"]:
			_check(action["amount"] is int and (not action.has("target_position")
				or action["target_position"] is int) and (not action.has("direction")
				or action["direction"] is int),
				id + ": parser preserves integral numeric action fields")
	_check(positions == [1, 2, 3], id + ": distinct authored positions are 1, 2, 3")
	var intents := CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), id + ": CombatEnemyIntents validates full authored grammar")
	if not intents.is_valid():
		return
	for beat in range(5):
		var expected_beat := _expected_actions(id, beat)
		_check(intents.get_intents() == expected_beat, id + ": source ordered beat %d exact including wrap" % beat)
		var detached := intents.get_intents()
		detached[0]["amount"] = 1000
		_check(intents.get_intents() == expected_beat, id + ": intent snapshot is detached")
		_check(intents.advance_turn(), id + ": explicit advance from beat %d" % beat)


func _party() -> CombatParty:
	var parsed := JSON.new()
	_check(parsed.parse(_text(HERO_CATALOG)) == OK and parsed.data is Array,
		"real starter party JSON loads as an Array")
	var definitions: Array = []
	if parsed.data is Array:
		for raw in parsed.data:
			var hero: Dictionary = raw.duplicate(true)
			_check(RunFightEncounterSelection._coerce_integral_field(hero, "max_hp"),
				"starter hero maximum HP normalizes safely")
			definitions.append(hero)
	_check(definitions.size() == 3, "three actual starter heroes")
	if definitions.size() == 3:
		_check([definitions[0]["id"], definitions[1]["id"], definitions[2]["id"]]
			== ["warden", "seamstress", "tinker"], "canonical front/middle/back hero identities")
		_check([definitions[0]["max_hp"], definitions[1]["max_hp"], definitions[2]["max_hp"]]
			== [40, 30, 26], "canonical hero HP values")
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "real CombatParty is valid")
	_check(CombatStartingBlock.new(party).apply(), "Warden receives real 6 opening Block")
	_check(party.get_hero(1).get("block") == 6 and party.get_hero(1).get("hp") == 40,
		"opening Block applied to the actual living Warden")
	return party


func _admit(id: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	_check(map.generate(rng), id + ": seeded RunMap generates")
	var node_id := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			node_id = candidate
			break
	_check(not node_id.is_empty() and map.get_legal_choices().has(node_id),
		id + ": selected candidate is an actual legal Fight")
	if node_id.is_empty():
		return {}
	_check(map.choose_node(node_id) and map.get_current_node_id() == node_id
		and map.get_node(node_id).get("type") == "Fight",
		id + ": RunMap.choose_node committed current Fight")
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = seed_value
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng) and oracle_map.choose_node(node_id)
		and oracle_map.get_floors() == map.get_floors(),
		id + ": independent same-seed map replays route")
	var one_entry: Dictionary = {}
	one_entry[id] = ENCOUNTER_DIR + id + ".json"
	var pools := {"Fight": one_entry}
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, pools)
	_check(choice == {"success": true, "node_type": "Fight",
		"encounter_id": id, "definitions": _expected(id)},
		id + ": authentic one-ID Fight pool selects matching parsed schedule")
	oracle_rng.randi_range(0, 0)
	_check(rng.state == oracle_rng.state, id + ": selection consumes precisely one seeded RNG draw")
	var state_after_choice := rng.state
	var cached := selector.select_current_battle(map, rng, pools)
	_check(cached == choice and rng.state == state_after_choice,
		id + ": current battle selection cache uses zero additional RNG")
	if not choice.get("success", false):
		return {}
	var bindings: Dictionary = {}
	bindings[id] = _order(id)
	var assembled := RunTypedBattleRoster.new().assemble(choice,
		bindings, [ENEMY_CATALOG])
	_check(assembled.get("ok", false) and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == id
		and assembled.get("definitions") == _expected(id),
		id + ": RunTypedBattleRoster accepts typed choice, three bindings and canonical enemy catalog")
	if not assembled.get("ok", false):
		return {}
	var enemies: CombatEnemies = assembled["enemies"]
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		id + ": valid three-enemy CombatEnemies assembled")
	var slots := enemies.get_enemies()
	var ids: Array = []
	var hp: Array = []
	var max_hp: Array = []
	var art: Array = []
	for index in range(slots.size()):
		var enemy: Dictionary = slots[index]
		ids.append(enemy["id"])
		hp.append(enemy["hp"])
		max_hp.append(enemy["max_hp"])
		art.append(enemy["art_path"])
		_check(enemy["position"] == index + 1 and enemy["block"] == 0,
			id + ": enemy occupies authentic assigned slot and starts without Block")
	_check(ids == _order(id) and ids.duplicate().size() == 3
		and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2],
		id + ": unique expected source IDs and exact slot order")
	_check(hp == _hp(id) and max_hp == _hp(id),
		id + ": matching canonical starting HP and max HP by source")
	_check(art.size() == 3 and art[0] != art[1] and art[1] != art[2]
		and art[0] != art[2], id + ": three distinct existing enemy asset paths")
	# Ensure the selection and the result are detached from selector's cache.
	var original_choice := choice.duplicate(true)
	cached["definitions"][0]["pattern"][0]["amount"] = 999
	_check(selector.select_current_battle(map, rng, pools) == original_choice
		and rng.state == state_after_choice, id + ": detached cached result never corrupts selection or RNG")
	var intents := CombatEnemyIntents.new(assembled["definitions"])
	_check(intents.is_valid(), id + ": selected schedule creates executable validated intents")
	return {"id": id, "party": _party(), "enemies": enemies, "intents": intents,
		"phase": CombatEnemyPhase.new(), "rng": rng, "map": map, "node": node_id,
		"choice": original_choice}


func _trace(fixture: Dictionary, label: String) -> Array:
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var intents: CombatEnemyIntents = fixture["intents"]
	var phase: CombatEnemyPhase = fixture["phase"]
	var rng: RandomNumberGenerator = fixture["rng"]
	var id: String = fixture["id"]
	var result: Array = []
	for beat in range(4):
		var announcements := intents.get_intents()
		_check(announcements == _expected_actions(id, beat),
			label + ": phase %d announced each original source's complete beat action" % beat)
		var original_announcements := announcements.duplicate(true)
		var heroes_before := party.get_heroes()
		var enemies_before := enemies.get_enemies()
		var rng_before := rng.state
		var applied: Dictionary = phase.execute_phase(party, enemies, announcements)
		_check(applied == {"ok": true, "events": _expected_events(original_announcements)},
			label + ": phase %d applied all sources in exact action/event order" % beat)
		_check(announcements == original_announcements and intents.get_intents() == original_announcements,
			label + ": phase %d does not mutate or advance intents" % beat)
		_check(rng.state == rng_before, label + ": phase %d consumes no run RNG" % beat)
		_check(party.get_heroes() != heroes_before or enemies.get_enemies() != enemies_before,
			label + ": phase %d caused an actual state change" % beat)
		result.append({"announced": original_announcements, "events": applied.get("events", []),
			"heroes": party.get_heroes(), "enemies": enemies.get_enemies(), "rng": rng.state})
		_check(intents.advance_turn(), label + ": explicit advance after phased beat %d" % beat)
	_check(intents.get_intents() == _expected_actions(id, 0),
		label + ": four real phased beats wrap to source-ordered beat zero")
	return result


func _test_battle_and_replay(id: String) -> void:
	var first := _admit(id, 40261)
	if first.is_empty():
		return
	var baseline := _trace(first, id + " first")
	_check(baseline.size() == 4, id + ": four real phase snapshots captured")
	if baseline.size() != 4:
		return
	var b0: Array = baseline[0]["heroes"]
	var b1: Array = baseline[1]["heroes"]
	var b2: Array = baseline[2]["heroes"]
	var b3: Array = baseline[3]["heroes"]
	var e0: Array = baseline[0]["enemies"]
	var e2: Array = baseline[2]["enemies"]
	var e3: Array = baseline[3]["enemies"]
	if id == "spoolstep_crossguard":
		_check(b0[0]["id"] == "warden" and b0[0]["hp"] == 40
			and b0[0]["block"] == 2 and b0[0].get("statuses", {}) == {"exposed": 1},
			id + ": source1 Exposed precedes Guard 3 -> floor(4.5)=4 absorbed by Warden 6->2 Block")
		_check(e0[2]["id"] == "seam_ripper" and e0[2]["block"] == 2,
			id + ": source3 block resolves after source2 front attack")
		_check(b1[0]["id"] == "warden" and b1[1]["id"] == "tinker"
			and b1[2]["id"] == "seamstress"
			and b1[1]["position"] == 2 and b1[2]["position"] == 3,
			id + ": beat1 shove swaps actual Seamstress and Tinker identities")
		_check(b1[2]["hp"] == 27 and b1[1]["hp"] == 26
			and b1[1].get("statuses", {}) == {"weak": 1},
			id + ": Guard hits rear Seamstress for 3 then Ripper Weakens new middle Tinker")
		_check(b2[2]["hp"] == 24 and b2[1]["hp"] == 22
			and e2[1]["block"] == 3,
			id + ": beat2 Stalker and Ripper hit current heroes; Guard blocks 3")
		_check(b3[0]["hp"] == 38 and b3[0]["block"] == 0
			and e3[0]["block"] == 2 and e3[1]["block"] == 5,
			id + ": beat3 front attack uses surviving Block; Stalker blocks 2 and Guard buffs 2")
	else:
		_check(b0[0]["id"] == "warden" and b0[0]["block"] == 6
			and b0[1]["id"] == "tinker" and b0[2]["id"] == "seamstress"
			and b0[1]["hp"] == 26 and b0[2]["hp"] == 28,
			id + ": source1 hit original middle Seamstress for 2 BEFORE source2 shoves Tinker to middle")
		_check(e0[2]["id"] == "button_guard" and e0[2]["block"] == 3,
			id + ": Guard gains source3 Block 3 on first phase")
		_check(b1[1]["id"] == "tinker" and b1[1]["hp"] == 23
			and b1[2]["id"] == "seamstress" and b1[2]["hp"] == 28
			and b1[2].get("statuses", {}) == {"bleed": 1}
			and b1[0]["hp"] == 40 and b1[0]["block"] == 4,
			id + ": beat1 Bleed targets new rear Seamstress, Tinker takes 3, Warden absorbs 2")
		_check(b2[0]["block"] == 1 and b2[0]["hp"] == 40
			and b2[1].get("statuses", {}) == {"weak": 1}
			and e2[1]["block"] == 2,
			id + ": beat2 attack uses remaining opening Block; Stalker buffs and Guard Weakens middle")
		_check(b3[0]["hp"] == 38 and b3[0]["block"] == 0
			and b3[1]["id"] == "tinker" and b3[1]["hp"] == 21
			and b3[2]["id"] == "seamstress" and b3[2]["hp"] == 25
			and b3[2].get("statuses", {}) == {"bleed": 1},
			id + ": beat3 damage follows present slots; no Bleed aging without owner-turn boundary")
	var baseline_for_replay := baseline.duplicate(true)
	# Returned snapshots are independent of authoritative state.
	baseline[0]["heroes"][0]["hp"] = -100
	_check(first["party"].get_hero(1)["hp"] >= 0,
		id + ": detached earlier snapshot edits cannot alter the live party")
	var second := _admit(id, 40261)
	if second.is_empty():
		return
	var replay := _trace(second, id + " replay")
	# Compare the complete independent phase trace, including the first beat.
	_check(replay == baseline_for_replay
		and first["choice"] == second["choice"]
		and first["node"] == second["node"]
		and first["rng"].state == second["rng"].state
		and first["party"].get_heroes() == second["party"].get_heroes()
		and first["enemies"].get_enemies() == second["enemies"].get_enemies(),
		id + ": two independent same-seed Fight selections and full phases replay exactly")


func _test_slain_source(id: String) -> void:
	var fixture := _admit(id, 8824)
	if fixture.is_empty():
		return
	var source := 1 if id == "spoolstep_crossguard" else 2
	var enemies: CombatEnemies = fixture["enemies"]
	var party: CombatParty = fixture["party"]
	var rng: RandomNumberGenerator = fixture["rng"]
	_check(enemies.apply_damage(source, enemies.get_enemy(source)["max_hp"])
		and enemies.is_slain(source), id + ": real damage slays selected source without removing its slot")
	var intents: CombatEnemyIntents = fixture["intents"]
	var actions := intents.get_intents()
	_check(actions == _expected_actions(id, 0) and actions.size() == 3,
		id + ": slain source is still part of complete beat0 announcements")
	var before_rng := rng.state
	var result: Dictionary = fixture["phase"].execute_phase(party, enemies, actions)
	_check(result == {"ok": true, "events": _expected_events(actions, source)}
		and rng.state == before_rng,
		id + ": dead source event is unapplied but two living sources act, without drawing RNG")
	if id == "spoolstep_crossguard":
		_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 3
			and party.get_hero(1).get("statuses", {}).is_empty()
			and enemies.get_enemy(3)["block"] == 2,
			id + ": slain Stalker cannot Expose; Guard deals 3 against Warden Block, Ripper gains 2")
	else:
		_check(party.get_hero(2)["id"] == "seamstress" and party.get_hero(2)["hp"] == 28
			and party.get_hero(3)["id"] == "tinker" and enemies.get_enemy(3)["block"] == 3,
			id + ": slain Stalker cannot shove; Scavenger damages original middle, Guard blocks")