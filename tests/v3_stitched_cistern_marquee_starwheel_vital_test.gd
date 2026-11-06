extends SceneTree
## Focused headless contract test for the three appended giant-prop Stitched
## hero vitality roadside Events in data/events/v3_hero_vital_events.json:
## The Needlefish Cistern (Yarn Ranger), The Mourning Glove Marquee (Rag
## Duelist) and The Starwheel Dumbwaiter (Button Golem). Exercises only the
## shipped catalog plus the real RunV3HeroVitalEventGate / RunEventChoice
## services: presence-only anchor checks (never a catalog total or an ordered
## ID list), per-entry integrity for the three authored records, real
## four-hero-party admission and offer negatives, authored funded settlements
## from an independent expected table, starved fail-closed refusals that leave
## the visit claimable by Leave, focused threshold witnesses, and
## catalog-growth-safe seeded actionable selection.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

## Prior named anchors that must still exist (presence only, no totals).
const ANCHOR_IDS := [
	"v3_yarn_ranger_stormkite_tangle",
	"v3_rag_duelist_velvet_needle_organ",
	"v3_button_golem_gravestone_press",
]

const EVENT_ORDER := [
	"v3_yarn_ranger_needlefish_cistern",
	"v3_rag_duelist_mourning_glove_marquee",
	"v3_button_golem_starwheel_dumbwaiter",
]

## Authored choice order per event.
const CHOICE_ORDER := {
	"v3_yarn_ranger_needlefish_cistern": ["mend_needlefins", "pry_glass_scales", "leave"],
	"v3_rag_duelist_mourning_glove_marquee": ["line_glove_cuff", "cut_marquee_tassels", "leave"],
	"v3_button_golem_starwheel_dumbwaiter": ["brace_starwheel", "pull_brass_pins", "leave"],
}

## Task-local transcription of the authored rows. Each choice row is
## [text, gold, scraps, hp, max_hp]; the outcome keys must be exactly the
## four signed integers, zeros included.
const SPECS := {
	"v3_yarn_ranger_needlefish_cistern": {
		"title": "The Needlefish Cistern",
		"description": "In an old wall niche, a giant glass cistern holds a silver-button needlefish; the Yarn Ranger's moss-and-teal bolas tether its woven tail while moonlight glints on a single cracked seam.",
		"hero": "yarn_ranger",
		"choices": {
			"mend_needlefins": ["Spend 2 scraps to mend the needlefish's felt fins (heal 9 HP)", 0, -2, 9, 0],
			"pry_glass_scales": ["Pull out sharp glass scales (lose 5 HP; gain 24 gold)", 24, 0, -5, 0],
			"leave": ["Leave the needlefish swimming in silence", 0, 0, 0, 0],
		},
	},
	"v3_rag_duelist_mourning_glove_marquee": {
		"title": "The Mourning Glove Marquee",
		"description": "An oxblood velvet glove the size of a tent droops over an abandoned toy stage; the Rag Duelist pins its frayed cuff with a needle rapier while pale ribbons sway above the candlelit seats.",
		"hero": "rag_duelist",
		"choices": {
			"line_glove_cuff": ["Pay 18 gold to line the velvet cuff (+3 max HP)", -18, 0, 0, 3],
			"cut_marquee_tassels": ["Cut barbed tassels (lose 5 HP; gain 3 scraps)", 0, 3, -5, 0],
			"leave": ["Let the great velvet glove fall closed", 0, 0, 0, 0],
		},
	},
	"v3_button_golem_starwheel_dumbwaiter": {
		"title": "The Starwheel Dumbwaiter",
		"description": "A button-faced brass dumbwaiter hangs over a stairwell as deep as night; the Button Golem presses its huge round fists against a painted starwheel to keep the thread-slung platform from slipping.",
		"hero": "button_golem",
		"choices": {
			"brace_starwheel": ["Spend 2 scraps on a stronger hauling seam (+2 max HP)", 0, -2, 0, 2],
			"pull_brass_pins": ["Pull the brass axle pins (lose 2 max HP; gain 26 gold)", 26, 0, 0, -2],
			"leave": ["Leave the starwheel turning in the dark", 0, 0, 0, 0],
		},
	},
}

