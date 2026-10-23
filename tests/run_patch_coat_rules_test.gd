extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_and_all_wearers()
	_test_simultaneous_coats_and_wearers()
	_test_battle_tear_mend_and_rest()
	_test_new_coats_tear_mend_and_resew()
	_test_rest_transfer_swap_and_replacement()
	_test_invalid_transactions_and_projection()
	_test_rng_and_detachment()
	_test_m05_reinforced_patchcoat_and_thick_felt_mantle()
	if failures.is_empty():
		print("run_patch_coat_rules_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_patch_coat_rules_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _json(path: String) -> Variant:
	var source := FileAccess.get_file_as_string(path)
	_check(not source.is_empty(), path + " is readable")
	return JSON.parse_string(source)


func _fixture(scraps: int = 3, include_coat: bool = true) -> Dictionary:
	var definitions: Variant = _json("res://data/heroes/starter_party.json")
	var authored: Variant = _json("res://data/patches/m04_coat_patches.json")
	var slots: Variant = _json("res://data/patches/initial_patch_slots.json")
	if typeof(definitions) != TYPE_ARRAY or typeof(authored) != TYPE_ARRAY \
			or typeof(slots) != TYPE_ARRAY:
		_check(false, "authored fixture collections are arrays")
		return {}
	var names := {"warden": 40, "seamstress": 30, "tinker": 26}
	_check(definitions.size() == 3, "the starter roster contains three actors")
	if definitions.size() != 3:
		return {}
	for i in range(3):
		var entry: Dictionary = definitions[i]
		_check(names.has(entry.get("id")) and entry.get("max_hp") == names.get(entry.get("id")),
			"starter hero named identity and HP verified at position " + str(i + 1))
	var present := {}
	for slot_record in slots:
		if typeof(slot_record) == TYPE_DICTIONARY:
			present[slot_record.get("id")] = slot_record.get("slot")
	_check(present.get("stitched_badge") == "HEAD" and present.get("spare_spool") == "ARM",
		"original two catalog entries remain named and correctly slotted")

	var coat_by_id := {}
	var duplicate_ids := false
	for coat_entry in authored:
		if coat_entry is Dictionary and coat_entry.has("id"):
			var cid: String = coat_entry.get("id")
			if coat_by_id.has(cid):
				duplicate_ids = true
			coat_by_id[cid] = coat_entry
	_check(not duplicate_ids, "authored coat patch IDs are unique")
	var expected_coats := {
		"quilted_coat": 6,
		"padded_vest": 4,
		"double_quilt_coat": 8,
		"scrap_lined_vest": 3,
		"wool_patch_cloak": 5,
		"chain_stitched_coat": 7,
		"reinforced_patchcoat": 9,
		"thick_felt_mantle": 10,
	}
	for cid in expected_coats:
		var entry: Variant = coat_by_id.get(cid)
		_check(entry is Dictionary and entry.size() == 3
			and entry.get("id") == cid
			and entry.get("slot") == "COAT"
			and entry.get("max_hp_bonus") == expected_coats[cid],
			"authored " + cid + " is valid exact COAT +" + str(expected_coats[cid]))
	if not (coat_by_id.has("quilted_coat") and coat_by_id.has("padded_vest") and coat_by_id.has("double_quilt_coat")
			and coat_by_id.has("reinforced_patchcoat") and coat_by_id.has("thick_felt_mantle")):
		return {}

	var party_defs: Array = definitions.duplicate(true)
	for entry in party_defs:
		entry["max_hp"] = int(entry["max_hp"])
	var party := CombatParty.new(party_defs)
	_check(party.is_valid(), "real CombatParty accepts authored three heroes")
	if not party.is_valid():
		return {}
	var heroes: Array = party.get_heroes()
	for i in range(3):
		heroes[i]["statuses"] = {"bleed": i, "weak": 0, "exposed": 0}
	var torn := RunTornMending.new(heroes)
	var patch_defs: Array = []
	for entry in slots:
		patch_defs.append({"id": entry["id"], "slot": entry["slot"]})
	# Project the authored three-field rule down to wardrobe's strict
	# two-field identity/slot-only constructor, without changing its schema.
	for cid in expected_coats:
		if coat_by_id.has(cid):
			patch_defs.append({"id": cid, "slot": "COAT"})
	patch_defs.append({"id": "coat_extra", "slot": "COAT"})
	var owned := ["coat_extra", "stitched_badge", "spare_spool"]
	if include_coat:
		for cid in expected_coats:
			owned.append(cid)
	var wardrobe := RunPatchWardrobe.new(heroes, owned, patch_defs, scraps,
		117, ["warden_strike", "seamstress_prick"], 920151)
	_check(torn.is_valid() and wardrobe.is_valid(),
		"actual torn/mend and wardrobe services initialize with two-field definitions")
	if not torn.is_valid() or not wardrobe.is_valid():
		return {}
	for cid in expected_coats:
		_check(wardrobe.get_snapshot().definitions.get(cid) == "COAT",
			"definition for " + cid + " is COAT")
	_check(not wardrobe.get_snapshot().definitions.has("max_hp_bonus"),
		"bonus field does not leak into RunPatchWardrobe definitions")
	return {"party": party, "torn": torn, "wardrobe": wardrobe, "coats": authored,
		"owned": owned, "definitions": patch_defs}


func _sew(w: RunPatchWardrobe, patch: String, wearer: String, op: String) -> Dictionary:
	return w.sew(patch, wearer, "COAT", op, w.get_snapshot())


func _project(f: Dictionary, caps: Array, label: String) -> void:
	var torn: RunTornMending = f.torn
	var w: RunPatchWardrobe = f.wardrobe
	var before_t := torn.read_state()
	var before_w := w.get_snapshot()
	var result := RunPatchCoatRules.project_health(before_t, w, f.coats)
	_check(result.get("ok") == true and result.get("heroes") is Array
		and result["heroes"].size() == 3, label + ": three detached heroes projected")
	if result.get("ok") != true or result["heroes"].size() != 3:
		return
	for i in range(3):
		var expected: Dictionary = before_t.heroes[i].duplicate(true)
		expected["max_hp"] = caps[i]
		_check(result.heroes[i] == expected,
			label + ": only derived cap changed for " + before_t.heroes[i]["id"])
	_check(torn.read_state() == before_t and w.get_snapshot() == before_w,
		label + ": preview cannot modify either service's full snapshot")
	_check(RunPatchCoatRules.project_health(torn.read_state(), w, f.coats) == result,
		label + ": repeated preview is exact, non-stacking and deterministic")


func _refresh(f: Dictionary, scraps: int) -> void:
	var w: RunPatchWardrobe = f.wardrobe
	var old := w.get_snapshot()
	_check(w.refresh_run_context(f.torn.read_state().heroes, old.owned, scraps,
		old.gold, old.cards, old), "run owner refreshes real wardrobe roster and purse")
	_check(w.get_snapshot().seed == old.seed and w.get_snapshot().gold == old.gold
		and w.get_snapshot().cards == old.cards and w.get_snapshot().worn == old.worn,
		"refresh does not change worn IDs, seed, cards or gold")


func _reject(w: RunPatchWardrobe, label: String, call: Callable) -> void:
	var prior := w.get_snapshot()
	var result: Dictionary = call.call()
	_check(result == {"ok": false, "state": prior},
		label + " is rejected with no receipt")
	_check(w.get_snapshot() == prior, label + " leaves the complete ledger intact")


func _test_catalog_and_all_wearers() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(RunPatchCoatRules.new().has_method("project_health"),
		"public coat projection method is present")
	_project(f, [40, 30, 26], "pristine unworn")
	_check(_sew(w, "quilted_coat", "warden", "sew_w").get("ok") == true,
		"free owned COAT sew onto Warden is committed")
	_check(w.get_snapshot().scraps == 3 and w.project_active(f.torn.read_state()).active.warden == ["quilted_coat"],
		"genuine wardrobe slot and active wearing established without spending scraps")
	_project(f, [46, 30, 26], "Warden wears coat")
	_check(w.start_rest("first_rest", w.get_snapshot()).get("ok") == true, "legal Rest opened")
	_check(w.re_sew("quilted_coat", "warden", "seamstress", "first_rest",
		"move_s", w.get_snapshot()).get("ok") == true, "real move Warden to Seamstress")
	_project(f, [40, 36, 26], "Seamstress wears coat")
	_check(w.re_sew("quilted_coat", "seamstress", "tinker", "first_rest",
		"move_t", w.get_snapshot()).get("ok") == true, "real move Seamstress to Tinker")
	_project(f, [40, 30, 32], "Tinker wears coat")
	_check(w.get_snapshot().scraps == 1 and w.end_rest("first_rest",
		w.get_snapshot()).get("ok") == true, "two moves cost exactly two scraps and close Rest")


func _test_simultaneous_coats_and_wearers() -> void:
	var f := _fixture(3)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var torn: RunTornMending = f.torn
	var before_t := torn.read_state()
	var before_w := w.get_snapshot()

	_project(f, [40, 30, 26], "simultaneous pristine unworn")

	# Sew padded_vest on living Warden -> 40 + 4 = 44
	_check(_sew(w, "padded_vest", "warden", "sew_warden_vest").get("ok") == true,
		"padded vest sews to living Warden")
	_project(f, [44, 30, 26], "Warden wears padded vest (+4)")

	# Sew double_quilt_coat on living Seamstress -> 30 + 8 = 38
	_check(_sew(w, "double_quilt_coat", "seamstress", "sew_seamstress_double").get("ok") == true,
		"double quilt coat sews to living Seamstress")
	_project(f, [44, 38, 26], "Seamstress wears double quilt coat (+8)")

	# Sew quilted_coat on living Tinker -> 26 + 6 = 32
	_check(_sew(w, "quilted_coat", "tinker", "sew_tinker_quilt").get("ok") == true,
		"quilted coat sews to living Tinker")
	_project(f, [44, 38, 32], "all three wear distinct coats (+4, +8, +6)")

	# Assert returned original HP/Block/statuses/positions unchanged, others not boosted
	var proj := RunPatchCoatRules.project_health(torn.read_state(), w, f.coats)
	_check(proj.get("ok") == true, "projection succeeded for distinct simultaneous coats")
	for i in range(3):
		var h: Dictionary = proj["heroes"][i]
		var orig: Dictionary = before_t.heroes[i]
		_check(h["id"] == orig["id"] and h["position"] == orig["position"]
			and h["hp"] == orig["hp"] and h["block"] == orig["block"]
			and h["statuses"] == orig["statuses"],
			"original hero fields preserved for " + orig["id"])
	_check(proj["heroes"][0]["max_hp"] == 44 and proj["heroes"][1]["max_hp"] == 38
		and proj["heroes"][2]["max_hp"] == 32,
		"derived max HP boosts exactly 44, 38, 32")

	# Untouched wardrobe/torn snapshots
	var cur_w := w.get_snapshot()
	var cur_t := torn.read_state()
	_check(cur_t.heroes[0]["max_hp"] == 40 and cur_t.heroes[1]["max_hp"] == 30
		and cur_t.heroes[2]["max_hp"] == 26,
		"torn service base max HP untouched by projection")
	_check(cur_w.gold == before_w.gold and cur_w.seed == before_w.seed
		and cur_w.cards == before_w.cards and cur_w.scraps == 3,
		"wardrobe gold, seed, cards, scraps untouched by projection")

	# Two reads do not stack bonuses
	var proj_again := RunPatchCoatRules.project_health(torn.read_state(), w, f.coats)
	_check(proj == proj_again, "repeated reads do not stack bonuses")


func _test_battle_tear_mend_and_rest() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var torn: RunTornMending = f.torn
	var w: RunPatchWardrobe = f.wardrobe
	_check(_sew(w, "quilted_coat", "warden", "before_tear").get("ok") == true,
		"Warden has genuinely sewn coat before battle")
	var starting: Array = torn.read_state().heroes
	var ending: Array = starting.duplicate(true)
	ending[0].hp = 0
	ending[0].block = 7
	ending[0].statuses.bleed = 3
	_check(torn.observe_battle_end("fight_a", starting, ending).get("ok") == true,
		"observed battle causes Warden first tear")
	_check(torn.read_state().heroes[0].hp == 0 and torn.read_state().heroes[0].max_hp == 37
		and torn.read_state().tear_counts.warden == 1,
		"tear applies actual -3 base max and HP zero with one recorded tear")
	var stale_before := w.get_snapshot()
	_check(not RunPatchCoatRules.project_health(torn.read_state(), w, f.coats).ok
		and w.get_snapshot() == stale_before,
		"projection fails closed while wardrobe still holds old base roster")
	_refresh(f, 2)
	_check(w.project_active(torn.read_state()).active.warden == []
		and w.get_snapshot().worn.warden.COAT == "quilted_coat",
		"existing wardrobe masks torn Warden while keeping patch sewn")
	_project(f, [37, 30, 26], "torn coat suppressed")
	var prior_t := torn.read_state()
	var bad_mend := torn.choose_mend("map_m", "m_bad", "warden", 1, 1,
		prior_t.heroes, true)
	_check(not bad_mend.ok and torn.read_state() == prior_t,
		"insufficient scrap mend cannot alter hero or claim receipt")
	var mend := torn.choose_mend("map_m", "m_good", "warden", 1, 2,
		torn.read_state().heroes, true)
	_check(mend.get("ok") == true and mend.get("remaining_scraps") == 0
		and mend.heroes[0].hp == 9 and mend.heroes[0].max_hp == 37,
		"real legal 2-scrap mend restores floor(37 / 4) = 9 HP, no coat heal")
	_refresh(f, mend.remaining_scraps)
	_check(w.project_active(torn.read_state()).active.warden == ["quilted_coat"]
		and w.get_snapshot().scraps == 0, "mend revives genuine active wearer without scrap underflow")
	_project(f, [43, 30, 26], "mend reactivates +6 without HP change")
	_check(torn.read_state().heroes[0].hp == 9
		and torn.read_state().tear_counts.warden == 1,
		"persistent base tear penalty survives equip and mend")

	var rest_f := _fixture(2)
	if rest_f.is_empty():
		return
	var rest_t: RunTornMending = rest_f.torn
	_check(_sew(rest_f.wardrobe, "quilted_coat", "warden", "rest_coat").ok,
		"Rest revival fixture has genuinely sewn coat")
	var battle: Array = rest_t.read_state().heroes
	var down: Array = battle.duplicate(true)
	down[0].hp = 0
	_check(rest_t.observe_battle_end("fight_rest", battle, down).ok,
		"Rest route witnesses separate genuine tear")
	_refresh(rest_f, 2)
	_project(rest_f, [37, 30, 26], "torn before Rest")
	_check(rest_t.apply_rest("rest_revival", rest_t.read_state().heroes, true).ok,
		"real Rest heal revives Warden independently from paid mend")
	_refresh(rest_f, 2)
	_check(rest_t.read_state().heroes[0].hp == 12, "Rest revival is separate 12 HP route")
	_project(rest_f, [43, 30, 26], "Rest revival activates +6")


func _test_new_coats_tear_mend_and_resew() -> void:
	var f := _fixture(3)
	if f.is_empty():
		return
	var torn: RunTornMending = f.torn
	var w: RunPatchWardrobe = f.wardrobe

	_check(_sew(w, "padded_vest", "warden", "sew_vest_tm").ok, "Warden wears padded vest")
	_check(_sew(w, "double_quilt_coat", "seamstress", "sew_double_tm").ok, "Seamstress wears double quilt")
	_check(_sew(w, "quilted_coat", "tinker", "sew_quilt_tm").ok, "Tinker wears quilted coat")
	_project(f, [44, 38, 32], "initial three coats active")

	# Tear Seamstress in battle
	var starting: Array = torn.read_state().heroes
	var ending: Array = starting.duplicate(true)
	ending[1].hp = 0
	_check(torn.observe_battle_end("fight_seamstress_down", starting, ending).ok,
		"Seamstress tears in battle")
	_check(torn.read_state().heroes[1].hp == 0 and torn.read_state().heroes[1].max_hp == 27
		and torn.read_state().tear_counts.seamstress == 1,
		"Seamstress base max drops to 27 with 1 tear")
	_refresh(f, 3)
	_project(f, [44, 27, 32], "torn Seamstress double quilt coat suppressed while living wearers boosted")

	# Paid map mend on Seamstress (position 2, costs 2 scraps)
	var mend := torn.choose_mend("map_mend_s", "m_s", "seamstress", 2, 3,
		torn.read_state().heroes, true)
	_check(mend.get("ok") == true and mend.get("remaining_scraps") == 1
		and mend.heroes[1].hp == 6 and mend.heroes[1].max_hp == 27,
		"map mend heals Seamstress floor(27 / 4) = 6 HP, base max 27")
	_refresh(f, mend.remaining_scraps)
	_check(w.project_active(torn.read_state()).active.seamstress == ["double_quilt_coat"],
		"mended Seamstress reactivates double quilt coat")
	_project(f, [44, 35, 32], "mended Seamstress reactivates +8 max HP")

	# Legal Rest re-sew / swap (1 scrap)
	_check(w.start_rest("rest_coats_swap", w.get_snapshot()).ok, "Rest opens for coat swap")
	var swap_res := w.re_sew("double_quilt_coat", "seamstress", "tinker",
		"rest_coats_swap", "swap_st", w.get_snapshot())
	_check(swap_res.ok and swap_res.receipt.exchanged_id == "quilted_coat"
		and swap_res.receipt.scrap_delta == -1 and w.get_snapshot().scraps == 0,
		"occupied COAT swap costs 1 scrap")
	# Seamstress now wears quilted_coat (+6 -> 27+6=33), Tinker wears double_quilt_coat (+8 -> 26+8=34)
	_project(f, [44, 33, 34], "after swap Seamstress has quilt (+6) and Tinker has double quilt (+8)")

	# Replacement of occupied COAT on Tinker (grants 1 scrap)
	var replace_res := _sew(w, "coat_extra", "tinker", "replace_tinker_double")
	_check(replace_res.ok and replace_res.receipt.displaced_id == "double_quilt_coat"
		and replace_res.receipt.scrap_delta == 1 and w.get_snapshot().scraps == 1
		and not w.get_snapshot().owned.has("double_quilt_coat")
		and w.get_snapshot().worn.tinker.COAT == "coat_extra",
		"occupied sew destroys displaced double quilt coat and grants 1 scrap")
	_project(f, [44, 33, 26], "replaced Tinker coat grants no bonus, others retain +4 and +6")
	_check(w.end_rest("rest_coats_swap", w.get_snapshot()).ok, "Rest closes cleanly")


func _test_rest_transfer_swap_and_replacement() -> void:
	var f := _fixture(3)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(_sew(w, "quilted_coat", "warden", "w_coat").ok
		and _sew(w, "coat_extra", "seamstress", "s_extra").ok,
		"two distinct COAT patches occupy Warden and Seamstress")
	var original := w.get_snapshot()
	var recovery := RunRestRecovery.new(f.torn.read_state().heroes)
	_check(not recovery.is_consumed(), "Rest choice genuinely unconsumed")
	_check(w.start_rest("rest_swap", w.get_snapshot()).ok, "confirmed Rest session opens")
	var moved := w.re_sew("quilted_coat", "warden", "tinker", "rest_swap",
		"to_tinker", w.get_snapshot())
	_check(moved.ok and moved.receipt.exchanged_id == ""
		and moved.receipt.scrap_delta == -1 and w.get_snapshot().scraps == 2,
		"empty COAT transfer costs exactly one scrap and leaves no exchanged ID")
	_project(f, [40, 30, 32], "empty-slot transfer Tinker")
	var swapped := w.re_sew("quilted_coat", "tinker", "seamstress", "rest_swap",
		"swap_s", w.get_snapshot())
	var after := w.get_snapshot()
	_check(swapped.ok and swapped.receipt.exchanged_id == "coat_extra"
		and after.worn.seamstress.COAT == "quilted_coat"
		and after.worn.tinker.COAT == "coat_extra" and after.scraps == 1,
		"occupied COAT exchange costs one scrap, preserving both patch IDs")
	_project(f, [40, 36, 26], "occupied-slot swap Seamstress")
	_check(not recovery.is_consumed() and after.gold == original.gold
		and after.seed == original.seed and after.cards == original.cards
		and after.heroes == original.heroes and after.owned == original.owned
		and after.worn.warden.HEAD == original.worn.warden.HEAD
		and after.worn.tinker.ARM == original.worn.tinker.ARM,
		"both re-sews leave Rest action, other slots, base heroes and run ledger unchanged")
	_check(w.end_rest("rest_swap", w.get_snapshot()).ok, "Rest session closes")

	var replacement := _fixture(0)
	if replacement.is_empty():
		return
	var w2: RunPatchWardrobe = replacement.wardrobe
	_check(_sew(w2, "quilted_coat", "warden", "sew_original").ok,
		"separate replacement fixture wears genuine Quilted Coat")
	_project(replacement, [46, 30, 26], "before destructive replacement")
	var old := w2.get_snapshot()
	var replaced := _sew(w2, "coat_extra", "warden", "replace_coat")
	_check(replaced.ok and replaced.receipt.displaced_id == "quilted_coat"
		and replaced.receipt.scrap_delta == 1 and w2.get_snapshot().scraps == 1
		and not w2.get_snapshot().owned.has("quilted_coat")
		and w2.get_snapshot().worn.warden.COAT == "coat_extra",
		"occupied sew destroys displaced coat and gives exactly one scrap")
	_check(w2.get_snapshot().gold == old.gold and w2.get_snapshot().seed == old.seed
		and w2.get_snapshot().cards == old.cards and w2.get_snapshot().heroes == old.heroes,
		"replacement does not touch hero base max, cards, gold or RNG seed")
	_project(replacement, [40, 30, 26], "replaced coat grants no bonus")


func _test_invalid_transactions_and_projection() -> void:
	var f := _fixture(1)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var t: RunTornMending = f.torn
	_reject(w, "wrong matching slot", func(): return w.sew(
		"quilted_coat", "warden", "HEAD", "wrong_slot", w.get_snapshot()))
	_reject(w, "unowned coat", func(): return w.sew(
		"not_owned", "warden", "COAT", "unowned", w.get_snapshot()))
	_check(_sew(w, "quilted_coat", "warden", "valid_sew").ok,
		"fresh legitimate sew still works following rejected slot and ownership")
	var stale := w.get_snapshot()
	_reject(w, "same patch cannot duplicate on another hero", func(): return w.sew(
		"quilted_coat", "seamstress", "COAT", "duplicate", w.get_snapshot()))
	_reject(w, "replayed sewing ID", func(): return w.sew(
		"coat_extra", "warden", "COAT", "valid_sew", w.get_snapshot()))
	_reject(w, "out-of-Rest re-sew", func(): return w.re_sew(
		"quilted_coat", "warden", "tinker", "rest_a", "move_valid", w.get_snapshot()))
	_check(w.start_rest("rest_a", w.get_snapshot()).ok, "valid Rest opens after rejection")
	_reject(w, "wrong Rest ID", func(): return w.re_sew(
		"quilted_coat", "warden", "tinker", "rest_bad", "move_valid", w.get_snapshot()))
	_reject(w, "re-sew with stale pre-Rest snapshot", func(): return w.re_sew(
		"quilted_coat", "warden", "tinker", "rest_a", "move_valid", stale))
	var forged := w.get_snapshot()
	forged.heroes[0].max_hp = 999
	_reject(w, "forged ledger snapshot", func(): return w.re_sew(
		"quilted_coat", "warden", "tinker", "rest_a", "move_valid", forged))
	_check(w.re_sew("quilted_coat", "warden", "tinker", "rest_a",
		"move_valid", w.get_snapshot()).ok,
		"fresh valid attempt succeeds after wrong rest and stale receipt")
	_reject(w, "replayed re-sew ID", func(): return w.re_sew(
		"quilted_coat", "tinker", "warden", "rest_a", "move_valid", w.get_snapshot()))
	_reject(w, "no scraps left", func(): return w.re_sew(
		"quilted_coat", "tinker", "warden", "rest_a", "insufficient", w.get_snapshot()))
	_project(f, [40, 30, 32], "rejected transactions leave Tinker coat active")
	var baseline_w := w.get_snapshot()
	var baseline_t := t.read_state()
	var baseline_coats: Array = f.coats.duplicate(true)

	var forged_t: Dictionary = baseline_t.duplicate(true)
	forged_t.heroes[2].hp = 0
	_check(not RunPatchCoatRules.project_health(forged_t, w, f.coats).ok,
		"stale mismatched torn roster rejects without fabricating a bonus")
	forged_t = baseline_t.duplicate(true)
	forged_t.heroes[2].id = "foreign"
	_check(not RunPatchCoatRules.project_health(forged_t, w, f.coats).ok,
		"foreign wearer identity rejects")
	forged_t = baseline_t.duplicate(true)
	forged_t.tear_counts.tinker = 1
	_check(not RunPatchCoatRules.project_health(forged_t, w, f.coats).ok,
		"tear count and base maximum mismatch rejects")

	# Invalid catalog checks:
	# 1. Repeated ID in catalog
	var bad_repeated: Array = f.coats.duplicate(true)
	bad_repeated.append({"id": "padded_vest", "slot": "COAT", "max_hp_bonus": 4})
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_repeated).ok,
		"repeated catalog ID rejects")

	# 2. Wrong named bonus
	for bad_info in [["quilted_coat", 7], ["padded_vest", 5], ["double_quilt_coat", 9]]:
		var bad_bonus: Array = f.coats.duplicate(true)
		for entry in bad_bonus:
			if entry["id"] == bad_info[0]:
				entry["max_hp_bonus"] = bad_info[1]
		_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_bonus).ok,
			"wrong named bonus for " + bad_info[0] + " rejects")

	# 3. Wrong slot
	var bad_authored: Array = f.coats.duplicate(true)
	for entry in bad_authored:
		if entry["id"] == "padded_vest":
			entry["slot"] = "ARM"
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_authored).ok,
		"wrong authored coat slot rejects")
	var bad_authored_m05: Array = f.coats.duplicate(true)
	for entry in bad_authored_m05:
		if entry["id"] == "reinforced_patchcoat":
			entry["slot"] = "ARM"
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_authored_m05).ok,
		"wrong authored coat slot for reinforced_patchcoat rejects")

	# 4. Missing required prior name
	for missing_id in ["quilted_coat", "padded_vest", "double_quilt_coat"]:
		var bad_missing: Array = []
		for entry in f.coats:
			if entry["id"] != missing_id:
				bad_missing.append(entry.duplicate(true))
		_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_missing).ok,
			"missing required coat " + missing_id + " rejects")

	# 5. Fractional and nonpositive amounts
	var bad_amount: Array = f.coats.duplicate(true)
	for entry in bad_amount:
		if entry["id"] == "padded_vest":
			entry["max_hp_bonus"] = 4.5
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_amount).ok,
		"fractional bonus drift rejects without truncation")
	bad_amount = f.coats.duplicate(true)
	for entry in bad_amount:
		if entry["id"] == "padded_vest":
			entry["max_hp_bonus"] = 0
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_amount).ok,
		"zero max_hp_bonus rejects")
	bad_amount = f.coats.duplicate(true)
	for entry in bad_amount:
		if entry["id"] == "double_quilt_coat":
			entry["max_hp_bonus"] = -8
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_amount).ok,
		"negative max_hp_bonus rejects")
	bad_amount = f.coats.duplicate(true)
	for entry in bad_amount:
		if entry["id"] == "reinforced_patchcoat":
			entry["max_hp_bonus"] = 0
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_amount).ok,
		"zero max_hp_bonus for reinforced_patchcoat rejects")
	bad_amount = f.coats.duplicate(true)
	for entry in bad_amount:
		if entry["id"] == "thick_felt_mantle":
			entry["max_hp_bonus"] = -10
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_amount).ok,
		"negative max_hp_bonus for thick_felt_mantle rejects")
	bad_amount = f.coats.duplicate(true)
	for entry in bad_amount:
		if entry["id"] == "thick_felt_mantle":
			entry["max_hp_bonus"] = 10.5
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_amount).ok,
		"fractional max_hp_bonus for thick_felt_mantle rejects")

	# 6. Malformed entries
	var bad_malformed: Array = f.coats.duplicate(true)
	bad_malformed.append("not_a_dict")
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_malformed).ok,
		"non-dictionary catalog entry rejects")
	bad_malformed = f.coats.duplicate(true)
	bad_malformed.append({"id": "extra_coat", "slot": "COAT"})
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_malformed).ok,
		"catalog entry missing bonus field rejects")
	bad_malformed = f.coats.duplicate(true)
	bad_malformed.append({"id": "extra_coat", "slot": "COAT", "max_hp_bonus": 5, "bogus": 1})
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_malformed).ok,
		"catalog entry with extra fields rejects")
	bad_malformed = f.coats.duplicate(true)
	bad_malformed.append({"id": "", "slot": "COAT", "max_hp_bonus": 5})
	_check(not RunPatchCoatRules.project_health(baseline_t, w, bad_malformed).ok,
		"catalog entry with empty ID rejects")
	_check(not RunPatchCoatRules.project_health(baseline_t, w, {}).ok,
		"catalog dictionary instead of array rejects")
	_check(not RunPatchCoatRules.project_health(baseline_t, w, []).ok,
		"empty catalog rejects")

	_check(w.get_snapshot() == baseline_w and t.read_state() == baseline_t
		and f.coats == baseline_coats,
		"all malformed projections leave services and authored catalog untouched")

	var no_coat := _fixture(2, false)
	if no_coat.is_empty():
		return
	_reject(no_coat.wardrobe, "coat definition does not imply ownership", func():
		return no_coat.wardrobe.sew("quilted_coat", "warden", "COAT",
			"unowned_quilt", no_coat.wardrobe.get_snapshot()))
	_project(no_coat, [40, 30, 26], "unowned/unsewn coat has no projected effect")
	_check(w.end_rest("rest_a", w.get_snapshot()).ok,
		"valid Rest end follows all failed operations")
	_reject(w, "closed Rest cannot re-sew", func(): return w.re_sew(
		"quilted_coat", "tinker", "warden", "rest_a", "after_end", w.get_snapshot()))


