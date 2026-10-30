extends SceneTree
## Regression for the four look-driven V3-4 hero vitality crossroads appended to
## data/events/v3_hero_vital_events.json (Scarecrow, Yarn Ranger, Button Golem,
## Tinker). Exercises only the real RunV3HeroVitalEventGate / RunEventChoice
## services: no stubs, no RNG use, no total-size or ordering assumptions.

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

## The five pre-existing records that must survive the append. Presence only.
const ORIGINAL_IDS := [
	"v3_warden_buckle_heart_ward",
	"v3_seamstress_crimson_quilt_surgeon",
	"v3_tinker_copper_needle_greenhouse",
	"v3_lantern_monk_thimble_moon_vigil",
	"v3_rag_duelist_velvet_straw_mender",
]

## Task-local, independently written spec of the four new records. Each choice
## row is [text, gold, scraps, hp, max_hp].
const SPECS := {
	"v3_scarecrow_strawheart_alarm": {
		"title": "The Strawheart Alarm",
		"description": "The Scarecrow hooks a quilted straw heart above a moonlit crow roost with a long forked pitchfork; black ribbon feathers tremble when it rings.",
		"hero": "scarecrow",
		"choices": {
			"patch_straw_heart": ["Spend 2 scraps patching the straw heart (+8 HP)", 0, -2, 8, 0],
			"offer_alarm_straw": ["Offer 5 HP of stuffing for 2 rescued scraps", 0, 2, -5, 0],
			"leave": ["Leave the crow roost to its midnight watch", 0, 0, 0, 0],
		},
	},
	"v3_yarn_ranger_starladder_bolas": {
		"title": "The Starladder Bolas",
		"description": "The Ranger's giant braided wool bolas snag a moonlit ladder of crossed knitting needles, its silver rungs hanging between two stitched willow trees.",
		"hero": "yarn_ranger",
		"choices": {
			"buy_knotted_rung": ["Spend 14 gold for a stronger wool seam (+2 max HP)", -14, 0, 0, 2],
			"unpick_bolas_strand": ["Unpick 1 max HP of wool to salvage 2 scraps", 0, 2, 0, -1],
			"leave": ["Leave the silver ladder hanging", 0, 0, 0, 0],
		},
	},
	"v3_button_golem_rivet_choir": {
		"title": "The Rivet Choir",
		"description": "The Golem's enormous chest buttons hum beside a choir of bronze rivets sewn into a midnight velvet bell, each bass note shaking its stitches.",
		"hero": "button_golem",
		"choices": {
			"polish_chest_buttons": ["Pay 17 gold to polish a worn chest seam (+9 HP)", -17, 0, 9, 0],
			"lend_bass_button": ["Give up 3 max HP of old brass for 27 gold", 27, 0, 0, -3],
			"leave": ["Let the bronze choir fall silent", 0, 0, 0, 0],
		},
	},
	"v3_tinker_blunderbuss_fuse_well": {
		"title": "The Blunderbuss Fuse Well",
		"description": "A huge blunderbuss rests against the Tinker's overstuffed scrap backpack as copper gear teeth catch sparks above an ink-dark wishing well.",
		"hero": "tinker",
		"choices": {
			"patch_fuse_lining": ["Spend 1 scrap reinforcing the blunderbuss lining (+2 max HP)", 0, -1, 0, 2],
			"bleed_fuse_heat": ["Endure 4 HP of hot fuse sparks to earn 21 gold", 21, 0, -4, 0],
			"leave": ["Cap the fuse and walk past the well", 0, 0, 0, 0],
		},
	},
}

## One canonical three-hero party per new required hero (distinct, known IDs).
const PARTIES := {
	"v3_scarecrow_strawheart_alarm": ["scarecrow", "warden", "tinker"],
	"v3_yarn_ranger_starladder_bolas": ["yarn_ranger", "seamstress", "warden"],
	"v3_button_golem_rivet_choir": ["button_golem", "tinker", "warden"],
	"v3_tinker_blunderbuss_fuse_well": ["tinker", "seamstress", "warden"],
}

const CHOICE_ORDER := [
	"v3_scarecrow_strawheart_alarm",
	"v3_yarn_ranger_starladder_bolas",
	"v3_button_golem_rivet_choir",
	"v3_tinker_blunderbuss_fuse_well",
]

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary = {}


