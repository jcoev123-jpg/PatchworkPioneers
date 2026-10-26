extends SceneTree
## Deterministic headless contract for Rag Duelist's Feather Feint and Velvet Feint (V3-1).
##
## Feather Feint lives in the v3 starter catalog and Velvet Feint in the v3 reward pool, so
## neither is assumed to be part of the mounted starter deck: every case builds a real seeded
## CombatDeck that genuinely holds the named ID. The party is a real three-hero CombatParty with
## Rag Duelist standing in a printed seat (fixture-only HP, never a hero stat or roster entry),
## and the enemies are shipped run_enemies.json records. The resolver is scene-free; no app,
## reward or live-hand wiring is claimed here.

const ENEMIES_PATH := "res://data/enemies/run_enemies.json"

const FEATHER := "rag_duelist_feather_feint"
const FEATHER_PLUS := "rag_duelist_feather_feint_plus"
const VELVET := "rag_duelist_velvet_feint"
const VELVET_PLUS := "rag_duelist_velvet_feint_plus"
const CARD_IDS := [FEATHER, FEATHER_PLUS, VELVET, VELVET_PLUS]

## Fixture-only HP so a real CombatParty can seat Rag Duelist at 1-3. These numbers are test
## setup, not a new hero stat: no data file or live roster is changed here.
const FIXTURE_HP := {"rag_duelist": 30, "warden": 40, "seamstress": 30}

const FILLERS := ["filler_stitch", "filler_thread", "filler_needle", "filler_ribbon",
	"filler_twig", "filler_button"]

var failures: Array[String] = []
var checks: int = 0
var service := CombatRagDuelistFeintCards.new()
var _catalog_cache: Array[Dictionary] = []


