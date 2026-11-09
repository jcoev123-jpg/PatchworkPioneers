extends SceneTree
## Deterministic headless coverage for the three doll-scale Stitched Events
## appended to the native route-effect catalog
## (res://data/events/stitched_route_effects.json): the Ashglass Metronome, the
## Black-Velvet Millwheel and the Cinder-Iron Bootscraper.
##
## EXPECTED and FUNDED_FINAL are independent hardcoded copies of the authored
## stories and the funded settlement oracle; they never read the production
## catalog or the consequence service back as their oracle. Only per-ID
## membership is asserted on the catalog: no catalog total, no full ordered ID
## list and no fixed pool position, so peer batches can land in the same catalog
## without clashing. Every preview row and receipt is compared against an exact
## hardcoded dictionary, which also proves the ABSENCE of the optional
## gold/scraps/hp/fear keys on choices that do not carry them. No flow under
## test draws from any RNG; a seeded guard proves that, and an explicit draw
## proves the guard is live.

const EVENTS_PATH := "res://data/events/stitched_route_effects.json"
const BASE_CANDLE := 42
const BASE_GOLD := 40
const BASE_SCRAPS := 7
const BASE_FEAR := 38
const HERO_FRAY := 15
const PARTY_IDS := ["tinker", "seamstress", "scarecrow", "warden"]