func _initialize() -> void:
	var before := FileAccess.get_file_as_string(CATALOG_PATH)
	seed(731)
	var expected_global := randi()
	seed(731)
	var rng := RandomNumberGenerator.new()
	rng.seed = 731
	var rng_state := rng.state

	catalog = JSON.parse_string(before)
	_check(catalog is Dictionary and catalog.get("events") is Array, "vital hero catalog parses as {events: []}")
	if not (catalog is Dictionary and catalog.get("events") is Array):
		_finish()
		return

	_test_authentic_records()
	_test_originals_still_present()
	_test_admission_and_offers()
	_test_every_choice_settles()
	_test_healing_and_cap_semantics()
	_test_negative_visits()

	_check(FileAccess.get_file_as_string(CATALOG_PATH) == before, "all operations leave the shipped catalog untouched")
	_check(rng.state == rng_state and randi() == expected_global, "no path consumes passed-in or global RNG")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_hero_vital_straw_bolas_rivet_fuse_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
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


func _snapshot(hero_id: String, gold: int = 50, scraps: int = 5, hp: int = 20, max_hp: int = 30) -> Dictionary:
	return {"gold": gold, "scraps": scraps, "hero": {"id": hero_id, "hp": hp, "max_hp": max_hp}}


func _entry_for(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry: Variant in preview.get("choices", []):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


# AC1: the four appended records are authentic, unique and exactly as authored.
func _test_authentic_records() -> void:
	for event_id: String in CHOICE_ORDER:
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
		_check(choices.size() == spec_choices.size(), "exactly three choices: " + event_id)
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
			_check(choice_dict.get("text") == row[0], "choice text is authentic: " + event_id + "/" + choice_id)
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
			"task-local leave row is zero delta: " + event_id)
		_check(_records_for(event_id)[0].get("choices", []).size() == 3,
			"second lookup is stable for: " + event_id)


# AC1: the five pre-existing records survive (ID presence only, no totals).
func _test_originals_still_present() -> void:
	for event_id: String in ORIGINAL_IDS:
		_check(_records_for(event_id).size() == 1, "pre-existing record still present exactly once: " + event_id)


