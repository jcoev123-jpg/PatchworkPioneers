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


func _deep_snapshot_catalog() -> Dictionary:
	"""Create a deep snapshot of all StarterCards definitions."""
	var catalog = _get_catalog()
	var snapshot: Dictionary = {}
	var all_ids: Array[String] = catalog.get_all_card_ids()
	for card_id in all_ids:
		var def: Dictionary = catalog.get_definition(card_id)
		if not def.is_empty():
			snapshot[card_id] = def.duplicate(true)
	return snapshot


func _assert_catalog_unchanged(before: Dictionary, after: Dictionary, context: String) -> void:
	"""Assert catalog snapshots are identical."""
	_check(before == after, context + ": catalog definitions unchanged")


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
	_check(prick.get("display_name") == "Prick", "seamstress_prick display_name is Prick")
	_check(prick.get("owner") == "seamstress", "seamstress_prick owner is seamstress")
	_check(prick.get("cost") == 1, "seamstress_prick cost is 1")
	_check(prick.get("from_positions") == [1, 2, 3], "seamstress_prick from_positions")
	_check(prick.get("target_kind") == "enemy_single", "seamstress_prick target_kind")
	_check(prick.get("to_positions") == [1, 2, 3], "seamstress_prick to_positions")
	_check(prick.get("effects").get("damage") == 3, "seamstress_prick damage is 3")
	_check(prick.get("effects").get("bleed") == 2, "seamstress_prick authored bleed is 2")
	_check(prick.get("starting_copies") == 2, "seamstress_prick starting_copies is 2")
	
	# seamstress_prick_plus
	var prick_plus: Dictionary = catalog.get_definition("seamstress_prick_plus")
	_check(not prick_plus.is_empty(), "seamstress_prick_plus exists in catalog")
	_check(prick_plus.get("id") == "seamstress_prick_plus", "seamstress_prick_plus stable ID")
	_check(prick_plus.get("display_name") == "Prick+", "seamstress_prick_plus display_name is Prick+")
	_check(prick_plus.get("owner") == "seamstress", "seamstress_prick_plus owner is seamstress")
	_check(prick_plus.get("cost") == 1, "seamstress_prick_plus cost is 1")
	_check(prick_plus.get("from_positions") == [1, 2, 3], "seamstress_prick_plus from_positions")
	_check(prick_plus.get("target_kind") == "enemy_single", "seamstress_prick_plus target_kind")
	_check(prick_plus.get("to_positions") == [1, 2, 3], "seamstress_prick_plus to_positions")
	_check(prick_plus.get("effects") == {"damage": 4, "bleed": 3}, "seamstress_prick_plus exact effects")
	_check(prick_plus.get("effects").get("damage") == 4, "seamstress_prick_plus damage is 4")
	_check(prick_plus.get("effects").get("bleed") == 3, "seamstress_prick_plus authored bleed is 3")
	_check(prick_plus.get("starting_copies") == 0, "seamstress_prick_plus starting_copies is 0")
	
	# warden_shield_bash
	var shield_bash: Dictionary = catalog.get_definition("warden_shield_bash")
	_check(not shield_bash.is_empty(), "warden_shield_bash exists in catalog")
	_check(shield_bash.get("id") == "warden_shield_bash", "warden_shield_bash stable ID")
	_check(shield_bash.get("display_name") == "Shield Bash", "warden_shield_bash display_name is Shield Bash")
	_check(shield_bash.get("owner") == "warden", "warden_shield_bash owner is warden")
	_check(shield_bash.get("cost") == 2, "warden_shield_bash cost is 2")
	_check(shield_bash.get("from_positions") == [1], "warden_shield_bash from_positions")
	_check(shield_bash.get("target_kind") == "enemy_single", "warden_shield_bash target_kind")
	_check(shield_bash.get("to_positions") == [1], "warden_shield_bash to_positions")
	_check(shield_bash.get("effects").get("damage") == 8, "warden_shield_bash damage is 8")
	_check(shield_bash.get("effects").get("weak") == 1, "warden_shield_bash authored weak is 1")
	_check(shield_bash.get("starting_copies") == 1, "warden_shield_bash starting_copies is 1")
	
	# warden_shield_bash_plus
	var shield_bash_plus: Dictionary = catalog.get_definition("warden_shield_bash_plus")
	_check(not shield_bash_plus.is_empty(), "warden_shield_bash_plus exists in catalog")
	_check(shield_bash_plus.get("id") == "warden_shield_bash_plus", "warden_shield_bash_plus stable ID")
	_check(shield_bash_plus.get("display_name") == "Shield Bash+", "warden_shield_bash_plus display_name is Shield Bash+")
	_check(shield_bash_plus.get("owner") == "warden", "warden_shield_bash_plus owner is warden")
	_check(shield_bash_plus.get("cost") == 2, "warden_shield_bash_plus cost is 2")
	_check(shield_bash_plus.get("from_positions") == [1], "warden_shield_bash_plus from_positions")
	_check(shield_bash_plus.get("target_kind") == "enemy_single", "warden_shield_bash_plus target_kind")
	_check(shield_bash_plus.get("to_positions") == [1], "warden_shield_bash_plus to_positions")
	_check(shield_bash_plus.get("effects") == {"damage": 11, "weak": 1}, "warden_shield_bash_plus exact effects")
	_check(shield_bash_plus.get("effects").get("damage") == 11, "warden_shield_bash_plus damage is 11")
	_check(shield_bash_plus.get("effects").get("weak") == 1, "warden_shield_bash_plus authored weak is 1")
	_check(shield_bash_plus.get("starting_copies") == 0, "warden_shield_bash_plus starting_copies is 0")
	
	# Verify canonical upgrade pairs in RunRestCardUpgrade match StarterCards
	var prick_pair: Dictionary = RunRestCardUpgrade.STARTER_UPGRADE_PAIRS.get("seamstress_prick", {})
	_check(prick_pair.get("plus_id") == "seamstress_prick_plus"
		and prick_pair.get("owner") == "seamstress"
		and prick_pair.get("effects") == prick.get("effects")
		and prick_pair.get("plus_effects") == prick_plus.get("effects"),
		"RunRestCardUpgrade canonical pair matches Prick and Prick+")
	var bash_pair: Dictionary = RunRestCardUpgrade.STARTER_UPGRADE_PAIRS.get("warden_shield_bash", {})
	_check(bash_pair.get("plus_id") == "warden_shield_bash_plus"
		and bash_pair.get("owner") == "warden"
		and bash_pair.get("effects") == shield_bash.get("effects")
		and bash_pair.get("plus_effects") == shield_bash_plus.get("effects"),
		"RunRestCardUpgrade canonical pair matches Shield Bash and Shield Bash+")


