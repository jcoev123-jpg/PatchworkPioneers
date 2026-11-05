extends SceneTree
## Deterministic headless coverage for the three Stitched hero-prop midnight
## waypoints appended to the hero-gated wallet Event catalog
## (res://data/events/v3_hero_choice_events.json): the Sable Grain Clock, the
## Needlebow Orrery and the Staircase Carillon.
##
## EXPECTED, FUNDED_FINAL, ANCHORS and SEEDS are independent authored copies.
## They never read the production catalog or the selector back as their oracle.
## Lookups are by authored event/choice ID only: no catalog total, no global
## ordered ID list and no fixed pool position is asserted, so peer batches can
## append to the same catalog without clashing.
##
## The test drives the real RunV3HeroEventOffers admission and seeded survivor
## selection plus real RunEventChoice wallet preview/settlement visits.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"
const HERO_PARTY := ["scarecrow", "yarn_ranger", "button_golem", "warden"]
const ABSENT_PARTY := ["warden", "seamstress", "tinker", "lantern_monk"]
const FUNDED_GOLD := 40
const FUNDED_SCRAPS := 4

const EXPECTED := {
	"v3_scarecrow_sable_grain_clock": {
		"title": "The Sable Grain Clock",
		"description": "A stuffed black crow rocks on a towering burlap grain-clock while a huge pitchfork serves as its rusted hand; pale straw falls through stitched hourglass panes.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["guide_crow_clockwork", "sell_sable_bell_strap"],
		"choices": [
			{"id": "guide_crow_clockwork", "text": "Guide the crow to two loose bundles of clock straw (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "sell_sable_bell_strap", "text": "Trade one scrap of worn bell strap for 21 gold", "gold": 21, "scraps": -1},
			{"id": "leave", "text": "Let the crooked grain-clock mark another hour", "gold": 0, "scraps": 0},
		],
	},
	"v3_yarn_ranger_needlebow_orrery": {
		"title": "The Needlebow Orrery",
		"description": "Two giant knitting-needle arms turn a brass moon-model above a velvet field; teal wool bolas have caught a tiny glowing button-star between its rings.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["reel_orrery_moons", "buy_moon_wool"],
		"choices": [
			{"id": "reel_orrery_moons", "text": "Reel in the fallen brass moon for 15 gold", "gold": 15, "scraps": 0},
			{"id": "buy_moon_wool", "text": "Pay 14 gold for two coils of moon-wool (+2 scraps)", "gold": -14, "scraps": 2},
			{"id": "leave", "text": "Leave the button-star turning in its rings", "gold": 0, "scraps": 0},
		],
	},
	"v3_button_golem_staircase_carillon": {
		"title": "The Staircase Carillon",
		"description": "Four enormous brass-button chimes hang over a broken stairwell; a round doll keeper asks for the Golem's heavy fists to lift the fallen velvet crank.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["raise_copper_carillon", "gather_fallen_shanks"],
		"choices": [
			{"id": "raise_copper_carillon", "text": "Use two scrap bundles to lift the crank (earn 28 gold)", "gold": 28, "scraps": -2},
			{"id": "gather_fallen_shanks", "text": "Gather one bundle of dropped button shanks (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave", "text": "Let the silent brass buttons hang over the stairs", "gold": 0, "scraps": 0},
		],
	},
}

## Independent funded {gold: 40, scraps: 4} settlement table: the exact final
## balance each authored choice must reach from a fresh unclaimed visit.
const FUNDED_FINAL := {
	"v3_scarecrow_sable_grain_clock": {
		"guide_crow_clockwork": {"gold": 40, "scraps": 6},
		"sell_sable_bell_strap": {"gold": 61, "scraps": 3},
		"leave": {"gold": 40, "scraps": 4},
	},
	"v3_yarn_ranger_needlebow_orrery": {
		"reel_orrery_moons": {"gold": 55, "scraps": 4},
		"buy_moon_wool": {"gold": 26, "scraps": 6},
		"leave": {"gold": 40, "scraps": 4},
	},
	"v3_button_golem_staircase_carillon": {
		"raise_copper_carillon": {"gold": 68, "scraps": 2},
		"gather_fallen_shanks": {"gold": 40, "scraps": 5},
		"leave": {"gold": 40, "scraps": 4},
	},
}

## Independent per-ID seeds for the forced single-eligible selection replays.
const SEEDS := {
	"v3_scarecrow_sable_grain_clock": 1190001,
	"v3_yarn_ranger_needlebow_orrery": 1190002,
	"v3_button_golem_staircase_carillon": 1190003,
}

## Earlier hero-gated anchors this additive batch must leave unchanged: their
## original titles, descriptions, required heroes and signed wallet outcomes.
const ANCHORS := {
	"v3_scarecrow_crow_roost": {
		"title": "The Crow's Threshing",
		"description": "A black crow perches on a burlap-headed straw doll beside an overgrown granary.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["gather_loose_straw", "sell_crow_feathers"],
		"choices": [
			{"id": "gather_loose_straw", "text": "Gather loose straw ties (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "sell_crow_feathers", "text": "Trade a bundle of crow feathers (spend 1 scrap; gain 19 gold)", "gold": 19, "scraps": -1},
			{"id": "leave", "text": "Leave the roost untouched", "gold": 0, "scraps": 0},
		],
	},
	"v3_yarn_ranger_knit_ford": {
		"title": "The Knitted Ford",
		"description": "A narrow crossing is webbed with wool bolas and two bent knitting-needle posts.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["retrieve_bolas", "purchase_wool"],
		"choices": [
			{"id": "retrieve_bolas", "text": "Retrieve a spool tangled in the ford (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "purchase_wool", "text": "Buy fresh coloured wool (spend 14 gold; gain 2 scraps)", "gold": -14, "scraps": 2},
			{"id": "leave", "text": "Cross without disturbing the knitting", "gold": 0, "scraps": 0},
		],
	},
	"v3_button_golem_button_press": {
		"title": "The Giant Button Press",
		"description": "A rattling bronze press stamps brass buttons as a towering button-bodied golem waits.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["stamp_brass", "collect_shanks"],
		"choices": [
			{"id": "stamp_brass", "text": "Feed the press two scrap bundles (spend 2 scraps; gain 31 gold)", "gold": 31, "scraps": -2},
			{"id": "collect_shanks", "text": "Collect fallen button shanks (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave", "text": "Leave the button press", "gold": 0, "scraps": 0},
		],
	},
}

var failures: Array[String] = []
var checks := 0
var source_document: Dictionary = {}
var source_snapshot: Dictionary = {}
var source_by_id: Dictionary = {}
var source_counts: Dictionary = {}


func _initialize() -> void:
	_load_source()
	if source_document.is_empty():
		_report()
		return
	_test_source_records()
	_test_anchor_records()
	_test_roster_offers()
	_test_absent_roster_refusal()
	_test_lost_hero_refusal()
	_test_forced_seeded_selection()
	_test_funded_receipts()
	_test_insufficient_funds()
	_test_preview_detachment()
	_check(source_document == source_snapshot, "the event catalog is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_hero_prop_sidepaths_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_source() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "v3_hero_choice_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK, "v3_hero_choice_events.json parses through JSON")
	if parsed != OK:
		return
	_check(parser.data is Dictionary, "the hero-choice catalog is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the hero-choice catalog carries an events array")
	if not events is Array:
		source_document = {}
		return
	for record in events:
		if not record is Dictionary:
			continue
		var event_id: Variant = (record as Dictionary).get("id")
		if not event_id is String:
			continue
		source_counts[event_id] = int(source_counts.get(event_id, 0)) + 1
		if not source_by_id.has(event_id):
			source_by_id[event_id] = record
	source_snapshot = source_document.duplicate(true)


## Each new record exists exactly once with its verbatim story, exact hero
## metadata, exactly three uniquely identified choices, one free Leave and the
## exact signed wallet deltas.
func _test_source_records() -> void:
	for event_id: String in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		_check(int(source_counts.get(event_id, 0)) == 1,
			"exactly one sourced record for " + event_id)
		if not source_by_id.has(event_id):
			continue
		_check_record_contract(source_by_id[event_id], event_id, contract, "source")
		var free_def := _free_choice(contract, event_id)
		_check(not free_def.is_empty(), "each sourced event keeps one free Leave: " + event_id)
		var service := RunEventChoice.new(source_by_id[event_id])
		_check(service.is_valid() and not service.is_claimed(),
			"a fresh sourced selector validates: " + event_id)
		_check(RunV3HeroEventOffers.HERO_IDS.has(contract["required_hero"]),
			"the required hero is a canonical roster hero: " + event_id)


## The named earlier anchors keep exactly one record each with their original
## titles, descriptions and signed wallet outcomes.
func _test_anchor_records() -> void:
	for anchor_id: String in ANCHORS:
		var contract: Dictionary = ANCHORS[anchor_id]
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"exactly one sourced record for the anchor " + anchor_id)
		if not source_by_id.has(anchor_id):
			continue
		_check_record_contract(source_by_id[anchor_id], anchor_id, contract, "anchor")


## The four-hero Stitched roster offers and admits each new event exactly once
## with its verbatim authored record, and previews it without spending a claim.
func _test_roster_offers() -> void:
	var party: Array = HERO_PARTY.duplicate()
	var party_snapshot: Array = party.duplicate()
	var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
	var wallet_snapshot: Dictionary = wallet.duplicate(true)
	var service := RunV3HeroEventOffers.new(party)
	_check(service.is_valid(), "the four-hero Stitched roster is admitted")
	if not service.is_valid():
		return
	var offers := service.get_offers()
	_check(not offers.is_empty(), "the four-hero Stitched roster offers events")
	for offer: Dictionary in offers:
		_check(HERO_PARTY.has(offer.get("required_hero")),
			"every offer belongs to the roster by required_hero: " + str(offer.get("id")))
	for event_id: String in EXPECTED:
		var matches := _matches(offers, event_id)
		_check(matches.size() == 1, "exactly one offer for " + event_id)
		if matches.size() == 1:
			_check(matches[0] == source_by_id[event_id],
				"the offer copies the authored record: " + event_id)
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"the roster admits a fresh unclaimed visit for " + event_id)
		if visit == null:
			continue
		_check(visit.get_event() == source_by_id[event_id],
			"the admitted visit keeps the authored record: " + event_id)
		var preview := visit.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"the admitted visit previews the funded wallet: " + event_id)
		_check(visit.is_valid() and not visit.is_claimed(),
			"an admission preview claims nothing: " + event_id)
		var legacy_visit := service.enter(event_id)
		_check(legacy_visit != null and legacy_visit.is_valid(),
			"the generic enter path still admits " + event_id)
	_check(party == party_snapshot, "the roster array is never mutated")
	_check(wallet == wallet_snapshot, "the funded preview wallet is never mutated")


