extends SceneTree
## V3-1 deterministic contract for the Yarn Ranger's rules-only "Reel" pull proposal.
##
## The two Reel printings (starter Reel Thread / Reel Thread+, common-pool Reel In / Reel In+)
## never attack and never leave the rules layer here: every case drives the real authored party
## (a 27 HP Yarn Ranger in her printed seat 2 or 3) and a detached three-slot enemy snapshot. The
## proposal must move exactly one living enemy one slot forward into a truly vacant slot, keep
## every other record byte-for-byte, add only the printed Tangled, and refuse everything else
## without touching the party, the snapshot or any seeded RNG.
##
## No live hand, energy payment, discard or target-selection hook is claimed: wiring these IDs
## into the mounted battle is a separate follow-up task.

const ReelCards = preload("res://scripts/combat_yarn_ranger_reel_cards.gd")
const YarnRangerStarterCards = preload("res://data/cards/yarn_ranger_starter_cards.gd")
const YarnRangerPoolCards = preload("res://data/cards/yarn_ranger_pool_cards.gd")
const CombatStatuses = preload("res://scripts/combat_statuses.gd")

const THREAD := "yarn_ranger_reel_thread"
const THREAD_PLUS := "yarn_ranger_reel_thread_plus"
const REEL_IN := "yarn_ranger_reel_in"
const REEL_IN_PLUS := "yarn_ranger_reel_in_plus"
const CARD_IDS := [THREAD, THREAD_PLUS, REEL_IN, REEL_IN_PLUS]

## Literal printed numbers, hand-copied from the brief and the two authored catalogs.
const PRINTED := {
	THREAD: {"catalog": "starter", "cost": 1, "tangled": 0},
	THREAD_PLUS: {"catalog": "starter", "cost": 0, "tangled": 0},
	REEL_IN: {"catalog": "pool", "cost": 1, "tangled": 1},
	REEL_IN_PLUS: {"catalog": "pool", "cost": 1, "tangled": 2},
}

const MAX_HP := {"warden": 40, "tinker": 26, "seamstress": 30, "yarn_ranger": 27}

var failures: Array[String] = []
var checks: int = 0
var service := ReelCards.new()


