extends SceneTree
## Deterministic headless regression for the authored M04 Thimble Exchange event.
##
## Reads and JSON-parses the real data/events/thimble_exchange.json and checks
## the authored record per choice ID (text and gold/scraps deltas) instead of
## trusting a hand-written fixture. It then drives the scene-free
## RunEventChoice service for both authored outcomes, for the unaffordable
## trade followed by the free alternative, and for the fail-closed paths
## (unknown choice, malformed wallet, replay). Every flow also proves that the
## authored file, the parsed record, the selector snapshot and the caller's
## wallet stay unchanged, that the service exposes no deck/hero/route side
## effect, and that no seeded RNG stream drifts.

const EVENT_PATH := "res://data/events/thimble_exchange.json"

const EVENT_ID := "thimble_exchange"
const EVENT_TITLE := "The Thimble Exchange"
const EVENT_DESCRIPTION := "A thimble merchant offers coins for loose thread beside a basket of cast-off stitching."

const REQUIRED_CHOICES := {
	"gather_thread": {
		"text": "Gather loose thread (+2 scraps)",
		"gold": 0,
		"scraps": 2,
	},
	"trade_scrap": {
		"text": "Trade 1 scrap for 10 gold",
		"gold": 10,
		"scraps": -1,
	},
}

var failures: Array[String] = []
var checks := 0
var record: Dictionary = {}
var record_snapshot: Dictionary = {}
var file_text: String = ""


func _initialize() -> void:
	_test_authored_record()
	_test_gather_thread_wallet()
	_test_trade_scrap_wallet()
	_test_unaffordable_trade_then_alternative()
	_test_invalid_choice_rejections()
	_test_malformed_wallet_rejections()
	_test_replay_rejection()
	_test_no_deck_hero_or_route_side_effects()
	_test_seeded_rng_unchanged_and_repeatable_traces()
	_check(record == record_snapshot, "parsed authored record unchanged by every flow")
	_check(_read_file_text() == file_text, "authored event file bytes unchanged by every flow")
	for failure in failures:
		printerr(failure)
	print("thimble_exchange_event_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_file_text() -> String:
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
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


func _test_authored_record() -> void:
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	_check(file != null, "thimble_exchange.json opens through FileAccess")
	if file == null:
		return
	file_text = file.get_as_text()
	file.close()
	_check(file_text != "", "thimble_exchange.json is non-empty")

	var parser := JSON.new()
	var parse_result := parser.parse(file_text)
	_check(parse_result == OK, "thimble_exchange.json parses through JSON")
	var data: Variant = parser.data if parse_result == OK else null
	_check(data is Dictionary, "thimble_exchange.json top level is a JSON object")
	if not data is Dictionary:
		return

	var parsed: Dictionary = data
	_check(parsed.size() == 4 and parsed.has("id") and parsed.has("title")
		and parsed.has("description") and parsed.has("choices"),
		"authored event has exactly the id/title/description/choices keys")
	_check(parsed.get("id") == EVENT_ID, "authored event ID is thimble_exchange")
	_check(parsed.get("title") == EVENT_TITLE, "authored title is The Thimble Exchange")
	_check(parsed.get("description") == EVENT_DESCRIPTION, "authored description matches")
	_check(typeof(parsed.get("id")) == TYPE_STRING and typeof(parsed.get("title")) == TYPE_STRING
		and typeof(parsed.get("description")) == TYPE_STRING,
		"authored id/title/description are strings")

	var choices: Variant = parsed.get("choices")
	_check(choices is Array, "authored choices is an array")
	if not choices is Array:
		return
	var choice_list: Array = choices
	_check(choice_list.size() == 2, "authored event has exactly two choices")
	_check(choice_list.size() >= 2 and choice_list.size() <= 3,
		"authored choice count stays inside the 2-3 event rule")

	var seen := {}
	var by_id := {}
	for choice in choice_list:
		_check(choice is Dictionary, "every authored choice is an object")
		if not choice is Dictionary:
			continue
		var choice_dict: Dictionary = choice
		_check(choice_dict.size() == 3 and choice_dict.has("id")
			and choice_dict.has("text") and choice_dict.has("outcome"),
			"authored choice has exactly the id/text/outcome keys")
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
		_check(REQUIRED_CHOICES.has(choice_id), "authored choice ID is one of the two authored IDs: " + choice_id)

	for choice_id in REQUIRED_CHOICES:
		_check(by_id.has(choice_id), "required authored choice present: " + choice_id)
		_check((seen.keys() as Array).count(choice_id) == 1,
			"exactly one authored choice carries the ID: " + choice_id)
		if not by_id.has(choice_id):
			continue
		var expected: Dictionary = REQUIRED_CHOICES[choice_id]
		var choice_dict: Dictionary = by_id[choice_id]
		_check(choice_dict.get("text") == expected["text"], "authored choice text: " + choice_id)
		var raw_outcome: Variant = choice_dict.get("outcome")
		_check(raw_outcome is Dictionary, "authored outcome is an object: " + choice_id)
		if not raw_outcome is Dictionary:
			continue
		var outcome: Dictionary = raw_outcome
		_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"),
			"authored outcome has exactly the gold/scraps keys: " + choice_id)
		var raw_gold: Variant = outcome.get("gold")
		var raw_scraps: Variant = outcome.get("scraps")
		_check(_is_integral_json_number(raw_gold),
			"authored outcome gold is an integral nonnegative number: " + choice_id)
		_check(_is_integral_json_number(raw_scraps, true),
			"authored outcome scraps is an integral signed number: " + choice_id)
		if _is_integral_json_number(raw_gold) and _is_integral_json_number(raw_scraps, true):
			_check(int(raw_gold) == int(expected["gold"]) and int(raw_scraps) == int(expected["scraps"]),
				"authored outcome matches the exact gold/scraps delta: " + choice_id)

	record = parsed.duplicate(true)
	record_snapshot = parsed.duplicate(true)

	var service := RunEventChoice.new(record)
	_check(service.is_valid(), "authored record builds a valid RunEventChoice")
	_check(not service.is_claimed(), "fresh Thimble Exchange selector is unclaimed")
	_check(service.get_event() == record, "selector snapshot equals the authored record")
	_check(record == record_snapshot, "constructing the selector does not mutate the authored record")


