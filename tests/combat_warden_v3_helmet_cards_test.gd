extends SceneTree
## Deterministic, headless contract for the V3-1 Warden pot-helmet Weak bonks.
##
## Pot Helm Bonk lives in the v3 starter catalog and Helmet Rattle in the v3 reward pool, so
## neither is assumed to be part of the mounted starter deck: every case builds a real seeded
## CombatDeck that genuinely holds the named ID. The party is the real authored starter party
## (Warden 40 HP, two distinct companions), and the enemies are shipped run_enemies.json records.
## The resolver is scene-free; no app, reward or live-hand wiring is claimed here.

const HEROES_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"

const BONK := "warden_v3_pot_helm_bonk"
const BONK_PLUS := "warden_v3_pot_helm_bonk_plus"
const RATTLE := "warden_v3_helmet_rattle"
const RATTLE_PLUS := "warden_v3_helmet_rattle_plus"
const CARD_IDS := [BONK, BONK_PLUS, RATTLE, RATTLE_PLUS]

## The only authored difference between a base card and its "+": the printed hit, never the Weak.
const PRINTED_DAMAGE := {BONK: 4, BONK_PLUS: 6, RATTLE: 4, RATTLE_PLUS: 6}

## Literal, hand-computed damage after the existing status rules floor once:
## Weak = 3/4, Exposed = 3/2, both = 9/8, all rounded down.
const ADJUSTED_DAMAGE := {
	4: {"none": 4, "weak": 3, "exposed": 6, "both": 4},
	6: {"none": 6, "weak": 4, "exposed": 9, "both": 6},
}

const STATUS_CASES := {
	"none": [{}, {}],
	"weak": [{"weak": 1}, {}],
	"exposed": [{}, {"exposed": 2}],
	"both": [{"weak": 3, "exposed": 1}, {"exposed": 2, "weak": 1}],
}

const FILLERS := ["filler_stitch", "filler_thread", "filler_needle", "filler_ribbon", "filler_twig"]

var failures: Array[String] = []
var checks: int = 0
var service := CombatWardenV3HelmetCards.new()
var _catalog_cache: Array[Dictionary] = []


