extends SceneTree
## Scene-free checks for the S6-ready Stitched Event consequence helper.
## Every snapshot, outcome and receipt here is plain data: no scene nodes, no
## run state, no reserved S1b rules file and no live Event routing.

var failures: Array[String] = []
var checks: int = 0

const FOUR := ["warden", "seamstress", "tinker", "button_golem"]
const FOUR_WITH_MONK := ["warden", "seamstress", "tinker", "lantern_monk"]
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
	_test_required_hero_party_and_hero_gates()
	_test_required_hero_rejections()
	_test_hp_party_and_hero_intents()
	_test_hp_combined_and_legacy_shapes()
	_test_hp_rejections()
	_test_paid_wick_party_and_hero_bargains()
	_test_paid_wick_underfunded_and_bounds()
	_test_paid_wick_opt_in_and_rejections()
	_test_min_fray_gates()
	_test_candle_band_gates()
	_test_lost_heroes_ac1_party_recipients()
	_test_lost_heroes_ac2_hero_targeted_and_required_hero()
	_test_lost_heroes_ac3_min_fray_and_all_lost()
	_test_lost_heroes_ac4_schema_compatibility_and_invariants()
	_test_kid_fear_fray_observations_ac1()
	_test_kid_fear_fray_observations_ac2_party_wide_and_debt_parcel()
	_test_kid_fear_fray_observations_ac3_negative_and_invariants()
	_test_require_candle_room_shipped_bedwarmer()
	_test_require_candle_room_fixtures_and_lost_dolls()
	_test_require_candle_room_schema_and_rejections()
	_test_wren_fear_ac1_projections()
	_test_wren_fear_ac2_refusals_and_alternatives()
	_test_wren_fear_ac3_shapes_and_invariants()
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


