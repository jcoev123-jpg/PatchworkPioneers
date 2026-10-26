extends SceneTree
## Deterministic headless test for the six V3-4 twilight roadside wallet Events
## appended to data/events/m04_events.json.
##
## The expected stories below are an independent copy of the authored contract;
## the production catalog is never read back as its own oracle. Only per-ID
## membership is asserted: no catalog total, no complete ordered ID list and no
## absolute index. The test covers:
##   - the raw JSON records (exact id/title/description and three choices with
##     authored text and signed gold/scraps outcomes, with exactly one genuine
##     free Leave) appended after the preexisting v3_ragdoll_bell_foundry record;
##   - the named older anchors kept unchanged (button_trail, estate_sale and the
##     roadside v3_raincoat_bridge) and quiet_spool still a separately routed
##     special that the generic rotation never offers;
##   - the default shipped RunM04EventRotation admitting each story exactly once,
##     a seeded forced selection per story that draws exactly once and returns a
##     detached record, a refused repeat that consumes no RNG, and an unchanged
##     source catalog after every selection and preview;
##   - RunEventChoice preview and settlement for every choice of every story:
##     funded, exact boundary, one-unit shortfalls refused without spending or
##     latching, the free Leave at a zero wallet, no replay, and malformed
##     wallet/record negatives;
##   - the real sewn Event panel scene mounted for representative branches among
##     the six: authored words, signed deltas, exact after-balance and shortfall,
##     disabled shortfall tickets, one receipt from a pressed ticket and one from
##     a physical number key in separate offers, with focus and Leave intact.

const EVENTS_PATH := "res://data/events/m04_events.json"
const ROADSIDE_EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const PANEL_SCENE := "res://scenes/event_choice_panel.tscn"
const SPECIAL_ID := "quiet_spool"
const TAIL_ANCHOR_ID := "v3_ragdoll_bell_foundry"
const SEED_BASE := 347000

