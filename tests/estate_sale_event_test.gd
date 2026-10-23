extends SceneTree
## Deterministic headless regression for the authored M04 Estate Sale event.
##
## Reads and JSON-parses res://data/events/estate_sale.json and res://data/events/m04_events.json,
## verifying per-ID authored fields on Estate Sale and that the six original catalog events remain
## present by ID without total-count or full-order assertions. Exercises RunEventChoice.new(record)
## for buy_thread, sell_fabric, leave, preview_wallet_choices boundary parity, insufficient-resource
## refusal, unconsumed retry on the same selector, duplicate-claim refusal, malformed input fail-closed
## handling, and zero RNG consumption.

const EVENT_PATH := "res://data/events/estate_sale.json"
const CATALOG_PATH := "res://data/events/m04_events.json"

const EVENT_ID := "estate_sale"
const EVENT_TITLE := "Estate Sale"
const EVENT_DESCRIPTION := "A travelling patchwork estate seller displays folded fabric lots beside a handcart."

const REQUIRED_CHOICES := {
	"buy_thread": {
		"text": "Buy a two-bundle thread lot (15 gold for 2 scraps)",
		"gold": -15,
		"scraps": 2,
	},
	"sell_fabric": {
		"text": "Sell two salvaged scraps for 30 gold",
		"gold": 30,
		"scraps": -2,
	},
	"leave": {
		"text": "Leave the estate sale",
		"gold": 0,
		"scraps": 0,
	},
}

const REQUIRED_CATALOG_EVENTS := {
	"button_trail": "The Button Trail",
	"loose_seam": "The Loose Seam",
	"thimble_well": "The Thimble Well",
	"frayed_signpost": "The Frayed Signpost",
	"quiet_spool": "The Quiet Spool",
	"needle_gate": "The Needle Gate",
}

var failures: Array[String] = []
var checks := 0
var record: Dictionary = {}
var record_snapshot: Dictionary = {}
var file_text: String = ""
var catalog_text: String = ""