## Funded precondition shared by every settlement check: wallet 50 gold / 5
## scraps, required hero at 17 of 30 HP.
const BASE_GOLD := 50
const BASE_SCRAPS := 5
const BASE_HP := 17
const BASE_MAX_HP := 30

## Expected resulting [gold, scraps, hp, max_hp] from the funded 50/5, 17/30
## opening, written independently of the JSON deltas rather than recomputed
## from them.
const EXPECTED := {
	"v3_yarn_ranger_needlefish_cistern": {
		"mend_needlefins": [50, 3, 26, 30],
		"pry_glass_scales": [74, 5, 12, 30],
		"leave": [50, 5, 17, 30],
	},
	"v3_rag_duelist_mourning_glove_marquee": {
		"line_glove_cuff": [32, 5, 17, 33],
		"cut_marquee_tassels": [50, 8, 12, 30],
		"leave": [50, 5, 17, 30],
	},
	"v3_button_golem_starwheel_dumbwaiter": {
		"brace_starwheel": [50, 3, 17, 32],
		"pull_brass_pins": [76, 5, 17, 28],
		"leave": [50, 5, 17, 30],
	},
}

## A genuine four-of-eight Stitched party containing every required hero.
const PARTY := ["yarn_ranger", "rag_duelist", "button_golem", "warden"]

## A genuine four-of-eight Stitched party with none of the required heroes.
const ABSENT_PARTY := ["warden", "seamstress", "tinker", "scarecrow"]

## Focused boundary witnesses: event, choice, gold, scraps, hp, max_hp and
## the exact affordability the real preview must report at that opening.
const THRESHOLD := [
	["v3_yarn_ranger_needlefish_cistern", "mend_needlefins", 50, 1, 17, 30, false],
	["v3_yarn_ranger_needlefish_cistern", "mend_needlefins", 50, 2, 17, 30, true],
	["v3_yarn_ranger_needlefish_cistern", "mend_needlefins", 50, 2, 30, 30, false],
	["v3_yarn_ranger_needlefish_cistern", "pry_glass_scales", 50, 5, 5, 30, false],
	["v3_yarn_ranger_needlefish_cistern", "pry_glass_scales", 50, 5, 6, 30, true],
	["v3_rag_duelist_mourning_glove_marquee", "line_glove_cuff", 17, 5, 17, 30, false],
	["v3_rag_duelist_mourning_glove_marquee", "line_glove_cuff", 18, 5, 17, 30, true],
	["v3_rag_duelist_mourning_glove_marquee", "cut_marquee_tassels", 50, 5, 5, 30, false],
	["v3_rag_duelist_mourning_glove_marquee", "cut_marquee_tassels", 50, 5, 6, 30, true],
	["v3_button_golem_starwheel_dumbwaiter", "brace_starwheel", 50, 1, 17, 30, false],
	["v3_button_golem_starwheel_dumbwaiter", "brace_starwheel", 50, 2, 17, 30, true],
	["v3_button_golem_starwheel_dumbwaiter", "pull_brass_pins", 50, 5, 11, 11, false],
	["v3_button_golem_starwheel_dumbwaiter", "pull_brass_pins", 50, 5, 11, 12, true],
]

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary = {}


