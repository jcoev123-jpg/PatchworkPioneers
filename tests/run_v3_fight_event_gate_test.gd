extends SceneTree
## Deterministic headless test for RunV3FightEventGate and
## res://data/events/v3_fight_choice_events.json (Milestone V3-4).

const CATALOG_PATH := "res://data/events/v3_fight_choice_events.json"

const EXPECTED_EVENTS := {
	"v3_stitchline_roadblock": {
		"fight_choice_id": "break_barricade",
		"paid_choice_id": "pay_road_toll",
		"paid_outcome": {"gold": -14, "scraps": 0},
		"short_wallet": {"gold": 13, "scraps": 5},
		"exact_wallet": {"gold": 14, "scraps": 0},
		"funded_wallet": {"gold": 30, "scraps": 4},
	},
	"v3_frayed_bridge_watch": {
		"fight_choice_id": "hold_bridge",
		"paid_choice_id": "offer_thread",
		"paid_outcome": {"gold": 0, "scraps": -2},
		"short_wallet": {"gold": 25, "scraps": 1},
		"exact_wallet": {"gold": 0, "scraps": 2},
		"funded_wallet": {"gold": 30, "scraps": 4},
	},
	"v3_lanternless_ambush": {
		"fight_choice_id": "face_shadows",
		"paid_choice_id": "buy_lantern_pass",
		"paid_outcome": {"gold": -18, "scraps": 0},
		"short_wallet": {"gold": 17, "scraps": 5},
		"exact_wallet": {"gold": 18, "scraps": 0},
		"funded_wallet": {"gold": 30, "scraps": 4},
	},
	"v3_knotted_yarn_patrol": {
		"fight_choice_id": "untie_patrol",
		"paid_choice_id": "trade_yarn",
		"paid_outcome": {"gold": 0, "scraps": -1},
		"short_wallet": {"gold": 25, "scraps": 0},
		"exact_wallet": {"gold": 0, "scraps": 1},
		"funded_wallet": {"gold": 30, "scraps": 4},
	},
	"v3_buttonwall_checkpoint": {
		"fight_choice_id": "challenge_checkpoint",
		"paid_choice_id": "purchase_token",
		"paid_outcome": {"gold": -20, "scraps": 0},
		"short_wallet": {"gold": 19, "scraps": 5},
		"exact_wallet": {"gold": 20, "scraps": 0},
		"funded_wallet": {"gold": 30, "scraps": 4},
	},
}

var failures: Array[String] = []
var checks: int = 0
var catalog_doc: Dictionary = {}
var catalog_snapshot: Dictionary = {}


