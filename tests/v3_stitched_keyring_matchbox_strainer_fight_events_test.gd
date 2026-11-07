extends SceneTree
## Deterministic headless test for the three appended doll-scale Stitched
## Fight-or-toll roadside Events in res://data/events/v3_fight_choice_events.json
## (Milestone V3-4 Events, Stitched Design v4 S6-compatible data-only content).
##
## The shipped catalog is read through FileAccess/JSON and authenticated through
## the real RunV3FightEventGate and its RunEventChoice wallet service. Nothing
## here enters a live battle: a successful Fight choice only yields the detached
## pending {"node_type": "Fight"} request that a later stage routes.
##
## Deliberately absent: assertions on the catalog's total record count, on any
## new record's absolute rank, on the full ordered catalog ID list, or on a
## fixed seed-to-event mapping over the whole catalog. Only required-ID
## presence, relative placement after the last earlier record, and per-ID
## seeded oracle behavior with dynamically built exclusions are checked, so
## other lanes may append records concurrently.

const CATALOG_PATH := "res://data/events/v3_fight_choice_events.json"
const FIGHT_REQUEST := {"node_type": "Fight"}
const FUNDED_WALLET := {"gold": 60, "scraps": 6}
const SELECTION_SEED := 5831794

## Three earlier records that must remain byte-equivalent after this lane's
## append. Their expected values are hardcoded independently of the JSON.
const ANCHOR_EVENTS := {
	"v3_stitchline_roadblock": {
		"title": "The Stitchline Roadblock",
		"description": "A barricade of knotted bobbins and taut running-stitch cord stretches across the patchwork lane while hostile figures stir behind the cloth.",
		"fight_choice_id": "break_barricade",
		"choices": [
			{"id": "break_barricade", "text": "Break through the stitched barricade (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "pay_road_toll", "text": "Pay the road toll (spend 14 gold)", "outcome": {"gold": -14, "scraps": 0}},
			{"id": "leave", "text": "Turn back down the quiet seam (Leave)", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	"v3_oxblood_musicbox_checkpoint": {
		"title": "The Oxblood Music-Box Checkpoint",
		"description": "An enormous oxblood music box straddles the floorboard lane; three plump button-eyed sentries turn its brass winding key while a toothed velvet tune gate blocks the dolls.",
		"fight_choice_id": "silence_clockwork_sentries",
		"choices": [
			{"id": "silence_clockwork_sentries", "text": "Silence the winding sentries and force the music-box gate (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "buy_copper_winding_pass", "text": "Pay 17 gold for a copper winding pass", "outcome": {"gold": -17, "scraps": 0}},
			{"id": "leave", "text": "Let the music box finish its crooked lullaby", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	"v3_mossfelt_scissorbridge": {
		"title": "The Moss-Felt Scissorbridge",
		"description": "Two enormous blunted dressmaking shears form a wavering bridge above a black button pond; squat moss-felt keeper dolls guard its brass pivot beneath a tiny candle lantern.",
		"fight_choice_id": "break_scissor_lock",
		"choices": [
			{"id": "break_scissor_lock", "text": "Break the scissor lock and face the keeper dolls (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "buy_dull_blade_permit", "text": "Pay 23 gold for a dull-blade crossing permit", "outcome": {"gold": -23, "scraps": 0}},
			{"id": "leave", "text": "Take the long bank around the quiet button pond", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
}

## The three records of this lane, hardcoded independently of the JSON: exact
## prose, choice IDs/texts and signed outcome deltas, plus the exact-cost and
## one-unit-short toll wallets for the threshold checks.
const EXPECTED_EVENTS := {
	"v3_bone_keyring_turnstile": {
		"title": "The Bone-Key Turnstile",
		"description": "A house-sized ring of tarnished keys turns in the seam of the corridor wall; button-eyed latchkeepers haul it by red cord while each key casts a second shadow.",
		"fight_choice_id": "force_turnstile_keys",
		"paid_choice_id": "bind_keyring_with_thread",
		"paid_outcome": {"gold": 0, "scraps": -2},
		"exact_wallet": {"gold": 0, "scraps": 2},
		"short_wallet": {"gold": 0, "scraps": 1},
		"choices": [
			{"id": "force_turnstile_keys", "text": "Break the spinning latch and face the keykeepers (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "bind_keyring_with_thread", "text": "Bind the swinging keys with 2 scraps for safe passage", "outcome": {"gold": 0, "scraps": -2}},
			{"id": "leave", "text": "Follow the narrow wall seam away from the keys", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	"v3_ember_matchbox_roadblock": {
		"title": "The Ember Matchbox Roadblock",
		"description": "A fallen matchbox blocks the floorboard road, its charred sticks propped upright as watchtowers; soot-smudged ragdoll wardens hold a red-thread tripline across the glowing drawer.",
		"fight_choice_id": "cut_matchstick_tripline",
		"paid_choice_id": "buy_ember_safe_pass",
		"paid_outcome": {"gold": -18, "scraps": 0},
		"exact_wallet": {"gold": 18, "scraps": 0},
		"short_wallet": {"gold": 17, "scraps": 0},
		"choices": [
			{"id": "cut_matchstick_tripline", "text": "Cut the tripline and confront the matchbox wardens (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "buy_ember_safe_pass", "text": "Pay 18 gold for an ember-safe crossing token", "outcome": {"gold": -18, "scraps": 0}},
			{"id": "leave", "text": "Take the long unlit route beside the skirting board", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	"v3_moonlit_tea_strainer_crossing": {
		"title": "The Moonlit Tea-Strainer Crossing",
		"description": "A silver tea strainer swings over a gap between quilted floorboards, carrying a tiny bridge of black lace; three aproned doll porters keep its chain taut by candlelight.",
		"fight_choice_id": "seize_strainer_bridge",
		"paid_choice_id": "offer_strainer_stitches",
		"paid_outcome": {"gold": 0, "scraps": -3},
		"exact_wallet": {"gold": 0, "scraps": 3},
		"short_wallet": {"gold": 0, "scraps": 2},
		"choices": [
			{"id": "seize_strainer_bridge", "text": "Seize the strainer bridge and face the porters (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "offer_strainer_stitches", "text": "Offer 3 scraps to lash the strainer safely in place", "outcome": {"gold": 0, "scraps": -3}},
			{"id": "leave", "text": "Back away from the swinging silver mesh", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
}

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	seed(31415)
	var expected_global_rng: int = randi()
	seed(31415)

	_test_ac1_shipped_records()
	_test_ac2_visit_settlement_branches()
	_test_ac3_toll_thresholds_and_one_claim()
	_test_ac4_seeded_selection()

	_check(randi() == expected_global_rng, "global RNG untouched across the whole suite")
	for failure: String in failures:
		printerr(failure)
	print(
		"v3_stitched_keyring_matchbox_strainer_fight_events_test: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)"
	)
	quit(0 if failures.is_empty() else 1)


func _test_ac1_shipped_records() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check(file != null, "catalog opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(not text.strip_edges().is_empty(), "catalog is non-empty")

	var parser := JSON.new()
	var parse_error := parser.parse(text)
	_check(parse_error == OK and parser.data is Dictionary, "catalog parses as a JSON object")
	if parse_error != OK or not (parser.data is Dictionary):
		return
	var document: Dictionary = parser.data
	_check(document.size() == 1 and document.has("events"), "catalog root holds only the events key")
	var events_raw: Variant = document.get("events")
	_check(events_raw is Array and not (events_raw as Array).is_empty(), "catalog has a non-empty events array")
	if not (events_raw is Array) or (events_raw as Array).is_empty():
		return
	var events: Array = events_raw

	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "shipped catalog validates through RunV3FightEventGate")
	var catalog_snapshot: Array = gate.get_catalog_events().duplicate(true)

	# Event IDs and authored (non-Leave) choice IDs stay globally unique.
	var seen_event_ids: Dictionary = {}
	var seen_choice_ids: Dictionary = {}
	for entry_raw: Variant in events:
		_check(entry_raw is Dictionary, "catalog entry is a Dictionary")
		if not (entry_raw is Dictionary):
			continue
		var entry: Dictionary = entry_raw
		var event_id: String = String(entry.get("id", ""))
		_check(not event_id.is_empty(), "catalog entry has a non-blank id")
		_check(not seen_event_ids.has(event_id), "event IDs are globally unique: " + event_id)
		seen_event_ids[event_id] = true
		for choice_raw: Variant in entry.get("choices", []):
			if not (choice_raw is Dictionary):
				continue
			var choice_id: String = String((choice_raw as Dictionary).get("id", ""))
			if choice_id == "leave":
				continue
			_check(not seen_choice_ids.has(choice_id), "non-Leave choice IDs are globally unique: " + choice_id)
			seen_choice_ids[choice_id] = true

	# The three named earlier anchors keep their exact authored records.
	for anchor_id: String in ANCHOR_EVENTS.keys():
		var anchor_matches: Array = _matching_events(events, anchor_id)
		_check(anchor_matches.size() == 1, "earlier anchor present exactly once: " + anchor_id)
		if anchor_matches.size() != 1:
			continue
		var anchor_record: Dictionary = anchor_matches[0]
		_check(anchor_record.size() == 5, "earlier anchor keeps five top-level keys: " + anchor_id)
		var expected_anchor: Dictionary = _normalized_from_spec(anchor_id, ANCHOR_EVENTS[anchor_id])
		_check(_normalized_record(anchor_record) == expected_anchor, "earlier anchor unchanged: " + anchor_id)
		_check(gate.get_event_record(anchor_id) == anchor_record, "gate authenticates the unchanged anchor: " + anchor_id)

	var mossfelt_index: int = _event_index(events, "v3_mossfelt_scissorbridge")
	_check(mossfelt_index >= 0, "the append point anchor is present")

	var new_choice_ids: Dictionary = {}
	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var matches: Array = _matching_events(events, event_id)
		_check(matches.size() == 1, "exactly one authored record for " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]

		# Five correct top-level keys, no extra metadata.
		_check(
			record.size() == 5
			and record.has("id")
			and record.has("title")
			and record.has("description")
			and record.has("fight_choice_id")
			and record.has("choices"),
			"record has exactly the five top-level keys: " + event_id
		)
		_check(record.get("id") == event_id, "exact id: " + event_id)
		_check(record.get("title") == spec["title"], "exact title: " + event_id)
		_check(record.get("description") == spec["description"], "exact description: " + event_id)
		_check(record.get("fight_choice_id") == spec["fight_choice_id"], "exact fight_choice_id: " + event_id)
		_check(
			String(record.get("title", "")).strip_edges() != ""
			and String(record.get("description", "")).strip_edges() != "",
			"non-blank title and description: " + event_id
		)

		var choices_raw: Variant = record.get("choices")
		_check(choices_raw is Array and (choices_raw as Array).size() == 3, "exactly three choices: " + event_id)
		if not (choices_raw is Array) or (choices_raw as Array).size() != 3:
			continue
		var choices: Array = choices_raw
		var expected_choices: Array = spec["choices"]

		var seen_local_choice_ids: Dictionary = {}
		var negative_amounts: int = 0
		var negative_choice_id: String = ""
		var leave_choice: Dictionary = {}
		var fight_choice: Dictionary = {}
		for index: int in range(choices.size()):
			var choice_raw: Variant = choices[index]
			_check(choice_raw is Dictionary, "choice is a Dictionary: " + event_id + " idx " + str(index))
			if not (choice_raw is Dictionary):
				continue
			var choice: Dictionary = choice_raw
			var expected_choice: Dictionary = expected_choices[index]
			_check(
				choice.size() == 3 and choice.has("id") and choice.has("text") and choice.has("outcome"),
				"choice has exactly id/text/outcome: " + event_id + " idx " + str(index)
			)
			var choice_id: String = String(choice.get("id", ""))
			_check(choice_id == String(expected_choice["id"]), "exact choice id: " + event_id + " idx " + str(index))
			_check(choice.get("text") == expected_choice["text"], "exact choice text: " + event_id + " idx " + str(index))
			_check(not seen_local_choice_ids.has(choice_id), "choice IDs are unique inside the record: " + choice_id)
			seen_local_choice_ids[choice_id] = true
			var outcome_raw: Variant = choice.get("outcome")
			_check(
				outcome_raw is Dictionary
				and (outcome_raw as Dictionary).size() == 2
				and (outcome_raw as Dictionary).has("gold")
				and (outcome_raw as Dictionary).has("scraps"),
				"outcome is exactly two integral keys: " + event_id + " idx " + str(index)
			)
			if not (outcome_raw is Dictionary):
				continue
			var outcome: Dictionary = outcome_raw
			_check(_is_integral_json_number(outcome.get("gold")), "integral gold outcome: " + event_id + " idx " + str(index))
			_check(_is_integral_json_number(outcome.get("scraps")), "integral scraps outcome: " + event_id + " idx " + str(index))
			var gold_delta: int = int(outcome.get("gold", 0))
			var scraps_delta: int = int(outcome.get("scraps", 0))
			_check(gold_delta == int(expected_choice["outcome"]["gold"]), "exact gold delta: " + event_id + " idx " + str(index))
			_check(scraps_delta == int(expected_choice["outcome"]["scraps"]), "exact scraps delta: " + event_id + " idx " + str(index))
			if gold_delta < 0:
				negative_amounts += 1
				negative_choice_id = choice_id
			if scraps_delta < 0:
				negative_amounts += 1
				negative_choice_id = choice_id
			if choice_id == "leave":
				leave_choice = choice
			if choice_id == String(spec["fight_choice_id"]):
				fight_choice = choice

		# One no-cost Fight as the first choice, one single-amount toll, one free Leave.
		_check(choices[0] is Dictionary and String((choices[0] as Dictionary).get("id", "")) == String(spec["fight_choice_id"]), "fight_choice_id is the first choice: " + event_id)
		_check(not fight_choice.is_empty(), "fight choice is offered: " + event_id)
		if not fight_choice.is_empty():
			_check(_is_free_outcome(fight_choice.get("outcome")), "fight outcome is free: " + event_id)
		_check(negative_amounts == 1, "exactly one strictly negative toll amount: " + event_id)
		_check(negative_choice_id == String(spec["paid_choice_id"]), "the toll is the paid choice: " + event_id)
		_check(not leave_choice.is_empty(), "leave choice is offered: " + event_id)
		if not leave_choice.is_empty():
			_check(_is_free_outcome(leave_choice.get("outcome")), "leave outcome is free: " + event_id)
		_check(String(leave_choice.get("id", "")) == "leave", "third choice id is exactly leave: " + event_id)

		# Every new authored choice ID is distinct from the others and from earlier records.
		for choice_id: String in seen_local_choice_ids.keys():
			if choice_id == "leave":
				continue
			_check(not new_choice_ids.has(choice_id), "new choice ID is distinct: " + choice_id)
			new_choice_ids[choice_id] = event_id

		# The new records sit after the last earlier record, never at a frozen rank.
		var new_index: int = _event_index(events, event_id)
		_check(new_index > mossfelt_index, "new record is appended after v3_mossfelt_scissorbridge: " + event_id)

		# The real gate authenticates the shipped record byte-for-byte.
		_check(gate.get_event_record(event_id) == record, "gate authenticates the shipped record: " + event_id)

		# RunEventChoice (the gate's wallet service) accepts the shipped record.
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(), "RunEventChoice accepts the shipped record: " + event_id)

	_check(gate.get_catalog_events() == catalog_snapshot, "authenticating records mutates nothing")
	_check(not gate.is_valid() and not gate.is_claimed(), "unbound catalog gate claims no visit")


func _test_ac2_visit_settlement_branches() -> void:
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "gate validates the shipped catalog for settlement")
	var catalog_snapshot: Array = gate.get_catalog_events().duplicate(true)

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var funded: Dictionary = FUNDED_WALLET.duplicate(true)
		var funded_before: Dictionary = funded.duplicate(true)
		var source_record: Dictionary = gate.get_event_record(event_id)
		var source_before: Dictionary = source_record.duplicate(true)
		var choice_ids: Array[String] = _spec_choice_ids(spec)

		# Preview: three authored branches with their pending Fight request.
		var preview_visit := gate.open_visit(event_id)
		_check(preview_visit != null, "fresh visit opens: " + event_id)
		if preview_visit == null:
			continue
		_check(preview_visit.is_valid() and not preview_visit.is_claimed(), "fresh visit is valid and unclaimed: " + event_id)
		var preview: Dictionary = preview_visit.preview_choices(funded)
		_check(preview.get("ok") == true, "preview succeeds: " + event_id)
		_check(preview.get("event_id") == event_id, "preview event_id: " + event_id)
		_check(preview.get("fight_choice_id") == spec["fight_choice_id"], "preview fight_choice_id: " + event_id)
		var rows: Array = preview.get("choices", [])
		_check(rows.size() == 3, "preview has three branches: " + event_id)
		var rows_by_id: Dictionary = {}
		var row_order: Array[String] = []
		for row_raw: Variant in rows:
			_check(row_raw is Dictionary, "preview row is a Dictionary: " + event_id)
			if not (row_raw is Dictionary):
				continue
			var row: Dictionary = row_raw
			_check(
				row.size() == 6
				and row.has("choice_id")
				and row.has("gold_delta")
				and row.has("scraps_delta")
				and row.has("affordable")
				and row.has("wallet")
				and row.has("fight_request"),
				"preview row has six keys: " + event_id
			)
			rows_by_id[row.get("choice_id")] = row
			row_order.append(String(row.get("choice_id", "")))
		_check(row_order == choice_ids, "preview keeps the authored choice order: " + event_id)

		for choice_raw: Variant in (spec["choices"] as Array):
			var choice: Dictionary = choice_raw
			var choice_id: String = String(choice["id"])
			_check(rows_by_id.has(choice_id), "preview contains authored choice: " + event_id + "/" + choice_id)
			if not rows_by_id.has(choice_id):
				continue
			var row: Dictionary = rows_by_id[choice_id]
			var gold_delta: int = int(choice["outcome"]["gold"])
			var scraps_delta: int = int(choice["outcome"]["scraps"])
			_check(row["gold_delta"] == gold_delta and row["scraps_delta"] == scraps_delta, "authored preview deltas: " + choice_id)
			_check(row["affordable"] == true, "funded wallet affords: " + choice_id)
			_check(
				row["wallet"] == {
					"gold": int(FUNDED_WALLET["gold"]) + gold_delta,
					"scraps": int(FUNDED_WALLET["scraps"]) + scraps_delta,
				},
				"preview projects the authored wallet: " + choice_id
			)
			var expected_request: Dictionary = FIGHT_REQUEST if choice_id == String(spec["fight_choice_id"]) else {}
			_check(row["fight_request"] == expected_request, "preview request distinguishes Fight from toll/Leave: " + choice_id)

		# Fight: free, claims the visit, returns only the pending Fight request.
		var fight_visit := gate.open_visit(event_id)
		_check(fight_visit != null and fight_visit.is_valid(), "fight visit opens: " + event_id)
		if fight_visit == null:
			continue
		var fight_receipt: Dictionary = fight_visit.choose_with_wallet(spec["fight_choice_id"], funded)
		_check(_receipt_shape_ok(fight_receipt), "fight receipt shape: " + event_id)
		_check(fight_receipt.get("ok") == true, "fight choice succeeds: " + event_id)
		_check(fight_receipt.get("event_id") == event_id, "fight receipt event_id: " + event_id)
		_check(fight_receipt.get("choice_id") == spec["fight_choice_id"], "fight receipt choice_id: " + event_id)
		_check(fight_receipt.get("wallet") == FUNDED_WALLET, "fight preserves the wallet: " + event_id)
		_check(fight_receipt.get("fight_request") == FIGHT_REQUEST, "fight returns only the pending Fight request: " + event_id)
		_check(_single_fight_request(fight_receipt.get("fight_request")), "fight request is exactly the one-key Fight node: " + event_id)
		_check(fight_visit.is_claimed() and not fight_visit.is_valid(), "fight claims the visit: " + event_id)

		# Paid toll: exact debit, no request.
		var toll_visit := gate.open_visit(event_id)
		_check(toll_visit != null and toll_visit.is_valid(), "toll visit opens: " + event_id)
		if toll_visit == null:
			continue
		var toll_receipt: Dictionary = toll_visit.choose_with_wallet(spec["paid_choice_id"], funded)
		_check(_receipt_shape_ok(toll_receipt), "toll receipt shape: " + event_id)
		_check(toll_receipt.get("ok") == true, "toll choice succeeds: " + event_id)
		_check(toll_receipt.get("event_id") == event_id, "toll receipt event_id: " + event_id)
		_check(toll_receipt.get("choice_id") == spec["paid_choice_id"], "toll receipt choice_id: " + event_id)
		_check(
			_wallet_exact_int(
				toll_receipt.get("wallet"),
				int(FUNDED_WALLET["gold"]) + int(spec["paid_outcome"]["gold"]),
				int(FUNDED_WALLET["scraps"]) + int(spec["paid_outcome"]["scraps"])
			),
			"toll debits the exact authored amount: " + event_id
		)
		_check(toll_receipt.get("fight_request") == {}, "toll returns no Fight request: " + event_id)
		_check(toll_visit.is_claimed(), "toll claims the visit: " + event_id)

		# Leave: no cost, no request.
		var leave_visit := gate.open_visit(event_id)
		_check(leave_visit != null and leave_visit.is_valid(), "leave visit opens: " + event_id)
		if leave_visit == null:
			continue
		var leave_receipt: Dictionary = leave_visit.choose_with_wallet("leave", funded)
		_check(_receipt_shape_ok(leave_receipt), "leave receipt shape: " + event_id)
		_check(leave_receipt.get("ok") == true, "leave choice succeeds: " + event_id)
		_check(leave_receipt.get("event_id") == event_id, "leave receipt event_id: " + event_id)
		_check(leave_receipt.get("choice_id") == "leave", "leave receipt choice_id: " + event_id)
		_check(leave_receipt.get("wallet") == FUNDED_WALLET, "leave preserves the wallet: " + event_id)
		_check(leave_receipt.get("fight_request") == {}, "leave returns no Fight request: " + event_id)
		_check(leave_visit.is_claimed(), "leave claims the visit: " + event_id)

		# Caller wallet, source record and catalog stay untouched.
		_check(funded == funded_before, "caller wallet unmutated: " + event_id)
		_check(gate.get_event_record(event_id) == source_before and source_record == source_before, "source record unmutated: " + event_id)
		source_record["title"] = "Mutated Title"
		(source_record["choices"] as Array).clear()
		_check(gate.get_event_record(event_id) == source_before, "detached source record cannot reach the catalog: " + event_id)

	_check(gate.get_catalog_events() == catalog_snapshot, "settlement preserves every catalog record")
	_check(not gate.is_claimed(), "settlement on visits leaves the catalog gate unclaimed")


func _test_ac3_toll_thresholds_and_one_claim() -> void:
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "gate validates the shipped catalog for threshold checks")
	var catalog_snapshot: Array = gate.get_catalog_events().duplicate(true)

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var paid_choice_id: String = spec["paid_choice_id"]
		var fight_choice_id: String = spec["fight_choice_id"]

		# At exactly the stated cost, the toll succeeds once and settles precisely.
		var exact_visit := gate.open_visit(event_id)
		_check(exact_visit != null and exact_visit.is_valid(), "exact-cost visit opens: " + event_id)
		if exact_visit == null:
			continue
		var exact_wallet: Dictionary = (spec["exact_wallet"] as Dictionary).duplicate(true)
		var exact_receipt: Dictionary = exact_visit.choose_with_wallet(paid_choice_id, exact_wallet)
		_check(_receipt_shape_ok(exact_receipt), "exact-cost receipt shape: " + event_id)
		_check(exact_receipt.get("ok") == true, "exact-cost toll succeeds: " + event_id)
		_check(
			_wallet_exact_int(
				exact_receipt.get("wallet"),
				int(spec["exact_wallet"]["gold"]) + int(spec["paid_outcome"]["gold"]),
				int(spec["exact_wallet"]["scraps"]) + int(spec["paid_outcome"]["scraps"])
			),
			"exact-cost toll settles the exact debit: " + event_id
		)
		_check(exact_receipt.get("fight_request") == {}, "exact-cost toll returns no Fight request: " + event_id)
		_check(exact_visit.is_claimed() and not exact_visit.is_valid(), "exact-cost toll claims the visit: " + event_id)

		# After a successful choice, repeated and alternate claims are rejected.
		var settled_wallet: Dictionary = exact_receipt.get("wallet")
		var repeat_claim: Dictionary = exact_visit.choose_with_wallet(paid_choice_id, settled_wallet)
		_check(repeat_claim.get("ok") == false, "repeated claim is refused: " + event_id)
		_check(repeat_claim.get("wallet") == settled_wallet, "repeated claim debits nothing: " + event_id)
		var alternate_claim: Dictionary = exact_visit.choose_with_wallet(fight_choice_id, settled_wallet)
		_check(alternate_claim.get("ok") == false, "alternate claim on a claimed visit is refused: " + event_id)
		_check(alternate_claim.get("wallet") == settled_wallet, "alternate claim debits nothing: " + event_id)
		_check(alternate_claim.get("fight_request") == {}, "alternate claim yields no Fight request: " + event_id)
		_check(exact_visit.is_claimed(), "claimed visit stays claimed: " + event_id)

		# One unit short: the toll is refused with no wallet or claim change.
		var short_visit := gate.open_visit(event_id)
		_check(short_visit != null and short_visit.is_valid(), "short-resource visit opens: " + event_id)
		if short_visit == null:
			continue
		var short_wallet: Dictionary = (spec["short_wallet"] as Dictionary).duplicate(true)
		var short_before := short_wallet.duplicate(true)
		var preview: Dictionary = short_visit.preview_choices(short_wallet)
		_check(preview.get("ok") == true, "short-resource preview succeeds: " + event_id)
		var toll_row: Dictionary = {}
		for row_raw: Variant in preview.get("choices", []):
			if row_raw is Dictionary and String((row_raw as Dictionary).get("choice_id", "")) == paid_choice_id:
				toll_row = row_raw
		_check(not toll_row.is_empty(), "short-resource preview lists the toll: " + event_id)
		if not toll_row.is_empty():
			_check(toll_row.get("affordable") == false, "short wallet makes the toll unaffordable: " + event_id)
			_check(toll_row.get("gold_delta") == spec["paid_outcome"]["gold"] and toll_row.get("scraps_delta") == spec["paid_outcome"]["scraps"], "unaffordable toll keeps its authored deltas: " + event_id)
			_check(toll_row.get("wallet") == short_wallet, "unaffordable toll keeps the unchanged wallet: " + event_id)
			_check(toll_row.get("fight_request") == {}, "toll never yields a Fight request: " + event_id)

		var refused: Dictionary = short_visit.choose_with_wallet(paid_choice_id, short_wallet)
		_check(_receipt_shape_ok(refused), "refusal receipt shape: " + event_id)
		_check(refused.get("ok") == false, "short wallet toll is refused: " + event_id)
		_check(refused.get("wallet") == short_wallet, "refusal returns the unchanged wallet: " + event_id)
		_check(refused.get("fight_request") == {}, "refusal returns no Fight request: " + event_id)
		_check(short_visit.is_valid() and not short_visit.is_claimed(), "refused toll leaves the visit unclaimed: " + event_id)
		_check(short_wallet == short_before, "refused toll mutates no caller wallet: " + event_id)

		# The same visit may still settle a free action afterwards.
		var leave_receipt: Dictionary = short_visit.choose_with_wallet("leave", short_wallet)
		_check(leave_receipt.get("ok") == true, "failed toll visit can still Leave: " + event_id)
		_check(leave_receipt.get("wallet") == short_wallet and leave_receipt.get("fight_request") == {}, "Leave after refusal is free: " + event_id)
		_check(short_visit.is_claimed(), "Leave after refusal claims the visit once: " + event_id)

		# A separate fresh visit may still settle Fight even one unit short.
		var fight_visit := gate.open_visit(event_id)
		_check(fight_visit != null and fight_visit.is_valid(), "separate fight visit opens: " + event_id)
		if fight_visit == null:
			continue
		var fight_receipt: Dictionary = fight_visit.choose_with_wallet(fight_choice_id, short_wallet)
		_check(fight_receipt.get("ok") == true, "fresh instance can still Fight after a failed toll: " + event_id)
		_check(fight_receipt.get("wallet") == short_wallet, "Fight after a failed toll is free: " + event_id)
		_check(fight_receipt.get("fight_request") == FIGHT_REQUEST, "Fight after a failed toll yields the pending request: " + event_id)

		# Unknown choice fails on a fresh visit and claims nothing.
		var unknown_visit := gate.open_visit(event_id)
		_check(unknown_visit != null, "unknown-choice visit opens: " + event_id)
		var unknown_receipt: Dictionary = unknown_visit.choose_with_wallet("bogus_choice_id", FUNDED_WALLET)
		_check(unknown_receipt.get("ok") == false, "unknown choice is refused: " + event_id)
		_check(unknown_receipt.get("wallet") == FUNDED_WALLET and unknown_receipt.get("fight_request") == {}, "unknown choice returns the unchanged wallet and no request: " + event_id)
		_check(unknown_visit.is_valid() and not unknown_visit.is_claimed(), "unknown choice leaves the visit unclaimed: " + event_id)

	_check(gate.get_catalog_events() == catalog_snapshot, "threshold checks preserve the catalog")
	_check(not gate.is_claimed(), "threshold checks leave the catalog gate unclaimed")


func _test_ac4_seeded_selection() -> void:
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "gate validates the shipped catalog for seeded selection")
	var records: Array[Dictionary] = gate.get_catalog_events()
	_check(not records.is_empty(), "selection catalog is non-empty")
	var all_ids: Array[String] = []
	for record: Dictionary in records:
		all_ids.append(String(record.get("id", "")))
	var catalog_snapshot: Array = records.duplicate(true)

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		_check(all_ids.has(event_id), "authored event is in the live catalog: " + event_id)
		# Build exclusions from every dynamically observed ID except this event.
		var excluded: Array[String] = all_ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id), "exclusions omit the target: " + event_id)
		var excluded_before: Array[String] = excluded.duplicate()
		var authentic_before: Dictionary = gate.get_event_record(event_id)

		# Oracle: one sorted-ID draw over the single eligible record.
		var oracle := RandomNumberGenerator.new()
		oracle.seed = SELECTION_SEED
		oracle.randi_range(0, 0)

		# select_event discovers the sole unexcluded ID with one seeded draw.
		var rng := RandomNumberGenerator.new()
		rng.seed = SELECTION_SEED
		var selected: Dictionary = gate.select_event(rng, excluded)
		_check(selected.get("ok") == true, "seeded select_event succeeds: " + event_id)
		_check(selected.get("event", {}).get("id") == event_id, "select_event returns the sole unexcluded ID: " + event_id)
		_check(selected.get("event") == authentic_before, "select_event returns the authenticated record: " + event_id)
		_check(rng.state == oracle.state, "select_event consumes exactly one draw: " + event_id)
		_check(excluded == excluded_before, "select_event preserves the caller exclusions: " + event_id)

		# select_affordable_toll_event discovers it when the funded wallet covers its toll.
		var toll_rng := RandomNumberGenerator.new()
		toll_rng.seed = SELECTION_SEED
		var toll_selected: Dictionary = gate.select_affordable_toll_event(toll_rng, excluded, FUNDED_WALLET)
		_check(toll_selected.get("ok") == true, "seeded select_affordable_toll_event succeeds: " + event_id)
		_check(toll_selected.get("event", {}).get("id") == event_id, "affordable selector returns the sole unexcluded ID: " + event_id)
		_check(toll_selected.get("event") == authentic_before, "affordable selector returns the authenticated record: " + event_id)
		_check(toll_rng.state == oracle.state, "affordable selector consumes exactly one draw: " + event_id)

		# An underfunded wallet rejects the selector without any RNG draw.
		var short_rng := RandomNumberGenerator.new()
		short_rng.seed = SELECTION_SEED
		var short_before: int = short_rng.state
		var short_wallet: Dictionary = (spec["short_wallet"] as Dictionary).duplicate(true)
		var short_result: Dictionary = gate.select_affordable_toll_event(short_rng, excluded, short_wallet)
		_check(short_result.get("ok") == false and short_result.get("event") == {}, "underfunded selector rejects: " + event_id)
		_check(short_rng.state == short_before, "underfunded selector consumes no RNG draw: " + event_id)
		_check(short_wallet == spec["short_wallet"], "underfunded selector mutates no wallet: " + event_id)

		# With every ID excluded, select_event also rejects without a draw.
		var exhausted_rng := RandomNumberGenerator.new()
		exhausted_rng.seed = SELECTION_SEED
		var exhausted_before: int = exhausted_rng.state
		var exhausted: Dictionary = gate.select_event(exhausted_rng, all_ids)
		_check(exhausted.get("ok") == false and exhausted.get("event") == {}, "fully excluded select_event rejects: " + event_id)
		_check(exhausted_rng.state == exhausted_before, "fully excluded select_event consumes no draw: " + event_id)

		# Same seed and exclusions replay the identical selection with one draw.
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = SELECTION_SEED
		var replay: Dictionary = gate.select_event(replay_rng, excluded)
		_check(replay == selected, "equal seeds replay the identical selection: " + event_id)
		_check(replay_rng.state == oracle.state, "replayed selection consumes exactly one draw: " + event_id)

		# Mutating the returned record cannot reach the catalog.
		if selected.get("event") is Dictionary:
			(selected["event"]["choices"] as Array).clear()
			(selected["event"])["title"] = "Mutated Title"
		_check(gate.get_event_record(event_id) == authentic_before, "selection mutation is detached from the catalog: " + event_id)

	_check(gate.get_catalog_events() == catalog_snapshot, "seeded selection preserves every catalog record")
	_check(not gate.is_claimed(), "seeded selection claims no visit")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _single_fight_request(request: Variant) -> bool:
	if typeof(request) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = request
	return dict.size() == 1 and dict.has("node_type") and dict.get("node_type") == "Fight"


func _receipt_shape_ok(receipt: Variant) -> bool:
	if typeof(receipt) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = receipt
	return (
		dict.size() == 5
		and typeof(dict.get("ok")) == TYPE_BOOL
		and typeof(dict.get("event_id")) == TYPE_STRING
		and typeof(dict.get("choice_id")) == TYPE_STRING
		and typeof(dict.get("wallet")) == TYPE_DICTIONARY
		and typeof(dict.get("fight_request")) == TYPE_DICTIONARY
	)


func _wallet_exact_int(wallet: Variant, expected_gold: int, expected_scraps: int) -> bool:
	if typeof(wallet) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = wallet
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return false
	return (
		typeof(dict.get("gold")) == TYPE_INT
		and typeof(dict.get("scraps")) == TYPE_INT
		and int(dict["gold"]) == expected_gold
		and int(dict["scraps"]) == expected_scraps
	)


func _is_integral_json_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number
	return false


func _is_free_outcome(outcome: Variant) -> bool:
	# Godot's JSON parser yields floats for numeric literals, so compare values.
	if typeof(outcome) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = outcome
	return (
		dict.size() == 2
		and dict.has("gold")
		and dict.has("scraps")
		and _is_integral_json_number(dict.get("gold"))
		and _is_integral_json_number(dict.get("scraps"))
		and int(dict["gold"]) == 0
		and int(dict["scraps"]) == 0
	)


## Converts a raw JSON/authored record into comparable integer-valued content.
func _normalized_record(record: Dictionary) -> Dictionary:
	var choices: Array = []
	for choice_raw: Variant in record.get("choices", []):
		if not (choice_raw is Dictionary):
			continue
		var choice: Dictionary = choice_raw
		var outcome_raw: Variant = choice.get("outcome")
		var outcome: Dictionary = outcome_raw if outcome_raw is Dictionary else {}
		choices.append({
			"id": String(choice.get("id", "")),
			"text": String(choice.get("text", "")),
			"outcome": {
				"gold": int(outcome.get("gold", 0)),
				"scraps": int(outcome.get("scraps", 0)),
			},
		})
	return {
		"id": String(record.get("id", "")),
		"title": String(record.get("title", "")),
		"description": String(record.get("description", "")),
		"fight_choice_id": String(record.get("fight_choice_id", "")),
		"choices": choices,
	}


func _normalized_from_spec(event_id: String, spec: Dictionary) -> Dictionary:
	return {
		"id": event_id,
		"title": String(spec.get("title", "")),
		"description": String(spec.get("description", "")),
		"fight_choice_id": String(spec.get("fight_choice_id", "")),
		"choices": spec.get("choices", []),
	}


func _matching_events(events: Array, event_id: String) -> Array:
	var matches: Array = []
	for item_raw: Variant in events:
		if item_raw is Dictionary and String((item_raw as Dictionary).get("id", "")) == event_id:
			matches.append(item_raw)
	return matches


func _event_index(events: Array, event_id: String) -> int:
	for index: int in range(events.size()):
		var item_raw: Variant = events[index]
		if item_raw is Dictionary and String((item_raw as Dictionary).get("id", "")) == event_id:
			return index
	return -1


func _spec_choice_ids(spec: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for choice_raw: Variant in (spec["choices"] as Array):
		ids.append(String((choice_raw as Dictionary)["id"]))
	return ids
