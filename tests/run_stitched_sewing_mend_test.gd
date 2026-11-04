extends SceneTree
## Design v4 (Stitched) Sewing Circle paid mending service (RunStitchedSewingMend).
##
## Scene-free: loads only the real Warden catalog (named ids, no totals or order), builds a local
## four-hero roster and drives the service directly. The quoted price of 2 is TEST FIXTURE INPUT only.

const WARDEN_PATH := "res://data/parts/warden_parts.json"
const NODE := "sewing_circle_node_5"

var failures: Array = []
var catalog: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 6052026
	var rng_state_before := rng.state
	if _load_inputs():
		_test_quote_and_deep_copy()
		_test_single_mend_receipt()
		_test_rejection_table()
		_test_constructor_rejects()
		_test_second_mend_and_replay()
		_test_leave_and_closed()
		_test_swap_after_mend()
	_check(rng.state == rng_state_before, "seeded RNG state must be unchanged")
	if failures.is_empty():
		print("run_stitched_sewing_mend_test: PASS")
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
	_check(bool(warden["ok"]), "warden catalog loads: " + str(warden["error"]))
	if not bool(warden["ok"]):
		return false
	catalog = warden["by_id"].duplicate(true)
	for id in ["warden_head_pot_helm_bonk", "warden_head_helmet_rattle", "warden_arms_shield_catch", "warden_arms_rivet_pummel", "warden_torso_iron_challenge", "warden_torso_buckle_rebound", "warden_legs_rim_toss", "warden_legs_shield_toss"]:
		_check(catalog.has(id), "catalog has " + id)
	return catalog.has("warden_arms_rivet_pummel") and catalog.has("warden_legs_shield_toss")


func _worn(id: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn}


## Local four-hero roster with opaque run fields. Hero "c" wears a torn tier-2 arms part, hero "a" a
## torn legs part; hero "b" and "d" are whole.
func _party() -> Array:
	var gear := [
		{"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch"), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_rim_toss", 3, true)},
		{"head": _worn("warden_head_helmet_rattle"), "arms": _worn("warden_arms_rivet_pummel"), "torso": _worn("warden_torso_buckle_rebound"), "legs": _worn("warden_legs_shield_toss")},
		{"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch", 2, true), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_shield_toss")},
		{"head": _worn("warden_head_helmet_rattle"), "arms": _worn("warden_arms_rivet_pummel"), "torso": _worn("warden_torso_buckle_rebound"), "legs": _worn("warden_legs_rim_toss")},
	]
	var ids := ["hero_a", "hero_b", "hero_c", "hero_d"]
	var heroes: Array = []
	for index in range(4):
		heroes.append({
			"id": ids[index],
			"name": "Doll " + ids[index],
			"parts": gear[index],
			"hp": 10 + index,
			"fray": 3 * index,
			"statuses": {"weak": index},
			"rank": index + 1,
			"extra": {"nested": [index, "opaque"]},
		})
	return heroes


func _service(scraps: int = 3, cost: int = 2, heroes: Array = [], node: String = NODE) -> RunStitchedSewingMend:
	if heroes.is_empty():
		heroes = _party()
	return RunStitchedSewingMend.new(node, heroes, scraps, cost, catalog)


func _hero(state: Dictionary, hero_id: String) -> Dictionary:
	for hero in state["heroes"]:
		if str(hero["id"]) == hero_id:
			return hero
	return {}


