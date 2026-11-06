extends SceneTree
## Deterministic headless coverage for the three doll-scale household
## roadside wallet stories appended to the shipped roadside pack
## (res://data/events/v3_roadside_events.json): the Moonlit Darning Egg,
## the Velvet Curtain Pulley and the Inkblack Hatpin Ladder.
##
## EXPECTED, FUNDED_FINAL and ANCHORS are independent copies of the authored
## stories, funded settlement tables and earlier anchors; they never read the
## production catalog or the selector back as their oracle. Only per-ID
## membership is asserted: no catalog total, no full ordered ID list and no
## fixed pool position, so peer batches can land in the same catalog without
## clashing.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const M04_EVENTS_PATH := "res://data/events/m04_events.json"
const FUNDED := {"gold": 50, "scraps": 5}
const SCARCE := {"gold": 0, "scraps": 0}

const EXPECTED := {
	"v3_moonlit_darning_egg": {
		"title": "The Moonlit Darning Egg",
		"description": "A house-sized bone-cream darning egg lies cracked on a black quilt ledge; a tiny button-eyed mender gathers silver thread from its split seam beneath one amber candle.",
		"choices": [
			{"id": "gather_egg_shell_stitches", "text": "Collect stray silver stitches from the cracked egg (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "resew_egg_crack", "text": "Spend 2 scraps sealing the great egg seam (earn 28 gold)", "gold": 28, "scraps": -2},
			{"id": "leave", "text": "Leave the great egg beneath its pale quilt moon", "gold": 0, "scraps": 0},
		],
	},
	"v3_velvet_curtain_pulley": {
		"title": "The Velvet Curtain Pulley",
		"description": "Across a high window ledge, a carriage-wide plum curtain hangs from a groaning brass pulley; a round moth-cloaked doll steadies its stitched rope in wavering candlelight.",
		"choices": [
			{"id": "buy_pulley_braid", "text": "Pay 16 gold for three coils of curtain braid (+3 scraps)", "gold": -16, "scraps": 3},
			{"id": "repair_curtain_guide", "text": "Spend 1 scrap repairing the brass guide (earn 21 gold)", "gold": 21, "scraps": -1},
			{"id": "leave", "text": "Let the heavy curtain fall across the ledge", "gold": 0, "scraps": 0},
		],
	},
	"v3_inkblack_hatpin_ladder": {
		"title": "The Inkblack Hatpin Ladder",
		"description": "Five towering silver hatpins lean against an inkblack wardrobe door; a squat moss-velvet ladder keeper lashes their heads together with oxblood yarn as the candle gutters.",
		"choices": [
			{"id": "salvage_hatpin_caps", "text": "Gather a loose hatpin cap (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "buy_ladder_lashing", "text": "Pay 23 gold for four bundles of ladder lashing (+4 scraps)", "gold": -23, "scraps": 4},
			{"id": "leave", "text": "Leave the hatpin ladder rattling against the wardrobe", "gold": 0, "scraps": 0},
		],
	},
}

## Independent funded {gold: 50, scraps: 5} settlement table: the exact final
## balance each authored choice must reach from a fresh unclaimed visit.
const FUNDED_FINAL := {
	"v3_moonlit_darning_egg": {
		"gather_egg_shell_stitches": {"gold": 50, "scraps": 7},
		"resew_egg_crack": {"gold": 78, "scraps": 3},
		"leave": {"gold": 50, "scraps": 5},
	},
	"v3_velvet_curtain_pulley": {
		"buy_pulley_braid": {"gold": 34, "scraps": 8},
		"repair_curtain_guide": {"gold": 71, "scraps": 4},
		"leave": {"gold": 50, "scraps": 5},
	},
	"v3_inkblack_hatpin_ladder": {
		"salvage_hatpin_caps": {"gold": 50, "scraps": 6},
		"buy_ladder_lashing": {"gold": 27, "scraps": 9},
		"leave": {"gold": 50, "scraps": 5},
	},
}

## Fresh unclaimed visits where a priced option must preview as unaffordable
## and refuse to settle or claim.
const LOW_WALLET_CASES := [
	{"event_id": "v3_moonlit_darning_egg", "choice_id": "resew_egg_crack", "wallet": {"gold": 50, "scraps": 1}},
	{"event_id": "v3_velvet_curtain_pulley", "choice_id": "buy_pulley_braid", "wallet": {"gold": 15, "scraps": 5}},
	{"event_id": "v3_velvet_curtain_pulley", "choice_id": "repair_curtain_guide", "wallet": {"gold": 50, "scraps": 0}},
	{"event_id": "v3_inkblack_hatpin_ladder", "choice_id": "buy_ladder_lashing", "wallet": {"gold": 22, "scraps": 5}},
]

## Independent per-ID seeds for the forced single-eligible injected selection.
const SEEDS := {
	"v3_moonlit_darning_egg": 1204001,
	"v3_velvet_curtain_pulley": 1204002,
	"v3_inkblack_hatpin_ladder": 1204003,
}

## Earlier roadside anchors this additive batch must leave in the authored
## source and eligible in the generic rotation, named independently of the
## selector, with their original titles and signed wallet deltas.
const ANCHORS := {
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"description": "A soaked quilt bridge stretching over a ravine.",
		"choices": {
			"salvage_hems": {"text": "Salvage loose hems (+1 scrap)", "gold": 0, "scraps": 1},
			"trade_fare": {"text": "Trade fare for threads (-12 gold, +2 scraps)", "gold": -12, "scraps": 2},
		},
	},
	"v3_bedpost_thimble_lift": {
		"title": "The Bedpost Thimble Lift",
		"description": "A stout button-eyed liftkeeper hauls a brass thimble up a giant bedpost on crossed red threads; the wooden rungs vanish into candlelit dark.",
		"choices": {
			"gather_pulley_shavings": {"text": "Collect brass pulley shavings (+2 scraps)", "gold": 0, "scraps": 2},
			"oil_lift_pulley": {"text": "Offer 2 scraps to oil the thimble lift (gain 28 gold)", "gold": 28, "scraps": -2},
		},
	},
	"v3_keyhole_ribbon_windmill": {
		"title": "The Keyhole Ribbon Windmill",
		"description": "Behind peeled wallpaper a bone-cream keyhole towers over the dolls; a squat velvet windkeeper turns a ribbon windmill inside the lock.",
		"choices": {
			"gather_ribbon_tails": {"text": "Gather fallen ribbon tails (+1 scrap)", "gold": 0, "scraps": 1},
			"buy_windmill_spools": {"text": "Pay 17 gold for three windmill spools (+3 scraps)", "gold": -17, "scraps": 3},
		},
	},
}

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
	_test_anchor_records()
	_test_default_selector_membership()
	_test_wallet_contract()
	_test_low_wallet_negatives()
	_test_unknown_choices()
	_test_zero_wallet_free_choices()
	_test_injected_seeded_selection()
	_test_zero_wallet_injected_selection()
	_check(source_document == source_snapshot, "the roadside source is unchanged by every flow")
	_report()

func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_darning_egg_curtain_hatpin_roadside_events_test: ",
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
## story, exactly three uniquely identified choices, one free Leave and the
## exact signed wallet deltas.
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

## The named earlier anchors keep exactly one record each with their original
## titles and signed wallet outcomes.
func _test_anchor_records() -> void:
	for anchor_id in ANCHORS:
		var contract: Dictionary = ANCHORS[anchor_id]
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"exactly one sourced record for the anchor " + anchor_id)
		if not source_by_id.has(anchor_id):
			continue
		var record: Dictionary = source_by_id[anchor_id]
		_check(record.get("title") == contract["title"],
			"the anchor keeps its original title: " + anchor_id)
		_check(record.get("description") == contract["description"],
			"the anchor keeps its original description: " + anchor_id)
		var choices: Variant = record.get("choices")
		if not choices is Array:
			_check(false, "the anchor keeps its choices array: " + anchor_id)
			continue
		var by_id := {}
		for choice in choices:
			if choice is Dictionary:
				by_id[(choice as Dictionary).get("id")] = choice
		for choice_id in contract["choices"]:
			_check(by_id.has(choice_id),
				"the anchor keeps its choice " + str(choice_id) + ": " + anchor_id)
			if not by_id.has(choice_id):
				continue
			var outcome: Variant = (by_id[choice_id] as Dictionary).get("outcome")
			var expected_outcome: Dictionary = contract["choices"][choice_id]
			_check((by_id[choice_id] as Dictionary).get("text") == expected_outcome["text"],
				"the anchor keeps its original choice text: " + anchor_id + " / " + str(choice_id))
			_check(outcome is Dictionary
				and (outcome as Dictionary).get("gold") == expected_outcome["gold"]
				and (outcome as Dictionary).get("scraps") == expected_outcome["scraps"],
				"the anchor keeps its original outcome: " + anchor_id + " / " + str(choice_id))