func _test_adapter_basic_emission() -> void:
	var adapter = _get_adapter()
	var catalog_before = _deep_snapshot_catalog()
	var rng_seed = 12344
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var rng_seed_before := rng.seed
	var rng_state_before := rng.state
	
	# Seed global RNG and capture expected next draw
	seed(rng_seed)
	var expected_next = randi()
	# Reseed to same state before adapter calls
	seed(rng_seed)
	
	# Confirmed Prick hit emits bleed 3 (authored 2 + passive +1)
	var prick_result: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	_check(prick_result == {"bleed": 3}, "Prick confirmed hit emits {'bleed': 3}")
	
	# Confirmed Prick+ hit emits bleed 4 (authored 3 + passive +1)
	var prick_plus_result: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick_plus", true)
	_check(prick_plus_result == {"bleed": 4}, "Prick+ confirmed hit emits {'bleed': 4}")
	
	# Confirmed Shield Bash hit emits weak 1
	var bash_result: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	_check(bash_result == {"weak": 1}, "Shield Bash confirmed hit emits {'weak': 1}")
	
	# Confirmed Shield Bash+ hit emits weak 1 (no additional Weak invented by upgrading)
	var bash_plus_result: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash_plus", true)
	_check(bash_plus_result == {"weak": 1}, "Shield Bash+ confirmed hit emits {'weak': 1}")
	
	# Verify the adapter doesn't return damage or other fields
	_check(not prick_result.has("damage"), "Prick result has no damage field")
	_check(not prick_plus_result.has("damage"), "Prick+ result has no damage field")
	_check(not bash_result.has("damage"), "Shield Bash result has no damage field")
	_check(not bash_plus_result.has("damage"), "Shield Bash+ result has no damage field")
	_check(prick_result.size() == 1, "Prick result has exactly one key")
	_check(prick_plus_result.size() == 1, "Prick+ result has exactly one key")
	_check(bash_result.size() == 1, "Shield Bash result has exactly one key")
	_check(bash_plus_result.size() == 1, "Shield Bash+ result has exactly one key")
	
	# Verify global and instance RNG not consumed
	_check(randi() == expected_next, "Global RNG state unchanged after basic emission calls")
	_check(rng.seed == rng_seed_before and rng.state == rng_state_before,
		"Seeded RandomNumberGenerator state unchanged after basic emission calls")
	
	# Verify catalog unchanged
	var catalog_after = _deep_snapshot_catalog()
	_assert_catalog_unchanged(catalog_before, catalog_after, "adapter basic emission")


