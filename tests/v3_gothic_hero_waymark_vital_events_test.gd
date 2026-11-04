extends SceneTree
## Focused headless contract test for the four appended look-driven V3-4 gothic
## hero waymark vitality Events in data/events/v3_hero_vital_events.json.
## Exercises only the shipped catalog plus the real RunV3HeroVitalEventGate /
## RunEventChoice services: presence-only anchor checks (never a catalog total
## or an ordered ID list), per-event admission and offer negatives, authored
## settlement results from an independent expected table, healing and max-HP
## clamp rules, fail-closed refusals that leave the visit unclaimed, and a
## single-eligible seeded actionable selection.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

## Prior named anchors that must still exist (presence only, no totals).
const ANCHOR_IDS := [
	"v3_lantern_monk_thimble_moon_vigil",
	"v3_rag_duelist_velvet_straw_mender",
	"v3_yarn_ranger_starladder_bolas",
]

const EVENT_ORDER := [
	"v3_lantern_monk_waxwing_crossing",
	"v3_rag_duelist_thimble_duel_stage",
	"v3_yarn_ranger_woolwisp_waymark",
	"v3_button_golem_gilt_turnstile",
]

## Task-local transcription of the authored rows. Each choice row is
## [text, gold, scraps, hp, max_hp]; the outcome keys must be exactly the four
## signed integers, zeros included.
const SPECS := {
	"v3_lantern_monk_waxwing_crossing": {
		"title": "The Waxwing Crossing",
		"description": "A great moth-wing bridge folds around a crooked lantern post; the Lantern Monk's glowing lamp reveals amber knots in the velvet crossing.",
		"hero": "lantern_monk",
		"choices": {
			"buy_waxwing_ward": ["Pay 24 gold to strengthen the wing-stitch (+3 max HP)", -24, 0, 0, 3],
			"pluck_amber_knots": ["Lose 6 HP plucking hot amber knots (gain 3 scraps)", 0, 3, -6, 0],
			"leave": ["Let the moth-wing bridge fold behind you", 0, 0, 0, 0],
		},
	},
	"v3_rag_duelist_thimble_duel_stage": {
		"title": "The Thimble Duel Stage",
		"description": "Beneath oxblood velvet curtains, a button-eyed duelling puppet raises a needle rapier above a stage made from one giant brass thimble.",
		"hero": "rag_duelist",
		"choices": {
			"darn_duellist_cape": ["Spend 2 scraps repairing the crimson cape (heal 9 HP)", 0, -2, 9, 0],
			"pawn_stage_medal": ["Give up 2 max HP for the puppet's 27-gold medal", 27, 0, 0, -2],
			"leave": ["Bow to the puppet and leave the stage", 0, 0, 0, 0],
		},
	},
	"v3_yarn_ranger_woolwisp_waymark": {
		"title": "The Woolwisp Waymark",
		"description": "The Yarn Ranger's huge wool bolas hold a stranded button-eyed wolf doll high above a moss-green needle-loom signpost.",
		"hero": "yarn_ranger",
		"choices": {
			"buy_wolf_lining": ["Pay 19 gold for a warm wolf-wool lining (heal 10 HP)", -19, 0, 10, 0],
			"free_tangled_wolf": ["Lose 5 HP freeing the wool-wolf (gain 2 scraps)", 0, 2, -5, 0],
			"leave": ["Leave the woolwisp dangling by the waymark", 0, 0, 0, 0],
		},
	},
	"v3_button_golem_gilt_turnstile": {
		"title": "The Gilt Button Turnstile",
		"description": "An enormous four-hole gilded button turns like a gate beneath a black chapel arch; the Button Golem's round fists steady its rattling rim.",
		"hero": "button_golem",
		"choices": {
			"reinforce_turnstile": ["Spend 3 scraps on a lasting brass-button seam (+4 max HP)", 0, -3, 0, 4],
			"wrench_loose_rim": ["Lose 6 HP prying out the brass rim (gain 29 gold)", 29, 0, -6, 0],
			"leave": ["Let the great button turn without you", 0, 0, 0, 0],
		},
	},
}

## Funded precondition shared by every settlement check: wallet 60 gold / 6 scraps,
## required hero at 20 of 30 HP.
const BASE_GOLD := 60
const BASE_SCRAPS := 6
const BASE_HP := 20
const BASE_MAX_HP := 30

