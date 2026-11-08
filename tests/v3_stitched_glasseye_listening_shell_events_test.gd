extends SceneTree
## Deterministic headless coverage for the two glass-eye clock and
## whispering-shell doll-scale roadside Events appended to the native
## Stitched route-effect catalog (res://data/events/stitched_route_effects.json):
## the Glass-Eyed Pendulum and the Skirting Listening Shell.
##
## EXPECTED and FUNDED_FINAL are independent hardcoded copies of the authored
## stories and the funded settlement oracle; they never read the production
## catalog or the consequence service back as their oracle. Only per-ID
## membership is asserted on the catalog: no catalog total, no full ordered ID
## list and no fixed pool position, so peer batches can land in the same catalog
## without clashing. Every preview row and receipt is compared against an exact
## hardcoded dictionary, which also proves the ABSENCE of the optional
## gold/scraps keys on choices that do not carry them. No flow under test draws
## from any RNG; a seeded guard proves that, and an explicit draw proves the
## guard is live.

const EVENTS_PATH := "res://data/events/stitched_route_effects.json"
const BASE_CANDLE := 42
const BASE_GOLD := 30
const BASE_SCRAPS := 5
const PARTY_FRAYS := [["warden", 20], ["seamstress", 15], ["tinker", 0], ["lantern_monk", 5]]

