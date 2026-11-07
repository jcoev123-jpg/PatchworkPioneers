extends SceneTree
## Design v4 (Stitched) Sewing Circle LOST-doll replacement (RunStitchedSewingReplacement).
##
## Scene-free: loads the real Scarecrow and Warden catalogs plus the real roster entry for Scarecrow's
## max HP, builds a local four-doll party (no Scarecrow) with the doll at rank 3 LOST, and drives the
## service directly. One candidate proves the generic service; no other starter id is registered here.

const SCARECROW_PATH := "res://data/parts/scarecrow_parts.json"
const WARDEN_PATH := "res://data/parts/warden_parts.json"
const ROSTER_PATH := "res://data/heroes/v3_party_roster.json"
const NODE := "sewing_circle_node_7"
const STARTERS := {
	"head": "scarecrow_head_sack_glare",
	"arms": "scarecrow_arms_fork_jab",
	"torso": "scarecrow_torso_straw_padding",
	"legs": "scarecrow_legs_crow_dive",
}

var failures: Array = []
var catalog: Dictionary = {}
var scarecrow_max_hp := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 7062026
	var rng_state_before := rng.state
	if _load_inputs():
		_test_admission()
		_test_quote()
		_test_replace_receipt()
		_test_rejections()
		_test_leave()
		_test_closed_and_replay()
	_check(rng.state == rng_state_before, "seeded RNG state must be unchanged")
	if failures.is_empty():
		print("run_stitched_sewing_replacement_test: PASS")
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
	var scarecrow := StitchedParts.load_catalog(SCARECROW_PATH)
	var warden := StitchedParts.load_catalog(WARDEN_PATH)
	_check(bool(scarecrow["ok"]), "scarecrow catalog loads: " + str(scarecrow["error"]))
	_check(bool(warden["ok"]), "warden catalog loads: " + str(warden["error"]))
	if not bool(scarecrow["ok"]) or not bool(warden["ok"]):
		return false
	catalog = warden["by_id"].duplicate(true)
	for id in scarecrow["by_id"]:
		catalog[id] = scarecrow["by_id"][id].duplicate(true)
	for slot in STARTERS:
		_check(catalog.has(STARTERS[slot]), "catalog has " + str(STARTERS[slot]))
		if catalog.has(STARTERS[slot]):
			_check(str(catalog[STARTERS[slot]]["slot"]) == slot and str(catalog[STARTERS[slot]]["owner"]) == "scarecrow", "starter slot and owner " + slot)
	var roster: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
	_check(roster is Array, "roster loads")
	if not roster is Array:
		return false
	for entry in roster:
		if entry is Dictionary and str(entry.get("id")) == "scarecrow":
			scarecrow_max_hp = int(entry["max_hp"])
	_check(scarecrow_max_hp == 34, "real Scarecrow max_hp is 34")
	for id in ["warden_head_pot_helm_bonk", "warden_head_helmet_rattle", "warden_arms_shield_catch", "warden_arms_rivet_pummel", "warden_torso_iron_challenge", "warden_torso_buckle_rebound", "warden_legs_rim_toss", "warden_legs_shield_toss"]:
		_check(catalog.has(id), "catalog has " + id)
	return scarecrow_max_hp == 34 and catalog.has("warden_legs_shield_toss") and catalog.has("warden_arms_rivet_pummel")


func _worn(id: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn}


## Four dolls at ranks 1-4, none Scarecrow. The doll at rank 3 ("doll_c") is LOST; doll_b is HANGING at 0 HP
## but not lost.
func _party(lost_index: int = 2) -> Array:
	var gear := [
		{"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch"), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_rim_toss", 3, true)},
		{"head": _worn("warden_head_helmet_rattle"), "arms": _worn("warden_arms_rivet_pummel"), "torso": _worn("warden_torso_buckle_rebound"), "legs": _worn("warden_legs_shield_toss")},
		{"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch", 2, true), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_shield_toss")},
		{"head": _worn("warden_head_helmet_rattle"), "arms": _worn("warden_arms_rivet_pummel"), "torso": _worn("warden_torso_buckle_rebound"), "legs": _worn("warden_legs_rim_toss")},
	]
	var ids := ["doll_a", "doll_b", "doll_c", "doll_d"]
	var party: Array = []
	for index in range(4):
		party.append({
			"id": ids[index],
			"name": "Doll " + ids[index],
			"rank": index + 1,
			"lost": index == lost_index,
			"hp": 0 if index == lost_index or index == 1 else 12 + index,
			"max_hp": 30 + index,
			"fray": 3 * index,
			"statuses": {"weak": index},
			"parts": {} if index == lost_index else gear[index],
			"extra": {"nested": [index, "opaque"]},
		})
	return party


