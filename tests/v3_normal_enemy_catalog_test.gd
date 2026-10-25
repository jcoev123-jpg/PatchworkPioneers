extends SceneTree

const PATH := "res://data/enemies/run_enemies.json"

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_catalog_records_and_parsing()
	_test_three_slot_roster_and_weighted_slots()
	_test_fixed_seed_binding_and_alternatives()
	_test_trio_catalog_records()
	_test_hedgehog_thorns_through_typed_roster()
	_test_trio_seeded_announcements()
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
			"art_path": "res://assets/paper/enemies/moth_swarm.png",
			"intent": {"target": "front", "actions": [
				{"type": "snip_block", "amount": 0, "weight": 2},
				{"type": "attack", "amount": 7, "weight": 3},
				{"type": "debuff", "status": "weak", "amount": 1, "weight": 1}]}},
		"needle_wasp": {"id": "needle_wasp", "name": "Needle Wasp", "max_hp": 22,
			"art_path": "res://assets/paper/enemies/needle_wasp.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
				{"type": "attack", "amount": 8, "weight": 3}]}}
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
