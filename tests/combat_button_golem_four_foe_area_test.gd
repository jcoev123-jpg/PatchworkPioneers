extends SceneTree
## V3-1 focused headless test for CombatButtonGolemAreaCards over a GENUINE opt-in four-capacity
## roster: Popping Volley (+) reaches every living original slot 1-4 with two independent,
## status-adjusted, Block-before-HP hits per surviving foe, and Buttonstorm (+) reaches every
## living original slot once at its printed per-pop damage.
##
## Everything here is real model state: a seeded CombatDeck, a real CombatParty, an opt-in
## CombatEnemies roster built from shipped run_enemies.json records, and the same
## CombatStatusAttacks/CombatStatuses rules the game uses. The only damage oracle is the shared
## CombatStatuses.adjusted_attack_damage, so this test never reimplements the damage calculator.
## Default-capacity 1-3-foe battles keep their current outcomes, slain foes keep their original
## slots, and every unlawful request is a complete no-op including the seeded RNG.
##
## No live hand, reward, party-picker or app wiring is claimed or tested here: the paid rules
## service is the contract, and the separately owned admission flow mounts four live foes.

const AreaResolver := preload("res://scripts/combat_button_golem_area_cards.gd")

const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
## Four distinct authored run foes, chosen by ID (never by catalog position or a hard-coded
## catalog total) for the explicitly opted-in four-slot roster.
const FOUR_FOE_IDS := ["button_guard", "spool_stalker", "seam_ripper", "felt_bulwark"]

const VOLLEY_IDS := ["button_golem_popping_volley", "button_golem_popping_volley_plus"]
const STORM_IDS := ["button_golem_buttonstorm", "button_golem_buttonstorm_plus"]
const VOLLEY_BASE := {"button_golem_popping_volley": 3,
	"button_golem_popping_volley_plus": 4}
const STORM_PER_POP := {"button_golem_buttonstorm": 4,
	"button_golem_buttonstorm_plus": 5}

