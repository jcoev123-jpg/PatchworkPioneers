extends SceneTree
## Deterministic headless coverage for the four V3-4 gothic prop-led roadside
## wallet stories appended to res://data/events/v3_roadside_events.json: the
## Umbra Zipper Meteor, the Button-Bun Bakery, the Moth-Needle Weather Vane and
## the Clockwork Teacup Parade.
##
## EXPECTED is an independent test-local table (verbatim story, captions and
## signed gold/scraps deltas); the production catalog is never its own oracle.
## Every check is per ID only: no catalog total, no index, no global ordered-ID
## list, so peer batches can land in the same catalog without clashing.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 100, "scraps": 10}
const UNFUNDED := {"gold": 0, "scraps": 0}

const EXPECTED := {
	"v3_umbra_zipper_meteor": {
		"title": "The Umbra Zipper Meteor",
		"description": "A round soot-purple comet doll drags an enormous silver zipper across the night sky, its bright teeth raining onto the torn velvet road.",
		"choices": [
			{"id": "gather_zipper_teeth", "text": "Gather fallen silver zipper teeth (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "purchase_star_shuttle", "text": "Pay 18 gold for the comet's star-thread shuttle (+3 scraps)", "gold": -18, "scraps": 3},
			{"id": "leave", "text": "Let the comet close the night seam (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_bellows_button_bakery": {
		"title": "The Button-Bun Bakery",
		"description": "A round baker doll with mismatched button eyes pedals giant patchwork bellows, blowing amber light through an oven of knitted button buns.",
		"choices": [
			{"id": "repair_oven_bellows", "text": "Repair the torn oven bellows (spend 2 scraps; gain 29 gold)", "gold": 29, "scraps": -2},
			{"id": "collect_oven_twine", "text": "Collect dropped oven twine (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave", "text": "Leave the button buns warming (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_mothneedle_weather_vane": {
		"title": "The Moth-Needle Weather Vane",
		"description": "An enormous moth-shaped brass vane with sewing-needle antennae creaks above a plum quilt watchhouse, pointing at a shower of silver pins.",
		"choices": [
			{"id": "sew_loose_vane", "text": "Sew down the loose vane (spend 1 scrap; gain 20 gold)", "gold": 20, "scraps": -1},
			{"id": "buy_storm_yarn", "text": "Buy two coils of storm yarn (spend 16 gold; gain 2 scraps)", "gold": -16, "scraps": 2},
			{"id": "leave", "text": "Let the moth vane turn with the wind (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_teacup_clockwork_procession": {
		"title": "The Clockwork Teacup Parade",
		"description": "Three button-eyed teacup automata march on oversized brass-spoon legs, spilling glowing thread from their lids onto a cobbled patchwork path.",
		"choices": [
			{"id": "gather_spilled_thread", "text": "Collect the spilled glowing thread (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "polish_spoon_joints", "text": "Polish the parade's spoon joints (spend 2 scraps; gain 25 gold)", "gold": 25, "scraps": -2},
			{"id": "leave", "text": "Watch the last teacup march away (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

## Independent per-ID seeds for the forced single-eligible selection replay.
const SEEDS := {
	"v3_umbra_zipper_meteor": 1190001,
	"v3_bellows_button_bakery": 1190002,
	"v3_mothneedle_weather_vane": 1190003,
	"v3_teacup_clockwork_procession": 1190004,
}

## Earlier roadside anchors this additive batch must leave authored and eligible.
const SOURCE_ANCHOR_IDS := [
	"v3_raincoat_bridge",
	"v3_amber_mole_tunnel",
	"v3_inkblue_swan_raincloak",
]
const ELIGIBLE_ANCHOR_IDS := [
	"v3_raincoat_bridge",
	"v3_amber_mole_tunnel",
	"v3_inkblue_swan_raincloak",
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
	_test_funded_wallet_contract()
	_test_unfunded_leave_and_unknown_choice()
	_test_forced_seeded_selection()
	_check(source_document == source_snapshot, "the roadside source is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_zipper_bakery_vane_teacup_roadside_test: ",
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
## story, exactly three uniquely identified choices and the exact signed deltas.
func _test_source_records() -> void:
	for event_id in EXPECTED:
		_check(int(source_counts.get(event_id, 0)) == 1,
			"exactly one sourced record for " + event_id)
		if not source_by_id.has(event_id):
			continue
		_check_record_contract(source_by_id[event_id], event_id, EXPECTED[event_id], "source")
		var free_def := _free_choice(EXPECTED[event_id], event_id)
		_check(not free_def.is_empty(), "each sourced event keeps one free Leave: " + event_id)
		var service := RunEventChoice.new(source_by_id[event_id])
		_check(service.is_valid() and not service.is_claimed(),
			"a fresh sourced selector validates: " + event_id)
	for anchor_id in SOURCE_ANCHOR_IDS:
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"the named earlier roadside anchor stays in the source once: " + anchor_id)


## A fresh default RunM04EventRotation lists every new record exactly once with
## the authored content and keeps the named earlier anchors eligible.
func _test_default_selector_membership() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped catalogs validate in the default selector")
	if not rotation.is_catalog_valid():
		return
	var listing: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
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


## Funded previews and receipts agree on all twelve authored deltas; a settled
## choice cannot be replayed; results and inputs stay detached.
func _test_funded_wallet_contract() -> void:
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var listing_snapshot: Array = listing.duplicate(true)
	var funded: Dictionary = FUNDED.duplicate(true)
	var funded_snapshot: Dictionary = funded.duplicate(true)
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 919191
	var guard_state := rng_guard.state
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches := _matches(listing, event_id)
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
			var after := {"gold": 100 + gold_delta, "scraps": 10 + scraps_delta}
			var service := RunEventChoice.new(record)
			var preview := service.preview_wallet_choices(FUNDED)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview succeeds: " + event_id + " / " + choice_id)
			var row: Dictionary = _preview_map(preview).get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var receipt := service.choose_with_wallet(choice_id, FUNDED)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": after,
			}, "the claim applies the authored deltas once: " + event_id + " / " + choice_id)
			settlements += 1
			_check(not is_same(receipt.get("wallet"), FUNDED),
				"a committed wallet is a detached copy: " + event_id + " / " + choice_id)
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay := service.choose_with_wallet(choice_id, FUNDED)
			_check(replay == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": FUNDED,
			}, "the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			_check(service.preview_wallet_choices(FUNDED).get("ok") == false,
				"a spent visit offers no further preview: " + event_id + " / " + choice_id)
			_check(record == record_snapshot,
				"a funded flow never mutates the record: " + event_id + " / " + choice_id)
	_check(EXPECTED.size() == 4, "the independent table covers four new events")
	_check(settlements == 12, "every authored choice settles once when funded")
	_check(funded == funded_snapshot, "a funded flow never mutates the caller wallet")
	_check(rotation.get_generic_events() == listing_snapshot,
		"wallet flows never mutate the selector listing")
	_check(rng_guard.state == guard_state,
		"previews and claims never touch an unrelated seeded RNG")


## An unfunded purse refuses a priced choice without spending the visit; the same
## visit still settles its free Leave exactly once. An unknown choice ID never
## settles. A refused call draws no RNG.
func _test_unfunded_leave_and_unknown_choice() -> void:
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var zero: Dictionary = UNFUNDED.duplicate(true)
	var zero_snapshot: Dictionary = zero.duplicate(true)
	var guard := RandomNumberGenerator.new()
	guard.seed = 515151
	var guard_state := guard.state
	var refusals := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "the selector serves " + event_id + " for unfunded play")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var record_snapshot: Dictionary = record.duplicate(true)
		var free_def := _free_choice(contract, event_id)
		_check(not free_def.is_empty(), "one free Leave per event: " + event_id)
		if free_def.is_empty():
			continue
		var free_id: String = free_def["id"]
		var paid := _first_priced_choice(contract)
		_check(not paid.is_empty(), "each event authors a priced choice: " + event_id)
		if paid.is_empty():
			continue
		var service := RunEventChoice.new(record)
		var unknown := service.choose_with_wallet("bogus_choice", zero)
		_check(unknown.get("ok") == false and unknown.get("wallet") == zero,
			"an unknown choice ID is refused unchanged: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"an unknown choice ID keeps the visit open: " + event_id)
		var paid_id: String = paid["id"]
		var rows := _preview_map(service.preview_wallet_choices(zero))
		_check(rows.get(paid_id, {}).get("affordable") == false,
			"an empty purse cannot afford " + paid_id + ": " + event_id)
		var denied := service.choose_with_wallet(paid_id, zero)
		_check(denied == {"ok": false, "event_id": "", "choice_id": "", "wallet": zero},
			"an unfunded priced choice is refused unchanged: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"an unfunded refusal keeps the visit open: " + event_id)
		refusals += 1
		var free_receipt := service.choose_with_wallet(free_id, zero)
		_check(free_receipt == {
			"ok": true, "event_id": event_id, "choice_id": free_id, "wallet": zero,
		}, "the same visit still settles its free Leave: " + event_id)
		_check(not service.is_valid()
			and service.choose_with_wallet(free_id, zero).get("ok") == false,
			"the free Leave claim is single: " + event_id)
		_check(record == record_snapshot, "an unfunded flow mutates no record: " + event_id)
	_check(refusals == 4, "every event refuses its priced choice at an empty purse")
	_check(zero == zero_snapshot, "an empty purse is never mutated")
	_check(guard.state == guard_state, "refusals never touch an unrelated seeded RNG")


## Every new event is selectable through the real default actionable selector by
## a seeded caller that excludes every other eligible ID, with exactly the
## documented one-draw contract and a detached authored record.
func _test_forced_seeded_selection() -> void:
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var listing_snapshot: Array = listing.duplicate(true)
	var ids: Array = rotation.get_generic_event_ids()
	var funded: Dictionary = FUNDED.duplicate(true)
	var funded_snapshot: Dictionary = funded.duplicate(true)
	_check(ids.size() > EXPECTED.size(),
		"the eligible pool holds more than this batch, so exclusions are meaningful")
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1, "the eligible pool carries " + event_id + " once")
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id) and excluded.size() == ids.size() - 1,
			"only " + event_id + " stays eligible")
		var seed_value: int = SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_actionable_event(rng, excluded, funded)
		_check(picked.get("ok") == true, "forced actionable selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "forced selection returns " + event_id)
		_check(selected == source_by_id[event_id],
			"the selection is the authentic authored record: " + event_id)
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_actionable_event(replay_rng, excluded, funded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"identical seed and exclusions replay " + event_id)
		var snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_actionable_event(detached_rng, excluded, funded)
		_check(detached.get("event") == snapshot and detached.get("event") == source_by_id[event_id],
			"the selected " + event_id + " is a detached authored copy")
	# No-op rejections consume no RNG draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 848484
	var guard_state: int = guard.state
	_check(rotation.select_actionable_event(guard, ids, funded).get("ok") == false,
		"excluding every eligible event rejects with no event")
	_check(guard.state == guard_state, "an exhausted pool consumes no RNG")
	_check(rotation.select_actionable_event(guard, ["v3_umbra_zipper_meteor"],
		{"gold": -1, "scraps": 10}).get("ok") == false,
		"a malformed wallet rejects")
	_check(guard.state == guard_state, "a malformed wallet consumes no RNG")
	_check(listing == listing_snapshot and funded == funded_snapshot,
		"seeded selections never mutate the listing or the caller wallet")


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


func _first_priced_choice(contract: Dictionary) -> Dictionary:
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		if int(definition["gold"]) < 0 or int(definition["scraps"]) < 0:
			return definition
	return {}


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
