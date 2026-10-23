extends SceneTree
## Deterministic headless test for the authored Quilting Bee M04 event.
## Loads/parses res://data/events/m04_events.json and verifies the new record
## plus the six pre-existing IDs remain intact. Exercises RunEventChoice for
## the three exact choice outcomes with wallet settlement, preview affordability,
## rejection/recovery, and replay/unknown-ID guards. No RNG use is permitted.

const EVENTS_PATH := "res://data/events/m04_events.json"

## The six pre-existing authored event IDs that must remain present.
const PREEXISTING := [
	"button_trail",
	"loose_seam",
	"thimble_well",
	"frayed_signpost",
	"quiet_spool",
	"needle_gate",
]

var failures: Array[String] = []
var checks := 0
var catalog: Array = []


func _initialize() -> void:
	_test_catalog_has_quilting_bee_and_preserves_six()
	_test_quilting_bee_record_exact_authored_fields()
	_test_quilting_bee_wallet_settlements()
	_test_quilting_bee_preview_affordability()
	_test_quilting_bee_rejections_and_recovery()
	_test_quilting_bee_unknown_id_and_replay()
	_test_quilting_bee_no_rng_consumption()
	_test_shared_catalog_unchanged()
	for failure in failures:
		print("FAILURE: ", failure)
	print("quilting_bee_event_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _wallet_shape_ok(result: Dictionary) -> bool:
	return (
		result.size() == 4
		and result.has("ok")
		and result.has("event_id")
		and result.has("choice_id")
		and result.has("wallet")
		and result.get("wallet") is Dictionary
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
		_is_integral_json_number(gold)
		and _is_integral_json_number(scraps, true)
		and int(gold) == expected_gold
		and int(scraps) == expected_scraps
	)


func _matching(event_id: String) -> Array:
	return catalog.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id
	)


func _is_integral_json_number(value: Variant, allow_negative: bool = false) -> bool:
	if typeof(value) == TYPE_INT:
		return allow_negative or int(value) >= 0
	if typeof(value) == TYPE_FLOAT:
		var num: float = value
		return (is_finite(num) and floor(num) == num
			and num <= RunEventChoice.MAX_SAFE_FLOAT_INT
			and num >= (-RunEventChoice.MAX_SAFE_FLOAT_INT if allow_negative else 0.0))
	return false


func _rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _test_catalog_has_quilting_bee_and_preserves_six() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "m04_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(text != "", "m04_events.json is non-empty")
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, "m04_events.json parses through JSON")
	var data: Variant = parser.data if parse_result == OK else null
	_check(data is Dictionary, "top level is a JSON object")
	if not data is Dictionary:
		return
	var list: Variant = (data as Dictionary).get("events")
	_check(list is Array, "top level has an events array")
	if not list is Array:
		return
	_check(not (list as Array).is_empty(), "events array is non-empty")
	catalog = list

	# Quilting Bee must be present exactly once.
	var quilting_matches := _matching("quilting_bee")
	_check(quilting_matches.size() == 1, "exactly one quilting_bee record in catalog")

	# All six pre-existing IDs must still be present exactly once.
	for id in PREEXISTING:
		var matches := _matching(id)
		_check(matches.size() == 1, "pre-existing event preserved exactly once: " + id)


