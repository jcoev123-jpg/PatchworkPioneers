extends SceneTree
## V3-1 deterministic contract for the Yarn Ranger's Snare Shot first-attack passive.
##
## Snare Shot ("her first attack each combat also applies Tangled 1") is RULES-ONLY here: no live
## hand, battle flow, reward, shop or app path calls it. Every case drives the real authored hero
## (a living 27 HP Yarn Ranger in her printed seat) and a detached four-slot enemy snapshot through
## `CombatYarnRangerSnareCards.propose_snare_shot`, with a canonical confirmed paid attack receipt
## and the combat-level once-per-combat flag supplied by the caller. Nothing is paid, drawn or
## written: the proposal is a NEW enemy map plus an updated flag, and a later mounted flow still
## owns storing that flag and applying the proposal after a real paid attack.
##
## Attack-ness is never taken from the caller: it is derived from the Yarn Ranger starter/pool
## records themselves (authentic owner, enemy target kind, real printed positive Damage), which the
## refusal cases prove for Snare Net, Knit Shield, Hood Knit, Reel Thread, Reel In, every forged or
## foreign spelling and every printed support line left unchanged.

const SnareCards = preload("res://scripts/combat_yarn_ranger_snare_cards.gd")
const YarnRangerStarterCards = preload("res://data/cards/yarn_ranger_starter_cards.gd")
const YarnRangerPoolCards = preload("res://data/cards/yarn_ranger_pool_cards.gd")
const CombatStatuses = preload("res://scripts/combat_statuses.gd")
const CombatStatusTurnBatch = preload("res://scripts/combat_status_turn_batch.gd")

const NEEDLE_NOCK := "yarn_ranger_needle_nock"
const NEEDLE_NOCK_PLUS := "yarn_ranger_needle_nock_plus"
const WOOL_BOLAS := "yarn_ranger_wool_bolas"
const WOOL_BOLAS_PLUS := "yarn_ranger_wool_bolas_plus"
const REEL_THREAD := "yarn_ranger_reel_thread"
const REEL_THREAD_PLUS := "yarn_ranger_reel_thread_plus"
const HOOD_KNIT := "yarn_ranger_hood_knit"
const HOOD_KNIT_PLUS := "yarn_ranger_hood_knit_plus"
const NEEDLE_ARROW := "yarn_ranger_needle_arrow"
const NEEDLE_ARROW_PLUS := "yarn_ranger_needle_arrow_plus"
const TANGLE_BOLAS := "yarn_ranger_tangle_bolas"
const TANGLE_BOLAS_PLUS := "yarn_ranger_tangle_bolas_plus"
const REEL_IN := "yarn_ranger_reel_in"
const REEL_IN_PLUS := "yarn_ranger_reel_in_plus"
const KNIT_SHIELD := "yarn_ranger_knit_shield"
const KNIT_SHIELD_PLUS := "yarn_ranger_knit_shield_plus"
const PURLING_BARRAGE := "yarn_ranger_purling_barrage"
const PURLING_BARRAGE_PLUS := "yarn_ranger_purling_barrage_plus"
const SNARE_NET := "yarn_ranger_snare_net"
const SNARE_NET_PLUS := "yarn_ranger_snare_net_plus"
const UNSPOOL := "yarn_ranger_unspool"
const UNSPOOL_PLUS := "yarn_ranger_unspool_plus"
const ENDLESS_SKEIN := "yarn_ranger_endless_skein"
const ENDLESS_SKEIN_PLUS := "yarn_ranger_endless_skein_plus"

## The attack-only positives this contract must still derive as attacks (presence check, never a
## catalog total or a full ordered ID list).
const REQUIRED_ATTACK_IDS := [NEEDLE_NOCK, NEEDLE_NOCK_PLUS, WOOL_BOLAS, WOOL_BOLAS_PLUS,
	NEEDLE_ARROW, NEEDLE_ARROW_PLUS, TANGLE_BOLAS, TANGLE_BOLAS_PLUS, PURLING_BARRAGE,
	PURLING_BARRAGE_PLUS, UNSPOOL, UNSPOOL_PLUS, ENDLESS_SKEIN, ENDLESS_SKEIN_PLUS]
## The support lines the passive must never spend or reinterpret.
const REQUIRED_SUPPORT_IDS := [SNARE_NET, SNARE_NET_PLUS, KNIT_SHIELD, KNIT_SHIELD_PLUS,
	HOOD_KNIT, HOOD_KNIT_PLUS, REEL_THREAD, REEL_THREAD_PLUS, REEL_IN, REEL_IN_PLUS]

var failures: Array[String] = []
var checks: int = 0
var service := SnareCards.new()
var _starter := YarnRangerStarterCards.new()
var _pool := YarnRangerPoolCards.new()