## A real seeded deck that genuinely holds the named printing with two cards left to draw.
const DECK_SEED := 907311
const DECK_FILLER := ["warden_strike", "warden_brace", "seamstress_stitch", "tinker_scrap",
	"seamstress_bind", "tinker_bolt"]

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_four_slot_fixture()
	_test_volley_four_foes()
	_test_volley_slain_fourth_and_seat_two()
	_test_storm_four_foes()
	_test_storm_zero_pops()
	_test_storm_slain_fourth()
	_test_default_capacity_retained()
	_test_opt_in_roster_below_capacity()
	_test_refusals()
	if failures.is_empty():
		print("combat_button_golem_four_foe_area_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_button_golem_four_foe_area_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


# ---------------------------------------------------------------------------------------------
# Fixture: a genuine opt-in four-capacity roster of four living authored foes. A default-capacity
# construction of the same four definitions stays empty and inert.
# ---------------------------------------------------------------------------------------------

func _test_four_slot_fixture() -> void:
	_check(CombatEnemies.MAX_ENEMIES == 3 and CombatEnemies.OPT_IN_MAX_ENEMIES == 4,
		"the model still prints its three-foe default and four-foe opt-in capacities")
	var records := _four_enemy_records()
	_check(records.size() == FOUR_FOE_IDS.size(),
		"four distinct authored enemy records were really selected by ID")
	var enemies := CombatEnemies.new(records, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.is_valid() and enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES,
		"the explicit opt-in capacity is a valid four-slot roster")
	var positions: Array[int] = []
	var ids: Array[String] = []
	var living := 0
	for foe: Dictionary in enemies.get_enemies():
		positions.append(int(foe["position"]))
		ids.append(str(foe["id"]))
		if int(foe["hp"]) > 0:
			living += 1
	_check(positions == [1, 2, 3, 4] and ids == FOUR_FOE_IDS and living == 4,
		"four living foes really occupy original slots 1-4 in authored order")
	_check(enemies.get_enemy(4).get("id") == FOUR_FOE_IDS[3]
		and enemies.get_enemy(4).get("position") == 4,
		"the fourth foe is a genuine authoritative slot")
	# The same four definitions through the default constructor never admit four.
	var default_roster := CombatEnemies.new(records)
	_check(default_roster.get_capacity() == CombatEnemies.MAX_ENEMIES
		and not default_roster.is_valid() and default_roster.get_enemies().is_empty(),
		"a default-capacity four-definition construction is empty and inert")


# ---------------------------------------------------------------------------------------------
# AC1: Popping Volley (+) over four living foes, from both legal Golem seats. Two independent
# status-adjusted Block-before-HP hits per surviving foe, surviving slot 2 skipped on hit two,
# slot 4 reached and charged its Block, exactly two energy and one held copy paid, no RNG draw.
# ---------------------------------------------------------------------------------------------

func _test_volley_four_foes() -> void:
	for card_id: String in VOLLEY_IDS:
		for golem_seat in [1, 2]:
			_play_volley_four(card_id, golem_seat)


func _play_volley_four(card_id: String, golem_seat: int) -> void:
	var base: int = int(VOLLEY_BASE[card_id])
	var label := "%s from seat %d over four living foes" % [card_id, golem_seat]
	var deck := _deck(card_id)
	var party := _party(golem_seat)
	party._heroes[golem_seat - 1]["statuses"] = {"weak": 1}
	party._heroes[golem_seat - 1]["buttons_popped"] = 2
	_check(party.gain_block(golem_seat, 4), label + ": the Golem starts with four Block")
	var enemies := _four_enemies()
	var max_hp_by_slot: Array[int] = []
	for foe: Dictionary in enemies.get_enemies():
		max_hp_by_slot.append(int(foe["max_hp"]))
	_check(max_hp_by_slot.size() == 4,
		label + ": the fixture reads four authored enemy limits")
	_check(enemies.apply_statuses({1: {"exposed": 1}}),
		label + ": slot 1 is Exposed through the roster API")
	_check(enemies.gain_block(3, 2), label + ": slot 3 starts with two Block")
	_check(enemies.gain_block(4, 3), label + ": slot 4 starts with three Block")
	# The roster's status API only admits Bleed/Weak/Exposed, so the applied Tangled count is
	# written onto the authoritative record directly, as the shipped area fixtures do.
	enemies._enemies[2]["statuses"] = {"tangled": 1}
	_check(enemies.get_enemy(3).get("statuses") == {"tangled": 1},
		label + ": slot 3 stores a Tangled count before the volley")
	var slot_two_max: int = int(enemies.get_enemy(2)["max_hp"])
	_check(enemies.apply_damage(2, slot_two_max - 1) and enemies.get_enemy(2).get("hp") == 1,
		label + ": slot 2 is reduced to one HP so its first hit is lethal")
	_check(enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
		and enemies.get_enemies().size() == 4,
		label + ": the roster under test really has four original slots")
	var before := _snapshot(deck, party, enemies)

	# Independent per-hit arithmetic: the shared rules, never the resolver.
	var rules := CombatStatuses.new()
	var attacker := {"weak": 1}
	var weak_hit: int = rules.adjusted_attack_damage(base, attacker, {})
	var exposed_hit: int = rules.adjusted_attack_damage(base, attacker, {"exposed": 1})
	var tangled_hit: int = rules.adjusted_attack_damage(base, attacker, {"tangled": 1})
	_check(weak_hit > 1 and exposed_hit != weak_hit and tangled_hit != weak_hit,
		label + ": the owner Weak and the defenders' statuses really change each hit")
	_check(tangled_hit * 2 != rules.adjusted_attack_damage(2 * base, attacker, {"tangled": 1}),
		label + ": two separate Tangled hits differ from one merged " + str(2 * base) + "-damage hit")

	var slot_three_absorbed: int = mini(2, tangled_hit)
	var slot_four_first_absorbed: int = mini(3, weak_hit)
	var slot_four_second_absorbed: int = mini(3 - slot_four_first_absorbed, weak_hit)
	var expected: Array = [
		{"position": 1, "hit": 1, "damage": exposed_hit, "absorbed": 0},
		{"position": 1, "hit": 2, "damage": exposed_hit, "absorbed": 0},
		{"position": 2, "hit": 1, "damage": weak_hit, "absorbed": 0},
		{"position": 3, "hit": 1, "damage": tangled_hit, "absorbed": slot_three_absorbed},
		{"position": 3, "hit": 2, "damage": tangled_hit, "absorbed": 0},
		{"position": 4, "hit": 1, "damage": weak_hit, "absorbed": slot_four_first_absorbed},
		{"position": 4, "hit": 2, "damage": weak_hit, "absorbed": slot_four_second_absorbed},
	]

	var receipt: Dictionary = AreaResolver.new().play_card(deck, party, enemies, card_id, 0)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid volley resolves over the four-capacity roster")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == 2
		and receipt.get("energy_spent") == 2, label + ": it charges exactly two energy")
	_check(receipt.get("owner_position") == golem_seat and receipt.get("target_position") == 0,
		label + ": the receipt binds the real Golem seat and no selected enemy slot")
	_check(receipt.get("buttons_popped") == 2 and receipt.get("base_damage") == base
		and receipt.get("hit_count") == 2,
		label + ": the receipt reports the read counter and printed per-hit base")
	_check(receipt.get("targets") == [1, 2, 3, 4],
		label + ": all four living original slots are targeted in ascending order")

	var hits: Array = receipt.get("hits", [])
	_check(hits.size() == expected.size(), label + ": " + str(expected.size())
		+ " independent hit receipts are reported")
	for index in range(mini(hits.size(), expected.size())):
		var hit: Dictionary = hits[index]
		var want: Dictionary = expected[index]
		var expected_hp_loss: int = int(want["damage"]) - int(want["absorbed"])
		if int(want["position"]) == 2:
			expected_hp_loss = mini(1, expected_hp_loss)
		_check(hit.get("position") == want["position"] and hit.get("hit") == want["hit"],
			label + ": hit " + str(index + 1) + " is slot " + str(want["position"])
			+ " hit " + str(want["hit"]))
		_check(hit.get("base_damage") == base,
			label + ": hit " + str(index + 1) + " keeps printed base " + str(base))
		_check(hit.get("damage") == want["damage"],
			label + ": hit " + str(index + 1) + " is status-adjusted on its own to "
			+ str(want["damage"]))
		_check(hit.get("block_absorbed") == want["absorbed"]
			and hit.get("hp_loss") == expected_hp_loss,
			label + ": hit " + str(index + 1) + " absorbs " + str(want["absorbed"])
			+ " Block and loses " + str(expected_hp_loss) + " HP")

	# The authoritative roster, written from the independent per-hit expectations.
	var exposed_foe: Dictionary = enemies.get_enemy(1)
	_check(exposed_foe.get("hp") == max_hp_by_slot[0] - 2 * exposed_hit
		and exposed_foe.get("block") == 0
		and exposed_foe.get("position") == 1 and exposed_foe.get("statuses") == {"exposed": 1},
		label + ": the Exposed front foe took two separate adjusted hits in slot 1")
	_check(enemies.is_slain(2) and enemies.get_enemy(2).get("hp") == 0
		and enemies.get_enemy(2).get("position") == 2,
		label + ": the one-HP foe dies on hit one and is never hit a second time")
	var tangled_foe: Dictionary = enemies.get_enemy(3)
	var tangled_loss: int = (tangled_hit - slot_three_absorbed) + tangled_hit
	_check(tangled_foe.get("hp") == max_hp_by_slot[2] - tangled_loss
		and tangled_foe.get("block") == 0
		and tangled_foe.get("position") == 3
		and tangled_foe.get("statuses") == {"tangled": 1},
		label + ": the Blocked Tangled foe absorbs per hit and keeps its original slot")
	var fourth: Dictionary = enemies.get_enemy(4)
	var fourth_loss: int = (weak_hit - slot_four_first_absorbed) \
		+ (weak_hit - slot_four_second_absorbed)
	_check(fourth.get("hp") == max_hp_by_slot[3] - fourth_loss and fourth.get("block") == 0
		and fourth.get("position") == 4 and fourth.get("id") == FOUR_FOE_IDS[3],
		label + ": the fourth foe is hit twice and spends its three Block before HP")
	_check(fourth.get("hp") < max_hp_by_slot[3] or fourth.get("block") < 3,
		label + ": slot 4 really changed, not a vacuous assertion")

	# Deck, party and RNG: exactly two energy and one genuinely held copy, nothing else.
	var expected_hand: Array = before["hand"].duplicate()
	expected_hand.erase(card_id)
	_check(deck.energy == 1 and deck.energy == int(before["energy"]) - 2
		and deck.combat_state.energy == int(before["state_energy"]) - 2,
		label + ": exactly two energy left the shared turn")
	_check(deck.hand == expected_hand and deck.discard_pile == [card_id],
		label + ": exactly one genuinely held copy moved to the discard pile")
	_check(deck.draw_pile == before["draw"] and deck.turn_active,
		label + ": the draw pile and the active turn are untouched")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		label + ": resolution consumes no seeded RNG draw")
	_check(party.get_heroes() == before["heroes"],
		label + ": the Golem's Block, statuses, counter and every ally record are unchanged")
	# Mutating a reported receipt can never rewrite the authoritative roster.
	if not hits.is_empty():
		receipt["hits"][0]["damage"] = -99
		_check(enemies.get_enemy(1).get("hp") == max_hp_by_slot[0] - 2 * exposed_hit,
			label + ": mutating the receipt leaves the real roster untouched")


