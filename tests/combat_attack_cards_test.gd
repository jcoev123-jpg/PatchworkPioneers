extends SceneTree

const ATTACK_IDS := [
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_strike_plus()
	_test_contract_and_five_attacks()
	_test_modifier_math_and_first_attack()
	_test_bomb_roster_shapes()
	_test_rejection_and_atomicity()
	_test_seeded_replay()
	_test_persisted_statuses()
	_test_area_bridge_atomicity()
	_test_forecast_rejections()
	_test_forecast_matrix()
	_test_forecast_overflow_choice()
	_test_patch_bound_attacks()
	_test_patch_bomb_and_status_overflow()
	_test_patch_torn_mend_and_transfer()
	_test_patch_rejections_and_replay()
	_test_real_shop_coat_wardrobes()
	_test_malformed_patch_wardrobes()
	_test_m05_head_statuses()
	_test_m05_head_rejections()
	for failure in failures:
		printerr(failure)
	print("combat_attack_cards_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _plus_deck() -> CombatDeck:
	var cards := StarterCards.new().get_starting_deck()
	var index := cards.find("warden_strike")
	var upgraded := RunRestCardUpgrade.new(cards, {"warden_strike": "warden_strike_plus"}).choose_upgrade(index)
	_check(upgraded.ok, "real upgrade transaction supplies attack fixture")
	var rng := RandomNumberGenerator.new()
	rng.seed = 78
	var deck := CombatDeck.new(upgraded.deck, rng)
	_check(deck.start_turn(), "upgraded deck starts real turn")
	while not deck.hand.has("warden_strike_plus") and not deck.draw_pile.is_empty():
		deck.draw_extra(1)
	_check(deck.hand.has("warden_strike_plus"), "actual upgraded copy held")
	return deck


func _test_strike_plus() -> void:
	for position in [1, 2]:
		_accept(CombatAttackCards.new(), _plus_deck(), _party(), _enemies(),
			"warden_strike_plus", position, [_hit(position, 7, 0, 7)], 1, "Strike+ normal hit")
	_reject(CombatAttackCards.new(), _plus_deck(), _party(["seamstress", "tinker", "warden"]), _enemies(),
		"warden_strike_plus", 1, "Strike+ Warden at back")
	var empty_energy := _plus_deck()
	_check(empty_energy.try_spend_energy(3), "spend all energy before rejection")
	_reject(CombatAttackCards.new(), empty_energy, _party(), _enemies(), "warden_strike_plus", 1, "Strike+ no energy")
	for target in [0, 3, 4]:
		_reject(CombatAttackCards.new(), _plus_deck(), _party(), _enemies(), "warden_strike_plus", target, "Strike+ unavailable target")
	var enemies := _enemies()
	_check(enemies.apply_damage(1, 999), "slain target fixture")
	_reject(CombatAttackCards.new(), _plus_deck(), _party(), enemies, "warden_strike_plus", 1, "Strike+ slain target")
	_reject(CombatAttackCards.new(), _plus_deck(), _party(), _enemies([20]), "warden_strike_plus", 2, "Strike+ absent slot")
	var absent := _plus_deck()
	_check(absent.discard_played("warden_strike_plus"), "remove held upgraded copy")
	_reject(CombatAttackCards.new(), absent, _party(), _enemies(), "warden_strike_plus", 1, "Strike+ absent from hand")
	var basic := _plus_deck()
	var roster := _enemies()
	_check(CombatBasicAttacks.new().play(basic, _party(), roster, "warden_strike_plus", 1)
		and roster.get_enemy(1).hp == 11 and basic.energy == 2 and basic.discard_pile.has("warden_strike_plus"), "basic resolver also reads seven damage from catalog")


func _test_area_bridge_atomicity() -> void:
	var service := CombatAttackCards.new()
	var deck := _deck(["tinker_pop_shot", "tinker_scrap_bomb"])
	var party := _party()
	var enemies := _enemies([30, 30, 30])
	_accept(service, deck, party, enemies, "tinker_pop_shot", 1,
		[_hit(1, 8, 0, 8)], 1, "Pop Shot consumes bonus before area bridge")
	_check(enemies.gain_block(1, 2) and enemies.gain_block(3, 8), "second attack area Block fixture")
	_seed_modifiers(party, enemies, "tinker_scrap_bomb", {"weak": 1},
		{1: {"exposed": 1}, 3: {"exposed": 1}})
	_accept(service, deck, party, enemies, "tinker_scrap_bomb", 0,
		[_hit(1, 4, 2, 2), _hit(2, 3, 0, 3), _hit(3, 4, 4, 0)], 2,
		"second Tinker attack area floors per slot without bonus", {"weak": 1},
		{1: {"exposed": 1}, 3: {"exposed": 1}})
	for field in ["position", "hp", "block", "statuses"]:
		var bad := _enemies()
		bad._enemies[2][field] = {"weak": -1} if field == "statuses" else -1
		_reject(CombatAttackCards.new(), _deck(["tinker_scrap_bomb"]), _party(), bad,
			"tinker_scrap_bomb", 0, "late malformed roster " + field)
	var absent := _deck(["tinker_scrap_bomb"])
	_check(absent.discard_played("tinker_scrap_bomb"), "remove real held Bomb")
	_reject(CombatAttackCards.new(), absent, _party(), _enemies(), "tinker_scrap_bomb", 0,
		"Bomb absent despite full energy")


func _party(order: Array = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var hp := {"warden": 40, "seamstress": 30, "tinker": 26, "other": 20}
	var definitions: Array = []
	for id in order:
		definitions.append({"id": id, "max_hp": hp[id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"fixture has a valid three-hero authoritative roster")
	return party


func _enemies(hp: Array[int] = [18, 19, 20]) -> CombatEnemies:
	var definitions: Array = []
	for i in range(hp.size()):
		definitions.append({"id": "foe_%d" % i, "max_hp": hp[i]})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hp.size(),
		"fixture has live enemies in their original slots")
	return enemies


func _deck(wanted: Array, seed_value: int = 6917) -> CombatDeck:
	var catalog := StarterCards.new()
	var cards := catalog.get_starting_deck()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5, "authentic seeded deck starts with five held cards and 3 energy")
	# Only real CombatDeck draw_extra may move additional copies into hand.
	var tries := 0
	while not _has_copies(deck.hand, wanted) and not deck.draw_pile.is_empty():
		_check(deck.draw_extra(1) == 1, "draw_extra advances a genuine draw")
		tries += 1
		if tries > cards.size():
			break
	_check(_has_copies(deck.hand, wanted), "all chosen authored copies are truly in hand")
	var found: Array[String] = []
	found.append_array(deck.draw_pile)
	found.append_array(deck.hand)
	found.append_array(deck.discard_pile)
	found.sort()
	var expected := cards.duplicate()
	expected.sort()
	_check(found == expected, "complete authored starting multiset is preserved after draws")
	_check(deck.draw_pile.size() + deck.hand.size() + deck.discard_pile.size() == cards.size(),
		"all original card copies remain in exactly one pile")
	return deck


func _has_copies(hand: Array[String], wanted: Array) -> bool:
	var remaining := hand.duplicate()
	for card_id in wanted:
		var index := remaining.find(card_id)
		if index < 0:
			return false
		remaining.remove_at(index)
	return true


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var result := {}
	if deck != null:
		result["draw"] = deck.draw_pile.duplicate(true)
		result["hand"] = deck.hand.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["active"] = deck.turn_active
		result["energy"] = deck.energy
		result["state_active"] = deck.combat_state.player_turn_active
		result["state_energy"] = deck.combat_state.energy
		result["rng_seed"] = deck._rng.seed
		result["rng_state"] = deck._rng.state
	if party != null:
		result["party"] = party.get_heroes()
	if enemies != null:
		result["enemies"] = enemies.get_enemies()
		result["victory"] = enemies.is_victorious()
	return result



# Only fixture creation may inject actor counters. Caller snapshot dictionaries
# remain separate compatibility arguments and do not supply damage modifiers.
func _seed_modifiers(party: CombatParty, enemies: CombatEnemies, card_id: String,
		owner_statuses: Dictionary, defender_statuses: Dictionary) -> void:
	var owner_id: String = StarterCards.new().get_definition(card_id)["owner"]
	var found := 0
	for hero in party._heroes:
		if hero["id"] == owner_id:
			hero["statuses"] = owner_statuses.duplicate(true)
			found += 1
	_check(found == 1, "fixture seeds unique owner by identity")
	for position in defender_statuses:
		var enemy := enemies.get_enemy(position)
		_check(not enemy.is_empty(), "fixture seeds actual occupied enemy slot")
		if not enemy.is_empty():
			enemies._enemies[position - 1]["statuses"] = defender_statuses[position].duplicate(true)


func _hit(position: int, damage: int, absorbed: int, loss: int,
		statuses: Dictionary = {}) -> Dictionary:
	return {"position": position, "damage": damage, "block_absorbed": absorbed,
		"hp_loss": loss, "statuses": statuses}


func _accept(service: CombatAttackCards, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: String, target: int,
		expected_hits: Array, cost: int, label: String,
		attacker_statuses: Dictionary = {},
		defender_statuses: Dictionary = {}) -> void:
	_check(deck.hand.has(card_id), label + ": real hand holds the played card")
	_check(deck.turn_active and deck.energy >= cost and not enemies.is_victorious(),
		label + ": valid live energy and nonterminal enemy preconditions")
	var before := _snapshot(deck, party, enemies)
	var effects_before := [attacker_statuses.duplicate(true), defender_statuses.duplicate(true)]
	var latch := service._tinker._consumed
	seed(19348)
	var next_global := randi()
	seed(19348)
	var forecast := service.forecast_attack(deck, party, enemies, card_id,
		attacker_statuses, defender_statuses)
	_check(forecast.playable and not forecast.hits.is_empty(), label + ": forecast has real recipients")
	for hit in expected_hits:
		_check({"position": hit.position, "damage": hit.damage} in forecast.hits,
			label + ": forecast agrees with exact actual damage")
	_check(service.forecast_attack(deck, party, enemies, card_id,
		attacker_statuses, defender_statuses) == forecast, label + ": repeat forecast")
	_check(_snapshot(deck, party, enemies) == before and service._tinker._consumed == latch
		and randi() == next_global, label + ": pure forecast preserves full state, latch and RNG")
	var result := service.play_attack(deck, party, enemies, card_id, target,
		attacker_statuses, defender_statuses)
	_check(result == {"ok": true, "hits": expected_hits}, label + ": exact ordered events and statuses")
	var expected := before.duplicate(true)
	expected["energy"] -= cost
	expected["state_energy"] -= cost
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var slots: Array = expected["enemies"]
	for expected_hit in expected_hits:
		var position: int = expected_hit["position"]
		var entry: Dictionary = slots[position - 1]
		entry["block"] -= expected_hit["block_absorbed"]
		entry["hp"] -= expected_hit["hp_loss"]
		for status in expected_hit["statuses"]:
			if not entry.has("statuses"):
				entry["statuses"] = {}
			entry["statuses"][status] = entry["statuses"].get(status, 0) + expected_hit["statuses"][status]
	var all_slain := true
	for entry in slots:
		if entry["hp"] > 0:
			all_slain = false
	expected["victory"] = all_slain
	_check(_snapshot(deck, party, enemies) == expected,
		label + ": exact full deck/turn/RNG/party/HP/Block and untouched slots")
	_check(effects_before == [attacker_statuses, defender_statuses],
		label + ": supplied status snapshots never change or age")


func _reject(service: CombatAttackCards, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: String, target: int, label: String,
		attacker_statuses: Dictionary = {}, defender_statuses: Dictionary = {}) -> void:
	var before := _snapshot(deck, party, enemies)
	var input_before := [attacker_statuses.duplicate(true), defender_statuses.duplicate(true)]
	var first_attack_before := service._tinker._consumed
	_check(service.play_attack(deck, party, enemies, card_id, target,
		attacker_statuses, defender_statuses) == {"ok": false, "hits": []},
		label + ": rejects with empty hits")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": rejects without spending, discarding, RNG or HP/Block mutation")
	_check(input_before == [attacker_statuses, defender_statuses],
		label + ": rejection does not alter supplied statuses")
	_check(service._tinker._consumed == first_attack_before,
		label + ": rejection preserves first-attack state")


func _test_contract_and_five_attacks() -> void:
	var service := CombatAttackCards.new()
	_check(service is RefCounted and service.has_method("play_attack")
		and service.has_method("start_player_turn"),
		"exact scene-free resolver methods are present")
	var catalog := StarterCards.new()
	var counts := {"warden_strike": 2, "warden_shield_bash": 1,
		"seamstress_prick": 2, "tinker_pop_shot": 2, "tinker_scrap_bomb": 1}
	var complete := catalog.get_starting_deck()
	for id in counts:
		_check(complete.count(id) == counts[id], id + ": authored starting copy count")
	for scenario in [
		{"id": "warden_strike", "target": 2, "cost": 1, "block": 4,
			"hit": _hit(2, 6, 4, 2)},
		{"id": "warden_shield_bash", "target": 1, "cost": 2, "block": 3,
			"hit": _hit(1, 8, 3, 5, {"weak": 1})},
		{"id": "seamstress_prick", "target": 3, "cost": 1, "block": 5,
			"hit": _hit(3, 3, 3, 0, {"bleed": 3})},
		{"id": "tinker_pop_shot", "target": 2, "cost": 1, "block": 6,
			"hit": _hit(2, 8, 6, 2)},
	]:
		var deck := _deck([scenario["id"]])
		var party := _party()
		var enemies := _enemies()
		_check(enemies.gain_block(scenario["target"], scenario["block"]),
			"precondition: target has genuine Block")
		_accept(CombatAttackCards.new(), deck, party, enemies, scenario["id"],
			scenario["target"], [scenario["hit"]], scenario["cost"], scenario["id"])
	var bomb_deck := _deck(["tinker_scrap_bomb"])
	var bomb_party := _party()
	var bomb_enemies := _enemies()
	_check(bomb_enemies.gain_block(1, 2) and bomb_enemies.gain_block(2, 10),
		"bomb fixture has two distinct authoritative Block values")
	_accept(CombatAttackCards.new(), bomb_deck, bomb_party, bomb_enemies,
		"tinker_scrap_bomb", 0, [_hit(1, 7, 2, 5), _hit(2, 7, 7, 0),
			_hit(3, 7, 0, 7)], 2, "three-enemy first Scrap Bomb")


func _test_modifier_math_and_first_attack() -> void:
	for entry in [
		{"attacker": {"weak": 1}, "defender": {}, "damage": 4},
		{"attacker": {}, "defender": {"exposed": 1}, "damage": 9},
		{"attacker": {"weak": 1}, "defender": {"exposed": 1}, "damage": 6},
	]:
		var strike_deck := _deck(["warden_strike"])
		var strike_enemies := _enemies()
		_check(strike_enemies.gain_block(1, 3), "modified Strike hits real Block")
		var strike_party := _party()
		_seed_modifiers(strike_party, strike_enemies, "warden_strike", entry.attacker,
			{1: entry.defender})
		_accept(CombatAttackCards.new(), strike_deck, strike_party, strike_enemies,
			"warden_strike", 1, [_hit(1, entry.damage, 3, entry.damage - 3)],
			1, "Strike exact modifier math " + str(entry), entry.attacker, {1: entry.defender})
	var service := CombatAttackCards.new()
	var deck := _deck(["tinker_pop_shot", "tinker_pop_shot", "tinker_scrap_bomb"])
	var party := _party()
	var enemies := _enemies([50, 50, 50])
	# Invalid attempt cannot consume pending first-attack bonus.
	_reject(service, deck, party, enemies, "tinker_pop_shot", 0,
		"missing single selection before Tinker hit")
	_reject(service, deck, party, enemies, "tinker_pop_shot", 1,
		"invalid attacker snapshot before Tinker hit", {"weak": -1})
	_reject(service, deck, party, enemies, "tinker_pop_shot", 1,
		"invalid unselected status before Tinker hit", {}, {3: {"exposed": "1"}})
	_seed_modifiers(party, enemies, "tinker_pop_shot", {"weak": 1},
		{1: {"exposed": 1}, 2: {"exposed": 1}})
	# 8 * (3/4) * (3/2) = 9; floor only ONCE.
	_accept(service, deck, party, enemies, "tinker_pop_shot", 1,
		[_hit(1, 9, 0, 9)], 1, "first Tinker Weak+Exposed",
		{"weak": 1}, {1: {"exposed": 1}})
	# 5 * (3/4) * (3/2) = floor(45/8) = 5, not 4.
	_accept(service, deck, party, enemies, "tinker_pop_shot", 2,
		[_hit(2, 5, 0, 5)], 1, "second Tinker lacks +3, final floor",
		{"weak": 1}, {2: {"exposed": 1}})
	_reject(service, deck, party, enemies, "tinker_scrap_bomb", 1,
		"bomb refuses explicit target")
	# Only 1 energy left: rejected 2-energy bomb, no side effects.
	_reject(service, deck, party, enemies, "tinker_scrap_bomb", 0,
		"unaffordable bomb after two attacks")
	var reset_snapshot := _snapshot(deck, party, enemies)
	service.start_player_turn()
	_check(_snapshot(deck, party, enemies) == reset_snapshot,
		"service turn reset leaves deck, roster and RNG unchanged")
	_check(deck.end_turn() and deck.start_turn(), "real deck crosses player-turn boundary")
	for draw_step in range(12):
		if deck.hand.has("tinker_scrap_bomb"):
			break
		deck.draw_extra(1)
	_check(deck.hand.has("tinker_scrap_bomb"), "reset test draws real bomb copy")
	_accept(service, deck, party, enemies, "tinker_scrap_bomb", 0,
		[_hit(1, 7, 0, 7), _hit(2, 7, 0, 7), _hit(3, 5, 0, 5)],
		2, "new player turn restores Tinker +3")

	# A first successful bomb consumes the bonus for later Pop Shot, too.
	var other := CombatAttackCards.new()
	var cards := _deck(["tinker_scrap_bomb", "tinker_pop_shot"])
	var foes := _enemies()
	var heroes := _party()
	_accept(other, cards, heroes, foes, "tinker_scrap_bomb", 0,
		[_hit(1, 7, 0, 7), _hit(2, 7, 0, 7), _hit(3, 7, 0, 7)],
		2, "bomb first action grants +3 each recipient")
	_accept(other, cards, heroes, foes, "tinker_pop_shot", 3,
		[_hit(3, 5, 0, 5)], 1, "Pop Shot after bomb receives no bonus")
	# Attacker Weak and defender Exposed also independently use existing math.
	for entry in [
		{"weak": {}, "defend": {"exposed": 1}, "damage": 12},
		{"weak": {"weak": 1}, "defend": {}, "damage": 6},
	]:
		var s := CombatAttackCards.new()
		var d := _deck(["tinker_pop_shot"])
		var f := _enemies()
		var p := _party()
		_seed_modifiers(p, f, "tinker_pop_shot", entry["weak"], {1: entry["defend"]})
		_accept(s, d, p, f, "tinker_pop_shot", 1,
			[_hit(1, entry["damage"], 0, entry["damage"])], 1,
			"independent attack multiplier " + str(entry),
			entry["weak"], {1: entry["defend"]})


func _test_bomb_roster_shapes() -> void:
	for count in [1, 2]:
		var hp: Array[int] = []
		for i in range(count):
			hp.append(20)
		var deck := _deck(["tinker_scrap_bomb"])
		var foes := _enemies(hp)
		var hits: Array = []
		for i in range(count):
			hits.append(_hit(i + 1, 7, 0, 7))
		_accept(CombatAttackCards.new(), deck, _party(), foes,
			"tinker_scrap_bomb", 0, hits, 2, "bomb all " + str(count) + " living slots")

	var deck := _deck(["tinker_scrap_bomb"])
	var party := _party()
	var foes := _enemies([10, 10, 10])
	_check(foes.apply_damage(2, 10) and foes.is_slain(2),
		"middle foe is slain without changing roster count or positions")
	_accept(CombatAttackCards.new(), deck, party, foes, "tinker_scrap_bomb",
		0, [_hit(1, 7, 0, 7), _hit(3, 7, 0, 7)], 2,
		"bomb skips slain middle while keeping original position 3")
	_check(foes.get_enemy(2)["position"] == 2 and foes.get_enemy(2)["hp"] == 0,
		"slain middle slot remains in-place")

	var one := _enemies([5])
	var one_deck := _deck(["warden_strike"])
	_accept(CombatAttackCards.new(), one_deck, _party(), one,
		"warden_strike", 1, [_hit(1, 6, 0, 5)], 1,
		"overkill clamps HP loss and triggers actual victory")
	_check(one.is_victorious() and one.get_enemies().size() == 1,
		"one-enemy victory requires the single death")
	_reject(CombatAttackCards.new(), one_deck, _party(), one, "warden_strike",
		1, "no attacks after one-enemy victory")


func _test_rejection_and_atomicity() -> void:
	var ids: Array[String] = []
	ids.assign(ATTACK_IDS)
	for id in ids:
		var deck := _deck([id])
		var party := _party()
		var foes := _enemies()
		_reject(CombatAttackCards.new(), deck, party, foes, id, 4,
			id + ": out-of-range selected enemy")
		_reject(CombatAttackCards.new(), deck, party, foes, id, -1,
			id + ": negative enemy selection")

	var deck := _deck(["warden_strike", "warden_shield_bash", "seamstress_prick",
		"tinker_pop_shot", "tinker_scrap_bomb"])
	var party := _party()
	var foes := _enemies()
	var service := CombatAttackCards.new()
	for card_id in ["", "warden_brace", "seamstress_mend", "tinker_tune_up",
			"not_a_card"]:
		_reject(service, deck, party, foes, card_id, 1,
			"unsupported or missing hand ID " + card_id)
	for target in [0, 3, 4]:
		_reject(service, deck, party, foes, "warden_strike", target,
			"Strike illegal destination")
	for target in [0, 2, 3]:
		_reject(service, deck, party, foes, "warden_shield_bash", target,
			"Shield Bash illegal destination")
	_reject(service, deck, party, foes, "tinker_scrap_bomb", 2,
		"explicit bomb selection rejected")
	_check(foes.apply_damage(2, 19) and foes.is_slain(2), "downed enemy fixture")
	_reject(service, deck, party, foes, "warden_strike", 2,
		"slain destination rejected")
	_reject(service, deck, party, foes, "tinker_pop_shot", 2,
		"slain Pop Shot destination rejected")
	_reject(service, deck, party, foes, "tinker_pop_shot", 0,
		"unselected Pop Shot rejected")
	_reject(service, deck, party, foes, "seamstress_prick", 0,
		"unselected Prick rejected")

	# Even a bad status for the last recipient must reject a three-target
	# bomb before it hits the first. Check unselected slots as well.
	var fresh := _enemies()
	for status in [{"weak": -1}, {"weak": "1"}, {"poison": 1},
			{8: 1}, {"bleed": 0.25}]:
		_reject(service, deck, party, fresh, "tinker_scrap_bomb", 0,
			"malformed attacker statuses " + str(status), status)
		_reject(service, deck, party, fresh, "tinker_scrap_bomb", 0,
			"malformed late recipient statuses " + str(status), {},
			{1: {}, 2: {}, 3: status})
	for status_by_slot in [
		{1: {}, 3: [], 2: {}}, {1: {}, 2: {}, 4: {}},
		{1: {}, 2: {}, "3": {}}, {1: {}, 2: {}, 0: {}}
	]:
		_reject(service, deck, party, fresh, "tinker_scrap_bomb", 0,
			"invalid late recipient entry " + str(status_by_slot), {}, status_by_slot)
	_reject(service, deck, party, fresh, "warden_strike", 1,
		"malformed unused third-slot snapshot", {}, {3: {"weak": -1}})
	_reject(service, deck, party, _enemies([20]), "warden_strike", 1,
		"status map for unoccupied slot", {}, {2: {}})

	# Owner positions are determined by real roster order, not card labels.
	var shuffled := _party(["tinker", "warden", "seamstress"])
	_accept(CombatAttackCards.new(), _deck(["warden_strike"]), shuffled, _enemies(),
		"warden_strike", 1, [_hit(1, 6, 0, 6)], 1,
		"reordered living Warden in allowed position 2")
	for entry in [
		{"order": ["seamstress", "tinker", "warden"], "id": "warden_strike", "target": 1},
		{"order": ["seamstress", "warden", "tinker"], "id": "warden_shield_bash", "target": 1},
		{"order": ["tinker", "warden", "seamstress"], "id": "tinker_pop_shot", "target": 1},
		{"order": ["tinker", "warden", "seamstress"], "id": "tinker_scrap_bomb", "target": 0}
	]:
		_reject(CombatAttackCards.new(), _deck([entry["id"]]), _party(entry["order"]),
			_enemies(), entry["id"], entry["target"], "illegal real owner position " + str(entry))
	for id in ATTACK_IDS:
		var owner_party := _party()
		var owner: String = StarterCards.new().get_definition(id)["owner"]
		var pos: int = {"warden": 1, "seamstress": 2, "tinker": 3}[owner]
		_check(owner_party.apply_damage(pos, 999) and owner_party.is_downed(pos),
			"owner downed in real CombatParty")
		_reject(CombatAttackCards.new(), _deck([id]), owner_party, _enemies(),
			id, 0 if id == "tinker_scrap_bomb" else 1,
			id + ": downed owner")
		var absent_party := _party()
		for hero in absent_party._heroes:
			if hero["id"] == owner:
				hero["id"] = "other"
		_reject(CombatAttackCards.new(), _deck([id]), absent_party,
			_enemies(), id, 0 if id == "tinker_scrap_bomb" else 1,
			id + ": absent owner")
	var duplicate_party := _party()
	duplicate_party._heroes[1]["id"] = "tinker"
	_reject(CombatAttackCards.new(), _deck(["tinker_pop_shot"]),
		duplicate_party, _enemies(), "tinker_pop_shot", 1, "duplicate Tinker owner")
	var missing_party := _party()
	missing_party._heroes[2]["id"] = "other"
	_reject(CombatAttackCards.new(), _deck(["tinker_pop_shot"]),
		missing_party, _enemies(), "tinker_pop_shot", 1, "missing Tinker owner")

	var active_deck := _deck(["warden_strike", "warden_shield_bash"])
	_check(active_deck.try_spend_energy(3), "fixture deliberately exhausts real energy")
	_reject(CombatAttackCards.new(), active_deck, _party(), _enemies(),
		"warden_strike", 1, "zero energy")
	_check(active_deck.end_turn(), "fixture deliberately ends real turn")
	_reject(CombatAttackCards.new(), active_deck, _party(), _enemies(),
		"warden_strike", 1, "inactive turn")
	var copy_deck := _deck(["warden_strike"])
	_accept(CombatAttackCards.new(), copy_deck, _party(), _enemies(),
		"warden_strike", 1, [_hit(1, 6, 0, 6)], 1, "consume a held Strike copy")
	# Some seeded hands can contain the second Strike: play remaining copies
	# through the same resolver, then assert a missing copy fails closed.
	var missing_service := CombatAttackCards.new()
	while copy_deck.hand.has("warden_strike") and copy_deck.energy > 0:
		_accept(missing_service, copy_deck, _party(), _enemies(), "warden_strike",
			1, [_hit(1, 6, 0, 6)], 1, "consume second held Strike")
	_reject(missing_service, copy_deck, _party(), _enemies(),
		"warden_strike", 1, "missing held copy")

	var terminal := _enemies([5, 5, 5])
	for pos in [1, 2, 3]:
		_check(terminal.apply_damage(pos, 5), "slay terminal roster member " + str(pos))
	_check(terminal.is_victorious(), "three-enemy roster actually won")
	_reject(CombatAttackCards.new(), _deck(["tinker_scrap_bomb"]),
		_party(), terminal, "tinker_scrap_bomb", 0, "won roster rejects bomb")
	_reject(CombatAttackCards.new(), _deck(["warden_strike"]),
		_party(), terminal, "warden_strike", 1, "won roster rejects Strike")
	_reject(service, null, _party(), _enemies(), "warden_strike", 1, "null deck")
	_reject(service, _deck(["warden_strike"]), null, _enemies(),
		"warden_strike", 1, "null party")
	_reject(service, _deck(["warden_strike"]), _party(), null,
		"warden_strike", 1, "null enemies")


func _replay(seed_value: int) -> Dictionary:
	var deck := _deck(["warden_strike", "seamstress_prick", "tinker_pop_shot",
		"tinker_scrap_bomb"], seed_value)
	var party := _party()
	var foes := _enemies()
	foes.gain_block(1, 4)
	foes.gain_block(2, 2)
	_seed_modifiers(party, foes, "tinker_pop_shot", {"weak": 1}, {2: {"exposed": 1}})
	var service := CombatAttackCards.new()
	var events := []
	events.append(service.play_attack(deck, party, foes, "tinker_pop_shot", 2,
		{"weak": 1}, {2: {"exposed": 1}}))
	events.append(service.play_attack(deck, party, foes, "warden_strike", 1))
	events.append(service.play_attack(deck, party, foes, "seamstress_prick", 3))
	events.append(service.play_attack(deck, party, foes, "tinker_scrap_bomb", 0))
	return {"events": events, "state": _snapshot(deck, party, foes)}


func _test_seeded_replay() -> void:
	var one := _replay(712)
	var two := _replay(712)
	_check(one == two, "same-seed same actions return identical events and complete state")
	_check(one["events"] == [
		{"ok": true, "hits": [_hit(2, 9, 2, 7)]},
		{"ok": true, "hits": [_hit(1, 6, 4, 2)]},
		{"ok": true, "hits": [_hit(3, 3, 0, 3, {"bleed": 3})]},
		{"ok": false, "hits": []}],
		"replay produces exact independent hit records plus unaffordable last attack")
	var deck := _deck(["tinker_scrap_bomb"])
	var party := _party()
	var enemies := _enemies()
	var service := CombatAttackCards.new()
	seed(987765)
	var expected_global := randi()
	seed(987765)
	var before_rng := deck._rng.state
	var result := service.play_attack(deck, party, enemies, "tinker_scrap_bomb")
	_check(result["ok"] and deck._rng.state == before_rng,
		"successful action leaves injected deck RNG untouched")
	_check(randi() == expected_global,
		"successful action does not consume global RNG draws")


func _test_persisted_statuses() -> void:
	for id in ["seamstress_prick", "warden_shield_bash"]:
		var service := CombatAttackCards.new()
		var deck := _deck([id])
		var party := _party()
		var enemies := _enemies([50, 50, 50])
		var status: String = "bleed" if id == "seamstress_prick" else "weak"
		var count: int = 3 if status == "bleed" else 1
		_check(enemies.gain_block(1, 100), "status hit can be entirely blocked")
		for attempt in range(2):
			if not deck.hand.has(id):
				deck.hand.append(id)
			deck.combat_state.energy = 3
			var event := service.play_attack(deck, party, enemies, id, 1)
			_check(event.ok and event.hits[0].hp_loss == 0, "blocked confirmed hit succeeds")
			_check(enemies.get_enemy(1).statuses == {status: count * (attempt + 1)}, "authoritative repeated statuses additive")
		var tick := CombatStatusTurnBatch.new().tick_side("enemies", enemies.get_enemies())
		_check(tick.ok and tick.actors[0].statuses == {status: count * 2 - 1}, "persisted status advances at owner boundary")
		enemies._enemies[0]["statuses"] = {status: CombatEnemies.MAX_INT}
		deck.hand.append(id)
		deck.combat_state.energy = 3
		_reject(service, deck, party, enemies, id, 1, "authoritative application overflow")
		enemies._enemies[0]["statuses"] = {}
		enemies._enemies[0]["block"] = 0
		enemies._enemies[0]["hp"] = 1
		var lethal := service.play_attack(deck, party, enemies, id, 1)
		_check(lethal.ok and enemies.is_slain(1) and enemies.get_enemy(1).statuses == {status: count}, "lethal confirmed hit persists original slot status")
		_reject(service, deck, party, enemies, id, 1, "repeat input against slain slot")
	var deck := _deck(["tinker_scrap_bomb"])
	var enemies := _enemies()
	enemies._enemies[2]["statuses"] = {"weak": -1}
	_reject(CombatAttackCards.new(), deck, _party(), enemies, "tinker_scrap_bomb", 0, "malformed authoritative last recipient")


func _test_forecast_rejections() -> void:
	for scenario in ["owner", "late", "key", "type", "slot", "inactive", "missing", "energy", "terminal", "invalid", "null", "overflow"]:
		var service := CombatAttackCards.new()
		var deck := _deck(["tinker_scrap_bomb"])
		var party := _party()
		var enemies := _enemies()
		var owner := {}
		var defenders := {}
		match scenario:
			"owner": owner = {"weak": -1}
			"late": defenders = {3: {"exposed": "1"}}
			"key": owner = {9: 1}
			"type": owner = {"weak": 1.5}
			"slot": defenders = {"3": {}}
			"inactive": deck.combat_state.player_turn_active = false
			"missing": deck.discard_played("tinker_scrap_bomb")
			"energy": deck.combat_state.energy = 0
			"terminal":
				for position in [1, 2, 3]:
					enemies.apply_damage(position, 100)
			"invalid": enemies._enemies[2]["position"] = 1
			"null": party = null
			"overflow":
				# Shield Bash cannot apply another Weak stack, even on a blocked hit.
				deck = _deck(["warden_shield_bash"])
				enemies._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
		var before := _snapshot(deck, party, enemies)
		var id := "warden_shield_bash" if scenario == "overflow" else "tinker_scrap_bomb"
		_check(service.forecast_attack(deck, party, enemies, id, owner, defenders)
			== {"playable": false, "requires_selection": false, "hits": []}, "forecast fails closed " + scenario)
		_check(_snapshot(deck, party, enemies) == before and not service._tinker._consumed,
			"rejected forecast preserves surviving models and latch " + scenario)


func _test_forecast_matrix() -> void:
	for id in ATTACK_IDS:
		for consumed in [false, true]:
			for weak in [false, true]:
				for exposed in [false, true]:
					var service := CombatAttackCards.new()
					var deck := _deck([id, "tinker_pop_shot"])
					var party := _party()
					var enemies := _enemies([100, 100, 100])
					if consumed:
						_check(service.play_attack(deck, party, enemies, "tinker_pop_shot", 1).ok,
							"consume real bonus before matrix forecast")
						# Refresh this controlled hand without replacing the session service.
						deck.hand.assign([id])
						deck.combat_state.energy = 3
					_check(enemies.apply_damage(2, 100), "matrix excludes slain original middle slot")
					var owner := {"weak": 1} if weak else {}
					var defenders := {1: {"exposed": 1}} if exposed else {}
					_seed_modifiers(party, enemies, id, owner, defenders)
					var before := _snapshot(deck, party, enemies)
					var forecast := service.forecast_attack(deck, party, enemies, id, owner, defenders)
					var positions: Array = []
					var expected: Array = []
					var definition := StarterCards.new().get_definition(id)
					var base: int = definition.effects.damage + (3 if id.begins_with("tinker_") and not consumed else 0)
					for position in [1, 3]:
						if position not in definition.to_positions:
							continue
						positions.append(position)
						var multiplier := 1.125 if weak and exposed and position == 1 else 0.75 if weak else 1.5 if exposed and position == 1 else 1.0
						expected.append({"position": position, "damage": int(floor(base * multiplier))})
					_check(forecast == {"playable": true, "requires_selection": id != "tinker_scrap_bomb", "hits": expected},
						"exact ordered independent forecast math and excluded slots " + id)
					_check(_snapshot(deck, party, enemies) == before and service._tinker._consumed == consumed,
						"matrix forecast leaves state and used/unused latch intact")
					var actual := service.play_attack(deck, party, enemies, id,
						0 if id == "tinker_scrap_bomb" else positions[0], owner, defenders)
					_check(actual.ok and not actual.hits.is_empty(), "matrix subsequent actual attack succeeds")
					for hit in actual.hits:
						_check({"position": hit.position, "damage": hit.damage} in forecast.hits,
							"matrix forecast agrees with actual status-adjusted hit")


func _test_forecast_overflow_choice() -> void:
	var service := CombatAttackCards.new()
	var deck := _deck(["seamstress_prick"])
	var party := _party()
	var enemies := _enemies([100, 100])
	enemies._enemies[0]["statuses"] = {"bleed": CombatEnemies.MAX_INT - 2}
	var before := _snapshot(deck, party, enemies)
	var forecast := service.forecast_attack(deck, party, enemies, "seamstress_prick")
	_check(forecast == {"playable": true, "requires_selection": true,
		"hits": [{"position": 2, "damage": 3}]}, "overflow excludes only the individually unplayable choice")
	_check(_snapshot(deck, party, enemies) == before, "overflow filtering is pure")
	_reject(service, deck, party, enemies, "seamstress_prick", 1, "overflow choice still rejected at cast")
	var actual := service.play_attack(deck, party, enemies, "seamstress_prick", 2)
	_check(actual.ok and actual.hits[0].position == 2 and actual.hits[0].damage == forecast.hits[0].damage,
		"remaining forecast choice matches successful actual hit")

## Real M04 authoring, starter-party ledger, and legal sewing for each combat.

func _shop_coat_context(mode: String) -> Dictionary:
	var hero_records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	_check(hero_records is Array and not hero_records.is_empty(), "real hero catalog loaded")
	var hero_defs := []
	for record in hero_records:
		hero_defs.append({"id": record.id, "max_hp": int(record.max_hp)})
	var party := CombatParty.new(hero_defs)
	var definitions := []
	for path in ["res://data/patches/initial_patch_slots.json",
			"res://data/patches/m04_coat_patches.json"]:
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(records is Array and not records.is_empty(), "real patch catalog loaded: " + path)
		for record in records:
			definitions.append({"id": record.id, "slot": record.slot})
	for id in ["stitched_badge", "spare_spool", "quilted_coat"]:
		_check(definitions.filter(func(record): return record.id == id).size() == 1,
			"genuine wardrobe definition present exactly once: " + id)
	var owned := ["stitched_badge", "spare_spool"]
	if mode != "shop":
		owned.append("quilted_coat")
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, definitions,
		4, 117, StarterCards.new().get_starting_deck(), 920151)
	var torn := RunTornMending.new(party.get_heroes())
	_check(party.is_valid() and wardrobe.is_valid() and torn.is_valid(),
		"genuine Shop/Elite fixture uses valid real services")
	for assignment in [{"id": "stitched_badge", "owner": "warden", "slot": "HEAD"},
			{"id": "spare_spool", "owner": "seamstress", "slot": "ARM"}]:
		_check(wardrobe.sew(assignment.id, assignment.owner, assignment.slot,
			"sew_" + assignment.id, wardrobe.get_snapshot()).ok, "real Shop patch sewn")
	if mode != "shop":
		_check(wardrobe.sew("quilted_coat", "warden", "COAT", "sew_coat",
			wardrobe.get_snapshot()).ok, "real Quilted Coat sewn")
	if mode == "torn":
		var start: Array = torn.read_state().heroes
		_check(party.apply_damage(1, 999) and party.is_downed(1), "actual wearer downed")
		_check(torn.observe_battle_end("shop_tear", start, party.get_heroes()).ok,
			"real torn ledger observes downed Shop/Coat wearer")
		_check(wardrobe.project_active(torn.read_state()).active.warden.is_empty(),
			"torn wearer has no active patches")
	var state := wardrobe.get_snapshot()
	_check(state.owned == owned and state.definitions.size() == definitions.size(),
		"wardrobe has only supplied ownership and projected slot metadata")
	for id in ["button_eye", "pincushion_arm"]:
		_check(not state.owned.has(id) and not state.definitions.has(id),
			"real Shop/Elite wardrobe neither owns nor defines " + id)
	return {"party": party, "wardrobe": wardrobe, "torn": torn}


func _test_real_shop_coat_wardrobes() -> void:
	for mode in ["shop", "coat", "torn"]:
		var replays := []
		for replay in range(2):
			var ctx := _shop_coat_context(mode)
			var ledger_before := [ctx.wardrobe.get_snapshot(), ctx.torn.read_state()]
			var service := _patch_service(ctx)
			var deck := _deck(["seamstress_prick", "tinker_pop_shot"], 920151)
			var foes := _enemies([40, 40])
			_check(foes.gain_block(1, 2), "real target Block precondition")
			var latch := service._patches.latch_snapshot()
			_accept(service, deck, ctx.party, foes, "seamstress_prick", 1,
				[_hit(1, 3, 2, 1, {"bleed": 3})], 1, mode + ": ordinary Prick")
			_accept(service, deck, ctx.party, foes, "tinker_pop_shot", 2,
				[_hit(2, 8, 0, 8)], 1, mode + ": ordinary first Pop Shot")
			_check(foes.get_enemy(1).statuses == {"bleed": 3}
				and foes.get_enemy(2).get("statuses", {}) == {}
				and service._patches.latch_snapshot() == latch,
				mode + ": no invented attack-patch status or latch power")
			_check([ctx.wardrobe.get_snapshot(), ctx.torn.read_state()] == ledger_before
				and ctx.wardrobe.get_snapshot().seed == 920151,
				mode + ": combat preserves complete run ledgers and seed")
			replays.append([_snapshot(deck, ctx.party, foes),
				service._patches.active_snapshot(), service._patches.latch_snapshot(),
				service._tinker._consumed, ctx.wardrobe.get_snapshot(), ctx.torn.read_state()])
		_check(replays[0] == replays[1], mode + ": independent seeded bound attacks replay all state")


func _test_malformed_patch_wardrobes() -> void:
	for id in ["button_eye", "pincushion_arm"]:
		for fault in ["missing_owned", "wrong_slot", "wrong_slot_unowned",
				"forged_absent", "forged_owned", "duplicate"]:
			var ctx := _shop_coat_context("shop")
			var w: RunPatchWardrobe = ctx.wardrobe
			var slot: String = CombatPatchAttackRules.EFFECTS[id].slot
			if fault not in ["forged_absent", "wrong_slot_unowned"]:
				w._owned.append(id)
			if fault in ["wrong_slot", "wrong_slot_unowned"]:
				w._definitions[id] = "COAT"
			elif fault == "forged_owned":
				w._definitions[id] = slot
				w._worn.tinker.COAT = id
			elif fault == "duplicate":
				w._definitions[id] = slot
				w._worn.warden[slot] = id
				w._worn.tinker[slot] = id
			elif fault == "forged_absent":
				w._worn.tinker[slot] = id
			_check(w.is_valid() and ctx.torn.is_valid(), "otherwise valid malformed ledger fixture")
			var service := CombatAttackCards.new()
			var deck := _deck(["warden_strike"])
			var foes := _enemies([30])
			var before := [_snapshot(deck, ctx.party, foes), w.get_snapshot(), ctx.torn.read_state()]
			seed(9981)
			var next_global := randi()
			seed(9981)
			_check(not service.bind_patch_wardrobe(w, ctx.torn) and not service._patches.is_valid(),
				id + " " + fault + ": malformed binding fails closed")
			_check([_snapshot(deck, ctx.party, foes), w.get_snapshot(), ctx.torn.read_state()] == before
				and randi() == next_global, "failed binding preserves all models and RNG")
			_patch_reject(service, deck, ctx.party, foes, "warden_strike", 1, ctx,
				id + " " + fault + ": failed bind cannot attack or spend")


func _patch_context(assignments: Array, scraps: int = 4) -> Dictionary:

	var heroes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))

	_check(heroes is Array and heroes.size() == 3, "real starter party JSON exists")

	var party_defs := []

	for hero in heroes:

		party_defs.append({"id": hero.id, "max_hp": int(hero.max_hp)})

	var party := CombatParty.new(party_defs)

	_check(party.is_valid() and party.get_hero(1).id == "warden"

		and party.get_hero(2).id == "seamstress" and party.get_hero(3).id == "tinker",

		"real hero party identities and slots")

	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(

		"res://data/patches/m04_attack_patches.json"))

	_check(records is Array and records.size() == 2, "own attack patch catalog parses")

	for id in ["button_eye", "pincushion_arm"]:

		var matching: Array = records.filter(func(record): return record.get("id") == id)

		_check(matching.size() == 1, "own M04 ID exists " + id)

		if matching.size() == 1:

			_check(matching[0].slot == ("HEAD" if id == "button_eye" else "ARM")

				and matching[0].effect == ("first_attack_exposed" if id == "button_eye"

					else "card_attack_bonus") and matching[0].amount == 1,

				"own M04 slot, power and amount " + id)

	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(

		"res://data/patches/initial_patch_slots.json"))

	for id in ["stitched_badge", "spare_spool"]:

		_check(old.any(func(record): return record.get("id") == id),

			"old Shop patch ID remains " + id)

	var definitions := []

	for record in records:

		definitions.append({"id": record.id, "slot": record.slot})

	definitions.append_array(old)

	var torn := RunTornMending.new(party.get_heroes())

	var wardrobe := RunPatchWardrobe.new(party.get_heroes(),

		["button_eye", "pincushion_arm", "stitched_badge", "spare_spool"],

		definitions, scraps)

	_check(torn.is_valid() and wardrobe.is_valid(), "real wardrobe and torn state are valid")

	for assignment in assignments:

		var result := wardrobe.sew(assignment.id, assignment.hero, assignment.slot,

			"sew_" + assignment.id, wardrobe.get_snapshot())

		_check(result.ok and result.receipt.hero_id == assignment.hero,

			"real legal sewing assigns " + assignment.id)

	return {"party": party, "wardrobe": wardrobe, "torn": torn}





