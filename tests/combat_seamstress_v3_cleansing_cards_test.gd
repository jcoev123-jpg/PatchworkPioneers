extends SceneTree
## Deterministic, headless contract for the V3-1 Seamstress cleansing heals.
##
## Mending Knot lives in the v3 starter catalog and Darn the Tear in the v3 reward pool, so
## neither is assumed to be part of the mounted starter deck: every case builds a real seeded
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

## Independent literal expectations copied from the v3 design, never read from the resolver.
const HEAL := {MEND: 4, MEND_PLUS: 6, DARN: 4, DARN_PLUS: 6}
const FROM := {MEND: [2, 3], MEND_PLUS: [2, 3], DARN: [1, 2, 3], DARN_PLUS: [1, 2, 3]}
const CATALOG := {MEND: "starter", MEND_PLUS: "starter", DARN: "pool", DARN_PLUS: "pool"}

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
