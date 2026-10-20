extends SceneTree

const ATTACK_IDS := [
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_contract_and_five_attacks()
	_test_modifier_math_and_first_attack()
	_test_bomb_roster_shapes()
	_test_rejection_and_atomicity()
	_test_seeded_replay()
	for failure in failures:
		printerr(failure)
	print("combat_attack_cards_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


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
		_accept(CombatAttackCards.new(), strike_deck, _party(), strike_enemies,
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
		[_hit(1, 7, 0, 7), _hit(2, 7, 0, 7), _hit(3, 7, 0, 7)],
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
		_accept(s, d, _party(), f, "tinker_pop_shot", 1,
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