func _initialize() -> void:
	_test_attack_derivation_from_catalogs()
	_test_ac1_fresh_and_spent_for_every_printing()
	_test_ac1_support_cards_never_spend_the_passive()
	_test_ac2_confirmed_recipients_across_four_slots()
	_test_ac2_single_target_and_sparse_slots()
	_test_ac2_blocked_missed_and_unconfirmed()
	_test_ac2_tangled_semantics_and_no_invented_duration()
	_test_ac2_detached_replay()
	_test_ac3_owner_refusals()
	_test_ac3_forged_and_non_attack_ids()
	_test_ac3_passive_state_refusals()
	_test_ac3_receipt_refusals()
	_test_ac3_snapshot_and_recipient_refusals()
	_test_ac3_purity_and_retry()
	_test_snare_net_unchanged()
	if failures.is_empty():
		print("combat_yarn_ranger_snare_shot_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_yarn_ranger_snare_shot_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


# --- attack-vs-support derivation --------------------------------------------------------------

## Snare Shot's attack-ness comes from the authored catalogs: an authentic `yarn_ranger` record
## aimed at enemies whose printed effects carry a real positive integer Damage. Every catalog ID,
## forged spelling and support line is classified by that rule alone.
func _test_attack_derivation_from_catalogs() -> void:
	var derived_attacks: Array[String] = []
	for card_id: String in _yarn_card_ids():
		var record: Dictionary = _card_record(card_id)
		_check(not record.is_empty(), card_id + ": resolves in its own Yarn catalog")
		var effects: Variant = record.get("effects", {})
		var damage: Variant = (effects as Dictionary).get("damage", null) \
			if effects is Dictionary else null
		var expected: bool = record.get("owner") == "yarn_ranger" \
			and [ "enemy_single", "enemy_all", "enemy_random" ].has(record.get("target_kind", "")) \
			and damage is int and int(damage) > 0
		_check(service.is_attack_card(card_id) == expected,
			card_id + ": attack-ness derived from its printed record alone")
		if expected:
			derived_attacks.append(card_id)
	_check(derived_attacks.size() >= REQUIRED_ATTACK_IDS.size(),
		"both catalogs expose the required attacks")
	for card_id: String in REQUIRED_ATTACK_IDS:
		_check(service.is_attack_card(card_id), card_id + ": derived as a real attack")
		_check(derived_attacks.has(card_id), card_id + ": part of the derived attack set")
	for card_id: String in REQUIRED_SUPPORT_IDS:
		_check(not service.is_attack_card(card_id), card_id + ": never derived as an attack")

	# The printed support lines are untouched: no Damage, no invented attack descriptor.
	for card_id: String in REQUIRED_SUPPORT_IDS:
		var effects: Dictionary = _card_record(card_id).get("effects", {})
		_check(not effects.has("damage"), card_id + ": still prints no Damage")
	_check(_card_record(SNARE_NET).get("cost") == 2
		and _card_record(SNARE_NET).get("effects") == {"tangled": 1, "living_targets_only": true},
		"Snare Net still prints two energy and Tangled 1")
	_check(_card_record(SNARE_NET_PLUS).get("cost") == 2
		and _card_record(SNARE_NET_PLUS).get("effects")
			== {"tangled": 2, "living_targets_only": true},
		"Snare Net+ still prints two energy and Tangled 2")
	_check(_card_record(KNIT_SHIELD).get("effects") == {"block": 6, "draw": 1},
		"Knit Shield still prints its Block and draw")
	_check(_card_record(HOOD_KNIT).get("effects") == {"block": 4, "draw": 1},
		"Hood Knit still prints its Block and draw")
	_check(_card_record(REEL_THREAD).get("effects") == {"pull_forward": 1},
		"Reel Thread still prints only its pull")
	_check(_card_record(REEL_IN).get("effects") == {"pull_forward": 1, "tangled": 1},
		"Reel In still prints its pull and Tangled 1")

	# The printed attack values are preserved exactly as the catalogs state them.
	_check(_card_record(NEEDLE_NOCK).get("effects") == {"damage": 4, "unravel": 1},
		"Needle Nock still prints Damage 4 and Unravel 1")
	_check(_card_record(NEEDLE_NOCK_PLUS).get("effects") == {"damage": 6, "unravel": 2},
		"Needle Nock+ still prints Damage 6 and Unravel 2")
	_check(_card_record(WOOL_BOLAS).get("effects") == {"damage": 2, "tangled": 1},
		"Wool Bolas still prints Damage 2 and Tangled 1")
	_check(_card_record(WOOL_BOLAS_PLUS).get("effects") == {"damage": 3, "tangled": 2},
		"Wool Bolas+ still prints Damage 3 and Tangled 2")
	_check(_card_record(PURLING_BARRAGE).get("effects")
		== {"damage": 3, "hit_count": 2, "unravel": 1},
		"Purling Barrage still prints its two-hit Damage 3 line")

	# Foreign, forged, lowercased, non-string and non-ID values are never attacks.
	for forged: Variant in ["warden_strike", "seamstress_prick", "tinker_pop_shot",
			NEEDLE_NOCK + "+", "yarn_ranger_needle_nock_plus_plus", SNARE_NET + "_plus_plus",
			"needle_nock", "YARN_RANGER_NEEDLE_NOCK", " " + NEEDLE_NOCK, NEEDLE_NOCK + " ", "",
			StringName(NEEDLE_NOCK), null, 0, 1, 3.5, false, [], {}]:
		_check(not service.is_attack_card(forged),
			"forged or foreign ID is never an attack: " + str(forged))
	# Support and attacks alike stay outside the paid Snare Net card table, which is untouched.
	_check(service.is_supported_card(SNARE_NET) and service.is_supported_card(SNARE_NET_PLUS),
		"the paid Snare Net table is unchanged")
	_check(not service.is_supported_card(NEEDLE_NOCK),
		"a real attack is not admitted into the paid Snare Net table")


# --- AC1 ---------------------------------------------------------------------------------------

## AC1: from a FRESH combat-level flag, every authentic base and "+" attack in both catalogs, cast
## from each seat its own record prints, offers exactly one Tangled-1 rider; feeding the returned
## flag back in refuses the next attack because it is already spent.
func _test_ac1_fresh_and_spent_for_every_printing() -> void:
	var cases := 0
	for card_id: String in _attack_ids():
		var record: Dictionary = _card_record(card_id)
		var cost: int = int(record["cost"])
		var multi: bool = record.get("target_kind") != "enemy_single"
		for seat: int in record.get("from_positions", []):
			cases += 1
			var label: String = card_id + " from seat " + str(seat)
			var party := _party(seat)
			_check(party.get_hero(seat).get("id") == "yarn_ranger"
				and party.get_hero(seat).get("hp") == 27
				and party.get_hero(seat).get("max_hp") == 27,
				label + ": real living 27 HP Yarn Ranger fixture")
			var slots: Dictionary = _four_slot_fixture()
			var slots_before: Dictionary = slots.duplicate(true)
			var receipt: Dictionary = _multi_receipt(card_id, seat, cost, [2, 3]) if multi \
				else _single_receipt(card_id, seat, cost, 2)
			var receipt_before: Dictionary = receipt.duplicate(true)
			var fresh: Dictionary = SnareCards.fresh_snare_shot_state()
			_check(fresh == {"available": true, "consumed": false},
				label + ": a fresh flag starts available")

			var result: Dictionary = service.propose_snare_shot(card_id, party, slots, receipt, fresh)

			_check(result.get("ok") == true and result.get("reason") == "proposed",
				label + ": a fresh flag offers the rider")
			_check(result.get("passive") == "snare_shot",
				label + ": the receipt names the roster passive")
			_check(result.get("card_id") == card_id, label + ": the authentic attack ID")
			_check(result.get("catalog") == _catalog_name(card_id),
				label + ": the receipt names the owning catalog")
			_check(result.get("cost_paid") == cost, label + ": the receipt reports the printed cost")
			_check(result.get("owner_position") == seat, label + ": the receipt reports her seat")
			_check(result.get("tangled_added") == 1, label + ": exactly one Tangled")
			_check(result.get("passive_state") == {"available": false, "consumed": true},
				label + ": the returned flag is consumed")
			_check(result.get("recipient_positions") == ([2, 3] if multi else [2]),
				label + ": the confirmed hit recipients are named in order")
			for unwanted: String in ["damage", "hp", "block", "energy", "draw", "discard",
					"move", "duration"]:
				_check(not result.has(unwanted), label + ": never claims " + unwanted)

			var second: Dictionary = service.propose_snare_shot(card_id, party, slots, receipt,
				result.get("passive_state"))
			_check(second.get("ok") == false and second.get("reason") == "passive_spent",
				label + ": the next attack finds the flag already spent")
			_check(not second.has("enemies"),
				label + ": a spent flag publishes no further enemy map")
			_check(slots == slots_before, label + ": the caller snapshot is never written")
			_check(receipt == receipt_before, label + ": the caller receipt is never rewritten")
			_check(fresh == {"available": true, "consumed": false},
				label + ": the caller's fresh flag dictionary is never mutated")
	_check(cases >= REQUIRED_ATTACK_IDS.size(), "AC1 covers every required attack and both seats")

	# A genuinely fresh flag after a spent one may propose again: only the caller's flag expired.
	var replay: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(3),
		_four_slot_fixture(), _single_receipt(NEEDLE_NOCK, 3, 1, 1),
		SnareCards.fresh_snare_shot_state())
	_check(replay.get("ok") == true and replay.get("tangled_added") == 1,
		"an explicit fresh flag proposes normally (the flag is caller-owned state)")


