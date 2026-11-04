extends SceneTree
## Scene-free checks for the S6-ready Stitched Event consequence helper.
## Every snapshot, outcome and receipt here is plain data: no scene nodes, no
## run state, no reserved S1b rules file and no live Event routing.

var failures: Array[String] = []
var checks: int = 0

const FOUR := ["warden", "seamstress", "tinker", "button_golem"]
const REQUIRED_IDS := [
	"warden",
	"seamstress",
	"tinker",
	"lantern_monk",
	"rag_duelist",
	"scarecrow",
	"yarn_ranger",
	"button_golem",
]


func _initialize() -> void:
	var starter: Array = _load_json_array("res://data/heroes/starter_party.json")
	var v3_roster: Array = _load_json_array("res://data/heroes/v3_party_roster.json")
	_check(not starter.is_empty(), "loads the actual authored starter party")
	_check(not v3_roster.is_empty(), "loads the actual authored v3 party roster")
	_test_canonical_ids(starter, v3_roster)
	_test_party_and_hero_previews()
	_test_candle_bounds()
	_test_leave_and_receipt_parity()
	_test_unavailable_hero_and_retry()
	_test_invalid_snapshots()
	_test_invalid_events()
	_test_invalid_outcomes()
	_test_unoffered_and_replay()
	_test_fray_thresholds()
	_test_detachment_and_rng()
	_finish()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("run_stitched_event_consequence_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_stitched_event_consequence_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _load_json_array(path: String) -> Array:
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


func _event(choices: Array, event_id: String = "ev_stitched_candle_bargain") -> Dictionary:
	return {
		"id": event_id,
		"title": "The Candle Bargain",
		"description": "A stitched stranger trades light for loosened thread.",
		"choices": choices,
	}


func _choice(choice_id: String, text: String, effect: Dictionary) -> Dictionary:
	return {"id": choice_id, "text": text, "stitched_effect": effect}


func _effect(candle: int, fray: int, target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {"candle": candle, "fray": fray, "target": target}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


## The documented sample bargain: +25 candle and -25 fray, plus a hero-targeted
## variant and the zero-delta Leave that uses the same fields.
func _bargain_event() -> Dictionary:
	return _event([
		_choice("bargain", "Tithe the wick for loosened seams.", _effect(25, -25)),
		_choice("tend", "Tend the seamstress's seam.", _effect(25, -25, "hero", "seamstress")),
		_choice("leave", "Leave the candle alone.", _effect(0, 0)),
	])


func _snapshot(candle: int, hero_pairs: Array) -> Dictionary:
	var party: Array = []
	for pair in hero_pairs:
		party.append({"id": pair[0], "fray": pair[1]})
	return {"candle": candle, "party": party}


func _four(candle: int, frays: Array) -> Dictionary:
	var pairs: Array = []
	for index in range(frays.size()):
		pairs.append([FOUR[index], frays[index]])
	return _snapshot(candle, pairs)


func _entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _denied_preview() -> Dictionary:
	return {"ok": false, "event_id": "", "candle": 0, "choices": []}


func _refusal(candle: int) -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"target": "",
		"hero_id": "",
		"candle": candle,
		"fray": {},
	}


func _receipt_keys(receipt: Dictionary) -> Array:
	var keys: Array = receipt.keys()
	keys.sort()
	return keys


func _assert_rejected(service: RunStitchedEventConsequence, choice_id: Variant,
		snapshot: Variant, expected_candle: int, label: String) -> void:
	var before: Variant = snapshot.duplicate(true) if snapshot is Dictionary else snapshot
	var was_claimed := service.is_claimed()
	var result: Dictionary = service.choose(choice_id, snapshot)
	_check(result == _refusal(expected_candle), label + ": uniform refusal, no forged receipt")
	_check(service.is_claimed() == was_claimed, label + ": refusal never latches or consumes")
	_check(snapshot == before, label + ": refusal leaves the caller's snapshot untouched")


func _test_canonical_ids(starter: Array, v3_roster: Array) -> void:
	for hero in starter:
		_check(RunStitchedEventConsequence.CANONICAL_HERO_IDS.has(hero.get("id")),
			"starter identity is canonical: " + str(hero.get("id")))
	for hero in v3_roster:
		_check(RunStitchedEventConsequence.CANONICAL_HERO_IDS.has(hero.get("id")),
			"v3 roster identity is canonical: " + str(hero.get("id")))
	# Presence of each required identity, never a catalog total.
	for hero_id in REQUIRED_IDS:
		_check(RunStitchedEventConsequence.CANONICAL_HERO_IDS.has(hero_id),
			"canonical roster contains " + hero_id)
		var service := RunStitchedEventConsequence.new(_event([
			_choice("tend", "Tend that hero.", _effect(25, -25, "hero", hero_id)),
			_choice("leave", "Leave.", _effect(0, 0)),
		]))
		var preview: Dictionary = service.preview(_snapshot(50, [[hero_id, 120]]))
		var entry := _entry(preview, "tend")
		_check(entry.get("available") == true and entry.get("hero_id") == hero_id,
			"canonical hero can be named by a hero target: " + hero_id)
		_check(entry.get("fray") == {hero_id: -25},
			"hero target affects only the named canonical hero: " + hero_id)
	# An unauthored identity is never a valid target or snapshot hero.
	var unknown := RunStitchedEventConsequence.new(_event([
		_choice("tend", "Tend that hero.", _effect(25, -25, "hero", "porcelain_doll")),
		_choice("leave", "Leave.", _effect(0, 0)),
	]))
	_check(_entry(unknown.preview(_snapshot(50, [["warden", 10]])), "tend").get("available") == false,
		"an unauthored hero id is a malformed outcome")


func _test_party_and_hero_previews() -> void:
	var snapshot := _four(40, [95, 0, 50, 200])
	var original := snapshot.duplicate(true)
	var service := RunStitchedEventConsequence.new(_bargain_event())
	_check(service.is_valid() and not service.is_claimed(), "a schema-valid bargain opens unclaimed")
	var preview := service.preview(snapshot)
	_check(preview.get("ok") == true and preview.get("event_id") == "ev_stitched_candle_bargain",
		"preflight names the authored event")
	_check(preview.get("candle") == 40, "preflight reports the untouched base candle")
	_check(preview.get("choices", []).size() == 3, "preflight keeps every authored choice slot")
	var party_entry := _entry(preview, "bargain")
	_check(party_entry.get("target") == "party" and party_entry.get("hero_id") == "",
		"a party bargain names no single hero")
	_check(party_entry.get("available") == true and party_entry.get("candle_delta") == 25
		and party_entry.get("fray_delta") == -25,
		"a party bargain exposes the authored +25 candle and -25 fray")
	_check(party_entry.get("candle") == 65, "a party bargain projects candle 40 + 25 = 65")
	_check(party_entry.get("fray") == {
		"warden": -25, "seamstress": -25, "tinker": -25, "button_golem": -25,
	}, "a party bargain touches each of the four active heroes exactly once")
	var hero_entry := _entry(preview, "tend")
	_check(hero_entry.get("target") == "hero" and hero_entry.get("hero_id") == "seamstress",
		"a hero bargain names its authored hero")
	_check(hero_entry.get("fray") == {"seamstress": -25},
		"a hero bargain touches only the named active hero")
	_check(hero_entry.get("candle") == 65, "a hero bargain projects the same authored candle delta")
	var leave_entry := _entry(preview, "leave")
	_check(leave_entry.get("available") == true and leave_entry.get("candle") == 40
		and leave_entry.get("fray") == {},
		"Leave projects the original candle and an empty fray map")
	_check(snapshot == original, "preflight never mutates the caller snapshot")
	_check(service.preview(snapshot) == preview, "preflight is deterministic across calls")
	var polluted := service.preview(snapshot)
	polluted["choices"][0]["fray"]["warden"] = 999
	polluted["choices"][1]["candle"] = -1
	polluted["choices"][2]["available"] = false
	_check(service.preview(snapshot) == preview, "a mutated preview never aliases a later one")
	_check(not service.is_claimed(), "preflight consumes nothing")
	for size in range(1, 5):
		var frays: Array = []
		for index in range(size):
			frays.append(100)
		var sized_preview := RunStitchedEventConsequence.new(_bargain_event()).preview(_four(50, frays))
		var sized_party: Dictionary = _entry(sized_preview, "bargain").get("fray", {})
		_check(sized_party.size() == size,
			"a party of %d projects exactly one fray intent per active hero" % size)
		_check(_entry(sized_preview, "tend").get("available") == (size >= 2),
			"hero bargain availability follows the active party (%d heroes)" % size)


func _test_candle_bounds() -> void:
	var cases := [
		[100, 25, 100], [90, 25, 100], [0, 25, 25], [10, -25, 0],
		[40, -25, 15], [0, -1, 0], [100, 1, 100], [50, 0, 50],
	]
	for case in cases:
		var snapshot := _snapshot(case[0], [["warden", 60], ["seamstress", 60]])
		var service := RunStitchedEventConsequence.new(_event([
			_choice("bargain", "Bargain.", _effect(case[1], -25)),
			_choice("leave", "Leave.", _effect(0, 0)),
		]))
		var entry := _entry(service.preview(snapshot), "bargain")
		_check(entry.get("candle") == case[2],
			"candle %d %+d clamps to %d" % [case[0], case[1], case[2]])
		var receipt := service.choose("bargain", snapshot)
		_check(receipt.get("ok") == true and receipt.get("candle") == case[2],
			"commit agrees with preview at candle %d %+d" % [case[0], case[1]])
		_check(snapshot.get("candle") == case[0],
			"a clamped projection never rewrites the caller candle")
	var huge := _snapshot(100, [["warden", 10]])
	var extreme := RunStitchedEventConsequence.new(_event([
		_choice("up", "Up.", _effect(9223372036854775807, 0)),
		_choice("down", "Down.", _effect(-9223372036854775807, 0)),
	]))
	_check(_entry(extreme.preview(huge), "up").get("candle") == 100,
		"an extreme positive delta clamps to 100 without overflow")
	_check(_entry(extreme.preview(huge), "down").get("candle") == 0,
		"an extreme negative delta clamps to 0 without overflow")


func _test_leave_and_receipt_parity() -> void:
	var snapshot := _four(40, [95, 0, 50, 200])
	var original := snapshot.duplicate(true)
	for choice_id in ["bargain", "tend", "leave"]:
		var service := RunStitchedEventConsequence.new(_bargain_event())
		var preview_entry := _entry(service.preview(snapshot), choice_id)
		var receipt := service.choose(choice_id, snapshot)
		_check(receipt.get("ok") == true and receipt.get("event_id") == "ev_stitched_candle_bargain"
			and receipt.get("choice_id") == choice_id,
			"%s receipt names the event and the committed choice" % choice_id)
		_check(receipt.get("candle") == preview_entry.get("candle")
			and receipt.get("fray") == preview_entry.get("fray")
			and receipt.get("target") == preview_entry.get("target")
			and receipt.get("hero_id") == preview_entry.get("hero_id"),
			"%s receipt is exactly the preview projection" % choice_id)
		_check(service.is_claimed() and not service.is_valid(),
			"%s consumes the single visit" % choice_id)
		_check(snapshot == original, "%s commit leaves the caller snapshot untouched" % choice_id)
	var leave_service := RunStitchedEventConsequence.new(_bargain_event())
	var leave_receipt := leave_service.choose("leave", snapshot)
	_check(leave_receipt.get("candle") == 40 and leave_receipt.get("fray") == {},
		"a Leave receipt has the original candle and no fray changes")
	_check(_receipt_keys(leave_receipt)
		== ["candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target"],
		"a receipt carries candle and fray intents only, no resolution payload")
	leave_receipt["fray"]["warden"] = 500
	leave_receipt["candle"] = -1
	_check(RunStitchedEventConsequence.new(_bargain_event()).preview(snapshot)
		== RunStitchedEventConsequence.new(_bargain_event()).preview(original),
		"mutating a receipt never reaches the caller's snapshot or a later preflight")
	var claimed := RunStitchedEventConsequence.new(_bargain_event())
	_check(claimed.choose("bargain", snapshot).get("ok") == true, "the first claim succeeds")
	for again in ["bargain", "tend", "leave"]:
		_assert_rejected(claimed, again, snapshot, 40, "second choice %s after a claim" % again)
	_check(claimed.preview(snapshot) == _denied_preview(), "a claimed visit denies preflight")


func _test_unavailable_hero_and_retry() -> void:
	var snapshot := _snapshot(30, [["warden", 90], ["tinker", 190]])
	var original := snapshot.duplicate(true)
	var service := RunStitchedEventConsequence.new(_event([
		_choice("gate", "Ask the absent scarecrow.", _effect(25, -25, "hero", "scarecrow")),
		_choice("bargain", "Bargain.", _effect(25, -25)),
	]))
	var entry := _entry(service.preview(snapshot), "gate")
	_check(entry.get("available") == false,
		"a hero choice whose named hero is absent is unavailable")
	_check(entry.get("candle") == 30 and entry.get("fray") == {},
		"an unavailable hero choice projects no candle or fray change")
	_check(entry.get("candle_delta") == 25 and entry.get("fray_delta") == -25,
		"an unavailable hero choice still shows its authored deltas")
	_check(_entry(service.preview(snapshot), "bargain").get("available") == true,
		"the same preflight still offers the legal choice")
	_assert_rejected(service, "gate", snapshot, 30, "absent hero")
	_check(not service.is_claimed(), "an unavailable hero choice does not latch the visit")
	_check(snapshot == original, "an unavailable hero refusal leaves the snapshot untouched")
	var receipt := service.choose("bargain", snapshot)
	_check(receipt.get("ok") == true and receipt.get("candle") == 55
		and receipt.get("fray") == {"warden": -25, "tinker": -25},
		"the same visit still accepts a legal choice after the refusal")
	_assert_rejected(service, "gate", snapshot, 30, "absent hero after the claim")


func _test_invalid_snapshots() -> void:
	var service := RunStitchedEventConsequence.new(_bargain_event())
	var good := _four(40, [10, 20, 30, 40])
	var good_before := good.duplicate(true)
	for boundary in [
		{"candle": 0, "party": [{"id": "warden", "fray": 0}]},
		{"candle": 100, "party": [{"id": "button_golem", "fray": 200}]},
	]:
		_check(service.preview(boundary).get("ok") == true,
			"boundary snapshot admitted: " + str(boundary))
	var bad: Array = []
	bad.append(null)
	bad.append("snapshot")
	bad.append(42)
	bad.append([])
	bad.append({})
	bad.append({"candle": 40})
	bad.append({"party": [{"id": "warden", "fray": 10}]})
	bad.append({"candle": 40, "party": [{"id": "warden", "fray": 10}], "extra": 1})
	bad.append({"candle": int(40), "party": "warden"})
	bad.append({"candle": 40, "party": []})
	var five: Array = []
	for hero_id in ["warden", "seamstress", "tinker", "lantern_monk", "rag_duelist"]:
		five.append({"id": hero_id, "fray": 10})
	bad.append({"candle": 40, "party": five})
	bad.append({"candle": 40, "party": [{"id": "warden", "fray": 10}, {"id": "warden", "fray": 20}]})
	bad.append({"candle": 40, "party": [{"id": "porcelain_doll", "fray": 10}]})
	bad.append({"candle": 40, "party": [{"id": " ", "fray": 10}]})
	bad.append({"candle": 40, "party": [{"id": 42, "fray": 10}]})
	bad.append({"candle": 40, "party": [7]})
	bad.append({"candle": 40, "party": [{"id": "warden", "fray": 10, "hp": 20}]})
	bad.append({"candle": 40, "party": [{"id": "warden"}]})
	bad.append({"candle": 40, "party": [{"id": "warden", "fray": 10}, {"id": "tinker", "fray": -1}]})
	bad.append({"candle": 40, "party": [{"id": "warden", "fray": 201}]})
	bad.append({"candle": 40, "party": [{"id": "warden", "fray": 1.5}]})
	bad.append({"candle": 40, "party": [{"id": "warden", "fray": "10"}]})
	bad.append({"candle": 40, "party": [{"id": "warden", "fray": true}]})
	for bad_candle in [-1, 101, 1.5, 40.5, "40", true, null, 9223372036854775807]:
		bad.append({"candle": bad_candle, "party": [{"id": "warden", "fray": 10}]})
	for index in range(bad.size()):
		var input: Variant = bad[index]
		var before: Variant = input.duplicate(true) if input is Dictionary else input
		_check(service.preview(input) == _denied_preview(),
			"invalid snapshot %d denies preflight" % index)
		_assert_rejected(service, "bargain", input, 0, "invalid snapshot %d commit" % index)
		_check(input == before, "invalid snapshot %d is not touched" % index)
	_check(not service.is_claimed(), "invalid snapshots never consume the visit")
	_check(service.preview(good).get("ok") == true, "a valid snapshot works after every refusal")
	var receipt := service.choose("bargain", good)
	_check(receipt.get("ok") == true and receipt.get("candle") == 65,
		"a legal claim follows every malformed-snapshot refusal")
	_check(good == good_before, "the later legal claim still leaves the caller snapshot untouched")


func _test_invalid_events() -> void:
	var snapshot := _four(40, [10, 20, 30, 40])
	var missing_title := _event([_choice("bargain", "Bargain.", _effect(25, -25)),
		_choice("leave", "Leave.", _effect(0, 0))])
	missing_title.erase("title")
	var missing_description := _event([_choice("bargain", "Bargain.", _effect(25, -25)),
		_choice("leave", "Leave.", _effect(0, 0))])
	missing_description.erase("description")
	var missing_id := _event([_choice("bargain", "Bargain.", _effect(25, -25)),
		_choice("leave", "Leave.", _effect(0, 0))])
	missing_id.erase("id")
	var bad_events: Array = [
		null, "event", 42, [], {},
		_event([]),
		_event([_choice("only", "Only.", _effect(0, 0))]),
		_event([
			_choice("a", "A.", _effect(0, 0)), _choice("b", "B.", _effect(0, 0)),
			_choice("c", "C.", _effect(0, 0)), _choice("d", "D.", _effect(0, 0)),
		]),
		_event([_choice("same", "A.", _effect(0, 0)), _choice("same", "B.", _effect(0, 0))]),
		_event([_choice("bargain", " ", _effect(25, -25)), _choice("leave", "Leave.", _effect(0, 0))]),
		_event([_choice(" ", "Blank id.", _effect(25, -25)), _choice("leave", "Leave.", _effect(0, 0))]),
		_event([{"id": "bargain"}, _choice("leave", "Leave.", _effect(0, 0))]),
		missing_title, missing_description, missing_id,
	]
	for index in range(bad_events.size()):
		var service := RunStitchedEventConsequence.new(bad_events[index])
		_check(not service.is_valid() and not service.is_claimed(),
			"invalid event %d never opens" % index)
		_check(service.preview(snapshot) == _denied_preview(),
			"invalid event %d denies preflight" % index)
		_assert_rejected(service, "bargain", snapshot, 40, "invalid event %d commit" % index)


func _test_invalid_outcomes() -> void:
	var snapshot := _snapshot(50, [["warden", 40], ["seamstress", 60]])
	var original := snapshot.duplicate(true)
	var broken: Array = []
	broken.append({"id": "broken", "text": "No outcome field."})
	broken.append({"id": "broken", "text": "Extra top-level key.",
		"stitched_effect": _effect(25, -25), "extra": true})
	broken.append({"id": "broken", "text": "Not a dict.", "stitched_effect": "party"})
	broken.append({"id": "broken", "text": "No target.", "stitched_effect": {"candle": 25, "fray": -25}})
	broken.append({"id": "broken", "text": "No candle.",
		"stitched_effect": {"fray": -25, "target": "party"}})
	broken.append({"id": "broken", "text": "No fray.",
		"stitched_effect": {"candle": 25, "target": "party"}})
	broken.append({"id": "broken", "text": "Party carries a hero.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": "party", "hero_id": "warden"}})
	broken.append({"id": "broken", "text": "Hero without an id.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": "hero"}})
	broken.append({"id": "broken", "text": "Hero not in the roster.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": "hero", "hero_id": "porcelain_doll"}})
	broken.append({"id": "broken", "text": "Blank hero.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": "hero", "hero_id": " "}})
	broken.append({"id": "broken", "text": "Hero not a string.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": "hero", "hero_id": 42}})
	broken.append({"id": "broken", "text": "Wrong case target.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": "Party"}})
	broken.append({"id": "broken", "text": "Unknown target.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": "all"}})
	broken.append({"id": "broken", "text": "Non-string target.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": 42}})
	broken.append({"id": "broken", "text": "String candle.",
		"stitched_effect": {"candle": "25", "fray": -25, "target": "party"}})
	broken.append({"id": "broken", "text": "Fractional candle.",
		"stitched_effect": {"candle": 25.5, "fray": -25, "target": "party"}})
	broken.append({"id": "broken", "text": "Boolean fray.",
		"stitched_effect": {"candle": 25, "fray": true, "target": "party"}})
	broken.append({"id": "broken", "text": "Null fray.",
		"stitched_effect": {"candle": 25, "fray": null, "target": "party"}})
	broken.append({"id": "broken", "text": "Extra effect key.",
		"stitched_effect": {"candle": 25, "fray": -25, "target": "party", "note": "gift"}})
	for index in range(broken.size()):
		var service := RunStitchedEventConsequence.new(_event([
			_choice("bargain", "Bargain.", _effect(25, -25)),
			broken[index],
		]))
		_check(service.is_valid(), "envelope %d stays schema-valid" % index)
		var preview := service.preview(snapshot)
		_check(preview.get("ok") == true, "envelope %d keeps a readable preflight" % index)
		var entry := _entry(preview, "broken")
		_check(entry.get("available") == false, "malformed outcome %d is unavailable" % index)
		_check(entry.get("candle_delta") == null and entry.get("fray_delta") == null,
			"malformed outcome %d exposes no deltas" % index)
		_check(entry.get("candle") == 50 and entry.get("fray") == {},
			"malformed outcome %d projects no change" % index)
		_check(_entry(preview, "bargain").get("available") == true,
			"malformed outcome %d leaves its sibling offerable" % index)
		_assert_rejected(service, "broken", snapshot, 50, "malformed outcome %d commit" % index)
		_check(not service.is_claimed(), "malformed outcome %d does not latch" % index)
		var receipt := service.choose("bargain", snapshot)
		_check(receipt.get("ok") == true and receipt.get("candle") == 75
			and receipt.get("fray") == {"warden": -25, "seamstress": -25},
			"malformed outcome %d does not poison the legal sibling" % index)
	_check(snapshot == original, "malformed outcomes never touch the caller snapshot")


