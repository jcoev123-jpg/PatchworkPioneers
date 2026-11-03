extends SceneTree
## V3-1 Scarecrow catalog contract plus scene-free paid Re-Stuff, pitchfork, sack-face Fear,
## Straw Wrap and Pitchfork Hook resolution. The pitchfork suites cover Fork Jab and Pitchfork
## Prick (base and "+"); the Fear suites cover Sack Glare and Sack Grin (base and "+"); the Hook
## suites cover the uncommon pool Pitchfork Hook pair's paid strike-plus-forward-pull proposal.
## All are callable rules-layer transactions only: they do not prove mounted hand/reward
## integration, live combat availability or any later dispatcher/UI wiring, and no live
## enemy-intent suppression or true enemy-roster movement is claimed.

const ScriptClass = preload("res://data/cards/scarecrow_pool_cards.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_rarity_distribution()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_starters_unchanged()
	_test_rng_state()
	_test_re_stuff_paid()
	_test_re_stuff_refusals()
	_test_pitchfork_authentic_records()
	_test_pitchfork_paid_hits()
	_test_pitchfork_block_and_bleed_stacks()
	_test_pitchfork_status_rounding()
	_test_pitchfork_refusals()
	_test_pitchfork_once_only_payment()
	_test_pitchfork_seeded_replay()
	_test_fear_authentic_records()
	_test_fear_paid_plays()
	_test_fear_owner_turn_expiry()
	_test_fear_refusals()
	_test_fear_once_only_payment()
	_test_fear_seeded_replay()
	_test_straw_wrap_authentic_records()
	_test_straw_wrap_paid_plays()
	_test_straw_wrap_draw_exhausted()
	_test_straw_wrap_reshuffle_order()
	_test_straw_wrap_refusals()
	_test_straw_wrap_catalog_preserved()
	_test_straw_wrap_once_only_payment()
	_test_straw_wrap_seeded_replay()
	_test_hook_authentic_records()
	_test_hook_paid_strikes()
	_test_hook_block_and_status_math()
	_test_hook_lethal_keeps_corpse()
	_test_hook_refusals()
	_test_hook_seeded_replay()
	if failures.is_empty():
		print("v3_scarecrow_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_scarecrow_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"scarecrow_pitchfork_prick": {
			"name": "Pitchfork Prick", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 5, "bleed": 1}, "plus_cost": 1,
			"plus_effects": {"damage": 7, "bleed": 2}},
		"scarecrow_crow_peck": {
			"name": "Crow Peck", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_back", "to": [1, 2, 3],
			"effects": {"damage": 4, "ignore_block": true}, "plus_cost": 1,
			"plus_effects": {"damage": 6, "ignore_block": true}},
		"scarecrow_sack_grin": {
			"name": "Sack Grin", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"weak": 1, "cannot_buff_next_turn": true}, "plus_cost": 1,
			"plus_effects": {"weak": 2, "cannot_buff_next_turn": true}},
		"scarecrow_straw_wrap": {
			"name": "Straw Wrap", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 6, "draw": 1}, "plus_cost": 1,
			"plus_effects": {"block": 8, "draw": 1}},
		"scarecrow_crow_flock": {
			"name": "Crow Flock", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"weak": 1, "cannot_buff_next_turn": true}, "plus_cost": 2,
			"plus_effects": {"weak": 2, "cannot_buff_next_turn": true}},
		"scarecrow_re_stuff": {
			"name": "Re-Stuff", "rarity": "uncommon", "cost": 2,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"max_hp_loss": 2, "heal": 10}, "plus_cost": 2,
			"plus_effects": {"max_hp_loss": 2, "heal": 13}},
		"scarecrow_pitchfork_hook": {
			"name": "Pitchfork Hook", "rarity": "uncommon", "cost": 2,
			"from": [1, 2], "target": "enemy_single", "to": [2, 3],
			"effects": {"damage": 7, "pull_forward": 1}, "plus_cost": 2,
			"plus_effects": {"damage": 10, "pull_forward": 1}},
		"scarecrow_harvest_fright": {
			"name": "Harvest Fright", "rarity": "rare", "cost": 3,
			"from": [1, 2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"damage": 4, "weak": 2, "cannot_buff_next_turn": true},
			"plus_cost": 3,
			"plus_effects": {"damage": 6, "weak": 3, "cannot_buff_next_turn": true}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "scarecrow",
		"cost": spec["plus_cost"] if upgraded else spec["cost"],
		"from_positions": spec["from"],
		"target_kind": spec["target"],
		"to_positions": spec["to"],
		"effects": spec["plus_effects"] if upgraded else spec["effects"],
		"illustration_path": "res://assets/paper/cards/" + base_id + ".png",
		"starting_copies": 0,
		"rarity": spec["rarity"],
		"reward_eligible": not upgraded,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


func _test_all_base_and_upgrades() -> void:
	var catalog = ScriptClass.new()
	var cases: Dictionary = _cases()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var seen: Dictionary = {}
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(not seen.has(base_id), base_id + " is a distinct base identifier")
		seen[base_id] = true
		_check(base_id.begins_with("scarecrow_"), base_id + " uses the Scarecrow ID prefix")
		_check(plus_id == base_id + "_plus", base_id + " upgrade ID is its base ID plus _plus")
		_check(base_ids.has(base_id), base_id + " is listed as a base")
		_check(base_ids.count(base_id) == 1, base_id + " has one base-list occurrence")
		_check(not base_ids.has(plus_id), plus_id + " is never a base candidate")
		_check(all_ids.has(base_id) and all_ids.has(plus_id), base_id + " both IDs discoverable")
		_check(all_ids.count(base_id) == 1 and all_ids.count(plus_id) == 1,
			base_id + " base and upgrade each appear once in the ID listing")
		_check(catalog.has_card(base_id) and catalog.has_card(plus_id), base_id + " both exist")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and record.get(field) == expected[field],
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has effect descriptors")
			_check(record.get("owner") == "scarecrow", card_id + " is Scarecrow-owned")
			_check(record.get("starting_copies") == 0, card_id + " is never a starter copy")
			_check(record.get("reward_eligible") == not upgraded,
				card_id + " reward eligibility matches its base/plus role")
			_check(String(record.get("illustration_path")).ends_with("/" + base_id + ".png"),
				card_id + " points at the shared base art path")
		_check(base_id != plus_id, base_id + " upgrade has a distinct stable ID")
		_check(catalog.get_definition(plus_id).get("upgrade_of") == base_id,
			plus_id + " records its base card")
		_check(not catalog.get_definition(base_id).has("upgrade_of"),
			base_id + " is not itself an upgrade")


func _test_rarity_distribution() -> void:
	var cases: Dictionary = _cases()
	var counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}
	for base_id: String in cases:
		counts[cases[base_id]["rarity"]] += 1
	_check(counts["common"] == 4, "four authored commons")
	_check(counts["uncommon"] == 3, "three authored uncommons")
	_check(counts["rare"] == 1, "one authored rare")


## The five signature mechanics, as authored metadata only (never as live combat behavior).
func _test_special_descriptors() -> void:
	var catalog = ScriptClass.new()

	var peck: Dictionary = catalog.get_definition("scarecrow_crow_peck")
	var peck_plus: Dictionary = catalog.get_definition("scarecrow_crow_peck_plus")
	_check(not peck.is_empty() and not peck_plus.is_empty(), "Crow Peck fixture loaded")
	_check(peck.get("target_kind") == "enemy_back" and peck_plus.get("target_kind") == "enemy_back",
		"Crow Peck targets the backmost living enemy, not a fixed position")
	_check(peck.get("effects") == {"damage": 4, "ignore_block": true}
			and peck_plus.get("effects") == {"damage": 6, "ignore_block": true},
		"Crow Peck carries Block-bypassing damage on base and plus")
	_check(peck.get("from_positions") == [1, 2, 3] and peck_plus.get("from_positions") == [1, 2, 3],
		"Crow Peck is usable from every hero position")
	_check(peck.get("to_positions") == [1, 2, 3] and peck_plus.get("to_positions") == [1, 2, 3],
		"Crow Peck keeps its position/target pair after upgrade")

	for base_id: String in ["scarecrow_sack_grin", "scarecrow_crow_flock",
			"scarecrow_harvest_fright"]:
		for upgraded: bool in [false, true]:
			var card_id: String = base_id + ("_plus" if upgraded else "")
			var record: Dictionary = catalog.get_definition(card_id)
			var effects: Dictionary = record.get("effects", {})
			_check(effects.get("cannot_buff_next_turn") == true,
				card_id + " carries Fear's buff lock")
			_check(typeof(effects.get("cannot_buff_next_turn")) == TYPE_BOOL,
				card_id + " expresses the buff lock as one-turn metadata, not a duration counter")
			_check(effects.has("weak"), card_id + " carries Fear's Weak")
	var sack: Dictionary = catalog.get_definition("scarecrow_sack_grin")
	var sack_plus: Dictionary = catalog.get_definition("scarecrow_sack_grin_plus")
	_check((sack.get("effects") as Dictionary).get("weak") == 1
			and (sack_plus.get("effects") as Dictionary).get("weak") == 2,
		"Sack Grin+ raises only Weak")
	var flock: Dictionary = catalog.get_definition("scarecrow_crow_flock")
	_check(flock.get("target_kind") == "enemy_all" and flock.get("to_positions") == [1, 2, 3],
		"Crow Flock applies Fear to every enemy")
	var fright_plus: Dictionary = catalog.get_definition("scarecrow_harvest_fright_plus")
	_check(fright_plus.get("effects") == {"damage": 6, "weak": 3, "cannot_buff_next_turn": true},
		"Harvest Fright+ scales damage and Weak but locks buffs for the same single turn")

	var re_stuff: Dictionary = catalog.get_definition("scarecrow_re_stuff")
	var re_stuff_plus: Dictionary = catalog.get_definition("scarecrow_re_stuff_plus")
	_check(re_stuff.get("target_kind") == "self" and re_stuff.get("to_positions") == [],
		"Re-Stuff targets only the acting Scarecrow")
	_check(re_stuff.get("effects") == {"max_hp_loss": 2, "heal": 10}
			and re_stuff_plus.get("effects") == {"max_hp_loss": 2, "heal": 13},
		"Re-Stuff trades 2 max HP for a heal, and the max-HP cost never scales")
	_check((re_stuff_plus.get("effects") as Dictionary).get("max_hp_loss") == 2,
		"Re-Stuff+ keeps the permanent 2 max-HP cost")

	var hook: Dictionary = catalog.get_definition("scarecrow_pitchfork_hook")
	var hook_plus: Dictionary = catalog.get_definition("scarecrow_pitchfork_hook_plus")
	_check(hook.get("target_kind") == "enemy_single" and hook.get("from_positions") == [1, 2],
		"Pitchfork Hook is a front/middle enemy attack")
	_check(hook.get("to_positions") == [2, 3] and hook_plus.get("to_positions") == [2, 3],
		"Pitchfork Hook can only hook an enemy that has room in front of it")
	_check((hook.get("effects") as Dictionary).get("pull_forward") == 1
			and (hook_plus.get("effects") as Dictionary).get("pull_forward") == 1,
		"Pitchfork Hook pulls exactly one position, unscaled by the upgrade")
	_check(hook.get("effects") == {"damage": 7, "pull_forward": 1}
			and hook_plus.get("effects") == {"damage": 10, "pull_forward": 1},
		"Pitchfork Hook+ raises only its damage")


func _test_detached_results() -> void:
	var catalog = ScriptClass.new()
	var sample: Dictionary = catalog.get_definition("scarecrow_pitchfork_prick")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["bleed"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("scarecrow_pitchfork_prick")
	_check(pristine.get("effects") == {"damage": 5, "bleed": 1},
		"effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [1, 2],
		"FROM arrays are deeply detached from catalog")
	_check(pristine.get("to_positions") == [1, 2],
		"TO arrays are deeply detached from catalog")
	_check(pristine.get("id") == "scarecrow_pitchfork_prick", "metadata is detached")

	var upgraded: Dictionary = catalog.get_definition("scarecrow_straw_wrap_plus")
	upgraded["effects"]["block"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	_check(catalog.get_definition("scarecrow_straw_wrap_plus").get("effects") == {"block": 8, "draw": 1},
		"upgrade effects are detached")
	_check(catalog.get_definition("scarecrow_straw_wrap_plus").get("from_positions") == [1, 2, 3],
		"upgrade FROM is detached")
	_check(catalog.get_definition("scarecrow_straw_wrap_plus").get("to_positions") == [],
		"empty upgrade TO is detached")

	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("scarecrow_straw_wrap") and all_ids.has("scarecrow_straw_wrap_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("scarecrow_straw_wrap"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("scarecrow_straw_wrap_plus"), "all-ID array is a fresh copy")
	_check(ScriptClass.new().get_definition("scarecrow_pitchfork_prick").get("effects") == pristine.get("effects"),
		"fresh instance retains canonical definition")


func _test_invalid_ids() -> void:
	var catalog = ScriptClass.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("scarecrow_crow_peck"),
		"", "scarecrow_not_a_card", "crow_peck", "scarecrow_crow_peck+",
		"scarecrow_crow_peck_plus_plus", "SCARECROW_CROW_PECK", " scarecrow_crow_peck"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_starters_unchanged() -> void:
	var starter := StarterCards.new()
	var pool = ScriptClass.new()
	var deck: Array[String] = starter.get_starting_deck()
	var raw: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array, "authored starter_deck.json parses as array")
	if not parsed is Array:
		return
	_check(deck.has("warden_strike") and deck.has("tinker_pop_shot"),
		"StarterCards still builds a populated starting deck")
	# Named starters of the three live heroes only: the roster and its totals may grow later.
	var expected_starters: Dictionary = {
		"warden_strike": {"owner": "warden", "count": 2, "effects": {"damage": 6}},
		"warden_brace": {"owner": "warden", "count": 1, "effects": {"block": 7}},
		"warden_shield_bash": {"owner": "warden", "count": 1, "effects": {"damage": 8, "weak": 1}},
		"seamstress_prick": {"owner": "seamstress", "count": 2, "effects": {"damage": 3, "bleed": 2}},
		"seamstress_mend": {"owner": "seamstress", "count": 1, "effects": {"heal": 5}},
		"seamstress_stitch_up": {"owner": "seamstress", "count": 1, "effects": {"block": 5}},
		"tinker_pop_shot": {"owner": "tinker", "count": 2, "effects": {"damage": 5}},
		"tinker_scrap_bomb": {"owner": "tinker", "count": 1, "effects": {"damage": 4}},
		"tinker_tune_up": {"owner": "tinker", "count": 1, "effects": {"draw": 1}},
	}
	for id: String in expected_starters:
		var starter_record: Dictionary = starter.get_definition(id)
		_check(not starter_record.is_empty(), id + " remains a StarterCards definition")
		_check(starter_record.get("owner") == expected_starters[id]["owner"],
			id + " remains owned by its live hero")
		_check(starter_record.get("effects") == expected_starters[id]["effects"],
			id + " printed effects unchanged")
		_check(starter_record.get("starting_copies") == expected_starters[id]["count"],
			id + " catalog multiplicity unchanged")
		_check(deck.count(id) == expected_starters[id]["count"], id + " runtime deck copies unchanged")
		_check(parsed.count(id) == expected_starters[id]["count"], id + " JSON deck copies unchanged")
	_check(not starter.has_card("scarecrow_crow_peck"),
		"Scarecrow pool cards have not entered StarterCards")
	for id: String in pool.get_all_card_ids():
		_check(not starter.has_card(id), id + " is not a starter definition")
		_check(not deck.has(id), id + " is absent from the runtime starter deck")
		_check(not parsed.has(id), id + " is absent from the authored starter deck")


func _test_rng_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var initial_state: int = rng.state
	var catalog = ScriptClass.new()
	var ids: Array[String] = catalog.get_all_card_ids()
	for id: String in ids:
		var definition: Dictionary = catalog.get_definition(id)
		_check(not definition.is_empty(), id + " resolves while enumerating")
	catalog.get_base_ids()
	catalog.has_card("scarecrow_crow_peck")
	catalog.get_upgrade_id("scarecrow_crow_peck")
	catalog.get_definition("unknown_scarecrow_card")
	_check(rng.state == initial_state, "constructing and enumerating the catalog consumes no run RNG")


func _re_stuff_fixture(card_id: String, seat: int = 3, max_hp: int = 30,
		damage: int = 20) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 279
	var cards: Array[String] = [card_id, "warden_strike", "warden_brace",
		"tinker_pop_shot", "tinker_tune_up"]
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn(), "fixture starts genuine shared turn")
	_check(deck.energy == 3 and deck.hand.size() == 5 and deck.hand.count(card_id) == 1,
		"fixture genuinely holds sole requested card at three energy")
	var heroes: Array = [{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "scarecrow", "max_hp": max_hp,
		"statuses": {"weak": 2, "bleed": 1}, "scraps": 17,
		"metadata": {"seams": ["straw", "felt"]}})
	var party := CombatParty.new(heroes)
	_check(party.is_valid() and party.get_hero(seat).get("id") == "scarecrow",
		"fixture has three distinct heroes and Scarecrow in requested seat")
	_check(party.apply_damage(seat, damage), "fixture damages authoritative hero")
	_check(party.gain_block(seat, 7) == not party.is_downed(seat),
		"fixture grants Block only to a living Scarecrow")
	_check(party.gain_block(2 if seat != 2 else 1, 4), "fixture grants ally Block")
	return {"deck": deck, "party": party, "rng": rng, "seat": seat}


func _re_stuff_snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var party: CombatParty = f["party"]
	return {"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"active": deck.turn_active, "heroes": party.get_heroes(), "rng": f["rng"].state}


func _re_stuff_refused(f: Dictionary, card_id: Variant, reason: String,
		target: int = 0) -> void:
	var before := _re_stuff_snapshot(f)
	var result := CombatScarecrowReStuffCards.new().play_card(f["deck"], f["party"], card_id, target)
	_check(not result.get("ok", true) and result.get("reason") == reason,
		"Re-Stuff refuses " + reason)
	_check(_re_stuff_snapshot(f) == before, reason + " preserves all authorities and RNG")
	result["hp_after"] = -999
	_check(_re_stuff_snapshot(f) == before, reason + " receipt is detached")


func _test_re_stuff_paid() -> void:
	for id: String in ["scarecrow_re_stuff", "scarecrow_re_stuff_plus"]:
		for seat: int in [1, 2, 3]:
			var f := _re_stuff_fixture(id, seat)
			var before := _re_stuff_snapshot(f)
			var expected: Array = before["heroes"].duplicate(true)
			var heal := 13 if id.ends_with("_plus") else 10
			expected[seat - 1]["max_hp"] = 28
			expected[seat - 1]["hp"] = 10 + heal
			var result := CombatScarecrowReStuffCards.new().play_card(f["deck"], f["party"], id)
			_check(result.get("ok", false), id + " paid play succeeds in seat " + str(seat))
			_check(result.get("card_id") == id and result.get("cost") == 2
				and result.get("owner_position") == seat, "receipt authenticates paid card and owner")
			_check(result.get("max_hp_before") == 30 and result.get("max_hp_after") == 28
				and result.get("hp_before") == 10 and result.get("hp_after") == 10 + heal,
				"receipt proves independent base/+ max HP and healing amounts")
			_check(f["party"].get_heroes() == expected,
				"only Scarecrow HP/cap change; identities, allies, Block, statuses and metadata retained")
			var deck: CombatDeck = f["deck"]
			var expected_hand: Array = before["hand"].duplicate()
			expected_hand.erase(id)
			_check(deck.energy == 1 and deck.hand == expected_hand and deck.discard_pile == [id],
				"exactly one held copy discarded for two shared energy")
			_check(deck.draw_pile == before["draw"] and f["rng"].state == before["rng"],
				"successful play does not draw, shuffle or advance RNG")
			result["hp_after"] = -999
			_check(f["party"].get_heroes() == expected, "success receipt is detached")
			# Restore affordability so replay is rejected specifically for the missing held copy.
			deck.combat_state.energy = 3
			_re_stuff_refused(f, id, "card_not_held")
		# Full HP must clamp first, and damaged healing must stop at the reduced cap.
		for damage: int in [0, 3]:
			var f := _re_stuff_fixture(id, 2, 30, damage)
			var result := CombatScarecrowReStuffCards.new().play_card(f["deck"], f["party"], id)
			_check(result.get("ok", false) and f["party"].get_hero(2)["hp"] == 28
				and f["party"].get_hero(2)["max_hp"] == 28, "clamp/heal respects reduced cap")
	# Positive remaining cap is legal even below ten; no arbitrary minimum.
	var tiny := _re_stuff_fixture("scarecrow_re_stuff", 3, 3, 1)
	var paid := CombatScarecrowReStuffCards.new().play_card(tiny["deck"], tiny["party"], "scarecrow_re_stuff")
	_check(paid.get("ok", false) and tiny["party"].get_hero(3)["max_hp"] == 1
		and tiny["party"].get_hero(3)["hp"] == 1, "max HP three can legally pay two")


func _test_re_stuff_refusals() -> void:
	var id := "scarecrow_re_stuff"
	var f := _re_stuff_fixture(id)
	_re_stuff_refused(f, "scarecrow_re_stuff_plus", "card_not_held")
	for invalid: Variant in [null, {}, StringName("scarecrow_re_stuff"), "missing", "warden_strike", "scarecrow_crow_peck"]:
		_re_stuff_refused(f, invalid, "unsupported_card")
	for target: int in [-1, 1, 2, 3, 4]:
		_re_stuff_refused(f, id, "invalid_target", target)
	_check(f["deck"].try_spend_energy(2) and f["deck"].energy == 1,
		"insufficient-energy fixture is genuine")
	_re_stuff_refused(f, id, "insufficient_energy")
	f = _re_stuff_fixture(id)
	_check(f["deck"].combat_state.end_player_turn() and f["deck"].hand.has(id),
		"inactive fixture retains held card")
	_re_stuff_refused(f, id, "inactive_turn")
	f = _re_stuff_fixture(id, 3, 30, 30)
	_check(f["party"].is_downed(3), "downed fixture has zero HP")
	_re_stuff_refused(f, id, "owner_downed")
	f = _re_stuff_fixture(id)
	f["party"] = CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 25}, {"id": "seamstress", "max_hp": 30}])
	_check(f["party"].is_valid() and f["party"].get_hero(3)["id"] == "seamstress",
		"foreign roster is valid, living and lacks Scarecrow")
	_re_stuff_refused(f, id, "owner_missing")
	for cap: int in [1, 2]:
		f = _re_stuff_fixture(id, 3, cap, 0)
		_check(not f["party"].is_downed(3) and f["party"].get_hero(3)["max_hp"] == cap,
			"max-HP-cost fixture is alive with insufficient cap")
		_re_stuff_refused(f, id, "max_hp_cost")