func _initialize() -> void:
	_test_authored_record_and_catalog_presence()
	_test_buy_thread_wallet()
	_test_sell_fabric_wallet()
	_test_leave_wallet()
	_test_preview_affordability_boundaries()
	_test_insufficient_resources_refusal_and_same_selector_retry()
	_test_duplicate_claim_refusal()
	_test_invalid_choices_and_malformed_wallets()
	_test_no_deck_hero_or_route_side_effects()
	_test_seeded_rng_unchanged_and_repeatable_traces()
	_check(record == record_snapshot, "parsed authored Estate Sale record unchanged across all flows")
	_check(_read_file_text(EVENT_PATH) == file_text, "estate_sale.json bytes unchanged across all flows")
	_check(_read_file_text(CATALOG_PATH) == catalog_text, "m04_events.json bytes unchanged across all flows")
	for failure in failures:
		printerr(failure)
	print("estate_sale_event_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_file_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _wallet_shape_ok(result: Variant) -> bool:
	if not result is Dictionary:
		return false
	var dict: Dictionary = result
	return (
		dict.size() == 4
		and dict.has("ok")
		and dict.has("event_id")
		and dict.has("choice_id")
		and dict.has("wallet")
		and dict.get("wallet") is Dictionary
	)


func _wallet_exact_int(wallet: Variant, expected_gold: int, expected_scraps: int) -> bool:
	if not wallet is Dictionary:
		return false
	var dict: Dictionary = wallet
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return false
	var gold: Variant = dict.get("gold")
	var scraps: Variant = dict.get("scraps")
	return (
		typeof(gold) == TYPE_INT
		and typeof(scraps) == TYPE_INT
		and int(gold) == expected_gold
		and int(scraps) == expected_scraps
	)


func _is_integral_json_number(value: Variant, allow_negative: bool = false) -> bool:
	if typeof(value) == TYPE_INT:
		return allow_negative or int(value) >= 0
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return (
			is_finite(number)
			and floor(number) == number
			and number <= RunEventChoice.MAX_SAFE_FLOAT_INT
			and number >= (-RunEventChoice.MAX_SAFE_FLOAT_INT if allow_negative else 0.0)
		)
	return false


func _global_rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _test_authored_record_and_catalog_presence() -> void:
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	_check(file != null, "estate_sale.json opens through FileAccess")
	if file == null:
		return
	file_text = file.get_as_text()
	file.close()
	_check(file_text != "", "estate_sale.json is non-empty")

	var parser := JSON.new()
	var parse_result := parser.parse(file_text)
	_check(parse_result == OK, "estate_sale.json parses through JSON")
	var data: Variant = parser.data if parse_result == OK else null
	_check(data is Dictionary, "estate_sale.json top level is a JSON object")
	if not data is Dictionary:
		return

	var parsed: Dictionary = data
	_check(parsed.size() == 4 and parsed.has("id") and parsed.has("title")
		and parsed.has("description") and parsed.has("choices"),
		"authored event has exactly id/title/description/choices keys")
	_check(parsed.get("id") == EVENT_ID, "authored event ID is estate_sale")
	_check(parsed.get("title") == EVENT_TITLE, "authored title is Estate Sale")
	_check(parsed.get("description") == EVENT_DESCRIPTION, "authored description matches")
	var desc_lower := String(parsed.get("description", "")).to_lower()
	_check(desc_lower.contains("estate") and desc_lower.contains("fabric"),
		"authored description mentions estate seller and fabric lots")
	_check(typeof(parsed.get("id")) == TYPE_STRING and typeof(parsed.get("title")) == TYPE_STRING
		and typeof(parsed.get("description")) == TYPE_STRING,
		"authored id/title/description are strings")

	var choices: Variant = parsed.get("choices")
	_check(choices is Array, "authored choices is an array")
	if not choices is Array:
		return
	var choice_list: Array = choices
	_check(choice_list.size() == 3, "authored Estate Sale event has exactly three choices")

	var seen := {}
	var by_id := {}
	for choice in choice_list:
		_check(choice is Dictionary, "every authored choice is an object")
		if not choice is Dictionary:
			continue
		var choice_dict: Dictionary = choice
		_check(choice_dict.size() == 3 and choice_dict.has("id")
			and choice_dict.has("text") and choice_dict.has("outcome"),
			"authored choice has exactly id/text/outcome keys")
		var choice_id: Variant = choice_dict.get("id")
		var choice_text: Variant = choice_dict.get("text")
		_check(typeof(choice_id) == TYPE_STRING and not (choice_id as String).strip_edges().is_empty(),
			"authored choice ID is a nonblank string")
		_check(typeof(choice_text) == TYPE_STRING and not (choice_text as String).strip_edges().is_empty(),
			"authored choice text is a nonblank string")
		if not choice_id is String:
			continue
		_check(not seen.has(choice_id), "authored choice IDs are unique: " + choice_id)
		seen[choice_id] = true
		by_id[choice_id] = choice_dict
		_check(REQUIRED_CHOICES.has(choice_id), "authored choice ID is one of the three expected IDs: " + choice_id)

	for choice_id in REQUIRED_CHOICES:
		_check(by_id.has(choice_id), "required authored choice present: " + choice_id)
		if not by_id.has(choice_id):
			continue
		var expected: Dictionary = REQUIRED_CHOICES[choice_id]
		var choice_dict: Dictionary = by_id[choice_id]
		_check(choice_dict.get("text") == expected["text"], "authored choice text matches: " + choice_id)
		var raw_outcome: Variant = choice_dict.get("outcome")
		_check(raw_outcome is Dictionary, "authored outcome is an object: " + choice_id)
		if not raw_outcome is Dictionary:
			continue
		var outcome: Dictionary = raw_outcome
		_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"),
			"authored outcome has exactly gold/scraps keys: " + choice_id)
		var raw_gold: Variant = outcome.get("gold")
		var raw_scraps: Variant = outcome.get("scraps")
		_check(_is_integral_json_number(raw_gold, true),
			"authored outcome gold is an integral signed number: " + choice_id)
		_check(_is_integral_json_number(raw_scraps, true),
			"authored outcome scraps is an integral signed number: " + choice_id)
		if _is_integral_json_number(raw_gold, true) and _is_integral_json_number(raw_scraps, true):
			_check(int(raw_gold) == int(expected["gold"]) and int(raw_scraps) == int(expected["scraps"]),
				"authored outcome matches exact gold/scraps delta: " + choice_id)

	record = parsed.duplicate(true)
	record_snapshot = parsed.duplicate(true)

	var service := RunEventChoice.new(record)
	_check(service.is_valid(), "authored Estate Sale record builds a valid RunEventChoice")
	_check(not service.is_claimed(), "fresh Estate Sale selector is unclaimed")
	_check(service.get_event() == record, "selector snapshot equals authored record")
	_check(record == record_snapshot, "constructing selector does not mutate authored record")

	# Verify original six-event catalog entries remain present by ID without count or order checks.
	var catalog_file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check(catalog_file != null, "m04_events.json opens through FileAccess")
	if catalog_file == null:
		return
	catalog_text = catalog_file.get_as_text()
	catalog_file.close()
	var catalog_parser := JSON.new()
	var catalog_parse_res := catalog_parser.parse(catalog_text)
	_check(catalog_parse_res == OK and catalog_parser.data is Dictionary,
		"m04_events.json parses as a JSON object")
	if catalog_parse_res == OK and catalog_parser.data is Dictionary:
		var events_variant: Variant = (catalog_parser.data as Dictionary).get("events")
		_check(events_variant is Array and not (events_variant as Array).is_empty(),
			"m04_events.json contains a non-empty events array")
		if events_variant is Array:
			var catalog_by_id := {}
			var estate_sale_count := 0
			var catalog_estate_sale: Dictionary = {}
			for entry in events_variant:
				if entry is Dictionary and (entry as Dictionary).has("id"):
					var eid: String = String((entry as Dictionary).get("id"))
					catalog_by_id[eid] = entry
					if eid == EVENT_ID:
						estate_sale_count += 1
						catalog_estate_sale = entry
			
			_check(estate_sale_count == 1, "exactly one catalog estate_sale matches")
			_check(catalog_estate_sale == record_snapshot, "catalog estate_sale is deep-equal to the standalone record")
			
			if estate_sale_count == 1:
				# Use the catalog record for the rest of the test
				record = catalog_estate_sale.duplicate(true)
				record_snapshot = catalog_estate_sale.duplicate(true)
			
			for required_id in REQUIRED_CATALOG_EVENTS:
				_check(catalog_by_id.has(required_id),
					"original catalog entry remains present by ID: " + required_id)
				if catalog_by_id.has(required_id):
					var cat_entry: Dictionary = catalog_by_id[required_id]
					_check(cat_entry.get("title") == REQUIRED_CATALOG_EVENTS[required_id],
						"original catalog entry keeps authored title: " + required_id)


