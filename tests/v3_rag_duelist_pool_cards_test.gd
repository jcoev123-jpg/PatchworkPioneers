extends SceneTree
## V3-1 Rag Duelist catalog contract. No live combat/reward/Rest behavior is assumed.
##
## The same real seeded CombatDeck and three-hero CombatParty fixtures also drive the scene-free
## CombatRagDuelistRiposteCards service for all six Cape Parry / Cape Guard / Duelist Reprise
## printings: one paid play, the printed Block, Riposte N on the owning hero, the canonical
## confirmed-hit projection, one owner-turn expiry, and fail-closed rejection snapshots. Like the
## Feint helper, this is callable rules-layer behaviour only: no live hand, reward, app or run-deck
## wiring is asserted here.

const ScriptClass = preload("res://data/cards/rag_duelist_pool_cards.gd")

## Paid self-targeting Block-and-Riposte fixtures, copied from the v3 design rather than read back
## from the service.
const PARRY := "rag_duelist_cape_parry"
const PARRY_PLUS := "rag_duelist_cape_parry_plus"
const GUARD := "rag_duelist_cape_guard"
const GUARD_PLUS := "rag_duelist_cape_guard_plus"
const REPRISE := "rag_duelist_duelist_reprise"
const REPRISE_PLUS := "rag_duelist_duelist_reprise_plus"
const RIPOSTE_IDS := [PARRY, PARRY_PLUS, GUARD, GUARD_PLUS, REPRISE, REPRISE_PLUS]
const RIPOSTE_COST := 1
const RIPOSTE_BLOCK := {
	PARRY: 4, PARRY_PLUS: 6, GUARD: 5, GUARD_PLUS: 7, REPRISE: 0, REPRISE_PLUS: 0,
}
const RIPOSTE_N := {
	PARRY: 2, PARRY_PLUS: 3, GUARD: 3, GUARD_PLUS: 4, REPRISE: 5, REPRISE_PLUS: 7,
}
const RIPOSTE_FROM := {
	PARRY: [1, 2, 3], PARRY_PLUS: [1, 2, 3], GUARD: [1, 2, 3], GUARD_PLUS: [1, 2, 3],
	REPRISE: [1, 2], REPRISE_PLUS: [1, 2],
}
const RIPOSTE_CATALOG := {
	PARRY: "starter", PARRY_PLUS: "starter", GUARD: "pool", GUARD_PLUS: "pool",
	REPRISE: "pool", REPRISE_PLUS: "pool",
}
const RIPOSTE_FILLERS := ["filler_stitch", "filler_thread", "filler_needle"]
const HEROES_PATH := "res://data/heroes/v3_party_roster.json"
const ALLY_PATH := "res://data/heroes/starter_party.json"

## Catalog seam double: only Riposte authentication reads it, so a forged record proves the paid
## service fails closed on a rewritten catalog. Every other case uses the real catalogs.
class ForgedRiposte extends CombatRagDuelistRiposteCards:
	var forged_id: String = ""
	var forged: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		if card_id == forged_id:
			return forged.duplicate(true)
		return super(card_id)

var failures: Array[String] = []
var checks: int = 0
var riposte_service := CombatRagDuelistRiposteCards.new()


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_rng_state()
	_test_riposte_cards_authored()
	_test_riposte_ac1_paid_play()
	_test_riposte_ac2_projection_and_expiry()
	_test_riposte_ac3_rejections()
	_test_riposte_seeded_replay()
	if failures.is_empty():
		print("v3_rag_duelist_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_rag_duelist_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"rag_duelist_needle_prick": {
			"name": "Needle Prick", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 4, "bleed": 2}, "plus_cost": 1,
			"plus_effects": {"damage": 6, "bleed": 3}},
		"rag_duelist_needle_lunge": {
			"name": "Needle Lunge", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 6, "move_self_forward": 1}, "plus_cost": 1,
			"plus_effects": {"damage": 8, "move_self_forward": 1}},
		"rag_duelist_cape_guard": {
			"name": "Cape Guard", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"block": 5, "riposte": 3, "duration": 1}, "plus_cost": 1,
			"plus_effects": {"block": 7, "riposte": 4, "duration": 1}},
		"rag_duelist_velvet_feint": {
			"name": "Velvet Feint", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"exposed": 1, "draw": 1}, "plus_cost": 0,
			"plus_effects": {"exposed": 1, "draw": 1}},
		"rag_duelist_duelist_reprise": {
			"name": "Duelist Reprise", "rarity": "uncommon", "cost": 1,
			"from": [1, 2], "target": "self", "to": [],
			"effects": {"riposte": 5, "duration": 1}, "plus_cost": 1,
			"plus_effects": {"riposte": 7, "duration": 1}},
		"rag_duelist_cape_flourish": {
			"name": "Cape Flourish", "rarity": "uncommon", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"dodge_next_attack": 1, "duration": 1}, "plus_cost": 0,
			"plus_effects": {"dodge_next_attack": 1, "duration": 1}},
		"rag_duelist_tattered_snare": {
			"name": "Tattered Snare", "rarity": "uncommon", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"tangled": 2}, "plus_cost": 1,
			"plus_effects": {"tangled": 3}},
		"rag_duelist_needle_barrage": {
			"name": "Needle Barrage", "rarity": "rare", "cost": 2,
			"from": [1], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 3, "hit_count": 3, "independent_hits": true}, "plus_cost": 2,
			"plus_effects": {"damage": 4, "hit_count": 3, "independent_hits": true}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "rag_duelist",
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
	var rarity_counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}

	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(not seen.has(base_id), base_id + " is a distinct base identifier")
		seen[base_id] = true
		_check(base_ids.has(base_id), base_id + " is listed as a base")
		_check(base_ids.count(base_id) == 1, base_id + " has one base-list occurrence")
		_check(not base_ids.has(plus_id), plus_id + " is not a base")
		_check(all_ids.has(base_id) and all_ids.has(plus_id), base_id + " both IDs discoverable")
		_check(catalog.has_card(base_id) and catalog.has_card(plus_id), base_id + " both exist")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		rarity_counts[spec["rarity"]] += 1

		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and str(record.get(field)) == str(expected[field]),
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has effect descriptors")
		_check(base_id != plus_id, base_id + " upgrade has distinct stable ID")

	_check(rarity_counts["common"] == 4, "Exactly 4 common cards")
	_check(rarity_counts["uncommon"] == 3, "Exactly 3 uncommon cards")
	_check(rarity_counts["rare"] == 1, "Exactly 1 rare card")