# --- Scarecrow pitchfork punctures: Fork Jab and Pitchfork Prick (base and "+") ---------------
## Authentic printings, stated independently of the resolver. `catalog` is the one authored
## catalog allowed to own each ID (starter for Fork Jab, reward pool for Pitchfork Prick).

const PITCHFORK_IDS := [
	"scarecrow_fork_jab", "scarecrow_fork_jab_plus",
	"scarecrow_pitchfork_prick", "scarecrow_pitchfork_prick_plus",
]

const PITCHFORK_CARDS := {
	"scarecrow_fork_jab": {"catalog": "starter", "cost": 1, "damage": 4, "bleed": 1},
	"scarecrow_fork_jab_plus": {"catalog": "starter", "cost": 1, "damage": 6, "bleed": 2},
	"scarecrow_pitchfork_prick": {"catalog": "pool", "cost": 1, "damage": 5, "bleed": 1},
	"scarecrow_pitchfork_prick_plus": {"catalog": "pool", "cost": 1, "damage": 7, "bleed": 2},
}

const PITCHFORK_FILLERS := ["filler_bobbin", "filler_thread", "filler_twig", "filler_scrap"]

const PITCHFORK_MAX_HP := {"warden": 40, "scarecrow": 32, "seamstress": 30, "tinker": 25}


func _test_pitchfork_authentic_records() -> void:
	var starter := ScarecrowStarterCards.new()
	var pool = ScriptClass.new()
	var service := CombatScarecrowPitchforkCards.new()
	for card_id: String in PITCHFORK_IDS:
		var spec: Dictionary = PITCHFORK_CARDS[card_id]
		var owner_catalog: Variant = starter if spec["catalog"] == "starter" else pool
		var other_catalog: Variant = pool if spec["catalog"] == "starter" else starter
		var record: Dictionary = owner_catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " has an authored record")
		_check(record.get("id") == card_id and record.get("owner") == "scarecrow",
			card_id + " is the Scarecrow record for its own ID")
		_check(record.get("cost") == 1, card_id + " prints one energy")
		_check(record.get("target_kind") == "enemy_single", card_id + " punctures one enemy")
		_check(record.get("from_positions") == [1, 2] and record.get("to_positions") == [1, 2],
			card_id + " reaches enemy slots 1-2 only from hero seats 1-2")
		_check(record.get("effects") == {"damage": spec["damage"], "bleed": spec["bleed"]},
			card_id + " prints exactly its damage and Bleed pair")
		_check(not other_catalog.has_card(card_id),
			card_id + " is owned by only one Scarecrow catalog")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
		if spec["catalog"] == "pool":
			_check(record.get("rarity") == "common" and record.get("starting_copies") == 0,
				card_id + " stays a common non-starter reward record")
			_check(record.get("reward_eligible") == not card_id.ends_with("_plus"),
				card_id + " keeps base-only reward eligibility")
		else:
			_check(record.get("reward_eligible") == false, card_id + " stays a non-reward starter")
	_check(starter.get_upgrade_id("scarecrow_fork_jab") == "scarecrow_fork_jab_plus"
		and starter.get_upgrade_id("scarecrow_fork_jab_plus") == "",
		"Fork Jab keeps its one-way starter upgrade link")
	_check(pool.get_upgrade_id("scarecrow_pitchfork_prick") == "scarecrow_pitchfork_prick_plus"
		and pool.get_upgrade_id("scarecrow_pitchfork_prick_plus") == "",
		"Pitchfork Prick keeps its one-way pool upgrade link")
	for unsupported: Variant in ["scarecrow_crow_peck", "scarecrow_crow_dive",
			"scarecrow_sack_glare", "scarecrow_sack_grin", "scarecrow_straw_padding",
			"scarecrow_straw_wrap", "scarecrow_re_stuff", "scarecrow_crow_flock",
			"scarecrow_pitchfork_hook", "scarecrow_harvest_fright",
			"warden_strike", "seamstress_prick", "tinker_pop_shot",
			"scarecrow_fork_jab_plus_plus", "scarecrow_pitchfork_prick_plus_plus",
			"fork_jab", "pitchfork_prick", "SCARECROW_FORK_JAB", " scarecrow_fork_jab", ""]:
		_check(not service.is_supported_card(unsupported),
			str(unsupported) + ": not a supported pitchfork puncture")
	_check(not service.is_supported_card(null) and not service.is_supported_card(5)
		and not service.is_supported_card(StringName("scarecrow_fork_jab"))
		and not service.is_supported_card({}) and not service.is_supported_card([]),
		"non-string IDs are never supported")


## AC1: on a genuine three-energy turn each printing pays once and lands its exact printed
## damage plus Bleed on a living enemy in slot 1 or 2, from a Scarecrow in seat 1 or 2.
func _test_pitchfork_paid_hits() -> void:
	for card_id: String in PITCHFORK_IDS:
		var spec: Dictionary = PITCHFORK_CARDS[card_id]
		for seat: int in [1, 2]:
			for target: int in [1, 2]:
				var f := _pitchfork_fixture(card_id, seat)
				var before := _pitchfork_snapshot(f)
				_check(int(before["hand"].count(card_id)) == 1 and int(before["energy"]) == 3,
					card_id + ": fixture really holds one copy at three energy")
				_check(f["party"].get_hero(seat).get("id") == "scarecrow"
						and f["party"].get_hero(seat).get("position") == seat,
					card_id + ": the authoritative Scarecrow is in seat " + str(seat))
				var result := _pitchfork_paid(f, card_id, target, int(spec["damage"]))
				_check(result.get("owner_position") == seat,
					card_id + ": receipt reports the actual owner seat " + str(seat))
				# Literal expected HP/Block/Bleed: slot 1 is 20 HP with no Block, slot 2 is
				# 14 HP behind 2 Block.
				var literal_hp: int
				if target == 1:
					literal_hp = 20 - int(spec["damage"])
				else:
					literal_hp = 14 - (int(spec["damage"]) - 2)
				var enemy_after: Dictionary = f["enemies"].get_enemy(target)
				_check(enemy_after["hp"] == literal_hp and enemy_after["block"] == 0
						and enemy_after.get("statuses", {}).get("bleed", 0) == int(spec["bleed"]),
					card_id + ": literal HP/Block/Bleed after the puncture on slot "
						+ str(target))
				_check(f["deck"].energy == 2 and f["deck"].hand.count(card_id) == 0
						and f["deck"].discard_pile == [card_id],
					card_id + ": exactly one copy charged and discarded for one energy")
				_check(f["rng"].state == before["rng"],
					card_id + ": a puncture never advances the seeded run RNG")
				_check(f["deck"].draw_pile == before["draw"],
					card_id + ": a puncture never draws or reshuffles")
				# The third slot exists but is outside the printed 1-2 window.
				_check(f["enemies"].get_enemy(3).get("statuses", {}) == {},
					card_id + ": Bleed is added only to the selected enemy")


## AC2: Block absorbs the hit first while the printed Bleed still lands, and Bleed stacks onto
## an existing counter. The Seamstress-only +1 passive never applies to the Scarecrow.
func _test_pitchfork_block_and_bleed_stacks() -> void:
	for card_id: String in PITCHFORK_IDS:
		var spec: Dictionary = PITCHFORK_CARDS[card_id]
		var block := 12
		var f := _pitchfork_fixture(card_id, 2, [
			{"max_hp": 20, "hp": 20, "block": block},
			{"max_hp": 16, "hp": 16},
			{"max_hp": 14, "hp": 14},
		])
		_check(block > int(spec["damage"]),
			card_id + ": fixture Block really exceeds the printed hit")
		var before := _pitchfork_snapshot(f)
		_pitchfork_paid(f, card_id, 1, int(spec["damage"]))
		var target: Dictionary = f["enemies"].get_enemy(1)
		_check(target["hp"] == 20 and target["block"] == block - int(spec["damage"]),
			card_id + ": fully blocked damage leaves HP untouched and spends Block")
		_check(target.get("statuses", {}).get("bleed", 0) == spec["bleed"],
			card_id + ": the printed Bleed lands even through a full Block")
		_check(f["enemies"].get_enemy(2).get("statuses", {}) == {}
				and f["enemies"].get_enemy(3)["hp"] == 14,
			card_id + ": unselected enemies keep no Bleed and full HP")
		_check(f["deck"].energy == 2 and f["deck"].discard_pile == [card_id],
			card_id + ": even a fully blocked hit still pays its one energy")
		var expected := _pitchfork_expected(before, card_id, 1, int(spec["damage"]), spec["bleed"])
		_check(_pitchfork_snapshot(f) == expected, card_id + ": blocked oracle is exact")

		# Partial Block plus a pre-existing Bleed stack.
		f = _pitchfork_fixture(card_id, 1, [
			{"max_hp": 20, "hp": 20, "block": 3, "statuses": {"bleed": 4}},
			{"max_hp": 18, "hp": 18},
		])
		before = _pitchfork_snapshot(f)
		_check(f["enemies"].get_enemy(1).get("statuses", {}).get("bleed", 0) == 4,
			card_id + ": fixture enemy really starts at Bleed 4")
		_pitchfork_paid(f, card_id, 1, int(spec["damage"]))
		target = f["enemies"].get_enemy(1)
		_check(target["block"] == 0
				and target["hp"] == 20 - (int(spec["damage"]) - 3),
			card_id + ": the three Block absorb first and the rest hits HP")
		_check(target.get("statuses", {}).get("bleed", 0) == 4 + int(spec["bleed"]),
			card_id + ": printed Bleed stacks onto the existing counter")
		expected = _pitchfork_expected(before, card_id, 1, int(spec["damage"]), spec["bleed"])
		_check(_pitchfork_snapshot(f) == expected, card_id + ": stacked-bleed oracle is exact")

	# A living Seamstress beside the Scarecrow grants no +1 Bleed to his puncture.
	var seamstress_f := _pitchfork_fixture("scarecrow_fork_jab", 1, [
		{"max_hp": 20, "hp": 20},
	], 2468, ["warden", "seamstress"])
	var result := _pitchfork_paid(seamstress_f, "scarecrow_fork_jab", 1, 4)
	_check(result.get("bleed_applied") == 1
			and seamstress_f["enemies"].get_enemy(1).get("statuses", {}).get("bleed", 0) == 1,
		"a living Seamstress adds no passive +1 Bleed to Fork Jab")


## AC2: Weak/Exposed/Tangled keep CombatStatuses' existing floor and Tangled +2 on the real
## attacker and defender records; nothing is consumed or aged.
func _test_pitchfork_status_rounding() -> void:
	var cases: Array[Dictionary] = [
		{"label": "Weak takes 25 percent off", "attacker": {"weak": 1}, "defender": {},
			"damage": {"scarecrow_fork_jab": 3, "scarecrow_fork_jab_plus": 4,
				"scarecrow_pitchfork_prick": 3, "scarecrow_pitchfork_prick_plus": 5}},
		{"label": "Exposed adds 50 percent", "attacker": {}, "defender": {"exposed": 1},
			"damage": {"scarecrow_fork_jab": 6, "scarecrow_fork_jab_plus": 9,
				"scarecrow_pitchfork_prick": 7, "scarecrow_pitchfork_prick_plus": 10}},
		{"label": "Weak plus Exposed combines at nine eighths",
			"attacker": {"weak": 2}, "defender": {"exposed": 3},
			"damage": {"scarecrow_fork_jab": 4, "scarecrow_fork_jab_plus": 6,
				"scarecrow_pitchfork_prick": 5, "scarecrow_pitchfork_prick_plus": 7}},
		{"label": "positive-base Tangled adds two after scaling", "attacker": {},
			"defender": {"tangled": 2},
			"damage": {"scarecrow_fork_jab": 6, "scarecrow_fork_jab_plus": 8,
				"scarecrow_pitchfork_prick": 7, "scarecrow_pitchfork_prick_plus": 9}},
		{"label": "Exposed then one Tangled +2", "attacker": {},
			"defender": {"exposed": 1, "tangled": 1},
			"damage": {"scarecrow_fork_jab": 8, "scarecrow_fork_jab_plus": 11,
				"scarecrow_pitchfork_prick": 9, "scarecrow_pitchfork_prick_plus": 12}},
	]
	for spec: Dictionary in cases:
		for card_id: String in PITCHFORK_IDS:
			var label: String = spec["label"] + " (" + card_id + ")"
			var f := _pitchfork_fixture(card_id, 2)
			f["party"]._heroes[1]["statuses"] = (spec["attacker"] as Dictionary).duplicate(true)
			f["enemies"]._enemies[1]["statuses"] = (spec["defender"] as Dictionary).duplicate(true)
			var expected_damage: int = int(spec["damage"][card_id])
			var result := _pitchfork_paid(f, card_id, 2, expected_damage)
			_check(result.get("damage") == expected_damage,
				label + ": adjusted damage is " + str(expected_damage))
			_check(f["party"].get_hero(2).get("statuses", {}) == spec["attacker"],
				label + ": the attacker's status record was not consumed or aged")
			var merged: Dictionary = (spec["defender"] as Dictionary).duplicate(true)
			merged["bleed"] = int(merged.get("bleed", 0)) + int(PITCHFORK_CARDS[card_id]["bleed"])
			_check(f["enemies"].get_enemy(2).get("statuses", {}) == merged,
				label + ": the defender keeps its statuses and gains the printed Bleed only")