func _patch_service(context: Dictionary) -> CombatAttackCards:

	var service := CombatAttackCards.new()

	_check(service.bind_patch_wardrobe(context.wardrobe, context.torn)

		and service._patches.is_valid(), "battle binds genuine wearer projection")

	var projection: Dictionary = context.wardrobe.project_active(context.torn.read_state())

	_check(service._patches.active_snapshot() == projection.active

		and service._patches.latch_snapshot() == {

			"warden": false, "seamstress": false, "tinker": false},

		"binding freezes the genuine detached active roster and fresh combat latch")

	return service





func _test_patch_bound_attacks() -> void:

	var ctx := _patch_context([

		{"id": "button_eye", "hero": "warden", "slot": "HEAD"},

		{"id": "pincushion_arm", "hero": "seamstress", "slot": "ARM"}])

	var service := _patch_service(ctx)

	var copy := service._patches.active_snapshot()

	copy.warden.clear()

	_check(service._patches.active_snapshot().warden == ["button_eye"],

		"projected wearer snapshot is detached from returned copy")

	var deck := _deck(["warden_strike", "warden_strike", "seamstress_prick"])

	var foes := _enemies([60, 60, 60])

	_check(foes.gain_block(3, 2), "real block before ARM Prick")

	_accept(service, deck, ctx.party, foes, "seamstress_prick", 3,

		[_hit(3, 4, 2, 2, {"bleed": 3})], 1, "ARM Prick: damage 4, Bleed 3")

	_check(not service._patches.latch_snapshot().warden,

		"Seamstress action does not spend Warden's HEAD latch")

	_accept(service, deck, ctx.party, foes, "warden_strike", 1,

		[_hit(1, 6, 0, 6, {"exposed": 1})], 1, "first Strike does not amplify itself")

	_accept(service, deck, ctx.party, foes, "warden_strike", 1,

		[_hit(1, 9, 0, 9)], 1, "second Strike uses prior Exposed +50%")

	_check(foes.get_enemy(1).statuses == {"exposed": 1}

		and foes.get_enemy(3).statuses == {"bleed": 3},

		"Exposed and Bleed counters persist independently")

	_check(CombatStatuses.new().end_owner_turn(10, 7, {"bleed": 3})

		== {"ok": true, "hp": 7, "block": 7, "statuses": {"bleed": 2}, "bleed_hp_loss": 3},

		"ARM never modifies direct Bleed or Block bypass")

	service.start_player_turn()

	_check(service._patches.latch_snapshot().warden,

		"turn reset does not restore Button Eye")

	var fresh := _patch_service(ctx)

	var bash := _deck(["warden_shield_bash", "warden_strike"])

	var enemies := _enemies([60])

	_accept(fresh, bash, ctx.party, enemies, "warden_shield_bash", 1,

		[_hit(1, 8, 0, 8, {"weak": 1, "exposed": 1})], 2,

		"fresh first Shield Bash merges Weak and Exposed")

	_accept(fresh, bash, ctx.party, enemies, "warden_strike", 1,

		[_hit(1, 9, 0, 9)], 1, "later Strike keeps Weak and Exposed counters")

	_check(enemies.get_enemy(1).statuses == {"weak": 1, "exposed": 1},

		"Button Eye only adds Exposed once this combat")

	var unbound := _patch_context([])

	_accept(_patch_service(unbound), _deck(["warden_strike"]), unbound.party,

		_enemies([30]), "warden_strike", 1, [_hit(1, 6, 0, 6)], 1,

		"not wearing a patch means no attack bonus")