func _test_rng_and_detachment() -> void:
	seed(314159)
	var expected_draw := randi()
	seed(314159)
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var torn: RunTornMending = f.torn
	_check(_sew(w, "quilted_coat", "warden", "rng_sew").ok, "RNG fixture sews real coat")
	var before_w := w.get_snapshot()
	var before_t := torn.read_state()
	var before_author: Array = f.coats.duplicate(true)
	var a := RunPatchCoatRules.project_health(torn.read_state(), w, f.coats)
	var b := RunPatchCoatRules.project_health(torn.read_state(), w, f.coats)
	_check(a == b and a.ok and a.heroes[0].max_hp == 46,
		"identical repeated projections contain exactly +6 Warden max")
	a.heroes[0].max_hp = 999
	a.heroes[1].statuses.bleed = 999
	b.heroes[0].max_hp = 888
	_check(RunPatchCoatRules.project_health(torn.read_state(), w, f.coats).heroes[0].max_hp == 46
		and torn.read_state().heroes[1].statuses.bleed == 1
		and w.get_snapshot() == before_w and torn.read_state() == before_t
		and f.coats == before_author,
		"mutating detached nested return never corrupts services or input rules")
	_check(randi() == expected_draw,
		"neither fixture nor transactional previews consume global random draws")


func _test_m05_reinforced_patchcoat_and_thick_felt_mantle() -> void:
	var f := _fixture(4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var torn: RunTornMending = f.torn
	var before_t := torn.read_state()
	var before_w := w.get_snapshot()

	_project(f, [40, 30, 26], "m05 pristine unworn")

	# AC2: Sew reinforced_patchcoat on living Warden (+9) -> 40 + 9 = 49
	_check(_sew(w, "reinforced_patchcoat", "warden", "sew_warden_reinforced").ok,
		"reinforced_patchcoat sews to living Warden")
	# Sew thick_felt_mantle on living Seamstress (+10) -> 30 + 10 = 40
	_check(_sew(w, "thick_felt_mantle", "seamstress", "sew_seamstress_mantle").ok,
		"thick_felt_mantle sews to living Seamstress")
	# Tinker is unpatched (+0) -> 26

	seed(84201)
	var expected_rng := randi()
	seed(84201)

	var proj := RunPatchCoatRules.project_health(torn.read_state(), w, f.coats)
	_check(proj.get("ok") == true, "m05 projection succeeded for living wearers")
	if proj.get("ok") == true:
		# Warden 40+9=49, Seamstress 30+10=40, unpatched Tinker 26
		_check(proj.heroes[0].max_hp == 49 and proj.heroes[0].hp == 40
			and proj.heroes[0].id == "warden" and proj.heroes[0].position == 1
			and proj.heroes[0].block == before_t.heroes[0].block
			and proj.heroes[0].statuses == before_t.heroes[0].statuses,
			"Warden projects 40+9=49 effective max HP with current HP, block, statuses and position intact")
		_check(proj.heroes[1].max_hp == 40 and proj.heroes[1].hp == 30
			and proj.heroes[1].id == "seamstress" and proj.heroes[1].position == 2
			and proj.heroes[1].block == before_t.heroes[1].block
			and proj.heroes[1].statuses == before_t.heroes[1].statuses,
			"Seamstress projects 30+10=40 effective max HP with current HP, block, statuses and position intact")
		_check(proj.heroes[2].max_hp == 26 and proj.heroes[2].hp == 26
			and proj.heroes[2].id == "tinker" and proj.heroes[2].position == 3
			and proj.heroes[2].block == before_t.heroes[2].block
			and proj.heroes[2].statuses == before_t.heroes[2].statuses,
			"unpatched Tinker remains 26 max HP and 26 current HP")

	# Base max HP, current HP, wallet, deck, receipts and RNG remain untouched
	var cur_t := torn.read_state()
	var cur_w := w.get_snapshot()
	_check(cur_t.heroes[0].max_hp == 40 and cur_t.heroes[1].max_hp == 30 and cur_t.heroes[2].max_hp == 26,
		"torn ledger base max HP untouched by projection")
	_check(cur_t.heroes[0].hp == 40 and cur_t.heroes[1].hp == 30 and cur_t.heroes[2].hp == 26,
		"torn ledger current HP untouched by projection")
	_check(cur_w.scraps == 4 and cur_w.gold == before_w.gold and cur_w.cards == before_w.cards
		and cur_w.seed == before_w.seed,
		"wardrobe scraps, gold, cards and seed untouched by projection")
	_check(randi() == expected_rng, "projection leaves global RNG draw untouched")

	# Detachable calculation: repeated projection does not stack bonuses
	var proj_repeat := RunPatchCoatRules.project_health(torn.read_state(), w, f.coats)
	_check(proj == proj_repeat, "repeated projection does not stack bonuses")
	_project(f, [49, 40, 26], "Warden wears +9, Seamstress wears +10, Tinker unpatched")

	# Suppression at HP 0: battle tear on Warden
	var b_start: Array = torn.read_state().heroes
	var b_end: Array = b_start.duplicate(true)
	b_end[0].hp = 0
	b_end[0].block = 4
	b_end[0].statuses.bleed = 2
	_check(torn.observe_battle_end("fight_m05_tear", b_start, b_end).ok,
		"battle tear drops Warden to HP 0")
	_check(torn.read_state().heroes[0].hp == 0 and torn.read_state().heroes[0].max_hp == 37
		and torn.read_state().tear_counts.warden == 1,
		"Warden base max drops to 37 with 1 recorded tear")
	_refresh(f, 4)
	_check(w.project_active(torn.read_state()).active.warden == []
		and w.get_snapshot().worn.warden.COAT == "reinforced_patchcoat",
		"torn Warden keeps reinforced_patchcoat sewn but inactive")
	_project(f, [37, 40, 26], "torn Warden coat suppressed to base 37 while Seamstress keeps +10 (40)")

	# Legal return after map mend (costs 2 scraps, restores floor(37/4) = 9 HP)
	var mend := torn.choose_mend("map_m05_mend", "mend_rc_1", "warden", 1, 4,
		torn.read_state().heroes, true)
	_check(mend.get("ok") == true and mend.get("remaining_scraps") == 2
		and mend.heroes[0].hp == 9 and mend.heroes[0].max_hp == 37,
		"legal 2-scrap map mend restores floor(37/4)=9 HP to Warden, base max 37")
	_refresh(f, mend.remaining_scraps)
	_check(w.project_active(torn.read_state()).active.warden == ["reinforced_patchcoat"]
		and w.get_snapshot().scraps == 2,
		"mended Warden reactivates reinforced_patchcoat without scrap discrepancy")
	_project(f, [46, 40, 26], "mend reactivates +9 bonus (37+9=46) without extra coat healing")
	_check(torn.read_state().heroes[0].hp == 9, "Warden current HP remains 9 after projection")

	# Rest revival route: tear Seamstress in battle
	var s_start: Array = torn.read_state().heroes
	var s_end: Array = s_start.duplicate(true)
	s_end[1].hp = 0
	_check(torn.observe_battle_end("fight_m05_s_tear", s_start, s_end).ok,
		"battle tear drops Seamstress to HP 0")
	_check(torn.read_state().heroes[1].hp == 0 and torn.read_state().heroes[1].max_hp == 27
		and torn.read_state().tear_counts.seamstress == 1,
		"Seamstress base max drops to 27 with 1 recorded tear")
	_refresh(f, 2)
	_project(f, [46, 27, 26], "torn Seamstress thick_felt_mantle suppressed to base 27")
	_check(torn.apply_rest("rest_m05_revival", torn.read_state().heroes, true).ok,
		"Rest revival heals party")
	_refresh(f, 2)
	_check(torn.read_state().heroes[1].hp == 9, "Rest revived Seamstress to floor(27/3)=9 HP")
	_project(f, [46, 37, 26], "Rest revival reactivates thick_felt_mantle +10 (27+10=37)")

	# AC4: Rest re-sew/swap (costs 1 scrap)
	_check(w.start_rest("rest_m05_session", w.get_snapshot()).ok, "Rest session opens")
	# Swap reinforced_patchcoat on Warden with thick_felt_mantle on Seamstress
	var swap_res := w.re_sew("reinforced_patchcoat", "warden", "seamstress",
		"rest_m05_session", "swap_ws_m05", w.get_snapshot())
	_check(swap_res.ok and swap_res.receipt.exchanged_id == "thick_felt_mantle"
		and swap_res.receipt.scrap_delta == -1 and w.get_snapshot().scraps == 1,
		"occupied coat swap costs 1 scrap and preserves both patch IDs")
	# Warden now wears thick_felt_mantle (+10 -> 37+10=47), Seamstress wears reinforced_patchcoat (+9 -> 27+9=36), Tinker 26
	_project(f, [47, 36, 26], "after swap Warden +10 (47) and Seamstress +9 (36)")

	# Transfer thick_felt_mantle from Warden to empty Tinker (costs 1 scrap)
	var move_res := w.re_sew("thick_felt_mantle", "warden", "tinker",
		"rest_m05_session", "move_wt_m05", w.get_snapshot())
	_check(move_res.ok and move_res.receipt.exchanged_id == ""
		and move_res.receipt.scrap_delta == -1 and w.get_snapshot().scraps == 0,
		"empty coat transfer costs 1 scrap")
	# Warden has no coat (37), Seamstress wears reinforced_patchcoat (+9 -> 36), Tinker wears thick_felt_mantle (+10 -> 36)
	_project(f, [37, 36, 36], "Warden empty (37), Seamstress wears +9 (36), Tinker wears +10 (36)")
	_check(w.end_rest("rest_m05_session", w.get_snapshot()).ok, "Rest session closes")

	# AC4: Sew replacement on Seamstress (occupied sew yields 1 scrap)
	var replace_res := _sew(w, "coat_extra", "seamstress", "replace_m05_seamstress")
	_check(replace_res.ok and replace_res.receipt.displaced_id == "reinforced_patchcoat"
		and replace_res.receipt.scrap_delta == 1 and w.get_snapshot().scraps == 1
		and not w.get_snapshot().owned.has("reinforced_patchcoat")
		and w.get_snapshot().worn.seamstress.COAT == "coat_extra",
		"sewing over reinforced_patchcoat destroys displaced coat and grants 1 scrap")
	# Warden empty (37), Seamstress coat_extra (+0 -> 27), Tinker thick_felt_mantle (+10 -> 36)
	_project(f, [37, 27, 36], "replaced coat gives no bonus, Tinker retains +10 (36)")