func _test_special_descriptors() -> void:
	var catalog = ScriptClass.new()
	for suffix: String in ["", "_plus"]:
		var lunge: Dictionary = catalog.get_definition("rag_duelist_needle_lunge" + suffix)
		_check(lunge.get("effects").has("move_self_forward") and lunge.get("effects").get("move_self_forward") == 1,
			"Needle Lunge specifies exactly one slot of forward movement" + suffix)

		var flourish: Dictionary = catalog.get_definition("rag_duelist_cape_flourish" + suffix)
		_check(flourish.get("effects").has("dodge_next_attack") and flourish.get("effects").get("dodge_next_attack") == 1,
			"Cape Flourish specifically identifies dodging the next incoming attack" + suffix)

		var snare: Dictionary = catalog.get_definition("rag_duelist_tattered_snare" + suffix)
		_check(snare.get("effects").has("tangled"),
			"Tattered Snare specifies Tangled duration" + suffix)

		var barrage: Dictionary = catalog.get_definition("rag_duelist_needle_barrage" + suffix)
		_check(barrage.get("effects").has("hit_count") and barrage.get("effects").get("hit_count") == 3,
			"Needle Barrage specifies 3 hits" + suffix)
		_check(barrage.get("effects").has("independent_hits") and barrage.get("effects").get("independent_hits") == true,
			"Needle Barrage specifies independent hits for V3 Thorns" + suffix)

		var reprise: Dictionary = catalog.get_definition("rag_duelist_duelist_reprise" + suffix)
		_check(reprise.get("effects").has("riposte") and reprise.get("effects").has("duration"),
			"Riposte explicitly tracks value and duration" + suffix)


