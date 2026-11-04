extends SceneTree
## Deterministic headless test for the four appended gothic roadside
## Fight-or-toll Events in res://data/events/v3_fight_choice_events.json
## (Milestone V3-4, Stitched v4 S6-ready data).
##
## The shipped catalog is read through FileAccess/JSON and authenticated through
## the real RunV3FightEventGate (and its RunEventChoice wallet service). Nothing
## here is wired into a live battle: a successful Fight choice only yields the
## detached pending {"node_type": "Fight"} request that S6 will route.
##
## Deliberately absent: an assertion on the catalog's total record count, on any
## new record's absolute rank, on the full ordered catalog ID list, or on a fixed
## seed-to-event mapping. Only required-ID presence, authored relative order of
## the fourteen earlier records, and per-ID seeded oracle behavior are checked, so
## other lanes may append records concurrently.

const CATALOG_PATH := "res://data/events/v3_fight_choice_events.json"
const FIGHT_REQUEST := {"node_type": "Fight"}

## The fourteen records authored before this lane, in their shipped order.
## Presence is required; only their relative order is asserted, never a rank.
const EARLIER_EVENT_IDS := [
	"v3_stitchline_roadblock",
	"v3_frayed_bridge_watch",
	"v3_lanternless_ambush",
	"v3_knotted_yarn_patrol",
	"v3_buttonwall_checkpoint",
	"v3_bellspool_picket",
	"v3_scissorclock_tollhouse",
	"v3_mothglass_lantern_patrol",
	"v3_crowpin_quilt_checkpoint",
	"v3_button_drum_masquerade",
	"v3_inklace_paper_doll_tribunal",
	"v3_mossroot_button_snare",
	"v3_oxblood_wardrobe_checkpoint",
	"v3_bonecream_mirror_masquerade",
]

