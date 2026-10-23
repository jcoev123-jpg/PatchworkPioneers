extends SceneTree
## Genuine M05 ARM wearer projection through the three authored pool resolvers.
## Service-level only: real mounted live-hand wiring belongs to a separate task.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_and_single_cards()
	_test_shrapnel_slots()
	_test_break_and_no_unravel_cards()
	_test_fail_closed()
	_test_torn_mend_and_resew()
	for failure in failures:
		printerr(failure)
	print("combat_loose_thread_glove_test: %s (%d checks)" % [
		"PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _fixture(card_ids: Array[String], wearer: String = "", equip: bool = false) -> Dictionary:
	var support: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_arm_support_patches.json"))
	_check(support is Array, "real M05 support catalog parsed")
	var definitions: Array = []
	var glove_found := false
	if support is Array:
		for entry in support:
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
			if entry.get("id") == "loose_thread_glove":
				glove_found = entry.get("slot") == "ARM" \
					and entry.get("effect") == "card_unravel_bonus" \
					and int(entry.get("amount", -1)) == 1
	_check(glove_found, "catalog authentic glove ID, ARM, effect and +1")
	var heroes_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	var hero_defs: Array = []
	if heroes_raw is Array:
		for hero in heroes_raw:
			var record: Dictionary = hero.duplicate(true)
			record["max_hp"] = int(hero["max_hp"])
			hero_defs.append(record)
	var party := CombatParty.new(hero_defs)
	var enemies := CombatEnemies.new([
		{"id": "front", "max_hp": 80},
		{"id": "middle", "max_hp": 80},
		{"id": "back", "max_hp": 80}])
	var gauge := CombatUnravel.new()
	_check(party.is_valid() and enemies.is_valid() and
		party.get_hero(1).get("id") == "warden" and
		party.get_hero(2).get("id") == "seamstress" and
		party.get_hero(3).get("id") == "tinker", "authored three-hero roster")
	_check(gauge.bind_roster(enemies, {1: "normal", 2: "elite", 3: "boss"}),
		"single gauge bound to original normal/elite/boss roster")
	_check(gauge.get_snapshot(1).get("threshold") == 8 and
		gauge.get_snapshot(2).get("threshold") == 12 and
		gauge.get_snapshot(3).get("threshold") == 16,
		"authentic normal/elite/boss initial thresholds are 8/12/16")
	var rng := RandomNumberGenerator.new()
	rng.seed = 17106
	var cards: Array[String] = card_ids.duplicate()
	while cards.size() < 5:
		cards.append("warden_strike")
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.hand.size() == 5
		and deck._rng == rng, "seeded actual hand and three-energy turn")
	for id in card_ids:
		_check(deck.hand.has(id), "physically held authored card " + id)
	var torn := RunTornMending.new(party.get_heroes())
	var owned: Array = ["loose_thread_glove"] if equip else []
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, definitions, 3)
	_check(torn.is_valid() and wardrobe.is_valid(), "real valid wardrobe and torn authorities")
	if equip:
		_check(wardrobe.sew("loose_thread_glove", wearer, "ARM", "sew_glove",
			wardrobe.get_snapshot()).get("ok") == true, "genuine owned glove sewn to " + wearer)
	var patches := CombatPatchAttackRules.new()
	_check(patches.bind_wardrobe(wardrobe, torn), "authenticated battle wearer projection")
	var pinned := CombatPinned.new()
	var first := CombatTinkerFirstAttack.new()
	var warden := CombatWardenPoolComboAttacks.new(patches)
	var seam := CombatSeamstressPoolControl.new()
	seam.bind_patch_rules(patches)
	var tinker := CombatTinkerPoolUnravelAttacks.new(first, gauge, pinned)
	_check(tinker.bind_patch_wardrobe(wardrobe, torn), "Tinker authentic patch wardrobe bind")
	return {"deck": deck, "party": party, "enemies": enemies, "gauge": gauge,
		"rng": rng, "wardrobe": wardrobe, "torn": torn, "patch": patches,
		"pinned": pinned, "first": first, "warden": warden, "seam": seam, "tinker": tinker}