func _initialize() -> void:
	seed(73401)
	var expected_global_rng: int = randi()
	seed(73401)
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = 73401
	var initial_rng_state: int = run_rng.state

	_test_ac1_catalog_and_run_event_choice_compatibility(run_rng)
	_test_ac2_fight_paid_and_leave_receipts(run_rng)
	_test_ac3_affordability_recovery_replay_and_isolation(run_rng)
	_test_ac3_invalid_metadata_and_forgeries(run_rng)
	_test_ac4_determinism_rng_and_ownership_boundaries(run_rng)

	_check(catalog_doc == catalog_snapshot, "loaded catalog dictionary unchanged across all test flows")
	_check(run_rng.state == initial_rng_state, "seeded RandomNumberGenerator state unchanged across entire suite")
	_check(randi() == expected_global_rng, "global RNG untouched across entire suite")

	for failure in failures:
		printerr(failure)
	print("run_v3_fight_event_gate_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


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
		var num: float = value
		return is_finite(num) and floor(num) == num
	return false


func _matching_events(events: Array, event_id: String) -> Array:
	var matches: Array = []
	for item_raw: Variant in events:
		if item_raw is Dictionary and (item_raw as Dictionary).get("id") == event_id:
			matches.append(item_raw)
	return matches


func _test_ac1_catalog_and_run_event_choice_compatibility(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check(file != null, "v3_fight_choice_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(not text.strip_edges().is_empty(), "v3_fight_choice_events.json is non-empty")
	var parser := JSON.new()
	var parse_err := parser.parse(text)
	_check(parse_err == OK and parser.data is Dictionary, "v3_fight_choice_events.json parses as a JSON object")
	if parse_err != OK or not (parser.data is Dictionary):
		return
	catalog_doc = parser.data
	catalog_snapshot = catalog_doc.duplicate(true)
	var events_raw: Variant = catalog_doc.get("events")
	_check(events_raw is Array and not (events_raw as Array).is_empty(), "catalog has a non-empty events array")
	if not (events_raw is Array):
		return
	var events: Array = events_raw

	var gate_catalog := RunV3FightEventGate.new()
	_check(gate_catalog.is_catalog_valid(), "default RunV3FightEventGate validates shipped catalog")
	_check(not gate_catalog.is_valid() and not gate_catalog.is_claimed(),
		"unbound catalog gate is not a bound visit until prepared or opened")

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var matches: Array = _matching_events(events, event_id)
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
			"record has exact 5 top-level keys: " + event_id
		)
		var title: Variant = record.get("title")
		var description: Variant = record.get("description")
		_check(title is String and not String(title).strip_edges().is_empty(), "nonblank title: " + event_id)
		_check(description is String and not String(description).strip_edges().is_empty(), "nonblank description: " + event_id)
		_check(record.get("fight_choice_id") == spec["fight_choice_id"], "exact fight_choice_id metadata: " + event_id)

		var choices_raw: Variant = record.get("choices")
		_check(choices_raw is Array and (choices_raw as Array).size() == 3, "three choices on " + event_id)
		if not (choices_raw is Array) or (choices_raw as Array).size() != 3:
			continue
		var by_choice_id: Dictionary = {}
		for choice_raw: Variant in (choices_raw as Array):
			_check(choice_raw is Dictionary, "choice is Dictionary in " + event_id)
			if not (choice_raw is Dictionary):
				continue
			var choice: Dictionary = choice_raw
			_check(
				choice.size() == 3 and choice.has("id") and choice.has("text") and choice.has("outcome"),
				"choice has exact keys id/text/outcome in " + event_id
			)
			var cid: Variant = choice.get("id")
			var ctext: Variant = choice.get("text")
			var outcome_raw: Variant = choice.get("outcome")
			_check(cid is String and not String(cid).strip_edges().is_empty(), "nonblank choice id in " + event_id)
			_check(ctext is String and not String(ctext).strip_edges().is_empty(), "nonblank choice text in " + event_id)
			_check(not by_choice_id.has(cid), "unique choice id in " + event_id + ": " + str(cid))
			_check(outcome_raw is Dictionary, "outcome is Dictionary in " + event_id + "/" + str(cid))
			if outcome_raw is Dictionary:
				var outcome: Dictionary = outcome_raw
				_check(
					outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps")
					and _is_integral_json_number(outcome.get("gold"))
					and _is_integral_json_number(outcome.get("scraps")),
					"exact two-key integral {gold, scraps} outcome in " + event_id + "/" + str(cid)
				)
			by_choice_id[String(cid)] = choice

		var fight_cid: String = spec["fight_choice_id"]
		var paid_cid: String = spec["paid_choice_id"]
		var expected_paid: Dictionary = spec["paid_outcome"]
		_check(by_choice_id.has(fight_cid), "Fight choice present: " + event_id + "/" + fight_cid)
		_check(by_choice_id.has(paid_cid), "Paid choice present: " + event_id + "/" + paid_cid)
		_check(by_choice_id.has("leave"), "Leave choice present: " + event_id + "/leave")

		if by_choice_id.has(fight_cid):
			var fight_out: Dictionary = by_choice_id[fight_cid]["outcome"]
			_check(int(fight_out["gold"]) == 0 and int(fight_out["scraps"]) == 0,
				"Fight choice outcome is {gold: 0, scraps: 0}: " + event_id)
		if by_choice_id.has(paid_cid):
			var paid_out: Dictionary = by_choice_id[paid_cid]["outcome"]
			_check(
				int(paid_out["gold"]) == int(expected_paid["gold"])
				and int(paid_out["scraps"]) == int(expected_paid["scraps"]),
				"Paid choice outcome matches authored delta: " + event_id + "/" + paid_cid
			)
		if by_choice_id.has("leave"):
			var leave_out: Dictionary = by_choice_id["leave"]["outcome"]
			_check(int(leave_out["gold"]) == 0 and int(leave_out["scraps"]) == 0,
				"Leave choice outcome is {gold: 0, scraps: 0}: " + event_id)

		# Instantiate actual RunEventChoice directly for each authored record.
		var raw_choice_service := RunEventChoice.new(record)
		_check(raw_choice_service.is_valid() and not raw_choice_service.is_claimed(),
			"RunEventChoice.new(record) is valid and unclaimed for " + event_id)
		var raw_preview: Dictionary = raw_choice_service.preview_wallet_choices({"gold": 30, "scraps": 4})
		_check(raw_preview.get("ok") == true and raw_preview.get("event_id") == event_id,
			"RunEventChoice.preview_wallet_choices succeeds for " + event_id)
		var raw_claim: Dictionary = raw_choice_service.choose_with_wallet(fight_cid, {"gold": 5, "scraps": 2})
		_check(
			raw_claim == {"ok": true, "event_id": event_id, "choice_id": fight_cid, "wallet": {"gold": 5, "scraps": 2}}
			and raw_choice_service.is_claimed() and not raw_choice_service.is_valid(),
			"RunEventChoice.choose_with_wallet settles and latches directly for " + event_id
		)

	# Verify catalog order independence and additive future-record tolerance.
	var reordered_doc: Dictionary = catalog_doc.duplicate(true)
	(reordered_doc["events"] as Array).reverse()
	var reordered_gate := RunV3FightEventGate.new("v3_stitchline_roadblock", reordered_doc)
	_check(reordered_gate.is_catalog_valid() and reordered_gate.is_valid(),
		"reversed catalog order remains valid and admits named event")

	var appended_doc: Dictionary = catalog_doc.duplicate(true)
	(appended_doc["events"] as Array).append({
		"id": "v3_appended_sixth_crossroad",
		"title": "The Appended Crossroad",
		"description": "A well-formed future fight-capable event appended to the catalog.",
		"fight_choice_id": "stand_fast",
		"choices": [
			{"id": "stand_fast", "text": "Stand fast (Fight)", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "bribe_watch", "text": "Bribe the watch (-10 gold)", "outcome": {"gold": -10, "scraps": 0}},
			{"id": "leave", "text": "Leave quietly", "outcome": {"gold": 0, "scraps": 0}},
		],
	})
	var appended_gate := RunV3FightEventGate.new("v3_appended_sixth_crossroad", appended_doc)
	_check(appended_gate.is_catalog_valid() and appended_gate.is_valid(),
		"catalog with an appended well-formed future record validates and admits it")
	var appended_receipt: Dictionary = appended_gate.choose_with_wallet("stand_fast", {"gold": 7, "scraps": 1})
	_check(
		appended_receipt == {
			"ok": true,
			"event_id": "v3_appended_sixth_crossroad",
			"choice_id": "stand_fast",
			"wallet": {"gold": 7, "scraps": 1},
			"fight_request": {"node_type": "Fight"},
		},
		"appended future record settles pending Fight request cleanly"
	)
	_check(run_rng.state == rng_before, "AC1 checks consume zero seeded RNG")


func _test_ac2_fight_paid_and_leave_receipts(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var events: Array = catalog_doc.get("events", [])
	var factory_gate := RunV3FightEventGate.new()

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var fight_cid: String = spec["fight_choice_id"]
		var paid_cid: String = spec["paid_choice_id"]
		var paid_delta: Dictionary = spec["paid_outcome"]
		var funded_wallet: Dictionary = (spec["funded_wallet"] as Dictionary).duplicate(true)
		var exact_wallet: Dictionary = (spec["exact_wallet"] as Dictionary).duplicate(true)
		var short_wallet: Dictionary = (spec["short_wallet"] as Dictionary).duplicate(true)
		var record: Dictionary = _matching_events(events, event_id)[0].duplicate(true)

		# 1. Preview verification (both preview_choices and preview_wallet_choices).
		var preview_gate := RunV3FightEventGate.new(event_id)
		_check(preview_gate.is_valid() and not preview_gate.is_claimed(),
			"fresh gate by event_id is valid and unclaimed: " + event_id)
		_check(preview_gate.get_event_id() == event_id and preview_gate.get_fight_choice_id() == fight_cid,
			"gate exposes bound event_id and fight_choice_id: " + event_id)
		var preview_funded: Dictionary = preview_gate.preview_choices(funded_wallet)
		_check(
			preview_funded.get("ok") == true
			and preview_funded.get("event_id") == event_id
			and preview_funded.get("fight_choice_id") == fight_cid,
			"preview_choices succeeds on funded wallet: " + event_id
		)
		var preview_short: Dictionary = preview_gate.preview_choices(short_wallet)
		_check(preview_short.get("ok") == true, "preview_choices succeeds on one-unit-short wallet: " + event_id)
		for entry_raw: Variant in preview_funded.get("choices", []):
			var entry: Dictionary = entry_raw
			var cid: String = entry["choice_id"]
			if cid == fight_cid:
				_check(
					entry.get("gold_delta") == 0
					and entry.get("scraps_delta") == 0
					and entry.get("affordable") == true
					and entry.get("wallet") == funded_wallet
					and entry.get("fight_request") == {"node_type": "Fight"},
					"preview marks Fight choice affordable with {node_type: Fight}: " + event_id
				)
			elif cid == paid_cid:
				_check(
					entry.get("gold_delta") == int(paid_delta["gold"])
					and entry.get("scraps_delta") == int(paid_delta["scraps"])
					and entry.get("affordable") == true
					and entry.get("wallet") == {
						"gold": int(funded_wallet["gold"]) + int(paid_delta["gold"]),
						"scraps": int(funded_wallet["scraps"]) + int(paid_delta["scraps"]),
					}
					and entry.get("fight_request") == {},
					"preview marks paid choice affordable with empty fight_request: " + event_id
				)
			elif cid == "leave":
				_check(
					entry.get("gold_delta") == 0
					and entry.get("scraps_delta") == 0
					and entry.get("affordable") == true
					and entry.get("wallet") == funded_wallet
					and entry.get("fight_request") == {},
					"preview marks Leave choice affordable with empty fight_request: " + event_id
				)
		for entry_raw: Variant in preview_short.get("choices", []):
			var entry: Dictionary = entry_raw
			if entry["choice_id"] == paid_cid:
				_check(
					entry.get("affordable") == false and entry.get("wallet") == short_wallet,
					"preview marks paid choice unaffordable on one-unit-short wallet: " + event_id
				)
		_check(preview_gate.is_valid() and not preview_gate.is_claimed(),
			"preview_choices does not consume claim: " + event_id)

		# 2. Fight branch settlement (constructed from record Dictionary).
		var fight_gate := RunV3FightEventGate.new(record)
		var fight_wallet_in: Dictionary = {"gold": 0, "scraps": 0}
		var fight_receipt: Dictionary = fight_gate.choose_with_wallet(fight_cid, fight_wallet_in)
		_check(_receipt_shape_ok(fight_receipt), "Fight receipt has exact 5-key shape: " + event_id)
		_check(
			fight_receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": fight_cid,
				"wallet": {"gold": 0, "scraps": 0},
				"fight_request": {"node_type": "Fight"},
			}
			and _wallet_exact_int(fight_receipt.get("wallet"), 0, 0),
			"Fight choice returns pending {node_type: Fight} request and unchanged wallet: " + event_id
		)
		_check(
			fight_receipt["fight_request"].get("node_type") == "Fight"
			and fight_receipt["fight_request"].get("node_type") != "Elite"
			and fight_receipt["fight_request"].get("node_type") != "Boss",
			"Fight request is strictly Fight, never Elite or Boss: " + event_id
		)
		_check(fight_gate.is_claimed() and not fight_gate.is_valid(),
			"Fight claim latches visit: " + event_id)

		# 3. Paid alternative branch settlement at exact threshold and funded wallets.
		var paid_exact_gate := factory_gate.open_visit(event_id)
		_check(paid_exact_gate != null and paid_exact_gate.is_valid(),
			"open_visit creates valid visit for exact paid branch: " + event_id)
		var paid_exact_receipt: Dictionary = paid_exact_gate.choose_with_wallet(paid_cid, exact_wallet)
		_check(
			paid_exact_receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": paid_cid,
				"wallet": {"gold": 0, "scraps": 0},
				"fight_request": {},
			}
			and _wallet_exact_int(paid_exact_receipt.get("wallet"), 0, 0),
			"Paid choice at exact balance settles to {gold: 0, scraps: 0} with no fight_request: " + event_id
		)
		_check(paid_exact_gate.is_claimed() and not paid_exact_gate.is_valid(),
			"Paid exact claim latches visit: " + event_id)

		var paid_funded_gate := RunV3FightEventGate.new()
		_check(paid_funded_gate.prepare(record), "prepare(record) binds fresh gate: " + event_id)
		var expected_funded_after := {
			"gold": int(funded_wallet["gold"]) + int(paid_delta["gold"]),
			"scraps": int(funded_wallet["scraps"]) + int(paid_delta["scraps"]),
		}
		var paid_funded_receipt: Dictionary = paid_funded_gate.choose_with_wallet(paid_cid, funded_wallet)
		_check(
			paid_funded_receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": paid_cid,
				"wallet": expected_funded_after,
				"fight_request": {},
			}
			and _wallet_exact_int(
				paid_funded_receipt.get("wallet"),
				int(expected_funded_after["gold"]),
				int(expected_funded_after["scraps"])
			),
			"Paid choice with funded wallet debits exact amount once with no fight_request: " + event_id
		)

		# 4. Leave branch settlement on empty and funded wallets.
		var leave_gate := factory_gate.enter(record)
		_check(leave_gate != null and leave_gate.is_valid(), "enter(record) creates valid visit: " + event_id)
		var empty_wallet := {"gold": 0, "scraps": 0}
		var leave_receipt: Dictionary = leave_gate.choose_with_wallet("leave", empty_wallet)
		_check(
			leave_receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": "leave",
				"wallet": {"gold": 0, "scraps": 0},
				"fight_request": {},
			}
			and leave_gate.is_claimed() and not leave_gate.is_valid(),
			"Leave choice settles {gold: 0, scraps: 0} with no fight_request and latches visit: " + event_id
		)

	_check(run_rng.state == rng_before, "AC2 checks consume zero seeded RNG")


