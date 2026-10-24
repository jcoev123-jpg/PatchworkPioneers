extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_definitions_and_schema()
	_test_active_wearer_card_support_bonuses()
	_test_negative_cross_owner_torn_and_resew_transfer()
	_test_immutability_detachment_and_m04_coexistence()
	_test_threadguard_wearer_block_bonus()
	_test_threadguard_scope_torn_resew_and_legacy_arms()

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
		"loose_thread_glove": {"slot": "ARM", "effect": "card_unravel_bonus", "amount": 1},
		"threadguard_wrap": {"slot": "ARM", "effect": "card_block_bonus", "amount": 1}
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

	# Threadguard Wrap is the smaller Block patch, never a copy of Hemguard Cuff.
	_check(int(_find_record(raw, "threadguard_wrap").get("amount", 0)) == 1,
		"threadguard_wrap authors exactly +1 Block")
	_check(int(_find_record(raw, "hemguard_cuff").get("amount", 0)) == 2,
		"hemguard_cuff keeps its authored +2 Block")

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

	# Every malformed fixture starts from the shipped records and breaks exactly
	# one authored field, so each rejection isolates its own defect.
	var bad_slot: Array = _with_patch_field(raw, "threadguard_wrap", "slot", "HEAD")
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_slot),
		"_valid_support_catalog rejects threadguard_wrap outside ARM")

	var bad_amount: Array = _with_patch_field(raw, "threadguard_wrap", "amount", 2)
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_amount),
		"_valid_support_catalog rejects threadguard_wrap at Hemguard Cuff's +2")

	var bad_effect: Array = _with_patch_field(raw, "threadguard_wrap", "effect", "card_bleed_bonus")
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_effect),
		"_valid_support_catalog rejects a threadguard_wrap authored as another effect")

	var missing_new: Array = _without_patch(raw, "threadguard_wrap")
	_check(not CombatPatchAttackRules._valid_support_catalog(missing_new),
		"_valid_support_catalog requires the shipped threadguard_wrap record")

	var bad_legacy_slot: Array = _with_patch_field(raw, "hemguard_cuff", "slot", "HEAD")
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_legacy_slot),
		"_valid_support_catalog rejects wrong slot")

	var bad_legacy_amount: Array = _with_patch_field(raw, "hemguard_cuff", "amount", 5)
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_legacy_amount),
		"_valid_support_catalog rejects wrong amount")

	var bad_dup: Array = raw.duplicate(true)
	bad_dup.append(_find_record(raw, "threadguard_wrap"))
	_check(not CombatPatchAttackRules._valid_support_catalog(bad_dup),
		"_valid_support_catalog rejects duplicate required ID")

	# A later lane may append a new M05 ARM identity before this resolver knows
	# it; that must stay tolerated instead of failing every battle bind.
	var later_record: Array = raw.duplicate(true)
	later_record.append({"id": "future_m05_arm", "slot": "ARM",
		"effect": "card_block_bonus", "amount": 3})
	_check(CombatPatchAttackRules._valid_support_catalog(later_record),
		"_valid_support_catalog tolerates a later unknown ARM record")


func _find_record(records: Array, patch_id: String) -> Dictionary:
	for entry: Variant in records:
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == patch_id:
			return entry
	return {}


func _with_patch_field(records: Array, patch_id: String, field: String, value: Variant) -> Array:
	var copy: Array = records.duplicate(true)
	for entry: Variant in copy:
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == patch_id:
			entry[field] = value
	return copy


func _without_patch(records: Array, patch_id: String) -> Array:
	var kept := []
	for entry: Variant in records:
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == patch_id:
			continue
		kept.append(entry)
	return kept


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


