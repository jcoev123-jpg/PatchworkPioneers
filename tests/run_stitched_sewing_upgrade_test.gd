extends SceneTree
## Design v4 (Stitched) Sewing Circle paid one-tier upgrade service (RunStitchedSewingUpgrade).
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
		_test_ac1_quote_projections_and_admission()
		_test_ac2_tier_upgrades_and_replay()
		_test_ac3_rejections_and_leave()
	_check(rng.state == rng_state_before, "seeded RNG state must be unchanged")
	if failures.is_empty():
		print("run_stitched_sewing_upgrade_test: PASS")
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
	return catalog.has("warden_head_pot_helm_bonk") and catalog.has("warden_arms_rivet_pummel") and catalog.has("warden_legs_shield_toss")


func _worn(id: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn}


## Local four-hero roster with opaque run fields. Hero "a" wears Pot Helm Bonk at tier I, hero "b" a
## tier-III legs part, hero "c" a torn tier-II arms part, hero "d" is whole.
func _party() -> Array:
	var gear := [
		{"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch"), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_rim_toss")},
		{"head": _worn("warden_head_helmet_rattle"), "arms": _worn("warden_arms_rivet_pummel"), "torso": _worn("warden_torso_buckle_rebound"), "legs": _worn("warden_legs_shield_toss", 3)},
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
			"max_hp": 20 + index,
			"fray": 3 * index,
			"gold": index,
			"candle": 5 - index,
			"statuses": {"weak": index},
			"rank": index + 1,
			"extra": {"nested": [index, "opaque"]},
		})
	return heroes


func _service(scraps: int = 5, cost: int = 2, heroes: Array = [], node: String = NODE) -> RunStitchedSewingUpgrade:
	if heroes.is_empty():
		heroes = _party()
	return RunStitchedSewingUpgrade.new(node, heroes, scraps, cost, catalog)


func _hero(state: Dictionary, hero_id: String) -> Dictionary:
	for hero in state["heroes"]:
		if str(hero["id"]) == hero_id:
			return hero
	return {}


func _slot_quote(quote: Dictionary, hero_id: String, slot: String) -> Dictionary:
	for hero_quote in quote["heroes"]:
		if str(hero_quote["hero_id"]) == hero_id:
			for slot_quote in hero_quote["slots"]:
				if str(slot_quote["slot"]) == slot:
					return slot_quote
	return {}


