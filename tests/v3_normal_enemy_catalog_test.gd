extends SceneTree

const PATH := "res://data/enemies/run_enemies.json"

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_normal_attack_minimum()
	_test_catalog_records_and_parsing()
	_test_three_slot_roster_and_weighted_slots()
	_test_fixed_seed_binding_and_alternatives()
	_test_zipper_snake_forward_pull_phase()
	_test_trio_catalog_records()
	_test_hedgehog_thorns_through_typed_roster()
	_test_trio_seeded_announcements()
	_test_harder_normal_catalog_records()
	_test_harder_normal_seeded_announcements()
	_test_harder_normal_phase_actions()
	_test_hound_enrage()
	_test_needle_wasp_bleeding_sting()
	_test_moth_swarm_block_chew_catalog()
	_test_moth_swarm_block_chew_phase()
	_test_scissor_crab_block_snip_catalog()
	_test_scissor_crab_block_snip_phase()
	_test_thread_biter_lifesteal_catalog()
	_test_thread_biter_lifesteal_phase()
	_test_tough_normal_pair_live_catalog_and_bands()
	_test_tough_normal_pair_phase_actions()
	_test_crusher_harrier_doll_catalog_records()
	_test_crusher_harrier_doll_seeded_announcements()
	_test_crusher_harrier_doll_phase_actions()
	_test_thistle_patch_doll_thorns()
	_test_bobbin_bat_quilt_termite_catalog()
	_test_bobbin_bat_quilt_termite_seeded_announcements()
	_test_bobbin_bat_drain_phase()
	_test_quilt_termite_chew_phase()
	_test_bobbin_bat_quilt_termite_live_bands()
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
				{"type": "attack", "amount": 5, "weight": 3},
				{"type": "block", "amount": 2, "weight": 2},
				{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1}]}},
		"button_guard": {"id": "button_guard", "name": "Button Guard", "max_hp": 16, "art_path": "res://assets/paper/enemies/button_guard.png",
			"intent": {"target": "front", "actions": [
				{"type": "attack", "amount": 5, "weight": 3},
				{"type": "block", "amount": 2, "weight": 2},
				{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
				{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]}},
		"spool_stalker": {"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14, "art_path": "res://assets/paper/enemies/spool_stalker.png",
			"intent": {"target": "exposed", "actions": [
				{"type": "attack", "amount": 5, "weight": 3},
				{"type": "block", "amount": 2, "weight": 2},
				{"type": "debuff", "amount": 1, "status": "exposed", "weight": 2},
				{"type": "buff", "amount": 2, "weight": 1}]}},
		"seam_ripper": {"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18, "art_path": "res://assets/paper/enemies/seam_ripper.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "attack", "amount": 5, "weight": 3},
				{"type": "block", "amount": 2, "weight": 2},
				{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
				{"type": "buff", "amount": 2, "weight": 1}]}},
		"felt_bulwark": {"id": "felt_bulwark", "name": "Felt Bulwark", "max_hp": 18, "art_path": "res://assets/paper/enemies/felt_bulwark.png",
			"intent": {"target": "front", "actions": [
				{"type": "attack", "amount": 5, "weight": 3},
				{"type": "block", "amount": 3, "weight": 3},
				{"type": "buff", "amount": 2, "weight": 1}]}},
		"moth_scribe": {"id": "moth_scribe", "name": "Moth Scribe", "max_hp": 14, "art_path": "res://assets/paper/enemies/moth_scribe.png",
			"intent": {"target": "exposed", "actions": [
				{"type": "attack", "amount": 5, "weight": 3},
				{"type": "debuff", "amount": 1, "status": "weak", "weight": 2},
				{"type": "block", "amount": 2, "weight": 1}]}},
		"pin_skitter": {"id": "pin_skitter", "name": "Pin Skitter", "max_hp": 13, "art_path": "res://assets/paper/enemies/pin_skitter.png",
			"intent": {"target": "random", "actions": [
				{"type": "attack", "amount": 5, "weight": 4},
				{"type": "shove", "amount": 0, "direction": 1, "weight": 1},
				{"type": "block", "amount": 1, "weight": 1}]}},
		"thread_biter": {"id": "thread_biter", "name": "Thread Biter", "max_hp": 15, "drain": true, "art_path": "res://assets/paper/enemies/thread_biter.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "attack", "amount": 5, "weight": 3},
				{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
				{"type": "block", "amount": 2, "weight": 1}]}}
	}

func _new_expected() -> Dictionary:
	return {
		"scissor_crab": {"id": "scissor_crab", "name": "Scissor Crab", "max_hp": 26,
			"chew_block_on_attack": true,
			"art_path": "res://assets/paper/enemies/scissor_crab.png",
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

func _test_normal_attack_minimum() -> void:
	var starter := RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(
		"res://data/enemies/starter_enemies.json"))
	for expected in [
		{"id": "ragling", "name": "Ragling", "max_hp": 12,
			"art_path": "res://assets/paper/enemies/ragling.png",
			"intent": {"target": "front", "actions": [
				{"type": "attack", "amount": 5, "weight": 3}]}},
		{"id": "ragling_guard", "name": "Guard Ragling", "max_hp": 12,
			"art_path": "res://assets/paper/enemies/ragling_guard.png",
			"intent": {"target": "front", "actions": [
				{"type": "block", "amount": 1, "weight": 3}]}}
	]:
		_check(_norm(_find(starter, expected.id)) == expected,
			"starter record preserves all fields and the block-only Guard: " + expected.id)
	for record in starter + _load_parsed():
		for raw in record.intent.actions:
			var parsed := CombatEnemyIntents.weighted_action(raw)
			_check(not parsed.is_empty(), "ordinary-normal alternative validates: " + record.id)
			if not parsed.is_empty() and parsed.action.type == "attack":
				_check(parsed.action.amount >= 5 and parsed.action.amount <= 9,
					"every ordinary-normal attack meets the authored V3 5-9 range: " + record.id)

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
		if String(forced.id) == "zipper_snake":
			# The authored pull names the middle hero so it really moves forward;
			# reversing it into a push was the old front-edge workaround.
			_check(announced.get("target_position") == 2
				and announced.get("direction") == -1,
				"forced Zipper Snake pull announces the middle hero pulled forward")
			_check(CombatEnemyIntents.shove_is_legal(party, 2, -1),
				"precondition: the announced middle-to-front pull is legal")
		elif announced.get("type") in ["attack", "debuff", "shove", "snip_block"]:
			_check(announced.get("target_position") == 1,
				"forced alternative targets the front hero: " + String(forced.id))

## The authentic Zipper Snake pull, announced by the real bound scheduler and
## then executed by the real enemy phase: the middle hero is dragged forward and
## all three heroes keep their own HP, Block and statuses.
func _test_zipper_snake_forward_pull_phase() -> void:
	var parsed := _load_parsed()
	var snake := _find(parsed, "zipper_snake")
	_check(not snake.is_empty(), "authentic Zipper Snake source present for the pull phase")
	if snake.is_empty():
		return
	var authored_pull := _authored_alternative(snake, "shove", 0)
	_check(int(authored_pull.get("direction", 0)) == -1,
		"precondition: the authentic Snake pull is an authored direction -1 shove")
	if authored_pull.is_empty():
		return
	var party := _party()
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"precondition: Warden, Seamstress and Tinker fill slots 1-3")
	_check(party.apply_damage(1, 10) and party.gain_block(1, 5)
		and party.apply_damage(2, 4) and party.gain_block(2, 3)
		and party.apply_damage(3, 6),
		"precondition: every hero carries distinct HP and Block")
	party._heroes[0]["statuses"] = {"weak": 2}
	party._heroes[1]["statuses"] = {"exposed": 3}
	party._heroes[2]["statuses"] = {"bleed": 1}
	var before := {}
	for hero in party.get_heroes():
		before[hero.id] = hero.duplicate(true)
	# Detached single-action fixture: production weights 2/3 stay untouched.
	var pull := _force_normal_alternative(snake, authored_pull, party)
	if pull.is_empty():
		return
	var committed: int = pull.rng.state
	var announced: Array = pull.intents
	_check(announced.size() == 1 and announced[0].get("type") == "shove"
		and announced[0].get("enemy_position") == 1
		and announced[0].get("target_position") == 2
		and announced[0].get("direction") == -1,
		"the bound Snake announces hero 2 pulled toward the front slot")
	_check(CombatEnemyIntents.shove_is_legal(party, 2, -1),
		"precondition: the announced middle-to-front pull is legal")
	_check(pull.scheduler.get_intents() == announced and pull.rng.state == committed,
		"the genuine announcement replays without spending run RNG")
	var receipt := CombatEnemyPhase.new().execute_phase(party, pull.enemies, announced, null, true)
	_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
		"the genuine Snake pull resolves through a real CombatEnemyPhase")
	if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
		var event: Dictionary = receipt["events"][0]
		_check(event.get("type") == "shove" and event.get("enemy_position") == 1
			and event.get("target_position") == 2 and event.get("direction") == -1
			and event.get("applied") == true,
			"the phase applies exactly one middle-to-front pull")
	_check(party.get_hero(1).get("id") == "seamstress" and party.get_hero(1).get("position") == 1
		and party.get_hero(2).get("id") == "warden" and party.get_hero(2).get("position") == 2
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("position") == 3,
		"the pull swaps Seamstress to the front, moves Warden to the middle and keeps Tinker in the back")
	var after := {}
	for hero in party.get_heroes():
		after[hero.id] = hero
	for id in ["warden", "seamstress", "tinker"]:
		_check(after.has(id) and before.has(id), "the pull keeps the original actor " + id)
		if not after.has(id) or not before.has(id):
			continue
		_check(after[id].get("hp") == before[id].get("hp")
			and after[id].get("block") == before[id].get("block")
			and after[id].get("statuses", {}) == before[id].get("statuses", {}),
			"the pull preserves " + id + " HP, Block and statuses")

## The three tougher look-driven normal enemies of this batch. Numbers are the
## bounded v3 tuning from the brief; the design fixes identity and the 5-9
## normal attack band, not each individual weight.
func _trio_expected() -> Dictionary:
	return {
		"pincushion_hedgehog": {"id": "pincushion_hedgehog", "name": "Pincushion Hedgehog",
			"max_hp": 25, "thorns": 3,
			"art_path": "res://assets/paper/enemies/pincushion_hedgehog.png",
			"intent": {"target": "front", "actions": [
				{"type": "attack", "amount": 6, "weight": 3},
				{"type": "block", "amount": 6, "weight": 2}]}},
		"moth_swarm": {"id": "moth_swarm", "name": "Moth Swarm", "max_hp": 21,
			"chew_block_on_attack": true,
			"art_path": "res://assets/paper/enemies/moth_swarm.png",
			"intent": {"target": "front", "actions": [
				{"type": "snip_block", "amount": 0, "weight": 2},
				{"type": "attack", "amount": 7, "weight": 3},
				{"type": "debuff", "status": "weak", "amount": 1, "weight": 1}]}},
		"needle_wasp": {"id": "needle_wasp", "name": "Needle Wasp", "max_hp": 22,
			"bleed_on_attack": true,
			"art_path": "res://assets/paper/enemies/needle_wasp.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
				{"type": "attack", "amount": 8, "hits": 2, "weight": 3}]}}
	}

## True when the record really authors this action alternative.
func _has_alternative(record: Dictionary, kind: String, amount: int,
		status: String = "") -> bool:
	var spec: Variant = record.get("intent")
	if not spec is Dictionary:
		return false
	var actions: Variant = spec.get("actions")
	if not actions is Array:
		return false
	for raw in actions:
		if not raw is Dictionary or raw.get("type") != kind \
				or int(raw.get("amount", -1)) != amount:
			continue
		if status.is_empty() or raw.get("status") == status:
			return true
	return false

func _test_trio_catalog_records() -> void:
	var parsed := _load_parsed()
	var ids: Array[String] = []
	for record in parsed:
		if record is Dictionary:
			ids.append(String(record.get("id", "")))
	# All eleven earlier records stay authored exactly as they were; the batch
	# only appends. No total and no ordered list is asserted.
	var earlier_expectations := _old_expected()
	earlier_expectations.merge(_new_expected())
	for earlier in earlier_expectations:
		_check(ids.has(String(earlier)), "earlier enemy still present after this append: " + String(earlier))
		var kept := _find(parsed, String(earlier))
		_check(not kept.is_empty() and _norm(kept) == _norm(earlier_expectations[earlier]),
			"earlier enemy record is unchanged: " + String(earlier))
	var trio := _trio_expected()
	for new_id in trio:
		_check(ids.has(String(new_id)), "trio enemy is individually present: " + String(new_id))
		var record := _find(parsed, String(new_id))
		_check(not record.is_empty(), "trio enemy record present: " + String(new_id))
		if record.is_empty():
			continue
		_check(_norm(record) == _norm(trio[new_id]),
			"trio enemy has its exact authored fields: " + String(new_id))
		var spec: Variant = record.get("intent")
		var expected_target: String = trio[new_id]["intent"]["target"]
		_check(spec is Dictionary and spec.get("target") == expected_target,
			"trio enemy keeps its authored target policy: " + String(new_id))
		var actions: Variant = spec.get("actions") if spec is Dictionary else null
		_check(actions is Array and not actions.is_empty(),
			"trio enemy authors weighted action alternatives: " + String(new_id))
		for raw in actions:
			_check(CombatEnemyIntents.weighted_action(raw) != {},
				"trio alternative validates through the weighted scheduler: %s %s" % [new_id, str(raw)])
			var kind := String(raw.get("type", ""))
			# The V3 list also names summon and multi_hit; those need separately
			# scoped engine support, so this slice must not claim them.
			_check(kind in ["attack", "block", "debuff", "snip_block"],
				"trio alternative only uses currently supported mechanics: %s %s" % [new_id, kind])
			if kind == "attack":
				var amount := int(raw.get("amount", 0))
				_check(amount >= 5 and amount <= 9,
					"trio normal attack stays inside the authored 5-9 band: " + String(new_id))
	# Look-driven identity: every one of the three acts the way it looks.
	var hedgehog := _find(parsed, "pincushion_hedgehog")
	_check(int(hedgehog.get("thorns", -1)) == 3, "Hedgehog carries authored Thorns 3 metadata")
	_check(_has_alternative(hedgehog, "attack", 6) and _has_alternative(hedgehog, "block", 6),
		"Hedgehog bristles into a 6 attack or 6 Block")
	var moth := _find(parsed, "moth_swarm")
	_check(_has_alternative(moth, "snip_block", 0) and _has_alternative(moth, "attack", 7)
		and _has_alternative(moth, "debuff", 1, "weak"),
		"Moth Swarm chews Block away, bites for 7 or leaves Weak 1")
	var wasp := _find(parsed, "needle_wasp")
	_check(_has_alternative(wasp, "debuff", 2, "bleed") and _has_alternative(wasp, "attack", 8),
		"Needle Wasp stings Bleed 2 or hits for 8")
	_check(wasp.get("intent", {}).get("target") == "lowest_living_hp",
		"Needle Wasp hunts the lowest-living hero")
	# The bleeding sting is one authored boolean on this enemy alone; it is not
	# a new weighted alternative, so the two authored choices stay untouched.
	_check(wasp.get("bleed_on_attack") is bool and wasp.get("bleed_on_attack") == true,
		"Needle Wasp alone authors the boolean bleeding sting")
	var carriers: Array[String] = []
	for record in parsed:
		if record is Dictionary and record.get("bleed_on_attack") is bool \
				and record.get("bleed_on_attack") == true:
			carriers.append(String(record.get("id", "")))
	_check(carriers == ["needle_wasp"],
		"bleed_on_attack=true is authored by Needle Wasp and nobody else: " + str(carriers))
	var wasp_actions: Array = wasp.get("intent", {}).get("actions", [])
	_check(wasp_actions.size() == 2,
		"the bleeding sting adds no extra weighted action to Needle Wasp")

## Local typed-selection fixture for this authored slice: these enemies are not
## wired into any live encounter pool yet, so the schedule is supplied here while
## the catalog file, its strict parser and the CombatEnemies bridge stay real.
func _trio_choice(ids: Array) -> Dictionary:
	var definitions: Array = []
	for index in range(ids.size()):
		definitions.append({"enemy_position": index + 1,
			"pattern": [{"type": "attack", "amount": 5, "target_position": 1}]})
	return {"success": true, "node_type": "Fight", "encounter_id": "v3_trio_slice",
		"definitions": definitions}

func _assemble(ids: Array) -> Dictionary:
	return RunTypedBattleRoster.new().assemble(_trio_choice(ids),
		{"v3_trio_slice": ids}, [PATH])

## A genuine seeded starter deck whose real hand truly holds the wanted attack.
func _attack_deck(wanted: String) -> CombatDeck:
	var cards := StarterCards.new().get_starting_deck()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4261
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3 and deck.hand.size() == 5,
		"authentic seeded deck starts with five held cards and three energy")
	var guard := 0
	while not deck.hand.has(wanted) and not deck.draw_pile.is_empty() and guard <= cards.size():
		_check(deck.draw_extra(1) == 1, "draw_extra advances a genuine draw")
		guard += 1
	_check(deck.hand.has(wanted), "the chosen authored attack is genuinely held: " + wanted)
	return deck

func _test_hedgehog_thorns_through_typed_roster() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_check(raw is Array, "raw enemy catalog JSON parses for the Thorns precondition")
	var raw_hedgehog := _find(raw if raw is Array else [], "pincushion_hedgehog")
	_check(raw_hedgehog.get("thorns") is float and raw_hedgehog.get("thorns") == 3.0,
		"precondition: authored Thorns arrives from JSON as a double")
	_check(_find(_load_parsed(), "pincushion_hedgehog").get("thorns") is int,
		"the strict catalog parser normalizes Thorns to a genuine int")
	var answer := _assemble(["pincushion_hedgehog", "moth_swarm"])
	_check(answer.get("ok") == true,
		"Hedgehog roster assembles through the genuine typed-roster bridge")
	if not answer.get("ok", false):
		return
	var enemies: Variant = answer.get("enemies")
	_check(enemies is CombatEnemies and enemies.is_valid()
		and enemies.get_enemies().size() == 2, "the bridge builds two real actors")
	if not enemies is CombatEnemies or not enemies.is_valid():
		return
	var hedgehog: Dictionary = enemies.get_enemy(1)
	_check(hedgehog.get("id") == "pincushion_hedgehog" and hedgehog.get("max_hp") == 25
		and hedgehog.get("hp") == 25 and hedgehog.get("block") == 0,
		"typed Hedgehog starts at its authored 25 HP and zero Block")
	_check(hedgehog.get("thorns") is int and hedgehog.get("thorns") == 3,
		"typed roster exposes Thorns as a genuine int 3, never a JSON double")
	var party := _party()
	var deck := _attack_deck("warden_strike")
	_check(party.gain_block(1, 2), "Warden really owns two Block before the confirmed hit")
	var party_before := party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	_check(party_before[0].get("hp") == 40 and party_before[0].get("block") == 2,
		"precondition: living Warden at 40 HP with 2 Block")
	var attacks := CombatAttackCards.new()
	var forecast := attacks.forecast_attack(deck, party, enemies, "warden_strike")
	_check(forecast.get("playable") == true and forecast.get("hits", []).size() == 2
		and {"position": 1, "damage": 6} in forecast.get("hits", []),
		"the real held Strike forecast offers the Hedgehog at its computed six damage")
	_check(party.get_heroes() == party_before and enemies.get_enemies() == enemies_before,
		"a pure forecast never triggers Thorns nor damages any actor")
	var result := attacks.play_attack(deck, party, enemies, "warden_strike", 1)
	_check(result.get("ok") == true and result.get("hits", []).size() == 1,
		"the real held-card attack against the Hedgehog commits")
	var hit: Dictionary = result.get("hits", [{}])[0]
	_check(hit.get("position") == 1 and hit.get("damage") == 6
		and hit.get("block_absorbed") == 0 and hit.get("hp_loss") == 6,
		"confirmed-hit receipt keeps the authored six damage and the old schema")
	_check(enemies.get_enemy(1).get("hp") == 19,
		"the Hedgehog takes the confirmed six damage")
	var warden: Dictionary = party.get_hero(1)
	_check(warden.get("block") == 0 and warden.get("hp") == 39,
		"Thorns 3 retaliates against the attacker through Block before HP")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		"Thorns retaliation lands only on the attacking hero")
	# Control: a confirmed hit on the non-thorned authored Moth Swarm never
	# retaliates, so a green Hedgehog hit cannot merely echo shared damage.
	var control_party := _party()
	var control_deck := _attack_deck("warden_strike")
	var control_answer := _assemble(["pincushion_hedgehog", "moth_swarm"])
	_check(control_answer.get("ok") == true, "control roster assembles for the no-Thorns hit")
	if not control_answer.get("ok", false):
		return
	var control_enemies: CombatEnemies = control_answer["enemies"]
	_check(not control_enemies.get_enemy(2).has("thorns"),
		"precondition: the authored Moth Swarm carries no Thorns metadata")
	var control := CombatAttackCards.new().play_attack(control_deck, control_party,
		control_enemies, "warden_strike", 2)
	_check(control.get("ok") == true and control_party.get_hero(1).get("hp") == 40
		and control_party.get_hero(1).get("block") == 0,
		"a confirmed hit on a non-thorned enemy costs the attacker nothing")
	# Control: an uncommitted, rejected attack triggers nothing and spends nothing.
	var rejected_party := _party()
	var rejected_deck := _attack_deck("warden_strike")
	var rejected_answer := _assemble(["pincushion_hedgehog"])
	_check(rejected_answer.get("ok") == true, "single Hedgehog roster assembles for the rejection control")
	if not rejected_answer.get("ok", false):
		return
	var rejected_enemies: CombatEnemies = rejected_answer["enemies"]
	var rejected := CombatAttackCards.new().play_attack(rejected_deck, rejected_party,
		rejected_enemies, "warden_strike", 3)
	_check(rejected == {"ok": false, "hits": []}
		and rejected_party.get_hero(1).get("hp") == 40
		and rejected_party.get_hero(1).get("block") == 0
		and rejected_enemies.get_enemy(1).get("hp") == 25
		and rejected_deck.hand.has("warden_strike") and rejected_deck.energy == 3,
		"a rejected zero-hit attack never triggers Thorns and mutates nothing")

## True when the announcement body is one of the record's authored alternatives.
func _is_authored_alternative(record: Dictionary, announced: Dictionary) -> bool:
	var spec: Variant = record.get("intent")
	if not spec is Dictionary:
		return false
	var body: Dictionary = {}
	for key in announced:
		if key in ["enemy_position", "target_position"]:
			continue
		body[key] = announced[key]
	var actions: Variant = spec.get("actions")
	if not actions is Array:
		return false
	for raw in actions:
		if not raw is Dictionary:
			continue
		var authored: Dictionary = {}
		for key in raw:
			if key == "weight":
				continue
			authored[key] = raw[key]
		if _norm(authored) == _norm(body):
			return true
	return false

## Resolve a real Moth Swarm Block snip through the genuine special-action service.
func _resolve_snip(announced: Dictionary, enemies: CombatEnemies) -> void:
	var party := _party()
	_check(party.gain_block(1, 5) and party.get_hero(1).get("block") == 5,
		"precondition: the front hero really holds five Block")
	var receipt := CombatEnemySpecialActions.new().execute_actions(party, enemies, [announced])
	_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1
		and receipt["events"][0].get("applied") == true,
		"Moth Block snip resolves as a real enemy special action")
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(1).get("hp") == 40,
		"snip sets the target's Block to zero without dealing HP damage")

## Resolve a real Weak/Bleed application through the genuine special-action service.
func _resolve_debuff(announced: Dictionary, enemies: CombatEnemies, status: String) -> void:
	var party := _party()
	var target := int(announced.get("target_position", 0))
	_check(target >= 1 and target <= CombatParty.PARTY_SIZE and not party.is_downed(target),
		"precondition: the announced debuff target is a living hero")
	if target < 1 or target > CombatParty.PARTY_SIZE:
		return
	var receipt := CombatEnemySpecialActions.new().execute_actions(party, enemies, [announced])
	_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1
		and receipt["events"][0].get("applied") == true,
		"the announced debuff resolves as a real enemy special action")
	_check(party.get_hero(target).get("statuses", {}).get(status, 0)
		== int(announced.get("amount", 0)),
		"the announced %s amount lands on the policy target" % status)
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		if position == target:
			continue
		_check(party.get_hero(position).get("statuses", {}).get(status, 0) == 0,
			"unaffected hero %d gains no %s" % [position, status])