## A four-hero roster without the three prop heroes can neither offer, enter nor
## select any of the new events.
func _test_absent_roster_refusal() -> void:
	var party: Array = ABSENT_PARTY.duplicate()
	var party_snapshot: Array = party.duplicate()
	var service := RunV3HeroEventOffers.new(party)
	_check(service.is_valid(), "the alternate four-hero roster is admitted")
	if not service.is_valid():
		return
	var offers := service.get_offers()
	_check(not offers.is_empty(), "the alternate roster offers its own events")
	for event_id: String in EXPECTED:
		_check(_matches(offers, event_id).is_empty(),
			"the absent-hero roster never offers " + event_id)
		_check(service.enter_stitched_survivor(event_id, []) == null,
			"the absent-hero roster refuses guarded entry to " + event_id)
		_check(service.enter(event_id) == null,
			"the absent-hero roster refuses generic entry to " + event_id)
	var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
	for seed_value in range(1190100, 1190110):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var result := service.select_stitched_survivor_event_with_preview(rng, [], null, wallet)
		_check(result.get("ok") == true, "the alternate roster still selects an event")
		var selected_id: Variant = result.get("event", {}).get("id")
		_check(not EXPECTED.has(selected_id),
			"the alternate roster never selects a prop event: " + str(selected_id))
	# A roster missing exactly one prop hero refuses only that hero's event.
	var per_hero_missing := {
		"v3_scarecrow_sable_grain_clock": ["yarn_ranger", "button_golem", "warden", "seamstress"],
		"v3_yarn_ranger_needlebow_orrery": ["scarecrow", "button_golem", "warden", "tinker"],
		"v3_button_golem_staircase_carillon": ["scarecrow", "yarn_ranger", "warden", "lantern_monk"],
	}
	for event_id: String in per_hero_missing:
		var missing_service := RunV3HeroEventOffers.new(per_hero_missing[event_id])
		_check(missing_service.is_valid(),
			"a roster missing only the event hero is still valid: " + event_id)
		_check(_matches(missing_service.get_offers(), event_id).is_empty(),
			"the missing required hero keeps the event unoffered: " + event_id)
		_check(missing_service.enter_stitched_survivor(event_id, []) == null,
			"the missing required hero keeps the event unenterable: " + event_id)
	_check(party == party_snapshot, "the alternate roster array is never mutated")