func _initialize() -> void:
	_test_authentic_catalog_contract()
	_test_ac1_one_slot_forward()
	_test_ac2_printed_cost_and_tangled()
	_test_ac3_owner_refusals()
	_test_ac3_card_refusals()
	_test_ac3_target_and_slot_refusals()
	_test_ac3_altered_descriptors()
	_test_replay_and_detached_results()
	if failures.is_empty():
		print("combat_yarn_ranger_reel_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_yarn_ranger_reel_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The four authentic printings, their own catalog, printed line and base/"+" links.
func _test_authentic_catalog_contract() -> void:
	var starter := YarnRangerStarterCards.new()
	var pool := YarnRangerPoolCards.new()
	for card_id: String in CARD_IDS:
		var printed: Dictionary = PRINTED[card_id]
		var catalog: Variant = starter if printed["catalog"] == "starter" else pool
		var other: Variant = pool if printed["catalog"] == "starter" else starter
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + ": authored in its own Yarn catalog")
		_check(other.get_definition(card_id).is_empty(),
			card_id + ": not duplicated in the other Yarn catalog")
		_check(record.get("id") == card_id, card_id + ": exact identifier")
		_check(record.get("owner") == "yarn_ranger", card_id + ": owned by Yarn Ranger")
		_check(record.get("cost") == printed["cost"], card_id + ": printed cost")
		_check(record.get("from_positions") == [2, 3], card_id + ": printed FROM 2-3")
		_check(record.get("to_positions") == [2, 3], card_id + ": printed TO 2-3")
		_check(record.get("target_kind") == "enemy_single", card_id + ": one enemy target")
		var effects: Dictionary = record.get("effects", {})
		_check(effects.get("pull_forward") == 1, card_id + ": prints pull_forward one")
		if printed["tangled"] == 0:
			_check(not effects.has("tangled"), card_id + ": prints no Tangled")
			_check(effects == {"pull_forward": 1}, card_id + ": prints only the pull")
		else:
			_check(effects.get("tangled") == printed["tangled"],
				card_id + ": prints Tangled " + str(printed["tangled"]))
			_check(effects.size() == 2, card_id + ": prints only pull and Tangled")
		_check(service.is_supported_card(card_id), card_id + ": supported by the pull preview")
		_check(ReelCards.is_authentic_definition(record, card_id),
			card_id + ": authentic catalog record passes authentication")
		_check(ReelCards.reel_definition(card_id) == record,
			card_id + ": resolves to its exact detached catalog record")
		if card_id.ends_with("_plus"):
			_check(record.get("upgrade_of") == card_id.trim_suffix("_plus")
				and not record.has("upgrade_id"), card_id + ": links back to its one base")
		else:
			_check(record.get("upgrade_id") == card_id + "_plus"
				and not record.has("upgrade_of"), card_id + ": links forward to its one upgrade")
	# Detached: a mutated resolution cannot poison the next one.
	var sample: Dictionary = ReelCards.reel_definition(REEL_IN)
	_check(not sample.is_empty(), "resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["pull_forward"] = 2
		sample["effects"]["tangled"] = 9
		sample["cost"] = 0
		sample["from_positions"].clear()
		_check(ReelCards.reel_definition(REEL_IN) == pool.get_definition(REEL_IN),
			"a mutated resolution cannot rewrite the next one")
	# Every other Yarn card, every forged spelling and every non-string is not a reel card.
	var unrelated: Array = []
	unrelated.append_array(starter.get_all_card_ids())
	unrelated.append_array(pool.get_all_card_ids())
	for card_id: String in CARD_IDS:
		unrelated.erase(card_id)
	_check(not unrelated.is_empty(), "unrelated Yarn cards exist to be refused")
	for other_id: Variant in unrelated:
		_check(not service.is_supported_card(other_id), str(other_id) + ": not a reel card")
		_check(ReelCards.reel_definition(other_id).is_empty(),
			str(other_id) + ": resolves no reel definition")
	for forged: Variant in ["yarn_ranger_reel_thread+", "yarn_ranger_reel_thread_plus_plus",
			"yarn_ranger_reel_in_+", "yarn_ranger_reel_in_plus_plus", "reel_thread", " reel_thread",
			"yarn_ranger_reel_thread ", "REEL_IN", "", StringName(THREAD), null, 0, 3.5, false,
			[], {}]:
		_check(not service.is_supported_card(forged), "forged ID is unsupported: " + str(forged))
		_check(ReelCards.reel_definition(forged).is_empty(),
			"forged ID resolves no reel definition: " + str(forged))


## AC1: a living Yarn Ranger in seat 2 or 3, a living chosen enemy in slot 2 or 3 and a vacant
## immediate front slot yields one detached proposal that moves only that enemy one slot forward
## and vacates its old slot.
func _test_ac1_one_slot_forward() -> void:
	var cases: Array[Dictionary] = []
	for card_id: String in CARD_IDS:
		for seat: int in [2, 3]:
			cases.append({"id": card_id, "seat": seat, "target": 2,
				"slots": _slots_target_two()})
			cases.append({"id": card_id, "seat": seat, "target": 3,
				"slots": _slots_target_three()})
	_check(cases.size() == 16, "AC1 exercises all four printings from both printed hero seats")
	for entry: Dictionary in cases:
		_check_projection(entry["id"], entry["seat"], entry["target"], entry["slots"])


func _check_projection(card_id: String, seat: int, target: int, slots: Dictionary) -> void:
	var label: String = card_id + " from seat " + str(seat) + " onto foe " + str(target)
	var printed: Dictionary = PRINTED[card_id]
	var party := _party(seat)
	_check(party.get_hero(seat).get("id") == "yarn_ranger"
		and party.get_hero(seat).get("hp") == 27, label + ": real 27 HP Yarn Ranger fixture")
	var source: Dictionary = slots.get(target, {})
	_check(not source.is_empty() and int(source.get("hp", 0)) > 0,
		label + ": the chosen foe really occupies a living slot")
	_check(slots.get(target - 1, {}).is_empty(),
		label + ": the destination really starts vacant")
	var heroes_before: Array = party.get_heroes()
	var slots_before: Dictionary = slots.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261030 + seat
	var rng_before: int = rng.state

	var result: Dictionary = service.propose_pull(card_id, party, target, slots)

	_check(result.get("ok") == true and result.get("reason") == "proposed",
		label + ": proposes the pull")
	_check(result.get("card_id") == card_id, label + ": receipt names the authentic card")
	_check(result.get("catalog") == printed["catalog"], label + ": receipt names its catalog")
	_check(result.get("cost") == printed["cost"], label + ": receipt prints the exact cost")
	_check(result.get("owner_position") == seat, label + ": receipt reports the owner seat")
	_check(result.get("target_position") == target, label + ": receipt reports the chosen foe")
	_check(result.get("destination_position") == target - 1,
		label + ": receipt reports one slot forward")
	_check(result.get("pull_forward") == 1, label + ": exactly one slot of pull")
	_check(result.get("tangled_added") == printed["tangled"],
		label + ": exactly the printed Tangled")
	for unwanted: String in ["damage", "draw", "energy", "discard", "block"]:
		_check(not result.has(unwanted), label + ": the preview never claims " + unwanted)

	var proposed: Dictionary = result.get("slots", {})
	_check(proposed.keys().size() == 3, label + ": three explicit slots")
	for slot: int in [1, 2, 3]:
		_check(proposed.has(slot), label + ": slot " + str(slot) + " is explicit")
		_check(proposed.get(slot) is Dictionary, label + ": slot " + str(slot) + " is a record")
	var moved: Dictionary = proposed.get(target - 1, {})
	var expected: Dictionary = source.duplicate(true)
	expected["position"] = target - 1
	if printed["tangled"] > 0:
		var statuses: Dictionary = expected.get("statuses", {}).duplicate(true)
		statuses["tangled"] = int(statuses.get("tangled", 0)) + printed["tangled"]
		expected["statuses"] = statuses
	_check(not moved.is_empty(), label + ": the destination now holds the pulled foe")
	_check(moved == expected,
		label + ": every original stat/status moves forward, plus only the printed Tangled")
	_check(moved.get("id") == source.get("id"), label + ": the pulled identity is preserved")
	_check(proposed.get(target) == {}, label + ": the old slot is vacated")
	for slot: int in [1, 2, 3]:
		if slot == target or slot == target - 1:
			continue
		_check(proposed.get(slot) == slots.get(slot, {}),
			label + ": slot " + str(slot) + " is copied unchanged")

	var occupied_before := 0
	for slot: int in [1, 2, 3]:
		if not slots.get(slot, {}).is_empty():
			occupied_before += 1
	var seen: Array[String] = []
	for slot: int in [1, 2, 3]:
		var actor: Dictionary = proposed.get(slot, {})
		if actor.is_empty():
			continue
		_check(not seen.has(actor.get("id")),
			label + ": identity " + str(actor.get("id")) + " stays unique")
		seen.append(actor.get("id"))
	_check(seen.size() == occupied_before, label + ": no foe is lost or duplicated")
	_check(moved.get("hp") == source.get("hp") and moved.get("block") == source.get("block"),
		label + ": the pull deals no damage and grants no Block")

	_check(slots == slots_before, label + ": the input snapshot is unchanged")
	_check(party.get_heroes() == heroes_before, label + ": the authoritative party is unchanged")
	_check(rng.state == rng_before, label + ": no seeded RNG draw is consumed")


## AC2: the printed cost and Tangled follow-up are exact, other statuses and stats are preserved,
## and nothing else (damage, draw, counters) changes.
func _test_ac2_printed_cost_and_tangled() -> void:
	for card_id: String in CARD_IDS:
		var printed: Dictionary = PRINTED[card_id]
		var label: String = card_id + " onto a stacked foe"
		var party := _party(3)
		var foe := _foe("moth_swarm", 3, 14, 20, 6,
			{"tangled": 1, "bleed": 2, "weak": 1, "exposed": 2})
		var slots := {1: _foe("button_guard", 1, 12, 12, 3), 3: foe}
		var foe_before: Dictionary = foe.duplicate(true)
		var result: Dictionary = service.propose_pull(card_id, party, 3, slots)
		_check(result.get("ok") == true, label + ": a pre-Tangled foe is still pulled")
		_check(result.get("reason") == "proposed", label + ": proposed")
		_check(result.get("cost") == printed["cost"],
			label + ": exact printed cost " + str(printed["cost"]))
		_check(result.get("tangled_added") == printed["tangled"],
			label + ": exact printed Tangled " + str(printed["tangled"]))
		var moved: Dictionary = result.get("slots", {}).get(2, {})
		_check(not moved.is_empty(), label + ": the foe really reached slot 2")
		_check(moved.get("hp") == 14 and moved.get("max_hp") == 20,
			label + ": HP and max HP are copied, never damaged")
		_check(moved.get("block") == 6, label + ": Block is copied unchanged")
		_check(moved.get("position") == 2, label + ": the canonical slot field follows the foe")
		var statuses: Dictionary = moved.get("statuses", {})
		var expected_statuses := {"tangled": 1 + int(printed["tangled"]),
			"bleed": 2, "weak": 1, "exposed": 2}
		if printed["tangled"] == 0:
			_check(statuses == {"tangled": 1, "bleed": 2, "weak": 1, "exposed": 2},
				label + ": Reel Thread adds no status at all")
		else:
			_check(statuses == expected_statuses,
				label + ": the printed Tangled stacks on the existing counter")
			_check(statuses.get("tangled") == 1 + int(printed["tangled"]),
				label + ": the Tangled counter moves by exactly the printed amount")
		_check(statuses.get("bleed") == 2 and statuses.get("weak") == 1
			and statuses.get("exposed") == 2, label + ": no other counter is touched")
		_check(moved.keys().size() == foe.keys().size(),
			label + ": the moved record gains and loses no field")
		_check(result.get("slots", {}).get(1) == slots[1],
			label + ": the front foe is untouched")
		_check(result.get("slots", {}).get(3) == {}, label + ": the vacated slot is empty")
		_check(foe == foe_before, label + ": the caller's foe record is unchanged")
	# Reel Thread is the free printing; Reel Thread+ costs zero and Reel In+ costs one.
	_check(service.propose_pull(THREAD_PLUS, _party(2), 2, _slots_target_two()).get("cost") == 0,
		"Reel Thread+ is the free printing")
	_check(service.propose_pull(THREAD, _party(2), 2, _slots_target_two()).get("cost") == 1,
		"Reel Thread costs one")
	_check(service.propose_pull(REEL_IN, _party(2), 2, _slots_target_two()).get("cost") == 1,
		"Reel In costs one")
	_check(service.propose_pull(REEL_IN_PLUS, _party(2), 2, _slots_target_two()).get("cost") == 1,
		"Reel In+ costs one")
	_check(service.propose_pull(THREAD, _party(2), 2, _slots_target_two()).get("tangled_added") == 0,
		"Reel Thread adds no Tangled")
	_check(service.propose_pull(THREAD_PLUS, _party(2), 2,
		_slots_target_two()).get("tangled_added") == 0, "Reel Thread+ adds no Tangled")
	_check(service.propose_pull(REEL_IN, _party(2), 2,
		_slots_target_two()).get("tangled_added") == 1, "Reel In adds Tangled one")
	_check(service.propose_pull(REEL_IN_PLUS, _party(2), 2,
		_slots_target_two()).get("tangled_added") == 2, "Reel In+ adds Tangled two")


## AC3: owner refusals: missing, downed, wrong seat and a malformed roster.
func _test_ac3_owner_refusals() -> void:
	_rejected("null party", THREAD, null, 2, _slots_target_two(), "invalid_request")
	var short_party := CombatParty.new([{"id": "yarn_ranger", "max_hp": 27}])
	_rejected("one-hero party", THREAD, short_party, 2, _slots_target_two(), "invalid_party")
	var duplicate_party := _party(2)
	duplicate_party._heroes[2]["id"] = "warden"
	_rejected("duplicate hero identities", THREAD, duplicate_party, 2, _slots_target_two(),
		"invalid_party")
	var bad_position := _party(2)
	bad_position._heroes[2]["position"] = 9
	_rejected("misplaced hero record", THREAD, bad_position, 2, _slots_target_two(),
		"invalid_party")
	var bad_block := _party(2)
	bad_block._heroes[0]["block"] = "0"
	_rejected("string Block on a hero", THREAD, bad_block, 2, _slots_target_two(),
		"invalid_party")
	var missing := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26}, {"id": "seamstress", "max_hp": 30}])
	_check(missing.is_valid(), "the missing-owner fixture is a real three-hero party")
	_rejected("no Yarn Ranger in the party", THREAD, missing, 2, _slots_target_two(),
		"owner_missing")
	var downed := _party(3, 0)
	_check(downed.is_downed(3), "the downed-owner fixture really is at 0 HP")
	_rejected("downed Yarn Ranger", THREAD, downed, 3, _slots_target_three(), "owner_downed")
	var wrong_seat := _party(1)
	_check(wrong_seat.get_hero(1).get("id") == "yarn_ranger",
		"the wrong-seat fixture really seats her in front")
	_rejected("Yarn Ranger in position 1", THREAD, wrong_seat, 2, _slots_target_two(),
		"owner_illegal_position")