## AC3: every invalid request is refused before payment and leaves all authorities untouched.
func _test_pitchfork_refusals() -> void:
	var service := CombatScarecrowPitchforkCards.new()

	var f := _pitchfork_fixture("scarecrow_fork_jab", 2)
	var before := _pitchfork_snapshot(f)
	for broken in [null, 5, StringName("scarecrow_fork_jab"), "", {},
			"scarecrow_re_stuff", "warden_strike",
			"scarecrow_fork_jab_plus_plus", "SCARECROW_FORK_JAB"]:
		var result := service.play_card(f["deck"], f["party"], f["enemies"], broken, 1)
		_check(result.get("ok") == false and result.get("reason") == "unsupported_card",
			"unsupported card refuses: " + str(broken))
	_check(_pitchfork_snapshot(f) == before, "unsupported cards preserve every authority")

	_check(service.play_card(null, f["party"], f["enemies"], "scarecrow_fork_jab", 1)
			.get("reason") == "invalid_request", "null deck refused")
	_check(service.play_card(f["deck"], null, f["enemies"], "scarecrow_fork_jab", 1)
			.get("reason") == "invalid_request", "null party refused")
	_check(service.play_card(f["deck"], f["party"], null, "scarecrow_fork_jab", 1)
			.get("reason") == "invalid_request", "null enemies refused")
	_check(_pitchfork_snapshot(f) == before, "null authorities preserve every authority")

	var inactive := _pitchfork_fixture("scarecrow_fork_jab", 2)
	_check(inactive["deck"].end_turn(), "inactive fixture really ends the shared turn")
	_pitchfork_refused(inactive, "scarecrow_fork_jab", 1, "inactive_turn")

	var unheld := _pitchfork_fixture("scarecrow_pitchfork_prick", 2)
	_pitchfork_refused(unheld, "scarecrow_fork_jab", 1, "card_not_held")
	var poor := _pitchfork_fixture("scarecrow_pitchfork_prick", 2)
	_check(poor["deck"].try_spend_energy(3) and poor["deck"].energy == 0,
		"insufficient-energy fixture really spent the whole budget")
	_pitchfork_refused(poor, "scarecrow_pitchfork_prick", 1, "insufficient_energy")

	var no_owner := _pitchfork_fixture("scarecrow_fork_jab", 2)
	no_owner["party"] = CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 25},
	])
	_check(no_owner["party"].is_valid() and no_owner["party"].get_hero(2).get("id") == "seamstress",
		"missing-owner fixture is a valid living party without a Scarecrow")
	_pitchfork_refused(no_owner, "scarecrow_fork_jab", 1, "owner_missing")

	var torn := _pitchfork_fixture("scarecrow_fork_jab", 1)
	_check(torn["party"].apply_damage(1, 32) and torn["party"].is_downed(1),
		"downed-owner fixture really has zero HP on the Scarecrow")
	_pitchfork_refused(torn, "scarecrow_fork_jab", 1, "owner_downed")

	var rear_seat := _pitchfork_fixture("scarecrow_fork_jab", 3)
	_check(rear_seat["party"].is_valid() and rear_seat["party"].get_hero(3).get("id") == "scarecrow"
			and not rear_seat["party"].is_downed(3),
		"rear-seat fixture is a valid, living Scarecrow outside the printed FROM seats")
	_pitchfork_refused(rear_seat, "scarecrow_fork_jab", 1, "owner_illegal_position")

	var target_f := _pitchfork_fixture("scarecrow_fork_jab", 2)
	for bad_target: int in [0, 3, 4, -1]:
		_pitchfork_refused(target_f, "scarecrow_fork_jab", bad_target, "invalid_target")
	var two_slots := _pitchfork_fixture("scarecrow_fork_jab", 2, [
		{"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10},
	])
	_pitchfork_refused(two_slots, "scarecrow_fork_jab", 3, "invalid_target")
	var slain := _pitchfork_fixture("scarecrow_fork_jab", 2, [
		{"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10},
	])
	_check(slain["enemies"].apply_damage(2, 10) and slain["enemies"].is_slain(2),
		"slain-target fixture really killed the selected enemy slot")
	_pitchfork_refused(slain, "scarecrow_fork_jab", 2, "invalid_target")

	var duplicate := _pitchfork_fixture("scarecrow_fork_jab", 2)
	duplicate["party"]._heroes[0]["id"] = "scarecrow"
	_check(duplicate["party"].get_hero(1).get("id") == "scarecrow"
			and duplicate["party"].get_hero(2).get("id") == "scarecrow",
		"duplicate-identity fixture really repeats the owner ID")
	_pitchfork_refused(duplicate, "scarecrow_fork_jab", 1, "invalid_party")

	var short_party := _pitchfork_fixture("scarecrow_fork_jab", 2)
	short_party["party"] = CombatParty.new([{"id": "scarecrow", "max_hp": 32},
		{"id": "warden", "max_hp": 40}])
	_check(not short_party["party"].is_valid(), "short-party fixture is really invalid")
	_pitchfork_refused(short_party, "scarecrow_fork_jab", 1, "invalid_party")

	var bad_hp := _pitchfork_fixture("scarecrow_fork_jab", 2)
	bad_hp["party"]._heroes[1]["hp"] = 99
	_pitchfork_refused(bad_hp, "scarecrow_fork_jab", 1, "invalid_party")

	var bad_status := _pitchfork_fixture("scarecrow_fork_jab", 2)
	bad_status["party"]._heroes[0]["statuses"] = {"forged": 1}
	_pitchfork_refused(bad_status, "scarecrow_fork_jab", 1, "malformed_statuses")
	var bad_status_count := _pitchfork_fixture("scarecrow_fork_jab", 2)
	bad_status_count["enemies"]._enemies[0]["statuses"] = {"bleed": "2"}
	_pitchfork_refused(bad_status_count, "scarecrow_fork_jab", 2, "malformed_statuses")

	var empty_roster := _pitchfork_fixture("scarecrow_fork_jab", 2)
	empty_roster["enemies"] = CombatEnemies.new([])
	_check(not empty_roster["enemies"].is_valid(), "empty-roster fixture is really invalid")
	_pitchfork_refused(empty_roster, "scarecrow_fork_jab", 1, "invalid_enemies")

	var bad_enemy := _pitchfork_fixture("scarecrow_fork_jab", 2)
	bad_enemy["enemies"]._enemies[1]["hp"] = 99
	_pitchfork_refused(bad_enemy, "scarecrow_fork_jab", 2, "invalid_enemies")

	# The status addition itself is preflighted: an overflowing Bleed counter refuses unpaid.
	var overflow := _pitchfork_fixture("scarecrow_fork_jab", 2)
	overflow["enemies"]._enemies[1]["statuses"] = {"bleed": CombatEnemies.MAX_INT}
	_pitchfork_refused(overflow, "scarecrow_fork_jab", 2, "malformed_statuses")
	var near_overflow := _pitchfork_fixture("scarecrow_fork_jab_plus", 2)
	near_overflow["enemies"]._enemies[1]["statuses"] = {"bleed": CombatEnemies.MAX_INT - 1}
	_pitchfork_refused(near_overflow, "scarecrow_fork_jab_plus", 2, "malformed_statuses")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry := _pitchfork_fixture("scarecrow_fork_jab", 2)
	_pitchfork_refused(retry, "scarecrow_fork_jab", 3, "invalid_target")
	_pitchfork_refused(retry, "scarecrow_pitchfork_prick", 1, "card_not_held")
	_pitchfork_paid(retry, "scarecrow_fork_jab", 1, 4)
	_check(retry["deck"].energy == 2 and retry["deck"].discard_pile == ["scarecrow_fork_jab"],
		"retry: the authentic play then charges and discards exactly once")


## AC3: one genuine held copy is charged and discarded once; replay is refused and inert.
func _test_pitchfork_once_only_payment() -> void:
	var f := _pitchfork_fixture("scarecrow_pitchfork_prick_plus", 2, [
		{"max_hp": 40, "hp": 40},
	])
	var before := _pitchfork_snapshot(f)
	_pitchfork_paid(f, "scarecrow_pitchfork_prick_plus", 1, 7)
	_check(f["deck"].energy == 2 and f["deck"].hand.count("scarecrow_pitchfork_prick_plus") == 0
			and f["deck"].discard_pile.count("scarecrow_pitchfork_prick_plus") == 1,
		"one copy costs exactly one energy and moves to discard once")
	_check(before["discard"].is_empty() and before["hand"].count("scarecrow_pitchfork_prick_plus") == 1,
		"the single-copy premise is genuine before the play")
	var after := _pitchfork_snapshot(f)
	_pitchfork_refused(f, "scarecrow_pitchfork_prick_plus", 1, "card_not_held")
	f["deck"].combat_state.energy = 3
	_pitchfork_refused(f, "scarecrow_pitchfork_prick_plus", 1, "card_not_held")
	_check(_pitchfork_snapshot(f)["enemies"] == after["enemies"],
		"replay attempts never touch enemy HP, Block or Bleed again")


## Deterministic replay: the same seed and the same request order produce identical state, and no
## puncture consumes a run RNG draw.
func _test_pitchfork_seeded_replay() -> void:
	var first := _pitchfork_replay(7331)
	var second := _pitchfork_replay(7331)
	_check(not (first["results"] as Array).is_empty(), "seeded replay ran real plays")
	_check(first == second, "seeded replay produces identical final state")
	_check(first["rng"] == second["rng"], "seeded replay consumes no run RNG draws")
	_check((first["results"] as Array).size() == 4
			and first["results"][0].get("ok") == true and first["results"][1].get("ok") == true
			and first["results"][2].get("ok") == true and first["results"][3].get("ok") == false,
		"seeded replay keeps three paid punctures and the final refusal")
	_check(first["results"][3].get("reason") == "insufficient_energy",
		"the spent three-energy turn refuses the fourth puncture")
	_check(first["hp"] == [12, 17, 20], "seeded replay lands the exact punctured HP")
	_check(first["bleed"] == [3, 1, 0], "seeded replay stacks the exact printed Bleed")
	_check(first["energy"] == 0 and first["discard"].size() == 3,
		"seeded replay charges and discards exactly three copies")


func _pitchfork_replay(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array[String] = ["scarecrow_fork_jab", "scarecrow_fork_jab_plus",
		"scarecrow_pitchfork_prick", "scarecrow_pitchfork_prick_plus", PITCHFORK_FILLERS[0]]
	var deck := CombatDeck.new(ids, rng)
	_check(deck.start_turn() and deck.hand.size() == 5 and deck.energy == 3,
		"replay deck starts the real five-draw three-energy turn")
	for card_id: String in PITCHFORK_IDS:
		_check(deck.hand.has(card_id), "replay fixture holds " + card_id)
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "scarecrow", "max_hp": 32},
		{"id": "tinker", "max_hp": 25},
	])
	var enemies := _pitchfork_enemies([
		{"max_hp": 20, "hp": 20, "block": 2},
		{"max_hp": 20, "hp": 20, "block": 2},
		{"max_hp": 20, "hp": 20},
	])
	var service := CombatScarecrowPitchforkCards.new()
	var results: Array = []
	results.append(service.play_card(deck, party, enemies, "scarecrow_fork_jab", 1))
	results.append(service.play_card(deck, party, enemies, "scarecrow_fork_jab_plus", 1))
	results.append(service.play_card(deck, party, enemies, "scarecrow_pitchfork_prick", 2))
	results.append(service.play_card(deck, party, enemies, "scarecrow_pitchfork_prick_plus", 2))
	var snapshot: Dictionary = {"rng": rng.state, "energy": deck.energy,
		"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(), "results": results}
	snapshot["hp"] = [enemies.get_enemy(1)["hp"], enemies.get_enemy(2)["hp"],
		enemies.get_enemy(3)["hp"]]
	snapshot["bleed"] = [int(enemies.get_enemy(1).get("statuses", {}).get("bleed", 0)),
		int(enemies.get_enemy(2).get("statuses", {}).get("bleed", 0)),
		int(enemies.get_enemy(3).get("statuses", {}).get("bleed", 0))]
	return snapshot


## A real seeded five-card hand holding exactly one genuine copy of `card_id`.
func _pitchfork_fixture(card_id: String, seat: int = 2, enemy_specs: Array = [],
		seed_value: int = 4242, neighbour_ids: Array = ["warden", "tinker"]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array[String] = [card_id]
	for filler: String in PITCHFORK_FILLERS:
		ids.append(filler)
	var deck := CombatDeck.new(ids, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
			and deck.hand.size() == 5 and deck.hand.count(card_id) == 1,
		card_id + ": real seeded five-card hand holding exactly one genuine copy")
	var hero_ids: Array[String] = []
	for neighbour: String in neighbour_ids:
		hero_ids.append(str(neighbour))
	hero_ids.insert(seat - 1, "scarecrow")
	var definitions: Array = []
	for hero_id: String in hero_ids:
		definitions.append({"id": hero_id, "max_hp": int(PITCHFORK_MAX_HP[hero_id])})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(seat).get("id") == "scarecrow"
			and party.get_hero(seat).get("position") == seat,
		card_id + ": valid real party with the Scarecrow in seat " + str(seat))
	var specs: Array = enemy_specs
	if specs.is_empty():
		specs = [{"max_hp": 20, "hp": 20},
			{"max_hp": 18, "hp": 14, "block": 2},
			{"max_hp": 14, "hp": 14, "block": 6}]
	var enemies := _pitchfork_enemies(specs)
	return {"deck": deck, "party": party, "enemies": enemies, "rng": rng}


## Real enemy slots: HP loss and Block through the model's own state APIs, then fixture statuses.
func _pitchfork_enemies(specs: Array) -> CombatEnemies:
	var definitions: Array = []
	for index in range(specs.size()):
		definitions.append({"id": "fixture_pitchfork_enemy_" + str(index + 1),
			"max_hp": int(specs[index]["max_hp"])})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == specs.size(),
		"fixture builds a real indexed enemy roster")
	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var lost: int = int(spec["max_hp"]) - int(spec.get("hp", spec["max_hp"]))
		if lost > 0:
			_check(enemies.apply_damage(index + 1, lost),
				"fixture enemy " + str(index + 1) + " really lost HP")
		var block := int(spec.get("block", 0))
		if block > 0:
			_check(enemies.gain_block(index + 1, block),
				"fixture enemy " + str(index + 1) + " really gained Block")
		var statuses: Dictionary = spec.get("statuses", {})
		if statuses.is_empty():
			continue
		var bleed := int(statuses.get("bleed", 0))
		if bleed > 0:
			_check(enemies.apply_statuses({index + 1: {"bleed": bleed}}),
				"fixture enemy " + str(index + 1) + " really gained its Bleed stack")
		for name in statuses:
			if name == "bleed":
				continue
			if not enemies._enemies[index].has("statuses"):
				enemies._enemies[index]["statuses"] = {}
			enemies._enemies[index]["statuses"][name] = statuses[name]
	return enemies