## Validate all actors, RNG, patch latch and run ledgers for every refusal.

func _patch_reject(service: CombatAttackCards, deck: CombatDeck, party: CombatParty,

		foes: CombatEnemies, id: String, target: int, ctx: Dictionary, label: String,

		owner_statuses: Dictionary = {}, target_statuses: Dictionary = {}) -> void:

	var before := _snapshot(deck, party, foes)

	var patch_before := [service._patches.active_snapshot(), service._patches.latch_snapshot()]

	var ledger_before := [ctx.wardrobe.get_snapshot(), ctx.torn.read_state()]

	seed(88712)

	var next_global := randi()

	seed(88712)

	var forecast := service.forecast_attack(deck, party, foes, id, owner_statuses, target_statuses)

	_check(not forecast.playable or (forecast.requires_selection and target == 0)

		or (not forecast.requires_selection and target != 0)

		or (forecast.requires_selection and not forecast.hits.any(

			func(hit): return hit.position == target)),

		label + ": forecast cannot authorize invalid selection")

	_check(service.play_attack(deck, party, foes, id, target,

		owner_statuses, target_statuses) == {"ok": false, "hits": []},

		label + ": attempt rejects")

	_check(_snapshot(deck, party, foes) == before

		and [service._patches.active_snapshot(), service._patches.latch_snapshot()] == patch_before

		and [ctx.wardrobe.get_snapshot(), ctx.torn.read_state()] == ledger_before

		and randi() == next_global, label + ": no deck/actor/RNG/latch/ledger mutation")