## AC1: the non-attack support lines never spend the attack-only passive, and a genuine attack
## afterwards still receives its one rider.
func _test_ac1_support_cards_never_spend_the_passive() -> void:
	var fresh: Dictionary = SnareCards.fresh_snare_shot_state()
	var slots: Dictionary = _four_slot_fixture()
	for card_id: String in REQUIRED_SUPPORT_IDS:
		var record: Dictionary = _card_record(card_id)
		var cost: int = int(record["cost"])
		var seat: int = int(record.get("from_positions", [2])[0])
		var receipt: Dictionary = _multi_receipt(card_id, seat, cost, [1, 2]) \
			if record.get("target_kind") != "enemy_single" else _single_receipt(card_id, seat, cost, 1)
		_rejected(card_id + " is support, not an attack", "not_an_attack", card_id, _party(seat),
			slots, receipt, fresh)
		_check(fresh == {"available": true, "consumed": false},
			card_id + ": the attack-only flag is still available")
	var after: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(3), slots,
		_single_receipt(NEEDLE_NOCK, 3, 1, 1), fresh)
	_check(after.get("ok") == true,
		"a genuine attack still triggers after every non-attack refusal")
	_check(after.get("tangled_added") == 1, "the support refusals cost no rider")


# --- AC2 ---------------------------------------------------------------------------------------

## AC2: every actual living hit recipient gains exactly Tangled 1 on its existing count (absent
## means zero), including slot 4; untargeted, dead and missed foes are untouched, positions never
## compact and the caller's snapshot is not aliased.
func _test_ac2_confirmed_recipients_across_four_slots() -> void:
	var slots := {
		1: _foe("button_guard", 1, 12, 12, 3, {"weak": 1}),
		2: _foe("spool_stalker", 2, 18, 18, 0, {"tangled": 2, "bleed": 1}),
		3: _foe("moth_swarm", 3, 14, 20, 0, {}),
		4: _foe("hoard_beetle", 4, 24, 24, 5, {"exposed": 2}),
	}
	var snapshot_before: Dictionary = slots.duplicate(true)
	var receipt := _multi_receipt(UNSPOOL, 3, 2, [2, 4])
	var receipt_before: Dictionary = receipt.duplicate(true)
	var state := SnareCards.fresh_snare_shot_state()

	var result: Dictionary = service.propose_snare_shot(UNSPOOL, _party(3), slots, receipt, state)

	_check(result.get("ok") == true, "AC2: the confirmed multi-target hit proposes")
	_check(result.get("recipient_positions") == [2, 4],
		"AC2: only the two confirmed recipients are named, in hit order")
	var enemies: Dictionary = result.get("enemies", {})
	var keys: Array = enemies.keys()
	keys.sort()
	_check(keys == [1, 2, 3, 4], "AC2: the published map keeps exactly the four slots")
	_check(enemies.get(2).get("statuses").get("tangled") == 3,
		"AC2: an existing Tangled 2 becomes Tangled 3")
	_check(enemies.get(4).get("statuses").get("tangled") == 1,
		"AC2: a bare fourth-slot foe gains Tangled 1")
	_check(enemies.get(2).get("statuses").get("bleed") == 1,
		"AC2: other counters on a recipient are preserved")
	_check(enemies.get(4).get("statuses").get("exposed") == 2,
		"AC2: other counters on the fourth foe are preserved")
	_check(enemies.get(1) == slots[1], "AC2: the untargeted front foe is untouched")
	_check(enemies.get(3) == slots[3], "AC2: the untargeted third foe is untouched")
	_check((enemies.get(3).get("statuses", {}) as Dictionary).is_empty(),
		"AC2: no counter is invented on an untargeted foe")
	for slot: int in [1, 2, 3, 4]:
		_check(enemies.get(slot).get("position") == slot,
			"AC2: slot " + str(slot) + " keeps its own position (no compaction)")
		_check(enemies.get(slot).get("id") == slots[slot].get("id"),
			"AC2: slot " + str(slot) + " keeps its own identity")
		_check(enemies.get(slot).get("hp") == slots[slot].get("hp")
			and enemies.get(slot).get("block") == slots[slot].get("block"),
			"AC2: slot " + str(slot) + " takes no Damage and loses no Block")
	_check(enemies.get(2).keys().size() == slots[2].keys().size(),
		"AC2: a recipient record gains and loses no field")
	var updates: Array = result.get("status_updates", [])
	_check(updates.size() == 2, "AC2: one ordered receipt entry per recipient")
	_check(updates[0] == {"position": 2, "enemy_id": "spool_stalker", "tangled_before": 2,
		"tangled_after": 3}, "AC2: the first receipt entry reports before and after")
	_check(updates[1] == {"position": 4, "enemy_id": "hoard_beetle", "tangled_before": 0,
		"tangled_after": 1}, "AC2: the second receipt entry reports absent-means-zero")
	_check(slots == snapshot_before, "AC2: the caller's snapshot is unchanged")
	_check(receipt == receipt_before, "AC2: the caller's receipt is unchanged")
	_check(state == {"available": true, "consumed": false}, "AC2: the caller's flag is unchanged")
	_check(enemies.get(2).get("statuses").get("tangled") == 3 and slots[2].get("statuses")
		.get("tangled") == 2, "AC2: the proposal never aliases the caller's status map")
	for slot: int in [1, 2, 3, 4]:
		_check(not is_same(enemies.get(slot), snapshot_before[slot]),
			"AC2: slot " + str(slot) + " is a detached copy, never a shared dictionary")

	# Each slot individually: a confirmed hit on any of slots 1-4 lands on that slot alone.
	var bare := {1: _foe("button_guard", 1, 12, 12), 2: _foe("spool_stalker", 2, 18, 18),
		3: _foe("moth_swarm", 3, 14, 20), 4: _foe("hoard_beetle", 4, 24, 24)}
	for target: int in [1, 2, 3, 4]:
		var single: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(3), bare,
			_single_receipt(NEEDLE_NOCK, 3, 1, target), SnareCards.fresh_snare_shot_state())
		_check(single.get("ok") == true, "slot " + str(target) + ": one confirmed hit proposes")
		_check(single.get("recipient_positions") == [target],
			"slot " + str(target) + ": only that foe is tangled")
		var single_enemies: Dictionary = single.get("enemies", {})
		for slot: int in [1, 2, 3, 4]:
			var statuses: Dictionary = single_enemies.get(slot, {}).get("statuses", {})
			if slot == target:
				_check(statuses.get("tangled") == 1,
					"slot " + str(target) + ": gains exactly Tangled 1")
			else:
				_check(not statuses.has("tangled"),
					"slot " + str(slot) + ": stays untangled when slot " + str(target) + " is hit")
		_check(bare.get(1).get("statuses") == null and bare.get(4).get("statuses") == null,
			"slot " + str(target) + ": the snapshot gains no status map")

	# A repeated position in a real multi-hit list is still one recipient, never two riders.
	var barrage: Dictionary = service.propose_snare_shot(UNSPOOL, _party(3),
		_four_slot_fixture(), _multi_receipt(UNSPOOL, 3, 2, [3, 3]),
		SnareCards.fresh_snare_shot_state())
	_check(barrage.get("ok") == true and barrage.get("recipient_positions") == [3],
		"a repeated hit position collapses to exactly one recipient")
	_check(barrage.get("enemies").get(3).get("statuses").get("tangled") == 1,
		"a second hit on the same foe never adds a second Tangled")