func _pitchfork_snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	return {"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"state_energy": deck.combat_state.energy, "active": deck.turn_active,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"rng": f["rng"].state}


## Independent oracle: one energy, one discarded held copy, Block before HP, then printed Bleed.
func _pitchfork_expected(before: Dictionary, card_id: String, target_position: int,
		damage: int, bleed: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 1
	expected["state_energy"] = int(expected["state_energy"]) - 1
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	var enemy: Dictionary = expected["enemies"][target_position - 1]
	var absorbed: int = mini(int(enemy["block"]), damage)
	enemy["block"] = int(enemy["block"]) - absorbed
	enemy["hp"] = maxi(0, int(enemy["hp"]) - (damage - absorbed))
	var statuses: Dictionary = enemy.get("statuses", {})
	statuses["bleed"] = int(statuses.get("bleed", 0)) + bleed
	enemy["statuses"] = statuses
	return expected


func _pitchfork_paid(f: Dictionary, card_id: String, target_position: int,
		expected_damage: int) -> Dictionary:
	var spec: Dictionary = PITCHFORK_CARDS[card_id]
	var before := _pitchfork_snapshot(f)
	var result := CombatScarecrowPitchforkCards.new().play_card(f["deck"], f["party"],
		f["enemies"], card_id, target_position)
	_check(result.get("ok") == true and result.get("reason") == "applied",
		card_id + ": authorized paid puncture on slot " + str(target_position))
	_check(result.get("card_id") == card_id and result.get("cost") == 1,
		card_id + ": receipt names the authentic card and its one energy")
	_check(result.get("target_position") == target_position,
		card_id + ": receipt reports the selected enemy slot")
	_check(result.get("base_damage") == spec["damage"] and result.get("damage") == expected_damage,
		card_id + ": receipt prints the base and the resolved damage")
	_check(result.get("bleed_applied") == spec["bleed"],
		card_id + ": receipt prints the exact Bleed stack")
	var expected := _pitchfork_expected(before, card_id, target_position, expected_damage,
		spec["bleed"])
	_check(_pitchfork_snapshot(f) == expected,
		card_id + ": exact hand/piles/energy/HP/Block/Bleed/RNG state")
	var enemy_before: Dictionary = before["enemies"][target_position - 1]
	var enemy_after: Dictionary = expected["enemies"][target_position - 1]
	_check(result.get("hp_before") == enemy_before["hp"]
			and result.get("hp_after") == enemy_after["hp"]
			and result.get("hp_loss") == int(enemy_before["hp"]) - int(enemy_after["hp"]),
		card_id + ": receipt proves the exact HP change")
	_check(result.get("block_before") == enemy_before["block"]
			and result.get("block_after") == enemy_after["block"]
			and result.get("block_absorbed") == int(enemy_before["block"]) - int(enemy_after["block"]),
		card_id + ": receipt proves Block absorption before HP")
	_check(result.get("bleed_before") == int(
			(enemy_before.get("statuses", {}) as Dictionary).get("bleed", 0))
			and result.get("bleed_after") == int(
				(enemy_after.get("statuses", {}) as Dictionary).get("bleed", 0)),
		card_id + ": receipt proves the Bleed stack change")
	result["hp_after"] = -999
	result["bleed_after"] = -999
	_check(_pitchfork_snapshot(f) == expected, card_id + ": receipt is detached from state")
	return result


func _pitchfork_refused(f: Dictionary, card_id: Variant, target_position: int,
		reason: String) -> void:
	var before := _pitchfork_snapshot(f)
	var result := CombatScarecrowPitchforkCards.new().play_card(f["deck"], f["party"],
		f["enemies"], card_id, target_position)
	_check(result.get("ok") == false and result.get("reason") == reason,
		str(card_id) + ": refuses " + reason)
	_check(_pitchfork_snapshot(f) == before,
		reason + ": preserves hand, draw, discard, energy, HP, Block, Bleed, turn and RNG")
	result["reason"] = "tampered"
	result["damage"] = 999
	_check(_pitchfork_snapshot(f) == before, reason + ": refusal receipt is detached")


# --- Scarecrow sack-face Fear: Sack Glare and Sack Grin (base and "+") -------------------------
## Authentic printings, stated independently of the resolver. `catalog` is the one authored catalog
## allowed to own each ID (starter for Sack Glare, reward pool for Sack Grin); `weak` is the printed
## stack and `starting_copies` the authored multiplicity.

const FEAR_IDS := [
	"scarecrow_sack_glare", "scarecrow_sack_glare_plus",
	"scarecrow_sack_grin", "scarecrow_sack_grin_plus",
]

const FEAR_CARDS := {
	"scarecrow_sack_glare": {"catalog": "starter", "weak": 1, "starting_copies": 1},
	"scarecrow_sack_glare_plus": {"catalog": "starter", "weak": 2, "starting_copies": 0},
	"scarecrow_sack_grin": {"catalog": "pool", "weak": 1, "starting_copies": 0},
	"scarecrow_sack_grin_plus": {"catalog": "pool", "weak": 2, "starting_copies": 0},
}

## Fixture enemies: slot 1 already carries Weak 1, slot 2 is damaged behind Block with Weak 2 and
## slot 3 is status-free, so a fresh base/plus Fear can be aged on its own.
const FEAR_ENEMY_SPECS := [
	{"max_hp": 20, "hp": 20, "statuses": {"weak": 1}},
	{"max_hp": 18, "hp": 14, "block": 2, "statuses": {"weak": 2}},
	{"max_hp": 14, "hp": 14},
]


## AC1: all four printings are catalog-authenticated from the one catalog that owns each ID, with
## exactly one energy, every seat/position, single-enemy targeting, the printed Weak count and
## Fear as the literal boolean true.
func _test_fear_authentic_records() -> void:
	var starter := ScarecrowStarterCards.new()
	var pool = ScriptClass.new()
	var service := CombatScarecrowFearCards.new()
	for card_id: String in FEAR_IDS:
		var spec: Dictionary = FEAR_CARDS[card_id]
		var owner_catalog: Variant = starter if spec["catalog"] == "starter" else pool
		var other_catalog: Variant = pool if spec["catalog"] == "starter" else starter
		var record: Dictionary = owner_catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " has an authored record")
		_check(record.get("id") == card_id and record.get("owner") == "scarecrow",
			card_id + " is the Scarecrow record for its own ID")
		_check(record.get("cost") == 1, card_id + " prints one energy")
		_check(record.get("target_kind") == "enemy_single", card_id + " frightens one enemy")
		_check(record.get("from_positions") == [1, 2, 3] and record.get("to_positions") == [1, 2, 3],
			card_id + " reaches every enemy slot from every hero seat")
		var effects: Dictionary = record.get("effects", {})
		_check(effects == {"weak": spec["weak"], "cannot_buff_next_turn": true},
			card_id + " prints exactly its Weak count plus the Fear flag")
		_check(effects.get("weak") is int and int(effects["weak"]) == spec["weak"],
			card_id + " states Weak as an integer count")
		_check(effects.get("cannot_buff_next_turn") is bool
				and bool(effects["cannot_buff_next_turn"]),
			card_id + " states Fear as the literal boolean true")
		_check(not other_catalog.has_card(card_id),
			card_id + " is owned by only one Scarecrow catalog")
		_check(record.get("starting_copies") == spec["starting_copies"],
			card_id + " keeps its authored copy count")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
		if spec["catalog"] == "pool":
			_check(record.get("rarity") == "common" and record.get("starting_copies") == 0,
				card_id + " stays a common non-starter reward record")
			_check(record.get("reward_eligible") == not card_id.ends_with("_plus"),
				card_id + " keeps base-only reward eligibility")
		else:
			_check(record.get("reward_eligible") == false, card_id + " stays a non-reward starter")
	_check(starter.get_upgrade_id("scarecrow_sack_glare") == "scarecrow_sack_glare_plus"
		and starter.get_upgrade_id("scarecrow_sack_glare_plus") == "",
		"Sack Glare keeps its one-way starter upgrade link")
	_check(pool.get_upgrade_id("scarecrow_sack_grin") == "scarecrow_sack_grin_plus"
		and pool.get_upgrade_id("scarecrow_sack_grin_plus") == "",
		"Sack Grin keeps its one-way pool upgrade link")
	for unsupported: Variant in ["scarecrow_fork_jab", "scarecrow_fork_jab_plus",
			"scarecrow_pitchfork_prick", "scarecrow_pitchfork_prick_plus",
			"scarecrow_crow_peck", "scarecrow_crow_dive", "scarecrow_crow_flock",
			"scarecrow_harvest_fright", "scarecrow_re_stuff", "scarecrow_straw_padding",
			"scarecrow_straw_wrap", "scarecrow_pitchfork_hook",
			"scarecrow_sack_glare_plus_plus", "scarecrow_sack_grin_plus_plus",
			"sack_glare", "sack_grin", "SCARECROW_SACK_GLARE", " scarecrow_sack_glare",
			"scarecrow_sack_glare ", "", "warden_strike", "seamstress_prick", "tinker_pop_shot"]:
		_check(not service.is_supported_card(unsupported),
			str(unsupported) + ": not a supported sack-face Fear printing")
	_check(not service.is_supported_card(null) and not service.is_supported_card(5)
		and not service.is_supported_card(3.5) and not service.is_supported_card(true)
		and not service.is_supported_card(StringName("scarecrow_sack_glare"))
		and not service.is_supported_card({}) and not service.is_supported_card([]),
		"non-string IDs are never supported")


## AC1: on a genuine three-energy turn each printing pays once and lands its exact printed Weak
## stack plus the literal Fear flag on a living enemy in slot 1-3, from a Scarecrow in seat 1-3.
func _test_fear_paid_plays() -> void:
	for card_id: String in FEAR_IDS:
		var spec: Dictionary = FEAR_CARDS[card_id]
		for seat: int in [1, 2, 3]:
			for target: int in [1, 2, 3]:
				var f := _fear_fixture(card_id, seat)
				var before := _fear_snapshot(f)
				_check(int(before["hand"].count(card_id)) == 1 and int(before["energy"]) == 3,
					card_id + ": fixture really holds one copy at three energy")
				_check(f["party"].get_hero(seat).get("id") == "scarecrow"
						and f["party"].get_hero(seat).get("position") == seat,
					card_id + ": the authoritative Scarecrow is in seat " + str(seat))
				var target_before: Dictionary = before["enemies"][target - 1]
				var weak_before: int = int(
					(target_before.get("statuses", {}) as Dictionary).get("weak", 0))
				var result := _fear_paid(f, card_id, target)
				_check(result.get("owner_position") == seat,
					card_id + ": receipt reports the actual owner seat " + str(seat))
				_check(result.get("weak_before") == weak_before
						and result.get("weak_applied") == spec["weak"]
						and result.get("weak_after") == weak_before + int(spec["weak"]),
					card_id + ": receipt proves the printed Weak added to the existing counter")
				var after: Dictionary = f["enemies"].get_enemy(target)
				var statuses: Dictionary = after.get("statuses", {})
				_check(statuses.get("cannot_buff_next_turn") is bool
						and bool(statuses["cannot_buff_next_turn"]),
					card_id + ": the target carries literal boolean Fear")
				_check(int(statuses.get("weak", 0)) == weak_before + int(spec["weak"]),
					card_id + ": the target's Weak stack is the only status count that moved")
				_check(after["hp"] == int(target_before["hp"])
						and after["block"] == int(target_before["block"]),
					card_id + ": Fear deals no damage and removes no Block")
				_check(f["deck"].energy == 2 and f["deck"].hand.count(card_id) == 0
						and f["deck"].discard_pile == [card_id],
					card_id + ": exactly one copy charged and discarded for one energy")
				_check(f["rng"].state == before["rng"], card_id + ": Fear never advances the seeded run RNG")
				_check(f["deck"].draw_pile == before["draw"], card_id + ": Fear never draws or reshuffles")
				_check(f["party"].get_heroes() == before["heroes"],
					card_id + ": no hero HP, Block, status, seat or identity changed")
				for other: int in [1, 2, 3]:
					if other == target:
						continue
					_check(f["enemies"].get_enemy(other) == before["enemies"][other - 1],
						card_id + ": unselected enemy " + str(other) + " keeps its exact record")


## AC2: after a successful play the real status rules lock the affected enemy's next buff and the
## real owner-turn batch expires that Fear while independently ageing the Weak printed beside it.
func _test_fear_owner_turn_expiry() -> void:
	var rules := CombatStatuses.new()
	# Status-free fixture slots, so the aging of unrelated counters cannot mask a Fear defect.
	var plain_specs: Array = [
		{"max_hp": 20, "hp": 20}, {"max_hp": 18, "hp": 18}, {"max_hp": 14, "hp": 14},
	]
	for card_id: String in FEAR_IDS:
		var spec: Dictionary = FEAR_CARDS[card_id]
		var f := _fear_fixture(card_id, 2, plain_specs)
		_check(f["enemies"].get_enemy(3).get("statuses", {}) == {},
			card_id + ": the selected target really starts status-free")
		var before := _fear_snapshot(f)
		_fear_paid(f, card_id, 3)
		var statuses: Dictionary = f["enemies"].get_enemy(3).get("statuses", {})
		_check(statuses.get("cannot_buff_next_turn") is bool
				and bool(statuses["cannot_buff_next_turn"]),
			card_id + ": canonical literal boolean Fear is stored on the target")
		_check(int(statuses.get("weak", 0)) == int(spec["weak"]),
			card_id + ": the printed Weak is still full at card-play time (no owner-turn tick yet)")
		_check(rules.can_apply_buff(statuses) == {"ok": true, "allowed": false},
			card_id + ": the real status rules lock the target's next buff")
		_check(rules.can_apply_buff({}) == {"ok": true, "allowed": true},
			card_id + ": an unaffected enemy remains free to buff")
		var roster_before: Array[Dictionary] = f["enemies"].get_enemies()
		var tick := CombatStatusTurnBatch.new().tick_side("enemies", f["enemies"].get_enemies())
		_check(tick.get("ok") == true and (tick["actors"] as Array).size() == 3,
			card_id + ": the real owner-turn batch ticks the enemy side")
		_check(f["enemies"].get_enemies() == roster_before,
			card_id + ": asking for the tick never mutates the authoritative roster")
		var ticked: Array = tick["actors"]
		var ticked_statuses: Dictionary = ticked[2]["statuses"]
		_check(not ticked_statuses.has("cannot_buff_next_turn"),
			card_id + ": Fear expires at that enemy's own owner-turn end")
		if int(spec["weak"]) == 1:
			_check(not ticked_statuses.has("weak"),
				card_id + ": base Weak 1 expires at the same boundary, independently of Fear")
		else:
			_check(int(ticked_statuses.get("weak", 0)) == int(spec["weak"]) - 1,
				card_id + ": upgraded Weak 2 becomes Weak 1, independently of Fear")
		_check(rules.can_apply_buff(ticked_statuses) == {"ok": true, "allowed": true},
			card_id + ": the very next owner turn may buff again")
		_check(int(ticked[2]["hp"]) == int(roster_before[2]["hp"]),
			card_id + ": ending that turn loses no HP with no Bleed on the bearer")
		for other: int in [0, 1]:
			_check(ticked[other]["id"] == roster_before[other]["id"]
					and int(ticked[other]["hp"]) == int(roster_before[other]["hp"])
					and int(ticked[other]["block"]) == int(roster_before[other]["block"])
					and (ticked[other].get("statuses", {}) as Dictionary).is_empty(),
				card_id + ": uninvolved enemy " + str(other + 1) + " is unchanged by the tick")
		# A second owner-turn end cannot extend Fear, and the play itself never consumed run RNG.
		var second := CombatStatusTurnBatch.new().tick_side("enemies", tick["actors"])
		_check(second.get("ok") == true
				and not ((second["actors"] as Array)[2]["statuses"] as Dictionary).has(
					"cannot_buff_next_turn"),
			card_id + ": Fear never adds a second, longer lock")
		_check(f["rng"].state == before["rng"],
			card_id + ": consulting the status rules consumes no run RNG")


## AC1/AC3: the detached post-play state must contain only the intended change, proven through the
## shared fixture snapshot, and a fifth play on the same turn is refused without any mutation.
func _test_fear_once_only_payment() -> void:
	var f := _fear_fixture("scarecrow_sack_glare_plus", 2, [{"max_hp": 30, "hp": 30}])
	var before := _fear_snapshot(f)
	_check((before["discard"] as Array).is_empty()
			and int(before["hand"].count("scarecrow_sack_glare_plus")) == 1,
		"the single-copy premise is genuine before the play")
	_fear_paid(f, "scarecrow_sack_glare_plus", 1)
	_check(f["deck"].energy == 2
			and f["deck"].discard_pile.count("scarecrow_sack_glare_plus") == 1,
		"one copy costs exactly one energy and moves to discard once")
	var after := _fear_snapshot(f)
	_fear_refused(f, "scarecrow_sack_glare_plus", 1, "card_not_held")
	f["deck"].combat_state.energy = 3
	_fear_refused(f, "scarecrow_sack_glare_plus", 1, "card_not_held")
	_check(_fear_snapshot(f)["enemies"] == after["enemies"],
		"replay attempts never re-stack Weak or touch the Fear lock")

	# Two genuine held copies can each be paid once on the same turn, and the second play adds its
	# own Weak stack while leaving exactly one canonical Fear flag on the enemy.
	var twin_rng := RandomNumberGenerator.new()
	twin_rng.seed = 6207
	var twin_ids: Array[String] = ["scarecrow_sack_grin", "scarecrow_sack_grin",
		PITCHFORK_FILLERS[0], PITCHFORK_FILLERS[1], PITCHFORK_FILLERS[2]]
	var twin_deck := CombatDeck.new(twin_ids, twin_rng)
	_check(twin_deck.start_turn() and twin_deck.hand.size() == 5
			and twin_deck.hand.count("scarecrow_sack_grin") == 2,
		"the twin-copy fixture really holds two genuine copies at three energy")
	var twin_party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "scarecrow", "max_hp": 34},
		{"id": "tinker", "max_hp": 25},
	])
	var twin_enemies := _fear_enemies([{"max_hp": 20, "hp": 20}])
	var service := CombatScarecrowFearCards.new()
	var first_copy := service.play_card(twin_deck, twin_party, twin_enemies,
		"scarecrow_sack_grin", 1)
	var second_copy := service.play_card(twin_deck, twin_party, twin_enemies,
		"scarecrow_sack_grin", 1)
	_check(first_copy.get("ok") == true and second_copy.get("ok") == true,
		"each of two genuine held copies can be paid once")
	_check(twin_deck.energy == 1
			and twin_deck.hand.count("scarecrow_sack_grin") == 0
			and twin_deck.discard_pile.count("scarecrow_sack_grin") == 2,
		"two plays charge two energy and discard exactly two copies")
	var twin_statuses: Dictionary = twin_enemies.get_enemy(1).get("statuses", {})
	_check(twin_statuses == {"weak": 2, "cannot_buff_next_turn": true},
		"two plays stack Weak twice and leave exactly one literal Fear flag")


