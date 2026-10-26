extends SceneTree
## Rest-crafted composite cards, real shared turn, authored living rosters.
## Every preview (including rejection) is an observational-only transaction.

var failures: Array[String] = []
var checks := 0
var service := CombatStitchedTargetPreview.new()
var catalog := StarterCards.new()


func _initialize() -> void:
	_test_warden_blocks()
	_test_legal_halves()
	_test_pool_healing_previews()
	_test_pool_self_previews()
	_test_positions_and_recipients()
	_test_refusals()
	_test_replay_and_isolation()
	for message in failures:
		printerr(message)
	print("combat_stitched_target_preview_test: ", "PASS" if failures.is_empty() else "FAIL",
			" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_warden_blocks() -> void:
	for id in CombatStitchedTargetPreview.WARDEN_BLOCK_IDS:
		for reverse in [false, true]:
			var c := _pair("tinker_pop_shot" if reverse else id, id if reverse else "tinker_pop_shot")
			for position in [1, 2, 3]:
				c.party = _party()
				for step in range(position - 1):
					var moved := CombatPositionSwaps.preview_adjacent_swap(c.party, step + 1, 1)
					_check(moved.ok, "preview uses actual displaced Warden")
					c.party._heroes.assign(moved.heroes)
				var result := _guarded_call(c, "canonical Warden preview")
				if position == 3 and id.begins_with("warden_hold"):
					_check(not result.playable, "Hold rejects current illegal back slot")
				else:
					_check(result.playable and result.halves.size() == 2, "canonical pool Block admitted in both orders")
					if result.playable:
						var half: Dictionary = result.halves[1 if reverse else 0]
						_check(half.card_id == id and half.owner == "warden" and not half.requires_selection
							and half.target_positions.is_empty() and half.affected_positions == [1, 2, 3], "automatic zero-target includes all living Block recipients")
			c.party = _party()
			_check(c.party.apply_damage(2, 999) and c.party.is_downed(2), "preview non-owner downed")
			var living := _guarded_call(c, "downed recipient")
			_check(living.playable and living.halves[1 if reverse else 0].affected_positions == [1, 3], "preview omits downed recipient")
			var forged: Dictionary = c.snapshot.duplicate(true)
			forged.descriptors[c.id].cost = 0
			_rejected(c, "forged Warden receipt", forged)
	for id in ["warden_quick_darn", "warden_patch_guard", "warden_iron_hem", "warden_pinning_jab"]:
		_rejected(_pair(id, "tinker_pop_shot"), "other unsupported pool halves stay rejected")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "shipped resource opens: " + path)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Array, "shipped JSON array: " + path)
	if parsed is Array:
		return parsed
	return []


func _starter_ids() -> Array[String]:
	var ids: Array[String] = []
	for value in _json("res://data/cards/starter_deck.json"):
		_check(value is String and catalog.has_card(value), "real authored starter ID: " + str(value))
		if value is String and catalog.has_card(value):
			ids.append(value)
	var from_catalog := catalog.get_starting_deck()
	# Assert the particular required originals, not a global catalog size/order.
	for card_id in ["warden_strike", "warden_brace", "warden_shield_bash",
			"seamstress_prick", "seamstress_mend", "seamstress_stitch_up",
			"tinker_pop_shot", "tinker_scrap_bomb", "tinker_tune_up"]:
		_check(ids.has(card_id) and from_catalog.has(card_id),
				"required authentic starting instance: " + card_id)
	return ids


func _party(order: Array[String] = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var by_id := {}
	for entry in _json("res://data/heroes/starter_party.json"):
		if entry is Dictionary:
			by_id[entry.get("id")] = entry
	var definitions: Array = []
	for id in order:
		_check(by_id.has(id), "shipped hero definition " + id)
		if not by_id.has(id):
			return CombatParty.new([])
		var hero: Dictionary = by_id[id].duplicate(true)
		_check(hero["max_hp"] == floor(float(hero["max_hp"])), "integral shipped hero max HP")
		hero["max_hp"] = int(hero["max_hp"])
		definitions.append(hero)
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "real CombatParty valid")
	return party


