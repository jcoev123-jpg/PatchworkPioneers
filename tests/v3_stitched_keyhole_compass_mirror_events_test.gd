extends SceneTree
## Deterministic headless coverage for the three doll-scale Stitched roadside
## stories appended to the native route-effect catalog
## (res://data/events/stitched_route_effects.json): The Keyhole Choir, The
## Compass of Loose Ends and The Veiled Wardrobe Mirror.
##
## EXPECTED, FUNDED_FINAL, UNDERFUNDED, CANDLE_SHORTS, KEYHOLE_FULL and
## ANCHOR_TITLES are independent hardcoded copies of the authored stories and of
## the funded settlement oracle; they never read the production catalog or the
## consequence service back as their oracle. Only per-ID membership is asserted
## on the catalog: no catalog total, no full ordered ID list and no fixed
## insertion position, so peer batches can land in the same catalog without
## clashing. Every preview row and receipt is compared against an exact
## hardcoded dictionary, which also proves the ABSENCE of invented zero
## gold/scraps keys on the choices that do not carry them. No RNG is seeded or
## drawn by the rules under test; the fixed-seed guard only witnesses that.

const EVENTS_PATH := "res://data/events/stitched_route_effects.json"
const BASE_CANDLE := 40
const BASE_GOLD := 60
const BASE_SCRAPS := 4
const BASE_WREN_FEAR := 20
const PARTY_FRAYS := [["warden", 40], ["seamstress", 60], ["tinker", 20], ["yarn_ranger", 10]]
## A distinct four-hero party that swaps the Yarn Ranger for the Lantern Monk, so
## the canonical ranger gate is exercised without shrinking the party.
const PARTY_WITHOUT_RANGER := [["warden", 40], ["seamstress", 60], ["tinker", 20], ["lantern_monk", 10]]