func _initialize() -> void:
	var before := FileAccess.get_file_as_string(CATALOG_PATH)
	seed(5813)
	var expected_global := randi()

	catalog = JSON.parse_string(before)
	_check(catalog is Dictionary and catalog.get("events") is Array,
		"vital hero catalog parses as {events: []}")
	if not (catalog is Dictionary and catalog.get("events") is Array):
		_finish()
		return

	_test_authentic_records()
	_test_anchor_records_present()
	_test_older_records_intact()
	_test_admission_and_offers()
	_test_settlement_table()
	_test_unknown_choice()
	_test_starved_refusals_then_leave()
	_test_threshold_witnesses()
	_test_seeded_selection()

	_check(FileAccess.get_file_as_string(CATALOG_PATH) == before,
		"all operations leave the shipped catalog untouched")
	seed(5813)
	_check(randi() == expected_global, "no path consumes the global RNG")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_cistern_marquee_starwheel_vital_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _events() -> Array:
	return (catalog as Dictionary).get("events", [])


func _records_for(event_id: String) -> Array:
	var found: Array = []
	for record: Variant in _events():
		if record is Dictionary and (record as Dictionary).get("id") == event_id:
			found.append(record)
	return found


func _snap(hero_id: String, gold: int = BASE_GOLD,
		scraps: int = BASE_SCRAPS, hp: int = BASE_HP, max_hp: int = BASE_MAX_HP) -> Dictionary:
	return {"gold": gold, "scraps": scraps, "hero": {"id": hero_id, "hp": hp, "max_hp": max_hp}}


## Whole-number integer semantics shared with RunEventChoice._read_outcome_amount:
## a native int, or a finite float with no fractional part.
func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number
	return false


func _entry_for(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry: Variant in preview.get("choices", []):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


# AC1: exact authored records, in authored choice order.
func _test_authentic_records() -> void:
	var seen_trade_ids: Dictionary = {}
	for event_id: String in EVENT_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var found := _records_for(event_id)
		_check(found.size() == 1, "new record appears exactly once: " + event_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		_check(record.get("title") == spec["title"], "title is authentic: " + event_id)
		_check(record.get("description") == spec["description"], "description is authentic: " + event_id)
		_check(record.get("required_hero") == spec["hero"], "required_hero is authentic: " + event_id)
		_check(record.size() == 5, "record has exactly the five authored keys: " + event_id)
		var choices: Array = record.get("choices", [])
		var spec_choices: Dictionary = spec["choices"]
		_check(choices.size() == 3, "exactly three choices: " + event_id)
		var seen: Dictionary = {}
		var order: Array = CHOICE_ORDER[event_id]
		for index in range(choices.size()):
			var choice_raw: Variant = choices[index]
			_check(choice_raw is Dictionary, "choice is a dictionary: " + event_id)
			if not choice_raw is Dictionary:
				continue
			var choice_dict: Dictionary = choice_raw
			var choice_id: String = choice_dict.get("id", "")
			_check(choice_id == order[index],
				"choice appears in the authored order: " + event_id + "/" + choice_id)
			_check(not seen.has(choice_id), "choice id unique: " + event_id + "/" + choice_id)
			seen[choice_id] = true
			_check(spec_choices.has(choice_id), "choice id is authored: " + event_id + "/" + choice_id)
			if not spec_choices.has(choice_id):
				continue
			var row: Array = spec_choices[choice_id]
			_check(choice_dict.get("text") == row[0],
				"choice text is authentic: " + event_id + "/" + choice_id)
			var outcome: Variant = choice_dict.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4,
				"outcome carries exactly four numeric fields: " + event_id + "/" + choice_id)
			if not outcome is Dictionary:
				continue
			var out: Dictionary = outcome
			_check(_is_integral(out.get("gold")) and _is_integral(out.get("scraps"))
				and _is_integral(out.get("hp")) and _is_integral(out.get("max_hp")),
				"outcome fields are signed whole-number integers: " + event_id + "/" + choice_id)
			_check(out.get("gold") == row[1] and out.get("scraps") == row[2]
				and out.get("hp") == row[3] and out.get("max_hp") == row[4],
				"signed deltas match the authored row: " + event_id + "/" + choice_id)
			if choice_id != "leave":
				_check(not seen_trade_ids.has(choice_id),
					"trade choice id is unique across the batch: " + choice_id)
				seen_trade_ids[choice_id] = true
		_check(seen.size() == 3, "all three authored choice ids present: " + event_id)
		var leave: Array = spec_choices["leave"]
		_check(leave[1] == 0 and leave[2] == 0 and leave[3] == 0 and leave[4] == 0,
			"authored leave row is zero delta: " + event_id)
	_check(seen_trade_ids.size() == 6, "all six named trade choice ids are unique")


# AC1: three named pre-existing anchors still present (presence only).
func _test_anchor_records_present() -> void:
	for event_id: String in ANCHOR_IDS:
		_check(_records_for(event_id).size() == 1,
			"anchor record still present exactly once: " + event_id)


# AC1: every catalog entry keeps its authored shape and unique ID, so no
# earlier addition was removed, duplicated or malformed (no totals, no
# ordered ID list); the real gate also revalidates the whole shipped catalog.
func _test_older_records_intact() -> void:
	var seen_ids: Dictionary = {}
	for record_raw: Variant in _events():
		if not record_raw is Dictionary:
			_check(false, "catalog entry is a dictionary")
			continue
		var record: Dictionary = record_raw
		var event_id := String(record.get("id", ""))
		_check(not event_id.is_empty() and not seen_ids.has(event_id),
			"catalog entry id is unique: " + event_id)
		seen_ids[event_id] = true
		_check(record.size() == 5 and record.has("id") and record.has("title")
			and record.has("description") and record.has("required_hero")
			and record.has("choices"),
			"entry keeps exactly the five authored keys: " + event_id)
		var choices: Array = record.get("choices", [])
		_check(choices.size() == 3, "entry keeps exactly three choices: " + event_id)
		for choice_raw: Variant in choices:
			if not choice_raw is Dictionary:
				_check(false, "choice is a dictionary: " + event_id)
				continue
			var choice: Dictionary = choice_raw
			_check(choice.size() == 3 and choice.has("id") and choice.has("text")
				and choice.has("outcome"),
				"choice keeps exactly id/text/outcome: " + event_id)
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4
				and (outcome as Dictionary).has("gold")
				and (outcome as Dictionary).has("scraps")
				and (outcome as Dictionary).has("hp")
				and (outcome as Dictionary).has("max_hp"),
				"outcome keeps exactly the four vital keys: " + event_id)
	_check(RunV3HeroVitalEventGate.new(PARTY).is_valid(),
		"the full shipped catalog still parses through the real gate")