func _enemies(count: int = 3) -> CombatEnemies:
	var authored := _json("res://data/enemies/run_enemies.json")
	_check(authored.size() >= count, "shipped enemy definitions available")
	var definitions: Array = []
	for index in range(mini(count, authored.size())):
		var enemy: Dictionary = authored[index].duplicate(true)
		_check(enemy["max_hp"] == floor(float(enemy["max_hp"])), "integral shipped enemy max HP")
		enemy["max_hp"] = int(enemy["max_hp"])
		definitions.append(enemy)
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid(), "real CombatEnemies valid for " + str(count) + " occupied slots")
	return enemies


func _pair(first_id: String, second_id: String, run_seed: int = 123456) -> Dictionary:
	var original := _starter_ids()
	for card_id in [first_id, second_id]:
		if not original.has(card_id):
			original.append(card_id)
	var first_index := original.find(first_id)
	var second_index := original.find(second_id)
	_check(first_index >= 0 and second_index >= 0 and first_index != second_index,
			"two distinct real card instances: " + first_id + " / " + second_id)
	_check(RunRestStitchCards.resolve_card_definition(first_id).get("owner") != RunRestStitchCards.resolve_card_definition(second_id).get("owner"),
			"Rest stitch requires two distinct authored owners")
	if first_index < 0 or second_index < 0 or first_index == second_index:
		return {}
	var rest := RunRestStitchCards.new(original, {}, 3)
	_check(rest.is_valid(), "valid authoritative Rest ledger before stitch")
	var source := rest.get_snapshot()
	var made := rest.choose_stitch(first_index, second_index, source)
	_check(made.get("ok") == true and rest.is_consumed(), "genuine choose_stitch transaction")
	if not made.get("ok", false):
		return {}
	var id: String = made["stitched_id"]
	var snapshot := rest.get_snapshot()
	_check(snapshot == _receipt(made) and snapshot["descriptors"][id] == made["descriptor"],
			"exact detached committed ledger receipt and descriptor")
	_check(made["consumed_indices"] == [first_index, second_index]
			and made["consumed_ids"] == [first_id, second_id], "ordered originals captured")
	var expected_cost: int = mini(3, maxi(
			RunRestStitchCards.resolve_card_definition(first_id)["cost"], RunRestStitchCards.resolve_card_definition(second_id)["cost"]) + 1)
	_check(made["descriptor"]["cost"] == expected_cost and snapshot["deck"].count(id) == 1,
			"real descriptor computed cost and single deck instance")
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var initial_state := rng.state
	var cards: Array[String] = []
	cards.assign(made["deck"])
	var deck := CombatDeck.new(cards, rng)
	_check(deck.draw_pile.size() == cards.size() and deck.hand.is_empty(),
			"new real CombatDeck starts from entire stitched shared deck")
	var found := false
	for n in range(8):
		_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
				"real turn starts with 3 energy and draws from seeded pile")
		if deck.hand.has(id):
			found = true
			break
		_check(deck.end_turn(), "unheld turn ended via actual CombatDeck API")
	_check(found, "seeded real draw eventually holds exact stitched card " + id)
	_check(deck.hand.has(id) and deck.turn_active and deck.energy >= expected_cost,
			"composite actually held and affordable in active shared hand")
	_check(rng.state != initial_state, "deck construction/draw consumed only injected RNG beforehand")
	return {
		"rest": rest, "snapshot": snapshot, "id": id, "cost": expected_cost,
		"deck": deck, "party": _party(), "enemies": _enemies(),
	}


func _receipt(made: Dictionary) -> Dictionary:
	var result := made.duplicate(true)
	for key in ["ok", "consumed", "stitched_id", "descriptor",
			"consumed_indices", "consumed_ids", "source_receipt"]:
		result.erase(key)
	return result