func _test_ac1_quote_projections_and_admission() -> void:
	var heroes := _party()
	var heroes_before := _snap(heroes)
	var svc := _service(5, 2, heroes)
	var state := svc.read_state()
	_check(bool(state["ok"]) and bool(state["open"]) and str(state["node_id"]) == NODE, "opening state is open at the node")
	_check(int(state["version"]) == 0 and int(state["scraps"]) == 5 and int(state["upgrade_cost"]) == 2, "opening state carries version, balance and quoted price")
	_check(_snap(state["heroes"]) == heroes_before, "state heroes equal the supplied roster")
	var quote := svc.quote()
	_check(bool(quote["ok"]) and int(quote["scraps"]) == 5 and int(quote["upgrade_cost"]) == 2, "quote shows balance and price")
	_check(_snap(quote["state"]) == _snap(state), "quote embeds the authoritative state")
	# Pot Helm Bonk authored projections: tier I acc 90 dmg [4,6], tier II dmg [5,8], tier III acc 95 dmg [7,10].
	var head_a := _slot_quote(quote, "hero_a", "head")
	_check(str(head_a["worn"]["id"]) == "warden_head_pot_helm_bonk" and int(head_a["current_tier"]) == 1 and int(head_a["next_tier"]) == 2, "hero_a head quotes tier I -> II")
	_check(int(head_a["current_ability"]["acc"]) == 90 and head_a["current_ability"]["dmg"] == [4, 6], "tier I ability is acc 90 dmg [4,6]")
	_check(int(head_a["next_ability"]["acc"]) == 90 and head_a["next_ability"]["dmg"] == [5, 8], "tier II ability is acc 90 dmg [5,8]")
	_check(bool(head_a["can_upgrade"]) and str(head_a["blocked"]).is_empty() and int(head_a["cost"]) == 2, "hero_a head is upgradeable at the quoted price")
	# tier III part reports no next tier and is blocked.
	var legs_b := _slot_quote(quote, "hero_b", "legs")
	_check(int(legs_b["current_tier"]) == 3 and int(legs_b["next_tier"]) == 0, "tier III slot has no next tier")
	_check(not bool(legs_b["can_upgrade"]) and str(legs_b["blocked"]) == "part is already at tier III", "tier III explains the blocked purchase")
	_check(legs_b["next_ability"].is_empty() and legs_b["next_stat"].is_empty(), "tier III shows no false prospective details")
	# torn part is blocked until mended.
	var arms_c := _slot_quote(quote, "hero_c", "arms")
	_check(not bool(arms_c["can_upgrade"]) and str(arms_c["blocked"]) == "part is torn: mend it first", "torn part explains mend-first")
	# Real authored effects/crit tier changes survive in the quoted projections.
	var arms_a := _slot_quote(quote, "hero_a", "arms")
	_check(int(arms_a["current_ability"]["effects"]["guard"]) == 2 and int(arms_a["next_ability"]["effects"]["guard"]) == 3, "Shield Catch quotes Guard 2 -> 3")
	_check(str(arms_a["current_ability"]["id"]) == "arms_shield_catch_move" and str(arms_a["current_ability"]["target_side"]) == "ally", "current ability keeps every authored field")
	_check(arms_a["current_ability"] == StitchedParts.ability_at_tier(catalog["warden_arms_shield_catch"], 1), "current ability equals the catalog resolution")
	_check(arms_a["next_ability"] == StitchedParts.ability_at_tier(catalog["warden_arms_shield_catch"], 2), "next ability equals the catalog resolution")
	_check(arms_a["worn"]["ability"] == StitchedParts.ability_at_tier(catalog["warden_arms_shield_catch"], 1), "worn summary carries the full ability")
	var rattle_b := _slot_quote(quote, "hero_b", "head")
	_check(int(rattle_b["current_ability"]["crit"]) == 0 and int(rattle_b["next_ability"]["crit"]) == 0, "Helmet Rattle tiers I and II have crit 0")
	_check(rattle_b["next_ability"]["dmg"] == [5, 7], "Helmet Rattle tier II dmg [5,7]")
	# Tier-II Shield Catch -> III (Guard 3 -> 4) and Helmet Rattle tier III crit 8 via upgraded services.
	var tier_party := _party()
	tier_party[0]["parts"]["arms"]["tier"] = 2
	tier_party[1]["parts"]["head"]["tier"] = 2
	var tier_svc := _service(5, 2, tier_party)
	var tier_quote := tier_svc.quote()
	var arms_t2 := _slot_quote(tier_quote, "hero_a", "arms")
	_check(int(arms_t2["current_ability"]["effects"]["guard"]) == 3 and int(arms_t2["next_ability"]["effects"]["guard"]) == 4, "Shield Catch quotes Guard 3 -> 4")
	var head_t2 := _slot_quote(tier_quote, "hero_b", "head")
	_check(int(head_t2["next_ability"]["crit"]) == 8 and head_t2["next_ability"]["dmg"] == [6, 9], "Helmet Rattle tier III shows crit 8 and dmg [6,9]")
	var tier_receipt := tier_svc.upgrade("hero_b", "head", NODE, tier_svc.read_state())
	_check(bool(tier_receipt["ok"]), "Helmet Rattle upgrades to tier III")
	var rattle_t3 := _slot_quote(tier_svc.quote(), "hero_b", "head")
	_check(int(rattle_t3["current_ability"]["crit"]) == 8 and rattle_t3["next_ability"].is_empty() and rattle_t3["next_stat"].is_empty(), "tier III quotes crit 8 and an empty next")
	# Mutation isolation for nested returned ability data.
	var iso := _service(5, 2)
	var iso_quote := iso.quote()
	var iso_arms := _slot_quote(iso_quote, "hero_a", "arms")
	iso_arms["current_ability"]["effects"]["guard"] = 99
	iso_arms["next_ability"]["effects"]["guard"] = 99
	iso_arms["next_ability"]["launch"].append(9)
	iso_arms["worn"]["ability"]["effects"]["guard"] = 99
	iso_arms["worn"]["ability"]["target"].clear()
	var iso_again := _slot_quote(iso.quote(), "hero_a", "arms")
	_check(int(iso_again["current_ability"]["effects"]["guard"]) == 2 and int(iso_again["next_ability"]["effects"]["guard"]) == 3, "mutating quoted effects never reaches the service")
	_check(iso_again["next_ability"]["launch"] == [1, 2] and iso_again["worn"]["ability"]["target"] == [1, 2, 3, 4], "mutating quoted arrays never reaches the service")
	_check(int(catalog["warden_arms_shield_catch"]["ability"]["effects"]["guard"]) == 2, "quote mutation never reaches the catalog")
	# every slot quotes the caller price and deep-copied details.
	for hero_quote in quote["heroes"]:
		for slot_quote in hero_quote["slots"]:
			_check(int(slot_quote["cost"]) == 2, "every slot quotes the caller price")
	# Deep copies: mutating inputs or returned snapshots never reaches the service.
	heroes[2]["parts"]["arms"]["torn"] = false
	heroes[0]["hp"] = 99
	state["heroes"][0]["parts"]["head"]["tier"] = 3
	state["scraps"] = 100
	quote["heroes"].clear()
	var again := svc.read_state()
	_check(bool(_hero(again, "hero_c")["parts"]["arms"]["torn"]), "service keeps its own torn flag")
	_check(int(again["scraps"]) == 5 and int(_hero(again, "hero_a")["hp"]) == 10, "service keeps its own balance and hero fields")
	_check(int(_hero(again, "hero_a")["parts"]["head"]["tier"]) == 1, "service keeps its own tier")
	_check(int(again["version"]) == 0, "reading and quoting never advance the version")
	# Admission refusals: malformed roster, catalog and price.
	var bad_inputs := [
		{"name": "zero price", "node": NODE, "scraps": 5, "cost": 0},
		{"name": "negative price", "node": NODE, "scraps": 5, "cost": -2},
		{"name": "string price", "node": NODE, "scraps": 5, "cost": "2"},
		{"name": "float price", "node": NODE, "scraps": 5, "cost": 2.5},
		{"name": "null price", "node": NODE, "scraps": 5, "cost": null},
		{"name": "negative scraps", "node": NODE, "scraps": -1, "cost": 2},
		{"name": "string scraps", "node": NODE, "scraps": "5", "cost": 2},
		{"name": "empty node", "node": "", "scraps": 5, "cost": 2},
		{"name": "padded node", "node": " node ", "scraps": 5, "cost": 2},
		{"name": "non-string node", "node": 7, "scraps": 5, "cost": 2},
	]
	for entry in bad_inputs:
		var bad := RunStitchedSewingUpgrade.new(entry["node"], _party(), entry["scraps"], entry["cost"], catalog)
		var bad_state := bad.read_state()
		_check(not bool(bad_state["ok"]) and not str(bad_state["error"]).is_empty(), "constructor refuses: " + str(entry["name"]))
		_check(not bool(bad.quote()["ok"]), "quote refuses: " + str(entry["name"]))
		_check(not bool(bad.upgrade("hero_a", "head", entry["node"], bad_state)["ok"]), "upgrade refuses: " + str(entry["name"]))
		_check(not bool(bad.leave(entry["node"], bad_state)["ok"]), "leave refuses: " + str(entry["name"]))
	var bad_rosters: Array = []
	var no_parts := _party()
	no_parts[0].erase("parts")
	bad_rosters.append(no_parts)
	var duplicate := _party()
	duplicate[1]["id"] = "hero_a"
	bad_rosters.append(duplicate)
	var dup_rank := _party()
	dup_rank[1]["rank"] = 1
	bad_rosters.append(dup_rank)
	var bad_rank := _party()
	bad_rank[3]["rank"] = 9
	bad_rosters.append(bad_rank)
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
	var empty_roster: Array = []
	bad_rosters.append(empty_roster)
	var five := _party()
	five.append({"id": "hero_e", "name": "Doll hero_e", "rank": 4, "parts": _party()[0]["parts"]})
	bad_rosters.append(five)
	var five_ranked := _party()
	five_ranked.append({"id": "hero_e", "name": "Doll hero_e", "rank": 5, "parts": _party()[0]["parts"]})
	bad_rosters.append(five_ranked)
	for roster in bad_rosters:
		_check(not bool(RunStitchedSewingUpgrade.new(NODE, roster, 5, 2, catalog).read_state()["ok"]), "constructor refuses a malformed roster")
	_check(not bool(RunStitchedSewingUpgrade.new(NODE, _party(), 5, 2, {}).read_state()["ok"]), "empty catalog refused")
	_check(not bool(RunStitchedSewingUpgrade.new(NODE, _party(), 5, 2, "catalog").read_state()["ok"]), "non-dictionary catalog refused")
	_check(not bool(RunStitchedSewingUpgrade.new(NODE, "roster", 5, 2, catalog).read_state()["ok"]), "non-array roster refused")
	_test_survivor_rosters()