## AC3: unheld/foreign/forged card identifiers never propose anything.
func _test_ac3_card_refusals() -> void:
	var foreign: Array = ["warden_strike", "seamstress_prick", "tinker_pop_shot",
		"yarn_ranger_needle_nock", "yarn_ranger_wool_bolas", "yarn_ranger_hood_knit",
		"yarn_ranger_needle_arrow", "yarn_ranger_tangle_bolas", "yarn_ranger_knit_shield",
		"yarn_ranger_snare_net", "yarn_ranger_unspool", "yarn_ranger_endless_skein",
		"yarn_ranger_reel_thread+", "yarn_ranger_reel_thread_plus_plus",
		"yarn_ranger_reel_in_plus_plus", "yarn_ranger_reel_thread ", "reel_thread",
		"REEL_IN", "", StringName(THREAD), null, 0, 3.5, false, [], {}]
	for wrong_id: Variant in foreign:
		_rejected("foreign or forged ID " + str(wrong_id), wrong_id, _party(2), 2,
			_slots_target_two(), "unsupported_card")


## AC3: invalid, slain and out-of-reach targets, occupied destinations and malformed snapshots.
func _test_ac3_target_and_slot_refusals() -> void:
	for bad_target: Variant in [0, 4, -1, 99, "2", 2.0, null, true, [2]]:
		_rejected("illegal target " + str(bad_target), THREAD, _party(2), bad_target,
			_slots_target_two(), "invalid_target")
	# Position 1 is a real enemy slot but outside the printed 2-3 target line.
	var front_occupied := _slots_target_two()
	front_occupied[1] = _foe("button_guard_front", 1, 12, 12, 3)
	_rejected("out-of-reach target in slot 1", THREAD, _party(2), 1, front_occupied,
		"target_out_of_reach")
	_rejected("out-of-reach vacant target in slot 1", THREAD, _party(2), 1,
		{2: _foe("spool_stalker", 2)}, "target_out_of_reach")
	# Vacant target slots, both absent and explicitly empty.
	_rejected("absent target slot", THREAD, _party(2), 2, {3: _foe("spool_stalker", 3)},
		"target_missing")
	_rejected("explicitly empty target slot", THREAD, _party(2), 2,
		{1: {}, 2: {}, 3: _foe("spool_stalker", 3)}, "target_missing")
	# A slain record still occupies its slot; it is never pulled and never treated as vacant.
	var slain_target := _slots_target_two()
	slain_target[2] = _foe("spool_stalker", 2, 0, 18)
	_rejected("slain target", THREAD, _party(2), 2, slain_target, "target_downed")
	# A pull never displaces an occupied neighbour, living or downed.
	var living_front := _slots_target_two()
	living_front[1] = _foe("button_guard_front", 1, 12, 12, 3)
	_rejected("living foe in the destination", THREAD, _party(2), 2, living_front,
		"destination_occupied")
	var downed_front := _slots_target_two()
	downed_front[1] = _foe("button_guard_front", 1, 0, 12)
	_rejected("downed record in the destination", THREAD, _party(2), 2, downed_front,
		"destination_occupied")
	var living_middle := _slots_target_three()
	living_middle[2] = _foe("button_guard_middle", 2, 12, 12)
	_rejected("living foe in slot 2 blocks a 3->2 pull", THREAD, _party(3), 3, living_middle,
		"destination_occupied")
	# Malformed snapshots.
	for malformed: Variant in [null, [], "slots", 7, true]:
		_rejected("non-dictionary snapshot " + str(malformed), THREAD, _party(2), 2, malformed,
			"invalid_slots")
	_rejected("slot key 0", THREAD, _party(2), 2, {0: _foe("x", 0), 2: _foe("y", 2)},
		"invalid_slots")
	_rejected("slot key 4", THREAD, _party(2), 2, {2: _foe("y", 2), 4: _foe("x", 4)},
		"invalid_slots")
	_rejected("string slot key", THREAD, _party(2), 2, {"2": _foe("y", 2)}, "invalid_slots")
	_rejected("non-dictionary slot value", THREAD, _party(2), 2, {2: "spool_stalker"},
		"invalid_slots")
	_rejected("record in the wrong slot", THREAD, _party(2), 2,
		{2: _foe("y", 2), 3: _foe("x", 1)}, "invalid_slots")
	_rejected("record without a position", THREAD, _party(2), 2,
		{2: {"id": "y", "hp": 5, "max_hp": 9, "block": 0}}, "invalid_slots")
	_rejected("record with more HP than max", THREAD, _party(2), 2,
		{2: _foe("y", 2, 12, 9)}, "invalid_slots")
	var float_hp := _foe("y", 2)
	float_hp["hp"] = 5.0
	_rejected("record with float HP", THREAD, _party(2), 2, {2: float_hp}, "invalid_slots")
	_rejected("record with string Block", THREAD, _party(2), 2,
		{2: _foe("y", 2, 5, 9, "0")}, "invalid_slots")
	_rejected("record with an empty identity", THREAD, _party(2), 2,
		{2: _foe("", 2)}, "invalid_slots")
	_rejected("duplicate enemy identities", THREAD, _party(2), 2,
		{2: _foe("twin", 2), 3: _foe("twin", 3)}, "invalid_slots")
	_rejected("statuses that are not a map", THREAD, _party(2), 2,
		{2: _foe("y", 2, 5, 9, 0, "tangled")}, "invalid_slots")
	_rejected("string Tangled count", THREAD, _party(2), 2,
		{2: _foe("y", 2, 5, 9, 0, {"tangled": "1"})}, "invalid_slots")
	_rejected("negative Tangled count", THREAD, _party(2), 2,
		{2: _foe("y", 2, 5, 9, 0, {"tangled": -1})}, "invalid_slots")
	_rejected("unknown status keyword", THREAD, _party(2), 2,
		{2: _foe("y", 2, 5, 9, 0, {"slow": 1})}, "invalid_slots")
	_rejected("non-canonical Dodge token", THREAD, _party(2), 2,
		{2: _foe("y", 2, 5, 9, 0, {"dodge_next_attack": 2})}, "invalid_slots")
	# A Tangled count at the ceiling refuses the printed addition instead of overflowing. The same
	# fixture is a valid Reel Thread target because that printing adds no status at all.
	var ceiling := {}
	ceiling[2] = _foe("spool_stalker", 2, 5, 9, 0, {"tangled": CombatStatuses.MAX_INT})
	_rejected("Tangled counter overflow", REEL_IN, _party(2), 2, ceiling, "status_overflow")
	_check(service.propose_pull(THREAD, _party(2), 2, ceiling).get("ok") == true,
		"Reel Thread still pulls a foe whose Tangled counter is at the ceiling")
	# Rejected inputs stay untouched: every refusal above went through _rejected's snapshots.
	var replay_slots := _slots_target_two()
	var replay_before: Dictionary = replay_slots.duplicate(true)
	var replay := service.propose_pull(REEL_IN, _party(2), 2, replay_slots)
	_check(replay.get("ok") == true, "a valid pull still works after the refusals")
	_check(replay_slots == replay_before, "the refusals and the later valid pull left the snapshot intact")