func _test_adapter_independence_and_determinism() -> void:
	var adapter = _get_adapter()
	var catalog = _get_catalog()
	
	# Repeated calls return equal but independent dictionaries for Prick
	var r1: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	var r2: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	_check(r1 == r2, "two Prick calls return equal results")
	
	# Mutate returned dictionary and verify catalog and next call are unchanged
	r1["bleed"] = 999
	r1["extra"] = 1
	var r3: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	_check(r3 == {"bleed": 3}, "mutating returned dict doesn't affect subsequent call")
	_check(r2 == {"bleed": 3}, "mutating r1 doesn't affect r2")
	
	# Verify catalog is unchanged
	var def: Dictionary = catalog.get_definition("seamstress_prick")
	_check(def.get("effects").get("bleed") == 2, "catalog bleed unchanged after adapter mutation")
	
	# Same for Prick+
	var rp1: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick_plus", true)
	var rp2: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick_plus", true)
	_check(rp1 == rp2, "two Prick+ calls return equal results")
	rp1["bleed"] = 999
	rp1["extra"] = 1
	var rp3: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick_plus", true)
	_check(rp3 == {"bleed": 4}, "mutating returned dict doesn't affect subsequent Prick+ call")
	_check(rp2 == {"bleed": 4}, "mutating rp1 doesn't affect rp2")
	var def_prick_plus: Dictionary = catalog.get_definition("seamstress_prick_plus")
	_check(def_prick_plus.get("effects") == {"damage": 4, "bleed": 3},
		"catalog Prick+ bleed unchanged after adapter mutation")
	
	# Same for Shield Bash
	var b1: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	var b2: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	_check(b1 == b2, "two Shield Bash calls return equal results")
	b1["weak"] = 999
	b1["extra"] = 1
	var b3: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	_check(b3 == {"weak": 1}, "mutating returned dict doesn't affect subsequent Shield Bash call")
	_check(b2 == {"weak": 1}, "mutating b1 doesn't affect b2")
	
	# Verify catalog is unchanged
	var def2: Dictionary = catalog.get_definition("warden_shield_bash")
	_check(def2.get("effects").get("weak") == 1, "catalog weak unchanged after adapter mutation")
	
	# Same for Shield Bash+
	var bp1: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash_plus", true)
	var bp2: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash_plus", true)
	_check(bp1 == bp2, "two Shield Bash+ calls return equal results")
	bp1["weak"] = 999
	bp1["extra"] = 1
	var bp3: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash_plus", true)
	_check(bp3 == {"weak": 1}, "mutating returned dict doesn't affect subsequent Shield Bash+ call")
	_check(bp2 == {"weak": 1}, "mutating bp1 doesn't affect bp2")
	var def_bash_plus: Dictionary = catalog.get_definition("warden_shield_bash_plus")
	_check(def_bash_plus.get("effects") == {"damage": 11, "weak": 1},
		"catalog Shield Bash+ weak unchanged after adapter mutation")