func _test_unoffered_and_replay() -> void:
	var snapshot := _four(40, [10, 20, 30, 40])
	var service := RunStitchedEventConsequence.new(_bargain_event())
	for unoffered in ["", "  ", "unknown", "bargain ", " bargain", "Bargain", 42, null,
			["bargain"], {"id": "bargain"}]:
		_assert_rejected(service, unoffered, snapshot, 40, "unoffered " + str(unoffered))
	_check(not service.is_claimed(), "unoffered refusals never latch the visit")
	var receipt := service.choose("tend", snapshot)
	_check(receipt.get("ok") == true and receipt.get("fray") == {"seamstress": -25},
		"a legal claim still follows the unoffered refusals")
	_assert_rejected(service, "tend", snapshot, 40, "replay of the committed choice")
	_assert_rejected(service, "bargain", snapshot, 40, "a different choice after the claim")
	_check(service.preview(snapshot) == _denied_preview(), "the claimed visit denies preflight")
	var first := RunStitchedEventConsequence.new(_bargain_event())
	var second := RunStitchedEventConsequence.new(_bargain_event())
	_check(first.choose("bargain", snapshot) == second.choose("bargain", snapshot),
		"two fresh visits replay the same receipt")


func _test_fray_thresholds() -> void:
	var cross_event := _event([
		_choice("raise", "Pull the thread taut.", _effect(0, 10)),
		_choice("soothe", "Soothe the seam.", _effect(0, -25)),
	])
	var snapshot := _snapshot(60, [["warden", 95], ["seamstress", 190]])
	var original := snapshot.duplicate(true)
	var raise_service := RunStitchedEventConsequence.new(cross_event)
	var raise_receipt := raise_service.choose("raise", snapshot)
	_check(raise_receipt.get("fray") == {"warden": 10, "seamstress": 10},
		"fray 95 and 190 receive raw +10 intents crossing 100 and 200")
	_check(snapshot == original and snapshot["party"][0]["fray"] == 95
		and snapshot["party"][1]["fray"] == 190,
		"threshold crossing never mutates or clamps the caller's fray")
	_check(_receipt_keys(raise_receipt)
		== ["candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target"],
		"a crossing receipt carries intents only, with no resolve or tear payload")
	_check(not raise_receipt.has("resolve") and not raise_receipt.has("trait")
		and not raise_receipt.has("heroes") and not raise_receipt.has("seams"),
		"no resolve check, trait choice or torn seam is reported")
	var soothe_receipt := RunStitchedEventConsequence.new(cross_event).choose("soothe", snapshot)
	_check(soothe_receipt.get("fray") == {"warden": -25, "seamstress": -25},
		"relief returns raw signed -25 intents without pre-clamping")
	var hundred := _snapshot(60, [["warden", 100], ["scarecrow", 45]])
	var calm := RunStitchedEventConsequence.new(_event([
		_choice("still", "Hold still.", _effect(0, 0)),
		_choice("raise", "Pull.", _effect(0, 10)),
	]))
	var calm_receipt := calm.choose("still", hundred)
	_check(calm_receipt.get("fray") == {} and hundred["party"][0]["fray"] == 100,
		"a zero-delta choice at fray 100 returns no intent and resolves nothing")
	var cross_receipt := RunStitchedEventConsequence.new(_event([
		_choice("still", "Hold still.", _effect(0, 0)),
		_choice("raise", "Pull.", _effect(0, 10)),
	])).choose("raise", hundred)
	_check(cross_receipt.get("fray") == {"warden": 10, "scarecrow": 10},
		"an intent at fray 100 is reported for the S1b owner to apply")
	_check(hundred["party"][0]["fray"] == 100 and hundred["party"][1]["fray"] == 45,
		"the fray 100 snapshot is still authoritative and untouched")
	var maxed := _snapshot(60, [["button_golem", 200]])
	_check(_entry(RunStitchedEventConsequence.new(_bargain_event()).preview(maxed), "bargain")
		.get("fray") == {"button_golem": -25},
		"a fray 200 hero is admitted and relieved by intent only")
	var source := FileAccess.get_file_as_string("res://scripts/run_stitched_event_consequence.gd")
	_check(not source.is_empty(), "reads its own authored service source")
	for forbidden in ["stitched_rules.gd", "StitchedRules", "StitchedS1BEffects",
			"RandomNumberGenerator", "randi(", "randf("]:
		_check(source.find(forbidden) == -1,
			"service never references reserved rules or RNG: " + forbidden)