## AC2/AC3: the published map is always the full four-key shape, whether the caller's snapshot has
## a vacant slot 1, an explicit empty slot, or a dead untargeted foe at the rear.
func _test_ac2_single_target_and_sparse_slots() -> void:
	var sparse := {2: _foe("spool_stalker", 2, 18, 18, 0, {"tangled": 2}),
		3: _foe("moth_swarm", 3, 14, 20, 0)}
	_check(not sparse.has(1) and not sparse.has(4), "the sparse fixture really omits slots 1 and 4")
	var result: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(3), sparse,
		_single_receipt(NEEDLE_NOCK, 3, 1, 2), SnareCards.fresh_snare_shot_state())
	_check(result.get("ok") == true, "sparse snapshot: the confirmed hit proposes")
	var enemies: Dictionary = result.get("enemies", {})
	var keys: Array = enemies.keys()
	keys.sort()
	_check(keys == [1, 2, 3, 4], "sparse snapshot: publishes exactly keys 1,2,3,4")
	_check(enemies.get(1) == {}, "sparse snapshot: the absent front slot stays vacant")
	_check(enemies.get(4) == {}, "sparse snapshot: the absent rear slot stays vacant")
	_check(enemies.get(2).get("statuses").get("tangled") == 3,
		"sparse snapshot: the hit foe stacks one on its existing count")
	_check(enemies.get(2).get("position") == 2,
		"sparse snapshot: the hit foe is not compacted forward")
	_check(enemies.get(3) == sparse[3], "sparse snapshot: the untargeted foe is untouched")

	var explicit := {1: {}, 2: _foe("spool_stalker", 2, 18, 18),
		3: _foe("moth_swarm", 3, 14, 20), 4: _foe("hoard_beetle", 4, 24, 24)}
	var explicit_result: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(2), explicit,
		_single_receipt(NEEDLE_NOCK, 2, 1, 3), SnareCards.fresh_snare_shot_state())
	_check(explicit_result.get("ok") == true, "explicit empty slot: still proposes")
	_check(explicit_result.get("enemies").get(1) == {},
		"explicit empty slot: stays empty, nothing is moved into it")
	_check(explicit_result.get("enemies").get(4) == explicit[4],
		"explicit empty slot: the untouched fourth foe is preserved")

	# A dead, untargeted foe keeps its HP, position, Block and counters exactly.
	var dead_rear := {1: _foe("button_guard", 1, 12, 12), 2: _foe("spool_stalker", 2, 18, 18),
		4: _foe("hoard_beetle", 4, 0, 24, 5, {"tangled": 4, "exposed": 1})}
	_check(dead_rear[4].get("hp") == 0, "the dead-rear fixture really is a slain record")
	var dead_result: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(3), dead_rear,
		_single_receipt(NEEDLE_NOCK, 3, 1, 2), SnareCards.fresh_snare_shot_state())
	_check(dead_result.get("ok") == true, "dead rear foe: the living hit still proposes")
	_check(dead_result.get("enemies").get(4) == dead_rear[4],
		"dead rear foe: the slain untargeted slot is untouched")
	_check(dead_result.get("enemies").get(4).get("statuses").get("tangled") == 4,
		"dead rear foe: no rider is invented on a corpse")


## AC2: a fully Block-absorbed confirmed hit still carries the rider; a missed or unconfirmed
## attempt, and a lethal confirmed hit that left no living recipient, carry none.
func _test_ac2_blocked_missed_and_unconfirmed() -> void:
	var blocked := {1: _foe("button_guard", 1, 12, 12, 9, {"weak": 1}),
		2: _foe("spool_stalker", 2, 18, 18)}
	var blocked_before: Dictionary = blocked.duplicate(true)
	var result: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(2), blocked,
		_single_receipt(NEEDLE_NOCK, 2, 1, 1), SnareCards.fresh_snare_shot_state())
	_check(result.get("ok") == true,
		"a fully Block-absorbed confirmed hit still applies the rider")
	_check(result.get("enemies").get(1).get("statuses").get("tangled") == 1,
		"the Blocked recipient gains Tangled 1")
	_check(result.get("enemies").get(1).get("hp") == 12
		and result.get("enemies").get(1).get("block") == 9,
		"the Blocked recipient's HP and Block are the confirmed post-hit values")
	_check(blocked == blocked_before, "the Blocked snapshot itself is unchanged")

	var slots: Dictionary = _four_slot_fixture()
	var fresh: Dictionary = SnareCards.fresh_snare_shot_state()
	var missed: Dictionary = _single_receipt(NEEDLE_NOCK, 2, 1, 1)
	missed["missed"] = true
	_rejected("a missed attack has no rider", "missed_attack", NEEDLE_NOCK, _party(2), slots,
		missed, fresh)
	var unconfirmed: Dictionary = _single_receipt(NEEDLE_NOCK, 2, 1, 1)
	unconfirmed["hit_confirmed"] = false
	_rejected("an unconfirmed attempt has no rider", "unconfirmed_hit", NEEDLE_NOCK, _party(2),
		slots, unconfirmed, fresh)
	_check(fresh == {"available": true, "consumed": false},
		"a miss or an unconfirmed attempt never spends the passive")

	# A lethal confirmed hit leaves no living recipient: refuse and keep the flag available.
	var lethal := {1: _foe("button_guard", 1, 0, 12, 0, {"tangled": 1}),
		2: _foe("spool_stalker", 2, 18, 18)}
	_rejected("a lethal confirmed hit has no living recipient", "recipient_downed", NEEDLE_NOCK,
		_party(2), lethal, _single_receipt(NEEDLE_NOCK, 2, 1, 1), fresh)
	_check(fresh == {"available": true, "consumed": false},
		"a refusal never consumes the passive")
	var retry: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(2), slots,
		_single_receipt(NEEDLE_NOCK, 2, 1, 2), fresh)
	_check(retry.get("ok") == true, "the passive still fires after those refusals")