# AC2: real gate admission per required hero, with fail-closed refusals.
func _test_admission_and_offers() -> void:
	for event_id: String in CHOICE_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var hero_id: String = spec["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
		_check(gate.is_valid(), "canonical party builds a valid gate: " + event_id)
		var offered_ids: Array = []
		for offer: Dictionary in gate.get_offers():
			offered_ids.append(offer.get("id", ""))
		_check(offered_ids.has(event_id), "offered to a party containing its hero: " + event_id)
		var found := _records_for(event_id)
		_check(found.size() == 1, "record exists for admission: " + event_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		var visit := gate.enter(record, _snapshot(hero_id))
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"admits its living matching hero: " + event_id)
		_check(visit != null and visit.get_event_id() == event_id,
			"admitted visit binds the canonical record: " + event_id)
		# Wrong hero snapshot for that record.
		var other_hero: String = ""
		for candidate: String in PARTIES[event_id]:
			if candidate != hero_id:
				other_hero = candidate
				break
		_check(gate.enter(record, _snapshot(other_hero)) == null,
			"refuses a mismatched hero snapshot: " + event_id)
		# Torn required hero.
		_check(gate.enter(record, _snapshot(hero_id, 50, 5, 0, 30)) == null,
			"refuses a Torn (0 HP) hero: " + event_id)
		_check(gate.enter(record, _snapshot(hero_id, 50, 5, 31, 30)) == null,
			"refuses HP above max HP: " + event_id)
		_check(gate.enter(record, _snapshot(hero_id, 50, 5, 5, 9)) == null,
			"refuses max HP below the floor: " + event_id)
		# Party lacking the required hero cannot even offer or open it.
		var lacking: Array = []
		for candidate: String in ["warden", "seamstress", "tinker", "lantern_monk",
				"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]:
			if candidate != hero_id and lacking.size() < 3:
				lacking.append(candidate)
		var absent_gate := RunV3HeroVitalEventGate.new(lacking)
		_check(absent_gate.is_valid(), "party without the hero is still a valid gate: " + event_id)
		var absent_ids: Array = []
		for offer: Dictionary in absent_gate.get_offers():
			absent_ids.append(offer.get("id", ""))
		_check(not absent_ids.has(event_id), "not offered without its hero: " + event_id)
		_check(absent_gate.enter(record, _snapshot(hero_id)) == null,
			"refuses entry for a hero outside the party: " + event_id)


# AC3: every choice previews and settles exactly once from a fresh funded visit.
func _test_every_choice_settles() -> void:
	for event_id: String in CHOICE_ORDER:
		var spec: Dictionary = SPECS[event_id]
		var hero_id: String = spec["hero"]
		var gate := RunV3HeroVitalEventGate.new(PARTIES[event_id])
		var choices: Dictionary = spec["choices"]
		for choice_id: String in ["patch_straw_heart", "offer_alarm_straw", "buy_knotted_rung",
				"unpick_bolas_strand", "polish_chest_buttons", "lend_bass_button",
				"patch_fuse_lining", "bleed_fuse_heat", "leave"]:
			if not choices.has(choice_id):
				continue
			var row: Array = choices[choice_id]
			var base := _snapshot(hero_id)
			var base_copy := base.duplicate(true)
			var visit := gate.enter(event_id, base)
			_check(visit != null and visit.is_valid(), "fresh visit for: " + event_id + "/" + choice_id)
			if visit == null:
				continue
			var new_max: int = base["hero"]["max_hp"] + int(row[4])
			var new_hp: int = mini(base["hero"]["hp"] + int(row[3]), new_max)
			var expected := {
				"gold": base["gold"] + int(row[1]),
				"scraps": base["scraps"] + int(row[2]),
				"hero": {"id": hero_id, "hp": new_hp, "max_hp": new_max},
			}
			var preview := visit.preview_vital_choices(base)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"preview ok: " + event_id + "/" + choice_id)
			_check(_entry_for(preview, choice_id) == {
				"choice_id": choice_id,
				"gold_delta": int(row[1]),
				"scraps_delta": int(row[2]),
				"hp_delta": int(row[3]),
				"max_hp_delta": int(row[4]),
				"affordable": true,
				"state": expected,
			}, "preview entry is exact: " + event_id + "/" + choice_id)
			_check(not visit.is_claimed() and visit.is_valid() and base == base_copy,
				"preview is non-claiming and inputs stay detached: " + event_id + "/" + choice_id)
			var receipt := visit.choose_with_vitals(choice_id, base)
			_check(receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": choice_id,
				"state": expected,
			}, "claim receipt equals preview settlement: " + event_id + "/" + choice_id)
			_check(visit.is_claimed() and not visit.is_valid() and base == base_copy,
				"claim latches once and leaves inputs detached: " + event_id + "/" + choice_id)
			var replay := visit.choose_with_vitals(choice_id, expected)
			_check(replay.get("ok") == false and replay.get("state") == expected,
				"replay refuses without mutation: " + event_id + "/" + choice_id)
			_check(visit.choose_with_vitals("leave", expected).get("ok") == false,
				"alternative choice also refuses once claimed: " + event_id + "/" + choice_id)