func _test_quote_and_deep_copy() -> void:
	var heroes := _party()
	var heroes_before := _snap(heroes)
	var svc := RunStitchedSewingMend.new(NODE, heroes, 3, 2, catalog)
	var state := svc.read_state()
	_check(bool(state["ok"]) and bool(state["open"]) and str(state["node_id"]) == NODE, "opening state is open at the node")
	_check(int(state["version"]) == 0 and int(state["scraps"]) == 3 and int(state["mend_cost"]) == 2, "opening state carries version, balance and quoted price")
	_check(state["heroes"].size() == 4, "opening state holds four heroes")
	_check(_snap(state["heroes"]) == heroes_before, "state heroes equal the supplied roster")
	var quote := svc.quote()
	_check(bool(quote["ok"]) and int(quote["scraps"]) == 3 and int(quote["mend_cost"]) == 2, "quote shows balance and price")
	_check(_snap(quote["state"]) == _snap(state), "quote embeds the authoritative state")
	var eligible: Array = []
	for hero_quote in quote["heroes"]:
		for slot_quote in hero_quote["slots"]:
			_check(int(slot_quote["cost"]) == 2, "every slot quotes the price")
			if bool(slot_quote["can_mend"]):
				eligible.append(str(hero_quote["hero_id"]) + ":" + str(slot_quote["slot"]))
			else:
				_check(not str(slot_quote["blocked"]).is_empty(), "blocked slot explains why")
			var key := str(hero_quote["hero_id"]) + ":" + str(slot_quote["slot"])
			_check(bool(slot_quote["worn"]["torn"]) == (key in ["hero_a:legs", "hero_c:arms"]), "worn torn flag is reported: " + key)
	eligible.sort()
	_check(eligible == ["hero_a:legs", "hero_c:arms"], "exactly the torn parts are eligible: " + str(eligible))
	var arms_quote: Dictionary = {}
	for hero_quote in quote["heroes"]:
		if str(hero_quote["hero_id"]) == "hero_c":
			for slot_quote in hero_quote["slots"]:
				if str(slot_quote["slot"]) == "arms":
					arms_quote = slot_quote
	_check(str(arms_quote["worn"]["id"]) == "warden_arms_shield_catch" and int(arms_quote["worn"]["tier"]) == 2, "quote names the torn arms part and tier")
	# Deep copies: mutating inputs or returned snapshots never reaches the service.
	heroes[2]["parts"]["arms"]["torn"] = false
	heroes[0]["hp"] = 99
	state["heroes"][2]["parts"]["arms"]["torn"] = false
	state["scraps"] = 100
	quote["heroes"].clear()
	var again := svc.read_state()
	_check(bool(_hero(again, "hero_c")["parts"]["arms"]["torn"]), "service keeps its own torn flag")
	_check(int(again["scraps"]) == 3 and int(_hero(again, "hero_a")["hp"]) == 10, "service keeps its own balance and hero fields")
	_check(int(again["version"]) == 0, "reading and quoting never advance the version")
	var fixed_quote := svc.quote()
	_check(fixed_quote["heroes"].size() == 4, "quote is rebuilt from service state")


func _test_single_mend_receipt() -> void:
	var svc := _service(3, 2)
	var source := svc.read_state()
	var receipt := svc.mend("hero_c", "arms", NODE, source)
	_check(bool(receipt["ok"]) and str(receipt["action"]) == "mend", "named hero arms mend succeeds")
	if not bool(receipt["ok"]):
		return
	_check(str(receipt["hero_id"]) == "hero_c" and str(receipt["slot"]) == "arms", "receipt names hero and slot")
	_check(int(receipt["charged_scraps"]) == 2 and int(receipt["scraps_before"]) == 3 and int(receipt["scraps"]) == 1, "3 scraps with a quoted price of 2 leaves exactly 1")
	_check(_snap(receipt["source_state"]) == _snap(source), "receipt source_state is the exact presented snapshot")
	_check(_snap(receipt["state"]) == _snap(svc.read_state()), "receipt state is the new authoritative state")
	_check(int(receipt["state"]["version"]) == int(source["version"]) + 1, "version advances by exactly one")
	_check(int(receipt["state"]["scraps"]) == 1, "new state holds the remaining scraps")
	var after_hero := _hero(receipt["state"], "hero_c")
	_check(_snap(receipt["changed_hero"]) == _snap(after_hero), "changed hero equals the new state's hero")
	_check(receipt["changed_heroes"].size() == 1 and _snap(receipt["changed_heroes"][0]) == _snap(after_hero), "changed_heroes lists the one hero")
	_check(not bool(after_hero["parts"]["arms"]["torn"]), "the equipped arms part is no longer torn")
	_check(str(after_hero["parts"]["arms"]["id"]) == "warden_arms_shield_catch" and int(after_hero["parts"]["arms"]["tier"]) == 2, "id and tier are preserved")
	# Everything else is identical to the source: only the one torn flag changed.
	var expected: Array = source["heroes"].duplicate(true)
	for hero in expected:
		if str(hero["id"]) == "hero_c":
			hero["parts"]["arms"]["torn"] = false
	_check(_snap(receipt["state"]["heroes"]) == _snap(expected), "no other hero, part or opaque field changed")
	var untouched := _hero(receipt["state"], "hero_a")
	_check(bool(untouched["parts"]["legs"]["torn"]), "another hero's torn part stays torn")
	_check(str(receipt["state"]["node_id"]) == NODE and bool(receipt["state"]["open"]), "visit stays open after a mend")
	# The same presented snapshot cannot be charged twice.
	var replay := svc.mend("hero_c", "arms", NODE, source)
	_check(not bool(replay["ok"]) and str(replay["error"]) == "stale or forged state", "replaying the source snapshot is refused")
	_check(int(svc.read_state()["scraps"]) == 1, "replay does not spend again")