func _initialize() -> void:
	_test_catalog_authentication()
	_test_ac1_one_paid_weak_hit()
	_test_ac1_owner_and_target_slots()
	_test_ac2_enemy_block_absorbs_first()
	_test_ac2_status_adjustments_use_existing_rules()
	_test_ac3_rejections()
	_test_ac3_repeat_and_retry()
	_test_seeded_replay()
	for failure in failures:
		printerr(failure)
	print("combat_warden_v3_helmet_cards_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


## The service must authenticate exactly the two printings in their own catalogs and nothing else.
func _test_catalog_authentication() -> void:
	var starter := V3WardenStarterCards.new()
	var pool := V3WardenPoolCards.new()
	var expected := {
		BONK: {"source": starter, "effects": {"damage": 4, "weak": 1}},
		BONK_PLUS: {"source": starter, "effects": {"damage": 6, "weak": 1}},
		RATTLE: {"source": pool, "effects": {"damage": 4, "weak": 1}},
		RATTLE_PLUS: {"source": pool, "effects": {"damage": 6, "weak": 1}},
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
		_check(definition.get("to_positions") == [1, 2], card_id + ": authored TO is 1-2")
		_check(definition.get("effects") == expected[card_id]["effects"],
			card_id + ": authored look effect is a hit plus exactly Weak 1")
		_check(int(definition.get("effects", {}).get("damage", 0)) == PRINTED_DAMAGE[card_id],
			card_id + ": authored printed damage matches the resolver table")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
	_check(not starter.has_card(RATTLE) and not pool.has_card(BONK),
		"the starter and pool printings are owned by separate catalogs")
	_check(starter.get_definition(BONK).get("starting_copies") == 1
		and starter.get_definition(BONK_PLUS).get("starting_copies") == 0
		and pool.get_definition(RATTLE).get("starting_copies") == 0
		and pool.get_definition(RATTLE_PLUS).get("starting_copies") == 0,
		"only the starter base is a printed starting copy; reward ids start at zero copies")
	_check(pool.get_definition(RATTLE).get("reward_eligible") == true
		and pool.get_definition(RATTLE_PLUS).get("reward_eligible") == false,
		"only the reward base is reward eligible")
	for unsupported in [
		"warden_v3_rim_toss", "warden_v3_rim_toss_plus", "warden_v3_shield_toss",
		"warden_v3_shield_toss_plus", "warden_v3_shield_catch", "warden_v3_iron_challenge",
		"warden_v3_guard_stitch", "warden_v3_iron_taunt", "warden_v3_rivet_pummel",
		"warden_v3_buckle_rebound", "warden_v3_shieldwall_chorus", "warden_v3_final_bastion",
		"warden_strike", "seamstress_prick", "tinker_pop_shot", "warden_v3_pot_helm_bonk_ultra",
		"warden_v3_helmet_rattle_plus_plus", ""]:
		_check(not service.is_supported_card(unsupported),
			unsupported + ": not a pot-helmet Weak bonk for this service")
	_check(not service.is_supported_card(5) and not service.is_supported_card(null),
		"non-string IDs are never supported")


## AC1/AC2: a genuine held copy is charged once, discarded once, lands one printed hit and adds
## exactly Weak 1 to that enemy while every other actor keeps its Block, HP and statuses.
func _test_ac1_one_paid_weak_hit() -> void:
	for card_id: String in CARD_IDS:
		var party := _party()
		var enemies := _two_enemies()
		_check(enemies.gain_block(2, 7), card_id + ": bystander really holds seven Block")
		_check(enemies.apply_statuses({2: {"weak": 2}}),
			card_id + ": bystander really carries its own Weak 2")
		var bystander_before: Dictionary = enemies.get_enemy(2)
		var target_before: Dictionary = enemies.get_enemy(1)
		var deck := _deck(card_id)
		var before := _snapshot(deck, party, enemies)
		var held_before: int = deck.hand.count(card_id)
		var printed: int = PRINTED_DAMAGE[card_id]

		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 1)
		_check(result.get("ok") == true, card_id + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			card_id + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == 1 and result.get("target_position") == 1,
			card_id + ": receipt reports the real Warden and target slots")
		_check(result.get("base_damage") == printed and result.get("damage") == printed,
			card_id + ": exactly the printed base damage")
		_check(result.get("block_absorbed") == 0 and result.get("hp_loss") == printed,
			card_id + ": no enemy Block means all damage reaches HP")
		_check(result.get("weak") == 1 and result.get("target_statuses") == {"weak": 1},
			card_id + ": receipt reports exactly Weak 1 on the target")
		_check(enemies.get_enemy(1)["hp"] == target_before["hp"] - printed,
			card_id + ": the authoritative target lost exactly the printed damage")
		_check(enemies.get_enemy(1).get("statuses", {}) == {"weak": 1},
			card_id + ": exactly Weak 1 persists on the target")
		_check(enemies.get_enemy(2) == bystander_before,
			card_id + ": the other enemy keeps its Block, HP and Weak 2 untouched")

		var expected := _expected_success(before, card_id, 1, 0, printed, 1)
		_check(_snapshot(deck, party, enemies) == expected,
			card_id + ": exact hand/piles/energy/turn/enemies and untouched injected RNG")
		_check(deck.hand.count(card_id) == held_before - 1
			and deck.discard_pile.count(card_id) == 1 and deck.discard_pile.size() == 1,
			card_id + ": precisely one held copy moved to the discard pile")
		_check(deck.energy == 2, card_id + ": exactly one energy was charged")
		_check(party.get_heroes() == before["heroes"],
			card_id + ": no hero's HP, Block or position changes")
		_check(_snapshot(deck, party, enemies)["rng_state"] == before["rng_state"],
			card_id + ": no run-RNG draw during resolution")
		# The receipt and its statuses are detached copies of the live roster.
		result["damage"] = 999
		result["target_statuses"]["weak"] = 99
		_check(enemies.get_enemy(1)["hp"] == target_before["hp"] - printed
			and enemies.get_enemy(1).get("statuses", {}) == {"weak": 1},
			card_id + ": a mutated receipt cannot change the enemy")


## AC1: the same authentic play is legal from either printed FROM slot onto either printed TO slot.
func _test_ac1_owner_and_target_slots() -> void:
	for card_id: String in CARD_IDS:
		for owner_position in [1, 2]:
			for target_position in [1, 2]:
				var label := "%s owner=%d target=%d" % [card_id, owner_position, target_position]
				var party := _party() if owner_position == 1 else _moved_party(2)
				_check(party.get_hero(owner_position).get("id") == "warden",
					label + ": Warden really stands in the played slot")
				var enemies := _two_enemies()
				var target_before: Dictionary = enemies.get_enemy(target_position)
				var other_before: Dictionary = enemies.get_enemy(3 - target_position)
				var deck := _deck(card_id)
				var before := _snapshot(deck, party, enemies)
				var printed: int = PRINTED_DAMAGE[card_id]

				var result: Dictionary = service.play_card(deck, party, enemies, card_id,
					target_position)
				_check(result.get("ok") == true, label + ": legal play")
				_check(result.get("owner_position") == owner_position
					and result.get("target_position") == target_position,
					label + ": receipt keeps the real owner and target slots")
				_check(result.get("damage") == printed and result.get("hp_loss") == printed,
					label + ": the printed hit lands once")
				_check(enemies.get_enemy(target_position).get("statuses", {}) == {"weak": 1},
					label + ": Weak 1 landed on the chosen enemy only")
				_check(enemies.get_enemy(3 - target_position) == other_before,
					label + ": the unchosen enemy is untouched")
				_check(enemies.get_enemy(target_position)["hp"] == target_before["hp"] - printed,
					label + ": the chosen enemy lost the printed HP")
				_check(_snapshot(deck, party, enemies)
					== _expected_success(before, card_id, target_position, 0, printed, 1),
					label + ": exact single transaction with an untouched injected RNG")


## AC2: enemy Block absorbs before HP and the Weak persists even when nothing reaches HP.
func _test_ac2_enemy_block_absorbs_first() -> void:
	for card_id: String in CARD_IDS:
		var label := card_id + " vs five Block"
		var party := _party()
		var enemies := _two_enemies()
		_check(enemies.gain_block(1, 5), label + ": target really holds five Block")
		var target_before: Dictionary = enemies.get_enemy(1)
		var deck := _deck(card_id)
		var before := _snapshot(deck, party, enemies)
		var printed: int = PRINTED_DAMAGE[card_id]
		var absorb: int = mini(5, printed)
		var hp_loss: int = printed - absorb

		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 1)
		_check(result.get("ok") == true, label + ": paid play")
		_check(result.get("damage") == printed and result.get("block_absorbed") == absorb
			and result.get("hp_loss") == hp_loss, label + ": exact Block then HP split")
		_check(enemies.get_enemy(1)["block"] == 5 - absorb
			and enemies.get_enemy(1)["hp"] == target_before["hp"] - hp_loss,
			label + ": authoritative Block/HP after the hit")
		_check(enemies.get_enemy(1).get("statuses", {}) == {"weak": 1},
			label + ": the confirmed hit Weakens the target even through its Block")
		_check(_snapshot(deck, party, enemies)
			== _expected_success(before, card_id, 1, absorb, hp_loss, 1),
			label + ": exact single transaction with an untouched injected RNG")
	if PRINTED_DAMAGE[BONK] != 4 or PRINTED_DAMAGE[BONK_PLUS] != 6:
		_check(false, "the Block fixtures assume the printed 4/6 split")

	# A four-damage bonk on a five-Block target loses no HP but still Weakens it.
	var party := _party()
	var enemies := _two_enemies()
	_check(enemies.gain_block(1, 5), "all-Block fixture has five enemy Block")
	var hp_before: int = enemies.get_enemy(1)["hp"]
	var deck := _deck(BONK)
	var result: Dictionary = service.play_card(deck, party, enemies, BONK, 1)
	_check(result.get("damage") == 4 and result.get("block_absorbed") == 4
		and result.get("hp_loss") == 0, "four damage is fully absorbed by five Block")
	_check(enemies.get_enemy(1)["hp"] == hp_before and enemies.get_enemy(1)["block"] == 1,
		"the all-Block hit leaves HP alone and one Block behind")
	_check(enemies.get_enemy(1).get("statuses", {}) == {"weak": 1},
		"the all-Block hit still persists Weak 1")

	# An existing Weak stack grows by exactly one; other statuses are never rewritten.
	party = _party()
	enemies = _two_enemies()
	_check(enemies.apply_statuses({1: {"weak": 3, "bleed": 2}}),
		"stacking fixture really carries Weak 3 and Bleed 2")
	deck = _deck(RATTLE_PLUS)
	result = service.play_card(deck, party, enemies, RATTLE_PLUS, 1)
	_check(result.get("ok") == true and result.get("damage") == 6,
		"the upgraded rattle still lands six")
	_check(enemies.get_enemy(1).get("statuses", {}) == {"weak": 4, "bleed": 2},
		"exactly one Weak was added and the existing Bleed was left alone")


