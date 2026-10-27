extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_p8_slots()
	_test_authored_switchback()
	_test_slots_and_replacement()
	_test_rest_moves_and_swaps()
	_test_torn_mend_and_rest()
	_test_rejections_and_invalid_inputs()
	_test_detachment_and_rng_replay()
	if failures.is_empty():
		print("run_patch_wardrobe_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_patch_wardrobe_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _test_p8_slots() -> void:
	var heroes := _party()
	var wardrobe := RunPatchWardrobe.new(heroes, ["relay_bobbin", "hearth_lining"],
		RunAuthoredPatchDefinitions.load_definitions(), 0)
	_check(wardrobe.is_valid(), "P8 owned definitions admit an actual wardrobe")
	_check(wardrobe.sew("relay_bobbin", "tinker", "HEAD", "p8-head", wardrobe.get_snapshot()).ok,
		"Relay Bobbin sews into existing HEAD")
	_check(wardrobe.sew("hearth_lining", "warden", "COAT", "p8-coat", wardrobe.get_snapshot()).ok,
		"Hearth Lining sews into existing COAT")
	var torn := RunTornMending.new(heroes)
	var summary := RunPatchWearerSummary.summarize(wardrobe, torn.read_state())
	_check(summary.get("ok", false), "both P8 wearers retain authenticated summary")
	var snapshot := wardrobe.get_snapshot()
	_check(not wardrobe.sew("relay_bobbin", "warden", "ARM", "bad-p8", snapshot).ok
		and wardrobe.get_snapshot() == snapshot, "P8 wrong-slot refusal leaves all state intact")


func _party() -> Array:
	var source := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var authored: Variant = JSON.parse_string(source)
	_check(typeof(authored) == TYPE_ARRAY and authored.size() == 3,
		"real starter party catalog and three actors are present")
	if typeof(authored) != TYPE_ARRAY or authored.size() != 3:
		return []
	var definitions := []
	for hero in authored:
		definitions.append({"id": hero["id"], "max_hp": int(hero["max_hp"]),
			"art_path": hero["art_path"]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "CombatParty accepts real Warden Seamstress Tinker definitions")
	if not party.is_valid():
		return []
	var heroes: Array = party.get_heroes()
	_check(heroes[0]["id"] == "warden" and heroes[0]["position"] == 1
		and heroes[0]["hp"] == 40 and heroes[0]["max_hp"] == 40
		and heroes[1]["id"] == "seamstress" and heroes[1]["position"] == 2
		and heroes[1]["hp"] == 30 and heroes[2]["id"] == "tinker"
		and heroes[2]["position"] == 3 and heroes[2]["hp"] == 26,
		"actual authored hero identities positions and HP are preconditions")
	return heroes


func _definitions() -> Array:
	# Only fixture metadata; no Shop catalog alteration or combat powers.
	return [
		{"id": "button_eye", "slot": "HEAD"},
		{"id": "button_eye_alt", "slot": "HEAD"},
		{"id": "head_mate", "slot": "HEAD"},
		{"id": "pincushion_arm", "slot": "ARM"},
		{"id": "quilted_coat", "slot": "COAT"},
		{"id": "coat_extra", "slot": "COAT"}
	]


func _test_authored_switchback() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(raw is Array, "authored M04 patch catalog parses")
	if not raw is Array:
		return
	var expected := {
		"button_eye": {"slot": "HEAD", "effect": "first_attack_exposed", "amount": 1},
		"pincushion_arm": {"slot": "ARM", "effect": "card_attack_bonus", "amount": 1},
		"switchback_button": {"slot": "HEAD", "effect": "different_owner_followup_block",
			"amount": 2, "once_per_player_turn": true},
	}
	var counts := {}
	var definitions := []
	for entry in raw:
		_check(entry is Dictionary and entry.has("id") and entry.has("slot"),
			"catalog entry has wardrobe metadata")
		if not entry is Dictionary or not entry.has("id") or not entry.has("slot"):
			continue
		definitions.append({"id": entry.id, "slot": entry.slot})
		if not expected.has(entry.id):
			continue
		counts[entry.id] = counts.get(entry.id, 0) + 1
		for key in expected[entry.id]:
			_check(entry.get(key) == expected[entry.id][key], entry.id + " authored " + key)
	for id in expected:
		_check(counts.get(id, 0) == 1, "exactly one authored record for " + id)
	var attacks := CombatPatchAttackRules.new()
	_check(attacks._valid_catalog(raw), "attack validator coexists with authored non-attack patch")
	for id in ["button_eye", "pincushion_arm"]:
		var absent: Array = raw.filter(func(entry): return entry.id != id)
		_check(not attacks._valid_catalog(absent), "attack validator still requires " + id)
		for key in ["slot", "effect", "amount"]:
			var malformed: Array = raw.duplicate(true)
			for entry in malformed:
				if entry.id == id:
					entry[key] = "invalid"
			_check(not attacks._valid_catalog(malformed), "attack validator rejects malformed " + id + " " + key)
	var duplicate: Array = raw.duplicate(true)
	duplicate.append(raw[0].duplicate(true))
	_check(not attacks._valid_catalog(duplicate) and not attacks._valid_catalog([])
		and not attacks._valid_catalog({}) and not attacks._valid_catalog([{}]),
		"attack validator preserves duplicate/missing/malformed rejection")
	var heroes := _party()
	_check(not RunPatchWardrobe.new(heroes, ["switchback_button"], raw, 0).is_valid(),
		"wardrobe rejects full effect definitions; metadata must be normalized")
	var wardrobe := RunPatchWardrobe.new(heroes, ["switchback_button"], definitions, 0)
	_check(wardrobe.is_valid(), "wardrobe accepts actual catalog id/slot projection")
	_reject(wardrobe, "Switchback cannot occupy ARM", func(): return wardrobe.sew(
		"switchback_button", "warden", "ARM", "wrong_slot", wardrobe.get_snapshot()))
	_check(_sew(wardrobe, "switchback_button", "warden", "HEAD", "switchback").ok,
		"authored Switchback sews onto HEAD")
	var before := wardrobe.get_snapshot()
	var torn := RunTornMending.new(heroes)
	var active := wardrobe.project_active(torn.read_state())
	_check(active.ok and active.active.warden == ["switchback_button"],
		"living wearer projects authored Switchback")
	var start: Array = torn.read_state().heroes
	var end := start.duplicate(true)
	end[0].hp = 0
	_check(torn.observe_battle_end("switchback_tear", start, end).ok,
		"genuine tear commits before testing inactive projection")
	active = wardrobe.project_active(torn.read_state())
	_check(active.ok and active.active.warden == [] and wardrobe.get_snapshot() == before,
		"tear masks Switchback without changing its worn slot or resources")


func _owned() -> Array:
	# Real M03 Shop IDs deliberately have NO inferred slot.
	var source := FileAccess.get_file_as_string("res://data/shop/initial_offers.json")
	var authored: Variant = JSON.parse_string(source)
	_check(typeof(authored) == TYPE_DICTIONARY and authored.has("trinkets"),
		"real initial Shop list is readable")
	var result := ["button_eye", "button_eye_alt", "head_mate",
		"pincushion_arm", "quilted_coat", "coat_extra"]
	if typeof(authored) == TYPE_DICTIONARY and authored.has("trinkets"):
		var shop_ids: Array = authored["trinkets"]
		for id in ["stitched_badge", "spare_spool"]:
			var matches := shop_ids.filter(func(entry): return entry.get("id") == id)
			_check(matches.size() == 1, "Shop retains unique unclassified owned ID " + id)
			result.append(id)
	return result


func _new(scraps: int = 1) -> RunPatchWardrobe:
	var party := _party()
	var owned := _owned()
	var defs := _definitions()
	var original_party := party.duplicate(true)
	var original_owned := owned.duplicate(true)
	var original_defs := defs.duplicate(true)
	var wardrobe := RunPatchWardrobe.new(party, owned, defs, scraps,
		170, ["warden_strike", "seamstress_prick"], 8197)
	_check(wardrobe.is_valid(), "valid fixture has an owned M03 inventory and all three heroes")
	_check(party == original_party and owned == original_owned and defs == original_defs,
		"constructor never mutates its caller data")
	return wardrobe


func _sew(w: RunPatchWardrobe, id: String, owner: String, slot: String, op: String) -> Dictionary:
	return w.sew(id, owner, slot, op, w.get_snapshot())


func _reject(w: RunPatchWardrobe, label: String, action: Callable) -> void:
	var prior := w.get_snapshot()
	var result: Dictionary = action.call()
	_check(result == {"ok": false, "state": prior},
		label + " returns detached failure with no receipt")
	_check(w.get_snapshot() == prior, label + " cannot spend mutate or claim an ID")


func _test_slots_and_replacement() -> void:
	var w := _new()
	if not w.is_valid():
		return
	_check(w.has_method("sew") and w.has_method("re_sew")
		and w.has_method("start_rest") and w.has_method("end_rest")
		and w.has_method("project_active") and w.has_method("get_snapshot"),
		"public ledger transaction and projection APIs exist")
	var initial := w.get_snapshot()
	var expected := initial.duplicate(true)
	var a := _sew(w, "button_eye", "warden", "HEAD", "sew_head")
	expected.worn.warden.HEAD = "button_eye"
	expected.operation_ids.append("sew_head")
	_check(a.ok and a.has("receipt") and a.receipt.scrap_delta == 0
		and a.receipt.displaced_id == "" and a.receipt.slot == "HEAD",
		"empty HEAD sewing returns free exact receipt")
	_check(w.get_snapshot().worn == expected.worn
		and w.get_snapshot().scraps == initial.scraps
		and w.get_snapshot().owned == initial.owned,
		"HEAD changes only Warden slot no owners or scraps")
	var b := _sew(w, "pincushion_arm", "seamstress", "ARM", "sew_arm")
	expected.worn.seamstress.ARM = "pincushion_arm"
	expected.operation_ids.append("sew_arm")
	_check(b.ok and b.receipt.scrap_delta == 0, "ARM sewn to other hero at zero scrap")
	var c := _sew(w, "quilted_coat", "tinker", "COAT", "sew_coat")
	expected.worn.tinker.COAT = "quilted_coat"
	expected.operation_ids.append("sew_coat")
	_check(c.ok and c.receipt.slot == "COAT", "COAT sewn to third hero")
	_check(w.get_snapshot().worn == expected.worn, "three slots per hero preserve every empty capacity")
	var before_replace := w.get_snapshot()
	var replaced := _sew(w, "button_eye_alt", "warden", "HEAD", "replace_head")
	_check(replaced.ok and replaced.receipt.displaced_id == "button_eye"
		and replaced.receipt.scrap_delta == 1 and replaced.receipt.slot == "HEAD",
		"exact single-slot replacement pays one scrap")
	var after := w.get_snapshot()
	_check(after.worn.warden == {"HEAD": "button_eye_alt", "ARM": "", "COAT": ""}
		and after.worn.seamstress == before_replace.worn.seamstress
		and after.worn.tinker == before_replace.worn.tinker,
		"replacement never touches other slots or wearers")
	_check(after.owned.size() == before_replace.owned.size() - 1
		and not after.owned.has("button_eye") and after.owned.has("button_eye_alt")
		and after.scraps == before_replace.scraps + 1,
		"displaced ID destroyed from inventory and exactly one scrap gained")
	_check(after.gold == initial.gold and after.cards == initial.cards
		and after.seed == initial.seed and after.heroes == initial.heroes
		and after.definitions == initial.definitions,
		"gold deck run seed HP statuses and authored metadata remain identical")
	_reject(w, "displaced no longer owned", func():
		return w.sew("button_eye", "seamstress", "HEAD", "lost", w.get_snapshot()))


func _test_rest_moves_and_swaps() -> void:
	var w := _new(1)
	if not w.is_valid():
		return
	_check(_sew(w, "button_eye", "warden", "HEAD", "first").ok
		and _sew(w, "head_mate", "seamstress", "HEAD", "second").ok
		and _sew(w, "button_eye_alt", "warden", "HEAD", "third").ok,
		"both HEAD slots and the scrap-earning replacement are installed")
	var before := w.get_snapshot()
	_check(before.scraps == 2 and before.worn.warden.HEAD == "button_eye_alt"
		and before.worn.seamstress.HEAD == "head_mate",
		"actual owned patches and two scraps exist for two paid operations")
	var recovery := RunRestRecovery.new(_party())
	_check(not recovery.is_consumed(), "real Rest heal has not been chosen")
	_reject(w, "outside Rest", func(): return w.re_sew("button_eye_alt",
		"warden", "tinker", "rest_a", "move", w.get_snapshot()))
	var opened := w.start_rest("rest_a", w.get_snapshot())
	_check(opened.ok and w.get_snapshot().rest_id == "rest_a"
		and not recovery.is_consumed(), "opening Rest does not choose or consume healing")
	_reject(w, "wrong active Rest", func(): return w.re_sew("button_eye_alt",
		"warden", "tinker", "other", "move", w.get_snapshot()))
	var pre_move := w.get_snapshot()
	var moved := w.re_sew("button_eye_alt", "warden", "tinker",
		"rest_a", "move", pre_move)
	var after_move := w.get_snapshot()
	_check(moved.ok and moved.receipt.exchanged_id == ""
		and moved.receipt.slot == "HEAD" and moved.receipt.scrap_delta == -1
		and after_move.worn.warden.HEAD == "" and after_move.worn.tinker.HEAD == "button_eye_alt",
		"paid Rest move empties source and fills matching destination")
	_check(after_move.scraps == pre_move.scraps - 1 and after_move.owned == pre_move.owned
		and after_move.worn.seamstress == pre_move.worn.seamstress,
		"move costs one scrap without loss of owned IDs or other hero changes")
	var swapped := w.re_sew("head_mate", "seamstress", "tinker",
		"rest_a", "swap", w.get_snapshot())
	var after_swap := w.get_snapshot()
	_check(swapped.ok and swapped.receipt.exchanged_id == "button_eye_alt"
		and after_swap.worn.tinker.HEAD == "head_mate"
		and after_swap.worn.seamstress.HEAD == "button_eye_alt"
		and after_swap.worn.warden.HEAD == "",
		"same-named slot swap retains both identities")
	_check(after_swap.scraps == 0 and after_swap.owned == after_move.owned
		and after_swap.gold == before.gold and after_swap.cards == before.cards
		and after_swap.heroes == before.heroes,
		"swap costs one scrap and neither alters other resources nor HP")
	_check(not recovery.is_consumed() and after_swap.rest_id == "rest_a",
		"both re-sews leave real Rest heal/upgrade/stitch choice unconsumed")
	_reject(w, "unaffordable third Rest re-sew", func(): return w.re_sew(
		"head_mate", "tinker", "warden", "rest_a", "unaffordable", w.get_snapshot()))
	_reject(w, "same hero", func(): return w.re_sew(
		"head_mate", "tinker", "tinker", "rest_a", "same", w.get_snapshot()))
	_check(w.end_rest("rest_a", w.get_snapshot()).ok, "Rest ends without consuming heal choice")
	_reject(w, "old rest cannot be reused", func(): return w.start_rest("rest_a", w.get_snapshot()))
	_reject(w, "outside Rest after close", func(): return w.re_sew(
		"head_mate", "tinker", "seamstress", "rest_a", "late", w.get_snapshot()))
	_check(not recovery.is_consumed(), "Rest choice remains available on closed wardrobe")


func _test_torn_mend_and_rest() -> void:
	var party := _party()
	var w := _new(2)
	var mending := RunTornMending.new(party)
	_check(w.is_valid() and mending.is_valid(), "real wardrobe and torn-run services initialized")
	if not w.is_valid() or not mending.is_valid():
		return
	_check(_sew(w, "button_eye", "warden", "HEAD", "torn_w").ok
		and _sew(w, "pincushion_arm", "seamstress", "ARM", "torn_s").ok,
		"two actors have recorded sewn patches before any battle")
	var before_tear := w.get_snapshot()
	var living := w.project_active(mending.read_state())
	_check(living.ok and living.active.warden == ["button_eye"]
		and living.active.seamstress == ["pincushion_arm"]
		and living.active.tinker == [], "real living hero state activates only worn IDs")
	var combat_start: Array = mending.read_state().heroes
	var combat_end: Array = combat_start.duplicate(true)
	combat_end[0].hp = 0
	_check(mending.observe_battle_end("tear_a", combat_start, combat_end).ok,
		"real RunTornMending witnesses a battle tear")
	var torn := mending.read_state()
	_check(torn.heroes[0].hp == 0 and torn.heroes[0].max_hp == 37
		and torn.tear_counts.warden == 1, "actual tear costs three maximum HP")
	var masked := w.project_active(torn)
	_check(masked.ok and masked.active.warden == []
		and masked.active.seamstress == ["pincushion_arm"]
		and masked.worn == before_tear.worn and masked.worn.warden.HEAD == "button_eye",
		"torn wearer becomes inactive while recorded patch stays worn")
	var mend := mending.choose_mend("map_a", "mend_a", "warden", 1, 2, torn.heroes, true)
	_check(mend.ok and mend.remaining_scraps == 0
		and mend.heroes[0].hp == 9 and mend.heroes[0].max_hp == 37,
		"real paid two-scrap mend revives floor(37 times 25%) to 9")
	var restored := w.project_active(mending.read_state())
	_check(restored.ok and restored.active.warden == ["button_eye"]
		and restored.active.seamstress == ["pincushion_arm"]
		and w.get_snapshot() == before_tear,
		"mend reactivates previously sewn patches with no wardrobe transaction")
	var second := RunTornMending.new(party)
	var start_2: Array = second.read_state().heroes
	var end_2: Array = start_2.duplicate(true)
	end_2[0].hp = 0
	_check(second.observe_battle_end("tear_b", start_2, end_2).ok,
		"independent genuine Rest timeline first tears Warden")
	_check(w.project_active(second.read_state()).active.warden == [],
		"another real torn snapshot also masks Warden patch")
	var rest_before: Array = second.read_state().heroes
	var independent_heal := RunRestRecovery.new(rest_before).choose_heal()
	var rest := second.apply_rest("rest_b", rest_before, true)
	_check(rest.ok and rest.heroes == independent_heal.heroes
		and rest.heroes[0].hp == 12 and rest.heroes[0].max_hp == 37,
		"real Rest uses 1 HP revival plus floor(30% of 37), not map mend")
	_check(w.project_active(second.read_state()).active.warden == ["button_eye"]
		and w.get_snapshot() == before_tear,
		"Rest revival reactivates old patch without consuming a sew")
	var forged := torn.duplicate(true)
	forged.heroes[0].hp = -1
	_check(not w.project_active(forged).ok and w.get_snapshot() == before_tear,
		"malformed projection rejected without changing wardrobe")


func _test_rejections_and_invalid_inputs() -> void:
	var w := _new(3)
	if not w.is_valid():
		return
	for entry in [
		["missing ownership", "unowned", "warden", "HEAD", "a"],
		["Shop ID unknown slot", "stitched_badge", "warden", "HEAD", "b"],
		["other Shop ID unknown slot", "spare_spool", "warden", "ARM", "c"],
		["wrong authored slot", "button_eye", "warden", "ARM", "d"],
		["wrong wearer", "button_eye", "visitor", "HEAD", "e"],
		["wrong owner type", "button_eye", 4, "HEAD", "f"],
		["wrong ID type", 7, "warden", "HEAD", "g"],
		["wrong slot case", "button_eye", "warden", "head", "h"],
		["blank operation", "button_eye", "warden", "HEAD", ""]
	]:
		_reject(w, entry[0], func(): return w.sew(entry[1], entry[2],
			entry[3], entry[4], w.get_snapshot()))
	var old := w.get_snapshot()
	_check(w.sew("button_eye", "warden", "HEAD", "first", old).ok,
		"valid action still succeeds after every invalid proposal")
	_reject(w, "stale expected snapshot", func(): return w.sew(
		"pincushion_arm", "seamstress", "ARM", "second", old))
	var forged := w.get_snapshot()
	forged.receipt = "fake"
	_reject(w, "forged receipt", func(): return w.sew(
		"pincushion_arm", "seamstress", "ARM", "second", forged))
	forged = w.get_snapshot()
	forged.scraps += 100
	_reject(w, "forged state", func(): return w.sew(
		"pincushion_arm", "seamstress", "ARM", "second", forged))
	_reject(w, "reused operation", func(): return w.sew(
		"pincushion_arm", "seamstress", "ARM", "first", w.get_snapshot()))
	_reject(w, "duplicate worn ID on another wearer", func(): return w.sew(
		"button_eye", "seamstress", "HEAD", "second", w.get_snapshot()))
	_check(_sew(w, "pincushion_arm", "seamstress", "ARM", "second").ok,
		"rejected op IDs stay unclaimed and can later be used")
	_check(w.start_rest("r", w.get_snapshot()).ok, "valid Rest opened")
	_reject(w, "Rest re-sew foreign source", func(): return w.re_sew(
		"button_eye", "seamstress", "tinker", "r", "bad_source", w.get_snapshot()))
	_reject(w, "Rest re-sew source ID unowned", func(): return w.re_sew(
		"unknown", "warden", "tinker", "r", "bad_patch", w.get_snapshot()))
	_reject(w, "Rest re-sew invalid target", func(): return w.re_sew(
		"button_eye", "warden", "visitor", "r", "bad_target", w.get_snapshot()))
	_reject(w, "Rest stale snapshot", func(): return w.re_sew(
		"button_eye", "warden", "tinker", "r", "valid", old))
	var changed_rest := w.get_snapshot()
	changed_rest.rest_id = "counterfeit"
	_reject(w, "Rest forged receipt/context", func(): return w.re_sew(
		"button_eye", "warden", "tinker", "r", "valid", changed_rest))
	_check(w.re_sew("button_eye", "warden", "tinker", "r", "valid",
		w.get_snapshot()).ok, "valid Rest move still works after failed forged attempts")
	_reject(w, "Rest op replay", func(): return w.re_sew(
		"button_eye", "tinker", "warden", "r", "valid", w.get_snapshot()))
	_reject(w, "Rest close with stale receipt", func():
		return w.end_rest("r", old))
	_check(w.end_rest("r", w.get_snapshot()).ok, "Rest close after failed actions")

	var party := _party()
	var owned := _owned()
	var defs := _definitions()
	for bad in [
		[party.slice(0, 2), owned, defs, 2],
		[[party[0], party[0], party[2]], owned, defs, 2],
		[party, ["button_eye", "button_eye"], defs, 2],
		[party, ["button_eye", 7], defs, 2],
		[party, owned, [{"id": "bad", "slot": "HAND"}], 2],
		[party, owned, [{"id": "button_eye", "slot": "HEAD"}, {"id": "button_eye", "slot": "COAT"}], 2],
		[party, owned, defs, -1],
		[party, owned, defs, 2.5],
		[party, owned, defs, true]
	]:
		var service := RunPatchWardrobe.new(bad[0], bad[1], bad[2], bad[3])
		_check(not service.is_valid() and service.get_snapshot().worn == {}
			and not service.sew("button_eye", "warden", "HEAD", "no", service.get_snapshot()).ok,
			"invalid roster/ownership/metadata/currency never initializes or sews")
	var wrong_position := party.duplicate(true)
	wrong_position[0].position = 2
	var wrong_hp := party.duplicate(true)
	wrong_hp[0].hp = 0
	var foreign := party.duplicate(true)
	foreign[2].id = "outsider"
	for bad_party in [wrong_position, wrong_hp, foreign]:
		var rejected := RunPatchWardrobe.new(bad_party, owned, defs, 2)
		_check(not rejected.is_valid(), "wrong hero position HP or owner rejects admission")


func _timeline() -> Dictionary:
	var w := _new()
	if not w.is_valid():
		return {}
	var receipts := []
	receipts.append(_sew(w, "button_eye", "warden", "HEAD", "one"))
	receipts.append(_sew(w, "pincushion_arm", "seamstress", "ARM", "two"))
	receipts.append(_sew(w, "button_eye_alt", "warden", "HEAD", "three"))
	receipts.append(w.start_rest("rest", w.get_snapshot()))
	receipts.append(w.re_sew("button_eye_alt", "warden", "tinker",
		"rest", "four", w.get_snapshot()))
	receipts.append(w.re_sew("pincushion_arm", "seamstress", "tinker",
		"rest", "five", w.get_snapshot()))
	receipts.append(w.end_rest("rest", w.get_snapshot()))
	return {"receipts": receipts, "state": w.get_snapshot()}


func _test_detachment_and_rng_replay() -> void:
	seed(445501)
	var expected_global := randi()
	seed(445501)
	var local := RandomNumberGenerator.new()
	local.seed = 542331
	var local_seed: int = local.seed
	var local_state: int = local.state
	var first := _timeline()
	var second := _timeline()
	_check(not first.is_empty() and first == second, "full independent sew replacement Rest and rejected-independent timeline replays")
	if first.is_empty():
		return
	_check(first.state.scraps == 0 and first.state.rest_id == ""
		and first.state.worn.tinker.HEAD == "button_eye_alt"
		and first.state.worn.tinker.ARM == "pincushion_arm",
		"replay had genuine successful state transitions, not two empty failures")
	_check(local.state == local_state and local.seed == local_seed
		and randi() == expected_global,
		"no supplied RNG seed/state or same global RNG stream advanced")
	var w := _new()
	if not w.is_valid():
		return
	var original := w.get_snapshot()
	var first_read := w.get_snapshot()
	var second_read := w.get_snapshot()
	first_read.worn.warden.HEAD = "forged"
	first_read.owned.clear()
	first_read.definitions.button_eye = "ARM"
	first_read.heroes[0].hp = 0
	first_read.cards.append("forged")
	first_read.operation_ids.append("forged")
	_check(second_read == original and w.get_snapshot() == original,
		"two detached reads and authoritative state retain nested identity and metadata")
	var success := _sew(w, "quilted_coat", "tinker", "COAT", "detached")
	var before_mutation := w.get_snapshot()
	success.state.worn.tinker.COAT = "spoof"
	success.state.owned.clear()
	success.state.heroes[1].hp = 0
	success.receipt.operation_id = "spoof"
	_check(w.get_snapshot() == before_mutation,
		"success receipt and nested returned state cannot mutate authoritative ledger")
	var failure := w.sew("no_patch", "warden", "HEAD", "wrong", w.get_snapshot())
	failure.state.owned.clear()
	failure.state.worn.tinker.COAT = ""
	_check(w.get_snapshot() == before_mutation,
		"rejected return also has no mutable aliases")
