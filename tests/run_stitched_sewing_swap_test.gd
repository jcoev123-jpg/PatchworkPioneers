extends SceneTree
## Design v4 (Stitched) Sewing Circle body-part exchange service (RunStitchedSewingSwap).
##
## Scene-free: loads the real Warden and enemy part catalogs, builds an in-memory four-hero party from
## the hero identities in data/stitched/s2_preview.json (given valid Warden gear), and drives the
## service directly. No catalog total or ordered list is asserted, only named ids.

const WARDEN_PATH := "res://data/parts/warden_parts.json"
const ENEMY_PATH := "res://data/parts/enemy_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const NODE := "sewing_circle_node_3"

var failures: Array = []
var catalog: Dictionary = {}
var identities: Array = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 4952026
	var rng_state_before := rng.state
	if _load_inputs():
		_test_opening_quote_and_deep_copy()
		_test_swaps_and_rejections()
		_test_terminal_and_closed()
		_test_roster_sizes_and_satchel_cap()
		_test_constructor_rejects()
		_test_lost_hero_cannot_swap()
		_test_lost_hero_receipts_and_variants()
		_test_direct_worn_quote_with_empty_satchel()
		_test_direct_worn_exchange()
		_test_direct_worn_rejections()
	_check(rng.state == rng_state_before, "seeded RNG state must be unchanged")
	if failures.is_empty():
		print("run_stitched_sewing_swap_test: PASS")
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
	var warden := StitchedParts.load_catalog(WARDEN_PATH)
	var enemy := StitchedParts.load_catalog(ENEMY_PATH)
	_check(bool(warden["ok"]), "warden catalog loads: " + str(warden["error"]))
	_check(bool(enemy["ok"]), "enemy catalog loads: " + str(enemy["error"]))
	if not bool(warden["ok"]) or not bool(enemy["ok"]):
		return false
	catalog = warden["by_id"].duplicate(true)
	for id in enemy["by_id"]:
		_check(not catalog.has(id), "catalogs do not overlap: " + str(id))
		catalog[id] = enemy["by_id"][id]
	for id in ["warden_arms_shield_catch", "warden_legs_rim_toss", "scissor_crab_claw_arm", "moth_swarm_wings", "felt_bulwark_button_shield"]:
		_check(catalog.has(id), "catalog has " + id)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	_check(parsed is Dictionary and parsed.get("heroes") is Array, "preview fixture parses")
	if not parsed is Dictionary or not parsed.get("heroes") is Array:
		return false
	identities = parsed["heroes"].duplicate(true)
	_check(identities.size() == 4, "preview has four heroes")
	return identities.size() == 4 and catalog.has("moth_swarm_wings")


func _worn(id: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn}


func _spare(id: String, slot: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn, "slot": slot}


## Four run heroes: preview identities plus run fields and Warden gear (ids repeat across heroes).
func _party() -> Array:
	var gear := [
		{"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch"), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_rim_toss")},
		{"head": _worn("warden_head_helmet_rattle"), "arms": _worn("warden_arms_rivet_pummel"), "torso": _worn("warden_torso_buckle_rebound"), "legs": _worn("warden_legs_shield_toss")},
		{"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch", 1, true), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_shield_toss")},
		{"head": _worn("warden_head_helmet_rattle"), "arms": _worn("warden_arms_rivet_pummel"), "torso": _worn("warden_torso_buckle_rebound"), "legs": _worn("warden_legs_rim_toss")},
	]
	var heroes: Array = []
	for index in range(identities.size()):
		var hero: Dictionary = identities[index].duplicate(true)
		hero["parts"] = gear[index]
		hero["hp"] = 10 + index
		hero["fray"] = 3 * index
		hero["statuses"] = {"weak": index}
		hero["rank"] = index + 1
		heroes.append(hero)
	return heroes


func _satchel() -> Array:
	return [
		_spare("scissor_crab_claw_arm", "arms", 2),
		_spare("moth_swarm_wings", "legs", 3),
		_spare("felt_bulwark_button_shield", "torso", 1),
		_spare("warden_head_helmet_rattle", "head", 1, true),
	]


func _service(heroes: Array = [], satchel: Array = [], node: String = NODE) -> RunStitchedSewingSwap:
	if heroes.is_empty():
		heroes = _party()
	if satchel.is_empty():
		satchel = _satchel()
	return RunStitchedSewingSwap.new(node, heroes, satchel, catalog)


func _test_opening_quote_and_deep_copy() -> void:
	var heroes := _party()
	var satchel := _satchel()
	var svc := RunStitchedSewingSwap.new(NODE, heroes, satchel, catalog)
	var state := svc.read_state()
	_check(bool(state["ok"]) and bool(state["open"]) and str(state["node_id"]) == NODE, "opening state is open at the node")
	_check(state["heroes"].size() == 4 and state["satchel"].size() == 4, "opening state holds the party and satchel")
	# Input and returned copies are detached from the service.
	var before := _snap(state)
	heroes[0]["parts"]["arms"]["id"] = "scissor_crab_claw_arm"
	heroes[0]["hp"] = 999
	satchel[0]["tier"] = 1
	satchel.clear()
	_check(_snap(svc.read_state()) == before, "constructor deep-copies its input")
	var read := svc.read_state()
	read["heroes"][1]["parts"]["head"]["id"] = "moth_swarm_wings"
	read["satchel"].clear()
	_check(_snap(svc.read_state()) == before, "read_state returns a deep copy")
	var quote := svc.quote()
	_check(bool(quote["ok"]) and bool(quote["open"]), "opening quote is open")
	for forbidden in ["cards", "energy", "deck", "hand", "gold", "scrap"]:
		_check(not quote.has(forbidden), "quote has no " + forbidden)
	_check(quote["satchel_max"] == 6 and quote["satchel_count"] == 4, "quote reports satchel cap and count")
	var warden_quote: Dictionary = quote["heroes"][0]
	_check(str(warden_quote["hero_id"]) == "warden" and warden_quote["slots"].size() == 4, "quote lists warden with four slots")
	var arms_quote: Dictionary = warden_quote["slots"][1]
	_check(str(arms_quote["slot"]) == "arms" and str(arms_quote["worn"]["id"]) == "warden_arms_shield_catch", "quote shows the worn arms part")
	_check(arms_quote["can_swap"] and arms_quote["offers"].size() == 1, "arms has exactly one compatible spare")
	_check(int(arms_quote["offers"][0]["satchel_index"]) == 0 and str(arms_quote["offers"][0]["part"]["id"]) == "scissor_crab_claw_arm", "arms offer is the tier-II claw at index 0")
	_check(int(arms_quote["offers"][0]["part"]["tier"]) == 2 and arms_quote["offers"][0]["part"]["stat"] == {"dmg": 1}, "offer shows tier and slot stat")
	var tinker_arms: Dictionary = quote["heroes"][2]["slots"][1]
	_check(not tinker_arms["can_swap"] and tinker_arms["offers"].is_empty() and not str(tinker_arms["blocked"]).is_empty(), "torn worn arms is blocked in the quote")
	_check(bool(quote["state"]["ok"]) and _snap(quote["state"]) == before, "quote carries the authoritative state")


func _expect_reject(svc: RunStitchedSewingSwap, label: String, result: Dictionary) -> void:
	_check(not bool(result.get("ok", true)) and not str(result.get("error", "")).is_empty(), label + ": fails with an error")