# ---------------------------------------------------------------------------------------------
# AC1/AC3: a genuine fourth-capacity roster still resolves with a pre-slain fourth slot (skipped,
# never compacted, other living slots still hit), and Popping Volley+ is payable from seat 2.
# ---------------------------------------------------------------------------------------------

func _test_volley_slain_fourth_and_seat_two() -> void:
	var card_id := "button_golem_popping_volley_plus"
	var label := "Popping Volley+ beside a pre-slain fourth slot"
	var deck := _deck(card_id)
	var party := _party(1)
	party._heroes[0]["buttons_popped"] = 1
	var enemies := _four_enemies()
	_check(enemies.apply_damage(4, 999) and enemies.is_slain(4),
		label + ": the fourth slot is genuinely slain before the volley")
	var fourth_before: Dictionary = enemies.get_enemy(4)
	var before := _snapshot(deck, party, enemies)
	var receipt: Dictionary = AreaResolver.new().play_card(deck, party, enemies, card_id, 0)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid volley still resolves")
	_check(receipt.get("targets") == [1, 2, 3],
		label + ": only the three living original slots are targeted")
	_check(receipt.get("hits", []).size() == 6,
		label + ": each of the three living foes takes two independent hits")
	_check(enemies.get_enemies().size() == 4 and enemies.get_enemy(4) == fourth_before
		and enemies.get_enemy(4).get("position") == 4,
		label + ": the slain fourth slot is never hit, moved or compacted")
	for position in [1, 2, 3]:
		_check(enemies.get_enemy(position).get("hp")
			< int(before["foes"][position - 1]["hp"]),
			label + ": living original slot " + str(position) + " still takes its hits")
	_check(deck.energy == 1 and deck.discard_pile == [card_id],
		label + ": it pays two energy and one held copy")
	_check(deck._rng.state == before["rng_state"],
		label + ": the cast draws no seeded RNG")

	var seat_two_deck := _deck(card_id)
	var seat_two_party := _party(2)
	seat_two_party._heroes[1]["buttons_popped"] = 0
	var seat_two_enemies := _four_enemies()
	var seat_two_before := _snapshot(seat_two_deck, seat_two_party, seat_two_enemies)
	var seat_two: Dictionary = AreaResolver.new().play_card(
		seat_two_deck, seat_two_party, seat_two_enemies, card_id, 0)
	_check(seat_two.get("ok") == true and seat_two.get("owner_position") == 2
		and seat_two.get("base_damage") == 4 and seat_two.get("targets") == [1, 2, 3, 4],
		"Popping Volley+ is payable by a living Golem in seat 2 beside four authored foes")
	_check(seat_two_enemies.get_enemy(4).get("hp")
		== int(seat_two_before["foes"][3]["max_hp"]) - 8
		and seat_two_deck.energy == 1 and seat_two_deck.discard_pile == [card_id]
		and seat_two_deck._rng.state == seat_two_before["rng_state"],
		"the seat-2 four-foe volley hits slot 4 twice, pays once and draws no RNG")


