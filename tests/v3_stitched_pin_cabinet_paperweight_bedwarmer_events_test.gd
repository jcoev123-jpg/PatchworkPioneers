extends SceneTree
## Deterministic headless coverage for the three candle-and-fray doll-house
## roadside bargains appended to the native Stitched route-effect catalog
## (res://data/events/stitched_route_effects.json): the Glassfront Pin
## Cabinet, the Moonblack Paperweight and the Cinder-Brass Bedwarmer.
##
## EXPECTED, FUNDED_FINAL, UNDERFUNDED and ZERO_PURSE_FREE are independent
## hardcoded copies of the authored stories and the funded settlement
## oracle; they never read the production catalog or the consequence service
## back as their oracle. Only per-ID membership is asserted on the catalog: no
## catalog total, no full ordered ID list and no fixed pool position, so peer
## batches can land in the same catalog without clashing. Every preview row
## and receipt is compared against an exact hardcoded dictionary, which also
## proves the ABSENCE of the optional gold/scraps keys on choices that do not
## carry them. No RNG is seeded or drawn anywhere in this test.

const EVENTS_PATH := "res://data/events/stitched_route_effects.json"
const BASE_CANDLE := 40
const BASE_GOLD := 60
const BASE_SCRAPS := 4
const PARTY_FRAYS := [["warden", 40], ["seamstress", 60], ["tinker", 20], ["lantern_monk", 10]]

