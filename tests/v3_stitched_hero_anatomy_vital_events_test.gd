extends SceneTree
## Focused headless contract test for the four appended Stitched hero-anatomy
## gothic vitality crossroads Events in data/events/v3_hero_vital_events.json.
## Exercises only the shipped catalog plus the real RunV3HeroVitalEventGate /
## RunEventChoice services: presence-only anchor checks (never a catalog total
## or an ordered ID list), per-entry integrity for every catalog record, real
## admission and offer negatives, authored funded settlements from an
## independent expected table, fail-closed refusals that leave the visit
## claimable by Leave, unknown/replay refusals, and single-eligible seeded
## actionable selection with dynamic exclusions.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

## Prior named anchors that must still exist (presence only, no totals).
const ANCHOR_IDS := [
	"v3_warden_buckle_heart_ward",
	"v3_lantern_monk_thimble_moon_vigil",
	"v3_yarn_ranger_woolwisp_waymark",
	"v3_button_golem_gilt_turnstile",
]

const EVENT_ORDER := [
	"v3_lantern_monk_amber_moth_nest",
	"v3_rag_duelist_duel_mask_mirror",
	"v3_yarn_ranger_moonbolas_stag",
	"v3_button_golem_stormbutton_canopy",
]

## Task-local transcription of the authored rows. Each choice row is
## [text, gold, scraps, hp, max_hp]; the outcome keys must be exactly the four
## signed integers, zeros included.
const SPECS := {
	"v3_lantern_monk_amber_moth_nest": {
		"title": "The Amber Moth Nest",
		"description": "The Lantern Monk finds a huge quilted moth cocoon hanging in a crooked bone-cream belfry; a single amber flame glows through its stitched silk ribs.",
		"hero": "lantern_monk",
		"choices": {
			"rewick_cocoon": ["Pay 14 gold to rekindle the nest wick (heal 8 HP)", -14, 0, 8, 0],
			"unspool_amber_silk": ["Unspool hot cocoon silk (lose 5 HP; gain 2 scraps)", 0, 2, -5, 0],
			"leave": ["Leave the amber moth asleep in its silk", 0, 0, 0, 0],
		},
	},
	"v3_rag_duelist_duel_mask_mirror": {
		"title": "The Duel-Mask Mirror",
		"description": "The Rag Duelist faces a cape-wide oxblood mirror where a button-eyed masked double holds a needle rapier through a torn velvet sash.",
		"hero": "rag_duelist",
		"choices": {
			"bind_mirror_cape": ["Spend 2 scraps binding the mirror-cape (heal 4 HP; gain 2 max HP)", 0, -2, 4, 2],
			"pawn_mirror_lining": ["Pawn the reflected cape lining (lose 3 max HP; gain 28 gold)", 28, 0, 0, -3],
			"leave": ["Cover the duel mirror and depart", 0, 0, 0, 0],
		},
	},
	"v3_yarn_ranger_moonbolas_stag": {
		"title": "The Moon-Bolas Stag",
		"description": "The Yarn Ranger finds a plump midnight-wool stag tangled in her enormous braided bolas; pale stitched stars gleam along its soft antlers.",
		"hero": "yarn_ranger",
		"choices": {
			"free_star_bolas": ["Spend 1 scrap loosening the starry knots (heal 6 HP)", 0, -1, 6, 0],
			"pluck_sharp_stars": ["Gather the sharp star-wool (lose 6 HP; gain 3 scraps)", 0, 3, -6, 0],
			"leave": ["Let the moon-wool stag find its own trail", 0, 0, 0, 0],
		},
	},
	"v3_button_golem_stormbutton_canopy": {
		"title": "The Stormbutton Canopy",
		"description": "The Button Golem braces a thundercloud-sized quilted canopy under violet rain; massive brass chest buttons and one lantern hold its seams together.",
		"hero": "button_golem",
		"choices": {
			"reinforce_thunder_button": ["Pay 20 gold to fit a stronger thunder button (+3 max HP)", -20, 0, 0, 3],
			"shake_copper_rain": ["Shake loose the copper rain (lose 4 HP; gain 24 gold)", 24, 0, -4, 0],
			"leave": ["Let the great canopy weather the storm", 0, 0, 0, 0],
		},
	},
}