func _test_quilting_bee_record_exact_authored_fields() -> void:
	var matches := _matching("quilting_bee")
	_check(matches.size() == 1, "quilting_bee record found for detailed validation")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]

	_check(record.size() == 4 and record.has("id") and record.has("title")
		and record.has("description") and record.has("choices"),
		"quilting_bee has exact top-level keys")
	_check(record.get("id") == "quilting_bee", "quilting_bee exact id")
	_check(record.get("title") == "The Quilting Bee", "quilting_bee exact title")
	_check(record.get("description") == "Neighbours gather around a half-sewn patchwork quilt, offering coins for help and spare thread for travellers.", "quilting_bee exact description")

	var choices: Variant = record.get("choices")
	_check(choices is Array, "choices is an array")
	if not choices is Array:
		return
	_check((choices as Array).size() == 3, "quilting_bee has exactly 3 choices")

	var expected_choices := {
		"sew_panel": "Sew a communal panel (spend 2 scraps; gain 32 gold)",
		"buy_thread": "Buy two thread bundles (spend 15 gold; gain 2 scraps)",
		"watch": "Watch the neighbours stitch (+1 scrap)",
	}
	var expected_outcomes := {
		"sew_panel": {"gold": 32, "scraps": -2},
		"buy_thread": {"gold": -15, "scraps": 2},
		"watch": {"gold": 0, "scraps": 1},
	}

	var seen := {}
	var by_id := {}
	for choice in choices:
		_check(choice is Dictionary, "each choice is a dictionary")
		if not choice is Dictionary:
			continue
		var choice_dict: Dictionary = choice
		var choice_id: Variant = choice_dict.get("id")
		var choice_text: Variant = choice_dict.get("text")
		_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(), "nonblank string choice id")
		_check(choice_text is String and not (choice_text as String).strip_edges().is_empty(), "nonblank string choice text")
		if not choice_id is String:
			continue
		_check(not seen.has(choice_id), "distinct choice ids")
		seen[choice_id] = true
		by_id[choice_id] = choice_dict

	for cid in expected_choices:
		_check(by_id.has(cid), "required choice present: " + cid)
		if by_id.has(cid):
			_check(by_id[cid].get("text") == expected_choices[cid], "exact choice text: " + cid)
			_check(by_id[cid].size() == 3 and by_id[cid].has("id") and by_id[cid].has("text") and by_id[cid].has("outcome"), "choice has exact keys id/text/outcome: " + cid)
			var raw_outcome: Variant = by_id[cid].get("outcome")
			_check(raw_outcome is Dictionary, "choice outcome is a dictionary: " + cid)
			if raw_outcome is Dictionary:
				var outcome: Dictionary = raw_outcome
				_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"), "outcome has exact gold/scraps keys: " + cid)
				var raw_gold: Variant = outcome.get("gold")
				var raw_scraps: Variant = outcome.get("scraps")
				var allow_negative_gold: bool = (cid == "buy_thread")
				_check(_is_integral_json_number(raw_gold, allow_negative_gold), "outcome gold is integral: " + cid)
				_check(_is_integral_json_number(raw_scraps, true), "outcome scraps is integral signed: " + cid)
				if _is_integral_json_number(raw_gold) and _is_integral_json_number(raw_scraps, true):
					_check(int(raw_gold) == expected_outcomes[cid]["gold"] and int(raw_scraps) == expected_outcomes[cid]["scraps"], "exact outcome deltas: " + cid)

	_check(seen.size() == expected_choices.size(), "no extra choice IDs beyond the three authored")

	# Verify the record builds a valid RunEventChoice.
	var service := RunEventChoice.new(record)
	_check(service.has_method("choose") and service.has_method("choose_with_wallet"), "RunEventChoice exposes choose and choose_with_wallet")
	_check(service.is_valid(), "quilting_bee builds a valid selector")
	_check(not service.is_claimed(), "fresh selector is unclaimed")