func _initialize() -> void:
	_test_catalog_authentication()
	_test_ac1_paid_play()
	_test_ac2_stacking()
	_test_ac2_refill_and_replay()
	_test_ac3_rejections()
	_test_ac3_repeat_and_no_draw()
	_test_no_unseeded_rng()
	for failure: String in failures:
		printerr(failure)
	print("combat_rag_duelist_feint_cards_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


## AC1: the four exact catalog records the service authenticates, plus the untouched
## starter/pool links and reward eligibility. No global catalog totals or ID ordering.
func _test_catalog_authentication() -> void:
	var starter := RagDuelistStarterCards.new()
	var pool := RagDuelistPoolCards.new()
	var expected := {
		FEATHER: {"source": starter, "name": "Feather Feint", "cost": 1, "copies": 1,
			"reward": false},
		FEATHER_PLUS: {"source": starter, "name": "Feather Feint+", "cost": 0, "copies": 0,
			"reward": false},
		VELVET: {"source": pool, "name": "Velvet Feint", "cost": 1, "copies": 0, "reward": true},
		VELVET_PLUS: {"source": pool, "name": "Velvet Feint+", "cost": 0, "copies": 0,
			"reward": false},
	}
	for card_id: String in CARD_IDS:
		var source: Variant = expected[card_id]["source"]
		var definition: Dictionary = source.get_definition(card_id)
		_check(definition.get("id") == card_id, card_id + ": authored catalog record exists")
		_check(definition.get("display_name") == expected[card_id]["name"],
			card_id + ": authored display name")
		_check(definition.get("owner") == "rag_duelist", card_id + ": authored owner")
		_check(definition.get("cost") == expected[card_id]["cost"],
			card_id + ": authored cost " + str(expected[card_id]["cost"]))
		_check(definition.get("from_positions") == [1, 2], card_id + ": authored FROM is 1-2")
		_check(definition.get("to_positions") == [1, 2, 3], card_id + ": authored TO is 1-3")
		_check(definition.get("target_kind") == "enemy_single",
			card_id + ": authored target is one enemy")
		_check(definition.get("effects") == {"exposed": 1, "draw": 1},
			card_id + ": authored effect is Exposed 1 and draw 1")
		_check(definition.get("starting_copies") == expected[card_id]["copies"],
			card_id + ": authored starting copies untouched")
		_check(definition.get("reward_eligible") == expected[card_id]["reward"],
			card_id + ": authored reward eligibility untouched")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
	_check(starter.get_upgrade_id(FEATHER) == FEATHER_PLUS
		and starter.get_definition(FEATHER_PLUS).get("upgrade_of") == FEATHER,
		"starter base-to-+ link is intact")
	_check(pool.get_upgrade_id(VELVET) == VELVET_PLUS
		and pool.get_definition(VELVET_PLUS).get("upgrade_of") == VELVET,
		"pool base-to-+ link is intact")
	# Real Rag Duelist cards this resolver must not silently play as a Feint.
	for unsupported: String in ["rag_duelist_rapier_lunge", "rag_duelist_cape_parry",
			"rag_duelist_cape_slip", "rag_duelist_needle_prick", "rag_duelist_cape_guard",
			"rag_duelist_tattered_snare", "rag_duelist_needle_barrage",
			"rag_duelist_velvet_feint_plus_plus", "rag_duelist_feather_feint_ultra",
			"RAG_DUELIST_FEATHER_FEINT", "rag_duelist_feather_feint ", ""]:
		_check(not service.is_supported_card(unsupported),
			unsupported + ": not a Feint for this service")
	_check(not service.is_supported_card(7) and not service.is_supported_card(null),
		"non-string IDs are never supported")


## AC1: each of the four IDs is a genuine paid play from a printed seat onto a living enemy.
## One energy for a base, none for a "+", Exposed 1 on that enemy only, one shared draw and
## exactly one discarded held copy; energy, hand, piles, heroes and statuses are snapshotted.
func _test_ac1_paid_play() -> void:
	for card_id: String in CARD_IDS:
		for owner_position in [1, 2]:
			for target_position in [1, 2, 3]:
				var label := "%s owner=%d target=%d" % [card_id, owner_position,
					target_position]
				var party := _party(owner_position)
				var enemies := _enemies(["fray_scavenger", "button_guard", "spool_stalker"])
				var deck := _deck([card_id, card_id, FILLERS[0], FILLERS[1], FILLERS[2],
					FILLERS[3]], 1200 + 10 * owner_position + target_position)
				_check(deck.hand.has(card_id) and deck.energy == CombatState.TURN_ENERGY,
					label + ": real seeded hand holds the Feint with three energy")
				_check(deck.draw_pile.size() >= 1, label + ": a shared card remains to draw")
				var before_enemies: Array[Dictionary] = enemies.get_enemies()
				var before := _snapshot(deck, party, enemies)
				var expected_cost: int = 0 if card_id.ends_with("_plus") else 1

				var result: Dictionary = service.play_card(deck, party, enemies, card_id,
					target_position)
				_check(result.get("ok") == true, label + ": paid play succeeds")
				_check(result.get("card_id") == card_id and result.get("cost") == expected_cost,
					label + ": receipt names the card and its authored cost")
				_check(result.get("owner_position") == owner_position
					and result.get("target_position") == target_position,
					label + ": receipt reports the real owner and enemy slots")
				_check(result.get("exposed") == 1 and result.get("drawn") == 1,
					label + ": exactly Exposed 1 and one drawn card")
				_check(result.get("target_statuses") == {"exposed": 1},
					label + ": receipt carries exactly the target's Exposed 1")
				_check(deck.energy == CombatState.TURN_ENERGY - expected_cost,
					label + ": exactly the authored cost was charged once")
				_check(deck.discard_pile.size() == 1 and deck.discard_pile[0] == card_id,
					label + ": exactly one held copy moved to the discard pile")
				_check(deck.hand.count(card_id) + deck.draw_pile.count(card_id)
					== before["hand"].count(card_id) + before["draw"].count(card_id) - 1,
					label + ": exactly one held copy left the hand for the discard pile")
				_check(deck.hand.size() == before["hand"].size(),
					label + ": one played copy and one drawn card cancel out")
				_check(enemies.get_enemy(target_position).get("statuses") == {"exposed": 1},
					label + ": Exposed 1 persists on the chosen enemy")
				_check(enemies.get_enemy(target_position)["hp"]
					== before_enemies[target_position - 1]["hp"]
					and enemies.get_enemy(target_position)["block"]
					== before_enemies[target_position - 1]["block"],
					label + ": a Feint deals no HP or Block damage")
				for position in range(1, before_enemies.size() + 1):
					if position != target_position:
						_check(enemies.get_enemy(position) == before_enemies[position - 1],
							label + ": enemy " + str(position) + " is untouched")
				_check(party.get_heroes() == before["heroes"],
					label + ": no hero's HP, Block or position changes")
				_check(_snapshot(deck, party, enemies)
					== _expected_play(before, card_id, expected_cost, target_position),
					label + ": exact hand/piles/energy/heroes/enemies and untouched injected RNG")
				# The receipt reports detached status counters, not the live roster.
				result["target_statuses"]["exposed"] = 99
				_check(enemies.get_enemy(target_position).get("statuses") == {"exposed": 1},
					label + ": a mutated receipt cannot change the enemy")


## AC2: an existing Exposed 1 stacks to 2 through CombatEnemies.apply_statuses, other counters
## and enemy slots are preserved.
func _test_ac2_stacking() -> void:
	var party := _party(2)
	var enemies := _enemies(["fray_scavenger", "button_guard", "spool_stalker"])
	_check(enemies.apply_statuses({1: {"exposed": 1, "bleed": 2}, 2: {"weak": 1}}),
		"stacking fixture really carries Exposed 1, Bleed 2 and Weak 1")
	var deck := _deck([VELVET, VELVET, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], 1402)
	_check(deck.hand.has(VELVET), "stacking fixture holds a genuine Velvet Feint")
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = service.play_card(deck, party, enemies, VELVET, 1)
	_check(result.get("ok") == true and result.get("exposed") == 1,
		"a Feint against an already-Exposed foe is legal")
	_check(enemies.get_enemy(1).get("statuses") == {"exposed": 2, "bleed": 2},
		"Exposed 1 stacks additively to 2 and the existing Bleed 2 is preserved")
	_check(result.get("target_statuses") == {"exposed": 2, "bleed": 2},
		"the receipt reports the stacked counters")
	_check(enemies.get_enemy(2).get("statuses") == {"weak": 1},
		"the other enemy keeps its own Weak 1")
	_check(enemies.get_enemy(3) == before["enemies"][2],
		"the untouched enemy gains no counters")
	for position in range(1, 4):
		_check(enemies.get_enemy(position)["position"] == position,
			"enemy slot " + str(position) + " keeps its position")
	_check(_snapshot(deck, party, enemies) == _expected_play(before, VELVET, 1, 1),
		"stacking resolves as one exact transaction with an untouched injected RNG")


## AC2: a seeded refill draws a previously discarded card (never the just-played Feint) using
## CombatDeck's own single generator, and a fixed seed replays the whole final state exactly.
func _test_ac2_refill_and_replay() -> void:
	var first: Dictionary = _refill_run(1501)
	_check(first["result"].get("ok") == true, "refill: the paid Feint plays")
	_check(first["result"].get("drawn") == 1, "refill: exactly one card was drawn")
	_check(not first["after"]["hand"].has(FEATHER),
		"refill: the just-played Feint is not drawn back into the hand")
	_check(first["after"]["discard"] == [FEATHER],
		"refill: the played copy is discarded only after the draw")
	_check(first["after"]["hand"].size() == 2 and first["after"]["draw"].size() == 2,
		"refill: the reshuffled pile supplied one card and kept two")
	_check(first["drawn_card"] in first["discarded_before"],
		"refill: the drawn card really came from the prior discard pile")
	_check(first["after"]["rng_state"] != first["before"]["rng_state"],
		"refill: the seeded reshuffle consumed the injected generator")
	_check(first["after"]["rng_seed"] == first["before"]["rng_seed"],
		"refill: the injected generator was never reseeded")
	_check(first["after"]["enemies"] == first["expected_enemies"],
		"refill: Exposed stacks to 2 and every other enemy record is untouched")

	var second: Dictionary = _refill_run(1501)
	_check(second["after"] == first["after"] and second["result"] == first["result"]
		and second["drawn_card"] == first["drawn_card"],
		"the same seed replays the final hand, both piles, statuses and RNG state exactly")


func _refill_run(seed_value: int) -> Dictionary:
	var party := _party(2)
	var enemies := _enemies(["fray_scavenger", "button_guard", "spool_stalker"])
	_check(enemies.apply_statuses({2: {"exposed": 1, "bleed": 1}, 3: {"weak": 2}}),
		"refill fixture seeds Exposed 1, Bleed 1 and Weak 2")
	var deck := _deck([FEATHER, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], seed_value)
	_check(deck.draw_pile.is_empty() and deck.hand.has(FEATHER),
		"refill fixture drew its whole five-card deck, so only a refill can supply a card")
	# Prior discards through the real API: the played Feint is not among them.
	for filler: String in [FILLERS[3], FILLERS[2], FILLERS[1]]:
		_check(deck.discard_played(filler), "refill fixture discards a prior held card")
	_check(deck.draw_pile.is_empty() and deck.discard_pile.size() == 3
		and deck.hand.has(FEATHER) and not deck.discard_pile.has(FEATHER),
		"refill fixture has an empty draw pile, three prior discards and a held Feint")
	var before := _snapshot(deck, party, enemies)
	var oracle: Dictionary = _oracle_draw(before["draw"], before["discard"], 1,
		before["rng_state"])
	var result: Dictionary = service.play_card(deck, party, enemies, FEATHER, 2)
	var after := _snapshot(deck, party, enemies)
	_check(after["rng_state"] == oracle["rng"], "refill: exact seeded RNG state after the draw")
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= 1
	expected["state_energy"] -= 1
	var expected_hand: Array = expected["hand"]
	expected_hand.append_array(oracle["drawn"])
	expected_hand.remove_at(expected_hand.find(FEATHER))
	expected["hand"] = expected_hand
	expected["draw"] = oracle["draw"]
	var expected_discard: Array = oracle["discard"]
	expected_discard.append(FEATHER)
	expected["discard"] = expected_discard
	expected["rng_state"] = oracle["rng"]
	expected["enemies"][1]["statuses"]["exposed"] = 2
	_check(after == expected, "refill: exact hand, both piles, energy, statuses and RNG state")
	return {"before": before, "after": after, "result": result,
		"drawn_card": oracle["drawn"][0] if oracle["drawn"].size() == 1 else "",
		"discarded_before": before["discard"].duplicate(), "expected_enemies": expected["enemies"]}


## AC3: every invalid request fails closed and leaves the whole transaction untouched,
## including the injected RNG.
func _test_ac3_rejections() -> void:
	var party := _party(1)
	var enemies := _enemies(["fray_scavenger", "button_guard"])

	# Inactive turn while the genuine copy is held and affordable.
	var inactive := _deck([FEATHER, FEATHER, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]],
		1601)
	inactive.combat_state.player_turn_active = false
	_check(not inactive.turn_active and inactive.hand.has(FEATHER) and inactive.energy == 3,
		"inactive-turn fixture holds the Feint and three energy")
	_rejected(inactive, party, enemies, FEATHER, 1, "inactive turn")

	# Missing held copy of a genuine ID.
	var other := _deck([VELVET, VELVET, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], 1602)
	_check(other.hand.has(VELVET) and not other.hand.has(FEATHER),
		"missing-copy fixture genuinely holds only the other Feint")
	_rejected(other, party, enemies, FEATHER, 1, "authentic ID absent from hand")

	# A real Rag Duelist card that is not one of these four Feints.
	var unsupported := _deck(["rag_duelist_needle_prick", "rag_duelist_needle_prick",
		FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], 1603)
	_check(unsupported.hand.has("rag_duelist_needle_prick"),
		"unsupported fixture genuinely holds another Rag Duelist card")
	_rejected(unsupported, party, enemies, "rag_duelist_needle_prick", 1,
		"unsupported Rag Duelist card")
	_rejected(unsupported, party, enemies, "rag_duelist_feather_feint_plus_plus", 1,
		"forged upgraded ID")
	_rejected(unsupported, party, enemies, "", 1, "empty ID")
	_rejected(unsupported, party, enemies, "RAG_DUELIST_FEATHER_FEINT", 1, "forged uppercase ID")

	# Cost: a base Feint cannot be paid at zero energy, while a "+" is legal for free.
	var broke := _deck([FEATHER, FEATHER, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]],
		1604)
	_check(broke.try_spend_energy(3) and broke.energy == 0 and broke.hand.has(FEATHER),
		"energy-short fixture is broke and still holds a base Feint")
	_rejected(broke, party, enemies, FEATHER, 1, "no energy for a base Feint")
	var free := _deck([FEATHER_PLUS, FEATHER_PLUS, FILLERS[0], FILLERS[1], FILLERS[2],
		FILLERS[3]], 1605)
	_check(free.try_spend_energy(3) and free.energy == 0 and free.hand.has(FEATHER_PLUS),
		"free-play fixture is broke and holds the upgraded Feint")
	var free_result: Dictionary = service.play_card(free, _party(1),
		_enemies(["fray_scavenger"]), FEATHER_PLUS, 1)
	_check(free_result.get("ok") == true and free_result.get("cost") == 0 and free.energy == 0,
		"cost 0 is a legal printed cost at zero energy")

	# Owner absent, downed or outside the printed 1-2 seats.
	var downed := _party(2)
	_check(downed.apply_damage(2, 99) and downed.is_downed(2),
		"downed-owner fixture has a genuinely downed Rag Duelist")
	_rejected(_deck([FEATHER, FEATHER, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], 1606),
		downed, enemies, FEATHER, 1, "downed Rag Duelist")
	var rear := _party(3)
	_check(rear.get_hero(3).get("id") == "rag_duelist",
		"rear-slot fixture really seats Rag Duelist in the unprinted slot 3")
	_rejected(_deck([FEATHER, FEATHER, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]],
		1607), rear, enemies, FEATHER, 1, "Rag Duelist in the unprinted rear slot")
	var no_owner := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(no_owner.is_valid() and no_owner.get_hero(1).get("id") != "rag_duelist"
		and no_owner.get_hero(2).get("id") != "rag_duelist"
		and no_owner.get_hero(3).get("id") != "rag_duelist",
		"absent-owner fixture is a valid party without a Rag Duelist")
	_rejected(_deck([FEATHER, FEATHER, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], 1608),
		no_owner, enemies, FEATHER, 1, "Rag Duelist absent from the party")

	# Invalid rosters.
	_rejected(_deck([FEATHER], 1609), CombatParty.new([]), enemies, FEATHER, 1,
		"invalid empty party roster")
	_rejected(_deck([FEATHER], 1610), CombatParty.new([
		{"id": "rag_duelist", "max_hp": 30}, {"id": "rag_duelist", "max_hp": 30},
		{"id": "warden", "max_hp": 40}]), enemies, FEATHER, 1, "invalid duplicate-owner roster")
	_rejected(_deck([FEATHER], 1611), _party(1), CombatEnemies.new([]), FEATHER, 1,
		"invalid empty enemy roster")

	# Enemy target: outside the printed line, beyond the roster or already slain.
	var three := _enemies(["fray_scavenger", "button_guard", "spool_stalker"])
	for wrong_target in [0, -1, 4, 99]:
		_rejected(_deck([FEATHER], 1612), party, three, FEATHER, wrong_target,
			"target outside the printed 1-3 line: " + str(wrong_target))
	var single := _enemies(["fray_scavenger"])
	_check(single.get_enemies().size() == 1, "single-enemy fixture really has one slot")
	_rejected(_deck([FEATHER], 1613), party, single, FEATHER, 2,
		"target missing from a single-enemy roster")
	var wounded := _enemies(["fray_scavenger", "button_guard"])
	_check(wounded.apply_damage(2, 99) and wounded.is_slain(2),
		"slain-target fixture really has a slain slot 2")
	_rejected(_deck([FEATHER], 1614), party, wounded, FEATHER, 2, "target already slain")

	# A roster whose status storage cannot accept the addition must fail before any spend.
	var corrupted := _enemies(["fray_scavenger", "button_guard"])
	corrupted._enemies[1]["statuses"] = {"unknown_status": 1}
	_rejected(_deck([FEATHER], 1615), party, corrupted, FEATHER, 2,
		"enemy roster rejecting the Exposed addition")

	# Null authorities.
	_rejected(null, party, enemies, FEATHER, 1, "null deck")
	_rejected(_deck([FEATHER], 1616), null, enemies, FEATHER, 1, "null party")
	_rejected(_deck([FEATHER], 1617), party, null, FEATHER, 1, "null enemies")