func _test_rejection_table() -> void:
	var svc := _service(3, 2)
	var state := svc.read_state()
	var forged_scraps := state.duplicate(true)
	forged_scraps["scraps"] = 50
	var forged_torn := state.duplicate(true)
	forged_torn["heroes"][1]["parts"]["arms"]["torn"] = true
	var forged_cost := state.duplicate(true)
	forged_cost["mend_cost"] = 1
	var cases := [
		{"name": "wrong node", "hero": "hero_c", "slot": "arms", "node": "other_node", "state": state},
		{"name": "non-string node", "hero": "hero_c", "slot": "arms", "node": 5, "state": state},
		{"name": "forged balance", "hero": "hero_c", "slot": "arms", "node": NODE, "state": forged_scraps},
		{"name": "forged torn flag", "hero": "hero_c", "slot": "arms", "node": NODE, "state": forged_torn},
		{"name": "forged price", "hero": "hero_c", "slot": "arms", "node": NODE, "state": forged_cost},
		{"name": "state not a dictionary", "hero": "hero_c", "slot": "arms", "node": NODE, "state": "state"},
		{"name": "unknown hero", "hero": "hero_z", "slot": "arms", "node": NODE, "state": state},
		{"name": "non-string hero", "hero": 3, "slot": "arms", "node": NODE, "state": state},
		{"name": "unknown slot", "hero": "hero_c", "slot": "tail", "node": NODE, "state": state},
		{"name": "non-string slot", "hero": "hero_c", "slot": null, "node": NODE, "state": state},
		{"name": "untorn part", "hero": "hero_c", "slot": "head", "node": NODE, "state": state},
		{"name": "untorn part of a whole hero", "hero": "hero_b", "slot": "arms", "node": NODE, "state": state},
	]
	var before := _snap(svc.read_state())
	for entry in cases:
		var result := svc.mend(entry["hero"], entry["slot"], entry["node"], entry["state"])
		_check(not bool(result["ok"]) and not str(result["error"]).is_empty(), "refused: " + str(entry["name"]))
		_check(_snap(svc.read_state()) == before, "nothing changed after refusal: " + str(entry["name"]))
	# A lost hero is not eligible even with a torn part.
	var lost_party := _party()
	lost_party[2]["lost"] = true
	var lost_svc := _service(3, 2, lost_party)
	var lost_before := _snap(lost_svc.read_state())
	var lost_result := lost_svc.mend("hero_c", "arms", NODE, lost_svc.read_state())
	_check(not bool(lost_result["ok"]) and _snap(lost_svc.read_state()) == lost_before, "lost hero cannot be mended")
	# Insufficient scraps: affordable only at exactly the price.
	for scraps in [0, 1]:
		var poor := _service(scraps, 2)
		var poor_before := _snap(poor.read_state())
		var poor_quote := poor.quote()
		for hero_quote in poor_quote["heroes"]:
			for slot_quote in hero_quote["slots"]:
				_check(not bool(slot_quote["can_mend"]), "nothing is mendable with %d scraps" % scraps)
		var poor_result := poor.mend("hero_c", "arms", NODE, poor.read_state())
		_check(not bool(poor_result["ok"]) and str(poor_result["error"]) == "insufficient scraps", "insufficient scraps refused at %d" % scraps)
		_check(_snap(poor.read_state()) == poor_before, "insufficient scraps change nothing at %d" % scraps)
	var exact := _service(2, 2)
	var exact_result := exact.mend("hero_a", "legs", NODE, exact.read_state())
	_check(bool(exact_result["ok"]) and int(exact_result["scraps"]) == 0, "exactly the price is enough and leaves zero")