func _test_quilting_bee_wallet_settlements() -> void:
	var matches := _matching("quilting_bee")
	_check(matches.size() == 1, "quilting_bee present for wallet settlement tests")
	if matches.size() != 1:
		return
	var authored_record: Dictionary = matches[0]
	var original_event: Dictionary = authored_record.duplicate(true)

	# 1) sew_panel: spend 2 scraps, gain 32 gold.
	#    From {gold: 0, scraps: 2} -> {gold: 32, scraps: 0}
	var sew_input: Dictionary = authored_record.duplicate(true)
	var sew_wallet := {"gold": 0, "scraps": 2}
	var sew_rng := _rng_start(70001)
	var sew_service := RunEventChoice.new(sew_input)
	_check(sew_service.is_valid() and not sew_service.is_claimed(), "fresh quilting_bee valid before sew_panel")
	var sew_result := sew_service.choose_with_wallet("sew_panel", sew_wallet)
	_check(_wallet_shape_ok(sew_result), "sew_panel returns 4-key wallet shape")
	_check(sew_result.get("ok", false) == true, "sew_panel choose_with_wallet succeeds")
	_check(sew_result.get("event_id", "") == "quilting_bee", "sew_panel returns quilting_bee event_id")
	_check(sew_result.get("choice_id", "") == "sew_panel", "sew_panel returns sew_panel choice_id")
	_check(_wallet_exact_int(sew_result.get("wallet"), 32, 0), "sew_panel settles exact wallet {gold: 32, scraps: 0}")
	_check(_wallet_exact_int(sew_wallet, 0, 2), "sew_panel does not mutate caller input wallet")
	_check(sew_input == original_event, "sew_panel does not mutate caller input event")
	_check(sew_service.get_event() == original_event, "sew_panel does not mutate internal snapshot")
	_check(sew_service.is_claimed() and not sew_service.is_valid(), "sew_panel latches claim and marks selector consumed")
	_check(randi() == sew_rng, "sew_panel settlement spends no global RNG")

	# 2) buy_thread: spend 15 gold, gain 2 scraps.
	#    From {gold: 15, scraps: 0} -> {gold: 0, scraps: 2}
	var buy_input: Dictionary = authored_record.duplicate(true)
	var buy_wallet := {"gold": 15, "scraps": 0}
	var buy_rng := _rng_start(70002)
	var buy_service := RunEventChoice.new(buy_input)
	_check(buy_service.is_valid() and not buy_service.is_claimed(), "fresh quilting_bee valid before buy_thread")
	var buy_result := buy_service.choose_with_wallet("buy_thread", buy_wallet)
	_check(_wallet_shape_ok(buy_result), "buy_thread returns 4-key wallet shape")
	_check(buy_result.get("ok", false) == true, "buy_thread choose_with_wallet succeeds")
	_check(buy_result.get("event_id", "") == "quilting_bee", "buy_thread returns quilting_bee event_id")
	_check(buy_result.get("choice_id", "") == "buy_thread", "buy_thread returns buy_thread choice_id")
	_check(_wallet_exact_int(buy_result.get("wallet"), 0, 2), "buy_thread settles exact wallet {gold: 0, scraps: 2}")
	_check(_wallet_exact_int(buy_wallet, 15, 0), "buy_thread does not mutate caller input wallet")
	_check(buy_input == original_event, "buy_thread does not mutate caller input event")
	_check(buy_service.get_event() == original_event, "buy_thread does not mutate internal snapshot")
	_check(buy_service.is_claimed() and not buy_service.is_valid(), "buy_thread latches claim and marks selector consumed")
	_check(randi() == buy_rng, "buy_thread settlement spends no global RNG")

	# 3) watch: gain 1 scrap.
	#    From {gold: 0, scraps: 0} -> {gold: 0, scraps: 1}
	var watch_input: Dictionary = authored_record.duplicate(true)
	var watch_wallet := {"gold": 0, "scraps": 0}
	var watch_rng := _rng_start(70003)
	var watch_service := RunEventChoice.new(watch_input)
	_check(watch_service.is_valid() and not watch_service.is_claimed(), "fresh quilting_bee valid before watch")
	var watch_result := watch_service.choose_with_wallet("watch", watch_wallet)
	_check(_wallet_shape_ok(watch_result), "watch returns 4-key wallet shape")
	_check(watch_result.get("ok", false) == true, "watch choose_with_wallet succeeds")
	_check(watch_result.get("event_id", "") == "quilting_bee", "watch returns quilting_bee event_id")
	_check(watch_result.get("choice_id", "") == "watch", "watch returns watch choice_id")
	_check(_wallet_exact_int(watch_result.get("wallet"), 0, 1), "watch settles exact wallet {gold: 0, scraps: 1}")
	_check(_wallet_exact_int(watch_wallet, 0, 0), "watch does not mutate caller input wallet")
	_check(watch_input == original_event, "watch does not mutate caller input event")
	_check(watch_service.get_event() == original_event, "watch does not mutate internal snapshot")
	_check(watch_service.is_claimed() and not watch_service.is_valid(), "watch latches claim and marks selector consumed")
	_check(randi() == watch_rng, "watch settlement spends no global RNG")

	# Verify source wallet and seeded RNG are unchanged after all three.
	_check(_wallet_exact_int(sew_wallet, 0, 2), "sew_panel caller wallet unchanged after all")
	_check(_wallet_exact_int(buy_wallet, 15, 0), "buy_thread caller wallet unchanged after all")
	_check(_wallet_exact_int(watch_wallet, 0, 0), "watch caller wallet unchanged after all")