func _test_swaps_and_rejections() -> void:
	var svc := _service()
	var state := svc.read_state()
	var snap := _snap(state)
	var stale := state.duplicate(true)
	stale["version"] = int(stale["version"]) + 1
	var forged := state.duplicate(true)
	forged["heroes"][0]["hp"] = 1
	var forged_part := state.duplicate(true)
	forged_part["satchel"][0]["tier"] = 3
	var bad_calls := {
		"wrong node": svc.swap("warden", "arms", 0, "other_node", state),
		"non-string node": svc.swap("warden", "arms", 0, 7, state),
		"stale state": svc.swap("warden", "arms", 0, NODE, stale),
		"forged hero": svc.swap("warden", "arms", 0, NODE, forged),
		"forged satchel": svc.swap("warden", "arms", 0, NODE, forged_part),
		"null state": svc.swap("warden", "arms", 0, NODE, null),
		"array state": svc.swap("warden", "arms", 0, NODE, []),
		"empty state": svc.swap("warden", "arms", 0, NODE, {}),
		"unknown hero": svc.swap("ghost", "arms", 0, NODE, state),
		"non-string hero": svc.swap(3, "arms", 0, NODE, state),
		"unknown slot": svc.swap("warden", "wings", 0, NODE, state),
		"non-string slot": svc.swap("warden", 1, 0, NODE, state),
		"negative index": svc.swap("warden", "arms", -1, NODE, state),
		"high index": svc.swap("warden", "arms", 4, NODE, state),
		"float index": svc.swap("warden", "arms", 0.0, NODE, state),
		"string index": svc.swap("warden", "arms", "0", NODE, state),
		"null index": svc.swap("warden", "arms", null, NODE, state),
		"wrong-slot spare (legs wings into arms)": svc.swap("warden", "arms", 1, NODE, state),
		"wrong-slot spare (arms claw into legs)": svc.swap("warden", "legs", 0, NODE, state),
		"unoffered torso into head": svc.swap("warden", "head", 2, NODE, state),
		"torn worn arms": svc.swap("tinker", "arms", 0, NODE, state),
		"leave wrong node": svc.leave("other_node", state),
		"leave stale": svc.leave(NODE, stale),
		"leave forged": svc.leave(NODE, forged),
	}
	for label in bad_calls:
		_expect_reject(svc, str(label), bad_calls[label])
	_check(_snap(svc.read_state()) == snap, "every rejected call left the state unchanged")
	_check(bool(svc.read_state()["open"]), "rejections do not close the visit")

	# Swap 1: Warden ARMS <-> tier-II scissor claw (enemy, owner any).
	var arms_def: Dictionary = catalog["scissor_crab_claw_arm"]
	_check(str(arms_def["owner"]) == "any" and str(arms_def["slot"]) == "arms" and str(catalog["warden_arms_shield_catch"]["slot"]) == "arms", "both arms parts are arms in the real catalog")
	var r1 := svc.swap("warden", "arms", 0, NODE, state)
	_check(bool(r1["ok"]) and str(r1["action"]) == "swap", "swap 1 succeeds")
	var expected1 := state.duplicate(true)
	expected1["version"] = 1
	expected1["heroes"][0]["parts"]["arms"] = _worn("scissor_crab_claw_arm", 2)
	expected1["satchel"][0] = _spare("warden_arms_shield_catch", "arms", 1)
	_check(_snap(r1["state"]) == _snap(expected1), "swap 1 exact new state (only warden arms and satchel[0])")
	_check(_snap(svc.read_state()) == _snap(expected1), "swap 1 read_state matches the receipt state")
	_check(_snap(r1["source_state"]) == snap, "receipt carries the source snapshot")
	_check(r1["worn_before"] == _worn("warden_arms_shield_catch") and r1["worn_after"] == _worn("scissor_crab_claw_arm", 2), "swap 1 worn before/after")
	_check(r1["satchel_before"] == _spare("scissor_crab_claw_arm", "arms", 2) and r1["satchel_after"] == _spare("warden_arms_shield_catch", "arms", 1), "swap 1 satchel before/after")
	_check(r1["changed_heroes"].size() == 1 and _snap(r1["changed_heroes"][0]) == _snap(expected1["heroes"][0]), "swap 1 changed hero is the complete warden record")
	_check(_snap(r1["satchel"]) == _snap(expected1["satchel"]) and r1["satchel"].size() == 4, "swap 1 receipt satchel and unchanged count")
	_check(not r1["changed_heroes"][0]["parts"]["arms"].has("slot") and r1["satchel"][0]["slot"] == "arms", "worn shape has no slot, satchel shape has it")
	_check(r1["changed_heroes"][0]["hp"] == 10 and r1["changed_heroes"][0]["statuses"] == {"weak": 0}, "other hero fields preserved")
	var ids_before: Array = _instance_ids(state)
	var ids_after: Array = _instance_ids(r1["state"])
	_check(ids_before == ids_after, "no part instance was created or lost by swap 1")

	# Replay and stale reuse fail without effect; the new state still works.
	var after1 := _snap(svc.read_state())
	_expect_reject(svc, "replay with old snapshot", svc.swap("warden", "arms", 0, NODE, state))
	_expect_reject(svc, "replay of source_state", svc.swap("warden", "arms", 0, NODE, r1["source_state"]))
	_expect_reject(svc, "leave with old snapshot", svc.leave(NODE, state))
	_expect_reject(svc, "torn arms still blocked", svc.swap("tinker", "arms", 0, NODE, r1["state"]))
	_expect_reject(svc, "wrong slot on new state", svc.swap("warden", "arms", 1, NODE, r1["state"]))
	_check(_snap(svc.read_state()) == after1, "rejected replays left the state unchanged")

	# Swap 2: Warden LEGS <-> tier-III moth wings, same visit, on the advanced snapshot.
	var r2 := svc.swap("warden", "legs", 1, NODE, r1["state"])
	_check(bool(r2["ok"]), "swap 2 succeeds in the same visit")
	var expected2: Dictionary = expected1.duplicate(true)
	expected2["version"] = 2
	expected2["heroes"][0]["parts"]["legs"] = _worn("moth_swarm_wings", 3)
	expected2["satchel"][1] = _spare("warden_legs_rim_toss", "legs", 1)
	_check(_snap(r2["state"]) == _snap(expected2), "swap 2 exact new state")
	_check(_snap(r2["source_state"]) == _snap(expected1), "swap 2 source snapshot is the post-swap-1 state")
	_check(str(catalog["moth_swarm_wings"]["slot"]) == "legs" and str(catalog["warden_legs_rim_toss"]["slot"]) == "legs", "both legs parts are legs in the real catalog")
	_check(StitchedParts.stat_at_tier(catalog["moth_swarm_wings"], 3) == {"dodge": 10}, "tier-III wings are a real tier-III stat")
	_check(_instance_ids(r2["state"]) == ids_before, "no instance duplicated after two swaps")

	# A foreign-owner part is wearable by slot: a Warden-owned helm on the Seamstress.
	var r3 := svc.swap("seamstress", "head", 3, NODE, r2["state"])
	_check(bool(r3["ok"]), "torn spare may be worn (slot, not owner or torn state, gates wearing)")
	if bool(r3["ok"]):
		_check(str(r3["changed_heroes"][0]["id"]) == "seamstress" and r3["changed_heroes"][0]["parts"]["head"] == _worn("warden_head_helmet_rattle", 1, true), "torn flag travels with the physical part")
		_check(r3["satchel"][3] == _spare("warden_head_helmet_rattle", "head", 1, false), "replaced head took the same satchel position")
		_check(_instance_ids(r3["state"]) == ids_before, "no instance duplicated after three swaps")
	# Leave publishes no changes.
	var final_state := svc.read_state()
	var left := svc.leave(NODE, final_state)
	_check(bool(left["ok"]) and str(left["action"]) == "leave" and left["changed_heroes"].is_empty(), "leave succeeds with no changed heroes")
	_check(_snap(left["source_state"]) == _snap(final_state), "leave receipt carries the source snapshot")
	_check(_snap(left["state"]["heroes"]) == _snap(final_state["heroes"]) and _snap(left["state"]["satchel"]) == _snap(final_state["satchel"]) and not bool(left["state"]["open"]), "leave changes no equipment and closes the visit")


