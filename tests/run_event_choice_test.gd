extends SceneTree
## Deterministic headless test for RunEventChoice (M04 authored event selector).
## Covers the six authored events in data/events/m04_events.json (looked up by
## ID, never by catalog size/order/index), Button Trail, Loose Seam, Thimble
## Well, Frayed Signpost, Needle Gate and Quiet Spool wallets, detached snapshots,
## fail-closed invalid records and outcomes, recovery after failed preflight,
## replay rejection and zero RNG use.
## Also covers the V3-4 vitality catalog (data/events/v3_vital_story_events.json, by ID)
## and the separate preview_vital_choices / choose_with_vitals transaction.

const EVENTS_PATH := "res://data/events/m04_events.json"

const REQUIRED := {
	"button_trail": {
		"title": "The Button Trail",
		"description": "Mismatched buttons form a trail across the grass.",
		"choices": {"follow": "Follow the button trail", "leave": "Leave 12 gold for two bundles of thread (+2 scraps)", "sell_buttons": "Sell a button bundle (spend 1 scrap; gain 18 gold)"},
		"outcomes": {
			"follow": {"gold": 0, "scraps": 1},
			"leave": {"gold": -12, "scraps": 2},
			"sell_buttons": {"gold": 18, "scraps": -1},
		},
	},
	"loose_seam": {
		"title": "The Loose Seam",
		"description": "A strip of patched ground has come unstitched.",
		"choices": {"mend": "Sew the seam (spend 1 scrap; recover 15 gold)", "bypass": "Walk around and gather loose thread (+1 scrap)", "reinforce": "Reinforce the long tear (spend 2 scraps; gain 32 gold)"},
		"outcomes": {
			"mend": {"gold": 15, "scraps": -1},
			"bypass": {"gold": 0, "scraps": 1},
			"reinforce": {"gold": 32, "scraps": -2},
		},
	},
	"thimble_well": {
		"title": "The Thimble Well",
		"description": "A silver thimble rests beside a dry stone well.",
		"choices": {"listen": "Listen for loose thimbles (+1 scrap)", "depart": "Find coins on the roadside (+5 gold)", "lower_spool": "Lower a spool line (spend 1 scrap; recover 18 gold)"},
		"outcomes": {
			"listen": {"gold": 0, "scraps": 1},
			"depart": {"gold": 5, "scraps": 0},
			"lower_spool": {"gold": 18, "scraps": -1},
		},
	},
	"frayed_signpost": {
		"title": "The Frayed Signpost",
		"description": "Three cloth arrows flap from a crooked signpost.",
		"choices": {"read": "Patch the arrows (1 scrap for 10 gold)", "choose": "Choose the clear path (+1 scrap)", "sell_arrowwork": "Sell the stitched arrowwork (spend 2 scraps; gain 26 gold)"},
		"outcomes": {
			"read": {"gold": 10, "scraps": -1},
			"choose": {"gold": 0, "scraps": 1},
			"sell_arrowwork": {"gold": 26, "scraps": -2},
		},
	},
	"quiet_spool": {
		"title": "The Quiet Spool",
		"description": "An abandoned spool spins without a breeze.",
		"choices": {"watch": "Watch the thread unwind", "ignore": "Leave the spool alone"},
		"outcomes": {
			"watch": {"gold": 0, "scraps": 1},
			"ignore": {"gold": 0, "scraps": 0},
		},
	},
	"needle_gate": {
		"title": "The Needle Gate",
		"description": "Crossed needles mark a narrow wooden gate.",
		"choices": {"examine": "Spend 1 scrap to unpick the gate and claim 12 gold", "pass": "Pass without stopping", "cut_bindings": "Cut the binding threads (spend 2 scraps; gain 28 gold)"},
		"outcomes": {
			"examine": {"gold": 12, "scraps": -1},
			"pass": {"gold": 0, "scraps": 0},
			"cut_bindings": {"gold": 28, "scraps": -2},
		},
	},
}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_snapshot: Array = []


func _initialize() -> void:
	_test_catalog_content()
	_test_authored_claim_flow()
	_test_button_trail_wallet_settlement()
	_test_loose_seam_wallet_settlement()
	_test_thimble_well_wallet_settlement()
	_test_frayed_signpost_wallet_settlement()
	_test_needle_gate_wallet_settlement()
	_test_quiet_spool_wallet_settlement()
	_test_signed_scraps_boundaries()
	_test_wallet_choice_previews()
	_test_wallet_preview_fail_closed()
	_test_wallet_preflight_rejections_and_recovery()
	_test_invalid_records()
	_test_bad_choice_recovery_and_replay()
	_test_no_rng_consumption()
	_test_seeded_replay_and_wallet_rng()
	_test_vital_catalog_content()
	_test_vital_branch_settlement()
	_test_vital_caps_and_bounds()
	_test_vital_unaffordable_then_leave()
	_test_vital_new_story_negatives()
	_test_vital_malformed_inputs()
	_check(catalog == catalog_snapshot, "shared event catalog unchanged across all test flows")
	for failure in failures:
		printerr(failure)
	print("run_event_choice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _shape_ok(result: Dictionary) -> bool:
	return result.size() == 3 and result.has("ok") and result.has("event_id") and result.has("choice_id")


func _wallet_shape_ok(result: Dictionary) -> bool:
	return (
		result.size() == 4
		and result.has("ok")
		and result.has("event_id")
		and result.has("choice_id")
		and result.has("wallet")
		and result.get("wallet") is Dictionary
	)


func _wallet_exact_int(wallet: Variant, expected_gold: int, expected_scraps: int) -> bool:
	if not wallet is Dictionary:
		return false
	var dict: Dictionary = wallet
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return false
	var gold: Variant = dict.get("gold")
	var scraps: Variant = dict.get("scraps")
	return (
		typeof(gold) == TYPE_INT
		and typeof(scraps) == TYPE_INT
		and int(gold) == expected_gold
		and int(scraps) == expected_scraps
	)


func _is_integral_json_number(value: Variant, allow_negative: bool = false) -> bool:
	if typeof(value) == TYPE_INT:
		return allow_negative or int(value) >= 0
	if typeof(value) == TYPE_FLOAT:
		var num: float = value
		return (is_finite(num) and floor(num) == num
			and num <= RunEventChoice.MAX_SAFE_FLOAT_INT
			and num >= (-RunEventChoice.MAX_SAFE_FLOAT_INT if allow_negative else 0.0))
	return false


func _rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _matching(event_id: String) -> Array:
	return catalog.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


func _valid_fixture() -> Dictionary:
	return {
		"id": "fixture_event",
		"title": "Fixture Event",
		"description": "An in-memory event used only by this test.",
		"choices": [
			{"id": "one", "text": "Take the first option"},
			{"id": "two", "text": "Take the second option"},
		],
	}


func _test_catalog_content() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "m04_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(text != "", "m04_events.json is non-empty")
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, "m04_events.json parses through JSON")
	var data: Variant = parser.data if parse_result == OK else null
	_check(data is Dictionary, "top level is a JSON object")
	if not data is Dictionary:
		return
	var list: Variant = (data as Dictionary).get("events")
	_check(list is Array, "top level has an events array")
	if not list is Array:
		return
	_check(not (list as Array).is_empty(), "events array is non-empty")
	catalog = list
	catalog_snapshot = catalog.duplicate(true)
	for entry in catalog:
		_check(entry is Dictionary, "every event record is an object")
	for event_id in REQUIRED:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "exactly one authored event record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = REQUIRED[event_id]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"authored event has exact top-level keys: " + event_id)
		_check(record.get("title") == expected["title"], "authored title: " + event_id)
		_check(record.get("description") == expected["description"], "authored description: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array, "choices array present: " + event_id)
		if not choices is Array:
			continue
		_check((choices as Array).size() >= 2 and (choices as Array).size() <= 3,
			"2 to 3 choices: " + event_id)
		if event_id == "needle_gate":
			var choice_ids := (choices as Array).map(func(c): return c.get("id"))
			_check(choice_ids.size() == 3 and choice_ids[0] == "examine" and choice_ids[1] == "pass" and choice_ids[2] == "cut_bindings",
				"Needle Gate retains examine, pass in authored order with new cut_bindings appended")
		var seen := {}
		var by_id := {}
		var choice_records := {}
		for choice in choices:
			if not choice is Dictionary:
				_check(false, "choice record is an object: " + event_id)
				continue
			var choice_dict: Dictionary = choice
			var choice_id: Variant = choice_dict.get("id")
			var choice_text: Variant = choice_dict.get("text")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"nonblank string choice ID: " + event_id)
			_check(choice_text is String and not (choice_text as String).strip_edges().is_empty(),
				"nonblank string choice text: " + event_id)
			if not choice_id is String:
				continue
			_check(not seen.has(choice_id), "distinct choice IDs: " + event_id)
			seen[choice_id] = true
			by_id[choice_id] = choice_text
			choice_records[choice_id] = choice_dict
		var wanted: Dictionary = expected["choices"]
		for choice_id in wanted:
			_check(by_id.has(choice_id), "required choice present: " + event_id + "/" + choice_id)
			_check(by_id.get(choice_id) == wanted[choice_id],
				"authored choice text: " + event_id + "/" + choice_id)
			if not choice_records.has(choice_id):
				continue
			var choice_dict: Dictionary = choice_records[choice_id]
			if expected.has("outcomes"):
				var wanted_outcomes: Dictionary = expected["outcomes"]
				var expected_outcome: Dictionary = wanted_outcomes[choice_id]
				_check(choice_dict.size() == 3 and choice_dict.has("id")
					and choice_dict.has("text") and choice_dict.has("outcome"),
					"outcome choice has exact keys id/text/outcome: " + event_id + "/" + choice_id)
				var raw_outcome: Variant = choice_dict.get("outcome")
				_check(raw_outcome is Dictionary,
					"authored outcome is an object: " + event_id + "/" + choice_id)
				if raw_outcome is Dictionary:
					var outcome: Dictionary = raw_outcome
					_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"),
						"authored outcome has exact gold/scraps keys: " + event_id + "/" + choice_id)
					var raw_gold: Variant = outcome.get("gold")
					var raw_scraps: Variant = outcome.get("scraps")
					var allow_negative_gold: bool = (event_id == "button_trail" and choice_id == "leave")
					_check(_is_integral_json_number(raw_gold, allow_negative_gold),
						"authored outcome gold is integral" + (" (negative allowed)" if allow_negative_gold else " nonnegative") + ": " + event_id + "/" + choice_id)
					_check(_is_integral_json_number(raw_scraps, true),
						"authored outcome scraps is integral signed: " + event_id + "/" + choice_id)
					if _is_integral_json_number(raw_gold, allow_negative_gold) and _is_integral_json_number(raw_scraps, true):
						_check(int(raw_gold) == expected_outcome["gold"]
							and int(raw_scraps) == expected_outcome["scraps"],
							"authored outcome matches exact gold/scraps: " + event_id + "/" + choice_id)
			else:
				_check(choice_dict.size() == 2 and choice_dict.has("id")
					and choice_dict.has("text") and not choice_dict.has("outcome"),
					"placeholder event choice unchanged without outcome: " + event_id + "/" + choice_id)
		_check(by_id.size() == wanted.size(), "no unstated choice IDs: " + event_id)
		var service := RunEventChoice.new(record)
		_check(service.has_method("choose") and service.has_method("choose_with_wallet"),
			"RunEventChoice exposes choose and choose_with_wallet: " + event_id)
		_check(service.is_valid(), "authored record builds a valid selector: " + event_id)
		_check(not service.is_claimed(), "fresh selector is unclaimed: " + event_id)


func _test_authored_claim_flow() -> void:
	if catalog.is_empty():
		return
	var step := 0
	for event_id in REQUIRED:
		step += 1
		var matches := _matching(event_id)
		if matches.size() != 1:
			continue
		var caller_record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = caller_record.duplicate(true)
		var rng_expected := _rng_start(63000 + step)
		var service := RunEventChoice.new(caller_record)
		_check(service.is_valid() and not service.is_claimed(), "fresh valid selector: " + event_id)
		var snapshot := service.get_event()
		_check(snapshot == original, "detached copy equals authored input: " + event_id)
		snapshot["title"] = "mutated snapshot title"
		var snapshot_choices: Array = snapshot.get("choices", [])
		snapshot_choices[0]["text"] = "mutated snapshot text"
		_check(service.get_event() == original, "returned snapshot mutation isolated: " + event_id)
		caller_record["description"] = "mutated caller description"
		var caller_choices: Array = caller_record.get("choices", [])
		caller_choices.append({"id": "sneaky", "text": "An appended caller choice"})
		_check(service.get_event() == original, "caller mutation isolated: " + event_id)
		_check(randi() == rng_expected, "construction and reads spend no RNG: " + event_id)

		# Fresh seeded window: everything from the claim to the replay must spend no global RNG.
		var rng_claim := _rng_start(63100 + step)
		var first_id: String = (original.get("choices", [])[0] as Dictionary).get("id", "")
		var result := service.choose(first_id)
		_check(_shape_ok(result), "result has exactly ok/event_id/choice_id: " + event_id)
		_check(result.get("ok", false) == true, "offered choice succeeds: " + event_id)
		_check(result.get("event_id", "") == event_id, "exact event ID returned: " + event_id)
		_check(result.get("choice_id", "") == first_id, "exact choice ID returned: " + event_id)
		_check(service.is_claimed(), "claim latched: " + event_id)
		_check(not service.is_valid(), "consumed offering reports invalid: " + event_id)
		_check(service.get_event() == original, "claim leaves event snapshot unchanged: " + event_id)

		var replay := service.choose(first_id)
		_check(_shape_ok(replay) and replay.get("ok", true) == false, "replay rejected: " + event_id)
		_check(service.is_claimed(), "rejection consumes no extra claim: " + event_id)
		_check(service.get_event() == original, "rejection leaves state unchanged: " + event_id)

		var fresh := RunEventChoice.new(original.duplicate(true))
		var fresh_result := fresh.choose(first_id)
		_check(fresh_result == result, "fresh-instance deterministic trace: " + event_id)
		_check(fresh.is_claimed(), "fresh instance claims independently: " + event_id)
		_check(fresh.get_event() == original, "fresh instance snapshot equal: " + event_id)
		_check(randi() == rng_claim, "whole claim flow spends no RNG: " + event_id)