## AC2: supplied Weak/Exposed snapshots go through the existing floor-once attack helper.
func _test_ac2_status_adjustments_use_existing_rules() -> void:
	var oracle := CombatStatuses.new()
	for card_id: String in CARD_IDS:
		var printed: int = PRINTED_DAMAGE[card_id]
		for status_name: String in STATUS_CASES:
			var label := "%s %s" % [card_id, status_name]
			var party := _party()
			var enemies := _two_enemies()
			var target_before: Dictionary = enemies.get_enemy(1)
			var deck := _deck(card_id)
			var attacker_statuses: Dictionary = STATUS_CASES[status_name][0].duplicate(true)
			var defender_statuses: Dictionary = STATUS_CASES[status_name][1].duplicate(true)
			var attacker_supplied: Dictionary = attacker_statuses.duplicate(true)
			var defender_supplied: Dictionary = defender_statuses.duplicate(true)
			var before := _snapshot(deck, party, enemies)
			var expected_damage: int = ADJUSTED_DAMAGE[printed][status_name]

			# Cross-check the literal table against the shared helper instead of new math.
			_check(oracle.adjusted_attack_damage(printed, attacker_statuses, defender_statuses)
				== expected_damage, label + ": literal table matches the existing helper")

			var result: Dictionary = service.play_card(deck, party, enemies, card_id, 1,
				attacker_statuses, defender_statuses)
			_check(result.get("ok") == true, label + ": valid status snapshot is accepted")
			_check(result.get("damage") == expected_damage,
				label + ": exact floored damage " + str(expected_damage))
			_check(result.get("hp_loss") == expected_damage
				and enemies.get_enemy(1)["hp"] == target_before["hp"] - expected_damage,
				label + ": the adjusted damage reaches HP")
			_check(enemies.get_enemy(1).get("statuses", {}) == {"weak": 1},
				label + ": Weak 1 is added on top of the supplied snapshot")
			_check(attacker_statuses == attacker_supplied and defender_statuses == defender_supplied,
				label + ": supplied status snapshots are never mutated")
			_check(_snapshot(deck, party, enemies)
				== _expected_success(before, card_id, 1, 0, expected_damage, 1),
				label + ": exact single transaction with an untouched injected RNG")

	# A Weak-Weakened Warden and an Exposed target still floor once, not twice.
	var party := _party()
	var enemies := _two_enemies()
	var deck := _deck(BONK_PLUS)
	var result: Dictionary = service.play_card(deck, party, enemies, BONK_PLUS, 1,
		{"weak": 1}, {"exposed": 1})
	_check(result.get("damage") == 6 and result.get("hp_loss") == 6,
		"six damage with Weak attacker and Exposed target is six (9/8 floored once)")
	_check(enemies.get_enemy(1).get("statuses", {}) == {"weak": 1},
		"the same Weak-and-Exposed hit still applies its own Weak 1")


