extends SceneTree
## Deterministic, headless contract for the V3-1 Warden Block-scaling toss cards.
##
## Rim Toss lives in the v3 starter catalog and Shield Toss in the v3 reward pool, so neither is
## assumed to be part of the mounted starter deck: every case builds a real seeded CombatDeck that
## genuinely holds the named ID. The party is the real authored starter party (Warden 40 HP) with
## Warden Block seeded through gain_block, and the enemies are the shipped run_enemies.json records.
## The resolver is scene-free; no app, reward or hand wiring is claimed here.

const HEROES_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const ELITES_PATH := "res://data/enemies/m04_elites.json"

const RIM := "warden_v3_rim_toss"
const RIM_PLUS := "warden_v3_rim_toss_plus"
const SHIELD := "warden_v3_shield_toss"
const SHIELD_PLUS := "warden_v3_shield_toss_plus"
const CARD_IDS := [RIM, RIM_PLUS, SHIELD, SHIELD_PLUS]

## The only authored difference between a base card and its "+": flat bonus on top of Warden Block.
const BONUS := {RIM: 0, RIM_PLUS: 2, SHIELD: 0, SHIELD_PLUS: 3}

## Literal, hand-computed damage for each card at each Warden Block and supplied status snapshot.
## Existing status rules floor once: Weak = 3/4, Exposed = 3/2, both = 9/8, rounded down.
const DAMAGE_MATRIX := {
	RIM: {
		0: {"none": 0, "weak": 0, "exposed": 0, "both": 0},
		6: {"none": 6, "weak": 4, "exposed": 9, "both": 6},
		9: {"none": 9, "weak": 6, "exposed": 13, "both": 10},
	},
	RIM_PLUS: {
		0: {"none": 2, "weak": 1, "exposed": 3, "both": 2},
		6: {"none": 8, "weak": 6, "exposed": 12, "both": 9},
		9: {"none": 11, "weak": 8, "exposed": 16, "both": 12},
	},
	SHIELD: {
		0: {"none": 0, "weak": 0, "exposed": 0, "both": 0},
		6: {"none": 6, "weak": 4, "exposed": 9, "both": 6},
		9: {"none": 9, "weak": 6, "exposed": 13, "both": 10},
	},
	SHIELD_PLUS: {
		0: {"none": 3, "weak": 2, "exposed": 4, "both": 3},
		6: {"none": 9, "weak": 6, "exposed": 13, "both": 10},
		9: {"none": 12, "weak": 9, "exposed": 18, "both": 13},
	},
}

const STATUS_CASES := {
	"none": [{}, {}],
	"weak": [{"weak": 1}, {}],
	"exposed": [{}, {"exposed": 1}],
	"both": [{"weak": 2, "exposed": 3}, {"exposed": 2, "weak": 1}],
}

const FILLERS := ["filler_stitch", "filler_thread", "filler_needle", "filler_ribbon", "filler_twig"]

var failures: Array[String] = []
var checks: int = 0
var service := CombatWardenV3ShieldTossCards.new()
var _catalog_cache: Array[Dictionary] = []


func _initialize() -> void:
	_test_authentic_catalog_and_api()
	_test_ac1_one_paid_hit()
	_test_ac1_owner_slot_two()
	_test_ac2_block_matrix()
	_test_ac2_block_before_hp()
	_test_ac2_zero_damage_and_lethal()
	_test_ac3_rejections()
	_test_ac3_retry_after_rejection()
	_test_once_only_payment()
	_test_seeded_replay()
	_test_thorns_retaliation()
	_test_enrage_progression()
	_test_needle_marshal_thorns_and_enrage()
	_test_traited_zero_damage_and_malformed_refusals()
	for failure in failures:
		printerr(failure)
	print("combat_warden_v3_shield_toss_cards_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


## The service must authenticate the exact two printings in their own catalogs and nothing else.
func _test_authentic_catalog_and_api() -> void:
	var starter := V3WardenStarterCards.new()
	var pool := V3WardenPoolCards.new()
	var expected := {
		RIM: {"source": starter, "effects": {"damage_equal_to_owner_block": true}},
		RIM_PLUS: {"source": starter,
			"effects": {"damage_equal_to_owner_block": true, "bonus_damage": 2}},
		SHIELD: {"source": pool, "effects": {"damage_equal_to_owner_block": true}},
		SHIELD_PLUS: {"source": pool,
			"effects": {"damage_equal_to_owner_block": true, "bonus_damage": 3}},
	}
	for card_id: String in CARD_IDS:
		var source: Variant = expected[card_id]["source"]
		var definition: Dictionary = source.get_definition(card_id)
		_check(definition.get("id") == card_id, card_id + ": authored catalog record exists")
		_check(definition.get("owner") == "warden", card_id + ": authored owner is Warden")
		_check(definition.get("cost") == 1, card_id + ": authored cost is 1")
		_check(definition.get("target_kind") == "enemy_single",
			card_id + ": authored target kind is one enemy")
		_check(definition.get("from_positions") == [1, 2], card_id + ": authored FROM is 1-2")
		_check(definition.get("to_positions") == [1, 2, 3], card_id + ": authored TO is 1-3")
		_check(definition.get("effects") == expected[card_id]["effects"],
			card_id + ": authored look effect is Block-scaled damage (plus its bonus)")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
	_check(not starter.has_card(SHIELD) and not pool.has_card(RIM),
		"the two printings are owned by separate catalogs")
	for unsupported in [
		"warden_v3_pot_helm_bonk", "warden_v3_shield_catch", "warden_v3_iron_challenge",
		"warden_v3_helmet_rattle", "warden_v3_guard_stitch", "warden_v3_iron_taunt",
		"warden_v3_rivet_pummel", "warden_v3_buckle_rebound", "warden_v3_shieldwall_chorus",
		"warden_v3_final_bastion", "warden_strike", "seamstress_prick", "tinker_pop_shot",
		"warden_v3_rim_toss_ultra", ""]:
		_check(not service.is_supported_card(unsupported),
			unsupported + ": not a Block-scaled toss for this service")
	_check(not service.is_supported_card(5) and not service.is_supported_card(null),
		"non-string IDs are never supported")


## AC1: a genuine held copy is charged once, discarded once and lands exactly one hit.
func _test_ac1_one_paid_hit() -> void:
	for card_id: String in CARD_IDS:
		var party := _party()
		var warden_position := 1
		_check(party.gain_block(warden_position, 6), card_id + ": Warden Block seeded through gain_block")
		_check(party.get_hero(warden_position)["block"] == 6,
			card_id + ": Warden really holds six Block before the play")
		var enemies := _enemies(["scissor_crab"])
		_check(enemies.gain_block(1, 4), card_id + ": target enemy really holds four Block")
		var deck := _deck(card_id)
		var before := _snapshot(deck, party, enemies)
		var held_before: int = deck.hand.count(card_id)
		var discarded_before: int = deck.discard_pile.count(card_id)
		var expect_damage: int = DAMAGE_MATRIX[card_id][6]["none"]
		var absorb: int = mini(4, expect_damage)
		var hp_loss: int = expect_damage - absorb

		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 1)
		_check(result.get("ok") == true, card_id + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			card_id + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == warden_position
			and result.get("owner_block") == 6
			and result.get("bonus_damage") == BONUS[card_id]
			and result.get("base_damage") == 6 + BONUS[card_id],
			card_id + ": receipt reports Warden slot, Block and authored bonus")
		_check(result.get("target_position") == 1, card_id + ": receipt keeps the original slot")
		_check(result.get("damage") == expect_damage,
			card_id + ": damage equals Warden Block plus the authored bonus")
		_check(result.get("block_absorbed") == absorb and result.get("hp_loss") == hp_loss,
			card_id + ": enemy Block absorbs before HP")

		var expected := _expected_success(before, card_id, 1, absorb, hp_loss)
		_check(_snapshot(deck, party, enemies) == expected,
			card_id + ": exact hand/piles/energy/turn/enemies and untouched injected RNG")
		_check(deck.hand.count(card_id) == held_before - 1
			and deck.discard_pile.count(card_id) == discarded_before + 1
			and deck.hand.size() == 4 and deck.discard_pile.size() == 1,
			card_id + ": precisely one held copy moved to the discard pile")
		_check(party.get_heroes() == before["heroes"] and party.get_hero(1)["block"] == 6,
			card_id + ": the Warden's own Block is never spent")
		_check(deck.energy == 2, card_id + ": exactly one energy was charged")
		_check(_snapshot(deck, party, enemies)["rng_state"] == before["rng_state"],
			card_id + ": no run-RNG draw during resolution")
		# The returned receipt is detached from the live roster.
		result["damage"] = 999
		_check(enemies.get_enemy(1)["hp"] == 26 - hp_loss,
			card_id + ": a mutated receipt cannot change the enemy")