func _test_button_trail_wallet_settlement() -> void:
	var matches := _matching("button_trail")
	_check(matches.size() == 1, "button_trail present in catalog for wallet settlement")
	if matches.size() != 1:
		return
	var authored_record: Dictionary = matches[0]
	var original_event: Dictionary = authored_record.duplicate(true)

	# Branch 1: follow (+0 gold, +1 scrap) from {gold: 12, scraps: 0} -> {gold: 12, scraps: 1}
	var follow_input_event: Dictionary = authored_record.duplicate(true)
	var follow_wallet := {"gold": 12, "scraps": 0}
	var follow_rng := _rng_start(64001)
	var follow_service := RunEventChoice.new(follow_input_event)
	_check(follow_service.is_valid() and not follow_service.is_claimed(),
		"fresh button_trail selector valid before follow")
	var follow_result := follow_service.choose_with_wallet("follow", follow_wallet)
	_check(_wallet_shape_ok(follow_result), "follow choose_with_wallet returns 4-key wallet shape")
	_check(follow_result.get("ok", false) == true, "follow choose_with_wallet succeeds")
	_check(follow_result.get("event_id", "") == "button_trail", "follow returns button_trail event_id")
	_check(follow_result.get("choice_id", "") == "follow", "follow returns follow choice_id")
	_check(_wallet_exact_int(follow_result.get("wallet"), 12, 1),
		"follow settles exact integer wallet {gold: 12, scraps: 1}")
	_check(_wallet_exact_int(follow_wallet, 12, 0), "follow does not mutate caller input wallet")
	_check(follow_input_event == original_event, "follow does not mutate caller input event")
	_check(follow_service.get_event() == original_event, "follow does not mutate internal event snapshot")
	_check(follow_service.is_claimed() and not follow_service.is_valid(),
		"follow latches claim and marks selector consumed")
	_check(randi() == follow_rng, "follow wallet settlement spends no global RNG")

	# Prove returned wallet and result dictionaries are detached from service and subsequent calls.
	follow_wallet["gold"] = 999
	follow_wallet["scraps"] = 999
	(follow_result["wallet"] as Dictionary)["gold"] = 777
	(follow_result["wallet"] as Dictionary)["scraps"] = 777
	follow_result["ok"] = false
	var follow_second_wallet := {"gold": 12, "scraps": 1}
	var follow_replay := follow_service.choose_with_wallet("leave", follow_second_wallet)
	_check(_wallet_shape_ok(follow_replay) and follow_replay.get("ok", true) == false,
		"subsequent choose_with_wallet after follow is rejected")
	_check(follow_replay.get("event_id", "") == "" and follow_replay.get("choice_id", "") == "",
		"rejected replay after follow returns empty IDs")
	_check(_wallet_exact_int(follow_replay.get("wallet"), 12, 1),
		"rejected replay after follow returns detached unchanged valid wallet")
	(follow_replay["wallet"] as Dictionary)["gold"] = 0
	_check(_wallet_exact_int(follow_second_wallet, 12, 1),
		"mutating rejected replay wallet does not mutate caller wallet")
	var follow_legacy_replay := follow_service.choose("follow")
	_check(_shape_ok(follow_legacy_replay) and follow_legacy_replay.get("ok", true) == false,
		"legacy choose() also rejects after choose_with_wallet claim")
	_check(follow_service.is_claimed() and not follow_service.is_valid(),
		"follow claim remains latched after replay attempts")
	_check(follow_service.get_event() == original_event,
		"follow event snapshot unchanged after replay attempts")

	# Branch 2: leave (-12 gold, +2 scraps) from {gold: 12, scraps: 0} -> {gold: 0, scraps: 2}
	var leave_input_event: Dictionary = authored_record.duplicate(true)
	var leave_wallet := {"gold": 12, "scraps": 0}
	var leave_rng := _rng_start(64002)
	var leave_service := RunEventChoice.new(leave_input_event)
	_check(leave_service.is_valid() and not leave_service.is_claimed(),
		"fresh button_trail selector valid before leave")
	var leave_result := leave_service.choose_with_wallet("leave", leave_wallet)
	_check(_wallet_shape_ok(leave_result), "leave choose_with_wallet returns 4-key wallet shape")
	_check(leave_result.get("ok", false) == true, "leave choose_with_wallet succeeds")
	_check(leave_result.get("event_id", "") == "button_trail", "leave returns button_trail event_id")
	_check(leave_result.get("choice_id", "") == "leave", "leave returns leave choice_id")
	_check(_wallet_exact_int(leave_result.get("wallet"), 0, 2),
		"leave settles exact integer wallet {gold: 0, scraps: 2}")
	_check(_wallet_exact_int(leave_wallet, 12, 0), "leave does not mutate caller input wallet")
	_check(leave_input_event == original_event, "leave does not mutate caller input event")
	_check(leave_service.get_event() == original_event, "leave does not mutate internal event snapshot")
	_check(leave_service.is_claimed() and not leave_service.is_valid(),
		"leave latches claim and marks selector consumed")
	_check(randi() == leave_rng, "leave wallet settlement spends no global RNG")

	# Preview leave at 12 gold/0 scraps: affordable, forecast 0 gold/2 scraps.
	var leave_preview_12_event: Dictionary = authored_record.duplicate(true)
	var leave_preview_12_wallet := {"gold": 12, "scraps": 0}
	var leave_preview_12_rng := _rng_start(64010)
	var leave_preview_12_service := RunEventChoice.new(leave_preview_12_event)
	_check(leave_preview_12_service.is_valid() and not leave_preview_12_service.is_claimed(),
		"fresh button_trail selector valid before leave preview at 12 gold")
	var leave_preview_12 := leave_preview_12_service.preview_wallet_choices(leave_preview_12_wallet)
	_check(leave_preview_12.get("ok") == true and leave_preview_12.get("event_id") == "button_trail",
		"leave preview at 12 gold returns ok with button_trail event_id")
	var leave_preview_entry := {}
	for entry in leave_preview_12.get("choices", []):
		if entry.get("choice_id") == "leave":
			leave_preview_entry = entry
			break
	_check(not leave_preview_entry.is_empty(), "leave preview entry present for leave choice")
	_check(leave_preview_entry.get("gold_delta") == -12 and leave_preview_entry.get("scraps_delta") == 2,
		"leave preview shows exact signed deltas -12 gold, +2 scraps")
	_check(leave_preview_entry.get("affordable") == true,
		"leave preview marks choice affordable at 12 gold")
	_check(_wallet_exact_int(leave_preview_entry.get("wallet"), 0, 2),
		"leave preview projects exact wallet {gold: 0, scraps: 2}")
	_check(leave_preview_12_service.is_valid() and not leave_preview_12_service.is_claimed()
		and leave_preview_12_service.get_event() == original_event
		and leave_preview_12_event == original_event
		and _wallet_exact_int(leave_preview_12_wallet, 12, 0),
		"leave preview consumes no claim and leaves state unchanged")
	_check(randi() == leave_preview_12_rng, "leave preview at 12 gold spends no global RNG")

	# Preview leave at 11 gold/0 scraps: unaffordable, unchanged forecast.
	var leave_preview_11_event: Dictionary = authored_record.duplicate(true)
	var leave_preview_11_wallet := {"gold": 11, "scraps": 0}
	var leave_preview_11_rng := _rng_start(64011)
	var leave_preview_11_service := RunEventChoice.new(leave_preview_11_event)
	_check(leave_preview_11_service.is_valid() and not leave_preview_11_service.is_claimed(),
		"fresh button_trail selector valid before leave preview at 11 gold")
	var leave_preview_11 := leave_preview_11_service.preview_wallet_choices(leave_preview_11_wallet)
	_check(leave_preview_11.get("ok") == true and leave_preview_11.get("event_id") == "button_trail",
		"leave preview at 11 gold returns ok with button_trail event_id")
	var leave_preview_11_entry := {}
	for entry in leave_preview_11.get("choices", []):
		if entry.get("choice_id") == "leave":
			leave_preview_11_entry = entry
			break
	_check(not leave_preview_11_entry.is_empty(), "leave preview entry present for leave choice at 11 gold")
	_check(leave_preview_11_entry.get("gold_delta") == -12 and leave_preview_11_entry.get("scraps_delta") == 2,
		"leave preview at 11 gold shows exact signed deltas -12 gold, +2 scraps")
	_check(leave_preview_11_entry.get("affordable") == false,
		"leave preview marks choice unaffordable at 11 gold")
	_check(_wallet_exact_int(leave_preview_11_entry.get("wallet"), 11, 0),
		"leave preview at 11 gold projects unchanged wallet {gold: 11, scraps: 0}")
	_check(leave_preview_11_service.is_valid() and not leave_preview_11_service.is_claimed()
		and leave_preview_11_service.get_event() == original_event
		and leave_preview_11_event == original_event
		and _wallet_exact_int(leave_preview_11_wallet, 11, 0),
		"leave preview at 11 gold consumes no claim and leaves state unchanged")
	_check(randi() == leave_preview_11_rng, "leave preview at 11 gold spends no global RNG")

	# Compare preview forecasts with actual commit/refusal receipts for leave at 12 gold.
	var leave_commit_12_event: Dictionary = authored_record.duplicate(true)
	var leave_commit_12_wallet := {"gold": 12, "scraps": 0}
	var leave_commit_12_service := RunEventChoice.new(leave_commit_12_event)
	var leave_commit_12_receipt := leave_commit_12_service.choose_with_wallet("leave", leave_commit_12_wallet)
	_check(leave_commit_12_receipt.get("ok") == true
		and leave_commit_12_receipt.get("wallet") == leave_preview_entry.get("wallet")
		and leave_commit_12_receipt.get("event_id") == "button_trail"
		and leave_commit_12_receipt.get("choice_id") == "leave",
		"leave commit at 12 gold matches preview forecast exactly")
	_check(leave_commit_12_service.is_claimed() and not leave_commit_12_service.is_valid(),
		"leave commit at 12 gold latches claim")

	# Compare preview forecasts with actual refusal receipt for leave at 11 gold.
	var leave_refuse_11_event: Dictionary = authored_record.duplicate(true)
	var leave_refuse_11_wallet := {"gold": 11, "scraps": 0}
	var leave_refuse_11_service := RunEventChoice.new(leave_refuse_11_event)
	var leave_refuse_11_receipt := leave_refuse_11_service.choose_with_wallet("leave", leave_refuse_11_wallet)
	_check(leave_refuse_11_receipt.get("ok") == false
		and leave_refuse_11_receipt.get("wallet") == leave_preview_11_entry.get("wallet")
		and leave_refuse_11_receipt.get("event_id") == ""
		and leave_refuse_11_receipt.get("choice_id") == ""
		and leave_refuse_11_service.is_valid() and not leave_refuse_11_service.is_claimed(),
		"leave refusal at 11 gold matches preview forecast exactly")

	# Branch 2a: leave with insufficient gold (11) is refused without claiming
	var poor_leave_event: Dictionary = authored_record.duplicate(true)
	var poor_leave_wallet := {"gold": 11, "scraps": 0}
	var poor_leave_rng := _rng_start(64005)
	var poor_leave_service := RunEventChoice.new(poor_leave_event)
	_check(poor_leave_service.is_valid() and not poor_leave_service.is_claimed(),
		"fresh button_trail selector valid before refused leave (11 gold)")
	var poor_leave_refusal := poor_leave_service.choose_with_wallet("leave", poor_leave_wallet)
	_check(_wallet_shape_ok(poor_leave_refusal) and poor_leave_refusal.get("ok", true) == false
		and poor_leave_refusal.get("event_id", "") == "" and poor_leave_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_leave_refusal.get("wallet"), 11, 0),
		"leave with 11 gold is refused with exact unchanged wallet")
	_check(poor_leave_service.is_valid() and not poor_leave_service.is_claimed()
		and _wallet_exact_int(poor_leave_wallet, 11, 0)
		and poor_leave_service.get_event() == original_event and poor_leave_event == original_event,
		"refused leave consumes no visit and keeps both event snapshots")
	(poor_leave_refusal["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(poor_leave_wallet, 11, 0),
		"mutating refused wallet cannot change caller wallet")
	_check(randi() == poor_leave_rng, "refused leave spends no global RNG")

	# Branch 2b: recovery with sufficient gold (12) succeeds exactly once on same selector
	var leave_recovery := poor_leave_service.choose_with_wallet("leave", {"gold": 12, "scraps": 0})
	_check(_wallet_shape_ok(leave_recovery) and leave_recovery.get("ok", false) == true
		and leave_recovery.get("event_id", "") == "button_trail"
		and leave_recovery.get("choice_id", "") == "leave"
		and _wallet_exact_int(leave_recovery.get("wallet"), 0, 2),
		"leave recovers on SAME selector after refused leave with 12 gold")
	_check(poor_leave_service.is_claimed() and not poor_leave_service.is_valid()
		and _wallet_exact_int(poor_leave_wallet, 11, 0) and poor_leave_event == original_event
		and poor_leave_service.get_event() == original_event,
		"recovered leave latches exactly one claim and spends nothing")

	# Branch 2c: replay after recovery fails
	var leave_replay := poor_leave_service.choose_with_wallet("leave", {"gold": 0, "scraps": 2})
	_check(_wallet_shape_ok(leave_replay) and leave_replay.get("ok", true) == false
		and leave_replay.get("event_id", "") == "" and leave_replay.get("choice_id", "") == ""
		and _wallet_exact_int(leave_replay.get("wallet"), 0, 2),
		"repeated leave after claim is rejected with unchanged wallet")
	_check(poor_leave_service.is_claimed() and poor_leave_service.get_event() == original_event,
		"replayed leave keeps claim latched and snapshot unchanged")

	# Explicit integer vs JSON-float outcome normalization check (including negative gold).
	var int_event: Dictionary = original_event.duplicate(true)
	int_event["choices"][0]["outcome"] = {"gold": 0, "scraps": 1}
	int_event["choices"][1]["outcome"] = {"gold": -12, "scraps": 2}
	var float_event: Dictionary = original_event.duplicate(true)
	float_event["choices"][0]["outcome"] = {"gold": 0.0, "scraps": 1.0}
	float_event["choices"][1]["outcome"] = {"gold": -12.0, "scraps": 2.0}
	var int_res := RunEventChoice.new(int_event).choose_with_wallet("leave", {"gold": 12, "scraps": 0})
	var float_res := RunEventChoice.new(float_event).choose_with_wallet("leave", {"gold": 12, "scraps": 0})
	_check(int_res == float_res and _wallet_exact_int(float_res.get("wallet"), 0, 2),
		"JSON float outcome values normalize to exact ints matching integer outcomes (including negative gold)")

	# Branch 3: sell_buttons (+18 gold, -1 scrap) from {gold: 4, scraps: 1} -> {gold: 22, scraps: 0}
	var sell_input_event: Dictionary = authored_record.duplicate(true)
	var sell_wallet := {"gold": 4, "scraps": 1}
	var sell_rng := _rng_start(64003)
	var sell_service := RunEventChoice.new(sell_input_event)
	_check(sell_service.is_valid() and not sell_service.is_claimed(),
		"fresh button_trail selector valid before sell_buttons")
	var sell_result := sell_service.choose_with_wallet("sell_buttons", sell_wallet)
	_check(_wallet_shape_ok(sell_result), "sell_buttons choose_with_wallet returns 4-key wallet shape")
	_check(sell_result.get("ok", false) == true, "sell_buttons choose_with_wallet succeeds")
	_check(sell_result.get("event_id", "") == "button_trail", "sell_buttons returns button_trail event_id")
	_check(sell_result.get("choice_id", "") == "sell_buttons", "sell_buttons returns sell_buttons choice_id")
	_check(_wallet_exact_int(sell_result.get("wallet"), 22, 0),
		"sell_buttons settles exact integer wallet {gold: 22, scraps: 0}")
	_check(_wallet_exact_int(sell_wallet, 4, 1), "sell_buttons does not mutate caller input wallet")
	_check(sell_input_event == original_event, "sell_buttons does not mutate caller input event")
	_check(sell_service.get_event() == original_event, "sell_buttons does not mutate internal event snapshot")
	_check(sell_service.is_claimed() and not sell_service.is_valid(),
		"sell_buttons latches claim and marks selector consumed")
	_check(randi() == sell_rng, "sell_buttons wallet settlement spends no global RNG")

	# Insufficient scraps for sell_buttons (zero scraps) rejects without claiming, then follow succeeds on same selector.
	var poor_sell_event: Dictionary = authored_record.duplicate(true)
	var poor_sell_wallet := {"gold": 4, "scraps": 0}
	var poor_sell_rng := _rng_start(64004)
	var poor_sell_service := RunEventChoice.new(poor_sell_event)
	_check(poor_sell_service.is_valid() and not poor_sell_service.is_claimed(),
		"fresh button_trail selector valid before refused sell_buttons")
	var poor_sell_refusal := poor_sell_service.choose_with_wallet("sell_buttons", poor_sell_wallet)
	_check(_wallet_shape_ok(poor_sell_refusal) and poor_sell_refusal.get("ok", true) == false
		and poor_sell_refusal.get("event_id", "") == "" and poor_sell_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_sell_refusal.get("wallet"), 4, 0),
		"sell_buttons without a scrap is refused with exact unchanged wallet")
	_check(poor_sell_service.is_valid() and not poor_sell_service.is_claimed()
		and _wallet_exact_int(poor_sell_wallet, 4, 0)
		and poor_sell_service.get_event() == original_event and poor_sell_event == original_event,
		"refused sell_buttons consumes no visit and keeps both event snapshots")
	(poor_sell_refusal["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(poor_sell_wallet, 4, 0),
		"mutating refused wallet cannot change caller wallet")
	var sell_recovery := poor_sell_service.choose_with_wallet("follow", poor_sell_wallet)
	_check(_wallet_shape_ok(sell_recovery) and sell_recovery.get("ok", false) == true
		and sell_recovery.get("event_id", "") == "button_trail"
		and sell_recovery.get("choice_id", "") == "follow"
		and _wallet_exact_int(sell_recovery.get("wallet"), 4, 1),
		"follow recovers on SAME selector after refused sell_buttons")
	_check(poor_sell_service.is_claimed() and not poor_sell_service.is_valid()
		and _wallet_exact_int(poor_sell_wallet, 4, 0) and poor_sell_event == original_event
		and poor_sell_service.get_event() == original_event,
		"recovered follow latches exactly one claim and spends nothing")
	_check(randi() == poor_sell_rng, "refused sell_buttons and recovery spend no global RNG")

	# Replay rejection after sell_buttons claim.
	var sell_replay := sell_service.choose_with_wallet("sell_buttons", {"gold": 22, "scraps": 0})
	_check(_wallet_shape_ok(sell_replay) and sell_replay.get("ok", true) == false
		and sell_replay.get("event_id", "") == "" and sell_replay.get("choice_id", "") == ""
		and _wallet_exact_int(sell_replay.get("wallet"), 22, 0),
		"repeated sell_buttons after claim is rejected with unchanged wallet")
	_check(sell_service.is_claimed() and sell_service.get_event() == original_event,
		"replayed sell_buttons keeps claim latched and snapshot unchanged")


func _test_loose_seam_wallet_settlement() -> void:
	# The authored Loose Seam record settles through the same one-shot wallet
	# service: mend spends one scrap and pays fifteen gold, bypass salvages one
	# scrap and leaves the gold untouched.
	var matches := _matching("loose_seam")
	_check(matches.size() == 1, "exactly one authored loose_seam record for wallet settlement")
	if matches.size() != 1:
		return
	var authored: Dictionary = matches[0]
	var original: Dictionary = authored.duplicate(true)

	# The file-loaded record keeps its authored identity, both choice IDs and
	# their exact authored texts and outcomes.
	_check(authored.get("id") == "loose_seam"
		and authored.get("title") == "The Loose Seam"
		and authored.get("description") == "A strip of patched ground has come unstitched.",
		"loose_seam keeps its authored id, title and description")
	var authored_choices: Array = authored.get("choices", [])
	_check(authored_choices.size() == 3, "loose_seam keeps exactly its three authored choices")
	var by_id := {}
	for entry in authored_choices:
		if entry is Dictionary:
			by_id[entry.get("id", "")] = entry
	_check(by_id.has("mend") and by_id.has("bypass") and by_id.has("reinforce"), "loose_seam offers all three authored choice IDs")
	if not (by_id.has("mend") and by_id.has("bypass") and by_id.has("reinforce")):
		return
	var mend_choice: Dictionary = by_id["mend"]
	var bypass_choice: Dictionary = by_id["bypass"]
	var reinforce_choice: Dictionary = by_id["reinforce"]
	_check(mend_choice.get("text", "") == "Sew the seam (spend 1 scrap; recover 15 gold)",
		"loose_seam mend keeps its exact authored text")
	_check(bypass_choice.get("text", "") == "Walk around and gather loose thread (+1 scrap)",
		"loose_seam bypass keeps its exact authored text")
	_check(reinforce_choice.get("text", "") == "Reinforce the long tear (spend 2 scraps; gain 32 gold)",
		"loose_seam reinforce keeps its exact authored text")
	var mend_outcome: Variant = mend_choice.get("outcome", {})
	var bypass_outcome: Variant = bypass_choice.get("outcome", {})
	var reinforce_outcome: Variant = reinforce_choice.get("outcome", {})
	_check(mend_outcome is Dictionary and bypass_outcome is Dictionary and reinforce_outcome is Dictionary,
		"loose_seam keeps an authored outcome object on all three choices")
	if mend_outcome is Dictionary and bypass_outcome is Dictionary and reinforce_outcome is Dictionary:
		var mend_values: Dictionary = mend_outcome
		var bypass_values: Dictionary = bypass_outcome
		var reinforce_values: Dictionary = reinforce_outcome
		_check(_is_integral_json_number(mend_values.get("gold"))
			and _is_integral_json_number(mend_values.get("scraps"), true)
			and int(mend_values.get("gold", 0)) == 15 and int(mend_values.get("scraps", 0)) == -1,
			"loose_seam mend keeps its exact authored gold/scraps outcome")
		_check(_is_integral_json_number(bypass_values.get("gold"))
			and _is_integral_json_number(bypass_values.get("scraps"), true)
			and int(bypass_values.get("gold", 0)) == 0 and int(bypass_values.get("scraps", 0)) == 1,
			"loose_seam bypass keeps its exact authored gold/scraps outcome")
		_check(_is_integral_json_number(reinforce_values.get("gold"))
			and _is_integral_json_number(reinforce_values.get("scraps"), true)
			and int(reinforce_values.get("gold", 0)) == 32 and int(reinforce_values.get("scraps", 0)) == -2,
			"loose_seam reinforce keeps its exact authored gold/scraps outcome")

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 64700
	var local_state: int = local_rng.state

	# 1. A fresh visit with one scrap sews the seam: one scrap is spent and
	#    fifteen gold is recovered in a detached wallet.
	var mend_event: Dictionary = authored.duplicate(true)
	var mend_wallet := {"gold": 4, "scraps": 1}
	var mend_rng := _rng_start(64701)
	var mend_service := RunEventChoice.new(mend_event)
	_check(mend_service.is_valid() and not mend_service.is_claimed(),
		"fresh loose_seam selector is valid and unclaimed before mend")
	var mend_result := mend_service.choose_with_wallet("mend", mend_wallet)
	_check(_wallet_shape_ok(mend_result) and mend_result.get("ok", false) == true
		and mend_result.get("event_id", "") == "loose_seam"
		and mend_result.get("choice_id", "") == "mend"
		and _wallet_exact_int(mend_result.get("wallet"), 19, 0),
		"mend spends one scrap and pays fifteen gold")
	_check(_wallet_exact_int(mend_wallet, 4, 1) and mend_event == original
		and mend_service.get_event() == original,
		"mend leaves the caller wallet, the caller event and the selector snapshot unchanged")
	_check(mend_service.is_claimed() and not mend_service.is_valid(),
		"mend latches exactly one claim on its visit")
	_check(randi() == mend_rng, "mend settlement spends no global RNG")

	# 2. A fresh visit that walks around salvages one scrap and keeps the gold.
	var bypass_event: Dictionary = authored.duplicate(true)
	var bypass_wallet := {"gold": 4, "scraps": 1}
	var bypass_rng := _rng_start(64702)
	var bypass_service := RunEventChoice.new(bypass_event)
	_check(bypass_service.is_valid() and not bypass_service.is_claimed(),
		"fresh loose_seam selector is valid and unclaimed before bypass")
	var bypass_result := bypass_service.choose_with_wallet("bypass", bypass_wallet)
	_check(_wallet_shape_ok(bypass_result) and bypass_result.get("ok", false) == true
		and bypass_result.get("event_id", "") == "loose_seam"
		and bypass_result.get("choice_id", "") == "bypass"
		and _wallet_exact_int(bypass_result.get("wallet"), 4, 2),
		"bypass salvages one scrap and keeps the gold")
	_check(_wallet_exact_int(bypass_wallet, 4, 1) and bypass_event == original
		and bypass_service.get_event() == original,
		"bypass leaves the caller wallet, the caller event and the selector snapshot unchanged")
	_check(bypass_service.is_claimed() and not bypass_service.is_valid(),
		"bypass latches exactly one claim on its visit")
	_check(randi() == bypass_rng, "bypass settlement spends no global RNG")

	# Branch 3: reinforce (+32 gold, -2 scraps) from {gold: 4, scraps: 2} -> {gold: 36, scraps: 0}
	var reinforce_input_event: Dictionary = authored.duplicate(true)
	var reinforce_wallet := {"gold": 4, "scraps": 2}
	var reinforce_rng := _rng_start(64708)
	var reinforce_service := RunEventChoice.new(reinforce_input_event)
	_check(reinforce_service.is_valid() and not reinforce_service.is_claimed(),
		"fresh loose_seam selector valid before reinforce")
	var reinforce_result := reinforce_service.choose_with_wallet("reinforce", reinforce_wallet)
	_check(_wallet_shape_ok(reinforce_result) and reinforce_result.get("ok", false) == true
		and reinforce_result.get("event_id", "") == "loose_seam"
		and reinforce_result.get("choice_id", "") == "reinforce"
		and _wallet_exact_int(reinforce_result.get("wallet"), 36, 0),
		"reinforce spends two scraps and pays thirty-two gold")
	_check(_wallet_exact_int(reinforce_wallet, 4, 2) and reinforce_input_event == original
		and reinforce_service.get_event() == original,
		"reinforce leaves the caller wallet, the caller event and the selector snapshot unchanged")
	_check(reinforce_service.is_claimed() and not reinforce_service.is_valid(),
		"reinforce latches exactly one claim on its visit")
	_check(randi() == reinforce_rng, "reinforce settlement spends no global RNG")

	# Insufficient scraps for reinforce (zero scraps) rejects without claiming, then mend succeeds on same selector.
	var poor_reinforce_event: Dictionary = authored.duplicate(true)
	var poor_reinforce_wallet := {"gold": 4, "scraps": 0}
	var poor_reinforce_rng := _rng_start(64709)
	var poor_reinforce_service := RunEventChoice.new(poor_reinforce_event)
	_check(poor_reinforce_service.is_valid() and not poor_reinforce_service.is_claimed(),
		"fresh loose_seam selector valid before refused reinforce")
	var poor_reinforce_refusal := poor_reinforce_service.choose_with_wallet("reinforce", poor_reinforce_wallet)
	_check(_wallet_shape_ok(poor_reinforce_refusal) and poor_reinforce_refusal.get("ok", true) == false
		and poor_reinforce_refusal.get("event_id", "") == "" and poor_reinforce_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_reinforce_refusal.get("wallet"), 4, 0),
		"reinforce without scraps is refused with exact unchanged wallet")
	_check(poor_reinforce_service.is_valid() and not poor_reinforce_service.is_claimed()
		and _wallet_exact_int(poor_reinforce_wallet, 4, 0)
		and poor_reinforce_service.get_event() == original and poor_reinforce_event == original,
		"refused reinforce consumes no visit and keeps both event snapshots")
	(poor_reinforce_refusal["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(poor_reinforce_wallet, 4, 0),
		"mutating refused wallet cannot change caller wallet")
	# One scrap is still insufficient for reinforce (needs 2).
	var poor_reinforce_one_scrap_event: Dictionary = authored.duplicate(true)
	var poor_reinforce_one_scrap_wallet := {"gold": 4, "scraps": 1}
	var poor_reinforce_one_scrap_rng := _rng_start(64710)
	var poor_reinforce_one_scrap_service := RunEventChoice.new(poor_reinforce_one_scrap_event)
	_check(poor_reinforce_one_scrap_service.is_valid() and not poor_reinforce_one_scrap_service.is_claimed(),
		"fresh loose_seam selector valid before refused reinforce with one scrap")
	var poor_reinforce_one_scrap_refusal := poor_reinforce_one_scrap_service.choose_with_wallet("reinforce", poor_reinforce_one_scrap_wallet)
	_check(_wallet_shape_ok(poor_reinforce_one_scrap_refusal) and poor_reinforce_one_scrap_refusal.get("ok", true) == false
		and poor_reinforce_one_scrap_refusal.get("event_id", "") == "" and poor_reinforce_one_scrap_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_reinforce_one_scrap_refusal.get("wallet"), 4, 1),
		"reinforce with only one scrap is refused with exact unchanged wallet")
	_check(poor_reinforce_one_scrap_service.is_valid() and not poor_reinforce_one_scrap_service.is_claimed()
		and _wallet_exact_int(poor_reinforce_one_scrap_wallet, 4, 1)
		and poor_reinforce_one_scrap_service.get_event() == original and poor_reinforce_one_scrap_event == original,
		"refused reinforce with one scrap consumes no visit and keeps both event snapshots")
	var mend_after_poor_reinforce := poor_reinforce_one_scrap_service.choose_with_wallet("mend", poor_reinforce_one_scrap_wallet)
	_check(_wallet_shape_ok(mend_after_poor_reinforce) and mend_after_poor_reinforce.get("ok", false) == true
		and mend_after_poor_reinforce.get("event_id", "") == "loose_seam"
		and mend_after_poor_reinforce.get("choice_id", "") == "mend"
		and _wallet_exact_int(mend_after_poor_reinforce.get("wallet"), 19, 0),
		"mend recovers on SAME selector after refused reinforce")
	_check(poor_reinforce_one_scrap_service.is_claimed() and not poor_reinforce_one_scrap_service.is_valid()
		and _wallet_exact_int(poor_reinforce_one_scrap_wallet, 4, 1) and poor_reinforce_one_scrap_event == original
		and poor_reinforce_one_scrap_service.get_event() == original,
		"recovered mend latches exactly one claim and spends nothing")
	_check(randi() == poor_reinforce_one_scrap_rng, "refused reinforce with one scrap and recovery spend no global RNG")

	# Replay rejection after reinforce claim.
	var reinforce_replay := reinforce_service.choose_with_wallet("reinforce", {"gold": 36, "scraps": 0})
	_check(_wallet_shape_ok(reinforce_replay) and reinforce_replay.get("ok", true) == false
		and reinforce_replay.get("event_id", "") == "" and reinforce_replay.get("choice_id", "") == ""
		and _wallet_exact_int(reinforce_replay.get("wallet"), 36, 0),
		"repeated reinforce after claim is rejected with unchanged wallet")
	_check(reinforce_service.is_claimed() and reinforce_service.get_event() == original,
		"replayed reinforce keeps claim latched and snapshot unchanged")

	# 3. Without a scrap the mend is refused without claiming or spending
	#    anything, and the same visit still offers the free salvage.
	var poor_event: Dictionary = authored.duplicate(true)
	var poor_wallet := {"gold": 4, "scraps": 0}
	var poor_rng := _rng_start(64703)
	var poor_service := RunEventChoice.new(poor_event)
	_check(poor_service.is_valid() and not poor_service.is_claimed(),
		"fresh loose_seam selector is valid and unclaimed before the refused mend")
	var refusal := poor_service.choose_with_wallet("mend", poor_wallet)
	_check(_wallet_shape_ok(refusal) and refusal.get("ok", true) == false
		and refusal.get("event_id", "") == "" and refusal.get("choice_id", "") == ""
		and _wallet_exact_int(refusal.get("wallet"), 4, 0),
		"a mend without a scrap is refused with the exact unchanged wallet")
	_check(poor_service.is_valid() and not poor_service.is_claimed()
		and _wallet_exact_int(poor_wallet, 4, 0)
		and poor_service.get_event() == original and poor_event == original,
		"the refused mend consumes no visit and keeps both event snapshots")
	(refusal["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(poor_wallet, 4, 0),
		"mutating the refused wallet cannot change the caller wallet")
	var salvage := poor_service.choose_with_wallet("bypass", poor_wallet)
	_check(_wallet_shape_ok(salvage) and salvage.get("ok", false) == true
		and salvage.get("event_id", "") == "loose_seam"
		and salvage.get("choice_id", "") == "bypass"
		and _wallet_exact_int(salvage.get("wallet"), 4, 1),
		"bypass salvages one scrap on the SAME visit after the refused mend")
	_check(_wallet_exact_int(poor_wallet, 4, 0) and poor_event == original
		and poor_service.get_event() == original,
		"the salvaging bypass leaves the caller wallet and event unchanged")
	_check(poor_service.is_claimed() and not poor_service.is_valid(),
		"the salvage latches exactly one claim on the visit")
	_check(randi() == poor_rng, "the refused mend and the salvage spend no global RNG")

	# 4. One charge only: a claimed visit pays or debits nothing a second time.
	for replay_choice in ["mend", "bypass", "reinforce"]:
		var replay := mend_service.choose_with_wallet(replay_choice, {"gold": 19, "scraps": 0})
		_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
			and replay.get("event_id", "") == "" and replay.get("choice_id", "") == ""
			and _wallet_exact_int(replay.get("wallet"), 19, 0),
			"a repeated loose_seam choice after the claim is rejected with the unchanged wallet: "
				+ replay_choice)
	_check(mend_service.is_claimed() and mend_service.get_event() == original,
		"the replayed visit keeps its claim latched and its snapshot unchanged")
	(mend_result["wallet"] as Dictionary)["gold"] = 999
	(mend_result["wallet"] as Dictionary)["scraps"] = 999
	_check(_wallet_exact_int(mend_wallet, 4, 1) and mend_service.get_event() == original,
		"mutating the settled wallet cannot change the caller wallet or the snapshot")

	# 5. Unknown choices and malformed wallets fail closed and leave the visit
	#    claimable.
	var reject_service := RunEventChoice.new(authored.duplicate(true))
	var valid_wallet := {"gold": 4, "scraps": 1}
	var bad_choices: Array = ["", "   ", "unoffered", "Mend", "mend ", null, 7, ["mend"], {"id": "mend"}]
	for bad_choice in bad_choices:
		var rng_expected := _rng_start(64704)
		var rejected := reject_service.choose_with_wallet(bad_choice, valid_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false
			and rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == ""
			and _wallet_exact_int(rejected.get("wallet"), 4, 1),
			"loose_seam rejects an illegal choice ID: " + str(bad_choice))
		_check(not reject_service.is_claimed() and reject_service.is_valid()
			and _wallet_exact_int(valid_wallet, 4, 1),
			"an illegal choice ID consumes no visit and spends nothing: " + str(bad_choice))
		_check(reject_service.get_event() == original,
			"an illegal choice ID leaves the selector snapshot unchanged: " + str(bad_choice))
		_check(randi() == rng_expected, "an illegal choice ID spends no RNG: " + str(bad_choice))

	var bad_wallets: Array[Dictionary] = [
		{"gold": -1, "scraps": 1},
		{"gold": 4, "scraps": -1},
		{"gold": 4.5, "scraps": 1},
		{"gold": "4", "scraps": 1},
		{"gold": true, "scraps": 1},
		{"gold": 4},
		{"scraps": 1},
		{"gold": 4, "scraps": 1, "hp": 5},
	]
	for bad_wallet in bad_wallets:
		var rng_expected := _rng_start(64705)
		var wallet_before: Dictionary = (bad_wallet as Dictionary).duplicate(true)
		var rejected := reject_service.choose_with_wallet("mend", bad_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false
			and rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == ""
			and (rejected.get("wallet") as Dictionary).is_empty(),
			"loose_seam rejects an invalid wallet: " + str(bad_wallet))
		_check(bad_wallet == wallet_before,
			"an invalid wallet rejection never mutates the caller wallet: " + str(bad_wallet))
		_check(not reject_service.is_claimed() and reject_service.is_valid(),
			"an invalid wallet consumes no visit: " + str(bad_wallet))
		_check(randi() == rng_expected, "an invalid wallet spends no RNG: " + str(bad_wallet))

	for bad_value in [null, "4", 4, [4, 1]]:
		var rng_expected := _rng_start(64706)
		var rejected := reject_service.choose_with_wallet("mend", bad_value)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false
			and (rejected.get("wallet") as Dictionary).is_empty(),
			"loose_seam rejects a non-dictionary wallet: " + str(bad_value))
		_check(not reject_service.is_claimed() and reject_service.is_valid(),
			"a non-dictionary wallet consumes no visit: " + str(bad_value))
		_check(randi() == rng_expected, "a non-dictionary wallet spends no RNG: " + str(bad_value))

	# A scrap balance that cannot absorb the salvage is refused as well.
	var overflow_wallet := {"gold": 4, "scraps": RunEventChoice.MAX_INT}
	var overflow := reject_service.choose_with_wallet("bypass", overflow_wallet)
	_check(_wallet_shape_ok(overflow) and overflow.get("ok", true) == false
		and overflow.get("event_id", "") == "" and overflow.get("choice_id", "") == ""
		and _wallet_exact_int(overflow.get("wallet"), 4, RunEventChoice.MAX_INT),
		"a max-int scrap balance cannot settle the salvage")
	_check(not reject_service.is_claimed() and reject_service.is_valid()
		and _wallet_exact_int(overflow_wallet, 4, RunEventChoice.MAX_INT)
		and reject_service.get_event() == original,
		"the overflow refusal consumes no visit and keeps both snapshots")

	# 6. The same visit still settles an affordable authored choice afterwards.
	var recovered := reject_service.choose_with_wallet("mend", valid_wallet)
	_check(_wallet_shape_ok(recovered) and recovered.get("ok", false) == true
		and recovered.get("event_id", "") == "loose_seam"
		and recovered.get("choice_id", "") == "mend"
		and _wallet_exact_int(recovered.get("wallet"), 19, 0),
		"loose_seam settles the mend on the same visit after rejected attempts")
	_check(reject_service.is_claimed() and not reject_service.is_valid()
		and _wallet_exact_int(valid_wallet, 4, 1) and reject_service.get_event() == original,
		"the recovered visit latches exactly one claim and spends nothing")

	# 7. Two independent fresh visits settle the same authored choice identically.
	var traces: Array = []
	for attempt in range(2):
		var fresh := RunEventChoice.new(authored.duplicate(true))
		traces.append(fresh.choose_with_wallet("bypass", {"gold": 4, "scraps": 1}))
	_check(traces.size() == 2 and traces[0] == traces[1]
		and _wallet_exact_int((traces[0] as Dictionary).get("wallet"), 4, 2),
		"two fresh loose_seam visits settle identical results")
	_check(local_rng.state == local_state, "loose_seam settlement spends no local seeded RNG")


