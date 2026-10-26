extends SceneTree
## Deterministic headless test for the six V3-4 moonlit crossroads wallet Events
## appended to data/events/v3_roadside_events.json.
##
## The expected stories below are an independent copy of the authored contract;
## the production catalog is never read back as its own oracle. Only per-ID
## membership is asserted: no catalog total, no complete ordered ID list and no
## absolute index. The test covers:
##   - the raw JSON records (exact id/title/description and three choices with
##     visible text and signed gold/scraps outcomes, with exactly one genuine free
##     Leave), unique across both shipped catalog sources;
##   - the named older anchors v3_raincoat_bridge and v3_lullaby_stitch_chapel
##     kept with their original authored values, and quiet_spool still a
##     separately routed special that the generic rotation never offers;
##   - the default shipped RunM04EventRotation admitting each story exactly once,
##     a seeded forced selection per story that draws exactly once and returns a
##     detached record, a refused exhausted replay that consumes no RNG, and an
##     unchanged source catalog after every selection and preview;
##   - RunEventChoice preview and settlement for every choice of every story:
##     funded, exact boundary, one-unit shortfalls refused without spending or
##     latching, the free Leave at a zero wallet, no replay, and malformed
##     wallet/record negatives;
##   - the real sewn Event panel scene mounted for all six stories and then for
##     representative branches: authored captions, signed deltas, exact
##     after-balance and shortfall, disabled shortfall tickets, one receipt from a
##     real pressed ticket and one from a physical number key in separate offers,
##     with focus, hidden and repeated-input inertness preserved.

const ROADSIDE_EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const GENERIC_EVENTS_PATH := "res://data/events/m04_events.json"
const PANEL_SCENE := "res://scenes/event_choice_panel.tscn"
const SPECIAL_ID := "quiet_spool"
const SEED_BASE := 413000

