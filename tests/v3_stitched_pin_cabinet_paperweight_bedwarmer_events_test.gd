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
			{"id": "salvage_loose_pinheads", "text": "Open a draughty pin tray (+3 scraps, -8 candle, +4 fray each)", "effect": {"target": "party", "candle": -8, "fray": 4, "scraps": 3}},
			{"id": "brace_wick_with_pins", "text": "Spend 2 scraps bracing the candle wick (+15 candle, -4 fray each)", "effect": {"target": "party", "candle": 15, "fray": -4, "scraps": -2}},
			{"id": "leave", "text": "Let the cabinet's velvet drawers close", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_moonblack_paperweight": {
		"title": "The Moonblack Paperweight",
		"description": "A moonblack glass paperweight pins a torn house plan to the floorboards; a small cream-felt mapkeeper waits beneath its cold reflection, holding an ink-stained spool.",
		"choices": [
			{"id": "buy_quiet_house_plan", "text": "Pay 16 gold for a reassuring house plan (-10 fray each)", "effect": {"target": "party", "candle": 0, "fray": -10, "gold": -16}},
			{"id": "lift_shadowed_map", "text": "Lift the shadowed weight (+23 gold, -10 candle, +7 fray each)", "effect": {"target": "party", "candle": -10, "fray": 7, "gold": 23}},
			{"id": "leave", "text": "Leave the black glass holding down the plan", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_cinder_brass_bedwarmer": {
		"title": "The Cinder-Brass Bedwarmer",
		"description": "A bedwarmer the size of a wagon glows behind a perforated brass lid; a soot-dark round ragdoll steadies its long wooden handle beside a threadbare carpet.",
		"choices": [
			{"id": "rent_ember_lid", "text": "Pay 11 gold to borrow glowing embers (+22 candle, +5 fray each)", "effect": {"target": "party", "candle": 22, "fray": 5, "gold": -11}},
			{"id": "sift_cooling_ashes", "text": "Let the embers cool and sift loose screws (+2 scraps, -12 candle, -6 fray each)", "effect": {"target": "party", "candle": -12, "fray": -6, "scraps": 2}},
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
