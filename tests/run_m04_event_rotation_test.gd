extends SceneTree
## Deterministic headless test for RunM04EventRotation (scene-free M04 Event
## rotation).
## Covers the shipped generic pool by membership checks (never an exact catalog
## total or full ordered list): each required authored record is listed exactly
## once with its own title/description/choices and a valid RunEventChoice, while
## the special quiet_spool record stays out of the generic rotation and remains
## in the source catalog.
## Also covers seeded replay against an independent RNG oracle, the one-draw
## contract, sorted eligibility, caller exclusions, fail-closed invalid input and
## invalid/missing/duplicated required catalog fixtures with no RNG drift,
## forward-compatible future additions, detached return values, and the existing
## RunEventChoice wallet preview/settlement of selected records.
## The V3-4 batches (six roadside, six midnight-story, six lantern-haunted and
## six promoted Candlelit Bargain wallet Events) are each verified by per-ID
## tables of exact authored text and signed outcomes.

const EVENTS_PATH := "res://data/events/m04_events.json"
const ROADSIDE_EVENTS_PATH := "res://data/events/v3_roadside_events.json"
## Canonical source of the twelve Candlelit Bargain records; the earlier six also
## live in m04_events.json, while the remaining six are merged from here by the
## default rotation without duplicating the earlier six.
const CANDLELIT_EVENTS_PATH := "res://data/events/v3_candlelit_bargains.json"

## Independent copy of the six remaining Candlelit Bargain IDs promoted directly
## from v3_candlelit_bargains.json by the default selector.
const PROMOTED_CANDLELIT_IDS := [
	"v3_bellglass_night_market",
	"v3_crowlace_ticket_booth",
	"v3_moonlit_pin_exchange",
	"v3_oxblood_patch_hall",
	"v3_bonecream_button_press",
	"v3_saffron_spool_trial",
]

## Independent copy of the thirteen named generic IDs; never read from the
## production constant, so a shrink there is caught here.
const REQUIRED_IDS := [
	"button_trail",
	"loose_seam",
	"thimble_well",
	"frayed_signpost",
	"needle_gate",
	"quilting_bee",
	"estate_sale",
	"lantern_moth_clearing",
	"patchwork_ferry",
	"spool_clocktower",
	"ragpicker_cart",
	"quilt_bridge",
	"button_moon_festival",
]

const SPECIAL_ID := "quiet_spool"

var failures: Array[String] = []
var checks := 0
var source_document: Dictionary = {}
var source_snapshot: Dictionary = {}
var source_by_id: Dictionary = {}


func _initialize() -> void:
	_load_source()
	if source_document.is_empty():
		_report()
		return
	_test_shipped_pool()
	_test_detached_listing()
	_test_seeded_choice()
	_test_sorted_eligibility()
	_test_exclusions()
	_test_rejections_without_rng_drift()
	_test_fixture_catalog_validation()
	_test_future_catalog_additions()
	_test_wallet_outcomes_of_selected_records()
	_test_v3_wallet_event_batch()
	_test_midnight_story_event_batch()
	_test_lantern_haunted_event_batch()
	_test_candlelit_bargain_event_batch()
	_test_remaining_candlelit_bargain_event_batch()
	_test_candlelit_shipping_merge_validation()
	_check(source_document == source_snapshot, "shipped catalog document unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("run_m04_event_rotation_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_source() -> void:
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
	if parse_result != OK:
		return
	_check(parser.data is Dictionary, "the M04 catalog is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the M04 catalog has an events array")
	if not events is Array:
		source_document = {}
		return
	for record in events:
		if not record is Dictionary:
			continue
		var event_id: Variant = (record as Dictionary).get("id")
		if not event_id is String:
			continue
		if not source_by_id.has(event_id):
			source_by_id[event_id] = record
	_check(source_by_id.has(SPECIAL_ID), "the source catalog still ships the special quiet_spool record")
	source_snapshot = source_document.duplicate(true)


func _test_shipped_pool() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped M04 catalog validates")
	var listing: Array = rotation.get_generic_events()
	_check(not listing.is_empty(), "the generic rotation has a non-empty listing")
	for record in listing:
		_check(record is Dictionary, "every generic listing entry is an object")
	for event_id in REQUIRED_IDS:
		_check(source_by_id.has(event_id), "the source catalog ships " + event_id)
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "exactly one generic record for " + event_id)
		if matches.size() != 1 or not source_by_id.has(event_id):
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = source_by_id[event_id]
		_check(record.get("title") == expected.get("title"), "authored title unchanged: " + event_id)
		_check(record.get("description") == expected.get("description"),
			"authored description unchanged: " + event_id)
		_check(record.get("choices") == expected.get("choices"), "authored choices unchanged: " + event_id)
		_check(record.size() == expected.size(), "authored record keys unchanged: " + event_id)
		var service := RunEventChoice.new(record)
		_check(service.is_valid(), "listed record is a valid RunEventChoice: " + event_id)
		var preview := service.preview_wallet_choices({"gold": 0, "scraps": 0})
		_check(preview.get("ok", false), "listed record forecasts its wallet choices: " + event_id)
	_check(_matches(listing, SPECIAL_ID).is_empty(), "quiet_spool is never in the generic rotation")
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() == listing.size(), "the ID listing matches the record listing length")
	var seen := {}
	for event_id in ids:
		_check(event_id is String and not (event_id as String).strip_edges().is_empty(),
			"every generic ID is a nonblank string")
		_check(not seen.has(event_id), "generic IDs are unique: " + str(event_id))
		seen[event_id] = true
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	_check(ids == sorted_ids, "the generic ID listing is sorted")


func _test_detached_listing() -> void:
	var rotation := RunM04EventRotation.new()
	var first: Array = rotation.get_generic_events()
	_check(not first.is_empty(), "listing is available before detachment checks")
	if first.is_empty():
		return
	var baseline: Array = first.duplicate(true)
	var first_record: Dictionary = first[0]
	first_record["title"] = "MUTATED"
	first_record["choices"] = [{"id": "fake", "text": "fake", "outcome": {"gold": 0, "scraps": 0}}]
	first.append({"id": "injected", "title": "Injected", "description": "Injected", "choices": []})
	var second: Array = rotation.get_generic_events()
	_check(second == baseline, "mutating a returned listing never reaches the rotation")
	var fresh := RunM04EventRotation.new()
	_check(fresh.get_generic_events() == baseline, "a fresh rotation rebuilds the sourced records")
	var mutated_second: Array = rotation.get_generic_events()
	_check(mutated_second == baseline, "the mutated copy is discarded on the next read")
	_check(source_document == source_snapshot, "mutating listings never reaches the source catalog")


func _test_seeded_choice() -> void:
	var rotation := RunM04EventRotation.new()
	var eligible: Array = rotation.get_generic_event_ids()
	_check(eligible.size() >= REQUIRED_IDS.size(), "the pool holds at least the required generic events")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 424242
	var expected_id: Variant = eligible[oracle.randi_range(0, eligible.size() - 1)]
	var result := rotation.select_event(rng)
	_check(_selection_shape_ok(result), "a selection returns exactly {ok, event}")
	_check(result.get("ok") == true, "a seeded selection succeeds")
	var event: Dictionary = result.get("event", {})
	_check(event.get("id") == expected_id, "the selection matches an independent seeded RNG oracle")
	_check(eligible.has(event.get("id")), "the selection belongs to the eligible set")
	_check(rng.state == oracle.state, "one successful selection consumes exactly one range draw")
	var replay := RandomNumberGenerator.new()
	replay.seed = 424242
	var again := rotation.select_event(replay)
	_check(again.get("ok") == true, "the replay selection succeeds")
	_check(again.get("event", {}).get("id") == expected_id, "an identical seed and state replay the same event")
	_check(replay.state == rng.state, "a replayed selection ends in identical RNG state")
	event["title"] = "MUTATED"
	event.erase("choices")
	var third := RandomNumberGenerator.new()
	third.seed = 424242
	var third_result := rotation.select_event(third)
	var source_record: Dictionary = _shipped_record(expected_id)
	_check(third_result.get("event", {}).get("title") == source_record["title"],
		"a returned event is detached from the rotation")
	_check(third_result.get("event", {}).get("choices") == source_record["choices"],
		"a returned event keeps its authored choices")
	for seed_value in range(1, 33):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		var picked := rotation.select_event(probe)
		_check(picked.get("ok") == true, "seed %d selects a generic event" % seed_value)
		var picked_id: Variant = picked.get("event", {}).get("id")
		_check(eligible.has(picked_id), "seed %d stays inside the generic pool" % seed_value)
		_check(picked_id != SPECIAL_ID, "seed %d never selects quiet_spool" % seed_value)


func _test_sorted_eligibility() -> void:
	var shipped := RunM04EventRotation.new()
	var reversed_events: Array = _combined_events()
	reversed_events.reverse()
	var reversed_rotation := RunM04EventRotation.new({"events": reversed_events})
	_check(reversed_rotation.is_catalog_valid(), "a reverse-ordered catalog fixture still validates")
	_check(reversed_rotation.get_generic_event_ids() == shipped.get_generic_event_ids(),
		"both JSON orderings expose the same sorted eligible IDs")
	var rev_generic_events: Array = _source_events()
	rev_generic_events.reverse()
	var rev_roadside_events: Array = _load_catalog_events(ROADSIDE_EVENTS_PATH)
	rev_roadside_events.reverse()
	var rev_candlelit_events: Array = _load_catalog_events(CANDLELIT_EVENTS_PATH)
	rev_candlelit_events.reverse()
	var reordered_merge: Variant = RunM04EventRotation._combine_shipped_catalogs(
		{"events": rev_generic_events},
		{"events": rev_roadside_events},
		{"events": rev_candlelit_events}
	)
	var reordered_shipped := RunM04EventRotation.new(reordered_merge)
	_check(reordered_shipped.is_catalog_valid(), "reordered shipping sources still validate")
	_check(reordered_shipped.get_generic_event_ids() == shipped.get_generic_event_ids(),
		"reordered shipping sources expose the exact same sorted eligible IDs")
	for seed_value in [7, 99, 424242, 1000003]:
		var first_rng := RandomNumberGenerator.new()
		first_rng.seed = seed_value
		var second_rng := RandomNumberGenerator.new()
		second_rng.seed = seed_value
		var third_rng := RandomNumberGenerator.new()
		third_rng.seed = seed_value
		var first := shipped.select_event(first_rng)
		var second := reversed_rotation.select_event(second_rng)
		var third := reordered_shipped.select_event(third_rng)
		_check(first.get("ok") == true and second.get("ok") == true and third.get("ok") == true,
			"all JSON orderings select with seed %d" % seed_value)
		_check(first.get("event", {}).get("id") == second.get("event", {}).get("id")
			and first.get("event", {}).get("id") == third.get("event", {}).get("id"),
			"JSON order is not a hidden random input (seed %d)" % seed_value)
		_check(first_rng.state == second_rng.state and first_rng.state == third_rng.state,
			"JSON order never changes the RNG state (seed %d)" % seed_value)


