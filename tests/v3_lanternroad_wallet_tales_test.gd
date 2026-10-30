extends SceneTree
## Deterministic headless test for the four lantern-road wallet tales appended to
## data/events/v3_roadside_events.json by V3-4.
##
## Everything here is independent of the shipped catalog and of the selector's
## constants: the four authored records are restated verbatim (title, description,
## all three choice IDs, captions and signed gold/scraps deltas), every assertion
## is per ID, and no catalog total, full ordered ID list or insertion position is
## asserted. The three named earlier anchors are re-specified independently.
##
## Coverage: shipped-data shape and anchor preservation (AC1); admission into the
## genuine default RunM04EventRotation plus forced one-draw seeded selection,
## replay, deep-copy isolation and fail-closed rejections (AC2); funded preview and
## one-shot claim receipts for all twelve authored branches (AC3); one-unit-short
## refusals on every debited branch, unknown choice IDs and replay without state,
## wallet or RNG mutation (AC4). No RNG is created inside a service call.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"

## Funded purse every claim branch starts from.
const FUNDED := {"gold": 60, "scraps": 6}

const EXPECTED := {
	"v3_lantern_snail_posthouse": {
		"title": "The Lantern Snail Posthouse",
		"description": "A plump moss-felt snail carries a posthouse in its shell, stamping letters with an enormous wax seal beneath a warm thimble lantern.",
		"choices": [
			{"id": "collect_seal_cuttings", "text": "Gather discarded wax-seal thread (gain 2 scraps)", "gold": 0, "scraps": 2},
			{"id": "buy_postal_spools", "text": "Buy three lantern-wick spools (spend 16 gold; gain 3 scraps)", "gold": -16, "scraps": 3},
			{"id": "leave", "text": "Let the snail carry the letters into the fog", "gold": 0, "scraps": 0},
		],
	},
	"v3_velvet_fox_thread_trick": {
		"title": "The Velvet Fox Thread Trick",
		"description": "A broad-faced oxblood fox puppet fans giant gingham cards, its long velvet tail stitched into a magician's sleeve hiding a little coin purse.",
		"choices": [
			{"id": "rethread_trick_cards", "text": "Resew the fox's split card deck (gain 15 gold)", "gold": 15, "scraps": 0},
			{"id": "trade_fox_tassels", "text": "Trade two scrap bundles for the hidden purse (spend 2 scraps; gain 24 gold)", "gold": 24, "scraps": -2},
			{"id": "leave", "text": "Keep your purse closed and watch the fox bow", "gold": 0, "scraps": 0},
		],
	},
	"v3_copper_beetle_pulley_bridge": {
		"title": "The Copper Beetle Pulley Bridge",
		"description": "A squat copper-shelled beetle doll winds a rope bridge with enormous brass-buckle mandibles under a midnight-teal lantern.",
		"choices": [
			{"id": "mend_pulley_rope", "text": "Replace two frayed rope bundles (spend 2 scraps; gain 34 gold)", "gold": 34, "scraps": -2},
			{"id": "buy_buckle_offcuts", "text": "Buy three buckle-thread offcuts (spend 19 gold; gain 3 scraps)", "gold": -19, "scraps": 3},
			{"id": "leave", "text": "Cross when the beetle's pulley falls quiet", "gold": 0, "scraps": 0},
		],
	},
	"v3_inkblue_swan_raincloak": {
		"title": "The Inkblue Swan Raincloak",
		"description": "A round inkblue swan ragdoll shelters travellers under one enormous umbrella-shaped quilt wing as brass-button raindrops tick along the hem.",
		"choices": [
			{"id": "sew_rain_hem", "text": "Sew the swan's leaky rain hem (gain 2 scraps)", "gold": 0, "scraps": 2},
			{"id": "purchase_rain_thread", "text": "Buy four waterproof thread bundles (spend 21 gold; gain 4 scraps)", "gold": -21, "scraps": 4},
			{"id": "leave", "text": "Walk beyond the swan's quilted shadow", "gold": 0, "scraps": 0},
		],
	},
}

const EVENT_IDS := [
	"v3_lantern_snail_posthouse",
	"v3_velvet_fox_thread_trick",
	"v3_copper_beetle_pulley_bridge",
	"v3_inkblue_swan_raincloak",
]