func _test_buy_thread_wallet() -> void:
	if record.is_empty():
		return
	# Exact threshold (15 gold, 0 scraps) -> (0 gold, 2 scraps), plus surplus wallet (22 gold, 3 scraps) -> (7 gold, 5 scraps).
	var cases := [
		{"label": "exact 15 gold 0 scraps", "gold": 15, "scraps": 0, "expected_gold": 0, "expected_scraps": 2},
		{"label": "surplus 22 gold 3 scraps", "gold": 22, "scraps": 3, "expected_gold": 7, "expected_scraps": 5},
	]
	for idx in range(cases.size()):
		var c: Dictionary = cases[idx]
		var caller_record: Dictionary = record.duplicate(true)
		var wallet := {"gold": int(c["gold"]), "scraps": int(c["scraps"])}
		var expected_rng := _global_rng_start(78001 + idx)
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 78001 + idx
		var local_state := local_rng.state

		var service := RunEventChoice.new(caller_record)
		_check(service.is_valid() and not service.is_claimed(),
			"fresh selector valid before buy_thread: " + String(c["label"]))
		var result := service.choose_with_wallet("buy_thread", wallet)
		_check(_wallet_shape_ok(result), "buy_thread returns exact four-key result shape: " + String(c["label"]))
		_check(result.get("ok", false) == true, "buy_thread claim succeeds: " + String(c["label"]))
		_check(result.get("event_id", "") == EVENT_ID, "buy_thread returns estate_sale event_id: " + String(c["label"]))
		_check(result.get("choice_id", "") == "buy_thread", "buy_thread returns buy_thread choice_id: " + String(c["label"]))
		_check(_wallet_exact_int(result.get("wallet"), int(c["expected_gold"]), int(c["expected_scraps"])),
			"buy_thread settles exact wallet: " + String(c["label"]))
		_check(_wallet_exact_int(wallet, int(c["gold"]), int(c["scraps"])),
			"buy_thread does not mutate caller wallet: " + String(c["label"]))
		_check(caller_record == record_snapshot, "buy_thread does not mutate caller record: " + String(c["label"]))
		_check(service.get_event() == record_snapshot, "buy_thread leaves selector snapshot unchanged: " + String(c["label"]))
		_check(service.is_claimed() and not service.is_valid(), "buy_thread latches claim once: " + String(c["label"]))
		_check(local_rng.state == local_state, "buy_thread spends no local seeded RNG: " + String(c["label"]))
		_check(randi() == expected_rng, "buy_thread spends no global seeded RNG: " + String(c["label"]))

		(result["wallet"] as Dictionary)["gold"] = 999
		(result["wallet"] as Dictionary)["scraps"] = 999
		_check(_wallet_exact_int(wallet, int(c["gold"]), int(c["scraps"])),
			"mutating buy_thread returned wallet cannot change caller wallet: " + String(c["label"]))