# ---------------------------------------------------------------------------------------------
# AC2: Buttonstorm (+) over four living foes with an authentic nonzero popped-button count. One
# hit per living original slot in ascending order, fourth slot damaged through its Block, exactly
# one payment, and the counter plus the Golem's Block conserved.
# ---------------------------------------------------------------------------------------------

func _test_storm_four_foes() -> void:
	for card_id: String in STORM_IDS:
		_play_storm_four(card_id, 2)


func _play_storm_four(card_id: String, counter: int) -> void:
	var per_pop: int = int(STORM_PER_POP[card_id])
	var base: int = per_pop * counter
	var label := "%s with %d popped buttons over four living foes" % [card_id, counter]
	var deck := _deck(card_id)
	var party := _party(1)
	party._heroes[0]["buttons_popped"] = counter
	_check(party.gain_block(1, 7), label + ": the Golem starts with seven Block")
	_check(party.get_hero(1).get("buttons_popped") == counter,
		label + ": the Golem really carries its authoritative popped-button count")
	var enemies := _four_enemies()
	_check(enemies.apply_statuses({1: {"exposed": 1}}),
		label + ": slot 1 is Exposed through the roster API")
	_check(enemies.gain_block(2, 4), label + ": slot 2 starts with four Block")
	_check(enemies.gain_block(4, 6), label + ": slot 4 starts with six Block")
	enemies._enemies[1]["statuses"] = {"tangled": 1}
	_check(enemies.get_enemy(2).get("statuses") == {"tangled": 1},
		label + ": slot 2 stores a Tangled count before the storm")
	var max_hp_by_slot: Array[int] = []
	for foe: Dictionary in enemies.get_enemies():
		max_hp_by_slot.append(int(foe["max_hp"]))
	_check(max_hp_by_slot.size() == 4 and base > 0,
		label + ": the fixture really holds four authored limits and a positive storm base")
	var before := _snapshot(deck, party, enemies)

	var rules := CombatStatuses.new()
	var exposed_damage: int = rules.adjusted_attack_damage(base, {}, {"exposed": 1})
	var tangled_damage: int = rules.adjusted_attack_damage(base, {}, {"tangled": 1})
	var plain_damage: int = rules.adjusted_attack_damage(base, {}, {})
	_check(plain_damage == base and exposed_damage > base and tangled_damage > base,
		label + ": the shared rules size one adjusted hit per defender")
	var expected: Array = [
		{"position": 1, "damage": exposed_damage, "absorbed": 0},
		{"position": 2, "damage": tangled_damage, "absorbed": 4},
		{"position": 3, "damage": plain_damage, "absorbed": 0},
		{"position": 4, "damage": plain_damage, "absorbed": 6},
	]

	var receipt: Dictionary = AreaResolver.new().play_card(deck, party, enemies, card_id, 0)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid Buttonstorm resolves over the four-capacity roster")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == 2
		and receipt.get("energy_spent") == 2, label + ": it charges exactly two energy")
	_check(receipt.get("owner_position") == 1 and receipt.get("target_position") == 0,
		label + ": the receipt binds the Golem in seat 1 and no selected enemy slot")
	_check(receipt.get("buttons_popped") == counter and receipt.get("base_damage") == base
		and receipt.get("hit_count") == 1,
		label + ": one hit of the printed " + str(per_pop) + " per prior pop")
	_check(receipt.get("targets") == [1, 2, 3, 4],
		label + ": one hit is due on every living original slot, the fourth included")

	var hits: Array = receipt.get("hits", [])
	_check(hits.size() == 4, label + ": exactly four hit receipts are reported")
	for index in range(mini(hits.size(), expected.size())):
		var hit: Dictionary = hits[index]
		var want: Dictionary = expected[index]
		_check(hit.get("position") == want["position"] and hit.get("hit") == 1,
			label + ": receipt " + str(index + 1) + " is slot " + str(want["position"])
			+ " hit 1")
		_check(hit.get("base_damage") == base and hit.get("damage") == want["damage"],
			label + ": slot " + str(want["position"]) + " takes its adjusted "
			+ str(want["damage"]) + " hit")
		_check(hit.get("block_absorbed") == want["absorbed"]
			and hit.get("hp_loss") == int(want["damage"]) - int(want["absorbed"]),
			label + ": slot " + str(want["position"]) + " spends "
			+ str(want["absorbed"]) + " Block before HP")

	_check(enemies.get_enemy(1).get("hp") == max_hp_by_slot[0] - exposed_damage
		and enemies.get_enemy(1).get("block") == 0,
		label + ": the Exposed front foe loses its adjusted damage and holds no Block")
	_check(enemies.get_enemy(2).get("hp") == max_hp_by_slot[1] - (tangled_damage - 4)
		and enemies.get_enemy(2).get("block") == 0,
		label + ": the Tangled foe loses its adjusted damage after Block")
	_check(enemies.get_enemy(3).get("hp") == max_hp_by_slot[2] - plain_damage
		and enemies.get_enemy(3).get("block") == 0,
		label + ": the plain foe loses exactly its adjusted damage")
	var fourth: Dictionary = enemies.get_enemy(4)
	_check(fourth.get("hp") == max_hp_by_slot[3] - (plain_damage - 6)
		and fourth.get("block") == 0
		and fourth.get("position") == 4 and fourth.get("id") == FOUR_FOE_IDS[3],
		label + ": the fourth foe is hit once through its six Block and keeps its slot")

	var expected_hand: Array = before["hand"].duplicate()
	expected_hand.erase(card_id)
	_check(deck.energy == 1 and deck.hand == expected_hand
		and deck.discard_pile == [card_id] and deck.draw_pile == before["draw"],
		label + ": exactly two energy and one held copy were paid with no draw")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		label + ": resolution consumes no seeded RNG draw")
	_check(party.get_hero(1).get("buttons_popped") == counter
		and party.get_hero(1).get("block") == 7,
		label + ": the popped-button counter and the Golem's Block are conserved")
	_check(party.get_heroes() == before["heroes"],
		label + ": no hero HP, Block, status or counter record changed")