## AC1: the same authentic play is legal with the Warden actually moved to the middle slot.
func _test_ac1_owner_slot_two() -> void:
	for card_id: String in CARD_IDS:
		var party := _moved_party(2)
		_check(party.gain_block(2, 9), card_id + ": moved Warden Block seeded")
		var enemies := _enemies(["fray_scavenger", "button_guard", "thimble_beetle"])
		var deck := _deck(card_id)
		var before := _snapshot(deck, party, enemies)
		var expect_damage: int = DAMAGE_MATRIX[card_id][9]["none"]
		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 3)
		_check(result.get("ok") == true, card_id + ": legal from the middle slot")
		_check(result.get("owner_position") == 2 and result.get("owner_block") == 9,
			card_id + ": resolves against the Warden's current slot and Block")
		_check(result.get("damage") == expect_damage
			and result.get("block_absorbed") == 0 and result.get("hp_loss") == expect_damage,
			card_id + ": Block-scaled damage lands on the rear target")
		var expected := _expected_success(before, card_id, 3, 0, expect_damage)
		_check(_snapshot(deck, party, enemies) == expected,
			card_id + ": middle-slot play charges, discards and hits exactly once")
		_check(party.get_hero(2)["block"] == 9, card_id + ": middle Warden keeps all nine Block")


## AC2: fixed Block/status matrix for all four printings, enemy Block absorbing first.
func _test_ac2_block_matrix() -> void:
	for card_id: String in CARD_IDS:
		for block_value: int in [0, 6, 9]:
			for status_name: String in STATUS_CASES:
				var label := "%s B=%d %s" % [card_id, block_value, status_name]
				var party := _party()
				if block_value > 0:
					_check(party.gain_block(1, block_value), label + ": Block seeded")
				_check(party.get_hero(1)["block"] == block_value,
					label + ": Warden really holds the seeded Block")
				var enemies := _enemies(["scissor_crab"])
				_check(enemies.gain_block(1, 4), label + ": enemy really holds four Block")
				var deck := _deck(card_id)
				var attacker_statuses: Dictionary = STATUS_CASES[status_name][0].duplicate(true)
				var defender_statuses: Dictionary = STATUS_CASES[status_name][1].duplicate(true)
				var attacker_before := attacker_statuses.duplicate(true)
				var defender_before := defender_statuses.duplicate(true)
				var deck_before := _snapshot(deck, party, enemies)
				var expect_damage: int = DAMAGE_MATRIX[card_id][block_value][status_name]
				var absorb: int = mini(4, expect_damage)
				var hp_loss: int = expect_damage - absorb

				var result: Dictionary = service.play_card(deck, party, enemies, card_id, 1,
					attacker_statuses, defender_statuses)
				_check(result.get("ok") == true, label + ": valid status snapshot is accepted")
				_check(result.get("damage") == expect_damage,
					label + ": exact floored damage " + str(expect_damage))
				_check(result.get("block_absorbed") == absorb
					and result.get("hp_loss") == hp_loss, label + ": exact Block then HP split")
				_check(enemies.get_enemy(1)["hp"] == 26 - hp_loss
					and enemies.get_enemy(1)["block"] == 4 - absorb,
					label + ": authoritative enemy block/HP after the hit")
				_check(party.get_hero(1)["block"] == block_value,
					label + ": Block-scaled damage never spends Warden Block")
				_check(attacker_statuses == attacker_before and defender_statuses == defender_before,
					label + ": supplied status snapshots are never mutated")
				_check(deck.energy == 2 and deck.discard_pile.count(card_id) == 1,
					label + ": one energy and one discard")
				var expected := _expected_success(deck_before, card_id, 1, absorb, hp_loss)
				_check(_snapshot(deck, party, enemies) == expected,
					label + ": full state and RNG match the single transaction")

	# The hit reads the Warden's OWN Block, never a well-guarded ally's.
	for card_id: String in CARD_IDS:
		var party := _party()
		_check(party.gain_block(2, 12) and party.gain_block(3, 12),
			card_id + ": ally-only Block fixture seeded")
		var enemies := _enemies(["scissor_crab"])
		var deck := _deck(card_id)
		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 1)
		_check(result.get("ok") == true and result.get("damage") == BONUS[card_id]
			and result.get("hp_loss") == BONUS[card_id],
			card_id + ": twelve Block on each ally contributes no damage")
		_check(party.get_hero(2)["block"] == 12 and party.get_hero(3)["block"] == 12,
			card_id + ": ally Block is untouched")


## AC2: enemy Block must be consumed before any HP loss, even when it covers the whole hit.
func _test_ac2_block_before_hp() -> void:
	var party := _party()
	_check(party.gain_block(1, 6), "Block-before-HP fixture has Warden Block")
	var enemies := _enemies(["scissor_crab"])
	_check(enemies.gain_block(1, 10), "Block-before-HP fixture has ten enemy Block")
	var deck := _deck(RIM)
	var result: Dictionary = service.play_card(deck, party, enemies, RIM, 1)
	_check(result.get("ok") == true and result.get("damage") == 6
		and result.get("block_absorbed") == 6 and result.get("hp_loss") == 0,
		"six damage is fully absorbed by ten enemy Block")
	_check(enemies.get_enemy(1)["hp"] == 26 and enemies.get_enemy(1)["block"] == 4,
		"enemy HP is untouched while four Block remain")

	party = _party()
	_check(party.gain_block(1, 4), "partial-absorb fixture has four Warden Block")
	enemies = _enemies(["scissor_crab"])
	_check(enemies.gain_block(1, 2), "partial-absorb fixture has two enemy Block")
	deck = _deck(SHIELD_PLUS)
	result = service.play_card(deck, party, enemies, SHIELD_PLUS, 1)
	_check(result.get("damage") == 7 and result.get("block_absorbed") == 2
		and result.get("hp_loss") == 5,
		"Block-scaled seven damage spends two enemy Block then five HP")


