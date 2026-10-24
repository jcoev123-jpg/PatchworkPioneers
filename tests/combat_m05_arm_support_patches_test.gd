extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_definitions_and_schema()
	_test_active_wearer_card_support_bonuses()
	_test_negative_cross_owner_torn_and_resew_transfer()
	_test_immutability_detachment_and_m04_coexistence()

	if failures.is_empty():
		print("combat_m05_arm_support_patches_test: PASS (", checks, " checks)")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("combat_m05_arm_support_patches_test: FAIL (", failures.size(), " failures)")
		quit(1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _json(path: String) -> Variant:
	var source := FileAccess.get_file_as_string(path)
	_check(not source.is_empty(), path + " is readable")
	return JSON.parse_string(source)


func _starter_heroes_fixture() -> Array:
	var raw_heroes: Variant = _json("res://data/heroes/starter_party.json")
	_check(typeof(raw_heroes) == TYPE_ARRAY and raw_heroes.size() == 3,
		"starter_party.json parses as 3-hero array")
	if typeof(raw_heroes) != TYPE_ARRAY:
		return []
	var party_defs: Array = []
	for entry: Variant in raw_heroes:
		if typeof(entry) == TYPE_DICTIONARY:
			party_defs.append({
				"id": str(entry.get("id", "")),
				"max_hp": int(entry.get("max_hp", 0)),
				"art_path": str(entry.get("art_path", ""))
			})
	var party := CombatParty.new(party_defs)
	_check(party.is_valid(), "CombatParty accepts starter definitions")
	return party.get_heroes()


func _test_catalog_definitions_and_schema() -> void:
	# AC1: Check new JSON read as authored M05 catalog.
	var path := "res://data/patches/m05_arm_support_patches.json"
	var raw: Variant = _json(path)
	_check(typeof(raw) == TYPE_ARRAY, "m05_arm_support_patches.json is a JSON array")
	if typeof(raw) != TYPE_ARRAY:
		return

	var expected_records := {
		"hemguard_cuff": {"slot": "ARM", "effect": "card_block_bonus", "amount": 2},
		"red_bobbin_cuff": {"slot": "ARM", "effect": "card_bleed_bonus", "amount": 1},
		"loose_thread_glove": {"slot": "ARM", "effect": "card_unravel_bonus", "amount": 1}
	}

	var seen_ids := {}
	for entry: Variant in raw:
		_check(typeof(entry) == TYPE_DICTIONARY, "patch entry is a dictionary")
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: Variant = entry.get("id")
		_check(typeof(id) == TYPE_STRING and not id.is_empty(), "entry has non-empty string id")
		if not expected_records.has(id):
			continue
		_check(not seen_ids.has(id), "exact one record for id " + str(id))
		seen_ids[id] = true
		var exp: Dictionary = expected_records[id]
		_check(entry.get("slot") == exp["slot"], str(id) + " slot is " + exp["slot"])
		_check(entry.get("effect") == exp["effect"], str(id) + " effect is " + exp["effect"])
		_check(int(entry.get("amount", 0)) == exp["amount"], str(id) + " amount is " + str(exp["amount"]))

	for exp_id: String in expected_records:
		_check(seen_ids.has(exp_id), "authored catalog contains record for " + exp_id)

	# Verify M04 catalog is intact.
	var m04_raw: Variant = _json("res://data/patches/m04_attack_patches.json")
	_check(typeof(m04_raw) == TYPE_ARRAY, "m04_attack_patches.json parses; required IDs checked below")
	var m04_seen := {}
	for entry: Variant in m04_raw:
		if typeof(entry) == TYPE_DICTIONARY:
			m04_seen[entry.get("id")] = entry
	_check(m04_seen.has("button_eye") and m04_seen["button_eye"].get("slot") == "HEAD", "button_eye intact in M04")
	_check(m04_seen.has("pincushion_arm") and m04_seen["pincushion_arm"].get("slot") == "ARM", "pincushion_arm intact in M04")

	# Validate fail-closed catalog validator CombatPatchAttackRules._valid_support_catalog
	_check(CombatPatchAttackRules._valid_support_catalog(raw), "_valid_support_catalog accepts authored catalog")
	_check(not CombatPatchAttackRules._valid_support_catalog(null), "_valid_support_catalog rejects null")
	_check(not CombatPatchAttackRules._valid_support_catalog({}), "_valid_support_catalog rejects dictionary")
	_check(not CombatPatchAttackRules._valid_support_catalog([]), "_valid_support_catalog rejects empty array lacking required IDs")

	# Wrong slot fixture
	var bad_slot: Array = [
		{"id": "hemguard_cuff", "slot": "HEAD", "effect": "card_block_bonus", "amount": 2},
		{"id": "red_bobbin_cuff", "slot": "ARM", "effect": "card_bleed_bonus", "amount": 1},
		{"id": "loose_thread_glove", "slot": "ARM", "effect": "card_unravel_bonus", "amount": 1}
	]
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_slot), "_valid_support_catalog rejects wrong slot")

	# Wrong amount fixture
	var bad_amount: Array = [
		{"id": "hemguard_cuff", "slot": "ARM", "effect": "card_block_bonus", "amount": 5},
		{"id": "red_bobbin_cuff", "slot": "ARM", "effect": "card_bleed_bonus", "amount": 1},
		{"id": "loose_thread_glove", "slot": "ARM", "effect": "card_unravel_bonus", "amount": 1}
	]
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_amount), "_valid_support_catalog rejects wrong amount")

	# Duplicate ID fixture
	var bad_dup: Array = [
		{"id": "hemguard_cuff", "slot": "ARM", "effect": "card_block_bonus", "amount": 2},
		{"id": "hemguard_cuff", "slot": "ARM", "effect": "card_block_bonus", "amount": 2},
		{"id": "red_bobbin_cuff", "slot": "ARM", "effect": "card_bleed_bonus", "amount": 1},
		{"id": "loose_thread_glove", "slot": "ARM", "effect": "card_unravel_bonus", "amount": 1}
	]
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_dup), "_valid_support_catalog rejects duplicate required ID")