## AC3: every invalid request is refused before payment and leaves every authority untouched.
func _test_fear_refusals() -> void:
	var service := CombatScarecrowFearCards.new()

	var f := _fear_fixture("scarecrow_sack_glare", 2)
	var before := _fear_snapshot(f)
	for broken in [null, 5, 3.5, true, [], {},
			StringName("scarecrow_sack_glare"), "", "scarecrow_sack_glare_plus_plus",
			"scarecrow_sack_grin_plus_plus", "SCARECROW_SACK_GLARE",
			" scarecrow_sack_glare", "scarecrow_sack_glare ",
			"scarecrow_crow_flock", "scarecrow_fork_jab", "scarecrow_harvest_fright",
			"warden_strike"]:
		var result := service.play_card(f["deck"], f["party"], f["enemies"], broken, 1)
		_check(result.get("ok") == false and result.get("reason") == "unsupported_card",
			"unsupported card refuses: " + str(broken))
	_check(_fear_snapshot(f) == before, "unsupported cards preserve every authority")

	_check(service.play_card(null, f["party"], f["enemies"], "scarecrow_sack_glare", 1)
			.get("reason") == "invalid_request", "null deck refused")
	_check(service.play_card(f["deck"], null, f["enemies"], "scarecrow_sack_glare", 1)
			.get("reason") == "invalid_request", "null party refused")
	_check(service.play_card(f["deck"], f["party"], null, "scarecrow_sack_glare", 1)
			.get("reason") == "invalid_request", "null enemies refused")
	_check(_fear_snapshot(f) == before, "null authorities preserve every authority")

	var inactive := _fear_fixture("scarecrow_sack_glare", 2)
	_check(inactive["deck"].end_turn(), "inactive fixture really ends the shared turn")
	_fear_refused(inactive, "scarecrow_sack_glare", 1, "inactive_turn")

	var unheld := _fear_fixture("scarecrow_sack_grin_plus", 2)
	_fear_refused(unheld, "scarecrow_sack_grin", 1, "card_not_held")
	_fear_refused(unheld, "scarecrow_sack_glare", 1, "card_not_held")

	var poor := _fear_fixture("scarecrow_sack_grin", 2)
	_check(poor["deck"].try_spend_energy(3) and poor["deck"].energy == 0,
		"insufficient-energy fixture really spent the whole budget")
	_fear_refused(poor, "scarecrow_sack_grin", 1, "insufficient_energy")

	var no_owner := _fear_fixture("scarecrow_sack_glare", 2)
	no_owner["party"] = CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 25},
	])
	_check(no_owner["party"].is_valid()
			and no_owner["party"].get_hero(2).get("id") == "seamstress",
		"missing-owner fixture is a valid living party without a Scarecrow")
	_fear_refused(no_owner, "scarecrow_sack_glare", 1, "owner_missing")

	var torn := _fear_fixture("scarecrow_sack_glare", 1)
	_check(torn["party"].apply_damage(1, 32) and torn["party"].is_downed(1),
		"torn-owner fixture really has zero HP on the Scarecrow")
	_fear_refused(torn, "scarecrow_sack_glare", 1, "owner_downed")

	var duplicate := _fear_fixture("scarecrow_sack_glare", 2)
	duplicate["party"]._heroes[0]["id"] = "scarecrow"
	_check(duplicate["party"].get_hero(1).get("id") == "scarecrow"
			and duplicate["party"].get_hero(2).get("id") == "scarecrow",
		"duplicate-identity fixture really repeats the owner ID")
	_fear_refused(duplicate, "scarecrow_sack_glare", 1, "invalid_party")

	var short_party := _fear_fixture("scarecrow_sack_glare", 2)
	short_party["party"] = CombatParty.new([{"id": "scarecrow", "max_hp": 34},
		{"id": "warden", "max_hp": 40}])
	_check(not short_party["party"].is_valid(), "short-party fixture is really invalid")
	_fear_refused(short_party, "scarecrow_sack_glare", 1, "invalid_party")

	var bad_hp := _fear_fixture("scarecrow_sack_glare", 2)
	bad_hp["party"]._heroes[1]["hp"] = 99
	_fear_refused(bad_hp, "scarecrow_sack_glare", 1, "invalid_party")

	var bad_hero_status := _fear_fixture("scarecrow_sack_glare", 2)
	bad_hero_status["party"]._heroes[0]["statuses"] = {"forged": 1}
	_fear_refused(bad_hero_status, "scarecrow_sack_glare", 1, "malformed_statuses")

	var empty_roster := _fear_fixture("scarecrow_sack_glare", 2)
	empty_roster["enemies"] = CombatEnemies.new([])
	_check(not empty_roster["enemies"].is_valid(), "empty-roster fixture is really invalid")
	_fear_refused(empty_roster, "scarecrow_sack_glare", 1, "invalid_enemies")

	var bad_enemy := _fear_fixture("scarecrow_sack_glare", 2)
	bad_enemy["enemies"]._enemies[1]["hp"] = 99
	_fear_refused(bad_enemy, "scarecrow_sack_glare", 2, "invalid_enemies")

	var bad_slot := _fear_fixture("scarecrow_sack_glare", 2)
	bad_slot["enemies"]._enemies[0]["position"] = 2
	_fear_refused(bad_slot, "scarecrow_sack_glare", 2, "invalid_enemies")

	var target_f := _fear_fixture("scarecrow_sack_glare", 2)
	for bad_target: int in [0, 4, -1]:
		_fear_refused(target_f, "scarecrow_sack_glare", bad_target, "invalid_target")
	var two_slots := _fear_fixture("scarecrow_sack_glare", 2, [
		{"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10},
	])
	_fear_refused(two_slots, "scarecrow_sack_glare", 3, "invalid_target")
	var slain := _fear_fixture("scarecrow_sack_glare", 2, [
		{"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10},
	])
	_check(slain["enemies"].apply_damage(2, 10) and slain["enemies"].is_slain(2),
		"slain-target fixture really killed the selected enemy slot")
	_fear_refused(slain, "scarecrow_sack_glare", 2, "invalid_target")

	# Malformed or unsupported status records on the selected enemy refuse before payment: a
	# lowercase/renamed key, a numeric or false Fear, a negative or fractional counter and an
	# out-of-range one-shot token are all malformed rather than silently inactive.
	var malformed_statuses: Array = [
		{"weak": "2"}, {"weak": -1}, {"weak": 1.5}, {"forged": 1}, {"fear": true},
		{"Fear": true}, {"cannot_buff_next_turn": 1}, {"cannot_buff_next_turn": false},
		{"cannot_buff_next_turn": "true"}, {"cannot_buff_next_turn": 1.0},
		{"dodge_next_attack": 2}, {"blind_next_attack": -1},
		{"cannot_buff_next_turn": true, "poison": 1},
	]
	for bad_statuses: Dictionary in malformed_statuses:
		var malformed := _fear_fixture("scarecrow_sack_glare", 2)
		malformed["enemies"]._enemies[1]["statuses"] = bad_statuses.duplicate(true)
		_fear_refused(malformed, "scarecrow_sack_glare", 2, "malformed_statuses")
	var malformed_roster := _fear_fixture("scarecrow_sack_glare", 2)
	malformed_roster["enemies"]._enemies[0]["statuses"] = {"weak": "1"}
	_fear_refused(malformed_roster, "scarecrow_sack_glare", 2, "malformed_statuses")

	# The Weak addition itself is preflighted: an overflowing counter refuses unpaid, while the
	# exact final legal count is accepted.
	var overflow := _fear_fixture("scarecrow_sack_glare", 2)
	overflow["enemies"]._enemies[1]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	_fear_refused(overflow, "scarecrow_sack_glare", 2, "malformed_statuses")
	var near_overflow := _fear_fixture("scarecrow_sack_glare_plus", 2)
	near_overflow["enemies"]._enemies[1]["statuses"] = {"weak": CombatEnemies.MAX_INT - 1}
	_fear_refused(near_overflow, "scarecrow_sack_glare_plus", 2, "malformed_statuses")
	var exact_overflow := _fear_fixture("scarecrow_sack_glare", 2)
	exact_overflow["enemies"]._enemies[1]["statuses"] = {"weak": CombatEnemies.MAX_INT - 1}
	var exact := CombatScarecrowFearCards.new().play_card(exact_overflow["deck"],
		exact_overflow["party"], exact_overflow["enemies"], "scarecrow_sack_glare", 2)
	_check(exact.get("ok") == true
			and int(exact_overflow["enemies"].get_enemy(2)["statuses"]["weak"])
				== CombatEnemies.MAX_INT,
		"the final legal Weak count is paid, not refused as overflow")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry := _fear_fixture("scarecrow_sack_glare", 2)
	_fear_refused(retry, "scarecrow_sack_glare", 4, "invalid_target")
	_fear_refused(retry, "scarecrow_sack_grin", 1, "card_not_held")
	_fear_paid(retry, "scarecrow_sack_glare", 1)
	_check(retry["deck"].energy == 2 and retry["deck"].discard_pile == ["scarecrow_sack_glare"],
		"retry: the authentic play then charges and discards exactly once")

	# A forged catalog record (a rewritten magnitude, a numeric Fear, an extra effect, the wrong
	# owner, a free cost, narrowed seating or a broken upgrade link) is never paid for under the
	# real ID: the service authenticates the authored record instead of trusting the lookup.
	var probe := ForgedFearCards.new()
	_check(probe.is_supported_card("scarecrow_sack_glare")
			and probe.is_supported_card("scarecrow_sack_grin_plus"),
		"the forged-catalog probe itself authenticates an unmutated record")
	for mutation: String in ["weak", "fear_int", "extra", "owner", "cost", "seats", "unlink"]:
		var forged_service := ForgedFearCards.new()
		forged_service.mutation = mutation
		var forged := _fear_fixture("scarecrow_sack_glare", 2)
		var forged_before := _fear_snapshot(forged)
		_check(not forged_service.is_supported_card("scarecrow_sack_glare"),
			"forged catalog record is not supported: " + mutation)
		var forged_result := forged_service.play_card(forged["deck"], forged["party"],
			forged["enemies"], "scarecrow_sack_glare", 1)
		_check(forged_result.get("ok") == false
				and forged_result.get("reason") == "catalog_mismatch",
			"forged catalog record refuses catalog_mismatch: " + mutation)
		_check(_fear_snapshot(forged) == forged_before,
			"forged catalog record mutates nothing: " + mutation)


## Deterministic replay: the same seed and the same request order produce identical state, the
## three-energy turn pays exactly three Fear printings and the fourth is refused, and no play
## consumes a run RNG draw.
func _test_fear_seeded_replay() -> void:
	var first := _fear_replay(90210)
	var second := _fear_replay(90210)
	_check(not (first["results"] as Array).is_empty(), "seeded Fear replay ran real plays")
	_check(first == second, "seeded Fear replay produces identical final state")
	_check(first["rng"] == second["rng"], "seeded Fear replay consumes no run RNG draws")
	_check((first["results"] as Array).size() == 4
			and first["results"][0].get("ok") == true and first["results"][1].get("ok") == true
			and first["results"][2].get("ok") == true
			and first["results"][3].get("ok") == false,
		"seeded Fear replay keeps three paid Fear plays and the final refusal")
	_check(first["results"][3].get("reason") == "insufficient_energy",
		"the spent three-energy turn refuses the fourth Fear play")
	_check(first["weak"] == [1, 2, 1] and first["fear"] == [true, true, true],
		"seeded Fear replay stacks the exact printed Weak and locks each selected enemy")
	_check(first["hp"] == [20, 18, 14] and first["energy"] == 0
			and (first["discard"] as Array).size() == 3,
		"seeded Fear replay deals no damage and charges and discards exactly three copies")


func _fear_replay(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array[String] = ["scarecrow_sack_glare", "scarecrow_sack_glare_plus",
		"scarecrow_sack_grin", "scarecrow_sack_grin_plus", PITCHFORK_FILLERS[1]]
	var deck := CombatDeck.new(ids, rng)
	_check(deck.start_turn() and deck.hand.size() == 5 and deck.energy == 3,
		"replay deck starts the real five-draw three-energy turn")
	for card_id: String in FEAR_IDS:
		_check(deck.hand.has(card_id), "replay fixture holds " + card_id)
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "scarecrow", "max_hp": 34},
		{"id": "tinker", "max_hp": 25},
	])
	var enemies := _fear_enemies([
		{"max_hp": 20, "hp": 20},
		{"max_hp": 18, "hp": 18},
		{"max_hp": 14, "hp": 14},
	])
	var service := CombatScarecrowFearCards.new()
	var results: Array = []
	results.append(service.play_card(deck, party, enemies, "scarecrow_sack_glare", 1))
	results.append(service.play_card(deck, party, enemies, "scarecrow_sack_glare_plus", 2))
	results.append(service.play_card(deck, party, enemies, "scarecrow_sack_grin", 3))
	results.append(service.play_card(deck, party, enemies, "scarecrow_sack_grin_plus", 1))
	var snapshot: Dictionary = {"rng": rng.state, "energy": deck.energy,
		"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(), "results": results}
	snapshot["hp"] = [enemies.get_enemy(1)["hp"], enemies.get_enemy(2)["hp"],
		enemies.get_enemy(3)["hp"]]
	snapshot["weak"] = [int(enemies.get_enemy(1).get("statuses", {}).get("weak", 0)),
		int(enemies.get_enemy(2).get("statuses", {}).get("weak", 0)),
		int(enemies.get_enemy(3).get("statuses", {}).get("weak", 0))]
	snapshot["fear"] = [enemies.get_enemy(1).get("statuses", {}).get("cannot_buff_next_turn") == true,
		enemies.get_enemy(2).get("statuses", {}).get("cannot_buff_next_turn") == true,
		enemies.get_enemy(3).get("statuses", {}).get("cannot_buff_next_turn") == true]
	return snapshot


## A real seeded five-card hand holding exactly one genuine copy of `card_id`, with the Scarecrow
## seated where the test asks and a real enemy roster.
func _fear_fixture(card_id: String, seat: int = 2, enemy_specs: Array = [],
		seed_value: int = 5150, neighbour_ids: Array = ["warden", "tinker"]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array[String] = [card_id]
	for filler: String in PITCHFORK_FILLERS:
		ids.append(filler)
	var deck := CombatDeck.new(ids, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
			and deck.hand.size() == 5 and deck.hand.count(card_id) == 1,
		card_id + ": real seeded five-card hand holding exactly one genuine copy")
	var hero_ids: Array[String] = []
	for neighbour: String in neighbour_ids:
		hero_ids.append(str(neighbour))
	hero_ids.insert(seat - 1, "scarecrow")
	var definitions: Array = []
	for hero_id: String in hero_ids:
		definitions.append({"id": hero_id, "max_hp": int(PITCHFORK_MAX_HP[hero_id])})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(seat).get("id") == "scarecrow"
			and party.get_hero(seat).get("position") == seat,
		card_id + ": valid real party with the Scarecrow in seat " + str(seat))
	var specs: Array = enemy_specs
	if specs.is_empty():
		specs = FEAR_ENEMY_SPECS
	return {"deck": deck, "party": party, "enemies": _fear_enemies(specs), "rng": rng}


## Real enemy slots: HP loss and Block through the model's own state APIs, integer status stacks
## through apply_statuses, and only the non-integer markers (Fear, Dodge, Blind) written directly.
func _fear_enemies(specs: Array) -> CombatEnemies:
	var definitions: Array = []
	for index in range(specs.size()):
		definitions.append({"id": "fixture_fear_enemy_" + str(index + 1),
			"max_hp": int(specs[index]["max_hp"])})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == specs.size(),
		"fixture builds a real indexed enemy roster")
	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var lost: int = int(spec["max_hp"]) - int(spec.get("hp", spec["max_hp"]))
		if lost > 0:
			_check(enemies.apply_damage(index + 1, lost),
				"fixture enemy " + str(index + 1) + " really lost HP")
		var block := int(spec.get("block", 0))
		if block > 0:
			_check(enemies.gain_block(index + 1, block),
				"fixture enemy " + str(index + 1) + " really gained Block")
		var statuses: Dictionary = spec.get("statuses", {})
		if statuses.is_empty():
			continue
		var stacks: Dictionary = {}
		for name in statuses:
			if typeof(statuses[name]) == TYPE_INT:
				stacks[name] = statuses[name]
		if not stacks.is_empty():
			_check(enemies.apply_statuses({index + 1: stacks}),
				"fixture enemy " + str(index + 1) + " really gained its status stacks")
		for name in statuses:
			if typeof(statuses[name]) == TYPE_INT:
				continue
			if not enemies._enemies[index].has("statuses"):
				enemies._enemies[index]["statuses"] = {}
			enemies._enemies[index]["statuses"][name] = statuses[name]
	return enemies


## The full authoritative state used by the Fear suites, in the same shape as the pitchfork
## snapshot: hand, both piles, energy, turn, heroes, the complete enemy roster and the run RNG.
func _fear_snapshot(f: Dictionary) -> Dictionary:
	return _pitchfork_snapshot(f)