func _test_exclusions() -> void:
	var rotation := RunM04EventRotation.new()
	var all_ids: Array = rotation.get_generic_event_ids()
	_check(all_ids.size() > 2, "the generic pool has enough events to exercise exclusions")
	if all_ids.size() <= 2:
		return
	var first_id: String = all_ids[0]
	var last_id: String = all_ids[all_ids.size() - 1]
	var excluded := [first_id, last_id]
	var remaining: Array = all_ids.duplicate()
	remaining.erase(first_id)
	remaining.erase(last_id)
	for seed_value in range(11, 21):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var result := rotation.select_event(rng, excluded)
		_check(result.get("ok") == true, "a selection with exclusions succeeds")
		var picked_id: Variant = result.get("event", {}).get("id")
		_check(remaining.has(picked_id), "exclusions remove exactly the supplied IDs (seed %d)" % seed_value)
		_check(not excluded.has(picked_id), "an excluded ID is never selected (seed %d)" % seed_value)
	# A single eligible record is still chosen with exactly the one documented draw.
	var only_first: Array = all_ids.duplicate()
	only_first.erase(first_id)
	var forced_rng := RandomNumberGenerator.new()
	forced_rng.seed = 31337
	var forced_oracle := RandomNumberGenerator.new()
	forced_oracle.seed = 31337
	forced_oracle.randi_range(0, 0)
	var forced := rotation.select_event(forced_rng, only_first)
	_check(forced.get("ok") == true, "a single eligible event still selects")
	_check(forced.get("event", {}).get("id") == first_id, "the single eligible event is chosen")
	_check(forced_rng.state == forced_oracle.state,
		"a single eligible event consumes the one documented range draw")
	# Unknown IDs are ignored: they can never enter the pool.
	var unknown_rng := RandomNumberGenerator.new()
	unknown_rng.seed = 555
	var plain_rng := RandomNumberGenerator.new()
	plain_rng.seed = 555
	var with_unknown := rotation.select_event(unknown_rng, ["future_event_not_in_catalog"])
	var plain := rotation.select_event(plain_rng)
	_check(with_unknown.get("event", {}).get("id") == plain.get("event", {}).get("id"),
		"an unknown exclusion is ignored")
	_check(unknown_rng.state == plain_rng.state, "an unknown exclusion does not change the draw")
	# Exclusion order and duplicates express the same set.
	var order_rng := RandomNumberGenerator.new()
	order_rng.seed = 606
	var duplicate_rng := RandomNumberGenerator.new()
	duplicate_rng.seed = 606
	var ordered := rotation.select_event(order_rng, [first_id, last_id])
	var duplicated := rotation.select_event(duplicate_rng, [last_id, first_id, first_id])
	_check(ordered.get("event", {}).get("id") == duplicated.get("event", {}).get("id"),
		"exclusion order never affects the selection")
	_check(order_rng.state == duplicate_rng.state, "duplicate exclusions never affect the draw")
	# An empty exclusion array selects the whole pool, as an untouched oracle does.
	var empty_rng := RandomNumberGenerator.new()
	empty_rng.seed = 707
	var empty_oracle := RandomNumberGenerator.new()
	empty_oracle.seed = 707
	var expected_empty: Variant = all_ids[empty_oracle.randi_range(0, all_ids.size() - 1)]
	var empty_result := rotation.select_event(empty_rng, [])
	_check(empty_result.get("ok") == true, "an empty exclusion array still selects")
	_check(empty_result.get("event", {}).get("id") == expected_empty,
		"an empty exclusion array selects from the whole pool")
	_check(empty_rng.state == empty_oracle.state, "an empty exclusion array consumes one draw")
	# Excluding everything rejects without a draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 909
	var guard_state := guard.state
	var none := rotation.select_event(guard, all_ids)
	_check(none.get("ok") == false, "excluding every generic event rejects")
	_check((none.get("event") as Dictionary).is_empty(), "an empty eligible set returns no event")
	_check(guard.state == guard_state, "an empty eligible set consumes no RNG")


func _test_rejections_without_rng_drift() -> void:
	var rotation := RunM04EventRotation.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567
	var state_before := rng.state
	var bad_rng_values := [null, 5, 3.5, "rng", {}, [], RefCounted.new()]
	for bad_value in bad_rng_values:
		var result := rotation.select_event(bad_value)
		_check(result.get("ok") == false, "a wrong RNG rejects: " + str(bad_value))
		_check((result.get("event") as Dictionary).is_empty(), "a wrong RNG returns no event")
		_check(rng.state == state_before, "a wrong RNG consumes no RNG")
	var bad_exclusions := [
		"button_trail", 7, {}, true, [1], [null], [{}], [true], [""], ["   "], [["button_trail"]],
	]
	for bad_list in bad_exclusions:
		var result := rotation.select_event(rng, bad_list)
		_check(result.get("ok") == false, "a malformed exclusion list rejects: " + str(bad_list))
		_check((result.get("event") as Dictionary).is_empty(), "a malformed exclusion list returns no event")
		_check(rng.state == state_before, "a malformed exclusion list consumes no RNG")
	# Rejections leave the RNG exactly where a clean oracle starts.
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 1234567
	var expected_id: Variant = rotation.get_generic_event_ids()[oracle.randi_range(
		0, rotation.get_generic_event_ids().size() - 1)]
	var recovered := rotation.select_event(rng)
	_check(recovered.get("ok") == true, "a valid call still works after rejections")
	_check(recovered.get("event", {}).get("id") == expected_id,
		"rejections leave the RNG state untouched")
	_check(rng.state == oracle.state, "rejections and the recovery call match the oracle state")


func _test_fixture_catalog_validation() -> void:
	var cases: Array = []
	var missing_events := _without(_source_events(), "quilting_bee")
	cases.append({"name": "missing required record", "document": {"events": missing_events}})
	var duplicated_events := _source_events()
	duplicated_events.append(_record_copy("button_trail"))
	cases.append({"name": "duplicated required record", "document": {"events": duplicated_events}})
	var blank_title := _record_copy("thimble_well")
	blank_title["title"] = " "
	cases.append({"name": "blank required title", "document": {"events": _replaced(
		_source_events(), "thimble_well", blank_title)}})
	var four_choices := _record_copy("needle_gate")
	(four_choices["choices"] as Array).append({"id": "extra", "text": "Extra", "outcome": {"gold": 0, "scraps": 0}})
	cases.append({"name": "too many required choices", "document": {"events": _replaced(
		_source_events(), "needle_gate", four_choices)}})
	var broken_outcome := _record_copy("frayed_signpost")
	((broken_outcome["choices"] as Array)[0] as Dictionary)["outcome"] = {"gold": 1}
	cases.append({"name": "malformed required outcome", "document": {"events": _replaced(
		_source_events(), "frayed_signpost", broken_outcome)}})
	cases.append({"name": "non-object required record", "document": {"events": _replaced(
		_source_events(), "loose_seam", "loose_seam")}})
	var missing_id := _record_copy("estate_sale")
	missing_id.erase("id")
	cases.append({"name": "required record without an ID", "document": {"events": _replaced(
		_source_events(), "estate_sale", missing_id)}})
	cases.append({"name": "document without events", "document": {}})
	cases.append({"name": "events is not an array", "document": {"events": "button_trail"}})
	cases.append({"name": "empty events array", "document": {"events": []}})
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for entry in cases:
		var state_before := rng.state
		var rotation := RunM04EventRotation.new(entry["document"])
		_check(not rotation.is_catalog_valid(), "catalog fixture rejects: " + entry["name"])
		_check(rotation.get_generic_events().is_empty(), "invalid catalog exposes no pool: " + entry["name"])
		_check(rotation.get_generic_event_ids().is_empty(), "invalid catalog exposes no IDs: " + entry["name"])
		var result := rotation.select_event(rng)
		_check(result.get("ok") == false, "invalid catalog rejects selection: " + entry["name"])
		_check(rng.state == state_before, "invalid catalog consumes no RNG: " + entry["name"])
	_check(source_document == source_snapshot, "catalog fixtures never mutate the shipped source")