func _test_detached_results() -> void:
	var catalog = ScriptClass.new()
	var sample: Dictionary = catalog.get_definition("rag_duelist_needle_prick")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["bleed"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("rag_duelist_needle_prick")
	_check(pristine.get("effects") == {"damage": 4, "bleed": 2},
		"effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [1, 2],
		"FROM arrays are deeply detached from catalog")
	_check(pristine.get("to_positions") == [1, 2],
		"TO arrays are deeply detached from catalog")
	_check(pristine.get("id") == "rag_duelist_needle_prick", "metadata is detached")

	var upgraded: Dictionary = catalog.get_definition("rag_duelist_cape_guard_plus")
	upgraded["effects"]["block"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("effects") == {"block": 7, "riposte": 4, "duration": 1},
		"upgrade effects are detached")
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("from_positions") == [1, 2, 3],
		"upgrade FROM is detached")
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("to_positions") == [],
		"empty upgrade TO is detached")

	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("rag_duelist_cape_guard") and all_ids.has("rag_duelist_cape_guard_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("rag_duelist_cape_guard"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("rag_duelist_cape_guard_plus"), "all-ID array is a fresh copy")
	_check(ScriptClass.new().get_definition("rag_duelist_needle_prick").get("effects") == pristine.get("effects"),
		"fresh instance retains canonical definition")


func _test_invalid_ids() -> void:
	var catalog = ScriptClass.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("rag_duelist_cape_guard"),
		"", "rag_duelist_not_a_card", "rag_duelist_needle_prick+", "rag_duelist_cape_guard_plus_plus"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_rng_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var initial_state: int = rng.state
	var catalog = ScriptClass.new()
	var ids: Array[String] = catalog.get_all_card_ids()
	for id: String in ids:
		var def: Dictionary = catalog.get_definition(id)
	_check(rng.state == initial_state, "constructing/enumerating catalog consumes no run RNG")


## --- Paid self Block-and-Riposte cards (Cape Parry / Cape Guard / Duelist Reprise) -----------
##
## These cases drive the scene-free CombatRagDuelistRiposteCards service over real seeded CombatDeck
## and CombatParty fixtures. Like the Feint helper they claim callable rules-layer behaviour only:
## no live hand, reward, app or run-deck wiring is asserted here.

func _riposte_effects(card_id: String) -> Dictionary:
	var effects := {"riposte": int(RIPOSTE_N[card_id]), "duration": 1}
	if int(RIPOSTE_BLOCK[card_id]) > 0:
		effects["block"] = int(RIPOSTE_BLOCK[card_id])
	return effects


func _riposte_catalog_record(card_id: String) -> Dictionary:
	if RIPOSTE_CATALOG.get(card_id, "") == "starter":
		return RagDuelistStarterCards.new().get_definition(card_id)
	return RagDuelistPoolCards.new().get_definition(card_id)


## Both catalogs must still carry the exact authored line for all six printings, and nothing else
## may be accepted as one of these effects.
func _test_riposte_cards_authored() -> void:
	var starter := RagDuelistStarterCards.new()
	var pool := RagDuelistPoolCards.new()
	var copies := {PARRY: 1, PARRY_PLUS: 0, GUARD: 0, GUARD_PLUS: 0, REPRISE: 0, REPRISE_PLUS: 0}
	var reward := {PARRY: false, PARRY_PLUS: false, GUARD: true, GUARD_PLUS: false,
		REPRISE: true, REPRISE_PLUS: false}
	for card_id: String in RIPOSTE_IDS:
		var record: Dictionary = _riposte_catalog_record(card_id)
		_check(not record.is_empty() and record.get("id") == card_id,
			card_id + ": authored catalog record exists")
		if record.is_empty():
			continue
		_check(record.get("owner") == "rag_duelist", card_id + ": authored owner is the Rag Duelist")
		_check(record.get("cost") == RIPOSTE_COST,
			card_id + ": authored cost is " + str(RIPOSTE_COST))
		_check(record.get("from_positions") == RIPOSTE_FROM[card_id],
			card_id + ": authored FROM seats " + str(RIPOSTE_FROM[card_id]))
		_check(record.get("target_kind") == "self", card_id + ": targets only its owner")
		_check(record.get("to_positions") == [], card_id + ": names no enemy position")
		_check(record.get("effects") == _riposte_effects(card_id),
			card_id + ": exact authored Block/Riposte/duration line")
		_check(record.get("starting_copies") == copies[card_id],
			card_id + ": authored starting copies untouched")
		_check(record.get("reward_eligible") == reward[card_id],
			card_id + ": authored reward eligibility untouched")
		_check(riposte_service.is_supported_card(card_id),
			card_id + ": service authenticates the ID")
	_check(starter.get_upgrade_id(PARRY) == PARRY_PLUS
		and starter.get_definition(PARRY_PLUS).get("upgrade_of") == PARRY,
		"starter Cape Parry base-to-+ link is intact")
	_check(pool.get_upgrade_id(GUARD) == GUARD_PLUS
		and pool.get_definition(GUARD_PLUS).get("upgrade_of") == GUARD,
		"pool Cape Guard base-to-+ link is intact")
	_check(pool.get_upgrade_id(REPRISE) == REPRISE_PLUS
		and pool.get_definition(REPRISE_PLUS).get("upgrade_of") == REPRISE,
		"pool Duelist Reprise base-to-+ link is intact")
	# Real Rag Duelist cards this resolver must not play as a Riposte card.
	for unsupported: String in ["rag_duelist_rapier_lunge", "rag_duelist_needle_lunge",
			"rag_duelist_feather_feint", "rag_duelist_velvet_feint", "rag_duelist_cape_slip",
			"rag_duelist_needle_prick", "rag_duelist_cape_flourish", "rag_duelist_tattered_snare",
			"rag_duelist_needle_barrage", "rag_duelist_cape_parry_plus_plus",
			"RAG_DUELIST_CAPE_PARRY", "rag_duelist_cape_parry ", ""]:
		_check(not riposte_service.is_supported_card(unsupported),
			unsupported + ": not a paid Riposte printing for this service")
	_check(not riposte_service.is_supported_card(null)
		and not riposte_service.is_supported_card(7)
		and not riposte_service.is_supported_card(true)
		and not riposte_service.is_supported_card(StringName(PARRY)),
		"non-string IDs are never supported")
	var rng := _rng(8241)
	var state_before: int = rng.state
	for card_id: String in RIPOSTE_IDS:
		riposte_service.is_supported_card(card_id)
	riposte_service.is_supported_card("rag_duelist_unknown")
	_check(rng.state == state_before and not RIPOSTE_IDS.is_empty(),
		"supported-card queries consume no run RNG (non-empty precondition)")


## AC1: each authentic base/'+' printing is charged exactly once, discards exactly one held copy
## and lands on the living owner in every printed seat (including Cape Parry/Guard at rear seat 3).
## AC2 is checked on the resulting owner statuses: exact Block/Riposte, the canonical confirmed-hit
## projection, an unconfirmed attempt returning zero, and one-owner-turn expiry.
func _test_riposte_ac1_paid_play() -> void:
	for card_id: String in RIPOSTE_IDS:
		for owner_position: int in RIPOSTE_FROM[card_id]:
			var label := "%s seat=%d" % [card_id, owner_position]
			var party := _riposte_party(owner_position)
			party._heroes[owner_position - 1]["block"] = 2
			party._heroes[owner_position - 1]["statuses"] = {"bleed": 2}
			for index in range(CombatParty.PARTY_SIZE):
				if index + 1 != owner_position:
					party._heroes[index]["statuses"] = {"weak": 1}
			var deck := _riposte_deck(card_id, 2100 + 10 * owner_position, 1)
			_check(deck.energy == 1 and deck.hand.has(card_id) and deck.hand.count(card_id) >= 2,
				label + ": real seeded hand holds the printing with exactly enough energy")
			var held_before: int = deck.hand.count(card_id)
			var before := _riposte_snapshot(deck, party)
			var result: Dictionary = riposte_service.play_card(deck, party, card_id)
			_check(result.get("ok") == true and result.get("reason") == "applied",
				label + ": authorized paid play")
			_check(result.get("card_id") == card_id and result.get("cost") == RIPOSTE_COST,
				label + ": receipt names the authentic card and its printed cost")
			_check(result.get("owner_position") == owner_position
				and result.get("owner_id") == "rag_duelist",
				label + ": receipt reports the real owning seat")
			_check(result.get("energy_before") == 1 and result.get("energy_after") == 0,
				label + ": exactly one shared energy was charged")
			_check(result.get("block") == RIPOSTE_BLOCK[card_id]
				and result.get("block_before") == 2
				and result.get("block_after") == 2 + int(RIPOSTE_BLOCK[card_id]),
				label + ": the receipt reports the printed Block")
			_check(result.get("riposte") == RIPOSTE_N[card_id]
				and result.get("riposte_before") == 0
				and result.get("riposte_after") == RIPOSTE_N[card_id],
				label + ": the receipt reports the printed Riposte N")
			var owner: Dictionary = party.get_hero(owner_position)
			var expected_statuses := {"bleed": 2, "riposte": int(RIPOSTE_N[card_id])}
			_check(owner["block"] == 2 + int(RIPOSTE_BLOCK[card_id]),
				label + ": only the owning hero gains the printed Block")
			_check(owner["statuses"] == expected_statuses,
				label + ": the owning hero keeps unrelated statuses and gains Riposte N")
			_check(owner["hp"] == before["heroes"][owner_position - 1]["hp"],
				label + ": owner HP is untouched")
			for index in range(CombatParty.PARTY_SIZE):
				if index + 1 != owner_position:
					_check(party.get_hero(index + 1) == before["heroes"][index],
						label + ": hero " + str(index + 1) + " is untouched")
			_check(deck.hand.count(card_id) == held_before - 1
				and deck.discard_pile == [card_id] and deck.hand.size() == 4,
				label + ": exactly one held copy moved to the discard with no extra draw")
			_check(deck.draw_pile == before["draw"],
				label + ": the other cards keep their draw-pile order")
			_check(_riposte_snapshot(deck, party)
				== _riposte_expected_play(before, card_id, owner_position),
				label + ": exact party, piles, energy and untouched injected RNG")
			# The receipt carries detached statuses, never the live roster.
			result["statuses"]["riposte"] = 99
			_check(party.get_hero(owner_position)["statuses"] == expected_statuses,
				label + ": a mutated receipt cannot change the hero")

			# AC2: the canonical projection repeats the exact counterdamage on confirmed hits, returns
			# zero for an unconfirmed attempt, and never mutates the statuses.
			var rules := CombatStatuses.new()
			var live: Dictionary = party.get_hero(owner_position)["statuses"]
			var live_snapshot: Dictionary = live.duplicate(true)
			for hit in range(1, 4):
				_check(rules.riposte_damage_for_confirmed_hit(live, true) == RIPOSTE_N[card_id],
					label + ": confirmed hit %d returns exactly Riposte %d" % [hit, RIPOSTE_N[card_id]])
			_check(rules.riposte_damage_for_confirmed_hit(live, false) == 0,
				label + ": an unconfirmed attempt returns zero counterdamage")
			_check(live == live_snapshot,
				label + ": projecting confirmed/unconfirmed hits never mutates Riposte")
			var ended: Dictionary = rules.end_owner_turn(owner["hp"], owner["block"], live)
			_check(ended.get("ok") == true and not ended["statuses"].has("riposte"),
				label + ": the next owner-turn boundary expires Riposte completely")
			_check(ended["statuses"] == {"bleed": 1},
				label + ": expiry keeps the surviving unrelated status counters")
			_check(ended["block"] == owner["block"] and ended["bleed_hp_loss"] == 2,
				label + ": expiry leaves the printed Block and deals only Bleed loss")
			_check(rules.riposte_damage_for_confirmed_hit(ended["statuses"], true) == 0,
				label + ": an expired Riposte yields no counterdamage")


## AC2: Duelist Reprise grants Riposte 5/7 with no Block at all, while re-applying any printing over
## an already active Riposte is refused rather than choosing a stacking/refresh policy. A fresh
## Riposte 0 is inert and may be replaced by the printed N.
func _test_riposte_ac2_projection_and_expiry() -> void:
	for card_id: String in [REPRISE, REPRISE_PLUS]:
		var party := _riposte_party(2)
		party._heroes[1]["block"] = 3
		party._heroes[1]["statuses"] = {"weak": 2, "bleed": 1}
		var deck := _riposte_deck(card_id, 3400, 1)
		var before := _riposte_snapshot(deck, party)
		var result: Dictionary = riposte_service.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("block") == 0,
			card_id + ": a legal Reprise play applies no Block")
		var owner: Dictionary = party.get_hero(2)
		_check(owner["block"] == 3,
			card_id + ": Reprise leaves the owner's existing Block exactly as it was")
		_check(owner["statuses"] == {"weak": 2, "bleed": 1, "riposte": RIPOSTE_N[card_id]},
			card_id + ": Reprise adds only Riposte N beside the existing counters")
		_check(_riposte_snapshot(deck, party) == _riposte_expected_play(before, card_id, 2),
			card_id + ": exact one-payment Reprise transaction with an untouched RNG")
		var rules := CombatStatuses.new()
		_check(rules.riposte_damage_for_confirmed_hit(owner["statuses"], true)
			== RIPOSTE_N[card_id],
			card_id + ": the canonical projection repeats Riposte " + str(RIPOSTE_N[card_id]))
		_check(rules.riposte_damage_for_confirmed_hit(owner["statuses"], false) == 0,
			card_id + ": an unconfirmed hit returns zero counterdamage")

	# A second authentic copy while Riposte is active fails closed instead of stacking or refreshing.
	for card_id: String in RIPOSTE_IDS:
		var party := _riposte_party(2)
		party._heroes[1]["statuses"] = {"riposte": 9, "bleed": 1}
		var deck := _riposte_deck(card_id, 3410)
		_riposte_rejected(deck, party, card_id,
			card_id + ": already active Riposte " + str(RIPOSTE_N[card_id]))

	# An inert Riposte 0 is not an active status, so the fresh printed N replaces it.
	for card_id: String in RIPOSTE_IDS:
		var party := _riposte_party(2)
		party._heroes[1]["block"] = 1
		party._heroes[1]["statuses"] = {"riposte": 0, "exposed": 2}
		var deck := _riposte_deck(card_id, 3420, 1)
		var before := _riposte_snapshot(deck, party)
		var result: Dictionary = riposte_service.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("riposte_before") == 0,
			card_id + ": a genuine play replaces an inert Riposte 0")
		_check(party.get_hero(2)["statuses"]
			== {"riposte": RIPOSTE_N[card_id], "exposed": 2},
			card_id + ": only Riposte changes; the unrelated Exposed counter survives")
		_check(_riposte_snapshot(deck, party) == _riposte_expected_play(before, card_id, 2),
			card_id + ": exact transaction from the inert-Riposte fixture")

	# Duelist Reprise never adds Block, so a maximal existing Block is not an overflow for it.
	var huge_party := _riposte_party(2)
	huge_party._heroes[1]["block"] = CombatParty.MAX_INT
	var huge_deck := _riposte_deck(REPRISE, 3430, 1)
	var huge_result: Dictionary = riposte_service.play_card(huge_deck, huge_party, REPRISE)
	_check(huge_result.get("ok") == true
		and huge_party.get_hero(2)["block"] == CombatParty.MAX_INT,
		"Duelist Reprise at maximal Block plays without inventing a Block gain")