func _test_thimble_well_wallet_settlement() -> void:
	var matches := _matching("thimble_well")
	_check(matches.size() == 1, "exactly one thimble_well in catalog for wallet settlement")
	if matches.size() != 1:
		return
	var authored_record: Dictionary = matches[0]
	var original_event: Dictionary = authored_record.duplicate(true)

	_check(authored_record.get("id") == "thimble_well"
		and authored_record.get("title") == "The Thimble Well"
		and authored_record.get("description") == "A silver thimble rests beside a dry stone well.",
		"thimble_well preserves authored id, title, description")
	var authored_choices: Array = authored_record.get("choices", [])
	_check(authored_choices.size() == 3, "thimble_well preserves exactly three authored choices")

	# Branch 1: listen (+0 gold, +1 scrap) from {gold: 7, scraps: 0} -> {gold: 7, scraps: 1}
	var listen_input_event: Dictionary = authored_record.duplicate(true)
	var listen_wallet := {"gold": 7, "scraps": 0}
	var listen_wallet_before: Dictionary = listen_wallet.duplicate(true)
	var listen_rng := _rng_start(64801)
	var listen_service := RunEventChoice.new(listen_input_event)
	_check(listen_service.is_valid() and not listen_service.is_claimed(),
		"fresh thimble_well selector valid and unclaimed before listen")
	var listen_result := listen_service.choose_with_wallet("listen", listen_wallet)
	_check(_wallet_shape_ok(listen_result), "listen returns 4-key wallet shape")
	_check(listen_result.get("ok", false) == true, "listen choose_with_wallet succeeds")
	_check(listen_result.get("event_id", "") == "thimble_well", "listen returns thimble_well event_id")
	_check(listen_result.get("choice_id", "") == "listen", "listen returns listen choice_id")
	_check(_wallet_exact_int(listen_result.get("wallet"), 7, 1),
		"listen settles exact integer wallet {gold: 7, scraps: 1}")
	_check(_wallet_exact_int(listen_wallet, 7, 0) and listen_wallet == listen_wallet_before,
		"listen does not mutate caller input wallet")
	_check(listen_input_event == original_event, "listen does not mutate caller input event")
	_check(listen_service.get_event() == original_event, "listen does not mutate internal snapshot")
	_check(listen_service.is_claimed() and not listen_service.is_valid(),
		"listen latches claim and marks selector consumed")
	_check(randi() == listen_rng, "listen wallet settlement spends no global RNG")

	(listen_result["wallet"] as Dictionary)["gold"] = 999
	(listen_result["wallet"] as Dictionary)["scraps"] = 999
	_check(_wallet_exact_int(listen_wallet, 7, 0), "mutating listen result wallet does not mutate caller wallet")

	var listen_replay := listen_service.choose_with_wallet("depart", {"gold": 7, "scraps": 1})
	_check(_wallet_shape_ok(listen_replay) and listen_replay.get("ok", true) == false,
		"replay after listen claim is rejected")
	_check(listen_replay.get("event_id", "") == "" and listen_replay.get("choice_id", "") == "",
		"rejected replay after listen returns empty IDs")
	_check(_wallet_exact_int(listen_replay.get("wallet"), 7, 1),
		"rejected replay after listen returns unchanged valid wallet")
	var listen_legacy_replay := listen_service.choose("listen")
	_check(_shape_ok(listen_legacy_replay) and listen_legacy_replay.get("ok", true) == false,
		"legacy choose rejects after listen claim")
	_check(listen_service.is_claimed() and not listen_service.is_valid(),
		"listen claim remains latched after replays")

	# Branch 2: depart (+5 gold, +0 scraps) from {gold: 7, scraps: 0} -> {gold: 12, scraps: 0}
	var depart_input_event: Dictionary = authored_record.duplicate(true)
	var depart_wallet := {"gold": 7, "scraps": 0}
	var depart_wallet_before: Dictionary = depart_wallet.duplicate(true)
	var depart_rng := _rng_start(64802)
	var depart_service := RunEventChoice.new(depart_input_event)
	_check(depart_service.is_valid() and not depart_service.is_claimed(),
		"fresh thimble_well selector valid and unclaimed before depart")
	var depart_result := depart_service.choose_with_wallet("depart", depart_wallet)
	_check(_wallet_shape_ok(depart_result), "depart returns 4-key wallet shape")
	_check(depart_result.get("ok", false) == true, "depart choose_with_wallet succeeds")
	_check(depart_result.get("event_id", "") == "thimble_well", "depart returns thimble_well event_id")
	_check(depart_result.get("choice_id", "") == "depart", "depart returns depart choice_id")
	_check(_wallet_exact_int(depart_result.get("wallet"), 12, 0),
		"depart settles exact integer wallet {gold: 12, scraps: 0}")
	_check(_wallet_exact_int(depart_wallet, 7, 0) and depart_wallet == depart_wallet_before,
		"depart does not mutate caller input wallet")
	_check(depart_input_event == original_event, "depart does not mutate caller input event")
	_check(depart_service.get_event() == original_event, "depart does not mutate internal snapshot")
	_check(depart_service.is_claimed() and not depart_service.is_valid(),
		"depart latches claim and marks selector consumed")
	_check(randi() == depart_rng, "depart wallet settlement spends no global RNG")

	(depart_result["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(depart_wallet, 7, 0), "mutating depart result wallet does not mutate caller wallet")

	var depart_replay := depart_service.choose_with_wallet("listen", {"gold": 12, "scraps": 0})
	_check(_wallet_shape_ok(depart_replay) and depart_replay.get("ok", true) == false
		and _wallet_exact_int(depart_replay.get("wallet"), 12, 0),
		"replay after depart claim is rejected with unchanged wallet")

	# Branch 3: lower_spool (+18 gold, -1 scrap) from {gold: 4, scraps: 1} -> {gold: 22, scraps: 0}
	var lower_input_event: Dictionary = authored_record.duplicate(true)
	var lower_wallet := {"gold": 4, "scraps": 1}
	var lower_wallet_before: Dictionary = lower_wallet.duplicate(true)
	var lower_rng := _rng_start(64803)
	var lower_service := RunEventChoice.new(lower_input_event)
	_check(lower_service.is_valid() and not lower_service.is_claimed(),
		"fresh thimble_well selector valid and unclaimed before lower_spool")
	var lower_result := lower_service.choose_with_wallet("lower_spool", lower_wallet)
	_check(_wallet_shape_ok(lower_result), "lower_spool returns 4-key wallet shape")
	_check(lower_result.get("ok", false) == true, "lower_spool choose_with_wallet succeeds")
	_check(lower_result.get("event_id", "") == "thimble_well", "lower_spool returns thimble_well event_id")
	_check(lower_result.get("choice_id", "") == "lower_spool", "lower_spool returns lower_spool choice_id")
	_check(_wallet_exact_int(lower_result.get("wallet"), 22, 0),
		"lower_spool settles exact integer wallet {gold: 22, scraps: 0}")
	_check(_wallet_exact_int(lower_wallet, 4, 1) and lower_wallet == lower_wallet_before,
		"lower_spool does not mutate caller input wallet")
	_check(lower_input_event == original_event, "lower_spool does not mutate caller input event")
	_check(lower_service.get_event() == original_event, "lower_spool does not mutate internal snapshot")
	_check(lower_service.is_claimed() and not lower_service.is_valid(),
		"lower_spool latches claim and marks selector consumed")
	_check(randi() == lower_rng, "lower_spool wallet settlement spends no global RNG")

	(lower_result["wallet"] as Dictionary)["gold"] = 999
	(lower_result["wallet"] as Dictionary)["scraps"] = 999
	_check(_wallet_exact_int(lower_wallet, 4, 1), "mutating lower_spool result wallet does not mutate caller wallet")

	var lower_replay := lower_service.choose_with_wallet("listen", {"gold": 22, "scraps": 0})
	_check(_wallet_shape_ok(lower_replay) and lower_replay.get("ok", true) == false
		and _wallet_exact_int(lower_replay.get("wallet"), 22, 0),
		"replay after lower_spool claim is rejected with unchanged wallet")

	# Insufficient scraps for lower_spool (zero scraps) rejects without claiming, then listen succeeds on same selector.
	var poor_lower_event: Dictionary = authored_record.duplicate(true)
	var poor_lower_wallet := {"gold": 4, "scraps": 0}
	var poor_lower_wallet_before: Dictionary = poor_lower_wallet.duplicate(true)
	var poor_lower_rng := _rng_start(64804)
	var poor_lower_service := RunEventChoice.new(poor_lower_event)
	_check(poor_lower_service.is_valid() and not poor_lower_service.is_claimed(),
		"fresh thimble_well selector valid before refused lower_spool")
	var poor_lower_refusal := poor_lower_service.choose_with_wallet("lower_spool", poor_lower_wallet)
	_check(_wallet_shape_ok(poor_lower_refusal) and poor_lower_refusal.get("ok", true) == false
		and poor_lower_refusal.get("event_id", "") == "" and poor_lower_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_lower_refusal.get("wallet"), 4, 0),
		"lower_spool without a scrap is refused with exact unchanged wallet")
	_check(poor_lower_service.is_valid() and not poor_lower_service.is_claimed()
		and _wallet_exact_int(poor_lower_wallet, 4, 0) and poor_lower_wallet == poor_lower_wallet_before
		and poor_lower_service.get_event() == original_event and poor_lower_event == original_event,
		"refused lower_spool consumes no visit and keeps both event snapshots")
	(poor_lower_refusal["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(poor_lower_wallet, 4, 0),
		"mutating refused wallet cannot change caller wallet")
	var listen_recovery := poor_lower_service.choose_with_wallet("listen", poor_lower_wallet)
	_check(_wallet_shape_ok(listen_recovery) and listen_recovery.get("ok", false) == true
		and listen_recovery.get("event_id", "") == "thimble_well"
		and listen_recovery.get("choice_id", "") == "listen"
		and _wallet_exact_int(listen_recovery.get("wallet"), 4, 1),
		"listen recovers on SAME selector after refused lower_spool")
	_check(poor_lower_service.is_claimed() and not poor_lower_service.is_valid()
		and _wallet_exact_int(poor_lower_wallet, 4, 0) and poor_lower_event == original_event
		and poor_lower_service.get_event() == original_event,
		"recovered listen latches exactly one claim and spends nothing")
	_check(randi() == poor_lower_rng, "refused lower_spool and recovery spend no global RNG")

	# Post-success replay rejection on the same selector after recovery.
	var poor_listen_replay := poor_lower_service.choose_with_wallet("listen", {"gold": 4, "scraps": 1})
	_check(_wallet_shape_ok(poor_listen_replay) and poor_listen_replay.get("ok", true) == false
		and poor_listen_replay.get("event_id", "") == "" and poor_listen_replay.get("choice_id", "") == ""
		and _wallet_exact_int(poor_listen_replay.get("wallet"), 4, 1),
		"replay after recovered listen is rejected with unchanged wallet")
	_check(poor_lower_service.is_claimed() and not poor_lower_service.is_valid()
		and poor_lower_service.get_event() == original_event,
		"replayed listen keeps claim latched and snapshot unchanged")

	var trace_a := RunEventChoice.new(authored_record.duplicate(true)).choose_with_wallet("listen", {"gold": 7, "scraps": 0})
	var trace_b := RunEventChoice.new(authored_record.duplicate(true)).choose_with_wallet("listen", {"gold": 7, "scraps": 0})
	_check(trace_a == trace_b and _wallet_exact_int(trace_a.get("wallet"), 7, 1),
		"independent fresh thimble_well selectors produce identical traces")


func _test_frayed_signpost_wallet_settlement() -> void:
	var matches := _matching("frayed_signpost")
	_check(matches.size() == 1, "exactly one frayed_signpost in catalog for wallet settlement")
	if matches.size() != 1:
		return
	var authored_record: Dictionary = matches[0]
	var original_event: Dictionary = authored_record.duplicate(true)

	_check(authored_record.get("id") == "frayed_signpost"
		and authored_record.get("title") == "The Frayed Signpost"
		and authored_record.get("description") == "Three cloth arrows flap from a crooked signpost.",
		"frayed_signpost preserves authored id, title, description")
	var authored_choices: Array = authored_record.get("choices", [])
	_check(authored_choices.size() >= 2 and authored_choices.size() <= 3, "frayed_signpost has allowed 2-3 choices")

	# 1. Fresh selector: "read" with {gold: 7, scraps: 2} -> {gold: 17, scraps: 1}
	var read_input_event: Dictionary = authored_record.duplicate(true)
	var read_wallet := {"gold": 7, "scraps": 2}
	var read_wallet_before: Dictionary = read_wallet.duplicate(true)
	var read_rng := _rng_start(64901)
	var read_service := RunEventChoice.new(read_input_event)
	_check(read_service.is_valid() and not read_service.is_claimed(),
		"fresh frayed_signpost selector valid and unclaimed before read")
	var read_result := read_service.choose_with_wallet("read", read_wallet)
	_check(_wallet_shape_ok(read_result), "read returns 4-key wallet shape")
	_check(read_result.get("ok", false) == true, "read choose_with_wallet succeeds")
	_check(read_result.get("event_id", "") == "frayed_signpost", "read returns frayed_signpost event_id")
	_check(read_result.get("choice_id", "") == "read", "read returns read choice_id")
	_check(_wallet_exact_int(read_result.get("wallet"), 17, 1),
		"read settles exact integer wallet {gold: 17, scraps: 1}")
	_check(_wallet_exact_int(read_wallet, 7, 2) and read_wallet == read_wallet_before,
		"read does not mutate caller input wallet")
	_check(read_input_event == original_event, "read does not mutate caller input event")
	_check(read_service.get_event() == original_event, "read does not mutate internal snapshot")
	_check(read_service.is_claimed() and not read_service.is_valid(),
		"read latches claim and marks selector consumed")
	_check(randi() == read_rng, "read wallet settlement spends no global RNG")

	(read_result["wallet"] as Dictionary)["gold"] = 999
	(read_result["wallet"] as Dictionary)["scraps"] = 999
	_check(_wallet_exact_int(read_wallet, 7, 2), "mutating read result wallet does not mutate caller wallet")

	for replay_id in ["read", "choose"]:
		var replay := read_service.choose_with_wallet(replay_id, {"gold": 17, "scraps": 1})
		_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
			and replay.get("event_id", "") == "" and replay.get("choice_id", "") == ""
			and _wallet_exact_int(replay.get("wallet"), 17, 1),
			"replay after read rejected with unchanged wallet: " + replay_id)
	_check(read_service.is_claimed() and not read_service.is_valid(),
		"read claim remains latched after replays")

	# 2. Fresh selector with {gold: 7, scraps: 0}:
	#    Unaffordable "read" rejects, remains unclaimed, leaves wallet alone.
	#    Then "choose" succeeds on THAT SAME selector to {gold: 7, scraps: 1}.
	#    Then replay of either ID fails.
	var same_selector_event: Dictionary = authored_record.duplicate(true)
	var zero_wallet := {"gold": 7, "scraps": 0}
	var zero_wallet_before: Dictionary = zero_wallet.duplicate(true)
	var flow_rng := _rng_start(64902)
	var same_service := RunEventChoice.new(same_selector_event)
	_check(same_service.is_valid() and not same_service.is_claimed(),
		"fresh frayed_signpost selector valid and unclaimed before flow")

	# Step 2a: Unaffordable read rejection
	var denied := same_service.choose_with_wallet("read", zero_wallet)
	_check(_wallet_shape_ok(denied) and denied.get("ok", true) == false,
		"unaffordable read with zero scraps is rejected")
	_check(denied.get("event_id", "") == "" and denied.get("choice_id", "") == ""
		and _wallet_exact_int(denied.get("wallet"), 7, 0),
		"unaffordable read returns empty IDs and detached unchanged valid wallet")
	_check(_wallet_exact_int(zero_wallet, 7, 0) and zero_wallet == zero_wallet_before,
		"unaffordable read does not mutate caller input wallet")
	_check((denied.get("wallet") as Dictionary).get("scraps", 0) >= 0,
		"wallet scrap balance never becomes negative")
	_check(same_service.is_valid() and not same_service.is_claimed(),
		"unaffordable read leaves selector valid and unclaimed")
	_check(same_selector_event == original_event and same_service.get_event() == original_event,
		"unaffordable read leaves caller event and selector snapshot intact")

	(denied["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(zero_wallet, 7, 0),
		"mutating denied wallet does not mutate caller wallet")

	# Step 2b: Choose on THAT SAME selector succeeds
	var choose_result := same_service.choose_with_wallet("choose", zero_wallet)
	_check(_wallet_shape_ok(choose_result) and choose_result.get("ok", false) == true,
		"choose on SAME selector succeeds after unaffordable read")
	_check(choose_result.get("event_id", "") == "frayed_signpost",
		"choose returns frayed_signpost event_id")
	_check(choose_result.get("choice_id", "") == "choose",
		"choose returns choose choice_id")
	_check(_wallet_exact_int(choose_result.get("wallet"), 7, 1),
		"choose settles exact integer wallet {gold: 7, scraps: 1}")
	_check(_wallet_exact_int(zero_wallet, 7, 0) and zero_wallet == zero_wallet_before,
		"choose does not mutate caller input wallet")
	_check(same_selector_event == original_event and same_service.get_event() == original_event,
		"choose preserves caller event and internal snapshot")
	_check(same_service.is_claimed() and not same_service.is_valid(),
		"choose latches claim and marks selector consumed")

	(choose_result["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(zero_wallet, 7, 0),
		"mutating choose result wallet does not mutate caller wallet")

	# Step 2c: Replay of either ID fails
	for replay_id in ["read", "choose"]:
		var replay := same_service.choose_with_wallet(replay_id, {"gold": 7, "scraps": 1})
		_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
			and replay.get("event_id", "") == "" and replay.get("choice_id", "") == ""
			and _wallet_exact_int(replay.get("wallet"), 7, 1),
			"replay after choose rejected with unchanged wallet: " + replay_id)
	var legacy_replay := same_service.choose("choose")
	_check(_shape_ok(legacy_replay) and legacy_replay.get("ok", true) == false,
		"legacy choose rejected after choose claim")
	_check(same_service.is_claimed() and not same_service.is_valid(),
		"selector remains claimed and consumed after replay attempts")
	_check(randi() == flow_rng, "complete unaffordable read -> choose -> replay flow spends no global RNG")

	# 3. Two independent fresh instances produce identical traces
	var trace_a := RunEventChoice.new(authored_record.duplicate(true)).choose_with_wallet("read", {"gold": 7, "scraps": 2})
	var trace_b := RunEventChoice.new(authored_record.duplicate(true)).choose_with_wallet("read", {"gold": 7, "scraps": 2})
	_check(trace_a == trace_b and _wallet_exact_int(trace_a.get("wallet"), 17, 1),
		"independent fresh frayed_signpost selectors produce identical traces")

	# 4. Verified new sell_arrowwork entry: text, outcome, and wallet settlement.
	# Check authored JSON records the new choice correctly.
	var by_id := {}
	for choice in authored_choices:
		if choice is Dictionary:
			by_id[choice.get("id", "")] = choice
	_check(by_id.has("sell_arrowwork"), "new sell_arrowwork choice present in parsed JSON")
	if by_id.has("sell_arrowwork"):
		var sell_choice: Dictionary = by_id["sell_arrowwork"]
		_check(sell_choice.get("text", "") == "Sell the stitched arrowwork (spend 2 scraps; gain 26 gold)",
			"sell_arrowwork exact authored text")
		_check(sell_choice.get("outcome", {}).get("gold", 0) == 26
			and sell_choice.get("outcome", {}).get("scraps", 0) == -2,
			"sell_arrowwork exact authored signed outcome")

	# Affordable sell_arrowwork: {gold: 7, scraps: 2} -> {gold: 33, scraps: 0}
	var sell_input_event: Dictionary = authored_record.duplicate(true)
	var sell_wallet := {"gold": 7, "scraps": 2}
	var sell_wallet_before: Dictionary = sell_wallet.duplicate(true)
	var sell_rng := _rng_start(64903)
	var sell_service := RunEventChoice.new(sell_input_event)
	_check(sell_service.is_valid() and not sell_service.is_claimed(),
		"fresh frayed_signpost selector valid before sell_arrowwork")
	var sell_result := sell_service.choose_with_wallet("sell_arrowwork", sell_wallet)
	_check(_wallet_shape_ok(sell_result), "sell_arrowwork returns 4-key wallet shape")
	_check(sell_result.get("ok", false) == true, "sell_arrowwork choose_with_wallet succeeds")
	_check(sell_result.get("event_id", "") == "frayed_signpost", "sell_arrowwork event_id")
	_check(sell_result.get("choice_id", "") == "sell_arrowwork", "sell_arrowwork choice_id")
	_check(_wallet_exact_int(sell_result.get("wallet"), 33, 0),
		"sell_arrowwork settles exact wallet {gold: 33, scraps: 0}")
	_check(_wallet_exact_int(sell_wallet, 7, 2) and sell_wallet == sell_wallet_before,
		"sell_arrowwork does not mutate caller input wallet")
	_check(sell_service.is_claimed() and not sell_service.is_valid(),
		"sell_arrowwork latches exactly one claim")
	_check(randi() == sell_rng, "sell_arrowwork settlement spends no global RNG")

	# Replay after successful sell_arrowwork claim fails.
	var sell_replay := sell_service.choose_with_wallet("sell_arrowwork", {"gold": 33, "scraps": 0})
	_check(_wallet_shape_ok(sell_replay) and sell_replay.get("ok", true) == false
		and sell_replay.get("event_id", "") == "" and sell_replay.get("choice_id", "") == ""
		and _wallet_exact_int(sell_replay.get("wallet"), 33, 0),
		"replay after sell_arrowwork claim rejected with unchanged wallet")

	# 5. Failed trade: with 0 or 1 scrap, sell_arrowwork rejected; then existing affordable choice succeeds.
	# Zero scraps: sell_arrowwork refused; then choose succeeds on same selector.
	var zero_scrap_service := RunEventChoice.new(authored_record.duplicate(true))
	var zero_scrap_wallet := {"gold": 7, "scraps": 0}
	var zero_scrap_rng := _rng_start(64904)
	_check(zero_scrap_service.is_valid() and not zero_scrap_service.is_claimed(),
		"fresh selector before refused sell_arrowwork with zero scraps")
	var zero_refusal := zero_scrap_service.choose_with_wallet("sell_arrowwork", zero_scrap_wallet)
	_check(_wallet_shape_ok(zero_refusal) and zero_refusal.get("ok", true) == false
		and zero_refusal.get("event_id", "") == "" and zero_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(zero_refusal.get("wallet"), 7, 0),
		"sell_arrowwork with zero scraps refused unchanged wallet")
	_check(zero_scrap_service.is_valid() and not zero_scrap_service.is_claimed(),
		"refused sell_arrowwork leaves selector unclaimed")
	var zero_recovery := zero_scrap_service.choose_with_wallet("choose", zero_scrap_wallet)
	_check(_wallet_shape_ok(zero_recovery) and zero_recovery.get("ok", false) == true
		and zero_recovery.get("event_id", "") == "frayed_signpost"
		and zero_recovery.get("choice_id", "") == "choose"
		and _wallet_exact_int(zero_recovery.get("wallet"), 7, 1),
		"choose succeeds on same selector after refused sell_arrowwork (0 scraps)")
	_check(zero_scrap_service.is_claimed() and not zero_scrap_service.is_valid(),
		"recovered choose latches claim after refused sell_arrowwork")
	_check(randi() == zero_scrap_rng, "refused sell_arrowwork and recovery spend no RNG")

	# One scrap (still insufficient, needs 2): refused; then read succeeds on same selector.
	var one_scrap_service := RunEventChoice.new(authored_record.duplicate(true))
	var one_scrap_wallet := {"gold": 7, "scraps": 1}
	var one_scrap_rng := _rng_start(64905)
	var one_refusal := one_scrap_service.choose_with_wallet("sell_arrowwork", one_scrap_wallet)
	_check(_wallet_shape_ok(one_refusal) and one_refusal.get("ok", true) == false
		and one_refusal.get("event_id", "") == "" and one_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(one_refusal.get("wallet"), 7, 1),
		"sell_arrowwork with one scrap refused unchanged wallet")
	_check(one_scrap_service.is_valid() and not one_scrap_service.is_claimed(),
		"refused sell_arrowwork with one scrap leaves selector unclaimed")
	var one_recovery := one_scrap_service.choose_with_wallet("read", one_scrap_wallet)
	_check(_wallet_shape_ok(one_recovery) and one_recovery.get("ok", false) == true
		and one_recovery.get("event_id", "") == "frayed_signpost"
		and one_recovery.get("choice_id", "") == "read"
		and _wallet_exact_int(one_recovery.get("wallet"), 17, 0),
		"read succeeds on same selector after refused sell_arrowwork (1 scrap)")
	_check(one_scrap_service.is_claimed() and not one_scrap_service.is_valid(),
		"recovered read latches claim after refused sell_arrowwork")
	_check(randi() == one_scrap_rng, "refused sell_arrowwork with one scrap and recovery spend no RNG")


func _test_needle_gate_wallet_settlement() -> void:
	var matches := _matching("needle_gate")
	_check(matches.size() == 1, "exactly one needle_gate for wallet settlement")
	if matches.size() != 1:
		return
	var authored: Dictionary = matches[0]
	var original: Dictionary = authored.duplicate(true)

	# The authored debit is affordable: eight gold and one scrap become 20 and zero.
	var caller_event: Dictionary = authored.duplicate(true)
	var wallet := {"gold": 8, "scraps": 1}
	var expected_rng := _rng_start(64501)
	var gate := RunEventChoice.new(caller_event)
	_check(gate.is_valid() and not gate.is_claimed(), "Needle Gate has a fresh usable selector")
	var result := gate.choose_with_wallet("examine", wallet)
	_check(_wallet_shape_ok(result) and result.get("ok") == true
		and result.get("event_id") == "needle_gate" and result.get("choice_id") == "examine"
		and _wallet_exact_int(result.get("wallet"), 20, 0),
		"examine returns exact four-key successful trade and IDs")
	_check(_wallet_exact_int(wallet, 8, 1) and caller_event == original and gate.get_event() == original,
		"examine preserves caller event/wallet and detached selector snapshot")
	_check(gate.is_claimed() and not gate.is_valid(), "successful trade consumes exactly one claim")
	var replay := gate.choose_with_wallet("pass", {"gold": 20, "scraps": 0})
	_check(_wallet_shape_ok(replay) and replay.get("ok") == false
		and replay.get("event_id") == "" and replay.get("choice_id") == ""
		and _wallet_exact_int(replay.get("wallet"), 20, 0),
		"trade replay rejected with exact IDs and unchanged wallet")
	(result["wallet"] as Dictionary)["gold"] = 999
	(replay["wallet"] as Dictionary)["scraps"] = 999
	_check(_wallet_exact_int(wallet, 8, 1) and gate.get_event() == original,
		"mutated successful/rejected result wallets cannot change caller or selector")
	_check(gate.is_claimed() and not gate.is_valid() and randi() == expected_rng,
		"trade and replay preserve claim state and global RNG")

	# Branch 2: cut_bindings (+28 gold, -2 scraps) from {gold: 4, scraps: 2} -> {gold: 32, scraps: 0}
	var cut_input_event: Dictionary = authored.duplicate(true)
	var cut_wallet := {"gold": 4, "scraps": 2}
	var cut_wallet_before: Dictionary = cut_wallet.duplicate(true)
	var cut_rng := _rng_start(64503)
	var cut_service := RunEventChoice.new(cut_input_event)
	_check(cut_service.is_valid() and not cut_service.is_claimed(),
		"fresh needle_gate selector valid and unclaimed before cut_bindings")
	var cut_result := cut_service.choose_with_wallet("cut_bindings", cut_wallet)
	_check(_wallet_shape_ok(cut_result), "cut_bindings returns 4-key wallet shape")
	_check(cut_result.get("ok", false) == true, "cut_bindings choose_with_wallet succeeds")
	_check(cut_result.get("event_id", "") == "needle_gate", "cut_bindings returns needle_gate event_id")
	_check(cut_result.get("choice_id", "") == "cut_bindings", "cut_bindings returns cut_bindings choice_id")
	_check(_wallet_exact_int(cut_result.get("wallet"), 32, 0),
		"cut_bindings settles exact integer wallet {gold: 32, scraps: 0}")
	_check(_wallet_exact_int(cut_wallet, 4, 2) and cut_wallet == cut_wallet_before,
		"cut_bindings does not mutate caller input wallet")
	_check(cut_input_event == original, "cut_bindings does not mutate caller input event")
	_check(cut_service.get_event() == original, "cut_bindings does not mutate internal snapshot")
	_check(cut_service.is_claimed() and not cut_service.is_valid(),
		"cut_bindings latches claim and marks selector consumed")
	_check(randi() == cut_rng, "cut_bindings wallet settlement spends no global RNG")

	(cut_result["wallet"] as Dictionary)["gold"] = 999
	(cut_result["wallet"] as Dictionary)["scraps"] = 999
	_check(_wallet_exact_int(cut_wallet, 4, 2), "mutating cut_bindings result wallet does not mutate caller wallet")

	var cut_replay := cut_service.choose_with_wallet("examine", {"gold": 32, "scraps": 0})
	_check(_wallet_shape_ok(cut_replay) and cut_replay.get("ok", true) == false
		and _wallet_exact_int(cut_replay.get("wallet"), 32, 0),
		"replay after cut_bindings claim is rejected with unchanged wallet")

	# An unaffordable gate cannot latch; its free pass is still offered on this instance.
	var empty_wallet := {"gold": 8, "scraps": 0}
	var empty_caller: Dictionary = authored.duplicate(true)
	var reject_rng := _rng_start(64502)
	var free_gate := RunEventChoice.new(empty_caller)
	var refusal := free_gate.choose_with_wallet("examine", empty_wallet)
	_check(_wallet_shape_ok(refusal) and refusal.get("ok") == false
		and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
		and _wallet_exact_int(refusal.get("wallet"), 8, 0),
		"no-scrap refusal returns exact detached original wallet")
	_check(free_gate.is_valid() and not free_gate.is_claimed()
		and free_gate.get_event() == original and empty_caller == original,
		"unaffordable debit preserves selector and both event snapshots")
	(refusal["wallet"] as Dictionary)["gold"] = -999
	_check(_wallet_exact_int(empty_wallet, 8, 0),
		"mutating refused wallet cannot affect original zero-scrap wallet")
	var free_result := free_gate.choose_with_wallet("pass", empty_wallet)
	_check(_wallet_shape_ok(free_result) and free_result.get("ok") == true
		and free_result.get("event_id") == "needle_gate" and free_result.get("choice_id") == "pass"
		and _wallet_exact_int(free_result.get("wallet"), 8, 0),
		"pass on SAME selector after unaffordable trade succeeds for free")
	_check(_wallet_exact_int(empty_wallet, 8, 0) and free_gate.get_event() == original,
		"passing preserves caller wallet and event")
	_check(free_gate.is_claimed() and not free_gate.is_valid(), "free pass latches exactly one claim")
	var after_pass := free_gate.choose_with_wallet("examine", {"gold": 8, "scraps": 1})
	_check(_wallet_shape_ok(after_pass) and after_pass.get("ok") == false
		and _wallet_exact_int(after_pass.get("wallet"), 8, 1),
		"post-pass replay rejects even when the offered trade becomes affordable")
	_check(randi() == reject_rng and free_gate.get_event() == original,
		"refused debit, free pass, replay spend no RNG or authored event state")

	# Insufficient scraps for cut_bindings (zero and one scrap) rejects without claiming,
	# then pass succeeds on SAME selector.
	# Zero scraps
	var poor_cut_zero_event: Dictionary = authored.duplicate(true)
	var poor_cut_zero_wallet := {"gold": 4, "scraps": 0}
	var poor_cut_zero_wallet_before: Dictionary = poor_cut_zero_wallet.duplicate(true)
	var poor_cut_zero_rng := _rng_start(64504)
	var poor_cut_zero_service := RunEventChoice.new(poor_cut_zero_event)
	_check(poor_cut_zero_service.is_valid() and not poor_cut_zero_service.is_claimed(),
		"fresh needle_gate selector valid before refused cut_bindings with zero scraps")
	var poor_cut_zero_refusal := poor_cut_zero_service.choose_with_wallet("cut_bindings", poor_cut_zero_wallet)
	_check(_wallet_shape_ok(poor_cut_zero_refusal) and poor_cut_zero_refusal.get("ok", true) == false
		and poor_cut_zero_refusal.get("event_id", "") == "" and poor_cut_zero_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_cut_zero_refusal.get("wallet"), 4, 0),
		"cut_bindings without scraps is refused with exact unchanged wallet")
	_check(poor_cut_zero_service.is_valid() and not poor_cut_zero_service.is_claimed()
		and _wallet_exact_int(poor_cut_zero_wallet, 4, 0) and poor_cut_zero_wallet == poor_cut_zero_wallet_before
		and poor_cut_zero_service.get_event() == original and poor_cut_zero_event == original,
		"refused cut_bindings with zero scraps consumes no visit and keeps both event snapshots")
	(poor_cut_zero_refusal["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(poor_cut_zero_wallet, 4, 0),
		"mutating refused wallet cannot change caller wallet")
	_check(randi() == poor_cut_zero_rng, "zero-scrap cut_bindings refusal spends no global RNG")

	# pass recovers on SAME selector after refused cut_bindings (zero scraps)
	var pass_recovery_zero := poor_cut_zero_service.choose_with_wallet("pass", poor_cut_zero_wallet)
	_check(_wallet_shape_ok(pass_recovery_zero) and pass_recovery_zero.get("ok", false) == true
		and pass_recovery_zero.get("event_id", "") == "needle_gate"
		and pass_recovery_zero.get("choice_id", "") == "pass"
		and _wallet_exact_int(pass_recovery_zero.get("wallet"), 4, 0),
		"pass recovers on SAME selector after refused cut_bindings with zero scraps")
	_check(poor_cut_zero_service.is_claimed() and not poor_cut_zero_service.is_valid()
		and _wallet_exact_int(poor_cut_zero_wallet, 4, 0) and poor_cut_zero_event == original
		and poor_cut_zero_service.get_event() == original,
		"recovered pass latches exactly one claim and spends nothing (zero scrap)")

	# Post-success replay rejection on the same selector after recovery.
	var pass_replay_zero := poor_cut_zero_service.choose_with_wallet("pass", {"gold": 4, "scraps": 0})
	_check(_wallet_shape_ok(pass_replay_zero) and pass_replay_zero.get("ok", true) == false
		and pass_replay_zero.get("event_id", "") == "" and pass_replay_zero.get("choice_id", "") == ""
		and _wallet_exact_int(pass_replay_zero.get("wallet"), 4, 0),
		"replay after recovered pass (zero scrap) is rejected with unchanged wallet")
	_check(poor_cut_zero_service.is_claimed() and not poor_cut_zero_service.is_valid()
		and poor_cut_zero_service.get_event() == original,
		"replayed pass keeps claim latched and snapshot unchanged (zero scrap)")

	# One scrap (still insufficient, needs 2)
	var poor_cut_one_event: Dictionary = authored.duplicate(true)
	var poor_cut_one_wallet := {"gold": 4, "scraps": 1}
	var poor_cut_one_wallet_before: Dictionary = poor_cut_one_wallet.duplicate(true)
	var poor_cut_one_rng := _rng_start(64505)
	var poor_cut_one_service := RunEventChoice.new(poor_cut_one_event)
	_check(poor_cut_one_service.is_valid() and not poor_cut_one_service.is_claimed(),
		"fresh needle_gate selector valid before refused cut_bindings with one scrap")
	var poor_cut_one_refusal := poor_cut_one_service.choose_with_wallet("cut_bindings", poor_cut_one_wallet)
	_check(_wallet_shape_ok(poor_cut_one_refusal) and poor_cut_one_refusal.get("ok", true) == false
		and poor_cut_one_refusal.get("event_id", "") == "" and poor_cut_one_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_cut_one_refusal.get("wallet"), 4, 1),
		"cut_bindings with only one scrap is refused with exact unchanged wallet")
	_check(poor_cut_one_service.is_valid() and not poor_cut_one_service.is_claimed()
		and _wallet_exact_int(poor_cut_one_wallet, 4, 1) and poor_cut_one_wallet == poor_cut_one_wallet_before
		and poor_cut_one_service.get_event() == original and poor_cut_one_event == original,
		"refused cut_bindings with one scrap consumes no visit and keeps both event snapshots")
	(poor_cut_one_refusal["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(poor_cut_one_wallet, 4, 1),
		"mutating refused wallet cannot change caller wallet")

	# pass recovers on SAME selector after refused cut_bindings
	var pass_recovery := poor_cut_one_service.choose_with_wallet("pass", poor_cut_one_wallet)
	_check(_wallet_shape_ok(pass_recovery) and pass_recovery.get("ok", false) == true
		and pass_recovery.get("event_id", "") == "needle_gate"
		and pass_recovery.get("choice_id", "") == "pass"
		and _wallet_exact_int(pass_recovery.get("wallet"), 4, 1),
		"pass recovers on SAME selector after refused cut_bindings")
	_check(poor_cut_one_service.is_claimed() and not poor_cut_one_service.is_valid()
		and _wallet_exact_int(poor_cut_one_wallet, 4, 1) and poor_cut_one_event == original
		and poor_cut_one_service.get_event() == original,
		"recovered pass latches exactly one claim and spends nothing")
	_check(randi() == poor_cut_one_rng, "refused cut_bindings and recovery spend no global RNG")

	# Post-success replay rejection on the same selector after recovery.
	var pass_replay_one := poor_cut_one_service.choose_with_wallet("pass", {"gold": 4, "scraps": 1})
	_check(_wallet_shape_ok(pass_replay_one) and pass_replay_one.get("ok", true) == false
		and pass_replay_one.get("event_id", "") == "" and pass_replay_one.get("choice_id", "") == ""
		and _wallet_exact_int(pass_replay_one.get("wallet"), 4, 1),
		"replay after recovered pass (one scrap) is rejected with unchanged wallet")
	_check(poor_cut_one_service.is_claimed() and not poor_cut_one_service.is_valid()
		and poor_cut_one_service.get_event() == original,
		"replayed pass keeps claim latched and snapshot unchanged (one scrap)")


func _test_quiet_spool_wallet_settlement() -> void:
	# The authored Quiet Spool record settles through the same one-shot wallet
	# service: watch grants one scrap, ignore leaves both balances untouched.
	var matches := _matching("quiet_spool")
	_check(matches.size() == 1, "exactly one authored quiet_spool record for wallet settlement")
	if matches.size() != 1:
		return
	var authored: Dictionary = matches[0]
	var original: Dictionary = authored.duplicate(true)

	var cases: Array[Dictionary] = [
		{"label": "watch from 0 scraps", "choice": "watch", "scraps": 0, "expected": 1},
		{"label": "watch from 4 scraps", "choice": "watch", "scraps": 4, "expected": 5},
		{"label": "ignore from 0 scraps", "choice": "ignore", "scraps": 0, "expected": 0},
		{"label": "ignore from 4 scraps", "choice": "ignore", "scraps": 4, "expected": 4},
	]
	for case_record in cases:
		var probe: Dictionary = case_record
		var choice_id: String = probe["choice"]
		var start_scraps: int = probe["scraps"]
		var expected_scraps: int = probe["expected"]
		var caller_event: Dictionary = authored.duplicate(true)
		var wallet := {"gold": 13, "scraps": start_scraps}
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 515151
		var local_state: int = local_rng.state
		var expected_global := _rng_start(515151)
		var service := RunEventChoice.new(caller_event)
		_check(service.is_valid() and not service.is_claimed(),
			"fresh quiet_spool selector before the claim: " + probe["label"])
		var result := service.choose_with_wallet(choice_id, wallet)
		_check(_wallet_shape_ok(result) and result.get("ok", false) == true
			and result.get("event_id", "") == "quiet_spool"
			and result.get("choice_id", "") == choice_id
			and _wallet_exact_int(result.get("wallet"), 13, expected_scraps),
			"quiet_spool settles the exact detached wallet: " + probe["label"])
		_check(_wallet_exact_int(wallet, 13, start_scraps),
			"quiet_spool leaves the caller wallet unchanged: " + probe["label"])
		_check(caller_event == original and service.get_event() == original,
			"quiet_spool leaves the caller event and the selector snapshot unchanged: " + probe["label"])
		_check(service.is_claimed() and not service.is_valid(),
			"quiet_spool consumes exactly one claim per visit: " + probe["label"])
		# The approved one-shot service must agree on the same authored IDs.
		var reference := RunQuietSpoolOutcome.new()
		var reference_result := reference.choose("quiet_spool", choice_id, start_scraps)
		_check(reference_result.get("ok", false) == true
			and reference_result.get("event_id", "") == "quiet_spool"
			and reference_result.get("choice_id", "") == choice_id
			and reference_result.get("scraps", -1) == expected_scraps,
			"the approved Quiet Spool service agrees on the same inputs: " + probe["label"])
		_check(local_rng.state == local_state and randi() == expected_global,
			"quiet_spool settlement spends no local or global RNG: " + probe["label"])

	# Illegal IDs, malformed and negative wallets and a max-int overflow all
	# reject on one visit without consuming it.
	var reject_service := RunEventChoice.new(authored.duplicate(true))
	var valid_wallet := {"gold": 13, "scraps": 4}
	var bad_choices: Array = ["", "   ", "unoffered", "Watch", "watch ", null, 12, ["watch"], {"id": "watch"}]
	for bad_choice in bad_choices:
		var rng_expected := _rng_start(51601)
		var rejected := reject_service.choose_with_wallet(bad_choice, valid_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false
			and rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == ""
			and _wallet_exact_int(rejected.get("wallet"), 13, 4),
			"quiet_spool rejects an illegal choice ID: " + str(bad_choice))
		_check(not reject_service.is_claimed() and reject_service.is_valid()
			and _wallet_exact_int(valid_wallet, 13, 4),
			"illegal choice ID consumes no visit and spends nothing: " + str(bad_choice))
		_check(reject_service.get_event() == original,
			"illegal choice ID leaves the selector snapshot unchanged: " + str(bad_choice))
		_check(randi() == rng_expected, "illegal choice ID spends no RNG: " + str(bad_choice))

	var bad_wallets: Array[Dictionary] = [
		{"gold": -1, "scraps": 0},
		{"gold": 13, "scraps": -1},
		{"gold": 13.5, "scraps": 0},
		{"gold": "13", "scraps": 0},
		{"gold": true, "scraps": 0},
		{"gold": 13},
		{"scraps": 0},
		{"gold": 13, "scraps": 0, "hp": 5},
	]
	for bad_wallet in bad_wallets:
		var rng_expected := _rng_start(51602)
		var wallet_before: Dictionary = (bad_wallet as Dictionary).duplicate(true)
		var rejected := reject_service.choose_with_wallet("watch", bad_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false
			and rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == ""
			and (rejected.get("wallet") as Dictionary).is_empty(),
			"quiet_spool rejects an invalid wallet: " + str(bad_wallet))
		_check(bad_wallet == wallet_before,
			"invalid wallet rejection never mutates the caller wallet: " + str(bad_wallet))
		_check(not reject_service.is_claimed() and reject_service.is_valid(),
			"invalid wallet consumes no visit: " + str(bad_wallet))
		_check(randi() == rng_expected, "invalid wallet spends no RNG: " + str(bad_wallet))

	for bad_value in [null, "13", 13, [13, 0]]:
		var rng_expected := _rng_start(51603)
		var rejected := reject_service.choose_with_wallet("watch", bad_value)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false
			and (rejected.get("wallet") as Dictionary).is_empty(),
			"quiet_spool rejects a non-dictionary wallet: " + str(bad_value))
		_check(not reject_service.is_claimed() and reject_service.is_valid(),
			"non-dictionary wallet consumes no visit: " + str(bad_value))
		_check(randi() == rng_expected, "non-dictionary wallet spends no RNG: " + str(bad_value))

	# watch grants one scrap, so a max-int scrap balance cannot settle.
	var overflow_wallet := {"gold": 13, "scraps": RunEventChoice.MAX_INT}
	var overflow := reject_service.choose_with_wallet("watch", overflow_wallet)
	_check(_wallet_shape_ok(overflow) and overflow.get("ok", true) == false
		and overflow.get("event_id", "") == "" and overflow.get("choice_id", "") == ""
		and _wallet_exact_int(overflow.get("wallet"), 13, RunEventChoice.MAX_INT),
		"max-int scrap overflow rejects without claiming")
	_check(not reject_service.is_claimed() and reject_service.is_valid()
		and _wallet_exact_int(overflow_wallet, 13, RunEventChoice.MAX_INT)
		and reject_service.get_event() == original,
		"overflow refusal consumes no visit, spends nothing and keeps both snapshots")

	# The same visit still accepts an affordable authored choice afterwards.
	var recovered := reject_service.choose_with_wallet("watch", valid_wallet)
	_check(_wallet_shape_ok(recovered) and recovered.get("ok", false) == true
		and recovered.get("event_id", "") == "quiet_spool"
		and recovered.get("choice_id", "") == "watch"
		and _wallet_exact_int(recovered.get("wallet"), 13, 5),
		"quiet_spool recovers on the same visit after rejected attempts")
	_check(reject_service.is_claimed() and not reject_service.is_valid()
		and _wallet_exact_int(valid_wallet, 13, 4),
		"the recovered visit latches exactly one claim and spends nothing")

	# Repeat watch, repeat ignore and cross-choice replay all fail closed.
	for replay_choice in ["watch", "ignore"]:
		var replay := reject_service.choose_with_wallet(replay_choice, {"gold": 13, "scraps": 5})
		_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
			and replay.get("event_id", "") == "" and replay.get("choice_id", "") == ""
			and _wallet_exact_int(replay.get("wallet"), 13, 5),
			"quiet_spool rejects a replayed choice after the claim: " + replay_choice)
	_check(reject_service.is_claimed() and reject_service.get_event() == original,
		"replay attempts leave the claim latched and the snapshot unchanged")
	(recovered["wallet"] as Dictionary)["gold"] = 999
	(recovered["wallet"] as Dictionary)["scraps"] = 999
	_check(_wallet_exact_int(valid_wallet, 13, 4),
		"mutating a returned wallet cannot change the caller wallet")

	# Two independent fresh selectors settle the same authored choice identically.
	var traces: Array = []
	for attempt in range(2):
		var fresh := RunEventChoice.new(authored.duplicate(true))
		traces.append(fresh.choose_with_wallet("watch", {"gold": 13, "scraps": 4}))
	_check(traces.size() == 2 and traces[0] == traces[1]
		and _wallet_exact_int((traces[0] as Dictionary).get("wallet"), 13, 5),
		"two fresh quiet_spool selectors settle identical results")