# AC3: max-HP gain does not heal, healing caps, and a cap cut pulls HP down.
func _test_healing_and_cap_semantics() -> void:
	var gate := RunV3HeroVitalEventGate.new(PARTIES["v3_scarecrow_strawheart_alarm"])
	var healed := gate.enter("v3_scarecrow_strawheart_alarm", _snapshot("scarecrow", 50, 5, 20, 30))
	var heal_receipt := healed.choose_with_vitals("patch_straw_heart", _snapshot("scarecrow", 50, 5, 20, 30))
	_check(heal_receipt.get("ok") == true
		and heal_receipt["state"]["scraps"] == 3
		and heal_receipt["state"]["hero"]["hp"] == 28
		and heal_receipt["state"]["hero"]["max_hp"] == 30,
		"Scarecrow patching spends scraps and heals 8 HP under the cap")

	var capped := gate.enter("v3_scarecrow_strawheart_alarm", _snapshot("scarecrow", 50, 5, 29, 30))
	var capped_receipt := capped.choose_with_vitals("patch_straw_heart", _snapshot("scarecrow", 50, 5, 29, 30))
	_check(capped_receipt.get("ok") == true and capped_receipt["state"]["hero"]["hp"] == 30,
		"healing stops at max HP")

	var cap_gate := RunV3HeroVitalEventGate.new(PARTIES["v3_yarn_ranger_starladder_bolas"])
	var grown := cap_gate.enter("v3_yarn_ranger_starladder_bolas", _snapshot("yarn_ranger"))
	var grown_receipt := grown.choose_with_vitals("buy_knotted_rung", _snapshot("yarn_ranger"))
	_check(grown_receipt.get("ok") == true
		and grown_receipt["state"]["gold"] == 36
		and grown_receipt["state"]["hero"]["hp"] == 20
		and grown_receipt["state"]["hero"]["max_hp"] == 32,
		"max HP gain alone does not heal current HP")

	var cut_gate := RunV3HeroVitalEventGate.new(PARTIES["v3_button_golem_rivet_choir"])
	var cut := cut_gate.enter("v3_button_golem_rivet_choir", _snapshot("button_golem", 50, 5, 30, 30))
	var cut_receipt := cut.choose_with_vitals("lend_bass_button", _snapshot("button_golem", 50, 5, 30, 30))
	_check(cut_receipt.get("ok") == true
		and cut_receipt["state"]["gold"] == 77
		and cut_receipt["state"]["hero"]["max_hp"] == 27
		and cut_receipt["state"]["hero"]["hp"] == 27,
		"max HP cut clamps current HP down to the new cap")