func _instance_ids(state: Dictionary) -> Array:
	var ids: Array = []
	for hero in state["heroes"]:
		for slot in StitchedParts.SLOTS:
			ids.append("%s|%d|%s" % [hero["parts"][slot]["id"], hero["parts"][slot]["tier"], hero["parts"][slot]["torn"]])
	for spare in state["satchel"]:
		ids.append("%s|%d|%s" % [spare["id"], spare["tier"], spare["torn"]])
	ids.sort()
	return ids


func _test_terminal_and_closed() -> void:
	var svc := _service()
	var state := svc.read_state()
	var left := svc.leave(NODE, state)
	_check(bool(left["ok"]), "leave on a fresh visit succeeds")
	var closed := svc.read_state()
	_check(bool(closed["ok"]) and not bool(closed["open"]), "state is closed after leave")
	_check(_snap(closed["heroes"]) == _snap(state["heroes"]) and _snap(closed["satchel"]) == _snap(state["satchel"]), "leave left heroes and satchel untouched")
	var terminal := svc.quote()
	_check(bool(terminal["ok"]) and not bool(terminal["open"]), "terminal quote reports a closed visit")
	var offers := 0
	var swappable := 0
	for hero in terminal["heroes"]:
		for slot in hero["slots"]:
			offers += slot["offers"].size()
			if slot["can_swap"]:
				swappable += 1
	_check(offers == 0 and swappable == 0 and terminal["heroes"].size() == 4, "terminal quote offers nothing")
	var snap := _snap(svc.read_state())
	_expect_reject(svc, "swap after leave", svc.swap("warden", "arms", 0, NODE, closed))
	_expect_reject(svc, "swap after leave with pre-leave state", svc.swap("warden", "arms", 0, NODE, state))
	_expect_reject(svc, "second leave", svc.leave(NODE, closed))
	_check(_snap(svc.read_state()) == snap, "post-leave callbacks change nothing")


func _test_roster_sizes_and_satchel_cap() -> void:
	for size in range(1, 5):
		var heroes := _party().slice(0, size)
		var svc := _service(heroes)
		var state := svc.read_state()
		_check(bool(state["ok"]) and state["heroes"].size() == size, "roster of %d heroes is accepted" % size)
		var last_id := str(heroes[size - 1]["id"])
		var result := svc.swap(last_id, "torso", 2, NODE, state)
		_check(bool(result["ok"]), "swap works for the surviving hero in a roster of %d" % size)
		if bool(result["ok"]):
			var expected := state.duplicate(true)
			expected["version"] = 1
			expected["heroes"][size - 1]["parts"]["torso"] = _worn("felt_bulwark_button_shield")
			expected["satchel"][2] = _spare(str(heroes[size - 1]["parts"]["torso"]["id"]), "torso", 1)
			_check(_snap(result["state"]) == _snap(expected), "exact receipt state for a roster of %d" % size)
		var missing := svc.swap("lantern_monk" if size < 4 else "ghost", "torso", 2, NODE, svc.read_state())
		_check(not bool(missing["ok"]), "an absent hero cannot swap in a roster of %d" % size)
	_check(bool(_service(_party().slice(0, 1)).read_state()["ok"]), "single-hero roster is valid")
	var dead := RunStitchedSewingSwap.new(NODE, [], _satchel(), catalog)
	_check(not bool(dead.read_state()["ok"]), "an empty roster is rejected")
	var five := _party()
	var extra: Dictionary = five[0].duplicate(true)
	extra["id"] = "fifth"
	five.append(extra)
	_check(not bool(RunStitchedSewingSwap.new(NODE, five, _satchel(), catalog).read_state()["ok"]), "five heroes are rejected")
	var dupes := _party().slice(0, 2)
	dupes[1]["id"] = dupes[0]["id"]
	_check(not bool(RunStitchedSewingSwap.new(NODE, dupes, _satchel(), catalog).read_state()["ok"]), "duplicate hero ids are rejected")
	# Satchel cap: six is fine (and swaps keep it at six), seven is refused.
	var six := _satchel()
	six.append(_spare("warden_legs_shield_toss", "legs", 2))
	six.append(_spare("warden_torso_buckle_rebound", "torso", 3))
	var full := _service(_party(), six)
	var full_state := full.read_state()
	_check(bool(full_state["ok"]) and full_state["satchel"].size() == 6, "six spares are accepted")
	_check(full.quote()["satchel_count"] == 6, "full satchel quote counts six")
	var full_result := full.swap("warden", "legs", 4, NODE, full_state)
	_check(bool(full_result["ok"]) and full_result["state"]["satchel"].size() == 6, "swap in a full satchel keeps six spares")
	if bool(full_result["ok"]):
		_check(full_result["satchel"][4] == _spare("warden_legs_rim_toss", "legs", 1) and full_result["changed_heroes"][0]["parts"]["legs"] == _worn("warden_legs_shield_toss", 2), "full-satchel swap uses that position")
	var seven := six.duplicate(true)
	seven.append(_spare("warden_head_pot_helm_bonk", "head"))
	var over := RunStitchedSewingSwap.new(NODE, _party(), seven, catalog)
	_check(not bool(over.read_state()["ok"]), "seven spares are rejected")
	_expect_reject(over, "unusable visit swap", over.swap("warden", "arms", 0, NODE, over.read_state()))
	_expect_reject(over, "unusable visit leave", over.leave(NODE, over.read_state()))