## AC3: every invalid request fails closed and leaves the whole transaction untouched.
func _test_ac3_rejections() -> void:
	var party := _party()
	var enemies := _two_enemies()

	var inactive := CombatDeck.new([BONK, BONK, BONK, FILLERS[0], FILLERS[1], FILLERS[2]], _rng(541))
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_rejected(inactive, party, enemies, BONK, 1, {}, {}, "inactive turn")

	var deck := _deck(RATTLE)
	_check(deck.hand.has(RATTLE) and not deck.hand.has(BONK),
		"absent-card fixture holds the other genuine ID only")
	_rejected(deck, party, enemies, BONK, 1, {}, {}, "card absent from hand")
	_rejected(deck, party, enemies, "missing_warden_v3_bonk", 1, {}, {}, "unknown card ID")
	_rejected(deck, party, enemies, "", 1, {}, {}, "empty card ID")
	_rejected(deck, party, enemies, "warden_v3_pot_helm_bonk_ULTRA", 1, {}, {},
		"forged uppercase ID")
	_rejected(deck, party, enemies, "warden_v3_pot_helm", 1, {}, {}, "truncated ID")

	# Legal-looking Warden IDs that this resolver must not silently resolve as a Weak bonk.
	for wrong_card in ["warden_v3_rim_toss", "warden_v3_rim_toss_plus", "warden_v3_shield_toss",
			"warden_v3_shield_toss_plus", "warden_v3_shield_catch", "warden_v3_iron_challenge",
			"warden_v3_guard_stitch", "warden_v3_iron_taunt", "warden_v3_rivet_pummel",
			"warden_v3_buckle_rebound", "warden_v3_shieldwall_chorus",
			"warden_v3_final_bastion", "warden_strike", "seamstress_prick", "tinker_pop_shot"]:
		var wrong_deck := _deck(wrong_card)
		_rejected(wrong_deck, party, enemies, wrong_card, 1, {}, {},
			"non-bonk card in hand " + wrong_card)

	# A missing held copy is not enough: the same ID twice must not pay twice for one card.
	var single_copy := CombatDeck.new(
		[BONK, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], _rng(6081))
	_check(single_copy.start_turn() and single_copy.hand.count(BONK) == 1,
		"single-copy fixture draws its one genuine copy")
	_check(service.play_card(single_copy, _party(), _two_enemies(), BONK, 1).get("ok") == true,
		"single-copy fixture plays its only copy once")
	var missing := _two_enemies()
	_rejected(single_copy, _party(), missing, BONK, 1, {}, {},
		"stale copy already discarded")

	var short := _deck(BONK)
	_check(short.try_spend_energy(3) and short.energy == 0 and short.hand.has(BONK),
		"energy-short fixture is genuinely broke and still holds Pot Helm Bonk")
	_rejected(short, party, enemies, BONK, 1, {}, {}, "no energy")

	var torn := _party()
	_check(torn.apply_damage(1, 40) and torn.is_downed(1),
		"torn-owner fixture has a genuinely downed Warden")
	_rejected(_deck(BONK), torn, enemies, BONK, 1, {}, {}, "downed Warden")
	_rejected(_deck(BONK), _moved_party(3), enemies, BONK, 1, {}, {},
		"Warden in the unprinted rear slot 3")

	var no_warden := CombatParty.new([
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
		{"id": "apprentice", "max_hp": 20},
	])
	_check(no_warden.is_valid() and no_warden.get_hero(1).get("id") != "warden"
		and no_warden.get_hero(2).get("id") != "warden"
		and no_warden.get_hero(3).get("id") != "warden",
		"absent-owner fixture is a valid party without a Warden")
	_rejected(_deck(BONK), no_warden, enemies, BONK, 1, {}, {}, "Warden absent from the party")

	for wrong_target in [0, -1, 3, 4, 99]:
		_rejected(_deck(BONK), _party(), _three_enemies(), BONK, wrong_target, {}, {},
			"target outside the printed 1-2 line: " + str(wrong_target))

	var two := _two_enemies()
	_check(two.get_enemies().size() == 2, "two-enemy fixture really has two slots")
	var one := _enemies(["scissor_crab"])
	_check(one.get_enemies().size() == 1, "single-enemy fixture really has one slot")
	_rejected(_deck(BONK), _party(), one, BONK, 2, {}, {},
		"target missing from a single-enemy roster")

	var wounded := _two_enemies()
	_check(wounded.apply_damage(2, 99) and wounded.is_slain(2),
		"slain-target fixture really has a slain slot 2")
	_rejected(_deck(BONK), _party(), wounded, BONK, 2, {}, {}, "target already slain")

	var cleared := _enemies(["scissor_crab"])
	_check(cleared.apply_damage(1, 99) and cleared.is_victorious(),
		"cleared fixture is genuinely victorious")
	_rejected(_deck(BONK), _party(), cleared, BONK, 1, {}, {},
		"no living enemy remains")

	for bad_attacker in [{"weak": -1}, {"weak": "2"}, {"weak": 1.5}, {1: 2}, {"poison": 1},
			{"exposed": true}]:
		_rejected(_deck(BONK), _party(), enemies, BONK, 1, bad_attacker, {},
			"malformed attacker snapshot " + str(bad_attacker))
	for bad_defender in [{"exposed": -2}, {"exposed": "1"}, {"tangled": 1.5}, {"bleed": null},
			{[1]: 2}]:
		_rejected(_deck(BONK), _party(), enemies, BONK, 1, {}, bad_defender,
			"malformed defender snapshot " + str(bad_defender))

	# The Weak addition is preflighted against the authoritative roster: a corrupted enemy status
	# record is rejected before any spend, discard or damage.
	var corrupted := _two_enemies()
	corrupted._enemies[1]["statuses"] = {"tangled": 1}
	_rejected(_deck(BONK), _party(), corrupted, BONK, 2, {}, {},
		"enemy roster with a status shape the Weak addition cannot accept")

	_rejected(null, _party(), enemies, BONK, 1, {}, {}, "null deck")
	_rejected(_deck(BONK), null, enemies, BONK, 1, {}, {}, "null party")
	_rejected(_deck(BONK), _party(), null, BONK, 1, {}, {}, "null enemies")
	_rejected(_deck(BONK), CombatParty.new([]), enemies, BONK, 1, {}, {},
		"invalid party roster")
	_rejected(_deck(BONK), _party(), CombatEnemies.new([]), BONK, 1, {}, {},
		"invalid enemy roster")