## Independent per-ID seeds for the forced single-eligible selection replay.
const SEEDS := {
	"v3_lantern_snail_posthouse": 1030401,
	"v3_velvet_fox_thread_trick": 1030402,
	"v3_copper_beetle_pulley_bridge": 1030403,
	"v3_inkblue_swan_raincloak": 1030404,
}

## The exact projected purse of every authored branch from FUNDED {60, 6}.
const RECEIPTS := {
	"v3_lantern_snail_posthouse": {
		"collect_seal_cuttings": {"gold": 60, "scraps": 8},
		"buy_postal_spools": {"gold": 44, "scraps": 9},
		"leave": {"gold": 60, "scraps": 6},
	},
	"v3_velvet_fox_thread_trick": {
		"rethread_trick_cards": {"gold": 75, "scraps": 6},
		"trade_fox_tassels": {"gold": 84, "scraps": 4},
		"leave": {"gold": 60, "scraps": 6},
	},
	"v3_copper_beetle_pulley_bridge": {
		"mend_pulley_rope": {"gold": 94, "scraps": 4},
		"buy_buckle_offcuts": {"gold": 41, "scraps": 9},
		"leave": {"gold": 60, "scraps": 6},
	},
	"v3_inkblue_swan_raincloak": {
		"sew_rain_hem": {"gold": 60, "scraps": 8},
		"purchase_rain_thread": {"gold": 39, "scraps": 10},
		"leave": {"gold": 60, "scraps": 6},
	},
}

