extends SceneTree
## Deterministic, headless contract for the V3-1 Seamstress cleansing heals.
##
## Two separate APIs share the one scene-free service:
## * the one-ally Mending Knot / Darn the Tear resolver (`play_card`, `is_supported_card`), and
## * the whole-party Midnight Loom / Midnight Loom+ resolver (`play_party_card`,
##   `is_supported_party_card`), which heals and Blocks every LIVING hero, leaves a torn hero
##   entirely unchanged and takes one explicit per-seat debuff selection.
##
## Mending Knot lives in the v3 starter catalog and Darn the Tear / Midnight Loom in the v3 reward
## pool, so none is assumed to be part of the mounted starter deck: every case builds a real seeded
## CombatDeck that genuinely holds the named ID and starts the shared five-draw/three-energy turn.
## The party is the real authored Warden 40 / Seamstress 30 / Tinker 26 roster; debuffs are seeded
## on the authoritative CombatParty records exactly as other combat rules store them.
##
## The resolver is scene-free. This test claims callable rules-layer behaviour only: no live hand,
## reward, app or run-deck wiring is asserted here.

const HEROES_PATH := "res://data/heroes/starter_party.json"

const MEND := "seamstress_v3_mending_knot"
const MEND_PLUS := "seamstress_v3_mending_knot_plus"
const DARN := "seamstress_v3_darn_the_tear"
const DARN_PLUS := "seamstress_v3_darn_the_tear_plus"
const CARD_IDS := [MEND, MEND_PLUS, DARN, DARN_PLUS]

## The two whole-party printings resolved by the separate party API.
const LOOM := "seamstress_v3_midnight_loom"
const LOOM_PLUS := "seamstress_v3_midnight_loom_plus"
const PARTY_CARD_IDS := [LOOM, LOOM_PLUS]

## Independent literal expectations copied from the v3 design, never read from the resolver.
const HEAL := {MEND: 4, MEND_PLUS: 6, DARN: 4, DARN_PLUS: 6}
const FROM := {MEND: [2, 3], MEND_PLUS: [2, 3], DARN: [1, 2, 3], DARN_PLUS: [1, 2, 3]}
const CATALOG := {MEND: "starter", MEND_PLUS: "starter", DARN: "pool", DARN_PLUS: "pool"}
const LOOM_HEAL := {LOOM: 4, LOOM_PLUS: 6}
const LOOM_BLOCK := {LOOM: 4, LOOM_PLUS: 6}
const LOOM_COST := 3

const FILLERS := ["filler_thread", "filler_ribbon", "filler_twig", "filler_bobbin", "filler_scrap"]

var failures: Array[String] = []
var checks: int = 0
var service := CombatSeamstressV3CleansingCards.new()
var _authored: Dictionary = {}


func _initialize() -> void:
	_test_authentic_catalog_and_api()
	_test_ac1_one_paid_play()
	_test_ac2_selected_cleanse()
	_test_ac2_exposed_and_unrelated_statuses()
	_test_ac2_heal_cap()
	_test_ac2_full_hp_and_no_debuff()
	_test_ac2_owner_seats()
	_test_ac3_rejections()
	_test_ac3_retry_after_rejection()
	_test_once_only_payment()
	_test_seeded_replay()
	_test_party_catalog_and_api()
	_test_party_ac1_one_paid_play()
	_test_party_ac2_roster_effects()
	_test_party_ac2_heal_cap()
	_test_party_ac3_selected_cleanse()
	_test_party_ac3_rejections()
	_test_party_ac3_retry_after_rejection()
	_test_party_once_only_payment()
	_test_party_seeded_replay()
	for failure: String in failures:
		printerr(failure)
	print("combat_seamstress_v3_cleansing_cards_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


## The service must authenticate the exact four printings in their own catalogs and nothing else.
func _test_authentic_catalog_and_api() -> void:
	var starter := V3SeamstressStarterCards.new()
	var pool := V3SeamstressPoolCards.new()
	for card_id: String in CARD_IDS:
		var source: Variant = starter if CATALOG[card_id] == "starter" else pool
		var definition: Dictionary = source.get_definition(card_id)
		_check(definition.get("id") == card_id, card_id + ": authored catalog record exists")
		_check(definition.get("owner") == "seamstress", card_id + ": authored owner is Seamstress")
		_check(definition.get("cost") == 1, card_id + ": authored cost is 1")
		_check(definition.get("target_kind") == "ally_single",
			card_id + ": authored target kind is one living ally")
		_check(definition.get("from_positions") == FROM[card_id],
			card_id + ": authored FROM slots")
		_check(definition.get("to_positions") == [],
			card_id + ": authored ally target uses no enemy TO slots")
		_check(definition.get("effects") == {"heal": HEAL[card_id], "cleanse_debuff": 1},
			card_id + ": authored heal plus one cleanse")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
	_check(starter.get_upgrade_id(MEND) == MEND_PLUS
		and starter.get_upgrade_id(MEND_PLUS) == ""
		and pool.get_upgrade_id(DARN) == DARN_PLUS
		and pool.get_upgrade_id(DARN_PLUS) == "",
		"base and '+' records point at each other in their own catalogs")
	_check(not starter.has_card(DARN) and not pool.has_card(MEND),
		"the two printings are owned by separate catalogs")
	for unsupported in [
		"seamstress_v3_thread_prick", "seamstress_v3_tether_loop", "seamstress_v3_shielding_hem",
		"seamstress_v3_needle_rain", "seamstress_v3_patchwork_poultice", "seamstress_v3_tether_stitch",
		"seamstress_v3_blanket_of_barbs", "seamstress_v3_midnight_loom",
		"seamstress_v3_mending_knot_ultra", "seamstress_mend", "seamstress_mend_plus",
		"seamstress_darning", "seamstress_thimble_tea", "seamstress_field_mend",
		"warden_v3_rim_toss", "tinker_pop_shot", ""]:
		_check(not service.is_supported_card(unsupported),
			unsupported + ": not a v3 cleansing heal for this service")
	_check(not service.is_supported_card(5) and not service.is_supported_card(null),
		"non-string IDs are never supported")


## AC1: a genuine held copy is charged once, discarded once and heals exactly once.
func _test_ac1_one_paid_play() -> void:
	for card_id: String in CARD_IDS:
		var party := _party()
		_check(party.apply_damage(3, 10) and party.get_hero(3)["hp"] == 16,
			card_id + ": chosen Tinker really lost ten HP")
		var deck := _deck(card_id)
		var held_before: int = deck.hand.count(card_id)
		var before := _snapshot(deck, party)
		var result: Dictionary = service.play_card(deck, party, card_id, 3)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			card_id + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			card_id + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == 2 and result.get("target_position") == 3,
			card_id + ": receipt reports the Seamstress seat and the chosen ally slot")
		_check(result.get("heal") == HEAL[card_id] and result.get("healed") == HEAL[card_id]
			and result.get("hp_before") == 16 and result.get("hp_after") == 16 + HEAL[card_id],
			card_id + ": printed heal lands once")
		_check(result.get("cleansed_debuff") == "" and result.get("cleansed_count") == 0,
			card_id + ": no debuff was selected or removed")
		var expected := _expected_success(before, card_id, 3, "")
		_check(_snapshot(deck, party) == expected,
			card_id + ": exact hand/piles/energy/turn/heroes and untouched injected RNG")
		_check(deck.hand.count(card_id) == held_before - 1
			and deck.discard_pile.count(card_id) == 1 and deck.hand.size() == 4
			and deck.discard_pile.size() == 1,
			card_id + ": precisely one held copy moved to the discard pile")
		_check(deck.energy == 2, card_id + ": exactly one energy was charged")
		_check(party.get_hero(1)["hp"] == 40 and party.get_hero(2)["hp"] == 30
			and party.get_hero(2)["block"] == 0 and party.get_hero(1)["block"] == 0,
			card_id + ": every other hero's HP and Block is unchanged")
		_check(_snapshot(deck, party)["rng_state"] == before["rng_state"],
			card_id + ": no run-RNG draw during resolution")
		# The returned receipt is detached from the live party.
		result["healed"] = 999
		result["hp_after"] = 999
		_check(party.get_hero(3)["hp"] == 16 + HEAL[card_id],
			card_id + ": a mutated receipt cannot change the ally")


