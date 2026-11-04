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
	_test_scraps_bargains()
	_test_scraps_rejections()
	_test_part_prize_bargains()
	_test_part_prize_rejections()
	_test_gold_bargains()
	_test_gold_rejections()
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


func _scraps_effect(candle: int, fray: int, scraps: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {"candle": candle, "fray": fray, "target": target, "scraps": scraps}
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


func _scraps_bargain_event() -> Dictionary:
	return _event([
		_choice("mend_party", "Spend scraps to calm the party.", _scraps_effect(25, -25, -2)),
		_choice("salvage_warden", "Salvage scraps from the warden's seam.",
			_scraps_effect(0, 10, 3, "hero", "warden")),
		_choice("leave", "Leave the scraps untouched.", _scraps_effect(0, 0, 0)),
	], "ev_stitched_scraps_bargain")


func _snapshot(candle: int, hero_pairs: Array) -> Dictionary:
	var party: Array = []
	for pair in hero_pairs:
		party.append({"id": pair[0], "fray": pair[1]})
	return {"candle": candle, "party": party}


func _scraps_snapshot(candle: int, scraps: Variant, hero_pairs: Array) -> Dictionary:
	var snapshot := _snapshot(candle, hero_pairs)
	snapshot["scraps"] = scraps
	return snapshot


func _four(candle: int, frays: Array) -> Dictionary:
	var pairs: Array = []
	for index in range(frays.size()):
		pairs.append([FOUR[index], frays[index]])
	return _snapshot(candle, pairs)


func _scraps_four(candle: int, scraps: Variant, frays: Array) -> Dictionary:
	var snapshot := _four(candle, frays)
	snapshot["scraps"] = scraps
	return snapshot


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


func _test_scraps_bargains() -> void:
	# Canonical eight-ID roster coverage for scrap-bearing hero and party choices,
	# plus legacy choices without the scraps key on a scraps-bearing snapshot.
	for hero_id in REQUIRED_IDS:
		var roster_snap := _scraps_snapshot(50, 4, [[hero_id, 110]])
		var roster_service := RunStitchedEventConsequence.new(_event([
			_choice("hero_scraps", "Hero scraps.", _scraps_effect(0, 10, 3, "hero", hero_id)),
			_choice("party_scraps", "Party scraps.", _scraps_effect(15, -15, -2)),
			_choice("legacy_leave", "Legacy leave.", _effect(0, 0)),
		]))
		var roster_preview := roster_service.preview(roster_snap)
		var hero_entry := _entry(roster_preview, "hero_scraps")
		_check(hero_entry.get("available") == true and hero_entry.get("hero_id") == hero_id
			and hero_entry.get("scraps_delta") == 3 and hero_entry.get("scraps") == 7
			and hero_entry.get("fray") == {hero_id: 10},
			"canonical hero %s accepts scrap-bearing hero effect with shared party scraps" % hero_id)
		var legacy_entry := _entry(roster_preview, "legacy_leave")
		_check(legacy_entry.get("available") == true and not legacy_entry.has("scraps")
			and not legacy_entry.has("scraps_delta"),
			"legacy choice alongside scraps choices retains exact non-scraps preview shape for %s" % hero_id)
		var hero_receipt := roster_service.choose("hero_scraps", roster_snap)
		_check(hero_receipt.get("ok") == true and hero_receipt.get("scraps") == 7
			and hero_receipt.get("scraps_delta") == 3 and hero_receipt.get("fray") == {hero_id: 10},
			"canonical hero %s receipt reports shared party scraps and single-hero fray" % hero_id)

	# AC2 four-hero fixture: candle 40, scraps 4, fray [95, 0, 50, 200].
	var snapshot := _scraps_four(40, 4, [95, 0, 50, 200])
	var original := snapshot.duplicate(true)
	var service := RunStitchedEventConsequence.new(_scraps_bargain_event())
	var preview := service.preview(snapshot)
	_check(preview.get("ok") == true and preview.get("event_id") == "ev_stitched_scraps_bargain"
		and preview.get("candle") == 40,
		"scraps bargain preflight succeeds and reports base candle 40")

	var mend_entry := _entry(preview, "mend_party")
	_check(mend_entry.get("available") == true and mend_entry.get("target") == "party"
		and mend_entry.get("hero_id") == "" and mend_entry.get("candle_delta") == 25
		and mend_entry.get("fray_delta") == -25 and mend_entry.get("scraps_delta") == -2
		and mend_entry.get("candle") == 65 and mend_entry.get("scraps") == 2
		and mend_entry.get("fray") == {
			"warden": -25, "seamstress": -25, "tinker": -25, "button_golem": -25,
		},
		"party choice {candle:25,fray:-25,target:party,scraps:-2} projects candle 65, scraps 2 and -25 per hero")

	var salvage_entry := _entry(preview, "salvage_warden")
	_check(salvage_entry.get("available") == true and salvage_entry.get("target") == "hero"
		and salvage_entry.get("hero_id") == "warden" and salvage_entry.get("candle_delta") == 0
		and salvage_entry.get("fray_delta") == 10 and salvage_entry.get("scraps_delta") == 3
		and salvage_entry.get("candle") == 40 and salvage_entry.get("scraps") == 7
		and salvage_entry.get("fray") == {"warden": 10},
		"Warden choice {candle:0,fray:10,target:hero,hero_id:warden,scraps:3} projects scraps 7 and Warden +10 only")

	var leave_entry := _entry(preview, "leave")
	_check(leave_entry.get("available") == true and leave_entry.get("scraps_delta") == 0
		and leave_entry.get("scraps") == 4 and leave_entry.get("candle") == 40
		and leave_entry.get("fray") == {},
		"zero-cost scrap-bearing Leave projects unchanged candle 40, scraps 4 and empty fray")

	for choice_id in ["mend_party", "salvage_warden", "leave"]:
		var visit := RunStitchedEventConsequence.new(_scraps_bargain_event())
		var expected_entry := _entry(visit.preview(snapshot), choice_id)
		var receipt := visit.choose(choice_id, snapshot)
		_check(receipt.get("ok") == true and receipt.get("event_id") == "ev_stitched_scraps_bargain"
			and receipt.get("choice_id") == choice_id,
			"scraps choice %s commits once" % choice_id)
		_check(_receipt_keys(receipt) == [
			"candle", "choice_id", "event_id", "fray", "hero_id",
			"ok", "scraps", "scraps_delta", "target",
		], "scraps choice %s receipt exposes scraps and scraps_delta alongside the 7 legacy keys" % choice_id)
		_check(receipt.get("candle") == expected_entry.get("candle")
			and receipt.get("fray") == expected_entry.get("fray")
			and receipt.get("target") == expected_entry.get("target")
			and receipt.get("hero_id") == expected_entry.get("hero_id")
			and receipt.get("scraps_delta") == expected_entry.get("scraps_delta")
			and receipt.get("scraps") == expected_entry.get("scraps"),
			"scraps choice %s receipt has exact parity with preview" % choice_id)
		_check(visit.is_claimed() and not visit.is_valid(),
			"scraps choice %s latches the visit" % choice_id)
		_check(snapshot == original,
			"scraps choice %s never mutates caller snapshot" % choice_id)

	# Integral float JSON representation, exact spend to 0, candle clamp, and MAX_INT boundary credit.
	var json_event: Dictionary = JSON.parse_string(JSON.stringify(_event([
		_choice("spend_all", "Spend all 4 scraps.", _scraps_effect(80, -10, -4)),
		_choice("cap_credit", "Credit up to MAX_INT.", _scraps_effect(-60, 15, 7, "hero", "tinker")),
	])))
	var clamp_snap := _scraps_four(40, 4, [95, 0, 50, 200])
	var spend_visit := RunStitchedEventConsequence.new(json_event)
	var spend_receipt := spend_visit.choose("spend_all", clamp_snap)
	_check(spend_receipt.get("ok") == true and spend_receipt.get("candle") == 100
		and spend_receipt.get("scraps_delta") == -4 and spend_receipt.get("scraps") == 0,
		"JSON-parsed integral scraps delta spends down to 0 and clamps candle at 100")
	var near_max_snap := _scraps_four(40, 9223372036854775800, [95, 0, 50, 200])
	var max_visit := RunStitchedEventConsequence.new(json_event)
	var max_receipt := max_visit.choose("cap_credit", near_max_snap)
	_check(max_receipt.get("ok") == true and max_receipt.get("candle") == 0
		and max_receipt.get("scraps_delta") == 7 and max_receipt.get("scraps") == 9223372036854775807
		and max_receipt.get("fray") == {"tinker": 15},
		"positive scraps credit up to exact 64-bit MAX_INT succeeds and clamps candle at 0")

	# Detachment and RNG invariance for scrap-bearing visits.
	var mutable_snap := _scraps_four(40, 4, [95, 0, 50, 200])
	var detach_service := RunStitchedEventConsequence.new(_scraps_bargain_event())
	var detach_preview := detach_service.preview(mutable_snap)
	mutable_snap["scraps"] = 99
	mutable_snap["party"][0]["fray"] = 12
	detach_preview["choices"][0]["scraps"] = -999
	detach_preview["choices"][0]["fray"]["warden"] = 999
	_check(detach_service.preview(original) == preview,
		"mutating caller snapshot or returned scraps preview never aliases later preflights")
	var detach_receipt := detach_service.choose("mend_party", original)
	detach_receipt["scraps"] = 999
	detach_receipt["fray"]["warden"] = 777
	_check(original == _scraps_four(40, 4, [95, 0, 50, 200]),
		"mutating a scrap-bearing receipt never mutates the caller snapshot")
	_check(RunStitchedEventConsequence.new(_scraps_bargain_event()).choose("mend_party", original)
		== RunStitchedEventConsequence.new(_scraps_bargain_event()).choose("mend_party", original.duplicate(true)),
		"scrap-bearing visits are deterministic across repeat instances")


func _test_scraps_rejections() -> void:
	# 1. Insufficient scraps (scraps 1 vs -2 cost): unavailable, rejected without latch,
	#    and both zero-cost scraps Leave and legacy Leave remain claimable on that same Event.
	var low_scraps := _scraps_four(40, 1, [95, 0, 50, 200])
	var low_original := low_scraps.duplicate(true)
	var low_service := RunStitchedEventConsequence.new(_scraps_bargain_event())
	var low_preview := low_service.preview(low_scraps)
	var unaffordable_entry := _entry(low_preview, "mend_party")
	_check(unaffordable_entry.get("available") == false
		and unaffordable_entry.get("scraps_delta") == -2
		and unaffordable_entry.get("scraps") == 1
		and unaffordable_entry.get("candle") == 40
		and unaffordable_entry.get("fray") == {},
		"from scraps 1, the -2 choice is unavailable and retains unchanged base candle/scraps")
	_check(_entry(low_preview, "salvage_warden").get("available") == true
		and _entry(low_preview, "leave").get("available") == true,
		"from scraps 1, positive and zero-cost siblings remain available")
	_assert_rejected(low_service, "mend_party", low_scraps, 40, "insufficient scraps (1 vs -2)")
	var zero_leave_receipt := low_service.choose("leave", low_scraps)
	_check(zero_leave_receipt.get("ok") == true and zero_leave_receipt.get("scraps") == 1
		and zero_leave_receipt.get("scraps_delta") == 0 and zero_leave_receipt.get("candle") == 40
		and zero_leave_receipt.get("fray") == {},
		"after insufficient-scraps rejection, zero-cost Leave still claims on the same instance")
	_assert_rejected(low_service, "leave", low_scraps, 40, "replay after zero-cost Leave claim")
	_check(low_scraps == low_original, "insufficient scraps and subsequent claim leave input untouched")

	# Same 1-scraps fixture with a legacy Leave (no scraps key) sibling:
	var mixed_event := _event([
		_choice("mend_party", "Spend 2 scraps.", _scraps_effect(25, -25, -2)),
		_choice("salvage_warden", "Gain 3 scraps.", _scraps_effect(0, 10, 3, "hero", "warden")),
		_choice("legacy_leave", "Leave.", _effect(0, 0)),
	])
	var mixed_service := RunStitchedEventConsequence.new(mixed_event)
	_assert_rejected(mixed_service, "mend_party", low_scraps, 40, "insufficient scraps on mixed event")
	var legacy_leave_receipt := mixed_service.choose("legacy_leave", low_scraps)
	_check(legacy_leave_receipt.get("ok") == true and _receipt_keys(legacy_leave_receipt)
		== ["candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target"],
		"after insufficient-scraps rejection, legacy Leave still claims with its exact 7-key receipt")
	_assert_rejected(mixed_service, "legacy_leave", low_scraps, 40, "replay after legacy Leave claim")

	# Debit below zero from 0 scraps:
	var zero_scraps := _scraps_four(40, 0, [95, 0, 50, 200])
	var debit_zero_service := RunStitchedEventConsequence.new(_event([
		_choice("debit_one", "Spend 1 scrap.", _scraps_effect(10, -10, -1)),
		_choice("leave", "Leave.", _scraps_effect(0, 0, 0)),
	]))
	_check(_entry(debit_zero_service.preview(zero_scraps), "debit_one").get("available") == false,
		"debit below zero from 0 scraps is unavailable")
	_assert_rejected(debit_zero_service, "debit_one", zero_scraps, 40, "debit below zero from 0 scraps")
	_check(debit_zero_service.choose("leave", zero_scraps).get("ok") == true,
		"sibling still claims after debit-below-zero refusal")

	# 2. Missing scraps balance in snapshot ({candle, party} only): makes only scrap-bearing
	#    choices unavailable, while a legacy choice on the same Event remains available.
	var missing_scraps := _four(40, [95, 0, 50, 200])
	var missing_original := missing_scraps.duplicate(true)
	var missing_service := RunStitchedEventConsequence.new(mixed_event)
	var missing_preview := missing_service.preview(missing_scraps)
	_check(missing_preview.get("ok") == true,
		"legacy {candle,party} snapshot still preflights on a mixed scraps/legacy Event")
	_check(_entry(missing_preview, "mend_party").get("available") == false
		and _entry(missing_preview, "mend_party").get("scraps_delta") == -2
		and _entry(missing_preview, "mend_party").get("scraps") == null
		and _entry(missing_preview, "salvage_warden").get("available") == false
		and _entry(missing_preview, "salvage_warden").get("scraps_delta") == 3
		and _entry(missing_preview, "salvage_warden").get("scraps") == null,
		"missing snapshot scraps makes scrap-bearing spend and gain choices unavailable")
	_check(_entry(missing_preview, "legacy_leave").get("available") == true,
		"missing snapshot scraps leaves the legacy non-scraps choice available")
	_assert_rejected(missing_service, "mend_party", missing_scraps, 40, "missing scraps on spend choice")
	_assert_rejected(missing_service, "salvage_warden", missing_scraps, 40, "missing scraps on gain choice")
	var missing_fallback := missing_service.choose("legacy_leave", missing_scraps)
	_check(missing_fallback.get("ok") == true and missing_fallback.get("candle") == 40
		and not missing_fallback.has("scraps"),
		"legacy sibling still claims when snapshot omits scraps")
	_assert_rejected(missing_service, "legacy_leave", missing_scraps, 40, "replay after missing-scraps fallback")
	_check(missing_scraps == missing_original, "missing-scraps checks leave caller snapshot untouched")

	# 3. Absent target hero on a scrap-bearing choice:
	var two_hero_snap := _scraps_snapshot(40, 4, [["warden", 95], ["tinker", 50]])
	var absent_hero_service := RunStitchedEventConsequence.new(_event([
		_choice("absent_scarecrow", "Ask the absent scarecrow.",
			_scraps_effect(10, -15, 3, "hero", "scarecrow")),
		_choice("mend_party", "Mend party.", _scraps_effect(25, -25, -2)),
	]))
	var absent_entry := _entry(absent_hero_service.preview(two_hero_snap), "absent_scarecrow")
	_check(absent_entry.get("available") == false and absent_entry.get("scraps_delta") == 3
		and absent_entry.get("scraps") == 4 and absent_entry.get("candle") == 40
		and absent_entry.get("fray") == {},
		"absent target hero makes a scrap-bearing choice unavailable without projecting changes")
	_assert_rejected(absent_hero_service, "absent_scarecrow", two_hero_snap, 40, "absent hero on scraps choice")
	var absent_sibling := absent_hero_service.choose("mend_party", two_hero_snap)
	_check(absent_sibling.get("ok") == true and absent_sibling.get("scraps") == 2
		and absent_sibling.get("fray") == {"warden": -25, "tinker": -25},
		"legal sibling claims after absent-hero scraps rejection")
	_assert_rejected(absent_hero_service, "mend_party", two_hero_snap, 40, "replay after absent-hero sibling claim")

	# 4. Overflow credit near 9223372036854775807 (MAX_INT):
	var overflow_snap := _scraps_four(40, 9223372036854775800, [95, 0, 50, 200])
	var overflow_service := RunStitchedEventConsequence.new(_event([
		_choice("overflow_eight", "Overflow by 1.", _scraps_effect(10, 0, 8)),
		_choice("overflow_max", "Overflow by MAX_INT.", _scraps_effect(10, 0, 9223372036854775807)),
		_choice("safe_seven", "Exact MAX_INT.", _scraps_effect(10, 0, 7)),
	]))
	var overflow_preview := overflow_service.preview(overflow_snap)
	_check(_entry(overflow_preview, "overflow_eight").get("available") == false
		and _entry(overflow_preview, "overflow_eight").get("scraps") == 9223372036854775800
		and _entry(overflow_preview, "overflow_max").get("available") == false
		and _entry(overflow_preview, "safe_seven").get("available") == true,
		"credits exceeding 64-bit MAX_INT are unavailable while exact MAX_INT remains available")
	_assert_rejected(overflow_service, "overflow_eight", overflow_snap, 40, "overflow credit +8")
	_assert_rejected(overflow_service, "overflow_max", overflow_snap, 40, "overflow credit +MAX_INT")
	var safe_receipt := overflow_service.choose("safe_seven", overflow_snap)
	_check(safe_receipt.get("ok") == true and safe_receipt.get("scraps") == 9223372036854775807,
		"legal sibling claims after overflow refusals")
	_assert_rejected(overflow_service, "safe_seven", overflow_snap, 40, "replay after safe sibling claim")

	# 5. Malformed noninteger/unknown scraps effects:
	var valid_scraps_snap := _scraps_snapshot(50, 4, [["warden", 40], ["seamstress", 60]])
	var broken_scraps_choices: Array = [
		_choice("broken", "Fractional scraps.", _scraps_effect(25, -25, 1.5)),
		_choice("broken", "Negative fraction.", _scraps_effect(25, -25, -0.5)),
		_choice("broken", "String scraps.", _scraps_effect(25, -25, "2")),
		_choice("broken", "Bool scraps.", _scraps_effect(25, -25, true)),
		_choice("broken", "Null scraps.", _scraps_effect(25, -25, null)),
		_choice("broken", "Infinite scraps.", _scraps_effect(25, -25, INF)),
		_choice("broken", "Unsafe float scraps.", _scraps_effect(25, -25, 9007199254740992.0 * 2.0)),
		{"id": "broken", "text": "Extra key with scraps.", "stitched_effect": {
			"candle": 25, "fray": -25, "target": "party", "scraps": -2, "extra": 1,
		}},
		{"id": "broken", "text": "Party target with hero_id and scraps.", "stitched_effect": {
			"candle": 25, "fray": -25, "target": "party", "hero_id": "warden", "scraps": -2,
		}},
		{"id": "broken", "text": "Hero target missing hero_id with scraps.", "stitched_effect": {
			"candle": 25, "fray": -25, "target": "hero", "scraps": 3,
		}},
		{"id": "broken", "text": "Hero target extra key with scraps.", "stitched_effect": {
			"candle": 25, "fray": -25, "target": "hero", "hero_id": "warden", "scraps": 3, "extra": 1,
		}},
		_choice("broken", "Unknown hero with scraps.", _scraps_effect(25, -25, 3, "hero", "porcelain_doll")),
	]
	for index in range(broken_scraps_choices.size()):
		var broken_service := RunStitchedEventConsequence.new(_event([
			_choice("mend_party", "Mend party.", _scraps_effect(25, -25, -2)),
			broken_scraps_choices[index],
		]))
		var broken_preview := broken_service.preview(valid_scraps_snap)
		var broken_entry := _entry(broken_preview, "broken")
		_check(broken_entry.get("available") == false
			and broken_entry.get("candle_delta") == null
			and broken_entry.get("fray_delta") == null
			and broken_entry.get("scraps_delta") == null,
			"malformed scraps effect %d is unavailable with null deltas" % index)
		_assert_rejected(broken_service, "broken", valid_scraps_snap, 50,
			"malformed scraps effect %d" % index)
		var sibling_receipt := broken_service.choose("mend_party", valid_scraps_snap)
		_check(sibling_receipt.get("ok") == true and sibling_receipt.get("scraps") == 2,
			"malformed scraps effect %d leaves legal sibling claimable" % index)
		_assert_rejected(broken_service, "mend_party", valid_scraps_snap, 50,
			"replay after malformed scraps effect %d sibling claim" % index)

	# 6. Malformed snapshot scraps balances and extra snapshot keys:
	var bad_balance_service := RunStitchedEventConsequence.new(_scraps_bargain_event())
	var bad_balances: Array = [-1, -9223372036854775807, 1.5, 4.0, "4", true, false, null, [], {}]
	for index in range(bad_balances.size()):
		var bad_snap := _scraps_four(40, bad_balances[index], [95, 0, 50, 200])
		_check(bad_balance_service.preview(bad_snap) == _denied_preview(),
			"malformed snapshot scraps %d denies preflight" % index)
		_assert_rejected(bad_balance_service, "mend_party", bad_snap, 0,
			"malformed snapshot scraps %d commit" % index)
	var extra_key_snap := _scraps_four(40, 4, [95, 0, 50, 200])
	extra_key_snap["extra"] = 10
	_check(bad_balance_service.preview(extra_key_snap) == _denied_preview(),
		"snapshot with extra key alongside scraps denies preflight")
	_assert_rejected(bad_balance_service, "mend_party", extra_key_snap, 0,
		"snapshot with extra key alongside scraps commit")
	_check(bad_balance_service.choose("mend_party", low_scraps).get("ok") == false,
		"insufficient scraps still refuses after malformed-balance checks")
	var valid_snap := _scraps_four(40, 4, [95, 0, 50, 200])
	var recovered := bad_balance_service.choose("mend_party", valid_snap)
	_check(recovered.get("ok") == true and recovered.get("scraps") == 2,
		"same instance still claims a legal choice after malformed-balance refusals")
	_assert_rejected(bad_balance_service, "leave", valid_snap, 40,
		"replay refused after recovered scraps claim")

	# 7. Unoffered choice and global RNG invariance across scraps refusals and claim:
	seed(20261105)
	var expected_rng := randi()
	seed(20261105)
	var rng_scraps_service := RunStitchedEventConsequence.new(_scraps_bargain_event())
	_check(rng_scraps_service.preview(low_scraps).get("ok") == true, "scraps rng preflight")
	_assert_rejected(rng_scraps_service, "mend_party", low_scraps, 40, "scraps rng insufficient refusal")
	_assert_rejected(rng_scraps_service, "not_a_choice", valid_snap, 40, "scraps rng unoffered refusal")
	_check(rng_scraps_service.choose("salvage_warden", valid_snap).get("ok") == true,
		"scraps rng legal claim")
	_assert_rejected(rng_scraps_service, "leave", valid_snap, 40, "scraps rng replay refusal")
	_check(randi() == expected_rng,
		"scraps preflight, refusals, claim and replay never advance the global RNG")


func _part_effect(candle: int, fray: int, part: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {"candle": candle, "fray": fray, "target": target, "part": part}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _part_scraps_effect(candle: int, fray: int, scraps: Variant, part: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {
		"candle": candle,
		"fray": fray,
		"target": target,
		"scraps": scraps,
		"part": part,
	}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _satchel_four(candle: int, satchel_count: Variant, frays: Array) -> Dictionary:
	var snapshot := _four(candle, frays)
	snapshot["satchel_count"] = satchel_count
	return snapshot


func _scraps_satchel_four(candle: int, scraps: Variant, satchel_count: Variant, frays: Array) -> Dictionary:
	var snapshot := _four(candle, frays)
	snapshot["scraps"] = scraps
	snapshot["satchel_count"] = satchel_count
	return snapshot


func _part_bargain_event() -> Dictionary:
	return _event([
		_choice("claim_pot_helm", "Take the stitched pot helm from the rack.",
			_part_effect(-15, 20, {"id": "warden_head_pot_helm_bonk", "tier": 2})),
		_choice("buy_pot_helm", "Pay scraps to fit the helm for the warden.",
			_part_scraps_effect(10, -15, -2, {"id": "warden_head_pot_helm_bonk", "tier": 2}, "hero", "warden")),
		_choice("leave", "Leave the rack untouched.", _effect(0, 0)),
	], "ev_stitched_part_bargain")


func _test_part_prize_bargains() -> void:
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var catalog_original := warden_catalog.duplicate(true)
	_check(bool(warden_catalog.get("ok", false)),
		"loads the actual authored Warden part catalog via StitchedParts.load_catalog")
	var by_id: Dictionary = warden_catalog.get("by_id", {})
	_check(by_id.has("warden_head_pot_helm_bonk"),
		"Warden part catalog contains warden_head_pot_helm_bonk")

	# Preserve all four snapshot combinations on non-part events, including when satchel_count is 5 or full 6.
	for count_val in [0, 5, 6]:
		var snap_count_only := _satchel_four(40, count_val, [95, 0, 50, 200])
		var snap_both := _scraps_satchel_four(40, 4, count_val, [95, 0, 50, 200])
		var non_part_service := RunStitchedEventConsequence.new(_bargain_event())
		var non_part_preview := non_part_service.preview(snap_count_only)
		_check(non_part_preview.get("ok") == true,
			"non-part event preflights with satchel_count=%d" % count_val)
		var non_part_entry := _entry(non_part_preview, "bargain")
		_check(non_part_entry.get("available") == true
			and not non_part_entry.has("part")
			and not non_part_entry.has("satchel_count"),
			"non-part preview entry omits part and satchel_count at count=%d" % count_val)
		var non_part_receipt := non_part_service.choose("bargain", snap_count_only)
		_check(non_part_receipt.get("ok") == true
			and _receipt_keys(non_part_receipt) == ["candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target"],
			"non-part receipt keeps exact 7-key shape at satchel_count=%d" % count_val)

		var scraps_only_service := RunStitchedEventConsequence.new(_scraps_bargain_event())
		var scraps_only_preview := scraps_only_service.preview(snap_both)
		_check(scraps_only_preview.get("ok") == true
			and _entry(scraps_only_preview, "mend_party").get("available") == true
			and not _entry(scraps_only_preview, "mend_party").has("part")
			and not _entry(scraps_only_preview, "mend_party").has("satchel_count"),
			"scraps-only choice omits part and satchel_count when snapshot has both scraps and satchel_count=%d" % count_val)
		var scraps_only_receipt := scraps_only_service.choose("mend_party", snap_both)
		_check(scraps_only_receipt.get("ok") == true
			and _receipt_keys(scraps_only_receipt) == [
				"candle", "choice_id", "event_id", "fray", "hero_id",
				"ok", "scraps", "scraps_delta", "target",
			],
			"scraps-only receipt keeps exact 9-key shape when snapshot has satchel_count=%d" % count_val)

	# AC1: Four canonical heroes, satchel_count 5, Warden catalog -> preview and choose agree on
	# warden_head_pot_helm_bonk tier 2 and projected satchel_count 6 alongside candle/fray/scraps.
	var event_record := _part_bargain_event()
	var event_original := event_record.duplicate(true)
	var snapshot := _scraps_satchel_four(40, 4, 5, [95, 0, 50, 200])
	var snapshot_original := snapshot.duplicate(true)

	seed(20261106)
	var expected_rng := randi()
	seed(20261106)

	var service := RunStitchedEventConsequence.new(event_record, warden_catalog)
	var preview := service.preview(snapshot)
	_check(preview.get("ok") == true and preview.get("event_id") == "ev_stitched_part_bargain"
		and preview.get("candle") == 40,
		"AC1: part bargain preflight succeeds and reports base candle 40")

	var claim_entry := _entry(preview, "claim_pot_helm")
	_check(claim_entry.get("available") == true
		and claim_entry.get("target") == "party"
		and claim_entry.get("hero_id") == ""
		and claim_entry.get("candle_delta") == -15
		and claim_entry.get("fray_delta") == 20
		and claim_entry.get("candle") == 25
		and claim_entry.get("fray") == {
			"warden": 20, "seamstress": 20, "tinker": 20, "button_golem": 20,
		}
		and claim_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and claim_entry.get("satchel_count") == 6
		and not claim_entry.has("scraps")
		and not claim_entry.has("scraps_delta"),
		"AC1: party part choice previews warden_head_pot_helm_bonk tier 2 and satchel_count 6")

	var buy_entry := _entry(preview, "buy_pot_helm")
	_check(buy_entry.get("available") == true
		and buy_entry.get("target") == "hero"
		and buy_entry.get("hero_id") == "warden"
		and buy_entry.get("candle_delta") == 10
		and buy_entry.get("fray_delta") == -15
		and buy_entry.get("scraps_delta") == -2
		and buy_entry.get("candle") == 50
		and buy_entry.get("scraps") == 2
		and buy_entry.get("fray") == {"warden": -15}
		and buy_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and buy_entry.get("satchel_count") == 6,
		"AC1: hero scraps+part choice previews warden_head_pot_helm_bonk tier 2, scraps 2 and satchel_count 6")

	var leave_entry := _entry(preview, "leave")
	_check(leave_entry.get("available") == true
		and leave_entry.get("candle") == 40
		and leave_entry.get("fray") == {}
		and not leave_entry.has("part")
		and not leave_entry.has("satchel_count")
		and not leave_entry.has("scraps"),
		"AC1: Leave sibling on part Event keeps legacy non-part preview shape")

	var claim_receipt := service.choose("claim_pot_helm", snapshot)
	_check(claim_receipt.get("ok") == true
		and claim_receipt.get("event_id") == "ev_stitched_part_bargain"
		and claim_receipt.get("choice_id") == "claim_pot_helm"
		and claim_receipt.get("target") == "party"
		and claim_receipt.get("hero_id") == ""
		and claim_receipt.get("candle") == 25
		and claim_receipt.get("fray") == {
			"warden": 20, "seamstress": 20, "tinker": 20, "button_golem": 20,
		}
		and claim_receipt.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and claim_receipt.get("satchel_count") == 6,
		"AC1: choose() returns exact previewed part award and satchel_count 6")
	_check(_receipt_keys(claim_receipt) == [
		"candle", "choice_id", "event_id", "fray", "hero_id",
		"ok", "part", "satchel_count", "target",
	], "AC1: part-only receipt has exact 9-key shape")
	_check(service.is_claimed() and not service.is_valid(),
		"AC1: committing a part choice consumes the single visit")
	_assert_rejected(service, "claim_pot_helm", snapshot, 40, "AC2: replay of committed part choice")
	_assert_rejected(service, "leave", snapshot, 40, "AC2: Leave after committed part choice")
	_check(randi() == expected_rng,
		"AC1/AC2: part preview, commit and replay never draw from global RNG")

	# Commit parity on the scraps+part choice and catalog passed via preview/choose arguments:
	var call_catalog_service := RunStitchedEventConsequence.new(event_record)
	var call_preview := call_catalog_service.preview(snapshot, warden_catalog)
	_check(call_preview == preview,
		"catalog supplied to preview() produces identical preflight to constructor catalog")
	var buy_receipt := call_catalog_service.choose("buy_pot_helm", snapshot, warden_catalog)
	_check(buy_receipt.get("ok") == true
		and buy_receipt.get("candle") == buy_entry.get("candle")
		and buy_receipt.get("fray") == buy_entry.get("fray")
		and buy_receipt.get("scraps_delta") == -2
		and buy_receipt.get("scraps") == 2
		and buy_receipt.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and buy_receipt.get("satchel_count") == 6,
		"AC1: scraps+part choice commits with exact preview parity")
	_check(_receipt_keys(buy_receipt) == [
		"candle", "choice_id", "event_id", "fray", "hero_id",
		"ok", "part", "satchel_count", "scraps", "scraps_delta", "target",
	], "AC1: scraps+part receipt has exact 11-key shape")

	# Snapshot without scraps ({candle, party, satchel_count: 5}) on a 2-choice Event (part + ordinary):
	var no_scraps_snap := _satchel_four(90, 5, [95, 0, 50, 200])
	var two_choice_event := _event([
		_choice("claim_pot_helm", "Take the helm.",
			_part_effect(25, -25, {"id": "warden_head_pot_helm_bonk", "tier": 2})),
		_choice("ordinary", "Steady the candle.", _effect(15, -10)),
	])
	var two_choice_service := RunStitchedEventConsequence.new(two_choice_event, warden_catalog)
	var two_choice_preview := two_choice_service.preview(no_scraps_snap)
	_check(_entry(two_choice_preview, "claim_pot_helm").get("candle") == 100
		and _entry(two_choice_preview, "claim_pot_helm").get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and _entry(two_choice_preview, "claim_pot_helm").get("satchel_count") == 6,
		"2-choice part Event clamps candle to 100 and projects satchel_count 6 without scraps key")
	var two_choice_receipt := two_choice_service.choose("claim_pot_helm", no_scraps_snap)
	_check(two_choice_receipt.get("ok") == true and two_choice_receipt.get("candle") == 100
		and two_choice_receipt.get("satchel_count") == 6,
		"2-choice part Event commits with clamped candle 100 and satchel_count 6")

	# Legal tiers 1, 2, 3 and satchel_count 0..5 projections, plus StitchedParts.build_catalog input forms:
	var built_catalog := StitchedParts.build_catalog(warden_catalog["parts"])
	_check(bool(built_catalog.get("ok", false)), "StitchedParts.build_catalog validates Warden parts array")
	for tier in [1, 2, 3]:
		var count_before: int = tier + 2 # 3, 4, 5
		var tier_snap := _satchel_four(50, count_before, [20, 40, 60, 80])
		var tier_event := _event([
			_choice("prize", "Tiered helm.",
				_part_effect(0, 5, {"id": "warden_head_pot_helm_bonk", "tier": tier})),
			_choice("leave", "Leave.", _effect(0, 0)),
		])
		var tier_service := RunStitchedEventConsequence.new(tier_event, built_catalog)
		var tier_entry := _entry(tier_service.preview(tier_snap), "prize")
		_check(tier_entry.get("available") == true
			and tier_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": tier}
			and tier_entry.get("satchel_count") == count_before + 1,
			"tier %d part offer is legal and projects satchel_count %d" % [tier, count_before + 1])
		var tier_receipt := tier_service.choose("prize", tier_snap)
		_check(tier_receipt.get("ok") == true
			and tier_receipt.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": tier}
			and tier_receipt.get("satchel_count") == count_before + 1,
			"tier %d part offer commits with exact tier and satchel_count" % tier)

	for base_count in range(0, 6):
		var count_snap := _satchel_four(50, base_count, [10, 20, 30, 40])
		var count_service := RunStitchedEventConsequence.new(two_choice_event, warden_catalog["parts"])
		var count_receipt := count_service.choose("claim_pot_helm", count_snap)
		_check(count_receipt.get("ok") == true and count_receipt.get("satchel_count") == base_count + 1,
			"satchel_count %d is affordable and projects %d" % [base_count, base_count + 1])

	# Deep-copy / immutability checks on catalog, event record, snapshot, preview and receipt:
	_check(warden_catalog == catalog_original, "caller's Warden catalog is never mutated")
	_check(event_record == event_original, "caller's authored event record is never mutated")
	_check(snapshot == snapshot_original, "caller's snapshot is never mutated")
	claim_entry["part"]["id"] = "mutated_id"
	claim_entry["part"]["tier"] = 99
	claim_receipt["part"]["id"] = "mutated_receipt_id"
	claim_receipt["part"]["tier"] = 1
	var fresh_check := RunStitchedEventConsequence.new(event_record, warden_catalog)
	var fresh_preview := fresh_check.preview(snapshot)
	_check(_entry(fresh_preview, "claim_pot_helm").get("part")
		== {"id": "warden_head_pot_helm_bonk", "tier": 2},
		"mutating preview or receipt part dictionary never aliases future calls")
	var mutated_catalog := warden_catalog.duplicate(true)
	mutated_catalog["by_id"].clear()
	mutated_catalog["parts"].clear()
	var after_catalog_mutation := fresh_check.choose("claim_pot_helm", snapshot)
	_check(after_catalog_mutation.get("ok") == true
		and after_catalog_mutation.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2},
		"mutating caller catalog after construction never affects the service")


func _test_part_prize_rejections() -> void:
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var event_record := _part_bargain_event()

	# 1. AC2: Full six-part satchel (satchel_count == 6) disables only part choices;
	#    choose rejects without claiming; Leave and ordinary choices still commit once; replay rejects.
	var full_snap := _scraps_satchel_four(40, 4, 6, [95, 0, 50, 200])
	var full_original := full_snap.duplicate(true)
	var full_service := RunStitchedEventConsequence.new(event_record, warden_catalog)
	var full_preview := full_service.preview(full_snap)
	_check(full_preview.get("ok") == true, "full satchel (6) snapshot still preflights")
	var full_claim_entry := _entry(full_preview, "claim_pot_helm")
	_check(full_claim_entry.get("available") == false
		and full_claim_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and full_claim_entry.get("satchel_count") == 6
		and full_claim_entry.get("candle") == 40
		and full_claim_entry.get("fray") == {},
		"AC2: at satchel_count 6, party part choice is unavailable and keeps count 6 / base candle 40")
	var full_buy_entry := _entry(full_preview, "buy_pot_helm")
	_check(full_buy_entry.get("available") == false
		and full_buy_entry.get("satchel_count") == 6
		and full_buy_entry.get("scraps") == 4
		and full_buy_entry.get("candle") == 40
		and full_buy_entry.get("fray") == {},
		"AC2: at satchel_count 6, scraps+part choice is unavailable without projecting scraps or fray")
	_check(_entry(full_preview, "leave").get("available") == true,
		"AC2: at satchel_count 6, Leave remains available")
	_assert_rejected(full_service, "claim_pot_helm", full_snap, 40, "AC2: full satchel party part choice")
	_assert_rejected(full_service, "buy_pot_helm", full_snap, 40, "AC2: full satchel scraps+part choice")
	_check(not full_service.is_claimed(), "AC2: full satchel rejections leave visit unclaimed")
	var full_leave_receipt := full_service.choose("leave", full_snap)
	_check(full_leave_receipt.get("ok") == true
		and full_leave_receipt.get("candle") == 40
		and full_leave_receipt.get("fray") == {}
		and not full_leave_receipt.has("part")
		and not full_leave_receipt.has("satchel_count"),
		"AC2: Leave commits on the same visit after full-satchel rejections")
	_assert_rejected(full_service, "leave", full_snap, 40, "AC2: replay after full-satchel Leave")
	_check(full_snap == full_original, "AC2: full-satchel checks never mutate caller snapshot")

	# Ordinary non-Leave choice also commits on the same visit when satchel_count == 6:
	var ordinary_full_event := _event([
		_choice("claim_pot_helm", "Take helm.",
			_part_effect(-15, 20, {"id": "warden_head_pot_helm_bonk", "tier": 2})),
		_choice("mend_party", "Spend scraps to calm the party.", _scraps_effect(25, -25, -2)),
		_choice("leave", "Leave.", _effect(0, 0)),
	])
	var ordinary_full_service := RunStitchedEventConsequence.new(ordinary_full_event, warden_catalog)
	_assert_rejected(ordinary_full_service, "claim_pot_helm", full_snap, 40,
		"AC2: full satchel rejects part choice before ordinary sibling")
	var ordinary_full_receipt := ordinary_full_service.choose("mend_party", full_snap)
	_check(ordinary_full_receipt.get("ok") == true
		and ordinary_full_receipt.get("candle") == 65
		and ordinary_full_receipt.get("scraps") == 2
		and not ordinary_full_receipt.has("part")
		and not ordinary_full_receipt.has("satchel_count"),
		"AC2: ordinary scraps choice commits normally when satchel_count is 6")
	_assert_rejected(ordinary_full_service, "leave", full_snap, 40,
		"AC2: replay rejected after ordinary choice commits")

	# 2. AC2: Missing satchel_count in snapshot disables only part choices;
	#    Leave and ordinary choices still commit on the same visit.
	var missing_count_snap := _scraps_four(40, 4, [95, 0, 50, 200])
	var missing_count_original := missing_count_snap.duplicate(true)
	var missing_count_service := RunStitchedEventConsequence.new(ordinary_full_event, warden_catalog)
	var missing_count_preview := missing_count_service.preview(missing_count_snap)
	_check(missing_count_preview.get("ok") == true,
		"AC2: snapshot without satchel_count still preflights on a mixed part/ordinary Event")
	var missing_part_entry := _entry(missing_count_preview, "claim_pot_helm")
	_check(missing_part_entry.get("available") == false
		and missing_part_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and missing_part_entry.get("satchel_count") == null
		and missing_part_entry.get("candle") == 40
		and missing_part_entry.get("fray") == {},
		"AC2: missing satchel_count makes part choice unavailable with null satchel_count")
	_check(_entry(missing_count_preview, "mend_party").get("available") == true
		and _entry(missing_count_preview, "leave").get("available") == true,
		"AC2: missing satchel_count leaves ordinary and Leave choices available")
	_assert_rejected(missing_count_service, "claim_pot_helm", missing_count_snap, 40,
		"AC2: missing satchel_count part choice")
	var missing_ordinary_receipt := missing_count_service.choose("mend_party", missing_count_snap)
	_check(missing_ordinary_receipt.get("ok") == true and missing_ordinary_receipt.get("scraps") == 2,
		"AC2: ordinary choice commits after missing-satchel_count refusal")
	_assert_rejected(missing_count_service, "leave", missing_count_snap, 40,
		"AC2: replay fails after missing-satchel_count fallback commit")
	_check(missing_count_snap == missing_count_original,
		"AC2: missing-satchel_count checks leave snapshot untouched")

	# Also check {candle, party} snapshot (neither scraps nor satchel_count) on part Event:
	var bare_snap := _four(40, [95, 0, 50, 200])
	var bare_service := RunStitchedEventConsequence.new(event_record, warden_catalog)
	_assert_rejected(bare_service, "claim_pot_helm", bare_snap, 40, "bare snapshot part choice")
	_assert_rejected(bare_service, "buy_pot_helm", bare_snap, 40, "bare snapshot scraps+part choice")
	var bare_leave := bare_service.choose("leave", bare_snap)
	_check(bare_leave.get("ok") == true and bare_leave.get("candle") == 40,
		"bare {candle, party} snapshot still commits Leave on a part Event")

	# Scraps+part choice where satchel has room (5) but scraps are insufficient (1 vs -2):
	var low_scraps_part_snap := _scraps_satchel_four(40, 1, 5, [95, 0, 50, 200])
	var low_scraps_part_service := RunStitchedEventConsequence.new(event_record, warden_catalog)
	var low_scraps_part_preview := low_scraps_part_service.preview(low_scraps_part_snap)
	_check(_entry(low_scraps_part_preview, "buy_pot_helm").get("available") == false
		and _entry(low_scraps_part_preview, "buy_pot_helm").get("scraps") == 1
		and _entry(low_scraps_part_preview, "buy_pot_helm").get("satchel_count") == 5
		and _entry(low_scraps_part_preview, "claim_pot_helm").get("available") == true,
		"insufficient scraps disables only the scraps-costing part choice while free part choice stays available")
	_assert_rejected(low_scraps_part_service, "buy_pot_helm", low_scraps_part_snap, 40,
		"insufficient scraps on scraps+part choice")
	var free_part_receipt := low_scraps_part_service.choose("claim_pot_helm", low_scraps_part_snap)
	_check(free_part_receipt.get("ok") == true and free_part_receipt.get("satchel_count") == 6,
		"free part sibling still commits after insufficient-scraps part refusal")

	# Absent hero on a hero-targeted part choice:
	var no_scarecrow_snap := _satchel_four(40, 5, [95, 0, 50, 200])
	var absent_hero_part_service := RunStitchedEventConsequence.new(_event([
		_choice("scarecrow_helm", "Give to absent scarecrow.",
			_part_effect(10, -10, {"id": "warden_head_pot_helm_bonk", "tier": 1}, "hero", "scarecrow")),
		_choice("leave", "Leave.", _effect(0, 0)),
	]), warden_catalog)
	var absent_part_entry := _entry(absent_hero_part_service.preview(no_scarecrow_snap), "scarecrow_helm")
	_check(absent_part_entry.get("available") == false
		and absent_part_entry.get("satchel_count") == 5
		and absent_part_entry.get("candle") == 40
		and absent_part_entry.get("fray") == {},
		"absent target hero makes hero-targeted part choice unavailable without incrementing satchel_count")
	_assert_rejected(absent_hero_part_service, "scarecrow_helm", no_scarecrow_snap, 40,
		"absent hero on part choice")
	_check(absent_hero_part_service.choose("leave", no_scarecrow_snap).get("ok") == true,
		"Leave commits after absent-hero part refusal")

	# 3. AC3: Absent or invalid catalog, unknown part ID, illegal tiers (0, 4, fraction, string, bool, null),
	#    and malformed part structures disable only the broken choice; legal sibling still commits.
	var valid_part_snap := _scraps_satchel_four(40, 4, 5, [95, 0, 50, 200])
	var missing_file_catalog := StitchedParts.load_catalog("res://data/parts/missing_parts_file.json")
	var tampered_catalog := warden_catalog.duplicate(true)
	tampered_catalog["parts"][0]["slot"] = "wings"
	var mismatched_by_id := warden_catalog.duplicate(true)
	mismatched_by_id["by_id"].erase("warden_head_pot_helm_bonk")
	var bad_catalogs: Array = [
		null,
		{},
		[],
		"res://data/parts/warden_parts.json",
		42,
		missing_file_catalog,
		{"ok": false, "parts": warden_catalog["parts"], "by_id": warden_catalog["by_id"]},
		{"ok": true, "parts": [], "by_id": {}},
		{"parts": "not_an_array"},
		{"parts": warden_catalog["parts"], "unexpected": true},
		tampered_catalog,
		mismatched_by_id,
		{"wrong_key": warden_catalog["parts"][0]},
	]
	for index in range(bad_catalogs.size()):
		var bad_cat: Variant = bad_catalogs[index]
		var cat_service := RunStitchedEventConsequence.new(ordinary_full_event, bad_cat)
		var cat_preview := cat_service.preview(valid_part_snap)
		_check(cat_preview.get("ok") == true,
			"bad catalog %d still allows Event preflight" % index)
		var cat_part_entry := _entry(cat_preview, "claim_pot_helm")
		_check(cat_part_entry.get("available") == false
			and cat_part_entry.get("part") == null
			and cat_part_entry.get("satchel_count") == null,
			"bad catalog %d disables part choice without exposing a part prize" % index)
		_check(_entry(cat_preview, "mend_party").get("available") == true,
			"bad catalog %d leaves non-part sibling available" % index)
		_assert_rejected(cat_service, "claim_pot_helm", valid_part_snap, 40,
			"bad catalog %d part commit" % index)
		var cat_sibling := cat_service.choose("mend_party", valid_part_snap)
		_check(cat_sibling.get("ok") == true and cat_sibling.get("scraps") == 2,
			"bad catalog %d allows non-part sibling to commit" % index)
		_assert_rejected(cat_service, "leave", valid_part_snap, 40,
			"replay after bad catalog %d sibling commit" % index)

	var broken_part_Payloads: Array = [
		{"id": "unknown_warden_part", "tier": 2},
		{"id": "porcelain_crown", "tier": 1},
		{"id": "", "tier": 2},
		{"id": "   ", "tier": 2},
		{"id": " warden_head_pot_helm_bonk", "tier": 2},
		{"id": "warden_head_pot_helm_bonk ", "tier": 2},
		{"id": 42, "tier": 2},
		{"id": null, "tier": 2},
		{"id": "warden_head_pot_helm_bonk", "tier": 0},
		{"id": "warden_head_pot_helm_bonk", "tier": 4},
		{"id": "warden_head_pot_helm_bonk", "tier": -1},
		{"id": "warden_head_pot_helm_bonk", "tier": 1.5},
		{"id": "warden_head_pot_helm_bonk", "tier": 2.0},
		{"id": "warden_head_pot_helm_bonk", "tier": "2"},
		{"id": "warden_head_pot_helm_bonk", "tier": true},
		{"id": "warden_head_pot_helm_bonk", "tier": null},
		{"id": "warden_head_pot_helm_bonk"},
		{"tier": 2},
		{"id": "warden_head_pot_helm_bonk", "tier": 2, "slot": "head"},
		{},
		[],
		"warden_head_pot_helm_bonk",
		2,
		null,
	]
	for index in range(broken_part_Payloads.size()):
		var broken_event := _event([
			_choice("broken_part", "Broken part prize.",
				_part_effect(-10, 10, broken_part_Payloads[index])),
			_choice("leave", "Leave.", _effect(0, 0)),
		])
		var broken_service := RunStitchedEventConsequence.new(broken_event, warden_catalog)
		var broken_preview := broken_service.preview(valid_part_snap)
		var broken_entry := _entry(broken_preview, "broken_part")
		_check(broken_entry.get("available") == false
			and broken_entry.get("candle_delta") == null
			and broken_entry.get("fray_delta") == null
			and broken_entry.get("part") == null
			and broken_entry.get("satchel_count") == null,
			"malformed/unknown part payload %d is unavailable with null deltas/part" % index)
		_check(_entry(broken_preview, "leave").get("available") == true,
			"malformed/unknown part payload %d leaves sibling available" % index)
		_assert_rejected(broken_service, "broken_part", valid_part_snap, 40,
			"malformed/unknown part payload %d commit" % index)
		var fallback_receipt := broken_service.choose("leave", valid_part_snap)
		_check(fallback_receipt.get("ok") == true and fallback_receipt.get("candle") == 40,
			"malformed/unknown part payload %d still lets sibling commit" % index)
		_assert_rejected(broken_service, "leave", valid_part_snap, 40,
			"replay after malformed/unknown part payload %d fallback" % index)

	# 4. AC3: Bad snapshot satchel_count (-1, 7, fraction, string, bool, null, etc.) rejected:
	var count_service := RunStitchedEventConsequence.new(event_record, warden_catalog)
	var bad_counts: Array = [-1, 7, -9223372036854775807, 9223372036854775807, 1.5, 5.0, "5", true, false, null, [], {}]
	for index in range(bad_counts.size()):
		var bad_count_snap := _satchel_four(40, bad_counts[index], [95, 0, 50, 200])
		_check(count_service.preview(bad_count_snap) == _denied_preview(),
			"bad satchel_count %d denies preflight" % index)
		_assert_rejected(count_service, "claim_pot_helm", bad_count_snap, 0,
			"bad satchel_count %d commit" % index)
		var bad_both_snap := _scraps_satchel_four(40, 4, bad_counts[index], [95, 0, 50, 200])
		_check(count_service.preview(bad_both_snap) == _denied_preview(),
			"bad satchel_count %d with scraps denies preflight" % index)
		_assert_rejected(count_service, "buy_pot_helm", bad_both_snap, 0,
			"bad satchel_count %d with scraps commit" % index)
	var extra_snap := _scraps_satchel_four(40, 4, 5, [95, 0, 50, 200])
	extra_snap["extra"] = 1
	_check(count_service.preview(extra_snap) == _denied_preview(),
		"snapshot with extra key alongside scraps and satchel_count denies preflight")
	_assert_rejected(count_service, "claim_pot_helm", extra_snap, 0,
		"snapshot with extra key alongside scraps and satchel_count commit")
	_check(not count_service.is_claimed(),
		"bad satchel_count snapshots never latch the visit")
	var valid_recovery := count_service.choose("claim_pot_helm", valid_part_snap)
	_check(valid_recovery.get("ok") == true
		and valid_recovery.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and valid_recovery.get("satchel_count") == 6,
		"same instance still commits legal part choice after bad-count refusals")
	_assert_rejected(count_service, "leave", valid_part_snap, 40,
		"replay refused after recovered part claim")

	# 5. Global RNG invariance across part rejections and fallback commit:
	seed(20261107)
	var expected_reject_rng := randi()
	seed(20261107)
	var rng_part_service := RunStitchedEventConsequence.new(event_record, warden_catalog)
	_check(rng_part_service.preview(full_snap).get("ok") == true, "rng full-satchel preflight")
	_assert_rejected(rng_part_service, "claim_pot_helm", full_snap, 40, "rng full-satchel refusal")
	_assert_rejected(rng_part_service, "claim_pot_helm", missing_count_snap, 40, "rng missing-count refusal")
	_check(rng_part_service.choose("leave", full_snap).get("ok") == true, "rng fallback Leave claim")
	_assert_rejected(rng_part_service, "leave", full_snap, 40, "rng replay refusal")
	_check(randi() == expected_reject_rng,
		"AC2: part refusals, fallback claim and replay never advance the global RNG")


func _gold_effect(candle: int, fray: int, gold: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {"candle": candle, "fray": fray, "target": target, "gold": gold}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _gold_scraps_effect(candle: int, fray: int, gold: Variant, scraps: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {
		"candle": candle,
		"fray": fray,
		"target": target,
		"gold": gold,
		"scraps": scraps,
	}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _gold_scraps_part_effect(candle: int, fray: int, gold: Variant, scraps: Variant,
		part: Variant, target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {
		"candle": candle,
		"fray": fray,
		"target": target,
		"gold": gold,
		"scraps": scraps,
		"part": part,
	}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _gold_snapshot(candle: int, gold: Variant, hero_pairs: Array) -> Dictionary:
	var snapshot := _snapshot(candle, hero_pairs)
	snapshot["gold"] = gold
	return snapshot


func _gold_four(candle: int, gold: Variant, frays: Array) -> Dictionary:
	var snapshot := _four(candle, frays)
	snapshot["gold"] = gold
	return snapshot


func _gold_scraps_four(candle: int, scraps: Variant, gold: Variant, frays: Array) -> Dictionary:
	var snapshot := _four(candle, frays)
	snapshot["scraps"] = scraps
	snapshot["gold"] = gold
	return snapshot


func _gold_scraps_satchel_four(candle: int, scraps: Variant, gold: Variant,
		satchel_count: Variant, frays: Array) -> Dictionary:
	var snapshot := _four(candle, frays)
	snapshot["scraps"] = scraps
	snapshot["gold"] = gold
	snapshot["satchel_count"] = satchel_count
	return snapshot


func _gold_bargain_event() -> Dictionary:
	return _event([
		_choice("tend_wick", "Tend the guttering wick", _gold_effect(25, -5, -12)),
		_choice("sell_wick", "Sell a brass wick", _gold_effect(-8, 0, 12)),
		_choice("leave", "Leave the brazier untouched.", _effect(0, 0)),
	], "ev_stitched_gold_bargain")


func _test_gold_bargains() -> void:
	# Canonical eight-ID roster coverage for gold-bearing hero and party choices,
	# plus legacy choices without the gold key on a gold-bearing snapshot.
	for hero_id in REQUIRED_IDS:
		var roster_snap := _gold_snapshot(50, 30, [[hero_id, 110]])
		var roster_service := RunStitchedEventConsequence.new(_event([
			_choice("hero_gold", "Hero gold.", _gold_effect(-8, 10, 12, "hero", hero_id)),
			_choice("party_gold", "Party gold.", _gold_effect(25, -5, -12)),
			_choice("legacy_leave", "Legacy leave.", _effect(0, 0)),
		]))
		var roster_preview := roster_service.preview(roster_snap)
		var hero_entry := _entry(roster_preview, "hero_gold")
		_check(hero_entry.get("available") == true and hero_entry.get("hero_id") == hero_id
			and hero_entry.get("gold_delta") == 12 and hero_entry.get("gold") == 42
			and hero_entry.get("candle") == 42 and hero_entry.get("fray") == {hero_id: 10},
			"canonical hero %s accepts gold-bearing hero effect with shared party gold" % hero_id)
		var legacy_entry := _entry(roster_preview, "legacy_leave")
		_check(legacy_entry.get("available") == true and not legacy_entry.has("gold")
			and not legacy_entry.has("gold_delta"),
			"legacy choice alongside gold choices retains exact non-gold preview shape for %s" % hero_id)
		var hero_receipt := roster_service.choose("hero_gold", roster_snap)
		_check(hero_receipt.get("ok") == true and hero_receipt.get("gold") == 42
			and hero_receipt.get("gold_delta") == 12 and hero_receipt.get("fray") == {hero_id: 10},
			"canonical hero %s receipt reports shared party gold and single-hero fray" % hero_id)

	# Preserve exact pre-existing non-gold preview/receipt keys when snapshot carries gold
	# alongside optional scraps and/or satchel_count.
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var snap_gold_only := _gold_four(50, 30, [95, 0, 50, 200])
	var snap_gold_scraps := _gold_scraps_four(50, 3, 30, [95, 0, 50, 200])
	var snap_all_purses := _gold_scraps_satchel_four(50, 3, 30, 5, [95, 0, 50, 200])
	for non_gold_snap in [snap_gold_only, snap_gold_scraps, snap_all_purses]:
		var non_gold_service := RunStitchedEventConsequence.new(_bargain_event())
		var non_gold_preview := non_gold_service.preview(non_gold_snap)
		_check(non_gold_preview.get("ok") == true,
			"non-gold event preflights when snapshot includes gold")
		var non_gold_entry := _entry(non_gold_preview, "bargain")
		_check(non_gold_entry.get("available") == true
			and not non_gold_entry.has("gold")
			and not non_gold_entry.has("gold_delta")
			and _receipt_keys(non_gold_entry) == [
				"available", "candle", "candle_delta", "choice_id",
				"fray", "fray_delta", "hero_id", "target",
			],
			"non-gold preview entry keeps exact 8-key shape when snapshot includes gold")
		var non_gold_receipt := non_gold_service.choose("bargain", non_gold_snap)
		_check(non_gold_receipt.get("ok") == true
			and not non_gold_receipt.has("gold")
			and not non_gold_receipt.has("gold_delta")
			and _receipt_keys(non_gold_receipt) == [
				"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
			],
			"non-gold receipt keeps exact 7-key shape when snapshot includes gold")

	var scraps_with_gold_service := RunStitchedEventConsequence.new(_scraps_bargain_event())
	var scraps_with_gold_receipt := scraps_with_gold_service.choose("mend_party", snap_gold_scraps)
	_check(scraps_with_gold_receipt.get("ok") == true
		and not scraps_with_gold_receipt.has("gold")
		and not scraps_with_gold_receipt.has("gold_delta")
		and _receipt_keys(scraps_with_gold_receipt) == [
			"candle", "choice_id", "event_id", "fray", "hero_id",
			"ok", "scraps", "scraps_delta", "target",
		],
		"scraps-only receipt keeps exact 9-key shape when snapshot includes gold")

	var part_with_gold_service := RunStitchedEventConsequence.new(_part_bargain_event(), warden_catalog)
	var part_with_gold_receipt := part_with_gold_service.choose("claim_pot_helm", snap_all_purses)
	_check(part_with_gold_receipt.get("ok") == true
		and not part_with_gold_receipt.has("gold")
		and not part_with_gold_receipt.has("gold_delta")
		and _receipt_keys(part_with_gold_receipt) == [
			"candle", "choice_id", "event_id", "fray", "hero_id",
			"ok", "part", "satchel_count", "target",
		],
		"part-only receipt keeps exact 9-key shape when snapshot includes gold")

	# AC1: Snapshot {candle: 50, party: four heroes, scraps: 3, gold: 30} with
	# "Tend the guttering wick" (gold -12, candle +25, fray -5 party) and
	# "Sell a brass wick" (gold +12, candle -8, fray 0).
	var event_record := _gold_bargain_event()
	var event_original := event_record.duplicate(true)
	var snapshot := _gold_scraps_four(50, 3, 30, [95, 0, 50, 200])
	var snapshot_original := snapshot.duplicate(true)

	seed(20261108)
	var expected_rng := randi()
	seed(20261108)

	var service := RunStitchedEventConsequence.new(event_record)
	var preview := service.preview(snapshot)
	_check(preview.get("ok") == true and preview.get("event_id") == "ev_stitched_gold_bargain"
		and preview.get("candle") == 50,
		"AC1: gold bargain preflight succeeds and reports base candle 50")

	var tend_entry := _entry(preview, "tend_wick")
	_check(tend_entry.get("available") == true
		and tend_entry.get("target") == "party"
		and tend_entry.get("hero_id") == ""
		and tend_entry.get("candle_delta") == 25
		and tend_entry.get("fray_delta") == -5
		and tend_entry.get("gold_delta") == -12
		and tend_entry.get("candle") == 75
		and tend_entry.get("gold") == 18
		and tend_entry.get("fray") == {
			"warden": -5, "seamstress": -5, "tinker": -5, "button_golem": -5,
		}
		and not tend_entry.has("scraps")
		and not tend_entry.has("scraps_delta")
		and not tend_entry.has("part")
		and not tend_entry.has("satchel_count"),
		"AC1: Tend the guttering wick previews candle 75, gold_delta -12, gold 18 and each hero fray intent -5")

	var sell_entry := _entry(preview, "sell_wick")
	_check(sell_entry.get("available") == true
		and sell_entry.get("target") == "party"
		and sell_entry.get("hero_id") == ""
		and sell_entry.get("candle_delta") == -8
		and sell_entry.get("fray_delta") == 0
		and sell_entry.get("gold_delta") == 12
		and sell_entry.get("candle") == 42
		and sell_entry.get("gold") == 42
		and sell_entry.get("fray") == {}
		and not sell_entry.has("scraps"),
		"AC2: Sell a brass wick previews candle 42, gold_delta +12, gold 42 and empty fray map")

	var leave_entry := _entry(preview, "leave")
	_check(leave_entry.get("available") == true
		and leave_entry.get("candle") == 50
		and leave_entry.get("fray") == {}
		and not leave_entry.has("gold")
		and not leave_entry.has("gold_delta")
		and not leave_entry.has("scraps"),
		"AC1/AC3: Leave sibling on gold Event keeps exact non-gold preview shape")

	var tend_receipt := service.choose("tend_wick", snapshot)
	_check(tend_receipt.get("ok") == true
		and tend_receipt.get("event_id") == "ev_stitched_gold_bargain"
		and tend_receipt.get("choice_id") == "tend_wick"
		and tend_receipt.get("target") == "party"
		and tend_receipt.get("hero_id") == ""
		and tend_receipt.get("candle") == 75
		and tend_receipt.get("gold_delta") == -12
		and tend_receipt.get("gold") == 18
		and tend_receipt.get("fray") == {
			"warden": -5, "seamstress": -5, "tinker": -5, "button_golem": -5,
		},
		"AC1: Tend the guttering wick receipt agrees with preview (candle 75, gold_delta -12, gold 18, fray -5 per hero)")
	_check(_receipt_keys(tend_receipt) == [
		"candle", "choice_id", "event_id", "fray", "gold",
		"gold_delta", "hero_id", "ok", "target",
	], "AC1: gold-only receipt has exact 9-key shape")
	_check(service.is_claimed() and not service.is_valid(),
		"AC1: committing a gold choice latches the visit")
	_assert_rejected(service, "tend_wick", snapshot, 50, "AC2: replay of committed gold choice")
	_assert_rejected(service, "sell_wick", snapshot, 50, "AC2: alternative after committed gold choice")

	# Two independent fresh visits produce identical receipts, source dictionaries stay unchanged,
	# and global RNG does not advance.
	var second_visit := RunStitchedEventConsequence.new(event_record)
	var second_receipt := second_visit.choose("tend_wick", snapshot.duplicate(true))
	_check(tend_receipt == second_receipt,
		"AC1: two fresh visits produce identical receipts")
	_check(snapshot == snapshot_original and event_record == event_original,
		"AC1: source snapshot, party, wallet and Event dictionaries remain untouched")
	_check(randi() == expected_rng,
		"AC1: construction, preview, commit, replay and fresh visit never advance global RNG")

	# Deep-copy detachment on preview and receipt mutation:
	tend_entry["gold"] = -999
	tend_entry["fray"]["warden"] = 999
	tend_receipt["gold"] = -999
	tend_receipt["fray"]["warden"] = 999
	_check(snapshot == snapshot_original,
		"AC1: mutating returned preview or receipt never mutates caller snapshot")
	_check(RunStitchedEventConsequence.new(event_record).choose("tend_wick", snapshot) == second_receipt,
		"AC1: mutating returned receipt never affects subsequent visits")

	# AC2: +12 -> 42 commit, zero gold delta, and combined gold -12 / scraps -2 on the same choice:
	var sell_visit := RunStitchedEventConsequence.new(event_record)
	var sell_receipt := sell_visit.choose("sell_wick", snapshot)
	_check(sell_receipt.get("ok") == true
		and sell_receipt.get("candle") == 42
		and sell_receipt.get("gold_delta") == 12
		and sell_receipt.get("gold") == 42
		and sell_receipt.get("fray") == {},
		"AC2: +12 gold choice commits with gold 42 and candle 42")
	_assert_rejected(sell_visit, "sell_wick", snapshot, 50, "AC2: replay after +12 gold choice")

	var combined_event := _event([
		_choice("combined_mend", "Pay gold and scraps to mend the party.",
			_gold_scraps_effect(25, -5, -12, -2)),
		_choice("zero_gold_leave", "Inspect the coins without trading.",
			_gold_effect(0, 0, 0)),
		_choice("combined_part", "Buy the pot helm with gold and scraps.",
			_gold_scraps_part_effect(10, -10, -12, -2, {"id": "warden_head_pot_helm_bonk", "tier": 2}, "hero", "warden")),
	], "ev_stitched_combined_gold")

	var combined_service := RunStitchedEventConsequence.new(combined_event, warden_catalog)
	var combined_preview := combined_service.preview(snap_all_purses)
	var zero_entry := _entry(combined_preview, "zero_gold_leave")
	_check(zero_entry.get("available") == true
		and zero_entry.get("gold_delta") == 0
		and zero_entry.get("gold") == 30
		and zero_entry.get("candle") == 50
		and zero_entry.get("fray") == {}
		and not zero_entry.has("scraps"),
		"AC2: zero-delta gold choice previews unchanged gold 30 and empty fray")
	var zero_visit := RunStitchedEventConsequence.new(combined_event, warden_catalog)
	var zero_receipt := zero_visit.choose("zero_gold_leave", snap_all_purses)
	_check(zero_receipt.get("ok") == true
		and zero_receipt.get("gold_delta") == 0
		and zero_receipt.get("gold") == 30
		and zero_receipt.get("candle") == 50
		and zero_receipt.get("fray") == {},
		"AC2: zero-delta gold choice commits once with gold_delta 0 and gold 30")
	_assert_rejected(zero_visit, "zero_gold_leave", snap_all_purses, 50, "AC2: replay after zero-delta gold choice")

	var both_entry := _entry(combined_preview, "combined_mend")
	_check(both_entry.get("available") == true
		and both_entry.get("candle") == 75
		and both_entry.get("gold_delta") == -12
		and both_entry.get("gold") == 18
		and both_entry.get("scraps_delta") == -2
		and both_entry.get("scraps") == 1
		and both_entry.get("fray") == {
			"warden": -5, "seamstress": -5, "tinker": -5, "button_golem": -5,
		}
		and not both_entry.has("part"),
		"AC2: simultaneous gold -12 and scraps -2 choice previews gold 18 and scraps 1")
	var both_receipt := combined_service.choose("combined_mend", snap_all_purses)
	_check(both_receipt.get("ok") == true
		and both_receipt.get("candle") == 75
		and both_receipt.get("gold_delta") == -12
		and both_receipt.get("gold") == 18
		and both_receipt.get("scraps_delta") == -2
		and both_receipt.get("scraps") == 1
		and both_receipt.get("fray") == {
			"warden": -5, "seamstress": -5, "tinker": -5, "button_golem": -5,
		},
		"AC2: simultaneous gold -12 and scraps -2 choice commits with exact preview parity")
	_check(_receipt_keys(both_receipt) == [
		"candle", "choice_id", "event_id", "fray", "gold", "gold_delta",
		"hero_id", "ok", "scraps", "scraps_delta", "target",
	], "AC2: simultaneous gold+scraps receipt has exact 11-key shape")
	_assert_rejected(combined_service, "combined_mend", snap_all_purses, 50,
		"AC2: replay after simultaneous gold+scraps choice")
	_check(RunStitchedEventConsequence.new(combined_event, warden_catalog).choose("combined_mend", snap_all_purses)
		== both_receipt,
		"AC2: simultaneous gold+scraps choice is deterministic across fresh visits")

	var triple_entry := _entry(combined_preview, "combined_part")
	_check(triple_entry.get("available") == true
		and triple_entry.get("gold_delta") == -12
		and triple_entry.get("gold") == 18
		and triple_entry.get("scraps_delta") == -2
		and triple_entry.get("scraps") == 1
		and triple_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and triple_entry.get("satchel_count") == 6
		and triple_entry.get("fray") == {"warden": -10},
		"gold+scraps+part choice previews gold 18, scraps 1, part tier 2 and satchel_count 6")
	var triple_visit := RunStitchedEventConsequence.new(combined_event, warden_catalog)
	var triple_receipt := triple_visit.choose("combined_part", snap_all_purses)
	_check(triple_receipt.get("ok") == true
		and triple_receipt.get("gold") == 18
		and triple_receipt.get("scraps") == 1
		and triple_receipt.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and triple_receipt.get("satchel_count") == 6,
		"gold+scraps+part choice commits with exact preview parity")

	# JSON-parsed integral float gold deltas, exact spend to 0, candle clamp, and exact MAX_INT credit:
	var json_gold_event: Dictionary = JSON.parse_string(JSON.stringify(_event([
		_choice("spend_all_gold", "Spend all 30 gold.", _gold_effect(80, -10, -30)),
		_choice("cap_gold_credit", "Credit up to MAX_INT.", _gold_effect(-70, 15, 7, "hero", "tinker")),
	])))
	var spend_all_visit := RunStitchedEventConsequence.new(json_gold_event)
	var spend_all_receipt := spend_all_visit.choose("spend_all_gold", snapshot)
	_check(spend_all_receipt.get("ok") == true
		and spend_all_receipt.get("candle") == 100
		and spend_all_receipt.get("gold_delta") == -30
		and spend_all_receipt.get("gold") == 0,
		"JSON-parsed integral gold delta spends down to 0 and clamps candle at 100")
	var near_max_gold_snap := _gold_four(50, 9223372036854775800, [95, 0, 50, 200])
	var max_gold_visit := RunStitchedEventConsequence.new(json_gold_event)
	var max_gold_receipt := max_gold_visit.choose("cap_gold_credit", near_max_gold_snap)
	_check(max_gold_receipt.get("ok") == true
		and max_gold_receipt.get("candle") == 0
		and max_gold_receipt.get("gold_delta") == 7
		and max_gold_receipt.get("gold") == 9223372036854775807
		and max_gold_receipt.get("fray") == {"tinker": 15},
		"positive gold credit up to exact 64-bit MAX_INT succeeds and clamps candle at 0")


func _test_gold_rejections() -> void:
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")

	# 1. AC2: With gold 5, the -12 choice is disabled, refused without latching or advancing RNG,
	#    and Leave (or a legal +12 alternative) on that SAME instance still commits once.
	var low_gold := _gold_scraps_four(50, 3, 5, [95, 0, 50, 200])
	var low_original := low_gold.duplicate(true)

	seed(20261109)
	var expected_rng := randi()
	seed(20261109)

	var low_service := RunStitchedEventConsequence.new(_gold_bargain_event())
	var low_preview := low_service.preview(low_gold)
	var unaffordable_entry := _entry(low_preview, "tend_wick")
	_check(unaffordable_entry.get("available") == false
		and unaffordable_entry.get("gold_delta") == -12
		and unaffordable_entry.get("gold") == 5
		and unaffordable_entry.get("candle") == 50
		and unaffordable_entry.get("fray") == {},
		"AC2: with gold 5, the -12 choice is unavailable and retains unchanged base candle 50 and gold 5")
	_check(_entry(low_preview, "sell_wick").get("available") == true
		and _entry(low_preview, "leave").get("available") == true,
		"AC2: with gold 5, +12 and Leave alternatives remain available")
	_assert_rejected(low_service, "tend_wick", low_gold, 50, "AC2: insufficient gold (5 vs -12)")
	_check(not low_service.is_claimed(), "AC2: refusing insufficient gold never latches the visit")
	var leave_receipt := low_service.choose("leave", low_gold)
	_check(leave_receipt.get("ok") == true
		and leave_receipt.get("candle") == 50
		and leave_receipt.get("fray") == {}
		and _receipt_keys(leave_receipt) == [
			"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
		],
		"AC2: after -12 refusal with gold 5, Leave still commits on the same instance with exact 7-key receipt")
	_assert_rejected(low_service, "leave", low_gold, 50, "AC2: replay after Leave commit")
	_check(low_gold == low_original, "AC2: insufficient gold refusal and fallback Leave never mutate caller snapshot")
	_check(randi() == expected_rng, "AC2: insufficient gold refusal, Leave commit and replay never draw global RNG")

	# Same gold 5 snapshot can also commit the +12 alternative after refusing -12:
	var alt_service := RunStitchedEventConsequence.new(_gold_bargain_event())
	_assert_rejected(alt_service, "tend_wick", low_gold, 50, "AC2: insufficient gold before +12 alternative")
	var alt_receipt := alt_service.choose("sell_wick", low_gold)
	_check(alt_receipt.get("ok") == true and alt_receipt.get("gold") == 17 and alt_receipt.get("candle") == 42,
		"AC2: after -12 refusal with gold 5, +12 alternative commits on the same visit")
	_assert_rejected(alt_service, "leave", low_gold, 50, "AC2: replay after +12 alternative commit")

	# Debit below zero from 0 gold:
	var zero_gold := _gold_four(50, 0, [95, 0, 50, 200])
	var debit_zero_service := RunStitchedEventConsequence.new(_event([
		_choice("debit_one", "Spend 1 gold.", _gold_effect(10, -10, -1)),
		_choice("zero_leave", "Hold coins.", _gold_effect(0, 0, 0)),
	]))
	_check(_entry(debit_zero_service.preview(zero_gold), "debit_one").get("available") == false,
		"debit below zero from 0 gold is unavailable")
	_assert_rejected(debit_zero_service, "debit_one", zero_gold, 50, "debit below zero from 0 gold")
	var zero_hold_receipt := debit_zero_service.choose("zero_leave", zero_gold)
	_check(zero_hold_receipt.get("ok") == true and zero_hold_receipt.get("gold") == 0,
		"zero-delta gold sibling commits at 0 gold after debit refusal")

	# 2. Combined gold + scraps + part choices require all applicable gates to pass:
	var combined_event := _event([
		_choice("both_cost", "Pay 12 gold and 2 scraps.", _gold_scraps_effect(25, -5, -12, -2)),
		_choice("triple_cost", "Pay 12 gold and 2 scraps for helm.",
			_gold_scraps_part_effect(10, -10, -12, -2, {"id": "warden_head_pot_helm_bonk", "tier": 2})),
		_choice("leave", "Leave.", _effect(0, 0)),
	])
	# Affordable gold (30), insufficient scraps (1 vs -2):
	var gold_ok_scraps_low := _gold_scraps_satchel_four(50, 1, 30, 5, [95, 0, 50, 200])
	var combo_service_a := RunStitchedEventConsequence.new(combined_event, warden_catalog)
	var combo_preview_a := combo_service_a.preview(gold_ok_scraps_low)
	var both_entry_a := _entry(combo_preview_a, "both_cost")
	_check(both_entry_a.get("available") == false
		and both_entry_a.get("gold") == 30
		and both_entry_a.get("scraps") == 1
		and both_entry_a.get("candle") == 50
		and both_entry_a.get("fray") == {},
		"combined gold+scraps choice with insufficient scraps keeps both old balances unprojected")
	_assert_rejected(combo_service_a, "both_cost", gold_ok_scraps_low, 50,
		"combined choice rejected when scraps insufficient")
	_check(combo_service_a.choose("leave", gold_ok_scraps_low).get("ok") == true,
		"Leave commits after combined scraps-insufficient refusal")

	# Affordable scraps (3), insufficient gold (5 vs -12):
	var scraps_ok_gold_low := _gold_scraps_satchel_four(50, 3, 5, 5, [95, 0, 50, 200])
	var combo_service_b := RunStitchedEventConsequence.new(combined_event, warden_catalog)
	var combo_preview_b := combo_service_b.preview(scraps_ok_gold_low)
	var both_entry_b := _entry(combo_preview_b, "both_cost")
	_check(both_entry_b.get("available") == false
		and both_entry_b.get("gold") == 5
		and both_entry_b.get("scraps") == 3
		and both_entry_b.get("candle") == 50
		and both_entry_b.get("fray") == {},
		"combined gold+scraps choice with insufficient gold keeps both old balances unprojected")
	_assert_rejected(combo_service_b, "both_cost", scraps_ok_gold_low, 50,
		"combined choice rejected when gold insufficient")
	_check(combo_service_b.choose("leave", scraps_ok_gold_low).get("ok") == true,
		"Leave commits after combined gold-insufficient refusal")

	# Affordable gold (30) and scraps (3), full satchel (6):
	var purses_ok_satchel_full := _gold_scraps_satchel_four(50, 3, 30, 6, [95, 0, 50, 200])
	var combo_service_c := RunStitchedEventConsequence.new(combined_event, warden_catalog)
	var combo_preview_c := combo_service_c.preview(purses_ok_satchel_full)
	var triple_entry_c := _entry(combo_preview_c, "triple_cost")
	_check(triple_entry_c.get("available") == false
		and triple_entry_c.get("gold") == 30
		and triple_entry_c.get("scraps") == 3
		and triple_entry_c.get("satchel_count") == 6
		and triple_entry_c.get("candle") == 50
		and triple_entry_c.get("fray") == {},
		"combined gold+scraps+part choice at satchel_count 6 keeps gold, scraps and satchel_count unprojected")
	_assert_rejected(combo_service_c, "triple_cost", purses_ok_satchel_full, 50,
		"combined gold+scraps+part choice rejected when satchel full")
	var non_part_combo_receipt := combo_service_c.choose("both_cost", purses_ok_satchel_full)
	_check(non_part_combo_receipt.get("ok") == true
		and non_part_combo_receipt.get("gold") == 18
		and non_part_combo_receipt.get("scraps") == 1,
		"non-part gold+scraps sibling still commits when satchel is full")

	# 3. AC3: Missing snapshot gold disables only gold-bearing choices and produces no gold-bearing receipt,
	#    while non-gold alternatives remain claimable.
	var missing_gold := _scraps_four(50, 3, [95, 0, 50, 200])
	var missing_original := missing_gold.duplicate(true)
	var missing_service := RunStitchedEventConsequence.new(_gold_bargain_event())
	var missing_preview := missing_service.preview(missing_gold)
	_check(missing_preview.get("ok") == true,
		"AC3: snapshot without gold still preflights on a mixed gold/non-gold Event")
	_check(_entry(missing_preview, "tend_wick").get("available") == false
		and _entry(missing_preview, "tend_wick").get("gold_delta") == -12
		and _entry(missing_preview, "tend_wick").get("gold") == null
		and _entry(missing_preview, "sell_wick").get("available") == false
		and _entry(missing_preview, "sell_wick").get("gold_delta") == 12
		and _entry(missing_preview, "sell_wick").get("gold") == null,
		"AC3: missing snapshot gold makes gold spend and gain choices unavailable with null gold")
	_check(_entry(missing_preview, "leave").get("available") == true,
		"AC3: missing snapshot gold leaves non-gold Leave choice available")
	_assert_rejected(missing_service, "tend_wick", missing_gold, 50, "AC3: missing gold on spend choice")
	_assert_rejected(missing_service, "sell_wick", missing_gold, 50, "AC3: missing gold on gain choice")
	var missing_fallback := missing_service.choose("leave", missing_gold)
	_check(missing_fallback.get("ok") == true
		and missing_fallback.get("candle") == 50
		and not missing_fallback.has("gold")
		and not missing_fallback.has("gold_delta"),
		"AC3: non-gold sibling still commits when snapshot omits gold")
	_assert_rejected(missing_service, "leave", missing_gold, 50, "AC3: replay after missing-gold fallback")
	_check(missing_gold == missing_original, "AC3: missing-gold checks leave caller snapshot untouched")

	# 4. Absent target hero on a hero-targeted gold choice:
	var two_hero_gold := _gold_snapshot(50, 30, [["warden", 95], ["tinker", 50]])
	var absent_hero_service := RunStitchedEventConsequence.new(_event([
		_choice("absent_scarecrow", "Pay the absent scarecrow.",
			_gold_effect(10, -15, -12, "hero", "scarecrow")),
		_choice("tend_wick", "Tend the guttering wick", _gold_effect(25, -5, -12)),
	]))
	var absent_entry := _entry(absent_hero_service.preview(two_hero_gold), "absent_scarecrow")
	_check(absent_entry.get("available") == false
		and absent_entry.get("gold_delta") == -12
		and absent_entry.get("gold") == 30
		and absent_entry.get("candle") == 50
		and absent_entry.get("fray") == {},
		"absent target hero makes a gold-bearing choice unavailable without projecting gold or fray")
	_assert_rejected(absent_hero_service, "absent_scarecrow", two_hero_gold, 50, "absent hero on gold choice")
	var absent_sibling := absent_hero_service.choose("tend_wick", two_hero_gold)
	_check(absent_sibling.get("ok") == true and absent_sibling.get("gold") == 18
		and absent_sibling.get("fray") == {"warden": -5, "tinker": -5},
		"legal sibling claims after absent-hero gold rejection")

	# 5. AC3: Overflow credit past MAX_INT (gold MAX_INT plus 1 and near-MAX_INT overflow):
	var max_gold_snap := _gold_four(50, 9223372036854775807, [95, 0, 50, 200])
	var max_plus_one_service := RunStitchedEventConsequence.new(_event([
		_choice("plus_one", "MAX_INT plus 1.", _gold_effect(10, 0, 1)),
		_choice("plus_twelve", "MAX_INT plus 12.", _gold_effect(-8, 0, 12)),
		_choice("zero_ok", "Exact MAX_INT.", _gold_effect(10, 0, 0)),
	]))
	var max_plus_one_preview := max_plus_one_service.preview(max_gold_snap)
	_check(_entry(max_plus_one_preview, "plus_one").get("available") == false
		and _entry(max_plus_one_preview, "plus_one").get("gold") == 9223372036854775807
		and _entry(max_plus_one_preview, "plus_twelve").get("available") == false
		and _entry(max_plus_one_preview, "zero_ok").get("available") == true,
		"AC3: gold MAX_INT plus 1 is unavailable and preserves old MAX_INT balance")
	_assert_rejected(max_plus_one_service, "plus_one", max_gold_snap, 50, "AC3: gold MAX_INT plus 1")
	_assert_rejected(max_plus_one_service, "plus_twelve", max_gold_snap, 50, "AC3: gold MAX_INT plus 12")
	var exact_max_receipt := max_plus_one_service.choose("zero_ok", max_gold_snap)
	_check(exact_max_receipt.get("ok") == true and exact_max_receipt.get("gold") == 9223372036854775807,
		"AC3: non-overflowing sibling still commits after MAX_INT+1 refusals")

	var near_max_snap := _gold_four(50, 9223372036854775800, [95, 0, 50, 200])
	var overflow_service := RunStitchedEventConsequence.new(_event([
		_choice("overflow_eight", "Overflow by 1.", _gold_effect(10, 0, 8)),
		_choice("overflow_max", "Overflow by MAX_INT.", _gold_effect(10, 0, 9223372036854775807)),
		_choice("safe_seven", "Exact MAX_INT.", _gold_effect(10, 0, 7)),
	]))
	_assert_rejected(overflow_service, "overflow_eight", near_max_snap, 50, "AC3: gold overflow +8")
	_assert_rejected(overflow_service, "overflow_max", near_max_snap, 50, "AC3: gold overflow +MAX_INT")
	var safe_seven_receipt := overflow_service.choose("safe_seven", near_max_snap)
	_check(safe_seven_receipt.get("ok") == true and safe_seven_receipt.get("gold") == 9223372036854775807,
		"AC3: exact MAX_INT gold credit commits after overflow refusals")

	# 6. AC3: Malformed fractional/string/bool/null/infinite/unsafe-float authored gold deltas
	#    and unknown added effect fields:
	var valid_gold_snap := _gold_snapshot(50, 30, [["warden", 40], ["seamstress", 60]])
	var broken_gold_choices: Array = [
		_choice("broken", "Fractional gold.", _gold_effect(25, -5, 1.5)),
		_choice("broken", "Negative fraction.", _gold_effect(25, -5, -12.5)),
		_choice("broken", "String gold.", _gold_effect(25, -5, "-12")),
		_choice("broken", "Bool true gold.", _gold_effect(25, -5, true)),
		_choice("broken", "Bool false gold.", _gold_effect(25, -5, false)),
		_choice("broken", "Null gold.", _gold_effect(25, -5, null)),
		_choice("broken", "Infinite gold.", _gold_effect(25, -5, INF)),
		_choice("broken", "Unsafe float gold.", _gold_effect(25, -5, 9007199254740992.0 * 2.0)),
		_choice("broken", "Array gold.", _gold_effect(25, -5, [-12])),
		_choice("broken", "Dict gold.", _gold_effect(25, -5, {"amount": -12})),
		{"id": "broken", "text": "Extra key with gold.", "stitched_effect": {
			"candle": 25, "fray": -5, "target": "party", "gold": -12, "extra": 1,
		}},
		{"id": "broken", "text": "Party target with hero_id and gold.", "stitched_effect": {
			"candle": 25, "fray": -5, "target": "party", "hero_id": "warden", "gold": -12,
		}},
		{"id": "broken", "text": "Hero target missing hero_id with gold.", "stitched_effect": {
			"candle": 25, "fray": -5, "target": "hero", "gold": 12,
		}},
		{"id": "broken", "text": "Hero target extra key with gold.", "stitched_effect": {
			"candle": 25, "fray": -5, "target": "hero", "hero_id": "warden", "gold": 12, "extra": 1,
		}},
		_choice("broken", "Unknown hero with gold.", _gold_effect(25, -5, 12, "hero", "porcelain_doll")),
	]
	for index in range(broken_gold_choices.size()):
		var broken_service := RunStitchedEventConsequence.new(_event([
			_choice("tend_wick", "Tend the guttering wick", _gold_effect(25, -5, -12)),
			broken_gold_choices[index],
		]))
		var broken_preview := broken_service.preview(valid_gold_snap)
		var broken_entry := _entry(broken_preview, "broken")
		_check(broken_entry.get("available") == false
			and broken_entry.get("candle_delta") == null
			and broken_entry.get("fray_delta") == null
			and broken_entry.get("gold_delta") == null
			and not broken_entry.has("gold")
			and not broken_entry.has("gold_delta"),
			"AC3: malformed gold effect %d is unavailable with null deltas and no gold keys" % index)
		_assert_rejected(broken_service, "broken", valid_gold_snap, 50,
			"AC3: malformed gold effect %d" % index)
		var sibling_receipt := broken_service.choose("tend_wick", valid_gold_snap)
		_check(sibling_receipt.get("ok") == true and sibling_receipt.get("gold") == 18,
			"AC3: malformed gold effect %d leaves legal sibling claimable" % index)
		_assert_rejected(broken_service, "tend_wick", valid_gold_snap, 50,
			"AC3: replay after malformed gold effect %d sibling claim" % index)

	# 7. AC3: Negative and non-native-int snapshot.gold values and unknown snapshot keys:
	var bad_gold_service := RunStitchedEventConsequence.new(_gold_bargain_event())
	var bad_gold_balances: Array = [-1, -12, -9223372036854775807, 1.5, 30.0, "30", true, false, null, [], {}]
	for index in range(bad_gold_balances.size()):
		var bad_snap := _gold_four(50, bad_gold_balances[index], [95, 0, 50, 200])
		_check(bad_gold_service.preview(bad_snap) == _denied_preview(),
			"AC3: invalid snapshot.gold %d denies preflight" % index)
		_assert_rejected(bad_gold_service, "tend_wick", bad_snap, 0,
			"AC3: invalid snapshot.gold %d commit" % index)
		var bad_combo_snap := _gold_scraps_four(50, 3, bad_gold_balances[index], [95, 0, 50, 200])
		_check(bad_gold_service.preview(bad_combo_snap) == _denied_preview(),
			"AC3: invalid snapshot.gold %d with scraps denies preflight" % index)
		_assert_rejected(bad_gold_service, "tend_wick", bad_combo_snap, 0,
			"AC3: invalid snapshot.gold %d with scraps commit" % index)
	var extra_gold_snap := _gold_scraps_satchel_four(50, 3, 30, 5, [95, 0, 50, 200])
	extra_gold_snap["extra"] = 1
	_check(bad_gold_service.preview(extra_gold_snap) == _denied_preview(),
		"AC3: snapshot with unknown extra key alongside gold/scraps/satchel_count denies preflight")
	_assert_rejected(bad_gold_service, "tend_wick", extra_gold_snap, 0,
		"AC3: snapshot with unknown extra key alongside gold/scraps/satchel_count commit")
	_check(not bad_gold_service.is_claimed(),
		"AC3: invalid snapshot.gold checks never latch the visit")
	var valid_gold_four := _gold_scraps_four(50, 3, 30, [95, 0, 50, 200])
	var recovered_gold := bad_gold_service.choose("tend_wick", valid_gold_four)
	_check(recovered_gold.get("ok") == true and recovered_gold.get("gold") == 18,
		"AC3: same instance still commits a legal gold choice after invalid-snapshot refusals")
	_assert_rejected(bad_gold_service, "leave", valid_gold_four, 50,
		"AC3: replay refused after recovered gold claim")