## AC2: the proposal keeps V3-2 Tangled's existing meaning — cannot be moved by its own side and
## takes +2 from attacks — and leaves duration/ticking to the existing status consumer.
func _test_ac2_tangled_semantics_and_no_invented_duration() -> void:
	var rules := CombatStatuses.new()
	var batch := CombatStatusTurnBatch.new()
	var slots := {1: _foe("spool_stalker", 1, 18, 18, 0, {"tangled": 2}),
		2: _foe("moth_swarm", 2, 14, 20)}
	var result: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(3), slots,
		_single_receipt(NEEDLE_NOCK, 3, 1, 1), SnareCards.fresh_snare_shot_state())
	_check(result.get("ok") == true, "tangled semantics: the rider proposes on a Tangled foe")
	var stacked: Dictionary = result.get("enemies").get(1).get("statuses", {})
	_check(stacked == {"tangled": 3},
		"tangled semantics: exactly one added count, no extra key or duration")
	_check(rules.adjusted_attack_damage(5, {}, stacked) == 7,
		"tangled semantics: a positive-base attack takes the flat +2 once")
	_check(rules.adjusted_attack_damage(0, {}, stacked) == 0,
		"tangled semantics: a zero-base hit never borrows the +2")
	var roster: Array[Dictionary] = [result.get("enemies").get(1), result.get("enemies").get(2)]
	var roster_before: Array[Dictionary] = roster.duplicate(true)
	var tick: Dictionary = batch.tick_side("enemies", roster, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(tick.get("ok") == true,
		"tangled semantics: the existing owner-turn consumer accepts the proposal")
	_check((tick["actors"] as Array)[0]["statuses"] == {"tangled": 2},
		"tangled semantics: three remaining owner turns tick down to two")
	_check((tick["actors"] as Array)[1]["statuses"] == {},
		"tangled semantics: a fresh count of one expires at its owner-turn boundary")
	_check(roster == roster_before,
		"tangled semantics: ticking stays a projection, not a write into the proposal")


## AC2: the proposal replays deterministically, is fully detached and cannot be poisoned.
func _test_ac2_detached_replay() -> void:
	var party := _party(3)
	var slots: Dictionary = _four_slot_fixture()
	var heroes_before: Array = party.get_heroes()
	var snapshot_before: Dictionary = slots.duplicate(true)
	var receipt := _multi_receipt(ENDLESS_SKEIN, 3, 3, [1, 3, 4])
	var receipt_before: Dictionary = receipt.duplicate(true)
	var state := SnareCards.fresh_snare_shot_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261102
	var rng_before: int = rng.state

	var first: Dictionary = service.propose_snare_shot(ENDLESS_SKEIN, party, slots, receipt, state)
	var second: Dictionary = service.propose_snare_shot(ENDLESS_SKEIN, party, slots, receipt, state)
	_check(first.get("ok") == true and second.get("ok") == true, "replay: both proposals succeed")
	_check(first == second, "replay: identical calls publish identical receipts")
	_check(not is_same(first.get("enemies"), second.get("enemies")),
		"replay: each proposal publishes an independent map")
	_check(not is_same(first.get("enemies", {}).get(3), slots.get(3)),
		"replay: a recipient is a detached copy of the caller's record")
	_check(not is_same(first.get("enemies", {}).get(1), slots.get(1)),
		"replay: an untouched foe is a detached copy too")
	var poisoned: Dictionary = first.get("enemies", {})
	poisoned[1]["hp"] = 0
	poisoned[1]["statuses"] = {"tangled": 99}
	poisoned[3]["id"] = "forged"
	first["passive_state"]["available"] = true
	first["tangled_added"] = 9
	var third: Dictionary = service.propose_snare_shot(ENDLESS_SKEIN, party, slots, receipt, state)
	_check(third == second, "replay: mutating one proposal cannot poison the next")
	_check(slots == snapshot_before, "replay: the caller's snapshot is still pristine")
	_check(receipt == receipt_before, "replay: the caller's receipt is still pristine")
	_check(state == {"available": true, "consumed": false},
		"replay: the caller's flag is still pristine")
	_check(party.get_heroes() == heroes_before, "replay: the authoritative party is unchanged")
	_check(rng.state == rng_before, "replay: no seeded RNG state moved")


# --- AC3 ---------------------------------------------------------------------------------------

## AC3: an absent, downed, misplaced or malformed owner refuses without a proposal.
func _test_ac3_owner_refusals() -> void:
	var slots: Dictionary = _four_slot_fixture()
	var fresh := SnareCards.fresh_snare_shot_state()
	_rejected("null party", "invalid_request", NEEDLE_NOCK, null, slots,
		_single_receipt(NEEDLE_NOCK, 2, 1, 1), fresh)
	var short_party := CombatParty.new([{"id": "yarn_ranger", "max_hp": 27}])
	_rejected("one-hero party", "invalid_party", NEEDLE_NOCK, short_party, slots,
		_single_receipt(NEEDLE_NOCK, 2, 1, 1), fresh)
	var duplicate := _party(2)
	duplicate._heroes[2]["id"] = "yarn_ranger"
	_check(duplicate.get_hero(2).get("id") == "yarn_ranger"
		and duplicate.get_hero(3).get("id") == "yarn_ranger",
		"the duplicate-owner fixture really repeats the ID")
	_rejected("duplicate hero identities", "invalid_party", NEEDLE_NOCK, duplicate, slots,
		_single_receipt(NEEDLE_NOCK, 2, 1, 1), fresh)
	var malformed := _party(2)
	malformed._heroes[0]["statuses"] = "weak"
	_rejected("malformed hero status map", "invalid_party", NEEDLE_NOCK, malformed, slots,
		_single_receipt(NEEDLE_NOCK, 2, 1, 1), fresh)
	var misplaced := _party(2)
	misplaced._heroes[1]["position"] = 9
	_rejected("misplaced hero record", "invalid_party", NEEDLE_NOCK, misplaced, slots,
		_single_receipt(NEEDLE_NOCK, 2, 1, 1), fresh)

	var no_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
	_check(no_owner.is_valid() and no_owner.get_hero(2).get("id") == "seamstress",
		"the absent-owner fixture is a real three-hero party without the Yarn Ranger")
	_rejected("no Yarn Ranger in the party", "owner_missing", NEEDLE_NOCK, no_owner, slots,
		_single_receipt(NEEDLE_NOCK, 2, 1, 1), fresh)

	var downed := _party(3, 0)
	_check(downed.is_downed(3), "the downed-owner fixture really is at 0 HP")
	_rejected("downed Yarn Ranger", "owner_downed", NEEDLE_NOCK, downed, slots,
		_single_receipt(NEEDLE_NOCK, 3, 1, 1), fresh)

	# A receipt naming a seat that is not her current seat is not her attack.
	_rejected("receipt names another seat", "owner_mismatch", NEEDLE_NOCK, _party(2), slots,
		_single_receipt(NEEDLE_NOCK, 3, 1, 1), fresh)
	_rejected("receipt names the front seat", "owner_mismatch", NEEDLE_NOCK, _party(2), slots,
		_single_receipt(NEEDLE_NOCK, 1, 1, 1), fresh)

	# She is alive in the party but her printing cannot be played from that seat.
	_rejected("Yarn Ranger in the front seat cannot play a FROM 2-3 attack",
		"owner_illegal_position", NEEDLE_NOCK, _party(1), slots,
		_single_receipt(NEEDLE_NOCK, 1, 1, 1), fresh)
	# Purling Barrage prints FROM seat 3 only.
	_rejected("Purling Barrage from seat 2", "owner_illegal_position", PURLING_BARRAGE, _party(2),
		slots, _single_receipt(PURLING_BARRAGE, 2, 2, 1), fresh)
	_check(fresh == {"available": true, "consumed": false},
		"every owner refusal left the passive available")
	var still_works: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(3), slots,
		_single_receipt(NEEDLE_NOCK, 3, 1, 1), fresh)
	_check(still_works.get("ok") == true,
		"a legal attack still triggers after the owner refusals")


## AC3: forged, foreign, unowned and non-attack card IDs never propose or spend anything.
func _test_ac3_forged_and_non_attack_ids() -> void:
	var slots: Dictionary = _four_slot_fixture()
	var fresh := SnareCards.fresh_snare_shot_state()
	var forged: Array = ["yarn_ranger_needle_nock+", "yarn_ranger_needle_nock_plus_plus",
		"yarn_ranger_wool_bolas_plus_plus", "needle_nock", "YARN_RANGER_NEEDLE_NOCK",
		" yarn_ranger_needle_nock", "yarn_ranger_needle_nock ", "",
		"warden_strike", "seamstress_prick", "tinker_pop_shot", "yarn_ranger_snare_net_plus2",
		StringName(NEEDLE_NOCK), null, 0, 1, 3.5, false, [], {}]
	for wrong_id: Variant in forged:
		_rejected("forged or foreign ID " + str(wrong_id), "unsupported_card", wrong_id,
			_party(2), slots, _single_receipt(NEEDLE_NOCK, 2, 1, 1), fresh)
	for support_id: String in REQUIRED_SUPPORT_IDS:
		var record: Dictionary = _card_record(support_id)
		var cost: int = int(record["cost"])
		var seat: int = int(record.get("from_positions", [2])[0])
		var receipt: Dictionary = _multi_receipt(support_id, seat, cost, [1]) \
			if record.get("target_kind") != "enemy_single" \
			else _single_receipt(support_id, seat, cost, 1)
		_rejected("authentic support line " + support_id, "not_an_attack", support_id,
			_party(seat), slots, receipt, fresh)
	# A forged "is_attack" claim cannot turn a support card into an attack.
	var forged_claim: Dictionary = _single_receipt(SNARE_NET, 2, 2, 1)
	forged_claim["is_attack"] = true
	_rejected("a caller-supplied is_attack claim is never authority", "not_an_attack", SNARE_NET,
		_party(2), slots, forged_claim, fresh)
	_check(fresh == {"available": true, "consumed": false},
		"no forged or support ID spent the passive")