func _state(s: Dictionary) -> Dictionary:
	var result := {}
	var rest: RunRestStitchCards = s.get("rest")
	var deck: CombatDeck = s.get("deck")
	var party: CombatParty = s.get("party")
	var foes: CombatEnemies = s.get("enemies")
	if rest != null:
		result["rest"] = rest.get_snapshot()
		result["rest_valid"] = rest.is_valid()
		result["rest_consumed"] = rest.is_consumed()
	if deck != null:
		result["draw"] = deck.draw_pile.duplicate(true)
		result["hand"] = deck.hand.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		result["combat_state"] = [deck.combat_state.energy, deck.combat_state.player_turn_active]
		result["rng_seed"] = deck._rng.seed
		result["rng_state"] = deck._rng.state
	if party != null:
		result["heroes"] = party.get_heroes()
	if foes != null:
		result["enemies"] = foes.get_enemies()
	return result


func _call(s: Dictionary, snapshot: Variant = null, override_id: Variant = null) -> Dictionary:
	return service.get_preview(s.get("rest"),
			s["snapshot"] if snapshot == null else snapshot,
			s.get("deck"), s.get("party"), s.get("enemies"),
			s["id"] if override_id == null else override_id)


func _guarded_call(s: Dictionary, label: String, snapshot: Variant = null,
		override_id: Variant = null) -> Dictionary:
	var before := _state(s)
	seed(8675309)
	var expected_global := randi()
	seed(8675309)
	var result := _call(s, snapshot, override_id)
	_check(_state(s) == before, label + ": complete deck, rosters, ledger and injected RNG untouched")
	_check(randi() == expected_global, label + ": global RNG stream untouched")
	return result


func _half(index: int, card_id: String, positions: Array,
		affected: Array = []) -> Dictionary:
	var definition := RunRestStitchCards.resolve_card_definition(card_id)
	var kind: String = definition["target_kind"]
	var side := "enemy" if kind.begins_with("enemy") else "none" if kind == "none" else "ally"
	var selectable := kind == "enemy_single" or kind == "ally_single"
	var choices: Array[int] = []
	choices.assign(positions)
	var automatic: Array[int] = []
	automatic.assign(affected)
	return {
		"index": index, "order": "first" if index == 0 else "second",
		"card_id": card_id, "owner": definition["owner"],
		"target_kind": kind, "side": side, "requires_selection": selectable,
		"target_positions": choices, "affected_positions": automatic,
	}


func _accepted(s: Dictionary, first: Dictionary, second: Dictionary, label: String) -> Dictionary:
	if s.is_empty():
		_check(false, label + ": fixture missing")
		return {}
	var actual := _guarded_call(s, label)
	var expected := {
		"playable": true, "stitched_id": s["id"], "cost": s["cost"],
		"first_half": first, "second_half": second, "halves": [first, second],
	}
	_check(actual == expected, label + ": exact two independent ordered authored half previews")
	_check(actual.get("playable") == true and actual.get("halves", []).size() == 2,
			label + ": nonvacuous real held composite success")
	if actual.get("playable", false):
		for half in actual["halves"]:
			_check((half["target_positions"] as Array).get_typed_builtin() == TYPE_INT
					and (half["affected_positions"] as Array).get_typed_builtin() == TYPE_INT,
					label + ": typed deterministic ascending target/affected positions")
	return actual


func _rejected(s: Dictionary, label: String, snapshot: Variant = null,
		override_id: Variant = null) -> void:
	var result := _guarded_call(s, label, snapshot, override_id)
	_check(result == {
		"playable": false, "stitched_id": "", "cost": 0,
		"first_half": {}, "second_half": {}, "halves": [],
	}, label + ": full refusal without a partial target offer")