## Marking each new event's required hero LOST refuses guarded entry and the
## seeded survivor selector, without consuming an RNG draw.
func _test_lost_hero_refusal() -> void:
	var service := RunV3HeroEventOffers.new(HERO_PARTY.duplicate())
	_check(service.is_valid(), "the Stitched roster is valid for LOST refusal checks")
	if not service.is_valid():
		return
	var eligible_ids: Array[String] = []
	for offer: Dictionary in service.get_offers():
		eligible_ids.append(offer["id"])
	var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
	for event_id: String in EXPECTED:
		var required_hero: String = EXPECTED[event_id]["required_hero"]
		_check(service.enter_stitched_survivor(event_id, [required_hero]) == null,
			"a LOST required hero refuses guarded entry to " + event_id)
		var excluded: Array[String] = []
		for other_id: String in eligible_ids:
			if other_id != event_id:
				excluded.append(other_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = SEEDS[event_id]
		var rng_state: int = rng.state
		var result := service.select_stitched_survivor_event_with_preview(
			rng, [required_hero], excluded, wallet)
		_check(result == {"ok": false, "event": {}, "preview": {}},
			"a LOST required hero refuses survivor selection for " + event_id)
		_check(rng.state == rng_state,
			"the LOST refusal consumes no RNG draw for " + event_id)


## With all other currently eligible IDs excluded, the seeded real selector must
## choose each new event, return its authentic record and preview, consume
## exactly one draw and leave the catalog and roster untouched.
func _test_forced_seeded_selection() -> void:
	var party: Array = HERO_PARTY.duplicate()
	var party_snapshot: Array = party.duplicate()
	var service := RunV3HeroEventOffers.new(party)
	_check(service.is_valid(), "the Stitched roster is valid for forced selection")
	if not service.is_valid():
		return
	var eligible_ids: Array[String] = []
	for offer: Dictionary in service.get_offers():
		eligible_ids.append(offer["id"])
	_check(eligible_ids.size() > EXPECTED.size(),
		"the eligible pool holds more than this batch, so exclusions are meaningful")
	var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
	var wallet_snapshot: Dictionary = wallet.duplicate(true)
	for event_id: String in EXPECTED:
		var excluded: Array[String] = []
		for other_id: String in eligible_ids:
			if other_id != event_id:
				excluded.append(other_id)
		var remaining: Array[String] = eligible_ids.duplicate()
		for excluded_id: String in excluded:
			remaining.erase(excluded_id)
		_check(remaining == [event_id],
			"only " + event_id + " stays eligible among the offered IDs")
		var seed_value: int = SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var result := service.select_stitched_survivor_event_with_preview(
			rng, [], excluded, wallet)
		_check(result.get("ok") == true, "forced survivor selection succeeds: " + event_id)
		var selected: Dictionary = result.get("event", {})
		_check(selected.get("id") == event_id,
			"forced survivor selection returns " + event_id)
		_check(selected == source_by_id[event_id],
			"the forced survivor selection is the authored record: " + event_id)
		_check(rng.state == oracle.state,
			"forced survivor selection consumes exactly one draw: " + event_id)
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null, "forced survivor selection opens a real visit: " + event_id)
		if visit != null:
			var expected_preview := visit.preview_wallet_choices(wallet)
			_check(result.get("preview") == expected_preview,
				"the forced survivor preview matches a fresh visit: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := service.select_stitched_survivor_event_with_preview(
			replay_rng, [], excluded, wallet)
		_check(replay == result and replay_rng.state == rng.state,
			"the forced survivor selection replays exactly: " + event_id)
		# The generic actionable selector must reach the same forced event.
		var action_rng := RandomNumberGenerator.new()
		action_rng.seed = seed_value
		var action_oracle := RandomNumberGenerator.new()
		action_oracle.seed = seed_value
		action_oracle.randi_range(0, 0)
		var actionable := service.select_actionable_event_with_preview(
			action_rng, excluded, wallet)
		_check(actionable.get("ok") == true
			and actionable.get("event", {}).get("id") == event_id
			and actionable.get("event") == source_by_id[event_id],
			"the forced actionable selector returns " + event_id)
		_check(action_rng.state == action_oracle.state,
			"the forced actionable selection consumes exactly one draw: " + event_id)
	_check(party == party_snapshot, "seeded selection never mutates the roster")
	_check(wallet == wallet_snapshot, "seeded selection never mutates the wallet")


