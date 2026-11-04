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