## Three earlier roadside anchors that must survive this append unchanged. Their
## choice IDs and signed deltas are restated here, independently of the catalog.
const ANCHORS := {
	"v3_raincoat_bridge": {
		"salvage_hems": {"gold": 0, "scraps": 1},
		"trade_fare": {"gold": -12, "scraps": 2},
		"take_detour": {"gold": 0, "scraps": 0},
	},
	"v3_inkblue_otter_ferry": {
		"patch_ferry_sail": {"gold": 31, "scraps": -2},
		"collect_coat_offcuts": {"gold": 0, "scraps": 1},
		"leave_otter_ferry": {"gold": 0, "scraps": 0},
	},
	"v3_brass_buttonbear_stormgate": {
		"oil_spool_crank": {"gold": 22, "scraps": -1},
		"buy_stormproof_hem": {"gold": -21, "scraps": 4},
		"leave_stormgate": {"gold": 0, "scraps": 0},
	},
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var document: Dictionary = _read_document(EVENTS_PATH)
	if not document.is_empty():
		_check_catalog(document)
		_check_rotation_and_selection(document)
		_check_wallet_claims(document)
		_check_underfunded(document)
	if failures.is_empty():
		print("v3_lanternroad_wallet_tales_test: PASS (", checks, " checks)")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("v3_lanternroad_wallet_tales_test: FAIL (", checks, " checks)")
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## AC1: shipped-data shape, verbatim authored text and signed deltas, one free
## "leave" per tale, unique IDs across the additive catalog, and the three named
## earlier anchors intact. No catalog total and no ordered ID list.
func _check_catalog(document: Dictionary) -> void:
	var events: Variant = document.get("events")
	_check(events is Array, "the roadside document carries an events array")
	if not events is Array:
		return
	var by_id: Dictionary = _records_by_id(events)
	var seen: Dictionary = {}
	for record in (events as Array):
		if not record is Dictionary:
			continue
		var raw_id: Variant = (record as Dictionary).get("id")
		if not raw_id is String:
			continue
		var event_id: String = raw_id
		_check(not seen.has(event_id), "roadside event IDs are unique: " + event_id)
		seen[event_id] = true
	for event_id in EVENT_IDS:
		_check(_matches(events, event_id).size() == 1,
			"exactly one sourced record for " + event_id)
		if not by_id.has(event_id):
			continue
		var record: Dictionary = by_id[event_id]
		var contract: Dictionary = EXPECTED[event_id]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"the record carries exactly id/title/description/choices: " + event_id)
		_check(record.get("title") == contract["title"], "authored title: " + event_id)
		_check(record.get("description") == contract["description"],
			"authored description: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array, "authored choices array: " + event_id)
		if not choices is Array:
			continue
		_check((choices as Array).size() == 3, "exactly three choices: " + event_id)
		var by_choice: Dictionary = {}
		for choice in (choices as Array):
			_check(choice is Dictionary, "every choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var entry: Dictionary = choice
			var choice_id: Variant = entry.get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"every choice has a nonblank string ID: " + event_id)
			if not choice_id is String:
				continue
			_check(not by_choice.has(choice_id),
				"choice IDs are distinct: " + event_id + " / " + str(choice_id))
			by_choice[choice_id] = entry
		_check(by_choice.size() == 3, "three distinct choice IDs: " + event_id)
		_check(by_choice.has("leave"), "the free choice ID is leave: " + event_id)
		var free_ids: Array = []
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			_check(by_choice.has(choice_id),
				"authored choice present: " + event_id + " / " + choice_id)
			if not by_choice.has(choice_id):
				continue
			var entry: Dictionary = by_choice[choice_id]
			_check(entry.size() == 3 and entry.has("id") and entry.has("text")
				and entry.has("outcome"),
				"exactly id/text/outcome with no extra mechanics: " + event_id + " / " + choice_id)
			_check(entry.get("text") == definition["text"],
				"authored caption: " + event_id + " / " + choice_id)
			var outcome: Variant = entry.get("outcome")
			_check(outcome is Dictionary, "outcome is an object: " + event_id + " / " + choice_id)
			if not outcome is Dictionary:
				continue
			var wallet_outcome: Dictionary = outcome
			_check(wallet_outcome.size() == 2 and wallet_outcome.has("gold")
				and wallet_outcome.has("scraps"),
				"exactly signed gold/scraps outcome keys: " + event_id + " / " + choice_id)
			var gold_amount: Variant = _signed_whole(wallet_outcome.get("gold"))
			var scraps_amount: Variant = _signed_whole(wallet_outcome.get("scraps"))
			_check(gold_amount != null and scraps_amount != null,
				"whole-number outcome amounts: " + event_id + " / " + choice_id)
			_check(gold_amount == definition["gold"] and scraps_amount == definition["scraps"],
				"authored signed outcome: " + event_id + " / " + choice_id)
			if int(definition["gold"]) == 0 and int(definition["scraps"]) == 0:
				free_ids.append(choice_id)
		_check(free_ids.size() == 1 and free_ids[0] == "leave",
			"the only zero/zero choice is the free leave: " + event_id)
		var service := RunEventChoice.new(record)
		_check(service.is_valid() and not service.is_claimed(),
			"the shipped RunEventChoice accepts the authored record: " + event_id)
	for anchor_id in ANCHORS:
		_check(_matches(events, anchor_id).size() == 1,
			"the earlier anchor stays in the source once: " + anchor_id)
		if not by_id.has(anchor_id):
			continue
		var anchor_choices: Variant = (by_id[anchor_id] as Dictionary).get("choices")
		_check(anchor_choices is Array, "the earlier anchor keeps its choices: " + anchor_id)
		if not anchor_choices is Array:
			continue
		var anchor_ids: Array = []
		for choice in (anchor_choices as Array):
			if not choice is Dictionary:
				continue
			var anchor_choice: Dictionary = choice
			var anchor_choice_id: Variant = anchor_choice.get("id")
			if not anchor_choice_id is String:
				continue
			anchor_ids.append(anchor_choice_id)
			if not ANCHORS[anchor_id].has(anchor_choice_id):
				continue
			var expected_outcome: Dictionary = ANCHORS[anchor_id][anchor_choice_id]
			var outcome: Variant = anchor_choice.get("outcome")
			_check(outcome is Dictionary
				and _signed_whole((outcome as Dictionary).get("gold")) == expected_outcome["gold"]
				and _signed_whole((outcome as Dictionary).get("scraps")) == expected_outcome["scraps"],
				"the earlier anchor keeps its authored deltas: " + anchor_id + " / " + str(anchor_choice_id))
		for anchor_choice_id in ANCHORS[anchor_id]:
			_check(anchor_ids.count(anchor_choice_id) == 1,
				"the earlier anchor keeps its choice ID: " + anchor_id + " / " + anchor_choice_id)


## AC2: the genuine default selector admits each new tale once, serves verbatim
## detached copies, forces each named tale with one seeded range draw, replays and
## rejects exhausted or malformed requests without consuming RNG.
func _check_rotation_and_selection(document: Dictionary) -> void:
	var source_by_id: Dictionary = _records_by_id(_source_events(document))
	var document_snapshot: Dictionary = document.duplicate(true)
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the default selector validates the shipped merge")
	if not rotation.is_catalog_valid():
		return
	var listing_snapshot: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() > EVENT_IDS.size(),
		"the default pool holds more than this batch, so exclusions are meaningful")
	for event_id in EVENT_IDS:
		var source_record: Dictionary = source_by_id.get(event_id, {})
		_check(not source_record.is_empty(), "the source carries the new tale: " + event_id)
		var admitted: Array = _matches(listing_snapshot, event_id)
		_check(admitted.size() == 1 and ids.count(event_id) == 1,
			"the default selector admits the tale exactly once: " + event_id)
		if admitted.size() == 1:
			_check(admitted[0] == source_record,
				"the default selector serves the verbatim authored record: " + event_id)
		var excluded: Array = []
		for other_id in ids:
			if other_id != event_id:
				excluded.append(other_id)
		_check(excluded.size() == ids.size() - 1 and not excluded.has(event_id),
			"only the named tale stays eligible: " + event_id)
		var seed_value: int = SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "the forced selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "the forced selection is the named tale: " + event_id)
		_check(selected == source_record,
			"the forced selection is the authentic authored record: " + event_id)
		_check(rng.state == oracle.state,
			"a forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"the same seed and exclusions replay " + event_id)
		var selected_snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		selected["injected"] = true
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == selected_snapshot
			and detached.get("event") == source_record,
			"the selected record is a detached authored copy: " + event_id)
	# Exhausted and malformed requests reject without an RNG draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 818181
	var guard_state: int = guard.state
	var none_result := rotation.select_event(guard, ids)
	_check(none_result.get("ok") == false
		and (none_result.get("event") as Dictionary).is_empty(),
		"excluding every eligible event rejects with no event")
	_check(guard.state == guard_state, "an exhausted pool consumes no RNG")
	for bad_list in [7, true, "button_trail", {}, [1], [""], ["   "], [null]]:
		var bad_result := rotation.select_event(guard, bad_list)
		_check(bad_result.get("ok") == false
			and (bad_result.get("event") as Dictionary).is_empty(),
			"a malformed exclusion list rejects: " + str(bad_list))
		_check(guard.state == guard_state,
			"a malformed exclusion list consumes no RNG: " + str(bad_list))
		_check(rotation.select_event(bad_list).get("ok") == false,
			"a malformed RNG value rejects: " + str(bad_list))
		_check(guard.state == guard_state,
			"a malformed RNG value consumes no RNG: " + str(bad_list))
	# AC2 actionable selection: at a zero purse the Lantern Snail stays actionable
	# (collect_seal_cuttings costs nothing and grants 2 scraps) while the Copper
	# Beetle is not (both non-Leave branches cost a currency).
	var zero := {"gold": 0, "scraps": 0}
	var snail_excluded: Array = []
	for other_id in ids:
		if other_id != "v3_lantern_snail_posthouse":
			snail_excluded.append(other_id)
	var actionable_rng := RandomNumberGenerator.new()
	actionable_rng.seed = 909090
	var actionable_oracle := RandomNumberGenerator.new()
	actionable_oracle.seed = 909090
	actionable_oracle.randi_range(0, 0)
	var actionable := rotation.select_actionable_event(actionable_rng, snail_excluded, zero)
	_check(actionable.get("ok") == true and actionable.get("event", {}).get("id")
		== "v3_lantern_snail_posthouse",
		"a zero-purse actionable selection still offers the Lantern Snail")
	_check(actionable_rng.state == actionable_oracle.state,
		"an actionable selection consumes exactly one range draw")
	var beetle_excluded: Array = []
	for other_id in ids:
		if other_id != "v3_copper_beetle_pulley_bridge":
			beetle_excluded.append(other_id)
	var beetle_rng := RandomNumberGenerator.new()
	beetle_rng.seed = 909091
	var beetle_state: int = beetle_rng.state
	var beetle_result := rotation.select_actionable_event(beetle_rng, beetle_excluded, zero)
	_check(beetle_result.get("ok") == false
		and (beetle_result.get("event") as Dictionary).is_empty(),
		"a zero purse makes the Copper Beetle non-actionable")
	_check(beetle_rng.state == beetle_state,
		"a forced non-actionable selection consumes no RNG")
	# The non-actionability is the authored prices, checked independently.
	var beetle_record: Dictionary = source_by_id.get("v3_copper_beetle_pulley_bridge", {})
	var beetle_rows: Dictionary = _preview_rows(
		RunEventChoice.new(beetle_record).preview_wallet_choices(zero))
	_check(beetle_rows.get("mend_pulley_rope", {}).get("affordable") == false,
		"the beetle rope mend is unaffordable at a zero purse")
	_check(beetle_rows.get("buy_buckle_offcuts", {}).get("affordable") == false,
		"the beetle buckle purchase is unaffordable at a zero purse")
	_check(rotation.get_generic_events() == listing_snapshot,
		"selection never mutates the selector listing")
	_check(document == document_snapshot,
		"selection never mutates the shipped roadside source")