## AC2: one caller-selected present debuff kind loses its entire counter, the other stays exact.
func _test_ac2_selected_cleanse() -> void:
	for card_id: String in CARD_IDS:
		for selection: String in ["bleed", "weak"]:
			var label := "%s cleanse %s" % [card_id, selection]
			var party := _party()
			_check(party.apply_damage(3, 20) and party.get_hero(3)["hp"] == 6,
				label + ": ally damaged")
			party._heroes[2]["statuses"] = {"bleed": 3, "weak": 2}
			party._heroes[0]["statuses"] = {"weak": 4, "riposte": 2}
			_check(party.get_hero(3)["statuses"] == {"bleed": 3, "weak": 2},
				label + ": two independent debuffs really stored")
			var deck := _deck(card_id)
			var before := _snapshot(deck, party)
			var result: Dictionary = service.play_card(deck, party, card_id, 3, selection)
			_check(result.get("ok") == true, label + ": selected present debuff accepted")
			_check(result.get("cleansed_debuff") == selection
				and result.get("cleansed_count") == int({"bleed": 3, "weak": 2}[selection]),
				label + ": the entire selected counter is reported as removed")
			var remaining := {"bleed": 3, "weak": 2}
			remaining.erase(selection)
			_check(party.get_hero(3)["statuses"] == remaining,
				label + ": only the selected kind is gone; the other keeps its exact count")
			_check(party.get_hero(3)["hp"] == 6 + HEAL[card_id],
				label + ": printed heal applied once")
			_check(party.get_hero(1)["statuses"] == {"weak": 4, "riposte": 2},
				label + ": another hero's status map is untouched")
			_check(_snapshot(deck, party) == _expected_success(before, card_id, 3, selection),
				label + ": exact party, piles, energy and RNG state")


## AC2: Exposed is a separate legal selection; Tangled/Riposte are never cleansed.
func _test_ac2_exposed_and_unrelated_statuses() -> void:
	for card_id: String in CARD_IDS:
		var party := _party()
		_check(party.apply_damage(2, 7) and party.get_hero(2)["hp"] == 23,
			card_id + ": Seamstress ally really lost seven HP")
		party._heroes[1]["statuses"] = {"exposed": 4, "tangled": 2, "riposte": 5}
		_check(party.get_hero(2)["statuses"] == {"exposed": 4, "tangled": 2, "riposte": 5},
			card_id + ": unrelated statuses really stored beside Exposed")
		var deck := _deck(card_id)
		var before := _snapshot(deck, party)
		var result: Dictionary = service.play_card(deck, party, card_id, 2, "exposed")
		_check(result.get("ok") == true and result.get("cleansed_debuff") == "exposed"
			and result.get("cleansed_count") == 4,
			card_id + ": Exposed is a separate accepted selection")
		_check(party.get_hero(2)["statuses"] == {"tangled": 2, "riposte": 5},
			card_id + ": Tangled and Riposte are preserved at their exact counts")
		_check(party.get_hero(2)["hp"] == 23 + HEAL[card_id],
			card_id + ": self-target heal lands exactly once")
		_check(_snapshot(deck, party) == _expected_success(before, card_id, 2, "exposed"),
			card_id + ": full state matches the single Exposed cleanse")


## AC2: healing stops at the chosen ally's max HP; there is no over-heal or revival.
func _test_ac2_heal_cap() -> void:
	for card_id: String in CARD_IDS:
		var party := _party()
		_check(party.apply_damage(3, 1) and party.get_hero(3)["hp"] == 25,
			card_id + ": Tinker really sits one below max HP")
		var deck := _deck(card_id)
		var before := _snapshot(deck, party)
		var result: Dictionary = service.play_card(deck, party, card_id, 3)
		_check(result.get("ok") == true and result.get("healed") == 1
			and result.get("hp_before") == 25 and result.get("hp_after") == 26,
			card_id + ": heal caps at the 26 max HP and reports the actual gain")
		_check(_snapshot(deck, party) == _expected_success(before, card_id, 3, ""),
			card_id + ": a capped heal still charges and discards exactly once")


## AC2: a fully healthy or debuff-free ally is still a legal paid target.
func _test_ac2_full_hp_and_no_debuff() -> void:
	for card_id: String in CARD_IDS:
		var party := _party()
		var deck := _deck(card_id)
		var before := _snapshot(deck, party)
		var result: Dictionary = service.play_card(deck, party, card_id, 1, "")
		_check(result.get("ok") == true and result.get("healed") == 0
			and result.get("hp_after") == 40,
			card_id + ": a full-HP ally may still receive the paid card")
		_check(_snapshot(deck, party) == _expected_success(before, card_id, 1, ""),
			card_id + ": the full-HP play still pays and discards once")

	var wounded := _party()
	_check(wounded.apply_damage(1, 5) and wounded.get_hero(1)["hp"] == 35,
		"no-debuff fixture really has a wounded status-free ally")
	_check(wounded.get_hero(1).get("statuses", {}) == {},
		"no-debuff fixture really carries no status dictionary")
	var wounded_deck := _deck(MEND)
	var wounded_before := _snapshot(wounded_deck, wounded)
	var wounded_result: Dictionary = service.play_card(wounded_deck, wounded, MEND, 1, "")
	_check(wounded_result.get("ok") == true and wounded_result.get("healed") == 4
		and wounded.get_hero(1)["hp"] == 39,
		"a status-free wounded ally is healed by the printed amount")
	_check(_snapshot(wounded_deck, wounded) == _expected_success(wounded_before, MEND, 1, ""),
		"the no-debuff play changes only the chosen ally's HP and the deck")

	var expired := _party()
	expired._heroes[1]["statuses"] = {"bleed": 0, "tangled": 2}
	_check(expired.get_hero(2)["statuses"] == {"bleed": 0, "tangled": 2},
		"expired-counter fixture really stores a zero Bleed")
	var expired_deck := _deck(DARN)
	var expired_before := _snapshot(expired_deck, expired)
	var expired_result: Dictionary = service.play_card(expired_deck, expired, DARN, 2, "")
	_check(expired_result.get("ok") == true and expired_result.get("cleansed_debuff") == "",
		"an expired zero counter is not a debuff and needs the empty selection")
	_check(expired.get_hero(2)["statuses"] == {"bleed": 0, "tangled": 2},
		"the expired counter and Tangled stay exactly as they were")
	_check(_snapshot(expired_deck, expired) == _expected_success(expired_before, DARN, 2, ""),
		"the empty-selection play keeps a well-formed but ineligible status map")


## AC2: the authored FROM seat follows the real current party order.
func _test_ac2_owner_seats() -> void:
	for card_id: String in [DARN, DARN_PLUS]:
		for seat in [1, 3]:
			var label := "%s from real seat %d" % [card_id, seat]
			var party := _moved_party(seat)
			var front_max: int = party.get_hero(1)["max_hp"]
			_check(party.apply_damage(1, 10) and party.get_hero(1)["hp"] == front_max - 10,
				label + ": front ally damaged")
			var deck := _deck(card_id)
			var before := _snapshot(deck, party)
			var result: Dictionary = service.play_card(deck, party, card_id, 1, "")
			_check(result.get("ok") == true and result.get("owner_position") == seat,
				label + ": Darn the Tear is legal from the moved Seamstress seat")
			_check(result.get("healed") == HEAL[card_id],
				label + ": heal follows the moved owner")
			_check(_snapshot(deck, party) == _expected_success(before, card_id, 1, ""),
				label + ": exact transaction from the moved seat")

	for card_id: String in [MEND, MEND_PLUS]:
		var party := _moved_party(3)
		var middle_max: int = party.get_hero(2)["max_hp"]
		_check(party.apply_damage(2, 9) and party.get_hero(2)["hp"] == middle_max - 9,
			card_id + ": middle ally damaged for the rear-seat cleanup")
		var deck := _deck(card_id)
		var before := _snapshot(deck, party)
		var result: Dictionary = service.play_card(deck, party, card_id, 2, "")
		_check(result.get("ok") == true and result.get("owner_position") == 3
			and result.get("healed") == HEAL[card_id],
			card_id + ": Mending Knot is legal from the moved rear seat 3")
		_check(_snapshot(deck, party) == _expected_success(before, card_id, 2, ""),
			card_id + ": exact transaction from the rear seat")

	for card_id: String in [MEND, MEND_PLUS]:
		var front := _moved_party(1)
		_check(front.get_hero(1)["id"] == "seamstress" and front.get_hero(1)["position"] == 1,
			card_id + ": illegal-FROM fixture really has the living Seamstress in slot 1")
		_rejected(_deck(card_id), front, card_id, 2, "",
			card_id + " from an illegal FROM slot 1")


