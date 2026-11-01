extends SceneTree
## Deterministic headless coverage for the four V3-4 midnight prop-led roadside
## wallet bargains appended to the shipped roadside pack
## (res://data/events/v3_roadside_events.json): the Ironboot Badger cobbler,
## the Midnight Seahorse lockgate, the Fireglass Salamander and the Moonkite
## Hare crossroads.
##
## EXPECTED is an independent copy of the authored stories and their signed
## gold/scraps outcomes; it never reads the production catalog or the selector
## back as its oracle. Only per-ID membership is asserted: no catalog total, no
## full ordered ID list and no fixed-seed arbitrary pick, so peer batches can
## land in the same catalog without clashing.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"

const EXPECTED := {
	"v3_ironboot_badger_cobbler": {
		"title": "The Ironboot Badger",
		"description": "A barrel-shaped oxblood badger doll punches an enormous copper awl through a velvet boot bigger than its body; two mismatched button eyes gleam in lanternlight.",
		"choices": [
			{"id": "sell_boot_hems", "text": "Sell two scrap bundles of boot hems (spend 2 scraps; gain 32 gold)", "gold": 32, "scraps": -2},
			{"id": "buy_spare_awls", "text": "Buy spare copper awls (spend 15 gold; gain 3 scraps)", "gold": -15, "scraps": 3},
			{"id": "leave", "text": "Leave the cobbler to its hammering", "gold": 0, "scraps": 0},
		],
	},
	"v3_midnight_seahorse_lockgate": {
		"title": "The Midnight Seahorse Lockgate",
		"description": "A plump midnight-teal seahorse puppet winds its corkscrew tail around an oversized brass canal key; an amber lantern glows inside the quilted lock gate.",
		"choices": [
			{"id": "wind_rusty_gate", "text": "Turn the old gate wheel (spend 1 scrap; gain 23 gold)", "gold": 23, "scraps": -1},
			{"id": "buy_key_thread", "text": "Buy new key-thread (spend 20 gold; gain 4 scraps)", "gold": -20, "scraps": 4},
			{"id": "leave", "text": "Leave the gate to the tide", "gold": 0, "scraps": 0},
		],
	},
	"v3_fireglass_salamander": {
		"title": "The Fireglass Salamander",
		"description": "A round moss-cloth salamander with stitched-X eyes puffs a glowing amber glass button into a thimble mould; its oversized bellows flap like quilted wings.",
		"choices": [
			{"id": "sell_cooling_glass", "text": "Sell cooled button glass (spend 3 scraps; gain 39 gold)", "gold": 39, "scraps": -3},
			{"id": "buy_fine_filament", "text": "Buy fireglass filament (spend 18 gold; gain 3 scraps)", "gold": -18, "scraps": 3},
			{"id": "leave", "text": "Let the bellows cool", "gold": 0, "scraps": 0},
		],
	},
	"v3_moonkite_hare_crossroads": {
		"title": "The Moonkite Hare",
		"description": "A squat bone-cream hare ragdoll braces an enormous plum-gingham kite against the wind; four brass-button tails tap on the moonlit crossroads.",
		"choices": [
			{"id": "repair_kite_tails", "text": "Repair the four kite tails (spend 2 scraps; gain 29 gold)", "gold": 29, "scraps": -2},
			{"id": "buy_windproof_seams", "text": "Buy windproof kite seams (spend 16 gold; gain 3 scraps)", "gold": -16, "scraps": 3},
			{"id": "leave", "text": "Wave goodbye to the moonkite", "gold": 0, "scraps": 0},
		],
	},
}

## Independent per-ID seeds for the forced single-eligible selection replays.
const SEEDS := {
	"v3_ironboot_badger_cobbler": 4160001,
	"v3_midnight_seahorse_lockgate": 4160002,
	"v3_fireglass_salamander": 4160003,
	"v3_moonkite_hare_crossroads": 4160004,
}

## Earlier roadside IDs this additive batch must leave in the authored source and
## eligible in the generic rotation, named independently of the selector.
const SOURCE_ANCHOR_IDS := [
	"v3_raincoat_bridge",
	"v3_inkcap_mushroom_school",
	"v3_amber_mole_tunnel",
	"v3_teacup_clockwork_procession",
]
const ELIGIBLE_ANCHOR_IDS := [
	"v3_raincoat_bridge",
	"v3_inkcap_mushroom_school",
	"v3_amber_mole_tunnel",
	"v3_teacup_clockwork_procession",
	"button_trail",
]

var failures: Array[String] = []
var checks := 0
var source_document: Dictionary = {}
var source_snapshot: Dictionary = {}
var source_by_id: Dictionary = {}
var source_counts: Dictionary = {}