## AC2 edge cases: a genuine zero-damage hit and a lethal hit are both real plays.
func _test_ac2_zero_damage_and_lethal() -> void:
	var party := _party()
	var enemies := _enemies(["scissor_crab"])
	_check(enemies.gain_block(1, 3), "zero-damage fixture has enemy Block")
	var deck := _deck(RIM)
	var result: Dictionary = service.play_card(deck, party, enemies, RIM, 1, {"weak": 3}, {})
	_check(result.get("ok") == true and result.get("damage") == 0
		and result.get("block_absorbed") == 0 and result.get("hp_loss") == 0,
		"zero Block with Weak is a real zero-damage hit")
	_check(enemies.get_enemy(1)["block"] == 3 and deck.energy == 2
		and deck.discard_pile.count(RIM) == 1,
		"a zero-damage hit still charges, discards and leaves enemy Block alone")

	party = _party()
	_check(party.gain_block(1, 9), "lethal fixture has nine Warden Block")
	enemies = _enemies(["fray_scavenger"])
	deck = _deck(SHIELD_PLUS)
	result = service.play_card(deck, party, enemies, SHIELD_PLUS, 1, {}, {"exposed": 1})
	_check(result.get("damage") == 18 and result.get("block_absorbed") == 0
		and result.get("hp_loss") == 14,
		"Exposed twelve Block damage is lethal and reports the fourteen HP actually lost")
	_check(enemies.is_slain(1) and enemies.get_enemy(1)["hp"] == 0,
		"the lethal hit persists on the authoritative roster")


## AC3: every invalid request fails closed and leaves the whole transaction untouched.
func _test_ac3_rejections() -> void:
	var party := _party()
	var enemies := _enemies(["scissor_crab", "button_guard", "spool_stalker"])

	var inactive := CombatDeck.new([RIM, RIM, RIM, FILLERS[0], FILLERS[1], FILLERS[2]], _rng(414))
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_rejected(inactive, party, enemies, RIM, 1, {}, {}, "inactive turn")

	var deck := _deck(SHIELD_PLUS)
	_check(deck.hand.has(SHIELD_PLUS) and not deck.hand.has(RIM),
		"absent-card fixture holds the other genuine ID only")
	_rejected(deck, party, enemies, RIM, 1, {}, {}, "card absent from hand")
	_rejected(deck, party, enemies, "missing_warden_v3_toss", 1, {}, {}, "unknown card ID")
	_rejected(deck, party, enemies, "", 1, {}, {}, "empty card ID")

	for wrong_card in ["warden_v3_pot_helm_bonk", "warden_v3_guard_stitch",
			"warden_strike", "seamstress_prick", "tinker_pop_shot"]:
		var wrong_deck := _deck(wrong_card)
		_rejected(wrong_deck, party, enemies, wrong_card, 1, {}, {},
			"non-toss card in hand " + wrong_card)

	var short := _deck(RIM)
	_check(short.try_spend_energy(3) and short.energy == 0 and short.hand.has(RIM),
		"energy-short fixture is genuinely broke and still holds Rim Toss")
	_rejected(short, party, enemies, RIM, 1, {}, {}, "energy short")

	var torn := _party()
	_check(torn.apply_damage(1, 40) and torn.is_downed(1),
		"torn-owner fixture has a genuinely downed Warden")
	_rejected(_deck(RIM), torn, enemies, RIM, 1, {}, {}, "torn (downed) owner")

	_rejected(_deck(RIM), _moved_party(3), enemies, RIM, 1, {}, {},
		"Warden in the rear slot 3")

	for wrong_target in [0, -1, 4, 99]:
		_rejected(_deck(RIM), _party(), enemies, RIM, wrong_target, {}, {},
			"target outside 1-3: " + str(wrong_target))

	var two := _enemies(["scissor_crab", "button_guard"])
	_check(two.get_enemies().size() == 2, "two-enemy fixture really has two slots")
	_rejected(_deck(RIM), _party(), two, RIM, 3, {}, {},
		"target missing from a two-enemy roster")

	var wounded := _enemies(["scissor_crab", "button_guard"])
	_check(wounded.apply_damage(2, 99) and wounded.is_slain(2),
		"slain-target fixture really has a slain slot 2")
	_rejected(_deck(RIM), _party(), wounded, RIM, 2, {}, {}, "target already slain")

	var cleared := _enemies(["scissor_crab"])
	_check(cleared.apply_damage(1, 99) and cleared.is_victorious(),
		"cleared fixture is genuinely victorious")
	_rejected(_deck(RIM), _party(), cleared, RIM, 1, {}, {},
		"no living enemy remains")

	for bad_attacker in [{"weak": -1}, {"weak": "2"}, {"weak": 1.5}, {1: 2}, {"poison": 1},
			{"exposed": true}]:
		_rejected(_deck(RIM), _party(), enemies, RIM, 1, bad_attacker, {},
			"malformed attacker snapshot " + str(bad_attacker))
	for bad_defender in [{"exposed": -2}, {"exposed": "1"}, {"tangled": 1.5}, {"bleed": null},
			{[1]: 2}]:
		_rejected(_deck(RIM), _party(), enemies, RIM, 1, {}, bad_defender,
			"malformed defender snapshot " + str(bad_defender))

	_rejected(null, _party(), enemies, RIM, 1, {}, {}, "null deck")
	_rejected(_deck(RIM), null, enemies, RIM, 1, {}, {}, "null party")
	_rejected(_deck(RIM), _party(), null, RIM, 1, {}, {}, "null enemies")
	_rejected(_deck(RIM), CombatParty.new([]), enemies, RIM, 1, {}, {},
		"invalid party roster")
	_rejected(_deck(RIM), _party(), CombatEnemies.new([]), RIM, 1, {}, {},
		"invalid enemy roster")


## AC3: a rejected attempt never poisons the next authentic one on the same objects.
func _test_ac3_retry_after_rejection() -> void:
	var party := _party()
	_check(party.gain_block(1, 6), "retry fixture has six Warden Block")
	var enemies := _enemies(["scissor_crab"])
	_check(enemies.gain_block(1, 4), "retry fixture has four enemy Block")
	var deck := _deck(RIM)

	_rejected(deck, party, enemies, RIM, 1, {"weak": -1}, {}, "retry: malformed snapshot first")
	_rejected(deck, party, enemies, RIM, 0, {}, {}, "retry: wrong target second")

	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = service.play_card(deck, party, enemies, RIM, 1, {"weak": 1}, {})
	_check(result.get("ok") == true, "retry: the authentic play then succeeds")
	_check(result.get("damage") == 4 and result.get("block_absorbed") == 4
		and result.get("hp_loss") == 0,
		"retry: the weak-affected four damage matches the untouched state")
	var expected := _expected_success(before, RIM, 1, 4, 0)
	_check(_snapshot(deck, party, enemies) == expected,
		"retry: exactly one charge, one discard, one hit and an untouched RNG")