## AC3: every invalid request fails closed and leaves the whole transaction untouched.
func _test_ac3_rejections() -> void:
	var party := _party()

	var inactive := CombatDeck.new([MEND, MEND, MEND, FILLERS[0], FILLERS[1], FILLERS[2]], _rng(414))
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_rejected(inactive, party, MEND, 2, "", "inactive turn")

	var deck := _deck(DARN)
	_check(deck.hand.has(DARN) and not deck.hand.has(MEND),
		"absent-card fixture holds the other genuine ID only")
	_rejected(deck, party, MEND, 2, "", "card absent from hand")
	_rejected(deck, party, "missing_v3_cleansing_heal", 2, "", "unknown card ID")
	_rejected(deck, party, "", 2, "", "empty card ID")
	_rejected(deck, party, 7, 2, "", "non-string card ID")

	for wrong_card in ["seamstress_v3_shielding_hem", "seamstress_v3_thread_prick",
			"seamstress_v3_tether_loop", "seamstress_v3_patchwork_poultice",
			"seamstress_v3_midnight_loom", "seamstress_mend", "seamstress_mend_plus",
			"seamstress_darning", "seamstress_thimble_tea", "seamstress_field_mend",
			"warden_v3_rim_toss", "tinker_pop_shot"]:
		var wrong_deck := _deck(wrong_card)
		_rejected(wrong_deck, party, wrong_card, 2, "",
			"non-cleansing card in hand " + wrong_card)

	var short := _deck(MEND)
	_check(short.try_spend_energy(3) and short.energy == 0 and short.hand.has(MEND),
		"energy-short fixture is genuinely broke and still holds Mending Knot")
	_rejected(short, party, MEND, 2, "", "insufficient energy")

	var torn_owner := _party()
	_check(torn_owner.apply_damage(2, 30) and torn_owner.is_downed(2),
		"torn-caster fixture has a genuinely downed Seamstress")
	_rejected(_deck(MEND), torn_owner, MEND, 1, "", "torn (downed) caster")

	var torn_target := _party()
	_check(torn_target.apply_damage(3, 26) and torn_target.is_downed(3),
		"torn-target fixture has a genuinely downed Tinker")
	_rejected(_deck(DARN), torn_target, DARN, 3, "", "torn (downed) recipient")

	for bad_target in [0, -1, 4, 99]:
		_rejected(_deck(DARN), _party(), DARN, bad_target, "",
			"target outside 1-3: " + str(bad_target))

	var two := _party()
	two._heroes[1]["statuses"] = {"bleed": 3, "weak": 2}
	_check(two.get_hero(2)["statuses"] == {"bleed": 3, "weak": 2},
		"wrong-cleanse fixture really carries two independent debuffs")
	for wrong_cleanse in ["", "exposed", "tangled", "riposte", "bleed ", "Bleed", "weak2"]:
		_rejected(_deck(MEND), two, MEND, 2, wrong_cleanse,
			"wrongly selected or absent debuff " + str(wrong_cleanse))
	_rejected(_deck(MEND), two, MEND, 2, 1, "non-string cleanse selection")
	_rejected(_deck(MEND), two, MEND, 2, null, "null cleanse selection")

	var healthy := _party()
	_check(healthy.get_hero(3).get("statuses", {}) == {},
		"no-debuff fixture really has no eligible counter")
	_rejected(_deck(MEND), healthy, MEND, 3, "bleed", "debuff named but absent")

	var zeroed := _party()
	zeroed._heroes[2]["statuses"] = {"bleed": 0}
	_check(zeroed.get_hero(3)["statuses"] == {"bleed": 0},
		"zero-counter fixture really stores an expired counter")
	_rejected(_deck(MEND), zeroed, MEND, 3, "bleed",
		"expired zero counter is not a positive present debuff")

	var malformed_target := [
		"bleed", null, {"bleed": -1}, {"bleed": "3"}, {"bleed": 1.5}, {"weak": true},
		{"exposed": null}, {1: 2}, {"": 1},
	]
	for bad in malformed_target:
		var broken := _party()
		broken._heroes[2]["statuses"] = bad
		_check(broken.get_hero(3)["statuses"] == bad,
			"malformed-status fixture really stores " + str(bad))
		_rejected(_deck(DARN), broken, DARN, 3, "", "malformed recipient statuses " + str(bad))

	var malformed_other := _party()
	malformed_other._heroes[0]["statuses"] = {"weak": -2}
	malformed_other._heroes[2]["statuses"] = {"bleed": 2}
	_check(malformed_other.get_hero(1)["statuses"] == {"weak": -2},
		"non-target malformed fixture really stores a negative counter")
	_rejected(_deck(DARN), malformed_other, DARN, 3, "bleed",
		"malformed status snapshot on another hero")

	var records := _authored_party_records()
	var no_owner := CombatParty.new([
		records["warden"].duplicate(true), records["tinker"].duplicate(true),
		{"id": "mender", "name": "Mender", "max_hp": 20},
	])
	_check(no_owner.is_valid() and no_owner.get_hero(2)["id"] == "tinker"
		and no_owner.get_hero(3)["id"] == "mender",
		"missing-owner fixture is a valid three-hero party with no Seamstress")
	_rejected(_deck(DARN), no_owner, DARN, 3, "", "party with no Seamstress owner")

	var duplicated := _party()
	duplicated._heroes[0]["id"] = "seamstress"
	_check(duplicated.get_hero(1)["id"] == "seamstress"
		and duplicated.get_hero(2)["id"] == "seamstress",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected(_deck(DARN), duplicated, DARN, 3, "", "duplicate hero identity")

	var broken_roster := _party()
	broken_roster._heroes[1]["hp"] = 31
	_check(broken_roster.get_hero(2)["hp"] == 31 and broken_roster.get_hero(2)["max_hp"] == 30,
		"malformed-roster fixture really has HP above max")
	_rejected(_deck(MEND), broken_roster, MEND, 1, "", "malformed party HP")

	_rejected(null, _party(), DARN, 2, "", "null deck")
	_rejected(_deck(DARN), null, DARN, 2, "", "null party")
	_rejected(_deck(DARN), CombatParty.new([]), DARN, 2, "", "invalid party roster")


## AC3: a rejected attempt never poisons the next authentic one on the same objects.
func _test_ac3_retry_after_rejection() -> void:
	var party := _party()
	_check(party.apply_damage(2, 6) and party.get_hero(2)["hp"] == 24,
		"retry fixture really has a wounded Seamstress")
	party._heroes[1]["statuses"] = {"bleed": 3, "weak": 2}
	var deck := _deck(DARN)

	_rejected(deck, party, DARN, 2, "", "retry: missing selection with a present debuff")
	_rejected(deck, party, DARN, 0, "bleed", "retry: invalid target second")
	_rejected(deck, party, DARN, 2, "exposed", "retry: absent debuff third")

	var before := _snapshot(deck, party)
	var result: Dictionary = service.play_card(deck, party, DARN, 2, "weak")
	_check(result.get("ok") == true and result.get("healed") == 4
		and result.get("hp_after") == 28,
		"retry: the authentic play then succeeds and heals the wounded owner")
	_check(party.get_hero(2)["statuses"] == {"bleed": 3},
		"retry: only the selected Weak kind was removed")
	_check(_snapshot(deck, party) == _expected_success(before, DARN, 2, "weak"),
		"retry: exactly one charge, one discard and an untouched RNG")


## Each authentic play pays and discards once; one accepted copy cannot be replayed.
func _test_once_only_payment() -> void:
	var party := _party()
	party._heroes[1]["statuses"] = {"bleed": 1}
	var single := CombatDeck.new(
		[DARN, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], _rng(5150))
	_check(single.start_turn() and single.hand.count(DARN) == 1 and single.energy == 3,
		"single-copy fixture draws its one genuine copy")
	var first: Dictionary = service.play_card(single, party, DARN, 2, "bleed")
	_check(first.get("ok") == true and first.get("cleansed_count") == 1,
		"the single copy plays once and clears the one Bleed")
	_check(not single.hand.has(DARN), "the played copy leaves the hand")
	var replayed_at := _snapshot(single, party)
	var replay: Dictionary = service.play_card(single, party, DARN, 2, "")
	_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
		"a second play of the same ID fails once the copy is discarded")
	_check(_snapshot(single, party) == replayed_at,
		"the double-play refusal leaves the deck, roster and RNG untouched")

	var multi_party := _party()
	_check(multi_party.apply_damage(3, 25) and multi_party.get_hero(3)["hp"] == 1,
		"repeat fixture really has a nearly torn Tinker")
	var multi := CombatDeck.new(
		[DARN_PLUS, DARN_PLUS, DARN_PLUS, DARN_PLUS, DARN_PLUS, FILLERS[0]], _rng(2710))
	_check(multi.start_turn() and multi.hand.count(DARN_PLUS) >= 4
		and multi.hand.size() == 5 and multi.energy == 3,
		"repeat fixture draws a hand holding several genuine copies")
	var initial_rng: int = multi._rng.state
	var expected_hp: int = 1
	for play_index in range(3):
		var before := _snapshot(multi, multi_party)
		var result: Dictionary = service.play_card(multi, multi_party, DARN_PLUS, 3, "")
		expected_hp += HEAL[DARN_PLUS]
		_check(result.get("ok") == true and result.get("healed") == HEAL[DARN_PLUS]
			and result.get("hp_after") == expected_hp,
			"repeat play %d lands the same printed heal" % (play_index + 1))
		_check(multi.energy == 2 - play_index,
			"repeat play %d charges one energy" % (play_index + 1))
		_check(multi.hand.size() == 4 - play_index
			and multi.discard_pile.size() == play_index + 1,
			"repeat play %d discards exactly one copy" % (play_index + 1))
		_check(_snapshot(multi, multi_party)["rng_state"] == initial_rng,
			"repeat play %d draws no run RNG" % (play_index + 1))
		_check(_snapshot(multi, multi_party) == _expected_success(before, DARN_PLUS, 3, ""),
			"repeat play %d matches the single-transaction oracle" % (play_index + 1))
	_check(multi.energy == 0 and multi.hand.count(DARN_PLUS) >= 1,
		"repeat fixture still holds a copy but has no energy left")
	var before_empty := _snapshot(multi, multi_party)
	var refused: Dictionary = service.play_card(multi, multi_party, DARN_PLUS, 3, "")
	_check(refused.get("ok") == false and refused.get("reason") == "insufficient_energy",
		"a held copy cannot be played at zero energy")
	_check(_snapshot(multi, multi_party) == before_empty,
		"the energy refusal changes no pile, energy, hero or RNG")


