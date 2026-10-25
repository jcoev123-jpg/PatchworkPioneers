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

const EVENTS_PATH := "res://data/events/m04_events.json"

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
	var source_record: Dictionary = source_by_id[expected_id]
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
	var reversed_events: Array = (source_document.get("events") as Array).duplicate(true)
	reversed_events.reverse()
	var reversed_rotation := RunM04EventRotation.new({"events": reversed_events})
	_check(reversed_rotation.is_catalog_valid(), "a reverse-ordered catalog fixture still validates")
	_check(reversed_rotation.get_generic_event_ids() == shipped.get_generic_event_ids(),
		"both JSON orderings expose the same sorted eligible IDs")
	for seed_value in [7, 99, 424242, 1000003]:
		var first_rng := RandomNumberGenerator.new()
		first_rng.seed = seed_value
		var second_rng := RandomNumberGenerator.new()
		second_rng.seed = seed_value
		var first := shipped.select_event(first_rng)
		var second := reversed_rotation.select_event(second_rng)
		_check(first.get("ok") == true and second.get("ok") == true,
			"both JSON orderings select with seed %d" % seed_value)
		_check(first.get("event", {}).get("id") == second.get("event", {}).get("id"),
			"JSON order is not a hidden random input (seed %d)" % seed_value)
		_check(first_rng.state == second_rng.state,
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
