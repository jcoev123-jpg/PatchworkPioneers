extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_catalog()
	_test_authored_cards_and_negative_cases()
	_test_torn_mend_and_resew()
	_test_bad_authorities_and_slots()
	if failures.is_empty():
		print("combat_m05_head_patch_rules_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_m05_head_patch_rules_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, what: String) -> void:
	checks += 1
	if not value:
		failures.append(what)


func _json(path: String) -> Variant:
	var source := FileAccess.get_file_as_string(path)
	_check(not source.is_empty(), path + " is readable")
	return JSON.parse_string(source)


func _test_catalog() -> void:
	var records: Variant = _json("res://data/patches/m05_head_patches.json")
	if typeof(records) != TYPE_ARRAY:
		_check(false, "M05 patch records are an array")
		return
	var expected := {
		"bloodstitch_bonnet": ["HEAD", "card_bleed_bonus", 1],
		"button_glass_visor": ["HEAD", "card_exposed_bonus", 1],
		"stern_seam_cap": ["HEAD", "card_weak_bonus", 1],
		"reinforced_browband": ["HEAD", "card_block_bonus", 2],
	}
	var by_id := {}
	for record in records:
		if not (record is Dictionary):
			_check(false, "patch entry is an object")
			continue
		var id: Variant = record.get("id")
		_check(not by_id.has(id), "unique authored patch id " + str(id))
		by_id[id] = record
	for id in expected:
		var item: Variant = by_id.get(id, {})
		_check(item is Dictionary and item.size() == 4
			and item.get("id") == id and item.get("slot") == expected[id][0]
			and item.get("effect") == expected[id][1]
			and item.get("amount") == expected[id][2],
			"exact named M05 catalog contract for " + id)
	_check(by_id.size() == expected.size(), "M05's independent catalog has no foreign records")
	var original: Variant = _json("res://data/patches/initial_patch_slots.json")
	var found_badge := false
	if original is Array:
		for item in original:
			if item is Dictionary and item.get("id") == "stitched_badge":
				found_badge = item.get("slot") == "HEAD"
	_check(found_badge, "original Stitched Badge is still HEAD")
	var attack: Variant = _json("res://data/patches/m04_attack_patches.json")
	var found_eye := false
	if attack is Array:
		for item in attack:
			if item is Dictionary and item.get("id") == "button_eye":
				found_eye = item.get("slot") == "HEAD" and item.get("effect") == "first_attack_exposed" and item.get("amount") == 1
	_check(found_eye, "existing Button Eye first-hit status rule unchanged")


func _party() -> Array:
	var authored: Variant = _json("res://data/heroes/starter_party.json")
	if not (authored is Array) or authored.size() != 3:
		_check(false, "genuine hero catalog has three entries")
		return []
	var definitions: Array = authored.duplicate(true)
	for record in definitions:
		record["max_hp"] = int(record["max_hp"])
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "CombatParty accepts authentic roster")
	if not party.is_valid():
		return []
	var heroes: Array = party.get_heroes()
	_check(heroes[0]["id"] == "warden" and heroes[0]["position"] == 1 and heroes[0]["hp"] == 40
		and heroes[1]["id"] == "seamstress" and heroes[1]["position"] == 2 and heroes[1]["hp"] == 30
		and heroes[2]["id"] == "tinker" and heroes[2]["position"] == 3 and heroes[2]["hp"] == 26,
		"authentic roster identity HP and positions verified")
	return heroes


func _fixture() -> Dictionary:
	var heroes := _party()
	if heroes.is_empty():
		return {}
	var m05: Variant = _json("res://data/patches/m05_head_patches.json")
	var original: Variant = _json("res://data/patches/initial_patch_slots.json")
	if not (m05 is Array) or not (original is Array):
		return {}
	var definitions := []
	var owned := []
	for record in m05 + original:
		definitions.append({"id": record["id"], "slot": record["slot"]})
		owned.append(record["id"])
	var wardrobe := RunPatchWardrobe.new(heroes, owned, definitions, 6, 12,
		["seamstress_prick", "warden_brace"], 7319)
	var torn := RunTornMending.new(heroes)
	_check(wardrobe.is_valid() and torn.is_valid(), "real matching authorities are valid")
	if not wardrobe.is_valid() or not torn.is_valid():
		return {}
	return {"wardrobe": wardrobe, "torn": torn}


func _sew(w: RunPatchWardrobe, id: String, hero: String, op: String) -> bool:
	var result := w.sew(id, hero, "HEAD", op, w.get_snapshot())
	_check(result.get("ok") == true and result.get("receipt", {}).get("slot") == "HEAD",
		"canonical sew " + id + " -> " + hero)
	return result.get("ok") == true


