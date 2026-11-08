extends SceneTree
## Focused headless contract test for the three appended doll-scale Stitched
## hero vitality crossroad Events in data/events/v3_hero_vital_events.json:
## The Stovepipe Hinge (Warden), The Shadow Embroidery Screen (Seamstress)
## and The Hollow Windsock (Scarecrow). Exercises only the shipped catalog
## plus the real RunV3HeroVitalEventGate / RunEventChoice services:
## presence-only anchor checks (never a catalog total or an ordered ID
## list), per-entry integrity for the three authored records, real
## four-hero-party admission with absent-hero, wrong-hero and Torn refusals,
## authored funded settlements from an independent expected table, and
## starved fail-closed refusals that leave the visit claimable by Leave,
## including unknown/replay refusals.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

## Prior named anchors that must still exist (presence only, no totals).
const ANCHOR_IDS := [
	"v3_warden_buckle_heart_ward",
	"v3_seamstress_crimson_quilt_surgeon",
	"v3_tinker_copper_needle_greenhouse",
]

const EVENT_ORDER := [
	"v3_warden_stovepipe_hinge",
	"v3_seamstress_shadow_embroidery_screen",
	"v3_scarecrow_hollow_windsock",
]

## Task-local transcription of the authored rows. Each choice row is
## [text, gold, scraps, hp, max_hp]; the outcome keys must be exactly the
## four signed integers, zeros included.
const SPECS := {
	"v3_warden_stovepipe_hinge": {
		"title": "The Stovepipe Hinge",
		"description": "A giant soot-black stovepipe leans through a narrow attic corridor. The Warden braces its buckled brass hinge with his quilted shield while a tiny ember glows behind the grate.",
		"hero": "warden",
		"choices": {
			"brace_soot_hinge": ["Stitch the hinge firm and reinforce the Warden's stuffing", 0, -2, 0, 3],
			"pry_stove_bolts": ["Burn some stuffing to salvage the blackened bolts", 24, 0, -5, 0],
			"leave": ["Leave the ember breathing behind the grate", 0, 0, 0, 0],
		},
	},
	"v3_seamstress_shadow_embroidery_screen": {
		"title": "The Shadow Embroidery Screen",
		"description": "An embroidery screen taller than the dolls blocks a moonlit passage. The Seamstress traces the silhouettes of lost puppets in its oxblood silk while an empty needle taps the wooden frame.",
		"hero": "seamstress",
		"choices": {
			"sew_shadow_lining": ["Buy silk and sew a lasting lining beneath the screen", -16, 0, 0, 2],
			"unpick_screen_memory": ["Unpick the Seamstress's own seam for ghostly threads", 0, 3, 0, -2],
			"leave": ["Let the puppet shadows hold their place", 0, 0, 0, 0],
		},
	},
	"v3_scarecrow_hollow_windsock": {
		"title": "The Hollow Windsock",
		"description": "A weather-beaten cloth windsock hangs from a doll-sized vent high in the corridor. The Scarecrow's ribbon-feather crows circle its hollow throat as cold air pulls straw from his sleeve.",
		"hero": "scarecrow",
		"choices": {
			"sew_windsock_heart": ["Stuff the windsock's heart and reinforce the Scarecrow", 0, -2, 0, 3],
			"strip_wind_seam": ["Trade a lasting seam for the wind's hidden coin", 27, 0, 0, -2],
			"leave": ["Let the wind swallow the crow calls", 0, 0, 0, 0],
		},
	},
}

## Funded precondition shared by every settlement check: wallet 60 gold / 6
## scraps, required hero at 20 of 30 HP.
const BASE_GOLD := 60
const BASE_SCRAPS := 6
const BASE_HP := 20
const BASE_MAX_HP := 30

## Expected resulting [gold, scraps, hp, max_hp] from the funded 60/6, 20/30
## opening, written independently of the JSON deltas rather than recomputed
## from them.
const EXPECTED := {
	"v3_warden_stovepipe_hinge": {
		"brace_soot_hinge": [60, 4, 20, 33],
		"pry_stove_bolts": [84, 6, 15, 30],
		"leave": [60, 6, 20, 30],
	},
	"v3_seamstress_shadow_embroidery_screen": {
		"sew_shadow_lining": [44, 6, 20, 32],
		"unpick_screen_memory": [60, 9, 20, 28],
		"leave": [60, 6, 20, 30],
	},
	"v3_scarecrow_hollow_windsock": {
		"sew_windsock_heart": [60, 4, 20, 33],
		"strip_wind_seam": [87, 6, 20, 28],
		"leave": [60, 6, 20, 30],
	},
}

## Genuine canonical four-of-eight Stitched party containing every new
## event's required hero.
const PARTY := ["warden", "seamstress", "scarecrow", "lantern_monk"]

## A living hero that is in the party but never an event's required hero:
## its snapshot must never admit a visit bound to another hero.
const WRONG_HERO := "lantern_monk"

## The party that omits exactly one event's required hero (a separate party
## per event, never one universal exclusion party).
const ABSENT_PARTIES := {
	"v3_warden_stovepipe_hinge": ["seamstress", "scarecrow", "lantern_monk", "rag_duelist"],
	"v3_seamstress_shadow_embroidery_screen": ["warden", "scarecrow", "lantern_monk", "rag_duelist"],
	"v3_scarecrow_hollow_windsock": ["warden", "seamstress", "lantern_monk", "rag_duelist"],
}

