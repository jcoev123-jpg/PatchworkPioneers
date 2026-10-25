extends SceneTree
## Deterministic headless coverage for the six V3-4 gothic ragdoll wallet-story
## Events appended to the shipped generic M04 catalog.
##
## The expected contract below is an independent copy of the authored stories and
## their signed gold/scraps outcomes; it never reads the production catalog or the
## selector back as its oracle. Only per-ID membership is asserted: no catalog
## total, no full ordered ID list and no fixed-seed result, so peer batches can
## land in the same catalog without clashing.
##
## Coverage: one sourced record and one fresh default-selector record per new ID
## with verbatim title/description/choice text and exact signed deltas; named
## earlier anchors stay eligible while quiet_spool stays special; funded previews
## and receipts agree; signed debits are refused at an empty purse without
## consuming the visit, after which the same visit still settles its free Leave;
## a settled choice cannot be replayed; caller wallets, the sourced document and
## an unrelated seeded RNG are never mutated; and every event can be forced
## through the real seeded selector with exactly one range draw.

const EVENTS_PATH := "res://data/events/m04_events.json"
const SPECIAL_ID := "quiet_spool"

## Independent copy of the six authored records and their signed wallet outcomes.
const EXPECTED := {
	"v3_stitched_fog_carousel": {
		"title": "The Stitched Fog Carousel",
		"description": "Button-eyed hobbyhorses circle a silent quilt carousel while amber lanterns disappear into the fog.",
		"choices": [
			{"id": "collect_brass_tickets", "text": "Collect the dropped brass tickets (+11 gold)", "gold": 11, "scraps": 0},
			{"id": "buy_spare_stitching", "text": "Pay 13 gold for two bundles of carousel stitching (+2 scraps)", "gold": -13, "scraps": 2},
			{"id": "watch_horses", "text": "Watch the horses disappear (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_rust_bell_laundry": {
		"title": "The Rust-Bell Laundry",
		"description": "Tiny ragdoll washerfolk hang oxblood coats under a rusted bell that tolls whenever the wind changes.",
		"choices": [
			{"id": "gather_wash_lint", "text": "Gather clean discarded fabric (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "rehem_work_smocks", "text": "Re-hem the work smocks (spend 2 scraps; gain 29 gold)", "gold": 29, "scraps": -2},
			{"id": "keep_dry", "text": "Keep to the dry road (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_inky_needle_orchard": {
		"title": "The Inky Needle Orchard",
		"description": "A grove of midnight-blue pincushion trees bears blunt silver needles instead of fruit.",
		"choices": [
			{"id": "gather_needles", "text": "Gather loose needle stems (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "pay_orchard_keeper", "text": "Pay the orchard keeper 16 gold for three thread spools (+3 scraps)", "gold": -16, "scraps": 3},
			{"id": "pass_trees", "text": "Pass between the silent trees (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_silver_spool_circus": {
		"title": "The Silver-Spool Circus",
		"description": "A lantern-lit puppet circus unfurls its silver-thread tent across the moonlit road.",
		"choices": [
			{"id": "rig_shadow_curtain", "text": "Rig the shadow curtain (spend 1 scrap; earn 21 gold)", "gold": 21, "scraps": -1},
			{"id": "buy_sewn_seats", "text": "Buy a stitched seat ribbon (spend 10 gold; gain 1 scrap)", "gold": -10, "scraps": 1},
			{"id": "skip_performance", "text": "Skip the midnight performance (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_thorned_pocket_library": {
		"title": "The Thorned Pocket Library",
		"description": "A rolling bookcase with button wheels carries tiny stitched books beneath a crown of woollen briars.",
		"choices": [
			{"id": "bind_torn_volumes", "text": "Rebind the torn volumes (spend 2 scraps; earn 30 gold)", "gold": 30, "scraps": -2},
			{"id": "salvage_bookmark", "text": "Collect a loose embroidered bookmark (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave_books", "text": "Leave the books undisturbed (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_amber_hem_undertaker": {
		"title": "The Amber-Hem Undertaker",
		"description": "A gentle button-eyed doll tends lanterns beside a ceremonial velvet quilt, carefully stitching its frayed edge.",
		"choices": [
			{"id": "repair_velvet_hem", "text": "Repair the velvet hem (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
			{"id": "buy_lantern_wick", "text": "Buy two spare lantern wicks (spend 15 gold; gain 2 scraps)", "gold": -15, "scraps": 2},
			{"id": "offer_respect", "text": "Offer a respectful bow (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

## Independent per-ID seeds for the forced single-eligible selection replay. They
## never pin a selected position: with one eligible ID the outcome is that ID.
const SEEDS := {
	"v3_stitched_fog_carousel": 91001,
	"v3_rust_bell_laundry": 91002,
	"v3_inky_needle_orchard": 91003,
	"v3_silver_spool_circus": 91004,
	"v3_thorned_pocket_library": 91005,
	"v3_amber_hem_undertaker": 91006,
}

## Earlier generic IDs this additive batch must leave eligible, named here
## independently of the production selector constants.
const EARLIER_ANCHOR_IDS := [
	"button_trail",
	"loose_seam",
	"thimble_well",
	"frayed_signpost",
	"needle_gate",
	"quilting_bee",
	"estate_sale",
	"v3_ghostlight_playhouse",
	"v3_stone_button_forge",
	"v3_lost_thimble_ball",
]

## One shipped roadside-pack ID the default merge must keep eligible even though
## it lives in the separate roadside source rather than the M04 catalog.
const ROADSIDE_ANCHOR_ID := "v3_raincoat_bridge"

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
	_test_forced_seeded_selection()
	_check(source_document == source_snapshot, "the sourced catalog is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_gothic_story_wallet_events_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
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
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK, "m04_events.json parses through JSON")
	if parsed != OK:
		return
	_check(parser.data is Dictionary, "the M04 catalog is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the M04 catalog carries an events array")
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
		var service := RunEventChoice.new(source_by_id[event_id])
		_check(service.is_valid() and not service.is_claimed(),
			"a fresh sourced selector validates: " + event_id)
	_check(int(source_counts.get(SPECIAL_ID, 0)) == 1,
		"the special quiet_spool record stays in the source catalog")


## A fresh default RunM04EventRotation lists every new record exactly once with
## the authored content, keeps the named earlier anchors eligible and still keeps
## quiet_spool out of the generic rotation.
func _test_default_selector_membership() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped catalog validates in the default selector")
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
	_check(_matches(listing, SPECIAL_ID).is_empty() and not ids.has(SPECIAL_ID),
		"quiet_spool is never in the generic rotation")
	for anchor_id in EARLIER_ANCHOR_IDS:
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"an earlier authored record stays exactly once in the source: " + anchor_id)
		_check(ids.count(anchor_id) == 1,
			"an earlier generic ID stays eligible exactly once: " + anchor_id)
	_check(ids.count(ROADSIDE_ANCHOR_ID) == 1,
		"the merged roadside pack stays eligible: " + ROADSIDE_ANCHOR_ID)
	# The listing stays detached: mutating it never reaches the selector.
	var snapshot: Array = listing.duplicate(true)
	var first: Dictionary = listing[0]
	first["title"] = "MUTATED"
	first["choices"] = []
	listing.append({"id": "injected", "title": "Injected", "description": "Injected", "choices": []})
	_check(rotation.get_generic_events() == snapshot,
		"mutating a returned listing never reaches the selector")


## Funded previews and receipts agree on all eighteen authored deltas; each signed
## debit is refused at an empty purse without consuming the visit and the same
## visit then settles its free Leave; a settled choice cannot be replayed.
func _test_wallet_contract() -> void:
	var rotation := RunM04EventRotation.new()
	var listing_snapshot: Array = rotation.get_generic_events()
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 515151
	var guard_state := rng_guard.state
	var funded := {"gold": 100, "scraps": 10}
	var funded_snapshot: Dictionary = funded.duplicate(true)
	var zero := {"gold": 0, "scraps": 0}
	var zero_snapshot: Dictionary = zero.duplicate(true)
	var settlements := 0
	var refusals := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches := _matches(listing_snapshot, event_id)
		_check(matches.size() == 1, "the default selector serves " + event_id + " for wallet play")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var record_snapshot: Dictionary = record.duplicate(true)
		var free_def := _free_choice(contract, event_id)
		_check(not free_def.is_empty(), "each event keeps one free Leave choice: " + event_id)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var gold_delta: int = definition["gold"]
			var scraps_delta: int = definition["scraps"]
			var after := {"gold": 100 + gold_delta, "scraps": 10 + scraps_delta}
			var paid := gold_delta < 0 or scraps_delta < 0
			# Funded preview and settlement from the record the real selector serves.
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
			# Results and inputs stay detached from each other.
			var receipt_wallet: Dictionary = receipt["wallet"]
			_check(not is_same(receipt_wallet, funded),
				"a committed wallet is a detached copy: " + event_id + " / " + choice_id)
			receipt_wallet["gold"] += 999
			_check(funded == funded_snapshot,
				"a committed wallet never mutates the caller: " + event_id + " / " + choice_id)
			# An empty purse: every signed debit is refused without consuming the
			# visit, and the same visit still settles its free Leave.
			var scarce := RunEventChoice.new(record)
			var scarce_rows := _preview_map(scarce.preview_wallet_choices(zero))
			_check(scarce_rows.get(choice_id, {}).get("affordable") == (not paid),
				"zero-purse affordability matches the signed outcome: " + event_id + " / " + choice_id)
			if paid:
				var denied := scarce.choose_with_wallet(choice_id, zero)
				_check(denied == {
					"ok": false, "event_id": "", "choice_id": "", "wallet": zero,
				}, "a signed debit is refused at an empty purse: " + event_id + " / " + choice_id)
				refusals += 1
				_check(not scarce.is_claimed() and scarce.is_valid(),
					"a refused debit keeps the visit open: " + event_id + " / " + choice_id)
				if not free_def.is_empty():
					var free_id: String = free_def["id"]
					var free_receipt := scarce.choose_with_wallet(free_id, zero)
					_check(free_receipt == {
						"ok": true, "event_id": event_id, "choice_id": free_id, "wallet": zero,
					}, "the same visit still settles its free Leave: " + event_id + " / " + choice_id)
					_check(scarce.is_claimed() and not scarce.is_valid(),
						"the free Leave consumes the visit: " + event_id + " / " + choice_id)
					_check(scarce.choose_with_wallet(free_id, zero).get("ok") == false,
						"the free Leave claim is single: " + event_id + " / " + choice_id)
			else:
				var granted := scarce.choose_with_wallet(choice_id, zero)
				_check(granted == {
					"ok": true, "event_id": event_id, "choice_id": choice_id,
					"wallet": {"gold": gold_delta, "scraps": scraps_delta},
				}, "a nonnegative choice settles at an empty purse: " + event_id + " / " + choice_id)
				_check(scarce.is_claimed()
					and scarce.choose_with_wallet(choice_id, zero).get("ok") == false,
					"the empty-purse claim cannot be replayed: " + event_id + " / " + choice_id)
			_check(zero == zero_snapshot and record == record_snapshot,
				"a purse and its record are never mutated: " + event_id + " / " + choice_id)
	# A non-vacuous table: six events, eighteen authored choices.
	_check(EXPECTED.size() == 6, "the independent table covers six new events")
	_check(settlements == 18, "every authored choice settles once when funded")
	_check(refusals == 8, "every signed debit is refused at an empty purse")
	_check(rotation.get_generic_events() == listing_snapshot,
		"wallet flows never mutate the selector listing")
	_check(rng_guard.state == guard_state,
		"previews and claims never touch an unrelated seeded RNG")


## Every new event is selectable through the real default selector by a seeded
## caller that excludes the other currently eligible IDs, with exactly the
## documented one-draw contract and a detached authored record.
func _test_forced_seeded_selection() -> void:
	var rotation := RunM04EventRotation.new()
	var ids: Array = rotation.get_generic_event_ids()
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
		# JSON may deliver whole numbers as floats; the authored contract is a
		# whole signed amount either way.
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