func _test_patch_bomb_and_status_overflow() -> void:

	var ctx := _patch_context([

		{"id": "button_eye", "hero": "tinker", "slot": "HEAD"},

		{"id": "pincushion_arm", "hero": "tinker", "slot": "ARM"}])

	var service := _patch_service(ctx)

	_accept(service, _deck(["tinker_pop_shot"]), ctx.party, _enemies([40]),

		"tinker_pop_shot", 1, [_hit(1, 9, 0, 9, {"exposed": 1})], 1,

		"Tinker Pop Shot 5+3+1 and first HEAD Exposed")

	_check(service._patches.latch_snapshot().tinker,

		"Pop Shot consumes Tinker's battle HEAD latch")

	var bomb := _patch_service(ctx)

	var foes := _enemies([40, 40, 40])

	_check(foes.apply_damage(2, 40) and foes.is_slain(2),

		"middle Bomb recipient truly slain")

	_seed_modifiers(ctx.party, foes, "tinker_scrap_bomb", {"weak": 1},

		{1: {"exposed": 1}})

	# Base 8; Weak+Exposed gives 9 at position 1; only Weak gives 6 at 3.

	_accept(bomb, _deck(["tinker_scrap_bomb"]), ctx.party, foes,

		"tinker_scrap_bomb", 0,

		[_hit(1, 9, 0, 9, {"exposed": 1}), _hit(3, 6, 0, 6, {"exposed": 1})],

		2, "first Bomb: living slots, Weak/Exposed one floor, late new Exposed",

		{"weak": 1}, {1: {"exposed": 1}})

	_check(foes.get_enemy(1).statuses == {"exposed": 2}

		and foes.get_enemy(2).get("statuses", {}).is_empty()

		and foes.get_enemy(3).statuses == {"exposed": 1},

		"Bomb effects do not touch dead slot and add after preexisting counters")

	# Clear the deliberate Weak fixture before unmodified Bombs.
	ctx.party._heroes[2]["statuses"] = {}
	bomb.start_player_turn()

	_check(bomb._patches.latch_snapshot().tinker and not bomb._tinker._consumed,

		"new turn restores +3 but never first-combat Exposed")

	_accept(_patch_service(ctx), _deck(["tinker_scrap_bomb"]), ctx.party,

		_enemies([40, 40]), "tinker_scrap_bomb", 0,

		[_hit(1, 8, 0, 8, {"exposed": 1}),

			_hit(2, 8, 0, 8, {"exposed": 1})], 2,

		"first unmodified Bomb deals 8 to each living target")

	var guard := _patch_service(ctx)

	var guarded_deck := _deck(["tinker_scrap_bomb"])

	var guarded_foes := _enemies([40, 40])

	guarded_foes._enemies[1]["statuses"] = {"exposed": CombatEnemies.MAX_INT}

	_patch_reject(guard, guarded_deck, ctx.party, guarded_foes,

		"tinker_scrap_bomb", 0, ctx, "late HEAD status overflow")

	guarded_foes._enemies[1]["statuses"] = {}

	_accept(guard, guarded_deck, ctx.party, guarded_foes, "tinker_scrap_bomb", 0,

		[_hit(1, 8, 0, 8, {"exposed": 1}),

			_hit(2, 8, 0, 8, {"exposed": 1})], 2,

		"valid Bomb after overflow still has first HEAD effect")





