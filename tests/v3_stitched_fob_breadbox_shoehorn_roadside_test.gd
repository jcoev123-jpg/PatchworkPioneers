extends SceneTree
## Independent authored contracts and settlement oracles for the three appended
## doll-scale roadside wallet stories (fob watch, breadbox, shoehorn ramp).
## The production roadside JSON is parsed directly, each new record is checked
## against separately hardcoded prose and wallet tables, and every funded,
## refused, replay and zero-wallet flow runs through the shipped RunEventChoice
## service on independent fresh selectors. The default RunM04EventRotation
## loader must discover each new ID exactly once and serve the authentic source
## record. This test deliberately never asserts the catalog's total size, a
## record index or a global ordering.

const PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 50, "scraps": 5}
const ZERO := {"gold": 0, "scraps": 0}

const FOB := "v3_hushed_fob_watch"
const BREADBOX := "v3_bonewhite_breadbox"
const SHOEHORN := "v3_silver_shoehorn_ramp"

## Exactly the four authored top-level fields and three choices per record.
const EXPECTED := {
	FOB: {
		"id": FOB,
		"title": "The Hushed Fob Watch",
		"description": "A brass fob watch hangs over a dark nursery stair like a pendulum moon; far below its cracked glass, a small oxblood watchkeeper winds the chain with mitten hands as one candle glows through the motionless gears.",
		"choices": [
			{"id": "buy_watch_spring", "text": "Pay 16 gold for three coils of watchspring thread (+3 scraps)", "outcome": {"gold": -16, "scraps": 3}},
			{"id": "rethread_watch_chain", "text": "Spend 2 scraps rethreading the hanging chain (earn 27 gold)", "outcome": {"gold": 27, "scraps": -2}},
			{"id": "leave", "text": "Let the frozen hands keep their midnight secret", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	BREADBOX: {
		"id": BREADBOX,
		"title": "The Bonewhite Breadbox",
		"description": "A breadbox as broad as a cellar yawns open on the pantry floor; a round button-eyed baker in a flour-white hood counts lost spool crumbs behind its moonlit glass door while black lace hangs from the hinges.",
		"choices": [
			{"id": "buy_crumb_thread", "text": "Pay 12 gold for two bundles of crumb-wrapped thread (+2 scraps)", "outcome": {"gold": -12, "scraps": 2}},
			{"id": "mend_breadbox_hinge", "text": "Spend 1 scrap bracing the heavy breadbox hinge (earn 19 gold)", "outcome": {"gold": 19, "scraps": -1}},
			{"id": "leave", "text": "Close the glass door before the crumbs begin to move", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	SHOEHORN: {
		"id": SHOEHORN,
		"title": "The Silver Shoehorn Ramp",
		"description": "A tarnished shoehorn bridges two giant boot heels above a crack in the floorboards; its curved silver back shines in amber candlelight as a tiny plum-cloth cobbler tightens the worn leather grip.",
		"choices": [
			{"id": "brace_shoehorn_span", "text": "Spend 2 scraps bracing the silver ramp (earn 31 gold)", "outcome": {"gold": 31, "scraps": -2}},
			{"id": "buy_leather_lacing", "text": "Pay 19 gold for three bundles of leather-grip lacing (+3 scraps)", "outcome": {"gold": -19, "scraps": 3}},
			{"id": "leave", "text": "Walk beneath the shoehorn and leave the crossing to the cobbler", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
}

## Hardcoded final balances from the funded {gold: 50, scraps: 5} wallet; never
## computed from the production outcomes.
const FINAL := {
	FOB: {
		"buy_watch_spring": {"gold": 34, "scraps": 8},
		"rethread_watch_chain": {"gold": 77, "scraps": 3},
		"leave": {"gold": 50, "scraps": 5},
	},
	BREADBOX: {
		"buy_crumb_thread": {"gold": 38, "scraps": 7},
		"mend_breadbox_hinge": {"gold": 69, "scraps": 4},
		"leave": {"gold": 50, "scraps": 5},
	},
	SHOEHORN: {
		"brace_shoehorn_span": {"gold": 81, "scraps": 3},
		"buy_leather_lacing": {"gold": 31, "scraps": 8},
		"leave": {"gold": 50, "scraps": 5},
	},
}

## [event ID, paid choice ID, wallet one unit below that choice's own cost while
## the other resource stays funded].
const SHORT := [
	[FOB, "buy_watch_spring", {"gold": 15, "scraps": 5}],
	[FOB, "rethread_watch_chain", {"gold": 50, "scraps": 1}],
	[BREADBOX, "buy_crumb_thread", {"gold": 11, "scraps": 5}],
	[BREADBOX, "mend_breadbox_hinge", {"gold": 50, "scraps": 0}],
	[SHOEHORN, "brace_shoehorn_span", {"gold": 50, "scraps": 1}],
	[SHOEHORN, "buy_leather_lacing", {"gold": 18, "scraps": 5}],
]

## Earlier roadside records that must survive exactly once; parallel catalog
## growth means only named-ID presence is asserted.
const ANCHOR_IDS := [
	"v3_raincoat_bridge",
	"v3_pepper_mill_stairwell",
	"v3_crooked_sewing_compass",
]

const DENIED_PREVIEW := {"ok": false, "event_id": "", "choices": []}

var failures: Array[String] = []
var checks := 0
var records: Dictionary = {}


func _initialize() -> void:
	var document: Dictionary = _read(PATH)
	var snapshot: Dictionary = document.duplicate(true)
	var events: Variant = document.get("events")
	_check(events is Array, "source has an events array")
	if not events is Array:
		_finish()
		return
	for event_id in EXPECTED.keys() + ANCHOR_IDS:
		var matches: Array = (events as Array).filter(
			func(row): return row is Dictionary and row.get("id") == event_id)
		_check(matches.size() == 1, "source ID occurs exactly once: " + event_id)
		if matches.size() == 1:
			records[event_id] = matches[0]
	if records.size() != EXPECTED.size() + ANCHOR_IDS.size():
		_finish()
		return
	_test_records()
	_test_anchors()
	_test_funded()
	_test_short_refusals()
	_test_zero_wallet()
	_test_rotation()
	_check(document == snapshot, "all flows preserve the parsed source document")
	_finish()


## Source-authentic authored contract: exact four top-level fields, exact title
## and description, three choices with exact IDs/text and integral gold/scraps
## deltas, and a zero-delta third Leave.
func _test_records() -> void:
	for event_id in EXPECTED:
		var record: Dictionary = records[event_id]
		var expected: Dictionary = EXPECTED[event_id]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"exact four top-level authored fields: " + event_id)
		_check(record.get("id") == event_id, "authored ID exact: " + event_id)
		_check(record.get("title") == expected.title, "authored title exact: " + event_id)
		_check(record.get("description") == expected.description, "authored description exact: " + event_id)
		_check(_same_authored(record, expected), "full authored record exact: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3, "exactly three authored choices: " + event_id)
		if not choices is Array or (choices as Array).size() != 3:
			continue
		var seen := {}
		for choice in choices:
			_check(choice is Dictionary, "choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var option: Dictionary = choice
			_check(option.size() == 3 and option.has("id") and option.has("text")
				and option.has("outcome"), "exact choice fields: " + event_id)
			var choice_id: Variant = option.get("id")
			_check(choice_id is String and not (choice_id as String).is_empty()
				and not seen.has(choice_id), "distinct nonblank choice ID: " + event_id)
			seen[choice_id] = true
			var outcome: Variant = option.get("outcome")
			_check(outcome is Dictionary, "wallet outcome object: " + event_id)
			if outcome is Dictionary:
				var wallet: Dictionary = outcome
				_check(wallet.size() == 2 and wallet.has("gold") and wallet.has("scraps"),
					"outcome carries precisely gold/scraps: " + event_id)
				_check(_whole(wallet.get("gold")) and _whole(wallet.get("scraps")),
					"outcome amounts are integral (JSON numbers may parse as floats): " + event_id)
		var third_choice: Variant = (choices as Array)[2]
		if third_choice is Dictionary:
			_check(third_choice.get("id") == "leave", "third choice is Leave: " + event_id)
			_check(_same_authored(third_choice.get("outcome"), {"gold": 0, "scraps": 0}),
				"third choice is free: " + event_id)


## The three named earlier roadside anchors survive exactly once and still build
## a valid fresh selector; their contents are not re-pinned here.
func _test_anchors() -> void:
	for event_id in ANCHOR_IDS:
		var record: Dictionary = records[event_id]
		_check(record.get("title") is String and not (record.get("title") as String).strip_edges().is_empty(),
			"anchor keeps authored title: " + event_id)
		_check(record.get("description") is String
			and not (record.get("description") as String).strip_edges().is_empty(),
			"anchor keeps authored description: " + event_id)
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(),
			"anchor builds a valid fresh selector: " + event_id)


## Each authored choice commits on its own fresh selector from the same funded
## wallet and settles the exact independent balance; replays are refused.
func _test_funded() -> void:
	var settled := 0
	for event_id in EXPECTED:
		var original: Dictionary = records[event_id].duplicate(true)
		for choice in EXPECTED[event_id]["choices"]:
			var choice_id: String = choice["id"]
			var tag: String = event_id + "/" + choice_id
			var wallet := FUNDED.duplicate(true)
			var selector := RunEventChoice.new(original)
			_check(selector.is_valid() and not selector.is_claimed(), "fresh funded visit validates: " + tag)
			var preview := selector.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3, "complete funded preview: " + tag)
			var row := _row(preview, choice_id)
			_check(not row.is_empty() and row.get("affordable") == true
				and _same_authored(row.get("gold_delta"), choice["outcome"]["gold"])
				and _same_authored(row.get("scraps_delta"), choice["outcome"]["scraps"])
				and row.get("wallet") == FINAL[event_id][choice_id],
				"funded preview forecasts the exact balance: " + tag)
			var receipt := selector.choose_with_wallet(choice_id, wallet)
			_check(receipt == {"ok": true, "event_id": event_id, "choice_id": choice_id,
				"wallet": FINAL[event_id][choice_id]}, "exact independent funded settlement: " + tag)
			_check(receipt.get("event_id") == event_id and receipt.get("choice_id") == choice_id,
				"receipt echoes exact event and choice IDs: " + tag)
			var balance: Dictionary = receipt.get("wallet", {})
			_check(balance.get("gold", -1) >= 0 and balance.get("scraps", -1) >= 0,
				"settled balance is never negative: " + tag)
			_check(selector.is_claimed() and not selector.is_valid(), "successful claim closes visit: " + tag)
			_check(selector.choose_with_wallet(choice_id, wallet) == _denied(FUNDED),
				"replay of a committed choice is refused unchanged: " + tag)
			_check(selector.preview_wallet_choices(wallet) == DENIED_PREVIEW,
				"claimed visit refuses a second preview: " + tag)
			receipt["wallet"]["gold"] = 999
			_check(wallet == FUNDED and records[event_id] == original,
				"funded flow preserves caller wallet and source record: " + tag)
			settled += 1
	_check(settled == 9, "all nine funded options exercised on independent fresh selectors")


## One unit below the paid cost marks the choice unaffordable, refuses the
## commit without spending or claiming, and still allows the free Leave on that
## same fresh selector.
func _test_short_refusals() -> void:
	for case in SHORT:
		var event_id: String = case[0]
		var choice_id: String = case[1]
		var wallet: Dictionary = (case[2] as Dictionary).duplicate(true)
		var before := wallet.duplicate(true)
		var original: Dictionary = records[event_id].duplicate(true)
		var tag: String = event_id + "/" + choice_id
		var selector := RunEventChoice.new(original)
		_check(selector.is_valid() and not selector.is_claimed(), "fresh short visit validates: " + tag)
		var preview := selector.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"short preview stays available: " + tag)
		var row := _row(preview, choice_id)
		_check(not row.is_empty() and row.get("affordable") == false
			and row.get("wallet") == before, "one unit short is unaffordable and unmoved: " + tag)
		var receipt := selector.choose_with_wallet(choice_id, wallet)
		_check(receipt == _denied(before), "short wallet refuses the paid choice unchanged: " + tag)
		_check(wallet == before and records[event_id] == original
			and selector.is_valid() and not selector.is_claimed(),
			"refusal spends nothing, claims nothing and preserves inputs: " + tag)
		var leave := selector.choose_with_wallet("leave", wallet)
		_check(leave == {"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": before},
			"free Leave still settles the refused visit: " + tag)
		_check(selector.is_claimed() and not selector.is_valid() and wallet == before,
			"Leave latches the visit once without touching the wallet: " + tag)


## With an empty wallet both paid options are unaffordable, are refused, and the
## free Leave still succeeds on that same fresh selector.
func _test_zero_wallet() -> void:
	for event_id in EXPECTED:
		var wallet := ZERO.duplicate(true)
		var selector := RunEventChoice.new(records[event_id])
		var original: Dictionary = records[event_id].duplicate(true)
		_check(selector.is_valid() and not selector.is_claimed(), "fresh zero-wallet visit validates: " + event_id)
		var preview := selector.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true and (preview.get("choices") as Array).size() == 3,
			"zero-wallet preview includes every option: " + event_id)
		var paid_unaffordable := 0
		for choice in EXPECTED[event_id]["choices"]:
			var choice_id: String = choice["id"]
			var row := _row(preview, choice_id)
			if choice_id == "leave":
				_check(not row.is_empty() and row.get("affordable") == true
					and row.get("wallet") == ZERO, "zero-wallet Leave stays affordable and free: " + event_id)
			else:
				_check(not row.is_empty() and row.get("affordable") == false
					and row.get("wallet") == ZERO, "zero-wallet paid option is unaffordable: " + event_id + "/" + choice_id)
				_check(selector.choose_with_wallet(choice_id, wallet) == _denied(ZERO),
					"zero-wallet paid option is refused: " + event_id + "/" + choice_id)
				paid_unaffordable += 1
		_check(paid_unaffordable == 2, "both paid options were exercised at zero: " + event_id)
		_check(wallet == ZERO and records[event_id] == original
			and selector.is_valid() and not selector.is_claimed(),
			"zero-wallet refusals preserve inputs and leave the visit unclaimed: " + event_id)
		var leave := selector.choose_with_wallet("leave", wallet)
		_check(leave == {"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": ZERO},
			"zero-wallet Leave succeeds after refusals: " + event_id)
		_check(selector.is_claimed() and wallet == ZERO, "zero-wallet Leave claims once and spends nothing: " + event_id)


## The unedited default rotation must validate its genuine catalogs and serve
## each new ID exactly once as the authentic source record, with the named
## anchors still present. Pool size, positions and seeded draws are not pinned.
func _test_rotation() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "default real catalog validates")
	if not rotation.is_catalog_valid():
		return
	var ids := rotation.get_generic_event_ids()
	var listing := rotation.get_generic_events()
	_check(not ids.is_empty() and not listing.is_empty(), "default generic pool is populated")
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1, "default ID listing membership exactly once: " + event_id)
		var matches := listing.filter(func(row): return row is Dictionary and row.get("id") == event_id)
		_check(matches.size() == 1, "default event listing membership exactly once: " + event_id)
		if matches.size() != 1:
			continue
		_check(matches[0] == records[event_id], "default serves the authentic source record: " + event_id)
		var selector := RunEventChoice.new(matches[0])
		_check(selector.is_valid() and not selector.is_claimed(),
			"default record builds a valid fresh selector: " + event_id)
		var preview := selector.preview_wallet_choices(FUNDED)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id
			and (preview.get("choices") as Array).size() == 3,
			"default record previews every funded choice: " + event_id)
	for event_id in ANCHOR_IDS:
		_check(ids.count(event_id) == 1, "anchor remains in default ID listing: " + event_id)
		_check(listing.filter(func(row): return row is Dictionary and row.get("id") == event_id).size() == 1,
			"anchor remains in default event listing: " + event_id)
	listing.clear()
	ids.clear()
	_check(not rotation.get_generic_event_ids().is_empty() and not rotation.get_generic_events().is_empty(),
		"returned listings are detached")


func _row(preview: Dictionary, choice_id: String) -> Dictionary:
	var rows: Variant = preview.get("choices", [])
	if not rows is Array:
		return {}
	var matches := (rows as Array).filter(
		func(row): return row is Dictionary and row.get("choice_id") == choice_id)
	_check(matches.size() == 1, "preview choice occurs exactly once: " + choice_id)
	return matches[0] if matches.size() == 1 else {}


func _denied(wallet: Dictionary) -> Dictionary:
	return {"ok": false, "event_id": "", "choice_id": "", "wallet": wallet}


## Godot's JSON parser yields floats for whole numbers; accept only finite
## whole-number equivalents of the independent integer literals.
func _whole(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value)


func _same_authored(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if not actual is Dictionary or (actual as Dictionary).size() != (expected as Dictionary).size():
			return false
		for key in (expected as Dictionary):
			if not (actual as Dictionary).has(key) or not _same_authored((actual as Dictionary)[key], (expected as Dictionary)[key]):
				return false
		return true
	if expected is Array:
		if not actual is Array or (actual as Array).size() != (expected as Array).size():
			return false
		for index in (expected as Array).size():
			if not _same_authored((actual as Array)[index], (expected as Array)[index]):
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
	print("v3_stitched_fob_breadbox_shoehorn_roadside_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