func _scarecrow(id: String = "scarecrow") -> Dictionary:
	var parts: Dictionary = {}
	for slot in STARTERS:
		parts[slot] = _worn(STARTERS[slot])
	return {"id": id, "name": "Scarecrow", "max_hp": scarecrow_max_hp, "hp": scarecrow_max_hp, "parts": parts}


func _service(party: Array = [], candidates: Array = [], node: String = NODE) -> RunStitchedSewingReplacement:
	if party.is_empty():
		party = _party()
	if candidates.is_empty():
		candidates = [_scarecrow()]
	return RunStitchedSewingReplacement.new(node, party, candidates, catalog)


func _ok(service: RunStitchedSewingReplacement) -> bool:
	return bool(service.read_state().get("ok", false))


func _test_admission() -> void:
	_check(_ok(_service()), "valid party and Scarecrow candidate are admitted")
	var bad_party := {
		"party of three": func(p: Array, _c: Array) -> void: p.pop_back(),
		"party of five": func(p: Array, _c: Array) -> void: p.append(p[0].duplicate(true)),
		"duplicate party id": func(p: Array, _c: Array) -> void: p[1]["id"] = "doll_a",
		"duplicate rank": func(p: Array, _c: Array) -> void: p[1]["rank"] = 1,
		"rank out of range": func(p: Array, _c: Array) -> void: p[3]["rank"] = 5,
		"string rank": func(p: Array, _c: Array) -> void: p[3]["rank"] = "4",
		"non-boolean lost": func(p: Array, _c: Array) -> void: p[0]["lost"] = 0,
		"missing lost": func(p: Array, _c: Array) -> void: p[0].erase("lost"),
		"lost still equipped": func(p: Array, _c: Array) -> void: p[2]["parts"] = p[0]["parts"].duplicate(true),
		"lost positive hp": func(p: Array, _c: Array) -> void: p[2]["hp"] = 1,
		"lost missing hp": func(p: Array, _c: Array) -> void: p[2].erase("hp"),
		"lost non-dictionary parts": func(p: Array, _c: Array) -> void: p[2]["parts"] = [],
		"empty survivor": func(p: Array, _c: Array) -> void: p[0]["parts"] = {},
		"invalid party hp": func(p: Array, _c: Array) -> void: p[0]["hp"] = true,
		"unknown worn part": func(p: Array, _c: Array) -> void: p[0]["parts"]["head"]["id"] = "nope",
		"worn part in wrong slot": func(p: Array, _c: Array) -> void: p[0]["parts"]["head"]["id"] = "warden_legs_rim_toss",
		"worn part missing slot": func(p: Array, _c: Array) -> void: p[0]["parts"].erase("legs"),
		"worn tier 4": func(p: Array, _c: Array) -> void: p[0]["parts"]["arms"]["tier"] = 4,
		"worn torn not bool": func(p: Array, _c: Array) -> void: p[0]["parts"]["arms"]["torn"] = 1,
		"candidate already in party": func(_p: Array, c: Array) -> void: c[0]["id"] = "doll_b",
		"duplicate candidate": func(_p: Array, c: Array) -> void: c.append(c[0].duplicate(true)),
		"candidate slot missing": func(_p: Array, c: Array) -> void: c[0]["parts"].erase("torso"),
		"candidate fifth slot": func(_p: Array, c: Array) -> void: c[0]["parts"]["tail"] = _worn("scarecrow_legs_crow_dive"),
		"candidate unknown part": func(_p: Array, c: Array) -> void: c[0]["parts"]["head"]["id"] = "scarecrow_head_forged",
		"candidate wrong slot": func(_p: Array, c: Array) -> void: c[0]["parts"]["head"]["id"] = "scarecrow_arms_fork_jab",
		"candidate foreign owner": func(_p: Array, c: Array) -> void: c[0]["parts"]["arms"]["id"] = "warden_arms_shield_catch",
		"candidate id differs from owner": func(_p: Array, c: Array) -> void: c[0]["id"] = "yarn_ranger",
		"candidate tier 2": func(_p: Array, c: Array) -> void: c[0]["parts"]["legs"]["tier"] = 2,
		"candidate torn": func(_p: Array, c: Array) -> void: c[0]["parts"]["torso"]["torn"] = true,
		"candidate carries lost": func(_p: Array, c: Array) -> void: c[0]["lost"] = false,
		"candidate carries rank": func(_p: Array, c: Array) -> void: c[0]["rank"] = 3,
		"candidate no max_hp": func(_p: Array, c: Array) -> void: c[0].erase("max_hp"),
		"candidate hp over max": func(_p: Array, c: Array) -> void: c[0]["hp"] = 99,
		"candidate zero hp": func(_p: Array, c: Array) -> void: c[0]["hp"] = 0,
	}
	for label in bad_party:
		var party := _party()
		var candidates: Array = [_scarecrow()]
		bad_party[label].call(party, candidates)
		var service := RunStitchedSewingReplacement.new(NODE, party, candidates, catalog)
		var state := service.read_state()
		_check(not bool(state["ok"]), "constructor rejects: " + label)
		var quote := service.quote()
		_check(not bool(quote["ok"]) and not quote.has("candidates"), "rejected visit quotes nothing: " + label)
		var receipt := service.replace("doll_c", "scarecrow", NODE, state)
		_check(not bool(receipt["ok"]), "rejected visit cannot replace: " + label)
	_check(not bool(RunStitchedSewingReplacement.new("", _party(), [_scarecrow()], catalog).read_state()["ok"]), "empty node rejected")
	_check(not bool(RunStitchedSewingReplacement.new(NODE, _party(), [_scarecrow()], {}).read_state()["ok"]), "empty catalog rejected")
	_check(not bool(RunStitchedSewingReplacement.new(NODE, _party(), [], catalog).read_state()["ok"]), "empty candidate list rejected")
	_check(not bool(RunStitchedSewingReplacement.new(NODE, "party", [_scarecrow()], catalog).read_state()["ok"]), "non-array party rejected")
	# A bare Scarecrow without an authored owner id in the catalog cannot be admitted under another id.
	var renamed := _scarecrow("scarecrow_twin")
	_check(not bool(RunStitchedSewingReplacement.new(NODE, _party(), [renamed], catalog).read_state()["ok"]), "forged candidate id with Scarecrow parts rejected")
	var untyped := RunStitchedSewingReplacement.new()
	_check(not bool(untyped.read_state()["ok"]), "default-constructed service is unusable")