## Reduced rosters (one or more dolls LOST) must still open and upgrade one legal tier at the quoted fee.
func _test_survivor_rosters() -> void:
	var cases := [
		{"name": "three survivors", "keep": [0, 1, 2], "ranks": [1, 2, 3], "hero": "hero_a", "slot": "head"},
		{"name": "two survivors", "keep": [0, 3], "ranks": [2, 4], "hero": "hero_d", "slot": "torso"},
		{"name": "one survivor", "keep": [3], "ranks": [1], "hero": "hero_d", "slot": "legs"},
		{"name": "gapped ranks 1,3,4", "keep": [0, 2, 3], "ranks": [1, 3, 4], "hero": "hero_d", "slot": "arms"},
	]
	for entry in cases:
		var party := _party()
		var roster: Array = []
		var ranks: Array = entry["ranks"]
		for position in range(entry["keep"].size()):
			var hero: Dictionary = party[int(entry["keep"][position])]
			hero["rank"] = int(ranks[position])
			roster.append(hero)
		var roster_before := _snap(roster)
		var svc := _service(5, 2, roster)
		var state := svc.read_state()
		var label := str(entry["name"])
		_check(bool(state["ok"]) and bool(state["open"]) and state["heroes"].size() == roster.size(), label + ": roster admitted")
		_check(_snap(state["heroes"]) == roster_before, label + ": state heroes equal the survivors")
		var quote := svc.quote()
		_check(bool(quote["ok"]) and quote["heroes"].size() == roster.size(), label + ": quote lists only the survivors")
		var slot_quote := _slot_quote(quote, str(entry["hero"]), str(entry["slot"]))
		_check(not slot_quote.is_empty() and bool(slot_quote["can_upgrade"]) and int(slot_quote["next_tier"]) == 2 and int(slot_quote["cost"]) == 2, label + ": a tier I part is offered at the quoted fee")
		var receipt := svc.upgrade(str(entry["hero"]), str(entry["slot"]), NODE, state)
		_check(bool(receipt["ok"]), label + ": upgrade succeeds")
		if not bool(receipt["ok"]):
			continue
		_check(int(receipt["tier_before"]) == 1 and int(receipt["tier_after"]) == 2, label + ": exactly one tier")
		_check(int(receipt["charged_scraps"]) == 2 and int(receipt["scraps_before"]) == 5 and int(receipt["scraps"]) == 3, label + ": 5 scraps becomes 3")
		_check(int(receipt["state"]["version"]) == int(state["version"]) + 1, label + ": version advances once")
		_check(_snap(receipt["source_state"]) == _snap(state), label + ": receipt source is the presented snapshot")
		var expected := state.duplicate(true)
		for hero in expected["heroes"]:
			if str(hero["id"]) == str(entry["hero"]):
				hero["parts"][str(entry["slot"])]["tier"] = 2
		expected["scraps"] = 3
		expected["version"] = int(state["version"]) + 1
		_check(_snap(receipt["state"]) == _snap(expected), label + ": only that tier, SCRAPS and version changed")
		var stale := svc.upgrade(str(entry["hero"]), str(entry["slot"]), NODE, state)
		_check(not bool(stale["ok"]) and str(stale["error"]) == "stale or forged state", label + ": stale snapshot refused")
		_check(int(svc.read_state()["scraps"]) == 3, label + ": stale attempt spent nothing")
		var twin_roster: Array = []
		for hero in state["heroes"]:
			twin_roster.append(hero.duplicate(true))
		var twin := _service(5, 2, twin_roster)
		var twin_receipt := twin.upgrade(str(entry["hero"]), str(entry["slot"]), NODE, twin.read_state())
		_check(bool(twin_receipt["ok"]) and _snap(twin_receipt["state"]) == _snap(receipt["state"]), label + ": independent replay matches")
		var left := svc.leave(NODE, receipt["state"])
		_check(bool(left["ok"]) and int(left["charged_scraps"]) == 0 and int(left["scraps"]) == 3, label + ": leave is free")
	# A lost doll in a reduced roster still cannot upgrade, and HP 0 (hanging) is not lost.
	var lost_roster := _party()
	lost_roster.remove_at(1)
	lost_roster[0]["lost"] = true
	lost_roster[1]["hp"] = 0
	var lost_svc := _service(5, 2, lost_roster)
	var lost_state := lost_svc.read_state()
	_check(bool(lost_state["ok"]), "reduced roster with a lost doll opens")
	var lost_before := _snap(lost_state)
	var lost_result := lost_svc.upgrade("hero_a", "head", NODE, lost_state)
	_check(not bool(lost_result["ok"]) and str(lost_result["error"]) == "hero is lost", "lost doll in a reduced roster cannot upgrade")
	_check(_snap(lost_svc.read_state()) == lost_before, "lost refusal changes nothing in a reduced roster")
	var hanging := lost_svc.upgrade("hero_c", "head", NODE, lost_svc.read_state())
	_check(bool(hanging["ok"]) and int(hanging["tier_after"]) == 2, "HP 0 hanging doll is not lost and may upgrade")