## Genuine starter-roster ledgers (real RunPatchWardrobe + RunTornMending) that
## own the shipped Threadguard Wrap and every older M05 ARM support patch.
func _threadguard_ledgers(scraps: int = 4) -> Dictionary:
	var heroes := _starter_heroes_fixture()
	var torn := RunTornMending.new(heroes)
	var defs := [
		{"id": "threadguard_wrap", "slot": "ARM"},
		{"id": "hemguard_cuff", "slot": "ARM"},
		{"id": "red_bobbin_cuff", "slot": "ARM"},
		{"id": "loose_thread_glove", "slot": "ARM"},
		{"id": "button_eye", "slot": "HEAD"}
	]
	var owned := ["threadguard_wrap", "hemguard_cuff", "red_bobbin_cuff",
		"loose_thread_glove", "button_eye"]
	var cards := ["warden_brace", "warden_strike", "seamstress_stitch_up",
		"seamstress_prick", "tinker_spool_launcher"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, scraps, 100, cards, 24601)
	_check(wardrobe.is_valid() and torn.is_valid(),
		"threadguard fixture uses genuine wardrobe and torn ledgers")
	_check(wardrobe.get_snapshot().get("heroes") == torn.read_state().get("heroes"),
		"threadguard fixture ledgers share one hero authority")
	return {"wardrobe": wardrobe, "torn": torn, "heroes": heroes}


## Sews threadguard_wrap onto one living wearer and binds a fresh resolver.
func _threadguard_rules(wearer: String) -> Dictionary:
	var ctx := _threadguard_ledgers()
	var wardrobe: RunPatchWardrobe = ctx["wardrobe"]
	var torn: RunTornMending = ctx["torn"]
	var sewn := wardrobe.sew("threadguard_wrap", wearer, "ARM",
		"op-threadguard-" + wearer, wardrobe.get_snapshot())
	_check(sewn.get("ok") == true, "sew threadguard_wrap to " + wearer + " ARM")
	var rules := CombatPatchAttackRules.new()
	_check(rules.bind_wardrobe(wardrobe, torn), "threadguard rules bound over the real ledgers")
	ctx["rules"] = rules
	return ctx


## Plays one authored support card through the real shared deck and party with
## the patch resolver bound to the same wearer ledgers.
func _play_threadguard_card(ctx: Dictionary, card_id: String, effect: String,
		amount: int, target_position: int, recipient_position: int,
		owner_position: int, expected_block: int, label: String) -> void:
	var wardrobe: RunPatchWardrobe = ctx["wardrobe"]
	var torn: RunTornMending = ctx["torn"]
	var party := CombatParty.new(ctx["heroes"])
	_check(party.is_valid(), label + ": genuine combat party")
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# Exactly five cards means start_turn deals the whole deck: the authored card
	# is genuinely held exactly once, so a discard is unambiguous.
	var cards: Array[String] = [card_id, "filler_a", "filler_b", "filler_c", "filler_d"]
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.hand.count(card_id) == 1,
		label + ": genuine shared turn holding exactly one copy")
	var support := CombatSupportCards.new()
	_check(support.bind_patch_wardrobe(wardrobe, torn),
		label + ": CombatSupportCards bound to the wearer ledgers")
	_check(support.is_patch_binding_valid(), label + ": bound wearer authorities are current")
	var authored := StarterCards.new().get_definition(card_id)
	var definition := {
		"id": card_id,
		"owner_id": authored.get("owner"),
		"cost": authored.get("cost"),
		"from_positions": authored.get("from_positions"),
		"effect": effect,
		"amount": amount
	}
	var hp_before: Array = party.get_heroes()
	_check(support.play_support(deck, party, definition, target_position),
		label + ": authored support card resolved")
	_check(party.get_hero(recipient_position)["block"] == expected_block,
		label + ": Block lands as " + str(expected_block) + " on the real recipient")
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		if position == recipient_position:
			continue
		_check(party.get_hero(position)["block"] == 0,
			label + ": position " + str(position) + " gains no Block")
	if recipient_position != owner_position:
		_check(party.get_hero(owner_position)["block"] == 0,
			label + ": the wearer gains no automatic Block of their own")
	_check(party.get_hero(recipient_position)["hp"] == hp_before[recipient_position - 1]["hp"],
		label + ": no HP mutation")
	_check(deck.energy == 3 - int(authored.get("cost"))
		and deck.discard_pile == [card_id] and not deck.hand.has(card_id),
		label + ": exactly one printed cost and one discarded copy")