## The same seed and the same request sequence produce identical outcomes; no RNG is consumed.
func _test_seeded_replay() -> void:
	var first := _replay_run(90210)
	var second := _replay_run(90210)
	_check(first == second, "seeded replay produces identical final state")
	_check(first["rng_state"] == second["rng_state"],
		"seeded replay consumes no run RNG at any step")
	_check(first["results"] == second["results"], "seeded replay reports the same receipts")
	_check(first["results"].size() == 4, "seeded replay covers all four printings")
	_check(first["results"][0].get("ok") == true and first["results"][1].get("ok") == true
		and first["results"][2].get("ok") == true and first["results"][3].get("ok") == false,
		"seeded replay keeps three legal plays and the zero-energy refusal")
	_check(first["hp"] == {"warden": 40, "seamstress": 27, "tinker": 14},
		"seeded replay lands the exact healed HP on the right heroes")
	_check(first["statuses"] == {},
		"seeded replay removes exactly the two selected debuff kinds")
	_check(first["results"][3].get("reason") == "insufficient_energy",
		"seeded replay's last refusal is the spent-energy rejection")


func _replay_run(seed_value: int) -> Dictionary:
	var party := _party()
	_check(party.apply_damage(3, 20) and party.get_hero(3)["hp"] == 6,
		"replay fixture damages Tinker to six HP")
	_check(party.apply_damage(2, 9) and party.get_hero(2)["hp"] == 21,
		"replay fixture damages the Seamstress to twenty-one HP")
	party._heroes[2]["statuses"] = {"bleed": 3, "weak": 2}
	# One isolated seeded deck holds all four named v3 IDs and starts the shared 5/3 turn.
	var deck := CombatDeck.new([MEND, MEND_PLUS, DARN, DARN_PLUS, FILLERS[0]], _rng(seed_value))
	_check(deck.start_turn() and deck.hand.size() == 5 and deck.energy == 3,
		"replay deck starts the real five-draw three-energy turn")
	for card_id: String in CARD_IDS:
		_check(deck.hand.has(card_id), "replay fixture holds " + card_id)
	var results: Array = []
	results.append(service.play_card(deck, party, MEND, 3, "weak"))
	results.append(service.play_card(deck, party, DARN, 3, "bleed"))
	results.append(service.play_card(deck, party, DARN_PLUS, 2, ""))
	results.append(service.play_card(deck, party, MEND_PLUS, 1, ""))
	var snapshot := _snapshot(deck, party)
	snapshot["results"] = results
	snapshot["hp"] = {
		"warden": party.get_hero(1)["hp"],
		"seamstress": party.get_hero(2)["hp"],
		"tinker": party.get_hero(3)["hp"],
	}
	snapshot["statuses"] = party.get_hero(3)["statuses"]
	return snapshot


func _rejected(deck: CombatDeck, party: CombatParty, card_id: Variant, target_position: int,
		cleanse_debuff: Variant, label: String) -> void:
	var before := _snapshot(deck, party)
	var result: Dictionary = service.play_card(deck, party, card_id, target_position, cleanse_debuff)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	_check(_snapshot(deck, party) == before,
		label + ": unchanged party, hand, draw, discard, energy, turn and RNG")


## The single-transaction expected state: one energy, one discarded held copy, one heal/cleanse.
func _expected_success(before: Dictionary, card_id: String, target_position: int,
		cleanse_debuff: String) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= 1
	expected["state_energy"] -= 1
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var hero: Dictionary = expected["heroes"][target_position - 1]
	if cleanse_debuff != "":
		var statuses: Dictionary = hero["statuses"]
		statuses.erase(cleanse_debuff)
	hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + int(HEAL[card_id]))
	return expected


func _snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
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


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real five-card hand from six cards, so at least two copies of the named ID are held.
func _deck(card_id: String, seed_value: int = 6452) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, FILLERS[0], FILLERS[1], FILLERS[2]]
	var deck := CombatDeck.new(ids, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(card_id) >= 2,
		card_id + ": real seeded five-card hand holding duplicate copies")
	return deck


func _authored_party_records() -> Dictionary:
	if not _authored.is_empty():
		return _authored
	var raw: String = FileAccess.get_file_as_string(HEROES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array and parsed.size() == CombatParty.PARTY_SIZE,
		"real authored starter party file supplies all three heroes")
	if not parsed is Array or parsed.size() != CombatParty.PARTY_SIZE:
		return {}
	for record in parsed:
		if not record is Dictionary:
			continue
		var hero: Dictionary = record.duplicate(true)
		if hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
		_authored[str(hero.get("id", ""))] = hero
	return _authored


func _party() -> CombatParty:
	var records := _authored_party_records()
	var definitions: Array = []
	for hero_id: String in ["warden", "seamstress", "tinker"]:
		_check(records.has(hero_id), "authored starter party contains " + hero_id)
		if not records.has(hero_id):
			return CombatParty.new([])
		definitions.append(records[hero_id].duplicate(true))
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("max_hp") == 26,
		"valid real CombatParty with the 40/30/26-HP Warden, Seamstress and Tinker")
	return party


## A genuine adjacent swap through the real position rules, not a hand-built roster.
func _moved_party(target_position: int) -> CombatParty:
	var party := _party()
	var move_id := "fixture_seamstress_shift"
	var moving := CombatDeck.new([move_id, move_id], _rng(345))
	_check(moving.start_turn(), "position fixture begins a legitimate shared turn")
	var direction := -1 if target_position < 2 else 1
	var definition := {"id": move_id, "owner": "seamstress", "cost": 0,
		"from_positions": [1, 2, 3], "action_kind": "adjacent_swap", "direction": direction}
	_check(CombatPositionSwaps.play_move_card(moving, party, move_id, definition),
		"actual adjacent move shifts the Seamstress toward slot " + str(target_position))
	_check(party.get_hero(target_position).get("id") == "seamstress"
		and party.get_hero(target_position).get("position") == target_position,
		"Seamstress identity is really at actual slot " + str(target_position))
	return party


# =============================================================================================
# Midnight Loom: the separate whole-party `play_party_card` / `is_supported_party_card` API.
# =============================================================================================