func _test_adapter_rejects_unknown_and_failed_hits() -> void:
	var adapter = _get_adapter()
	var catalog_before = _deep_snapshot_catalog()
	var rng_seed = 12345
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var rng_seed_before := rng.seed
	var rng_state_before := rng.state
	
	# Seed global RNG and capture expected next draw
	seed(rng_seed)
	var expected_next = randi()
	# Reseed to same state before adapter calls
	seed(rng_seed)
	
	# hit_confirmed=false for all four supported IDs
	_check(adapter.status_for_confirmed_hit("seamstress_prick", false) == {}, "Prick failed hit emits {}")
	_check(adapter.status_for_confirmed_hit("seamstress_prick_plus", false) == {}, "Prick+ failed hit emits {}")
	_check(adapter.status_for_confirmed_hit("warden_shield_bash", false) == {}, "Shield Bash failed hit emits {}")
	_check(adapter.status_for_confirmed_hit("warden_shield_bash_plus", false) == {}, "Shield Bash+ failed hit emits {}")
	
	# Unknown and malformed IDs with hit_confirmed=true and false
	var invalid_ids: Array[String] = [
		"nonexistent_card",
		"",
		"seamstress_prick_plus_plus",
		"warden_shield_bash_plus_plus",
		"seamstress_prick+",
		"warden_shield_bash+",
		"SEAMSTRESS_PRICK",
		"SEAMSTRESS_PRICK_PLUS",
		"WARDEN_SHIELD_BASH",
		"WARDEN_SHIELD_BASH_PLUS",
		" seamstress_prick_plus",
		"warden_shield_bash_plus "
	]
	for bad_id in invalid_ids:
		_check(adapter.status_for_confirmed_hit(bad_id, true) == {},
			"invalid/unknown ID '" + bad_id + "' with hit_confirmed=true emits {}")
		_check(adapter.status_for_confirmed_hit(bad_id, false) == {},
			"invalid/unknown ID '" + bad_id + "' with hit_confirmed=false emits {}")
	
	# Verify global and instance RNG not consumed
	_check(randi() == expected_next, "Global RNG state unchanged after failed/unknown hit calls")
	_check(rng.seed == rng_seed_before and rng.state == rng_state_before,
		"Seeded RandomNumberGenerator state unchanged after failed/unknown hit calls")
	
	# Verify catalog unchanged
	var catalog_after = _deep_snapshot_catalog()
	_assert_catalog_unchanged(catalog_before, catalog_after, "adapter rejects unknown and failed hits")


func _test_adapter_rejects_other_starter_cards() -> void:
	var adapter = _get_adapter()
	var catalog = _get_catalog()
	var catalog_before = _deep_snapshot_catalog()
	var rng_seed = 12346
	
	# Seed global RNG and capture expected next draw
	seed(rng_seed)
	var expected_next = randi()
	# Reseed to same state before adapter calls
	seed(rng_seed)
	
	# All other status-free starter card IDs (base and '+') emit {}
	var other_ids: Array[String] = [
		"warden_strike",
		"warden_strike_plus",
		"warden_brace",
		"warden_brace_plus",
		"seamstress_mend",
		"seamstress_mend_plus",
		"seamstress_stitch_up",
		"seamstress_stitch_up_plus",
		"tinker_pop_shot",
		"tinker_pop_shot_plus",
		"tinker_scrap_bomb",
		"tinker_scrap_bomb_plus",
		"tinker_tune_up",
		"tinker_tune_up_plus"
	]
	
	for card_id in other_ids:
		var def: Dictionary = catalog.get_definition(card_id)
		_check(not def.is_empty(), card_id + " exists in catalog for test")
		var result: Dictionary = adapter.status_for_confirmed_hit(card_id, true)
		_check(result == {}, card_id + " with hit_confirmed=true emits {}")
		var failed_result: Dictionary = adapter.status_for_confirmed_hit(card_id, false)
		_check(failed_result == {}, card_id + " with hit_confirmed=false emits {}")
	
	# Verify global RNG not consumed
	_check(randi() == expected_next, "Global RNG state unchanged after other starter card calls")
	
	# Verify catalog unchanged
	var catalog_after = _deep_snapshot_catalog()
	_assert_catalog_unchanged(catalog_before, catalog_after, "adapter rejects other starter cards")


