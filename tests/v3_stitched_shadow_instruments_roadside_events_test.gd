extends SceneTree
## Scene-free contract coverage for the three appended gothic shadow-instrument
## roadside wallet stories in the shared V3 roadside catalog. The authored JSON is
## parsed directly, every new record is checked against its authored prose and
## wallet table, and all settlement, refusal and fail-closed paths run through the
## real RunEventChoice service on independent fresh selectors. The default
## RunM04EventRotation loader must discover every new ID exactly once. The
## catalog's total size, global order and seeded selection are deliberately never
## asserted.

const PATH := "res://data/events/v3_roadside_events.json"
const FUNDED_WALLET := {"gold": 60, "scraps": 6}

## Earlier roadside records that must survive exactly once; the shared catalog
## grows in parallel, so only named-ID presence is asserted.
const ANCHOR_IDS := [
	"v3_raincoat_bridge",
	"v3_shutterhook_signal",
	"v3_porcelain_doorbell",
]

## Choice rows are [id, text, gold, scraps, settled {gold, scraps}] where the
## settled balance comes from the funded {gold: 60, scraps: 6} wallet.
## gold_short/scraps_short are [paid choice ID, wallet that must refuse it].
const NEW_RECORDS := {
	"v3_shadow_stitch_zoetrope": {
		"title": "The Shadow-Stitch Zoetrope",
		"description": "An enormous brass zoetrope turns by itself on the floorboards; each slit shows four rag dolls marching under a thread-red moon while its button-eyed keeper grips the broken crank.",
		"choices": [
			["buy_shadow_frames", "Pay 19 gold for three bundles of frame-thread (+3 scraps)", -19, 3, {"gold": 41, "scraps": 9}],
			["retie_spinning_axle", "Spend 2 scraps to retie the turning axle (earn 31 gold)", 31, -2, {"gold": 91, "scraps": 4}],
			["leave", "Let the fourth shadow finish its lonely circuit", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"gold_short": ["buy_shadow_frames", {"gold": 18, "scraps": 6}],
		"scraps_short": ["retie_spinning_axle", {"gold": 60, "scraps": 1}],
	},
	"v3_hushglass_kaleidoscope": {
		"title": "The Hushglass Kaleidoscope",
		"description": "A fractured kaleidoscope as long as a bedpost leans over a black stairwell; its round plum-cloth keeper shows the party's stitched faces in shards that blink out of turn.",
		"choices": [
			["buy_lens_hem", "Pay 14 gold for two bundles of lens-binding thread (+2 scraps)", -14, 2, {"gold": 46, "scraps": 8}],
			["patch_shattered_eye", "Spend 1 scrap patching the broken eyepiece (earn 18 gold)", 18, -1, {"gold": 78, "scraps": 5}],
			["leave", "Leave the blinking fragments in the stairwell", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"gold_short": ["buy_lens_hem", {"gold": 13, "scraps": 6}],
		"scraps_short": ["patch_shattered_eye", {"gold": 60, "scraps": 0}],
	},
	"v3_crooked_sewing_compass": {
		"title": "The Crooked Sewing Compass",
		"description": "An ivory sewing compass lies on a quilt-map as large as the floor; its needle follows the party's loose thread instead of north while a slate-blue survey doll holds its hinge shut.",
		"choices": [
			["buy_direction_thread", "Pay 22 gold for three bundles of survey thread (+3 scraps)", -22, 3, {"gold": 38, "scraps": 9}],
			["repair_wandering_needle", "Spend 3 scraps binding the wandering needle (earn 42 gold)", 42, -3, {"gold": 102, "scraps": 3}],
			["leave", "Step away before the compass points after you", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"gold_short": ["buy_direction_thread", {"gold": 21, "scraps": 6}],
		"scraps_short": ["repair_wandering_needle", {"gold": 60, "scraps": 2}],
	},
}

const DENIED_PREVIEW := {"ok": false, "event_id": "", "choices": []}

var failures: Array[String] = []
var checks := 0
## Which fail-closed kind each new Event actually exercised: {event_id: {kind: true}}.
var exercised := {}
## The detached default-rotation records, indexed by ID.
var rotation_records := {}
## The parsed roadside catalog records, indexed by ID, for authenticity checks.
var source_records := {}


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _nonblank(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


## Godot JSON parses integer tokens as floats; require exact integral values.
func _integral_exact(value: Variant, wanted: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and value == wanted


func _initialize() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	_check(file != null, "catalog opens")
	if file != null:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		_check(error == OK, "catalog parses")
		if error == OK:
			var document: Variant = json.data
			_check(document is Dictionary and document.get("events") is Array, "events array exists")
			if document is Dictionary and document.get("events") is Array:
				var records: Array = document.events
				var snapshot: Array = records.duplicate(true)
				source_records = {}
				for record in records:
					if record is Dictionary and record.get("id") is String:
						source_records[record["id"]] = record
				_test_anchors(records)
				for event_id in NEW_RECORDS:
					_test_new_record(records, event_id)
				_check(records == snapshot, "all authored inputs remain unchanged")
	_test_rotation()
	for failure in failures:
		printerr(failure)
	print("v3_stitched_shadow_instruments_roadside_events_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _find(records: Array, event_id: String) -> Array:
	return records.filter(func(record): return record is Dictionary and record.get("id") == event_id)


func _count_id(ids: Array, event_id: String) -> int:
	return ids.count(event_id)


func _test_anchors(records: Array) -> void:
	for event_id in ANCHOR_IDS:
		var matches: Array = _find(records, event_id)
		_check(matches.size() == 1, "anchor ID occurs exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(_nonblank(record.get("title")) and _nonblank(record.get("description")), "anchor readable prose: " + event_id)
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(), "anchor builds a valid fresh selector: " + event_id)


func _test_new_record(records: Array, event_id: String) -> void:
	var expected: Dictionary = NEW_RECORDS[event_id]
	var tag: String = event_id
	var matches: Array = _find(records, event_id)
	_check(matches.size() == 1, "new ID occurs exactly once: " + tag)
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	_check(record.size() == 4 and record.has("id") and record.has("title")
		and record.has("description") and record.has("choices"),
		"new record keeps only id/title/description/choices: " + tag)
	_check(record.get("title") == expected.title, "new title exact: " + tag)
	_check(record.get("description") == expected.description, "new description exact: " + tag)
	var choices: Variant = record.get("choices")
	_check(choices is Array and (choices as Array).size() == 3, "new record authors exactly three choices: " + tag)
	if not choices is Array:
		return
	var by_id := {}
	for choice in choices:
		_check(choice is Dictionary, "new choice record: " + tag)
		if not choice is Dictionary:
			continue
		var raw_choice: Dictionary = choice
		_check(raw_choice.size() == 3 and raw_choice.has("id") and raw_choice.has("text")
			and raw_choice.has("outcome"), "new choice keeps only id/text/outcome: " + tag)
		var raw_id: Variant = raw_choice.get("id")
		_check(_nonblank(raw_id) and not by_id.has(raw_id), "distinct nonblank new choice ID: " + tag)
		if raw_id is String:
			by_id[raw_id] = raw_choice
	var wanted: Array = expected.choices
	_check(by_id.size() == wanted.size(), "new choice count matches the authored table: " + tag)
	for row in wanted:
		var choice_id: String = row[0]
		var choice_tag: String = tag + "/" + choice_id
		_check(by_id.has(choice_id), "required new choice exists: " + choice_tag)
		if not by_id.has(choice_id):
			continue
		var choice: Dictionary = by_id[choice_id]
		_check(choice.get("text") == row[1], "new choice text exact: " + choice_tag)
		var outcome: Variant = choice.get("outcome")
		_check(outcome is Dictionary and (outcome as Dictionary).size() == 2
			and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps"),
			"new outcome carries precisely gold/scraps: " + choice_tag)
		if outcome is Dictionary:
			_check(_integral_exact((outcome as Dictionary).get("gold"), row[2])
				and _integral_exact((outcome as Dictionary).get("scraps"), row[3]),
				"new outcome exact signed deltas: " + choice_tag)
	_check(by_id.has("leave"), "new record offers a Leave choice: " + tag)
	if by_id.has("leave"):
		var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
		_check(leave_outcome is Dictionary
			and _integral_exact((leave_outcome as Dictionary).get("gold"), 0)
			and _integral_exact((leave_outcome as Dictionary).get("scraps"), 0),
			"Leave is free: " + tag)
	_test_preview_and_settlements(record, expected)
	if expected.has("gold_short"):
		_test_short_refusal(record, expected.gold_short, "gold-short")
	_test_short_refusal(record, expected.scraps_short, "scraps-short")
	_test_unknown_choice(record)
	_test_repeated_claim(record, expected)
	var kinds: Dictionary = exercised.get(event_id, {})
	var needed := ["gold-short", "scraps-short", "unknown", "repeated"]
	for kind in needed:
		_check(kinds.get(kind, false), "new Event exercised fail-closed witness " + kind + ": " + tag)


func _preview_entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


## Funded preview plus one fresh committing selector per authored branch, each
## settling independently from the same {gold: 60, scraps: 6} wallet.
func _test_preview_and_settlements(record: Dictionary, expected: Dictionary) -> void:
	var tag: String = record.id
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	_check(selector.is_valid() and not selector.is_claimed(), "valid fresh selector: " + tag)
	var preview := selector.preview_wallet_choices(FUNDED_WALLET)
	_check(preview.get("ok") == true and preview.get("event_id") == record.id, "funded preview available: " + tag)
	_check(selector.is_valid() and not selector.is_claimed(), "preview consumes no visit: " + tag)
	var entries: Variant = preview.get("choices")
	_check(entries is Array and (entries as Array).size() == expected.choices.size(),
		"preview covers every authored choice: " + tag)
	for row in expected.choices:
		var choice_id: String = row[0]
		var choice_tag: String = tag + "/" + choice_id
		var forecast := _preview_entry(preview, choice_id)
		_check(not forecast.is_empty() and forecast.get("gold_delta") == row[2]
			and forecast.get("scraps_delta") == row[3] and forecast.get("affordable") == true
			and forecast.get("wallet") == row[4],
			"funded preview forecasts the exact balance: " + choice_tag)
		var branch := RunEventChoice.new(record)
		var wallet := {"gold": 60, "scraps": 6}
		var receipt := branch.choose_with_wallet(choice_id, wallet)
		_check(receipt == {"ok": true, "event_id": record.id, "choice_id": choice_id, "wallet": row[4]},
			"fresh selector settles the exact independent balance: " + choice_tag)
		_check(branch.is_claimed() and not branch.is_valid(),
			"success claims the visit exactly once: " + choice_tag)
		_check(wallet == FUNDED_WALLET and record == original,
			"settlement preserves caller wallet and event data: " + choice_tag)
		# A repeated funded claim on the same selector is refused unchanged.
		var replay := branch.choose_with_wallet(choice_id, wallet)
		_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": FUNDED_WALLET},
			"funded replay refused unchanged: " + choice_tag)
	_check(selector.get_event() == original, "service event detached and unchanged: " + tag)


## One short-resource witness: the paid choice is unaffordable, the refusal
## keeps the wallet, the record and the unclaimed visit intact, and the free
## Leave still settles that same visit.
func _test_short_refusal(record: Dictionary, witness: Array, kind: String) -> void:
	var choice_id: String = witness[0]
	var wallet: Dictionary = (witness[1] as Dictionary).duplicate(true)
	var before: Dictionary = wallet.duplicate(true)
	var original: Dictionary = record.duplicate(true)
	var tag: String = record.id + "/" + choice_id + "/" + kind
	var selector := RunEventChoice.new(record)
	var forecast := _preview_entry(selector.preview_wallet_choices(wallet), choice_id)
	_check(not forecast.is_empty() and forecast.get("affordable") == false
		and forecast.get("wallet") == before,
		kind + " wallet previews the paid choice unavailable: " + tag)
	var receipt := selector.choose_with_wallet(choice_id, wallet)
	_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": before},
		kind + " wallet refuses the paid choice unchanged: " + tag)
	_check(wallet == before and record == original and selector.is_valid() and not selector.is_claimed(),
		kind + " refusal preserves inputs and leaves the visit unclaimed: " + tag)
	receipt.wallet.gold += 999
	_check(wallet == before, kind + " refusal wallet detached: " + tag)
	var leave := selector.choose_with_wallet("leave", wallet)
	_check(leave == {"ok": true, "event_id": record.id, "choice_id": "leave", "wallet": before}
		and selector.is_claimed() and not selector.is_valid(),
		"free Leave still settles the refused visit: " + tag)
	_check(wallet == before and record == original, "free Leave preserves inputs: " + tag)
	_mark_exercised(record.id, kind)


## An unknown choice ID denies without spending, claiming or changing anything,
## and the free Leave remains usable on that same unclaimed visit.
func _test_unknown_choice(record: Dictionary) -> void:
	var tag: String = record.id
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 60, "scraps": 6}
	var before := wallet.duplicate(true)
	var receipt := selector.choose_with_wallet("no_such_shadow_choice", wallet)
	_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": before},
		"unknown choice ID denies the visit: " + tag)
	_check(wallet == before and record == original and selector.is_valid() and not selector.is_claimed(),
		"unknown-ID denial preserves inputs and leaves the visit unclaimed: " + tag)
	var leave := selector.choose_with_wallet("leave", wallet)
	_check(leave == {"ok": true, "event_id": record.id, "choice_id": "leave", "wallet": before},
		"free Leave remains usable after an unknown-ID denial: " + tag)
	_check(wallet == before and record == original, "free Leave preserves inputs after denial: " + tag)
	_mark_exercised(record.id, "unknown")


## A settled visit denies every repeated claim with the same wallet and exactly
## one claim latched; the service supplies the fail-closed behavior.
func _test_repeated_claim(record: Dictionary, expected: Dictionary) -> void:
	var tag: String = record.id
	var row: Array = expected.choices[0]
	var choice_id: String = row[0]
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 60, "scraps": 6}
	var first := selector.choose_with_wallet(choice_id, wallet)
	_check(first == {"ok": true, "event_id": record.id, "choice_id": choice_id, "wallet": row[4]},
		"repeated-claim visit settles once: " + tag)
	var settled: Dictionary = first.wallet.duplicate(true)
	var replay := selector.choose_with_wallet(choice_id, settled)
	_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": settled},
		"repeated claim denies without another settlement: " + tag)
	var leave := selector.choose_with_wallet("leave", settled)
	_check(leave == {"ok": false, "event_id": "", "choice_id": "", "wallet": settled},
		"claimed visit denies every later choice: " + tag)
	_check(selector.is_claimed() and not selector.is_valid() and settled == row[4]
		and wallet == FUNDED_WALLET and record == original,
		"repeated-claim denial leaves the same wallet and exactly one claim: " + tag)
	_check(selector.preview_wallet_choices(settled) == DENIED_PREVIEW,
		"claimed visit refuses a second preview: " + tag)
	_mark_exercised(record.id, "repeated")


## The unedited default rotation script must discover every new roadside record
## exactly once, alongside the surviving anchors, and serve authentic detached
## records that build valid selectors.
func _test_rotation() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "default real catalog validates")
	if not rotation.is_catalog_valid():
		return
	var ids := rotation.get_generic_event_ids()
	var listing := rotation.get_generic_events()
	_check(not ids.is_empty() and not listing.is_empty(), "default generic pool is populated")
	rotation_records = {}
	for record in listing:
		if record is Dictionary and record.get("id") is String:
			rotation_records[record["id"]] = record
	for event_id in NEW_RECORDS:
		_check(_count_id(ids, event_id) == 1, "default membership exactly once: " + event_id)
		_check(rotation_records.has(event_id), "default serves the new record: " + event_id)
		if not rotation_records.has(event_id):
			continue
		var served: Dictionary = rotation_records[event_id]
		_check(source_records.has(event_id) and served == source_records[event_id],
			"default serves the authentic detached authored record: " + event_id)
		var selector := RunEventChoice.new(served)
		_check(selector.is_valid() and not selector.is_claimed(),
			"default record builds a valid fresh selector: " + event_id)
		var original := served.duplicate(true)
		var preview := selector.preview_wallet_choices(FUNDED_WALLET)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id
			and (preview.get("choices") as Array).size() == NEW_RECORDS[event_id].choices.size(),
			"default record previews all funded choices: " + event_id)
		_check(served == original, "default preview preserves the served record: " + event_id)
	for event_id in ANCHOR_IDS:
		_check(_count_id(ids, event_id) == 1, "anchor remains in default pool: " + event_id)
		_check(rotation_records.has(event_id), "default serves the anchor record: " + event_id)
		if rotation_records.has(event_id):
			var anchor := RunEventChoice.new(rotation_records[event_id])
			_check(anchor.is_valid(), "default anchor builds a valid selector: " + event_id)
	# Returned listings are detached: clearing them cannot alter the rotation.
	listing.clear()
	ids.clear()
	_check(not rotation.get_generic_event_ids().is_empty() and not rotation.get_generic_events().is_empty(),
		"returned listings are detached")


func _mark_exercised(event_id: String, kind: String) -> void:
	var kinds: Dictionary = exercised.get(event_id, {})
	kinds[kind] = true
	exercised[event_id] = kinds