func _test_threadguard_wearer_block_bonus() -> void:
	# AC2: the living, untorn wearer's own positive-Block cards gain exactly +1.
	var warden_ctx := _threadguard_rules("warden")
	var warden_rules: CombatPatchAttackRules = warden_ctx["rules"]
	_check(warden_rules.active_snapshot().get("warden", []).has("threadguard_wrap"),
		"living Warden's ARM projection activates threadguard_wrap")

	var starter := StarterCards.new()
	var brace_def := starter.get_definition("warden_brace")
	_check(brace_def.get("cost") == 1 and brace_def.get("effects", {}) == {"block": 7},
		"printed Warden Brace is 1 cost for 7 Block")
	_check(warden_rules.card_block_bonus("warden", "warden_brace") == 1,
		"threadguard_wrap gives its wearer's Brace exactly +1 Block")
	_check(warden_rules.card_support_bonuses("warden", "warden_brace") ==
		{"block": 1, "bleed": 0, "unravel": 0}, "Brace support bonus is only block: 1")
	_check(warden_rules.project_card_support("warden", "warden_brace") == {"block": 8},
		"Brace projects 7 -> 8 with threadguard_wrap")
	_check(warden_rules.project_card_support("warden", "warden_brace").get("block") != 9,
		"threadguard_wrap is not Hemguard Cuff's +2")

	# A non-Block card never gains Block.
	var strike_def := starter.get_definition("warden_strike")
	_check(strike_def.get("effects", {}) == {"damage": 6}, "printed Warden Strike deals 6 damage")
	_check(warden_rules.card_support_bonuses("warden", "warden_strike") ==
		{"block": 0, "bleed": 0, "unravel": 0},
		"non-Block warden_strike gains no threadguard_wrap bonus")
	_check(warden_rules.project_card_support("warden", "warden_strike") == {"damage": 6},
		"Strike projects unchanged damage without an invented Block key")

	# Wrong owner / wrong recipient.
	_check(warden_rules.card_block_bonus("seamstress", "seamstress_stitch_up") == 0,
		"Seamstress without threadguard_wrap gets no Block bonus")
	_check(warden_rules.card_block_bonus("warden", "seamstress_stitch_up") == 0,
		"wearer playing another owner's card gets no Block bonus")
	_check(warden_rules.project_card_support("warden", "warden_shield_bash") ==
		{"damage": 8, "weak": 1},
		"a non-Block wearer card projects no invented Block")
	_check(warden_rules.card_block_bonus("tinker", "tinker_spool_launcher") == 0,
		"unworn Tinker keeps zero Block bonus")

	# Brace through the real shared hand: 7 printed -> 8 for the wearer only.
	_play_threadguard_card(warden_ctx, "warden_brace", "self_block", 7, 0, 1, 1, 8,
		"Warden Brace with threadguard_wrap")

	# AC2: Stitch Up is still the chosen ally's Block, now +1 to 6.
	var seam_ctx := _threadguard_rules("seamstress")
	var seam_rules: CombatPatchAttackRules = seam_ctx["rules"]
	var stitch_def := starter.get_definition("seamstress_stitch_up")
	_check(stitch_def.get("cost") == 1 and stitch_def.get("effects", {}) == {"block": 5}
		and stitch_def.get("target_kind") == "ally_single",
		"printed Seamstress Stitch Up is 1 cost for 5 Block on one chosen ally")
	_check(seam_rules.card_block_bonus("seamstress", "seamstress_stitch_up") == 1,
		"threadguard_wrap gives the wearing Seamstress's Stitch Up +1 Block")
	_check(seam_rules.project_card_support("seamstress", "seamstress_stitch_up") == {"block": 6},
		"Stitch Up projects 5 -> 6 with threadguard_wrap")
	_check(seam_rules.project_card_support("seamstress", "seamstress_stitch_up").get("block") != 7,
		"Stitch Up is not projected twice")
	_check(seam_rules.card_block_bonus("warden", "warden_brace") == 0,
		"the bonus belongs to the wearer, never to another hero's card")
	_check(seam_rules.card_support_bonuses("seamstress", "seamstress_prick") ==
		{"block": 0, "bleed": 0, "unravel": 0},
		"threadguard_wrap is not a generic bonus for a Bleed card")

	# The chosen ally receives the 6 Block; the wearing Seamstress receives none.
	_play_threadguard_card(seam_ctx, "seamstress_stitch_up", "ally_block", 5, 1, 1, 2, 6,
		"Seamstress Stitch Up on ally Warden")