## A fresh default RunM04EventRotation keeps its catalog valid and lists every
## new record and every named anchor exactly once in the generic ID pool.
func _test_default_selector_membership() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped catalogs validate in the default selector")
	if not rotation.is_catalog_valid():
		return
	var ids: Array = rotation.get_generic_event_ids()
	var listing: Array = rotation.get_generic_events()
	_check(not listing.is_empty(), "the default selector lists a non-empty generic pool")
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1,
			"the default generic ID pool carries " + event_id + " exactly once")
		var matches := _matches(listing, event_id)
		_check(matches.size() == 1 and matches[0] == source_by_id[event_id],
			"the default selector serves the verbatim authored record: " + event_id)
	for anchor_id in ANCHORS:
		_check(ids.count(anchor_id) == 1,
			"the named earlier anchor stays eligible: " + anchor_id)

## Funded previews and receipts agree with the independent settlement table on
## all nine authored choices, each on a fresh service with a fresh funded
## purse; a settled claim cannot be replayed and never mutates its inputs.
func _test_wallet_contract() -> void:
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var final_table: Dictionary = FUNDED_FINAL[event_id]
		_check(final_table.size() == 3,
			"the independent funded table covers three choices: " + event_id)
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var purse := FUNDED.duplicate(true)
			var service := RunEventChoice.new(record)
			var preview := service.preview_wallet_choices(purse)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview succeeds: " + event_id + " / " + choice_id)
			var row: Dictionary = _preview_map(preview).get(choice_id, {})
			_check(row.get("affordable") == true,
				"funded preview marks the choice affordable: " + event_id + " / " + choice_id)
			_check(row.get("gold_delta") == definition["gold"]
				and row.get("scraps_delta") == definition["scraps"],
				"funded preview reports the authored deltas: " + event_id + " / " + choice_id)
			var receipt := service.choose_with_wallet(choice_id, purse)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id,
				"wallet": final_table[choice_id],
			}, "the claim settles the independent funded balance: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay := service.choose_with_wallet(choice_id, purse)
			_check(replay.get("ok") == false and replay.get("event_id") == ""
				and replay.get("choice_id") == "" and replay.get("wallet") == purse,
				"the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			_check(purse == FUNDED and record == record_snapshot,
				"a funded flow never mutates the purse or the record: " + event_id + " / " + choice_id)
	_check(EXPECTED.size() == 3, "the independent table covers three new events")
	_check(settlements == 9, "every authored choice settles once when funded")