## Each authentic play pays and discards once; leftover copies cannot be played without energy.
func _test_once_only_payment() -> void:
	var party := _party()
	_check(party.gain_block(1, 6), "repeat fixture has six Warden Block")
	var enemies := _enemies(["thimble_beetle"])
	var deck := CombatDeck.new(
		[SHIELD_PLUS, SHIELD_PLUS, SHIELD_PLUS, SHIELD_PLUS, SHIELD_PLUS, FILLERS[0]],
		_rng(2710))
	_check(deck.start_turn() and deck.hand.count(SHIELD_PLUS) >= 4,
		"repeat fixture draws a hand holding several genuine copies")
	var initial_rng: int = deck._rng.state
	for play_index in range(3):
		var before := _snapshot(deck, party, enemies)
		var result: Dictionary = service.play_card(deck, party, enemies, SHIELD_PLUS, 1)
		_check(result.get("ok") == true and result.get("damage") == 9,
			"repeat play %d lands the same nine damage" % (play_index + 1))
		_check(deck.energy == 2 - play_index and deck.hand.size() == 4 - play_index
			and deck.discard_pile.size() == play_index + 1,
			"repeat play %d charges one energy and discards one copy" % (play_index + 1))
		_check(_snapshot(deck, party, enemies)["rng_state"] == initial_rng,
			"repeat play %d draws no run RNG" % (play_index + 1))
		_check(party.get_hero(1)["block"] == 6,
			"repeat play %d never spends Warden Block" % (play_index + 1))
		_check(before["heroes"] == party.get_heroes(),
			"repeat play %d leaves every hero intact" % (play_index + 1))
	_check(deck.hand.count(SHIELD_PLUS) >= 1 and deck.energy == 0,
		"repeat fixture still holds a copy but has no energy left")
	var before_empty := _snapshot(deck, party, enemies)
	var refused: Dictionary = service.play_card(deck, party, enemies, SHIELD_PLUS, 1)
	_check(refused.get("ok") == false, "a held copy cannot be played at zero energy")
	_check(_snapshot(deck, party, enemies) == before_empty,
		"the energy refusal changes no pile, energy, hero, enemy or RNG")

	# A deck holding exactly one copy proves the held-copy gate, not merely the energy gate.
	var single_party := _party()
	var single_enemies := _enemies(["zipper_snake"])
	var single := CombatDeck.new(
		[RIM, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], _rng(5150))
	_check(single.start_turn() and single.hand.count(RIM) == 1
		and single.energy == 3, "single-copy fixture draws its one genuine copy")
	var once: Dictionary = service.play_card(single, single_party, single_enemies, RIM, 1)
	_check(once.get("ok") == true and once.get("damage") == 0,
		"single copy plays once for zero damage without Warden Block")
	_check(not single.hand.has(RIM), "the played copy leaves the hand")
	var single_before := _snapshot(single, single_party, single_enemies)
	var replay: Dictionary = service.play_card(single, single_party, single_enemies, RIM, 1)
	_check(replay.get("ok") == false and replay.get("damage") == 0,
		"a second play of the same ID fails once the copy is discarded")
	_check(_snapshot(single, single_party, single_enemies) == single_before,
		"the double-play refusal leaves the deck, roster and RNG untouched")


## The same seed and the same request sequence produce identical outcomes.
func _test_seeded_replay() -> void:
	var first := _replay_run(90210)
	var second := _replay_run(90210)
	_check(first == second, "seeded replay produces identical final state")
	_check(first["rng_state"] == second["rng_state"],
		"seeded replay consumes no run RNG at any step")
	_check(first["results"] == second["results"], "seeded replay reports the same receipts")
	_check(first["results"].size() == 5, "seeded replay covers five requests")
	_check(first["results"][0]["damage"] == 4 and first["results"][1]["damage"] == 6
		and first["results"][2]["damage"] == 12,
		"seeded replay lands the expected weak, plain and exposed-plus hits")
	_check(first["results"][3]["ok"] == false and first["results"][4]["ok"] == false,
		"seeded replay keeps the spent-energy and absent-copy refusals")


func _replay_run(seed_value: int) -> Dictionary:
	var party := _party()
	_check(party.gain_block(1, 6), "replay fixture has six Warden Block")
	var enemies := _enemies(["scissor_crab", "button_guard"])
	var deck := CombatDeck.new([RIM, RIM, RIM_PLUS, SHIELD, SHIELD_PLUS], _rng(seed_value))
	_check(deck.start_turn() and deck.hand.count(RIM) == 2 and deck.energy == 3,
		"replay fixture draws both Rim Toss copies and all upgrades")
	var results: Array = []
	var requests := [
		[RIM, 1, {"weak": 1}, {}], [RIM, 2, {}, {}], [RIM_PLUS, 1, {}, {"exposed": 1}],
		[SHIELD, 1, {}, {}], [RIM, 1, {}, {}],
	]
	for request in requests:
		results.append(service.play_card(deck, party, enemies, request[0], request[1],
			request[2], request[3]))
	var snapshot := _snapshot(deck, party, enemies)
	snapshot["results"] = results
	return snapshot