# AC2: real gate admission per required hero, with fail-closed refusals.
func _test_admission_and_offers() -> void:
	for event_id: String in EVENT_ORDER:
		var hero_id: String = SPECS[event_id]["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTY)
		_check(gate.is_valid(), "four-hero party builds a valid gate: " + event_id)
		var offered_ids: Array = []
		var genuine: Dictionary = {}
		for offer: Dictionary in gate.get_offers():
			offered_ids.append(String(offer.get("id", "")))
			if String(offer.get("id", "")) == event_id:
				genuine = offer
		_check(offered_ids.count(event_id) == 1,
			"record offered exactly once to its party: " + event_id)
		_check(not genuine.is_empty(), "genuine offered record found: " + event_id)
		var visit := gate.enter(event_id, _snap(hero_id))
		_check(visit != null and visit.is_valid() and not visit.is_claimed()
			and visit.get_event_id() == event_id,
			"admits its living matching hero at 17/30: " + event_id)
		var record_visit := gate.enter(genuine, _snap(hero_id))
		_check(record_visit != null and record_visit.is_valid()
			and not record_visit.is_claimed(),
			"admits the genuine offered record dictionary: " + event_id)
		_check(gate.enter(event_id, _snap(hero_id, BASE_GOLD, BASE_SCRAPS, 0, BASE_MAX_HP)) == null,
			"refuses a Torn (0 HP) required hero: " + event_id)
		var forged: Dictionary = genuine.duplicate(true)
		forged["title"] = "A Forged Title"
		_check(gate.enter(forged, _snap(hero_id)) == null,
			"refuses a forged record: " + event_id)
		_check(gate.enter("v3_unknown_bogus_event", _snap(hero_id)) == null,
			"refuses an unknown event id: " + event_id)
		_check(gate.enter(event_id, _snap("warden")) == null,
			"refuses a wrong-hero snapshot: " + event_id)
	var absent_gate := RunV3HeroVitalEventGate.new(ABSENT_PARTY)
	_check(absent_gate.is_valid(),
		"party without the required heroes is a valid gate")
	for event_id: String in EVENT_ORDER:
		var absent_ids: Array = []
		for offer: Dictionary in absent_gate.get_offers():
			absent_ids.append(String(offer.get("id", "")))
		_check(not absent_ids.has(event_id),
			"not offered without its required hero: " + event_id)
		_check(absent_gate.enter(event_id, _snap(SPECS[event_id]["hero"])) == null,
			"refuses entry for a hero outside the party: " + event_id)


# AC3: preview and settlement match the independent funded table, one fresh
# gate/visit per choice, with the one-claim-only latch.
func _test_settlement_table() -> void:
	for event_id: String in EVENT_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var hero_id: String = spec["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTY)
		var expected_choices: Dictionary = EXPECTED[event_id]
		var spec_choices: Dictionary = spec["choices"]
		for choice_id: String in expected_choices:
			var row: Array = spec_choices[choice_id]
			var expected_row: Array = expected_choices[choice_id]
			var base := _snap(hero_id)
			var base_copy := base.duplicate(true)
			var visit := gate.enter(event_id, base)
			_check(visit != null and visit.is_valid(),
				"fresh funded visit for: " + event_id + "/" + choice_id)
			if visit == null:
				continue
			var expected_state := {
				"gold": expected_row[0],
				"scraps": expected_row[1],
				"hero": {"id": hero_id, "hp": expected_row[2], "max_hp": expected_row[3]},
			}
			var preview := visit.preview_vital_choices(base)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"preview ok: " + event_id + "/" + choice_id)
			var entry := _entry_for(preview, choice_id)
			_check(entry.get("gold_delta") == int(row[1])
				and entry.get("scraps_delta") == int(row[2])
				and entry.get("hp_delta") == int(row[3])
				and entry.get("max_hp_delta") == int(row[4])
				and entry.get("affordable") == true
				and entry.get("state") == expected_state,
				"preview quotes the independent funded result: "
				+ event_id + "/" + choice_id)
			_check(not visit.is_claimed() and visit.is_valid() and base == base_copy,
				"preview is non-claiming and inputs stay detached: "
				+ event_id + "/" + choice_id)
			var receipt := visit.choose_with_vitals(choice_id, base)
			_check(receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": choice_id,
				"state": expected_state,
			}, "settlement equals the independent funded result: "
				+ event_id + "/" + choice_id)
			_check(visit.is_claimed() and not visit.is_valid() and base == base_copy,
				"claim latches once and leaves inputs detached: "
				+ event_id + "/" + choice_id)
			_check(visit.choose_with_vitals(choice_id, base).get("ok") == false,
				"second claim after success fails: "
				+ event_id + "/" + choice_id)
			var alternate := ""
			for other: String in spec_choices:
				if other != choice_id:
					alternate = other
					break
			_check(visit.choose_with_vitals(alternate, base).get("ok") == false,
				"alternate claim refuses on the latched visit: "
				+ event_id + "/" + choice_id)