## AC3: a stale, inconsistent or already consumed combat-level flag refuses before anything else.
func _test_ac3_passive_state_refusals() -> void:
	var slots: Dictionary = _four_slot_fixture()
	var receipt := _single_receipt(NEEDLE_NOCK, 2, 1, 1)
	for bad_state: Variant in [null, [], "available", 1, true,
			{"available": true}, {"consumed": false},
			{"available": true, "consumed": false, "spent_turn": 2},
			{"available": true, "consumed": false, "extra": true},
			{"available": 1, "consumed": 0}, {"available": "true", "consumed": "false"},
			{"available": true, "consumed": true}, {"available": false, "consumed": false}]:
		_rejected("invalid flag " + str(bad_state), "invalid_passive_state", NEEDLE_NOCK,
			_party(2), slots, receipt, bad_state)
	_rejected("already consumed flag", "passive_spent", NEEDLE_NOCK, _party(2), slots, receipt,
		{"available": false, "consumed": true})
	var spent := {"available": false, "consumed": true}
	var spent_before: Dictionary = spent.duplicate(true)
	var refused: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, _party(2), slots, receipt,
		spent)
	_check(refused.get("ok") == false and refused.get("reason") == "passive_spent",
		"a consumed flag refuses the rider")
	_check(spent == spent_before, "the consumed flag is not rewritten by the refusal")
	_check(not slots.get(1).has("statuses"), "a stale flag writes no Tangled")


## AC3: malformed, inconsistent or unconfirmed hit receipts are refused whole.
func _test_ac3_receipt_refusals() -> void:
	var slots: Dictionary = _four_slot_fixture()
	var fresh := SnareCards.fresh_snare_shot_state()
	var good := _single_receipt(NEEDLE_NOCK, 2, 1, 1)
	for malformed: Variant in [null, [], "receipt", 7, true]:
		_rejected("non-dictionary receipt " + str(malformed), "malformed_receipt", NEEDLE_NOCK,
			_party(2), slots, malformed, fresh)

	for key: String in ["card_id", "owner_position", "cost_paid", "paid", "hit_confirmed"]:
		_rejected("receipt missing " + key, "malformed_receipt", NEEDLE_NOCK, _party(2), slots,
			_receipt_without(good, key), fresh)

	var swapped: Dictionary = good.duplicate(true)
	swapped["card_id"] = WOOL_BOLAS
	_rejected("receipt for another card", "receipt_card_mismatch", NEEDLE_NOCK, _party(2), slots,
		swapped, fresh)
	var unpaid: Dictionary = good.duplicate(true)
	unpaid["paid"] = false
	_rejected("unpaid attack", "unpaid_attack", NEEDLE_NOCK, _party(2), slots, unpaid, fresh)
	var coerced_paid: Dictionary = good.duplicate(true)
	coerced_paid["paid"] = "true"
	_rejected("string paid flag", "unpaid_attack", NEEDLE_NOCK, _party(2), slots, coerced_paid,
		fresh)
	var unconfirmed: Dictionary = good.duplicate(true)
	unconfirmed["hit_confirmed"] = 1
	_rejected("non-boolean hit confirmation", "unconfirmed_hit", NEEDLE_NOCK, _party(2), slots,
		unconfirmed, fresh)
	var missed_float: Dictionary = good.duplicate(true)
	missed_float["missed"] = 1
	_rejected("non-boolean missed flag", "malformed_receipt", NEEDLE_NOCK, _party(2), slots,
		missed_float, fresh)
	var cheap: Dictionary = good.duplicate(true)
	cheap["cost_paid"] = 0
	_rejected("wrong paid cost", "receipt_cost_mismatch", NEEDLE_NOCK, _party(2), slots, cheap,
		fresh)
	var expensive: Dictionary = good.duplicate(true)
	expensive["cost_paid"] = 2
	_rejected("overpaid cost", "receipt_cost_mismatch", NEEDLE_NOCK, _party(2), slots, expensive,
		fresh)
	var string_cost: Dictionary = good.duplicate(true)
	string_cost["cost_paid"] = "1"
	_rejected("string paid cost", "receipt_cost_mismatch", NEEDLE_NOCK, _party(2), slots,
		string_cost, fresh)
	var float_seat: Dictionary = good.duplicate(true)
	float_seat["owner_position"] = 2.0
	_rejected("float owner seat", "malformed_receipt", NEEDLE_NOCK, _party(2), slots, float_seat,
		fresh)
	var both_forms: Dictionary = good.duplicate(true)
	both_forms["hit_positions"] = [1]
	_rejected("both target forms", "malformed_receipt", NEEDLE_NOCK, _party(2), slots, both_forms,
		fresh)
	var no_form: Dictionary = good.duplicate(true)
	no_form.erase("target_position")
	_rejected("no target form", "malformed_receipt", NEEDLE_NOCK, _party(2), slots, no_form, fresh)
	var extra_key: Dictionary = good.duplicate(true)
	extra_key["damage"] = 99
	_rejected("a caller-supplied extra field", "malformed_receipt", NEEDLE_NOCK, _party(2), slots,
		extra_key, fresh)
	var string_target: Dictionary = good.duplicate(true)
	string_target["target_position"] = "1"
	_rejected("string target", "malformed_receipt", NEEDLE_NOCK, _party(2), slots, string_target,
		fresh)
	var empty_hits: Dictionary = _multi_receipt(UNSPOOL, 3, 2, [])
	_rejected("empty hit list", "no_hit_recipients", UNSPOOL, _party(3), slots, empty_hits, fresh)
	var string_hit: Dictionary = _multi_receipt(UNSPOOL, 3, 2, [1, "2"])
	_rejected("string in the hit list", "malformed_receipt", UNSPOOL, _party(3), slots, string_hit,
		fresh)
	var hits_not_array: Dictionary = _multi_receipt(UNSPOOL, 3, 2, [1])
	hits_not_array["hit_positions"] = 1
	_rejected("hit list that is not a list", "malformed_receipt", UNSPOOL, _party(3), slots,
		hits_not_array, fresh)
	# The receipt form must match the printed targeting: one foe for a single-target printing,
	# the confirmed hit list for a real multi-target attack.
	_rejected("hit list for a single-target attack", "receipt_target_mismatch", NEEDLE_NOCK,
		_party(2), slots, _multi_receipt(NEEDLE_NOCK, 2, 1, [1]), fresh)
	_rejected("single target for an all-enemy attack", "receipt_target_mismatch", UNSPOOL,
		_party(3), slots, _single_receipt(UNSPOOL, 3, 2, 1), fresh)
	# Out-of-domain recipient positions are refused before any snapshot lookup.
	for bad_position: Variant in [0, 5, -1, 99]:
		var out_of_domain: Dictionary = good.duplicate(true)
		out_of_domain["target_position"] = bad_position
		_rejected("out-of-domain recipient " + str(bad_position), "invalid_recipient", NEEDLE_NOCK,
			_party(2), slots, out_of_domain, fresh)
	_check(fresh == {"available": true, "consumed": false},
		"every malformed receipt left the passive available")


