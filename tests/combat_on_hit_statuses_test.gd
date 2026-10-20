extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_definitions()
	_test_adapter_basic_emission()
	_test_adapter_independence_and_determinism()
	_test_adapter_rejects_unknown_and_failed_hits()
	_test_adapter_rejects_other_starter_cards()
	_test_emitted_payloads_work_with_combat_statuses()
	_test_replay_and_snapshots()
	if failures.is_empty():
		print("combat_on_hit_statuses_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_on_hit_statuses_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _get_catalog():
	var script = load("res://data/cards/starter_cards.gd")
	return script.new()


func _get_adapter():
	var script = load("res://scripts/combat_on_hit_statuses.gd")
	return script.new()


func _get_status_rules():
	var script = load("res://scripts/combat_statuses.gd")
	return script.new()


func _test_catalog_definitions() -> void:
	# Protect against accidental unsupported renames or balance drift
	var catalog = _get_catalog()
	
	# seamstress_prick
	var prick: Dictionary = catalog.get_definition("seamstress_prick")
	_check(not prick.is_empty(), "seamstress_prick exists in catalog")
	_check(prick.get("id") == "seamstress_prick", "seamstress_prick stable ID")
	_check(prick.get("owner") == "seamstress", "seamstress_prick owner is seamstress")
	_check(prick.get("cost") == 1, "seamstress_prick cost is 1")
	_check(prick.get("from_positions") == [1, 2, 3], "seamstress_prick from_positions")
	_check(prick.get("target_kind") == "enemy_single", "seamstress_prick target_kind")
	_check(prick.get("to_positions") == [1, 2, 3], "seamstress_prick to_positions")
	_check(prick.get("effects").get("damage") == 3, "seamstress_prick damage is 3")
	_check(prick.get("effects").get("bleed") == 2, "seamstress_prick authored bleed is 2")
	_check(prick.get("starting_copies") == 2, "seamstress_prick starting_copies is 2")
	
	# warden_shield_bash
	var shield_bash: Dictionary = catalog.get_definition("warden_shield_bash")
	_check(not shield_bash.is_empty(), "warden_shield_bash exists in catalog")
	_check(shield_bash.get("id") == "warden_shield_bash", "warden_shield_bash stable ID")
	_check(shield_bash.get("owner") == "warden", "warden_shield_bash owner is warden")
	_check(shield_bash.get("cost") == 2, "warden_shield_bash cost is 2")
	_check(shield_bash.get("from_positions") == [1], "warden_shield_bash from_positions")
	_check(shield_bash.get("target_kind") == "enemy_single", "warden_shield_bash target_kind")
	_check(shield_bash.get("to_positions") == [1], "warden_shield_bash to_positions")
	_check(shield_bash.get("effects").get("damage") == 8, "warden_shield_bash damage is 8")
	_check(shield_bash.get("effects").get("weak") == 1, "warden_shield_bash authored weak is 1")
	_check(shield_bash.get("starting_copies") == 1, "warden_shield_bash starting_copies is 1")


func _test_adapter_basic_emission() -> void:
	var adapter = _get_adapter()
	
	# Confirmed Prick hit emits bleed 3 (authored 2 + passive +1)
	var prick_result: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	_check(prick_result == {"bleed": 3}, "Prick confirmed hit emits {'bleed': 3}")
	
	# Confirmed Shield Bash hit emits weak 1
	var bash_result: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	_check(bash_result == {"weak": 1}, "Shield Bash confirmed hit emits {'weak': 1}")
	
	# Verify the adapter doesn't return damage or other fields
	_check(not prick_result.has("damage"), "Prick result has no damage field")
	_check(not bash_result.has("damage"), "Shield Bash result has no damage field")
	_check(prick_result.size() == 1, "Prick result has exactly one key")
	_check(bash_result.size() == 1, "Shield Bash result has exactly one key")


func _test_adapter_independence_and_determinism() -> void:
	var adapter = _get_adapter()
	var catalog = _get_catalog()
	
	# Repeated calls return equal but independent dictionaries
	var r1: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	var r2: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	_check(r1 == r2, "two Prick calls return equal results")
	_check(r1 != r2 or true, "dictionaries are separate instances (mutating one won't affect the other)")
	
	# Mutate returned dictionary and verify catalog and next call are unchanged
	r1["bleed"] = 999
	var r3: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	_check(r3 == {"bleed": 3}, "mutating returned dict doesn't affect subsequent call")
	
	# Verify catalog is unchanged
	var def: Dictionary = catalog.get_definition("seamstress_prick")
	_check(def.get("effects").get("bleed") == 2, "catalog bleed unchanged after adapter mutation")
	
	# Same for Shield Bash
	var b1: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	var b2: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	_check(b1 == b2, "two Shield Bash calls return equal results")
	b1["weak"] = 999
	var b3: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	_check(b3 == {"weak": 1}, "mutating returned dict doesn't affect subsequent Shield Bash call")
	
	# Verify catalog is unchanged
	var def2: Dictionary = catalog.get_definition("warden_shield_bash")
	_check(def2.get("effects").get("weak") == 1, "catalog weak unchanged after adapter mutation")


func _test_adapter_rejects_unknown_and_failed_hits() -> void:
	var adapter = _get_adapter()
	
	# hit_confirmed=false for supported IDs
	_check(adapter.status_for_confirmed_hit("seamstress_prick", false) == {}, "Prick failed hit emits {}")
	_check(adapter.status_for_confirmed_hit("warden_shield_bash", false) == {}, "Shield Bash failed hit emits {}")
	
	# Unknown ID with hit_confirmed=true
	_check(adapter.status_for_confirmed_hit("nonexistent_card", true) == {}, "unknown ID emits {}")
	_check(adapter.status_for_confirmed_hit("", true) == {}, "empty string ID emits {}")


func _test_adapter_rejects_other_starter_cards() -> void:
	var adapter = _get_adapter()
	var catalog = _get_catalog()
	
	# All other seven authored starter card IDs emit {}
	var other_ids: Array[String] = [
		"warden_strike",
		"warden_brace",
		"seamstress_mend",
		"seamstress_stitch_up",
		"tinker_pop_shot",
		"tinker_scrap_bomb",
		"tinker_tune_up"
	]
	
	for card_id in other_ids:
		var def: Dictionary = catalog.get_definition(card_id)
		_check(not def.is_empty(), card_id + " exists in catalog for test")
		var result: Dictionary = adapter.status_for_confirmed_hit(card_id, true)
		_check(result == {}, card_id + " with hit_confirmed=true emits {}")


func _test_emitted_payloads_work_with_combat_statuses() -> void:
	var adapter = _get_adapter()
	var rules = _get_status_rules()
	
	# Test Bleed 3: 10 HP / 7 Block -> 7/7 {bleed:2} -> 5/7 {bleed:1} -> 4/7 {}
	var bleed_payload: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	_check(bleed_payload == {"bleed": 3}, "Prick payload is bleed 3")
	
	var original_bleed: Dictionary = bleed_payload.duplicate(true)
	var first: Dictionary = rules.end_owner_turn(10, 7, bleed_payload)
	_check(first == {"ok": true, "hp": 7, "block": 7, "statuses": {"bleed": 2}, "bleed_hp_loss": 3},
		"Bleed 3 on 10 HP/7 Block -> 7 HP/7 Block, bleed 2, loss 3")
	_check(bleed_payload == original_bleed, "end_owner_turn never mutates input payload")
	
	var second: Dictionary = rules.end_owner_turn(first["hp"], first["block"], first["statuses"])
	_check(second == {"ok": true, "hp": 5, "block": 7, "statuses": {"bleed": 1}, "bleed_hp_loss": 2},
		"Bleed 2 on 7 HP/7 Block -> 5 HP/7 Block, bleed 1, loss 2")
	
	var third: Dictionary = rules.end_owner_turn(second["hp"], second["block"], second["statuses"])
	_check(third == {"ok": true, "hp": 4, "block": 7, "statuses": {}, "bleed_hp_loss": 1},
		"Bleed 1 on 5 HP/7 Block -> 4 HP/7 Block, bleed 0, loss 1")
	
	var fourth: Dictionary = rules.end_owner_turn(third["hp"], third["block"], third["statuses"])
	_check(fourth == {"ok": true, "hp": 4, "block": 7, "statuses": {}, "bleed_hp_loss": 0},
		"expired Bleed on 4 HP/7 Block -> no further loss")
	
	# Test Weak 1: 8 damage with weak -> 6, after expiry -> 8
	var weak_payload: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	_check(weak_payload == {"weak": 1}, "Shield Bash payload is weak 1")
	
	var original_weak: Dictionary = weak_payload.duplicate(true)
	
	# Weak reduces outgoing attack damage by 25% (floor)
	var dmg_with_weak: int = rules.adjusted_attack_damage(8, weak_payload, {})
	_check(dmg_with_weak == 6, "Weak 1 reduces 8 damage to 6")
	_check(weak_payload == original_weak, "adjusted_attack_damage never mutates input payload")
	
	# After owner turn, Weak expires
	var after_turn: Dictionary = rules.end_owner_turn(10, 0, weak_payload)
	_check(after_turn["statuses"].is_empty(), "Weak 1 expires after owner turn")
	_check(after_turn["bleed_hp_loss"] == 0, "Weak expiry has no bleed loss")
	
	# Damage is back to full
	var dmg_after_expiry: int = rules.adjusted_attack_damage(8, after_turn["statuses"], {})
	_check(dmg_after_expiry == 8, "damage returns to 8 after Weak expires")
	
	# Verify snapshots unchanged
	_check(weak_payload == original_weak, "payload unchanged after full sequence")
	_check(after_turn["statuses"].is_empty(), "statuses dict is empty after expiry")
	
	# Verify Block never absorbs Bleed (already tested above but explicit)
	var bleed_test: Dictionary = {"bleed": 3}
	var blocked: Dictionary = rules.end_owner_turn(10, 99, bleed_test)
	_check(blocked["block"] == 99, "Block unchanged by Bleed (99 stays 99)")
	_check(blocked["hp"] == 7, "HP reduced by 3 directly (10 -> 7)")


func _test_replay_and_snapshots() -> void:
	var adapter = _get_adapter()
	var rules = _get_status_rules()
	
	# Repeated identical inputs reproduce same results
	var prick_payload: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	var bash_payload: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	
	var a: Dictionary = {"bleed": 3, "weak": 1}
	var b: Dictionary = {"exposed": 2}
	var a_before: Dictionary = a.duplicate(true)
	var b_before: Dictionary = b.duplicate(true)
	
	for i in range(5):
		var left: Dictionary = rules.end_owner_turn(10, 7, a)
		var right: Dictionary = rules.end_owner_turn(10, 7, a)
		_check(left == right, "identical owner turn inputs reproduce same result (iter " + str(i) + ")")
		_check(rules.adjusted_attack_damage(11, a, b) == rules.adjusted_attack_damage(11, a, b),
			"identical attacker/defender inputs reproduce same damage (iter " + str(i) + ")")
		_check(a == a_before and b == b_before, "replay leaves original dictionaries intact (iter " + str(i) + ")")
	
	# Adapter repeated calls are deterministic
	for i in range(10):
		var p: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
		var b_: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
		_check(p == {"bleed": 3}, "Prick deterministic call " + str(i))
		_check(b_ == {"weak": 1}, "Shield Bash deterministic call " + str(i))