## AC3: preview and one-shot claim for all twelve authored branches from the
## funded {60, 6} purse, with exact receipts and no caller mutation.
func _check_wallet_claims(document: Dictionary) -> void:
	var source_by_id: Dictionary = _records_by_id(_source_events(document))
	var document_snapshot: Dictionary = document.duplicate(true)
	var rotation := RunM04EventRotation.new()
	var listing_snapshot: Array = rotation.get_generic_events()
	var settlements := 0
	for event_id in EVENT_IDS:
		var record: Dictionary = source_by_id.get(event_id, {})
		if record.is_empty():
			continue
		var record_snapshot: Dictionary = record.duplicate(true)
		var funded: Dictionary = FUNDED.duplicate(true)
		var funded_snapshot: Dictionary = funded.duplicate(true)
		var forecast := RunEventChoice.new(record)
		var preview: Dictionary = forecast.preview_wallet_choices(funded)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"a funded preview succeeds: " + event_id)
		var rows: Dictionary = _preview_rows(preview)
		_check(rows.size() == 3, "a funded preview lists all three choices: " + event_id)
		_check(not forecast.is_claimed(), "a preview never claims the visit: " + event_id)
		for choice_def in EXPECTED[event_id]["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var after: Dictionary = RECEIPTS[event_id][choice_id]
			var row: Dictionary = rows.get(choice_id, {})
			_check(int(row.get("gold_delta", 0)) == int(definition["gold"])
				and int(row.get("scraps_delta", 0)) == int(definition["scraps"]),
				"the preview reports the authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"the preview forecasts the exact funded purse: " + event_id + " / " + choice_id)
			var visit := RunEventChoice.new(record)
			var receipt := visit.choose_with_wallet(choice_id, funded)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": after,
			}, "the funded claim settles the authored deltas once: " + event_id + " / " + choice_id)
			settlements += 1
			_check(visit.is_claimed() and not visit.is_valid(),
				"the funded claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay := visit.choose_with_wallet(choice_id, funded)
			_check(replay == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": funded,
			}, "the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			_check(visit.preview_wallet_choices(funded).get("ok") == false,
				"a spent visit offers no further preview: " + event_id + " / " + choice_id)
		_check(funded == funded_snapshot,
			"the caller's funded purse is unchanged by claim play: " + event_id)
		_check(record == record_snapshot,
			"the authored record is unchanged by claim play: " + event_id)
	_check(settlements == EVENT_IDS.size() * 3,
		"every authored branch settles exactly once when funded")
	_check(rotation.get_generic_events() == listing_snapshot,
		"claim play never mutates the selector listing")
	_check(document == document_snapshot,
		"claim play never mutates the shipped roadside source")