# ---------------------------------------------------------------------------------------------
# AC2: a zero popped-button count is a valid paid zero-damage hit on every living slot, never a
# refusal and never an invented bonus, and the counter stays zero.
# ---------------------------------------------------------------------------------------------

func _test_storm_zero_pops() -> void:
	for card_id: String in STORM_IDS:
		var label := card_id + " with zero popped buttons over four foes"
		var deck := _deck(card_id)
		var party := _party(1)
		party._heroes[0]["buttons_popped"] = 0
		_check(party.gain_block(1, 5), label + ": the Golem starts with five Block")
		var enemies := _four_enemies()
		_check(enemies.apply_statuses({1: {"exposed": 1}}),
			label + ": slot 1 is Exposed through the roster API")
		_check(enemies.gain_block(4, 3), label + ": slot 4 starts with three Block")
		var before := _snapshot(deck, party, enemies)
		_check(CombatStatuses.new().adjusted_attack_damage(0, {}, {"exposed": 1}) == 0,
			label + ": the shared rules keep zero raw damage at zero")
		var receipt: Dictionary = AreaResolver.new().play_card(deck, party, enemies, card_id, 0)
		_check(receipt.get("ok") == true and receipt.get("reason") == "applied"
			and receipt.get("base_damage") == 0 and receipt.get("buttons_popped") == 0,
			label + ": zero pops is a legal paid zero-base hit")
		_check(receipt.get("targets") == [1, 2, 3, 4]
			and receipt.get("hits", []).size() == 4,
			label + ": all four living original slots still receive their one hit")
		for hit: Dictionary in receipt.get("hits", []):
			_check(hit.get("damage") == 0 and hit.get("block_absorbed") == 0
				and hit.get("hp_loss") == 0,
				label + ": slot " + str(hit.get("position")) + " takes a zero-damage hit")
		_check(enemies.get_enemies() == before["foes"],
			label + ": no enemy HP, Block or status changed")
		_check(deck.energy == 1 and deck.discard_pile == [card_id],
			label + ": the zero-damage storm still pays two energy and one held copy")
		_check(party.get_hero(1).get("buttons_popped") == 0
			and party.get_heroes() == before["heroes"],
			label + ": the counter is read as zero and never invented or spent")
		_check(deck._rng.state == before["rng_state"],
			label + ": the zero-damage cast consumes no seeded RNG draw")


# ---------------------------------------------------------------------------------------------
# AC2/AC3: a genuine fourth-capacity roster with a pre-slain fourth slot: the storm skips it, never
# compacts it, and still hits the other three living original slots once each.
# ---------------------------------------------------------------------------------------------

func _test_storm_slain_fourth() -> void:
	var card_id := "button_golem_buttonstorm_plus"
	var per_pop: int = int(STORM_PER_POP[card_id])
	var counter := 1
	var label := "Buttonstorm+ beside a pre-slain fourth slot"
	var deck := _deck(card_id)
	var party := _party(1)
	party._heroes[0]["buttons_popped"] = counter
	var enemies := _four_enemies()
	_check(enemies.apply_damage(4, 999) and enemies.is_slain(4),
		label + ": the fourth slot is genuinely slain before the storm")
	var fourth_before: Dictionary = enemies.get_enemy(4)
	var before := _snapshot(deck, party, enemies)
	var receipt: Dictionary = AreaResolver.new().play_card(deck, party, enemies, card_id, 0)
	_check(receipt.get("ok") == true and receipt.get("base_damage") == per_pop * counter
		and receipt.get("targets") == [1, 2, 3],
		label + ": only the three living original slots are targeted once each")
	_check(receipt.get("hits", []).size() == 3,
		label + ": exactly three hit receipts are reported")
	_check(enemies.get_enemies().size() == 4 and enemies.get_enemy(4) == fourth_before
		and enemies.get_enemy(4).get("position") == 4,
		label + ": the slain fourth slot is never hit, moved or compacted")
	for position in [1, 2, 3]:
		_check(enemies.get_enemy(position).get("hp")
			< int(before["foes"][position - 1]["hp"]),
			label + ": living original slot " + str(position) + " still takes its hit")
	_check(party.get_hero(1).get("buttons_popped") == counter
		and deck.energy == 1 and deck.discard_pile == [card_id],
		label + ": the counter is conserved and the storm pays exactly once")
	_check(deck._rng.state == before["rng_state"],
		label + ": the cast draws no seeded RNG")


