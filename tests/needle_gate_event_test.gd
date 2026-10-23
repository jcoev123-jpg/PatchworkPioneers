extends SceneTree
## Deterministic headless regression for the authored M04 Needle Gate event.
##
## Reads and JSON-parses res://data/events/needle_gate.json and checks the
## authored record per choice ID (text and gold/scraps deltas) instead of
## trusting a hand-written fixture. Confirms earlier generic entries in
## res://data/events/m04_events.json remain available without exact catalog
## length or positional indexing.
## Drives the scene-free RunEventChoice service for all three authored outcomes
## (examine, pass, cut_bindings), previews at 0, 1 and 2 scraps with exact
## affordability boundaries, and verifies fail-closed negative transactions
## (insufficient scraps, unknown choice, malformed wallet, replay on the same
## selector). Every flow proves that the authored file, the parsed record, the
## selector snapshot and caller wallets stay unchanged, and no seeded RNG drifts.

const EVENT_PATH := "res://data/events/needle_gate.json"
const M04_EVENTS_PATH := "res://data/events/m04_events.json"

const EVENT_ID := "needle_gate"
const EVENT_TITLE := "The Needle Gate"
const EVENT_DESCRIPTION := "Crossed needles mark a narrow wooden gate."

const REQUIRED_CHOICES := {
	"examine": {
		"text": "Spend 1 scrap to unpick the gate and claim 12 gold",
		"gold": 12,
		"scraps": -1,
	},
	"pass": {
		"text": "Pass without stopping",
		"gold": 0,
		"scraps": 0,
	},
	"cut_bindings": {
		"text": "Cut the binding threads (spend 2 scraps; gain 28 gold)",
		"gold": 28,
		"scraps": -2,
	},
}

const REQUIRED_M04_IDS := [
	"needle_gate",
	"quiet_spool",
	"button_trail",
	"loose_seam",
	"thimble_well",
	"frayed_signpost",
]

var failures: Array[String] = []
var checks := 0
var record: Dictionary = {}
var record_snapshot: Dictionary = {}
var file_text: String = ""
var m04_catalog_snapshot: Array = []


func _initialize() -> void:
	_test_m04_catalog_presence()
	_test_authored_record()
	_test_wallet_choice_previews_at_boundaries()
	_test_three_authored_outcomes_fresh_instances()
	_test_insufficient_scraps_recovery_and_replay_same_selector()
	_test_invalid_choice_rejections()
	_test_malformed_wallet_rejections()
	_test_replay_rejection_across_all_choices()
	_test_no_deck_hero_or_route_side_effects()
	_test_seeded_rng_unchanged_and_repeatable_traces()
	_check(record == record_snapshot, "parsed authored record unchanged across all test flows")
	_check(_read_file_text(EVENT_PATH) == file_text, "authored needle_gate.json file bytes unchanged by every flow")
	for failure in failures:
		printerr(failure)
	print("needle_gate_event_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
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
			and number <= 9007199254740992.0
			and number >= (-9007199254740992.0 if allow_negative else 0.0)
		)
	return false


func _global_rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _test_m04_catalog_presence() -> void:
	var text := _read_file_text(M04_EVENTS_PATH)
	_check(text != "", "m04_events.json opens and is non-empty")
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, "m04_events.json parses cleanly through JSON")
	if parse_result != OK or not parser.data is Dictionary:
		return
	var data: Dictionary = parser.data
	var events_list: Variant = data.get("events")
	_check(events_list is Array, "m04_events.json contains events array")
	if not events_list is Array:
		return
	var catalog: Array = events_list
	m04_catalog_snapshot = catalog.duplicate(true)

	# Verify required existing entries are present by ID without checking exact catalog size or index positions
	for required_id in REQUIRED_M04_IDS:
		var matches := catalog.filter(func(e): return e is Dictionary and e.get("id") == required_id)
		_check(matches.size() >= 1, "m04_events.json contains entry by ID: " + required_id)
		if matches.size() >= 1:
			var entry: Dictionary = matches[0]
			_check(entry.has("title") and entry.has("description") and entry.has("choices"),
				"entry has required fields: " + required_id)