## Funded receipt matrix: fresh real visits settle all nine authored choices to
## the independent final balances, exactly once, with detached inputs.
func _test_funded_receipts() -> void:
	var service := RunV3HeroEventOffers.new(HERO_PARTY.duplicate())
	_check(service.is_valid(), "the Stitched roster is valid for funded receipts")
	if not service.is_valid():
		return
	var settlements := 0
	for event_id: String in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var final_table: Dictionary = FUNDED_FINAL[event_id]
		_check(final_table.size() == 3,
			"the independent funded table covers three choices: " + event_id)
		var record: Dictionary = source_by_id[event_id]
		var record_snapshot: Dictionary = record.duplicate(true)
		for choice_def: Dictionary in contract["choices"]:
			var choice_id: String = choice_def["id"]
			var expected_gold: int = FUNDED_GOLD + int(choice_def["gold"])
			var expected_scraps: int = FUNDED_SCRAPS + int(choice_def["scraps"])
			var final: Dictionary = final_table[choice_id]
			_check(final == {"gold": expected_gold, "scraps": expected_scraps},
				"the funded table agrees with the authored deltas: "
					+ event_id + " / " + choice_id)
			_check(final["gold"] >= 0 and final["scraps"] >= 0,
				"a funded balance never goes negative: " + event_id + " / " + choice_id)
			var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
			var wallet_snapshot: Dictionary = wallet.duplicate(true)
			var visit := service.enter_stitched_survivor(event_id, [])
			_check(visit != null and visit.is_valid() and not visit.is_claimed(),
				"a fresh funded visit opens: " + event_id + " / " + choice_id)
			if visit == null:
				continue
			var preview := visit.preview_wallet_choices(wallet)
			var rows := _preview_map(preview)
			var row: Dictionary = rows.get(choice_id, {})
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"the funded preview succeeds: " + event_id + " / " + choice_id)
			_check(row.get("gold_delta") == int(choice_def["gold"])
				and row.get("scraps_delta") == int(choice_def["scraps"]),
				"the funded preview reports authored deltas: "
					+ event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == final,
				"the funded preview forecasts the exact balance: "
					+ event_id + " / " + choice_id)
			_check(visit.is_valid() and not visit.is_claimed()
				and wallet == wallet_snapshot and record == record_snapshot,
				"the funded preview claims and spends nothing: "
					+ event_id + " / " + choice_id)
			var receipt := visit.choose_with_wallet(choice_id, wallet)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": final,
			}, "the claim settles the independent funded balance: "
				+ event_id + " / " + choice_id)
			settlements += 1
			_check(visit.is_claimed() and not visit.is_valid(),
				"the funded claim latches the one visit: "
					+ event_id + " / " + choice_id)
			_check(wallet == wallet_snapshot and record == record_snapshot,
				"the funded claim leaves its inputs untouched: "
					+ event_id + " / " + choice_id)
			var replay := visit.choose_with_wallet(choice_id, final)
			_check(replay == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": final,
			}, "a settled choice cannot be claimed twice: "
				+ event_id + " / " + choice_id)
			_check(visit.preview_wallet_choices(wallet).get("ok") == false,
				"a claimed visit offers no further preview: "
					+ event_id + " / " + choice_id)
			var fresh := service.enter_stitched_survivor(event_id, [])
			_check(fresh != null and fresh.is_valid() and not fresh.is_claimed(),
				"a new visit reopens the event after settlement: "
					+ event_id + " / " + choice_id)
	_check(settlements == 9, "all nine authored funded choices settle once")