func _test_constructor_rejects() -> void:
	var bad_inputs := [
		{"name": "zero price", "node": NODE, "scraps": 3, "cost": 0},
		{"name": "negative price", "node": NODE, "scraps": 3, "cost": -2},
		{"name": "string price", "node": NODE, "scraps": 3, "cost": "2"},
		{"name": "float price", "node": NODE, "scraps": 3, "cost": 2.5},
		{"name": "null price", "node": NODE, "scraps": 3, "cost": null},
		{"name": "negative scraps", "node": NODE, "scraps": -1, "cost": 2},
		{"name": "string scraps", "node": NODE, "scraps": "3", "cost": 2},
		{"name": "empty node", "node": "", "scraps": 3, "cost": 2},
		{"name": "non-string node", "node": 7, "scraps": 3, "cost": 2},
	]
	for entry in bad_inputs:
		var svc := RunStitchedSewingMend.new(entry["node"], _party(), entry["scraps"], entry["cost"], catalog)
		var state := svc.read_state()
		_check(not bool(state["ok"]) and not str(state["error"]).is_empty(), "constructor refuses: " + str(entry["name"]))
		_check(not bool(svc.quote()["ok"]), "quote refuses: " + str(entry["name"]))
		var result := svc.mend("hero_c", "arms", entry["node"], state)
		_check(not bool(result["ok"]), "mend refuses: " + str(entry["name"]))
		_check(not bool(svc.leave(entry["node"], state)["ok"]), "leave refuses: " + str(entry["name"]))
	var bad_rosters: Array = []
	var no_parts := _party()
	no_parts[0].erase("parts")
	bad_rosters.append(no_parts)
	var duplicate := _party()
	duplicate[1]["id"] = "hero_a"
	bad_rosters.append(duplicate)
	var unknown_part := _party()
	unknown_part[0]["parts"]["head"] = _worn("no_such_part")
	bad_rosters.append(unknown_part)
	var wrong_slot := _party()
	wrong_slot[0]["parts"]["head"] = _worn("warden_arms_shield_catch")
	bad_rosters.append(wrong_slot)
	var bad_tier := _party()
	bad_tier[0]["parts"]["head"] = _worn("warden_head_pot_helm_bonk", 4)
	bad_rosters.append(bad_tier)
	var bad_torn := _party()
	bad_torn[0]["parts"]["head"] = {"id": "warden_head_pot_helm_bonk", "tier": 1, "torn": "yes"}
	bad_rosters.append(bad_torn)
	var extra_slot := _party()
	extra_slot[0]["parts"]["tail"] = _worn("warden_head_pot_helm_bonk")
	bad_rosters.append(extra_slot)
	var five := _party()
	var fifth: Dictionary = five[0].duplicate(true)
	fifth["id"] = "hero_e"
	five.append(fifth)
	bad_rosters.append(five)
	for roster in bad_rosters:
		var svc := RunStitchedSewingMend.new(NODE, roster, 3, 2, catalog)
		_check(not bool(svc.read_state()["ok"]), "constructor refuses a malformed roster")
	_check(not bool(RunStitchedSewingMend.new(NODE, [], 3, 2, catalog).read_state()["ok"]), "empty roster refused")
	_check(not bool(RunStitchedSewingMend.new(NODE, _party(), 3, 2, {}).read_state()["ok"]), "empty catalog refused")
	_check(not bool(RunStitchedSewingMend.new(NODE, _party(), 3, 2, "catalog").read_state()["ok"]), "non-dictionary catalog refused")


func _test_second_mend_and_replay() -> void:
	var svc := _service(5, 2)
	var source := svc.read_state()
	var first := svc.mend("hero_c", "arms", NODE, source)
	_check(bool(first["ok"]) and int(first["scraps"]) == 3, "first mend leaves 3 of 5")
	# Stale snapshots and the first receipt's source cannot mend the second part.
	var stale := svc.mend("hero_a", "legs", NODE, source)
	_check(not bool(stale["ok"]) and str(stale["error"]) == "stale or forged state", "stale snapshot cannot pay for the second mend")
	_check(int(svc.read_state()["scraps"]) == 3, "stale attempt spent nothing")
	var second := svc.mend("hero_a", "legs", NODE, first["state"])
	_check(bool(second["ok"]), "second independently paid mend uses the fresh snapshot")
	if not bool(second["ok"]):
		return
	_check(int(second["charged_scraps"]) == 2 and int(second["scraps_before"]) == 3 and int(second["scraps"]) == 1, "second mend charges exactly the price once")
	_check(_snap(second["source_state"]) == _snap(first["state"]), "second receipt's source is the first receipt's state")
	_check(int(second["state"]["version"]) == int(source["version"]) + 2, "version is monotonic across mends")
	var hero_a := _hero(second["state"], "hero_a")
	_check(not bool(hero_a["parts"]["legs"]["torn"]) and str(hero_a["parts"]["legs"]["id"]) == "warden_legs_rim_toss" and int(hero_a["parts"]["legs"]["tier"]) == 3, "legs mended with id and tier preserved")
	_check(not bool(_hero(second["state"], "hero_c")["parts"]["arms"]["torn"]), "first mend persists")
	# Replays of either receipt, or of the second mend itself, cannot charge again.
	for replay_state in [source, first["state"], second["source_state"]]:
		for target in [["hero_c", "arms"], ["hero_a", "legs"]]:
			var replay := svc.mend(target[0], target[1], NODE, replay_state)
			_check(not bool(replay["ok"]), "replayed snapshot refused for %s %s" % target)
	var current := svc.read_state()
	var now_untorn := svc.mend("hero_a", "legs", NODE, current)
	_check(not bool(now_untorn["ok"]) and str(now_untorn["error"]) == "part is not torn", "an already mended part is not mended or charged again")
	_check(int(svc.read_state()["scraps"]) == 1 and _snap(svc.read_state()) == _snap(current), "balance and heroes unchanged by the refused repeat")


