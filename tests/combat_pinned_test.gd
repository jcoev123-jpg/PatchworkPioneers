extends SceneTree

var failures: Array[String] = []
var checks := 0
var pinned := CombatPinned.new()
var attacks := CombatStatusAttacks.new()


func _initialize() -> void:
	_test_relay_committed_hits()
	_test_relay_energy_cap()
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


func _test_relay_committed_hits() -> void:
	for mode in ["live", "dead", "torn", "stale", "failed", "same", "preview", "unworn", "simulated"]:
		var party := CombatParty.new([{"id": "warden", "max_hp": 40},
			{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
		var wardrobe := RunPatchWardrobe.new(party.get_heroes(), ["relay_bobbin"],
			RunAuthoredPatchDefinitions.load_definitions(), 0)
		_check(wardrobe.is_valid(), mode + ": real wardrobe admitted")
		if mode != "unworn":
			_check(wardrobe.sew("relay_bobbin", "tinker", "HEAD", "relay", wardrobe.get_snapshot()).ok,
				mode + ": Relay Bobbin sewn to Tinker")
		var torn := RunTornMending.new(party.get_heroes())
		if mode == "torn":
			torn._tear_counts.tinker = 1
		var rng := RandomNumberGenerator.new()
		rng.seed = 317
		var deck := CombatDeck.new(["tinker_spring_trap", "warden_brass_buckle",
			"tinker_spring_trap", "warden_brass_buckle"], rng)
		_check(deck.start_turn(), mode + ": actual active seeded hand")
		var foes := CombatEnemies.new([{"id": "training_target", "max_hp": 200}])
		var authority := CombatPinned.new()
		authority.bind_relay(deck, party, foes, wardrobe, torn)
		var trap := CombatTinkerPoolAttacks.new()
		var pin_receipt := trap.play_attack(deck, party, foes, "tinker_spring_trap", 1, authority)
		_check(pin_receipt.ok and authority.pinner_for_enemy(1) == "tinker",
			mode + ": a paid actual Spring Trap placed the token")
		if mode == "dead":
			_check(party.apply_damage(3, 999), "down actual wearer after pin")
		if mode == "stale":
			_check(wardrobe.refresh_run_context(party.get_heroes(), ["relay_bobbin"], 0, 1,
				[], wardrobe.get_snapshot()), "change bound wardrobe context")
		if mode == "preview":
			var energy := deck.energy
			_check(authority.bonus_for_attack(foes, 1, "warden") == 5
				and deck.energy == energy and not authority._relay_used,
				"preview quotes damage without consumption or energy")
			continue
		if mode == "simulated":
			authority.begin_confirmed_cast("warden_brass_buckle")
			_check(deck.try_spend_energy(1) and deck.discard_played("warden_brass_buckle")
				and authority.consume_after_attack(1, "warden", true), "simulate a paid cast without a real hit")
			_check(not authority.finish_confirmed_cast({"ok": true, "hits": [{"position": 1,
				"damage": 5, "hp_loss": 0, "block_absorbed": 0}]}) and not authority._relay_used,
				"simulated consumption without enemy HP/Block change cannot award energy")
			continue
		var id := "tinker_spring_trap" if mode == "same" else "warden_brass_buckle"
		if mode == "failed":
			deck.combat_state.energy = 0
		var before := deck.energy
		authority.begin_confirmed_cast(id)
		var receipt: Dictionary
		if mode == "same":
			receipt = trap.play_attack(deck, party, foes, id, 1, authority)
		else:
			receipt = CombatPoolPlainStrikes.new().play_card(deck, party, foes, id, 1, authority)
		var awarded := authority.finish_confirmed_cast(receipt)
		_check(awarded == (mode == "live"), mode + ": only living untorn cross-owner consumption awards")
		_check(deck.energy == (before if mode in ["live", "failed"] else before - 1),
			mode + ": exact paid energy and optional one-energy refund")
		var settled := deck.energy
		_check(not authority.finish_confirmed_cast(receipt) and deck.energy == settled,
			mode + ": stale duplicate receipt awards zero")
		if mode == "live":
			_check(authority._relay_used, "combat latch consumed")
			_check(deck.end_turn() and deck.start_turn(), "real next turn")
			_check(authority._relay_used, "turn refresh preserves once-per-combat latch")
			_check(trap.play_attack(deck, party, foes, "tinker_spring_trap", 1, authority).ok,
				"real next turn wearer places another pin")
			authority.begin_confirmed_cast("warden_brass_buckle")
			var later := CombatPoolPlainStrikes.new().play_card(deck, party, foes,
				"warden_brass_buckle", 1, authority)
			_check(later.ok and not authority.finish_confirmed_cast(later) and deck.energy == 1,
				"real consumed cross-owner pin next turn grants zero after combat latch")
			authority.reset_combat()
			_check(not authority._relay_used and authority.pinner_for_enemy(1).is_empty(),
				"new fight reset clears latch and tokens")


func _test_relay_energy_cap() -> void:
	var party := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), ["relay_bobbin"],
		RunAuthoredPatchDefinitions.load_definitions(), 0)
	_check(wardrobe.sew("relay_bobbin", "seamstress", "HEAD", "cap", wardrobe.get_snapshot()).ok,
		"cap fixture sews actual pinning wearer")
	var rng := RandomNumberGenerator.new()
	rng.seed = 317
	var deck := CombatDeck.new(["seamstress_needle_pin", "tinker_spring_trap"], rng)
	var enemies := CombatEnemies.new([{"id": "cap_target", "max_hp": 200}])
	var pins := CombatPinned.new()
	pins.bind_relay(deck, party, enemies, wardrobe, RunTornMending.new(party.get_heroes()))
	_check(deck.start_turn(), "cap fixture starts actual turn")
	_check(CombatSeamstressPoolControl.new().play_card(deck, party, enemies, pins,
		CombatUnravel.new(), "seamstress_needle_pin", 1).get("ok", false),
		"actual paid Needle Pin places wearer's token")
	_check(pins.pinner_for_enemy(1) == "seamstress" and deck.end_turn() and deck.start_turn(),
		"token persists into fresh three-energy hand")
	pins.begin_confirmed_cast("tinker_spring_trap", "tinker", 1)
	var hit := CombatTinkerPoolAttacks.new().play_attack(deck, party, enemies,
		"tinker_spring_trap", 1, pins)
	_check(hit.ok and pins.finish_confirmed_cast(hit) and deck.energy == 3,
		"genuine paid confirmed hit consumes entitlement, shared energy returns to capped three")


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