## AC3: bad payment, forged/foreign/absent cards, invalid actors, malformed statuses and exceeded
## capacity all fail closed and leave hand, draw, discard, energy, party and seeded RNG unchanged.
func _test_riposte_ac3_rejections() -> void:
	var party := _riposte_party(2)

	_riposte_rejected(null, party, PARRY, "null deck")
	_riposte_rejected(_riposte_deck(PARRY, 4001), null, PARRY, "null party")
	_riposte_rejected(_riposte_deck(PARRY, 4002), CombatParty.new([]), PARRY,
		"invalid party roster")

	var inactive := _riposte_deck(PARRY, 4003, -1, false)
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_riposte_rejected(inactive, party, PARRY, "inactive turn")

	var held := _riposte_deck(PARRY, 4004)
	_check(held.hand.has(PARRY) and not held.hand.has(PARRY_PLUS),
		"absent-card fixture holds the base Cape Parry only")
	_riposte_rejected(held, party, PARRY_PLUS, "authentic '+' absent from the hand")

	var foreign := _riposte_deck("rag_duelist_feather_feint", 4005)
	_check(foreign.hand.has("rag_duelist_feather_feint"),
		"foreign-card fixture really holds another Rag Duelist card")
	_riposte_rejected(foreign, party, "rag_duelist_feather_feint", "foreign Rag Duelist card")
	for unsupported: Variant in ["", "rag_duelist_cape_parry_plus_plus",
			"rag_duelist_cape_parry ", "RAG_DUELIST_CAPE_PARRY", "rag_duelist_feather_feint",
			"rag_duelist_rapier_lunge", "rag_duelist_needle_prick", 7, null, true,
			StringName(PARRY)]:
		_riposte_rejected(_riposte_deck(PARRY, 4006), party, unsupported,
			"unsupported or forged printing " + str(unsupported))

	var broke := _riposte_deck(PARRY, 4007, 0)
	_check(broke.energy == 0 and broke.hand.has(PARRY),
		"energy-short fixture is genuinely broke and still holds the card")
	_riposte_rejected(broke, party, PARRY, "insufficient energy")

	var rear_reprise := _riposte_party(3)
	_check(rear_reprise.get_hero(3)["id"] == "rag_duelist",
		"rear-slot fixture really seats the Rag Duelist in slot 3")
	_riposte_rejected(_riposte_deck(REPRISE, 4008), rear_reprise, REPRISE,
		"Duelist Reprise from its unprinted rear seat 3")

	var downed := _riposte_party(1)
	_check(downed.apply_damage(1, downed.get_hero(1)["max_hp"]) and downed.is_downed(1),
		"downed-owner fixture really has a downed Rag Duelist")
	_riposte_rejected(_riposte_deck(PARRY, 4009), downed, PARRY, "downed Rag Duelist")

	var no_owner := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(no_owner.is_valid() and no_owner.get_hero(1)["id"] != "rag_duelist"
		and no_owner.get_hero(2)["id"] != "rag_duelist"
		and no_owner.get_hero(3)["id"] != "rag_duelist",
		"absent-owner fixture is a valid party without a Rag Duelist")
	_riposte_rejected(_riposte_deck(PARRY, 4010), no_owner, PARRY, "party with no Rag Duelist owner")

	var duplicated := _riposte_party(2)
	duplicated._heroes[0]["id"] = "rag_duelist"
	_check(duplicated.get_hero(1)["id"] == "rag_duelist"
		and duplicated.get_hero(2)["id"] == "rag_duelist",
		"duplicate-identity fixture really repeats the owner ID")
	_riposte_rejected(_riposte_deck(PARRY, 4011), duplicated, PARRY, "duplicate Rag Duelist identity")

	var above_max := _riposte_party(2)
	above_max._heroes[1]["hp"] = int(above_max._heroes[1]["max_hp"]) + 1
	_check(above_max.get_hero(2)["hp"] > above_max.get_hero(2)["max_hp"],
		"malformed-roster fixture really has HP above max")
	_riposte_rejected(_riposte_deck(PARRY, 4012), above_max, PARRY, "HP above max")

	var bad_block := _riposte_party(2)
	bad_block._heroes[1]["block"] = -1
	_check(bad_block.get_hero(2)["block"] == -1, "negative-Block fixture really stores -1")
	_riposte_rejected(_riposte_deck(PARRY, 4013), bad_block, PARRY, "negative Block")

	var bad_position := _riposte_party(2)
	bad_position._heroes[0]["position"] = 3
	_check(bad_position.get_hero(1)["position"] == 3,
		"wrong-position fixture really stores the wrong slot")
	_riposte_rejected(_riposte_deck(PARRY, 4014), bad_position, PARRY, "wrong stored hero position")

	for bad_statuses: Variant in ["bleed", [], null, {"bleed": -1}, {"bleed": "3"},
			{"bleed": 1.5}, {"weak": true}, {1: 2}, {"": 1}, {"unknown_status": 1},
			{"dodge_next_attack": 2}, {"blind_next_attack": 2}, {"riposte": -1},
			{"riposte": 1.5}, {"riposte": "3"}, {"riposte": true}]:
		var broken := _riposte_party(2)
		broken._heroes[1]["statuses"] = bad_statuses
		_check(broken.get_hero(2)["statuses"] == bad_statuses,
			"malformed-status fixture really stores " + str(bad_statuses))
		_riposte_rejected(_riposte_deck(PARRY, 4015), broken, PARRY,
			"malformed owner statuses " + str(bad_statuses))

	var ally_statuses := _riposte_party(2)
	ally_statuses._heroes[0]["statuses"] = {"poison": 1}
	_check(ally_statuses.get_hero(1)["statuses"] == {"poison": 1},
		"malformed-ally fixture really stores an unknown status")
	_riposte_rejected(_riposte_deck(PARRY, 4016), ally_statuses, PARRY,
		"malformed statuses on a non-owner hero")

	for block_card: String in [PARRY, PARRY_PLUS, GUARD, GUARD_PLUS]:
		var huge_block := _riposte_party(2)
		huge_block._heroes[1]["block"] = CombatParty.MAX_INT
		_check(huge_block.get_hero(2)["block"] == CombatParty.MAX_INT,
			block_card + ": Block-overflow fixture really stores MAX_INT Block")
		_riposte_rejected(_riposte_deck(block_card, 4017), huge_block, block_card,
			block_card + ": unrepresentable Block gain")
		var nearly_full := _riposte_party(2)
		nearly_full._heroes[1]["block"] = CombatParty.MAX_INT - int(RIPOSTE_BLOCK[block_card]) + 1
		_check(nearly_full.get_hero(2)["block"]
			> CombatParty.MAX_INT - int(RIPOSTE_BLOCK[block_card]),
			block_card + ": near-overflow fixture leaves too little room for the gain")
		_riposte_rejected(_riposte_deck(block_card, 4018), nearly_full, block_card,
			block_card + ": Block gain would overflow")

	# A rejected attempt never poisons the next authentic one.
	var retry_deck := _riposte_deck(PARRY, 4019, 1)
	var retry_party := _riposte_party(2)
	var retry_before := _riposte_snapshot(retry_deck, retry_party)
	_riposte_rejected(retry_deck, retry_party, PARRY_PLUS, "retry: absent '+' printing")
	var retried: Dictionary = riposte_service.play_card(retry_deck, retry_party, PARRY)
	_check(retried.get("ok") == true, "retry: the authentic play then succeeds")
	_check(_riposte_snapshot(retry_deck, retry_party)
		== _riposte_expected_play(retry_before, PARRY, 2),
		"retry: exactly one charge, one discard and an untouched RNG")

	# A forged catalog record - every authenticated field omitted or altered - is never paid for,
	# while the restored authentic record still plays, so the refusal comes from the forgery.
	for card_id: String in RIPOSTE_IDS:
		var authentic: Dictionary = _riposte_catalog_record(card_id)
		_check(not authentic.is_empty(),
			card_id + ": authentic record available (forgery precondition)")
		if authentic.is_empty():
			continue
		var link_field := "upgrade_of" if card_id.ends_with("_plus") else "upgrade_id"
		var mutations: Array = []
		for field in ["id", "owner", "cost", "from_positions", "to_positions", "target_kind",
				"effects", link_field]:
			var omitted: Dictionary = authentic.duplicate(true)
			omitted.erase(field)
			mutations.append(omitted)
			var altered: Dictionary = authentic.duplicate(true)
			altered[field] = {"id": "fake_riposte", "owner": "warden", "cost": 2.0,
				"from_positions": [3], "to_positions": [1, 2], "target_kind": "enemy_single",
				"effects": {"riposte": 99, "duration": 2},
				"upgrade_id": "fake_riposte", "upgrade_of": "fake_riposte"}[field]
			mutations.append(altered)
		var extra_effect: Dictionary = authentic.duplicate(true)
		extra_effect["effects"]["weak"] = 1
		mutations.append(extra_effect)
		var stacked_riposte: Dictionary = authentic.duplicate(true)
		stacked_riposte["effects"]["riposte"] = int(stacked_riposte["effects"]["riposte"]) + 1
		mutations.append(stacked_riposte)
		var wrong_duration: Dictionary = authentic.duplicate(true)
		wrong_duration["effects"]["duration"] = 2
		mutations.append(wrong_duration)
		var typed_riposte: Dictionary = authentic.duplicate(true)
		typed_riposte["effects"]["riposte"] = float(typed_riposte["effects"]["riposte"])
		mutations.append(typed_riposte)
		if authentic["effects"].has("block"):
			var missing_block: Dictionary = authentic.duplicate(true)
			missing_block["effects"].erase("block")
			mutations.append(missing_block)
			var typed_block: Dictionary = authentic.duplicate(true)
			typed_block["effects"]["block"] = float(typed_block["effects"]["block"])
			mutations.append(typed_block)
		else:
			var invented_block: Dictionary = authentic.duplicate(true)
			invented_block["effects"]["block"] = 1
			mutations.append(invented_block)
		_check(not mutations.is_empty(), card_id + ": forgery fixtures are non-empty (precondition)")

		var forged_service := ForgedRiposte.new()
		var forged_deck := _riposte_deck(card_id, 4020)
		var forged_party := _riposte_party(2)
		forged_service.forged_id = card_id
		for forged: Dictionary in mutations:
			forged_service.forged = forged
			var forged_before := _riposte_snapshot(forged_deck, forged_party)
			var result: Dictionary = forged_service.play_card(forged_deck, forged_party, card_id)
			_check(result.get("ok") == false, card_id + ": forged catalog record rejected")
			_check(_riposte_snapshot(forged_deck, forged_party) == forged_before,
				card_id + ": forged record rejection leaves deck, party and RNG unchanged")
		forged_service.forged_id = ""
		var restored: Dictionary = forged_service.play_card(forged_deck, forged_party, card_id)
		_check(restored.get("ok") == true and restored.get("card_id") == card_id,
			card_id + ": the restored authentic record plays")