func _test_signed_scraps_boundaries() -> void:
	var matches := _matching("needle_gate")
	_check(matches.size() == 1, "exactly one Needle Gate for signed amount probes")
	if matches.size() != 1:
		return
	var authored: Dictionary = matches[0]
	# Both integer and JSON-style integral float deltas are admitted, including negative gold.
	var accepted := [
		{"label": "int debit", "gold": 1, "scraps": -1, "wallet": {"gold": 8, "scraps": 1}, "gold_after": 9, "scraps_after": 0},
		{"label": "JSON-float debit", "gold": 1.0, "scraps": -1.0, "wallet": {"gold": 8, "scraps": 1}, "gold_after": 9, "scraps_after": 0},
		{"label": "int positive scraps", "gold": 0, "scraps": 1, "wallet": {"gold": 8, "scraps": 0}, "gold_after": 8, "scraps_after": 1},
		{"label": "JSON-float positive scraps", "gold": 0.0, "scraps": 1.0, "wallet": {"gold": 8, "scraps": 0}, "gold_after": 8, "scraps_after": 1},
		{"label": "free zeros", "gold": 0.0, "scraps": 0.0, "wallet": {"gold": 8, "scraps": 0}, "gold_after": 8, "scraps_after": 0},
		{"label": "max int debit", "gold": 0, "scraps": -RunEventChoice.MAX_INT, "wallet": {"gold": 8, "scraps": RunEventChoice.MAX_INT}, "gold_after": 8, "scraps_after": 0},
		{"label": "max safe float debit", "gold": 0.0, "scraps": -9007199254740992.0, "wallet": {"gold": 8, "scraps": 9007199254740992}, "gold_after": 8, "scraps_after": 0},
		{"label": "negative int gold", "gold": -1, "scraps": 0, "wallet": {"gold": 8, "scraps": 1}, "gold_after": 7, "scraps_after": 1},
		{"label": "negative float gold", "gold": -1.0, "scraps": 0.0, "wallet": {"gold": 8, "scraps": 1}, "gold_after": 7, "scraps_after": 1},
	]
	for case_record in accepted:
		var probe: Dictionary = case_record
		var record: Dictionary = authored.duplicate(true)
		record["choices"][0]["outcome"] = {"gold": probe["gold"], "scraps": probe["scraps"]}
		var before: Dictionary = record.duplicate(true)
		var wallet: Dictionary = probe["wallet"].duplicate(true)
		var wallet_before: Dictionary = wallet.duplicate(true)
		var instance := RunEventChoice.new(record)
		_check(instance.is_valid() and not instance.is_claimed(), "positive fixture constructs: " + probe["label"])
		var result := instance.choose_with_wallet("examine", wallet)
		_check(_wallet_shape_ok(result) and result.get("ok") == true
			and result.get("event_id") == "needle_gate" and result.get("choice_id") == "examine"
			and _wallet_exact_int(result.get("wallet"), probe["gold_after"], probe["scraps_after"]),
			"signed/integral delta settles exactly: " + probe["label"])
		_check(wallet == wallet_before and record == before and instance.get_event() == before
			and instance.is_claimed() and not instance.is_valid(),
			"signed/integral delta leaves inputs and snapshots immutable: " + probe["label"])

	# Malformed metadata, rejected gold debits, oversized credits and scrap overdrafts
	# must all fail *before* claiming; the same selector can then pass for free.
	var rejected := [
		{"label": "int scraps overdraft", "gold": 0, "scraps": -2},
		{"label": "float scraps overdraft", "gold": 0.0, "scraps": -2.0},
		{"label": "smallest signed int overdraft", "gold": 0, "scraps": -RunEventChoice.MAX_INT - 1},
		{"label": "fractional gold", "gold": 0.5, "scraps": -1},
		{"label": "fractional scraps", "gold": 0, "scraps": -1.5},
		{"label": "positive fractional scraps", "gold": 0, "scraps": 1.25},
		{"label": "nonfinite gold", "gold": INF, "scraps": -1},
		{"label": "nonfinite scraps", "gold": 0, "scraps": -INF},
		{"label": "NaN gold", "gold": NAN, "scraps": -1},
		{"label": "NaN scraps", "gold": 0, "scraps": NAN},
		{"label": "typed wrong gold", "gold": "1", "scraps": -1},
		{"label": "typed wrong scraps", "gold": 0, "scraps": "-1"},
		{"label": "bool gold", "gold": true, "scraps": -1},
		{"label": "bool scraps", "gold": 0, "scraps": false},
		{"label": "null scraps", "gold": 0, "scraps": null},
		{"label": "oversize float gold", "gold": 9007199254740994.0, "scraps": -1},
		{"label": "oversize float scraps", "gold": 0, "scraps": -9007199254740994.0},
		{"label": "overflow gold credit", "gold": 12, "scraps": -1, "wallet": {"gold": RunEventChoice.MAX_INT, "scraps": 1}},
		{"label": "overflow scraps credit", "gold": 0, "scraps": 1, "wallet": {"gold": 8, "scraps": RunEventChoice.MAX_INT}},
	]
	for case_record in rejected:
		var probe: Dictionary = case_record
		var record: Dictionary = authored.duplicate(true)
		record["choices"][0]["outcome"] = {"gold": probe["gold"], "scraps": probe["scraps"]}
		var wallet: Dictionary = probe.get("wallet", {"gold": 8, "scraps": 1}).duplicate(true)
		var wallet_before: Dictionary = wallet.duplicate(true)
		var initial: Dictionary = record.duplicate(true)
		var expected_rng := _rng_start(64600)
		var instance := RunEventChoice.new(record)
		var denied := instance.choose_with_wallet("examine", wallet)
		_check(_wallet_shape_ok(denied) and denied.get("ok") == false
			and denied.get("event_id") == "" and denied.get("choice_id") == ""
			and denied.get("wallet") == wallet_before,
			"invalid delta rejected with untouched exact wallet: " + probe["label"])
		_check(instance.is_valid() and not instance.is_claimed()
			and var_to_bytes(instance.get_event()) == var_to_bytes(initial)
			and var_to_bytes(record) == var_to_bytes(initial) and wallet == wallet_before,
			"invalid delta leaves selector/snapshots/inputs intact: " + probe["label"])
		(denied["wallet"] as Dictionary)["gold"] = -4
		_check(wallet == wallet_before, "invalid delta rejection wallet is detached: " + probe["label"])
		var recovered := instance.choose_with_wallet("pass", wallet)
		_check(_wallet_shape_ok(recovered) and recovered.get("ok") == true
			and recovered.get("event_id") == "needle_gate" and recovered.get("choice_id") == "pass"
			and recovered.get("wallet") == wallet_before,
			"invalid delta recovers through free pass: " + probe["label"])
		_check(instance.is_claimed() and not instance.is_valid()
			and var_to_bytes(instance.get_event()) == var_to_bytes(initial) and wallet == wallet_before,
			"recovery is one-time and input-safe: " + probe["label"])
		_check(randi() == expected_rng, "invalid delta and recovery use no global RNG: " + probe["label"])