# AC3: an unknown choice fails closed and the visit stays claimable.
func _test_unknown_choice() -> void:
	for event_id: String in EVENT_ORDER:
		var hero_id: String = SPECS[event_id]["hero"]
		var base := _snap(hero_id)
		var base_copy := base.duplicate(true)
		var gate := RunV3HeroVitalEventGate.new(PARTY)
		var visit := gate.enter(event_id, base)
		_check(visit != null and visit.is_valid(),
			"unknown-choice visit opens: " + event_id)
		if visit == null:
			continue
		_check(visit.choose_with_vitals("not_a_real_choice", base).get("ok") == false
			and visit.is_valid() and not visit.is_claimed() and base == base_copy,
			"unknown choice refuses without mutation: " + event_id)
		var leave_receipt := visit.choose_with_vitals("leave", base)
		_check(leave_receipt.get("ok") == true
			and leave_receipt.get("state") == base_copy
			and leave_receipt.get("state", {}).get("hero", {}).get("id") == hero_id
			and visit.is_claimed() and not visit.is_valid(),
			"Leave still works after the unknown refusal: " + event_id)
		_check(visit.choose_with_vitals("leave", base).get("ok") == false,
			"double claiming Leave also refuses once claimed: " + event_id)


# AC4: a zero-gold, zero-scraps party with the required hero at 1/10 HP makes
# every paid/risky trade fail closed without consuming the visit, and the same
# unclaimed visit still settles the free Leave.
func _test_starved_refusals_then_leave() -> void:
	for event_id: String in EVENT_ORDER:
		var hero_id: String = SPECS[event_id]["hero"]
		var spec_choices: Dictionary = SPECS[event_id]["choices"]
		for choice_id: String in spec_choices:
			if choice_id == "leave":
				continue
			var starved := _snap(hero_id, 0, 0, 1, 10)
			var starved_copy := starved.duplicate(true)
			var gate := RunV3HeroVitalEventGate.new(PARTY)
			var visit := gate.enter(event_id, starved)
			_check(visit != null and visit.is_valid(),
				"starved visit opens: " + event_id + "/" + choice_id)
			if visit == null:
				continue
			var preview := visit.preview_vital_choices(starved)
			var entry := _entry_for(preview, choice_id)
			_check(preview.get("ok") == true and entry.get("affordable") == false,
				"starved trade previews as unavailable: " + event_id + "/" + choice_id)
			var refused := visit.choose_with_vitals(choice_id, starved)
			_check(refused.get("ok") == false and visit.is_valid() and not visit.is_claimed()
				and refused.get("state") == starved_copy and starved == starved_copy,
				"starved trade refuses without consuming the visit: "
				+ event_id + "/" + choice_id)
			var recovered := visit.choose_with_vitals("leave", starved)
			_check(recovered.get("ok") == true
				and recovered.get("state") == starved_copy
				and recovered.get("state", {}).get("hero", {}).get("id") == hero_id
				and visit.is_claimed() and not visit.is_valid(),
				"same starved visit still settles free Leave: "
				+ event_id + "/" + choice_id)