func _test_trio_seeded_announcements() -> void:
	var parsed := _load_parsed()
	var trio: Array = []
	for id in ["pincushion_hedgehog", "moth_swarm", "needle_wasp"]:
		var record := _find(parsed, id)
		_check(not record.is_empty(), "authentic trio source present: " + id)
		trio.append(record)
	_check(trio.size() == 3, "precondition: all three authentic records loaded")
	if trio.size() != 3:
		return
	var party := _party()
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"precondition: an authentic three-hero party")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		"precondition: lowest living HP is the back hero, so policies differ")
	var bound := _bind(4261, trio)
	_check(bound.get("ok") == true and bound.scheduler.is_bound(),
		"the authentic three-slot trio binds seeded weighted intents")
	_check(bound.party.get_heroes() == _party().get_heroes(),
		"seeded intent selection never applies Hedgehog Thorns early")
	if bound.get("ok", false):
		var enemies: CombatEnemies = bound["enemies"]
		_check(CombatEnemyIntents.policy_for(enemies, 1) == "front"
			and CombatEnemyIntents.policy_for(enemies, 2) == "front"
			and CombatEnemyIntents.policy_for(enemies, 3) == "lowest_living_hp",
			"the seeded roster keeps every authored target policy")
		var intents: Array = bound.scheduler.get_intents()
		_check(intents.size() == 3, "the seeded roster announces once per authentic slot")
		for index in range(intents.size()):
			var announced: Dictionary = intents[index]
			var source: Dictionary = trio[index]
			var enemy_id := String(source.get("id", ""))
			_check(announced.get("enemy_position") == index + 1,
				"announcement keeps its original source slot: " + enemy_id)
			_check(_is_authored_alternative(source, announced),
				"announcement is one of the authored alternatives: " + enemy_id)
			if announced.get("type") in ["attack", "debuff", "snip_block"]:
				var expected_target := 1 if source["intent"]["target"] == "front" else 3
				_check(announced.get("target_position") == expected_target,
					"announcement applies the authored target policy: " + enemy_id)
		var replay := _bind(4261, trio)
		_check(replay.get("ok") == true and replay.scheduler.get_intents() == intents
			and replay.rng.state == bound.rng.state,
			"seeded trio announcements and RNG state replay exactly")
	# Force every authored alternative, so no guessed seed can hide one.
	var forced := [
		{"id": "pincushion_hedgehog", "target": "front",
			"action": {"type": "attack", "amount": 6, "weight": 1}},
		{"id": "pincushion_hedgehog", "target": "front",
			"action": {"type": "block", "amount": 6, "weight": 1}},
		{"id": "moth_swarm", "target": "front",
			"action": {"type": "snip_block", "amount": 0, "weight": 1}},
		{"id": "moth_swarm", "target": "front",
			"action": {"type": "attack", "amount": 7, "weight": 1}},
		{"id": "moth_swarm", "target": "front",
			"action": {"type": "debuff", "status": "weak", "amount": 1, "weight": 1}},
		{"id": "needle_wasp", "target": "lowest_living_hp",
			"action": {"type": "debuff", "status": "bleed", "amount": 2, "weight": 1}},
		{"id": "needle_wasp", "target": "lowest_living_hp",
			"action": {"type": "attack", "amount": 8, "weight": 1}}]
	for case in forced:
		var record := _find(parsed, String(case.id))
		_check(not record.is_empty(), "forced alternative source present: " + String(case.id))
		if record.is_empty():
			continue
		var forced_record: Dictionary = record.duplicate(true)
		forced_record["intent"] = {"target": case.target, "actions": [case.action]}
		var forced_enemies := CombatEnemies.new([forced_record])
		var forced_rng := RandomNumberGenerator.new()
		forced_rng.seed = 4261
		var forced_scheduler := CombatEnemyIntents.new([_enemy(1, [{"type": "block", "amount": 1}])])
		var did_bind := forced_enemies.is_valid() \
			and forced_scheduler.bind_battle(forced_enemies, party, forced_rng)
		_check(did_bind, "forced alternative binds: %s %s" % [case.id, str(case.action)])
		if not did_bind:
			continue
		var announced: Dictionary = forced_scheduler.get_intents()[0]
		_check(announced.get("type") == case.action.type
			and int(announced.get("amount", -1)) == int(case.action.amount),
			"forced alternative announces its authored effect: %s %s" % [case.id, str(case.action)])
		if case.action.has("status"):
			_check(announced.get("status") == case.action.status,
				"forced debuff keeps its authored status: " + String(case.action.status))
		if announced.get("type") in ["attack", "debuff", "snip_block"]:
			var expected := 1 if case.target == "front" else 3
			_check(announced.get("target_position") == expected,
				"forced alternative honours the authored target policy: " + String(case.id))
		if announced.get("type") == "snip_block":
			_resolve_snip(announced, forced_enemies)
		elif announced.get("type") == "debuff":
			_resolve_debuff(announced, forced_enemies, String(case.action.status))

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
	# Optional authored Thorns metadata must be a genuine nonnegative integer.
	var thorned := {"id": "thorn_fixture", "name": "Thorn", "max_hp": 10, "thorns": 3,
		"art_path": "x", "intent": {"target": "front",
			"actions": [{"type": "attack", "amount": 1, "weight": 1}]}}
	var thorned_parsed := RunTypedBattleRoster._parse_catalog_text(JSON.stringify([thorned]))
	_check(thorned_parsed.size() == 1 and thorned_parsed[0].get("thorns") is int
		and thorned_parsed[0].get("thorns") == 3,
		"integral JSON Thorns normalizes to a genuine int")
	var thornless := thorned.duplicate(true)
	thornless["id"] = "thornless_fixture"
	thornless.erase("thorns")
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([thornless])).size() == 1,
		"absent Thorns metadata stays optional")
	for invalid_thorns in [-1, -1.0, 2.5, "3", true, null, []]:
		var malformed_thorns := thorned.duplicate(true)
		malformed_thorns["thorns"] = invalid_thorns
		_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([malformed_thorns])).is_empty(),
			"invalid Thorns metadata rejects the whole catalog: " + str(invalid_thorns))
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
		_check(announced.get("target_position") == 2 and announced.get("direction") == -1,
			"front-policy forward pull announces the middle hero, never a reversed push")
		_check(CombatEnemyIntents.shove_is_legal(party, int(announced.get("target_position", 0)),
			int(announced.get("direction", 0))),
			"announced forward pull moves into a living neighbour")
	# A valid party with no legal forward pair keeps the pre-existing safe
	# handling: no illegal swap and no extra run RNG draw.
	var gapped := _party()
	_check(gapped.apply_damage(2, 30) and gapped.is_downed(2),
		"precondition: the middle hero is genuinely downed")
	var gapped_roster := CombatEnemies.new([edge_enemy.duplicate(true)])
	var gapped_scheduler := CombatEnemyIntents.new([_enemy(1, [{"type": "block", "amount": 1}])])
	var gapped_rng := RandomNumberGenerator.new()
	gapped_rng.seed = 12
	_check(gapped_roster.is_valid()
		and gapped_scheduler.bind_battle(gapped_roster, gapped, gapped_rng),
		"a party with no legal forward pair still binds its authored shove")
	if gapped_scheduler.is_bound():
		var gapped_committed: int = gapped_rng.state
		var gapped_action: Dictionary = gapped_scheduler.get_intents()[0]
		var gapped_target: int = int(gapped_action.get("target_position", 0))
		var gapped_direction: int = int(gapped_action.get("direction", 0))
		var gapped_body: Dictionary = gapped_action.duplicate(true)
		gapped_body.erase("enemy_position")
		_check(CombatEnemyIntents.valid_action(gapped_body),
			"the no-pair announcement is still a structurally valid action")
		_check(not CombatEnemyIntents.shove_is_legal(gapped, gapped_target, gapped_direction),
			"precondition: the gapped party has no legal forward pair")
		var gapped_heroes: Array = gapped.get_heroes()
		var gapped_enemies: Array = gapped_roster.get_enemies()
		var gapped_receipt := CombatEnemyPhase.new().execute_phase(gapped, gapped_roster,
			[gapped_action], null, true)
		_check(gapped_receipt.get("ok") == true
			and gapped_receipt.get("events", []).size() == 1
			and gapped_receipt["events"][0].get("applied") == false,
			"a forward pull with no legal pair stays an inert ordered beat")
		_check(gapped.get_heroes() == gapped_heroes
			and gapped_roster.get_enemies() == gapped_enemies,
			"the inert forward pull leaves every hero and enemy unchanged")
		_check(gapped_rng.state == gapped_committed
			and gapped_scheduler.get_intents() == [gapped_action],
			"the inert forward pull neither re-rolls nor spends run RNG")
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

## The three harder look-driven normals of this batch. Identity, HP and the
## exact weighted intent are author-set for this bounded V3-2 slice; the design
## fixes only the 5-9 floor-1-4 normal attack band, which every attack obeys.
func _harder_expected() -> Dictionary:
	return {
		"shearwing_mantis": {"id": "shearwing_mantis", "name": "Shearwing Mantis",
			"max_hp": 26, "chew_block_on_attack": true,
			"art_path": "res://assets/paper/enemies/shearwing_mantis.png",
			"intent": {"target": "front", "actions": [
				{"type": "snip_block", "amount": 0, "weight": 2},
				{"type": "attack", "amount": 8, "weight": 3}]}},
		"spoolback_hound": {"id": "spoolback_hound", "name": "Spoolback Hound",
			"max_hp": 28, "enrage": true, "art_path": "res://assets/paper/enemies/spoolback_hound.png",
			"intent": {"target": "front", "actions": [
				{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
				{"type": "attack", "amount": 7, "weight": 3}]}},
		"inkbrush_imp": {"id": "inkbrush_imp", "name": "Inkbrush Imp",
			"max_hp": 23, "art_path": "res://assets/paper/enemies/inkbrush_imp.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "debuff", "amount": 2, "status": "exposed", "weight": 2},
				{"type": "attack", "amount": 6, "weight": 3}]}}
	}

## True when the authored alternative carries exactly the keys its supported
## kind needs, so no invented field or unsupported type can slip in.
func _alternative_shape_is_exact(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var expected: Array = []
	match String(raw.get("type", "")):
		"attack", "snip_block", "block":
			expected = ["amount", "type", "weight"]
		"shove":
			expected = ["amount", "direction", "type", "weight"]
		"debuff":
			expected = ["amount", "status", "type", "weight"]
		_:
			return false
	var actual: Array = raw.keys()
	actual.sort()
	expected.sort()
	return actual == expected

func _test_harder_normal_catalog_records() -> void:
	var parsed := _load_parsed()
	var ids: Array[String] = []
	for record in parsed:
		if record is Dictionary:
			ids.append(String(record.get("id", "")))
	# The fourteen earlier records stay exactly as authored; this batch only
	# appends, so no global total and no ordered list is asserted.
	var earlier := _old_expected()
	earlier.merge(_new_expected())
	earlier.merge(_trio_expected())
	for kept_id in earlier:
		_check(ids.has(String(kept_id)),
			"earlier normal still present after this append: " + String(kept_id))
		_check(_norm(_find(parsed, String(kept_id))) == _norm(earlier[kept_id]),
			"earlier normal record is unchanged: " + String(kept_id))
	var harder := _harder_expected()
	for new_id in harder:
		var occurrences := 0
		for present in ids:
			if present == String(new_id):
				occurrences += 1
		_check(occurrences == 1, "harder normal is authored exactly once: " + String(new_id))
		var record := _find(parsed, String(new_id))
		_check(not record.is_empty(), "harder normal record present: " + String(new_id))
		if record.is_empty():
			continue
		_check(_norm(record) == _norm(harder[new_id]),
			"harder normal has its exact authored fields: " + String(new_id))
		var spec: Variant = record.get("intent")
		_check(spec is Dictionary
			and spec.get("target") == harder[new_id]["intent"]["target"],
			"harder normal keeps its authored target policy: " + String(new_id))
		_check(not CombatEnemyIntents._weighted_slot(1, spec).is_empty(),
			"harder normal intent validates as a weighted slot: " + String(new_id))
		var actions: Variant = spec.get("actions") if spec is Dictionary else null
		_check(actions is Array and not actions.is_empty(),
			"harder normal authors weighted action alternatives: " + String(new_id))
		if not actions is Array:
			continue
		for raw in actions:
			_check(CombatEnemyIntents.weighted_action(raw) != {},
				"harder alternative validates through the weighted scheduler: %s %s"
					% [new_id, str(raw)])
			_check(_alternative_shape_is_exact(raw),
				"harder alternative uses supported mechanics and exact fields: %s %s"
					% [new_id, str(raw)])
			if raw is Dictionary and raw.get("type") == "attack":
				var amount := int(raw.get("amount", 0))
				_check(amount >= 5 and amount <= 9,
					"harder normal attack stays inside the authored 5-9 band: " + String(new_id))
	# Look-driven identity: each enemy's signature move is unmistakable.
	var mantis := _find(parsed, "shearwing_mantis")
	_check(_has_alternative(mantis, "snip_block", 0) and _has_alternative(mantis, "attack", 8),
		"Shearwing Mantis shears the front Block away or hits for 8")
	var hound := _find(parsed, "spoolback_hound")
	_check(_has_alternative(hound, "shove", 0) and _has_alternative(hound, "attack", 7),
		"Spoolback Hound leashes a +1 shove or bites for 7")
	var imp := _find(parsed, "inkbrush_imp")
	_check(_has_alternative(imp, "debuff", 2, "exposed") and _has_alternative(imp, "attack", 6),
		"Inkbrush Imp marks Exposed 2 or hits for 6")
	_check(imp.get("intent", {}).get("target") == "lowest_living_hp",
		"Inkbrush Imp marks the lowest-living hero")

## Three independent source records bound with two separately seeded real
## schedulers; identical seeds must replay first and successive announcements
## while reads never consume RNG and the parsed sources stay detached.
func _test_harder_normal_seeded_announcements() -> void:
	var parsed := _load_parsed()
	var selected: Array = []
	for id in ["shearwing_mantis", "spoolback_hound", "inkbrush_imp"]:
		var record := _find(parsed, id)
		_check(not record.is_empty(), "authentic harder normal source present: " + id)
		selected.append(record)
	_check(selected.size() == 3, "precondition: all three authentic records loaded")
	if selected.size() != 3 or selected.has({}):
		return
	var party := _party()
	_check(party.is_valid() and party.get_heroes().size() == CombatParty.PARTY_SIZE,
		"precondition: a valid three-hero CombatParty")
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		_check(party.get_hero(position).get("hp", 0) > 0,
			"precondition: hero slot %d is living" % position)
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		"precondition: the back hero is the unique lowest-living target")
	var snapshot: Array = selected.duplicate(true)
	var first := _bind(582201, selected)
	var second := _bind(582201, selected)
	_check(first.get("ok") == true and second.get("ok") == true,
		"the three harder normals bind on identical seeds")
	_check(first.scheduler.is_bound() and second.scheduler.is_bound(),
		"both seeded bindings report the weighted mode")
	var first_intents: Array = first.scheduler.get_intents()
	var second_intents: Array = second.scheduler.get_intents()
	_check(first_intents.size() == 3, "one announcement per harder normal")
	_check(first_intents == second_intents,
		"same-seed first-turn announcements replay identically")
	_check(first.rng.state == second.rng.state,
		"same-seed bindings leave matching RNG state")
	var state_before: int = first.rng.state
	var reread: Array = first.scheduler.get_intents()
	_check(reread == first_intents and first.rng.state == state_before,
		"repeated reads neither change announcements nor consume RNG")
	_check(first.scheduler.advance_turn(), "the first seeded schedule advances a turn")
	_check(second.scheduler.advance_turn(), "the second seeded schedule advances a turn")
	var first_next: Array = first.scheduler.get_intents()
	_check(first_next.size() == 3 and first_next == second.scheduler.get_intents(),
		"successive announced turns replay identically on equal seeds")
	_check(first.rng.state == second.rng.state,
		"successive turns keep matching RNG state")
	for index in range(first_intents.size()):
		var announced: Dictionary = first_intents[index]
		var source: Dictionary = selected[index]
		_check(announced.get("enemy_position") == index + 1,
			"announcement keeps its source slot: " + String(source.get("id", "")))
		_check(_is_authored_alternative(source, announced),
			"announcement is an authored alternative: " + String(source.get("id", "")))
		if announced.get("type") in ["attack", "debuff", "snip_block", "shove"]:
			var expected_target := 1 \
				if String(source.get("intent", {}).get("target", "")) == "front" else 3
			_check(announced.get("target_position") == expected_target,
				"announcement applies the authored target policy: " + String(source.get("id", "")))
		for field in ["type", "amount", "status", "direction"]:
			if not announced.has(field):
				continue
			var chosen: bool = false
			for raw in source.get("intent", {}).get("actions", []):
				if raw is Dictionary and raw.get("type") == announced.get("type") \
						and int(raw.get("amount", -1)) == int(announced.get("amount", -2)) \
						and raw.get(field) == announced.get(field):
					chosen = true
			_check(chosen, "announcement field %s matches an authored alternative: %s"
				% [field, String(source.get("id", ""))])
	_check(selected == snapshot,
		"weighted binding never mutates the parsed source records")
	_check(_norm(_find(_load_parsed(), "shearwing_mantis"))
		== _norm(_harder_expected()["shearwing_mantis"]),
		"the parsed catalog stays detached after binding")
	# Independent option validation for every authored alternative.
	for id in ["shearwing_mantis", "spoolback_hound", "inkbrush_imp"]:
		var record := _find(parsed, id)
		var spec: Variant = record.get("intent")
		var slot := CombatEnemyIntents._weighted_slot(1, spec)
		_check(not slot.is_empty(), "authored harder slot validates: " + id)
		var actions: Array = slot.get("actions", [])
		_check(actions.size() == 2, "authored harder slot keeps both alternatives: " + id)
		for entry in actions:
			_check(int(entry.get("weight", 0)) > 0,
				"authored harder alternative has a positive weight: " + id)

## The authored alternative of one kind/amount in a parsed record, so forced
## encounters carry the genuine catalog entry rather than a hand copy.
func _authored_alternative(record: Dictionary, kind: String, amount: int) -> Dictionary:
	var spec: Variant = record.get("intent")
	if not spec is Dictionary:
		return {}
	var actions: Variant = spec.get("actions")
	if not actions is Array:
		return {}
	for raw in actions:
		if raw is Dictionary and raw.get("type") == kind and int(raw.get("amount", -1)) == amount:
			return raw.duplicate(true)
	return {}

## Bind a valid one-source encounter carrying exactly one authored alternative,
## so an executed beat never depends on a lucky weighted roll.
func _force_normal_alternative(source: Dictionary, raw: Variant,
		party: CombatParty) -> Dictionary:
	var normalized := CombatEnemyIntents.weighted_action(raw)
	_check(not normalized.is_empty(), "forced alternative is a valid authored action: " + str(raw))
	if normalized.is_empty() or source.is_empty():
		return {}
	var forced: Dictionary = source.duplicate(true)
	var action: Dictionary = normalized["action"].duplicate(true)
	action["weight"] = 1
	forced["intent"] = {"target": source["intent"]["target"], "actions": [action]}
	var enemies := CombatEnemies.new([forced])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2631
	var scheduler := CombatEnemyIntents.new([_enemy(1, [{"type": "block", "amount": 1}])])
	var bound := enemies.is_valid() and scheduler.bind_battle(enemies, party, rng)
	_check(bound, "forced one-source harder encounter binds: " + str(raw))
	if not bound:
		return {}
	return {"enemies": enemies, "intents": scheduler.get_intents(), "rng": rng,
		"scheduler": scheduler}

