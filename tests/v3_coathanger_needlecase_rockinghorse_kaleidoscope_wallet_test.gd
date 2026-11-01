extends SceneTree
## Deterministic headless test for the four V3-4 gothic prop-trade Events
## appended to data/events/m04_events.json:
##   v3_inkblue_coathanger_choir, v3_bonecream_needlecase_hotel,
##   v3_moss_cuff_rocking_horse, v3_oxblood_stitchglass_kaleidoscope.
##
## The table below is an independent hard-coded copy of the authored story,
## captions and signed outcomes: it never reads the production catalog back as
## its oracle and it asserts per-ID membership rather than a catalog total, a
## fixed index or a full ordered ID list.
##
## Every branch is driven through a FRESH RunEventChoice built from the actual
## JSON record: funded preview and settlement against the independently
## calculated post-wallet, detached receipts, no mutation of the caller's wallet
## or the record, one-claim-only replay refusal, per-resource short-purse
## refusal followed by a legal free Leave on the same unclaimed instance, an
## invalid choice ID refusal and a seeded RNG state comparison proving the
## services consume no randomness.
##
## Selector coverage proves the shipped admission end to end: a fresh uninjected
## RunM04EventRotation validates, lists each new ID once, and with every other
## known ID excluded each new ID is the one legal selection for both
## select_event and select_actionable_event. No fixed catalog size, ID ordering,
## ticket index or lucky seed is assumed.

const EVENTS_PATH := "res://data/events/m04_events.json"

## Pre-existing anchors that must survive this additive task exactly once.
const ANCHOR_IDS := [
	"button_trail",
	"quiet_spool",
	"v3_rosebutton_oracle",
	"dusk_post_bobbin",
]

## The funded starting wallet every branch is tested from.
const FUNDED := {"gold": 50, "scraps": 5}

## Independent per-ID spec: exact title, full description, the three ordered
## choice contracts (id, caption, signed gold/scraps delta) and the expected
## funded post-wallet for each choice.
const EXPECTED := {
	"v3_inkblue_coathanger_choir": {
		"title": "The Ink-Blue Coat-Hanger Choir",
		"description": "Four plump, button-eyed coats dangle from an enormous bent silver hanger; each dangling hook hums through a velvet night-road archway.",
		"choices": [
			{"id": "rent_stitch_hooks", "text": "Pay 18 gold to borrow two singing stitch hooks (+2 scraps)", "gold": -18, "scraps": 2, "post": {"gold": 32, "scraps": 7}},
			{"id": "tune_bent_hangers", "text": "Repair the bent hooks with 3 scraps for 40 gold", "gold": 40, "scraps": -3, "post": {"gold": 90, "scraps": 2}},
			{"id": "leave", "text": "Let the hanging coats finish their chorus", "gold": 0, "scraps": 0, "post": {"gold": 50, "scraps": 5}},
		],
	},
	"v3_bonecream_needlecase_hotel": {
		"title": "The Bone-Cream Needlecase Hotel",
		"description": "A giant bone-cream needle case opens like a tiny hotel, its padded rooms lit by mustard lanterns and watched by a sleepy button-eyed bellhop.",
		"choices": [
			{"id": "book_thread_room", "text": "Pay 24 gold for three traveller-thread bundles (+3 scraps)", "gold": -24, "scraps": 3, "post": {"gold": 26, "scraps": 8}},
			{"id": "mend_room_hem", "text": "Mend the split pillow hems with 2 scraps for 27 gold", "gold": 27, "scraps": -2, "post": {"gold": 77, "scraps": 3}},
			{"id": "leave", "text": "Let the bellhop close the padded doors", "gold": 0, "scraps": 0, "post": {"gold": 50, "scraps": 5}},
		],
	},
	"v3_moss_cuff_rocking_horse": {
		"title": "The Moss-Cuff Rocking Horse",
		"description": "An enormous moss-green cloth cuff wraps a wooden rocking horse with floppy ragdoll ears; loose brass buttons tick like hooves against the road.",
		"choices": [
			{"id": "buy_saddle_thread", "text": "Pay 11 gold for a spare saddle stitch (+1 scrap)", "gold": -11, "scraps": 1, "post": {"gold": 39, "scraps": 6}},
			{"id": "sew_rocking_saddle", "text": "Use 1 scrap to stitch the horse's saddle (gain 17 gold)", "gold": 17, "scraps": -1, "post": {"gold": 67, "scraps": 4}},
			{"id": "leave", "text": "Leave the brass-button hooves rocking softly", "gold": 0, "scraps": 0, "post": {"gold": 50, "scraps": 5}},
		],
	},
	"v3_oxblood_stitchglass_kaleidoscope": {
		"title": "The Oxblood Stitchglass Kaleidoscope",
		"description": "A squat glass kaleidoscope turns inside an oxblood felt sleeve; button-eyed silhouettes dance among its pinwheel of velvet thread.",
		"choices": [
			{"id": "buy_prism_threads", "text": "Spend 31 gold for four glimmering thread bundles (+4 scraps)", "gold": -31, "scraps": 4, "post": {"gold": 19, "scraps": 9}},
			{"id": "reset_prism_spokes", "text": "Trade 3 scraps to fix the fractured wheel (gain 36 gold)", "gold": 36, "scraps": -3, "post": {"gold": 86, "scraps": 2}},
			{"id": "leave", "text": "Let the velvet pinwheel settle to stillness", "gold": 0, "scraps": 0, "post": {"gold": 50, "scraps": 5}},
		],
	},
}