func _test_sell_fabric_wallet() -> void:
	if record.is_empty():
		return
	# Exact threshold (0 gold, 2 scraps) -> (30 gold, 0 scraps), plus surplus wallet (10 gold, 5 scraps) -> (40 gold, 3 scraps).
	var cases := [
		{"label": "exact 0 gold 2 scraps", "gold": 0, "scraps": 2, "expected_gold": 30, "expected_scraps": 0},
		{"label": "surplus 10 gold 5 scraps", "gold": 10, "scraps": 5, "expected_gold": 40, "expected_scraps": 3},
	]
	for idx in range(cases.size()):
		var c: Dictionary = cases[idx]
		var caller_record: Dictionary = record.duplicate(true)
		var wallet := {"gold": int(c["gold"]), "scraps": int(c["scraps"])}
		var expected_rng := _global_rng_start(78011 + idx)
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 78011 + idx
		var local_state := local_rng.state

		var service := RunEventChoice.new(caller_record)
		_check(service.is_valid() and not service.is_claimed(),
			"fresh selector valid before sell_fabric: " + String(c["label"]))
		var result := service.choose_with_wallet("sell_fabric", wallet)
		_check(_wallet_shape_ok(result), "sell_fabric returns exact four-key result shape: " + String(c["label"]))
		_check(result.get("ok", false) == true, "sell_fabric claim succeeds: " + String(c["label"]))
		_check(result.get("event_id", "") == EVENT_ID, "sell_fabric returns estate_sale event_id: " + String(c["label"]))
		_check(result.get("choice_id", "") == "sell_fabric", "sell_fabric returns sell_fabric choice_id: " + String(c["label"]))
		_check(_wallet_exact_int(result.get("wallet"), int(c["expected_gold"]), int(c["expected_scraps"])),
			"sell_fabric settles exact wallet: " + String(c["label"]))
		_check(_wallet_exact_int(wallet, int(c["gold"]), int(c["scraps"])),
			"sell_fabric does not mutate caller wallet: " + String(c["label"]))
		_check(caller_record == record_snapshot, "sell_fabric does not mutate caller record: " + String(c["label"]))
		_check(service.get_event() == record_snapshot, "sell_fabric leaves selector snapshot unchanged: " + String(c["label"]))
		_check(service.is_claimed() and not service.is_valid(), "sell_fabric latches claim once: " + String(c["label"]))
		_check(local_rng.state == local_state, "sell_fabric spends no local seeded RNG: " + String(c["label"]))
		_check(randi() == expected_rng, "sell_fabric spends no global seeded RNG: " + String(c["label"]))

		(result["wallet"] as Dictionary)["gold"] = -1
		_check(_wallet_exact_int(wallet, int(c["gold"]), int(c["scraps"])),
			"mutating sell_fabric returned wallet cannot change caller wallet: " + String(c["label"]))


func _test_leave_wallet() -> void:
	if record.is_empty():
		return
	var cases := [
		{"label": "empty 0 gold 0 scraps", "gold": 0, "scraps": 0},
		{"label": "non-zero 14 gold 1 scrap", "gold": 14, "scraps": 1},
	]
	for idx in range(cases.size()):
		var c: Dictionary = cases[idx]
		var caller_record: Dictionary = record.duplicate(true)
		var wallet := {"gold": int(c["gold"]), "scraps": int(c["scraps"])}
		var expected_rng := _global_rng_start(78021 + idx)
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 78021 + idx
		var local_state := local_rng.state

		var service := RunEventChoice.new(caller_record)
		var result := service.choose_with_wallet("leave", wallet)
		_check(_wallet_shape_ok(result), "leave returns exact four-key result shape: " + String(c["label"]))
		_check(result.get("ok", false) == true, "leave claim succeeds: " + String(c["label"]))
		_check(result.get("event_id", "") == EVENT_ID and result.get("choice_id", "") == "leave",
			"leave returns exact event/choice IDs: " + String(c["label"]))
		_check(_wallet_exact_int(result.get("wallet"), int(c["gold"]), int(c["scraps"])),
			"leave settles zero delta: " + String(c["label"]))
		_check(_wallet_exact_int(wallet, int(c["gold"]), int(c["scraps"])),
			"leave does not mutate caller wallet: " + String(c["label"]))
		_check(service.is_claimed() and not service.is_valid(),
			"leave latches claim once: " + String(c["label"]))
		_check(local_rng.state == local_state and randi() == expected_rng,
			"leave spends no local or global RNG: " + String(c["label"]))