func _test_quote() -> void:
	var inputs_party := _party()
	var inputs_candidates: Array = [_scarecrow()]
	var party_before := _snap(inputs_party)
	var candidates_before := _snap(inputs_candidates)
	var service := RunStitchedSewingReplacement.new(NODE, inputs_party, inputs_candidates, catalog)
	# Caller mutation after construction must not reach the visit.
	inputs_party[2]["lost"] = false
	inputs_candidates[0]["parts"]["head"]["id"] = "forged"
	inputs_candidates[0]["max_hp"] = 999
	var state := service.read_state()
	_check(bool(state["ok"]) and bool(state["party"][2]["lost"]), "constructor detaches the party")
	_check(int(state["candidates"][0]["max_hp"]) == 34 and str(state["candidates"][0]["parts"]["head"]["id"]) == STARTERS["head"], "constructor detaches candidate templates")
	inputs_party[2]["lost"] = true
	inputs_candidates[0]["parts"]["head"]["id"] = STARTERS["head"]
	inputs_candidates[0]["max_hp"] = 34
	_check(_snap(inputs_party) == party_before and _snap(inputs_candidates) == candidates_before, "restored inputs match the originals")

	var quote := service.quote()
	_check(bool(quote["ok"]) and bool(quote["open"]) and bool(quote["can_replace"]), "quote with a LOST doll offers a replacement")
	_check(quote["lost"].size() == 1 and str(quote["lost"][0]["hero_id"]) == "doll_c" and int(quote["lost"][0]["rank"]) == 3, "quote names only the LOST doll at rank 3")
	_check(quote["candidates"].size() == 1 and str(quote["candidates"][0]["candidate_id"]) == "scarecrow", "quote names the Scarecrow candidate")
	var offer: Dictionary = quote["candidates"][0]
	_check(int(offer["max_hp"]) == 34, "offer shows real max HP 34")
	for slot in STARTERS:
		_check(str(offer["parts"][slot]["id"]) == STARTERS[slot] and int(offer["parts"][slot]["tier"]) == 1 and not bool(offer["parts"][slot]["torn"]) and str(offer["parts"][slot]["owner"]) == "scarecrow", "offer exposes starter " + slot)
	_check(bool(quote["leave"]["available"]) and str(quote["leave"]["action"]) == "leave", "quote lists Leave")
	_test_quote_projection(service, offer)
	var state_before := _snap(service.read_state())
	quote["candidates"][0]["parts"]["head"]["id"] = "tampered"
	quote["state"]["party"][0]["id"] = "tampered"
	quote["lost"].clear()
	_check(_snap(service.read_state()) == state_before, "mutating a quote does not reach the visit")
	_check(_snap(service.quote()["state"]) == state_before and str(service.quote()["candidates"][0]["parts"]["head"]["id"]) == STARTERS["head"], "a fresh quote is untouched")
	var state_copy := service.read_state()
	state_copy["party"][2]["lost"] = false
	_check(_snap(service.read_state()) == state_before, "mutating read_state does not reach the visit")

	# No LOST doll: only Leave. Hanging (hp 0) is not LOST.
	var healthy := _party(-1)
	var no_lost := RunStitchedSewingReplacement.new(NODE, healthy, [_scarecrow()], catalog)
	var no_quote := no_lost.quote()
	_check(bool(no_quote["ok"]) and no_quote["candidates"].is_empty() and no_quote["lost"].is_empty() and not bool(no_quote["can_replace"]), "no LOST doll: quote names no candidates")
	_check(bool(no_quote["leave"]["available"]), "no LOST doll: Leave is still listed")
	_check(int(healthy[1]["hp"]) == 0 and not bool(healthy[1]["lost"]), "fixture has a Hanging but not LOST doll")
	var refused := no_lost.replace("doll_b", "scarecrow", NODE, no_lost.read_state())
	_check(not bool(refused["ok"]) and str(refused["error"]) == "doll is not lost", "a Hanging doll cannot be replaced")
	var refused_healthy := no_lost.replace("doll_a", "scarecrow", NODE, no_lost.read_state())
	_check(not bool(refused_healthy["ok"]), "a healthy doll cannot be replaced")
	_check(bool(no_lost.read_state()["open"]) and int(no_lost.read_state()["version"]) == 0, "refused requests leave the visit open")