func _test_authored_record() -> void:
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	_check(file != null, "needle_gate.json opens through FileAccess")
	if file == null:
		return
	file_text = file.get_as_text()
	file.close()
	_check(file_text != "", "needle_gate.json is non-empty")

	var parser := JSON.new()
	var parse_result := parser.parse(file_text)
	_check(parse_result == OK, "needle_gate.json parses cleanly through JSON")
	var data: Variant = parser.data if parse_result == OK else null
	_check(data is Dictionary, "needle_gate.json top level is a JSON object")
	if not data is Dictionary:
		return

	var parsed: Dictionary = data
	_check(parsed.size() == 4 and parsed.has("id") and parsed.has("title")
		and parsed.has("description") and parsed.has("choices"),
		"authored event has exact top-level keys id, title, description, choices")
	_check(parsed.get("id") == EVENT_ID, "authored event ID is needle_gate")
	_check(parsed.get("title") == EVENT_TITLE, "authored title is The Needle Gate")
	_check(parsed.get("description") == EVENT_DESCRIPTION, "authored description matches")
	_check(typeof(parsed.get("id")) == TYPE_STRING and typeof(parsed.get("title")) == TYPE_STRING
		and typeof(parsed.get("description")) == TYPE_STRING,
		"authored id, title, description are strings")

	var choices: Variant = parsed.get("choices")
	_check(choices is Array, "authored choices is an array")
	if not choices is Array:
		return
	var choice_list: Array = choices
	_check(choice_list.size() == 3, "authored event has exactly three choices")
	_check(choice_list.size() >= 2 and choice_list.size() <= 3,
		"choice count complies with 2-3 choices rule")

	# Sequence check: examine, pass, cut_bindings
	var expected_order := ["examine", "pass", "cut_bindings"]
	var seen := {}
	var by_id := {}
	for i in range(choice_list.size()):
		var choice: Variant = choice_list[i]
		_check(choice is Dictionary, "choice is an object at index " + str(i))
		if not choice is Dictionary:
			continue
		var choice_dict: Dictionary = choice
		_check(choice_dict.size() == 3 and choice_dict.has("id")
			and choice_dict.has("text") and choice_dict.has("outcome"),
			"authored choice has exact keys id, text, outcome")
		var choice_id: Variant = choice_dict.get("id")
		var choice_text: Variant = choice_dict.get("text")
		_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
			"choice ID is nonblank string at index " + str(i))
		_check(choice_text is String and not (choice_text as String).strip_edges().is_empty(),
			"choice text is nonblank string at index " + str(i))
		if not choice_id is String:
			continue
		_check(not seen.has(choice_id), "choice ID is unique: " + choice_id)
		seen[choice_id] = true
		by_id[choice_id] = choice_dict
		if i < expected_order.size():
			_check(choice_id == expected_order[i],
				"choice sequence matches prescribed order at index " + str(i) + ": " + choice_id)

	for choice_id in REQUIRED_CHOICES:
		_check(by_id.has(choice_id), "required choice present: " + choice_id)
		if not by_id.has(choice_id):
			continue
		var expected: Dictionary = REQUIRED_CHOICES[choice_id]
		var choice_dict: Dictionary = by_id[choice_id]
		_check(choice_dict.get("text") == expected["text"], "authored text for choice: " + choice_id)
		var raw_outcome: Variant = choice_dict.get("outcome")
		_check(raw_outcome is Dictionary, "outcome is an object: " + choice_id)
		if not raw_outcome is Dictionary:
			continue
		var outcome: Dictionary = raw_outcome
		_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"),
			"outcome has exact keys gold and scraps: " + choice_id)
		var raw_gold: Variant = outcome.get("gold")
		var raw_scraps: Variant = outcome.get("scraps")
		_check(_is_integral_json_number(raw_gold, false),
			"authored outcome gold is integral nonnegative: " + choice_id)
		_check(_is_integral_json_number(raw_scraps, true),
			"authored outcome scraps is integral signed: " + choice_id)
		if _is_integral_json_number(raw_gold, false) and _is_integral_json_number(raw_scraps, true):
			_check(int(raw_gold) == int(expected["gold"]) and int(raw_scraps) == int(expected["scraps"]),
				"authored outcome matches exact gold/scraps: " + choice_id)

	record = parsed.duplicate(true)
	record_snapshot = parsed.duplicate(true)

	var service := RunEventChoice.new(record)
	_check(service.is_valid(), "authored record constructs a valid RunEventChoice")
	_check(not service.is_claimed(), "fresh selector is unclaimed")
	_check(service.get_event() == record, "selector snapshot equals authored record")
	_check(record == record_snapshot, "service construction does not mutate authored record")