func _test_wallet_preflight_rejections_and_recovery() -> void:
	var matches := _matching("button_trail")
	if matches.size() != 1:
		return
	var original_button_trail: Dictionary = matches[0].duplicate(true)

	# 1. Single button_trail instance: reject bad choice IDs and bad wallets, then recover on same instance.
	var service := RunEventChoice.new(original_button_trail)
	var valid_wallet := {"gold": 12, "scraps": 0}
	var bad_choices: Array = ["", "   ", "unoffered", "FOLLOW", "follow ", " follow", null, 12, ["follow"], {"id": "follow"}]
	for bad_choice in bad_choices:
		var rng_expected := _rng_start(64100)
		var rejected := service.choose_with_wallet(bad_choice, valid_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false,
			"bad choice_id rejected in choose_with_wallet: " + str(bad_choice))
		_check(rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == "",
			"bad choice_id returns empty IDs: " + str(bad_choice))
		_check(_wallet_exact_int(rejected.get("wallet"), 12, 0),
			"bad choice_id preserves detached valid wallet: " + str(bad_choice))
		(rejected["wallet"] as Dictionary)["gold"] = -1
		_check(_wallet_exact_int(valid_wallet, 12, 0),
			"mutating rejected wallet does not alter caller wallet: " + str(bad_choice))
		_check(not service.is_claimed() and service.is_valid(),
			"bad choice_id does not consume visit: " + str(bad_choice))
		_check(service.get_event() == original_button_trail,
			"bad choice_id leaves event snapshot unchanged: " + str(bad_choice))
		_check(randi() == rng_expected, "bad choice_id spends no RNG: " + str(bad_choice))

	var invalid_wallets := {
		"null wallet": null,
		"string wallet": "12",
		"int wallet": 12,
		"array wallet": [12, 0],
		"empty dict": {},
		"missing scraps": {"gold": 12},
		"missing gold": {"scraps": 0},
		"extra key": {"gold": 12, "scraps": 0, "hp": 5},
		"negative gold": {"gold": -1, "scraps": 0},
		"negative scraps": {"gold": 12, "scraps": -1},
		"both negative": {"gold": -5, "scraps": -2},
		"fractional gold": {"gold": 12.5, "scraps": 0},
		"fractional scraps": {"gold": 12, "scraps": 0.25},
		"float gold": {"gold": 12.0, "scraps": 0},
		"float scraps": {"gold": 12, "scraps": 0.0},
		"string gold": {"gold": "12", "scraps": 0},
		"string scraps": {"gold": 12, "scraps": "0"},
		"bool gold": {"gold": true, "scraps": 0},
		"bool scraps": {"gold": 12, "scraps": false},
		"null gold": {"gold": null, "scraps": 0},
		"inf gold": {"gold": INF, "scraps": 0},
		"nan scraps": {"gold": 12, "scraps": NAN},
	}
	for label in invalid_wallets:
		var bad_wallet: Variant = invalid_wallets[label]
		var before_wallet: Variant = bad_wallet.duplicate(true) if bad_wallet is Dictionary else null
		var rng_expected := _rng_start(64200)
		var rejected := service.choose_with_wallet("follow", bad_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false,
			"invalid wallet rejected: " + label)
		_check(rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == "",
			"invalid wallet returns empty IDs: " + label)
		_check((rejected.get("wallet") as Dictionary).is_empty(),
			"invalid wallet returns empty wallet dict: " + label)
		if bad_wallet is Dictionary and not ( label == "nan scraps" ):
			_check(bad_wallet == before_wallet, "invalid caller wallet dict not mutated: " + label)
		_check(not service.is_claimed() and service.is_valid(),
			"invalid wallet does not consume visit: " + label)
		_check(service.get_event() == original_button_trail,
			"invalid wallet leaves event snapshot unchanged: " + label)
		_check(randi() == rng_expected, "invalid wallet spends no RNG: " + label)

	# Overflow guard on otherwise valid wallet: sell_buttons adds 18 gold, follow adds 1 scrap.
	var max_gold_wallet := {"gold": RunEventChoice.MAX_INT, "scraps": 1}
	var overflow_gold := service.choose_with_wallet("sell_buttons", max_gold_wallet)
	_check(_wallet_shape_ok(overflow_gold) and overflow_gold.get("ok", true) == false
		and _wallet_exact_int(overflow_gold.get("wallet"), RunEventChoice.MAX_INT, 1)
		and not service.is_claimed() and service.is_valid(),
		"gold overflow rejects without claiming and retains detached valid wallet")
	var max_scraps_wallet := {"gold": 12, "scraps": RunEventChoice.MAX_INT}
	var overflow_scraps := service.choose_with_wallet("follow", max_scraps_wallet)
	_check(_wallet_shape_ok(overflow_scraps) and overflow_scraps.get("ok", true) == false
		and _wallet_exact_int(overflow_scraps.get("wallet"), 12, RunEventChoice.MAX_INT)
		and not service.is_claimed() and service.is_valid(),
		"scraps overflow rejects without claiming and retains detached valid wallet")

	# Recovery on the SAME instance after all bad-choice, invalid-wallet and overflow rejections.
	var recovered := service.choose_with_wallet("follow", valid_wallet)
	_check(_wallet_shape_ok(recovered) and recovered.get("ok", false) == true
		and recovered.get("event_id", "") == "button_trail"
		and recovered.get("choice_id", "") == "follow"
		and _wallet_exact_int(recovered.get("wallet"), 12, 1),
		"same instance accepts valid choice after preflight rejections")
	_check(service.is_claimed() and not service.is_valid(),
		"recovered claim latches after preflight rejections")

	# 2. Outcome-less fixture events reject choose_with_wallet without claiming,
	#    then still accept legacy choose().
	var placeholder_fixture := _valid_fixture()
	var placeholder_service := RunEventChoice.new(placeholder_fixture)
	var placeholder_rng := _rng_start(64300)
	var wallet_attempt := placeholder_service.choose_with_wallet("one", {"gold": 12, "scraps": 0})
	_check(_wallet_shape_ok(wallet_attempt) and wallet_attempt.get("ok", true) == false,
		"placeholder fixture rejects choose_with_wallet")
	_check(_wallet_exact_int(wallet_attempt.get("wallet"), 12, 0),
		"placeholder rejection preserves detached wallet")
	_check(not placeholder_service.is_claimed() and placeholder_service.is_valid(),
		"placeholder wallet rejection does not consume visit")
	var legacy_claim := placeholder_service.choose("one")
	_check(_shape_ok(legacy_claim) and legacy_claim.get("ok", false) == true
		and legacy_claim.get("event_id", "") == "fixture_event"
		and legacy_claim.get("choice_id", "") == "one",
		"placeholder fixture still accepts legacy choose() after wallet rejection")
	_check(placeholder_service.is_claimed() and not placeholder_service.is_valid(),
		"placeholder legacy claim latches once")
	_check(randi() == placeholder_rng, "placeholder rejection + legacy claim spend no RNG")

	# 3. Corrupt outcome metadata on one choice rejects before latching, and same instance recovers on valid choice.
	var corrupt_outcomes := {
		"missing outcome key": null,
		"outcome is null": {"outcome": null},
		"outcome is string": {"outcome": "1 scrap"},
		"outcome is array": {"outcome": [0, 1]},
		"outcome is int": {"outcome": 1},
		"outcome empty dict": {"outcome": {}},
		"outcome missing scraps": {"outcome": {"gold": 0}},
		"outcome missing gold": {"outcome": {"scraps": 1}},
		"outcome extra key": {"outcome": {"gold": 0, "scraps": 1, "hp": 5}},
		"choice extra key": {"outcome": {"gold": 0, "scraps": 1}, "bonus": true},
		"fractional gold 0.5": {"outcome": {"gold": 0.5, "scraps": 1}},
		"fractional scraps 1.25": {"outcome": {"gold": 0, "scraps": 1.25}},
		"negative fractional": {"outcome": {"gold": -0.5, "scraps": 0}},
		"inf outcome gold": {"outcome": {"gold": INF, "scraps": 1}},
		"nan outcome scraps": {"outcome": {"gold": 0, "scraps": NAN}},
		"string outcome gold": {"outcome": {"gold": "0", "scraps": 1}},
		"string outcome scraps": {"outcome": {"gold": 0, "scraps": "1"}},
		"bool outcome gold": {"outcome": {"gold": true, "scraps": 1}},
		"null outcome scraps": {"outcome": {"gold": 0, "scraps": null}},
	}
	for label in corrupt_outcomes:
		var custom_event: Dictionary = original_button_trail.duplicate(true)
		var bad_follow: Dictionary = {"id": "follow", "text": "Follow the button trail"}
		var patch: Variant = corrupt_outcomes[label]
		if patch is Dictionary:
			for k in (patch as Dictionary):
				bad_follow[k] = (patch as Dictionary)[k]
		custom_event["choices"][0] = bad_follow
		var rng_expected := _rng_start(64400)
		var corrupt_service := RunEventChoice.new(custom_event)
		_check(corrupt_service.is_valid() and not corrupt_service.is_claimed(),
			"event with corrupt choice outcome still constructs unclaimed: " + label)
		var caller_wallet := {"gold": 12, "scraps": 0}
		var rejected := corrupt_service.choose_with_wallet("follow", caller_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false,
			"corrupt outcome rejected by choose_with_wallet: " + label)
		_check(_wallet_exact_int(rejected.get("wallet"), 12, 0),
			"corrupt outcome rejection preserves detached valid wallet: " + label)
		_check(_wallet_exact_int(caller_wallet, 12, 0),
			"corrupt outcome rejection does not mutate caller wallet: " + label)
		_check(not corrupt_service.is_claimed() and corrupt_service.is_valid(),
			"corrupt outcome rejection does not consume visit: " + label)
		# Same instance recovers when choosing the valid "leave" choice.
		var recovered_leave := corrupt_service.choose_with_wallet("leave", caller_wallet)
		_check(_wallet_shape_ok(recovered_leave) and recovered_leave.get("ok", false) == true
			and recovered_leave.get("event_id", "") == "button_trail"
			and recovered_leave.get("choice_id", "") == "leave"
			and _wallet_exact_int(recovered_leave.get("wallet"), 0, 2),
			"same instance recovers with valid sibling choice after corrupt outcome rejection: " + label)
		_check(corrupt_service.is_claimed() and not corrupt_service.is_valid(),
			"recovered sibling choice latches once: " + label)
		_check(randi() == rng_expected, "corrupt outcome rejection + recovery spend no RNG: " + label)