# AC4: focused scraps/gold/HP/max-HP/full-health-waste boundary witnesses.
func _test_threshold_witnesses() -> void:
	for case_raw: Array in THRESHOLD:
		var event_id: String = case_raw[0]
		var choice_id: String = case_raw[1]
		var hero_id: String = SPECS[event_id]["hero"]
		var opening := _snap(hero_id, case_raw[2], case_raw[3], case_raw[4], case_raw[5])
		var want_affordable: bool = case_raw[6]
		var gate := RunV3HeroVitalEventGate.new(PARTY)
		var visit := gate.enter(event_id, opening)
		_check(visit != null and visit.is_valid(),
			"threshold visit opens: " + event_id + "/" + choice_id)
		if visit == null:
			continue
		var preview := visit.preview_vital_choices(opening)
		var entry := _entry_for(preview, choice_id)
		_check(entry.get("affordable") == want_affordable,
			"threshold affordability is exact: " + event_id + "/" + choice_id
			+ " (want " + str(want_affordable) + ")")
		if not want_affordable:
			var refused := visit.choose_with_vitals(choice_id, opening)
			_check(refused.get("ok") == false and visit.is_valid()
				and not visit.is_claimed(),
				"below-threshold trade fails closed without consuming the visit: "
				+ event_id + "/" + choice_id)