## Independent oracle: one energy, one discarded held copy, the printed Weak added to the existing
## counter and literal boolean Fear stamped on that one enemy; every other field is untouched.
func _fear_expected(before: Dictionary, card_id: String, target_position: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 1
	expected["state_energy"] = int(expected["state_energy"]) - 1
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	var enemy: Dictionary = expected["enemies"][target_position - 1]
	var statuses: Dictionary = enemy.get("statuses", {})
	statuses["weak"] = int(statuses.get("weak", 0)) + int(FEAR_CARDS[card_id]["weak"])
	statuses["cannot_buff_next_turn"] = true
	enemy["statuses"] = statuses
	return expected


func _fear_paid(f: Dictionary, card_id: String, target_position: int) -> Dictionary:
	var before := _fear_snapshot(f)
	var result := CombatScarecrowFearCards.new().play_card(f["deck"], f["party"],
		f["enemies"], card_id, target_position)
	_check(result.get("ok") == true and result.get("reason") == "applied",
		card_id + ": authorized paid Fear play on slot " + str(target_position))
	_check(result.get("card_id") == card_id and result.get("cost") == 1,
		card_id + ": receipt names the authentic card and its one energy")
	_check(result.get("target_position") == target_position,
		card_id + ": receipt reports the selected enemy slot")
	_check(result.get("fear_applied") == true and result.get("cannot_buff_next_turn") == true,
		card_id + ": receipt reports the applied one-turn Fear lock")
	_check(result.get("energy_before") == int(before["energy"])
			and result.get("energy_after") == int(before["energy"]) - 1,
		card_id + ": receipt proves exactly one energy spent")
	var expected := _fear_expected(before, card_id, target_position)
	_check(_fear_snapshot(f) == expected,
		card_id + ": exact hand/piles/energy/party/enemy-status/RNG state")
	var receipt: Dictionary = result.duplicate(true)
	result["weak_after"] = -999
	result["fear_applied"] = false
	_check(_fear_snapshot(f) == expected, card_id + ": receipt is detached from state")
	return receipt


func _fear_refused(f: Dictionary, card_id: Variant, target_position: int,
		reason: String) -> void:
	var before := _fear_snapshot(f)
	var result := CombatScarecrowFearCards.new().play_card(f["deck"], f["party"],
		f["enemies"], card_id, target_position)
	_check(result.get("ok") == false and result.get("reason") == reason,
		str(card_id) + ": refuses " + reason)
	_check(_fear_snapshot(f) == before,
		reason + ": preserves hand, draw, discard, energy, party, enemies, turn and RNG")
	result["reason"] = "tampered"
	result["weak_applied"] = 999
	_check(_fear_snapshot(f) == before, reason + ": refusal receipt is detached")


## A resolver whose catalog lookup serves one rewritten record, so a forged magnitude, a numeric
## Fear, an extra effect, the wrong owner, a free cost, narrowed seating or a broken upgrade link
## can be proven inert before any energy, hand or status state moves.
class ForgedFearCards extends CombatScarecrowFearCards:
	var mutation: String = ""

	func _catalog_definition(card_id: String, catalog: String) -> Dictionary:
		var record: Dictionary = super._catalog_definition(card_id, catalog)
		if record.is_empty() or not record.get("effects") is Dictionary:
			return record
		var effects: Dictionary = record["effects"]
		match mutation:
			"weak":
				effects["weak"] = 9
			"fear_int":
				effects["cannot_buff_next_turn"] = 1
			"extra":
				effects["damage"] = 3
			"owner":
				record["owner"] = "warden"
			"cost":
				record["cost"] = 0
			"seats":
				record["from_positions"] = [1]
			"unlink":
				if record.has("upgrade_id"):
					record["upgrade_id"] = "scarecrow_sack_glare_plus_plus"
				else:
					record["upgrade_of"] = "scarecrow_sack_glare_plus"
		return record


# --- Scarecrow Straw Wrap and Straw Wrap+ paid ally Block-and-draw ---------------
const STRAW_WRAP_IDS := ["scarecrow_straw_wrap", "scarecrow_straw_wrap_plus"]
const STRAW_WRAP_BLOCKS := {
	"scarecrow_straw_wrap": 6,
	"scarecrow_straw_wrap_plus": 8,
}


func _straw_wrap_fixture(card_id: String, seat: int = 2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var cards: Array[String] = [card_id, "warden_strike", "warden_brace",
		"tinker_pop_shot", "tinker_tune_up"]
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn(), "straw fixture starts genuine shared turn")
	# Supply cards in discard so draw_extra has something to draw.
	for filler: String in ["filler_bobbin", "filler_thread", "filler_twig",
		"filler_scrap", "filler_paper"]:
		deck.discard_pile.append(filler)
	_check(deck.energy == 3 and deck.hand.size() == 5 and deck.hand.count(card_id) == 1,
		"fixture genuinely holds sole requested straw card at three energy")
	var heroes: Array = [{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "scarecrow", "max_hp": 34,
		"statuses": {"weak": 1}, "metadata": {"seams": ["straw", "felt"]}})
	var party := CombatParty.new(heroes)
	_check(party.is_valid() and party.get_hero(seat).get("id") == "scarecrow",
		"fixture has three distinct heroes and Scarecrow in requested seat")
	return {"deck": deck, "party": party, "rng": rng, "seat": seat}


func _straw_wrap_snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var party: CombatParty = f["party"]
	return {"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"active": deck.turn_active, "heroes": party.get_heroes(), "rng": f["rng"].state}


func _straw_wrap_refused(f: Dictionary, card_id: Variant, reason: String,
		target: int = 0) -> void:
	var before := _straw_wrap_snapshot(f)
	var result := CombatScarecrowStrawWrapCards.new().play_card(
		f["deck"], f["party"], card_id, target)
	_check(not result.get("ok", true) and result.get("reason") == reason,
		"Straw Wrap refuses " + reason)
	_check(_straw_wrap_snapshot(f) == before,
		reason + " preserves all authorities and RNG")
	result["drawn"] = -999
	_check(_straw_wrap_snapshot(f) == before,
		reason + " receipt is detached")


func _straw_wrap_paid(f: Dictionary, card_id: String, target: int) -> Dictionary:
	var before := _straw_wrap_snapshot(f)
	var result := CombatScarecrowStrawWrapCards.new().play_card(
		f["deck"], f["party"], card_id, target)
	_check(result.get("ok", false), card_id + ": authorized paid straw play to "
		+ str(target) + " from seat " + str(f["seat"]))
	_check(result.get("card_id") == card_id, card_id + ": receipt names card")
	_check(result.get("cost") == 1, card_id + ": receipt shows cost 1")
	_check(result.get("owner_position") == f["seat"], card_id + ": receipt shows owner seat")
	_check(result.get("target_position") == target,
		card_id + ": receipt shows target seat")
	var expected_block: int = STRAW_WRAP_BLOCKS[card_id]
	_check(result.get("block_gained") == expected_block,
		card_id + ": receipt shows printed block " + str(expected_block))
	_check(f["party"].get_hero(target)["block"] == before["heroes"][target - 1]["block"]
		+ expected_block,
		card_id + ": target gains exactly printed block")
	for other in [1, 2, 3]:
		if other != target:
			_check(f["party"].get_hero(other)["block"] == before["heroes"][other - 1]["block"],
				card_id + ": non-target hero " + str(other) + " keeps block")
	_check(f["deck"].energy == 2,
		card_id + ": exactly one energy spent")
	_check(f["deck"].hand.count(card_id) == 0,
		card_id + ": held copy removed from hand")
	_check(f["deck"].discard_pile.count(card_id) == 1,
		card_id + ": exactly one copy discarded")
	return result


func _test_straw_wrap_authentic_records() -> void:
	var pool := ScriptClass.new()
	var service := CombatScarecrowStrawWrapCards.new()
	for id: String in STRAW_WRAP_IDS:
		var spec_block: int = STRAW_WRAP_BLOCKS[id]
		_check(service.is_supported_card(id), id + ": service authenticates")
		var record := pool.get_definition(id)
		_check(not record.is_empty(), id + ": pool record exists")
		_check(record.get("id") == id and record.get("owner") == "scarecrow",
			id + ": owned by scarecrow")
		_check(record.get("cost") == 1, id + ": cost 1")
		_check(record.get("from_positions") == [1, 2, 3], id + ": any seat")
		_check(record.get("target_kind") == "ally_single", id + ": ally target")
		_check(record.get("to_positions") == [], id + ": empty TO")
		_check(record.get("effects") == {"block": spec_block, "draw": 1},
			id + ": effects match")
		_check(record.get("reward_eligible") == (not id.ends_with("_plus")),
			id + ": reward eligibility correct")


func _test_straw_wrap_paid_plays() -> void:
	for id: String in STRAW_WRAP_IDS:
		for seat: int in [1, 2, 3]:
			for target: int in [1, 2, 3]:
				var f := _straw_wrap_fixture(id, seat)
				var result := _straw_wrap_paid(f, id, target)
				_check(result.get("drawn") == 1,
					id + ": exactly one card drawn when supply available")


func _test_straw_wrap_draw_exhausted() -> void:
	# AC2: zero supply still resolves with drawn == 0.
	var empty_f := _straw_wrap_fixture("scarecrow_straw_wrap", 1)
	# Empty the draw and discard piles to have nothing drawable.
	empty_f["deck"].draw_pile.clear()
	empty_f["deck"].discard_pile.clear()
	var result := CombatScarecrowStrawWrapCards.new().play_card(
		empty_f["deck"], empty_f["party"], "scarecrow_straw_wrap", 2)
	_check(result.get("ok", false), "exhausted supply: play succeeds")
	_check(result.get("drawn") == 0, "exhausted supply: drawn is 0")
	_check(empty_f["deck"].energy == 2, "exhausted supply: energy spent")
	_check(empty_f["deck"].discard_pile == ["scarecrow_straw_wrap"],
		"exhausted supply: card discarded")


func _test_straw_wrap_reshuffle_order() -> void:
	# AC2: draw first, then discard. A reshuffle cannot redraw the played card.
	var f := _straw_wrap_fixture("scarecrow_straw_wrap_plus", 2)
	# Manually discard a different card into discard pile so reshuffle has something.
	f["deck"].discard_pile.append("straw_other")
	var before := _straw_wrap_snapshot(f)
	var result := _straw_wrap_paid(f, "scarecrow_straw_wrap_plus", 1)
	_check(result.get("drawn") == 1, "reshuffle: one card drawn")
	# More directly: the played card must not be in the new hand (since it was discarded after draw).
	_check(not f["deck"].hand.has("scarecrow_straw_wrap_plus"),
		"reshuffle: played card is not back in hand")


func _test_straw_wrap_refusals() -> void:
	var service := CombatScarecrowStrawWrapCards.new()

	var f := _straw_wrap_fixture("scarecrow_straw_wrap", 2)
	var before := _straw_wrap_snapshot(f)

	# No held card
	_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", "card_not_held", 1)

	# Unsupported / forged IDs
	for broken in [null, 5, 3.5, true, [], {},
		StringName("scarecrow_straw_wrap"), "missing", "warden_strike",
		"scarecrow_straw_wrap_plus_plus", "SCARECROW_STRAW_WRAP",
		" scarecrow_straw_wrap"]:
		_straw_wrap_refused(f, broken, "unsupported_card", 1)

	# Inactive turn
	var inactive := _straw_wrap_fixture("scarecrow_straw_wrap", 2)
	_check(inactive["deck"].end_turn() and not inactive["deck"].turn_active,
		"inactive fixture really ends turn")
	_straw_wrap_refused(inactive, "scarecrow_straw_wrap", "inactive_turn", 1)

	# Insufficient energy
	var poor := _straw_wrap_fixture("scarecrow_straw_wrap", 2)
	_check(poor["deck"].try_spend_energy(3) and poor["deck"].energy == 0,
		"poor fixture really spent all energy")
	_straw_wrap_refused(poor, "scarecrow_straw_wrap", "insufficient_energy", 1)

	# Missing owner
	var no_owner := _straw_wrap_fixture("scarecrow_straw_wrap", 2)
	no_owner["party"] = CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 25},
		{"id": "seamstress", "max_hp": 30}])
	_check(no_owner["party"].is_valid() and no_owner["party"].get_hero(3)["id"] == "seamstress",
		"missing-owner fixture is valid living without Scarecrow")
	_straw_wrap_refused(no_owner, "scarecrow_straw_wrap", "owner_missing", 1)

	# Downed owner
	var torn := _straw_wrap_fixture("scarecrow_straw_wrap", 1)
	_check(torn["party"].apply_damage(1, 34) and torn["party"].is_downed(1),
		"downed-owner fixture really has zero HP on Scarecrow")
	_straw_wrap_refused(torn, "scarecrow_straw_wrap", "owner_downed", 1)

	# Downed target
	var target_down := _straw_wrap_fixture("scarecrow_straw_wrap", 2)
	_check(target_down["party"].apply_damage(1, 40) and target_down["party"].is_downed(1),
		"downed-target fixture really killed Warden in seat 1")
	_straw_wrap_refused(target_down, "scarecrow_straw_wrap", "target_downed", 1)

	# Invalid target seat
	for bad_target: int in [0, 4, -1]:
		_straw_wrap_refused(f, "scarecrow_straw_wrap", "invalid_target", bad_target)


func _test_straw_wrap_catalog_preserved() -> void:
	# Check the unchanged catalog still has both named cards and their upgrade links.
	var catalog := ScriptClass.new()
	_check(catalog.has_card("scarecrow_straw_wrap"),
		"catalog preserves straw_wrap base")
	_check(catalog.has_card("scarecrow_straw_wrap_plus"),
		"catalog preserves straw_wrap_plus")
	_check(catalog.get_upgrade_id("scarecrow_straw_wrap") == "scarecrow_straw_wrap_plus",
		"base upgrade link preserved")
	_check(catalog.get_upgrade_id("scarecrow_straw_wrap_plus") == "",
		"plus has no further upgrade")


func _test_straw_wrap_once_only_payment() -> void:
	var f := _straw_wrap_fixture("scarecrow_straw_wrap_plus", 2)
	var before := _straw_wrap_snapshot(f)
	var result := _straw_wrap_paid(f, "scarecrow_straw_wrap_plus", 3)
	_check(f["deck"].energy == 2 and f["deck"].hand.count("scarecrow_straw_wrap_plus") == 0
			and f["deck"].discard_pile == ["scarecrow_straw_wrap_plus"],
		"one play costs exactly one energy and moves to discard once")
	# Replay refused
	var after := _straw_wrap_snapshot(f)
	_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", "card_not_held", 2)
	_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", "card_not_held", 3)
	_check(_straw_wrap_snapshot(f) == after, "replay attempts never touch state")


func _test_straw_wrap_seeded_replay() -> void:
	var first := _straw_wrap_replay(7333)
	var second := _straw_wrap_replay(7333)
	_check(first == second, "seeded replay produces identical final state")
	_check(first["rng"] == second["rng"], "seeded replay consumes no run RNG")
	_check((first["results"] as Array).size() == 2
			and first["results"][0].get("ok") == true
			and first["results"][1].get("ok") == false,
		"seeded replay keeps one paid straw and one refusal")
	_check(first["results"][1].get("reason") == "card_not_held",
		"final refusal is specifically missing held copy")


func _straw_wrap_replay(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array[String] = ["scarecrow_straw_wrap",
		"warden_strike", "warden_brace", "tinker_pop_shot", "tinker_tune_up"]
	var deck := CombatDeck.new(ids, rng)
	_check(deck.start_turn() and deck.hand.size() == 5, "replay deck starts real turn")
	for filler: String in ["filler_bobbin", "filler_thread", "filler_twig",
		"filler_scrap", "filler_paper"]:
		deck.discard_pile.append(filler)
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "scarecrow", "max_hp": 34},
		{"id": "tinker", "max_hp": 25},
	])
	var service := CombatScarecrowStrawWrapCards.new()
	var results: Array = []
	results.append(service.play_card(deck, party, "scarecrow_straw_wrap", 2))
	results.append(service.play_card(deck, party, "scarecrow_straw_wrap_plus", 2))
	return {"rng": rng.state, "energy": deck.energy,
		"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "heroes": party.get_heroes(),
		"results": results}


# --- Scarecrow Pitchfork Hook: paid strike plus one-slot forward pull -------------------------
## Authentic printings, stated independently of the resolver: both are uncommon Scarecrow reward
## pool cards with two energy, hero seats 1-2, a single enemy target in slot 2-3, one forward pull
## and damage 7 (base) / 10 (+). The complete expected records are compared field by field below.

const HOOK_IDS := ["scarecrow_pitchfork_hook", "scarecrow_pitchfork_hook_plus"]

const HOOK_CARDS := {
	"scarecrow_pitchfork_hook": {
		"cost": 2, "damage": 7,
		"record": {
			"id": "scarecrow_pitchfork_hook",
			"display_name": "Pitchfork Hook",
			"owner": "scarecrow",
			"cost": 2,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [2, 3],
			"effects": {"damage": 7, "pull_forward": 1},
			"illustration_path": "res://assets/paper/cards/scarecrow_pitchfork_hook.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "scarecrow_pitchfork_hook_plus",
		},
	},
	"scarecrow_pitchfork_hook_plus": {
		"cost": 2, "damage": 10,
		"record": {
			"id": "scarecrow_pitchfork_hook_plus",
			"display_name": "Pitchfork Hook+",
			"owner": "scarecrow",
			"cost": 2,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [2, 3],
			"effects": {"damage": 10, "pull_forward": 1},
			"illustration_path": "res://assets/paper/cards/scarecrow_pitchfork_hook.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "scarecrow_pitchfork_hook",
		},
	},
}