const EXPECTED := {
	"v3_ember_needle_smithy": {
		"title": "The Ember-Needle Smithy",
		"description": "An amber-lit ragdoll smith draws glowing copper needles through a midnight-plum quilt.",
		"choices": [
			{"id": "polish_bent_needles", "text": "Polish a tray of bent needles (spend 1 scrap; gain 20 gold)", "gold": 20, "scraps": -1},
			{"id": "buy_ember_thread", "text": "Buy three spools of ember thread (spend 17 gold; gain 3 scraps)", "gold": -17, "scraps": 3},
			{"id": "leave_smithy", "text": "Leave the needles cooling", "gold": 0, "scraps": 0},
		],
	},
	"v3_gloamveil_laundry": {
		"title": "The Gloamveil Laundry",
		"description": "Button-eyed washer dolls hang oxblood velvet veils across lines of silver running-stitch.",
		"choices": [
			{"id": "gather_soft_lint", "text": "Gather discarded soft lint (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "buy_dye_cord", "text": "Buy two bundles of dyed cord (spend 14 gold; gain 2 scraps)", "gold": -14, "scraps": 2},
			{"id": "leave_laundry", "text": "Leave the veils to dry", "gold": 0, "scraps": 0},
		],
	},
	"v3_bellflower_patch_barge": {
		"title": "The Bellflower Patch Barge",
		"description": "A quilt-sailed barge floats among enormous sewn bellflowers, its ferryman counting copper bells.",
		"choices": [
			{"id": "mend_torn_sail", "text": "Mend the torn sail (spend 2 scraps; earn 34 gold)", "gold": 34, "scraps": -2},
			{"id": "carry_ferry_parcels", "text": "Carry the sealed parcels (+10 gold)", "gold": 10, "scraps": 0},
			{"id": "leave_barge", "text": "Wave the barge onward", "gold": 0, "scraps": 0},
		],
	},
	"v3_rosebutton_oracle": {
		"title": "The Rosebutton Oracle",
		"description": "A plump button-eyed oracle lays mismatched rose-shaped buttons on a star-patterned tablecloth.",
		"choices": [
			{"id": "trade_rose_button", "text": "Trade a rare rose button (spend 1 scrap; gain 23 gold)", "gold": 23, "scraps": -1},
			{"id": "buy_fortune_thread", "text": "Buy three fortune-thread spools (spend 19 gold; gain 3 scraps)", "gold": -19, "scraps": 3},
			{"id": "leave_oracle", "text": "Keep your fortune unspoken", "gold": 0, "scraps": 0},
		],
	},
	"v3_saffron_thimble_observatory": {
		"title": "The Saffron Thimble Observatory",
		"description": "A brass thimble telescope peers through quilted midnight skies stitched with tiny stars.",
		"choices": [
			{"id": "chart_moon_seams", "text": "Chart the moon seams for the keeper (+13 gold)", "gold": 13, "scraps": 0},
			{"id": "purchase_star_silk", "text": "Purchase four star-silk offcuts (spend 22 gold; gain 4 scraps)", "gold": -22, "scraps": 4},
			{"id": "leave_stars", "text": "Close the observatory hatch", "gold": 0, "scraps": 0},
		],
	},
	"v3_hushthread_gatehouse": {
		"title": "The Hushthread Gatehouse",
		"description": "A sleepy patchwork gatekeeper counts stitches along a moss-green arch of giant safety pins.",
		"choices": [
			{"id": "gather_lock_cuttings", "text": "Gather loose lock cuttings (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "repair_pin_lock", "text": "Repair the pin lock (spend 2 scraps; gain 30 gold)", "gold": 30, "scraps": -2},
			{"id": "walk_round_gate", "text": "Walk around the silent gate", "gold": 0, "scraps": 0},
		],
	},
}

## Older stories that must stay selectable and unchanged: title, source file and
## each choice's [gold, scraps] outcome, written out independently of the catalog.
const ANCHORS := {
	"button_trail": {
		"file": "m04",
		"title": "The Button Trail",
		"deltas": {"follow": [0, 1], "leave": [-12, 2], "sell_buttons": [18, -1]},
	},
	"estate_sale": {
		"file": "m04",
		"title": "Estate Sale",
		"deltas": {"buy_thread": [-15, 2], "sell_fabric": [30, -2], "leave": [0, 0]},
	},
	"v3_ragdoll_bell_foundry": {
		"file": "m04",
		"title": "The Ragdoll Bell Foundry",
		"deltas": {"polish_clappers": [31, -2], "sweep_ribbons": [0, 1], "leave_foundry": [0, 0]},
	},
	"v3_raincoat_bridge": {
		"file": "roadside",
		"title": "The Raincoat Bridge",
		"deltas": {"salvage_hems": [0, 1], "trade_fare": [-12, 2], "take_detour": [0, 0]},
	},
}

## The separately routed special keeps its two authored choices in the source.
const SPECIAL_DELTAS := {"watch": [0, 1], "ignore": [0, 0]}

var failures: Array[String] = []
var checks := 0
var commits: Array[Dictionary] = []
var source_text := ""
var source_document: Dictionary = {}
var source_snapshot: Dictionary = {}
var roadside_document: Dictionary = {}
var sources: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(key: int) -> void:
	for state in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key as Key
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _on_commit(result: Dictionary) -> void:
	commits.append(result.duplicate(true))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	source_text = _read_text(EVENTS_PATH)
	source_document = _parse_document(EVENTS_PATH)
	roadside_document = _parse_document(ROADSIDE_EVENTS_PATH)
	source_snapshot = source_document.duplicate(true)
	if source_document.is_empty() or roadside_document.is_empty():
		_report()
		return
	_test_source_records()
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the default shipped rotation validates")
	_test_admission(rotation)
	var listing_snapshot: Array = rotation.get_generic_events()
	var records: Dictionary = {}
	var index := 0
	for event_id in EXPECTED:
		var record := _test_forced_selection(rotation, event_id, SEED_BASE + index)
		index += 1
		if record.is_empty():
			continue
		records[event_id] = record
		_test_service_flows(record, EXPECTED[event_id])
	_check(rotation.get_generic_events() == listing_snapshot,
		"selection, preview and settlement never mutate the rotation listing")
	await _test_panel_branches(records)
	_check(source_document == source_snapshot, "the parsed source catalog is unchanged by every flow")
	_check(_read_text(EVENTS_PATH) == source_text, "the shipped catalog file is never rewritten")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_twilight_wallet_events_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		_check(false, path + " exists")
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + " opens through FileAccess")
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _parse_document(path: String) -> Dictionary:
	var text := _read_text(path)
	if text.is_empty():
		return {}
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK and parser.data is Dictionary, path + " parses as a JSON object")
	if parsed != OK or not parser.data is Dictionary:
		return {}
	var events: Variant = (parser.data as Dictionary).get("events")
	_check(events is Array, path + " has an events array")
	if not events is Array:
		return {}
	return (parser.data as Dictionary).duplicate(true)


func _events_of(document: Dictionary) -> Array:
	var events: Variant = document.get("events")
	return events if events is Array else []


func _matches(listing: Array, event_id: String) -> Array:
	var found: Array = []
	for record in listing:
		if record is Dictionary and (record as Dictionary).get("id") == event_id:
			found.append(record)
	return found


