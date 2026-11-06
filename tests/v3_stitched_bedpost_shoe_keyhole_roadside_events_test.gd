extends SceneTree
## Deterministic headless coverage for the three doll-scale roadside wallet
## stories appended to the shipped roadside pack
## (res://data/events/v3_roadside_events.json): the Bedpost Thimble Lift, the
## Shoe-Tongue Tollbooth and the Keyhole Ribbon Windmill.
##
## EXPECTED, FUNDED_FINAL and ANCHORS are independent copies of the authored
## stories, deltas, funded settlement tables and earlier anchors; they never
## read the production catalog or the selector back as their oracle. Only
## per-ID membership is asserted: no catalog total, no full ordered ID list and
## no fixed pool position, so peer batches can land in the same catalog
## without clashing.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 60, "scraps": 6}
const SCARCE := {"gold": 0, "scraps": 0}

const EXPECTED := {
	"v3_bedpost_thimble_lift": {
		"title": "The Bedpost Thimble Lift",
		"description": "A stout button-eyed liftkeeper hauls a brass thimble up a giant bedpost on crossed red threads; the wooden rungs vanish into candlelit dark.",
		"choices": [
			{"id": "gather_pulley_shavings", "text": "Collect brass pulley shavings (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "oil_lift_pulley", "text": "Offer 2 scraps to oil the thimble lift (gain 28 gold)", "gold": 28, "scraps": -2},
			{"id": "leave", "text": "Let the lift climb without you", "gold": 0, "scraps": 0},
		],
	},
	"v3_shoe_tongue_tollbooth": {
		"title": "The Shoe-Tongue Tollbooth",
		"description": "An enormous oxblood boot blocks the passage, its tongue folded into a toll desk while a round mismatched-eye cobbler threads the towering eyelets.",
		"choices": [
			{"id": "fix_boot_laces", "text": "Spend 1 scrap re-lacing the giant boot (gain 19 gold)", "gold": 19, "scraps": -1},
			{"id": "buy_heel_threads", "text": "Pay 22 gold for four heel-thread bundles (+4 scraps)", "gold": -22, "scraps": 4},
			{"id": "leave", "text": "Tiptoe past the boot's loose lace", "gold": 0, "scraps": 0},
		],
	},
	"v3_keyhole_ribbon_windmill": {
		"title": "The Keyhole Ribbon Windmill",
		"description": "Behind peeled wallpaper a bone-cream keyhole towers over the dolls; a squat velvet windkeeper turns a ribbon windmill inside the lock.",
		"choices": [
			{"id": "gather_ribbon_tails", "text": "Gather fallen ribbon tails (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "buy_windmill_spools", "text": "Pay 17 gold for three windmill spools (+3 scraps)", "gold": -17, "scraps": 3},
			{"id": "leave", "text": "Leave the keyhole to its quiet wind", "gold": 0, "scraps": 0},
		],
	},
}

## Independent funded {gold: 60, scraps: 6} settlement table: the exact final
## balance each authored choice must reach from a fresh unclaimed visit.
const FUNDED_FINAL := {
	"v3_bedpost_thimble_lift": {
		"gather_pulley_shavings": {"gold": 60, "scraps": 8},
		"oil_lift_pulley": {"gold": 88, "scraps": 4},
		"leave": {"gold": 60, "scraps": 6},
	},
	"v3_shoe_tongue_tollbooth": {
		"fix_boot_laces": {"gold": 79, "scraps": 5},
		"buy_heel_threads": {"gold": 38, "scraps": 10},
		"leave": {"gold": 60, "scraps": 6},
	},
	"v3_keyhole_ribbon_windmill": {
		"gather_ribbon_tails": {"gold": 60, "scraps": 7},
		"buy_windmill_spools": {"gold": 43, "scraps": 9},
		"leave": {"gold": 60, "scraps": 6},
	},
}

## Independent per-ID seeds for the forced single-eligible selection replay.
const SEEDS := {
	"v3_bedpost_thimble_lift": 1190001,
	"v3_shoe_tongue_tollbooth": 1190002,
	"v3_keyhole_ribbon_windmill": 1190003,
}

## Earlier roadside anchors this additive batch must leave in the authored
## source and eligible in the generic rotation, named independently of the
## selector, with their original titles and signed wallet deltas.
const ANCHORS := {
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"description": "A soaked quilt bridge stretching over a ravine.",
		"choices": {
			"salvage_hems": {"text": "Salvage loose hems (+1 scrap)", "gold": 0, "scraps": 1},
			"trade_fare": {"text": "Trade fare for threads (-12 gold, +2 scraps)", "gold": -12, "scraps": 2},
			"take_detour": {"text": "Take a detour (Leave)", "gold": 0, "scraps": 0},
		},
	},
	"v3_midnight_lockbox_garden": {
		"title": "The Midnight Lockbox Garden",
		"description": "A squat moss-cloth gardener waters towering lockboxes whose brass keyholes bloom like flowers; a lone lantern lights their crooked velvet roots.",
		"choices": {
			"sell_old_lockplates": {"text": "Sell two worn lockplates (spend 2 scraps; gain 25 gold)", "gold": 25, "scraps": -2},
			"buy_keyhole_threads": {"text": "Buy three keyhole spools (spend 16 gold; gain 3 scraps)", "gold": -16, "scraps": 3},
			"leave": {"text": "Leave the lockbox flowers shut", "gold": 0, "scraps": 0},
		},
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
	_test_default_selector_membership()
	_test_wallet_contract()
	_test_scarce_wallets()
	_test_unknown_choices_and_invalid_wallets()
	_test_forced_seeded_selection()
	_check(source_document == source_snapshot, "the roadside source is unchanged by every flow")
	_report()

func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_bedpost_shoe_keyhole_roadside_events_test: ",
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
## signed wallet deltas.
func _test_source_records() -> void:
	for event_id in EXPECTED:
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

## The named earlier anchors keep exactly one record each with their original
## titles and signed wallet outcomes.
func _test_anchor_records() -> void:
	for anchor_id in ANCHORS:
		var contract: Dictionary = ANCHORS[anchor_id]
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"exactly one sourced record for the anchor " + anchor_id)
		if not source_by_id.has(anchor_id):
			continue
		var record: Dictionary = source_by_id[anchor_id]
		_check(record.get("title") == contract["title"],
			"the anchor keeps its original title: " + anchor_id)
		_check(record.get("description") == contract["description"],
			"the anchor keeps its original description: " + anchor_id)
		var choices: Variant = record.get("choices")
		if not choices is Array:
			_check(false, "the anchor keeps its choices array: " + anchor_id)
			continue
		_check((choices as Array).size() == 3, "anchor keeps its three original choices: " + anchor_id)
		var by_id := {}
		for choice in choices:
			if choice is Dictionary:
				by_id[(choice as Dictionary).get("id")] = choice
		for choice_id in contract["choices"]:
			_check(by_id.has(choice_id),
				"the anchor keeps its choice " + str(choice_id) + ": " + anchor_id)
			if not by_id.has(choice_id):
				continue
			var outcome: Variant = (by_id[choice_id] as Dictionary).get("outcome")
			var expected_outcome: Dictionary = contract["choices"][choice_id]
			_check((by_id[choice_id] as Dictionary).get("text") == expected_outcome["text"],
				"the anchor keeps its original choice text: " + anchor_id + " / " + str(choice_id))
			_check(outcome is Dictionary
				and (outcome as Dictionary).get("gold") == expected_outcome["gold"]
				and (outcome as Dictionary).get("scraps") == expected_outcome["scraps"],
				"the anchor keeps its original outcome: " + anchor_id + " / " + str(choice_id))

## A fresh default RunM04EventRotation lists every new record exactly once with
## the authored content and keeps the earlier anchors eligible.
func _test_default_selector_membership() -> void:
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
		_check(ids.count(anchor_id) == 1,
			"the named earlier anchor stays eligible: " + anchor_id)
	# The listing stays detached: mutating it never reaches the selector.
	var snapshot: Array = listing.duplicate(true)
	var first: Dictionary = listing[0]
	first["title"] = "MUTATED"
	first["choices"] = []
	listing.append({"id": "injected", "title": "Injected", "description": "Injected", "choices": []})
	_check(rotation.get_generic_events() == snapshot,
		"mutating a returned listing never reaches the selector")

## Funded previews and receipts agree with the independent settlement table on
## all nine authored choices; a settled choice cannot be replayed; results and
## inputs stay detached and an unrelated seeded RNG is untouched.
func _test_wallet_contract() -> void:
	var rotation := RunM04EventRotation.new()
	var listing_snapshot: Array = rotation.get_generic_events()
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 828282
	var guard_state := rng_guard.state
	var funded := FUNDED.duplicate(true)
	var funded_snapshot: Dictionary = funded.duplicate(true)
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var final_table: Dictionary = FUNDED_FINAL[event_id]
		_check(final_table.size() == 3,
			"the independent funded table covers three choices: " + event_id)
		var matches := _matches(listing_snapshot, event_id)
		_check(matches.size() == 1, "the default selector serves " + event_id + " for wallet play")
		if matches.size() != 1:
			continue
		var record: Dictionary = (matches[0] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var gold_delta: int = definition["gold"]
			var scraps_delta: int = definition["scraps"]
			var after: Dictionary = final_table[choice_id]
			_check(after["gold"] == 60 + gold_delta and after["scraps"] == 6 + scraps_delta,
				"the independent funded table agrees with the authored deltas: " + event_id + " / " + choice_id)
			var visit_record: Dictionary = record.duplicate(true)
			var service := RunEventChoice.new(visit_record)
			var preview := service.preview_wallet_choices(funded)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview succeeds: " + event_id + " / " + choice_id)
			var rows := _preview_map(preview)
			var row: Dictionary = rows.get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var receipt := service.choose_with_wallet(choice_id, funded)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": after,
			}, "the claim settles the independent funded balance: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay := service.choose_with_wallet(choice_id, funded)
			_check(replay == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": funded,
			}, "the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			var alternate_id := _other_choice_id(contract, choice_id)
			_check(service.choose_with_wallet(alternate_id, funded).get("ok") == false,
				"no alternate choice claims a spent visit: " + event_id + " / " + choice_id)
			_check(service.preview_wallet_choices(funded).get("ok") == false,
				"a spent visit offers no further preview: " + event_id + " / " + choice_id)
			var receipt_wallet: Dictionary = receipt["wallet"]
			_check(not is_same(receipt_wallet, funded),
				"a committed wallet is a detached copy: " + event_id + " / " + choice_id)
			receipt_wallet["gold"] += 999
			_check(funded == funded_snapshot,
				"a committed wallet never mutates the caller: " + event_id + " / " + choice_id)
			_check(visit_record == record_snapshot and record == record_snapshot and funded == funded_snapshot,
				"a funded flow never mutates the record or its purse: " + event_id + " / " + choice_id)
	_check(EXPECTED.size() == 3, "the independent table covers three new events")
	_check(settlements == 9, "every authored choice settles once when funded")
	_check(rotation.get_generic_events() == listing_snapshot,
		"wallet flows never mutate the selector listing")
	_check(rng_guard.state == guard_state,
		"previews and claims never touch an unrelated seeded RNG")

## Every spend-gold or spend-scraps branch refuses at an authentic empty
## purse without claim or mutation, while the free Leave settles for free on
## each fresh visit and the two gathering choices remain genuine free
## actionable gains of exactly two and one scraps.
func _test_scarce_wallets() -> void:
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var zero := SCARCE.duplicate(true)
	var zero_snapshot: Dictionary = zero.duplicate(true)
	var refusals := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "the selector serves " + event_id + " for scarce-purse play")
		if matches.size() != 1:
			continue
		var record: Dictionary = (matches[0] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		var paid_service := RunEventChoice.new(record)
		var paid_rows := _preview_map(paid_service.preview_wallet_choices(zero))
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			if int(definition["gold"]) >= 0 and int(definition["scraps"]) >= 0:
				continue
			_check(paid_rows.get(choice_id, {}).get("affordable") == false,
				"an empty purse cannot afford the debit: " + event_id + " / " + choice_id)
			var refused := paid_service.choose_with_wallet(choice_id, zero)
			_check(refused == {"ok": false, "event_id": "", "choice_id": "", "wallet": zero},
				"an empty purse refuses the debit unchanged: " + event_id + " / " + choice_id)
			_check(not is_same(refused.get("wallet"), zero),
				"a refusal returns a detached purse: " + event_id + " / " + choice_id)
			_check(paid_service.is_valid() and not paid_service.is_claimed(),
				"a refused debit keeps the visit open: " + event_id + " / " + choice_id)
			refusals += 1
		var free_def := _free_choice(contract, event_id)
		var leave_id := ""
		if not free_def.is_empty():
			leave_id = free_def["id"]
		if leave_id != "":
			var leave_service := RunEventChoice.new(record)
			var leave_receipt := leave_service.choose_with_wallet(leave_id, zero)
			_check(leave_receipt == {
				"ok": true, "event_id": event_id, "choice_id": leave_id, "wallet": zero,
			}, "an empty purse still settles its free Leave: " + event_id)
			_check(not leave_service.is_valid()
				and leave_service.choose_with_wallet(leave_id, zero).get("ok") == false,
				"the empty-purse Leave cannot be replayed: " + event_id)
		_check(zero == zero_snapshot and record == record_snapshot,
			"no scarce flow mutates the purse or the record: " + event_id)
	_check(refusals == 4, "every signed debit is refused at an empty purse")
	var bedpost_matches := _matches(listing, "v3_bedpost_thimble_lift")
	_check(bedpost_matches.size() == 1, "the selector serves the Bedpost Lift for free-gain play")
	if bedpost_matches.size() == 1:
		var shavings_service := RunEventChoice.new((bedpost_matches[0] as Dictionary).duplicate(true))
		var shavings := shavings_service.choose_with_wallet("gather_pulley_shavings", SCARCE)
		_check(shavings == {
			"ok": true, "event_id": "v3_bedpost_thimble_lift",
			"choice_id": "gather_pulley_shavings", "wallet": {"gold": 0, "scraps": 2},
		}, "the free pulley shavings settle to exactly two scraps from an empty purse")
		_check(shavings_service.is_claimed() and not shavings_service.is_valid(),
			"the free shavings claim latches once")
	var keyhole_matches := _matches(listing, "v3_keyhole_ribbon_windmill")
	_check(keyhole_matches.size() == 1, "the selector serves the Keyhole Windmill for free-gain play")
	if keyhole_matches.size() == 1:
		var tails_service := RunEventChoice.new((keyhole_matches[0] as Dictionary).duplicate(true))
		var tails := tails_service.choose_with_wallet("gather_ribbon_tails", SCARCE)
		_check(tails == {
			"ok": true, "event_id": "v3_keyhole_ribbon_windmill",
			"choice_id": "gather_ribbon_tails", "wallet": {"gold": 0, "scraps": 1},
		}, "the free ribbon tails settle to exactly one scrap from an empty purse")
		_check(tails_service.is_claimed() and not tails_service.is_valid(),
			"the free tails claim latches once")

## An unknown choice ID fails without claiming and Leave then succeeds on the
## same selector; malformed negative wallets are rejected in preview and
## choice without consuming the visit.
func _test_unknown_choices_and_invalid_wallets() -> void:
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var funded := FUNDED.duplicate(true)
	for event_id in EXPECTED:
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "the selector serves " + event_id + " for forged-ID play")
		if matches.size() != 1:
			continue
		var record: Dictionary = (matches[0] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var forged := service.choose_with_wallet("forged_choice", funded)
		_check(forged.get("ok") == false and forged.get("wallet") == funded,
			"an unknown choice ID is refused unchanged: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"an unknown choice ID keeps the visit open: " + event_id)
		var free_def := _free_choice(EXPECTED[event_id], event_id)
		if not free_def.is_empty():
			var leave_id: String = free_def["id"]
			var leave_receipt := service.choose_with_wallet(leave_id, funded)
			_check(leave_receipt == {
				"ok": true, "event_id": event_id, "choice_id": leave_id,
				"wallet": FUNDED_FINAL[event_id][leave_id],
			}, "Leave still succeeds after a forged refusal: " + event_id)
			_check(service.is_claimed() and not service.is_valid(),
				"the post-forged Leave claim latches once: " + event_id)
		var negative := {"gold": -1, "scraps": 0}
		var second := RunEventChoice.new(record)
		var denied_preview := second.preview_wallet_choices(negative)
		_check(denied_preview == {"ok": false, "event_id": "", "choices": []},
			"a malformed negative wallet is rejected in preview: " + event_id)
		var denied_choice := second.choose_with_wallet("leave", negative)
		_check(denied_choice == {"ok": false, "event_id": "", "choice_id": "", "wallet": {}},
			"a malformed negative wallet is rejected in choice: " + event_id)
		_check(second.is_valid() and not second.is_claimed(),
			"a malformed wallet consumes no visit: " + event_id)
		var third := RunEventChoice.new(record)
		_check(third.preview_wallet_choices({"gold": 60, "scraps": -6}).get("ok") == false,
			"a negative scraps wallet is rejected in preview: " + event_id)
		_check(third.is_valid() and not third.is_claimed(),
			"a rejected preview leaves the visit open: " + event_id)
		_check(record == record_snapshot, "forged and malformed flows mutate no record: " + event_id)

## Every new event is selectable through the real default selector by a seeded
## caller that excludes the other currently eligible IDs, through both the
## generic and the actionable route with the funded wallet, with exactly the
## documented one-draw contract, replay consistency, a detached authored
## record and an untouched caller wallet. Exhausted and malformed calls reject
## without consuming RNG.
func _test_forced_seeded_selection() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped catalogs validate in the default selector")
	if not rotation.is_catalog_valid():
		return
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() > EXPECTED.size(),
		"the eligible pool holds more than this batch, so exclusions are meaningful")
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1, "the eligible pool carries " + event_id + " once")
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id) and excluded.size() == ids.size() - 1,
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
		_check(selected == source_by_id[event_id],
			"the selection is the authentic authored record: " + event_id)
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"identical seed and exclusions replay " + event_id)
		var action_rng := RandomNumberGenerator.new()
		action_rng.seed = seed_value
		var action_oracle := RandomNumberGenerator.new()
		action_oracle.seed = seed_value
		action_oracle.randi_range(0, 0)
		var action_wallet := FUNDED.duplicate(true)
		var action_wallet_snapshot: Dictionary = action_wallet.duplicate(true)
		var actionable := rotation.select_actionable_event(action_rng, excluded, action_wallet)
		_check(actionable.get("ok") == true,
			"the funded wallet keeps " + event_id + " actionable")
		var action_event: Dictionary = actionable.get("event", {})
		_check(action_event.get("id") == event_id
			and action_event == source_by_id[event_id],
			"the forced actionable route returns " + event_id)
		_check(action_rng.state == action_oracle.state,
			"the forced actionable draw consumes exactly one range draw: " + event_id)
		_check(action_wallet == action_wallet_snapshot,
			"the actionable route never mutates the caller wallet: " + event_id)
		var action_replay_rng := RandomNumberGenerator.new()
		action_replay_rng.seed = seed_value
		var action_replay := rotation.select_actionable_event(action_replay_rng, excluded, FUNDED)
		_check(action_replay.get("ok") == true and action_replay.get("event") == action_event
			and action_replay_rng.state == action_rng.state,
			"identical seed and exclusions replay the actionable " + event_id)
		var snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == snapshot and detached.get("event") == source_by_id[event_id],
			"the selected " + event_id + " is a detached authored copy")
	# An exhausted pool rejects without a draw through both routes.
	var guard := RandomNumberGenerator.new()
	guard.seed = 747474
	var guard_state: int = guard.state
	var none_result := rotation.select_event(guard, ids)
	_check(none_result.get("ok") == false and (none_result.get("event") as Dictionary).is_empty(),
		"excluding every eligible event rejects with no event")
	_check(guard.state == guard_state, "an exhausted pool consumes no RNG")
	var none_actionable := rotation.select_actionable_event(guard, ids, FUNDED)
	_check(none_actionable.get("ok") == false,
		"the exhausted actionable route rejects with no event")
	_check(guard.state == guard_state, "the exhausted actionable route consumes no RNG")
	# Malformed exclusions and wallets reject closed without consuming RNG.
	var malformed_guard := RandomNumberGenerator.new()
	malformed_guard.seed = 191919
	var malformed_state: int = malformed_guard.state
	_check(rotation.select_event(malformed_guard, 5).get("ok") == false,
		"a non-array exclusion list rejects")
	_check(rotation.select_event(malformed_guard, [""]).get("ok") == false,
		"a blank exclusion ID rejects")
	_check(rotation.select_event(malformed_guard, [7]).get("ok") == false,
		"a non-string exclusion ID rejects")
	_check(rotation.select_actionable_event(malformed_guard, [""]).get("ok") == false,
		"a malformed actionable exclusion rejects without a wallet")
	_check(rotation.select_actionable_event(malformed_guard, null, {"gold": -5, "scraps": 0}).get("ok") == false,
		"a malformed actionable wallet rejects")
	_check(rotation.select_actionable_event(malformed_guard, [""], FUNDED).get("ok") == false,
		"a malformed actionable exclusion rejects with a funded wallet")
	_check(malformed_guard.state == malformed_state,
		"malformed exclusions and wallets consume no RNG")

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
		var gold_amount: Variant = _signed_amount(wallet_outcome.get("gold"))
		var scraps_amount: Variant = _signed_amount(wallet_outcome.get("scraps"))
		_check(gold_amount != null and scraps_amount != null,
			"whole-number outcome amounts: " + origin + " / " + event_id + " / " + choice_id)
		_check(gold_amount == definition["gold"] and scraps_amount == definition["scraps"],
			"authored signed outcome: " + origin + " / " + event_id + " / " + choice_id)

func _free_choice(contract: Dictionary, event_id: String) -> Dictionary:
	var free_choices: Array = []
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		if int(definition["gold"]) == 0 and int(definition["scraps"]) == 0:
			free_choices.append(definition)
	_check(free_choices.size() == 1,
		"exactly one zero-cost Leave choice is authored: " + event_id)
	return free_choices[0] if free_choices.size() == 1 else {}

func _other_choice_id(contract: Dictionary, choice_id: String) -> String:
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		if definition["id"] != choice_id:
			return definition["id"]
	return choice_id

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
