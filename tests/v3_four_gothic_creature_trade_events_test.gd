extends SceneTree
## Deterministic headless coverage for the four V3-4 gothic creature-and-tool
## roadside wallet trades appended to res://data/events/v3_roadside_events.json:
## the Copper Crab's Shears Cart, the Mourning-Clock Armadillo, the Blacklace
## Puffin Ferry and the Thimbleback Beaver Dam.
##
## EXPECTED, FUNDED_RESULTS and EMPTY_UNPAYABLE are independent copies of the
## authored stories and their signed gold/scraps outcomes; they never read the
## production catalog or the selector back as their oracle. Only per-ID
## membership is asserted: no catalog total, no ordered ID list and no arbitrary
## unfiltered seed pick, so peer batches can land in the same catalog without
## clashing.
##
## Coverage: one sourced record and one fresh default-selector record per new ID
## with verbatim title/description/choice text and exact signed deltas; the named
## earlier roadside anchors stay present and unchanged; funded previews and
## receipts agree from {gold: 60, scraps: 8}; every signed debit is refused at an
## empty purse without consuming the visit; beaver's free salvage and every free
## Leave settle exactly once; an unknown choice claims nothing; caller wallets,
## the sourced document and exclusion lists are never mutated; and every new
## event is forced through the real seeded generic selector with exactly one
## range draw.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 60, "scraps": 8}
const EMPTY := {"gold": 0, "scraps": 0}

## Independent copy of the four authored records and their signed wallet outcomes.
const EXPECTED := {
	"v3_copper_crab_shears_cart": {
		"title": "The Copper Crab's Shears Cart",
		"description": "A stout oxblood crab ragdoll spreads enormous silver shears over a lace-lined cart; mismatched buttons glimmer on its quilted pincers by candlelight.",
		"choices": [
			{"id": "sell_shear_offcuts", "text": "Sell two spools of scissor offcuts (spend 2 scraps; gain 32 gold)", "gold": 32, "scraps": -2},
			{"id": "buy_hem_silk", "text": "Buy the crab's stormproof silk hem (spend 21 gold; gain 4 scraps)", "gold": -21, "scraps": 4},
			{"id": "leave", "text": "Let the crab fold its silver shears", "gold": 0, "scraps": 0},
		],
	},
	"v3_mourning_clock_armadillo": {
		"title": "The Mourning-Clock Armadillo",
		"description": "A squat midnight-teal armadillo curls around an enormous cracked bone-cream clock; four brass-button paws rewind its long thread hour hand.",
		"choices": [
			{"id": "rewind_thread_hand", "text": "Rewind the clock with a spool (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
			{"id": "buy_spring_thread", "text": "Buy a spring-thread winding (spend 17 gold; gain 3 scraps)", "gold": -17, "scraps": 3},
			{"id": "leave", "text": "Let the thread clock tick in the fog", "gold": 0, "scraps": 0},
		],
	},
	"v3_blacklace_puffin_ferry": {
		"title": "The Blacklace Puffin Ferry",
		"description": "A round bone-cream puffin doll in a plum patchwork cape paddles a tiny black-lace ferry with an oversized red knitting needle beneath an amber locklight.",
		"choices": [
			{"id": "mend_needle_oar", "text": "Mend the huge needle-oar (spend 2 scraps; gain 28 gold)", "gold": 28, "scraps": -2},
			{"id": "buy_canal_wool", "text": "Buy canal-warmed wool (spend 12 gold; gain 2 scraps)", "gold": -12, "scraps": 2},
			{"id": "leave", "text": "Watch the puffin ferry slip into the mist", "gold": 0, "scraps": 0},
		],
	},
	"v3_thimbleback_beaver_dam": {
		"title": "The Thimbleback Beaver Dam",
		"description": "A plump moss-cloth beaver ragdoll stacks giant quilted log patches into a little canal dam; a silver thimble caps one tooth and button eyes catch the lantern glow.",
		"choices": [
			{"id": "gather_dam_offcuts", "text": "Gather abandoned dam offcuts (gain 1 scrap)", "gold": 0, "scraps": 1},
			{"id": "reinforce_button_gate", "text": "Reinforce the giant button sluice (spend 3 scraps; gain 42 gold)", "gold": 42, "scraps": -3},
			{"id": "leave", "text": "Leave the beaver to its midnight repairs", "gold": 0, "scraps": 0},
		],
	},
}

## Resulting wallets in authored choice order from {gold: 60, scraps: 8}.
const FUNDED_RESULTS := {
	"v3_copper_crab_shears_cart": [[92, 6], [39, 12], [60, 8]],
	"v3_mourning_clock_armadillo": [[78, 7], [43, 11], [60, 8]],
	"v3_blacklace_puffin_ferry": [[88, 6], [48, 10], [60, 8]],
	"v3_thimbleback_beaver_dam": [[60, 9], [102, 5], [60, 8]],
}

## Unpayable branches from an empty purse: [event_id, choice_id].
const EMPTY_UNPAYABLE := [
	["v3_copper_crab_shears_cart", "sell_shear_offcuts"],
	["v3_copper_crab_shears_cart", "buy_hem_silk"],
	["v3_mourning_clock_armadillo", "rewind_thread_hand"],
	["v3_mourning_clock_armadillo", "buy_spring_thread"],
	["v3_blacklace_puffin_ferry", "mend_needle_oar"],
	["v3_blacklace_puffin_ferry", "buy_canal_wool"],
	["v3_thimbleback_beaver_dam", "reinforce_button_gate"],
]

## Earlier roadside anchors that must stay present and unchanged.
const ANCHORS := {
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"description": "A soaked quilt bridge stretching over a ravine.",
		"choices": [
			{"id": "salvage_hems", "gold": 0, "scraps": 1},
			{"id": "trade_fare", "gold": -12, "scraps": 2},
			{"id": "take_detour", "gold": 0, "scraps": 0},
		],
	},
	"v3_puppet_box_office": {
		"title": "The Puppet Box Office",
		"description": "Rag puppets wait under a patchwork theatre awning.",
		"choices": [
			{"id": "perform", "gold": 9, "scraps": 0},
			{"id": "restring", "gold": 24, "scraps": -2},
			{"id": "applaud", "gold": 0, "scraps": 0},
		],
	},
	"v3_moonkite_hare_crossroads": {
		"title": "The Moonkite Hare",
		"description": "A squat bone-cream hare ragdoll braces an enormous plum-gingham kite against the wind; four brass-button tails tap on the moonlit crossroads.",
		"choices": [
			{"id": "repair_kite_tails", "gold": 29, "scraps": -2},
			{"id": "buy_windproof_seams", "gold": -16, "scraps": 3},
			{"id": "leave", "gold": 0, "scraps": 0},
		],
	},
}