func _test_legal_halves() -> void:
	var s := _pair("seamstress_prick", "tinker_pop_shot")
	_accepted(s, _half(0, "seamstress_prick", [1, 2, 3]),
			_half(1, "tinker_pop_shot", [1, 2, 3]), "Prick / Pop both singles select independently")
	_check(s["cost"] == 2, "two one-energy attacks stitch to cost two")
	s = _pair("warden_shield_bash", "tinker_pop_shot")
	_accepted(s, _half(0, "warden_shield_bash", [1]),
			_half(1, "tinker_pop_shot", [1, 2, 3]),
			"two independently selectable attack halves have different legal target sets")
	s = _pair("warden_shield_bash", "tinker_tune_up")
	_accepted(s, _half(0, "warden_shield_bash", [1]),
			_half(1, "tinker_tune_up", []), "Shield Bash / Tune Up enemy and none")
	_check(s["cost"] == 3, "cost-two Bash + zero Tune computes capped three")
	s = _pair("seamstress_prick", "tinker_scrap_bomb")
	_accepted(s, _half(0, "seamstress_prick", [1, 2, 3]),
			_half(1, "tinker_scrap_bomb", [], [1, 2, 3]), "Prick / Scrap Bomb selectable then automatic all")
	s = _pair("seamstress_mend", "tinker_pop_shot")
	_accepted(s, _half(0, "seamstress_mend", [1, 2, 3]),
			_half(1, "tinker_pop_shot", [1, 2, 3]), "Mend / Pop ally vs enemy independent")
	s = _pair("warden_brace", "seamstress_mend")
	_accepted(s, _half(0, "warden_brace", [], [1]),
			_half(1, "seamstress_mend", [1, 2, 3]), "Brace / Mend self automatic vs ally selectable")
	s = _pair("seamstress_stitch_up", "tinker_tune_up")
	_accepted(s, _half(0, "seamstress_stitch_up", [1, 2, 3]),
			_half(1, "tinker_tune_up", []), "Stitch Up / Tune Up ally vs none")


func _test_positions_and_recipients() -> void:
	var s := _pair("seamstress_prick", "tinker_pop_shot", 6651)
	var foes: CombatEnemies = s["enemies"]
	_check(foes.apply_damage(2, 999) and foes.is_slain(2), "enemy middle killed in-place, not compacted")
	_accepted(s, _half(0, "seamstress_prick", [1, 3]),
			_half(1, "tinker_pop_shot", [1, 3]), "two singles omit slain middle")
	s["enemies"] = _enemies(1)
	_accepted(s, _half(0, "seamstress_prick", [1]),
			_half(1, "tinker_pop_shot", [1]), "absent enemy slots never selectable")
	s["enemies"] = _enemies()
	_check(s["enemies"].apply_damage(1, 999), "enemy front slain for new independent choices")
	_accepted(s, _half(0, "seamstress_prick", [2, 3]),
			_half(1, "tinker_pop_shot", [2, 3]), "remaining enemy slots sorted ascending")
	s = _pair("seamstress_prick", "tinker_scrap_bomb")
	_check(s["enemies"].apply_damage(2, 999), "area fixture has defeated enemy middle")
	_accepted(s, _half(0, "seamstress_prick", [1, 3]),
			_half(1, "tinker_scrap_bomb", [], [1, 3]), "enemy-all only living affected positions")
	s = _pair("seamstress_mend", "tinker_pop_shot")
	_check(s["party"].apply_damage(1, 40) and s["party"].is_downed(1), "actual Warden downed")
	_accepted(s, _half(0, "seamstress_mend", [2, 3]),
			_half(1, "tinker_pop_shot", [1, 2, 3]), "Mend excludes downed ally; enemy half unaffected")
	s = _pair("warden_brace", "seamstress_mend")
	var initial: CombatParty = s["party"]
	var legal_swap := CombatPositionSwaps.preview_adjacent_swap(initial, 1, 1)
	_check(legal_swap.get("ok") and legal_swap["heroes"][0]["id"] == "seamstress",
			"legal adjacent swap proposal for actual living hero slots")
	s["party"] = _party(["seamstress", "warden", "tinker"])
	_check(s["party"].get_heroes() == legal_swap["heroes"],
			"swapped real party matches existing CombatPositionSwaps legality")
	_rejected(s, "Mend from front illegal after Warden/Seamstress legal swap")
	s = _pair("seamstress_prick", "tinker_pop_shot")
	s["party"] = _party(["seamstress", "tinker", "warden"])
	_accepted(s, _half(0, "seamstress_prick", [1, 2, 3]),
			_half(1, "tinker_pop_shot", [1, 2, 3]), "both owners may swap while preserving individual from positions")
	s = _pair("warden_brace", "seamstress_mend")
	s["party"] = _party(["warden", "tinker", "seamstress"])
	_accepted(s, _half(0, "warden_brace", [], [1]),
			_half(1, "seamstress_mend", [1, 2, 3]), "Mend legal at seamstress back position")
	s = _pair("seamstress_stitch_up", "tinker_tune_up")
	s["party"] = _party(["tinker", "seamstress", "warden"])
	_accepted(s, _half(0, "seamstress_stitch_up", [1, 2, 3]),
			_half(1, "tinker_tune_up", []), "Stitch/none legal after live-roster reorder")