func _test_hound_enrage() -> void:
	var parsed := _load_parsed()
	var hound := _find(parsed, "spoolback_hound")
	_check(_norm(hound) == _norm(_harder_expected().spoolback_hound)
		and hound.get("enrage") is bool and not hound.has("enrage_stacks"),
		"Hound authors only boolean Enrage, with exact identity and fresh zero stacks")
	var carriers: Array = []
	for record in parsed:
		if record.get("enrage", false) == true:
			carriers.append(record.id)
	_check(carriers == ["spoolback_hound"], "only the shipped Hound activates Enrage")
	var material := RunAuthoredBattleEntry._floor_band_material(null)
	_check(material.get("ok") == true, "Hound live Fight catalog loads")
	if not material.get("ok", false) or hound.is_empty():
		return
	_check(_norm(material.records.get("spoolback_hound", {})) == _norm(hound),
		"live Fight loader retains the authentic Enrage Hound")
	var oracle = preload("res://tests/floor_band_oracle.gd")
	var owning_bands := 0
	for floor_number in [1, 5, 9]:
		var band: String = oracle.band_for_floor(floor_number)
		_check(material.pools.get(band, []) == oracle.band_ids(floor_number),
			"live eligible IDs retain independent HP/ID band ordering: " + band)
		if oracle.band_ids(floor_number).has("spoolback_hound"):
			owning_bands += 1
	_check(owning_bands == 1, "Hound remains eligible in exactly one ordinary floor band")
	var first := _hound_paid_sequence(parsed, 326)
	_check(not first.is_empty() and first == _hound_paid_sequence(parsed, 326),
		"paid Hound hits, phases, piles and shared RNG replay exactly")
	# Starter Strike cannot deal zero. Use the real status bridge's zero receipt,
	# then the same confirmed-hit callback used by paid attacks (no invented hit).
	var foes := CombatEnemies.new([hound])
	var party := _party()
	var before := foes.get_enemy(1)
	var zero := CombatStatusAttacks.new().resolve_vs_enemy(foes, 1, 0, {}, {})
	_check(zero == {"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0},
		"authentic Hound zero-damage bridge confirms no HP or Block loss")
	CombatAttackCards.new()._retaliate_hits(party, foes, 1,
		[{"position": 1, "damage": zero.damage, "block_absorbed": zero.block_absorbed,
		"hp_loss": zero.hp_loss}], {1: before})
	_check(foes.get_enemy(1) == before and party.get_heroes() == _party().get_heroes(),
		"zero-damage confirmation grants no stack or retaliation")
	for flag in [null, false]:
		var sibling := _find(parsed, "inkbrush_imp")
		if flag != null:
			sibling.enrage = flag
		var control := CombatEnemies.new([hound, sibling])
		var deck := _attack_deck("warden_strike")
		var rng_before: int = deck._rng.state
		var hit := CombatAttackCards.new().play_attack(deck, _party(), control, "warden_strike", 2)
		_check(hit.ok and control.get_enemy(2).hp == 17 and deck.energy == 2
			and not control.get_enemy(2).has("enrage_stacks")
			and not control.get_enemy(1).has("enrage_stacks") and deck._rng.state == rng_before,
			"paid hit on absent/false sibling empowers neither source and uses no RNG")
	# Malformed metadata and slain targets reject before spending or publishing.
	for invalid in ["true", 1, -1]:
		var bad := CombatEnemies.new([hound])
		bad._enemies[0].enrage = invalid
		_hound_reject(bad)
	var slain := CombatEnemies.new([hound])
	_check(slain.apply_damage(1, 28) and slain.is_slain(1), "Hound is genuinely slain")
	_hound_reject(slain)
	var dead_party := _party()
	var dead_before := slain.get_enemies()
	var skipped := CombatEnemyPhase.new().execute_phase(dead_party, slain,
		[{"enemy_position": 1, "type": "attack", "amount": 7, "target_position": 1}])
	_check(skipped.ok and not skipped.events[0].applied and slain.get_enemies() == dead_before
		and dead_party.get_heroes() == _party().get_heroes(), "slain Hound never bites or gains stacks")

func _hound_reject(foes: CombatEnemies) -> void:
	var deck := _attack_deck("warden_strike")
	var party := _party()
	var before := [foes.get_enemies(), party.get_heroes(), deck.hand.duplicate(),
		deck.draw_pile.duplicate(), deck.discard_pile.duplicate(), deck.energy, deck._rng.state]
	var result := CombatAttackCards.new().play_attack(deck, party, foes, "warden_strike", 1)
	_check(result == {"ok": false, "hits": []} and before == [foes.get_enemies(),
		party.get_heroes(), deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, deck._rng.state],
		"invalid/slain Hound rejects paid attack with complete no-spend actor/pile/RNG snapshot")
	if not foes.is_slain(1):
		var phase := CombatEnemyPhase.new().execute_phase(party, foes,
			[{"enemy_position": 1, "type": "attack", "amount": 7, "target_position": 1}])
		_check(not phase.ok and phase.events.is_empty() and foes.get_enemies() == before[0]
			and party.get_heroes() == before[1], "invalid Enrage rejects whole phase atomically")

func _hound_paid_sequence(parsed: Array, seed_value: int) -> Dictionary:
	var hound := _find(parsed, "spoolback_hound")
	var imp := _find(parsed, "inkbrush_imp")
	_check(not hound.is_empty() and not imp.is_empty(), "authentic paid sequence sources exist")
	if hound.is_empty() or imp.is_empty():
		return {}
	var enemies := CombatEnemies.new([hound, imp])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(StarterCards.new().get_starting_deck(), rng)
	var party := _party()
	var attacks := CombatAttackCards.new()
	# Force only authored attack alternatives for deterministic announcements;
	# execute those announcements against the original, unmodified live actors.
	var forced: Array = []
	for source in [hound, imp]:
		var copy: Dictionary = source.duplicate(true)
		copy.intent.actions = [_authored_alternative(source, "attack", 7 if source.id == hound.id else 6)]
		forced.append(copy)
	var scheduler := CombatEnemyIntents.new([
		_enemy(1, [{"type": "block", "amount": 1}]),
		_enemy(2, [{"type": "block", "amount": 1}])])
	_check(enemies.is_valid() and party.is_valid() and party.get_hero(1).id == "warden"
		and scheduler.bind_battle(CombatEnemies.new(forced), party, rng),
		"real Hound and unflagged Imp bind authored bite announcements on shared seeded RNG")
	var intents := scheduler.get_intents()
	_check(intents.size() == 2 and intents[0].amount == 7 and intents[1].amount == 6,
		"announcements retain base seven and six, never pre-add Enrage")
	if not scheduler.is_bound() or intents.size() != 2:
		return {}
	var trace: Array = []
	for hits in range(5):
		var stacks := mini(hits, 3)
		_check(enemies.get_enemy(1).get("enrage_stacks", 0) == stacks
			and enemies.get_enemy(1).id == "spoolback_hound"
			and enemies.get_enemy(2).id == "inkbrush_imp", "stacks stay on original Hound source")
		var recipient := _party()
		_check(recipient.gain_block(1, 5), "bite recipient starts with five real Block")
		var before_phase := enemies.get_enemies()
		var state: int = rng.state
		var phase := CombatEnemyPhase.new().execute_phase(recipient, enemies, intents, null, true)
		_check(phase.ok and phase.events.size() == 2 and phase.events[0].applied
			and phase.events[1].applied and recipient.get_hero(1).block == 0
			and recipient.get_hero(1).hp == 40 - (7 + stacks * 2 - 5)
			and recipient.get_hero(2).hp == 30 and recipient.get_hero(3).hp == 20,
			"real Hound bite is 7/9/11/13 through Block before HP; unflagged Imp stays six")
		_check(enemies.get_enemies() == before_phase and rng.state == state
			and scheduler.get_intents() == intents, "phase reads stacks without rerolling or changing sources")
		trace.append([phase, recipient.get_heroes(), enemies.get_enemies()])
		if hits == 4:
			break
		_check(deck.start_turn(), "legal next player turn starts")
		attacks.start_player_turn()
		for draw in range(StarterCards.new().get_starting_deck().size()):
			if deck.hand.has("warden_strike"):
				break
			_check(deck.draw_extra(1) == 1, "real shared deck draws to a held Strike")
		_check(deck.hand.has("warden_strike") and deck.energy == 3
			and party.get_hero(1).hp > 0, "living front Warden owns a drawn affordable Strike")
		if hits == 1:
			_check(enemies.gain_block(1, 6), "second confirmed hit is fully enemy-Block absorbed")
		var before := enemies.get_enemies()
		state = rng.state
		var hand := deck.hand.duplicate()
		var forecast := attacks.forecast_attack(deck, party, enemies, "warden_strike")
		var rejected := attacks.play_attack(deck, party, enemies, "warden_strike", 3)
		_check(forecast.playable and rejected == {"ok": false, "hits": []}
			and enemies.get_enemies() == before and deck.hand == hand and deck.energy == 3
			and rng.state == state, "preview and rejected absent target grant no stacks, payment or RNG")
		var discard_count := deck.discard_pile.size()
		var hit := attacks.play_attack(deck, party, enemies, "warden_strike", 1)
		_check(hit.ok and hit.hits.size() == 1 and hit.hits[0].damage == 6
			and hit.hits[0].block_absorbed == (6 if hits == 1 else 0)
			and hit.hits[0].hp_loss == (0 if hits == 1 else 6), "paid Strike produces genuine six-damage receipt")
		_check(deck.energy == 2 and deck.hand.size() == hand.size() - 1
			and deck.discard_pile.size() == discard_count + 1 and deck.discard_pile.back() == "warden_strike"
			and rng.state == state, "Strike pays/discards exactly once without RNG")
		_check(enemies.get_enemy(1).get("enrage_stacks") == mini(hits + 1, 3)
			and enemies.get_enemy(1).hp == 28 - 6 * (hits + 1 - (1 if hits >= 1 else 0))
			and enemies.get_enemy(1).block == 0 and enemies.get_enemy(2) == before[1],
			"living Hound gains 1/2/3/capped-three stacks, including absorbed hit; neighbor untouched")
		_check(deck.end_turn(), "legal turn ends before next paid Strike")
	return {"trace": trace, "rng": rng.state, "draw": deck.draw_pile,
		"discard": deck.discard_pile, "hand": deck.hand}

func _test_harder_normal_phase_actions() -> void:
	var parsed := _load_parsed()
	var mantis := _find(parsed, "shearwing_mantis")
	var hound := _find(parsed, "spoolback_hound")
	var imp := _find(parsed, "inkbrush_imp")
	for record in [mantis, hound, imp]:
		_check(not record.is_empty(), "authentic harder normal record present for the phase checks")
	# Shearwing Mantis: the tailor-shear forelegs strip the front Block entirely.
	var snip_party := _party()
	_check(snip_party.gain_block(1, 7), "precondition: the front hero really holds seven Block")
	_check(snip_party.get_hero(1).get("hp") == 40,
		"precondition: the front hero is at full HP")
	var snip := _force_normal_alternative(mantis, _authored_alternative(mantis, "snip_block", 0),
		snip_party)
	if not snip.is_empty():
		_check(snip.intents.size() == 1 and snip.intents[0].get("type") == "snip_block"
			and snip.intents[0].get("target_position") == 1,
			"Mantis snip announces against the front hero")
		var receipt := CombatEnemyPhase.new().execute_phase(snip_party, snip.enemies,
			snip.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced Mantis snip resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "snip_block" and event.get("applied") == true
				and event.get("target_position") == 1 and event.get("enemy_position") == 1,
				"the phase reports the applied front snip")
		_check(snip_party.get_hero(1).get("block") == 0 and snip_party.get_hero(1).get("hp") == 40,
			"Mantis snip leaves the front hero at zero Block and full HP")
	_check(snip_party.get_hero(2).get("block") == 0 and snip_party.get_hero(2).get("hp") == 30,
		"the Mantis snip never touches the middle hero")
	# Spoolback Hound: the thread leash pulls the front hero toward the middle.
	var shove_party := _party()
	_check(shove_party.get_hero(1).get("id") == "warden"
		and shove_party.get_hero(2).get("id") == "seamstress",
		"precondition: slots 1 and 2 hold Warden then Seamstress")
	var shove := _force_normal_alternative(hound, _authored_alternative(hound, "shove", 0),
		shove_party)
	if not shove.is_empty():
		_check(shove.intents.size() == 1 and shove.intents[0].get("type") == "shove"
			and shove.intents[0].get("target_position") == 1
			and shove.intents[0].get("direction") == 1,
			"Hound leash announces a legal +1 shove from the front hero")
		_check(CombatEnemyIntents.shove_is_legal(shove_party, 1, 1),
			"precondition: the announced +1 shove is legal")
		var receipt := CombatEnemyPhase.new().execute_phase(shove_party, shove.enemies,
			shove.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced Hound shove resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "shove" and event.get("applied") == true
				and event.get("target_position") == 1 and event.get("direction") == 1,
				"the phase reports the applied +1 shove")
		_check(shove_party.get_hero(1).get("id") == "seamstress"
			and shove_party.get_hero(1).get("position") == 1,
			"the Hound pulls Seamstress forward into slot 1")
		_check(shove_party.get_hero(2).get("id") == "warden"
			and shove_party.get_hero(2).get("position") == 2,
			"Warden moves back into slot 2")
		_check(shove_party.get_hero(1).get("hp") == 30 and shove_party.get_hero(1).get("block") == 0
			and shove_party.get_hero(2).get("hp") == 40 and shove_party.get_hero(2).get("block") == 0,
			"the exchange costs neither swapped hero HP or Block")
		_check(shove_party.get_hero(3).get("id") == "tinker"
			and shove_party.get_hero(3).get("hp") == 26 and shove_party.get_hero(3).get("block") == 0,
			"the untouched back slot keeps its hero and state")
	# Inkbrush Imp: the dye brush marks vulnerable seams with the existing status.
	var debuff_party := _party()
	_check(debuff_party.apply_damage(2, 10), "precondition: the middle hero really takes damage")
	_check(debuff_party.get_hero(2).get("hp") == 20 and debuff_party.get_hero(3).get("hp") == 26
		and debuff_party.get_hero(1).get("hp") == 40,
		"precondition: the middle hero is the unique lowest-living target")
	_check(CombatEnemyIntents.priority_target(debuff_party, "lowest_living_hp") == 2,
		"precondition: the authored policy really selects the middle hero")
	var debuff := _force_normal_alternative(imp, _authored_alternative(imp, "debuff", 2),
		debuff_party)
	if not debuff.is_empty():
		_check(debuff.intents.size() == 1 and debuff.intents[0].get("type") == "debuff"
			and debuff.intents[0].get("status") == "exposed"
			and debuff.intents[0].get("target_position") == 2,
			"Imp marks the uniquely damaged hero with Exposed")
		var receipt := CombatEnemyPhase.new().execute_phase(debuff_party, debuff.enemies,
			debuff.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced Imp debuff resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "debuff" and event.get("applied") == true
				and event.get("status") == "exposed" and event.get("target_position") == 2,
				"the phase reports the applied Exposed mark")
		_check(debuff_party.get_hero(2).get("statuses", {}).get("exposed", 0) == 2,
			"the Imp's Exposed 2 lands on the marked hero through the existing status handler")
		_check(debuff_party.get_hero(2).get("hp") == 20,
			"the Exposed mark costs the target no HP")
		for position in [1, 3]:
			_check(debuff_party.get_hero(position).get("statuses", {}).get("exposed", 0) == 0,
				"unmarked hero %d gains no Exposed" % position)
	# Every authored attack resolves through the real phase with Block first.
	# Shearwing Mantis is distinguished: its chew_block_on_attack strips all
	# Block before dealing its 8 damage, not the ordinary absorption path.
	var attack_cases := [
		{"id": "spoolback_hound", "amount": 7, "block": 5},
		{"id": "inkbrush_imp", "amount": 6, "block": 4}]
	for case in attack_cases:
		var record := _find(parsed, String(case.id))
		var policy := String(record.get("intent", {}).get("target", ""))
		var attack_party := _party()
		var target := CombatEnemyIntents.priority_target(attack_party, policy)
		_check(target >= 1, "precondition: the attack policy selects a living hero: " + String(case.id))
		if target < 1:
			continue
		_check(attack_party.gain_block(target, int(case.block)),
			"precondition: the policy target holds Block: " + String(case.id))
		var hp_before := int(attack_party.get_hero(target).get("hp", 0))
		var attack := _force_normal_alternative(record,
			_authored_alternative(record, "attack", int(case.amount)), attack_party)
		if attack.is_empty():
			continue
		_check(attack.intents.size() == 1 and attack.intents[0].get("type") == "attack"
			and int(attack.intents[0].get("amount", -1)) == int(case.amount)
			and attack.intents[0].get("target_position") == target,
			"the attack announces its authored %d damage on the policy target: %s"
				% [int(case.amount), String(case.id)])
		var receipt := CombatEnemyPhase.new().execute_phase(attack_party, attack.enemies,
			attack.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced %d-damage attack resolves through a real CombatEnemyPhase: %s"
				% [int(case.amount), String(case.id)])
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "attack" and event.get("applied") == true
				and event.get("target_position") == target,
				"the phase reports the applied attack on the policy target: " + String(case.id))
		var absorbed := mini(int(case.block), int(case.amount))
		_check(attack_party.get_hero(target).get("block") == int(case.block) - absorbed,
			"Block is consumed before HP for the %d-damage hit: %s"
				% [int(case.amount), String(case.id)])
		_check(attack_party.get_hero(target).get("hp")
			== hp_before - (int(case.amount) - absorbed),
			"only the unabsorbed remainder reaches HP for the %d-damage hit: %s"
				% [int(case.amount), String(case.id)])
	# Shearwing Mantis positive chew_block_on_attack test.
	var mantis_attack_party := _party()
	_check(mantis.get("chew_block_on_attack") is bool
		and mantis.get("chew_block_on_attack") == true,
		"precondition: Mantis really carries the chew_block flag")
	_check(mantis_attack_party.gain_block(1, 5),
		"precondition: the Mantis target really holds 5 Block")
	var hp_before_mantis := int(mantis_attack_party.get_hero(1).get("hp", 0))
	var mantis_attack := _force_normal_alternative(mantis,
		_authored_alternative(mantis, "attack", 8), mantis_attack_party)
	if not mantis_attack.is_empty():
		_check(mantis_attack.intents.size() == 1
			and mantis_attack.intents[0].get("type") == "attack"
			and int(mantis_attack.intents[0].get("amount", -1)) == 8
			and mantis_attack.intents[0].get("target_position") == 1,
			"the Mantis attack-8 announces on the front hero")
		var mantis_receipt := CombatEnemyPhase.new().execute_phase(
			mantis_attack_party, mantis_attack.enemies,
			mantis_attack.intents, null, true)
		_check(mantis_receipt.get("ok") == true
			and mantis_receipt.get("events", []).size() == 1,
			"AC2: the Mantis chew_block attack resolves through the real phase")
		if mantis_receipt.get("ok", false) and mantis_receipt.get("events", []).size() == 1:
			var event: Dictionary = mantis_receipt["events"][0]
			_check(event.get("type") == "attack" and event.get("applied") == true
				and event.get("target_position") == 1,
				"the phase reports the applied Mantis attack on the front hero")
		# Block is fully eaten before the 8 damage lands.
		_check(mantis_attack_party.get_hero(1).get("block") == 0,
			"AC2: Mantis chew eats all 5 Block before damage")
		_check(mantis_attack_party.get_hero(1).get("hp") == hp_before_mantis - 8,
			"AC2: the front hero loses exactly 8 HP after Block is stripped")
	# The standalone snip stays a zero-damage Block strip.
	var snip_party_fresh := _party()
	_check(snip_party_fresh.gain_block(1, 5),
		"precondition: fresh party holds 5 Block for standalone snip")
	var snip_receipt_check := _force_normal_alternative(mantis,
		_authored_alternative(mantis, "snip_block", 0), snip_party_fresh)
	if not snip_receipt_check.is_empty():
		var snip_receipt := CombatEnemyPhase.new().execute_phase(
			snip_party_fresh, snip_receipt_check.enemies,
			snip_receipt_check.intents, null, true)
		_check(snip_receipt.get("ok") == true,
			"AC3: the Mantis snip resolves without damage")
		_check(snip_party_fresh.get_hero(1).get("block") == 0
			and snip_party_fresh.get_hero(1).get("hp") == 40,
			"AC3: standalone snip strips Block but leaves HP untouched")
	# AC4: malformed chew_block_on_attack on Mantis fails the phase closed.
	var malformed_mantis := mantis.duplicate(true)
	malformed_mantis["chew_block_on_attack"] = 1
	var malformed_party := _party()
	var malformed_enemies := CombatEnemies.new([malformed_mantis])
	_check(malformed_enemies.is_valid(),
		"precondition: malformed Mantis roster constructs")
	var malformed_before: Array = malformed_party.get_heroes()
	var malformed_receipt := CombatEnemyPhase.new().execute_phase(
		malformed_party, malformed_enemies, [_raw_attack_intent(1)], null, true)
	_check(malformed_receipt == {"ok": false, "events": []}
		and malformed_party.get_heroes() == malformed_before,
		"AC4: malformed Mantis chew_block metadata rejects the phase")


## The real Warden reaction hand, seeded like the existing guard-phase fixture.
func _guard_deck(held_cards: Array[String]) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = 131006
	var deck := CombatDeck.new(held_cards, rng)
	_check(deck.start_turn() and deck.hand.size() == held_cards.size(),
		"precondition: the real reaction hand is dealt")
	for id in held_cards:
		_check(deck.hand.has(id), "precondition: paid reaction card is held: " + id)
	return deck

## An announced attack built here only for the downed and malformed controls;
## the positive cases use the authentic authored alternative instead.
func _raw_attack_intent(target: int) -> Dictionary:
	return {"type": "attack", "enemy_position": 1, "amount": 8, "target_position": target}

func _test_needle_wasp_bleeding_sting() -> void:
	var parsed := _load_parsed()
	var wasp := _find(parsed, "needle_wasp")
	_check(not wasp.is_empty(), "precondition: authentic Needle Wasp record loaded")
	if wasp.is_empty():
		return
	_check(wasp.get("bleed_on_attack") is bool and wasp.get("bleed_on_attack") == true,
		"AC1: the parsed Needle Wasp carries bleed_on_attack as a genuine bool")
	var attack := _authored_alternative(wasp, "attack", 8)
	_check(not attack.is_empty(), "precondition: authentic authored attack 8 alternative")
	var bleed_2 := _authored_alternative(wasp, "debuff", 2)
	_check(not bleed_2.is_empty() and bleed_2.get("status") == "bleed",
		"precondition: authentic authored standalone Bleed 2 alternative")
	# AC2: an unblocked sting on the real 40/30/26 party bleeds its real recipient.
	var party := _party()
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		"precondition: authentic Warden 40 / Seamstress 30 / Tinker 26 party")
	_check(CombatEnemyIntents.priority_target(party, "lowest_living_hp") == 3,
		"precondition: the authored policy really announces Tinker at slot 3")
	var sting_case := _force_normal_alternative(wasp, attack, party)
	if sting_case.is_empty():
		return
	_check(sting_case.intents.size() == 1 and sting_case.intents[0].get("type") == "attack"
		and int(sting_case.intents[0].get("amount", -1)) == 8
		and sting_case.intents[0].get("target_position") == 3,
		"the forced sting announces its authored 8 damage on Tinker")
	var untouched := [party.get_hero(1), party.get_hero(2)]
	var without_bleed: Dictionary = party.get_hero(3)
	var receipt := CombatEnemyPhase.new().execute_phase(party, sting_case.enemies,
		sting_case.intents, null, true)
	_check(receipt.get("ok") == true and receipt.get("events", []).size() == 2,
		"AC2: the announced sting resolves through a real CombatEnemyPhase")
	if receipt.get("ok", false) and receipt.get("events", []).size() == 2:
		var event: Dictionary = receipt["events"][0]
		_check(event == {"type": "attack", "enemy_position": 1, "applied": true,
			"target_position": 3},
			"AC2: the phase receipt keeps its exact pre-existing attack shape")
	_check(party.get_hero(3).get("hp") == 18 and party.get_hero(3).get("block") == 0,
		"AC2: the unblocked 8-damage sting drops Tinker from 26 to 18 HP")
	_check(party.get_hero(3).get("statuses", {}).get("bleed", 0) == 2,
		"AC2: the hero who really lost HP gains Bleed 1 per hit")
	_check(int(without_bleed.get("statuses", {}).get("bleed", 0)) == 0,
		"precondition: Tinker held no Bleed before the sting")
	_check([party.get_hero(1), party.get_hero(2)] == untouched,
		"AC2: the other two heroes keep their HP, Block and statuses")
	# Consecutive confirmed stings stack the status; the second still hits Tinker.
	var second := _force_normal_alternative(wasp, attack, party)
	if not second.is_empty():
		_check(second.intents.size() == 1 and second.intents[0].get("target_position") == 3,
			"the stacking sting still announces Tinker as the lowest-living hero")
		var second_receipt := CombatEnemyPhase.new().execute_phase(party, second.enemies,
			second.intents, null, true)
		_check(second_receipt.get("ok") == true, "the second sting resolves through the real phase")
		_check(party.get_hero(3).get("hp") == 10
			and party.get_hero(3).get("statuses", {}).get("bleed", 0) == 4,
			"AC2: a second confirmed sting stacks Bleed to 4 and drops Tinker to 10 HP")
	# AC3: the separate authored Bleed 2 debuff stays exactly Bleed 2.
	var debuff_party := _party()
	var debuff_case := _force_normal_alternative(wasp, bleed_2, debuff_party)
	if not debuff_case.is_empty():
		_check(debuff_case.intents.size() == 1 and debuff_case.intents[0].get("type") == "debuff"
			and debuff_case.intents[0].get("status") == "bleed"
			and int(debuff_case.intents[0].get("amount", -1)) == 2
			and debuff_case.intents[0].get("target_position") == 3,
			"the standalone debuff announces Bleed 2 on Tinker")
		var debuff_receipt := CombatEnemyPhase.new().execute_phase(debuff_party,
			debuff_case.enemies, debuff_case.intents, null, true)
		_check(debuff_receipt.get("ok") == true and debuff_receipt.get("events", [{}])[0].get(
			"applied") == true, "the announced Bleed 2 debuff resolves through the real phase")
		_check(debuff_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 2,
			"AC3: the separate Bleed 2 action stays exactly Bleed 2 with no sting bonus")
		_check(debuff_party.get_hero(3).get("hp") == 26,
			"AC3: the standalone Bleed 2 costs its target no HP")
		for position in [1, 2]:
			_check(debuff_party.get_hero(position).get("statuses", {}).get("bleed", 0) == 0,
				"unannounced hero %d gains no Bleed from the debuff" % position)
	# AC3: full Block protects HP and therefore prevents the sting's Bleed.
	var blocked_party := _party()
	_check(blocked_party.gain_block(3, 8), "precondition: Tinker really holds eight Block")
	var blocked := _force_normal_alternative(wasp, attack, blocked_party)
	if not blocked.is_empty():
		var blocked_receipt := CombatEnemyPhase.new().execute_phase(blocked_party,
			blocked.enemies, blocked.intents, null, true)
		_check(blocked_receipt.get("ok") == true, "the blocked sting still resolves")
		_check(blocked_party.get_hero(3).get("hp") == 26
			and blocked_party.get_hero(3).get("block") == 0,
			"AC3: eight Block absorb the whole sting and leave HP untouched")
		_check(blocked_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 0,
			"AC3: a fully blocked sting inflicts no Bleed")
	# Only the HP actually lost after Block causes the sting.
	var partial_party := _party()
	_check(partial_party.gain_block(3, 5), "precondition: Tinker really holds five Block")
	var partial := _force_normal_alternative(wasp, attack, partial_party)
	if not partial.is_empty():
		var partial_receipt := CombatEnemyPhase.new().execute_phase(partial_party,
			partial.enemies, partial.intents, null, true)
		_check(partial_receipt.get("ok") == true, "the partially blocked sting resolves")
		_check(partial_party.get_hero(3).get("hp") == 23
			and partial_party.get_hero(3).get("block") == 0
			and partial_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 1,
			"AC3: real HP loss after Block still earns exactly Bleed 1")
	# AC3: a slain wasp never stings.
	var slain_party := _party()
	var slain_case := _force_normal_alternative(wasp, attack, slain_party)
	if not slain_case.is_empty():
		_check(slain_case.enemies.apply_damage(1, 22) and slain_case.enemies.is_slain(1),
			"precondition: the stinging wasp is genuinely slain before its beat")
		var slain_before: Array = slain_party.get_heroes()
		var slain_receipt := CombatEnemyPhase.new().execute_phase(slain_party,
			slain_case.enemies, slain_case.intents, null, true)
		_check(slain_receipt.get("ok") == true
			and slain_receipt.get("events", [{}])[0].get("applied") == false,
			"AC3: a slain wasp's announced sting resolves as an inert beat")
		_check(slain_party.get_heroes() == slain_before,
			"AC3: a slain wasp deals no damage and grants no Bleed")
	# AC3: a downed announced hero never bleeds.
	var downed_party := _party()
	_check(downed_party.apply_damage(3, 26) and downed_party.is_downed(3),
		"precondition: the announced Tinker is already downed")
	var downed_enemies := CombatEnemies.new([wasp.duplicate(true)])
	_check(downed_enemies.is_valid(), "precondition: a real one-wasp roster for the downed beat")
	var downed_before: Array = downed_party.get_heroes()
	var downed_receipt := CombatEnemyPhase.new().execute_phase(downed_party, downed_enemies,
		[_raw_attack_intent(3)])
	_check(downed_receipt.get("ok") == true
		and downed_receipt.get("events", [{}])[0].get("applied") == false
		and downed_party.get_heroes() == downed_before,
		"AC3: a downed announced hero takes no sting damage and gains no Bleed")
	# AC3: another authored enemy without the flag never bleeds on HP damage.
	var control_source := _find(parsed, "seam_ripper")
	_check(not control_source.is_empty() and not control_source.has("bleed_on_attack"),
		"precondition: another authored normal enemy carries no bleeding sting")
	if not control_source.is_empty():
		var control_party := _party()
		var control_case := _force_normal_alternative(control_source,
			_authored_alternative(control_source, "attack", 5), control_party)
		if not control_case.is_empty():
			var control_receipt := CombatEnemyPhase.new().execute_phase(control_party,
				control_case.enemies, control_case.intents, null, true)
			_check(control_receipt.get("ok") == true, "the unarmed enemy's attack resolves")
			_check(control_party.get_hero(3).get("hp") == 21
				and control_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 0,
				"AC3: HP damage from a non-wasp enemy never adds the sting's Bleed")
	# AC3: the same wasp with an explicit authored false never stings.
	var false_record := wasp.duplicate(true)
	false_record["bleed_on_attack"] = false
	var false_party := _party()
	var false_enemies := CombatEnemies.new([false_record])
	_check(false_enemies.is_valid() and false_enemies.get_enemy(1).get("bleed_on_attack") == false,
		"precondition: a real roster carries the explicit false flag")
	var false_receipt := CombatEnemyPhase.new().execute_phase(false_party, false_enemies,
		[_raw_attack_intent(3)], null, true)
	_check(false_receipt.get("ok") == true and false_party.get_hero(3).get("hp") == 18
		and false_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 0,
		"AC3: an explicit false flag still deals the 8 damage but grants no Bleed")
	# AC3: Warden Guard redirects the sting; only the real recipient bleeds.
	var guard_party := _party()
	var guard_deck := _guard_deck(["warden_draw_fire", "warden_iron_hem",
		"warden_hold_the_line", "warden_quick_darn", "warden_counter_stitch"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(guard_deck, guard_party, "warden_draw_fire")
		and reactions.is_guarding() and guard_party.get_hero(1).get("block") == 6,
		"precondition: the real paid Draw Fire activates Guarding and six Block")
	var guard_case := _force_normal_alternative(wasp, attack, guard_party)
	if not guard_case.is_empty():
		_check(guard_case.intents.size() == 1
			and guard_case.intents[0].get("target_position") == 3,
			"the guard case announces Tinker before any redirect")
		var guard_receipt := CombatEnemyPhase.new().execute_phase(guard_party,
			guard_case.enemies, guard_case.intents, reactions)
		_check(guard_receipt.get("ok") == true and guard_receipt.get("events", []).size() == 2,
			"AC3: the redirected sting resolves through the real reaction path")
		if guard_receipt.get("ok", false) and guard_receipt.get("events", []).size() == 2:
			var guard_event: Dictionary = guard_receipt["events"][0]
			_check(guard_event.get("target_position") == 3
				and guard_event.get("actual_target_position") == 1
				and guard_event.get("redirected") == true,
				"AC3: the receipt keeps the announced Tinker and reports the Warden as actual recipient")
		_check(guard_party.get_hero(1).get("hp") == 38
			and guard_party.get_hero(1).get("block") == 0
			and guard_party.get_hero(1).get("statuses", {}).get("bleed", 0) == 1,
			"AC3: only the Warden who really lost 2 HP gains Bleed 1")
		_check(guard_party.get_hero(3).get("hp") == 26
			and guard_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 0,
			"AC3: the announced Tinker takes nothing and gains no Bleed")
		_check(guard_party.get_hero(2).get("statuses", {}).get("bleed", 0) == 0,
			"AC3: the uninvolved Seamstress gains no Bleed")
	# AC4: malformed metadata fails closed without authoritative mutation.
	for invalid_value in ["true", 1, 1.0, null, [], {}]:
		var malformed := wasp.duplicate(true)
		malformed["bleed_on_attack"] = invalid_value
		_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([malformed])).is_empty(),
			"AC4: malformed bleed_on_attack rejects the whole catalog: " + str(invalid_value))
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([wasp])).size() == 1,
		"AC4: the genuine boolean flag keeps the catalog valid")
	var contested := wasp.duplicate(true)
	contested["bleed_on_attack"] = false
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([contested])).size() == 1,
		"AC4: an explicit false stays valid metadata and simply never stings")
	var malformed_record := wasp.duplicate(true)
	malformed_record["bleed_on_attack"] = 1
	var malformed_enemies := CombatEnemies.new([malformed_record])
	_check(malformed_enemies.is_valid(),
		"precondition: the malformed roster really constructs before the phase rejects it")
	var malformed_party := _party()
	var malformed_party_before: Array = malformed_party.get_heroes()
	var malformed_enemies_before: Array = malformed_enemies.get_enemies()
	var malformed_rng := RandomNumberGenerator.new()
	malformed_rng.seed = 7161
	var malformed_state: int = malformed_rng.state
	var rejected := CombatEnemyPhase.new().execute_phase(malformed_party,
		malformed_enemies, [_raw_attack_intent(3)], null, true)
	_check(rejected == {"ok": false, "events": []},
		"AC4: malformed bleed_on_attack metadata rejects the phase")
	_check(malformed_party.get_heroes() == malformed_party_before
		and malformed_enemies.get_enemies() == malformed_enemies_before
		and malformed_rng.state == malformed_state,
		"AC4: a rejected malformed roster changes no hero, enemy or RNG state")
	var invalid_party := _party()
	var invalid_case := _force_normal_alternative(wasp, attack, invalid_party)
	if not invalid_case.is_empty():
		var invalid_before: Array = [invalid_party.get_heroes(),
			invalid_case.enemies.get_enemies()]
		var bad_intent: Dictionary = invalid_case.intents[0].duplicate(true)
		bad_intent["target_position"] = 0
		var invalid_receipt := CombatEnemyPhase.new().execute_phase(invalid_party,
			invalid_case.enemies, [bad_intent], null, true)
		_check(invalid_receipt == {"ok": false, "events": []}
			and [invalid_party.get_heroes(), invalid_case.enemies.get_enemies()] == invalid_before,
			"AC4: an invalid announced sting rejects the phase without damage or Bleed")
	# AC4: one identical seeded sting replays exactly, twice.
	var replay_party_one := _party()
	var replay_party_two := _party()
	var replay_one := _force_normal_alternative(wasp, attack, replay_party_one)
	var replay_two := _force_normal_alternative(wasp, attack, replay_party_two)
	if not replay_one.is_empty() and not replay_two.is_empty():
		_check(replay_one.intents == replay_two.intents,
			"AC4: identical seeds announce the identical sting")
		var replay_result_one := CombatEnemyPhase.new().execute_phase(replay_party_one,
			replay_one.enemies, replay_one.intents, null, true)
		var replay_result_two := CombatEnemyPhase.new().execute_phase(replay_party_two,
			replay_two.enemies, replay_two.intents, null, true)
		_check(replay_result_one == replay_result_two
			and replay_party_one.get_heroes() == replay_party_two.get_heroes()
			and replay_one.enemies.get_enemies() == replay_two.enemies.get_enemies(),
			"AC4: an identical seeded sting reproduces actors, statuses and receipts")
		_check(replay_one.rng.state == replay_two.rng.state,
			"AC4: an identical seeded sting leaves matching RNG state")