## One-short and empty purses refuse the debit before any spend or claim, while
## free gains and Leave still settle, and the same visit cannot claim twice.
func _test_insufficient_funds() -> void:
	var service := RunV3HeroEventOffers.new(HERO_PARTY.duplicate())
	_check(service.is_valid(), "the Stitched roster is valid for refusal checks")
	if not service.is_valid():
		return
	var cases := [
		{"event": "v3_yarn_ranger_needlebow_orrery", "choice": "buy_moon_wool",
			"wallet": {"gold": 13, "scraps": 4}, "label": "one gold short"},
		{"event": "v3_button_golem_staircase_carillon", "choice": "raise_copper_carillon",
			"wallet": {"gold": 40, "scraps": 1}, "label": "one scrap short"},
		{"event": "v3_scarecrow_sable_grain_clock", "choice": "sell_sable_bell_strap",
			"wallet": {"gold": 40, "scraps": 0}, "label": "no scraps"},
	]
	for case: Dictionary in cases:
		var event_id: String = case["event"]
		var choice_id: String = case["choice"]
		var wallet: Dictionary = (case["wallet"] as Dictionary).duplicate(true)
		var wallet_snapshot: Dictionary = wallet.duplicate(true)
		var label: String = case["label"]
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"a fresh visit opens for the " + label + " case")
		if visit == null:
			continue
		var rows := _preview_map(visit.preview_wallet_choices(wallet))
		_check(rows.get(choice_id, {}).get("affordable") == false,
			"the " + label + " choice previews as unaffordable")
		_check(rows.get(choice_id, {}).get("wallet") == wallet_snapshot,
			"the unaffordable preview forecasts the unchanged purse: " + label)
		var refused := visit.choose_with_wallet(choice_id, wallet)
		_check(refused == {
			"ok": false, "event_id": "", "choice_id": "", "wallet": wallet_snapshot,
		}, "the " + label + " choice is refused unchanged")
		_check(visit.is_valid() and not visit.is_claimed()
			and wallet == wallet_snapshot,
			"the " + label + " refusal spends no purse and no claim")
		var leave := visit.choose_with_wallet("leave", wallet)
		_check(leave == {
			"ok": true, "event_id": event_id, "choice_id": "leave",
			"wallet": wallet_snapshot,
		}, "Leave still works on the same " + label + " visit")
		_check(visit.is_claimed() and not visit.is_valid(),
			"the " + label + " Leave latches exactly once")
		var late := visit.choose_with_wallet(choice_id, wallet)
		_check(late.get("ok") == false and late.get("wallet") == wallet_snapshot,
			"the " + label + " claim cannot be replayed")
	# Free/gain choices still settle from an empty purse.
	var free_cases := [
		{"event": "v3_scarecrow_sable_grain_clock", "choice": "guide_crow_clockwork",
			"final": {"gold": 0, "scraps": 2}},
		{"event": "v3_yarn_ranger_needlebow_orrery", "choice": "reel_orrery_moons",
			"final": {"gold": 15, "scraps": 0}},
		{"event": "v3_button_golem_staircase_carillon", "choice": "gather_fallen_shanks",
			"final": {"gold": 0, "scraps": 1}},
	]
	for case: Dictionary in free_cases:
		var event_id: String = case["event"]
		var choice_id: String = case["choice"]
		var final: Dictionary = case["final"]
		var empty := {"gold": 0, "scraps": 0}
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null, "a fresh visit opens for the free gain " + choice_id)
		if visit == null:
			continue
		var receipt := visit.choose_with_wallet(choice_id, empty)
		_check(receipt == {
			"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": final,
		}, "the free gain " + choice_id + " settles from an empty purse")
		_check(empty == {"gold": 0, "scraps": 0},
			"the free gain leaves the caller purse untouched: " + choice_id)
		_check(receipt.get("wallet", {}).get("gold", -1) >= 0
			and receipt.get("wallet", {}).get("scraps", -1) >= 0,
			"the free gain settles a nonnegative balance: " + choice_id)