func _test_refusals() -> void:
	var s := _pair("seamstress_prick", "tinker_pop_shot", 185)
	_rejected(s, "unknown composite", null, "stitched_999999")
	_rejected(s, "non-stitched original cannot impersonate held composite", null, "seamstress_prick")
	_rejected(s, "malformed numeric card identity", null, 123)
	_rejected(s, "empty card identity", null, "")
	var good := _accepted(s, _half(0, "seamstress_prick", [1, 2, 3]),
			_half(1, "tinker_pop_shot", [1, 2, 3]), "valid retry before ledger corruption")
	var stale: Dictionary = s["snapshot"].duplicate(true)
	stale["receipt"] = "stale"
	_rejected(s, "stale receipt", stale)
	stale = s["snapshot"].duplicate(true)
	stale["deck"].erase(s["id"])
	_rejected(s, "mismatched deck receipt", stale)
	stale = s["snapshot"].duplicate(true)
	stale["descriptors"][s["id"]]["second_half"]["cost"] = 999
	_rejected(s, "forged supplied descriptor", stale)
	stale = s["snapshot"].duplicate(true)
	stale["remaining_scraps"] += 1
	_rejected(s, "changed scraps receipt", stale)
	stale = s["snapshot"].duplicate(true)
	stale["next_stitch_id"] += 1
	_rejected(s, "stale allocator receipt", stale)
	_check(_guarded_call(s, "valid ledger survives stale and forged calls") == good,
			"valid retry after all stale/malformed snapshots still succeeds")
	var held: CombatDeck = s["deck"]
	_check(held.try_spend_energy(2) and held.energy == 1, "genuine turn spends two for unaffordable cost-two card")
	_rejected(s, "insufficient combined energy")
	var still_held := _pair("seamstress_prick", "tinker_pop_shot", 186)
	var still_held_deck: CombatDeck = still_held["deck"]
	_check(still_held_deck.combat_state.end_player_turn()
			and not still_held_deck.turn_active and still_held_deck.hand.has(still_held["id"]),
			"inactive fixture deliberately retains authentic currently held composite")
	_rejected(still_held, "inactive player turn despite held composite")
	_check(held.end_turn() and not held.turn_active, "genuine turn ended")
	_rejected(s, "inactive turn without held card")
	_check(held.start_turn(), "genuine subsequent active turn")
	# If the stitched card is drawn again, discard it using the real deck API.
	for n in range(8):
		if held.hand.has(s["id"]):
			break
		_check(held.end_turn() and held.start_turn(), "advance real draw for unheld fixture")
	_check(held.hand.has(s["id"]), "unheld fixture starts with a truly held stitched copy")
	if held.hand.has(s["id"]):
		_check(held.discard_played(s["id"]) and not held.hand.has(s["id"]),
				"actual discard removes sole composite from held hand")
		_rejected(s, "already discarded stitched copy absent from hand")
	var clean := _pair("seamstress_prick", "tinker_pop_shot")
	_check(clean["party"].apply_damage(2, 999) and clean["party"].is_downed(2),
			"first owner's real HP zero")
	_rejected(clean, "torn first owner")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	_check(clean["party"].apply_damage(3, 999) and clean["party"].is_downed(3),
			"second owner's real HP zero")
	_rejected(clean, "torn second owner")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	clean["party"] = _party(["tinker", "seamstress", "warden"])
	_rejected(clean, "Tinker illegally positioned at front")
	clean = _pair("warden_shield_bash", "tinker_tune_up")
	_check(clean["enemies"].apply_damage(1, 999) and not clean["enemies"].is_defeated(),
			"Bash has no enemy1, but other living enemies still exist")
	_rejected(clean, "one half lacks legal enemy while none half would be legal")
	clean = _pair("tinker_tune_up", "warden_shield_bash")
	_check(clean["enemies"].apply_damage(1, 999) and not clean["enemies"].is_defeated(),
			"second-half Bash loses enemy1 while first-half none remains usable")
	_rejected(clean, "second half lacks target even though first half needs none")
	clean = _pair("seamstress_prick", "tinker_scrap_bomb")
	for position in [1, 2, 3]:
		_check(clean["enemies"].apply_damage(position, 999), "genuine enemy defeat " + str(position))
	_check(clean["enemies"].is_defeated(), "no living targets")
	_rejected(clean, "defeated enemy roster")
	clean = _pair("seamstress_mend", "tinker_pop_shot")
	clean["enemies"] = CombatEnemies.new([])
	_rejected(clean, "invalid empty enemy roster even if ally half would work")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	clean["enemies"] = CombatEnemies.new([
		{"id": "duplicate", "max_hp": 3}, {"id": "duplicate", "max_hp": 3}
	])
	_rejected(clean, "invalid duplicate enemy roster")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	clean["party"] = CombatParty.new([])
	_rejected(clean, "invalid empty party roster")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	clean["party"]._heroes[2]["id"] = "seamstress"
	_rejected(clean, "duplicate actual hero identity")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	clean["party"]._heroes[2]["id"] = "outsider"
	_rejected(clean, "foreign actor identity")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	var corrupted: Dictionary = clean["rest"]._descriptors[clean["id"]]
	corrupted["first_half"]["effects"]["bleed"] = 999
	clean["snapshot"] = clean["rest"].get_snapshot()
	_rejected(clean, "mutated internal descriptor with self-consistent receipt")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	clean["rest"]._descriptors.erase(clean["id"])
	clean["snapshot"] = clean["rest"].get_snapshot()
	_rejected(clean, "unregistered internal descriptor")
	clean = _pair("seamstress_prick", "tinker_pop_shot")
	var before := _state(clean)
	seed(945691)
	var global_expected := randi()
	seed(945691)
	for failed in [
		service.get_preview(clean["rest"], null, clean["deck"], clean["party"], clean["enemies"], clean["id"]),
		service.get_preview(clean["rest"], {}, clean["deck"], clean["party"], clean["enemies"], clean["id"]),
		service.get_preview(null, clean["snapshot"], clean["deck"], clean["party"], clean["enemies"], clean["id"]),
		service.get_preview([], clean["snapshot"], clean["deck"], clean["party"], clean["enemies"], clean["id"]),
		service.get_preview(clean["rest"], clean["snapshot"], null, clean["party"], clean["enemies"], clean["id"]),
		service.get_preview(clean["rest"], clean["snapshot"], clean["party"], clean["party"], clean["enemies"], clean["id"]),
		service.get_preview(clean["rest"], clean["snapshot"], clean["deck"], null, clean["enemies"], clean["id"]),
		service.get_preview(clean["rest"], clean["snapshot"], clean["deck"], clean["party"], null, clean["id"]),
		service.get_preview(clean["rest"], clean["snapshot"], clean["deck"], clean["party"], clean["deck"], clean["id"]),
	]:
		_check(failed["playable"] == false and failed["halves"] == [],
				"null/wrong typed combat object fails closed")
	_check(_state(clean) == before, "every wrong type leaves all surviving models untouched")
	_check(randi() == global_expected, "null, stale and wrong-typed requests do not draw global RNG")
	_accepted(clean, _half(0, "seamstress_prick", [1, 2, 3]),
			_half(1, "tinker_pop_shot", [1, 2, 3]), "fresh valid play after rejected malformed objects")