# AC4: unaffordable/lethal/floor/replay/unknown refusals, then legal Leave.
func _test_negative_visits() -> void:
	# Insufficient gold for buy_knotted_rung (-14).
	var ranger_gate := RunV3HeroVitalEventGate.new(PARTIES["v3_yarn_ranger_starladder_bolas"])
	var poor_gold := _snapshot("yarn_ranger", 5, 5, 20, 30)
	var poor_gold_copy := poor_gold.duplicate(true)
	var gold_visit := ranger_gate.enter("v3_yarn_ranger_starladder_bolas", poor_gold)
	_check(gold_visit != null, "negative gold visit opens")
	if gold_visit != null:
		var preview := gold_visit.preview_vital_choices(poor_gold)
		_check(_entry_for(preview, "buy_knotted_rung").get("affordable") == false,
			"unaffordable gold choice previews as unaffordable")
		var refused := gold_visit.choose_with_vitals("buy_knotted_rung", poor_gold)
		_check(refused.get("ok") == false and gold_visit.is_valid() and not gold_visit.is_claimed()
			and poor_gold == poor_gold_copy, "insufficient gold refuses without consuming the visit")
		var recovered := gold_visit.choose_with_vitals("leave", poor_gold)
		_check(recovered.get("ok") == true and recovered.get("state") == poor_gold
			and gold_visit.is_claimed() and not gold_visit.is_valid(),
			"free Leave still settles after the unaffordable attempt")

	# Insufficient scraps for patch_fuse_lining (-1).
	var tinker_gate := RunV3HeroVitalEventGate.new(PARTIES["v3_tinker_blunderbuss_fuse_well"])
	var poor_scraps := _snapshot("tinker", 50, 0, 20, 30)
	var poor_scraps_copy := poor_scraps.duplicate(true)
	var scraps_visit := tinker_gate.enter("v3_tinker_blunderbuss_fuse_well", poor_scraps)
	_check(scraps_visit != null, "negative scraps visit opens")
	if scraps_visit != null:
		_check(scraps_visit.choose_with_vitals("patch_fuse_lining", poor_scraps).get("ok") == false
			and scraps_visit.is_valid() and not scraps_visit.is_claimed()
			and poor_scraps == poor_scraps_copy,
			"insufficient scraps refuses without consuming the visit")
		_check(scraps_visit.choose_with_vitals("leave", poor_scraps).get("ok") == true,
			"Leave remains possible after the scraps refusal")

	# Lethal HP cost: bleed_fuse_heat (-4) at 3 HP would drop below 1.
	var lethal := _snapshot("tinker", 50, 5, 3, 30)
	var lethal_copy := lethal.duplicate(true)
	var lethal_visit := tinker_gate.enter("v3_tinker_blunderbuss_fuse_well", lethal)
	_check(lethal_visit != null, "lethal HP visit opens")
	if lethal_visit != null:
		_check(lethal_visit.choose_with_vitals("bleed_fuse_heat", lethal).get("ok") == false
			and lethal_visit.is_valid() and not lethal_visit.is_claimed() and lethal == lethal_copy,
			"lethal HP cost refuses without consuming the visit")
		_check(lethal_visit.choose_with_vitals("leave", lethal).get("ok") == true,
			"Leave remains possible after the lethal HP refusal")

	# Max-HP floor: unpick_bolas_strand (-1) and lend_bass_button (-3) at max HP 10.
	var floor_ranger := _snapshot("yarn_ranger", 50, 5, 10, 10)
	var floor_copy := floor_ranger.duplicate(true)
	var floor_visit := ranger_gate.enter("v3_yarn_ranger_starladder_bolas", floor_ranger)
	_check(floor_visit != null, "max HP floor visit opens")
	if floor_visit != null:
		_check(floor_visit.choose_with_vitals("unpick_bolas_strand", floor_ranger).get("ok") == false
			and floor_visit.is_valid() and not floor_visit.is_claimed() and floor_ranger == floor_copy,
			"max HP cut below the floor 10 refuses without consuming the visit")
		_check(floor_visit.choose_with_vitals("leave", floor_ranger).get("ok") == true,
			"Leave remains possible after the max HP floor refusal")

	var floor_golem := _snapshot("button_golem", 50, 5, 10, 10)
	var golem_gate := RunV3HeroVitalEventGate.new(PARTIES["v3_button_golem_rivet_choir"])
	var golem_visit := golem_gate.enter("v3_button_golem_rivet_choir", floor_golem)
	_check(golem_visit != null, "golem max HP floor visit opens")
	if golem_visit != null:
		_check(golem_visit.choose_with_vitals("lend_bass_button", floor_golem).get("ok") == false
			and golem_visit.is_valid() and not golem_visit.is_claimed(),
			"3 point max HP cut at the floor refuses")

	# Unknown choice and replayed choice on a fresh visit.
	var unknown_snap := _snapshot("scarecrow")
	var unknown_copy := unknown_snap.duplicate(true)
	var scare_gate := RunV3HeroVitalEventGate.new(PARTIES["v3_scarecrow_strawheart_alarm"])
	var unknown_visit := scare_gate.enter("v3_scarecrow_strawheart_alarm", unknown_snap)
	_check(unknown_visit != null, "unknown-choice visit opens")
	if unknown_visit != null:
		_check(unknown_visit.choose_with_vitals("not_a_real_choice", unknown_snap).get("ok") == false
			and unknown_visit.is_valid() and not unknown_visit.is_claimed()
			and unknown_snap == unknown_copy, "unknown choice refuses without mutation")
		_check(unknown_visit.choose_with_vitals("offer_alarm_straw", unknown_snap).get("ok") == true,
			"a genuine choice still settles after the unknown refusal")
		_check(unknown_visit.choose_with_vitals("offer_alarm_straw", unknown_snap).get("ok") == false,
			"replayed choice refuses on the latched visit")

	# A gate built from a party that cannot host any new hero still cannot enter.
	var outside := RunV3HeroVitalEventGate.new(["warden", "seamstress", "lantern_monk"])
	_check(outside.is_valid(), "outside party gate is valid")
	var tinker_found := _records_for("v3_tinker_blunderbuss_fuse_well")
	var yarn_found := _records_for("v3_yarn_ranger_starladder_bolas")
	_check(tinker_found.size() == 1 and yarn_found.size() == 1,
		"fuse well and starladder records exist for the outside-party check")
	if tinker_found.size() == 1 and yarn_found.size() == 1:
		_check(outside.enter(tinker_found[0], _snapshot("tinker")) == null,
			"party without the Tinker refuses the fuse well visit")
		_check(outside.enter(yarn_found[0], _snapshot("yarn_ranger")) == null,
			"party without the Yarn Ranger refuses the starladder visit")
