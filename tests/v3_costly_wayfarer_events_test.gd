extends SceneTree
## Deterministic headless test for the six V3-4 costly-wayfarer wallet Events
## appended to data/events/m04_events.json.
##
## The expected stories below are an independent copy of the authored contract;
## the production catalog is never read back as its own oracle. Only per-ID
## membership is asserted: no catalog total, no complete ordered ID list and no
## absolute index. The test covers:
##   - the raw JSON records (exact id/title/description and three choices with
##     authored text and signed gold/scraps outcomes, with exactly one genuine
##     free Leave) appended after the preexisting v3_hushthread_gatehouse record;
##   - the named older anchors kept unchanged (button_trail, estate_sale and
##     v3_hushthread_gatehouse) and quiet_spool still a separately routed
##     special that the generic rotation never offers;
##   - the default shipped RunM04EventRotation admitting each story exactly once
##     and a seeded forced selection per story that draws exactly once, returns a
##     detached record and never re-offers an excluded story;
##   - the real app scene's existing catalog loader admitting all six without
##     starting a run;
##   - RunEventChoice preview and settlement for every choice of every story:
##     funded, exact boundary, an underfunded paid trade refused per story,
##     the free Leave at a zero wallet, no replay and fail-closed negatives;
##   - the real sewn Event panel scene mounted for two representative stories:
##     authored words, signed deltas, exact after-balance and shortfall, disabled
##     shortfall ticket, one receipt from a real mouse click and one from a
##     physical number key.

const EVENTS_PATH := "res://data/events/m04_events.json"
const PANEL_SCENE := "res://scenes/event_choice_panel.tscn"
const APP_SCENE := "res://scenes/app.tscn"
const SPECIAL_ID := "quiet_spool"
const TAIL_ANCHOR_ID := "v3_hushthread_gatehouse"
const SEED_BASE := 401000

