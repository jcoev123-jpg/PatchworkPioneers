extends SceneTree
## Design v4 (Stitched) Sewing Circle swap quotes disclose the FULL tier-resolved part ability.
##
## Scene-free: loads the real enemy part catalog, builds four locally-made complete dolls (HEAD, ARMS,
## TORSO, LEGS each) with a tier-I Needle Stinger worn in one ARMS slot and a tier-II Scissor Claw in
## the satchel, and drives RunStitchedSewingSwap directly. No catalog total or ordered id list is
## asserted, only named ids.

const ENEMY_PATH := "res://data/parts/enemy_parts.json"
const NODE := "sewing_circle_node_6"
const SLOT_NAMES := ["head", "arms", "torso", "legs"]
const ABILITY_FIELDS := ["id", "name", "kind", "launch", "target", "target_side", "multi", "acc", "dmg", "crit", "effects", "self_move", "move"]

var failures: Array = []
var catalog: Dictionary = {}
var catalog_before := ""


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6062026
	var rng_state_before := rng.state
	seed(6062026)
	var global_expected := randi()
	seed(6062026)
	if _load_inputs():
		_test_full_ability_quotes()
		_test_tier_one_claw_witness()
		_test_detachment()
		_test_authentic_swap()
		_test_comparison()
		_test_refusals()
	_check(rng.state == rng_state_before, "seeded RNG state must be unchanged")
	_check(randi() == global_expected, "global RNG must not advance")
	if failures.is_empty():
		print("stitched_s6_sewing_swap_ability_preview_test: PASS")
		quit(0)
	else:
		for message in failures:
			printerr("FAIL: " + str(message))
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _snap(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _load_inputs() -> bool:
	var loaded := StitchedParts.load_catalog(ENEMY_PATH)
	_check(bool(loaded["ok"]), "enemy catalog loads: " + str(loaded["error"]))
	if not bool(loaded["ok"]):
		return false
	catalog = loaded["by_id"]
	catalog_before = _snap(catalog)
	for id in _required_ids():
		_check(catalog.has(id), "catalog has " + id)
	for id in _required_ids():
		if not catalog.has(id):
			return false
	return true


func _required_ids() -> Array:
	return [
		"needle_wasp_stinger", "scissor_crab_claw_arm", "fray_scavenger_sack_arm", "moth_scribe_inkbrush_arm",
		"ragling_tatter_claw", "thread_biter_lint_gland", "zipper_snake_zip_teeth", "felt_bulwark_button_shield",
		"ragling_guard_button_plate", "button_guard_button_buckler", "thimble_beetle_shell", "moth_swarm_wings",
		"spool_stalker_thread_legs", "pin_skitter_quill_legs", "shearwing_mantis_shear_wing",
	]


func _worn(id: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn}


func _spare(id: String, slot: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn, "slot": slot}


## Four distinct dolls in ranks 1-4, each with a full HEAD/ARMS/TORSO/LEGS loadout of real enemy parts.
func _party() -> Array:
	var gear := [
		{"head": _worn("thread_biter_lint_gland"), "arms": _worn("needle_wasp_stinger"), "torso": _worn("felt_bulwark_button_shield"), "legs": _worn("moth_swarm_wings")},
		{"head": _worn("zipper_snake_zip_teeth", 2), "arms": _worn("fray_scavenger_sack_arm"), "torso": _worn("ragling_guard_button_plate", 2), "legs": _worn("spool_stalker_thread_legs")},
		{"head": _worn("thread_biter_lint_gland", 3), "arms": _worn("moth_scribe_inkbrush_arm", 2), "torso": _worn("button_guard_button_buckler"), "legs": _worn("pin_skitter_quill_legs", 3)},
		{"head": _worn("zipper_snake_zip_teeth"), "arms": _worn("ragling_tatter_claw", 3), "torso": _worn("thimble_beetle_shell", 2), "legs": _worn("shearwing_mantis_shear_wing")},
	]
	var heroes: Array = []
	for index in range(4):
		heroes.append({
			"id": "doll_%d" % (index + 1),
			"name": "Doll %d" % (index + 1),
			"rank": index + 1,
			"hp": 10 + index,
			"fray": 2 * index,
			"statuses": {"weak": index},
			"parts": gear[index],
		})
	return heroes


func _satchel(claw_tier: int = 2) -> Array:
	return [
		_spare("scissor_crab_claw_arm", "arms", claw_tier),
		_spare("spool_stalker_thread_legs", "legs", 3),
		_spare("thimble_beetle_shell", "torso", 1),
		_spare("zipper_snake_zip_teeth", "head", 2),
	]


func _service(heroes: Array = [], satchel: Array = [], node: String = NODE) -> RunStitchedSewingSwap:
	if heroes.is_empty():
		heroes = _party()
	if satchel.is_empty():
		satchel = _satchel()
	return RunStitchedSewingSwap.new(node, heroes, satchel, catalog)


func _expected_ability(id: String, tier: int) -> Dictionary:
	return StitchedParts.ability_at_tier(catalog[id], tier)


func _slot_quote(quote: Dictionary, hero_id: String, slot: String) -> Dictionary:
	for hero in quote["heroes"]:
		if str(hero["hero_id"]) == hero_id:
			for entry in hero["slots"]:
				if str(entry["slot"]) == slot:
					return entry
	return {}


## Every published part summary carries the unchanged identity fields and the full ability.
func _check_summary(summary: Dictionary, id: String, tier: int, slot: String, torn: bool, label: String) -> void:
	var entry: Dictionary = catalog[id]
	var expected := _expected_ability(id, tier)
	_check(not expected.is_empty(), label + ": expected ability resolves")
	_check(summary.get("ability") is Dictionary, label + ": ability is a dictionary")
	if not summary.get("ability") is Dictionary:
		return
	_check(summary["ability"] == expected, label + ": ability equals ability_at_tier")
	_check(_snap(summary["ability"]) == _snap(expected), label + ": ability snapshot equals ability_at_tier")
	for field in ABILITY_FIELDS:
		_check(summary["ability"].has(field), label + ": ability has " + field)
		_check(_snap(summary["ability"].get(field)) == _snap(expected.get(field)), label + ": ability field " + field)
	for field in ["launch_mask", "target_mask", "mark_damage"]:
		_check(summary["ability"].get(field) == expected.get(field), label + ": ability derived field " + field)
	_check(str(summary["id"]) == id, label + ": id")
	_check(str(summary["name"]) == str(entry["name"]), label + ": name")
	_check(str(summary["slot"]) == slot, label + ": slot")
	_check(str(summary["owner"]) == str(entry["owner"]), label + ": owner")
	_check(int(summary["tier"]) == tier, label + ": tier")
	_check(bool(summary["torn"]) == torn, label + ": torn")
	_check(summary["stat"] == StitchedParts.stat_at_tier(entry, tier), label + ": stat")
	_check(str(summary["text"]) == str(entry["text"]), label + ": text")


func _test_full_ability_quotes() -> void:
	var heroes := _party()
	var satchel := _satchel()
	var svc := RunStitchedSewingSwap.new(NODE, heroes, satchel, catalog)
	var quote := svc.quote()
	_check(bool(quote["ok"]), "opening quote ok")
	_check(quote["heroes"].size() == 4, "four dolls are quoted")
	_check(quote["satchel_count"] == satchel.size(), "satchel count")
	var worn_checked := 0
	var offers_checked := 0
	for hero_index in range(4):
		var hero: Dictionary = heroes[hero_index]
		var hero_quote: Dictionary = quote["heroes"][hero_index]
		_check(str(hero_quote["hero_id"]) == str(hero["id"]), "hero order " + str(hero["id"]))
		_check(hero_quote["slots"].size() == 4, "four slots for " + str(hero["id"]))
		for slot_index in range(4):
			var slot: String = SLOT_NAMES[slot_index]
			var slot_quote: Dictionary = hero_quote["slots"][slot_index]
			_check(str(slot_quote["slot"]) == slot, "slot order " + slot)
			var worn: Dictionary = hero["parts"][slot]
			_check_summary(slot_quote["worn"], str(worn["id"]), int(worn["tier"]), slot, bool(worn["torn"]), "%s %s worn" % [hero["id"], slot])
			worn_checked += 1
			var expected_indices: Array = []
			for index in range(satchel.size()):
				if str(satchel[index]["slot"]) == slot:
					expected_indices.append(index)
			_check(expected_indices.size() == 1, "one spare fits " + slot)
			_check(bool(slot_quote["can_swap"]), "%s %s can swap" % [hero["id"], slot])
			_check(str(slot_quote["blocked"]).is_empty(), "%s %s not blocked" % [hero["id"], slot])
			_check(slot_quote["offers"].size() == expected_indices.size(), "%s %s offer count" % [hero["id"], slot])
			for offer_index in range(slot_quote["offers"].size()):
				var offer: Dictionary = slot_quote["offers"][offer_index]
				var spare: Dictionary = satchel[int(expected_indices[offer_index])]
				_check(int(offer["satchel_index"]) == int(expected_indices[offer_index]), "offer index " + slot)
				_check_summary(offer["part"], str(spare["id"]), int(spare["tier"]), slot, bool(spare["torn"]), "%s %s offer" % [hero["id"], slot])
				offers_checked += 1
	_check(worn_checked == 16, "all sixteen worn parts were checked")
	_check(offers_checked == 16, "all sixteen offers were checked")
	for index in range(satchel.size()):
		var spare_summary: Dictionary = quote["satchel"][index]
		_check(int(spare_summary["satchel_index"]) == index, "satchel summary index")
		_check(spare_summary["ability"] == _expected_ability(str(satchel[index]["id"]), int(satchel[index]["tier"])), "satchel summary ability %d" % index)

	# AC2: worn tier-I stinger and satchel tier-II claw keep their own authored numbers.
	var arms: Dictionary = _slot_quote(quote, "doll_1", "arms")
	var sting: Dictionary = arms["worn"]["ability"]
	_check(str(sting["id"]) == "wasp_sting" and str(sting["name"]) == "Wasp Sting" and str(sting["kind"]) == "melee", "stinger identity")
	_check(sting["launch"] == [1, 3] and sting["target"] == [1], "stinger launch/target")
	_check(str(sting["target_side"]) == "enemy" and sting["multi"] == false, "stinger side/multi")
	_check(int(sting["acc"]) == 88 and sting["dmg"] == [4, 6] and int(sting["crit"]) == 0, "stinger acc/dmg/crit")
	_check(sting["effects"] == {"bleed": 2} and int(sting["self_move"]) == 0 and str(sting["move"]) == "attack2", "stinger bleed 2, no self move, attack2 pose")
	_check(int(sting["launch_mask"]) == StitchedParts.rank_mask([1, 3]) and int(sting["target_mask"]) == StitchedParts.rank_mask([1]), "stinger rank masks preserved")
	var claw: Dictionary = arms["offers"][0]["part"]["ability"]
	_check(int(arms["offers"][0]["part"]["tier"]) == 2, "claw offer is tier II")
	_check(str(claw["id"]) == "snip" and str(claw["name"]) == "Snip" and str(claw["kind"]) == "melee", "claw identity")
	_check(claw["launch"] == [1, 2] and claw["target"] == [1, 2], "claw launch/target")
	_check(str(claw["target_side"]) == "enemy" and claw["multi"] == false, "claw side/multi")
	_check(int(claw["acc"]) == 90 and claw["dmg"] == [5, 8] and int(claw["crit"]) == 0, "tier II claw acc 90, damage [5,8]")
	_check(claw["effects"] == {"bleed": 3} and int(claw["self_move"]) == 0 and str(claw["move"]) == "attack", "tier II claw bleed 3, attack pose")
	_check(arms["offers"][0]["part"]["stat"] == {"dmg": 1}, "claw slot stat starts at +1 DMG at tier II (no tier stat override)")
	_check(arms["worn"]["stat"] == {"dmg": 2}, "stinger tier I slot stat")
	_check(int(claw["launch_mask"]) == StitchedParts.rank_mask([1, 2]) and int(claw["target_mask"]) == StitchedParts.rank_mask([1, 2]), "claw rank masks preserved")
	_check(_snap(catalog) == catalog_before, "catalog is not mutated by quoting")


func _test_tier_one_claw_witness() -> void:
	var svc := _service([], _satchel(1))
	var quote := svc.quote()
	var arms: Dictionary = _slot_quote(quote, "doll_1", "arms")
	_check(arms["offers"].size() == 1, "tier I claw offered")
	var snip: Dictionary = arms["offers"][0]["part"]["ability"]
	_check(int(arms["offers"][0]["part"]["tier"]) == 1, "claw offer is tier I")
	_check(snip == _expected_ability("scissor_crab_claw_arm", 1), "tier I Snip equals ability_at_tier")
	_check(str(snip["name"]) == "Snip" and snip["launch"] == [1, 2] and snip["target"] == [1, 2], "tier I Snip launch/target")
	_check(int(snip["acc"]) == 90 and snip["dmg"] == [4, 7] and snip["effects"] == {"bleed": 2}, "tier I Snip acc 90, damage [4,7], Bleed 2")
	_check(arms["offers"][0]["part"]["stat"] == {"dmg": 1}, "tier I claw stat +1 DMG")
	# the authored tiers differ, so a short or tier-blind projection could not pass both checks
	_check(_expected_ability("scissor_crab_claw_arm", 1) != _expected_ability("scissor_crab_claw_arm", 2), "tier I and II Snip differ")
	_check(_expected_ability("scissor_crab_claw_arm", 3)["dmg"] == [6, 9], "tier III Snip damage is authored")


func _test_detachment() -> void:
	var svc := _service()
	var first := svc.quote()
	var first_snap := _snap(first)
	var state_snap := _snap(svc.read_state())
	var arms: Dictionary = _slot_quote(first, "doll_1", "arms")
	var worn_ability: Dictionary = arms["worn"]["ability"]
	var offer_ability: Dictionary = arms["offers"][0]["part"]["ability"]
	var satchel_ability: Dictionary = first["satchel"][0]["ability"]
	worn_ability["dmg"][0] = 99
	worn_ability["launch"].append(4)
	worn_ability["effects"]["bleed"] = 99
	worn_ability["effects"]["poison"] = 5
	worn_ability["name"] = "Mutated"
	worn_ability.erase("move")
	offer_ability["dmg"][1] = 77
	offer_ability["target"].clear()
	offer_ability["effects"].clear()
	offer_ability["acc"] = 1
	satchel_ability["dmg"].append(1)
	satchel_ability["effects"]["bleed"] = 50
	arms["worn"]["stat"]["dmg"] = 50
	var second := svc.quote()
	_check(_snap(second) == first_snap, "re-quote is unaffected by mutating a returned quote")
	_check(_snap(svc.read_state()) == state_snap, "service state is unaffected by mutating a returned quote")
	var second_arms: Dictionary = _slot_quote(second, "doll_1", "arms")
	_check(second_arms["worn"]["ability"]["dmg"] == [4, 6] and second_arms["worn"]["ability"]["effects"] == {"bleed": 2}, "stinger numbers survive mutation")
	_check(second_arms["offers"][0]["part"]["ability"]["dmg"] == [5, 8] and second_arms["offers"][0]["part"]["ability"]["effects"] == {"bleed": 3}, "claw numbers survive mutation")
	_check(_snap(catalog) == catalog_before, "catalog is not mutated through a returned quote")
	# two quotes never share nested containers
	var other := svc.quote()
	var one: Dictionary = _slot_quote(second, "doll_1", "arms")["worn"]["ability"]
	var two: Dictionary = _slot_quote(other, "doll_1", "arms")["worn"]["ability"]
	one["effects"]["bleed"] = 123
	_check(two["effects"]["bleed"] == 2, "two quotes are independent copies")
	# the same part worn by two dolls is also independent inside one quote
	var shared: Dictionary = _slot_quote(other, "doll_1", "head")["worn"]["ability"]
	var shared_other: Dictionary = _slot_quote(other, "doll_3", "head")["worn"]["ability"]
	_check(str(shared["id"]) == str(shared_other["id"]), "dolls 1 and 3 wear the same head part")
	shared["effects"]["exposed"] = 99
	_check(shared_other["effects"]["exposed"] != 99, "same part on two dolls does not share containers")


func _test_authentic_swap() -> void:
	var heroes := _party()
	var satchel := _satchel()
	var svc := RunStitchedSewingSwap.new(NODE, heroes, satchel, catalog)
	var quote := svc.quote()
	var source: Dictionary = quote["state"]
	var arms: Dictionary = _slot_quote(quote, "doll_1", "arms")
	var offer: Dictionary = arms["offers"][0]
	_check(str(arms["worn"]["id"]) == "needle_wasp_stinger" and str(offer["part"]["id"]) == "scissor_crab_claw_arm", "quote pairs stinger with claw")
	var receipt := svc.swap("doll_1", "arms", int(offer["satchel_index"]), NODE, source)
	_check(bool(receipt["ok"]), "authentic swap succeeds: " + str(receipt.get("error")))
	if not bool(receipt["ok"]):
		return
	_check(str(receipt["action"]) == "swap" and str(receipt["hero_id"]) == "doll_1" and str(receipt["slot"]) == "arms", "receipt identifies the exchange")
	_check(receipt["worn_before"] == {"id": "needle_wasp_stinger", "tier": 1, "torn": false}, "receipt worn_before")
	_check(receipt["worn_after"] == {"id": "scissor_crab_claw_arm", "tier": 2, "torn": false}, "receipt worn_after")
	_check(receipt["satchel_before"] == satchel[0], "receipt satchel_before")
	_check(receipt["satchel_after"] == {"id": "needle_wasp_stinger", "tier": 1, "torn": false, "slot": "arms"}, "receipt satchel_after")
	_check(_snap(receipt["source_state"]) == _snap(source), "receipt carries the authentic source snapshot")
	var after: Dictionary = receipt["state"]
	_check(int(after["version"]) == int(source["version"]) + 1 and bool(after["open"]), "only the visit version advances")
	_check(_snap(after) == _snap(svc.read_state()), "receipt state is the authoritative state")
	for index in range(4):
		var before_hero: Dictionary = source["heroes"][index].duplicate(true)
		var after_hero: Dictionary = after["heroes"][index].duplicate(true)
		if index == 0:
			_check(after_hero["parts"]["arms"] == {"id": "scissor_crab_claw_arm", "tier": 2, "torn": false}, "doll 1 now wears the tier II claw")
			for slot in ["head", "torso", "legs"]:
				_check(after_hero["parts"][slot] == before_hero["parts"][slot], "doll 1 keeps its " + slot)
			before_hero["parts"].erase("arms")
			after_hero["parts"].erase("arms")
		_check(_snap(before_hero) == _snap(after_hero), "doll %d hp/fray/statuses/rank/other parts unchanged" % (index + 1))
	for index in range(satchel.size()):
		if index == 0:
			_check(after["satchel"][0] == receipt["satchel_after"], "satchel slot 0 now holds the stinger")
		else:
			_check(after["satchel"][index] == source["satchel"][index], "satchel record %d unchanged" % index)
	_check(after["satchel"].size() == satchel.size(), "no part is minted or lost")
	var requote := svc.quote()
	var new_arms: Dictionary = _slot_quote(requote, "doll_1", "arms")
	_check(new_arms["worn"]["ability"] == _expected_ability("scissor_crab_claw_arm", 2), "post-swap worn claw shows the full tier II ability")
	_check(new_arms["offers"][0]["part"]["ability"] == _expected_ability("needle_wasp_stinger", 1), "post-swap spare stinger shows the full tier I ability")
	_check(int(requote["version"]) == int(source["version"]) + 1, "quote reports the new version")


const COMPARISON_FIELDS := ["name", "launch", "target", "target_side", "dmg", "acc", "crit", "effects", "self_move"]


func _expected_view(id: String, tier: int) -> Dictionary:
	var ability := _expected_ability(id, tier)
	var view: Dictionary = {}
	for field in COMPARISON_FIELDS:
		view[field] = ability[field]
	return view


func _comparison_of(quote: Dictionary, hero_id: String, slot: String, offer_index: int = 0) -> Dictionary:
	var slot_quote := _slot_quote(quote, hero_id, slot)
	if slot_quote.is_empty() or slot_quote["offers"].size() <= offer_index:
		return {}
	var offer: Dictionary = slot_quote["offers"][offer_index]
	return offer.get("comparison", {}) if offer.get("comparison") is Dictionary else {}


func _test_comparison() -> void:
	var svc := _service()
	var quote := svc.quote()
	var arms: Dictionary = _slot_quote(quote, "doll_1", "arms")
	_check(str(arms["worn"]["id"]) == "needle_wasp_stinger" and int(arms["worn"]["tier"]) == 1, "comparison precondition: tier I stinger worn")
	_check(str(arms["offers"][0]["part"]["id"]) == "scissor_crab_claw_arm" and int(arms["offers"][0]["part"]["tier"]) == 2, "comparison precondition: tier II claw offered")
	var comparison := _comparison_of(quote, "doll_1", "arms")
	_check(not comparison.is_empty(), "arms offer publishes a comparison")
	if comparison.is_empty():
		return
	_check(comparison.keys().size() == 3, "comparison has only before, after and stat_delta")
	var before: Dictionary = comparison["ability_before"]
	var after: Dictionary = comparison["ability_after"]
	_check(before == _expected_view("needle_wasp_stinger", 1), "ability_before is the tier I stinger view")
	_check(after == _expected_view("scissor_crab_claw_arm", 2), "ability_after is the tier II claw view")
	_check(int(before["acc"]) == 88 and int(after["acc"]) == 90, "ACC 88 -> 90")
	_check(before["dmg"] == [4, 6] and after["dmg"] == [5, 8], "damage [4,6] -> [5,8]")
	_check(before["effects"] == {"bleed": 2} and after["effects"] == {"bleed": 3}, "Bleed 2 -> 3")
	_check(before["launch"] == [1, 3] and after["launch"] == [1, 2], "launch [1,3] -> [1,2]")
	_check(before["target"] == [1] and after["target"] == [1, 2], "target [1] -> [1,2]")
	_check(str(before["name"]) == "Wasp Sting" and str(after["name"]) == "Snip", "ability names")
	_check(str(after["target_side"]) == "enemy" and int(after["self_move"]) == 0 and int(after["crit"]) == 0, "side, self move and crit are carried")
	_check(comparison["stat_delta"] == {"dmg": -1}, "stat_delta is {dmg:-1}")
	# worn and offer summaries keep their complete existing fields
	_check_summary(arms["worn"], "needle_wasp_stinger", 1, "arms", false, "comparison worn")
	_check_summary(arms["offers"][0]["part"], "scissor_crab_claw_arm", 2, "arms", false, "comparison offer")

	# generic stat keys: a missing key counts as 0 and an unchanged key is omitted
	var legs := _comparison_of(quote, "doll_1", "legs")
	_check(legs["stat_delta"] == {"speed": 3, "dodge": 2}, "legs: dodge 5 -> 7 and missing speed -> 3")
	_check(legs["ability_before"] == _expected_view("moth_swarm_wings", 1) and legs["ability_after"] == _expected_view("spool_stalker_thread_legs", 3), "legs ability views at their tiers")
	var legs_two := _comparison_of(quote, "doll_2", "legs")
	_check(legs_two["stat_delta"] == {"speed": 2, "dodge": 4}, "doll 2 legs: tier I -> III gives speed +2, dodge +4")
	var reverse_legs_svc := _service([], [_spare("moth_swarm_wings", "legs", 1)])
	var reverse_legs := _comparison_of(reverse_legs_svc.quote(), "doll_2", "legs")
	_check(reverse_legs["stat_delta"] == {"speed": -1, "dodge": 2}, "absent incoming key goes negative: speed -1, dodge +2")
	var torso := _comparison_of(quote, "doll_1", "torso")
	_check(torso["stat_delta"].is_empty(), "equal prot 10 -> 10 leaves stat_delta empty")
	_check(torso["ability_before"]["effects"] == {"guard": 2} and torso["ability_after"]["effects"] == {"guard": 3}, "ability change is reported despite equal stats")
	var same_head := _comparison_of(quote, "doll_2", "head")
	_check(same_head["stat_delta"].is_empty() and same_head["ability_before"] == same_head["ability_after"], "identical part and tier: empty delta, equal abilities")

	# (d) mutating a returned comparison never alters another quote or the service
	var state_snap := _snap(svc.read_state())
	var fresh_snap := _snap(svc.quote())
	comparison["ability_before"]["dmg"][0] = 99
	comparison["ability_after"]["launch"].append(4)
	comparison["ability_after"]["effects"]["bleed"] = 99
	comparison["ability_before"]["effects"]["poison"] = 5
	comparison["stat_delta"]["dmg"] = 50
	comparison["stat_delta"]["acc"] = 1
	var again := svc.quote()
	_check(_snap(again) == fresh_snap, "re-quote unaffected by mutating a returned comparison")
	_check(_snap(svc.read_state()) == state_snap, "service state unaffected by mutating a comparison")
	var again_comparison := _comparison_of(again, "doll_1", "arms")
	_check(again_comparison["stat_delta"] == {"dmg": -1} and again_comparison["ability_before"]["dmg"] == [4, 6], "fresh comparison keeps authored numbers")
	_check(again_comparison["ability_after"]["effects"] == {"bleed": 3} and again_comparison["ability_after"]["launch"] == [1, 2], "fresh comparison after-ability unchanged")
	_check(_snap(catalog) == catalog_before, "catalog unchanged by comparison mutation")
	# a comparison never shares containers with its own part summaries
	var arms_again := _slot_quote(again, "doll_1", "arms")
	again_comparison["ability_before"]["effects"]["bleed"] = 7
	again_comparison["ability_after"]["dmg"][1] = 1
	_check(arms_again["worn"]["ability"]["effects"] == {"bleed": 2} and arms_again["offers"][0]["part"]["ability"]["dmg"] == [5, 8], "comparison is detached from the part summaries")

	# (b) reverse comparison after a genuine same-node swap
	var swap_svc := _service()
	var swap_quote := swap_svc.quote()
	var receipt := swap_svc.swap("doll_1", "arms", 0, NODE, swap_quote["state"])
	_check(bool(receipt["ok"]), "comparison swap succeeds: " + str(receipt.get("error")))
	if not bool(receipt["ok"]):
		return
	var requote := swap_svc.quote()
	var new_arms := _slot_quote(requote, "doll_1", "arms")
	_check(str(new_arms["worn"]["id"]) == "scissor_crab_claw_arm" and str(new_arms["offers"][0]["part"]["id"]) == "needle_wasp_stinger", "after the swap the claw is worn and the stinger is offered")
	_check(int(new_arms["offers"][0]["satchel_index"]) == 0, "returned stinger sits at the same satchel index")
	var reverse := _comparison_of(requote, "doll_1", "arms")
	_check(reverse["ability_before"] == _expected_view("scissor_crab_claw_arm", 2), "reverse ability_before is the tier II claw")
	_check(reverse["ability_after"] == _expected_view("needle_wasp_stinger", 1), "reverse ability_after is the tier I stinger")
	_check(reverse["stat_delta"] == {"dmg": 1}, "reverse stat_delta is {dmg:1}")
	_check(int(reverse["ability_before"]["acc"]) == 90 and int(reverse["ability_after"]["acc"]) == 88, "reverse ACC 90 -> 88")
	_check(reverse["ability_before"]["dmg"] == [5, 8] and reverse["ability_after"]["dmg"] == [4, 6], "reverse damage [5,8] -> [4,6]")
	# unrelated offers keep their comparisons after the swap
	_check(_comparison_of(requote, "doll_1", "legs")["stat_delta"] == {"speed": 3, "dodge": 2}, "unrelated legs comparison unchanged by the arms swap")
	_check(_snap(swap_svc.quote()) == _snap(requote), "quoting twice after the swap is stable")


func _expect_refusal(svc: RunStitchedSewingSwap, result: Dictionary, label: String) -> void:
	var before_snap := _snap(svc.read_state())
	_check(not bool(result.get("ok", true)), label + ": refused")
	_check(str(result.get("error", "")) != "", label + ": names a reason")
	_check(_snap(svc.read_state()) == before_snap, label + ": no state drift")


func _test_refusals() -> void:
	# wrong node
	var svc := _service()
	var state := svc.read_state()
	var before_snap := _snap(state)
	_expect_refusal(svc, svc.swap("doll_1", "arms", 0, "sewing_circle_node_7", state), "wrong node")
	_check(_snap(svc.read_state()) == before_snap, "wrong node leaves the visit untouched")

	# stale snapshot: a snapshot from before an authentic exchange
	var stale_svc := _service()
	var stale_state := stale_svc.read_state()
	var done := stale_svc.swap("doll_1", "arms", 0, NODE, stale_state)
	_check(bool(done["ok"]), "setup swap before stale replay")
	_expect_refusal(stale_svc, stale_svc.swap("doll_2", "arms", 0, NODE, stale_state), "stale snapshot")
	_check(str(stale_svc.swap("doll_2", "arms", 0, NODE, stale_state)["error"]) == "stale or forged state", "stale snapshot reason")

	# wrong slot: the claw is an ARMS spare and cannot be forced into LEGS
	var slot_svc := _service()
	var slot_state := slot_svc.read_state()
	var wrong_slot := slot_svc.swap("doll_1", "legs", 0, NODE, slot_state)
	_expect_refusal(slot_svc, wrong_slot, "wrong slot")
	_check(str(wrong_slot["error"]).contains("does not fit"), "wrong slot reason")

	# torn worn part: blocked in the quote and refused by swap
	var torn_party := _party()
	torn_party[0]["parts"]["arms"] = _worn("needle_wasp_stinger", 1, true)
	var torn_svc := _service(torn_party)
	var torn_quote := torn_svc.quote()
	var torn_arms: Dictionary = _slot_quote(torn_quote, "doll_1", "arms")
	_check(not bool(torn_arms["can_swap"]) and torn_arms["offers"].is_empty() and str(torn_arms["blocked"]).contains("torn"), "torn worn part offers nothing")
	_check(torn_arms["worn"]["ability"] == _expected_ability("needle_wasp_stinger", 1) and bool(torn_arms["worn"]["torn"]), "torn worn part still discloses its ability")
	_expect_refusal(torn_svc, torn_svc.swap("doll_1", "arms", 0, NODE, torn_svc.read_state()), "torn worn part")

	# LOST hero: no offers, every slot blocked, swap refused
	var lost_party := _party()
	lost_party[0]["lost"] = true
	var lost_svc := _service(lost_party)
	var lost_quote := lost_svc.quote()
	for slot in SLOT_NAMES:
		var lost_slot: Dictionary = _slot_quote(lost_quote, "doll_1", slot)
		_check(not bool(lost_slot["can_swap"]) and lost_slot["offers"].is_empty() and str(lost_slot["blocked"]) == "hero is lost", "lost doll " + slot + " is blocked")
	_expect_refusal(lost_svc, lost_svc.swap("doll_1", "arms", 0, NODE, lost_svc.read_state()), "lost hero")
	var other_ok := lost_svc.swap("doll_2", "arms", 0, NODE, lost_svc.read_state())
	_check(bool(other_ok["ok"]), "a living doll can still swap beside a lost one")

	# second choice after Leave
	var leave_svc := _service()
	var leave_state := leave_svc.read_state()
	var left := leave_svc.leave(NODE, leave_state)
	_check(bool(left["ok"]) and not bool(left["state"]["open"]), "leave closes the visit")
	var closed_snap := _snap(leave_svc.read_state())
	var late := leave_svc.swap("doll_1", "arms", 0, NODE, left["state"])
	_expect_refusal(leave_svc, late, "swap after leave")
	_check(str(late["error"]) == "visit is closed", "closed visit reason")
	_check(_snap(leave_svc.read_state()) == closed_snap, "closed visit state is frozen")
	var closed_quote := leave_svc.quote()
	var closed_arms: Dictionary = _slot_quote(closed_quote, "doll_1", "arms")
	_check(closed_arms["offers"].is_empty() and not bool(closed_arms["can_swap"]), "closed visit lists no offers")
	_check(closed_arms["worn"]["ability"] == _expected_ability("needle_wasp_stinger", 1), "closed visit still discloses the worn ability")