## A priced option previews as unaffordable on a low wallet and refuses to
## settle, claim or mutate anything.
func _test_low_wallet_negatives() -> void:
	for case in LOW_WALLET_CASES:
		var event_id: String = case["event_id"]
		var choice_id: String = case["choice_id"]
		var purse: Dictionary = (case["wallet"] as Dictionary).duplicate(true)
		var purse_snapshot: Dictionary = purse.duplicate(true)
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var service := RunEventChoice.new(record)
		var preview := service.preview_wallet_choices(purse)
		_check(preview.get("ok") == true,
			"the low-wallet preview still opens: " + event_id + " / " + choice_id)
		var row: Dictionary = _preview_map(preview).get(choice_id, {})
		_check(row.get("affordable") == false,
			"the priced option previews unaffordable: " + event_id + " / " + choice_id)
		var refused := service.choose_with_wallet(choice_id, purse)
		_check(refused.get("ok") == false and refused.get("event_id") == ""
			and refused.get("choice_id") == "",
			"the priced option refuses to settle: " + event_id + " / " + choice_id)
		_check(refused.get("wallet") == purse_snapshot,
			"the refusal returns the unchanged purse: " + event_id + " / " + choice_id)
		_check(not service.is_claimed() and service.is_valid(),
			"the refused priced option keeps the visit open: " + event_id + " / " + choice_id)
		_check(purse == purse_snapshot and record == (source_by_id[event_id] as Dictionary),
			"a refused priced option mutates nothing: " + event_id + " / " + choice_id)

