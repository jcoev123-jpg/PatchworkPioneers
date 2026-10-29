extends SceneTree
## Deterministic headless coverage for the four V3-4 gothic night-road wallet
## stories appended to the shipped roadside pack
## (res://data/events/v3_roadside_events.json): the Blackwater Singing Well, the
## Nightglass Firefly Hutch, the Silver Snail Clocktower and the Inkcap Mushroom
## School.
##
## EXPECTED is an independent copy of the authored stories and their signed
## gold/scraps outcomes; it never reads the production catalog or the selector
## back as its oracle. Only per-ID membership is asserted: no catalog total, no
## full ordered ID list and no fixed-seed arbitrary pick, so peer batches can
## land in the same catalog without clashing.
##
## Coverage: one sourced record and one fresh default-selector record per new ID
## with verbatim title/description/choice text and exact signed deltas; the named
## earlier roadside anchors stay eligible while quiet_spool stays special; funded
## previews and receipts agree from {gold: 100, scraps: 10}; every signed debit is
## refused one currency unit short and at an empty purse without consuming the
## visit, after which the same visit still settles its free Leave; a settled
## choice cannot be replayed; caller wallets, the sourced document and an
## unrelated seeded RNG are never mutated; and every new event is forced through
## the real seeded generic selector with exactly one range draw.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const SPECIAL_ID := "quiet_spool"

