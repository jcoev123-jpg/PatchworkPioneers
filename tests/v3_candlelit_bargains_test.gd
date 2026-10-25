extends SceneTree
## Scene-free coverage of the separate, deliberately unrouted candlelit catalog.

const PATH := "res://data/events/v3_candlelit_bargains.json"
const EXPECTED := {
	"lantern_bobbin_ferry": {"title": "The Lantern Bobbin Ferry", "choices": {
		"buy_passage": [-12, 2], "ferry_parcels": [18, -1], "walk_bank": [0, 0]}},
	"thimble_star_reading": {"title": "The Thimble Star Reading", "choices": {
		"offer_thread": [16, -1], "gather_starlint": [0, 1], "pass_by": [0, 0]}},
	"moonpatch_archway": {"title": "The Moonpatch Archway", "choices": {
		"purchase_two_spools": [-15, 2], "sell_two_spools": [27, -2], "keep_walking": [0, 0]}},
	"blacklace_swap_table": {"title": "The Blacklace Swap Table", "choices": {
		"take_small_bundle": [-8, 1], "trade_own_bundle": [14, -1], "decline_trade": [0, 0]}},
	"crooked_marionette": {"title": "The Crooked Marionette", "choices": {
		"retie_strings": [30, -2], "gather_cuttings": [0, 1], "leave_puppet": [0, 0]}},
	"dusk_post_bobbin": {"title": "The Dusk Post Bobbin", "choices": {
		"send_letter": [-10, 1], "deliver_letters": [17, -1], "ignore_post": [0, 0]}},
}

var failures: Array[String] = []
var checks := 0


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _nonblank(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


func _initialize() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	_check(file != null, "catalog opens")
	if file != null:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		_check(error == OK, "catalog parses")
		if error == OK:
			var document: Variant = json.data
			_check(document is Dictionary and document.get("events") is Array, "events array exists")
			if document is Dictionary and document.get("events") is Array:
				_test_records(document.events)
	for failure in failures:
		printerr(failure)
	print("v3_candlelit_bargains_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_records(records: Array) -> void:
	var snapshot := records.duplicate(true)
	for id in EXPECTED:
		var matches: Array = records.filter(func(record): return record is Dictionary and record.get("id") == id)
		_check(matches.size() == 1, "required ID occurs exactly once: " + id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.get("title") == EXPECTED[id].title and _nonblank(record.get("description")), "readable authored presentation: " + id)
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(), "valid fresh selector: " + id)
		var choices: Variant = record.get("choices")
		_check(choices is Array, "choices array: " + id)
		if not choices is Array:
			continue
		_check(choices.size() >= 2 and choices.size() <= 3, "two or three choices: " + id)
		var seen := {}
		for choice in choices:
			_check(choice is Dictionary, "choice record: " + id)
			if not choice is Dictionary:
				continue
			var choice_id: Variant = choice.get("id")
			_check(_nonblank(choice_id) and not seen.has(choice_id), "distinct nonblank choice ID: " + id)
			seen[choice_id] = true
			_check(_nonblank(choice.get("text")), "readable choice text: " + id)
			_check(EXPECTED[id].choices.has(choice_id), "known choice: " + id)
			if not EXPECTED[id].choices.has(choice_id):
				continue
			var delta: Array = EXPECTED[id].choices[choice_id]
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "wallet outcome: " + id)
			if outcome is Dictionary:
				_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"), "precisely wallet keys: " + id)
				for index in range(2):
					var value: Variant = outcome.get(["gold", "scraps"][index])
					# Godot JSON parses JSON integer tokens as floats; require exact integral values.
					_check((typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and value == delta[index], "exact integral delta: " + id + "/" + str(choice_id))
			_test_choice(record, choice_id, delta)
		for choice_id in EXPECTED[id].choices:
			_check(seen.has(choice_id), "required choice exists: " + id + "/" + choice_id)
	_check(records == snapshot, "all authored inputs remain unchanged")


func _test_choice(record: Dictionary, choice_id: String, delta: Array) -> void:
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 100, "scraps": 10}
	var original := record.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 259
	var rng_state := rng.state
	var receipt := selector.choose_with_wallet(choice_id, wallet)
	var expected_wallet := {"gold": 100 + delta[0], "scraps": 10 + delta[1]}
	_check(receipt == {"ok": true, "event_id": record.id, "choice_id": choice_id, "wallet": expected_wallet}, "exact receipt: " + record.id + "/" + choice_id)
	_check(selector.is_claimed() and not selector.is_valid(), "success consumes visit")
	_check(wallet == {"gold": 100, "scraps": 10} and record == original, "success preserves inputs")
	_check(rng.state == rng_state, "success consumes no seeded RNG state")
	var replay := selector.choose_with_wallet(choice_id, receipt.wallet)
	_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": expected_wallet}, "replay rejects without another payment")
	replay.wallet.gold += 999
	_check(receipt.wallet == expected_wallet, "replay wallet detached from committed result")
	receipt.wallet.scraps += 999
	_check(wallet == {"gold": 100, "scraps": 10} and selector.get_event() == original, "success result detached from wallet and event")
	if delta[0] < 0 or delta[1] < 0:
		_test_unfunded(record, choice_id, delta)


func _test_unfunded(record: Dictionary, choice_id: String, delta: Array) -> void:
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 0 if delta[0] < 0 else 100, "scraps": 0 if delta[1] < 0 else 10}
	var before := wallet.duplicate(true)
	var record_before := record.duplicate(true)
	var receipt := selector.choose_with_wallet(choice_id, wallet)
	_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": before}, "unfunded debit rejects unchanged")
	_check(wallet == before and record == record_before and selector.is_valid() and not selector.is_claimed(), "rejection preserves inputs and visit")
	receipt.wallet.gold += 999
	_check(wallet == before, "rejection wallet detached")
	var exit_id := ""
	for candidate in EXPECTED[record.id].choices:
		if EXPECTED[record.id].choices[candidate] == [0, 0]:
			exit_id = candidate
	_check(not exit_id.is_empty(), "authored free exit exists")
	var exit_receipt := selector.choose_with_wallet(exit_id, wallet)
	_check(exit_receipt == {"ok": true, "event_id": record.id, "choice_id": exit_id, "wallet": before}
		and selector.is_claimed() and not selector.is_valid(), "same rejected selector permits free exit")
	_check(wallet == before and record == record_before, "free exit preserves inputs")