func _test_gather_thread_wallet() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var wallet := {"gold": 0, "scraps": 0}
	var wallet_before: Dictionary = wallet.duplicate(true)
	var expected_rng := _global_rng_start(77001)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 77001
	var local_state := local_rng.state

	var service := RunEventChoice.new(caller_record)
	_check(service.is_valid() and not service.is_claimed(), "fresh selector valid before gather_thread")
	var result := service.choose_with_wallet("gather_thread", wallet)
	_check(_wallet_shape_ok(result), "gather_thread returns the exact four-key result shape")
	_check(result.get("ok", false) == true, "gather_thread claim succeeds")
	_check(result.get("event_id", "") == EVENT_ID, "gather_thread returns the exact event ID")
	_check(result.get("choice_id", "") == "gather_thread", "gather_thread returns the exact choice ID")
	_check(_wallet_exact_int(result.get("wallet"), 0, 2),
		"gather_thread settles {gold: 0, scraps: 0} to {gold: 0, scraps: 2}")
	_check(_wallet_exact_int(wallet, 0, 0), "gather_thread does not mutate the caller wallet")
	_check(caller_record == record_snapshot, "gather_thread does not mutate the caller record")
	_check(service.get_event() == record_snapshot, "gather_thread leaves the selector snapshot unchanged")
	_check(service.is_claimed() and not service.is_valid(), "gather_thread latches exactly one claim")
	_check(local_rng.state == local_state, "gather_thread spends no local seeded RNG")
	_check(randi() == expected_rng, "gather_thread spends no global seeded RNG")

	# The returned dictionaries are detached: mutating them cannot reach the
	# selector, the caller wallet or a later settlement.
	(result["wallet"] as Dictionary)["gold"] = 999
	(result["wallet"] as Dictionary)["scraps"] = 999
	(result as Dictionary)["ok"] = false
	_check(_wallet_exact_int(wallet, 0, 0), "mutating the gather_thread result cannot change the caller wallet")
	_check(service.get_event() == record_snapshot, "mutating the gather_thread result cannot change the snapshot")
	_check(service.is_claimed(), "mutating the gather_thread result cannot release the claim")