## Independent literal copies of the three authored stories, including the
## exact signed stitched_effect fields.
const EXPECTED := {
	"v3_glassfront_pin_cabinet": {
		"title": "The Glassfront Pin Cabinet",
		"description": "A giant glass-front sewing cabinet looms above the doll-sized passage; behind warped panes a plump button-eyed keeper sorts copper pins into black velvet drawers.",
		"choices": [
			{"id": "salvage_loose_pinheads", "text": "Open a draughty pin tray (+3 scraps, -8 candle, +4 fray each)", "effect": {"target": "party", "candle": -8, "fray": 4, "scraps": 3, "require_full_candle": true}},
			{"id": "brace_wick_with_pins", "text": "Spend 2 scraps bracing the candle wick (+15 candle, -4 fray each)", "effect": {"target": "party", "candle": 15, "fray": -4, "scraps": -2, "require_full_candle_gain": true}},
			{"id": "leave", "text": "Let the cabinet's velvet drawers close", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_moonblack_paperweight": {
		"title": "The Moonblack Paperweight",
		"description": "A moonblack glass paperweight pins a torn house plan to the floorboards; a small cream-felt mapkeeper waits beneath its cold reflection, holding an ink-stained spool.",
		"choices": [
			{"id": "buy_quiet_house_plan", "text": "Pay 16 gold for a reassuring house plan (-10 fray each)", "effect": {"target": "party", "candle": 0, "fray": -10, "gold": -16, "min_fray": 1}},
			{"id": "lift_shadowed_map", "text": "Lift the shadowed weight (+23 gold, -10 candle, +7 fray each)", "effect": {"target": "party", "candle": -10, "fray": 7, "gold": 23, "require_full_candle": true}},
			{"id": "leave", "text": "Leave the black glass holding down the plan", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_cinder_brass_bedwarmer": {
		"title": "The Cinder-Brass Bedwarmer",
		"description": "A bedwarmer the size of a wagon glows behind a perforated brass lid; a soot-dark round ragdoll steadies its long wooden handle beside a threadbare carpet.",
		"choices": [
			{"id": "rent_ember_lid", "text": "When the candle gutters, borrow embers; gain light but fray the dolls", "effect": {"target": "party", "candle": 22, "fray": 5, "gold": -11, "require_candle_room": true, "required_candle_bands": ["snuffed", "dark", "gloom"]}},
			{"id": "sift_cooling_ashes", "text": "Sift cooling ashes for scraps; dim the candle and ease fray", "effect": {"target": "party", "candle": -12, "fray": -6, "scraps": 2, "require_full_candle": true}},
			{"id": "leave", "text": "Leave the bedwarmer glowing in the dark", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
}

## Independent funded oracle from the snapshot {candle 40, gold 60, scraps 4,
## satchel_count 0, frays warden 40 / seamstress 60 / tinker 20 /
## lantern_monk 10}: the exact projected candle, the raw per-hero fray delta
## and the exact settled purse per choice, each row also carrying its own
## hardcoded authored deltas for an internal consistency check.
const FUNDED_FINAL := {
	"v3_glassfront_pin_cabinet": {
		"salvage_loose_pinheads": {"candle": 32, "candle_delta": -8, "fray": 4, "scraps": 7, "scraps_delta": 3},
		"brace_wick_with_pins": {"candle": 55, "candle_delta": 15, "fray": -4, "scraps": 2, "scraps_delta": -2},
		"leave": {"candle": 40, "candle_delta": 0, "fray": 0},
	},
	"v3_moonblack_paperweight": {
		"buy_quiet_house_plan": {"candle": 40, "candle_delta": 0, "fray": -10, "gold": 44, "gold_delta": -16},
		"lift_shadowed_map": {"candle": 30, "candle_delta": -10, "fray": 7, "gold": 83, "gold_delta": 23},
		"leave": {"candle": 40, "candle_delta": 0, "fray": 0},
	},
	"v3_cinder_brass_bedwarmer": {
		"rent_ember_lid": {"candle": 62, "candle_delta": 22, "fray": 5, "gold": 49, "gold_delta": -11},
		"sift_cooling_ashes": {"candle": 28, "candle_delta": -12, "fray": -6, "scraps": 6, "scraps_delta": 2},
		"leave": {"candle": 40, "candle_delta": 0, "fray": 0},
	},
}

## One unit short of each paid price: the funded snapshot's other fields are
## kept, only the paying purse is short, and the free path plus Leave stay
## selectable on the very same visit.
const UNDERFUNDED := {
	"v3_glassfront_pin_cabinet": {
		"choice_id": "brace_wick_with_pins", "gold": 60, "scraps": 1,
		"balance_key": "scraps", "balance": 1, "free_id": "salvage_loose_pinheads",
	},
	"v3_moonblack_paperweight": {
		"choice_id": "buy_quiet_house_plan", "gold": 15, "scraps": 4,
		"balance_key": "gold", "balance": 15, "free_id": "lift_shadowed_map",
	},
	"v3_cinder_brass_bedwarmer": {
		"choice_id": "rent_ember_lid", "gold": 10, "scraps": 4,
		"balance_key": "gold", "balance": 10, "free_id": "sift_cooling_ashes",
	},
}

## A zero purse can still claim one nonzero free path per story.
const ZERO_PURSE_FREE := {
	"v3_glassfront_pin_cabinet": {
		"choice_id": "salvage_loose_pinheads", "candle": 32, "fray": 4,
		"extra": {"scraps_delta": 3, "scraps": 3},
	},
	"v3_moonblack_paperweight": {
		"choice_id": "lift_shadowed_map", "candle": 30, "fray": 7,
		"extra": {"gold_delta": 23, "gold": 23},
	},
	"v3_cinder_brass_bedwarmer": {
		"choice_id": "sift_cooling_ashes", "candle": 28, "fray": -6,
		"extra": {"scraps_delta": 2, "scraps": 2},
	},
}

## Earlier anchors that must remain in the catalog with their original titles.
const ANCHOR_TITLES := {
	"moth_infestation": "Moth Infestation",
	"dye_vat": "The Dye Vat",
	"frayed_debt_parcel": "Frayed Debt Parcel",
	"needle_toll": "The Needle Toll",
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
	_test_funded_contract()
	_test_underfunded_visits()
	_test_zero_purse_free_claims()
	_test_unknown_choice_refusals()
	_test_stale_effect_fails()
	_test_full_candle_bedwarmer()
	_test_full_candle_pin_cabinet()
	_test_pin_cabinet_partial_gain_refusals()
	_test_negative_candle_boundaries()
	_check(source_document == source_snapshot, "the catalog document is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_pin_cabinet_paperweight_bedwarmer_events_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_source() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "stitched_route_effects.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parsed: int = parser.parse(text)
	_check(parsed == OK, "stitched_route_effects.json parses through JSON")
	if parsed != OK:
		return
	_check(parser.data is Dictionary, "the route-effect catalog is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the route-effect catalog carries an events array")
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


## Each new record exists exactly once with only the native Event envelope,
## its verbatim story, exactly three distinct choices carrying only
## id/text/stitched_effect, and the exact signed effects.
func _test_source_records() -> void:
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		_check(int(source_counts.get(event_id, 0)) == 1,
			"exactly one authored record for " + event_id)
		if not source_by_id.has(event_id):
			continue
		var record: Dictionary = source_by_id[event_id]
		_check(record.keys().size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"the new record uses only the native Event envelope: " + event_id)
		_check(record.get("title") == contract["title"],
			"the authored title matches: " + event_id)
		_check(record.get("description") == contract["description"],
			"the authored description matches: " + event_id)
		var choices: Variant = record.get("choices")
		if not choices is Array or (choices as Array).size() != 3:
			_check(false, "the new record carries exactly three choices: " + event_id)
			continue
		var seen: Dictionary = {}
		for choice in choices:
			if not choice is Dictionary:
				_check(false, "each new choice is an object: " + event_id)
				continue
			var authored: Dictionary = choice
			_check(authored.keys().size() == 3 and authored.has("id")
				and authored.has("text") and authored.has("stitched_effect"),
				"each new choice uses only id/text/stitched_effect: " + event_id)
			seen[authored.get("id")] = true
		_check(seen.size() == 3, "the three new choice IDs are distinct: " + event_id)
		var by_id := {}
		for choice in choices:
			by_id[(choice as Dictionary).get("id")] = choice
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			if not by_id.has(choice_id):
				_check(false, "the record keeps its choice " + choice_id + ": " + event_id)
				continue
			var authored_choice: Dictionary = by_id[choice_id]
			_check(authored_choice.get("text") == definition["text"],
				"the authored choice text matches: " + event_id + " / " + choice_id)
			var effect: Variant = authored_choice.get("stitched_effect")
			if not effect is Dictionary:
				_check(false, "the authored choice carries a stitched_effect: " + event_id + " / " + choice_id)
				continue
			var expected_effect: Dictionary = definition["effect"]
			_check((effect as Dictionary).size() == expected_effect.size(),
				"the effect carries exactly its authored keys: " + event_id + " / " + choice_id)
			for key in expected_effect:
				_check((effect as Dictionary).has(key)
					and (effect as Dictionary)[key] == expected_effect[key],
					"the authored effect field matches exactly: " + event_id + " / " + choice_id + " / " + str(key))


## The named earlier anchors stay present with their original titles.
func _test_anchor_records() -> void:
	for anchor_id in ANCHOR_TITLES:
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"the earlier anchor keeps exactly one record: " + anchor_id)
		if not source_by_id.has(anchor_id):
			continue
		var record: Dictionary = source_by_id[anchor_id]
		_check(record.get("title") == ANCHOR_TITLES[anchor_id],
			"the anchor keeps its original title: " + anchor_id)
		_check(record.get("choices") is Array
			and (record.get("choices") as Array).size() >= 2,
			"the anchor keeps its choices: " + anchor_id)


## Funded previews and claims agree with the independent oracle on all nine
## choices; a settled visit cannot be replayed, previews close after the
## claim, and neither the caller snapshot nor the record is ever mutated.
func _test_funded_contract() -> void:
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 616161
	var guard_state: int = rng_guard.state
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var table: Dictionary = FUNDED_FINAL[event_id]
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		_check(RunEventChoice.new(record).is_valid(),
			"the shipped envelope validator accepts the fresh record: " + event_id)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var row: Dictionary = table[choice_id]
			_check(int(row["candle"]) == BASE_CANDLE + int(row["candle_delta"]),
				"the funded candle agrees with its hardcoded delta: " + event_id + " / " + choice_id)
			if row.has("scraps"):
				_check(int(row["scraps"]) == BASE_SCRAPS + int(row["scraps_delta"]),
					"the funded scraps agree with their hardcoded delta: " + event_id + " / " + choice_id)
			if row.has("gold"):
				_check(int(row["gold"]) == BASE_GOLD + int(row["gold_delta"]),
					"the funded gold agrees with its hardcoded delta: " + event_id + " / " + choice_id)
			var snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
			var before: Dictionary = snapshot.duplicate(true)
			var service := RunStitchedEventConsequence.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"a fresh visit opens: " + event_id + " / " + choice_id)
			var preview: Dictionary = service.preview(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and int(preview.get("candle")) == BASE_CANDLE,
				"funded preview succeeds: " + event_id + " / " + choice_id)
			_check(preview.get("choices", []).size() == 3,
				"funded preview lists all three choices: " + event_id)
			var entry := _entry(preview, choice_id)
			_check(entry == _expected_entry(choice_id, row),
				"funded preview matches the hardcoded oracle exactly: " + event_id + " / " + choice_id)
			var receipt: Dictionary = service.choose(choice_id, snapshot)
			_check(receipt == _expected_receipt(event_id, choice_id, row),
				"funded claim settles the hardcoded oracle exactly: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches exactly once: " + event_id + " / " + choice_id)
			_check(service.choose(choice_id, snapshot) == _refusal(BASE_CANDLE),
				"a settled choice cannot be replayed: " + event_id + " / " + choice_id)
			var other_id := _other_choice_id(contract, choice_id)
			_check(service.choose(other_id, snapshot) == _refusal(BASE_CANDLE),
				"no alternate choice claims a spent visit: " + event_id + " / " + choice_id)
			_check(service.preview(snapshot) == _denied_preview(),
				"a spent visit offers no further preview: " + event_id + " / " + choice_id)
			_check(snapshot == before and record == record_snapshot,
				"a funded flow mutates neither snapshot nor record: " + event_id + " / " + choice_id)
	_check(settlements == 9, "every one of the nine authored choices settles once when funded")
	_check(rng_guard.state == guard_state,
		"previews and claims never touch an unrelated seeded RNG")


## Each paid option one unit short previews unavailable with the caller's
## unchanged balance, is refused without a claim or any balance change, and
## Leave still succeeds on that same visit.
func _test_underfunded_visits() -> void:
	for event_id in UNDERFUNDED:
		var plan: Dictionary = UNDERFUNDED[event_id]
		var paid_id: String = plan["choice_id"]
		var balance_key: String = plan["balance_key"]
		var snapshot := _funded_snapshot(int(plan["gold"]), int(plan["scraps"]))
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new((source_by_id[event_id] as Dictionary).duplicate(true))
		var preview: Dictionary = service.preview(snapshot)
		_check(preview.get("ok") == true,
			"an underfunded visit still previews: " + event_id)
		var paid := _entry(preview, paid_id)
		_check(paid.get("available") == false and int(paid.get("candle")) == BASE_CANDLE
			and paid.get("fray") == {},
			"the underfunded paid choice is unavailable without projection: " + event_id)
		_check(paid.has(balance_key) and int(paid[balance_key]) == int(plan["balance"]),
			"the unavailable paid choice reports the caller's unchanged balance: " + event_id)
		_check(_entry(preview, String(plan["free_id"])).get("available") == true,
			"the free alternative stays selectable on the underfunded visit: " + event_id)
		_check(_entry(preview, "leave").get("available") == true,
			"Leave stays selectable on the underfunded visit: " + event_id)
		_check(service.choose(paid_id, snapshot) == _refusal(BASE_CANDLE),
			"the underfunded paid choice is refused: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"a refused debit keeps the visit open and unclaimed: " + event_id)
		_check(snapshot == before,
			"a refused debit changes no balance: " + event_id)
		var leave: Dictionary = service.choose("leave", snapshot)
		_check(leave == _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"]),
			"Leave succeeds on the same visit after the refusal: " + event_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the post-refusal Leave claim latches once: " + event_id)
		_check(snapshot == before,
			"the underfunded flow mutates no balance at all: " + event_id)


## A zero purse can still claim one nonzero free path per story, settling the
## hardcoded oracle.
func _test_zero_purse_free_claims() -> void:
	for event_id in ZERO_PURSE_FREE:
		var pick: Dictionary = ZERO_PURSE_FREE[event_id]
		var choice_id: String = pick["choice_id"]
		var snapshot := _funded_snapshot(0, 0)
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new((source_by_id[event_id] as Dictionary).duplicate(true))
		var preview: Dictionary = service.preview(snapshot)
		_check(_entry(preview, choice_id).get("available") == true,
			"a zero purse can still select the free path: " + event_id)
		var receipt: Dictionary = service.choose(choice_id, snapshot)
		var expected := {
			"ok": true,
			"event_id": event_id,
			"choice_id": choice_id,
			"target": "party",
			"hero_id": "",
			"candle": int(pick["candle"]),
			"fray": _fray_map(int(pick["fray"])),
		}
		for key in pick["extra"]:
			expected[key] = pick["extra"][key]
		_check(receipt == expected,
			"the zero-purse free path settles the hardcoded oracle: " + event_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the zero-purse claim latches once: " + event_id)
		_check(snapshot == before,
			"the zero-purse flow mutates no balance: " + event_id)


## An unknown choice ID is refused without a claim and Leave then succeeds on
## the same visit.
func _test_unknown_choice_refusals() -> void:
	for event_id in EXPECTED:
		var snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new((source_by_id[event_id] as Dictionary).duplicate(true))
		_check(service.choose("forged_choice", snapshot) == _refusal(BASE_CANDLE),
			"an unknown choice ID is refused: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"an unknown choice keeps the visit open: " + event_id)
		var leave: Dictionary = service.choose("leave", snapshot)
		_check(leave == _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"]),
			"Leave succeeds after the forged refusal: " + event_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the post-forged Leave claim latches once: " + event_id)
		_check(snapshot == before,
			"forged-ID flows mutate no snapshot: " + event_id)


## A choice carrying an unsupported extra effect key stays envelope-valid but
## can never settle: no preview availability, no receipt, no claim consumed.
func _test_stale_effect_fails() -> void:
	var record: Dictionary = (source_by_id["v3_glassfront_pin_cabinet"] as Dictionary).duplicate(true)
	var choices: Array = record["choices"]
	var stale: Dictionary = choices[0]
	stale["outcome"] = {"gold": 1, "scraps": 1}
	var snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
	var before: Dictionary = snapshot.duplicate(true)
	var service := RunStitchedEventConsequence.new(record)
	_check(service.is_valid(),
		"a stale choice keeps the shared envelope valid")
	var preview: Dictionary = service.preview(snapshot)
	var entry := _entry(preview, "salvage_loose_pinheads")
	_check(entry.get("available") == false and entry.get("candle_delta") == null
		and entry.get("fray_delta") == null,
		"an unsupported extra effect key makes the choice unsettleable")
	_check(service.choose("salvage_loose_pinheads", snapshot) == _refusal(BASE_CANDLE),
		"an unsupported effect is refused without a receipt")
	_check(service.is_valid() and not service.is_claimed(),
		"the stale effect consumes no claim")
	_check(snapshot == before,
		"the stale-effect flow mutates no snapshot")


## Authentic low-band and disallowed-band Bedwarmer witness (AC2, AC3):
## At opening candles 0, 25, 26, 50 (snuffed, dark, gloom) with gold >= 11,
## rent_ember_lid is available in preview and claims once, settling candle 22, 47, 48, 72,
## -11 gold and +5 fray per active doll.
## At disallowed opening candles 51, 75, 76, 99, 100 (dim, bright, full candle),
## rent_ember_lid is unavailable in preview (empty fray intent, base purse), choose() refuses
## with exact uniform refusal shape without consuming the visit or mutating snapshot/record/RNG,
## and sift_cooling_ashes (candle >= 12) and leave remain claimable on the same visit.
func _test_full_candle_bedwarmer() -> void:
	var event_id := "v3_cinder_brass_bedwarmer"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	var record_snapshot: Dictionary = record.duplicate(true)
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 334455
	var guard_state: int = rng_guard.state

	# 1. Low-band boundary positives: candles 0, 25, 26, 50 with exact gold 11
	var low_band_cases := [
		{"opening": 0, "expected_candle": 22},
		{"opening": 25, "expected_candle": 47},
		{"opening": 26, "expected_candle": 48},
		{"opening": 50, "expected_candle": 72},
	]
	for c_case in low_band_cases:
		var c: int = c_case["opening"]
		var exp_candle: int = c_case["expected_candle"]
		var snapshot := _funded_snapshot(11, BASE_SCRAPS)
		snapshot["candle"] = c
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		_check(service.is_valid() and not service.is_claimed(),
			"fresh visit opens for low-band bedwarmer: candle " + str(c))
		var preview: Dictionary = service.preview(snapshot)
		_check(preview.get("ok") == true and int(preview.get("candle")) == c,
			"preview ok for low-band bedwarmer: candle " + str(c))
		var rent := _entry(preview, "rent_ember_lid")
		_check(rent.get("available") == true
			and int(rent.get("candle")) == exp_candle
			and int(rent.get("candle_delta")) == 22
			and int(rent.get("gold")) == 0
			and int(rent.get("gold_delta")) == -11
			and int(rent.get("fray_delta")) == 5
			and rent.get("fray") == _fray_map(5),
			"candle " + str(c) + " quotes rent_ember_lid available, settled candle " + str(exp_candle) + ", gold 0, fray +5")
		var receipt: Dictionary = service.choose("rent_ember_lid", snapshot)
		var expected_receipt := {
			"ok": true,
			"event_id": event_id,
			"choice_id": "rent_ember_lid",
			"target": "party",
			"hero_id": "",
			"candle": exp_candle,
			"fray": _fray_map(5),
			"gold": 0,
			"gold_delta": -11,
		}
		_check(receipt == expected_receipt,
			"candle " + str(c) + " claims rent_ember_lid settling candle " + str(exp_candle) + ", gold 0, fray +5")
		_check(service.is_claimed() and not service.is_valid(),
			"visit latches after low-band claim at candle " + str(c))
		_check(service.choose("rent_ember_lid", snapshot) == _refusal(c),
			"replay refusal at candle " + str(c))
		_check(service.choose("leave", snapshot) == _refusal(c),
			"spent visit refuses alternative at candle " + str(c))
		_check(snapshot == before,
			"claim mutates no caller snapshot at candle " + str(c))
		_check(record == record_snapshot,
			"claim mutates no source record at candle " + str(c))
		_check(rng_guard.state == guard_state,
			"claim draws no RNG at candle " + str(c))

	# 2. Disallowed-band negatives: candles 51, 75, 76, 99, 100 with ample gold 60
	var disallowed_candles := [51, 75, 76, 99, 100]
	for c in disallowed_candles:
		var snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		snapshot["candle"] = c
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		_check(service.is_valid() and not service.is_claimed(),
			"fresh visit opens for disallowed-band bedwarmer: candle " + str(c))
		var preview: Dictionary = service.preview(snapshot)
		_check(preview.get("ok") == true and int(preview.get("candle")) == c,
			"preview ok for disallowed-band bedwarmer: candle " + str(c))
		var rent := _entry(preview, "rent_ember_lid")
		_check(rent.get("available") == false
			and int(rent.get("candle")) == c
			and int(rent.get("candle_delta")) == 22
			and int(rent.get("gold")) == BASE_GOLD
			and int(rent.get("gold_delta")) == -11
			and int(rent.get("fray_delta")) == 5
			and rent.get("fray") == {},
			"disallowed candle " + str(c) + " quotes rent_ember_lid unavailable with base purse and empty fray")
		_check(_entry(preview, "sift_cooling_ashes").get("available") == true,
			"sift_cooling_ashes remains available at disallowed candle " + str(c))
		_check(_entry(preview, "leave").get("available") == true,
			"leave remains available at disallowed candle " + str(c))

		# choose("rent_ember_lid") refuses without latching or mutating state/RNG
		var refusal: Dictionary = service.choose("rent_ember_lid", snapshot)
		_check(refusal == _refusal(c),
			"rent_ember_lid is refused at disallowed candle " + str(c) + " with uniform refusal shape")
		_check(service.is_valid() and not service.is_claimed(),
			"refusal on disallowed candle " + str(c) + " leaves visit unclaimed and open")
		_check(snapshot == before,
			"refusal on disallowed candle " + str(c) + " mutates no caller snapshot")
		_check(record == record_snapshot,
			"refusal on disallowed candle " + str(c) + " mutates no source record")
		_check(rng_guard.state == guard_state,
			"refusal on disallowed candle " + str(c) + " draws no RNG")

		# Alternative choice (sift_cooling_ashes) succeeds on the same visit after refusal
		var sift_receipt: Dictionary = service.choose("sift_cooling_ashes", snapshot)
		var expected_sift := {
			"ok": true,
			"event_id": event_id,
			"choice_id": "sift_cooling_ashes",
			"target": "party",
			"hero_id": "",
			"candle": c - 12,
			"fray": _fray_map(-6),
			"scraps": BASE_SCRAPS + 2,
			"scraps_delta": 2,
		}
		_check(sift_receipt == expected_sift,
			"sift_cooling_ashes claims successfully on same visit after rent refusal at candle " + str(c))
		_check(service.is_claimed() and not service.is_valid(),
			"visit latches after sift claim at candle " + str(c))

		# Independent visit: leave succeeds after rent refusal
		var service_leave := RunStitchedEventConsequence.new(record)
		var snapshot_leave := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		snapshot_leave["candle"] = c
		_check(service_leave.choose("rent_ember_lid", snapshot_leave) == _refusal(c),
			"rent_ember_lid refusal on independent visit at candle " + str(c))
		var leave_receipt: Dictionary = service_leave.choose("leave", snapshot_leave)
		var expected_leave := {
			"ok": true,
			"event_id": event_id,
			"choice_id": "leave",
			"target": "party",
			"hero_id": "",
			"candle": c,
			"fray": {},
		}
		_check(leave_receipt == expected_leave,
			"leave succeeds after rent refusal at candle " + str(c))
		_check(service_leave.is_claimed() and not service_leave.is_valid(),
			"visit latches after leave claim at candle " + str(c))

	# 3. Insufficient gold (10 vs required 11) within a low candle band (candle 25)
	var snapshot_underfunded := _funded_snapshot(10, BASE_SCRAPS)
	snapshot_underfunded["candle"] = 25
	var before_underfunded: Dictionary = snapshot_underfunded.duplicate(true)
	var service_underfunded := RunStitchedEventConsequence.new(record)
	var preview_underfunded: Dictionary = service_underfunded.preview(snapshot_underfunded)
	var rent_underfunded := _entry(preview_underfunded, "rent_ember_lid")
	_check(rent_underfunded.get("available") == false
		and int(rent_underfunded.get("candle")) == 25
		and int(rent_underfunded.get("gold")) == 10
		and rent_underfunded.get("fray") == {},
		"insufficient gold 10 at candle 25 quotes rent_ember_lid unavailable with base purse and empty fray")
	_check(_entry(preview_underfunded, "sift_cooling_ashes").get("available") == true,
		"sift_cooling_ashes remains available with insufficient gold at candle 25")
	_check(_entry(preview_underfunded, "leave").get("available") == true,
		"leave remains available with insufficient gold at candle 25")
	_check(service_underfunded.choose("rent_ember_lid", snapshot_underfunded) == _refusal(25),
		"rent_ember_lid refused with insufficient gold 10 at candle 25")
	_check(service_underfunded.is_valid() and not service_underfunded.is_claimed(),
		"visit remains unclaimed after insufficient-gold refusal at candle 25")
	_check(snapshot_underfunded == before_underfunded,
		"snapshot unchanged after insufficient-gold refusal at candle 25")
	var sift_underfunded: Dictionary = service_underfunded.choose("sift_cooling_ashes", snapshot_underfunded)
	_check(sift_underfunded.get("ok") == true and int(sift_underfunded.get("candle")) == 13,
		"sift_cooling_ashes succeeds on same visit after insufficient-gold refusal at candle 25")
	_check(service_underfunded.is_claimed() and not service_underfunded.is_valid(),
		"visit latches on sift after insufficient-gold refusal")


## Authentic full-candle witness for the Pin Cabinet (AC3): at candle 100 with scraps >= 2,
## "brace_wick_with_pins" is unavailable (preserving opening candle/scraps and empty fray intent),
## choose() refuses without consuming the visit or mutating state, and alternate choices
## ("salvage_loose_pinheads" and "leave") remain claimable. "brace_wick_with_pins" carries
## require_full_candle_gain, so it only admits when the whole +15 fits (candle <= 85): at the
## exactly funded candle 85 with scraps 2 it claims candle 100, scraps 0 and fray -4 each; the
## near-full candles 86 and 99 are refused too (see _test_pin_cabinet_partial_gain_refusals).
func _test_full_candle_pin_cabinet() -> void:
	var event_id := "v3_glassfront_pin_cabinet"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	var record_snapshot: Dictionary = record.duplicate(true)
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 223344
	var guard_state: int = rng_guard.state

	# 1. Full candle 100 with ample scraps (4)
	var snapshot_100 := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
	snapshot_100["candle"] = 100
	var before_100: Dictionary = snapshot_100.duplicate(true)
	var service_100 := RunStitchedEventConsequence.new(record)
	_check(service_100.is_valid() and not service_100.is_claimed(),
		"a fresh full-candle pin cabinet visit opens")
	var preview_100: Dictionary = service_100.preview(snapshot_100)
	_check(preview_100.get("ok") == true and int(preview_100.get("candle")) == 100,
		"full-candle pin cabinet preview succeeds")
	var brace_entry := _entry(preview_100, "brace_wick_with_pins")
	_check(brace_entry.get("available") == false
		and int(brace_entry.get("candle")) == 100
		and int(brace_entry.get("candle_delta")) == 15
		and int(brace_entry.get("scraps")) == BASE_SCRAPS
		and int(brace_entry.get("scraps_delta")) == -2
		and int(brace_entry.get("fray_delta")) == -4
		and brace_entry.get("fray") == {},
		"full candle quotes brace_wick_with_pins unavailable with original deltas, base scraps, and empty fray")
	_check(_entry(preview_100, "salvage_loose_pinheads").get("available") == true,
		"salvage_loose_pinheads remains available at candle 100")
	_check(_entry(preview_100, "leave").get("available") == true,
		"leave remains available at candle 100 for pin cabinet")

	# choose("brace_wick_with_pins") refuses at candle 100 without latching or mutating state/RNG
	var refusal: Dictionary = service_100.choose("brace_wick_with_pins", snapshot_100)
	_check(refusal == _refusal(100),
		"brace_wick_with_pins is refused at candle 100 with uniform refusal shape")
	_check(service_100.is_valid() and not service_100.is_claimed(),
		"refusal on full candle leaves pin cabinet unclaimed and open")
	_check(snapshot_100 == before_100,
		"refusal on full candle mutates no caller snapshot")
	_check(record == record_snapshot,
		"refusal on full candle mutates no source record")
	_check(rng_guard.state == guard_state,
		"brace_wick_with_pins refusal draws no RNG")

	# Alternative choice succeeds on the same visit after refusal
	var salvage_receipt: Dictionary = service_100.choose("salvage_loose_pinheads", snapshot_100)
	_check(salvage_receipt.get("ok") == true
		and int(salvage_receipt.get("candle")) == 92
		and int(salvage_receipt.get("scraps")) == BASE_SCRAPS + 3
		and salvage_receipt.get("fray") == _fray_map(4),
		"salvage_loose_pinheads claims successfully on the same visit after brace refusal")
	_check(service_100.is_claimed() and not service_100.is_valid(),
		"visit latches once after alternative salvage claim")

	# Independent full-candle visit where leave succeeds after refusal
	var service_leave := RunStitchedEventConsequence.new(record)
	var snapshot_leave := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
	snapshot_leave["candle"] = 100
	_check(service_leave.choose("brace_wick_with_pins", snapshot_leave) == _refusal(100),
		"brace_wick_with_pins refusal on second independent visit")
	var leave_receipt: Dictionary = service_leave.choose("leave", snapshot_leave)
	var expected_leave := {
		"ok": true,
		"event_id": event_id,
		"choice_id": "leave",
		"target": "party",
		"hero_id": "",
		"candle": 100,
		"fray": {},
	}
	_check(leave_receipt == expected_leave,
		"leave succeeds after brace_wick_with_pins refusal at candle 100")

	# 2. Exactly funded candle 85 with exact scraps (2): the full +15 fits
	var snapshot_85 := _funded_snapshot(BASE_GOLD, 2)
	snapshot_85["candle"] = 85
	var before_85: Dictionary = snapshot_85.duplicate(true)
	var service_85 := RunStitchedEventConsequence.new(record)
	var preview_85: Dictionary = service_85.preview(snapshot_85)
	var brace_85 := _entry(preview_85, "brace_wick_with_pins")
	_check(brace_85.get("available") == true
		and int(brace_85.get("candle")) == 100
		and int(brace_85.get("candle_delta")) == 15
		and int(brace_85.get("scraps")) == 0
		and int(brace_85.get("scraps_delta")) == -2
		and int(brace_85.get("fray_delta")) == -4
		and brace_85.get("fray") == _fray_map(-4),
		"candle 85 with scraps 2 quotes brace_wick_with_pins available, candle 100, scraps 0, fray -4")
	var receipt_85: Dictionary = service_85.choose("brace_wick_with_pins", snapshot_85)
	_check(receipt_85 == {
		"ok": true,
		"event_id": event_id,
		"choice_id": "brace_wick_with_pins",
		"target": "party",
		"hero_id": "",
		"candle": 100,
		"fray": _fray_map(-4),
		"scraps": 0,
		"scraps_delta": -2,
	}, "candle 85 with scraps 2 claims brace_wick_with_pins settling candle 100, scraps 0, fray -4 each")
	_check(service_85.is_claimed() and not service_85.is_valid(),
		"visit latches after the exactly funded candle-85 claim for pin cabinet")
	_check(service_85.choose("brace_wick_with_pins", snapshot_85) == _refusal(85),
		"replay refusal after the candle-85 claim for pin cabinet")
	_check(snapshot_85 == before_85,
		"claim mutates no caller snapshot for pin cabinet")
	_check(record == record_snapshot,
		"the candle-85 claim mutates no source record")
	_check(rng_guard.state == guard_state,
		"the candle-85 claim draws no RNG")

	# 3. Scraps 1 at candle 85: a funded candle gate still needs the price
	var snapshot_poor := _funded_snapshot(BASE_GOLD, 1)
	snapshot_poor["candle"] = 85
	var before_poor: Dictionary = snapshot_poor.duplicate(true)
	var service_poor := RunStitchedEventConsequence.new(record)
	_check(_entry(service_poor.preview(snapshot_poor), "brace_wick_with_pins").get("available") == false,
		"candle 85 with scraps 1 quotes brace_wick_with_pins unavailable")
	_check(service_poor.choose("brace_wick_with_pins", snapshot_poor) == _refusal(85),
		"candle 85 with scraps 1 refuses brace_wick_with_pins")
	_check(service_poor.is_valid() and not service_poor.is_claimed() and snapshot_poor == before_poor,
		"the scraps-1 refusal at candle 85 keeps the visit open and the snapshot unchanged")


## Authentic partial-gain refusals: at candle 86 (only +14 fits), 99 and 100 the funded
## (scraps 2) brace_wick_with_pins is unavailable with its original deltas and an empty fray
## intent, choose() refuses with the uniform shape and no debit, snapshot, record, claim or
## RNG change, and then both Leave and the legal salvage still claim on the same visit.
func _test_pin_cabinet_partial_gain_refusals() -> void:
	var event_id := "v3_glassfront_pin_cabinet"
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 778899
	var guard_state: int = rng_guard.state
	for candle in [86, 99, 100]:
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		var snapshot := _funded_snapshot(BASE_GOLD, 2)
		snapshot["candle"] = candle
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		var preview: Dictionary = service.preview(snapshot)
		var brace := _entry(preview, "brace_wick_with_pins")
		_check(brace.get("available") == false
			and int(brace.get("candle")) == candle
			and int(brace.get("candle_delta")) == 15
			and int(brace.get("scraps")) == 2
			and int(brace.get("scraps_delta")) == -2
			and int(brace.get("fray_delta")) == -4
			and brace.get("fray") == {},
			"funded candle " + str(candle) + " quotes brace_wick_with_pins unavailable with base scraps and empty fray")
		_check(_entry(preview, "salvage_loose_pinheads").get("available") == true
			and _entry(preview, "leave").get("available") == true,
			"salvage and leave stay available at candle " + str(candle))
		_check(service.choose("brace_wick_with_pins", snapshot) == _refusal(candle),
			"funded candle " + str(candle) + " refuses brace_wick_with_pins with the uniform shape")
		_check(service.is_valid() and not service.is_claimed(),
			"the candle-" + str(candle) + " refusal leaves the visit open and unclaimed")
		_check(snapshot == before and int(snapshot["scraps"]) == 2,
			"the candle-" + str(candle) + " refusal debits no scraps and mutates no snapshot")
		_check(record == record_snapshot,
			"the candle-" + str(candle) + " refusal mutates no source record")
		_check(rng_guard.state == guard_state,
			"the candle-" + str(candle) + " refusal draws no RNG")
		var salvage: Dictionary = service.choose("salvage_loose_pinheads", snapshot)
		_check(salvage.get("ok") == true
			and int(salvage.get("candle")) == candle - 8
			and int(salvage.get("scraps")) == 5
			and salvage.get("fray") == _fray_map(4),
			"salvage claims on the same visit after the candle-" + str(candle) + " brace refusal")
		_check(service.is_claimed() and not service.is_valid(),
			"the post-refusal salvage latches the candle-" + str(candle) + " visit")

		var leave_service := RunStitchedEventConsequence.new(record)
		_check(leave_service.choose("brace_wick_with_pins", snapshot) == _refusal(candle),
			"brace_wick_with_pins is refused on a second candle-" + str(candle) + " visit")
		var leave: Dictionary = leave_service.choose("leave", snapshot)
		_check(leave == {
			"ok": true,
			"event_id": event_id,
			"choice_id": "leave",
			"target": "party",
			"hero_id": "",
			"candle": candle,
			"fray": {},
		}, "Leave stays free and claimable after the candle-" + str(candle) + " brace refusal")
		_check(leave_service.is_claimed() and snapshot == before,
			"the Leave claim at candle " + str(candle) + " latches and mutates no snapshot")


## Authentic negative-candle boundaries (AC2):
## 7/8 for v3_glassfront_pin_cabinet.salvage_loose_pinheads (-8 candle, +3 scraps, +4 fray)
## 9/10 for v3_moonblack_paperweight.lift_shadowed_map (-10 candle, +23 gold, +7 fray)
## 11/12 for v3_cinder_brass_bedwarmer.sift_cooling_ashes (-12 candle, +2 scraps, -6 fray)
## Verifies underpriced snapshot makes choice unavailable and choose() refuses without
## claim, state mutation or RNG use; exactly funded boundary makes it available and
## returns original correct receipt. Leave remains claimable after denial.
func _test_negative_candle_boundaries() -> void:
	var boundaries := [
		{
			"event_id": "v3_glassfront_pin_cabinet",
			"choice_id": "salvage_loose_pinheads",
			"under_candle": 7,
			"funded_candle": 8,
			"candle_delta": -8,
			"fray_delta": 4,
			"wallet_key": "scraps",
			"wallet_delta_key": "scraps_delta",
			"wallet_base": BASE_SCRAPS,
			"wallet_delta": 3,
		},
		{
			"event_id": "v3_moonblack_paperweight",
			"choice_id": "lift_shadowed_map",
			"under_candle": 9,
			"funded_candle": 10,
			"candle_delta": -10,
			"fray_delta": 7,
			"wallet_key": "gold",
			"wallet_delta_key": "gold_delta",
			"wallet_base": BASE_GOLD,
			"wallet_delta": 23,
		},
		{
			"event_id": "v3_cinder_brass_bedwarmer",
			"choice_id": "sift_cooling_ashes",
			"under_candle": 11,
			"funded_candle": 12,
			"candle_delta": -12,
			"fray_delta": -6,
			"wallet_key": "scraps",
			"wallet_delta_key": "scraps_delta",
			"wallet_base": BASE_SCRAPS,
			"wallet_delta": 2,
		},
	]

	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 556677
	var guard_state: int = rng_guard.state

	for b in boundaries:
		var event_id: String = b["event_id"]
		var choice_id: String = b["choice_id"]
		var under_candle: int = b["under_candle"]
		var funded_candle: int = b["funded_candle"]
		var candle_delta: int = b["candle_delta"]
		var fray_delta: int = b["fray_delta"]
		var wallet_key: String = b["wallet_key"]
		var wallet_delta_key: String = b["wallet_delta_key"]
		var wallet_base: int = b["wallet_base"]
		var wallet_delta: int = b["wallet_delta"]
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)

		# 1. Underfunded candle boundary
		var snapshot_under := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		snapshot_under["candle"] = under_candle
		var before_under: Dictionary = snapshot_under.duplicate(true)
		var service_under := RunStitchedEventConsequence.new(record)
		_check(service_under.is_valid() and not service_under.is_claimed(),
			"fresh visit opens for underfunded boundary: " + event_id + " candle " + str(under_candle))
		var preview_under: Dictionary = service_under.preview(snapshot_under)
		_check(preview_under.get("ok") == true and int(preview_under.get("candle")) == under_candle,
			"preview ok for underfunded boundary: " + event_id + " candle " + str(under_candle))
		var entry_under := _entry(preview_under, choice_id)
		_check(entry_under.get("available") == false
			and int(entry_under.get("candle")) == under_candle
			and int(entry_under.get("candle_delta")) == candle_delta
			and int(entry_under.get("fray_delta")) == fray_delta
			and entry_under.get("fray") == {}
			and int(entry_under.get(wallet_key)) == wallet_base
			and int(entry_under.get(wallet_delta_key)) == wallet_delta,
			"underpriced candle " + str(under_candle) + " makes choice unavailable with unchanged base purse and empty fray: " + event_id + " / " + choice_id)
		_check(_entry(preview_under, "leave").get("available") == true,
			"leave remains available at underfunded candle: " + event_id)

		var refusal: Dictionary = service_under.choose(choice_id, snapshot_under)
		_check(refusal == _refusal(under_candle),
			"underfunded choice refused with exact base candle: " + event_id + " candle " + str(under_candle))
		_check(service_under.is_valid() and not service_under.is_claimed(),
			"underfunded choice refusal leaves visit unclaimed: " + event_id)
		_check(snapshot_under == before_under,
			"refusal mutates no caller snapshot: " + event_id)
		_check(record == record_snapshot,
			"refusal mutates no source record: " + event_id)
		_check(rng_guard.state == guard_state,
			"refusal draws no RNG: " + event_id)

		# Leave succeeds on the same visit after refusal
		var leave_rec: Dictionary = service_under.choose("leave", snapshot_under)
		var expected_leave := {
			"ok": true,
			"event_id": event_id,
			"choice_id": "leave",
			"target": "party",
			"hero_id": "",
			"candle": under_candle,
			"fray": {},
		}
		_check(leave_rec == expected_leave,
			"leave succeeds after underfunded negative candle refusal: " + event_id + " candle " + str(under_candle))
		_check(service_under.is_claimed() and not service_under.is_valid(),
			"visit latches after post-refusal Leave: " + event_id)
		_check(snapshot_under == before_under,
			"post-refusal Leave mutates no wallet/candle state: " + event_id)

		# 2. Exactly funded candle boundary
		var snapshot_funded := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		snapshot_funded["candle"] = funded_candle
		var before_funded: Dictionary = snapshot_funded.duplicate(true)
		var service_funded := RunStitchedEventConsequence.new(record)
		_check(service_funded.is_valid() and not service_funded.is_claimed(),
			"fresh visit opens for funded boundary: " + event_id + " candle " + str(funded_candle))
		var preview_funded: Dictionary = service_funded.preview(snapshot_funded)
		_check(preview_funded.get("ok") == true and int(preview_funded.get("candle")) == funded_candle,
			"preview ok for funded boundary: " + event_id + " candle " + str(funded_candle))
		var entry_funded := _entry(preview_funded, choice_id)
		_check(entry_funded.get("available") == true
			and int(entry_funded.get("candle")) == 0
			and int(entry_funded.get("candle_delta")) == candle_delta
			and int(entry_funded.get("fray_delta")) == fray_delta
			and entry_funded.get("fray") == _fray_map(fray_delta)
			and int(entry_funded.get(wallet_key)) == wallet_base + wallet_delta
			and int(entry_funded.get(wallet_delta_key)) == wallet_delta,
			"funded candle " + str(funded_candle) + " makes choice available leaving candle 0: " + event_id + " / " + choice_id)

		var receipt_funded: Dictionary = service_funded.choose(choice_id, snapshot_funded)
		var expected_receipt := {
			"ok": true,
			"event_id": event_id,
			"choice_id": choice_id,
			"target": "party",
			"hero_id": "",
			"candle": 0,
			"fray": _fray_map(fray_delta),
		}
		expected_receipt[wallet_delta_key] = wallet_delta
		expected_receipt[wallet_key] = wallet_base + wallet_delta
		_check(receipt_funded == expected_receipt,
			"funded choice claims leaving candle 0 with correct purse/fray receipt: " + event_id + " / " + choice_id)
		_check(service_funded.is_claimed() and not service_funded.is_valid(),
			"visit latches after funded boundary claim: " + event_id)
		_check(service_funded.choose(choice_id, snapshot_funded) == _refusal(funded_candle),
			"replay refused after funded claim: " + event_id)
		_check(snapshot_funded == before_funded,
			"funded claim mutates no caller snapshot: " + event_id)
		_check(rng_guard.state == guard_state,
			"funded claim draws no RNG: " + event_id)


func _funded_snapshot(gold: int, scraps: int) -> Dictionary:
	var party: Array = []
	for pair in PARTY_FRAYS:
		party.append({"id": pair[0], "fray": pair[1]})
	return {"candle": BASE_CANDLE, "party": party, "gold": gold, "scraps": scraps, "satchel_count": 0}


func _fray_map(delta: int) -> Dictionary:
	var intents: Dictionary = {}
	if delta == 0:
		return intents
	for pair in PARTY_FRAYS:
		intents[pair[0]] = delta
	return intents


func _expected_entry(choice_id: String, row: Dictionary) -> Dictionary:
	var entry := {
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle_delta": int(row["candle_delta"]),
		"fray_delta": int(row["fray"]),
		"available": true,
		"candle": int(row["candle"]),
		"fray": _fray_map(int(row["fray"])),
	}
	if row.has("scraps"):
		entry["scraps_delta"] = int(row["scraps_delta"])
		entry["scraps"] = int(row["scraps"])
	if row.has("gold"):
		entry["gold_delta"] = int(row["gold_delta"])
		entry["gold"] = int(row["gold"])
	return entry


func _expected_receipt(event_id: String, choice_id: String, row: Dictionary) -> Dictionary:
	var receipt := {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": int(row["candle"]),
		"fray": _fray_map(int(row["fray"])),
	}
	if row.has("scraps"):
		receipt["scraps_delta"] = int(row["scraps_delta"])
		receipt["scraps"] = int(row["scraps"])
	if row.has("gold"):
		receipt["gold_delta"] = int(row["gold_delta"])
		receipt["gold"] = int(row["gold"])
	return receipt


func _entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _other_choice_id(contract: Dictionary, choice_id: String) -> String:
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		if definition["id"] != choice_id:
			return definition["id"]
	return ""


func _refusal(candle: int) -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"target": "",
		"hero_id": "",
		"candle": candle,
		"fray": {},
	}


func _denied_preview() -> Dictionary:
	return {"ok": false, "event_id": "", "candle": 0, "choices": []}