func _test_quilting_bee_preview_affordability() -> void:
	var matches := _matching("quilting_bee")
	_check(matches.size() == 1, "quilting_bee present for preview tests")
	if matches.size() != 1:
		return
	var authored_record: Dictionary = matches[0]
	var original_event: Dictionary = authored_record.duplicate(true)

	# Preview with 1 scrap (just below sew_panel's 2 scraps threshold): sew_panel unaffordable.
	var preview_low_event: Dictionary = authored_record.duplicate(true)
	var preview_low_wallet := {"gold": 0, "scraps": 1}
	var preview_low_rng := _rng_start(70101)
	var preview_low_service := RunEventChoice.new(preview_low_event)
	_check(preview_low_service.is_valid() and not preview_low_service.is_claimed(), "fresh quilting_bee valid before preview with 1 scrap")
	var preview_low := preview_low_service.preview_wallet_choices(preview_low_wallet)
	_check(preview_low.get("ok") == true and preview_low.get("event_id") == "quilting_bee", "preview with 1 scrap returns ok with quilting_bee event_id")
	var sew_entry := {}
	var buy_entry := {}
	var watch_entry := {}
	for entry in preview_low.get("choices", []):
		if entry.get("choice_id") == "sew_panel":
			sew_entry = entry
		elif entry.get("choice_id") == "buy_thread":
			buy_entry = entry
		elif entry.get("choice_id") == "watch":
			watch_entry = entry
	_check(not sew_entry.is_empty(), "sew_panel preview entry present")
	_check(sew_entry.get("gold_delta") == 32 and sew_entry.get("scraps_delta") == -2, "sew_panel preview shows exact deltas +32 gold, -2 scraps")
	_check(sew_entry.get("affordable") == false, "sew_panel unaffordable with 1 scrap")
	_check(_wallet_exact_int(sew_entry.get("wallet"), 0, 1), "sew_panel preview projects unchanged wallet with 1 scrap")

	_check(not buy_entry.is_empty(), "buy_thread preview entry present")
	_check(buy_entry.get("gold_delta") == -15 and buy_entry.get("scraps_delta") == 2, "buy_thread preview shows exact deltas -15 gold, +2 scraps")
	_check(buy_entry.get("affordable") == false, "buy_thread unaffordable with 0 gold")
	_check(_wallet_exact_int(buy_entry.get("wallet"), 0, 1), "buy_thread preview projects unchanged wallet with 0 gold")

	_check(not watch_entry.is_empty(), "watch preview entry present")
	_check(watch_entry.get("gold_delta") == 0 and watch_entry.get("scraps_delta") == 1, "watch preview shows exact deltas 0 gold, +1 scrap")
	_check(watch_entry.get("affordable") == true, "watch affordable with 1 scrap")
	_check(_wallet_exact_int(watch_entry.get("wallet"), 0, 2), "watch preview projects wallet {gold: 0, scraps: 2}")

	_check(preview_low_service.is_valid() and not preview_low_service.is_claimed()
		and preview_low_service.get_event() == original_event
		and preview_low_event == original_event
		and _wallet_exact_int(preview_low_wallet, 0, 1),
		"preview with 1 scrap consumes no claim and leaves state unchanged")
	_check(randi() == preview_low_rng, "preview with 1 scrap spends no global RNG")

	# Preview with 14 gold (just below buy_thread's 15 gold threshold): buy_thread unaffordable.
	var preview_14_event: Dictionary = authored_record.duplicate(true)
	var preview_14_wallet := {"gold": 14, "scraps": 0}
	var preview_14_rng := _rng_start(70102)
	var preview_14_service := RunEventChoice.new(preview_14_event)
	_check(preview_14_service.is_valid() and not preview_14_service.is_claimed(), "fresh quilting_bee valid before preview with 14 gold")
	var preview_14 := preview_14_service.preview_wallet_choices(preview_14_wallet)
	_check(preview_14.get("ok") == true and preview_14.get("event_id") == "quilting_bee", "preview with 14 gold returns ok with quilting_bee event_id")
	var sew_entry_14 := {}
	var buy_entry_14 := {}
	for entry in preview_14.get("choices", []):
		if entry.get("choice_id") == "sew_panel":
			sew_entry_14 = entry
		elif entry.get("choice_id") == "buy_thread":
			buy_entry_14 = entry
	_check(not buy_entry_14.is_empty(), "buy_thread preview entry present at 14 gold")
	_check(buy_entry_14.get("gold_delta") == -15 and buy_entry_14.get("scraps_delta") == 2, "buy_thread preview at 14 gold shows exact deltas")
	_check(buy_entry_14.get("affordable") == false, "buy_thread unaffordable at 14 gold")
	_check(_wallet_exact_int(buy_entry_14.get("wallet"), 14, 0), "buy_thread preview at 14 gold projects unchanged wallet")
	_check(not sew_entry_14.is_empty(), "sew_panel preview entry present at 14 gold")
	_check(sew_entry_14.get("affordable") == false, "sew_panel unaffordable at 14 gold (0 scraps)")
	_check(preview_14_service.is_valid() and not preview_14_service.is_claimed()
		and preview_14_service.get_event() == original_event
		and preview_14_event == original_event
		and _wallet_exact_int(preview_14_wallet, 14, 0),
		"preview with 14 gold consumes no claim and leaves state unchanged")
	_check(randi() == preview_14_rng, "preview with 14 gold spends no global RNG")

	# Preview at exact thresholds: 2 scraps for sew_panel, 15 gold for buy_thread.
	var preview_exact_event: Dictionary = authored_record.duplicate(true)
	var preview_exact_wallet := {"gold": 15, "scraps": 2}
	var preview_exact_rng := _rng_start(70103)
	var preview_exact_service := RunEventChoice.new(preview_exact_event)
	var preview_exact := preview_exact_service.preview_wallet_choices(preview_exact_wallet)
	_check(preview_exact.get("ok") == true and preview_exact.get("event_id") == "quilting_bee", "preview at exact thresholds returns ok")
	for entry in preview_exact.get("choices", []):
		var cid: String = entry.get("choice_id")
		if cid == "sew_panel":
			_check(entry.get("affordable") == true, "sew_panel affordable at exactly 2 scraps")
			_check(_wallet_exact_int(entry.get("wallet"), 47, 0), "sew_panel preview projects {gold: 47, scraps: 0}")
		elif cid == "buy_thread":
			_check(entry.get("affordable") == true, "buy_thread affordable at exactly 15 gold")
			_check(_wallet_exact_int(entry.get("wallet"), 0, 4), "buy_thread preview projects {gold: 0, scraps: 4}")
		elif cid == "watch":
			_check(entry.get("affordable") == true, "watch affordable at 2 scraps")
			_check(_wallet_exact_int(entry.get("wallet"), 15, 3), "watch preview projects {gold: 15, scraps: 3}")
	_check(preview_exact_service.is_valid() and not preview_exact_service.is_claimed()
		and preview_exact_service.get_event() == original_event
		and preview_exact_event == original_event
		and _wallet_exact_int(preview_exact_wallet, 15, 2),
		"preview at exact thresholds consumes no claim and leaves state unchanged")
	_check(randi() == preview_exact_rng, "preview at exact thresholds spends no global RNG")