func _play(f: Dictionary, card_id: String, target: int = 1) -> Dictionary:
	if card_id.begins_with("warden_"):
		return f["warden"].play_attack(f["deck"], f["party"], f["enemies"],
			f["pinned"], f["gauge"], card_id, target)
	if card_id.begins_with("seamstress_"):
		return f["seam"].play_card(f["deck"], f["party"], f["enemies"],
			f["pinned"], f["gauge"], card_id, target)
	return f["tinker"].play_attack(f["deck"], f["party"], f["enemies"],
		card_id, target, f["gauge"], f["pinned"])


func _snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	return {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"turn": deck.turn_active, "rng": deck._rng.state,
		"heroes": f["party"].get_heroes(), "enemies": f["enemies"].get_enemies(),
		"gauges": f["gauge"]._gauges.duplicate(true),
		"bound": f["gauge"]._bound_enemies,
		"pins": f["pinned"]._pinner_by_position.duplicate(true),
		"first": f["first"]._consumed,
		"patch_latch": f["patch"].latch_snapshot()}


func _assert_spent(f: Dictionary, before: Dictionary, card_id: String,
		cost: int, label: String) -> void:
	var after := _snapshot(f)
	var prior_hand: Array = before["hand"].duplicate()
	prior_hand.erase(card_id)
	var prior_discard: Array = before["discard"].duplicate()
	prior_discard.append(card_id)
	_check(after["energy"] == before["energy"] - cost and
		after["hand"] == prior_hand and after["discard"] == prior_discard
		and after["draw"] == before["draw"] and after["rng"] == before["rng"]
		and after["heroes"] == before["heroes"],
		label + ": exactly one spend/discard, no RNG or hero mutation")


func _test_catalog_and_single_cards() -> void:
	for item: Dictionary in [
		{"id": "warden_seam_breaker", "owner": "warden", "base": 4, "damage": 7, "cost": 2},
		{"id": "warden_seam_breaker_plus", "owner": "warden", "base": 6, "damage": 10, "cost": 2},
		{"id": "seamstress_snag", "owner": "seamstress", "base": 3, "damage": 0, "cost": 1},
		{"id": "seamstress_snag_plus", "owner": "seamstress", "base": 4, "damage": 0, "cost": 1},
		{"id": "seamstress_unpick", "owner": "seamstress", "base": 5, "damage": 0, "cost": 1},
		{"id": "seamstress_unpick_plus", "owner": "seamstress", "base": 7, "damage": 0, "cost": 1},
		{"id": "tinker_spool_launcher", "owner": "tinker", "base": 3, "damage": 6, "cost": 1},
		{"id": "tinker_spool_launcher_plus", "owner": "tinker", "base": 4, "damage": 7, "cost": 1},
	]:
		var id: String = item["id"]
		var patched := _fixture([id], item["owner"], true)
		var vanilla := _fixture([id])
		var patched_before := _snapshot(patched)
		var vanilla_before := _snapshot(vanilla)
		_check(patched["patch"].card_unravel_bonus(item["owner"], id) == 1 and
			vanilla["patch"].card_unravel_bonus(item["owner"], id) == 0,
			id + ": canonical card + active ARM glove only")
		var receipt: Dictionary = _play(patched, id)
		var original: Dictionary = _play(vanilla, id)
		var expected: int = item["base"] + 1
		var applied: int = -1
		var damage: int = -1
		if id.begins_with("warden_"):
			if receipt.get("hits", []).size() == 1 and original.get("hits", []).size() == 1:
				applied = receipt["hits"][0]["unravel_added"]
				damage = receipt["hits"][0]["damage"]
		elif id.begins_with("seamstress_"):
			applied = receipt.get("unravel_applied", -1)
			damage = receipt.get("damage", -1)
			if id.begins_with("seamstress_snag"):
				_check(receipt.get("weak_applied") == 1 and
					patched["enemies"].get_enemy(1).get("statuses", {}).get("weak") == 1,
					id + ": Weak 1 retained unchanged")
		elif receipt.get("hits", []).size() == 1:
			applied = receipt["hits"][0]["unravel"]
			damage = receipt["hits"][0]["damage"]
		_check(receipt.get("ok") == true and original.get("ok") == true and
			applied == expected and damage == item["damage"],
			id + ": resolved printed damage and actual bonus receipt")
		_check(patched["gauge"].get_snapshot(1)["gauge"] == expected and
			vanilla["gauge"].get_snapshot(1)["gauge"] == item["base"] and
			patched["gauge"].get_snapshot(2)["gauge"] == 0 and
			patched["gauge"].get_snapshot(3)["gauge"] == 0,
			id + ": exact amended vs plain gauges on original enemy slot")
		_check(patched["enemies"].get_enemies() == vanilla["enemies"].get_enemies(),
			id + ": no other damage, Block or statuses from glove")
		_assert_spent(patched, patched_before, id, item["cost"], id + " patched")
		_assert_spent(vanilla, vanilla_before, id, item["cost"], id + " vanilla")