func _test_preview_affordability_boundaries() -> void:
	if record.is_empty():
		return
	# Test exact affordability threshold and just below it for buy_thread (15 vs 14, 0 gold)
	# and sell_fabric (2 vs 1, 0 scraps), plus combined affordable and overflow states.
	var wallets := [
		{"gold": 0, "scraps": 0},
		{"gold": 14, "scraps": 0},
		{"gold": 15, "scraps": 0},
		{"gold": 16, "scraps": 0},
		{"gold": 0, "scraps": 1},
		{"gold": 0, "scraps": 2},
		{"gold": 0, "scraps": 3},
		{"gold": 14, "scraps": 1},
		{"gold": 15, "scraps": 2},
	]
	for idx in range(wallets.size()):
		var w: Dictionary = wallets[idx]
		var wallet: Dictionary = w.duplicate(true)
		var wallet_before: Dictionary = wallet.duplicate(true)
		var caller_record: Dictionary = record.duplicate(true)
		var expected_rng := _global_rng_start(78100 + idx)
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 78100 + idx
		var local_state := local_rng.state

		var service := RunEventChoice.new(caller_record)
		var preview := service.preview_wallet_choices(wallet)
		_check(preview.size() == 3 and preview.get("ok") == true
			and preview.get("event_id") == EVENT_ID and preview.get("choices") is Array,
			"preview returns valid contract for wallet " + str(wallet))
		var entries: Array = preview.get("choices", [])
		_check(entries.size() == 3, "preview returns all three choices in order for wallet " + str(wallet))

		var source_choices: Array = record["choices"]
		for c_idx in range(source_choices.size()):
			var choice_id: String = source_choices[c_idx]["id"]
			var expected: Dictionary = REQUIRED_CHOICES[choice_id]
			var entry := _preview_choice(preview, choice_id)
			var can_afford: bool = (int(wallet["gold"]) + int(expected["gold"]) >= 0) and (int(wallet["scraps"]) + int(expected["scraps"]) >= 0)
			var proj_gold: int = int(wallet["gold"]) + int(expected["gold"]) if can_afford else int(wallet["gold"])
			var proj_scraps: int = int(wallet["scraps"]) + int(expected["scraps"]) if can_afford else int(wallet["scraps"])

			_check(not entry.is_empty() and entries[c_idx].get("choice_id") == choice_id,
				"preview preserves choice order for " + choice_id + " at " + str(wallet))
			_check(entry.size() == 5
				and entry.get("gold_delta") == int(expected["gold"])
				and entry.get("scraps_delta") == int(expected["scraps"])
				and entry.get("affordable") == can_afford
				and _wallet_exact_int(entry.get("wallet"), proj_gold, proj_scraps),
				"preview entry matches signed deltas, affordability and projected wallet for "
				+ choice_id + " at " + str(wallet))

			# Verify parity with an independent commit/refusal receipt.
			var receipt := RunEventChoice.new(record).choose_with_wallet(choice_id, wallet)
			_check(receipt.get("ok") == can_afford
				and receipt.get("wallet") == entry.get("wallet")
				and receipt.get("event_id") == (EVENT_ID if can_afford else "")
				and receipt.get("choice_id") == (choice_id if can_afford else ""),
				"preview agrees with choose_with_wallet receipt for " + choice_id + " at " + str(wallet))

		# Mutating a preview entry wallet does not affect caller wallet, sibling entries, or selector.
		var leave_entry := _preview_choice(preview, "leave")
		var leave_wallet_before: Dictionary = (leave_entry["wallet"] as Dictionary).duplicate(true)
		(entries[0]["wallet"] as Dictionary)["gold"] = -999
		_check(leave_entry["wallet"] == leave_wallet_before and wallet == wallet_before
			and service.is_valid() and not service.is_claimed()
			and service.get_event() == record_snapshot,
			"preview entries are detached and preview does not claim at " + str(wallet))
		_check(local_rng.state == local_state and randi() == expected_rng,
			"preview and boundary checks spend no RNG at " + str(wallet))


