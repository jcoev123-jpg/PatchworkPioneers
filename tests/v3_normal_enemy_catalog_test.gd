extends SceneTree

const PATH := "res://data/enemies/run_enemies.json"

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_catalog_records_and_parsing()
	_test_three_slot_roster_and_weighted_slots()
	_test_fixed_seed_binding_and_alternatives()
	_test_negative_fixtures()
	if failures.is_empty():
		print("v3_normal_enemy_catalog_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("v3_normal_enemy_catalog_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _norm(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _norm(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_norm(item))
		return result
	if value is float and is_finite(value) and floorf(value) == value and absf(value) <= 9007199254740991.0:
		return int(value)
	return value

func _load_parsed() -> Array:
	var text := FileAccess.get_file_as_string(PATH)
	_check(not text.is_empty(), "run_enemies.json is readable")
	var parsed := RunTypedBattleRoster._parse_catalog_text(text)
	_check(parsed is Array and not parsed.is_empty(), "RunTypedBattleRoster._parse_catalog_text succeeds")
	return parsed if parsed is Array else []

func _find(records: Array, id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and record.get("id") == id:
			return record.duplicate(true)
	return {}

func _old_expected() -> Dictionary:
	return {
		"fray_scavenger": {"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14, "art_path": "res://assets/paper/enemies/fray_scavenger.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "attack", "amount": 3, "weight": 3},
				{"type": "block", "amount": 2, "weight": 2},
				{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1}]}},
		"button_guard": {"id": "button_guard", "name": "Button Guard", "max_hp": 16, "art_path": "res://assets/paper/enemies/button_guard.png",
			"intent": {"target": "front", "actions": [
				{"type": "attack", "amount": 2, "weight": 3},
				{"type": "block", "amount": 2, "weight": 2},
				{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
				{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]}},
		"spool_stalker": {"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14, "art_path": "res://assets/paper/enemies/spool_stalker.png",
			"intent": {"target": "exposed", "actions": [
				{"type": "attack", "amount": 2, "weight": 3},
				{"type": "block", "amount": 2, "weight": 2},
				{"type": "debuff", "amount": 1, "status": "exposed", "weight": 2},
				{"type": "buff", "amount": 2, "weight": 1}]}},
		"seam_ripper": {"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18, "art_path": "res://assets/paper/enemies/seam_ripper.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "attack", "amount": 4, "weight": 3},
				{"type": "block", "amount": 2, "weight": 2},
				{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
				{"type": "buff", "amount": 2, "weight": 1}]}},
		"felt_bulwark": {"id": "felt_bulwark", "name": "Felt Bulwark", "max_hp": 18, "art_path": "res://assets/paper/enemies/felt_bulwark.png",
			"intent": {"target": "front", "actions": [
				{"type": "attack", "amount": 2, "weight": 3},
				{"type": "block", "amount": 3, "weight": 3},
				{"type": "buff", "amount": 2, "weight": 1}]}},
		"moth_scribe": {"id": "moth_scribe", "name": "Moth Scribe", "max_hp": 14, "art_path": "res://assets/paper/enemies/moth_scribe.png",
			"intent": {"target": "exposed", "actions": [
				{"type": "attack", "amount": 2, "weight": 3},
				{"type": "debuff", "amount": 1, "status": "weak", "weight": 2},
				{"type": "block", "amount": 2, "weight": 1}]}},
		"pin_skitter": {"id": "pin_skitter", "name": "Pin Skitter", "max_hp": 13, "art_path": "res://assets/paper/enemies/pin_skitter.png",
			"intent": {"target": "random", "actions": [
				{"type": "attack", "amount": 2, "weight": 4},
				{"type": "shove", "amount": 0, "direction": 1, "weight": 1},
				{"type": "block", "amount": 1, "weight": 1}]}},
		"thread_biter": {"id": "thread_biter", "name": "Thread Biter", "max_hp": 15, "art_path": "res://assets/paper/enemies/thread_biter.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "attack", "amount": 3, "weight": 3},
				{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
				{"type": "block", "amount": 2, "weight": 1}]}}
	}

func _new_expected() -> Dictionary:
	return {
		"scissor_crab": {"id": "scissor_crab", "name": "Scissor Crab", "max_hp": 26, "art_path": "res://assets/paper/enemies/scissor_crab.png",
			"intent": {"target": "front", "actions": [
				{"type": "snip_block", "amount": 0, "weight": 2},
				{"type": "attack", "amount": 6, "weight": 3}]}},
		"thimble_beetle": {"id": "thimble_beetle", "name": "Thimble Beetle", "max_hp": 29, "art_path": "res://assets/paper/enemies/thimble_beetle.png",
			"intent": {"target": "front", "actions": [
				{"type": "block", "amount": 9, "weight": 3},
				{"type": "attack", "amount": 5, "weight": 2}]}},
		"zipper_snake": {"id": "zipper_snake", "name": "Zipper Snake", "max_hp": 24, "art_path": "res://assets/paper/enemies/zipper_snake.png",
			"intent": {"target": "front", "actions": [
				{"type": "shove", "amount": 0, "direction": -1, "weight": 2},
				{"type": "attack", "amount": 6, "weight": 3}]}}
	}

func _test_catalog_records_and_parsing() -> void:
	var parsed := _load_parsed()
	var ids: Array[String] = []
	for record in parsed:
		if record is Dictionary:
			ids.append(String(record.get("id", "")))
	for old_id in _old_expected().keys():
		_check(ids.has(old_id), "old enemy preserved: " + old_id)
		var record := _find(parsed, old_id)
		_check(not record.is_empty(), "old enemy record present: " + old_id)
		if not record.is_empty():
			_check(_norm(record) == _norm(_old_expected()[old_id]),
				"old enemy remains semantically identical: " + old_id)
	for new_id in _new_expected().keys():
		_check(ids.has(new_id), "new enemy appended: " + new_id)
		var record := _find(parsed, new_id)
		_check(not record.is_empty(), "new enemy record present: " + new_id)
		if not record.is_empty():
			_check(_norm(record) == _norm(_new_expected()[new_id]),
				"new enemy exact record: " + new_id)
			var spec: Variant = record.get("intent")
			_check(spec is Dictionary and spec.get("target") == "front",
				"new enemy target policy is front: " + new_id)
			var actions: Variant = spec.get("actions") if spec is Dictionary else null
			_check(actions is Array and not actions.is_empty(),
				"new enemy weighted actions exist: " + new_id)
			for raw in actions:
				_check(CombatEnemyIntents.weighted_action(raw) != {},
					"new enemy alternative validates: " + new_id + " " + str(raw))

func _test_three_slot_roster_and_weighted_slots() -> void:
	var parsed := _load_parsed()
	var selected: Array = []
	for new_id in ["scissor_crab", "thimble_beetle", "zipper_snake"]:
		var record := _find(parsed, new_id)
		_check(not record.is_empty(), "roster source present: " + new_id)
		if not record.is_empty():
			selected.append(record)
	var enemies := CombatEnemies.new(selected)
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"CombatEnemies.new creates a genuine three-slot roster")
	for position in range(1, 4):
		var enemy: Dictionary = enemies.get_enemy(position)
		_check(enemy.get("position") == position and enemy.get("hp") == enemy.get("max_hp")
			and enemy.get("block") == 0, "roster slot %d is initialized" % position)
	for index in range(selected.size()):
		var spec: Variant = selected[index].get("intent")
		var slot := CombatEnemyIntents._weighted_slot(index + 1, spec)
		_check(not slot.is_empty(), "weighted slot validates: " + String(selected[index].get("id", "")))
		_check(slot.get("target") == "front", "weighted slot keeps front policy")
		var actions: Array = slot.get("actions", [])
		_check(not actions.is_empty(), "weighted slot has alternatives")
		for entry in actions:
			_check(int(entry.get("weight", 0)) > 0, "weighted slot alternative has positive weight")

