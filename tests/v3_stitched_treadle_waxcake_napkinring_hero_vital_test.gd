extends SceneTree
## Focused headless contract test for the three appended doll-scale corridor
## Stitched hero vitality Events in data/events/v3_hero_vital_events.json:
## The Sewing Treadle (Tinker), The Tailor's Wax Cake (Yarn Ranger) and
## The Bent Napkin Ring (Button Golem).
## Exercises only the shipped catalog plus the real RunV3HeroVitalEventGate /
## RunEventChoice services: presence-only anchor checks (never a catalog total
## or an ordered ID list), per-entry integrity for the three authored records
## and the whole catalog, real four-hero-party admission and offer negatives,
## authored funded settlements from an independent expected table, and starved
## fail-closed refusals that leave the visit claimable by Leave, including
## unknown/replay refusals.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

## Prior named anchors that must still exist (presence only, no totals).
const ANCHOR_IDS := [
	"v3_tinker_copper_needle_greenhouse",
	"v3_yarn_ranger_starladder_bolas",
	"v3_button_golem_rivet_choir",
]

const EVENT_ORDER := [
	"v3_tinker_sewing_treadle",
	"v3_yarn_ranger_tailors_wax_cake",
	"v3_button_golem_bent_napkin_ring",
]

## Task-local transcription of the authored rows. Each choice row is
## [text, gold, scraps, hp, max_hp]; the outcome keys must be exactly the
## four signed integers, zeros included.
const SPECS := {
	"v3_tinker_sewing_treadle": {
		"title": "The Sewing Treadle",
		"description": "A house-sized cast-iron treadle rises through a crack in the floorboards. The Tinker's crooked goggles catch an amber spark beneath its loose brass hinge, while a thread of red light shivers through the pedal.",
		"hero": "tinker",
		"choices": {
			"brace_treadle_rivet": ["Patch the hinge into sturdier stuffing", 0, -2, 3, 2],
			"strip_treadle_axle": ["Pawn the axle and surrender a seam", 27, 0, 0, -2],
			"leave": ["Let the great pedal fall quiet", 0, 0, 0, 0],
		},
	},
	"v3_yarn_ranger_tailors_wax_cake": {
		"title": "The Tailor's Wax Cake",
		"description": "A moon-pale cake of tailor's wax hangs above a skirting-board passage like a second ceiling. The Yarn Ranger catches it with braided bolas; tiny stitched birds wait on the ledge for the falling shavings.",
		"hero": "yarn_ranger",
		"choices": {
			"bind_wax_roost": ["Buy warm wax to seal the torn wool", -15, 0, 6, 1],
			"scrape_wax_heart": ["Trade a lasting seam for waxy salvage", 0, 3, 0, -2],
			"leave": ["Leave the little birds to their candlelit roost", 0, 0, 0, 0],
		},
	},
	"v3_button_golem_bent_napkin_ring": {
		"title": "The Bent Napkin Ring",
		"description": "A bent brass napkin ring fills a gap between two cupboard walls. The Button Golem's wide button fists hold back its closing clasp as old oxblood ribbon wraps the little corridor like a noose.",
		"hero": "button_golem",
		"choices": {
			"reinforce_ring_stitch": ["Sew the brass clasp into a tougher shell", 0, -3, 0, 3],
			"pawn_brass_clasp": ["Pawn a button seam with the broken clasp", 25, 0, 0, -2],
			"leave": ["Ease the brass ring back into the shadows", 0, 0, 0, 0],
		},
	},
}

## Funded precondition shared by every settlement check: wallet 40 gold / 4
## scraps, required hero at 20 of 30 HP.
const BASE_GOLD := 40
const BASE_SCRAPS := 4
const BASE_HP := 20
const BASE_MAX_HP := 30

## Expected resulting [gold, scraps, hp, max_hp] from the funded 40/4, 20/30
## opening, written independently of the JSON deltas rather than recomputed
## from them.
const EXPECTED := {
	"v3_tinker_sewing_treadle": {
		"brace_treadle_rivet": [40, 2, 23, 32],
		"strip_treadle_axle": [67, 4, 20, 28],
		"leave": [40, 4, 20, 30],
	},
	"v3_yarn_ranger_tailors_wax_cake": {
		"bind_wax_roost": [25, 4, 26, 31],
		"scrape_wax_heart": [40, 7, 20, 28],
		"leave": [40, 4, 20, 30],
	},
	"v3_button_golem_bent_napkin_ring": {
		"reinforce_ring_stitch": [40, 1, 20, 33],
		"pawn_brass_clasp": [65, 4, 20, 28],
		"leave": [40, 4, 20, 30],
	},
}

## A genuine four-of-eight Stitched party containing every required hero.
const PARTIES := {
	"v3_tinker_sewing_treadle": ["tinker", "yarn_ranger", "button_golem", "warden"],
	"v3_yarn_ranger_tailors_wax_cake": ["tinker", "yarn_ranger", "button_golem", "warden"],
	"v3_button_golem_bent_napkin_ring": ["tinker", "yarn_ranger", "button_golem", "warden"],
}