func _initialize() -> void:
	_load_source()
	if source_document.is_empty():
		_report()
		return
	_test_source_records()
	_test_default_selector_membership()
	_test_wallet_contract()
	_test_insufficient_wallets()
	_test_wrong_choice_ids()
	_test_forced_seeded_selection()
	_check(source_document == source_snapshot, "the roadside source is unchanged by every flow")
	_report()

func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_midnight_prop_bargains_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _load_source() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "v3_roadside_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK, "v3_roadside_events.json parses through JSON")
	if parsed != OK:
		return
	_check(parser.data is Dictionary, "the roadside catalog is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the roadside catalog carries an events array")
	if not events is Array:
		source_document = {}
		return
	for record in events:
		if not record is Dictionary:
			continue
		var event_id: Variant = (record as Dictionary).get("id")
		if not event_id is String:
			continue
		source_counts[event_id] = int(source_counts.get(event_id, 0)) + 1
		if not source_by_id.has(event_id):
			source_by_id[event_id] = record
	source_snapshot = source_document.duplicate(true)

## Each new record exists exactly once in the authored source with its verbatim
## story, exactly three uniquely identified choices, one free Leave and the exact
## signed wallet deltas.
func _test_source_records() -> void:
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		_check(int(source_counts.get(event_id, 0)) == 1,
			"exactly one sourced record for " + event_id)
		if not source_by_id.has(event_id):
			continue
		_check_record_contract(source_by_id[event_id], event_id, contract, "source")
		var free_def := _free_choice(contract, event_id)
		_check(not free_def.is_empty(), "each sourced event keeps one free Leave: " + event_id)
		var service := RunEventChoice.new(source_by_id[event_id])
		_check(service.is_valid() and not service.is_claimed(),
			"a fresh sourced selector validates: " + event_id)
	for anchor_id in SOURCE_ANCHOR_IDS:
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"the named earlier roadside anchor stays in the source once: " + anchor_id)

## A fresh default RunM04EventRotation lists every new record exactly once with
## the authored content and keeps earlier roadside records eligible.
func _test_default_selector_membership() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped catalogs validate in the default selector")
	if not rotation.is_catalog_valid():
		return
	var listing: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	_check(not listing.is_empty(), "the default selector lists a non-empty generic pool")
	for event_id in EXPECTED:
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "exactly one default generic record for " + event_id)
		_check(ids.count(event_id) == 1, "the generic ID listing carries " + event_id + " exactly once")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record == source_by_id[event_id], "the selector copies the authored record: " + event_id)
		_check_record_contract(record, event_id, EXPECTED[event_id], "default selector")
	for anchor_id in ELIGIBLE_ANCHOR_IDS:
		_check(ids.count(anchor_id) == 1,
			"the named earlier anchor stays eligible: " + anchor_id)
	# The listing stays detached: mutating it never reaches the selector.
	var snapshot: Array = listing.duplicate(true)
	var first: Dictionary = listing[0]
	first["title"] = "MUTATED"
	first["choices"] = []
	listing.append({"id": "injected", "title": "Injected", "description": "Injected", "choices": []})
	_check(rotation.get_generic_events() == snapshot,
		"mutating a returned listing never reaches the selector")

## Funded previews and receipts agree on all twelve authored deltas; a settled
## choice cannot be replayed; results and inputs stay detached and an unrelated
## seeded RNG is untouched.
func _test_wallet_contract() -> void:
	var rotation := RunM04EventRotation.new()
	var listing_snapshot: Array = rotation.get_generic_events()
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 636363
	var guard_state := rng_guard.state
	var funded := {"gold": 70, "scraps": 10}
	var funded_snapshot: Dictionary = funded.duplicate(true)
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches := _matches(listing_snapshot, event_id)
		_check(matches.size() == 1, "the default selector serves " + event_id + " for wallet play")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var record_snapshot: Dictionary = record.duplicate(true)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var gold_delta: int = definition["gold"]
			var scraps_delta: int = definition["scraps"]
			var after := {"gold": 70 + gold_delta, "scraps": 10 + scraps_delta}
			var service := RunEventChoice.new(record)
			var preview := service.preview_wallet_choices(funded)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview succeeds: " + event_id + " / " + choice_id)
			var rows := _preview_map(preview)
			var row: Dictionary = rows.get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var receipt := service.choose_with_wallet(choice_id, funded)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": after,
			}, "the claim applies the authored deltas once: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay := service.choose_with_wallet(choice_id, funded)
			_check(replay == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": funded,
			}, "the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			var alternate_id := _other_choice_id(contract, choice_id)
			_check(service.choose_with_wallet(alternate_id, funded).get("ok") == false,
				"no alternate choice claims a spent visit: " + event_id + " / " + choice_id)
			_check(service.preview_wallet_choices(funded).get("ok") == false,
				"a spent visit offers no further preview: " + event_id + " / " + choice_id)
			var receipt_wallet: Dictionary = receipt["wallet"]
			_check(not is_same(receipt_wallet, funded),
				"a committed wallet is a detached copy: " + event_id + " / " + choice_id)
			receipt_wallet["gold"] += 999
			_check(funded == funded_snapshot,
				"a committed wallet never mutates the caller: " + event_id + " / " + choice_id)
			_check(record == record_snapshot and funded == funded_snapshot,
				"a funded flow never mutates the record or its purse: " + event_id + " / " + choice_id)
	_check(EXPECTED.size() == 4, "the independent table covers four new events")
	_check(settlements == 12, "every authored choice settles once when funded")
	_check(rotation.get_generic_events() == listing_snapshot,
		"wallet flows never mutate the selector listing")
	_check(rng_guard.state == guard_state,
		"previews and claims never touch an unrelated seeded RNG")