func _test_active_wearer_card_support_bonuses() -> void:
	# AC2: Valid roster, genuine RunPatchWardrobe with ARM patches sewn to living card owner.
	var heroes := _starter_heroes_fixture()
	var torn := RunTornMending.new(heroes)
	var defs := [
		{"id": "button_eye", "slot": "HEAD"},
		{"id": "hemguard_cuff", "slot": "ARM"},
		{"id": "red_bobbin_cuff", "slot": "ARM"},
		{"id": "loose_thread_glove", "slot": "ARM"}
	]
	var owned := ["button_eye", "hemguard_cuff", "red_bobbin_cuff", "loose_thread_glove"]
	var cards := ["warden_brace", "seamstress_prick", "tinker_spool_launcher"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, 5, 100, cards, 12345)
	_check(wardrobe.is_valid(), "RunPatchWardrobe is valid")

	# Sew hemguard_cuff to Warden's ARM
	var snap := wardrobe.get_snapshot()
	var sew1 := wardrobe.sew("hemguard_cuff", "warden", "ARM", "op-sew-warden-arm", snap)
	_check(sew1.get("ok") == true, "sew hemguard_cuff to warden succeeded")

	# Sew red_bobbin_cuff to Seamstress's ARM
	snap = wardrobe.get_snapshot()
	var sew2 := wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "op-sew-seamstress-arm", snap)
	_check(sew2.get("ok") == true, "sew red_bobbin_cuff to seamstress succeeded")

	# Sew loose_thread_glove to Tinker's ARM
	snap = wardrobe.get_snapshot()
	var sew3 := wardrobe.sew("loose_thread_glove", "tinker", "ARM", "op-sew-tinker-arm", snap)
	_check(sew3.get("ok") == true, "sew loose_thread_glove to tinker succeeded")

	# Sew button_eye to Warden's HEAD (M04 coexistence)
	snap = wardrobe.get_snapshot()
	var sew4 := wardrobe.sew("button_eye", "warden", "HEAD", "op-sew-warden-head", snap)
	_check(sew4.get("ok") == true, "sew button_eye to warden succeeded")

	var rules := CombatPatchAttackRules.new()
	var bound := rules.bind_wardrobe(wardrobe, torn)
	_check(bound and rules.is_valid(), "CombatPatchAttackRules bound successfully")

	# --- Warden: hemguard_cuff (+2 Block to printed positive block) ---
	var starter := StarterCards.new()
	var brace_def := starter.get_definition("warden_brace")
	_check(brace_def.get("effects", {}).get("block") == 7, "printed warden_brace Block is 7")
	var warden_brace_bonus := rules.card_support_bonuses("warden", "warden_brace")
	_check(warden_brace_bonus == {"block": 2, "bleed": 0, "unravel": 0},
		"warden_brace grants exactly block: 2 bonus")
	var projected_brace := rules.project_card_support("warden", "warden_brace")
	_check(projected_brace.get("block") == 9, "warden_brace projected Block 7 -> 9")

	var brace_plus_def := starter.get_definition("warden_brace_plus")
	_check(brace_plus_def.get("effects", {}).get("block") == 10, "printed warden_brace_plus Block is 10")
	var warden_brace_plus_bonus := rules.card_support_bonuses("warden", "warden_brace_plus")
	_check(warden_brace_plus_bonus == {"block": 2, "bleed": 0, "unravel": 0},
		"warden_brace_plus grants exactly block: 2 bonus")
	var projected_brace_plus := rules.project_card_support("warden", "warden_brace_plus")
	_check(projected_brace_plus.get("block") == 12, "warden_brace_plus projected Block 10 -> 12")

	# Warden pool block card
	var warden_pool := WardenPoolCards.new()
	var hold_line_def := warden_pool.get_definition("warden_hold_the_line")
	_check(hold_line_def.get("effects", {}).get("block") == 5, "printed warden_hold_the_line Block is 5")
	var hold_bonus := rules.card_support_bonuses("warden", "warden_hold_the_line")
	_check(hold_bonus == {"block": 2, "bleed": 0, "unravel": 0}, "warden_hold_the_line grants block: 2")
	_check(rules.project_card_support("warden", "warden_hold_the_line").get("block") == 7,
		"warden_hold_the_line projected Block 5 -> 7")

	var hold_plus_def := warden_pool.get_definition("warden_hold_the_line_plus")
	_check(hold_plus_def.get("effects", {}).get("block") == 7, "printed warden_hold_the_line_plus Block is 7")
	_check(rules.card_support_bonuses("warden", "warden_hold_the_line_plus") == {"block": 2, "bleed": 0, "unravel": 0},
		"warden_hold_the_line_plus grants block: 2")
	_check(rules.project_card_support("warden", "warden_hold_the_line_plus").get("block") == 9,
		"warden_hold_the_line_plus projected Block 7 -> 9")

	# Warden non-block card yields zeros
	var strike_bonus := rules.card_support_bonuses("warden", "warden_strike")
	_check(strike_bonus == {"block": 0, "bleed": 0, "unravel": 0}, "warden_strike gives 0 support bonus")

	# --- Seamstress: red_bobbin_cuff (+1 Bleed to printed positive bleed) ---
	var prick_def := starter.get_definition("seamstress_prick")
	_check(prick_def.get("effects", {}).get("bleed") == 2, "printed seamstress_prick Bleed is 2")
	var prick_bonus := rules.card_support_bonuses("seamstress", "seamstress_prick")
	_check(prick_bonus == {"block": 0, "bleed": 1, "unravel": 0},
		"seamstress_prick grants exactly bleed: 1 bonus")
	var projected_prick := rules.project_card_support("seamstress", "seamstress_prick")
	_check(projected_prick.get("bleed") == 3, "seamstress_prick projected Bleed 2 -> 3 before passive")

	var seamstress_pool := SeamstressPoolCards.new()
	var running_def := seamstress_pool.get_definition("seamstress_running_stitch")
	_check(running_def.get("effects", {}).get("bleed") == 3, "printed seamstress_running_stitch Bleed is 3")
	var running_bonus := rules.card_support_bonuses("seamstress", "seamstress_running_stitch")
	_check(running_bonus == {"block": 0, "bleed": 1, "unravel": 0},
		"seamstress_running_stitch grants exactly bleed: 1 bonus")
	var projected_running := rules.project_card_support("seamstress", "seamstress_running_stitch")
	_check(projected_running.get("bleed") == 4, "seamstress_running_stitch projected Bleed 3 -> 4")

	var running_plus_def := seamstress_pool.get_definition("seamstress_running_stitch_plus")
	_check(running_plus_def.get("effects", {}).get("bleed") == 4, "printed seamstress_running_stitch_plus Bleed is 4")
	var running_plus_bonus := rules.card_support_bonuses("seamstress", "seamstress_running_stitch_plus")
	_check(running_plus_bonus == {"block": 0, "bleed": 1, "unravel": 0},
		"seamstress_running_stitch_plus grants exactly bleed: 1 bonus")
	_check(rules.project_card_support("seamstress", "seamstress_running_stitch_plus").get("bleed") == 5,
		"seamstress_running_stitch_plus projected Bleed 4 -> 5")

	# Seamstress non-bleed card yields zeros
	var mend_bonus := rules.card_support_bonuses("seamstress", "seamstress_mend")
	_check(mend_bonus == {"block": 0, "bleed": 0, "unravel": 0}, "seamstress_mend gives 0 support bonus")

	# --- Tinker: loose_thread_glove (+1 Unravel to printed positive unravel) ---
	var tinker_pool := TinkerPoolCards.new()
	var spool_def := tinker_pool.get_definition("tinker_spool_launcher")
	_check(spool_def.get("effects", {}).get("unravel") == 3, "printed tinker_spool_launcher Unravel is 3")
	var spool_bonus := rules.card_support_bonuses("tinker", "tinker_spool_launcher")
	_check(spool_bonus == {"block": 0, "bleed": 0, "unravel": 1},
		"tinker_spool_launcher grants exactly unravel: 1 bonus")
	var projected_spool := rules.project_card_support("tinker", "tinker_spool_launcher")
	_check(projected_spool.get("unravel") == 4, "tinker_spool_launcher projected Unravel 3 -> 4")

	var spool_plus_def := tinker_pool.get_definition("tinker_spool_launcher_plus")
	_check(spool_plus_def.get("effects", {}).get("unravel") == 4, "printed tinker_spool_launcher_plus Unravel is 4")
	var spool_plus_bonus := rules.card_support_bonuses("tinker", "tinker_spool_launcher_plus")
	_check(spool_plus_bonus == {"block": 0, "bleed": 0, "unravel": 1},
		"tinker_spool_launcher_plus grants exactly unravel: 1 bonus")
	var projected_spool_plus := rules.project_card_support("tinker", "tinker_spool_launcher_plus")
	_check(projected_spool_plus.get("unravel") == 5, "tinker_spool_launcher_plus projected Unravel 4 -> 5")

	# Tinker non-unravel card yields zeros
	var pop_bonus := rules.card_support_bonuses("tinker", "tinker_pop_shot")
	_check(pop_bonus == {"block": 0, "bleed": 0, "unravel": 0}, "tinker_pop_shot gives 0 support bonus")