## AC3: invalid recipient/status maps, malformed snapshots and counter overflow are refused whole.
func _test_ac3_snapshot_and_recipient_refusals() -> void:
	var receipt := _single_receipt(NEEDLE_NOCK, 2, 1, 1)
	var fresh := SnareCards.fresh_snare_shot_state()
	for malformed: Variant in [null, [], "slots", 7, true, {}]:
		_rejected("non-dictionary snapshot " + str(malformed), "invalid_enemies", NEEDLE_NOCK,
			_party(2), malformed, receipt, fresh)
	_rejected("string slot key", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{"1": _foe("x", 1, 5)}, receipt, fresh)
	_rejected("slot key 0", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{0: _foe("x", 0, 5), 1: _foe("y", 1, 5)}, receipt, fresh)
	_rejected("slot key 5", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 5), 5: _foe("y", 5, 5)}, receipt, fresh)
	_rejected("record in the wrong slot", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 2, 5)}, receipt, fresh)
	_rejected("duplicate identities", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("twin", 1, 5), 2: _foe("twin", 2, 5)}, receipt, fresh)
	_rejected("non-dictionary record", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: "spool_stalker"}, receipt, fresh)
	_rejected("record with more HP than max", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 12, 9)}, receipt, fresh)
	_rejected("string Block", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 5, 9, "0")}, receipt, fresh)
	_rejected("empty identity", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("", 1, 5)}, receipt, fresh)
	_rejected("statuses that are not a map", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 5, 9, 0, "tangled")}, receipt, fresh)
	_rejected("string Tangled count", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 5, 9, 0, {"tangled": "1"})}, receipt, fresh)
	_rejected("negative Tangled count", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 5, 9, 0, {"tangled": -1})}, receipt, fresh)
	_rejected("unknown status keyword", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 5, 9, 0, {"slow": 1})}, receipt, fresh)
	_rejected("non-canonical Dodge token", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 5, 9, 0, {"dodge_next_attack": 2})}, receipt, fresh)
	_rejected("float HP", "invalid_enemies", NEEDLE_NOCK, _party(2),
		{1: _foe("x", 1, 5.0)}, receipt, fresh)

	# A recipient the snapshot does not hold is never invented.
	_rejected("recipient in a vacant slot", "recipient_missing", NEEDLE_NOCK, _party(2),
		{2: _foe("spool_stalker", 2, 18)}, receipt, fresh)
	_rejected("recipient on a dead foe", "recipient_downed", NEEDLE_NOCK, _party(2),
		{1: _foe("spool_stalker", 1, 0, 18)}, receipt, fresh)
	var ceiling := {1: _foe("spool_stalker", 1, 18, 18, 0, {"tangled": CombatStatuses.MAX_INT})}
	_rejected("Tangled counter overflow", "status_overflow", NEEDLE_NOCK, _party(2), ceiling,
		receipt, fresh)
	# A whole roster is preflighted: a later invalid recipient refuses the earlier valid one too.
	var partial := {1: _foe("spool_stalker", 1, 18, 18, 0, {"tangled": 1}),
		2: _foe("moth_swarm", 2, 14, 20, 0, {"tangled": CombatStatuses.MAX_INT})}
	var partial_before: Dictionary = partial.duplicate(true)
	var partial_result: Dictionary = service.propose_snare_shot(UNSPOOL, _party(3), partial,
		_multi_receipt(UNSPOOL, 3, 2, [1, 2]), fresh)
	_check(partial_result.get("ok") == false
		and partial_result.get("reason") == "status_overflow",
		"a later overflowing recipient refuses the whole list")
	_check(partial == partial_before,
		"the earlier recipient was not partially tangled")
	_check(fresh == {"available": true, "consumed": false},
		"the overflow refusal did not spend the passive")


## AC3 / purity: refusals change no flag, enemy HP/Block/status, deck, energy, wallet or RNG, and a
## genuine proposal still follows them.
func _test_ac3_purity_and_retry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261102
	var deck := CombatDeck.new([NEEDLE_NOCK, WOOL_BOLAS, HOOD_KNIT, SNARE_NET, REEL_IN], rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		"purity: a real three-energy shared turn")
	var party := _party(3)
	party.gain_block(1, 4)
	var enemies := CombatEnemies.new([{"id": "spool_stalker", "max_hp": 18},
		{"id": "moth_swarm", "max_hp": 20}])
	_check(enemies.is_valid(), "purity: a real two-foe roster")
	enemies.gain_block(1, 3)
	var wallet := 42
	var before: Dictionary = _world(deck, party, enemies, rng, wallet)
	var slots: Dictionary = _four_slot_fixture()
	var receipt := _single_receipt(NEEDLE_NOCK, 3, 1, 1)
	var fresh := SnareCards.fresh_snare_shot_state()
	var spent := {"available": false, "consumed": true}

	var refusals: Array[Dictionary] = [
		{"card_id": SNARE_NET, "party": party, "slots": slots, "receipt":
			_single_receipt(SNARE_NET, 3, 2, 1), "state": fresh},
		{"card_id": NEEDLE_NOCK, "party": null, "slots": slots, "receipt": receipt,
			"state": fresh},
		{"card_id": NEEDLE_NOCK, "party": party, "slots": slots, "receipt": receipt,
			"state": spent},
		{"card_id": NEEDLE_NOCK, "party": party, "slots": {1: "bad"}, "receipt": receipt,
			"state": fresh},
		{"card_id": NEEDLE_NOCK, "party": party, "slots": slots, "receipt": [1, 2], "state": fresh},
	]
	for entry: Dictionary in refusals:
		var result: Dictionary = service.propose_snare_shot(entry["card_id"], entry["party"],
			entry["slots"], entry["receipt"], entry["state"])
		_check(result.get("ok") == false, "purity: the refusal really refuses")
		_check(_world(deck, party, enemies, rng, wallet) == before,
			"purity: deck, energy, hand, discard, party, enemies, wallet and RNG are unchanged")

	# A genuine proposal after those refusals still works and still writes nothing real.
	var proposed: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, party, slots, receipt, fresh)
	_check(proposed.get("ok") == true, "purity: the genuine proposal still succeeds")
	_check(_world(deck, party, enemies, rng, wallet) == before,
		"purity: the proposal itself pays nothing and writes no real state")
	_check(not enemies.get_enemy(1).has("statuses"),
		"purity: the authoritative enemy roster is never bound by the proposal")
	_check(deck.discard_pile.is_empty() and deck.hand.size() == 5,
		"purity: no card is discarded or drawn")