## Independent per-ID seeds for the forced single-eligible selection replay. They
## never pin a selected position: with one eligible ID the outcome is that ID.
const SEEDS := {
	"v3_copper_crab_shears_cart": 95501,
	"v3_mourning_clock_armadillo": 95502,
	"v3_blacklace_puffin_ferry": 95503,
	"v3_thimbleback_beaver_dam": 95504,
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
	_test_default_selector()
	_test_funded_wallet()
	_test_empty_wallet()
	_test_unknown_choice()
	_test_forced_seeded_selection()
	_check(source_document == source_snapshot, "the roadside source is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_four_gothic_creature_trade_events_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_source() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "v3_roadside_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK, "v3_roadside_events.json parses through JSON")
	if parsed != OK:
		return
	_check(parser.data is Dictionary, "the roadside catalog is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the roadside catalog carries an events array")
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


## Each new record exists exactly once in the authored source with its verbatim
## story, exactly three uniquely identified choices, one free Leave and the exact
## signed wallet deltas; the named earlier anchors are untouched.
func _test_source_records() -> void:
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		_check(int(source_counts.get(event_id, 0)) == 1,
			"exactly one sourced record for " + event_id)
		if not source_by_id.has(event_id):
			continue
		_check_record_contract(source_by_id[event_id], event_id, contract, "source")
		var service := RunEventChoice.new(source_by_id[event_id])
		_check(service.is_valid() and not service.is_claimed(),
			"a fresh sourced selector validates: " + event_id)
	for anchor_id in ANCHORS:
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"the named earlier roadside anchor stays in the source once: " + anchor_id)
		if source_by_id.has(anchor_id):
			_check_anchor(source_by_id[anchor_id], anchor_id, ANCHORS[anchor_id])