## AC1: A confirmed positive hit triggers exactly one Thorns 3 retaliation against the Warden.
func _test_thorns_retaliation() -> void:
	for card_id: String in CARD_IDS:
		# 1. Standard hit from seat 1 with Warden Block 6:
		var party := _party()
		_check(party.gain_block(1, 6), card_id + ": Thorns fixture seeded with 6 Warden Block")
		var enemies := _enemies(["pincushion_hedgehog"])
		var deck := _deck(card_id)
		var before := _snapshot(deck, party, enemies)
		var expect_damage: int = DAMAGE_MATRIX[card_id][6]["none"]
		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 1)
		_check(result.get("ok") == true, card_id + ": positive hit lands on Hedgehog")
		_check(result.get("damage") == expect_damage and result.get("block_absorbed") == 0
			and result.get("hp_loss") == expect_damage, card_id + ": Hedgehog takes full unblocked damage")
		_check(enemies.get_enemy(1)["hp"] == 25 - expect_damage, card_id + ": Hedgehog HP updated")
		# Warden took Thorns 3 retaliation, absorbed by Warden Block: 6 -> 3 Block, 40 HP.
		_check(party.get_hero(1)["block"] == 3 and party.get_hero(1)["hp"] == 40,
			card_id + ": Warden Block absorbed Thorns 3 before HP")
		_check(party.get_hero(2) == before["heroes"][1] and party.get_hero(3) == before["heroes"][2],
			card_id + ": party allies untouched by Thorns retaliation")
		_check(deck.energy == 2 and deck.discard_pile.count(card_id) == 1 and deck.hand.size() == 4,
			card_id + ": exactly one energy charged and one card discarded")
		var expected := _expected_traited_success(before, card_id, 1, 0, expect_damage, 1, 3, 0)
		_check(_snapshot(deck, party, enemies) == expected,
			card_id + ": full state and RNG match one paid transaction with Thorns")

	# 2. Warden in seat 2 (middle position):
	for card_id: String in [RIM, SHIELD_PLUS]:
		var party := _moved_party(2)
		_check(party.gain_block(2, 6), card_id + ": moved Warden Block 6 seeded in seat 2")
		var enemies := _enemies(["pincushion_hedgehog"])
		var deck := _deck(card_id)
		var before := _snapshot(deck, party, enemies)
		var expect_damage: int = DAMAGE_MATRIX[card_id][6]["none"]
		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 1)
		_check(result.get("ok") == true and result.get("owner_position") == 2,
			card_id + ": legal throw from middle seat 2")
		_check(party.get_hero(2)["block"] == 3 and party.get_hero(2)["hp"] == 40,
			card_id + ": Warden in seat 2 absorbed Thorns 3 retaliation")
		_check(party.get_hero(1) == before["heroes"][0] and party.get_hero(3) == before["heroes"][2],
			card_id + ": heroes in seat 1 and 3 untouched")
		var expected := _expected_traited_success(before, card_id, 1, 0, expect_damage, 2, 3, 0)
		_check(_snapshot(deck, party, enemies) == expected,
			card_id + ": middle seat full snapshot matches")

	# 3. Defender Block fully absorbs the hit, but Thorns 3 STILL retaliates:
	var blocked_party := _party()
	_check(blocked_party.gain_block(1, 6), "fully blocked hit: Warden Block 6 seeded")
	var blocked_enemies := _enemies(["pincushion_hedgehog"])
	_check(blocked_enemies.gain_block(1, 10), "fully blocked hit: Hedgehog holds 10 Block")
	var blocked_deck := _deck(RIM)
	var blocked_before := _snapshot(blocked_deck, blocked_party, blocked_enemies)
	var blocked_res: Dictionary = service.play_card(blocked_deck, blocked_party, blocked_enemies, RIM, 1)
	_check(blocked_res.get("ok") == true and blocked_res.get("damage") == 6
		and blocked_res.get("block_absorbed") == 6 and blocked_res.get("hp_loss") == 0,
		"fully blocked hit: 6 damage fully absorbed by enemy Block")
	_check(blocked_enemies.get_enemy(1)["hp"] == 25 and blocked_enemies.get_enemy(1)["block"] == 4,
		"fully blocked hit: Hedgehog HP 25 untouched, Block 10 -> 4")
	_check(blocked_party.get_hero(1)["block"] == 3 and blocked_party.get_hero(1)["hp"] == 40,
		"fully blocked hit: Thorns 3 STILL retaliates against Warden Block (6 -> 3)")
	var blocked_exp := _expected_traited_success(blocked_before, RIM, 1, 6, 0, 1, 3, 0)
	_check(_snapshot(blocked_deck, blocked_party, blocked_enemies) == blocked_exp,
		"fully blocked hit: full snapshot matches")

	# 4. Warden Block partial absorption and zero Block:
	var partial_party := _party()
	_check(partial_party.gain_block(1, 1), "partial: Warden has 1 Block")
	var partial_enemies := _enemies(["pincushion_hedgehog"])
	var partial_deck := _deck(RIM_PLUS)
	var partial_res: Dictionary = service.play_card(partial_deck, partial_party, partial_enemies, RIM_PLUS, 1)
	_check(partial_res.get("ok") == true and partial_res.get("damage") == 3,
		"partial: RIM_PLUS deals 1 Block + 2 bonus = 3 damage")
	_check(partial_party.get_hero(1)["block"] == 0 and partial_party.get_hero(1)["hp"] == 38,
		"partial: Warden 1 Block absorbed, 2 HP lost from Thorns 3 retaliation")

	var zero_block_party := _party()
	var zero_block_enemies := _enemies(["pincushion_hedgehog"])
	var zero_block_deck := _deck(SHIELD_PLUS)
	var zero_res: Dictionary = service.play_card(zero_block_deck, zero_block_party, zero_block_enemies, SHIELD_PLUS, 1)
	_check(zero_res.get("ok") == true and zero_res.get("damage") == 3,
		"zero block: SHIELD_PLUS deals 3 bonus damage")
	_check(zero_block_party.get_hero(1)["block"] == 0 and zero_block_party.get_hero(1)["hp"] == 37,
		"zero block: Warden takes 3 full HP damage from Thorns 3 retaliation")

	# 5. Status modifiers Weak and Exposed:
	var weak_party := _party()
	_check(weak_party.gain_block(1, 6), "weak: Warden has 6 Block")
	var weak_enemies := _enemies(["pincushion_hedgehog"])
	var weak_deck := _deck(RIM)
	var weak_res: Dictionary = service.play_card(weak_deck, weak_party, weak_enemies, RIM, 1, {"weak": 1}, {})
	_check(weak_res.get("ok") == true and weak_res.get("damage") == 4,
		"weak: 6 Block floored at 4 damage")
	_check(weak_party.get_hero(1)["block"] == 3 and weak_party.get_hero(1)["hp"] == 40,
		"weak: Thorns 3 still retaliates against Warden Block")

	var exp_party := _party()
	_check(exp_party.gain_block(1, 6), "exposed: Warden has 6 Block")
	var exp_enemies := _enemies(["pincushion_hedgehog"])
	var exp_deck := _deck(RIM)
	var exp_res: Dictionary = service.play_card(exp_deck, exp_party, exp_enemies, RIM, 1, {}, {"exposed": 1})
	_check(exp_res.get("ok") == true and exp_res.get("damage") == 9,
		"exposed: 6 Block floored at 9 damage")
	_check(exp_party.get_hero(1)["block"] == 3 and exp_party.get_hero(1)["hp"] == 40,
		"exposed: Thorns 3 still retaliates against Warden Block")

	# 6. Lethal hit on Thorns enemy:
	var lethal_party := _party()
	_check(lethal_party.gain_block(1, 6), "lethal: Warden has 6 Block")
	var lethal_enemies := _enemies(["pincushion_hedgehog"])
	_check(lethal_enemies.apply_damage(1, 20) and lethal_enemies.get_enemy(1)["hp"] == 5,
		"lethal: Hedgehog damaged to 5 HP")
	var lethal_deck := _deck(RIM)
	var lethal_res: Dictionary = service.play_card(lethal_deck, lethal_party, lethal_enemies, RIM, 1)
	_check(lethal_res.get("ok") == true and lethal_res.get("damage") == 6
		and lethal_res.get("hp_loss") == 5, "lethal: 6 damage lands, 5 HP lost")
	_check(lethal_enemies.is_slain(1) and lethal_enemies.get_enemy(1)["hp"] == 0,
		"lethal: Hedgehog is slain")
	_check(lethal_party.get_hero(1)["block"] == 3 and lethal_party.get_hero(1)["hp"] == 40,
		"lethal: Thorns 3 STILL retaliates on lethal strike against Hedgehog")

	# 7. Lethal Thorns retaliation on Warden (downed owner):
	var downed_party := _party()
	_check(downed_party.apply_damage(1, 38) and downed_party.get_hero(1)["hp"] == 2,
		"downed Warden: Warden down to 2 HP, 0 Block")
	var downed_enemies := _enemies(["pincushion_hedgehog"])
	var downed_deck := _deck(RIM_PLUS)
	var downed_res: Dictionary = service.play_card(downed_deck, downed_party, downed_enemies, RIM_PLUS, 1)
	_check(downed_res.get("ok") == true and downed_res.get("damage") == 2,
		"downed Warden: attack lands for 2 damage")
	_check(downed_enemies.get_enemy(1)["hp"] == 23, "downed Warden: Hedgehog took damage")
	_check(downed_party.get_hero(1)["hp"] == 0 and downed_party.is_downed(1),
		"downed Warden: Thorns 3 downs the Warden")
	_check(downed_deck.energy == 2 and downed_deck.discard_pile.count(RIM_PLUS) == 1,
		"downed Warden: transaction completed and not rolled back")