func _test_invalid_records() -> void:
	var four_choices := _valid_fixture()
	four_choices["choices"] = [
		{"id": "one", "text": "Take the first option"},
		{"id": "two", "text": "Take the second option"},
		{"id": "three", "text": "Take the third option"},
		{"id": "four", "text": "Take the fourth option"},
	]
	var one_choice := _valid_fixture()
	one_choice["choices"] = [{"id": "one", "text": "Take the first option"}]
	var no_choices := _valid_fixture()
	no_choices["choices"] = []
	var duplicate_ids := _valid_fixture()
	duplicate_ids["choices"] = [
		{"id": "one", "text": "Take the first option"},
		{"id": "one", "text": "A different second option"},
	]
	var blank_text := _valid_fixture()
	blank_text["choices"] = [
		{"id": "one", "text": "   "},
		{"id": "two", "text": "Take the second option"},
	]
	var blank_choice_id := _valid_fixture()
	blank_choice_id["choices"] = [
		{"id": "", "text": "Take the first option"},
		{"id": "two", "text": "Take the second option"},
	]
	var cases := {
		"null record": null,
		"array record": [{"id": "button_trail"}],
		"string record": "button_trail",
		"int record": 7,
		"missing id": {"title": "T", "description": "D", "choices": [{"id": "one", "text": "A"}, {"id": "two", "text": "B"}]},
		"blank id": {"id": "   ", "title": "T", "description": "D", "choices": [{"id": "one", "text": "A"}, {"id": "two", "text": "B"}]},
		"numeric id": {"id": 12, "title": "T", "description": "D", "choices": [{"id": "one", "text": "A"}, {"id": "two", "text": "B"}]},
		"missing title": {"id": "event", "description": "D", "choices": [{"id": "one", "text": "A"}, {"id": "two", "text": "B"}]},
		"blank title": {"id": "event", "title": "", "description": "D", "choices": [{"id": "one", "text": "A"}, {"id": "two", "text": "B"}]},
		"numeric description": {"id": "event", "title": "T", "description": 5, "choices": [{"id": "one", "text": "A"}, {"id": "two", "text": "B"}]},
		"missing description": {"id": "event", "title": "T", "choices": [{"id": "one", "text": "A"}, {"id": "two", "text": "B"}]},
		"missing choices": {"id": "event", "title": "T", "description": "D"},
		"choices not array": {"id": "event", "title": "T", "description": "D", "choices": "one"},
		"zero choices": no_choices,
		"one choice": one_choice,
		"four choices": four_choices,
		"duplicate choice IDs": duplicate_ids,
		"blank choice text": blank_text,
		"blank choice ID": blank_choice_id,
		"choice record not object": {"id": "event", "title": "T", "description": "D", "choices": ["one", "two"]},
	}
	for label in cases:
		var record: Variant = cases[label]
		var before: Variant = record.duplicate(true) if record is Dictionary else null
		var rng_expected := _rng_start(63500)
		var service := RunEventChoice.new(record)
		_check(not service.is_valid(), "invalid construction rejected: " + label)
		_check(not service.is_claimed(), "invalid construction consumes no claim: " + label)
		_check(service.get_event().is_empty(), "invalid construction stores no event: " + label)
		var result := service.choose("one")
		_check(_shape_ok(result), "rejection shape exact: " + label)
		_check(result.get("ok", true) == false, "choose rejected: " + label)
		_check(result.get("event_id", "") == "" and result.get("choice_id", "") == "",
			"rejection returns empty IDs: " + label)
		var wallet_result := service.choose_with_wallet("one", {"gold": 12, "scraps": 0})
		_check(_wallet_shape_ok(wallet_result) and wallet_result.get("ok", true) == false
			and _wallet_exact_int(wallet_result.get("wallet"), 12, 0),
			"choose_with_wallet on invalid record rejects with detached valid wallet: " + label)
		_check(not service.is_claimed(), "still unclaimed after rejection: " + label)
		_check(not service.is_valid(), "still invalid after rejection: " + label)
		if record is Dictionary:
			_check(record == before, "input record unchanged by construction and rejection: " + label)
		_check(randi() == rng_expected, "invalid records spend no RNG: " + label)
	# AC3: a valid first record still claims once after every rejected construction.
	var recovered := RunEventChoice.new(_valid_fixture())
	_check(recovered.is_valid(), "valid record usable after rejected constructions")
	_check(recovered.choose("one").get("ok", false) == true, "valid claim succeeds after rejected constructions")
	_check(recovered.is_claimed() and not recovered.is_valid(), "recovered claim latched exactly once")
	_check(recovered.choose("two").get("ok", true) == false, "no second claim after recovery")


func _test_bad_choice_recovery_and_replay() -> void:
	var service := RunEventChoice.new(_valid_fixture())
	var expected_event := service.get_event()
	for bad in ["", "   ", "missing_choice", "ONE", "one "]:
		var rejected := service.choose(bad)
		_check(_shape_ok(rejected), "bad-choice rejection shape: '" + bad + "'")
		_check(rejected.get("ok", true) == false, "bad choice rejected: '" + bad + "'")
		_check(rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == "",
			"bad choice returns empty IDs: '" + bad + "'")
		_check(not service.is_claimed(), "bad choice consumes no claim: '" + bad + "'")
		_check(service.is_valid(), "still claimable after bad choice: '" + bad + "'")
		_check(service.get_event() == expected_event, "event unchanged after bad choice: '" + bad + "'")
	var accepted := service.choose("two")
	_check(accepted.get("ok", false) == true, "valid choice succeeds after rejected choices")
	_check(accepted.get("event_id", "") == "fixture_event" and accepted.get("choice_id", "") == "two",
		"recovery returns exact IDs")
	accepted["ok"] = false
	accepted["choice_id"] = "mutated"
	_check(service.is_claimed() and service.get_event() == expected_event,
		"returned result mutation isolated")
	var second := service.choose("one")
	_check(_shape_ok(second) and second.get("ok", true) == false, "second claim rejected")
	_check(service.is_claimed(), "single claim latched across rejections")
	_check(not service.is_valid(), "consumed offering stays invalid")
	_check(service.get_event() == expected_event, "event snapshot stable after replay rejection")
	var fresh := RunEventChoice.new(_valid_fixture())
	_check(fresh.choose("one").get("ok", false) == true, "fresh instance claims independently")
	_check(fresh.is_claimed() and not fresh.is_valid(), "fresh instance latches its own claim")
	_check(service.get_event() == expected_event, "other instance untouched by fresh claim")


func _test_no_rng_consumption() -> void:
	# Global-stream sentinel: an injected draw must be detectable.
	var sentinel := _rng_start(63999)
	randi()
	_check(randi() != sentinel, "RNG sentinel detects an injected global draw")
	seed(63999)
	var expected := randi()
	seed(63999)
	var service := RunEventChoice.new(_valid_fixture())
	_check(service.get_event() == _valid_fixture(), "snapshot readable during RNG probe")
	_check(not service.choose("nope").get("ok", true), "rejected choice during RNG probe")
	_check(service.choose("one").get("ok", false) == true, "claim during RNG probe")
	_check(service.get_event() == _valid_fixture(), "event snapshot stable during RNG probe")
	_check(randi() == expected, "construction, reads and claim spend no global RNG")


func _test_seeded_replay_and_wallet_rng() -> void:
	# Each branch gets two fresh selectors and seeded streams, including the
	# unaffordable Needle Gate and Frayed Signpost attempts before the successful free choices.
	for event_id in ["button_trail", "needle_gate", "thimble_well", "frayed_signpost"]:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "seeded replay record exists exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var authored_record: Dictionary = matches[0]
		var choices: Array[String] = []
		if event_id == "button_trail":
			choices = ["follow", "leave", "sell_buttons"]
		elif event_id == "needle_gate":
			choices = ["examine", "pass", "cut_bindings"]
		elif event_id == "thimble_well":
			choices = ["listen", "depart", "lower_spool"]
		elif event_id == "frayed_signpost":
			choices = ["read", "choose", "sell_arrowwork"]
		for choice_id in choices:
			var traces: Array = []
			for attempt in range(2):
				var local_rng := RandomNumberGenerator.new()
				local_rng.seed = 918273
				var initial_local_state := local_rng.state
				var expected_global := _rng_start(918273)
				var caller_event: Dictionary = authored_record.duplicate(true)
				var original_event: Dictionary = caller_event.duplicate(true)
				var instance := RunEventChoice.new(caller_event)
				var wallet := {"gold": 12, "scraps": 0}
				if event_id == "button_trail":
					if choice_id == "sell_buttons":
						wallet = {"gold": 4, "scraps": 1}
					else:
						wallet = {"gold": 12, "scraps": 0}
				elif event_id == "needle_gate":
					if choice_id == "examine":
						wallet = {"gold": 8, "scraps": 1}
					elif choice_id == "cut_bindings":
						wallet = {"gold": 4, "scraps": 2}
					else:
						wallet = {"gold": 8, "scraps": 0}
				elif event_id == "thimble_well":
					if choice_id == "lower_spool":
						wallet = {"gold": 4, "scraps": 1}
					else:
						wallet = {"gold": 7, "scraps": 0}
				elif event_id == "frayed_signpost":
					if choice_id == "read":
						wallet = {"gold": 7, "scraps": 2}
					elif choice_id == "sell_arrowwork":
						wallet = {"gold": 7, "scraps": 2}
					else:
						wallet = {"gold": 7, "scraps": 0}
				var wallet_before: Dictionary = wallet.duplicate(true)
				var preflight_reject := instance.choose_with_wallet("not_a_choice", wallet)
				var denied_debit: Dictionary = {}
				if event_id == "needle_gate" and choice_id == "pass":
					# Try examine with zero scraps (unaffordable), then pass succeeds
					var zero_scrap_wallet := {"gold": 8, "scraps": 0}
					denied_debit = instance.choose_with_wallet("examine", zero_scrap_wallet)
					_check(_wallet_shape_ok(denied_debit) and denied_debit.get("ok") == false
						and _wallet_exact_int(denied_debit.get("wallet"), 8, 0)
						and instance.is_valid() and not instance.is_claimed(),
						"seeded no-scrap debit refused before free pass")
				elif event_id == "needle_gate" and choice_id == "examine":
					# Try cut_bindings with zero scraps (unaffordable), then examine succeeds
					var zero_scrap_wallet := {"gold": 4, "scraps": 0}
					denied_debit = instance.choose_with_wallet("cut_bindings", zero_scrap_wallet)
					_check(_wallet_shape_ok(denied_debit) and denied_debit.get("ok") == false
						and _wallet_exact_int(denied_debit.get("wallet"), 4, 0)
						and instance.is_valid() and not instance.is_claimed(),
						"seeded no-scrap cut_bindings refused before examine")
				elif event_id == "needle_gate" and choice_id == "cut_bindings":
					# Try examine with zero scraps (unaffordable), then cut_bindings succeeds
					var zero_scrap_wallet := {"gold": 8, "scraps": 0}
					denied_debit = instance.choose_with_wallet("examine", zero_scrap_wallet)
					_check(_wallet_shape_ok(denied_debit) and denied_debit.get("ok") == false
						and _wallet_exact_int(denied_debit.get("wallet"), 8, 0)
						and instance.is_valid() and not instance.is_claimed(),
						"seeded no-scrap debit refused before cut_bindings")
				elif event_id == "button_trail" and choice_id == "follow":
					# Try sell_buttons with zero scraps (unaffordable), then follow succeeds
					var zero_scrap_wallet := {"gold": 4, "scraps": 0}
					denied_debit = instance.choose_with_wallet("sell_buttons", zero_scrap_wallet)
					_check(_wallet_shape_ok(denied_debit) and denied_debit.get("ok") == false
						and _wallet_exact_int(denied_debit.get("wallet"), 4, 0)
						and instance.is_valid() and not instance.is_claimed(),
						"seeded no-scrap sell_buttons refused before follow")
				elif event_id == "button_trail" and choice_id == "leave":
					# Try sell_buttons with zero scraps (unaffordable), then leave succeeds
					var zero_scrap_wallet := {"gold": 4, "scraps": 0}
					denied_debit = instance.choose_with_wallet("sell_buttons", zero_scrap_wallet)
					_check(_wallet_shape_ok(denied_debit) and denied_debit.get("ok") == false
						and _wallet_exact_int(denied_debit.get("wallet"), 4, 0)
						and instance.is_valid() and not instance.is_claimed(),
						"seeded no-scrap sell_buttons refused before leave")
				elif event_id == "thimble_well" and choice_id == "lower_spool":
					# Try listen with zero scraps (always affordable, but we test the flow)
					# lower_spool is costly, so no denied_debit needed for it
					pass
				elif event_id == "frayed_signpost" and choice_id == "choose":
					denied_debit = instance.choose_with_wallet("read", wallet)
					_check(_wallet_shape_ok(denied_debit) and denied_debit.get("ok") == false
						and _wallet_exact_int(denied_debit.get("wallet"), 7, 0)
						and instance.is_valid() and not instance.is_claimed(),
						"seeded no-scrap debit refused before free choose")
				elif event_id == "frayed_signpost" and choice_id == "sell_arrowwork":
					var zero_scrap_wallet := {"gold": 7, "scraps": 0}
					denied_debit = instance.choose_with_wallet("read", zero_scrap_wallet)
					_check(_wallet_shape_ok(denied_debit) and denied_debit.get("ok") == false
						and _wallet_exact_int(denied_debit.get("wallet"), 7, 0)
						and instance.is_valid() and not instance.is_claimed(),
						"seeded no-scrap debit refused before sell_arrowwork")
				var claim_result := instance.choose_with_wallet(choice_id, wallet)
				var replay_reject := instance.choose_with_wallet(choice_id, claim_result["wallet"])
				_check(_wallet_shape_ok(preflight_reject) and preflight_reject.get("ok") == false
					and preflight_reject.get("wallet") == wallet_before,
					"seeded forged choice preserves wallet for " + event_id + "/" + choice_id)
				_check(_wallet_shape_ok(claim_result) and claim_result.get("ok") == true
					and claim_result.get("event_id") == event_id and claim_result.get("choice_id") == choice_id,
					"seeded valid claim has expected IDs: " + event_id + "/" + choice_id)
				_check(_wallet_shape_ok(replay_reject) and replay_reject.get("ok") == false
					and replay_reject.get("wallet") == claim_result["wallet"]
					and instance.is_claimed() and not instance.is_valid(),
					"seeded replay fails after one claim: " + event_id + "/" + choice_id)
				_check(wallet == wallet_before and caller_event == original_event
					and instance.get_event() == original_event,
					"seeded traces preserve caller event, wallet and selector snapshots")
				_check(local_rng.state == initial_local_state,
					"local seeded RNG state unchanged for " + event_id + "/" + choice_id + " attempt " + str(attempt))
				_check(randi() == expected_global,
					"global seeded RNG stream unchanged for " + event_id + "/" + choice_id + " attempt " + str(attempt))
				traces.append({
					"preflight_reject": preflight_reject,
					"denied_debit": denied_debit,
					"claim_result": claim_result,
					"replay_reject": replay_reject,
					"is_claimed": instance.is_claimed(),
					"is_valid": instance.is_valid(),
					"event": instance.get_event(),
				})
			_check(traces.size() == 2 and traces[0] == traces[1],
				"two independent seeded instances produce identical wallet traces for " + event_id + "/" + choice_id)


