extends SceneTree
## Focused headless contract test for the three appended doll-scale
## hero-gated Stitched hero vitality rescue Events in
## data/events/v3_hero_vital_events.json: The Quilt-Press Switch (Warden),
## The Puppet-Lamp Infirmary (Seamstress) and The Spectacle Footbridge
## (Tinker). Exercises only the shipped catalog plus the real
## RunV3HeroVitalEventGate / RunEventChoice services: presence-only anchor
## checks (never a catalog total or an ordered ID list), per-entry integrity
## for the three authored records and the whole catalog, real four-hero-party
## admission and offer negatives, a dynamically excluded per-ID seeded
## selector, authored funded settlements from an independent expected table,
## and starved fail-closed refusals that leave the visit claimable by Leave,
## including unknown/replay refusals and a full-HP paid-heal no-waste witness.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

## Prior named anchors that must still exist (presence only, no totals).
const ANCHOR_IDS := [
    "v3_warden_buckle_heart_ward",
    "v3_seamstress_stitchglass_hourhouse",
    "v3_tinker_windup_birdcage",
    "v3_scarecrow_inkwell_thresher",
    "v3_yarn_ranger_sockdrawer_aviary",
]

const EVENT_ORDER := [
    "v3_warden_quiltpress_switch",
    "v3_seamstress_puppetlamp_infirmary",
    "v3_tinker_spectacle_footbridge",
]