## AC3: a rejected attempt never poisons the next authentic one, and a consumed copy cannot replay.
func _test_ac3_repeat_and_retry() -> void:
	var party := _party()
	var enemies := _two_enemies()
	var deck := _deck(RATTLE_PLUS)

	_rejected(deck, party, enemies, RATTLE_PLUS, 1, {"weak": -1}, {}, "retry: malformed first")
	_rejected(deck, party, enemies, RATTLE_PLUS, 0, {}, {}, "retry: wrong target second")
	_rejected(deck, party, enemies, RATTLE_PLUS, 3, {}, {}, "retry: unprinted slot third")

	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = service.play_card(deck, party, enemies, RATTLE_PLUS, 1,
		{"weak": 1}, {})
	_check(result.get("ok") == true and result.get("damage") == 4
		and result.get("hp_loss") == 4, "retry: the authentic Weak-affected play succeeds")
	_check(enemies.get_enemy(1).get("statuses", {}) == {"weak": 1},
		"retry: the Weak 1 lands after the rejected attempts")
	_check(_snapshot(deck, party, enemies)
		== _expected_success(before, RATTLE_PLUS, 1, 0, 4, 1),
		"retry: exactly one charge, one discard, one hit and an untouched RNG")

	# A second play of a consumed copy must not exist: prove it on a deck holding exactly one copy.
	var single := CombatDeck.new(
		[RATTLE_PLUS, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], _rng(4471))
	_check(single.start_turn() and single.hand.count(RATTLE_PLUS) == 1
		and single.energy == 3, "single-copy fixture draws exactly one authentic copy")
	var single_party := _party()
	var single_enemies := _two_enemies()
	var once: Dictionary = service.play_card(single, single_party, single_enemies, RATTLE_PLUS, 1)
	_check(once.get("ok") == true and once.get("damage") == 6,
		"the single held copy plays once for six")
	var spent := _snapshot(single, single_party, single_enemies)
	var replay: Dictionary = service.play_card(single, single_party, single_enemies, RATTLE_PLUS, 1)
	_check(replay.get("ok") == false and replay.get("damage") == 0
		and replay.get("weak") == 0, "a repeat play of the same consumed copy is refused")
	_check(_snapshot(single, single_party, single_enemies) == spent,
		"the repeat refusal changes no pile, energy, hero, enemy or RNG")

	# Three copies and three energy: the fourth play is refused for energy, not silently free.
	var triple := CombatDeck.new(
		[BONK, BONK, BONK, BONK, BONK, FILLERS[0]], _rng(3312))
	_check(triple.start_turn() and triple.hand.count(BONK) >= 4 and triple.energy == 3,
		"repeat fixture really holds four copies and three energy")
	var triple_party := _party()
	var triple_enemies := _enemies(["thimble_beetle"])
	var first_hp: int = triple_enemies.get_enemy(1)["hp"]
	for play_index in range(3):
		var play: Dictionary = service.play_card(triple, triple_party, triple_enemies, BONK, 1)
		_check(play.get("ok") == true and play.get("damage") == 4,
			"repeat play %d lands four damage" % (play_index + 1))
		_check(triple.energy == 2 - play_index and triple.discard_pile.size() == play_index + 1,
			"repeat play %d charges one energy and discards one copy" % (play_index + 1))
		_check(triple_enemies.get_enemy(1).get("statuses", {}).get("weak", 0) == play_index + 1,
			"repeat play %d stacks exactly one more Weak" % (play_index + 1))
	_check(triple_enemies.get_enemy(1)["hp"] == first_hp - 12,
		"three authentic bonks cost twelve HP in total")
	var drained := _snapshot(triple, triple_party, triple_enemies)
	var refused: Dictionary = service.play_card(triple, triple_party, triple_enemies, BONK, 1)
	_check(refused.get("ok") == false and refused.get("weak") == 0,
		"a held copy cannot be played at zero energy")
	_check(_snapshot(triple, triple_party, triple_enemies) == drained,
		"the energy refusal changes no pile, energy, hero, enemy or RNG")