func _test_wallet_choice_previews_at_boundaries() -> void:
	if record.is_empty():
		return

	# 1. Preview at {gold: 20, scraps: 2} -> all three affordable
	var caller_event_2: Dictionary = record.duplicate(true)
	var wallet_2 := {"gold": 20, "scraps": 2}
	var wallet_2_before: Dictionary = wallet_2.duplicate(true)
	var rng_2 := _global_rng_start(81001)
	var service_2 := RunEventChoice.new(caller_event_2)
	var preview_2 := service_2.preview_wallet_choices(wallet_2)
	_check(preview_2.get("ok") == true and preview_2.get("event_id") == EVENT_ID,
		"preview at 2 scraps returns ok and needle_gate event_id")
	var choices_2: Array = preview_2.get("choices", [])
	_check(choices_2.size() == 3, "preview at 2 scraps returns 3 choices")
	var p2_by_id := {}
	for c in choices_2:
		if c is Dictionary:
			p2_by_id[c.get("choice_id")] = c

	_check(p2_by_id.has("examine") and p2_by_id.has("pass") and p2_by_id.has("cut_bindings"),
		"preview at 2 scraps contains all 3 choice IDs")
	if p2_by_id.has("examine") and p2_by_id.has("pass") and p2_by_id.has("cut_bindings"):
		var p_ex: Dictionary = p2_by_id["examine"]
		var p_pa: Dictionary = p2_by_id["pass"]
		var p_cu: Dictionary = p2_by_id["cut_bindings"]

		_check(p_ex.get("gold_delta") == 12 and p_ex.get("scraps_delta") == -1
			and p_ex.get("affordable") == true and _wallet_exact_int(p_ex.get("wallet"), 32, 1),
			"examine preview at 2 scraps: deltas (12,-1), affordable true, projected {gold: 32, scraps: 1}")

		_check(p_pa.get("gold_delta") == 0 and p_pa.get("scraps_delta") == 0
			and p_pa.get("affordable") == true and _wallet_exact_int(p_pa.get("wallet"), 20, 2),
			"pass preview at 2 scraps: deltas (0,0), affordable true, projected {gold: 20, scraps: 2}")

		_check(p_cu.get("gold_delta") == 28 and p_cu.get("scraps_delta") == -2
			and p_cu.get("affordable") == true and _wallet_exact_int(p_cu.get("wallet"), 48, 0),
			"cut_bindings preview at 2 scraps: deltas (28,-2), affordable true, projected {gold: 48, scraps: 0}")

	_check(service_2.is_valid() and not service_2.is_claimed(), "preview consumes no claim")
	_check(service_2.get_event() == record_snapshot and caller_event_2 == record_snapshot,
		"preview leaves selector and caller event records untouched")
	_check(wallet_2 == wallet_2_before, "preview leaves caller wallet untouched")
	_check(randi() == rng_2, "preview at 2 scraps spends no global RNG")

	# 2. Preview at {gold: 20, scraps: 1} -> examine and pass affordable, cut_bindings unaffordable
	var caller_event_1: Dictionary = record.duplicate(true)
	var wallet_1 := {"gold": 20, "scraps": 1}
	var wallet_1_before: Dictionary = wallet_1.duplicate(true)
	var rng_1 := _global_rng_start(81002)
	var service_1 := RunEventChoice.new(caller_event_1)
	var preview_1 := service_1.preview_wallet_choices(wallet_1)
	_check(preview_1.get("ok") == true, "preview at 1 scrap returns ok")
	var p1_by_id := {}
	for c in preview_1.get("choices", []):
		if c is Dictionary:
			p1_by_id[c.get("choice_id")] = c
	if p1_by_id.has("examine") and p1_by_id.has("pass") and p1_by_id.has("cut_bindings"):
		var p_ex1: Dictionary = p1_by_id["examine"]
		var p_pa1: Dictionary = p1_by_id["pass"]
		var p_cu1: Dictionary = p1_by_id["cut_bindings"]

		_check(p_ex1.get("affordable") == true and _wallet_exact_int(p_ex1.get("wallet"), 32, 0),
			"examine preview at 1 scrap: affordable true, projected {gold: 32, scraps: 0}")
		_check(p_pa1.get("affordable") == true and _wallet_exact_int(p_pa1.get("wallet"), 20, 1),
			"pass preview at 1 scrap: affordable true, projected {gold: 20, scraps: 1}")
		_check(p_cu1.get("affordable") == false and _wallet_exact_int(p_cu1.get("wallet"), 20, 1),
			"cut_bindings preview at 1 scrap: affordable false, projected unchanged {gold: 20, scraps: 1}")

	_check(service_1.is_valid() and not service_1.is_claimed(), "preview at 1 scrap consumes no claim")
	_check(wallet_1 == wallet_1_before, "preview at 1 scrap leaves caller wallet untouched")
	_check(randi() == rng_1, "preview at 1 scrap spends no global RNG")

	# 3. Preview at {gold: 20, scraps: 0} -> both examine and cut_bindings unaffordable, pass affordable
	var caller_event_0: Dictionary = record.duplicate(true)
	var wallet_0 := {"gold": 20, "scraps": 0}
	var wallet_0_before: Dictionary = wallet_0.duplicate(true)
	var rng_0 := _global_rng_start(81003)
	var service_0 := RunEventChoice.new(caller_event_0)
	var preview_0 := service_0.preview_wallet_choices(wallet_0)
	_check(preview_0.get("ok") == true, "preview at 0 scraps returns ok")
	var p0_by_id := {}
	for c in preview_0.get("choices", []):
		if c is Dictionary:
			p0_by_id[c.get("choice_id")] = c
	if p0_by_id.has("examine") and p0_by_id.has("pass") and p0_by_id.has("cut_bindings"):
		var p_ex0: Dictionary = p0_by_id["examine"]
		var p_pa0: Dictionary = p0_by_id["pass"]
		var p_cu0: Dictionary = p0_by_id["cut_bindings"]

		_check(p_ex0.get("affordable") == false and _wallet_exact_int(p_ex0.get("wallet"), 20, 0),
			"examine preview at 0 scraps: affordable false, projected unchanged {gold: 20, scraps: 0}")
		_check(p_pa0.get("affordable") == true and _wallet_exact_int(p_pa0.get("wallet"), 20, 0),
			"pass preview at 0 scraps: affordable true, projected {gold: 20, scraps: 0}")
		_check(p_cu0.get("affordable") == false and _wallet_exact_int(p_cu0.get("wallet"), 20, 0),
			"cut_bindings preview at 0 scraps: affordable false, projected unchanged {gold: 20, scraps: 0}")

	_check(service_0.is_valid() and not service_0.is_claimed(), "preview at 0 scraps consumes no claim")
	_check(wallet_0 == wallet_0_before, "preview at 0 scraps leaves caller wallet untouched")
	_check(randi() == rng_0, "preview at 0 scraps spends no global RNG")

	# Boundary parity checks against actual commit/refusal receipts (Lesson 39):
	# examine threshold: scraps=1 (affordable) vs scraps=0 (unaffordable)
	var commit_ex1 := RunEventChoice.new(record.duplicate(true)).choose_with_wallet("examine", {"gold": 20, "scraps": 1})
	_check(commit_ex1.get("ok") == true and commit_ex1.get("wallet") == p1_by_id["examine"].get("wallet"),
		"examine commit receipt at 1 scrap matches preview projection")

	var refuse_ex0 := RunEventChoice.new(record.duplicate(true)).choose_with_wallet("examine", {"gold": 20, "scraps": 0})
	_check(refuse_ex0.get("ok") == false and refuse_ex0.get("wallet") == p0_by_id["examine"].get("wallet"),
		"examine refusal receipt at 0 scraps matches preview unchanged wallet")

	# cut_bindings threshold: scraps=2 (affordable) vs scraps=1 (unaffordable)
	var commit_cu2 := RunEventChoice.new(record.duplicate(true)).choose_with_wallet("cut_bindings", {"gold": 20, "scraps": 2})
	_check(commit_cu2.get("ok") == true and commit_cu2.get("wallet") == p2_by_id["cut_bindings"].get("wallet"),
		"cut_bindings commit receipt at 2 scraps matches preview projection")

	var refuse_cu1 := RunEventChoice.new(record.duplicate(true)).choose_with_wallet("cut_bindings", {"gold": 20, "scraps": 1})
	_check(refuse_cu1.get("ok") == false and refuse_cu1.get("wallet") == p1_by_id["cut_bindings"].get("wallet"),
		"cut_bindings refusal receipt at 1 scrap matches preview unchanged wallet")