func _test_shrapnel_slots() -> void:
	for id in ["tinker_shrapnel_seam", "tinker_shrapnel_seam_plus"]:
		var patched := _fixture([id], "tinker", true)
		var vanilla := _fixture([id])
		_check(patched["enemies"].apply_damage(2, 80) and
			vanilla["enemies"].apply_damage(2, 80) and
			patched["enemies"].is_slain(2), id + ": original slot two slain")
		var before := _snapshot(patched)
		var raw: int = 2 if id == "tinker_shrapnel_seam" else 3
		var damage: int = 8 if raw == 2 else 10
		var result := _play(patched, id, 0)
		var plain := _play(vanilla, id, 0)
		var hits: Array = result.get("hits", [])
		var plain_hits: Array = plain.get("hits", [])
		_check(result.get("ok") == true and plain.get("ok") == true and
			hits.size() == 2 and plain_hits.size() == 2,
			id + ": exactly two living area recipients")
		if hits.size() == 2 and plain_hits.size() == 2:
			for index in range(2):
				var pos: int = 1 if index == 0 else 3
				_check(hits[index]["position"] == pos and
					hits[index]["unravel"] == raw + 1 and
					plain_hits[index]["unravel"] == raw and
					hits[index]["damage"] == damage and
					hits[index]["hp_loss"] == damage,
					id + ": original position %d, first attack +3 only once" % pos)
		for pos in [1, 3]:
			_check(patched["gauge"].get_snapshot(pos)["gauge"] == raw + 1 and
				vanilla["gauge"].get_snapshot(pos)["gauge"] == raw,
				id + ": target %d bound gauge exactly once" % pos)
		_check(patched["gauge"].get_snapshot(2)["gauge"] == 0 and
			patched["enemies"].get_enemies() == vanilla["enemies"].get_enemies() and
			patched["first"]._consumed,
			id + ": corpse skipped and hit damage/latch unchanged")
		_assert_spent(patched, before, id, 2, id + " area")