# ---------------------------------------------------------------------------------------------
# AC3: unmodified default-capacity 1-3-foe battles keep their current outcomes: every living slot
# is visited, a volley still lands two hits per foe, and each cast pays once.
# ---------------------------------------------------------------------------------------------

func _test_default_capacity_retained() -> void:
	for size in [1, 2, 3]:
		for card_id: String in ["button_golem_popping_volley", "button_golem_buttonstorm_plus"]:
			var volley: bool = VOLLEY_BASE.has(card_id)
			var label := "%s over %d default-capacity foe(s)" % [card_id, size]
			var deck := _deck(card_id)
			var party := _party(1)
			party._heroes[0]["buttons_popped"] = 1
			var enemies := _default_enemies(size)
			_check(enemies.get_capacity() == CombatEnemies.MAX_ENEMIES
				and enemies.get_enemies().size() == size,
				label + ": the roster really has default capacity and " + str(size) + " foe(s)")
			var before := _snapshot(deck, party, enemies)
			var receipt: Dictionary = AreaResolver.new().play_card(deck, party, enemies, card_id, 0)
			var living: Array[int] = []
			for index in range(size):
				living.append(index + 1)
			_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
				label + ": the paid area attack still resolves")
			_check(receipt.get("targets") == living,
				label + ": every living default slot is targeted")
			_check(receipt.get("hits", []).size() == size * (2 if volley else 1),
				label + ": two hits per foe for the volley, one for the storm")
			_check(deck.energy == 1 and deck.discard_pile == [card_id]
				and deck._rng.state == before["rng_state"],
				label + ": exactly one payment and no seeded RNG draw")
			for position in living:
				_check(enemies.get_enemy(position).get("hp")
					< int(before["foes"][position - 1]["hp"]),
					label + ": default slot " + str(position) + " really takes its damage")


# ---------------------------------------------------------------------------------------------
# A genuine opt-in capacity of four does not demand four actors: a smaller roster is still the
# validated actual roster and every one of its living slots is hit.
# ---------------------------------------------------------------------------------------------

func _test_opt_in_roster_below_capacity() -> void:
	var card_id := "button_golem_popping_volley"
	var deck := _deck(card_id)
	var party := _party(1)
	var enemies := CombatEnemies.new([
		{"id": "ol_four_a", "max_hp": 30},
		{"id": "ol_four_b", "max_hp": 30},
	], CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.is_valid() and enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
		and enemies.get_enemies().size() == 2,
		"an opted-in four-capacity roster may genuinely hold two actors")
	var before := _snapshot(deck, party, enemies)
	var receipt: Dictionary = AreaResolver.new().play_card(deck, party, enemies, card_id, 0)
	_check(receipt.get("ok") == true and receipt.get("targets") == [1, 2]
		and receipt.get("hits", []).size() == 4,
		"both living slots of a smaller opt-in roster take two hits each")
	_check(enemies.get_enemy(1).get("hp") == 30 - int(VOLLEY_BASE[card_id]) * 2
		and enemies.get_enemy(2).get("hp") == 30 - int(VOLLEY_BASE[card_id]) * 2,
		"the two living slots lost both printed hits")
	_check(deck.energy == 1 and deck.discard_pile == [card_id]
		and deck._rng.state == before["rng_state"],
		"the smaller opt-in roster is paid exactly once with no seeded RNG draw")


# ---------------------------------------------------------------------------------------------
# AC3: every unlawful request is a complete no-op. Nonzero target, insufficient energy, unlawful
# owner seat, downed owner, malformed status (including the fourth slot), malformed counter,
# non-opted-in and tampered four-foe rosters, and missing collaborators all refuse before payment.
# ---------------------------------------------------------------------------------------------