## AC1: both Hook printings are authenticated from the Scarecrow reward pool with their exact
## complete records, reciprocal one-way links and only the two IDs accepted. The other seven
## authored reward bases and named foreign starters remain intact (named presence only: no catalog
## total, full ordered list or ordinal assumption).
func _test_hook_authentic_records() -> void:
	var pool = ScriptClass.new()
	var service := CombatScarecrowPitchforkHookCards.new()
	for card_id: String in HOOK_IDS:
		var spec: Dictionary = HOOK_CARDS[card_id]
		var record: Dictionary = pool.get_definition(card_id)
		_check(not record.is_empty(), card_id + " has an authored Scarecrow pool record")
		_check(record == spec["record"], card_id + " is the exact complete authored record")
		for field: String in spec["record"]:
			_check(record.get(field) == spec["record"][field],
				card_id + " keeps the authored " + field)
		_check(record.size() == (spec["record"] as Dictionary).size(),
			card_id + " carries exactly the authored field set")
		_check(record.get("owner") == "scarecrow", card_id + " is Scarecrow-owned")
		_check(record.get("cost") == 2, card_id + " prints two energy")
		_check(record.get("from_positions") == [1, 2], card_id + " is played from hero seat 1-2")
		_check(record.get("target_kind") == "enemy_single", card_id + " hooks one enemy")
		_check(record.get("to_positions") == [2, 3], card_id + " reaches enemy slot 2-3 only")
		_check(record.get("effects") == {"damage": spec["damage"], "pull_forward": 1},
			card_id + " prints exactly its damage plus one forward pull")
		_check(record.get("starting_copies") == 0, card_id + " is never a starter copy")
		_check(record.get("rarity") == "uncommon", card_id + " stays uncommon")
		_check(record.get("reward_eligible") == (card_id == "scarecrow_pitchfork_hook"),
			card_id + " keeps base-only reward eligibility")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
		_check(CombatScarecrowPitchforkHookCards.is_authentic_definition(record, card_id),
			card_id + ": the authored record passes exact authentication")
		_check(CombatScarecrowPitchforkHookCards.hook_definition(card_id) == record,
			card_id + ": resolves to its exact detached pool record")
	_check(pool.get_upgrade_id("scarecrow_pitchfork_hook") == "scarecrow_pitchfork_hook_plus"
		and pool.get_upgrade_id("scarecrow_pitchfork_hook_plus") == "",
		"Pitchfork Hook keeps its one-way pool upgrade link")
	# Detached: a mutated resolution cannot poison the next one.
	var sample: Dictionary = CombatScarecrowPitchforkHookCards.hook_definition(
		"scarecrow_pitchfork_hook")
	_check(not sample.is_empty(), "hook resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["damage"] = 99
		sample["effects"]["pull_forward"] = 3
		sample["cost"] = 0
		sample["from_positions"].clear()
		_check(CombatScarecrowPitchforkHookCards.hook_definition("scarecrow_pitchfork_hook")
			== pool.get_definition("scarecrow_pitchfork_hook"),
			"a mutated resolution cannot rewrite the next one")
	# Every other Scarecrow pool printing, every foreign card and every forged spelling is refused.
	for other: Variant in ["scarecrow_pitchfork_prick", "scarecrow_pitchfork_prick_plus",
			"scarecrow_crow_peck", "scarecrow_crow_peck_plus", "scarecrow_sack_grin",
			"scarecrow_sack_grin_plus", "scarecrow_straw_wrap", "scarecrow_straw_wrap_plus",
			"scarecrow_crow_flock", "scarecrow_crow_flock_plus", "scarecrow_re_stuff",
			"scarecrow_re_stuff_plus", "scarecrow_harvest_fright",
			"scarecrow_harvest_fright_plus", "warden_strike", "seamstress_prick",
			"tinker_pop_shot", "scarecrow_pitchfork_hook+", "scarecrow_pitchfork_hook_plus_plus",
			"pitchfork_hook", " scarecrow_pitchfork_hook", "SCARECROW_PITCHFORK_HOOK", "",
			StringName("scarecrow_pitchfork_hook"), null, 0, 3.5, false, [], {}]:
		_check(not service.is_supported_card(other), str(other) + ": not a supported Hook printing")
		_check(CombatScarecrowPitchforkHookCards.hook_definition(other).is_empty(),
			str(other) + ": resolves no Hook definition")
	# The eight authored Scarecrow reward bases and their "+" partners remain unchanged.
	var cases: Dictionary = _cases()
	for base_id: String in cases:
		var expected: Dictionary = _expected_record(base_id, cases[base_id], false)
		_check(pool.has_card(base_id), base_id + " remains an authored Scarecrow reward base")
		_check(pool.get_definition(base_id) == expected, base_id + " record is unchanged")
		_check(pool.has_card(base_id + "_plus"), base_id + "_plus remains authored")
		_check(pool.get_upgrade_id(base_id) == base_id + "_plus",
			base_id + " keeps its one-way upgrade link")
	# Named foreign starters are still intact.
	var starter := StarterCards.new()
	for foreign_id: String in ["warden_strike", "warden_brace", "seamstress_prick",
			"seamstress_mend", "tinker_pop_shot", "tinker_tune_up"]:
		_check(not starter.get_definition(foreign_id).is_empty(),
			foreign_id + " remains another hero's authored starter")


## AC2: each printing is genuinely held in a real active shared deck, pays exactly two energy and
## one held copy, lands its printed 7/10 through Block-before-HP on the detached target and
## proposes moving that same surviving identity one slot forward. The untouched companion and the
## fourth bystander keep every field; the party, input snapshot and seeded RNG stay unchanged.
func _test_hook_paid_strikes() -> void:
	var cases := 0
	for card_id: String in HOOK_IDS:
		var spec: Dictionary = HOOK_CARDS[card_id]
		for seat: int in [1, 2]:
			for target: int in [2, 3]:
				cases += 1
				var slots: Dictionary = _hook_slots(target)
				var f := _hook_fixture(card_id, seat, 424242 + seat * 10 + target)
				var before := _hook_state(f, slots)
				_check(f["party"].get_hero(seat).get("id") == "scarecrow"
					and f["party"].get_hero(seat).get("position") == seat,
					card_id + ": the authoritative Scarecrow really sits in seat " + str(seat))
				_check(f["deck"].hand.count(card_id) == 1 and f["deck"].energy == 3,
					card_id + ": the real seeded hand really holds one copy at three energy")
				var source: Dictionary = slots[target].duplicate(true)
				var companion_slot: int = 3 if target == 2 else 1
				var companion: Dictionary = slots[companion_slot].duplicate(true)
				var bystander: Dictionary = slots[4].duplicate(true)
				var result := CombatScarecrowPitchforkHookCards.new().play_held_hook(
					f["deck"], f["party"], card_id, target, slots)
				_check(result.get("ok") == true and result.get("reason") == "applied",
					card_id + ": paid Hook from seat " + str(seat) + " onto slot " + str(target))
				_check(result.get("card_id") == card_id and result.get("cost") == 2
					and result.get("energy_spent") == 2,
					card_id + ": receipt names the authentic card and its two energy")
				_check(result.get("owner_position") == seat
					and result.get("source_position") == target
					and result.get("target_position") == target
					and result.get("destination_position") == target - 1,
					card_id + ": receipt names owner, source and one-slot-forward destination")
				_check(result.get("base_damage") == spec["damage"]
					and result.get("damage") == spec["damage"],
					card_id + ": receipt prints base " + str(spec["damage"]) + " and no multiplier")
				var expected_hp: int = int(source["hp"]) - int(spec["damage"])
				_check(result.get("hp_before") == source["hp"]
					and result.get("hp_after") == expected_hp
					and result.get("hp_loss") == int(spec["damage"]),
					card_id + ": receipt proves the exact printed HP loss")
				_check(result.get("block_before") == source["block"]
					and result.get("block_after") == source["block"]
					and result.get("block_absorbed") == 0,
					card_id + ": a Block-free target absorbs nothing")
				_check(result.get("moved") == true and result.get("slain") == false,
					card_id + ": the surviving foe is pulled forward")
				var proposed: Dictionary = result.get("slots", {})
				var keys: Array = proposed.keys()
				keys.sort()
				_check(keys == [1, 2, 3, 4], card_id + ": publishes exactly the four Hook slots")
				var expected_moved: Dictionary = source.duplicate(true)
				expected_moved["hp"] = expected_hp
				expected_moved["position"] = target - 1
				_check(proposed.get(target - 1) == expected_moved,
					card_id + ": every field of the surviving foe moves one slot forward")
				_check(proposed.get(target) == {}, card_id + ": the old slot is vacated")
				_check(proposed.get(4) == bystander,
					card_id + ": the fourth bystander keeps HP, Block, statuses and slot")
				_check(proposed.get(companion_slot) == companion,
					card_id + ": the untouched companion is preserved byte-for-byte")
				_check(slots == before["slots"], card_id + ": the caller's snapshot is unchanged")
				var after := _hook_state(f, slots)
				_check(after["energy"] == 1 and after["state_energy"] == 1,
					card_id + ": exactly two energy are spent")
				_check(after["hand"].size() == before["hand"].size() - 1
					and after["hand"].count(card_id) == 0,
					card_id + ": exactly one held copy leaves the hand")
				_check(after["discard"] == [card_id],
					card_id + ": exactly one copy lands in the discard pile")
				_check(after["draw"] == before["draw"] and after["exhausted"] == before["exhausted"]
					and after["active"] == true,
					card_id + ": no card is drawn or exhausted and the turn stays active")
				_check(after["rng"] == before["rng"],
					card_id + ": a fixed-target Hook never advances the seeded run RNG")
				_check(after["heroes"] == before["heroes"],
					card_id + ": the source party is unchanged")
				var fresh := CombatScarecrowPitchforkHookCards.new().propose_hook(
					card_id, f["party"], target, slots)
				_check(fresh.get("ok") == true and fresh.get("slots") == proposed,
					card_id + ": a legal replay has the same detached proposal")
				# The receipt is detached: mutating it cannot rewrite the authorities.
				result["slots"][target - 1]["hp"] = -999
				result["damage"] = -999
				_check(_hook_state(f, slots) == after,
					card_id + ": the paid receipt is detached from every authority")
	_check(cases == 8, "AC2 exercises both printings from both legal seats onto both legal targets")


## AC2: explicit Block absorption plus Weak/Exposed/Tangled arithmetic through the real
## CombatStatuses rules. Tangled adds its flat +2 after scaling and never blocks the hero-side
## pull; no status is added, consumed or aged.
func _test_hook_block_and_status_math() -> void:
	for card_id: String in HOOK_IDS:
		var damage: int = int(HOOK_CARDS[card_id]["damage"])
		var block := 12
		var slots := {2: _hook_foe("spool_stalker", 2, 20, 20, block, {"bleed": 1}),
			4: _hook_bystander()}
		var f := _hook_fixture(card_id, 2, 424300 + damage)
		var result := CombatScarecrowPitchforkHookCards.new().play_held_hook(
			f["deck"], f["party"], card_id, 2, slots)
		_check(result.get("ok") == true, card_id + ": a fully blocked Hook still resolves")
		_check(result.get("block_before") == block and result.get("block_after") == block - damage
			and result.get("block_absorbed") == damage,
			card_id + ": enemy Block absorbs the whole printed hit")
		_check(result.get("hp_before") == 20 and result.get("hp_after") == 20
			and result.get("hp_loss") == 0,
			card_id + ": fully blocked damage leaves HP untouched")
		_check(result.get("moved") == true, card_id + ": the blocked foe is still pulled forward")
		var moved: Dictionary = result.get("slots", {}).get(1, {})
		_check(moved.get("hp") == 20 and moved.get("block") == block - damage
			and moved.get("position") == 1,
			card_id + ": the moved copy carries the post-Block HP/Block and its new slot")
		_check(moved.get("statuses") == {"bleed": 1},
			card_id + ": the Hook adds, consumes and ages no status")
		_check(_hook_state(f, slots)["energy"] == 1, card_id + ": the blocked hit still pays")
	var cases: Array = [
		["Weak takes 25 percent off", {"weak": 1}, {},
			{"scarecrow_pitchfork_hook": 5, "scarecrow_pitchfork_hook_plus": 7}],
		["Exposed adds 50 percent", {}, {"exposed": 1},
			{"scarecrow_pitchfork_hook": 10, "scarecrow_pitchfork_hook_plus": 15}],
		["Weak plus Exposed combines at nine eighths", {"weak": 2}, {"exposed": 3},
			{"scarecrow_pitchfork_hook": 7, "scarecrow_pitchfork_hook_plus": 11}],
		["positive-base Tangled adds two after scaling", {}, {"tangled": 2},
			{"scarecrow_pitchfork_hook": 9, "scarecrow_pitchfork_hook_plus": 12}],
		["Exposed then one Tangled +2", {}, {"exposed": 1, "tangled": 1},
			{"scarecrow_pitchfork_hook": 12, "scarecrow_pitchfork_hook_plus": 17}],
	]
	for entry: Array in cases:
		var label_base: String = entry[0]
		var attacker: Dictionary = entry[1]
		var defender: Dictionary = entry[2]
		var printed: Dictionary = entry[3]
		for card_id: String in HOOK_IDS:
			var label: String = label_base + " (" + card_id + ")"
			var slots := {2: _hook_foe("spool_stalker", 2, 60, 60, 0,
				defender.duplicate(true)), 4: _hook_bystander()}
			var f := _hook_fixture(card_id, 2, 424400 + int(printed[card_id]))
			f["party"]._heroes[1]["statuses"] = attacker.duplicate(true)
			var expected_damage: int = int(printed[card_id])
			var result := CombatScarecrowPitchforkHookCards.new().play_held_hook(
				f["deck"], f["party"], card_id, 2, slots)
			_check(result.get("ok") == true, label + ": resolves")
			_check(result.get("damage") == expected_damage,
				label + ": adjusted damage is " + str(expected_damage))
			_check(result.get("hp_after") == 60 - expected_damage,
				label + ": the adjusted damage lands on HP")
			_check(result.get("moved") == true,
				label + ": a Tangled foe is still pulled by the hero side")
			var moved: Dictionary = result.get("slots", {}).get(1, {})
			_check(moved.get("statuses") == defender,
				label + ": the defender's statuses are preserved, not consumed or aged")
			_check(f["party"].get_hero(2).get("statuses") == attacker,
				label + ": the attacker's statuses are not consumed or aged")
			# Independent oracle through the same shared rules.
			_check(CombatStatuses.new().adjusted_attack_damage(
				int(HOOK_CARDS[card_id]["damage"]), attacker, defender) == expected_damage,
				label + ": matches CombatStatuses' own projection")


## AC2: a lethal Hook leaves the defeated actor in its original slot at 0 HP, creates no living
## duplicate, drags no corpse forward and still pays its two energy and one held copy.
func _test_hook_lethal_keeps_corpse() -> void:
	for card_id: String in HOOK_IDS:
		var damage: int = int(HOOK_CARDS[card_id]["damage"])
		for hp: int in [damage, 1]:
			var slots := {2: _hook_foe("spool_stalker", 2, hp, 18, 0, {"bleed": 2}),
				3: _hook_foe("button_guard", 3, 12, 12, 4),
				4: _hook_bystander()}
			var f := _hook_fixture(card_id, 1, 424500 + hp)
			var result := CombatScarecrowPitchforkHookCards.new().play_held_hook(
				f["deck"], f["party"], card_id, 2, slots)
			_check(result.get("ok") == true, card_id + ": a lethal Hook still resolves")
			_check(result.get("slain") == true and result.get("moved") == false,
				card_id + ": a lethal hit moves no corpse")
			_check(result.get("hp_after") == 0 and result.get("hp_loss") == hp,
				card_id + ": the defeated foe is left at zero HP")
			var proposed: Dictionary = result.get("slots", {})
			_check(proposed.get(2, {}).get("id") == "spool_stalker"
				and proposed.get(2, {}).get("hp") == 0
				and proposed.get(2, {}).get("position") == 2,
				card_id + ": the corpse stays in its original slot")
			_check(proposed.get(1) == {}, card_id + ": no living duplicate appears in slot 1")
			var living := 0
			var seen: Array[String] = []
			for slot: int in [1, 2, 3, 4]:
				var actor: Dictionary = proposed.get(slot, {})
				if actor.is_empty():
					continue
				if int(actor.get("hp", 0)) > 0:
					living += 1
				_check(not seen.has(actor.get("id")), card_id + ": identity stays unique")
				seen.append(actor.get("id"))
			_check(living == 2, card_id + ": exactly the two living bystanders survive")
			_check(proposed.get(3) == slots[3] and proposed.get(4) == slots[4],
				card_id + ": the other actors are byte-for-byte unchanged")
			var after := _hook_state(f, slots)
			_check(after["energy"] == 1 and after["discard"] == [card_id],
				card_id + ": the lethal hit still pays two energy and one copy")


## AC3: every invalid request is refused before payment and leaves the deck, party, detached
## snapshot and seeded RNG byte-for-byte unchanged.
func _test_hook_refusals() -> void:
	var service := CombatScarecrowPitchforkHookCards.new()
	var base_id := "scarecrow_pitchfork_hook"
	var slots_two := _hook_slots(2)
	var slots_three := _hook_slots(3)

	var f := _hook_fixture(base_id, 2, 424600)
	for broken: Variant in [null, 5, 3.5, true, [], {}, StringName(base_id), "",
			"scarecrow_pitchfork_hook_plus_plus", "SCARECROW_PITCHFORK_HOOK",
			" scarecrow_pitchfork_hook", "scarecrow_pitchfork_hook ",
			"scarecrow_pitchfork_prick", "scarecrow_re_stuff", "warden_strike",
			"scarecrow_pitchfork_hook+"]:
		_hook_refused(f, broken, 2, slots_two, "unsupported_card")

	# Null authorities.
	var heroes_before: Array = f["party"].get_heroes()
	var slots_before: Dictionary = slots_two.duplicate(true)
	_check(service.play_held_hook(null, f["party"], base_id, 2, slots_two)
		.get("reason") == "invalid_request", "a null shared deck is refused")
	_check(service.play_held_hook(f["deck"], null, base_id, 2, slots_two)
		.get("reason") == "invalid_request", "a null party is refused")
	_check(f["party"].get_heroes() == heroes_before and slots_two == slots_before,
		"null authorities mutate nothing")

	# Malformed shared deck state.
	var no_state := _hook_fixture(base_id, 2, 424601)
	no_state["deck"].combat_state = null
	_hook_refused(no_state, base_id, 2, slots_two, "invalid_deck")
	var no_rng := _hook_fixture(base_id, 2, 424602)
	no_rng["deck"]._rng = null
	_hook_refused(no_rng, base_id, 2, slots_two, "invalid_deck")

	var inactive := _hook_fixture(base_id, 2, 424603)
	_check(inactive["deck"].end_turn(), "inactive Hook fixture really ends the shared turn")
	_hook_refused(inactive, base_id, 2, slots_two, "inactive_turn")

	var unheld := _hook_fixture(base_id, 2, 424604)
	_hook_refused(unheld, "scarecrow_pitchfork_hook_plus", 2, slots_two, "card_not_held")
	var poor := _hook_fixture(base_id, 2, 424605)
	_check(poor["deck"].try_spend_energy(3) and poor["deck"].energy == 0,
		"insufficient-energy Hook fixture really spent the whole budget")
	_hook_refused(poor, base_id, 2, slots_two, "insufficient_energy")

	# Owner roster and seat.
	var no_owner := _hook_fixture(base_id, 2, 424606)
	no_owner["party"] = CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 25},
	])
	_check(no_owner["party"].is_valid() and no_owner["party"].get_hero(2).get("id") == "seamstress",
		"missing-owner Hook fixture is a valid living party without a Scarecrow")
	_hook_refused(no_owner, base_id, 2, slots_two, "owner_missing")
	var torn := _hook_fixture(base_id, 1, 424607)
	_check(torn["party"].apply_damage(1, 32) and torn["party"].is_downed(1),
		"downed-owner Hook fixture really has zero HP on the Scarecrow")
	_hook_refused(torn, base_id, 2, slots_two, "owner_downed")
	var rear_seat := _hook_fixture(base_id, 3, 424608)
	_check(rear_seat["party"].get_hero(3).get("id") == "scarecrow"
		and not rear_seat["party"].is_downed(3),
		"rear-seat Hook fixture is a valid, living Scarecrow outside the printed FROM seats")
	_hook_refused(rear_seat, base_id, 2, slots_two, "owner_illegal_position")
	var duplicate := _hook_fixture(base_id, 2, 424609)
	duplicate["party"]._heroes[0]["id"] = "scarecrow"
	_hook_refused(duplicate, base_id, 2, slots_two, "invalid_party")
	var short_party := _hook_fixture(base_id, 2, 424610)
	short_party["party"] = CombatParty.new([{"id": "scarecrow", "max_hp": 32},
		{"id": "warden", "max_hp": 40}])
	_hook_refused(short_party, base_id, 2, slots_two, "invalid_party")
	var bad_hp := _hook_fixture(base_id, 2, 424611)
	bad_hp["party"]._heroes[1]["hp"] = 99
	_hook_refused(bad_hp, base_id, 2, slots_two, "invalid_party")
	var bad_block := _hook_fixture(base_id, 2, 424612)
	bad_block["party"]._heroes[0]["block"] = "0"
	_hook_refused(bad_block, base_id, 2, slots_two, "invalid_party")
	var bad_status := _hook_fixture(base_id, 2, 424613)
	bad_status["party"]._heroes[0]["statuses"] = {"forged": 1}
	_hook_refused(bad_status, base_id, 2, slots_two, "invalid_party")

	# Target line, missing/slain targets and occupied destinations.
	var target_f := _hook_fixture(base_id, 2, 424614)
	for bad_target: Variant in [0, 5, -1, "2", 2.0, null, true, [2]]:
		_hook_refused(target_f, base_id, bad_target, slots_two, "invalid_target")
	_hook_refused(target_f, base_id, 1,
		{1: _hook_foe("button_guard_front", 1, 12, 12), 4: _hook_bystander()},
		"target_out_of_reach")
	_hook_refused(target_f, base_id, 4, slots_two, "target_out_of_reach")
	_hook_refused(target_f, base_id, 2, {3: _hook_foe("button_guard", 3)}, "target_missing")
	_hook_refused(target_f, base_id, 2, {1: {}, 2: {}, 3: _hook_foe("button_guard", 3)},
		"target_missing")
	var slain_slots := _hook_slots(2)
	slain_slots[2]["hp"] = 0
	_hook_refused(target_f, base_id, 2, slain_slots, "target_downed")
	var occupied_front := _hook_slots(2)
	occupied_front[1] = _hook_foe("button_guard_front", 1, 12, 12, 3)
	_hook_refused(target_f, base_id, 2, occupied_front, "destination_occupied")
	var occupied_middle := _hook_slots(3)
	occupied_middle[2] = _hook_foe("button_guard_middle", 2, 12, 12)
	_hook_refused(target_f, base_id, 3, occupied_middle, "destination_occupied")

	# Malformed detached snapshots: whole-snapshot validation, never coercion.
	for malformed: Variant in [null, [], "slots", 7, true]:
		_hook_refused(target_f, base_id, 2, malformed, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{0: _hook_foe("x", 0), 2: _hook_foe("y", 2)}, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{2: _hook_foe("y", 2), 5: _hook_foe("x", 5)}, "invalid_slots")
	_hook_refused(target_f, base_id, 2, {"2": _hook_foe("y", 2)}, "invalid_slots")
	_hook_refused(target_f, base_id, 2, {2: "spool_stalker"}, "invalid_slots")
	_hook_refused(target_f, base_id, 2, {2: _hook_foe("y", 1)}, "invalid_slots")
	var no_position := _hook_foe("y", 2)
	no_position.erase("position")
	_hook_refused(target_f, base_id, 2, {2: no_position}, "invalid_slots")
	var float_hp := _hook_foe("y", 2)
	float_hp["hp"] = 5.0
	_hook_refused(target_f, base_id, 2, {2: float_hp}, "invalid_slots")
	_hook_refused(target_f, base_id, 2, {2: _hook_foe("y", 2, 12, 9)}, "invalid_slots")
	_hook_refused(target_f, base_id, 2, {2: _hook_foe("y", 2, 5, 9, "0")}, "invalid_slots")
	_hook_refused(target_f, base_id, 2, {2: _hook_foe("", 2)}, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{2: _hook_foe("twin", 2), 3: _hook_foe("twin", 3)}, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{2: _hook_foe("y", 2, 5, 9, 0, "tangled")}, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{2: _hook_foe("y", 2, 5, 9, 0, {"slow": 1})}, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{2: _hook_foe("y", 2, 5, 9, 0, {"tangled": "1"})}, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{2: _hook_foe("y", 2, 5, 9, 0, {"tangled": -1})}, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{2: _hook_foe("y", 2, 5, 9, 0, {"dodge_next_attack": 2})}, "invalid_slots")
	_hook_refused(target_f, base_id, 2,
		{2: _hook_foe("y", 2), 4: _hook_foe("z", 3)}, "invalid_slots")

	# Forged catalog records: rewritten numbers, extra keys, wrong owner, broken links and seams.
	var pool = ScriptClass.new()
	var authentic: Dictionary = pool.get_definition(base_id)
	_check(CombatScarecrowPitchforkHookCards.is_authentic_definition(authentic, base_id),
		"the unmutated Hook fixture record really authenticates")
	var mutations: Array = [
		["damage", func(record: Dictionary) -> void: record["effects"]["damage"] = 99],
		["pull_two", func(record: Dictionary) -> void: record["effects"]["pull_forward"] = 2],
		["extra_effect", func(record: Dictionary) -> void: record["effects"]["bleed"] = 1],
		["owner", func(record: Dictionary) -> void: record["owner"] = "warden"],
		["free_cost", func(record: Dictionary) -> void: record["cost"] = 0],
		["float_cost", func(record: Dictionary) -> void: record["cost"] = 2.0],
		["seats", func(record: Dictionary) -> void: record["from_positions"] = [1]],
		["target_line", func(record: Dictionary) -> void: record["to_positions"] = [1, 2, 3]],
		["name", func(record: Dictionary) -> void: record["display_name"] = "Pitchfork Hook+"],
		["rarity", func(record: Dictionary) -> void: record["rarity"] = "rare"],
		["reward", func(record: Dictionary) -> void: record["reward_eligible"] = false],
		["unlink", func(record: Dictionary) -> void:
			record["upgrade_id"] = "scarecrow_pitchfork_hook_plus_plus"],
		["extra_key", func(record: Dictionary) -> void: record["action_kind"] = "hook"],
		["missing_art", func(record: Dictionary) -> void: record.erase("illustration_path")],
	]
	for entry: Array in mutations:
		var label: String = entry[0]
		var mutate: Callable = entry[1]
		var forged := _hook_fixture(base_id, 2, 424700)
		var record: Dictionary = pool.get_definition(base_id)
		mutate.call(record)
		var lookup := func(_id: String) -> Dictionary: return record
		_check(not CombatScarecrowPitchforkHookCards.is_authentic_definition(record, base_id),
			"forged Hook record fails authentication: " + label)
		_hook_refused(forged, base_id, 2, slots_two, "catalog_mismatch", lookup)
	# A broken "+" link is refused in both directions.
	var plus := _hook_fixture("scarecrow_pitchfork_hook_plus", 2, 424701)
	var plus_record: Dictionary = pool.get_definition("scarecrow_pitchfork_hook_plus")
	plus_record["upgrade_of"] = "scarecrow_pitchfork_prick"
	_hook_refused(plus, "scarecrow_pitchfork_hook_plus", 2, slots_two, "catalog_mismatch",
		func(_id: String) -> Dictionary: return plus_record)
	var plus_with_id: Dictionary = pool.get_definition("scarecrow_pitchfork_hook_plus")
	plus_with_id["upgrade_id"] = "scarecrow_pitchfork_hook_plus_plus"
	_hook_refused(plus, "scarecrow_pitchfork_hook_plus", 2, slots_two, "catalog_mismatch",
		func(_id: String) -> Dictionary: return plus_with_id)
	# A seam that returns a foreign record, nothing, a non-record or is not callable.
	_hook_refused(f, base_id, 2, slots_two, "catalog_mismatch",
		func(_id: String) -> Dictionary: return pool.get_definition("scarecrow_pitchfork_prick"))
	_hook_refused(f, base_id, 2, slots_two, "catalog_mismatch",
		func(_id: String) -> Dictionary: return {})
	_hook_refused(f, base_id, 2, slots_two, "catalog_mismatch",
		func(_id: String) -> Variant: return null)
	_hook_refused(f, base_id, 2, slots_two, "catalog_mismatch", {})
	_hook_refused(f, base_id, 2, slots_two, "catalog_mismatch", Callable())
	# The authenticated seam is honoured only for a genuinely exact record.
	_check(CombatScarecrowPitchforkHookCards.new().propose_hook(base_id, f["party"], 2, slots_two,
		func(_id: String) -> Dictionary: return pool.get_definition(base_id)).get("ok") == true,
		"an exact authenticated seam proposes normally")
	# A refused attempt never poisons the next authentic play on the same objects.
	var recovery := _hook_fixture(base_id, 2, 424800)
	var recovered := CombatScarecrowPitchforkHookCards.new().play_held_hook(
		recovery["deck"], recovery["party"], base_id, 2, slots_two)
	_check(recovered.get("ok") == true and recovery["deck"].energy == 1
		and recovery["deck"].discard_pile == [base_id],
		"a valid Hook still resolves after every refusal")