func _unchanged(w: RunPatchWardrobe, t: RunTornMending,
		rules: CombatM05HeadPatchRules, wearer: String, card: String,
		key: String, amount: int) -> void:
	var ws := w.get_snapshot()
	var ts := t.read_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = 89233
	var random_before := rng.state
	for i in range(3):
		_check(rules.get_bonus(wearer, card, key) == amount,
			"repeat deterministic bonus " + wearer + " / " + card + " / " + key)
	_check(w.get_snapshot() == ws and t.read_state() == ts and rng.state == random_before,
		"bonus preview never changes snapshots or seeded run RNG")


func _test_authored_cards_and_negative_cases() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f["wardrobe"]
	var t: RunTornMending = f["torn"]
	var rules := CombatM05HeadPatchRules.new()
	_check(rules.get_bonus("seamstress", "seamstress_prick", "bleed") == 0,
		"unbound service never grants anything")
	if not _sew(w, "stern_seam_cap", "warden", "weak_head") 			or not _sew(w, "bloodstitch_bonnet", "seamstress", "bleed_head") 			or not _sew(w, "button_glass_visor", "tinker", "exposed_head"):
		return
	_check(rules.bind_wardrobe(w, t), "simultaneous living different HEAD wearers bind")
	var projection := rules.read_projection()
	_check(projection.get("ok") == true and projection["heads"].size() == 3
		and projection["heads"]["warden"]["patch_id"] == "stern_seam_cap"
		and projection["heads"]["seamstress"]["patch_id"] == "bloodstitch_bonnet"
		and projection["heads"]["tinker"]["patch_id"] == "button_glass_visor",
		"read-only inspectable three-wearer projection")
	_unchanged(w, t, rules, "seamstress", "seamstress_prick", "bleed", 1)
	_unchanged(w, t, rules, "tinker", "tinker_rivet_shot", "exposed", 1)
	_unchanged(w, t, rules, "warden", "warden_shield_bash", "weak", 1)
	_unchanged(w, t, rules, "seamstress", "seamstress_running_stitch_plus", "bleed", 1)
	_unchanged(w, t, rules, "tinker", "tinker_sight_glass_plus", "exposed", 1)
	_check(rules.get_bonus("seamstress", "seamstress_hemorrhage_hem_plus", "bleed") == 0
		and rules.get_bonus("seamstress", "seamstress_mend", "bleed") == 0,
		"positive bleed_multiplier and healing never fabricate bleed")
	_check(rules.get_bonus("warden", "warden_strike_plus", "weak") == 0
		and rules.get_bonus("tinker", "tinker_pop_shot", "exposed") == 0,
		"real damage-only cards do not gain a status")
	_check(rules.get_bonus("warden", "seamstress_snag", "weak") == 0
		and rules.get_bonus("seamstress", "warden_shield_bash", "bleed") == 0
		and rules.get_bonus("tinker", "seamstress_red_thread_plus", "exposed") == 0,
		"cross-owner cards never earn HEAD powers")
	_check(rules.get_bonus("seamstress", "seamstress_prick_plus_plus", "bleed") == 0
		and rules.get_bonus("seamstress", "fake_seamstress_prick", "bleed") == 0
		and rules.get_bonus("seamstress", "seamstress_prick", "exposed") == 0
		and rules.get_bonus("seamstress", "seamstress_prick", "damage") == 0
		and rules.get_bonus("fake_hero", "seamstress_prick", "bleed") == 0,
		"fabricated upgrade, namespaced fake, absent effect, wrong key and owner rejected")
	_check(rules.get_bonus(null, 99, true) == 0, "malformed query values rejected")
	var starter := StarterCards.new()
	var seam := SeamstressPoolCards.new()
	var tinker := TinkerPoolCards.new()
	var warden := WardenPoolCards.new()
	var expected_prick := starter.get_definition("seamstress_prick")
	var expected_rivet := tinker.get_definition("tinker_rivet_shot")
	var expected_bash := starter.get_definition("warden_shield_bash")
	var expected_brace := starter.get_definition("warden_brace")
	var expected_guard := warden.get_definition("warden_patch_guard_plus")
	_check(expected_prick["cost"] == 1 and expected_prick["effects"] == {"damage": 3, "bleed": 2}
		and expected_rivet["cost"] == 1 and expected_rivet["effects"] == {"damage": 4, "exposed": 1}
		and expected_bash["cost"] == 2 and expected_bash["effects"] == {"damage": 8, "weak": 1},
		"source damage, status and energy cost independently canonical")
	_check(seam.get_definition("seamstress_running_stitch_plus")["effects"]["bleed"] == 4
		and expected_guard["target_kind"] == "ally_single"
		and expected_guard["effects"]["block"] == 11,
		"authored upgrade and ally-target definition verified")
	_check(_sew(w, "reinforced_browband", "warden", "replace_cap"),
		"reinforced HEAD replaces cap through authentic one-slot transaction")
	_check(rules.get_bonus("warden", "warden_brace", "block") == 0,
		"stale binding invalid immediately on fresh sew")
	_check(rules.read_projection().get("ok") == false, "stale projection fails closed")
	_check(rules.bind_wardrobe(w, t), "rebind after replacement")
	_unchanged(w, t, rules, "warden", "warden_brace", "block", 2)
	_unchanged(w, t, rules, "warden", "warden_patch_guard_plus", "block", 2)
	_unchanged(w, t, rules, "warden", "warden_brace_plus", "block", 2)
	_check(rules.get_bonus("warden", "warden_shield_bash", "weak") == 0
		and rules.get_bonus("warden", "warden_strike", "block") == 0
		and rules.get_bonus("warden", "warden_bastion_quilt", "block") == 0
		and rules.get_bonus("tinker", "tinker_spare_parts_plus", "block") == 0,
		"only authored positive block on the genuine HEAD wearer; block_all not inferred")
	_check(starter.get_definition("seamstress_prick") == expected_prick
		and tinker.get_definition("tinker_rivet_shot") == expected_rivet
		and starter.get_definition("warden_shield_bash") == expected_bash
		and starter.get_definition("warden_brace") == expected_brace
		and warden.get_definition("warden_patch_guard_plus") == expected_guard,
		"all original authored costs damage targets and effects stay untouched")
	projection["heads"]["warden"]["amount"] = 999
	projection["heads"]["warden"]["patch_id"] = "forged"
	_check(rules.read_projection()["heads"]["warden"]["amount"] == 2
		and rules.get_bonus("warden", "warden_brace", "block") == 2,
		"returned nested projection is detached from internal rules")