## A fresh default RunM04EventRotation lists every new record exactly once with
## the authored content and keeps every named earlier anchor eligible.
func _test_default_selector() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped catalogs validate in the default selector")
	if not rotation.is_catalog_valid():
		return
	var listing: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	_check(not listing.is_empty(), "the default selector lists a non-empty generic pool")
	for event_id in EXPECTED:
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "exactly one default generic record for " + event_id)
		_check(ids.count(event_id) == 1, "the generic ID listing carries " + event_id + " exactly once")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record == source_by_id[event_id], "the selector copies the authored record: " + event_id)
		_check_record_contract(record, event_id, EXPECTED[event_id], "default selector")
	for anchor_id in ANCHORS:
		_check(ids.count(anchor_id) == 1, "the named earlier anchor stays eligible: " + anchor_id)
		var anchor_matches := _matches(listing, anchor_id)
		if anchor_matches.size() == 1:
			_check_anchor(anchor_matches[0], anchor_id, ANCHORS[anchor_id])
	# The listing stays detached: mutating it never reaches the selector.
	var snapshot: Array = listing.duplicate(true)
	var first: Dictionary = listing[0]
	first["title"] = "MUTATED"
	first["choices"] = []
	listing.append({"id": "injected", "title": "Injected", "description": "Injected", "choices": []})
	_check(rotation.get_generic_events() == snapshot,
		"mutating a returned listing never reaches the selector")


## Funded previews and receipts agree on all twelve authored deltas; a settled
## choice cannot be replayed; results and inputs stay detached.
func _test_funded_wallet() -> void:
	var funded_snapshot: Dictionary = FUNDED.duplicate(true)
	var settlements := 0
	for event_id in EXPECTED:
		_check(source_by_id.has(event_id), "source record available for funded play: " + event_id)
		if not source_by_id.has(event_id):
			continue
		var record: Dictionary = source_by_id[event_id]
		var record_snapshot: Dictionary = record.duplicate(true)
		var contract: Dictionary = EXPECTED[event_id]
		var results: Array = FUNDED_RESULTS[event_id]
		for index in range((contract["choices"] as Array).size()):
			var definition: Dictionary = contract["choices"][index]
			var choice_id: String = definition["id"]
			var expected_wallet: Dictionary = {"gold": results[index][0], "scraps": results[index][1]}
			var service := RunEventChoice.new(record)
			var row := _preview_row(service.preview_wallet_choices(FUNDED), choice_id)
			_check(row.get("affordable") == true,
				"funded preview is affordable: " + event_id + " / " + choice_id)
			_check(row.get("gold_delta") == definition["gold"]
				and row.get("scraps_delta") == definition["scraps"],
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("wallet") == expected_wallet,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var receipt := service.choose_with_wallet(choice_id, FUNDED)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": expected_wallet,
			}, "the claim applies the authored deltas once: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay := service.choose_with_wallet(choice_id, FUNDED)
			_check(replay == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": FUNDED,
			}, "the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			_check(FUNDED == funded_snapshot and record == record_snapshot,
				"a funded flow never mutates the record or its purse: " + event_id + " / " + choice_id)
	_check(settlements == 12, "every authored choice settles once when funded")