## Independent literal copies of the two authored stories, including the exact
## signed stitched_effect fields.
const EXPECTED := {
	"v3_glasseye_pendulum": {
		"title": "The Glass-Eyed Pendulum",
		"description": "A toppled hall clock blocks the doll-sized corridor. Its pendulum swings past a black glass eye, and a button-eyed keeper holds the wick beneath its ticking teeth.",
		"choices": [
			{"id": "feed_brass_wick", "text": "Feed the clock's wick and quiet the dolls", "effect": {"target": "party", "candle": 24, "fray": -6, "scraps": -2, "require_candle_room": true, "min_fray": 1}},
			{"id": "pluck_clock_tooth", "text": "Break off a brass tooth and take its spool", "effect": {"target": "party", "candle": -12, "fray": 10, "scraps": 3, "require_full_candle": true}},
			{"id": "leave", "text": "Back away from the ticking glass", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_skirting_listening_shell": {
		"title": "The Skirting Listening Shell",
		"description": "A pale spiral shell is sewn into the tall skirting board. Four little voices whisper from its mouth while the corridor candle bends toward the wall.",
		"choices": [
			{"id": "monk_answer_echo", "text": "Let the Lantern Monk answer the whisper", "effect": {"target": "party", "candle": 16, "fray": 6, "required_hero": "lantern_monk", "require_candle_room": true}},
			{"id": "buy_shell_silence", "text": "Pay to quiet the voices", "effect": {"target": "party", "candle": 0, "fray": -12, "gold": -14, "min_fray": 1}},
			{"id": "leave", "text": "Leave the shell to whisper", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
}

## Independent funded oracle from the fixture snapshot {candle 42, gold 30,
## scraps 5, frays warden 20 / seamstress 15 / tinker 0 / lantern_monk 5}:
## the exact projected candle, the raw per-hero fray delta and the exact
## settled purse per choice.
const FUNDED_FINAL := {
	"v3_glasseye_pendulum": {
		"feed_brass_wick": {"candle": 66, "candle_delta": 24, "fray": -6, "scraps": 3, "scraps_delta": -2},
		"pluck_clock_tooth": {"candle": 30, "candle_delta": -12, "fray": 10, "scraps": 8, "scraps_delta": 3},
		"leave": {"candle": 42, "candle_delta": 0, "fray": 0},
	},
	"v3_skirting_listening_shell": {
		"monk_answer_echo": {"candle": 58, "candle_delta": 16, "fray": 6},
		"buy_shell_silence": {"candle": 42, "candle_delta": 0, "fray": -12, "gold": 16, "gold_delta": -14},
		"leave": {"candle": 42, "candle_delta": 0, "fray": 0},
	},
}

## Earlier anchors that must remain in the catalog with their original titles.
const ANCHOR_TITLES := {
	"moth_infestation": "Moth Infestation",
	"needle_toll": "The Needle Toll",
	"v3_keyhole_choir": "The Keyhole Choir",
	"v3_moonblack_paperweight": "The Moonblack Paperweight",
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
	_test_funded_contract()
	_test_wick_boundaries()
	_test_tooth_candle_boundaries()
	_test_shell_answer_boundaries()
	_test_shell_silence_boundaries()
	_test_lost_hero_cannot_satisfy_min_fray()
	_test_determinism_and_rng_guard()
	_check(source_document == source_snapshot, "the catalog document is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_glasseye_listening_shell_events_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_source() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "stitched_route_effects.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parsed: int = parser.parse(text)
	_check(parsed == OK, "stitched_route_effects.json parses through JSON")
	if parsed != OK:
		return
	_check(parser.data is Dictionary, "the route-effect catalog is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the route-effect catalog carries an events array")
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


## Each new record exists exactly once with only the native Event envelope,
## its verbatim story, exactly three distinct choices carrying only
## id/text/stitched_effect, and the exact signed effects.
func _test_source_records() -> void:
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		_check(int(source_counts.get(event_id, 0)) == 1,
			"exactly one authored record for " + event_id)
		if not source_by_id.has(event_id):
			continue
		var record: Dictionary = source_by_id[event_id]
		_check(record.keys().size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"the new record uses only the native Event envelope: " + event_id)
		_check(record.get("title") == contract["title"],
			"the authored title matches: " + event_id)
		_check(record.get("description") == contract["description"],
			"the authored description matches: " + event_id)
		var choices: Variant = record.get("choices")
		if not choices is Array or (choices as Array).size() != 3:
			_check(false, "the new record carries exactly three choices: " + event_id)
			continue
		var seen: Dictionary = {}
		for choice in choices:
			if not choice is Dictionary:
				_check(false, "each new choice is an object: " + event_id)
				continue
			var authored: Dictionary = choice
			_check(authored.keys().size() == 3 and authored.has("id")
				and authored.has("text") and authored.has("stitched_effect"),
				"each new choice uses only id/text/stitched_effect: " + event_id)
			seen[authored.get("id")] = true
		_check(seen.size() == 3, "the three new choice IDs are distinct: " + event_id)
		var by_id := {}
		for choice in choices:
			by_id[(choice as Dictionary).get("id")] = choice
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			if not by_id.has(choice_id):
				_check(false, "the record keeps its choice " + choice_id + ": " + event_id)
				continue
			var authored_choice: Dictionary = by_id[choice_id]
			_check(authored_choice.get("text") == definition["text"],
				"the authored choice text matches: " + event_id + " / " + choice_id)
			var effect: Variant = authored_choice.get("stitched_effect")
			if not effect is Dictionary:
				_check(false, "the authored choice carries a stitched_effect: " + event_id + " / " + choice_id)
				continue
			var expected_effect: Dictionary = definition["effect"]
			_check((effect as Dictionary).size() == expected_effect.size(),
				"the effect carries exactly its authored keys: " + event_id + " / " + choice_id)
			for key in expected_effect:
				_check((effect as Dictionary).has(key)
					and (effect as Dictionary)[key] == expected_effect[key],
					"the authored effect field matches exactly: " + event_id + " / " + choice_id + " / " + str(key))


## The named earlier anchors stay present with their original titles.
func _test_anchor_records() -> void:
	for anchor_id in ANCHOR_TITLES:
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"the earlier anchor keeps exactly one record: " + anchor_id)
		if not source_by_id.has(anchor_id):
			continue
		var record: Dictionary = source_by_id[anchor_id]
		_check(record.get("title") == ANCHOR_TITLES[anchor_id],
			"the anchor keeps its original title: " + anchor_id)
		_check(record.get("choices") is Array
			and (record.get("choices") as Array).size() >= 2,
			"the anchor keeps its choices: " + anchor_id)


## Funded previews and claims agree with the independent oracle on all six
## choices; a settled visit cannot be replayed, previews close after the
## claim, and neither the caller snapshot nor the record is ever mutated.
func _test_funded_contract() -> void:
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 717171
	var guard_state: int = rng_guard.state
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var table: Dictionary = FUNDED_FINAL[event_id]
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		_check(RunEventChoice.new(record).is_valid(),
			"the shipped envelope validator accepts the fresh record: " + event_id)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var row: Dictionary = table[choice_id]
			_check(int(row["candle"]) == BASE_CANDLE + int(row["candle_delta"]),
				"the funded candle agrees with its hardcoded delta: " + event_id + " / " + choice_id)
			if row.has("scraps"):
				_check(int(row["scraps"]) == BASE_SCRAPS + int(row["scraps_delta"]),
					"the funded scraps agree with their hardcoded delta: " + event_id + " / " + choice_id)
			if row.has("gold"):
				_check(int(row["gold"]) == BASE_GOLD + int(row["gold_delta"]),
					"the funded gold agrees with its hardcoded delta: " + event_id + " / " + choice_id)
			var snapshot := _funded_snapshot()
			var before: Dictionary = snapshot.duplicate(true)
			var service := RunStitchedEventConsequence.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"a fresh visit opens: " + event_id + " / " + choice_id)
			var preview: Dictionary = service.preview(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and int(preview.get("candle")) == BASE_CANDLE,
				"funded preview succeeds: " + event_id + " / " + choice_id)
			_check(preview.get("choices", []).size() == 3,
				"funded preview lists all three choices: " + event_id)
			var entry := _entry(preview, choice_id)
			_check(entry == _expected_entry(choice_id, row),
				"funded preview matches the hardcoded oracle exactly: " + event_id + " / " + choice_id)
			var receipt: Dictionary = service.choose(choice_id, snapshot)
			_check(receipt == _expected_receipt(event_id, choice_id, row),
				"funded claim settles the hardcoded oracle exactly: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches exactly once: " + event_id + " / " + choice_id)
			_check(service.choose(choice_id, snapshot) == _refusal(BASE_CANDLE),
				"a settled choice cannot be replayed: " + event_id + " / " + choice_id)
			var other_id := _other_choice_id(contract, choice_id)
			_check(service.choose(other_id, snapshot) == _refusal(BASE_CANDLE),
				"no alternate choice claims a spent visit: " + event_id + " / " + choice_id)
			_check(service.choose("forged_choice", snapshot) == _refusal(BASE_CANDLE),
				"an unknown choice cannot claim a spent visit: " + event_id + " / " + choice_id)
			_check(service.preview(snapshot) == _denied_preview(),
				"a spent visit offers no further preview: " + event_id + " / " + choice_id)
			_check(snapshot == before and record == record_snapshot,
				"a funded flow mutates neither snapshot nor record: " + event_id + " / " + choice_id)
	_check(settlements == 6, "every one of the six authored choices settles once when funded")
	_check(rng_guard.state == guard_state,
		"previews and claims never touch an unrelated seeded RNG")


## The paid wick feed is denied at scraps 1, at all-zero fray and at a full
## candle; each refusal claims nothing, mutates nothing, and another legal
## option still commits on the very same visit.
func _test_wick_boundaries() -> void:
	var event_id := "v3_glasseye_pendulum"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	var record_snapshot: Dictionary = record.duplicate(true)

	# 1. scraps 1 cannot pay the two-scrap wick feed; the tooth still commits.
	var snapshot_scraps := _funded_snapshot()
	snapshot_scraps["scraps"] = 1
	var before_scraps: Dictionary = snapshot_scraps.duplicate(true)
	var service_scraps := RunStitchedEventConsequence.new(record)
	var preview_scraps: Dictionary = service_scraps.preview(snapshot_scraps)
	_check(preview_scraps.get("ok") == true, "an under-scrapped wick visit still previews")
	var wick_scraps := _entry(preview_scraps, "feed_brass_wick")
	_check(wick_scraps.get("available") == false
		and int(wick_scraps.get("candle")) == BASE_CANDLE
		and int(wick_scraps.get("candle_delta")) == 24
		and int(wick_scraps.get("fray_delta")) == -6
		and wick_scraps.get("fray") == {}
		and int(wick_scraps.get("scraps")) == 1
		and int(wick_scraps.get("scraps_delta")) == -2,
		"scraps 1 quotes the wick feed unavailable with the unchanged purse and empty fray")
	_check(_entry(preview_scraps, "leave").get("available") == true,
		"leave stays selectable at scraps 1")
	_check(service_scraps.choose("feed_brass_wick", snapshot_scraps) == _refusal(BASE_CANDLE),
		"the under-scrapped wick feed is refused")
	_check(service_scraps.is_valid() and not service_scraps.is_claimed(),
		"the under-scrapped refusal keeps the visit open and unclaimed")
	_check(snapshot_scraps == before_scraps,
		"the under-scrapped refusal changes no balance")
	var tooth_receipt: Dictionary = service_scraps.choose("pluck_clock_tooth", snapshot_scraps)
	var expected_tooth := {
		"ok": true,
		"event_id": event_id,
		"choice_id": "pluck_clock_tooth",
		"target": "party",
		"hero_id": "",
		"candle": 30,
		"fray": _fray_map(10),
		"scraps": 4,
		"scraps_delta": 3,
	}
	_check(tooth_receipt == expected_tooth,
		"the tooth still commits on the under-scrapped visit, settling scraps 4")
	_check(service_scraps.is_claimed() and not service_scraps.is_valid(),
		"the post-refusal tooth claim latches once")
	_check(snapshot_scraps == before_scraps and record == record_snapshot,
		"the under-scrapped flow mutates neither snapshot nor record")

	# 2. All surviving fray 0 cannot satisfy min_fray 1.
	var snapshot_zero := _funded_snapshot()
	snapshot_zero["party"] = _party_with_frays([["warden", 0], ["seamstress", 0], ["tinker", 0], ["lantern_monk", 0]])
	var before_zero: Dictionary = snapshot_zero.duplicate(true)
	var service_zero := RunStitchedEventConsequence.new(record)
	var preview_zero: Dictionary = service_zero.preview(snapshot_zero)
	var wick_zero := _entry(preview_zero, "feed_brass_wick")
	_check(wick_zero.get("available") == false
		and int(wick_zero.get("candle")) == BASE_CANDLE
		and wick_zero.get("fray") == {},
		"all-zero fray quotes the wick feed unavailable with empty fray intents")
	_check(_entry(preview_zero, "leave").get("available") == true,
		"leave stays selectable at all-zero fray")
	_check(service_zero.choose("feed_brass_wick", snapshot_zero) == _refusal(BASE_CANDLE),
		"the all-zero-fray wick feed is refused")
	_check(service_zero.is_valid() and not service_zero.is_claimed(),
		"the all-zero-fray refusal keeps the visit open and unclaimed")
	var leave_zero: Dictionary = service_zero.choose("leave", snapshot_zero)
	_check(leave_zero == _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"]),
		"leave commits on the same visit after the all-zero-fray refusal")
	_check(service_zero.is_claimed() and not service_zero.is_valid(),
		"the post-refusal leave claim latches once")
	_check(snapshot_zero == before_zero, "the all-zero-fray flow mutates no snapshot")

	# 3. A full candle has no candle room for the +24 wick feed.
	var snapshot_full := _funded_snapshot()
	snapshot_full["candle"] = 100
	var before_full: Dictionary = snapshot_full.duplicate(true)
	var service_full := RunStitchedEventConsequence.new(record)
	var preview_full: Dictionary = service_full.preview(snapshot_full)
	var wick_full := _entry(preview_full, "feed_brass_wick")
	_check(wick_full.get("available") == false
		and int(wick_full.get("candle")) == 100
		and int(wick_full.get("candle_delta")) == 24
		and wick_full.get("fray") == {},
		"a full candle quotes the wick feed unavailable with empty fray intents")
	_check(_entry(preview_full, "leave").get("available") == true,
		"leave stays selectable at a full candle")
	_check(service_full.choose("feed_brass_wick", snapshot_full) == _refusal(100),
		"the full-candle wick feed is refused")
	_check(service_full.is_valid() and not service_full.is_claimed(),
		"the full-candle refusal keeps the visit open and unclaimed")
	var leave_full: Dictionary = service_full.choose("leave", snapshot_full)
	var expected_full_leave := {
		"ok": true,
		"event_id": event_id,
		"choice_id": "leave",
		"target": "party",
		"hero_id": "",
		"candle": 100,
		"fray": {},
	}
	_check(leave_full == expected_full_leave,
		"leave commits on the same visit after the full-candle refusal")
	_check(service_full.is_claimed() and not service_full.is_valid(),
		"the post-refusal leave claim latches once")
	_check(snapshot_full == before_full, "the full-candle flow mutates no snapshot")


## The -12 candle tooth needs a full 12-candle base: candle 11 is denied while
## candle 12 settles exactly to a snuffed candle.
func _test_tooth_candle_boundaries() -> void:
	var event_id := "v3_glasseye_pendulum"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)

	# 1. candle 11 cannot afford the 12-candle debit.
	var snapshot_11 := _funded_snapshot()
	snapshot_11["candle"] = 11
	var before_11: Dictionary = snapshot_11.duplicate(true)
	var service_11 := RunStitchedEventConsequence.new(record)
	var preview_11: Dictionary = service_11.preview(snapshot_11)
	var tooth_11 := _entry(preview_11, "pluck_clock_tooth")
	_check(tooth_11.get("available") == false
		and int(tooth_11.get("candle")) == 11
		and int(tooth_11.get("candle_delta")) == -12
		and int(tooth_11.get("fray_delta")) == 10
		and tooth_11.get("fray") == {}
		and int(tooth_11.get("scraps")) == BASE_SCRAPS
		and int(tooth_11.get("scraps_delta")) == 3,
		"candle 11 quotes the tooth unavailable with the unchanged purse and empty fray")
	_check(_entry(preview_11, "leave").get("available") == true,
		"leave stays selectable at candle 11")
	_check(service_11.choose("pluck_clock_tooth", snapshot_11) == _refusal(11),
		"the tooth is refused at candle 11")
	_check(service_11.is_valid() and not service_11.is_claimed(),
		"the candle-11 refusal keeps the visit open and unclaimed")
	var leave_11: Dictionary = service_11.choose("leave", snapshot_11)
	var expected_leave_11 := {
		"ok": true,
		"event_id": event_id,
		"choice_id": "leave",
		"target": "party",
		"hero_id": "",
		"candle": 11,
		"fray": {},
	}
	_check(leave_11 == expected_leave_11,
		"leave commits on the same visit after the candle-11 refusal")
	_check(service_11.is_claimed() and not service_11.is_valid(),
		"the post-refusal leave claim latches once")
	_check(snapshot_11 == before_11, "the candle-11 flow mutates no snapshot")

	# 2. candle 12 settles exactly to candle 0.
	var snapshot_12 := _funded_snapshot()
	snapshot_12["candle"] = 12
	var before_12: Dictionary = snapshot_12.duplicate(true)
	var service_12 := RunStitchedEventConsequence.new(record)
	var preview_12: Dictionary = service_12.preview(snapshot_12)
	var tooth_12 := _entry(preview_12, "pluck_clock_tooth")
	_check(tooth_12.get("available") == true
		and int(tooth_12.get("candle")) == 0
		and int(tooth_12.get("candle_delta")) == -12
		and tooth_12.get("fray") == _fray_map(10)
		and int(tooth_12.get("scraps")) == 8,
		"candle 12 quotes the tooth available, settling candle 0 and scraps 8")
	var receipt_12: Dictionary = service_12.choose("pluck_clock_tooth", snapshot_12)
	var expected_receipt_12 := {
		"ok": true,
		"event_id": event_id,
		"choice_id": "pluck_clock_tooth",
		"target": "party",
		"hero_id": "",
		"candle": 0,
		"fray": _fray_map(10),
		"scraps": 8,
		"scraps_delta": 3,
	}
	_check(receipt_12 == expected_receipt_12,
		"candle 12 claims the tooth settling candle 0, scraps 8 and fray +10 each")
	_check(service_12.is_claimed() and not service_12.is_valid(),
		"the candle-12 claim latches once")
	_check(service_12.choose("pluck_clock_tooth", snapshot_12) == _refusal(12),
		"the spent candle-12 visit refuses a replay")
	_check(snapshot_12 == before_12, "the candle-12 flow mutates no snapshot")


## The monk-gated echo is hidden when the Lantern Monk is absent and denied at
## a full candle; the remaining options stay claimable in both cases.
func _test_shell_answer_boundaries() -> void:
	var event_id := "v3_skirting_listening_shell"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	var record_snapshot: Dictionary = record.duplicate(true)

	# 1. Without the Lantern Monk the echo is hidden from preview and refused.
	var snapshot_no_monk := {
		"candle": BASE_CANDLE,
		"party": [
			{"id": "warden", "fray": 20},
			{"id": "seamstress", "fray": 15},
			{"id": "tinker", "fray": 0},
			{"id": "yarn_ranger", "fray": 5},
		],
		"gold": BASE_GOLD,
		"scraps": BASE_SCRAPS,
	}
	var before_no_monk: Dictionary = snapshot_no_monk.duplicate(true)
	var service_no_monk := RunStitchedEventConsequence.new(record)
	var preview_no_monk: Dictionary = service_no_monk.preview(snapshot_no_monk)
	_check(preview_no_monk.get("ok") == true,
		"a monkless party still previews the shell")
	_check(preview_no_monk.get("choices", []).size() == 2,
		"the monk-gated echo is hidden from the monkless preview")
	_check(_entry(preview_no_monk, "monk_answer_echo") == {},
		"no preview row exists for the hidden echo")
	_check(_entry(preview_no_monk, "buy_shell_silence").get("available") == true,
		"the paid silence stays selectable without the monk")
	_check(_entry(preview_no_monk, "leave").get("available") == true,
		"leave stays selectable without the monk")
	_check(service_no_monk.choose("monk_answer_echo", snapshot_no_monk) == _refusal(BASE_CANDLE),
		"the hidden echo is refused by choose")
	_check(service_no_monk.is_valid() and not service_no_monk.is_claimed(),
		"the hidden-echo refusal keeps the visit open and unclaimed")
	var silence_no_monk: Dictionary = service_no_monk.choose("buy_shell_silence", snapshot_no_monk)
	var expected_silence_no_monk := {
		"ok": true,
		"event_id": event_id,
		"choice_id": "buy_shell_silence",
		"target": "party",
		"hero_id": "",
		"candle": BASE_CANDLE,
		"fray": {"warden": -12, "seamstress": -12, "tinker": -12, "yarn_ranger": -12},
		"gold": 16,
		"gold_delta": -14,
	}
	_check(silence_no_monk == expected_silence_no_monk,
		"the paid silence commits for the monkless party, easing fray on every living doll")
	_check(service_no_monk.is_claimed() and not service_no_monk.is_valid(),
		"the post-refusal silence claim latches once")
	_check(snapshot_no_monk == before_no_monk and record == record_snapshot,
		"the monkless flow mutates neither snapshot nor record")

	# 2. With the monk present, a full candle still denies the +16 echo.
	var snapshot_full := _funded_snapshot()
	snapshot_full["candle"] = 100
	var before_full: Dictionary = snapshot_full.duplicate(true)
	var service_full := RunStitchedEventConsequence.new(record)
	var preview_full: Dictionary = service_full.preview(snapshot_full)
	_check(preview_full.get("choices", []).size() == 3,
		"a full candle keeps the echo visible in preview")
	var echo_full := _entry(preview_full, "monk_answer_echo")
	_check(echo_full.get("available") == false
		and int(echo_full.get("candle")) == 100
		and int(echo_full.get("candle_delta")) == 16
		and echo_full.get("fray") == {},
		"a full candle quotes the echo unavailable with empty fray intents")
	_check(_entry(preview_full, "leave").get("available") == true,
		"leave stays selectable at a full candle")
	_check(service_full.choose("monk_answer_echo", snapshot_full) == _refusal(100),
		"the echo is refused at a full candle")
	_check(service_full.is_valid() and not service_full.is_claimed(),
		"the full-candle refusal keeps the visit open and unclaimed")
	var leave_full: Dictionary = service_full.choose("leave", snapshot_full)
	var expected_leave_full := {
		"ok": true,
		"event_id": event_id,
		"choice_id": "leave",
		"target": "party",
		"hero_id": "",
		"candle": 100,
		"fray": {},
	}
	_check(leave_full == expected_leave_full,
		"leave commits on the same visit after the full-candle echo refusal")
	_check(service_full.is_claimed() and not service_full.is_valid(),
		"the post-refusal leave claim latches once")
	_check(snapshot_full == before_full, "the full-candle echo flow mutates no snapshot")


## The paid silence is denied at gold 13 and when no living doll carries fray;
## leave still commits on the very same visit.
func _test_shell_silence_boundaries() -> void:
	var event_id := "v3_skirting_listening_shell"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)

	# 1. gold 13 cannot pay the 14-gold hush.
	var snapshot_gold := _funded_snapshot()
	snapshot_gold["gold"] = 13
	var before_gold: Dictionary = snapshot_gold.duplicate(true)
	var service_gold := RunStitchedEventConsequence.new(record)
	var preview_gold: Dictionary = service_gold.preview(snapshot_gold)
	var silence_gold := _entry(preview_gold, "buy_shell_silence")
	_check(silence_gold.get("available") == false
		and int(silence_gold.get("candle")) == BASE_CANDLE
		and int(silence_gold.get("fray_delta")) == -12
		and silence_gold.get("fray") == {}
		and int(silence_gold.get("gold")) == 13
		and int(silence_gold.get("gold_delta")) == -14,
		"gold 13 quotes the silence unavailable with the unchanged purse and empty fray")
	_check(_entry(preview_gold, "leave").get("available") == true,
		"leave stays selectable at gold 13")
	_check(service_gold.choose("buy_shell_silence", snapshot_gold) == _refusal(BASE_CANDLE),
		"the underpaid silence is refused")
	_check(service_gold.is_valid() and not service_gold.is_claimed(),
		"the underpaid refusal keeps the visit open and unclaimed")
	_check(snapshot_gold == before_gold,
		"the underpaid refusal changes no balance")
	var leave_gold: Dictionary = service_gold.choose("leave", snapshot_gold)
	_check(leave_gold == _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"]),
		"leave commits on the same visit after the underpaid refusal")
	_check(service_gold.is_claimed() and not service_gold.is_valid(),
		"the post-refusal leave claim latches once")
	_check(snapshot_gold == before_gold, "the underpaid flow mutates no snapshot")

	# 2. No living fray means min_fray 1 cannot be satisfied.
	var snapshot_zero := _funded_snapshot()
	snapshot_zero["party"] = _party_with_frays([["warden", 0], ["seamstress", 0], ["tinker", 0], ["lantern_monk", 0]])
	var before_zero: Dictionary = snapshot_zero.duplicate(true)
	var service_zero := RunStitchedEventConsequence.new(record)
	var preview_zero: Dictionary = service_zero.preview(snapshot_zero)
	var silence_zero := _entry(preview_zero, "buy_shell_silence")
	_check(silence_zero.get("available") == false
		and int(silence_zero.get("candle")) == BASE_CANDLE
		and silence_zero.get("fray") == {},
		"all-zero fray quotes the silence unavailable with empty fray intents")
	_check(_entry(preview_zero, "leave").get("available") == true,
		"leave stays selectable at all-zero fray")
	_check(service_zero.choose("buy_shell_silence", snapshot_zero) == _refusal(BASE_CANDLE),
		"the all-zero-fray silence is refused")
	_check(service_zero.is_valid() and not service_zero.is_claimed(),
		"the all-zero-fray refusal keeps the visit open and unclaimed")
	var leave_zero: Dictionary = service_zero.choose("leave", snapshot_zero)
	_check(leave_zero == _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"]),
		"leave commits on the same visit after the all-zero-fray silence refusal")
	_check(service_zero.is_claimed() and not service_zero.is_valid(),
		"the post-refusal leave claim latches once")
	_check(snapshot_zero == before_zero, "the all-zero-fray flow mutates no snapshot")


## A LOST hero's fray never satisfies min_fray and never receives a fray intent:
## with the warden LOST at fray 100 and three living dolls at fray 0, both
## min_fray bargains are denied, while the monk echo pays fray only to the
## living dolls.
func _test_lost_hero_cannot_satisfy_min_fray() -> void:
	var lost_party: Array = [
		{"id": "warden", "fray": 100, "lost": true},
		{"id": "seamstress", "fray": 0},
		{"id": "tinker", "fray": 0},
		{"id": "lantern_monk", "fray": 0},
	]

	# 1. The wick feed is denied: only the LOST warden carries fray.
	var clock_record: Dictionary = (source_by_id["v3_glasseye_pendulum"] as Dictionary).duplicate(true)
	var snapshot_wick := {"candle": BASE_CANDLE, "party": lost_party, "gold": BASE_GOLD, "scraps": BASE_SCRAPS}
	var before_wick: Dictionary = snapshot_wick.duplicate(true)
	var service_wick := RunStitchedEventConsequence.new(clock_record)
	var preview_wick: Dictionary = service_wick.preview(snapshot_wick)
	var wick_entry := _entry(preview_wick, "feed_brass_wick")
	_check(wick_entry.get("available") == false
		and int(wick_entry.get("candle")) == BASE_CANDLE
		and wick_entry.get("fray") == {},
		"a LOST hero's fray cannot satisfy the wick feed's min_fray")
	_check(service_wick.choose("feed_brass_wick", snapshot_wick) == _refusal(BASE_CANDLE),
		"the wick feed is refused when only a LOST hero is frayed")
	_check(service_wick.is_valid() and not service_wick.is_claimed(),
		"the LOST-hero refusal keeps the clock visit open and unclaimed")
	var leave_wick: Dictionary = service_wick.choose("leave", snapshot_wick)
	_check(leave_wick == _expected_receipt("v3_glasseye_pendulum", "leave", FUNDED_FINAL["v3_glasseye_pendulum"]["leave"]),
		"leave commits on the same visit after the LOST-hero wick refusal")
	_check(service_wick.is_claimed() and not service_wick.is_valid(),
		"the post-refusal leave claim latches once")
	_check(snapshot_wick == before_wick, "the LOST-hero wick flow mutates no snapshot")

	# 2. The paid silence is denied the same way.
	var shell_record: Dictionary = (source_by_id["v3_skirting_listening_shell"] as Dictionary).duplicate(true)
	var snapshot_silence := {"candle": BASE_CANDLE, "party": lost_party, "gold": BASE_GOLD, "scraps": BASE_SCRAPS}
	var before_silence: Dictionary = snapshot_silence.duplicate(true)
	var service_silence := RunStitchedEventConsequence.new(shell_record)
	var preview_silence: Dictionary = service_silence.preview(snapshot_silence)
	var silence_entry := _entry(preview_silence, "buy_shell_silence")
	_check(silence_entry.get("available") == false
		and int(silence_entry.get("gold")) == BASE_GOLD
		and silence_entry.get("fray") == {},
		"a LOST hero's fray cannot satisfy the silence's min_fray")
	_check(service_silence.choose("buy_shell_silence", snapshot_silence) == _refusal(BASE_CANDLE),
		"the silence is refused when only a LOST hero is frayed")
	_check(service_silence.is_valid() and not service_silence.is_claimed(),
		"the LOST-hero refusal keeps the shell visit open and unclaimed")

	# 3. On that same shell visit the monk echo commits, fraying only living dolls.
	var echo_receipt: Dictionary = service_silence.choose("monk_answer_echo", snapshot_silence)
	var expected_echo := {
		"ok": true,
		"event_id": "v3_skirting_listening_shell",
		"choice_id": "monk_answer_echo",
		"target": "party",
		"hero_id": "",
		"candle": 58,
		"fray": {"seamstress": 6, "tinker": 6, "lantern_monk": 6},
	}
	_check(echo_receipt == expected_echo,
		"the monk echo settles on the LOST-warden party, fraying only the living dolls")
	_check(service_silence.is_claimed() and not service_silence.is_valid(),
		"the post-refusal echo claim latches once")
	_check(snapshot_silence == before_silence, "the LOST-hero shell flow mutates no snapshot")


## Same-seed fresh visits are identical and no flow draws from a caller RNG;
## an explicit draw proves the guard can actually observe a change.
func _test_determinism_and_rng_guard() -> void:
	var clock_record: Dictionary = (source_by_id["v3_glasseye_pendulum"] as Dictionary).duplicate(true)
	var shell_record: Dictionary = (source_by_id["v3_skirting_listening_shell"] as Dictionary).duplicate(true)

	var first_clock := _replay_visit(clock_record, "feed_brass_wick")
	var second_clock := _replay_visit(clock_record, "feed_brass_wick")
	_check(first_clock["preview"] == second_clock["preview"]
		and first_clock["receipt"] == second_clock["receipt"],
		"two fresh same-seed clock visits project and settle identically")
	_check(second_clock["receipt"] == _expected_receipt("v3_glasseye_pendulum", "feed_brass_wick", FUNDED_FINAL["v3_glasseye_pendulum"]["feed_brass_wick"]),
		"the replayed clock visit still settles the hardcoded oracle")

	var first_shell := _replay_visit(shell_record, "monk_answer_echo")
	var second_shell := _replay_visit(shell_record, "monk_answer_echo")
	_check(first_shell["preview"] == second_shell["preview"]
		and first_shell["receipt"] == second_shell["receipt"],
		"two fresh same-seed shell visits project and settle identically")

	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 828282
	var guard_state: int = rng_guard.state
	var snapshot := _funded_snapshot()
	var service := RunStitchedEventConsequence.new(clock_record)
	service.preview(snapshot)
	service.choose("leave", snapshot)
	_check(rng_guard.state == guard_state,
		"a preview and claim leave a fixed-seed caller RNG unchanged")
	var drawn: int = rng_guard.randi_range(0, 99)
	_check(drawn >= 0 and drawn <= 99 and rng_guard.state != guard_state,
		"an explicit draw advances the guard RNG, proving the guard is live")


func _replay_visit(record: Dictionary, choice_id: String) -> Dictionary:
	var snapshot := _funded_snapshot()
	var service := RunStitchedEventConsequence.new(record)
	var preview: Dictionary = service.preview(snapshot)
	var receipt: Dictionary = service.choose(choice_id, snapshot)
	return {"preview": preview, "receipt": receipt}


func _funded_snapshot() -> Dictionary:
	return {"candle": BASE_CANDLE, "party": _party_with_frays(PARTY_FRAYS), "gold": BASE_GOLD, "scraps": BASE_SCRAPS}


func _party_with_frays(frays: Array) -> Array:
	var party: Array = []
	for pair in frays:
		party.append({"id": pair[0], "fray": pair[1]})
	return party


func _fray_map(delta: int) -> Dictionary:
	var intents: Dictionary = {}
	if delta == 0:
		return intents
	for pair in PARTY_FRAYS:
		intents[pair[0]] = delta
	return intents


func _expected_entry(choice_id: String, row: Dictionary) -> Dictionary:
	var entry := {
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle_delta": int(row["candle_delta"]),
		"fray_delta": int(row["fray"]),
		"available": true,
		"candle": int(row["candle"]),
		"fray": _fray_map(int(row["fray"])),
	}
	if row.has("scraps"):
		entry["scraps_delta"] = int(row["scraps_delta"])
		entry["scraps"] = int(row["scraps"])
	if row.has("gold"):
		entry["gold_delta"] = int(row["gold_delta"])
		entry["gold"] = int(row["gold"])
	return entry


func _expected_receipt(event_id: String, choice_id: String, row: Dictionary) -> Dictionary:
	var receipt := {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": int(row["candle"]),
		"fray": _fray_map(int(row["fray"])),
	}
	if row.has("scraps"):
		receipt["scraps_delta"] = int(row["scraps_delta"])
		receipt["scraps"] = int(row["scraps"])
	if row.has("gold"):
		receipt["gold_delta"] = int(row["gold_delta"])
		receipt["gold"] = int(row["gold"])
	return receipt


func _entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _other_choice_id(contract: Dictionary, choice_id: String) -> String:
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		if definition["id"] != choice_id:
			return definition["id"]
	return ""


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


func _denied_preview() -> Dictionary:
	return {"ok": false, "event_id": "", "candle": 0, "choices": []}