## AC3: the existing paid Snare Net / Snare Net+ transactions are unchanged.
func _test_snare_net_unchanged() -> void:
	for card_id: String in [SNARE_NET, SNARE_NET_PLUS]:
		var added: int = 1 if card_id == SNARE_NET else 2
		for seat: int in [2, 3]:
			var label: String = card_id + " from seat " + str(seat)
			var rng := RandomNumberGenerator.new()
			rng.seed = 439000 + seat + added
			var deck := CombatDeck.new([card_id, card_id, HOOD_KNIT, REEL_IN, SNARE_NET], rng)
			_check(deck.start_turn() and deck.hand.has(card_id),
				label + ": a real seeded turn holds the net")
			var party := _party(seat)
			var enemies := CombatEnemies.new([{"id": "spool_stalker", "max_hp": 18},
				{"id": "moth_swarm", "max_hp": 20}, {"id": "hoard_beetle", "max_hp": 24}])
			enemies.apply_damage(2, 20)
			_check(enemies.is_slain(2), label + ": the middle foe really is slain")
			var result: Dictionary = service.play_card(deck, party, enemies, card_id)
			_check(result.get("ok") == true and result.get("reason") == "applied",
				label + ": the paid net still resolves")
			_check(result.get("cost") == 2 and deck.energy == 1,
				label + ": exactly two energy are still charged")
			_check(result.get("tangled_added") == added,
				label + ": the printed Tangled count is unchanged")
			_check(result.get("target_positions") == [1, 3],
				label + ": only living foes are bound, in original slot order")
			_check(enemies.get_enemy(1).get("statuses") == {"tangled": added}
				and enemies.get_enemy(3).get("statuses") == {"tangled": added},
				label + ": every living foe gains the printed Tangled")
			_check(not enemies.get_enemy(2).has("statuses"),
				label + ": the slain slot gains nothing")
			_check(deck.discard_pile.count(card_id) == 1,
				label + ": exactly one held copy is discarded")
	# The passive proposal never touches the real snare roster either.
	var rng := RandomNumberGenerator.new()
	rng.seed = 439111
	var deck := CombatDeck.new([SNARE_NET, HOOD_KNIT, REEL_IN, NEEDLE_NOCK, WOOL_BOLAS], rng)
	deck.start_turn()
	var party := _party(2)
	var enemies := CombatEnemies.new([{"id": "spool_stalker", "max_hp": 18}])
	var before: Dictionary = _world(deck, party, enemies, rng, 7)
	var proposed: Dictionary = service.propose_snare_shot(NEEDLE_NOCK, party,
		{1: enemies.get_enemy(1)}, _single_receipt(NEEDLE_NOCK, 2, 1, 1),
		SnareCards.fresh_snare_shot_state())
	_check(proposed.get("ok") == true, "the passive proposes beside a real snare roster")
	_check(_world(deck, party, enemies, rng, 7) == before,
		"a real battle object is never mutated by the passive proposal")


# --- fixtures ----------------------------------------------------------------------------------

## A real three-hero party with a living 27 HP Yarn Ranger in the named seat.
func _party(ranger_position: int, ranger_hp: int = 27) -> CombatParty:
	var heroes: Array = [
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	]
	heroes[ranger_position - 1] = {"id": "yarn_ranger", "max_hp": 27}
	var party := CombatParty.new(heroes)
	_check(party.is_valid() and party.get_hero(ranger_position).get("id") == "yarn_ranger",
		"fixture builds a real party with the Yarn Ranger in seat " + str(ranger_position))
	if ranger_hp != 27:
		party.apply_damage(ranger_position, 27 - ranger_hp)
	return party


## A detached enemy record in the canonical actor shape. The value parameters stay untyped so the
## refusal cases can build deliberately malformed records (a float HP, a string Block, ...).
func _foe(enemy_id: Variant, slot: Variant, hp: Variant, max_hp: Variant = -1,
		block: Variant = 0, statuses: Variant = null) -> Dictionary:
	var limit: Variant = max_hp if max_hp > 0 else hp
	var record := {"id": enemy_id, "position": slot, "hp": hp, "block": block, "max_hp": limit}
	if statuses != null:
		record["statuses"] = statuses
	return record


## A four-slot snapshot: a full front foe, a pre-Tangled second foe, a bare third foe and a
## distinctive fourth foe behind the printed target line.
func _four_slot_fixture() -> Dictionary:
	return {
		1: _foe("button_guard", 1, 12, 12, 3),
		2: _foe("spool_stalker", 2, 18, 18, 0, {"tangled": 2}),
		3: _foe("moth_swarm", 3, 14, 20),
		4: _foe("hoard_beetle", 4, 24, 24, 5, {"exposed": 2}),
	}


func _single_receipt(card_id: String, seat: int, cost: int, target: int) -> Dictionary:
	return {"card_id": card_id, "owner_position": seat, "cost_paid": cost, "paid": true,
		"hit_confirmed": true, "target_position": target}


func _multi_receipt(card_id: String, seat: int, cost: int, hits: Array) -> Dictionary:
	return {"card_id": card_id, "owner_position": seat, "cost_paid": cost, "paid": true,
		"hit_confirmed": true, "hit_positions": hits.duplicate()}


## A detached copy of a receipt with one required field removed, for the malformed cases.
func _receipt_without(receipt: Dictionary, key: String) -> Dictionary:
	var copy: Dictionary = receipt.duplicate(true)
	copy.erase(key)
	return copy


## One refusal case: labelled reason, no proposal escapes, and every input stays untouched.
func _rejected(label: String, expected_reason: String, card_id: Variant, party: CombatParty,
		slots: Variant, receipt: Variant, state: Variant) -> void:
	var slots_before: Variant = slots.duplicate(true) if slots is Dictionary else slots
	var receipt_before: Variant = receipt.duplicate(true) if receipt is Dictionary else receipt
	var state_before: Variant = state.duplicate(true) if state is Dictionary else state
	var heroes_before: Array = party.get_heroes() if party != null else []
	var result: Dictionary = service.propose_snare_shot(card_id, party, slots, receipt, state)
	_check(result.get("ok") == false, label + ": refused")
	_check(result.get("reason") == expected_reason,
		label + ": refused with " + expected_reason + " (got " + str(result.get("reason")) + ")")
	_check(not result.has("enemies") and not result.has("passive_state"),
		label + ": no enemy map or flag escapes a refusal")
	if slots is Dictionary:
		_check(slots == slots_before, label + ": the caller snapshot is unchanged")
	if receipt is Dictionary:
		_check(receipt == receipt_before, label + ": the caller receipt is unchanged")
	if state is Dictionary:
		_check(state == state_before, label + ": the caller flag is unchanged")
	if party != null:
		_check(party.get_heroes() == heroes_before, label + ": the party is unchanged")


## Every ID in both Yarn Ranger catalogs, in a stable order.
func _yarn_card_ids() -> Array[String]:
	var ids: Array[String] = _starter.get_all_card_ids()
	ids.sort()
	var pool_ids: Array[String] = _pool.get_all_card_ids()
	pool_ids.sort()
	ids.append_array(pool_ids)
	return ids


## Every catalog ID the resolver derives as an attack.
func _attack_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_id: String in _yarn_card_ids():
		if service.is_attack_card(card_id):
			ids.append(card_id)
	return ids


## The catalog record for an ID from the catalog that owns it.
func _card_record(card_id: String) -> Dictionary:
	var record: Dictionary = _starter.get_definition(card_id)
	if record.is_empty():
		record = _pool.get_definition(card_id)
	return record


func _catalog_name(card_id: String) -> String:
	return "starter" if _starter.has_card(card_id) else "pool"


## The combat and run state a refusal must never disturb.
func _world(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		rng: RandomNumberGenerator, wallet: int) -> Dictionary:
	return {
		"energy": deck.energy,
		"turn": deck.turn_active,
		"hand": deck.hand.duplicate(),
		"draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"exhausted": deck.exhausted.duplicate(),
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"rng": rng.state,
		"wallet": wallet,
	}
