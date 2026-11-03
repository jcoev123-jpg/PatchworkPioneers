extends SceneTree
## Deterministic headless coverage for the four V3-4 gothic mechanical-oddity
## roadside wallet Events appended to res://data/events/v3_roadside_events.json:
## the Mourning Gramophone, the Candlewick Airship, the Iron-Glove Well and the
## Mothglass Orrery.
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
## earlier roadside anchors (Raincoat Bridge, Puppet Box Office, Sootglass
## Letterpress and Ashen Bell Foundry) stay present and unchanged; funded
## previews and receipts agree from {gold: 60, scraps: 8}; every signed debit is
## refused at an empty purse without consuming the visit; the Airship's free
## salvage and every free Leave settle exactly once; an unknown choice claims
## nothing; caller wallets, the sourced document and exclusion lists are never
## mutated; and every new event is forced through the real seeded generic
## selector with exactly one range draw.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 60, "scraps": 8}
const EMPTY := {"gold": 0, "scraps": 0}

## Independent copy of the four authored records and their signed wallet outcomes.
const EXPECTED := {
	"v3_mourning_gramophone": {
		"title": "The Mourning Gramophone",
		"description": "A round oxblood gramophone doll cranks a brass horn broader than its body, coughing black ribbon notes onto a candlelit cobblestone lane.",
		"choices": [
			{"id": "mend_silent_horn", "text": "Mend the silent horn (spend 2 scraps; gain 31 gold)", "gold": 31, "scraps": -2},
			{"id": "buy_whisper_record", "text": "Buy a whisper record (spend 17 gold; gain 3 scraps)", "gold": -17, "scraps": 3},
			{"id": "leave", "text": "Let the last black ribbon note fade", "gold": 0, "scraps": 0},
		],
	},
	"v3_candlewick_airship": {
		"title": "The Candlewick Airship",
		"description": "A squat plum-cloth balloon captain steadies an enormous patched airship tethered by glowing candlewicks above a fog-bound roadside mast.",
		"choices": [
			{"id": "collect_mooring_knots", "text": "Gather loose mooring knots (gain 2 scraps)", "gold": 0, "scraps": 2},
			{"id": "buy_waxed_balloontwine", "text": "Buy waxed balloon twine (spend 21 gold; gain 4 scraps)", "gold": -21, "scraps": 4},
			{"id": "leave", "text": "Let the candlewick airship drift in the fog", "gold": 0, "scraps": 0},
		],
	},
	"v3_iron_glove_well": {
		"title": "The Iron-Glove Well",
		"description": "An enormous black stitched glove rises from a moss-dark well, each silver-thimbled finger holding a tiny amber lamp.",
		"choices": [
			{"id": "stitch_glove_cuff", "text": "Re-sew the heavy glove cuff (spend 1 scrap; gain 20 gold)", "gold": 20, "scraps": -1},
			{"id": "buy_thimble_lamps", "text": "Buy two thimble lamps (spend 13 gold; gain 2 scraps)", "gold": -13, "scraps": 2},
			{"id": "leave", "text": "Leave the giant glove reaching into darkness", "gold": 0, "scraps": 0},
		],
	},
	"v3_mothglass_orrery": {
		"title": "The Mothglass Orrery",
		"description": "A button-eyed midnight-blue astrologer turns a towering brass orrery whose quilted moth-wing moons glow in a narrow candlelit alcove.",
		"choices": [
			{"id": "oil_silver_orbits", "text": "Oil the silver orbit wheels (spend 2 scraps; gain 33 gold)", "gold": 33, "scraps": -2},
			{"id": "buy_moonwheel_thread", "text": "Buy moonwheel thread (spend 18 gold; gain 3 scraps)", "gold": -18, "scraps": 3},
			{"id": "leave", "text": "Let the moth-wing moons turn alone", "gold": 0, "scraps": 0},
		],
	},
}

## Resulting wallets in authored choice order from {gold: 60, scraps: 8}.
const FUNDED_RESULTS := {
	"v3_mourning_gramophone": [[91, 6], [43, 11], [60, 8]],
	"v3_candlewick_airship": [[60, 10], [39, 12], [60, 8]],
	"v3_iron_glove_well": [[80, 7], [47, 10], [60, 8]],
	"v3_mothglass_orrery": [[93, 6], [42, 11], [60, 8]],
}