func _test_negative_cross_owner_torn_and_resew_transfer() -> void:
	# AC3: Cross-owner, unowned, torn wearer, invalid bind, bleed_multiplier refusal, rest re-sew transfer.
	var heroes := _starter_heroes_fixture()
	var torn := RunTornMending.new(heroes)
	var defs := [
		{"id": "hemguard_cuff", "slot": "ARM"},
		{"id": "red_bobbin_cuff", "slot": "ARM"}
	]
	var owned := ["hemguard_cuff", "red_bobbin_cuff"]
	var cards := ["warden_brace", "seamstress_prick", "seamstress_darning", "seamstress_hemorrhage_hem"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, 3, 50, cards, 999)

	var snap := wardrobe.get_snapshot()
	var sew_w := wardrobe.sew("hemguard_cuff", "warden", "ARM", "op-sew-w", snap)
	_check(sew_w.get("ok") == true, "sew hemguard_cuff to warden")

	snap = wardrobe.get_snapshot()
	var sew_s := wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "op-sew-s", snap)
	_check(sew_s.get("ok") == true, "sew red_bobbin_cuff to seamstress")

	var rules := CombatPatchAttackRules.new()
	_check(rules.bind_wardrobe(wardrobe, torn), "rules bound successfully")

	# 1. Cross-owner refusal:
	_check(rules.card_support_bonuses("warden", "seamstress_prick") == {"block": 0, "bleed": 0, "unravel": 0},
		"cross-owner card seamstress_prick played by warden grants no bonus")
	_check(rules.card_support_bonuses("seamstress", "warden_brace") == {"block": 0, "bleed": 0, "unravel": 0},
		"cross-owner card warden_brace played by seamstress grants no bonus")
	_check(rules.card_support_bonuses("tinker", "warden_brace") == {"block": 0, "bleed": 0, "unravel": 0},
		"unworn tinker playing warden_brace grants no bonus")

	# 2. Applying a card to a different hero does not transfer wearer eligibility:
	# Seamstress plays seamstress_darning (ally_single heal/block) - Seamstress owns it, wears red_bobbin_cuff.
	# Warden wears hemguard_cuff, but Seamstress is the card owner playing it.
	_check(rules.card_support_bonuses("seamstress", "seamstress_darning") == {"block": 0, "bleed": 0, "unravel": 0},
		"seamstress_darning played on ally does not receive Warden's cuff block bonus")

	# 3. Multiplicative bleed does NOT get bleed bonus:
	_check(rules.card_support_bonuses("seamstress", "seamstress_hemorrhage_hem") == {"block": 0, "bleed": 0, "unravel": 0},
		"seamstress_hemorrhage_hem (bleed_multiplier) receives no flat bleed bonus")

	# 4. Unknown / fabricated / malformed inputs:
	_check(rules.card_support_bonuses("warden", "unknown_card_id") == {"block": 0, "bleed": 0, "unravel": 0},
		"unknown card ID returns zero bonus")
	_check(rules.card_support_bonuses("warden", {"id": "warden_brace", "effects": {"block": 7}}) == {"block": 0, "bleed": 0, "unravel": 0},
		"fabricated card dictionary returns zero bonus")
	_check(rules.card_support_bonuses("nonexistent_hero", "warden_brace") == {"block": 0, "bleed": 0, "unravel": 0},
		"unknown owner returns zero bonus")
	_check(rules.card_support_bonuses(null, "warden_brace") == {"block": 0, "bleed": 0, "unravel": 0},
		"null owner returns zero bonus")
	_check(rules.card_support_bonuses("warden", null) == {"block": 0, "bleed": 0, "unravel": 0},
		"null card returns zero bonus")

	# 5. Unbound rules object:
	var unbound := CombatPatchAttackRules.new()
	_check(not unbound.is_valid(), "fresh rules is not valid")
	_check(unbound.card_support_bonuses("warden", "warden_brace") == {"block": 0, "bleed": 0, "unravel": 0},
		"unbound rules returns zero bonus")

	# 6. Invalid bind due to wrong slot definition:
	var bad_wardrobe := RunPatchWardrobe.new(heroes, ["hemguard_cuff"],
		[{"id": "hemguard_cuff", "slot": "HEAD"}], 3, 50, cards, 999)
	var bad_rules := CombatPatchAttackRules.new()
	_check(not bad_rules.bind_wardrobe(bad_wardrobe, torn), "wardrobe with wrong slot definition fails bind")
	_check(not bad_rules.is_valid(), "bad_rules remains invalid")
	_check(bad_rules.card_support_bonuses("warden", "warden_brace") == {"block": 0, "bleed": 0, "unravel": 0},
		"invalidly bound rules returns zero bonus")

	# 7. Torn wearer at 0 HP suppresses bonus:
	var battle_start := heroes.duplicate(true)
	var battle_end := heroes.duplicate(true)
	battle_end[0]["hp"] = 0 # Warden drops to 0 HP (torn)
	var obs := torn.observe_battle_end("battle-node-1", battle_start, battle_end)
	_check(obs.get("ok") == true, "battle end observed: Warden torn")

	var torn_rules := CombatPatchAttackRules.new()
	_check(torn_rules.bind_wardrobe(wardrobe, torn), "torn_rules bound")
	_check(torn_rules.card_support_bonuses("warden", "warden_brace") == {"block": 0, "bleed": 0, "unravel": 0},
		"torn Warden at 0 HP receives NO block bonus from hemguard_cuff")
	# Living Seamstress still receives her bonus:
	_check(torn_rules.card_support_bonuses("seamstress", "seamstress_prick") == {"block": 0, "bleed": 1, "unravel": 0},
		"living Seamstress still receives bleed bonus while Warden is torn")

	# Mend Warden back to life:
	var mend := torn.choose_mend("mend-node-1", "mend-rec-1", "warden", 1, 3, torn.read_state().heroes, true)
	_check(mend.get("ok") == true, "Warden mended to positive HP")
	var mended_rules := CombatPatchAttackRules.new()
	_check(mended_rules.bind_wardrobe(wardrobe, torn), "mended_rules bound")
	_check(mended_rules.card_support_bonuses("warden", "warden_brace") == {"block": 2, "bleed": 0, "unravel": 0},
		"mended living Warden once again receives block bonus")

	# 8. Rest re-sew transfer:
	snap = wardrobe.get_snapshot()
	var r_start := wardrobe.start_rest("rest-node-1", snap)
	_check(r_start.get("ok") == true, "rest started")

	var scraps_before: int = wardrobe.get_snapshot()["scraps"]
	snap = wardrobe.get_snapshot()
	# Re-sew hemguard_cuff from warden to seamstress (exchanges red_bobbin_cuff onto warden)
	var resew := wardrobe.re_sew("hemguard_cuff", "warden", "seamstress", "rest-node-1", "op-resew-1", snap)
	_check(resew.get("ok") == true, "re-sew hemguard_cuff from warden to seamstress succeeded")
	var scraps_after: int = wardrobe.get_snapshot()["scraps"]
	_check(scraps_after == scraps_before - 1, "re-sew cost exactly 1 scrap")

	snap = wardrobe.get_snapshot()
	var r_end := wardrobe.end_rest("rest-node-1", snap)
	_check(r_end.get("ok") == true, "rest ended")

	# Stale projection on old rules object before rebind:
	# (mended_rules still holds the old snapshot where Warden wore hemguard_cuff)
	_check(mended_rules.card_support_bonuses("seamstress", "seamstress_darning") == {"block": 0, "bleed": 0, "unravel": 0},
		"stale rules before rebind does not give seamstress block bonus")

	# After rebinding with fresh wardrobe snapshot:
	var rebound_rules := CombatPatchAttackRules.new()
	_check(rebound_rules.bind_wardrobe(wardrobe, torn), "rebound_rules bound")
	# Now Seamstress wears hemguard_cuff in ARM:
	_check(rebound_rules.card_support_bonuses("seamstress", "seamstress_darning") == {"block": 2, "bleed": 0, "unravel": 0},
		"after re-sew transfer, Seamstress receives block: 2 bonus on seamstress_darning")
	# Warden now has red_bobbin_cuff (exchanged), so no block bonus on warden_brace:
	_check(rebound_rules.card_support_bonuses("warden", "warden_brace") == {"block": 0, "bleed": 0, "unravel": 0},
		"former wearer Warden no longer receives block bonus on warden_brace")