## Independent literal copies of the three authored stories, including the exact
## signed stitched_effect fields.
const EXPECTED := {
	"v3_keyhole_choir": {
		"title": "The Keyhole Choir",
		"description": "A brass keyhole towers above the doll-sized skirting board. Three round, button-eyed singers sway behind its dark throat, and their humming makes the candle flame bow toward the door.",
		"choices": [
			{"id": "follow_humming", "text": "Follow the warm humming; mend the dolls, kindle the wick, strain their seams", "effect": {"target": "party", "candle": 16, "fray": 7, "hp": 5, "require_candle_room_or_wound": true}},
			{"id": "buy_silence", "text": "Spend scraps to quiet Wren and ease the dolls' seams", "effect": {"target": "party", "candle": 0, "fray": -12, "scraps": -2, "fear": -8, "require_fray_or_fear": true}},
			{"id": "leave", "text": "Leave the little choir singing behind the door", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_yarn_compass_spool": {
		"title": "The Compass of Loose Ends",
		"description": "A dinner-plate compass sits on a vast overturned spool. Its needle is a bent knitting pin, turning toward a knot that only the little hooded dolls seem able to read.",
		"choices": [
			{"id": "follow_yarn_bolas", "text": "Let the Yarn Ranger trace the knot (+2 scraps, -9 candle; requires Yarn Ranger)", "effect": {"target": "party", "candle": -9, "fray": 6, "scraps": 2, "required_hero": "yarn_ranger", "require_full_candle": true}},
			{"id": "buy_quiet_bearing", "text": "Trade gold for a quiet bearing to calm the dolls", "effect": {"target": "party", "candle": 0, "fray": -8, "gold": -10, "min_fray": 1}},
			{"id": "leave", "text": "Leave the needle turning in circles", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_veiled_wardrobe_mirror": {
		"title": "The Veiled Wardrobe Mirror",
		"description": "A wardrobe mirror looms like a silver wall. A small stitched doll in the glass wears a lace veil and copies every movement a heartbeat too late.",
		"choices": [
			{"id": "lift_silver_seam", "text": "Pry the silver seam for a rich purse; dim the wick and strain every doll", "effect": {"target": "party", "candle": -18, "fray": 15, "gold": 35, "require_full_candle": true, "min_active_heroes": 2}},
			{"id": "pin_lace_veil", "text": "Pin the veil back with a scrap to soothe the dolls", "effect": {"target": "party", "candle": 0, "fray": -9, "scraps": -1, "min_fray": 1}},
			{"id": "leave", "text": "Pass without looking into the silver again", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
}

## Independent funded oracle for the snapshot {candle 40, gold 60, scraps 4,
## frays warden 40 / seamstress 60 / tinker 20 / yarn_ranger 10}: the exact
## projected candle, the raw per-hero fray delta and the exact settled purse per
## choice, each row also carrying its own hardcoded authored deltas for an
## internal consistency check.
const FUNDED_FINAL := {
	"v3_keyhole_choir": {
		"follow_humming": {"candle": 56, "candle_delta": 16, "fray": 7, "hp": 5, "hp_delta": 5},
		"buy_silence": {"candle": 40, "candle_delta": 0, "fray": -12, "scraps": 2, "scraps_delta": -2, "fear": 12, "fear_delta": -8},
		"leave": {"candle": 40, "candle_delta": 0, "fray": 0},
	},
	"v3_yarn_compass_spool": {
		"follow_yarn_bolas": {"candle": 31, "candle_delta": -9, "fray": 6, "scraps": 6, "scraps_delta": 2},
		"buy_quiet_bearing": {"candle": 40, "candle_delta": 0, "fray": -8, "gold": 50, "gold_delta": -10},
		"leave": {"candle": 40, "candle_delta": 0, "fray": 0},
	},
	"v3_veiled_wardrobe_mirror": {
		"lift_silver_seam": {"candle": 22, "candle_delta": -18, "fray": 15, "gold": 95, "gold_delta": 35},
		"pin_lace_veil": {"candle": 40, "candle_delta": 0, "fray": -9, "scraps": 3, "scraps_delta": -1},
		"leave": {"candle": 40, "candle_delta": 0, "fray": 0},
	},
}

## One unit short of each paid price: only the paying purse is short, everything
## else stays funded, and the free alternative plus Leave stay selectable on the
## very same visit.
const UNDERFUNDED := {
	"v3_keyhole_choir": {
		"choice_id": "buy_silence", "gold": 60, "scraps": 1,
		"balance_key": "scraps", "balance": 1, "fray_delta": -12, "free_id": "follow_humming",
	},
	"v3_yarn_compass_spool": {
		"choice_id": "buy_quiet_bearing", "gold": 9, "scraps": 4,
		"balance_key": "gold", "balance": 9, "fray_delta": -8, "free_id": "follow_yarn_bolas",
	},
	"v3_veiled_wardrobe_mirror": {
		"choice_id": "pin_lace_veil", "gold": 60, "scraps": 0,
		"balance_key": "scraps", "balance": 0, "fray_delta": -9, "free_id": "lift_silver_seam",
	},
}

## Insufficient-candle witnesses for the two require_full_candle debits: one
## candle short is unavailable and refused; the exact price is claimable and
## leaves candle 0.
const CANDLE_SHORTS := [
	{
		"event_id": "v3_yarn_compass_spool",
		"choice_id": "follow_yarn_bolas",
		"short_candle": 8,
		"funded_candle": 9,
		"candle_delta": -9,
		"fray_delta": 6,
		"purse_key": "scraps",
		"purse_delta_key": "scraps_delta",
		"purse_base": BASE_SCRAPS,
		"purse_delta": 2,
	},
	{
		"event_id": "v3_veiled_wardrobe_mirror",
		"choice_id": "lift_silver_seam",
		"short_candle": 17,
		"funded_candle": 18,
		"candle_delta": -18,
		"fray_delta": 15,
		"purse_key": "gold",
		"purse_delta_key": "gold_delta",
		"purse_base": BASE_GOLD,
		"purse_delta": 35,
	},
]

## Earlier anchors that must remain in the catalog with their original titles.
const ANCHOR_TITLES := {
	"moth_infestation": "Moth Infestation",
	"dye_vat": "The Dye Vat",
	"frayed_debt_parcel": "Frayed Debt Parcel",
	"needle_toll": "The Needle Toll",
	"v3_glassfront_pin_cabinet": "The Glassfront Pin Cabinet",
	"v3_moonblack_paperweight": "The Moonblack Paperweight",
	"v3_cinder_brass_bedwarmer": "The Cinder-Brass Bedwarmer",
}

var failures: Array[String] = []
var checks := 0
var source_document: Dictionary = {}
var source_snapshot: Dictionary = {}
var source_by_id: Dictionary = {}
var source_counts: Dictionary = {}
var rng_guard: RandomNumberGenerator = null
var guard_state := 0


func _initialize() -> void:
	rng_guard = RandomNumberGenerator.new()
	rng_guard.seed = 5991794
	guard_state = rng_guard.state
	_load_source()
	if source_document.is_empty():
		_report()
		return
	_test_source_records()
	_test_anchor_records()
	_test_envelope_choices()
	_test_funded_contract()
	_test_underfunded_visits()
	_test_missing_yarn_ranger()
	_test_insufficient_candle_debits()
	_test_full_candle_keyhole()
	_test_unknown_choice_refusals()
	_test_stale_effect_fails()
	_test_compass_fray_gates()
	_test_paid_fray_relief_gates()
	_test_mirror_surviving_party_gate()
	_check(source_document == source_snapshot, "the catalog document is unchanged by every flow")
	var before_draw: int = rng_guard.state
	rng_guard.randi()
	_check(rng_guard.state != before_draw,
		"the fixed-seed RNG guard is live: an explicit draw advances its state")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_keyhole_compass_mirror_events_test: ",
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
			var rec_copy: Dictionary = (record as Dictionary).duplicate(true)
			for choice in rec_copy.get("choices", []):
				if choice is Dictionary and choice.has("stitched_effect") and choice["stitched_effect"] is Dictionary:
					var eff: Dictionary = choice["stitched_effect"]
					if eff.has("min_active_heroes") and typeof(eff["min_active_heroes"]) == TYPE_FLOAT and floor(eff["min_active_heroes"]) == eff["min_active_heroes"]:
						eff["min_active_heroes"] = int(eff["min_active_heroes"])
					if eff.has("fear") and typeof(eff["fear"]) == TYPE_FLOAT and floor(eff["fear"]) == eff["fear"]:
						eff["fear"] = int(eff["fear"])
			source_by_id[event_id] = rec_copy
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
			_check(false, "the authored record is present: " + event_id)
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
			_check(by_id.has(choice_id),
				"the record keeps its choice " + choice_id + ": " + event_id)
			if not by_id.has(choice_id):
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


## The named earlier anchors stay present with their original titles and choices.
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


## The shared envelope validator accepts every new record and each of its
## choices claims exactly once against a fresh instance.
func _test_envelope_choices() -> void:
	for event_id in EXPECTED:
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		_check(RunEventChoice.new(record).is_valid(),
			"the shipped envelope validator accepts the shipped record: " + event_id)
		var contract: Dictionary = EXPECTED[event_id]
		for choice_def in contract["choices"]:
			var choice_id: String = (choice_def as Dictionary)["id"]
			var envelope := RunEventChoice.new(record)
			_check(envelope.choose(choice_id) == {
				"ok": true, "event_id": event_id, "choice_id": choice_id,
			}, "the envelope claims its authored choice: " + event_id + " / " + choice_id)
			_check(envelope.is_claimed() and not envelope.is_valid(),
				"the envelope claim latches once: " + event_id + " / " + choice_id)
			_check(envelope.choose(choice_id) == {
				"ok": false, "event_id": "", "choice_id": "",
			}, "the envelope refuses a replay: " + event_id + " / " + choice_id)


## Funded previews and claims agree with the independent oracle on all nine
## choices; a settled visit cannot be replayed, previews close after the claim,
## and neither the caller snapshot nor the record is ever mutated.
func _test_funded_contract() -> void:
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var table: Dictionary = FUNDED_FINAL[event_id]
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
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
					"the funded gold agree with its hardcoded delta: " + event_id + " / " + choice_id)
			if row.has("fear"):
				_check(int(row["fear"]) == BASE_WREN_FEAR + int(row["fear_delta"]),
					"the funded fear agrees with its hardcoded delta: " + event_id + " / " + choice_id)
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
			_check(entry == _expected_entry(choice_id, row, PARTY_FRAYS),
				"funded preview matches the hardcoded oracle exactly: " + event_id + " / " + choice_id)
			var receipt: Dictionary = service.choose(choice_id, snapshot)
			_check(receipt == _expected_receipt(event_id, choice_id, row, PARTY_FRAYS),
				"funded claim settles the hardcoded oracle exactly: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches exactly once: " + event_id + " / " + choice_id)
			_check(service.choose(choice_id, snapshot) == _refusal(BASE_CANDLE),
				"a settled choice cannot be replayed: " + event_id + " / " + choice_id)
			_check(service.choose(_other_choice_id(contract, choice_id), snapshot) == _refusal(BASE_CANDLE),
				"no alternate choice claims a spent visit: " + event_id + " / " + choice_id)
			_check(service.preview(snapshot) == _denied_preview(),
				"a spent visit offers no further preview: " + event_id + " / " + choice_id)
			_check(snapshot == before and record == record_snapshot,
				"a funded flow mutates neither snapshot nor record: " + event_id + " / " + choice_id)
		_check(rng_guard.state == guard_state,
			"the funded flows never touch the fixed-seed RNG: " + event_id)
	_check(settlements == 9, "every one of the nine authored choices settles once when funded")


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
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		var preview: Dictionary = service.preview(snapshot)
		_check(preview.get("ok") == true,
			"an underfunded visit still previews: " + event_id)
		var paid := _entry(preview, paid_id)
		_check(not paid.is_empty(), "the underfunded paid choice keeps its slot: " + event_id)
		if paid.is_empty():
			continue
		_check(paid.get("available") == false and int(paid.get("candle")) == BASE_CANDLE
			and paid.get("fray") == {},
			"the underfunded paid choice is unavailable without projection: " + event_id)
		_check(int(paid.get("candle_delta")) == 0
			and int(paid.get("fray_delta")) == int(plan["fray_delta"]),
			"the unavailable paid choice still reports its authored deltas: " + event_id)
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
		_check(snapshot == before and record == record_snapshot,
			"a refused debit changes no balance and no record: " + event_id)
		_check(rng_guard.state == guard_state,
			"a refused debit draws no RNG: " + event_id)
		var leave: Dictionary = service.choose("leave", snapshot)
		_check(leave == _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"], PARTY_FRAYS),
			"Leave succeeds on the same visit after the refusal: " + event_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the post-refusal Leave claim latches once: " + event_id)
		_check(snapshot == before,
			"the underfunded flow mutates no balance at all: " + event_id)


## AC3: without the Yarn Ranger the compass's follow_yarn_bolas choice is
## hidden from preview and refused without latching, while its paid alternative
## and Leave remain; with the ranger in the party the same choice is available at
## candle 40 and carries its written effects.
func _test_missing_yarn_ranger() -> void:
	var event_id := "v3_yarn_compass_spool"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	var record_snapshot: Dictionary = record.duplicate(true)
	var snapshot := _snapshot(BASE_CANDLE, BASE_GOLD, BASE_SCRAPS, PARTY_WITHOUT_RANGER)
	var before: Dictionary = snapshot.duplicate(true)
	var service := RunStitchedEventConsequence.new(record)
	var preview: Dictionary = service.preview(snapshot)
	_check(preview.get("ok") == true and preview.get("event_id") == event_id,
		"the ranger-less compass visit still previews")
	_check(preview.get("choices", []).size() == 2,
		"the ranger-gated choice is hidden from the ranger-less preview")
	_check(_entry(preview, "follow_yarn_bolas").is_empty(),
		"the ranger-gated choice has no preview row at all")
	_check(_entry(preview, "buy_quiet_bearing") == {
		"choice_id": "buy_quiet_bearing", "target": "party", "hero_id": "",
		"candle_delta": 0, "fray_delta": -8, "available": true,
		"candle": BASE_CANDLE, "fray": _fray_map(PARTY_WITHOUT_RANGER, -8),
		"gold_delta": -10, "gold": BASE_GOLD - 10,
	}, "the paid alternative stays available and exact without the ranger")
	_check(_entry(preview, "leave") == {
		"choice_id": "leave", "target": "party", "hero_id": "",
		"candle_delta": 0, "fray_delta": 0, "available": true,
		"candle": BASE_CANDLE, "fray": {},
	}, "Leave stays available without the ranger")
	_check(service.choose("follow_yarn_bolas", snapshot) == _refusal(BASE_CANDLE),
		"the ranger-gated choice is strictly refused when the ranger is absent")
	_check(service.is_valid() and not service.is_claimed(),
		"the absent-hero refusal consumes no claim")
	_check(snapshot == before and record == record_snapshot,
		"the absent-hero refusal mutates no snapshot and no record")
	_check(rng_guard.state == guard_state,
		"the absent-hero refusal draws no RNG")
	var alternative: Dictionary = service.choose("buy_quiet_bearing", snapshot)
	_check(alternative == _expected_receipt(event_id, "buy_quiet_bearing",
		FUNDED_FINAL[event_id]["buy_quiet_bearing"], PARTY_WITHOUT_RANGER),
		"the paid alternative still commits once without the ranger")
	_check(service.is_claimed() and not service.is_valid(),
		"the ranger-less alternative claim latches once")

	var leave_service := RunStitchedEventConsequence.new(record)
	var leave_snapshot := _snapshot(BASE_CANDLE, BASE_GOLD, BASE_SCRAPS, PARTY_WITHOUT_RANGER)
	_check(leave_service.choose("follow_yarn_bolas", leave_snapshot) == _refusal(BASE_CANDLE),
		"the ranger-gated choice is refused on an independent ranger-less visit")
	_check(leave_service.choose("leave", leave_snapshot) == _expected_receipt(
		event_id, "leave", FUNDED_FINAL[event_id]["leave"], PARTY_WITHOUT_RANGER),
		"Leave still commits once on the ranger-less visit")

	var ranger_snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
	var ranger_before: Dictionary = ranger_snapshot.duplicate(true)
	var ranger_service := RunStitchedEventConsequence.new(record)
	var ranger_preview: Dictionary = ranger_service.preview(ranger_snapshot)
	_check(ranger_preview.get("choices", []).size() == 3,
		"the ranger-gated choice is available in a four-hero party")
	_check(_entry(ranger_preview, "follow_yarn_bolas") == _expected_entry(
		"follow_yarn_bolas", FUNDED_FINAL[event_id]["follow_yarn_bolas"], PARTY_FRAYS),
		"the ranger-gated choice quotes its full candle cost and written effects at candle 40")
	_check(ranger_snapshot == ranger_before,
		"the ranger-present preview mutates no snapshot")


## AC4 candle gate for the two require_full_candle debits: one candle short is
## unavailable and refused without consuming the visit, RNG or snapshot; the
## exact price claims and leaves candle 0; Leave still commits after a refusal.
func _test_insufficient_candle_debits() -> void:
	for witness in CANDLE_SHORTS:
		var event_id: String = witness["event_id"]
		var choice_id: String = witness["choice_id"]
		var short_candle: int = witness["short_candle"]
		var funded_candle: int = witness["funded_candle"]
		var candle_delta: int = witness["candle_delta"]
		var fray_delta: int = witness["fray_delta"]
		var purse_key: String = witness["purse_key"]
		var purse_delta_key: String = witness["purse_delta_key"]
		var purse_base: int = witness["purse_base"]
		var purse_delta: int = witness["purse_delta"]
		_check(funded_candle == -candle_delta,
			"the funded candle boundary is the exact authored price: " + event_id)

		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		var short_snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		short_snapshot["candle"] = short_candle
		var short_before: Dictionary = short_snapshot.duplicate(true)
		var short_service := RunStitchedEventConsequence.new(record)
		var short_preview: Dictionary = short_service.preview(short_snapshot)
		_check(short_preview.get("ok") == true and int(short_preview.get("candle")) == short_candle,
			"the short-candle visit previews: " + event_id)
		var short_entry := _entry(short_preview, choice_id)
		_check(not short_entry.is_empty(), "the short-candle choice keeps its slot: " + event_id)
		if short_entry.is_empty():
			continue
		_check(short_entry.get("available") == false
			and int(short_entry.get("candle")) == short_candle
			and int(short_entry.get("candle_delta")) == candle_delta
			and int(short_entry.get("fray_delta")) == fray_delta
			and short_entry.get("fray") == {}
			and int(short_entry.get(purse_key)) == purse_base
			and int(short_entry.get(purse_delta_key)) == purse_delta,
			"one candle short makes the debit unavailable with unchanged purse and empty fray: " + event_id)
		_check(_entry(short_preview, "leave").get("available") == true,
			"Leave stays available at the short candle: " + event_id)
		_check(short_service.choose(choice_id, short_snapshot) == _refusal(short_candle),
			"one candle short strictly refuses the debit: " + event_id)
		_check(short_service.is_valid() and not short_service.is_claimed(),
			"the short-candle refusal consumes no claim: " + event_id)
		_check(short_snapshot == short_before and record == record_snapshot,
			"the short-candle refusal mutates no snapshot and no record: " + event_id)
		_check(rng_guard.state == guard_state,
			"the short-candle refusal draws no RNG: " + event_id)
		var short_leave_expected := _expected_receipt(
			event_id, "leave", FUNDED_FINAL[event_id]["leave"], PARTY_FRAYS)
		short_leave_expected["candle"] = short_candle
		_check(short_service.choose("leave", short_snapshot) == short_leave_expected,
			"Leave still commits once after the short-candle refusal: " + event_id)
		var funded_snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		funded_snapshot["candle"] = funded_candle
		var funded_before: Dictionary = funded_snapshot.duplicate(true)
		var funded_service := RunStitchedEventConsequence.new(record)
		var funded_preview: Dictionary = funded_service.preview(funded_snapshot)
		var funded_entry := _entry(funded_preview, choice_id)
		_check(funded_entry.get("available") == true
			and int(funded_entry.get("candle")) == 0
			and int(funded_entry.get(purse_key)) == purse_base + purse_delta,
			"the exact candle price makes the debit available and leaves candle 0: " + event_id)
		var funded_receipt: Dictionary = funded_service.choose(choice_id, funded_snapshot)
		var expected := _expected_receipt(event_id, choice_id,
			FUNDED_FINAL[event_id][choice_id], PARTY_FRAYS)
		expected["candle"] = 0
		_check(funded_receipt == expected,
			"the exact candle price settles the hardcoded oracle at candle 0: " + event_id)
		_check(funded_service.choose(choice_id, funded_snapshot) == _refusal(funded_candle),
			"the funded candle claim cannot be replayed: " + event_id)
		_check(funded_snapshot == funded_before,
			"the funded candle claim mutates no caller snapshot: " + event_id)


## AC4 positive-candle gate: at candle 100 the keyhole's follow_humming choice is
## unavailable and refused (no claim, no mutation, no RNG draw) while its paid
## alternative and Leave stay claimable; at candle 99 it is available and clamps
## to 100.
func _test_full_candle_keyhole() -> void:
	var event_id := "v3_keyhole_choir"
	var choice_id := "follow_humming"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	var record_snapshot: Dictionary = record.duplicate(true)

	var snapshot_100 := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
	snapshot_100["candle"] = 100
	var before_100: Dictionary = snapshot_100.duplicate(true)
	var service_100 := RunStitchedEventConsequence.new(record)
	var preview_100: Dictionary = service_100.preview(snapshot_100)
	_check(preview_100.get("ok") == true and int(preview_100.get("candle")) == 100,
		"the full-candle keyhole visit previews")
	var entry_100 := _entry(preview_100, choice_id)
	_check(entry_100.get("available") == false
		and int(entry_100.get("candle")) == 100
		and int(entry_100.get("candle_delta")) == 16
		and int(entry_100.get("fray_delta")) == 7
		and entry_100.get("fray") == {},
		"a full candle quotes follow_humming unavailable with its authored deltas and empty fray")
	_check(_entry(preview_100, "buy_silence").get("available") == true,
		"buy_silence stays available at a full candle")
	_check(_entry(preview_100, "leave").get("available") == true,
		"Leave stays available at a full candle")
	_check(service_100.choose(choice_id, snapshot_100) == _refusal(100),
		"follow_humming is strictly refused at a full candle")
	_check(service_100.is_valid() and not service_100.is_claimed(),
		"the full-candle refusal consumes no claim")
	_check(snapshot_100 == before_100 and record == record_snapshot,
		"the full-candle refusal mutates no snapshot and no record")
	_check(rng_guard.state == guard_state,
		"the full-candle refusal draws no RNG")
	var full_alt_expected := _expected_receipt(
		event_id, "buy_silence", FUNDED_FINAL[event_id]["buy_silence"], PARTY_FRAYS)
	full_alt_expected["candle"] = 100
	_check(service_100.choose("buy_silence", snapshot_100) == full_alt_expected,
		"the paid alternative still commits once after the full-candle refusal")
	_check(service_100.is_claimed() and not service_100.is_valid(),
		"the post-refusal alternative claim latches once")

	var leave_service := RunStitchedEventConsequence.new(record)
	var leave_snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
	leave_snapshot["candle"] = 100
	_check(leave_service.choose(choice_id, leave_snapshot) == _refusal(100),
		"follow_humming is refused on an independent full-candle visit")
	var leave_receipt: Dictionary = leave_service.choose("leave", leave_snapshot)
	_check(leave_receipt == {
		"ok": true, "event_id": event_id, "choice_id": "leave",
		"target": "party", "hero_id": "", "candle": 100, "fray": {},
	}, "Leave settles its minimal receipt at a full candle")

	var snapshot_99 := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
	snapshot_99["candle"] = 99
	var before_99: Dictionary = snapshot_99.duplicate(true)
	var service_99 := RunStitchedEventConsequence.new(record)
	var entry_99 := _entry(service_99.preview(snapshot_99), choice_id)
	_check(entry_99.get("available") == true
		and int(entry_99.get("candle")) == 100
		and entry_99.get("fray") == _fray_map(PARTY_FRAYS, 7),
		"candle 99 quotes follow_humming available, clamped to candle 100, fray +7 each")
	var receipt_99: Dictionary = service_99.choose(choice_id, snapshot_99)
	_check(receipt_99 == {
		"ok": true, "event_id": event_id, "choice_id": choice_id,
		"target": "party", "hero_id": "", "candle": 100,
		"fray": _fray_map(PARTY_FRAYS, 7),
		"hp_delta": 5,
		"hp": _fray_map(PARTY_FRAYS, 5),
	}, "candle 99 claims follow_humming settling the clamped candle 100 and its minimal receipt")
	_check(service_99.is_claimed() and not service_99.is_valid(),
		"the near-full claim latches once")
	_check(snapshot_99 == before_99,
		"the near-full claim mutates no caller snapshot")


## An unknown choice ID is refused without a claim and Leave then succeeds on
## the same visit.
func _test_unknown_choice_refusals() -> void:
	for event_id in EXPECTED:
		var snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(
			(source_by_id[event_id] as Dictionary).duplicate(true))
		_check(service.choose("forged_choice", snapshot) == _refusal(BASE_CANDLE),
			"an unknown choice ID is refused: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"an unknown choice keeps the visit open: " + event_id)
		var leave: Dictionary = service.choose("leave", snapshot)
		_check(leave == _expected_receipt(event_id, "leave",
			FUNDED_FINAL[event_id]["leave"], PARTY_FRAYS),
			"Leave succeeds after the forged refusal: " + event_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the post-forged Leave claim latches once: " + event_id)
		_check(snapshot == before,
			"forged-ID flows mutate no snapshot: " + event_id)


## A new choice carrying an unsupported extra effect key stays envelope-valid but
## can never settle: no preview availability, no receipt, no claim consumed.
func _test_stale_effect_fails() -> void:
	for event_id in EXPECTED:
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var choices: Array = record["choices"]
		var stale: Dictionary = choices[0]
		var choice_id: String = stale["id"]
		stale["outcome"] = {"gold": 1, "scraps": 1}
		var snapshot := _funded_snapshot(BASE_GOLD, BASE_SCRAPS)
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		_check(service.is_valid(), "a stale choice keeps the shared envelope valid: " + event_id)
		var entry := _entry(service.preview(snapshot), choice_id)
		_check(entry.get("available") == false and entry.get("candle_delta") == null
			and entry.get("fray_delta") == null,
			"an unsupported extra effect key makes the choice unsettleable: " + event_id)
		_check(service.choose(choice_id, snapshot) == _refusal(BASE_CANDLE),
			"an unsupported effect is refused without a receipt: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"the stale effect consumes no claim: " + event_id)
		_check(snapshot == before,
			"the stale-effect flow mutates no snapshot: " + event_id)
		_check(service.choose("leave", snapshot).get("ok") == true,
			"Leave still commits after a stale-effect refusal: " + event_id)


## AC2 / AC3: Compass of Loose Ends min_fray gate on buy_quiet_bearing.
## Fixture A: living dolls all at fray 0 -> buy choice unavailable / hidden from available choices, choose refused.
## Fixture B: only a LOST doll has positive fray -> refused the same way.
## Fixture C: one living doll at fray 1, gold 10 -> paid choice available, commits -10 gold, -8 fray each once.
## Fixture D: gold 9, fray positive -> choice unavailable, Leave preserved.
func _test_compass_fray_gates() -> void:
	var event_id := "v3_yarn_compass_spool"
	var choice_id := "buy_quiet_bearing"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	var record_snapshot: Dictionary = record.duplicate(true)

	# --- Fixture A: four distinct valid living heroes (including yarn_ranger), gold 10, candle 40, every living fray 0 ---
	var snap_a := {
		"candle": 40,
		"gold": 10,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 0},
			{"id": "seamstress", "fray": 0},
			{"id": "tinker", "fray": 0},
			{"id": "yarn_ranger", "fray": 0},
		],
	}
	var before_a: Dictionary = snap_a.duplicate(true)
	var svc_a := RunStitchedEventConsequence.new(record)
	var prev_a: Dictionary = svc_a.preview(snap_a)
	_check(prev_a.get("ok") == true and prev_a.get("event_id") == event_id,
		"Fixture A: zero living fray compass visit previews")
	var buy_a := _entry(prev_a, choice_id)
	_check(buy_a.is_empty() or buy_a.get("available") == false,
		"Fixture A: buy choice hidden or unavailable when living fray is zero")
	if not buy_a.is_empty():
		_check(buy_a.get("available") == false
			and buy_a.get("fray") == {}
			and int(buy_a.get("candle")) == 40
			and int(buy_a.get("gold")) == 10
			and int(buy_a.get("candle_delta")) == 0
			and int(buy_a.get("fray_delta")) == -8
			and int(buy_a.get("gold_delta")) == -10,
			"Fixture A: unavailable buy choice quotes caller state, empty fray map, and deltas")
	_check(_entry(prev_a, "follow_yarn_bolas").get("available") == true,
		"Fixture A: follow_yarn_bolas remains available with yarn_ranger and sufficient candle")
	_check(_entry(prev_a, "leave").get("available") == true,
		"Fixture A: leave remains available")
	_check(svc_a.choose(choice_id, snap_a) == _refusal(40),
		"Fixture A: direct choose refused without spend when living fray is zero")
	_check(svc_a.is_valid() and not svc_a.is_claimed(),
		"Fixture A: refused choose does not latch the visit")
	_check(snap_a == before_a and record == record_snapshot,
		"Fixture A: refused choose mutates no snapshot and no record")
	_check(rng_guard.state == guard_state,
		"Fixture A: refused choose draws no RNG")
	# follow_yarn_bolas remains claimable on the same visit
	var bolas_rec: Dictionary = svc_a.choose("follow_yarn_bolas", snap_a)
	_check(bolas_rec.get("ok") == true
		and bolas_rec.get("choice_id") == "follow_yarn_bolas"
		and int(bolas_rec.get("candle")) == 31
		and int(bolas_rec.get("scraps")) == 6
		and bolas_rec.get("fray") == {"warden": 6, "seamstress": 6, "tinker": 6, "yarn_ranger": 6},
		"Fixture A: follow_yarn_bolas settles after buy refusal")
	_check(svc_a.is_claimed() and not svc_a.is_valid(),
		"Fixture A: follow_yarn_bolas claim latches once")

	# Fixture A Leave alternative on independent visit:
	var svc_a_leave := RunStitchedEventConsequence.new(record)
	_check(svc_a_leave.choose(choice_id, snap_a) == _refusal(40),
		"Fixture A: choose refused on independent visit")
	var leave_a_rec: Dictionary = svc_a_leave.choose("leave", snap_a)
	_check(leave_a_rec.get("ok") == true
		and leave_a_rec.get("choice_id") == "leave"
		and int(leave_a_rec.get("candle")) == 40
		and leave_a_rec.get("fray") == {},
		"Fixture A: leave settles on independent visit after buy refusal")
	_check(svc_a_leave.is_claimed() and not svc_a_leave.is_valid(),
		"Fixture A: leave claim latches once")

	# --- Fixture B: only a LOST hero has positive fray ---
	var snap_b := {
		"candle": 40,
		"gold": 10,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 40, "lost": true},
			{"id": "seamstress", "fray": 0},
			{"id": "tinker", "fray": 0},
			{"id": "yarn_ranger", "fray": 0},
		],
	}
	var before_b: Dictionary = snap_b.duplicate(true)
	var svc_b := RunStitchedEventConsequence.new(record)
	var prev_b: Dictionary = svc_b.preview(snap_b)
	_check(prev_b.get("ok") == true, "Fixture B: only-lost-fray compass visit previews")
	var buy_b := _entry(prev_b, choice_id)
	_check(buy_b.is_empty() or buy_b.get("available") == false,
		"Fixture B: buy choice hidden or unavailable when only lost hero has fray")
	if not buy_b.is_empty():
		_check(buy_b.get("available") == false and buy_b.get("fray") == {},
			"Fixture B: unavailable buy choice projects empty fray")
	_check(_entry(prev_b, "follow_yarn_bolas").get("available") == true,
		"Fixture B: follow_yarn_bolas remains available")
	_check(_entry(prev_b, "leave").get("available") == true,
		"Fixture B: leave remains available")
	_check(svc_b.choose(choice_id, snap_b) == _refusal(40),
		"Fixture B: direct choose refused when only lost hero has positive fray")
	_check(svc_b.is_valid() and not svc_b.is_claimed(),
		"Fixture B: refused choose leaves visit unclaimed and valid")
	_check(snap_b == before_b and record == record_snapshot,
		"Fixture B: refused choose mutates no snapshot or record")
	_check(rng_guard.state == guard_state,
		"Fixture B: refused choose draws no RNG")
	var leave_b_rec: Dictionary = svc_b.choose("leave", snap_b)
	_check(leave_b_rec.get("ok") == true and leave_b_rec.get("choice_id") == "leave",
		"Fixture B: leave succeeds after buy refusal")
	_check(svc_b.is_claimed() and not svc_b.is_valid(),
		"Fixture B: leave claim latches once")

	# --- Fixture C: one living doll fray 1 (others 0), gold 10 ---
	var snap_c := {
		"candle": 40,
		"gold": 10,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 1},
			{"id": "seamstress", "fray": 0},
			{"id": "tinker", "fray": 0},
			{"id": "yarn_ranger", "fray": 0},
		],
	}
	var before_c: Dictionary = snap_c.duplicate(true)
	var svc_c := RunStitchedEventConsequence.new(record)
	var prev_c: Dictionary = svc_c.preview(snap_c)
	_check(prev_c.get("ok") == true, "Fixture C: single living fray 1 visit previews")
	var buy_c := _entry(prev_c, choice_id)
	_check(not buy_c.is_empty() and buy_c.get("available") == true,
		"Fixture C: paid choice exists and is available with one living doll at fray 1")
	var expected_fray_c := {
		"warden": -8, "seamstress": -8, "tinker": -8, "yarn_ranger": -8,
	}
	_check(int(buy_c.get("candle")) == 40
		and int(buy_c.get("candle_delta")) == 0
		and int(buy_c.get("fray_delta")) == -8
		and int(buy_c.get("gold")) == 0
		and int(buy_c.get("gold_delta")) == -10
		and buy_c.get("fray") == expected_fray_c,
		"Fixture C: preview projects 0 gold, 40 candle, and -8 party fray intent each")
	var rec_c: Dictionary = svc_c.choose(choice_id, snap_c)
	_check(rec_c == {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": 40,
		"fray": expected_fray_c,
		"gold_delta": -10,
		"gold": 0,
	}, "Fixture C: paid choice commits a -10 gold / -8 party fray intent once")
	_check(not rec_c.has("scraps") and not rec_c.has("scraps_delta")
		and not rec_c.has("hp") and not rec_c.has("hp_delta")
		and not rec_c.has("fear") and not rec_c.has("fear_delta")
		and not rec_c.has("part"),
		"Fixture C: omission of nonexistent zero/bonus keys on paid receipt")
	_check(svc_c.is_claimed() and not svc_c.is_valid(),
		"Fixture C: paid claim latches once")
	_check(svc_c.choose(choice_id, snap_c) == _refusal(40),
		"Fixture C: replay after claim is refused")
	_check(svc_c.choose("leave", snap_c) == _refusal(40),
		"Fixture C: alternate choice after claim is refused")
	_check(snap_c == before_c and record == record_snapshot,
		"Fixture C: flow mutates no caller snapshot or record")
	_check(rng_guard.state == guard_state,
		"Fixture C: flow draws no RNG")

	# Fixture C replay check: fresh instance with identical snapshot yields identical preview and receipt
	var svc_c_replay := RunStitchedEventConsequence.new(record)
	var prev_c_replay: Dictionary = svc_c_replay.preview(snap_c)
	var rec_c_replay: Dictionary = svc_c_replay.choose(choice_id, snap_c)
	_check(prev_c_replay == prev_c, "Fixture C: deterministic replay preview matches")
	_check(rec_c_replay == rec_c, "Fixture C: deterministic replay receipt matches")

	# --- Fixture D: gold 9, fray positive ---
	var snap_d := {
		"candle": 40,
		"gold": 9,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 10},
			{"id": "seamstress", "fray": 5},
			{"id": "tinker", "fray": 2},
			{"id": "yarn_ranger", "fray": 1},
		],
	}
	var before_d: Dictionary = snap_d.duplicate(true)
	var svc_d := RunStitchedEventConsequence.new(record)
	var prev_d: Dictionary = svc_d.preview(snap_d)
	_check(prev_d.get("ok") == true, "Fixture D: gold 9 visit previews")
	var buy_d := _entry(prev_d, choice_id)
	_check(not buy_d.is_empty() and buy_d.get("available") == false,
		"Fixture D: with 9 gold and positive fray, choice is unavailable")
	_check(int(buy_d.get("candle")) == 40
		and int(buy_d.get("gold")) == 9
		and int(buy_d.get("gold_delta")) == -10
		and int(buy_d.get("fray_delta")) == -8
		and buy_d.get("fray") == {},
		"Fixture D: unavailable choice quotes caller gold 9 and empty fray projection")
	_check(_entry(prev_d, "leave").get("available") == true,
		"Fixture D: leave stays available")
	_check(_entry(prev_d, "follow_yarn_bolas").get("available") == true,
		"Fixture D: follow_yarn_bolas stays available")
	_check(svc_d.choose(choice_id, snap_d) == _refusal(40),
		"Fixture D: underfunded choice refused without latching")
	_check(svc_d.is_valid() and not svc_d.is_claimed(),
		"Fixture D: refused choose leaves service valid and unclaimed")
	_check(snap_d == before_d and record == record_snapshot,
		"Fixture D: refused choose mutates no snapshot or record")
	_check(rng_guard.state == guard_state,
		"Fixture D: refused choose draws no RNG")
	var leave_d_rec: Dictionary = svc_d.choose("leave", snap_d)
	_check(leave_d_rec.get("ok") == true
		and leave_d_rec.get("choice_id") == "leave"
		and int(leave_d_rec.get("candle")) == 40
		and leave_d_rec.get("fray") == {},
		"Fixture D: leave preserved and succeeds on the same visit")
	_check(not leave_d_rec.has("gold") and not leave_d_rec.has("gold_delta")
		and not leave_d_rec.has("scraps") and not leave_d_rec.has("scraps_delta"),
		"Fixture D: omission of nonexistent zero keys on Leave receipt")
	_check(svc_d.is_claimed() and not svc_d.is_valid(),
		"Fixture D: leave latches once")


## AC2 / AC3: Keyhole Choir (buy_silence) and Veiled Wardrobe Mirror (pin_lace_veil)
## min_fray gates on scrap-paid party fray relief.
## 1. Living dolls all at fray 0 -> choice unavailable, deltas present, choose refused without spend.
## 2. Only a LOST doll has positive fray -> refused the same way.
## 3. One living doll at fray 1 -> choice available, commits scrap price and -12 / -9 raw fray intent once.
## 4. One living doll at fray 1 with a LOST doll in the party -> LOST doll excluded from fray intent map.
## 5. Underfunded with positive living fray -> choice unavailable, choose refused, Leave preserved.
func _test_paid_fray_relief_gates() -> void:
	var cases := [
		{
			"event_id": "v3_keyhole_choir",
			"choice_id": "buy_silence",
			"other_choice_id": "follow_humming",
			"price": 2,
			"settled_scraps": 2,
			"fray_delta": -12,
			"underfunded_scraps": 1,
			"has_fear": true,
			"fear_delta": -8,
		},
		{
			"event_id": "v3_veiled_wardrobe_mirror",
			"choice_id": "pin_lace_veil",
			"other_choice_id": "lift_silver_seam",
			"price": 1,
			"settled_scraps": 3,
			"fray_delta": -9,
			"underfunded_scraps": 0,
			"has_fear": false,
		},
	]

	for tc in cases:
		var event_id: String = tc["event_id"]
		var choice_id: String = tc["choice_id"]
		var other_id: String = tc["other_choice_id"]
		var price: int = tc["price"]
		var settled_scraps: int = tc["settled_scraps"]
		var fray_delta: int = tc["fray_delta"]
		var underfunded_scraps: int = tc["underfunded_scraps"]
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)

		# 1. All-calm: 4 active non-LOST heroes at fray 0, scraps 4, candle 40
		var snap_calm := {
			"candle": 40,
			"gold": 60,
			"scraps": 4,
			"wren_fear": 0,
			"party": [
				{"id": "warden", "fray": 0},
				{"id": "seamstress", "fray": 0},
				{"id": "tinker", "fray": 0},
				{"id": "yarn_ranger", "fray": 0},
			],
		}
		var before_calm: Dictionary = snap_calm.duplicate(true)
		var svc_calm := RunStitchedEventConsequence.new(record)
		var prev_calm: Dictionary = svc_calm.preview(snap_calm)
		_check(prev_calm.get("ok") == true and prev_calm.get("event_id") == event_id,
			"all-calm visit previews: " + event_id)
		var calm_entry := _entry(prev_calm, choice_id)
		_check(not calm_entry.is_empty() and calm_entry.get("available") == false,
			"all-calm paid relief choice unavailable: " + event_id + " / " + choice_id)
		_check(calm_entry.get("fray") == {}
			and int(calm_entry.get("candle")) == 40
			and int(calm_entry.get("scraps")) == 4
			and int(calm_entry.get("candle_delta")) == 0
			and int(calm_entry.get("fray_delta")) == fray_delta
			and int(calm_entry.get("scraps_delta")) == -price,
			"all-calm unavailable choice quotes original scraps, empty fray map, and deltas: " + event_id)
		_check(_entry(prev_calm, other_id).get("available") == true,
			"all-calm other lawful choice stays available: " + event_id + " / " + other_id)
		_check(_entry(prev_calm, "leave").get("available") == true,
			"all-calm Leave stays available: " + event_id)
		_check(svc_calm.choose(choice_id, snap_calm) == _refusal(40),
			"all-calm direct choose refused: " + event_id + " / " + choice_id)
		_check(svc_calm.is_valid() and not svc_calm.is_claimed(),
			"all-calm refused choose keeps visit open and unclaimed: " + event_id)
		_check(snap_calm == before_calm and record == record_snapshot,
			"all-calm refused choose mutates no snapshot or record: " + event_id)
		_check(rng_guard.state == guard_state,
			"all-calm refused choose draws no RNG: " + event_id)

		# Alternate choice claims on same visit after refusal:
		var alt_receipt: Dictionary = svc_calm.choose(other_id, snap_calm)
		_check(alt_receipt.get("ok") == true and alt_receipt.get("choice_id") == other_id,
			"other choice succeeds after refusal on same visit: " + event_id + " / " + other_id)
		_check(svc_calm.is_claimed() and not svc_calm.is_valid(),
			"other choice claim latches once: " + event_id)

		# Leave succeeds on independent all-calm visit after refusal:
		var svc_calm_leave := RunStitchedEventConsequence.new(record)
		var snap_calm_2 := snap_calm.duplicate(true)
		_check(svc_calm_leave.choose(choice_id, snap_calm_2) == _refusal(40),
			"independent all-calm choose refused: " + event_id)
		var leave_calm_rec: Dictionary = svc_calm_leave.choose("leave", snap_calm_2)
		_check(leave_calm_rec.get("ok") == true and leave_calm_rec.get("choice_id") == "leave"
			and int(leave_calm_rec.get("candle")) == 40 and leave_calm_rec.get("fray") == {},
			"Leave settles after refusal on independent all-calm visit: " + event_id)
		_check(svc_calm_leave.is_claimed() and not svc_calm_leave.is_valid(),
			"Leave claim latches once: " + event_id)

		# 2. Only a LOST hero has positive fray
		var snap_lost := {
			"candle": 40,
			"gold": 60,
			"scraps": 4,
			"wren_fear": 0,
			"party": [
				{"id": "warden", "fray": 40, "lost": true},
				{"id": "seamstress", "fray": 0},
				{"id": "tinker", "fray": 0},
				{"id": "yarn_ranger", "fray": 0},
			],
		}
		var before_lost: Dictionary = snap_lost.duplicate(true)
		var svc_lost := RunStitchedEventConsequence.new(record)
		var prev_lost: Dictionary = svc_lost.preview(snap_lost)
		_check(prev_lost.get("ok") == true, "only-lost-fray visit previews: " + event_id)
		var lost_entry := _entry(prev_lost, choice_id)
		_check(not lost_entry.is_empty() and lost_entry.get("available") == false,
			"only-lost-fray choice unavailable: " + event_id)
		_check(lost_entry.get("fray") == {} and int(lost_entry.get("scraps")) == 4,
			"only-lost-fray choice quotes original scraps and empty fray: " + event_id)
		_check(svc_lost.choose(choice_id, snap_lost) == _refusal(40),
			"only-lost-fray direct choose refused: " + event_id)
		_check(svc_lost.is_valid() and not svc_lost.is_claimed(),
			"only-lost-fray refused choose keeps visit open: " + event_id)
		_check(snap_lost == before_lost and record == record_snapshot,
			"only-lost-fray refused choose mutates no snapshot or record: " + event_id)
		_check(rng_guard.state == guard_state,
			"only-lost-fray refused choose draws no RNG: " + event_id)
		var leave_lost_rec: Dictionary = svc_lost.choose("leave", snap_lost)
		_check(leave_lost_rec.get("ok") == true and leave_lost_rec.get("choice_id") == "leave",
			"Leave succeeds after only-lost-fray refusal: " + event_id)
		_check(svc_lost.is_claimed() and not svc_lost.is_valid(),
			"post-refusal Leave latches once: " + event_id)

		# 3. One living frayed hero (warden fray 1, others 0)
		var snap_frayed := {
			"candle": 40,
			"gold": 60,
			"scraps": 4,
			"wren_fear": 0,
			"party": [
				{"id": "warden", "fray": 1},
				{"id": "seamstress", "fray": 0},
				{"id": "tinker", "fray": 0},
				{"id": "yarn_ranger", "fray": 0},
			],
		}
		var before_frayed: Dictionary = snap_frayed.duplicate(true)
		var svc_frayed := RunStitchedEventConsequence.new(record)
		var prev_frayed: Dictionary = svc_frayed.preview(snap_frayed)
		_check(prev_frayed.get("ok") == true, "one-living-frayed visit previews: " + event_id)
		var frayed_entry := _entry(prev_frayed, choice_id)
		_check(not frayed_entry.is_empty() and frayed_entry.get("available") == true,
			"one-living-frayed choice is available: " + event_id)
		var expected_fray_map := {
			"warden": fray_delta,
			"seamstress": fray_delta,
			"tinker": fray_delta,
			"yarn_ranger": fray_delta,
		}
		_check(int(frayed_entry.get("candle")) == 40
			and int(frayed_entry.get("candle_delta")) == 0
			and int(frayed_entry.get("fray_delta")) == fray_delta
			and int(frayed_entry.get("scraps")) == settled_scraps
			and int(frayed_entry.get("scraps_delta")) == -price
			and frayed_entry.get("fray") == expected_fray_map,
			"one-living-frayed preview quotes settled scraps and -12/-9 raw fray intents: " + event_id)
		if tc.get("has_fear", false):
			_check(int(frayed_entry.get("fear")) == 0
				and int(frayed_entry.get("fear_delta")) == tc["fear_delta"],
				"one-living-frayed preview quotes clamped fear 0 and delta: " + event_id)
		var expected_claim := {
			"ok": true,
			"event_id": event_id,
			"choice_id": choice_id,
			"target": "party",
			"hero_id": "",
			"candle": 40,
			"fray": expected_fray_map,
			"scraps_delta": -price,
			"scraps": settled_scraps,
		}
		if tc.get("has_fear", false):
			expected_claim["fear_delta"] = tc["fear_delta"]
			expected_claim["fear"] = 0
		var claim_rec: Dictionary = svc_frayed.choose(choice_id, snap_frayed)
		_check(claim_rec == expected_claim, "one-living-frayed claim settles exact raw fray map and scraps: " + event_id)
		if tc.get("has_fear", false):
			_check(not claim_rec.has("gold") and not claim_rec.has("gold_delta")
				and not claim_rec.has("hp") and not claim_rec.has("hp_delta")
				and not claim_rec.has("part")
				and claim_rec.has("fear") and claim_rec.has("fear_delta"),
				"claim receipt carries fear keys and omits nonexistent keys: " + event_id)
		else:
			_check(not claim_rec.has("gold") and not claim_rec.has("gold_delta")
				and not claim_rec.has("hp") and not claim_rec.has("hp_delta")
				and not claim_rec.has("fear") and not claim_rec.has("fear_delta")
				and not claim_rec.has("part"),
				"claim receipt omits nonexistent keys: " + event_id)
		_check(svc_frayed.is_claimed() and not svc_frayed.is_valid(),
			"claim latches exactly once: " + event_id)
		_check(svc_frayed.choose(choice_id, snap_frayed) == _refusal(40),
			"replay after claim is refused: " + event_id)
		_check(svc_frayed.choose("leave", snap_frayed) == _refusal(40),
			"alternate choice after claim is refused: " + event_id)
		_check(svc_frayed.preview(snap_frayed) == _denied_preview(),
			"spent visit offers no preview: " + event_id)
		_check(snap_frayed == before_frayed and record == record_snapshot,
			"claim flow mutates no caller snapshot or record: " + event_id)
		_check(rng_guard.state == guard_state,
			"claim flow draws no RNG: " + event_id)

		# AC1: Living dolls all at fray 0, Wren fear 8, scraps 4 -> bargain admitted, settles fear 0, fray -12 each, scraps 2
		if tc.get("has_fear", false):
			var snap_ac1 := {
				"candle": 40,
				"gold": 60,
				"scraps": 4,
				"wren_fear": 8,
				"party": [
					{"id": "warden", "fray": 0},
					{"id": "seamstress", "fray": 0},
					{"id": "tinker", "fray": 0},
					{"id": "yarn_ranger", "fray": 0},
				],
			}
			var before_ac1: Dictionary = snap_ac1.duplicate(true)
			var svc_ac1 := RunStitchedEventConsequence.new(record)
			var prev_ac1: Dictionary = svc_ac1.preview(snap_ac1)
			_check(prev_ac1.get("ok") == true, "AC1: living fray 0 with Wren fear 8 visit previews: " + event_id)
			var ac1_entry := _entry(prev_ac1, choice_id)
			_check(not ac1_entry.is_empty() and ac1_entry.get("available") == true,
				"AC1: living fray 0 with Wren fear 8 choice is available: " + event_id)
			_check(int(ac1_entry.get("candle")) == 40
				and int(ac1_entry.get("candle_delta")) == 0
				and int(ac1_entry.get("fray_delta")) == fray_delta
				and int(ac1_entry.get("scraps")) == settled_scraps
				and int(ac1_entry.get("scraps_delta")) == -price
				and int(ac1_entry.get("fear")) == 0
				and int(ac1_entry.get("fear_delta")) == tc["fear_delta"]
				and ac1_entry.get("fray") == expected_fray_map,
				"AC1: preview quotes settled scraps, fear 0, and raw -12 fray intents: " + event_id)
			var rec_ac1: Dictionary = svc_ac1.choose(choice_id, snap_ac1)
			_check(rec_ac1 == {
				"ok": true,
				"event_id": event_id,
				"choice_id": choice_id,
				"target": "party",
				"hero_id": "",
				"candle": 40,
				"fray": expected_fray_map,
				"scraps_delta": -price,
				"scraps": settled_scraps,
				"fear_delta": tc["fear_delta"],
				"fear": 0,
			}, "AC1: choose settles Wren fear to 0 plus raw -12 fray intents and scraps 2: " + event_id)
			_check(snap_ac1 == before_ac1 and record == record_snapshot,
				"AC1: flow mutates no caller snapshot or record: " + event_id)

		# Deterministic replay check
		var svc_replay := RunStitchedEventConsequence.new(record)
		_check(svc_replay.preview(snap_frayed) == prev_frayed,
			"deterministic replay preview matches: " + event_id)
		_check(svc_replay.choose(choice_id, snap_frayed) == claim_rec,
			"deterministic replay receipt matches: " + event_id)

		# 4. Living frayed hero with a LOST hero in the party (never target LOST hero)
		var snap_with_lost := {
			"candle": 40,
			"gold": 60,
			"scraps": 4,
			"wren_fear": 0,
			"party": [
				{"id": "warden", "fray": 1},
				{"id": "seamstress", "fray": 0},
				{"id": "tinker", "fray": 0},
				{"id": "yarn_ranger", "fray": 30, "lost": true},
			],
		}
		var svc_with_lost := RunStitchedEventConsequence.new(record)
		var prev_with_lost: Dictionary = svc_with_lost.preview(snap_with_lost)
		var entry_with_lost := _entry(prev_with_lost, choice_id)
		_check(not entry_with_lost.is_empty() and entry_with_lost.get("available") == true,
			"living frayed with lost hero choice is available: " + event_id)
		var expected_fray_living_only := {
			"warden": fray_delta,
			"seamstress": fray_delta,
			"tinker": fray_delta,
		}
		_check(entry_with_lost.get("fray") == expected_fray_living_only,
			"preview never emits fray intent for LOST hero: " + event_id)
		var rec_with_lost: Dictionary = svc_with_lost.choose(choice_id, snap_with_lost)
		var expected_rec_with_lost := {
			"ok": true,
			"event_id": event_id,
			"choice_id": choice_id,
			"target": "party",
			"hero_id": "",
			"candle": 40,
			"fray": expected_fray_living_only,
			"scraps_delta": -price,
			"scraps": settled_scraps,
		}
		if tc.get("has_fear", false):
			expected_rec_with_lost["fear_delta"] = tc["fear_delta"]
			expected_rec_with_lost["fear"] = 0
		_check(rec_with_lost == expected_rec_with_lost,
			"receipt matches expected settled state without LOST hero: " + event_id)
		_check(not (rec_with_lost.get("fray") as Dictionary).has("yarn_ranger"),
			"LOST hero absent from settled fray map: " + event_id)

		# 5. Underfunded with living fray positive
		var snap_under := {
			"candle": 40,
			"gold": 60,
			"scraps": underfunded_scraps,
			"wren_fear": 0,
			"party": [
				{"id": "warden", "fray": 1},
				{"id": "seamstress", "fray": 0},
				{"id": "tinker", "fray": 0},
				{"id": "yarn_ranger", "fray": 0},
			],
		}
		var before_under: Dictionary = snap_under.duplicate(true)
		var svc_under := RunStitchedEventConsequence.new(record)
		var prev_under: Dictionary = svc_under.preview(snap_under)
		_check(prev_under.get("ok") == true, "underfunded visit previews: " + event_id)
		var under_entry := _entry(prev_under, choice_id)
		_check(not under_entry.is_empty() and under_entry.get("available") == false,
			"underfunded choice unavailable: " + event_id)
		_check(under_entry.get("fray") == {}
			and int(under_entry.get("scraps")) == underfunded_scraps
			and int(under_entry.get("scraps_delta")) == -price
			and int(under_entry.get("fray_delta")) == fray_delta,
			"underfunded choice quotes caller balance and empty fray: " + event_id)
		_check(_entry(prev_under, "leave").get("available") == true,
			"underfunded Leave stays available: " + event_id)
		_check(svc_under.choose(choice_id, snap_under) == _refusal(40),
			"underfunded choice refused: " + event_id)
		_check(svc_under.is_valid() and not svc_under.is_claimed(),
			"underfunded refusal leaves service valid and unclaimed: " + event_id)
		_check(snap_under == before_under and record == record_snapshot,
			"underfunded refusal mutates no snapshot or record: " + event_id)
		_check(rng_guard.state == guard_state,
			"underfunded refusal draws no RNG: " + event_id)
		var leave_under_rec: Dictionary = svc_under.choose("leave", snap_under)
		_check(leave_under_rec.get("ok") == true and leave_under_rec.get("choice_id") == "leave"
			and int(leave_under_rec.get("candle")) == 40 and leave_under_rec.get("fray") == {},
			"Leave succeeds after underfunded refusal on same visit: " + event_id)
		_check(svc_under.is_claimed() and not svc_under.is_valid(),
			"post-underfunded Leave latches once: " + event_id)


func _funded_snapshot(gold: int, scraps: int) -> Dictionary:
	return _snapshot(BASE_CANDLE, gold, scraps, PARTY_FRAYS)


func _snapshot(candle: int, gold: int, scraps: int, frays: Array) -> Dictionary:
	var party: Array = []
	for pair in frays:
		party.append({"id": pair[0], "fray": pair[1]})
	return {"candle": candle, "party": party, "gold": gold, "scraps": scraps, "wren_fear": BASE_WREN_FEAR}


func _fray_map(frays: Array, delta: int) -> Dictionary:
	var intents: Dictionary = {}
	if delta == 0:
		return intents
	for pair in frays:
		intents[pair[0]] = delta
	return intents


func _expected_entry(choice_id: String, row: Dictionary, frays: Array) -> Dictionary:
	var entry := {
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle_delta": int(row["candle_delta"]),
		"fray_delta": int(row["fray"]),
		"available": true,
		"candle": int(row["candle"]),
		"fray": _fray_map(frays, int(row["fray"])),
	}
	if row.has("scraps"):
		entry["scraps_delta"] = int(row["scraps_delta"])
		entry["scraps"] = int(row["scraps"])
	if row.has("gold"):
		entry["gold_delta"] = int(row["gold_delta"])
		entry["gold"] = int(row["gold"])
	if row.has("hp"):
		entry["hp_delta"] = int(row["hp_delta"])
		entry["hp"] = _fray_map(frays, int(row["hp"]))
	if row.has("fear"):
		entry["fear_delta"] = int(row["fear_delta"])
		entry["fear"] = int(row["fear"])
	return entry


func _expected_receipt(event_id: String, choice_id: String, row: Dictionary, frays: Array) -> Dictionary:
	var receipt := {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": int(row["candle"]),
		"fray": _fray_map(frays, int(row["fray"])),
	}
	if row.has("scraps"):
		receipt["scraps_delta"] = int(row["scraps_delta"])
		receipt["scraps"] = int(row["scraps"])
	if row.has("gold"):
		receipt["gold_delta"] = int(row["gold_delta"])
		receipt["gold"] = int(row["gold"])
	if row.has("hp"):
		receipt["hp_delta"] = int(row["hp_delta"])
		receipt["hp"] = _fray_map(frays, int(row["hp"]))
	if row.has("fear"):
		receipt["fear_delta"] = int(row["fear_delta"])
		receipt["fear"] = int(row["fear"])
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


## AC1 / AC2 / AC3 / AC4: Veiled Wardrobe Mirror surviving-party gate on lift_silver_seam.
## Requires at least 2 non-LOST distinct heroes.
## 1. Four survivors: candle 40, gold 60, scraps 4 -> candle 22, gold 95, raw +15 fray intent for all 4.
## 2. Three survivors: 3 living + 1 lost -> candle 22, gold 95, raw +15 fray for the 3 living IDs only.
## 3. Two survivors: 2 living + 2 lost -> candle 22, gold 95, raw +15 fray for the 2 living IDs only.
## 4. Candle affordability boundary: candle 17 unavailable, candle 18 available and projects 0.
## 5. One survivor: (1 living + 3 lost) or solitary -> unavailable, refused, Leave succeeds.
## 6. Malformed min_active_heroes injections: 0, 5, -1, true, "2", 2.0, null and unexpected key.
## 7. Ungated sibling preservation: choices without gate remain byte-for-byte compatible.
func _test_mirror_surviving_party_gate() -> void:
	var event_id := "v3_veiled_wardrobe_mirror"
	var choice_id := "lift_silver_seam"
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	var record_snapshot: Dictionary = record.duplicate(true)

	# --- 1. Four survivors: Warden, Seamstress, Tinker, Yarn Ranger ---
	var snap_four := {
		"candle": 40,
		"gold": 60,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 10},
			{"id": "seamstress", "fray": 20},
			{"id": "tinker", "fray": 30},
			{"id": "yarn_ranger", "fray": 40},
		],
	}
	var before_four: Dictionary = snap_four.duplicate(true)
	var svc_four := RunStitchedEventConsequence.new(record)
	var prev_four: Dictionary = svc_four.preview(snap_four)
	_check(prev_four.get("ok") == true and prev_four.get("event_id") == event_id,
		"four-survivor mirror visit previews")
	var entry_four := _entry(prev_four, choice_id)
	_check(not entry_four.is_empty() and entry_four.get("available") == true,
		"four-survivor salvage choice is available")
	var expected_fray_four := {
		"warden": 15, "seamstress": 15, "tinker": 15, "yarn_ranger": 15,
	}
	_check(int(entry_four.get("candle")) == 22
		and int(entry_four.get("candle_delta")) == -18
		and int(entry_four.get("fray_delta")) == 15
		and int(entry_four.get("gold")) == 95
		and int(entry_four.get("gold_delta")) == 35
		and entry_four.get("fray") == expected_fray_four,
		"four-survivor preview quotes candle 22, gold 95, and raw +15 fray for all four")
	var rec_four: Dictionary = svc_four.choose(choice_id, snap_four)
	var expected_rec_four := {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": 22,
		"fray": expected_fray_four,
		"gold_delta": 35,
		"gold": 95,
	}
	_check(rec_four == expected_rec_four,
		"four-survivor claim settles exact receipt (40->22 candle, 60->95 gold, +15 fray for four)")
	_check(not rec_four.has("min_active_heroes") and not rec_four.has("scraps") and not rec_four.has("hp"),
		"four-survivor receipt has no extra keys")
	_check(svc_four.is_claimed() and not svc_four.is_valid(),
		"four-survivor claim latches once")
	_check(svc_four.choose(choice_id, snap_four) == _refusal(40),
		"four-survivor replay refused")
	_check(svc_four.choose("leave", snap_four) == _refusal(40),
		"four-survivor alternate choice refused after latch")
	_check(snap_four == before_four and record == record_snapshot,
		"four-survivor flow mutates no caller snapshot or record")
	_check(rng_guard.state == guard_state,
		"four-survivor flow draws no RNG")

	# Deterministic replay check for four survivors
	var svc_four_replay := RunStitchedEventConsequence.new(record)
	_check(svc_four_replay.preview(snap_four) == prev_four,
		"four-survivor deterministic replay preview matches")
	_check(svc_four_replay.choose(choice_id, snap_four) == rec_four,
		"four-survivor deterministic replay receipt matches")

	# --- 2. Three survivors: 3 living + 1 LOST ---
	var snap_three := {
		"candle": 40,
		"gold": 60,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 10},
			{"id": "seamstress", "fray": 20},
			{"id": "tinker", "fray": 30},
			{"id": "yarn_ranger", "fray": 40, "lost": true},
		],
	}
	var before_three: Dictionary = snap_three.duplicate(true)
	var svc_three := RunStitchedEventConsequence.new(record)
	var prev_three: Dictionary = svc_three.preview(snap_three)
	_check(prev_three.get("ok") == true, "three-survivor mirror visit previews")
	var entry_three := _entry(prev_three, choice_id)
	_check(not entry_three.is_empty() and entry_three.get("available") == true,
		"three-survivor salvage choice is available")
	var expected_fray_three := {
		"warden": 15, "seamstress": 15, "tinker": 15,
	}
	_check(int(entry_three.get("candle")) == 22
		and int(entry_three.get("gold")) == 95
		and entry_three.get("fray") == expected_fray_three,
		"three-survivor preview quotes candle 22, gold 95, and raw +15 fray for the three active dolls only")
	var rec_three: Dictionary = svc_three.choose(choice_id, snap_three)
	_check(rec_three == {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": 22,
		"fray": expected_fray_three,
		"gold_delta": 35,
		"gold": 95,
	}, "three-survivor claim settles exact receipt with only 3 living hero IDs in fray map")
	_check(not (rec_three.get("fray") as Dictionary).has("yarn_ranger"),
		"three-survivor fray map excludes LOST doll")
	_check(snap_three == before_three and record == record_snapshot,
		"three-survivor flow mutates no caller snapshot or record")
	_check(rng_guard.state == guard_state,
		"three-survivor flow draws no RNG")

	# --- 3. Two survivors: 2 living + 2 LOST ---
	# Candidate non-lost doll included (fray 0, non-lost identity, counts as active)
	var snap_two := {
		"candle": 40,
		"gold": 60,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 15},
			{"id": "seamstress", "fray": 0},
			{"id": "tinker", "fray": 50, "lost": true},
			{"id": "yarn_ranger", "fray": 50, "lost": true},
		],
	}
	var before_two: Dictionary = snap_two.duplicate(true)
	var svc_two := RunStitchedEventConsequence.new(record)
	var prev_two: Dictionary = svc_two.preview(snap_two)
	_check(prev_two.get("ok") == true, "two-survivor mirror visit previews")
	var entry_two := _entry(prev_two, choice_id)
	_check(not entry_two.is_empty() and entry_two.get("available") == true,
		"two-survivor salvage choice is available")
	var expected_fray_two := {
		"warden": 15, "seamstress": 15,
	}
	_check(int(entry_two.get("candle")) == 22
		and int(entry_two.get("gold")) == 95
		and entry_two.get("fray") == expected_fray_two,
		"two-survivor preview quotes candle 22, gold 95, and fray map for only the two active dolls")
	var rec_two: Dictionary = svc_two.choose(choice_id, snap_two)
	_check(rec_two == {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": 22,
		"fray": expected_fray_two,
		"gold_delta": 35,
		"gold": 95,
	}, "two-survivor claim settles exact receipt with only 2 living hero IDs in fray map")
	_check(snap_two == before_two and record == record_snapshot,
		"two-survivor flow mutates no caller snapshot or record")
	_check(rng_guard.state == guard_state,
		"two-survivor flow draws no RNG")

	# --- 4. Two survivors candle affordability boundary: candle 17 vs 18 ---
	var snap_two_c17 := snap_two.duplicate(true)
	snap_two_c17["candle"] = 17
	var before_two_c17: Dictionary = snap_two_c17.duplicate(true)
	var svc_two_c17 := RunStitchedEventConsequence.new(record)
	var prev_two_c17: Dictionary = svc_two_c17.preview(snap_two_c17)
	_check(prev_two_c17.get("ok") == true, "two-survivor candle 17 visit previews")
	var entry_two_c17 := _entry(prev_two_c17, choice_id)
	_check(not entry_two_c17.is_empty() and entry_two_c17.get("available") == false,
		"two-survivor candle 17 makes salvage unavailable via require_full_candle")
	_check(int(entry_two_c17.get("candle")) == 17 and entry_two_c17.get("fray") == {},
		"two-survivor candle 17 quotes caller candle 17 and empty fray")
	_check(svc_two_c17.choose(choice_id, snap_two_c17) == _refusal(17),
		"two-survivor candle 17 direct choose refused")
	_check(svc_two_c17.is_valid() and not svc_two_c17.is_claimed(),
		"two-survivor candle 17 refusal does not latch")
	_check(snap_two_c17 == before_two_c17, "candle 17 snapshot unchanged")
	_check(rng_guard.state == guard_state, "candle 17 refusal draws no RNG")

	var snap_two_c18 := snap_two.duplicate(true)
	snap_two_c18["candle"] = 18
	var before_two_c18: Dictionary = snap_two_c18.duplicate(true)
	var svc_two_c18 := RunStitchedEventConsequence.new(record)
	var prev_two_c18: Dictionary = svc_two_c18.preview(snap_two_c18)
	_check(prev_two_c18.get("ok") == true, "two-survivor candle 18 visit previews")
	var entry_two_c18 := _entry(prev_two_c18, choice_id)
	_check(not entry_two_c18.is_empty() and entry_two_c18.get("available") == true,
		"two-survivor candle 18 makes salvage available")
	_check(int(entry_two_c18.get("candle")) == 0 and int(entry_two_c18.get("gold")) == 95,
		"two-survivor candle 18 projects candle 0 and gold 95")
	var rec_two_c18: Dictionary = svc_two_c18.choose(choice_id, snap_two_c18)
	_check(rec_two_c18 == {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": 0,
		"fray": expected_fray_two,
		"gold_delta": 35,
		"gold": 95,
	}, "two-survivor candle 18 settles exact receipt at candle 0 and gold 95")
	_check(snap_two_c18 == before_two_c18, "candle 18 snapshot unchanged")
	_check(rng_guard.state == guard_state, "candle 18 claim draws no RNG")

	# --- 5. One survivor: (1 living + 3 LOST) AND solitary doll ---
	var snap_one_of_four := {
		"candle": 40,
		"gold": 60,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 15},
			{"id": "seamstress", "fray": 20, "lost": true},
			{"id": "tinker", "fray": 30, "lost": true},
			{"id": "yarn_ranger", "fray": 40, "lost": true},
		],
	}
	var before_one_of_four: Dictionary = snap_one_of_four.duplicate(true)
	var svc_one_of_four := RunStitchedEventConsequence.new(record)
	var prev_one_of_four: Dictionary = svc_one_of_four.preview(snap_one_of_four)
	_check(prev_one_of_four.get("ok") == true, "one-survivor (1 living + 3 lost) visit previews")
	var entry_one_of_four := _entry(prev_one_of_four, choice_id)
	_check(not entry_one_of_four.is_empty() and entry_one_of_four.get("available") == false,
		"one-survivor (1 living + 3 lost) salvage choice is unavailable")
	_check(int(entry_one_of_four.get("candle")) == 40
		and int(entry_one_of_four.get("gold")) == 60
		and int(entry_one_of_four.get("candle_delta")) == -18
		and int(entry_one_of_four.get("fray_delta")) == 15
		and int(entry_one_of_four.get("gold_delta")) == 35
		and entry_one_of_four.get("fray") == {},
		"one-survivor unavailable choice quotes caller state, deltas, and empty fray")
	var veil_entry := _entry(prev_one_of_four, "pin_lace_veil")
	_check(not veil_entry.is_empty() and veil_entry.get("available") == true,
		"one-survivor pin_lace_veil stays available with living warden fray 15 and scraps 4")
	_check(_entry(prev_one_of_four, "leave").get("available") == true,
		"one-survivor leave stays available")
	_check(svc_one_of_four.choose(choice_id, snap_one_of_four) == _refusal(40),
		"one-survivor direct salvage choose is refused with unchanged 7-key refusal")
	_check(svc_one_of_four.is_valid() and not svc_one_of_four.is_claimed(),
		"one-survivor refusal leaves visit open and unclaimed")
	_check(snap_one_of_four == before_one_of_four and record == record_snapshot,
		"one-survivor refusal mutates no snapshot or record")
	_check(rng_guard.state == guard_state, "one-survivor refusal draws no RNG")
	var leave_rec_one: Dictionary = svc_one_of_four.choose("leave", snap_one_of_four)
	_check(leave_rec_one == {
		"ok": true,
		"event_id": event_id,
		"choice_id": "leave",
		"target": "party",
		"hero_id": "",
		"candle": 40,
		"fray": {},
	}, "Leave succeeds on same visit after salvage refusal with 1 survivor")
	_check(svc_one_of_four.is_claimed() and not svc_one_of_four.is_valid(),
		"post-refusal Leave latches once")

	# Solitary-doll party snapshot (1 survivor total)
	var snap_solitary := {
		"candle": 40,
		"gold": 60,
		"scraps": 4,
		"party": [
			{"id": "warden", "fray": 10},
		],
	}
	var before_solitary: Dictionary = snap_solitary.duplicate(true)
	var svc_solitary := RunStitchedEventConsequence.new(record)
	var prev_solitary: Dictionary = svc_solitary.preview(snap_solitary)
	_check(prev_solitary.get("ok") == true, "solitary-doll party visit previews")
	var entry_solitary := _entry(prev_solitary, choice_id)
	_check(not entry_solitary.is_empty() and entry_solitary.get("available") == false,
		"solitary-doll party salvage choice is unavailable")
	_check(svc_solitary.choose(choice_id, snap_solitary) == _refusal(40),
		"solitary-doll party salvage choose refused")
	_check(svc_solitary.is_valid() and not svc_solitary.is_claimed(),
		"solitary refusal leaves visit unclaimed")
	var leave_rec_solitary: Dictionary = svc_solitary.choose("leave", snap_solitary)
	_check(leave_rec_solitary.get("ok") == true and leave_rec_solitary.get("choice_id") == "leave",
		"Leave succeeds after solitary refusal on same visit")
	_check(snap_solitary == before_solitary, "solitary snapshot unmutated")
	_check(rng_guard.state == guard_state, "solitary flow draws no RNG")

	# --- 6. Malformed min_active_heroes injections ---
	var malformed_values: Array = [0, 5, -1, true, "2", 2.0, null]
	for idx in range(malformed_values.size()):
		var bad_val: Variant = malformed_values[idx]
		var bad_choice := {
			"id": "bad_salvage",
			"text": "Malformed salvage.",
			"stitched_effect": {
				"target": "party",
				"candle": -12,
				"fray": 10,
				"gold": 26,
				"require_full_candle": true,
				"min_active_heroes": bad_val,
			},
		}
		var bad_event := {
			"id": "v3_veiled_wardrobe_mirror",
			"title": "The Veiled Wardrobe Mirror",
			"description": "Test malformed mirror.",
			"choices": [
				bad_choice,
				{"id": "leave", "text": "Leave.", "stitched_effect": {"target": "party", "candle": 0, "fray": 0}},
			],
		}
		var bad_before: Dictionary = bad_event.duplicate(true)
		var snap_four_bad: Dictionary = snap_four.duplicate(true)
		var snap_four_before: Dictionary = snap_four_bad.duplicate(true)
		var bad_svc := RunStitchedEventConsequence.new(bad_event)
		_check(bad_svc.is_valid(), "bad min_active_heroes %s keeps envelope valid" % str(bad_val))
		var bad_prev: Dictionary = bad_svc.preview(snap_four_bad)
		_check(bad_prev.get("ok") == true, "bad min_active_heroes %s visit previews" % str(bad_val))
		var bad_entry := _entry(bad_prev, "bad_salvage")
		_check(not bad_entry.is_empty()
			and bad_entry.get("available") == false
			and bad_entry.get("candle_delta") == null
			and bad_entry.get("fray_delta") == null
			and int(bad_entry.get("candle")) == 40
			and bad_entry.get("fray") == {},
			"bad min_active_heroes %s is unavailable with null deltas" % str(bad_val))
		_check(_entry(bad_prev, "leave").get("available") == true,
			"Leave stays available with bad min_active_heroes %s" % str(bad_val))
		_check(bad_svc.choose("bad_salvage", snap_four_bad) == _refusal(40),
			"bad min_active_heroes %s choose is refused" % str(bad_val))
		_check(bad_svc.is_valid() and not bad_svc.is_claimed(),
			"bad min_active_heroes %s refusal does not latch" % str(bad_val))
		_check(snap_four_bad == snap_four_before and bad_event == bad_before,
			"bad min_active_heroes %s mutates no snapshot or event" % str(bad_val))
		_check(rng_guard.state == guard_state,
			"bad min_active_heroes %s draws no RNG" % str(bad_val))
		var bad_leave: Dictionary = bad_svc.choose("leave", snap_four_bad)
		_check(bad_leave.get("ok") == true and bad_leave.get("choice_id") == "leave",
			"Leave succeeds after bad min_active_heroes %s refusal" % str(bad_val))
		_check(bad_svc.is_claimed() and not bad_svc.is_valid(),
			"post-bad-refusal Leave latches once")

	# Unexpected extra key on effect with min_active_heroes
	var extra_key_event := {
		"id": "v3_veiled_wardrobe_mirror",
		"title": "The Veiled Wardrobe Mirror",
		"description": "Test extra key mirror.",
		"choices": [
			{
				"id": "extra_key_salvage",
				"text": "Extra key salvage.",
				"stitched_effect": {
					"target": "party",
					"candle": -12,
					"fray": 10,
					"gold": 26,
					"require_full_candle": true,
					"min_active_heroes": 2,
					"unexpected_key": 999,
				},
			},
			{"id": "leave", "text": "Leave.", "stitched_effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	}
	var extra_svc := RunStitchedEventConsequence.new(extra_key_event)
	_check(extra_svc.is_valid(), "extra key keeps envelope valid")
	var extra_prev: Dictionary = extra_svc.preview(snap_four)
	var extra_entry := _entry(extra_prev, "extra_key_salvage")
	_check(extra_entry.get("available") == false and extra_entry.get("candle_delta") == null,
		"unexpected key makes salvage malformed and unavailable with null deltas")
	_check(_entry(extra_prev, "leave").get("available") == true, "Leave stays available with extra key")
	_check(extra_svc.choose("extra_key_salvage", snap_four) == _refusal(40),
		"unexpected key choice is refused")
	_check(extra_svc.is_valid() and not extra_svc.is_claimed(), "unexpected key refusal does not latch")
	_check(extra_svc.choose("leave", snap_four).get("ok") == true,
		"Leave succeeds after unexpected key refusal")

	# Ungated sibling preservation: choices without min_active_heroes have byte-for-byte compatible receipts
	var pin_rec: Dictionary = RunStitchedEventConsequence.new(record).choose("pin_lace_veil", snap_four)
	_check(pin_rec == {
		"ok": true,
		"event_id": event_id,
		"choice_id": "pin_lace_veil",
		"target": "party",
		"hero_id": "",
		"candle": 40,
		"fray": {"warden": -9, "seamstress": -9, "tinker": -9, "yarn_ranger": -9},
		"scraps_delta": -1,
		"scraps": 3,
	}, "ungated pin_lace_veil receipt is byte-for-byte compatible with legacy")
	_check(not pin_rec.has("min_active_heroes"), "ungated receipt emits no min_active_heroes key")