## AC3: one held copy cannot be charged twice, and a play with nothing left to draw still
## succeeds with zero cards drawn.
func _test_ac3_repeat_and_no_draw() -> void:
	var party := _party(1)
	var enemies := _enemies(["fray_scavenger"])
	var deck := _deck([FEATHER, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], 1701)
	_check(deck.hand.count(FEATHER) == 1 and deck.draw_pile.is_empty()
		and deck.discard_pile.is_empty(),
		"single-copy fixture draws its only Feint and has nothing left to draw")
	var result: Dictionary = service.play_card(deck, party, enemies, FEATHER, 1)
	_check(result.get("ok") == true and result.get("drawn") == 0,
		"a legal Feint with no cards available still succeeds drawing zero")
	_check(deck.energy == 2 and deck.hand.size() == 4 and deck.discard_pile == [FEATHER],
		"the zero-draw play still charges once and discards its played copy")
	_check(enemies.get_enemy(1).get("statuses") == {"exposed": 1},
		"the zero-draw play still exposes its target")
	var spent := _snapshot(deck, party, enemies)
	var replay: Dictionary = service.play_card(deck, party, enemies, FEATHER, 1)
	_check(replay.get("ok") == false and replay.get("cost") == 0
		and replay.get("exposed") == 0 and replay.get("drawn") == 0,
		"a repeat play of the consumed copy is refused")
	_check(_snapshot(deck, party, enemies) == spent,
		"the repeat refusal changes no pile, energy, hero, enemy or RNG")