## AC2: Confirmed hits grant +1 Enrage stack up to 3; each stack adds +2 attack in enemy phase.
func _test_enrage_progression() -> void:
	# 1. Four sequential hits on Spoolback Hound to verify 1, 2, 3 stacks and cap:
	var party := _party()
	_check(party.gain_block(1, 6), "enrage chain: Warden has 6 Block")
	var enemies := _enemies(["spoolback_hound"])
	var rng := _rng(8821)
	var deck := CombatDeck.new([SHIELD, SHIELD, SHIELD, SHIELD, SHIELD, FILLERS[0]], rng)
	_check(deck.start_turn() and deck.hand.size() == 5, "enrage chain: deck started")
	deck.combat_state.energy = 10
	deck.energy = 10

	var expected_stacks := [1, 2, 3, 3]
	var expected_bonuses := [2, 4, 6, 6]
	for step in range(4):
		var before := _snapshot(deck, party, enemies)
		var res: Dictionary = service.play_card(deck, party, enemies, SHIELD, 1)
		_check(res.get("ok") == true and res.get("damage") == 6,
			"enrage chain hit %d: lands 6 damage" % (step + 1))
		var want_stacks: int = expected_stacks[step]
		var want_bonus: int = expected_bonuses[step]
		var hound: Dictionary = enemies.get_enemy(1)
		_check(hound.get("enrage_stacks") == want_stacks,
			"enrage chain hit %d: Hound has %d enrage stacks" % [step + 1, want_stacks])
		_check(CombatEnemyPhase._enrage_attack_bonus(enemies, 1) == want_bonus,
			"enrage chain hit %d: enemy phase reports +%d attack bonus" % [step + 1, want_bonus])
		# Hound has NO Thorns, so Warden Block 6 and HP 40 remain untouched:
		_check(party.get_hero(1)["block"] == 6 and party.get_hero(1)["hp"] == 40,
			"enrage chain hit %d: Hound has no Thorns, Warden Block untouched" % (step + 1))
		var exp := _expected_traited_success(before, SHIELD, 1, 0, 6, 1, 0, 0, want_stacks)
		_check(_snapshot(deck, party, enemies) == exp,
			"enrage chain hit %d: full state matches" % (step + 1))

	# 2. Fully blocked hit on Hound still grants 1 Enrage stack:
	var blocked_party := _party()
	_check(blocked_party.gain_block(1, 6), "enrage blocked: Warden has 6 Block")
	var blocked_enemies := _enemies(["spoolback_hound"])
	_check(blocked_enemies.gain_block(1, 10), "enrage blocked: Hound has 10 Block")
	var blocked_deck := _deck(RIM)
	var blocked_res: Dictionary = service.play_card(blocked_deck, blocked_party, blocked_enemies, RIM, 1)
	_check(blocked_res.get("ok") == true and blocked_res.get("block_absorbed") == 6
		and blocked_res.get("hp_loss") == 0, "enrage blocked: hit fully absorbed by enemy Block")
	_check(blocked_enemies.get_enemy(1)["enrage_stacks"] == 1,
		"enrage blocked: fully blocked hit still awards 1 Enrage stack")
	_check(CombatEnemyPhase._enrage_attack_bonus(blocked_enemies, 1) == 2,
		"enrage blocked: attack bonus is +2")

	# 3. Middle Warden position (seat 2):
	var mid_party := _moved_party(2)
	_check(mid_party.gain_block(2, 6), "enrage mid: seat 2 Warden has 6 Block")
	var mid_enemies := _enemies(["spoolback_hound"])
	var mid_deck := _deck(RIM)
	var mid_res: Dictionary = service.play_card(mid_deck, mid_party, mid_enemies, RIM, 1)
	_check(mid_res.get("ok") == true and mid_res.get("owner_position") == 2,
		"enrage mid: legal throw from seat 2")
	_check(mid_enemies.get_enemy(1)["enrage_stacks"] == 1,
		"enrage mid: Hound gains 1 stack from seat 2 Warden")


## AC1/AC2: Needle Marshal combines Thorns 3 and Enrage on every confirmed positive hit.
func _test_needle_marshal_thorns_and_enrage() -> void:
	# 1. Single hit: damage, Thorns retaliation, Enrage stack, escort untouched:
	var party := _party()
	_check(party.gain_block(1, 6), "marshal: Warden has 6 Block")
	var enemies := _enemies(["needle_marshal", "button_guard"])
	var deck := _deck(RIM_PLUS)
	var before := _snapshot(deck, party, enemies)
	var res: Dictionary = service.play_card(deck, party, enemies, RIM_PLUS, 1)
	_check(res.get("ok") == true and res.get("damage") == 8
		and res.get("block_absorbed") == 0 and res.get("hp_loss") == 8,
		"marshal hit 1: deals 8 damage (6 Block + 2 bonus)")
	_check(enemies.get_enemy(1)["hp"] == 20, "marshal hit 1: HP 28 -> 20")
	_check(enemies.get_enemy(1)["enrage_stacks"] == 1, "marshal hit 1: gains 1 Enrage stack")
	_check(CombatEnemyPhase._enrage_attack_bonus(enemies, 1) == 2, "marshal hit 1: bonus is +2")
	_check(party.get_hero(1)["block"] == 3 and party.get_hero(1)["hp"] == 40,
		"marshal hit 1: Warden took Thorns 3 retaliation (Block 6 -> 3)")
	_check(enemies.get_enemy(2) == before["enemies"][1], "marshal hit 1: escort button_guard untouched")
	_check(deck.energy == 2 and deck.discard_pile.count(RIM_PLUS) == 1,
		"marshal hit 1: paid 1 energy and 1 discard")
	var exp := _expected_traited_success(before, RIM_PLUS, 1, 0, 8, 1, 3, 0, 1)
	_check(_snapshot(deck, party, enemies) == exp, "marshal hit 1: full snapshot matches")

	# 2. Blocked hit: Marshal Block absorbs hit, both Thorns 3 and Enrage trigger:
	var blocked_party := _party()
	_check(blocked_party.gain_block(1, 6), "marshal blocked: Warden has 6 Block")
	var blocked_enemies := _enemies(["needle_marshal"])
	_check(blocked_enemies.gain_block(1, 10), "marshal blocked: Marshal has 10 Block")
	var blocked_deck := _deck(RIM)
	var blocked_res: Dictionary = service.play_card(blocked_deck, blocked_party, blocked_enemies, RIM, 1)
	_check(blocked_res.get("ok") == true and blocked_res.get("damage") == 6
		and blocked_res.get("block_absorbed") == 6 and blocked_res.get("hp_loss") == 0,
		"marshal blocked: hit fully absorbed by enemy Block")
	_check(blocked_enemies.get_enemy(1)["hp"] == 28 and blocked_enemies.get_enemy(1)["block"] == 4,
		"marshal blocked: Marshal HP 28, Block 10 -> 4")
	_check(blocked_enemies.get_enemy(1)["enrage_stacks"] == 1,
		"marshal blocked: fully blocked hit still awards 1 Enrage stack")
	_check(blocked_party.get_hero(1)["block"] == 3 and blocked_party.get_hero(1)["hp"] == 40,
		"marshal blocked: fully blocked hit still triggers Thorns 3 retaliation (Block 6 -> 3)")

	# 3. Sequential hits to cap stacks:
	var seq_party := _party()
	var seq_enemies := _enemies(["needle_marshal"])
	var rng := _rng(4411)
	var seq_deck := CombatDeck.new([RIM, RIM, RIM, RIM, RIM], rng)
	_check(seq_deck.start_turn(), "marshal seq: deck started")
	seq_deck.combat_state.energy = 10
	seq_deck.energy = 10

	var expected_seq_stacks := [1, 2, 3, 3]
	for step in range(4):
		seq_party._heroes[0]["block"] = 0
		_check(seq_party.gain_block(1, 6), "marshal seq hit %d: seed 6 Warden Block" % (step + 1))
		var seq_res: Dictionary = service.play_card(seq_deck, seq_party, seq_enemies, RIM, 1)
		_check(seq_res.get("ok") == true, "marshal seq hit %d lands" % (step + 1))
		var want_st: int = expected_seq_stacks[step]
		_check(seq_enemies.get_enemy(1)["enrage_stacks"] == want_st,
			"marshal seq hit %d: has %d enrage stacks" % [step + 1, want_st])
		_check(seq_party.get_hero(1)["block"] == 6 - 3,
			"marshal seq hit %d: took Thorns 3 retaliation" % (step + 1))
		_check(seq_enemies.get_enemy(1)["hp"] == 28 - 6 * (step + 1),
			"marshal seq hit %d: Marshal HP 28 - %d" % [step + 1, 6 * (step + 1)])

	# 4. Lethal hit on Marshal:
	var let_party := _party()
	_check(let_party.gain_block(1, 6), "marshal lethal: Warden has 6 Block")
	var let_enemies := _enemies(["needle_marshal"])
	_check(let_enemies.apply_damage(1, 25) and let_enemies.get_enemy(1)["hp"] == 3,
		"marshal lethal: Marshal down to 3 HP")
	var let_deck := _deck(SHIELD_PLUS)
	var let_res: Dictionary = service.play_card(let_deck, let_party, let_enemies, SHIELD_PLUS, 1)
	_check(let_res.get("ok") == true and let_res.get("hp_loss") == 3,
		"marshal lethal: lands lethal strike")
	_check(let_enemies.is_slain(1) and let_enemies.get_enemy(1)["hp"] == 0,
		"marshal lethal: Marshal is slain")
	_check(let_enemies.get_enemy(1)["enrage_stacks"] == 1,
		"marshal lethal: Enrage stack committed onto slain slot without reviving")
	_check(let_party.get_hero(1)["block"] == 3 and let_party.get_hero(1)["hp"] == 40,
		"marshal lethal: Warden took Thorns 3 retaliation on lethal hit")