func _test_ac3_affordability_recovery_replay_and_isolation(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var fight_cid: String = spec["fight_choice_id"]
		var paid_cid: String = spec["paid_choice_id"]
		var short_wallet: Dictionary = (spec["short_wallet"] as Dictionary).duplicate(true)
		var exact_wallet: Dictionary = (spec["exact_wallet"] as Dictionary).duplicate(true)
		var empty_wallet := {"gold": 0, "scraps": 0}

		# 1. Insufficient gold/scraps on empty wallet and one-unit-short wallet rejects before any claim,
		#    then recovers on the SAME visit with Leave, Fight, or a funded wallet.
		var recover_to_leave := RunV3FightEventGate.new(event_id)
		var empty_refusal: Dictionary = recover_to_leave.choose_with_wallet(paid_cid, empty_wallet)
		_check(
			empty_refusal == {
				"ok": false,
				"event_id": "",
				"choice_id": "",
				"wallet": {"gold": 0, "scraps": 0},
				"fight_request": {},
			}
			and recover_to_leave.is_valid() and not recover_to_leave.is_claimed(),
			"empty wallet refuses paid choice without claiming visit: " + event_id
		)
		var short_refusal: Dictionary = recover_to_leave.choose_with_wallet(paid_cid, short_wallet)
		_check(
			short_refusal == {
				"ok": false,
				"event_id": "",
				"choice_id": "",
				"wallet": short_wallet,
				"fight_request": {},
			}
			and recover_to_leave.is_valid() and not recover_to_leave.is_claimed(),
			"one-unit-short wallet refuses paid choice without claiming visit: " + event_id
		)
		var leave_after_refusal: Dictionary = recover_to_leave.choose_with_wallet("leave", short_wallet)
		_check(
			leave_after_refusal == {
				"ok": true,
				"event_id": event_id,
				"choice_id": "leave",
				"wallet": short_wallet,
				"fight_request": {},
			}
			and recover_to_leave.is_claimed() and not recover_to_leave.is_valid(),
			"same visit recovers with free Leave after unaffordable paid preflight: " + event_id
		)

		var recover_to_fight := RunV3FightEventGate.new(event_id)
		_check(not recover_to_fight.choose_with_wallet(paid_cid, short_wallet)["ok"],
			"unaffordable paid preflight rejected before Fight recovery: " + event_id)
		var fight_after_refusal: Dictionary = recover_to_fight.choose_with_wallet(fight_cid, short_wallet)
		_check(
			fight_after_refusal == {
				"ok": true,
				"event_id": event_id,
				"choice_id": fight_cid,
				"wallet": short_wallet,
				"fight_request": {"node_type": "Fight"},
			}
			and recover_to_fight.is_claimed() and not recover_to_fight.is_valid(),
			"same visit recovers with Fight choice after unaffordable paid preflight: " + event_id
		)

		var recover_to_paid := RunV3FightEventGate.new(event_id)
		_check(not recover_to_paid.choose_with_wallet(paid_cid, short_wallet)["ok"],
			"unaffordable paid preflight rejected before funded retry: " + event_id)
		var paid_after_refusal: Dictionary = recover_to_paid.choose_with_wallet(paid_cid, exact_wallet)
		_check(
			paid_after_refusal == {
				"ok": true,
				"event_id": event_id,
				"choice_id": paid_cid,
				"wallet": {"gold": 0, "scraps": 0},
				"fight_request": {},
			}
			and recover_to_paid.is_claimed() and not recover_to_paid.is_valid(),
			"same visit recovers with exact paid choice after failed preflight: " + event_id
		)

		# 2. Wrong choice IDs and malformed/negative wallets reject without claiming, then recover.
		var bad_input_gate := RunV3FightEventGate.new(event_id)
		for bad_choice: Variant in ["unknown_choice", "", "   ", " " + fight_cid, fight_cid + " ", null, 42, ["leave"], {"id": "leave"}]:
			var bad_choice_res: Dictionary = bad_input_gate.choose_with_wallet(bad_choice, exact_wallet)
			_check(
				bad_choice_res == {
					"ok": false,
					"event_id": "",
					"choice_id": "",
					"wallet": exact_wallet,
					"fight_request": {},
				}
				and bad_input_gate.is_valid() and not bad_input_gate.is_claimed(),
				"wrong choice rejected without consuming visit: " + event_id + " / " + str(bad_choice)
			)
		for bad_wallet: Variant in [
			null,
			12,
			"wallet",
			[],
			{},
			{"gold": 20},
			{"scraps": 2},
			{"gold": 20, "scraps": 2, "extra": 1},
			{"gold": -1, "scraps": 2},
			{"gold": 20, "scraps": -1},
			{"gold": 20.0, "scraps": 2},
			{"gold": 20, "scraps": 2.0},
			{"gold": "20", "scraps": 2},
			{"gold": true, "scraps": 2},
		]:
			var bad_wallet_res: Dictionary = bad_input_gate.choose_with_wallet(fight_cid, bad_wallet)
			_check(
				bad_wallet_res == {
					"ok": false,
					"event_id": "",
					"choice_id": "",
					"wallet": {},
					"fight_request": {},
				}
				and bad_input_gate.is_valid() and not bad_input_gate.is_claimed(),
				"malformed/negative wallet rejected with empty wallet and no claim: " + event_id
			)
			var bad_preview: Dictionary = bad_input_gate.preview_choices(bad_wallet)
			_check(
				bad_preview == {"ok": false, "event_id": "", "fight_choice_id": "", "choices": []}
				and bad_input_gate.is_valid() and not bad_input_gate.is_claimed(),
				"preview_choices rejects malformed wallet cleanly: " + event_id
			)

		var recovered_after_bad_inputs: Dictionary = bad_input_gate.choose_with_wallet(fight_cid, exact_wallet)
		_check(
			recovered_after_bad_inputs.get("ok") == true
			and recovered_after_bad_inputs.get("fight_request") == {"node_type": "Fight"}
			and bad_input_gate.is_claimed(),
			"visit still settles cleanly after wrong-choice and malformed-wallet refusals: " + event_id
		)

		# 3. One-shot replay rejection across all branches after claim.
		for replay_choice: String in [fight_cid, paid_cid, "leave"]:
			var replay_res: Dictionary = bad_input_gate.choose_with_wallet(replay_choice, {"gold": 50, "scraps": 5})
			_check(
				replay_res == {
					"ok": false,
					"event_id": "",
					"choice_id": "",
					"wallet": {"gold": 50, "scraps": 5},
					"fight_request": {},
				}
				and bad_input_gate.is_claimed() and not bad_input_gate.is_valid(),
				"replay after claim rejected with no pending fight: " + event_id + "/" + replay_choice
			)
		_check(
			bad_input_gate.preview_choices({"gold": 50, "scraps": 5}) == {
				"ok": false, "event_id": "", "fight_choice_id": "", "choices": []
			}
			and bad_input_gate.preview_wallet_choices({"gold": 50, "scraps": 5}) == {
				"ok": false, "event_id": "", "choices": []
			},
			"previews fail closed after visit is claimed: " + event_id
		)
		_check(not bad_input_gate.prepare(event_id), "prepare() cannot reset or rebind a claimed gate: " + event_id)

	# 4. Deep-copy isolation of inputs and outputs.
	var caller_catalog: Dictionary = catalog_doc.duplicate(true)
	var caller_record: Dictionary = _matching_events(caller_catalog["events"], "v3_stitchline_roadblock")[0].duplicate(true)
	var record_snapshot: Dictionary = caller_record.duplicate(true)
	var caller_wallet := {"gold": 20, "scraps": 3}
	var isolation_gate := RunV3FightEventGate.new(caller_record, caller_catalog)
	caller_catalog["events"].clear()
	caller_record["fight_choice_id"] = "leave"
	caller_record["choices"].clear()
	caller_wallet["gold"] = 999
	_check(isolation_gate.get_event() == record_snapshot,
		"mutating caller catalog and record does not mutate bound gate event")
	var mutated_event_out: Dictionary = isolation_gate.get_event()
	mutated_event_out["fight_choice_id"] = "pay_road_toll"
	(mutated_event_out["choices"] as Array).clear()
	_check(isolation_gate.get_event() == record_snapshot,
		"mutating get_event() return value does not mutate gate state")

	var preview_out: Dictionary = isolation_gate.preview_choices({"gold": 20, "scraps": 3})
	(preview_out["choices"][0]["wallet"] as Dictionary)["gold"] = -999
	(preview_out["choices"][0]["fight_request"] as Dictionary)["node_type"] = "Boss"
	var settle_wallet := {"gold": 20, "scraps": 3}
	var receipt: Dictionary = isolation_gate.choose_with_wallet("break_barricade", settle_wallet)
	_check(
		receipt == {
			"ok": true,
			"event_id": "v3_stitchline_roadblock",
			"choice_id": "break_barricade",
			"wallet": {"gold": 20, "scraps": 3},
			"fight_request": {"node_type": "Fight"},
		},
		"mutating preview output does not affect subsequent settlement"
	)
	(receipt["wallet"] as Dictionary)["gold"] = 0
	(receipt["fight_request"] as Dictionary)["node_type"] = "Elite"
	_check(settle_wallet == {"gold": 20, "scraps": 3}, "mutating receipt wallet does not mutate caller wallet")
	var replay_after_mutation: Dictionary = isolation_gate.choose_with_wallet("break_barricade", settle_wallet)
	_check(
		replay_after_mutation == {
			"ok": false,
			"event_id": "",
			"choice_id": "",
			"wallet": {"gold": 20, "scraps": 3},
			"fight_request": {},
		},
		"mutating receipt fight_request/wallet does not leak into replay rejections"
	)

	_check(run_rng.state == rng_before, "AC3 affordability/recovery/isolation checks consume zero seeded RNG")


func _test_ac3_invalid_metadata_and_forgeries(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var base_events: Array = catalog_doc.get("events", [])
	var base_record: Dictionary = _matching_events(base_events, "v3_stitchline_roadblock")[0].duplicate(true)

	# 1. Malformed top-level catalog documents.
	for bad_doc: Variant in [
		false,
		10,
		"events",
		[],
		{},
		{"events": null},
		{"events": {}},
		{"events": []},
		{"events": [null]},
		{"events": base_events.duplicate(true), "extra_key": true},
	]:
		var gate := RunV3FightEventGate.new("v3_stitchline_roadblock", bad_doc)
		_check(
			not gate.is_catalog_valid()
			and not gate.is_valid()
			and gate.get_catalog_events().is_empty()
			and gate.open_visit("v3_stitchline_roadblock") == null
			and gate.choose_with_wallet("break_barricade", {"gold": 20, "scraps": 2}) == {
				"ok": false,
				"event_id": "",
				"choice_id": "",
				"wallet": {"gold": 20, "scraps": 2},
				"fight_request": {},
			},
			"malformed catalog document rejected: " + str(bad_doc)
		)

	# 2. Missing required event or duplicate event IDs in catalog.
	var missing_required_doc: Dictionary = catalog_doc.duplicate(true)
	(missing_required_doc["events"] as Array).pop_back()
	var missing_gate := RunV3FightEventGate.new("v3_stitchline_roadblock", missing_required_doc)
	_check(not missing_gate.is_catalog_valid() and not missing_gate.is_valid(),
		"catalog missing one of the five required events fails closed")

	var duplicate_event_doc: Dictionary = catalog_doc.duplicate(true)
	(duplicate_event_doc["events"] as Array).append(base_record.duplicate(true))
	var duplicate_gate := RunV3FightEventGate.new("v3_stitchline_roadblock", duplicate_event_doc)
	_check(not duplicate_gate.is_catalog_valid() and not duplicate_gate.is_valid(),
		"catalog with duplicate event IDs fails closed")

	# 3. Invalid fight_choice_id, duplicate choice IDs, forged outcomes/metadata on both
	#    record admission and catalog validation.
	var invalid_records: Array[Dictionary] = []

	var unoffered_fight := base_record.duplicate(true)
	unoffered_fight["fight_choice_id"] = "hold_bridge"
	invalid_records.append(unoffered_fight)

	var leave_as_fight := base_record.duplicate(true)
	leave_as_fight["fight_choice_id"] = "leave"
	invalid_records.append(leave_as_fight)

	var paid_as_fight := base_record.duplicate(true)
	paid_as_fight["fight_choice_id"] = "pay_road_toll"
	invalid_records.append(paid_as_fight)

	var blank_fight := base_record.duplicate(true)
	blank_fight["fight_choice_id"] = "   "
	invalid_records.append(blank_fight)

	var padded_fight := base_record.duplicate(true)
	padded_fight["fight_choice_id"] = " break_barricade "
	invalid_records.append(padded_fight)

	var missing_fight_key := base_record.duplicate(true)
	missing_fight_key.erase("fight_choice_id")
	invalid_records.append(missing_fight_key)

	var extra_top_key := base_record.duplicate(true)
	extra_top_key["node_type"] = "Elite"
	invalid_records.append(extra_top_key)

	var duplicate_choice_id := base_record.duplicate(true)
	duplicate_choice_id["choices"][1]["id"] = "break_barricade"
	invalid_records.append(duplicate_choice_id)

	var missing_leave_choice := base_record.duplicate(true)
	missing_leave_choice["choices"][2]["id"] = "retreat"
	invalid_records.append(missing_leave_choice)

	var two_choices_only := base_record.duplicate(true)
	(two_choices_only["choices"] as Array).pop_back()
	invalid_records.append(two_choices_only)

	var nonzero_fight_outcome := base_record.duplicate(true)
	nonzero_fight_outcome["choices"][0]["outcome"] = {"gold": -5, "scraps": 0}
	invalid_records.append(nonzero_fight_outcome)

	var nonzero_leave_outcome := base_record.duplicate(true)
	nonzero_leave_outcome["choices"][2]["outcome"] = {"gold": 5, "scraps": 0}
	invalid_records.append(nonzero_leave_outcome)

	var forged_paid_amount := base_record.duplicate(true)
	forged_paid_amount["choices"][1]["outcome"] = {"gold": -1, "scraps": 0}

	var positive_paid_amount := base_record.duplicate(true)
	positive_paid_amount["choices"][1]["outcome"] = {"gold": 14, "scraps": 0}
	invalid_records.append(positive_paid_amount)

	var extra_outcome_key := base_record.duplicate(true)
	extra_outcome_key["choices"][0]["outcome"] = {"gold": 0, "scraps": 0, "fight": true}
	invalid_records.append(extra_outcome_key)

	var fractional_outcome := base_record.duplicate(true)
	fractional_outcome["choices"][1]["outcome"] = {"gold": -14.5, "scraps": 0}
	invalid_records.append(fractional_outcome)

	var forged_title := base_record.duplicate(true)
	forged_title["title"] = "Forged Roadblock Title"

	var unknown_event_id := base_record.duplicate(true)
	unknown_event_id["id"] = "v3_forged_unknown_roadblock"

	var forged_known_records: Array[Dictionary] = [
		forged_paid_amount,
		forged_title,
		unknown_event_id,
	]

	var valid_factory := RunV3FightEventGate.new()
	for bad_rec: Dictionary in invalid_records + forged_known_records:
		var rec_before: Dictionary = bad_rec.duplicate(true)
		var direct_gate := RunV3FightEventGate.new(bad_rec)
		_check(
			not direct_gate.is_valid()
			and not direct_gate.is_claimed()
			and valid_factory.open_visit(bad_rec) == null,
			"forged/invalid event record rejected on direct visit admission"
		)
		var direct_res: Dictionary = direct_gate.choose_with_wallet("break_barricade", {"gold": 20, "scraps": 2})
		_check(
			direct_res == {
				"ok": false,
				"event_id": "",
				"choice_id": "",
				"wallet": {"gold": 20, "scraps": 2},
				"fight_request": {},
			}
			and bad_rec == rec_before,
			"rejected record cannot produce a Fight request or mutate caller record"
		)

		# Also test substituting the invalid/forged record in place of v3_stitchline_roadblock.
		var replaced_catalog: Dictionary = catalog_doc.duplicate(true)
		for idx in range((replaced_catalog["events"] as Array).size()):
			if replaced_catalog["events"][idx].get("id") == "v3_stitchline_roadblock":
				replaced_catalog["events"][idx] = bad_rec.duplicate(true)
		var cat_gate := RunV3FightEventGate.new("v3_frayed_bridge_watch", replaced_catalog)
		_check(
			not cat_gate.is_catalog_valid() and not cat_gate.is_valid(),
			"tampered catalog replacing required event with invalid/forged record fails closed"
		)

	for schema_bad_rec: Dictionary in invalid_records:
		var appended_bad_catalog: Dictionary = catalog_doc.duplicate(true)
		var appended_bad: Dictionary = schema_bad_rec.duplicate(true)
		appended_bad["id"] = "v3_appended_broken_crossroad"
		(appended_bad_catalog["events"] as Array).append(appended_bad)
		var appended_bad_gate := RunV3FightEventGate.new("v3_frayed_bridge_watch", appended_bad_catalog)
		_check(
			not appended_bad_gate.is_catalog_valid() and not appended_bad_gate.is_valid(),
			"catalog with malformed appended 6th record fails closed"
		)

	_check(run_rng.state == rng_before, "AC3 forgery/metadata checks consume zero seeded RNG")


func _test_ac4_determinism_rng_and_ownership_boundaries(run_rng: RandomNumberGenerator) -> void:
	# Verify that authoritative run objects (RunMap, CombatParty, CombatDeck) and RNG
	# remain completely untouched while preparing, previewing, and claiming across all 5 events.
	var map_rng := RandomNumberGenerator.new()
	map_rng.seed = 91005
	var run_map := RunMap.new()
	run_map.generate(map_rng)
	var first_floor_choices: Array[String] = run_map.get_legal_choices()
	_check(not first_floor_choices.is_empty(), "precondition: generated RunMap has floor-1 legal choices")
	run_map.choose_node(first_floor_choices[0])
	var map_route_before: Array[String] = run_map.get_route()
	var map_current_before: String = run_map.get_current_node_id()

	var party := CombatParty.new([
		{"id": "warden", "max_hp": 46},
		{"id": "seamstress", "max_hp": 38},
		{"id": "tinker", "max_hp": 42},
	])
	_check(party.is_valid(), "precondition: CombatParty is valid")
	var party_snapshot_before: Array[Dictionary] = party.get_heroes()

	var deck_rng := RandomNumberGenerator.new()
	deck_rng.seed = 91006
	var initial_cards: Array[String] = [
		"warden_strike",
		"warden_defend",
		"seamstress_strike",
		"seamstress_mend",
		"tinker_zap",
	]
	var deck := CombatDeck.new(initial_cards, deck_rng)
	_check(deck.draw_pile.size() == 5, "precondition: CombatDeck has 5 cards in draw_pile")
	var draw_before: Array[String] = deck.draw_pile.duplicate()
	var hand_before: Array[String] = deck.hand.duplicate()
	var discard_before: Array[String] = deck.discard_pile.duplicate()

	var trace_a: Array = _run_seeded_sequence(88123)
	var trace_b: Array = _run_seeded_sequence(88123)
	_check(not trace_a.is_empty() and trace_a == trace_b,
		"repeated seeded sequence produces identical previews, receipts and RNG state")

	_check(
		run_map.get_route() == map_route_before and run_map.get_current_node_id() == map_current_before,
		"RunMap route and current node remain untouched"
	)
	_check(party.get_heroes() == party_snapshot_before, "CombatParty remains untouched")
	_check(
		deck.draw_pile == draw_before
		and deck.hand == hand_before
		and deck.discard_pile == discard_before,
		"CombatDeck piles remain untouched"
	)
	_check(run_rng != null, "run_rng reference remains valid")


func _run_seeded_sequence(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var start_state: int = rng.state
	var wallet := {"gold": 40, "scraps": 4}
	var log_entries: Array = []
	var gate_factory := RunV3FightEventGate.new()
	_check(gate_factory.is_catalog_valid(), "seeded sequence factory catalog valid")

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var fight_cid: String = spec["fight_choice_id"]
		var paid_cid: String = spec["paid_choice_id"]

		var visit_paid := gate_factory.open_visit(event_id)
		var preview_paid: Dictionary = visit_paid.preview_choices(wallet)
		var receipt_paid: Dictionary = visit_paid.choose_with_wallet(paid_cid, wallet)
		wallet = receipt_paid["wallet"]

		var visit_fight := gate_factory.open_visit(event_id)
		var preview_fight: Dictionary = visit_fight.preview_choices(wallet)
		var receipt_fight: Dictionary = visit_fight.choose_with_wallet(fight_cid, wallet)
		var replay_fight: Dictionary = visit_fight.choose_with_wallet("leave", wallet)

		var visit_leave := gate_factory.open_visit(event_id)
		var receipt_leave: Dictionary = visit_leave.choose_with_wallet("leave", wallet)

		log_entries.append({
			"event_id": event_id,
			"preview_paid": preview_paid,
			"receipt_paid": receipt_paid,
			"preview_fight": preview_fight,
			"receipt_fight": receipt_fight,
			"replay_fight": replay_fight,
			"receipt_leave": receipt_leave,
			"rng_state": rng.state,
		})

	_check(rng.state == start_state, "seeded sequence consumes zero RNG draws")
	return log_entries