func _test_emitted_payloads_work_with_combat_statuses() -> void:
	var adapter = _get_adapter()
	var rules = _get_status_rules()
	var catalog_before = _deep_snapshot_catalog()
	var rng_seed = 12347
	
	# Seed global RNG and capture expected next draw
	seed(rng_seed)
	var expected_next = randi()
	# Reseed to same state before adapter calls
	seed(rng_seed)
	
	# Test Bleed 3 (Prick): 10 HP / 7 Block -> 7/7 {bleed:2} -> 5/7 {bleed:1} -> 4/7 {}
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
	
	# Test Bleed 4 (Prick+): 15 HP / 7 Block -> 11/7 {bleed:3} -> 8/7 {bleed:2} -> 6/7 {bleed:1} -> 5/7 {}
	var bleed_plus_payload: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick_plus", true)
	_check(bleed_plus_payload == {"bleed": 4}, "Prick+ payload is bleed 4")
	var original_bleed_plus: Dictionary = bleed_plus_payload.duplicate(true)
	var p_first: Dictionary = rules.end_owner_turn(15, 7, bleed_plus_payload)
	_check(p_first == {"ok": true, "hp": 11, "block": 7, "statuses": {"bleed": 3}, "bleed_hp_loss": 4},
		"Bleed 4 on 15 HP/7 Block -> 11 HP/7 Block, bleed 3, loss 4")
	_check(bleed_plus_payload == original_bleed_plus, "end_owner_turn never mutates Prick+ input payload")
	var p_second: Dictionary = rules.end_owner_turn(p_first["hp"], p_first["block"], p_first["statuses"])
	_check(p_second == {"ok": true, "hp": 8, "block": 7, "statuses": {"bleed": 2}, "bleed_hp_loss": 3},
		"Bleed 3 on 11 HP/7 Block -> 8 HP/7 Block, bleed 2, loss 3")
	var p_third: Dictionary = rules.end_owner_turn(p_second["hp"], p_second["block"], p_second["statuses"])
	_check(p_third == {"ok": true, "hp": 6, "block": 7, "statuses": {"bleed": 1}, "bleed_hp_loss": 2},
		"Bleed 2 on 8 HP/7 Block -> 6 HP/7 Block, bleed 1, loss 2")
	var p_fourth: Dictionary = rules.end_owner_turn(p_third["hp"], p_third["block"], p_third["statuses"])
	_check(p_fourth == {"ok": true, "hp": 5, "block": 7, "statuses": {}, "bleed_hp_loss": 1},
		"Bleed 1 on 6 HP/7 Block -> 5 HP/7 Block, expired bleed, loss 1")
	var p_fifth: Dictionary = rules.end_owner_turn(p_fourth["hp"], p_fourth["block"], p_fourth["statuses"])
	_check(p_fifth == {"ok": true, "hp": 5, "block": 7, "statuses": {}, "bleed_hp_loss": 0},
		"expired Prick+ Bleed on 5 HP/7 Block -> no further loss")
	
	# Test Weak 1 (Shield Bash): 8 damage with weak -> 6, after expiry -> 8
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
	
	# Test Weak 1 (Shield Bash+): 11 damage with weak -> 8 (floor(11*3/4)=8), after 1 owner turn expires -> 11
	var weak_plus_payload: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash_plus", true)
	_check(weak_plus_payload == {"weak": 1}, "Shield Bash+ payload is weak 1")
	var original_weak_plus: Dictionary = weak_plus_payload.duplicate(true)
	var dmg_plus_with_weak: int = rules.adjusted_attack_damage(11, weak_plus_payload, {})
	_check(dmg_plus_with_weak == 8, "Shield Bash+ Weak 1 reduces 11 damage to 8")
	var after_plus_turn: Dictionary = rules.end_owner_turn(10, 0, weak_plus_payload)
	_check(after_plus_turn["statuses"].is_empty() and after_plus_turn["bleed_hp_loss"] == 0,
		"Shield Bash+ Weak 1 expires after one owner turn")
	_check(rules.adjusted_attack_damage(11, after_plus_turn["statuses"], {}) == 11,
		"damage returns to 11 after Shield Bash+ Weak expires")
	_check(weak_plus_payload == original_weak_plus, "Shield Bash+ payload unchanged after sequence")
	
	# Verify Block never absorbs Bleed (already tested above but explicit)
	var bleed_test: Dictionary = {"bleed": 3}
	var blocked: Dictionary = rules.end_owner_turn(10, 99, bleed_test)
	_check(blocked["block"] == 99, "Block unchanged by Bleed (99 stays 99)")
	_check(blocked["hp"] == 7, "HP reduced by 3 directly (10 -> 7)")
	
	# Verify global RNG not consumed
	_check(randi() == expected_next, "Global RNG state unchanged after combat statuses integration calls")
	
	# Verify catalog unchanged
	var catalog_after = _deep_snapshot_catalog()
	_assert_catalog_unchanged(catalog_before, catalog_after, "emitted payloads with combat statuses")