func _test_patch_torn_mend_and_transfer() -> void:

	var ctx := _patch_context([

		{"id": "pincushion_arm", "hero": "seamstress", "slot": "ARM"},

		{"id": "button_eye", "hero": "warden", "slot": "HEAD"}])

	var prior := _patch_service(ctx)

	var battle_start: Array = ctx.torn.read_state().heroes

	var battle_end := battle_start.duplicate(true)

	battle_end[1]["hp"] = 0

	_check(ctx.torn.observe_battle_end("tear_01", battle_start, battle_end).ok,

		"real torn service observes downed Seamstress")

	var masked: Dictionary = ctx.wardrobe.project_active(ctx.torn.read_state())

	_check(masked.ok and masked.worn.seamstress.ARM == "pincushion_arm"

		and masked.active.seamstress.is_empty(),

		"downed wearer retains sewn patch but activation is masked")

	_check(prior._patches.damage_bonus("seamstress") == 1,

		"earlier battle snapshot remains detached from subsequent tear")

	var torn_combat := _patch_service(ctx)

	_check(torn_combat._patches.damage_bonus("seamstress") == 0,

		"downed owner gets no ARM power in fresh combat")

	var down_party := _party()

	_check(down_party.apply_damage(2, 999), "actual party has downed owner")

	_patch_reject(torn_combat, _deck(["seamstress_prick"]), down_party,

		_enemies([30]), "seamstress_prick", 1, ctx, "downed patched attack")

	var state: Dictionary = ctx.torn.read_state()

	var mend: Dictionary = ctx.torn.choose_mend("mend_node", "mend_receipt", "seamstress", 2,

		2, state.heroes, true)

	_check(mend.ok and mend.remaining_scraps == 0

		and mend.heroes[1].max_hp == 27 and mend.heroes[1].hp == 6,

		"real two-scrap map mend revives at floor 25 percent of reduced max HP")

	var healed := _patch_service(ctx)

	_check(healed._patches.damage_bonus("seamstress") == 1,

		"revival unlocks ARM on a separately bound battle")

	_accept(healed, _deck(["seamstress_prick"]), ctx.party, _enemies([30]),

		"seamstress_prick", 1, [_hit(1, 4, 0, 4, {"bleed": 3})], 1,

		"map-mended wearer deals ARM bonus damage")

	_check(ctx.wardrobe.start_rest("rest_move", ctx.wardrobe.get_snapshot()).ok,

		"real Rest context opens")

	var moved: Dictionary = ctx.wardrobe.re_sew("pincushion_arm", "seamstress", "tinker",

		"rest_move", "move_arm", ctx.wardrobe.get_snapshot())

	_check(moved.ok and moved.receipt.scrap_delta == -1

		and ctx.wardrobe.get_snapshot().worn.tinker.ARM == "pincushion_arm",

		"paid Rest re-sew moves ARM to Tinker")

	_check(ctx.wardrobe.end_rest("rest_move", ctx.wardrobe.get_snapshot()).ok,

		"real Rest closes")

	_check(healed._patches.damage_bonus("seamstress") == 1

		and healed._patches.damage_bonus("tinker") == 0,

		"earlier combat cannot steal ARM after transfer")

	var renewed := _patch_service(ctx)

	_check(renewed._patches.damage_bonus("seamstress") == 0

		and renewed._patches.damage_bonus("tinker") == 1,

		"new combat recognizes only ARM's current wearer")

	_accept(renewed, _deck(["tinker_pop_shot"]), ctx.party, _enemies([30]),

		"tinker_pop_shot", 1, [_hit(1, 9, 0, 9)], 1,

		"transferred ARM adds +1 to Tinker's initial Pop Shot")