## The party API authenticates only the two authored Midnight Loom printings. The one-ally API keeps
## refusing them (and the party API refuses every one-ally printing), so neither API widens the other.
func _test_party_catalog_and_api() -> void:
	var pool := V3SeamstressPoolCards.new()
	for card_id: String in PARTY_CARD_IDS:
		var definition: Dictionary = pool.get_definition(card_id)
		_check(definition.get("id") == card_id, card_id + ": authored party-wide record exists")
		_check(definition.get("owner") == "seamstress", card_id + ": authored owner is Seamstress")
		_check(definition.get("cost") == LOOM_COST, card_id + ": authored cost is three energy")
		_check(definition.get("from_positions") == [2, 3],
			card_id + ": authored FROM seats 2 and 3")
		_check(definition.get("target_kind") == "party_all",
			card_id + ": authored target is the whole party")
		_check(definition.get("to_positions") == [],
			card_id + ": a party card names no enemy TO slots")
		_check(definition.get("effects") == {"heal": LOOM_HEAL[card_id],
			"block": LOOM_BLOCK[card_id], "cleanse_debuff": 1},
			card_id + ": authored heal, Block and one cleanse")
		_check(definition.get("rarity") == "rare", card_id + ": authored rarity is rare")
		_check(definition.get("starting_copies") == 0, card_id + ": not part of any starting deck")
		_check(service.is_supported_party_card(card_id),
			card_id + ": the party API authenticates the ID")
		_check(not service.is_supported_card(card_id),
			card_id + ": the one-ally API still refuses it")
	_check(pool.get_definition(LOOM).get("reward_eligible") == true,
		"Midnight Loom base is reward eligible")
	_check(pool.get_definition(LOOM_PLUS).get("reward_eligible") == false,
		"Midnight Loom+ is not independently reward eligible")
	_check(pool.get_upgrade_id(LOOM) == LOOM_PLUS and pool.get_upgrade_id(LOOM_PLUS) == "",
		"the base and '+' Loom records still point at each other")
	_check(pool.get_definition(LOOM_PLUS).get("upgrade_of") == LOOM,
		"Midnight Loom+ records Midnight Loom as its base")
	for card_id: String in CARD_IDS:
		_check(not service.is_supported_party_card(card_id),
			card_id + ": a one-ally cleansing heal is not a party card")
	for unsupported in [
		"seamstress_v3_thread_prick", "seamstress_v3_tether_loop", "seamstress_v3_shielding_hem",
		"seamstress_v3_needle_rain", "seamstress_v3_needle_rain_plus",
		"seamstress_v3_patchwork_poultice", "seamstress_v3_tether_stitch",
		"seamstress_v3_blanket_of_barbs", "seamstress_v3_blanket_of_barbs_plus",
		"seamstress_v3_darn_the_tear_ultra", "seamstress_mend", "seamstress_mend_plus",
		"seamstress_darning", "seamstress_thimble_tea", "seamstress_field_mend",
		"warden_v3_rim_toss", "tinker_pop_shot", "seamstress_v3_midnight_loom_plus_plus", ""]:
		_check(not service.is_supported_party_card(unsupported),
			unsupported + ": not a whole-party Loom printing")
	_check(not service.is_supported_party_card(5) and not service.is_supported_party_card(null)
		and not service.is_supported_party_card(StringName(LOOM)),
		"non-string party card IDs are never supported")


## AC1: a genuine held Loom is charged three energy once, discarded once and reaches all three
## living heroes, from a real Seamstress seat 2 (base) and seat 3 (the '+').
func _test_party_ac1_one_paid_play() -> void:
	for card_id: String in PARTY_CARD_IDS:
		var owner_seat := 2 if card_id == LOOM else 3
		var party := _party() if owner_seat == 2 else _moved_party(3)
		_check(party.is_valid() and party.get_hero(owner_seat).get("id") == "seamstress",
			card_id + ": fixture really has a living Seamstress in seat " + str(owner_seat))
		_check(party.apply_damage(1, 6) and party.apply_damage(2, 5)
			and party.apply_damage(3, 4),
			card_id + ": all three living heroes really lost HP")
		var deck := _party_deck(card_id)
		var before := _snapshot(deck, party)
		var selections := _empty_selections()
		var result: Dictionary = service.play_party_card(deck, party, card_id, selections)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			card_id + ": authorized paid party-wide play")
		_check(result.get("card_id") == card_id and result.get("cost") == LOOM_COST,
			card_id + ": receipt names the authentic card and its three energy")
		_check(result.get("owner_position") == owner_seat,
			card_id + ": receipt reports the real current owner seat")
		_check(result.get("heal") == LOOM_HEAL[card_id]
			and result.get("block") == LOOM_BLOCK[card_id],
			card_id + ": receipt reports the printed heal and Block")
		var seats: Array = result.get("seats", [])
		_check(seats.size() == 3, card_id + ": all three living heroes receive the card")
		_check(deck.energy == 0 and deck.combat_state.energy == 0,
			card_id + ": exactly three energy was charged")
		_check(deck.hand.size() == 4 and deck.discard_pile == [card_id]
			and deck.discard_pile.size() == 1,
			card_id + ": precisely one held copy moved to the discard pile")
		_check(_snapshot(deck, party) == _expected_party_success(before, card_id, selections),
			card_id + ": exact hand/piles/energy/turn/roster and untouched injected RNG")
		for position in [1, 2, 3]:
			var seat_before: Dictionary = before["heroes"][position - 1]
			var hero: Dictionary = party.get_hero(position)
			_check(hero["hp"] == mini(int(seat_before["max_hp"]),
				int(seat_before["hp"]) + LOOM_HEAL[card_id]),
				card_id + ": seat %d is healed up to its own maximum" % position)
			_check(hero["block"] == int(seat_before["block"]) + LOOM_BLOCK[card_id],
				card_id + ": seat %d gains exactly the printed Block" % position)
		_check(_snapshot(deck, party)["rng_state"] == before["rng_state"],
			card_id + ": no run-RNG draw during party resolution")
		# The returned receipt is detached from the live party.
		result["healed"] = 999
		if not seats.is_empty():
			(seats[0] as Dictionary)["hp_after"] = 999
		_check(party.get_hero(1)["hp"] == mini(40, 34 + LOOM_HEAL[card_id]),
			card_id + ": a mutated receipt cannot change a hero")

	# AC1: the authored FROM seats 2 and 3 really exclude a living Seamstress in slot 1.
	for card_id: String in PARTY_CARD_IDS:
		var front := _moved_party(1)
		_check(front.get_hero(1).get("id") == "seamstress"
			and front.get_hero(1).get("position") == 1,
			card_id + ": illegal-FROM fixture really has the living Seamstress in slot 1")
		var front_deck := _party_deck(card_id)
		_check(front_deck.hand.has(card_id),
			card_id + ": front-seat fixture genuinely holds the Loom")
		_party_rejected(front_deck, front, card_id, _empty_selections(),
			card_id + " from the illegal FROM slot 1", "owner_illegal_position")


## AC2: the exact before/after three-hero roster, with a fully living party and a partially
## downed party where the torn hero is left entirely alone.
func _test_party_ac2_roster_effects() -> void:
	# --- All three heroes living. ---
	var party := _party()
	_check(party.apply_damage(1, 12) and party.apply_damage(2, 3),
		"full-party fixture really wounded two heroes")
	var before: Array[Dictionary] = party.get_heroes()
	var deck := _party_deck(LOOM)
	var selections := _empty_selections()
	var result: Dictionary = service.play_party_card(deck, party, LOOM, selections)
	_check(result.get("ok") == true, "the full-party Loom play succeeds")
	var expected: Array = before.duplicate(true)
	expected[0]["hp"] = 32
	expected[0]["block"] = 4
	expected[1]["hp"] = 30
	expected[1]["block"] = 4
	expected[2]["hp"] = 26
	expected[2]["block"] = 4
	_check(party.get_heroes() == expected,
		"exact roster after one Loom: 32/30/26 HP and 4 Block on each living hero")
	_check(not party.get_hero(1).has("statuses") and not party.get_hero(2).has("statuses")
		and not party.get_hero(3).has("statuses"),
		"no status dictionary is invented by a status-free party play")

	# --- One torn hero. ---
	var downed := _party()
	_check(downed.apply_damage(3, 26) and downed.is_downed(3),
		"partially downed fixture really has a torn Tinker")
	downed._heroes[2]["statuses"] = {"bleed": 3, "riposte": 2}
	_check(downed.apply_damage(1, 10) and downed.apply_damage(2, 7),
		"partially downed fixture really wounded both living heroes")
	downed._heroes[1]["statuses"] = {"weak": 2}
	var downed_before: Array[Dictionary] = downed.get_heroes()
	var torn_before: Dictionary = downed_before[2].duplicate(true)
	var downed_deck := _party_deck(LOOM_PLUS)
	var downed_snapshot := _snapshot(downed_deck, downed)
	var downed_selections := {1: "", 2: "weak"}
	var downed_result: Dictionary = service.play_party_card(
		downed_deck, downed, LOOM_PLUS, downed_selections)
	_check(downed_result.get("ok") == true, "Midnight Loom+ succeeds with one torn seat")
	var reported: Array = downed_result.get("seats", [])
	_check(reported.size() == 2 and reported[0].get("position") == 1
		and reported[1].get("position") == 2,
		"only the two living seats report an outcome")
	_check(downed.get_heroes()[2] == torn_before,
		"the torn hero is entirely unchanged: no revive, no Block, no cleanse")
	_check(downed.get_hero(3)["hp"] == 0 and downed.get_hero(3)["block"] == 0,
		"the torn hero stays downed at zero HP and zero Block")
	var downed_expected: Array = downed_before.duplicate(true)
	downed_expected[0]["hp"] = 36
	downed_expected[0]["block"] = 6
	downed_expected[1]["hp"] = 29
	downed_expected[1]["block"] = 6
	downed_expected[1]["statuses"] = {}
	_check(downed.get_heroes() == downed_expected,
		"exact roster: 36/29 HP and 6 Block on the living pair, torn Tinker untouched")
	_check(downed.get_hero(1)["hp"] == 36 and downed.get_hero(2)["hp"] == 29,
		"both living heroes, including the Seamstress, receive the printed heal")
	_check(_snapshot(downed_deck, downed)
		== _expected_party_success(downed_snapshot, LOOM_PLUS, downed_selections),
		"the torn-seat play still charges and discards exactly once")


