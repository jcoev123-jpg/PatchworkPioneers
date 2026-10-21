extends SceneTree
## Deterministic headless test for RunEventChoice (M04 authored event selector).
## Covers the six authored events in data/events/m04_events.json (looked up by
## ID, never by catalog size/order/index), detached snapshots, one-claim
## semantics, fail-closed invalid records, replay rejection and zero RNG use.

const EVENTS_PATH := "res://data/events/m04_events.json"

const REQUIRED := {
	"button_trail": {
		"title": "The Button Trail",
		"description": "Mismatched buttons form a trail across the grass.",
		"choices": {"follow": "Follow the button trail", "leave": "Leave the buttons untouched"},
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
		"choices": {"examine": "Examine the gate", "pass": "Pass without stopping"},
	},
}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []


func _initialize() -> void:
	_test_catalog_content()
	_test_authored_claim_flow()
	_test_invalid_records()
	_test_bad_choice_recovery_and_replay()
	_test_no_rng_consumption()
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
	for entry in catalog:
		_check(entry is Dictionary, "every event record is an object")
	for event_id in REQUIRED:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "exactly one authored event record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = REQUIRED[event_id]
		_check(record.get("title") == expected["title"], "authored title: " + event_id)
		_check(record.get("description") == expected["description"], "authored description: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array, "choices array present: " + event_id)
		if not choices is Array:
			continue
		_check((choices as Array).size() >= 2 and (choices as Array).size() <= 3,
			"2 to 3 choices: " + event_id)
		var seen := {}
		var by_id := {}
		for choice in choices:
			if not choice is Dictionary:
				_check(false, "choice record is an object: " + event_id)
				continue
			var choice_id: Variant = (choice as Dictionary).get("id")
			var choice_text: Variant = (choice as Dictionary).get("text")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"nonblank string choice ID: " + event_id)
			_check(choice_text is String and not (choice_text as String).strip_edges().is_empty(),
				"nonblank string choice text: " + event_id)
			if not choice_id is String:
				continue
			_check(not seen.has(choice_id), "distinct choice IDs: " + event_id)
			seen[choice_id] = true
			by_id[choice_id] = choice_text
		var wanted: Dictionary = expected["choices"]
		for choice_id in wanted:
			_check(by_id.has(choice_id), "required choice present: " + event_id + "/" + choice_id)
			_check(by_id.get(choice_id) == wanted[choice_id],
				"authored choice text: " + event_id + "/" + choice_id)
		_check(by_id.size() == wanted.size(), "no unstated choice IDs: " + event_id)
		var service := RunEventChoice.new(record)
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
		var caller_record: Dictionary = matches[0]
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