## AC3: the same seed and request order produce identical state, a legal replay repeats the same
## detached proposal, the paid replay is refused, and no Hook consumes a run RNG draw.
func _test_hook_seeded_replay() -> void:
	var first := _hook_replay(7331)
	var second := _hook_replay(7331)
	_check(not (first["results"] as Array).is_empty(), "seeded Hook replay ran real plays")
	_check(first == second, "seeded Hook replay produces identical final state")
	_check(first["rng"] == second["rng"], "seeded Hook replay consumes no run RNG draws")
	_check((first["results"] as Array).size() == 2
		and first["results"][0].get("ok") == true
		and first["results"][1].get("ok") == false,
		"seeded Hook replay keeps one paid Hook and the replay refusal")
	_check(first["results"][1].get("reason") == "card_not_held",
		"the replay is refused specifically for the missing held copy")
	_check(first["hp"] == [11, 12] and first["energy"] == 1
		and first["discard"] == ["scarecrow_pitchfork_hook"],
		"seeded Hook replay lands the exact HP, spends two energy and discards one copy")
	_check(first["slot_one"] == "spool_stalker" and first["slot_two"] == {},
		"seeded Hook replay moves the surviving foe exactly one slot forward")
	_check(first["bystander"] == _hook_bystander(),
		"seeded Hook replay preserves the fourth bystander exactly")
	# Two identical proposals are independent copies, and mutating one cannot poison the next.
	var f := _hook_fixture("scarecrow_pitchfork_hook_plus", 2, 7332)
	var slots := _hook_slots(2)
	var slots_before: Dictionary = slots.duplicate(true)
	var proposal_a := CombatScarecrowPitchforkHookCards.new().propose_hook(
		"scarecrow_pitchfork_hook_plus", f["party"], 2, slots)
	var proposal_b := CombatScarecrowPitchforkHookCards.new().propose_hook(
		"scarecrow_pitchfork_hook_plus", f["party"], 2, slots)
	_check(proposal_a.get("ok") == true and proposal_a == proposal_b,
		"a legal replay has the same detached proposal")
	_check(not is_same(proposal_a.get("slots"), proposal_b.get("slots")),
		"each proposal is an independent map")
	proposal_a["slots"][1]["hp"] = -999
	proposal_a["slots"][1]["statuses"]["bleed"] = 99
	proposal_a["damage"] = -999
	var proposal_c := CombatScarecrowPitchforkHookCards.new().propose_hook(
		"scarecrow_pitchfork_hook_plus", f["party"], 2, slots)
	_check(proposal_c == proposal_b, "mutating one proposal cannot poison the next")
	_check(slots == slots_before, "the caller's snapshot is still pristine")


func _hook_replay(seed_value: int) -> Dictionary:
	var f := _hook_fixture("scarecrow_pitchfork_hook", 2, seed_value)
	var slots := _hook_slots(2)
	var service := CombatScarecrowPitchforkHookCards.new()
	var results: Array = []
	results.append(service.play_held_hook(f["deck"], f["party"],
		"scarecrow_pitchfork_hook", 2, slots))
	results.append(service.play_held_hook(f["deck"], f["party"],
		"scarecrow_pitchfork_hook", 2, slots))
	var state := _hook_state(f, slots)
	var published: Dictionary = results[0].get("slots", {})
	return {"rng": state["rng"], "energy": state["energy"],
		"hand": state["hand"], "draw": state["draw"], "discard": state["discard"],
		"heroes": state["heroes"], "slots": published, "results": results,
		"hp": [int(published.get(1, {}).get("hp", -1)),
			int(published.get(3, {}).get("hp", -1))],
		"slot_one": published.get(1, {}).get("id", ""),
		"slot_two": published.get(2, {}),
		"bystander": published.get(4, {})}


## A real seeded five-card hand holding exactly one genuine copy of `card_id`, with the
## authoritative Scarecrow seated where the test asks.
func _hook_fixture(card_id: String, seat: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array[String] = [card_id]
	for filler: String in PITCHFORK_FILLERS:
		ids.append(filler)
	var deck := CombatDeck.new(ids, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(card_id) == 1,
		card_id + ": real seeded five-card hand holding exactly one genuine copy")
	return {"deck": deck, "party": _hook_party(seat), "rng": rng}


func _hook_party(seat: int) -> CombatParty:
	var ids: Array[String] = ["warden", "tinker", "seamstress"]
	ids[seat - 1] = "scarecrow"
	var definitions: Array = []
	for hero_id: String in ids:
		definitions.append({"id": hero_id, "max_hp": int(PITCHFORK_MAX_HP[hero_id])})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(seat).get("id") == "scarecrow"
		and party.get_hero(seat).get("position") == seat,
		"valid real party with the Scarecrow in seat " + str(seat))
	return party


## A canonical detached enemy record with extra authored fields, so any lost or rewritten field is
## visible. `statuses` stays absent when null and is validated exactly when present.
func _hook_foe(enemy_id: String, slot: int, hp: int = 18, max_hp: int = 18,
		block: Variant = 0, statuses: Variant = null) -> Dictionary:
	var record := {
		"id": enemy_id,
		"name": enemy_id.capitalize(),
		"max_hp": max_hp,
		"hp": hp,
		"block": block,
		"position": slot,
		"art_path": "res://assets/paper/enemies/" + enemy_id + ".png",
	}
	if statuses != null:
		record["statuses"] = statuses
	return record


## A distinctive living fourth bystander (post-summon band) with real HP, Block and statuses.
func _hook_bystander() -> Dictionary:
	return _hook_foe("hoard_beetle", 4, 21, 24, 7,
		{"riposte": 2, "cannot_buff_next_turn": true})


## Slot `target` holds the chosen foe with its immediate forward slot truly vacant; a companion
## occupies the other printed enemy slot and slot 4 is the untouched bystander.
func _hook_slots(target: int) -> Dictionary:
	if target == 2:
		return {2: _hook_foe("spool_stalker", 2, 18, 18, 0, {"bleed": 2}),
			3: _hook_foe("button_guard", 3, 12, 12, 4, {"weak": 2}),
			4: _hook_bystander()}
	return {1: _hook_foe("button_guard", 1, 12, 12, 4, {"exposed": 1}),
		3: _hook_foe("spool_stalker", 3, 18, 18, 0, {"bleed": 2}),
		4: _hook_bystander()}


## The full authoritative state used by the Hook suites: hand, both piles, energy, turn, heroes,
## the caller's detached snapshot and the seeded run RNG. Guards the deliberately malformed deck
## fixtures used by the refusal suite.
func _hook_state(f: Dictionary, slots: Variant) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var party: CombatParty = f["party"]
	var energy: Variant = null
	var state_energy: Variant = null
	var active: Variant = null
	if deck.combat_state != null:
		energy = deck.energy
		state_energy = deck.combat_state.energy
		active = deck.turn_active
	var rng_state: Variant = null
	if deck._rng != null:
		rng_state = deck._rng.state
	return {"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "exhausted": deck.exhausted.duplicate(),
		"energy": energy, "state_energy": state_energy, "active": active,
		"heroes": party.get_heroes(),
		"slots": slots.duplicate(true) if slots is Dictionary else slots,
		"rng": rng_state}


## Assert one Hook refusal: no receipt map and no payment, and the complete deck, party, detached
## snapshot and seeded RNG are byte-for-byte unchanged.
func _hook_refused(f: Dictionary, card_id: Variant, target: Variant, slots: Variant,
		reason: String, lookup: Variant = null) -> void:
	var before := _hook_state(f, slots)
	var result := CombatScarecrowPitchforkHookCards.new().play_held_hook(
		f["deck"], f["party"], card_id, target, slots, lookup)
	_check(result.get("ok") == false, str(card_id) + ": refuses " + reason)
	_check(result.get("reason") == reason,
		str(card_id) + ": reason " + reason + " (got " + str(result.get("reason")) + ")")
	_check(not result.has("slots") and not result.has("energy_spent") and not result.has("cost"),
		reason + ": publishes no proposal and no payment")
	_check(_hook_state(f, slots) == before,
		reason + ": preserves hand, draw, discard, energy, party, snapshot, turn and RNG")