## Previews are read-only: repeated previews stay identical, mutating a preview
## never reaches the selector or the catalog, and the roster stays unchanged.
func _test_preview_detachment() -> void:
	var party: Array = HERO_PARTY.duplicate()
	var party_snapshot: Array = party.duplicate()
	var service := RunV3HeroEventOffers.new(party)
	_check(service.is_valid(), "the Stitched roster is valid for preview detachment")
	if not service.is_valid():
		return
	var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
	var wallet_snapshot: Dictionary = wallet.duplicate(true)
	for event_id: String in EXPECTED:
		var record: Dictionary = source_by_id[event_id]
		var record_snapshot: Dictionary = record.duplicate(true)
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null, "a fresh visit opens for preview detachment: " + event_id)
		if visit == null:
			continue
		var first := visit.preview_wallet_choices(wallet)
		var again := visit.preview_wallet_choices(wallet)
		_check(first == again, "repeated previews are deterministic: " + event_id)
		var entries: Array = first.get("choices", [])
		_check(entries.size() == 3, "the preview carries every authored choice: " + event_id)
		if not entries.is_empty():
			var entry: Dictionary = entries[0]
			(entry["wallet"] as Dictionary)["gold"] = 9999
			entry["gold_delta"] = 9999
		_check(visit.preview_wallet_choices(wallet) == again,
			"mutating a preview never reaches the selector: " + event_id)
		_check(visit.is_valid() and not visit.is_claimed()
			and visit.get_event() == record_snapshot,
			"preview detachment keeps the visit and snapshot intact: " + event_id)
		_check(record == record_snapshot and wallet == wallet_snapshot,
			"preview detachment leaves the catalog and purse intact: " + event_id)
	_check(party == party_snapshot, "preview flows never mutate the roster")
	_check(source_document == source_snapshot, "preview flows never mutate the source catalog")