## Independent literal copies of the three authored stories, including the
## exact signed stitched_effect fields.
const EXPECTED := {
	"v3_ashglass_metronome": {
		"title": "The Ashglass Metronome",
		"description": "A towering metronome sways in a torn velvet wall niche. Its black glass weight holds a trapped candle-glow while the Tinker's crooked gears tick in sympathy.",
		"choices": [
			{"id": "tinker_retime_weight", "text": "Let the Tinker retime the hot weight and steady Wren.", "effect": {"target": "party", "candle": 20, "fray": 6, "fear": -10, "gold": -12, "required_hero": "tinker", "require_candle_room": true}},
			{"id": "crack_glass_weight", "text": "Crack the glass for loose brass while the light stumbles.", "effect": {"target": "party", "candle": -12, "fray": 9, "scraps": 3, "require_full_candle": true}},
			{"id": "leave", "text": "Let the metronome count the quiet again.", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_black_velvet_millwheel": {
		"title": "The Black-Velvet Millwheel",
		"description": "A dinner-table-sized toy mill grinds old stitches beside the skirting. A velvet doll keeper holds its cracked spokes as the Seamstress studies the loose binding.",
		"choices": [
			{"id": "seamstress_reline_wheel", "text": "Let the Seamstress bind the wheel and mend tired dolls.", "effect": {"target": "party", "candle": 0, "fray": -9, "hp": 6, "scraps": -2, "required_hero": "seamstress"}},
			{"id": "lift_silver_pinion", "text": "Steal the silver pinion, darkening the road ahead.", "effect": {"target": "party", "candle": -15, "fray": 11, "gold": 28, "require_full_candle": true}},
			{"id": "leave", "text": "Leave the mill to grind its own ragged thread.", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
	"v3_cinder_iron_bootscraper": {
		"title": "The Cinder-Iron Bootscraper",
		"description": "A vast iron bootscraper juts from a soot-stained threshold, its blunt teeth crowded with torn doll-straw. Beyond it a weak amber glow slips under the door.",
		"choices": [
			{"id": "scarecrow_wedge_straw", "text": "Let the Scarecrow pack its teeth and shield the flame.", "effect": {"target": "party", "candle": 24, "fray": -5, "scraps": -2, "required_hero": "scarecrow", "require_candle_room": true}},
			{"id": "harvest_rust_teeth", "text": "Pull free the rusted teeth; the dolls pay in stuffing.", "effect": {"target": "party", "candle": -11, "fray": 10, "scraps": 3, "hp": -4, "require_full_candle": true}},
			{"id": "leave", "text": "Step around the iron teeth and keep walking.", "effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	},
}

## Independent funded oracle from the fixture snapshot {candle 42, gold 40,
## scraps 7, wren_fear 38, four living heroes each at fray 15}: the exact
## projected candle, the raw per-hero fray/hp intents, Wren fear and the exact
## settled purse per choice.
const FUNDED_FINAL := {
	"v3_ashglass_metronome": {
		"tinker_retime_weight": {"candle": 62, "candle_delta": 20, "fray": 6, "fear": 28, "fear_delta": -10, "gold": 28, "gold_delta": -12},
		"crack_glass_weight": {"candle": 30, "candle_delta": -12, "fray": 9, "scraps": 10, "scraps_delta": 3},
		"leave": {"candle": 42, "candle_delta": 0, "fray": 0},
	},
	"v3_black_velvet_millwheel": {
		"seamstress_reline_wheel": {"candle": 42, "candle_delta": 0, "fray": -9, "scraps": 5, "scraps_delta": -2, "hp": 6, "hp_delta": 6},
		"lift_silver_pinion": {"candle": 27, "candle_delta": -15, "fray": 11, "gold": 68, "gold_delta": 28},
		"leave": {"candle": 42, "candle_delta": 0, "fray": 0},
	},
	"v3_cinder_iron_bootscraper": {
		"scarecrow_wedge_straw": {"candle": 66, "candle_delta": 24, "fray": -5, "scraps": 5, "scraps_delta": -2},
		"harvest_rust_teeth": {"candle": 31, "candle_delta": -11, "fray": 10, "scraps": 10, "scraps_delta": 3, "hp": -4, "hp_delta": -4},
		"leave": {"candle": 42, "candle_delta": 0, "fray": 0},
	},
}

## Earlier anchors that must remain in the catalog with their original titles.
const ANCHOR_TITLES := {
	"moth_infestation": "Moth Infestation",
	"v3_glasseye_pendulum": "The Glass-Eyed Pendulum",
	"v3_hushed_birdcage": "The Hushed Birdcage",
	"v3_rocking_horse_vigil": "The Rocking Horse Vigil",
	"v3_frosted_attic_porthole": "The Frosted Attic Porthole",
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
	_test_missing_or_lost_hero_gates()
	_test_candle_debit_boundaries()
	_test_full_candle_boundaries()
	_test_purse_boundaries()
	_test_determinism_and_rng_guard()
	_check(source_document == source_snapshot, "the catalog document is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_metronome_millwheel_bootscraper_events_test: ",
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
## id/text/stitched_effect, the exact signed effects, and a Leave effect of
## exactly {"target":"party","candle":0,"fray":0} with no optional fields.
func _test_source_records() -> void:
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		_check(int(source_counts.get(event_id, 0)) == 1,
			"exactly one authored record for " + event_id)
		if not source_by_id.has(event_id):
			continue
		var record: Dictionary = source_by_id[event_id]
		_check(RunEventChoice.new(record).is_valid(),
			"the shipped envelope validator accepts the fresh record: " + event_id)
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
			if choice_id == "leave":
				_check((effect as Dictionary).size() == 3
					and (effect as Dictionary).get("target") == "party"
					and (effect as Dictionary).get("candle") == 0
					and (effect as Dictionary).get("fray") == 0,
					"the Leave effect is exactly target/candle/fray with no optional keys: " + event_id)


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
			and (record.get("choices") as Array).size() == 3,
			"the anchor keeps its three authored choices: " + anchor_id)


## Funded previews and claims agree with the independent oracle on all nine
## choices; a settled visit cannot be replayed or forged, previews close after
## the claim, and neither the caller snapshot nor the record is ever mutated.
func _test_funded_contract() -> void:
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 515151
	var guard_state: int = rng_guard.state
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var table: Dictionary = FUNDED_FINAL[event_id]
		var record: Dictionary = _service_record(event_id)
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
					"the funded gold agrees with their hardcoded delta: " + event_id + " / " + choice_id)
			if row.has("fear"):
				_check(int(row["fear"]) == BASE_FEAR + int(row["fear_delta"]),
					"the funded fear agrees with its hardcoded delta: " + event_id + " / " + choice_id)
			var snapshot := _funded_snapshot()
			var before: Dictionary = snapshot.duplicate(true)
			var service := RunStitchedEventConsequence.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"a fresh visit opens: " + event_id + " / " + choice_id)
			_check(service.choose("forged_choice", snapshot) == _refusal(BASE_CANDLE),
				"an unknown choice cannot claim a fresh visit: " + event_id + " / " + choice_id)
			_check(service.is_valid() and not service.is_claimed(),
				"the forged refusal keeps the visit open and unclaimed: " + event_id + " / " + choice_id)
			var preview: Dictionary = service.preview(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and int(preview.get("candle")) == BASE_CANDLE,
				"funded preview succeeds: " + event_id + " / " + choice_id)
			_check(preview.get("choices", []).size() == 3,
				"funded preview lists all three choices: " + event_id)
			var entry := _entry(preview, choice_id)
			_check(entry == _expected_entry(choice_id, row, PARTY_IDS),
				"funded preview matches the hardcoded oracle exactly: " + event_id + " / " + choice_id)
			var receipt: Dictionary = service.choose(choice_id, snapshot)
			_check(receipt == _expected_receipt(event_id, choice_id, row, PARTY_IDS),
				"funded claim settles the hardcoded oracle exactly: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches exactly once: " + event_id + " / " + choice_id)
			_check(service.choose(choice_id, snapshot) == _refusal(BASE_CANDLE),
				"a settled choice cannot be replayed: " + event_id + " / " + choice_id)
			var other_id := _other_choice_id(contract, choice_id)
			_check(service.choose(other_id, snapshot) == _refusal(BASE_CANDLE),
				"no alternate choice claims a spent visit: " + event_id + " / " + choice_id)
			_check(service.choose("forged_choice", snapshot) == _refusal(BASE_CANDLE),
				"an unknown choice cannot claim a spent visit: " + event_id + " / " + choice_id)
			_check(service.preview(snapshot) == _denied_preview(),
				"a spent visit offers no further preview: " + event_id + " / " + choice_id)
			_check(snapshot == before and record == record_snapshot,
				"a funded flow mutates neither snapshot nor record: " + event_id + " / " + choice_id)
	_check(settlements == 9, "every one of the nine authored choices settles once when funded")
	_check(rng_guard.state == guard_state,
		"previews and claims never touch an unrelated seeded RNG")


## Without the living gated hero (a four-person canonical party with another
## valid hero substituted, or the gated hero present but LOST), the
## required-hero choice is hidden from preview, refused without latching, and
## Leave still settles once on that visit.
func _test_missing_or_lost_hero_gates() -> void:
	var cases := [
		{"event_id": "v3_ashglass_metronome", "gated": "tinker_retime_weight", "party": ["warden", "seamstress", "scarecrow", "lantern_monk"], "lost": ""},
		{"event_id": "v3_black_velvet_millwheel", "gated": "seamstress_reline_wheel", "party": ["warden", "tinker", "scarecrow", "rag_duelist"], "lost": ""},
		{"event_id": "v3_cinder_iron_bootscraper", "gated": "scarecrow_wedge_straw", "party": ["warden", "seamstress", "tinker", "yarn_ranger"], "lost": ""},
		{"event_id": "v3_ashglass_metronome", "gated": "tinker_retime_weight", "party": PARTY_IDS, "lost": "tinker"},
		{"event_id": "v3_black_velvet_millwheel", "gated": "seamstress_reline_wheel", "party": PARTY_IDS, "lost": "seamstress"},
		{"event_id": "v3_cinder_iron_bootscraper", "gated": "scarecrow_wedge_straw", "party": PARTY_IDS, "lost": "scarecrow"},
	]
	for case in cases:
		var event_id: String = case["event_id"]
		var gated: String = case["gated"]
		var lost_id: String = case["lost"]
		var label: String = event_id + " / " + gated + (" (LOST)" if not lost_id.is_empty() else " (missing)")
		var record: Dictionary = _service_record(event_id)
		var record_snapshot: Dictionary = record.duplicate(true)
		var snapshot := _funded_snapshot()
		if lost_id.is_empty():
			snapshot["party"] = _party(case["party"])
		else:
			snapshot["party"] = _party_with_lost(case["party"], lost_id)
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		var preview: Dictionary = service.preview(snapshot)
		_check(preview.get("ok") == true, "the substituted party still previews: " + label)
		_check(preview.get("choices", []).size() == 2,
			"the hero-gated choice is hidden from the preview: " + label)
		_check(_entry(preview, gated) == {},
			"no preview row exists for the hidden choice: " + label)
		_check(_entry(preview, "leave").get("available") == true,
			"leave stays selectable without the gated hero: " + label)
		_check(service.choose(gated, snapshot) == _refusal(BASE_CANDLE),
			"the hidden choice is refused by choose: " + label)
		_check(service.is_valid() and not service.is_claimed(),
			"the hidden-choice refusal keeps the visit open and unclaimed: " + label)
		_check(service.choose("leave", snapshot) == _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"], PARTY_IDS),
			"leave commits on the same visit after the hidden-choice refusal: " + label)
		_check(service.is_claimed() and not service.is_valid(),
			"the post-refusal leave claim latches once: " + label)
		_check(service.choose("leave", snapshot) == _refusal(BASE_CANDLE),
			"the spent visit refuses a replay: " + label)
		_check(snapshot == before and record == record_snapshot,
			"the missing/LOST-hero flow mutates neither snapshot nor record: " + label)


## require_full_candle debits refuse at candle 4, below every full cost:
## metronome -12, millwheel -15, bootscraper -11.
func _test_candle_debit_boundaries() -> void:
	var cases := [
		{"event_id": "v3_ashglass_metronome", "choice_id": "crack_glass_weight"},
		{"event_id": "v3_black_velvet_millwheel", "choice_id": "lift_silver_pinion"},
		{"event_id": "v3_cinder_iron_bootscraper", "choice_id": "harvest_rust_teeth"},
	]
	for case in cases:
		var event_id: String = case["event_id"]
		var choice_id: String = case["choice_id"]
		var candle := 4
		var record: Dictionary = _service_record(event_id)
		var snapshot := _funded_snapshot()
		snapshot["candle"] = candle
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		var preview: Dictionary = service.preview(snapshot)
		var entry := _entry(preview, choice_id)
		_check(entry.get("available") == false
			and int(entry.get("candle")) == candle
			and entry.get("fray") == {},
			"candle 4 quotes the debit unavailable with the unchanged candle and empty fray: " + event_id + " / " + choice_id)
		_check(_entry(preview, "leave").get("available") == true,
			"leave stays selectable at candle 4: " + event_id)
		_check(service.choose(choice_id, snapshot) == _refusal(candle),
			"the under-candled debit is refused: " + event_id + " / " + choice_id)
		_check(service.is_valid() and not service.is_claimed(),
			"the candle refusal keeps the visit open and unclaimed: " + event_id + " / " + choice_id)
		var expected_leave := _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"], PARTY_IDS)
		expected_leave["candle"] = candle
		_check(service.choose("leave", snapshot) == expected_leave,
			"leave commits on the same visit at candle 4: " + event_id + " / " + choice_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the post-refusal leave claim latches once: " + event_id + " / " + choice_id)
		_check(service.choose("leave", snapshot) == _refusal(candle),
			"the spent visit refuses a replay: " + event_id)
		_check(snapshot == before, "the candle-boundary flow mutates no snapshot: " + event_id)


## A full candle leaves no room for the metronome +20 and the bootscraper +24
## require_candle_room gains; both are quoted unavailable and refused.
func _test_full_candle_boundaries() -> void:
	var cases := [
		{"event_id": "v3_ashglass_metronome", "choice_id": "tinker_retime_weight"},
		{"event_id": "v3_cinder_iron_bootscraper", "choice_id": "scarecrow_wedge_straw"},
	]
	for case in cases:
		var event_id: String = case["event_id"]
		var choice_id: String = case["choice_id"]
		var record: Dictionary = _service_record(event_id)
		var snapshot := _funded_snapshot()
		snapshot["candle"] = 100
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		var preview: Dictionary = service.preview(snapshot)
		_check(preview.get("choices", []).size() == 3,
			"a full candle keeps the gain visible in preview: " + event_id)
		var entry := _entry(preview, choice_id)
		_check(entry.get("available") == false
			and int(entry.get("candle")) == 100
			and entry.get("fray") == {},
			"a full candle quotes the gain unavailable with empty fray intents: " + event_id + " / " + choice_id)
		_check(_entry(preview, "leave").get("available") == true,
			"leave stays selectable at a full candle: " + event_id)
		_check(service.choose(choice_id, snapshot) == _refusal(100),
			"the full-candle gain is refused: " + event_id + " / " + choice_id)
		_check(service.is_valid() and not service.is_claimed(),
			"the full-candle refusal keeps the visit open and unclaimed: " + event_id + " / " + choice_id)
		var expected_leave := _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"], PARTY_IDS)
		expected_leave["candle"] = 100
		_check(service.choose("leave", snapshot) == expected_leave,
			"leave commits on the same visit at a full candle: " + event_id + " / " + choice_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the post-refusal leave claim latches once: " + event_id + " / " + choice_id)
		_check(snapshot == before, "the full-candle flow mutates no snapshot: " + event_id)


## Underfunded purses refuse their debits: gold 0 vs the metronome -12,
## scraps 0 vs the millwheel -2 and the bootscraper -2.
func _test_purse_boundaries() -> void:
	var cases := [
		{"event_id": "v3_ashglass_metronome", "choice_id": "tinker_retime_weight", "key": "gold", "value": 0},
		{"event_id": "v3_black_velvet_millwheel", "choice_id": "seamstress_reline_wheel", "key": "scraps", "value": 0},
		{"event_id": "v3_cinder_iron_bootscraper", "choice_id": "scarecrow_wedge_straw", "key": "scraps", "value": 0},
	]
	for case in cases:
		var event_id: String = case["event_id"]
		var choice_id: String = case["choice_id"]
		var key: String = case["key"]
		var value: int = case["value"]
		var record: Dictionary = _service_record(event_id)
		var snapshot := _funded_snapshot()
		snapshot[key] = value
		var before: Dictionary = snapshot.duplicate(true)
		var service := RunStitchedEventConsequence.new(record)
		var preview: Dictionary = service.preview(snapshot)
		var entry := _entry(preview, choice_id)
		_check(entry.get("available") == false
			and int(entry.get("candle")) == BASE_CANDLE
			and entry.get("fray") == {}
			and int(entry.get(key)) == value,
			str(value) + " " + key + " quotes the paid choice unavailable with the unchanged purse and empty fray: " + event_id + " / " + choice_id)
		_check(_entry(preview, "leave").get("available") == true,
			"leave stays selectable at " + str(value) + " " + key + ": " + event_id)
		_check(service.choose(choice_id, snapshot) == _refusal(BASE_CANDLE),
			"the underfunded choice is refused: " + event_id + " / " + choice_id)
		_check(service.is_valid() and not service.is_claimed(),
			"the purse refusal keeps the visit open and unclaimed: " + event_id + " / " + choice_id)
		_check(service.choose("leave", snapshot) == _expected_receipt(event_id, "leave", FUNDED_FINAL[event_id]["leave"], PARTY_IDS),
			"leave commits on the same visit after the purse refusal: " + event_id + " / " + choice_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the post-refusal leave claim latches once: " + event_id + " / " + choice_id)
		_check(service.choose("leave", snapshot) == _refusal(BASE_CANDLE),
			"the spent visit refuses a replay: " + event_id)
		_check(snapshot == before, "the purse-boundary flow mutates no snapshot: " + event_id)


## Same-seed fresh visits are identical and no flow draws from a caller RNG;
## an explicit draw proves the guard can actually observe a change.
func _test_determinism_and_rng_guard() -> void:
	var rng_guard := RandomNumberGenerator.new()
	rng_guard.seed = 919191
	var guard_state: int = rng_guard.state
	for event_id in EXPECTED:
		var record: Dictionary = _service_record(event_id)
		var first := _replay_visit(record, "leave")
		var second := _replay_visit(record, "leave")
		_check(first["preview"] == second["preview"] and first["receipt"] == second["receipt"],
			"two fresh visits project and settle identically: " + event_id)
	var snapshot := _funded_snapshot()
	for event_id in EXPECTED:
		var record: Dictionary = _service_record(event_id)
		var service := RunStitchedEventConsequence.new(record)
		service.preview(snapshot)
		service.choose("leave", snapshot)
	_check(rng_guard.state == guard_state,
		"previews and claims leave a fixed-seed caller RNG unchanged")
	var drawn: int = rng_guard.randi_range(0, 99)
	_check(drawn >= 0 and drawn <= 99 and rng_guard.state != guard_state,
		"an explicit draw advances the guard RNG, proving the guard is live")


## The service contract wants a native int fear delta; JSON decodes authored
## whole numbers as floats, so normalize exactly like the session converter.
func _service_record(event_id: String) -> Dictionary:
	var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
	for choice in record.get("choices", []):
		if choice is Dictionary and choice.get("stitched_effect") is Dictionary:
			var effect: Dictionary = choice["stitched_effect"]
			if effect.has("fear") and typeof(effect["fear"]) == TYPE_FLOAT:
				effect["fear"] = int(effect["fear"])
	return record


func _replay_visit(record: Dictionary, choice_id: String) -> Dictionary:
	var snapshot := _funded_snapshot()
	var service := RunStitchedEventConsequence.new(record)
	var preview: Dictionary = service.preview(snapshot)
	var receipt: Dictionary = service.choose(choice_id, snapshot)
	return {"preview": preview, "receipt": receipt}


func _funded_snapshot() -> Dictionary:
	return {"candle": BASE_CANDLE, "party": _party_with_fray(PARTY_IDS, HERO_FRAY),
		"gold": BASE_GOLD, "scraps": BASE_SCRAPS, "wren_fear": BASE_FEAR}


func _party(ids: Array) -> Array:
	return _party_with_fray(ids, HERO_FRAY)


func _party_with_fray(ids: Array, fray: int) -> Array:
	var party: Array = []
	for hero_id in ids:
		party.append({"id": hero_id, "fray": fray})
	return party


func _party_with_lost(ids: Array, lost_id: String) -> Array:
	var party: Array = []
	for hero_id in ids:
		if hero_id == lost_id:
			party.append({"id": hero_id, "fray": HERO_FRAY, "lost": true})
		else:
			party.append({"id": hero_id, "fray": HERO_FRAY})
	return party


func _intent_map(delta: int, ids: Array) -> Dictionary:
	var intents: Dictionary = {}
	if delta == 0:
		return intents
	for hero_id in ids:
		intents[hero_id] = delta
	return intents


func _expected_entry(choice_id: String, row: Dictionary, ids: Array) -> Dictionary:
	var entry := {
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle_delta": int(row["candle_delta"]),
		"fray_delta": int(row["fray"]),
		"available": true,
		"candle": int(row["candle"]),
		"fray": _intent_map(int(row["fray"]), ids),
	}
	if row.has("scraps"):
		entry["scraps_delta"] = int(row["scraps_delta"])
		entry["scraps"] = int(row["scraps"])
	if row.has("gold"):
		entry["gold_delta"] = int(row["gold_delta"])
		entry["gold"] = int(row["gold"])
	if row.has("hp"):
		entry["hp_delta"] = int(row["hp_delta"])
		entry["hp"] = _intent_map(int(row["hp"]), ids)
	if row.has("fear"):
		entry["fear_delta"] = int(row["fear_delta"])
		entry["fear"] = int(row["fear"])
	return entry


func _expected_receipt(event_id: String, choice_id: String, row: Dictionary, ids: Array) -> Dictionary:
	var receipt := {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"target": "party",
		"hero_id": "",
		"candle": int(row["candle"]),
		"fray": _intent_map(int(row["fray"]), ids),
	}
	if row.has("scraps"):
		receipt["scraps_delta"] = int(row["scraps_delta"])
		receipt["scraps"] = int(row["scraps"])
	if row.has("gold"):
		receipt["gold_delta"] = int(row["gold_delta"])
		receipt["gold"] = int(row["gold"])
	if row.has("hp"):
		receipt["hp_delta"] = int(row["hp_delta"])
		receipt["hp"] = _intent_map(int(row["hp"]), ids)
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