## The same seed and the same request sequence produce identical outcomes.
func _test_seeded_replay() -> void:
	var first := _replay_run(273273)
	var second := _replay_run(273273)
	_check(first == second, "seeded replay produces identical final state")
	_check(first["results"] == second["results"], "seeded replay reports the same receipts")
	_check(first["rng_state"] == second["rng_state"],
		"seeded replay leaves both runs on the same run RNG state")
	_check(first["results"].size() == 5, "seeded replay covers five requests")
	_check(first["results"][0].get("damage") == 3
		and first["results"][1].get("damage") == 6
		and first["results"][2].get("damage") == 9,
		"seeded replay lands the Weak-floored three, the upgraded six and the Exposed nine")
	_check(first["results"][3].get("ok") == false and first["results"][4].get("ok") == false,
		"seeded replay keeps both spent-energy refusals")


func _replay_run(seed_value: int) -> Dictionary:
	var party := _party()
	var enemies := _two_enemies()
	var deck := CombatDeck.new([BONK, BONK, BONK_PLUS, RATTLE, RATTLE_PLUS], _rng(seed_value))
	_check(deck.start_turn() and deck.hand.count(BONK) == 2 and deck.energy == 3,
		"replay fixture draws both Pot Helm Bonk copies and all upgrades")
	var results: Array = []
	var requests := [
		[BONK, 1, {"weak": 1}, {}], [BONK_PLUS, 2, {}, {}],
		[RATTLE_PLUS, 1, {}, {"exposed": 1}], [RATTLE, 1, {}, {}], [BONK, 2, {}, {}],
	]
	for request in requests:
		results.append(service.play_card(deck, party, enemies, request[0], request[1],
			request[2], request[3]))
	var snapshot := _snapshot(deck, party, enemies)
	snapshot["results"] = results
	return snapshot