func _test_quilting_bee_rejections_and_recovery() -> void:
	var matches := _matching("quilting_bee")
	_check(matches.size() == 1, "quilting_bee present for rejection/recovery tests")
	if matches.size() != 1:
		return
	var authored_record: Dictionary = matches[0]
	var original_event: Dictionary = authored_record.duplicate(true)

	# sew_panel with 1 scrap (insufficient) -> reject, no claim, then retry with 2 scraps on SAME selector -> succeed.
	var poor_sew_event: Dictionary = authored_record.duplicate(true)
	var poor_sew_wallet := {"gold": 0, "scraps": 1}
	var poor_sew_rng := _rng_start(70201)
	var poor_sew_service := RunEventChoice.new(poor_sew_event)
	_check(poor_sew_service.is_valid() and not poor_sew_service.is_claimed(), "fresh quilting_bee valid before refused sew_panel (1 scrap)")
	var poor_sew_refusal := poor_sew_service.choose_with_wallet("sew_panel", poor_sew_wallet)
	_check(_wallet_shape_ok(poor_sew_refusal) and poor_sew_refusal.get("ok", true) == false
		and poor_sew_refusal.get("event_id", "") == "" and poor_sew_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_sew_refusal.get("wallet"), 0, 1),
		"sew_panel with 1 scrap refused with exact unchanged wallet")
	_check(poor_sew_service.is_valid() and not poor_sew_service.is_claimed()
		and _wallet_exact_int(poor_sew_wallet, 0, 1)
		and poor_sew_service.get_event() == original_event and poor_sew_event == original_event,
		"refused sew_panel consumes no visit and keeps both snapshots")

	# Recovery on SAME selector with 2 scraps.
	var sew_recovery := poor_sew_service.choose_with_wallet("sew_panel", {"gold": 0, "scraps": 2})
	_check(_wallet_shape_ok(sew_recovery) and sew_recovery.get("ok", false) == true
		and sew_recovery.get("event_id", "") == "quilting_bee"
		and sew_recovery.get("choice_id", "") == "sew_panel"
		and _wallet_exact_int(sew_recovery.get("wallet"), 32, 0),
		"sew_panel recovers on SAME selector after refused sew_panel with 2 scraps")
	_check(poor_sew_service.is_claimed() and not poor_sew_service.is_valid()
		and _wallet_exact_int(poor_sew_wallet, 0, 1) and poor_sew_event == original_event
		and poor_sew_service.get_event() == original_event,
		"recovered sew_panel latches exactly one claim and spends nothing")
	_check(randi() == poor_sew_rng, "refused sew_panel and recovery spend no global RNG")

	# buy_thread with 14 gold (insufficient) -> reject, no claim, then retry with 15 gold on SAME selector -> succeed.
	var poor_buy_event: Dictionary = authored_record.duplicate(true)
	var poor_buy_wallet := {"gold": 14, "scraps": 0}
	var poor_buy_rng := _rng_start(70202)
	var poor_buy_service := RunEventChoice.new(poor_buy_event)
	_check(poor_buy_service.is_valid() and not poor_buy_service.is_claimed(), "fresh quilting_bee valid before refused buy_thread (14 gold)")
	var poor_buy_refusal := poor_buy_service.choose_with_wallet("buy_thread", poor_buy_wallet)
	_check(_wallet_shape_ok(poor_buy_refusal) and poor_buy_refusal.get("ok", true) == false
		and poor_buy_refusal.get("event_id", "") == "" and poor_buy_refusal.get("choice_id", "") == ""
		and _wallet_exact_int(poor_buy_refusal.get("wallet"), 14, 0),
		"buy_thread with 14 gold refused with exact unchanged wallet")
	_check(poor_buy_service.is_valid() and not poor_buy_service.is_claimed()
		and _wallet_exact_int(poor_buy_wallet, 14, 0)
		and poor_buy_service.get_event() == original_event and poor_buy_event == original_event,
		"refused buy_thread consumes no visit and keeps both snapshots")

	# Recovery on SAME selector with 15 gold.
	var buy_recovery := poor_buy_service.choose_with_wallet("buy_thread", {"gold": 15, "scraps": 0})
	_check(_wallet_shape_ok(buy_recovery) and buy_recovery.get("ok", false) == true
		and buy_recovery.get("event_id", "") == "quilting_bee"
		and buy_recovery.get("choice_id", "") == "buy_thread"
		and _wallet_exact_int(buy_recovery.get("wallet"), 0, 2),
		"buy_thread recovers on SAME selector after refused buy_thread with 15 gold")
	_check(poor_buy_service.is_claimed() and not poor_buy_service.is_valid()
		and _wallet_exact_int(poor_buy_wallet, 14, 0) and poor_buy_event == original_event
		and poor_buy_service.get_event() == original_event,
		"recovered buy_thread latches exactly one claim and spends nothing")
	_check(randi() == poor_buy_rng, "refused buy_thread and recovery spend no global RNG")


