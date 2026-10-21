extends SceneTree
## Deterministic headless test for RunEventChoice (M04 authored event selector).
## Covers the six authored events in data/events/m04_events.json (looked up by
## ID, never by catalog size/order/index), Button Trail and Needle Gate wallets,
## detached snapshots, one-claim semantics, fail-closed invalid records and
## outcomes, recovery after failed preflight, replay rejection and zero RNG use.

const EVENTS_PATH := "res://data/events/m04_events.json"

const REQUIRED := {
	"button_trail": {
		"title": "The Button Trail",
		"description": "Mismatched buttons form a trail across the grass.",
		"choices": {"follow": "Follow the button trail", "leave": "Leave the buttons untouched"},
		"outcomes": {
			"follow": {"gold": 0, "scraps": 1},
			"leave": {"gold": 5, "scraps": 0},
		},
	},
	"loose_seam": {
		"title": "The Loose Seam",
		"description": "A strip of patched ground has come unstitched.",
		"choices": {"mend": "Inspect the loose stitching", "bypass": "Walk around the seam"},
	},
	"thimble_well": {
		"title": "The Thimble Well",
		"description": "A silver thimble rests beside a dry stone well.",
		"choices": {"listen": "Listen at the well", "depart": "Continue along the road"},
	},
	"frayed_signpost": {
		"title": "The Frayed Signpost",
		"description": "Three cloth arrows flap from a crooked signpost.",
		"choices": {"read": "Read the faded arrows", "choose": "Choose the clearer path"},
	},
	"quiet_spool": {
		"title": "The Quiet Spool",
		"description": "An abandoned spool spins without a breeze.",
		"choices": {"watch": "Watch the thread unwind", "ignore": "Leave the spool alone"},
	},
	"needle_gate": {
		"title": "The Needle Gate",
		"description": "Crossed needles mark a narrow wooden gate.",
		"choices": {"examine": "Spend 1 scrap to unpick the gate and claim 12 gold", "pass": "Pass without stopping"},
		"outcomes": {
			"examine": {"gold": 12, "scraps": -1},
			"pass": {"gold": 0, "scraps": 0},
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
	_test_needle_gate_wallet_settlement()
	_test_signed_scraps_boundaries()
	_test_wallet_preflight_rejections_and_recovery()
	_test_invalid_records()
	_test_bad_choice_recovery_and_replay()
	_test_no_rng_consumption()
	_test_seeded_replay_and_wallet_rng()
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
			_check((choices as Array).size() == 2 and (choices as Array).map(func(c): return c.get("id")) == ["examine", "pass"],
				"Needle Gate retains exactly examine then pass in authored order")
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
					_check(_is_integral_json_number(raw_gold),
						"authored outcome gold is integral nonnegative: " + event_id + "/" + choice_id)
					_check(_is_integral_json_number(raw_scraps, true),
						"authored outcome scraps is integral signed: " + event_id + "/" + choice_id)
					if _is_integral_json_number(raw_gold) and _is_integral_json_number(raw_scraps, true):
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

	# Branch 2: leave (+5 gold, +0 scraps) from {gold: 12, scraps: 0} -> {gold: 17, scraps: 0}
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
	_check(_wallet_exact_int(leave_result.get("wallet"), 17, 0),
		"leave settles exact integer wallet {gold: 17, scraps: 0}")
	_check(_wallet_exact_int(leave_wallet, 12, 0), "leave does not mutate caller input wallet")
	_check(leave_input_event == original_event, "leave does not mutate caller input event")
	_check(leave_service.get_event() == original_event, "leave does not mutate internal event snapshot")
	_check(leave_service.is_claimed() and not leave_service.is_valid(),
		"leave latches claim and marks selector consumed")
	_check(randi() == leave_rng, "leave wallet settlement spends no global RNG")

	var leave_replay := leave_service.choose_with_wallet("follow", {"gold": 17, "scraps": 0})
	_check(_wallet_shape_ok(leave_replay) and leave_replay.get("ok", true) == false
		and _wallet_exact_int(leave_replay.get("wallet"), 17, 0),
		"subsequent choose_with_wallet after leave is rejected with unchanged wallet")

	# Explicit integer vs JSON-float outcome normalization check.
	var int_event: Dictionary = original_event.duplicate(true)
	int_event["choices"][0]["outcome"] = {"gold": 0, "scraps": 1}
	int_event["choices"][1]["outcome"] = {"gold": 5, "scraps": 0}
	var float_event: Dictionary = original_event.duplicate(true)
	float_event["choices"][0]["outcome"] = {"gold": 0.0, "scraps": 1.0}
	float_event["choices"][1]["outcome"] = {"gold": 5.0, "scraps": 0.0}
	var int_res := RunEventChoice.new(int_event).choose_with_wallet("leave", {"gold": 12, "scraps": 0})
	var float_res := RunEventChoice.new(float_event).choose_with_wallet("leave", {"gold": 12, "scraps": 0})
	_check(int_res == float_res and _wallet_exact_int(float_res.get("wallet"), 17, 0),
		"JSON float outcome values normalize to exact ints matching integer outcomes")



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


func _test_signed_scraps_boundaries() -> void:
	var matches := _matching("needle_gate")
	_check(matches.size() == 1, "exactly one Needle Gate for signed amount probes")
	if matches.size() != 1:
		return
	var authored: Dictionary = matches[0]
	# Both integer and JSON-style integral float deltas are admitted, including -1.
	var accepted := [
		{"label": "int debit", "gold": 1, "scraps": -1, "wallet": {"gold": 8, "scraps": 1}, "gold_after": 9, "scraps_after": 0},
		{"label": "JSON-float debit", "gold": 1.0, "scraps": -1.0, "wallet": {"gold": 8, "scraps": 1}, "gold_after": 9, "scraps_after": 0},
		{"label": "int positive scraps", "gold": 0, "scraps": 1, "wallet": {"gold": 8, "scraps": 0}, "gold_after": 8, "scraps_after": 1},
		{"label": "JSON-float positive scraps", "gold": 0.0, "scraps": 1.0, "wallet": {"gold": 8, "scraps": 0}, "gold_after": 8, "scraps_after": 1},
		{"label": "free zeros", "gold": 0.0, "scraps": 0.0, "wallet": {"gold": 8, "scraps": 0}, "gold_after": 8, "scraps_after": 0},
		{"label": "max int debit", "gold": 0, "scraps": -RunEventChoice.MAX_INT, "wallet": {"gold": 8, "scraps": RunEventChoice.MAX_INT}, "gold_after": 8, "scraps_after": 0},
		{"label": "max safe float debit", "gold": 0.0, "scraps": -9007199254740992.0, "wallet": {"gold": 8, "scraps": 9007199254740992}, "gold_after": 8, "scraps_after": 0},
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
		{"label": "negative int gold", "gold": -1, "scraps": -1},
		{"label": "negative float gold", "gold": -1.0, "scraps": -1.0},
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

	# Overflow guard on otherwise valid wallet: leave adds 5 gold, follow adds 1 scrap.
	var max_gold_wallet := {"gold": RunEventChoice.MAX_INT, "scraps": 0}
	var overflow_gold := service.choose_with_wallet("leave", max_gold_wallet)
	_check(_wallet_shape_ok(overflow_gold) and overflow_gold.get("ok", true) == false
		and _wallet_exact_int(overflow_gold.get("wallet"), RunEventChoice.MAX_INT, 0)
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

	# 2. The four placeholder events reject choose_with_wallet without claiming, then still accept legacy choose().
	for event_id in REQUIRED:
		if event_id in ["button_trail", "needle_gate"]:
			continue
		var event_matches := _matching(event_id)
		if event_matches.size() != 1:
			continue
		var record: Dictionary = event_matches[0].duplicate(true)
		var first_id: String = (record["choices"][0] as Dictionary)["id"]
		var placeholder_service := RunEventChoice.new(record)
		var rng_expected := _rng_start(64300)
		var wallet_attempt := placeholder_service.choose_with_wallet(first_id, {"gold": 12, "scraps": 0})
		_check(_wallet_shape_ok(wallet_attempt) and wallet_attempt.get("ok", true) == false,
			"placeholder event rejects choose_with_wallet: " + event_id)
		_check(_wallet_exact_int(wallet_attempt.get("wallet"), 12, 0),
			"placeholder rejection preserves detached wallet: " + event_id)
		_check(not placeholder_service.is_claimed() and placeholder_service.is_valid(),
			"placeholder wallet rejection does not consume visit: " + event_id)
		var legacy_claim := placeholder_service.choose(first_id)
		_check(_shape_ok(legacy_claim) and legacy_claim.get("ok", false) == true
			and legacy_claim.get("event_id", "") == event_id
			and legacy_claim.get("choice_id", "") == first_id,
			"placeholder event still accepts legacy choose() after wallet rejection: " + event_id)
		_check(placeholder_service.is_claimed() and not placeholder_service.is_valid(),
			"placeholder legacy claim latches once: " + event_id)
		_check(randi() == rng_expected, "placeholder rejection + legacy claim spend no RNG: " + event_id)

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
		"negative int gold": {"outcome": {"gold": -1, "scraps": 1}},
		"negative int scraps": {"outcome": {"gold": 0, "scraps": -1}},
		"negative float gold": {"outcome": {"gold": -1.0, "scraps": 1.0}},
		"negative float scraps": {"outcome": {"gold": 0.0, "scraps": -2.0}},
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
			and _wallet_exact_int(recovered_leave.get("wallet"), 17, 0),
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
	# unaffordable Needle Gate attempt before the successful free pass.
	for event_id in ["button_trail", "needle_gate"]:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "seeded replay record exists exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var authored_record: Dictionary = matches[0]
		var choices := ["follow", "leave"] if event_id == "button_trail" else ["examine", "pass"]
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
				var wallet := {"gold": 12, "scraps": 0} if event_id == "button_trail" else {"gold": 8, "scraps": 1 if choice_id == "examine" else 0}
				var wallet_before: Dictionary = wallet.duplicate(true)
				var preflight_reject := instance.choose_with_wallet("not_a_choice", wallet)
				var denied_debit: Dictionary = {}
				if event_id == "needle_gate" and choice_id == "pass":
					denied_debit = instance.choose_with_wallet("examine", wallet)
					_check(_wallet_shape_ok(denied_debit) and denied_debit.get("ok") == false
						and _wallet_exact_int(denied_debit.get("wallet"), 8, 0)
						and instance.is_valid() and not instance.is_claimed(),
						"seeded no-scrap debit refused before free pass")
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
