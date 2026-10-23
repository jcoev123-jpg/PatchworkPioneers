extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalogs_and_authored_identities()
	_test_distinct_wearer_powers_and_assignments()
	_test_torn_suppression_revival_and_reordered_slots()
	_test_rejections_and_malformed_inputs()
	_test_coexistence_detachment_and_rng_replay()
	_test_pool_heal_projection()
	if failures.is_empty():
		print("combat_shop_patch_rules_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_shop_patch_rules_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _json(path: String) -> Variant:
	var source := FileAccess.get_file_as_string(path)
	_check(not source.is_empty(), path + " is readable")
	return JSON.parse_string(source)


func _is_integral(value: Variant, expected: int) -> bool:
	if typeof(value) == TYPE_INT:
		return value == expected
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and floor(value) == value and int(value) == expected
	return false


func _starter_party_fixture() -> Dictionary:
	var raw_heroes: Variant = _json("res://data/heroes/starter_party.json")
	_check(typeof(raw_heroes) == TYPE_ARRAY and raw_heroes.size() == 3,
		"starter_party.json parses as 3-hero array")
	if typeof(raw_heroes) != TYPE_ARRAY or raw_heroes.size() != 3:
		return {}
	var expected_hp := {"warden": 40, "seamstress": 30, "tinker": 26}
	var expected_order := ["warden", "seamstress", "tinker"]
	var party_defs: Array = []
	for i in range(3):
		var entry: Variant = raw_heroes[i]
		_check(typeof(entry) == TYPE_DICTIONARY and entry.get("id") == expected_order[i]
			and _is_integral(entry.get("max_hp"), expected_hp[expected_order[i]]),
			"starter hero identity and max_hp verified at index " + str(i))
		if typeof(entry) != TYPE_DICTIONARY:
			return {}
		party_defs.append({
			"id": entry["id"],
			"max_hp": int(entry["max_hp"]),
			"art_path": entry.get("art_path", "")
		})
	var party := CombatParty.new(party_defs)
	_check(party.is_valid(), "CombatParty accepts starter_party.json definitions")
	if not party.is_valid():
		return {}
	var heroes: Array = party.get_heroes()
	_check(heroes[0]["id"] == "warden" and heroes[0]["position"] == 1 and heroes[0]["hp"] == 40
		and heroes[1]["id"] == "seamstress" and heroes[1]["position"] == 2 and heroes[1]["hp"] == 30
		and heroes[2]["id"] == "tinker" and heroes[2]["position"] == 3 and heroes[2]["hp"] == 26,
		"CombatParty heroes match starter positions and full HP")
	return {"party": party, "heroes": heroes, "raw_heroes": raw_heroes.duplicate(true)}


func _build_fixture(owned: Array = ["stitched_badge", "spare_spool"], scraps: int = 3,
		extra_defs: Array = []) -> Dictionary:
	var party_data := _starter_party_fixture()
	if party_data.is_empty():
		return {}
	var slots_raw: Variant = _json(CombatShopPatchRules.SLOTS_CATALOG)
	if typeof(slots_raw) != TYPE_ARRAY:
		_check(false, "initial_patch_slots.json is an array")
		return {}
	var defs: Array = []
	var seen := {}
	for entry in slots_raw:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("id") and entry.has("slot"):
			defs.append({"id": entry["id"], "slot": entry["slot"]})
			seen[entry["id"]] = true
	for extra in extra_defs:
		if typeof(extra) == TYPE_DICTIONARY and not seen.has(extra.get("id")):
			defs.append({"id": extra["id"], "slot": extra["slot"]})
			seen[extra["id"]] = true
	var heroes: Array = party_data["heroes"]
	var torn := RunTornMending.new(heroes)
	var cards := ["warden_strike", "warden_brace", "seamstress_mend", "seamstress_prick", "tinker_pop_shot"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, scraps, 200, cards, 410208)
	_check(torn.is_valid() and wardrobe.is_valid(),
		"RunTornMending and RunPatchWardrobe initialize validly")
	if not torn.is_valid() or not wardrobe.is_valid():
		return {}
	return {
		"party": party_data["party"],
		"heroes": heroes,
		"torn": torn,
		"wardrobe": wardrobe,
		"definitions": defs
	}


func _sew(w: RunPatchWardrobe, patch_id: String, hero_id: String, slot: String, op_id: String) -> Dictionary:
	return w.sew(patch_id, hero_id, slot, op_id, w.get_snapshot())


func _refresh_wardrobe(w: RunPatchWardrobe, torn: RunTornMending, scraps: int = -1) -> bool:
	var prior := w.get_snapshot()
	var next_scraps: int = prior["scraps"] if scraps < 0 else scraps
	return w.refresh_run_context(torn.read_state()["heroes"], prior["owned"],
		next_scraps, prior["gold"], prior["cards"], prior)


func _test_catalogs_and_authored_identities() -> void:
	var slots_raw: Variant = _json(CombatShopPatchRules.SLOTS_CATALOG)
	var offers_raw: Variant = _json(CombatShopPatchRules.OFFERS_CATALOG)
	_check(typeof(slots_raw) == TYPE_ARRAY and typeof(offers_raw) == TYPE_DICTIONARY,
		"initial_patch_slots.json and initial_offers.json parse into expected containers")
	if typeof(slots_raw) != TYPE_ARRAY or typeof(offers_raw) != TYPE_DICTIONARY:
		return
	var slots_before: Array = slots_raw.duplicate(true)
	var offers_before: Dictionary = offers_raw.duplicate(true)

	var badge_slots: Array = slots_raw.filter(
		func(entry): return typeof(entry) == TYPE_DICTIONARY and entry.get("id") == "stitched_badge")
	var spool_slots: Array = slots_raw.filter(
		func(entry): return typeof(entry) == TYPE_DICTIONARY and entry.get("id") == "spare_spool")
	_check(badge_slots.size() == 1 and badge_slots[0].size() == 2
		and badge_slots[0].get("slot") == "HEAD",
		"initial_patch_slots.json has unique stitched_badge with slot HEAD")
	_check(spool_slots.size() == 1 and spool_slots[0].size() == 2
		and spool_slots[0].get("slot") == "ARM",
		"initial_patch_slots.json has unique spare_spool with slot ARM")

	var trinkets: Variant = offers_raw.get("trinkets")
	_check(typeof(trinkets) == TYPE_ARRAY, "initial_offers.json contains trinkets array")
	if typeof(trinkets) != TYPE_ARRAY:
		return
	var badge_offers: Array = trinkets.filter(
		func(entry): return typeof(entry) == TYPE_DICTIONARY and entry.get("id") == "stitched_badge")
	var spool_offers: Array = trinkets.filter(
		func(entry): return typeof(entry) == TYPE_DICTIONARY and entry.get("id") == "spare_spool")
	_check(badge_offers.size() == 1 and badge_offers[0].size() == 2
		and _is_integral(badge_offers[0].get("price"), 100),
		"initial_offers.json has unique stitched_badge priced at integer 100 gold")
	_check(spool_offers.size() == 1 and spool_offers[0].size() == 2
		and _is_integral(spool_offers[0].get("price"), 100),
		"initial_offers.json has unique spare_spool priced at integer 100 gold")

	# Verify appendable catalog validation retains other entries without fixed total checks.
	_check(CombatShopPatchRules._valid_slot_catalog(slots_raw),
		"real initial_patch_slots.json passes slot catalog validation")
	var extended_slots: Array = slots_raw.duplicate(true)
	extended_slots.append({"id": "future_coat_patch", "slot": "COAT"})
	_check(CombatShopPatchRules._valid_slot_catalog(extended_slots),
		"slot catalog validation accepts additional valid entries")
	_check(CombatShopPatchRules._valid_offers_catalog(offers_raw),
		"real initial_offers.json passes offers catalog validation")
	var extended_offers: Dictionary = offers_raw.duplicate(true)
	extended_offers["trinkets"].append({"id": "future_trinket", "price": 120})
	_check(CombatShopPatchRules._valid_offers_catalog(extended_offers),
		"offers catalog validation accepts additional valid trinkets")

	# Malformed/drift catalog probes fail closed.
	var wrong_badge_slot: Array = [
		{"id": "stitched_badge", "slot": "ARM"},
		{"id": "spare_spool", "slot": "ARM"}
	]
	var wrong_spool_slot: Array = [
		{"id": "stitched_badge", "slot": "HEAD"},
		{"id": "spare_spool", "slot": "COAT"}
	]
	var duplicate_slot_id: Array = [
		{"id": "stitched_badge", "slot": "HEAD"},
		{"id": "stitched_badge", "slot": "HEAD"},
		{"id": "spare_spool", "slot": "ARM"}
	]
	var missing_spool: Array = [{"id": "stitched_badge", "slot": "HEAD"}]
	for bad_slots in [null, {}, missing_spool, wrong_badge_slot, wrong_spool_slot, duplicate_slot_id]:
		_check(not CombatShopPatchRules._valid_slot_catalog(bad_slots),
			"malformed slot catalog rejected")

	var fractional_price: Dictionary = {
		"trinkets": [
			{"id": "stitched_badge", "price": 100.5},
			{"id": "spare_spool", "price": 100}
		]
	}
	var wrong_price: Dictionary = {
		"trinkets": [
			{"id": "stitched_badge", "price": 99},
			{"id": "spare_spool", "price": 100}
		]
	}
	var duplicate_offer: Dictionary = {
		"trinkets": [
			{"id": "stitched_badge", "price": 100},
			{"id": "stitched_badge", "price": 100},
			{"id": "spare_spool", "price": 100}
		]
	}
	var missing_offer: Dictionary = {
		"trinkets": [{"id": "stitched_badge", "price": 100}]
	}
	for bad_offers in [null, [], {}, fractional_price, wrong_price, duplicate_offer, missing_offer]:
		_check(not CombatShopPatchRules._valid_offers_catalog(bad_offers),
			"malformed offers catalog rejected")
	_check(slots_raw == slots_before and offers_raw == offers_before,
		"catalog validation never mutates parsed catalog data")


func _test_distinct_wearer_powers_and_assignments() -> void:
	var probe := CombatShopPatchRules.new()
	for method_name in [
		"bind_wardrobe", "is_valid", "active_snapshot", "worn_snapshot",
		"opening_block_bonus", "healing_card_bonus",
		"project_opening_block", "project_card_healing"
	]:
		_check(probe.has_method(method_name), "CombatShopPatchRules has method " + method_name)
	_check(not probe.is_valid()
		and probe.opening_block_bonus("warden") == 0
		and probe.healing_card_bonus("seamstress", "seamstress_mend") == 0
		and probe.project_opening_block("warden") == 0
		and probe.project_card_healing("seamstress", "seamstress_mend") == 0,
		"unbound CombatShopPatchRules is invalid and returns 0 for all queries")

	# Verify independent base rules: Warden +6 opening Block and Seamstress Mend 5 heal.
	var base_f := _build_fixture()
	if base_f.is_empty():
		return
	var base_party: CombatParty = base_f["party"]
	_check(base_party.start_player_turn(), "base CombatParty starts player turn")
	var block_helper := CombatStartingBlock.new(base_party)
	_check(block_helper.apply() and base_party.get_hero(1)["block"] == 6
		and base_party.get_hero(2)["block"] == 0 and base_party.get_hero(3)["block"] == 0,
		"Warden's existing independent opening Block is 6")
	_check(not block_helper.apply() and base_party.get_hero(1)["block"] == 6,
		"CombatStartingBlock remains one-shot")

	var cards_catalog := StarterCards.new()
	var cards_before: Dictionary = {}
	for cid in cards_catalog.get_all_card_ids():
		cards_before[cid] = cards_catalog.get_definition(cid)
	var mend_def: Dictionary = cards_catalog.get_definition("seamstress_mend")
	_check(mend_def.get("owner") == "seamstress"
		and mend_def.get("cost") == 1
		and mend_def.get("from_positions") == [2, 3]
		and mend_def.get("target_kind") == "ally_single"
		and mend_def.get("effects") == {"heal": 5},
		"Seamstress Mend authored definition is owner seamstress, cost 1, pos 2-3, heal 5")

	# Unsewn wardrobe: both patches owned, neither sewn.
	var unsewn_rules := CombatShopPatchRules.new()
	var w_unsewn: RunPatchWardrobe = base_f["wardrobe"]
	var t_unsewn: RunTornMending = base_f["torn"]
	var w_snap_before := w_unsewn.get_snapshot()
	var t_snap_before := t_unsewn.read_state()
	_check(unsewn_rules.bind_wardrobe(w_unsewn, t_unsewn) and unsewn_rules.is_valid(),
		"unsewn owned wardrobe binds cleanly")
	_check(unsewn_rules.active_snapshot() == {"warden": [], "seamstress": [], "tinker": []},
		"unsewn wardrobe projects no active patches")
	for hero_id in ["warden", "seamstress", "tinker"]:
		_check(unsewn_rules.opening_block_bonus(hero_id) == 0,
			"unsewn opening_block_bonus is 0 for " + hero_id)
		var expected_base_block := 6 if hero_id == "warden" else 0
		_check(unsewn_rules.project_opening_block(hero_id) == expected_base_block,
			"unsewn project_opening_block matches base for " + hero_id)
		for cid in cards_catalog.get_all_card_ids():
			_check(unsewn_rules.healing_card_bonus(hero_id, cid) == 0,
				"unsewn healing_card_bonus is 0 for " + hero_id + " / " + cid)
	_check(unsewn_rules.project_card_healing("seamstress", "seamstress_mend") == 5,
		"unsewn Seamstress Mend projected heal is base 5")
	_check(w_unsewn.get_snapshot() == w_snap_before and t_unsewn.read_state() == t_snap_before,
		"binding and querying unsewn rules leaves wardrobe and torn snapshots unchanged")

	# Fixture 1: Stitched Badge on Warden (HEAD), Spare Spool on Seamstress (ARM).
	var f1 := _build_fixture()
	if f1.is_empty():
		return
	var w1: RunPatchWardrobe = f1["wardrobe"]
	var t1: RunTornMending = f1["torn"]
	var sew_badge := _sew(w1, "stitched_badge", "warden", "HEAD", "sew_badge_w")
	var sew_spool := _sew(w1, "spare_spool", "seamstress", "ARM", "sew_spool_s")
	_check(sew_badge.get("ok") == true and sew_badge.get("receipt") == {
		"operation_id": "sew_badge_w", "kind": "sew", "patch_id": "stitched_badge",
		"hero_id": "warden", "slot": "HEAD", "displaced_id": "", "scrap_delta": 0
	}, "stitched_badge sews into Warden HEAD slot with exact free receipt")
	_check(sew_spool.get("ok") == true and sew_spool.get("receipt") == {
		"operation_id": "sew_spool_s", "kind": "sew", "patch_id": "spare_spool",
		"hero_id": "seamstress", "slot": "ARM", "displaced_id": "", "scrap_delta": 0
	}, "spare_spool sews into Seamstress ARM slot with exact free receipt")

	var rules1 := CombatShopPatchRules.new()
	var w1_before := w1.get_snapshot()
	var t1_before := t1.read_state()
	_check(rules1.bind_wardrobe(w1, t1, w1_before, t1_before) and rules1.is_valid(),
		"rules1 binds Warden Badge + Seamstress Spool with exact snapshots")
	_check(rules1.active_snapshot() == {
		"warden": ["stitched_badge"],
		"seamstress": ["spare_spool"],
		"tinker": []
	}, "active_snapshot shows stitched_badge on Warden and spare_spool on Seamstress")
	_check(rules1.opening_block_bonus("warden") == 3
		and rules1.opening_block_bonus("seamstress") == 0
		and rules1.opening_block_bonus("tinker") == 0,
		"Stitched Badge grants +3 opening Block only to Warden")
	_check(rules1.project_opening_block("warden") == 9
		and rules1.project_opening_block("seamstress") == 0
		and rules1.project_opening_block("tinker") == 0,
		"Warden base 6 + Stitched Badge 3 projects 9 total opening Block")
	var authored_heal_totals := {"seamstress_mend": 5, "seamstress_mend_plus": 7}
	for hero_id in ["warden", "seamstress", "tinker"]:
		for cid in cards_catalog.get_all_card_ids():
			var bonus := rules1.healing_card_bonus(hero_id, cid)
			var total_heal := rules1.project_card_healing(hero_id, cid)
			if hero_id == "seamstress" and authored_heal_totals.has(cid):
				_check(bonus == 2 and total_heal == authored_heal_totals[cid] + 2,
					"Spare Spool on Seamstress grants +2 to authored heal " + cid)
			else:
				_check(bonus == 0 and total_heal == 0,
					"no healing_card_bonus for " + hero_id + " + " + cid)
	_check(w1.get_snapshot() == w1_before and t1.read_state() == t1_before,
		"rules1 queries do not mutate wardrobe or torn snapshots")

	# Verify effective 7 heal before max-HP clamp on a real CombatParty via CombatSupportCards.
	var heal_party: CombatParty = f1["party"]
	_check(heal_party.apply_damage(1, 10) and heal_party.get_hero(1)["hp"] == 30,
		"Warden takes 10 damage to 30/40 HP")
	var rng := RandomNumberGenerator.new()
	rng.seed = 10401
	var deck_ids: Array[String] = ["seamstress_mend"]
	var deck := CombatDeck.new(deck_ids, rng)
	_check(deck.start_turn() and deck.hand.has("seamstress_mend"), "Mend drawn into hand")
	var support := CombatSupportCards.new()
	var effective_mend := {
		"id": "seamstress_mend",
		"owner_id": mend_def["owner"],
		"cost": mend_def["cost"],
		"from_positions": mend_def["from_positions"],
		"effect": "ally_heal",
		"amount": int(mend_def["effects"]["heal"]) + rules1.healing_card_bonus("seamstress", "seamstress_mend")
	}
	_check(effective_mend["amount"] == 7
		and support.play_support(deck, heal_party, effective_mend, 1)
		and heal_party.get_hero(1)["hp"] == 37,
		"effective Mend amount 7 (5 + 2) heals wounded Warden from 30 to 37")

	# Fixture 2: Move assignments on a fresh wardrobe: Badge on Seamstress, Spool on Warden.
	var f2 := _build_fixture()
	if f2.is_empty():
		return
	var w2: RunPatchWardrobe = f2["wardrobe"]
	var t2: RunTornMending = f2["torn"]
	_check(_sew(w2, "stitched_badge", "seamstress", "HEAD", "sew_badge_s").get("ok") == true
		and _sew(w2, "spare_spool", "warden", "ARM", "sew_spool_w").get("ok") == true,
		"Badge sewn on Seamstress and Spool sewn on Warden")
	var rules2 := CombatShopPatchRules.new()
	_check(rules2.bind_wardrobe(w2, t2) and rules2.is_valid(), "rules2 binds cleanly")
	_check(rules2.opening_block_bonus("warden") == 0
		and rules2.opening_block_bonus("seamstress") == 3
		and rules2.opening_block_bonus("tinker") == 0,
		"Badge on Seamstress grants +3 opening Block only to Seamstress")
	_check(rules2.project_opening_block("warden") == 6
		and rules2.project_opening_block("seamstress") == 3
		and rules2.project_opening_block("tinker") == 0,
		"Warden keeps base 6 while Seamstress gets 3 opening Block")
	for hero_id in ["warden", "seamstress", "tinker"]:
		for cid in cards_catalog.get_all_card_ids():
			_check(rules2.healing_card_bonus(hero_id, cid) == 0,
				"Spool on Warden grants 0 heal bonus to " + hero_id + " / " + cid)
	_check(rules2.project_card_healing("seamstress", "seamstress_mend") == 5
		and rules2.project_card_healing("warden", "seamstress_mend") == 0,
		"Seamstress Mend stays at base 5 when Warden wears Spare Spool")

	# Fixture 3: Same-hero HEAD + ARM on Seamstress, then Rest re-sew to Tinker.
	var f3 := _build_fixture()
	if f3.is_empty():
		return
	var w3: RunPatchWardrobe = f3["wardrobe"]
	var t3: RunTornMending = f3["torn"]
	_check(_sew(w3, "stitched_badge", "seamstress", "HEAD", "sew_both_head").get("ok") == true
		and _sew(w3, "spare_spool", "seamstress", "ARM", "sew_both_arm").get("ok") == true,
		"both Shop patches sewn onto Seamstress (HEAD + ARM)")
	var rules3 := CombatShopPatchRules.new()
	_check(rules3.bind_wardrobe(w3, t3) and rules3.is_valid(),
		"same-hero HEAD+ARM on Seamstress binds cleanly")
	_check(rules3.opening_block_bonus("seamstress") == 3
		and rules3.opening_block_bonus("warden") == 0
		and rules3.opening_block_bonus("tinker") == 0
		and rules3.healing_card_bonus("seamstress", "seamstress_mend") == 2
		and rules3.healing_card_bonus("seamstress", "seamstress_prick") == 0
		and rules3.healing_card_bonus("seamstress", "seamstress_stitch_up") == 0
		and rules3.project_opening_block("seamstress") == 3
		and rules3.project_opening_block("warden") == 6
		and rules3.project_card_healing("seamstress", "seamstress_mend") == 7,
		"Seamstress wearing both HEAD+ARM gets both +3 Block and +2 Mend heal with no global leak")

	# Move both from Seamstress to Tinker via real Rest re_sew.
	_check(w3.start_rest("rest_move_both", w3.get_snapshot()).get("ok") == true, "Rest opened")
	_check(w3.re_sew("stitched_badge", "seamstress", "tinker", "rest_move_both",
		"move_badge_t", w3.get_snapshot()).get("ok") == true,
		"Rest re-sews stitched_badge to Tinker")
	_check(w3.re_sew("spare_spool", "seamstress", "tinker", "rest_move_both",
		"move_spool_t", w3.get_snapshot()).get("ok") == true,
		"Rest re-sews spare_spool to Tinker")
	_check(w3.end_rest("rest_move_both", w3.get_snapshot()).get("ok") == true, "Rest closed")
	_check(rules3.opening_block_bonus("seamstress") == 3
		and rules3.healing_card_bonus("seamstress", "seamstress_mend") == 2
		and rules3.opening_block_bonus("tinker") == 0,
		"already-bound rules3 remains detached from later Rest re-sew")
	var rules3_after := CombatShopPatchRules.new()
	_check(rules3_after.bind_wardrobe(w3, t3) and rules3_after.is_valid(),
		"fresh rules3_after binds Tinker HEAD+ARM")
	_check(rules3_after.opening_block_bonus("tinker") == 3
		and rules3_after.opening_block_bonus("seamstress") == 0
		and rules3_after.opening_block_bonus("warden") == 0
		and rules3_after.project_opening_block("tinker") == 3
		and rules3_after.healing_card_bonus("tinker", "tinker_pop_shot") == 0
		and rules3_after.healing_card_bonus("tinker", "tinker_tune_up") == 0
		and rules3_after.healing_card_bonus("tinker", "seamstress_mend") == 0
		and rules3_after.healing_card_bonus("seamstress", "seamstress_mend") == 0
		and rules3_after.project_card_healing("seamstress", "seamstress_mend") == 5,
		"Tinker wearing both gets +3 opening Block and 0 heal bonus across all cards")

	var cards_after: Dictionary = {}
	for cid in cards_catalog.get_all_card_ids():
		cards_after[cid] = cards_catalog.get_definition(cid)
	_check(cards_after == cards_before, "StarterCards catalog remains completely unchanged")


func _test_torn_suppression_revival_and_reordered_slots() -> void:
	# Case 1: Warden wears Badge (HEAD), Seamstress wears Spool (ARM); Warden is torn in battle.
	var f := _build_fixture(["stitched_badge", "spare_spool"], 4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f["wardrobe"]
	var torn: RunTornMending = f["torn"]
	_check(_sew(w, "stitched_badge", "warden", "HEAD", "w_badge").get("ok") == true
		and _sew(w, "spare_spool", "seamstress", "ARM", "s_spool").get("ok") == true,
		"Warden and Seamstress sew starter Shop patches before battle")

	var battle_start: Array = torn.read_state()["heroes"]
	var battle_end: Array = battle_start.duplicate(true)
	battle_end[0]["hp"] = 0
	battle_end[0]["block"] = 6
	_check(torn.observe_battle_end("fight_tear_warden", battle_start, battle_end).get("ok") == true,
		"RunTornMending observes Warden downed in fight_tear_warden")
	_check(torn.read_state()["heroes"][0]["hp"] == 0
		and torn.read_state()["heroes"][0]["max_hp"] == 37
		and torn.read_state()["tear_counts"]["warden"] == 1,
		"Warden has 0 HP, 37 max_hp, and 1 tear")

	# Before wardrobe refresh, wardrobe holds stale pre-battle heroes -> bind must reject.
	var stale_w_snap := w.get_snapshot()
	var torn_snap := torn.read_state()
	var stale_rules := CombatShopPatchRules.new()
	_check(not stale_rules.bind_wardrobe(w, torn) and not stale_rules.is_valid()
		and stale_rules.opening_block_bonus("warden") == 0
		and stale_rules.healing_card_bonus("seamstress", "seamstress_mend") == 0
		and w.get_snapshot() == stale_w_snap and torn.read_state() == torn_snap,
		"bind_wardrobe fails closed when wardrobe roster is stale vs torn state")

	_check(_refresh_wardrobe(w, torn), "wardrobe refreshed with post-battle torn roster")
	var torn_rules := CombatShopPatchRules.new()
	_check(torn_rules.bind_wardrobe(w, torn) and torn_rules.is_valid(),
		"bind_wardrobe succeeds once wardrobe matches torn state")
	_check(torn_rules.worn_snapshot()["warden"]["HEAD"] == "stitched_badge"
		and torn_rules.active_snapshot()["warden"] == []
		and torn_rules.active_snapshot()["seamstress"] == ["spare_spool"],
		"torn Warden keeps stitched_badge sewn in HEAD while active projection masks it")
	_check(torn_rules.opening_block_bonus("warden") == 0
		and torn_rules.project_opening_block("warden") == 0
		and torn_rules.healing_card_bonus("seamstress", "seamstress_mend") == 2
		and torn_rules.project_card_healing("seamstress", "seamstress_mend") == 7,
		"torn Warden loses +3 Block while surviving Seamstress keeps +2 Mend heal")

	# Case 2: Seamstress wears BOTH Badge (HEAD) and Spool (ARM) and is torn, then mended, then torn & Rest-revived.
	var f_both := _build_fixture(["stitched_badge", "spare_spool"], 4)
	if f_both.is_empty():
		return
	var w_both: RunPatchWardrobe = f_both["wardrobe"]
	var t_both: RunTornMending = f_both["torn"]
	_check(_sew(w_both, "stitched_badge", "seamstress", "HEAD", "s_badge").get("ok") == true
		and _sew(w_both, "spare_spool", "seamstress", "ARM", "s_spool_2").get("ok") == true,
		"Seamstress wears both Badge and Spool")
	var s_start: Array = t_both.read_state()["heroes"]
	var s_end: Array = s_start.duplicate(true)
	s_end[1]["hp"] = 0
	_check(t_both.observe_battle_end("fight_tear_seamstress", s_start, s_end).get("ok") == true
		and _refresh_wardrobe(w_both, t_both),
		"Seamstress torn in battle and wardrobe refreshed")
	var s_torn_rules := CombatShopPatchRules.new()
	_check(s_torn_rules.bind_wardrobe(w_both, t_both) and s_torn_rules.is_valid(),
		"binds with torn Seamstress")
	_check(s_torn_rules.worn_snapshot()["seamstress"] == {
			"HEAD": "stitched_badge", "ARM": "spare_spool", "COAT": ""
		}
		and s_torn_rules.active_snapshot()["seamstress"] == []
		and s_torn_rules.opening_block_bonus("seamstress") == 0
		and s_torn_rules.project_opening_block("seamstress") == 0
		and s_torn_rules.healing_card_bonus("seamstress", "seamstress_mend") == 0
		and s_torn_rules.project_card_healing("seamstress", "seamstress_mend") == 0
		and s_torn_rules.project_opening_block("warden") == 6,
		"both HEAD and ARM benefits are suppressed on torn Seamstress while worn IDs remain assigned")

	# Map mend revives Seamstress (max_hp 27 -> hp 6) for 2 scraps.
	var mend_res := t_both.choose_mend("map_mend_s", "mend_rcpt_s", "seamstress", 2, 4,
		t_both.read_state()["heroes"], true)
	_check(mend_res.get("ok") == true and mend_res.get("remaining_scraps") == 2
		and mend_res["heroes"][1]["hp"] == 6 and mend_res["heroes"][1]["max_hp"] == 27,
		"paid map mend revives Seamstress to 6/27 HP")
	_check(not CombatShopPatchRules.new().bind_wardrobe(w_both, t_both),
		"stale pre-mend wardrobe rejected before refresh")
	_check(_refresh_wardrobe(w_both, t_both, mend_res["remaining_scraps"]),
		"wardrobe refreshed after map mend")
	var s_mended_rules := CombatShopPatchRules.new()
	_check(s_mended_rules.bind_wardrobe(w_both, t_both)
		and s_mended_rules.opening_block_bonus("seamstress") == 3
		and s_mended_rules.healing_card_bonus("seamstress", "seamstress_mend") == 2
		and s_mended_rules.project_card_healing("seamstress", "seamstress_mend") == 7,
		"map mend reactivates both HEAD +3 Block and ARM +2 heal on Seamstress")

	# Tear Seamstress again and revive via Rest heal.
	var s_start2: Array = t_both.read_state()["heroes"]
	var s_end2: Array = s_start2.duplicate(true)
	s_end2[1]["hp"] = 0
	_check(t_both.observe_battle_end("fight_tear_seamstress_2", s_start2, s_end2).get("ok") == true
		and _refresh_wardrobe(w_both, t_both),
		"Seamstress torn a second time to 0/24 HP")
	var s_torn2 := CombatShopPatchRules.new()
	_check(s_torn2.bind_wardrobe(w_both, t_both)
		and s_torn2.opening_block_bonus("seamstress") == 0
		and s_torn2.healing_card_bonus("seamstress", "seamstress_mend") == 0,
		"second tear suppresses both benefits again")
	_check(t_both.apply_rest("rest_revive_s", t_both.read_state()["heroes"], true).get("ok") == true
		and _refresh_wardrobe(w_both, t_both),
		"Rest heal revives Seamstress and refreshes wardrobe")
	var s_rested := CombatShopPatchRules.new()
	_check(s_rested.bind_wardrobe(w_both, t_both)
		and s_rested.opening_block_bonus("seamstress") == 3
		and s_rested.healing_card_bonus("seamstress", "seamstress_mend") == 2,
		"Rest revival reactivates both HEAD and ARM benefits")

	# Case 3: Legitimate combat position swap before battle end keeps wearer identity intact.
	var f_swap := _build_fixture()
	if f_swap.is_empty():
		return
	var w_swap: RunPatchWardrobe = f_swap["wardrobe"]
	var t_swap: RunTornMending = f_swap["torn"]
	var p_swap: CombatParty = f_swap["party"]
	_check(_sew(w_swap, "stitched_badge", "warden", "HEAD", "swap_badge").get("ok") == true
		and _sew(w_swap, "spare_spool", "seamstress", "ARM", "swap_spool").get("ok") == true,
		"swap fixture sews Badge on Warden and Spool on Seamstress")
	var swap_preview := CombatPositionSwaps.preview_adjacent_swap(p_swap, 1, 1)
	_check(swap_preview.get("ok") == true
		and swap_preview["heroes"][0]["id"] == "seamstress"
		and swap_preview["heroes"][1]["id"] == "warden",
		"CombatPositionSwaps swaps Seamstress to slot 1 and Warden to slot 2")
	var start_swap: Array = t_swap.read_state()["heroes"]
	var end_swap: Array = swap_preview["heroes"].duplicate(true)
	_check(t_swap.observe_battle_end("fight_swapped_slots", start_swap, end_swap).get("ok") == true
		and _refresh_wardrobe(w_swap, t_swap),
		"RunTornMending and RunPatchWardrobe accept permuted hero positions")
	var swapped_rules := CombatShopPatchRules.new()
	_check(swapped_rules.bind_wardrobe(w_swap, t_swap)
		and swapped_rules.opening_block_bonus("warden") == 3
		and swapped_rules.project_opening_block("warden") == 9
		and swapped_rules.healing_card_bonus("seamstress", "seamstress_mend") == 2
		and swapped_rules.project_card_healing("seamstress", "seamstress_mend") == 7,
		"wearer bonuses track hero ID across permuted combat slots")


func _test_rejections_and_malformed_inputs() -> void:
	# 1. Failed wrong-slot sews, unowned sews, duplicate sews, and stale sew snapshots.
	var f := _build_fixture(["stitched_badge", "spare_spool"], 2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f["wardrobe"]
	var torn: RunTornMending = f["torn"]
	var p: CombatParty = f["party"]
	for bad_sew in [
		["badge wrong ARM slot", "stitched_badge", "warden", "ARM", "bad_1"],
		["badge wrong COAT slot", "stitched_badge", "warden", "COAT", "bad_2"],
		["spool wrong HEAD slot", "spare_spool", "seamstress", "HEAD", "bad_3"],
		["spool wrong COAT slot", "spare_spool", "seamstress", "COAT", "bad_4"],
		["unknown patch ID", "phantom_patch", "warden", "HEAD", "bad_5"],
		["unknown hero ID", "stitched_badge", "stranger", "HEAD", "bad_6"],
		["empty operation ID", "stitched_badge", "warden", "HEAD", ""]
	]:
		var prior_w := w.get_snapshot()
		var prior_t := torn.read_state()
		var prior_p := p.get_heroes()
		var res := w.sew(bad_sew[1], bad_sew[2], bad_sew[3], bad_sew[4], prior_w)
		_check(res == {"ok": false, "state": prior_w}
			and w.get_snapshot() == prior_w
			and torn.read_state() == prior_t
			and p.get_heroes() == prior_p,
			bad_sew[0] + " rejected without mutating snapshots")

	# Missing ownership fixture: definitions exist, but patches are not in owned array.
	var f_unowned := _build_fixture([], 2)
	if f_unowned.is_empty():
		return
	var w_unowned: RunPatchWardrobe = f_unowned["wardrobe"]
	var prior_unowned := w_unowned.get_snapshot()
	_check(w_unowned.sew("stitched_badge", "warden", "HEAD", "unowned_b", prior_unowned)
		== {"ok": false, "state": prior_unowned}
		and w_unowned.sew("spare_spool", "seamstress", "ARM", "unowned_s", prior_unowned)
		== {"ok": false, "state": prior_unowned}
		and w_unowned.get_snapshot() == prior_unowned,
		"missing ownership rejects sewing for both Shop patches without mutation")
	var unowned_rules := CombatShopPatchRules.new()
	_check(unowned_rules.bind_wardrobe(w_unowned, f_unowned["torn"])
		and unowned_rules.opening_block_bonus("warden") == 0
		and unowned_rules.healing_card_bonus("seamstress", "seamstress_mend") == 0,
		"unowned patches project 0 bonuses")

	# Valid sew followed by duplicate sew on another hero and replayed op ID.
	var pre_sew_snap := w.get_snapshot()
	_check(_sew(w, "stitched_badge", "warden", "HEAD", "op_badge").get("ok") == true
		and _sew(w, "spare_spool", "seamstress", "ARM", "op_spool").get("ok") == true,
		"valid sews succeed after rejected wrong-slot attempts")
	var post_sew_snap := w.get_snapshot()
	_check(w.sew("stitched_badge", "tinker", "HEAD", "dup_badge", post_sew_snap)
		== {"ok": false, "state": post_sew_snap}
		and w.sew("spare_spool", "tinker", "ARM", "dup_spool", post_sew_snap)
		== {"ok": false, "state": post_sew_snap}
		and w.sew("stitched_badge", "tinker", "HEAD", "op_badge", post_sew_snap)
		== {"ok": false, "state": post_sew_snap}
		and w.get_snapshot() == post_sew_snap,
		"duplicate sew onto second wearer and replayed operation ID fail closed")

	# 2. Stale or forged expected snapshots passed to bind_wardrobe.
	var check_rules := CombatShopPatchRules.new()
	_check(check_rules.bind_wardrobe(w, torn), "baseline valid binding succeeds")
	var forged_w := post_sew_snap.duplicate(true)
	forged_w["receipt"] = "forged_sha256"
	var forged_w_gold := post_sew_snap.duplicate(true)
	forged_w_gold["gold"] = 9999
	var forged_t := torn.read_state().duplicate(true)
	forged_t["heroes"][0]["hp"] = 1
	for bad_expected in [
		["stale pre-sew wardrobe snapshot", pre_sew_snap, torn.read_state()],
		["forged wardrobe receipt", forged_w, torn.read_state()],
		["forged wardrobe gold", forged_w_gold, torn.read_state()],
		["forged torn hero HP", post_sew_snap, forged_t],
		["non-dictionary expected wardrobe", "invalid", torn.read_state()],
		["non-dictionary expected torn", post_sew_snap, 42]
	]:
		var before_w := w.get_snapshot()
		var before_t := torn.read_state()
		_check(not check_rules.bind_wardrobe(w, torn, bad_expected[1], bad_expected[2])
			and not check_rules.is_valid()
			and check_rules.active_snapshot().is_empty()
			and check_rules.opening_block_bonus("warden") == 0
			and check_rules.healing_card_bonus("seamstress", "seamstress_mend") == 0
			and w.get_snapshot() == before_w and torn.read_state() == before_t,
			bad_expected[0] + " fails closed and clears prior binding without mutating services")

	# 3. Null / invalid service instances and corrupted internal wardrobe/torn structures.
	var invalid_w := RunPatchWardrobe.new()
	var invalid_t := RunTornMending.new()
	for bad_pair in [
		[null, torn],
		[w, null],
		[null, null],
		[invalid_w, torn],
		[w, invalid_t],
		["not_a_wardrobe", torn],
		[w, {"ok": true}]
	]:
		var r := CombatShopPatchRules.new()
		_check(not r.bind_wardrobe(bad_pair[0], bad_pair[1]) and not r.is_valid(),
			"null or invalid service argument fails closed")

	for patch_id in ["stitched_badge", "spare_spool"]:
		var expected_slot: String = CombatShopPatchRules.EFFECTS[patch_id]["slot"]
		var wrong_slot := "ARM" if expected_slot == "HEAD" else "HEAD"
		for fault in [
			"missing_owned_definition", "wrong_slot_definition", "forged_unowned_worn",
			"forged_wrong_slot_worn", "duplicate_wearers", "duplicate_owned_list",
			"forged_tear_count", "forged_foreign_hero", "forged_negative_block"
		]:
			var fx := _build_fixture(["stitched_badge", "spare_spool"], 2)
			var fw: RunPatchWardrobe = fx["wardrobe"]
			var ft: RunTornMending = fx["torn"]
			if fault == "missing_owned_definition":
				fw._definitions.erase(patch_id)
			elif fault == "wrong_slot_definition":
				fw._definitions[patch_id] = wrong_slot
			elif fault == "forged_unowned_worn":
				fw._owned.erase(patch_id)
				fw._worn["warden"][expected_slot] = patch_id
			elif fault == "forged_wrong_slot_worn":
				fw._worn["warden"][wrong_slot] = patch_id
			elif fault == "duplicate_wearers":
				fw._worn["warden"][expected_slot] = patch_id
				fw._worn["seamstress"][expected_slot] = patch_id
			elif fault == "duplicate_owned_list":
				fw._owned.append(patch_id)
			elif fault == "forged_tear_count":
				ft._tear_counts["warden"] = 2
			elif fault == "forged_foreign_hero":
				fw._heroes[2]["id"] = "outsider"
				ft._heroes[2]["id"] = "outsider"
			elif fault == "forged_negative_block":
				fw._heroes[0]["block"] = -1
				ft._heroes[0]["block"] = -1
			var snap_w := fw.get_snapshot()
			var snap_t := ft.read_state()
			var rule_probe := CombatShopPatchRules.new()
			_check(not rule_probe.bind_wardrobe(fw, ft)
				and not rule_probe.is_valid()
				and rule_probe.opening_block_bonus("warden") == 0
				and rule_probe.opening_block_bonus("seamstress") == 0
				and rule_probe.healing_card_bonus("seamstress", "seamstress_mend") == 0
				and fw.get_snapshot() == snap_w and ft.read_state() == snap_t,
				patch_id + " " + fault + " rejected fail-closed without mutation")

	# 4. Unknown, wrong-owner, non-heal, and malformed card/hero arguments on a valid binding.
	_check(check_rules.bind_wardrobe(w, torn) and check_rules.is_valid(),
		"re-bind valid wardrobe after rejection tests")
	for bad_hero in [null, "", " ", "outsider", "WARDEN", 1, true, [], {}]:
		_check(check_rules.opening_block_bonus(bad_hero) == 0
			and check_rules.project_opening_block(bad_hero) == 0
			and check_rules.healing_card_bonus(bad_hero, "seamstress_mend") == 0
			and check_rules.project_card_healing(bad_hero, "seamstress_mend") == 0,
			"invalid hero_id returns 0 for all queries")
	for bad_card in [
		null, "", " ", "unknown_card", "seamstress_mend_plus_unknown", "SEAMSTRESS_MEND",
		"warden_strike", "warden_brace", "warden_shield_bash",
		"seamstress_prick", "seamstress_stitch_up",
		"tinker_pop_shot", "tinker_scrap_bomb", "tinker_tune_up",
		42, true, ["seamstress_mend"],
		{"id": "seamstress_mend", "owner": "seamstress", "effects": {"heal": 5}}
	]:
		_check(check_rules.healing_card_bonus("seamstress", bad_card) == 0
			and check_rules.project_card_healing("seamstress", bad_card) == 0,
			"unknown/non-heal/forged card argument returns 0")

	# Mend+ is now an authored positive-heal starter card, so the same bound
	# spare spool projects its own base seven plus the existing +2.
	_check(check_rules.healing_card_bonus("seamstress", "seamstress_mend_plus") == 2
		and check_rules.project_card_healing("seamstress", "seamstress_mend_plus") == 9,
		"authored Mend+ reads its own base seven through the spare spool")

	# Direct probes of _has_positive_authored_heal against non-positive/float/forged definitions.
	for bad_def in [
		null, "seamstress_mend", {},
		{"id": "seamstress_mend", "owner": "warden", "effects": {"heal": 5}},
		{"id": "other_id", "owner": "seamstress", "effects": {"heal": 5}},
		{"id": "seamstress_mend", "owner": "seamstress", "effects": {"heal": 0}},
		{"id": "seamstress_mend", "owner": "seamstress", "effects": {"heal": -2}},
		{"id": "seamstress_mend", "owner": "seamstress", "effects": {"heal": 5.0}},
		{"id": "seamstress_mend", "owner": "seamstress", "effects": {"heal": 5.5}},
		{"id": "seamstress_mend", "owner": "seamstress", "effects": {"heal": "5"}},
		{"id": "seamstress_mend", "owner": "seamstress", "effects": {"heal": true}},
		{"id": "seamstress_mend", "owner": "seamstress", "effects": {"block": 5}}
	]:
		_check(not CombatShopPatchRules._has_positive_authored_heal(bad_def, "seamstress", "seamstress_mend"),
			"forged or non-positive heal definition rejected")


func _replay_timeline() -> Dictionary:
	var extra_defs := [
		{"id": "button_eye", "slot": "HEAD"},
		{"id": "pincushion_arm", "slot": "ARM"},
		{"id": "quilted_coat", "slot": "COAT"}
	]
	var owned := ["stitched_badge", "spare_spool", "button_eye", "pincushion_arm", "quilted_coat"]
	var fx := _build_fixture(owned, 3, extra_defs)
	if fx.is_empty():
		return {}
	var w: RunPatchWardrobe = fx["wardrobe"]
	var torn: RunTornMending = fx["torn"]
	var trace: Array = []

	trace.append(_sew(w, "stitched_badge", "warden", "HEAD", "t_sew_1"))
	trace.append(_sew(w, "spare_spool", "seamstress", "ARM", "t_sew_2"))
	trace.append(_sew(w, "quilted_coat", "seamstress", "COAT", "t_sew_3"))
	trace.append(_sew(w, "button_eye", "tinker", "HEAD", "t_sew_4"))
	trace.append(_sew(w, "pincushion_arm", "warden", "ARM", "t_sew_5"))

	var shop_rules := CombatShopPatchRules.new()
	var attack_rules := CombatPatchAttackRules.new()
	var coats: Variant = _json("res://data/patches/m04_coat_patches.json")
	var bound_ok := shop_rules.bind_wardrobe(w, torn) and attack_rules.bind_wardrobe(w, torn)
	var coat_proj := RunPatchCoatRules.project_health(torn.read_state(), w, coats)
	trace.append({
		"bound_ok": bound_ok,
		"shop_active": shop_rules.active_snapshot(),
		"warden_block_bonus": shop_rules.opening_block_bonus("warden"),
		"warden_total_block": shop_rules.project_opening_block("warden"),
		"seamstress_mend_bonus": shop_rules.healing_card_bonus("seamstress", "seamstress_mend"),
		"seamstress_mend_total": shop_rules.project_card_healing("seamstress", "seamstress_mend"),
		"tinker_exposed": attack_rules.exposed_for_first_hit("tinker"),
		"warden_dmg_bonus": attack_rules.damage_bonus("warden"),
		"seamstress_coat_hp": coat_proj["heroes"][1]["max_hp"]
	})

	# Tear Warden in battle, refresh, bind, mend, refresh, Rest swap HEAD between Warden and Tinker.
	var b_start: Array = torn.read_state()["heroes"]
	var b_end: Array = b_start.duplicate(true)
	b_end[0]["hp"] = 0
	trace.append(torn.observe_battle_end("replay_fight_1", b_start, b_end))
	trace.append(_refresh_wardrobe(w, torn))
	var shop_torn := CombatShopPatchRules.new()
	trace.append({
		"torn_bind": shop_torn.bind_wardrobe(w, torn),
		"warden_block_bonus": shop_torn.opening_block_bonus("warden"),
		"seamstress_mend_bonus": shop_torn.healing_card_bonus("seamstress", "seamstress_mend")
	})
	var mend := torn.choose_mend("replay_mend_1", "replay_rcpt_1", "warden", 1,
		w.get_snapshot()["scraps"], torn.read_state()["heroes"], true)
	trace.append(mend)
	trace.append(_refresh_wardrobe(w, torn, mend["remaining_scraps"]))
	trace.append(w.start_rest("replay_rest_1", w.get_snapshot()))
	trace.append(w.re_sew("stitched_badge", "warden", "tinker", "replay_rest_1",
		"replay_swap_head", w.get_snapshot()))
	trace.append(w.end_rest("replay_rest_1", w.get_snapshot()))
	var shop_after := CombatShopPatchRules.new()
	var attack_after := CombatPatchAttackRules.new()
	trace.append({
		"after_bind": shop_after.bind_wardrobe(w, torn) and attack_after.bind_wardrobe(w, torn),
		"warden_block_bonus": shop_after.opening_block_bonus("warden"),
		"tinker_block_bonus": shop_after.opening_block_bonus("tinker"),
		"warden_exposed": attack_after.exposed_for_first_hit("warden"),
		"tinker_exposed": attack_after.exposed_for_first_hit("tinker"),
		"seamstress_mend_bonus": shop_after.healing_card_bonus("seamstress", "seamstress_mend")
	})
	return {"trace": trace, "wardrobe": w.get_snapshot(), "torn": torn.read_state()}


func _test_coexistence_detachment_and_rng_replay() -> void:
	# Prove the global RNG check detects an extra draw if one occurs.
	seed(804179)
	var probe_expected := randi()
	seed(804179)
	var _injected := randi()
	_check(randi() != probe_expected, "global RNG guard detects an injected draw")

	seed(804179)
	var expected_global := randi()
	seed(804179)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 661209
	var local_seed: int = local_rng.seed
	var local_state: int = local_rng.state

	var first := _replay_timeline()
	var second := _replay_timeline()
	_check(not first.is_empty() and first == second,
		"two independent multi-step timelines agree byte-for-byte")
	if first.is_empty():
		return
	var step_initial: Dictionary = first["trace"][5]
	var step_torn: Dictionary = first["trace"][8]
	var step_after: Dictionary = first["trace"][14]
	_check(step_initial == {
		"bound_ok": true,
		"shop_active": {
			"warden": ["stitched_badge", "pincushion_arm"],
			"seamstress": ["spare_spool", "quilted_coat"],
			"tinker": ["button_eye"]
		},
		"warden_block_bonus": 3,
		"warden_total_block": 9,
		"seamstress_mend_bonus": 2,
		"seamstress_mend_total": 7,
		"tinker_exposed": {"exposed": 1},
		"warden_dmg_bonus": 1,
		"seamstress_coat_hp": 36
	}, "Shop patches coexist with Button Eye, Pincushion Arm, and Quilted Coat without cross-activation")
	_check(step_torn == {
		"torn_bind": true,
		"warden_block_bonus": 0,
		"seamstress_mend_bonus": 2
	}, "timeline torn step suppresses only downed Warden's Stitched Badge")
	_check(step_after == {
		"after_bind": true,
		"warden_block_bonus": 0,
		"tinker_block_bonus": 3,
		"warden_exposed": {"exposed": 1},
		"tinker_exposed": {},
		"seamstress_mend_bonus": 2
	}, "timeline mend and Rest HEAD swap exchanges Stitched Badge and Button Eye cleanly")

	# Repeated queries and snapshot detachment check.
	var fx := _build_fixture(["stitched_badge", "spare_spool"], 2)
	var w: RunPatchWardrobe = fx["wardrobe"]
	var torn: RunTornMending = fx["torn"]
	_check(_sew(w, "stitched_badge", "warden", "HEAD", "det_1").get("ok") == true
		and _sew(w, "spare_spool", "seamstress", "ARM", "det_2").get("ok") == true,
		"detachment fixture sews both Shop patches")
	var rules := CombatShopPatchRules.new()
	_check(rules.bind_wardrobe(w, torn), "detachment fixture binds")
	var w_before := w.get_snapshot()
	var t_before := torn.read_state()
	for _i in range(5):
		_check(rules.opening_block_bonus("warden") == 3
			and rules.project_opening_block("warden") == 9
			and rules.healing_card_bonus("seamstress", "seamstress_mend") == 2
			and rules.project_card_healing("seamstress", "seamstress_mend") == 7,
			"repeated queries return constant non-stacking bonuses")
	var active_a := rules.active_snapshot()
	var active_b := rules.active_snapshot()
	var worn_a := rules.worn_snapshot()
	var worn_b := rules.worn_snapshot()
	active_a["warden"].clear()
	active_a["tinker"].append("stitched_badge")
	worn_a["warden"]["HEAD"] = ""
	worn_a["tinker"]["ARM"] = "spare_spool"
	_check(active_b == {"warden": ["stitched_badge"], "seamstress": ["spare_spool"], "tinker": []}
		and rules.active_snapshot() == active_b
		and worn_b == w_before["worn"]
		and rules.worn_snapshot() == worn_b
		and rules.opening_block_bonus("warden") == 3
		and rules.healing_card_bonus("seamstress", "seamstress_mend") == 2
		and w.get_snapshot() == w_before and torn.read_state() == t_before,
		"mutating returned snapshots never alters sibling snapshots, rules, or ledgers")

	_check(local_rng.seed == local_seed and local_rng.state == local_state
		and randi() == expected_global,
		"neither bindings nor queries consume local or global RNG")


func _test_pool_heal_projection() -> void:
	# AC1 / AC2: Verify all six D2-1 pool healing definitions recognized with +2 bonus.
	var f := _build_fixture(["stitched_badge", "spare_spool"], 4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f["wardrobe"]
	var torn: RunTornMending = f["torn"]
	_check(_sew(w, "spare_spool", "seamstress", "ARM", "pool_spool").get("ok") == true,
		"spare_spool sews to Seamstress ARM for pool test")

	var rules := CombatShopPatchRules.new()
	_check(rules.bind_wardrobe(w, torn) and rules.is_valid(),
		"pool projection binds with spare_spool on Seamstress ARM")

	# All six canonical base/+ definitions.
	var pairs: Array = [
		["seamstress_darning", 4, 6],
		["seamstress_darning_plus", 6, 8],
		["seamstress_thimble_tea", 3, 5],
		["seamstress_thimble_tea_plus", 4, 6],
		["seamstress_field_mend", 4, 6],
		["seamstress_field_mend_plus", 6, 8],
	]
	for pair in pairs:
		var card_id: String = pair[0]
		var base_heal: int = pair[1]
		var expected_total: int = pair[2]
		_check(rules.healing_card_bonus("seamstress", card_id) == 2,
			"spool +2 bonus on " + card_id)
		_check(rules.project_card_healing("seamstress", card_id) == expected_total,
			"project_card_healing(" + card_id + ") == " + str(expected_total) + " (base " + str(base_heal) + ")")

	# Unchanged authored payloads preserved: Block and targeting untouched.
	var pool_catalog := SeamstressPoolCards.new()
	for card_id in ["seamstress_darning", "seamstress_darning_plus", "seamstress_thimble_tea",
		"seamstress_thimble_tea_plus", "seamstress_field_mend", "seamstress_field_mend_plus"]:
		var def := pool_catalog.get_definition(card_id)
		_check(not def.is_empty() and def.get("id") == card_id and def.get("owner") == "seamstress",
			"authored pool definition preserved for " + card_id)
		if card_id.begins_with("seamstress_darning"):
			_check(def.get("effects").get("block") > 0,
				"Darning block unchanged: " + str(def.get("effects").get("block")))
		if card_id.begins_with("seamstress_field_mend"):
			_check(def.get("target_kind") == "party_all",
				"Field Mend party_all targeting unchanged")

	# Starter Mend still gets +2.
	_check(rules.healing_card_bonus("seamstress", "seamstress_mend") == 2,
		"starter seamstress_mend keeps +2")
	_check(rules.project_card_healing("seamstress", "seamstress_mend") == 7,
		"project_card_healing(seamstress_mend) == 7")

	# Negative checks.
	# Spool on Tinker -> no bonus.
	var spool_tinker := rules.healing_card_bonus("tinker", "seamstress_darning") == 0
	_check(spool_tinker,
		"tinker claims seamstress_darning with spool on tinker -> 0 bonus")

	# Empty ARM on Seamstress -> no bonus.
	var f_empty := _build_fixture(["stitched_badge", "spare_spool"], 2)
	if not f_empty.is_empty():
		var w_empty: RunPatchWardrobe = f_empty["wardrobe"]
		var torn_empty: RunTornMending = f_empty["torn"]
		var empty_rules := CombatShopPatchRules.new()
		_check(empty_rules.bind_wardrobe(w_empty, torn_empty) and empty_rules.is_valid(),
			"empty ARM fixture binds")
		_check(empty_rules.healing_card_bonus("seamstress", "seamstress_darning") == 0,
			"empty ARM gives 0 bonus for pool card")

	# Torn wearer -> no bonus.
	var torn_f := _build_fixture(["stitched_badge", "spare_spool"], 4)
	if not torn_f.is_empty():
		var tw: RunPatchWardrobe = torn_f["wardrobe"]
		var ttorn: RunTornMending = torn_f["torn"]
		_check(_sew(tw, "spare_spool", "seamstress", "ARM", "torn_spool").get("ok") == true,
			"torn fixture sews spool")
		var s_start_torn: Array = ttorn.read_state()["heroes"].duplicate(true)
		var s_end_torn: Array = s_start_torn.duplicate(true)
		s_end_torn[1]["hp"] = 0
		_check(ttorn.observe_battle_end("tear_seam", s_start_torn, s_end_torn).get("ok") == true
			and _refresh_wardrobe(tw, ttorn),
			"torn seamstress and wardrobe refreshed")
		var torn_rules := CombatShopPatchRules.new()
		_check(torn_rules.bind_wardrobe(tw, ttorn) and torn_rules.is_valid(),
			"torn rules binds")
		_check(torn_rules.healing_card_bonus("seamstress", "seamstress_darning") == 0
			and torn_rules.project_card_healing("seamstress", "seamstress_darning") == 0,
			"torn wearer suppresses pool healing bonus")

	# Unknown card -> 0.
	_check(rules.healing_card_bonus("seamstress", "unknown_pool") == 0,
		"unknown pool card returns 0 bonus")

	# Attack-only Seamstress pool card -> 0 (positive heal required).
	# seamstress_prick has damage/bleed, no heal.
	_check(rules.healing_card_bonus("seamstress", "seamstress_prick") == 0,
		"attack-only pool card (prick) returns 0 bonus")

	# Forged ID (wrong owner) -> 0.
	_check(rules.healing_card_bonus("warden", "seamstress_darning") == 0,
		"cross-owner request (warden claiming seamstress_darning) returns 0")

	# Forged definition with wrong owner does not pass.
	_check(not CombatShopPatchRules._has_positive_authored_heal(
		{"id": "seamstress_darning", "owner": "warden", "effects": {"heal": 4}},
		"seamstress", "seamstress_darning"),
		"forged cross-owner definition rejected")

	# Definition payloads not modified by projection.
	var starter_catalog := StarterCards.new()
	var starter_before := starter_catalog.get_definition("seamstress_mend")
	_check(starter_before.get("effects") == {"heal": 5},
		"starter mend definition unchanged after projection queries")
