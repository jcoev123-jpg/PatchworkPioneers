extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_test_api_contract()
	_test_ac1_watch_rewards_and_deterministic_replay()
	_test_ac2_ignore_preserves_balance_and_unrelated_fixtures()
	_test_ac3_rejections_recovery_replays_and_rng_invariance()

	if _failures.is_empty():
		print("PASS: run_quiet_spool_outcome_test")
		quit(0)
		return

	for failure: String in _failures:
		printerr("FAIL: %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_exact_receipt(
	receipt: Dictionary,
	expected_ok: bool,
	expected_event_id: String,
	expected_choice_id: String,
	expected_scraps: int,
	context: String
) -> void:
	_check(receipt.size() == 4, "%s: receipt must have exactly 4 keys, got %d" % [context, receipt.size()])
	_check(
		receipt.has("ok") and typeof(receipt["ok"]) == TYPE_BOOL and bool(receipt["ok"]) == expected_ok,
		"%s: receipt.ok expected %s, got %s" % [context, str(expected_ok), str(receipt.get("ok"))]
	)
	_check(
		receipt.has("event_id") and typeof(receipt["event_id"]) == TYPE_STRING and String(receipt["event_id"]) == expected_event_id,
		"%s: receipt.event_id expected '%s', got '%s'" % [context, expected_event_id, str(receipt.get("event_id"))]
	)
	_check(
		receipt.has("choice_id") and typeof(receipt["choice_id"]) == TYPE_STRING and String(receipt["choice_id"]) == expected_choice_id,
		"%s: receipt.choice_id expected '%s', got '%s'" % [context, expected_choice_id, str(receipt.get("choice_id"))]
	)
	_check(
		receipt.has("scraps") and typeof(receipt["scraps"]) == TYPE_INT and int(receipt["scraps"]) == expected_scraps,
		"%s: receipt.scraps expected %d, got %s" % [context, expected_scraps, str(receipt.get("scraps"))]
	)


func _build_unrelated_run_fixture() -> Dictionary:
	return {
		"gold": 37,
		"deck": ["strike", "defend", "mend", "thread_lance"],
		"party_hp": [
			{"hero_id": "vanguard", "slot": 0, "hp": 24, "max_hp": 30},
			{"hero_id": "weaver", "slot": 1, "hp": 18, "max_hp": 22},
			{"hero_id": "needle", "slot": 2, "hp": 15, "max_hp": 20},
		],
		"route": {
			"row": 2,
			"current_node_id": "r2_n1_event",
			"visited_node_ids": ["r0_n0_fight", "r1_n1_fight", "r2_n1_event"],
			"available_next": ["r3_n0_shop", "r3_n1_rest"],
		},
		"records": {
			"fights_won": 2,
			"elites_won": 0,
			"events_claimed": 0,
			"event_meta": {
				"id": "quiet_spool",
				"title": "The Quiet Spool",
				"description": "An abandoned spool spins without a breeze.",
				"choices": {
					"watch": "Watch the thread unwind",
					"ignore": "Leave the spool alone",
				},
			},
		},
	}


func _run_deterministic_trace(seed_value: int) -> Array[Dictionary]:
	seed(seed_value)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value

	var trace: Array[Dictionary] = []

	var visit_zero := RunQuietSpoolOutcome.new()
	var step_zero_before: bool = visit_zero.is_consumed()
	var step_zero_res: Dictionary = visit_zero.choose("quiet_spool", "watch", 0)
	var step_zero_replay: Dictionary = visit_zero.choose("quiet_spool", "watch", int(step_zero_res.get("scraps", -1)))
	trace.append({
		"before": step_zero_before,
		"first": step_zero_res.duplicate(true),
		"replay": step_zero_replay.duplicate(true),
		"after": visit_zero.is_consumed(),
	})

	var visit_recover := RunQuietSpoolOutcome.new()
	var bad_first: Dictionary = visit_recover.choose("quiet_spool", "Watch", 1)
	var bad_before_valid: bool = visit_recover.is_consumed()
	var valid_retry: Dictionary = visit_recover.choose("quiet_spool", "watch", 1)
	trace.append({
		"bad_first": bad_first.duplicate(true),
		"consumed_after_bad": bad_before_valid,
		"valid_retry": valid_retry.duplicate(true),
		"consumed_after_retry": visit_recover.is_consumed(),
	})

	var visit_four := RunQuietSpoolOutcome.new()
	var step_four_res: Dictionary = visit_four.choose("quiet_spool", "watch", 4)
	trace.append({
		"four_res": step_four_res.duplicate(true),
		"four_consumed": visit_four.is_consumed(),
		"post_global_draw": randi(),
		"post_local_draw": local_rng.randi(),
	})
	return trace


