extends SceneTree
## Scene-free contract coverage for the three appended glass-dropper, dinner-fork
## and toy-submarine roadside wallet stories in the shared V3 roadside catalog.
## The authored JSON is parsed directly, every new record is checked against its
## hardcoded prose and wallet oracle, and all settlement, refusal and fail-closed
## paths run through the real RunEventChoice service on independent fresh
## selectors without drawing from the global RNG. The default RunM04EventRotation
## loader must discover every new ID exactly once and serve each authentic record
## through a seeded all-but-one exclusion selection. The catalog's total size,
## global order and any fixed seed-to-event mapping are never asserted.

const PATH := "res://data/events/v3_roadside_events.json"
const FUNDED_WALLET := {"gold": 60, "scraps": 6}

## Earlier roadside records that must survive exactly once; the shared catalog
## grows in parallel, so only named-ID presence is asserted.
const ANCHOR_IDS := [
	"v3_cinderlace_samovar",
	"v3_ashbone_whistle",
	"v3_oxblood_threadstorm_barometer",
]

## Choice rows are [id, text, gold, scraps, settled {gold, scraps}] where the
## settled balance comes from the funded {gold: 60, scraps: 6} wallet.
## refusals are [[paid choice ID, wallet that must refuse it], ...].
const NEW_RECORDS := {
	"v3_moonblack_medicine_dropper": {
		"title": "The Moonblack Medicine Dropper",
		"description": "A medicine dropper as long as a fallen tree hangs over a dark nursery sink; its cracked glass bulb is held in red stitches by a round moss-felt apothecary.",
		"choices": [
			["buy_dropper_lacing", "Buy fresh glass-binding thread with gold", -17, 3, {"gold": 43, "scraps": 9}],
			["bind_glass_neck", "Resew the cracked neck for a purse of gold", 30, -2, {"gold": 90, "scraps": 4}],
			["leave", "Step around the black drops beneath the sink", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"refusals": [
			["buy_dropper_lacing", {"gold": 16, "scraps": 6}],
			["bind_glass_neck", {"gold": 60, "scraps": 1}],
		],
	},
	"v3_silver_dinnerfork_bridge": {
		"title": "The Silver Dinner-Fork Bridge",
		"description": "An enormous silver dinner fork spans a gap in the floorboards, its four tines roped to opposite shelves; tiny plum-cloth porters strain to hold it steady in candlelight.",
		"choices": [
			["gather_fork_wraps", "Gather the loose wool wrapping the fork tines", 0, 2, {"gold": 60, "scraps": 8}],
			["repair_fork_tines", "Stitch the bending bridge for the porters' wages", 27, -2, {"gold": 87, "scraps": 4}],
			["leave", "Leave the silver bridge swaying in the dark", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"refusals": [
			["repair_fork_tines", {"gold": 60, "scraps": 1}],
		],
	},
	"v3_tin_toy_submarine": {
		"title": "The Tin Toy Submarine",
		"description": "A tiny tin toy submarine looms like a ship to the dolls, half sunk in a black puddle beneath the stairs; a button-eyed mariner guards its leaking porthole with waxed red thread.",
		"choices": [
			["buy_hull_thread", "Buy the mariner's waxed hull-thread bundles", -20, 3, {"gold": 40, "scraps": 9}],
			["patch_submarine_seam", "Patch the tin hull for salvage wages", 38, -3, {"gold": 98, "scraps": 3}],
			["leave", "Let the toy submarine sink back into shadow", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"refusals": [
			["buy_hull_thread", {"gold": 19, "scraps": 6}],
			["patch_submarine_seam", {"gold": 60, "scraps": 2}],
		],
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
				_test_unique_new_choice_ids(records)
				# Every wallet service exercise must leave the global RNG untouched.
				seed(20261109)
				var lead := randi()
				for event_id in NEW_RECORDS:
					_test_new_record(records, event_id)
				var follow := randi()
				seed(20261109)
				var replay_lead := randi()
				var replay_follow := randi()
				_check(lead == replay_lead and follow == replay_follow,
					"wallet services draw no global RNG state")
				_check(records == snapshot, "all authored inputs remain unchanged")
	_test_rotation()
	for failure in failures:
		printerr(failure)
	print("v3_stitched_dropper_fork_submarine_roadside_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
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


## Every non-Leave choice ID of the three new records must be unique across the
## whole shared catalog, so no earlier or later record can shadow a new bargain.
func _test_unique_new_choice_ids(records: Array) -> void:
	var wanted: Array = []
	for event_id in NEW_RECORDS:
		for row in NEW_RECORDS[event_id].choices:
			if row[0] != "leave":
				wanted.append(row[0])
	var catalog_counts := {}
	for record in records:
		if not record is Dictionary:
			continue
		var choices: Variant = (record as Dictionary).get("choices")
		if not choices is Array:
			continue
		for choice in choices:
			if choice is Dictionary and (choice as Dictionary).get("id") is String:
				var choice_id: String = (choice as Dictionary)["id"]
				catalog_counts[choice_id] = int(catalog_counts.get(choice_id, 0)) + 1
	for choice_id in wanted:
		_check(wanted.count(choice_id) == 1, "distinct new non-Leave choice ID: " + choice_id)
		_check(int(catalog_counts.get(choice_id, 0)) == 1,
			"new non-Leave choice ID unique across the catalog: " + choice_id)


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
	for witness in expected.refusals:
		_test_short_refusal(record, expected, witness)
	_test_unknown_choice(record)
	_test_repeated_claim(record, expected)
	var kinds: Dictionary = exercised.get(event_id, {})
	for witness in expected.refusals:
		_check(kinds.get(witness[0], false),
			"new Event exercised fail-closed refusal witness " + witness[0] + ": " + tag)
	_check(kinds.get("unknown", false), "new Event exercised fail-closed witness unknown: " + tag)
	_check(kinds.get("repeated", false), "new Event exercised fail-closed witness repeated: " + tag)


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
	_check(selector.get_event() == original, "service event detached and unchanged: " + tag)


## One short-resource witness: the paid choice is unaffordable, the refusal
## keeps the wallet, the record and the unclaimed visit intact, and a funded
## retry then settles that same visit; the duplicate claim after it fails.
func _test_short_refusal(record: Dictionary, expected: Dictionary, witness: Array) -> void:
	var choice_id: String = witness[0]
	var short_wallet: Dictionary = (witness[1] as Dictionary).duplicate(true)
	var before: Dictionary = short_wallet.duplicate(true)
	var original: Dictionary = record.duplicate(true)
	var tag: String = record.id + "/" + choice_id + "/short"
	var settled_balance: Dictionary = {}
	for row in expected.choices:
		if row[0] == choice_id:
			settled_balance = row[4]
	_check(not settled_balance.is_empty(), "refusal witness is an authored paid choice: " + tag)
	if settled_balance.is_empty():
		return
	var selector := RunEventChoice.new(record)
	var forecast := _preview_entry(selector.preview_wallet_choices(short_wallet), choice_id)
	_check(not forecast.is_empty() and forecast.get("affordable") == false
		and forecast.get("wallet") == before,
		"short wallet previews the paid choice unavailable: " + tag)
	var receipt := selector.choose_with_wallet(choice_id, short_wallet)
	_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": before},
		"short wallet refuses the paid choice unchanged: " + tag)
	_check(short_wallet == before and record == original
		and selector.is_valid() and not selector.is_claimed(),
		"refusal preserves inputs and leaves the visit unclaimed: " + tag)
	receipt.wallet.gold += 999
	_check(short_wallet == before, "refusal wallet detached: " + tag)
	# The refusal consumed no visit: a funded retry on the same selector settles.
	var retry_wallet := {"gold": 60, "scraps": 6}
	var retry := selector.choose_with_wallet(choice_id, retry_wallet)
	_check(retry == {"ok": true, "event_id": record.id, "choice_id": choice_id,
		"wallet": settled_balance},
		"funded retry settles the refused visit: " + tag)
	_check(selector.is_claimed() and not selector.is_valid(),
		"funded retry claims the visit exactly once: " + tag)
	_check(retry_wallet == FUNDED_WALLET and record == original,
		"funded retry preserves caller wallet and event data: " + tag)
	var settled: Dictionary = (retry.get("wallet") as Dictionary).duplicate(true)
	var replay := selector.choose_with_wallet(choice_id, settled)
	_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": settled},
		"duplicate claim after success denies without another settlement: " + tag)
	_check(selector.preview_wallet_choices(settled) == DENIED_PREVIEW,
		"claimed visit refuses a later preview: " + tag)
	_mark_exercised(record.id, choice_id)


## An unknown choice ID denies without spending, claiming or changing anything,
## and the free Leave remains usable on that same unclaimed visit.
func _test_unknown_choice(record: Dictionary) -> void:
	var tag: String = record.id
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 60, "scraps": 6}
	var before := wallet.duplicate(true)
	var receipt := selector.choose_with_wallet("no_such_roadside_bargain_choice", wallet)
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
## exactly once, alongside the surviving anchors, serve authentic detached records
## that build valid selectors, and reach each new record through a seeded
## all-but-one exclusion selection without any fixed seed-to-event mapping.
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
	# Selective service reachability: exclude every returned ID except one new
	# ID, then a locally seeded draw must serve exactly that authentic record.
	for event_id in NEW_RECORDS:
		var exclusions: Array = []
		for other_id in ids:
			if other_id != event_id:
				exclusions.append(other_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261109
		var picked: Dictionary = rotation.select_event(rng, exclusions)
		_check(picked.get("ok") == true and picked.get("event") is Dictionary
			and (picked.get("event") as Dictionary).get("id") == event_id,
			"all-but-one exclusion selects the intended new record: " + event_id)
		if picked.get("ok") == true and picked.get("event") is Dictionary:
			_check(source_records.has(event_id)
				and (picked.get("event") as Dictionary) == source_records[event_id],
				"seeded exclusion selection serves the authentic record: " + event_id)
	# Returned listings are detached: clearing them cannot alter the rotation.
	listing.clear()
	ids.clear()
	_check(not rotation.get_generic_event_ids().is_empty() and not rotation.get_generic_events().is_empty(),
		"returned listings are detached")


func _mark_exercised(event_id: String, kind: String) -> void:
	var kinds: Dictionary = exercised.get(event_id, {})
	kinds[kind] = true
	exercised[event_id] = kinds