func _test_trade_scrap_wallet() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var wallet := {"gold": 17, "scraps": 3}
	var expected_rng := _global_rng_start(77002)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 77002
	var local_state := local_rng.state

	var service := RunEventChoice.new(caller_record)
	_check(service.is_valid() and not service.is_claimed(), "fresh selector valid before trade_scrap")
	var result := service.choose_with_wallet("trade_scrap", wallet)
	_check(_wallet_shape_ok(result), "trade_scrap returns the exact four-key result shape")
	_check(result.get("ok", false) == true, "trade_scrap claim succeeds")
	_check(result.get("event_id", "") == EVENT_ID, "trade_scrap returns the exact event ID")
	_check(result.get("choice_id", "") == "trade_scrap", "trade_scrap returns the exact choice ID")
	_check(_wallet_exact_int(result.get("wallet"), 27, 2),
		"trade_scrap settles {gold: 17, scraps: 3} to {gold: 27, scraps: 2}")
	_check(_wallet_exact_int(wallet, 17, 3), "trade_scrap does not mutate the caller wallet")
	_check(caller_record == record_snapshot, "trade_scrap does not mutate the caller record")
	_check(service.get_event() == record_snapshot, "trade_scrap leaves the selector snapshot unchanged")
	_check(service.is_claimed() and not service.is_valid(), "trade_scrap latches exactly one claim")
	_check(local_rng.state == local_state, "trade_scrap spends no local seeded RNG")
	_check(randi() == expected_rng, "trade_scrap spends no global seeded RNG")

	(result["wallet"] as Dictionary)["gold"] = -1
	_check(_wallet_exact_int(wallet, 17, 3), "mutating the trade_scrap result cannot change the caller wallet")
	_check(service.get_event() == record_snapshot, "mutating the trade_scrap result cannot change the snapshot")


func _test_unaffordable_trade_then_alternative() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var wallet := {"gold": 5, "scraps": 0}
	var expected_rng := _global_rng_start(77003)

	var service := RunEventChoice.new(caller_record)
	var refusal := service.choose_with_wallet("trade_scrap", wallet)
	_check(_wallet_shape_ok(refusal), "unaffordable trade returns the exact four-key result shape")
	_check(refusal.get("ok", true) == false, "unaffordable trade is rejected")
	_check(refusal.get("event_id", "") == "" and refusal.get("choice_id", "") == "",
		"unaffordable trade returns empty event/choice IDs")
	_check(_wallet_exact_int(refusal.get("wallet"), 5, 0),
		"unaffordable trade returns the detached unchanged wallet")
	_check(_wallet_exact_int(wallet, 5, 0), "unaffordable trade does not spend the caller wallet")
	_check(not service.is_claimed() and service.is_valid(),
		"unaffordable trade does not latch the claim")
	_check(service.get_event() == record_snapshot, "unaffordable trade leaves the snapshot unchanged")
	_check(caller_record == record_snapshot, "unaffordable trade leaves the caller record unchanged")
	(refusal["wallet"] as Dictionary)["scraps"] = 7
	_check(_wallet_exact_int(wallet, 5, 0), "mutating the refused wallet cannot change the caller wallet")

	# The same visit still offers the free alternative.
	var recovered := service.choose_with_wallet("gather_thread", wallet)
	_check(_wallet_shape_ok(recovered), "gather_thread after the refused trade returns the result shape")
	_check(recovered.get("ok", false) == true, "gather_thread succeeds after the refused trade")
	_check(recovered.get("event_id", "") == EVENT_ID
		and recovered.get("choice_id", "") == "gather_thread",
		"gather_thread after the refused trade returns the exact IDs")
	_check(_wallet_exact_int(recovered.get("wallet"), 5, 2),
		"gather_thread after the refused trade settles {gold: 5, scraps: 2}")
	_check(_wallet_exact_int(wallet, 5, 0), "the recovered claim does not mutate the caller wallet")
	_check(service.is_claimed() and not service.is_valid(), "the recovered claim latches exactly one claim")
	_check(randi() == expected_rng, "the refused trade and the recovery spend no global seeded RNG")


func _test_invalid_choice_rejections() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var wallet := {"gold": 4, "scraps": 1}
	var bad_choices: Array = [
		"", "   ", "unknown_choice", "gather", "gather_thread ", " gather_thread",
		"GATHER_THREAD", "gather-thread", null, 12, 1.5, true, ["gather_thread"],
		{"id": "gather_thread"},
	]
	for bad_choice in bad_choices:
		var expected_rng := _global_rng_start(77004)
		var service := RunEventChoice.new(caller_record)
		var rejected := service.choose_with_wallet(bad_choice, wallet)
		_check(_wallet_shape_ok(rejected), "invalid choice returns the result shape: " + str(bad_choice))
		_check(rejected.get("ok", true) == false, "invalid choice is rejected: " + str(bad_choice))
		_check(rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == "",
			"invalid choice returns empty event/choice IDs: " + str(bad_choice))
		_check(_wallet_exact_int(rejected.get("wallet"), 4, 1),
			"invalid choice returns the detached unchanged wallet: " + str(bad_choice))
		_check(not service.is_claimed() and service.is_valid(),
			"invalid choice does not consume the visit: " + str(bad_choice))
		_check(service.get_event() == record_snapshot,
			"invalid choice leaves the selector snapshot unchanged: " + str(bad_choice))
		_check(caller_record == record_snapshot,
			"invalid choice leaves the caller record unchanged: " + str(bad_choice))
		_check(randi() == expected_rng, "invalid choice spends no global seeded RNG: " + str(bad_choice))

	# The visit survives every rejection and still settles a valid choice.
	var service := RunEventChoice.new(caller_record)
	for bad_choice in bad_choices:
		service.choose_with_wallet(bad_choice, wallet)
	var accepted := service.choose_with_wallet("gather_thread", wallet)
	_check(_wallet_shape_ok(accepted) and accepted.get("ok", false) == true
		and accepted.get("event_id", "") == EVENT_ID
		and accepted.get("choice_id", "") == "gather_thread"
		and _wallet_exact_int(accepted.get("wallet"), 4, 3),
		"a valid choice still succeeds after every invalid choice was rejected")
	_check(service.is_claimed() and not service.is_valid(),
		"the surviving visit latches exactly one claim")