## The four authored records of this lane, hardcoded independently of the JSON:
## exact prose, choice IDs/texts and signed outcome deltas.
const EXPECTED_EVENTS := {
	"v3_midnight_needle_ferryman": {
		"title": "The Midnight Needle Ferry",
		"description": "A squat button-eyed ferryman plants an enormous silver needle oar across a black quilt river; three hooded doll sentries pull the ferry's oxblood rope taut.",
		"fight_choice_id": "seize_needle_oar",
		"paid_choice_id": "buy_ferry_token",
		"paid_outcome": {"gold": -18, "scraps": 0},
		"toll_wallet": {"gold": 22, "scraps": 5},
		"short_wallet": {"gold": 17, "scraps": 5},
		"choices": [
			{"id": "seize_needle_oar", "text": "Seize the giant needle oar and face the ferry sentries (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "buy_ferry_token", "text": "Pay 18 gold for a stitched night-ferry token", "outcome": {"gold": -18, "scraps": 0}},
			{"id": "leave", "text": "Follow the dim bank instead (Leave)", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	"v3_glass_eye_marionette_gate": {
		"title": "The Glass-Eye Marionette Gate",
		"description": "A huge cloudy glass-button eye hangs over a pin-laced gate as four plump velvet marionette guards tug their stiff strings into a barricade.",
		"fight_choice_id": "cut_puppet_barrier",
		"paid_choice_id": "offer_glass_thread",
		"paid_outcome": {"gold": 0, "scraps": -2},
		"toll_wallet": {"gold": 40, "scraps": 3},
		"short_wallet": {"gold": 40, "scraps": 1},
		"choices": [
			{"id": "cut_puppet_barrier", "text": "Cut the puppet strings and confront the dangling guards (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "offer_glass_thread", "text": "Offer 2 scrap bundles to loosen the gate's puppet strings", "outcome": {"gold": 0, "scraps": -2}},
			{"id": "leave", "text": "Back away while the glass eye stays shut (Leave)", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	"v3_briar_hem_funeral_parade": {
		"title": "The Briar-Hem Procession",
		"description": "Three round mourning dolls haul a coffin-sized brass thimble beneath a mossy briar arch; a stout bell-bearing marshal bars the candlelit lane.",
		"fight_choice_id": "challenge_briar_marshal",
		"paid_choice_id": "purchase_briar_seal",
		"paid_outcome": {"gold": -22, "scraps": 0},
		"toll_wallet": {"gold": 18, "scraps": 5},
		"short_wallet": {"gold": 21, "scraps": 5},
		"choices": [
			{"id": "challenge_briar_marshal", "text": "Challenge the briar-hem marshal and its mourners (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "purchase_briar_seal", "text": "Pay 22 gold for the marshal's stitched passage seal", "outcome": {"gold": -22, "scraps": 0}},
			{"id": "leave", "text": "Let the mourning parade pass ahead (Leave)", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	"v3_ashen_candle_clocktower": {
		"title": "The Ashen Wick Clocktower",
		"description": "A leaning quilted clocktower turns a giant unlit candle into its hour hand; squat pin-helmet dolls brace a brass pendulum across the road.",
		"fight_choice_id": "break_pendulum_line",
		"paid_choice_id": "surrender_wick_scraps",
		"paid_outcome": {"gold": 0, "scraps": -3},
		"toll_wallet": {"gold": 40, "scraps": 2},
		"short_wallet": {"gold": 40, "scraps": 2},
		"choices": [
			{"id": "break_pendulum_line", "text": "Break the brass pendulum line and fight the clock guards (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "surrender_wick_scraps", "text": "Surrender 3 scrap bundles for the clock guards' safe passage", "outcome": {"gold": 0, "scraps": -3}},
			{"id": "leave", "text": "Wait outside the tower until the guards leave (Leave)", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
}

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	seed(90210)
	var expected_global_rng: int = randi()
	seed(90210)

	_test_ac1_shipped_records()
	_test_ac2_visit_settlement_branches()
	_test_ac3_short_wallets_and_forgeries()
	_test_ac4_single_offer_selection()

	_check(randi() == expected_global_rng, "global RNG untouched across the whole suite")
	for failure: String in failures:
		printerr(failure)
	print(
		"v3_stitched_gothic_fight_roadside_events_test: ",
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

	# Named earlier anchors and every earlier record remain present exactly once.
	var earlier_choice_ids: Dictionary = {}
	var last_earlier_index: int = -1
	for anchor_id: String in EARLIER_EVENT_IDS:
		var anchor_matches: Array = _matching_events(events, anchor_id)
		_check(anchor_matches.size() == 1, "earlier record present exactly once: " + anchor_id)
		var anchor_index: int = _event_index(events, anchor_id)
		_check(anchor_index > last_earlier_index, "earlier records keep their relative order: " + anchor_id)
		last_earlier_index = anchor_index
		if anchor_matches.size() != 1:
			continue
		for choice_raw: Variant in (anchor_matches[0] as Dictionary).get("choices", []):
			if choice_raw is Dictionary:
				earlier_choice_ids[String((choice_raw as Dictionary).get("id", ""))] = anchor_id
	for named_anchor: String in ["v3_stitchline_roadblock", "v3_bellspool_picket", "v3_bonecream_mirror_masquerade"]:
		_check(EARLIER_EVENT_IDS.has(named_anchor), "named earlier anchor is tracked: " + named_anchor)
		_check(_matching_events(events, named_anchor).size() == 1, "named earlier anchor present exactly once: " + named_anchor)

	var new_choice_ids: Dictionary = {}
	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		_check(not EARLIER_EVENT_IDS.has(event_id), "new event ID was never used before: " + event_id)
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

		var seen_choice_ids: Dictionary = {}
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
			_check(not seen_choice_ids.has(choice_id), "choice IDs are unique inside the record: " + choice_id)
			seen_choice_ids[choice_id] = true
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

		# Every new authored choice ID is distinct from the others and from earlier ones.
		for choice_id: String in seen_choice_ids.keys():
			if choice_id == "leave":
				continue
			_check(not new_choice_ids.has(choice_id), "new choice ID is distinct: " + choice_id)
			_check(not earlier_choice_ids.has(choice_id), "new choice ID was never used before: " + choice_id)
			new_choice_ids[choice_id] = event_id

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
		var funded := _funded_wallet()
		var funded_before := funded.duplicate(true)
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
			_check(row["wallet"] == {"gold": 40 + gold_delta, "scraps": 5 + scraps_delta}, "preview projects the authored wallet: " + choice_id)
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
		_check(fight_receipt.get("wallet") == _funded_wallet(), "fight preserves the wallet: " + event_id)
		_check(fight_receipt.get("fight_request") == FIGHT_REQUEST, "fight returns only the pending Fight request: " + event_id)
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
		_check(_wallet_exact_int(toll_receipt.get("wallet"), int(spec["toll_wallet"]["gold"]), int(spec["toll_wallet"]["scraps"])), "toll debits the exact authored amount: " + event_id)
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
		_check(leave_receipt.get("wallet") == _funded_wallet(), "leave preserves the wallet: " + event_id)
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


func _test_ac3_short_wallets_and_forgeries() -> void:
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "gate validates the shipped catalog for fail-closed checks")
	var catalog_snapshot: Array = gate.get_catalog_events().duplicate(true)

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var paid_choice_id: String = spec["paid_choice_id"]
		var fight_choice_id: String = spec["fight_choice_id"]
		var short_wallet: Dictionary = (spec["short_wallet"] as Dictionary).duplicate(true)
		var short_before := short_wallet.duplicate(true)

		# Preview reports the toll as unaffordable at one unit short.
		var short_visit := gate.open_visit(event_id)
		_check(short_visit != null and short_visit.is_valid(), "short-resource visit opens: " + event_id)
		if short_visit == null:
			continue
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

		# Settlement refuses unchanged and claims nothing.
		var refused: Dictionary = short_visit.choose_with_wallet(paid_choice_id, short_wallet)
		_check(_receipt_shape_ok(refused), "refusal receipt shape: " + event_id)
		_check(refused.get("ok") == false, "short wallet toll is refused: " + event_id)
		_check(refused.get("wallet") == short_wallet, "refusal returns the unchanged wallet: " + event_id)
		_check(refused.get("fight_request") == {}, "refusal returns no Fight request: " + event_id)
		_check(short_visit.is_valid() and not short_visit.is_claimed(), "refused toll leaves the visit unclaimed: " + event_id)
		_check(short_wallet == short_before, "refused toll mutates no caller wallet: " + event_id)

		# The same fresh visit may still settle Leave.
		var leave_receipt: Dictionary = short_visit.choose_with_wallet("leave", short_wallet)
		_check(leave_receipt.get("ok") == true, "failed toll visit can still Leave: " + event_id)
		_check(leave_receipt.get("wallet") == short_wallet and leave_receipt.get("fight_request") == {}, "Leave after refusal is free: " + event_id)
		_check(short_visit.is_claimed(), "Leave after refusal claims the visit once: " + event_id)

		# A separate fresh instance may still settle Fight.
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
		var unknown_receipt: Dictionary = unknown_visit.choose_with_wallet("bogus_choice_id", _funded_wallet())
		_check(unknown_receipt.get("ok") == false, "unknown choice is refused: " + event_id)
		_check(unknown_receipt.get("wallet") == _funded_wallet() and unknown_receipt.get("fight_request") == {}, "unknown choice returns the unchanged wallet and no request: " + event_id)
		_check(unknown_visit.is_valid() and not unknown_visit.is_claimed(), "unknown choice leaves the visit unclaimed: " + event_id)

		# Forged records (altered title or outcome) cannot be opened or bound.
		var authentic: Dictionary = gate.get_event_record(event_id)
		_check(not authentic.is_empty(), "authentic record retrieved: " + event_id)
		var forged_title: Dictionary = authentic.duplicate(true)
		forged_title["title"] = "A Forged Goth Roadside Title"
		var forged_paid: Dictionary = authentic.duplicate(true)
		(forged_paid["choices"] as Array)[1]["outcome"] = {"gold": 0, "scraps": 0}
		var forged_fight: Dictionary = authentic.duplicate(true)
		(forged_fight["choices"] as Array)[0]["outcome"] = {"gold": 1, "scraps": 0}
		var forged_leave: Dictionary = authentic.duplicate(true)
		(forged_leave["choices"] as Array)[2]["outcome"] = {"gold": 0, "scraps": -1}
		var forged_cases: Array = [
			{"record": forged_title, "label": "altered title"},
			{"record": forged_paid, "label": "free toll outcome"},
			{"record": forged_fight, "label": "paid Fight outcome"},
			{"record": forged_leave, "label": "paid Leave outcome"},
		]
		for forged_case: Dictionary in forged_cases:
			var forged: Dictionary = forged_case["record"]
			var label: String = forged_case["label"]
			_check(gate.open_visit(forged) == null, "open_visit refuses forged record (" + label + "): " + event_id)
			var forged_gate := RunV3FightEventGate.new(forged)
			_check(not forged_gate.is_valid() and not forged_gate.is_claimed(), "forged gate binds no visit (" + label + "): " + event_id)
			var forged_wallet := _funded_wallet()
			var forged_receipt: Dictionary = forged_gate.choose_with_wallet(paid_choice_id, forged_wallet)
			_check(forged_receipt.get("ok") == false, "forged gate settles nothing (" + label + "): " + event_id)
			_check(forged_receipt.get("wallet") == forged_wallet and forged_receipt.get("fight_request") == {}, "forged refusal preserves the wallet (" + label + "): " + event_id)

		# A successful visit rejects a repeated or alternate claim with no extra debit.
		var claimed_visit := gate.open_visit(event_id)
		_check(claimed_visit != null and claimed_visit.is_valid(), "claimable visit opens: " + event_id)
		if claimed_visit == null:
			continue
		var first_claim: Dictionary = claimed_visit.choose_with_wallet(paid_choice_id, _funded_wallet())
		_check(first_claim.get("ok") == true and first_claim.get("wallet") == spec["toll_wallet"], "first toll claim debits once: " + event_id)
		var settled_wallet: Dictionary = (spec["toll_wallet"] as Dictionary).duplicate(true)
		var repeat_claim: Dictionary = claimed_visit.choose_with_wallet(paid_choice_id, settled_wallet)
		_check(repeat_claim.get("ok") == false, "repeated claim is refused: " + event_id)
		_check(repeat_claim.get("wallet") == settled_wallet, "repeated claim debits nothing: " + event_id)
		var alternate_claim: Dictionary = claimed_visit.choose_with_wallet(fight_choice_id, settled_wallet)
		_check(alternate_claim.get("ok") == false, "alternate claim on a claimed visit is refused: " + event_id)
		_check(alternate_claim.get("wallet") == settled_wallet, "alternate claim debits nothing: " + event_id)
		_check(alternate_claim.get("fight_request") == {}, "alternate claim yields no Fight request: " + event_id)
		_check(claimed_visit.is_claimed(), "claimed visit stays claimed: " + event_id)

	_check(gate.get_catalog_events() == catalog_snapshot, "fail-closed checks preserve the catalog")
	_check(not gate.is_claimed(), "fail-closed checks leave the catalog gate unclaimed")


func _test_ac4_single_offer_selection() -> void:
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "gate validates the shipped catalog for offer selection")
	var records: Array[Dictionary] = gate.get_catalog_events()
	_check(not records.is_empty(), "offer catalog is non-empty")
	var all_ids: Array[String] = []
	for record: Dictionary in records:
		all_ids.append(String(record.get("id", "")))
	var catalog_snapshot: Array = records.duplicate(true)
	var seed_value: int = 246813

	for event_id: String in EXPECTED_EVENTS.keys():
		_check(all_ids.has(event_id), "authored event is in the live catalog: " + event_id)
		var excluded: Array[String] = all_ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id), "exclusions omit the target: " + event_id)
		var excluded_before: Array[String] = excluded.duplicate()
		var authentic_before: Dictionary = gate.get_event_record(event_id)

		# Oracle: one sorted-ID draw over the single eligible record.
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)

		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var offer: Dictionary = gate.select_fight_or_toll_offer(rng, excluded, _funded_wallet())
		_check(offer.get("ok") == true, "single-option offer succeeds: " + event_id)
		_check(offer.get("event", {}).get("id") == event_id, "offer returns the sole unexcluded ID: " + event_id)
		_check(offer.get("event") == gate.get_event_record(event_id), "offer returns the authenticated record: " + event_id)
		_check(rng.state == oracle.state, "single-option offer consumes exactly one draw: " + event_id)
		var offered_visit := gate.open_visit(offer.get("event"))
		_check(offered_visit != null and offered_visit.is_valid(), "offered record opens an authentic visit: " + event_id)
		if offered_visit != null:
			_check(offer.get("preview") == offered_visit.preview_choices(_funded_wallet()), "offer preview matches an authentic preview: " + event_id)
		_check(excluded == excluded_before, "offer preserves the caller exclusions: " + event_id)

		# Same seed and exclusions replay the identical offer with one draw.
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay: Dictionary = gate.select_fight_or_toll_offer(replay_rng, excluded, _funded_wallet())
		_check(replay == offer, "equal seeds replay the identical offer: " + event_id)
		_check(replay_rng.state == oracle.state, "replayed offer consumes exactly one draw: " + event_id)

		# Mutating the returned offer cannot reach the catalog or bound visits.
		if offer.get("event") is Dictionary:
			(offer["event"]["choices"] as Array).clear()
		if offer.get("preview") is Dictionary:
			for row_raw: Variant in offer["preview"].get("choices", []):
				if row_raw is Dictionary:
					(row_raw as Dictionary)["wallet"]["gold"] = 999
					(row_raw as Dictionary)["fight_request"]["node_type"] = "Boss"
		_check(gate.get_event_record(event_id) == authentic_before, "offer mutation is detached from the catalog: " + event_id)
		_check(gate.open_visit(event_id).preview_choices(_funded_wallet()) != offer.get("preview"), "mutated offer preview is detached from an authentic preview: " + event_id)

	# Refusals consume no RNG at all.
	var denied := {"ok": false, "event": {}, "preview": {}}
	var probe := RandomNumberGenerator.new()
	probe.seed = 13579
	var probe_before: int = probe.state
	_check(gate.select_fight_or_toll_offer(null, [], _funded_wallet()) == denied, "null RNG is refused")
	_check(gate.select_fight_or_toll_offer(123, [], _funded_wallet()) == denied, "int RNG is refused")
	_check(gate.select_fight_or_toll_offer("rng", [], _funded_wallet()) == denied, "string RNG is refused")
	_check(gate.select_fight_or_toll_offer({}, [], _funded_wallet()) == denied, "dictionary RNG is refused")
	_check(probe.state == probe_before, "invalid RNG spends no draw")

	var bad_wallets: Array = [
		null,
		1,
		"wallet",
		[],
		{},
		{"gold": 40},
		{"scraps": 5},
		{"gold": 40, "scraps": 5, "extra": 1},
		{"gold": -1, "scraps": 5},
		{"gold": 40, "scraps": -1},
		{"gold": 40.0, "scraps": 5},
		{"gold": 40, "scraps": 5.0},
		{"gold": "40", "scraps": 5},
		{"gold": true, "scraps": 5},
	]
	for bad_wallet: Variant in bad_wallets:
		_check(gate.select_fight_or_toll_offer(probe, [], bad_wallet) == denied, "wrong-type wallet is refused: " + str(bad_wallet))
		_check(probe.state == probe_before, "wrong-type wallet spends no draw: " + str(bad_wallet))

	var bad_exclusions: Array = [
		"not_an_array",
		123,
		{},
		[123],
		[""],
		["   "],
		[null],
	]
	for bad_exclusion: Variant in bad_exclusions:
		_check(gate.select_fight_or_toll_offer(probe, bad_exclusion, _funded_wallet()) == denied, "invalid exclusions are refused: " + str(bad_exclusion))
		_check(probe.state == probe_before, "invalid exclusions spend no draw: " + str(bad_exclusion))

	_check(gate.select_fight_or_toll_offer(probe, all_ids, _funded_wallet()) == denied, "all IDs excluded is refused")
	_check(probe.state == probe_before, "exhausted exclusions spend no draw")
	_check(gate.get_catalog_events() == catalog_snapshot, "offer selection preserves every catalog record")
	_check(not gate.is_claimed(), "offer selection claims no visit")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _funded_wallet() -> Dictionary:
	return {"gold": 40, "scraps": 5}


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
