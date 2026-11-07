extends SceneTree
## Independent authored contracts and settlement oracles for the four appended
## doll-scale roadside bargains. Each record is looked up by ID in the production
## catalog, checked verbatim, then driven through the shipped RunEventChoice
## service for funded, refused, zero-wallet and isolation flows. The test avoids
## catalog totals, ordered listings and index positions, and it does not depend
## on any rotation script.
const PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 50, "scraps": 5}
const ZERO := {"gold": 0, "scraps": 0}
const SHUTTER := "v3_shutterhook_signal"
const TYPEWRITER := "v3_ink_ribbon_typewriter"
const CORK := "v3_cork_lid_lookout"
const DOORBELL := "v3_porcelain_doorbell"
const ANCHORS := ["v3_raincoat_bridge", "v3_sugar_tongs_span"]
const EXPECTED := {
	SHUTTER: {
		"id": SHUTTER, "title": "The Shutter-Hook Signal",
		"description": "A towering nursery shutter swings over the ragdoll road; a squat oxblood watch doll holds an amber lantern beneath its giant brass hook while a red-thread warning bell taps the frame.",
		"choices": [
			{"id": "reseat_sentry_hook", "text": "Refasten the warning hook (spend 2 scraps; earn 29 gold)", "outcome": {"gold": 29, "scraps": -2}},
			{"id": "buy_storm_hems", "text": "Buy three coils of storm-hem thread (spend 16 gold; gain 3 scraps)", "outcome": {"gold": -16, "scraps": 3}},
			{"id": "leave", "text": "Leave the warning bell ringing into the night", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	TYPEWRITER: {
		"id": TYPEWRITER, "title": "The Ink-Ribbon Typewriter",
		"description": "House-sized typewriter keys rise from a puddle of midnight ink like stepping stones; a round button-eyed typist gathers torn plum ribbons in a single trembling candlebeam.",
		"choices": [
			{"id": "gather_fallen_ribbon", "text": "Collect two loose ribbon windings (gain 2 scraps)", "outcome": {"gold": 0, "scraps": 2}},
			{"id": "replace_ink_spool", "text": "Retie the ink spool (spend 1 scrap; earn 20 gold)", "outcome": {"gold": 20, "scraps": -1}},
			{"id": "leave", "text": "Let the last typewriter key fall silent", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	CORK: {
		"id": CORK, "title": "The Cork-Lid Lookout",
		"description": "A saucer-wide cork stopper shelters a tiny moss-cloth sentry above a black inkwell; its stitched warning pennant hangs from an immense silver pin in the candlelit draft.",
		"choices": [
			{"id": "buy_cork_lacing", "text": "Buy three strands of cork-lid lacing (spend 18 gold; gain 3 scraps)", "outcome": {"gold": -18, "scraps": 3}},
			{"id": "seal_lookout_cork", "text": "Seal the sentry's leaking roof (spend 2 scraps; earn 31 gold)", "outcome": {"gold": 31, "scraps": -2}},
			{"id": "leave", "text": "Leave the pennant floating above the black ink", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	DOORBELL: {
		"id": DOORBELL, "title": "The Porcelain Doorbell",
		"description": "A cracked porcelain bell hangs above a giant cupboard door; a plump slate-blue latchkeeper in mismatched button boots holds its fallen red-thread pull cord under a wan candle.",
		"choices": [
			{"id": "rethread_bell_puller", "text": "Mend the porcelain bell pull (spend 1 scrap; earn 22 gold)", "outcome": {"gold": 22, "scraps": -1}},
			{"id": "buy_bellcord", "text": "Buy two braided bell cords (spend 12 gold; gain 2 scraps)", "outcome": {"gold": -12, "scraps": 2}},
			{"id": "leave", "text": "Pass the cupboard before the bell tolls", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
}
# Independent funded balances from the brief, never computed from production outcomes.
const FINAL := {
	SHUTTER: {"reseat_sentry_hook": {"gold": 79, "scraps": 3}, "buy_storm_hems": {"gold": 34, "scraps": 8}, "leave": {"gold": 50, "scraps": 5}},
	TYPEWRITER: {"gather_fallen_ribbon": {"gold": 50, "scraps": 7}, "replace_ink_spool": {"gold": 70, "scraps": 4}, "leave": {"gold": 50, "scraps": 5}},
	CORK: {"buy_cork_lacing": {"gold": 32, "scraps": 8}, "seal_lookout_cork": {"gold": 81, "scraps": 3}, "leave": {"gold": 50, "scraps": 5}},
	DOORBELL: {"rethread_bell_puller": {"gold": 72, "scraps": 4}, "buy_bellcord": {"gold": 38, "scraps": 7}, "leave": {"gold": 50, "scraps": 5}},
}
# One unit below each paid choice's gold or scrap requirement.
const LOW := [
	[SHUTTER, "reseat_sentry_hook", {"gold": 50, "scraps": 1}],
	[SHUTTER, "buy_storm_hems", {"gold": 15, "scraps": 5}],
	[TYPEWRITER, "replace_ink_spool", {"gold": 50, "scraps": 0}],
	[CORK, "buy_cork_lacing", {"gold": 17, "scraps": 5}],
	[CORK, "seal_lookout_cork", {"gold": 50, "scraps": 1}],
	[DOORBELL, "rethread_bell_puller", {"gold": 50, "scraps": 0}],
	[DOORBELL, "buy_bellcord", {"gold": 11, "scraps": 5}],
]

var failures: Array[String] = []
var checks := 0
var document: Dictionary = {}
var records: Dictionary = {}

func _initialize() -> void:
	document = _read(PATH)
	var snapshot := document.duplicate(true)
	var events: Variant = document.get("events")
	_check(events is Array, "source has an events array")
	if not events is Array:
		_finish()
		return
	for event_id in EXPECTED.keys() + ANCHORS:
		var matches: Array = events.filter(func(row): return row is Dictionary and row.get("id") == event_id)
		_check(matches.size() == 1, "source ID occurs exactly once: " + event_id)
		if matches.size() == 1:
			records[event_id] = matches[0]
	if records.size() != EXPECTED.size() + ANCHORS.size():
		_finish()
		return
	_test_records()
	_test_funded()
	_test_refusals()
	_test_zero()
	_test_injected()
	_check(document == snapshot, "all flows preserve the source catalog")
	_finish()

func _test_records() -> void:
	for event_id in EXPECTED:
		var record: Dictionary = records[event_id]
		_check(_same_authored(record, EXPECTED[event_id]), "exact authored contract (id/title/description/choices): " + event_id)
		_check(record.size() == 4 and record.has("id") and record.has("title") and record.has("description") and record.has("choices"), "only the four supported event fields: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and choices.size() == 3, "three authored options: " + event_id)
		if not choices is Array:
			continue
		var seen := {}
		for choice in choices:
			_check(choice is Dictionary, "choice is an object")
			if not choice is Dictionary:
				continue
			_check(choice.size() == 3 and choice.has("id") and choice.has("text") and choice.has("outcome"), "exact choice fields")
			_check(not seen.has(choice.get("id")), "distinct choice ID")
			seen[choice.get("id")] = true
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "wallet outcome object")
			if outcome is Dictionary:
				_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"), "only signed gold and scraps keys")
				_check(_whole(outcome.get("gold")) and _whole(outcome.get("scraps")), "signed integer amounts (JSON may parse them as floats)")
		var third: Dictionary = (choices as Array)[2]
		_check(third.get("id") == "leave" and _same_authored(third.get("outcome"), {"gold": 0, "scraps": 0}), "third option is a zero-cost Leave: " + event_id)
	for event_id in ANCHORS:
		_check(records.has(event_id), "earlier anchor still present exactly once: " + event_id)
		_check(records[event_id].get("id") == event_id, "earlier anchor keeps its ID: " + event_id)

func _test_funded() -> void:
	var settled := 0
	for event_id in EXPECTED:
		for choice in EXPECTED[event_id]["choices"]:
			var choice_id: String = choice["id"]
			var record: Dictionary = records[event_id].duplicate(true)
			var original := record.duplicate(true)
			var wallet := FUNDED.duplicate(true)
			var service := RunEventChoice.new(record)
			_check(service.is_valid() and not service.is_claimed(), "fresh funded visit validates before selection: " + event_id + "/" + choice_id)
			var preview := service.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id and preview.get("choices", []).size() == 3, "complete funded preview: " + event_id)
			for option in EXPECTED[event_id]["choices"]:
				_check(_row(preview, option["id"]) == {
					"choice_id": option["id"],
					"gold_delta": option["outcome"]["gold"],
					"scraps_delta": option["outcome"]["scraps"],
					"affordable": true,
					"wallet": FINAL[event_id][option["id"]],
				}, "exact funded preview deltas and independent balance: " + event_id + "/" + option["id"])
			# Mutating public nested returns cannot alter the service, the record or the wallet.
			var exposed := service.get_event()
			exposed["choices"][0]["outcome"]["gold"] = 999
			preview["choices"][0]["wallet"]["gold"] = 999
			var fresh_preview := service.preview_wallet_choices(wallet)
			_check(service.get_event() == original and fresh_preview["choices"][0]["wallet"] == FINAL[event_id][EXPECTED[event_id]["choices"][0]["id"]], "event and preview returns are detached: " + event_id)
			_check(wallet == FUNDED and record == original, "funded preview preserves supplied snapshots: " + event_id + "/" + choice_id)
			var receipt := service.choose_with_wallet(choice_id, wallet)
			_check(receipt == {"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": FINAL[event_id][choice_id]}, "exact independent funded receipt: " + event_id + "/" + choice_id)
			_check(service.is_claimed() and not service.is_valid(), "successful claim closes the visit: " + event_id + "/" + choice_id)
			_check(service.preview_wallet_choices(wallet) == {"ok": false, "event_id": "", "choices": []}, "claimed visit denies further previews: " + event_id)
			_check(service.choose_with_wallet(choice_id, wallet) == _denied(wallet), "second claim rejected unchanged: " + event_id + "/" + choice_id)
			receipt["wallet"]["gold"] = 999
			_check(wallet == FUNDED and record == original, "funded settlement preserves inputs and receipt is detached: " + event_id + "/" + choice_id)
			settled += 1
	_check(settled == 12, "all twelve funded options exercised on independent fresh visits")

func _test_refusals() -> void:
	for case in LOW:
		_refusal(case[0], case[1], case[2], true)
	for event_id in EXPECTED:
		_refusal(event_id, "forged_unknown_choice", FUNDED, false)

func _refusal(event_id: String, choice_id: String, initial: Dictionary, priced: bool) -> void:
	var record: Dictionary = records[event_id].duplicate(true)
	var original := record.duplicate(true)
	var wallet := initial.duplicate(true)
	var service := RunEventChoice.new(record)
	_check(service.is_valid() and not service.is_claimed(), "fresh refusal visit validates: " + event_id + "/" + choice_id)
	if priced:
		var preview := service.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id and preview.get("choices", []).size() == 3, "short-wallet preview remains complete: " + event_id)
		var row := _row(preview, choice_id)
		_check(not row.is_empty() and row.get("affordable") == false and row.get("wallet") == initial, "one-unit-short choice visible, unaffordable and uncharged: " + event_id + "/" + choice_id)
		_check(row.get("gold_delta") == FINAL[event_id][choice_id]["gold"] - FUNDED["gold"] and row.get("scraps_delta") == FINAL[event_id][choice_id]["scraps"] - FUNDED["scraps"], "unaffordable preview keeps authored deltas: " + event_id + "/" + choice_id)
	_check(service.choose_with_wallet(choice_id, wallet) == _denied(wallet), "failed choice refuses with the exact unchanged wallet: " + event_id + "/" + choice_id)
	_check(service.is_valid() and not service.is_claimed(), "refusal consumes no claim and leaves the visit open: " + event_id + "/" + choice_id)
	_check(service.choose_with_wallet("leave", wallet) == {"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": wallet}, "zero-cost Leave still succeeds after refusal: " + event_id + "/" + choice_id)
	_check(service.is_claimed() and not service.is_valid(), "subsequent Leave claims exactly once: " + event_id)
	_check(wallet == initial and record == original, "refusal and subsequent Leave preserve supplied snapshots: " + event_id + "/" + choice_id)

func _test_zero() -> void:
	var wallet := ZERO.duplicate(true)
	var service := RunEventChoice.new(records[TYPEWRITER].duplicate(true))
	_check(service.is_valid(), "fresh zero-wallet typewriter visit validates")
	var preview := service.preview_wallet_choices(wallet)
	var row := _row(preview, "gather_fallen_ribbon")
	_check(row.get("affordable") == true and row.get("wallet") == {"gold": 0, "scraps": 2}, "zero-wallet ribbon salvage projects two scraps")
	_check(service.choose_with_wallet("gather_fallen_ribbon", wallet) == {"ok": true, "event_id": TYPEWRITER, "choice_id": "gather_fallen_ribbon", "wallet": {"gold": 0, "scraps": 2}}, "zero-wallet ribbon salvage settles exactly two scraps")
	_check(service.is_claimed() and wallet == ZERO, "zero-wallet salvage latches without input mutation")
	for event_id in EXPECTED:
		var leave_wallet := ZERO.duplicate(true)
		var leave_service := RunEventChoice.new(records[event_id].duplicate(true))
		_check(leave_service.is_valid(), "fresh zero-wallet visit validates: " + event_id)
		_check(leave_service.choose_with_wallet("leave", leave_wallet) == {"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": {"gold": 0, "scraps": 0}}, "fresh zero-wallet Leave settles unchanged: " + event_id)
		_check(leave_service.is_claimed() and leave_wallet == ZERO, "zero-wallet Leave latches without input mutation: " + event_id)
	var shutter := RunEventChoice.new(records[SHUTTER].duplicate(true))
	var shutter_preview := shutter.preview_wallet_choices(ZERO)
	_check(_row(shutter_preview, "reseat_sentry_hook").get("affordable") == false and _row(shutter_preview, "buy_storm_hems").get("affordable") == false, "both shutter trades unaffordable at zero")
	for option in shutter_preview.get("choices", []):
		_check(not option.get("affordable", false) or (option.get("gold_delta") == 0 and option.get("scraps_delta") == 0), "zero-wallet shutter offers no affordable nonzero outcome")

func _test_injected() -> void:
	var input: Dictionary = records[DOORBELL].duplicate(true)
	var service := RunEventChoice.new(input)
	_check(service.is_valid(), "constructed service validates from an injected record")
	input["choices"][0]["outcome"]["gold"] = 999
	input["title"] = "mutated"
	_check(service.get_event() == records[DOORBELL], "constructor detaches the supplied nested record")
	_check(service.choose_with_wallet("rethread_bell_puller", {"gold": 50, "scraps": 5}) == {"ok": true, "event_id": DOORBELL, "choice_id": "rethread_bell_puller", "wallet": {"gold": 72, "scraps": 4}}, "caller mutation cannot alter settlement")
	var wallet := FUNDED.duplicate(true)
	var fresh := RunEventChoice.new(records[CORK].duplicate(true))
	var preview := fresh.preview_wallet_choices(wallet)
	var rows: Array = preview.get("choices", [])
	_check(rows.size() == 3, "injected preview returns three detached rows")
	if rows.size() == 3:
		rows[0]["wallet"]["gold"] = 999
		rows[0]["gold_delta"] = 999
		var settled := fresh.preview_wallet_choices(wallet)
		_check(settled["choices"][1]["wallet"] == FINAL[CORK]["seal_lookout_cork"] and settled["choices"][0]["wallet"] == FINAL[CORK]["buy_cork_lacing"], "preview rows are detached from each other and from the source")
	_check(wallet == FUNDED, "preview never mutates the supplied wallet snapshot")

func _row(preview: Dictionary, choice_id: String) -> Dictionary:
	var rows: Array = preview.get("choices", [])
	var matches := rows.filter(func(row): return row is Dictionary and row.get("choice_id") == choice_id)
	_check(matches.size() == 1, "preview choice occurs exactly once: " + choice_id)
	return matches[0] if matches.size() == 1 else {}

func _denied(wallet: Dictionary) -> Dictionary:
	return {"ok": false, "event_id": "", "choice_id": "", "wallet": wallet}

func _whole(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value)

# JSON parses all numbers as floats; compare exact keys/text/order while allowing
# only finite whole-number equivalents of the independent integer literals.
func _same_authored(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not _same_authored(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size():
			return false
		for index in expected.size():
			if not _same_authored(actual[index], expected[index]):
				return false
		return true
	if typeof(expected) == TYPE_INT:
		return _whole(actual) and actual == expected
	return typeof(actual) == typeof(expected) and actual == expected

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "FileAccess opens " + path)
	if file == null:
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	_check(error == OK and parser.data is Dictionary, "JSON object parses: " + path)
	return parser.data if error == OK and parser.data is Dictionary else {}

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_shutter_typewriter_cork_bell_roadside_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