func _test_constructor_rejects() -> void:
	var unknown_worn := _party()
	unknown_worn[0]["parts"]["arms"]["id"] = "no_such_part"
	var bad_tier_high := _party()
	bad_tier_high[0]["parts"]["arms"]["tier"] = 4
	var bad_tier_zero := _party()
	bad_tier_zero[1]["parts"]["head"]["tier"] = 0
	var bad_tier_text := _party()
	bad_tier_text[1]["parts"]["head"]["tier"] = "2"
	var wrong_slot := _party()
	wrong_slot[2]["parts"]["legs"] = _worn("scissor_crab_claw_arm")
	var no_torn := _party()
	no_torn[3]["parts"]["torso"].erase("torn")
	var missing_slot := _party()
	missing_slot[0]["parts"].erase("legs")
	var extra_slot := _party()
	extra_slot[0]["parts"]["tail"] = _worn("moth_swarm_wings")
	var bad_rosters := {"unknown worn id": unknown_worn, "tier 4": bad_tier_high, "tier 0": bad_tier_zero, "text tier": bad_tier_text, "wrong-slot worn": wrong_slot, "missing torn flag": no_torn, "missing slot": missing_slot, "extra slot": extra_slot}
	for label in bad_rosters:
		var bad := RunStitchedSewingSwap.new(NODE, bad_rosters[label], _satchel(), catalog)
		_check(not bool(bad.read_state()["ok"]), "constructor rejects: " + str(label))
		_check(not bool(bad.quote()["ok"]), "quote of an invalid visit fails: " + str(label))
	var bad_spares := {
		"unknown spare id": [_spare("no_such_part", "arms")],
		"spare slot mismatch with catalog": [_spare("moth_swarm_wings", "arms")],
		"spare unknown slot": [_spare("moth_swarm_wings", "tail")],
		"spare tier 4": [_spare("moth_swarm_wings", "legs", 4)],
		"spare missing slot": [{"id": "moth_swarm_wings", "tier": 1, "torn": false}],
		"spare non-bool torn": [{"id": "moth_swarm_wings", "tier": 1, "torn": 0, "slot": "legs"}],
	}
	for label in bad_spares:
		var svc := RunStitchedSewingSwap.new(NODE, _party(), bad_spares[label], catalog)
		_check(not bool(svc.read_state()["ok"]), "constructor rejects: " + str(label))
	_check(not bool(RunStitchedSewingSwap.new("", _party(), _satchel(), catalog).read_state()["ok"]), "empty node id is rejected")
	_check(not bool(RunStitchedSewingSwap.new(NODE, _party(), _satchel(), {}).read_state()["ok"]), "empty catalog is rejected")
	# An empty satchel is a legal visit with nothing to swap.
	var empty := RunStitchedSewingSwap.new(NODE, _party(), [], catalog)
	_check(bool(empty.read_state()["ok"]) and empty.read_state()["satchel"].is_empty(), "empty satchel is accepted")
	_expect_reject(empty, "swap from an empty satchel", empty.swap("warden", "arms", 0, NODE, empty.read_state()))


func _test_lost_hero_receipts_and_variants() -> void:
	var heroes := _party()
	heroes[0]["lost"] = true
	heroes[1]["lost"] = false
	var svc := _service(heroes)
	var state := svc.read_state()
	var snap := _snap(state)
	_check(bool(state["ok"]) and state["heroes"][0]["lost"] == true, "lost flag survives into the service state")
	var quote := svc.quote()
	var warden_slots: Array = quote["heroes"][0]["slots"]
	_check(warden_slots.size() == 4, "lost warden still lists four slots")
	for slot_quote in warden_slots:
		_check(not bool(slot_quote["can_swap"]) and str(slot_quote["blocked"]) == "hero is lost" and slot_quote["offers"].is_empty(), "lost warden %s slot is blocked with no offers" % str(slot_quote["slot"]))
	_check(quote["satchel_count"] == 4 and quote["satchel"].size() == 4, "satchel summary stays visible for a lost hero")
	var seamstress_slots: Array = quote["heroes"][1]["slots"]
	var swappable := 0
	for slot_quote in seamstress_slots:
		if bool(slot_quote["can_swap"]):
			swappable += 1
			_check(str(slot_quote["blocked"]).is_empty() and slot_quote["offers"].size() == 1, "active seamstress %s keeps its compatible spare" % str(slot_quote["slot"]))
	_check(swappable == 4, "active seamstress quotes all four slots as swappable")

	# A LOST hero's matching-slot swap is refused before any mutation.
	var lost_result := svc.swap("warden", "arms", 0, NODE, state)
	_check(not bool(lost_result["ok"]) and str(lost_result["error"]).contains("lost"), "lost warden arms swap is refused as lost")
	_check(str(lost_result["error"]) == "hero is lost", "lost refusal message")
	for slot_name in StitchedParts.SLOTS:
		var index := {"head": 3, "arms": 0, "torso": 2, "legs": 1}[slot_name] as int
		var refused := svc.swap("warden", slot_name, index, NODE, svc.read_state())
		_check(not bool(refused["ok"]) and str(refused["error"]) == "hero is lost", "lost warden %s swap is refused" % slot_name)
	_check(_snap(svc.read_state()) == snap, "refused lost swaps leave the complete state unchanged")
	_check(bool(svc.read_state()["open"]), "refused lost swap does not close the visit")

	# The living Seamstress can still swap torso <-> felt bulwark in the same unchanged visit.
	var result := svc.swap("seamstress", "torso", 2, NODE, state)
	_check(bool(result["ok"]), "active seamstress swaps in the same visit as a lost warden")
	if bool(result["ok"]):
		var expected := state.duplicate(true)
		expected["version"] = int(state["version"]) + 1
		expected["heroes"][1]["parts"]["torso"] = _worn("felt_bulwark_button_shield")
		expected["satchel"][2] = _spare("warden_torso_buckle_rebound", "torso", 1)
		_check(_snap(result["state"]) == _snap(expected), "exactly one worn part and its satchel slot changed")
		_check(_snap(result["state"]["heroes"][0]) == _snap(state["heroes"][0]) and _snap(result["state"]["heroes"][2]) == _snap(state["heroes"][2]) and _snap(result["state"]["heroes"][3]) == _snap(state["heroes"][3]), "other heroes are unchanged")
		_check(result["state"]["heroes"][0]["lost"] == true, "lost flag still set after the active swap")
		_check(_instance_ids(result["state"]) == _instance_ids(state), "no part instance created or lost")
		_check(result["changed_heroes"].size() == 1 and str(result["changed_heroes"][0]["id"]) == "seamstress", "only the seamstress is reported changed")
		for forbidden in ["gold", "scrap", "fee", "cost", "rng"]:
			_check(not result.has(forbidden), "swap receipt has no " + forbidden)
		var again := svc.swap("warden", "arms", 0, NODE, result["state"])
		_check(not bool(again["ok"]) and str(again["error"]) == "hero is lost", "lost warden is still refused after the active swap")
		var left := svc.leave(NODE, svc.read_state())
		_check(bool(left["ok"]) and not bool(left["state"]["open"]) and left["changed_heroes"].is_empty(), "free leave closes the visit")
		_expect_reject(svc, "swap after leave", svc.swap("seamstress", "arms", 0, NODE, left["state"]))
		_expect_reject(svc, "second leave", svc.leave(NODE, left["state"]))
		var closed_quote := svc.quote()
		_check(not bool(closed_quote["open"]), "closed visit quote reports closed")

	# Active variants: lost=false and an absent lost field give the Warden normal access.
	for variant in ["false", "absent", "hanging"]:
		var party := _party()
		if variant == "false":
			party[0]["lost"] = false
		elif variant == "hanging":
			party[0]["hp"] = 0
			party[0]["hanging"] = true
		var vsvc := _service(party)
		var vstate := vsvc.read_state()
		var arms_quote: Dictionary = vsvc.quote()["heroes"][0]["slots"][1]
		_check(bool(arms_quote["can_swap"]) and arms_quote["offers"].size() == 1 and str(arms_quote["blocked"]).is_empty(), "%s warden arms quote offers the claw" % variant)
		var vresult := vsvc.swap("warden", "arms", 0, NODE, vstate)
		_check(bool(vresult["ok"]) and vresult["changed_heroes"][0]["parts"]["arms"] == _worn("scissor_crab_claw_arm", 2), "%s warden can swap arms" % variant)
	# Non-boolean lost values are not LOST (native boolean true only).
	var odd := _party()
	odd[0]["lost"] = "true"
	var odd_svc := _service(odd)
	_check(bool(odd_svc.quote()["heroes"][0]["slots"][1]["can_swap"]), "string lost value is not treated as LOST")