## AC3: an altered or unverifiable catalog descriptor is never paid attention to.
func _test_ac3_altered_descriptors() -> void:
	var starter := YarnRangerStarterCards.new()
	var pool := YarnRangerPoolCards.new()
	# Nonadjacent (pull two) and a widened target line: authentic IDs, forged rules.
	_expect_descriptor_refused("pull of two slots", THREAD, starter,
		func(record: Dictionary) -> void: record["effects"]["pull_forward"] = 2)
	_expect_descriptor_refused("pull of two slots (Reel In+)", REEL_IN_PLUS, pool,
		func(record: Dictionary) -> void: record["effects"]["pull_forward"] = 2)
	_expect_descriptor_refused("target line widened to slot 1", REEL_IN, pool,
		func(record: Dictionary) -> void: record["to_positions"] = [1, 2, 3])
	_expect_descriptor_refused("FROM line widened to slot 1", THREAD, starter,
		func(record: Dictionary) -> void: record["from_positions"] = [1, 2, 3])
	# Printed numbers, identity and metadata.
	_expect_descriptor_refused("cheaper cost", THREAD, starter,
		func(record: Dictionary) -> void: record["cost"] = 0)
	_expect_descriptor_refused("pricier cost", REEL_IN_PLUS, pool,
		func(record: Dictionary) -> void: record["cost"] = 2)
	_expect_descriptor_refused("float cost", THREAD, starter,
		func(record: Dictionary) -> void: record["cost"] = 1.0)
	_expect_descriptor_refused("altered Tangled", REEL_IN, pool,
		func(record: Dictionary) -> void: record["effects"]["tangled"] = 2)
	_expect_descriptor_refused("removed Tangled", REEL_IN_PLUS, pool,
		func(record: Dictionary) -> void: record["effects"].erase("tangled"))
	_expect_descriptor_refused("extra effect", THREAD, starter,
		func(record: Dictionary) -> void: record["effects"]["damage"] = 3)
	_expect_descriptor_refused("effects replaced by a string", THREAD, starter,
		func(record: Dictionary) -> void: record["effects"] = "pull_forward 1")
	_expect_descriptor_refused("foreign owner", THREAD, starter,
		func(record: Dictionary) -> void: record["owner"] = "warden")
	_expect_descriptor_refused("display name swap", REEL_IN, pool,
		func(record: Dictionary) -> void: record["display_name"] = "Reel In+")
	_expect_descriptor_refused("extra starting copy", THREAD, starter,
		func(record: Dictionary) -> void: record["starting_copies"] = 2)
	_expect_descriptor_refused("reward eligibility flipped", REEL_IN, pool,
		func(record: Dictionary) -> void: record["reward_eligible"] = false)
	_expect_descriptor_refused("rarity dropped", REEL_IN, pool,
		func(record: Dictionary) -> void: record.erase("rarity"))
	_expect_descriptor_refused("rarity raised", REEL_IN_PLUS, pool,
		func(record: Dictionary) -> void: record["rarity"] = "rare")
	_expect_descriptor_refused("upgrade link removed", THREAD, starter,
		func(record: Dictionary) -> void: record.erase("upgrade_id"))
	_expect_descriptor_refused("extra forged key", REEL_IN, pool,
		func(record: Dictionary) -> void: record["action_kind"] = "adjacent_swap")
	_expect_descriptor_refused("missing illustration path", THREAD, starter,
		func(record: Dictionary) -> void: record.erase("illustration_path"))
	_expect_descriptor_refused("swapped identity", THREAD, starter,
		func(record: Dictionary) -> void: record["id"] = THREAD_PLUS)
	# A seam that returns another card's record, nothing, or is not callable at all.
	var thread_record: Dictionary = starter.get_definition(THREAD)
	_rejected("seam returns a foreign record", THREAD, _party(2), 2, _slots_target_two(),
		"catalog_mismatch",
		func(_id: String) -> Dictionary: return pool.get_definition(REEL_IN))
	_rejected("seam returns nothing", THREAD, _party(2), 2, _slots_target_two(),
		"catalog_mismatch", func(_id: String) -> Dictionary: return {})
	_rejected("seam returns a non-record", THREAD, _party(2), 2, _slots_target_two(),
		"catalog_mismatch", func(_id: String) -> Variant: return null)
	_rejected("seam is not callable", THREAD, _party(2), 2, _slots_target_two(),
		"catalog_mismatch", {})
	_rejected("empty callable seam", THREAD, _party(2), 2, _slots_target_two(),
		"catalog_mismatch", Callable())
	_check(not thread_record.is_empty(), "the authentic method seam fixture loaded")
	# The authenticated seam is honoured only for a genuinely exact record.
	_check(service.propose_pull(THREAD, _party(2), 2, _slots_target_two(),
		func(_id: String) -> Dictionary: return starter.get_definition(THREAD)).get("ok") == true,
		"an exact authenticated seam proposes normally")
	_check(service.propose_pull(THREAD, _party(2), 2, _slots_target_two(),
		func(_id: String) -> Dictionary: return thread_record).get("ok") == true,
		"an exact detached record resolves normally")