## Resolution never reseeds the injected generator and never touches the global RNG.
func _test_no_unseeded_rng() -> void:
	seed(13579)
	var expected_next: int = randi()
	seed(13579)
	var party := _party(2)
	var enemies := _enemies(["fray_scavenger", "button_guard"])
	var deck := _deck([VELVET_PLUS, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]], 1801)
	var seed_before: int = deck._rng.seed
	var state_before: int = deck._rng.state
	var result: Dictionary = service.play_card(deck, party, enemies, VELVET_PLUS, 2)
	_check(result.get("ok") == true, "RNG fixture plays a genuine Velvet Feint+")
	_check(deck._rng.seed == seed_before, "the injected generator is never reseeded")
	_check(deck._rng.state == state_before,
		"a play with nothing to draw consumes no injected RNG state")
	_check(randi() == expected_next, "resolution never draws from the global RNG")


func _rejected(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String,
		target_position: int, label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = service.play_card(deck, party, enemies, card_id, target_position)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("cost") == 0 and result.get("exposed") == 0
		and result.get("drawn") == 0 and result.get("target_statuses") == {},
		label + ": refusal reports no cost, no Exposed and no draw")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": unchanged party, enemies, piles, energy and RNG")


## The single-transaction expected state when the draw pile still has a card: charge, take the
## next shared card, then discard the played copy, and stack Exposed 1 on the chosen enemy.
func _expected_play(before: Dictionary, card_id: String, cost: int,
		target_position: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= cost
	expected["state_energy"] -= cost
	var drawn: String = expected["draw"].pop_back()
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	hand.append(drawn)
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var enemy: Dictionary = expected["enemies"][target_position - 1]
	if not enemy.has("statuses"):
		enemy["statuses"] = {}
	enemy["statuses"]["exposed"] = int(enemy["statuses"].get("exposed", 0)) + 1
	return expected


## Independent Fisher-Yates/refill oracle mirroring CombatDeck._draw exactly.
func _oracle_draw(draw_pile: Array, discard_pile: Array, count: int,
		rng_state: int) -> Dictionary:
	var oracle := RandomNumberGenerator.new()
	oracle.state = rng_state
	var pile: Array = draw_pile.duplicate()
	var discard: Array = discard_pile.duplicate()
	var drawn: Array = []
	while drawn.size() < count:
		if pile.is_empty():
			if discard.is_empty():
				break
			pile = discard.duplicate()
			discard.clear()
			for index in range(pile.size() - 1, 0, -1):
				var other := oracle.randi_range(0, index)
				var card = pile[index]
				pile[index] = pile[other]
				pile[other] = card
		drawn.append(pile.pop_back())
	return {"draw": pile, "discard": discard, "drawn": drawn, "rng": oracle.state}


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
		if deck.combat_state != null:
			result["energy"] = deck.combat_state.energy
			result["state_energy"] = deck.combat_state.energy
			result["turn"] = deck.turn_active
			result["state_turn"] = deck.combat_state.player_turn_active
		if deck._rng != null:
			result["rng_state"] = deck._rng.state
			result["rng_seed"] = deck._rng.seed
	return result


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _deck(ids: Array, seed_value: int, start: bool = true) -> CombatDeck:
	var cards: Array[String] = []
	for card in ids:
		cards.append(str(card))
	var deck := CombatDeck.new(cards, _rng(seed_value))
	if start:
		_check(deck.start_turn() and deck.turn_active
			and deck.energy == CombatState.TURN_ENERGY
			and deck.hand.size() == mini(cards.size(), CombatDeck.TURN_DRAW),
			"real seeded turn with three energy and its full five-card draw")
	return deck


## A real three-hero CombatParty with Rag Duelist standing in the requested seat.
func _party(owner_position: int = 1) -> CombatParty:
	var order: Array[String] = ["warden", "seamstress"]
	order.insert(owner_position - 1, "rag_duelist")
	var definitions: Array = []
	for hero_id: String in order:
		definitions.append({"id": hero_id, "max_hp": FIXTURE_HP[hero_id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(owner_position).get("id") == "rag_duelist"
		and not party.is_downed(owner_position),
		"living Rag Duelist really stands in seat " + str(owner_position))
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