## Four heroes with distinct arms (warden shield catch I, seamstress scissor claw II, tinker torn shield
## catch, fourth hero rivet pummel I) from the real catalogs.
func _direct_party() -> Array:
	var heroes := _party()
	heroes[1]["parts"]["arms"] = _worn("scissor_crab_claw_arm", 2)
	return heroes


func _is_lost_flag(hero: Dictionary) -> bool:
	return typeof(hero.get("lost")) == TYPE_BOOL and bool(hero["lost"])


## Independent oracle for the quoted direct offers: other, non-LOST heroes whose same-slot part is
## untorn, in roster order; nothing when the asking hero is LOST or its own part is torn.
func _expected_worn_offer_ids(heroes: Array, hero_index: int, slot: String) -> Array:
	var out: Array = []
	var me: Dictionary = heroes[hero_index]
	if _is_lost_flag(me) or bool(me["parts"][slot]["torn"]):
		return out
	for index in range(heroes.size()):
		if index == hero_index:
			continue
		var other: Dictionary = heroes[index]
		if _is_lost_flag(other) or bool(other["parts"][slot]["torn"]):
			continue
		out.append(str(other["id"]))
	return out


func _expected_stat_delta(worn_id: String, worn_tier: int, incoming_id: String, incoming_tier: int) -> Dictionary:
	var worn_stat: Dictionary = StitchedParts.stat_at_tier(catalog[worn_id], worn_tier)
	var incoming_stat: Dictionary = StitchedParts.stat_at_tier(catalog[incoming_id], incoming_tier)
	var keys: Dictionary = {}
	for key in worn_stat:
		keys[key] = true
	for key in incoming_stat:
		keys[key] = true
	var delta: Dictionary = {}
	for key in keys:
		var change := int(incoming_stat.get(key, 0)) - int(worn_stat.get(key, 0))
		if change != 0:
			delta[str(key)] = change
	return delta


func _check_direct_offer(offer: Dictionary, worn_id: String, worn_tier: int, incoming_id: String, incoming_tier: int, label: String) -> void:
	var worn_entry: Dictionary = catalog[worn_id]
	var incoming_entry: Dictionary = catalog[incoming_id]
	var part: Dictionary = offer["part"]
	_check(str(part["id"]) == incoming_id and int(part["tier"]) == incoming_tier and not bool(part["torn"]) and str(part["name"]) == str(incoming_entry["name"]), label + ": incoming part identity, tier and name")
	_check(part["stat"] == StitchedParts.stat_at_tier(incoming_entry, incoming_tier), label + ": incoming stat is the real tier stat")
	_check(part["ability"] == StitchedParts.ability_at_tier(incoming_entry, incoming_tier), label + ": incoming ability is the real tier ability")
	var comparison: Dictionary = offer["comparison"]
	var before: Dictionary = StitchedParts.ability_at_tier(worn_entry, worn_tier)
	var after: Dictionary = StitchedParts.ability_at_tier(incoming_entry, incoming_tier)
	_check(not before.is_empty() and not after.is_empty(), label + ": both real abilities resolve")
	for field in ["name", "launch", "target", "target_side", "dmg", "acc", "crit", "effects", "self_move"]:
		if before.has(field):
			_check(comparison["ability_before"].get(field) == before[field], label + ": ability_before " + field)
		if after.has(field):
			_check(comparison["ability_after"].get(field) == after[field], label + ": ability_after " + field)
	_check(comparison["stat_delta"] == _expected_stat_delta(worn_id, worn_tier, incoming_id, incoming_tier), label + ": signed stat delta from real projections")


func _test_direct_worn_quote_with_empty_satchel() -> void:
	var heroes := _direct_party()
	var ids: Array = []
	for hero in heroes:
		ids.append(str(hero["id"]))
	var svc := RunStitchedSewingSwap.new(NODE, heroes, [], catalog)
	var state := svc.read_state()
	_check(bool(state["ok"]) and state["satchel"].is_empty() and state["heroes"].size() == 4, "direct fixture: four heroes and an empty satchel")
	_check(str(catalog["warden_arms_shield_catch"]["slot"]) == "arms" and str(catalog["scissor_crab_claw_arm"]["slot"]) == "arms" and str(catalog["warden_arms_rivet_pummel"]["slot"]) == "arms", "direct fixture: all three arms parts are real arms parts")
	var quote := svc.quote()
	_check(bool(quote["ok"]) and quote["satchel_count"] == 0 and quote["satchel"].is_empty(), "direct quote: empty satchel")
	_check(_snap(quote["state"]) == _snap(state), "direct quote carries the authoritative state")
	var warden_arms: Dictionary = quote["heroes"][0]["slots"][1]
	_check(str(warden_arms["slot"]) == "arms" and str(warden_arms["worn"]["id"]) == "warden_arms_shield_catch", "direct quote: warden arms worn part")
	_check(warden_arms["offers"].is_empty() and str(warden_arms["blocked"]).is_empty() and bool(warden_arms["can_swap"]), "empty satchel: no satchel offers but can_swap through direct offers")
	var offers: Array = warden_arms["worn_offers"]
	_check(offers.size() == 2, "warden arms has two direct offers (torn tinker hidden)")
	if offers.size() == 2:
		_check(str(offers[0]["hero_id"]) == ids[1] and str(offers[1]["hero_id"]) == ids[3], "direct offers follow roster order and hide the torn tinker and self")
		_check_direct_offer(offers[0], "warden_arms_shield_catch", 1, "scissor_crab_claw_arm", 2, "warden<-seamstress")
		_check_direct_offer(offers[1], "warden_arms_shield_catch", 1, "warden_arms_rivet_pummel", 1, "warden<-fourth")
	var seamstress_offers: Array = quote["heroes"][1]["slots"][1]["worn_offers"]
	_check(seamstress_offers.size() == 2, "seamstress arms has two direct offers")
	if seamstress_offers.size() == 2:
		_check(str(seamstress_offers[0]["hero_id"]) == ids[0] and str(seamstress_offers[1]["hero_id"]) == ids[3], "seamstress offers: warden then fourth hero")
		_check_direct_offer(seamstress_offers[0], "scissor_crab_claw_arm", 2, "warden_arms_shield_catch", 1, "seamstress<-warden")
	var tinker_arms: Dictionary = quote["heroes"][2]["slots"][1]
	_check(not bool(tinker_arms["can_swap"]) and tinker_arms["worn_offers"].is_empty() and tinker_arms["offers"].is_empty() and not str(tinker_arms["blocked"]).is_empty(), "torn tinker arms: blocked with no offers of either kind")

	# Every slot of every hero matches the independent oracle, for a plain and a LOST-variant roster.
	var lost_heroes := _direct_party()
	lost_heroes[3]["lost"] = true
	for roster in [heroes, lost_heroes]:
		var rsvc := RunStitchedSewingSwap.new(NODE, roster, [], catalog)
		var rquote := rsvc.quote()
		var total := 0
		for hero_index in range(roster.size()):
			for slot_index in range(StitchedParts.SLOTS.size()):
				var slot: String = StitchedParts.SLOTS[slot_index]
				var slot_quote: Dictionary = rquote["heroes"][hero_index]["slots"][slot_index]
				var expected_ids := _expected_worn_offer_ids(roster, hero_index, slot)
				var got_ids: Array = []
				for offer in slot_quote["worn_offers"]:
					got_ids.append(str(offer["hero_id"]))
					_check(str(offer["part"]["slot"]) == slot and str(offer["hero_id"]) != str(roster[hero_index]["id"]), "direct offer is same-slot and never self")
				total += got_ids.size()
				_check(got_ids == expected_ids, "direct offers match the oracle for hero %d slot %s" % [hero_index, slot])
				_check(bool(slot_quote["can_swap"]) == (not expected_ids.is_empty()), "can_swap equals direct availability with an empty satchel (hero %d %s)" % [hero_index, slot])
		_check(total > 0, "oracle comparison is not vacuous")
	var lost_quote := RunStitchedSewingSwap.new(NODE, lost_heroes, [], catalog).quote()
	_check(str(lost_quote["heroes"][3]["slots"][1]["blocked"]) == "hero is lost" and lost_quote["heroes"][3]["slots"][1]["worn_offers"].is_empty(), "a LOST hero gets no direct offers")
	var lost_ids: Array = []
	for offer in lost_quote["heroes"][0]["slots"][1]["worn_offers"]:
		lost_ids.append(str(offer["hero_id"]))
	_check(lost_ids == [ids[1]], "a LOST hero is hidden from others' direct offers")

	# With spares present the satchel offers keep their old shape and direct offers appear beside them.
	var full := RunStitchedSewingSwap.new(NODE, _direct_party(), _satchel(), catalog).quote()
	var full_arms: Dictionary = full["heroes"][0]["slots"][1]
	_check(full_arms["offers"].size() == 1 and int(full_arms["offers"][0]["satchel_index"]) == 0 and str(full_arms["offers"][0]["part"]["id"]) == "scissor_crab_claw_arm", "satchel offers are preserved unchanged")
	_check(full_arms["worn_offers"].size() == 2 and bool(full_arms["can_swap"]), "direct offers coexist with satchel offers")

	# The quote is a detached copy and a closed visit lists no direct offers.
	var detached := svc.quote()
	detached["heroes"][0]["slots"][1]["worn_offers"].clear()
	_check(svc.quote()["heroes"][0]["slots"][1]["worn_offers"].size() == 2, "quote worn_offers are detached copies")
	var closing := svc.leave(NODE, state)
	_check(bool(closing["ok"]), "leave closes the direct fixture visit")
	var closed := svc.quote()
	var closed_direct := 0
	var closed_swappable := 0
	for hero_quote in closed["heroes"]:
		for slot_quote in hero_quote["slots"]:
			closed_direct += slot_quote["worn_offers"].size()
			if bool(slot_quote["can_swap"]):
				closed_swappable += 1
	_check(closed["heroes"].size() == 4 and closed_direct == 0 and closed_swappable == 0, "closed visit lists no direct offers")