## Task-local transcription of the authored rows. Each choice row is
## [text, gold, scraps, hp, max_hp]; the outcome keys must be exactly the
## four signed integers, zeros included.
const SPECS := {
    "v3_warden_quiltpress_switch": {
        "title": "The Quilt-Press Switch",
        "description": "A brass quilt press towers above a narrow skirting-board path, its stack of oxblood blankets held by a single bent lever; the Warden braces the lever with a huge round patchwork shield.",
        "hero": "warden",
        "choices": {
            "wedge_shield_under_press": ["Spend 2 scraps to pad the shield brace (+2 max HP)", 0, -2, 0, 2],
            "strip_brass_counterweight": ["Strip the falling brass weight (lose 5 HP; gain 22 gold)", 22, 0, -5, 0],
            "leave": ["Let the enormous quilt press settle in silence", 0, 0, 0, 0],
        },
    },
    "v3_seamstress_puppetlamp_infirmary": {
        "title": "The Puppet-Lamp Infirmary",
        "description": "A milk-glass bedside lamp shelters a row of tiny sleeping rag dolls, its cracked shade bound with crimson thread; the Seamstress lifts her oversized needle to the frayed pull-cord.",
        "hero": "seamstress",
        "choices": {
            "stitch_lamp_shade": ["Pay 15 gold for warm lamp-lining (heal 9 HP)", -15, 0, 9, 0],
            "sell_crimson_cord": ["Sell 2 max HP of crimson cord for 25 gold", 25, 0, 0, -2],
            "leave": ["Leave the little dolls beneath their amber light", 0, 0, 0, 0],
        },
    },
    "v3_tinker_spectacle_footbridge": {
        "title": "The Spectacle Footbridge",
        "description": "A giant pair of tarnished spectacles spans a black rain gutter, one cracked lens turning slowly on a gear hinge; the Tinker studies its screws through mismatched goggles.",
        "hero": "tinker",
        "choices": {
            "tighten_spectacle_hinge": ["Spend 3 scraps reinforcing the gear hinge (+3 max HP)", 0, -3, 0, 3],
            "pocket_lens_prisms": ["Salvage loose lens prisms (lose 6 HP; gain 3 scraps)", 0, 3, -6, 0],
            "leave": ["Leave the rain shining through the broken spectacles", 0, 0, 0, 0],
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
    "v3_warden_quiltpress_switch": {
        "wedge_shield_under_press": [60, 4, 20, 32],
        "strip_brass_counterweight": [82, 6, 15, 30],
        "leave": [60, 6, 20, 30],
    },
    "v3_seamstress_puppetlamp_infirmary": {
        "stitch_lamp_shade": [45, 6, 29, 30],
        "sell_crimson_cord": [85, 6, 20, 28],
        "leave": [60, 6, 20, 30],
    },
    "v3_tinker_spectacle_footbridge": {
        "tighten_spectacle_hinge": [60, 3, 20, 33],
        "pocket_lens_prisms": [60, 9, 14, 30],
        "leave": [60, 6, 20, 30],
    },
}

## A genuine four-of-eight Stitched party containing all three required heroes.
const PARTY := ["warden", "seamstress", "tinker", "lantern_monk"]

## Another valid four-hero party that knows none of the three required heroes.
const ABSENT_PARTY := ["lantern_monk", "rag_duelist", "scarecrow", "yarn_ranger"]

## Starved fail-closed cases: event -> list of {choice, gold, scraps, hp,
## max_hp} opening snapshots where the named trade must refuse (gold-starved,
## scraps-starved, a self-harm loss that would leave less than 1 HP, a pure
## paid heal at full HP that must not waste gold, or a max-HP cut below the
## floor of 10), without consuming the visit or mutating the snapshot.
## The Puppet-Lamp Infirmary carries three witnesses: both trades plus the
## full-HP paid-heal rule; the other two events carry two each.
const STARVED := {
    "v3_warden_quiltpress_switch": [
        {"choice": "wedge_shield_under_press", "gold": 60, "scraps": 1, "hp": 20, "max_hp": 30},
        {"choice": "strip_brass_counterweight", "gold": 60, "scraps": 6, "hp": 5, "max_hp": 30},
    ],
    "v3_seamstress_puppetlamp_infirmary": [
        {"choice": "stitch_lamp_shade", "gold": 14, "scraps": 6, "hp": 20, "max_hp": 30},
        {"choice": "stitch_lamp_shade", "gold": 60, "scraps": 6, "hp": 30, "max_hp": 30},
        {"choice": "sell_crimson_cord", "gold": 60, "scraps": 6, "hp": 10, "max_hp": 11},
    ],
    "v3_tinker_spectacle_footbridge": [
        {"choice": "tighten_spectacle_hinge", "gold": 60, "scraps": 2, "hp": 20, "max_hp": 30},
        {"choice": "pocket_lens_prisms", "gold": 60, "scraps": 6, "hp": 6, "max_hp": 30},
    ],
}

## Expected starved witness count per event, so no fail-closed branch is
## silently missing (counts are per-event, never a catalog total).
const STARVED_COUNTS := {
    "v3_warden_quiltpress_switch": 2,
    "v3_seamstress_puppetlamp_infirmary": 3,
    "v3_tinker_spectacle_footbridge": 2,
}

## Any valid canonical four-hero party proves the whole shipped catalog parses.
const CATALOG_PARSE_PARTY := ["warden", "tinker", "lantern_monk", "scarecrow"]

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary = {}


func _initialize() -> void:
    var before := FileAccess.get_file_as_string(CATALOG_PATH)
    seed(5571)
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
    _test_per_id_selection()
    _test_settlement_table()
    _test_unknown_choice()
    _test_starved_refusals_then_leave()

    _check(FileAccess.get_file_as_string(CATALOG_PATH) == before,
        "all operations leave the shipped catalog untouched")
    seed(5571)
    _check(randi() == expected_global, "no path consumes the global RNG")
    _finish()


func _finish() -> void:
    for failure in failures:
        printerr(failure)
    print("v3_stitched_quiltpress_lamplight_spectacles_vital_events_test: ",
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
    _check(RunV3HeroVitalEventGate.new(CATALOG_PARSE_PARTY).is_valid(),
        "the full shipped catalog still parses through the real gate")


# AC2: real gate admission per required hero, with fail-closed refusals.
func _test_admission_and_offers() -> void:
    var gate := RunV3HeroVitalEventGate.new(PARTY)
    _check(gate.is_valid(), "authentic four-hero party builds a valid gate")
    var offered_ids: Array = []
    for offer: Dictionary in gate.get_offers():
        offered_ids.append(String(offer.get("id", "")))
    var absent_gate := RunV3HeroVitalEventGate.new(ABSENT_PARTY)
    _check(absent_gate.is_valid(), "party without the heroes is a valid gate")
    var absent_ids: Array = []
    for offer: Dictionary in absent_gate.get_offers():
        absent_ids.append(String(offer.get("id", "")))

    for event_id: String in EVENT_ORDER:
        var spec: Dictionary = SPECS[event_id]
        var hero_id: String = spec["hero"]
        _check(_records_for(event_id).size() == 1,
            "party event is present in the catalog: " + event_id)
        _check(offered_ids.count(event_id) == 1,
            "record offered exactly once to its party: " + event_id)
        _check(not absent_ids.has(event_id),
            "not offered without its hero: " + event_id)

        var base := _snap(hero_id)
        var base_copy := base.duplicate(true)
        var visit := gate.enter(event_id, base)
        _check(visit != null and visit.is_valid() and not visit.is_claimed(),
            "admits its living matching hero at 20/30: " + event_id)
        if visit == null:
            continue
        _check(visit.get_event_id() == event_id,
            "admitted visit binds the canonical record: " + event_id)
        _check(visit.get_event().get("required_hero") == hero_id,
            "admitted visit keeps the authored hero gate: " + event_id)
        var preview := visit.preview_vital_choices(base)
        _check(preview.get("ok") == true and preview.get("event_id") == event_id,
            "funded preview opens for every authored row: " + event_id)
        var spec_choices: Dictionary = spec["choices"]
        for choice_id: String in spec_choices:
            var entry := _entry_for(preview, choice_id)
            _check(not entry.is_empty() and entry.get("affordable") == true,
                "every authored choice previews as affordable when funded: "
                + event_id + "/" + choice_id)
        _check(not visit.is_claimed() and visit.is_valid() and base == base_copy,
            "previewing leaves the visit unclaimed and inputs detached: " + event_id)

        _check(gate.enter(event_id, _snap(hero_id, BASE_GOLD, BASE_SCRAPS, 0, BASE_MAX_HP)) == null,
            "refuses a Torn (0 HP) required hero: " + event_id)
        _check(gate.enter(event_id, _snap("lantern_monk")) == null,
            "refuses a snapshot of a different living hero: " + event_id)
        _check(gate.enter("v3_not_a_real_event", base) == null,
            "refuses an unknown event target: " + event_id)
        _check(absent_gate.enter(event_id, base) == null,
            "refuses entry for a hero outside the party: " + event_id)

    _check(gate.enter(null, _snap("warden")) == null,
        "refuses a missing event target")


# AC2: per-ID seeded selection that dynamically excludes every other existing
# offer (never a hard-coded catalog pool length), plus Torn witnesses.
func _test_per_id_selection() -> void:
    var gate := RunV3HeroVitalEventGate.new(PARTY)
    _check(gate.is_valid(), "selection gate builds for the four-hero party")
    var offered_ids: Array = []
    for offer: Dictionary in gate.get_offers():
        offered_ids.append(String(offer.get("id", "")))
    _check(offered_ids.size() > 0, "party gate offers a non-empty pool")

    for event_id: String in EVENT_ORDER:
        var hero_id: String = SPECS[event_id]["hero"]
        _check(offered_ids.has(event_id),
            "selection target is offered to the party: " + event_id)
        var excluded: Array = []
        for offered_id: String in offered_ids:
            if offered_id != event_id:
                excluded.append(offered_id)
        _check(excluded.size() == offered_ids.size() - 1,
            "dynamic exclusion keeps only the target: " + event_id)

        var wallet := {"gold": BASE_GOLD, "scraps": BASE_SCRAPS}
        var heroes: Array = []
        for pid: String in PARTY:
            heroes.append({"id": pid, "hp": BASE_HP, "max_hp": BASE_MAX_HP})
        var rng := RandomNumberGenerator.new()
        rng.seed = 8123
        var picked: Dictionary = gate.select_party_actionable_event(rng, excluded, wallet, heroes)
        _check(picked.get("ok") == true
            and picked.get("event", {}).get("id") == event_id
            and picked.get("event", {}).get("required_hero") == hero_id,
            "seeded selector picks the target with all other offers excluded: " + event_id)

        var torn_heroes: Array = []
        for pid: String in PARTY:
            torn_heroes.append({
                "id": pid,
                "hp": 0 if pid == hero_id else BASE_HP,
                "max_hp": BASE_MAX_HP,
            })
        var torn_rng := RandomNumberGenerator.new()
        torn_rng.seed = 8123
        var torn_pick: Dictionary = gate.select_party_actionable_event(
            torn_rng, excluded, wallet, torn_heroes)
        _check(torn_pick.get("ok") == false,
            "seeded selector fails closed when the required hero is Torn: " + event_id)


# AC3: preview and settlement match the independent funded table, one fresh
# gate/visit per choice, with the one-claim-only latch.
func _test_settlement_table() -> void:
    for event_id: String in EVENT_ORDER:
        var spec: Dictionary = SPECS[event_id]
        var hero_id: String = spec["hero"]
        var gate := RunV3HeroVitalEventGate.new(PARTY)
        var expected_choices: Dictionary = EXPECTED[event_id]
        var spec_choices: Dictionary = spec["choices"]
        _check(expected_choices.size() == 3,
            "independent table covers all three choices: " + event_id)
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
            _check(visit.preview_vital_choices(base).get("ok") == false,
                "preview also refuses on the latched visit: "
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
        _check(visit.choose_with_vitals("", base).get("ok") == false
            and visit.is_valid() and not visit.is_claimed(),
            "blank choice refuses without mutation: " + event_id)
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
        var starved_cases: Array = STARVED[event_id]
        _check(starved_cases.size() == int(STARVED_COUNTS[event_id]),
            "every starved witness is present: " + event_id)
        for starve_raw: Variant in starved_cases:
            var starve_case: Dictionary = starve_raw
            var choice_id: String = starve_case["choice"]
            _check(choice_id != "leave",
                "starved branch is a paid or self-harm trade: "
                + event_id + "/" + choice_id)
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