## AC2: every living target stops at its OWN maximum HP; there is no over-heal and no extra effect.
func _test_party_ac2_heal_cap() -> void:
	for card_id: String in PARTY_CARD_IDS:
		var party := _party() if card_id == LOOM else _moved_party(3)
		var deck := _party_deck(card_id)
		var maxima: Array[int] = []
		for index in range(CombatParty.PARTY_SIZE):
			maxima.append(int(party.get_hero(index + 1)["max_hp"]))
			_check(party.apply_damage(index + 1, 1),
				card_id + ": seat %d really sits one below max" % (index + 1))
		var before := _snapshot(deck, party)
		var selections := _empty_selections()
		var result: Dictionary = service.play_party_card(deck, party, card_id, selections)
		_check(result.get("ok") == true, card_id + ": a capped party heal is a legal paid play")
		var seats: Array = result.get("seats", [])
		_check(seats.size() == 3, card_id + ": three living seats are healed")
		for index in range(CombatParty.PARTY_SIZE):
			var seat: Dictionary = seats[index]
			_check(seat.get("position") == index + 1 and seat.get("healed") == 1
				and seat.get("hp_after") == maxima[index]
				and seat.get("hp_before") == maxima[index] - 1,
				card_id + ": seat %d heals exactly one point up to its own cap" % (index + 1))
			_check(party.get_hero(index + 1)["hp"] == maxima[index],
				card_id + ": seat %d never overheals past its max HP" % (index + 1))
		_check(result.get("healed") == 3,
			card_id + ": the receipt totals the three actually restored points")
		_check(_snapshot(deck, party) == _expected_party_success(before, card_id, selections),
			card_id + ": a capped party heal still charges and discards exactly once")


## AC3: one explicit present kind per living hero loses its whole counter; every unselected
## status (including Tangled and Riposte) is preserved exactly.
func _test_party_ac3_selected_cleanse() -> void:
	var party := _party()
	_check(party.apply_damage(1, 4) and party.apply_damage(2, 9) and party.apply_damage(3, 11),
		"cleanse fixture really wounded all three heroes")
	party._heroes[0]["statuses"] = {"bleed": 3, "riposte": 2, "tangled": 1}
	party._heroes[1]["statuses"] = {"weak": 4, "tangled": 2}
	party._heroes[2]["statuses"] = {"exposed": 2, "riposte": 5, "dodge_next_attack": 1}
	_check(party.get_hero(1)["statuses"] == {"bleed": 3, "riposte": 2, "tangled": 1}
		and party.get_hero(2)["statuses"] == {"weak": 4, "tangled": 2}
		and party.get_hero(3)["statuses"] == {"exposed": 2, "riposte": 5, "dodge_next_attack": 1},
		"three independent per-seat debuff maps are really stored")
	var deck := _party_deck(LOOM)
	var before := _snapshot(deck, party)
	var selections := {1: "bleed", 2: "weak", 3: "exposed"}
	var result: Dictionary = service.play_party_card(deck, party, LOOM, selections)
	_check(result.get("ok") == true, "three independent per-seat selections are accepted")
	var seats: Array = result.get("seats", [])
	_check(seats.size() == 3 and seats[0].get("cleansed_debuff") == "bleed"
		and seats[1].get("cleansed_debuff") == "weak"
		and seats[2].get("cleansed_debuff") == "exposed",
		"the receipt reports each seat's explicitly chosen kind")
	_check(seats[0].get("cleansed_count") == 3 and seats[1].get("cleansed_count") == 4
		and seats[2].get("cleansed_count") == 2,
		"each chosen kind loses its entire counter, not one stack")
	_check(result.get("cleansed_count") == 9,
		"the receipt totals the whole counters removed across the party")
	_check(party.get_hero(1)["statuses"] == {"riposte": 2, "tangled": 1},
		"seat 1 keeps its Riposte and Tangled untouched")
	_check(party.get_hero(2)["statuses"] == {"tangled": 2},
		"seat 2 keeps its Tangled untouched")
	_check(party.get_hero(3)["statuses"] == {"riposte": 5, "dodge_next_attack": 1},
		"seat 3 keeps its Riposte and one-shot Dodge token untouched")
	_check(_snapshot(deck, party) == _expected_party_success(before, LOOM, selections),
		"exact party, piles, energy and RNG state after three selected cleanses")

	# A hero carrying two eligible kinds loses only the named one, whichever the caller picks.
	for choice: String in ["bleed", "weak"]:
		var mixed := _party()
		mixed._heroes[0]["statuses"] = {"weak": 1}
		mixed._heroes[1]["statuses"] = {"bleed": 2, "weak": 5}
		var mixed_deck := _party_deck(LOOM_PLUS)
		var mixed_before := _snapshot(mixed_deck, mixed)
		var pick := {1: "weak", 2: choice}
		var mixed_result: Dictionary = service.play_party_card(
			mixed_deck, mixed, LOOM_PLUS, pick)
		_check(mixed_result.get("ok") == true, "a mixed-debuff party accepts " + choice)
		var expected_mixed := {"bleed": 2, "weak": 5}
		expected_mixed.erase(choice)
		_check(mixed.get_hero(2)["statuses"] == expected_mixed,
			"seat 2 removes only the explicitly selected " + choice)
		_check(mixed.get_hero(1)["statuses"] == {},
			"seat 1's separate Weak selection is removed")
		_check(mixed.get_hero(1)["hp"] == 40 and mixed.get_hero(1)["block"] == 6,
			"the full-HP seat 1 still gains Block from " + choice)
		_check(_snapshot(mixed_deck, mixed)
			== _expected_party_success(mixed_before, LOOM_PLUS, pick),
			"exact state after the mixed " + choice + " play")