func _refresh(w: RunPatchWardrobe, t: RunTornMending, scraps: int = -1) -> bool:
	var old := w.get_snapshot()
	var next_scraps: int = old["scraps"] if scraps == -1 else scraps
	var ok := w.refresh_run_context(t.read_state()["heroes"], old["owned"],
		next_scraps, old["gold"], old["cards"], old)
	_check(ok, "wardrobe refresh confirms torn authority's new roster")
	return ok


func _test_torn_mend_and_resew() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f["wardrobe"]
	var t: RunTornMending = f["torn"]
	if not _sew(w, "reinforced_browband", "warden", "brow") 			or not _sew(w, "bloodstitch_bonnet", "seamstress", "bonnet"):
		return
	var rules := CombatM05HeadPatchRules.new()
	_check(rules.bind_wardrobe(w, t), "initial two-hero binding succeeds")
	var start: Array = t.read_state()["heroes"]
	var finish := start.duplicate(true)
	finish[0]["hp"] = 0
	finish[0]["block"] = 6
	var battle := t.observe_battle_end("real_battle_1", start, finish)
	_check(battle.get("ok") == true and battle["heroes"][0]["max_hp"] == 37
		and battle["heroes"][0]["hp"] == 0, "authentic battle witness tears Warden -3 max HP")
	_check(rules.get_bonus("warden", "warden_brace", "block") == 0
		and rules.read_projection().get("ok") == false,
		"torn mutation invalidates earlier living projection")
	_check(not rules.bind_wardrobe(w, t), "mismatched wardrobe/torn snapshots cannot bind")
	if not _refresh(w, t):
		return
	_check(rules.bind_wardrobe(w, t), "matching torn pair binds read-only")
	_check(rules.get_bonus("warden", "warden_patch_guard_plus", "block") == 0
		and rules.get_bonus("seamstress", "seamstress_prick", "bleed") == 1,
		"torn wearer inert while other living wearer remains active")
	var before_mend := t.read_state()
	var mend := t.choose_mend("real_map_mend", "mend_receipt_1", "warden", 1,
		6, before_mend["heroes"], true)
	_check(mend.get("ok") == true and mend.get("remaining_scraps") == 4
		and mend["heroes"][0]["hp"] == 9 and mend["heroes"][0]["max_hp"] == 37,
		"real map mend revives for floor(37/4) and spends exactly two scraps")
	if not mend.get("ok"):
		return
	_check(rules.get_bonus("warden", "warden_brace", "block") == 0
		and not rules.bind_wardrobe(w, t), "mend needs refreshed wardrobe and rebind")
	if not _refresh(w, t, mend["remaining_scraps"]):
		return
	_check(rules.bind_wardrobe(w, t), "post-mend matching authorities bind")
	_unchanged(w, t, rules, "warden", "warden_brace", "block", 2)
	_check(w.start_rest("rest_for_swap", w.get_snapshot()).get("ok") == true,
		"genuine Rest node opened for re-sew")
	_check(rules.get_bonus("warden", "warden_brace", "block") == 0,
		"Rest authority revision invalidates binding")
	var swapped := w.re_sew("reinforced_browband", "warden", "seamstress",
		"rest_for_swap", "swapped_heads", w.get_snapshot())
	_check(swapped.get("ok") == true and swapped["receipt"]["exchanged_id"] == "bloodstitch_bonnet"
		and swapped["receipt"]["scrap_delta"] == -1,
		"canonical paid Rest re-sew swaps occupied HEAD patches")
	if not swapped.get("ok"):
		return
	_check(rules.bind_wardrobe(w, t), "fresh binding after paid swap succeeds")
	var projection := rules.read_projection()
	_check(projection["heads"]["warden"]["patch_id"] == "bloodstitch_bonnet"
		and projection["heads"]["seamstress"]["patch_id"] == "reinforced_browband",
		"real slot swap changes genuine HEAD owners")
	_check(rules.get_bonus("warden", "warden_brace", "block") == 0
		and rules.get_bonus("seamstress", "seamstress_prick", "bleed") == 0,
		"old bonus owners cannot retain swapped powers")
	_unchanged(w, t, rules, "seamstress", "seamstress_stitch_up_plus", "block", 2)
	_check(w.get_snapshot()["scraps"] == 3 and t.read_state()["heroes"][0]["hp"] == 9,
		"preview does not spend extra scrap or change post-mend HP")