## One independent seed per new ID for the forced single-eligible selection.
const SEEDS := {
	"v3_inkblue_coathanger_choir": 1110301,
	"v3_bonecream_needlecase_hotel": 1110302,
	"v3_moss_cuff_rocking_horse": 1110303,
	"v3_oxblood_stitchglass_kaleidoscope": 1110304,
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run_tests()
	if failures.is_empty():
		print("v3_coathanger_needlecase_rockinghorse_kaleidoscope_wallet_test: PASS (",
			checks, " checks)")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("v3_coathanger_needlecase_rockinghorse_kaleidoscope_wallet_test: FAIL (",
			checks, " checks)")
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + " opens through FileAccess")
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, path + " parses through JSON")
	if parse_result != OK:
		return {}
	var data: Variant = parser.data
	_check(data is Dictionary, path + " parses to a document object")
	if not data is Dictionary:
		return {}
	return data


func _preview_rows(preview: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return out
	for entry in entries:
		if entry is Dictionary:
			out[entry["choice_id"]] = entry
	return out


func _matches(listing: Array, event_id: String) -> Array:
	var found: Array = []
	for record in listing:
		if record is Dictionary and record.get("id") == event_id:
			found.append(record)
	return found


func _run_tests() -> void:
	var data: Dictionary = _read_document(EVENTS_PATH)
	if data.is_empty():
		return
	var events: Variant = data.get("events")
	_check(events is Array, "the M04 catalog carries an events array")
	if not events is Array:
		return

	# ---- Catalog content: unique IDs and independent per-ID spec -----------
	var parsed_events := {}
	var duplicate_ids := []
	for entry in events:
		_check(entry is Dictionary, "every M04 entry is a record object")
		if not entry is Dictionary:
			continue
		var raw_id: Variant = entry.get("id")
		_check(raw_id is String and not (raw_id as String).strip_edges().is_empty(),
			"every M04 record has a nonblank string ID")
		if not raw_id is String:
			continue
		var event_id: String = raw_id
		if parsed_events.has(event_id):
			duplicate_ids.append(event_id)
			continue
		parsed_events[event_id] = entry
	_check(duplicate_ids.is_empty(), "M04 event IDs are unique: " + str(duplicate_ids))
	for anchor in ANCHOR_IDS:
		_check(parsed_events.has(anchor), "pre-existing anchor record survives exactly once: " + anchor)

	var catalog_snapshot: Dictionary = data.duplicate(true)

	for expected_id in EXPECTED:
		_check(parsed_events.has(expected_id), "the new record exists in the catalog: " + expected_id)
		if not parsed_events.has(expected_id):
			continue
		var record: Dictionary = parsed_events[expected_id]
		var expected: Dictionary = EXPECTED[expected_id]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"the new record carries exactly id/title/description/choices: " + expected_id)
		_check(record.get("id") == expected_id, "authored ID matches: " + expected_id)
		_check(record.get("title") == expected["title"], "authored title matches: " + expected_id)
		_check(record.get("description") == expected["description"],
			"authored description matches: " + expected_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array, "choices is an array: " + expected_id)
		if not choices is Array:
			continue
		_check((choices as Array).size() == 3, "exactly three choices: " + expected_id)
		var by_choice_id := {}
		var order := []
		for choice in (choices as Array):
			_check(choice is Dictionary, "every choice is an object: " + expected_id)
			if not choice is Dictionary:
				continue
			var cid: Variant = choice.get("id")
			_check(cid is String and not (cid as String).strip_edges().is_empty(),
				"every choice has a nonblank string ID: " + expected_id)
			if not cid is String:
				continue
			_check(not by_choice_id.has(cid),
				"choice IDs are unique in the record: " + expected_id + " / " + str(cid))
			by_choice_id[cid] = choice
			order.append(cid)
		var expected_order: Array = []
		for choice_def in expected["choices"]:
			expected_order.append(choice_def["id"])
		_check(order == expected_order,
			"choice IDs exactly match the spec order: " + expected_id)
		for choice_def in expected["choices"]:
			var cid: String = choice_def["id"]
			_check(by_choice_id.has(cid),
				"expected choice present: " + expected_id + " / " + cid)
			if not by_choice_id.has(cid):
				continue
			var choice: Dictionary = by_choice_id[cid]
			_check(choice.size() == 3 and choice.has("id") and choice.has("text")
				and choice.has("outcome"),
				"choice carries exactly id/text/outcome: " + expected_id + " / " + cid)
			_check(choice.get("text") == choice_def["text"],
				"authored caption matches: " + expected_id + " / " + cid)
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "outcome is an object: " + expected_id + " / " + cid)
			if not outcome is Dictionary:
				continue
			var wallet_outcome: Dictionary = outcome
			_check(wallet_outcome.size() == 2 and wallet_outcome.has("gold")
				and wallet_outcome.has("scraps"),
				"outcome carries exactly gold/scraps: " + expected_id + " / " + cid)
			var raw_gold: Variant = wallet_outcome.get("gold")
			var raw_scraps: Variant = wallet_outcome.get("scraps")
			_check((typeof(raw_gold) == TYPE_INT or typeof(raw_gold) == TYPE_FLOAT)
				and (typeof(raw_scraps) == TYPE_INT or typeof(raw_scraps) == TYPE_FLOAT),
				"outcome values are JSON numbers, not coerced text: " + expected_id + " / " + cid)
			_check(raw_gold == choice_def["gold"] and raw_scraps == choice_def["scraps"],
				"authored signed outcome matches: " + expected_id + " / " + cid)

	# ---- Funded preview + settlement for all 12 branches -------------------
	for expected_id in EXPECTED:
		if not parsed_events.has(expected_id):
			continue
		var record: Dictionary = parsed_events[expected_id]
		var original_record: Dictionary = record.duplicate(true)
		var expected: Dictionary = EXPECTED[expected_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261103
		var rng_state_before: int = rng.state
		# A private RNG cannot detect accidental use of Godot's global RNG.
		# Compare a global seeded oracle as well as the independent instance.
		seed(20261103)
		var global_next: int = randi()
		seed(20261103)

		for choice_def in expected["choices"]:
			var cid: String = choice_def["id"]
			var base_wallet := FUNDED.duplicate(true)
			var wallet_snapshot: Dictionary = base_wallet.duplicate(true)
			var service := RunEventChoice.new(record)
			_check(service.is_valid(), "fresh service validates: " + expected_id + " / " + cid)
			var preview: Dictionary = service.preview_wallet_choices(base_wallet)
			_check(preview.get("ok", false), "preview succeeds: " + expected_id + " / " + cid)
			var rows := _preview_rows(preview)
			var preview_snapshot: Dictionary = preview.duplicate(true)
			_check(rows.size() == 3, "preview has one slot per choice: " + expected_id)
			var row: Dictionary = rows.get(cid, {})
			_check(row.get("choice_id") == cid, "preview row names the choice: " + expected_id + " / " + cid)
			_check(int(row.get("gold_delta", 0)) == int(choice_def["gold"]),
				"preview gold_delta matches: " + expected_id + " / " + cid)
			_check(int(row.get("scraps_delta", 0)) == int(choice_def["scraps"]),
				"preview scraps_delta matches: " + expected_id + " / " + cid)
			_check(row.get("affordable") == true,
				"funded preview is affordable: " + expected_id + " / " + cid)
			_check(row.get("wallet") == choice_def["post"],
				"funded preview post-wallet exact: " + expected_id + " / " + cid)
			# Preview never claims and never mutates the caller's wallet.
			_check(service.is_claimed() == false,
				"preview does not claim: " + expected_id + " / " + cid)
			_check(base_wallet == wallet_snapshot,
				"preview leaves the caller wallet unchanged: " + expected_id + " / " + cid)
			_check(record == original_record,
				"preview leaves the authored record unchanged: " + expected_id + " / " + cid)
			# Other preview rows are the unchanged base wallet on a denied path
			# and each computed independently: ensure the sibling rows are the
			# exact projected wallets of their own deltas.
			for other_def in expected["choices"]:
				if other_def["id"] == cid:
					continue
				var sibling: Dictionary = rows.get(other_def["id"], {})
				_check(sibling.get("wallet") == other_def["post"],
					"preview row is independent of siblings: " + expected_id + " / "
					+ other_def["id"])

			var caller_wallet := FUNDED.duplicate(true)
			var caller_snapshot: Dictionary = caller_wallet.duplicate(true)
			var settled: Dictionary = service.choose_with_wallet(cid, caller_wallet)
			_check(settled.get("ok", false), "funded settlement succeeds: " + expected_id + " / " + cid)
			_check(settled.get("event_id") == expected_id and settled.get("choice_id") == cid,
				"settlement names the event and choice: " + expected_id + " / " + cid)
			var receipt: Dictionary = settled.get("wallet", {})
			_check(receipt == choice_def["post"], "settled receipt exact: " + expected_id + " / " + cid)
			_check(caller_wallet == caller_snapshot,
				"settlement does not mutate the caller's wallet: " + expected_id + " / " + cid)
			_check(record == original_record,
				"settlement leaves the authored record unchanged: " + expected_id + " / " + cid)
			_check(preview == preview_snapshot,
				"settlement does not mutate preview entries: " + expected_id + " / " + cid)
			_check(service.is_claimed() == true, "settlement claims the instance: " + expected_id + " / " + cid)
			_check(service.is_valid() == false,
				"a claimed instance is no longer valid: " + expected_id + " / " + cid)
			# Detached receipt: mutating it never touches a fresh read.
			if receipt is Dictionary:
				(receipt as Dictionary)["gold"] = -999
			_check(caller_wallet == caller_snapshot and record == original_record
				and preview == preview_snapshot,
				"mutating the receipt changes no caller, record or preview: "
				+ expected_id + " / " + cid)
			var again: Dictionary = service.choose_with_wallet(cid, caller_snapshot)
			_check(again.get("ok") == false, "replay is refused: " + expected_id + " / " + cid)
			_check(again.get("wallet") == caller_snapshot,
				"replay returns the unchanged wallet: " + expected_id + " / " + cid)
			_check(service.is_claimed() == true,
				"replay does not change the claim: " + expected_id + " / " + cid)
		_check(rng.state == rng_state_before,
			"funded preview+settle flow consumes no private RNG: " + expected_id)
		_check(randi() == global_next,
			"funded preview+settle flow consumes no global RNG: " + expected_id)

	# ---- Denied trades: one short-purse per resource, then free Leave -----
	for expected_id in EXPECTED:
		if not parsed_events.has(expected_id):
			continue
		var record: Dictionary = parsed_events[expected_id]
		var original_record: Dictionary = record.duplicate(true)
		var expected: Dictionary = EXPECTED[expected_id]
		seed(20261105)
		var global_next: int = randi()
		seed(20261105)
		for choice_def in expected["choices"]:
			var cid: String = choice_def["id"]
			var gold_delta: int = int(choice_def["gold"])
			var scraps_delta: int = int(choice_def["scraps"])
			var poor_wallet: Dictionary = {}
			var funded_ok := true
			if gold_delta < 0:
				poor_wallet = {"gold": 0, "scraps": 5}
			elif scraps_delta < 0:
				poor_wallet = {"gold": 50, "scraps": 0}
			else:
				funded_ok = false
			if not funded_ok:
				continue
			var poor_snapshot: Dictionary = poor_wallet.duplicate(true)
			var service := RunEventChoice.new(record)
			var preview: Dictionary = service.preview_wallet_choices(poor_wallet)
			var rows := _preview_rows(preview)
			var row: Dictionary = rows.get(cid, {})
			_check(row.get("affordable") == false,
				"short-purse preview is unaffordable: " + expected_id + " / " + cid)
			_check(row.get("wallet") == poor_wallet,
				"unaffordable preview keeps the unchanged wallet: " + expected_id + " / " + cid)
			_check(poor_wallet == poor_snapshot,
				"unaffordable preview never mutates the caller wallet: " + expected_id + " / " + cid)
			var denied: Dictionary = service.choose_with_wallet(cid, poor_wallet)
			_check(denied.get("ok") == false,
				"short-purse settlement is refused: " + expected_id + " / " + cid)
			_check(denied.get("wallet") == poor_snapshot,
				"refused settlement returns the unchanged wallet: " + expected_id + " / " + cid)
			_check(poor_wallet == poor_snapshot,
				"refused settlement does not mutate the caller wallet: " + expected_id + " / " + cid)
			_check(service.is_claimed() == false,
				"a refusal does not latch: " + expected_id + " / " + cid)
			_check(record == original_record,
				"a refusal does not mutate the record: " + expected_id + " / " + cid)
			# Invalid choice ID also refuses without latching.
			var bogus: Dictionary = service.choose_with_wallet("not_a_real_choice", poor_wallet)
			_check(bogus.get("ok") == false,
				"an unknown choice ID is refused: " + expected_id + " / " + cid)
			_check(service.is_claimed() == false,
				"an unknown choice ID does not latch: " + expected_id + " / " + cid)
			# Same still-unclaimed instance can free Leave exactly once.
			var leave_result: Dictionary = service.choose_with_wallet("leave", poor_wallet)
			_check(leave_result.get("ok") == true,
				"free Leave succeeds after a refusal: " + expected_id + " / " + cid)
			_check(leave_result.get("wallet") == poor_snapshot,
				"free Leave leaves the wallet unchanged: " + expected_id + " / " + cid)
			_check(service.is_claimed() == true,
				"free Leave claims once: " + expected_id + " / " + cid)
			var replay: Dictionary = service.choose_with_wallet("leave", poor_snapshot)
			_check(replay.get("ok") == false,
				"free Leave replay is refused: " + expected_id + " / " + cid)
			_check(service.is_claimed() == true,
				"free Leave replay keeps the claim: " + expected_id + " / " + cid)
			_check(poor_wallet == poor_snapshot,
				"denial, invalid choice, Leave and replay never mutate caller: "
				+ expected_id + " / " + cid)
		_check(randi() == global_next,
			"denied choices, invalid ID and free Leave consume no global RNG: " + expected_id)

	# ---- Selector coverage: each new ID is a legal sole eligible selection --
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped M04 catalog validates")
	if not rotation.is_catalog_valid():
		return
	var all_ids: Array = rotation.get_generic_event_ids()
	var all_records: Array = rotation.get_generic_events()
	for expected_id in EXPECTED:
		_check(all_ids.count(expected_id) == 1,
			"the shipped rotation lists the new ID exactly once: " + expected_id)
		var matches := _matches(all_records, expected_id)
		_check(matches.size() == 1,
			"the shipped rotation has exactly one record for the new ID: " + expected_id)
		if matches.size() != 1 or not parsed_events.has(expected_id):
			continue
		_check(matches[0] == parsed_events[expected_id],
			"the shipped rotation serves the verbatim authored record: " + expected_id)
		var selected: Dictionary = _force_selection(rotation, all_ids, expected_id, SEEDS[expected_id])
		_check(selected.get("ok") == true, "select_event picks the sole eligible new ID: " + expected_id)
		_check(selected.get("event", {}).get("id") == expected_id,
			"select_event returns the new ID: " + expected_id)
		_check(selected.get("event") == parsed_events[expected_id],
			"select_event returns the verbatim record: " + expected_id)
		var actionable: Dictionary = _force_actionable(rotation, all_ids, expected_id, SEEDS[expected_id])
		_check(actionable.get("ok") == true,
			"select_actionable_event picks the sole eligible new ID: " + expected_id)
		_check(actionable.get("event", {}).get("id") == expected_id,
			"select_actionable_event returns the new ID: " + expected_id)
		_check(actionable.get("event") == parsed_events[expected_id],
			"select_actionable_event returns the verbatim record: " + expected_id)

	_check(data == catalog_snapshot, "the shipped M04 catalog is unchanged across every flow")


## Excludes every other known ID and picks the sole remaining eligible ID with
## an independent one-draw oracle.
func _force_selection(rotation: RunM04EventRotation, all_ids: Array, target_id: String,
		seed_value: int) -> Dictionary:
	var excluded: Array = all_ids.duplicate()
	excluded.erase(target_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var oracle := RandomNumberGenerator.new()
	oracle.seed = seed_value
	oracle.randi_range(0, 0)
	var result := rotation.select_event(rng, excluded)
	_check(rng.state == oracle.state, "forced select_event consumes exactly one draw: " + target_id)
	return result


func _force_actionable(rotation: RunM04EventRotation, all_ids: Array, target_id: String,
		seed_value: int) -> Dictionary:
	var excluded: Array = all_ids.duplicate()
	excluded.erase(target_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var oracle := RandomNumberGenerator.new()
	oracle.seed = seed_value
	oracle.randi_range(0, 0)
	var wallet := FUNDED.duplicate(true)
	var result := rotation.select_actionable_event(rng, excluded, wallet)
	_check(rng.state == oracle.state,
		"forced select_actionable_event consumes exactly one draw: " + target_id)
	return result