func _test_patch_rejections_and_replay() -> void:

	var ctx := _patch_context([{"id": "button_eye", "hero": "warden", "slot": "HEAD"}])

	var service := _patch_service(ctx)

	var deck := _deck(["warden_strike", "warden_strike"])

	var foes := _enemies([60, 60, 60])

	_patch_reject(service, deck, ctx.party, foes, "warden_strike", 3, ctx, "wrong target")

	_patch_reject(service, deck, ctx.party, foes, "warden_strike", 0, ctx, "no selection")

	_patch_reject(service, deck, ctx.party, foes, "warden_strike", 1, ctx,

		"malformed owner status", {"weak": -1})

	_patch_reject(service, deck, ctx.party, foes, "warden_strike", 1, ctx,

		"malformed late target status", {}, {3: {"exposed": -1}})

	var exhausted := _deck(["warden_strike"])

	_check(exhausted.try_spend_energy(3), "no-energy precondition")

	_patch_reject(service, exhausted, ctx.party, foes, "warden_strike", 1,

		ctx, "unaffordable")

	var unheld := _deck(["warden_strike"])

	_check(unheld.discard_played("warden_strike") and not unheld.hand.has("warden_strike"),

		"unheld patch attack precondition")

	_patch_reject(service, unheld, ctx.party, foes, "warden_strike", 1, ctx, "unheld")

	var slain := _enemies([12])

	_check(slain.apply_damage(1, 12), "slain target precondition")

	_patch_reject(service, deck, ctx.party, slain, "warden_strike", 1, ctx, "slain")

	_patch_reject(service, _deck(["warden_strike"]),

		_party(["seamstress", "tinker", "warden"]), foes, "warden_strike", 1,

		ctx, "invalid Warden position")

	var malformed := _enemies([30, 30, 30])

	malformed._enemies[2]["statuses"] = {"weak": -1}

	_patch_reject(service, deck, ctx.party, malformed, "warden_strike", 1,

		ctx, "malformed authoritative enemy status")

	_accept(service, deck, ctx.party, foes, "warden_strike", 1,

		[_hit(1, 6, 0, 6, {"exposed": 1})], 1,

		"first valid hit after all rejections still triggers Button Eye")

	var shop := _patch_context([{"id": "stitched_badge", "hero": "warden", "slot": "HEAD"}])

	_accept(_patch_service(shop), _deck(["warden_strike"]), shop.party,

		_enemies([30]), "warden_strike", 1, [_hit(1, 6, 0, 6)], 1,

		"old sewn Shop HEAD ID never gains invented M04 power")

	var invalid := RunPatchWardrobe.new(ctx.party.get_heroes(),

		["button_eye", "pincushion_arm"],

		[{"id": "button_eye", "slot": "ARM"},

			{"id": "pincushion_arm", "slot": "HEAD"}], 4)

	_check(invalid.is_valid(), "forged swapped-slot ledger otherwise valid")

	var failed := CombatAttackCards.new()

	_check(not failed.bind_patch_wardrobe(invalid, ctx.torn)

		and not failed._patches.is_valid(),

		"wrong authored patch slots fail closed before granting powers")

	_reject(failed, _deck(["warden_strike"]), ctx.party, _enemies([30]),

		"warden_strike", 1, "invalid attempted binding cannot fall back to unbound")

	var a := _patch_service(ctx)

	var b := _patch_service(ctx)

	var da := _deck(["warden_strike", "warden_strike"], 9271)

	var db := _deck(["warden_strike", "warden_strike"], 9271)

	var ea := _enemies([60])

	var eb := _enemies([60])

	var events_a := [a.play_attack(da, ctx.party, ea, "warden_strike", 1),

		a.play_attack(da, ctx.party, ea, "warden_strike", 1)]

	var events_b := [b.play_attack(db, ctx.party, eb, "warden_strike", 1),

		b.play_attack(db, ctx.party, eb, "warden_strike", 1)]

	_check(events_a == events_b and events_a == [

		{"ok": true, "hits": [_hit(1, 6, 0, 6, {"exposed": 1})]},

		{"ok": true, "hits": [_hit(1, 9, 0, 9)]}]

		and _snapshot(da, ctx.party, ea) == _snapshot(db, ctx.party, eb)

		and a._patches.latch_snapshot() == b._patches.latch_snapshot(),

		"identical seeded real decks, events and patch latches replay exactly")