func _test_api_contract() -> void:
	var outcome := RunQuietSpoolOutcome.new()
	var outcome_obj: Object = outcome
	_check(outcome != null, "RunQuietSpoolOutcome.new() must return a non-null instance")
	_check(outcome_obj is RefCounted, "RunQuietSpoolOutcome must extend RefCounted")
	_check(not (outcome_obj is Node), "RunQuietSpoolOutcome must be scene-free and not extend Node")
	_check(outcome.has_method("choose"), "RunQuietSpoolOutcome must expose choose()")
	_check(outcome.has_method("is_consumed"), "RunQuietSpoolOutcome must expose is_consumed()")
	_check(outcome.is_consumed() == false, "Fresh RunQuietSpoolOutcome must start unconsumed")


func _test_ac1_watch_rewards_and_deterministic_replay() -> void:
	var visit_from_zero := RunQuietSpoolOutcome.new()
	_check(not visit_from_zero.is_consumed(), "AC1: visit_from_zero must start unconsumed")
	var receipt_zero: Dictionary = visit_from_zero.choose("quiet_spool", "watch", 0)
	_assert_exact_receipt(receipt_zero, true, "quiet_spool", "watch", 1, "AC1 watch from 0")
	_check(visit_from_zero.is_consumed(), "AC1: visit_from_zero must latch consumed after valid watch")

	var visit_from_four := RunQuietSpoolOutcome.new()
	_check(not visit_from_four.is_consumed(), "AC1: visit_from_four must start unconsumed")
	var receipt_four: Dictionary = visit_from_four.choose("quiet_spool", "watch", 4)
	_assert_exact_receipt(receipt_four, true, "quiet_spool", "watch", 5, "AC1 watch from 4")
	_check(visit_from_four.is_consumed(), "AC1: visit_from_four must latch consumed after valid watch")

	# Receipt isolation check: mutating a returned Dictionary must not affect subsequent calls or other instances.
	var other_visit := RunQuietSpoolOutcome.new()
	var other_receipt: Dictionary = other_visit.choose("quiet_spool", "watch", 4)
	receipt_four["ok"] = false
	receipt_four["scraps"] = 999
	receipt_four["injected"] = true
	_assert_exact_receipt(other_receipt, true, "quiet_spool", "watch", 5, "AC1 isolated receipt after mutation")
	_check(visit_from_four.is_consumed(), "AC1: mutating returned dictionary must not unconsume visit")

	var trace_a: Array[Dictionary] = _run_deterministic_trace(774109)
	var trace_b: Array[Dictionary] = _run_deterministic_trace(774109)
	_check(trace_a.size() == 3, "AC1: deterministic trace must record all 3 steps")
	_check(trace_a == trace_b, "AC1: two independently repeated seeded traces must be identical")


func _test_ac2_ignore_preserves_balance_and_unrelated_fixtures() -> void:
	var fixture: Dictionary = _build_unrelated_run_fixture()
	var fixture_snapshot: Dictionary = fixture.duplicate(true)
	var deck_before: Array = (fixture["deck"] as Array).duplicate()
	var route_visited_before: Array = ((fixture["route"] as Dictionary)["visited_node_ids"] as Array).duplicate()

	var ignore_zero := RunQuietSpoolOutcome.new()
	_check(not ignore_zero.is_consumed(), "AC2: ignore_zero must start unconsumed")
	var receipt_ignore_zero: Dictionary = ignore_zero.choose("quiet_spool", "ignore", 0)
	_assert_exact_receipt(receipt_ignore_zero, true, "quiet_spool", "ignore", 0, "AC2 ignore from 0")
	_check(ignore_zero.is_consumed(), "AC2: ignore_zero must latch consumed after valid ignore")

	var ignore_four := RunQuietSpoolOutcome.new()
	_check(not ignore_four.is_consumed(), "AC2: ignore_four must start unconsumed")
	var receipt_ignore_four: Dictionary = ignore_four.choose("quiet_spool", "ignore", 4)
	_assert_exact_receipt(receipt_ignore_four, true, "quiet_spool", "ignore", 4, "AC2 ignore from 4")
	_check(ignore_four.is_consumed(), "AC2: ignore_four must latch consumed after valid ignore")

	var watch_with_fixture := RunQuietSpoolOutcome.new()
	var receipt_watch_four: Dictionary = watch_with_fixture.choose("quiet_spool", "watch", 4)
	_assert_exact_receipt(receipt_watch_four, true, "quiet_spool", "watch", 5, "AC2 watch alongside fixture")

	_check(fixture == fixture_snapshot, "AC2: watch and ignore must leave unrelated gold, deck, HP, route and records unchanged")
	_check(fixture["deck"] == deck_before, "AC2: deck order must remain exact")
	_check((fixture["route"] as Dictionary)["visited_node_ids"] == route_visited_before, "AC2: route visited order must remain exact")