## The same seed replays each paid play exactly, and resolution reseeds neither the injected
## generator nor the global RNG (these cards draw no cards).
func _test_riposte_seeded_replay() -> void:
	for card_id: String in RIPOSTE_IDS:
		var first: Dictionary = _riposte_replay_run(card_id, 5201)
		var second: Dictionary = _riposte_replay_run(card_id, 5201)
		_check(not first["snapshot"].is_empty() and first["result"].get("ok") == true,
			card_id + ": seeded replay fixture really plays (non-empty precondition)")
		_check(second["snapshot"] == first["snapshot"]
			and second["result"] == first["result"],
			card_id + ": the same seed replays the final state exactly")
		_check(first["rng_state"] == first["rng_start"]
			and first["rng_seed"] == first["rng_seed_start"]
			and first["snapshot"]["rng_state"] == first["rng_start"],
			card_id + ": a non-drawing paid play consumes no injected RNG state")

	seed(13579)
	var expected_next: int = randi()
	seed(13579)
	var party := _riposte_party(1)
	var deck := _riposte_deck(REPRISE, 5202, 1)
	var state_before: int = deck._rng.state
	var result: Dictionary = riposte_service.play_card(deck, party, REPRISE)
	_check(result.get("ok") == true and deck._rng.state == state_before,
		"a genuine play never consumes the injected generator")
	_check(randi() == expected_next, "resolution never draws from the global RNG")