func _test_quilting_bee_unknown_id_and_replay() -> void:
	var matches := _matching("quilting_bee")
	_check(matches.size() == 1, "quilting_bee present for unknown-id/replay tests")
	if matches.size() != 1:
		return
	var authored_record: Dictionary = matches[0]
	var original_event: Dictionary = authored_record.duplicate(true)

	# Unknown choice ID rejected, selector remains unclaimed.
	var unknown_service := RunEventChoice.new(authored_record.duplicate(true))
	var valid_wallet := {"gold": 15, "scraps": 2}
	var unknown_rng := _rng_start(70301)
	var unknown_rejection := unknown_service.choose_with_wallet("not_a_choice", valid_wallet)
	_check(_wallet_shape_ok(unknown_rejection) and unknown_rejection.get("ok", true) == false
		and unknown_rejection.get("event_id", "") == "" and unknown_rejection.get("choice_id", "") == ""
		and _wallet_exact_int(unknown_rejection.get("wallet"), 15, 2),
		"unknown choice ID rejected with unchanged wallet")
	_check(not unknown_service.is_claimed() and unknown_service.is_valid()
		and _wallet_exact_int(valid_wallet, 15, 2)
		and unknown_service.get_event() == original_event,
		"unknown choice ID consumes no visit and leaves selector valid")
	_check(randi() == unknown_rng, "unknown choice ID spends no global RNG")

	# Successful claim then replay rejected.
	var replay_service := RunEventChoice.new(authored_record.duplicate(true))
	var replay_wallet := {"gold": 0, "scraps": 2}
	var replay_rng := _rng_start(70302)
	var first_claim := replay_service.choose_with_wallet("sew_panel", replay_wallet)
	_check(first_claim.get("ok", false) == true, "first sew_panel claim succeeds")
	_check(replay_service.is_claimed() and not replay_service.is_valid(), "first claim latches")

	# Replay same choice ID.
	var replay_same := replay_service.choose_with_wallet("sew_panel", {"gold": 32, "scraps": 0})
	_check(_wallet_shape_ok(replay_same) and replay_same.get("ok", true) == false
		and replay_same.get("event_id", "") == "" and replay_same.get("choice_id", "") == ""
		and _wallet_exact_int(replay_same.get("wallet"), 32, 0),
		"replay of same choice rejected with unchanged wallet")

	# Replay different choice ID.
	var replay_diff := replay_service.choose_with_wallet("buy_thread", {"gold": 32, "scraps": 0})
	_check(_wallet_shape_ok(replay_diff) and replay_diff.get("ok", true) == false
		and replay_diff.get("event_id", "") == "" and replay_diff.get("choice_id", "") == ""
		and _wallet_exact_int(replay_diff.get("wallet"), 32, 0),
		"replay of different choice rejected with unchanged wallet")

	# Legacy choose() also rejects after choose_with_wallet claim.
	var legacy_replay := replay_service.choose("sew_panel")
	_check(legacy_replay.size() == 3 and legacy_replay.get("ok", true) == false, "legacy choose() rejects after choose_with_wallet claim")

	_check(replay_service.is_claimed() and replay_service.get_event() == original_event,
		"replay attempts keep claim latched and snapshot unchanged")
	_check(randi() == replay_rng, "claim and replays spend no global RNG")