func _test_insufficient_resources_refusal_and_same_selector_retry() -> void:
	if record.is_empty():
		return

	# Sequence 1: Insufficient gold for buy_thread (0 gold and 14 gold) and insufficient scraps for
	# sell_fabric (0 scraps and 1 scrap) all fail on the SAME selector without wallet mutation or claiming,
	# then the same selector succeeds on 'leave' and rejects any subsequent replay.
	var caller_record: Dictionary = record.duplicate(true)
	var service := RunEventChoice.new(caller_record)
	var rejection_cases := [
		{"choice": "buy_thread", "wallet": {"gold": 0, "scraps": 0}, "seed": 78201},
		{"choice": "buy_thread", "wallet": {"gold": 14, "scraps": 5}, "seed": 78202},
		{"choice": "sell_fabric", "wallet": {"gold": 50, "scraps": 0}, "seed": 78203},
		{"choice": "sell_fabric", "wallet": {"gold": 50, "scraps": 1}, "seed": 78204},
	]
	for item in rejection_cases:
		var choice_id: String = item["choice"]
		var w: Dictionary = (item["wallet"] as Dictionary).duplicate(true)
		var w_before: Dictionary = w.duplicate(true)
		var rng_seed: int = item["seed"]
		var expected_rng := _global_rng_start(rng_seed)
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = rng_seed
		var local_state := local_rng.state

		var preview := service.preview_wallet_choices(w)
		var p_entry := _preview_choice(preview, choice_id)
		_check(p_entry.get("affordable") == false and p_entry.get("wallet") == w_before,
			"unaffordable choice marked false in preview: " + choice_id + " with " + str(w))

		var refusal := service.choose_with_wallet(choice_id, w)
		_check(_wallet_shape_ok(refusal) and refusal.get("ok", true) == false
			and refusal.get("event_id", "") == "" and refusal.get("choice_id", "") == ""
			and _wallet_exact_int(refusal.get("wallet"), int(w_before["gold"]), int(w_before["scraps"])),
			"unaffordable choice rejected with unchanged detached wallet: " + choice_id + " with " + str(w))
		_check(w == w_before, "caller wallet unmutated on refusal: " + choice_id)
		_check(not service.is_claimed() and service.is_valid(),
			"selector remains unclaimed and valid after refusal: " + choice_id)
		_check(service.get_event() == record_snapshot and caller_record == record_snapshot,
			"selector and caller event snapshots unchanged after refusal: " + choice_id)
		(refusal["wallet"] as Dictionary)["gold"] = 9999
		_check(w == w_before, "mutating refused wallet does not mutate caller wallet: " + choice_id)
		_check(local_rng.state == local_state and randi() == expected_rng,
			"insufficient-resource refusal spends no local or global RNG: " + choice_id + " with " + str(w))

	# Retry on the SAME unconsumed selector with 'leave' (14 gold, 1 scrap).
	var fallback_wallet := {"gold": 14, "scraps": 1}
	var expected_fallback_rng := _global_rng_start(78205)
	var local_fallback_rng := RandomNumberGenerator.new()
	local_fallback_rng.seed = 78205
	var local_fallback_state := local_fallback_rng.state
	var fallback := service.choose_with_wallet("leave", fallback_wallet)
	_check(_wallet_shape_ok(fallback) and fallback.get("ok", false) == true
		and fallback.get("event_id", "") == EVENT_ID and fallback.get("choice_id", "") == "leave"
		and _wallet_exact_int(fallback.get("wallet"), 14, 1),
		"same selector accepts leave after insufficient-resource refusals")
	_check(_wallet_exact_int(fallback_wallet, 14, 1), "caller wallet unchanged after fallback claim")
	_check(service.is_claimed() and not service.is_valid(), "fallback claim latches the selector")
	var post_replay := service.choose_with_wallet("buy_thread", {"gold": 20, "scraps": 5})
	_check(_wallet_shape_ok(post_replay) and post_replay.get("ok", true) == false
		and _wallet_exact_int(post_replay.get("wallet"), 20, 5),
		"subsequent replay on same selector after fallback is rejected")
	_check(local_fallback_rng.state == local_fallback_state and randi() == expected_fallback_rng,
		"fallback claim and post-claim replay spend no RNG")

	# Sequence 2: Unaffordable sell_fabric (15 gold, 1 scrap) fails on a selector, then buy_thread
	# succeeds on that SAME selector -> (0 gold, 3 scraps), and subsequent replay fails.
	var service_buy := RunEventChoice.new(record.duplicate(true))
	var wallet_15_1 := {"gold": 15, "scraps": 1}
	var rng_seq2 := _global_rng_start(78206)
	var denied_sell := service_buy.choose_with_wallet("sell_fabric", wallet_15_1)
	_check(denied_sell.get("ok", true) == false and _wallet_exact_int(denied_sell.get("wallet"), 15, 1)
		and service_buy.is_valid() and not service_buy.is_claimed(),
		"sell_fabric with 1 scrap fails without claiming")
	var retry_buy := service_buy.choose_with_wallet("buy_thread", wallet_15_1)
	_check(retry_buy.get("ok", false) == true and retry_buy.get("choice_id") == "buy_thread"
		and _wallet_exact_int(retry_buy.get("wallet"), 0, 3)
		and service_buy.is_claimed() and not service_buy.is_valid(),
		"buy_thread succeeds on same selector after failed sell_fabric")
	var replay_after_buy := service_buy.choose_with_wallet("leave", wallet_15_1)
	_check(replay_after_buy.get("ok", true) == false and _wallet_exact_int(replay_after_buy.get("wallet"), 15, 1),
		"replay after buy_thread is rejected")
	_check(randi() == rng_seq2, "sequence 2 spends no global RNG")

	# Sequence 3: Unaffordable buy_thread (14 gold, 2 scraps) fails on a selector, then sell_fabric
	# succeeds on that SAME selector -> (44 gold, 0 scraps), and subsequent replay fails.
	var service_sell := RunEventChoice.new(record.duplicate(true))
	var wallet_14_2 := {"gold": 14, "scraps": 2}
	var rng_seq3 := _global_rng_start(78207)
	var denied_buy := service_sell.choose_with_wallet("buy_thread", wallet_14_2)
	_check(denied_buy.get("ok", true) == false and _wallet_exact_int(denied_buy.get("wallet"), 14, 2)
		and service_sell.is_valid() and not service_sell.is_claimed(),
		"buy_thread with 14 gold fails without claiming")
	var retry_sell := service_sell.choose_with_wallet("sell_fabric", wallet_14_2)
	_check(retry_sell.get("ok", false) == true and retry_sell.get("choice_id") == "sell_fabric"
		and _wallet_exact_int(retry_sell.get("wallet"), 44, 0)
		and service_sell.is_claimed() and not service_sell.is_valid(),
		"sell_fabric succeeds on same selector after failed buy_thread")
	var replay_after_sell := service_sell.choose_with_wallet("leave", wallet_14_2)
	_check(replay_after_sell.get("ok", true) == false and _wallet_exact_int(replay_after_sell.get("wallet"), 14, 2),
		"replay after sell_fabric is rejected")
	_check(randi() == rng_seq3, "sequence 3 spends no global RNG")