func _deltas(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var choices: Variant = record.get("choices")
	if not choices is Array:
		return result
	for choice in choices:
		if not choice is Dictionary or not (choice as Dictionary).get("outcome") is Dictionary:
			continue
		var outcome: Dictionary = (choice as Dictionary)["outcome"]
		result[choice.get("id")] = [
			_signed_amount(outcome.get("gold")), _signed_amount(outcome.get("scraps"))]
	return result


## JSON may deliver whole numbers as floats; the authored contract is a whole
## signed amount either way.
func _signed_amount(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number and absf(number) <= 9007199254740992.0:
			return int(number)
	return null


func _check_anchor_record(record: Dictionary, anchor_id: String, where: String) -> void:
	var anchor: Dictionary = ANCHORS[anchor_id]
	_check(record.get("title") == anchor["title"], "anchor title unchanged (" + where + "): " + anchor_id)
	var table: Dictionary = anchor["deltas"]
	var expected: Dictionary = {}
	for choice_id in table:
		expected[choice_id] = [int(table[choice_id][0]), int(table[choice_id][1])]
	_check(_deltas(record) == expected,
		"anchor choice IDs and signed outcomes unchanged (" + where + "): " + anchor_id)


## Direct JSON inspection of the six appended records plus the named anchors.
func _test_source_records() -> void:
	var events: Array = _events_of(source_document)
	var roadside: Array = _events_of(roadside_document)
	var positions: Dictionary = {}
	for i in range(events.size()):
		var entry: Variant = events[i]
		if entry is Dictionary and (entry as Dictionary).get("id") is String:
			var key: String = (entry as Dictionary)["id"]
			positions[key] = i if not positions.has(key) else -1
	_check(positions.has(TAIL_ANCHOR_ID) and positions[TAIL_ANCHOR_ID] >= 0,
		"the preexisting anchor " + TAIL_ANCHOR_ID + " is present exactly once")
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches: Array = _matches(events, event_id)
		_check(matches.size() == 1, "exactly one authored record for " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		sources[event_id] = record
		if positions.has(TAIL_ANCHOR_ID) and positions.has(event_id):
			_check(positions[event_id] > positions[TAIL_ANCHOR_ID],
				event_id + " is appended after the preexisting anchor " + TAIL_ANCHOR_ID)
		_check(record.keys().size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices") and not record.has("required_hero"),
			"authored record carries exactly id/title/description/choices: " + event_id)
		_check(record.get("title") == contract["title"], "authored title: " + event_id)
		_check(record.get("description") == contract["description"], "authored description: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3, "exactly three authored choices: " + event_id)
		if not choices is Array or (choices as Array).size() != 3:
			continue
		var expected_choices: Array = contract["choices"]
		var seen_ids: Dictionary = {}
		var free_count := 0
		for i in range(3):
			var choice: Variant = (choices as Array)[i]
			var want: Dictionary = expected_choices[i]
			_check(choice is Dictionary, "choice is an object: %s #%d" % [event_id, i])
			if not choice is Dictionary:
				continue
			var label: String = event_id + " / " + str(want["id"])
			_check((choice as Dictionary).keys().size() == 3, "choice carries exactly id/text/outcome: " + label)
			_check(choice.get("id") == want["id"], "authored choice ID in order: " + label)
			_check(choice.get("text") == want["text"], "authored visible choice text: " + label)
			seen_ids[choice.get("id")] = true
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).keys().size() == 2,
				"wallet-only outcome: " + label)
			if not outcome is Dictionary:
				continue
			var gold: Variant = _signed_amount((outcome as Dictionary).get("gold"))
			var scraps: Variant = _signed_amount((outcome as Dictionary).get("scraps"))
			_check(gold != null and scraps != null, "integral outcome amounts: " + label)
			_check(gold == want["gold"] and scraps == want["scraps"], "exact signed outcome: " + label)
			if gold == 0 and scraps == 0:
				free_count += 1
		_check(seen_ids.size() == 3, "three distinct choice IDs: " + event_id)
		_check(free_count == 1, "exactly one genuine no-cost Leave: " + event_id)
		var last_choice: Dictionary = (choices as Array)[2]
		_check(_deltas(record).get(last_choice.get("id")) == [0, 0],
			"the third choice is the free Leave: " + event_id)
	_check(sources.size() == EXPECTED.size(), "every new story was found in the authored catalog")
	for anchor_id in ANCHORS:
		var pool: Array = roadside if ANCHORS[anchor_id]["file"] == "roadside" else events
		var anchor_matches: Array = _matches(pool, anchor_id)
		_check(anchor_matches.size() == 1,
			"older anchor present exactly once in its source file: " + anchor_id)
		if anchor_matches.size() == 1:
			_check_anchor_record(anchor_matches[0], anchor_id, "source file")
	var special_matches: Array = _matches(events, SPECIAL_ID)
	_check(special_matches.size() == 1, "the special quiet_spool record stays in the source catalog")
	if special_matches.size() == 1:
		_check(_deltas(special_matches[0]) == SPECIAL_DELTAS,
			"the special quiet_spool keeps its authored choices")


## Each new story joins the default rotation exactly once; older anchors stay
## selectable and quiet_spool never becomes a generic stop.
func _test_admission(rotation: RunM04EventRotation) -> void:
	var listing: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1, "default rotation lists once: " + event_id)
		var matches: Array = _matches(listing, event_id)
		_check(matches.size() == 1, "default rotation exposes one record: " + event_id)
		if matches.size() == 1 and sources.has(event_id):
			_check(matches[0] == sources[event_id], "default rotation copies the authored record: " + event_id)
	for anchor_id in ANCHORS:
		_check(ids.count(anchor_id) == 1, "older anchor stays selectable: " + anchor_id)
		var anchor_matches: Array = _matches(listing, anchor_id)
		if anchor_matches.size() == 1:
			_check_anchor_record(anchor_matches[0], anchor_id, "rotation")
	_check(not ids.has(SPECIAL_ID) and _matches(listing, SPECIAL_ID).is_empty(),
		"quiet_spool is never part of the generic rotation")
	for seed_value in range(1, 31):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var picked: Dictionary = rotation.select_event(rng)
		_check(picked.get("ok") == true and picked.get("event", {}).get("id") != SPECIAL_ID,
			"a seeded generic selection never reaches quiet_spool (seed %d)" % seed_value)


## Excludes every other eligible ID, so the seeded draw must pick this story with
## exactly one randi_range() draw and hand back a detached record. Excluding the
## story too leaves nothing eligible, which must reject without a draw.
func _test_forced_selection(rotation: RunM04EventRotation, event_id: String, seed_value: int) -> Dictionary:
	var excluded: Array = rotation.get_generic_event_ids()
	_check(excluded.has(event_id) and excluded.size() > 1, "a pool with competitors admits " + event_id)
	excluded.erase(event_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var oracle := RandomNumberGenerator.new()
	oracle.seed = seed_value
	oracle.randi_range(0, 0)
	var result: Dictionary = rotation.select_event(rng, excluded)
	_check(result.get("ok") == true, "forced selection succeeds: " + event_id)
	var record: Dictionary = result.get("event", {})
	_check(record.get("id") == event_id, "forced selection returns the story: " + event_id)
	_check(rng.state == oracle.state, "forced selection consumes exactly one draw: " + event_id)
	if record.get("id") != event_id:
		return {}
	var snapshot: Dictionary = record.duplicate(true)
	record["title"] = "MUTATED"
	(record["choices"] as Array).clear()
	var again_rng := RandomNumberGenerator.new()
	again_rng.seed = seed_value
	var again: Dictionary = rotation.select_event(again_rng, excluded)
	_check(again.get("event") == snapshot, "the selected record is detached from the rotation: " + event_id)
	_check(again_rng.state == oracle.state, "a replayed selection ends in the same RNG state: " + event_id)
	var repeat_excluded: Array = excluded.duplicate()
	repeat_excluded.append(event_id)
	var guard := RandomNumberGenerator.new()
	guard.seed = seed_value
	var guard_state := guard.state
	var repeat: Dictionary = rotation.select_event(guard, repeat_excluded)
	_check(repeat.get("ok") == false and (repeat.get("event") as Dictionary).is_empty(),
		"a previously visited story cannot be selected again: " + event_id)
	_check(guard.state == guard_state, "the refused repeat consumes no RNG: " + event_id)
	_check(source_document == source_snapshot, "selection never mutates the source catalog: " + event_id)
	return snapshot


func _wallet_after(wallet: Dictionary, choice: Dictionary) -> Dictionary:
	return {"gold": int(wallet["gold"]) + int(choice["gold"]),
		"scraps": int(wallet["scraps"]) + int(choice["scraps"])}


func _is_debit(choice: Dictionary) -> bool:
	return int(choice["gold"]) < 0 or int(choice["scraps"]) < 0


func _preview_map(preview: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return out
	for entry in entries:
		if entry is Dictionary:
			out[entry["choice_id"]] = entry
	return out


func _leave_id(choices: Array) -> String:
	for choice in choices:
		if int(choice["gold"]) == 0 and int(choice["scraps"]) == 0:
			return choice["id"]
	return ""


## RunEventChoice preview and settlement for every authored choice of one story.
func _test_service_flows(record: Dictionary, contract: Dictionary) -> void:
	var event_id: String = record["id"]
	var expected_choices: Array = contract["choices"]
	var funded := {"gold": 100, "scraps": 10}
	var zero := {"gold": 0, "scraps": 0}
	var leave_id: String = _leave_id(expected_choices)
	_check(not leave_id.is_empty(), "the contract lists a free Leave: " + event_id)
	var preview_service := RunEventChoice.new(record)
	_check(preview_service.is_valid(), "the selected record is a valid RunEventChoice: " + event_id)
	var preview: Dictionary = preview_service.preview_wallet_choices(funded)
	_check(preview.get("ok") == true and preview.get("event_id") == event_id,
		"a funded preview succeeds: " + event_id)
	var rows: Dictionary = _preview_map(preview)
	_check(rows.size() == 3, "the funded preview lists all three choices: " + event_id)
	for choice in expected_choices:
		var choice_id: String = choice["id"]
		var label: String = event_id + " / " + choice_id
		var after: Dictionary = _wallet_after(funded, choice)
		var row: Dictionary = rows.get(choice_id, {})
		_check(row.get("gold_delta") == int(choice["gold"]) and row.get("scraps_delta") == int(choice["scraps"]),
			"the funded preview reports the authored deltas: " + label)
		_check(row.get("affordable") == true and row.get("wallet") == after,
			"the funded preview forecasts the exact balance: " + label)
		var claimed: RunEventChoice = RunEventChoice.new(record)
		var receipt: Dictionary = claimed.choose_with_wallet(choice_id, funded)
		_check(receipt.get("ok") == true and receipt.get("event_id") == event_id
			and receipt.get("choice_id") == choice_id, "the funded claim names story and choice: " + label)
		_check(receipt.get("wallet") == after, "the funded claim applies the authored deltas once: " + label)
		_check(claimed.is_claimed() and not claimed.is_valid(),
			"the settled claim latches and closes the visit: " + label)
		var replay: Dictionary = claimed.choose_with_wallet(choice_id, funded)
		_check(replay.get("ok") == false and replay.get("wallet") == funded,
			"no second receipt after the claim: " + label)
		var alternate_id := ""
		for other in expected_choices:
			if other["id"] != choice_id:
				alternate_id = other["id"]
				break
		var alternate: Dictionary = claimed.choose_with_wallet(alternate_id, funded)
		_check(alternate.get("ok") == false and alternate.get("wallet") == funded,
			"no alternate choice settles a spent visit: " + label)
		# Exact boundary: the wallet holding precisely the cost still pays.
		var boundary := {"gold": maxi(0, -int(choice["gold"])), "scraps": maxi(0, -int(choice["scraps"]))}
		var boundary_after: Dictionary = _wallet_after(boundary, choice)
		var boundary_service := RunEventChoice.new(record)
		var boundary_row: Dictionary = _preview_map(
			boundary_service.preview_wallet_choices(boundary)).get(choice_id, {})
		_check(boundary_row.get("affordable") == true and boundary_row.get("wallet") == boundary_after,
			"an exactly funded choice stays affordable: " + label)
		var boundary_receipt: Dictionary = boundary_service.choose_with_wallet(choice_id, boundary)
		_check(boundary_receipt.get("ok") == true and boundary_receipt.get("wallet") == boundary_after,
			"an exactly funded choice settles its authored deltas: " + label)
		# One unit short in each debited currency: refused, unchanged, unlatched.
		var shortfalls: Array = []
		if int(choice["gold"]) < 0:
			shortfalls.append({"gold": -int(choice["gold"]) - 1, "scraps": 10})
		if int(choice["scraps"]) < 0:
			shortfalls.append({"gold": 100, "scraps": -int(choice["scraps"]) - 1})
		for short in shortfalls:
			var poor := RunEventChoice.new(record)
			var poor_preview: Dictionary = _preview_map(poor.preview_wallet_choices(short))
			_check(poor_preview.get(choice_id, {}).get("affordable") == false
				and poor_preview.get(choice_id, {}).get("wallet") == short,
				"a one-unit shortfall is forecast as unaffordable: " + label)
			var denied: Dictionary = poor.choose_with_wallet(choice_id, short)
			_check(denied.get("ok") == false and denied.get("wallet") == short,
				"a one-unit shortfall is refused with the wallet unchanged: " + label)
			_check(not poor.is_claimed() and poor.is_valid(),
				"a refused trade leaves the visit open: " + label)
			var escape: Dictionary = poor.choose_with_wallet(leave_id, short)
			_check(escape.get("ok") == true and escape.get("wallet") == short,
				"the free Leave still settles after a refusal: " + label)
			_check(poor.choose_with_wallet(choice_id, funded).get("ok") == false,
				"nothing can be spent after the Leave: " + label)
		if not _is_debit(choice):
			var free_service := RunEventChoice.new(record)
			var free_receipt: Dictionary = free_service.choose_with_wallet(choice_id, zero)
			_check(free_receipt.get("ok") == true
				and free_receipt.get("wallet") == _wallet_after(zero, choice),
				"a no-debit choice settles from an empty wallet: " + label)
			_check(free_service.choose_with_wallet(choice_id, zero).get("ok") == false,
				"an empty-wallet claim cannot be replayed: " + label)
	_check(preview_service.is_valid() and not preview_service.is_claimed(),
		"previews never consume the visit: " + event_id)
	# The free Leave is always available at a zero wallet.
	var leave_service := RunEventChoice.new(record)
	var leave_rows: Dictionary = _preview_map(leave_service.preview_wallet_choices(zero))
	_check(leave_rows.get(leave_id, {}).get("affordable") == true,
		"the free Leave is affordable at a zero wallet: " + event_id)
	var leave_receipt: Dictionary = leave_service.choose_with_wallet(leave_id, zero)
	_check(leave_receipt.get("ok") == true and leave_receipt.get("wallet") == zero,
		"the free Leave settles without a charge: " + event_id)
	# Malformed wallets and unknown choices reject without latching.
	var bad_wallets: Array = [
		null, {}, {"gold": 1}, {"gold": 1.0, "scraps": 0}, {"gold": -1, "scraps": 0},
		{"gold": 0, "scraps": "0"}, {"gold": 0, "scraps": 0, "extra": 0},
	]
	for bad in bad_wallets:
		var fresh := RunEventChoice.new(record)
		var denied: Dictionary = fresh.choose_with_wallet(leave_id, bad)
		_check(denied.get("ok") == false and (denied.get("wallet") as Dictionary).is_empty(),
			"a malformed wallet is refused with no wallet: " + event_id + " " + str(bad))
		_check(fresh.preview_wallet_choices(bad).get("ok") == false,
			"a malformed wallet cannot be previewed: " + event_id + " " + str(bad))
		_check(not fresh.is_claimed() and fresh.is_valid(),
			"a malformed wallet never latches the visit: " + event_id + " " + str(bad))
	var stranger := RunEventChoice.new(record)
	var unknown: Dictionary = stranger.choose_with_wallet("unlisted_choice", zero)
	_check(unknown.get("ok") == false and unknown.get("wallet") == zero
		and not stranger.is_claimed() and stranger.is_valid(),
		"an unauthorized choice is refused without consuming the visit: " + event_id)
	# Malformed authored records stay closed.
	var missing_description: Dictionary = record.duplicate(true)
	missing_description.erase("description")
	var broken := RunEventChoice.new(missing_description)
	_check(not broken.is_valid() and broken.preview_wallet_choices(zero).get("ok") == false
		and broken.choose_with_wallet(leave_id, zero).get("ok") == false,
		"a record missing its description stays closed: " + event_id)
	var duplicated_choice: Dictionary = record.duplicate(true)
	var dup_choices: Array = duplicated_choice["choices"]
	(dup_choices[1] as Dictionary)["id"] = (dup_choices[0] as Dictionary)["id"]
	_check(not RunEventChoice.new(duplicated_choice).is_valid(),
		"duplicate choice IDs reject the record: " + event_id)
	var malformed_outcome: Dictionary = record.duplicate(true)
	var bad_choices: Array = malformed_outcome["choices"]
	(bad_choices[0] as Dictionary)["outcome"] = {"gold": 1}
	var outcome_service := RunEventChoice.new(malformed_outcome)
	_check(outcome_service.is_valid(), "a malformed outcome keeps the record open: " + event_id)
	var outcome_preview: Array = outcome_service.preview_wallet_choices(funded).get("choices", [])
	_check(outcome_preview.size() == 3 and outcome_preview[0].get("gold_delta") == null
		and outcome_preview[0].get("affordable") == false,
		"a malformed outcome is not settled or invented: " + event_id)
	_check(outcome_service.choose_with_wallet((bad_choices[0] as Dictionary)["id"], funded).get("ok") == false
		and not outcome_service.is_claimed(),
		"a malformed outcome choice cannot settle: " + event_id)
	_check(record == sources[event_id], "wallet play never mutates the selected record: " + event_id)


func _open_panel(record: Dictionary, wallet: Dictionary) -> LiveEventChoicePanel:
	commits.clear()
	var panel := (load(PANEL_SCENE) as PackedScene).instantiate() as LiveEventChoicePanel
	root.add_child(panel)
	await _frames()
	panel.wallet_choice_committed.connect(_on_commit)
	_check(panel.open_event_with_wallet(record, wallet),
		"the real panel mounts the wallet Event: " + str(record.get("id")))
	await _frames()
	_check(commits.is_empty(), "opening the wallet Event emits no receipt: " + str(record.get("id")))
	return panel


func _close_panel(panel: LiveEventChoicePanel) -> void:
	panel.close_event()
	panel.free()
	await _frames()


func _delta_line(choice: Dictionary) -> String:
	return "Gold %+d   |   Scraps %+d" % [int(choice["gold"]), int(choice["scraps"])]


func _after_line(wallet: Dictionary, choice: Dictionary) -> String:
	var after: Dictionary = _wallet_after(wallet, choice)
	return "After: %d gold | %d scraps" % [int(after["gold"]), int(after["scraps"])]


## Mounts the real sewn panel for representative branches among the six stories.
func _test_panel_branches(records: Dictionary) -> void:
	# A funded smithy: every ticket is enabled, shows its signed deltas and exact
	# after-balance, and one pressed ticket emits exactly one receipt.
	var ember: Dictionary = records.get("v3_ember_needle_smithy", {})
	_check(not ember.is_empty(), "the smithy really reached the mounted panel branch")
	if not ember.is_empty():
		var smithy_wallet := {"gold": 40, "scraps": 3}
		var panel: LiveEventChoicePanel = await _open_panel(ember, smithy_wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		_check(buttons.size() == 3, "the smithy mounts three sewn tickets")
		_check(panel.title_label.text == EXPECTED["v3_ember_needle_smithy"]["title"],
			"the panel shows the authored smithy title")
		_check(panel.description_label.text == EXPECTED["v3_ember_needle_smithy"]["description"],
			"the panel shows the authored smithy story")
		var smithy_choices: Array = EXPECTED["v3_ember_needle_smithy"]["choices"]
		if buttons.size() == 3:
			for i in range(3):
				var choice: Dictionary = smithy_choices[i]
				_check(buttons[i].text.begins_with(str(choice["text"])),
					"ticket shows the authored smithy words #%d" % i)
				_check(buttons[i].text.contains(_delta_line(choice)),
					"signed deltas on the smithy ticket #%d" % i)
				_check(buttons[i].text.contains(_after_line(smithy_wallet, choice)),
					"exact after-balance on the smithy ticket #%d" % i)
				_check(not buttons[i].disabled and buttons[i].focus_mode == Control.FOCUS_ALL,
					"funded smithy ticket is enabled and focusable #%d" % i)
			buttons[0].grab_focus()
			_check(buttons[0].has_focus(), "the smithy ticket takes real keyboard focus")
			await _key(KEY_TAB)
			_check(buttons[1].has_focus(), "Tab reaches the next affordable smithy ticket")
			buttons[0].pressed.emit()
			await _frames()
			_check(commits.size() == 1, "one pressed smithy ticket emits one receipt")
			if commits.size() == 1:
				_check(commits[0].get("event_id") == "v3_ember_needle_smithy"
					and commits[0].get("choice_id") == "polish_bent_needles",
					"the smithy receipt names the authored story and choice")
				_check(commits[0].get("wallet") == _wallet_after(smithy_wallet, smithy_choices[0]),
					"the smithy receipt applies the signed deltas once")
			for button in buttons:
				_check(button.disabled, "every smithy ticket closes after the claim")
			buttons[1].pressed.emit()
			await _key(KEY_2)
			_check(commits.size() == 1, "a replayed smithy ticket cannot spend again")
		await _close_panel(panel)

	# A funded barge: a physical number key is the only input, in its own offer.
	var barge: Dictionary = records.get("v3_bellflower_patch_barge", {})
	_check(not barge.is_empty(), "the barge really reached the mounted panel branch")
	if not barge.is_empty():
		var barge_wallet := {"gold": 50, "scraps": 5}
		var panel: LiveEventChoicePanel = await _open_panel(barge, barge_wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var barge_choices: Array = EXPECTED["v3_bellflower_patch_barge"]["choices"]
		_check(buttons.size() == 3, "the barge mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[1].text.contains(_delta_line(barge_choices[1]))
				and buttons[1].text.contains(_after_line(barge_wallet, barge_choices[1])),
				"the barge ticket shows its signed deltas and after-balance")
			_check(not buttons[1].disabled, "the barge parcel ticket is affordable")
			await _key(KEY_2)
			_check(commits.size() == 1, "one physical number key emits one receipt")
			if commits.size() == 1:
				_check(commits[0].get("event_id") == "v3_bellflower_patch_barge"
					and commits[0].get("choice_id") == "carry_ferry_parcels",
					"the key receipt names the authored barge choice")
				_check(commits[0].get("wallet") == _wallet_after(barge_wallet, barge_choices[1]),
					"the key receipt applies the authored gain once")
			await _key(KEY_1)
			await _key(KEY_3)
			_check(commits.size() == 1, "keys after the barge claim cannot spend again")
		await _close_panel(panel)

	# A gold shortfall: the star-silk ticket is disabled with its exact need, and
	# the free Leave stays reachable and settles without a charge.
	var stars: Dictionary = records.get("v3_saffron_thimble_observatory", {})
	_check(not stars.is_empty(), "the observatory really reached the mounted panel branch")
	if not stars.is_empty():
		var stars_wallet := {"gold": 21, "scraps": 0}
		var panel: LiveEventChoicePanel = await _open_panel(stars, stars_wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var star_choices: Array = EXPECTED["v3_saffron_thimble_observatory"]["choices"]
		_check(buttons.size() == 3, "the observatory mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[1].disabled and buttons[1].focus_mode == Control.FOCUS_NONE,
				"the unaffordable star-silk ticket is disabled and unfocusable")
			_check(buttons[1].text.contains("Need 1 gold") and not buttons[1].text.contains("After:"),
				"the star-silk ticket states its exact gold shortfall")
			_check(not buttons[0].disabled and not buttons[2].disabled,
				"the observatory gain and Leave stay enabled")
			buttons[1].pressed.emit()
			await _key(KEY_2)
			_check(commits.is_empty() and panel.has_open_event(),
				"a disabled star-silk ticket cannot settle or consume the visit")
			await _key(KEY_3)
			_check(commits.size() == 1, "the observatory Leave emits one receipt")
			if commits.size() == 1:
				_check(commits[0].get("choice_id") == star_choices[2]["id"]
					and commits[0].get("wallet") == stars_wallet,
					"the observatory Leave settles the wallet unchanged")
			buttons[2].pressed.emit()
			_check(commits.size() == 1, "the observatory Leave cannot be replayed")
		await _close_panel(panel)

	# A scrap shortfall: the pin-lock ticket states its exact need and stays inert;
	# the pressed Leave path still works.
	var gate: Dictionary = records.get("v3_hushthread_gatehouse", {})
	_check(not gate.is_empty(), "the gatehouse really reached the mounted panel branch")
	if not gate.is_empty():
		var gate_wallet := {"gold": 0, "scraps": 1}
		var panel: LiveEventChoicePanel = await _open_panel(gate, gate_wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var gate_choices: Array = EXPECTED["v3_hushthread_gatehouse"]["choices"]
		_check(buttons.size() == 3, "the gatehouse mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[1].disabled and buttons[1].text.contains("Need 1 scraps")
				and not buttons[1].text.contains("After:"),
				"the pin-lock ticket states its exact scrap shortfall")
			buttons[1].pressed.emit()
			await _frames()
			_check(commits.is_empty() and panel.has_open_event(),
				"a disabled pin-lock ticket cannot settle or consume the visit")
			buttons[2].pressed.emit()
			_check(commits.size() == 1 and commits[0].get("choice_id") == gate_choices[2]["id"]
				and commits[0].get("wallet") == gate_wallet,
				"the gatehouse pressed Leave settles the wallet unchanged")
		await _close_panel(panel)

	# A zero wallet: the gain ticket and the Leave stay available, the priced
	# ticket is disabled, and the signed delta shows the exact award.
	var laundry: Dictionary = records.get("v3_gloamveil_laundry", {})
	_check(not laundry.is_empty(), "the laundry really reached the mounted panel branch")
	if not laundry.is_empty():
		var zero := {"gold": 0, "scraps": 0}
		var panel: LiveEventChoicePanel = await _open_panel(laundry, zero)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var laundry_choices: Array = EXPECTED["v3_gloamveil_laundry"]["choices"]
		_check(buttons.size() == 3, "the laundry mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[0].text.contains(_delta_line(laundry_choices[0]))
				and buttons[0].text.contains(_after_line(zero, laundry_choices[0])),
				"the lint ticket shows its exact scrap award")
			_check(not buttons[0].disabled and not buttons[2].disabled,
				"the lint gain and the Leave are available at a zero wallet")
			_check(buttons[1].disabled and buttons[1].text.contains("Need 14 gold"),
				"the dyed-cord ticket states its exact gold shortfall")
			await _key(KEY_1)
			_check(commits.size() == 1 and commits[0].get("choice_id") == laundry_choices[0]["id"]
				and commits[0].get("wallet") == _wallet_after(zero, laundry_choices[0]),
				"the laundry key claim applies the authored scrap award once")
		await _close_panel(panel)