func _test_refusals() -> void:
	var volley := "button_golem_popping_volley"
	var storm := "button_golem_buttonstorm"

	# `enemy_all` never takes an explicit slot, and a four-foe roster does not make slot 4 one.
	for bad_target in [1, 4, 3, -1, 99]:
		for card_id: String in [volley, storm]:
			_expect_refusal("four-foe enemy_all with a selected slot " + str(bad_target)
				+ " for " + card_id, _deck(card_id), _party(1), _four_enemies(), card_id,
				bad_target, "invalid_target")

	# Exactly one energy is not enough for a two-energy printing.
	var broke := _deck(volley)
	_check(broke.try_spend_energy(2) and broke.energy == 1 and broke.hand.has(volley),
		"energy-short fixture really holds one energy and the card")
	_expect_refusal("insufficient energy over four foes", broke, _party(1), _four_enemies(),
		volley, 0, "insufficient_energy")
	var broke_storm := _deck(storm)
	_check(broke_storm.try_spend_energy(2) and broke_storm.energy == 1,
		"storm energy-short fixture really holds one energy")
	_expect_refusal("insufficient energy for the storm over four foes", broke_storm, _party(1),
		_four_enemies(), storm, 0, "insufficient_energy")

	# The Golem must be the single living body in a legal FROM seat.
	_expect_refusal("Popping Volley from illegal seat 3 over four foes", _deck(volley),
		_party(3), _four_enemies(), volley, 0, "invalid_owner_position")
	_expect_refusal("Buttonstorm from illegal seat 2 over four foes", _deck(storm),
		_party(2), _four_enemies(), storm, 0, "invalid_owner_position")
	var torn := _party(1)
	_check(torn.apply_damage(1, 400) and torn.is_downed(1),
		"torn-Golem fixture has a genuinely downed Golem")
	_expect_refusal("downed Golem over four foes", _deck(volley), torn, _four_enemies(),
		volley, 0, "owner_torn")
	_expect_refusal("no Button Golem in the party over four foes", _deck(volley),
		_party_of(["warden", "seamstress", "tinker"]), _four_enemies(), volley, 0,
		"owner_missing")
	var duplicate := _party(1)
	duplicate._heroes[1]["id"] = "button_golem"
	_check(duplicate.get_hero(2).get("id") == "button_golem",
		"duplicate-Golem fixture really carries a second Golem record")
	_expect_refusal("two Button Golems over four foes", _deck(volley), duplicate,
		_four_enemies(), volley, 0, "duplicate_owner")

	# Malformed authoritative statuses are refused, including on the opted-in fourth slot.
	for bad_status in [{"weak": "1"}, {"tangled": 1.5}, {"bleed": -1}, {"unknown": 1}]:
		var hero_statuses := _party(1)
		hero_statuses._heroes[0]["statuses"] = bad_status
		_check(hero_statuses.get_hero(1).get("statuses") == bad_status,
			"malformed Golem status fixture really stores " + str(bad_status))
		_expect_refusal("malformed Golem status " + str(bad_status) + " over four foes",
			_deck(volley), hero_statuses, _four_enemies(), volley, 0, "malformed_statuses")
	var fourth_status := _four_enemies()
	fourth_status._enemies[3]["statuses"] = {"tangled": 1.5}
	_check(fourth_status.get_enemy(4).get("statuses") == {"tangled": 1.5},
		"the fourth slot really stores a malformed status map")
	_expect_refusal("malformed status on the fourth foe", _deck(volley), _party(1),
		fourth_status, volley, 0, "malformed_statuses")
	_expect_refusal("malformed status on the fourth foe for the storm", _deck(storm),
		_party(1), fourth_status, storm, 0, "malformed_statuses")

	# The popped-button counter is authoritative state for both printings.
	for bad_counter in ["2", -1, 2.5, null, true]:
		var bad_count := _party(1)
		bad_count._heroes[0]["buttons_popped"] = bad_counter
		_check(bad_count.get_hero(1).get("buttons_popped") == bad_counter,
			"malformed counter fixture really stores " + str(bad_counter))
		for card_id: String in [volley, storm]:
			_expect_refusal("malformed popped-button count " + str(bad_counter) + " for "
				+ card_id, _deck(card_id), bad_count, _four_enemies(), card_id, 0,
				"malformed_button_count")

	# A four-foe roster that was never opted in (default constructor) is inert and refused.
	var records := _four_enemy_records()
	var not_opted_in := CombatEnemies.new(records)
	_check(not not_opted_in.is_valid() and not_opted_in.get_enemies().is_empty()
		and not_opted_in.get_capacity() == CombatEnemies.MAX_ENEMIES,
		"the non-opted-in fixture really holds no roster")
	for card_id: String in [volley, storm]:
		_expect_refusal("default-capacity four-foe construction for " + card_id,
			_deck(card_id), _party(1), not_opted_in, card_id, 0, "invalid_roster")

	# A tampered capacity above the model's opt-in maximum never silently admits four actors.
	var tampered := _four_enemies()
	tampered._capacity = CombatEnemies.OPT_IN_MAX_ENEMIES + 1
	_check(tampered.is_valid() and tampered.get_capacity() == 5,
		"the tampered-capacity fixture really claims five slots")
	_expect_refusal("tampered four-foe capacity", _deck(volley), _party(1), tampered, volley,
		0, "invalid_roster")

	# A malformed record in the opted-in fourth slot is refused.
	var broken_fourth := _four_enemies()
	broken_fourth._enemies[3]["hp"] = 999
	_check(broken_fourth.get_enemy(4).get("hp") == 999,
		"the malformed fourth-record fixture really stores HP above its maximum")
	_expect_refusal("malformed fourth foe record", _deck(volley), _party(1), broken_fourth,
		volley, 0, "invalid_roster")

	# Inactive turn and missing collaborators fail closed.
	var inactive := CombatDeck.new([volley], _rng(DECK_SEED))
	_check(not inactive.turn_active and inactive.energy == 0 and inactive.hand.is_empty(),
		"inactive-turn fixture really has not started its turn")
	_expect_refusal("inactive turn over four foes", inactive, _party(1), _four_enemies(),
		volley, 0, "inactive_turn")
	_expect_refusal("missing deck over four foes", null, _party(1), _four_enemies(), volley, 0,
		"invalid_request")
	_expect_refusal("missing party over four foes", _deck(volley), null, _four_enemies(),
		volley, 0, "invalid_request")
	_expect_refusal("missing enemies", _deck(volley), _party(1), null, volley, 0,
		"invalid_request")
	var broken_deck := _deck(volley)
	broken_deck.combat_state = null
	_check(broken_deck.combat_state == null and broken_deck.hand.has(volley),
		"broken-deck fixture really has no combat state and still holds the card")
	_expect_refusal("deck without combat state over four foes", broken_deck, _party(1),
		_four_enemies(), volley, 0, "invalid_deck")

	# A refusal receipt carries the same field set as a success and reports no payment.
	var bare_deck := _deck(volley)
	var receipt: Dictionary = AreaResolver.new().play_card(bare_deck, _party(3), _four_enemies(),
		volley, 0)
	for key: String in ["ok", "reason", "card_id", "cost", "owner_position",
			"target_position", "buttons_popped", "base_damage", "hit_count", "energy_spent",
			"targets", "hits"]:
		_check(receipt.has(key), "refusal receipt carries " + key)
	_check(receipt.get("ok") == false and receipt.get("targets") == []
		and receipt.get("hits") == [] and receipt.get("energy_spent") == 0,
		"refusal reports no spend and no hits")