func _test_replay_and_isolation() -> void:
	for value in [0, 42, 987654]:
		var first := _pair("seamstress_mend", "tinker_pop_shot", value)
		var second := _pair("seamstress_mend", "tinker_pop_shot", value)
		_check(_state(first) == _state(second),
				"two independent real Rest+deck sessions same draw, piles, ledger, actors, RNG seed " + str(value))
		var a := _guarded_call(first, "replay first " + str(value))
		var b := _guarded_call(second, "replay second " + str(value))
		_check(a == b and a["playable"] and a["halves"].size() == 2,
				"two full authored per-half outputs exactly reproducible from same seed " + str(value))
		first["party"] = _party(["warden", "tinker", "seamstress"])
		second["party"] = _party(["warden", "tinker", "seamstress"])
		a = _guarded_call(first, "after legal position swap first")
		b = _guarded_call(second, "after legal position swap second")
		_check(a == b and a["playable"] and a["first_half"]["target_positions"] == [1, 2, 3],
				"reordered living parties produce identical legal per-half choices")
	var s := _pair("seamstress_prick", "tinker_scrap_bomb")
	var first_read := _guarded_call(s, "isolated first")
	var second_read := _guarded_call(s, "isolated second")
	(first_read["first_half"]["target_positions"] as Array).clear()
	(first_read["halves"][1]["affected_positions"] as Array).append(99)
	_check(second_read["first_half"]["target_positions"] == [1, 2, 3]
			and second_read["second_half"]["affected_positions"] == [1, 2, 3],
			"independent call result detached from mutated earlier result")
	_check(_guarded_call(s, "isolated subsequent") == second_read,
			"mutating earlier preview cannot corrupt ledger or future output")