## The party that omits exactly one event's required hero (the Seamstress takes
## that hero's place, so the party keeps four distinct canonical IDs).
const ABSENT_PARTIES := {
	"v3_tinker_sewing_treadle": ["seamstress", "yarn_ranger", "button_golem", "warden"],
	"v3_yarn_ranger_tailors_wax_cake": ["tinker", "seamstress", "button_golem", "warden"],
	"v3_button_golem_bent_napkin_ring": ["tinker", "yarn_ranger", "seamstress", "warden"],
}

## Starved fail-closed cases: event -> list of {choice, gold, scraps, hp,
## max_hp} opening snapshots where the named trade must refuse (gold-starved,
## scraps-starved, or a max-HP cut that would drop below the floor of 10),
## without consuming the visit or mutating the snapshot.
const STARVED := {
	"v3_tinker_sewing_treadle": [
		{"choice": "brace_treadle_rivet", "gold": 40, "scraps": 1, "hp": 20, "max_hp": 30},
		{"choice": "strip_treadle_axle", "gold": 40, "scraps": 4, "hp": 10, "max_hp": 11},
	],
	"v3_yarn_ranger_tailors_wax_cake": [
		{"choice": "bind_wax_roost", "gold": 14, "scraps": 4, "hp": 20, "max_hp": 30},
		{"choice": "scrape_wax_heart", "gold": 40, "scraps": 4, "hp": 10, "max_hp": 11},
	],
	"v3_button_golem_bent_napkin_ring": [
		{"choice": "reinforce_ring_stitch", "gold": 40, "scraps": 2, "hp": 20, "max_hp": 30},
		{"choice": "pawn_brass_clasp", "gold": 40, "scraps": 4, "hp": 10, "max_hp": 11},
	],
}

## Any valid canonical four-hero party proves the whole shipped catalog parses.
const CATALOG_PARSE_PARTY := ["tinker", "yarn_ranger", "button_golem", "warden"]

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary = {}


func _initialize() -> void:
	var before := FileAccess.get_file_as_string(CATALOG_PATH)
	seed(5941)
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

	_check(FileAccess.get_file_as_string(CATALOG_PATH) == before,
		"all operations leave the shipped catalog untouched")
	seed(5941)
	_check(randi() == expected_global, "no path consumes the global RNG")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_treadle_waxcake_napkinring_hero_vital_test: ",
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