func _test_immutability_detachment_and_m04_coexistence() -> void:
	# AC4: Queries are detached, deterministic, do not mutate state, and preserve M04 Exposed and Pincushion Arm.
	var heroes := _starter_heroes_fixture()
	var torn := RunTornMending.new(heroes)
	var defs := [
		{"id": "button_eye", "slot": "HEAD"},
		{"id": "pincushion_arm", "slot": "ARM"},
		{"id": "hemguard_cuff", "slot": "ARM"}
	]
	var owned := ["button_eye", "pincushion_arm", "hemguard_cuff"]
	var cards := ["warden_brace", "warden_strike"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, 4, 100, cards, 54321)

	var snap := wardrobe.get_snapshot()
	wardrobe.sew("button_eye", "warden", "HEAD", "op-b-eye", snap)
	snap = wardrobe.get_snapshot()
	wardrobe.sew("pincushion_arm", "seamstress", "ARM", "op-pin-arm", snap)
	snap = wardrobe.get_snapshot()
	wardrobe.sew("hemguard_cuff", "warden", "ARM", "op-hem-cuff", snap)

	var rules := CombatPatchAttackRules.new()
	_check(rules.bind_wardrobe(wardrobe, torn), "rules bound")

	# Detached result verification:
	var bonus1 := rules.card_support_bonuses("warden", "warden_brace")
	_check(bonus1 == {"block": 2, "bleed": 0, "unravel": 0}, "initial bonus query")
	bonus1["block"] = 9999
	bonus1["bleed"] = 8888
	bonus1["injected_key"] = true

	var bonus2 := rules.card_support_bonuses("warden", "warden_brace")
	_check(bonus2 == {"block": 2, "bleed": 0, "unravel": 0}, "second query completely isolated from mutation")
	_check(not bonus2.has("injected_key"), "no injected keys persisted")

	# Snapshot stability across 20 repeated queries:
	var wardrobe_snap_before := wardrobe.get_snapshot()
	var torn_snap_before := torn.read_state()
	var latch_before := rules.latch_snapshot()
	var active_before := rules.active_snapshot()

	var rng := RandomNumberGenerator.new()
	rng.seed = 987654
	var rng_state_before := rng.state

	for i in range(20):
		rules.card_support_bonuses("warden", "warden_brace")
		rules.card_support_bonuses("warden", "warden_strike")
		rules.card_support_bonuses("seamstress", "seamstress_prick")
		rules.card_support_bonuses("tinker", "tinker_spool_launcher")
		rules.card_block_bonus("warden", "warden_brace")
		rules.project_card_support("warden", "warden_brace")

	_check(wardrobe.get_snapshot() == wardrobe_snap_before, "wardrobe snapshot unchanged after repeated queries")
	_check(torn.read_state() == torn_snap_before, "torn state unchanged after repeated queries")
	_check(rules.latch_snapshot() == latch_before, "latch snapshot unchanged after repeated queries")
	_check(rules.active_snapshot() == active_before, "active snapshot unchanged after repeated queries")
	_check(rng.state == rng_state_before, "RNG state untouched after repeated queries")

	# M04 powers coexistence:
	# Warden has button_eye in HEAD:
	_check(rules.exposed_for_first_hit("warden") == {"exposed": 1}, "button_eye grants Exposed 1 on first hit")
	# Preview queries must not consume button_eye latch:
	rules.card_support_bonuses("warden", "warden_brace")
	_check(rules.exposed_for_first_hit("warden") == {"exposed": 1},
		"preview query does not consume button_eye once-only latch")
	# Confirming attack consumes latch:
	rules.record_successful_attack("warden")
	_check(rules.exposed_for_first_hit("warden") == {},
		"record_successful_attack consumes button_eye latch")
	# But support bonus remains active:
	_check(rules.card_support_bonuses("warden", "warden_brace") == {"block": 2, "bleed": 0, "unravel": 0},
		"support bonus still fully functional after button_eye latch consumed")

	# Seamstress has pincushion_arm in ARM:
	_check(rules.damage_bonus("seamstress") == 1, "pincushion_arm grants damage_bonus 1 to seamstress")
	_check(rules.damage_bonus("warden") == 0, "warden does not have pincushion_arm")
	_check(rules.card_support_bonuses("seamstress", "seamstress_prick") == {"block": 0, "bleed": 0, "unravel": 0},
		"seamstress wearing pincushion_arm does not have bleed support bonus")