func _ints(values: Variant) -> Array:
	var result: Array = []
	if values is Array:
		for value in values:
			result.append(int(value))
	return result


## The quote shows each starter's real, catalog-resolved ability, stat and text (read-only, detached).
func _test_quote_projection(service: RunStitchedSewingReplacement, offer: Dictionary) -> void:
	var catalog_before := _snap(catalog)
	var state_before := _snap(service.read_state())
	_check(offer["parts"].size() == 4, "offer lists all four slots")
	for slot in STARTERS:
		var record: Dictionary = catalog[STARTERS[slot]]
		var part: Dictionary = offer["parts"][slot]
		_check(_snap(part["ability"]) == _snap(StitchedParts.ability_at_tier(record, 1)), "offer ability equals catalog tier-1 ability: " + slot)
		_check(_snap(part["stat"]) == _snap(StitchedParts.stat_at_tier(record, 1)), "offer stat equals catalog tier-1 stat: " + slot)
		_check(str(part["text"]) == str(record["text"]) and not str(part["text"]).is_empty(), "offer text equals authored text: " + slot)
		_check(part["ability"] is Dictionary and not part["ability"].is_empty() and part["stat"] is Dictionary and not part["stat"].is_empty(), "offer ability and stat are non-empty: " + slot)
	var head: Dictionary = offer["parts"]["head"]["ability"]
	_check(str(head["kind"]) == "debuff" and int(head["effects"]["weak"]) == 1 and int(head["effects"]["mark"]) == 2, "HEAD Sack Glare Weak 1 and Mark 2")
	_check(_ints(head["launch"]) == [1, 2, 3] and _ints(head["target"]) == [1, 2, 3] and str(head["target_side"]) == "enemy", "HEAD launch and enemy target ranks 1-3")
	_check(int(head["acc"]) == 92 and _ints(head["dmg"]) == [0, 0], "HEAD ACC 92, no damage")
	_check(int(offer["parts"]["head"]["stat"]["acc"]) == 4, "HEAD stat acc +4")
	var arms: Dictionary = offer["parts"]["arms"]["ability"]
	_check(str(arms["kind"]) == "melee" and int(arms["effects"]["bleed"]) == 1 and _ints(arms["dmg"]) == [4, 6], "ARMS Fork Jab Bleed 1, damage 4-6")
	_check(_ints(arms["launch"]) == [1, 2] and _ints(arms["target"]) == [1, 2] and int(arms["acc"]) == 93, "ARMS ranks 1-2, ACC 93")
	_check(int(offer["parts"]["arms"]["stat"]["dmg"]) == 1, "ARMS stat dmg +1")
	var torso: Dictionary = offer["parts"]["torso"]["ability"]
	_check(str(torso["kind"]) == "guard" and int(torso["effects"]["guard"]) == 2, "TORSO Straw Padding Guard 2")
	_check(str(torso["target_side"]) == "ally" and _ints(torso["target"]) == [1, 2, 3, 4] and _ints(torso["launch"]) == [1, 2, 3], "TORSO ally reach 1-4, launch 1-3")
	var torso_stat: Dictionary = offer["parts"]["torso"]["stat"]
	_check(int(torso_stat["max_hp"]) == 6 and int(torso_stat["prot"]) == 3, "TORSO stat max_hp 6 and prot 3")
	_check(int(offer["max_hp"]) == 34 and int(offer["hp"]) == 34, "torso stat is not added to the candidate's HP")
	var legs: Dictionary = offer["parts"]["legs"]["ability"]
	_check(str(legs["kind"]) == "ranged" and int(legs["mark_damage"]) == 3 and _ints(legs["dmg"]) == [3, 5], "LEGS Crow Dive mark_damage 3, damage 3-5")
	_check(_ints(legs["launch"]) == [1, 2, 3, 4] and _ints(legs["target"]) == [1, 2, 3] and int(legs["acc"]) == 91, "LEGS launch 1-4, target 1-3, ACC 91")
	_check(int(offer["parts"]["legs"]["stat"]["speed"]) == 2, "LEGS stat speed +2")

	# Mutating every nested copy in a returned quote cannot reach the visit, the catalog or later quotes.
	var quote := service.quote()
	var mutable: Dictionary = quote["candidates"][0]
	for slot in STARTERS:
		var part: Dictionary = mutable["parts"][slot]
		part["ability"]["effects"]["tampered"] = 99
		part["ability"]["target"].append(9)
		part["ability"]["launch"].clear()
		part["ability"]["dmg"][0] = 999
		part["ability"]["name"] = "tampered"
		part["stat"]["tampered"] = 99
		part["stat"].erase("acc")
		part["text"] = "tampered"
	_check(_snap(service.read_state()) == state_before, "mutating a quoted ability, stat and text does not reach the visit")
	_check(_snap(catalog) == catalog_before, "mutating a quoted ability, stat and text does not reach the catalog")
	var again: Dictionary = service.quote()["candidates"][0]
	for slot in STARTERS:
		var record: Dictionary = catalog[STARTERS[slot]]
		_check(_snap(again["parts"][slot]["ability"]) == _snap(StitchedParts.ability_at_tier(record, 1)), "a later quote ability is untouched: " + slot)
		_check(_snap(again["parts"][slot]["stat"]) == _snap(StitchedParts.stat_at_tier(record, 1)) and str(again["parts"][slot]["text"]) == str(record["text"]), "a later quote stat and text are untouched: " + slot)
	_check(_snap(service.quote()["state"]) == state_before, "a later quote state is untouched")
	var copied := service.read_state()
	copied["candidates"][0]["parts"]["head"]["tampered"] = true
	_check(_snap(service.read_state()) == state_before, "mutating a copied state does not reach the visit")
	_check(_snap(service.quote()["candidates"][0]) == _snap(again), "repeated quotes are identical")

	# A left visit offers no candidates.
	var left_service := _service()
	_check(bool(left_service.leave(NODE, left_service.read_state())["ok"]), "visit is left")
	var left_quote := left_service.quote()
	_check(left_quote["candidates"].is_empty() and not bool(left_quote["can_replace"]), "left visit quotes no candidates")