## AC3: Zero damage produces no Thorns/Enrage; malformed traits fail closed before mutation.
func _test_traited_zero_damage_and_malformed_refusals() -> void:
	# 1. Zero-damage toss against Hedgehog (Thorns 3):
	var z_party := _party()
	var z_enemies := _enemies(["pincushion_hedgehog"])
	var z_deck := _deck(RIM)
	var z_before := _snapshot(z_deck, z_party, z_enemies)
	var z_res: Dictionary = service.play_card(z_deck, z_party, z_enemies, RIM, 1)
	_check(z_res.get("ok") == true and z_res.get("damage") == 0
		and z_res.get("block_absorbed") == 0 and z_res.get("hp_loss") == 0,
		"zero damage: 0 Block RIM produces 0 damage")
	_check(z_enemies.get_enemy(1)["hp"] == 25, "zero damage: Hedgehog HP untouched")
	_check(z_party.get_hero(1)["hp"] == 40 and z_party.get_hero(1)["block"] == 0,
		"zero damage: NO Thorns retaliation occurred against Warden")
	_check(z_deck.energy == 2 and z_deck.discard_pile.count(RIM) == 1,
		"zero damage: exactly one energy charged and one card discarded")
	var z_exp := _expected_traited_success(z_before, RIM, 1, 0, 0, 1, 0, 0, null)
	_check(_snapshot(z_deck, z_party, z_enemies) == z_exp,
		"zero damage: full snapshot matches no-thorns outcome")

	# 2. Zero-damage toss against Hound (Enrage true):
	var z_hound_party := _party()
	var z_hound_enemies := _enemies(["spoolback_hound"])
	var z_hound_deck := _deck(SHIELD)
	var z_h_before := _snapshot(z_hound_deck, z_hound_party, z_hound_enemies)
	var z_h_res: Dictionary = service.play_card(z_hound_deck, z_hound_party, z_hound_enemies, SHIELD, 1)
	_check(z_h_res.get("ok") == true and z_h_res.get("damage") == 0,
		"zero damage: 0 Block SHIELD produces 0 damage on Hound")
	_check(not z_hound_enemies.get_enemy(1).has("enrage_stacks"),
		"zero damage: NO Enrage stack gained on Hound")
	var z_h_exp := _expected_traited_success(z_h_before, SHIELD, 1, 0, 0, 1, 0, 0, null)
	_check(_snapshot(z_hound_deck, z_hound_party, z_hound_enemies) == z_h_exp,
		"zero damage: full snapshot matches no-enrage outcome")

	# 3. Weak-adjusted zero-damage toss against Needle Marshal (Thorns + Enrage):
	var z_weak_party := _party()
	var z_weak_enemies := _enemies(["needle_marshal"])
	var z_weak_deck := _deck(RIM)
	var z_w_res: Dictionary = service.play_card(z_weak_deck, z_weak_party, z_weak_enemies, RIM, 1, {"weak": 1}, {})
	_check(z_w_res.get("ok") == true and z_w_res.get("damage") == 0,
		"weak zero: Weak 0-damage hit on Needle Marshal")
	_check(z_weak_party.get_hero(1)["hp"] == 40 and z_weak_party.get_hero(1)["block"] == 0,
		"weak zero: NO Thorns retaliation on Marshal")
	_check(not z_weak_enemies.get_enemy(1).has("enrage_stacks"),
		"weak zero: NO Enrage stack gained on Marshal")
	_check(z_weak_deck.energy == 2 and z_weak_deck.discard_pile.count(RIM) == 1,
		"weak zero: 1 energy spent, 1 discard")

	# 4. Malformed trait refusals fail closed before mutation or spend:
	var ref_party := _party()
	var ref_deck := _deck(RIM)

	# Negative thorns:
	_rejected(ref_deck, ref_party, CombatEnemies.new([{"id": "spiky", "max_hp": 20, "thorns": -1}]),
		RIM, 1, {}, {}, "thorns negative")
	# Non-int thorns:
	_rejected(ref_deck, ref_party, CombatEnemies.new([{"id": "spiky", "max_hp": 20, "thorns": "sharp"}]),
		RIM, 1, {}, {}, "thorns non-int")
	# Non-bool enrage (string):
	_rejected(ref_deck, ref_party, CombatEnemies.new([{"id": "mad", "max_hp": 20, "enrage": "yes"}]),
		RIM, 1, {}, {}, "enrage non-bool string")
	# Non-bool enrage (int):
	_rejected(ref_deck, ref_party, CombatEnemies.new([{"id": "mad", "max_hp": 20, "enrage": 1}]),
		RIM, 1, {}, {}, "enrage non-bool int")
	# Enrage stacks over cap (4):
	_rejected(ref_deck, ref_party, CombatEnemies.new([{"id": "mad", "max_hp": 20, "enrage": true, "enrage_stacks": 4}]),
		RIM, 1, {}, {}, "enrage stacks over cap")
	# Enrage stacks negative:
	_rejected(ref_deck, ref_party, CombatEnemies.new([{"id": "mad", "max_hp": 20, "enrage": true, "enrage_stacks": -1}]),
		RIM, 1, {}, {}, "enrage stacks negative")
	# Enrage stacks non-int:
	_rejected(ref_deck, ref_party, CombatEnemies.new([{"id": "mad", "max_hp": 20, "enrage": true, "enrage_stacks": "two"}]),
		RIM, 1, {}, {}, "enrage stacks non-int")
	# Non-target enemy in roster has malformed trait:
	_rejected(ref_deck, ref_party, CombatEnemies.new([{"id": "good", "max_hp": 20}, {"id": "bad", "max_hp": 20, "thorns": -1}]),
		RIM, 1, {}, {}, "roster has invalid enemy trait")
	# Dead target among traited enemies:
	var dead_trait_enemies := _enemies(["pincushion_hedgehog"])
	_check(dead_trait_enemies.apply_damage(1, 99) and dead_trait_enemies.is_slain(1),
		"fixture: Hedgehog actually slain")
	_rejected(ref_deck, ref_party, dead_trait_enemies, RIM, 1, {}, {}, "dead traited target")
	# Malformed attacker status with traited target:
	var hedge_enemies := _enemies(["pincushion_hedgehog"])
	_rejected(ref_deck, ref_party, hedge_enemies, RIM, 1, {"weak": -1}, {},
		"malformed status with traited target")