## Funded precondition shared by every settlement check: wallet 60 gold / 6
## scraps, required hero at 20 of 30 HP.
const BASE_GOLD := 60
const BASE_SCRAPS := 6
const BASE_HP := 20
const BASE_MAX_HP := 30

## Expected resulting [gold, scraps, hp, max_hp], written independently of the
## JSON deltas rather than recomputed from them.
const EXPECTED := {
	"v3_lantern_monk_amber_moth_nest": {
		"rewick_cocoon": [46, 6, 28, 30],
		"unspool_amber_silk": [60, 8, 15, 30],
		"leave": [60, 6, 20, 30],
	},
	"v3_rag_duelist_duel_mask_mirror": {
		"bind_mirror_cape": [60, 4, 24, 32],
		"pawn_mirror_lining": [88, 6, 20, 27],
		"leave": [60, 6, 20, 30],
	},
	"v3_yarn_ranger_moonbolas_stag": {
		"free_star_bolas": [60, 5, 26, 30],
		"pluck_sharp_stars": [60, 9, 14, 30],
		"leave": [60, 6, 20, 30],
	},
	"v3_button_golem_stormbutton_canopy": {
		"reinforce_thunder_button": [40, 6, 20, 33],
		"shake_copper_rain": [84, 6, 16, 30],
		"leave": [60, 6, 20, 30],
	},
}

## Party per event: the required hero plus Warden and Tinker.
const PARTIES := {
	"v3_lantern_monk_amber_moth_nest": ["lantern_monk", "warden", "tinker"],
	"v3_rag_duelist_duel_mask_mirror": ["rag_duelist", "warden", "tinker"],
	"v3_yarn_ranger_moonbolas_stag": ["yarn_ranger", "warden", "tinker"],
	"v3_button_golem_stormbutton_canopy": ["button_golem", "warden", "tinker"],
}

## A valid canonical party that excludes every new required hero.
const EXCLUDING_PARTY := ["warden", "seamstress", "tinker"]

const RNG_SEED := 20261104

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary = {}


func _initialize() -> void:
	var before := FileAccess.get_file_as_string(CATALOG_PATH)
	seed(4417)
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
	_test_refusals_then_leave()
	_test_seeded_selection()

	_check(FileAccess.get_file_as_string(CATALOG_PATH) == before,
		"all operations leave the shipped catalog untouched")
	seed(4417)
	_check(randi() == expected_global, "no path consumes the global RNG")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_hero_anatomy_vital_events_test: ",
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


# AC1: exact authored records, presence-only anchor checks.
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


# AC1: four named pre-existing anchors still present (presence only).
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
	_check(RunV3HeroVitalEventGate.new(EXCLUDING_PARTY).is_valid(),
		"the full shipped catalog still parses through the real gate")