func _test_replace_receipt() -> void:
	var party := _party()
	var service := RunStitchedSewingReplacement.new(NODE, party, [_scarecrow()], catalog)
	var before := service.read_state()
	var receipt := service.replace("doll_c", "scarecrow", NODE, before)
	_check(bool(receipt["ok"]) and str(receipt["action"]) == "replace", "replace succeeds")
	if not bool(receipt["ok"]):
		return
	_check(int(receipt["rank"]) == 3 and int(receipt["party_index"]) == 2, "Scarecrow takes rank 3 / party index 2")
	_check(str(receipt["lost_id"]) == "doll_c" and str(receipt["candidate_id"]) == "scarecrow", "receipt names both dolls")
	_check(_snap(receipt["source_state"]) == _snap(before), "receipt carries the authentic source state")
	_check(_snap(receipt["hero_before"]) == _snap(before["party"][2]) and bool(receipt["hero_before"]["lost"]), "receipt carries the LOST record")
	var hero: Dictionary = receipt["hero_after"]
	_check(str(hero["id"]) == "scarecrow" and int(hero["rank"]) == 3 and not bool(hero["lost"]), "installed record is Scarecrow at rank 3, not lost")
	_check(int(hero["max_hp"]) == 34 and int(hero["hp"]) == 34, "Scarecrow keeps its own profile HP 34/34, no bonus")
	for slot in STARTERS:
		_check(_snap(hero["parts"][slot]) == _snap(_worn(STARTERS[slot])), "Scarecrow wears its actual starter " + slot)
	_check(receipt["unchanged_ids"] == ["doll_a", "doll_b", "doll_d"], "receipt lists the three preserved dolls")
	_check(receipt["changed_heroes"].size() == 1 and _snap(receipt["changed_heroes"][0]) == _snap(hero), "exactly one changed hero")
	_check(int(receipt["charged_gold"]) == 0 and int(receipt["charged_scraps"]) == 0 and int(receipt["healed"]) == 0, "no fee and no healing")
	var after: Dictionary = receipt["state"]
	_check(_snap(after) == _snap(service.read_state()), "receipt state is the authoritative state")
	_check(not bool(after["open"]) and int(after["version"]) == 1, "visit closed after one replacement")
	_check(after["party"].size() == 4, "party still has four dolls")
	for index in [0, 1, 3]:
		_check(_snap(after["party"][index]) == _snap(before["party"][index]), "doll at index %d is byte-for-byte unchanged" % index)
		_check(_snap(after["party"][index]) == _snap(party[index]), "doll at index %d matches the caller's record" % index)
	var ranks: Array = []
	for member in after["party"]:
		ranks.append(int(member["rank"]))
	_check(ranks == [1, 2, 3, 4], "ranks stay 1-4 in party order")
	_check(_snap(after["candidates"]) == _snap(before["candidates"]), "prepared candidate template list is unchanged")
	# Receipt is detached from the visit.
	receipt["state"]["party"][2]["id"] = "tampered"
	receipt["hero_after"]["parts"]["head"]["id"] = "tampered"
	_check(str(service.read_state()["party"][2]["id"]) == "scarecrow" and str(service.read_state()["party"][2]["parts"]["head"]["id"]) == STARTERS["head"], "mutating a receipt does not reach the visit")
	_check(not bool(service.quote()["can_replace"]) and service.quote()["candidates"].is_empty(), "closed visit quotes no candidates")
	_check(not bool(service.quote()["leave"]["available"]), "closed visit has no Leave")