func _expect_refusal(label: String, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: Variant, target_position: int, reason: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var receipt: Dictionary = AreaResolver.new().play_card(deck, party, enemies, card_id,
		target_position)
	_check(receipt.get("ok") == false, label + ": refused")
	_check(receipt.get("reason") == reason, label + ": refusal reason is " + reason
		+ " (got " + str(receipt.get("reason")) + ")")
	_check(receipt.get("energy_spent") == 0 and receipt.get("targets") == []
		and receipt.get("hits") == [], label + ": refusal reports no spend and no hits")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": deck, party, enemies, counters and seeded RNG are unchanged")


# ---------------------------------------------------------------------------------------------
# Fixtures.
# ---------------------------------------------------------------------------------------------

## Four distinct records authenticated from the shipped run catalog by ID.
func _four_enemy_records() -> Array:
	var catalog: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(ENEMIES_PATH))
	_check(not catalog.is_empty(), "shipped run_enemies.json enemy catalog loads")
	var selected: Array = []
	for required: String in FOUR_FOE_IDS:
		var matches: Array = catalog.filter(func(entry: Variant) -> bool:
			return entry is Dictionary and entry.get("id") == required)
		_check(matches.size() == 1,
			"authored four-foe source present exactly once: " + required)
		if matches.size() == 1:
			selected.append(matches[0].duplicate(true))
	return selected


## A genuinely opted-in four-slot roster of four distinct authored living foes.
func _four_enemies() -> CombatEnemies:
	var records := _four_enemy_records()
	_check(records.size() == FOUR_FOE_IDS.size(),
		"four distinct authenticated enemy records selected")
	var enemies := CombatEnemies.new(records, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.is_valid()
			and enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
			and enemies.get_enemies().size() == FOUR_FOE_IDS.size()
			and enemies.get_enemies().all(func(foe: Dictionary) -> bool:
				return foe.get("hp") == foe.get("max_hp") and foe.get("hp") > 0),
		"explicit opt-in roster really holds four living authored slots")
	return enemies


## A real default-capacity roster of `size` living foes at forty HP each.
func _default_enemies(size: int) -> CombatEnemies:
	var definitions: Array = []
	for index in range(size):
		definitions.append({"id": "default_foe_%d" % (index + 1), "max_hp": 40})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == size,
		"fixture has a valid default-capacity enemy roster of " + str(size))
	return enemies


## A real three-hero party with the Button Golem genuinely sitting in the requested seat.
func _party(golem_seat: int) -> CombatParty:
	var order: Array = ["warden", "seamstress"]
	order.insert(golem_seat - 1, "button_golem")
	var party := _party_of(order)
	_check(party.get_hero(golem_seat).get("id") == "button_golem"
		and party.get_hero(golem_seat).get("position") == golem_seat,
		"fixture has the Golem living in seat " + str(golem_seat))
	return party


func _party_of(order: Array) -> CombatParty:
	var hp := {"button_golem": 48, "warden": 40, "seamstress": 30, "tinker": 26}
	var definitions: Array = []
	for hero_id: String in order:
		definitions.append({"id": hero_id, "max_hp": hp[hero_id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == CombatParty.PARTY_SIZE,
		"fixture has three distinct living heroes")
	return party


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real seeded CombatDeck that starts the shared three-energy turn with the named printing
## genuinely held and two cards left to draw.
func _deck(card_id: String) -> CombatDeck:
	var cards: Array[String] = [card_id]
	cards.append_array(DECK_FILLER)
	var deck := CombatDeck.new(cards, _rng(DECK_SEED))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.has(card_id) and deck.hand.size() == CombatDeck.TURN_DRAW
		and deck.draw_pile.size() == 2,
		"seeded real CombatDeck starts a three-energy turn holding " + card_id)
	return deck


## Detached before/after state: hand, piles, energy, turn, seeded RNG, both rosters and the
## enemy capacity/validity, so no refusal can hide a write.
func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var snapshot: Dictionary = {}
	if deck != null:
		snapshot["draw"] = deck.draw_pile.duplicate(true)
		snapshot["hand"] = deck.hand.duplicate(true)
		snapshot["discard"] = deck.discard_pile.duplicate(true)
		if deck.combat_state != null:
			snapshot["turn"] = deck.turn_active
			snapshot["energy"] = deck.energy
			snapshot["state_turn"] = deck.combat_state.player_turn_active
			snapshot["state_energy"] = deck.combat_state.energy
		else:
			snapshot["combat_state"] = "missing"
		if deck._rng != null:
			snapshot["rng_state"] = deck._rng.state
			snapshot["rng_seed"] = deck._rng.seed
	if party != null:
		snapshot["party_valid"] = party.is_valid()
		snapshot["heroes"] = party.get_heroes()
	if enemies != null:
		snapshot["enemies_valid"] = enemies.is_valid()
		snapshot["enemies_capacity"] = enemies.get_capacity()
		snapshot["foes"] = enemies.get_enemies()
		snapshot["victory"] = enemies.is_victorious()
	return snapshot