## AC1: the shipped Thread Biter record opts into Drain without changing its
## identity, HP, target policy or weighted alternatives, and the genuine
## floor-band roster that live Fights consume keeps that metadata.
func _test_thread_biter_lifesteal_catalog() -> void:
	var parsed := _load_parsed()
	var biter := _find(parsed, "thread_biter")
	_check(not biter.is_empty(), "precondition: shipped Thread Biter record loads")
	if biter.is_empty():
		return
	_check(biter.get("drain") is bool and biter.get("drain") == true,
		"AC1: the parsed Thread Biter authors drain as a genuine bool")
	_check(_norm(biter) == _norm(_old_expected()["thread_biter"]),
		"AC1: Thread Biter preserves its exact authored record with the V3 five-point bite")
	_check(biter.get("max_hp") is int and biter.get("max_hp") == 15,
		"AC1: Thread Biter keeps its authored 15 max HP")
	var spec: Variant = biter.get("intent")
	_check(spec is Dictionary and spec.get("target") == "lowest_living_hp",
		"AC1: Thread Biter keeps its lowest-living target policy")
	var bite := _authored_alternative(biter, "attack", 5)
	_check(not bite.is_empty() and int(bite.get("weight", 0)) == 3,
		"AC1: the authored 5-damage bite keeps weight 3")
	var bleed := _authored_alternative(biter, "debuff", 1)
	_check(not bleed.is_empty() and bleed.get("status") == "bleed"
		and int(bleed.get("weight", 0)) == 1,
		"AC1: the authored Bleed 1 alternative keeps weight 1")
	var block := _authored_alternative(biter, "block", 2)
	_check(not block.is_empty() and int(block.get("weight", 0)) == 1,
		"AC1: the authored Block 2 alternative keeps weight 1")
	var slot := CombatEnemyIntents._weighted_slot(1, spec)
	_check(not slot.is_empty() and slot.get("actions", []).size() == 3,
		"AC1: the intent still validates as exactly three weighted alternatives")
	# The live entry service derives the ordinary normal records and the three
	# HP-sorted floor bands from the shipped catalogs.
	var material := RunAuthoredBattleEntry._floor_band_material(null)
	_check(material.get("ok") == true,
		"AC1: live floor-band material builds from the shipped catalogs")
	if not material.get("ok", false):
		return
	var records: Dictionary = material.get("records", {})
	var pools: Dictionary = material.get("pools", {})
	var live: Dictionary = records.get("thread_biter", {})
	_check(not live.is_empty() and live.get("drain") == true
		and live.get("max_hp") == 15
		and live.get("intent", {}).get("target") == "lowest_living_hp",
		"AC1: the live floor-band record keeps Drain, 15 HP and lowest-living targeting")
	var band := _band_containing(pools, "thread_biter")
	_check(not band.is_empty(), "AC1: Thread Biter is eligible in a derived floor band")
	if band.is_empty():
		return
	var floor_number := _floor_in_band(band)
	var witness := 0
	for value in range(1, 401):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var probe := RunV3FloorBandRoster.new().pick(floor_number, 2, rng, pools)
		if probe.get("ok", false) and probe.get("enemy_ids", []).has("thread_biter"):
			witness = value
			break
	_check(witness > 0,
		"AC1: a deterministic sampled band group really contains Thread Biter")
	if witness == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = witness
	var picked := RunV3FloorBandRoster.new().pick(floor_number, 2, rng, pools)
	var group: Array = picked.get("enemy_ids", [])
	var ordered: Array = []
	for enemy_id in group:
		_check(records.has(enemy_id),
			"AC1: every sampled band actor has an authentic record: " + String(enemy_id))
		if records.has(enemy_id):
			ordered.append(records[enemy_id].duplicate(true))
	var roster := CombatEnemies.new(ordered)
	_check(roster.is_valid() and roster.get_enemies().size() == 2,
		"AC1: the sampled authentic band group builds a real CombatEnemies roster")
	if not roster.is_valid():
		return
	var index: int = group.find("thread_biter")
	_check(index >= 0, "AC1: the sampled roster really contains Thread Biter")
	if index < 0:
		return
	var selected: Dictionary = roster.get_enemy(index + 1)
	_check(selected.get("id") == "thread_biter" and selected.get("drain") == true
		and selected.get("max_hp") == 15 and selected.get("hp") == 15
		and selected.get("block") == 0,
		"AC1: the selected authentic roster slot keeps Drain and its full 15 HP")

## AC2/AC3: the shipped record's real announced bite heals exactly the HP it
## removes, never Block-absorbed damage, never past its cap, and heals nothing
## on a non-attack or skipped beat.
func _test_thread_biter_lifesteal_phase() -> void:
	var parsed := _load_parsed()
	var biter := _find(parsed, "thread_biter")
	_check(not biter.is_empty() and biter.get("drain") == true,
		"precondition: the shipped Thread Biter really authors Drain")
	if biter.is_empty():
		return
	var bite := _authored_alternative(biter, "attack", 5)
	var bleed := _authored_alternative(biter, "debuff", 1)
	_check(not bite.is_empty() and not bleed.is_empty(),
		"precondition: the shipped bite and Bleed alternatives exist")
	if bite.is_empty() or bleed.is_empty():
		return
	# AC2: a wounded 8/15 biter restores exactly the 5 HP its real bite removes.
	var party := _party()
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		"AC2 precondition: authentic Warden 40 / Seamstress 30 / Tinker 26 party")
	_check(CombatEnemyIntents.priority_target(party, "lowest_living_hp") == 3,
		"AC2 precondition: the authored policy announces Tinker at slot 3")
	var case := _force_normal_alternative(biter, bite, party)
	_check(not case.is_empty(), "AC2: the shipped bite binds as a real announcement")
	if case.is_empty():
		return
	_check(case.enemies.apply_damage(1, 7)
		and case.enemies.get_enemy(1).get("hp") == 8,
		"AC2 precondition: the Thread Biter really stands at 8 of 15 HP")
	_check(case.intents.size() == 1 and case.intents[0].get("type") == "attack"
		and int(case.intents[0].get("amount", -1)) == 5
		and case.intents[0].get("target_position") == 3,
		"AC2: the real announcement is the authored 5-damage bite on Tinker")
	var receipt := CombatEnemyPhase.new().execute_phase(party, case.enemies,
		case.intents, null, true)
	_check(receipt == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true}]},
		"AC2: the genuine bite keeps the ordinary attack event shape")
	_check(party.get_hero(3).get("hp") == 21 and party.get_hero(3).get("block") == 0,
		"AC2: the unblocked bite removes exactly five Tinker HP")
	_check(case.enemies.get_enemy(1).get("hp") == 13,
		"AC2: the real after-state heals exactly five HP back to 13 of 15")
	_check(case.enemies.get_enemy(1).get("drain") == true
		and case.enemies.get_enemy(1).get("max_hp") == 15
		and case.enemies.get_enemy(1).get("position") == 1,
		"AC2: the heal preserves the attacker's Drain flag, cap and slot")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30,
		"AC2: the other two heroes keep their HP")
	# AC3: five Block absorb the whole bite, so there is no HP loss to drain.
	var blocked_party := _party()
	_check(blocked_party.gain_block(3, 5),
		"AC3 precondition: Tinker really holds five Block")
	var blocked := _force_normal_alternative(biter, bite, blocked_party)
	if not blocked.is_empty():
		_check(blocked.enemies.apply_damage(1, 7)
			and blocked.enemies.get_enemy(1).get("hp") == 8,
			"AC3 precondition: the blocked case starts at 8 of 15 HP")
		var blocked_receipt := CombatEnemyPhase.new().execute_phase(blocked_party,
			blocked.enemies, blocked.intents, null, true)
		_check(blocked_receipt.get("ok") == true
			and blocked_receipt.get("events", [{}])[0].get("applied") == true,
			"AC3: the fully blocked bite still resolves as one applied attack")
		_check(blocked_party.get_hero(3).get("hp") == 26
			and blocked_party.get_hero(3).get("block") == 0
			and blocked.enemies.get_enemy(1).get("hp") == 8,
			"AC3: Block absorbs all five damage and Drain heals nothing")
	# AC3: an attacker already at its cap cannot overheal.
	var capped_party := _party()
	var capped := _force_normal_alternative(biter, bite, capped_party)
	if not capped.is_empty():
		_check(capped.enemies.get_enemy(1).get("hp") == 15,
			"AC3 precondition: the attacker really stands at full 15 HP")
		var capped_receipt := CombatEnemyPhase.new().execute_phase(capped_party,
			capped.enemies, capped.intents, null, true)
		_check(capped_receipt.get("ok") == true
			and capped_party.get_hero(3).get("hp") == 21
			and capped.enemies.get_enemy(1).get("hp") == 15,
			"AC3: a full-HP Thread Biter cannot overheal past 15")
	# AC3: the authored non-attack Bleed beat heals nothing.
	var debuff_party := _party()
	var debuff := _force_normal_alternative(biter, bleed, debuff_party)
	if not debuff.is_empty():
		_check(debuff.enemies.apply_damage(1, 7)
			and debuff.enemies.get_enemy(1).get("hp") == 8,
			"AC3 precondition: the debuff case starts at 8 of 15 HP")
		_check(debuff.intents.size() == 1 and debuff.intents[0].get("type") == "debuff"
			and debuff.intents[0].get("status") == "bleed"
			and int(debuff.intents[0].get("amount", -1)) == 1
			and debuff.intents[0].get("target_position") == 3,
			"AC3: the announcement is the authored Bleed 1 on Tinker")
		var debuff_receipt := CombatEnemyPhase.new().execute_phase(debuff_party,
			debuff.enemies, debuff.intents, null, true)
		_check(debuff_receipt.get("ok") == true
			and debuff_receipt.get("events", [{}])[0].get("applied") == true,
			"AC3: the authored Bleed beat resolves through the real phase")
		_check(debuff_party.get_hero(3).get("hp") == 26
			and debuff_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 1
			and debuff.enemies.get_enemy(1).get("hp") == 8,
			"AC3: a non-attack beat inflicts no HP loss and heals nothing")
	# AC3: a skipped beat cannot fabricate damage or a Drain heal.
	var skipped_party := _party()
	_check(skipped_party.apply_damage(3, 26) and skipped_party.is_downed(3),
		"AC3 precondition: the announced Tinker is already downed")
	var skipped_enemies := CombatEnemies.new([biter.duplicate(true)])
	_check(skipped_enemies.is_valid()
		and skipped_enemies.apply_damage(1, 7)
		and skipped_enemies.get_enemy(1).get("hp") == 8,
		"AC3 precondition: a real wounded Thread Biter at 8 of 15 HP")
	var skipped_before: Array = skipped_party.get_heroes()
	var skipped_receipt := CombatEnemyPhase.new().execute_phase(skipped_party,
		skipped_enemies, [_raw_attack_intent(3)])
	_check(skipped_receipt == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": false}]}
		and skipped_party.get_heroes() == skipped_before
		and skipped_enemies.get_enemy(1).get("hp") == 8,
		"AC3: a skipped bite deals no damage and heals nothing")

## The two harder normals shipped into the live catalog by this batch, exactly as
## their accepted authoring source records them.
func _tough_pair_expected() -> Dictionary:
	return {
		"spindle_ram": {"id": "spindle_ram", "name": "Spindle Ram", "max_hp": 30,
			"art_path": "res://assets/paper/enemies/spindle_ram.png",
			"intent": {"target": "front", "actions": [
				{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
				{"type": "block", "amount": 7, "weight": 2},
				{"type": "attack", "amount": 8, "weight": 3}]}},
		"razor_ribbon_wraith": {"id": "razor_ribbon_wraith", "name": "Razor Ribbon Wraith",
			"max_hp": 27, "art_path": "res://assets/paper/enemies/razor_ribbon_wraith.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
				{"type": "debuff", "status": "exposed", "amount": 1, "weight": 1},
				{"type": "attack", "amount": 9, "weight": 3}]}}
	}

## The live band that owns an ID, derived from the validated pools rather than a
## fixed slot or position.
func _band_containing(pools: Dictionary, id: String) -> String:
	for band in RunV3FloorBandRoster.BAND_KEYS:
		if pools.get(band, []).has(id):
			return band
	return ""

func _floor_in_band(band: String) -> int:
	if band == RunV3FloorBandRoster.BAND_LOW:
		return 2
	if band == RunV3FloorBandRoster.BAND_MID:
		return 6
	if band == RunV3FloorBandRoster.BAND_HIGH:
		return 10
	return 0

## Independent oracle for one sampled group: sorted band candidates, then one
## shrinking-array draw per requested actor on the supplied generator.
func _sampled_band_group(pools: Dictionary, band: String, count: int,
		rng: RandomNumberGenerator) -> Array:
	var remaining: Array = pools.get(band, []).duplicate()
	remaining.sort()
	var group: Array = []
	for _draw in range(count):
		if remaining.is_empty():
			return []
		var index: int = rng.randi_range(0, remaining.size() - 1)
		group.append(remaining[index])
		remaining.remove_at(index)
	return group

## AC1/AC3: both accepted records ship in the live normal catalog, survive the
## real HP-sorted band admission, and replay through deterministic sampled groups.
func _test_tough_normal_pair_live_catalog_and_bands() -> void:
	var parsed := _load_parsed()
	var expected := _tough_pair_expected()
	var ids: Array[String] = []
	for record in parsed:
		if record is Dictionary:
			ids.append(String(record.get("id", "")))
	var source := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/v3_tough_normals.json"))
	_check(not source.is_empty(), "the authored tough-normal source still parses")
	for id in expected:
		var occurrences := 0
		for present in ids:
			if present == String(id):
				occurrences += 1
		_check(occurrences == 1, "shipped harder normal is authored exactly once: " + String(id))
		var live := _find(parsed, String(id))
		_check(not live.is_empty(), "shipped harder normal record present: " + String(id))
		if live.is_empty():
			continue
		_check(_norm(live) == _norm(expected[id]),
			"shipped harder normal has its exact authored fields: " + String(id))
		_check(_norm(live) == _norm(_find(source, String(id))),
			"shipped harder normal is field-equivalent to its authored source: " + String(id))
		_check(live.get("max_hp") is int,
			"shipped harder normal max_hp is a genuine int: " + String(id))
		var spec: Variant = live.get("intent")
		_check(spec is Dictionary and spec.get("target") == expected[id]["intent"]["target"],
			"shipped harder normal keeps its authored target policy: " + String(id))
		var slot := CombatEnemyIntents._weighted_slot(1, spec)
		_check(not slot.is_empty(),
			"shipped harder normal intent validates as a weighted slot: " + String(id))
		var actions: Array = slot.get("actions", [])
		_check(actions.size() == 3,
			"shipped harder normal authors exactly its three alternatives: " + String(id))
		for entry in actions:
			_check(int(entry.get("weight", 0)) > 0,
				"shipped harder normal alternative has a positive weight: " + String(id))
	# Earlier named records survive the append.
	for earlier in ["fray_scavenger", "scissor_crab", "pincushion_hedgehog", "needle_wasp"]:
		_check(ids.has(earlier) and not _find(parsed, earlier).is_empty(),
			"earlier normal survives the append: " + earlier)
	# The real entry service derives the ordinary Fight records and the three
	# contiguous HP-sorted bands from the shipped normal catalogs.
	var material := RunAuthoredBattleEntry._floor_band_material(null)
	_check(material.get("ok") == true, "live floor-band material builds from shipped catalogs")
	if not material.get("ok", false):
		return
	var records: Dictionary = material.get("records", {})
	var pools: Dictionary = material.get("pools", {})
	_check(not records.is_empty() and pools.size() == RunV3FloorBandRoster.BAND_KEYS.size(),
		"live material carries ordinary Fight records and all three floor bands")
	var elite := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/m04_elites.json"))
	var boss := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/boss.json"))
	_check(not elite.is_empty() and not boss.is_empty(),
		"the Elite and Boss catalogs still parse beside the appended normals")
	for id in expected:
		_check(records.has(String(id)), "live Fight records contain " + String(id))
		var band := _band_containing(pools, String(id))
		_check(not band.is_empty(), "new normal is eligible in a derived floor band: " + String(id))
		if band.is_empty():
			continue
		_check(pools[band].has(String(id)) and records[String(id)].get("max_hp")
			== expected[id]["max_hp"],
			"new normal sits in the band its authored HP sorted into: " + String(id))
		_check(_find(elite, String(id)).is_empty() and _find(boss, String(id)).is_empty(),
			"new normal never enters an Elite or Boss roster: " + String(id))
		var floor_number := _floor_in_band(band)
		_check(floor_number > 0, "derived band maps to an ordinary Fight floor: " + String(id))
		if floor_number == 0:
			continue
		var witness := 0
		for value in range(1, 401):
			var rng := RandomNumberGenerator.new()
			rng.seed = value
			var picked := RunV3FloorBandRoster.new().pick(floor_number, 4, rng, pools)
			if picked.get("ok", false) and picked.get("enemy_ids", []).has(String(id)):
				witness = value
				break
		_check(witness > 0, "a deterministic sampled group contains " + String(id))
		if witness == 0:
			continue
		var first_rng := RandomNumberGenerator.new()
		first_rng.seed = witness
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = witness
		var oracle_rng := RandomNumberGenerator.new()
		oracle_rng.seed = witness
		var first := RunV3FloorBandRoster.new().pick(floor_number, 4, first_rng, pools)
		var replay := RunV3FloorBandRoster.new().pick(floor_number, 4, replay_rng, pools)
		var oracle := _sampled_band_group(pools, band, 4, oracle_rng)
		_check(first == replay, "same-seed sampled band group replays exactly: " + String(id))
		_check(first.get("band") == band and first.get("enemy_ids", []) == oracle
			and first_rng.state == oracle_rng.state,
			"sampled group matches the independent shrinking-array oracle: " + String(id))
		var sampled: Array = first.get("enemy_ids", [])
		_check(sampled.size() == 4 and sampled.has(String(id)),
			"sampled group really selects " + String(id))
		var distinct := {}
		var in_band := true
		for sampled_id in sampled:
			distinct[sampled_id] = true
			in_band = in_band and pools[band].has(sampled_id)
		_check(distinct.size() == sampled.size() and in_band,
			"sampled group is distinct and band-safe: " + String(id))