## AC4: every debited branch is refused from a purse one unit short, the visit
## stays open, and a legal alternative still settles. Unknown IDs and replays are
## refused without mutating the wallet, the visit or the run RNG.
func _check_underfunded(document: Dictionary) -> void:
	var source_by_id: Dictionary = _records_by_id(_source_events(document))
	var document_snapshot: Dictionary = document.duplicate(true)
	var cases: Array = [
		{"event": "v3_lantern_snail_posthouse", "choice": "buy_postal_spools",
			"wallet": {"gold": 15, "scraps": 6}},
		{"event": "v3_velvet_fox_thread_trick", "choice": "trade_fox_tassels",
			"wallet": {"gold": 60, "scraps": 1}},
		{"event": "v3_copper_beetle_pulley_bridge", "choice": "mend_pulley_rope",
			"wallet": {"gold": 60, "scraps": 1}},
		{"event": "v3_copper_beetle_pulley_bridge", "choice": "buy_buckle_offcuts",
			"wallet": {"gold": 18, "scraps": 6}},
		{"event": "v3_inkblue_swan_raincloak", "choice": "purchase_rain_thread",
			"wallet": {"gold": 20, "scraps": 6}},
	]
	var guard := RandomNumberGenerator.new()
	guard.seed = 727272
	var guard_state: int = guard.state
	var refusals := 0
	for entry in cases:
		var case: Dictionary = entry
		var event_id: String = case["event"]
		var choice_id: String = case["choice"]
		var record: Dictionary = source_by_id.get(event_id, {})
		if record.is_empty():
			continue
		var record_snapshot: Dictionary = record.duplicate(true)
		var scarce: Dictionary = (case["wallet"] as Dictionary).duplicate(true)
		var scarce_snapshot: Dictionary = scarce.duplicate(true)
		var visit := RunEventChoice.new(record)
		var rows: Dictionary = _preview_rows(visit.preview_wallet_choices(scarce))
		_check(rows.get(choice_id, {}).get("affordable") == false,
			"a one-unit-short purse marks the debit unaffordable: " + event_id + " / " + choice_id)
		_check(rows.get(choice_id, {}).get("wallet") == scarce,
			"an unaffordable preview keeps the unchanged purse: " + event_id + " / " + choice_id)
		var denied := visit.choose_with_wallet(choice_id, scarce)
		_check(denied == {
			"ok": false, "event_id": "", "choice_id": "", "wallet": scarce,
		}, "the short debit is refused with an unchanged purse: " + event_id + " / " + choice_id)
		refusals += 1
		_check(not visit.is_claimed() and visit.is_valid(),
			"the refused debit leaves the visit open: " + event_id + " / " + choice_id)
		_check(guard.state == guard_state,
			"a refused debit never touches the run RNG: " + event_id + " / " + choice_id)
		var unknown := visit.choose_with_wallet("v3_unknown_lanternroad_choice", scarce)
		_check(unknown == {"ok": false, "event_id": "", "choice_id": "", "wallet": scarce},
			"an unknown choice ID is refused: " + event_id)
		_check(not visit.is_claimed() and visit.is_valid(),
			"an unknown choice leaves the visit open: " + event_id)
		var leave := visit.choose_with_wallet("leave", scarce)
		_check(leave == {
			"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": scarce,
		}, "the same visit still settles its free leave: " + event_id)
		_check(visit.is_claimed() and not visit.is_valid(),
			"the free leave consumes the visit: " + event_id)
		var leave_replay := visit.choose_with_wallet("leave", scarce)
		_check(leave_replay == {
			"ok": false, "event_id": "", "choice_id": "", "wallet": scarce,
		}, "the settled free leave cannot be replayed: " + event_id)
		var after_claim := visit.choose_with_wallet(choice_id, FUNDED)
		_check(after_claim.get("ok") == false and after_claim.get("wallet") == FUNDED,
			"no debit claims a spent visit: " + event_id + " / " + choice_id)
		_check(scarce == scarce_snapshot,
			"the short purse is unchanged by refusals and the leave: " + event_id)
		_check(record == record_snapshot,
			"the authored record is unchanged by the short visit: " + event_id)
		_check(guard.state == guard_state,
			"short previews, refusals and leaves never touch the run RNG: " + event_id)
	_check(refusals == cases.size(), "every debited branch is refused one unit short")
	_check(document == document_snapshot,
		"short-purse visits never mutate the shipped roadside source")


func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + " opens through FileAccess")
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, path + " parses through JSON")
	if parse_result != OK:
		return {}
	var data: Variant = parser.data
	_check(data is Dictionary, path + " parses to a document object")
	if not data is Dictionary:
		return {}
	return data


func _source_events(document: Dictionary) -> Array:
	var events: Variant = document.get("events")
	if not events is Array:
		return []
	return (events as Array).duplicate(true)


func _records_by_id(events: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for record in events:
		if not record is Dictionary:
			continue
		var raw_id: Variant = record.get("id")
		if not raw_id is String or (raw_id as String).strip_edges().is_empty():
			continue
		if by_id.has(raw_id):
			continue
		by_id[raw_id] = record
	return by_id


func _matches(events: Array, event_id: String) -> Array:
	var found: Array = []
	for record in events:
		if record is Dictionary and record.get("id") == event_id:
			found.append(record)
	return found


func _preview_rows(preview: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return out
	for entry in entries:
		if entry is Dictionary:
			out[entry["choice_id"]] = entry
	return out


func _signed_whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number and absf(number) <= 9007199254740992.0:
			return int(number)
	return null