## Every signed debit is unaffordable at an empty purse; the refusal keeps the
## visit open, changes no wallet or record. Beaver's free salvage and every free
## Leave settle exactly once in independent fresh visits.
func _test_empty_wallet() -> void:
	var empty_snapshot: Dictionary = EMPTY.duplicate(true)
	for pair in EMPTY_UNPAYABLE:
		var event_id: String = pair[0]
		var choice_id: String = pair[1]
		_check(source_by_id.has(event_id), "source record available for empty play: " + event_id)
		if not source_by_id.has(event_id):
			continue
		var record: Dictionary = source_by_id[event_id]
		var record_snapshot: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var row := _preview_row(service.preview_wallet_choices(EMPTY), choice_id)
		_check(row.get("affordable") == false,
			"an empty purse cannot afford a debit: " + event_id + " / " + choice_id)
		var denied := service.choose_with_wallet(choice_id, EMPTY)
		_check(denied == {"ok": false, "event_id": "", "choice_id": "", "wallet": EMPTY},
			"an empty purse refuses a debit unchanged: " + event_id + " / " + choice_id)
		_check(not service.is_claimed() and service.is_valid(),
			"an empty-purse refusal keeps the visit open: " + event_id + " / " + choice_id)
		_check(EMPTY == empty_snapshot and record == record_snapshot,
			"an empty-purse refusal mutates no purse and no record: " + event_id + " / " + choice_id)
	# Beaver's free salvage genuinely earns one scrap from an empty purse.
	var beaver: Dictionary = source_by_id["v3_thimbleback_beaver_dam"]
	var free_service := RunEventChoice.new(beaver)
	var free_row := _preview_row(free_service.preview_wallet_choices(EMPTY), "gather_dam_offcuts")
	_check(free_row.get("affordable") == true,
		"the free beaver salvage is affordable from an empty purse")
	_check(free_row.get("wallet") == {"gold": 0, "scraps": 1},
		"the free beaver salvage previews exactly one scrap")
	var free_receipt := free_service.choose_with_wallet("gather_dam_offcuts", EMPTY)
	_check(free_receipt == {
		"ok": true, "event_id": "v3_thimbleback_beaver_dam",
		"choice_id": "gather_dam_offcuts", "wallet": {"gold": 0, "scraps": 1},
	}, "the free beaver salvage earns exactly one scrap")
	_check(not free_service.is_valid()
		and free_service.choose_with_wallet("gather_dam_offcuts", EMPTY).get("ok") == false,
		"the free beaver salvage cannot be replayed")
	_check(EMPTY == empty_snapshot, "the free beaver salvage never mutates the empty purse")
	# Each event's Leave succeeds with an unchanged wallet in a fresh visit.
	for event_id in EXPECTED:
		var leave_id := _leave_id(EXPECTED[event_id])
		_check(leave_id != "", "a free Leave is authored: " + event_id)
		if leave_id == "":
			continue
		var leave_service := RunEventChoice.new(source_by_id[event_id])
		var leave := leave_service.choose_with_wallet(leave_id, EMPTY)
		_check(leave == {
			"ok": true, "event_id": event_id, "choice_id": leave_id, "wallet": EMPTY,
		}, "an empty purse still settles its free Leave: " + event_id)
		_check(not leave_service.is_valid()
			and leave_service.choose_with_wallet(leave_id, EMPTY).get("ok") == false,
			"the empty-purse Leave cannot be replayed: " + event_id)
	_check(EMPTY == empty_snapshot, "the empty purse is never mutated")


## An unknown choice ID rejects without claiming, after which the same visit
## still settles its free Leave.
func _test_unknown_choice() -> void:
	var record: Dictionary = source_by_id["v3_copper_crab_shears_cart"]
	var service := RunEventChoice.new(record)
	var denied := service.choose_with_wallet("no_such_choice", EMPTY)
	_check(denied.get("ok") == false and denied.get("wallet") == EMPTY,
		"an unknown choice rejects with an unchanged wallet")
	_check(not service.is_claimed() and service.is_valid(),
		"an unknown choice claims nothing")
	var leave := service.choose_with_wallet("leave", EMPTY)
	_check(leave.get("ok") == true and leave.get("wallet") == EMPTY,
		"the visit still settles its Leave after an unknown choice")
	_check(not service.is_valid(),
		"the Leave after an unknown choice closes the visit")


## Every new event is selectable through the real default selector by a seeded
## caller that excludes the other currently eligible IDs, with exactly the
## documented one-draw contract and a detached authored record.
func _test_forced_seeded_selection() -> void:
	var rotation := RunM04EventRotation.new()
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() > EXPECTED.size(),
		"the eligible pool holds more than this batch, so exclusions are meaningful")
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1, "the eligible pool carries " + event_id + " once")
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var excluded_snapshot: Array = excluded.duplicate()
		_check(not excluded.has(event_id),
			"only " + event_id + " stays eligible")
		var seed_value: int = SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "forced selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "forced selection returns " + event_id)
		_check_record_contract(selected, event_id, EXPECTED[event_id], "seeded selection")
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one range draw: " + event_id)
		_check(excluded == excluded_snapshot,
			"the exclusion list is never mutated: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected,
			"identical seed and exclusions replay " + event_id)
		var selected_snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == selected_snapshot
			and detached.get("event") == source_by_id[event_id],
			"the selected " + event_id + " is a detached authored copy")