## Independent copy of the four authored records and their signed wallet outcomes.
const EXPECTED := {
	"v3_blackwater_singing_well": {
		"title": "The Blackwater Singing Well",
		"description": "A round button-eyed frog sings inside a velvet-lined wishing well; tarnished brass wishes shimmer on its stitches.",
		"choices": [
			{"id": "polish_wish_buttons", "text": "Polish the well's lost wish-buttons (gain 13 gold)", "gold": 13, "scraps": 0},
			{"id": "buy_rainproof_seam", "text": "Buy rainproof well-thread (spend 17 gold; gain 3 scraps)", "gold": -17, "scraps": 3},
			{"id": "leave_well", "text": "Leave the frog to its song (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_nightglass_firefly_hutch": {
		"title": "The Nightglass Firefly Hutch",
		"description": "A plump plum-velvet mothkeeper opens a glass hutch of lantern-bright button fireflies beneath a stitched cobalt sky.",
		"choices": [
			{"id": "repair_hutch_net", "text": "Reweave the fireflies' torn net (spend 2 scraps; gain 31 gold)", "gold": 31, "scraps": -2},
			{"id": "collect_glowing_trim", "text": "Gather loose glowing trim (gain 1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave_hutch", "text": "Shut the hutch quietly (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_silver_snail_clocktower": {
		"title": "The Silver Snail Clocktower",
		"description": "A squat clockwork snail carries a moonlit clock on its quilted shell, winding it with silver spool antennae.",
		"choices": [
			{"id": "buy_clockthread", "text": "Buy clockthread for the road (spend 19 gold; gain 3 scraps)", "gold": -19, "scraps": 3},
			{"id": "trade_spare_gears", "text": "Trade a spare spool-gear (spend 1 scrap; gain 22 gold)", "gold": 22, "scraps": -1},
			{"id": "let_clock_tick", "text": "Leave the slow clock ticking (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_inkcap_mushroom_school": {
		"title": "The Inkcap Mushroom School",
		"description": "Button-eyed mushroom pupils practise needlework under a damask leaf canopy while their round teacher rings a thimble bell.",
		"choices": [
			{"id": "teach_needlework", "text": "Teach the pupils a safe stitch (gain 17 gold)", "gold": 17, "scraps": 0},
			{"id": "donate_inkproof_patches", "text": "Donate inkproof patches (spend 2 scraps; gain 37 gold)", "gold": 37, "scraps": -2},
			{"id": "leave_school", "text": "Leave the thimble classroom (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

## Independent per-ID seeds for the forced single-eligible selection replay. They
## never pin a selected position: with one eligible ID the outcome is that ID.
const SEEDS := {
	"v3_blackwater_singing_well": 94001,
	"v3_nightglass_firefly_hutch": 94002,
	"v3_silver_snail_clocktower": 94003,
	"v3_inkcap_mushroom_school": 94004,
}

## Earlier roadside IDs this additive batch must leave in the authored source and
## eligible in the generic rotation, named here independently of the production
## selector constants.
const SOURCE_ANCHOR_IDS := [
	"v3_raincoat_bridge",
	"v3_lullaby_button_fountain",
]
const ELIGIBLE_ANCHOR_IDS := [
	"v3_raincoat_bridge",
	"v3_lullaby_button_fountain",
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
	_test_forced_seeded_selection()
	_check(source_document == source_snapshot, "the roadside source is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_gothic_nightroad_wallet_events_test: ",
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
	_check(int(source_counts.get(SPECIAL_ID, 0)) == 0,
		"quiet_spool is not authored into the roadside pack")


## A fresh default RunM04EventRotation lists every new record exactly once with
## the authored content, keeps every earlier roadside record eligible and still
## keeps quiet_spool out of the generic rotation.
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
	_check(_matches(listing, SPECIAL_ID).is_empty() and not ids.has(SPECIAL_ID),
		"quiet_spool is never in the generic rotation")
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
## choice cannot be replayed or replaced by another choice; results and inputs
## stay detached and an unrelated seeded RNG is untouched.
func _test_wallet_contract() -> void:
	var rotation := RunM04EventRotation.new()
	var listing_snapshot: Array = rotation.get_generic_events()
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 636363
	var guard_state := rng_guard.state
	var funded := {"gold": 100, "scraps": 10}
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
			var after := {"gold": 100 + gold_delta, "scraps": 10 + scraps_delta}
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


## Each signed debit is unaffordable one currency unit short and at an empty
## purse; the refusal keeps the visit open, changes no wallet or record, and the
## same visit still settles its free Leave exactly once.
func _test_insufficient_wallets() -> void:
	var rotation := RunM04EventRotation.new()
	var listing: Array = rotation.get_generic_events()
	var short_refusals := 0
	var empty_refusals := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1, "the selector serves " + event_id + " for short-purse play")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var record_snapshot: Dictionary = record.duplicate(true)
		var free_def := _free_choice(contract, event_id)
		_check(not free_def.is_empty(), "one free Leave per event: " + event_id)
		var free_id := ""
		if not free_def.is_empty():
			free_id = free_def["id"]
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var gold_delta: int = definition["gold"]
			var scraps_delta: int = definition["scraps"]
			if gold_delta >= 0 and scraps_delta >= 0:
				continue
			var short_wallet := {"gold": 100, "scraps": 10}
			var short_currency := ""
			if gold_delta < 0:
				short_wallet["gold"] = -gold_delta - 1
				short_currency = "gold"
			else:
				short_wallet["scraps"] = -scraps_delta - 1
				short_currency = "scraps"
			var short_snapshot: Dictionary = short_wallet.duplicate(true)
			var scarce := RunEventChoice.new(record)
			var rows := _preview_map(scarce.preview_wallet_choices(short_wallet))
			_check(rows.get(choice_id, {}).get("affordable") == false,
				"a one-unit-short " + short_currency + " debit is unaffordable: " + event_id + " / " + choice_id)
			var denied := scarce.choose_with_wallet(choice_id, short_wallet)
			_check(denied == {"ok": false, "event_id": "", "choice_id": "", "wallet": short_wallet},
				"a one-unit-short debit is refused unchanged: " + event_id + " / " + choice_id)
			_check(not is_same(denied.get("wallet"), short_wallet),
				"a refusal returns a detached purse: " + event_id + " / " + choice_id)
			_check(not scarce.is_claimed() and scarce.is_valid(),
				"a refused debit keeps the visit open: " + event_id + " / " + choice_id)
			_check(short_wallet == short_snapshot and record == record_snapshot,
				"a refused debit mutates no purse and no record: " + event_id + " / " + choice_id)
			short_refusals += 1
			if free_id != "":
				var free_receipt := scarce.choose_with_wallet(free_id, short_wallet)
				_check(free_receipt == {
					"ok": true, "event_id": event_id, "choice_id": free_id, "wallet": short_wallet,
				}, "the same visit still settles its free Leave: " + event_id + " / " + choice_id)
				_check(not scarce.is_valid()
					and scarce.choose_with_wallet(free_id, short_wallet).get("ok") == false,
					"the free Leave claim is single: " + event_id + " / " + choice_id)
		var zero := {"gold": 0, "scraps": 0}
		var zero_snapshot: Dictionary = zero.duplicate(true)
		var empty_service := RunEventChoice.new(record)
		var empty_rows := _preview_map(empty_service.preview_wallet_choices(zero))
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			if int(definition["gold"]) >= 0 and int(definition["scraps"]) >= 0:
				continue
			var choice_id: String = definition["id"]
			_check(empty_rows.get(choice_id, {}).get("affordable") == false,
				"an empty purse cannot afford a debit: " + event_id + " / " + choice_id)
			var refused := empty_service.choose_with_wallet(choice_id, zero)
			_check(refused.get("ok") == false and refused.get("wallet") == zero,
				"an empty purse refuses a debit unchanged: " + event_id + " / " + choice_id)
			_check(empty_service.is_valid() and not empty_service.is_claimed(),
				"an empty-purse refusal keeps the visit open: " + event_id + " / " + choice_id)
			empty_refusals += 1
		_check(zero == zero_snapshot,
			"an empty purse is never mutated: " + event_id)
		if free_id != "":
			var empty_free := empty_service.choose_with_wallet(free_id, zero)
			_check(empty_free == {
				"ok": true, "event_id": event_id, "choice_id": free_id, "wallet": zero,
			}, "an empty purse still settles its free Leave: " + event_id)
			_check(not empty_service.is_valid()
				and empty_service.choose_with_wallet(free_id, zero).get("ok") == false,
				"the empty-purse Leave cannot be replayed: " + event_id)
		_check(record == record_snapshot,
			"no short-purse flow mutates the record: " + event_id)
	_check(short_refusals == 5, "every signed debit is refused one unit short")
	_check(empty_refusals == 5, "every signed debit is refused at an empty purse")


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
	# An exhausted pool rejects without a draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 747474
	var guard_state: int = guard.state
	var none_result := rotation.select_event(guard, ids)
	_check(none_result.get("ok") == false and (none_result.get("event") as Dictionary).is_empty(),
		"excluding every eligible event rejects with no event")
	_check(guard.state == guard_state, "an exhausted pool consumes no RNG")


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