## Each signed debit is unaffordable at an empty purse; the refusal keeps the
## visit open and the same visit still settles its free Leave exactly once.
func _test_insufficient_wallets() -> void:
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var listing_snapshot: Array = listing.duplicate(true)
	var empty_refusals := 0
	var leave_settlements := 0
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 929292
	var guard_state: int = rng_guard.state
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "the selector serves " + event_id + " for empty-purse play")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var record_snapshot: Dictionary = record.duplicate(true)
		var free_def := _free_choice(contract, event_id)
		_check(not free_def.is_empty(), "one free Leave per event: " + event_id)
		if free_def.is_empty():
			continue
		var free_id: String = free_def["id"]
		var zero := {"gold": 0, "scraps": 0}
		var zero_snapshot: Dictionary = zero.duplicate(true)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			if definition["id"] == free_id:
				continue
			var choice_id: String = definition["id"]
			var service := RunEventChoice.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"each paid refusal uses a fresh unclaimed visit: " + event_id + " / " + choice_id)
			var preview := service.preview_wallet_choices(zero)
			var empty_rows := _preview_map(preview)
			var paid_row: Dictionary = empty_rows.get(choice_id, {})
			var leave_row: Dictionary = empty_rows.get(free_id, {})
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"the empty-purse preview is valid: " + event_id + " / " + choice_id)
			_check(paid_row.get("gold_delta") == definition["gold"]
				and paid_row.get("scraps_delta") == definition["scraps"],
				"the empty-purse preview retains signed paid deltas: " + event_id + " / " + choice_id)
			_check(paid_row.get("affordable") == false and paid_row.get("wallet") == zero,
				"an empty purse cannot afford a debit: " + event_id + " / " + choice_id)
			_check(leave_row.get("affordable") == true
				and leave_row.get("gold_delta") == 0 and leave_row.get("scraps_delta") == 0
				and leave_row.get("wallet") == zero,
				"the same fresh visit advertises a free Leave: " + event_id + " / " + choice_id)
			var refused := service.choose_with_wallet(choice_id, zero)
			_check(refused == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": zero,
			}, "an empty purse refuses a debit unchanged: " + event_id + " / " + choice_id)
			_check(not is_same(refused.get("wallet"), zero),
				"an empty-purse refusal returns a detached purse: " + event_id + " / " + choice_id)
			_check(service.is_valid() and not service.is_claimed(),
				"an empty-purse refusal keeps its visit open: " + event_id + " / " + choice_id)
			empty_refusals += 1
			var empty_free := service.choose_with_wallet(free_id, zero)
			_check(empty_free == {
				"ok": true, "event_id": event_id, "choice_id": free_id, "wallet": zero,
			}, "the same unfunded visit still settles Leave: " + event_id + " / " + choice_id)
			_check(service.is_claimed() and not service.is_valid(),
				"Leave closes its visit once: " + event_id + " / " + choice_id)
			_check(service.choose_with_wallet(free_id, zero) == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": zero,
			} and service.choose_with_wallet(choice_id, zero).get("ok") == false,
				"the spent Leave refuses replay and a paid alternative: " + event_id + " / " + choice_id)
			leave_settlements += 1
		_check(zero == zero_snapshot, "an empty purse is never mutated: " + event_id)
		_check(record == record_snapshot,
			"no empty-purse flow mutates the record: " + event_id)
	_check(empty_refusals == 8, "each of eight paid branches refuses on its own visit")
	_check(leave_settlements == 8, "each of eight refused visits still settles Leave")
	_check(listing == listing_snapshot and rotation.get_generic_events() == listing_snapshot,
		"empty-purse flows never mutate the selector records")
	_check(rng_guard.state == guard_state,
		"empty-purse flows do not consume unrelated seeded RNG")