func _test_break_and_no_unravel_cards() -> void:
	var f := _fixture(["seamstress_snag", "seamstress_snag"], "seamstress", true)
	var one := _play(f, "seamstress_snag")
	var two := _play(f, "seamstress_snag")
	var snap: Dictionary = f["gauge"].get_snapshot(1)
	_check(one.get("ok") == true and two.get("ok") == true and
		f["deck"].energy == 1 and f["deck"].discard_pile.size() == 2 and
		snap["gauge"] == 8 and snap["threshold"] == 8 and
		snap["unravelled"] and snap["skip_pending"],
		"two separate glove casts reach authentic normal threshold and one pending skip")
	_check(f["gauge"].consume_action_skip(f["enemies"], 1) and
		f["gauge"].get_snapshot(1) == {
			"gauge": 0, "threshold": 12, "unravelled": false, "skip_pending": false},
		"real skip consumption resets gauge and raises threshold +4")
	var pinned_case := _fixture(["warden_seam_breaker"], "warden", true)
	_check(pinned_case["pinned"].pin_enemy(pinned_case["enemies"], 1, "seamstress"),
		"real cross-owner Pinned token precondition")
	var breaker := _play(pinned_case, "warden_seam_breaker")
	_check(breaker.get("ok") == true and breaker["hits"].size() == 1 and
		breaker["hits"][0]["damage"] == 12 and
		breaker["hits"][0]["pin_bonus"] == 5 and
		breaker["hits"][0]["pin_consumed"] and
		breaker["hits"][0]["unravel_added"] == 5 and
		pinned_case["pinned"].pinner_for_enemy(1) == "",
		"Seam Breaker retains one cross-owner +5 Pin and exactly +1 Unravel")
	var lethal := _fixture(["warden_seam_breaker"], "warden", true)
	_check(lethal["enemies"].apply_damage(1, 77), "lethal Warden target 3 HP")
	var lethal_receipt := _play(lethal, "warden_seam_breaker")
	_check(lethal_receipt.get("ok") == true and lethal["enemies"].is_slain(1) and
		lethal_receipt["hits"][0]["unravel_added"] == 0 and
		lethal["gauge"].get_snapshot(1)["gauge"] == 0,
		"no authored or bonus gauge on killed Warden target")
	for item in [
		{"id": "warden_pinning_jab", "owner": "warden"},
		{"id": "seamstress_needle_pin", "owner": "seamstress"},
		{"id": "tinker_snip_the_seam", "owner": "tinker"},
	]:
		var id: String = item["id"]
		f = _fixture([id], item["owner"], true)
		_check(f["patch"].card_unravel_bonus(item["owner"], id) == 0,
			id + ": no invented Unravel on non-bearing authored card")
		var r := _play(f, id)
		_check(r.get("ok") == true and f["gauge"].get_snapshot(1)["gauge"] == 0,
			id + ": genuine confirmed play does not charge gauge")
		if id == "warden_pinning_jab":
			_check(r["hits"][0]["pin_applied"] and
				f["pinned"].pinner_for_enemy(1) == "warden" and
				r["hits"][0]["damage"] == 4, "Pinning Jab original damage and pin")
		if id == "seamstress_needle_pin":
			_check(f["pinned"].pinner_for_enemy(1) == "seamstress",
				"Needle Pin retains actual pinned action")
		if id == "tinker_snip_the_seam":
			_check(r["hits"][0]["damage"] == 8 and f["first"]._consumed,
				"Snip's native first attack +3 retained without Unravel")