func _test_ac2_tier_upgrades_and_replay() -> void:
	var svc := _service(5, 2)
	var source := svc.read_state()
	var first := svc.upgrade("hero_a", "head", NODE, source)
	_check(bool(first["ok"]) and str(first["action"]) == "upgrade", "tier I -> II upgrade succeeds")
	if not bool(first["ok"]):
		return
	_check(str(first["hero_id"]) == "hero_a" and str(first["slot"]) == "head" and str(first["part_id"]) == "warden_head_pot_helm_bonk", "receipt names hero, slot and part")
	_check(int(first["tier_before"]) == 1 and int(first["tier_after"]) == 2, "receipt reports tier I -> II")
	_check(int(first["charged_scraps"]) == 2 and int(first["scraps_before"]) == 5 and int(first["scraps"]) == 3, "5 scraps with a quoted price of 2 leaves exactly 3")
	_check(_snap(first["source_state"]) == _snap(source), "receipt source_state is the exact presented snapshot")
	_check(_snap(first["state"]) == _snap(svc.read_state()), "receipt state is the new authoritative state")
	_check(int(first["state"]["version"]) == int(source["version"]) + 1, "version advances by exactly one")
	# Full state diff: only the one tier and SCRAPS changed.
	var expected: Array = source["heroes"].duplicate(true)
	for hero in expected:
		if str(hero["id"]) == "hero_a":
			hero["parts"]["head"]["tier"] = 2
	var expected_state := source.duplicate(true)
	expected_state["heroes"] = expected
	expected_state["scraps"] = 3
	expected_state["version"] = int(source["version"]) + 1
	_check(_snap(first["state"]) == _snap(expected_state), "only the worn tier and SCRAPS changed")
	_check(str(_hero(first["state"], "hero_a")["parts"]["head"]["id"]) == "warden_head_pot_helm_bonk", "same worn part id after upgrade")
	# A future upgrade in the same visit must use the newest returned state; never direct I -> III.
	var stale := svc.upgrade("hero_a", "head", NODE, source)
	_check(not bool(stale["ok"]) and str(stale["error"]) == "stale or forged state", "stale snapshot cannot upgrade again")
	_check(int(svc.read_state()["scraps"]) == 3, "stale attempt spent nothing")
	var second := svc.upgrade("hero_a", "head", NODE, first["state"])
	_check(bool(second["ok"]), "second upgrade uses the fresh snapshot")
	if not bool(second["ok"]):
		return
	_check(int(second["tier_before"]) == 2 and int(second["tier_after"]) == 3, "second upgrade is II -> III")
	_check(int(second["charged_scraps"]) == 2 and int(second["scraps_before"]) == 3 and int(second["scraps"]) == 1, "second upgrade charges exactly the price once")
	_check(_snap(second["source_state"]) == _snap(first["state"]), "second receipt's source is the first receipt's state")
	_check(int(second["state"]["version"]) == int(source["version"]) + 2, "version is monotonic across upgrades")
	var head_after: Dictionary = _hero(second["state"], "hero_a")["parts"]["head"]
	_check(str(head_after["id"]) == "warden_head_pot_helm_bonk" and int(head_after["tier"]) == 3 and not bool(head_after["torn"]), "worn head is the same part at tier III")
	# Authored tier III projection on the quote: acc 95 dmg [7,10].
	var q := svc.quote()
	var head_q := _slot_quote(q, "hero_a", "head")
	_check(int(head_q["current_tier"]) == 3 and int(head_q["next_tier"]) == 0, "quote now shows tier III with no next")
	_check(not bool(head_q["can_upgrade"]) and str(head_q["blocked"]) == "part is already at tier III", "tier III cannot upgrade further")
	_check(int(head_q["current_ability"]["acc"]) == 95 and head_q["current_ability"]["dmg"] == [7, 10], "tier III ability is authored acc 95 dmg [7,10]")
	# Replays of any older snapshot fail closed and spend nothing.
	for replay_state in [source, first["state"], second["source_state"]]:
		var replay := svc.upgrade("hero_a", "head", NODE, replay_state)
		_check(not bool(replay["ok"]), "replayed snapshot refused")
	_check(int(svc.read_state()["scraps"]) == 1, "replays spend nothing")
	# Independent seeded replay: a fresh identical service reaches the same state.
	var twin := _service(5, 2)
	var t1 := twin.upgrade("hero_a", "head", NODE, twin.read_state())
	var t2 := twin.upgrade("hero_a", "head", NODE, t1["state"])
	_check(bool(t2["ok"]) and _snap(t2["state"]) == _snap(second["state"]), "independent seeded replay reaches the identical state")