## Bogus choice IDs refuse on a fresh visit without spending it or the purse.
func _test_wrong_choice_ids() -> void:
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var funded := {"gold": 70, "scraps": 10}
	for event_id in EXPECTED:
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "the selector serves " + event_id + " for bogus-ID play")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var record_snapshot: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var refused := service.choose_with_wallet("bogus_choice", funded)
		_check(refused.get("ok") == false and refused.get("wallet") == funded,
			"a bogus choice ID is refused unchanged: " + event_id)
		_check(not service.is_claimed() and service.is_valid(),
			"a bogus choice ID keeps the visit open: " + event_id)
		_check(record == record_snapshot, "a bogus choice ID mutates no record: " + event_id)

## Every new event is selectable through the real default selector by a seeded
## caller that excludes the other currently eligible IDs, with exactly the
## documented one-draw contract and a detached authored record. Both the plain
## and the actionable selection paths are covered.
func _test_forced_seeded_selection() -> void:
	var rotation := RunM04EventRotation.new()
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() > EXPECTED.size(),
		"the eligible pool holds more than this batch, so exclusions are meaningful")
	var funded := {"gold": 70, "scraps": 10}
	var budget := {"gold": 0, "scraps": 0}
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1, "the eligible pool carries " + event_id + " once")
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id) and excluded.size() == ids.size() - 1,
			"only " + event_id + " stays eligible")
		var seed_value: int = SEEDS[event_id]
		# Plain selection path.
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "forced selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "forced selection returns " + event_id)
		_check(selected == source_by_id[event_id],
			"the selection is the authentic authored record: " + event_id)
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"identical seed and exclusions replay " + event_id)
		var snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == snapshot and detached.get("event") == source_by_id[event_id],
			"the selected " + event_id + " is a detached authored copy")
		# Actionable selection path with a funded wallet.
		var act_rng := RandomNumberGenerator.new()
		act_rng.seed = seed_value
		var act_oracle := RandomNumberGenerator.new()
		act_oracle.seed = seed_value
		act_oracle.randi_range(0, 0)
		var act_picked := rotation.select_actionable_event(act_rng, excluded, funded)
		_check(act_picked.get("ok") == true, "forced actionable selection succeeds: " + event_id)
		_check(act_picked.get("event") == source_by_id[event_id],
			"the actionable selection is the authentic authored record: " + event_id)
		_check(act_rng.state == act_oracle.state,
			"forced actionable selection consumes exactly one range draw: " + event_id)
		var act_replay_rng := RandomNumberGenerator.new()
		act_replay_rng.seed = seed_value
		var act_replay := rotation.select_actionable_event(act_replay_rng, excluded, funded)
		_check(act_replay.get("event") == source_by_id[event_id]
			and act_replay_rng.state == act_rng.state,
			"identical seed and exclusions replay actionable " + event_id)
		var act_record: Dictionary = act_picked.get("event", {})
		var act_snapshot: Dictionary = act_record.duplicate(true)
		act_record["title"] = "MUTATED"
		act_record["choices"] = []
		var act_detached_rng := RandomNumberGenerator.new()
		act_detached_rng.seed = seed_value
		var act_detached := rotation.select_actionable_event(act_detached_rng, excluded, funded)
		_check(act_detached.get("ok") == true
			and act_detached.get("event") == act_snapshot
			and act_detached.get("event") == source_by_id[event_id],
			"actionable selection returns a detached authored record: " + event_id)
		# With an empty purse a fully excluded pool still fails closed with no draw.
		var broke_rng := RandomNumberGenerator.new()
		broke_rng.seed = seed_value
		var broke_state: int = broke_rng.state
		var broke := rotation.select_actionable_event(broke_rng, ids, budget)
		_check(broke.get("ok") == false and (broke.get("event") as Dictionary).is_empty(),
			"an empty purse never makes " + event_id + " actionable")
		_check(broke_rng.state == broke_state,
			"an unfunded actionable rejection consumes no RNG: " + event_id)
	# An exhausted plain pool rejects without a draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 747474
	var guard_state: int = guard.state
	var none_result := rotation.select_event(guard, ids)
	_check(none_result.get("ok") == false and (none_result.get("event") as Dictionary).is_empty(),
		"excluding every eligible event rejects with no event")
	_check(guard.state == guard_state, "an exhausted pool consumes no RNG")
	# A malformed wallet rejects the actionable path without a draw.
	var bad_wallet_rng := RandomNumberGenerator.new()
	bad_wallet_rng.seed = 848484
	var bad_state: int = bad_wallet_rng.state
	var bad_result := rotation.select_actionable_event(bad_wallet_rng, [], {"gold": 1})
	_check(bad_result.get("ok") == false, "a malformed wallet rejects actionable selection")
	_check(bad_wallet_rng.state == bad_state, "a malformed wallet consumes no RNG")