func _test_future_catalog_additions() -> void:
	var events := _source_events()
	events.append(_future_event())
	var rotation := RunM04EventRotation.new({"events": events})
	_check(rotation.is_catalog_valid(), "a future addition keeps the shipped rotation valid")
	_check(_matches(rotation.get_generic_events(), "future_lantern").size() == 1,
		"a well-formed future addition joins the generic pool")
	_check(_matches(rotation.get_generic_events(), SPECIAL_ID).is_empty(),
		"quiet_spool stays out of an extended pool")
	var found := false
	for seed_value in range(1, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var result := rotation.select_event(rng)
		if result.get("ok") == true and result.get("event", {}).get("id") == "future_lantern":
			found = true
			break
	_check(found, "a future catalog addition is selectable, not only listed")
	var dangling := _source_events()
	dangling.append({"id": "future_broken", "title": "Broken", "description": "Broken", "choices": []})
	var tolerant := RunM04EventRotation.new({"events": dangling})
	_check(tolerant.is_catalog_valid(), "a malformed future addition never breaks the rotation")
	_check(_matches(tolerant.get_generic_events(), "future_broken").is_empty(),
		"a malformed future addition stays out of the pool")
	var doubled := _source_events()
	doubled.append(_future_event())
	doubled.append(_future_event())
	var ambiguous := RunM04EventRotation.new({"events": doubled})
	_check(ambiguous.is_catalog_valid(), "a duplicated future addition never breaks the rotation")
	_check(_matches(ambiguous.get_generic_events(), "future_lantern").is_empty(),
		"a duplicated future addition stays out of the pool")
	_check(source_document == source_snapshot, "future catalog fixtures never mutate the shipped source")


func _test_wallet_outcomes_of_selected_records() -> void:
	var rotation := RunM04EventRotation.new()
	var pool_snapshot: Array = rotation.get_generic_events()
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 616
	var guard_state := rng_guard.state

	# button_trail: positive scrap award plus priced choices at zero and partial balances.
	var trail := _force_selection(rotation, "button_trail", 12)
	if trail.is_empty():
		return
	var trail_snapshot: Dictionary = trail.duplicate(true)
	var trail_service := RunEventChoice.new(trail)
	_check(trail_service.is_valid(), "the selected button_trail validates")
	var trail_preview := _preview_map(trail_service.preview_wallet_choices({"gold": 5, "scraps": 0}))
	_check(trail_preview.get("follow", {}).get("affordable") == true,
		"the positive scrap award is affordable without gold")
	_check(trail_preview.get("follow", {}).get("wallet") == {"gold": 5, "scraps": 1},
		"the positive scrap award forecasts its authored +1 scrap")
	_check(trail_preview.get("leave", {}).get("affordable") == false,
		"a priced gold choice is unaffordable at 5 gold")
	_check(trail_preview.get("sell_buttons", {}).get("affordable") == false,
		"a priced scrap choice is unaffordable at 0 scraps")
	var denied := trail_service.choose_with_wallet("leave", {"gold": 5, "scraps": 0})
	_check(denied.get("ok") == false, "an unaffordable gold choice is refused")
	_check(denied.get("wallet") == {"gold": 5, "scraps": 0}, "a refusal returns the unchanged wallet")
	_check(not trail_service.is_claimed(), "a refused choice never consumes the claim")
	_check(trail_service.is_valid(), "the service stays usable after a refusal")
	var paid := trail_service.choose_with_wallet("follow", {"gold": 5, "scraps": 0})
	_check(paid.get("ok") == true, "the positive scrap award settles once the balance allows it")
	_check(paid.get("event_id") == "button_trail" and paid.get("choice_id") == "follow",
		"settlement names the authored event and choice")
	_check(paid.get("wallet") == {"gold": 5, "scraps": 1},
		"settlement applies the authored +1 scrap award")
	_check(trail_service.is_claimed(), "the settled choice consumes the claim")
	_check(trail_service.choose_with_wallet("follow", {"gold": 5, "scraps": 0}).get("ok") == false,
		"the claim cannot be replayed")
	_check(trail == trail_snapshot, "wallet settlement never mutates the selector's detached record")

	# estate_sale: a priced gold/scrap choice at sufficient and insufficient balances.
	var estate := _force_selection(rotation, "estate_sale", 21)
	if estate.is_empty():
		return
	var estate_snapshot: Dictionary = estate.duplicate(true)
	var rich_service := RunEventChoice.new(estate)
	var rich_preview := _preview_map(rich_service.preview_wallet_choices({"gold": 100, "scraps": 5}))
	_check(rich_preview.get("buy_thread", {}).get("affordable") == true,
		"the priced gold/scrap choice is affordable when funded")
	_check(rich_preview.get("buy_thread", {}).get("wallet") == {"gold": 85, "scraps": 7},
		"the priced gold/scrap choice forecasts its authored deltas")
	_check(rich_preview.get("sell_fabric", {}).get("wallet") == {"gold": 130, "scraps": 3},
		"the priced scrap/gold choice forecasts its authored deltas")
	var bought := rich_service.choose_with_wallet("buy_thread", {"gold": 100, "scraps": 5})
	_check(bought.get("ok") == true, "the priced gold/scrap choice settles when funded")
	_check(bought.get("wallet") == {"gold": 85, "scraps": 7},
		"the priced gold/scrap choice applies its authored deltas")
	var poor_service := RunEventChoice.new(estate)
	var poor_preview := _preview_map(poor_service.preview_wallet_choices({"gold": 10, "scraps": 0}))
	_check(poor_preview.get("buy_thread", {}).get("affordable") == false,
		"the priced gold/scrap choice is unaffordable when underfunded")
	_check(poor_preview.get("sell_fabric", {}).get("affordable") == false,
		"the priced scrap choice is unaffordable without scraps")
	_check(poor_preview.get("leave", {}).get("affordable") == true,
		"the free choice stays affordable while underfunded")
	var poor_denied := poor_service.choose_with_wallet("buy_thread", {"gold": 10, "scraps": 0})
	_check(poor_denied.get("ok") == false, "an underfunded priced choice is refused")
	_check(poor_denied.get("wallet") == {"gold": 10, "scraps": 0},
		"an underfunded refusal returns the unchanged wallet")
	_check(not poor_service.is_claimed(), "an underfunded refusal leaves the record unclaimed")
	var left := poor_service.choose_with_wallet("leave", {"gold": 10, "scraps": 0})
	_check(left.get("ok") == true, "the free choice settles after a refusal")
	_check(left.get("wallet") == {"gold": 10, "scraps": 0},
		"the free choice leaves the wallet balance unchanged")
	_check(estate == estate_snapshot, "estate sale settlement never mutates the detached record")
	_check(estate == source_by_id["estate_sale"], "the selected estate sale matches the authored source")

	_check(rotation.get_generic_events() == pool_snapshot, "wallet flows never mutate the rotation listing")
	_check(rng_guard.state == guard_state, "wallet preview and settlement never touch the run RNG")


func _test_v3_wallet_event_batch() -> void:
	## Table-driven verification of the six V3-4 wallet-only events.
	## Each entry: id, title, description, choices array of {id, text, gold, scraps}.
	var new_events: Array[Dictionary] = [
		{
			"id": "lantern_moth_clearing",
			"title": "Lantern-Moth Clearing",
			"description": "Moths orbit a quilted lantern; abandoned silk spools glimmer in the grass.",
			"choices": [
				{"id": "gather_spools", "text": "Gather loose silk (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "buy_wick", "text": "Trade 14 gold for two wick spools (+2 scraps)", "gold": -14, "scraps": 2},
				{"id": "move_on", "text": "Leave the moths undisturbed", "gold": 0, "scraps": 0},
			],
		},
		{
			"id": "patchwork_ferry",
			"title": "The Patchwork Ferry",
			"description": "A cloth-sailed ferry rocks at a riverbank lined with cast-off rope.",
			"choices": [
				{"id": "buy_passage", "text": "Pay 10 gold for a spare rope coil (+1 scrap)", "gold": -10, "scraps": 1},
				{"id": "sell_rigging", "text": "Sell two scraps of salvaged rigging (+25 gold)", "gold": 25, "scraps": -2},
				{"id": "walk_river", "text": "Take the long road", "gold": 0, "scraps": 0},
			],
		},
		{
			"id": "spool_clocktower",
			"title": "The Spool Clocktower",
			"description": "A crooked clock made of spools ticks above a deserted seamstress stall.",
			"choices": [
				{"id": "collect_coins", "text": "Untangle six fallen coins (+6 gold)", "gold": 6, "scraps": 0},
				{"id": "repair_hand", "text": "Spend 1 scrap to fix the clock hand (+20 gold)", "gold": 20, "scraps": -1},
				{"id": "ignore_chimes", "text": "Ignore the chimes", "gold": 0, "scraps": 0},
			],
		},
		{
			"id": "ragpicker_cart",
			"title": "The Ragpicker's Cart",
			"description": "A ragpicker sorts striped remnants into bundles beside a handcart.",
			"choices": [
				{"id": "buy_bundle", "text": "Buy a bundle for 20 gold (+3 scraps)", "gold": -20, "scraps": 3},
				{"id": "sell_remnants", "text": "Sell two scraps of fine fabric (+29 gold)", "gold": 29, "scraps": -2},
				{"id": "leave", "text": "Leave the cart", "gold": 0, "scraps": 0},
			],
		},
		{
			"id": "quilt_bridge",
			"title": "The Quilt Bridge",
			"description": "The river crossing is a suspended strip of embroidered quilt.",
			"choices": [
				{"id": "salvage_stitch", "text": "Pick up a fallen stitch (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "repair_toll", "text": "Spend 1 scrap on the guardrail (+18 gold)", "gold": 18, "scraps": -1},
				{"id": "barter_thread", "text": "Exchange 12 gold for two thread bundles (+2 scraps)", "gold": -12, "scraps": 2},
			],
		},
		{
			"id": "button_moon_festival",
			"title": "The Button-Moon Festival",
			"description": "Travellers celebrate beneath a moon stitched from silver buttons.",
			"choices": [
				{"id": "find_lucky_button", "text": "Find a dropped lucky coin (+5 gold)", "gold": 5, "scraps": 0},
				{"id": "buy_ribbons", "text": "Buy two ribbon bundles for 16 gold (+2 scraps)", "gold": -16, "scraps": 2},
				{"id": "sell_masks", "text": "Sell two scraps of festival fabric (+28 gold)", "gold": 28, "scraps": -2},
			],
		},
	]

	var rotation := RunM04EventRotation.new()
	var pool_snapshot: Array = rotation.get_generic_events()

	for event_def in new_events:
		var event_id: String = event_def["id"]
		# Verify the event appears exactly once in the generic rotation with exact authored fields.
		var matches := _matches(pool_snapshot, event_id)
		_check(matches.size() == 1, "exactly one generic record for new event " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.get("title") == event_def["title"], "authored title matches: " + event_id)
		_check(record.get("description") == event_def["description"], "authored description matches: " + event_id)
		# Verify each choice's text and outcome deltas.
		var expected_choices: Array = event_def["choices"]
		var actual_choices: Array = record.get("choices", [])
		_check(actual_choices.size() == expected_choices.size(), "choice count matches: " + event_id)
		for choice_def in expected_choices:
			var found := false
			for actual in actual_choices:
				if actual is Dictionary and actual.get("id") == choice_def["id"]:
					found = true
					_check(actual.get("text") == choice_def["text"], "choice text matches: " + event_id + " / " + choice_def["id"])
					var actual_outcome: Dictionary = actual.get("outcome", {})
					var expected_gold: int = choice_def["gold"]
					var expected_scraps: int = choice_def["scraps"]
					var actual_gold: int = int(actual_outcome.get("gold", 0))
					var actual_scraps: int = int(actual_outcome.get("scraps", 0))
					_check(actual_gold == expected_gold and actual_scraps == expected_scraps, "choice outcome deltas match: " + event_id + " / " + choice_def["id"])
					break
			_check(found, "choice id present: " + event_id + " / " + choice_def["id"])

		# Force selection via exclusions with a fixed seed and independent oracle.
		var excluded: Array = rotation.get_generic_event_ids()
		excluded.erase(event_id)
		var seed_value: int = _event_seed(event_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		# Since we excluded all OTHER IDs, the only eligible is event_id, so oracle.randi_range(0,0) = 0
		oracle.randi_range(0, 0)
		var result := rotation.select_event(rng, excluded)
		_check(result.get("ok") == true, "forced selection succeeds: " + event_id)
		_check(result.get("event", {}).get("id") == event_id, "forced selection returns correct event: " + event_id)
		_check(rng.state == oracle.state, "forced selection consumes exactly one draw: " + event_id)

		# Wallet preview and settlement for each choice.
		var service := RunEventChoice.new(record)
		_check(service.is_valid(), "selected record validates: " + event_id)
		for choice_def in expected_choices:
			var choice_id: String = choice_def["id"]
			var preview: Dictionary = _preview_map(service.preview_wallet_choices({"gold": 100, "scraps": 10}))
			_check(preview.has(choice_id), "preview has choice: " + event_id + " / " + choice_id)
			var choice_preview: Dictionary = preview[choice_id]
			_check(choice_preview.get("affordable") == true, "choice affordable at funded wallet: " + event_id + " / " + choice_id)
			var expected_wallet: Dictionary = {"gold": 100 + choice_def["gold"], "scraps": 10 + choice_def["scraps"]}
			_check(choice_preview.get("wallet") == expected_wallet, "preview wallet matches authored deltas: " + event_id + " / " + choice_id)

			# Test insufficient funds for debit choices, then success after funding.
			if choice_def["gold"] < 0 or choice_def["scraps"] < 0:
				var poor_service := RunEventChoice.new(record)
				var poor_preview := _preview_map(poor_service.preview_wallet_choices({"gold": 0, "scraps": 0}))
				_check(poor_preview[choice_id].get("affordable") == false, "choice unaffordable at zero wallet: " + event_id + " / " + choice_id)
				var denied := poor_service.choose_with_wallet(choice_id, {"gold": 0, "scraps": 0})
				_check(denied.get("ok") == false, "debit choice refused at zero wallet: " + event_id + " / " + choice_id)
				_check(denied.get("wallet") == {"gold": 0, "scraps": 0}, "refusal returns unchanged wallet: " + event_id + " / " + choice_id)
				_check(not poor_service.is_claimed(), "refusal leaves claim unconsumed: " + event_id + " / " + choice_id)
				# Now fund and succeed.
				var funded_service := RunEventChoice.new(record)
				var funded := funded_service.choose_with_wallet(choice_id, {"gold": 100, "scraps": 10})
				_check(funded.get("ok") == true, "debit choice succeeds when funded: " + event_id + " / " + choice_id)
				_check(funded.get("wallet") == {"gold": 100 + choice_def["gold"], "scraps": 10 + choice_def["scraps"]}, "funded settlement applies deltas: " + event_id + " / " + choice_id)
				_check(funded_service.is_claimed(), "funded settlement consumes claim: " + event_id + " / " + choice_id)
				# Replay rejected.
				_check(funded_service.choose_with_wallet(choice_id, {"gold": 100, "scraps": 10}).get("ok") == false, "replay rejected: " + event_id + " / " + choice_id)
			else:
				# Non-debit options (zero or positive deltas) remain selectable at zero wallet.
				var free_service := RunEventChoice.new(record)
				var free := free_service.choose_with_wallet(choice_id, {"gold": 0, "scraps": 0})
				_check(free.get("ok") == true, "non-debit choice succeeds at zero wallet: " + event_id + " / " + choice_id)
				var free_wallet: Dictionary = free.get("wallet", {})
				var free_gold: int = int(free_wallet.get("gold", 0))
				var free_scraps: int = int(free_wallet.get("scraps", 0))
				var expected_gold: int = max(0, choice_def["gold"])
				var expected_scraps: int = max(0, choice_def["scraps"])
				_check(free_gold == expected_gold and free_scraps == expected_scraps, "non-debit choice applies positive deltas: " + event_id + " / " + choice_id)
				_check(free_service.is_claimed(), "non-debit choice consumes claim: " + event_id + " / " + choice_id)
				_check(free_service.choose_with_wallet(choice_id, {"gold": 0, "scraps": 0}).get("ok") == false, "replay rejected: " + event_id + " / " + choice_id)

		_check(service.is_valid(), "service stays usable after all settlements: " + event_id)

	_check(rotation.get_generic_events() == pool_snapshot, "wallet flows never mutate the rotation listing")


## Table-driven verification of the six V3-4 midnight-story wallet-only Events
## appended to the generic M04 rotation. The expected contract below is an
## independent copy of the authored story and signed outcomes; it never reads
## the production catalog or the selector's constants back as its oracle.
## Only per-ID membership is asserted: no catalog total and no ordered list.
func _test_midnight_story_event_batch() -> void:
	var expected: Dictionary = {
		"v3_lost_thimble_ball": {
			"title": "The Lost Thimble Ball",
			"description": "Under a velvet marquee, three button-eyed puppets waltz around a missing silver thimble.",
			"choices": [
				{"id": "return_thimble", "text": "Return the thimble for 17 gold", "gold": 17, "scraps": 0},
				{"id": "trade_ribbon", "text": "Trade 12 gold for two ribbon scraps", "gold": -12, "scraps": 2},
				{"id": "walk_past", "text": "Pass the velvet marquee", "gold": 0, "scraps": 0},
			],
		},
		"v3_moonlace_tailor": {
			"title": "The Moonlace Tailor",
			"description": "A pale quiltmaker holds up moonlit lace, its hems fluttering against a great needle hoop.",
			"choices": [
				{"id": "offer_scraps", "text": "Sell two scraps for 31 gold", "gold": 31, "scraps": -2},
				{"id": "gather_trimmings", "text": "Gather dropped lace trimmings (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "leave", "text": "Leave the tailor to the moonlight", "gold": 0, "scraps": 0},
			],
		},
		"v3_copper_bell_choir": {
			"title": "The Copper-Bell Choir",
			"description": "Button-eyed ragdolls ring tiny copper bells beneath an oxblood awning.",
			"choices": [
				{"id": "sort_bell_tags", "text": "Sort the bell tags for 10 gold", "gold": 10, "scraps": 0},
				{"id": "buy_bell_cord", "text": "Pay 14 gold for two cord scraps", "gold": -14, "scraps": 2},
				{"id": "listen", "text": "Listen to the bells and go", "gold": 0, "scraps": 0},
			],
		},
		"v3_stitched_rooftop_market": {
			"title": "Rooftop Stitch Market",
			"description": "A rope ladder climbs to a sewn rooftop where velvet-winged crows barter loose thread.",
			"choices": [
				{"id": "sell_fabric", "text": "Sell one scrap of fine fabric for 19 gold", "gold": 19, "scraps": -1},
				{"id": "collect_strands", "text": "Collect stray thread (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "descend", "text": "Climb back down", "gold": 0, "scraps": 0},
			],
		},
		"v3_torn_parasol_caravan": {
			"title": "The Torn Parasol Caravan",
			"description": "Patch-covered parasols shuffle along on tiny wooden feet through lantern fog.",
			"choices": [
				{"id": "repair_frames", "text": "Repair the frames with two scraps for 27 gold", "gold": 27, "scraps": -2},
				{"id": "buy_tassels", "text": "Pay 9 gold for one loose tassel scrap", "gold": -9, "scraps": 1},
				{"id": "pass_by", "text": "Wave the caravan onward", "gold": 0, "scraps": 0},
			],
		},
		"v3_silk_mirror_fountain": {
			"title": "The Silk-Mirror Fountain",
			"description": "A midnight fountain shows unsewn paths in its trembling silk reflection.",
			"choices": [
				{"id": "comb_ribbons", "text": "Comb loose ribbons from the water (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "buy_spools", "text": "Give 20 gold for three dry spools (+3 scraps)", "gold": -20, "scraps": 3},
				{"id": "turn_away", "text": "Turn away from the reflection", "gold": 0, "scraps": 0},
			],
		},
	}
	## Independent per-ID seeds for the forced single-eligible selection replay.
	var seeds: Dictionary = {
		"v3_lost_thimble_ball": 62001,
		"v3_moonlace_tailor": 62002,
		"v3_copper_bell_choir": 62003,
		"v3_stitched_rooftop_market": 62004,
		"v3_torn_parasol_caravan": 62005,
		"v3_silk_mirror_fountain": 62006,
	}
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	var listing_snapshot: Array = listing.duplicate(true)
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 731731
	var guard_state := rng_guard.state
	for event_id in expected:
		var contract: Dictionary = expected[event_id]
		# Exactly one sourced record and one generic rotation record per ID.
		var sourced_matches := _matches(_source_events(), event_id)
		_check(sourced_matches.size() == 1, "exactly one sourced record for " + event_id)
		var listed_matches := _matches(listing, event_id)
		_check(listed_matches.size() == 1, "exactly one generic rotation record for " + event_id)
		_check(ids.count(event_id) == 1, "the generic ID listing carries " + event_id + " exactly once")
		if sourced_matches.size() != 1 or listed_matches.size() != 1:
			continue
		var source_record: Dictionary = sourced_matches[0]
		var record: Dictionary = listed_matches[0]
		_check(record == source_record, "the rotation copies the authored record: " + event_id)
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"authored record carries exactly id/title/description/choices: " + event_id)
		_check(record.get("title") == contract["title"], "authored title: " + event_id)
		_check(record.get("description") == contract["description"], "authored description: " + event_id)
		var choices: Array = record.get("choices", [])
		_check(choices.size() == 3, "three authored choices: " + event_id)
		var by_choice: Dictionary = {}
		for choice in choices:
			_check(choice is Dictionary, "every choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_key: Variant = (choice as Dictionary).get("id")
			_check(choice_key is String, "every choice has a string ID: " + event_id)
			if not choice_key is String:
				continue
			_check(not by_choice.has(choice_key), "choice IDs are distinct: " + event_id + " / " + str(choice_key))
			by_choice[choice_key] = choice
		_check(by_choice.size() == 3, "three distinct choice IDs: " + event_id)
		for choice_def in contract["choices"]:
			var choice_id: String = choice_def["id"]
			_check(by_choice.has(choice_id), "authored choice present: " + event_id + " / " + choice_id)
			if not by_choice.has(choice_id):
				continue
			var choice: Dictionary = by_choice[choice_id]
			_check(choice.get("text") == choice_def["text"],
				"authored choice text: " + event_id + " / " + choice_id)
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "choice outcome is an object: " + event_id + " / " + choice_id)
			if not outcome is Dictionary:
				continue
			var outcome_dict: Dictionary = outcome
			_check(outcome_dict.size() == 2 and outcome_dict.has("gold") and outcome_dict.has("scraps"),
				"exact signed outcome keys: " + event_id + " / " + choice_id)
			# JSON parsing may deliver whole numbers as floats; the authored
			# contract is a whole signed amount either way.
			var gold_amount: Variant = _signed_amount(outcome_dict.get("gold"))
			var scraps_amount: Variant = _signed_amount(outcome_dict.get("scraps"))
			_check(gold_amount != null and scraps_amount != null,
				"whole-number outcome amounts: " + event_id + " / " + choice_id)
			_check(gold_amount == choice_def["gold"] and scraps_amount == choice_def["scraps"],
				"authored signed outcome: " + event_id + " / " + choice_id)
		# Excluding every other generic ID leaves only this event, which the real
		# selector must return after exactly one range draw.
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var seed_value: int = seeds[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "forced selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "forced selection returns " + event_id)
		_check(rng.state == oracle.state, "forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"identical seed and exclusions replay " + event_id)
		# The returned record is a detached copy of the authored record.
		var selected_snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		selected["injected"] = true
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == selected_snapshot and detached.get("event") == source_record,
			"the selected " + event_id + " is a detached authored copy")
		# Wallet preview and one-shot settlement for all three authored choices.
		var funded := {"gold": 100, "scraps": 5}
		var funded_snapshot: Dictionary = funded.duplicate(true)
		var forecast_service := RunEventChoice.new(source_record)
		_check(forecast_service.is_valid(), "authored record is a valid RunEventChoice: " + event_id)
		var preview := forecast_service.preview_wallet_choices(funded)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"funded preview succeeds: " + event_id)
		var rows := _preview_map(preview)
		_check(rows.size() == 3, "funded preview lists all three choices: " + event_id)
		var fallback_def: Dictionary = {}
		for choice_def in contract["choices"]:
			if int(choice_def["gold"]) == 0 and int(choice_def["scraps"]) == 0:
				fallback_def = choice_def
		_check(not fallback_def.is_empty(), "each event keeps one free fallback choice: " + event_id)
		var zero := {"gold": 0, "scraps": 0}
		for choice_def in contract["choices"]:
			var choice_id: String = choice_def["id"]
			var gold_delta: int = choice_def["gold"]
			var scraps_delta: int = choice_def["scraps"]
			var after := {"gold": 100 + gold_delta, "scraps": 5 + scraps_delta}
			var row: Dictionary = rows.get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var committed := RunEventChoice.new(source_record)
			var receipt := committed.choose_with_wallet(choice_id, funded)
			_check(receipt.get("ok") == true and receipt.get("event_id") == event_id
				and receipt.get("choice_id") == choice_id,
				"exact authored claim: " + event_id + " / " + choice_id)
			_check(receipt.get("wallet") == after, "the claim applies the authored deltas once: "
				+ event_id + " / " + choice_id)
			_check(committed.is_claimed() and not committed.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay_claim := committed.choose_with_wallet(choice_id, funded)
			_check(replay_claim.get("ok") == false and replay_claim.get("wallet") == funded,
				"the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			# Signed debits at an empty wallet: refused without consuming the visit,
			# then the same selector settles its authored free fallback.
			var paid := gold_delta < 0 or scraps_delta < 0
			var zero_snapshot: Dictionary = zero.duplicate(true)
			var scarce := RunEventChoice.new(source_record)
			var scarce_rows := _preview_map(scarce.preview_wallet_choices(zero))
			_check(scarce_rows.get(choice_id, {}).get("affordable") == (not paid),
				"zero-wallet affordability matches the signed outcome: " + event_id + " / " + choice_id)
			if paid:
				var denied := scarce.choose_with_wallet(choice_id, zero)
				_check(denied.get("ok") == false and denied.get("wallet") == zero,
					"a signed debit is refused at an empty wallet: " + event_id + " / " + choice_id)
				_check(not scarce.is_claimed() and scarce.is_valid(),
					"a refused debit keeps the visit open: " + event_id + " / " + choice_id)
				_check(not fallback_def.is_empty(), "a refused debit has a free fallback: "
					+ event_id + " / " + choice_id)
				if not fallback_def.is_empty():
					var fallback_id: String = fallback_def["id"]
					var fallback := scarce.choose_with_wallet(fallback_id, zero)
					_check(fallback.get("ok") == true and fallback.get("wallet") == {
						"gold": int(fallback_def["gold"]), "scraps": int(fallback_def["scraps"])},
						"the same selector settles the free fallback: " + event_id + " / " + choice_id)
					_check(scarce.is_claimed() and scarce.choose_with_wallet(fallback_id, zero).get("ok") == false,
						"the fallback claim is single: " + event_id + " / " + choice_id)
			else:
				var granted := scarce.choose_with_wallet(choice_id, zero)
				_check(granted.get("ok") == true and granted.get("wallet") == {
					"gold": gold_delta, "scraps": scraps_delta},
					"a nonnegative choice settles at an empty wallet: " + event_id + " / " + choice_id)
				_check(scarce.is_claimed() and scarce.choose_with_wallet(choice_id, zero).get("ok") == false,
					"the empty-wallet claim cannot be replayed: " + event_id + " / " + choice_id)
			_check(zero == zero_snapshot, "the caller's empty wallet is unchanged: "
				+ event_id + " / " + choice_id)
		# An unknown choice ID is denied without consuming the visit.
		var stranger := RunEventChoice.new(source_record)
		var unknown_claim := stranger.choose_with_wallet("unlisted_choice", zero)
		_check(unknown_claim.get("ok") == false and unknown_claim.get("wallet") == zero
			and not stranger.is_claimed() and stranger.is_valid(),
			"an unknown choice ID is denied without consuming the visit: " + event_id)
		_check(forecast_service.is_valid(), "previews never consume the visit: " + event_id)
		_check(funded == funded_snapshot, "the caller's funded wallet is unchanged: " + event_id)
	_check(rotation.get_generic_events() == listing_snapshot,
		"the midnight-story batch never mutates the rotation listing")
	_check(rng_guard.state == guard_state,
		"selections, previews and claims never touch an unrelated run RNG")


## Table-driven verification of the six V3-4 lantern-haunted wallet-only Events
## appended to the generic M04 rotation. The expected contract below is an
## independent copy of the authored stories and signed outcomes; it never reads
## the production catalog or the selector's constants back as its oracle. Only
## per-ID membership is asserted: no catalog total and no ordered ID list, so
## peer batches can land in the same catalog without clashing.
func _test_lantern_haunted_event_batch() -> void:
	var expected: Dictionary = {
		"v3_ghostlight_playhouse": {
			"title": "The Ghostlight Playhouse",
			"description": "Button-eyed actors bow beneath a lone amber candle in a theatre of torn oxblood velvet.",
			"choices": [
				{"id": "gather_prop_ribbons", "text": "Gather dropped costume ribbons (+2 scraps)", "gold": 0, "scraps": 2},
				{"id": "rent_footlights", "text": "Rent the spare footlights (spend 17 gold; gain 3 scraps)", "gold": -17, "scraps": 3},
				{"id": "close_curtain", "text": "Close the velvet curtain and leave", "gold": 0, "scraps": 0},
			],
		},
		"v3_frosted_pincushion": {
			"title": "The Frosted Pincushion",
			"description": "A mountain-sized pincushion bristles with icy needles while its brass pins ring like bells.",
			"choices": [
				{"id": "pull_copper_pin", "text": "Pull a loose copper pin (+12 gold)", "gold": 12, "scraps": 0},
				{"id": "reline_needle_cap", "text": "Re-line a needle cap (spend 2 scraps; gain 26 gold)", "gold": 26, "scraps": -2},
				{"id": "skirt_ice", "text": "Skirt the frozen cushion and leave", "gold": 0, "scraps": 0},
			],
		},
		"v3_threadbare_aviary": {
			"title": "The Threadbare Aviary",
			"description": "Clockwork felt birds rustle in a stitched cage whose roof has lost its final seam.",
			"choices": [
				{"id": "gather_fallen_feathers", "text": "Gather soft feather stuffing (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "mend_birdcage", "text": "Buy cage-repair thread (spend 13 gold; gain 2 scraps)", "gold": -13, "scraps": 2},
				{"id": "leave_birds", "text": "Let the birds rest and leave", "gold": 0, "scraps": 0},
			],
		},
		"v3_oxblood_moss_garden": {
			"title": "The Oxblood Moss Garden",
			"description": "Plush midnight roses bloom from the stitched pockets of a wandering quilt garden.",
			"choices": [
				{"id": "gather_garden_trim", "text": "Collect clipped rose hems (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "sell_rose_ribbon", "text": "Trade one saved scrap for a rose ribbon (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
				{"id": "leave_garden", "text": "Walk out through the moss gate", "gold": 0, "scraps": 0},
			],
		},
		"v3_cloud_hem_windmill": {
			"title": "The Cloud-Hem Windmill",
			"description": "A patchwork windmill turns its broad cloud-patterned sails above a valley of sewn grasses.",
			"choices": [
				{"id": "crank_spool", "text": "Crank the spare spool for wages (+7 gold)", "gold": 7, "scraps": 0},
				{"id": "trade_cuttings", "text": "Sell two sailcloth scraps (spend 2 scraps; gain 32 gold)", "gold": 32, "scraps": -2},
				{"id": "watch_sails", "text": "Watch the sails turn and leave", "gold": 0, "scraps": 0},
			],
		},
		"v3_stone_button_forge": {
			"title": "The Stone Button Forge",
			"description": "A giant button-eyed smith hammers moon-bright brass circles on an embroidered anvil.",
			"choices": [
				{"id": "sweep_button_shanks", "text": "Sweep stray button shanks (+2 scraps)", "gold": 0, "scraps": 2},
				{"id": "buy_thread_steel", "text": "Buy three spools of thread-steel (spend 21 gold; gain 3 scraps)", "gold": -21, "scraps": 3},
				{"id": "leave_forge", "text": "Leave the forge before the next bell", "gold": 0, "scraps": 0},
			],
		},
	}
	## Independent per-ID seeds for the forced single-eligible selection replay.
	var seeds: Dictionary = {
		"v3_ghostlight_playhouse": 72001,
		"v3_frosted_pincushion": 72002,
		"v3_threadbare_aviary": 72003,
		"v3_oxblood_moss_garden": 72004,
		"v3_cloud_hem_windmill": 72005,
		"v3_stone_button_forge": 72006,
	}
	## Earlier named generic IDs this additive batch must leave eligible.
	var earlier_generic_ids: Array[String] = [
		"lantern_moth_clearing",
		"patchwork_ferry",
		"spool_clocktower",
		"ragpicker_cart",
		"quilt_bridge",
		"button_moon_festival",
		"v3_lost_thimble_ball",
		"v3_moonlace_tailor",
		"v3_copper_bell_choir",
		"v3_stitched_rooftop_market",
		"v3_torn_parasol_caravan",
		"v3_silk_mirror_fountain",
	]
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	var listing_snapshot: Array = listing.duplicate(true)
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 818181
	var guard_state := rng_guard.state
	for earlier_id in earlier_generic_ids:
		_check(_matches(_source_events(), earlier_id).size() == 1,
			"an earlier authored record stays exactly once in the source: " + earlier_id)
		_check(ids.count(earlier_id) == 1,
			"an earlier generic ID stays eligible exactly once: " + earlier_id)
	_check(_matches(_source_events(), SPECIAL_ID).size() == 1,
		"the special quiet_spool record stays in the source catalog")
	_check(_matches(listing, SPECIAL_ID).is_empty() and not ids.has(SPECIAL_ID),
		"the lantern-haunted batch never pulls quiet_spool into the rotation")
	for event_id in expected:
		var contract: Dictionary = expected[event_id]
		# Exactly one sourced record and one generic rotation record per ID.
		var sourced_matches := _matches(_source_events(), event_id)
		_check(sourced_matches.size() == 1, "exactly one sourced record for " + event_id)
		var listed_matches := _matches(listing, event_id)
		_check(listed_matches.size() == 1, "exactly one generic rotation record for " + event_id)
		_check(ids.count(event_id) == 1, "the generic ID listing carries " + event_id + " exactly once")
		if sourced_matches.size() != 1 or listed_matches.size() != 1:
			continue
		var source_record: Dictionary = sourced_matches[0]
		var record: Dictionary = listed_matches[0]
		_check(record == source_record, "the rotation copies the authored record: " + event_id)
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"authored record carries exactly id/title/description/choices: " + event_id)
		_check(record.get("title") == contract["title"], "authored title: " + event_id)
		_check(record.get("description") == contract["description"], "authored description: " + event_id)
		var choices: Array = record.get("choices", [])
		_check(choices.size() == 3, "three authored choices: " + event_id)
		var by_choice: Dictionary = {}
		for choice in choices:
			_check(choice is Dictionary, "every choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_key: Variant = (choice as Dictionary).get("id")
			_check(choice_key is String, "every choice has a string ID: " + event_id)
			if not choice_key is String:
				continue
			_check(not by_choice.has(choice_key), "choice IDs are distinct: " + event_id + " / " + str(choice_key))
			by_choice[choice_key] = choice
		_check(by_choice.size() == 3, "three distinct choice IDs: " + event_id)
		for choice_def in contract["choices"]:
			var choice_id: String = choice_def["id"]
			_check(by_choice.has(choice_id), "authored choice present: " + event_id + " / " + choice_id)
			if not by_choice.has(choice_id):
				continue
			var choice: Dictionary = by_choice[choice_id]
			_check(choice.get("text") == choice_def["text"],
				"authored choice text: " + event_id + " / " + choice_id)
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "choice outcome is an object: " + event_id + " / " + choice_id)
			if not outcome is Dictionary:
				continue
			var outcome_dict: Dictionary = outcome
			_check(outcome_dict.size() == 2 and outcome_dict.has("gold") and outcome_dict.has("scraps"),
				"exact signed outcome keys: " + event_id + " / " + choice_id)
			# JSON parsing may deliver whole numbers as floats; the authored
			# contract is a whole signed amount either way.
			var gold_amount: Variant = _signed_amount(outcome_dict.get("gold"))
			var scraps_amount: Variant = _signed_amount(outcome_dict.get("scraps"))
			_check(gold_amount != null and scraps_amount != null,
				"whole-number outcome amounts: " + event_id + " / " + choice_id)
			_check(gold_amount == choice_def["gold"] and scraps_amount == choice_def["scraps"],
				"authored signed outcome: " + event_id + " / " + choice_id)
		# Excluding every other generic ID leaves only this event, which the real
		# selector must return after exactly one range draw.
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var seed_value: int = seeds[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "forced selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "forced selection returns " + event_id)
		_check(rng.state == oracle.state, "forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"identical seed and exclusions replay " + event_id)
		# The returned record is a detached copy of the authored record.
		var selected_snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		selected["injected"] = true
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == selected_snapshot and detached.get("event") == source_record,
			"the selected " + event_id + " is a detached authored copy")
		# Wallet play consumes the record the real selector just handed back, not the source document.
		var wallet_record: Dictionary = detached.get("event", {})
		_check(wallet_record == source_record,
			"the selector hands back the authentic record for wallet play: " + event_id)
		# Wallet preview and one-shot settlement for all three authored choices.
		var funded := {"gold": 100, "scraps": 5}
		var funded_snapshot: Dictionary = funded.duplicate(true)
		var zero := {"gold": 0, "scraps": 0}
		var forecast_service := RunEventChoice.new(wallet_record)
		_check(forecast_service.is_valid(), "authored record is a valid RunEventChoice: " + event_id)
		var preview := forecast_service.preview_wallet_choices(funded)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"funded preview succeeds: " + event_id)
		var rows := _preview_map(preview)
		_check(rows.size() == 3, "funded preview lists all three choices: " + event_id)
		var free_def: Dictionary = {}
		for choice_def in contract["choices"]:
			if int(choice_def["gold"]) == 0 and int(choice_def["scraps"]) == 0:
				free_def = choice_def
		_check(not free_def.is_empty(), "each event keeps one free Leave choice: " + event_id)
		for choice_def in contract["choices"]:
			var choice_id: String = choice_def["id"]
			var gold_delta: int = choice_def["gold"]
			var scraps_delta: int = choice_def["scraps"]
			var after := {"gold": 100 + gold_delta, "scraps": 5 + scraps_delta}
			var row: Dictionary = rows.get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var committed := RunEventChoice.new(wallet_record)
			var receipt := committed.choose_with_wallet(choice_id, funded)
			_check(receipt.get("ok") == true and receipt.get("event_id") == event_id
				and receipt.get("choice_id") == choice_id,
				"exact authored claim: " + event_id + " / " + choice_id)
			_check(receipt.get("wallet") == after,
				"the claim applies the authored deltas once: " + event_id + " / " + choice_id)
			_check(committed.is_claimed() and not committed.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay_claim := committed.choose_with_wallet(choice_id, funded)
			_check(replay_claim.get("ok") == false and replay_claim.get("wallet") == funded,
				"the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			var alternate_id: String = choice_id
			for other_def in contract["choices"]:
				if other_def["id"] != choice_id:
					alternate_id = other_def["id"]
					break
			var alternate_claim := committed.choose_with_wallet(alternate_id, funded)
			_check(alternate_claim.get("ok") == false and alternate_claim.get("wallet") == funded,
				"no alternate choice claims a spent visit: " + event_id + " / " + choice_id)
			# Signed debits at an empty wallet: refused without consuming the visit,
			# then the same selector settles its authored free Leave.
			var paid := gold_delta < 0 or scraps_delta < 0
			var zero_snapshot: Dictionary = zero.duplicate(true)
			var scarce := RunEventChoice.new(wallet_record)
			var scarce_rows := _preview_map(scarce.preview_wallet_choices(zero))
			_check(scarce_rows.get(choice_id, {}).get("affordable") == (not paid),
				"zero-wallet affordability matches the signed outcome: " + event_id + " / " + choice_id)
			if paid:
				var denied := scarce.choose_with_wallet(choice_id, zero)
				_check(denied.get("ok") == false and denied.get("wallet") == zero,
					"a signed debit is refused at an empty wallet: " + event_id + " / " + choice_id)
				_check(not scarce.is_claimed() and scarce.is_valid(),
					"a refused debit keeps the visit open: " + event_id + " / " + choice_id)
				if not free_def.is_empty():
					var fallback_id: String = free_def["id"]
					var fallback := scarce.choose_with_wallet(fallback_id, zero)
					_check(fallback.get("ok") == true and fallback.get("wallet") == zero,
						"the same visit still settles its free Leave: " + event_id + " / " + choice_id)
					_check(scarce.is_claimed()
						and scarce.choose_with_wallet(fallback_id, zero).get("ok") == false,
						"the free Leave claim is single: " + event_id + " / " + choice_id)
			else:
				var granted := scarce.choose_with_wallet(choice_id, zero)
				_check(granted.get("ok") == true and granted.get("wallet") == {
					"gold": gold_delta, "scraps": scraps_delta},
					"a nonnegative choice settles at an empty wallet: " + event_id + " / " + choice_id)
				_check(scarce.is_claimed() and scarce.choose_with_wallet(choice_id, zero).get("ok") == false,
					"the empty-wallet claim cannot be replayed: " + event_id + " / " + choice_id)
			_check(zero == zero_snapshot, "the caller's empty wallet is unchanged: "
				+ event_id + " / " + choice_id)
		# An unknown choice ID is denied without consuming the visit.
		var stranger := RunEventChoice.new(wallet_record)
		var unknown_claim := stranger.choose_with_wallet("unlisted_choice", zero)
		_check(unknown_claim.get("ok") == false and unknown_claim.get("wallet") == zero
			and not stranger.is_claimed() and stranger.is_valid(),
			"an unknown choice ID is denied without consuming the visit: " + event_id)
		_check(forecast_service.is_valid(), "previews never consume the visit: " + event_id)
		_check(funded == funded_snapshot, "the caller's funded wallet is unchanged: " + event_id)
	_check(rotation.get_generic_events() == listing_snapshot,
		"the lantern-haunted batch never mutates the rotation listing")
	_check(rng_guard.state == guard_state,
		"selections, previews and claims never touch an unrelated run RNG")


## Table-driven verification of the six Candlelit Bargain wallet Events promoted
## from the separate authored source into the generic M04 rotation. The expected
## contract below is an independent copy of the authored story and signed
## outcomes; the canonical candlelit file is also parsed and compared by ID.
## Only per-ID membership is asserted: no catalog total and no ordered ID list,
## so peer batches can land in the same catalog without clashing.
func _test_candlelit_bargain_event_batch() -> void:
	var expected: Dictionary = {
		"lantern_bobbin_ferry": {
			"title": "The Lantern Bobbin Ferry",
			"description": "A bobbin boat rocks beneath hanging lanterns, its ragdoll ferryman winding loose thread in the amber hush.",
			"choices": [
				{"id": "buy_passage", "text": "Pay the ferryman 12 gold for loose thread (+2 scraps)", "gold": -12, "scraps": 2},
				{"id": "ferry_parcels", "text": "Trade a thread bundle for parcel wages (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
				{"id": "walk_bank", "text": "Walk along the bank (no cost or gain)", "gold": 0, "scraps": 0},
			],
		},
		"thimble_star_reading": {
			"title": "The Thimble Star Reading",
			"description": "A felt fortune-reader peers through a silver thimble at stitched constellations, their frame trailing pale starlint.",
			"choices": [
				{"id": "offer_thread", "text": "Sell a spool to the reader (spend 1 scrap; gain 16 gold)", "gold": 16, "scraps": -1},
				{"id": "gather_starlint", "text": "Collect thread caught in the frame (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "pass_by", "text": "Pass by (no cost or gain)", "gold": 0, "scraps": 0},
			],
		},
		"moonpatch_archway": {
			"title": "The Moonpatch Archway",
			"description": "Tiny cloth patches line a crescent arch; dangling price tags whisper against its candlelit seams.",
			"choices": [
				{"id": "purchase_two_spools", "text": "Purchase two spools (spend 15 gold; gain 2 scraps)", "gold": -15, "scraps": 2},
				{"id": "sell_two_spools", "text": "Sell two spools (spend 2 scraps; gain 27 gold)", "gold": 27, "scraps": -2},
				{"id": "keep_walking", "text": "Keep walking (no cost or gain)", "gold": 0, "scraps": 0},
			],
		},
		"blacklace_swap_table": {
			"title": "The Blacklace Swap Table",
			"description": "Small button-eyed puppets barter ribbons over an ink-black lace tablecloth, their stitched smiles lit by candle stubs.",
			"choices": [
				{"id": "take_small_bundle", "text": "Buy a small ribbon bundle (spend 8 gold; gain 1 scrap)", "gold": -8, "scraps": 1},
				{"id": "trade_own_bundle", "text": "Sell your own bundle (spend 1 scrap; gain 14 gold)", "gold": 14, "scraps": -1},
				{"id": "decline_trade", "text": "Decline the trade (no cost or gain)", "gold": 0, "scraps": 0},
			],
		},
		"crooked_marionette": {
			"title": "The Crooked Marionette",
			"description": "A wooden puppet dangles crookedly above a candle, offering a little coin purse for rethreading its frayed strings.",
			"choices": [
				{"id": "retie_strings", "text": "Rethread the puppet's strings (spend 2 scraps; earn 30 gold)", "gold": 30, "scraps": -2},
				{"id": "gather_cuttings", "text": "Gather discarded thread cuttings (+1 scrap)", "gold": 0, "scraps": 1},
				{"id": "leave_puppet", "text": "Leave the puppet (no cost or gain)", "gold": 0, "scraps": 0},
			],
		},
		"dusk_post_bobbin": {
			"title": "The Dusk Post Bobbin",
			"description": "A patchwork postbox totters on a walking spindle, accepting thread-wrapped letters through a softly glowing slot.",
			"choices": [
				{"id": "send_letter", "text": "Pay postage and receive spare wrapping thread (spend 10 gold; gain 1 scrap)", "gold": -10, "scraps": 1},
				{"id": "deliver_letters", "text": "Wrap letters for delivery wages (spend 1 scrap; earn 17 gold)", "gold": 17, "scraps": -1},
				{"id": "ignore_post", "text": "Pass the postbox (no cost or gain)", "gold": 0, "scraps": 0},
			],
		},
	}
	## Independent per-ID seeds for the forced single-eligible selection replay.
	var seeds: Dictionary = {
		"lantern_bobbin_ferry": 82001,
		"thimble_star_reading": 82002,
		"moonpatch_archway": 82003,
		"blacklace_swap_table": 82004,
		"crooked_marionette": 82005,
		"dusk_post_bobbin": 82006,
	}
	var reference: Dictionary = _load_candlelit_by_id()
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the promoted candlelit batch keeps the shipped rotation valid")
	var listing: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	var listing_snapshot: Array = listing.duplicate(true)
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 919191
	var guard_state := rng_guard.state
	# Earlier named generic anchors stay eligible and the separately routed
	# special never joins the generic pool.
	for anchor in REQUIRED_IDS:
		_check(ids.count(anchor) == 1, "the promoted batch keeps the earlier anchor eligible: " + anchor)
	_check(_matches(_source_events(), SPECIAL_ID).size() == 1,
		"the special quiet_spool record stays in the source catalog")
	_check(_matches(listing, SPECIAL_ID).is_empty() and not ids.has(SPECIAL_ID),
		"the promoted candlelit batch never pulls quiet_spool into the rotation")
	for event_id in expected:
		var contract: Dictionary = expected[event_id]
		var candlelit: Dictionary = reference.get(event_id, {})
		_check(not candlelit.is_empty(), "the authored candlelit source still carries " + event_id)
		if candlelit.is_empty():
			continue
		_check(candlelit.get("title") == contract["title"], "authored candlelit title: " + event_id)
		_check(candlelit.get("description") == contract["description"],
			"authored candlelit description: " + event_id)
		# Exactly one promoted M04 source record, one generic rotation record and
		# one eligible ID, all verbatim copies of the candlelit source record.
		var sourced_matches := _matches(_source_events(), event_id)
		_check(sourced_matches.size() == 1, "exactly one promoted M04 source record for " + event_id)
		var listed_matches := _matches(listing, event_id)
		_check(listed_matches.size() == 1, "exactly one generic rotation record for " + event_id)
		_check(ids.count(event_id) == 1, "the generic ID listing carries " + event_id + " exactly once")
		if sourced_matches.size() != 1 or listed_matches.size() != 1:
			continue
		var authored: Dictionary = sourced_matches[0]
		var listed: Dictionary = listed_matches[0]
		_check(authored == candlelit, "the promoted M04 record is verbatim: " + event_id)
		_check(listed == candlelit, "the rotation copies the authored candlelit record: " + event_id)
		_check(authored.size() == 4 and authored.has("id") and authored.has("title")
			and authored.has("description") and authored.has("choices"),
			"authored record carries exactly id/title/description/choices: " + event_id)
		_check(authored.get("title") == contract["title"], "promoted authored title: " + event_id)
		_check(authored.get("description") == contract["description"],
			"promoted authored description: " + event_id)
		var choices: Array = authored.get("choices", [])
		_check(choices.size() == 3, "three authored choices: " + event_id)
		var expected_choices: Array = contract["choices"]
		for index in range(expected_choices.size()):
			var choice_def: Dictionary = expected_choices[index]
			var choice_id: String = choice_def["id"]
			_check(index < choices.size(), "authored choice slot exists: " + event_id + " / " + choice_id)
			if index >= choices.size():
				continue
			var choice: Variant = choices[index]
			_check(choice is Dictionary, "every choice is an object: " + event_id + " / " + choice_id)
			if not choice is Dictionary:
				continue
			_check(choice.get("id") == choice_id,
				"authored ordered choice ID: " + event_id + " / " + choice_id)
			_check(choice.get("text") == choice_def["text"],
				"authored choice text: " + event_id + " / " + choice_id)
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "choice outcome is an object: " + event_id + " / " + choice_id)
			if not outcome is Dictionary:
				continue
			var outcome_dict: Dictionary = outcome
			_check(outcome_dict.size() == 2 and outcome_dict.has("gold") and outcome_dict.has("scraps"),
				"exact signed outcome keys: " + event_id + " / " + choice_id)
			# JSON parsing may deliver whole numbers as floats; the authored
			# contract is a whole signed amount either way.
			_check(_signed_amount(outcome_dict.get("gold")) == choice_def["gold"]
				and _signed_amount(outcome_dict.get("scraps")) == choice_def["scraps"],
				"authored signed outcome: " + event_id + " / " + choice_id)
		# Excluding every other currently eligible ID leaves only this event, which
		# the real no-argument selector must return after exactly one draw.
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var seed_value: int = seeds[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "forced selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "forced selection returns " + event_id)
		_check(rng.state == oracle.state, "forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"identical seed and exclusions replay " + event_id)
		_check(selected == candlelit, "the selector hands back the authored candlelit record: " + event_id)
		if selected.is_empty():
			continue
		# Wallet preview and one-shot settlement for all three authored choices.
		var funded := {"gold": 50, "scraps": 5}
		var funded_snapshot: Dictionary = funded.duplicate(true)
		var zero := {"gold": 0, "scraps": 0}
		var zero_snapshot: Dictionary = zero.duplicate(true)
		var forecast_service := RunEventChoice.new(selected)
		_check(forecast_service.is_valid(), "authored record is a valid RunEventChoice: " + event_id)
		var preview := forecast_service.preview_wallet_choices(funded)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"funded preview succeeds: " + event_id)
		var rows := _preview_map(preview)
		_check(rows.size() == 3, "funded preview lists all three choices: " + event_id)
		var free_choice_ids: Array = []
		for choice_def in expected_choices:
			var choice_id: String = choice_def["id"]
			var gold_delta: int = choice_def["gold"]
			var scraps_delta: int = choice_def["scraps"]
			var after := {"gold": 50 + gold_delta, "scraps": 5 + scraps_delta}
			var row: Dictionary = rows.get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var service := RunEventChoice.new(selected)
			var receipt := service.choose_with_wallet(choice_id, funded)
			_check(receipt.get("ok") == true and receipt.get("event_id") == event_id
				and receipt.get("choice_id") == choice_id,
				"exact authored claim: " + event_id + " / " + choice_id)
			_check(receipt.get("wallet") == after,
				"the claim applies the authored deltas once: " + event_id + " / " + choice_id)
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay_claim := service.choose_with_wallet(choice_id, funded)
			_check(replay_claim.get("ok") == false and replay_claim.get("wallet") == funded,
				"the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			if gold_delta == 0 and scraps_delta == 0:
				free_choice_ids.append(choice_id)
			# Signed debits at an empty wallet: refused without consuming the visit.
			var paid := gold_delta < 0 or scraps_delta < 0
			var scarce := RunEventChoice.new(selected)
			var scarce_rows := _preview_map(scarce.preview_wallet_choices(zero))
			_check(scarce_rows.get(choice_id, {}).get("affordable") == (not paid),
				"zero-wallet affordability matches the signed outcome: "
				+ event_id + " / " + choice_id)
			if paid:
				var denied := scarce.choose_with_wallet(choice_id, zero)
				_check(denied.get("ok") == false and denied.get("wallet") == zero,
					"a signed debit is refused at an empty wallet: " + event_id + " / " + choice_id)
				_check(not scarce.is_claimed() and scarce.is_valid(),
					"a refused debit keeps the visit open: " + event_id + " / " + choice_id)
			else:
				var granted := scarce.choose_with_wallet(choice_id, zero)
				_check(granted.get("ok") == true and granted.get("wallet") == {
					"gold": gold_delta, "scraps": scraps_delta},
					"a nonnegative choice settles at an empty wallet: " + event_id + " / " + choice_id)
				_check(scarce.is_claimed() and scarce.choose_with_wallet(choice_id, zero).get("ok") == false,
					"the empty-wallet claim cannot be replayed: " + event_id + " / " + choice_id)
		# The authored free leave still settles a clean (0, 0) transaction.
		_check(free_choice_ids.size() == 1, "each promoted event keeps exactly one free leave: " + event_id)
		for free_id in free_choice_ids:
			var leave_service := RunEventChoice.new(selected)
			var leave := leave_service.choose_with_wallet(free_id, zero)
			_check(leave.get("ok") == true and leave.get("wallet") == zero,
				"the free leave settles (0,0): " + event_id + " / " + free_id)
			_check(leave_service.is_claimed()
				and leave_service.choose_with_wallet(free_id, zero).get("ok") == false,
				"the free leave claim is single: " + event_id + " / " + free_id)
		# An unknown choice ID is denied without consuming the visit.
		var stranger := RunEventChoice.new(selected)
		var unknown_claim := stranger.choose_with_wallet("unlisted_choice", zero)
		_check(unknown_claim.get("ok") == false and unknown_claim.get("wallet") == zero
			and not stranger.is_claimed() and stranger.is_valid(),
			"an unknown choice ID is denied without consuming the visit: " + event_id)
		_check(forecast_service.is_valid(), "previews never consume the visit: " + event_id)
		_check(funded == funded_snapshot and zero == zero_snapshot,
			"the caller's funded and empty wallets are unchanged: " + event_id)
	_check(rotation.get_generic_events() == listing_snapshot,
		"the candlelit batch never mutates the rotation listing")
	_check(rng_guard.state == guard_state,
		"selections, previews and claims never touch an unrelated run RNG")


## Table-driven verification of the six remaining V3-4 Candlelit Bargain wallet
## Events promoted directly from v3_candlelit_bargains.json by the default
## RunM04EventRotation without re-copying them into m04_events.json or doubling
## the earlier six.
func _test_remaining_candlelit_bargain_event_batch() -> void:
	var expected: Dictionary = {
		"v3_bellglass_night_market": {
			"title": "The Bellglass Night Market",
			"description": "Round button-eyed merchants count glass bells beneath plum awnings, every bobbin lit by a single amber lantern.",
			"choices": [
				{"id": "buy_velvet_thread", "text": "Pay 26 gold for three bundles of midnight thread (+3 scraps)", "gold": -26, "scraps": 3},
				{"id": "trade_three_loops", "text": "Trade three scrap bundles for 39 gold", "gold": 39, "scraps": -3},
				{"id": "leave", "text": "Leave the bellglass traders to their counting", "gold": 0, "scraps": 0},
			],
		},
		"v3_crowlace_ticket_booth": {
			"title": "The Crowlace Ticket Booth",
			"description": "A stuffed crow in a gold-button waistcoat stamps crooked ferry tickets beside a black-lace window.",
			"choices": [
				{"id": "buy_night_pass", "text": "Pay 18 gold for a pair of thread tickets (+2 scraps)", "gold": -18, "scraps": 2},
				{"id": "sell_spare_ticket", "text": "Exchange one spare scrap bundle for 15 gold", "gold": 15, "scraps": -1},
				{"id": "leave", "text": "Let the paper tickets flutter away", "gold": 0, "scraps": 0},
			],
		},
		"v3_moonlit_pin_exchange": {
			"title": "The Moonlit Pin Exchange",
			"description": "A slate-blue puppet clerk opens a pin-lined drawer beneath a stitched button moon.",
			"choices": [
				{"id": "order_pin_roll", "text": "Pay 34 gold for five rolled pin bundles (+5 scraps)", "gold": -34, "scraps": 5},
				{"id": "redeem_spare_pins", "text": "Turn two scrap bundles into 33 gold", "gold": 33, "scraps": -2},
				{"id": "leave", "text": "Close the pin drawer without trading", "gold": 0, "scraps": 0},
			],
		},
		"v3_oxblood_patch_hall": {
			"title": "The Oxblood Patch Hall",
			"description": "Tiny velvet ragdolls hold a candlelit auction around an oxblood quilt sewn with brass-button seals.",
			"choices": [
				{"id": "buy_quilt_seam", "text": "Spend 23 gold on three fine repair seams (+3 scraps)", "gold": -23, "scraps": 3},
				{"id": "auction_old_patch", "text": "Auction four scrap bundles for 51 gold", "gold": 51, "scraps": -4},
				{"id": "leave", "text": "Bow out before the next auction bell", "gold": 0, "scraps": 0},
			],
		},
		"v3_bonecream_button_press": {
			"title": "The Bone-Cream Button Press",
			"description": "A squat stitched machinist works a giant button press under cream damask curtains.",
			"choices": [
				{"id": "buy_brass_mould", "text": "Buy a mould offcut for 12 gold (+1 scrap)", "gold": -12, "scraps": 1},
				{"id": "pawn_needle_wheel", "text": "Pawn two scrap bundles for 22 gold", "gold": 22, "scraps": -2},
				{"id": "leave", "text": "Let the press fall silent", "gold": 0, "scraps": 0},
			],
		},
		"v3_saffron_spool_trial": {
			"title": "The Saffron Spool Trial",
			"description": "A plump saffron-robed spool-keeper displays prize threads in a midnight-teal candlelit alcove.",
			"choices": [
				{"id": "buy_trial_thread", "text": "Pay 40 gold for five prize-thread bundles (+5 scraps)", "gold": -40, "scraps": 5},
				{"id": "sell_spool_braid", "text": "Sell two scrap bundles for 31 gold", "gold": 31, "scraps": -2},
				{"id": "leave", "text": "Decline the spool-keeper’s trial", "gold": 0, "scraps": 0},
			],
		},
	}
	var earlier_candlelit_ids: Array[String] = [
		"lantern_bobbin_ferry",
		"thimble_star_reading",
		"moonpatch_archway",
		"blacklace_swap_table",
		"crooked_marionette",
		"dusk_post_bobbin",
	]
	var roadside_anchor_ids: Array[String] = [
		"v3_raincoat_bridge",
		"v3_puppet_box_office",
		"v3_mismatched_mittens",
		"v3_coil_and_crow",
		"v3_patchwork_lighthouse",
		"v3_button_orchard",
		"v3_lacework_railway",
		"v3_moonshadow_tailor",
		"v3_sleeping_thimble_giant",
		"v3_needlefall_star",
		"v3_jackdaw_stitchmarket",
		"v3_dreaming_quilt_fair",
	]
	var seeds: Dictionary = {
		"v3_bellglass_night_market": 92001,
		"v3_crowlace_ticket_booth": 92002,
		"v3_moonlit_pin_exchange": 92003,
		"v3_oxblood_patch_hall": 92004,
		"v3_bonecream_button_press": 92005,
		"v3_saffron_spool_trial": 92006,
	}
	var reference: Dictionary = _load_candlelit_by_id()
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the remaining candlelit promotion keeps the default rotation valid")
	var listing: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	var listing_snapshot: Array = listing.duplicate(true)
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 949494
	var guard_state := rng_guard.state
	for anchor in REQUIRED_IDS:
		_check(ids.count(anchor) == 1, "original generic anchor stays eligible once: " + anchor)
	for roadside_id in roadside_anchor_ids:
		_check(ids.count(roadside_id) == 1, "roadside anchor stays eligible once: " + roadside_id)
	for earlier_id in earlier_candlelit_ids:
		_check(_matches(_source_events(), earlier_id).size() == 1,
			"earlier promoted candlelit story stays once in m04_events.json: " + earlier_id)
		_check(_matches(listing, earlier_id).size() == 1 and ids.count(earlier_id) == 1,
			"earlier promoted candlelit story is never doubled in the default rotation: " + earlier_id)
	_check(_matches(_source_events(), SPECIAL_ID).size() == 1,
		"the special quiet_spool record stays in the generic source catalog")
	_check(_matches(listing, SPECIAL_ID).is_empty() and not ids.has(SPECIAL_ID),
		"quiet_spool stays excluded from the default generic rotation")
	for event_id in expected:
		var contract: Dictionary = expected[event_id]
		var candlelit: Dictionary = reference.get(event_id, {})
		_check(not candlelit.is_empty(), "the candlelit source carries " + event_id)
		if candlelit.is_empty():
			continue
		_check(_matches(_source_events(), event_id).is_empty(),
			"newly promoted candlelit record is routed from its source without re-copying into m04_events.json: " + event_id)
		var listed_matches := _matches(listing, event_id)
		_check(listed_matches.size() == 1, "exactly one default rotation record for " + event_id)
		_check(ids.count(event_id) == 1, "the default ID listing carries " + event_id + " exactly once")
		if listed_matches.size() != 1:
			continue
		var listed: Dictionary = listed_matches[0]
		_check(listed == candlelit, "the default rotation serves the verbatim candlelit record: " + event_id)
		_check(listed.size() == 4 and listed.has("id") and listed.has("title")
			and listed.has("description") and listed.has("choices"),
			"promoted record carries exactly id/title/description/choices: " + event_id)
		_check(listed.get("title") == contract["title"], "authored title: " + event_id)
		_check(listed.get("description") == contract["description"], "authored description: " + event_id)
		var choices: Array = listed.get("choices", [])
		_check(choices.size() == 3, "three authored choices: " + event_id)
		var expected_choices: Array = contract["choices"]
		for index in range(expected_choices.size()):
			var choice_def: Dictionary = expected_choices[index]
			var choice_id: String = choice_def["id"]
			_check(index < choices.size(), "authored choice slot exists: " + event_id + " / " + choice_id)
			if index >= choices.size():
				continue
			var choice: Variant = choices[index]
			_check(choice is Dictionary, "every choice is an object: " + event_id + " / " + choice_id)
			if not choice is Dictionary:
				continue
			_check(choice.get("id") == choice_id,
				"authored ordered choice ID: " + event_id + " / " + choice_id)
			_check(choice.get("text") == choice_def["text"],
				"authored choice text: " + event_id + " / " + choice_id)
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "choice outcome is an object: " + event_id + " / " + choice_id)
			if not outcome is Dictionary:
				continue
			var outcome_dict: Dictionary = outcome
			_check(outcome_dict.size() == 2 and outcome_dict.has("gold") and outcome_dict.has("scraps"),
				"exact signed outcome keys: " + event_id + " / " + choice_id)
			_check(_signed_amount(outcome_dict.get("gold")) == choice_def["gold"]
				and _signed_amount(outcome_dict.get("scraps")) == choice_def["scraps"],
				"authored signed outcome: " + event_id + " / " + choice_id)
		# Forced selection under caller exclusions: one RNG draw, exact record equality and detachment.
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var seed_value: int = seeds[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "forced selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "forced selection returns " + event_id)
		_check(rng.state == oracle.state, "forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"identical seed and exclusions replay " + event_id)
		_check(selected == candlelit, "selected event equals the candlelit source record: " + event_id)
		var selected_snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == selected_snapshot and detached.get("event") == candlelit,
			"selected " + event_id + " is a detached authored copy")
		var wallet_record: Dictionary = detached.get("event", {})
		if wallet_record.is_empty():
			continue
		# Wallet preview and settlement across funded, exact-boundary, short-resource and empty wallets.
		var funded := {"gold": 100, "scraps": 10}
		var funded_snapshot: Dictionary = funded.duplicate(true)
		var zero := {"gold": 0, "scraps": 0}
		var zero_snapshot: Dictionary = zero.duplicate(true)
		var forecast_service := RunEventChoice.new(wallet_record)
		_check(forecast_service.is_valid(), "selected record is a valid RunEventChoice: " + event_id)
		var preview := forecast_service.preview_wallet_choices(funded)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"funded preview succeeds: " + event_id)
		var rows := _preview_map(preview)
		_check(rows.size() == 3, "funded preview lists all three choices: " + event_id)
		var free_choice_ids: Array = []
		for choice_def in expected_choices:
			var choice_id: String = choice_def["id"]
			var gold_delta: int = choice_def["gold"]
			var scraps_delta: int = choice_def["scraps"]
			var after := {"gold": 100 + gold_delta, "scraps": 10 + scraps_delta}
			var row: Dictionary = rows.get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var service := RunEventChoice.new(wallet_record)
			var receipt := service.choose_with_wallet(choice_id, funded)
			_check(receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": choice_id,
				"wallet": after,
			}, "choose_with_wallet settles exact signed receipt: " + event_id + " / " + choice_id)
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay_claim := service.choose_with_wallet(choice_id, funded)
			_check(replay_claim == {
				"ok": false,
				"event_id": "",
				"choice_id": "",
				"wallet": funded,
			}, "the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			for other_def in expected_choices:
				if other_def["id"] != choice_id:
					var alt_claim := service.choose_with_wallet(other_def["id"], funded)
					_check(alt_claim.get("ok") == false and alt_claim.get("wallet") == funded,
						"no alternate choice claims a spent visit: " + event_id + " / " + choice_id)
					break
			if gold_delta == 0 and scraps_delta == 0:
				free_choice_ids.append(choice_id)
			var paid := gold_delta < 0 or scraps_delta < 0
			if paid:
				var short_wallet := {
					"gold": (-gold_delta - 1) if gold_delta < 0 else 100,
					"scraps": (-scraps_delta - 1) if scraps_delta < 0 else 10,
				}
				var short_snapshot: Dictionary = short_wallet.duplicate(true)
				var short_service := RunEventChoice.new(wallet_record)
				var short_rows := _preview_map(short_service.preview_wallet_choices(short_wallet))
				_check(short_rows.get(choice_id, {}).get("affordable") == false
					and short_rows.get(choice_id, {}).get("wallet") == short_wallet,
					"short-resource wallet previews debit as unaffordable: " + event_id + " / " + choice_id)
				_check(short_rows.get("leave", {}).get("affordable") == true
					and short_rows.get("leave", {}).get("wallet") == short_wallet,
					"short-resource wallet keeps leave affordable: " + event_id + " / " + choice_id)
				var short_denied := short_service.choose_with_wallet(choice_id, short_wallet)
				_check(short_denied == {
					"ok": false,
					"event_id": "",
					"choice_id": "",
					"wallet": short_wallet,
				}, "short-resource debit is refused unchanged: " + event_id + " / " + choice_id)
				_check(not short_service.is_claimed() and short_service.is_valid(),
					"short-resource refusal preserves the visit claim: " + event_id + " / " + choice_id)
				var short_leave := short_service.choose_with_wallet("leave", short_wallet)
				_check(short_leave == {
					"ok": true,
					"event_id": event_id,
					"choice_id": "leave",
					"wallet": short_wallet,
				}, "same selector settles free leave after short-resource refusal: " + event_id + " / " + choice_id)
				_check(short_service.is_claimed() and not short_service.is_valid()
					and short_service.choose_with_wallet("leave", short_wallet).get("ok") == false,
					"free leave after refusal latches once: " + event_id + " / " + choice_id)
				_check(short_wallet == short_snapshot,
					"short-resource wallet input stays untouched: " + event_id + " / " + choice_id)
			var scarce := RunEventChoice.new(wallet_record)
			var scarce_rows := _preview_map(scarce.preview_wallet_choices(zero))
			_check(scarce_rows.get(choice_id, {}).get("affordable") == (not paid),
				"zero-wallet affordability matches the signed outcome: " + event_id + " / " + choice_id)
			if paid:
				var denied := scarce.choose_with_wallet(choice_id, zero)
				_check(denied.get("ok") == false and denied.get("wallet") == zero,
					"a signed debit is refused at an empty wallet: " + event_id + " / " + choice_id)
				_check(not scarce.is_claimed() and scarce.is_valid(),
					"a refused debit keeps the visit open: " + event_id + " / " + choice_id)
			else:
				var granted := scarce.choose_with_wallet(choice_id, zero)
				_check(granted == {
					"ok": true,
					"event_id": event_id,
					"choice_id": choice_id,
					"wallet": {"gold": gold_delta, "scraps": scraps_delta},
				}, "free leave settles at an empty wallet: " + event_id + " / " + choice_id)
				_check(scarce.is_claimed() and scarce.choose_with_wallet(choice_id, zero).get("ok") == false,
					"the empty-wallet claim cannot be replayed: " + event_id + " / " + choice_id)
		_check(free_choice_ids == ["leave"], "each newly promoted candlelit event offers free leave: " + event_id)
		var stranger := RunEventChoice.new(wallet_record)
		var unknown_claim := stranger.choose_with_wallet("unlisted_choice", zero)
		_check(unknown_claim.get("ok") == false and unknown_claim.get("wallet") == zero
			and not stranger.is_claimed() and stranger.is_valid(),
			"an unknown choice ID is denied without consuming the visit: " + event_id)
		_check(forecast_service.is_valid(), "previews never consume the visit: " + event_id)
		_check(funded == funded_snapshot and zero == zero_snapshot,
			"caller funded and empty wallets remain unchanged: " + event_id)
	_check(rotation.get_generic_events() == listing_snapshot,
		"the remaining candlelit batch never mutates the rotation listing")
	_check(rng_guard.state == guard_state,
		"selections, previews and claims never touch an unrelated run RNG")


## AC3 & AC4: injected fixtures stay independent of the shipping merge, and any
## missing, duplicated, malformed or cross-catalog-conflicting required candlelit
## record fails the default shipping merge closed and consumes no RNG.
func _test_candlelit_shipping_merge_validation() -> void:
	var injected_only := RunM04EventRotation.new(source_document)
	_check(injected_only.is_catalog_valid(), "an injected generic catalog fixture still validates on its own")
	var injected_ids: Array = injected_only.get_generic_event_ids()
	for promoted_id in PROMOTED_CANDLELIT_IDS:
		_check(not injected_ids.has(promoted_id),
			"an injected catalog fixture never receives the shipping candlelit merge: " + promoted_id)
	var generic_doc: Dictionary = {"events": _source_events()}
	var roadside_events: Array = _load_catalog_events(ROADSIDE_EVENTS_PATH)
	var roadside_doc: Dictionary = {"events": roadside_events}
	var candlelit_events: Array = _load_catalog_events(CANDLELIT_EVENTS_PATH)
	var candlelit_doc: Dictionary = {"events": candlelit_events}
	var candlelit_by_id: Dictionary = _load_candlelit_by_id()
	var cases: Array = [
		{"name": "null candlelit catalog", "g": generic_doc, "r": roadside_doc, "c": null},
		{"name": "candlelit catalog without events", "g": generic_doc, "r": roadside_doc, "c": {}},
		{"name": "candlelit events not an array", "g": generic_doc, "r": roadside_doc, "c": {"events": "v3_bellglass_night_market"}},
		{"name": "empty candlelit events", "g": generic_doc, "r": roadside_doc, "c": {"events": []}},
		{"name": "non-object candlelit record", "g": generic_doc, "r": roadside_doc, "c": {"events": _replaced(candlelit_events, "v3_bellglass_night_market", 42)}},
	]
	for promoted_id in PROMOTED_CANDLELIT_IDS:
		cases.append({
			"name": "missing required candlelit record " + promoted_id,
			"g": generic_doc,
			"r": roadside_doc,
			"c": {"events": _without(candlelit_events, promoted_id)},
		})
		var duplicated_candlelit: Array = candlelit_events.duplicate(true)
		duplicated_candlelit.append((candlelit_by_id[promoted_id] as Dictionary).duplicate(true))
		cases.append({
			"name": "duplicated required candlelit record " + promoted_id,
			"g": generic_doc,
			"r": roadside_doc,
			"c": {"events": duplicated_candlelit},
		})
	var duplicated_earlier: Array = candlelit_events.duplicate(true)
	duplicated_earlier.append((candlelit_by_id["lantern_bobbin_ferry"] as Dictionary).duplicate(true))
	cases.append({
		"name": "duplicated earlier candlelit record in candlelit source",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": duplicated_earlier},
	})
	var missing_id_rec: Dictionary = (candlelit_by_id["v3_bellglass_night_market"] as Dictionary).duplicate(true)
	missing_id_rec.erase("id")
	cases.append({
		"name": "required candlelit record without id",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": _replaced(candlelit_events, "v3_bellglass_night_market", missing_id_rec)},
	})
	var blank_title_rec: Dictionary = (candlelit_by_id["v3_crowlace_ticket_booth"] as Dictionary).duplicate(true)
	blank_title_rec["title"] = "   "
	cases.append({
		"name": "blank required candlelit title",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": _replaced(candlelit_events, "v3_crowlace_ticket_booth", blank_title_rec)},
	})
	var blank_desc_rec: Dictionary = (candlelit_by_id["v3_moonlit_pin_exchange"] as Dictionary).duplicate(true)
	blank_desc_rec["description"] = ""
	cases.append({
		"name": "blank required candlelit description",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": _replaced(candlelit_events, "v3_moonlit_pin_exchange", blank_desc_rec)},
	})
	var two_choices_rec: Dictionary = (candlelit_by_id["v3_oxblood_patch_hall"] as Dictionary).duplicate(true)
	(two_choices_rec["choices"] as Array).pop_back()
	cases.append({
		"name": "truncated two-choice required candlelit record",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": _replaced(candlelit_events, "v3_oxblood_patch_hall", two_choices_rec)},
	})
	var four_choices_rec: Dictionary = (candlelit_by_id["v3_oxblood_patch_hall"] as Dictionary).duplicate(true)
	(four_choices_rec["choices"] as Array).append({"id": "extra", "text": "Extra", "outcome": {"gold": 0, "scraps": 0}})
	cases.append({
		"name": "four-choice required candlelit record",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": _replaced(candlelit_events, "v3_oxblood_patch_hall", four_choices_rec)},
	})
	var dup_choice_rec: Dictionary = (candlelit_by_id["v3_bonecream_button_press"] as Dictionary).duplicate(true)
	((dup_choice_rec["choices"] as Array)[1] as Dictionary)["id"] = "buy_brass_mould"
	cases.append({
		"name": "duplicate choice ID in required candlelit record",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": _replaced(candlelit_events, "v3_bonecream_button_press", dup_choice_rec)},
	})
	var bad_outcome_rec: Dictionary = (candlelit_by_id["v3_saffron_spool_trial"] as Dictionary).duplicate(true)
	((bad_outcome_rec["choices"] as Array)[0] as Dictionary)["outcome"] = {"gold": -40}
	cases.append({
		"name": "malformed required candlelit outcome",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": _replaced(candlelit_events, "v3_saffron_spool_trial", bad_outcome_rec)},
	})
	var generic_conflict: Array = _source_events()
	generic_conflict.append((candlelit_by_id["v3_bellglass_night_market"] as Dictionary).duplicate(true))
	cases.append({
		"name": "cross-catalog conflict between generic and promoted candlelit ID",
		"g": {"events": generic_conflict},
		"r": roadside_doc,
		"c": candlelit_doc,
	})
	var roadside_conflict: Array = roadside_events.duplicate(true)
	roadside_conflict.append((candlelit_by_id["v3_crowlace_ticket_booth"] as Dictionary).duplicate(true))
	cases.append({
		"name": "cross-catalog conflict between roadside and promoted candlelit ID",
		"g": generic_doc,
		"r": {"events": roadside_conflict},
		"c": candlelit_doc,
	})
	var candlelit_generic_conflict: Array = candlelit_events.duplicate(true)
	candlelit_generic_conflict.append(_record_copy("button_trail"))
	cases.append({
		"name": "cross-catalog conflict with generic ID inside candlelit catalog",
		"g": generic_doc,
		"r": roadside_doc,
		"c": {"events": candlelit_generic_conflict},
	})
	var rng := RandomNumberGenerator.new()
	rng.seed = 404040
	for entry in cases:
		var state_before := rng.state
		var merged: Variant = RunM04EventRotation._combine_shipped_catalogs(entry["g"], entry["r"], entry["c"])
		_check(merged == null, "shipping merge rejects: " + entry["name"])
		var rotation := RunM04EventRotation.new(merged)
		_check(not rotation.is_catalog_valid(), "failed shipping merge invalidates rotation: " + entry["name"])
		_check(rotation.get_generic_events().is_empty(), "failed shipping merge exposes no events: " + entry["name"])
		_check(rotation.get_generic_event_ids().is_empty(), "failed shipping merge exposes no IDs: " + entry["name"])
		var pick := rotation.select_event(rng)
		_check(pick.get("ok") == false and (pick.get("event") as Dictionary).is_empty(),
			"failed shipping merge refuses selection: " + entry["name"])
		_check(rng.state == state_before, "failed shipping merge consumes no RNG: " + entry["name"])


## The separate authored candlelit catalog, parsed once per test run and keyed by
## ID.
func _load_candlelit_by_id() -> Dictionary:
	var out: Dictionary = {}
	var file := FileAccess.open(CANDLELIT_EVENTS_PATH, FileAccess.READ)
	_check(file != null, "v3_candlelit_bargains.json opens as the canonical promoted source")
	if file == null:
		return out
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK, "v3_candlelit_bargains.json parses as the canonical promoted source")
	if parsed != OK or not parser.data is Dictionary:
		return out
	var events: Variant = (parser.data as Dictionary).get("events")
	_check(events is Array, "v3_candlelit_bargains.json carries its events array")
	if not events is Array:
		return out
	for record in events:
		if not record is Dictionary:
			continue
		var raw_id: Variant = (record as Dictionary).get("id")
		if raw_id is String and not out.has(raw_id):
			out[raw_id] = (record as Dictionary).duplicate(true)
	return out


func _load_catalog_events(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + " opens for catalog fixture")
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK, path + " parses for catalog fixture")
	if parsed != OK or not parser.data is Dictionary:
		return []
	var events: Variant = (parser.data as Dictionary).get("events")
	_check(events is Array, path + " carries an events array for catalog fixture")
	if not events is Array:
		return []
	return (events as Array).duplicate(true)


## Deterministic seed per new event id for forced selections.
func _event_seed(event_id: String) -> int:
	match event_id:
		"lantern_moth_clearing": return 1001
		"patchwork_ferry": return 1002
		"spool_clocktower": return 1003
		"ragpicker_cart": return 1004
		"quilt_bridge": return 1005
		"button_moon_festival": return 1006
		_: return 9999


func _force_selection(rotation: RunM04EventRotation, target_id: String, seed_value: int) -> Dictionary:
	var excluded: Array = rotation.get_generic_event_ids()
	excluded.erase(target_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result := rotation.select_event(rng, excluded)
	_check(result.get("ok") == true, "a forced selection succeeds for " + target_id)
	var event: Dictionary = result.get("event", {})
	_check(event.get("id") == target_id, "the forced selection returns " + target_id)
	return event


func _source_events() -> Array:
	return (source_document.get("events") as Array).duplicate(true)


## Every event the default selector ships: the generic M04 catalog, the
## standalone roadside pack, and the six remaining promoted candlelit bargains.
## A fixture that must mirror the shipping merge (for example the reversed-order
## ordering check) uses this instead of the generic catalog alone.
func _combined_events() -> Array:
	var events: Array = _source_events()
	events.append_array(_load_catalog_events(ROADSIDE_EVENTS_PATH))
	var candlelit_by_id: Dictionary = _load_candlelit_by_id()
	for promoted_id in PROMOTED_CANDLELIT_IDS:
		if candlelit_by_id.has(promoted_id):
			events.append((candlelit_by_id[promoted_id] as Dictionary).duplicate(true))
	return events


## The authored record for a default-pool ID, from whichever shipped catalog
## carries it: the generic M04 document or the standalone roadside pack. A
## default selection may serve either source, so detached-record checks must
## not assume the generic catalog alone.
func _shipped_record(event_id: String) -> Dictionary:
	for record in _combined_events():
		if record is Dictionary and record.get("id") == event_id:
			return record
	return {}


func _without(events: Array, drop_id: String) -> Array:
	var kept: Array = []
	for record in events:
		if record is Dictionary and record.get("id") == drop_id:
			continue
		kept.append(record)
	return kept


func _replaced(events: Array, target_id: String, replacement: Variant) -> Array:
	var out: Array = []
	for record in events:
		if record is Dictionary and record.get("id") == target_id:
			out.append(replacement)
		else:
			out.append(record)
	return out


func _record_copy(event_id: String) -> Dictionary:
	return (source_by_id[event_id] as Dictionary).duplicate(true)


func _future_event() -> Dictionary:
	return {
		"id": "future_lantern",
		"title": "The Future Lantern",
		"description": "A lantern waits for a later release.",
		"choices": [
			{"id": "look", "text": "Look inside (+1 scrap)", "outcome": {"gold": 0, "scraps": 1}},
			{"id": "pass", "text": "Pass by", "outcome": {"gold": 0, "scraps": 0}},
		],
	}


## The authored signed amount as an int, or null when the JSON value is not a
## finite whole number. JSON may deliver whole numbers as floats.
func _signed_amount(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number and absf(number) <= 9007199254740992.0:
			return int(number)
	return null


func _matches(listing: Array, event_id: String) -> Array:
	var found: Array = []
	for record in listing:
		if record is Dictionary and record.get("id") == event_id:
			found.append(record)
	return found


func _preview_map(preview: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return out
	for entry in entries:
		if entry is Dictionary:
			out[entry["choice_id"]] = entry
	return out


func _selection_shape_ok(result: Dictionary) -> bool:
	return (
		result.size() == 2
		and result.has("ok")
		and result.get("ok") is bool
		and result.has("event")
		and result.get("event") is Dictionary
	)