## Verbatim presentation, choice shape and signed deltas against the independent
## table. `origin` only labels failure messages.
func _check_record_contract(record: Variant, event_id: String, contract: Dictionary,
		origin: String) -> void:
	_check(record is Dictionary, "the " + origin + " record is an object: " + event_id)
	if not record is Dictionary:
		return
	var authored: Dictionary = record
	_check(authored.size() == 6 and authored.has("id") and authored.has("title")
		and authored.has("description") and authored.has("required_hero")
		and authored.has("hero_choice_ids") and authored.has("choices"),
		"exactly the six authored keys: " + origin + " / " + event_id)
	_check(authored.get("id") == event_id, "authored ID: " + origin + " / " + event_id)
	_check(authored.get("title") == contract["title"],
		"authored title: " + origin + " / " + event_id)
	_check(authored.get("description") == contract["description"],
		"authored description: " + origin + " / " + event_id)
	_check(authored.get("required_hero") == contract["required_hero"],
		"authored required hero: " + origin + " / " + event_id)
	_check(authored.get("hero_choice_ids") == contract["hero_choice_ids"],
		"authored hero_choice_ids: " + origin + " / " + event_id)
	var choices: Variant = authored.get("choices")
	_check(choices is Array, "authored choices array: " + origin + " / " + event_id)
	if not choices is Array:
		return
	_check((choices as Array).size() == 3,
		"exactly three choices: " + origin + " / " + event_id)
	var by_id: Dictionary = {}
	for choice in (choices as Array):
		_check(choice is Dictionary, "every choice is an object: " + origin + " / " + event_id)
		if not choice is Dictionary:
			continue
		var entry: Dictionary = choice
		var choice_id: Variant = entry.get("id")
		_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
			"every choice has a nonblank string ID: " + origin + " / " + event_id)
		if not choice_id is String:
			continue
		_check(not by_id.has(choice_id),
			"choice IDs are distinct: " + origin + " / " + event_id + " / " + str(choice_id))
		by_id[choice_id] = entry
	_check(by_id.size() == 3, "three distinct choice IDs: " + origin + " / " + event_id)
	for choice_def: Dictionary in contract["choices"]:
		var choice_id: String = choice_def["id"]
		_check(by_id.has(choice_id),
			"authored choice present: " + origin + " / " + event_id + " / " + choice_id)
		if not by_id.has(choice_id):
			continue
		var entry: Dictionary = by_id[choice_id]
		_check(entry.size() == 3 and entry.has("id") and entry.has("text")
			and entry.has("outcome"),
			"exactly id/text/outcome: " + origin + " / " + event_id + " / " + choice_id)
		_check(entry.get("text") == choice_def["text"],
			"authored choice text: " + origin + " / " + event_id + " / " + choice_id)
		var outcome: Variant = entry.get("outcome")
		_check(outcome is Dictionary,
			"choice outcome is an object: " + origin + " / " + event_id + " / " + choice_id)
		if not outcome is Dictionary:
			continue
		var wallet_outcome: Dictionary = outcome
		_check(wallet_outcome.size() == 2 and wallet_outcome.has("gold")
			and wallet_outcome.has("scraps"),
			"exactly gold/scraps outcome keys: "
				+ origin + " / " + event_id + " / " + choice_id)
		var gold_amount: Variant = _signed_amount(wallet_outcome.get("gold"))
		var scraps_amount: Variant = _signed_amount(wallet_outcome.get("scraps"))
		_check(gold_amount != null and scraps_amount != null,
			"whole-number outcome amounts: " + origin + " / " + event_id + " / " + choice_id)
		_check(gold_amount == choice_def["gold"] and scraps_amount == choice_def["scraps"],
			"authored signed outcome: " + origin + " / " + event_id + " / " + choice_id)


func _free_choice(contract: Dictionary, event_id: String) -> Dictionary:
	var free_choices: Array = []
	for choice_def: Dictionary in contract["choices"]:
		if int(choice_def["gold"]) == 0 and int(choice_def["scraps"]) == 0:
			free_choices.append(choice_def)
	_check(free_choices.size() == 1,
		"exactly one zero-cost Leave choice is authored: " + event_id)
	return free_choices[0] if free_choices.size() == 1 else {}


## The authored signed amount as an int, or null when the JSON value is not a
## finite whole number.
func _signed_amount(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number and absf(number) <= 9007199254740992.0:
			return int(number)
	return null


func _matches(listing: Array, event_id: String) -> Array:
	var found: Array = []
	for record in listing:
		if record is Dictionary and record.get("id") == event_id:
			found.append(record)
	return found


func _preview_map(preview: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return out
	for entry in entries:
		if entry is Dictionary:
			out[entry["choice_id"]] = entry
	return out