## AC2: both shipped look-driven kits execute through the genuine weighted
## scheduler and enemy phase, bound to the real catalog records.
func _test_tough_normal_pair_phase_actions() -> void:
	var parsed := _load_parsed()
	var ram := _find(parsed, "spindle_ram")
	var wraith := _find(parsed, "razor_ribbon_wraith")
	_check(not ram.is_empty() and not wraith.is_empty(),
		"precondition: both shipped harder normals load for the phase checks")
	if ram.is_empty() or wraith.is_empty():
		return
	# Spindle Ram: the charging bobbin shoves the front hero into the next spot.
	var shove_party := _party()
	var shove_before: Array = shove_party.get_heroes()
	var shove := _force_normal_alternative(ram, _authored_alternative(ram, "shove", 0),
		shove_party)
	_check(not shove.is_empty(), "the shipped Ram shove alternative binds")
	if not shove.is_empty():
		_check(shove.intents.size() == 1 and shove.intents[0].get("type") == "shove"
			and shove.intents[0].get("amount") == 0
			and shove.intents[0].get("target_position") == 1
			and shove.intents[0].get("direction") == 1,
			"the Ram announces its authored +1 shove from the front hero")
		var receipt := CombatEnemyPhase.new().execute_phase(shove_party, shove.enemies,
			shove.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the shipped Ram shove resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "shove" and event.get("applied") == true
				and event.get("target_position") == 1 and event.get("direction") == 1,
				"the phase reports the applied +1 shove")
		_check(shove_party.get_hero(1).get("id") == "seamstress"
			and shove_party.get_hero(2).get("id") == "warden"
			and shove_party.get_hero(3).get("id") == "tinker",
			"the Ram shove swaps only the two front-line positions")
		var before_by_id := {}
		for hero in shove_before:
			before_by_id[hero.id] = hero
		var hp_block_kept := true
		for hero in shove_party.get_heroes():
			var prior: Dictionary = before_by_id.get(hero.id, {})
			hp_block_kept = hp_block_kept and not prior.is_empty() \
				and hero.get("hp") == prior.get("hp") \
				and hero.get("block") == prior.get("block") \
				and hero.get("statuses", {}) == prior.get("statuses", {})
		_check(hp_block_kept, "the shove preserves every hero's HP, Block and statuses")
	# Spindle Ram: the padded body gains exactly its authored 7 Block.
	var block_party := _party()
	var blocked := _force_normal_alternative(ram, _authored_alternative(ram, "block", 7),
		block_party)
	_check(not blocked.is_empty(), "the shipped Ram Block alternative binds")
	if not blocked.is_empty():
		_check(blocked.intents.size() == 1 and blocked.intents[0].get("type") == "block"
			and blocked.intents[0].get("amount") == 7,
			"the Ram announces its authored 7 Block")
		var receipt := CombatEnemyPhase.new().execute_phase(block_party, blocked.enemies,
			blocked.intents, null, true)
		_check(receipt.get("ok") == true,
			"the shipped Ram Block resolves through a real CombatEnemyPhase")
		_check(blocked.enemies.get_enemy(1).get("block") == 7
			and blocked.enemies.get_enemy(1).get("hp") == 30,
			"the Ram really holds 7 Block at its authored 30 HP")
		_check(block_party.get_heroes() == _party().get_heroes(),
			"a self Block changes no hero")
	# Spindle Ram: its 8-damage charge spends hero Block before HP.
	var attack_party := _party()
	_check(attack_party.gain_block(1, 5),
		"precondition: the front hero really holds five Block")
	var ram_attack := _force_normal_alternative(ram, _authored_alternative(ram, "attack", 8),
		attack_party)
	_check(not ram_attack.is_empty(), "the shipped Ram attack alternative binds")
	if not ram_attack.is_empty():
		_check(ram_attack.intents.size() == 1 and ram_attack.intents[0].get("type") == "attack"
			and int(ram_attack.intents[0].get("amount", -1)) == 8
			and ram_attack.intents[0].get("target_position") == 1,
			"the Ram announces its authored 8 damage on the front hero")
		var receipt := CombatEnemyPhase.new().execute_phase(attack_party, ram_attack.enemies,
			ram_attack.intents, null, true)
		_check(receipt.get("ok") == true,
			"the announced 8-damage charge resolves through a real CombatEnemyPhase")
		_check(attack_party.get_hero(1).get("block") == 0
			and attack_party.get_hero(1).get("hp") == 37,
			"five Block absorb five and the remaining three reach the front hero")
		_check(attack_party.get_hero(2).get("hp") == 30
			and attack_party.get_hero(3).get("hp") == 26,
			"the Ram charge touches no other hero")
	# Razor Ribbon Wraith: the razored ribbon ticks Bleed onto the lowest-living hero.
	var bleed_party := _party()
	_check(bleed_party.apply_damage(3, 10),
		"precondition: the Tinker really loses HP and becomes the lowest living")
	var bleed := _force_normal_alternative(wraith, _authored_alternative(wraith, "debuff", 2),
		bleed_party)
	_check(not bleed.is_empty(), "the shipped Wraith Bleed 2 alternative binds")
	if not bleed.is_empty():
		_check(bleed.intents.size() == 1 and bleed.intents[0].get("type") == "debuff"
			and bleed.intents[0].get("status") == "bleed"
			and int(bleed.intents[0].get("amount", -1)) == 2
			and bleed.intents[0].get("target_position") == 3,
			"the Wraith announces its authored Bleed 2 on the lowest-living hero")
		var receipt := CombatEnemyPhase.new().execute_phase(bleed_party, bleed.enemies,
			bleed.intents, null, true)
		_check(receipt.get("ok") == true,
			"the announced Wraith Bleed resolves through a real CombatEnemyPhase")
		_check(bleed_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 2
			and bleed_party.get_hero(3).get("hp") == 16,
			"the Wraith's Bleed 2 lands without costing its target HP")
		for position in [1, 2]:
			_check(bleed_party.get_hero(position).get("statuses", {}).get("bleed", 0) == 0,
				"unaffected hero %d gains no Wraith Bleed" % position)
	# Razor Ribbon Wraith: the exposed seams take one Exposed counter.
	var exposed_party := _party()
	_check(exposed_party.apply_damage(3, 10),
		"precondition: the Tinker is the Wraith's lowest-living target")
	var exposed := _force_normal_alternative(wraith, _authored_alternative(wraith, "debuff", 1),
		exposed_party)
	_check(not exposed.is_empty(), "the shipped Wraith Exposed 1 alternative binds")
	if not exposed.is_empty():
		_check(exposed.intents.size() == 1 and exposed.intents[0].get("type") == "debuff"
			and exposed.intents[0].get("status") == "exposed"
			and int(exposed.intents[0].get("amount", -1)) == 1
			and exposed.intents[0].get("target_position") == 3,
			"the Wraith announces its authored Exposed 1 on the lowest-living hero")
		var receipt := CombatEnemyPhase.new().execute_phase(exposed_party, exposed.enemies,
			exposed.intents, null, true)
		_check(receipt.get("ok") == true,
			"the announced Wraith Exposed resolves through a real CombatEnemyPhase")
		_check(exposed_party.get_hero(3).get("statuses", {}).get("exposed", 0) == 1
			and exposed_party.get_hero(3).get("hp") == 16,
			"the Wraith's Exposed 1 lands without costing its target HP")
		for position in [1, 2]:
			_check(exposed_party.get_hero(position).get("statuses", {}).get("exposed", 0) == 0,
				"unaffected hero %d gains no Wraith Exposed" % position)
	# Razor Ribbon Wraith: its 9-damage slash also passes through hero Block first.
	var slash_party := _party()
	_check(slash_party.apply_damage(3, 10) and slash_party.gain_block(3, 4),
		"precondition: the lowest-living Tinker really holds four Block")
	var slash := _force_normal_alternative(wraith, _authored_alternative(wraith, "attack", 9),
		slash_party)
	_check(not slash.is_empty(), "the shipped Wraith attack alternative binds")
	if not slash.is_empty():
		_check(slash.intents.size() == 1 and slash.intents[0].get("type") == "attack"
			and int(slash.intents[0].get("amount", -1)) == 9
			and slash.intents[0].get("target_position") == 3,
			"the Wraith announces its authored 9 damage on the lowest-living hero")
		var receipt := CombatEnemyPhase.new().execute_phase(slash_party, slash.enemies,
			slash.intents, null, true)
		_check(receipt.get("ok") == true,
			"the announced 9-damage slash resolves through a real CombatEnemyPhase")
		_check(slash_party.get_hero(3).get("block") == 0
			and slash_party.get_hero(3).get("hp") == 11,
			"four Block absorb four and the remaining five reach the back hero")
		_check(slash_party.get_hero(1).get("hp") == 40
			and slash_party.get_hero(2).get("hp") == 30,
			"the Wraith slash touches no other hero")

## The three harder look-driven normals of this V3-2 batch. Identity, HP and the
## exact weighted intent are author-set; the design fixes each foe's look and the
## 5-9 floor-1-4 normal attack band, not the individual weights. These records are
## catalog content only: no encounter pool, floor band or route wiring is claimed.
func _crusher_harrier_doll_expected() -> Dictionary:
	return {
		"clothespin_crusher": {"id": "clothespin_crusher", "name": "Clothespin Crusher",
			"max_hp": 30, "art_path": "res://assets/paper/enemies/clothespin_crusher.png",
			"intent": {"target": "front", "actions": [
				{"type": "snip_block", "amount": 0, "weight": 2},
				{"type": "attack", "amount": 8, "weight": 3},
				{"type": "block", "amount": 7, "weight": 1}]}},
		"crochet_hook_harrier": {"id": "crochet_hook_harrier",
			"name": "Crochet Hook Harrier",
			"max_hp": 26, "art_path": "res://assets/paper/enemies/crochet_hook_harrier.png",
			"intent": {"target": "front", "actions": [
				{"type": "shove", "amount": 0, "direction": -1, "weight": 2},
				{"type": "attack", "amount": 7, "weight": 3},
				{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1}]}},
		"thistle_patch_doll": {"id": "thistle_patch_doll", "name": "Thistle Patch Doll",
			"max_hp": 28, "thorns": 2,
			"art_path": "res://assets/paper/enemies/thistle_patch_doll.png",
			"intent": {"target": "front", "actions": [
				{"type": "block", "amount": 8, "weight": 2},
				{"type": "attack", "amount": 6, "weight": 3}]}}
	}

## Per-ID catalog validation for the appended batch: unique occurrence, exact
## name/HP/art/target/weights and named earlier entries only. No total, ordered
## ID list or guessed insertion index is asserted, so parallel appends stay legal.
func _test_crusher_harrier_doll_catalog_records() -> void:
	var parsed := _load_parsed()
	var ids: Array[String] = []
	for record in parsed:
		if record is Dictionary:
			ids.append(String(record.get("id", "")))
	# Earlier normals named by the brief keep their exact authored records.
	var earlier := _old_expected()
	earlier.merge(_new_expected())
	earlier.merge(_trio_expected())
	earlier.merge(_harder_expected())
	for named in ["scissor_crab", "zipper_snake", "pincushion_hedgehog", "moth_swarm",
			"needle_wasp", "shearwing_mantis", "spoolback_hound", "inkbrush_imp"]:
		_check(ids.has(named), "named earlier normal persists: " + named)
		_check(_norm(_find(parsed, named)) == _norm(earlier[named]),
			"named earlier normal record is unchanged: " + named)
	var expected := _crusher_harrier_doll_expected()
	for new_id in expected:
		var occurrences := 0
		for present in ids:
			if present == String(new_id):
				occurrences += 1
		_check(occurrences == 1, "new normal is authored exactly once: " + String(new_id))
		var record := _find(parsed, String(new_id))
		_check(not record.is_empty(), "new normal record present: " + String(new_id))
		if record.is_empty():
			continue
		_check(record.get("name") == expected[new_id]["name"],
			"new normal keeps its exact authored name: " + String(new_id))
		_check(record.get("max_hp") == expected[new_id]["max_hp"],
			"new normal keeps its authored max HP: " + String(new_id))
		_check(record.get("art_path") == expected[new_id]["art_path"]
			and String(record.get("art_path", "")).begins_with(
				"res://assets/paper/enemies/"),
			"new normal keeps its placeholder-swappable art path: " + String(new_id))
		_check(_norm(record) == _norm(expected[new_id]),
			"new normal has its exact authored fields: " + String(new_id))
		var spec: Variant = record.get("intent")
		_check(spec is Dictionary and spec.get("target") == "front",
			"new normal keeps its front target policy: " + String(new_id))
		_check(not CombatEnemyIntents._weighted_slot(1, spec).is_empty(),
			"new normal intent validates as a weighted slot: " + String(new_id))
		var actions: Variant = spec.get("actions") if spec is Dictionary else null
		_check(actions is Array and not actions.is_empty(),
			"new normal authors weighted action alternatives: " + String(new_id))
		if not actions is Array:
			continue
		_check(actions.size() == expected[new_id]["intent"]["actions"].size(),
			"new normal keeps its authored alternative count: " + String(new_id))
		for raw in actions:
			_check(CombatEnemyIntents.weighted_action(raw) != {},
				"new alternative validates through the weighted scheduler: %s %s"
					% [new_id, str(raw)])
			_check(_alternative_shape_is_exact(raw),
				"new alternative uses supported mechanics and exact fields: %s %s"
					% [new_id, str(raw)])
			_check(int(raw.get("weight", 0)) > 0,
				"new alternative keeps a positive authored weight: " + String(new_id))
			if raw is Dictionary and raw.get("type") == "attack":
				var amount := int(raw.get("amount", 0))
				_check(amount >= 5 and amount <= 9,
					"new normal attack stays inside the authored 5-9 band: " + String(new_id))
	# Look-driven identity: every silhouette acts exactly the way it looks.
	var crusher := _find(parsed, "clothespin_crusher")
	_check(_has_alternative(crusher, "snip_block", 0)
		and _has_alternative(crusher, "attack", 8)
		and _has_alternative(crusher, "block", 7),
		"Clothespin Crusher snips Block away, bites for 8 or clamps for 7 Block")
	var harrier := _find(parsed, "crochet_hook_harrier")
	_check(_has_alternative(harrier, "shove", 0)
		and _has_alternative(harrier, "attack", 7)
		and _has_alternative(harrier, "debuff", 1, "exposed"),
		"Crochet Hook Harrier hooks a hero forward, strikes for 7 or marks Exposed 1")
	_check(int(_authored_alternative(harrier, "shove", 0).get("direction", 0)) == -1,
		"the Harrier's oversized hook pulls toward the front rather than pushing")
	var doll := _find(parsed, "thistle_patch_doll")
	_check(_has_alternative(doll, "block", 8) and _has_alternative(doll, "attack", 6),
		"Thistle Patch Doll reinforces for 8 Block or swipes for 6")
	_check(doll.get("thorns") is int and doll.get("thorns") == 2,
		"Thistle Patch Doll exposes its authored Thorns 2 as a genuine int")

## A genuine seeded three-enemy CombatEnemies roster of the appended records,
## bound to the real weighted scheduler over a living Warden/Seamstress/Tinker
## party. Forced alternatives come from the parsed records, never from guessed
## seeds, so each authored move is announced and checked on its own.
func _test_crusher_harrier_doll_seeded_announcements() -> void:
	var parsed := _load_parsed()
	var selected: Array = []
	for id in ["clothespin_crusher", "crochet_hook_harrier", "thistle_patch_doll"]:
		var record := _find(parsed, id)
		_check(not record.is_empty(), "authentic new normal source present: " + id)
		selected.append(record)
	_check(selected.size() == 3 and not selected.has({}),
		"precondition: all three authentic records loaded")
	if selected.size() != 3 or selected.has({}):
		return
	var party := _party()
	_check(party.is_valid() and party.get_heroes().size() == CombatParty.PARTY_SIZE,
		"precondition: a valid three-hero CombatParty")
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		_check(party.get_hero(position).get("hp", 0) > 0,
			"precondition: hero slot %d is living" % position)
	var first := _bind(774411, selected)
	var second := _bind(774411, selected)
	_check(first.get("ok") == true and second.get("ok") == true,
		"the three new normals bind on identical seeds")
	_check(first.scheduler.is_bound() and second.scheduler.is_bound(),
		"both seeded bindings report the weighted mode")
	var first_intents: Array = first.scheduler.get_intents()
	var second_intents: Array = second.scheduler.get_intents()
	_check(first_intents.size() == 3, "one announcement per new normal")
	_check(first_intents == second_intents,
		"same-seed first-turn announcements replay identically")
	_check(first.rng.state == second.rng.state,
		"same-seed bindings leave matching RNG state")
	var state_before: int = first.rng.state
	_check(first.scheduler.get_intents() == first_intents and first.rng.state == state_before,
		"reading bound announcements neither changes them nor consumes RNG")
	for index in range(first_intents.size()):
		var announced: Dictionary = first_intents[index]
		var source: Dictionary = selected[index]
		_check(announced.get("enemy_position") == index + 1,
			"announcement keeps its source slot: " + String(source.get("id", "")))
		_check(_is_authored_alternative(source, announced),
			"announcement is one of the authored alternatives: "
				+ String(source.get("id", "")))
		if announced.get("type") in ["attack", "debuff", "snip_block"]:
			_check(announced.get("target_position") == 1,
				"front policy announces the front hero: " + String(source.get("id", "")))
		if announced.get("type") == "shove":
			_check(announced.get("target_position") == 2
				and announced.get("direction") == -1,
				"the Harrier pull announces the middle hero dragged forward")
	# Every authored alternative is forced from the genuine record, so no seed
	# can hide one behind a lucky roll and production weights stay untouched.
	var forced := [
		{"id": "clothespin_crusher",
			"action": {"type": "snip_block", "amount": 0, "weight": 1}},
		{"id": "clothespin_crusher",
			"action": {"type": "attack", "amount": 8, "weight": 1}},
		{"id": "clothespin_crusher",
			"action": {"type": "block", "amount": 7, "weight": 1}},
		{"id": "crochet_hook_harrier",
			"action": {"type": "shove", "amount": 0, "direction": -1, "weight": 1}},
		{"id": "crochet_hook_harrier",
			"action": {"type": "attack", "amount": 7, "weight": 1}},
		{"id": "crochet_hook_harrier",
			"action": {"type": "debuff", "amount": 1, "status": "exposed", "weight": 1}},
		{"id": "thistle_patch_doll",
			"action": {"type": "block", "amount": 8, "weight": 1}},
		{"id": "thistle_patch_doll",
			"action": {"type": "attack", "amount": 6, "weight": 1}}]
	for case in forced:
		var record := _find(parsed, String(case.id))
		_check(not record.is_empty(), "forced alternative source present: " + String(case.id))
		if record.is_empty():
			continue
		var forced_record: Dictionary = record.duplicate(true)
		forced_record["intent"] = {"target": "front", "actions": [case.action]}
		var forced_enemies := CombatEnemies.new([forced_record])
		var forced_rng := RandomNumberGenerator.new()
		forced_rng.seed = 774411
		var forced_scheduler := CombatEnemyIntents.new(
			[_enemy(1, [{"type": "block", "amount": 1}])])
		var did_bind := forced_enemies.is_valid() \
			and forced_scheduler.bind_battle(forced_enemies, party, forced_rng)
		_check(did_bind, "forced alternative binds: %s %s" % [case.id, str(case.action)])
		if not did_bind:
			continue
		var announced: Dictionary = forced_scheduler.get_intents()[0]
		_check(announced.get("type") == case.action.type
			and int(announced.get("amount", -1)) == int(case.action.amount),
			"forced alternative announces its authored effect: %s %s"
				% [case.id, str(case.action)])
		if case.action.has("status"):
			_check(announced.get("status") == case.action.status,
				"forced debuff keeps its authored status: " + String(case.action.status))
		if announced.get("type") == "shove":
			_check(announced.get("target_position") == 2
				and announced.get("direction") == -1,
				"forced Harrier pull announces hero 2 toward the front")
			_check(CombatEnemyIntents.shove_is_legal(party, 2, -1),
				"precondition: the announced middle-to-front pull is legal")
		elif announced.get("type") in ["attack", "debuff", "snip_block"]:
			_check(announced.get("target_position") == 1,
				"forced alternative honours the front policy: " + String(case.id))

## The genuine announced special actions of the appended batch, executed by the
## real CombatEnemyPhase: the Crusher clamp snips Block without HP loss, and the
## Harrier hook drags the middle hero forward while exposing a living target.
func _test_crusher_harrier_doll_phase_actions() -> void:
	var parsed := _load_parsed()
	var crusher := _find(parsed, "clothespin_crusher")
	var harrier := _find(parsed, "crochet_hook_harrier")
	_check(not crusher.is_empty() and not harrier.is_empty(),
		"authentic Crusher and Harrier records present for the phase checks")
	if crusher.is_empty() or harrier.is_empty():
		return
	# Clothespin Crusher: the giant clamp snips the front hero's Block cleanly.
	var snip_party := _party()
	_check(snip_party.gain_block(1, 5),
		"precondition: the front hero really holds five Block")
	_check(snip_party.get_hero(1).get("hp") == 40
		and snip_party.get_hero(1).get("block") == 5
		and snip_party.get_hero(2).get("block") == 0,
		"precondition: only the front hero owns Block and everyone is at full HP")
	var snip := _force_normal_alternative(crusher,
		_authored_alternative(crusher, "snip_block", 0), snip_party)
	if not snip.is_empty():
		_check(snip.intents.size() == 1 and snip.intents[0].get("type") == "snip_block"
			and int(snip.intents[0].get("amount", -1)) == 0
			and snip.intents[0].get("target_position") == 1,
			"Crusher snip announces a zero-amount Block strip on the front hero")
		var receipt := CombatEnemyPhase.new().execute_phase(snip_party, snip.enemies,
			snip.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced Crusher snip resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event == {"type": "snip_block", "enemy_position": 1, "applied": true,
				"target_position": 1},
				"the phase receipt keeps the existing applied snip shape")
		_check(snip_party.get_hero(1).get("block") == 0
			and snip_party.get_hero(1).get("hp") == 40,
			"Crusher snip leaves the front hero at zero Block and unchanged HP")
		_check(snip_party.get_hero(2).get("hp") == 30 and snip_party.get_hero(2).get("block") == 0
			and snip_party.get_hero(3).get("hp") == 26,
			"Crusher snip never touches the other heroes")
	# Crochet Hook Harrier: the oversized hook snags the middle hero forward.
	var pull_party := _party()
	_check(pull_party.get_hero(1).get("id") == "warden"
		and pull_party.get_hero(2).get("id") == "seamstress"
		and pull_party.get_hero(3).get("id") == "tinker",
		"precondition: Warden, Seamstress and Tinker fill slots 1-3")
	_check(pull_party.apply_damage(1, 10) and pull_party.gain_block(1, 4)
		and pull_party.apply_damage(2, 4) and pull_party.gain_block(2, 2)
		and pull_party.apply_damage(3, 6),
		"precondition: every hero carries distinct HP and Block")
	pull_party._heroes[0]["statuses"] = {"weak": 2}
	pull_party._heroes[1]["statuses"] = {"exposed": 1}
	pull_party._heroes[2]["statuses"] = {"bleed": 3}
	var before := {}
	for hero in pull_party.get_heroes():
		before[hero.id] = hero.duplicate(true)
	_check(CombatEnemyIntents.shove_is_legal(pull_party, 2, -1),
		"precondition: the middle-to-front pull is unobstructed and legal")
	var pull := _force_normal_alternative(harrier,
		_authored_alternative(harrier, "shove", 0), pull_party)
	if not pull.is_empty():
		_check(pull.intents.size() == 1 and pull.intents[0].get("type") == "shove"
			and pull.intents[0].get("enemy_position") == 1
			and pull.intents[0].get("target_position") == 2
			and pull.intents[0].get("direction") == -1,
			"the bound Harrier announces hero 2 pulled toward the front slot")
		var committed: int = pull.rng.state
		_check(pull.scheduler.get_intents() == pull.intents and pull.rng.state == committed,
			"the genuine Harrier pull replays without spending run RNG")
		var receipt := CombatEnemyPhase.new().execute_phase(pull_party, pull.enemies,
			pull.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the genuine Harrier pull resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "shove" and event.get("enemy_position") == 1
				and event.get("target_position") == 2 and event.get("direction") == -1
				and event.get("applied") == true,
				"the phase applies exactly the authored -1 middle-to-front pull")
		_check(pull_party.get_hero(1).get("id") == "seamstress"
			and pull_party.get_hero(1).get("position") == 1,
			"the Harrier hook drags Seamstress into the front slot")
		_check(pull_party.get_hero(2).get("id") == "warden"
			and pull_party.get_hero(2).get("position") == 2,
			"Warden falls back to the middle slot")
		_check(pull_party.get_hero(3).get("id") == "tinker"
			and pull_party.get_hero(3).get("position") == 3,
			"Tinker stays untouched in the back slot")
		var after := {}
		for hero in pull_party.get_heroes():
			after[hero.id] = hero
		for id in ["warden", "seamstress", "tinker"]:
			_check(after.has(id) and before.has(id),
				"the pull keeps the original actor " + id)
			if not after.has(id) or not before.has(id):
				continue
			_check(after[id].get("hp") == before[id].get("hp")
				and after[id].get("block") == before[id].get("block")
				and after[id].get("statuses", {}) == before[id].get("statuses", {}),
				"the pull preserves " + id + " HP, Block and statuses")
	# Exposed 1 lands on the living front hero the policy really names.
	var expose_party := _party()
	_check(CombatEnemyIntents.priority_target(expose_party, "front") == 1
		and not expose_party.is_downed(1),
		"precondition: the front policy target is living")
	var expose := _force_normal_alternative(harrier,
		_authored_alternative(harrier, "debuff", 1), expose_party)
	if not expose.is_empty():
		_check(expose.intents.size() == 1 and expose.intents[0].get("type") == "debuff"
			and expose.intents[0].get("status") == "exposed"
			and int(expose.intents[0].get("amount", -1)) == 1
			and expose.intents[0].get("target_position") == 1,
			"the Harrier marks the living front hero with Exposed 1")
		var receipt := CombatEnemyPhase.new().execute_phase(expose_party, expose.enemies,
			expose.intents, null, true)
		_check(receipt.get("ok") == true
			and receipt.get("events", [{}])[0].get("applied") == true,
			"the announced Exposed 1 resolves through a real CombatEnemyPhase")
		_check(expose_party.get_hero(1).get("statuses", {}).get("exposed", 0) == 1,
			"Exposed 1 lands on the living policy target")
		_check(expose_party.get_hero(1).get("hp") == 40,
			"the Exposed mark costs the target no HP")
		for position in [2, 3]:
			_check(expose_party.get_hero(position).get("statuses", {}).get("exposed", 0) == 0,
				"unmarked hero %d gains no Exposed" % position)

