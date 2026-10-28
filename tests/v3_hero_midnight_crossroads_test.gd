extends SceneTree

const CATALOG_PATH := "res://data/events/v3_hero_choice_events.json"
const NEW_EVENT_IDS := [
	"v3_warden_cinder_shield_parade",
	"v3_seamstress_ribbon_heart_gallery",
	"v3_tinker_thunder_spool_dock",
	"v3_lantern_monk_moonmoth_procession",
	"v3_scarecrow_strawmoon_watch",
	"v3_button_golem_bronze_rivet_choir",
]

const ANCHORS := [
	"v3_warden_shield_menders",
	"v3_seamstress_thread_cart",
	"v3_tinker_clockwork_wagon",
	"v3_lantern_monk_moth_vigil",
	"v3_scarecrow_crow_roost",
	"v3_button_golem_buttonlift",
]

const EXPECTED := {
	"v3_warden_cinder_shield_parade": {
		"title": "The Cinder Shield Parade",
		"description": "A squat guard with a dented pot helmet braces a giant slate patch shield beneath oxblood procession flags and glowing lantern coals.",
		"required_hero": "warden",
		"hero_choice_ids": ["brace_cinder_procession", "buy_shield_rivets"],
		"choices": {
			"brace_cinder_procession": {"text": "Brace the burning procession (spend 2 scraps; gain 26 gold)", "gold": 26, "scraps": -2},
			"buy_shield_rivets": {"text": "Buy shield rivets (spend 13 gold; gain 2 scraps)", "gold": -13, "scraps": 2},
			"leave": {"text": "Let the lantern procession pass", "gold": 0, "scraps": 0},
		},
	},
	"v3_seamstress_ribbon_heart_gallery": {
		"title": "The Ribbon-Heart Gallery",
		"description": "A needle the size of a staff threads scarlet ribbons between plush velvet hearts beneath a bone-cream gallery roof.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["mend_gallery_hearts", "buy_glimmer_needles"],
		"choices": {
			"mend_gallery_hearts": {"text": "Mend the torn velvet hearts (spend 2 scraps; gain 31 gold)", "gold": 31, "scraps": -2},
			"buy_glimmer_needles": {"text": "Buy silver glimmer needles (spend 19 gold; gain 3 scraps)", "gold": -19, "scraps": 3},
			"leave": {"text": "Leave the hearts hanging", "gold": 0, "scraps": 0},
		},
	},
	"v3_tinker_thunder_spool_dock": {
		"title": "The Thunder-Spool Dock",
		"description": "A hunchbacked gearsmith with a scrap blunderbuss winds copper turbines beside a storm-lit mountain of wooden spools.",
		"required_hero": "tinker",
		"hero_choice_ids": ["rewind_dock_engines", "buy_copper_springs"],
		"choices": {
			"rewind_dock_engines": {"text": "Rewind the dock engines (spend 3 scraps; gain 33 gold)", "gold": 33, "scraps": -3},
			"buy_copper_springs": {"text": "Buy copper clock springs (spend 11 gold; gain 2 scraps)", "gold": -11, "scraps": 2},
			"leave": {"text": "Leave the turbines unwound", "gold": 0, "scraps": 0},
		},
	},
	"v3_lantern_monk_moonmoth_procession": {
		"title": "The Moon-Moth Procession",
		"description": "A round saffron-robed lantern keeper guides button-eyed moth dolls across a midnight-teal bridge of embroidered stars.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["guide_moonmoth_pilgrims", "buy_amber_wicks"],
		"choices": {
			"guide_moonmoth_pilgrims": {"text": "Guide the moth pilgrims (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
			"buy_amber_wicks": {"text": "Buy amber lantern wicks (spend 18 gold; gain 3 scraps)", "gold": -18, "scraps": 3},
			"leave": {"text": "Watch the lanterns float away", "gold": 0, "scraps": 0},
		},
	},
	"v3_scarecrow_strawmoon_watch": {
		"title": "The Strawmoon Watch",
		"description": "A pumpkin-orange sack head and pitchfork stand beside a black crow on a velvet roof while straw bells ring across the moonlit fields.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["guard_crow_bell", "buy_harvest_twine"],
		"choices": {
			"guard_crow_bell": {"text": "Guard the midnight crow bell (spend 2 scraps; gain 22 gold)", "gold": 22, "scraps": -2},
			"buy_harvest_twine": {"text": "Buy fresh harvest twine (spend 14 gold; gain 2 scraps)", "gold": -14, "scraps": 2},
			"leave": {"text": "Leave the straw bells ringing", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_bronze_rivet_choir": {
		"title": "The Bronze-Rivet Choir",
		"description": "A huge button-bodied doll steadies a falling brass-button organ while tiny velvet singers hold its fraying thread pipes.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["raise_button_organ", "buy_rivet_thread"],
		"choices": {
			"raise_button_organ": {"text": "Raise the giant button organ (spend 3 scraps; gain 37 gold)", "gold": 37, "scraps": -3},
			"buy_rivet_thread": {"text": "Buy brass rivet thread (spend 20 gold; gain 3 scraps)", "gold": -20, "scraps": 3},
			"leave": {"text": "Leave the choir to its song", "gold": 0, "scraps": 0},
		},
	},
}

var failures: Array[String] = []
var checks := 0


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _wallet_exact(dict: Variant, gold: int, scraps: int) -> bool:
	if not dict is Dictionary:
		return false
	return dict.get("gold") == gold and dict.get("scraps") == scraps


func _find_events() -> Array:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check(file != null, "catalog file opens")
	if file == null:
		return []
	var parser := JSON.new()
	var res := parser.parse(file.get_as_text())
	file.close()
	_check(res == OK, "catalog parses")
	if res != OK:
		return []
	var data: Variant = parser.data
	_check(data is Dictionary and data.has("events"), "catalog has events array")
	if not (data is Dictionary and data.get("events") is Array):
		return []
	return (data as Dictionary).get("events") as Array


func _record_by_id(events: Array, event_id: String) -> Dictionary:
	for e in events:
		if e is Dictionary and e.get("id") == event_id:
			return e
	return {}


func _test_catalog_content(events: Array) -> void:
	# Each new ID exactly once
	var seen := {}
	for nid in NEW_EVENT_IDS:
		_check(not seen.has(nid), "new ID listed once: " + nid)
		seen[nid] = true
		var rec := _record_by_id(events, nid)
		_check(not rec.is_empty(), "new event authored once: " + nid)
		_check(rec.get("title") == EXPECTED[nid]["title"], "new title: " + nid)
		_check(rec.get("description") == EXPECTED[nid]["description"], "new description: " + nid)
		_check(rec.get("required_hero") == EXPECTED[nid]["required_hero"], "new required_hero: " + nid)
		var hero_ids: Array = rec.get("hero_choice_ids", [])
		_check(hero_ids == EXPECTED[nid]["hero_choice_ids"], "new hero_choice_ids: " + nid)
		var choices: Array = rec.get("choices", [])
		_check(choices.size() == 3, "new three choices: " + nid)
		var by_id := {}
		for c in choices:
			if c is Dictionary:
				by_id[c.get("id", "")] = c
		for cid in EXPECTED[nid]["choices"]:
			_check(by_id.has(cid), "new choice present: " + nid + "/" + cid)
			if by_id.has(cid):
				var choice_dict: Dictionary = by_id[cid]
				_check(choice_dict.get("text") == EXPECTED[nid]["choices"][cid]["text"],
					"new choice text: " + nid + "/" + cid)
				var outcome: Variant = choice_dict.get("outcome")
				_check(outcome is Dictionary, "new choice outcome is object: " + nid + "/" + cid)
				if outcome is Dictionary:
					_check(int(outcome.get("gold", -999)) == EXPECTED[nid]["choices"][cid]["gold"],
						"new gold delta: " + nid + "/" + cid)
					_check(int(outcome.get("scraps", -999)) == EXPECTED[nid]["choices"][cid]["scraps"],
						"new scraps delta: " + nid + "/" + cid)
		_check(by_id.has("leave"), "new has leave: " + nid)
		if by_id.has("leave"):
			var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
			if leave_outcome is Dictionary:
				_check(int(leave_outcome.get("gold", 1)) == 0 and int(leave_outcome.get("scraps", 1)) == 0,
					"new leave is zero delta: " + nid)

	# Named old anchors occur once
	for anchor in ANCHORS:
		var matches := []
		for e in events:
			if e is Dictionary and e.get("id") == anchor:
				matches.append(e)
		_check(matches.size() == 1, "anchor present once: " + anchor)


func _test_party_gating(events: Array) -> void:
	# Party with warden/seamstress/tinker should include warden, seamstress, tinker events
	# Party with lantern_monk/scarecrow/button_golem should include those
	for party in [["warden", "seamstress", "tinker"], ["lantern_monk", "scarecrow", "button_golem"]]:
		var offers := RunV3HeroEventOffers.new(party)
		_check(offers.is_valid(), "valid service for party: " + str(party))
		for nid in NEW_EVENT_IDS:
			var expected_hero: String = EXPECTED[nid]["required_hero"]
			var eligible: bool = party.has(expected_hero)
			var visit := offers.enter(nid)
			if eligible:
				_check(visit != null and visit is RunEventChoice and visit.is_valid() and not visit.is_claimed(),
					"entry available when hero present: " + nid + "/" + str(party))
			else:
				_check(visit == null, "entry denied when hero absent: " + nid + "/" + str(party))


func _test_event_service(event_id: String, events: Array) -> void:
	var rec := _record_by_id(events, event_id)
	_check(not rec.is_empty(), "service test has authored record: " + event_id)
	if rec.is_empty():
		return

	# Three independent fresh visits
	# 1. Paid choice from funded wallet
	var funded_wallet := {"gold": 60, "scraps": 6}
	var funded_before := funded_wallet.duplicate(true)

	# Visit 1: first paid choice
	var visit1 := RunEventChoice.new(rec.duplicate(true))
	var paid_ids: Array = EXPECTED[event_id]["hero_choice_ids"]
	var first_paid: String = paid_ids[0]
	var first_delta: Dictionary = EXPECTED[event_id]["choices"][first_paid]

	var preview1 := visit1.preview_wallet_choices(funded_wallet)
	_check(preview1.get("ok") == true, "funded preview ok: " + event_id)
	var entry1: Dictionary = {}
	for entry in preview1.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == first_paid:
			entry1 = entry
	_check(not entry1.is_empty(), "funded preview names paid choice: " + event_id + "/" + first_paid)
	_check(entry1.get("affordable") == true, "funded affordable: " + event_id)
	_check(int(entry1.get("gold_delta")) == int(first_delta["gold"]), "funded gold delta: " + event_id)
	_check(int(entry1.get("scraps_delta")) == int(first_delta["scraps"]), "funded scraps delta: " + event_id)

	var claim1 := visit1.choose_with_wallet(first_paid, funded_wallet)
	_check(claim1.get("ok") == true, "funded claim succeeds: " + event_id)
	_check(claim1.get("event_id") == event_id, "funded claim event id: " + event_id)
	_check(claim1.get("choice_id") == first_paid, "funded claim choice id: " + event_id)
	_check(_wallet_exact(claim1.get("wallet"), 60 + int(first_delta["gold"]), 6 + int(first_delta["scraps"])),
		"funded claim exact wallet: " + event_id)
	_check(_wallet_exact(funded_wallet, 60, 6) and funded_wallet == funded_before, "funded claim does not mutate caller wallet: " + event_id)
	_check(visit1.is_claimed() and not visit1.is_valid(), "funded claim latches once: " + event_id)

	var replay1 := visit1.choose_with_wallet(first_paid, claim1.get("wallet", {}))
	_check(replay1.get("ok") == false and replay1.get("event_id") == "" and replay1.get("choice_id") == "",
		"funded replay refused: " + event_id)
	var replay_wallet1: Dictionary = replay1.get("wallet", {})
	_check(_wallet_exact(replay_wallet1, 60 + int(first_delta["gold"]), 6 + int(first_delta["scraps"])),
		"funded replay detached wallet unchanged: " + event_id)

	# 2. Second paid choice (separate fresh visit)
	var visit2 := RunEventChoice.new(rec.duplicate(true))
	var second_paid: String = paid_ids[1]
	var second_delta: Dictionary = EXPECTED[event_id]["choices"][second_paid]
	var claim2 := visit2.choose_with_wallet(second_paid, funded_wallet)
	_check(claim2.get("ok") == true, "second funded claim succeeds: " + event_id)
	_check(_wallet_exact(claim2.get("wallet"), 60 + int(second_delta["gold"]), 6 + int(second_delta["scraps"])),
		"second funded claim exact wallet: " + event_id)

	# 3. Free Leave visit (separate fresh visit)
	var visit3 := RunEventChoice.new(rec.duplicate(true))
	var claim3 := visit3.choose_with_wallet("leave", funded_wallet)
	_check(claim3.get("ok") == true and claim3.get("choice_id") == "leave" and claim3.get("event_id") == event_id,
		"funded leave claim succeeds: " + event_id)
	_check(_wallet_exact(claim3.get("wallet"), 60, 6), "funded leave preserves wallet: " + event_id)

	# Zero wallet refusal and recovery
	var zero_wallet := {"gold": 0, "scraps": 0}
	var zero_before := zero_wallet.duplicate(true)
	for paid in paid_ids:
		var delta: Dictionary = EXPECTED[event_id]["choices"][paid]
		var visit_zero := RunEventChoice.new(rec.duplicate(true))
		var preview_zero := visit_zero.preview_wallet_choices(zero_wallet)
		var entry_zero: Dictionary = {}
		for entry in preview_zero.get("choices", []):
			if entry is Dictionary and entry.get("choice_id") == paid:
				entry_zero = entry
		_check(not entry_zero.is_empty(), "zero preview has entry: " + event_id + "/" + paid)
		_check(entry_zero.get("affordable") == false, "zero unaffordable paid: " + event_id + "/" + paid)

		var refused := visit_zero.choose_with_wallet(paid, zero_wallet)
		_check(refused.get("ok") == false, "zero refusal fails: " + event_id + "/" + paid)
		_check(refused.get("event_id") == "" and refused.get("choice_id") == "", "zero refusal empty ids: " + event_id + "/" + paid)
		_check(_wallet_exact(refused.get("wallet"), 0, 0), "zero refusal unchanged wallet: " + event_id + "/" + paid)
		_check(visit_zero.is_valid() and not visit_zero.is_claimed(), "zero refusal consumes no claim: " + event_id + "/" + paid)

	# After refusal, Leave commits once
	var visit_recover := RunEventChoice.new(rec.duplicate(true))
	var refusal := visit_recover.choose_with_wallet(paid_ids[0], zero_wallet)
	_check(refusal.get("ok") == false, "recovery refusal fails: " + event_id)
	var recovered := visit_recover.choose_with_wallet("leave", zero_wallet)
	_check(recovered.get("ok") == true and recovered.get("event_id") == event_id and recovered.get("choice_id") == "leave",
		"recovery leave succeeds: " + event_id)
	_check(_wallet_exact(recovered.get("wallet"), 0, 0), "recovery leave unchanged wallet: " + event_id)
	_check(visit_recover.is_claimed() and not visit_recover.is_valid(), "recovery leave latches claim: " + event_id)

	# Unknown choice IDs refuse unchanged
	var visit_bad := RunEventChoice.new(rec.duplicate(true))
	var unknown_result := visit_bad.choose_with_wallet("unknown_choice", funded_wallet)
	_check(unknown_result.get("ok") == false, "unknown choice refused: " + event_id)
	_check(unknown_result.get("wallet") is Dictionary, "unknown choice detached wallet: " + event_id)


func _test_seeded_rng(events: Array) -> void:
	var rec := _record_by_id(events, NEW_EVENT_IDS[0])
	_check(not rec.is_empty(), "seeded test has record")
	if rec.is_empty():
		return
	seed(3604)
	var expected_global := randi()
	seed(3604)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 3604
	var local_state := local_rng.state

	var visit := RunEventChoice.new(rec.duplicate(true))
	var wallet := {"gold": 60, "scraps": 6}
	var preview := visit.preview_wallet_choices(wallet)
	var claim := visit.choose_with_wallet(EXPECTED[NEW_EVENT_IDS[0]]["hero_choice_ids"][0], wallet)
	var replay := visit.choose_with_wallet(EXPECTED[NEW_EVENT_IDS[0]]["hero_choice_ids"][0], claim.get("wallet", {}))

	_check(local_rng.state == local_state, "seeded visit does not change local RNG state")
	_check(randi() == expected_global, "seeded visit does not change global RNG stream")


func _test_detached_source(events: Array) -> void:
	# Confirm the authored catalog record is unchanged after services
	var before_text := FileAccess.get_file_as_string(CATALOG_PATH)
	var service := RunV3HeroEventOffers.new(["warden", "seamstress", "tinker"])
	var visit := service.enter("v3_warden_cinder_shield_parade")
	_check(visit != null, "detached source visit exists")
	if visit != null:
		var result := visit.choose_with_wallet("brace_cinder_procession", {"gold": 60, "scraps": 6})
		_check(result.get("ok") == true, "detached claim succeeds")
	var after_text := FileAccess.get_file_as_string(CATALOG_PATH)
	_check(before_text == after_text, "catalog file unchanged after service visit")


func _initialize() -> void:
	var events := _find_events()
	_test_catalog_content(events)
	_test_party_gating(events)
	for nid in NEW_EVENT_IDS:
		_test_event_service(nid, events)
	_test_seeded_rng(events)
	_test_detached_source(events)

	var passed := failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_hero_midnight_crossroads_test: ", "PASS" if passed else "FAIL", " (", checks, " checks)")
	quit(0 if passed else 1)