## An unknown choice ID fails without claiming on every new event.
func _test_unknown_choices() -> void:
	for event_id in EXPECTED:
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var service := RunEventChoice.new(record)
		var purse := FUNDED.duplicate(true)
		var forged := service.choose_with_wallet("forged_choice", purse)
		_check(forged.get("ok") == false and forged.get("event_id") == ""
			and forged.get("choice_id") == "" and forged.get("wallet") == purse,
			"an unknown choice ID is refused unchanged: " + event_id)
		_check(not service.is_claimed() and service.is_valid(),
			"an unknown choice ID keeps the visit open: " + event_id)

## From an empty purse the two free gathering gains and every event's Leave
## still settle on separate fresh visits.
func _test_zero_wallet_free_choices() -> void:
	var zero := SCARCE.duplicate(true)
	var cases := [
		{"event_id": "v3_moonlit_darning_egg", "choice_id": "gather_egg_shell_stitches", "wallet": {"gold": 0, "scraps": 2}},
		{"event_id": "v3_inkblack_hatpin_ladder", "choice_id": "salvage_hatpin_caps", "wallet": {"gold": 0, "scraps": 1}},
		{"event_id": "v3_moonlit_darning_egg", "choice_id": "leave", "wallet": {"gold": 0, "scraps": 0}},
		{"event_id": "v3_velvet_curtain_pulley", "choice_id": "leave", "wallet": {"gold": 0, "scraps": 0}},
		{"event_id": "v3_inkblack_hatpin_ladder", "choice_id": "leave", "wallet": {"gold": 0, "scraps": 0}},
	]
	for case in cases:
		var event_id: String = case["event_id"]
		var choice_id: String = case["choice_id"]
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var service := RunEventChoice.new(record)
		var receipt := service.choose_with_wallet(choice_id, zero)
		_check(receipt == {
			"ok": true, "event_id": event_id, "choice_id": choice_id,
			"wallet": case["wallet"],
		}, "the empty purse still settles " + event_id + " / " + choice_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the empty-purse claim latches once: " + event_id + " / " + choice_id)
		_check(zero == SCARCE,
			"an empty-purse settlement never mutates the caller: " + event_id + " / " + choice_id)

## An injected catalog is used exactly as passed. The selector's constructor
## still demands the seven required generic records, so the injected document
## below carries the shipped generic events plus the three canonical new
## records; excluding every other eligible ID (which includes the other two
## new IDs) proves per-entry eligibility of each new tale without any global
## seeded slot, pool total or ordered ID list.
func _injected_document() -> Dictionary:
	var m04 := _read_document(M04_EVENTS_PATH)
	if m04.is_empty():
		return {}
	var events: Array = []
	events.append_array(m04.get("events", []))
	for event_id in EXPECTED:
		events.append((source_by_id[event_id] as Dictionary).duplicate(true))
	return {"events": events}

func _test_injected_seeded_selection() -> void:
	var document := _injected_document()
	if document.is_empty():
		_check(false, "the injected document builds from the shipped generic catalog")
		return
	var document_snapshot: Dictionary = document.duplicate(true)
	for event_id in EXPECTED:
		var rotation := RunM04EventRotation.new(document)
		_check(rotation.is_catalog_valid(), "the injected catalog validates for " + event_id)
		if not rotation.is_catalog_valid():
			continue
		var ids: Array = rotation.get_generic_event_ids()
		_check(ids.count(event_id) == 1, "the injected pool carries " + event_id + " once")
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		for other_id in EXPECTED:
			if other_id != event_id:
				_check(excluded.has(other_id),
					"the injected selection excludes the other new ID " + other_id)
		var excluded_snapshot: Array = excluded.duplicate()
		var wallet := FUNDED.duplicate(true)
		var wallet_snapshot: Dictionary = wallet.duplicate(true)
		var rng := RandomNumberGenerator.new()
		rng.seed = SEEDS[event_id]
		var picked := rotation.select_actionable_event(rng, excluded, wallet)
		_check(picked.get("ok") == true,
			"the funded injected selection succeeds: " + event_id)
		_check(picked.get("event", {}).get("id") == event_id,
			"the funded injected selection chooses " + event_id)
		_check(picked.get("event", {}) == source_by_id[event_id],
			"the injected selection returns the authentic authored record: " + event_id)
		_check(document == document_snapshot,
			"the injected selection leaves the supplied source unchanged: " + event_id)
		_check(excluded == excluded_snapshot,
			"the injected selection leaves the excluded array unchanged: " + event_id)
		_check(wallet == wallet_snapshot,
			"the injected selection never mutates the caller wallet: " + event_id)

## At a zero wallet the darning egg and the hatpin ladder each keep an
## affordable nonzero choice while the all-priced curtain pulley offers only
## its free zero-delta Leave and is therefore not actionable: an injected
## selection that excludes the two free-actionable new tales finds no
## actionable candidate and consumes no seeded RNG.
func _test_zero_wallet_injected_selection() -> void:
	_check(_is_actionable(source_by_id["v3_moonlit_darning_egg"], SCARCE),
		"the darning egg has an affordable nonzero choice at a zero wallet")
	_check(_is_actionable(source_by_id["v3_inkblack_hatpin_ladder"], SCARCE),
		"the hatpin ladder has an affordable nonzero choice at a zero wallet")
	_check(not _is_actionable(source_by_id["v3_velvet_curtain_pulley"], SCARCE),
		"the curtain pulley is not actionable at a zero wallet")
	var document := _injected_document()
	if document.is_empty():
		_check(false, "the zero-wallet injected document builds from the shipped generic catalog")
		return
	var document_snapshot: Dictionary = document.duplicate(true)
	var rotation := RunM04EventRotation.new(document)
	_check(rotation.is_catalog_valid(), "the zero-wallet injected catalog validates")
	if not rotation.is_catalog_valid():
		return
	var ids: Array = rotation.get_generic_event_ids()
	var excluded: Array = ids.duplicate()
	excluded.erase("v3_velvet_curtain_pulley")
	_check(excluded.has("v3_moonlit_darning_egg")
		and excluded.has("v3_inkblack_hatpin_ladder"),
		"the zero-wallet exclusions cover the two free-actionable new events")
	var excluded_snapshot: Array = excluded.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1204099
	var rng_state: int = rng.state
	var picked := rotation.select_actionable_event(rng, excluded, SCARCE)
	_check(picked.get("ok") == false and (picked.get("event") as Dictionary).is_empty(),
		"the zero-wallet injected selection returns no actionable candidate")
	_check(rng.state == rng_state, "the zero-wallet rejection consumes no seeded RNG")
	_check(document == document_snapshot and excluded == excluded_snapshot,
		"the zero-wallet rejection leaves the source and exclusions unchanged")

## True when the record offers at least one affordable nonzero-delta choice
## under wallet, judged only through the authentic preview service.
func _is_actionable(record: Variant, wallet: Dictionary) -> bool:
	if not record is Dictionary:
		return false
	var service := RunEventChoice.new(record)
	if not service.is_valid():
		return false
	var preview := service.preview_wallet_choices(wallet)
	if not preview.get("ok", false):
		return false
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return false
	for entry in entries:
		if not entry is Dictionary:
			continue
		var choice: Dictionary = entry
		if not choice.get("affordable", false):
			continue
		var gold_delta: Variant = choice.get("gold_delta")
		var scraps_delta: Variant = choice.get("scraps_delta")
		if typeof(gold_delta) != TYPE_INT or typeof(scraps_delta) != TYPE_INT:
			continue
		if int(gold_delta) != 0 or int(scraps_delta) != 0:
			return true
	return false

## Verbatim presentation, choice shape and signed deltas against the
## independent table. `origin` only labels failure messages.
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

func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	if not parser.data is Dictionary:
		return {}
	return (parser.data as Dictionary).duplicate(true)