## Lookup is by authored choice ID; preview order is checked separately against
## the actual record, never against the catalog's overall size or ordering.
func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _test_wallet_choice_previews() -> void:
	# Every real authored choice, from scarcity through exact affordability, must
	# predict what a separate fresh instance actually commits.
	for event_id in REQUIRED:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "preview requires one real authored event: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0].duplicate(true)
		var expected: Dictionary = REQUIRED[event_id]["outcomes"]
		var source_choices: Array = record["choices"]
		_check(source_choices.size() >= 2 and source_choices.size() <= 3,
			"preview nonempty real 2-3 choice fixture: " + event_id)
		for scraps in [0, 1, 2]:
			var wallet := {"gold": 9, "scraps": scraps}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var event_before: Dictionary = record.duplicate(true)
			var rng_expected := _rng_start(70000 + scraps)
			var local_rng := RandomNumberGenerator.new()
			local_rng.seed = 70000 + scraps
			var local_state: int = local_rng.state
			var service := RunEventChoice.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"preview starts with valid, unclaimed real selector: " + event_id)
			var preview := service.preview_wallet_choices(wallet)
			_check(preview.size() == 3 and preview.get("ok") == true
				and preview.get("event_id") == event_id and preview.get("choices") is Array,
				"preview exact result contract: " + event_id + "/" + str(scraps))
			var entries: Array = preview.get("choices", [])
			_check(entries.size() == source_choices.size(),
				"preview has one entry per real authored choice: " + event_id + "/" + str(scraps))
			for index in range(source_choices.size()):
				var choice_id: String = source_choices[index]["id"]
				var delta: Dictionary = expected[choice_id]
				var entry := _preview_choice(preview, choice_id)
				var affordable: bool = (scraps + int(delta["scraps"]) >= 0) and (9 + int(delta["gold"]) >= 0)
				var projected_gold: int = 9 + int(delta["gold"]) if affordable else 9
				var projected_scraps: int = scraps + int(delta["scraps"]) if affordable else scraps
				_check(not entry.is_empty() and index < entries.size()
					and entries[index].get("choice_id") == choice_id,
					"preview keeps original authored choice order: " + event_id + "/" + choice_id)
				_check(entry.size() == 5 and entry.get("choice_id") == choice_id
					and typeof(entry.get("gold_delta")) == TYPE_INT
					and typeof(entry.get("scraps_delta")) == TYPE_INT
					and entry.get("gold_delta") == delta["gold"]
					and entry.get("scraps_delta") == delta["scraps"],
					"preview exact normalized signed authored deltas: " + event_id + "/" + choice_id)
				_check(entry.get("affordable") == affordable
					and _wallet_exact_int(entry.get("wallet"), projected_gold, projected_scraps),
					"preview affordability and detached projected/unchanged wallet: " + event_id
					+ "/" + choice_id + "/" + str(scraps))
				# The choice settlement is the authoritative oracle, not reimplemented
				# by the preview test as a substitute for a commit.
				var receipt := RunEventChoice.new(record).choose_with_wallet(choice_id, wallet)
				_check(receipt.get("ok") == affordable
					and receipt.get("wallet") == entry.get("wallet")
					and receipt.get("event_id") == (event_id if affordable else "")
					and receipt.get("choice_id") == (choice_id if affordable else ""),
					"preview agrees with independently committed wallet receipt: " + event_id
					+ "/" + choice_id + "/" + str(scraps))
			_check(service.is_valid() and not service.is_claimed()
				and service.get_event() == event_before and record == event_before
				and wallet == wallet_before,
				"preview leaves latch, authored event, and caller wallet unchanged: "
				+ event_id + "/" + str(scraps))
			var again := service.preview_wallet_choices(wallet)
			_check(again == preview and service.is_valid() and not service.is_claimed(),
				"repeated preview deterministic and does not claim: " + event_id + "/" + str(scraps))
			if entries.size() >= 2:
				var other_wallet: Dictionary = entries[1]["wallet"]
				var other_before: Dictionary = other_wallet.duplicate(true)
				(entries[0]["wallet"] as Dictionary)["gold"] = -500
				entries[0]["gold_delta"] = -500
				_check(other_wallet == other_before and service.preview_wallet_choices(wallet) == again
					and wallet == wallet_before and service.get_event() == event_before,
					"preview result wallets and metadata detached from siblings and selector: "
					+ event_id + "/" + str(scraps))
			# Preview must never make a subsequent legitimate claim or its replay
			# behave differently from the ordinary wallet transaction.
			var chosen_id: String = source_choices[0]["id"]
			var first_entry := _preview_choice(again, chosen_id)
			if not first_entry.get("affordable", false):
				chosen_id = source_choices[1]["id"]
				first_entry = _preview_choice(again, chosen_id)
			_check(first_entry.get("affordable", false),
				"fixture has a genuinely claimable choice after preview: " + event_id)
			if first_entry.get("affordable", false):
				var committed := service.choose_with_wallet(chosen_id, wallet)
				_check(committed.get("ok") == true and committed.get("wallet") == first_entry["wallet"]
					and service.is_claimed() and not service.is_valid(),
					"post-preview commit matches forecast and claims once: " + event_id)
				var replay := service.choose_with_wallet(chosen_id, wallet)
				_check(replay.get("ok") == false and replay.get("event_id") == ""
					and replay.get("choice_id") == "" and replay.get("wallet") == wallet_before
					and service.preview_wallet_choices(wallet) == {"ok": false, "event_id": "", "choices": []},
					"commit consumes preview, and replay rejects unchanged wallet: " + event_id)
			_check(local_rng.state == local_state and randi() == rng_expected,
				"repeat preview, wallet oracle, commit and replay leave both RNGs untouched: "
				+ event_id + "/" + str(scraps))

	# Explicit Button Trail leave preview at exact affordability boundaries (AC2, AC3).
	# These are not covered by the gold=9 loop above; leave requires 12 gold.
	var button_trail_matches := _matching("button_trail")
	_check(button_trail_matches.size() == 1, "Button Trail event required for leave boundary previews")
	if button_trail_matches.size() == 1:
		var bt_record: Dictionary = button_trail_matches[0].duplicate(true)
		var bt_expected: Dictionary = REQUIRED["button_trail"]["outcomes"]
		
		# leave at 12 gold/0 scraps: affordable, forecast 0 gold/2 scraps
		var bt_wallet_12 := {"gold": 12, "scraps": 0}
		var bt_wallet_12_before: Dictionary = bt_wallet_12.duplicate(true)
		var bt_event_12_before: Dictionary = bt_record.duplicate(true)
		var bt_rng_12 := _rng_start(70100)
		var bt_local_12 := RandomNumberGenerator.new()
		bt_local_12.seed = 70100
		var bt_local_state_12: int = bt_local_12.state
		var bt_service_12 := RunEventChoice.new(bt_record)
		_check(bt_service_12.is_valid() and not bt_service_12.is_claimed(),
			"Button Trail leave preview at 12 gold starts valid and unclaimed")
		var bt_preview_12 := bt_service_12.preview_wallet_choices(bt_wallet_12)
		_check(bt_preview_12.get("ok") == true and bt_preview_12.get("event_id") == "button_trail",
			"Button Trail leave preview at 12 gold returns ok")
		var bt_leave_entry_12 := _preview_choice(bt_preview_12, "leave")
		_check(not bt_leave_entry_12.is_empty(), "leave entry present in preview at 12 gold")
		_check(bt_leave_entry_12.get("gold_delta") == -12 and bt_leave_entry_12.get("scraps_delta") == 2,
			"leave preview at 12 gold shows exact signed deltas")
		_check(bt_leave_entry_12.get("affordable") == true,
			"leave preview at 12 gold marks choice affordable")
		_check(_wallet_exact_int(bt_leave_entry_12.get("wallet"), 0, 2),
			"leave preview at 12 gold projects {gold: 0, scraps: 2}")
		var bt_receipt_12 := RunEventChoice.new(bt_record).choose_with_wallet("leave", bt_wallet_12)
		_check(bt_receipt_12.get("ok") == true
			and bt_receipt_12.get("wallet") == bt_leave_entry_12.get("wallet")
			and bt_receipt_12.get("event_id") == "button_trail"
			and bt_receipt_12.get("choice_id") == "leave",
			"leave commit at 12 gold matches preview forecast")
		_check(bt_service_12.is_valid() and not bt_service_12.is_claimed()
			and bt_service_12.get_event() == bt_event_12_before
			and bt_record == bt_event_12_before
			and bt_wallet_12 == bt_wallet_12_before,
			"leave preview at 12 gold leaves selector and inputs unchanged")
		_check(bt_local_12.state == bt_local_state_12 and randi() == bt_rng_12,
			"leave preview at 12 gold spends no RNG")
		
		# leave at 11 gold/0 scraps: unaffordable, unchanged forecast
		var bt_wallet_11 := {"gold": 11, "scraps": 0}
		var bt_wallet_11_before: Dictionary = bt_wallet_11.duplicate(true)
		var bt_event_11_before: Dictionary = bt_record.duplicate(true)
		var bt_rng_11 := _rng_start(70101)
		var bt_local_11 := RandomNumberGenerator.new()
		bt_local_11.seed = 70101
		var bt_local_state_11: int = bt_local_11.state
		var bt_service_11 := RunEventChoice.new(bt_record)
		_check(bt_service_11.is_valid() and not bt_service_11.is_claimed(),
			"Button Trail leave preview at 11 gold starts valid and unclaimed")
		var bt_preview_11 := bt_service_11.preview_wallet_choices(bt_wallet_11)
		_check(bt_preview_11.get("ok") == true and bt_preview_11.get("event_id") == "button_trail",
			"Button Trail leave preview at 11 gold returns ok")
		var bt_leave_entry_11 := _preview_choice(bt_preview_11, "leave")
		_check(not bt_leave_entry_11.is_empty(), "leave entry present in preview at 11 gold")
		_check(bt_leave_entry_11.get("gold_delta") == -12 and bt_leave_entry_11.get("scraps_delta") == 2,
			"leave preview at 11 gold shows exact signed deltas")
		_check(bt_leave_entry_11.get("affordable") == false,
			"leave preview at 11 gold marks choice unaffordable")
		_check(_wallet_exact_int(bt_leave_entry_11.get("wallet"), 11, 0),
			"leave preview at 11 gold projects unchanged wallet {gold: 11, scraps: 0}")
		var bt_refusal_11 := RunEventChoice.new(bt_record).choose_with_wallet("leave", bt_wallet_11)
		_check(bt_refusal_11.get("ok") == false
			and bt_refusal_11.get("wallet") == bt_leave_entry_11.get("wallet")
			and bt_refusal_11.get("event_id") == ""
			and bt_refusal_11.get("choice_id") == "",
			"leave refusal at 11 gold matches preview forecast")
		_check(bt_service_11.is_valid() and not bt_service_11.is_claimed()
			and bt_service_11.get_event() == bt_event_11_before
			and bt_record == bt_event_11_before
			and bt_wallet_11 == bt_wallet_11_before,
			"leave preview at 11 gold leaves selector and inputs unchanged")
		_check(bt_local_11.state == bt_local_state_11 and randi() == bt_rng_11,
			"leave preview at 11 gold spends no RNG")

	# Explicit scarcity gates on all five requested authored spending IDs;
	# free/gain alternatives must remain available in the very same query.
	var scarcity := [
		{"event": "button_trail", "spend": "sell_buttons", "cost": 1, "free": "follow"},
		{"event": "loose_seam", "spend": "reinforce", "cost": 2, "free": "bypass"},
		{"event": "thimble_well", "spend": "lower_spool", "cost": 1, "free": "listen"},
		{"event": "frayed_signpost", "spend": "sell_arrowwork", "cost": 2, "free": "choose"},
		{"event": "needle_gate", "spend": "cut_bindings", "cost": 2, "free": "pass"},
	]
	for case_record in scarcity:
		var found := _matching(case_record["event"])
		_check(found.size() == 1, "scarcity case has its real event: " + case_record["event"])
		if found.size() != 1:
			continue
		for scraps in [0, 1, 2]:
			var preview := RunEventChoice.new(found[0]).preview_wallet_choices({"gold": 4, "scraps": scraps})
			var spend := _preview_choice(preview, case_record["spend"])
			var free := _preview_choice(preview, case_record["free"])
			_check(not spend.is_empty() and not free.is_empty()
				and spend.get("affordable") == (scraps >= case_record["cost"])
				and free.get("affordable") == true
				and (spend.get("wallet") as Dictionary).get("scraps", -1) >= 0,
				"named authored scarcity/free choice: " + case_record["event"] + "/" + str(scraps))


func _test_wallet_preview_fail_closed() -> void:
	var invalid_result := {"ok": false, "event_id": "", "choices": []}
	var invalid := RunEventChoice.new({"id": "bad", "choices": []})
	_check(not invalid.is_valid() and invalid.preview_wallet_choices({"gold": 4, "scraps": 2}) == invalid_result,
		"invalid event returns no previews")
	var matches := _matching("needle_gate")
	_check(matches.size() == 1, "malformed preview cases require real needle_gate event")
	if matches.size() != 1:
		return
	var original: Dictionary = matches[0].duplicate(true)
	var service := RunEventChoice.new(original)
	var invalid_wallets: Array = [
		null, 5, ["wallet"], {}, {"gold": 1}, {"gold": 1, "scraps": 0, "hp": 8},
		{"gold": -1, "scraps": 2}, {"gold": 2, "scraps": -1},
		{"gold": 1.0, "scraps": 2}, {"gold": 1, "scraps": 0.0},
		{"gold": true, "scraps": 2}, {"gold": "1", "scraps": 2},
	]
	for wallet in invalid_wallets:
		var before: Variant = wallet.duplicate(true) if wallet is Array or wallet is Dictionary else wallet
		var rng_expected := _rng_start(71001)
		_check(service.preview_wallet_choices(wallet) == invalid_result
			and wallet == before and not service.is_claimed() and service.is_valid()
			and service.get_event() == original,
			"malformed wallet preview fails closed and changes nothing: " + str(wallet))
		_check(randi() == rng_expected, "invalid preview wallet spends no RNG: " + str(wallet))

	# One malformed outcome denies only its choice; a legal alternate settles.
	for bad_outcome in [
		{"gold": "12", "scraps": -1},
		{"gold": -1.5, "scraps": -1},
		{"gold": 0, "scraps": -1.5},
		{"gold": 0},
		{"gold": 0, "scraps": -1, "extra": 1},
	]:
		var record: Dictionary = original.duplicate(true)
		record["choices"][0]["outcome"] = bad_outcome
		var before: Dictionary = record.duplicate(true)
		var instance := RunEventChoice.new(record)
		var rng_expected := _rng_start(71002)
		var preview := instance.preview_wallet_choices({"gold": 4, "scraps": 2})
		var bad := _preview_choice(preview, "examine")
		var good := _preview_choice(preview, "pass")
		_check(preview.get("ok") == true and preview.get("event_id") == "needle_gate"
			and (preview.get("choices") as Array).size() == (original["choices"] as Array).size()
			and bad.size() == 5 and bad.get("gold_delta") == null
			and bad.get("scraps_delta") == null and bad.get("affordable") == false
			and _wallet_exact_int(bad.get("wallet"), 4, 2)
			and good.get("affordable") == true and _wallet_exact_int(good.get("wallet"), 4, 2),
			"malformed authored outcome disables only its own preview: " + str(bad_outcome))
		var rejected := instance.choose_with_wallet("examine", {"gold": 4, "scraps": 2})
		_check(rejected.get("ok") == false and _wallet_exact_int(rejected.get("wallet"), 4, 2)
			and instance.is_valid() and not instance.is_claimed(),
			"malformed outcome still rejects actual commit without claiming")
		var recovery := instance.choose_with_wallet("pass", {"gold": 4, "scraps": 2})
		_check(recovery.get("ok") == true and recovery.get("wallet") == good["wallet"]
			and instance.is_claimed() and record == before and instance.get_event() == before,
			"valid authored alternative remains claimable after malformed preview")
		_check(instance.preview_wallet_choices({"gold": 4, "scraps": 2}) == invalid_result
			and randi() == rng_expected, "malformed preview and consumed state remain RNG-free")

	# A real spending ID is initially unaffordable; its zero-wallet preview
	# cannot award gold, and the same selector can still claim its free fallback.
	var poor := RunEventChoice.new(original)
	var poor_preview := poor.preview_wallet_choices({"gold": 4, "scraps": 0})
	var poor_spend := _preview_choice(poor_preview, "cut_bindings")
	_check(poor_spend.get("gold_delta") == 28 and poor_spend.get("scraps_delta") == -2
		and poor_spend.get("affordable") == false and _wallet_exact_int(poor_spend.get("wallet"), 4, 0)
		and poor.is_valid() and not poor.is_claimed(),
		"unaffordable spending preview grants neither money nor a claim")
	var recovered := poor.choose_with_wallet("pass", {"gold": 4, "scraps": 0})
	_check(recovered.get("ok") == true and _wallet_exact_int(recovered.get("wallet"), 4, 0)
		and poor.is_claimed() and poor.preview_wallet_choices({"gold": 4, "scraps": 0}) == invalid_result,
		"unaffordable preview keeps same selector available for free fallback")

	# Overflow is per-choice, not a reason to hide a valid remaining option.
	var gold_preview := RunEventChoice.new(original).preview_wallet_choices(
		{"gold": RunEventChoice.MAX_INT, "scraps": 2})
	_check(_preview_choice(gold_preview, "examine").get("affordable") == false
		and _wallet_exact_int(_preview_choice(gold_preview, "examine").get("wallet"), RunEventChoice.MAX_INT, 2)
		and _preview_choice(gold_preview, "pass").get("affordable") == true,
		"gold overflow denies one choice while zero delta remains affordable")
	var scraps_preview := RunEventChoice.new(original).preview_wallet_choices(
		{"gold": 4, "scraps": RunEventChoice.MAX_INT})
	_check(_preview_choice(scraps_preview, "pass").get("affordable") == true
		and _preview_choice(scraps_preview, "cut_bindings").get("affordable") == true,
		"max scrap balance safely admits a debit")
	var gain_matches := _matching("quiet_spool")
	_check(gain_matches.size() == 1, "scrap overflow uses real quiet_spool")
	if gain_matches.size() == 1:
		var gain_preview := RunEventChoice.new(gain_matches[0]).preview_wallet_choices(
			{"gold": 4, "scraps": RunEventChoice.MAX_INT})
		_check(_preview_choice(gain_preview, "watch").get("affordable") == false
			and _wallet_exact_int(_preview_choice(gain_preview, "watch").get("wallet"), 4, RunEventChoice.MAX_INT)
			and _preview_choice(gain_preview, "ignore").get("affordable") == true,
			"scrap overflow denies gain without blocking no-op option")


# ---------------------------------------------------------------------------
# V3-4 vitality Events: data/events/v3_vital_story_events.json plus the separate
# preview_vital_choices / choose_with_vitals transaction. Looked up by ID only.
# ---------------------------------------------------------------------------

const VITAL_EVENTS_PATH := "res://data/events/v3_vital_story_events.json"
const ROADSIDE_EVENTS_PATH := "res://data/events/v3_roadside_events.json"

# Independent authored expectations: choice rows are [id, text, gold, scraps, hp, max_hp].
const VITAL_REQUIRED := {
	"v3_lantern_quilt_infirmary": {
		"title": "The Lantern-Quilt Infirmary",
		"description": "A round, button-eyed nurse hangs warm quilts beside a midnight-teal lantern.",
		"choices": [
			["buy_bandages", "Pay 12 gold to dress one hero's wounds (+8 HP)", -12, 0, 8, 0],
			["blood_receipt", "Donate 4 HP for a purse of 18 gold", 18, 0, -4, 0],
			["leave", "Leave the lantern burning", 0, 0, 0, 0],
		],
	},
	"v3_button_heart_shrine": {
		"title": "The Button-Heart Shrine",
		"description": "A moss-cloaked doll tends a beating brass button stitched into a chapel wall.",
		"choices": [
			["reinforce_heart", "Spend 2 scraps to sew a lasting heart seam (+3 max HP)", 0, -2, 0, 3],
			["surrender_button", "Give up 2 max HP for 24 gold", 24, 0, 0, -2],
			["leave", "Let the little heart keep ticking", 0, 0, 0, 0],
		],
	},
	"v3_needle_thorn_garden": {
		"title": "The Needle-Thorn Garden",
		"description": "Oxblood roses made of fabric bristle with huge blunt sewing needles.",
		"choices": [
			["harvest_thorns", "Endure 6 HP loss to salvage 3 scraps", 0, 3, -6, 0],
			["buy_rose_balm", "Spend 10 gold on rose balm (+6 HP)", -10, 0, 6, 0],
			["leave", "Slip through the unpricked path", 0, 0, 0, 0],
		],
	},
	"v3_thimble_moon_sanctuary": {
		"title": "The Thimble-Moon Sanctuary",
		"description": "A bone-cream thimble glows above a congregation of velvet ragdolls.",
		"choices": [
			["moonblessing", "Pay 16 gold to strengthen a hero's seams (+2 max HP)", -16, 0, 0, 2],
			["tend_candles", "Lose 4 HP tending the candles; earn 20 gold", 20, 0, -4, 0],
			["leave", "Leave the sanctuary undisturbed", 0, 0, 0, 0],
		],
	},
	"v3_forgotten_straw_bed": {
		"title": "The Forgotten Straw Bed",
		"description": "A short scarecrow sleeps under a mustard quilt, its straw spilling onto a velvet pillow.",
		"choices": [
			["mend_straw", "Spend 2 scraps on fresh stuffing (+10 HP)", 0, -2, 10, 0],
			["sell_straw", "Give up 5 HP worth of straw for 22 gold", 22, 0, -5, 0],
			["leave", "Tuck the quilt in and depart", 0, 0, 0, 0],
		],
	},
	"v3_oxblood_stitch_oracle": {
		"title": "The Oxblood Stitch Oracle",
		"description": "A large-eyed doll reads the future in thread stretched across a crimson hoop.",
		"choices": [
			["surrender_seam", "Lose 1 max HP to receive 2 scraps", 0, 2, 0, -1],
			["weave_fortune", "Spend 30 gold to gain 4 lasting max HP", -30, 0, 0, 4],
			["leave", "Refuse the prophecy and go", 0, 0, 0, 0],
		],
	},
	"v3_lacebound_mirror": {
		"title": "The Lacebound Mirror",
		"description": "A plum-velvet mirror shows a button-eyed doll with one seam stronger and one button missing.",
		"choices": [
			["sew_reflection", "Spend 2 scraps; mend 4 HP and add 2 lasting max HP", 0, -2, 4, 2],
			["break_reflection", "Break the reflection for 25 gold; lose 2 max HP", 25, 0, 0, -2],
			["leave", "Cover the mirror and leave", 0, 0, 0, 0],
		],
	},
	"v3_ashthread_balcony": {
		"title": "The Ashthread Balcony",
		"description": "Beneath a midnight-teal bell, dolls sing through seams filled with glowing ash.",
		"choices": [
			["sing_into_ash", "Lose 5 HP to gain 2 lasting max HP", 0, 0, -5, 2],
			["cut_bell_cord", "Cut the bell cord for 19 gold; lose 3 HP", 19, 0, -3, 0],
			["leave", "Leave the choir singing", 0, 0, 0, 0],
		],
	},
	"v3_copper_moon_puppet": {
		"title": "The Copper-Moon Puppet",
		"description": "A giant round-headed marionette holds a warm copper moon between stitched hands.",
		"choices": [
			["take_moonlight", "Pay 18 gold; heal 6 HP and gain 1 max HP", -18, 0, 6, 1],
			["unhook_strings", "Salvage 3 scraps but lose 7 HP", 0, 3, -7, 0],
			["leave", "Let the puppet bow", 0, 0, 0, 0],
		],
	},
	"v3_bone_cream_wardrobe": {
		"title": "The Bone-Cream Wardrobe",
		"description": "A moonlit wardrobe offers one soft lining and one permanent bone-cream hem.",
		"choices": [
			["borrow_lining", "Spend 1 scrap; heal 8 HP but lose 1 max HP", 0, -1, 8, -1],
			["buy_permanent_hem", "Pay 25 gold for 3 lasting max HP", -25, 0, 0, 3],
			["leave", "Close the wardrobe doors", 0, 0, 0, 0],
		],
	},
	"v3_mosslit_seam_trial": {
		"title": "The Mosslit Seam Trial",
		"description": "A moss-clad ragdoll judge weighs thread against a glowing, stitched heart.",
		"choices": [
			["prove_courage", "Lose 6 HP; receive 2 scraps and 1 max HP", 0, 2, -6, 1],
			["purchase_verdict", "Pay 16 gold for 2 lasting max HP", -16, 0, 0, 2],
			["leave", "Decline the trial", 0, 0, 0, 0],
		],
	},
	"v3_duskwoven_cocoon": {
		"title": "The Duskwoven Cocoon",
		"description": "An enormous quilted moth cocoon glows rose-gold beside the road.",
		"choices": [
			["rest_in_cocoon", "Spend 2 scraps; heal 7 HP and gain 1 max HP", 0, -2, 7, 1],
			["harvest_silk", "Take 24 gold in silk; lose 1 max HP", 24, 0, 0, -1],
			["leave", "Leave the cocoon untouched", 0, 0, 0, 0],
		],
	},
}

var vital_catalog: Array = []


func _vital_state(gold: int, scraps: int, hp: int, max_hp: int) -> Dictionary:
	return {"gold": gold, "scraps": scraps, "hero": {"id": "warden", "hp": hp, "max_hp": max_hp}}


func _vital_state_is(state: Variant, gold: int, scraps: int, hp: int, max_hp: int) -> bool:
	if not state is Dictionary:
		return false
	var dict: Dictionary = state
	if dict.size() != 3 or not dict.get("hero") is Dictionary:
		return false
	var hero: Dictionary = dict["hero"]
	return (hero.size() == 3 and hero.get("id") == "warden"
		and typeof(dict.get("gold")) == TYPE_INT and int(dict["gold"]) == gold
		and typeof(dict.get("scraps")) == TYPE_INT and int(dict["scraps"]) == scraps
		and typeof(hero.get("hp")) == TYPE_INT and int(hero["hp"]) == hp
		and typeof(hero.get("max_hp")) == TYPE_INT and int(hero["max_hp"]) == max_hp)


func _vital_record(event_id: String) -> Dictionary:
	for entry in vital_catalog:
		if entry is Dictionary and entry.get("id") == event_id:
			return (entry as Dictionary).duplicate(true)
	return {}


func _load_events(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "events file opens: " + path)
	if file == null:
		return []
	var parser := JSON.new()
	var parse_result := parser.parse(file.get_as_text())
	file.close()
	_check(parse_result == OK and parser.data is Dictionary and (parser.data as Dictionary).get("events") is Array,
		"events file parses to {events: [...]}: " + path)
	if parse_result != OK or not parser.data is Dictionary or not (parser.data as Dictionary).get("events") is Array:
		return []
	return (parser.data as Dictionary)["events"]


