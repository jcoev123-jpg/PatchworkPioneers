extends SceneTree
## Deterministic headless test for the four gothic prop-driven roadside
## Fight-choice Events appended to res://data/events/v3_fight_choice_events.json
## (Milestone V3-4). Expectations are authored independently from the brief; the
## catalog's exact total, slot order and full ID list are never asserted.

const CATALOG_PATH := "res://data/events/v3_fight_choice_events.json"
const FUNDED_WALLET := {"gold": 40, "scraps": 5}
const POOR_WALLET := {"gold": 0, "scraps": 0}
const FIGHT_REQUEST := {"node_type": "Fight"}

const EXPECTED_EVENTS := {
	"v3_scissorclock_tollhouse": {
		"title": "The Scissor-Clock Tollhouse",
		"description": "A squat button-eyed tollkeeper shelters under a giant scissor-faced clock; its brass blades tick as stitched sentries bar the midnight lane.",
		"fight_choice_id": "cut_clock_chain",
		"paid_choice_id": "buy_clock_pass",
		"choices": [
			{"id": "cut_clock_chain", "text": "Cut the scissor-clock chain and confront the sentries (Fight)", "gold": 0, "scraps": 0},
			{"id": "buy_clock_pass", "text": "Pay 17 gold for a stamped scissor-clock pass", "gold": -17, "scraps": 0},
			{"id": "leave", "text": "Take the unlit side path (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_mothglass_lantern_patrol": {
		"title": "The Mothglass Lantern Patrol",
		"description": "A plump moth puppet circles a huge glass lantern as candle-eyed guards block the velvet road with stretched silk wings.",
		"fight_choice_id": "scatter_moth_guard",
		"paid_choice_id": "offer_wick_thread",
		"choices": [
			{"id": "scatter_moth_guard", "text": "Scatter the moth-wing guards and fight through (Fight)", "gold": 0, "scraps": 0},
			{"id": "offer_wick_thread", "text": "Offer 2 scrap bundles of wick thread for passage", "gold": 0, "scraps": -2},
			{"id": "leave", "text": "Follow the dark path around the lantern (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_crowpin_quilt_checkpoint": {
		"title": "The Crowpin Quilt Checkpoint",
		"description": "A button-eyed crow doll perches on an oversized silver safety pin above an oxblood quilt wall; masked guards wait beneath its wings.",
		"fight_choice_id": "raise_crowpin_banner",
		"paid_choice_id": "buy_crowpin_token",
		"choices": [
			{"id": "raise_crowpin_banner", "text": "Raise the crowpin banner and challenge the guards (Fight)", "gold": 0, "scraps": 0},
			{"id": "buy_crowpin_token", "text": "Pay 13 gold for a crowpin crossing token", "gold": -13, "scraps": 0},
			{"id": "leave", "text": "Turn away from the quilt wall (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_button_drum_masquerade": {
		"title": "The Button-Drum Masquerade",
		"description": "A brass-button drum booms beneath plum bunting; round masked ragdoll drummers raise patched shields to block the torchlit street.",
		"fight_choice_id": "challenge_drum_guard",
		"paid_choice_id": "trade_drum_stitches",
		"choices": [
			{"id": "challenge_drum_guard", "text": "Challenge the button-drummers at the barricade (Fight)", "gold": 0, "scraps": 0},
			{"id": "trade_drum_stitches", "text": "Trade 3 scrap bundles for a guarded pass", "gold": 0, "scraps": -3},
			{"id": "leave", "text": "Slip past the quiet bunting (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

const ANCHOR_EVENTS := {
	"v3_stitchline_roadblock": {
		"fight_choice_id": "break_barricade",
		"paid_choice_id": "pay_road_toll",
		"paid_gold": -14,
		"paid_scraps": 0,
	},
	"v3_bellspool_picket": {
		"fight_choice_id": "ring_the_bells",
		"paid_choice_id": "pay_bell_toll",
		"paid_gold": -16,
		"paid_scraps": 0,
	},
}

var failures: Array[String] = []
var checks: int = 0
var catalog_doc: Dictionary = {}
var catalog_snapshot: Dictionary = {}


func _initialize() -> void:
	seed(61207)
	var expected_global_rng: int = randi()
	seed(61207)
	var probe_rng := RandomNumberGenerator.new()
	probe_rng.seed = 61207
	var initial_probe_state: int = probe_rng.state

	_load_catalog()
	if catalog_doc.is_empty():
		for failure in failures:
			printerr(failure)
		print("v3_scissorclock_mothglass_fight_stories_test: FAIL (", checks, " checks, catalog unreadable)")
		quit(1)
		return

	_test_ac1_authored_records()
	_test_ac1_anchors_preserved()
	_test_ac2_funded_branches()
	_test_ac3_poor_wallet_fail_closed()
	_test_ac4_catalog_selector()
	_test_ac4_detached_records_and_refusals()

	_check(catalog_doc == catalog_snapshot, "catalog document unchanged across the suite")
	_check(probe_rng.state == initial_probe_state, "seeded probe RNG state unchanged across the suite")
	_check(randi() == expected_global_rng, "global RNG untouched across the suite")

	for failure in failures:
		printerr(failure)
	print("v3_scissorclock_mothglass_fight_stories_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_catalog() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check(file != null, "v3_fight_choice_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_err := parser.parse(text)
	_check(parse_err == OK and parser.data is Dictionary, "v3_fight_choice_events.json parses as a JSON object")
	if parse_err != OK or not (parser.data is Dictionary):
		return
	catalog_doc = parser.data
	catalog_snapshot = catalog_doc.duplicate(true)
	var events_raw: Variant = catalog_doc.get("events")
	_check(events_raw is Array and not (events_raw as Array).is_empty(), "catalog has a non-empty events array")


func _catalog_events() -> Array:
	return catalog_doc.get("events", [])


func _records_matching(event_id: String) -> Array:
	var matches: Array = []
	for item_raw: Variant in _catalog_events():
		if item_raw is Dictionary and (item_raw as Dictionary).get("id") == event_id:
			matches.append(item_raw)
	return matches


func _project(wallet: Dictionary, gold: int, scraps: int) -> Dictionary:
	return {"gold": int(wallet["gold"]) + gold, "scraps": int(wallet["scraps"]) + scraps}


func _expected_receipt(event_id: String, choice_id: String, wallet_after: Dictionary, pending_fight: bool) -> Dictionary:
	return {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"wallet": wallet_after,
		"fight_request": FIGHT_REQUEST.duplicate(true) if pending_fight else {},
	}


func _expected_rejection(wallet_after: Dictionary) -> Dictionary:
	return {"ok": false, "event_id": "", "choice_id": "", "wallet": wallet_after, "fight_request": {}}


func _integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number
	return false


func _find_entry(entries: Array, choice_id: String) -> Dictionary:
	for entry_raw: Variant in entries:
		if entry_raw is Dictionary and (entry_raw as Dictionary).get("choice_id") == choice_id:
			return entry_raw
	return {}


func _test_ac1_authored_records() -> void:
	var id_counts: Dictionary = {}
	for item_raw: Variant in _catalog_events():
		_check(item_raw is Dictionary, "every catalog entry is a JSON object")
		if not (item_raw is Dictionary):
			continue
		var entry_id: Variant = (item_raw as Dictionary).get("id")
		_check(entry_id is String and not String(entry_id).strip_edges().is_empty(), "every catalog entry has a nonblank id")
		if entry_id is String:
			id_counts[String(entry_id)] = int(id_counts.get(String(entry_id), 0)) + 1
	for counted_id: String in id_counts.keys():
		_check(int(id_counts[counted_id]) == 1, "catalog ID occurs exactly once: " + counted_id)

	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "RunV3FightEventGate validates the shipped catalog")

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var matches: Array = _records_matching(event_id)
		_check(matches.size() == 1, "exactly one authored record for " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(
			record.size() == 5
			and record.has("id")
			and record.has("title")
			and record.has("description")
			and record.has("fight_choice_id")
			and record.has("choices"),
			"record has exact five top-level keys: " + event_id
		)
		_check(record.get("id") == event_id, "record id matches its key: " + event_id)
		_check(record.get("title") == spec["title"], "exact title: " + event_id)
		_check(record.get("description") == spec["description"], "exact description: " + event_id)
		_check(record.get("fight_choice_id") == spec["fight_choice_id"], "exact fight_choice_id: " + event_id)

		var choices_raw: Variant = record.get("choices")
		_check(choices_raw is Array and (choices_raw as Array).size() == 3, "exactly three choices: " + event_id)
		if not (choices_raw is Array) or (choices_raw as Array).size() != 3:
			continue
		var expected_choices: Array = spec["choices"]
		for index in range(3):
			var expected_choice: Dictionary = expected_choices[index]
			var choice_raw: Variant = (choices_raw as Array)[index]
			_check(choice_raw is Dictionary, "choice %d is a JSON object: %s" % [index, event_id])
			if not (choice_raw is Dictionary):
				continue
			var choice: Dictionary = choice_raw
			_check(
				choice.size() == 3 and choice.has("id") and choice.has("text") and choice.has("outcome"),
				"choice %d has exact id/text/outcome keys: %s" % [index, event_id]
			)
			_check(choice.get("id") == expected_choice["id"], "exact choice id at slot %d: %s" % [index, event_id])
			_check(choice.get("text") == expected_choice["text"], "exact choice text at slot %d: %s" % [index, event_id])
			var outcome_raw: Variant = choice.get("outcome")
			_check(outcome_raw is Dictionary, "choice %d outcome is a JSON object: %s" % [index, event_id])
			if not (outcome_raw is Dictionary):
				continue
			var outcome: Dictionary = outcome_raw
			_check(
				outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps")
				and _integral(outcome.get("gold")) and _integral(outcome.get("scraps")),
				"outcome has exactly integral gold/scraps: %s/%s" % [event_id, expected_choice["id"]]
			)
			_check(
				int(outcome.get("gold")) == int(expected_choice["gold"])
				and int(outcome.get("scraps")) == int(expected_choice["scraps"]),
				"exact signed outcome delta: %s/%s" % [event_id, expected_choice["id"]]
			)

		var fight_choice_id: String = spec["fight_choice_id"]
		var paid_choice_id: String = spec["paid_choice_id"]
		var fight_choice: Dictionary = (choices_raw as Array)[0]
		var paid_choice: Dictionary = (choices_raw as Array)[1]
		var leave_choice: Dictionary = (choices_raw as Array)[2]
		_check(fight_choice.get("id") == fight_choice_id, "fight_choice_id matches the offered Fight choice: " + event_id)
		_check(paid_choice.get("id") == paid_choice_id, "priced alternative is the second offered choice: " + event_id)
		_check(leave_choice.get("id") == "leave", "third choice is the free Leave: " + event_id)
		var paid_outcome: Dictionary = paid_choice.get("outcome")
		_check(
			int(paid_outcome.get("gold")) < 0 or int(paid_outcome.get("scraps")) < 0,
			"priced alternative carries a negative delta: " + event_id
		)

		var authenticated: Dictionary = gate.get_event_record(event_id)
		_check(authenticated == record, "gate authenticates the authored record: " + event_id)


func _test_ac1_anchors_preserved() -> void:
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "catalog stays valid with the appended records")
	for event_id: String in ANCHOR_EVENTS.keys():
		var spec: Dictionary = ANCHOR_EVENTS[event_id]
		var matches: Array = _records_matching(event_id)
		_check(matches.size() == 1, "earlier anchor entry preserved exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.get("fight_choice_id") == spec["fight_choice_id"], "anchor fight_choice_id preserved: " + event_id)
		var paid: Dictionary = {}
		for choice_raw: Variant in record.get("choices", []):
			if (choice_raw as Dictionary).get("id") == spec["paid_choice_id"]:
				paid = choice_raw
		_check(not paid.is_empty(), "anchor priced choice preserved: " + event_id)
		if not paid.is_empty():
			var outcome: Dictionary = paid.get("outcome", {})
			_check(
				int(outcome.get("gold")) == int(spec["paid_gold"])
				and int(outcome.get("scraps")) == int(spec["paid_scraps"]),
				"anchor priced delta preserved: " + event_id
			)
		var visit := gate.open_visit(event_id)
		_check(visit != null and visit.is_valid(), "anchor still opens a valid visit: " + event_id)


func _test_ac2_funded_branches() -> void:
	var factory := RunV3FightEventGate.new()
	_check(factory.is_catalog_valid(), "factory gate validates the catalog before funded branches")

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var fight_choice_id: String = spec["fight_choice_id"]
		for choice_spec_raw: Variant in spec["choices"]:
			var choice_spec: Dictionary = choice_spec_raw
			var choice_id: String = choice_spec["id"]
			var expected_wallet: Dictionary = _project(FUNDED_WALLET, int(choice_spec["gold"]), int(choice_spec["scraps"]))
			var pending_fight: bool = choice_id == fight_choice_id

			var visit := factory.open_visit(event_id)
			_check(visit != null and visit.is_valid(), "fresh visit opens for %s/%s" % [event_id, choice_id])
			if visit == null:
				continue
			var caller_wallet: Dictionary = FUNDED_WALLET.duplicate(true)
			var wallet_snapshot: Dictionary = caller_wallet.duplicate(true)

			var preview: Dictionary = visit.preview_choices(caller_wallet)
			_check(
				preview.get("ok") == true
				and preview.get("event_id") == event_id
				and preview.get("fight_choice_id") == fight_choice_id,
				"preview_choices identifies the visit for %s/%s" % [event_id, choice_id]
			)
			var entries: Array = preview.get("choices", [])
			_check(entries.size() == 3, "preview lists three choices for %s/%s" % [event_id, choice_id])
			var entry: Dictionary = _find_entry(entries, choice_id)
			_check(not entry.is_empty(), "preview lists the chosen option for %s/%s" % [event_id, choice_id])
			if not entry.is_empty():
				_check(
					entry.get("gold_delta") == int(choice_spec["gold"])
					and entry.get("scraps_delta") == int(choice_spec["scraps"]),
					"preview deltas match the authored outcome for %s/%s" % [event_id, choice_id]
				)
				_check(entry.get("affordable") == true, "funded wallet affords %s/%s" % [event_id, choice_id])
				_check(entry.get("wallet") == expected_wallet, "preview projects the exact balance for %s/%s" % [event_id, choice_id])
				_check(
					entry.get("fight_request") == (FIGHT_REQUEST.duplicate(true) if pending_fight else {}),
					"preview fight_request only on the Fight option for %s/%s" % [event_id, choice_id]
				)
			for other_raw: Variant in entries:
				var other: Dictionary = other_raw
				if other.get("choice_id") != fight_choice_id:
					_check(
						other.get("fight_request") == {},
						"non-Fight preview carries no fight_request: %s/%s" % [event_id, other.get("choice_id")]
					)
			_check(visit.is_valid() and not visit.is_claimed(), "preview does not consume the claim for %s/%s" % [event_id, choice_id])

			var receipt: Dictionary = visit.choose_with_wallet(choice_id, caller_wallet)
			_check(
				receipt == _expected_receipt(event_id, choice_id, expected_wallet, pending_fight),
				"claim settles %s/%s with expected wallet and fight_request" % [event_id, choice_id]
			)
			if pending_fight:
				_check(receipt.get("fight_request") == {"node_type": "Fight"}, "Fight choice requests exactly one pending Fight: " + event_id)
			else:
				_check(receipt.get("fight_request") == {}, "non-Fight choice never launches a fight: %s/%s" % [event_id, choice_id])
			_check(caller_wallet == wallet_snapshot, "claim does not mutate the caller wallet for %s/%s" % [event_id, choice_id])
			_check(visit.is_claimed() and not visit.is_valid(), "claim latches the visit for %s/%s" % [event_id, choice_id])

			var replay: Dictionary = visit.choose_with_wallet(choice_id, caller_wallet)
			_check(
				replay == _expected_rejection(wallet_snapshot),
				"replayed claim rejects without a fight for %s/%s" % [event_id, choice_id]
			)
			var unknown: Dictionary = visit.choose_with_wallet("unknown_choice_id", caller_wallet)
			_check(
				unknown == _expected_rejection(wallet_snapshot),
				"unknown choice rejects without a fight for %s/%s" % [event_id, choice_id]
			)


func _test_ac3_poor_wallet_fail_closed() -> void:
	var factory := RunV3FightEventGate.new()
	_check(factory.is_catalog_valid(), "factory gate validates the catalog before poor-wallet branches")

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var fight_choice_id: String = spec["fight_choice_id"]
		var paid_choice_id: String = spec["paid_choice_id"]

		var visit := factory.open_visit(event_id)
		_check(visit != null and visit.is_valid(), "poor-wallet visit opens for " + event_id)
		if visit == null:
			continue
		var poor_wallet: Dictionary = POOR_WALLET.duplicate(true)
		var preview: Dictionary = visit.preview_choices(poor_wallet)
		var paid_entry: Dictionary = _find_entry(preview.get("choices", []), paid_choice_id)
		_check(not paid_entry.is_empty(), "poor-wallet preview lists the priced option: " + event_id)
		if not paid_entry.is_empty():
			_check(paid_entry.get("affordable") == false, "poor wallet cannot afford the priced option: " + event_id)
			_check(paid_entry.get("wallet") == POOR_WALLET, "unaffordable preview keeps the unchanged balance: " + event_id)
			_check(paid_entry.get("fight_request") == {}, "unaffordable preview carries no fight_request: " + event_id)
		var refusal: Dictionary = visit.choose_with_wallet(paid_choice_id, poor_wallet)
		_check(refusal == _expected_rejection(POOR_WALLET), "poor-wallet priced claim rejects without a fight: " + event_id)
		_check(poor_wallet == POOR_WALLET, "rejected priced claim leaves the wallet unchanged: " + event_id)
		_check(visit.is_valid() and not visit.is_claimed(), "rejected priced claim leaves the visit unclaimed: " + event_id)

		var fight_visit := factory.open_visit(event_id)
		_check(fight_visit != null and fight_visit.is_valid(), "separate poor-wallet Fight visit opens: " + event_id)
		var fight_wallet: Dictionary = POOR_WALLET.duplicate(true)
		var fight_receipt: Dictionary = fight_visit.choose_with_wallet(fight_choice_id, fight_wallet)
		_check(
			fight_receipt == _expected_receipt(event_id, fight_choice_id, POOR_WALLET, true),
			"poor wallet still claims the free Fight on a fresh visit: " + event_id
		)
		_check(fight_wallet == POOR_WALLET, "free Fight claim leaves the wallet unchanged: " + event_id)

		var leave_visit := factory.open_visit(event_id)
		_check(leave_visit != null and leave_visit.is_valid(), "separate poor-wallet Leave visit opens: " + event_id)
		var leave_wallet: Dictionary = POOR_WALLET.duplicate(true)
		var leave_receipt: Dictionary = leave_visit.choose_with_wallet("leave", leave_wallet)
		_check(
			leave_receipt == _expected_receipt(event_id, "leave", POOR_WALLET, false),
			"poor wallet still claims the free Leave on a fresh visit: " + event_id
		)
		var leave_replay: Dictionary = leave_visit.choose_with_wallet("leave", leave_wallet)
		_check(leave_replay == _expected_rejection(POOR_WALLET), "replayed Leave never yields a second receipt: " + event_id)

		var unknown_visit := factory.open_visit(event_id)
		_check(unknown_visit != null and unknown_visit.is_valid(), "probe visit opens for the unoffered-choice check: " + event_id)
		var unknown_receipt: Dictionary = unknown_visit.choose_with_wallet("forged_choice", POOR_WALLET.duplicate(true))
		_check(unknown_receipt == _expected_rejection(POOR_WALLET), "unoffered choice rejects on a poor wallet: " + event_id)
		_check(unknown_visit.is_valid() and not unknown_visit.is_claimed(), "unoffered choice leaves the visit unclaimed: " + event_id)
		var recovery: Dictionary = unknown_visit.choose_with_wallet(fight_choice_id, POOR_WALLET.duplicate(true))
		_check(recovery.get("fight_request") == FIGHT_REQUEST, "visit recovers with Fight after an unoffered choice: " + event_id)
		var after_fight: Dictionary = unknown_visit.choose_with_wallet(fight_choice_id, POOR_WALLET.duplicate(true))
		_check(after_fight == _expected_rejection(POOR_WALLET), "no second fight receipt after a successful claim: " + event_id)


func _all_catalog_ids() -> Array:
	var ids: Array = []
	for record: Dictionary in _catalog_events():
		ids.append(String(record.get("id", "")))
	return ids


func _exclusions_for(event_id: String) -> Array:
	var others: Array = []
	for catalog_id: String in _all_catalog_ids():
		if catalog_id != event_id:
			others.append(catalog_id)
	return others


func _test_ac4_catalog_selector() -> void:
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "gate validates the canonical catalog for selection")
	var listed_ids: Array = _all_catalog_ids()

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		_check(listed_ids.has(event_id), "get_catalog_events lists the new ID: " + event_id)
		var record: Dictionary = gate.get_event_record(event_id)
		_check(record.get("id") == event_id, "get_event_record returns the new ID: " + event_id)
		_check(record.get("fight_choice_id") == spec["fight_choice_id"], "catalog record keeps the authored fight ID: " + event_id)
		var visit := gate.open_visit(event_id)
		_check(
			visit != null and visit.is_valid() and visit.get_event_id() == event_id,
			"open_visit binds the new ID: " + event_id
		)

		var exclusions: Array = _exclusions_for(event_id)
		_check(exclusions.size() == listed_ids.size() - 1, "exclusions cover every other current ID: " + event_id)
		var first_rng := RandomNumberGenerator.new()
		first_rng.seed = 41879
		var selection: Dictionary = gate.select_event(first_rng, exclusions)
		_check(
			selection.get("ok") == true and (selection.get("event", {}) as Dictionary).get("id") == event_id,
			"forced seeded selection returns the new ID: " + event_id
		)
		_check(selection.get("event") == gate.get_event_record(event_id), "selected record equals the authenticated record: " + event_id)

		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = 41879
		var replay: Dictionary = gate.select_event(replay_rng, exclusions)
		_check(replay == selection, "same-seed selection replays identically: " + event_id)
		_check(replay_rng.state == first_rng.state, "same-seed selection consumes the same RNG state: " + event_id)


func _test_ac4_detached_records_and_refusals() -> void:
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "gate validates the catalog for detached/refusal checks")
	var catalog_before: Array[Dictionary] = gate.get_catalog_events()

	var target_id := "v3_crowpin_quilt_checkpoint"
	var canonical: Dictionary = gate.get_event_record(target_id)
	var canonical_snapshot: Dictionary = canonical.duplicate(true)
	_check(not canonical.is_empty(), "detached-check target record exists")
	canonical["title"] = "MUTATED"
	(canonical["choices"] as Array).clear()
	_check(gate.get_event_record(target_id) == canonical_snapshot, "mutating get_event_record output does not touch the catalog")

	var selection_rng := RandomNumberGenerator.new()
	selection_rng.seed = 90210
	var selection: Dictionary = gate.select_event(selection_rng, _exclusions_for(target_id))
	var selected: Dictionary = selection.get("event", {})
	_check(not selected.is_empty(), "targeted selection succeeds for the detached check")
	selected["fight_choice_id"] = "leave"
	(selected["choices"] as Array).clear()
	_check(gate.get_event_record(target_id) == canonical_snapshot, "mutating a selected record does not touch the catalog")
	_check(gate.get_catalog_events() == catalog_before, "catalog event list stays detached across selector use")

	var exhausted_rng := RandomNumberGenerator.new()
	exhausted_rng.seed = 5150
	var exhausted_state: int = exhausted_rng.state
	var exhausted: Dictionary = gate.select_event(exhausted_rng, _all_catalog_ids())
	_check(exhausted == {"ok": false, "event": {}}, "excluding every current ID refuses selection")
	_check(exhausted_rng.state == exhausted_state, "exhausted exclusions consume no RNG draws")

	for bad_exclusion: Variant in ["v3_stitchline_roadblock", 7, [1], [""], [null]]:
		var bad_rng := RandomNumberGenerator.new()
		bad_rng.seed = 5150
		var bad_state: int = bad_rng.state
		var bad_result: Dictionary = gate.select_event(bad_rng, bad_exclusion)
		_check(bad_result == {"ok": false, "event": {}}, "malformed exclusions refuse selection: " + str(bad_exclusion))
		_check(bad_rng.state == bad_state, "malformed exclusions consume no RNG draws: " + str(bad_exclusion))

	var plain_rng := RandomNumberGenerator.new()
	plain_rng.seed = 31337
	var plain: Dictionary = gate.select_event(plain_rng)
	var unknown_rng := RandomNumberGenerator.new()
	unknown_rng.seed = 31337
	var unknown: Dictionary = gate.select_event(unknown_rng, ["v3_unknown_future_crossroad"])
	_check(unknown == plain and unknown_rng.state == plain_rng.state, "unknown well-formed exclusion is harmless")