## The Thistle Patch Doll's genuine parsed integer-Thorns definition driven
## through the real held-card CombatAttackCards route: a confirmed hit retaliates
## against the card owner's Block before HP, and an unthorned or rejected hit
## never does. Only Thorns 2 is authored here; no shared combat rules change.
func _test_thistle_patch_doll_thorns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_check(raw is Array, "raw enemy catalog JSON parses for the Doll Thorns precondition")
	var raw_doll := _find(raw if raw is Array else [], "thistle_patch_doll")
	_check(raw_doll.get("thorns") is float and raw_doll.get("thorns") == 2.0,
		"precondition: the Doll's authored Thorns arrives from JSON as a double")
	var parsed_doll := _find(_load_parsed(), "thistle_patch_doll")
	_check(parsed_doll.get("thorns") is int,
		"the strict catalog parser normalizes the Doll's Thorns to a genuine int")
	var answer := _assemble(["thistle_patch_doll", "moth_swarm"])
	_check(answer.get("ok") == true,
		"the Doll roster assembles through the genuine typed-roster bridge")
	if not answer.get("ok", false):
		return
	var enemies: Variant = answer.get("enemies")
	_check(enemies is CombatEnemies and enemies.is_valid()
		and enemies.get_enemies().size() == 2, "the bridge builds two real actors")
	if not enemies is CombatEnemies or not enemies.is_valid():
		return
	var doll: Dictionary = enemies.get_enemy(1)
	_check(doll.get("id") == "thistle_patch_doll" and doll.get("max_hp") == 28
		and doll.get("hp") == 28 and doll.get("block") == 0,
		"typed Doll starts at its authored 28 HP and zero Block")
	_check(doll.get("thorns") is int and doll.get("thorns") == 2,
		"typed roster exposes the Doll's Thorns as a genuine int 2")
	_check(not enemies.get_enemy(2).has("thorns"),
		"precondition: the ordinary Moth Swarm carries no Thorns metadata")
	var party := _party()
	var deck := _attack_deck("warden_strike")
	_check(party.gain_block(1, 1), "Warden really owns one Block before the confirmed hit")
	var party_before := party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var attacks := CombatAttackCards.new()
	var forecast := attacks.forecast_attack(deck, party, enemies, "warden_strike")
	_check(forecast.get("playable") == true and forecast.get("hits", []).size() == 2
		and {"position": 1, "damage": 6} in forecast.get("hits", []),
		"the real held Strike forecast offers the Doll at six damage")
	_check(party.get_heroes() == party_before and enemies.get_enemies() == enemies_before,
		"a pure forecast never triggers the Doll's Thorns nor damages any actor")
	var result := attacks.play_attack(deck, party, enemies, "warden_strike", 1)
	_check(result.get("ok") == true and result.get("hits", []).size() == 1,
		"the real held-card attack against the Doll commits")
	var hit: Dictionary = result.get("hits", [{}])[0]
	_check(hit.get("position") == 1 and hit.get("damage") == 6
		and hit.get("block_absorbed") == 0 and hit.get("hp_loss") == 6,
		"the confirmed-hit receipt keeps the authored six damage and old schema")
	_check(enemies.get_enemy(1).get("hp") == 22,
		"the Doll takes the confirmed six damage")
	var warden: Dictionary = party.get_hero(1)
	_check(warden.get("block") == 0 and warden.get("hp") == 39,
		"Thorns 2 consumes Warden's one Block and then one HP")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		"Thorns retaliation lands only on the attacking hero")
	# Block fully absorbing the retaliation protects the attacker's HP.
	var absorbed_party := _party()
	var absorbed_deck := _attack_deck("warden_strike")
	_check(absorbed_party.gain_block(1, 2),
		"precondition: Warden really holds two Block")
	var absorbed_answer := _assemble(["thistle_patch_doll"])
	_check(absorbed_answer.get("ok") == true,
		"single Doll roster assembles for the absorbed retaliation")
	if not absorbed_answer.get("ok", false):
		return
	var absorbed_enemies: CombatEnemies = absorbed_answer["enemies"]
	var absorbed := CombatAttackCards.new().play_attack(absorbed_deck, absorbed_party,
		absorbed_enemies, "warden_strike", 1)
	_check(absorbed.get("ok") == true and absorbed_party.get_hero(1).get("block") == 0
		and absorbed_party.get_hero(1).get("hp") == 40,
		"two Block absorb the whole Thorns 2 retaliation and leave Warden HP untouched")
	_check(absorbed_enemies.get_enemy(1).get("hp") == 22,
		"the absorbed retaliation still follows the confirmed six damage")
	# Control: a confirmed hit on the non-thorned authored Moth Swarm never
	# retaliates, so a green Doll hit cannot merely echo shared damage.
	var control_party := _party()
	var control_deck := _attack_deck("warden_strike")
	var control_answer := _assemble(["thistle_patch_doll", "moth_swarm"])
	_check(control_answer.get("ok") == true,
		"control roster assembles for the no-Thorns hit")
	if not control_answer.get("ok", false):
		return
	var control_enemies: CombatEnemies = control_answer["enemies"]
	var control := CombatAttackCards.new().play_attack(control_deck, control_party,
		control_enemies, "warden_strike", 2)
	_check(control.get("ok") == true and control_party.get_hero(1).get("hp") == 40
		and control_party.get_hero(1).get("block") == 0
		and control_enemies.get_enemy(2).get("hp") == 15,
		"a confirmed hit on the unthorned Moth Swarm costs the attacker nothing")
	# Control: a rejected wrong-target attack is uncommitted, so it triggers no
	# Thorns and changes no hero, enemy, hand, discard pile or energy.
	var rejected_party := _party()
	var rejected_deck := _attack_deck("warden_strike")
	var rejected_answer := _assemble(["thistle_patch_doll"])
	_check(rejected_answer.get("ok") == true,
		"single Doll roster assembles for the rejection control")
	if not rejected_answer.get("ok", false):
		return
	var rejected_enemies: CombatEnemies = rejected_answer["enemies"]
	var hand_before: Array[String] = rejected_deck.hand.duplicate()
	var discard_before: Array[String] = rejected_deck.discard_pile.duplicate()
	var rejected := CombatAttackCards.new().play_attack(rejected_deck, rejected_party,
		rejected_enemies, "warden_strike", 3)
	_check(rejected == {"ok": false, "hits": []}
		and rejected_party.get_hero(1).get("hp") == 40
		and rejected_party.get_hero(1).get("block") == 0
		and rejected_enemies.get_enemy(1).get("hp") == 28
		and rejected_deck.energy == 3,
		"a rejected zero-hit attack never triggers Thorns and mutates nothing")
	_check(rejected_deck.hand == hand_before
		and rejected_deck.discard_pile == discard_before,
		"the rejected attack leaves the real held card and discard pile unchanged")
	# Malformed Thorns on this exact record still fails the catalog closed.
	var malformed_doll := parsed_doll.duplicate(true)
	malformed_doll["thorns"] = 2.5
	_check(RunTypedBattleRoster._parse_catalog_text(
		JSON.stringify([malformed_doll])).is_empty(),
		"a non-integral Doll Thorns value rejects the whole catalog")

## AC1: the shipped Moth Swarm opts into its cloth-eating bite with exactly one
## boolean metadata field; 21 HP, art, front target and the 0/7/Weak-1
## alternatives with weights 2/3/1 stay untouched. The strict catalog parser
## accepts only a genuine boolean (or an absent key) and rejects everything else.
func _test_moth_swarm_block_chew_catalog() -> void:
	var parsed := _load_parsed()
	var moth := _find(parsed, "moth_swarm")
	_check(not moth.is_empty(), "precondition: the shipped Moth Swarm record loads")
	if moth.is_empty():
		return
	_check(moth.get("chew_block_on_attack") is bool
		and moth.get("chew_block_on_attack") == true,
		"AC1: the parsed Moth Swarm authors chew_block_on_attack as a genuine bool")
	_check(_norm(moth) == _norm(_trio_expected()["moth_swarm"]),
		"AC1: the exact Moth record keeps its authored fields and alternatives")
	var established: Dictionary = _trio_expected()["moth_swarm"].duplicate(true)
	established.erase("chew_block_on_attack")
	var without_trait: Dictionary = moth.duplicate(true)
	without_trait.erase("chew_block_on_attack")
	_check(_norm(without_trait) == _norm(established),
		"AC1: the new boolean is the only difference from the established Moth record")
	_check(moth.get("intent", {}).get("target") == "front"
		and int(moth.get("max_hp", 0)) == 21
		and String(moth.get("art_path", "")) == "res://assets/paper/enemies/moth_swarm.png",
		"AC1: Moth keeps its 21 HP, art path and front target")
	var snip := _authored_alternative(moth, "snip_block", 0)
	var bite := _authored_alternative(moth, "attack", 7)
	var weaken := _authored_alternative(moth, "debuff", 1)
	_check(not snip.is_empty() and not bite.is_empty() and not weaken.is_empty()
		and weaken.get("status") == "weak",
		"AC1: the authored 0 snip, 7 bite and Weak 1 alternatives stay authored")
	_check(int(snip.get("weight", 0)) == 2 and int(bite.get("weight", 0)) == 3
		and int(weaken.get("weight", 0)) == 1,
		"AC1: the authored weights stay exactly 2/3/1")
	var carriers: Array[String] = []
	for record in parsed:
		if record is Dictionary and record.get("chew_block_on_attack") is bool \
				and record.get("chew_block_on_attack") == true:
			carriers.append(String(record.get("id", "")))
	# The trait is shared authored content, so each named opt-in is checked on
	# its own and the named non-carrier proves the per-ID checks still bite.
	_check(carriers.has("moth_swarm"),
		"AC1: chew_block_on_attack=true is authored by the Moth Swarm: " + str(carriers))
	_check(carriers.has("scissor_crab"),
		"AC1: chew_block_on_attack=true is authored by the Scissor Crab: " + str(carriers))
	_check(not carriers.has("thimble_beetle"),
		"AC1: the Thimble Beetle stays the unflagged named control: " + str(carriers))
	_check(_find(parsed, "moth_swarm").get("chew_block_on_attack") == true
		and _find(parsed, "scissor_crab").get("chew_block_on_attack") == true
		and not _find(parsed, "thimble_beetle").has("chew_block_on_attack"),
		"AC1: the named records carry exactly their own authored trait state")
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([moth])).size() == 1,
		"AC1: the genuine boolean trait keeps the whole catalog valid")
	_check(RunTypedBattleRoster._parse_catalog_text(
		JSON.stringify([without_trait])).size() == 1,
		"AC4: an absent trait stays valid metadata")
	var disabled: Dictionary = moth.duplicate(true)
	disabled["chew_block_on_attack"] = false
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([disabled])).size() == 1,
		"AC4: an explicit false stays valid metadata")
	for invalid_value in ["true", 1, 1.0, null, [], {}]:
		var malformed: Dictionary = moth.duplicate(true)
		malformed["chew_block_on_attack"] = invalid_value
		_check(RunTypedBattleRoster._parse_catalog_text(
			JSON.stringify([malformed])).is_empty(),
			"AC4: malformed chew metadata rejects the whole catalog: " + str(invalid_value))

## Bind a genuine seeded multi-source encounter where every source announces
## exactly one authored alternative. Production weights stay untouched and no
## guessed seed chooses a beat, so an ordered shove-then-bite batch is real.
func _force_normal_batch(sources: Array, actions: Array,
		party: CombatParty) -> Dictionary:
	if sources.is_empty() or sources.size() != actions.size() \
			or sources.size() > CombatEnemies.MAX_ENEMIES or party == null:
		return {}
	var forced: Array = []
	var definitions: Array = []
	for index in range(sources.size()):
		var source: Variant = sources[index]
		var normalized := CombatEnemyIntents.weighted_action(actions[index])
		_check(not normalized.is_empty(),
			"forced batch alternative is a valid authored action: " + str(actions[index]))
		if not source is Dictionary or source.is_empty() or normalized.is_empty():
			return {}
		var action: Dictionary = normalized["action"].duplicate(true)
		action["weight"] = 1
		var forced_record: Dictionary = source.duplicate(true)
		forced_record["intent"] = {"target": source["intent"]["target"], "actions": [action]}
		forced.append(forced_record)
		definitions.append(_enemy(index + 1, [{"type": "block", "amount": 1}]))
	var enemies := CombatEnemies.new(forced)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2631
	var scheduler := CombatEnemyIntents.new(definitions)
	var bound := enemies.is_valid() and scheduler.bind_battle(enemies, party, rng)
	_check(bound, "forced multi-source encounter binds")
	if not bound:
		return {}
	return {"enemies": enemies, "intents": scheduler.get_intents(), "rng": rng,
		"scheduler": scheduler}

## AC2: a living opted-in Moth Swarm's real authored bite eats the actual
## recipient's Block before its status-adjusted seven lands, including after a
## Guard redirect and an earlier staged swap. AC3: non-attack, non-opted-in,
## explicit-false, absent and slain cases keep the old behavior. AC4: malformed
## metadata and rejected beats stay atomic and replay deterministically.
func _test_moth_swarm_block_chew_phase() -> void:
	var parsed := _load_parsed()
	var moth := _find(parsed, "moth_swarm")
	_check(not moth.is_empty() and moth.get("chew_block_on_attack") == true,
		"precondition: the shipped Moth Swarm really authors the cloth-eating bite")
	if moth.is_empty() or moth.get("chew_block_on_attack") != true:
		return
	var bite := _authored_alternative(moth, "attack", 7)
	var snip := _authored_alternative(moth, "snip_block", 0)
	var weaken := _authored_alternative(moth, "debuff", 1)
	_check(not bite.is_empty() and not snip.is_empty() and not weaken.is_empty(),
		"precondition: the authored Moth alternatives exist")
	if bite.is_empty() or snip.is_empty() or weaken.is_empty():
		return

	# AC2: 6 Block and full 40 HP lose the Block first, then the full seven.
	var party := _party()
	_check(party.get_hero(1).get("hp") == 40 and party.gain_block(1, 6),
		"AC2 precondition: the front hero really holds 40 HP and six Block")
	var case := _force_normal_alternative(moth, bite, party)
	_check(not case.is_empty(), "AC2: the shipped bite binds as a real announcement")
	if case.is_empty():
		return
	_check(case.intents.size() == 1 and case.intents[0].get("type") == "attack"
		and int(case.intents[0].get("amount", -1)) == 7
		and case.intents[0].get("target_position") == 1,
		"AC2: the real announcement is the authored seven-damage bite on the front hero")
	var committed: int = case.rng.state
	var receipt := CombatEnemyPhase.new().execute_phase(party, case.enemies,
		case.intents, null, true)
	_check(receipt == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true}]},
		"AC2: the cloth-eating bite keeps the ordinary attack event shape")
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(1).get("hp") == 33,
		"AC2: 6 Block + 40 HP => 0 Block + 33 HP in that one bite")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26,
		"AC2: the cloth-eating bite touches no other hero")
	_check(case.rng.state == committed and case.scheduler.get_intents() == case.intents,
		"AC4: the executed bite spends no extra run RNG and replays its announcement")

	# AC2: Guard redirects the bite to the Warden's real slot after a staged
	# forward swap; the Warden's six Block are eaten, the announced hero is not.
	var guard_party := _party()
	var guard_deck := _guard_deck(["warden_draw_fire", "warden_iron_hem",
		"warden_hold_the_line", "warden_quick_darn", "warden_counter_stitch"])
	var reactions := CombatWardenGuardReactions.new()
	_check(reactions.play_from_hand(guard_deck, guard_party, "warden_draw_fire")
		and reactions.is_guarding() and guard_party.get_hero(1).get("block") == 6,
		"precondition: the real paid Draw Fire activates Guarding and six Block")
	var leash_source := _find(parsed, "spoolback_hound")
	_check(not leash_source.is_empty(), "precondition: an authentic authored shove source")
	var leash := _authored_alternative(leash_source, "shove", 0)
	_check(not leash_source.is_empty() and not leash.is_empty(),
		"precondition: the authentic +1 leash alternative exists")
	if not leash_source.is_empty() and not leash.is_empty():
		var redirect_case := _force_normal_batch([leash_source, moth], [leash, bite],
			guard_party)
		_check(not redirect_case.is_empty(),
			"AC2: the shove-then-bite pair binds as real announcements")
		if not redirect_case.is_empty():
			_check(redirect_case.intents.size() == 2
				and redirect_case.intents[0].get("type") == "shove"
				and redirect_case.intents[1].get("type") == "attack"
				and redirect_case.intents[1].get("target_position") == 1,
				"AC2: the batch announces the +1 shove then the bite on the front slot")
			var redirect_receipt := CombatEnemyPhase.new().execute_phase(guard_party,
				redirect_case.enemies, redirect_case.intents, reactions, true)
			_check(redirect_receipt.get("ok") == true
				and redirect_receipt.get("events", []).size() == 2,
				"AC2: the redirected cloth-eating bite resolves through the real reactions")
			if redirect_receipt.get("ok", false) \
					and redirect_receipt.get("events", []).size() == 2:
				var redirect_event: Dictionary = redirect_receipt["events"][1]
				_check(redirect_event.get("target_position") == 1
					and redirect_event.get("actual_target_position") == 2
					and redirect_event.get("redirected") == true,
					"AC2: the receipt keeps the front slot and reports the Warden recipient")
			_check(guard_party.get_hero(2).get("id") == "warden"
				and guard_party.get_hero(2).get("block") == 0
				and guard_party.get_hero(2).get("hp") == 33,
				"AC2: the redirected Warden eats the bite's six Block and loses seven HP")
			_check(guard_party.get_hero(1).get("id") == "seamstress"
				and guard_party.get_hero(1).get("hp") == 30
				and guard_party.get_hero(1).get("block") == 0,
				"AC2: the announced Seamstress is untouched by the redirected bite")

	# AC3: the non-Moth control still blocks normally: six absorb six of seven.
	var control_party := _party()
	_check(control_party.gain_block(1, 6),
		"AC3 precondition: the front hero really holds six Block")
	var control_case := _force_normal_alternative(leash_source,
		_authored_alternative(leash_source, "attack", 7), control_party)
	_check(not control_case.is_empty(), "AC3: the non-Moth seven-damage control binds")
	if not control_case.is_empty():
		var control_receipt := CombatEnemyPhase.new().execute_phase(control_party,
			control_case.enemies, control_case.intents, null, true)
		_check(control_receipt.get("ok") == true, "AC3: the non-Moth attack resolves")
		_check(control_party.get_hero(1).get("block") == 0
			and control_party.get_hero(1).get("hp") == 39,
			"AC3: a non-opted-in attack keeps 6 Block + 39 HP on the old Block-first path")

	# AC3: an explicit false or absent trait keeps the old Block-first behavior.
	var disabled_record: Dictionary = moth.duplicate(true)
	disabled_record["chew_block_on_attack"] = false
	var disabled_party := _party()
	_check(disabled_party.gain_block(1, 6),
		"AC3 precondition: six Block for the explicit-false Moth")
	var disabled_case := _force_normal_alternative(disabled_record, bite, disabled_party)
	if not disabled_case.is_empty():
		var disabled_receipt := CombatEnemyPhase.new().execute_phase(disabled_party,
			disabled_case.enemies, disabled_case.intents, null, true)
		_check(disabled_receipt.get("ok") == true
			and disabled_party.get_hero(1).get("block") == 0
			and disabled_party.get_hero(1).get("hp") == 39,
			"AC3: an explicit false Moth still blocks instead of chewing")
	var absent_record: Dictionary = moth.duplicate(true)
	absent_record.erase("chew_block_on_attack")
	var absent_party := _party()
	_check(absent_party.gain_block(1, 6),
		"AC3 precondition: six Block for the trait-less Moth")
	var absent_case := _force_normal_alternative(absent_record, bite, absent_party)
	if not absent_case.is_empty():
		var absent_receipt := CombatEnemyPhase.new().execute_phase(absent_party,
			absent_case.enemies, absent_case.intents, null, true)
		_check(absent_receipt.get("ok") == true
			and absent_party.get_hero(1).get("block") == 0
			and absent_party.get_hero(1).get("hp") == 39,
			"AC3: a missing trait stays inert and blocks normally")

	# AC3: a slain Moth's announced bite eats nothing and deals nothing.
	var slain_party := _party()
	_check(slain_party.gain_block(1, 6),
		"AC3 precondition: six Block before the slain Moth's beat")
	var slain_case := _force_normal_alternative(moth, bite, slain_party)
	if not slain_case.is_empty():
		_check(slain_case.enemies.apply_damage(1, 21) and slain_case.enemies.is_slain(1),
			"AC3 precondition: the Moth is genuinely slain before its beat")
		var slain_heroes: Array = slain_party.get_heroes()
		var slain_roster: Array = slain_case.enemies.get_enemies()
		var slain_receipt := CombatEnemyPhase.new().execute_phase(slain_party,
			slain_case.enemies, slain_case.intents, null, true)
		_check(slain_receipt == {"ok": true, "events": [
			{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false}]},
			"AC3: a slain Moth's announced bite resolves as one inert beat")
		_check(slain_party.get_heroes() == slain_heroes
			and slain_case.enemies.get_enemies() == slain_roster,
			"AC3: a slain Moth eats no Block and deals no damage")

	# AC3: the standalone authored snip stays a Block strip, with no extra bite.
	var snip_party := _party()
	_check(snip_party.gain_block(1, 6),
		"AC3 precondition: six Block before the standalone snip")
	var snip_case := _force_normal_alternative(moth, snip, snip_party)
	if not snip_case.is_empty():
		var snip_receipt := CombatEnemyPhase.new().execute_phase(snip_party,
			snip_case.enemies, snip_case.intents, null, true)
		_check(snip_receipt == {"ok": true, "events": [
			{"type": "snip_block", "enemy_position": 1, "target_position": 1, "applied": true}]},
			"AC3: the standalone snip is one ordered Block strip with no extra bite")
		_check(snip_party.get_hero(1).get("block") == 0
			and snip_party.get_hero(1).get("hp") == 40,
			"AC3: the standalone snip zeroes Block and costs no HP")

	# AC3: the standalone Weak 1 keeps the hero's Block and HP untouched.
	var weak_party := _party()
	_check(weak_party.gain_block(1, 6),
		"AC3 precondition: six Block before the standalone Weak 1")
	var weak_case := _force_normal_alternative(moth, weaken, weak_party)
	if not weak_case.is_empty():
		var weak_receipt := CombatEnemyPhase.new().execute_phase(weak_party,
			weak_case.enemies, weak_case.intents, null, true)
		_check(weak_receipt.get("ok") == true
			and weak_receipt.get("events", []).size() == 1
			and weak_receipt["events"][0].get("type") == "debuff",
			"AC3: the standalone Weak 1 is one debuff, never an extra attack")
		_check(weak_party.get_hero(1).get("block") == 6
			and weak_party.get_hero(1).get("hp") == 40
			and weak_party.get_hero(1).get("statuses", {}).get("weak", 0) == 1,
			"AC3: Weak 1 leaves Block and HP alone and adds exactly one Weak")

	# AC4: malformed trait metadata rejects the whole phase before staging.
	for invalid_value in [1, "true", 1.0, null, [], {}]:
		var malformed_record: Dictionary = moth.duplicate(true)
		malformed_record["chew_block_on_attack"] = invalid_value
		var malformed_party := _party()
		_check(malformed_party.gain_block(1, 6),
			"AC4 precondition: six Block on the malformed case")
		var malformed_enemies := CombatEnemies.new([malformed_record])
		_check(malformed_enemies.is_valid()
			and malformed_enemies.get_enemy(1).has("chew_block_on_attack"),
			"AC4 precondition: the malformed trait reaches a valid roster")
		var heroes_before: Array = malformed_party.get_heroes()
		var roster_before: Array = malformed_enemies.get_enemies()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7717
		var state_before: int = rng.state
		_check(CombatEnemyPhase.new().execute_phase(malformed_party, malformed_enemies,
			[_raw_attack_intent(1)], null, true) == {"ok": false, "events": []},
			"AC4: malformed chew metadata rejects the whole phase: " + str(invalid_value))
		_check(malformed_party.get_heroes() == heroes_before
			and malformed_enemies.get_enemies() == roster_before
			and rng.state == state_before,
			"AC4: a rejected malformed bite mutates neither roster and spends no RNG")
	# A malformed trait on a source that never acts still fails the whole batch.
	var mixed_party := _party()
	_check(mixed_party.gain_block(1, 6),
		"AC4 precondition: six Block before the mixed malformed batch")
	var mixed_enemies := CombatEnemies.new([moth.duplicate(true),
		{"id": "ragling-a", "max_hp": 15, "chew_block_on_attack": 1}])
	_check(mixed_enemies.is_valid(),
		"AC4 precondition: the mixed roster really constructs")
	if mixed_enemies.is_valid():
		var mixed_heroes: Array = mixed_party.get_heroes()
		var mixed_roster: Array = mixed_enemies.get_enemies()
		var mixed := CombatEnemyPhase.new().execute_phase(mixed_party, mixed_enemies,
			[_raw_attack_intent(1)], null, true)
		_check(mixed == {"ok": false, "events": []}
			and mixed_party.get_heroes() == mixed_heroes
			and mixed_enemies.get_enemies() == mixed_roster
			and mixed_party.get_hero(1).get("block") == 6,
			"AC4: a malformed second source rolls back the legal earlier bite")

	# AC4: a rejected announced beat publishes nothing either.
	var rejected_party := _party()
	_check(rejected_party.gain_block(1, 6),
		"AC4 precondition: six Block before the rejected announcement")
	var rejected_case := _force_normal_alternative(moth, bite, rejected_party)
	if not rejected_case.is_empty():
		var rejected_heroes: Array = rejected_party.get_heroes()
		var rejected_roster: Array = rejected_case.enemies.get_enemies()
		var bad_intent: Dictionary = rejected_case.intents[0].duplicate(true)
		bad_intent["target_position"] = 0
		_check(CombatEnemyPhase.new().execute_phase(rejected_party, rejected_case.enemies,
			[bad_intent], null, true) == {"ok": false, "events": []}
			and rejected_party.get_heroes() == rejected_heroes
			and rejected_case.enemies.get_enemies() == rejected_roster,
			"AC4: an invalid announced bite rejects the phase without eating Block")

	# AC4: identical seeded binding, announcements and execution replay exactly.
	var replay_one := _force_normal_alternative(moth, bite, _party())
	var replay_two := _force_normal_alternative(moth, bite, _party())
	if not replay_one.is_empty() and not replay_two.is_empty():
		_check(replay_one.intents == replay_two.intents
			and replay_one.rng.state == replay_two.rng.state,
			"AC4: identical seeds announce the identical cloth-eating bite")
		var replay_party_one := _party()
		var replay_party_two := _party()
		_check(replay_party_one.gain_block(1, 6) and replay_party_two.gain_block(1, 6),
			"AC4 precondition: both replay parties really hold six Block")
		var replay_state: int = replay_one.rng.state
		var replay_result_one := CombatEnemyPhase.new().execute_phase(replay_party_one,
			replay_one.enemies, replay_one.intents, null, true)
		var replay_result_two := CombatEnemyPhase.new().execute_phase(replay_party_two,
			replay_two.enemies, replay_two.intents, null, true)
		_check(replay_result_one == replay_result_two
			and replay_party_one.get_heroes() == replay_party_two.get_heroes(),
			"AC4: identical seeded bites reproduce events, Block and HP")
		_check(replay_one.rng.state == replay_state,
			"AC4: the replayed phase consumes no further run RNG")