## AC3: every bad party transaction fails closed before spending or writing ANY hero.
func _test_party_ac3_rejections() -> void:
	var party := _party()
	var selections := _empty_selections()

	var inactive := CombatDeck.new(
		[LOOM, LOOM, LOOM, FILLERS[0], FILLERS[1], FILLERS[2]], _rng(818))
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_party_rejected(inactive, party, LOOM, selections, "inactive turn", "inactive_turn")

	var other := _deck(DARN)
	_check(other.hand.has(DARN) and not other.hand.has(LOOM),
		"absent-card fixture holds the one-ally Darn the Tear only")
	_party_rejected(other, party, LOOM, selections, "Midnight Loom absent from hand",
		"card_not_held")
	_party_rejected(other, party, DARN, selections,
		"a genuine one-ally printing is not a party card", "unsupported_card")
	_party_rejected(_deck(MEND), party, MEND, selections,
		"Mending Knot is not a party card", "unsupported_card")
	var held := _party_deck(LOOM)
	_check(held.hand.has(LOOM), "ID fixture genuinely holds Midnight Loom")
	for bad_id in ["missing_v3_party_heal", "", "seamstress_v3_midnight_loom_plus_plus",
			7, null, StringName(LOOM)]:
		_party_rejected(held, party, bad_id, selections,
			"unsupported party card ID " + str(bad_id), "unsupported_card")
	_party_rejected(held, party, LOOM_PLUS, selections,
		"a valid but unheld '+' printing", "card_not_held")

	for bad_selections in [null, [], "bleed", 3, true]:
		_party_rejected(_party_deck(LOOM), party, LOOM, bad_selections,
			"non-dictionary per-seat selections " + str(bad_selections), "invalid_selections")
	for bad_key in ["1", 0, 4, -1, 99, true, 1.5]:
		_party_rejected(_party_deck(LOOM), party, LOOM, {bad_key: ""},
			"invalid per-seat selection key " + str(bad_key), "invalid_selections")

	var missing := _party()
	missing._heroes[1]["statuses"] = {"weak": 2}
	_check(missing.get_hero(2)["statuses"] == {"weak": 2},
		"missing-selection fixture really carries Weak")
	_party_rejected(_party_deck(LOOM), missing, LOOM, {1: "", 3: ""},
		"a debuffed living hero with no explicit selection", "cleanse_required")
	_party_rejected(_party_deck(LOOM), missing, LOOM, {1: "", 2: "", 3: ""},
		"an empty selection while a debuff is present", "cleanse_required")
	_party_rejected(_party_deck(LOOM), missing, LOOM, {1: "", 2: "bleed", 3: ""},
		"a kind that is not present on that seat", "cleanse_required")
	_party_rejected(_party_deck(LOOM), missing, LOOM, {1: "", 2: 3, 3: ""},
		"a non-string per-seat selection", "invalid_selections")
	_party_rejected(_party_deck(LOOM), missing, LOOM, {1: "", 2: "weak ", 3: ""},
		"a misspelled kind is not the present debuff", "cleanse_required")
	_check(missing.get_hero(2)["statuses"] == {"weak": 2},
		"no rejected selection touched the Weak counter")

	var named_absent := _party()
	_party_rejected(_party_deck(LOOM), named_absent, LOOM, {1: "bleed", 2: "", 3: ""},
		"a kind named on a hero that carries none", "cleanse_not_present")

	var expired := _party()
	expired._heroes[0]["statuses"] = {"bleed": 0}
	_check(expired.get_hero(1)["statuses"] == {"bleed": 0},
		"zero-counter fixture really stores an expired Bleed")
	_party_rejected(_party_deck(LOOM), expired, LOOM, {1: "bleed", 2: "", 3: ""},
		"an expired zero counter is not a present debuff", "cleanse_not_present")

	var torn := _party()
	_check(torn.apply_damage(3, 26) and torn.is_downed(3),
		"torn-seat fixture really has a downed Tinker")
	_party_rejected(_party_deck(LOOM), torn, LOOM, {1: "", 2: "", 3: ""},
		"a downed seat may not carry a selection", "invalid_selections")
	_party_rejected(_party_deck(LOOM), torn, LOOM, {1: "", 2: "", 3: "bleed"},
		"a downed seat may not select a cleanse kind", "invalid_selections")

	var short := _party_deck(LOOM)
	_check(short.try_spend_energy(1) and short.energy == 2 and short.hand.has(LOOM),
		"energy-short fixture is genuinely broke and still holds the Loom")
	_party_rejected(short, party, LOOM, selections, "insufficient energy for three energy",
		"insufficient_energy")

	var no_owner := _no_owner_party()
	_check(no_owner.is_valid(), "missing-owner fixture is a valid three-hero party")
	_party_rejected(_party_deck(LOOM), no_owner, LOOM, selections,
		"party with no Seamstress owner", "owner_missing")

	var duplicated := _party()
	duplicated._heroes[0]["id"] = "seamstress"
	_check(duplicated.get_hero(1)["id"] == "seamstress"
		and duplicated.get_hero(2)["id"] == "seamstress",
		"duplicate-identity fixture really repeats the owner ID")
	_party_rejected(_party_deck(LOOM), duplicated, LOOM, selections,
		"duplicate hero identity", "invalid_party")

	var torn_owner := _party()
	_check(torn_owner.apply_damage(2, 30) and torn_owner.is_downed(2),
		"torn-owner fixture really has a downed Seamstress")
	_party_rejected(_party_deck(LOOM), torn_owner, LOOM, {1: "", 3: ""},
		"torn (downed) owner", "owner_downed")

	var front := _moved_party(1)
	_check(front.get_hero(1)["id"] == "seamstress" and front.get_hero(1)["position"] == 1,
		"illegal-seat fixture really has the living owner in slot 1")
	_party_rejected(_party_deck(LOOM), front, LOOM, selections,
		"owner in the illegal FROM slot 1", "owner_illegal_position")

	for bad in [
		"bleed", null, {"bleed": -1}, {"bleed": "3"}, {"bleed": 1.5}, {"weak": true},
		{"exposed": null}, {1: 2}, {"": 1}, [],
	]:
		var broken := _party()
		broken._heroes[0]["statuses"] = bad
		_check(broken.get_hero(1)["statuses"] == bad,
			"malformed-status fixture really stores " + str(bad))
		_party_rejected(_party_deck(LOOM), broken, LOOM, selections,
			"malformed status map on a living seat " + str(bad), "malformed_statuses")

	var broken_torn := _party()
	_check(broken_torn.apply_damage(3, 26), "malformed downed fixture really tore the Tinker")
	broken_torn._heroes[2]["statuses"] = {"bleed": -1}
	_party_rejected(_party_deck(LOOM), broken_torn, LOOM, {1: "", 2: ""},
		"malformed status map on an already torn seat", "malformed_statuses")

	var broken_roster := _party()
	broken_roster._heroes[1]["hp"] = 31
	_check(broken_roster.get_hero(2)["hp"] == 31
		and broken_roster.get_hero(2)["max_hp"] == 30,
		"malformed-roster fixture really has HP above max")
	_party_rejected(_party_deck(LOOM), broken_roster, LOOM, selections,
		"malformed party HP", "invalid_party")

	var overflow := _party()
	overflow._heroes[0]["block"] = CombatParty.MAX_INT - 3
	_check(overflow.get_hero(1)["block"] == CombatParty.MAX_INT - 3,
		"block-overflow fixture really sits three below the integer ceiling")
	_party_rejected(_party_deck(LOOM), overflow, LOOM, selections,
		"Block capacity the real gain_block would refuse", "block_overflow")

	_party_rejected(null, _party(), LOOM, selections, "null deck", "invalid_request")
	_party_rejected(_party_deck(LOOM), null, LOOM, selections, "null party",
		"invalid_request")
	_party_rejected(_party_deck(LOOM), CombatParty.new([]), LOOM, selections,
		"invalid party roster", "invalid_party")


## AC3: a rejected party transaction never poisons the next authentic one on the same objects.
func _test_party_ac3_retry_after_rejection() -> void:
	var party := _party()
	_check(party.apply_damage(1, 5) and party.apply_damage(2, 11) and party.apply_damage(3, 9),
		"retry fixture really wounded all three heroes")
	party._heroes[0]["statuses"] = {"bleed": 2, "tangled": 1}
	party._heroes[2]["statuses"] = {"weak": 4}
	var deck := _party_deck(LOOM_PLUS)

	_party_rejected(deck, party, LOOM_PLUS, {1: "exposed", 2: "", 3: "weak"},
		"retry: absent kind on seat 1", "cleanse_required")
	_party_rejected(deck, party, LOOM_PLUS, {1: "", 2: "", 3: "weak"},
		"retry: seat 1's present Bleed left unnamed", "cleanse_required")
	_party_rejected(deck, party, LOOM_PLUS, {1: "bleed", 2: "", 3: "weak", 4: ""},
		"retry: seat 4 is not a real party position", "invalid_selections")
	_party_rejected(deck, party, LOOM_PLUS, {1: "bleed", 2: "", 3: 4},
		"retry: a non-string seat selection", "invalid_selections")

	var before := _snapshot(deck, party)
	var result: Dictionary = service.play_party_card(
		deck, party, LOOM_PLUS, {1: "bleed", 2: "", 3: "weak"})
	_check(result.get("ok") == true and result.get("healed") == 17,
		"retry: the authentic party play then succeeds and heals the whole party")
	_check(party.get_hero(1)["statuses"] == {"tangled": 1},
		"retry: seat 1 keeps its Tangled")
	_check(party.get_hero(3).get("statuses", {}) == {},
		"retry: seat 3's Weak is gone")
	_check(not party.get_hero(2).has("statuses"),
		"retry: the status-free seat gains no status dictionary")
	_check(_snapshot(deck, party) == _expected_party_success(
		before, LOOM_PLUS, {1: "bleed", 2: "", 3: "weak"}),
		"retry: exactly one charge, one discard and an untouched RNG")