func _test_pool_healing_previews() -> void:
	var pool := SeamstressPoolCards.new()
	for id in CombatStitchedTargetPreview.POOL_HEAL_IDS:
		var authored: Dictionary = pool.get_definition(id)
		_check(not authored.is_empty() and authored == RunRestStitchCards.resolve_card_definition(id),
				id + ": genuine Rest-resolved authored base/+ definition")
		for reverse in [false, true]:
			var counterpart := "tinker_pop_shot" if id.contains("field_mend") else "warden_brace"
			var first: String = counterpart if reverse else id
			var second: String = id if reverse else counterpart
			var s := _pair(first, second, 2201)
			var pool_half := _half(1 if reverse else 0, id,
				[] if id.contains("field_mend") else [1, 2, 3],
				[1, 2, 3] if id.contains("field_mend") else [])
			var other_half := _half(0 if reverse else 1, counterpart,
				[1, 2, 3] if counterpart == "tinker_pop_shot" else [],
				[] if counterpart == "tinker_pop_shot" else [1])
			var result := _accepted(s, other_half if reverse else pool_half,
					pool_half if reverse else other_half, id + " both orders " + str(reverse))
			var expected_cost := 3 if id.contains("field_mend") else 2
			_check(result.get("playable", false) and result.cost == expected_cost
					and pool_half["owner"] == "seamstress",
					id + ": authentic receipt, cost and separate owners")
			if id.contains("field_mend"):
				_check(not pool_half["requires_selection"] and pool_half["side"] == "ally"
					and pool_half["target_positions"] == [] and pool_half["affected_positions"] == [1, 2, 3],
					id + ": automatic all-living party, no extra enemy selection")
			else:
				_check(pool_half["requires_selection"] and pool_half["affected_positions"] == [],
					id + ": single chosen living ally")
			_check(s["party"].apply_damage(3, 26), "actual Tinker downed for preview")
			if counterpart == "warden_brace":
				_accepted(s, other_half if reverse else _half(0, id, [1, 2]),
					_half(1, id, [1, 2]) if reverse else other_half,
					id + ": downed ally omitted")
			else:
				_rejected(s, id + ": Tinker owner down fails closed")
	# An unrelated pool card has an authentic Rest receipt but no supported preview.
	for reversed in [false, true]:
		var unsupported := _pair("warden_brace" if reversed else "seamstress_needle_pin",
				"seamstress_needle_pin" if reversed else "warden_brace")
		_check(not unsupported.is_empty() and unsupported["rest"].is_valid(),
				"unsupported pool half still genuinely authored and stitched")
		_rejected(unsupported, "unrelated pool half remains unsupported")
	var field := _pair("seamstress_field_mend", "warden_brace")
	_check(field["party"].apply_damage(3, 26), "real downed Tinker with living Field Mend owner")
	_accepted(field, _half(0, "seamstress_field_mend", [], [1, 2]),
			_half(1, "warden_brace", [], [1]), "Field Mend excludes torn ally, targets nobody manually")
	field["party"] = _party(["seamstress", "warden", "tinker"])
	_rejected(field, "Field Mend illegal from front after swap")
	field["party"] = _party(["warden", "tinker", "seamstress"])
	_accepted(field, _half(0, "seamstress_field_mend", [], [1, 2, 3]),
			_half(1, "warden_brace", [], [1]), "Field Mend legal from back")