func _test_duplicate_claim_refusal() -> void:
	if record.is_empty():
		return
	for initial_choice in ["buy_thread", "sell_fabric", "leave"]:
		var caller_record: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(caller_record)
		var wallet := {"gold": 20, "scraps": 4}
		var expected_rng := _global_rng_start(78300)
		var first := service.choose_with_wallet(initial_choice, wallet)
		_check(first.get("ok", false) == true and service.is_claimed() and not service.is_valid(),
			"first claim succeeds and latches selector for " + initial_choice)

		for second_choice in ["buy_thread", "sell_fabric", "leave"]:
			var replay_wallet := {"gold": 30, "scraps": 6}
			var replay := service.choose_with_wallet(second_choice, replay_wallet)
			_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
				and replay.get("event_id", "") == "" and replay.get("choice_id", "") == ""
				and _wallet_exact_int(replay.get("wallet"), 30, 6)
				and _wallet_exact_int(replay_wallet, 30, 6),
				"duplicate choose_with_wallet rejected after " + initial_choice + " -> " + second_choice)
			var legacy_replay := service.choose(second_choice)
			_check(legacy_replay.get("ok", true) == false
				and legacy_replay.get("event_id", "") == "" and legacy_replay.get("choice_id", "") == "",
				"duplicate legacy choose() rejected after " + initial_choice + " -> " + second_choice)

		var preview_after := service.preview_wallet_choices(wallet)
		_check(preview_after == {"ok": false, "event_id": "", "choices": []},
			"preview_wallet_choices denied after selector is claimed: " + initial_choice)
		_check(service.is_claimed() and not service.is_valid() and service.get_event() == record_snapshot,
			"selector remains claimed and snapshot intact after duplicate attempts: " + initial_choice)
		_check(randi() == expected_rng, "duplicate claim refusals spend no global RNG: " + initial_choice)