## A paid party card pays and discards once; the same copy can never be played twice.
func _test_party_once_only_payment() -> void:
	var party := _party()
	party._heroes[0]["statuses"] = {"bleed": 1}
	var single := _party_single_copy_deck(LOOM)
	_check(single.hand.count(LOOM) == 1 and single.energy == 3,
		"single-copy fixture draws its one genuine Loom copy")
	var first: Dictionary = service.play_party_card(
		single, party, LOOM, {1: "bleed", 2: "", 3: ""})
	_check(first.get("ok") == true and first.get("cleansed_count") == 1,
		"the single held copy plays once and clears the one Bleed")
	_check(not single.hand.has(LOOM) and single.discard_pile == [LOOM],
		"the played copy leaves the hand for the discard pile")
	var replay_at := _snapshot(single, party)
	var replay: Dictionary = service.play_party_card(single, party, LOOM, _empty_selections())
	_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
		"a second party play fails once the copy is discarded")
	_check(_snapshot(single, party) == replay_at,
		"the replay refusal leaves the deck, roster and RNG untouched")

	var multi_party := _party()
	for index in range(CombatParty.PARTY_SIZE):
		_check(multi_party.apply_damage(index + 1, 4),
			"repeat fixture really wounded party seat %d" % (index + 1))
	var multi := _party_deck(LOOM_PLUS)
	var before := _snapshot(multi, multi_party)
	var accepted: Dictionary = service.play_party_card(
		multi, multi_party, LOOM_PLUS, _empty_selections())
	_check(accepted.get("ok") == true and multi.energy == 0,
		"a three-energy party play empties the shared bank")
	_check(_snapshot(multi, multi_party)
		== _expected_party_success(before, LOOM_PLUS, _empty_selections()),
		"the accepted play matches the single-transaction oracle")
	_check(multi.hand.has(LOOM_PLUS),
		"the fixture still holds another genuine copy at zero energy")
	var refused_at := _snapshot(multi, multi_party)
	var refused: Dictionary = service.play_party_card(
		multi, multi_party, LOOM_PLUS, _empty_selections())
	_check(refused.get("ok") == false and refused.get("reason") == "insufficient_energy",
		"a held copy cannot be played at zero energy")
	_check(_snapshot(multi, multi_party) == refused_at,
		"the energy refusal changes no pile, energy, hero or RNG")


## The same seed and the same party requests produce identical outcomes; no RNG is consumed.
func _test_party_seeded_replay() -> void:
	var first := _party_replay_run(31415)
	var second := _party_replay_run(31415)
	_check(first["state"] == second["state"],
		"seeded party replay produces an identical final state")
	_check(first["results"] == second["results"],
		"seeded party replay reports the same receipts")
	_check(first["results"].size() == 2 and first["results"][0].get("ok") == true
		and first["results"][1].get("ok") == true,
		"seeded party replay covers both Loom printings")
	_check(first["rng_after_start"] == first["rng_after_play"],
		"party resolution draws no run RNG for either printing")
	_check(first["hp"] == {"warden": 35, "seamstress": 22, "tinker": 10},
		"seeded base replay lands the exact healed HP on the right heroes")
	_check(first["statuses"] == {"warden": {"tangled": 2}, "seamstress": {},
		"tinker": {"riposte": 1}},
		"seeded base replay removes exactly the two selected debuff kinds")
	_check(first["plus_hp"] == {"warden": 40, "seamstress": 29, "tinker": 17},
		"seeded '+' replay lands the exact healed and Blocked party")
	_check(first["plus_statuses"] == {"warden": {}, "seamstress": {}, "tinker": {}},
		"seeded '+' replay removes exactly the one selected debuff kind")
	_check(first["plus_blocks"] == {"warden": 6, "seamstress": 6, "tinker": 6},
		"seeded '+' replay grants the printed six Block to every living hero")


func _party_replay_run(seed_value: int) -> Dictionary:
	# --- Midnight Loom from the real seat 2. ---
	var base_party := _party()
	_check(base_party.apply_damage(1, 9) and base_party.apply_damage(2, 12)
		and base_party.apply_damage(3, 20),
		"replay fixture damages all three heroes")
	base_party._heroes[0]["statuses"] = {"bleed": 3, "tangled": 2}
	base_party._heroes[2]["statuses"] = {"weak": 2, "riposte": 1}
	var base_deck := CombatDeck.new(
		[LOOM, LOOM, FILLERS[0], FILLERS[1], FILLERS[2]], _rng(seed_value))
	_check(base_deck.start_turn() and base_deck.hand.size() == 5
		and base_deck.energy == 3,
		"replay deck starts the real five-draw three-energy turn")
	var base_start_rng: int = base_deck._rng.state
	var base_result: Dictionary = service.play_party_card(
		base_deck, base_party, LOOM, {1: "bleed", 2: "", 3: "weak"})
	var base_after_rng: int = base_deck._rng.state

	# --- Midnight Loom+ from the real seat 3. ---
	var plus_party := _moved_party(3)
	_check(plus_party.apply_damage(1, 4) and plus_party.apply_damage(2, 15)
		and plus_party.apply_damage(3, 7),
		"replay fixture damages the moved party")
	plus_party._heroes[1]["statuses"] = {"exposed": 2}
	var plus_deck := CombatDeck.new(
		[LOOM_PLUS, LOOM_PLUS, FILLERS[0], FILLERS[1], FILLERS[2]], _rng(seed_value + 1))
	_check(plus_deck.start_turn() and plus_deck.hand.size() == 5
		and plus_deck.energy == 3,
		"replay deck for the '+' starts the same shared turn")
	var plus_start_rng: int = plus_deck._rng.state
	var plus_result: Dictionary = service.play_party_card(
		plus_deck, plus_party, LOOM_PLUS, {1: "", 2: "exposed", 3: ""})
	var plus_after_rng: int = plus_deck._rng.state

	return {
		"state": {"base": _snapshot(base_deck, base_party),
			"plus": _snapshot(plus_deck, plus_party)},
		"results": [base_result, plus_result],
		"rng_after_start": [base_start_rng, plus_start_rng],
		"rng_after_play": [base_after_rng, plus_after_rng],
		"hp": {
			"warden": base_party.get_hero(1)["hp"],
			"seamstress": base_party.get_hero(2)["hp"],
			"tinker": base_party.get_hero(3)["hp"],
		},
		"statuses": {
			"warden": base_party.get_hero(1).get("statuses", {}),
			"seamstress": base_party.get_hero(2).get("statuses", {}),
			"tinker": base_party.get_hero(3).get("statuses", {}),
		},
		"plus_hp": {
			"warden": plus_party.get_hero(1)["hp"],
			"seamstress": plus_party.get_hero(3)["hp"],
			"tinker": plus_party.get_hero(2)["hp"],
		},
		"plus_blocks": {
			"warden": plus_party.get_hero(1)["block"],
			"seamstress": plus_party.get_hero(3)["block"],
			"tinker": plus_party.get_hero(2)["block"],
		},
		"plus_statuses": {
			"warden": plus_party.get_hero(1).get("statuses", {}),
			"seamstress": plus_party.get_hero(3).get("statuses", {}),
			"tinker": plus_party.get_hero(2).get("statuses", {}),
		},
	}


func _empty_selections() -> Dictionary:
	return {1: "", 2: "", 3: ""}


func _party_rejected(deck: CombatDeck, party: CombatParty, card_id: Variant,
		selections: Variant, label: String, expected_reason: String = "") -> void:
	var before := _snapshot(deck, party)
	var result: Dictionary = service.play_party_card(deck, party, card_id, selections)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	if not expected_reason.is_empty():
		_check(result.get("reason") == expected_reason,
			label + ": refused as " + expected_reason + " (got "
				+ str(result.get("reason")) + ")")
	_check(_snapshot(deck, party) == before,
		label + ": unchanged party, hand, draw, discard, energy, turn and RNG")


## The party-transaction expected state: three energy, one discarded held copy, then the printed
## heal (capped per hero), printed Block and the named cleanse on every LIVING seat only.
func _expected_party_success(before: Dictionary, card_id: String,
		selections: Dictionary) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= LOOM_COST
	expected["state_energy"] -= LOOM_COST
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = expected["heroes"][index]
		if int(hero["hp"]) == 0:
			continue
		var selection: String = str(selections.get(index + 1, ""))
		if selection != "":
			var statuses: Dictionary = hero["statuses"]
			statuses.erase(selection)
			hero["statuses"] = statuses
		hero["block"] = int(hero["block"]) + int(LOOM_BLOCK[card_id])
		hero["hp"] = mini(int(hero["max_hp"]),
			int(hero["hp"]) + int(LOOM_HEAL[card_id]))
	return expected


## A real five-card hand from six cards, so at least two copies of the named Loom are held and one
## copy survives the single three-energy play.
func _party_deck(card_id: String, seed_value: int = 7321) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, FILLERS[0], FILLERS[1], FILLERS[2]]
	var deck := CombatDeck.new(ids, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(card_id) >= 2,
		card_id + ": real seeded five-card hand holding duplicate Loom copies")
	return deck


## A real five-card hand holding exactly one copy, for the discarded-copy replay refusal.
func _party_single_copy_deck(card_id: String, seed_value: int = 4417) -> CombatDeck:
	var ids: Array[String] = [card_id, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]]
	var deck := CombatDeck.new(ids, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(card_id) == 1,
		card_id + ": real seeded hand holding exactly one Loom copy")
	return deck


func _no_owner_party() -> CombatParty:
	var records := _authored_party_records()
	return CombatParty.new([
		records["warden"].duplicate(true), records["tinker"].duplicate(true),
		{"id": "mender", "name": "Mender", "max_hp": 20},
	])