func _enemy(position: int, pattern: Array) -> Dictionary:
	return {"enemy_position": position, "pattern": pattern}

func _party() -> CombatParty:
	return CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])

func _bind(seed_value: int, selected: Array) -> Dictionary:
	var enemies := CombatEnemies.new(selected.duplicate(true))
	var party := _party()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scheduler := CombatEnemyIntents.new([
		_enemy(1, [{"type": "block", "amount": 1}]),
		_enemy(2, [{"type": "block", "amount": 1}]),
		_enemy(3, [{"type": "block", "amount": 1}])])
	var ok := scheduler.bind_battle(enemies, party, rng)
	return {"ok": ok, "enemies": enemies, "party": party, "rng": rng, "scheduler": scheduler}

func _test_fixed_seed_binding_and_alternatives() -> void:
	var parsed := _load_parsed()
	var selected: Array = []
	for new_id in ["scissor_crab", "thimble_beetle", "zipper_snake"]:
		selected.append(_find(parsed, new_id))
	var party := _party()
	_check(party.is_valid(), "precondition: valid CombatParty of three living heroes")
	for position in range(1, 4):
		_check(party.get_hero(position).get("hp", 0) > 0,
			"precondition: hero slot %d is living" % position)
	var first := _bind(918273, selected)
	var second := _bind(918273, selected)
	_check(first.ok and second.ok, "full three-enemy roster binds on identical seeds")
	_check(first.scheduler.is_bound() and second.scheduler.is_bound(), "binding is reported")
	var first_intents: Array = first.scheduler.get_intents()
	var second_intents: Array = second.scheduler.get_intents()
	_check(first_intents == second_intents, "bound first-turn intent repeats on identical seeds")
	_check(first.rng.state == second.rng.state, "bound RNG state repeats on identical seeds")
	var read_state: int = first.rng.state
	var read_intents: Array = first.scheduler.get_intents()
	_check(read_intents == first_intents and first.rng.state == read_state,
		"reading bound intents does not consume RNG")
	# Independent option validation for each authored alternative.
	var crab_spec: Variant = _find(parsed, "scissor_crab").get("intent")
	var beetle_spec: Variant = _find(parsed, "thimble_beetle").get("intent")
	var snake_spec: Variant = _find(parsed, "zipper_snake").get("intent")
	var crab_slot := CombatEnemyIntents._weighted_slot(1, crab_spec)
	var beetle_slot := CombatEnemyIntents._weighted_slot(2, beetle_spec)
	var snake_slot := CombatEnemyIntents._weighted_slot(3, snake_spec)
	var crab_actions: Array = crab_slot.get("actions", [])
	var beetle_actions: Array = beetle_slot.get("actions", [])
	var snake_actions: Array = snake_slot.get("actions", [])
	var found_snip := false
	var found_beetle_block := false
	var found_snake_shove := false
	var found_crab_attack := false
	var found_beetle_attack := false
	var found_snake_attack := false
	for entry in crab_actions:
		var action: Dictionary = entry.get("action", {})
		if action.get("type") == "snip_block":
			found_snip = found_snip or (int(action.get("amount", -1)) == 0)
		if action.get("type") == "attack":
			found_crab_attack = found_crab_attack or (int(action.get("amount", -1)) == 6)
	for entry in beetle_actions:
		var action: Dictionary = entry.get("action", {})
		if action.get("type") == "block":
			found_beetle_block = found_beetle_block or (int(action.get("amount", -1)) == 9)
		if action.get("type") == "attack":
			found_beetle_attack = found_beetle_attack or (int(action.get("amount", -1)) == 5)
	for entry in snake_actions:
		var action: Dictionary = entry.get("action", {})
		if action.get("type") == "shove":
			found_snake_shove = found_snake_shove or (int(action.get("direction", 0)) == -1)
		if action.get("type") == "attack":
			found_snake_attack = found_snake_attack or (int(action.get("amount", -1)) == 6)
	_check(found_snip, "Crab has an authentic 0-amount snip_block alternative")
	_check(found_beetle_block, "Beetle has a 9-Block alternative")
	_check(found_snake_shove, "Snake has a legal forward shove alternative")
	_check(found_crab_attack, "Crab basic attack deals 6")
	_check(found_beetle_attack, "Beetle basic attack deals 5")
	_check(found_snake_attack, "Snake basic attack deals 6")
	# Force each authored alternative to announce by binding a single-action roster,
	# so no particular guessed seed can make these checks pass by luck.
	for forced in [
		{"id": "scissor_crab", "action": {"type": "snip_block", "amount": 0, "weight": 1}, "amount": 0},
		{"id": "thimble_beetle", "action": {"type": "block", "amount": 9, "weight": 1}, "amount": 9},
		{"id": "zipper_snake", "action": {"type": "shove", "amount": 0, "direction": -1, "weight": 1}, "amount": 0}]:
		var record := _find(parsed, String(forced.id))
		_check(not record.is_empty(), "forced alternative source present: " + String(forced.id))
		if record.is_empty():
			continue
		var forced_record: Dictionary = record.duplicate(true)
		forced_record["intent"] = {"target": "front", "actions": [forced.action]}
		var forced_enemies := CombatEnemies.new([forced_record])
		var forced_rng := RandomNumberGenerator.new()
		forced_rng.seed = 7
		var forced_scheduler := CombatEnemyIntents.new([_enemy(1, [{"type": "block", "amount": 1}])])
		var bound := forced_enemies.is_valid() and forced_scheduler.bind_battle(forced_enemies, party, forced_rng)
		_check(bound, "forced alternative binds: " + String(forced.id))
		if not bound:
			continue
		var announced: Dictionary = forced_scheduler.get_intents()[0]
		_check(announced.get("type") == forced.action.type
			and int(announced.get("amount", -1)) == int(forced.amount),
			"forced alternative announces its authored effect: " + String(forced.id))
		if announced.get("type") in ["attack", "debuff", "shove", "snip_block"]:
			_check(announced.get("target_position") == 1,
				"forced alternative targets the front hero: " + String(forced.id))
		if String(forced.id) == "zipper_snake":
			# The authored pull from slot 2 to 1 is illegal for a front hero, so the
			# announcement is re-aimed to the living neighbour instead.
			_check(announced.get("direction") == 1
				and CombatEnemyIntents.shove_is_legal(party, 1, int(announced.get("direction", 0))),
				"forced forward shove from the front edge announces only a legal move")