func _test_vital_catalog_content() -> void:
	vital_catalog = _load_events(VITAL_EVENTS_PATH)
	_check(not vital_catalog.is_empty(), "vital story catalog is non-empty")
	for event_id in VITAL_REQUIRED:
		var found: Array = vital_catalog.filter(func(entry) -> bool:
			return entry is Dictionary and entry.get("id") == event_id)
		_check(found.size() == 1, "exactly one authored vital record: " + event_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		var expected: Dictionary = VITAL_REQUIRED[event_id]
		_check(record.size() == 4 and record.has("title") and record.has("description") and record.has("choices"),
			"vital record has exact top-level keys: " + event_id)
		_check(record.get("title") == expected["title"], "vital title: " + event_id)
		_check(record.get("description") == expected["description"], "vital description: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3, "vital record has three choices: " + event_id)
		if not choices is Array:
			continue
		var wanted: Array = expected["choices"]
		var seen := {}
		for choice in choices:
			_check(choice is Dictionary and choice.size() == 3 and choice.has("id") and choice.has("text")
				and choice.has("outcome") and choice.get("outcome") is Dictionary
				and choice["outcome"].size() == 4, "vital choice has id/text/four-key outcome: " + event_id)
			if choice is Dictionary and choice.get("id") is String:
				seen[choice["id"]] = choice
		_check(seen.size() == wanted.size(), "vital choice IDs are distinct: " + event_id)
		for row in wanted:
			var tag: String = event_id + "/" + row[0]
			_check(seen.has(row[0]), "vital choice present: " + tag)
			if not seen.has(row[0]) or not seen[row[0]].get("outcome") is Dictionary:
				continue
			var outcome: Dictionary = seen[row[0]]["outcome"]
			_check(seen[row[0]].get("text") == row[1], "vital choice text: " + tag)
			var keys := ["gold", "scraps", "hp", "max_hp"]
			for i in range(4):
				var raw: Variant = outcome.get(keys[i])
				_check(_is_integral_json_number(raw, true) and int(raw) == int(row[2 + i]),
					"vital outcome " + keys[i] + ": " + tag)
		var service := RunEventChoice.new(record)
		_check(service.is_valid() and not service.is_claimed(), "vital record builds a valid selector: " + event_id)

	# The vitality records stay out of the wallet-only rotation sources.
	var roadside := _load_events(ROADSIDE_EVENTS_PATH)
	for event_id in VITAL_REQUIRED:
		_check(_matching(event_id).is_empty(), "vital record absent from m04_events.json: " + event_id)
		_check(roadside.filter(func(entry) -> bool:
			return entry is Dictionary and entry.get("id") == event_id).is_empty(),
			"vital record absent from v3_roadside_events.json: " + event_id)
	for anchor in ["button_trail", "needle_gate", "v3_stitched_fog_carousel"]:
		_check(_matching(anchor).size() == 1, "legacy anchor still authored: " + anchor)
	for anchor in ["v3_raincoat_bridge"]:
		_check(roadside.filter(func(entry) -> bool:
			return entry is Dictionary and entry.get("id") == anchor).size() == 1,
			"roadside anchor still authored: " + anchor)


func _test_vital_branch_settlement() -> void:
	for event_id in VITAL_REQUIRED:
		var record := _vital_record(event_id)
		if record.is_empty():
			_check(false, "vital record available for settlement: " + event_id)
			continue
		var rows: Array = VITAL_REQUIRED[event_id]["choices"]
		var caller := _vital_state(40, 4, 25, 40)
		var rng_expected := _rng_start(72000)
		var preview_service := RunEventChoice.new(record.duplicate(true))
		var preview := preview_service.preview_vital_choices(caller)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id
			and (preview.get("choices") as Array).size() == 3, "vital preview lists three choices: " + event_id)
		_check(preview_service.is_valid() and not preview_service.is_claimed() and caller == _vital_state(40, 4, 25, 40),
			"vital preview consumes nothing and leaves caller state: " + event_id)
		for row in rows:
			var tag: String = event_id + "/" + row[0]
			var exp_max: int = 40 + int(row[5])
			var exp_hp: int = min(25 + int(row[4]), exp_max)
			var entry := _preview_choice(preview, row[0])
			_check(entry.size() == 7 and entry.get("gold_delta") == row[2] and entry.get("scraps_delta") == row[3]
				and entry.get("hp_delta") == row[4] and entry.get("max_hp_delta") == row[5]
				and entry.get("affordable") == true
				and _vital_state_is(entry.get("state"), 40 + int(row[2]), 4 + int(row[3]), exp_hp, exp_max),
				"funded vital forecast exact: " + tag)
			var visit_record := _vital_record(event_id)
			var service := RunEventChoice.new(visit_record)
			var input := _vital_state(40, 4, 25, 40)
			var result := service.choose_with_vitals(row[0], input)
			_check(result.size() == 4 and result.get("ok") == true and result.get("event_id") == event_id
				and result.get("choice_id") == row[0]
				and _vital_state_is(result.get("state"), 40 + int(row[2]), 4 + int(row[3]), exp_hp, exp_max),
				"funded vital commit exact: " + tag)
			_check(result.get("state") == entry.get("state"), "commit matches forecast: " + tag)
			_check(input == _vital_state(40, 4, 25, 40) and visit_record == _vital_record(event_id)
				and service.get_event() == _vital_record(event_id), "commit leaves caller inputs untouched: " + tag)
			_check(service.is_claimed() and not service.is_valid(), "vital commit consumes the visit: " + tag)
			# Detached returns: scribbling on them reaches neither the service nor later receipts.
			(result["state"] as Dictionary)["gold"] = 999
			((entry["state"]) as Dictionary)["hero"]["hp"] = 999
			var replay := service.choose_with_vitals(row[0], input)
			_check(replay.size() == 4 and replay.get("ok") == false and replay.get("event_id") == ""
				and replay.get("choice_id") == "" and replay.get("state") == _vital_state(40, 4, 25, 40),
				"vital replay rejected with unchanged detached state: " + tag)
			var other := service.choose_with_vitals("leave", input)
			_check(other.get("ok") == false and service.preview_vital_choices(input).get("ok") == false
				and service.choose(row[0]).get("ok") == false
				and service.choose_with_wallet(row[0], {"gold": 40, "scraps": 4}).get("ok") == false,
				"consumed visit rejects every other API: " + tag)
			(replay["state"] as Dictionary)["gold"] = 1
			_check(input == _vital_state(40, 4, 25, 40), "rejected state is detached from caller: " + tag)
		_check(randi() == rng_expected, "vital preview and commits spend no RNG: " + event_id)
		_check(RunEventChoice.new(_vital_record(event_id)).preview_vital_choices(caller)
			== RunEventChoice.new(_vital_record(event_id)).preview_vital_choices(caller),
			"vital previews are deterministic and detached from earlier scribbles: " + event_id)


func _test_vital_caps_and_bounds() -> void:
	var infirmary := RunEventChoice.new(_vital_record("v3_lantern_quilt_infirmary"))
	var healed := infirmary.choose_with_vitals("buy_bandages", _vital_state(40, 4, 39, 40))
	_check(healed.get("ok") == true and _vital_state_is(healed.get("state"), 28, 4, 40, 40),
		"positive healing clamps to max HP (39/40 + 8 -> 40/40)")
	var shrine := RunEventChoice.new(_vital_record("v3_button_heart_shrine"))
	var sewn := shrine.choose_with_vitals("reinforce_heart", _vital_state(40, 4, 25, 40))
	_check(sewn.get("ok") == true and _vital_state_is(sewn.get("state"), 40, 2, 25, 43),
		"a max HP increase alone does not heal (25/40 -> 25/43)")
	var cut := RunEventChoice.new(_vital_record("v3_button_heart_shrine")).choose_with_vitals(
		"surrender_button", _vital_state(40, 4, 40, 40))
	_check(cut.get("ok") == true and _vital_state_is(cut.get("state"), 64, 4, 38, 38),
		"a max HP cut pulls current HP down to the new maximum (40/40 -> 38/38)")
	var low_cut := RunEventChoice.new(_vital_record("v3_button_heart_shrine")).choose_with_vitals(
		"surrender_button", _vital_state(40, 4, 25, 40))
	_check(low_cut.get("ok") == true and _vital_state_is(low_cut.get("state"), 64, 4, 25, 38),
		"a max HP cut leaves lower current HP alone (25/40 -> 25/38)")
	var floor_cut := RunEventChoice.new(_vital_record("v3_oxblood_stitch_oracle")).choose_with_vitals(
		"surrender_seam", _vital_state(0, 0, 11, 11))
	_check(floor_cut.get("ok") == true and _vital_state_is(floor_cut.get("state"), 0, 2, 10, 10),
		"max HP may fall exactly to 10 (11/11 -> 10/10)")
	var straw_edge := _vital_record("v3_forgotten_straw_bed")
	_check(RunEventChoice.new(straw_edge).choose_with_vitals("sell_straw", _vital_state(0, 0, 6, 40)).get("ok") == true
		and RunEventChoice.new(straw_edge).choose_with_vitals("sell_straw", _vital_state(0, 0, 5, 40)).get("ok") == false,
		"an HP debit may leave exactly 1 HP but never 0")
	var thorns := RunEventChoice.new(_vital_record("v3_needle_thorn_garden")).choose_with_vitals(
		"harvest_thorns", _vital_state(40, 4, 25, 40))
	_check(thorns.get("ok") == true and _vital_state_is(thorns.get("state"), 40, 7, 19, 40),
		"HP debit for scraps settles exactly (25 -> 19, +3 scraps)")
	# Integer overflow is per-branch rejection, never wraparound.
	var big := RunEventChoice.MAX_INT
	var oracle := _vital_record("v3_thimble_moon_sanctuary")
	var over_max := RunEventChoice.new(oracle).preview_vital_choices(
		{"gold": 40, "scraps": 0, "hero": {"id": "warden", "hp": 5, "max_hp": big}})
	_check(_preview_choice(over_max, "moonblessing").get("affordable") == false
		and _preview_choice(over_max, "leave").get("affordable") == true,
		"max HP overflow denies only that branch")
	var over_hp := RunEventChoice.new(_vital_record("v3_forgotten_straw_bed")).preview_vital_choices(
		{"gold": 0, "scraps": 4, "hero": {"id": "warden", "hp": big, "max_hp": big}})
	_check(_preview_choice(over_hp, "mend_straw").get("affordable") == false
		and _preview_choice(over_hp, "sell_straw").get("affordable") == true,
		"HP overflow denies healing while a debit stays legal")
	var over_gold := RunEventChoice.new(_vital_record("v3_lantern_quilt_infirmary")).preview_vital_choices(
		{"gold": big, "scraps": 0, "hero": {"id": "warden", "hp": 5, "max_hp": 40}})
	_check(_preview_choice(over_gold, "blood_receipt").get("affordable") == false,
		"gold overflow denies the purse branch")


func _test_vital_unaffordable_then_leave() -> void:
	var cases := [
		{"state": _vital_state(0, 4, 25, 40), "rejected": [
			"buy_bandages", "buy_rose_balm", "moonblessing", "weave_fortune",
			"take_moonlight", "buy_permanent_hem", "purchase_verdict"]},
		{"state": _vital_state(40, 0, 25, 40), "rejected": [
			"reinforce_heart", "mend_straw",
			"sew_reflection", "borrow_lining", "rest_in_cocoon"]},
		{"state": _vital_state(40, 4, 1, 40), "rejected": [
			"blood_receipt", "harvest_thorns", "tend_candles", "sell_straw",
			"sing_into_ash", "cut_bell_cord", "unhook_strings", "prove_courage"]},
		{"state": _vital_state(40, 4, 10, 10), "rejected": [
			"surrender_button", "surrender_seam",
			"break_reflection", "borrow_lining", "harvest_silk"]},
	]
	for event_id in VITAL_REQUIRED:
		var rows: Array = VITAL_REQUIRED[event_id]["choices"]
		for case_data in cases:
			var state: Dictionary = case_data["state"]
			var rejected: Array = case_data["rejected"]
			var original: Dictionary = state.duplicate(true)
			var service := RunEventChoice.new(_vital_record(event_id))
			var rng_expected := _rng_start(72100)
			var preview := service.preview_vital_choices(state)
			for row in rows:
				var tag: String = event_id + "/" + row[0] + "/" + str(state)
				var entry := _preview_choice(preview, row[0])
				var expect_reject: bool = rejected.has(row[0])
				_check(not entry.is_empty() and entry.get("affordable") == not expect_reject
					and (not expect_reject or entry.get("state") == original), "affordability forecast: " + tag)
				if not expect_reject:
					continue
				var refusal := service.choose_with_vitals(row[0], state)
				_check(refusal.size() == 4 and refusal.get("ok") == false and refusal.get("event_id") == ""
					and refusal.get("choice_id") == "" and refusal.get("state") == original
					and state == original and service.is_valid() and not service.is_claimed(),
					"unaffordable branch rejected without consuming: " + tag)
			var leave := service.choose_with_vitals("leave", state)
			_check(leave.get("ok") == true and leave.get("event_id") == event_id and leave.get("state") == original
				and service.is_claimed(), "free leave still works on the same visit: " + event_id)
			_check(randi() == rng_expected, "rejections and leave spend no RNG: " + event_id)


## The appended story Events each carry one genuinely unaffordable or dangerous
## branch: an underfunded permanent hem, a lethal string salvage and a mirror
## bargain that would tear past the max-HP floor. Every refusal must leave the
## visit claimable so Leave still settles it.
func _test_vital_new_story_negatives() -> void:
	var cases := [
		{"event": "v3_bone_cream_wardrobe", "choice": "buy_permanent_hem",
			"state": _vital_state(24, 4, 25, 40)},
		{"event": "v3_copper_moon_puppet", "choice": "unhook_strings",
			"state": _vital_state(40, 4, 7, 40)},
		{"event": "v3_lacebound_mirror", "choice": "break_reflection",
			"state": _vital_state(40, 4, 10, 10)},
	]
	for case_data in cases:
		var event_id: String = case_data["event"]
		var choice_id: String = case_data["choice"]
		var tag: String = event_id + "/" + choice_id
		var record := _vital_record(event_id)
		_check(not record.is_empty(), "new story negative has its authored record: " + event_id)
		if record.is_empty():
			continue
		var state: Dictionary = case_data["state"]
		var original: Dictionary = state.duplicate(true)
		var record_before: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var rng_expected := _rng_start(72300)
		var preview := service.preview_vital_choices(state)
		var entry := _preview_choice(preview, choice_id)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id
			and not entry.is_empty() and entry.get("affordable") == false
			and entry.get("state") == original,
			"new story branch is unaffordable in preview: " + tag)
		var refusal := service.choose_with_vitals(choice_id, state)
		_check(refusal.size() == 4 and refusal.get("ok") == false
			and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
			and refusal.get("state") == original,
			"refused new story branch returns the unchanged detached snapshot: " + tag)
		_check(state == original and record == record_before and service.get_event() == record_before
			and service.is_valid() and not service.is_claimed(),
			"refused new story branch consumes no visit or caller state: " + tag)
		(refusal["state"] as Dictionary)["hero"]["hp"] = 999
		var leave_entry := _preview_choice(service.preview_vital_choices(state), "leave")
		_check(leave_entry.get("affordable") == true and leave_entry.get("state") == original,
			"leave stays forecastable after the new story refusal: " + tag)
		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"leave settles the new story visit after the refusal: " + tag)
		var replay := service.choose_with_vitals(choice_id, state)
		_check(replay.get("ok") == false and replay.get("state") == original
			and state == original,
			"new story visit rejects replay after leave: " + tag)
		_check(randi() == rng_expected, "new story refusal, leave and replay spend no RNG: " + tag)


func _test_vital_malformed_inputs() -> void:
	var record := _vital_record("v3_lantern_quilt_infirmary")
	var good := _vital_state(40, 4, 25, 40)
	var denied := {"ok": false, "event_id": "", "choices": []}
	var bad_states: Array = [
		null, 5, "state", [good], {}, {"gold": 40, "scraps": 4},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 25, "max_hp": 40}, "extra": 1},
		{"gold": 40, "scraps": 4, "hero": null}, {"gold": 40, "scraps": 4, "hero": "warden"},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 25}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 25, "max_hp": 40, "mood": 1}},
		{"gold": 40, "scraps": 4, "hero": {"id": "", "hp": 25, "max_hp": 40}},
		{"gold": 40, "scraps": 4, "hero": {"id": "  ", "hp": 25, "max_hp": 40}},
		{"gold": 40, "scraps": 4, "hero": {"id": 7, "hp": 25, "max_hp": 40}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 0, "max_hp": 40}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": -3, "max_hp": 40}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 41, "max_hp": 40}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 9, "max_hp": 9}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 25.0, "max_hp": 40}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 25, "max_hp": 40.0}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": "25", "max_hp": 40}},
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": true, "max_hp": 40}},
		{"gold": -1, "scraps": 4, "hero": {"id": "warden", "hp": 25, "max_hp": 40}},
		{"gold": 40, "scraps": -1, "hero": {"id": "warden", "hp": 25, "max_hp": 40}},
		{"gold": 40.0, "scraps": 4, "hero": {"id": "warden", "hp": 25, "max_hp": 40}},
		{"gold": 40, "scraps": "4", "hero": {"id": "warden", "hp": 25, "max_hp": 40}},
		{"gold": null, "scraps": 4, "hero": {"id": "warden", "hp": 25, "max_hp": 40}},
	]
	for bad in bad_states:
		var before: Variant = bad.duplicate(true) if bad is Dictionary or bad is Array else bad
		var service := RunEventChoice.new(record.duplicate(true))
		var rng_expected := _rng_start(72200)
		var refusal := service.choose_with_vitals("buy_bandages", bad)
		_check(refusal.size() == 4 and refusal.get("ok") == false and refusal.get("event_id") == ""
			and refusal.get("choice_id") == "" and refusal.get("state") == {},
			"malformed snapshot rejected with empty state: " + str(bad))
		_check(service.preview_vital_choices(bad) == denied and bad == before
			and service.is_valid() and not service.is_claimed() and randi() == rng_expected,
			"malformed snapshot preview denied without effects: " + str(bad))
		_check(service.choose_with_vitals("leave", good).get("ok") == true,
			"visit survives a malformed snapshot: " + str(bad))

	# Blank, unknown and mistyped choice IDs reject with a detached valid state.
	for bad_id in ["", "  ", "no_such_choice", "BUY_BANDAGES", null, 5, ["leave"]]:
		var service := RunEventChoice.new(record.duplicate(true))
		var refusal := service.choose_with_vitals(bad_id, good)
		_check(refusal.get("ok") == false and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
			and refusal.get("state") == good and service.is_valid() and not service.is_claimed(),
			"bad choice ID rejected without consuming: " + str(bad_id))
		_check(service.choose_with_vitals("leave", good).get("ok") == true, "leave after bad ID: " + str(bad_id))

	# Torn (0 HP) heroes cannot be acted on, even for a free Leave.
	var torn := RunEventChoice.new(record.duplicate(true))
	var torn_state := {"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 0, "max_hp": 40}}
	_check(torn.choose_with_vitals("leave", torn_state).get("ok") == false and torn.is_valid(),
		"a Torn hero is never a valid target")

	# Outcome shapes: the vitality API needs exactly the four keys; the wallet API exactly two.
	var bad_outcomes: Array = [
		{"gold": -12, "scraps": 0},
		{"gold": -12, "scraps": 0, "hp": 8},
		{"gold": -12, "scraps": 0, "hp": 8, "max_hp": 0, "extra": 0},
		{"gold": -12, "scraps": 0, "hp": "8", "max_hp": 0},
		{"gold": -12, "scraps": 0, "hp": 8.5, "max_hp": 0},
		{"gold": -12, "scraps": 0, "hp": 8, "max_hp": null},
		{"gold": -12, "scraps": 0, "hp": 8, "mx": 0},
		"outcome",
	]
	for bad_outcome in bad_outcomes:
		var broken := _vital_record("v3_lantern_quilt_infirmary")
		broken["choices"][0]["outcome"] = bad_outcome
		var service := RunEventChoice.new(broken)
		var preview := service.preview_vital_choices(good)
		var entry := _preview_choice(preview, "buy_bandages")
		_check(preview.get("ok") == true and entry.get("affordable") == false and entry.get("hp_delta") == null
			and entry.get("state") == good and _preview_choice(preview, "leave").get("affordable") == true,
			"malformed outcome denies only its branch: " + str(bad_outcome))
		var refusal := service.choose_with_vitals("buy_bandages", good)
		_check(refusal.get("ok") == false and refusal.get("state") == good and not service.is_claimed(),
			"malformed outcome never settles: " + str(bad_outcome))
		_check(service.choose_with_vitals("leave", good).get("ok") == true, "leave after malformed outcome")
	var float_record := _vital_record("v3_lantern_quilt_infirmary")
	float_record["choices"][0]["outcome"] = {"gold": -12.0, "scraps": 0.0, "hp": 8.0, "max_hp": 0.0}
	_check(RunEventChoice.new(float_record).choose_with_vitals("buy_bandages", good).get("state")
		== _vital_state(28, 4, 33, 40), "integral JSON floats normalize to exact integers")

	# Wallet-only records are rejected by the vitality API, and vitality records by the wallet API.
	var wallet_only := RunEventChoice.new(_matching("needle_gate")[0])
	var wallet_preview := wallet_only.preview_vital_choices(good)
	_check(wallet_preview.get("ok") == true and (wallet_preview["choices"] as Array).size() == 3, "wallet-only event preview keeps slots")
	for entry in wallet_preview["choices"]:
		_check(entry.get("affordable") == false and entry.get("hp_delta") == null and entry.get("state") == good,
			"wallet-only outcome is never padded into a vitality outcome: " + str(entry.get("choice_id")))
	_check(wallet_only.choose_with_vitals("pass", good).get("ok") == false and not wallet_only.is_claimed(),
		"wallet-only commit rejected by choose_with_vitals")
	_check(wallet_only.choose_with_wallet("pass", {"gold": 4, "scraps": 0}).get("ok") == true,
		"legacy wallet commit still works on the same visit")
	var vital_for_wallet := RunEventChoice.new(record.duplicate(true))
	var wallet_view := vital_for_wallet.preview_wallet_choices({"gold": 40, "scraps": 4})
	for entry in wallet_view["choices"]:
		_check(entry.get("affordable") == false and entry.get("gold_delta") == null,
			"wallet preview rejects extra vitality outcome fields: " + str(entry.get("choice_id")))
	_check(vital_for_wallet.choose_with_wallet("leave", {"gold": 40, "scraps": 4}).get("ok") == false
		and not vital_for_wallet.is_claimed(), "wallet commit rejects extra vitality outcome fields")
	_check(vital_for_wallet.choose("leave").get("ok") == true and vital_for_wallet.choose_with_vitals("leave", good).get("ok") == false,
		"legacy choose shares the single visit latch with vitality commits")

	# Caller/source isolation for the authored record and the snapshot.
	var source := _vital_record("v3_lantern_quilt_infirmary")
	var live := RunEventChoice.new(source)
	source["choices"][0]["outcome"]["hp"] = 99
	source["title"] = "scribble"
	var scribbled := {"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 25, "max_hp": 40}}
	var scribble_preview := live.preview_vital_choices(scribbled)
	scribbled["hero"]["hp"] = 1
	_check(_vital_state_is(_preview_choice(scribble_preview, "buy_bandages").get("state"), 28, 4, 33, 40)
		and live.get_event() == _vital_record("v3_lantern_quilt_infirmary"),
		"source record and snapshot mutations never reach the service or earlier previews")
	# Invalid construction fails closed.
	var invalid := RunEventChoice.new({"id": "bad", "choices": []})
	_check(invalid.preview_vital_choices(good) == denied and invalid.choose_with_vitals("leave", good).get("state") == good
		and invalid.choose_with_vitals("leave", good).get("ok") == false, "invalid event fails closed on vitality APIs")