func _test_invalid_choices_and_malformed_wallets() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var service := RunEventChoice.new(caller_record)
	var valid_wallet := {"gold": 15, "scraps": 2}
	var bad_choices: Array = [
		"", "   ", "unknown", "BUY_THREAD", "buy_thread ", " buy_thread",
		"sell", "leave_now", null, 15, 2.0, false, ["buy_thread"], {"id": "buy_thread"},
	]
	for bad_choice in bad_choices:
		var expected_rng := _global_rng_start(78400)
		var rejected := service.choose_with_wallet(bad_choice, valid_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false
			and rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == ""
			and _wallet_exact_int(rejected.get("wallet"), 15, 2),
			"invalid choice rejected with unchanged detached wallet: " + str(bad_choice))
		_check(not service.is_claimed() and service.is_valid(),
			"invalid choice does not claim selector: " + str(bad_choice))
		_check(randi() == expected_rng, "invalid choice spends no RNG: " + str(bad_choice))

	var malformed_wallets := {
		"null": null,
		"int": 15,
		"string": "15",
		"array": [15, 2],
		"empty": {},
		"missing scraps": {"gold": 15},
		"missing gold": {"scraps": 2},
		"extra key": {"gold": 15, "scraps": 2, "cards": 1},
		"negative gold": {"gold": -1, "scraps": 2},
		"negative scraps": {"gold": 15, "scraps": -1},
		"float gold": {"gold": 15.0, "scraps": 2},
		"float scraps": {"gold": 15, "scraps": 2.0},
		"bool gold": {"gold": true, "scraps": 2},
		"string scraps": {"gold": 15, "scraps": "2"},
	}
	for label in malformed_wallets:
		var bad_wallet: Variant = malformed_wallets[label]
		var expected_rng := _global_rng_start(78401)
		var rejected := service.choose_with_wallet("buy_thread", bad_wallet)
		_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false
			and (rejected.get("wallet") as Dictionary).is_empty(),
			"malformed wallet rejected with empty wallet dict: " + label)
		_check(not service.is_claimed() and service.is_valid(),
			"malformed wallet does not claim selector: " + label)
		_check(randi() == expected_rng, "malformed wallet spends no RNG: " + label)

	var accepted := service.choose_with_wallet("buy_thread", valid_wallet)
	_check(accepted.get("ok", false) == true and _wallet_exact_int(accepted.get("wallet"), 0, 4)
		and service.is_claimed() and not service.is_valid(),
		"selector still settles valid buy_thread after all invalid choice and wallet rejections")


func _test_no_deck_hero_or_route_side_effects() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var service := RunEventChoice.new(caller_record)
	var wallet := {"gold": 15, "scraps": 0}
	var result := service.choose_with_wallet("buy_thread", wallet)
	_check(result.size() == 4, "settled result carries only ok/event_id/choice_id/wallet")
	_check((result.get("wallet") as Dictionary).size() == 2, "settled wallet carries only gold/scraps")
	for key in result:
		var k := str(key).to_lower()
		_check(not k.contains("deck") and not k.contains("hero")
			and not k.contains("route") and not k.contains("hp")
			and not k.contains("patch") and not k.contains("card"),
			"result exposes no deck/hero/route/hp/patch/card side effect: " + str(key))


func _test_seeded_rng_unchanged_and_repeatable_traces() -> void:
	if record.is_empty():
		return
	var sentinel := _global_rng_start(78500)
	randi()
	_check(randi() != sentinel, "global RNG probe detects an injected draw")

	var traces: Array = []
	for attempt in range(2):
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 78501
		var local_state := local_rng.state
		var expected_global := _global_rng_start(78501)
		var caller_record: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(caller_record)
		var preview := service.preview_wallet_choices({"gold": 15, "scraps": 1})
		var refused_sell := service.choose_with_wallet("sell_fabric", {"gold": 15, "scraps": 1})
		var settled_buy := service.choose_with_wallet("buy_thread", {"gold": 15, "scraps": 1})
		var replayed := service.choose_with_wallet("leave", {"gold": 0, "scraps": 3})
		_check(local_rng.state == local_state and randi() == expected_global,
			"seeded trace spends no local or global RNG on attempt " + str(attempt))
		traces.append({
			"preview": preview,
			"refused_sell": refused_sell,
			"settled_buy": settled_buy,
			"replayed": replayed,
			"is_claimed": service.is_claimed(),
			"is_valid": service.is_valid(),
			"event": service.get_event(),
		})
	_check(traces.size() == 2 and traces[0] == traces[1],
		"two independent seeded Estate Sale traces are identical")