const EXPECTED := {
	"v3_silver_cobble_toll": {
		"title": "The Silver-Cobble Toll",
		"description": "Stuffed crows perch on a silver-stitched toll bridge, their brass bells jingling whenever travellers pass.",
		"choices": [
			{"id": "rewind_bellcord", "text": "Rewind the bell cord (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "purchase_pass", "text": "Buy two spools of pass-thread (spend 15 gold; gain 2 scraps)", "gold": -15, "scraps": 2},
			{"id": "cross_sidepath", "text": "Take the stitched sidepath (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_amber_thimble_loom": {
		"title": "The Amber-Thimble Loom",
		"description": "A plump ragdoll weaver feeds copper thread through an enormous amber thimble beneath a velvet awning.",
		"choices": [
			{"id": "repair_looms", "text": "Repair the thimble loom (spend 2 scraps; gain 32 gold)", "gold": 32, "scraps": -2},
			{"id": "untangle_bobbins", "text": "Untangle fallen bobbins (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave_loom", "text": "Leave the loom humming (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_midnight_moth_post": {
		"title": "The Midnight Moth Post",
		"description": "Button-eyed moth couriers carry sealed plum-velvet letters from a crooked patchwork postbox.",
		"choices": [
			{"id": "sort_letters", "text": "Sort the wayward letters (+13 gold)", "gold": 13, "scraps": 0},
			{"id": "buy_moth_stamps", "text": "Buy moth-wing stamps (spend 19 gold; gain 3 scraps)", "gold": -19, "scraps": 3},
			{"id": "leave_post", "text": "Let the moths deliver their letters (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_rosequilt_bridgekeeper": {
		"title": "The Rosequilt Bridgekeeper",
		"description": "A stitched-X-eyed bridgekeeper polishes rosy brass buttons on a moss-green quilt railing.",
		"choices": [
			{"id": "barter_button", "text": "Barter a spare button (spend 1 scrap; gain 23 gold)", "gold": 23, "scraps": -1},
			{"id": "buy_safety_pins", "text": "Buy safety pins (spend 12 gold; gain 2 scraps)", "gold": -12, "scraps": 2},
			{"id": "leave_bridge", "text": "Cross without trading (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_starhook_washhouse": {
		"title": "The Starhook Washhouse",
		"description": "Silver hooks hold dripping star-patterned quilts over a lantern-lit blackwater washhouse.",
		"choices": [
			{"id": "collect_frayed_trim", "text": "Collect the frayed trim (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "sell_copper_hooks", "text": "Sell two copper hooks (spend 2 scraps; gain 34 gold)", "gold": 34, "scraps": -2},
			{"id": "leave_washhouse", "text": "Leave the quilts to dry (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_bellspool_masquerade": {
		"title": "The Bellspool Masquerade",
		"description": "Round velvet dolls dance beneath hanging bobbin bells, wearing mismatched stitched masks.",
		"choices": [
			{"id": "sew_masks", "text": "Sew masks for the dancers (+18 gold)", "gold": 18, "scraps": 0},
			{"id": "buy_masque_thread", "text": "Buy masque thread (spend 21 gold; gain 4 scraps)", "gold": -21, "scraps": 4},
			{"id": "leave_masquerade", "text": "Slip away before the last bell (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

## Older roadside stories that must stay selectable and unchanged: written out
## independently of the catalog, per ID rather than as one ordered catalog list.
const ANCHORS := {
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"description": "A soaked quilt bridge stretching over a ravine.",
		"choices": [
			{"id": "salvage_hems", "text": "Salvage loose hems (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "trade_fare", "text": "Trade fare for threads (-12 gold, +2 scraps)", "gold": -12, "scraps": 2},
			{"id": "take_detour", "text": "Take a detour (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_lullaby_stitch_chapel": {
		"title": "The Lullaby Stitch Chapel",
		"description": "Tiny thread bells hum under moss-green stitched rafters while wax candles gutter in the draft.",
		"choices": [
			{"id": "clean_lanterns", "text": "Clean the tiny lanterns (+9 gold)", "gold": 9, "scraps": 0},
			{"id": "trade_bells", "text": "Trade for thread bells (-12 gold, +2 scraps)", "gold": -12, "scraps": 2},
			{"id": "leave_chapel", "text": "Leave the humming chapel (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

var failures: Array[String] = []
var checks := 0
var commits: Array[Dictionary] = []
var wallet_commits: Array[Dictionary] = []
var source_text := ""
var roadside_document: Dictionary = {}
var roadside_snapshot: Dictionary = {}
var generic_document: Dictionary = {}
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


func _key(key: Key) -> void:
	for state in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _mouse(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for state in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _on_commit(result: Dictionary) -> void:
	wallet_commits.append(result.duplicate(true))


func _on_legacy_commit(_event_id: String, _choice_id: String) -> void:
	commits.append({"legacy": true})


func _run() -> void:
	root.size = Vector2i(1280, 720)
	source_text = _read_text(ROADSIDE_EVENTS_PATH)
	roadside_document = _parse_document(ROADSIDE_EVENTS_PATH)
	generic_document = _parse_document(GENERIC_EVENTS_PATH)
	roadside_snapshot = roadside_document.duplicate(true)
	if roadside_document.is_empty() or generic_document.is_empty():
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
	_check(roadside_document == roadside_snapshot,
		"the parsed roadside catalog is unchanged by every flow")
	_check(_read_text(ROADSIDE_EVENTS_PATH) == source_text,
		"the shipped roadside catalog file is never rewritten")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_moonlit_crossroads_events_test: ", "PASS" if failures.is_empty() else "FAIL",
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


## Verbatim presentation, choice shape and signed deltas against one independent
## literal contract. `origin` only labels failure messages.
func _check_record(record: Variant, event_id: String, contract: Dictionary, origin: String) -> void:
	var label := origin + " " + event_id
	_check(record is Dictionary, "record is an object: " + label)
	if not record is Dictionary:
		return
	var entry: Dictionary = record
	_check(entry.keys().size() == 4 and entry.has("id") and entry.has("title")
		and entry.has("description") and entry.has("choices"),
		"record carries exactly id/title/description/choices: " + label)
	_check(entry.get("id") == event_id, "authored ID: " + label)
	_check(entry.get("title") == contract["title"], "authored title: " + label)
	_check(entry.get("description") == contract["description"], "authored description: " + label)
	var choices: Variant = entry.get("choices")
	_check(choices is Array, "choices is an array: " + label)
	if not choices is Array:
		return
	_check((choices as Array).size() == 3, "exactly three choices: " + label)
	var expected_choices: Array = contract["choices"]
	var seen: Dictionary = {}
	for i in range(mini((choices as Array).size(), expected_choices.size())):
		var choice: Variant = (choices as Array)[i]
		var want: Dictionary = expected_choices[i]
		var choice_label: String = label + " / " + str(want["id"])
		_check(choice is Dictionary, "choice is an object: " + choice_label)
		if not choice is Dictionary:
			continue
		var authored: Dictionary = choice
		_check(authored.keys().size() == 3 and authored.has("id") and authored.has("text")
			and authored.has("outcome"),
			"choice carries exactly id/text/outcome: " + choice_label)
		_check(authored.get("id") == want["id"], "authored choice ID in order: " + choice_label)
		_check(authored.get("text") == want["text"], "authored choice text: " + choice_label)
		seen[authored.get("id")] = true
		var outcome: Variant = authored.get("outcome")
		_check(outcome is Dictionary, "outcome is an object: " + choice_label)
		if not outcome is Dictionary:
			continue
		var wallet_outcome: Dictionary = outcome
		_check(wallet_outcome.keys().size() == 2 and wallet_outcome.has("gold")
			and wallet_outcome.has("scraps"),
			"wallet-only outcome: " + choice_label)
		var gold: Variant = _signed_amount(wallet_outcome.get("gold"))
		var scraps: Variant = _signed_amount(wallet_outcome.get("scraps"))
		_check(gold != null and scraps != null, "integral outcome amounts: " + choice_label)
		_check(gold == want["gold"] and scraps == want["scraps"],
			"exact signed outcome: " + choice_label)
	_check(seen.size() == 3, "three distinct choice IDs: " + label)


## Direct JSON inspection of the six appended records, the two named anchors and
## the cross-catalog uniqueness of the new IDs.
func _test_source_records() -> void:
	var events: Array = _events_of(roadside_document)
	var generic_events: Array = _events_of(generic_document)
	var ids: Dictionary = {}
	var duplicates: Array = []
	for entry in events:
		_check(entry is Dictionary, "every roadside entry is a record object")
		if not entry is Dictionary:
			continue
		var raw_id: Variant = (entry as Dictionary).get("id")
		_check(raw_id is String and not (raw_id as String).strip_edges().is_empty(),
			"every roadside record has a nonblank string ID")
		if not raw_id is String:
			continue
		if ids.has(raw_id):
			duplicates.append(raw_id)
		ids[raw_id] = entry
	_check(duplicates.is_empty(), "roadside event IDs stay unique: " + str(duplicates))
	for event_id in EXPECTED:
		var matches: Array = _matches(events, event_id)
		_check(matches.size() == 1, "exactly one authored roadside record for " + event_id)
		_check(_matches(generic_events, event_id).is_empty(),
			"the new ID is unique across both catalogs: " + event_id)
		if matches.size() != 1:
			continue
		sources[event_id] = matches[0]
		_check_record(matches[0], event_id, EXPECTED[event_id], "source")
		var contract_choices: Array = EXPECTED[event_id]["choices"]
		var free_count := 0
		for choice in contract_choices:
			if int(choice["gold"]) == 0 and int(choice["scraps"]) == 0:
				free_count += 1
		_check(free_count == 1, "exactly one genuine no-cost Leave: " + event_id)
		var third: Dictionary = contract_choices[2]
		_check(int(third["gold"]) == 0 and int(third["scraps"]) == 0,
			"the third authored choice is the free Leave: " + event_id)
	_check(sources.size() == EXPECTED.size(), "every new story was found in the authored catalog")
	for anchor_id in ANCHORS:
		var anchor_matches: Array = _matches(events, anchor_id)
		_check(anchor_matches.size() == 1,
			"older anchor present exactly once in the roadside source: " + anchor_id)
		if anchor_matches.size() == 1:
			_check_record(anchor_matches[0], anchor_id, ANCHORS[anchor_id], "anchor")
	var special_matches: Array = _matches(generic_events, SPECIAL_ID)
	_check(special_matches.size() == 1,
		"the separately routed quiet_spool record stays in the generic source")


## Each new story joins the default rotation exactly once; older anchors stay
## selectable and quiet_spool never becomes a generic stop.
func _test_admission(rotation: RunM04EventRotation) -> void:
	var listing: Array = rotation.get_generic_events()
	var generic_ids: Array = rotation.get_generic_event_ids()
	for event_id in EXPECTED:
		_check(generic_ids.count(event_id) == 1, "default rotation lists once: " + event_id)
		var matches: Array = _matches(listing, event_id)
		_check(matches.size() == 1, "default rotation exposes one record: " + event_id)
		if matches.size() == 1 and sources.has(event_id):
			_check(matches[0] == sources[event_id], "default rotation copies the authored record: " + event_id)
	for anchor_id in ANCHORS:
		_check(generic_ids.count(anchor_id) == 1, "older anchor stays selectable: " + anchor_id)
		var anchor_matches: Array = _matches(listing, anchor_id)
		if anchor_matches.size() == 1:
			_check_record(anchor_matches[0], anchor_id, ANCHORS[anchor_id], "rotation")
	_check(not generic_ids.has(SPECIAL_ID) and _matches(listing, SPECIAL_ID).is_empty(),
		"quiet_spool is never part of the generic rotation")
	for seed_value in range(1, 31):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var picked: Dictionary = rotation.select_event(rng)
		_check(picked.get("ok") == true
			and (picked.get("event") as Dictionary).get("id") != SPECIAL_ID,
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
	if sources.has(event_id):
		_check(record == sources[event_id], "forced selection is the authentic authored record: " + event_id)
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
	_check(guard.state == guard_state, "the refused exhausted replay consumes no RNG: " + event_id)
	_check(roadside_document == roadside_snapshot,
		"selection never mutates the source catalog: " + event_id)
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
	var funded_wallet := {"gold": 100, "scraps": 10}
	var funded_snapshot: Dictionary = funded_wallet.duplicate(true)
	var zero := {"gold": 0, "scraps": 0}
	var zero_snapshot: Dictionary = zero.duplicate(true)
	var guard := RandomNumberGenerator.new()
	guard.seed = SEED_BASE + 500
	var guard_state: int = guard.state
	var leave_id: String = _leave_id(expected_choices)
	_check(not leave_id.is_empty(), "the contract lists a free Leave: " + event_id)
	var preview_service := RunEventChoice.new(record)
	_check(preview_service.is_valid(), "the selected record is a valid RunEventChoice: " + event_id)
	var preview: Dictionary = preview_service.preview_wallet_choices(funded_wallet)
	_check(preview.get("ok") == true and preview.get("event_id") == event_id,
		"a funded preview succeeds: " + event_id)
	var rows: Dictionary = _preview_map(preview)
	_check(rows.size() == 3, "the funded preview lists all three choices: " + event_id)
	for choice in expected_choices:
		var choice_id: String = choice["id"]
		var label: String = event_id + " / " + choice_id
		var after: Dictionary = _wallet_after(funded_wallet, choice)
		var row: Dictionary = rows.get(choice_id, {})
		_check(row.get("gold_delta") == int(choice["gold"])
			and row.get("scraps_delta") == int(choice["scraps"]),
			"the funded preview reports the authored deltas: " + label)
		_check(row.get("affordable") == true and row.get("wallet") == after,
			"the funded preview forecasts the exact balance: " + label)
		var claimed: RunEventChoice = RunEventChoice.new(record)
		var receipt: Dictionary = claimed.choose_with_wallet(choice_id, funded_wallet)
		_check(receipt.get("ok") == true and receipt.get("event_id") == event_id
			and receipt.get("choice_id") == choice_id,
			"the funded claim names story and choice: " + label)
		_check(receipt.get("wallet") == after, "the funded claim applies the authored deltas once: " + label)
		_check(claimed.is_claimed() and not claimed.is_valid(),
			"the settled claim latches and closes the visit: " + label)
		var replay: Dictionary = claimed.choose_with_wallet(choice_id, funded_wallet)
		_check(replay.get("ok") == false and replay.get("wallet") == funded_wallet,
			"no second receipt after the claim: " + label)
		var alternate_id := ""
		for other in expected_choices:
			if other["id"] != choice_id:
				alternate_id = other["id"]
				break
		var alternate: Dictionary = claimed.choose_with_wallet(alternate_id, funded_wallet)
		_check(alternate.get("ok") == false and alternate.get("wallet") == funded_wallet,
			"no alternate choice settles a spent visit: " + label)
		# Exact boundary: the wallet holding precisely the cost still pays.
		var boundary := {"gold": maxi(0, -int(choice["gold"])),
			"scraps": maxi(0, -int(choice["scraps"]))}
		var boundary_after: Dictionary = _wallet_after(boundary, choice)
		var boundary_service := RunEventChoice.new(record)
		var boundary_row: Dictionary = _preview_map(
			boundary_service.preview_wallet_choices(boundary)).get(choice_id, {})
		_check(boundary_row.get("affordable") == true and boundary_row.get("wallet") == boundary_after,
			"an exactly funded choice stays affordable: " + label)
		var boundary_receipt: Dictionary = boundary_service.choose_with_wallet(choice_id, boundary)
		_check(boundary_receipt.get("ok") == true
			and boundary_receipt.get("wallet") == boundary_after,
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
			_check(poor.choose_with_wallet(choice_id, funded_wallet).get("ok") == false,
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
	var outcome_preview: Array = outcome_service.preview_wallet_choices(funded_wallet).get("choices", [])
	_check(outcome_preview.size() == 3 and outcome_preview[0].get("gold_delta") == null
		and outcome_preview[0].get("affordable") == false,
		"a malformed outcome is not settled or invented: " + event_id)
	_check(outcome_service.choose_with_wallet((bad_choices[0] as Dictionary)["id"], funded_wallet).get("ok") == false
		and not outcome_service.is_claimed(),
		"a malformed outcome choice cannot settle: " + event_id)
	_check(guard.state == guard_state, "wallet play never touches a seeded run RNG: " + event_id)
	_check(funded_wallet == funded_snapshot and zero == zero_snapshot,
		"the caller's wallets are unchanged by wallet play: " + event_id)
	if sources.has(event_id):
		_check(record == sources[event_id], "wallet play never mutates the selected record: " + event_id)


func _open_panel(record: Dictionary, wallet: Dictionary) -> LiveEventChoicePanel:
	commits.clear()
	wallet_commits.clear()
	var panel := (load(PANEL_SCENE) as PackedScene).instantiate() as LiveEventChoicePanel
	root.add_child(panel)
	await _frames()
	panel.choice_committed.connect(_on_legacy_commit)
	panel.wallet_choice_committed.connect(_on_commit)
	_check(panel.open_event_with_wallet(record, wallet),
		"the real panel mounts the wallet Event: " + str(record.get("id")))
	await _frames()
	_check(wallet_commits.is_empty(), "opening the wallet Event emits no receipt: " + str(record.get("id")))
	_check(commits.is_empty(), "wallet mode never emits a legacy receipt: " + str(record.get("id")))
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


func _needs_line(wallet: Dictionary, choice: Dictionary) -> String:
	var needs := PackedStringArray()
	var missing_gold: int = -(int(wallet["gold"]) + int(choice["gold"]))
	var missing_scraps: int = -(int(wallet["scraps"]) + int(choice["scraps"]))
	if missing_gold > 0:
		needs.append("Need %d gold" % missing_gold)
	if missing_scraps > 0:
		needs.append("Need %d scraps" % missing_scraps)
	return "   •   ".join(needs)


## Mounts the real sewn panel for every new story, then for representative
## branches that need a particular purse.
func _test_panel_branches(records: Dictionary) -> void:
	# Every new story really mounts in wallet mode with its three authored
	# captions, signed deltas and exact funded after-balances.
	var funded_purse := {"gold": 50, "scraps": 10}
	for event_id in EXPECTED:
		var record: Dictionary = records.get(event_id, {})
		_check(not record.is_empty(), "the story really reached the mounted panel: " + event_id)
		if record.is_empty():
			continue
		var panel: LiveEventChoicePanel = await _open_panel(record, funded_purse)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var choices: Array = EXPECTED[event_id]["choices"]
		_check(panel.title_label.text == EXPECTED[event_id]["title"],
			"the panel shows the authored title: " + event_id)
		_check(panel.description_label.text == EXPECTED[event_id]["description"],
			"the panel shows the authored story: " + event_id)
		_check(buttons.size() == 3, "the panel mounts three sewn tickets: " + event_id)
		if buttons.size() == 3:
			for i in range(3):
				var choice: Dictionary = choices[i]
				_check(buttons[i].text.begins_with(str(choice["text"])),
					"ticket shows the authored words #%d: %s" % [i, event_id])
				_check(buttons[i].text.contains(_delta_line(choice)),
					"signed deltas on ticket #%d: %s" % [i, event_id])
				_check(buttons[i].text.contains(_after_line(funded_purse, choice)),
					"exact after-balance on ticket #%d: %s" % [i, event_id])
				_check(not buttons[i].disabled and buttons[i].focus_mode == Control.FOCUS_ALL,
					"funded ticket is enabled and focusable #%d: %s" % [i, event_id])
		await _close_panel(panel)

	# A funded toll bridge: a real pointer press on the priced ticket emits one
	# receipt and every ticket then closes.
	var toll: Dictionary = records.get("v3_silver_cobble_toll", {})
	_check(not toll.is_empty(), "the toll bridge reached the mounted pointer branch")
	if not toll.is_empty():
		var toll_wallet := {"gold": 20, "scraps": 1}
		var panel: LiveEventChoicePanel = await _open_panel(toll, toll_wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var toll_choices: Array = EXPECTED["v3_silver_cobble_toll"]["choices"]
		_check(buttons.size() == 3, "the toll bridge mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[1].text.contains(_delta_line(toll_choices[1]))
				and buttons[1].text.contains(_after_line(toll_wallet, toll_choices[1])),
				"the pass-thread ticket shows its signed deltas and after-balance")
			buttons[0].grab_focus()
			_check(buttons[0].has_focus(), "the toll ticket takes real keyboard focus")
			await _key(KEY_TAB)
			_check(buttons[1].has_focus(), "Tab reaches the next affordable toll ticket")
			await _mouse(buttons[1])
			_check(wallet_commits.size() == 1, "one pressed toll ticket emits one receipt")
			if wallet_commits.size() == 1:
				_check(wallet_commits[0].get("event_id") == "v3_silver_cobble_toll"
					and wallet_commits[0].get("choice_id") == "purchase_pass",
					"the toll receipt names the authored story and choice")
				_check(wallet_commits[0].get("wallet") == _wallet_after(toll_wallet, toll_choices[1]),
					"the toll receipt applies the signed deltas once")
			for button in buttons:
				_check(button.disabled, "every toll ticket closes after the claim")
			buttons[1].pressed.emit()
			await _key(KEY_2)
			await _mouse(buttons[2])
			_check(wallet_commits.size() == 1, "a replayed toll ticket cannot spend again")
		await _close_panel(panel)

	# A funded masquerade: a physical number key is the only input, in its own
	# offer, and focus order still reaches the middle ticket.
	var masque: Dictionary = records.get("v3_bellspool_masquerade", {})
	_check(not masque.is_empty(), "the masquerade reached the mounted key branch")
	if not masque.is_empty():
		var masque_wallet := {"gold": 25, "scraps": 0}
		var panel: LiveEventChoicePanel = await _open_panel(masque, masque_wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var masque_choices: Array = EXPECTED["v3_bellspool_masquerade"]["choices"]
		_check(buttons.size() == 3, "the masquerade mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[1].text.contains(_delta_line(masque_choices[1]))
				and buttons[1].text.contains(_after_line(masque_wallet, masque_choices[1])),
				"the masque-thread ticket shows its signed deltas and after-balance")
			_check(not buttons[1].disabled, "the masque-thread ticket is affordable")
			buttons[0].grab_focus()
			await _key(KEY_TAB)
			_check(buttons[1].has_focus(), "Tab reaches the masque-thread ticket")
			await _key(KEY_2)
			_check(wallet_commits.size() == 1, "one physical number key emits one receipt")
			if wallet_commits.size() == 1:
				_check(wallet_commits[0].get("event_id") == "v3_bellspool_masquerade"
					and wallet_commits[0].get("choice_id") == "buy_masque_thread",
					"the key receipt names the authored masquerade choice")
				_check(wallet_commits[0].get("wallet") == _wallet_after(masque_wallet, masque_choices[1]),
					"the key receipt applies the authored deltas once")
			await _key(KEY_1)
			await _key(KEY_3)
			buttons[1].pressed.emit()
			_check(wallet_commits.size() == 1, "keys and presses after the masquerade claim cannot spend again")
		await _close_panel(panel)

	# A scrap shortfall: the loom ticket is disabled with its exact need, while
	# the free Leave stays reachable and settles without a charge.
	var loom: Dictionary = records.get("v3_amber_thimble_loom", {})
	_check(not loom.is_empty(), "the loom reached the mounted shortfall branch")
	if not loom.is_empty():
		var loom_wallet := {"gold": 0, "scraps": 1}
		var panel: LiveEventChoicePanel = await _open_panel(loom, loom_wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var loom_choices: Array = EXPECTED["v3_amber_thimble_loom"]["choices"]
		_check(buttons.size() == 3, "the loom mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[0].disabled and buttons[0].focus_mode == Control.FOCUS_NONE,
				"the unaffordable loom ticket is disabled and unfocusable")
			_check(buttons[0].text.contains(_needs_line(loom_wallet, loom_choices[0]))
				and not buttons[0].text.contains("After:"),
				"the loom ticket states its exact scrap shortfall")
			_check(not buttons[1].disabled and not buttons[2].disabled,
				"the loom bobbin gain and Leave stay enabled")
			buttons[0].pressed.emit()
			await _key(KEY_1)
			panel.hide()
			await _frames()
			await _key(KEY_1)
			panel.show()
			await _frames()
			_check(wallet_commits.is_empty() and panel.has_open_event() and panel._selector.is_valid(),
				"a disabled or hidden loom ticket cannot settle or consume the visit")
			await _key(KEY_3)
			_check(wallet_commits.size() == 1, "the loom Leave emits one receipt")
			if wallet_commits.size() == 1:
				_check(wallet_commits[0].get("choice_id") == loom_choices[2]["id"]
					and wallet_commits[0].get("wallet") == loom_wallet,
					"the loom Leave settles the wallet unchanged")
			buttons[2].pressed.emit()
			_check(wallet_commits.size() == 1, "the loom Leave cannot be replayed")
		await _close_panel(panel)

	# A gold shortfall: the moth-stamp ticket states its exact need and stays
	# inert, while the pressed gain ticket still settles exactly once.
	var post: Dictionary = records.get("v3_midnight_moth_post", {})
	_check(not post.is_empty(), "the moth post reached the mounted gold-shortfall branch")
	if not post.is_empty():
		var post_wallet := {"gold": 18, "scraps": 0}
		var panel: LiveEventChoicePanel = await _open_panel(post, post_wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var post_choices: Array = EXPECTED["v3_midnight_moth_post"]["choices"]
		_check(buttons.size() == 3, "the moth post mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[1].disabled
				and buttons[1].text.contains(_needs_line(post_wallet, post_choices[1]))
				and not buttons[1].text.contains("After:"),
				"the moth-stamp ticket states its exact gold shortfall")
			buttons[1].pressed.emit()
			await _frames()
			_check(wallet_commits.is_empty() and panel.has_open_event(),
				"a disabled moth-stamp ticket cannot settle or consume the visit")
			await _mouse(buttons[0])
			_check(wallet_commits.size() == 1, "a pressed moth-post ticket emits one receipt")
			if wallet_commits.size() == 1:
				_check(wallet_commits[0].get("choice_id") == post_choices[0]["id"]
					and wallet_commits[0].get("wallet") == _wallet_after(post_wallet, post_choices[0]),
					"the moth-post receipt applies the authored gold gain once")
		await _close_panel(panel)

	# A zero wallet: the trim gain and the Leave stay available, the priced
	# ticket is disabled, and the caption names the exact award.
	var wash: Dictionary = records.get("v3_starhook_washhouse", {})
	_check(not wash.is_empty(), "the washhouse reached the mounted zero-wallet branch")
	if not wash.is_empty():
		var zero := {"gold": 0, "scraps": 0}
		var panel: LiveEventChoicePanel = await _open_panel(wash, zero)
		var buttons: Array[Button] = panel.get_choice_buttons()
		var wash_choices: Array = EXPECTED["v3_starhook_washhouse"]["choices"]
		_check(buttons.size() == 3, "the washhouse mounts three sewn tickets")
		if buttons.size() == 3:
			_check(buttons[0].text.contains(_delta_line(wash_choices[0]))
				and buttons[0].text.contains(_after_line(zero, wash_choices[0])),
				"the trim ticket shows its exact scrap award")
			_check(not buttons[0].disabled and not buttons[2].disabled,
				"the trim gain and the Leave are available at a zero wallet")
			_check(buttons[1].disabled
				and buttons[1].text.contains(_needs_line(zero, wash_choices[1])),
				"the copper-hook ticket states its exact scrap shortfall")
			await _key(KEY_1)
			_check(wallet_commits.size() == 1
				and wallet_commits[0].get("choice_id") == wash_choices[0]["id"]
				and wallet_commits[0].get("wallet") == _wallet_after(zero, wash_choices[0]),
				"the washhouse key claim applies the authored scrap award once")
		await _close_panel(panel)