func _test_three_authored_outcomes_fresh_instances() -> void:
	if record.is_empty():
		return

	# Fresh instance 1: examine (+12 gold, -1 scrap) with {gold: 20, scraps: 2} -> {gold: 32, scraps: 1}
	var ex_caller_record: Dictionary = record.duplicate(true)
	var ex_wallet := {"gold": 20, "scraps": 2}
	var ex_wallet_before: Dictionary = ex_wallet.duplicate(true)
	var ex_rng := _global_rng_start(82001)
	var ex_service := RunEventChoice.new(ex_caller_record)
	_check(ex_service.is_valid() and not ex_service.is_claimed(), "fresh examine selector valid and unclaimed")
	var ex_result := ex_service.choose_with_wallet("examine", ex_wallet)
	_check(_wallet_shape_ok(ex_result), "examine returns four-key result shape")
	_check(ex_result.get("ok", false) == true, "examine choice succeeds")
	_check(ex_result.get("event_id", "") == EVENT_ID, "examine returns needle_gate event_id")
	_check(ex_result.get("choice_id", "") == "examine", "examine returns examine choice_id")
	_check(_wallet_exact_int(ex_result.get("wallet"), 32, 1),
		"examine settles {gold: 20, scraps: 2} to exact integer wallet {gold: 32, scraps: 1}")
	_check(_wallet_exact_int(ex_wallet, 20, 2) and ex_wallet == ex_wallet_before,
		"examine does not mutate caller wallet")
	_check(ex_caller_record == record_snapshot, "examine does not mutate caller record")
	_check(ex_service.get_event() == record_snapshot, "examine does not mutate selector snapshot")
	_check(ex_service.is_claimed() and not ex_service.is_valid(), "examine latches exactly one claim")
	_check(randi() == ex_rng, "examine settlement spends no global RNG")

	# Returned wallet is detached
	(ex_result["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(ex_wallet, 20, 2), "mutating examine result wallet does not mutate caller wallet")

	# Fresh instance 2: pass (+0 gold, +0 scraps) with {gold: 20, scraps: 2} -> {gold: 20, scraps: 2}
	var pa_caller_record: Dictionary = record.duplicate(true)
	var pa_wallet := {"gold": 20, "scraps": 2}
	var pa_wallet_before: Dictionary = pa_wallet.duplicate(true)
	var pa_rng := _global_rng_start(82002)
	var pa_service := RunEventChoice.new(pa_caller_record)
	_check(pa_service.is_valid() and not pa_service.is_claimed(), "fresh pass selector valid and unclaimed")
	var pa_result := pa_service.choose_with_wallet("pass", pa_wallet)
	_check(_wallet_shape_ok(pa_result), "pass returns four-key result shape")
	_check(pa_result.get("ok", false) == true, "pass choice succeeds")
	_check(pa_result.get("event_id", "") == EVENT_ID, "pass returns needle_gate event_id")
	_check(pa_result.get("choice_id", "") == "pass", "pass returns pass choice_id")
	_check(_wallet_exact_int(pa_result.get("wallet"), 20, 2),
		"pass settles {gold: 20, scraps: 2} to exact integer wallet {gold: 20, scraps: 2}")
	_check(_wallet_exact_int(pa_wallet, 20, 2) and pa_wallet == pa_wallet_before,
		"pass does not mutate caller wallet")
	_check(pa_caller_record == record_snapshot, "pass does not mutate caller record")
	_check(pa_service.get_event() == record_snapshot, "pass does not mutate selector snapshot")
	_check(pa_service.is_claimed() and not pa_service.is_valid(), "pass latches exactly one claim")
	_check(randi() == pa_rng, "pass settlement spends no global RNG")

	(pa_result["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(pa_wallet, 20, 2), "mutating pass result wallet does not mutate caller wallet")

	# Fresh instance 3: cut_bindings (+28 gold, -2 scraps) with {gold: 20, scraps: 2} -> {gold: 48, scraps: 0}
	var cu_caller_record: Dictionary = record.duplicate(true)
	var cu_wallet := {"gold": 20, "scraps": 2}
	var cu_wallet_before: Dictionary = cu_wallet.duplicate(true)
	var cu_rng := _global_rng_start(82003)
	var cu_service := RunEventChoice.new(cu_caller_record)
	_check(cu_service.is_valid() and not cu_service.is_claimed(), "fresh cut_bindings selector valid and unclaimed")
	var cu_result := cu_service.choose_with_wallet("cut_bindings", cu_wallet)
	_check(_wallet_shape_ok(cu_result), "cut_bindings returns four-key result shape")
	_check(cu_result.get("ok", false) == true, "cut_bindings choice succeeds")
	_check(cu_result.get("event_id", "") == EVENT_ID, "cut_bindings returns needle_gate event_id")
	_check(cu_result.get("choice_id", "") == "cut_bindings", "cut_bindings returns cut_bindings choice_id")
	_check(_wallet_exact_int(cu_result.get("wallet"), 48, 0),
		"cut_bindings settles {gold: 20, scraps: 2} to exact integer wallet {gold: 48, scraps: 0}")
	_check(_wallet_exact_int(cu_wallet, 20, 2) and cu_wallet == cu_wallet_before,
		"cut_bindings does not mutate caller wallet")
	_check(cu_caller_record == record_snapshot, "cut_bindings does not mutate caller record")
	_check(cu_service.get_event() == record_snapshot, "cut_bindings does not mutate selector snapshot")
	_check(cu_service.is_claimed() and not cu_service.is_valid(), "cut_bindings latches exactly one claim")
	_check(randi() == cu_rng, "cut_bindings settlement spends no global RNG")

	(cu_result["wallet"] as Dictionary)["scraps"] = 999
	_check(_wallet_exact_int(cu_wallet, 20, 2), "mutating cut_bindings result wallet does not mutate caller wallet")


func _test_insufficient_scraps_recovery_and_replay_same_selector() -> void:
	if record.is_empty():
		return

	# Sequence 1: At scraps=0, examine is refused; then pass succeeds on SAME selector; replay rejected
	var caller_1: Dictionary = record.duplicate(true)
	var wallet_0 := {"gold": 15, "scraps": 0}
	var wallet_0_before: Dictionary = wallet_0.duplicate(true)
	var rng_seq1 := _global_rng_start(83001)
	var service_1 := RunEventChoice.new(caller_1)

	var refusal_1 := service_1.choose_with_wallet("examine", wallet_0)
	_check(_wallet_shape_ok(refusal_1), "refused examine returns 4-key shape")
	_check(refusal_1.get("ok", true) == false, "examine with 0 scraps is refused")
	_check(refusal_1.get("event_id", "") == "" and refusal_1.get("choice_id", "") == "",
		"refused examine returns empty event/choice IDs")
	_check(_wallet_exact_int(refusal_1.get("wallet"), 15, 0),
		"refused examine returns detached unchanged wallet")
	_check(_wallet_exact_int(wallet_0, 15, 0), "refused examine does not mutate caller wallet")
	_check(not service_1.is_claimed() and service_1.is_valid(),
		"refused examine leaves selector valid and unclaimed")
	_check(service_1.get_event() == record_snapshot and caller_1 == record_snapshot,
		"refused examine preserves selector snapshot and caller record")
	_check(randi() == rng_seq1, "refused examine spends no global RNG")

	(refusal_1["wallet"] as Dictionary)["gold"] = 999
	_check(_wallet_exact_int(wallet_0, 15, 0), "mutating refused wallet does not mutate caller wallet")

	# Recovery on SAME selector: pass succeeds
	var pass_recovery_1 := service_1.choose_with_wallet("pass", wallet_0)
	_check(_wallet_shape_ok(pass_recovery_1) and pass_recovery_1.get("ok", false) == true,
		"pass succeeds on SAME selector after refused examine")
	_check(pass_recovery_1.get("event_id", "") == EVENT_ID and pass_recovery_1.get("choice_id", "") == "pass",
		"pass recovery returns needle_gate and pass choice ID")
	_check(_wallet_exact_int(pass_recovery_1.get("wallet"), 15, 0),
		"pass recovery settles exact wallet {gold: 15, scraps: 0}")
	_check(_wallet_exact_int(wallet_0, 15, 0) and wallet_0 == wallet_0_before,
		"pass recovery leaves caller wallet intact")
	_check(service_1.is_claimed() and not service_1.is_valid(),
		"pass recovery latches claim and consumes selector")

	# Replay on SAME selector fails across all choice IDs
	for replay_id in ["examine", "pass", "cut_bindings"]:
		var rng_rep := _global_rng_start(83002)
		var replay := service_1.choose_with_wallet(replay_id, {"gold": 15, "scraps": 2})
		_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
			and replay.get("event_id", "") == "" and replay.get("choice_id", "") == ""
			and _wallet_exact_int(replay.get("wallet"), 15, 2),
			"replay on claimed selector rejected with unchanged wallet: " + replay_id)
		_check(service_1.is_claimed() and not service_1.is_valid(),
			"replay leaves claim latched: " + replay_id)
		_check(randi() == rng_rep, "replay rejection spends no global RNG: " + replay_id)

	# Sequence 2: At scraps=0, cut_bindings is refused; then pass succeeds on SAME selector
	var caller_2: Dictionary = record.duplicate(true)
	var rng_seq2 := _global_rng_start(83003)
	var service_2 := RunEventChoice.new(caller_2)
	var refusal_2 := service_2.choose_with_wallet("cut_bindings", {"gold": 10, "scraps": 0})
	_check(_wallet_shape_ok(refusal_2) and refusal_2.get("ok", true) == false
		and _wallet_exact_int(refusal_2.get("wallet"), 10, 0),
		"cut_bindings with 0 scraps refused with unchanged wallet")
	_check(not service_2.is_claimed() and service_2.is_valid(),
		"refused cut_bindings at 0 scraps leaves selector unclaimed")
	_check(randi() == rng_seq2, "refused cut_bindings at 0 scraps spends no global RNG")

	var pass_recovery_2 := service_2.choose_with_wallet("pass", {"gold": 10, "scraps": 0})
	_check(_wallet_shape_ok(pass_recovery_2) and pass_recovery_2.get("ok", false) == true
		and _wallet_exact_int(pass_recovery_2.get("wallet"), 10, 0),
		"pass succeeds on SAME selector after cut_bindings refusal at 0 scraps")
	_check(service_2.is_claimed(), "selector claims exactly once after pass recovery")

	# Sequence 3: At scraps=1, cut_bindings (needs 2) is refused; then examine succeeds on SAME selector
	var caller_3: Dictionary = record.duplicate(true)
	var wallet_1 := {"gold": 10, "scraps": 1}
	var wallet_1_before: Dictionary = wallet_1.duplicate(true)
	var rng_seq3 := _global_rng_start(83004)
	var service_3 := RunEventChoice.new(caller_3)
	var refusal_3 := service_3.choose_with_wallet("cut_bindings", wallet_1)
	_check(_wallet_shape_ok(refusal_3) and refusal_3.get("ok", true) == false
		and _wallet_exact_int(refusal_3.get("wallet"), 10, 1),
		"cut_bindings with 1 scrap refused with unchanged wallet")
	_check(not service_3.is_claimed() and service_3.is_valid(),
		"refused cut_bindings at 1 scrap leaves selector unclaimed")
	_check(_wallet_exact_int(wallet_1, 10, 1) and wallet_1 == wallet_1_before,
		"caller wallet untouched by cut_bindings refusal at 1 scrap")
	_check(randi() == rng_seq3, "refused cut_bindings at 1 scrap spends no global RNG")

	# examine succeeds on SAME selector
	var examine_recovery_3 := service_3.choose_with_wallet("examine", wallet_1)
	_check(_wallet_shape_ok(examine_recovery_3) and examine_recovery_3.get("ok", false) == true
		and examine_recovery_3.get("event_id", "") == EVENT_ID
		and examine_recovery_3.get("choice_id", "") == "examine"
		and _wallet_exact_int(examine_recovery_3.get("wallet"), 22, 0),
		"examine succeeds on SAME selector after cut_bindings refusal at 1 scrap ({gold: 10, scraps: 1} -> {gold: 22, scraps: 0})")
	_check(service_3.is_claimed() and not service_3.is_valid(),
		"selector latches claim after recovered examine")

	# Replay after examine recovery rejected
	var replay_3 := service_3.choose_with_wallet("examine", {"gold": 22, "scraps": 0})
	_check(_wallet_shape_ok(replay_3) and replay_3.get("ok", true) == false
		and _wallet_exact_int(replay_3.get("wallet"), 22, 0),
		"replay after examine recovery rejected with unchanged wallet")


func _test_invalid_choice_rejections() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var wallet := {"gold": 20, "scraps": 2}
	var wallet_before: Dictionary = wallet.duplicate(true)
	var bad_choices: Array = [
		"", "   ", "unoffered", "examine ", " examine", "EXAMINE",
		"pass ", "Pass", "cut", "cut_bindings ", null, 15, 2.5, true,
		["examine"], {"id": "examine"},
	]
	for bad_choice in bad_choices:
		var expected_rng := _global_rng_start(84001)
		var service := RunEventChoice.new(caller_record)
		var rejected := service.choose_with_wallet(bad_choice, wallet)
		_check(_wallet_shape_ok(rejected), "invalid choice returns 4-key shape: " + str(bad_choice))
		_check(rejected.get("ok", true) == false, "invalid choice rejected: " + str(bad_choice))
		_check(rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == "",
			"invalid choice returns empty event/choice IDs: " + str(bad_choice))
		_check(_wallet_exact_int(rejected.get("wallet"), 20, 2),
			"invalid choice returns detached unchanged wallet: " + str(bad_choice))
		_check(not service.is_claimed() and service.is_valid(),
			"invalid choice does not consume visit: " + str(bad_choice))
		_check(service.get_event() == record_snapshot,
			"invalid choice leaves selector snapshot unchanged: " + str(bad_choice))
		_check(caller_record == record_snapshot and wallet == wallet_before,
			"invalid choice leaves caller record and wallet unchanged: " + str(bad_choice))
		_check(randi() == expected_rng, "invalid choice spends no global RNG: " + str(bad_choice))

	# Surviving selector can still settle after all invalid choice rejections
	var surviving_service := RunEventChoice.new(caller_record)
	for bad_choice in bad_choices:
		surviving_service.choose_with_wallet(bad_choice, wallet)
	var settled := surviving_service.choose_with_wallet("examine", wallet)
	_check(_wallet_shape_ok(settled) and settled.get("ok", false) == true
		and _wallet_exact_int(settled.get("wallet"), 32, 1),
		"valid choice succeeds on selector that survived all invalid choice attempts")
	_check(surviving_service.is_claimed() and not surviving_service.is_valid(),
		"surviving selector latches exactly one claim")


func _test_malformed_wallet_rejections() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var malformed: Dictionary = {
		"null wallet": null,
		"string wallet": "20",
		"int wallet": 20,
		"float wallet": 20.5,
		"array wallet": [20, 2],
		"empty dict": {},
		"missing scraps": {"gold": 20},
		"missing gold": {"scraps": 2},
		"extra key": {"gold": 20, "scraps": 2, "extra": 1},
		"negative gold": {"gold": -1, "scraps": 2},
		"negative scraps": {"gold": 20, "scraps": -1},
		"fractional gold": {"gold": 20.5, "scraps": 2},
		"fractional scraps": {"gold": 20, "scraps": 1.5},
		"float gold": {"gold": 20.0, "scraps": 2},
		"float scraps": {"gold": 20, "scraps": 2.0},
		"string gold": {"gold": "20", "scraps": 2},
		"string scraps": {"gold": 20, "scraps": "2"},
		"bool gold": {"gold": true, "scraps": 2},
		"bool scraps": {"gold": 20, "scraps": false},
		"null gold": {"gold": null, "scraps": 2},
		"inf gold": {"gold": INF, "scraps": 2},
		"nan scraps": {"gold": 20, "scraps": NAN},
	}
	for label in malformed:
		var bad_wallet: Variant = malformed[label]
		var before_wallet: Variant = bad_wallet.duplicate(true) if bad_wallet is Dictionary else null
		var expected_rng := _global_rng_start(85001)
		var service := RunEventChoice.new(caller_record)
		var rejected := service.choose_with_wallet("examine", bad_wallet)
		_check(_wallet_shape_ok(rejected), "malformed wallet returns 4-key shape: " + label)
		_check(rejected.get("ok", true) == false, "malformed wallet rejected: " + label)
		_check(rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == "",
			"malformed wallet returns empty IDs: " + label)
		_check((rejected.get("wallet") as Dictionary).is_empty(),
			"malformed wallet returns empty wallet dictionary: " + label)
		if bad_wallet is Dictionary and label != "nan scraps":
			_check(bad_wallet == before_wallet, "malformed caller wallet is not mutated: " + label)
		_check(not service.is_claimed() and service.is_valid(),
			"malformed wallet does not consume visit: " + label)
		_check(service.get_event() == record_snapshot and caller_record == record_snapshot,
			"malformed wallet leaves snapshot and record unchanged: " + label)
		_check(randi() == expected_rng, "malformed wallet spends no global RNG: " + label)

	# Surviving selector still settles a valid choice
	var surviving_service := RunEventChoice.new(caller_record)
	for label in malformed:
		surviving_service.choose_with_wallet("examine", malformed[label])
	var wallet := {"gold": 20, "scraps": 2}
	var accepted := surviving_service.choose_with_wallet("cut_bindings", wallet)
	_check(_wallet_shape_ok(accepted) and accepted.get("ok", false) == true
		and _wallet_exact_int(accepted.get("wallet"), 48, 0),
		"valid choice succeeds after surviving all malformed wallet attempts")
	_check(surviving_service.is_claimed(), "surviving selector latches claim")


func _test_replay_rejection_across_all_choices() -> void:
	if record.is_empty():
		return

	# Test replay on choices claimed via choose_with_wallet
	for initial_choice in ["examine", "pass", "cut_bindings"]:
		var service := RunEventChoice.new(record.duplicate(true))
		var wallet := {"gold": 20, "scraps": 2}
		var first_claim := service.choose_with_wallet(initial_choice, wallet)
		_check(first_claim.get("ok", false) == true, "first claim succeeds for: " + initial_choice)
		_check(service.is_claimed() and not service.is_valid(), "latches claim for: " + initial_choice)

		var expected_gold: int = (first_claim.get("wallet") as Dictionary).get("gold", 0)
		var expected_scraps: int = (first_claim.get("wallet") as Dictionary).get("scraps", 0)

		# Subsequent choose_with_wallet replay fails
		for replay_choice in ["examine", "pass", "cut_bindings"]:
			var replay := service.choose_with_wallet(replay_choice, {"gold": expected_gold, "scraps": expected_scraps})
			_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
				and replay.get("event_id", "") == "" and replay.get("choice_id", "") == ""
				and _wallet_exact_int(replay.get("wallet"), expected_gold, expected_scraps),
				"choose_with_wallet replay rejected after " + initial_choice + " when replaying: " + replay_choice)
			_check(service.is_claimed(), "replay does not unlatch claim: " + replay_choice)

		# Legacy choose() also rejects after choose_with_wallet claim
		var legacy_replay := service.choose(initial_choice)
		_check(legacy_replay.get("ok", true) == false, "legacy choose rejects after choose_with_wallet claim: " + initial_choice)

	# Test replay when initial choice was claimed via legacy choose()
	var legacy_service := RunEventChoice.new(record.duplicate(true))
	var legacy_first := legacy_service.choose("examine")
	_check(legacy_first.get("ok", false) == true and legacy_first.get("event_id", "") == EVENT_ID
		and legacy_first.get("choice_id", "") == "examine",
		"legacy choose succeeds and returns event_id and choice_id")
	_check(legacy_service.is_claimed() and not legacy_service.is_valid(),
		"legacy choose latches claim")

	# choose_with_wallet rejects after legacy choose claim
	var wallet_after_legacy := legacy_service.choose_with_wallet("pass", {"gold": 20, "scraps": 2})
	_check(wallet_after_legacy.get("ok", true) == false
		and _wallet_exact_int(wallet_after_legacy.get("wallet"), 20, 2),
		"choose_with_wallet rejects after legacy choose claim")


func _test_no_deck_hero_or_route_side_effects() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var service := RunEventChoice.new(caller_record)
	var wallet := {"gold": 20, "scraps": 2}
	var result := service.choose_with_wallet("examine", wallet)
	_check(result.size() == 4, "settled result carries exactly ok/event_id/choice_id/wallet")
	_check((result.get("wallet") as Dictionary).size() == 2,
		"settled wallet carries exactly gold/scraps")
	for key in result:
		_check(not str(key).to_lower().contains("deck") and not str(key).to_lower().contains("hero")
			and not str(key).to_lower().contains("route") and not str(key).to_lower().contains("hp"),
			"settled result exposes no deck/hero/route/hp key: " + str(key))
	for method in service.get_method_list():
		var method_name := String(method.get("name", "")).to_lower()
		_check(not method_name.contains("deck") and not method_name.contains("hero")
			and not method_name.contains("route") and not method_name.contains("heal")
			and not method_name.contains("hp"),
			"service exposes no deck/hero/route/heal/hp method: " + method_name)
	_check(service.get_event() == record_snapshot, "settled visit leaves authored record untouched")
	_check(caller_record == record_snapshot, "settled visit leaves caller record untouched")
	_check(_wallet_exact_int(wallet, 20, 2), "settled visit leaves caller wallet untouched")


func _test_seeded_rng_unchanged_and_repeatable_traces() -> void:
	if record.is_empty():
		return
	# Sentinel: the global-stream probe must be able to detect an injected draw.
	var sentinel := _global_rng_start(86001)
	randi()
	_check(randi() != sentinel, "global RNG probe detects an injected draw")

	var traces: Array = []
	for attempt in range(2):
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 86002
		var local_state := local_rng.state
		var expected_global := _global_rng_start(86002)
		var caller_record: Dictionary = record.duplicate(true)
		var wallet := {"gold": 20, "scraps": 2}
		var service := RunEventChoice.new(caller_record)

		# Preview
		var preview := service.preview_wallet_choices(wallet)
		# Rejected forged choice
		var forged := service.choose_with_wallet("invalid_choice", wallet)
		# Refused unaffordable choice on same selector
		var refused := service.choose_with_wallet("cut_bindings", {"gold": 20, "scraps": 0})
		# Successful choice on same selector
		var settled := service.choose_with_wallet("cut_bindings", wallet)
		# Rejected replay
		var replayed := service.choose_with_wallet("examine", wallet)

		_check(preview.get("ok", false) == true, "seeded trace preview succeeds")
		_check(forged.get("ok", true) == false, "seeded trace forged choice rejected")
		_check(refused.get("ok", true) == false, "seeded trace unaffordable choice refused")
		_check(settled.get("ok", false) == true and settled.get("event_id", "") == EVENT_ID
			and settled.get("choice_id", "") == "cut_bindings"
			and _wallet_exact_int(settled.get("wallet"), 48, 0),
			"seeded trace settles cut_bindings exactly")
		_check(replayed.get("ok", true) == false, "seeded trace replay rejected")
		_check(local_rng.state == local_state,
			"seeded local RNG state unchanged in attempt " + str(attempt))
		_check(randi() == expected_global,
			"seeded global RNG stream unchanged in attempt " + str(attempt))
		traces.append({
			"preview": preview,
			"forged": forged,
			"refused": refused,
			"settled": settled,
			"replayed": replayed,
			"wallet": wallet,
			"event": service.get_event(),
			"is_claimed": service.is_claimed(),
			"is_valid": service.is_valid(),
		})
	_check(traces.size() == 2 and traces[0] == traces[1],
		"two independent seeded visits produce identical deterministic traces")