func _test_quilting_bee_no_rng_consumption() -> void:
	var matches := _matching("quilting_bee")
	_check(matches.size() == 1, "quilting_bee present for RNG test")
	if matches.size() != 1:
		return
	var authored_record: Dictionary = matches[0]

	# Global RNG must not advance during any operation.
	# Preview does not consume RNG.
	var preview_rng := _rng_start(70401)
	var preview_service := RunEventChoice.new(authored_record.duplicate(true))
	_check(preview_service.is_valid() and not preview_service.is_claimed(), "fresh quilting_bee valid for preview")
	preview_service.preview_wallet_choices({"gold": 100, "scraps": 100})
	_check(randi() == preview_rng, "preview_wallet_choices spends no global RNG")

	# choose_with_wallet sew_panel does not consume RNG.
	var sew_rng := _rng_start(70402)
	var sew_service := RunEventChoice.new(authored_record.duplicate(true))
	_check(sew_service.is_valid() and not sew_service.is_claimed(), "fresh quilting_bee valid for sew_panel")
	sew_service.choose_with_wallet("sew_panel", {"gold": 0, "scraps": 2})
	_check(randi() == sew_rng, "choose_with_wallet sew_panel spends no global RNG")

	# choose_with_wallet buy_thread does not consume RNG.
	var buy_rng := _rng_start(70403)
	var buy_service := RunEventChoice.new(authored_record.duplicate(true))
	_check(buy_service.is_valid() and not buy_service.is_claimed(), "fresh quilting_bee valid for buy_thread")
	buy_service.choose_with_wallet("buy_thread", {"gold": 15, "scraps": 0})
	_check(randi() == buy_rng, "choose_with_wallet buy_thread spends no global RNG")

	# choose_with_wallet watch does not consume RNG.
	var watch_rng := _rng_start(70404)
	var watch_service := RunEventChoice.new(authored_record.duplicate(true))
	_check(watch_service.is_valid() and not watch_service.is_claimed(), "fresh quilting_bee valid for watch")
	watch_service.choose_with_wallet("watch", {"gold": 0, "scraps": 0})
	_check(randi() == watch_rng, "choose_with_wallet watch spends no global RNG")


func _test_shared_catalog_unchanged() -> void:
	# Re-read the catalog and ensure all seven IDs are present.
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		return
	var parser := JSON.new()
	parser.parse(file.get_as_text())
	file.close()
	if parser.data is Dictionary:
		var list: Variant = (parser.data as Dictionary).get("events")
		if list is Array:
			var ids: Array = []
			for entry in list:
				if entry is Dictionary and entry.has("id"):
					ids.append(entry.get("id"))
			for id in PREEXISTING:
				_check(ids.has(id), "shared catalog still contains pre-existing: " + id)
			_check(ids.has("quilting_bee"), "shared catalog contains quilting_bee")