func _test_negative_fixtures() -> void:
	# Duplicate ID rejection in catalog parsing.
	var duplicate_a := {"id": "a", "name": "A", "max_hp": 1, "art_path": "x",
		"intent": {"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 1}]}}
	var duplicate_b := duplicate_a.duplicate(true)
	duplicate_b["name"] = "B"
	duplicate_b["max_hp"] = 2
	duplicate_b["art_path"] = "y"
	var duplicate_text := JSON.stringify([duplicate_a, duplicate_b])
	var duplicate_parsed := RunTypedBattleRoster._parse_catalog_text(duplicate_text)
	_check(duplicate_parsed.is_empty(), "duplicate catalog ID is rejected")
	# Duplicate candidate actors are also refused by the roster rules, atomically.
	_check(not CombatEnemies.new([duplicate_a, duplicate_b]).is_valid(),
		"CombatEnemies rejects duplicate actor IDs")
	# Malformed candidate records fail the strict catalog parser.
	var zero_hp := {"id": "zero_hp", "name": "Zero", "max_hp": 0, "art_path": "x",
		"intent": {"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 1}]}}
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([zero_hp])).is_empty(),
		"non-positive catalog HP is rejected")
	var blank_id := zero_hp.duplicate(true)
	blank_id["id"] = " "
	blank_id["max_hp"] = 1
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([blank_id])).is_empty(),
		"blank catalog ID is rejected")
	# Invalid action rejection.
	_check(CombatEnemyIntents.weighted_action({"type": "attack", "amount": 1, "weight": 0}).is_empty(),
		"zero weight is rejected")
	_check(not CombatEnemyIntents.weighted_action({"type": "attack", "amount": 1, "weight": 1}).is_empty(),
		"valid weighted attack is accepted")
	_check(CombatEnemyIntents.weighted_action({"type": "attack", "amount": 1, "weight": 1, "target_position": 1}).is_empty(),
		"weighted authored action cannot carry target_position")
	_check(CombatEnemyIntents.weighted_action({"type": "attack", "amount": 1, "weight": 1, "extra": true}).is_empty(),
		"extra weighted action key is rejected")
	_check(CombatEnemyIntents._weighted_slot(1, {"target": "front", "actions": []}).is_empty(),
		"empty action list is rejected")
	_check(CombatEnemyIntents._weighted_slot(1, {"target": "bogus", "actions": [{"type": "attack", "amount": 1, "weight": 1}]}).is_empty(),
		"unknown target policy is rejected")
	# Invalid authored intent shapes fail closed before binding and publish nothing.
	var party := _party()
	var bad_intent := duplicate_a.duplicate(true)
	bad_intent["intent"] = {"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 0}]}
	var bad_roster := CombatEnemies.new([bad_intent])
	var bad_scheduler := CombatEnemyIntents.new([_enemy(1, [{"type": "block", "amount": 1}])])
	var bad_rng := RandomNumberGenerator.new()
	bad_rng.seed = 3
	var state_before: int = bad_rng.state
	var legacy_before: Array = bad_scheduler.get_intents()
	_check(bad_roster.is_valid() and not bad_scheduler.bind_battle(bad_roster, party, bad_rng),
		"zero-weight authored intent fails closed")
	_check(not bad_scheduler.is_bound() and bad_scheduler.get_intents() == legacy_before,
		"rejected intent publishes no weighted announcement and keeps its legacy schedule")
	_check(bad_rng.state == state_before, "rejected intent consumes no run RNG")
	# No illegal movement on an edge.
	_check(not CombatEnemyIntents.shove_is_legal(party, 1, -1),
		"forward shove from hero slot 1 is illegal at the edge")
	_check(not CombatEnemyIntents.shove_is_legal(party, 3, 1),
		"backward shove from hero slot 3 is illegal at the edge")
	_check(CombatEnemyIntents.shove_is_legal(party, 2, -1),
		"forward shove from hero slot 2 is legal")
	var edge_enemy := {"id": "zipper_snake", "max_hp": 24,
		"intent": {"target": "front", "actions": [{"type": "shove", "amount": 0, "direction": -1, "weight": 1}]}}
	var edge_roster := CombatEnemies.new([edge_enemy])
	var edge_scheduler := CombatEnemyIntents.new([_enemy(1, [{"type": "block", "amount": 1}])])
	var edge_rng := RandomNumberGenerator.new()
	edge_rng.seed = 11
	_check(edge_roster.is_valid() and edge_scheduler.bind_battle(edge_roster, party, edge_rng),
		"single authored shove roster binds")
	if edge_scheduler.is_bound():
		var announced: Dictionary = edge_scheduler.get_intents()[0]
		_check(announced.get("target_position") == 1 and announced.get("direction") == 1,
			"front-edge shove is announced away from the illegal edge")
		_check(CombatEnemyIntents.shove_is_legal(party, int(announced.get("target_position", 0)),
			int(announced.get("direction", 0))),
			"announced front-edge shove moves into a living neighbour")
	# A downed announced hero falls back to the policy target, and that fallback
	# shove is re-aimed away from the downed neighbour instead of off the board.
	var downed_party := _party()
	_check(downed_party.apply_damage(1, 40) and downed_party.is_downed(1),
		"precondition: front hero is genuinely downed")
	var resolved := CombatEnemyIntents.resolve_announced_action(downed_party,
		{"type": "shove", "amount": 0, "target_position": 1, "direction": -1, "enemy_position": 1},
		edge_roster)
	_check(resolved.get("target_position") == 2 and resolved.get("direction") == 1,
		"downed-target shove falls back and flips to a legal living neighbour")
	_check(CombatEnemyIntents.shove_is_legal(downed_party, int(resolved.get("target_position", 0)),
		int(resolved.get("direction", 0))), "resolved shove destination is living and in range")