## AC1: the shipped Scissor Crab keeps its identity and both original weighted
## alternatives, and opts into the already-live Block-eating attack trait with
## exactly one genuine boolean field. The Moth Swarm keeps its own flag and the
## Thimble Beetle stays the unflagged named control.
func _test_scissor_crab_block_snip_catalog() -> void:
	var parsed := _load_parsed()
	var crab := _find(parsed, "scissor_crab")
	_check(not crab.is_empty(), "precondition: the shipped Scissor Crab record loads")
	if crab.is_empty():
		return
	_check(crab.get("chew_block_on_attack") is bool
		and crab.get("chew_block_on_attack") == true,
		"AC1: the parsed Scissor Crab authors chew_block_on_attack as a genuine bool")
	_check(_norm(crab) == _norm(_new_expected()["scissor_crab"]),
		"AC1: the exact Scissor Crab record keeps its authored fields and alternatives")
	var established: Dictionary = _new_expected()["scissor_crab"].duplicate(true)
	established.erase("chew_block_on_attack")
	var without_trait: Dictionary = crab.duplicate(true)
	without_trait.erase("chew_block_on_attack")
	_check(_norm(without_trait) == _norm(established),
		"AC1: the new boolean is the only difference from the established Crab record")
	_check(crab.get("name") == "Scissor Crab" and crab.get("max_hp") == 26
		and crab.get("art_path") == "res://assets/paper/enemies/scissor_crab.png"
		and crab.get("intent", {}).get("target") == "front",
		"AC1: Scissor Crab keeps its name, 26 HP, art path and front target")
	var snip := _authored_alternative(crab, "snip_block", 0)
	var attack := _authored_alternative(crab, "attack", 6)
	_check(not snip.is_empty() and int(snip.get("weight", 0)) == 2,
		"AC1: the authored 0-amount snip keeps weight 2")
	_check(not attack.is_empty() and int(attack.get("weight", 0)) == 3,
		"AC1: the authored 6-damage attack keeps weight 3")
	var moth := _find(parsed, "moth_swarm")
	_check(moth.get("chew_block_on_attack") is bool
		and moth.get("chew_block_on_attack") == true,
		"AC1: the already-authored Moth Swarm keeps its own true trait")
	_check(_norm(moth) == _norm(_trio_expected()["moth_swarm"]),
		"AC1: the Moth Swarm record is untouched by the Crab opt-in")
	var beetle := _find(parsed, "thimble_beetle")
	_check(not beetle.is_empty() and not beetle.has("chew_block_on_attack"),
		"AC1: the Thimble Beetle control authors no chew trait")
	# AC4: the same record is already admitted by ID through the real live Fight
	# catalog and floor-band derivation, with no new wiring or encounter.
	var material := RunAuthoredBattleEntry._floor_band_material(null)
	_check(material.get("ok") == true,
		"AC4: live floor-band material builds from the shipped catalogs")
	if material.get("ok", false):
		var live: Dictionary = material.get("records", {}).get("scissor_crab", {})
		_check(not live.is_empty() and live.get("chew_block_on_attack") == true
			and live.get("max_hp") == 26
			and live.get("intent", {}).get("target") == "front",
			"AC4: the live Fight record keeps the Crab's trait, HP and target policy")
		var band := _band_containing(material.get("pools", {}), "scissor_crab")
		_check(not band.is_empty(),
			"AC4: Scissor Crab is eligible in a derived live floor band")
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([crab])).size() == 1,
		"AC1: the genuine boolean trait keeps the whole catalog valid")
	_check(RunTypedBattleRoster._parse_catalog_text(
		JSON.stringify([without_trait])).size() == 1,
		"AC3: an absent Crab trait stays valid metadata")
	var disabled: Dictionary = crab.duplicate(true)
	disabled["chew_block_on_attack"] = false
	_check(RunTypedBattleRoster._parse_catalog_text(JSON.stringify([disabled])).size() == 1,
		"AC3: an explicit false Crab trait stays valid metadata")
	for invalid_value in ["true", 1, 1.0, null, [], {}]:
		var malformed: Dictionary = crab.duplicate(true)
		malformed["chew_block_on_attack"] = invalid_value
		_check(RunTypedBattleRoster._parse_catalog_text(
			JSON.stringify([malformed])).is_empty(),
			"AC3: malformed Crab chew metadata rejects the whole catalog: "
				+ str(invalid_value))

## AC2: a living opted-in Scissor Crab's genuine 6-damage attack snips all six
## Block off the real recipient before the hit lands, through the real catalog
## record, seeded weighted scheduler and CombatEnemyPhase. AC3: the separate
## snip, an explicit-false/absent flag and a slain source keep the old
## Block-first or inert behavior. AC4: invalid metadata and rejected beats stay
## atomic, and the executed attack spends no extra run RNG.
func _test_scissor_crab_block_snip_phase() -> void:
	var parsed := _load_parsed()
	var crab := _find(parsed, "scissor_crab")
	_check(not crab.is_empty() and crab.get("chew_block_on_attack") == true,
		"precondition: the shipped Scissor Crab really authors the snip trait")
	if crab.is_empty() or crab.get("chew_block_on_attack") != true:
		return
	var attack := _authored_alternative(crab, "attack", 6)
	var snip := _authored_alternative(crab, "snip_block", 0)
	_check(not attack.is_empty() and not snip.is_empty(),
		"precondition: the authored Crab attack and snip alternatives exist")
	if attack.is_empty() or snip.is_empty():
		return

	# AC2: 6 Block and full 40 HP lose the Block first, then the full six.
	var party := _party()
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("hp") == 40 and party.gain_block(1, 6),
		"AC2 precondition: the living front Warden really holds 40 HP and six Block")
	var case := _force_normal_alternative(crab, attack, party)
	_check(not case.is_empty(), "AC2: the shipped Crab attack binds as a real announcement")
	if case.is_empty():
		return
	_check(case.intents.size() == 1 and case.intents[0].get("type") == "attack"
		and int(case.intents[0].get("amount", -1)) == 6
		and case.intents[0].get("target_position") == 1,
		"AC2: the real announcement is the authored six-damage attack on the front hero")
	var committed: int = case.rng.state
	var untouched: Array = [party.get_hero(2), party.get_hero(3)]
	var receipt := CombatEnemyPhase.new().execute_phase(party, case.enemies,
		case.intents, null, true)
	_check(receipt == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true}]},
		"AC2: the snipping attack publishes exactly one ordinary attack event")
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(1).get("hp") == 34,
		"AC2: 6 Block + 40 HP => 0 Block + 34 HP in that one attack")
	_check([party.get_hero(2), party.get_hero(3)] == untouched,
		"AC2: the snipping attack leaves the other two heroes exactly unchanged")
	_check(case.rng.state == committed and case.scheduler.get_intents() == case.intents,
		"AC4: the executed attack spends no extra run RNG and replays its announcement")

	# AC3: the separate authored snip clears Block without any HP damage.
	var snip_party := _party()
	_check(snip_party.gain_block(1, 6),
		"AC3 precondition: six Block before the standalone Crab snip")
	var snip_case := _force_normal_alternative(crab, snip, snip_party)
	if not snip_case.is_empty():
		var snip_receipt := CombatEnemyPhase.new().execute_phase(snip_party,
			snip_case.enemies, snip_case.intents, null, true)
		_check(snip_receipt == {"ok": true, "events": [
			{"type": "snip_block", "enemy_position": 1, "target_position": 1,
				"applied": true}]},
			"AC3: the standalone snip is one ordered Block strip with no extra attack")
		_check(snip_party.get_hero(1).get("block") == 0
			and snip_party.get_hero(1).get("hp") == 40,
			"AC3: the standalone snip zeroes Block and costs no HP")

	# AC3: an explicit false or an absent trait blocks all six damage in full.
	for mode in ["explicit_false", "absent"]:
		var control_record: Dictionary = crab.duplicate(true)
		if mode == "explicit_false":
			control_record["chew_block_on_attack"] = false
		else:
			control_record.erase("chew_block_on_attack")
		var control_party := _party()
		_check(control_party.gain_block(1, 6),
			"AC3 precondition: six Block for the %s Crab control" % mode)
		var control_case := _force_normal_alternative(control_record, attack, control_party)
		if control_case.is_empty():
			continue
		var control_receipt := CombatEnemyPhase.new().execute_phase(control_party,
			control_case.enemies, control_case.intents, null, true)
		_check(control_receipt.get("ok") == true
			and control_receipt.get("events", [{}])[0].get("applied") == true,
			"AC3: the non-opted-in six-damage attack still resolves: " + mode)
		_check(control_party.get_hero(1).get("block") == 0
			and control_party.get_hero(1).get("hp") == 40,
			"AC3: six Block absorb the whole non-opted-in attack: " + mode)
		_check(control_party.get_hero(2).get("hp") == 30
			and control_party.get_hero(3).get("hp") == 26,
			"AC3: the blocked control attack touches no other hero: " + mode)

	# AC3: a slain Crab neither snips nor hits.
	var slain_party := _party()
	_check(slain_party.gain_block(1, 6),
		"AC3 precondition: six Block before the slain Crab's beat")
	var slain_case := _force_normal_alternative(crab, attack, slain_party)
	if not slain_case.is_empty():
		_check(slain_case.enemies.apply_damage(1, 26) and slain_case.enemies.is_slain(1),
			"AC3 precondition: the Crab is genuinely slain before its beat")
		var slain_heroes: Array = slain_party.get_heroes()
		var slain_roster: Array = slain_case.enemies.get_enemies()
		var slain_receipt := CombatEnemyPhase.new().execute_phase(slain_party,
			slain_case.enemies, slain_case.intents, null, true)
		_check(slain_receipt == {"ok": true, "events": [
			{"type": "attack", "enemy_position": 1, "target_position": 1,
				"applied": false}]},
			"AC3: a slain Crab's announced attack resolves as one inert beat")
		_check(slain_party.get_heroes() == slain_heroes
			and slain_case.enemies.get_enemies() == slain_roster,
			"AC3: a slain Crab eats no Block and deals no damage")

	# AC4: malformed trait metadata rejects the whole phase before staging.
	var malformed_record: Dictionary = crab.duplicate(true)
	malformed_record["chew_block_on_attack"] = 1
	var malformed_party := _party()
	_check(malformed_party.gain_block(1, 6),
		"AC4 precondition: six Block on the malformed Crab case")
	var malformed_enemies := CombatEnemies.new([malformed_record])
	_check(malformed_enemies.is_valid()
		and malformed_enemies.get_enemy(1).has("chew_block_on_attack"),
		"AC4 precondition: the malformed Crab trait reaches a valid roster")
	if malformed_enemies.is_valid():
		var malformed_heroes: Array = malformed_party.get_heroes()
		var malformed_roster: Array = malformed_enemies.get_enemies()
		_check(CombatEnemyPhase.new().execute_phase(malformed_party, malformed_enemies,
			[_raw_attack_intent(1)], null, true) == {"ok": false, "events": []},
			"AC4: malformed Crab chew metadata rejects the whole phase")
		_check(malformed_party.get_heroes() == malformed_heroes
			and malformed_enemies.get_enemies() == malformed_roster,
			"AC4: a rejected malformed Crab attack mutates neither roster")

	# AC4: a rejected announced beat publishes nothing and keeps the Block.
	var rejected_party := _party()
	_check(rejected_party.gain_block(1, 6),
		"AC4 precondition: six Block before the rejected Crab announcement")
	var rejected_case := _force_normal_alternative(crab, attack, rejected_party)
	if not rejected_case.is_empty():
		var rejected_heroes: Array = rejected_party.get_heroes()
		var rejected_roster: Array = rejected_case.enemies.get_enemies()
		var bad_intent: Dictionary = rejected_case.intents[0].duplicate(true)
		bad_intent["target_position"] = 0
		_check(CombatEnemyPhase.new().execute_phase(rejected_party, rejected_case.enemies,
			[bad_intent], null, true) == {"ok": false, "events": []}
			and rejected_party.get_heroes() == rejected_heroes
			and rejected_case.enemies.get_enemies() == rejected_roster
			and rejected_party.get_hero(1).get("block") == 6,
			"AC4: an invalid announced Crab attack rejects the phase without eating Block")

## The two look-driven normal enemies of this batch: the bobbin-beaked Bat sucks
## life back through the already-live Drain trait and the Quilt Termite bites
## through the already-live cloth-eating trait. HP, target policy and the full
## 4/1/1 weighted intent are authored in data/enemies/run_enemies.json.
func _bobbin_quilt_expected() -> Dictionary:
	return {
		"bobbin_bat": {"id": "bobbin_bat", "name": "Bobbin Bat", "max_hp": 27,
			"drain": true,
			"art_path": "res://assets/paper/enemies/bobbin_bat.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "attack", "amount": 7, "weight": 4},
				{"type": "debuff", "status": "weak", "amount": 1, "weight": 1},
				{"type": "block", "amount": 4, "weight": 1}]}},
		"quilt_termite": {"id": "quilt_termite", "name": "Quilt Termite", "max_hp": 26,
			"chew_block_on_attack": true,
			"art_path": "res://assets/paper/enemies/quilt_termite.png",
			"intent": {"target": "front", "actions": [
				{"type": "attack", "amount": 6, "weight": 4},
				{"type": "block", "amount": 5, "weight": 1},
				{"type": "debuff", "status": "exposed", "amount": 1, "weight": 1}]}}
	}

## AC1: both records ship exactly once in the live normal catalog with their
## authored identity, target policy, flags and 4/1/1 weighted alternatives, and
## every earlier named normal stays byte-for-byte equivalent. No catalog total,
## ordered ID list or insertion slot is asserted, so parallel appends stay legal.
func _test_bobbin_bat_quilt_termite_catalog() -> void:
	var parsed := _load_parsed()
	var ids: Array[String] = []
	for record in parsed:
		if record is Dictionary:
			ids.append(String(record.get("id", "")))
	# Every earlier named record from the batches this file already knows about.
	var earlier := _old_expected()
	earlier.merge(_new_expected())
	earlier.merge(_trio_expected())
	earlier.merge(_harder_expected())
	earlier.merge(_tough_pair_expected())
	earlier.merge(_crusher_harrier_doll_expected())
	for kept_id in earlier:
		_check(ids.has(String(kept_id)),
			"named earlier normal still present after this append: " + String(kept_id))
		_check(_norm(_find(parsed, String(kept_id))) == _norm(earlier[kept_id]),
			"named earlier normal record is unchanged: " + String(kept_id))
	var expected := _bobbin_quilt_expected()
	for new_id in expected:
		var occurrences := 0
		for present in ids:
			if present == String(new_id):
				occurrences += 1
		_check(occurrences == 1, "new normal is authored exactly once: " + String(new_id))
		var record := _find(parsed, String(new_id))
		_check(not record.is_empty(), "new normal record present: " + String(new_id))
		if record.is_empty():
			continue
		_check(_norm(record) == _norm(expected[new_id]),
			"new normal has its exact authored fields: " + String(new_id))
		_check(record.get("name") == expected[new_id]["name"]
			and record.get("max_hp") is int
			and record.get("max_hp") == expected[new_id]["max_hp"],
			"new normal keeps its authored name and genuine int HP: " + String(new_id))
		_check(record.get("art_path") == expected[new_id]["art_path"]
			and String(record.get("art_path", "")).begins_with(
				"res://assets/paper/enemies/"),
			"new normal keeps its placeholder-swappable art path: " + String(new_id))
		var spec: Variant = record.get("intent")
		_check(spec is Dictionary
			and spec.get("target") == expected[new_id]["intent"]["target"],
			"new normal keeps its authored target policy: " + String(new_id))
		_check(not CombatEnemyIntents._weighted_slot(1, spec).is_empty(),
			"new normal intent validates as a weighted slot: " + String(new_id))
		var actions: Variant = spec.get("actions") if spec is Dictionary else null
		_check(actions is Array and actions.size() == 3,
			"new normal authors exactly its three weighted alternatives: " + String(new_id))
		if not actions is Array:
			continue
		var weights: Array[int] = []
		for raw in actions:
			_check(CombatEnemyIntents.weighted_action(raw) != {},
				"new alternative validates through the weighted scheduler: %s %s"
					% [new_id, str(raw)])
			_check(_alternative_shape_is_exact(raw),
				"new alternative uses supported mechanics and exact fields: %s %s"
					% [new_id, str(raw)])
			var weight := int(raw.get("weight", 0))
			weights.append(weight)
			_check(weight > 0,
				"new alternative keeps a positive authored weight: " + String(new_id))
			if raw is Dictionary and raw.get("type") == "attack":
				var amount := int(raw.get("amount", 0))
				_check(amount >= 5 and amount <= 9,
					"new normal attack stays inside the authored 5-9 band: " + String(new_id))
		_check(weights == [4, 1, 1],
			"new normal keeps its shipped 4/1/1 weights: " + String(new_id))
		_check(RunTypedBattleRoster._parse_catalog_text(
			JSON.stringify([record])).size() == 1,
			"the shipped record survives the strict catalog parser: " + String(new_id))
	# Look-driven identity: each silhouette acts the way it looks.
	var bat := _find(parsed, "bobbin_bat")
	_check(bat.get("drain") is bool and bat.get("drain") == true,
		"Bobbin Bat authors Drain as a genuine boolean")
	_check(_has_alternative(bat, "attack", 7) and _has_alternative(bat, "debuff", 1, "weak")
		and _has_alternative(bat, "block", 4),
		"Bobbin Bat bites for 7, leaves Weak 1 or wraps itself in 4 Block")
	_check(bat.get("intent", {}).get("target") == "lowest_living_hp",
		"Bobbin Bat hunts the lowest-living hero")
	var termite := _find(parsed, "quilt_termite")
	_check(termite.get("chew_block_on_attack") is bool
		and termite.get("chew_block_on_attack") == true,
		"Quilt Termite authors the cloth-eating bite as a genuine boolean")
	_check(_has_alternative(termite, "attack", 6) and _has_alternative(termite, "block", 5)
		and _has_alternative(termite, "debuff", 1, "exposed"),
		"Quilt Termite bites for 6, boards up 5 Block or marks Exposed 1")
	_check(termite.get("intent", {}).get("target") == "front",
		"Quilt Termite bites the front hero")
	# Named controls: the two new flags stay per-record, not catalog-wide.
	var beetle := _find(parsed, "thimble_beetle")
	_check(not beetle.is_empty() and not beetle.has("drain"),
		"the named Thimble Beetle control authors no Drain")
	var ram := _find(parsed, "spindle_ram")
	_check(not ram.is_empty() and not ram.has("chew_block_on_attack"),
		"the named Spindle Ram control authors no cloth-eating bite")

## Up to three real sources in their catalog order, bound to one genuine
## scheduler so a two-enemy group binds without borrowing an unrelated actor.
func _bind_records(seed_value: int, selected: Array) -> Dictionary:
	var enemies := CombatEnemies.new(selected.duplicate(true))
	var party := _party()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var definitions: Array = []
	for index in range(selected.size()):
		definitions.append(_enemy(index + 1, [{"type": "block", "amount": 1}]))
	var scheduler := CombatEnemyIntents.new(definitions)
	var ok := scheduler.bind_battle(enemies, party, rng)
	return {"ok": ok, "enemies": enemies, "party": party, "rng": rng, "scheduler": scheduler}