func _test_pool_self_previews() -> void:
	for id in CombatPoolEnergyCards.SUPPORTED_IDS + CombatStitchedCards.SPARE_PARTS_IDS:
		var authored := RunRestStitchCards.resolve_card_definition(id)
		_check(not authored.is_empty() and authored.target_kind == "self", "authored self half " + id)
		for reverse in [false, true]:
			var s := _pair("warden_brace" if reverse else id, id if reverse else "warden_brace")
			for order in [["warden", "seamstress", "tinker"], ["warden", "tinker", "seamstress"],
					["tinker", "warden", "seamstress"], ["seamstress", "warden", "tinker"]]:
				var typed_order: Array[String] = []
				typed_order.assign(order)
				s.party = _party(typed_order)
				var position: int = order.find(authored.owner) + 1
				if not authored.from_positions.has(position):
					_rejected(s, id + ": current owner slot illegal")
				else:
					var own := _half(1 if reverse else 0, id, [], [position])
					var brace := _half(0 if reverse else 1, "warden_brace", [], [order.find("warden") + 1])
					_accepted(s, brace if reverse else own, own if reverse else brace, id + ": owner-only both orders")
				s.party = _party(typed_order)
				_check(s.party.apply_damage(position, 999) and s.party.is_downed(position), "real self owner downed")
				_rejected(s, id + ": downed owner")
			s.party = _party()
			var forged: Dictionary = s.snapshot.duplicate(true)
			forged.descriptors[s.id]["second_half" if reverse else "first_half"].effects["draw"] = 99
			_rejected(s, id + ": forged effects receipt", forged)
			s.rest._descriptors[s.id]["second_half" if reverse else "first_half"].effects["draw"] = 99
			s.snapshot = s.rest.get_snapshot()
			_rejected(s, id + ": forged internal canonical descriptor")
			var poor := _pair("warden_brace" if reverse else id, id if reverse else "warden_brace")
			_check(poor.deck.try_spend_energy(3), "spend actual shared energy")
			_rejected(poor, id + ": no advance credit from energy half")