func _test_ac3_rejections_and_leave() -> void:
	var svc := _service(5, 2)
	var state := svc.read_state()
	var forged_scraps := state.duplicate(true)
	forged_scraps["scraps"] = 50
	var forged_tier := state.duplicate(true)
	forged_tier["heroes"][0]["parts"]["head"]["tier"] = 3
	var forged_cost := state.duplicate(true)
	forged_cost["upgrade_cost"] = 1
	var cases := [
		{"name": "wrong node", "hero": "hero_a", "slot": "head", "node": "other_node", "state": state},
		{"name": "non-string node", "hero": "hero_a", "slot": "head", "node": 5, "state": state},
		{"name": "forged balance", "hero": "hero_a", "slot": "head", "node": NODE, "state": forged_scraps},
		{"name": "forged tier", "hero": "hero_a", "slot": "head", "node": NODE, "state": forged_tier},
		{"name": "forged price", "hero": "hero_a", "slot": "head", "node": NODE, "state": forged_cost},
		{"name": "state not a dictionary", "hero": "hero_a", "slot": "head", "node": NODE, "state": "state"},
		{"name": "unknown hero", "hero": "hero_z", "slot": "head", "node": NODE, "state": state},
		{"name": "non-string hero", "hero": 3, "slot": "head", "node": NODE, "state": state},
		{"name": "unknown slot", "hero": "hero_a", "slot": "tail", "node": NODE, "state": state},
		{"name": "non-string slot", "hero": "hero_a", "slot": null, "node": NODE, "state": state},
		{"name": "tier III part", "hero": "hero_b", "slot": "legs", "node": NODE, "state": state},
		{"name": "torn part", "hero": "hero_c", "slot": "arms", "node": NODE, "state": state},
	]
	var before := _snap(svc.read_state())
	for entry in cases:
		var result := svc.upgrade(entry["hero"], entry["slot"], entry["node"], entry["state"])
		_check(not bool(result["ok"]) and not str(result["error"]).is_empty(), "refused: " + str(entry["name"]))
		_check(_snap(svc.read_state()) == before, "nothing changed after refusal: " + str(entry["name"]))
	# A lost hero cannot buy an upgrade.
	var lost_party := _party()
	lost_party[3]["lost"] = true
	var lost_svc := _service(5, 2, lost_party)
	var lost_before := _snap(lost_svc.read_state())
	var lost_result := lost_svc.upgrade("hero_d", "head", NODE, lost_svc.read_state())
	_check(not bool(lost_result["ok"]) and str(lost_result["error"]) == "hero is lost", "lost hero cannot upgrade")
	_check(_snap(lost_svc.read_state()) == lost_before, "lost hero refusal changes nothing")
	var lost_quote := lost_svc.quote()
	_check(not bool(_slot_quote(lost_quote, "hero_d", "head")["can_upgrade"]), "quote blocks the lost hero")
	# Insufficient scraps.
	for scraps in [0, 1]:
		var poor := _service(scraps, 2)
		var poor_before := _snap(poor.read_state())
		var poor_quote := poor.quote()
		for hero_quote in poor_quote["heroes"]:
			for slot_quote in hero_quote["slots"]:
				if str(hero_quote["hero_id"]) == "hero_a" and str(slot_quote["slot"]) == "head":
					_check(not bool(slot_quote["can_upgrade"]) and str(slot_quote["blocked"]) == "insufficient scraps", "quote blocks at %d scraps" % scraps)
		var poor_result := poor.upgrade("hero_a", "head", NODE, poor.read_state())
		_check(not bool(poor_result["ok"]) and str(poor_result["error"]) == "insufficient scraps", "insufficient scraps refused at %d" % scraps)
		_check(_snap(poor.read_state()) == poor_before, "insufficient scraps change nothing at %d" % scraps)
	# Exactly the price is enough and SCRAPS never goes negative.
	var exact := _service(2, 2)
	var exact_result := exact.upgrade("hero_a", "head", NODE, exact.read_state())
	_check(bool(exact_result["ok"]) and int(exact_result["scraps"]) == 0, "exactly the price is enough and leaves zero")
	# A legal Leave from an open visit remains free after all refusals.
	var left := svc.leave(NODE, state)
	_check(bool(left["ok"]) and str(left["action"]) == "leave" and left["changed_heroes"].is_empty(), "leave succeeds with no changed hero")
	_check(int(left["charged_scraps"]) == 0 and int(left["scraps"]) == 5, "leave charges nothing")
	var closed := svc.read_state()
	_check(not bool(closed["open"]) and int(closed["version"]) == 1, "visit is closed with a bumped version")
	_check(_snap(closed["heroes"]) == _snap(state["heroes"]), "leave changes no hero")
	var after_close := svc.upgrade("hero_a", "head", NODE, closed)
	_check(not bool(after_close["ok"]) and str(after_close["error"]) == "visit is closed", "closed visit refuses an upgrade")
	_check(not bool(svc.leave(NODE, closed)["ok"]), "closed visit refuses a second leave")
	_check(_snap(svc.read_state()) == _snap(closed), "closed visit is unchanged by refusals")
	var closed_quote := svc.quote()
	for hero_quote in closed_quote["heroes"]:
		for slot_quote in hero_quote["slots"]:
			_check(not bool(slot_quote["can_upgrade"]) and str(slot_quote["blocked"]) == "visit closed", "closed visit offers no upgrade")
	# Upgrade then leave: the receipt state is accepted by leave.
	var svc2 := _service(5, 2)
	var upgraded := svc2.upgrade("hero_a", "head", NODE, svc2.read_state())
	var left2 := svc2.leave(NODE, upgraded["state"])
	_check(bool(left2["ok"]) and int(left2["scraps"]) == 3, "leave after an upgrade keeps the remaining scraps")