func _test_rejections() -> void:
	var service := _service()
	var state := service.read_state()
	var baseline := _snap(state)
	var forged_party := state.duplicate(true)
	forged_party["party"][2]["hp"] = 99
	var forged_candidate := state.duplicate(true)
	forged_candidate["candidates"][0]["max_hp"] = 50
	var forged_lost := state.duplicate(true)
	forged_lost["party"][0]["lost"] = true
	var stale := state.duplicate(true)
	stale["version"] = 5
	var table := [
		["wrong node", "doll_c", "scarecrow", "other_node", state],
		["missing node", "doll_c", "scarecrow", null, state],
		["integer node", "doll_c", "scarecrow", 7, state],
		["missing state", "doll_c", "scarecrow", NODE, null],
		["array state", "doll_c", "scarecrow", NODE, []],
		["empty state", "doll_c", "scarecrow", NODE, {}],
		["stale version", "doll_c", "scarecrow", NODE, stale],
		["forged party hp", "doll_c", "scarecrow", NODE, forged_party],
		["forged candidate template", "doll_c", "scarecrow", NODE, forged_candidate],
		["forged lost flag", "doll_c", "scarecrow", NODE, forged_lost],
		["unknown doll", "doll_z", "scarecrow", NODE, state],
		["non-string doll", 3, "scarecrow", NODE, state],
		["non-string candidate", "doll_c", 3, NODE, state],
		["null ids", null, null, NODE, state],
		["unknown candidate", "doll_c", "yarn_ranger", NODE, state],
		["forged candidate id", "doll_c", "scarecrow ", NODE, state],
		["candidate is a party member", "doll_c", "doll_a", NODE, state],
		["hanging doll is not lost", "doll_b", "scarecrow", NODE, state],
		["healthy doll is not lost", "doll_a", "scarecrow", NODE, state],
		["empty ids", "", "", NODE, state],
	]
	for row in table:
		var result: Dictionary = service.replace(row[1], row[2], row[3], row[4])
		_check(not bool(result["ok"]) and not str(result["error"]).is_empty(), "replace refused: " + str(row[0]))
		_check(_snap(service.read_state()) == baseline, "refusal changes nothing: " + str(row[0]))
	_check(bool(service.read_state()["open"]) and int(service.read_state()["version"]) == 0, "refusals never consume the visit")
	var bad_leave := service.leave("other_node", state)
	_check(not bool(bad_leave["ok"]) and _snap(service.read_state()) == baseline, "Leave with wrong node refused without effect")
	bad_leave = service.leave(NODE, stale)
	_check(not bool(bad_leave["ok"]) and _snap(service.read_state()) == baseline, "Leave with stale state refused without effect")
	# After every refusal the legitimate action still works exactly once.
	var good := service.replace("doll_c", "scarecrow", NODE, service.read_state())
	_check(bool(good["ok"]) and str(good["hero_after"]["id"]) == "scarecrow", "valid replace still works after refusals")