func _test_ac3_rejections_recovery_replays_and_rng_invariance() -> void:
	var rng_seed: int = 918273645
	seed(rng_seed)
	var expected_global_first_draw: int = randi()

	# Prove the global RNG check is non-vacuous if an extra draw occurs.
	seed(rng_seed)
	var _consumed_draw: int = randi()
	var shifted_global_draw: int = randi()
	_check(
		shifted_global_draw != expected_global_first_draw,
		"AC3: RNG probe precondition must detect an extra global randi() draw"
	)

	# Re-seed global RNG and independent RandomNumberGenerator before exercising RunQuietSpoolOutcome.
	seed(rng_seed)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = rng_seed
	var initial_local_rng_state: int = local_rng.state

	var recoverable_visit := RunQuietSpoolOutcome.new()
	var invalid_cases: Array[Dictionary] = [
		{"event_id": "", "choice_id": "watch", "scraps": 4, "expected_scraps": 4, "label": "blank event_id"},
		{"event_id": "other_event", "choice_id": "watch", "scraps": 4, "expected_scraps": 4, "label": "foreign event_id"},
		{"event_id": "Quiet_Spool", "choice_id": "watch", "scraps": 4, "expected_scraps": 4, "label": "title-case event_id"},
		{"event_id": "QUIET_SPOOL", "choice_id": "watch", "scraps": 4, "expected_scraps": 4, "label": "upper-case event_id"},
		{"event_id": " quiet_spool", "choice_id": "watch", "scraps": 4, "expected_scraps": 4, "label": "leading-space event_id"},
		{"event_id": "quiet_spool ", "choice_id": "watch", "scraps": 4, "expected_scraps": 4, "label": "trailing-space event_id"},
		{"event_id": "quiet_spool\n", "choice_id": "watch", "scraps": 4, "expected_scraps": 4, "label": "newline event_id"},
		{"event_id": "quiet_spool", "choice_id": "", "scraps": 4, "expected_scraps": 4, "label": "blank choice_id"},
		{"event_id": "quiet_spool", "choice_id": "take", "scraps": 4, "expected_scraps": 4, "label": "foreign choice_id"},
		{"event_id": "quiet_spool", "choice_id": "Watch", "scraps": 4, "expected_scraps": 4, "label": "title-case Watch"},
		{"event_id": "quiet_spool", "choice_id": "WATCH", "scraps": 4, "expected_scraps": 4, "label": "upper-case WATCH"},
		{"event_id": "quiet_spool", "choice_id": " watch", "scraps": 4, "expected_scraps": 4, "label": "leading-space watch"},
		{"event_id": "quiet_spool", "choice_id": "watch ", "scraps": 4, "expected_scraps": 4, "label": "trailing-space watch"},
		{"event_id": "quiet_spool", "choice_id": "Ignore", "scraps": 4, "expected_scraps": 4, "label": "title-case Ignore"},
		{"event_id": "quiet_spool", "choice_id": "IGNORE", "scraps": 4, "expected_scraps": 4, "label": "upper-case IGNORE"},
		{"event_id": "quiet_spool", "choice_id": " ignore", "scraps": 4, "expected_scraps": 4, "label": "leading-space ignore"},
		{"event_id": "quiet_spool", "choice_id": "ignore ", "scraps": 4, "expected_scraps": 4, "label": "trailing-space ignore"},
		{"event_id": "quiet_spool", "choice_id": "watch", "scraps": -1, "expected_scraps": -1, "label": "negative scraps -1 on watch"},
		{"event_id": "quiet_spool", "choice_id": "ignore", "scraps": -3, "expected_scraps": -3, "label": "negative scraps -3 on ignore"},
		{"event_id": "quiet_spool", "choice_id": "watch", "scraps": 1.5, "expected_scraps": 0, "label": "fractional float scraps"},
		{"event_id": null, "choice_id": "watch", "scraps": 2, "expected_scraps": 2, "label": "null event_id"},
		{"event_id": "quiet_spool", "choice_id": null, "scraps": 2, "expected_scraps": 2, "label": "null choice_id"},
		{"event_id": 123, "choice_id": "watch", "scraps": 2, "expected_scraps": 2, "label": "numeric event_id"},
		{"event_id": "quiet_spool", "choice_id": 456, "scraps": 2, "expected_scraps": 2, "label": "numeric choice_id"},
	]

	var invalid_cases_snapshot: Array[Dictionary] = invalid_cases.duplicate(true)
	for case_entry: Dictionary in invalid_cases:
		var label: String = String(case_entry["label"])
		var rejected: Dictionary = recoverable_visit.choose(
			case_entry["event_id"],
			case_entry["choice_id"],
			case_entry["scraps"]
		)
		_assert_exact_receipt(
			rejected,
			false,
			"",
			"",
			int(case_entry["expected_scraps"]),
			"AC3 invalid %s" % label
		)
		_check(
			not recoverable_visit.is_consumed(),
			"AC3: invalid attempt (%s) must not consume a fresh instance" % label
		)

	_check(invalid_cases == invalid_cases_snapshot, "AC3: rejected calls must not mutate caller dictionaries")

	# Rejected-first valid-retry recovery for watch:
	var recovered_watch: Dictionary = recoverable_visit.choose("quiet_spool", "watch", 4)
	_assert_exact_receipt(recovered_watch, true, "quiet_spool", "watch", 5, "AC3 valid watch retry after rejections")
	_check(recoverable_visit.is_consumed(), "AC3: valid watch retry must latch instance as consumed")

	# Rejected-first valid-retry recovery for ignore:
	var recoverable_ignore_visit := RunQuietSpoolOutcome.new()
	var rejected_before_ignore: Dictionary = recoverable_ignore_visit.choose("wrong_event", "ignore", 4)
	_assert_exact_receipt(rejected_before_ignore, false, "", "", 4, "AC3 rejection before ignore retry")
	_check(not recoverable_ignore_visit.is_consumed(), "AC3: failed attempt before ignore retry must not consume")
	var recovered_ignore: Dictionary = recoverable_ignore_visit.choose("quiet_spool", "ignore", 4)
	_assert_exact_receipt(recovered_ignore, true, "quiet_spool", "ignore", 4, "AC3 valid ignore retry after rejection")
	_check(recoverable_ignore_visit.is_consumed(), "AC3: valid ignore retry must latch instance as consumed")

	# Replay ordering 1: watch first, then duplicate watch, then ignore after watch.
	var replay_after_watch := RunQuietSpoolOutcome.new()
	var first_watch: Dictionary = replay_after_watch.choose("quiet_spool", "watch", 4)
	var first_watch_snapshot: Dictionary = first_watch.duplicate(true)
	_assert_exact_receipt(first_watch, true, "quiet_spool", "watch", 5, "AC3 first watch")
	_check(replay_after_watch.is_consumed(), "AC3: consumed after first watch")

	var dup_watch: Dictionary = replay_after_watch.choose("quiet_spool", "watch", 5)
	_assert_exact_receipt(dup_watch, false, "", "", 5, "AC3 duplicate watch after watch")
	_check(replay_after_watch.is_consumed(), "AC3: still consumed after duplicate watch")

	var ignore_after_watch: Dictionary = replay_after_watch.choose("quiet_spool", "ignore", 5)
	_assert_exact_receipt(ignore_after_watch, false, "", "", 5, "AC3 ignore after watch")
	_check(replay_after_watch.is_consumed(), "AC3: still consumed after ignore-after-watch")
	_check(first_watch == first_watch_snapshot, "AC3: first watch result dictionary must remain unchanged after replays")

	# Replay ordering 2: ignore first, then watch after ignore, then duplicate ignore.
	var replay_after_ignore := RunQuietSpoolOutcome.new()
	var first_ignore: Dictionary = replay_after_ignore.choose("quiet_spool", "ignore", 4)
	var first_ignore_snapshot: Dictionary = first_ignore.duplicate(true)
	_assert_exact_receipt(first_ignore, true, "quiet_spool", "ignore", 4, "AC3 first ignore")
	_check(replay_after_ignore.is_consumed(), "AC3: consumed after first ignore")

	var watch_after_ignore: Dictionary = replay_after_ignore.choose("quiet_spool", "watch", 4)
	_assert_exact_receipt(watch_after_ignore, false, "", "", 4, "AC3 watch after ignore")
	_check(replay_after_ignore.is_consumed(), "AC3: still consumed after watch-after-ignore")

	var dup_ignore: Dictionary = replay_after_ignore.choose("quiet_spool", "ignore", 4)
	_assert_exact_receipt(dup_ignore, false, "", "", 4, "AC3 duplicate ignore after ignore")
	_check(replay_after_ignore.is_consumed(), "AC3: still consumed after duplicate ignore")
	_check(first_ignore == first_ignore_snapshot, "AC3: first ignore result dictionary must remain unchanged after replays")

	# Verify neither global RNG nor independent RandomNumberGenerator advanced.
	var actual_global_first_draw: int = randi()
	_check(
		actual_global_first_draw == expected_global_first_draw,
		"AC3: global randi() stream must not advance during RunQuietSpoolOutcome operations"
	)
	_check(
		local_rng.state == initial_local_rng_state,
		"AC3: independent RandomNumberGenerator state must remain unchanged"
	)
