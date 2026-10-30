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
	"v3_bellspool_picket": {
		"fight_choice_id": "ring_the_bells",
		"paid_choice_id": "pay_bell_toll",
		"paid_outcome": {"gold": -16, "scraps": 0},
		"short_wallet": {"gold": 15, "scraps": 5},
		"exact_wallet": {"gold": 16, "scraps": 0},
		"funded_wallet": {"gold": 30, "scraps": 4},
	},
}

const WAYSTATION_CATALOG_PATH := "res://data/events/v3_service_waystation_events.json"

const EXPECTED_WAYSTATION_EVENTS := {
	"v3_emberglass_campfire": {
		"title": "The Emberglass Hearth",
		"description": "Moth-winged lanterns surround a cracked brass firebox.",
		"service_choice_id": "light_the_embers",
		"service_kind": "Campfire",
		"paid_outcome": {"gold": 0, "scraps": -1},
		"trade_choice_id": "sell_cinders",
		"trade_outcome": {"gold": 12, "scraps": 0},
		"leave_choice_id": "leave",
		"choices": [
			{"id": "light_the_embers", "text": "Light the embers (spend 1 scrap, Campfire)", "outcome": {"gold": 0, "scraps": -1}},
			{"id": "sell_cinders", "text": "Sell cinders (gain 12 gold)", "outcome": {"gold": 12, "scraps": 0}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
		],
		"short_wallet": {"gold": 10, "scraps": 0},
		"exact_wallet": {"gold": 0, "scraps": 1},
		"funded_wallet": {"gold": 25, "scraps": 3},
	},
	"v3_threadmill_sewing_circle": {
		"title": "The Threadmill Loft",
		"description": "A huge brass needle wheel hauls moonlit cloth through a stitched room.",
		"service_choice_id": "borrow_spools",
		"service_kind": "SewingCircle",
		"paid_outcome": {"gold": -12, "scraps": 0},
		"trade_choice_id": "untie_scraps",
		"trade_outcome": {"gold": 0, "scraps": 2},
		"leave_choice_id": "leave",
		"choices": [
			{"id": "borrow_spools", "text": "Borrow spools (spend 12 gold, Sewing Circle)", "outcome": {"gold": -12, "scraps": 0}},
			{"id": "untie_scraps", "text": "Untie scraps (gain 2 scraps)", "outcome": {"gold": 0, "scraps": 2}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
		],
		"short_wallet": {"gold": 11, "scraps": 5},
		"exact_wallet": {"gold": 12, "scraps": 0},
		"funded_wallet": {"gold": 25, "scraps": 3},
	},
	"v3_inkblack_unpicker_van": {
		"title": "The Inkblack Unpicker Van",
		"description": "Silver scissors hang behind an oxblood caravan's velvet curtain.",
		"service_choice_id": "hire_unpicker",
		"service_kind": "Unpicker",
		"paid_outcome": {"gold": -10, "scraps": 0},
		"trade_choice_id": "sell_trim",
		"trade_outcome": {"gold": 0, "scraps": 1},
		"leave_choice_id": "leave",
		"choices": [
			{"id": "hire_unpicker", "text": "Hire unpicker (spend 10 gold, Unpicker)", "outcome": {"gold": -10, "scraps": 0}},
			{"id": "sell_trim", "text": "Sell trim (gain 1 scrap)", "outcome": {"gold": 0, "scraps": 1}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
		],
		"short_wallet": {"gold": 9, "scraps": 5},
		"exact_wallet": {"gold": 10, "scraps": 0},
		"funded_wallet": {"gold": 25, "scraps": 3},
	},
	"v3_briar_button_mending_bench": {
		"title": "The Briar-Button Hearth",
		"description": "A giant button kettle glows beside a bramble-wrapped quilt bench.",
		"service_choice_id": "fuel_button_fire",
		"service_kind": "Campfire",
		"paid_outcome": {"gold": 0, "scraps": -2},
		"trade_choice_id": "take_rivets",
		"trade_outcome": {"gold": 14, "scraps": 0},
		"leave_choice_id": "leave",
		"choices": [
			{"id": "fuel_button_fire", "text": "Fuel button fire (spend 2 scraps, Campfire)", "outcome": {"gold": 0, "scraps": -2}},
			{"id": "take_rivets", "text": "Take rivets (gain 14 gold)", "outcome": {"gold": 14, "scraps": 0}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
		],
		"short_wallet": {"gold": 20, "scraps": 1},
		"exact_wallet": {"gold": 0, "scraps": 2},
		"funded_wallet": {"gold": 25, "scraps": 3},
	},
	"v3_moonlace_darning_parlor": {
		"title": "The Moonlace Parlour",
		"description": "A button-eyed seam-keeper rents a lace loom below a plum lantern.",
		"service_choice_id": "sew_at_parlor",
		"service_kind": "SewingCircle",
		"paid_outcome": {"gold": 0, "scraps": -2},
		"trade_choice_id": "trade_lace",
		"trade_outcome": {"gold": 10, "scraps": 0},
		"leave_choice_id": "leave",
		"choices": [
			{"id": "sew_at_parlor", "text": "Sew at parlour (spend 2 scraps, Sewing Circle)", "outcome": {"gold": 0, "scraps": -2}},
			{"id": "trade_lace", "text": "Trade lace (gain 10 gold)", "outcome": {"gold": 10, "scraps": 0}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
		],
		"short_wallet": {"gold": 20, "scraps": 1},
		"exact_wallet": {"gold": 0, "scraps": 2},
		"funded_wallet": {"gold": 25, "scraps": 3},
	},
}

var failures: Array[String] = []
var checks: int = 0
var catalog_doc: Dictionary = {}
var catalog_snapshot: Dictionary = {}
var waystation_catalog_doc: Dictionary = {}
var waystation_catalog_snapshot: Dictionary = {}


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
	_test_ac1_seeded_selection_and_oracle_replay(run_rng)
	_test_ac2_selected_open_visit_and_receipt_branches(run_rng)
	_test_ac3_selection_refusals_and_isolation(run_rng)
	_test_ac_bellspool_picket_dedicated(run_rng)

	_test_ac1_waystation_catalog_and_choices(run_rng)
	_test_ac2_waystation_service_choices_and_previews(run_rng)
	_test_ac3_waystation_trades_leave_and_rejections(run_rng)
	_test_ac3_waystation_forgery_tampering_and_isolation(run_rng)

	_check(catalog_doc == catalog_snapshot, "loaded catalog dictionary unchanged across all test flows")
	_check(waystation_catalog_doc == waystation_catalog_snapshot, "loaded waystation catalog dictionary unchanged across all test flows")
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


func _waystation_receipt_shape_ok(receipt: Variant) -> bool:
	if typeof(receipt) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = receipt
	return (
		dict.size() == 5
		and typeof(dict.get("ok")) == TYPE_BOOL
		and typeof(dict.get("event_id")) == TYPE_STRING
		and typeof(dict.get("choice_id")) == TYPE_STRING
		and typeof(dict.get("wallet")) == TYPE_DICTIONARY
		and typeof(dict.get("service_request")) == TYPE_DICTIONARY
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
	# Remove a NAMED required event by ID (never by position: the catalog is shared
	# with other lanes and grows additively).
	var missing_required_doc: Dictionary = catalog_doc.duplicate(true)
	var missing_filtered: Array = []
	for ev_raw: Variant in (missing_required_doc["events"] as Array):
		if (ev_raw as Dictionary).get("id") != "v3_bellspool_picket":
			missing_filtered.append(ev_raw)
	missing_required_doc["events"] = missing_filtered
	var missing_gate := RunV3FightEventGate.new("v3_stitchline_roadblock", missing_required_doc)
	_check(not missing_gate.is_catalog_valid() and not missing_gate.is_valid(),
		"catalog missing one of the required events fails closed")

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
			"catalog with malformed appended record fails closed"
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



func _oracle_select_id(catalog_events: Array, excluded_ids: Variant, seed_value: int) -> Dictionary:
	var excluded_dict: Dictionary = {}
	if excluded_ids != null:
		if not (excluded_ids is Array):
			return {"ok": false, "id": "", "rng_state": 0}
		for value: Variant in (excluded_ids as Array):
			if not (value is String):
				return {"ok": false, "id": "", "rng_state": 0}
			var s: String = value
			if s.strip_edges().is_empty():
				return {"ok": false, "id": "", "rng_state": 0}
			excluded_dict[s] = true
	var eligible_ids: Array = []
	for item_raw: Variant in catalog_events:
		if item_raw is Dictionary:
			var id_val: Variant = (item_raw as Dictionary).get("id")
			if id_val is String and not excluded_dict.has(String(id_val)):
				eligible_ids.append(String(id_val))
	if eligible_ids.is_empty():
		return {"ok": false, "id": "", "rng_state": 0}
	eligible_ids.sort()
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = seed_value
	var picked_index: int = oracle_rng.randi_range(0, eligible_ids.size() - 1)
	return {
		"ok": true,
		"id": String(eligible_ids[picked_index]),
		"rng_state": oracle_rng.state,
	}


func _test_ac1_seeded_selection_and_oracle_replay(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "gate has valid catalog")
	_check(not gate.is_valid() and not gate.is_claimed(), "unbound gate is neither valid visit nor claimed")

	# Detached record: modifying returned record cannot alter catalog or future selections.
	var mut_rng := RandomNumberGenerator.new()
	mut_rng.seed = 445566
	var initial_sel: Dictionary = gate.select_event(mut_rng)
	_check(initial_sel.get("ok") == true and initial_sel.get("event") is Dictionary, "initial selection succeeds")
	var selected_event: Dictionary = initial_sel.get("event", {})
	var original_event_id: String = String(selected_event.get("id", ""))
	_check(not original_event_id.is_empty(), "selected event has non-empty ID")
	var original_snapshot: Dictionary = selected_event.duplicate(true)

	selected_event["title"] = "MUTATED_TITLE_ATTACK"
	selected_event["choices"] = []
	selected_event["id"] = "v3_mutated_id"
	var canonical_check: Dictionary = gate.get_event_record(original_event_id)
	_check(canonical_check == original_snapshot, "mutating returned record dictionary does not mutate catalog record")
	var mut_rng_replay := RandomNumberGenerator.new()
	mut_rng_replay.seed = 445566
	var second_sel: Dictionary = gate.select_event(mut_rng_replay)
	_check(second_sel.get("event") == original_snapshot, "mutating returned record dictionary does not mutate future offers")

	# Test multiple seeds against independent sorted-ID RNG oracle, verifying shipped-record membership and 2 identical-seed replays.
	var test_seeds: Array[int] = [10001, 20002, 30003, 40004, 50005, 99999]
	var catalog_events: Array[Dictionary] = gate.get_catalog_events()
	# Membership is checked against the canonical catalog itself (which must still
	# contain every originally required ID), never against a hard-coded total.
	var canonical_ids: Dictionary = {}
	for rec: Dictionary in catalog_events:
		canonical_ids[String(rec.get("id", ""))] = true
	for required_id: String in EXPECTED_EVENTS.keys():
		_check(canonical_ids.has(required_id), "catalog still lists required event: " + required_id)
	for s_val: int in test_seeds:
		var draw_rng := RandomNumberGenerator.new()
		draw_rng.seed = s_val
		var res: Dictionary = gate.select_event(draw_rng)
		_check(res.get("ok") == true, "select_event succeeds with seed: " + str(s_val))
		var picked: Dictionary = res.get("event", {})
		var picked_id: String = String(picked.get("id", ""))
		_check(canonical_ids.has(picked_id), "shipped-record membership proven: " + picked_id)
		_check(picked == gate.get_event_record(picked_id), "selected record equals get_event_record for: " + picked_id)

		var oracle_res: Dictionary = _oracle_select_id(catalog_events, null, s_val)
		_check(oracle_res.get("ok") == true, "oracle succeeds with seed: " + str(s_val))
		_check(picked_id == oracle_res.get("id"), "selected ID matches independent oracle ID for seed: " + str(s_val))
		_check(draw_rng.state == int(oracle_res.get("rng_state")), "RNG state matches oracle RNG state for seed: " + str(s_val))

		# Replay 1 with same seed from scratch.
		var replay_rng_1 := RandomNumberGenerator.new()
		replay_rng_1.seed = s_val
		var rep_1: Dictionary = gate.select_event(replay_rng_1)
		_check(rep_1 == res and replay_rng_1.state == draw_rng.state, "identical seed replay 1 matches exact result and state: " + str(s_val))

		# Replay 2 with same seed from scratch.
		var replay_rng_2 := RandomNumberGenerator.new()
		replay_rng_2.seed = s_val
		var rep_2: Dictionary = gate.select_event(replay_rng_2)
		_check(rep_2 == res and replay_rng_2.state == draw_rng.state, "identical seed replay 2 matches exact result and state: " + str(s_val))

	# Injected reordering fixture: reverse catalog events order.
	var reordered_doc: Dictionary = catalog_doc.duplicate(true)
	(reordered_doc["events"] as Array).reverse()
	var reordered_gate := RunV3FightEventGate.new(&"__omitted_event_target__", reordered_doc)
	_check(reordered_gate.is_catalog_valid(), "reordered catalog gate is catalog-valid")
	for s_val: int in test_seeds:
		var reorder_rng := RandomNumberGenerator.new()
		reorder_rng.seed = s_val
		var reorder_res: Dictionary = reordered_gate.select_event(reorder_rng)
		var oracle_res: Dictionary = _oracle_select_id(catalog_events, null, s_val)
		_check(
			reorder_res.get("ok") == true
			and reorder_res.get("event", {}).get("id") == oracle_res.get("id")
			and reorder_rng.state == int(oracle_res.get("rng_state")),
			"injected reversed-order fixture produces identical sorted-ID draw and RNG state for seed: " + str(s_val)
		)

	# Exclusions for each required named ID without assuming it is the nth item.
	for required_id: String in EXPECTED_EVENTS.keys():
		# 1. Exclude this specific ID: verify it is never drawn.
		for s_val: int in [111, 222, 333, 444]:
			var excl_rng := RandomNumberGenerator.new()
			excl_rng.seed = s_val
			var excl_res: Dictionary = gate.select_event(excl_rng, [required_id])
			_check(excl_res.get("ok") == true, "selection with excluded ID succeeds: " + required_id)
			_check(excl_res.get("event", {}).get("id") != required_id,
				"excluded ID is never returned: " + required_id + " (seed " + str(s_val) + ")")

		# 2. Exclude all OTHER catalog IDs: this named ID must be drawn deterministically.
		var all_others: Array = []
		for rec: Dictionary in catalog_events:
			var rid: String = String(rec.get("id", ""))
			if rid != required_id:
				all_others.append(rid)
		var isolate_rng := RandomNumberGenerator.new()
		isolate_rng.seed = 77777
		var iso_res: Dictionary = gate.select_event(isolate_rng, all_others)
		_check(iso_res.get("ok") == true and iso_res.get("event", {}).get("id") == required_id,
			"isolating required ID by excluding others selects it deterministically: " + required_id)

	# Unknown but well-formed excluded IDs are harmless and have zero effect on draw.
	var plain_rng := RandomNumberGenerator.new()
	plain_rng.seed = 88888
	var plain_res: Dictionary = gate.select_event(plain_rng, null)
	var unknown_rng := RandomNumberGenerator.new()
	unknown_rng.seed = 88888
	var unknown_res: Dictionary = gate.select_event(unknown_rng, ["v3_unknown_unrelated_future_event_id"])
	_check(
		unknown_res == plain_res and unknown_rng.state == plain_rng.state,
		"unknown well-formed exclusion is harmless and yields identical draw and RNG state"
	)

	# Duplicate and reordered exclusions produce identical results.
	var ord_rng := RandomNumberGenerator.new()
	ord_rng.seed = 99999
	var dup_rng := RandomNumberGenerator.new()
	dup_rng.seed = 99999
	var ord_res: Dictionary = gate.select_event(ord_rng, ["v3_stitchline_roadblock", "v3_frayed_bridge_watch"])
	var dup_res: Dictionary = gate.select_event(dup_rng, ["v3_frayed_bridge_watch", "v3_stitchline_roadblock", "v3_stitchline_roadblock"])
	_check(
		ord_res == dup_res and ord_rng.state == dup_rng.state,
		"duplicate and reordered exclusions produce identical selection and RNG state"
	)

	# Forward-compatible future catalog additions join the eligible rotation.
	var future_doc: Dictionary = catalog_doc.duplicate(true)
	(future_doc["events"] as Array).append({
		"id": "v3_future_crossroad_gate",
		"title": "Future Gate",
		"description": "A well-formed future crossroad.",
		"fight_choice_id": "future_fight",
		"choices": [
			{"id": "future_fight", "text": "Fight", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "future_paid", "text": "Pay (-10 gold)", "outcome": {"gold": -10, "scraps": 0}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
		],
	})
	var future_gate := RunV3FightEventGate.new(&"__omitted_event_target__", future_doc)
	_check(future_gate.is_catalog_valid(), "catalog with future addition validates")
	var all_standard_ids: Array = []
	for rec: Dictionary in catalog_events:
		all_standard_ids.append(rec.get("id"))
	var fut_rng := RandomNumberGenerator.new()
	fut_rng.seed = 54321
	var fut_res: Dictionary = future_gate.select_event(fut_rng, all_standard_ids)
	_check(
		fut_res.get("ok") == true and fut_res.get("event", {}).get("id") == "v3_future_crossroad_gate",
		"future catalog addition is eligible and selected when required IDs are excluded"
	)

	_check(run_rng.state == rng_before, "AC1 selection tests consume zero run_rng draws")


func _test_ac2_selected_open_visit_and_receipt_branches(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var gate := RunV3FightEventGate.new()
	var catalog_events: Array[Dictionary] = gate.get_catalog_events()

	for event_id: String in EXPECTED_EVENTS.keys():
		var spec: Dictionary = EXPECTED_EVENTS[event_id]
		var fight_cid: String = spec["fight_choice_id"]
		var paid_cid: String = spec["paid_choice_id"]
		var paid_delta: Dictionary = spec["paid_outcome"]
		var funded_wallet: Dictionary = (spec["funded_wallet"] as Dictionary).duplicate(true)
		var exact_wallet: Dictionary = (spec["exact_wallet"] as Dictionary).duplicate(true)
		var short_wallet: Dictionary = (spec["short_wallet"] as Dictionary).duplicate(true)

		# Deterministically select this specific named event record via select_event.
		var others: Array = []
		for rec: Dictionary in catalog_events:
			var rid: String = String(rec.get("id", ""))
			if rid != event_id:
				others.append(rid)
		var sel_rng := RandomNumberGenerator.new()
		sel_rng.seed = 65432
		var sel: Dictionary = gate.select_event(sel_rng, others)
		_check(sel.get("ok") == true, "select_event succeeded for: " + event_id)
		var selected_record: Dictionary = sel.get("event", {})
		_check(selected_record.get("id") == event_id, "selected record ID matches: " + event_id)

		# 1. Fight branch on authentic open_visit(selected.event).
		var visit_fight := gate.open_visit(selected_record)
		_check(visit_fight != null and visit_fight.is_valid(), "open_visit(selected.event) is valid for Fight branch: " + event_id)
		var preview_funded: Dictionary = visit_fight.preview_choices(funded_wallet)
		_check(
			preview_funded.get("ok") == true
			and preview_funded.get("event_id") == event_id
			and preview_funded.get("fight_choice_id") == fight_cid,
			"preview_choices succeeded on funded wallet for Fight: " + event_id
		)
		for entry_raw: Variant in preview_funded.get("choices", []):
			var entry: Dictionary = entry_raw
			if entry.get("choice_id") == fight_cid:
				_check(
					entry.get("gold_delta") == 0
					and entry.get("scraps_delta") == 0
					and entry.get("affordable") == true
					and entry.get("wallet") == funded_wallet
					and entry.get("fight_request") == {"node_type": "Fight"},
					"preview marks Fight choice affordable with node_type Fight: " + event_id
				)
		var receipt_fight: Dictionary = visit_fight.choose_with_wallet(fight_cid, funded_wallet)
		_check(
			receipt_fight == {
				"ok": true,
				"event_id": event_id,
				"choice_id": fight_cid,
				"wallet": funded_wallet,
				"fight_request": {"node_type": "Fight"},
			},
			"Fight choice settles {node_type: Fight} without wallet charge: " + event_id
		)
		_check(visit_fight.is_claimed() and not visit_fight.is_valid(), "Fight choice latches visit: " + event_id)
		var double_claim: Dictionary = visit_fight.choose_with_wallet("leave", funded_wallet)
		_check(double_claim.get("ok") == false and double_claim.get("fight_request") == {},
			"double claim on Fight visit fails closed: " + event_id)

		# 2. Paid escape branch on authentic open_visit(selected.event).
		# 2a. Insufficient funds preflight refusal and recovery.
		var visit_paid_short := gate.open_visit(selected_record)
		_check(visit_paid_short != null and visit_paid_short.is_valid(), "open_visit valid for short wallet: " + event_id)
		var short_refusal: Dictionary = visit_paid_short.choose_with_wallet(paid_cid, short_wallet)
		_check(
			short_refusal == {
				"ok": false,
				"event_id": "",
				"choice_id": "",
				"wallet": short_wallet,
				"fight_request": {},
			}
			and visit_paid_short.is_valid() and not visit_paid_short.is_claimed(),
			"insufficient-funds paid choice refused without claiming visit: " + event_id
		)
		var recover_leave: Dictionary = visit_paid_short.choose_with_wallet("leave", short_wallet)
		_check(
			recover_leave == {
				"ok": true,
				"event_id": event_id,
				"choice_id": "leave",
				"wallet": short_wallet,
				"fight_request": {},
			}
			and visit_paid_short.is_claimed() and not visit_paid_short.is_valid(),
			"short-wallet visit recovers on free Leave and latches: " + event_id
		)

		# 2b. Exact wallet paid escape.
		var visit_paid_exact := gate.open_visit(selected_record)
		var exact_receipt: Dictionary = visit_paid_exact.choose_with_wallet(paid_cid, exact_wallet)
		_check(
			exact_receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": paid_cid,
				"wallet": {"gold": 0, "scraps": 0},
				"fight_request": {},
			}
			and visit_paid_exact.is_claimed() and not visit_paid_exact.is_valid(),
			"exact wallet paid choice debits to 0/0 with empty fight_request: " + event_id
		)

		# 2c. Funded wallet paid escape.
		var visit_paid_funded := gate.open_visit(selected_record)
		var expected_funded_after := {
			"gold": int(funded_wallet["gold"]) + int(paid_delta["gold"]),
			"scraps": int(funded_wallet["scraps"]) + int(paid_delta["scraps"]),
		}
		var funded_receipt: Dictionary = visit_paid_funded.choose_with_wallet(paid_cid, funded_wallet)
		_check(
			funded_receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": paid_cid,
				"wallet": expected_funded_after,
				"fight_request": {},
			}
			and visit_paid_funded.is_claimed() and not visit_paid_funded.is_valid(),
			"funded paid choice debits printed cost with empty fight_request: " + event_id
		)

		# 3. Leave branch on authentic open_visit(selected.event).
		var visit_leave := gate.open_visit(selected_record)
		var empty_wallet := {"gold": 0, "scraps": 0}
		var leave_receipt: Dictionary = visit_leave.choose_with_wallet("leave", empty_wallet)
		_check(
			leave_receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": "leave",
				"wallet": {"gold": 0, "scraps": 0},
				"fight_request": {},
			}
			and visit_leave.is_claimed() and not visit_leave.is_valid(),
			"Leave choice changes nothing, returns empty fight_request and latches: " + event_id
		)

	_check(run_rng.state == rng_before, "AC2 tests consume zero run_rng draws")


func _test_ac3_selection_refusals_and_isolation(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "factory gate is catalog-valid")

	# Prepare an active bound visit to prove refusals do not mutate it.
	var bound_visit := gate.open_visit("v3_stitchline_roadblock")
	_check(bound_visit != null and bound_visit.is_valid() and not bound_visit.is_claimed(), "bound visit ready")
	var bound_id_before: String = bound_visit.get_event_id()
	var bound_fight_id_before: String = bound_visit.get_fight_choice_id()
	var bound_event_before: Dictionary = bound_visit.get_event()

	var caller_wallet := {"gold": 33, "scraps": 5}
	var wallet_snapshot := caller_wallet.duplicate(true)
	var catalog_snapshot_events := gate.get_catalog_events()

	var probe_rng := RandomNumberGenerator.new()
	probe_rng.seed = 551122
	var probe_rng_state: int = probe_rng.state

	seed(73401)
	var expected_global_rng: int = randi()
	seed(73401)

	# 1. Missing / wrong RNG values fail closed.
	var bad_rngs: Array = [null, 0, 42, 3.14, "rng", {}, [], RefCounted.new()]
	for bad_rng: Variant in bad_rngs:
		var bad_sel: Dictionary = gate.select_event(bad_rng)
		_check(
			bad_sel == {"ok": false, "event": {}},
			"wrong/missing RNG rejects with empty event: " + str(bad_rng)
		)
		_check(probe_rng.state == probe_rng_state, "probe RNG unmutated by wrong RNG rejection")
		_check(randi() == expected_global_rng, "global RNG unmutated by wrong RNG rejection")
		seed(73401)
		_check(caller_wallet == wallet_snapshot, "caller wallet unmutated by wrong RNG rejection")
		_check(
			bound_visit.is_valid()
			and not bound_visit.is_claimed()
			and bound_visit.get_event_id() == bound_id_before
			and bound_visit.get_fight_choice_id() == bound_fight_id_before
			and bound_visit.get_event() == bound_event_before,
			"bound visit completely unmutated by wrong RNG rejection"
		)

	# 2. Malformed exclusions fail closed without drawing RNG.
	var bad_exclusions: Array = [
		"v3_stitchline_roadblock",
		123,
		4.5,
		{},
		true,
		false,
		[1],
		[null],
		[{}],
		[true],
		[""],
		["   "],
		[["v3_stitchline_roadblock"]],
	]
	for bad_excl: Variant in bad_exclusions:
		var st_before: int = probe_rng.state
		var bad_sel: Dictionary = gate.select_event(probe_rng, bad_excl)
		_check(
			bad_sel == {"ok": false, "event": {}},
			"malformed exclusions rejects with empty event: " + str(bad_excl)
		)
		_check(probe_rng.state == st_before, "RNG state untouched by malformed exclusion rejection")
		_check(randi() == expected_global_rng, "global RNG untouched by malformed exclusion rejection")
		seed(73401)
		_check(caller_wallet == wallet_snapshot, "caller wallet untouched by malformed exclusion rejection")
		_check(bound_visit.is_valid() and not bound_visit.is_claimed(), "bound visit untouched by malformed exclusion")

	# 3. Exhausted eligible events (all catalog events excluded) fails closed without drawing RNG.
	var all_ids: Array = []
	for rec: Dictionary in catalog_snapshot_events:
		all_ids.append(rec.get("id"))
	var st_before_exh: int = probe_rng.state
	var exh_sel: Dictionary = gate.select_event(probe_rng, all_ids)
	_check(
		exh_sel == {"ok": false, "event": {}},
		"exhausted catalog exclusions rejects with empty event"
	)
	_check(probe_rng.state == st_before_exh, "RNG state untouched by exhausted exclusions rejection")
	_check(randi() == expected_global_rng, "global RNG untouched by exhausted exclusions rejection")
	seed(73401)

	# 4. Invalid catalog rejects selection.
	var bad_docs: Array = [
		false,
		99,
		"catalog",
		[],
		{},
		{"events": null},
		{"events": []},
		{"events": [null]},
	]
	for bad_doc: Variant in bad_docs:
		var bad_gate := RunV3FightEventGate.new(&"__omitted_event_target__", bad_doc)
		_check(not bad_gate.is_catalog_valid(), "bad doc is catalog invalid: " + str(bad_doc))
		var st_before_bad: int = probe_rng.state
		var bad_cat_sel: Dictionary = bad_gate.select_event(probe_rng)
		_check(
			bad_cat_sel == {"ok": false, "event": {}},
			"invalid catalog rejects select_event with empty event: " + str(bad_doc)
		)
		_check(probe_rng.state == st_before_bad, "RNG state untouched by invalid catalog rejection")
		_check(randi() == expected_global_rng, "global RNG untouched by invalid catalog rejection")
		seed(73401)

	# 5. Altered / forged selected records fail closed on open_visit() and enter() (returning null).
	var valid_sel_rng := RandomNumberGenerator.new()
	valid_sel_rng.seed = 332211
	var genuine_sel: Dictionary = gate.select_event(valid_sel_rng)
	_check(genuine_sel.get("ok") == true, "fresh genuine selection succeeds")
	var auth_rec: Dictionary = genuine_sel.get("event", {})

	var forgeries: Array[Dictionary] = []
	var forged_title := auth_rec.duplicate(true)
	forged_title["title"] = "Forged Event Title"
	forgeries.append(forged_title)

	var forged_desc := auth_rec.duplicate(true)
	forged_desc["description"] = "Forged Event Description"
	forgeries.append(forged_desc)

	var forged_fight_cid := auth_rec.duplicate(true)
	forged_fight_cid["fight_choice_id"] = "leave"
	forgeries.append(forged_fight_cid)

	var forged_fight_outcome := auth_rec.duplicate(true)
	forged_fight_outcome["choices"][0]["outcome"] = {"gold": -10, "scraps": 0}
	forgeries.append(forged_fight_outcome)

	var forged_paid_outcome := auth_rec.duplicate(true)
	forged_paid_outcome["choices"][1]["outcome"] = {"gold": 0, "scraps": 0}
	forgeries.append(forged_paid_outcome)

	var forged_extra_key := auth_rec.duplicate(true)
	forged_extra_key["node_type"] = "Boss"
	forgeries.append(forged_extra_key)

	var forged_unknown_id := auth_rec.duplicate(true)
	forged_unknown_id["id"] = "v3_forged_unknown_fight_event"
	forgeries.append(forged_unknown_id)

	for forged_rec: Dictionary in forgeries:
		var st_before_forgery: int = probe_rng.state
		var v_open := gate.open_visit(forged_rec)
		var v_enter := gate.enter(forged_rec)
		var v_new := RunV3FightEventGate.new(forged_rec)
		_check(v_open == null, "open_visit rejects forged record: " + str(forged_rec.get("id")))
		_check(v_enter == null, "enter rejects forged record: " + str(forged_rec.get("id")))
		_check(not v_new.is_valid(), "new(forged) is not a valid visit: " + str(forged_rec.get("id")))
		_check(probe_rng.state == st_before_forgery, "probe RNG state unmutated by forged admission rejection")
		_check(randi() == expected_global_rng, "global RNG unmutated by forged admission rejection")
		seed(73401)
		_check(caller_wallet == wallet_snapshot, "caller wallet unmutated by forged admission rejection")
		_check(bound_visit.is_valid() and not bound_visit.is_claimed(), "bound visit unmutated by forged admission rejection")

	# 6. Prove the bound visit settles cleanly and latches after all previous rejections.
	var bound_claim: Dictionary = bound_visit.choose_with_wallet("break_barricade", caller_wallet)
	_check(
		bound_claim == {
			"ok": true,
			"event_id": "v3_stitchline_roadblock",
			"choice_id": "break_barricade",
			"wallet": wallet_snapshot,
			"fight_request": {"node_type": "Fight"},
		},
		"bound visit settles successfully and produces Fight request after all rejections"
	)
	_check(bound_visit.is_claimed() and not bound_visit.is_valid(), "bound visit latches after successful settlement")
	_check(caller_wallet == wallet_snapshot, "caller wallet argument unmutated by settlement")
	_check(gate.get_catalog_events() == catalog_snapshot_events, "catalog events snapshot unmutated")
	_check(run_rng.state == rng_before, "AC3 tests consume zero run_rng draws")


func _test_ac_bellspool_picket_dedicated(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var gate := RunV3FightEventGate.new()
	_check(gate.is_catalog_valid(), "bellspool test: catalog is valid")

	# 1. AC1: Authoring and schema verification of v3_bellspool_picket
	var record: Dictionary = gate.get_event_record("v3_bellspool_picket")
	_check(not record.is_empty(), "v3_bellspool_picket record exists in catalog")
	_check(record.get("id") == "v3_bellspool_picket", "exact event ID v3_bellspool_picket")
	_check(record.get("title") == "The Bellspool Picket", "exact title The Bellspool Picket")
	_check(
		record.get("description") == "A chain of oversized brass bells and thread-wrapped spools blocks the moonlit lane; doll sentries turn as one when the bells ring.",
		"exact description byte-for-byte"
	)
	_check(record.get("fight_choice_id") == "ring_the_bells", "exact fight_choice_id ring_the_bells")
	var choices_raw: Variant = record.get("choices")
	_check(choices_raw is Array and (choices_raw as Array).size() == 3, "exact 3 choices in authored order")
	if choices_raw is Array and (choices_raw as Array).size() == 3:
		var choices: Array = choices_raw
		_check(
			choices[0].get("id") == "ring_the_bells"
			and choices[0].get("text") == "Ring the bellspool and face the sentries (Fight)"
			and int(choices[0].get("outcome", {}).get("gold")) == 0
			and int(choices[0].get("outcome", {}).get("scraps")) == 0,
			"choice 0 is ring_the_bells fight choice"
		)
		_check(
			choices[1].get("id") == "pay_bell_toll"
			and choices[1].get("text") == "Pay the bell toll (spend 16 gold)"
			and int(choices[1].get("outcome", {}).get("gold")) == -16
			and int(choices[1].get("outcome", {}).get("scraps")) == 0,
			"choice 1 is pay_bell_toll paid choice costing 16 gold"
		)
		_check(
			choices[2].get("id") == "leave"
			and choices[2].get("text") == "Retreat along the quiet seam (Leave)"
			and int(choices[2].get("outcome", {}).get("gold")) == 0
			and int(choices[2].get("outcome", {}).get("scraps")) == 0,
			"choice 2 is leave retreat choice"
		)

	# 2. AC2: Boundary affordability previews at 15 and 16 gold
	var visit_preview_15 := gate.open_visit("v3_bellspool_picket")
	_check(visit_preview_15 != null and visit_preview_15.is_valid(), "visit_preview_15 opened successfully")
	var preview_15: Dictionary = visit_preview_15.preview_choices({"gold": 15, "scraps": 0})
	_check(preview_15.get("ok") == true, "preview_choices succeeds at 15 gold")
	var p15_choices: Array = preview_15.get("choices", [])
	_check(p15_choices.size() == 3, "preview_15 has 3 choices")
	for entry_raw: Variant in p15_choices:
		var entry: Dictionary = entry_raw
		var cid: String = String(entry.get("choice_id", ""))
		if cid == "ring_the_bells":
			_check(
				entry.get("affordable") == true
				and entry.get("wallet") == {"gold": 15, "scraps": 0}
				and entry.get("fight_request") == {"node_type": "Fight"},
				"15 gold preview: ring_the_bells affordable with fight_request"
			)
		elif cid == "pay_bell_toll":
			_check(
				entry.get("affordable") == false
				and entry.get("wallet") == {"gold": 15, "scraps": 0}
				and entry.get("fight_request") == {},
				"15 gold preview: pay_bell_toll unaffordable without fight_request"
			)
		elif cid == "leave":
			_check(
				entry.get("affordable") == true
				and entry.get("wallet") == {"gold": 15, "scraps": 0}
				and entry.get("fight_request") == {},
				"15 gold preview: leave affordable without fight_request"
			)
	var short_res: Dictionary = visit_preview_15.choose_with_wallet("pay_bell_toll", {"gold": 15, "scraps": 0})
	_check(
		short_res == {
			"ok": false,
			"event_id": "",
			"choice_id": "",
			"wallet": {"gold": 15, "scraps": 0},
			"fight_request": {},
		},
		"15 gold paid choice refused without mutating wallet or issuing fight_request"
	)
	_check(visit_preview_15.is_valid() and not visit_preview_15.is_claimed(), "visit remains open after 15 gold refusal")

	# At 16 gold: preview and successful payment to 0
	var visit_preview_16 := gate.open_visit("v3_bellspool_picket")
	_check(visit_preview_16 != null and visit_preview_16.is_valid(), "visit_preview_16 opened successfully")
	var preview_16: Dictionary = visit_preview_16.preview_choices({"gold": 16, "scraps": 0})
	_check(preview_16.get("ok") == true, "preview_choices succeeds at 16 gold")
	for entry_raw: Variant in preview_16.get("choices", []):
		var entry: Dictionary = entry_raw
		if entry.get("choice_id") == "pay_bell_toll":
			_check(
				entry.get("affordable") == true
				and entry.get("wallet") == {"gold": 0, "scraps": 0}
				and entry.get("fight_request") == {},
				"16 gold preview: pay_bell_toll affordable with resulting 0/0 wallet"
			)
	var exact_res: Dictionary = visit_preview_16.choose_with_wallet("pay_bell_toll", {"gold": 16, "scraps": 0})
	_check(
		exact_res == {
			"ok": true,
			"event_id": "v3_bellspool_picket",
			"choice_id": "pay_bell_toll",
			"wallet": {"gold": 0, "scraps": 0},
			"fight_request": {},
		},
		"16 gold paid choice succeeds to exactly 0 gold with empty fight_request"
	)
	_check(visit_preview_16.is_claimed() and not visit_preview_16.is_valid(), "exact paid choice latches visit")

	# 3. AC2: Fresh visit one-claim receipts
	# Fresh visit: Fight choice
	var visit_fight := gate.open_visit("v3_bellspool_picket")
	var wallet_for_fight := {"gold": 22, "scraps": 3}
	var fight_receipt: Dictionary = visit_fight.choose_with_wallet("ring_the_bells", wallet_for_fight)
	_check(
		fight_receipt == {
			"ok": true,
			"event_id": "v3_bellspool_picket",
			"choice_id": "ring_the_bells",
			"wallet": {"gold": 22, "scraps": 3},
			"fight_request": {"node_type": "Fight"},
		},
		"ring_the_bells returns ONLY detached {node_type: Fight} and unchanged wallet"
	)
	_check(visit_fight.is_claimed() and not visit_fight.is_valid(), "fight choice latches visit")
	var repeat_fight: Dictionary = visit_fight.choose_with_wallet("leave", wallet_for_fight)
	_check(repeat_fight.get("ok") == false and repeat_fight.get("fight_request") == {}, "repeat claim rejected")

	# Fresh visit: Leave choice
	var visit_leave := gate.open_visit("v3_bellspool_picket")
	var wallet_for_leave := {"gold": 12, "scraps": 2}
	var leave_receipt: Dictionary = visit_leave.choose_with_wallet("leave", wallet_for_leave)
	_check(
		leave_receipt == {
			"ok": true,
			"event_id": "v3_bellspool_picket",
			"choice_id": "leave",
			"wallet": {"gold": 12, "scraps": 2},
			"fight_request": {},
		},
		"leave choice returns empty fight_request and unchanged wallet"
	)
	_check(visit_leave.is_claimed() and not visit_leave.is_valid(), "leave choice latches visit")

	# 4. AC3: Seeded selection and exclusions
	var excl_rng := RandomNumberGenerator.new()
	excl_rng.seed = 80808
	for _i in range(50):
		var sel_excl: Dictionary = gate.select_event(excl_rng, ["v3_bellspool_picket"])
		_check(sel_excl.get("ok") == true, "select_event succeeds with exclusion")
		_check(sel_excl.get("event", {}).get("id") != "v3_bellspool_picket", "excluded bellspool never selected")

	# Exclude all OTHER events to select bellspool deterministically
	var all_other_ids: Array = []
	for rec: Dictionary in gate.get_catalog_events():
		var rid: String = String(rec.get("id", ""))
		if rid != "v3_bellspool_picket":
			all_other_ids.append(rid)
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = 90909
	var sel_bell: Dictionary = gate.select_event(pick_rng, all_other_ids)
	_check(
		sel_bell.get("ok") == true and sel_bell.get("event", {}).get("id") == "v3_bellspool_picket",
		"isolating bellspool selects it deterministically"
	)
	var expected_draw_rng := RandomNumberGenerator.new()
	expected_draw_rng.seed = 90909
	expected_draw_rng.randi_range(0, 0)
	_check(pick_rng.state == expected_draw_rng.state, "selection consumes exactly 1 draw from 1 eligible option")

	# 5. AC3: Tampered metadata / forgery rejections
	var bell_base: Dictionary = record.duplicate(true)

	var tampered_cases: Array[Dictionary] = []
	var t_paid_as_fight := bell_base.duplicate(true)
	t_paid_as_fight["fight_choice_id"] = "pay_bell_toll"
	tampered_cases.append(t_paid_as_fight)

	var t_leave_as_fight := bell_base.duplicate(true)
	t_leave_as_fight["fight_choice_id"] = "leave"
	tampered_cases.append(t_leave_as_fight)

	var t_unknown_fight := bell_base.duplicate(true)
	t_unknown_fight["fight_choice_id"] = "ring_the_gong"
	tampered_cases.append(t_unknown_fight)

	var t_forged_paid := bell_base.duplicate(true)
	t_forged_paid["choices"][1]["outcome"] = {"gold": -10, "scraps": 0}
	tampered_cases.append(t_forged_paid)

	var t_forged_fight := bell_base.duplicate(true)
	t_forged_fight["choices"][0]["outcome"] = {"gold": -5, "scraps": 0}
	tampered_cases.append(t_forged_fight)

	var t_forged_leave := bell_base.duplicate(true)
	t_forged_leave["choices"][2]["outcome"] = {"gold": 5, "scraps": 0}
	tampered_cases.append(t_forged_leave)

	for bad_rec: Dictionary in tampered_cases:
		var bad_gate := RunV3FightEventGate.new(bad_rec)
		_check(not bad_gate.is_valid() and not bad_gate.is_claimed(), "tampered bellspool record rejected on new()")
		_check(gate.open_visit(bad_rec) == null, "tampered bellspool record rejected on open_visit()")
		var replaced_cat: Dictionary = catalog_doc.duplicate(true)
		for idx in range((replaced_cat["events"] as Array).size()):
			if replaced_cat["events"][idx].get("id") == "v3_bellspool_picket":
				replaced_cat["events"][idx] = bad_rec.duplicate(true)
		var cat_gate := RunV3FightEventGate.new("v3_stitchline_roadblock", replaced_cat)
		_check(not cat_gate.is_catalog_valid(), "catalog with tampered bellspool fails validation")

	# Missing bellspool from catalog fails closed
	var missing_bell_cat: Dictionary = catalog_doc.duplicate(true)
	var filtered_events: Array = []
	for ev_raw: Variant in missing_bell_cat["events"]:
		if (ev_raw as Dictionary).get("id") != "v3_bellspool_picket":
			filtered_events.append(ev_raw)
	missing_bell_cat["events"] = filtered_events
	var missing_bell_gate := RunV3FightEventGate.new("v3_stitchline_roadblock", missing_bell_cat)
	_check(not missing_bell_gate.is_catalog_valid(), "catalog missing required v3_bellspool_picket fails validation")

	_check(run_rng.state == rng_before, "dedicated bellspool checks consume zero run_rng draws")


func _test_ac1_waystation_catalog_and_choices(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var file := FileAccess.open(WAYSTATION_CATALOG_PATH, FileAccess.READ)
	_check(file != null, "v3_service_waystation_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(not text.strip_edges().is_empty(), "v3_service_waystation_events.json is non-empty")
	var parser := JSON.new()
	var parse_err := parser.parse(text)
	_check(parse_err == OK and parser.data is Dictionary, "v3_service_waystation_events.json parses as a JSON object")
	if parse_err != OK or not (parser.data is Dictionary):
		return
	waystation_catalog_doc = parser.data
	waystation_catalog_snapshot = waystation_catalog_doc.duplicate(true)
	var events_raw: Variant = waystation_catalog_doc.get("events")
	_check(events_raw is Array and not (events_raw as Array).is_empty(), "waystation catalog has a non-empty events array")
	if not (events_raw is Array):
		return
	var events: Array = events_raw

	var gate_catalog := RunV3ServiceWaystationEventGate.new()
	_check(gate_catalog.is_catalog_valid(), "default RunV3ServiceWaystationEventGate validates shipped catalog")
	_check(not gate_catalog.is_valid() and not gate_catalog.is_claimed(),
		"unbound waystation catalog gate is not a bound visit until prepared or opened")

	for event_id: String in EXPECTED_WAYSTATION_EVENTS.keys():
		var spec: Dictionary = EXPECTED_WAYSTATION_EVENTS[event_id]
		var matches: Array = _matching_events(events, event_id)
		_check(matches.size() == 1, "exactly one authored waystation record for " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(
			record.size() == 6
			and record.has("id")
			and record.has("title")
			and record.has("description")
			and record.has("service_choice_id")
			and record.has("service_kind")
			and record.has("choices"),
			"record has exact 6 top-level keys: " + event_id
		)
		var title: Variant = record.get("title")
		var description: Variant = record.get("description")
		_check(title is String and not String(title).strip_edges().is_empty(), "nonblank title: " + event_id)
		_check(description is String and not String(description).strip_edges().is_empty(), "nonblank description: " + event_id)
		_check(record.get("id") == event_id, "exact id: " + event_id)
		_check(record.get("title") == spec["title"], "exact title: " + event_id)
		_check(record.get("description") == spec["description"], "exact description: " + event_id)
		_check(record.get("service_choice_id") == spec["service_choice_id"], "exact service_choice_id metadata: " + event_id)
		_check(record.get("service_kind") == spec["service_kind"], "exact service_kind metadata: " + event_id)

		var choices_raw: Variant = record.get("choices")
		_check(choices_raw is Array and (choices_raw as Array).size() == 3, "three choices on " + event_id)
		if not (choices_raw is Array) or (choices_raw as Array).size() != 3:
			continue
		var choices: Array = choices_raw
		var exp_choices: Array = spec["choices"]
		for idx in range(3):
			var choice_raw: Variant = choices[idx]
			_check(choice_raw is Dictionary, "choice is Dictionary in " + event_id)
			if not (choice_raw is Dictionary):
				continue
			var choice: Dictionary = choice_raw
			var exp_choice: Dictionary = exp_choices[idx]
			_check(choice.get("id") == exp_choice["id"], "choice id matches: " + event_id + " idx " + str(idx))
			_check(choice.get("text") == exp_choice["text"], "choice text matches: " + event_id + " idx " + str(idx))
			var outcome_raw: Variant = choice.get("outcome")
			_check(outcome_raw is Dictionary and (outcome_raw as Dictionary).size() == 2, "outcome is 2-key dict: " + event_id)
			if outcome_raw is Dictionary:
				var outcome: Dictionary = outcome_raw
				_check(_is_integral_json_number(outcome.get("gold")) and _is_integral_json_number(outcome.get("scraps")), "outcome values are integral: " + event_id)
				_check(int(outcome.get("gold")) == int(exp_choice["outcome"]["gold"]), "exact gold outcome: " + event_id + " idx " + str(idx))
				_check(int(outcome.get("scraps")) == int(exp_choice["outcome"]["scraps"]), "exact scraps outcome: " + event_id + " idx " + str(idx))

		# Verify RunEventChoice compatibility
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(), "RunEventChoice accepts waystation record: " + event_id)
		var preview: Dictionary = selector.preview_wallet_choices({"gold": 50, "scraps": 50})
		_check(preview.get("ok") == true, "RunEventChoice preview_wallet_choices succeeds: " + event_id)
		var p_choices: Array = preview.get("choices", [])
		_check(p_choices.size() == 3, "RunEventChoice preview has 3 choices: " + event_id)

	_check(run_rng.state == rng_before, "AC1 waystation tests consume zero run_rng draws")


func _test_ac2_waystation_service_choices_and_previews(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var gate := RunV3ServiceWaystationEventGate.new()
	_check(gate.is_catalog_valid(), "gate validates catalog for AC2")

	for event_id: String in EXPECTED_WAYSTATION_EVENTS.keys():
		var spec: Dictionary = EXPECTED_WAYSTATION_EVENTS[event_id]
		var service_choice_id: String = spec["service_choice_id"]
		var service_kind: String = spec["service_kind"]
		var paid_outcome: Dictionary = spec["paid_outcome"]
		var exact_wallet: Dictionary = spec["exact_wallet"]
		var funded_wallet: Dictionary = spec["funded_wallet"]

		# 1. Preview checks on funded wallet
		var visit_p := gate.open_visit(event_id)
		_check(visit_p != null and visit_p.is_valid() and not visit_p.is_claimed(), "visit opened for preview: " + event_id)
		var preview: Dictionary = visit_p.preview_choices(funded_wallet)
		_check(preview.get("ok") == true, "preview_choices ok: " + event_id)
		_check(preview.get("event_id") == event_id, "preview event_id: " + event_id)
		_check(preview.get("service_choice_id") == service_choice_id, "preview service_choice_id: " + event_id)
		_check(preview.get("service_kind") == service_kind, "preview service_kind: " + event_id)
		var p_choices: Array = preview.get("choices", [])
		_check(p_choices.size() == 3, "preview has 3 choices: " + event_id)

		var expected_post_wallet := {
			"gold": funded_wallet["gold"] + paid_outcome["gold"],
			"scraps": funded_wallet["scraps"] + paid_outcome["scraps"],
		}

		for item_raw: Variant in p_choices:
			var item: Dictionary = item_raw
			var cid: String = String(item.get("choice_id", ""))
			if cid == service_choice_id:
				_check(item.get("affordable") == true, "service choice affordable in funded preview: " + event_id)
				_check(item.get("service_request") == {"stop_type": service_kind}, "service_request in preview for service choice: " + event_id)
				_check(item.get("wallet") == expected_post_wallet, "preview wallet matches expected post-payment: " + event_id)
			else:
				_check(item.get("service_request") == {}, "non-service choices have empty service_request in preview: " + event_id)

		# 2. Exact wallet settlement (settling down to 0)
		var visit_exact := gate.open_visit(event_id)
		var exact_receipt: Dictionary = visit_exact.choose_with_wallet(service_choice_id, exact_wallet)
		_check(_waystation_receipt_shape_ok(exact_receipt), "exact receipt shape ok: " + event_id)
		_check(exact_receipt.get("ok") == true, "exact paid choice succeeds: " + event_id)
		_check(exact_receipt.get("event_id") == event_id, "exact receipt event_id: " + event_id)
		_check(exact_receipt.get("choice_id") == service_choice_id, "exact receipt choice_id: " + event_id)
		_check(exact_receipt.get("wallet") == {"gold": 0, "scraps": 0}, "exact settlement reaches 0/0: " + event_id)
		_check(exact_receipt.get("service_request") == {"stop_type": service_kind}, "exact service_request: " + event_id)
		_check(visit_exact.is_claimed() and not visit_exact.is_valid(), "visit latched after exact paid choice: " + event_id)

		# 3. Funded wallet settlement and preview/receipt agreement
		var visit_funded := gate.open_visit(event_id)
		var funded_receipt: Dictionary = visit_funded.choose_with_wallet(service_choice_id, funded_wallet)
		_check(_waystation_receipt_shape_ok(funded_receipt), "funded receipt shape ok: " + event_id)
		_check(funded_receipt.get("ok") == true, "funded paid choice succeeds: " + event_id)
		_check(funded_receipt.get("event_id") == event_id, "funded receipt event_id: " + event_id)
		_check(funded_receipt.get("choice_id") == service_choice_id, "funded receipt choice_id: " + event_id)
		_check(funded_receipt.get("wallet") == expected_post_wallet, "post-payment wallet matches preview: " + event_id)
		_check(funded_receipt.get("service_request") == {"stop_type": service_kind}, "funded service_request matches kind: " + event_id)
		_check(visit_funded.is_claimed() and not visit_funded.is_valid(), "visit latched after funded paid choice: " + event_id)

		# Replay rejection on same visit
		var replay_res: Dictionary = visit_funded.choose_with_wallet(service_choice_id, funded_wallet)
		_check(replay_res.get("ok") == false, "replay on claimed visit rejected: " + event_id)
		_check(replay_res.get("service_request") == {}, "replay returns empty service_request: " + event_id)
		_check(replay_res.get("wallet") == funded_wallet, "replay returns unchanged wallet: " + event_id)

	_check(run_rng.state == rng_before, "AC2 waystation tests consume zero run_rng draws")


func _test_ac3_waystation_trades_leave_and_rejections(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var gate := RunV3ServiceWaystationEventGate.new()

	for event_id: String in EXPECTED_WAYSTATION_EVENTS.keys():
		var spec: Dictionary = EXPECTED_WAYSTATION_EVENTS[event_id]
		var service_choice_id: String = spec["service_choice_id"]
		var trade_choice_id: String = spec["trade_choice_id"]
		var trade_outcome: Dictionary = spec["trade_outcome"]
		var short_wallet: Dictionary = spec["short_wallet"]
		var funded_wallet: Dictionary = spec["funded_wallet"]

		# 1. Trade choice branch on fresh visit
		var visit_trade := gate.open_visit(event_id)
		_check(visit_trade != null and visit_trade.is_valid(), "trade visit opened: " + event_id)
		var trade_receipt: Dictionary = visit_trade.choose_with_wallet(trade_choice_id, funded_wallet)
		_check(_waystation_receipt_shape_ok(trade_receipt), "trade receipt shape: " + event_id)
		_check(trade_receipt.get("ok") == true, "trade choice succeeds: " + event_id)
		_check(trade_receipt.get("event_id") == event_id, "trade event_id: " + event_id)
		_check(trade_receipt.get("choice_id") == trade_choice_id, "trade choice_id: " + event_id)
		var expected_trade_wallet := {
			"gold": funded_wallet["gold"] + trade_outcome["gold"],
			"scraps": funded_wallet["scraps"] + trade_outcome["scraps"],
		}
		_check(trade_receipt.get("wallet") == expected_trade_wallet, "trade grants exact currency reward: " + event_id)
		_check(trade_receipt.get("service_request") == {}, "trade returns empty service_request: " + event_id)
		_check(visit_trade.is_claimed() and not visit_trade.is_valid(), "trade consumes visit once: " + event_id)
		var replay_trade: Dictionary = visit_trade.choose_with_wallet("leave", funded_wallet)
		_check(replay_trade.get("ok") == false and replay_trade.get("service_request") == {}, "replay denied on trade visit: " + event_id)

		# 2. Leave choice branch on fresh visit
		var visit_leave := gate.open_visit(event_id)
		_check(visit_leave != null and visit_leave.is_valid(), "leave visit opened: " + event_id)
		var leave_receipt: Dictionary = visit_leave.choose_with_wallet("leave", funded_wallet)
		_check(_waystation_receipt_shape_ok(leave_receipt), "leave receipt shape: " + event_id)
		_check(leave_receipt.get("ok") == true, "leave choice succeeds: " + event_id)
		_check(leave_receipt.get("event_id") == event_id, "leave event_id: " + event_id)
		_check(leave_receipt.get("choice_id") == "leave", "leave choice_id: " + event_id)
		_check(leave_receipt.get("wallet") == funded_wallet, "leave returns exact unchanged wallet: " + event_id)
		_check(leave_receipt.get("service_request") == {}, "leave returns empty service_request: " + event_id)
		_check(visit_leave.is_claimed() and not visit_leave.is_valid(), "leave consumes visit once: " + event_id)
		var replay_leave: Dictionary = visit_leave.choose_with_wallet("leave", funded_wallet)
		_check(replay_leave.get("ok") == false and replay_leave.get("service_request") == {}, "replay denied on leave visit: " + event_id)

		# 3. Short wallet preflight failure leaves visit unclaimed; affordable retry succeeds
		var visit_short := gate.open_visit(event_id)
		_check(visit_short != null and visit_short.is_valid(), "short visit opened: " + event_id)
		var short_receipt: Dictionary = visit_short.choose_with_wallet(service_choice_id, short_wallet)
		_check(short_receipt.get("ok") == false, "unaffordable payment rejected: " + event_id)
		_check(short_receipt.get("wallet") == short_wallet, "short wallet unchanged on refusal: " + event_id)
		_check(short_receipt.get("service_request") == {}, "empty service_request on refusal: " + event_id)
		_check(visit_short.is_valid() and not visit_short.is_claimed(), "visit remains unclaimed after payment refusal: " + event_id)

		var retry_receipt: Dictionary = visit_short.choose_with_wallet(service_choice_id, funded_wallet)
		_check(retry_receipt.get("ok") == true, "affordable retry succeeds on same visit: " + event_id)
		_check(retry_receipt.get("service_request") == {"stop_type": spec["service_kind"]}, "retry returns service request: " + event_id)
		_check(visit_short.is_claimed() and not visit_short.is_valid(), "retry consumes visit: " + event_id)

		# 4. Unknown choice rejection
		var visit_unk := gate.open_visit(event_id)
		var unk_receipt: Dictionary = visit_unk.choose_with_wallet("bogus_choice_id", funded_wallet)
		_check(unk_receipt.get("ok") == false, "unknown choice rejected: " + event_id)
		_check(unk_receipt.get("wallet") == funded_wallet, "wallet unchanged on unknown choice: " + event_id)
		_check(unk_receipt.get("service_request") == {}, "empty service_request on unknown choice: " + event_id)
		_check(visit_unk.is_valid() and not visit_unk.is_claimed(), "visit remains unclaimed after unknown choice: " + event_id)

		# 5. Malformed wallet rejection
		var bad_wallets: Array = [
			null,
			"not a wallet",
			[1, 2],
			{"gold": -1, "scraps": 0},
			{"gold": 0, "scraps": -1},
			{"gold": 10.5, "scraps": 0},
			{"gold": 10},
			{"gold": 10, "scraps": 0, "extra": 1},
		]
		for bad_w: Variant in bad_wallets:
			var bad_receipt: Dictionary = visit_unk.choose_with_wallet(service_choice_id, bad_w)
			_check(bad_receipt.get("ok") == false, "malformed wallet rejected: " + event_id)
			_check(bad_receipt.get("wallet") == {}, "malformed wallet returns empty dict: " + event_id)
			_check(bad_receipt.get("service_request") == {}, "malformed wallet returns empty service_request: " + event_id)
			_check(visit_unk.is_valid() and not visit_unk.is_claimed(), "visit remains unclaimed after bad wallet: " + event_id)

	_check(run_rng.state == rng_before, "AC3 waystation tests consume zero run_rng draws")


func _test_ac3_waystation_forgery_tampering_and_isolation(run_rng: RandomNumberGenerator) -> void:
	var rng_before: int = run_rng.state
	var gate := RunV3ServiceWaystationEventGate.new()

	for event_id: String in EXPECTED_WAYSTATION_EVENTS.keys():
		var authentic_rec: Dictionary = gate.get_event_record(event_id)
		_check(not authentic_rec.is_empty(), "get_event_record returns authentic record: " + event_id)

		# Detached copy isolation
		authentic_rec["title"] = "Injected Modified Title"
		authentic_rec["choices"][0]["outcome"]["scraps"] = 999
		var authentic_rec2: Dictionary = gate.get_event_record(event_id)
		_check(authentic_rec2["title"] != "Injected Modified Title", "modifying get_event_record does not alter catalog: " + event_id)
		_check(authentic_rec2["choices"][0]["outcome"]["scraps"] != 999, "modifying choices does not alter catalog: " + event_id)

		# Bound visit get_event isolation
		var visit := gate.open_visit(event_id)
		var v_event: Dictionary = visit.get_event()
		v_event["title"] = "Another Mutation"
		_check(visit.get_event()["title"] != "Another Mutation", "modifying visit.get_event does not alter bound event: " + event_id)

		# Forged / tampered records
		var base_record: Dictionary = gate.get_event_record(event_id)
		var tampered_cases: Array[Dictionary] = []

		# Case 1: Tampered service_choice_id
		var t_choice_id := base_record.duplicate(true)
		t_choice_id["service_choice_id"] = "leave"
		tampered_cases.append(t_choice_id)

		var t_choice_id2 := base_record.duplicate(true)
		t_choice_id2["service_choice_id"] = base_record["choices"][1]["id"]
		tampered_cases.append(t_choice_id2)

		# Case 2: Tampered service_kind
		var t_kind := base_record.duplicate(true)
		t_kind["service_kind"] = "Fight"
		tampered_cases.append(t_kind)

		var t_kind_bogus := base_record.duplicate(true)
		t_kind_bogus["service_kind"] = "UnknownKind"
		tampered_cases.append(t_kind_bogus)

		# Case 3: Tampered service outcome (made free or gain)
		var t_free_service := base_record.duplicate(true)
		t_free_service["choices"][0]["outcome"] = {"gold": 0, "scraps": 0}
		tampered_cases.append(t_free_service)

		var t_gain_service := base_record.duplicate(true)
		t_gain_service["choices"][0]["outcome"] = {"gold": 10, "scraps": 0}
		tampered_cases.append(t_gain_service)

		# Case 4: Tampered trade outcome (made spend instead of gain)
		var t_spend_trade := base_record.duplicate(true)
		t_spend_trade["choices"][1]["outcome"] = {"gold": -5, "scraps": 0}
		tampered_cases.append(t_spend_trade)

		# Case 5: Tampered leave outcome (non-zero)
		var t_paid_leave := base_record.duplicate(true)
		t_paid_leave["choices"][2]["outcome"] = {"gold": 1, "scraps": 0}
		tampered_cases.append(t_paid_leave)

		# Case 6: Extra key
		var t_extra_key := base_record.duplicate(true)
		t_extra_key["extra_tamper_key"] = true
		tampered_cases.append(t_extra_key)

		for bad_rec: Dictionary in tampered_cases:
			var bad_gate := RunV3ServiceWaystationEventGate.new(bad_rec)
			_check(not bad_gate.is_valid() and not bad_gate.is_claimed(), "tampered waystation record rejected on new(): " + event_id)
			_check(gate.open_visit(bad_rec) == null, "tampered waystation record rejected on open_visit(): " + event_id)

			# Tampered catalog injection rejection
			var replaced_cat: Dictionary = waystation_catalog_doc.duplicate(true)
			for idx in range((replaced_cat["events"] as Array).size()):
				if replaced_cat["events"][idx].get("id") == event_id:
					replaced_cat["events"][idx] = bad_rec.duplicate(true)
			var cat_gate := RunV3ServiceWaystationEventGate.new("v3_emberglass_campfire", replaced_cat)
			_check(not cat_gate.is_catalog_valid(), "catalog with tampered record fails validation: " + event_id)

	# Missing required event fails catalog validation
	for req_id: String in EXPECTED_WAYSTATION_EVENTS.keys():
		var missing_cat: Dictionary = waystation_catalog_doc.duplicate(true)
		var filtered: Array = []
		for ev_raw: Variant in missing_cat["events"]:
			if (ev_raw as Dictionary).get("id") != req_id:
				filtered.append(ev_raw)
		missing_cat["events"] = filtered
		var missing_gate := RunV3ServiceWaystationEventGate.new("v3_emberglass_campfire", missing_cat)
		_check(not missing_gate.is_catalog_valid(), "catalog missing " + req_id + " fails validation")

	# Duplicate event ID fails catalog validation
	var dup_cat: Dictionary = waystation_catalog_doc.duplicate(true)
	var first_rec: Dictionary = (dup_cat["events"] as Array)[0].duplicate(true)
	(dup_cat["events"] as Array).append(first_rec)
	var dup_gate := RunV3ServiceWaystationEventGate.new("v3_emberglass_campfire", dup_cat)
	_check(not dup_gate.is_catalog_valid(), "catalog with duplicate event fails validation")

	# Seeded selection test with independent RNG
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = 445566
	var pick_res: Dictionary = gate.select_event(pick_rng)
	_check(pick_res.get("ok") == true, "select_event succeeds with seeded RNG")
	_check(EXPECTED_WAYSTATION_EVENTS.has(pick_res.get("event", {}).get("id")), "select_event picked valid waystation")

	# Defect 1: Injected sixth valid-looking ID in custom catalog must fail catalog validation
	var sixth_forged_event := {
		"id": "v3_forged_sixth_waystation",
		"title": "The Forged Hearth",
		"description": "An authentic-looking but never-shipped extra waystation event.",
		"service_choice_id": "service_action",
		"service_kind": "Campfire",
		"choices": [
			{"id": "service_action", "text": "Stitch embers (spend 1 scrap, Campfire)", "outcome": {"gold": 0, "scraps": -1}},
			{"id": "trade_action", "text": "Trade cinders (gain 10 gold)", "outcome": {"gold": 10, "scraps": 0}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
		],
	}
	var injected_sixth_cat: Dictionary = waystation_catalog_doc.duplicate(true)
	(injected_sixth_cat["events"] as Array).append(sixth_forged_event.duplicate(true))

	var forged_sixth_cat_gate := RunV3ServiceWaystationEventGate.new(&"__omitted_event_target__", injected_sixth_cat)
	_check(not forged_sixth_cat_gate.is_catalog_valid(), "catalog with injected sixth never-shipped event ID fails is_catalog_valid()")
	_check(forged_sixth_cat_gate.open_visit("v3_forged_sixth_waystation") == null, "open_visit rejects injected sixth event on invalid catalog")
	_check(forged_sixth_cat_gate.open_visit("v3_emberglass_campfire") == null, "open_visit rejects authentic event on invalid injected catalog")

	var forged_sixth_bound_gate := RunV3ServiceWaystationEventGate.new("v3_forged_sixth_waystation", injected_sixth_cat)
	_check(not forged_sixth_bound_gate.is_catalog_valid(), "bound gate with injected sixth catalog fails is_catalog_valid()")
	_check(not forged_sixth_bound_gate.is_valid(), "bound gate with injected sixth event is not valid")
	_check(not forged_sixth_bound_gate.is_claimed(), "bound gate with injected sixth event is not claimed")
	var caller_test_wallet := {"gold": 25, "scraps": 5}
	var test_wallet_snap := caller_test_wallet.duplicate(true)
	var forged_sixth_claim: Dictionary = forged_sixth_bound_gate.choose_with_wallet("service_action", caller_test_wallet)
	_check(forged_sixth_claim.get("ok") == false, "claim rejected on injected sixth event")
	_check(forged_sixth_claim.get("service_request") == {}, "no service_request issued for injected sixth event")
	_check(forged_sixth_claim.get("wallet") == test_wallet_snap, "wallet unchanged on rejected injected sixth event")
	_check(not forged_sixth_bound_gate.is_claimed(), "injected sixth event visit remains unclaimed")

	# Standard gate rejects opening sixth event directly
	_check(gate.open_visit(sixth_forged_event) == null, "open_visit rejects sixth event record dictionary")
	_check(gate.open_visit("v3_forged_sixth_waystation") == null, "open_visit rejects sixth event id string")

	# Confirm the five authentic IDs still pass on authentic catalog
	for auth_id: String in EXPECTED_WAYSTATION_EVENTS.keys():
		var auth_spec: Dictionary = EXPECTED_WAYSTATION_EVENTS[auth_id]
		var auth_v := gate.open_visit(auth_id)
		_check(auth_v != null and auth_v.is_valid() and not auth_v.is_claimed(), "authentic event open_visit succeeds: " + auth_id)
		var auth_receipt: Dictionary = auth_v.choose_with_wallet(auth_spec["service_choice_id"], auth_spec["funded_wallet"])
		_check(auth_receipt.get("ok") == true, "authentic service choice succeeds: " + auth_id)
		_check(auth_receipt.get("service_request") == {"stop_type": auth_spec["service_kind"]}, "authentic service_request matches: " + auth_id)

	# Defect 2: Cloned authentic record/catalog with float outcome substitution must fail validation
	var ember_authentic: Dictionary = gate.get_event_record("v3_emberglass_campfire")
	_check(not ember_authentic.is_empty(), "retrieved authentic emberglass record")

	var float_scraps_rec := ember_authentic.duplicate(true)
	float_scraps_rec["choices"][0]["outcome"]["scraps"] = -1.0 # integral float substitution

	var float_gold_rec := ember_authentic.duplicate(true)
	float_gold_rec["choices"][0]["outcome"]["gold"] = 0.0 # integral float substitution

	var float_trade_rec := ember_authentic.duplicate(true)
	float_trade_rec["choices"][1]["outcome"]["gold"] = 12.0 # integral float in trade choice

	var float_leave_rec := ember_authentic.duplicate(true)
	float_leave_rec["choices"][2]["outcome"]["gold"] = 0.0 # integral float in leave choice

	var float_cases: Array = [
		{"rec": float_scraps_rec, "label": "float scraps -1.0"},
		{"rec": float_gold_rec, "label": "float gold 0.0"},
		{"rec": float_trade_rec, "label": "float trade gold 12.0"},
		{"rec": float_leave_rec, "label": "float leave gold 0.0"},
	]

	for fc: Dictionary in float_cases:
		var f_rec: Dictionary = fc["rec"]
		var f_label: String = fc["label"]

		# 1. Direct record binding fails
		var f_gate := RunV3ServiceWaystationEventGate.new(f_rec)
		_check(not f_gate.is_valid(), "gate initialized with " + f_label + " is not valid")
		_check(not f_gate.is_claimed(), "gate initialized with " + f_label + " is unclaimed")
		var f_wallet := {"gold": 20, "scraps": 5}
		var f_wallet_snap := f_wallet.duplicate(true)
		var f_claim: Dictionary = f_gate.choose_with_wallet("light_the_embers", f_wallet)
		_check(f_claim.get("ok") == false, "claim rejected on " + f_label)
		_check(f_claim.get("service_request") == {}, "service_request is {} on " + f_label + " rejection")
		_check(f_claim.get("wallet") == f_wallet_snap, "wallet unchanged on " + f_label + " rejection")
		_check(not f_gate.is_claimed(), "gate remains unclaimed after " + f_label + " rejection")

		# 2. open_visit with float record fails
		_check(gate.open_visit(f_rec) == null, "open_visit rejects record with " + f_label)

		# 3. Injected catalog with float-substituted record fails
		var float_cat: Dictionary = waystation_catalog_doc.duplicate(true)
		for idx in range((float_cat["events"] as Array).size()):
			if float_cat["events"][idx].get("id") == "v3_emberglass_campfire":
				float_cat["events"][idx] = f_rec.duplicate(true)
		var float_cat_gate := RunV3ServiceWaystationEventGate.new("v3_emberglass_campfire", float_cat)
		_check(not float_cat_gate.is_catalog_valid(), "catalog with " + f_label + " fails is_catalog_valid()")
		_check(not float_cat_gate.is_valid(), "gate with " + f_label + " catalog is not valid")
		var f_cat_claim: Dictionary = float_cat_gate.choose_with_wallet("light_the_embers", f_wallet)
		_check(f_cat_claim.get("ok") == false, "claim rejected on " + f_label + " catalog")
		_check(f_cat_claim.get("service_request") == {}, "service_request is {} on " + f_label + " catalog rejection")
		_check(f_cat_claim.get("wallet") == f_wallet_snap, "wallet unchanged on " + f_label + " catalog rejection")
		_check(not float_cat_gate.is_claimed(), "visit remains unclaimed on " + f_label + " catalog rejection")

	# 4. Verify authentic integer record receipts succeed with signed integer results
	var auth_visit := gate.open_visit("v3_emberglass_campfire")
	_check(auth_visit != null and auth_visit.is_valid(), "authentic emberglass visit opens")
	var auth_gold_scraps_wallet := {"gold": 10, "scraps": 3}
	var signed_receipt: Dictionary = auth_visit.choose_with_wallet("light_the_embers", auth_gold_scraps_wallet)
	_check(signed_receipt.get("ok") == true, "signed integer paid receipt succeeds")
	_check(signed_receipt.get("choice_id") == "light_the_embers", "signed integer receipt choice_id")
	_check(signed_receipt.get("wallet") == {"gold": 10, "scraps": 2}, "signed integer receipt wallet")
	_check(typeof(signed_receipt["wallet"]["gold"]) == TYPE_INT and typeof(signed_receipt["wallet"]["scraps"]) == TYPE_INT, "wallet fields remain native TYPE_INT")
	_check(signed_receipt.get("service_request") == {"stop_type": "Campfire"}, "signed integer receipt service_request")

	_check(run_rng.state == rng_before, "waystation tamper and isolation checks consume zero run_rng draws")