func _test_leave() -> void:
	var service := _service()
	var state := service.read_state()
	var left := service.leave(NODE, state)
	_check(bool(left["ok"]) and str(left["action"]) == "leave" and left["changed_heroes"].is_empty(), "Leave succeeds with no change")
	_check(_snap(left["source_state"]) == _snap(state), "Leave receipt carries the source state")
	var after: Dictionary = left["state"]
	_check(not bool(after["open"]) and int(after["version"]) == 1, "Leave closes the visit")
	_check(_snap(after["party"]) == _snap(state["party"]) and _snap(after["candidates"]) == _snap(state["candidates"]), "Leave leaves party and candidates untouched")
	_check(not left.has("charged_gold") and not left.has("charged_scraps"), "Leave carries no fee")
	var again := service.leave(NODE, after)
	_check(not bool(again["ok"]), "Leave is one-use")
	var replace_after := service.replace("doll_c", "scarecrow", NODE, after)
	_check(not bool(replace_after["ok"]), "no replacement after Leave")
	_check(_snap(service.read_state()) == _snap(after), "closed visit state is stable")
	# Leave without any LOST doll is free too.
	var healthy := RunStitchedSewingReplacement.new(NODE, _party(-1), [_scarecrow()], catalog)
	var healthy_state := healthy.read_state()
	var healthy_left := healthy.leave(NODE, healthy_state)
	_check(bool(healthy_left["ok"]) and _snap(healthy_left["state"]["party"]) == _snap(healthy_state["party"]), "Leave with no LOST doll succeeds unchanged")