## A projection is deterministic and fully detached: replaying it is identical, mutating one
## result cannot poison the next, and the inputs never carry a proposal back.
func _test_replay_and_detached_results() -> void:
	var party := _party(2)
	var slots := _slots_target_two()
	var slots_before: Dictionary = slots.duplicate(true)
	var heroes_before: Array = party.get_heroes()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101
	var rng_before: int = rng.state
	var first: Dictionary = service.propose_pull(REEL_IN_PLUS, party, 2, slots)
	var second: Dictionary = service.propose_pull(REEL_IN_PLUS, party, 2, slots)
	_check(first.get("ok") == true and second.get("ok") == true, "both replays propose")
	_check(first == second, "identical calls replay identically")
	_check(not is_same(first.get("slots"), second.get("slots")),
		"each proposal is an independent map")
	_check(not is_same(first.get("slots", {}).get(1), slots.get(2)),
		"the moved record is a detached copy of the caller's foe")
	var moved: Dictionary = first.get("slots", {}).get(1, {})
	_check(not moved.is_empty(), "replay fixture really moved the foe")
	if not moved.is_empty():
		moved["hp"] = 0
		moved["statuses"]["tangled"] = 99
		moved["id"] = "forged"
	first["cost"] = 99
	first["owner_position"] = 1
	var third: Dictionary = service.propose_pull(REEL_IN_PLUS, party, 2, slots)
	_check(third == second, "mutating one proposal cannot poison the next")
	_check(slots == slots_before, "the caller's snapshot is still pristine")
	_check(party.get_heroes() == heroes_before, "the party is still pristine")
	_check(rng.state == rng_before, "no seeded RNG state moved across the replays")
	# A refusal between two successes does not disturb the projection.
	var refused: Dictionary = service.propose_pull(THREAD, _party(2), 2,
		{1: _foe("button_guard", 1), 2: _foe("spool_stalker", 2)})
	_check(refused.get("ok") == false, "the interleaved refusal is refused")
	var fourth: Dictionary = service.propose_pull(REEL_IN_PLUS, party, 2, slots)
	_check(fourth == second, "the successful projection replays after a refusal")