func _test_direct_worn_exchange() -> void:
	seed(777)
	var expected_next := randi()
	seed(777)
	var heroes := _direct_party()
	var ids: Array = []
	for hero in heroes:
		ids.append(str(hero["id"]))
	var svc := RunStitchedSewingSwap.new(NODE, heroes, [], catalog)
	var state := svc.read_state()
	var snap := _snap(state)
	var result := svc.exchange_worn(ids[0], ids[1], "arms", NODE, state)
	_check(bool(result["ok"]) and str(result["action"]) == "exchange_worn" and str(result["error"]).is_empty(), "direct exchange succeeds at the exact snapshot")
	if not bool(result["ok"]):
		return
	var original_a := _worn("warden_arms_shield_catch", 1)
	var original_b := _worn("scissor_crab_claw_arm", 2)
	var expected := state.duplicate(true)
	expected["version"] = 1
	expected["heroes"][0]["parts"]["arms"] = original_b
	expected["heroes"][1]["parts"]["arms"] = original_a
	_check(_snap(result["state"]) == _snap(expected), "only the two arms records traded; everything else, satchel included, is equal")
	_check(_snap(svc.read_state()) == _snap(expected), "read_state matches the receipt state")
	_check(int(result["state"]["version"]) == int(state["version"]) + 1, "version advanced exactly once")
	_check(result["state"]["satchel"].is_empty() and result["satchel"].is_empty(), "satchel length stays zero")
	_check(str(result["slot"]) == "arms" and str(result["hero_a_id"]) == ids[0] and str(result["hero_b_id"]) == ids[1] and str(result["node_id"]) == NODE, "receipt names slot, both wearers and node")
	_check(result["worn_before"][ids[0]] == original_a and result["worn_before"][ids[1]] == original_b, "receipt worn_before records")
	_check(result["worn_after"][ids[0]] == original_b and result["worn_after"][ids[1]] == original_a, "receipt worn_after records: each original part, tier included, went to the other wearer")
	_check(_snap(result["source_state"]) == snap, "receipt carries the source snapshot")
	_check(result["changed_heroes"].size() == 2 and str(result["changed_heroes"][0]["id"]) == ids[0] and str(result["changed_heroes"][1]["id"]) == ids[1], "changed_heroes lists exactly the two wearers")
	if result["changed_heroes"].size() == 2:
		_check(_snap(result["changed_heroes"][0]) == _snap(expected["heroes"][0]) and _snap(result["changed_heroes"][1]) == _snap(expected["heroes"][1]), "changed heroes are the complete updated records")
	for index in [2, 3]:
		_check(_snap(result["state"]["heroes"][index]) == _snap(state["heroes"][index]), "uninvolved hero %d is unchanged" % index)
	for index in [0, 1]:
		var after_hero: Dictionary = result["state"]["heroes"][index]
		var before_hero: Dictionary = state["heroes"][index]
		_check(after_hero["hp"] == before_hero["hp"] and after_hero["fray"] == before_hero["fray"] and after_hero["rank"] == before_hero["rank"] and _snap(after_hero["statuses"]) == _snap(before_hero["statuses"]), "hero %d keeps HP, fray, rank and statuses" % index)
		for slot in ["head", "torso", "legs"]:
			_check(_snap(after_hero["parts"][slot]) == _snap(before_hero["parts"][slot]), "hero %d keeps its %s" % [index, slot])
	_check(_instance_ids(result["state"]) == _instance_ids(state), "no part instance created or lost")
	for forbidden in ["gold", "scrap", "fee", "cost", "rng"]:
		_check(not result.has(forbidden), "exchange receipt has no " + forbidden)

	# The receipt is detached from the service.
	result["state"]["heroes"][0]["parts"]["arms"]["id"] = "moth_swarm_wings"
	result["changed_heroes"][0]["hp"] = 999
	result["worn_after"][ids[0]]["tier"] = 3
	result["source_state"]["version"] = 42
	result["satchel"].append({})
	_check(_snap(svc.read_state()) == _snap(expected), "mutating the receipt does not touch the service")

	# Replays with the old snapshots fail; the fresh quote shows the traded parts.
	var after_snap := _snap(svc.read_state())
	_expect_reject(svc, "replay of the original snapshot", svc.exchange_worn(ids[0], ids[1], "arms", NODE, state))
	_check(_snap(svc.read_state()) == after_snap, "replay changed nothing")
	var fresh := svc.quote()
	var warden_arms: Dictionary = fresh["heroes"][0]["slots"][1]
	_check(str(warden_arms["worn"]["id"]) == "scissor_crab_claw_arm" and int(warden_arms["worn"]["tier"]) == 2, "fresh quote shows the claw on the warden")
	var back_offers: Array = warden_arms["worn_offers"]
	_check(back_offers.size() == 2 and str(back_offers[0]["hero_id"]) == ids[1], "fresh quote still offers the seamstress")
	if back_offers.size() == 2:
		_check_direct_offer(back_offers[0], "scissor_crab_claw_arm", 2, "warden_arms_shield_catch", 1, "requote warden<-seamstress")

	# Exchanging back on the fresh snapshot (given in the reverse order) restores the original gear.
	var fresh_state: Dictionary = fresh["state"]
	var back := svc.exchange_worn(ids[1], ids[0], "arms", NODE, fresh_state)
	_check(bool(back["ok"]) and int(back["state"]["version"]) == 2, "exchange back succeeds and advances the version once more")
	if bool(back["ok"]):
		var restored := state.duplicate(true)
		restored["version"] = 2
		_check(_snap(back["state"]) == _snap(restored), "exchanging back restores the original equipment")
		_check(back["changed_heroes"].size() == 2 and str(back["changed_heroes"][0]["id"]) == ids[1], "reverse-order receipt lists the wearers in argument order")
		_check(_snap(back["source_state"]) == _snap(fresh_state), "exchange back carries the fresh source snapshot")

	# A different slot between two intact wearers works in the same visit (head: pot helm <-> rattle).
	var head_state := svc.read_state()
	var head := svc.exchange_worn(ids[0], ids[1], "head", NODE, head_state)
	_check(bool(head["ok"]) and head["worn_after"][ids[0]] == _worn("warden_head_helmet_rattle") and head["worn_after"][ids[1]] == _worn("warden_head_pot_helm_bonk"), "head exchange trades the two distinct helms")
	var left := svc.leave(NODE, svc.read_state())
	_check(bool(left["ok"]), "leave works after direct exchanges")

	# No global RNG draw happened anywhere in this test.
	_check(randi() == expected_next, "the exchange consumed no random numbers")


