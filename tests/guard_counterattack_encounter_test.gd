extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_guard_counterattack_pattern()
	_test_existing_starter_encounter_unchanged()
	_test_deterministic_replay_and_no_rng_consumption()
	_test_slain_guard_skips_attack()
	if failures.is_empty():
		print("guard_counterattack_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("guard_counterattack_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return null
	var text = file.get_as_text()
	file.close()
	var parser = JSON.new()
	var err = parser.parse(text)
	_check(err == OK, "parses " + path + " without error")
	return parser.data


func _load_party_definitions() -> Array:
	var data = _load_json("res://data/heroes/starter_party.json")
	if not data is Array:
		return []
	for definition in data:
		if not definition is Dictionary:
			return []
		var max_hp = definition.get("max_hp")
		if not (max_hp is float or max_hp is int):
			return []
		if not is_finite(float(max_hp)) or max_hp <= 0:
			return []
		if floor(float(max_hp)) != float(max_hp):
			return []
		definition["max_hp"] = int(max_hp)
	return data


func _load_enemy_definitions() -> Array:
	var data = _load_json("res://data/enemies/starter_enemies.json")
	if not data is Array:
		return []
	for definition in data:
		if not definition is Dictionary:
			return []
		var max_hp = definition.get("max_hp")
		if not (max_hp is float or max_hp is int):
			return []
		if not is_finite(float(max_hp)) or max_hp <= 0:
			return []
		if floor(float(max_hp)) != float(max_hp):
			return []
		definition["max_hp"] = int(max_hp)
	return data


func _load_encounter_definitions(path: String) -> Array:
	var data = _load_json(path)
	if not data is Array:
		return []
	# Convert float numbers to ints in the pattern actions and enemy_position
	for definition in data:
		if not definition is Dictionary:
			continue
		# Convert enemy_position
		if definition.has("enemy_position"):
			var val = definition["enemy_position"]
			if val is float:
				definition["enemy_position"] = int(val)
		var pattern = definition.get("pattern")
		if pattern is Array:
			for action in pattern:
				if action is Dictionary:
					for key in ["amount", "target_position"]:
						if action.has(key):
							var val = action[key]
							if val is float:
								action[key] = int(val)
	return data


func _test_guard_counterattack_pattern() -> void:
	# Load actual data files using proper loaders that convert JSON floats to ints
	var party_defs = _load_party_definitions()
	var enemy_defs = _load_enemy_definitions()
	var guard_counterattack_defs = _load_encounter_definitions("res://data/encounters/guard_counterattack.json")
	
	_check(party_defs is Array and party_defs.size() == 3, "starter party has three heroes")
	_check(enemy_defs is Array and enemy_defs.size() == 2, "starter enemies has two enemies")
	_check(guard_counterattack_defs is Array and guard_counterattack_defs.size() == 2, "guard_counterattack has two enemy slots")
	
	# Verify enemy IDs and HP
	_check(enemy_defs[0]["id"] == "ragling" and enemy_defs[0]["name"] == "Ragling" and enemy_defs[0]["max_hp"] == 12,
		"enemy slot 1 is Ragling with 12 HP")
	_check(enemy_defs[1]["id"] == "ragling_guard" and enemy_defs[1]["name"] == "Guard Ragling" and enemy_defs[1]["max_hp"] == 12,
		"enemy slot 2 is Guard Ragling with 12 HP")
	
	# Verify guard_counterattack patterns exactly match specification
	var slot1 = guard_counterattack_defs[0]
	var slot2 = guard_counterattack_defs[1]
	_check(slot1["enemy_position"] == 1, "slot 1 enemy_position is 1")
	_check(slot2["enemy_position"] == 2, "slot 2 enemy_position is 2")
	
	# Slot 1 (Ragling): [Block 1, Attack 1 at hero 1]
	_check(slot1["pattern"].size() == 2, "Ragling has two-pattern cycle")
	_check(slot1["pattern"][0] == {"type": "block", "amount": 1}, "Ragling turn 0: Block 1")
	_check(slot1["pattern"][1] == {"type": "attack", "amount": 1, "target_position": 1}, "Ragling turn 1: Attack 1 at hero 1")
	
	# Slot 2 (Guard Ragling): [Attack 1 at hero 3, Block 1]
	_check(slot2["pattern"].size() == 2, "Guard has two-pattern cycle")
	_check(slot2["pattern"][0] == {"type": "attack", "amount": 1, "target_position": 3}, "Guard turn 0: Attack 1 at hero 3 (Tinker)")
	_check(slot2["pattern"][1] == {"type": "block", "amount": 1}, "Guard turn 1: Block 1")
	
	# Instantiate real combat classes
	var party = CombatParty.new(party_defs)
	var enemies = CombatEnemies.new(enemy_defs)
	var intents = CombatEnemyIntents.new(guard_counterattack_defs)
	var phase = CombatEnemyPhase.new()
	var starting_block = CombatStartingBlock.new(party)
	
	_check(party.is_valid(), "CombatParty is valid")
	_check(enemies.is_valid(), "CombatEnemies is valid")
	_check(intents.is_valid(), "CombatEnemyIntents is valid")
	
	# Verify initial hero HP
	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["max_hp"] == 40, "Warden starts at 40 HP")
	_check(party.get_hero(2)["hp"] == 30 and party.get_hero(2)["max_hp"] == 30, "Seamstress starts at 30 HP")
	_check(party.get_hero(3)["hp"] == 26 and party.get_hero(3)["max_hp"] == 26, "Tinker starts at 26 HP")
	
	# Verify initial enemy HP
	_check(enemies.get_enemy(1)["hp"] == 12, "Ragling starts at 12 HP")
	_check(enemies.get_enemy(2)["hp"] == 12, "Guard Ragling starts at 12 HP")
	
	# Apply Warden's starting Block (one-time +6)
	_check(starting_block.apply(), "Warden receives starting Block 6")
	_check(party.get_hero(1)["block"] == 6, "Warden has 6 Block after starting block")
	
	# Turn 0: Get intents and execute phase
	var turn0_intents = intents.get_intents()
	_check(turn0_intents.size() == 2, "Turn 0 announces two intents")
	# Use safe element access via loop since typed array direct indexing can be finicky
	var turn0_intent_0: Dictionary = {}
	var turn0_intent_1: Dictionary = {}
	for i in range(turn0_intents.size()):
		if i == 0:
			turn0_intent_0 = turn0_intents[i]
		elif i == 1:
			turn0_intent_1 = turn0_intents[i]
	_check(turn0_intent_0 == {"type": "block", "enemy_position": 1, "amount": 1},
		"Turn 0: Ragling (pos 1) announces Block 1")
	_check(turn0_intent_1 == {"type": "attack", "enemy_position": 2, "amount": 1, "target_position": 3},
		"Turn 0: Guard (pos 2) announces Attack 1 at hero 3 (Tinker)")
	
	# Execute phase - sorted by enemy_position
	var result0 = phase.execute_phase(party, enemies, turn0_intents)
	_check(result0["ok"] == true, "Turn 0 phase executes successfully")
	var events0: Array = result0["events"]
	_check(events0.size() == 2, "Turn 0 produces two events")
	
	# Verify events are in source order (1 then 2) - use safe loop access
	var event0_0: Dictionary = {}
	var event0_1: Dictionary = {}
	for i in range(events0.size()):
		if i == 0:
			event0_0 = events0[i]
		elif i == 1:
			event0_1 = events0[i]
	_check(event0_0 == {"type": "block", "enemy_position": 1, "applied": true},
		"Event 0: Ragling Block 1 applied")
	_check(event0_1 == {"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
		"Event 1: Guard Attack 1 at Tinker applied")
	
	# Verify state after turn 0
	_check(enemies.get_enemy(1)["block"] == 1 and enemies.get_enemy(1)["hp"] == 12,
		"Ragling has 1 Block, 12 HP after turn 0")
	_check(enemies.get_enemy(2)["block"] == 0 and enemies.get_enemy(2)["hp"] == 12,
		"Guard has 0 Block, 12 HP after turn 0")
	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 6,
		"Warden unchanged at 40 HP, 6 Block")
	_check(party.get_hero(2)["hp"] == 30 and party.get_hero(2)["block"] == 0,
		"Seamstress unchanged at 30 HP, 0 Block")
	_check(party.get_hero(3)["hp"] == 25 and party.get_hero(3)["block"] == 0,
		"Tinker takes 1 damage: 26 -> 25 HP")
	
	# Verify intents haven't advanced (caller must advance explicitly)
	var turn0_again = intents.get_intents()
	_check(turn0_again == turn0_intents, "get_intents() does not advance turn")
	
	# Advance to turn 1
	_check(intents.advance_turn(), "Advance to turn 1 succeeds")
	var turn1_intents = intents.get_intents()
	var turn1_intent_0: Dictionary = {}
	var turn1_intent_1: Dictionary = {}
	for i in range(turn1_intents.size()):
		if i == 0:
			turn1_intent_0 = turn1_intents[i]
		elif i == 1:
			turn1_intent_1 = turn1_intents[i]
	_check(turn1_intent_0 == {"type": "attack", "enemy_position": 1, "amount": 1, "target_position": 1},
		"Turn 1: Ragling announces Attack 1 at hero 1 (Warden)")
	_check(turn1_intent_1 == {"type": "block", "enemy_position": 2, "amount": 1},
		"Turn 1: Guard announces Block 1")
	
	# Reset hero Block for player turn (simulating start_player_turn)
	_check(party.start_player_turn(), "Player turn resets hero Block")
	_check(party.get_hero(1)["block"] == 0, "Warden Block reset to 0")
	_check(party.get_hero(2)["block"] == 0, "Seamstress Block reset to 0")
	_check(party.get_hero(3)["block"] == 0, "Tinker Block reset to 0")
	
	# Execute turn 1 phase
	var result1 = phase.execute_phase(party, enemies, turn1_intents)
	_check(result1["ok"] == true, "Turn 1 phase executes successfully")
	var events1: Array = result1["events"]
	var event1_0: Dictionary = {}
	var event1_1: Dictionary = {}
	for i in range(events1.size()):
		if i == 0:
			event1_0 = events1[i]
		elif i == 1:
			event1_1 = events1[i]
	_check(event1_0 == {"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		"Event 0: Ragling Attack 1 at Warden applied")
	_check(event1_1 == {"type": "block", "enemy_position": 2, "applied": true},
		"Event 1: Guard Block 1 applied")
	
	# Verify state after turn 1
	_check(enemies.get_enemy(1)["block"] == 1 and enemies.get_enemy(1)["hp"] == 12,
		"Ragling retains 1 Block, 12 HP")
	_check(enemies.get_enemy(2)["block"] == 1 and enemies.get_enemy(2)["hp"] == 12,
		"Guard gains 1 Block, 12 HP")
	_check(party.get_hero(1)["hp"] == 39 and party.get_hero(1)["block"] == 0,
		"Warden takes 1 damage: 40 -> 39 HP (no Block)")
	_check(party.get_hero(2)["hp"] == 30, "Seamstress unchanged at 30 HP")
	_check(party.get_hero(3)["hp"] == 25, "Tinker unchanged at 25 HP")
	
	# Advance to turn 2 (wrap to turn 0 pattern)
	_check(intents.advance_turn(), "Advance to turn 2 succeeds")
	var turn2_intents = intents.get_intents()
	var turn2_intent_0: Dictionary = {}
	var turn2_intent_1: Dictionary = {}
	for i in range(turn2_intents.size()):
		if i == 0:
			turn2_intent_0 = turn2_intents[i]
		elif i == 1:
			turn2_intent_1 = turn2_intents[i]
	_check(turn2_intent_0 == {"type": "block", "enemy_position": 1, "amount": 1},
		"Turn 2 (wrap): Ragling announces Block 1")
	_check(turn2_intent_1 == {"type": "attack", "enemy_position": 2, "amount": 1, "target_position": 3},
		"Turn 2 (wrap): Guard announces Attack 1 at hero 3 (Tinker)")
	
	# Execute turn 2 phase (player Block already 0 from previous reset)
	var result2 = phase.execute_phase(party, enemies, turn2_intents)
	_check(result2["ok"] == true, "Turn 2 phase executes successfully")
	var events2: Array = result2["events"]
	var event2_0: Dictionary = {}
	var event2_1: Dictionary = {}
	for i in range(events2.size()):
		if i == 0:
			event2_0 = events2[i]
		elif i == 1:
			event2_1 = events2[i]
	_check(event2_0 == {"type": "block", "enemy_position": 1, "applied": true},
		"Event 0: Ragling Block 1 applied (stacks to 2)")
	_check(event2_1 == {"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
		"Event 1: Guard Attack 1 at Tinker applied")
	
	# Verify state after turn 2
	_check(enemies.get_enemy(1)["block"] == 2 and enemies.get_enemy(1)["hp"] == 12,
		"Ragling Block stacks to 2, 12 HP")
	_check(enemies.get_enemy(2)["block"] == 1 and enemies.get_enemy(2)["hp"] == 12,
		"Guard retains 1 Block, 12 HP")
	_check(party.get_hero(3)["hp"] == 24, "Tinker takes another hit: 25 -> 24 HP")
	_check(party.get_hero(1)["hp"] == 39, "Warden unchanged at 39 HP")
	_check(party.get_hero(2)["hp"] == 30, "Seamstress unchanged at 30 HP")
	
	# Verify action definitions unchanged
	var final_intents = intents.get_intents()
	_check(final_intents == turn2_intents, "Action definitions unchanged after phase execution")


func _test_existing_starter_encounter_unchanged() -> void:
	# Load and verify the existing starter_attacks.json is unchanged (using same loader for float conversion)
	var starter_defs = _load_encounter_definitions("res://data/encounters/starter_attacks.json")
	_check(starter_defs is Array and starter_defs.size() == 2, "starter_attacks has two enemy slots")
	
	# Original pattern: slot 1 [attack hero 1, attack hero 2], slot 2 [Block 1]
	var slot1 = starter_defs[0]
	var slot2 = starter_defs[1]
	_check(slot1["enemy_position"] == 1, "starter slot 1 position 1")
	_check(slot2["enemy_position"] == 2, "starter slot 2 position 2")
	
	_check(slot1["pattern"].size() == 2, "starter Ragling has two-pattern cycle")
	_check(slot1["pattern"][0] == {"type": "attack", "amount": 1, "target_position": 1},
		"starter Ragling turn 0: Attack 1 at hero 1")
	_check(slot1["pattern"][1] == {"type": "attack", "amount": 1, "target_position": 2},
		"starter Ragling turn 1: Attack 1 at hero 2")
	
	_check(slot2["pattern"].size() == 1, "starter Guard has one-pattern cycle")
	_check(slot2["pattern"][0] == {"type": "block", "amount": 1},
		"starter Guard turn 0: Block 1")
	
	# Verify both encounter files can be loaded simultaneously and are independent
	var guard_counterattack_defs = _load_encounter_definitions("res://data/encounters/guard_counterattack.json")
	_check(guard_counterattack_defs[0]["pattern"][0]["type"] == "block",
		"guard_counterattack slot 1 turn 0 is Block (different from starter)")
	_check(starter_defs[0]["pattern"][0]["type"] == "attack",
		"starter slot 1 turn 0 is Attack (different from guard_counterattack)")


func _test_deterministic_replay_and_no_rng_consumption() -> void:
	# Load data using proper loaders
	var party_defs = _load_party_definitions()
	var enemy_defs = _load_enemy_definitions()
	var guard_counterattack_defs = _load_encounter_definitions("res://data/encounters/guard_counterattack.json")
	
	# Create two identical setups
	var party_a = CombatParty.new(party_defs)
	var enemies_a = CombatEnemies.new(enemy_defs)
	var intents_a = CombatEnemyIntents.new(guard_counterattack_defs)
	var phase_a = CombatEnemyPhase.new()
	var starting_block_a = CombatStartingBlock.new(party_a)
	_check(starting_block_a.apply(), "Setup A: Warden starting block")
	
	var party_b = CombatParty.new(party_defs)
	var enemies_b = CombatEnemies.new(enemy_defs)
	var intents_b = CombatEnemyIntents.new(guard_counterattack_defs)
	var phase_b = CombatEnemyPhase.new()
	var starting_block_b = CombatStartingBlock.new(party_b)
	_check(starting_block_b.apply(), "Setup B: Warden starting block")
	
	# Execute several turns and verify identical state
	for turn in range(6):
		var intents_a_turn = intents_a.get_intents()
		var intents_b_turn = intents_b.get_intents()
		_check(intents_a_turn == intents_b_turn, "Turn %d: both schedulers announce identical intents" % turn)
		
		var result_a = phase_a.execute_phase(party_a, enemies_a, intents_a_turn)
		var result_b = phase_b.execute_phase(party_b, enemies_b, intents_b_turn)
		_check(result_a == result_b, "Turn %d: both phases produce identical events" % turn)
		
		_check(party_a.get_heroes() == party_b.get_heroes(), "Turn %d: party states identical" % turn)
		_check(enemies_a.get_enemies() == enemies_b.get_enemies(), "Turn %d: enemy states identical" % turn)
		
		# Advance both
		_check(intents_a.advance_turn() and intents_b.advance_turn(), "Turn %d: both advance" % turn)
		
		# Simulate player turn Block reset every other turn
		if turn % 2 == 1:
			party_a.start_player_turn()
			party_b.start_player_turn()
	
	# Verify calling get_intents() multiple times doesn't advance
	var snapshot_a = intents_a.get_intents()
	for i in range(5):
		_check(intents_a.get_intents() == snapshot_a, "Repeated get_intents() returns same snapshot")
	
	# Verify executing phase doesn't advance scheduler
	var before_advance = intents_a.get_intents()
	phase_a.execute_phase(party_a, enemies_a, before_advance)
	_check(intents_a.get_intents() == before_advance, "Phase execution does not advance scheduler")
	
	# Verify copied announcement doesn't advance
	var copied = before_advance.duplicate(true)
	phase_a.execute_phase(party_a, enemies_a, copied)
	_check(intents_a.get_intents() == before_advance, "Copied announcement execution does not advance scheduler")
	
	# Verify no RNG consumption (CombatEnemyIntents and CombatEnemyPhase don't use RNG)
	# This is implicit - they have no RNG dependency


func _test_slain_guard_skips_attack() -> void:
	# Load data using proper loaders
	var party_defs = _load_party_definitions()
	var enemy_defs = _load_enemy_definitions()
	var guard_counterattack_defs = _load_encounter_definitions("res://data/encounters/guard_counterattack.json")
	
	# Setup: Guard (position 2) is slain before its attack
	var party = CombatParty.new(party_defs)
	var enemies = CombatEnemies.new(enemy_defs)
	var intents = CombatEnemyIntents.new(guard_counterattack_defs)
	var phase = CombatEnemyPhase.new()
	var starting_block = CombatStartingBlock.new(party)
	_check(starting_block.apply(), "Warden starting block")
	
	# Slay the Guard (position 2) - 12 damage
	_check(enemies.apply_damage(2, 12), "Guard slain with 12 damage")
	_check(enemies.is_slain(2), "Guard is slain")
	_check(enemies.get_enemy(2)["hp"] == 0 and enemies.get_enemy(2)["position"] == 2,
		"Guard retains position 2 with 0 HP")
	
	# Get turn 0 intents: Ragling Block 1, Guard Attack 1 at Tinker
	var turn0_intents = intents.get_intents()
	var turn0_intent_0: Dictionary = {}
	var turn0_intent_1: Dictionary = {}
	for i in range(turn0_intents.size()):
		if i == 0:
			turn0_intent_0 = turn0_intents[i]
		elif i == 1:
			turn0_intent_1 = turn0_intents[i]
	_check(turn0_intent_0["enemy_position"] == 1 and turn0_intent_0["type"] == "block",
		"Ragling announces Block 1")
	_check(turn0_intent_1["enemy_position"] == 2 and turn0_intent_1["type"] == "attack",
		"Guard announces Attack 1 at Tinker")
	
	# Execute phase - Guard is slain, so its attack should be skipped
	var result = phase.execute_phase(party, enemies, turn0_intents)
	_check(result["ok"] == true, "Phase executes with slain Guard")
	var events: Array = result["events"]
	_check(events.size() == 2, "Two events produced (one skipped)")
	
	# Verify Ragling's Block applied, Guard's attack skipped
	var event_0: Dictionary = {}
	var event_1: Dictionary = {}
	for i in range(events.size()):
		if i == 0:
			event_0 = events[i]
		elif i == 1:
			event_1 = events[i]
	_check(event_0 == {"type": "block", "enemy_position": 1, "applied": true},
		"Ragling Block 1 applied")
	_check(event_1 == {"type": "attack", "enemy_position": 2, "target_position": 3, "applied": false},
		"Guard attack skipped (applied: false)")
	
	# Verify state: Ragling has Block, Tinker unharmed
	_check(enemies.get_enemy(1)["block"] == 1, "Ragling gains Block")
	_check(enemies.get_enemy(2)["block"] == 0, "Slain Guard gains no Block")
	_check(party.get_hero(3)["hp"] == 26, "Tinker unharmed at 26 HP (Guard attack skipped)")
	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 6, "Warden unchanged")
	
	# Verify the scheduler didn't advance from phase execution
	_check(intents.get_intents() == turn0_intents, "Scheduler not advanced by phase execution")
	
	# Now test the reverse: slay Ragling, Guard should still act
	var party2 = CombatParty.new(party_defs)
	var enemies2 = CombatEnemies.new(enemy_defs)
	var intents2 = CombatEnemyIntents.new(guard_counterattack_defs)
	var phase2 = CombatEnemyPhase.new()
	var starting_block2 = CombatStartingBlock.new(party2)
	_check(starting_block2.apply(), "Warden starting block")
	
	# Slay Ragling (position 1)
	_check(enemies2.apply_damage(1, 12), "Ragling slain")
	_check(enemies2.is_slain(1), "Ragling is slain")
	
	# Get turn 0 intents
	var turn0_intents2 = intents2.get_intents()
	
	# Execute phase
	var result2 = phase2.execute_phase(party2, enemies2, turn0_intents2)
	_check(result2["ok"] == true, "Phase executes with slain Ragling")
	var events2: Array = result2["events"]
	var event2_0: Dictionary = {}
	var event2_1: Dictionary = {}
	for i in range(events2.size()):
		if i == 0:
			event2_0 = events2[i]
		elif i == 1:
			event2_1 = events2[i]
	
	# Verify Ragling's Block skipped, Guard's attack applied
	_check(event2_0 == {"type": "block", "enemy_position": 1, "applied": false},
		"Slain Ragling Block skipped")
	_check(event2_1 == {"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
		"Guard attack applied")
	
	_check(party2.get_hero(3)["hp"] == 25, "Tinker takes 1 damage from Guard")
	_check(enemies2.get_enemy(1)["block"] == 0, "Slain Ragling has no Block")
	_check(enemies2.get_enemy(2)["block"] == 0, "Guard has no Block (attack, not block)")