# AC4: target-only seeded actionable selection built from CURRENT offered IDs
# (never a hardcoded catalog length or full ID list), with replay agreement,
# a Torn-required-hero refusal and exhausted exclusions consuming no RNG.
func _test_seeded_selection() -> void:
	var wallet := {"gold": BASE_GOLD, "scraps": BASE_SCRAPS}
	var heroes := [
		{"id": "yarn_ranger", "hp": BASE_HP, "max_hp": BASE_MAX_HP},
		{"id": "rag_duelist", "hp": BASE_HP, "max_hp": BASE_MAX_HP},
		{"id": "button_golem", "hp": BASE_HP, "max_hp": BASE_MAX_HP},
		{"id": "warden", "hp": BASE_HP, "max_hp": BASE_MAX_HP},
	]
	var gate := RunV3HeroVitalEventGate.new(PARTY)
	_check(gate.is_valid(), "selection gate is valid")
	var offers := gate.get_offers()
	var seed_base := 9100
	for event_id: String in EVENT_ORDER:
		var excluded: Array = []
		for offer: Dictionary in offers:
			var oid: String = offer.get("id", "")
			if oid != event_id:
				excluded.append(oid)
		_check(not excluded.is_empty(), "dynamic exclusions are genuine: " + event_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_base
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_base
		oracle.randi_range(0, 0)
		var picked := gate.select_party_actionable_event(rng, excluded, wallet, heroes)
		_check(picked.get("ok") == true and picked.get("event", {}).get("id") == event_id,
			"seeded selection isolates the target event: " + event_id)
		_check(rng.state == oracle.state,
			"target-only selection consumes exactly one draw: " + event_id)
		var replay := RandomNumberGenerator.new()
		replay.seed = seed_base
		var picked_again := gate.select_party_actionable_event(replay, excluded, wallet, heroes)
		_check(picked_again.get("ok") == true
			and picked_again.get("event", {}).get("id") == event_id,
			"same seed replays the same isolated target: " + event_id)
		var hero_id: String = SPECS[event_id]["hero"]
		var visit := gate.enter(picked["event"], _snap(hero_id))
		_check(visit != null and visit.is_valid() and not visit.is_claimed()
			and visit.get_event_id() == event_id,
			"selected authentic record enters a fresh visit: " + event_id)
		seed_base += 7
	# A Torn (0 HP) required hero is ineligible to the selection, without RNG use.
	for event_id: String in EVENT_ORDER:
		var hero_id: String = SPECS[event_id]["hero"]
		var torn_heroes := heroes.duplicate(true)
		for item: Dictionary in torn_heroes:
			if item["id"] == hero_id:
				item["hp"] = 0
		var excluded: Array = []
		for offer: Dictionary in offers:
			if String(offer.get("id", "")) != event_id:
				excluded.append(offer["id"])
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		var before_state := rng.state
		var refused := gate.select_party_actionable_event(rng, excluded, wallet, torn_heroes)
		_check(refused.get("ok") == false and refused.get("event") == {}
			and rng.state == before_state,
			"Torn required hero is ineligible without advancing RNG: " + event_id)
	# Excluding every offered ID yields a failed selection without advancing RNG.
	var all_offered: Array = []
	for offer: Dictionary in offers:
		all_offered.append(offer["id"])
	var rng_all := RandomNumberGenerator.new()
	rng_all.seed = 4243
	var all_before := rng_all.state
	var none_left := gate.select_party_actionable_event(rng_all, all_offered, wallet, heroes)
	_check(none_left.get("ok") == false and none_left.get("event") == {}
		and rng_all.state == all_before,
		"excluding every offered ID fails selection without advancing RNG")