## Verbatim presentation, choice shape and signed deltas against the independent
## table. `origin` only labels failure messages.
func _check_record_contract(record: Variant, event_id: String, contract: Dictionary,
		origin: String) -> void:
	_check(record is Dictionary, "the " + origin + " record is an object: " + event_id)
	if not record is Dictionary:
		return
	var authored: Dictionary = record
	_check(authored.size() == 4 and authored.has("id") and authored.has("title")
		and authored.has("description") and authored.has("choices"),
		"exactly id/title/description/choices: " + origin + " / " + event_id)
	_check(authored.get("id") == event_id, "authored ID: " + origin + " / " + event_id)
	_check(authored.get("title") == contract["title"], "authored title: " + origin + " / " + event_id)
	_check(authored.get("description") == contract["description"],
		"authored description: " + origin + " / " + event_id)
	var choices: Variant = authored.get("choices")
	_check(choices is Array, "authored choices array: " + origin + " / " + event_id)
	if not choices is Array:
		return
	_check((choices as Array).size() == 3, "exactly three choices: " + origin + " / " + event_id)
	var by_id: Dictionary = {}
	for choice in (choices as Array):
		_check(choice is Dictionary, "every choice is an object: " + origin + " / " + event_id)
		if not choice is Dictionary:
			continue
		var entry: Dictionary = choice
		var choice_id: Variant = entry.get("id")
		_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
			"every choice has a nonblank string ID: " + origin + " / " + event_id)
		if not choice_id is String:
			continue
		_check(not by_id.has(choice_id),
			"choice IDs are distinct: " + origin + " / " + event_id + " / " + str(choice_id))
		by_id[choice_id] = entry
	_check(by_id.size() == 3, "three distinct choice IDs: " + origin + " / " + event_id)
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		var choice_id: String = definition["id"]
		_check(by_id.has(choice_id),
			"authored choice present: " + origin + " / " + event_id + " / " + choice_id)
		if not by_id.has(choice_id):
			continue
		var entry: Dictionary = by_id[choice_id]
		_check(entry.size() == 3 and entry.has("id") and entry.has("text")
			and entry.has("outcome"),
			"exactly id/text/outcome: " + origin + " / " + event_id + " / " + choice_id)
		_check(entry.get("text") == definition["text"],
			"authored choice text: " + origin + " / " + event_id + " / " + choice_id)
		var outcome: Variant = entry.get("outcome")
		_check(outcome is Dictionary,
			"choice outcome is an object: " + origin + " / " + event_id + " / " + choice_id)
		if not outcome is Dictionary:
			continue
		var wallet_outcome: Dictionary = outcome
		_check(wallet_outcome.size() == 2 and wallet_outcome.has("gold")
			and wallet_outcome.has("scraps"),
			"exactly gold/scraps outcome keys: " + origin + " / " + event_id + " / " + choice_id)
		var gold_amount: Variant = _signed_amount(wallet_outcome.get("gold"))
		var scraps_amount: Variant = _signed_amount(wallet_outcome.get("scraps"))
		_check(gold_amount != null and scraps_amount != null,
			"whole-number outcome amounts: " + origin + " / " + event_id + " / " + choice_id)
		_check(gold_amount == definition["gold"] and scraps_amount == definition["scraps"],
			"authored signed outcome: " + origin + " / " + event_id + " / " + choice_id)

func _free_choice(contract: Dictionary, event_id: String) -> Dictionary:
	var free_choices: Array = []
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		if int(definition["gold"]) == 0 and int(definition["scraps"]) == 0:
			free_choices.append(definition)
	_check(free_choices.size() == 1,
		"exactly one zero-cost Leave choice is authored: " + event_id)
	return free_choices[0] if free_choices.size() == 1 else {}

func _other_choice_id(contract: Dictionary, choice_id: String) -> String:
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		if definition["id"] != choice_id:
			return definition["id"]
	return choice_id

## The authored signed amount as an int, or null when the JSON value is not a
## finite whole number.
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