## Verbatim presentation, choice shape and signed deltas against the independent
## table. `origin` only labels failure messages.
func _check_record_contract(record: Variant, event_id: String, contract: Dictionary,
		origin: String) -> void:
	_check(record is Dictionary, "the " + origin + " record is an object: " + event_id)
	if not record is Dictionary:
		return
	var authored: Dictionary = record
	_check(authored.size() == 4 and authored.has("id") and authored.has("title")
		and authored.has("description") and authored.has("choices"),
		"exactly id/title/description/choices: " + origin + " / " + event_id)
	_check(authored.get("id") == event_id, "authored ID: " + origin + " / " + event_id)
	_check(authored.get("title") == contract["title"], "authored title: " + origin + " / " + event_id)
	_check(authored.get("description") == contract["description"],
		"authored description: " + origin + " / " + event_id)
	var choices: Variant = authored.get("choices")
	_check(choices is Array, "authored choices array: " + origin + " / " + event_id)
	if not choices is Array:
		return
	_check((choices as Array).size() == 3, "exactly three choices: " + origin + " / " + event_id)
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
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		var choice_id: String = definition["id"]
		_check(by_id.has(choice_id),
			"authored choice present: " + origin + " / " + event_id + " / " + choice_id)
		if not by_id.has(choice_id):
			continue
		var entry: Dictionary = by_id[choice_id]
		_check(entry.size() == 3 and entry.has("id") and entry.has("text")
			and entry.has("outcome"),
			"exactly id/text/outcome: " + origin + " / " + event_id + " / " + choice_id)
		_check(entry.get("text") == definition["text"],
			"authored choice text: " + origin + " / " + event_id + " / " + choice_id)
		var outcome: Variant = entry.get("outcome")
		_check(outcome is Dictionary,
			"choice outcome is an object: " + origin + " / " + event_id + " / " + choice_id)
		if not outcome is Dictionary:
			continue
		var wallet_outcome: Dictionary = outcome
		_check(wallet_outcome.size() == 2 and wallet_outcome.has("gold")
			and wallet_outcome.has("scraps"),
			"exactly gold/scraps outcome keys: " + origin + " / " + event_id + " / " + choice_id)
		# JSON may deliver whole numbers as floats; the authored contract is a
		# whole signed amount either way.
		var gold_amount: Variant = _signed_amount(wallet_outcome.get("gold"))
		var scraps_amount: Variant = _signed_amount(wallet_outcome.get("scraps"))
		_check(gold_amount != null and scraps_amount != null,
			"whole-number outcome amounts: " + origin + " / " + event_id + " / " + choice_id)
		_check(gold_amount == definition["gold"] and scraps_amount == definition["scraps"],
			"authored signed outcome: " + origin + " / " + event_id + " / " + choice_id)


## The named earlier anchors keep their verbatim presentation and outcomes.
func _check_anchor(record: Variant, anchor_id: String, contract: Dictionary) -> void:
	if not record is Dictionary:
		_check(false, "the earlier anchor is an object: " + anchor_id)
		return
	var authored: Dictionary = record
	_check(authored.get("id") == anchor_id, "the earlier anchor keeps its ID: " + anchor_id)
	_check(authored.get("title") == contract["title"],
		"the earlier anchor keeps its title: " + anchor_id)
	_check(authored.get("description") == contract["description"],
		"the earlier anchor keeps its description: " + anchor_id)
	var choices: Variant = authored.get("choices")
	_check(choices is Array and (choices as Array).size() == (contract["choices"] as Array).size(),
		"the earlier anchor keeps its choice count: " + anchor_id)
	if not choices is Array:
		return
	for index in range((contract["choices"] as Array).size()):
		var definition: Dictionary = contract["choices"][index]
		var entry: Variant = (choices as Array)[index]
		if not entry is Dictionary:
			_check(false, "the earlier anchor choice is an object: " + anchor_id)
			continue
		var choice_dict: Dictionary = entry
		_check(choice_dict.get("id") == definition["id"],
			"the earlier anchor choice ID is unchanged: " + anchor_id + " / " + definition["id"])
		var outcome: Variant = choice_dict.get("outcome")
		if not outcome is Dictionary:
			_check(false, "the earlier anchor outcome is an object: " + anchor_id)
			continue
		_check(_signed_amount((outcome as Dictionary).get("gold")) == definition["gold"]
			and _signed_amount((outcome as Dictionary).get("scraps")) == definition["scraps"],
			"the earlier anchor outcome is unchanged: " + anchor_id + " / " + definition["id"])


func _leave_id(contract: Dictionary) -> String:
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		if int(definition["gold"]) == 0 and int(definition["scraps"]) == 0:
			return definition["id"]
	return ""


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


func _preview_row(preview: Dictionary, choice_id: String) -> Dictionary:
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return {}
	for entry in entries:
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}