## AC2: two independent real weighted schedulers over the three living heroes
## announce only authored alternatives, replay on the same seed, advance a turn
## identically and never consume RNG on a read. Each authored attack is then
## forced from the parsed record and executed by the real CombatEnemyPhase.
func _test_bobbin_bat_quilt_termite_seeded_announcements() -> void:
	var parsed := _load_parsed()
	var selected: Array = []
	for id in ["bobbin_bat", "quilt_termite"]:
		var record := _find(parsed, id)
		_check(not record.is_empty(), "authentic new normal source present: " + id)
		selected.append(record)
	_check(selected.size() == 2 and not selected.has({}),
		"precondition: both authentic new normal records loaded")
	if selected.size() != 2 or selected.has({}):
		return
	var party := _party()
	_check(party.is_valid() and party.get_heroes().size() == CombatParty.PARTY_SIZE,
		"precondition: a valid three-hero CombatParty")
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		_check(party.get_hero(position).get("hp", 0) > 0,
			"precondition: hero slot %d is living" % position)
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		"precondition: the back hero is the unique lowest-living target")
	_check(CombatEnemyIntents.priority_target(party, "lowest_living_hp") == 3
		and CombatEnemyIntents.priority_target(party, "front") == 1,
		"precondition: the two authored policies name different heroes")
	var snapshot: Array = selected.duplicate(true)
	var first := _bind_records(61027, selected)
	var second := _bind_records(61027, selected)
	_check(first.get("ok") == true and second.get("ok") == true,
		"both new normals bind on identical seeds")
	_check(first.scheduler.is_bound() and second.scheduler.is_bound(),
		"both seeded bindings report the weighted mode")
	var first_intents: Array = first.scheduler.get_intents()
	var second_intents: Array = second.scheduler.get_intents()
	_check(first_intents.size() == 2, "one announcement per new normal")
	_check(first_intents == second_intents,
		"same-seed first-turn announcements replay identically")
	_check(first.rng.state == second.rng.state,
		"same-seed bindings leave matching RNG state")
	var state_before: int = first.rng.state
	_check(first.scheduler.get_intents() == first_intents and first.rng.state == state_before,
		"reading bound announcements neither changes them nor consumes RNG")
	for index in range(first_intents.size()):
		var announced: Dictionary = first_intents[index]
		var source: Dictionary = selected[index]
		var enemy_id := String(source.get("id", ""))
		_check(announced.get("enemy_position") == index + 1,
			"announcement keeps its source slot: " + enemy_id)
		_check(_is_authored_alternative(source, announced),
			"announcement is one of the authored alternatives: " + enemy_id)
		_check(String(announced.get("type", "")) in ["attack", "debuff", "block"],
			"announcement uses only an existing authored action type: " + enemy_id)
		if announced.get("type") in ["attack", "debuff"]:
			var expected_target := 1 \
				if String(source.get("intent", {}).get("target", "")) == "front" else 3
			_check(announced.get("target_position") == expected_target,
				"announcement applies the authored target policy: " + enemy_id)
	_check(first.scheduler.advance_turn(), "the first seeded schedule advances a turn")
	_check(second.scheduler.advance_turn(), "the second seeded schedule advances a turn")
	_check(first.scheduler.get_intents() == second.scheduler.get_intents()
		and first.rng.state == second.rng.state,
		"successive announced turns replay identically on equal seeds")
	_check(selected == snapshot, "weighted binding never mutates the parsed source records")
	# Force every authored alternative from the genuine record, so no guessed
	# seed can hide one and production weights stay 4/1/1.
	var forced := [
		{"id": "bobbin_bat", "action": {"type": "attack", "amount": 7, "weight": 1}},
		{"id": "bobbin_bat",
			"action": {"type": "debuff", "status": "weak", "amount": 1, "weight": 1}},
		{"id": "bobbin_bat", "action": {"type": "block", "amount": 4, "weight": 1}},
		{"id": "quilt_termite", "action": {"type": "attack", "amount": 6, "weight": 1}},
		{"id": "quilt_termite", "action": {"type": "block", "amount": 5, "weight": 1}},
		{"id": "quilt_termite",
			"action": {"type": "debuff", "status": "exposed", "amount": 1, "weight": 1}}]
	for case in forced:
		var record := _find(parsed, String(case.id))
		_check(not record.is_empty(), "forced alternative source present: " + String(case.id))
		if record.is_empty():
			continue
		var policy := String(record.get("intent", {}).get("target", ""))
		var expected_target := 1 if policy == "front" else 3
		var forced_record: Dictionary = record.duplicate(true)
		forced_record["intent"] = {"target": policy, "actions": [case.action]}
		var forced_enemies := CombatEnemies.new([forced_record])
		var forced_rng := RandomNumberGenerator.new()
		forced_rng.seed = 61027
		var forced_scheduler := CombatEnemyIntents.new(
			[_enemy(1, [{"type": "block", "amount": 1}])])
		var did_bind := forced_enemies.is_valid() \
			and forced_scheduler.bind_battle(forced_enemies, party, forced_rng)
		_check(did_bind, "forced alternative binds: %s %s" % [case.id, str(case.action)])
		if not did_bind:
			continue
		var announced: Dictionary = forced_scheduler.get_intents()[0]
		_check(announced.get("type") == case.action.type
			and int(announced.get("amount", -1)) == int(case.action.amount),
			"forced alternative announces its authored effect: %s %s"
				% [case.id, str(case.action)])
		if case.action.has("status"):
			_check(announced.get("status") == case.action.status,
				"forced debuff keeps its authored status: " + String(case.action.status))
		if announced.get("type") in ["attack", "debuff"]:
			_check(announced.get("target_position") == expected_target,
				"forced alternative honours the authored target policy: " + String(case.id))
		# Every forced beat resolves through the genuine phase on fresh actors.
		var live_party := _party()
		var receipt := CombatEnemyPhase.new().execute_phase(live_party, forced_enemies,
			forced_scheduler.get_intents(), null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1
			and receipt["events"][0].get("applied") == true,
			"forced alternative executes through the real CombatEnemyPhase: %s %s"
				% [case.id, str(case.action)])
		if announced.get("type") == "attack":
			_check(live_party.get_hero(expected_target).get("hp")
				== _party().get_hero(expected_target).get("hp") - int(case.action.amount),
				"the real phase applies the authored attack damage: " + String(case.id))
		elif announced.get("type") == "block":
			_check(forced_enemies.get_enemy(1).get("block") == int(case.action.amount),
				"the real phase grants the authored Block: " + String(case.id))
		elif announced.get("type") == "debuff":
			_check(live_party.get_hero(expected_target).get("statuses", {}).get(
				String(case.action.status), 0) == int(case.action.amount),
				"the real phase applies the authored status: " + String(case.id))

## AC3: the shipped Bat's real 7-damage bite heals exactly the hero HP it removes,
## capped by its own missing HP and never by Block-absorbed damage. Non-attack
## turns and a slain Bat heal nothing.
func _test_bobbin_bat_drain_phase() -> void:
	var parsed := _load_parsed()
	var bat := _find(parsed, "bobbin_bat")
	_check(not bat.is_empty() and bat.get("drain") is bool and bat.get("drain") == true,
		"precondition: the shipped Bobbin Bat really authors Drain")
	if bat.is_empty():
		return
	var bite := _authored_alternative(bat, "attack", 7)
	var weaken := _authored_alternative(bat, "debuff", 1)
	var wing := _authored_alternative(bat, "block", 4)
	_check(not bite.is_empty() and not weaken.is_empty() and not wing.is_empty(),
		"precondition: the shipped bite, Weak 1 and 4 Block alternatives exist")
	if bite.is_empty() or weaken.is_empty() or wing.is_empty():
		return
	# AC3: a wounded 8/27 Bat restores exactly the 7 HP its real bite removes.
	var party := _party()
	var case := _force_normal_alternative(bat, bite, party)
	_check(not case.is_empty(), "AC3: the shipped bite binds as a real announcement")
	if case.is_empty():
		return
	_check(case.enemies.apply_damage(1, 19)
		and case.enemies.get_enemy(1).get("hp") == 8,
		"AC3 precondition: the Bat really stands at 8 of its authored 27 HP")
	_check(case.intents.size() == 1 and case.intents[0].get("type") == "attack"
		and int(case.intents[0].get("amount", -1)) == 7
		and case.intents[0].get("target_position") == 3,
		"AC3: the real announcement is the authored 7-damage bite on Tinker")
	var receipt := CombatEnemyPhase.new().execute_phase(party, case.enemies,
		case.intents, null, true)
	_check(receipt == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true}]},
		"AC3: the draining bite keeps the ordinary attack event shape")
	_check(party.get_hero(3).get("hp") == 19 and party.get_hero(3).get("block") == 0,
		"AC3: the unblocked bite removes exactly seven Tinker HP")
	_check(case.enemies.get_enemy(1).get("hp") == 15,
		"AC3: Drain heals exactly the seven HP the bite really removed")
	_check(case.enemies.get_enemy(1).get("drain") == true
		and case.enemies.get_enemy(1).get("max_hp") == 27,
		"AC3: the heal preserves the Bat's Drain flag and its authored cap")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30,
		"AC3: the other two heroes keep their HP")
	# AC3: a Bat missing only 2 HP heals only those 2, never the full seven.
	var capped_party := _party()
	var capped := _force_normal_alternative(bat, bite, capped_party)
	if not capped.is_empty():
		_check(capped.enemies.apply_damage(1, 2)
			and capped.enemies.get_enemy(1).get("hp") == 25,
			"AC3 precondition: the Bat is only two HP below its cap")
		var capped_receipt := CombatEnemyPhase.new().execute_phase(capped_party,
			capped.enemies, capped.intents, null, true)
		_check(capped_receipt.get("ok") == true
			and capped_party.get_hero(3).get("hp") == 19
			and capped.enemies.get_enemy(1).get("hp") == 27,
			"AC3: Drain is clamped to the two missing HP and never overheals")
	# AC3: seven Block absorb the whole bite, so there is no hero HP loss to drain.
	var blocked_party := _party()
	_check(blocked_party.gain_block(3, 7),
		"AC3 precondition: Tinker really holds seven Block")
	var blocked := _force_normal_alternative(bat, bite, blocked_party)
	if not blocked.is_empty():
		_check(blocked.enemies.apply_damage(1, 19)
			and blocked.enemies.get_enemy(1).get("hp") == 8,
			"AC3 precondition: the blocked case starts at 8 of 27 HP")
		var blocked_receipt := CombatEnemyPhase.new().execute_phase(blocked_party,
			blocked.enemies, blocked.intents, null, true)
		_check(blocked_receipt.get("ok") == true
			and blocked_receipt.get("events", [{}])[0].get("applied") == true,
			"AC3: the fully blocked bite still resolves as one applied attack")
		_check(blocked_party.get_hero(3).get("hp") == 26
			and blocked_party.get_hero(3).get("block") == 0
			and blocked.enemies.get_enemy(1).get("hp") == 8,
			"AC3: seven Block absorb all seven damage and Drain heals nothing")
	# AC3: only the HP that really got through partial Block drains.
	var partial_party := _party()
	_check(partial_party.gain_block(3, 3),
		"AC3 precondition: Tinker really holds three Block")
	var partial := _force_normal_alternative(bat, bite, partial_party)
	if not partial.is_empty():
		_check(partial.enemies.apply_damage(1, 19)
			and partial.enemies.get_enemy(1).get("hp") == 8,
			"AC3 precondition: the partially blocked case starts at 8 of 27 HP")
		var partial_receipt := CombatEnemyPhase.new().execute_phase(partial_party,
			partial.enemies, partial.intents, null, true)
		_check(partial_receipt.get("ok") == true
			and partial_party.get_hero(3).get("hp") == 22
			and partial_party.get_hero(3).get("block") == 0,
			"AC3: three Block absorb three and four HP really reach Tinker")
		_check(partial.enemies.get_enemy(1).get("hp") == 12,
			"AC3: a partial Block drains exactly the four HP that got through")
	# AC3: the authored non-attack Weak turn heals nothing.
	var weak_party := _party()
	var weak := _force_normal_alternative(bat, weaken, weak_party)
	if not weak.is_empty():
		_check(weak.enemies.apply_damage(1, 19)
			and weak.enemies.get_enemy(1).get("hp") == 8,
			"AC3 precondition: the Weak case starts at 8 of 27 HP")
		_check(weak.intents.size() == 1 and weak.intents[0].get("type") == "debuff"
			and weak.intents[0].get("status") == "weak"
			and int(weak.intents[0].get("amount", -1)) == 1
			and weak.intents[0].get("target_position") == 3,
			"AC3: the second alternative announces Weak 1 on Tinker")
		var weak_receipt := CombatEnemyPhase.new().execute_phase(weak_party,
			weak.enemies, weak.intents, null, true)
		_check(weak_receipt.get("ok") == true
			and weak_party.get_hero(3).get("hp") == 26
			and weak_party.get_hero(3).get("statuses", {}).get("weak", 0) == 1
			and weak.enemies.get_enemy(1).get("hp") == 8,
			"AC3: a non-attack Weak turn damages nobody and heals the Bat nothing")
	# AC3: the authored Block turn heals nothing either.
	var wing_party := _party()
	var wing_case := _force_normal_alternative(bat, wing, wing_party)
	if not wing_case.is_empty():
		_check(wing_case.enemies.apply_damage(1, 19)
			and wing_case.enemies.get_enemy(1).get("hp") == 8,
			"AC3 precondition: the Block case starts at 8 of 27 HP")
		var wing_receipt := CombatEnemyPhase.new().execute_phase(wing_party,
			wing_case.enemies, wing_case.intents, null, true)
		_check(wing_receipt.get("ok") == true
			and wing_case.enemies.get_enemy(1).get("block") == 4
			and wing_case.enemies.get_enemy(1).get("hp") == 8
			and wing_party.get_heroes() == _party().get_heroes(),
			"AC3: a self-Block turn grants 4 Block, hits nobody and heals nothing")
	# AC3: a slain Bat never drains, never revives and never damages a hero.
	var slain_party := _party()
	var slain := _force_normal_alternative(bat, bite, slain_party)
	if not slain.is_empty():
		_check(slain.enemies.apply_damage(1, 27) and slain.enemies.is_slain(1),
			"AC3 precondition: the draining Bat is genuinely slain before its beat")
		var slain_heroes: Array = slain_party.get_heroes()
		var slain_roster: Array = slain.enemies.get_enemies()
		var slain_receipt := CombatEnemyPhase.new().execute_phase(slain_party,
			slain.enemies, slain.intents, null, true)
		_check(slain_receipt == {"ok": true, "events": [
			{"type": "attack", "enemy_position": 1, "target_position": 3,
				"applied": false}]},
			"AC3: a slain Bat's announced bite resolves as one inert beat")
		_check(slain_party.get_heroes() == slain_heroes
			and slain.enemies.get_enemies() == slain_roster
			and slain.enemies.get_enemy(1).get("hp") == 0,
			"AC3: a slain Bat deals no damage and is never healed back to life")

## AC3: the shipped Termite's real 6-damage bite eats ALL the front hero's Block
## before the hit, so the full six reaches HP. Its standalone Block and Exposed
## alternatives never chew, and a slain Termite neither chews nor bites.
func _test_quilt_termite_chew_phase() -> void:
	var parsed := _load_parsed()
	var termite := _find(parsed, "quilt_termite")
	_check(not termite.is_empty() and termite.get("chew_block_on_attack") is bool
		and termite.get("chew_block_on_attack") == true,
		"precondition: the shipped Quilt Termite really authors the cloth-eating bite")
	if termite.is_empty() or termite.get("chew_block_on_attack") != true:
		return
	var bite := _authored_alternative(termite, "attack", 6)
	var shell := _authored_alternative(termite, "block", 5)
	var mark := _authored_alternative(termite, "debuff", 1)
	_check(not bite.is_empty() and not shell.is_empty() and not mark.is_empty(),
		"precondition: the authored Termite alternatives exist")
	if bite.is_empty() or shell.is_empty() or mark.is_empty():
		return
	# AC3: six Block and full 40 HP lose the Block, then the full six HP.
	var party := _party()
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("hp") == 40 and party.gain_block(1, 6),
		"AC3 precondition: the living front Warden really holds 40 HP and six Block")
	var case := _force_normal_alternative(termite, bite, party)
	_check(not case.is_empty(), "AC3: the shipped bite binds as a real announcement")
	if case.is_empty():
		return
	_check(case.intents.size() == 1 and case.intents[0].get("type") == "attack"
		and int(case.intents[0].get("amount", -1)) == 6
		and case.intents[0].get("target_position") == 1,
		"AC3: the real announcement is the authored six-damage bite on the front hero")
	var committed: int = case.rng.state
	var untouched: Array = [party.get_hero(2), party.get_hero(3)]
	var receipt := CombatEnemyPhase.new().execute_phase(party, case.enemies,
		case.intents, null, true)
	_check(receipt == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true}]},
		"AC3: the cloth-eating bite publishes exactly one ordinary attack event")
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(1).get("hp") == 34,
		"AC3: six Block are eaten first and the full six still reach Warden HP")
	_check([party.get_hero(2), party.get_hero(3)] == untouched,
		"AC3: the cloth-eating bite leaves the other two heroes exactly unchanged")
	_check(case.rng.state == committed and case.scheduler.get_intents() == case.intents,
		"AC3: the executed bite spends no extra run RNG and replays its announcement")
	# AC3: more Block than damage is still eaten whole, not merely offset.
	var heavy_party := _party()
	_check(heavy_party.gain_block(1, 9),
		"AC3 precondition: the front hero really holds nine Block")
	var heavy := _force_normal_alternative(termite, bite, heavy_party)
	if not heavy.is_empty():
		var heavy_receipt := CombatEnemyPhase.new().execute_phase(heavy_party,
			heavy.enemies, heavy.intents, null, true)
		_check(heavy_receipt.get("ok") == true
			and heavy_party.get_hero(1).get("block") == 0
			and heavy_party.get_hero(1).get("hp") == 34,
			"AC3: all nine Block are eaten and the full six still reach HP")
	# AC3: the authored Block alternative never chews the hero's Block.
	var shell_party := _party()
	_check(shell_party.gain_block(1, 6),
		"AC3 precondition: six Block before the standalone Block turn")
	var shell_case := _force_normal_alternative(termite, shell, shell_party)
	if not shell_case.is_empty():
		var shell_receipt := CombatEnemyPhase.new().execute_phase(shell_party,
			shell_case.enemies, shell_case.intents, null, true)
		_check(shell_receipt.get("ok") == true and shell_receipt.get("events", []).size() == 1
			and shell_receipt["events"][0].get("type") == "block"
			and shell_receipt["events"][0].get("applied") == true,
			"AC3: the standalone Block turn is one self-Block, never an attack")
		_check(shell_case.enemies.get_enemy(1).get("block") == 5
			and shell_party.get_hero(1).get("block") == 6
			and shell_party.get_hero(1).get("hp") == 40,
			"AC3: the Block turn grants 5 enemy Block and keeps the hero's six")
	# AC3: the authored Exposed alternative never chews either.
	var mark_party := _party()
	_check(mark_party.gain_block(1, 6),
		"AC3 precondition: six Block before the standalone Exposed turn")
	var mark_case := _force_normal_alternative(termite, mark, mark_party)
	if not mark_case.is_empty():
		_check(mark_case.intents.size() == 1 and mark_case.intents[0].get("type") == "debuff"
			and mark_case.intents[0].get("status") == "exposed"
			and int(mark_case.intents[0].get("amount", -1)) == 1
			and mark_case.intents[0].get("target_position") == 1,
			"AC3: the Exposed alternative announces Exposed 1 on the front hero")
		var mark_receipt := CombatEnemyPhase.new().execute_phase(mark_party,
			mark_case.enemies, mark_case.intents, null, true)
		_check(mark_receipt.get("ok") == true
			and mark_receipt.get("events", [{}])[0].get("applied") == true,
			"AC3: the Exposed turn resolves through the real phase")
		_check(mark_party.get_hero(1).get("statuses", {}).get("exposed", 0) == 1
			and mark_party.get_hero(1).get("block") == 6
			and mark_party.get_hero(1).get("hp") == 40,
			"AC3: an Exposed turn costs no Block and no HP")
	# AC3: a slain Termite with a pending attack neither chews nor bites.
	var slain_party := _party()
	_check(slain_party.gain_block(1, 6),
		"AC3 precondition: six Block before the slain Termite's beat")
	var slain := _force_normal_alternative(termite, bite, slain_party)
	if not slain.is_empty():
		_check(slain.enemies.apply_damage(1, 26) and slain.enemies.is_slain(1),
			"AC3 precondition: the Termite is genuinely slain before its beat")
		var slain_heroes: Array = slain_party.get_heroes()
		var slain_roster: Array = slain.enemies.get_enemies()
		var slain_receipt := CombatEnemyPhase.new().execute_phase(slain_party,
			slain.enemies, slain.intents, null, true)
		_check(slain_receipt == {"ok": true, "events": [
			{"type": "attack", "enemy_position": 1, "target_position": 1,
				"applied": false}]},
			"AC3: a slain Termite's announced bite resolves as one inert beat")
		_check(slain_party.get_heroes() == slain_heroes
			and slain.enemies.get_enemies() == slain_roster
			and slain_party.get_hero(1).get("block") == 6,
			"AC3: a slain Termite eats no Block and deals no damage")

## AC4: both appended records reach the live ordinary-Fight catalog exactly once
## through unmodified floor-band admission, inside a band the documented 1-4,
## 5-8 and 9-11 rule owns, with no special-case reordering of the HP sort.
func _test_bobbin_bat_quilt_termite_live_bands() -> void:
	var material := RunAuthoredBattleEntry._floor_band_material(null)
	_check(material.get("ok") == true,
		"AC4: live floor-band material builds from the shipped catalogs")
	if not material.get("ok", false):
		return
	var records: Dictionary = material.get("records", {})
	var pools: Dictionary = material.get("pools", {})
	_check(pools.size() == RunV3FloorBandRoster.BAND_KEYS.size(),
		"AC4: live material carries exactly the three documented floor bands")
	# The documented ordering is the only rule: HP ascending, ID as the tiebreak.
	for band in RunV3FloorBandRoster.BAND_KEYS:
		var candidates: Array = pools.get(band, [])
		_check(candidates.size() >= RunV3FloorBandRoster.MIN_IDS_PER_BAND,
			"AC4: band keeps the authored minimum candidate count: " + String(band))
		var ordered := true
		var distinct := {}
		for index in range(candidates.size()):
			var enemy_id: String = candidates[index]
			distinct[enemy_id] = true
			_check(records.has(enemy_id),
				"AC4: every band candidate has a live record: " + enemy_id)
			if not records.has(enemy_id) or index == 0 \
					or not records.has(String(candidates[index - 1])):
				continue
			var previous: Dictionary = records[candidates[index - 1]]
			var current: Dictionary = records[enemy_id]
			if int(previous.get("max_hp", 0)) > int(current.get("max_hp", 0)):
				ordered = false
			elif int(previous.get("max_hp", 0)) == int(current.get("max_hp", 0)) \
					and String(previous.get("id", "")) > String(current.get("id", "")):
				ordered = false
		_check(ordered, "AC4: band keeps the authored HP-then-ID order: " + String(band))
		_check(distinct.size() == candidates.size(),
			"AC4: band candidates are distinct: " + String(band))
	for index in range(1, RunV3FloorBandRoster.BAND_KEYS.size()):
		var earlier_band: String = RunV3FloorBandRoster.BAND_KEYS[index - 1]
		var later_band: String = RunV3FloorBandRoster.BAND_KEYS[index]
		var earlier_max := 0
		for enemy_id in pools.get(earlier_band, []):
			earlier_max = maxi(earlier_max, int(records.get(enemy_id, {}).get("max_hp", 0)))
		var later_min := 0
		var seeded := false
		for enemy_id in pools.get(later_band, []):
			var hp := int(records.get(enemy_id, {}).get("max_hp", 0))
			later_min = hp if not seeded else mini(later_min, hp)
			seeded = true
		_check(seeded and earlier_max <= later_min,
			"AC4: floor bands stay contiguous in authored HP order: %s -> %s"
				% [earlier_band, later_band])
	var expected := _bobbin_quilt_expected()
	for id in expected:
		var enemy_id := String(id)
		_check(records.has(enemy_id), "AC4: live Fight records contain " + enemy_id)
		if not records.has(enemy_id):
			continue
		_check(_norm(records[enemy_id]) == _norm(expected[id]),
			"AC4: the live Fight record keeps every authored field: " + enemy_id)
		var bands: Array[String] = []
		for band in RunV3FloorBandRoster.BAND_KEYS:
			if pools.get(band, []).has(enemy_id):
				bands.append(band)
		_check(bands.size() == 1,
			"AC4: the new normal is eligible exactly once across the bands: " + enemy_id)
		if bands.size() != 1:
			continue
		var band: String = bands[0]
		var floor_number := _floor_in_band(band)
		_check(floor_number > 0 and RunV3FloorBandRoster._band_for_floor(floor_number) == band,
			"AC4: the owning band keeps its documented 1-4/5-8/9-11 floors: " + enemy_id)
		if floor_number == 0:
			continue
		# A deterministic sampled group really mounts the new actor in its band.
		var witness := 0
		for value in range(1, 401):
			var rng := RandomNumberGenerator.new()
			rng.seed = value
			var picked := RunV3FloorBandRoster.new().pick(floor_number, 2, rng,
				material["pools"])
			if picked.get("ok", false) and picked.get("enemy_ids", []).has(enemy_id):
				witness = value
				break
		_check(witness > 0, "AC4: a deterministic sampled group contains " + enemy_id)
		if witness == 0:
			continue
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = witness
		var first := RunV3FloorBandRoster.new().pick(floor_number, 2, replay_rng,
			material["pools"])
		var oracle_rng := RandomNumberGenerator.new()
		oracle_rng.seed = witness
		var oracle := _sampled_band_group(pools, band, 2, oracle_rng)
		_check(first.get("ok") == true and first.get("band") == band
			and first.get("enemy_ids", []) == oracle and replay_rng.state == oracle_rng.state,
			"AC4: the sampled group matches the independent band oracle: " + enemy_id)
		_check(oracle.has(enemy_id) and oracle.size() == 2,
			"AC4: the sampled group really selects " + enemy_id)
		# The selected authentic records build a real, executable roster.
		var ordered_records: Array = []
		for sampled_id in oracle:
			ordered_records.append(records[sampled_id].duplicate(true))
		var roster := CombatEnemies.new(ordered_records)
		var index := oracle.find(enemy_id)
		_check(roster.is_valid() and roster.get_enemies().size() == 2 and index >= 0,
			"AC4: the sampled band group builds a real CombatEnemies roster: " + enemy_id)
		if not roster.is_valid() or index < 0:
			continue
		var selected := roster.get_enemy(index + 1)
		_check(selected.get("id") == enemy_id
			and selected.get("hp") == int(expected[id]["max_hp"])
			and selected.get("block") == 0,
			"AC4: the selected slot keeps its authored full HP and zero Block: " + enemy_id)