func _test_threadguard_scope_torn_resew_and_legacy_arms() -> void:
	# AC3: owning the patch without sewing it admits no bonus.
	var idle := _threadguard_ledgers()
	var idle_rules := CombatPatchAttackRules.new()
	_check(idle_rules.bind_wardrobe(idle["wardrobe"], idle["torn"]), "unworn fixture bound")
	_check(idle_rules.card_block_bonus("warden", "warden_brace") == 0,
		"unworn threadguard_wrap grants no Block bonus")
	_check(idle_rules.card_block_bonus("seamstress", "seamstress_stitch_up") == 0,
		"unworn threadguard_wrap grants no ally Block bonus")

	# A torn (0 HP) wearer's Threadguard Wrap is dormant.
	var torn_ctx := _threadguard_rules("warden")
	var torn_wardrobe: RunPatchWardrobe = torn_ctx["wardrobe"]
	var torn: RunTornMending = torn_ctx["torn"]
	var torn_rules: CombatPatchAttackRules = torn_ctx["rules"]
	_check(torn_rules.card_block_bonus("warden", "warden_brace") == 1,
		"the living Warden starts with the Threadguard bonus")
	var battle_start: Array = torn_ctx["heroes"].duplicate(true)
	var battle_end: Array = torn_ctx["heroes"].duplicate(true)
	battle_end[0]["hp"] = 0 # Warden is torn at 0 HP.
	var tear := torn.observe_battle_end("threadguard-battle-1", battle_start, battle_end)
	_check(tear.get("ok") == true, "battle end observed: Warden torn")
	var torn_rebind := CombatPatchAttackRules.new()
	_check(torn_rebind.bind_wardrobe(torn_wardrobe, torn), "torn fixture re-bound")
	_check(torn_rebind.active_snapshot().get("warden", []).is_empty(),
		"torn Warden carries no active patches")
	_check(torn_rebind.card_block_bonus("warden", "warden_brace") == 0,
		"torn wearer admits no Threadguard Block bonus")
	_check(torn_rebind.project_card_support("warden", "warden_brace") == {"block": 7},
		"torn wearer's Brace still projects the printed 7 Block")
	_check(torn_rebind.card_block_bonus("seamstress", "seamstress_stitch_up") == 0,
		"a torn Warden never lends the effect to another hero")

	# A real paid same-slot Rest re-sew moves the effect, and only a fresh bind
	# admits it for the new wearer.
	var resew_ctx := _threadguard_rules("warden")
	var resew_wardrobe: RunPatchWardrobe = resew_ctx["wardrobe"]
	var resew_torn: RunTornMending = resew_ctx["torn"]
	var old_rules: CombatPatchAttackRules = resew_ctx["rules"]
	var old_support := CombatSupportCards.new()
	_check(old_support.bind_patch_wardrobe(resew_wardrobe, resew_torn),
		"support resolver bound before the paid re-sew")
	_check(old_rules.card_block_bonus("warden", "warden_brace") == 1,
		"the pre-rest bind grants Warden the Threadguard bonus")
	var rest_open := resew_wardrobe.start_rest("threadguard-rest", resew_wardrobe.get_snapshot())
	_check(rest_open.get("ok") == true, "Rest opened for the Threadguard re-sew")
	var scraps_before: int = resew_wardrobe.get_snapshot()["scraps"]
	var resew := resew_wardrobe.re_sew("threadguard_wrap", "warden", "seamstress",
		"threadguard-rest", "op-threadguard-resew", resew_wardrobe.get_snapshot())
	_check(resew.get("ok") == true, "paid same-slot re-sew of threadguard_wrap to Seamstress")
	_check(int(resew_wardrobe.get_snapshot()["scraps"]) == scraps_before - 1,
		"the Threadguard re-sew cost exactly 1 scrap")
	_check(resew.get("receipt", {}).get("slot") == "ARM"
		and resew.get("receipt", {}).get("exchanged_id") == "",
		"the re-sew stayed inside the ARM slot and exchanged nothing")
	_check(resew_wardrobe.end_rest("threadguard-rest", resew_wardrobe.get_snapshot()).get("ok") == true,
		"Rest closed after the Threadguard re-sew")

	# Stale ownership: the pre-rest authorities refuse the new state.
	_check(not old_rules.is_current(), "the pre-rest bind is stale after the paid re-sew")
	_check(not old_support.is_patch_binding_valid(),
		"a resolver bound before the re-sew refuses to play the stale wearer")

	var rebound := CombatPatchAttackRules.new()
	_check(rebound.bind_wardrobe(resew_wardrobe, resew_torn), "fresh bind after the Threadguard re-sew")
	_check(rebound.card_block_bonus("warden", "warden_brace") == 0,
		"the former wearer loses the Threadguard Block bonus")
	_check(rebound.card_block_bonus("seamstress", "seamstress_stitch_up") == 1,
		"the new wearer gains the Threadguard Block bonus")
	_check(rebound.project_card_support("seamstress", "seamstress_stitch_up") == {"block": 6},
		"the new wearer's Stitch Up projects 5 -> 6")
	_play_threadguard_card(resew_ctx, "seamstress_stitch_up", "ally_block", 5, 1, 1, 2, 6,
		"Seamstress Stitch Up after the paid re-sew")

	# The older ARM identities keep their authored amounts next to the new one.
	var legacy := _threadguard_ledgers()
	var legacy_wardrobe: RunPatchWardrobe = legacy["wardrobe"]
	var legacy_torn: RunTornMending = legacy["torn"]
	_check(legacy_wardrobe.sew("hemguard_cuff", "warden", "ARM", "op-legacy-hem",
		legacy_wardrobe.get_snapshot()).get("ok") == true, "sew hemguard_cuff to Warden")
	_check(legacy_wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "op-legacy-bobbin",
		legacy_wardrobe.get_snapshot()).get("ok") == true, "sew red_bobbin_cuff to Seamstress")
	_check(legacy_wardrobe.sew("loose_thread_glove", "tinker", "ARM", "op-legacy-glove",
		legacy_wardrobe.get_snapshot()).get("ok") == true, "sew loose_thread_glove to Tinker")
	var legacy_rules := CombatPatchAttackRules.new()
	_check(legacy_rules.bind_wardrobe(legacy_wardrobe, legacy_torn), "legacy ARM fixture bound")
	_check(legacy_rules.card_block_bonus("warden", "warden_brace") == 2,
		"Hemguard Cuff still adds its authored +2 Block")
	_check(legacy_rules.project_card_support("warden", "warden_brace") == {"block": 9},
		"Hemguard Cuff still projects Brace 7 -> 9")
	_check(legacy_rules.card_support_bonuses("seamstress", "seamstress_prick") ==
		{"block": 0, "bleed": 1, "unravel": 0}, "Red Bobbin Cuff still adds +1 Bleed")
	_check(legacy_rules.card_support_bonuses("tinker", "tinker_spool_launcher") ==
		{"block": 0, "bleed": 0, "unravel": 1}, "Loose Thread Glove still adds +1 Unravel")