func _test_closed_and_replay() -> void:
	var service := _service()
	var first := service.replace("doll_c", "scarecrow", NODE, service.read_state())
	_check(bool(first["ok"]), "first replacement succeeds")
	var closed_state := service.read_state()
	var replay := service.replace("doll_c", "scarecrow", NODE, first["source_state"])
	_check(not bool(replay["ok"]), "replaying the old state fails")
	replay = service.replace("doll_c", "scarecrow", NODE, closed_state)
	_check(not bool(replay["ok"]), "replaying with the current state fails (visit closed)")
	replay = service.replace("scarecrow", "scarecrow", NODE, closed_state)
	_check(not bool(replay["ok"]), "no second action on the installed doll")
	_check(_snap(service.read_state()) == _snap(closed_state), "replays change nothing")
	# Two LOST dolls: one visit still replaces only one.
	var party := _party()
	party[0]["lost"] = true
	party[0]["hp"] = 0
	party[0]["parts"] = {}
	var two_lost := RunStitchedSewingReplacement.new(NODE, party, [_scarecrow(), _scarecrow_variant()], catalog)
	_check(bool(two_lost.read_state()["ok"]), "party with two LOST dolls is admitted")
	_check(two_lost.quote()["lost"].size() == 2 and two_lost.quote()["candidates"].size() == 2, "quote lists both LOST dolls and both candidates")
	var one := two_lost.replace("doll_a", "scarecrow", NODE, two_lost.read_state())
	_check(bool(one["ok"]) and int(one["rank"]) == 1 and int(one["party_index"]) == 0, "first LOST doll is replaced at its own rank 1")
	var two := two_lost.replace("doll_c", "warden", NODE, two_lost.read_state())
	_check(not bool(two["ok"]), "visit allows only one replacement")
	_check(bool(two_lost.read_state()["party"][2]["lost"]) and str(two_lost.read_state()["party"][2]["id"]) == "doll_c", "second LOST doll untouched")


## A second prepared candidate built only from the Scarecrow catalog entries but with a distinct hero id would
## fail the owner check, so reuse owner ids: the catalog's Scarecrow parts only ever admit hero "scarecrow".
## This second template is therefore a copy of the Warden-owned starter set under the real hero id "warden".
func _scarecrow_variant() -> Dictionary:
	var parts := {
		"head": _worn("warden_head_pot_helm_bonk"),
		"arms": _worn("warden_arms_shield_catch"),
		"torso": _worn("warden_torso_iron_challenge"),
		"legs": _worn("warden_legs_rim_toss"),
	}
	var owner := str(catalog["warden_head_pot_helm_bonk"]["owner"])
	for slot in parts:
		if str(catalog[parts[slot]["id"]]["owner"]) != owner:
			return {"id": "unowned", "max_hp": 1, "hp": 1, "parts": parts}
	return {"id": owner, "name": "Second candidate", "max_hp": 40, "hp": 40, "parts": parts}