## Expected resulting [gold, scraps, hp, max_hp], written independently of the
## JSON deltas rather than recomputed from them.
const EXPECTED := {
	"v3_lantern_monk_waxwing_crossing": {
		"buy_waxwing_ward": [36, 6, 20, 33],
		"pluck_amber_knots": [60, 9, 14, 30],
		"leave": [60, 6, 20, 30],
	},
	"v3_rag_duelist_thimble_duel_stage": {
		"darn_duellist_cape": [60, 4, 29, 30],
		"pawn_stage_medal": [87, 6, 20, 28],
		"leave": [60, 6, 20, 30],
	},
	"v3_yarn_ranger_woolwisp_waymark": {
		"buy_wolf_lining": [41, 6, 30, 30],
		"free_tangled_wolf": [60, 8, 15, 30],
		"leave": [60, 6, 20, 30],
	},
	"v3_button_golem_gilt_turnstile": {
		"reinforce_turnstile": [60, 3, 20, 34],
		"wrench_loose_rim": [89, 6, 14, 30],
		"leave": [60, 6, 20, 30],
	},
}

## Party per event: contains the required hero plus two other canonical heroes.
const PARTIES := {
	"v3_lantern_monk_waxwing_crossing": ["lantern_monk", "warden", "tinker"],
	"v3_rag_duelist_thimble_duel_stage": ["rag_duelist", "warden", "tinker"],
	"v3_yarn_ranger_woolwisp_waymark": ["yarn_ranger", "warden", "tinker"],
	"v3_button_golem_gilt_turnstile": ["button_golem", "warden", "tinker"],
}

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
	_test_admission_and_offers()
	_test_settlement_table()
	_test_healing_and_maxhp_clamps()
	_test_refusals_then_leave()
	_test_unknown_and_replay()
	_test_single_eligible_seeded_selection()

	_check(FileAccess.get_file_as_string(CATALOG_PATH) == before,
		"all operations leave the shipped catalog untouched")
	seed(4417)
	_check(randi() == expected_global, "no path consumes the global RNG")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_gothic_hero_waymark_vital_events_test: ",
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


# AC2: real gate admission per required hero, with fail-closed refusals.
func _test_admission_and_offers() -> void:
	for event_id: String in EVENT_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var hero_id: String = spec["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
		_check(gate.is_valid(), "canonical party builds a valid gate: " + event_id)
		var offered_ids: Array = []
		for offer: Dictionary in gate.get_offers():
			offered_ids.append(offer.get("id", ""))
		_check(offered_ids.has(event_id), "offered to a party containing its hero: " + event_id)
		var visit := gate.enter(event_id, _snap(hero_id))
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"admits its living matching hero: " + event_id)
		_check(visit != null and visit.get_event_id() == event_id,
			"admitted visit binds the canonical record: " + event_id)
		var other_hero := ""
		for candidate: String in PARTIES[event_id]:
			if candidate != hero_id:
				other_hero = candidate
				break
		_check(gate.enter(event_id, _snap(other_hero)) == null,
			"refuses a mismatched hero snapshot: " + event_id)
		_check(gate.enter(event_id, _snap(hero_id, BASE_GOLD, BASE_SCRAPS, 0, BASE_MAX_HP)) == null,
			"refuses a Torn (0 HP) required hero: " + event_id)
		var lacking := _party_without(hero_id)
		var absent_gate := RunV3HeroVitalEventGate.new(lacking)
		_check(absent_gate.is_valid(), "party without the hero is a valid gate: " + event_id)
		var absent_ids: Array = []
		for offer: Dictionary in absent_gate.get_offers():
			absent_ids.append(offer.get("id", ""))
		_check(not absent_ids.has(event_id), "not offered without its hero: " + event_id)
		_check(absent_gate.enter(event_id, _snap(hero_id)) == null,
			"refuses entry for a hero outside the party: " + event_id)