func _rejected(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String,
		target_position: int, attacker_statuses: Dictionary, defender_statuses: Dictionary,
		label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = service.play_card(deck, party, enemies, card_id, target_position,
		attacker_statuses, defender_statuses)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("damage") == 0 and result.get("block_absorbed") == 0
		and result.get("hp_loss") == 0, label + ": refusal reports no hit")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": unchanged party, enemies, piles, energy and RNG")


## The single-transaction expected state: one energy, one discarded held copy, one enemy hit.
func _expected_success(before: Dictionary, card_id: String, target_position: int,
		block_absorbed: int, hp_loss: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= 1
	expected["state_energy"] -= 1
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var enemy: Dictionary = expected["enemies"][target_position - 1]
	enemy["block"] -= block_absorbed
	enemy["hp"] -= hp_loss
	return expected


## Expected transaction state with Thorns retaliation on the attacker and/or Enrage on the target.
func _expected_traited_success(before: Dictionary, card_id: String, target_position: int,
		block_absorbed: int, hp_loss: int, owner_position: int = 1,
		thorns_block_absorbed: int = 0, thorns_hp_loss: int = 0,
		enrage_stacks: Variant = null) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= 1
	expected["state_energy"] -= 1
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var enemy: Dictionary = expected["enemies"][target_position - 1]
	enemy["block"] -= block_absorbed
	enemy["hp"] -= hp_loss
	if enrage_stacks != null:
		enemy["enrage_stacks"] = enrage_stacks
	var hero: Dictionary = expected["heroes"][owner_position - 1]
	hero["block"] -= thorns_block_absorbed
	hero["hp"] -= thorns_hp_loss
	return expected


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var result: Dictionary = {}
	if party != null:
		result["heroes"] = party.get_heroes()
	if enemies != null:
		result["enemies"] = enemies.get_enemies()
	if deck != null:
		result["hand"] = deck.hand.duplicate(true)
		result["draw"] = deck.draw_pile.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		if deck.combat_state != null:
			result["state_energy"] = deck.combat_state.energy
			result["state_turn"] = deck.combat_state.player_turn_active
		if deck._rng != null:
			result["rng_state"] = deck._rng.state
			result["rng_seed"] = deck._rng.seed
	return result


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real five-card hand from six cards, so at least two copies of the named ID are held.
func _deck(card_id: String, seed_value: int = 6452) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, FILLERS[0], FILLERS[1], FILLERS[2]]
	var deck := CombatDeck.new(ids, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(card_id) >= 2,
		card_id + ": real seeded five-card hand holding duplicate copies")
	return deck


func _party() -> CombatParty:
	var raw: String = FileAccess.get_file_as_string(HEROES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array and parsed.size() == CombatParty.PARTY_SIZE,
		"real authored starter party file supplies all three heroes")
	if not parsed is Array or parsed.size() != CombatParty.PARTY_SIZE:
		return CombatParty.new([])
	for hero in parsed:
		if hero is Dictionary and hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
	var party := CombatParty.new(parsed)
	_check(party.is_valid() and party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("max_hp") == 40 and party.get_hero(1).get("hp") == 40,
		"valid real CombatParty with the 40-HP Warden in the front slot")
	return party


## A genuine adjacent swap through the real position rules, not a hand-built roster.
func _moved_party(position: int) -> CombatParty:
	var party := _party()
	var move_id := "fixture_warden_forward"
	var moving := CombatDeck.new([move_id, move_id], _rng(345))
	_check(moving.start_turn(), "position fixture begins a legitimate shared turn")
	var definition := {"id": move_id, "owner": "warden", "cost": 0,
		"from_positions": [1, 2, 3], "action_kind": "adjacent_swap", "direction": 1}
	for step in range(position - 1):
		_check(CombatPositionSwaps.play_move_card(moving, party, move_id, definition),
			"actual adjacent move shifts Warden to " + str(step + 2))
	_check(party.get_hero(position).get("id") == "warden"
		and party.get_hero(position).get("position") == position,
		"Warden identity is really at actual slot " + str(position))
	return party


func _enemies(ids: Array) -> CombatEnemies:
	var definitions: Array = []
	for enemy_id: String in ids:
		definitions.append(_enemy_record(enemy_id))
	var enemies := CombatEnemies.new(definitions)
	var actual: Array = []
	for record in enemies.get_enemies():
		actual.append(record.get("id"))
	_check(enemies.is_valid() and actual == ids,
		"real run_enemies.json roster " + str(ids))
	return enemies


func _enemy_record(enemy_id: String) -> Dictionary:
	for record in _enemy_catalog():
		if record.get("id") == enemy_id:
			return record.duplicate(true)
	_check(false, "shipped enemy catalogs contain " + enemy_id)
	return {}


func _enemy_catalog() -> Array[Dictionary]:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	for path in [ENEMIES_PATH, ELITES_PATH]:
		var raw: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(raw)
		_check(not raw.is_empty() and parsed is Array and not parsed.is_empty(),
			path + " catalog loads")
		if not parsed is Array:
			continue
		for entry in parsed:
			if not entry is Dictionary:
				continue
			var record: Dictionary = entry.duplicate(true)
			var max_hp: Variant = record.get("max_hp")
			if max_hp is float and max_hp == floor(max_hp):
				record["max_hp"] = int(max_hp)
			var thorns: Variant = record.get("thorns")
			if thorns is float and thorns == floor(thorns):
				record["thorns"] = int(thorns)
			var stacks: Variant = record.get("enrage_stacks")
			if stacks is float and stacks == floor(stacks):
				record["enrage_stacks"] = int(stacks)
			_catalog_cache.append(record)
	return _catalog_cache