# AC1: exact authored records, matched by ID (never by position or total).
func _test_authentic_records() -> void:
	for event_id: String in EVENT_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var found := _records_for(event_id)
		_check(found.size() == 1, "new record appears exactly once: " + event_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		_check(record.get("title") == spec["title"], "title is authentic: " + event_id)
		_check(record.get("description") == spec["description"],
			"description is authentic: " + event_id)
		_check(record.get("required_hero") == spec["hero"],
			"required_hero is authentic: " + event_id)
		_check(record.size() == 5, "record has exactly the five authored keys: " + event_id)
		var choices: Array = record.get("choices", [])
		var spec_choices: Dictionary = spec["choices"]
		_check(choices.size() == 3, "exactly three choices: " + event_id)
		var seen: Dictionary = {}
		for choice: Variant in choices:
			_check(choice is Dictionary, "choice is a dictionary: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_dict: Dictionary = choice
			var choice_id: String = choice_dict.get("id", "")
			_check(not seen.has(choice_id), "choice id unique: " + event_id + "/" + choice_id)
			seen[choice_id] = true
			_check(spec_choices.has(choice_id), "choice id is authored: " + event_id + "/" + choice_id)
			if not spec_choices.has(choice_id):
				continue
			var row: Array = spec_choices[choice_id]
			_check(choice_dict.get("text") == row[0],
				"choice text is authentic: " + event_id + "/" + choice_id)
			_check(choice_dict.size() == 3 and choice_dict.has("id")
				and choice_dict.has("text") and choice_dict.has("outcome"),
				"choice keeps exactly id/text/outcome: " + event_id + "/" + choice_id)
			var outcome: Variant = choice_dict.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4,
				"outcome carries exactly four numeric fields: " + event_id + "/" + choice_id)
			if not outcome is Dictionary:
				continue
			var out: Dictionary = outcome
			_check(out.has("gold") and out.has("scraps") and out.has("hp")
				and out.has("max_hp"),
				"outcome carries the four vital keys: " + event_id + "/" + choice_id)
			_check(_is_integral(out.get("gold")) and _is_integral(out.get("scraps"))
				and _is_integral(out.get("hp")) and _is_integral(out.get("max_hp")),
				"outcome fields are signed whole-number integers: " + event_id + "/" + choice_id)
			_check(out.get("gold") == row[1] and out.get("scraps") == row[2]
				and out.get("hp") == row[3] and out.get("max_hp") == row[4],
				"signed deltas match the authored row: " + event_id + "/" + choice_id)
		_check(seen.size() == 3, "all three authored choice ids present: " + event_id)
		var leave: Array = spec_choices["leave"]
		_check(leave[1] == 0 and leave[2] == 0 and leave[3] == 0 and leave[4] == 0,
			"authored leave row is zero delta: " + event_id)


# AC1: three named pre-existing anchors still present (presence only).
func _test_anchor_records_present() -> void:
	for event_id: String in ANCHOR_IDS:
		_check(_records_for(event_id).size() == 1,
			"anchor record still present exactly once: " + event_id)


# AC1/AC4: every catalog entry keeps its authored shape and unique ID, so no
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
	for event_id: String in EVENT_ORDER:
		_check(seen_ids.has(event_id), "catalog still holds the new record: " + event_id)
	_check(RunV3HeroVitalEventGate.new(CATALOG_PARSE_PARTY).is_valid(),
		"the full shipped catalog still parses through the real gate")


# AC2: real gate admission per required hero, with fail-closed refusals.
func _test_admission_and_offers() -> void:
	for event_id: String in EVENT_ORDER:
		var hero_id: String = SPECS[event_id]["hero"]
		var party: Array = PARTIES[event_id]
		_check(party.has(hero_id), "party contains the required hero: " + event_id)
		var gate := RunV3HeroVitalEventGate.new(party)
		_check(gate.is_valid(), "four-hero party builds a valid gate: " + event_id)
		var offered_ids: Array = []
		for offer: Dictionary in gate.get_offers():
			offered_ids.append(String(offer.get("id", "")))
		_check(offered_ids.count(event_id) == 1,
			"record offered exactly once to its party: " + event_id)
		var visit := gate.enter(event_id, _snap(hero_id))
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"admits its living matching hero at 20/30: " + event_id)
		_check(visit != null and visit.get_event_id() == event_id,
			"admitted visit binds the canonical record: " + event_id)
		_check(gate.enter(event_id, _snap(hero_id, BASE_GOLD, BASE_SCRAPS, 0, BASE_MAX_HP)) == null,
			"refuses a dead (0 HP) required hero: " + event_id)
		var absent_party: Array = ABSENT_PARTIES[event_id]
		_check(not absent_party.has(hero_id),
			"absent party omits the required hero: " + event_id)
		var absent_seen: Dictionary = {}
		for absent_hero: Variant in absent_party:
			absent_seen[absent_hero] = true
		_check(absent_party.size() == 4 and absent_seen.size() == 4
			and absent_seen.has("seamstress"),
			"absent party keeps four distinct canonical IDs incl. the Seamstress: "
			+ event_id)
		var absent_gate := RunV3HeroVitalEventGate.new(absent_party)
		_check(absent_gate.is_valid(), "party without the hero is a valid gate: " + event_id)
		var absent_ids: Array = []
		for offer: Dictionary in absent_gate.get_offers():
			absent_ids.append(String(offer.get("id", "")))
		_check(not absent_ids.has(event_id), "not offered without its hero: " + event_id)
		_check(absent_gate.enter(event_id, _snap(hero_id)) == null,
			"refuses entry for a hero outside the party: " + event_id)
		_check(gate.enter(event_id, _snap("warden")) == null,
			"refuses an unrelated hero snapshot at entry: " + event_id)


# AC3: preview and settlement match the independent funded table, one fresh
# gate/visit per choice (Leave included as its own fresh visit), with the
# one-claim-only latch.
func _test_settlement_table() -> void:
	for event_id: String in EVENT_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var hero_id: String = spec["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
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


# AC4: an unknown choice fails closed and the visit stays claimable.
func _test_unknown_choice() -> void:
	for event_id: String in EVENT_ORDER:
		var hero_id: String = SPECS[event_id]["hero"]
		var base := _snap(hero_id)
		var base_copy := base.duplicate(true)
		var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
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


# AC4: starved openings fail closed without consuming the visit or mutating
# the snapshot, and the same unclaimed visit still settles the free Leave.
func _test_starved_refusals_then_leave() -> void:
	for event_id: String in EVENT_ORDER:
		var hero_id: String = SPECS[event_id]["hero"]
		for starve_raw: Variant in STARVED[event_id]:
			var starve_case: Dictionary = starve_raw
			var choice_id: String = starve_case["choice"]
			var starved := _snap(hero_id, starve_case["gold"], starve_case["scraps"],
				starve_case["hp"], starve_case["max_hp"])
			var starved_copy := starved.duplicate(true)
			var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
			var visit := gate.enter(event_id, starved)
			_check(visit != null and visit.is_valid(),
				"starved visit opens: " + event_id + "/" + choice_id)
			if visit == null:
				continue
			var preview := visit.preview_vital_choices(starved)
			var entry := _entry_for(preview, choice_id)
			_check(preview.get("ok") == true and entry.get("affordable") == false,
				"starved trade previews as unavailable: " + event_id + "/" + choice_id)
			_check(entry.get("state") == starved_copy,
				"starved preview keeps the unchanged snapshot: "
				+ event_id + "/" + choice_id)
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
