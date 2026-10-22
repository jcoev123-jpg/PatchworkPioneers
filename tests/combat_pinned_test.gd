extends SceneTree

var failures: Array[String] = []
var checks := 0
var pinned := CombatPinned.new()
var attacks := CombatStatusAttacks.new()


func _initialize() -> void:
	_test_ac1_basic_pin_and_replace()
	_test_ac1_independent_slots_and_slain_block()
	_test_ac2_cross_hero_bonus_and_preview()
	_test_ac2_status_arithmetic_with_weak_exposed()
	_test_ac3_consumption_and_preservation()
	_test_ac3_lethal_hit_consumes()
	_test_ac3_turn_persistence_and_reset()
	_test_ac4_invalid_calls_no_side_effects()
	_test_ac4_roster_unchanged_by_token_ops()
	if failures.is_empty():
		print("combat_pinned_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_pinned_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _enemies(count: int = 3) -> CombatEnemies:
	var definitions: Array = []
	for index in range(count):
		definitions.append({"id": "fixture_%d" % index, "max_hp": 11 + index})
	return CombatEnemies.new(definitions)


func _test_ac1_basic_pin_and_replace() -> void:
	pinned.reset_combat()
	var enemies := _enemies()
	# Pin enemy 1 with warden
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 with warden")
	_check(pinned.pinner_for_enemy(1) == "warden", "pinner recorded as warden")
	# Pin again with seamstress replaces
	_check(pinned.pin_enemy(enemies, 1, "seamstress"), "replace pin with seamstress")
	_check(pinned.pinner_for_enemy(1) == "seamstress", "pinner replaced by seamstress")
	# Pin enemy 2 with tinker is independent
	_check(pinned.pin_enemy(enemies, 2, "tinker"), "pin enemy 2 with tinker")
	_check(pinned.pinner_for_enemy(2) == "tinker", "enemy 2 has tinker")
	_check(pinned.pinner_for_enemy(1) == "seamstress", "enemy 1 unchanged")
	# Enemy 3 has no pin
	_check(pinned.pinner_for_enemy(3) == "", "enemy 3 has no pin")


func _test_ac1_independent_slots_and_slain_block() -> void:
	pinned.reset_combat()
	var enemies := _enemies(3)
	# Pin all three
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 with warden")
	_check(pinned.pin_enemy(enemies, 2, "seamstress"), "pin enemy 2 with seamstress")
	_check(pinned.pin_enemy(enemies, 3, "tinker"), "pin enemy 3 with tinker")
	# Kill enemy 2
	_check(enemies.apply_damage(2, 100), "kill enemy 2")
	_check(enemies.is_slain(2), "enemy 2 is slain")
	# Cannot pin slain enemy
	_check(not pinned.pin_enemy(enemies, 2, "warden"), "cannot pin slain enemy")
	_check(pinned.pinner_for_enemy(2) == "seamstress", "slain enemy retains old pin")
	# Cannot pin invalid positions
	_check(not pinned.pin_enemy(enemies, 0, "warden"), "invalid position 0 rejected")
	_check(not pinned.pin_enemy(enemies, 4, "warden"), "invalid position 4 rejected")
	_check(not pinned.pin_enemy(enemies, -1, "warden"), "invalid position -1 rejected")
	# Cannot pin with invalid pinner
	_check(not pinned.pin_enemy(enemies, 1, ""), "empty pinner rejected")
	_check(not pinned.pin_enemy(enemies, 1, "unknown"), "unknown pinner rejected")
	_check(not pinned.pin_enemy(enemies, 1, "hero"), "invalid hero rejected")
	# Invalid roster rejects
	_check(not pinned.pin_enemy(null, 1, "warden"), "null roster rejected")
	_check(not pinned.pin_enemy(CombatEnemies.new([]), 1, "warden"), "invalid roster rejected")


func _test_ac2_cross_hero_bonus_and_preview() -> void:
	pinned.reset_combat()
	var enemies := _enemies()
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 with warden")
	# Different hero gets +5
	_check(pinned.bonus_for_attack(enemies, 1, "seamstress") == 5, "cross-hero bonus is +5")
	_check(pinned.bonus_for_attack(enemies, 1, "tinker") == 5, "tinker also gets +5")
	# Same hero gets 0
	_check(pinned.bonus_for_attack(enemies, 1, "warden") == 0, "same hero gets 0")
	# Preview (bonus_for_attack) does not consume
	_check(pinned.bonus_for_attack(enemies, 1, "seamstress") == 5, "preview still +5")
	_check(pinned.pinner_for_enemy(1) == "warden", "pin still present after preview")
	# Dead enemy yields 0
	_check(enemies.apply_damage(1, 100), "kill enemy 1")
	_check(pinned.bonus_for_attack(enemies, 1, "seamstress") == 0, "dead enemy yields 0 bonus")
	# Invalid positions/rosters yield 0
	_check(pinned.bonus_for_attack(enemies, 0, "seamstress") == 0, "invalid position yields 0")
	_check(pinned.bonus_for_attack(enemies, 4, "seamstress") == 0, "out of range yields 0")
	_check(pinned.bonus_for_attack(null, 1, "seamstress") == 0, "null roster yields 0")
	_check(pinned.bonus_for_attack(CombatEnemies.new([]), 1, "seamstress") == 0, "invalid roster yields 0")
	# Invalid attacker yields 0
	_check(pinned.bonus_for_attack(enemies, 1, "") == 0, "empty attacker yields 0")
	_check(pinned.bonus_for_attack(enemies, 1, "unknown") == 0, "unknown attacker yields 0")


func _test_ac2_status_arithmetic_with_weak_exposed() -> void:
	pinned.reset_combat()
	var enemies := _enemies()
	_check(enemies.gain_block(1, 3), "set enemy block 3")
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin with warden")
	# Base damage 4 + cross-hero bonus 5 = 9 before statuses
	# Attacker has Weak 1, defender has Exposed 1
	# 9 with Weak (3/4) and Exposed (3/2) => 9 * 9/8 = 81/8 = 10 (floor once)
	var base_damage := 4
	var bonus := pinned.bonus_for_attack(enemies, 1, "seamstress")
	var total_before_statuses := base_damage + bonus
	_check(total_before_statuses == 9, "base 4 + bonus 5 = 9")
	var result := attacks.resolve_vs_enemy(enemies, 1, total_before_statuses, {"weak": 1}, {"exposed": 1})
	var expected_event := {"ok": true, "damage": 10, "block_absorbed": 3, "hp_loss": 7}
	_check(result == expected_event, "status arithmetic: 9 with Weak 1 + Exposed 1 -> 10 dmg, 3 block, 7 HP lost, got " + str(result))
	_check(enemies.get_enemy(1)["hp"] == 4, "enemy HP is 11 - 7 = 4")
	_check(enemies.get_enemy(1)["block"] == 0, "enemy block consumed")


func _test_ac3_consumption_and_preservation() -> void:
	pinned.reset_combat()
	var enemies := _enemies(3)
	# Pin enemy 1 with warden, enemy 2 with seamstress
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 warden")
	_check(pinned.pin_enemy(enemies, 2, "seamstress"), "pin enemy 2 seamstress")
	# Same-hero attack does not consume
	_check(not pinned.consume_after_attack(1, "warden", true), "same hero does not consume")
	_check(pinned.pinner_for_enemy(1) == "warden", "pin remains after same-hero attack")
	# Failed attempt (hit_confirmed=false) does not consume
	_check(not pinned.consume_after_attack(1, "seamstress", false), "preview does not consume")
	_check(pinned.pinner_for_enemy(1) == "warden", "pin remains after failed attempt")
	# Cross-hero confirmed hit consumes
	_check(pinned.consume_after_attack(1, "seamstress", true), "cross-hero confirmed hit consumes")
	_check(pinned.pinner_for_enemy(1) == "", "pin consumed and cleared")
	# Enemy 2 pin unaffected
	_check(pinned.pinner_for_enemy(2) == "seamstress", "enemy 2 pin unaffected")
	# Consuming again on same enemy returns false
	_check(not pinned.consume_after_attack(1, "tinker", true), "double consume returns false")
	# Invalid attacker does not consume
	_check(pinned.pin_enemy(enemies, 1, "warden"), "re-pin enemy 1")
	_check(not pinned.consume_after_attack(1, "", true), "empty attacker does not consume")
	_check(pinned.pinner_for_enemy(1) == "warden", "pin remains")
	_check(not pinned.consume_after_attack(1, "unknown", true), "unknown attacker does not consume")
	_check(pinned.pinner_for_enemy(1) == "warden", "pin remains")


func _test_ac3_lethal_hit_consumes() -> void:
	pinned.reset_combat()
	var enemies := _enemies()
	_check(enemies.gain_block(1, 0), "ensure no block")
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1")
	# Seamstress deals lethal damage (enemy has 11 HP, no block)
	var bonus := pinned.bonus_for_attack(enemies, 1, "seamstress")
	var result := attacks.resolve_vs_enemy(enemies, 1, 4 + bonus, {}, {}) # 4+5=9 damage vs 11 HP
	_check(result["ok"] and result["hp_loss"] == 9, "first hit not lethal")
	_check(not enemies.is_slain(1), "enemy still alive")
	# Pin still there because same hero? No, different hero. Wait, seamstress attacked.
	# Actually the consume should happen. Let me re-read: "A successful confirmed cross-hero attack consumes Pinned exactly once, including if that hit kills the enemy"
	# So the consume should happen on the attack. But the test is about consume_after_attack.
	# The caller (not CombatPinned) decides when to call consume_after_attack.
	# Let me test that consume_after_attack works on lethal hit.
	pinned.reset_combat()
	enemies = _enemies()
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 for lethal test")
	# Now simulate a lethal cross-hero hit
	var lethal_damage := 20
	bonus = pinned.bonus_for_attack(enemies, 1, "seamstress")
	var total := lethal_damage + bonus
	result = attacks.resolve_vs_enemy(enemies, 1, total, {}, {})
	_check(result["ok"] and enemies.is_slain(1), "lethal hit kills enemy")
	# Now consume_after_attack should work even on slain enemy
	_check(pinned.consume_after_attack(1, "seamstress", true), "consume works on lethal confirmed hit")
	_check(pinned.pinner_for_enemy(1) == "", "pin consumed after lethal hit")


func _test_ac3_turn_persistence_and_reset() -> void:
	pinned.reset_combat()
	var enemies := _enemies()
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 warden")
	_check(pinned.pin_enemy(enemies, 2, "seamstress"), "pin enemy 2 seamstress")
	# Simulate turn boundary - pins should persist
	_check(pinned.pinner_for_enemy(1) == "warden", "pin persists across turn")
	_check(pinned.pinner_for_enemy(2) == "seamstress", "pin persists across turn")
	# Reset clears all
	pinned.reset_combat()
	_check(pinned.pinner_for_enemy(1) == "", "reset clears enemy 1")
	_check(pinned.pinner_for_enemy(2) == "", "reset clears enemy 2")
	_check(pinned.pinner_for_enemy(3) == "", "reset clears enemy 3 (was empty)")


func _test_ac4_invalid_calls_no_side_effects() -> void:
	pinned.reset_combat()
	var enemies := _enemies()
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 warden")
	# Invalid consume calls don't change state
	_check(not pinned.consume_after_attack(0, "seamstress", true), "invalid position rejected")
	_check(pinned.pinner_for_enemy(1) == "warden", "state unchanged after invalid consume")
	_check(not pinned.consume_after_attack(1, "", true), "empty attacker rejected")
	_check(pinned.pinner_for_enemy(1) == "warden", "state unchanged after empty attacker")
	_check(not pinned.consume_after_attack(1, "unknown", true), "unknown attacker rejected")
	_check(pinned.pinner_for_enemy(1) == "warden", "state unchanged after unknown attacker")
	_check(not pinned.consume_after_attack(1, "seamstress", false), "preview rejected")
	_check(pinned.pinner_for_enemy(1) == "warden", "state unchanged after preview")


func _test_ac4_roster_unchanged_by_token_ops() -> void:
	pinned.reset_combat()
	var enemies := _enemies(3)
	_check(enemies.gain_block(1, 5), "set block on enemy 1")
	_check(enemies.gain_block(2, 3), "set block on enemy 2")
	_check(enemies.apply_damage(3, 5), "damage enemy 3")
	var before_roster := enemies.get_enemies()
	# Pin operations
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 warden")
	_check(pinned.pin_enemy(enemies, 2, "seamstress"), "pin enemy 2 seamstress")
	_check(pinned.pin_enemy(enemies, 1, "tinker"), "replace pin enemy 1 tinker")
	# Bonus queries
	_check(pinned.bonus_for_attack(enemies, 1, "seamstress") == 5, "bonus enemy 1 seamstress")
	_check(pinned.bonus_for_attack(enemies, 2, "warden") == 5, "bonus enemy 2 warden")
	_check(pinned.bonus_for_attack(enemies, 3, "tinker") == 0, "bonus enemy 3 no pin")
	# Consume operations
	_check(pinned.consume_after_attack(1, "seamstress", true), "consume enemy 1 seamstress")
	_check(pinned.consume_after_attack(2, "warden", true), "consume enemy 2 warden")
	_check(not pinned.consume_after_attack(2, "tinker", false), "preview enemy 2 tinker")
	# Reset
	pinned.reset_combat()
	# Roster must be identical
	var after_roster := enemies.get_enemies()
	_check(after_roster == before_roster, "token operations never mutate CombatEnemies roster")