# AC2: real gate admission per required hero, with fail-closed refusals.
func _test_admission_and_offers() -> void:
	for event_id: String in EVENT_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var hero_id: String = spec["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
		_check(gate.is_valid(), "canonical party builds a valid gate: " + event_id)
		var offered_ids: Array = []
		for offer: Dictionary in gate.get_offers():
			offered_ids.append(String(offer.get("id", "")))
		_check(offered_ids.count(event_id) == 1,
			"record offered exactly once to its party: " + event_id)
		var visit := gate.enter(event_id, _snap(hero_id))
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"admits its living matching hero: " + event_id)
		_check(visit != null and visit.get_event_id() == event_id,
			"admitted visit binds the canonical record: " + event_id)
		_check(gate.enter(event_id, _snap("warden")) == null,
			"refuses a mismatched hero snapshot: " + event_id)
		_check(gate.enter(event_id, _snap(hero_id, BASE_GOLD, BASE_SCRAPS, 0, BASE_MAX_HP)) == null,
			"refuses a Torn (0 HP) required hero: " + event_id)
		var absent_gate := RunV3HeroVitalEventGate.new(EXCLUDING_PARTY)
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
			_check(visit.choose_with_vitals(choice_id, receipt.get("state", base)).get("ok") == false,
				"repeat claim refuses on the latched visit: "
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
		var spec: Dictionary = SPECS[event_id]
		var hero_id: String = spec["hero"]
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
		var first_trade := ""
		for choice_id: String in spec["choices"]:
			if choice_id != "leave":
				first_trade = choice_id
				break
		var settled := visit.choose_with_vitals(first_trade, base)
		_check(settled.get("ok") == true,
			"genuine choice settles after the unknown refusal: " + event_id)
		_check(visit.choose_with_vitals(first_trade, settled.get("state", base)).get("ok") == false,
			"replay refuses on the latched visit: " + event_id)
		_check(visit.choose_with_vitals("leave", base).get("ok") == false,
			"alternate claim also refuses once claimed: " + event_id)


# AC3: every stated debit witness fails closed without spending, mutation or a
# claim, and the same visit still settles the free Leave.
func _test_refusals_then_leave() -> void:
	# Insufficient gold for rewick_cocoon (-14) at gold 13.
	_refusal_then_leave("v3_lantern_monk_amber_moth_nest", "rewick_cocoon",
		_snap("lantern_monk", 13, BASE_SCRAPS))
	# Lethal HP debit for unspool_amber_silk (-5) at hp 5.
	_refusal_then_leave("v3_lantern_monk_amber_moth_nest", "unspool_amber_silk",
		_snap("lantern_monk", BASE_GOLD, BASE_SCRAPS, 5, BASE_MAX_HP))
	# Insufficient scraps for bind_mirror_cape (-2) at scraps 1.
	_refusal_then_leave("v3_rag_duelist_duel_mask_mirror", "bind_mirror_cape",
		_snap("rag_duelist", BASE_GOLD, 1))
	# Max HP floor for pawn_mirror_lining (-3) at max_hp 10.
	_refusal_then_leave("v3_rag_duelist_duel_mask_mirror", "pawn_mirror_lining",
		_snap("rag_duelist", BASE_GOLD, BASE_SCRAPS, 10, 10))
	# Insufficient scraps for free_star_bolas (-1) at scraps 0.
	_refusal_then_leave("v3_yarn_ranger_moonbolas_stag", "free_star_bolas",
		_snap("yarn_ranger", BASE_GOLD, 0))
	# Lethal HP debit for pluck_sharp_stars (-6) at hp 6.
	_refusal_then_leave("v3_yarn_ranger_moonbolas_stag", "pluck_sharp_stars",
		_snap("yarn_ranger", BASE_GOLD, BASE_SCRAPS, 6, BASE_MAX_HP))
	# Insufficient gold for reinforce_thunder_button (-20) at gold 19.
	_refusal_then_leave("v3_button_golem_stormbutton_canopy", "reinforce_thunder_button",
		_snap("button_golem", 19, BASE_SCRAPS))
	# Lethal HP debit for shake_copper_rain (-4) at hp 4.
	_refusal_then_leave("v3_button_golem_stormbutton_canopy", "shake_copper_rain",
		_snap("button_golem", BASE_GOLD, BASE_SCRAPS, 4, BASE_MAX_HP))


func _refusal_then_leave(event_id: String, choice_id: String,
		state: Dictionary) -> void:
	var state_copy := state.duplicate(true)
	var hero_id: String = SPECS[event_id]["hero"]
	var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
	var visit := gate.enter(event_id, state)
	_check(visit != null and visit.is_valid(),
		"refusal visit opens: " + event_id + "/" + choice_id)
	if visit == null:
		return
	var preview := visit.preview_vital_choices(state)
	var entry := _entry_for(preview, choice_id)
	_check(entry.get("affordable") == false,
		"refused choice previews as unaffordable: " + event_id + "/" + choice_id)
	var refused := visit.choose_with_vitals(choice_id, state)
	_check(refused.get("ok") == false
		and visit.is_valid() and not visit.is_claimed() and state == state_copy,
		"refused branch leaves the visit unclaimed and snapshot intact: "
		+ event_id + "/" + choice_id)
	var recovered := visit.choose_with_vitals("leave", state)
	_check(recovered.get("ok") == true
		and recovered.get("state") == state_copy
		and recovered.get("state", {}).get("hero", {}).get("id") == hero_id
		and visit.is_claimed() and not visit.is_valid(),
		"same visit still settles free Leave after the refusal: "
		+ event_id + "/" + choice_id)


# AC4: single-eligible seeded actionable selection with dynamic exclusions,
# one randi_range(0, 0) draw, seed replay and fail-closed malformed or
# fully exhausted exclusions that consume no RNG.
func _test_seeded_selection() -> void:
	for event_id: String in EVENT_ORDER:
		var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
		_check(gate.is_valid(), "selection gate is valid: " + event_id)
		var offered: Array = []
		for offer: Dictionary in gate.get_offers():
			offered.append(String(offer.get("id", "")))
		_check(offered.count(event_id) == 1,
			"selection gate offers the record exactly once: " + event_id)
		var excluded: Array = []
		for oid: String in offered:
			if oid != event_id:
				excluded.append(oid)
		var wallet := {"gold": BASE_GOLD, "scraps": BASE_SCRAPS}
		var heroes: Array = []
		for hero_id: String in PARTIES[event_id]:
			heroes.append({"id": hero_id, "hp": BASE_HP, "max_hp": BASE_MAX_HP})
		var wallet_copy := wallet.duplicate(true)
		var heroes_copy := heroes.duplicate(true)
		var excluded_copy := excluded.duplicate(true)
		var rng := RandomNumberGenerator.new()
		rng.seed = RNG_SEED
		var oracle := RandomNumberGenerator.new()
		oracle.seed = RNG_SEED
		oracle.randi_range(0, 0)
		var selection := gate.select_party_actionable_event(rng, excluded, wallet, heroes)
		_check(selection.get("ok") == true
			and selection.get("event", {}).get("id") == event_id,
			"single-eligible seeded selection returns the new record: " + event_id)
		_check(rng.state == oracle.state,
			"selection consumes exactly one randi_range(0, 0) draw: " + event_id)
		_check(wallet == wallet_copy and heroes == heroes_copy and excluded == excluded_copy,
			"selection preserves caller inputs: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = RNG_SEED
		var replay := gate.select_party_actionable_event(replay_rng, excluded, wallet, heroes)
		_check(replay.get("ok") == true
			and replay.get("event", {}).get("id") == event_id,
			"same seed replays the same selection: " + event_id)
		var strict_rng := RandomNumberGenerator.new()
		strict_rng.seed = RNG_SEED
		var state_before := strict_rng.state
		var bad_shape := gate.select_party_actionable_event(strict_rng, "not_an_array", wallet, heroes)
		_check(bad_shape.get("ok") == false and strict_rng.state == state_before,
			"malformed exclusions fail without RNG use: " + event_id)
		var bad_element := gate.select_party_actionable_event(strict_rng, [event_id, 17], wallet, heroes)
		_check(bad_element.get("ok") == false and strict_rng.state == state_before,
			"non-string exclusion fails without RNG use: " + event_id)
		var exhausted: Array = offered.duplicate(true)
		var drained_rng := RandomNumberGenerator.new()
		drained_rng.seed = RNG_SEED
		var drained_before := drained_rng.state
		var drained := gate.select_party_actionable_event(drained_rng, exhausted, wallet, heroes)
		_check(drained.get("ok") == false and drained_rng.state == drained_before,
			"fully exhausted exclusions fail without RNG use: " + event_id)