# --- fixtures -------------------------------------------------------------------------------

func _party(seat: int, owner_hp: int = 27) -> CombatParty:
	var ids: Array[String] = ["warden", "tinker", "seamstress"]
	ids[seat - 1] = "yarn_ranger"
	var definitions: Array = []
	for index in range(3):
		definitions.append({"id": ids[index], "max_hp": MAX_HP[ids[index]]})
	var party := CombatParty.new(definitions)
	if party.is_valid() and party.get_hero(seat).get("hp") != owner_hp:
		party._heroes[seat - 1]["hp"] = owner_hp
	return party


## Slot 2 is the chosen foe; slot 1 is truly vacant and slot 3 is an untouched companion.
func _slots_target_two() -> Dictionary:
	return {2: _foe("spool_stalker", 2, 18, 18),
		3: _foe("button_guard", 3, 12, 12, 4, {"weak": 2})}


## Slot 3 is the chosen foe; slot 2 is truly vacant and slot 1 is an untouched companion.
func _slots_target_three() -> Dictionary:
	return {1: _foe("button_guard", 1, 12, 12, 4, {"exposed": 1}),
		3: _foe("spool_stalker", 3, 18, 18)}


func _foe(enemy_id: String, slot: int, hp: int = 9, max_hp: int = 9, block: Variant = 0,
		statuses: Variant = null) -> Dictionary:
	var record := {
		"id": enemy_id,
		"name": enemy_id.capitalize(),
		"max_hp": max_hp,
		"hp": hp,
		"block": block,
		"position": slot,
		"art_path": "res://assets/paper/enemies/" + enemy_id + ".png",
	}
	if statuses != null:
		record["statuses"] = statuses
	return record