## Starved fail-closed cases: event -> list of {choice, gold, scraps, hp,
## max_hp} opening snapshots where the named trade must refuse (gold-starved,
## scraps-starved, a lethal HP loss, or a max-HP cut below the floor of 10)
## without consuming the visit or mutating the snapshot.
const STARVED := {
	"v3_warden_stovepipe_hinge": [
		{"choice": "brace_soot_hinge", "gold": 60, "scraps": 1, "hp": 20, "max_hp": 30},
		{"choice": "pry_stove_bolts", "gold": 60, "scraps": 6, "hp": 5, "max_hp": 30},
	],
	"v3_seamstress_shadow_embroidery_screen": [
		{"choice": "sew_shadow_lining", "gold": 15, "scraps": 6, "hp": 20, "max_hp": 30},
		{"choice": "unpick_screen_memory", "gold": 60, "scraps": 6, "hp": 10, "max_hp": 11},
	],
	"v3_scarecrow_hollow_windsock": [
		{"choice": "sew_windsock_heart", "gold": 60, "scraps": 1, "hp": 20, "max_hp": 30},
		{"choice": "strip_wind_seam", "gold": 60, "scraps": 6, "hp": 10, "max_hp": 11},
	],
}

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary = {}


func _initialize() -> void:
	var before := FileAccess.get_file_as_string(CATALOG_PATH)
	seed(4429)
	var expected_global := randi()

	catalog = JSON.parse_string(before)
	_check(catalog is Dictionary and catalog.get("events") is Array,
		"vital hero catalog parses as {events: []}")
	if not (catalog is Dictionary and catalog.get("events") is Array):
		_finish()
		return

	_test_authentic_records()
	_test_anchor_records_present()
	_test_catalog_ids_unique()
	_test_admission_and_offers()
	_test_settlement_table()
	_test_unknown_choice()
	_test_starved_refusals_then_leave()

	_check(FileAccess.get_file_as_string(CATALOG_PATH) == before,
		"all operations leave the shipped catalog untouched")
	seed(4429)
	_check(randi() == expected_global, "no path consumes the global RNG")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_stovepipe_screen_windsock_vital_test: ",
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


# AC1: exact authored records.
func _test_authentic_records() -> void:
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
		_check(seen.size() == 3, "all three authored choice ids present: " + event_id)
		var leave: Array = spec_choices["leave"]
		_check(leave[1] == 0 and leave[2] == 0 and leave[3] == 0 and leave[4] == 0,
			"authored leave row is zero delta: " + event_id)


# AC1: named pre-existing anchors still present (presence only).
func _test_anchor_records_present() -> void:
	for event_id: String in ANCHOR_IDS:
		_check(_records_for(event_id).size() == 1,
			"anchor record still present exactly once: " + event_id)


# AC1: no duplicated ID anywhere in the catalog and the real gate still
# accepts the whole shipped document (no totals, no ordered ID list).
func _test_catalog_ids_unique() -> void:
	var seen_ids: Dictionary = {}
	for record_raw: Variant in _events():
		if record_raw is Dictionary:
			var event_id := String((record_raw as Dictionary).get("id", ""))
			_check(not event_id.is_empty() and not seen_ids.has(event_id),
				"catalog entry id is unique: " + event_id)
			seen_ids[event_id] = true
	_check(RunV3HeroVitalEventGate.new(PARTY).is_valid(),
		"the full shipped catalog still parses through the real gate")


# AC2: real gate admission per required hero, with fail-closed refusals.
func _test_admission_and_offers() -> void:
	for event_id: String in EVENT_ORDER:
		var hero_id: String = SPECS[event_id]["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTY)
		_check(gate.is_valid(),
			"canonical four-hero party builds a valid gate: " + event_id)
		var offered_ids: Array = []
		for offer: Dictionary in gate.get_offers():
			offered_ids.append(String(offer.get("id", "")))
		_check(offered_ids.count(event_id) == 1,
			"record offered exactly once to its party: " + event_id)
		for other_id: String in EVENT_ORDER:
			_check(offered_ids.count(other_id) == 1,
				"every new record offered to the shared party: " + other_id)
		var visit := gate.enter(event_id, _snap(hero_id))
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"admits its living matching hero at 20/30: " + event_id)
		_check(visit != null and visit.get_event_id() == event_id,
			"admitted visit binds the canonical record: " + event_id)
		_check(gate.enter(event_id, _snap(hero_id, BASE_GOLD, BASE_SCRAPS, 0, BASE_MAX_HP)) == null,
			"refuses a Torn (0 HP) required hero: " + event_id)
		_check(gate.enter(event_id, _snap(WRONG_HERO)) == null,
			"refuses a wrong-hero snapshot: " + event_id)
		var absent_party: Array = ABSENT_PARTIES[event_id]
		_check(not absent_party.has(hero_id),
			"absent party omits the required hero: " + event_id)
		var absent_gate := RunV3HeroVitalEventGate.new(absent_party)
		_check(absent_gate.is_valid(),
			"party without the hero is a valid gate: " + event_id)
		var absent_ids: Array = []
		for offer: Dictionary in absent_gate.get_offers():
			absent_ids.append(String(offer.get("id", "")))
		_check(not absent_ids.has(event_id),
			"not offered without its hero: " + event_id)
		_check(absent_gate.enter(event_id, _snap(hero_id)) == null,
			"refuses entry for a hero outside the party: " + event_id)


# AC3: preview and settlement match the independent funded table, one fresh
# visit per choice, with the one-claim-only latch.
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


# AC4: an unknown choice fails closed and the visit stays claimable.
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
			_check(visit.choose_with_vitals("leave", starved).get("ok") == false,
				"replay after the free Leave fails: " + event_id + "/" + choice_id)