func _fear_effect(candle: int, fray: int, fear: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {"candle": candle, "fray": fray, "target": target, "fear": fear}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _fear_snapshot(candle: int, wren_fear: Variant, hero_pairs: Array) -> Dictionary:
	var snapshot := _snapshot(candle, hero_pairs)
	snapshot["wren_fear"] = wren_fear
	return snapshot


func _fear_four(candle: int, wren_fear: Variant, frays: Array) -> Dictionary:
	var snapshot := _four(candle, frays)
	snapshot["wren_fear"] = wren_fear
	return snapshot


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
	for forbidden in ["stitched_rules.gd", "StitchedRules",
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


func _required_hero_effect(candle: int, fray: int, required_hero: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {
		"candle": candle,
		"fray": fray,
		"target": target,
		"required_hero": required_hero,
	}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _four_with_monk(candle: int, frays: Array) -> Dictionary:
	var pairs: Array = []
	for index in range(frays.size()):
		pairs.append([FOUR_WITH_MONK[index], frays[index]])
	return _snapshot(candle, pairs)


func _choice_ids(preview: Dictionary) -> Array:
	var ids: Array = []
	for entry in preview.get("choices", []):
		if entry is Dictionary:
			ids.append(entry.get("choice_id", ""))
	return ids


func _required_hero_bargain_event() -> Dictionary:
	return _event([
		_choice("monk_prayer", "The Lantern Monk chants over the party's seams.",
			_required_hero_effect(25, -25, "lantern_monk", "party")),
		_choice("tend", "Tend the seamstress's seam.",
			_effect(25, -25, "hero", "seamstress")),
		_choice("leave", "Leave the shrine untouched.",
			_effect(0, 0, "party")),
	], "ev_stitched_lantern_monk_shrine")


func _test_required_hero_party_and_hero_gates() -> void:
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var catalog_original := warden_catalog.duplicate(true)
	_check(bool(warden_catalog.get("ok", false)),
		"required_hero fixture loads Warden part catalog")

	# AC1: Two valid four-hero fixtures (one without Lantern Monk, one with Lantern Monk),
	# a gated party effect (required_hero="lantern_monk", +25 candle / -25 fray),
	# an ordinary hero-targeted effect (seamstress) and an ungated Leave.
	var without_monk := _four(40, [95, 0, 50, 200])
	var without_monk_original := without_monk.duplicate(true)
	var with_monk := _four_with_monk(40, [95, 0, 50, 200])
	var with_monk_original := with_monk.duplicate(true)
	var event_record := _required_hero_bargain_event()
	var event_original := event_record.duplicate(true)

	var service_absent := RunStitchedEventConsequence.new(event_record)
	var preview_absent := service_absent.preview(without_monk)
	_check(preview_absent.get("ok") == true
		and preview_absent.get("event_id") == "ev_stitched_lantern_monk_shrine"
		and preview_absent.get("candle") == 40,
		"AC1: preflight succeeds at candle 40 without Lantern Monk")
	_check(_choice_ids(preview_absent) == ["tend", "leave"],
		"AC1: absent required_hero excludes the gated choice from preview.choices and preserves visible choice order")
	_check(_entry(preview_absent, "monk_prayer") == {},
		"AC1: hidden gated choice is omitted from preview.choices rather than shown disabled")

	var absent_tend_entry := _entry(preview_absent, "tend")
	_check(absent_tend_entry.get("available") == true
		and absent_tend_entry.get("target") == "hero"
		and absent_tend_entry.get("hero_id") == "seamstress"
		and absent_tend_entry.get("candle_delta") == 25
		and absent_tend_entry.get("fray_delta") == -25
		and absent_tend_entry.get("candle") == 65
		and absent_tend_entry.get("fray") == {"seamstress": -25}
		and _receipt_keys(absent_tend_entry) == [
			"available", "candle", "candle_delta", "choice_id",
			"fray", "fray_delta", "hero_id", "target",
		],
		"AC1/AC3: ordinary hero-targeted sibling retains exact 8-key preview shape when gated choice is hidden")

	var absent_leave_entry := _entry(preview_absent, "leave")
	_check(absent_leave_entry.get("available") == true
		and absent_leave_entry.get("target") == "party"
		and absent_leave_entry.get("hero_id") == ""
		and absent_leave_entry.get("candle") == 40
		and absent_leave_entry.get("fray") == {}
		and _receipt_keys(absent_leave_entry) == [
			"available", "candle", "candle_delta", "choice_id",
			"fray", "fray_delta", "hero_id", "target",
		],
		"AC1/AC3: ungated Leave remains available with exact 8-key preview shape when gated choice is hidden")

	# AC1: With [warden, seamstress, tinker, lantern_monk], the gated choice appears in authored order,
	# previews candle 65 and -25 fray for all four party members.
	var service_present := RunStitchedEventConsequence.new(event_record)
	var preview_present := service_present.preview(with_monk)
	_check(preview_present.get("ok") == true
		and preview_present.get("event_id") == "ev_stitched_lantern_monk_shrine"
		and preview_present.get("candle") == 40,
		"AC1: preflight succeeds at candle 40 with Lantern Monk present")
	_check(_choice_ids(preview_present) == ["monk_prayer", "tend", "leave"],
		"AC1: present required_hero keeps all three choices in exact authored order")

	var monk_entry := _entry(preview_present, "monk_prayer")
	_check(monk_entry.get("available") == true
		and monk_entry.get("target") == "party"
		and monk_entry.get("hero_id") == ""
		and monk_entry.get("candle_delta") == 25
		and monk_entry.get("fray_delta") == -25
		and monk_entry.get("candle") == 65
		and monk_entry.get("fray") == {
			"warden": -25,
			"seamstress": -25,
			"tinker": -25,
			"lantern_monk": -25,
		}
		and _receipt_keys(monk_entry) == [
			"available", "candle", "candle_delta", "choice_id",
			"fray", "fray_delta", "hero_id", "target",
		],
		"AC1: party-targeted Lantern-Monk-required choice previews candle 65 and -25 fray for all four active heroes")

	# Relative order preservation when the gated choice is authored in middle or last slot, and on a 2-choice event:
	var middle_gated_event := _event([
		_choice("tend", "Tend seamstress.", _effect(25, -25, "hero", "seamstress")),
		_choice("monk_prayer", "Monk prayer.", _required_hero_effect(25, -25, "lantern_monk", "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	_check(_choice_ids(RunStitchedEventConsequence.new(middle_gated_event).preview(without_monk)) == ["tend", "leave"]
		and _choice_ids(RunStitchedEventConsequence.new(middle_gated_event).preview(with_monk)) == ["tend", "monk_prayer", "leave"],
		"AC1: middle-slot gated choice preserves relative order of visible choices")

	var last_gated_event := _event([
		_choice("tend", "Tend seamstress.", _effect(25, -25, "hero", "seamstress")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
		_choice("monk_prayer", "Monk prayer.", _required_hero_effect(25, -25, "lantern_monk", "party")),
	])
	_check(_choice_ids(RunStitchedEventConsequence.new(last_gated_event).preview(without_monk)) == ["tend", "leave"]
		and _choice_ids(RunStitchedEventConsequence.new(last_gated_event).preview(with_monk)) == ["tend", "leave", "monk_prayer"],
		"AC1: last-slot gated choice preserves relative order of visible choices")

	var two_choice_gated_event := _event([
		_choice("monk_prayer", "Monk prayer.", _required_hero_effect(25, -25, "lantern_monk", "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	var two_absent_preview := RunStitchedEventConsequence.new(two_choice_gated_event).preview(without_monk)
	var two_present_preview := RunStitchedEventConsequence.new(two_choice_gated_event).preview(with_monk)
	_check(_choice_ids(two_absent_preview) == ["leave"]
		and _choice_ids(two_present_preview) == ["monk_prayer", "leave"],
		"AC1: two-choice event with gated choice filters to [leave] when absent and [monk_prayer, leave] when present")

	# AC1: Candle clamp to 0..100 on gated party choice:
	var high_candle_monk := _four_with_monk(90, [95, 0, 50, 200])
	var clamp_service := RunStitchedEventConsequence.new(event_record)
	var clamp_preview := clamp_service.preview(high_candle_monk)
	_check(_entry(clamp_preview, "monk_prayer").get("candle") == 100
		and _entry(clamp_preview, "monk_prayer").get("fray") == {
			"warden": -25, "seamstress": -25, "tinker": -25, "lantern_monk": -25,
		},
		"AC1: gated party choice clamps candle 90 + 25 to 100 in preview")
	var clamp_receipt := clamp_service.choose("monk_prayer", high_candle_monk)
	_check(clamp_receipt.get("ok") == true and clamp_receipt.get("candle") == 100,
		"AC1/AC2: gated party choice clamps candle 90 + 25 to 100 in choose()")

	var low_candle_monk := _four_with_monk(10, [95, 0, 50, 200])
	var low_clamp_service := RunStitchedEventConsequence.new(_event([
		_choice("monk_dim", "Dim the lantern.", _required_hero_effect(-25, -10, "lantern_monk", "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	]))
	_check(_entry(low_clamp_service.preview(low_candle_monk), "monk_dim").get("candle") == 0,
		"AC1: gated party choice clamps candle 10 - 25 to 0 in preview")
	_check(low_clamp_service.choose("monk_dim", low_candle_monk).get("candle") == 0,
		"AC1/AC2: gated party choice clamps candle 10 - 25 to 0 in choose()")

	# AC2: Choosing the hidden choice when required_hero is missing fails without consuming the visit,
	# snapshot, catalog, or RNG; a subsequent Leave or other eligible choice still claims once; replay fails.
	seed(20261110)
	var expected_rng_absent := randi()
	seed(20261110)

	_assert_rejected(service_absent, "monk_prayer", without_monk, 40,
		"AC2: hidden choice rejected when required_hero is absent")
	_check(not service_absent.is_claimed() and service_absent.is_valid(),
		"AC2: rejecting hidden choice does not latch or consume the visit")
	var leave_after_hidden := service_absent.choose("leave", without_monk)
	_check(leave_after_hidden.get("ok") == true
		and leave_after_hidden.get("event_id") == "ev_stitched_lantern_monk_shrine"
		and leave_after_hidden.get("choice_id") == "leave"
		and leave_after_hidden.get("target") == "party"
		and leave_after_hidden.get("hero_id") == ""
		and leave_after_hidden.get("candle") == 40
		and leave_after_hidden.get("fray") == {}
		and _receipt_keys(leave_after_hidden) == [
			"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
		],
		"AC2: subsequent Leave claims once after hidden choice rejection")
	_check(service_absent.is_claimed() and not service_absent.is_valid(),
		"AC2: subsequent Leave latches the visit")
	_assert_rejected(service_absent, "leave", without_monk, 40,
		"AC2: replay after Leave is denied")
	_assert_rejected(service_absent, "tend", without_monk, 40,
		"AC2: sibling choice after Leave claim is denied")
	_check(randi() == expected_rng_absent,
		"AC2: hidden choice refusal, Leave claim and replay never advance global RNG")

	# Also verify another eligible non-Leave choice ("tend") claims once after hidden choice rejection:
	var service_absent_tend := RunStitchedEventConsequence.new(event_record)
	_assert_rejected(service_absent_tend, "monk_prayer", without_monk, 40,
		"AC2: hidden choice rejected before ordinary hero choice")
	var tend_after_hidden := service_absent_tend.choose("tend", without_monk)
	_check(tend_after_hidden.get("ok") == true
		and tend_after_hidden.get("choice_id") == "tend"
		and tend_after_hidden.get("target") == "hero"
		and tend_after_hidden.get("hero_id") == "seamstress"
		and tend_after_hidden.get("candle") == 65
		and tend_after_hidden.get("fray") == {"seamstress": -25},
		"AC2: other eligible choice claims once after hidden choice rejection")
	_assert_rejected(service_absent_tend, "tend", without_monk, 40,
		"AC2: replay after eligible sibling claim is denied")

	# AC2: Given the required hero present, choosing the gated choice succeeds and a repeated claim fails.
	seed(20261111)
	var expected_rng_present := randi()
	seed(20261111)

	var monk_receipt := service_present.choose("monk_prayer", with_monk)
	_check(monk_receipt.get("ok") == true
		and monk_receipt.get("event_id") == "ev_stitched_lantern_monk_shrine"
		and monk_receipt.get("choice_id") == "monk_prayer"
		and monk_receipt.get("target") == "party"
		and monk_receipt.get("hero_id") == ""
		and monk_receipt.get("candle") == 65
		and monk_receipt.get("fray") == {
			"warden": -25,
			"seamstress": -25,
			"tinker": -25,
			"lantern_monk": -25,
		}
		and _receipt_keys(monk_receipt) == [
			"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
		],
		"AC2: gated party choice returns exact previewed candle/fray and 7-key receipt shape")
	_check(service_present.is_claimed() and not service_present.is_valid(),
		"AC2: claiming gated choice consumes the single visit")
	_assert_rejected(service_present, "monk_prayer", with_monk, 40,
		"AC2: repeated claim of gated choice fails")
	_assert_rejected(service_present, "leave", with_monk, 40,
		"AC2: Leave after gated choice claim fails")
	_check(service_present.preview(with_monk) == _denied_preview(),
		"AC2: claimed gated visit denies preflight")
	_check(randi() == expected_rng_present,
		"AC2: gated choice claim and replay never advance global RNG")
	_check(without_monk == without_monk_original
		and with_monk == with_monk_original
		and event_record == event_original,
		"AC1/AC2: caller snapshots and authored event record remain untouched")

	# AC2: Gated choice with optional gold, scraps and part receipt fields:
	var gated_full_effect := {
		"candle": 25,
		"fray": -25,
		"target": "party",
		"required_hero": "lantern_monk",
		"scraps": -2,
		"gold": -12,
		"part": {"id": "warden_head_pot_helm_bonk", "tier": 2},
	}
	var gated_bargain_event := _event([
		_choice("monk_relic", "The Lantern Monk consecrates the pot helm.", gated_full_effect),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_monk_relic")
	var full_without_monk := _gold_scraps_satchel_four(40, 4, 30, 5, [95, 0, 50, 200])
	var full_with_monk := _four_with_monk(40, [95, 0, 50, 200])
	full_with_monk["scraps"] = 4
	full_with_monk["gold"] = 30
	full_with_monk["satchel_count"] = 5
	var full_with_monk_original := full_with_monk.duplicate(true)

	var relic_absent_service := RunStitchedEventConsequence.new(gated_bargain_event, warden_catalog)
	var relic_absent_preview := relic_absent_service.preview(full_without_monk)
	_check(_choice_ids(relic_absent_preview) == ["leave"]
		and _entry(relic_absent_preview, "monk_relic") == {},
		"AC1/AC2: gated choice with gold/scraps/part is hidden when required_hero is absent")
	var result_relic_absent := relic_absent_service.choose("monk_relic", full_without_monk)
	_check(result_relic_absent == _refusal(40) and not relic_absent_service.is_claimed(),
		"AC2: hidden gated gold/scraps/part choice fails without consuming visit")
	_check(relic_absent_service.choose("leave", full_without_monk).get("ok") == true,
		"AC2: Leave claims after hidden gated gold/scraps/part choice refusal")

	var relic_present_service := RunStitchedEventConsequence.new(gated_bargain_event, warden_catalog)
	var relic_present_preview := relic_present_service.preview(full_with_monk)
	var relic_entry := _entry(relic_present_preview, "monk_relic")
	_check(relic_entry.get("available") == true
		and relic_entry.get("candle") == 65
		and relic_entry.get("scraps_delta") == -2
		and relic_entry.get("scraps") == 2
		and relic_entry.get("gold_delta") == -12
		and relic_entry.get("gold") == 18
		and relic_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and relic_entry.get("satchel_count") == 6
		and relic_entry.get("fray") == {
			"warden": -25, "seamstress": -25, "tinker": -25, "lantern_monk": -25,
		},
		"AC2: gated choice with gold/scraps/part previews all optional receipt fields")
	var relic_receipt := relic_present_service.choose("monk_relic", full_with_monk)
	_check(relic_receipt.get("ok") == true
		and relic_receipt.get("candle") == 65
		and relic_receipt.get("scraps_delta") == -2
		and relic_receipt.get("scraps") == 2
		and relic_receipt.get("gold_delta") == -12
		and relic_receipt.get("gold") == 18
		and relic_receipt.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and relic_receipt.get("satchel_count") == 6
		and relic_receipt.get("fray") == {
			"warden": -25, "seamstress": -25, "tinker": -25, "lantern_monk": -25,
		},
		"AC2: gated choice with gold/scraps/part returns exact receipt fields")
	_assert_rejected(relic_present_service, "monk_relic", full_with_monk, 40,
		"AC2: repeated claim on gated gold/scraps/part choice fails")
	_check(full_with_monk == full_with_monk_original and warden_catalog == catalog_original,
		"AC2: gated gold/scraps/part choice preserves snapshot and catalog detachment")

	# Exercise a required_hero different from a target="hero" hero_id, requiring BOTH to be present:
	var cross_hero_event := _event([
		_choice("monk_mends_seamstress", "The Lantern Monk steadies the Seamstress's needle.",
			_required_hero_effect(20, -15, "lantern_monk", "hero", "seamstress")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_cross_hero_gate")

	# 1) Both required_hero ("lantern_monk") and target hero_id ("seamstress") present:
	var both_present_service := RunStitchedEventConsequence.new(cross_hero_event)
	var both_present_preview := both_present_service.preview(with_monk)
	_check(_choice_ids(both_present_preview) == ["monk_mends_seamstress", "leave"],
		"target=hero with distinct required_hero appears when both heroes are in the party")
	var cross_entry := _entry(both_present_preview, "monk_mends_seamstress")
	_check(cross_entry.get("available") == true
		and cross_entry.get("target") == "hero"
		and cross_entry.get("hero_id") == "seamstress"
		and cross_entry.get("candle") == 60
		and cross_entry.get("fray") == {"seamstress": -15},
		"target=hero with distinct required_hero directs fray intent solely to hero_id")
	var cross_receipt := both_present_service.choose("monk_mends_seamstress", with_monk)
	_check(cross_receipt.get("ok") == true
		and cross_receipt.get("target") == "hero"
		and cross_receipt.get("hero_id") == "seamstress"
		and cross_receipt.get("candle") == 60
		and cross_receipt.get("fray") == {"seamstress": -15},
		"target=hero with distinct required_hero commits with sole hero_id fray intent")
	_assert_rejected(both_present_service, "monk_mends_seamstress", with_monk, 40,
		"replay of distinct required_hero + hero_id choice fails")

	# 2) hero_id ("seamstress") present, required_hero ("lantern_monk") absent:
	var req_missing_service := RunStitchedEventConsequence.new(cross_hero_event)
	var req_missing_preview := req_missing_service.preview(without_monk)
	_check(_choice_ids(req_missing_preview) == ["leave"]
		and _entry(req_missing_preview, "monk_mends_seamstress") == {},
		"target=hero choice is hidden when required_hero is absent even if hero_id is present")
	_assert_rejected(req_missing_service, "monk_mends_seamstress", without_monk, 40,
		"target=hero choice rejected when required_hero is absent")
	_check(req_missing_service.choose("leave", without_monk).get("ok") == true,
		"Leave claims after absent required_hero rejection on target=hero choice")

	# 3) required_hero ("lantern_monk") present, hero_id ("seamstress") absent:
	var target_missing_snap := _snapshot(40, [
		["warden", 95], ["rag_duelist", 0], ["tinker", 50], ["lantern_monk", 200],
	])
	var target_missing_service := RunStitchedEventConsequence.new(cross_hero_event)
	var target_missing_preview := target_missing_service.preview(target_missing_snap)
	var target_missing_entry := _entry(target_missing_preview, "monk_mends_seamstress")
	_check(target_missing_entry.get("available") == false
		and target_missing_entry.get("candle") == 40
		and target_missing_entry.get("fray") == {},
		"target=hero choice with present required_hero but absent hero_id is unavailable and projects no change")
	_assert_rejected(target_missing_service, "monk_mends_seamstress", target_missing_snap, 40,
		"target=hero choice rejected when hero_id is absent even though required_hero is present")
	_check(target_missing_service.choose("leave", target_missing_snap).get("ok") == true,
		"Leave claims after absent hero_id rejection on gated target=hero choice")

	# Canonical eight-ID coverage for required_hero:
	for hero_id in REQUIRED_IDS:
		var canonical_event := _event([
			_choice("gated", "Hero gate.", _required_hero_effect(15, -10, hero_id, "party")),
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		])
		var other_id := "warden" if hero_id != "warden" else "seamstress"
		var present_snap := _snapshot(50, [[hero_id, 80], [other_id, 60]])
		var absent_snap := _snapshot(50, [[other_id, 60]])
		var present_svc := RunStitchedEventConsequence.new(canonical_event)
		var absent_svc := RunStitchedEventConsequence.new(canonical_event)
		_check(_choice_ids(present_svc.preview(present_snap)) == ["gated", "leave"]
			and present_svc.choose("gated", present_snap).get("fray") == {hero_id: -10, other_id: -10},
			"canonical required_hero %s admits and commits party fray when present" % hero_id)
		_check(_choice_ids(absent_svc.preview(absent_snap)) == ["leave"]
			and absent_svc.choose("gated", absent_snap).get("ok") == false
			and absent_svc.choose("leave", absent_snap).get("ok") == true,
			"canonical required_hero %s hides and rejects gated choice when absent" % hero_id)


func _test_required_hero_rejections() -> void:
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var with_monk := _four_with_monk(40, [95, 0, 50, 200])
	var without_monk := _four(40, [95, 0, 50, 200])

	# 1. Unaffordable optional costs (scraps, gold) and full satchel (6) on a choice with a present required_hero:
	var gated_cost_event := _event([
		_choice("monk_scraps", "Spend 2 scraps with the Monk.", {
			"candle": 20, "fray": -20, "target": "party", "required_hero": "lantern_monk", "scraps": -2,
		}),
		_choice("monk_gold", "Spend 12 gold with the Monk.", {
			"candle": 20, "fray": -20, "target": "party", "required_hero": "lantern_monk", "gold": -12,
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	var low_purses_monk := _four_with_monk(40, [95, 0, 50, 200])
	low_purses_monk["scraps"] = 1
	low_purses_monk["gold"] = 5
	var cost_service := RunStitchedEventConsequence.new(gated_cost_event)
	var cost_preview := cost_service.preview(low_purses_monk)
	_check(_choice_ids(cost_preview) == ["monk_scraps", "monk_gold", "leave"],
		"present required_hero choices remain visible in preview when optional costs are unaffordable")
	_check(_entry(cost_preview, "monk_scraps").get("available") == false
		and _entry(cost_preview, "monk_scraps").get("scraps") == 1
		and _entry(cost_preview, "monk_scraps").get("candle") == 40
		and _entry(cost_preview, "monk_scraps").get("fray") == {}
		and _entry(cost_preview, "monk_gold").get("available") == false
		and _entry(cost_preview, "monk_gold").get("gold") == 5
		and _entry(cost_preview, "monk_gold").get("candle") == 40
		and _entry(cost_preview, "monk_gold").get("fray") == {},
		"unaffordable gated scraps/gold choices report available=false and unprojected balances")
	_assert_rejected(cost_service, "monk_scraps", low_purses_monk, 40,
		"unaffordable scraps on gated choice")
	_assert_rejected(cost_service, "monk_gold", low_purses_monk, 40,
		"unaffordable gold on gated choice")
	_check(cost_service.choose("leave", low_purses_monk).get("ok") == true,
		"Leave still claims after unaffordable gated cost rejections")

	var gated_part_event := _event([
		_choice("monk_helm", "Receive the helm from the Monk.", {
			"candle": 10, "fray": -10, "target": "party", "required_hero": "lantern_monk",
			"part": {"id": "warden_head_pot_helm_bonk", "tier": 2},
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	var full_satchel_monk := _four_with_monk(40, [95, 0, 50, 200])
	full_satchel_monk["satchel_count"] = 6
	var full_satchel_service := RunStitchedEventConsequence.new(gated_part_event, warden_catalog)
	var full_satchel_preview := full_satchel_service.preview(full_satchel_monk)
	_check(_choice_ids(full_satchel_preview) == ["monk_helm", "leave"]
		and _entry(full_satchel_preview, "monk_helm").get("available") == false
		and _entry(full_satchel_preview, "monk_helm").get("satchel_count") == 6
		and _entry(full_satchel_preview, "monk_helm").get("candle") == 40
		and _entry(full_satchel_preview, "monk_helm").get("fray") == {},
		"gated part choice at full satchel_count=6 is visible with available=false and count 6")
	_assert_rejected(full_satchel_service, "monk_helm", full_satchel_monk, 40,
		"full satchel on gated part choice")
	_check(full_satchel_service.choose("leave", full_satchel_monk).get("ok") == true,
		"Leave still claims after full-satchel gated part rejection")

	# 2. AC3: Unknown hero names, empty strings, padded strings, wrong case, and non-string required_hero
	#    are malformed outcomes (NOT permissive absences!) for both target="party" and target="hero".
	var invalid_gates: Array = [
		"",
		" ",
		"   ",
		"porcelain_doll",
		"clockwork_hound",
		"Lantern_Monk",
		"LANTERN_MONK",
		" lantern_monk",
		"lantern_monk ",
		42,
		0,
		1.5,
		true,
		false,
		null,
		["lantern_monk"],
		{"id": "lantern_monk"},
	]
	for index in range(invalid_gates.size()):
		var bad_gate: Variant = invalid_gates[index]
		for target_mode in ["party", "hero"]:
			var broken_choice := _choice(
				"broken",
				"Invalid required_hero.",
				_required_hero_effect(25, -25, bad_gate, target_mode, "seamstress")
			)
			for snap in [with_monk, without_monk]:
				var svc := RunStitchedEventConsequence.new(_event([
					broken_choice,
					_choice("leave", "Leave.", _effect(0, 0, "party")),
				]))
				var prev := svc.preview(snap)
				_check(prev.get("ok") == true,
					"AC3: invalid required_hero %d (%s) keeps readable event preflight" % [index, target_mode])
				_check(_choice_ids(prev) == ["broken", "leave"],
					"AC3: invalid required_hero %d (%s) is a malformed outcome kept in preview, not a hidden gate" % [index, target_mode])
				var broken_entry := _entry(prev, "broken")
				_check(broken_entry.get("available") == false
					and broken_entry.get("candle_delta") == null
					and broken_entry.get("fray_delta") == null
					and broken_entry.get("candle") == 40
					and broken_entry.get("fray") == {},
					"AC3: invalid required_hero %d (%s) reports available=false and null deltas" % [index, target_mode])
				_assert_rejected(svc, "broken", snap, 40,
					"AC3: invalid required_hero %d (%s) commit" % [index, target_mode])
				var fallback := svc.choose("leave", snap)
				_check(fallback.get("ok") == true and fallback.get("candle") == 40,
					"AC3: legal sibling still claims after invalid required_hero %d (%s)" % [index, target_mode])
				_assert_rejected(svc, "leave", snap, 40,
					"AC3: replay after invalid required_hero %d (%s) sibling claim" % [index, target_mode])

	# Extra malformed combinations with required_hero (party with hero_id, hero without hero_id, extra key):
	var extra_broken_choices: Array = [
		{"id": "broken", "text": "Party with hero_id and required_hero.", "stitched_effect": {
			"candle": 25, "fray": -25, "target": "party",
			"hero_id": "seamstress", "required_hero": "lantern_monk",
		}},
		{"id": "broken", "text": "Hero without hero_id but with required_hero.", "stitched_effect": {
			"candle": 25, "fray": -25, "target": "hero",
			"required_hero": "lantern_monk",
		}},
		{"id": "broken", "text": "Extra unknown key alongside required_hero.", "stitched_effect": {
			"candle": 25, "fray": -25, "target": "party",
			"required_hero": "lantern_monk", "extra": 1,
		}},
	]
	for index in range(extra_broken_choices.size()):
		var svc := RunStitchedEventConsequence.new(_event([
			extra_broken_choices[index],
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		]))
		var prev := svc.preview(without_monk)
		var broken_entry := _entry(prev, "broken")
		_check(_choice_ids(prev) == ["broken", "leave"]
			and broken_entry.get("available") == false
			and broken_entry.get("candle_delta") == null
			and broken_entry.get("fray_delta") == null,
			"AC3: malformed structural required_hero choice %d is shown malformed, not hidden" % index)
		_assert_rejected(svc, "broken", without_monk, 40,
			"AC3: malformed structural required_hero choice %d commit" % index)
		_check(svc.choose("leave", without_monk).get("ok") == true,
			"AC3: Leave claims after malformed structural required_hero choice %d" % index)


func _hp_effect(candle: int, fray: int, hp: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {"candle": candle, "fray": fray, "target": target, "hp": hp}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _hp_required_hero_effect(candle: int, fray: int, hp: Variant, required_hero: Variant,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {
		"candle": candle,
		"fray": fray,
		"target": target,
		"hp": hp,
		"required_hero": required_hero,
	}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _hp_party_bargain_event() -> Dictionary:
	return _event([
		_choice("mend_flesh", "Stitch the party's torn felt.", _hp_effect(15, -20, 6, "party")),
		_choice("bleed_thread", "Draw taut thread through every seam.", _hp_effect(25, 10, -4, "party")),
		_choice("steady_pulse", "Hold the needle still.", _hp_effect(0, 0, 0, "party")),
	], "ev_stitched_hp_party_bargain")


func _test_hp_party_and_hero_intents() -> void:
	# AC1: Three-choice and two-choice Events with optional signed stitched_effect.hp (+6, -4, 0),
	# four-hero snapshots in differing party orders, exact hp_delta and hp intent maps,
	# and independent candle (clamped 0..100) and fray (raw signed intents) projections.
	var party_orders: Array = [
		["warden", "seamstress", "tinker", "button_golem"],
		["button_golem", "tinker", "seamstress", "warden"],
		["seamstress", "button_golem", "warden", "tinker"],
		["lantern_monk", "rag_duelist", "scarecrow", "yarn_ranger"],
		["yarn_ranger", "scarecrow", "rag_duelist", "lantern_monk"],
	]
	var expected_hp_preview_keys := [
		"available", "candle", "candle_delta", "choice_id",
		"fray", "fray_delta", "hero_id", "hp", "hp_delta", "target",
	]
	var expected_hp_receipt_keys := [
		"candle", "choice_id", "event_id", "fray",
		"hero_id", "hp", "hp_delta", "ok", "target",
	]

	for order_idx in range(party_orders.size()):
		var order: Array = party_orders[order_idx]
		var snap := _snapshot(40, [
			[order[0], 95],
			[order[1], 0],
			[order[2], 50],
			[order[3], 200],
		])
		var snap_original := snap.duplicate(true)
		var expected_plus_six := {
			order[0]: 6,
			order[1]: 6,
			order[2]: 6,
			order[3]: 6,
		}
		var expected_minus_four := {
			order[0]: -4,
			order[1]: -4,
			order[2]: -4,
			order[3]: -4,
		}
		var expected_fray_mend := {
			order[0]: -20,
			order[1]: -20,
			order[2]: -20,
			order[3]: -20,
		}
		var expected_fray_bleed := {
			order[0]: 10,
			order[1]: 10,
			order[2]: 10,
			order[3]: 10,
		}
		if order_idx < 3:
			_check(expected_plus_six == {
				"warden": 6, "seamstress": 6, "tinker": 6, "button_golem": 6,
			} and expected_minus_four == {
				"warden": -4, "seamstress": -4, "tinker": -4, "button_golem": -4,
			}, "AC1: four-hero order %d matches exact {warden,seamstress,tinker,button_golem} map" % order_idx)

		var svc := RunStitchedEventConsequence.new(_hp_party_bargain_event())
		var prev := svc.preview(snap)
		_check(prev.get("ok") == true
			and prev.get("event_id") == "ev_stitched_hp_party_bargain"
			and prev.get("candle") == 40
			and prev.get("choices", []).size() == 3,
			"AC1: 3-choice party HP event preflights for party order %d" % order_idx)

		var mend_entry := _entry(prev, "mend_flesh")
		_check(mend_entry.get("available") == true
			and mend_entry.get("target") == "party"
			and mend_entry.get("hero_id") == ""
			and mend_entry.get("candle_delta") == 15
			and mend_entry.get("fray_delta") == -20
			and mend_entry.get("hp_delta") == 6
			and mend_entry.get("candle") == 55
			and mend_entry.get("fray") == expected_fray_mend
			and mend_entry.get("hp") == expected_plus_six
			and (mend_entry.get("hp") as Dictionary).size() == 4
			and _receipt_keys(mend_entry) == expected_hp_preview_keys,
			"AC1: +6 party HP preview returns exact 10-key entry and +6 on all four heroes (order %d)" % order_idx)

		var bleed_entry := _entry(prev, "bleed_thread")
		_check(bleed_entry.get("available") == true
			and bleed_entry.get("target") == "party"
			and bleed_entry.get("hero_id") == ""
			and bleed_entry.get("candle_delta") == 25
			and bleed_entry.get("fray_delta") == 10
			and bleed_entry.get("hp_delta") == -4
			and bleed_entry.get("candle") == 65
			and bleed_entry.get("fray") == expected_fray_bleed
			and bleed_entry.get("hp") == expected_minus_four
			and (bleed_entry.get("hp") as Dictionary).size() == 4
			and _receipt_keys(bleed_entry) == expected_hp_preview_keys,
			"AC1: -4 party HP preview returns exact 10-key entry and -4 on all four heroes (order %d)" % order_idx)

		var zero_entry := _entry(prev, "steady_pulse")
		_check(zero_entry.get("available") == true
			and zero_entry.get("target") == "party"
			and zero_entry.get("hero_id") == ""
			and zero_entry.get("candle_delta") == 0
			and zero_entry.get("fray_delta") == 0
			and zero_entry.get("hp_delta") == 0
			and zero_entry.get("candle") == 40
			and zero_entry.get("fray") == {}
			and zero_entry.get("hp") == {}
			and _receipt_keys(zero_entry) == expected_hp_preview_keys,
			"AC1: 0 party HP preview returns exact 10-key entry with hp_delta 0 and empty hp map (order %d)" % order_idx)

		for choice_id in ["mend_flesh", "bleed_thread", "steady_pulse"]:
			var visit := RunStitchedEventConsequence.new(_hp_party_bargain_event())
			var expected_entry := _entry(visit.preview(snap), choice_id)
			var receipt := visit.choose(choice_id, snap)
			_check(receipt.get("ok") == true
				and receipt.get("event_id") == "ev_stitched_hp_party_bargain"
				and receipt.get("choice_id") == choice_id
				and receipt.get("target") == expected_entry.get("target")
				and receipt.get("hero_id") == expected_entry.get("hero_id")
				and receipt.get("candle") == expected_entry.get("candle")
				and receipt.get("fray") == expected_entry.get("fray")
				and receipt.get("hp_delta") == expected_entry.get("hp_delta")
				and receipt.get("hp") == expected_entry.get("hp")
				and _receipt_keys(receipt) == expected_hp_receipt_keys,
				"AC1: party HP choice %s receipt has exact parity and 9-key shape (order %d)" % [choice_id, order_idx])
			_check(visit.is_claimed() and not visit.is_valid(),
				"AC1: party HP choice %s latches the visit (order %d)" % [choice_id, order_idx])
			_assert_rejected(visit, choice_id, snap, 40,
				"AC1: replay of %s rejected (order %d)" % [choice_id, order_idx])
			_check(snap == snap_original,
				"AC1: party HP choice %s leaves caller snapshot untouched (order %d)" % [choice_id, order_idx])

	# AC1: Two-choice Event with JSON-parsed integral float hp (+6.0, -4.0) and candle clamping (0..100):
	var two_choice_hp_json: Dictionary = JSON.parse_string(JSON.stringify(_event([
		_choice("heal_clamp_up", "Warm the seams.", _hp_effect(80, -30, 6, "party")),
		_choice("harm_clamp_down", "Snuff the wick.", _hp_effect(-60, 15, -4, "party")),
	], "ev_stitched_hp_two_choice")))
	var clamp_snap := _four(40, [95, 0, 50, 200])
	var two_svc_a := RunStitchedEventConsequence.new(two_choice_hp_json)
	var two_prev := two_svc_a.preview(clamp_snap)
	_check(_entry(two_prev, "heal_clamp_up").get("candle") == 100
		and _entry(two_prev, "heal_clamp_up").get("hp_delta") == 6
		and _entry(two_prev, "heal_clamp_up").get("hp") == {
			"warden": 6, "seamstress": 6, "tinker": 6, "button_golem": 6,
		}
		and _entry(two_prev, "harm_clamp_down").get("candle") == 0
		and _entry(two_prev, "harm_clamp_down").get("hp_delta") == -4
		and _entry(two_prev, "harm_clamp_down").get("hp") == {
			"warden": -4, "seamstress": -4, "tinker": -4, "button_golem": -4,
		},
		"AC1: 2-choice JSON-parsed party HP Event clamps candle 0..100 and projects +6/-4 intents")
	var two_rec_a := two_svc_a.choose("heal_clamp_up", clamp_snap)
	var two_rec_b := RunStitchedEventConsequence.new(two_choice_hp_json).choose("harm_clamp_down", clamp_snap)
	_check(two_rec_a.get("ok") == true and two_rec_a.get("candle") == 100
		and two_rec_a.get("hp_delta") == 6
		and two_rec_a.get("hp") == {"warden": 6, "seamstress": 6, "tinker": 6, "button_golem": 6}
		and two_rec_b.get("ok") == true and two_rec_b.get("candle") == 0
		and two_rec_b.get("hp_delta") == -4
		and two_rec_b.get("hp") == {"warden": -4, "seamstress": -4, "tinker": -4, "button_golem": -4},
		"AC1: 2-choice JSON-parsed party HP Event commits with exact preview parity")

	# AC2: Hero-targeted HP choices across all 8 canonical hero IDs (present vs absent, +6, -4, 0,
	# exact preview/receipt key checks, and retry of another legal choice on the same visit).
	for hero_idx in range(REQUIRED_IDS.size()):
		var hero_id: String = REQUIRED_IDS[hero_idx]
		var alt_a: String = REQUIRED_IDS[(hero_idx + 1) % REQUIRED_IDS.size()]
		var alt_b: String = REQUIRED_IDS[(hero_idx + 2) % REQUIRED_IDS.size()]
		var alt_c: String = REQUIRED_IDS[(hero_idx + 3) % REQUIRED_IDS.size()]
		var alt_d: String = REQUIRED_IDS[(hero_idx + 4) % REQUIRED_IDS.size()]

		var present_four := _snapshot(45, [
			[alt_a, 30], [hero_id, 110], [alt_b, 70], [alt_c, 190],
		])
		var absent_four := _snapshot(45, [
			[alt_a, 30], [alt_b, 70], [alt_c, 190], [alt_d, 15],
		])
		var hero_event := _event([
			_choice("hurt_hero", "Prick the named hero.", _hp_effect(10, 15, -4, "hero", hero_id)),
			_choice("heal_hero", "Patch the named hero.", _hp_effect(-5, -10, 6, "hero", hero_id)),
			_choice("zero_hero", "Check the named hero's stitches.", _hp_effect(0, 0, 0, "hero", hero_id)),
		], "ev_stitched_hp_hero_" + hero_id)

		var present_svc := RunStitchedEventConsequence.new(hero_event)
		var present_prev := present_svc.preview(present_four)
		var hurt_entry := _entry(present_prev, "hurt_hero")
		var heal_entry := _entry(present_prev, "heal_hero")
		var zero_hero_entry := _entry(present_prev, "zero_hero")
		_check(hurt_entry.get("available") == true
			and hurt_entry.get("target") == "hero"
			and hurt_entry.get("hero_id") == hero_id
			and hurt_entry.get("hp_delta") == -4
			and hurt_entry.get("hp") == {hero_id: -4}
			and hurt_entry.get("fray") == {hero_id: 15}
			and hurt_entry.get("candle") == 55
			and _receipt_keys(hurt_entry) == expected_hp_preview_keys,
			"AC2: present canonical hero %s previews sole -4 hp intent and exact 10-key entry" % hero_id)
		_check(heal_entry.get("available") == true
			and heal_entry.get("target") == "hero"
			and heal_entry.get("hero_id") == hero_id
			and heal_entry.get("hp_delta") == 6
			and heal_entry.get("hp") == {hero_id: 6}
			and heal_entry.get("fray") == {hero_id: -10}
			and heal_entry.get("candle") == 40
			and _receipt_keys(heal_entry) == expected_hp_preview_keys,
			"AC2: present canonical hero %s previews sole +6 hp intent and exact 10-key entry" % hero_id)
		_check(zero_hero_entry.get("available") == true
			and zero_hero_entry.get("hp_delta") == 0
			and zero_hero_entry.get("hp") == {}
			and zero_hero_entry.get("fray") == {}
			and _receipt_keys(zero_hero_entry) == expected_hp_preview_keys,
			"AC2: present canonical hero %s previews empty hp map for 0 delta" % hero_id)

		var hurt_receipt := present_svc.choose("hurt_hero", present_four)
		_check(hurt_receipt.get("ok") == true
			and hurt_receipt.get("target") == "hero"
			and hurt_receipt.get("hero_id") == hero_id
			and hurt_receipt.get("hp_delta") == -4
			and hurt_receipt.get("hp") == {hero_id: -4}
			and hurt_receipt.get("fray") == {hero_id: 15}
			and hurt_receipt.get("candle") == 55
			and _receipt_keys(hurt_receipt) == expected_hp_receipt_keys,
			"AC2: present canonical hero %s commits sole -4 hp intent with exact 9-key receipt" % hero_id)
		_assert_rejected(present_svc, "heal_hero", present_four, 45,
			"AC2: replay after hero HP commit rejected for %s" % hero_id)

		var heal_receipt := RunStitchedEventConsequence.new(hero_event).choose("heal_hero", present_four)
		_check(heal_receipt.get("ok") == true
			and heal_receipt.get("hp_delta") == 6
			and heal_receipt.get("hp") == {hero_id: 6}
			and _receipt_keys(heal_receipt) == expected_hp_receipt_keys,
			"AC2: present canonical hero %s commits sole +6 hp intent" % hero_id)

		var zero_hero_receipt := RunStitchedEventConsequence.new(hero_event).choose("zero_hero", present_four)
		_check(zero_hero_receipt.get("ok") == true
			and zero_hero_receipt.get("hp_delta") == 0
			and zero_hero_receipt.get("hp") == {}
			and _receipt_keys(zero_hero_receipt) == expected_hp_receipt_keys,
			"AC2: present canonical hero %s commits empty hp map for 0 delta" % hero_id)

		# Absent named hero with a legal party HP alternative and a legacy Leave alternative:
		var retry_event := _event([
			_choice("absent_hurt", "Hurt absent hero.", _hp_effect(10, 15, -4, "hero", hero_id)),
			_choice("party_heal", "Heal active party.", _hp_effect(15, -10, 6, "party")),
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		], "ev_stitched_hp_absent_" + hero_id)
		var absent_svc := RunStitchedEventConsequence.new(retry_event)
		var absent_prev := absent_svc.preview(absent_four)
		var absent_entry := _entry(absent_prev, "absent_hurt")
		_check(absent_entry.get("available") == false
			and absent_entry.get("target") == "hero"
			and absent_entry.get("hero_id") == hero_id
			and absent_entry.get("candle_delta") == 10
			and absent_entry.get("fray_delta") == 15
			and absent_entry.get("hp_delta") == -4
			and absent_entry.get("candle") == 45
			and absent_entry.get("fray") == {}
			and absent_entry.get("hp") == {}
			and _receipt_keys(absent_entry) == expected_hp_preview_keys,
			"AC2: absent canonical hero %s is unavailable with readable hp_delta -4 and empty hp map" % hero_id)
		_assert_rejected(absent_svc, "absent_hurt", absent_four, 45,
			"AC2: absent canonical hero %s cannot claim" % hero_id)
		_check(not absent_svc.is_claimed() and absent_svc.is_valid(),
			"AC2: absent canonical hero %s refusal does not consume the visit" % hero_id)
		var retry_receipt := absent_svc.choose("party_heal", absent_four)
		_check(retry_receipt.get("ok") == true
			and retry_receipt.get("choice_id") == "party_heal"
			and retry_receipt.get("candle") == 60
			and retry_receipt.get("hp_delta") == 6
			and retry_receipt.get("hp") == {
				alt_a: 6, alt_b: 6, alt_c: 6, alt_d: 6,
			}
			and _receipt_keys(retry_receipt) == expected_hp_receipt_keys,
			"AC2: retry of legal party HP choice on same visit succeeds after absent %s" % hero_id)
		_assert_rejected(absent_svc, "leave", absent_four, 45,
			"AC2: replay after retry claim rejected for %s" % hero_id)

		# Required-hero gate on HP-bearing choice across all 8 canonical hero IDs:
		var gated_hp_event := _event([
			_choice("gated_heal", "Required hero heals the party.",
				_hp_required_hero_effect(20, -15, 6, hero_id, "party")),
			_choice("gated_self_hurt", "Required hero takes the needle.",
				_hp_required_hero_effect(10, 5, -4, hero_id, "hero", alt_a)),
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		], "ev_stitched_hp_gate_" + hero_id)
		var gate_absent_svc := RunStitchedEventConsequence.new(gated_hp_event)
		var gate_absent_prev := gate_absent_svc.preview(absent_four)
		_check(_choice_ids(gate_absent_prev) == ["leave"]
			and _entry(gate_absent_prev, "gated_heal") == {}
			and _entry(gate_absent_prev, "gated_self_hurt") == {},
			"AC2: absent required_hero %s hides HP-bearing choices from preview" % hero_id)
		_assert_rejected(gate_absent_svc, "gated_heal", absent_four, 45,
			"AC2: hidden party HP choice rejected when required_hero %s is absent" % hero_id)
		_assert_rejected(gate_absent_svc, "gated_self_hurt", absent_four, 45,
			"AC2: hidden hero HP choice rejected when required_hero %s is absent" % hero_id)
		var gate_leave_receipt := gate_absent_svc.choose("leave", absent_four)
		_check(gate_leave_receipt.get("ok") == true
			and _receipt_keys(gate_leave_receipt) == [
				"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
			],
			"AC2: Leave claims once after hidden HP-choice refusals for %s" % hero_id)

		var gate_present_svc := RunStitchedEventConsequence.new(gated_hp_event)
		var gate_present_prev := gate_present_svc.preview(present_four)
		_check(_choice_ids(gate_present_prev) == ["gated_heal", "gated_self_hurt", "leave"],
			"AC2: present required_hero %s exposes HP-bearing gated choices in authored order" % hero_id)
		var gate_self_entry := _entry(gate_present_prev, "gated_self_hurt")
		_check(gate_self_entry.get("available") == true
			and gate_self_entry.get("hp_delta") == -4
			and gate_self_entry.get("hp") == {alt_a: -4},
			"AC2: present required_hero %s with target=hero directs -4 hp intent only to %s" % [hero_id, alt_a])
		var gate_self_receipt := gate_present_svc.choose("gated_self_hurt", present_four)
		_check(gate_self_receipt.get("ok") == true
			and gate_self_receipt.get("hp_delta") == -4
			and gate_self_receipt.get("hp") == {alt_a: -4}
			and _receipt_keys(gate_self_receipt) == expected_hp_receipt_keys,
			"AC2: present required_hero %s commits target=hero HP choice once" % hero_id)


func _test_hp_combined_and_legacy_shapes() -> void:
	# AC3: Combined HP, candle, fray and optional scraps/gold/part fields can be previewed and
	# claimed together once without settlement, mutation or RNG draws. HP-absent choices keep
	# their original exact 8-key preview and 7-key success receipt (plus any optional wallet/part
	# keys); rejection keeps its exact 7-key shape.
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var catalog_original := warden_catalog.duplicate(true)
	var snap := _gold_scraps_satchel_four(50, 4, 30, 5, [95, 0, 50, 200])
	var snap_original := snap.duplicate(true)

	var combined_hp_effect := {
		"candle": 25,
		"fray": -15,
		"target": "party",
		"required_hero": "warden",
		"scraps": -2,
		"gold": -12,
		"part": {"id": "warden_head_pot_helm_bonk", "tier": 2},
		"hp": 6,
	}
	var hero_hp_scraps_effect := {
		"candle": -10,
		"fray": 10,
		"target": "hero",
		"hero_id": "seamstress",
		"scraps": 3,
		"hp": -4,
	}
	var mixed_event := _event([
		_choice("all_in_mend", "Pay gold and scraps for helm and party stitch.", combined_hp_effect),
		_choice("seamstress_tithe", "Draw thread from the seamstress for scraps.", hero_hp_scraps_effect),
		_choice("legacy_leave", "Leave without touching HP.", _effect(0, 0, "party")),
	], "ev_stitched_hp_combined")
	var event_original := mixed_event.duplicate(true)

	seed(20261112)
	var expected_rng := randi()
	seed(20261112)

	var svc := RunStitchedEventConsequence.new(mixed_event, warden_catalog)
	var prev := svc.preview(snap)
	_check(prev.get("ok") == true and prev.get("candle") == 50,
		"AC3: combined HP+wallet+part event preflights")

	var all_in_entry := _entry(prev, "all_in_mend")
	_check(all_in_entry.get("available") == true
		and all_in_entry.get("candle_delta") == 25
		and all_in_entry.get("candle") == 75
		and all_in_entry.get("fray_delta") == -15
		and all_in_entry.get("fray") == {
			"warden": -15, "seamstress": -15, "tinker": -15, "button_golem": -15,
		}
		and all_in_entry.get("scraps_delta") == -2
		and all_in_entry.get("scraps") == 2
		and all_in_entry.get("gold_delta") == -12
		and all_in_entry.get("gold") == 18
		and all_in_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and all_in_entry.get("satchel_count") == 6
		and all_in_entry.get("hp_delta") == 6
		and all_in_entry.get("hp") == {
			"warden": 6, "seamstress": 6, "tinker": 6, "button_golem": 6,
		}
		and _receipt_keys(all_in_entry) == [
			"available", "candle", "candle_delta", "choice_id", "fray", "fray_delta",
			"gold", "gold_delta", "hero_id", "hp", "hp_delta", "part", "satchel_count",
			"scraps", "scraps_delta", "target",
		],
		"AC3: combined HP+scraps+gold+part preview entry has exact 16 keys and projected values")

	var tithe_entry := _entry(prev, "seamstress_tithe")
	_check(tithe_entry.get("available") == true
		and tithe_entry.get("target") == "hero"
		and tithe_entry.get("hero_id") == "seamstress"
		and tithe_entry.get("candle") == 40
		and tithe_entry.get("fray") == {"seamstress": 10}
		and tithe_entry.get("scraps_delta") == 3
		and tithe_entry.get("scraps") == 7
		and tithe_entry.get("hp_delta") == -4
		and tithe_entry.get("hp") == {"seamstress": -4}
		and _receipt_keys(tithe_entry) == [
			"available", "candle", "candle_delta", "choice_id", "fray", "fray_delta",
			"hero_id", "hp", "hp_delta", "scraps", "scraps_delta", "target",
		],
		"AC3: hero HP+scraps preview entry has exact 12 keys and single-hero -4 hp intent")

	var leave_entry := _entry(prev, "legacy_leave")
	_check(leave_entry.get("available") == true
		and not leave_entry.has("hp")
		and not leave_entry.has("hp_delta")
		and _receipt_keys(leave_entry) == [
			"available", "candle", "candle_delta", "choice_id",
			"fray", "fray_delta", "hero_id", "target",
		],
		"AC3: HP-absent Leave sibling retains exact 8-key preview shape")

	var all_in_receipt := svc.choose("all_in_mend", snap)
	_check(all_in_receipt.get("ok") == true
		and all_in_receipt.get("candle") == 75
		and all_in_receipt.get("fray") == {
			"warden": -15, "seamstress": -15, "tinker": -15, "button_golem": -15,
		}
		and all_in_receipt.get("scraps_delta") == -2
		and all_in_receipt.get("scraps") == 2
		and all_in_receipt.get("gold_delta") == -12
		and all_in_receipt.get("gold") == 18
		and all_in_receipt.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and all_in_receipt.get("satchel_count") == 6
		and all_in_receipt.get("hp_delta") == 6
		and all_in_receipt.get("hp") == {
			"warden": 6, "seamstress": 6, "tinker": 6, "button_golem": 6,
		}
		and _receipt_keys(all_in_receipt) == [
			"candle", "choice_id", "event_id", "fray", "gold", "gold_delta",
			"hero_id", "hp", "hp_delta", "ok", "part", "satchel_count",
			"scraps", "scraps_delta", "target",
		],
		"AC3: combined HP+scraps+gold+part receipt has exact 15 keys and matches preview")
	_assert_rejected(svc, "all_in_mend", snap, 50,
		"AC3: replay of combined HP choice returns exact 7-key refusal")

	var leave_receipt := RunStitchedEventConsequence.new(mixed_event, warden_catalog).choose("legacy_leave", snap)
	_check(leave_receipt.get("ok") == true
		and not leave_receipt.has("hp")
		and not leave_receipt.has("hp_delta")
		and _receipt_keys(leave_receipt) == [
			"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
		],
		"AC3: HP-absent Leave receipt retains exact 7-key shape")

	_check(randi() == expected_rng,
		"AC3: combined HP preview, commit and replay never draw from global RNG")
	_check(snap == snap_original and warden_catalog == catalog_original and mixed_event == event_original,
		"AC3: combined HP preview and commit leave snapshot, catalog and event untouched")

	# Detachment and repeatability of HP intent maps:
	var replay_receipt := RunStitchedEventConsequence.new(mixed_event, warden_catalog).choose("all_in_mend", snap)
	_check(all_in_receipt == replay_receipt,
		"AC3: combined HP receipt is repeatable across fresh instances")
	all_in_entry["hp"]["warden"] = 999
	all_in_receipt["hp"]["warden"] = -999
	_check(RunStitchedEventConsequence.new(mixed_event, warden_catalog).choose("all_in_mend", snap) == replay_receipt
		and snap == snap_original,
		"AC3: mutating preview or receipt hp dictionary never aliases caller state or later visits")

	# Wallet and satchel capacity checks on HP-bearing combined choices (insufficient scraps,
	# insufficient gold, full satchel_count == 6, missing balances):
	var low_scraps_snap := _gold_scraps_satchel_four(50, 1, 30, 5, [95, 0, 50, 200])
	var low_scraps_svc := RunStitchedEventConsequence.new(mixed_event, warden_catalog)
	var low_scraps_entry := _entry(low_scraps_svc.preview(low_scraps_snap), "all_in_mend")
	_check(low_scraps_entry.get("available") == false
		and low_scraps_entry.get("hp_delta") == 6
		and low_scraps_entry.get("hp") == {}
		and low_scraps_entry.get("fray") == {}
		and low_scraps_entry.get("scraps") == 1
		and low_scraps_entry.get("gold") == 30
		and low_scraps_entry.get("satchel_count") == 5
		and low_scraps_entry.get("candle") == 50,
		"AC3: insufficient scraps disables combined HP choice and leaves hp map empty")
	_assert_rejected(low_scraps_svc, "all_in_mend", low_scraps_snap, 50,
		"AC3: insufficient scraps on combined HP choice")
	var fallback_tithe := low_scraps_svc.choose("seamstress_tithe", low_scraps_snap)
	_check(fallback_tithe.get("ok") == true
		and fallback_tithe.get("scraps") == 4
		and fallback_tithe.get("hp") == {"seamstress": -4},
		"AC3: legal HP+scraps sibling claims after insufficient-scraps refusal")

	var low_gold_snap := _gold_scraps_satchel_four(50, 4, 5, 5, [95, 0, 50, 200])
	var low_gold_svc := RunStitchedEventConsequence.new(mixed_event, warden_catalog)
	var low_gold_entry := _entry(low_gold_svc.preview(low_gold_snap), "all_in_mend")
	_check(low_gold_entry.get("available") == false
		and low_gold_entry.get("hp_delta") == 6
		and low_gold_entry.get("hp") == {}
		and low_gold_entry.get("gold") == 5,
		"AC3: insufficient gold disables combined HP choice and leaves hp map empty")
	_assert_rejected(low_gold_svc, "all_in_mend", low_gold_snap, 50,
		"AC3: insufficient gold on combined HP choice")
	_check(low_gold_svc.choose("legacy_leave", low_gold_snap).get("ok") == true,
		"AC3: Leave claims after insufficient-gold combined HP refusal")

	var full_satchel_snap := _gold_scraps_satchel_four(50, 4, 30, 6, [95, 0, 50, 200])
	var full_satchel_svc := RunStitchedEventConsequence.new(mixed_event, warden_catalog)
	var full_satchel_entry := _entry(full_satchel_svc.preview(full_satchel_snap), "all_in_mend")
	_check(full_satchel_entry.get("available") == false
		and full_satchel_entry.get("hp_delta") == 6
		and full_satchel_entry.get("hp") == {}
		and full_satchel_entry.get("satchel_count") == 6,
		"AC3: full satchel (6) disables combined HP+part choice and leaves hp map empty")
	_assert_rejected(full_satchel_svc, "all_in_mend", full_satchel_snap, 50,
		"AC3: full satchel on combined HP+part choice")
	_check(full_satchel_svc.choose("seamstress_tithe", full_satchel_snap).get("ok") == true,
		"AC3: non-part HP sibling claims when satchel is full")


func _test_hp_rejections() -> void:
	# AC4: Fractional, nonfinite, string, null, out-of-safe-integral-range or wrong-shaped hp
	# values make that choice unavailable and unclaimable without consuming the visit; a valid
	# alternative still works.
	var snap := _four(40, [95, 0, 50, 200])
	var snap_original := snap.duplicate(true)
	var expected_malformed_preview_keys := [
		"available", "candle", "candle_delta", "choice_id",
		"fray", "fray_delta", "hero_id", "target",
	]
	var bad_hp_values: Array = [
		1.5,
		-4.5,
		0.25,
		INF,
		-INF,
		NAN,
		"6",
		"-4",
		"0",
		"",
		" ",
		null,
		true,
		false,
		9007199254740992.0 * 2.0,
		-9007199254740992.0 * 2.0,
		[6],
		[-4],
		{"hp": 6},
		{"amount": -4},
	]

	seed(20261113)
	var expected_rng := randi()
	seed(20261113)

	for index in range(bad_hp_values.size()):
		var bad_hp: Variant = bad_hp_values[index]
		for target_mode in ["party", "hero"]:
			var broken_choice := _choice(
				"broken_hp",
				"Malformed HP outcome.",
				_hp_effect(20, -15, bad_hp, target_mode, "seamstress")
			)
			var svc := RunStitchedEventConsequence.new(_event([
				broken_choice,
				_choice("valid_heal", "Valid party stitch.", _hp_effect(15, -20, 6, "party")),
				_choice("leave", "Leave.", _effect(0, 0, "party")),
			]))
			_check(svc.is_valid() and not svc.is_claimed(),
				"AC4: malformed hp %d (%s) keeps event envelope valid" % [index, target_mode])
			var prev := svc.preview(snap)
			_check(prev.get("ok") == true,
				"AC4: malformed hp %d (%s) keeps event preflight readable" % [index, target_mode])
			var broken_entry := _entry(prev, "broken_hp")
			_check(broken_entry.get("available") == false
				and broken_entry.get("candle_delta") == null
				and broken_entry.get("fray_delta") == null
				and broken_entry.get("hp_delta") == null
				and not broken_entry.has("hp")
				and not broken_entry.has("hp_delta")
				and broken_entry.get("candle") == 40
				and broken_entry.get("fray") == {}
				and _receipt_keys(broken_entry) == expected_malformed_preview_keys,
				"AC4: malformed hp %d (%s) is unavailable with null deltas and no hp keys" % [index, target_mode])
			_check(_entry(prev, "valid_heal").get("available") == true
				and _entry(prev, "leave").get("available") == true,
				"AC4: malformed hp %d (%s) leaves valid siblings available" % [index, target_mode])
			_assert_rejected(svc, "broken_hp", snap, 40,
				"AC4: malformed hp %d (%s) commit" % [index, target_mode])
			_check(not svc.is_claimed(),
				"AC4: malformed hp %d (%s) refusal never latches the visit" % [index, target_mode])
			var fallback := svc.choose("valid_heal", snap)
			_check(fallback.get("ok") == true
				and fallback.get("candle") == 55
				and fallback.get("hp_delta") == 6
				and fallback.get("hp") == {
					"warden": 6, "seamstress": 6, "tinker": 6, "button_golem": 6,
				},
				"AC4: valid HP sibling still claims after malformed hp %d (%s)" % [index, target_mode])
			_assert_rejected(svc, "leave", snap, 40,
				"AC4: replay after valid sibling claim rejected (%d, %s)" % [index, target_mode])

	# Structural errors alongside valid hp (party with hero_id, hero without hero_id,
	# unknown hero_id, invalid required_hero, absent required_hero with malformed hp, extra key):
	var structural_broken: Array = [
		{"id": "broken_hp", "text": "Party target with hero_id and hp.", "stitched_effect": {
			"candle": 15, "fray": -10, "target": "party", "hero_id": "warden", "hp": 6,
		}},
		{"id": "broken_hp", "text": "Hero target missing hero_id with hp.", "stitched_effect": {
			"candle": 15, "fray": -10, "target": "hero", "hp": -4,
		}},
		{"id": "broken_hp", "text": "Unknown hero_id with hp.", "stitched_effect": {
			"candle": 15, "fray": -10, "target": "hero", "hero_id": "porcelain_doll", "hp": -4,
		}},
		{"id": "broken_hp", "text": "Invalid required_hero with hp.", "stitched_effect": {
			"candle": 15, "fray": -10, "target": "party", "required_hero": "porcelain_doll", "hp": 6,
		}},
		{"id": "broken_hp", "text": "Absent required_hero with fractional hp is malformed, not hidden.", "stitched_effect": {
			"candle": 15, "fray": -10, "target": "party", "required_hero": "lantern_monk", "hp": 1.5,
		}},
		{"id": "broken_hp", "text": "Extra unknown key alongside hp.", "stitched_effect": {
			"candle": 15, "fray": -10, "target": "party", "hp": 6, "max_hp": 4,
		}},
	]
	for index in range(structural_broken.size()):
		var svc := RunStitchedEventConsequence.new(_event([
			structural_broken[index],
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		]))
		var prev := svc.preview(snap)
		var broken_entry := _entry(prev, "broken_hp")
		_check(_choice_ids(prev) == ["broken_hp", "leave"]
			and broken_entry.get("available") == false
			and broken_entry.get("candle_delta") == null
			and broken_entry.get("fray_delta") == null
			and not broken_entry.has("hp")
			and not broken_entry.has("hp_delta"),
			"AC4: structural malformed HP choice %d is shown unavailable with null deltas" % index)
		_assert_rejected(svc, "broken_hp", snap, 40,
			"AC4: structural malformed HP choice %d commit" % index)
		_check(svc.choose("leave", snap).get("ok") == true,
			"AC4: Leave claims after structural malformed HP choice %d" % index)

	_check(randi() == expected_rng,
		"AC4: malformed HP checks and fallback claims never draw from global RNG")
	_check(snap == snap_original,
		"AC4: malformed HP checks never mutate caller snapshot")


func _paid_wick_effect(candle: Variant, fray: int, require_full_candle: Variant = true,
		target: String = "party", hero_id: String = "") -> Dictionary:
	var effect := {
		"candle": candle,
		"fray": fray,
		"target": target,
		"require_full_candle": require_full_candle,
	}
	if target == "hero":
		effect["hero_id"] = hero_id
	return effect


func _paid_wick_event() -> Dictionary:
	return _event([
		_choice("pay_wick", "Burn a quarter of the wick to soothe the party's seams.",
			_paid_wick_effect(-25, -25, true, "party")),
		_choice("leave", "Keep the remaining wick untouched.",
			_effect(0, 0, "party")),
	], "ev_stitched_paid_wick_bargain")


func _test_paid_wick_party_and_hero_bargains() -> void:
	var expected_preview_keys := [
		"available", "candle", "candle_delta", "choice_id",
		"fray", "fray_delta", "hero_id", "target",
	]
	var expected_receipt_keys := [
		"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
	]
	var expected_party_fray := {
		"warden": -25,
		"seamstress": -25,
		"tinker": -25,
		"button_golem": -25,
	}

	# AC1: Four-hero snapshot (warden, seamstress, tinker, button_golem, each fray 80, candle 40)
	# with {candle:-25, fray:-25, target:"party", require_full_candle:true} and Leave {candle:0, fray:0, target:"party"}.
	var snap_40 := _four(40, [80, 80, 80, 80])
	var snap_40_original := snap_40.duplicate(true)
	var event_record := _paid_wick_event()
	var event_original := event_record.duplicate(true)

	seed(20261114)
	var expected_rng := randi()
	seed(20261114)

	var svc := RunStitchedEventConsequence.new(event_record)
	_check(svc.is_valid() and not svc.is_claimed(),
		"AC1: paid-wick Event opens valid and unclaimed")
	var prev_40 := svc.preview(snap_40)
	_check(prev_40.get("ok") == true
		and prev_40.get("event_id") == "ev_stitched_paid_wick_bargain"
		and prev_40.get("candle") == 40
		and _choice_ids(prev_40) == ["pay_wick", "leave"],
		"AC1: paid-wick Event preflights at candle 40 with exact choice order")

	var pay_entry_40 := _entry(prev_40, "pay_wick")
	_check(pay_entry_40.get("available") == true
		and pay_entry_40.get("target") == "party"
		and pay_entry_40.get("hero_id") == ""
		and pay_entry_40.get("candle_delta") == -25
		and pay_entry_40.get("fray_delta") == -25
		and pay_entry_40.get("candle") == 15
		and pay_entry_40.get("fray") == expected_party_fray
		and (pay_entry_40.get("fray") as Dictionary).size() == 4
		and _receipt_keys(pay_entry_40) == expected_preview_keys,
		"AC1: at candle 40, pay_wick is offered and previews candle 15, four raw -25 fray intents, and exact 8-key shape")

	var leave_entry_40 := _entry(prev_40, "leave")
	_check(leave_entry_40.get("available") == true
		and leave_entry_40.get("target") == "party"
		and leave_entry_40.get("hero_id") == ""
		and leave_entry_40.get("candle_delta") == 0
		and leave_entry_40.get("fray_delta") == 0
		and leave_entry_40.get("candle") == 40
		and leave_entry_40.get("fray") == {}
		and _receipt_keys(leave_entry_40) == expected_preview_keys,
		"AC1: Leave sibling previews unchanged candle 40, empty fray map, and exact 8-key shape")

	var receipt_40 := svc.choose("pay_wick", snap_40)
	_check(receipt_40.get("ok") == true
		and receipt_40.get("event_id") == "ev_stitched_paid_wick_bargain"
		and receipt_40.get("choice_id") == "pay_wick"
		and receipt_40.get("target") == "party"
		and receipt_40.get("hero_id") == ""
		and receipt_40.get("candle") == 15
		and receipt_40.get("fray") == expected_party_fray
		and _receipt_keys(receipt_40) == expected_receipt_keys,
		"AC1: choose(pay_wick) at candle 40 returns candle 15, four raw -25 fray intents, and exact 7-key receipt")
	_check(svc.is_claimed() and not svc.is_valid(),
		"AC1: choose(pay_wick) claims the visit once")
	_assert_rejected(svc, "pay_wick", snap_40, 40,
		"AC1/AC3: duplicate claim of pay_wick is rejected")
	_assert_rejected(svc, "leave", snap_40, 40,
		"AC1/AC3: Leave after pay_wick claim is rejected")
	_check(svc.preview(snap_40) == _denied_preview(),
		"AC1/AC3: claimed paid-wick visit denies preflight")

	# Deterministic replay across equal detached snapshots and mutation isolation:
	var replay_svc := RunStitchedEventConsequence.new(event_record.duplicate(true))
	var replay_snap := snap_40.duplicate(true)
	var replay_prev := replay_svc.preview(replay_snap)
	var replay_receipt := replay_svc.choose("pay_wick", replay_snap)
	_check(replay_prev == prev_40 and replay_receipt == receipt_40,
		"AC1: paid-wick preview and receipt are deterministic across equal detached snapshots")
	pay_entry_40["fray"]["warden"] = 999
	pay_entry_40["candle"] = 99
	receipt_40["fray"]["warden"] = -999
	receipt_40["candle"] = 0
	_check(snap_40 == snap_40_original and event_record == event_original
		and RunStitchedEventConsequence.new(event_record).choose("pay_wick", snap_40) == replay_receipt,
		"AC1: mutating returned preview or receipt never mutates caller snapshot, event, or later visits")
	_check(randi() == expected_rng,
		"AC1: paid-wick construction, preview, commit and duplicate-claim rejection never draw global RNG")

	# Named-hero target coverage across all 8 canonical heroes (funded vs underfunded vs absent hero):
	for hero_idx in range(REQUIRED_IDS.size()):
		var hero_id: String = REQUIRED_IDS[hero_idx]
		var alt_a: String = REQUIRED_IDS[(hero_idx + 1) % REQUIRED_IDS.size()]
		var alt_b: String = REQUIRED_IDS[(hero_idx + 2) % REQUIRED_IDS.size()]
		var alt_c: String = REQUIRED_IDS[(hero_idx + 3) % REQUIRED_IDS.size()]
		var alt_d: String = REQUIRED_IDS[(hero_idx + 4) % REQUIRED_IDS.size()]

		var hero_event := _event([
			_choice("pay_wick_hero", "Burn wick for named hero.",
				_paid_wick_effect(-25, -25, true, "hero", hero_id)),
			_choice("pay_wick", "Burn wick for party.",
				_paid_wick_effect(-25, -25, true, "party")),
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		], "ev_stitched_paid_wick_" + hero_id)

		for funded_case in [[40, 15], [25, 0], [100, 75]]:
			var funded_candle: int = funded_case[0]
			var expected_candle: int = funded_case[1]
			var present_snap := _snapshot(funded_candle, [
				[alt_a, 80], [hero_id, 80], [alt_b, 80], [alt_c, 80],
			])
			var hero_svc := RunStitchedEventConsequence.new(hero_event)
			var hero_prev := hero_svc.preview(present_snap)
			var hero_entry := _entry(hero_prev, "pay_wick_hero")
			_check(hero_entry.get("available") == true
				and hero_entry.get("target") == "hero"
				and hero_entry.get("hero_id") == hero_id
				and hero_entry.get("candle_delta") == -25
				and hero_entry.get("fray_delta") == -25
				and hero_entry.get("candle") == expected_candle
				and hero_entry.get("fray") == {hero_id: -25}
				and _receipt_keys(hero_entry) == expected_preview_keys,
				"paid-wick hero target %s at candle %d previews candle %d and sole -25 fray" % [
					hero_id, funded_candle, expected_candle,
				])
			var hero_rec := hero_svc.choose("pay_wick_hero", present_snap)
			_check(hero_rec.get("ok") == true
				and hero_rec.get("target") == "hero"
				and hero_rec.get("hero_id") == hero_id
				and hero_rec.get("candle") == expected_candle
				and hero_rec.get("fray") == {hero_id: -25}
				and _receipt_keys(hero_rec) == expected_receipt_keys,
				"paid-wick hero target %s at candle %d commits candle %d and sole -25 fray" % [
					hero_id, funded_candle, expected_candle,
				])

		for underfunded_candle in [24, 0]:
			var low_snap := _snapshot(underfunded_candle, [
				[alt_a, 80], [hero_id, 80], [alt_b, 80], [alt_c, 80],
			])
			var low_svc := RunStitchedEventConsequence.new(hero_event)
			var low_prev := low_svc.preview(low_snap)
			var low_hero_entry := _entry(low_prev, "pay_wick_hero")
			_check(low_hero_entry.get("available") == false
				and low_hero_entry.get("candle_delta") == -25
				and low_hero_entry.get("fray_delta") == -25
				and low_hero_entry.get("candle") == underfunded_candle
				and low_hero_entry.get("fray") == {}
				and _receipt_keys(low_hero_entry) == expected_preview_keys,
				"paid-wick hero target %s at candle %d is unavailable with unchanged candle and empty fray" % [
					hero_id, underfunded_candle,
				])
			_assert_rejected(low_svc, "pay_wick_hero", low_snap, underfunded_candle,
				"underfunded paid-wick hero target %s at candle %d" % [hero_id, underfunded_candle])
			var low_leave := low_svc.choose("leave", low_snap)
			_check(low_leave.get("ok") == true and low_leave.get("candle") == underfunded_candle,
				"Leave claims after underfunded paid-wick hero denial for %s at candle %d" % [
					hero_id, underfunded_candle,
				])

		var absent_snap := _snapshot(40, [
			[alt_a, 80], [alt_b, 80], [alt_c, 80], [alt_d, 80],
		])
		var absent_svc := RunStitchedEventConsequence.new(hero_event)
		var absent_prev := absent_svc.preview(absent_snap)
		var absent_entry := _entry(absent_prev, "pay_wick_hero")
		_check(absent_entry.get("available") == false
			and absent_entry.get("candle") == 40
			and absent_entry.get("fray") == {},
			"paid-wick hero target %s when absent from party is unavailable even at candle 40" % hero_id)
		_assert_rejected(absent_svc, "pay_wick_hero", absent_snap, 40,
			"absent hero on paid-wick hero choice for " + hero_id)
		var fallback_party := absent_svc.choose("pay_wick", absent_snap)
		_check(fallback_party.get("ok") == true and fallback_party.get("candle") == 15,
			"funded party paid-wick sibling claims after absent-hero refusal for " + hero_id)

	# Combined paid-wick with existing optional fields (required_hero, scraps, gold, part, hp):
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var combined_effect := {
		"candle": -25,
		"fray": -25,
		"target": "party",
		"required_hero": "warden",
		"scraps": -2,
		"gold": -12,
		"part": {"id": "warden_head_pot_helm_bonk", "tier": 2},
		"hp": 6,
		"require_full_candle": true,
	}
	var combined_event := _event([
		_choice("pay_wick", "Full paid bargain with all optional fields.", combined_effect),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_paid_wick_combined")

	var funded_combo_snap := _gold_scraps_satchel_four(40, 4, 30, 5, [80, 80, 80, 80])
	var funded_combo_svc := RunStitchedEventConsequence.new(combined_event, warden_catalog)
	var funded_combo_prev := funded_combo_svc.preview(funded_combo_snap)
	var funded_combo_entry := _entry(funded_combo_prev, "pay_wick")
	_check(funded_combo_entry.get("available") == true
		and funded_combo_entry.get("candle") == 15
		and funded_combo_entry.get("scraps") == 2
		and funded_combo_entry.get("gold") == 18
		and funded_combo_entry.get("satchel_count") == 6
		and funded_combo_entry.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 2}
		and funded_combo_entry.get("fray") == expected_party_fray
		and funded_combo_entry.get("hp") == {
			"warden": 6, "seamstress": 6, "tinker": 6, "button_golem": 6,
		}
		and _receipt_keys(funded_combo_entry) == [
			"available", "candle", "candle_delta", "choice_id", "fray", "fray_delta",
			"gold", "gold_delta", "hero_id", "hp", "hp_delta", "part", "satchel_count",
			"scraps", "scraps_delta", "target",
		],
		"AC1/AC3: combined paid-wick + scraps/gold/part/hp/required_hero previews all fields at candle 40")
	var funded_combo_rec := funded_combo_svc.choose("pay_wick", funded_combo_snap)
	_check(funded_combo_rec.get("ok") == true
		and funded_combo_rec.get("candle") == 15
		and funded_combo_rec.get("scraps") == 2
		and funded_combo_rec.get("gold") == 18
		and funded_combo_rec.get("satchel_count") == 6
		and _receipt_keys(funded_combo_rec) == [
			"candle", "choice_id", "event_id", "fray", "gold", "gold_delta",
			"hero_id", "hp", "hp_delta", "ok", "part", "satchel_count",
			"scraps", "scraps_delta", "target",
		],
		"AC1/AC3: combined paid-wick + scraps/gold/part/hp/required_hero commits with exact 15-key receipt")

	var underfunded_combo_snap := _gold_scraps_satchel_four(24, 4, 30, 5, [80, 80, 80, 80])
	var underfunded_combo_svc := RunStitchedEventConsequence.new(combined_event, warden_catalog)
	var underfunded_combo_entry := _entry(underfunded_combo_svc.preview(underfunded_combo_snap), "pay_wick")
	_check(underfunded_combo_entry.get("available") == false
		and underfunded_combo_entry.get("candle") == 24
		and underfunded_combo_entry.get("scraps") == 4
		and underfunded_combo_entry.get("gold") == 30
		and underfunded_combo_entry.get("satchel_count") == 5
		and underfunded_combo_entry.get("fray") == {}
		and underfunded_combo_entry.get("hp") == {},
		"AC2/AC3: underfunded combined paid-wick at candle 24 leaves candle/scraps/gold/satchel_count unprojected and fray/hp empty")
	_assert_rejected(underfunded_combo_svc, "pay_wick", underfunded_combo_snap, 24,
		"AC2/AC3: underfunded combined paid-wick rejected at candle 24")
	_check(underfunded_combo_svc.choose("leave", underfunded_combo_snap).get("ok") == true,
		"AC2/AC3: Leave claims after underfunded combined paid-wick refusal")


func _test_paid_wick_underfunded_and_bounds() -> void:
	var expected_party_fray := {
		"warden": -25,
		"seamstress": -25,
		"tinker": -25,
		"button_golem": -25,
	}
	var expected_preview_keys := [
		"available", "candle", "candle_delta", "choice_id",
		"fray", "fray_delta", "hero_id", "target",
	]
	var expected_receipt_keys := [
		"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
	]

	# AC2: Funded boundary checks at candle 25 -> 0 and candle 100 -> 75 (plus 40 -> 15):
	for funded_case in [[25, 0], [40, 15], [100, 75]]:
		var base_candle: int = funded_case[0]
		var expected_candle: int = funded_case[1]
		var snap := _four(base_candle, [80, 80, 80, 80])
		var snap_original := snap.duplicate(true)

		seed(20261115 + base_candle)
		var expected_rng := randi()
		seed(20261115 + base_candle)

		var svc := RunStitchedEventConsequence.new(_paid_wick_event())
		var prev := svc.preview(snap)
		var pay_entry := _entry(prev, "pay_wick")
		_check(pay_entry.get("available") == true
			and pay_entry.get("candle_delta") == -25
			and pay_entry.get("fray_delta") == -25
			and pay_entry.get("candle") == expected_candle
			and pay_entry.get("fray") == expected_party_fray
			and _receipt_keys(pay_entry) == expected_preview_keys,
			"AC2: at candle %d, pay_wick is available and previews candle %d" % [base_candle, expected_candle])
		var rec := svc.choose("pay_wick", snap)
		_check(rec.get("ok") == true
			and rec.get("choice_id") == "pay_wick"
			and rec.get("candle") == expected_candle
			and rec.get("fray") == expected_party_fray
			and _receipt_keys(rec) == expected_receipt_keys,
			"AC2: at candle %d, choose(pay_wick) succeeds with candle %d and claims once" % [base_candle, expected_candle])
		_check(svc.is_claimed() and not svc.is_valid(),
			"AC2: at candle %d, choose(pay_wick) latches the visit" % base_candle)
		_assert_rejected(svc, "pay_wick", snap, base_candle,
			"AC2: replay at candle %d rejected" % base_candle)
		_assert_rejected(svc, "leave", snap, base_candle,
			"AC2: Leave after claim at candle %d rejected" % base_candle)
		_check(snap == snap_original and randi() == expected_rng,
			"AC2: funded bound %d mutates nothing and draws no RNG" % base_candle)

	# AC2: Denied previews and non-latching rejections at candle 24 and 0 (plus intermediate underfunded values),
	# followed by a legal zero-effect Leave on the same instance:
	for denied_candle in [24, 0, 1, 12]:
		var snap := _four(denied_candle, [80, 80, 80, 80])
		var snap_original := snap.duplicate(true)

		seed(20261300 + denied_candle)
		var expected_rng := randi()
		seed(20261300 + denied_candle)

		var svc := RunStitchedEventConsequence.new(_paid_wick_event())
		var prev := svc.preview(snap)
		_check(prev.get("ok") == true
			and prev.get("event_id") == "ev_stitched_paid_wick_bargain"
			and prev.get("candle") == denied_candle
			and _choice_ids(prev) == ["pay_wick", "leave"],
			"AC2: at candle %d, paid Event still preflights with both choices" % denied_candle)

		var pay_entry := _entry(prev, "pay_wick")
		_check(pay_entry.get("available") == false
			and pay_entry.get("target") == "party"
			and pay_entry.get("hero_id") == ""
			and pay_entry.get("candle_delta") == -25
			and pay_entry.get("fray_delta") == -25
			and pay_entry.get("candle") == denied_candle
			and pay_entry.get("fray") == {}
			and _receipt_keys(pay_entry) == expected_preview_keys,
			"AC2: at candle %d, preview marks pay_wick unavailable with unchanged candle %d and empty fray" % [
				denied_candle, denied_candle,
			])

		var leave_entry := _entry(prev, "leave")
		_check(leave_entry.get("available") == true
			and leave_entry.get("candle") == denied_candle
			and leave_entry.get("fray") == {},
			"AC2: at candle %d, Leave remains available in preview" % denied_candle)

		_assert_rejected(svc, "pay_wick", snap, denied_candle,
			"AC2: underfunded pay_wick at candle %d" % denied_candle)
		_check(not svc.is_claimed() and svc.is_valid(),
			"AC2: underfunded pay_wick at candle %d leaves visit unclaimed" % denied_candle)
		_check(svc.preview(snap) == prev,
			"AC2: preflight remains identical after underfunded rejection at candle %d" % denied_candle)

		var leave_rec := svc.choose("leave", snap)
		_check(leave_rec.get("ok") == true
			and leave_rec.get("event_id") == "ev_stitched_paid_wick_bargain"
			and leave_rec.get("choice_id") == "leave"
			and leave_rec.get("target") == "party"
			and leave_rec.get("hero_id") == ""
			and leave_rec.get("candle") == denied_candle
			and leave_rec.get("fray") == {}
			and _receipt_keys(leave_rec) == expected_receipt_keys,
			"AC2: at candle %d, Leave succeeds on the same instance after pay_wick denial" % denied_candle)
		_check(svc.is_claimed() and not svc.is_valid(),
			"AC2: Leave latches the visit after underfunded denial at candle %d" % denied_candle)
		_assert_rejected(svc, "leave", snap, denied_candle,
			"AC2: duplicate Leave after claim at candle %d rejected" % denied_candle)
		_assert_rejected(svc, "pay_wick", snap, denied_candle,
			"AC2: pay_wick after Leave claim at candle %d rejected" % denied_candle)
		_check(snap == snap_original,
			"AC2: underfunded denial and Leave at candle %d leave caller snapshot untouched" % denied_candle)
		_check(randi() == expected_rng,
			"AC2: underfunded denial and Leave at candle %d never draw global RNG" % denied_candle)

	# Retry on same instance with a funded snapshot after an underfunded denial:
	var retry_svc := RunStitchedEventConsequence.new(_paid_wick_event())
	var snap_24 := _four(24, [80, 80, 80, 80])
	var snap_25 := _four(25, [80, 80, 80, 80])
	_assert_rejected(retry_svc, "pay_wick", snap_24, 24,
		"AC2: denied at candle 24 before retry at candle 25")
	var retry_rec := retry_svc.choose("pay_wick", snap_25)
	_check(retry_rec.get("ok") == true
		and retry_rec.get("candle") == 0
		and retry_rec.get("fray") == expected_party_fray,
		"AC2: same unclaimed instance accepts pay_wick when retried with candle 25")
	_assert_rejected(retry_svc, "leave", snap_25, 25,
		"AC2: replay rejected after funded retry claim")

	# Exact -1 and -100 paid-wick boundaries and extreme negative deltas (including MIN_INT):
	var one_wick_event := _event([
		_choice("pay_one", "Pay 1 candle.", _paid_wick_effect(-1, -5, true, "party")),
		_choice("pay_all", "Pay 100 candle.", _paid_wick_effect(-100, -50, true, "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	_check(_entry(RunStitchedEventConsequence.new(one_wick_event).preview(_four(0, [80, 80, 80, 80])), "pay_one").get("available") == false
		and _entry(RunStitchedEventConsequence.new(one_wick_event).preview(_four(1, [80, 80, 80, 80])), "pay_one").get("available") == true
		and _entry(RunStitchedEventConsequence.new(one_wick_event).preview(_four(99, [80, 80, 80, 80])), "pay_all").get("available") == false
		and _entry(RunStitchedEventConsequence.new(one_wick_event).preview(_four(100, [80, 80, 80, 80])), "pay_all").get("available") == true,
		"AC2: -1 and -100 paid-wick choices enforce exact >= 1 and >= 100 candle bounds")

	var min_int: int = -9223372036854775807 - 1
	var extreme_paid_event := _event([
		_choice("pay_min_int", "Impossible wick cost (MIN_INT).",
			_paid_wick_effect(min_int, -25, true, "party")),
		_choice("pay_max_neg", "Impossible wick cost (-MAX_INT).",
			_paid_wick_effect(-9223372036854775807, -25, true, "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	var snap_100 := _four(100, [80, 80, 80, 80])
	var extreme_svc := RunStitchedEventConsequence.new(extreme_paid_event)
	var extreme_prev := extreme_svc.preview(snap_100)
	_check(_entry(extreme_prev, "pay_min_int").get("available") == false
		and _entry(extreme_prev, "pay_min_int").get("candle_delta") == min_int
		and _entry(extreme_prev, "pay_min_int").get("candle") == 100
		and _entry(extreme_prev, "pay_min_int").get("fray") == {}
		and _entry(extreme_prev, "pay_max_neg").get("available") == false
		and _entry(extreme_prev, "pay_max_neg").get("candle_delta") == -9223372036854775807
		and _entry(extreme_prev, "pay_max_neg").get("candle") == 100,
		"AC2: MIN_INT and -MAX_INT paid-wick deltas compare safely in signed arithmetic without overflow")
	_assert_rejected(extreme_svc, "pay_min_int", snap_100, 100,
		"AC2: MIN_INT paid-wick delta rejected safely")
	_assert_rejected(extreme_svc, "pay_max_neg", snap_100, 100,
		"AC2: -MAX_INT paid-wick delta rejected safely")
	_check(extreme_svc.choose("leave", snap_100).get("ok") == true,
		"AC2: Leave claims after extreme negative paid-wick rejections")

	var service_source := FileAccess.get_file_as_string("res://scripts/run_stitched_event_consequence.gd")
	_check(service_source.find("abs(") == -1 and service_source.find("absi(") == -1,
		"AC2: service never calls abs() or absi() on signed integer deltas")


func _test_paid_wick_opt_in_and_rejections() -> void:
	var snap_24 := _four(24, [80, 80, 80, 80])
	var snap_0 := _four(0, [80, 80, 80, 80])
	var snap_40 := _four(40, [80, 80, 80, 80])
	var snap_40_original := snap_40.duplicate(true)
	var expected_malformed_preview_keys := [
		"available", "candle", "candle_delta", "choice_id",
		"fray", "fray_delta", "hero_id", "target",
	]

	# 1. AC3: Optional absence keeps legacy unconditional candle clamping to 0 and unchanged shapes:
	var legacy_unclamped_event := _event([
		_choice("legacy_burn", "Burn wick without require_full_candle.", _effect(-25, -25, "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	for low_candle in [24, 0]:
		var low_snap := _four(low_candle, [80, 80, 80, 80])
		var legacy_svc := RunStitchedEventConsequence.new(legacy_unclamped_event)
		var legacy_prev := legacy_svc.preview(low_snap)
		var legacy_entry := _entry(legacy_prev, "legacy_burn")
		_check(legacy_entry.get("available") == true
			and legacy_entry.get("candle") == 0
			and legacy_entry.get("fray") == {
				"warden": -25, "seamstress": -25, "tinker": -25, "button_golem": -25,
			}
			and _receipt_keys(legacy_entry) == expected_malformed_preview_keys,
			"AC3: omitting require_full_candle at candle %d preserves legacy clamped candle 0 and 8-key preview" % low_candle)
		var legacy_rec := legacy_svc.choose("legacy_burn", low_snap)
		_check(legacy_rec.get("ok") == true
			and legacy_rec.get("candle") == 0
			and _receipt_keys(legacy_rec) == [
				"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
			],
			"AC3: omitting require_full_candle at candle %d commits clamped candle 0 with 7-key receipt" % low_candle)

	seed(20261116)
	var expected_rng := randi()
	seed(20261116)

	# 2. AC3: Invalid opt-in booleans/types (false, non-boolean) on a negative candle delta are malformed
	#    outcomes (unavailable with null deltas and unclaimable), NOT silent opt-outs:
	var bad_flag_values: Array = [
		false,
		null,
		1,
		0,
		-1,
		1.0,
		0.0,
		"true",
		"false",
		"1",
		"",
		" ",
		[true],
		{"require_full_candle": true},
	]
	for index in range(bad_flag_values.size()):
		var bad_flag: Variant = bad_flag_values[index]
		for target_mode in ["party", "hero"]:
			var broken_choice := _choice(
				"broken_wick",
				"Invalid require_full_candle value.",
				_paid_wick_effect(-25, -25, bad_flag, target_mode, "seamstress")
			)
			for test_snap in [snap_40, snap_24, snap_0]:
				var base_candle: int = int(test_snap["candle"])
				var svc := RunStitchedEventConsequence.new(_event([
					broken_choice,
					_choice("leave", "Leave.", _effect(0, 0, "party")),
				]))
				var prev := svc.preview(test_snap)
				var broken_entry := _entry(prev, "broken_wick")
				_check(prev.get("ok") == true
					and broken_entry.get("available") == false
					and broken_entry.get("candle_delta") == null
					and broken_entry.get("fray_delta") == null
					and broken_entry.get("candle") == base_candle
					and broken_entry.get("fray") == {}
					and _receipt_keys(broken_entry) == expected_malformed_preview_keys,
					"AC3: invalid require_full_candle %d (%s, candle %d) is malformed with null deltas" % [
						index, target_mode, base_candle,
					])
				_assert_rejected(svc, "broken_wick", test_snap, base_candle,
					"AC3: invalid require_full_candle %d (%s, candle %d) commit" % [
						index, target_mode, base_candle,
					])
				var leave_rec := svc.choose("leave", test_snap)
				_check(leave_rec.get("ok") == true and leave_rec.get("candle") == base_candle,
					"AC3: Leave still claims after invalid require_full_candle %d (%s, candle %d)" % [
						index, target_mode, base_candle,
					])

	# 3. AC3: Nonnegative, fractional, or non-integer candle deltas with require_full_candle: true are malformed:
	var bad_paid_candle_deltas: Array = [
		0,
		1,
		25,
		100,
		9223372036854775807,
		0.0,
		25.0,
		-25.5,
		"-25",
		"0",
		true,
		false,
		null,
		INF,
		-INF,
		NAN,
		[-25],
		{"candle": -25},
	]
	for index in range(bad_paid_candle_deltas.size()):
		var bad_delta: Variant = bad_paid_candle_deltas[index]
		for target_mode in ["party", "hero"]:
			var broken_choice := _choice(
				"broken_delta",
				"Invalid paid candle delta.",
				_paid_wick_effect(bad_delta, -25, true, target_mode, "seamstress")
			)
			var svc := RunStitchedEventConsequence.new(_event([
				broken_choice,
				_choice("pay_wick", "Valid paid wick.", _paid_wick_effect(-25, -25, true, "party")),
				_choice("leave", "Leave.", _effect(0, 0, "party")),
			]))
			var prev := svc.preview(snap_40)
			var broken_entry := _entry(prev, "broken_delta")
			_check(prev.get("ok") == true
				and broken_entry.get("available") == false
				and broken_entry.get("candle_delta") == null
				and broken_entry.get("fray_delta") == null
				and broken_entry.get("candle") == 40
				and broken_entry.get("fray") == {}
				and _entry(prev, "pay_wick").get("available") == true,
				"AC3: invalid paid candle delta %d (%s) is malformed with null deltas while valid sibling stays available" % [
					index, target_mode,
				])
			_assert_rejected(svc, "broken_delta", snap_40, 40,
				"AC3: invalid paid candle delta %d (%s) commit" % [index, target_mode])
			var valid_rec := svc.choose("pay_wick", snap_40)
			_check(valid_rec.get("ok") == true and valid_rec.get("candle") == 15,
				"AC3: valid paid-wick sibling claims after invalid paid delta %d (%s)" % [index, target_mode])

	# JSON parsers produce finite integral floats for negative deltas; verify -25.0 is valid:
	for float_delta in [-25.0, -1.0]:
		var json_choice := _choice("json_wick", "JSON float wick.", _paid_wick_effect(float_delta, -25, true, "party"))
		var json_svc := RunStitchedEventConsequence.new(_event([json_choice, _choice("leave", "Leave.", _effect(0, 0, "party"))]))
		var json_prev := json_svc.preview(snap_40)
		_check(json_prev.get("ok") == true and _entry(json_prev, "json_wick").get("available") == true,
			"AC3: integral float candle delta %s from JSON is valid" % str(float_delta))
		var json_rec := json_svc.choose("json_wick", snap_40)
		_check(json_rec.get("ok") == true and json_rec.get("candle") == 40 + int(float_delta),
			"AC3: integral float candle delta %s from JSON claims correctly" % str(float_delta))

	# 4. AC3: Structural errors alongside require_full_candle, forged choice IDs, and malformed snapshots:
	var structural_broken: Array = [
		{"id": "broken", "text": "Party with hero_id and require_full_candle.", "stitched_effect": {
			"candle": -25, "fray": -25, "target": "party",
			"hero_id": "warden", "require_full_candle": true,
		}},
		{"id": "broken", "text": "Hero without hero_id and require_full_candle.", "stitched_effect": {
			"candle": -25, "fray": -25, "target": "hero",
			"require_full_candle": true,
		}},
		{"id": "broken", "text": "Unknown hero_id with require_full_candle.", "stitched_effect": {
			"candle": -25, "fray": -25, "target": "hero",
			"hero_id": "porcelain_doll", "require_full_candle": true,
		}},
		{"id": "broken", "text": "Absent required_hero with require_full_candle=false is malformed, not hidden.", "stitched_effect": {
			"candle": -25, "fray": -25, "target": "party",
			"required_hero": "lantern_monk", "require_full_candle": false,
		}},
		{"id": "broken", "text": "Absent required_hero with nonnegative paid delta is malformed, not hidden.", "stitched_effect": {
			"candle": 0, "fray": -25, "target": "party",
			"required_hero": "lantern_monk", "require_full_candle": true,
		}},
		{"id": "broken", "text": "Extra unknown key alongside require_full_candle.", "stitched_effect": {
			"candle": -25, "fray": -25, "target": "party",
			"require_full_candle": true, "extra": 1,
		}},
	]
	for index in range(structural_broken.size()):
		var svc := RunStitchedEventConsequence.new(_event([
			structural_broken[index],
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		]))
		var prev := svc.preview(snap_40)
		var broken_entry := _entry(prev, "broken")
		_check(_choice_ids(prev) == ["broken", "leave"]
			and broken_entry.get("available") == false
			and broken_entry.get("candle_delta") == null
			and broken_entry.get("fray_delta") == null,
			"AC3: structural malformed paid-wick choice %d is shown unavailable with null deltas" % index)
		_assert_rejected(svc, "broken", snap_40, 40,
			"AC3: structural malformed paid-wick choice %d commit" % index)
		_check(svc.choose("leave", snap_40).get("ok") == true,
			"AC3: Leave claims after structural malformed paid-wick choice %d" % index)

	var unoffered_svc := RunStitchedEventConsequence.new(_paid_wick_event())
	for forged_id in ["", " ", "bargain", "pay_wick ", " pay_wick", "PAY_WICK", 42, null, ["pay_wick"], {"id": "pay_wick"}]:
		_assert_rejected(unoffered_svc, forged_id, snap_40, 40,
			"AC3: forged choice id on paid-wick Event: " + str(forged_id))
	for bad_snap in [
		null,
		{},
		{"candle": -1, "party": [{"id": "warden", "fray": 80}]},
		{"candle": 101, "party": [{"id": "warden", "fray": 80}]},
		{"candle": 40, "party": []},
		{"candle": 40, "party": [{"id": "warden", "fray": 80}], "extra": 1},
	]:
		_check(unoffered_svc.preview(bad_snap) == _denied_preview(),
			"AC3: malformed snapshot denies paid-wick preflight")
		_assert_rejected(unoffered_svc, "pay_wick", bad_snap, 0,
			"AC3: malformed snapshot rejected on paid-wick commit")
	_check(unoffered_svc.choose("pay_wick", snap_40).get("ok") == true,
		"AC3: valid paid-wick choice still claims after forged-choice and malformed-snapshot refusals")

	_check(randi() == expected_rng,
		"AC3: paid-wick rejection checks never draw global RNG")
	_check(snap_40 == snap_40_original,
		"AC3: paid-wick rejection checks never mutate caller snapshot")


func _min_fray_confession_event() -> Dictionary:
	return _event([
		_choice("confess", "The Warden confesses a frayed oath by candlelight.", {
			"candle": -25,
			"fray": -25,
			"target": "hero",
			"hero_id": "warden",
			"min_fray": 100,
			"require_full_candle": true,
		}),
		_choice("leave", "Keep the oath unspoken.", _effect(0, 0, "party")),
	], "ev_stitched_fray_confession")


func _min_fray_party_event() -> Dictionary:
	return _event([
		_choice("seamstress_calm", "The frayed Seamstress re-threads every companion's hem.", {
			"candle": 0,
			"fray": -10,
			"target": "party",
			"required_hero": "seamstress",
			"min_fray": 100,
		}),
		_choice("leave", "Leave the hems as they are.", _effect(0, 0, "party")),
	], "ev_stitched_seamstress_fray_relief")


func _min_fray_party_any_event() -> Dictionary:
	return _event([
		_choice("party_calm", "Calm the frayed company.", {
			"candle": 0,
			"fray": -25,
			"target": "party",
			"min_fray": 100,
		}),
		_choice("party_wick", "Spend wick to rally frayed souls.", {
			"candle": -25,
			"fray": -25,
			"target": "party",
			"min_fray": 100,
			"require_full_candle": true,
		}),
		_choice("leave", "Leave the company as they are.", _effect(0, 0, "party")),
	], "ev_stitched_party_fray_relief")


func _test_min_fray_gates() -> void:
	var expected_preview_keys := [
		"available", "candle", "candle_delta", "choice_id",
		"fray", "fray_delta", "hero_id", "target",
	]
	var expected_receipt_keys := [
		"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target",
	]

	seed(20261117)
	var expected_rng := randi()
	seed(20261117)

	# --- AC1: Hero-targeted min_fray: 100 inclusive gate (99 vs 100 vs 200) and paid candle (40 vs 24) ---
	var confess_event := _min_fray_confession_event()
	var confess_event_original := confess_event.duplicate(true)
	var snap_warden_100 := _four(40, [100, 30, 50, 10])
	var snap_warden_100_original := snap_warden_100.duplicate(true)
	var snap_warden_200 := _four(40, [200, 30, 50, 10])
	var snap_warden_99 := _four(40, [99, 200, 200, 200])
	var snap_warden_99_original := snap_warden_99.duplicate(true)
	var snap_candle_24 := _four(24, [100, 30, 50, 10])
	var snap_candle_24_original := snap_candle_24.duplicate(true)

	# At 100 FRAY and candle 40: preview offers confess (candle 15, {"warden": -25}) and choose claims once
	var svc_100 := RunStitchedEventConsequence.new(confess_event)
	var prev_100 := svc_100.preview(snap_warden_100)
	_check(prev_100.get("ok") == true
		and prev_100.get("event_id") == "ev_stitched_fray_confession"
		and prev_100.get("candle") == 40
		and _choice_ids(prev_100) == ["confess", "leave"],
		"AC1: ev_stitched_fray_confession preflights at FRAY 100 and candle 40")
	var confess_entry_100 := _entry(prev_100, "confess")
	_check(confess_entry_100.get("available") == true
		and confess_entry_100.get("target") == "hero"
		and confess_entry_100.get("hero_id") == "warden"
		and confess_entry_100.get("candle_delta") == -25
		and confess_entry_100.get("fray_delta") == -25
		and confess_entry_100.get("candle") == 15
		and confess_entry_100.get("fray") == {"warden": -25}
		and _receipt_keys(confess_entry_100) == expected_preview_keys,
		"AC1: at FRAY 100 and candle 40, confess is available and previews candle 15, {warden:-25}, and 8-key shape")
	var rec_100 := svc_100.choose("confess", snap_warden_100)
	_check(rec_100.get("ok") == true
		and rec_100.get("event_id") == "ev_stitched_fray_confession"
		and rec_100.get("choice_id") == "confess"
		and rec_100.get("target") == "hero"
		and rec_100.get("hero_id") == "warden"
		and rec_100.get("candle") == 15
		and rec_100.get("fray") == {"warden": -25}
		and _receipt_keys(rec_100) == expected_receipt_keys,
		"AC1: at FRAY 100 and candle 40, choose(confess) returns candle 15, {warden:-25}, and 7-key receipt")
	_check(svc_100.is_claimed() and not svc_100.is_valid(),
		"AC1: choose(confess) at FRAY 100 latches the visit")
	_assert_rejected(svc_100, "confess", snap_warden_100, 40,
		"AC1: duplicate claim after confess success is rejected")
	_assert_rejected(svc_100, "leave", snap_warden_100, 40,
		"AC1: Leave after confess claim is rejected")
	_check(svc_100.preview(snap_warden_100) == _denied_preview(),
		"AC1: claimed min_fray visit denies preflight")

	# At 200 FRAY and candle 40: also admitted and returns raw {"warden": -25} intent
	var svc_200 := RunStitchedEventConsequence.new(confess_event)
	var prev_200 := svc_200.preview(snap_warden_200)
	_check(_entry(prev_200, "confess").get("available") == true
		and _entry(prev_200, "confess").get("candle") == 15
		and _entry(prev_200, "confess").get("fray") == {"warden": -25},
		"AC1: at FRAY 200 and candle 40, confess is available with candle 15 and {warden:-25}")
	var rec_200 := svc_200.choose("confess", snap_warden_200)
	_check(rec_200.get("ok") == true
		and rec_200.get("candle") == 15
		and rec_200.get("fray") == {"warden": -25},
		"AC1: at FRAY 200 and candle 40, choose(confess) commits once")
	_assert_rejected(svc_200, "confess", snap_warden_200, 40,
		"AC1: replay after FRAY 200 claim is rejected")

	# At 99 FRAY (even with companions at 200) and candle 40: visible but unavailable; choose refuses without latching;
	# a later valid snapshot (FRAY 100) succeeds on the same unclaimed service instance, and Leave works on another instance
	var svc_99_retry := RunStitchedEventConsequence.new(confess_event)
	var prev_99 := svc_99_retry.preview(snap_warden_99)
	_check(_choice_ids(prev_99) == ["confess", "leave"],
		"AC1: at FRAY 99, hero-targeted min_fray choice stays visible in preview")
	var confess_entry_99 := _entry(prev_99, "confess")
	_check(confess_entry_99.get("available") == false
		and confess_entry_99.get("candle_delta") == -25
		and confess_entry_99.get("fray_delta") == -25
		and confess_entry_99.get("candle") == 40
		and confess_entry_99.get("fray") == {}
		and _receipt_keys(confess_entry_99) == expected_preview_keys,
		"AC1: at FRAY 99, confess is unavailable with base candle 40, empty fray, and 8-key shape")
	_assert_rejected(svc_99_retry, "confess", snap_warden_99, 40,
		"AC1: at FRAY 99, choose(confess) refuses without latching")
	_check(not svc_99_retry.is_claimed() and svc_99_retry.is_valid(),
		"AC1: refused FRAY 99 claim leaves service unclaimed")
	var rec_after_99 := svc_99_retry.choose("confess", snap_warden_100)
	_check(rec_after_99.get("ok") == true
		and rec_after_99.get("candle") == 15
		and rec_after_99.get("fray") == {"warden": -25},
		"AC1: a later FRAY 100 snapshot succeeds on the same unclaimed service instance")
	_assert_rejected(svc_99_retry, "leave", snap_warden_100, 40,
		"AC1: replay rejected after retry claim")

	var svc_99_leave := RunStitchedEventConsequence.new(confess_event)
	_assert_rejected(svc_99_leave, "confess", snap_warden_99, 40,
		"AC1: FRAY 99 confess rejected before Leave fallback")
	var leave_rec_99 := svc_99_leave.choose("leave", snap_warden_99)
	_check(leave_rec_99.get("ok") == true
		and leave_rec_99.get("choice_id") == "leave"
		and leave_rec_99.get("candle") == 40
		and leave_rec_99.get("fray") == {}
		and _receipt_keys(leave_rec_99) == expected_receipt_keys,
		"AC1: Leave succeeds after FRAY 99 gate refusal")
	_assert_rejected(svc_99_leave, "leave", snap_warden_99, 40,
		"AC1: replay after Leave fallback is rejected")

	# At 100 FRAY and candle 24 (underfunded paid wick): unavailable and rejected without latching; Leave succeeds
	var svc_candle_24 := RunStitchedEventConsequence.new(confess_event)
	var prev_candle_24 := svc_candle_24.preview(snap_candle_24)
	var confess_entry_24 := _entry(prev_candle_24, "confess")
	_check(confess_entry_24.get("available") == false
		and confess_entry_24.get("candle_delta") == -25
		and confess_entry_24.get("fray_delta") == -25
		and confess_entry_24.get("candle") == 24
		and confess_entry_24.get("fray") == {}
		and _receipt_keys(confess_entry_24) == expected_preview_keys,
		"AC1: at FRAY 100 but candle 24, confess is unavailable due to require_full_candle")
	_assert_rejected(svc_candle_24, "confess", snap_candle_24, 24,
		"AC1: at FRAY 100 and candle 24, choose(confess) refuses without latching")
	var leave_rec_24 := svc_candle_24.choose("leave", snap_candle_24)
	_check(leave_rec_24.get("ok") == true and leave_rec_24.get("candle") == 24,
		"AC1: Leave succeeds after candle 24 refusal")

	# Boundary min_fray values 1 and 200, plus optional rewards (scraps, gold, part, hp) on hero-targeted min_fray:
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var hero_rewards_event := _event([
		_choice("min_one", "Requires fray 1.", {
			"candle": 10, "fray": -5, "target": "hero", "hero_id": "warden", "min_fray": 1,
		}),
		_choice("min_two_hundred", "Requires fray 200 with rewards.", {
			"candle": 10, "fray": -50, "target": "hero", "hero_id": "warden", "min_fray": 200,
			"scraps": 2, "gold": 5, "hp": 8,
			"part": {"id": "warden_head_pot_helm_bonk", "tier": 2},
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	var snap_0_199 := _gold_scraps_satchel_four(40, 4, 20, 3, [0, 200, 200, 200])
	var snap_1_199 := _gold_scraps_satchel_four(40, 4, 20, 3, [1, 200, 200, 200])
	var snap_200_full := _gold_scraps_satchel_four(40, 4, 20, 3, [200, 10, 10, 10])
	var svc_bounds := RunStitchedEventConsequence.new(hero_rewards_event, warden_catalog)
	var prev_0 := svc_bounds.preview(snap_0_199)
	_check(_entry(prev_0, "min_one").get("available") == false
		and _entry(prev_0, "min_two_hundred").get("available") == false
		and _entry(prev_0, "min_two_hundred").get("hp") == {}
		and _entry(prev_0, "min_two_hundred").get("scraps") == 4
		and _entry(prev_0, "min_two_hundred").get("gold") == 20
		and _entry(prev_0, "min_two_hundred").get("satchel_count") == 3,
		"AC1: min_fray 1 and 200 are unavailable at fray 0, leaving optional rewards unprojected")
	_check(_entry(svc_bounds.preview(snap_1_199), "min_one").get("available") == true
		and _entry(svc_bounds.preview(snap_1_199), "min_two_hundred").get("available") == false,
		"AC1: at fray 1, min_fray 1 is available while min_fray 200 remains unavailable")
	var prev_200_rewards := svc_bounds.preview(snap_200_full)
	var reward_entry := _entry(prev_200_rewards, "min_two_hundred")
	_check(reward_entry.get("available") == true
		and reward_entry.get("candle") == 50
		and reward_entry.get("fray") == {"warden": -50}
		and reward_entry.get("hp") == {"warden": 8}
		and reward_entry.get("scraps") == 6
		and reward_entry.get("gold") == 25
		and reward_entry.get("satchel_count") == 4,
		"AC1: at fray 200, min_fray 200 projects candle, fray, hp, scraps, gold and part")
	var reward_rec := svc_bounds.choose("min_two_hundred", snap_200_full)
	_check(reward_rec.get("ok") == true
		and reward_rec.get("fray") == {"warden": -50}
		and reward_rec.get("hp") == {"warden": 8}
		and reward_rec.get("scraps") == 6
		and reward_rec.get("gold") == 25
		and reward_rec.get("satchel_count") == 4,
		"AC1: choose(min_two_hundred) at fray 200 returns exact optional reward intents once")

	# --- AC2: Party-targeted min_fray with canonical required_hero (100 vs 99 vs absent) ---
	var party_event := _min_fray_party_event()
	var party_event_original := party_event.duplicate(true)
	var snap_seamstress_100 := _four(40, [10, 100, 20, 30])
	var snap_seamstress_100_original := snap_seamstress_100.duplicate(true)
	var snap_seamstress_200_alt := _snapshot(40, [
		["seamstress", 200], ["lantern_monk", 15], ["rag_duelist", 45], ["yarn_ranger", 80],
	])
	var snap_seamstress_99 := _four(40, [200, 99, 200, 200])
	var snap_seamstress_99_original := snap_seamstress_99.duplicate(true)
	var snap_seamstress_absent := _snapshot(40, [
		["warden", 200], ["tinker", 200], ["lantern_monk", 200], ["button_golem", 200],
	])
	var snap_seamstress_absent_original := snap_seamstress_absent.duplicate(true)

	# Seamstress at 100 FRAY: previews and claims -10 fray for the exact four active party heroes
	var svc_party_100 := RunStitchedEventConsequence.new(party_event)
	var prev_party_100 := svc_party_100.preview(snap_seamstress_100)
	_check(prev_party_100.get("ok") == true
		and _choice_ids(prev_party_100) == ["seamstress_calm", "leave"],
		"AC2: party min_fray choice is visible when required_hero seamstress is present at FRAY 100")
	var party_entry_100 := _entry(prev_party_100, "seamstress_calm")
	var expected_four_minus_10 := {
		"warden": -10, "seamstress": -10, "tinker": -10, "button_golem": -10,
	}
	_check(party_entry_100.get("available") == true
		and party_entry_100.get("target") == "party"
		and party_entry_100.get("hero_id") == ""
		and party_entry_100.get("candle_delta") == 0
		and party_entry_100.get("fray_delta") == -10
		and party_entry_100.get("candle") == 40
		and party_entry_100.get("fray") == expected_four_minus_10
		and (party_entry_100.get("fray") as Dictionary).size() == 4
		and _receipt_keys(party_entry_100) == expected_preview_keys,
		"AC2: when Seamstress is at FRAY 100, party choice previews -10 for the exact four active heroes")
	var rec_party_100 := svc_party_100.choose("seamstress_calm", snap_seamstress_100)
	_check(rec_party_100.get("ok") == true
		and rec_party_100.get("choice_id") == "seamstress_calm"
		and rec_party_100.get("target") == "party"
		and rec_party_100.get("hero_id") == ""
		and rec_party_100.get("candle") == 40
		and rec_party_100.get("fray") == expected_four_minus_10
		and _receipt_keys(rec_party_100) == expected_receipt_keys,
		"AC2: choose(seamstress_calm) at FRAY 100 returns -10 for the exact four active heroes")
	_assert_rejected(svc_party_100, "seamstress_calm", snap_seamstress_100, 40,
		"AC2: replay after party min_fray claim is rejected")

	# Alternate four-hero roster with Seamstress at FRAY 200: only those four present heroes receive -10
	var svc_party_alt := RunStitchedEventConsequence.new(party_event)
	var expected_alt_minus_10 := {
		"seamstress": -10, "lantern_monk": -10, "rag_duelist": -10, "yarn_ranger": -10,
	}
	var prev_party_alt := svc_party_alt.preview(snap_seamstress_200_alt)
	_check(_entry(prev_party_alt, "seamstress_calm").get("available") == true
		and _entry(prev_party_alt, "seamstress_calm").get("fray") == expected_alt_minus_10,
		"AC2: alternate party at Seamstress FRAY 200 previews -10 only for present heroes, never absent heroes")
	var rec_party_alt := svc_party_alt.choose("seamstress_calm", snap_seamstress_200_alt)
	_check(rec_party_alt.get("ok") == true and rec_party_alt.get("fray") == expected_alt_minus_10,
		"AC2: alternate party at Seamstress FRAY 200 claims -10 only for present heroes")

	# Seamstress present at FRAY 99 while companions are at 200: visible in slot as available:false (NOT hidden!),
	# refuses claim without latching, and allows retry with valid 100 snapshot or fallback Leave
	var svc_party_99 := RunStitchedEventConsequence.new(party_event)
	var prev_party_99 := svc_party_99.preview(snap_seamstress_99)
	_check(_choice_ids(prev_party_99) == ["seamstress_calm", "leave"],
		"AC2: with required_hero Seamstress present at FRAY 99, choice slot is preserved (not hidden)")
	var party_entry_99 := _entry(prev_party_99, "seamstress_calm")
	_check(party_entry_99.get("available") == false
		and party_entry_99.get("candle_delta") == 0
		and party_entry_99.get("fray_delta") == -10
		and party_entry_99.get("candle") == 40
		and party_entry_99.get("fray") == {}
		and _receipt_keys(party_entry_99) == expected_preview_keys,
		"AC2: companions at FRAY 200 do not qualify when Seamstress is at FRAY 99; preview is available:false with empty fray")
	_assert_rejected(svc_party_99, "seamstress_calm", snap_seamstress_99, 40,
		"AC2: choose(seamstress_calm) at Seamstress FRAY 99 is refused without latching")
	var party_retry_rec := svc_party_99.choose("seamstress_calm", snap_seamstress_100)
	_check(party_retry_rec.get("ok") == true and party_retry_rec.get("fray") == expected_four_minus_10,
		"AC2: same unclaimed party service instance succeeds when retried with Seamstress at FRAY 100")

	var svc_party_99_leave := RunStitchedEventConsequence.new(party_event)
	_assert_rejected(svc_party_99_leave, "seamstress_calm", snap_seamstress_99, 40,
		"AC2: Seamstress FRAY 99 rejected before Leave")
	_check(svc_party_99_leave.choose("leave", snap_seamstress_99).get("ok") == true,
		"AC2: Leave claims after Seamstress FRAY 99 refusal")

	# Seamstress absent from party (even with all 4 present heroes at 200): hidden in preview and refused in choose
	var svc_party_absent := RunStitchedEventConsequence.new(party_event)
	var prev_party_absent := svc_party_absent.preview(snap_seamstress_absent)
	_check(_choice_ids(prev_party_absent) == ["leave"]
		and _entry(prev_party_absent, "seamstress_calm") == {},
		"AC2: when required_hero Seamstress is absent, party min_fray choice is hidden from preview.choices")
	_assert_rejected(svc_party_absent, "seamstress_calm", snap_seamstress_absent, 40,
		"AC2: forged claim of hidden party min_fray choice is refused without latching")
	var absent_leave_rec := svc_party_absent.choose("leave", snap_seamstress_absent)
	_check(absent_leave_rec.get("ok") == true and absent_leave_rec.get("candle") == 40,
		"AC2: Leave still claims after hidden party min_fray refusal")

	# --- AC1/AC2/AC3: Party-targeted min_fray for ANY active frayed hero (no required_hero) ---
	var party_any_event := _min_fray_party_any_event()
	var party_any_original := party_any_event.duplicate(true)
	var snap_any_100 := _four(40, [0, 99, 100, 200])
	var snap_any_100_original := snap_any_100.duplicate(true)
	var snap_any_99 := _four(40, [0, 99, 99, 0])
	var snap_any_99_original := snap_any_99.duplicate(true)

	# Eligible [0, 99, 100, 200]: preview marks available, projects -25 for all four active heroes; choose latches once
	var svc_any := RunStitchedEventConsequence.new(party_any_event)
	var prev_any_100 := svc_any.preview(snap_any_100)
	_check(prev_any_100.get("ok") == true
		and _choice_ids(prev_any_100) == ["party_calm", "party_wick", "leave"],
		"AC1: party min_fray without required_hero is schema-valid and visible in authored order")

	var calm_entry_100 := _entry(prev_any_100, "party_calm")
	var expected_four_minus_25 := {
		"warden": -25, "seamstress": -25, "tinker": -25, "button_golem": -25,
	}
	_check(calm_entry_100.get("available") == true
		and calm_entry_100.get("target") == "party"
		and calm_entry_100.get("hero_id") == ""
		and calm_entry_100.get("candle_delta") == 0
		and calm_entry_100.get("fray_delta") == -25
		and calm_entry_100.get("candle") == 40
		and calm_entry_100.get("fray") == expected_four_minus_25
		and _receipt_keys(calm_entry_100) == expected_preview_keys,
		"AC1: party min_fray:100 is available for [0,99,100,200] and projects -25 for all four heroes")

	var rec_any_100 := svc_any.choose("party_calm", snap_any_100)
	_check(rec_any_100.get("ok") == true
		and rec_any_100.get("event_id") == "ev_stitched_party_fray_relief"
		and rec_any_100.get("choice_id") == "party_calm"
		and rec_any_100.get("target") == "party"
		and rec_any_100.get("hero_id") == ""
		and rec_any_100.get("candle") == 40
		and rec_any_100.get("fray") == expected_four_minus_25
		and _receipt_keys(rec_any_100) == expected_receipt_keys,
		"AC2: choose(party_calm) emits exactly four raw fray intents {-25} and preserves candle 40")
	_check(svc_any.is_claimed() and not svc_any.is_valid(),
		"AC2: choose(party_calm) latches the visit once")
	_assert_rejected(svc_any, "party_calm", snap_any_100, 40,
		"AC2: replay after party_calm claim is rejected")
	_assert_rejected(svc_any, "leave", snap_any_100, 40,
		"AC2: leave after party_calm claim is rejected")
	_check(svc_any.preview(snap_any_100) == _denied_preview(),
		"AC2: preflight after claim is denied")

	# Ineligible [0, 99, 99, 0]: available:false, parsed deltas, empty fray map; choose refused without latching
	var svc_any_refuse := RunStitchedEventConsequence.new(party_any_event)
	var prev_any_99 := svc_any_refuse.preview(snap_any_99)
	_check(_choice_ids(prev_any_99) == ["party_calm", "party_wick", "leave"],
		"AC1: with all heroes below threshold [0,99,99,0], choices remain visible in authored slots")
	var calm_entry_99 := _entry(prev_any_99, "party_calm")
	_check(calm_entry_99.get("available") == false
		and calm_entry_99.get("candle_delta") == 0
		and calm_entry_99.get("fray_delta") == -25
		and calm_entry_99.get("candle") == 40
		and calm_entry_99.get("fray") == {}
		and _receipt_keys(calm_entry_99) == expected_preview_keys,
		"AC1: party min_fray:100 is unavailable for [0,99,99,0] with parsed deltas and empty fray")

	_assert_rejected(svc_any_refuse, "party_calm", snap_any_99, 40,
		"AC2: choose(party_calm) at [0,99,99,0] is refused without latching")
	_check(not svc_any_refuse.is_claimed() and svc_any_refuse.is_valid(),
		"AC2: refused party_calm leaves service valid and unclaimed")

	# Retry with qualifying snapshot succeeds on same unclaimed instance:
	var rec_any_retry := svc_any_refuse.choose("party_calm", snap_any_100)
	_check(rec_any_retry.get("ok") == true and rec_any_retry.get("fray") == expected_four_minus_25,
		"AC2: retry with qualifying snapshot succeeds on same unclaimed instance")

	# Fallback Leave on another instance:
	var svc_any_leave := RunStitchedEventConsequence.new(party_any_event)
	_assert_rejected(svc_any_leave, "party_calm", snap_any_99, 40,
		"AC2: party_calm refused before Leave")
	var rec_any_leave := svc_any_leave.choose("leave", snap_any_99)
	_check(rec_any_leave.get("ok") == true
		and rec_any_leave.get("choice_id") == "leave"
		and rec_any_leave.get("candle") == 40
		and rec_any_leave.get("fray") == {},
		"AC2: Leave succeeds after party_calm refusal")

	# Thresholds 1 (0 vs 1), 100 (99 vs 100), 200 (199 vs 200) across all array/rank positions:
	var bound_event_1_100 := _event([
		_choice("gate_1", "Min fray 1.", {"candle": 0, "fray": -5, "target": "party", "min_fray": 1}),
		_choice("gate_100", "Min fray 100.", {"candle": 0, "fray": -10, "target": "party", "min_fray": 100}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_party_bounds_1_100")

	var bound_event_200 := _event([
		_choice("gate_200", "Min fray 200.", {"candle": 0, "fray": -20, "target": "party", "min_fray": 200}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_party_bounds_200")

	# All at 0: all gates unavailable
	var snap_all_0 := _four(50, [0, 0, 0, 0])
	var prev_all_0_a := RunStitchedEventConsequence.new(bound_event_1_100).preview(snap_all_0)
	var prev_all_0_b := RunStitchedEventConsequence.new(bound_event_200).preview(snap_all_0)
	_check(_entry(prev_all_0_a, "gate_1").get("available") == false
		and _entry(prev_all_0_a, "gate_100").get("available") == false
		and _entry(prev_all_0_b, "gate_200").get("available") == false,
		"AC1: at fray [0,0,0,0], min_fray 1, 100, 200 are all unavailable")

	# For each position 0..3: frayed hero at threshold 1 qualifies gate_1 while 0 does not
	for pos in range(4):
		var frays_1 := [0, 0, 0, 0]
		frays_1[pos] = 1
		var snap_pos_1 := _four(50, frays_1)
		var prev_pos_1 := RunStitchedEventConsequence.new(bound_event_1_100).preview(snap_pos_1)
		_check(_entry(prev_pos_1, "gate_1").get("available") == true
			and _entry(prev_pos_1, "gate_100").get("available") == false,
			"AC1: frayed hero at fray 1 at position %d qualifies min_fray:1" % pos)

	# All at 99: min_fray 100 unavailable
	var snap_all_99 := _four(50, [99, 99, 99, 99])
	var prev_all_99 := RunStitchedEventConsequence.new(bound_event_1_100).preview(snap_all_99)
	_check(_entry(prev_all_99, "gate_1").get("available") == true
		and _entry(prev_all_99, "gate_100").get("available") == false,
		"AC1: at fray [99,99,99,99], min_fray:100 is unavailable")

	# For each position 0..3: frayed hero at threshold 100 qualifies gate_100 while 99 does not
	for pos in range(4):
		var frays_100 := [99, 99, 99, 99]
		frays_100[pos] = 100
		var snap_pos_100 := _four(50, frays_100)
		var prev_pos_100 := RunStitchedEventConsequence.new(bound_event_1_100).preview(snap_pos_100)
		_check(_entry(prev_pos_100, "gate_1").get("available") == true
			and _entry(prev_pos_100, "gate_100").get("available") == true,
			"AC1: frayed hero at fray 100 at position %d qualifies min_fray:100" % pos)

	# All at 199: min_fray 200 unavailable
	var snap_all_199 := _four(50, [199, 199, 199, 199])
	var prev_all_199 := RunStitchedEventConsequence.new(bound_event_200).preview(snap_all_199)
	_check(_entry(prev_all_199, "gate_200").get("available") == false,
		"AC1: at fray [199,199,199,199], min_fray:200 is unavailable")

	# For each position 0..3: frayed hero at threshold 200 qualifies gate_200 while 199 does not
	for pos in range(4):
		var frays_200 := [199, 199, 199, 199]
		frays_200[pos] = 200
		var snap_pos_200 := _four(50, frays_200)
		var prev_pos_200 := RunStitchedEventConsequence.new(bound_event_200).preview(snap_pos_200)
		_check(_entry(prev_pos_200, "gate_200").get("available") == true,
			"AC1: frayed hero at fray 200 at position %d qualifies min_fray:200" % pos)

	# Smaller active party (e.g. 2 heroes after losses):
	var snap_two_heroes := _snapshot(40, [["warden", 0], ["seamstress", 100]])
	var svc_two := RunStitchedEventConsequence.new(party_any_event)
	var prev_two := svc_two.preview(snap_two_heroes)
	_check(_entry(prev_two, "party_calm").get("available") == true
		and _entry(prev_two, "party_calm").get("fray") == {"warden": -25, "seamstress": -25},
		"AC1: party min_fray works with 2-hero active party when one qualifies")
	var rec_two := svc_two.choose("party_calm", snap_two_heroes)
	_check(rec_two.get("ok") == true and rec_two.get("fray") == {"warden": -25, "seamstress": -25},
		"AC2: choose(party_calm) with 2-hero party emits exactly two fray intents")

	# AC3: Paid candle combination with any-member gate (require_full_candle: true, candle: -25, min_fray: 100)
	var snap_candle_25_qual := _four(25, [0, 99, 100, 200])
	var snap_candle_24_qual := _four(24, [0, 99, 100, 200])
	var snap_candle_100_no_fray := _four(100, [0, 99, 99, 0])
	var snap_candle_24_no_fray := _four(24, [0, 99, 99, 0])

	# Exactly 25 candle + qualifying fray: preview available, candle projected 25 - 25 = 0, choose succeeds
	var svc_wick_25 := RunStitchedEventConsequence.new(party_any_event)
	var prev_wick_25 := svc_wick_25.preview(snap_candle_25_qual)
	var entry_wick_25 := _entry(prev_wick_25, "party_wick")
	_check(entry_wick_25.get("available") == true
		and entry_wick_25.get("candle_delta") == -25
		and entry_wick_25.get("fray_delta") == -25
		and entry_wick_25.get("candle") == 0
		and entry_wick_25.get("fray") == expected_four_minus_25,
		"AC3: party min_fray:100 with require_full_candle:true succeeds at exactly candle 25")
	var rec_wick_25 := svc_wick_25.choose("party_wick", snap_candle_25_qual)
	_check(rec_wick_25.get("ok") == true
		and rec_wick_25.get("candle") == 0
		and rec_wick_25.get("fray") == expected_four_minus_25,
		"AC3: choose(party_wick) at candle 25 commits once with candle 0")

	# 24 candle with qualifying fray: preview available:false, choose refused with unchanged candle 24
	var svc_wick_24 := RunStitchedEventConsequence.new(party_any_event)
	var prev_wick_24 := svc_wick_24.preview(snap_candle_24_qual)
	var entry_wick_24 := _entry(prev_wick_24, "party_wick")
	_check(entry_wick_24.get("available") == false
		and entry_wick_24.get("candle_delta") == -25
		and entry_wick_24.get("candle") == 24
		and entry_wick_24.get("fray") == {},
		"AC3: candle 24 is unavailable even with qualifying fray due to require_full_candle")
	_assert_rejected(svc_wick_24, "party_wick", snap_candle_24_qual, 24,
		"AC3: choose(party_wick) at candle 24 refused without latching")
	_check(svc_wick_24.choose("leave", snap_candle_24_qual).get("ok") == true,
		"AC3: Leave succeeds after candle 24 refusal")

	# 100 candle with non-qualifying fray [0,99,99,0]: preview available:false, choose refused
	var svc_wick_100_no_fray := RunStitchedEventConsequence.new(party_any_event)
	var prev_wick_100 := svc_wick_100_no_fray.preview(snap_candle_100_no_fray)
	var entry_wick_100 := _entry(prev_wick_100, "party_wick")
	_check(entry_wick_100.get("available") == false
		and entry_wick_100.get("candle") == 100
		and entry_wick_100.get("fray") == {},
		"AC3: funded party (candle 100) with no qualifying fray cannot buy party_wick")
	_assert_rejected(svc_wick_100_no_fray, "party_wick", snap_candle_100_no_fray, 100,
		"AC3: choose(party_wick) with no qualifying fray refused at candle 100")
	_check(svc_wick_100_no_fray.choose("leave", snap_candle_100_no_fray).get("ok") == true,
		"AC3: Leave succeeds after non-qualifying fray refusal at candle 100")

	# 24 candle with non-qualifying fray: both fail, refused
	var svc_wick_24_no_fray := RunStitchedEventConsequence.new(party_any_event)
	_assert_rejected(svc_wick_24_no_fray, "party_wick", snap_candle_24_no_fray, 24,
		"AC3: choose(party_wick) refused when both candle and fray fail")

	# AC3: Optional rewards combination (scraps, gold, part, hp) on party-any gate:
	var party_rewards_event := _event([
		_choice("rally", "Rally the frayed band.", {
			"candle": 10,
			"fray": -25,
			"target": "party",
			"min_fray": 100,
			"scraps": 3,
			"gold": 5,
			"hp": 4,
			"part": {"id": "warden_head_pot_helm_bonk", "tier": 2},
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_party_rewards")

	var snap_rewards_qual := _gold_scraps_satchel_four(40, 2, 10, 1, [0, 99, 100, 200])
	var snap_rewards_ineligible := _gold_scraps_satchel_four(40, 2, 10, 1, [0, 99, 99, 0])

	# Eligible: projects candle, fray, scraps, gold, satchel_count, hp
	var svc_rewards := RunStitchedEventConsequence.new(party_rewards_event, warden_catalog)
	var prev_rewards := svc_rewards.preview(snap_rewards_qual)
	var rally_entry := _entry(prev_rewards, "rally")
	var expected_four_hp := {
		"warden": 4, "seamstress": 4, "tinker": 4, "button_golem": 4,
	}
	_check(rally_entry.get("available") == true
		and rally_entry.get("candle") == 50
		and rally_entry.get("fray") == expected_four_minus_25
		and rally_entry.get("hp") == expected_four_hp
		and rally_entry.get("scraps") == 5
		and rally_entry.get("gold") == 15
		and rally_entry.get("satchel_count") == 2,
		"AC3: party min_fray projects optional scraps, gold, part, and party hp intents")
	var rec_rewards := svc_rewards.choose("rally", snap_rewards_qual)
	_check(rec_rewards.get("ok") == true
		and rec_rewards.get("candle") == 50
		and rec_rewards.get("fray") == expected_four_minus_25
		and rec_rewards.get("hp") == expected_four_hp
		and rec_rewards.get("scraps") == 5
		and rec_rewards.get("gold") == 15
		and rec_rewards.get("satchel_count") == 2,
		"AC3: choose(rally) returns exact optional scraps, gold, part and hp receipts")

	# Ineligible: available:false, rewards unprojected, wallet/satchel unchanged on refusal
	var svc_rewards_ineligible := RunStitchedEventConsequence.new(party_rewards_event, warden_catalog)
	var prev_rewards_ineligible := svc_rewards_ineligible.preview(snap_rewards_ineligible)
	var rally_ineligible := _entry(prev_rewards_ineligible, "rally")
	_check(rally_ineligible.get("available") == false
		and rally_ineligible.get("candle") == 40
		and rally_ineligible.get("fray") == {}
		and rally_ineligible.get("hp") == {}
		and rally_ineligible.get("scraps") == 2
		and rally_ineligible.get("gold") == 10
		and rally_ineligible.get("satchel_count") == 1,
		"AC3: party min_fray ineligible leaves rewards unprojected and base balances unchanged")
	_assert_rejected(svc_rewards_ineligible, "rally", snap_rewards_ineligible, 40,
		"AC3: choose(rally) refused when party is ineligible")

	# --- AC4: Malformed min_fray values, structural invalid gates, and extra keys fail closed ---
	var malformed_min_frays: Array = [0, -1, -100, 201, 999, 100.0, 1.5, true, false, "100", "", null, [100], {"min_fray": 100}]
	for idx in range(malformed_min_frays.size()):
		var bad_val: Variant = malformed_min_frays[idx]
		for target_mode in ["hero", "party"]:
			var bad_effect := {
				"candle": -10,
				"fray": -10,
				"target": target_mode,
				"min_fray": bad_val,
			}
			if target_mode == "hero":
				bad_effect["hero_id"] = "warden"
			else:
				bad_effect["required_hero"] = "seamstress"
			var bad_event := _event([
				_choice("bad_gate", "Malformed min_fray.", bad_effect),
				_choice("valid_alt", "Valid alternative.", _effect(5, -5, "party")),
				_choice("leave", "Leave.", _effect(0, 0, "party")),
			])
			var bad_svc := RunStitchedEventConsequence.new(bad_event)
			var bad_prev := bad_svc.preview(snap_seamstress_100)
			var bad_entry := _entry(bad_prev, "bad_gate")
			_check(bad_prev.get("ok") == true
				and _choice_ids(bad_prev) == ["bad_gate", "valid_alt", "leave"]
				and bad_entry.get("available") == false
				and bad_entry.get("candle_delta") == null
				and bad_entry.get("fray_delta") == null
				and bad_entry.get("candle") == 40
				and bad_entry.get("fray") == {}
				and _entry(bad_prev, "valid_alt").get("available") == true
				and _entry(bad_prev, "leave").get("available") == true,
				"AC3: malformed min_fray %d (%s) is unavailable with null deltas while siblings remain available" % [
					idx, target_mode,
				])
			_assert_rejected(bad_svc, "bad_gate", snap_seamstress_100, 40,
				"AC3: malformed min_fray %d (%s) commit" % [idx, target_mode])
			var fallback_choice := "leave" if (idx % 2 == 0) else "valid_alt"
			_check(bad_svc.choose(fallback_choice, snap_seamstress_100).get("ok") == true,
				"AC3: %s claims after malformed min_fray %d (%s) refusal" % [fallback_choice, idx, target_mode])

	# Structural malformed cases with min_fray: unknown hero, unexpected extra keys, missing required fields:
	var structural_bad_effects: Array = [
		{"candle": 0, "fray": -10, "target": "party", "min_fray": 100, "extra": 1},
		{"candle": -25, "fray": -25, "target": "party", "min_fray": 100, "require_full_candle": true, "bogus": true},
		{"candle": 0, "fray": -10, "target": "party", "min_fray": 100, "hero_id": "warden"},
		{"candle": 0, "fray": -10, "target": "party", "required_hero": "porcelain_doll", "min_fray": 100},
		{"candle": 0, "fray": -10, "target": "party", "required_hero": "seamstress", "min_fray": 100, "extra": 1},
		{"candle": -25, "fray": -25, "target": "hero", "hero_id": "warden", "min_fray": 100, "extra": 1},
		{"candle": 0, "fray": -10, "target": "hero", "min_fray": 100},
	]
	for idx in range(structural_bad_effects.size()):
		var bad_svc := RunStitchedEventConsequence.new(_event([
			_choice("bad_struct", "Malformed gate structure.", structural_bad_effects[idx]),
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		]))
		var bad_prev := bad_svc.preview(snap_warden_99)
		var bad_entry := _entry(bad_prev, "bad_struct")
		_check(_choice_ids(bad_prev) == ["bad_struct", "leave"]
			and bad_entry.get("available") == false
			and bad_entry.get("candle_delta") == null
			and bad_entry.get("fray_delta") == null
			and bad_entry.get("candle") == 40
			and bad_entry.get("fray") == {}
			and _entry(bad_prev, "leave").get("available") == true,
			"AC3: structural bad min_fray %d is malformed with null deltas and leaves Leave available" % idx)
		_assert_rejected(bad_svc, "bad_struct", snap_warden_99, 40,
			"AC3: structural bad min_fray %d commit" % idx)
		_check(bad_svc.choose("leave", snap_warden_99).get("ok") == true,
			"AC3: Leave claims after structural bad min_fray %d refusal" % idx)

	# Clone/detachment and untouched global RNG verification:
	confess_entry_100["fray"]["warden"] = 999
	rec_100["fray"]["warden"] = -999
	party_entry_100["fray"]["seamstress"] = 888
	rec_party_100["fray"]["seamstress"] = -888
	_check(confess_event == confess_event_original
		and party_event == party_event_original
		and party_any_event == party_any_original
		and snap_warden_100 == snap_warden_100_original
		and snap_warden_99 == snap_warden_99_original
		and snap_candle_24 == snap_candle_24_original
		and snap_seamstress_100 == snap_seamstress_100_original
		and snap_seamstress_99 == snap_seamstress_99_original
		and snap_seamstress_absent == snap_seamstress_absent_original
		and snap_any_100 == snap_any_100_original
		and snap_any_99 == snap_any_99_original,
		"AC1/AC2/AC3/AC4: min_fray previews, claims and rejections never mutate caller snapshots or events")
	_check(randi() == expected_rng,
		"AC1/AC2/AC3: min_fray checks never draw from the seeded global RNG")


func _test_candle_band_gates() -> void:
	var warden_catalog := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	var catalog_original := warden_catalog.duplicate(true)
	_check(bool(warden_catalog.get("ok", false)), "AC1: loads valid warden catalog for band tests")

	var all_bands := ["snuffed", "dark", "gloom", "dim", "bright"]
	var boundary_candles := [0, 1, 25, 26, 50, 51, 75, 76, 100]

	# AC1/AC2: Matrix test of all 9 boundaries x 5 band names for party target and hero target
	for c in boundary_candles:
		var expected_band := ""
		if c == 0:
			expected_band = "snuffed"
		elif c <= 25:
			expected_band = "dark"
		elif c <= 50:
			expected_band = "gloom"
		elif c <= 75:
			expected_band = "dim"
		else:
			expected_band = "bright"

		var snap_party := _four(c, [10, 20, 30, 40])
		var snap_hero := _four(c, [10, 20, 30, 40])

		for target_mode in ["party", "hero"]:
			for band_name in all_bands:
				var is_match: bool = (band_name == expected_band)
				var eff := {
					"candle": 10,
					"fray": -10,
					"target": target_mode,
					"required_candle_band": band_name,
				}
				if target_mode == "hero":
					eff["hero_id"] = "warden"

				var ev := _event([
					_choice("band_trade", "Band trade.", eff),
					_choice("leave", "Leave.", _effect(0, 0, "party")),
				], "ev_band_%s_%d_%s" % [target_mode, c, band_name])

				var svc := RunStitchedEventConsequence.new(ev)
				var snap := snap_party if target_mode == "party" else snap_hero
				var snap_copy := snap.duplicate(true)
				var prev := svc.preview(snap)
				var entry := _entry(prev, "band_trade")

				_check(prev.get("ok") == true,
					"AC1: preview ok for candle %d, band %s, target %s" % [c, band_name, target_mode])
				_check(entry.get("choice_id") == "band_trade",
					"AC1: choice slot kept for candle %d, band %s, target %s" % [c, band_name, target_mode])
				_check(entry.get("candle_delta") == 10 and entry.get("fray_delta") == -10,
					"AC1: parsed deltas preserved for candle %d, band %s, target %s" % [c, band_name, target_mode])

				var expected_candle: int = 100 if c + 10 > 100 else c + 10
				if not is_match:
					expected_candle = c
				var expected_fray: Dictionary = {}
				if is_match:
					if target_mode == "party":
						expected_fray = {"warden": -10, "seamstress": -10, "tinker": -10, "button_golem": -10}
					else:
						expected_fray = {"warden": -10}

				_check(entry.get("available") == is_match,
					"AC1: available == %s for candle %d, band %s (expected %s), target %s" % [
						str(is_match), c, band_name, expected_band, target_mode
					])
				_check(entry.get("candle") == expected_candle,
					"AC1: projected candle == %d for candle %d, band %s, target %s" % [
						expected_candle, c, band_name, target_mode
					])
				_check(entry.get("fray") == expected_fray,
					"AC1: projected fray matches for candle %d, band %s, target %s" % [
						c, band_name, target_mode
					])

				# AC2: choose() behavior
				if is_match:
					var rec := svc.choose("band_trade", snap)
					_check(rec.get("ok") == true
						and rec.get("candle") == expected_candle
						and rec.get("fray") == expected_fray
						and rec.get("target") == target_mode
						and (target_mode == "party" or rec.get("hero_id") == "warden"),
						"AC2: choose succeeds with matching receipt for candle %d, band %s, target %s" % [
							c, band_name, target_mode
						])
					_check(svc.is_claimed() == true and svc.is_valid() == false,
						"AC2: claim consumed once on matching choice")
					# Replay rejected
					_assert_rejected(svc, "band_trade", snap, c,
						"AC2: replay on consumed visit rejected")
				else:
					_assert_rejected(svc, "band_trade", snap, c,
						"AC2: choose rejected without latching for wrong band %s at candle %d" % [
							band_name, c
						])
					_check(svc.is_claimed() == false and svc.is_valid() == true,
						"AC2: unconsumed after rejection for wrong band %s" % band_name)
					_check(snap == snap_copy,
						"AC2: snapshot untouched after rejection for wrong band %s" % band_name)
					# Leave still possible after wrong band rejection
					var leave_rec := svc.choose("leave", snap)
					_check(leave_rec.get("ok") == true and leave_rec.get("candle") == c,
						"AC2: Leave succeeds on same visit after wrong-band refusal")
					_check(svc.is_claimed() == true, "AC2: Leave consumed visit latch")

	# AC1/AC2: Opening candle semantics for +25 gain at candle 25 (dark)
	# Opening candle 25 is dark. Even though 25 + 25 = 50 (gloom), dark qualifies and gloom fails.
	var gain_event := _event([
		_choice("gain_dark", "Gain light in dark.", {
			"candle": 25, "fray": -15, "target": "party", "required_candle_band": "dark",
		}),
		_choice("gain_gloom", "Gain light in gloom.", {
			"candle": 25, "fray": -15, "target": "party", "required_candle_band": "gloom",
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_gain_candle_25")

	var snap_25 := _four(25, [20, 20, 20, 20])
	var snap_25_orig := snap_25.duplicate(true)
	var gain_event_orig := gain_event.duplicate(true)

	var svc_gain := RunStitchedEventConsequence.new(gain_event)
	var prev_gain := svc_gain.preview(snap_25)
	var entry_gain_dark := _entry(prev_gain, "gain_dark")
	var entry_gain_gloom := _entry(prev_gain, "gain_gloom")

	_check(entry_gain_dark.get("available") == true
		and entry_gain_dark.get("candle") == 50
		and entry_gain_dark.get("candle_delta") == 25,
		"AC1: at opening candle 25, dark qualifies for +25 gain reaching gloom 50")
	_check(entry_gain_gloom.get("available") == false
		and entry_gain_gloom.get("candle") == 25
		and entry_gain_gloom.get("candle_delta") == 25
		and entry_gain_gloom.get("fray") == {},
		"AC1: at opening candle 25, gloom does NOT qualify even though end candle is 50")

	# Choose wrong band (gloom) then matching band (dark) on same visit with RNG check
	seed(1337)
	var rng_before := randi()
	seed(1337)

	_assert_rejected(svc_gain, "gain_gloom", snap_25, 25,
		"AC2: choosing gloom at candle 25 is refused without latching")
	_check(randi() == rng_before, "AC2: rejection never advances global RNG")
	seed(1337)

	var rec_gain_dark := svc_gain.choose("gain_dark", snap_25)
	_check(rec_gain_dark.get("ok") == true
		and rec_gain_dark.get("candle") == 50
		and rec_gain_dark.get("candle") == entry_gain_dark.get("candle")
		and rec_gain_dark.get("fray") == entry_gain_dark.get("fray"),
		"AC2: choose(gain_dark) succeeds on same visit with preview/receipt parity")
	_check(randi() == rng_before, "AC2: matching claim never advances global RNG")
	_check(snap_25 == snap_25_orig and gain_event == gain_event_orig,
		"AC2: deep input immutability preserved across preview, rejection and claim")

	# AC1/AC2: Negative paid-wick cost crossing a boundary (candle 51 dim -> 41 gloom)
	# Opening candle 51 is dim. Subtracting 10 reaches 41 (gloom). Dim qualifies; gloom fails.
	var wick_event := _event([
		_choice("burn_dim", "Spend wick in dim.", {
			"candle": -10, "fray": -20, "target": "party", "require_full_candle": true, "required_candle_band": "dim",
		}),
		_choice("burn_gloom", "Spend wick in gloom.", {
			"candle": -10, "fray": -20, "target": "party", "require_full_candle": true, "required_candle_band": "gloom",
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_wick_cross_51")

	var snap_51 := _four(51, [40, 40, 40, 40])
	var svc_wick := RunStitchedEventConsequence.new(wick_event)
	var prev_wick := svc_wick.preview(snap_51)
	var entry_burn_dim := _entry(prev_wick, "burn_dim")
	var entry_burn_gloom := _entry(prev_wick, "burn_gloom")

	_check(entry_burn_dim.get("available") == true
		and entry_burn_dim.get("candle") == 41
		and entry_burn_dim.get("candle_delta") == -10,
		"AC1: at opening candle 51, dim qualifies for -10 paid wick ending in gloom 41")
	_check(entry_burn_gloom.get("available") == false
		and entry_burn_gloom.get("candle") == 51
		and entry_burn_gloom.get("fray") == {},
		"AC1: at opening candle 51, gloom does NOT qualify even though end candle is 41")

	_assert_rejected(svc_wick, "burn_gloom", snap_51, 51,
		"AC2: choose(burn_gloom) refused at opening candle 51")
	var rec_burn_dim := svc_wick.choose("burn_dim", snap_51)
	_check(rec_burn_dim.get("ok") == true and rec_burn_dim.get("candle") == 41,
		"AC2: choose(burn_dim) succeeds after burn_gloom refusal on same visit")

	# Paid wick at candle 26 (gloom) with -10 cost ending in 16 (dark)
	var snap_26 := _four(26, [30, 30, 30, 30])
	var svc_wick_26 := RunStitchedEventConsequence.new(_event([
		_choice("burn_gloom", "Burn in gloom.", {
			"candle": -10, "fray": -10, "target": "party", "require_full_candle": true, "required_candle_band": "gloom",
		}),
		_choice("burn_dark", "Burn in dark.", {
			"candle": -10, "fray": -10, "target": "party", "require_full_candle": true, "required_candle_band": "dark",
		}),
	]))
	var prev_wick_26 := svc_wick_26.preview(snap_26)
	_check(_entry(prev_wick_26, "burn_gloom").get("available") == true
		and _entry(prev_wick_26, "burn_gloom").get("candle") == 16,
		"AC1: at opening candle 26, gloom qualifies and projects candle 16")
	_check(_entry(prev_wick_26, "burn_dark").get("available") == false
		and _entry(prev_wick_26, "burn_dark").get("candle") == 26,
		"AC1: at opening candle 26, dark does not qualify")

	# AC1/AC2: Independent gates interaction (required_candle_band + min_fray + require_full_candle + required_hero)
	# All gates must pass!
	var multi_gate_event := _event([
		_choice("multi_gate", "Strict multi gate.", {
			"candle": -20,
			"fray": -30,
			"target": "party",
			"required_candle_band": "bright",
			"require_full_candle": true,
			"min_fray": 100,
			"required_hero": "warden",
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_multi_gate")

	# Case A: candle 100 (bright), fray 100 on warden -> passes all!
	var snap_multi_pass := _four(100, [100, 10, 10, 10])
	var svc_multi_pass := RunStitchedEventConsequence.new(multi_gate_event)
	var prev_multi_pass := svc_multi_pass.preview(snap_multi_pass)
	_check(_entry(prev_multi_pass, "multi_gate").get("available") == true
		and _entry(prev_multi_pass, "multi_gate").get("candle") == 80,
		"AC1: multi_gate available when bright, paid wick, min_fray and required_hero all pass")
	var rec_multi_pass := svc_multi_pass.choose("multi_gate", snap_multi_pass)
	_check(rec_multi_pass.get("ok") == true and rec_multi_pass.get("candle") == 80,
		"AC2: choose(multi_gate) succeeds when all gates pass")

	# Case B: candle 50 (gloom), fray 100 on warden -> candle band fails
	var snap_multi_bad_band := _four(50, [100, 10, 10, 10])
	var svc_multi_bad_band := RunStitchedEventConsequence.new(multi_gate_event)
	var prev_multi_bad_band := svc_multi_bad_band.preview(snap_multi_bad_band)
	_check(_entry(prev_multi_bad_band, "multi_gate").get("available") == false
		and _entry(prev_multi_bad_band, "multi_gate").get("candle") == 50,
		"AC1: multi_gate unavailable when candle band fails")
	_assert_rejected(svc_multi_bad_band, "multi_gate", snap_multi_bad_band, 50,
		"AC2: choose(multi_gate) rejected when band fails")

	# Case C: candle 100 (bright), fray 99 on warden -> min_fray fails
	var snap_multi_bad_fray := _four(100, [99, 10, 10, 10])
	var svc_multi_bad_fray := RunStitchedEventConsequence.new(multi_gate_event)
	var prev_multi_bad_fray := svc_multi_bad_fray.preview(snap_multi_bad_fray)
	_check(_entry(prev_multi_bad_fray, "multi_gate").get("available") == false
		and _entry(prev_multi_bad_fray, "multi_gate").get("candle") == 100,
		"AC1: multi_gate unavailable when min_fray fails")
	_assert_rejected(svc_multi_bad_fray, "multi_gate", snap_multi_bad_fray, 100,
		"AC2: choose(multi_gate) rejected when min_fray fails")

	# Case D: candle 100 (bright), fray 100, warden absent -> hidden from preview, rejected on choose
	var snap_multi_absent := _snapshot(100, [["seamstress", 100], ["tinker", 100]])
	var svc_multi_absent := RunStitchedEventConsequence.new(multi_gate_event)
	var prev_multi_absent := svc_multi_absent.preview(snap_multi_absent)
	_check(_entry(prev_multi_absent, "multi_gate").is_empty(),
		"AC1: multi_gate omitted from preview when required_hero is absent")
	_assert_rejected(svc_multi_absent, "multi_gate", snap_multi_absent, 100,
		"AC2: choose(multi_gate) rejected when required_hero is absent")

	# Case E: hero target with min_fray and band gate
	var hero_multi_event := _event([
		_choice("hero_gate", "Hero strict gate.", {
			"candle": 5, "fray": -20, "target": "hero", "hero_id": "seamstress",
			"required_candle_band": "dark", "min_fray": 50,
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	])
	var snap_hero_dark_pass := _four(20, [0, 50, 0, 0])
	var svc_hero_pass := RunStitchedEventConsequence.new(hero_multi_event)
	_check(_entry(svc_hero_pass.preview(snap_hero_dark_pass), "hero_gate").get("available") == true,
		"AC1: hero target available when both dark and seamstress fray >= 50")
	var snap_hero_dark_bad_fray := _four(20, [0, 49, 0, 0])
	_check(_entry(svc_hero_pass.preview(snap_hero_dark_bad_fray), "hero_gate").get("available") == false,
		"AC1: hero target unavailable when dark matches but seamstress fray < 50")
	var snap_hero_bright_good_fray := _four(80, [0, 50, 0, 0])
	_check(_entry(svc_hero_pass.preview(snap_hero_bright_good_fray), "hero_gate").get("available") == false,
		"AC1: hero target unavailable when fray passes but band fails")

	# AC1/AC2: Optional rewards combination (scraps, gold, part, hp) with required_candle_band
	var rewards_band_event := _event([
		_choice("dim_bounty", "Bounty in the dim.", {
			"candle": 10,
			"fray": -15,
			"target": "party",
			"required_candle_band": "dim",
			"scraps": 4,
			"gold": 6,
			"hp": 5,
			"part": {"id": "warden_head_pot_helm_bonk", "tier": 1},
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_dim_bounty")

	var snap_dim_qual := _gold_scraps_satchel_four(60, 3, 10, 2, [10, 10, 10, 10])
	var snap_dark_inelig := _gold_scraps_satchel_four(20, 3, 10, 2, [10, 10, 10, 10])

	var svc_rewards_pass := RunStitchedEventConsequence.new(rewards_band_event, warden_catalog)
	var prev_rewards_pass := svc_rewards_pass.preview(snap_dim_qual)
	var entry_dim_bounty := _entry(prev_rewards_pass, "dim_bounty")

	_check(entry_dim_bounty.get("available") == true
		and entry_dim_bounty.get("candle") == 70
		and entry_dim_bounty.get("scraps") == 7
		and entry_dim_bounty.get("gold") == 16
		and entry_dim_bounty.get("satchel_count") == 3
		and entry_dim_bounty.get("hp") == {"warden": 5, "seamstress": 5, "tinker": 5, "button_golem": 5},
		"AC1: matching band projects optional scraps, gold, satchel_count and hp intents")

	var rec_rewards_pass := svc_rewards_pass.choose("dim_bounty", snap_dim_qual)
	_check(rec_rewards_pass.get("ok") == true
		and rec_rewards_pass.get("candle") == 70
		and rec_rewards_pass.get("scraps") == 7
		and rec_rewards_pass.get("gold") == 16
		and rec_rewards_pass.get("satchel_count") == 3
		and rec_rewards_pass.get("part") == {"id": "warden_head_pot_helm_bonk", "tier": 1}
		and rec_rewards_pass.get("hp") == {"warden": 5, "seamstress": 5, "tinker": 5, "button_golem": 5},
		"AC2: choose(dim_bounty) returns exact projected optional receipts")

	var svc_rewards_fail := RunStitchedEventConsequence.new(rewards_band_event, warden_catalog)
	var prev_rewards_fail := svc_rewards_fail.preview(snap_dark_inelig)
	var entry_fail_bounty := _entry(prev_rewards_fail, "dim_bounty")
	_check(entry_fail_bounty.get("available") == false
		and entry_fail_bounty.get("candle") == 20
		and entry_fail_bounty.get("scraps") == 3
		and entry_fail_bounty.get("gold") == 10
		and entry_fail_bounty.get("satchel_count") == 2
		and entry_fail_bounty.get("hp") == {}
		and entry_fail_bounty.get("fray") == {},
		"AC1: non-matching band leaves balances unchanged, hp/fray empty, available false")
	_assert_rejected(svc_rewards_fail, "dim_bounty", snap_dark_inelig, 20,
		"AC2: choose(dim_bounty) rejected when band fails")

	# AC3: Backward compatibility for absent required_candle_band field
	var legacy_event := _event([
		_choice("legacy_party", "Legacy party.", _effect(15, -15, "party")),
		_choice("legacy_hero", "Legacy hero.", _effect(0, -10, "hero", "warden")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_legacy_absent_band")

	var snap_legacy := _four(50, [20, 20, 20, 20])
	var svc_legacy := RunStitchedEventConsequence.new(legacy_event)
	var prev_legacy := svc_legacy.preview(snap_legacy)
	var entry_legacy_party := _entry(prev_legacy, "legacy_party")
	var entry_legacy_hero := _entry(prev_legacy, "legacy_hero")

	var expected_legacy_preview_keys := [
		"available", "candle", "candle_delta", "choice_id", "fray", "fray_delta", "hero_id", "target"
	]
	var expected_legacy_receipt_keys := [
		"candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target"
	]

	_check(_receipt_keys(entry_legacy_party) == expected_legacy_preview_keys,
		"AC3: absent band field preserves exact 8-key preview entry shape for party")
	_check(_receipt_keys(entry_legacy_hero) == expected_legacy_preview_keys,
		"AC3: absent band field preserves exact 8-key preview entry shape for hero")
	_check(entry_legacy_party.get("available") == true and entry_legacy_hero.get("available") == true,
		"AC3: absent band field remains available regardless of candle band")

	var rec_legacy_party := svc_legacy.choose("legacy_party", snap_legacy)
	_check(_receipt_keys(rec_legacy_party) == expected_legacy_receipt_keys,
		"AC3: absent band field preserves exact 7-key receipt shape")
	_check(rec_legacy_party.get("ok") == true and rec_legacy_party.get("candle") == 65,
		"AC3: absent band field settles normally")

	# AC3: Malformed, unknown, case-variant, whitespace, null, integer, bool band values fail closed
	var malformed_bands: Array = [
		# Unknown names
		"twilight", "midnight", "dusk", "shadow", "brightest", "snuff", "dimmer", "noon",
		# Uppercase
		"BRIGHT", "DIM", "GLOOM", "DARK", "SNUFFED",
		# Mixed case
		"Bright", "Dark", "Dim", "Gloom", "Snuffed", "brighT", "dArk",
		# Whitespace
		"", " ", "  ", " bright", "bright ", " bright ", "dim\n", "\tdark",
		# Non-string types
		null, 0, 1, 25, 50, 76, 100, -1, 1.0, 0.0, true, false,
		["bright"], {"band": "bright"},
	]

	var snap_test_malformed := _four(50, [20, 20, 20, 20])
	for idx in range(malformed_bands.size()):
		var bad_band: Variant = malformed_bands[idx]
		for target_mode in ["party", "hero"]:
			var bad_effect := {
				"candle": 10,
				"fray": -10,
				"target": target_mode,
				"required_candle_band": bad_band,
			}
			if target_mode == "hero":
				bad_effect["hero_id"] = "warden"

			var bad_ev := _event([
				_choice("bad_band", "Malformed band.", bad_effect),
				_choice("valid_alt", "Valid sibling.", _effect(5, -5, "party")),
				_choice("leave", "Leave.", _effect(0, 0, "party")),
			], "ev_bad_band_%d_%s" % [idx, target_mode])

			var bad_svc := RunStitchedEventConsequence.new(bad_ev)
			var bad_prev := bad_svc.preview(snap_test_malformed)
			var bad_entry := _entry(bad_prev, "bad_band")

			_check(bad_prev.get("ok") == true
				and _choice_ids(bad_prev) == ["bad_band", "valid_alt", "leave"]
				and bad_entry.get("available") == false
				and bad_entry.get("candle_delta") == null
				and bad_entry.get("fray_delta") == null
				and bad_entry.get("candle") == 50
				and bad_entry.get("fray") == {}
				and _entry(bad_prev, "valid_alt").get("available") == true
				and _entry(bad_prev, "leave").get("available") == true,
				"AC3: malformed band %d (%s) is unavailable with null deltas while siblings remain available" % [
					idx, target_mode
				])

			_assert_rejected(bad_svc, "bad_band", snap_test_malformed, 50,
				"AC3: choose(bad_band) rejected for malformed band %d (%s)" % [idx, target_mode])

			# Alternating sibling choice claim
			var fallback := "leave" if (idx % 2 == 0) else "valid_alt"
			_check(bad_svc.choose(fallback, snap_test_malformed).get("ok") == true,
				"AC3: %s succeeds after malformed band %d (%s) refusal" % [fallback, idx, target_mode])

	# AC3: Structural malformations (extra keys, wrong key combination) fail closed
	var structural_bad_effects: Array = [
		{"candle": 0, "fray": -10, "target": "party", "required_candle_band": "bright", "extra": 1},
		{"candle": 0, "fray": -10, "target": "party", "required_candle_band": "bright", "hero_id": "warden"},
		{"candle": 0, "fray": -10, "target": "hero", "required_candle_band": "bright"}, # missing hero_id
		{"candle": 0, "fray": -10, "target": "hero", "hero_id": "warden", "required_candle_band": "bright", "bogus": true},
		{"candle": -25, "fray": -10, "target": "party", "required_candle_band": "bright", "require_full_candle": true, "extra": 1},
	]

	for idx in range(structural_bad_effects.size()):
		var bad_struct_ev := _event([
			_choice("bad_struct", "Malformed struct.", structural_bad_effects[idx]),
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		])
		var bad_struct_svc := RunStitchedEventConsequence.new(bad_struct_ev)
		var bad_struct_prev := bad_struct_svc.preview(snap_test_malformed)
		var bad_struct_entry := _entry(bad_struct_prev, "bad_struct")

		_check(_choice_ids(bad_struct_prev) == ["bad_struct", "leave"]
			and bad_struct_entry.get("available") == false
			and bad_struct_entry.get("candle_delta") == null
			and bad_struct_entry.get("fray_delta") == null
			and bad_struct_entry.get("candle") == 50
			and bad_struct_entry.get("fray") == {}
			and _entry(bad_struct_prev, "leave").get("available") == true,
			"AC3: structural bad band effect %d fails closed with null deltas" % idx)

		_assert_rejected(bad_struct_svc, "bad_struct", snap_test_malformed, 50,
			"AC3: choose(bad_struct) rejected for structural bad effect %d" % idx)
		_check(bad_struct_svc.choose("leave", snap_test_malformed).get("ok") == true,
			"AC3: Leave succeeds after structural bad effect %d refusal" % idx)

	# Verify warden_catalog was never mutated
	_check(warden_catalog == catalog_original, "AC3: warden_catalog was never mutated during band tests")


func _test_lost_heroes_ac1_party_recipients() -> void:
	# AC1: Given a valid four-ID snapshot with one explicit lost:true doll and three living dolls,
	# an authored party-targeted Event with FRAY -25 and HP +10 projects/receipts raw FRAY and HP
	# intents for precisely the three living IDs, omitting the LOST ID. The wallet, candle and other
	# earned effects follow their existing rules. Assert preview/choose equality on the same event
	# and snapshot in the existing headless suite.
	var party: Array = [
		{"id": "warden", "fray": 20, "lost": false}, # healthy living ally
		{"id": "seamstress", "fray": 150, "lost": true}, # explicitly LOST doll
		{"id": "tinker", "fray": 50, "lost": false}, # HANGING-but-not-LOST living hero
		{"id": "button_golem", "fray": 30}, # omitted lost -> living ally
	]
	var snapshot := {
		"candle": 40,
		"party": party,
		"scraps": 10,
		"gold": 25,
		"satchel_count": 2,
	}
	var snap_before := snapshot.duplicate(true)

	var ev := _event([
		_choice("party_bargain", "Mend seams and heal cloth.", {
			"candle": 20,
			"fray": -25,
			"target": "party",
			"hp": 10,
			"scraps": -2,
			"gold": 5,
		}),
		_choice("leave", "Leave untouched.", _effect(0, 0, "party")),
	], "ev_stitched_ac1_lost_party")
	var ev_before := ev.duplicate(true)

	var service := RunStitchedEventConsequence.new(ev)
	var prev := service.preview(snapshot)
	_check(prev.get("ok") == true, "AC1: preview succeeds with 1 lost and 3 living dolls")
	_check(prev.get("candle") == 40, "AC1: preview preserves untouched base candle")

	var entry := _entry(prev, "party_bargain")
	_check(entry.get("available") == true, "AC1: party bargain is available with living recipients")
	_check(entry.get("candle") == 60, "AC1: projects candle 40 + 20 = 60")
	_check(entry.get("candle_delta") == 20, "AC1: authored candle delta 20")
	_check(entry.get("fray_delta") == -25, "AC1: authored fray delta -25")
	_check(entry.get("hp_delta") == 10, "AC1: authored hp delta 10")
	_check(entry.get("scraps") == 8 and entry.get("scraps_delta") == -2, "AC1: scraps projected 10 - 2 = 8")
	_check(entry.get("gold") == 30 and entry.get("gold_delta") == 5, "AC1: gold projected 25 + 5 = 30")

	# Fray and HP intents: precisely the 3 living IDs, omitting seamstress
	var expected_fray := {"warden": -25, "tinker": -25, "button_golem": -25}
	var expected_hp := {"warden": 10, "tinker": 10, "button_golem": 10}
	_check(entry.get("fray") == expected_fray, "AC1: preview fray projects precisely the 3 living IDs, omitting lost seamstress")
	_check(entry.get("hp") == expected_hp, "AC1: preview hp projects precisely the 3 living IDs, omitting lost seamstress")
	_check(not entry.get("fray", {}).has("seamstress"), "AC1: preview fray never includes lost seamstress")
	_check(not entry.get("hp", {}).has("seamstress"), "AC1: preview hp never includes lost seamstress")

	# Commit choose and verify exact equality with preview
	var receipt := service.choose("party_bargain", snapshot)
	_check(receipt.get("ok") == true, "AC1: choose succeeds")
	_check(receipt.get("event_id") == "ev_stitched_ac1_lost_party", "AC1: receipt names event id")
	_check(receipt.get("choice_id") == "party_bargain", "AC1: receipt names choice id")
	_check(receipt.get("target") == "party" and receipt.get("hero_id") == "", "AC1: receipt target metadata matches")
	_check(receipt.get("candle") == entry.get("candle"), "AC1: receipt candle matches preview equality")
	_check(receipt.get("fray") == entry.get("fray"), "AC1: receipt fray matches preview equality")
	_check(receipt.get("hp") == entry.get("hp"), "AC1: receipt hp matches preview equality")
	_check(receipt.get("scraps") == entry.get("scraps") and receipt.get("scraps_delta") == entry.get("scraps_delta"),
		"AC1: receipt scraps matches preview equality")
	_check(receipt.get("gold") == entry.get("gold") and receipt.get("gold_delta") == entry.get("gold_delta"),
		"AC1: receipt gold matches preview equality")

	_check(service.is_claimed() == true, "AC1: successful choose latches visit")
	_check(snapshot == snap_before, "AC1: input snapshot is untouched")
	_check(ev == ev_before, "AC1: input event is untouched")


func _test_lost_heroes_ac2_hero_targeted_and_required_hero() -> void:
	# AC2: Given an authored hero-targeted Event whose hero_id is LOST, preview shows its offered
	# choice unavailable and choose refuses without latching. Given a party-targeted choice requiring
	# that LOST hero, treat it like an absent required_hero (hidden/refused), even when surviving
	# allies exist; a living required_hero remains eligible. Prove with explicit preview, refused
	# choose and a subsequent lawful Leave receipt.
	var party: Array = [
		{"id": "warden", "fray": 20, "lost": false}, # living
		{"id": "seamstress", "fray": 150, "lost": true}, # explicitly LOST
		{"id": "tinker", "fray": 50, "lost": false}, # living (hanging)
		{"id": "button_golem", "fray": 30}, # living (omitted lost)
	]
	var snapshot := {
		"candle": 50,
		"party": party,
		"scraps": 10,
		"gold": 20,
	}
	var snap_before := snapshot.duplicate(true)

	var ev := _event([
		_choice("tend_lost", "Tend Seamstress.", _hp_effect(15, -25, 10, "hero", "seamstress")),
		_choice("require_lost", "Seamstress leads thread.", _hp_required_hero_effect(10, -20, 5, "seamstress", "party")),
		_choice("leave", "Leave unharmed.", _effect(0, 0, "party")),
	], "ev_stitched_ac2_hero_gates")

	var service := RunStitchedEventConsequence.new(ev)
	var prev := service.preview(snapshot)
	_check(prev.get("ok") == true, "AC2: preflight succeeds")

	# require_lost is hidden because seamstress is LOST (treated like absent required_hero)
	var choice_ids: Array = []
	for c in prev.get("choices", []):
		choice_ids.append(c.get("choice_id"))
	_check(choice_ids == ["tend_lost", "leave"], "AC2: party choice requiring LOST hero is hidden from preview")
	_check(not choice_ids.has("require_lost"), "AC2: require_lost is not in preview choices")

	# tend_lost is offered in preview but unavailable
	var lost_hero_entry := _entry(prev, "tend_lost")
	_check(lost_hero_entry.get("available") == false, "AC2: choice targeting LOST hero is unavailable in preview")
	_check(lost_hero_entry.get("candle") == 50, "AC2: unavailable choice projects base candle")
	_check(lost_hero_entry.get("fray") == {} and lost_hero_entry.get("hp") == {},
		"AC2: unavailable choice projects empty fray and hp")
	_check(lost_hero_entry.get("candle_delta") == 15 and lost_hero_entry.get("fray_delta") == -25 and lost_hero_entry.get("hp_delta") == 10,
		"AC2: unavailable choice still exposes authored deltas")

	# choose(tend_lost) refuses without latching
	_assert_rejected(service, "tend_lost", snapshot, 50, "AC2: choose(tend_lost) refused")
	_check(not service.is_claimed(), "AC2: tend_lost refusal does not latch visit")
	_check(snapshot == snap_before, "AC2: tend_lost refusal leaves snapshot untouched")

	# choose(require_lost) refuses without latching
	_assert_rejected(service, "require_lost", snapshot, 50, "AC2: choose(require_lost) refused")
	_check(not service.is_claimed(), "AC2: require_lost refusal does not latch visit")
	_check(snapshot == snap_before, "AC2: require_lost refusal leaves snapshot untouched")

	# subsequent lawful Leave receipt succeeds
	var leave_receipt := service.choose("leave", snapshot)
	_check(leave_receipt.get("ok") == true, "AC2: lawful Leave succeeds after prior refusals")
	_check(leave_receipt.get("candle") == 50 and leave_receipt.get("fray") == {}, "AC2: Leave receipt has base candle and empty fray")
	_check(service.is_claimed() == true, "AC2: Leave claim latches the visit")

	# Living required_hero remains eligible:
	var living_req_ev := _event([
		_choice("require_warden", "Warden shields.", _hp_required_hero_effect(10, -10, 5, "warden", "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_ac2_living_req")
	var living_req_svc := RunStitchedEventConsequence.new(living_req_ev)
	var living_req_prev := living_req_svc.preview(snapshot)
	var req_entry := _entry(living_req_prev, "require_warden")
	_check(req_entry.get("available") == true, "AC2: choice requiring living warden is visible and available")
	_check(req_entry.get("fray") == {"warden": -10, "tinker": -10, "button_golem": -10},
		"AC2: living required hero choice affects all living allies")
	var req_receipt := living_req_svc.choose("require_warden", snapshot)
	_check(req_receipt.get("ok") == true and req_receipt.get("fray") == req_entry.get("fray"),
		"AC2: living required hero choice claims successfully with preview equality")

	# Living hero-targeted choice remains eligible:
	var living_target_ev := _event([
		_choice("tend_tinker", "Tend hanging Tinker.", _hp_effect(5, -15, 8, "hero", "tinker")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_ac2_living_target")
	var living_target_svc := RunStitchedEventConsequence.new(living_target_ev)
	var living_target_prev := living_target_svc.preview(snapshot)
	var target_entry := _entry(living_target_prev, "tend_tinker")
	_check(target_entry.get("available") == true, "AC2: hero-targeted choice for living hanging Tinker is available")
	_check(target_entry.get("fray") == {"tinker": -15} and target_entry.get("hp") == {"tinker": 8},
		"AC2: living hanging Tinker receives fray and hp intents")
	var target_receipt := living_target_svc.choose("tend_tinker", snapshot)
	_check(target_receipt.get("ok") == true and target_receipt.get("fray") == {"tinker": -15},
		"AC2: living hanging Tinker choice claims successfully")


func _test_lost_heroes_ac3_min_fray_and_all_lost() -> void:
	# AC3: Given min_fray:100 and one LOST doll at FRAY 150 but all living dolls below 100,
	# the choice is unavailable and cannot charge resources; when a living eligible doll is at FRAY 100,
	# the ordinary party or matching required_hero choice works. A party with no living recipients
	# cannot claim targeted benefits. Test quote/claim parity and unchanged wallets on refusal.
	var party: Array = [
		{"id": "warden", "fray": 80, "lost": false}, # living below 100
		{"id": "seamstress", "fray": 150, "lost": true}, # LOST at 150
		{"id": "tinker", "fray": 50, "lost": false}, # living below 100
		{"id": "button_golem", "fray": 20}, # living below 100
	]
	var snapshot := {
		"candle": 60,
		"party": party,
		"gold": 25,
		"scraps": 15,
	}
	var snap_before := snapshot.duplicate(true)

	var ev := _event([
		_choice("gated_party", "Soothe severe fray.", {
			"candle": 0,
			"fray": -30,
			"target": "party",
			"min_fray": 100,
			"gold": -10,
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_ac3_min_fray")

	var service := RunStitchedEventConsequence.new(ev)
	var prev := service.preview(snapshot)
	var gated_entry := _entry(prev, "gated_party")
	_check(gated_entry.get("available") == false,
		"AC3: min_fray 100 is unavailable when only LOST doll is at fray 150 and living dolls are < 100")
	_check(gated_entry.get("gold") == 25, "AC3: unavailable min_fray choice does not project gold deduction")

	# choose refusal: no latching, unchanged wallets
	_assert_rejected(service, "gated_party", snapshot, 60, "AC3: gated_party refused due to living dolls < min_fray")
	_check(not service.is_claimed(), "AC3: gated_party refusal does not latch visit")
	_check(snapshot == snap_before, "AC3: wallets completely unchanged on min_fray refusal")
	_check(service.choose("leave", snapshot).get("ok") == true, "AC3: leave succeeds after min_fray refusal")

	# Now when a living doll is at fray 100:
	var party_with_living_100: Array = [
		{"id": "warden", "fray": 100, "lost": false}, # living at 100
		{"id": "seamstress", "fray": 150, "lost": true},
		{"id": "tinker", "fray": 50, "lost": false},
		{"id": "button_golem", "fray": 20},
	]
	var snap_living_100 := {
		"candle": 60,
		"party": party_with_living_100,
		"gold": 25,
		"scraps": 15,
	}
	var svc_living_100 := RunStitchedEventConsequence.new(ev)
	var prev_living_100 := svc_living_100.preview(snap_living_100)
	var entry_living_100 := _entry(prev_living_100, "gated_party")
	_check(entry_living_100.get("available") == true, "AC3: min_fray 100 choice is available when living warden is at fray 100")
	_check(entry_living_100.get("gold") == 15, "AC3: projects gold 25 - 10 = 15")
	_check(entry_living_100.get("fray") == {"warden": -30, "tinker": -30, "button_golem": -30},
		"AC3: fray intent omits lost seamstress")
	var rec_living_100 := svc_living_100.choose("gated_party", snap_living_100)
	_check(rec_living_100.get("ok") == true, "AC3: claim succeeds with living doll at min_fray")
	_check(rec_living_100.get("gold") == 15 and rec_living_100.get("gold_delta") == -10, "AC3: gold charged on successful claim")

	# matching required_hero choice with min_fray:
	var req_min_fray_ev := _event([
		_choice("req_warden", "Warden resolve.", {
			"candle": 0, "fray": -20, "target": "party", "required_hero": "warden", "min_fray": 100
		}),
		_choice("req_seamstress", "Seamstress resolve.", {
			"candle": 0, "fray": -20, "target": "party", "required_hero": "seamstress", "min_fray": 100
		}),
		_choice("leave", "Leave.", _effect(0, 0)),
	], "ev_stitched_ac3_req_min_fray")
	var req_svc := RunStitchedEventConsequence.new(req_min_fray_ev)
	var req_prev := req_svc.preview(snap_living_100)
	_check(_entry(req_prev, "req_warden").get("available") == true, "AC3: living warden satisfies both required_hero and min_fray")
	# req_seamstress is hidden because seamstress is LOST
	_check(_entry(req_prev, "req_seamstress").is_empty(), "AC3: req_seamstress is hidden because seamstress is LOST")
	_assert_rejected(req_svc, "req_seamstress", snap_living_100, 60, "AC3: req_seamstress choose is refused")

	# ALL-LOST edge case: party where every single doll is lost
	var all_lost_party: Array = [
		{"id": "warden", "fray": 40, "lost": true},
		{"id": "seamstress", "fray": 150, "lost": true},
		{"id": "tinker", "fray": 70, "lost": true},
		{"id": "button_golem", "fray": 90, "lost": true},
	]
	var all_lost_snap := {
		"candle": 50,
		"party": all_lost_party,
		"gold": 30,
		"scraps": 10,
	}
	var all_lost_snap_before := all_lost_snap.duplicate(true)

	var all_lost_ev := _event([
		_choice("party_fray", "Mend seams.", {"candle": 0, "fray": -20, "target": "party", "gold": -5}),
		_choice("party_hp", "Sew torn flesh.", _hp_effect(0, 0, 10, "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_ac3_all_lost_targeted")
	var all_lost_svc := RunStitchedEventConsequence.new(all_lost_ev)
	var all_lost_prev := all_lost_svc.preview(all_lost_snap)

	# Targeted choices unavailable because no living recipients exist
	var fray_entry := _entry(all_lost_prev, "party_fray")
	var hp_entry := _entry(all_lost_prev, "party_hp")
	var leave_entry := _entry(all_lost_prev, "leave")
	_check(fray_entry.get("available") == false, "AC3: all-lost party cannot claim targeted fray benefits")
	_check(fray_entry.get("fray") == {} and fray_entry.get("gold") == 30, "AC3: all-lost party fray entry does not project gold deduction")
	_check(hp_entry.get("available") == false, "AC3: all-lost party cannot claim targeted hp benefits")
	_check(leave_entry.get("available") == true, "AC3: Leave remains available when all heroes are lost")

	# choose refusals on targeted benefits
	_assert_rejected(all_lost_svc, "party_fray", all_lost_snap, 50, "AC3: choose(party_fray) refused for all-lost party")
	_check(not all_lost_svc.is_claimed(), "AC3: party_fray refusal does not latch")
	_check(all_lost_snap == all_lost_snap_before, "AC3: wallet unchanged after party_fray refusal")

	_assert_rejected(all_lost_svc, "party_hp", all_lost_snap, 50, "AC3: choose(party_hp) refused for all-lost party")
	_check(not all_lost_svc.is_claimed(), "AC3: party_hp refusal does not latch")
	_check(all_lost_snap == all_lost_snap_before, "AC3: wallet unchanged after party_hp refusal")

	# Trade / Leave remains claimable under existing rules
	var all_lost_trade_ev := _event([
		_choice("buy_scraps", "Buy scraps with gold.", {
			"candle": 0, "fray": 0, "target": "party", "gold": -10, "scraps": 4
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_ac3_all_lost_trade")
	var trade_svc := RunStitchedEventConsequence.new(all_lost_trade_ev)
	var trade_prev := trade_svc.preview(all_lost_snap)
	_check(_entry(trade_prev, "buy_scraps").get("available") == true,
		"AC3: pure trade remains available for all-lost party")
	_check(_entry(trade_prev, "buy_scraps").get("gold") == 20 and _entry(trade_prev, "buy_scraps").get("scraps") == 14,
		"AC3: pure trade projects wallet deltas for all-lost party")
	var trade_rec := trade_svc.choose("buy_scraps", all_lost_snap)
	_check(trade_rec.get("ok") == true, "AC3: pure trade succeeds for all-lost party")
	_check(trade_rec.get("gold") == 20 and trade_rec.get("scraps") == 14, "AC3: wallet updated correctly on trade")
	_check(trade_rec.get("fray") == {}, "AC3: trade receipt fray is empty")

	# Lawful leave also succeeds for all-lost party
	var all_lost_leave_rec := all_lost_svc.choose("leave", all_lost_snap)
	_check(all_lost_leave_rec.get("ok") == true, "AC3: lawful Leave succeeds for all-lost party")
	_check(all_lost_leave_rec.get("candle") == 50 and all_lost_leave_rec.get("fray") == {},
		"AC3: Leave receipt has base candle and empty fray")


func _test_lost_heroes_ac4_schema_compatibility_and_invariants() -> void:
	# AC4: Given the existing canonical {id,fray} snapshots, all former successful receipts
	# and negative tests remain unchanged. An explicit lost:false has the same eligibility as an
	# omitted flag; nonboolean lost values or unexpected keys are rejected. Input snapshots/events
	# stay deep-copy safe, seed RNG is not drawn, and a claimed visit still refuses replay. Run the
	# existing full Stitched consequence suite and a representative S6 Event live regression without
	# changing live behavior.
	var ev := _event([
		_choice("party_bargain", "Mend seams.", _hp_effect(20, -25, 10, "party")),
		_choice("tend_warden", "Tend Warden.", _hp_effect(10, -15, 5, "hero", "warden")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_stitched_ac4_compat")

	# Omitted lost vs explicit lost:false equivalence
	var snap_omitted := {
		"candle": 40,
		"party": [
			{"id": "warden", "fray": 10},
			{"id": "seamstress", "fray": 20},
			{"id": "tinker", "fray": 30},
			{"id": "button_golem", "fray": 40},
		],
		"scraps": 5,
		"gold": 10,
	}
	var snap_explicit_false := {
		"candle": 40,
		"party": [
			{"id": "warden", "fray": 10, "lost": false},
			{"id": "seamstress", "fray": 20, "lost": false},
			{"id": "tinker", "fray": 30, "lost": false},
			{"id": "button_golem", "fray": 40, "lost": false},
		],
		"scraps": 5,
		"gold": 10,
	}

	var svc1 := RunStitchedEventConsequence.new(ev)
	var svc2 := RunStitchedEventConsequence.new(ev)
	var prev1 := svc1.preview(snap_omitted)
	var prev2 := svc2.preview(snap_explicit_false)
	_check(prev1 == prev2, "AC4: preview with omitted lost equals preview with explicit lost:false")

	var rec1 := svc1.choose("party_bargain", snap_omitted)
	var rec2 := svc2.choose("party_bargain", snap_explicit_false)
	_check(rec1 == rec2, "AC4: choose receipt with omitted lost equals choose receipt with explicit lost:false")

	# Nonboolean lost values and unexpected keys rejected
	var bad_lost_snapshots: Array = [
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": 1}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": 0}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": 1.0}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": "true"}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": "false"}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": null}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": []}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": {}}]},
		# Unexpected keys on hero
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": false, "extra": 1}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "lost": true, "hp": 10}]},
		{"candle": 40, "party": [{"id": "warden", "fray": 10, "extra": 1}]},
		{"candle": 40, "party": [{"id": "warden", "lost": false}]}, # missing fray
		# Top-level unexpected key
		{"candle": 40, "party": [{"id": "warden", "fray": 10}], "lost": false},
	]

	for idx in range(bad_lost_snapshots.size()):
		var bad_snap: Dictionary = bad_lost_snapshots[idx]
		var bad_snap_before := bad_snap.duplicate(true)
		var bad_svc := RunStitchedEventConsequence.new(ev)
		_check(bad_svc.preview(bad_snap) == _denied_preview(),
			"AC4: bad snapshot %d denies preview" % idx)
		_assert_rejected(bad_svc, "party_bargain", bad_snap, 0,
			"AC4: bad snapshot %d choose rejected" % idx)
		_check(bad_snap == bad_snap_before, "AC4: bad snapshot %d untouched" % idx)

	# Input immutability & detached copy verification
	var valid_snap := {
		"candle": 50,
		"party": [
			{"id": "warden", "fray": 20, "lost": false},
			{"id": "seamstress", "fray": 150, "lost": true},
			{"id": "tinker", "fray": 40},
			{"id": "button_golem", "fray": 60, "lost": false},
		],
		"scraps": 10,
		"gold": 20,
	}
	var valid_snap_copy := valid_snap.duplicate(true)
	var ev_copy := ev.duplicate(true)
	var immut_svc := RunStitchedEventConsequence.new(ev)
	var immut_prev := immut_svc.preview(valid_snap)
	_check(valid_snap == valid_snap_copy, "AC4: preview does not mutate input snapshot")
	_check(ev == ev_copy, "AC4: preview does not mutate input event")

	var immut_rec := immut_svc.choose("party_bargain", valid_snap)
	_check(valid_snap == valid_snap_copy, "AC4: choose does not mutate input snapshot")
	_check(ev == ev_copy, "AC4: choose does not mutate input event")

	# Mutating the returned receipt does not reach snapshot or event
	immut_rec["fray"]["warden"] = 999
	immut_rec["hp"]["warden"] = 999
	immut_rec["candle"] = 999
	_check(valid_snap == valid_snap_copy, "AC4: mutating receipt does not mutate input snapshot")

	# Replay refusal
	_check(immut_svc.is_claimed() == true, "AC4: service is claimed after choice")
	_check(immut_svc.is_valid() == false, "AC4: service is no longer valid after claim")
	_assert_rejected(immut_svc, "party_bargain", valid_snap, 50, "AC4: replay party_bargain refused")
	_assert_rejected(immut_svc, "leave", valid_snap, 50, "AC4: replay leave refused")
	_check(immut_svc.preview(valid_snap) == _denied_preview(), "AC4: preview denied on claimed visit")

	# Unchanged seeded RNG
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 987654321
	var control_rng := RandomNumberGenerator.new()
	control_rng.seed = 987654321

	for i in range(5):
		test_rng.randi()
		control_rng.randi()

	# Execute consequence preview and choose
	var rng_svc := RunStitchedEventConsequence.new(ev)
	rng_svc.preview(valid_snap)
	rng_svc.choose("party_bargain", valid_snap)

	# Verify test_rng was not drawn or altered
	for i in range(5):
		_check(test_rng.randi() == control_rng.randi(), "AC4: seeded RNG was never drawn during consequence operations")


func _test_kid_fear_fray_observations_ac1() -> void:
	# AC1: 30 -> 40 yields exactly one {"kind":"fray_gain","hero_id":ID,"amount":10}
	# 30 -> 39 and fray decreases produce none.
	# StitchedKidFear consumer yields exactly +2 for the qualifying observation.
	var event_record := _event([
		_choice("fray_hero", "Fray the warden's seam.", _effect(0, 10, "hero", "warden")),
		_choice("relief_hero", "Soothe the warden's seam.", _effect(0, -10, "hero", "warden")),
		_choice("leave", "Leave.", _effect(0, 0)),
	], "ev_test_kid_fear_ac1")

	var snap_30 := _four(50, [30, 20, 20, 20])
	var svc_10 := RunStitchedEventConsequence.new(event_record)
	var receipt_10 := svc_10.choose("fray_hero", snap_30)
	_check(bool(receipt_10.get("ok", false)) == true, "AC1: genuine choose succeeds")

	# Case 1: 30 -> 40 (+10 actual gain)
	var after_40 := [
		{"id": "warden", "fray": 40},
		{"id": "seamstress", "fray": 20},
		{"id": "tinker", "fray": 20},
		{"id": "button_golem", "fray": 20},
	]
	var obs_10: Array = svc_10.derive_fear_observations(receipt_10, snap_30, after_40)
	_check(obs_10.size() == 1, "AC1: 30 -> 40 yields exactly one observation")
	_check(obs_10[0] is Dictionary, "AC1: observation is a Dictionary")
	_check(obs_10[0].get("kind") == "fray_gain", "AC1: observation kind is fray_gain")
	_check(obs_10[0].get("hero_id") == "warden", "AC1: observation hero_id is warden")
	_check(obs_10[0].get("amount") == 10, "AC1: observation amount is 10")

	# Consumer verification with StitchedKidFear fixture
	var kid_fear := StitchedKidFear.new(0)
	_check(kid_fear.get_fear() == 0, "AC1: kid fear starts at 0")
	var fear_receipt := kid_fear.apply_observed_event(obs_10[0])
	_check(bool(fear_receipt.get("ok", false)) == true, "AC1: kid fear accepts fray_gain observation")
	_check(kid_fear.get_fear() == 2, "AC1: StitchedKidFear consumer yields exactly +2 for one qualifying observation (0 -> 2)")

	# Case 2: 30 -> 39 (+9 actual gain) produces no observation
	var after_39 := [
		{"id": "warden", "fray": 39},
		{"id": "seamstress", "fray": 20},
		{"id": "tinker", "fray": 20},
		{"id": "button_golem", "fray": 20},
	]
	var obs_39: Array = svc_10.derive_fear_observations(receipt_10, snap_30, after_39)
	_check(obs_39.is_empty(), "AC1: 30 -> 39 produces no fear observation")

	# Negative three-argument assertion: valid claimed +10 receipt, authentic after-roster with 30->39,
	# and altered supplied before-FRAY 20: require empty observations (fail closed on mismatched opening fray).
	var snap_altered_fray_20 := _four(50, [20, 20, 20, 20])
	var obs_altered_20: Array = svc_10.derive_fear_observations(receipt_10, snap_altered_fray_20, after_39)
	_check(obs_altered_20.is_empty(), "AC1: altered supplied before-FRAY 20 with authentic after-roster 39 yields empty observations")

	# Altered opening lost flag fails closed
	var snap_altered_lost := {
		"candle": 50,
		"party": [
			{"id": "warden", "fray": 30, "lost": true},
			{"id": "seamstress", "fray": 20},
			{"id": "tinker", "fray": 20},
			{"id": "button_golem", "fray": 20},
		],
	}
	var obs_altered_lost: Array = svc_10.derive_fear_observations(receipt_10, snap_altered_lost, after_40)
	_check(obs_altered_lost.is_empty(), "AC1: altered supplied opening lost flag fails closed and yields empty observations")

	# Case 3: 30 -> 30 (0 gain) produces no observation
	var after_same := [
		{"id": "warden", "fray": 30},
		{"id": "seamstress", "fray": 20},
		{"id": "tinker", "fray": 20},
		{"id": "button_golem", "fray": 20},
	]
	var obs_same: Array = svc_10.derive_fear_observations(receipt_10, snap_30, after_same)
	_check(obs_same.is_empty(), "AC1: 30 -> 30 produces no fear observation")

	# Case 4: 40 -> 30 (fray decrease) produces no observation
	var after_decrease := [
		{"id": "warden", "fray": 25},
		{"id": "seamstress", "fray": 20},
		{"id": "tinker", "fray": 20},
		{"id": "button_golem", "fray": 20},
	]
	var obs_dec: Array = svc_10.derive_fear_observations(receipt_10, snap_30, after_decrease)
	_check(obs_dec.is_empty(), "AC1: fray decrease produces no fear observation")

	# Case 5: Fray relief choice (-10 fray intent) produces no observation
	var svc_relief := RunStitchedEventConsequence.new(event_record)
	var snap_relief := _four(50, [50, 20, 20, 20])
	var receipt_relief := svc_relief.choose("relief_hero", snap_relief)
	_check(bool(receipt_relief.get("ok", false)) == true, "AC1: relief choice succeeds")
	var after_relief := [
		{"id": "warden", "fray": 40},
		{"id": "seamstress", "fray": 20},
		{"id": "tinker", "fray": 20},
		{"id": "button_golem", "fray": 20},
	]
	var obs_relief: Array = svc_relief.derive_fear_observations(receipt_relief, snap_relief, after_relief)
	_check(obs_relief.is_empty(), "AC1: fray relief choice produces no fear observation")


func _test_kid_fear_fray_observations_ac2_party_wide_and_debt_parcel() -> void:
	# AC2: Party-wide +25 event yields exactly one observation per surviving active doll
	# that actually gains at least 10, in stable party/rank order.
	# Four eligible dolls yield +8 total Wren fear when applied once each.
	# A lost doll yields no gain observation, and 198 -> 200 does not count as +25.
	# Verify with real authored event fixture and controlled after-roster snapshots,
	# without asserting catalog totals or order.

	# Find real authored frayed_debt_parcel from data/events/stitched_route_effects.json
	var route_file := FileAccess.get_file_as_string("res://data/events/stitched_route_effects.json")
	var parsed_file: Variant = JSON.parse_string(route_file)
	_check(parsed_file is Dictionary, "AC2: stitched_route_effects.json is a Dictionary")
	var events_list: Array = (parsed_file as Dictionary).get("events", [])
	var debt_parcel: Dictionary = {}
	for ev in events_list:
		if ev is Dictionary and ev.get("id") == "frayed_debt_parcel":
			debt_parcel = ev
			break
	_check(not debt_parcel.is_empty(), "AC2: found real authored frayed_debt_parcel fixture")

	# Load enemy parts catalog for moth_swarm_wings
	var parts_catalog := StitchedParts.load_catalog("res://data/parts/enemy_parts.json")
	_check(bool(parts_catalog.get("ok", false)) == true, "AC2: parts catalog loaded for debt parcel")

	# Prepare event record with native integer tiers as stitched_run_session._convert_event does
	var live_event := debt_parcel.duplicate(true)
	for ch in live_event.get("choices", []):
		if ch.get("stitched_effect", {}).has("part"):
			ch["stitched_effect"]["part"]["tier"] = int(ch["stitched_effect"]["part"]["tier"])

	# Case 1: Four eligible dolls all gain 25 fray (30 -> 55)
	var snap_four: Dictionary = {
		"candle": 50,
		"satchel_count": 0,
		"party": [
			{"id": "warden", "fray": 30},
			{"id": "seamstress", "fray": 30},
			{"id": "tinker", "fray": 30},
			{"id": "button_golem", "fray": 30},
		],
	}
	var svc_debt := RunStitchedEventConsequence.new(live_event, parts_catalog)
	var receipt_debt := svc_debt.choose("offer_1", snap_four)
	_check(bool(receipt_debt.get("ok", false)) == true, "AC2: offer_1 claimed on frayed_debt_parcel")
	_check(bool(receipt_debt.get("ok", false)) == true, "AC2: offer_1 claimed on frayed_debt_parcel")
	_check(receipt_debt.get("fray") == {
		"warden": 25, "seamstress": 25, "tinker": 25, "button_golem": 25,
	}, "AC2: offer_1 receipt carries +25 fray intents to all 4 dolls")

	var after_all_55 := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
	]
	var obs_four: Array = svc_debt.derive_fear_observations(receipt_debt, snap_four, after_all_55)
	_check(obs_four.size() == 4, "AC2: four eligible dolls yield exactly 4 observations")

	# Check stable party/rank order
	_check(obs_four[0] == {"kind": "fray_gain", "hero_id": "warden", "amount": 25}, "AC2: rank 1 warden observation")
	_check(obs_four[1] == {"kind": "fray_gain", "hero_id": "seamstress", "amount": 25}, "AC2: rank 2 seamstress observation")
	_check(obs_four[2] == {"kind": "fray_gain", "hero_id": "tinker", "amount": 25}, "AC2: rank 3 tinker observation")
	_check(obs_four[3] == {"kind": "fray_gain", "hero_id": "button_golem", "amount": 25}, "AC2: rank 4 button_golem observation")

	# Feed each to StitchedKidFear fixture -> exactly +8 fear total (+2 each)
	var fear_consumer := StitchedKidFear.new(0)
	for obs_entry in obs_four:
		var apply_res := fear_consumer.apply_observed_event(obs_entry)
		_check(bool(apply_res.get("ok", false)) == true, "AC2: fear consumer accepted observation")
	_check(fear_consumer.get_fear() == 8, "AC2: four eligible dolls yield exactly +8 total Wren fear (0 -> 8)")

	# Case 2: One lost doll in opening party (seamstress lost)
	var snap_one_lost: Dictionary = {
		"candle": 50,
		"satchel_count": 0,
		"party": [
			{"id": "warden", "fray": 30},
			{"id": "seamstress", "fray": 30, "lost": true},
			{"id": "tinker", "fray": 30},
			{"id": "button_golem", "fray": 30},
		],
	}
	var svc_lost := RunStitchedEventConsequence.new(live_event, parts_catalog)
	var receipt_lost := svc_lost.choose("offer_1", snap_one_lost)
	_check(bool(receipt_lost.get("ok", false)) == true, "AC2: choose with one lost doll succeeds")
	var after_lost := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 30, "lost": true},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
	]
	var obs_lost: Array = svc_lost.derive_fear_observations(receipt_lost, snap_one_lost, after_lost)
	_check(obs_lost.size() == 3, "AC2: one lost doll results in 3 observations for surviving dolls")
	_check(obs_lost[0].get("hero_id") == "warden", "AC2: warden observation present")
	_check(obs_lost[1].get("hero_id") == "tinker", "AC2: tinker observation present")
	_check(obs_lost[2].get("hero_id") == "button_golem", "AC2: button_golem observation present")
	for o in obs_lost:
		_check(o.get("hero_id") != "seamstress", "AC2: lost doll yields no gain observation")

	# Case 3: Doll becomes lost post-settlement (lost in after_roster)
	var after_became_lost := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 55, "lost": true},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
	]
	var obs_became_lost: Array = svc_debt.derive_fear_observations(receipt_debt, snap_four, after_became_lost)
	_check(obs_became_lost.size() == 3, "AC2: doll lost after settlement yields no observation")
	for o in obs_became_lost:
		_check(o.get("hero_id") != "seamstress", "AC2: doll lost post-settlement excluded")

	# Case 4: Near-cap doll: 198 -> 200 does not count as +25
	# tinker goes 198 -> 200 (actual gain 2 < 10)
	var snap_near_cap: Dictionary = {
		"candle": 50,
		"satchel_count": 0,
		"party": [
			{"id": "warden", "fray": 30},
			{"id": "seamstress", "fray": 30},
			{"id": "tinker", "fray": 198},
			{"id": "button_golem", "fray": 30},
		],
	}
	var svc_near_cap := RunStitchedEventConsequence.new(live_event, parts_catalog)
	var receipt_near_cap := svc_near_cap.choose("offer_1", snap_near_cap)
	_check(bool(receipt_near_cap.get("ok", false)) == true, "AC2: near-cap choose succeeds")

	var after_near_cap := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 200},
		{"id": "button_golem", "fray": 55},
	]
	var obs_near_cap: Array = svc_near_cap.derive_fear_observations(receipt_near_cap, snap_near_cap, after_near_cap)
	_check(obs_near_cap.size() == 3, "AC2: near-cap 198 -> 200 excluded because actual gain is 2 < 10")
	for o in obs_near_cap:
		_check(o.get("hero_id") != "tinker", "AC2: tinker 198 -> 200 yields no gain observation")

	# Case 5: Near-cap doll: 190 -> 200 (+10 actual gain) DOES count as +10
	var snap_cap_10: Dictionary = {
		"candle": 50,
		"satchel_count": 0,
		"party": [
			{"id": "warden", "fray": 30},
			{"id": "seamstress", "fray": 30},
			{"id": "tinker", "fray": 190},
			{"id": "button_golem", "fray": 30},
		],
	}
	var svc_cap_10 := RunStitchedEventConsequence.new(live_event, parts_catalog)
	var receipt_cap_10 := svc_cap_10.choose("offer_1", snap_cap_10)
	var after_cap_10 := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 200},
		{"id": "button_golem", "fray": 55},
	]
	var obs_cap_10: Array = svc_cap_10.derive_fear_observations(receipt_cap_10, snap_cap_10, after_cap_10)
	_check(obs_cap_10.size() == 4, "AC2: 190 -> 200 yields observation with actual gain 10")
	_check(obs_cap_10[2] == {"kind": "fray_gain", "hero_id": "tinker", "amount": 10}, "AC2: tinker amount is actual 10, not raw 25")

	# Case 6: No duplicate observations
	var seen_ids := {}
	for o in obs_four:
		var hid: String = str(o.get("hero_id"))
		_check(not seen_ids.has(hid), "AC2: no duplicate observations for hero " + hid)
		seen_ids[hid] = true


func _test_kid_fear_fray_observations_ac3_negative_and_invariants() -> void:
	# AC3: Wrong, failed, unclaimed/forged, wrong-event, repeated-choice or mismatched-roster
	# receipts return no actionable observations; opening and settled records remain deep-equal
	# to their input copies. Existing Event preview/receipt/failed-claim shapes, one-use admission,
	# candle/scrap/gold/part/HP effects and deterministic RNG behavior remain unchanged.
	var event_a := _bargain_event()
	var event_b := _scraps_bargain_event()

	var snap_valid := _four(50, [30, 30, 30, 30])
	var svc_a := RunStitchedEventConsequence.new(event_a)
	var svc_b := RunStitchedEventConsequence.new(event_b)

	# 1. Unclaimed service: receipt passed before choose()
	var uncommitted_svc := RunStitchedEventConsequence.new(event_a)
	_check(uncommitted_svc.is_claimed() == false, "AC3: uncommitted service is not claimed")
	var forged_receipt := {
		"ok": true,
		"event_id": event_a["id"],
		"choice_id": "bargain",
		"target": "party",
		"hero_id": "",
		"candle": 75,
		"fray": {"warden": 25, "seamstress": 25, "tinker": 25, "button_golem": 25},
	}
	var after_valid := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
	]
	var obs_unclaimed := uncommitted_svc.derive_fear_observations(forged_receipt, snap_valid, after_valid)
	_check(obs_unclaimed.is_empty(), "AC3: unclaimed service returns no actionable observations")

	# Claim svc_a and svc_b
	var receipt_a := svc_a.choose("bargain", snap_valid)
	_check(bool(receipt_a.get("ok", false)) == true, "AC3: svc_a claimed")
	var snap_scraps := _scraps_four(50, 5, [30, 30, 30, 30])
	var receipt_b := svc_b.choose("salvage_warden", snap_scraps)
	_check(bool(receipt_b.get("ok", false)) == true, "AC3: svc_b claimed")

	# 2. Wrong receipt formats (null, non-dict, missing fields)
	_check(svc_a.derive_fear_observations(null, snap_valid, after_valid).is_empty(), "AC3: null receipt returns empty")
	_check(svc_a.derive_fear_observations("invalid", snap_valid, after_valid).is_empty(), "AC3: string receipt returns empty")
	_check(svc_a.derive_fear_observations(12345, snap_valid, after_valid).is_empty(), "AC3: int receipt returns empty")
	_check(svc_a.derive_fear_observations({}, snap_valid, after_valid).is_empty(), "AC3: empty dict receipt returns empty")
	_check(svc_a.derive_fear_observations({"ok": true}, snap_valid, after_valid).is_empty(), "AC3: missing receipt keys returns empty")

	# 3. Failed receipts (ok: false)
	var failed_receipt := {"ok": false, "event_id": "", "choice_id": "", "target": "", "hero_id": "", "candle": 50, "fray": {}}
	_check(svc_a.derive_fear_observations(failed_receipt, snap_valid, after_valid).is_empty(), "AC3: failed receipt returns empty")

	# 4. Wrong-event receipts (passing receipt from event_b to svc_a)
	var obs_wrong_event := svc_a.derive_fear_observations(receipt_b, snap_valid, after_valid)
	_check(obs_wrong_event.is_empty(), "AC3: wrong-event receipt returns no actionable observations")

	# 5. Forged choice receipt (tampered choice_id or tampered event_id)
	var tampered_receipt := receipt_a.duplicate(true)
	tampered_receipt["choice_id"] = "tend"
	_check(svc_a.derive_fear_observations(tampered_receipt, snap_valid, after_valid).is_empty(), "AC3: tampered choice_id returns empty")
	var tampered_event := receipt_a.duplicate(true)
	tampered_event["event_id"] = "wrong_event_id"
	_check(svc_a.derive_fear_observations(tampered_event, snap_valid, after_valid).is_empty(), "AC3: tampered event_id returns empty")

	# 6. Repeated-choice receipt (re-claiming an already-claimed service returns refusal)
	var repeat_result := svc_a.choose("bargain", snap_valid)
	_check(bool(repeat_result.get("ok", false)) == false, "AC3: repeated choose() returns refusal")
	_check(svc_a.derive_fear_observations(repeat_result, snap_valid, after_valid).is_empty(), "AC3: repeated-choice receipt returns empty")

	# 7. Mismatched-roster cases
	# Mismatched roster: different heroes
	var mismatched_heroes := [
		{"id": "warden", "fray": 55},
		{"id": "rag_duelist", "fray": 55},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
	]
	_check(svc_a.derive_fear_observations(receipt_a, snap_valid, mismatched_heroes).is_empty(), "AC3: mismatched heroes in after_roster returns empty")

	# Mismatched roster: missing a hero (3 heroes instead of 4)
	var short_roster := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 55},
	]
	_check(svc_a.derive_fear_observations(receipt_a, snap_valid, short_roster).is_empty(), "AC3: short after_roster returns empty")

	# Mismatched roster: extra hero (5 heroes)
	var long_roster := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
		{"id": "scarecrow", "fray": 55},
	]
	_check(svc_a.derive_fear_observations(receipt_a, snap_valid, long_roster).is_empty(), "AC3: extra hero in after_roster returns empty")

	# Mismatched roster: invalid fray (< 0 or > 200)
	var negative_fray_roster := [
		{"id": "warden", "fray": -5},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
	]
	_check(svc_a.derive_fear_observations(receipt_a, snap_valid, negative_fray_roster).is_empty(), "AC3: negative fray in after_roster returns empty")

	var overflow_fray_roster := [
		{"id": "warden", "fray": 250},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
	]
	_check(svc_a.derive_fear_observations(receipt_a, snap_valid, overflow_fray_roster).is_empty(), "AC3: overflow fray in after_roster returns empty")

	# Mismatched opening snapshot: altered before-fray
	var snap_altered_fray := _four(50, [20, 30, 30, 30])
	_check(svc_a.derive_fear_observations(receipt_a, snap_altered_fray, after_valid).is_empty(), "AC3: altered fray in opening_snapshot returns empty")

	# Mismatched opening snapshot: altered lost flag
	var snap_altered_lost_ac3 := {
		"candle": 50,
		"party": [
			{"id": "warden", "fray": 30, "lost": true},
			{"id": "seamstress", "fray": 30},
			{"id": "tinker", "fray": 30},
			{"id": "button_golem", "fray": 30},
		],
	}
	_check(svc_a.derive_fear_observations(receipt_a, snap_altered_lost_ac3, after_valid).is_empty(), "AC3: altered lost flag in opening_snapshot returns empty")

	# Mismatched opening snapshot: altered hero order
	var snap_altered_order := {
		"candle": 50,
		"party": [
			{"id": "seamstress", "fray": 30},
			{"id": "warden", "fray": 30},
			{"id": "tinker", "fray": 30},
			{"id": "button_golem", "fray": 30},
		],
	}
	_check(svc_a.derive_fear_observations(receipt_a, snap_altered_order, after_valid).is_empty(), "AC3: altered order in opening_snapshot returns empty")

	# 8. Deep-copy preservation and input immutability
	var test_snap := _four(50, [30, 30, 30, 30])
	var test_snap_copy := test_snap.duplicate(true)
	var test_after := [
		{"id": "warden", "fray": 55},
		{"id": "seamstress", "fray": 55},
		{"id": "tinker", "fray": 55},
		{"id": "button_golem", "fray": 55},
	]
	var test_after_copy := test_after.duplicate(true)
	var test_receipt_copy := receipt_b.duplicate(true)

	var valid_observations := svc_b.derive_fear_observations(receipt_b, test_snap, test_after)
	_check(test_snap == test_snap_copy, "AC3: opening snapshot remained deep-equal to input copy")
	_check(test_after == test_after_copy, "AC3: settled after_roster remained deep-equal to input copy")
	_check(receipt_b == test_receipt_copy, "AC3: receipt remained deep-equal to input copy")

	# Mutating the returned observation array does not pollute subsequent calls
	_check(valid_observations.size() == 1, "AC3: salvage_warden yielded 1 observation (30 -> 55, gain 25)")
	valid_observations.clear()
	var re_observations := svc_b.derive_fear_observations(receipt_b, test_snap, test_after)
	_check(re_observations.size() == 1, "AC3: re-called observation is detached and unaffected by prior mutations")

	# 9. No RNG or one-use state change
	var was_claimed := svc_b.is_claimed()
	var was_valid := svc_b.is_valid()
	svc_b.derive_fear_observations(receipt_b, test_snap, test_after)
	_check(svc_b.is_claimed() == was_claimed, "AC3: derive_fear_observations preserves is_claimed state")
	_check(svc_b.is_valid() == was_valid, "AC3: derive_fear_observations preserves is_valid state")

	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 424242
	var control_rng := RandomNumberGenerator.new()
	control_rng.seed = 424242
	for i in range(10):
		test_rng.randi()
		control_rng.randi()
	svc_b.derive_fear_observations(receipt_b, test_snap, test_after)
	for i in range(10):
		_check(test_rng.randi() == control_rng.randi(), "AC3: RNG undisturbed by fear observation derivation")

	# 10. All 5 aliases return identical observations
	var obs_main := svc_b.post_settlement_fear_observations(receipt_b, test_snap, test_after)
	var obs_alias1 := svc_b.derive_fear_observations(receipt_b, test_snap, test_after)
	var obs_alias2 := svc_b.fear_observations(receipt_b, test_snap, test_after)
	var obs_alias3 := svc_b.derive_fray_fear_observations(receipt_b, test_snap, test_after)
	var obs_alias4 := svc_b.post_settlement_observations(receipt_b, test_snap, test_after)
	_check(obs_alias1 == obs_main, "AC3: derive_fear_observations alias matches")
	_check(obs_alias2 == obs_main, "AC3: fear_observations alias matches")
	_check(obs_alias3 == obs_main, "AC3: derive_fray_fear_observations alias matches")
	_check(obs_alias4 == obs_main, "AC3: post_settlement_observations alias matches")

	# 11. Two-argument form (omitting opening snapshot, using claimed snapshot)
	var obs_two_arg := svc_b.derive_fear_observations(receipt_b, test_after)
	_check(obs_two_arg == obs_main, "AC3: two-argument form matches three-argument form")

	# 12. Snapshot variations: dictionary with "heroes" or "party"
	var after_dict_party := {"party": test_after.duplicate(true)}
	var obs_dict_party := svc_b.derive_fear_observations(receipt_b, test_snap, after_dict_party)
	_check(obs_dict_party == obs_main, "AC3: after_roster as dict with party matches")

	var after_dict_heroes := {"heroes": test_after.duplicate(true)}
	var obs_dict_heroes := svc_b.derive_fear_observations(receipt_b, test_snap, after_dict_heroes)
	_check(obs_dict_heroes == obs_main, "AC3: after_roster as dict with heroes matches")


func _test_require_candle_room_shipped_bedwarmer() -> void:
	var source := FileAccess.get_file_as_string("res://data/events/stitched_route_effects.json")
	var doc: Variant = JSON.parse_string(source)
	_check(doc is Dictionary and doc.has("events"), "AC1: loads stitched_route_effects.json")
	var bedwarmer: Dictionary = {}
	if doc is Dictionary and doc.has("events"):
		for ev in doc["events"]:
			if ev is Dictionary and ev.get("id") == "v3_cinder_brass_bedwarmer":
				bedwarmer = (ev as Dictionary).duplicate(true)
				break
	_check(not bedwarmer.is_empty(), "AC1: genuine shipped Bedwarmer record found")
	var record_snapshot: Dictionary = bedwarmer.duplicate(true)

	# AC1: Candle 100, gold 60, four dolls: preview quotes unavailable, original deltas, empty fray
	var snap_100 := _gold_scraps_four(100, 4, 60, [10, 20, 30, 40])
	var before_100: Dictionary = snap_100.duplicate(true)
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 998877
	var guard_state: int = rng_guard.state

	var svc_100 := RunStitchedEventConsequence.new(bedwarmer)
	_check(svc_100.is_valid() and not svc_100.is_claimed(), "AC1: visit opens")
	var prev_100: Dictionary = svc_100.preview(snap_100)
	_check(prev_100.get("ok") == true and int(prev_100.get("candle")) == 100, "AC1: preview ok")
	var rent_100 := _entry(prev_100, "rent_ember_lid")
	_check(rent_100.get("available") == false
		and int(rent_100.get("candle")) == 100
		and int(rent_100.get("candle_delta")) == 22
		and int(rent_100.get("gold")) == 60
		and int(rent_100.get("gold_delta")) == -11
		and int(rent_100.get("fray_delta")) == 5
		and rent_100.get("fray") == {},
		"AC1: rent_ember_lid unavailable at candle 100, preserving base purse and empty fray intent")
	_check(_entry(prev_100, "sift_cooling_ashes").get("available") == true, "AC1: sift available")
	_check(_entry(prev_100, "leave").get("available") == true, "AC1: leave available")

	# choose("rent_ember_lid") refused without latching, without mutating snapshot or record, no gold spent
	_assert_rejected(svc_100, "rent_ember_lid", snap_100, 100, "AC1: rent_ember_lid rejected at candle 100")
	_check(svc_100.is_valid() and not svc_100.is_claimed(), "AC1: visit remains unclaimed after refusal")
	_check(snap_100 == before_100, "AC1: snapshot unchanged by refusal")
	_check(bedwarmer == record_snapshot, "AC1: source record unchanged by refusal")
	_check(rng_guard.state == guard_state, "AC1: RNG undisturbed by refusal")

	# AC3: Sift cooling ashes succeeds on the same visit after refusal
	var sift_receipt: Dictionary = svc_100.choose("sift_cooling_ashes", snap_100)
	_check(sift_receipt.get("ok") == true
		and int(sift_receipt.get("candle")) == 88
		and int(sift_receipt.get("scraps")) == 6
		and sift_receipt.get("fray") == {"warden": -6, "seamstress": -6, "tinker": -6, "button_golem": -6},
		"AC3: sift succeeds on same visit after rent refusal")
	_check(svc_100.is_claimed() and not svc_100.is_valid(), "AC3: visit latches on sift")

	# AC3: Leave succeeds on an independent full-candle visit after refusal
	var svc_leave := RunStitchedEventConsequence.new(bedwarmer)
	var snap_leave := _gold_scraps_four(100, 4, 60, [10, 20, 30, 40])
	_assert_rejected(svc_leave, "rent_ember_lid", snap_leave, 100, "AC3: refusal on independent visit")
	var leave_receipt: Dictionary = svc_leave.choose("leave", snap_leave)
	_check(leave_receipt.get("ok") == true
		and int(leave_receipt.get("candle")) == 100
		and leave_receipt.get("fray") == {},
		"AC3: leave succeeds after refusal at candle 100")
	_check(svc_leave.is_claimed() and not svc_leave.is_valid(), "AC3: visit latches on leave")

	# AC2: Candle 99 and gold >= 11 (tested with exact gold 11)
	var snap_99 := _gold_scraps_four(99, 4, 11, [10, 20, 30, 40])
	var before_99: Dictionary = snap_99.duplicate(true)
	var svc_99 := RunStitchedEventConsequence.new(bedwarmer)
	var prev_99: Dictionary = svc_99.preview(snap_99)
	var rent_99 := _entry(prev_99, "rent_ember_lid")
	_check(rent_99.get("available") == true
		and int(rent_99.get("candle")) == 100
		and int(rent_99.get("gold")) == 0
		and rent_99.get("fray") == {"warden": 5, "seamstress": 5, "tinker": 5, "button_golem": 5},
		"AC2: candle 99 with gold 11 quotes available, clamped candle 100, gold 0, fray +5")
	var receipt_99: Dictionary = svc_99.choose("rent_ember_lid", snap_99)
	_check(receipt_99.get("ok") == true
		and int(receipt_99.get("candle")) == 100
		and int(receipt_99.get("gold")) == 0
		and int(receipt_99.get("gold_delta")) == -11
		and receipt_99.get("fray") == {"warden": 5, "seamstress": 5, "tinker": 5, "button_golem": 5},
		"AC2: candle 99 with gold 11 claims rent_ember_lid, clamped candle 100, gold 0, fray +5")
	_check(svc_99.is_claimed() and not svc_99.is_valid(), "AC2: latched once")
	_assert_rejected(svc_99, "rent_ember_lid", snap_99, 99, "AC2: replay refusal")
	_assert_rejected(svc_99, "leave", snap_99, 99, "AC2: spent visit refuses alternative")
	_check(snap_99 == before_99, "AC2: snapshot undisturbed")

	# AC2: Candle 40 and gold 60 yields candle 62 and gold 49
	var snap_40 := _gold_scraps_four(40, 4, 60, [10, 20, 30, 40])
	var svc_40 := RunStitchedEventConsequence.new(bedwarmer)
	var prev_40: Dictionary = svc_40.preview(snap_40)
	var rent_40 := _entry(prev_40, "rent_ember_lid")
	_check(rent_40.get("available") == true
		and int(rent_40.get("candle")) == 62
		and int(rent_40.get("gold")) == 49
		and rent_40.get("fray") == {"warden": 5, "seamstress": 5, "tinker": 5, "button_golem": 5},
		"AC2: candle 40 and gold 60 quotes candle 62 and gold 49")
	var receipt_40: Dictionary = svc_40.choose("rent_ember_lid", snap_40)
	_check(receipt_40.get("ok") == true
		and int(receipt_40.get("candle")) == 62
		and int(receipt_40.get("gold")) == 49
		and receipt_40.get("fray") == {"warden": 5, "seamstress": 5, "tinker": 5, "button_golem": 5},
		"AC2: candle 40 and gold 60 claims candle 62 and gold 49")

	# AC3: Underfunded gold 10 with candle 40 (candle < 100)
	var snap_underfunded := _gold_scraps_four(40, 4, 10, [10, 20, 30, 40])
	var before_under: Dictionary = snap_underfunded.duplicate(true)
	var svc_under := RunStitchedEventConsequence.new(bedwarmer)
	var prev_under: Dictionary = svc_under.preview(snap_underfunded)
	var rent_under := _entry(prev_under, "rent_ember_lid")
	_check(rent_under.get("available") == false
		and int(rent_under.get("candle")) == 40
		and int(rent_under.get("gold")) == 10
		and rent_under.get("fray") == {},
		"AC3: underfunded gold 10 quotes rent_ember_lid unavailable")
	_check(_entry(prev_under, "sift_cooling_ashes").get("available") == true,
		"AC3: sift remains available on underfunded visit")
	_assert_rejected(svc_under, "rent_ember_lid", snap_underfunded, 40,
		"AC3: underfunded rent refused without latching")
	_check(svc_under.is_valid() and not svc_under.is_claimed(), "AC3: visit open after underfunded refusal")
	_check(snap_underfunded == before_under, "AC3: underfunded snapshot untouched")
	var under_sift: Dictionary = svc_under.choose("sift_cooling_ashes", snap_underfunded)
	_check(under_sift.get("ok") == true and int(under_sift.get("candle")) == 28,
		"AC3: free salvage claims on underfunded visit after refusal")


func _test_require_candle_room_fixtures_and_lost_dolls() -> void:
	# 1. Resource-free candle room gate preserves legacy 8-key preview and 7-key receipt
	var free_gated_event := _event([
		_choice("ember_breeze", "Warm the party.", {
			"target": "party", "candle": 15, "fray": 2, "require_candle_room": true,
		}),
		_choice("leave", "Leave.", _effect(0, 0)),
	], "ev_free_candle_room")
	var legacy_preview_keys := ["available", "candle", "candle_delta", "choice_id", "fray", "fray_delta", "hero_id", "target"]
	legacy_preview_keys.sort()
	var legacy_receipt_keys := ["candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target"]
	legacy_receipt_keys.sort()

	# At candle 100: unavailable, legacy 8-key preview entry
	var snap_100 := _four(100, [10, 20, 30, 40])
	var svc_free_100 := RunStitchedEventConsequence.new(free_gated_event)
	var prev_free_100 := svc_free_100.preview(snap_100)
	var breeze_entry_100 := _entry(prev_free_100, "ember_breeze")
	_check(breeze_entry_100.get("available") == false
		and _receipt_keys(breeze_entry_100) == legacy_preview_keys,
		"AC4: free candle-room choice has exact legacy 8-key preview entry when full")
	_assert_rejected(svc_free_100, "ember_breeze", snap_100, 100, "AC4: free choice rejected at candle 100")

	# At candle 50: available, exact legacy 7-key receipt
	var snap_50 := _four(50, [10, 20, 30, 40])
	var svc_free_50 := RunStitchedEventConsequence.new(free_gated_event)
	var prev_free_50 := svc_free_50.preview(snap_50)
	var breeze_entry_50 := _entry(prev_free_50, "ember_breeze")
	_check(breeze_entry_50.get("available") == true
		and int(breeze_entry_50.get("candle")) == 65
		and _receipt_keys(breeze_entry_50) == legacy_preview_keys,
		"AC4: free candle-room choice has exact legacy 8-key preview entry when eligible")
	var receipt_50 := svc_free_50.choose("ember_breeze", snap_50)
	_check(receipt_50.get("ok") == true
		and int(receipt_50.get("candle")) == 65
		and _receipt_keys(receipt_50) == legacy_receipt_keys,
		"AC4: free candle-room choice has exact legacy 7-key receipt")

	# Ungated choice at candle 100 still available (omitting require_candle_room preserves legacy)
	var ungated_event := _event([
		_choice("ungated_ember", "Add light.", _effect(15, 2)),
		_choice("leave", "Leave.", _effect(0, 0)),
	], "ev_ungated")
	var svc_ungated := RunStitchedEventConsequence.new(ungated_event)
	var prev_ungated := svc_ungated.preview(snap_100)
	_check(_entry(prev_ungated, "ungated_ember").get("available") == true
		and int(_entry(prev_ungated, "ungated_ember").get("candle")) == 100,
		"AC3: omitting require_candle_room preserves legacy candle clamp at 100")

	# 2. Lost doll recipient flags
	var party_with_lost := [
		{"id": "warden", "fray": 20, "lost": true},
		{"id": "seamstress", "fray": 30, "lost": false},
		{"id": "tinker", "fray": 40, "lost": false},
		{"id": "button_golem", "fray": 50, "lost": false},
	]
	var snap_lost := {"candle": 90, "party": party_with_lost, "gold": 50}
	var gated_gold_event := _event([
		_choice("paid_warm", "Warm active party.", {
			"target": "party", "candle": 20, "fray": 5, "gold": -10, "require_candle_room": true,
		}),
		_choice("hero_warm", "Warm seamstress.", {
			"target": "hero", "hero_id": "seamstress", "candle": 20, "fray": 5, "gold": -10, "require_candle_room": true,
		}),
		_choice("lost_hero_warm", "Warm lost warden.", {
			"target": "hero", "hero_id": "warden", "candle": 20, "fray": 5, "gold": -10, "require_candle_room": true,
		}),
	], "ev_lost_check")

	var svc_lost := RunStitchedEventConsequence.new(gated_gold_event)
	var prev_lost := svc_lost.preview(snap_lost)
	# Party target: only non-lost heroes receive fray intent
	var paid_warm_entry := _entry(prev_lost, "paid_warm")
	_check(paid_warm_entry.get("available") == true
		and paid_warm_entry.get("fray") == {"seamstress": 5, "tinker": 5, "button_golem": 5},
		"AC2: lost hero omitted from fray intents on party target with require_candle_room")
	var lost_hero_entry := _entry(prev_lost, "lost_hero_warm")
	_check(lost_hero_entry.get("available") == false and lost_hero_entry.get("fray") == {},
		"AC4: targeting a lost hero is unavailable")
	_assert_rejected(svc_lost, "lost_hero_warm", snap_lost, 90, "AC4: lost hero target refused")

	# If all heroes are lost, party target with fray benefit is unavailable
	var all_lost_party := [
		{"id": "warden", "fray": 20, "lost": true},
		{"id": "seamstress", "fray": 30, "lost": true},
	]
	var snap_all_lost := {"candle": 90, "party": all_lost_party, "gold": 50}
	var svc_all_lost := RunStitchedEventConsequence.new(gated_gold_event)
	var prev_all_lost := svc_all_lost.preview(snap_all_lost)
	_check(_entry(prev_all_lost, "paid_warm").get("available") == false,
		"AC4: party choice with benefits unavailable when all heroes lost")


func _test_require_candle_room_schema_and_rejections() -> void:
	var snap_40 := _gold_four(40, 60, [10, 20, 30, 40])
	var expected_malformed_preview_keys := [
		"available", "candle", "candle_delta", "choice_id", "fray", "fray_delta", "hero_id", "target"
	]
	expected_malformed_preview_keys.sort()

	# 1. Bad gate values: must be strictly native bool true
	var bad_gate_values: Array = [
		false,
		0,
		1,
		"true",
		"false",
		"1",
		"",
		" ",
		1.0,
		0.0,
		null,
		[true],
		{"require_candle_room": true},
	]
	for idx in range(bad_gate_values.size()):
		var bad_gate: Variant = bad_gate_values[idx]
		for target_mode in ["party", "hero"]:
			var broken_effect := {
				"target": target_mode,
				"candle": 22,
				"fray": 5,
				"require_candle_room": bad_gate,
			}
			if target_mode == "hero":
				broken_effect["hero_id"] = "seamstress"
			var broken_choice := _choice("broken_gate", "Bad gate.", broken_effect)
			var svc := RunStitchedEventConsequence.new(_event([
				broken_choice,
				_choice("leave", "Leave.", _effect(0, 0)),
			]))
			var prev := svc.preview(snap_40)
			var broken_entry := _entry(prev, "broken_gate")
			_check(prev.get("ok") == true
				and broken_entry.get("available") == false
				and broken_entry.get("candle_delta") == null
				and broken_entry.get("fray_delta") == null
				and int(broken_entry.get("candle")) == 40
				and broken_entry.get("fray") == {}
				and _receipt_keys(broken_entry) == expected_malformed_preview_keys,
				"AC4: bad require_candle_room %d (%s) is malformed with null deltas" % [idx, target_mode])
			_assert_rejected(svc, "broken_gate", snap_40, 40,
				"AC4: bad require_candle_room %d (%s) commit rejected" % [idx, target_mode])
			var leave_rec := svc.choose("leave", snap_40)
			_check(leave_rec.get("ok") == true and int(leave_rec.get("candle")) == 40,
				"AC4: leave claims on same visit after bad gate %d (%s)" % [idx, target_mode])

	# 2. Bad candle values with require_candle_room: true
	# Strictly positive native integer required: reject zero, negative, fractional, strings, non-numbers
	var bad_room_candle_deltas: Array = [
		0,
		-1,
		-22,
		-100,
		-9223372036854775807,
		22.5,
		0.5,
		-0.5,
		-22.5,
		"22",
		"0",
		"-22",
		true,
		false,
		null,
		INF,
		-INF,
		NAN,
		[22],
		{"candle": 22},
	]
	for idx in range(bad_room_candle_deltas.size()):
		var bad_candle: Variant = bad_room_candle_deltas[idx]
		for target_mode in ["party", "hero"]:
			var broken_effect := {
				"target": target_mode,
				"candle": bad_candle,
				"fray": 5,
				"require_candle_room": true,
			}
			if target_mode == "hero":
				broken_effect["hero_id"] = "seamstress"
			var broken_choice := _choice("broken_candle", "Bad candle.", broken_effect)
			var valid_choice := _choice("valid_room", "Valid room.", {
				"target": "party", "candle": 22, "fray": 5, "require_candle_room": true,
			})
			var svc := RunStitchedEventConsequence.new(_event([
				broken_choice,
				valid_choice,
				_choice("leave", "Leave.", _effect(0, 0)),
			]))
			var prev := svc.preview(snap_40)
			var broken_entry := _entry(prev, "broken_candle")
			_check(prev.get("ok") == true
				and broken_entry.get("available") == false
				and broken_entry.get("candle_delta") == null
				and broken_entry.get("fray_delta") == null
				and int(broken_entry.get("candle")) == 40
				and broken_entry.get("fray") == {}
				and _entry(prev, "valid_room").get("available") == true,
				"AC4: bad room candle delta %d (%s) is malformed while sibling stays available" % [idx, target_mode])
			_assert_rejected(svc, "broken_candle", snap_40, 40,
				"AC4: bad room candle delta %d (%s) commit rejected" % [idx, target_mode])
			var valid_rec := svc.choose("valid_room", snap_40)
			_check(valid_rec.get("ok") == true and int(valid_rec.get("candle")) == 62,
				"AC4: valid sibling claims after bad room candle %d (%s)" % [idx, target_mode])

	# 3. Contradictory gates and unrecognized keys
	var structural_errors: Array = [
		# both require_candle_room and require_full_candle
		{"id": "both_gates", "text": "Both candle gates.", "stitched_effect": {
			"candle": 22, "fray": 5, "target": "party",
			"require_candle_room": true, "require_full_candle": true,
		}},
		# unrecognized key alongside require_candle_room
		{"id": "extra_key", "text": "Extra key.", "stitched_effect": {
			"candle": 22, "fray": 5, "target": "party",
			"require_candle_room": true, "bogus_field": 42,
		}},
		# party with hero_id alongside require_candle_room
		{"id": "party_hero_id", "text": "Party with hero_id.", "stitched_effect": {
			"candle": 22, "fray": 5, "target": "party",
			"hero_id": "warden", "require_candle_room": true,
		}},
	]
	for idx in range(structural_errors.size()):
		var broken_def: Dictionary = structural_errors[idx]
		var svc := RunStitchedEventConsequence.new(_event([
			broken_def,
			_choice("leave", "Leave.", _effect(0, 0)),
		]))
		var prev := svc.preview(snap_40)
		var broken_entry := _entry(prev, broken_def["id"])
		_check(prev.get("ok") == true
			and broken_entry.get("available") == false
			and broken_entry.get("candle_delta") == null
			and broken_entry.get("fray_delta") == null,
			"AC4: structural error %d (%s) is malformed" % [idx, broken_def["id"]])
		_assert_rejected(svc, broken_def["id"], snap_40, 40,
			"AC4: structural error %d (%s) commit rejected" % [idx, broken_def["id"]])
		var leave_rec := svc.choose("leave", snap_40)
		_check(leave_rec.get("ok") == true and int(leave_rec.get("candle")) == 40,
			"AC4: leave claims after structural error %d" % idx)


func _test_wren_fear_ac1_projections() -> void:
	# AC1: Authentic choice with native signed fear and a valid 0..100 Wren snapshot yields a single
	# kid fear_delta plus projected fear in both preview and committed receipt:
	# 40+5=45, 40-8=32, 99+5=100 and 2-5=0.
	# The focused test proves this for target=party and hero without multiplying by party count.

	var cases: Array = [
		{"base": 40, "delta": 5, "expected": 45, "label": "40 + 5 = 45"},
		{"base": 40, "delta": -8, "expected": 32, "label": "40 - 8 = 32"},
		{"base": 99, "delta": 5, "expected": 100, "label": "99 + 5 = 100 (upper clamp)"},
		{"base": 2, "delta": -5, "expected": 0, "label": "2 - 5 = 0 (lower clamp)"},
		{"base": 40, "delta": 0, "expected": 40, "label": "40 + 0 = 40 (zero delta)"},
	]

	# Test across party sizes: 1, 2, 3, and 4 canonical heroes.
	var party_fixtures: Array = [
		{"name": "1-hero", "pairs": [["warden", 50]]},
		{"name": "2-hero", "pairs": [["warden", 50], ["seamstress", 60]]},
		{"name": "3-hero", "pairs": [["warden", 50], ["seamstress", 60], ["tinker", 70]]},
		{"name": "4-hero", "pairs": [["warden", 50], ["seamstress", 60], ["tinker", 70], ["button_golem", 80]]},
	]

	for p_fix in party_fixtures:
		var p_name: String = p_fix["name"]
		var pairs: Array = p_fix["pairs"]
		var hero_count: int = pairs.size()

		for case_def in cases:
			var base_fear: int = case_def["base"]
			var fear_delta: int = case_def["delta"]
			var expected_fear: int = case_def["expected"]
			var c_label: String = case_def["label"]

			# 1. Party target
			var ev_party := _event([
				_choice("fear_opt", "Endure the fear.", _fear_effect(15, 0, fear_delta, "party")),
				_choice("leave", "Leave.", _effect(0, 0, "party")),
			], "ev_fear_party_" + p_name)

			var snap_party := _fear_snapshot(45, base_fear, pairs)
			var svc_party := RunStitchedEventConsequence.new(ev_party)
			_check(svc_party.is_valid() and not svc_party.is_claimed(), "AC1: (%s, %s) party service initialized valid and unclaimed" % [p_name, c_label])

			var prev_party := svc_party.preview(snap_party)
			_check(prev_party.get("ok") == true, "AC1: (%s, %s) party preview ok" % [p_name, c_label])
			var entry_party := _entry(prev_party, "fear_opt")
			_check(entry_party.get("available") == true, "AC1: (%s, %s) party entry available" % [p_name, c_label])
			_check(entry_party.get("fear_delta") == fear_delta, "AC1: (%s, %s) preview raw fear_delta matches authored" % [p_name, c_label])
			_check(entry_party.get("fear") == expected_fear, "AC1: (%s, %s) preview projected fear clamped to expected (scalar, not multiplied by party size %d)" % [p_name, c_label, hero_count])
			_check(entry_party.get("candle") == 60, "AC1: (%s, %s) candle projected correctly" % [p_name, c_label])
			_check(entry_party.get("fray") == {}, "AC1: (%s, %s) fear never written into hero fray map" % [p_name, c_label])

			var rec_party := svc_party.choose("fear_opt", snap_party)
			_check(rec_party.get("ok") == true, "AC1: (%s, %s) party choose succeeded" % [p_name, c_label])
			_check(svc_party.is_claimed() == true, "AC1: (%s, %s) service is now claimed" % [p_name, c_label])
			_check(not svc_party.is_valid(), "AC1: (%s, %s) service is not valid after claim" % [p_name, c_label])
			_check(rec_party.get("fear_delta") == fear_delta, "AC1: (%s, %s) receipt raw fear_delta matches authored" % [p_name, c_label])
			_check(rec_party.get("fear") == expected_fear, "AC1: (%s, %s) receipt projected fear matches preview" % [p_name, c_label])
			_check(rec_party.get("fear_delta") == entry_party.get("fear_delta"), "AC1: (%s, %s) preview/choose fear_delta equality" % [p_name, c_label])
			_check(rec_party.get("fear") == entry_party.get("fear"), "AC1: (%s, %s) preview/choose fear equality" % [p_name, c_label])
			_check(rec_party.get("fray") == {}, "AC1: (%s, %s) receipt fray map is empty" % [p_name, c_label])
			_check(_receipt_keys(rec_party) == ["candle", "choice_id", "event_id", "fear", "fear_delta", "fray", "hero_id", "ok", "target"],
				"AC1: (%s, %s) receipt has exact fear consequence keys" % [p_name, c_label])

			# Replay rejected
			_assert_rejected(svc_party, "fear_opt", snap_party, 45, "AC1: (%s, %s) party replay rejected" % [p_name, c_label])
			_assert_rejected(svc_party, "leave", snap_party, 45, "AC1: (%s, %s) alternative replay rejected" % [p_name, c_label])

			# 2. Hero target
			var ev_hero := _event([
				_choice("fear_opt", "Endure the fear.", _fear_effect(15, 0, fear_delta, "hero", "warden")),
				_choice("leave", "Leave.", _effect(0, 0, "hero", "warden")),
			], "ev_fear_hero_" + p_name)

			var snap_hero := _fear_snapshot(45, base_fear, pairs)
			var svc_hero := RunStitchedEventConsequence.new(ev_hero)
			var prev_hero := svc_hero.preview(snap_hero)
			var entry_hero := _entry(prev_hero, "fear_opt")
			_check(entry_hero.get("available") == true, "AC1: (%s, %s) hero entry available" % [p_name, c_label])
			_check(entry_hero.get("fear_delta") == fear_delta, "AC1: (%s, %s) hero preview fear_delta matches" % [p_name, c_label])
			_check(entry_hero.get("fear") == expected_fear, "AC1: (%s, %s) hero preview projected fear matches" % [p_name, c_label])
			_check(entry_hero.get("hero_id") == "warden", "AC1: (%s, %s) hero target names warden" % [p_name, c_label])

			var rec_hero := svc_hero.choose("fear_opt", snap_hero)
			_check(rec_hero.get("ok") == true, "AC1: (%s, %s) hero choose succeeded" % [p_name, c_label])
			_check(rec_hero.get("fear_delta") == fear_delta, "AC1: (%s, %s) hero receipt fear_delta matches" % [p_name, c_label])
			_check(rec_hero.get("fear") == expected_fear, "AC1: (%s, %s) hero receipt fear matches" % [p_name, c_label])
			_check(rec_hero.get("fear_delta") == entry_hero.get("fear_delta"), "AC1: (%s, %s) hero preview/choose fear_delta equality" % [p_name, c_label])
			_check(rec_hero.get("fear") == entry_hero.get("fear"), "AC1: (%s, %s) hero preview/choose fear equality" % [p_name, c_label])
			_check(rec_hero.get("hero_id") == "warden", "AC1: (%s, %s) hero receipt names warden" % [p_name, c_label])


func _test_wren_fear_ac2_refusals_and_alternatives() -> void:
	# AC2: Missing/invalid Wren input or malformed authored fear refuses only the affected choice;
	# valid alternative still commits and rejections preserve the one claim, snapshots,
	# global and supplied RNG. Focused refusal/retry tests prove this.

	var test_pairs: Array = [["warden", 50], ["seamstress", 60], ["tinker", 70], ["button_golem", 80]]

	# 1. Missing wren_fear in snapshot: refuses only fear choice; valid alternative commits.
	var missing_snap := _snapshot(50, test_pairs)
	var missing_before := missing_snap.duplicate(true)
	var ev_mixed := _event([
		_choice("fear_choice", "Face the terror.", _fear_effect(10, 0, 5, "party")),
		_choice("hero_fear_choice", "Warden faces terror.", _fear_effect(10, 0, -8, "hero", "warden")),
		_choice("leave", "Walk away.", _effect(0, 0, "party")),
	], "ev_wren_missing_test")

	var svc_missing := RunStitchedEventConsequence.new(ev_mixed)
	var prev_missing := svc_missing.preview(missing_snap)
	_check(prev_missing.get("ok") == true, "AC2: preview ok with missing wren_fear on mixed event")
	var entry_fear_party := _entry(prev_missing, "fear_choice")
	_check(entry_fear_party.get("available") == false
		and entry_fear_party.get("fear_delta") == 5
		and entry_fear_party.get("fear") == null
		and entry_fear_party.get("candle") == 50
		and entry_fear_party.get("fray") == {},
		"AC2: missing wren_fear makes fear choice unavailable with null projected fear and unchanged candle")
	var entry_fear_hero := _entry(prev_missing, "hero_fear_choice")
	_check(entry_fear_hero.get("available") == false
		and entry_fear_hero.get("fear_delta") == -8
		and entry_fear_hero.get("fear") == null,
		"AC2: missing wren_fear makes hero-targeted fear choice unavailable")
	var entry_leave := _entry(prev_missing, "leave")
	_check(entry_leave.get("available") == true and entry_leave.get("candle") == 50,
		"AC2: valid alternative Leave remains available when snapshot lacks wren_fear")

	# Rejections do not consume claim or mutate snapshot
	_assert_rejected(svc_missing, "fear_choice", missing_snap, 50, "AC2: missing wren_fear choose party rejected")
	_check(not svc_missing.is_claimed(), "AC2: service still unclaimed after fear_choice refusal")
	_check(missing_snap == missing_before, "AC2: snapshot untouched after fear_choice refusal")

	_assert_rejected(svc_missing, "hero_fear_choice", missing_snap, 50, "AC2: missing wren_fear choose hero rejected")
	_check(not svc_missing.is_claimed(), "AC2: service still unclaimed after hero_fear_choice refusal")
	_check(missing_snap == missing_before, "AC2: snapshot untouched after hero_fear_choice refusal")

	# Alternative commits
	var rec_leave := svc_missing.choose("leave", missing_snap)
	_check(rec_leave.get("ok") == true and rec_leave.get("candle") == 50,
		"AC2: alternative Leave commits successfully after fear refusals")
	_check(svc_missing.is_claimed() == true, "AC2: service claimed after Leave commit")
	_assert_rejected(svc_missing, "leave", missing_snap, 50, "AC2: replay Leave rejected after claim")
	_check(missing_snap == missing_before, "AC2: snapshot untouched after commit and replay")

	# 2. Invalid wren_fear values in snapshot:
	# Exercise: 101, -1, float (40.5, 40.0), string ("40"), bool (true, false), null, array, dict.
	var invalid_wren_fear_values: Array = [
		101, -1, 40.5, 40.0, "40", true, false, null, [], {}, 9223372036854775807, -9223372036854775807
	]

	for idx in range(invalid_wren_fear_values.size()):
		var bad_fear_val: Variant = invalid_wren_fear_values[idx]
		var bad_snap := _fear_snapshot(50, bad_fear_val, test_pairs)
		var bad_snap_before := bad_snap.duplicate(true)

		var svc_bad_snap := RunStitchedEventConsequence.new(ev_mixed)
		var prev_bad := svc_bad_snap.preview(bad_snap)
		_check(prev_bad.get("ok") == true, "AC2: invalid wren_fear %d preflights successfully" % idx)

		var bad_entry := _entry(prev_bad, "fear_choice")
		_check(bad_entry.get("available") == false
			and bad_entry.get("fear_delta") == 5
			and bad_entry.get("candle") == 50
			and bad_entry.get("fray") == {},
			"AC2: invalid wren_fear %d makes fear choice unavailable with authored fear_delta" % idx)

		var alt_entry := _entry(prev_bad, "leave")
		_check(alt_entry.get("available") == true and alt_entry.get("candle") == 50,
			"AC2: invalid wren_fear %d leaves alternative available" % idx)

		_assert_rejected(svc_bad_snap, "fear_choice", bad_snap, 50, "AC2: invalid wren_fear %d choose rejected" % idx)
		_check(not svc_bad_snap.is_claimed(), "AC2: invalid wren_fear %d does not latch visit" % idx)
		_check(bad_snap == bad_snap_before, "AC2: invalid wren_fear %d leaves snapshot untouched" % idx)

		# Alternative commits on the same instance
		var alt_rec := svc_bad_snap.choose("leave", bad_snap)
		_check(alt_rec.get("ok") == true and alt_rec.get("candle") == 50,
			"AC2: alternative commits on invalid wren_fear %d instance" % idx)
		_check(svc_bad_snap.is_claimed() == true, "AC2: invalid wren_fear %d latches after alt commit" % idx)
		_assert_rejected(svc_bad_snap, "leave", bad_snap, 50, "AC2: replay rejected after alt commit on %d" % idx)
		_check(bad_snap == bad_snap_before, "AC2: snapshot still untouched after alt commit on %d" % idx)

	# 3. Malformed authored fear in stitched_effect:
	# Exercise: float (5.5, 5.0), string ("5"), bool (true, false), null, array, dict.
	var malformed_fear_effects: Array = [
		5.5, 5.0, "5", true, false, null, [5], {"delta": 5}
	]

	var valid_snap_40 := _fear_snapshot(50, 40, test_pairs)
	var snap_40_before := valid_snap_40.duplicate(true)

	for idx in range(malformed_fear_effects.size()):
		var bad_effect_fear: Variant = malformed_fear_effects[idx]
		var ev_malformed := _event([
			_choice("broken_fear", "Corrupt delta.", {
				"candle": 10, "fray": 0, "target": "party", "fear": bad_effect_fear
			}),
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		], "ev_malformed_fear_%d" % idx)

		var svc_malformed := RunStitchedEventConsequence.new(ev_malformed)
		var prev_mal := svc_malformed.preview(valid_snap_40)
		_check(prev_mal.get("ok") == true, "AC2: malformed fear effect %d preflights" % idx)

		var broken_entry := _entry(prev_mal, "broken_fear")
		_check(broken_entry.get("available") == false
			and broken_entry.get("candle_delta") == null
			and broken_entry.get("fray_delta") == null
			and not broken_entry.has("fear_delta")
			and not broken_entry.has("fear"),
			"AC2: malformed fear effect %d has null deltas and no fear keys" % idx)

		_check(_entry(prev_mal, "leave").get("available") == true,
			"AC2: malformed fear effect %d leaves valid alternative available" % idx)

		_assert_rejected(svc_malformed, "broken_fear", valid_snap_40, 50,
			"AC2: malformed fear effect %d choose rejected" % idx)
		_check(not svc_malformed.is_claimed(), "AC2: malformed fear effect %d does not latch" % idx)
		_check(valid_snap_40 == snap_40_before, "AC2: malformed fear effect %d leaves snapshot untouched" % idx)

		var leave_rec := svc_malformed.choose("leave", valid_snap_40)
		_check(leave_rec.get("ok") == true and leave_rec.get("candle") == 50,
			"AC2: alternative commits after malformed fear effect %d refusal" % idx)
		_check(svc_malformed.is_claimed() == true, "AC2: latched after alternative commit on %d" % idx)
		_assert_rejected(svc_malformed, "leave", valid_snap_40, 50, "AC2: replay after alternative commit on %d" % idx)

	# 4. Structural errors alongside fear:
	var structural_fear_errors: Array = [
		{"id": "party_with_hero", "text": "Party with hero_id.", "stitched_effect": {
			"candle": 0, "fray": 0, "target": "party", "hero_id": "warden", "fear": 5
		}},
		{"id": "hero_missing_id", "text": "Hero missing hero_id.", "stitched_effect": {
			"candle": 0, "fray": 0, "target": "hero", "fear": 5
		}},
		{"id": "extra_key_fear", "text": "Extra key with fear.", "stitched_effect": {
			"candle": 0, "fray": 0, "target": "party", "fear": 5, "unknown_field": 123
		}},
	]

	for idx in range(structural_fear_errors.size()):
		var err_choice: Dictionary = structural_fear_errors[idx]
		var svc_struct := RunStitchedEventConsequence.new(_event([
			err_choice,
			_choice("leave", "Leave.", _effect(0, 0, "party")),
		]))
		var prev_struct := svc_struct.preview(valid_snap_40)
		var err_entry := _entry(prev_struct, err_choice["id"])
		_check(prev_struct.get("ok") == true
			and err_entry.get("available") == false
			and err_entry.get("candle_delta") == null
			and err_entry.get("fray_delta") == null,
			"AC2: structural fear error %d (%s) is malformed with null deltas" % [idx, err_choice["id"]])
		_assert_rejected(svc_struct, err_choice["id"], valid_snap_40, 50,
			"AC2: structural fear error %d (%s) rejected" % [idx, err_choice["id"]])
		var struct_leave := svc_struct.choose("leave", valid_snap_40)
		_check(struct_leave.get("ok") == true, "AC2: leave claims after structural error %d" % idx)

	# 5. Global and supplied RNG preservation:
	seed(20261108)
	var expected_global_rng := randi()
	seed(20261108)

	var control_rng := RandomNumberGenerator.new()
	control_rng.seed = 987654321
	var expected_supplied_rng := control_rng.randi()

	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 987654321

	var rng_service := RunStitchedEventConsequence.new(ev_mixed)
	rng_service.preview(missing_snap)
	rng_service.choose("fear_choice", missing_snap)
	rng_service.preview(valid_snap_40)
	var rng_leave_rec := rng_service.choose("leave", valid_snap_40)
	_check(rng_leave_rec.get("ok") == true, "AC2: RNG test leave committed")

	_check(randi() == expected_global_rng, "AC2: global RNG was never drawn during fear previews, refusals or choose")
	_check(test_rng.randi() == expected_supplied_rng, "AC2: supplied RNG was never drawn during fear operations")

	# 6. Input detachment and returned receipt mutation:
	var detach_snap := _fear_snapshot(50, 40, test_pairs)
	var detach_svc := RunStitchedEventConsequence.new(_event([
		_choice("fear_opt", "Gain fear.", _fear_effect(10, 0, 5, "party")),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_detach_fear"))

	var detach_receipt := detach_svc.choose("fear_opt", detach_snap)
	_check(detach_receipt.get("ok") == true and detach_receipt.get("fear") == 45, "AC2: detach choice committed")

	# Mutate returned receipt
	detach_receipt["fear"] = 999
	detach_receipt["fear_delta"] = -999
	detach_receipt["fray"]["warden"] = 100

	# Ensure second query / post_settlement helper fails closed on altered receipt
	var obs_altered := detach_svc.post_settlement_fear_observations(detach_receipt, detach_snap, [
		{"id": "warden", "fray": 60},
		{"id": "seamstress", "fray": 60},
		{"id": "tinker", "fray": 70},
		{"id": "button_golem", "fray": 80},
	])
	_check(obs_altered.is_empty(), "AC2: altered returned receipt fails closed in post_settlement_fear_observations")


func _test_wren_fear_ac3_shapes_and_invariants() -> void:
	# AC3: Fear-free choices retain their prior preview/receipt shapes, all existing admission/gating
	# and negative cases keep working, and fray-driven Wren observations still pass.
	# Focused existing suite and applicable regressions prove this.

	var test_pairs: Array = [["warden", 50], ["seamstress", 60], ["tinker", 70], ["button_golem", 80]]
	var legacy_preview_keys := ["available", "candle", "candle_delta", "choice_id", "fray", "fray_delta", "hero_id", "target"]
	legacy_preview_keys.sort()
	var legacy_receipt_keys := ["candle", "choice_id", "event_id", "fray", "hero_id", "ok", "target"]
	legacy_receipt_keys.sort()

	# 1. Pure fear-free event with snapshot containing wren_fear:
	var snap_with_fear := _fear_snapshot(50, 40, test_pairs)
	var legacy_svc := RunStitchedEventConsequence.new(_bargain_event())
	var legacy_prev := legacy_svc.preview(snap_with_fear)
	_check(legacy_prev.get("ok") == true, "AC3: legacy event preflights with wren_fear in snapshot")

	for entry in legacy_prev.get("choices", []):
		_check(_receipt_keys(entry) == legacy_preview_keys,
			"AC3: fear-free choices retain exact 8-key preview shape even when snapshot supplies wren_fear")

	var legacy_rec := legacy_svc.choose("bargain", snap_with_fear)
	_check(legacy_rec.get("ok") == true, "AC3: legacy choice claims successfully")
	_check(_receipt_keys(legacy_rec) == legacy_receipt_keys,
		"AC3: fear-free choice retains exact 7-key receipt shape without fear/fear_delta")

	# 2. Mixed event with fear-bearing and fear-free choices:
	var mixed_ev := _event([
		_choice("fear_opt", "Gain fear.", _fear_effect(10, 0, 5, "party")),
		_choice("free_opt", "Free option.", _effect(10, -10, "party")),
	], "ev_mixed_shape_test")

	var mixed_svc := RunStitchedEventConsequence.new(mixed_ev)
	var mixed_prev := mixed_svc.preview(snap_with_fear)
	var mixed_fear_entry := _entry(mixed_prev, "fear_opt")
	var mixed_free_entry := _entry(mixed_prev, "free_opt")

	var expected_fear_preview_keys := legacy_preview_keys.duplicate()
	expected_fear_preview_keys.append("fear")
	expected_fear_preview_keys.append("fear_delta")
	expected_fear_preview_keys.sort()

	_check(_receipt_keys(mixed_fear_entry) == expected_fear_preview_keys,
		"AC3: fear-bearing choice in mixed event has fear and fear_delta in preview")
	_check(_receipt_keys(mixed_free_entry) == legacy_preview_keys,
		"AC3: fear-free choice in mixed event retains exact 8-key preview without fear keys")

	# Choosing fear-free option on mixed event yields exact 7-key receipt:
	var mixed_free_rec := mixed_svc.choose("free_opt", snap_with_fear)
	_check(mixed_free_rec.get("ok") == true, "AC3: free choice on mixed event claimed")
	_check(_receipt_keys(mixed_free_rec) == legacy_receipt_keys,
		"AC3: free choice receipt on mixed event has exact 7-key receipt shape")

	# 3. Gating integration with fear choices:
	# A. required_hero gate:
	var req_hero_ev := _event([
		_choice("scarecrow_fear", "Scarecrow courage.", {
			"candle": 0, "fray": 0, "target": "party", "fear": -10, "required_hero": "scarecrow"
		}),
		_choice("warden_fear", "Warden courage.", {
			"candle": 0, "fray": 0, "target": "party", "fear": -10, "required_hero": "warden"
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_req_hero_fear")

	var req_svc := RunStitchedEventConsequence.new(req_hero_ev)
	var req_prev := req_svc.preview(snap_with_fear)
	_check(_entry(req_prev, "scarecrow_fear").is_empty(), "AC3: scarecrow fear choice hidden when scarecrow absent")
	_check(_entry(req_prev, "warden_fear").get("available") == true, "AC3: warden fear choice available when warden present")
	_assert_rejected(req_svc, "scarecrow_fear", snap_with_fear, 50, "AC3: scarecrow fear choice rejected on choose")

	var warden_rec := req_svc.choose("warden_fear", snap_with_fear)
	_check(warden_rec.get("ok") == true and warden_rec.get("fear") == 30 and warden_rec.get("fear_delta") == -10,
		"AC3: required_hero fear choice commits with projected fear 40 - 10 = 30")

	# B. min_fray gate:
	var min_fray_ev := _event([
		_choice("calm_fear", "Soothe high fray.", {
			"candle": 0, "fray": -10, "target": "party", "fear": 5, "min_fray": 65
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_min_fray_fear")

	var low_fray_snap := _fear_snapshot(50, 40, [["warden", 10], ["seamstress", 20]])
	var svc_low_fray := RunStitchedEventConsequence.new(min_fray_ev)
	_check(_entry(svc_low_fray.preview(low_fray_snap), "calm_fear").get("available") == false,
		"AC3: min_fray fear choice unavailable when all fray < 65")
	_assert_rejected(svc_low_fray, "calm_fear", low_fray_snap, 50, "AC3: min_fray fear choice rejected when fray < 65")

	var high_fray_snap := _fear_snapshot(50, 40, [["warden", 10], ["seamstress", 70]])
	var svc_high_fray := RunStitchedEventConsequence.new(min_fray_ev)
	_check(_entry(svc_high_fray.preview(high_fray_snap), "calm_fear").get("available") == true,
		"AC3: min_fray fear choice available when one hero has fray >= 65")
	var high_fray_rec := svc_high_fray.choose("calm_fear", high_fray_snap)
	_check(high_fray_rec.get("ok") == true and high_fray_rec.get("fear") == 45,
		"AC3: min_fray fear choice claims with projected fear 45")

	# C. Candle band gate:
	var band_ev := _event([
		_choice("bright_fear", "Bright flame dread.", {
			"candle": 0, "fray": 0, "target": "party", "fear": -5, "required_candle_band": "bright"
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_band_fear")

	var gloom_snap := _fear_snapshot(40, 40, test_pairs)
	var svc_gloom := RunStitchedEventConsequence.new(band_ev)
	_check(_entry(svc_gloom.preview(gloom_snap), "bright_fear").get("available") == false,
		"AC3: bright band fear choice unavailable at gloom candle 40")
	_assert_rejected(svc_gloom, "bright_fear", gloom_snap, 40, "AC3: bright band fear choice rejected at candle 40")

	var bright_snap := _fear_snapshot(85, 40, test_pairs)
	var svc_bright := RunStitchedEventConsequence.new(band_ev)
	_check(_entry(svc_bright.preview(bright_snap), "bright_fear").get("available") == true,
		"AC3: bright band fear choice available at bright candle 85")
	var bright_rec := svc_bright.choose("bright_fear", bright_snap)
	_check(bright_rec.get("ok") == true and bright_rec.get("fear") == 35,
		"AC3: bright band fear choice claims with projected fear 35")

	# D. Candle room gate:
	var room_ev := _event([
		_choice("room_fear", "Room fear.", {
			"candle": 10, "fray": 0, "target": "party", "fear": 5, "require_candle_room": true
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_room_fear")

	var full_candle_snap := _fear_snapshot(100, 40, test_pairs)
	var svc_full := RunStitchedEventConsequence.new(room_ev)
	_check(_entry(svc_full.preview(full_candle_snap), "room_fear").get("available") == false,
		"AC3: candle room fear choice unavailable at candle 100")
	_assert_rejected(svc_full, "room_fear", full_candle_snap, 100, "AC3: candle room fear choice rejected at 100")

	# E. Combination with wallet and HP:
	var combo_ev := _event([
		_choice("combo_fear", "Rich and terrifying.", {
			"candle": 5, "fray": 0, "target": "party", "fear": 7, "gold": -10, "scraps": 3, "hp": 2
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_combo_fear")

	var combo_snap := {
		"candle": 50,
		"party": [
			{"id": "warden", "fray": 20},
			{"id": "seamstress", "fray": 30},
		],
		"gold": 25,
		"scraps": 5,
		"wren_fear": 40,
	}
	var svc_combo := RunStitchedEventConsequence.new(combo_ev)
	var prev_combo := svc_combo.preview(combo_snap)
	var combo_entry := _entry(prev_combo, "combo_fear")
	_check(combo_entry.get("available") == true
		and combo_entry.get("fear") == 47
		and combo_entry.get("fear_delta") == 7
		and combo_entry.get("gold") == 15
		and combo_entry.get("scraps") == 8
		and combo_entry.get("hp") == {"warden": 2, "seamstress": 2},
		"AC3: combination of fear + gold + scraps + hp projects all values properly")

	var combo_rec := svc_combo.choose("combo_fear", combo_snap)
	_check(combo_rec.get("ok") == true
		and combo_rec.get("fear") == 47
		and combo_rec.get("fear_delta") == 7
		and combo_rec.get("gold") == 15
		and combo_rec.get("scraps") == 8
		and combo_rec.get("hp") == {"warden": 2, "seamstress": 2},
		"AC3: combination of fear + gold + scraps + hp commits with all receipt keys")

	# 4. Fray-driven Wren observations with a fear-bearing choice:
	var obs_ev := _event([
		_choice("fray_and_fear", "Horror and fray.", {
			"candle": 0, "fray": 20, "target": "party", "fear": 5
		}),
		_choice("leave", "Leave.", _effect(0, 0, "party")),
	], "ev_obs_fear")

	var obs_snap := _fear_four(50, 40, [30, 30, 30, 30])
	var obs_svc := RunStitchedEventConsequence.new(obs_ev)
	var obs_rec := obs_svc.choose("fray_and_fear", obs_snap)
	_check(obs_rec.get("ok") == true and obs_rec.get("fear") == 45, "AC3: fray and fear choice claimed")

	var after_roster := [
		{"id": "warden", "fray": 50},
		{"id": "seamstress", "fray": 50},
		{"id": "tinker", "fray": 50},
		{"id": "button_golem", "fray": 50},
	]
	var observations := obs_svc.post_settlement_fear_observations(obs_rec, obs_snap, after_roster)
	_check(observations.size() == 4, "AC3: fray-driven observations pass for all 4 dolls on fear-bearing receipt")
	for obs in observations:
		_check(obs.get("kind") == "fray_gain" and obs.get("amount") == 20,
			"AC3: observation kind is fray_gain and amount is 20: " + str(obs.get("hero_id")))

	# Fail closed when receipt's fear or fear_delta is altered:
	var altered_fear_rec := obs_rec.duplicate(true)
	altered_fear_rec["fear"] = 80
	_check(obs_svc.post_settlement_fear_observations(altered_fear_rec, obs_snap, after_roster).is_empty(),
		"AC3: post_settlement_fear_observations fails closed when fear is altered")

	var altered_fear_delta_rec := obs_rec.duplicate(true)
	altered_fear_delta_rec["fear_delta"] = 15
	_check(obs_svc.post_settlement_fear_observations(altered_fear_delta_rec, obs_snap, after_roster).is_empty(),
		"AC3: post_settlement_fear_observations fails closed when fear_delta is altered")