func _reject(f: Dictionary, id: String, target: int, label: String) -> void:
	var before := _snapshot(f)
	var result := _play(f, id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(_snapshot(f) == before,
		label + ": zero energy/hand/discard/HP/Block/status/pin/gauge/latch/RNG mutation")


func _test_fail_closed() -> void:
	for item in [
		{"id": "warden_seam_breaker", "owner": "warden"},
		{"id": "seamstress_snag", "owner": "seamstress"},
		{"id": "tinker_spool_launcher", "owner": "tinker"},
		{"id": "tinker_shrapnel_seam", "owner": "tinker"},
	]:
		var id: String = item["id"]
		var f := _fixture([id], item["owner"], true)
		_reject(f, id, 9 if id != "tinker_shrapnel_seam" else 1,
			id + " invalid target")
		_check(f["deck"].try_spend_energy(3), id + ": precondition empty energy")
		_reject(f, id, 0 if id == "tinker_shrapnel_seam" else 1,
			id + " unavailable energy")
		f = _fixture([id], item["owner"], true)
		f["deck"].hand.erase(id)
		_reject(f, id, 0 if id == "tinker_shrapnel_seam" else 1,
			id + " not in held hand")
		f = _fixture([id], item["owner"], true)
		var other_enemies := CombatEnemies.new([{"id": "stale", "max_hp": 60}])
		var stale := CombatUnravel.new()
		_check(stale.bind_roster(other_enemies, {1: "normal"}),
			id + ": stale gauge genuinely bound to another roster")
		f["gauge"] = stale
		_reject(f, id, 0 if id == "tinker_shrapnel_seam" else 1,
			id + " stale gauge")
		f = _fixture([id], item["owner"], true)
		if id.begins_with("warden_"):
			f["warden"].set_patches(CombatPatchAttackRules.new())
		elif id.begins_with("seamstress_"):
			f["seam"].bind_patch_rules(CombatPatchAttackRules.new())
		else:
			_check(not f["tinker"].bind_patch_wardrobe(null, null),
				id + ": invalid explicit bind fails")
		_reject(f, id, 0 if id == "tinker_shrapnel_seam" else 1,
			id + " explicit invalid patch authority")
		f = _fixture([id], "seamstress" if item["owner"] != "seamstress" else "warden", true)
		_check(f["patch"].card_unravel_bonus(item["owner"], id) == 0,
			id + ": mismatch wearer denied by canonical ownership")
		var r := _play(f, id, 0 if id == "tinker_shrapnel_seam" else 1)
		_check(r.get("ok") == true, id + ": mismatched wearer vanilla cast legal")
		var authored: int = 4 if id == "warden_seam_breaker" else (
			3 if id in ["seamstress_snag", "tinker_spool_launcher"] else 2)
		_check(f["gauge"].get_snapshot(1)["gauge"] == authored,
			id + ": no unauthorized wearer bonus")


func _test_torn_mend_and_resew() -> void:
	var f := _fixture(["warden_seam_breaker"], "warden", true)
	var wardrobe: RunPatchWardrobe = f["wardrobe"]
	var torn: RunTornMending = f["torn"]
	var start: Array = torn.read_state()["heroes"]
	var end: Array = start.duplicate(true)
	end[0]["hp"] = 0
	_check(torn.observe_battle_end("battle_torn", start, end).get("ok") == true,
		"genuine combat tear recorded in RunTornMending")
	_check(torn.read_state()["heroes"][0]["max_hp"] == 37,
		"torn Warden max HP reduced by three")
	_check(f["party"].apply_damage(1, 40) and f["party"].is_downed(1),
		"torn hero cannot legally author a later Warden cast")
	_reject(f, "warden_seam_breaker", 1, "torn owner cannot cast even while still wearing glove")
	var projected: CombatPatchAttackRules = f["patch"]
	_check(projected.bind_wardrobe(wardrobe, torn) and
		projected.card_unravel_bonus("warden", "warden_seam_breaker") == 0 and
		wardrobe.get_snapshot()["worn"]["warden"]["ARM"] == "loose_thread_glove",
		"worn glove remains assigned but is inactive while wearer torn")
	var mend := torn.choose_mend("node_mend", "receipt_mend", "warden", 1, 3,
		torn.read_state()["heroes"], true)
	_check(mend.get("ok") == true and torn.read_state()["heroes"][0]["hp"] > 0,
		"actual paid mend revives wearer")
	_check(wardrobe.start_rest("rest_resew", wardrobe.get_snapshot()).get("ok") == true,
		"genuine wardrobe Rest entry")
	_check(wardrobe.re_sew("loose_thread_glove", "warden", "seamstress",
		"rest_resew", "move_glove", wardrobe.get_snapshot()).get("ok") == true,
		"paid re-sew transfers glove to new ARM wearer")
	_check(projected.bind_wardrobe(wardrobe, torn) and
		projected.card_unravel_bonus("seamstress", "seamstress_snag") == 1 and
		projected.card_unravel_bonus("warden", "warden_seam_breaker") == 0,
		"fresh authenticated projection benefits only new living wearer")
	var seam_f := _fixture(["seamstress_snag"])
	seam_f["seam"].bind_patch_rules(projected)
	var receipt := _play(seam_f, "seamstress_snag")
	_check(receipt.get("ok") == true and receipt.get("unravel_applied") == 4 and
		seam_f["gauge"].get_snapshot(1)["gauge"] == 4,
		"re-sewn new wearer receives bonus through real Seamstress resolver")
	var warden_f := _fixture(["warden_seam_breaker"])
	warden_f["warden"].set_patches(projected)
	var old_receipt := _play(warden_f, "warden_seam_breaker")
	_check(old_receipt.get("ok") == true and
		old_receipt["hits"][0]["unravel_added"] == 4 and
		warden_f["gauge"].get_snapshot(1)["gauge"] == 4,
		"former wearer no longer benefits after paid re-sew")