## Authentic M05 metadata and sew receipts; never fabricate an active modifier.
func _head_context(assignments: Array) -> Dictionary:
	var party := _party()
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_head_patches.json"))
	_check(records is Array, "authored HEAD catalog exists")
	if not records is Array:
		return {}
	var expected := {
		"stern_seam_cap": {"slot": "HEAD", "effect": "card_weak_bonus", "amount": 1},
		"bloodstitch_bonnet": {"slot": "HEAD", "effect": "card_bleed_bonus", "amount": 1},
		"button_glass_visor": {"slot": "HEAD", "effect": "card_exposed_bonus", "amount": 1},
		"reinforced_browband": {"slot": "HEAD", "effect": "card_block_bonus", "amount": 2},
	}
	var defs := []
	for id in expected:
		var matches: Array = records.filter(func(record): return record is Dictionary and record.get("id") == id)
		_check(matches.size() == 1 and matches[0].get("slot") == expected[id].slot
			and matches[0].get("effect") == expected[id].effect
			and matches[0].get("amount") == expected[id].amount,
			"required M05 HEAD ID/slot/effect/amount: " + id)
		if matches.size() != 1:
			return {}
		defs.append({"id": id, "slot": "HEAD"})
	var worn := []
	for id in expected:
		worn.append(id)
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), worn, defs, 4)
	_check(torn.is_valid() and wardrobe.is_valid(), "M05 real wearer and torn authorities")
	for assigned in assignments:
		var sewn := wardrobe.sew(assigned.id, assigned.hero, "HEAD",
			"head_" + assigned.id, wardrobe.get_snapshot())
		_check(sewn.get("ok", false) and sewn.receipt.patch_id == assigned.id
			and sewn.receipt.hero_id == assigned.hero and sewn.receipt.slot == "HEAD",
			"authentic unique M05 HEAD sew receipt")
	return {"party": party, "torn": torn, "wardrobe": wardrobe}