func _test_malformed_wallet_rejections() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var malformed: Dictionary = {
		"null wallet": null,
		"string wallet": "4",
		"int wallet": 4,
		"float wallet": 4.5,
		"array wallet": [4, 1],
		"empty dict": {},
		"missing scraps": {"gold": 4},
		"missing gold": {"scraps": 1},
		"extra key": {"gold": 4, "scraps": 1, "hp": 3},
		"negative gold": {"gold": -1, "scraps": 1},
		"negative scraps": {"gold": 4, "scraps": -1},
		"fractional gold": {"gold": 4.5, "scraps": 1},
		"fractional scraps": {"gold": 4, "scraps": 0.5},
		"float gold": {"gold": 4.0, "scraps": 1},
		"float scraps": {"gold": 4, "scraps": 1.0},
		"string gold": {"gold": "4", "scraps": 1},
		"string scraps": {"gold": 4, "scraps": "1"},
		"bool gold": {"gold": true, "scraps": 1},
		"bool scraps": {"gold": 4, "scraps": false},
		"null gold": {"gold": null, "scraps": 1},
		"inf gold": {"gold": INF, "scraps": 1},
		"nan scraps": {"gold": 4, "scraps": NAN},
	}
	for label in malformed:
		var bad_wallet: Variant = malformed[label]
		var before_wallet: Variant = bad_wallet.duplicate(true) if bad_wallet is Dictionary else null
		var expected_rng := _global_rng_start(77005)
		var service := RunEventChoice.new(caller_record)
		var rejected := service.choose_with_wallet("gather_thread", bad_wallet)
		_check(_wallet_shape_ok(rejected), "malformed wallet returns the result shape: " + label)
		_check(rejected.get("ok", true) == false, "malformed wallet is rejected: " + label)
		_check(rejected.get("event_id", "") == "" and rejected.get("choice_id", "") == "",
			"malformed wallet returns empty event/choice IDs: " + label)
		_check((rejected.get("wallet") as Dictionary).is_empty(),
			"malformed wallet returns an empty wallet dictionary: " + label)
		if bad_wallet is Dictionary and label != "nan scraps":
			_check(bad_wallet == before_wallet, "malformed caller wallet is not mutated: " + label)
		_check(not service.is_claimed() and service.is_valid(),
			"malformed wallet does not consume the visit: " + label)
		_check(service.get_event() == record_snapshot,
			"malformed wallet leaves the selector snapshot unchanged: " + label)
		_check(caller_record == record_snapshot,
			"malformed wallet leaves the caller record unchanged: " + label)
		_check(randi() == expected_rng, "malformed wallet spends no global seeded RNG: " + label)

	# The visit survives every malformed wallet and still settles a valid one.
	var service := RunEventChoice.new(caller_record)
	for label in malformed:
		service.choose_with_wallet("gather_thread", malformed[label])
	var wallet := {"gold": 4, "scraps": 1}
	var accepted := service.choose_with_wallet("gather_thread", wallet)
	_check(_wallet_shape_ok(accepted) and accepted.get("ok", false) == true
		and accepted.get("event_id", "") == EVENT_ID
		and accepted.get("choice_id", "") == "gather_thread"
		and _wallet_exact_int(accepted.get("wallet"), 4, 3),
		"a valid choice still succeeds after every malformed wallet was rejected")
	_check(service.is_claimed() and not service.is_valid(),
		"the surviving visit latches exactly one claim")


