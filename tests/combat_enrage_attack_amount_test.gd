extends SceneTree
## Deterministic headless tests for V3-2 Enrage keyword attack action projection:
## - AC1: Living Needle Marshal snapshot (enrage: true) at stacks 0, 1, 2, 3 projects
##   authored attack amount 3 -> 3/5/7/9 and amount 4 -> 4/6/8/10 with a hard +6 ceiling.
## - AC2: Non-attack actions (buff, shove, etc.) pass through unchanged, non-Enrage
##   foes' attacks pass through unchanged, all action fields preserved, no floor rescaling.
## - AC3: Malformed/slain enemy snapshots, impossible stacks, negative/noninteger amounts
##   fail closed without mutating inputs, consuming RNG or altering rosters; regression green.

const ELITE_CATALOG_PATH := "res://data/enemies/m04_elites.json"
const STARTER_CATALOG_PATH := "res://data/enemies/starter_enemies.json"
const MARSHAL_ENCOUNTER_PATH := "res://data/encounters/needle_marshal_elite.json"

var failures: Array[String] = []
var checks := 0
var rules := CombatEnemyKeywordRules.new()


func _initialize() -> void:
	_test_ac1_needle_marshal_attack_projection()
	_test_ac2_non_attack_and_non_enrage_passthrough()
	_test_ac3_malformed_slain_and_rejections()
	_test_ac3_isolation_replay_and_rng()
	_test_ac3_existing_regressions_green()
	if failures.is_empty():
		print("combat_enrage_attack_amount_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_enrage_attack_amount_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _catalog_records(path: String) -> Array:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(path))
	_check(not records.is_empty(), "fixture: shipped catalog parses " + path)
	return records


func _catalog_record(path: String, id: String) -> Dictionary:
	var records := _catalog_records(path)
	var matches: Array = records.filter(func(record: Dictionary) -> bool:
		return record.get("id") == id)
	_check(matches.size() == 1,
		"fixture: exactly one on-disk record %s in %s" % [id, path])
	if matches.size() != 1:
		return {}
	var found: Dictionary = matches[0]
	return found.duplicate(true)


func _marshal_encounter_actions() -> Array[Dictionary]:
	var text := FileAccess.get_file_as_string(MARSHAL_ENCOUNTER_PATH)
	var data: Array = RunFightEncounterSelection._parse_schedule_text(text)
	_check(not data.is_empty(), "fixture: needle_marshal_elite parses via RunFightEncounterSelection")
	var actions: Array[Dictionary] = []
	for slot in data:
		if slot is Dictionary and slot.get("enemy_position") == 1:
			for act in slot.get("pattern", []):
				if act is Dictionary:
					actions.append(act.duplicate(true))
	_check(actions.size() == 4, "fixture: Marshal slot 1 authors exactly four actions")
	return actions


func _living_marshal(stacks: Variant = null) -> Dictionary:
	var marshal := _catalog_record(ELITE_CATALOG_PATH, "needle_marshal")
	marshal["hp"] = marshal["max_hp"]
	marshal["block"] = 0
	marshal["position"] = 1
	if stacks != null:
		marshal["enrage_stacks"] = stacks
	else:
		marshal.erase("enrage_stacks")
	return marshal


func _project(enemy: Variant, action: Variant, label: String) -> Dictionary:
	var enemy_before: Variant = enemy.duplicate(true) if enemy is Dictionary else enemy
	var action_before: Variant = action.duplicate(true) if action is Dictionary else action
	var result := rules.project_enrage_action(enemy, action)
	_check(enemy == enemy_before, label + ": projection leaves enemy input unchanged")
	_check(action == action_before, label + ": projection leaves action input unchanged")
	return result


func _test_ac1_needle_marshal_attack_projection() -> void:
	var marshal_raw := _catalog_record(ELITE_CATALOG_PATH, "needle_marshal")
	_check(marshal_raw.get("id") == "needle_marshal"
		and marshal_raw.get("max_hp") == 28
		and marshal_raw.get("thorns") == 3
		and marshal_raw.get("enrage") == true,
		"AC1: authored Needle Marshal has max_hp: 28, thorns: 3, enrage: true")

	var actions := _marshal_encounter_actions()
	var attack_3: Dictionary = {}
	var attack_4: Dictionary = {}
	for act in actions:
		if act.get("type") == "attack" and act.get("amount") == 3:
			attack_3 = act.duplicate(true)
		elif act.get("type") == "attack" and act.get("amount") == 4:
			attack_4 = act.duplicate(true)

	_check(not attack_3.is_empty() and attack_3.get("target_position") == 1,
		"AC1: authored Marshal attack amount 3 targets hero position 1")
	_check(not attack_4.is_empty() and attack_4.get("target_position") == 2,
		"AC1: authored Marshal attack amount 4 targets hero position 2")

	# Test stacks 0, 1, 2, 3 against attack 3 -> 3/5/7/9
	var expected_3 := [
		{"stacks": 0, "amount": 3, "bonus": 0, "applied": false},
		{"stacks": 1, "amount": 5, "bonus": 2, "applied": true},
		{"stacks": 2, "amount": 7, "bonus": 4, "applied": true},
		{"stacks": 3, "amount": 9, "bonus": 6, "applied": true},
	]
	for exp in expected_3:
		var snapshot := _living_marshal(exp["stacks"])
		var receipt := _project(snapshot, attack_3, "AC1: attack 3 at %d stacks" % exp["stacks"])
		_check(receipt["ok"] == true, "AC1: attack 3 projection succeeds at stack %d" % exp["stacks"])
		_check(receipt["applied"] == exp["applied"],
			"AC1: attack 3 applied is %s at stack %d" % [exp["applied"], exp["stacks"]])
		_check(receipt["enrage_stacks"] == exp["stacks"],
			"AC1: receipt reflects %d enrage_stacks" % exp["stacks"])
		_check(receipt["attack_bonus"] == exp["bonus"],
			"AC1: attack bonus is %d at stack %d" % [exp["bonus"], exp["stacks"]])
		_check(receipt["action"]["amount"] == exp["amount"],
			"AC1: attack 3 projects to %d damage at stack %d" % [exp["amount"], exp["stacks"]])
		_check(receipt["action"]["target_position"] == 1,
			"AC1: attack 3 preserves target_position 1 at stack %d" % exp["stacks"])
		_check(receipt["action"]["type"] == "attack",
			"AC1: action type remains attack")

	# Test stacks 0, 1, 2, 3 against attack 4 -> 4/6/8/10
	var expected_4 := [
		{"stacks": 0, "amount": 4, "bonus": 0, "applied": false},
		{"stacks": 1, "amount": 6, "bonus": 2, "applied": true},
		{"stacks": 2, "amount": 8, "bonus": 4, "applied": true},
		{"stacks": 3, "amount": 10, "bonus": 6, "applied": true},
	]
	for exp in expected_4:
		var snapshot := _living_marshal(exp["stacks"])
		var receipt := _project(snapshot, attack_4, "AC1: attack 4 at %d stacks" % exp["stacks"])
		_check(receipt["ok"] == true, "AC1: attack 4 projection succeeds at stack %d" % exp["stacks"])
		_check(receipt["applied"] == exp["applied"],
			"AC1: attack 4 applied is %s at stack %d" % [exp["applied"], exp["stacks"]])
		_check(receipt["enrage_stacks"] == exp["stacks"],
			"AC1: receipt reflects %d enrage_stacks" % exp["stacks"])
		_check(receipt["attack_bonus"] == exp["bonus"],
			"AC1: attack bonus is %d at stack %d" % [exp["bonus"], exp["stacks"]])
		_check(receipt["action"]["amount"] == exp["amount"],
			"AC1: attack 4 projects to %d damage at stack %d" % [exp["amount"], exp["stacks"]])
		_check(receipt["action"]["target_position"] == 2,
			"AC1: attack 4 preserves target_position 2 at stack %d" % exp["stacks"])

	# Missing enrage_stacks key defaults to 0 stacks (base amounts 3 and 4)
	var fresh_marshal := _living_marshal(null)
	_check(not fresh_marshal.has("enrage_stacks"), "AC1: fresh living Marshal has no enrage_stacks key")
	var fresh_3 := _project(fresh_marshal, attack_3, "AC1: fresh Marshal attack 3")
	_check(fresh_3["ok"] == true and fresh_3["applied"] == false
		and fresh_3["enrage_stacks"] == 0 and fresh_3["attack_bonus"] == 0
		and fresh_3["action"]["amount"] == 3,
		"AC1: absent enrage_stacks defaults to 0 stacks and base damage 3")
	var fresh_4 := _project(fresh_marshal, attack_4, "AC1: fresh Marshal attack 4")
	_check(fresh_4["ok"] == true and fresh_4["applied"] == false
		and fresh_4["enrage_stacks"] == 0 and fresh_4["attack_bonus"] == 0
		and fresh_4["action"]["amount"] == 4,
		"AC1: absent enrage_stacks defaults to 0 stacks and base damage 4")

	# Hard ceiling check: at maximum stacks (3), bonus is strictly +6
	var max_marshal := _living_marshal(3)
	var max_receipt := _project(max_marshal, attack_3, "AC1: ceiling check")
	_check(max_receipt["attack_bonus"] == 6 and max_receipt["action"]["amount"] == 9,
		"AC1: hard ceiling of +6 bonus confirmed at stack 3")


func _test_ac2_non_attack_and_non_enrage_passthrough() -> void:
	var actions := _marshal_encounter_actions()
	var buff_action: Dictionary = {}
	var shove_action: Dictionary = {}
	for act in actions:
		if act.get("type") == "buff":
			buff_action = act.duplicate(true)
		elif act.get("type") == "shove":
			shove_action = act.duplicate(true)

	_check(not buff_action.is_empty() and buff_action.get("amount") == 3,
		"AC2: authored Marshal buff has amount: 3")
	_check(not shove_action.is_empty() and shove_action.get("amount") == 0
		and shove_action.get("target_position") == 2 and shove_action.get("direction") == 1,
		"AC2: authored Marshal shove has amount: 0, target_position: 2, direction: 1")

	# AC2: for valid Marshal source at stacks 0..3, buff and shove actions are unchanged
	for stacks in [0, 1, 2, 3]:
		var marshal := _living_marshal(stacks)

		var buff_res := _project(marshal, buff_action, "AC2: buff at stack %d" % stacks)
		_check(buff_res["ok"] == true, "AC2: buff projection succeeds at stack %d" % stacks)
		_check(buff_res["applied"] == false, "AC2: buff projection applied is false at stack %d" % stacks)
		_check(buff_res["enrage_stacks"] == stacks, "AC2: buff receipt preserves enrage_stacks %d" % stacks)
		_check(buff_res["attack_bonus"] == 0, "AC2: buff receipt attack_bonus is 0 at stack %d" % stacks)
		_check(buff_res["action"] == buff_action,
			"AC2: buff action returned exactly unchanged at stack %d" % stacks)

		var shove_res := _project(marshal, shove_action, "AC2: shove at stack %d" % stacks)
		_check(shove_res["ok"] == true, "AC2: shove projection succeeds at stack %d" % stacks)
		_check(shove_res["applied"] == false, "AC2: shove projection applied is false at stack %d" % stacks)
		_check(shove_res["enrage_stacks"] == stacks, "AC2: shove receipt preserves enrage_stacks %d" % stacks)
		_check(shove_res["attack_bonus"] == 0, "AC2: shove receipt attack_bonus is 0 at stack %d" % stacks)
		_check(shove_res["action"] == shove_action,
			"AC2: shove action returned exactly unchanged at stack %d" % stacks)

	# AC2: weighted action fields from m04_elites.json preserved
	var elite_marshal := _catalog_record(ELITE_CATALOG_PATH, "needle_marshal")
	var elite_actions: Array = elite_marshal.get("intent", {}).get("actions", [])
	var weighted_buff: Dictionary = {}
	var weighted_shove: Dictionary = {}
	for raw in elite_actions:
		var weighted := CombatEnemyIntents.weighted_action(raw)
		var body: Dictionary = weighted.get("action", {}).duplicate(true)
		body["weight"] = weighted.get("weight", 0)
		if body.get("type") == "buff":
			weighted_buff = body
		elif body.get("type") == "shove":
			weighted_shove = body

	_check(weighted_buff.get("weight") == 1 and weighted_buff.get("amount") == 3,
		"AC2: intent buff has weight: 1 and amount: 3")
	_check(weighted_shove.get("weight") == 1 and weighted_shove.get("direction") == 1,
		"AC2: intent shove has weight: 1 and direction: 1")

	var marshal_stacked := _living_marshal(2)
	var w_buff_res := _project(marshal_stacked, weighted_buff, "AC2: weighted buff")
	_check(w_buff_res["ok"] == true and w_buff_res["action"] == weighted_buff
		and w_buff_res["action"]["weight"] == 1,
		"AC2: weighted buff preserves weight field")
	var w_shove_res := _project(marshal_stacked, weighted_shove, "AC2: weighted shove")
	_check(w_shove_res["ok"] == true and w_shove_res["action"] == weighted_shove
		and w_shove_res["action"]["weight"] == 1 and w_shove_res["action"]["direction"] == 1,
		"AC2: weighted shove preserves weight and direction fields")

	# AC2: other valid action types pass through unchanged
	var block_act := {"type": "block", "amount": 8}
	var debuff_act := {"type": "debuff", "status": "bleed", "amount": 2, "target_position": 1}
	var snip_act := {"type": "snip_block", "amount": 0, "target_position": 1}
	var summon_act := {"type": "summon", "amount": 0}
	for other_act in [block_act, debuff_act, snip_act, summon_act]:
		var other_res := _project(marshal_stacked, other_act, "AC2: other action " + other_act["type"])
		_check(other_res["ok"] == true and other_res["action"] == other_act
			and other_res["applied"] == false and other_res["attack_bonus"] == 0,
			"AC2: action type %s passes through unchanged" % other_act["type"])

	# AC2: non-Enrage authored enemy (spool_hexer) attack remains unchanged
	var hexer_raw := _catalog_record(ELITE_CATALOG_PATH, "spool_hexer")
	_check(hexer_raw.get("id") == "spool_hexer" and not hexer_raw.has("enrage"),
		"AC2: Spool Hexer has no Enrage keyword")
	var hexer_snapshot := hexer_raw.duplicate(true)
	hexer_snapshot["hp"] = hexer_raw["max_hp"]
	hexer_snapshot["block"] = 0
	hexer_snapshot["position"] = 1
	var hexer_attack := {"type": "attack", "amount": 9, "target_position": 1, "weight": 3}
	var hexer_res := _project(hexer_snapshot, hexer_attack, "AC2: non-Enrage hexer attack")
	_check(hexer_res["ok"] == true and hexer_res["applied"] == false
		and hexer_res["enrage_stacks"] == 0 and hexer_res["attack_bonus"] == 0
		and hexer_res["action"] == hexer_attack and hexer_res["action"]["amount"] == 9,
		"AC2: non-Enrage enemy attack passes through completely unchanged at amount 9")

	# AC2: disabled enrage flag with leftover stacks remains unchanged
	var disabled_enemy := hexer_snapshot.duplicate(true)
	disabled_enemy["enrage"] = false
	disabled_enemy["enrage_stacks"] = 2
	var disabled_res := _project(disabled_enemy, hexer_attack, "AC2: disabled enrage flag")
	_check(disabled_res["ok"] == true and disabled_res["applied"] == false
		and disabled_res["enrage_stacks"] == 0 and disabled_res["attack_bonus"] == 0
		and disabled_res["action"] == hexer_attack,
		"AC2: enemy with enrage: false grants no stack bonus even if enrage_stacks present")

	# AC2: exact detached comparison: mutating returned action does not mutate original
	var orig_attack := {"type": "attack", "amount": 4, "target_position": 2}
	var orig_copy := orig_attack.duplicate(true)
	var det_res := rules.project_enrage_action(marshal_stacked, orig_attack)
	det_res["action"]["amount"] = 999
	det_res["action"]["target_position"] = 999
	_check(orig_attack == orig_copy,
		"AC2: mutating returned action does not alter the caller's input action")


func _test_ac3_malformed_slain_and_rejections() -> void:
	var valid_marshal := _living_marshal(1)
	var valid_attack := {"type": "attack", "amount": 4, "target_position": 2}
	var failure_receipt := {
		"ok": false,
		"applied": false,
		"action": {},
		"enrage_stacks": 0,
		"attack_bonus": 0,
	}

	# AC3: Slain source metadata fails closed
	for slain_hp in [0, -1, -10]:
		var slain_enemy := valid_marshal.duplicate(true)
		slain_enemy["hp"] = slain_hp
		var res := _project(slain_enemy, valid_attack, "AC3: slain enemy hp %d" % slain_hp)
		_check(res == failure_receipt,
			"AC3: slain enemy with hp %d fails closed" % slain_hp)

	# AC3: Slain source from authentic CombatEnemies lethal damage
	var enemies := CombatEnemies.new([_catalog_record(ELITE_CATALOG_PATH, "needle_marshal")])
	_check(enemies.apply_damage(1, 28) and enemies.is_slain(1), "fixture: Marshal authentically slain")
	var live_slain := enemies.get_enemy(1)
	_check(live_slain.get("hp") == 0, "fixture: live slain enemy has hp 0")
	var slain_res := _project(live_slain, valid_attack, "AC3: live slain enemy")
	_check(slain_res == failure_receipt, "AC3: authentically slain enemy snapshot fails closed")

	# AC3: Malformed enemy snapshots fail closed
	var malformed_enemies: Array = [
		{},
		{"enrage": true},
		{"hp": 28},
		{"id": "needle_marshal"},
		{"hp": "28", "max_hp": 28, "enrage": true},
		{"hp": 28.5, "max_hp": 28, "enrage": true},
		{"hp": null, "max_hp": 28, "enrage": true},
		{"hp": 35, "max_hp": 28, "enrage": true}, # stale: hp > max_hp
		{"hp": 28, "max_hp": 0, "enrage": true},
		{"hp": 28, "max_hp": -1, "enrage": true},
		{"hp": 28, "max_hp": "28", "enrage": true},
		{"hp": 28, "max_hp": 28, "block": -1, "enrage": true},
		{"hp": 28, "max_hp": 28, "thorns": -1, "enrage": true},
		{"hp": 28, "max_hp": 28, "id": 123, "enrage": true},
		{"hp": 28, "max_hp": 28, "id": "", "enrage": true},
		{"hp": 28, "max_hp": 28, "position": 0, "enrage": true},
		{"hp": 28, "max_hp": 28, "position": 4, "enrage": true},
		{"hp": 28, "max_hp": 28, "position": -1, "enrage": true},
		{"hp": 28, "max_hp": 28, "enrage": 1},
		{"hp": 28, "max_hp": 28, "enrage": "true"},
		{"hp": 28, "max_hp": 28, "enrage": null},
		{"hp": 28, "max_hp": 28, "enrage": []},
		{"hp": 28, "max_hp": 28, "enrage": {}},
		null,
		123,
		"needle_marshal",
		[],
	]
	for bad_enemy in malformed_enemies:
		var res := _project(bad_enemy, valid_attack, "AC3: malformed enemy " + str(bad_enemy))
		_check(res == failure_receipt, "AC3: malformed enemy snapshot fails closed: " + str(bad_enemy))

	# AC3: Impossible stack counts fail closed
	var impossible_stacks: Array = [-1, 4, 5, 99, 1.5, "2", true, null, [], {}]
	for bad_stack in impossible_stacks:
		var bad_stack_enemy := valid_marshal.duplicate(true)
		bad_stack_enemy["enrage_stacks"] = bad_stack
		var res := _project(bad_stack_enemy, valid_attack, "AC3: impossible stack " + str(bad_stack))
		_check(res == failure_receipt, "AC3: impossible stack count %s fails closed" % str(bad_stack))

	# AC3: Negative, non-integer or malformed attack values fail closed
	var malformed_attacks: Array = [
		{},
		null,
		123,
		"attack",
		[],
		{"type": ""},
		{"type": 123},
		{"type": "unknown_action", "amount": 4},
		{"type": "attack"}, # missing amount
		{"type": "attack", "amount": -1, "target_position": 1},
		{"type": "attack", "amount": -4, "target_position": 1},
		{"type": "attack", "amount": 3.5, "target_position": 1},
		{"type": "attack", "amount": "4", "target_position": 1},
		{"type": "attack", "amount": null, "target_position": 1},
		{"type": "attack", "amount": true, "target_position": 1},
		{"type": "attack", "amount": [], "target_position": 1},
		{"type": "attack", "amount": 4, "target_position": 0},
		{"type": "attack", "amount": 4, "target_position": 4},
		{"type": "attack", "amount": 4, "target_position": -1},
		{"type": "attack", "amount": 4, "target_position": "1"},
		{"type": "attack", "amount": 4, "weight": -1},
		{"type": "attack", "amount": 4, "hits": 0},
		{"type": "attack", "amount": 4, "hits": -1},
		{"type": "buff", "amount": -1},
		{"type": "buff", "amount": "3"},
		{"type": "shove", "amount": 0, "direction": "left"},
	]
	for bad_action in malformed_attacks:
		var res := _project(valid_marshal, bad_action, "AC3: malformed action " + str(bad_action))
		_check(res == failure_receipt, "AC3: malformed action fails closed: " + str(bad_action))

	# Prove repeatable success after all rejections
	var post_reject_res := _project(valid_marshal, valid_attack, "AC3: valid action after rejections")
	_check(post_reject_res["ok"] == true and post_reject_res["action"]["amount"] == 6,
		"AC3: valid action still projects correctly after negative cases")


func _test_ac3_isolation_replay_and_rng() -> void:
	# Authoritative roster isolation
	var marshal_raw := _catalog_record(ELITE_CATALOG_PATH, "needle_marshal")
	var guard_raw := _catalog_record(STARTER_CATALOG_PATH, "ragling_guard")
	var enemies := CombatEnemies.new([marshal_raw.duplicate(true), guard_raw.duplicate(true)])
	_check(enemies.set_enrage_stacks(1, 2), "fixture: set marshal stacks to 2")
	var roster_before := enemies.get_enemies()
	var marshal_snap := enemies.get_enemy(1)
	var attack := {"type": "attack", "amount": 3, "target_position": 1}

	var res := _project(marshal_snap, attack, "AC3: roster isolation check")
	_check(res["ok"] == true and res["action"]["amount"] == 7,
		"AC3: projection succeeded with 3 + 4 = 7")
	_check(enemies.get_enemies() == roster_before,
		"AC3: projection call leaves authoritative CombatEnemies roster completely untouched")

	# Deterministic replay: 3 identical calls return identical receipts
	var first_res: Dictionary = {}
	for repeat in range(3):
		var snap := marshal_snap.duplicate(true)
		var act := attack.duplicate(true)
		var replay_res := rules.project_enrage_action(snap, act)
		_check(replay_res["ok"] == true and replay_res["action"]["amount"] == 7,
			"AC3: deterministic replay iteration %d" % repeat)
		if repeat == 0:
			first_res = replay_res.duplicate(true)
			# Mutate first returned receipt to test isolation
			replay_res["action"]["amount"] = 999
			replay_res["enrage_stacks"] = 99
		else:
			_check(replay_res == first_res,
				"AC3: replay %d exactly equals first result" % repeat)

	# RNG isolation: local seeded RandomNumberGenerator
	var rng := RandomNumberGenerator.new()
	rng.seed = 62831
	var rng_state_before := rng.state
	for i in range(5):
		rules.project_enrage_action(marshal_snap, attack)
	_check(rng.state == rng_state_before,
		"AC3: project_enrage_action consumes no local RandomNumberGenerator state")

	# RNG isolation: global randi() sequence
	seed(41982)
	var expected_global_1 := randi()
	var expected_global_2 := randi()
	seed(41982)
	rules.project_enrage_action(marshal_snap, attack)
	rules.project_enrage_action(marshal_snap, {"type": "buff", "amount": 3})
	_check(randi() == expected_global_1 and randi() == expected_global_2,
		"AC3: project_enrage_action consumes no global RNG state")


func _test_ac3_existing_regressions_green() -> void:
	# quote_enrage_after_hit
	var enemies := CombatEnemies.new([_catalog_record(ELITE_CATALOG_PATH, "needle_marshal")])
	var pre := enemies.get_enemy(1)
	var quote := rules.quote_enrage_after_hit(pre, {"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 5})
	_check(quote == {"ok": true, "applied": true, "enrage_stacks": 1, "attack_bonus": 2},
		"regression: quote_enrage_after_hit still grants 1 stack (+2)")

	# commit_enrage_after_hit
	var attacks_bridge := CombatStatusAttacks.new()
	var receipt := attacks_bridge.resolve_vs_enemy(enemies, 1, 4, {}, {})
	var commit := rules.commit_enrage_after_hit(enemies, 1, pre, receipt)
	_check(commit == {"ok": true, "applied": true, "enrage_stacks": 1, "attack_bonus": 2}
		and enemies.get_enemy(1).get("enrage_stacks") == 1,
		"regression: commit_enrage_after_hit still writes stack to roster")

	# resolve_thorns_retaliation
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	var thorns_res := rules.resolve_thorns_retaliation(party, 1, pre,
		{"ok": true, "damage": 4, "block_absorbed": 0, "hp_loss": 4})
	_check(thorns_res == {"ok": true, "applied": true, "thorns": 3, "block_absorbed": 0, "hp_loss": 3},
		"regression: resolve_thorns_retaliation still retaliates 3")

	# resolve_drain_after_hit
	var leech := CombatEnemies.new([{"id": "spool_leech", "max_hp": 42, "drain": true}])
	_check(leech.apply_damage(1, 10) and leech.get_enemy(1).get("hp") == 32, "fixture: wounded drain source")
	var drain_res := rules.resolve_drain_after_hit(leech, 1,
		{"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 5})
	_check(drain_res == {"ok": true, "applied": true, "healed": 5} and leech.get_enemy(1).get("hp") == 37,
		"regression: resolve_drain_after_hit still heals 5 HP")

	# project_charge_step
	var charge_windup := rules.project_charge_step(6, false)
	_check(charge_windup == {"ok": true, "kind": "wind_up", "damage": 0, "armed_next": true},
		"regression: project_charge_step wind-up intact")
	var charge_strike := rules.project_charge_step(6, true)
	_check(charge_strike == {"ok": true, "kind": "attack", "damage": 15, "armed_next": false},
		"regression: project_charge_step strike intact")

	# Stable API aliases
	var marshal := _living_marshal(2)
	var atk := {"type": "attack", "amount": 3, "target_position": 1}
	var canonical := rules.project_enrage_action(marshal, atk)
	var alias1 := rules.project_enrage_attack_action(marshal, atk)
	var alias2 := rules.project_enrage_attack(marshal, atk)
	_check(canonical == alias1 and canonical == alias2 and canonical["action"]["amount"] == 7,
		"API: project_enrage_attack_action and project_enrage_attack aliases match project_enrage_action")