func _rejected(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String,
		target_position: int, attacker_statuses: Dictionary, defender_statuses: Dictionary,
		label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = service.play_card(deck, party, enemies, card_id, target_position,
		attacker_statuses, defender_statuses)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("damage") == 0 and result.get("block_absorbed") == 0
		and result.get("hp_loss") == 0 and result.get("weak") == 0,
		label + ": refusal reports no hit and no Weak")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": unchanged party, enemies, piles, energy and RNG")


## The single-transaction expected state: one energy, one discarded held copy, one enemy hit and
## exactly one added Weak on that same enemy.
func _expected_success(before: Dictionary, card_id: String, target_position: int,
		block_absorbed: int, hp_loss: int, weak_added: int) -> Dictionary:
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
	if weak_added > 0:
		if not enemy.has("statuses"):
			enemy["statuses"] = {}
		enemy["statuses"]["weak"] = int(enemy["statuses"].get("weak", 0)) + weak_added
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
		and party.get_hero(1).get("max_hp") == 40 and party.get_hero(1).get("hp") == 40
		and party.get_hero(2).get("max_hp") == 30 and party.get_hero(3).get("max_hp") == 26,
		"valid real CombatParty with the 40-HP Warden and two distinct companions")
	return party


## A genuine adjacent swap through the real position rules, not a hand-built roster.
func _moved_party(position: int) -> CombatParty:
	var party := _party()
	var move_id := "fixture_warden_forward"
	var moving := CombatDeck.new([move_id, move_id, move_id], _rng(345))
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


func _two_enemies() -> CombatEnemies:
	return _enemies(["scissor_crab", "button_guard"])


func _three_enemies() -> CombatEnemies:
	return _enemies(["scissor_crab", "button_guard", "spool_stalker"])


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
	_check(false, "shipped run_enemies.json contains " + enemy_id)
	return {}


func _enemy_catalog() -> Array[Dictionary]:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	var raw: String = FileAccess.get_file_as_string(ENEMIES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array and not parsed.is_empty(),
		"shipped run_enemies.json catalog loads")
	if not parsed is Array:
		return []
	for entry in parsed:
		if not entry is Dictionary:
			continue
		var record: Dictionary = entry.duplicate(true)
		var max_hp: Variant = record.get("max_hp")
		if max_hp is float and max_hp == floor(max_hp):
			record["max_hp"] = int(max_hp)
		_catalog_cache.append(record)
	return _catalog_cache