func _party_without(hero_id: String) -> Array:
	var parties: Array = []
	for candidate: String in ["warden", "seamstress", "tinker", "lantern_monk",
			"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]:
		if candidate != hero_id and parties.size() < 3:
			parties.append(candidate)
	return parties


# AC2: preview and settlement match the independent expected table.
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
				"preview quotes the independent expected state: " + event_id + "/" + choice_id)
			_check(not visit.is_claimed() and visit.is_valid() and base == base_copy,
				"preview is non-claiming and inputs stay detached: " + event_id + "/" + choice_id)
			var receipt := visit.choose_with_vitals(choice_id, base)
			_check(receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": choice_id,
				"state": expected_state,
			}, "settlement equals the independent expected table: " + event_id + "/" + choice_id)
			_check(visit.is_claimed() and not visit.is_valid() and base == base_copy,
				"claim latches once and leaves inputs detached: " + event_id + "/" + choice_id)


# AC2: healing caps at max HP, a max-HP gain alone never heals, and a max-HP
# cut pulls current HP down to the new maximum.
func _test_healing_and_maxhp_clamps() -> void:
	_clamp_case("v3_lantern_monk_waxwing_crossing", "buy_waxwing_ward",
		_snap("lantern_monk"), [36, 6, 20, 33],
		"max HP gain alone leaves current HP at 20")
	_clamp_case("v3_yarn_ranger_woolwisp_waymark", "buy_wolf_lining",
		_snap("yarn_ranger", BASE_GOLD, BASE_SCRAPS, 26, BASE_MAX_HP), [41, 6, 30, 30],
		"healing caps at max HP (26/30 +10 => 30)")
	_clamp_case("v3_rag_duelist_thimble_duel_stage", "pawn_stage_medal",
		_snap("rag_duelist", BASE_GOLD, BASE_SCRAPS, 29, BASE_MAX_HP), [87, 6, 28, 28],
		"reducing max HP caps current HP (29/30 -2 max => 28/28)")


func _clamp_case(event_id: String, choice_id: String, state: Dictionary,
		expected_row: Array, message: String) -> void:
	var hero_id: String = SPECS[event_id]["hero"]
	var state_copy := state.duplicate(true)
	var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
	var visit := gate.enter(event_id, state)
	_check(visit != null and visit.is_valid(), "clamp visit opens: " + event_id + "/" + choice_id)
	if visit == null:
		return
	var receipt := visit.choose_with_vitals(choice_id, state)
	_check(receipt == {
		"ok": true,
		"event_id": event_id,
		"choice_id": choice_id,
		"state": {
			"gold": expected_row[0],
			"scraps": expected_row[1],
			"hero": {"id": hero_id, "hp": expected_row[2], "max_hp": expected_row[3]},
		},
	}, message + ": " + event_id + "/" + choice_id)
	_check(visit.is_claimed() and state == state_copy,
		"clamp settlement claims once and leaves inputs detached: " + event_id + "/" + choice_id)


# AC3: insufficiency, lethal HP, max HP floor fail closed and leave the same
# visit claimable by Leave.
func _test_refusals_then_leave() -> void:
	# Insufficient gold for Waxwing buy_waxwing_ward (-24) at gold 23.
	_refusal_then_leave("v3_lantern_monk_waxwing_crossing", "lantern_monk", "buy_waxwing_ward",
		_snap("lantern_monk", 23))
	# Insufficient gold for Woolwisp buy_wolf_lining (-19) at gold 18.
	_refusal_then_leave("v3_yarn_ranger_woolwisp_waymark", "yarn_ranger", "buy_wolf_lining",
		_snap("yarn_ranger", 18))
	# Insufficient scraps for Thimble darn_duellist_cape (-2) at scraps 1.
	_refusal_then_leave("v3_rag_duelist_thimble_duel_stage", "rag_duelist", "darn_duellist_cape",
		_snap("rag_duelist", BASE_GOLD, 1))
	# Insufficient scraps for Turnstile reinforce_turnstile (-3) at scraps 2.
	_refusal_then_leave("v3_button_golem_gilt_turnstile", "button_golem", "reinforce_turnstile",
		_snap("button_golem", BASE_GOLD, 2))
	# Lethal HP debit for Waxwing pluck_amber_knots (-6) at hp 6.
	_refusal_then_leave("v3_lantern_monk_waxwing_crossing", "lantern_monk", "pluck_amber_knots",
		_snap("lantern_monk", BASE_GOLD, BASE_SCRAPS, 6, BASE_MAX_HP))
	# Lethal HP debit for Turnstile wrench_loose_rim (-6) at hp 6.
	_refusal_then_leave("v3_button_golem_gilt_turnstile", "button_golem", "wrench_loose_rim",
		_snap("button_golem", BASE_GOLD, BASE_SCRAPS, 6, BASE_MAX_HP))
	# Max HP floor for Thimble pawn_stage_medal (-2) at max_hp 11, hp 11.
	_refusal_then_leave("v3_rag_duelist_thimble_duel_stage", "rag_duelist", "pawn_stage_medal",
		_snap("rag_duelist", BASE_GOLD, BASE_SCRAPS, 11, 11))