const EXPECTED := {
	"v3_briar_pin_checkpoint": {
		"title": "The Briar-Pin Checkpoint",
		"description": "Two round ragdoll guards weigh spare pins beneath a moonlit gate stitched from blackthorn velvet.",
		"choices": [
			{"id": "sell_pin_cache", "text": "Surrender two pin bundles (spend 2 scraps; gain 29 gold)", "gold": 29, "scraps": -2},
			{"id": "buy_gate_thread", "text": "Buy the guarded gate thread (spend 14 gold; gain 2 scraps)", "gold": -14, "scraps": 2},
			{"id": "leave_checkpoint", "text": "Take the bramble bypass (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_mothlamp_tannery": {
		"title": "The Mothlamp Tannery",
		"description": "A button-eyed tanner hangs patterned moth-wing leather beside a glowing honey-coloured lamp.",
		"choices": [
			{"id": "mend_tanner_apron", "text": "Mend the tanner's apron (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
			{"id": "purchase_wing_lining", "text": "Buy three moth-wing linings (spend 22 gold; gain 3 scraps)", "gold": -22, "scraps": 3},
			{"id": "leave_tannery", "text": "Leave the lamp burning (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_crooked_bobbin_bell": {
		"title": "The Crooked Bobbin Bell",
		"description": "A giant crooked brass bell hangs over a velvet-clad village of stuffed button-faced dolls.",
		"choices": [
			{"id": "brace_bell_tower", "text": "Brace the leaning bell (spend 3 scraps; gain 41 gold)", "gold": 41, "scraps": -3},
			{"id": "buy_chime_cord", "text": "Buy a replacement chime cord (spend 11 gold; gain 1 scrap)", "gold": -11, "scraps": 1},
			{"id": "leave_bell", "text": "Let the bell sleep (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_velvet_valise_station": {
		"title": "The Velvet Valise Station",
		"description": "A sleepy doll porter stacks enormous quilted suitcases beneath a clock with mismatched button hands.",
		"choices": [
			{"id": "mend_valises", "text": "Repair two torn valises (spend 2 scraps; gain 34 gold)", "gold": 34, "scraps": -2},
			{"id": "buy_spare_straps", "text": "Buy spare suitcase straps (spend 16 gold; gain 2 scraps)", "gold": -16, "scraps": 2},
			{"id": "leave_station", "text": "Board no train (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_straw_crown_auction": {
		"title": "The Straw-Crown Auction",
		"description": "A plump scarecrow auctioneer raises a straw crown above a candlelit dais of stitched plum cloth.",
		"choices": [
			{"id": "polish_crown_buttons", "text": "Polish the crown buttons (spend 1 scrap; gain 17 gold)", "gold": 17, "scraps": -1},
			{"id": "purchase_straw_braid", "text": "Buy four coils of straw braid (spend 24 gold; gain 4 scraps)", "gold": -24, "scraps": 4},
			{"id": "leave_auction", "text": "Decline the final bid (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_quilt_reef_lighthouse": {
		"title": "The Quilt-Reef Lighthouse",
		"description": "A round lantern keeper patches a midnight-teal lighthouse above a sea of patterned quilt reefs.",
		"choices": [
			{"id": "stitch_beacon_sail", "text": "Stitch the beacon's sail (spend 2 scraps; gain 30 gold)", "gold": 30, "scraps": -2},
			{"id": "buy_lighthouse_wick", "text": "Buy three coils of wick (spend 18 gold; gain 3 scraps)", "gold": -18, "scraps": 3},
			{"id": "leave_lighthouse", "text": "Follow the dark shoreline (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

## Older stories that must stay present and unchanged: title and each choice's
## [gold, scraps] outcome, written out independently of the catalog.
const ANCHORS := {
	"button_trail": {
		"title": "The Button Trail",
		"deltas": {"follow": [0, 1], "leave": [-12, 2], "sell_buttons": [18, -1]},
	},
	"estate_sale": {
		"title": "Estate Sale",
		"deltas": {"buy_thread": [-15, 2], "sell_fabric": [30, -2], "leave": [0, 0]},
	},
	"v3_hushthread_gatehouse": {
		"title": "The Hushthread Gatehouse",
		"deltas": {"gather_lock_cuttings": [0, 1], "repair_pin_lock": [30, -2], "walk_round_gate": [0, 0]},
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


## A real pointer press and release on the mounted ticket, at its centre.
func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "mouse target is mounted")
	if not is_instance_valid(button):
		return
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "mouse target inside the viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await _frames()


func _on_commit(result: Dictionary) -> void:
	commits.append(result.duplicate(true))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	source_text = _read_text(EVENTS_PATH)
	source_document = _parse_document(EVENTS_PATH)
	source_snapshot = source_document.duplicate(true)
	if source_document.is_empty():
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
	await _test_app_catalog()
	await _test_panel_branches(records)
	_check(source_document == source_snapshot, "the parsed source catalog is unchanged by every flow")
	_check(_read_text(EVENTS_PATH) == source_text, "the shipped catalog file is never rewritten")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_costly_wayfarer_events_test: ", "PASS" if failures.is_empty() else "FAIL",
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
		var anchor_matches: Array = _matches(events, anchor_id)
		_check(anchor_matches.size() == 1, "older anchor present exactly once in the source file: " + anchor_id)
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
	var rows: Dictionary = _preview_map(preview_service.preview_wallet_choices(funded))
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
		var claimed := RunEventChoice.new(record)
		var receipt: Dictionary = claimed.choose_with_wallet(choice_id, funded)
		_check(receipt.get("ok") == true and receipt.get("event_id") == event_id
			and receipt.get("choice_id") == choice_id, "the funded claim names story and choice: " + label)
		_check(receipt.get("wallet") == after, "the funded claim applies the authored deltas once: " + label)
		_check(claimed.is_claimed() and not claimed.is_valid(),
			"the settled claim latches and closes the visit: " + label)
		var replay: Dictionary = claimed.choose_with_wallet(choice_id, funded)
		_check(replay.get("ok") == false and replay.get("wallet") == funded,
			"no second receipt after the claim: " + label)
		# Exact boundary: the wallet holding precisely each debited amount still pays.
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
	_check(preview_service.is_valid() and not preview_service.is_claimed(),
		"previews never consume the visit: " + event_id)
	# One underfunded paid trade for this story: one unit short of its cost.
	var paid_choice: Dictionary = {}
	for choice in expected_choices:
		if _is_debit(choice):
			paid_choice = choice
			break
	_check(not paid_choice.is_empty(), "the contract lists a paid exchange: " + event_id)
	if not paid_choice.is_empty():
		var short := {"gold": 100, "scraps": 10}
		if int(paid_choice["gold"]) < 0:
			short["gold"] = -int(paid_choice["gold"]) - 1
		if int(paid_choice["scraps"]) < 0:
			short["scraps"] = -int(paid_choice["scraps"]) - 1
		var poor := RunEventChoice.new(record)
		var poor_rows: Dictionary = _preview_map(poor.preview_wallet_choices(short))
		_check(poor_rows.get(paid_choice["id"], {}).get("affordable") == false
			and poor_rows.get(paid_choice["id"], {}).get("wallet") == short,
			"an underfunded paid trade is forecast as unaffordable: " + event_id)
		var denied: Dictionary = poor.choose_with_wallet(paid_choice["id"], short)
		_check(denied.get("ok") == false and denied.get("wallet") == short,
			"an underfunded paid trade is refused with no negative balance: " + event_id)
		_check(not poor.is_claimed() and poor.is_valid(),
			"a refused trade leaves the visit open: " + event_id)
		var escape: Dictionary = poor.choose_with_wallet(leave_id, short)
		_check(escape.get("ok") == true and escape.get("wallet") == short,
			"the free Leave still settles after a refusal: " + event_id)
		_check(poor.choose_with_wallet(paid_choice["id"], funded).get("ok") == false,
			"nothing can be spent after the Leave: " + event_id)
	# The free Leave settles at a zero wallet and cannot be replayed.
	var leave_service := RunEventChoice.new(record)
	var leave_rows: Dictionary = _preview_map(leave_service.preview_wallet_choices(zero))
	_check(leave_rows.get(leave_id, {}).get("affordable") == true,
		"the free Leave is affordable at a zero wallet: " + event_id)
	var leave_receipt: Dictionary = leave_service.choose_with_wallet(leave_id, zero)
	_check(leave_receipt.get("ok") == true and leave_receipt.get("wallet") == zero,
		"the free Leave settles without a charge: " + event_id)
	_check(leave_service.choose_with_wallet(leave_id, zero).get("ok") == false,
		"the free Leave cannot be replayed: " + event_id)
	# Fail-closed wallets and unknown choices mutate nothing.
	for bad in [null, {}, {"gold": 0, "scraps": 0, "extra": 0}, {"gold": -1, "scraps": 0},
			{"gold": 0.0, "scraps": 0}]:
		var fresh := RunEventChoice.new(record)
		var bad_claim: Dictionary = fresh.choose_with_wallet(leave_id, bad)
		_check(bad_claim.get("ok") == false and (bad_claim.get("wallet") as Dictionary).is_empty(),
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
	# A malformed authored outcome keeps its slot and cannot settle.
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


## The real app scene, mounted once at the title, admits the six stories through
## its existing generic catalog loader. No run is started here.
func _test_app_catalog() -> void:
	var app = load(APP_SCENE).instantiate()
	_check(app != null, "the real app scene instantiates")
	if app == null:
		return
	root.add_child(app)
	await _frames()
	_check(app.run_map == null and app.run_heroes.is_empty(), "the app rests at the title with no run")
	var live: Dictionary = app._load_wallet_event_catalog()
	_check(not live.is_empty(), "the app's existing catalog loader returns a live document")
	if not live.is_empty():
		var rotation := RunM04EventRotation.new(live)
		_check(rotation.is_catalog_valid(), "the app's loaded catalog validates for the real rotation")
		var ids: Array = rotation.get_generic_event_ids()
		for event_id in EXPECTED:
			_check(ids.count(event_id) == 1, "the app's catalog admits the story once: " + event_id)
		_check(not ids.has(SPECIAL_ID), "the app's catalog never routes quiet_spool generically")
	_check(app.run_map == null and app.run_heroes.is_empty(), "loading the catalog starts no run")
	app.free()
	await _frames()


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


## Mounts the real sewn panel for two representative stories: one mouse claim and
## one physical number key claim, each with honest shortfall and forecast labels.
func _test_panel_branches(records: Dictionary) -> void:
	var checkpoint: Dictionary = records.get("v3_briar_pin_checkpoint", {})
	_check(not checkpoint.is_empty(), "the checkpoint really reached the mounted panel branch")
	if not checkpoint.is_empty():
		# One scrap short of the pin-bundle price; the guarded thread is affordable.
		var wallet := {"gold": 20, "scraps": 1}
		var panel: LiveEventChoicePanel = await _open_panel(checkpoint, wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var choices: Array = EXPECTED["v3_briar_pin_checkpoint"]["choices"]
		_check(buttons.size() == 3, "the checkpoint mounts three sewn tickets")
		_check(panel.title_label.text == EXPECTED["v3_briar_pin_checkpoint"]["title"],
			"the panel shows the authored checkpoint title")
		_check(panel.description_label.text == EXPECTED["v3_briar_pin_checkpoint"]["description"],
			"the panel shows the authored checkpoint story")
		if buttons.size() == 3:
			_check(buttons[0].text.begins_with(str(choices[0]["text"]))
				and buttons[0].text.contains(_delta_line(choices[0])),
				"the pin-bundle ticket shows its authored words and signed deltas")
			_check(buttons[0].disabled and buttons[0].focus_mode == Control.FOCUS_NONE,
				"the unaffordable pin-bundle ticket is disabled and unfocusable")
			_check(buttons[0].text.contains("Need 1 scraps") and not buttons[0].text.contains("After:"),
				"the pin-bundle ticket states its exact scrap shortfall")
			_check(buttons[1].text.begins_with(str(choices[1]["text"]))
				and buttons[1].text.contains(_delta_line(choices[1]))
				and buttons[1].text.contains(_after_line(wallet, choices[1])),
				"the gate-thread ticket shows its words, deltas and exact after-balance")
			_check(not buttons[1].disabled, "the affordable gate thread is enabled")
			_check(buttons[2].text.contains(_delta_line(choices[2]))
				and buttons[2].text.contains(_after_line(wallet, choices[2])) and not buttons[2].disabled,
				"the free bramble bypass stays available with a zero delta")
			await _click(buttons[1])
			_check(commits.size() == 1, "one real mouse click on the checkpoint ticket emits one receipt")
			if commits.size() == 1:
				_check(commits[0].get("event_id") == "v3_briar_pin_checkpoint"
					and commits[0].get("choice_id") == choices[1]["id"],
					"the checkpoint receipt names the authored story and choice")
				_check(commits[0].get("wallet") == _wallet_after(wallet, choices[1]),
					"the checkpoint receipt applies the signed deltas once")
			for button in buttons:
				_check(button.disabled, "every checkpoint ticket closes after the claim")
			buttons[1].pressed.emit()
			await _key(KEY_3)
			_check(commits.size() == 1, "a replayed checkpoint ticket cannot spend again")
		await _close_panel(panel)

	var lighthouse: Dictionary = records.get("v3_quilt_reef_lighthouse", {})
	_check(not lighthouse.is_empty(), "the lighthouse really reached the mounted panel branch")
	if not lighthouse.is_empty():
		var wallet := {"gold": 40, "scraps": 4}
		var panel: LiveEventChoicePanel = await _open_panel(lighthouse, wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var choices: Array = EXPECTED["v3_quilt_reef_lighthouse"]["choices"]
		_check(buttons.size() == 3, "the lighthouse mounts three sewn tickets")
		if buttons.size() == 3:
			for i in range(3):
				_check(buttons[i].text.begins_with(str(choices[i]["text"]))
					and buttons[i].text.contains(_delta_line(choices[i]))
					and buttons[i].text.contains(_after_line(wallet, choices[i]))
					and not buttons[i].disabled,
					"funded lighthouse ticket shows its words, deltas and after-balance #%d" % i)
			await _key(KEY_1)
			_check(commits.size() == 1, "one physical number key emits one receipt")
			if commits.size() == 1:
				_check(commits[0].get("event_id") == "v3_quilt_reef_lighthouse"
					and commits[0].get("choice_id") == choices[0]["id"],
					"the key receipt names the authored lighthouse choice")
				_check(commits[0].get("wallet") == _wallet_after(wallet, choices[0]),
					"the key receipt applies the authored gain and scrap cost once")
			await _key(KEY_2)
			await _key(KEY_3)
			_check(commits.size() == 1, "keys after the lighthouse claim cannot spend again")
		await _close_panel(panel)