## Unpayable branches from an empty purse: [event_id, choice_id].
const EMPTY_UNPAYABLE := [
	["v3_mourning_gramophone", "mend_silent_horn"],
	["v3_mourning_gramophone", "buy_whisper_record"],
	["v3_candlewick_airship", "buy_waxed_balloontwine"],
	["v3_iron_glove_well", "stitch_glove_cuff"],
	["v3_iron_glove_well", "buy_thimble_lamps"],
	["v3_mothglass_orrery", "oil_silver_orbits"],
	["v3_mothglass_orrery", "buy_moonwheel_thread"],
]

## Earlier roadside anchors that must stay present and unchanged.
const ANCHORS := {
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"description": "A soaked quilt bridge stretching over a ravine.",
		"choices": [
			{"id": "salvage_hems", "text": "Salvage loose hems (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "trade_fare", "text": "Trade fare for threads (-12 gold, +2 scraps)", "gold": -12, "scraps": 2},
			{"id": "take_detour", "text": "Take a detour (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_puppet_box_office": {
		"title": "The Puppet Box Office",
		"description": "Rag puppets wait under a patchwork theatre awning.",
		"choices": [
			{"id": "perform", "text": "Perform a short act (+9 gold)", "gold": 9, "scraps": 0},
			{"id": "restring", "text": "Restring the puppets (+24 gold, -2 scraps)", "gold": 24, "scraps": -2},
			{"id": "applaud", "text": "Applaud and move on", "gold": 0, "scraps": 0},
		],
	},
	"v3_sootglass_letterpress": {
		"title": "The Sootglass Letterpress",
		"description": "Under a leaking midnight awning, a masked paper-doll printer winds a giant sootglass letterpress; its black keys punch red-thread seals into quilt labels.",
		"choices": [
			{"id": "sell_inked_offcuts", "text": "Sell inked fabric offcuts (spend 2 scraps; gain 27 gold)", "gold": 27, "scraps": -2},
			{"id": "buy_label_shavings", "text": "Buy pressed label shavings (spend 14 gold; gain 2 scraps)", "gold": -14, "scraps": 2},
			{"id": "leave", "text": "Leave the press to its rattling", "gold": 0, "scraps": 0},
		],
	},
	"v3_ashen_bell_foundry": {
		"title": "The Ashen Bell Foundry",
		"description": "A squat candlekeeper feeds a vast bone-cream bell mould with frayed seam strips; every low toll drops a warm button of slag into the dark.",
		"choices": [
			{"id": "gather_casting_threads", "text": "Gather loose casting threads (gain 1 scrap)", "gold": 0, "scraps": 1},
			{"id": "patch_bell_mould", "text": "Patch the cracked bell mould (spend 3 scraps; gain 38 gold)", "gold": 38, "scraps": -3},
			{"id": "leave", "text": "Leave the foundry bells sleeping", "gold": 0, "scraps": 0},
		],
	},
}

## Independent per-ID seeds for the forced single-eligible selection replay. They
## never pin a selected position: with one eligible ID the outcome is that ID.
const SEEDS := {
	"v3_mourning_gramophone": 97301,
	"v3_candlewick_airship": 97302,
	"v3_iron_glove_well": 97303,
	"v3_mothglass_orrery": 97304,
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
	print("v3_gothic_oddity_roadside_wallet_test: ",
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
## signed wallet deltas; every catalog ID is unique; the named earlier anchors
## are untouched.
func _test_source_records() -> void:
	var events: Array = source_document.get("events", [])
	var seen: Dictionary = {}
	for record in events:
		if not record is Dictionary:
			continue
		var raw_id: Variant = (record as Dictionary).get("id")
		if not raw_id is String:
			continue
		var event_id: String = raw_id
		_check(not seen.has(event_id), "the catalog carries a unique ID: " + event_id)
		seen[event_id] = true
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
			_check_record_contract(source_by_id[anchor_id], anchor_id, ANCHORS[anchor_id], "anchor")


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
			_check_record_contract(anchor_matches[0], anchor_id, ANCHORS[anchor_id], "anchor selector")
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
## visit open, changes no wallet or record. The Airship's free salvage and every
## free Leave settle exactly once in independent fresh visits.
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
		# A refused paid branch must not consume the same visit's free Leave.
		var later_leave := service.choose_with_wallet("leave", EMPTY)
		_check(later_leave == {
			"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": EMPTY,
		}, "a refused debit still allows Leave on the same service: " + event_id + " / " + choice_id)
		_check(service.is_claimed() and not service.is_valid()
			and service.choose_with_wallet("leave", EMPTY).get("ok") == false,
			"the post-refusal Leave settles once: " + event_id + " / " + choice_id)
		_check(EMPTY == empty_snapshot and record == record_snapshot,
			"post-refusal Leave never mutates the input wallet or event")
	# The Airship's free salvage genuinely earns two scraps from an empty purse.
	var airship: Dictionary = source_by_id["v3_candlewick_airship"]
	var free_service := RunEventChoice.new(airship)
	var free_row := _preview_row(free_service.preview_wallet_choices(EMPTY), "collect_mooring_knots")
	_check(free_row.get("affordable") == true,
		"the free airship salvage is affordable from an empty purse")
	_check(free_row.get("wallet") == {"gold": 0, "scraps": 2},
		"the free airship salvage previews exactly two scraps")
	var free_receipt := free_service.choose_with_wallet("collect_mooring_knots", EMPTY)
	_check(free_receipt == {
		"ok": true, "event_id": "v3_candlewick_airship",
		"choice_id": "collect_mooring_knots", "wallet": {"gold": 0, "scraps": 2},
	}, "the free airship salvage earns exactly two scraps")
	_check(not free_service.is_valid()
		and free_service.choose_with_wallet("collect_mooring_knots", EMPTY).get("ok") == false,
		"the free airship salvage cannot be replayed")
	_check(EMPTY == empty_snapshot, "the free airship salvage never mutates the empty purse")
	# Each event's Leave succeeds with an unchanged wallet in a fresh visit.
	for event_id in EXPECTED:
		var leave_service := RunEventChoice.new(source_by_id[event_id])
		var leave_preview := _preview_row(leave_service.preview_wallet_choices(EMPTY), "leave")
		_check(leave_preview.get("affordable") == true and leave_preview.get("wallet") == EMPTY,
			"an empty purse previews the free Leave: " + event_id)
		var leave := leave_service.choose_with_wallet("leave", EMPTY)
		_check(leave == {
			"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": EMPTY,
		}, "an empty purse still settles its free Leave: " + event_id)
		_check(not leave_service.is_valid()
			and leave_service.choose_with_wallet("leave", EMPTY).get("ok") == false,
			"the empty-purse Leave cannot be replayed: " + event_id)
	_check(EMPTY == empty_snapshot, "the empty purse is never mutated")


## An unknown choice ID rejects without claiming, after which the same visit
## still settles its free Leave.
func _test_unknown_choice() -> void:
	var record: Dictionary = source_by_id["v3_mothglass_orrery"]
	var record_snapshot: Dictionary = record.duplicate(true)
	var service := RunEventChoice.new(record)
	var denied := service.choose_with_wallet("no_such_choice", EMPTY)
	_check(denied == {"ok": false, "event_id": "", "choice_id": "", "wallet": EMPTY},
		"an unknown choice rejects with an unchanged wallet")
	_check(not service.is_claimed() and service.is_valid(),
		"an unknown choice claims nothing")
	_check(record == record_snapshot, "an unknown choice never mutates the event record")
	var leave := service.choose_with_wallet("leave", EMPTY)
	_check(leave.get("ok") == true and leave.get("wallet") == EMPTY,
		"the visit still settles its Leave after an unknown choice")
	_check(not service.is_valid(),
		"the Leave after an unknown choice closes the visit")


## Every new event is selectable through the real default selector by a seeded
## caller that excludes the other currently eligible IDs, with exactly the
## documented one-draw contract and a detached authored record; exhausted or
## malformed exclusions reject without a draw and leave the selector detached.
func _test_forced_seeded_selection() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the default selector validates for forced selection")
	var ids: Array = rotation.get_generic_event_ids()
	var listing_snapshot: Array = rotation.get_generic_events()
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 951753
	var guard_state := rng_guard.state
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
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
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
	# Excluding every eligible ID rejects without a draw.
	var guard_before := rng_guard.state
	var exhausted := rotation.select_event(rng_guard, ids)
	_check(exhausted.get("ok") == false and (exhausted.get("event") as Dictionary).is_empty(),
		"an exhausted eligible set rejects with no event")
	_check(rng_guard.state == guard_before, "an exhausted eligible set consumes no RNG")
	# Malformed exclusion lists reject without a draw.
	for bad_list in ["leave", 7, {}, [1], [""], [["v3_mothglass_orrery"]]]:
		var malformed := rotation.select_event(rng_guard, bad_list)
		_check(malformed.get("ok") == false, "a malformed exclusion list rejects: " + str(bad_list))
		_check(rng_guard.state == guard_before,
			"a malformed exclusion list consumes no RNG: " + str(bad_list))
	# The selector and its catalog stay detached and valid after the rejections.
	_check(rotation.is_catalog_valid(), "rejections leave the selector valid")
	_check(rotation.get_generic_events() == listing_snapshot,
		"rejections never mutate the selector listing")
	_check(rng_guard.state == guard_state,
		"forced selections and rejections never touch an unrelated run RNG")


## Verbatim presentation, choice shape and signed deltas against the independent
## table. `origin` only labels failure messages.
func _check_record_contract(record: Variant, event_id: String, contract: Dictionary,
		origin: String) -> void:
	_check(record is Dictionary, origin + ": record is an object: " + event_id)
	if not record is Dictionary:
		return
	var event_record: Dictionary = record
	_check(event_record.get("id") == event_id, origin + ": authored id: " + event_id)
	_check(event_record.size() == 4 and event_record.has("id") and event_record.has("title")
		and event_record.has("description") and event_record.has("choices"),
		origin + ": record carries exactly id/title/description/choices: " + event_id)
	_check(event_record.get("title") == contract["title"], origin + ": authored title: " + event_id)
	_check(event_record.get("description") == contract["description"],
		origin + ": authored description: " + event_id)
	var choices: Variant = event_record.get("choices")
	_check(choices is Array, origin + ": choices is an array: " + event_id)
	if not choices is Array:
		return
	var expected_choices: Array = contract["choices"]
	_check((choices as Array).size() == expected_choices.size(),
		origin + ": exactly three authored choices: " + event_id)
	var by_choice: Dictionary = {}
	for choice in (choices as Array):
		_check(choice is Dictionary, origin + ": every choice is an object: " + event_id)
		if not choice is Dictionary:
			continue
		var choice_dict: Dictionary = choice
		_check(choice_dict.size() == 3 and choice_dict.has("id") and choice_dict.has("text")
			and choice_dict.has("outcome"),
			origin + ": choice carries exactly id/text/outcome: " + event_id)
		var raw_choice_id: Variant = choice_dict.get("id")
		_check(raw_choice_id is String, origin + ": every choice has a string ID: " + event_id)
		if not raw_choice_id is String:
			continue
		var choice_key: String = raw_choice_id
		_check(not by_choice.has(choice_key),
			origin + ": choice IDs are distinct: " + event_id + " / " + choice_key)
		by_choice[choice_key] = choice_dict
	_check(by_choice.size() == expected_choices.size(),
		origin + ": exactly three distinct choice IDs: " + event_id)
	for choice_def in expected_choices:
		var choice_id: String = choice_def["id"]
		_check(by_choice.has(choice_id),
			origin + ": authored choice present: " + event_id + " / " + choice_id)
		if not by_choice.has(choice_id):
			continue
		var choice: Dictionary = by_choice[choice_id]
		_check(choice.get("text") == choice_def["text"],
			origin + ": authored choice text: " + event_id + " / " + choice_id)
		var outcome: Variant = choice.get("outcome")
		_check(outcome is Dictionary, origin + ": choice outcome is an object: " + event_id + " / " + choice_id)
		if not outcome is Dictionary:
			continue
		var outcome_dict: Dictionary = outcome
		_check(outcome_dict.size() == 2 and outcome_dict.has("gold") and outcome_dict.has("scraps"),
			origin + ": exact signed outcome keys: " + event_id + " / " + choice_id)
		# JSON parsing may deliver whole numbers as floats; the authored
		# contract is a whole signed amount either way.
		var gold_amount: Variant = _signed_amount(outcome_dict.get("gold"))
		var scraps_amount: Variant = _signed_amount(outcome_dict.get("scraps"))
		_check(gold_amount != null and scraps_amount != null,
			origin + ": whole-number outcome amounts: " + event_id + " / " + choice_id)
		_check(gold_amount == choice_def["gold"] and scraps_amount == choice_def["scraps"],
			origin + ": authored signed outcome: " + event_id + " / " + choice_id)


func _signed_amount(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if not is_finite(number) or floor(number) != number:
			return null
		return int(number)
	return null


func _preview_row(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in (preview.get("choices", []) as Array):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


func _matches(records: Array, event_id: String) -> Array:
	var found: Array = []
	for record in records:
		if record is Dictionary and (record as Dictionary).get("id") == event_id:
			found.append(record)
	return found