func _riposte_replay_run(card_id: String, seed_value: int) -> Dictionary:
	var party := _riposte_party(2)
	party._heroes[0]["statuses"] = {"bleed": 1}
	party._heroes[1]["statuses"] = {"weak": 2}
	var deck := _riposte_deck(card_id, seed_value, 1)
	var rng_start: int = deck._rng.state
	var rng_seed: int = deck._rng.seed
	var result: Dictionary = riposte_service.play_card(deck, party, card_id)
	return {"result": result, "snapshot": _riposte_snapshot(deck, party),
		"rng_start": rng_start, "rng_state": deck._rng.state,
		"rng_seed_start": rng_seed, "rng_seed": deck._rng.seed}


func _riposte_rejected(deck: CombatDeck, party: CombatParty, card_id: Variant,
		label: String) -> void:
	var before := _riposte_snapshot(deck, party)
	var result: Dictionary = riposte_service.play_card(deck, party, card_id)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	_check(_riposte_snapshot(deck, party) == before,
		label + ": unchanged party, hand, draw, discard, energy, turn and RNG")


## The single-transaction expected state for one paid play: one cost, one discard, the printed
## Block on the owning seat and the printed Riposte N on that hero only.
func _riposte_expected_play(before: Dictionary, card_id: String,
		owner_position: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - RIPOSTE_COST
	expected["state_energy"] = int(expected["state_energy"]) - RIPOSTE_COST
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var hero: Dictionary = expected["heroes"][owner_position - 1]
	hero["block"] = int(hero["block"]) + int(RIPOSTE_BLOCK[card_id])
	var statuses: Dictionary = hero.get("statuses", {})
	statuses["riposte"] = int(RIPOSTE_N[card_id])
	hero["statuses"] = statuses
	return expected


## The full observable deck/party state plus the injected RNG state, for exact comparisons.
func _riposte_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var result: Dictionary = {}
	if party != null:
		result["heroes"] = party.get_heroes()
		result["party_valid"] = party.is_valid()
	if deck != null:
		result["hand"] = deck.hand.duplicate(true)
		result["draw"] = deck.draw_pile.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		if deck.combat_state != null:
			result["state_energy"] = deck.combat_state.energy
			result["state_turn"] = deck.combat_state.player_turn_active
		if deck._rng != null:
			result["rng_state"] = deck._rng.state
			result["rng_seed"] = deck._rng.seed
	return result


## A real seeded five-card hand from six cards (three copies of the named ID), so at least two
## copies are genuinely held. `energy` of 0+ spends down to exactly that budget before the play.
func _riposte_deck(card_id: String, seed_value: int, energy: int = -1,
		start_turn: bool = true) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, RIPOSTE_FILLERS[0],
		RIPOSTE_FILLERS[1], RIPOSTE_FILLERS[2]]
	var deck := CombatDeck.new(ids, _rng(seed_value))
	if not start_turn:
		return deck
	_check(deck.start_turn() and deck.turn_active and deck.hand.size() == 5
		and deck.hand.count(card_id) >= 2,
		card_id + ": real seeded five-card hand holding duplicate copies")
	if energy >= 0:
		var spend: int = deck.energy - energy
		_check(spend >= 0 and deck.try_spend_energy(spend) and deck.energy == energy,
			card_id + ": energy fixture holds exactly " + str(energy) + " energy")
	return deck


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real three-hero CombatParty with the authored Rag Duelist in the requested seat and the two
## authored starter allies filling the rest. No run roster or data file is changed.
func _riposte_party(owner_position: int) -> CombatParty:
	var duelist := _authored_record(HEROES_PATH, "rag_duelist")
	var warden := _authored_record(ALLY_PATH, "warden")
	var seamstress := _authored_record(ALLY_PATH, "seamstress")
	_check(int(duelist.get("max_hp", 0)) == 32, "authored Rag Duelist max HP is 32")
	_check(not warden.is_empty() and not seamstress.is_empty(),
		"authored starter party supplies the two ally records")
	var allies: Array = [warden, seamstress]
	var definitions: Array = []
	for index in range(CombatParty.PARTY_SIZE):
		if index + 1 == owner_position:
			definitions.append(duelist)
		else:
			definitions.append(allies.pop_front())
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(owner_position).get("id") == "rag_duelist"
		and not party.is_downed(owner_position),
		"valid party with the unique living Rag Duelist in seat " + str(owner_position))
	return party


func _authored_record(path: String, hero_id: String) -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array, path + " parses")
	if not parsed is Array:
		return {}
	for entry in parsed:
		if not entry is Dictionary:
			continue
		if str(entry.get("id", "")) != hero_id:
			continue
		var max_hp: Variant = entry.get("max_hp")
		if max_hp is float:
			max_hp = int(max_hp)
		_check(max_hp is int and max_hp > 0, path + " gives " + hero_id + " a positive max HP")
		return {"id": hero_id, "name": str(entry.get("name", "")), "max_hp": int(max_hp)}
	_check(false, path + " contains " + hero_id)
	return {}