func _test_replay_and_snapshots() -> void:
	var adapter = _get_adapter()
	var rules = _get_status_rules()
	var catalog_before = _deep_snapshot_catalog()
	var rng_seed = 12348
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var rng_seed_before := rng.seed
	var rng_state_before := rng.state
	
	# Seed global RNG and capture expected next draw
	seed(rng_seed)
	var expected_next = randi()
	# Reseed to same state before adapter calls
	seed(rng_seed)
	
	# Repeated identical inputs reproduce same results
	var prick_payload: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
	var prick_plus_payload: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick_plus", true)
	var bash_payload: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
	var bash_plus_payload: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash_plus", true)
	_check(prick_payload == {"bleed": 3} and prick_plus_payload == {"bleed": 4}
		and bash_payload == {"weak": 1} and bash_plus_payload == {"weak": 1},
		"all four supported printings emit expected initial payloads")
	
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
	
	# Adapter repeated calls are deterministic for all four printings
	for i in range(10):
		var p: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick", true)
		var pp: Dictionary = adapter.status_for_confirmed_hit("seamstress_prick_plus", true)
		var b_: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash", true)
		var bp: Dictionary = adapter.status_for_confirmed_hit("warden_shield_bash_plus", true)
		_check(p == {"bleed": 3}, "Prick deterministic call " + str(i))
		_check(pp == {"bleed": 4}, "Prick+ deterministic call " + str(i))
		_check(b_ == {"weak": 1}, "Shield Bash deterministic call " + str(i))
		_check(bp == {"weak": 1}, "Shield Bash+ deterministic call " + str(i))
	
	# Verify global and instance RNG not consumed
	_check(randi() == expected_next, "Global RNG state unchanged after replay and snapshot calls")
	_check(rng.seed == rng_seed_before and rng.state == rng_state_before,
		"Seeded RandomNumberGenerator state unchanged after replay and snapshot calls")
	
	# Verify catalog unchanged
	var catalog_after = _deep_snapshot_catalog()
	_assert_catalog_unchanged(catalog_before, catalog_after, "replay and snapshots")