func _test_leave_and_closed() -> void:
	var svc := _service(3, 2)
	var source := svc.read_state()
	var wrong := svc.leave("other_node", source)
	_check(not bool(wrong["ok"]) and bool(svc.read_state()["open"]), "leave at the wrong node is refused")
	var left := svc.leave(NODE, source)
	_check(bool(left["ok"]) and str(left["action"]) == "leave" and left["changed_heroes"].is_empty(), "leave succeeds with no changed hero")
	_check(int(left["charged_scraps"]) == 0 and int(left["scraps"]) == 3, "leave charges nothing")
	var closed := svc.read_state()
	_check(not bool(closed["open"]) and int(closed["version"]) == 1, "visit is closed with a bumped version")
	_check(_snap(closed["heroes"]) == _snap(source["heroes"]), "leave changes no hero")
	var after_close := svc.mend("hero_c", "arms", NODE, closed)
	_check(not bool(after_close["ok"]) and str(after_close["error"]) == "visit is closed", "closed visit refuses a mend")
	_check(not bool(svc.leave(NODE, closed)["ok"]), "closed visit refuses a second leave")
	_check(_snap(svc.read_state()) == _snap(closed), "closed visit is unchanged by refusals")
	var closed_quote := svc.quote()
	_check(bool(closed_quote["ok"]) and not bool(closed_quote["open"]), "closed visit still quotes")
	for hero_quote in closed_quote["heroes"]:
		for slot_quote in hero_quote["slots"]:
			_check(not bool(slot_quote["can_mend"]) and str(slot_quote["blocked"]) == "visit closed", "closed visit offers no mend")
	# Mend then leave: the receipt state is accepted by leave.
	var svc2 := _service(3, 2)
	var mended := svc2.mend("hero_c", "arms", NODE, svc2.read_state())
	var left2 := svc2.leave(NODE, mended["state"])
	_check(bool(left2["ok"]) and int(left2["scraps"]) == 1, "leave after a mend keeps the remaining scraps")


func _test_swap_after_mend() -> void:
	var spare := {"id": "warden_arms_rivet_pummel", "tier": 2, "torn": false, "slot": "arms"}
	var torn_party := _party()
	var blocked_swap := RunStitchedSewingSwap.new("swap_node", torn_party, [spare], catalog)
	var blocked := blocked_swap.swap("hero_c", "arms", 0, "swap_node", blocked_swap.read_state())
	_check(not bool(blocked["ok"]), "existing swap service refuses the torn part before mending")
	var svc := _service(3, 2)
	var receipt := svc.mend("hero_c", "arms", NODE, svc.read_state())
	_check(bool(receipt["ok"]), "mend for the swap hand-off succeeds")
	if not bool(receipt["ok"]):
		return
	var mended_heroes: Array = receipt["state"]["heroes"].duplicate(true)
	var swap_svc := RunStitchedSewingSwap.new("swap_node", mended_heroes, [spare], catalog)
	_check(bool(swap_svc.read_state()["ok"]), "mended heroes are accepted by the existing swap service")
	var swapped := swap_svc.swap("hero_c", "arms", 0, "swap_node", swap_svc.read_state())
	_check(bool(swapped["ok"]), "the mended part can now be swapped for a same-slot spare")
	if not bool(swapped["ok"]):
		return
	var worn_after: Dictionary = _hero(swapped["state"], "hero_c")["parts"]["arms"]
	_check(str(worn_after["id"]) == "warden_arms_rivet_pummel" and int(worn_after["tier"]) == 2 and not bool(worn_after["torn"]), "spare is worn after the swap")
	var stored: Dictionary = swapped["state"]["satchel"][0]
	_check(str(stored["id"]) == "warden_arms_shield_catch" and int(stored["tier"]) == 2 and not bool(stored["torn"]) and str(stored["slot"]) == "arms", "the mended part went to the satchel unchanged and untorn")
	_check(swapped["state"]["satchel"].size() == 1, "swap keeps the satchel at one part")