func _head_service(ctx: Dictionary) -> CombatAttackCards:
	var attacks := CombatAttackCards.new()
	var heads := CombatM05HeadPatchRules.new()
	_check(heads.bind_wardrobe(ctx.wardrobe, ctx.torn)
		and heads.read_projection().ok, "M05 binds genuine current HEAD projection")
	_check(attacks.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
		and attacks.bind_head_patch_rules(heads), "attack resolver shares HEAD authority")
	_check(attacks._head_rules == heads and heads.read_projection().heads.size() == 3,
		"one read-only wearer HEAD authority for all owners")
	return attacks


func _head_reject(attacks: CombatAttackCards, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, id: String, target: int, ctx: Dictionary,
		label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var heads_before := attacks._head_rules.read_projection()
	var wardrobe_before: Dictionary = ctx.wardrobe.get_snapshot()
	var torn_before: Dictionary = ctx.torn.read_state()
	_reject(attacks, deck, party, enemies, id, target, label)
	_check(_snapshot(deck, party, enemies) == before
		and attacks._head_rules.read_projection() == heads_before
		and ctx.wardrobe.get_snapshot() == wardrobe_before
		and ctx.torn.read_state() == torn_before,
		label + ": HEAD projection, both ledgers and run RNG stay unchanged")


func _test_m05_head_statuses() -> void:
	var ctx := _head_context([
		{"id": "stern_seam_cap", "hero": "warden"},
		{"id": "bloodstitch_bonnet", "hero": "seamstress"}])
	if ctx.is_empty():
		return
	var attacks := _head_service(ctx)
	var heads: Dictionary = attacks._head_rules.read_projection().heads
	_check(heads.warden.patch_id == "stern_seam_cap"
		and heads.seamstress.patch_id == "bloodstitch_bonnet"
		and heads.tinker.is_empty(), "independent wearer-specific HEAD projections")
	var deck := _deck(["warden_shield_bash", "seamstress_prick"])
	var foes := _enemies([60, 60, 60])
	_check(foes.gain_block(1, 3), "patched Shield Bash hits genuine enemy Block")
	_accept(attacks, deck, ctx.party, foes, "warden_shield_bash", 1,
		[_hit(1, 8, 3, 5, {"weak": 2})], 2,
		"real sewn Stern Seam Cap: eight damage, Weak 2 at enemy one")
	_accept(attacks, deck, ctx.party, foes, "seamstress_prick", 2,
		[_hit(2, 3, 0, 3, {"bleed": 4})], 1,
		"real sewn Bloodstitch Bonnet: three damage, Bleed 4 at enemy two")
	_check(foes.get_enemy(1).statuses == {"weak": 2}
		and foes.get_enemy(2).statuses == {"bleed": 4}
		and foes.get_enemy(3).get("statuses", {}).is_empty() and deck.energy == 0,
		"exact separated status destinations and one three-energy turn")
	_check(CombatStatuses.new().end_owner_turn(20, 0, {"bleed": 4})
		== {"ok": true, "hp": 16, "block": 0,
			"statuses": {"bleed": 3}, "bleed_hp_loss": 4},
		"normal bleed lifecycle remains untouched")
	_check(attacks._head_rules.read_projection().heads == heads,
		"confirmed casts never change wearer receipt/projection")
	var none := _head_context([])
	if none.is_empty():
		return
	var plain := _head_service(none)
	_accept(plain, _deck(["warden_shield_bash"]), none.party, _enemies([40]),
		"warden_shield_bash", 1, [_hit(1, 8, 0, 8, {"weak": 1})], 2,
		"valid unworn HEAD returns authored Weak 1")
	_accept(plain, _deck(["seamstress_prick"]), none.party, _enemies([40, 40]),
		"seamstress_prick", 2, [_hit(2, 3, 0, 3, {"bleed": 3})], 1,
		"valid unworn HEAD returns passive Bleed 3")
	_accept(CombatAttackCards.new(), _deck(["warden_shield_bash"]), _party(),
		_enemies([40]), "warden_shield_bash", 1,
		[_hit(1, 8, 0, 8, {"weak": 1})], 2,
		"untouched unbound legacy starter attack still resolves")


func _test_m05_head_rejections() -> void:
	var wrong := _head_context([
		{"id": "stern_seam_cap", "hero": "seamstress"},
		{"id": "bloodstitch_bonnet", "hero": "warden"}])
	if wrong.is_empty():
		return
	var wrong_attacks := _head_service(wrong)
	_accept(wrong_attacks, _deck(["warden_shield_bash"]), wrong.party, _enemies([40]),
		"warden_shield_bash", 1, [_hit(1, 8, 0, 8, {"weak": 1})], 2,
		"foreign Stern cap cannot grant Warden Weak")
	_accept(wrong_attacks, _deck(["seamstress_prick"]), wrong.party, _enemies([40, 40]),
		"seamstress_prick", 2, [_hit(2, 3, 0, 3, {"bleed": 3})], 1,
		"foreign Bloodstitch cannot grant Seamstress Bleed")
	_check(not wrong.wardrobe.sew("button_glass_visor", "warden", "ARM",
		"forged_arm", wrong.wardrobe.get_snapshot()).ok,
		"HEAD metadata rejects wrong-slot sew without ledger write")
	var ctx := _head_context([
		{"id": "stern_seam_cap", "hero": "warden"},
		{"id": "bloodstitch_bonnet", "hero": "seamstress"}])
	if ctx.is_empty():
		return
	var attacks := _head_service(ctx)
	_accept(attacks, _deck(["warden_strike"]), ctx.party, _enemies([40]),
		"warden_strike", 1, [_hit(1, 6, 0, 6)], 1,
		"unrelated positive-damage starter attack never inherits status")
	_head_reject(attacks, _deck(["warden_shield_bash"]), ctx.party, _enemies([40]),
		"warden_shield_bash", 2, ctx, "illegal enemy TO with sewn HEAD")
	_head_reject(attacks, _deck(["seamstress_prick"]), ctx.party, _enemies([40]),
		"seamstress_prick", 3, ctx, "missing enemy slot with sewn HEAD")
	var empty := _deck(["warden_shield_bash"])
	_check(empty.try_spend_energy(2), "real energy pre-spent before refusal")
	_head_reject(attacks, empty, ctx.party, _enemies([40]),
		"warden_shield_bash", 1, ctx, "insufficient energy with sewn HEAD")
	var overflow := _enemies([40])
	overflow._enemies[0]["statuses"] = {"weak": CombatStatuses.MAX_INT}
	_head_reject(attacks, _deck(["warden_shield_bash"]), ctx.party, overflow,
		"warden_shield_bash", 1, ctx, "HEAD Weak status capacity preflight")
	var downed := _party()
	_check(downed.apply_damage(2, 9999) and downed.is_downed(2),
		"owner truly downed in battle")
	_head_reject(attacks, _deck(["seamstress_prick"]), downed, _enemies([40]),
		"seamstress_prick", 1, ctx, "downed HEAD wearer cannot cast")
	var back := _party(["seamstress", "tinker", "warden"])
	_head_reject(attacks, _deck(["warden_shield_bash"]), back, _enemies([40]),
		"warden_shield_bash", 1, ctx, "illegal owner FROM for worn Bash")
	var stale_deck := _deck(["warden_shield_bash"])
	var stale: Dictionary = ctx.wardrobe.sew("reinforced_browband", "tinker", "HEAD",
		"later_authentic_sew", ctx.wardrobe.get_snapshot())
	_check(stale.ok and not attacks._head_rules.read_projection().ok,
		"new authentic sew invalidates battle-start HEAD authority")
	_head_reject(attacks, stale_deck, ctx.party, _enemies([40]),
		"warden_shield_bash", 1, ctx, "stale current-run HEAD receipt fails closed")
	var invalid := CombatM05HeadPatchRules.new()
	_check(not invalid.bind_wardrobe(null, null), "malformed HEAD bind rejected")
	var malformed := CombatAttackCards.new()
	_check(not malformed.bind_head_patch_rules(invalid),
		"present invalid HEAD authority retained as a rejection")
	_reject(malformed, _deck(["warden_shield_bash"]), _party(), _enemies([40]),
		"warden_shield_bash", 1, "malformed HEAD never falls back to baseline")
	var fresh := _head_context([{"id": "bloodstitch_bonnet", "hero": "seamstress"}])
	if fresh.is_empty():
		return
	var prior: Array = fresh.torn.read_state().heroes
	var ended: Array = prior.duplicate(true)
	ended[1]["hp"] = 0
	_check(fresh.torn.observe_battle_end("genuine_torn_fight", prior, ended).ok,
		"real battle-end observation tears Seamstress")
	var previous: Dictionary = fresh.wardrobe.get_snapshot()
	var torn_roster: Array = fresh.torn.read_state().heroes
	_check(fresh.wardrobe.refresh_run_context(torn_roster, previous.owned,
		previous.scraps, previous.gold, previous.cards, previous),
		"persistent wardrobe refreshes to true torn roster")
	var torn_attacks := _head_service(fresh)
	_check(torn_attacks._head_rules.read_projection().heads.seamstress.is_empty(),
		"torn wearer has no projected HEAD power")
	# A fresh CombatParty can be full-HP before carryover replays torn state.
	_head_reject(torn_attacks, _deck(["seamstress_prick"]), _party(), _enemies([40]),
		"seamstress_prick", 1, fresh,
		"positive fresh combat HP cannot bypass torn run owner")