# --- refusal fixture ------------------------------------------------------------------------

## Assert one refusal: no proposed roster, and no change to the party, the snapshot or seeded RNG.
func _rejected(label: String, card_id: Variant, party: Variant, target: Variant,
		slots: Variant, reason: String, lookup: Variant = null) -> void:
	var party_before: Variant = null
	if party != null and party is CombatParty:
		party_before = party.get_heroes()
	var slots_before: Variant = null
	if slots is Dictionary:
		slots_before = slots.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var rng_before: int = rng.state
	var result: Dictionary = service.propose_pull(card_id, party, target, slots, lookup)
	_check(result.get("ok") == false, label + ": refused")
	_check(result.get("reason") == reason,
		label + ": reason " + reason + " (got " + str(result.get("reason")) + ")")
	_check(not result.has("slots"), label + ": publishes no proposed roster")
	_check(not result.has("enemies") and not result.has("actors"),
		label + ": publishes no other roster")
	if party_before != null:
		_check(party.get_heroes() == party_before, label + ": the party is unchanged")
	if slots_before != null:
		_check(slots == slots_before, label + ": the snapshot is unchanged")
	_check(rng.state == rng_before, label + ": no seeded RNG draw is consumed")


## Apply one mutation to a fresh authentic record and prove both the authenticator and the
## proposal refuse it, through a testable catalog seam.
func _expect_descriptor_refused(label: String, card_id: String, catalog: Variant,
		mutation: Callable) -> void:
	var record: Dictionary = catalog.get_definition(card_id)
	if record.is_empty():
		_check(false, label + ": fixture record exists")
		return
	_check(ReelCards.is_authentic_definition(record, card_id),
		label + ": the unmutated fixture really authenticates")
	mutation.call(record)
	var lookup := func(_id: String) -> Dictionary: return record
	_check(not ReelCards.is_authentic_definition(record, card_id),
		label + ": the authenticator refuses the altered descriptor")
	_rejected(label, card_id, _party(2), 2, _slots_target_two(), "catalog_mismatch", lookup)