func _test_bad_authorities_and_slots() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f["wardrobe"]
	var t: RunTornMending = f["torn"]
	var rules := CombatM05HeadPatchRules.new()
	_check(not rules.bind_wardrobe(null, null)
		and not rules.bind_wardrobe(RunPatchWardrobe.new(), t)
		and not rules.bind_wardrobe(w, RunTornMending.new()),
		"null and invalid authorities never bind")
	_check(rules.read_projection() == {"ok": false, "heads": {}}
		and rules.get_bonus("seamstress", "seamstress_prick", "bleed") == 0,
		"invalid authority projection grants nothing")
	var party := _party()
	if party.is_empty():
		return
	var mis_slot := RunPatchWardrobe.new(party, ["bloodstitch_bonnet"],
		[{"id": "bloodstitch_bonnet", "slot": "ARM"}], 2)
	_check(mis_slot.is_valid(), "authentic wardrobe can represent a mis-slotted test catalog")
	var sew := mis_slot.sew("bloodstitch_bonnet", "seamstress", "ARM",
		"bad_slot", mis_slot.get_snapshot())
	_check(sew.get("ok") == true, "mis-slotted ARM installed via real wardrobe API")
	_check(not rules.bind_wardrobe(mis_slot, t)
		and rules.get_bonus("seamstress", "seamstress_prick", "bleed") == 0,
		"M05 ID forged onto ARM slot rejected on bind")
	var unknown := RunPatchWardrobe.new(party, ["counterfeit_hat"],
		[{"id": "counterfeit_hat", "slot": "HEAD"}], 2)
	_check(unknown.is_valid() and unknown.sew("counterfeit_hat", "seamstress",
		"HEAD", "counterfeit_sew", unknown.get_snapshot()).get("ok") == true,
		"genuine wardrobe tracks unknown owned HEAD ID without inventing catalog power")
	_check(rules.bind_wardrobe(unknown, t)
		and rules.get_bonus("seamstress", "seamstress_prick", "bleed") == 0
		and rules.read_projection()["heads"]["seamstress"].is_empty(),
		"unknown HEAD patch never manufactures effect")
	_check(rules.bind_wardrobe(w, t) and _sew(w, "bloodstitch_bonnet",
		"seamstress", "now_sewn"), "valid bind followed by real mutation")
	_check(rules.get_bonus("seamstress", "seamstress_prick", "bleed") == 0,
		"no stale bonus after fresh sew without explicit rebind")