func _test_direct_worn_rejections() -> void:
	var heroes := _direct_party()
	var ids: Array = []
	for hero in heroes:
		ids.append(str(hero["id"]))
	var svc := RunStitchedSewingSwap.new(NODE, heroes, [], catalog)
	var state := svc.read_state()
	var snap := _snap(state)
	var stale := state.duplicate(true)
	stale["version"] = int(stale["version"]) + 1
	var forged_hp := state.duplicate(true)
	forged_hp["heroes"][0]["hp"] = 1
	var forged_part := state.duplicate(true)
	forged_part["heroes"][1]["parts"]["arms"]["tier"] = 3
	var forged_open := state.duplicate(true)
	forged_open["open"] = false
	var bad_calls := {
		"same hero": svc.exchange_worn(ids[0], ids[0], "arms", NODE, state),
		"unknown first hero": svc.exchange_worn("ghost", ids[1], "arms", NODE, state),
		"unknown second hero": svc.exchange_worn(ids[0], "ghost", "arms", NODE, state),
		"non-string first hero": svc.exchange_worn(3, ids[1], "arms", NODE, state),
		"non-string second hero": svc.exchange_worn(ids[0], null, "arms", NODE, state),
		"unknown slot": svc.exchange_worn(ids[0], ids[1], "wings", NODE, state),
		"non-string slot": svc.exchange_worn(ids[0], ids[1], 1, NODE, state),
		"empty slot": svc.exchange_worn(ids[0], ids[1], "", NODE, state),
		"torn second wearer": svc.exchange_worn(ids[0], ids[2], "arms", NODE, state),
		"torn first wearer": svc.exchange_worn(ids[2], ids[0], "arms", NODE, state),
		"stale state": svc.exchange_worn(ids[0], ids[1], "arms", NODE, stale),
		"forged hero field": svc.exchange_worn(ids[0], ids[1], "arms", NODE, forged_hp),
		"forged part tier": svc.exchange_worn(ids[0], ids[1], "arms", NODE, forged_part),
		"forged open flag": svc.exchange_worn(ids[0], ids[1], "arms", NODE, forged_open),
		"null state": svc.exchange_worn(ids[0], ids[1], "arms", NODE, null),
		"array state": svc.exchange_worn(ids[0], ids[1], "arms", NODE, []),
		"empty state": svc.exchange_worn(ids[0], ids[1], "arms", NODE, {}),
		"wrong node": svc.exchange_worn(ids[0], ids[1], "arms", "other_node", state),
		"non-string node": svc.exchange_worn(ids[0], ids[1], "arms", 7, state),
	}
	for label in bad_calls:
		_expect_reject(svc, "exchange_worn " + str(label), bad_calls[label])
	_check(_snap(svc.read_state()) == snap, "every rejected exchange left the state unchanged")
	_check(int(svc.read_state()["version"]) == 0 and bool(svc.read_state()["open"]), "rejections neither advance the version nor close the visit")
	_check(str(bad_calls["same hero"]["error"]) != "", "same-hero refusal explains itself")
	_check(_snap(bad_calls["torn second wearer"]["state"]) == snap, "failure result reports the unchanged state")
	# Torn is per slot: the torn tinker arms block only arms, while its intact head still trades.
	var head_ok := svc.exchange_worn(ids[0], ids[2], "head", NODE, state)
	_check(bool(head_ok["ok"]) and head_ok["state"]["heroes"][2]["parts"]["arms"]["torn"] == true, "torn arms do not block an intact head exchange and stay torn")

	# A LOST wearer on either side is refused; the same slot between living heroes still works.
	var lost_heroes := _direct_party()
	lost_heroes[1]["lost"] = true
	var lost_svc := RunStitchedSewingSwap.new(NODE, lost_heroes, [], catalog)
	var lost_state := lost_svc.read_state()
	var lost_snap := _snap(lost_state)
	var lost_a := lost_svc.exchange_worn(ids[0], ids[1], "arms", NODE, lost_state)
	var lost_b := lost_svc.exchange_worn(ids[1], ids[0], "arms", NODE, lost_state)
	_check(not bool(lost_a["ok"]) and str(lost_a["error"]) == "hero is lost", "exchange with a LOST second hero is refused")
	_check(not bool(lost_b["ok"]) and str(lost_b["error"]) == "hero is lost", "exchange with a LOST first hero is refused")
	_check(_snap(lost_svc.read_state()) == lost_snap, "LOST refusals changed nothing")
	_check(bool(lost_svc.exchange_worn(ids[0], ids[3], "arms", NODE, lost_state)["ok"]), "living heroes still exchange beside a LOST one")

	# A 0-HP hanging hero is not LOST and may exchange.
	var hanging_heroes := _direct_party()
	hanging_heroes[0]["hp"] = 0
	hanging_heroes[0]["hanging"] = true
	var hanging_svc := RunStitchedSewingSwap.new(NODE, hanging_heroes, [], catalog)
	_check(bool(hanging_svc.exchange_worn(ids[0], ids[1], "arms", NODE, hanging_svc.read_state())["ok"]), "a hanging 0-HP hero is not LOST and may exchange")

	# A closed visit refuses every exchange, with the pre-leave and the closed snapshot alike.
	var closed_svc := RunStitchedSewingSwap.new(NODE, _direct_party(), [], catalog)
	var open_state := closed_svc.read_state()
	var left := closed_svc.leave(NODE, open_state)
	_check(bool(left["ok"]), "leave closes the visit for the closed-visit checks")
	var closed_snap := _snap(closed_svc.read_state())
	_expect_reject(closed_svc, "exchange after leave (closed state)", closed_svc.exchange_worn(ids[0], ids[1], "arms", NODE, left["state"]))
	_expect_reject(closed_svc, "exchange after leave (pre-leave state)", closed_svc.exchange_worn(ids[0], ids[1], "arms", NODE, open_state))
	_check(_snap(closed_svc.read_state()) == closed_snap, "post-leave exchanges changed nothing")

	# An invalid visit is unusable.
	var broken := RunStitchedSewingSwap.new(NODE, [], [], catalog)
	_expect_reject(broken, "exchange on an unusable visit", broken.exchange_worn(ids[0], ids[1], "arms", NODE, broken.read_state()))