func _test_detachment_and_rng() -> void:
	var fresh := _four(40, [95, 0, 50, 200])
	var original := fresh.duplicate(true)
	var service := RunStitchedEventConsequence.new(_bargain_event())
	var preview := service.preview(fresh)
	fresh["party"][0]["fray"] = 199
	fresh["candle"] = 3
	_check(preview == RunStitchedEventConsequence.new(_bargain_event()).preview(original),
		"a preflight keeps its projection when the caller edits its own snapshot")
	var receipt := service.choose("bargain", original)
	var replay := RunStitchedEventConsequence.new(_bargain_event()).choose("bargain", original.duplicate(true))
	_check(receipt == replay, "a committed receipt is deterministic and fully detached")
	receipt["fray"]["warden"] = 999
	receipt["candle"] = 0
	_check(original == _four(40, [95, 0, 50, 200]),
		"mutating a returned receipt never rewrites the caller snapshot")
	_check(replay.get("candle") == 65 and replay.get("fray", {}).get("tinker") == -25,
		"the replay remains a real, non-vacuous projection")
	seed(20261104)
	var expected_next := randi()
	seed(20261104)
	var rng_service := RunStitchedEventConsequence.new(_bargain_event())
	_check(rng_service.preview(original).get("ok") == true, "rng fixture preflights")
	_assert_rejected(rng_service, "gate", original, 40, "rng refusal")
	_check(rng_service.choose("bargain", original).get("ok") == true, "rng fixture commits")
	_check(randi() == expected_next,
		"construction, preflight, refusals and a claim never draw the global RNG")