func _test_replay_rejection() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var wallet := {"gold": 9, "scraps": 1}
	var expected_rng := _global_rng_start(77006)
	var service := RunEventChoice.new(caller_record)
	var first := service.choose_with_wallet("gather_thread", wallet)
	_check(first.get("ok", false) == true, "the first Thimble Exchange claim succeeds")
	_check(service.is_claimed() and not service.is_valid(), "the first claim latches the visit")

	var replay_wallet := {"gold": 9, "scraps": 3}
	var replay := service.choose_with_wallet("trade_scrap", replay_wallet)
	_check(_wallet_shape_ok(replay), "the replay returns the exact four-key result shape")
	_check(replay.get("ok", true) == false, "a second choice after a claim is rejected")
	_check(replay.get("event_id", "") == "" and replay.get("choice_id", "") == "",
		"the rejected replay returns empty event/choice IDs")
	_check(_wallet_exact_int(replay.get("wallet"), 9, 3),
		"the rejected replay returns the detached unchanged wallet")
	_check(_wallet_exact_int(replay_wallet, 9, 3), "the rejected replay does not mutate the caller wallet")
	_check(service.is_claimed(), "the rejected replay consumes no extra claim")
	_check(service.get_event() == record_snapshot, "the rejected replay leaves the snapshot unchanged")
	_check(caller_record == record_snapshot, "the rejected replay leaves the caller record unchanged")

	var legacy := service.choose("trade_scrap")
	_check(legacy.get("ok", true) == false, "the legacy claim path also rejects a second choice")
	_check(service.is_claimed() and not service.is_valid(), "the visit stays claimed after the rejected replay")
	_check(randi() == expected_rng, "the claim and the rejected replay spend no global seeded RNG")


func _test_no_deck_hero_or_route_side_effects() -> void:
	if record.is_empty():
		return
	var caller_record: Dictionary = record.duplicate(true)
	var service := RunEventChoice.new(caller_record)
	var wallet := {"gold": 6, "scraps": 2}
	var result := service.choose_with_wallet("gather_thread", wallet)
	_check(result.size() == 4, "the settled result carries exactly ok/event_id/choice_id/wallet")
	_check((result.get("wallet") as Dictionary).size() == 2,
		"the settled wallet carries exactly gold/scraps")
	for key in result:
		_check(not str(key).to_lower().contains("deck") and not str(key).to_lower().contains("hero")
			and not str(key).to_lower().contains("route") and not str(key).to_lower().contains("hp"),
			"the settled result exposes no deck/hero/route/hp state: " + str(key))
	for method in service.get_method_list():
		var method_name := String(method.get("name", "")).to_lower()
		_check(not method_name.contains("deck") and not method_name.contains("hero")
			and not method_name.contains("route") and not method_name.contains("heal")
			and not method_name.contains("hp"),
			"the service exposes no deck/hero/route/heal/hp side effect: " + method_name)
	_check(service.get_event() == record_snapshot, "the settled visit leaves the authored record untouched")
	_check(caller_record == record_snapshot, "the settled visit leaves the caller record untouched")
	_check(_wallet_exact_int(wallet, 6, 2), "the settled visit leaves the caller wallet untouched")


func _test_seeded_rng_unchanged_and_repeatable_traces() -> void:
	if record.is_empty():
		return
	# Sentinel: the global-stream probe must be able to detect an injected draw.
	var sentinel := _global_rng_start(77007)
	randi()
	_check(randi() != sentinel, "the global RNG probe detects an injected draw")

	var traces: Array = []
	for attempt in range(2):
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 77008
		var local_state := local_rng.state
		var expected_global := _global_rng_start(77008)
		var caller_record: Dictionary = record.duplicate(true)
		var wallet := {"gold": 17, "scraps": 3}
		var service := RunEventChoice.new(caller_record)
		var forged := service.choose_with_wallet("not_a_choice", wallet)
		var refused := service.choose_with_wallet("trade_scrap", {"gold": 17, "scraps": 0})
		var settled := service.choose_with_wallet("trade_scrap", wallet)
		var replayed := service.choose_with_wallet("gather_thread", wallet)
		_check(forged.get("ok", true) == false and refused.get("ok", true) == false,
			"seeded trace rejects the forged and the unaffordable choice")
		_check(settled.get("ok", false) == true and settled.get("event_id", "") == EVENT_ID
			and settled.get("choice_id", "") == "trade_scrap"
			and _wallet_exact_int(settled.get("wallet"), 27, 2),
			"seeded trace settles the trade exactly")
		_check(replayed.get("ok", true) == false, "seeded trace rejects the replay")
		_check(local_rng.state == local_state,
			"seeded local RNG state is unchanged in attempt " + str(attempt))
		_check(randi() == expected_global,
			"seeded global RNG stream is unchanged in attempt " + str(attempt))
		traces.append({
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
		"two independent seeded visits produce identical traces")