func _refusal_then_leave(event_id: String, hero_id: String, choice_id: String,
		state: Dictionary) -> void:
	var state_copy := state.duplicate(true)
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
		and visit.is_claimed() and not visit.is_valid(),
		"same visit still settles Leave after the refusal: " + event_id + "/" + choice_id)


# AC3: unknown choice and replay fail closed.
func _test_unknown_and_replay() -> void:
	var event_id := "v3_button_golem_gilt_turnstile"
	var base := _snap("button_golem")
	var base_copy := base.duplicate(true)
	var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
	var visit := gate.enter(event_id, base)
	_check(visit != null, "unknown/replay visit opens")
	if visit == null:
		return
	_check(visit.choose_with_vitals("not_a_real_choice", base).get("ok") == false
		and visit.is_valid() and not visit.is_claimed() and base == base_copy,
		"unknown choice refuses without mutation")
	var first := visit.choose_with_vitals("reinforce_turnstile", base)
	_check(first.get("ok") == true, "genuine choice settles after the unknown refusal")
	_check(visit.choose_with_vitals("reinforce_turnstile", first.get("state", base)).get("ok") == false,
		"replay refuses on the latched visit")
	_check(visit.choose_with_vitals("leave", base).get("ok") == false,
		"alternate choice also refuses once claimed")


# AC2: single-eligible seeded actionable selection returns the new record
# regardless of the growing pool's ordering, without asserting a fixed seed.
func _test_single_eligible_seeded_selection() -> void:
	for event_id: String in EVENT_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var hero_id: String = spec["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
		var excluded: Array = []
		for offer: Dictionary in gate.get_offers():
			var oid: String = offer.get("id", "")
			if oid != event_id:
				excluded.append(oid)
		excluded.sort()
		var wallet := {"gold": BASE_GOLD, "scraps": BASE_SCRAPS}
		var heroes := [
			{"id": PARTIES[event_id][0], "hp": BASE_HP, "max_hp": BASE_MAX_HP},
			{"id": PARTIES[event_id][1], "hp": BASE_HP, "max_hp": BASE_MAX_HP},
			{"id": PARTIES[event_id][2], "hp": BASE_HP, "max_hp": BASE_MAX_HP},
		]
		var wallet_copy := wallet.duplicate(true)
		var heroes_copy := heroes.duplicate(true)
		var excluded_copy := excluded.duplicate(true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260101
		var oracle := RandomNumberGenerator.new()
		oracle.seed = 20260101
		oracle.randi_range(0, 0)
		var selection := gate.select_party_actionable_event(rng, excluded, wallet, heroes)
		_check(selection.get("ok") == true and selection.get("event", {}).get("id") == event_id,
			"single-eligible seeded selection returns the new record: " + event_id)
		_check(rng.state == oracle.state,
			"single-eligible selection consumes exactly one randi_range draw: " + event_id)
		_check(wallet == wallet_copy and heroes == heroes_copy and excluded == excluded_copy,
			"selection preserves caller inputs: " + event_id)
		var reordered_gate := RunV3HeroVitalEventGate.new(PARTIES[event_id], _reversed_catalog())
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = 20260101
		var reordered := reordered_gate.select_party_actionable_event(
			replay_rng, excluded, wallet, heroes)
		_check(reordered.get("ok") == true and reordered.get("event", {}).get("id") == event_id,
			"reversed source order still returns the new record: " + event_id)


func _reversed_catalog() -> Dictionary:
	var doc := RunV3HeroVitalEventGate.load_shipped_catalog()
	var events: Array = doc.get("events", []).duplicate(true)
	events.reverse()
	return {"events": events}