func _count_offers(hero_quote: Dictionary) -> int:
	var total := 0
	for slot_quote in hero_quote["slots"]:
		total += slot_quote["offers"].size()
	return total


func _test_lost_hero_cannot_swap() -> void:
	# Variants: lost=true on the Warden; lost=false and an absent flag must stay fully active.
	var lost_party := _party()
	lost_party[0]["lost"] = true
	lost_party[1]["lost"] = false
	var svc := _service(lost_party)
	var state := svc.read_state()
	var quote := svc.quote()
	_check(bool(quote["ok"]) and bool(quote["open"]) and quote["heroes"].size() == 4, "lost quote: open visit with four heroes")
	var warden_quote: Dictionary = quote["heroes"][0]
	_check(str(warden_quote["hero_id"]) == "warden" and warden_quote["slots"].size() == 4, "lost quote lists the warden with four slots")
	for slot_quote in warden_quote["slots"]:
		var label := "lost warden " + str(slot_quote["slot"])
		_check(not bool(slot_quote["can_swap"]), label + " cannot swap")
		_check(str(slot_quote["blocked"]) == "hero is lost", label + " is blocked as lost")
		_check(slot_quote["offers"].is_empty(), label + " has no offers")
	_check(quote["satchel_count"] == 4 and quote["satchel"].size() == 4, "satchel summary stays visible for a lost hero")
	var seamstress_quote: Dictionary = quote["heroes"][1]
	_check(_count_offers(seamstress_quote) == 4, "active seamstress still has four compatible offers (one per slot)")
	var seam_torso: Dictionary = seamstress_quote["slots"][2]
	_check(str(seam_torso["slot"]) == "torso" and bool(seam_torso["can_swap"]) and seam_torso["blocked"] == "" and seam_torso["offers"].size() == 1 and int(seam_torso["offers"][0]["satchel_index"]) == 2, "seamstress torso offers satchel index 2")

	# Refused lost swap: error mentions lost, nothing changes.
	var snap := _snap(state)
	var refused := svc.swap("warden", "arms", 0, NODE, state)
	_check(not bool(refused["ok"]) and str(refused["error"]) == "hero is lost", "lost warden arms swap is refused with a lost error")
	_check(_snap(svc.read_state()) == snap, "lost refusal leaves the full state unchanged")
	_check(_snap(refused["state"]) == snap, "lost refusal reports the unchanged state")
	_check(int(svc.read_state()["version"]) == 0 and bool(svc.read_state()["open"]), "lost refusal keeps version and keeps the visit open")
	for slot in StitchedParts.SLOTS:
		var any_refused := svc.swap("warden", slot, 0, NODE, state)
		_check(not bool(any_refused["ok"]) and str(any_refused["error"]) == "hero is lost", "lost warden %s is refused even for a mismatched index" % slot)
	_check(_snap(svc.read_state()) == snap, "all lost refusals changed nothing")

	# An active hero swaps in the same unchanged visit.
	var swap := svc.swap("seamstress", "torso", 2, NODE, state)
	_check(bool(swap["ok"]) and str(swap["action"]) == "swap", "active seamstress swaps in the same visit")
	if bool(swap["ok"]):
		var expected := state.duplicate(true)
		expected["version"] = 1
		expected["heroes"][1]["parts"]["torso"] = _worn("felt_bulwark_button_shield")
		expected["satchel"][2] = _spare("warden_torso_buckle_rebound", "torso", 1)
		_check(_snap(swap["state"]) == _snap(expected), "exactly one worn part and its reciprocal satchel slot changed")
		_check(swap["changed_heroes"].size() == 1 and str(swap["changed_heroes"][0]["id"]) == "seamstress", "only the seamstress changed")
		_check(_snap(swap["state"]["heroes"][0]) == _snap(state["heroes"][0]) and swap["state"]["heroes"][0]["lost"] == true, "lost warden record untouched")
		_check(_snap(swap["state"]["heroes"][2]) == _snap(state["heroes"][2]) and _snap(swap["state"]["heroes"][3]) == _snap(state["heroes"][3]), "other heroes untouched")
		_check(not swap.has("gold") and not swap.has("scrap") and not swap.has("fee"), "swap receipt has no fee")
		_check(_instance_ids(swap["state"]) == _instance_ids(state), "no part instance created or lost")
		var again := svc.swap("warden", "arms", 0, NODE, swap["state"])
		_check(not bool(again["ok"]) and str(again["error"]) == "hero is lost", "lost warden still refused after an active swap")
		var left := svc.leave(NODE, swap["state"])
		_check(bool(left["ok"]) and str(left["action"]) == "leave" and not bool(left["state"]["open"]), "leave closes the visit")
		_check(_snap(left["state"]["heroes"]) == _snap(swap["state"]["heroes"]) and _snap(left["state"]["satchel"]) == _snap(swap["state"]["satchel"]), "leave changes no equipment")
		_expect_reject(svc, "swap after leave", svc.swap("seamstress", "arms", 0, NODE, left["state"]))
		_expect_reject(svc, "second leave", svc.leave(NODE, left["state"]))
		var closed_warden: Dictionary = svc.quote()["heroes"][0]["slots"][0]
		_check(str(closed_warden["blocked"]) == "visit closed" and closed_warden["offers"].is_empty(), "closed visit still reports closed ahead of lost")

	# Active variants: lost=false and an absent flag give the Warden normal access.
	var false_party := _party()
	false_party[0]["lost"] = false
	for variant in ["lost false", "lost absent"]:
		var heroes := false_party if variant == "lost false" else _party()
		var active := _service(heroes)
		var active_state := active.read_state()
		var warden_arms: Dictionary = active.quote()["heroes"][0]["slots"][1]
		_check(bool(warden_arms["can_swap"]) and warden_arms["blocked"] == "" and warden_arms["offers"].size() == 1, variant + ": warden arms quote offers the claw")
		var active_swap := active.swap("warden", "arms", 0, NODE, active_state)
		_check(bool(active_swap["ok"]) and active_swap["changed_heroes"][0]["parts"]["arms"] == _worn("scissor_crab_claw_arm", 2), variant + ": warden swaps arms for the tier-II claw")

	# HP 0 / Hanging without lost=true is not LOST.
	var hanging_party := _party()
	hanging_party[0]["hp"] = 0
	hanging_party[0]["hanging"] = true
	var hanging := _service(hanging_party)
	var hanging_arms: Dictionary = hanging.quote()["heroes"][0]["slots"][1]
	_check(bool(hanging_arms["can_swap"]) and hanging_arms["blocked"] == "", "HP 0 and hanging hero is not lost and may swap")
	_check(bool(hanging.swap("warden", "arms", 0, NODE, hanging.read_state())["ok"]), "HP 0 and hanging hero swaps")

	# Only a native boolean true counts: text or numbers are not LOST.
	for odd in ["true", 1]:
		var odd_party := _party()
		odd_party[0]["lost"] = odd
		var odd_svc := _service(odd_party)
		_check(bool(odd_svc.quote()["heroes"][0]["slots"][1]["can_swap"]), "non-boolean lost %s is not LOST" % str(odd))
