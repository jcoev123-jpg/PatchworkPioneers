extends SceneTree

const ATTACK_IDS := [
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_enrage_starter_hits()
	_test_enrage_bomb_and_replay()
	_test_enrage_rejections()
	_test_enrage_zero_damage()
	_test_strike_plus()
	_test_prick_plus()
	_test_shield_bash_plus()
	_test_thorns_starter_attacks()
	_test_thorns_bomb_and_downed_owner()
	_test_thorns_rejections()
	_test_thorns_seeded_replay()
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
	_test_red_bobbin_cuff()
	_test_one_shot_token_bridge()
	_test_one_shot_token_held_card()
	_test_one_shot_token_bridge_rejections()
	_test_one_shot_token_card_rejections()
	for failure in failures:
		printerr(failure)
	print("combat_attack_cards_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _plus_deck(plus_id: String = "warden_strike_plus") -> CombatDeck:
	var base_id := "warden_strike"
	if plus_id == "warden_shield_bash_plus":
		base_id = "warden_shield_bash"
	elif plus_id == "seamstress_prick_plus":
		base_id = "seamstress_prick"
	var cards := StarterCards.new().get_starting_deck()
	var index := cards.find(base_id)
	var upgraded := RunRestCardUpgrade.new(cards, {base_id: plus_id}).choose_upgrade(index)
	_check(upgraded.ok, "real upgrade transaction supplies attack fixture")
	var rng := RandomNumberGenerator.new()
	rng.seed = 78
	var deck := CombatDeck.new(upgraded.deck, rng)
	_check(deck.start_turn(), "upgraded deck starts real turn")
	while not deck.hand.has(plus_id) and not deck.draw_pile.is_empty():
		deck.draw_extra(1)
	_check(deck.hand.has(plus_id), "actual upgraded copy held")
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



func _test_prick_plus() -> void:
	# AC1: living Seamstress in positions 1, 2, 3 reaches enemies in positions 1, 2, 3
	# Hits deal authored 4 damage and Bleed 4 (printed 3 + Seamstress passive 1).
	for hero_pos in [1, 2, 3]:
		var party_order := ["seamstress", "warden", "tinker"] if hero_pos == 1 else (
			["warden", "seamstress", "tinker"] if hero_pos == 2 else ["warden", "tinker", "seamstress"]
		)
		for target in [1, 2, 3]:
			var enemies := _enemies([20, 20, 20])
			_accept(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), _party(party_order), enemies,
				"seamstress_prick_plus", target, [_hit(target, 4, 0, 4, {"bleed": 4})], 1,
				"Prick+ hero pos %d to target %d" % [hero_pos, target])

	# Hit through Block before HP
	var block_enemies := _enemies([20, 20, 20])
	_check(block_enemies.gain_block(2, 2), "target 2 gains 2 Block")
	_accept(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), _party(), block_enemies,
		"seamstress_prick_plus", 2, [_hit(2, 4, 2, 2, {"bleed": 4})], 1, "Prick+ absorbs 2 Block, 2 HP loss")

	# Full absorption: Block >= 4, 0 HP loss, Bleed 4 still persists
	var heavy_block := _enemies([20, 20, 20])
	_check(heavy_block.gain_block(1, 10), "target 1 gains 10 Block")
	_accept(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), _party(), heavy_block,
		"seamstress_prick_plus", 1, [_hit(1, 4, 4, 0, {"bleed": 4})], 1, "Prick+ full absorption retains Bleed 4")
	_check(heavy_block.get_enemy(1).statuses == {"bleed": 4} and heavy_block.get_enemy(1).block == 6,
		"Prick+ persistent status on blocked target")

	# Repeated hits accumulate Bleed: 4 + 4 = 8
	var multi_deck := _plus_deck("seamstress_prick_plus")
	multi_deck.hand.append("seamstress_prick_plus")
	multi_deck.combat_state.energy = 3
	var multi_service := CombatAttackCards.new()
	var first_hit := multi_service.play_attack(multi_deck, _party(), heavy_block, "seamstress_prick_plus", 1)
	_check(first_hit.ok and heavy_block.get_enemy(1).statuses == {"bleed": 8}, "Prick+ Bleed stacks to 8")
	var tick := CombatStatusTurnBatch.new().tick_side("enemies", heavy_block.get_enemies())
	_check(tick.ok and tick.actors[0].statuses == {"bleed": 7} and tick.actors[0].hp == 12,
		"Bleed loss bypasses Block and decrements by one")

	# Lethal hit clamps HP loss and slays enemy
	var low_hp := _enemies([3, 20, 20])
	_accept(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), _party(), low_hp,
		"seamstress_prick_plus", 1, [_hit(1, 4, 0, 3, {"bleed": 4})], 1, "Prick+ lethal hit clamps HP loss")
	_check(low_hp.is_slain(1) and low_hp.get_enemy(1).statuses == {"bleed": 4},
		"Prick+ lethal hit persists Bleed on slain slot")

	# AC3: Negative/rejection cases
	# Downed Seamstress
	var downed_party := _party()
	_check(downed_party.apply_damage(2, 999) and downed_party.is_downed(2), "down Seamstress")
	_reject(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), downed_party, _enemies(),
		"seamstress_prick_plus", 1, "Prick+ downed Seamstress")

	# Absent Seamstress owner
	var absent_party := _party(["warden", "tinker", "other"])
	_reject(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), absent_party, _enemies(),
		"seamstress_prick_plus", 1, "Prick+ absent Seamstress")

	# Insufficient energy (0 energy)
	var empty_energy := _plus_deck("seamstress_prick_plus")
	_check(empty_energy.try_spend_energy(3), "drain all energy")
	_reject(CombatAttackCards.new(), empty_energy, _party(), _enemies(),
		"seamstress_prick_plus", 1, "Prick+ no energy")

	# Inactive turn
	var inactive_deck := _plus_deck("seamstress_prick_plus")
	_check(inactive_deck.end_turn(), "end turn")
	_reject(CombatAttackCards.new(), inactive_deck, _party(), _enemies(),
		"seamstress_prick_plus", 1, "Prick+ inactive turn")

	# Absent from hand
	var absent_deck := _plus_deck("seamstress_prick_plus")
	_check(absent_deck.discard_played("seamstress_prick_plus"), "discard held card")
	_reject(CombatAttackCards.new(), absent_deck, _party(), _enemies(),
		"seamstress_prick_plus", 1, "Prick+ absent from hand")

	# Illegal target positions: 0, 4, -1
	for bad_target in [0, 4, -1]:
		_reject(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), _party(), _enemies(),
			"seamstress_prick_plus", bad_target, "Prick+ illegal target " + str(bad_target))

	# Slain target
	var slain_enemies := _enemies()
	_check(slain_enemies.apply_damage(1, 999), "slay enemy 1")
	_reject(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), _party(), slain_enemies,
		"seamstress_prick_plus", 1, "Prick+ slain target")

	# Absent enemy slot (roster of 1 enemy, target 2)
	_reject(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), _party(), _enemies([20]),
		"seamstress_prick_plus", 2, "Prick+ absent slot 2")

	# Status overflow rejection
	var overflow_enemies := _enemies([20, 20, 20])
	overflow_enemies._enemies[0]["statuses"] = {"bleed": CombatEnemies.MAX_INT - 2}
	_reject(CombatAttackCards.new(), _plus_deck("seamstress_prick_plus"), _party(), overflow_enemies,
		"seamstress_prick_plus", 1, "Prick+ status overflow")


func _test_shield_bash_plus() -> void:
	# AC2: active real turn with 2+ energy, held warden_shield_bash_plus,
	# living Warden in position 1, living enemy in position 1.
	# Spends 2 energy, deals authored 11 damage and Weak 1.
	_accept(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(), _enemies([30, 30, 30]),
		"warden_shield_bash_plus", 1, [_hit(1, 11, 0, 11, {"weak": 1})], 2, "Shield Bash+ normal hit unblocked")

	# Partial Block absorption: Block 5 -> absorbs 5, HP loss 6, Weak 1
	var block_enemies := _enemies([30, 30, 30])
	_check(block_enemies.gain_block(1, 5), "target 1 gains 5 Block")
	_accept(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(), block_enemies,
		"warden_shield_bash_plus", 1, [_hit(1, 11, 5, 6, {"weak": 1})], 2, "Shield Bash+ partial Block absorption")

	# Full Block absorption: Block 20 -> absorbs 11, HP loss 0, Weak 1
	var heavy_block := _enemies([30, 30, 30])
	_check(heavy_block.gain_block(1, 20), "target 1 gains 20 Block")
	_accept(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(), heavy_block,
		"warden_shield_bash_plus", 1, [_hit(1, 11, 11, 0, {"weak": 1})], 2, "Shield Bash+ full Block absorption retains Weak 1")
	_check(heavy_block.get_enemy(1).statuses == {"weak": 1} and heavy_block.get_enemy(1).block == 9,
		"Shield Bash+ persistent Weak on blocked target")

	# Stacking Weak: consecutive hit adds Weak 1 -> Weak 2
	var multi_deck := _plus_deck("warden_shield_bash_plus")
	multi_deck.hand.append("warden_shield_bash_plus")
	multi_deck.combat_state.energy = 3
	var multi_service := CombatAttackCards.new()
	var first_hit := multi_service.play_attack(multi_deck, _party(), heavy_block, "warden_shield_bash_plus", 1)
	_check(first_hit.ok and heavy_block.get_enemy(1).statuses == {"weak": 2}, "Shield Bash+ Weak stacks to 2")
	var tick := CombatStatusTurnBatch.new().tick_side("enemies", heavy_block.get_enemies())
	_check(tick.ok and tick.actors[0].statuses == {"weak": 1}, "Weak decrements by 1 on turn boundary")

	# Lethal hit clamps HP loss and slays enemy
	var low_hp := _enemies([5, 30, 30])
	_accept(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(), low_hp,
		"warden_shield_bash_plus", 1, [_hit(1, 11, 0, 5, {"weak": 1})], 2, "Shield Bash+ lethal hit clamps HP loss")
	_check(low_hp.is_slain(1) and low_hp.get_enemy(1).statuses == {"weak": 1},
		"Shield Bash+ lethal hit persists Weak on slain slot")

	# Modified damage with Weak/Exposed:
	# Attacker Weak 1: floor(11 * 0.75) = 8
	var weak_party := _party()
	weak_party._heroes[0]["statuses"] = {"weak": 1}
	var weak_foes := _enemies([30, 30, 30])
	_accept(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), weak_party, weak_foes,
		"warden_shield_bash_plus", 1, [_hit(1, 8, 0, 8, {"weak": 1})], 2, "Shield Bash+ with attacker Weak",
		{"weak": 1})

	# AC3: Negative/rejection cases
	# Warden not in position 1: position 2 or 3
	_reject(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(["seamstress", "warden", "tinker"]), _enemies(),
		"warden_shield_bash_plus", 1, "Shield Bash+ Warden in position 2")
	_reject(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(["seamstress", "tinker", "warden"]), _enemies(),
		"warden_shield_bash_plus", 1, "Shield Bash+ Warden in position 3")

	# Downed Warden
	var downed_party := _party()
	_check(downed_party.apply_damage(1, 999) and downed_party.is_downed(1), "down Warden")
	_reject(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), downed_party, _enemies(),
		"warden_shield_bash_plus", 1, "Shield Bash+ downed Warden")

	# Absent Warden owner
	var absent_party := _party(["seamstress", "tinker", "other"])
	_reject(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), absent_party, _enemies(),
		"warden_shield_bash_plus", 1, "Shield Bash+ absent Warden")

	# Insufficient energy (energy = 1, cost = 2)
	var poor_deck := _plus_deck("warden_shield_bash_plus")
	_check(poor_deck.try_spend_energy(2) and poor_deck.energy == 1, "leave 1 energy")
	_reject(CombatAttackCards.new(), poor_deck, _party(), _enemies(),
		"warden_shield_bash_plus", 1, "Shield Bash+ insufficient energy 1")

	# Inactive turn
	var inactive_deck := _plus_deck("warden_shield_bash_plus")
	_check(inactive_deck.end_turn(), "end turn")
	_reject(CombatAttackCards.new(), inactive_deck, _party(), _enemies(),
		"warden_shield_bash_plus", 1, "Shield Bash+ inactive turn")

	# Absent from hand
	var absent_deck := _plus_deck("warden_shield_bash_plus")
	_check(absent_deck.discard_played("warden_shield_bash_plus"), "discard held card")
	_reject(CombatAttackCards.new(), absent_deck, _party(), _enemies(),
		"warden_shield_bash_plus", 1, "Shield Bash+ absent from hand")

	# Illegal target positions: 0, 2, 3, 4
	for bad_target in [0, 2, 3, 4]:
		_reject(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(), _enemies(),
			"warden_shield_bash_plus", bad_target, "Shield Bash+ illegal target " + str(bad_target))

	# Slain target 1
	var slain_enemies := _enemies()
	_check(slain_enemies.apply_damage(1, 999), "slay enemy 1")
	_reject(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(), slain_enemies,
		"warden_shield_bash_plus", 1, "Shield Bash+ slain target 1")

	# Weak overflow on enemy 1
	var overflow_enemies := _enemies([30, 30, 30])
	overflow_enemies._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	_reject(CombatAttackCards.new(), _plus_deck("warden_shield_bash_plus"), _party(), overflow_enemies,
		"warden_shield_bash_plus", 1, "Shield Bash+ Weak overflow")


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

	_check(records is Array, "own attack patch catalog parses; required IDs checked below")

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


## AC3: a rejected patched Prick must leave the deck, the party, the enemy
## roster, both run ledgers, the bound ARM authority, its patch latch and the
## seeded run RNG exactly as they were before the attempt.
func _arm_reject(attacks: CombatAttackCards, wardrobe: Variant, torn: RunTornMending,
		deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, target: int,
		label: String) -> void:
	var deck_before := _snapshot(deck, party, enemies)
	var seed_before: int = deck._rng.seed
	var state_before: int = deck._rng.state
	var wardrobe_before: Variant = null if wardrobe == null else wardrobe.get_snapshot()
	var torn_before: Dictionary = torn.read_state()
	var active_before: Dictionary = attacks._patches.active_snapshot()
	var worn_before: Dictionary = attacks._patches.worn_snapshot()
	var latch_before: Dictionary = attacks._patches.latch_snapshot()
	_reject(attacks, deck, party, enemies, "seamstress_prick", target, label)
	_check(_snapshot(deck, party, enemies) == deck_before,
		label + ": deck, party and enemy rosters unchanged")
	_check(deck._rng.seed == seed_before and deck._rng.state == state_before,
		label + ": seeded run RNG unchanged")
	var wardrobe_after: Variant = null if wardrobe == null else wardrobe.get_snapshot()
	_check(wardrobe_after == wardrobe_before and torn.read_state() == torn_before,
		label + ": wardrobe and torn ledgers unchanged")
	_check(attacks._patches.active_snapshot() == active_before
		and attacks._patches.worn_snapshot() == worn_before
		and attacks._patches.latch_snapshot() == latch_before,
		label + ": bound ARM authority and patch latch unchanged")


## M05 Red Bobbin Cuff is a living wearer's ARM patch: it adds one Bleed to that
## Seamstress's own confirmed Prick, never to a foreign wearer, a stale battle
## start or a malformed binding. Every fixture is a shipped catalog record.
func _test_red_bobbin_cuff() -> void:
	var arm_records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_arm_support_patches.json"))
	var head_records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_head_patches.json"))
	_check(arm_records is Array and head_records is Array,
		"authored M05 ARM and HEAD catalogs exist")
	if not (arm_records is Array and head_records is Array):
		return
	var cuff := {}
	for record in arm_records:
		if record is Dictionary and record.get("id") == "red_bobbin_cuff":
			cuff = record
	_check(cuff.get("slot") == "ARM" and cuff.get("effect") == "card_bleed_bonus"
		and cuff.get("amount") == 1,
		"shipped Red Bobbin Cuff is an ARM +1 card_bleed_bonus record")
	var defs := []
	for record in arm_records + head_records:
		if record is Dictionary and record.has("id") and record.has("slot"):
			defs.append({"id": record["id"], "slot": record["slot"]})
	var owned := ["red_bobbin_cuff", "bloodstitch_bonnet"]
	var party := _party()
	var torn := RunTornMending.new(party.get_heroes())
	_check(torn.is_valid(), "genuine run torn ledger for the living starter roster")

	# AC2: the HEAD Bonnet and the ARM Cuff coexist and stack exactly once.
	var both := RunPatchWardrobe.new(party.get_heroes(), owned, defs, 4)
	var sew_arm: Dictionary = both.sew("red_bobbin_cuff", "seamstress", "ARM",
		"both_arm", both.get_snapshot())
	var sew_head: Dictionary = both.sew("bloodstitch_bonnet", "seamstress", "HEAD",
		"both_head", both.get_snapshot())
	_check(sew_arm.get("ok", false) and sew_head.get("ok", false),
		"authentic ARM and HEAD sew receipts on the same Seamstress")
	var both_attacks := CombatAttackCards.new()
	var heads := CombatM05HeadPatchRules.new()
	_check(both_attacks.bind_patch_wardrobe(both, torn)
		and heads.bind_wardrobe(both, torn) and both_attacks.bind_head_patch_rules(heads),
		"one Seamstress wears a real cuff and bonnet in distinct slots")
	var both_foes := _enemies([60, 60, 60])
	_accept(both_attacks, _deck(["seamstress_prick"]), party, both_foes, "seamstress_prick", 1,
		[_hit(1, 3, 0, 3, {"bleed": 5})], 1,
		"printed Bleed 2, passive 1, HEAD 1 and ARM 1 stack to Bleed 5 once")
	_check(both_foes.get_enemy(1).get("statuses", {}) == {"bleed": 5},
		"one confirmed stacked Prick leaves exactly Bleed 5")

	# AC1: a genuine ARM-only cuff adds its one Bleed to the committed Prick.
	var arm_only := RunPatchWardrobe.new(party.get_heroes(), owned, defs, 4)
	_check(arm_only.sew("red_bobbin_cuff", "seamstress", "ARM", "arm_only",
		arm_only.get_snapshot()).get("ok", false),
		"ARM-only cuff sewn on the living Seamstress")
	var arm_attacks := CombatAttackCards.new()
	_check(arm_attacks.bind_patch_wardrobe(arm_only, torn) and arm_attacks._head_rules == null,
		"ARM-only genuine binding with no HEAD authority")
	_check(arm_attacks._patches.card_bleed_bonus("seamstress", "seamstress_prick") == 1
		and arm_attacks._patches.card_bleed_bonus("warden", "seamstress_prick") == 0,
		"bound ARM authority quotes +1 only for its own wearer")
	var arm_foes := _enemies([60])
	var arm_deck := _deck(["seamstress_prick"])
	var starting_size: int = StarterCards.new().get_starting_deck().size()
	_accept(arm_attacks, arm_deck, party, arm_foes, "seamstress_prick", 1,
		[_hit(1, 3, 0, 3, {"bleed": 4})], 1,
		"confirmed ARM-only Prick deals 3 damage and applies Bleed 4")
	_check(arm_foes.get_enemy(1).get("hp") == 57
		and arm_foes.get_enemy(1).get("statuses", {}) == {"bleed": 4},
		"committed ARM Prick leaves 3 HP loss and the exact Bleed 4 status")
	_check(arm_deck.energy == 2
		and arm_deck.discard_pile.count("seamstress_prick") == 1
		and arm_deck.draw_pile.size() + arm_deck.hand.size() + arm_deck.discard_pile.size()
			== starting_size,
		"one committed ARM Prick charges one energy and discards one copy")

	var plain := RunPatchWardrobe.new(party.get_heroes(), owned, defs, 4)
	var plain_attacks := CombatAttackCards.new()
	_check(plain_attacks.bind_patch_wardrobe(plain, torn), "valid unworn wardrobe binds")
	var plain_foes := _enemies([60])
	_accept(plain_attacks, _deck(["seamstress_prick"]), party, plain_foes, "seamstress_prick", 1,
		[_hit(1, 3, 0, 3, {"bleed": 3})], 1, "an unworn cuff keeps the passive Bleed 3")
	_check(plain_foes.get_enemy(1).get("statuses", {}) == {"bleed": 3},
		"no cuff applies exactly the printed plus passive Bleed 3")

	var warden_wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, defs, 4)
	_check(warden_wardrobe.sew("red_bobbin_cuff", "warden", "ARM", "warden_arm",
		warden_wardrobe.get_snapshot()).get("ok", false), "cuff genuinely sewn on the Warden")
	var warden_attacks := CombatAttackCards.new()
	_check(warden_attacks.bind_patch_wardrobe(warden_wardrobe, torn),
		"foreign wearer wardrobe binds")
	_accept(warden_attacks, _deck(["seamstress_prick"]), party, _enemies([60]),
		"seamstress_prick", 1, [_hit(1, 3, 0, 3, {"bleed": 3})], 1,
		"a cuff on another hero grants the Seamstress no bonus")

	# The same cap admits the unpatched Bleed 3 but not the patched Bleed 4.
	var overflow := _enemies([60])
	overflow._enemies[0]["statuses"] = {"bleed": CombatStatuses.MAX_INT - 3}
	var overflow_plain := _enemies([60])
	overflow_plain._enemies[0]["statuses"] = {"bleed": CombatStatuses.MAX_INT - 3}
	_accept(plain_attacks, _deck(["seamstress_prick"]), party, overflow_plain,
		"seamstress_prick", 1, [_hit(1, 3, 0, 3, {"bleed": 3})], 1,
		"unpatched Bleed 3 exactly reaches the status cap")

	var seamstress_living := false
	for hero in torn.read_state().heroes:
		if hero.get("id") == "seamstress" and hero.get("hp", 0) > 0:
			seamstress_living = true
	_check(seamstress_living, "the run ledger keeps the Seamstress genuinely alive")
	var down_party := _party()
	_check(down_party.apply_damage(2, 100) and down_party.is_downed(2),
		"the Seamstress is truly downed in the combat party")
	var empty_energy := _deck(["seamstress_prick"])
	_check(empty_energy.try_spend_energy(3), "all three energy spent before the refusal")
	var slain := _enemies([60])
	_check(slain.apply_damage(1, 999) and slain.is_slain(1), "target enemy truly slain")
	# Prick may be cast from every hero slot, so its only illegal owner FROM is a
	# living run owner who is missing from (or ambiguous in) the combat roster.
	var rejections := [
		{"deck": _deck(["seamstress_prick"]), "party": party, "enemies": overflow,
			"target": 1, "label": "patched Bleed 4 past the status cap rejects"},
		{"deck": _deck(["seamstress_prick"]), "party": _party(["warden", "tinker", "other"]),
			"enemies": _enemies([60]), "target": 1,
			"label": "living run owner with an illegal combat FROM rejects"},
		{"deck": _deck(["seamstress_prick"]), "party": party, "enemies": _enemies([60]),
			"target": 2, "label": "truly absent enemy rank rejects"},
		{"deck": _deck(["seamstress_prick"]), "party": party, "enemies": _enemies([60]),
			"target": 0, "label": "unselected target rejects"},
		{"deck": _deck(["seamstress_prick"]), "party": down_party, "enemies": _enemies([60]),
			"target": 1, "label": "downed Seamstress rejects"},
		{"deck": empty_energy, "party": party, "enemies": _enemies([60]), "target": 1,
			"label": "insufficient energy rejects"},
		{"deck": _deck(["seamstress_prick"]), "party": party, "enemies": slain,
			"target": 1, "label": "slain target rejects"},
	]
	for request in rejections:
		var request_deck: CombatDeck = request["deck"]
		var request_party: CombatParty = request["party"]
		var request_enemies: CombatEnemies = request["enemies"]
		_arm_reject(arm_attacks, arm_only, torn, request_deck, request_party,
			request_enemies, int(request["target"]), str(request["label"]))

	# AC3 stale ARM authority: a genuine post-bind re-sew moves the cuff away, so
	# the saved battle-start active/worn projection must not award it.
	var stale_wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, defs, 4)
	_check(stale_wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "stale_arm",
		stale_wardrobe.get_snapshot()).get("ok", false),
		"the stale fixture starts with a genuine Seamstress cuff")
	var stale_attacks := CombatAttackCards.new()
	_check(stale_attacks.bind_patch_wardrobe(stale_wardrobe, torn)
		and stale_attacks._patches.card_bleed_bonus("seamstress", "seamstress_prick") == 1,
		"the battle-start ARM authority quotes the cuff for the Seamstress")
	_check(stale_wardrobe.start_rest("stale_rest", stale_wardrobe.get_snapshot()).get("ok", false),
		"an authentic Rest opens for the re-sew")
	var moved: Dictionary = stale_wardrobe.re_sew("red_bobbin_cuff", "seamstress", "warden",
		"stale_rest", "stale_move", stale_wardrobe.get_snapshot())
	var moved_state: Dictionary = stale_wardrobe.get_snapshot()
	_check(moved.get("ok", false) and moved_state["worn"]["warden"]["ARM"] == "red_bobbin_cuff"
		and moved_state["worn"]["seamstress"]["ARM"] == "",
		"the live wardrobe really moves the cuff to the Warden after binding")
	_arm_reject(stale_attacks, stale_wardrobe, torn, _deck(["seamstress_prick"]), party,
		_enemies([60]), 1, "stale ARM wardrobe rejects before the hit")
	# Any later genuine sew, even one that leaves the cuff in place, changes the
	# authenticated receipt and must not silently reuse the battle-start powers.
	var sewed_wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, defs, 4)
	_check(sewed_wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "sew_then_cuff",
		sewed_wardrobe.get_snapshot()).get("ok", false),
		"the post-bind sew fixture starts with the genuine cuff")
	var sewed_attacks := CombatAttackCards.new()
	_check(sewed_attacks.bind_patch_wardrobe(sewed_wardrobe, torn)
		and sewed_attacks._patches.card_bleed_bonus("seamstress", "seamstress_prick") == 1,
		"the battle-start authority quotes the cuff before the later sew")
	_check(sewed_wardrobe.sew("bloodstitch_bonnet", "warden", "HEAD", "sew_after_bind",
		sewed_wardrobe.get_snapshot()).get("ok", false),
		"a genuine HEAD sew lands after the battle-start binding")
	_arm_reject(sewed_attacks, sewed_wardrobe, torn, _deck(["seamstress_prick"]), party,
		_enemies([60]), 1, "wardrobe sewn after binding rejects before the hit")
	var rebound_arm := CombatAttackCards.new()
	_check(rebound_arm.bind_patch_wardrobe(stale_wardrobe, torn),
		"a fresh binding follows the moved cuff")
	_accept(rebound_arm, _deck(["seamstress_prick"]), party, _enemies([60]),
		"seamstress_prick", 1, [_hit(1, 3, 0, 3, {"bleed": 3})], 1,
		"the freshly bound service follows the moved cuff with no Seamstress bonus")

	# AC3 stale torn receipt: a real battle-end tear after binding fails closed.
	var torn_wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, defs, 4)
	_check(torn_wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "torn_arm",
		torn_wardrobe.get_snapshot()).get("ok", false),
		"the stale torn fixture wears the genuine cuff")
	var torn_ledger := RunTornMending.new(party.get_heroes())
	var torn_attacks := CombatAttackCards.new()
	_check(torn_attacks.bind_patch_wardrobe(torn_wardrobe, torn_ledger)
		and torn_attacks._patches.card_bleed_bonus("seamstress", "seamstress_prick") == 1,
		"the battle-start torn authority admits the cuff")
	var start_roster: Array = torn_ledger.read_state()["heroes"]
	var end_roster: Array = start_roster.duplicate(true)
	end_roster[0]["hp"] = 0
	_check(torn_ledger.observe_battle_end("tear_node", start_roster, end_roster).get("ok", false),
		"a genuine battle end tears the Warden after binding")
	_arm_reject(torn_attacks, torn_wardrobe, torn_ledger, _deck(["seamstress_prick"]), party,
		_enemies([60]), 1, "stale torn ledger rejects before the hit")
	var live_torn: Dictionary = torn_ledger.read_state()
	var live_snapshot: Dictionary = torn_wardrobe.get_snapshot()
	_check(torn_wardrobe.refresh_run_context(live_torn["heroes"], live_snapshot["owned"],
		live_snapshot["scraps"], live_snapshot["gold"], live_snapshot["cards"],
		live_snapshot), "the wardrobe refreshes to the true torn roster")
	var rebound_torn := CombatAttackCards.new()
	_check(rebound_torn.bind_patch_wardrobe(torn_wardrobe, torn_ledger),
		"a fresh binding to the torn authorities succeeds")
	_accept(rebound_torn, _deck(["seamstress_prick"]), party, _enemies([60]),
		"seamstress_prick", 1, [_hit(1, 3, 0, 3, {"bleed": 4})], 1,
		"the living Seamstress keeps her cuff after a Warden tear")

	# AC3 malformed or absent ARM authorities never fall back to baseline.
	var invalid_wardrobe := RunPatchWardrobe.new()
	var malformed_attacks := CombatAttackCards.new()
	_check(not invalid_wardrobe.is_valid()
		and not malformed_attacks.bind_patch_wardrobe(invalid_wardrobe, torn),
		"a malformed ARM wardrobe binding fails closed")
	_arm_reject(malformed_attacks, invalid_wardrobe, torn, _deck(["seamstress_prick"]),
		party, _enemies([60]), 1, "malformed ARM binding rejects before the hit")
	var missing_wardrobe := CombatAttackCards.new()
	_check(not missing_wardrobe.bind_patch_wardrobe(null, torn),
		"an absent ARM wardrobe fails closed")
	_arm_reject(missing_wardrobe, null, torn, _deck(["seamstress_prick"]), party,
		_enemies([60]), 1, "absent ARM wardrobe rejects before the hit")
	var missing_torn := CombatAttackCards.new()
	_check(not missing_torn.bind_patch_wardrobe(arm_only, null),
		"an absent torn ledger fails closed")
	_arm_reject(missing_torn, arm_only, torn, _deck(["seamstress_prick"]), party,
		_enemies([60]), 1, "absent torn ledger rejects before the hit")


## Thorns applies to the real held-card/deck/party/roster transaction, while
## retaining precisely the existing public hit receipt (no extra keys).
func _thorns_check_play(service: CombatAttackCards, deck: CombatDeck,
		party: CombatParty, foes: CombatEnemies, id: String, target: int,
		hits: Array, cost: int, owner_position: int, owner_hp: int,
		owner_block: int, label: String, earned_stacks: Dictionary = {}) -> void:
	var before := _snapshot(deck, party, foes)
	var owner_id: String = StarterCards.new().get_definition(id).owner
	_check(before.hand.has(id) and before.active and before.energy >= cost,
		label + ": authentic held, affordable card and active turn")
	_check(party.get_hero(owner_position).get("id") == owner_id
		and not party.is_downed(owner_position), label + ": unique living owner at actual position")
	var expected := before.duplicate(true)
	expected["energy"] -= cost
	expected["state_energy"] -= cost
	var hand: Array = expected["hand"]
	hand.erase(id)
	var discard: Array = expected["discard"]
	discard.append(id)
	var expected_enemies: Array = expected["enemies"]
	for hit in hits:
		var entry: Dictionary = expected_enemies[hit.position - 1]
		entry["block"] -= hit.block_absorbed
		entry["hp"] -= hit.hp_loss
		for status in hit.statuses:
			if not entry.has("statuses"):
				entry["statuses"] = {}
			entry["statuses"][status] = entry["statuses"].get(status, 0) + hit.statuses[status]
	var expected_heroes: Array = expected["party"]
	for position in earned_stacks:
		expected_enemies[position - 1]["enrage_stacks"] = earned_stacks[position]
	var owner: Dictionary = expected_heroes[owner_position - 1]
	owner["hp"] = owner_hp
	owner["block"] = owner_block
	var all_slain := true
	for entry in expected_enemies:
		if entry.hp > 0:
			all_slain = false
	expected["victory"] = all_slain
	seed(13840)
	var next_global := randi()
	seed(13840)
	var forecast := service.forecast_attack(deck, party, foes, id)
	var preview := CombatAttackTargeting.new().get_preview(deck, party, foes, id)
	_check(forecast.playable and forecast.hits.size() == preview.target_positions.size(),
		label + ": pure forecast covers real hit recipients")
	for hit in hits:
		_check({"position": hit.position, "damage": hit.damage} in forecast.hits,
			label + ": pre-hit computed damage agrees with forecast")
	_check(_snapshot(deck, party, foes) == before
		and randi() == next_global, label + ": forecast cannot retaliate, spend or advance RNG")
	var result := service.play_attack(deck, party, foes, id, target)
	_check(result == {"ok": true, "hits": hits},
		label + ": unchanged ordered hit-array schema and damage/status math")
	_check(_snapshot(deck, party, foes) == expected,
		label + ": exact authoritative heroes, enemies, piles, turn, cost and RNG")
	if id.begins_with("tinker_"):
		_check(service._tinker._consumed, label + ": Tinker first-attack latch consumed")


func _test_thorns_starter_attacks() -> void:
	var strikes := _deck(["warden_strike"])
	var warden := _party()
	var thorned := _enemies([20])
	thorned._enemies[0]["thorns"] = 3
	_check(warden.gain_block(1, 2) and thorned.gain_block(1, 2),
		"Strike: hero Block 2 and enemy Block 2 set before real hit")
	_thorns_check_play(CombatAttackCards.new(), strikes, warden, thorned,
		"warden_strike", 1, [_hit(1, 6, 2, 4)], 1, 1, 39, 0,
		"Strike 6 versus Thorns 3: Warden Block 2 absorbs, HP loses 1")
	var plus_party := _party()
	var plus_foes := _enemies([20])
	plus_foes._enemies[0]["thorns"] = 2
	_thorns_check_play(CombatAttackCards.new(), _plus_deck(), plus_party, plus_foes,
		"warden_strike_plus", 1, [_hit(1, 7, 0, 7)], 1, 1, 38, 0,
		"real upgraded Strike+ uses same Thorns seam")
	var blocked := _party()
	var armored := _enemies([20])
	armored._enemies[0]["thorns"] = 3
	_check(armored.gain_block(1, 8), "Shield Bash target fully absorbs eight damage")
	_thorns_check_play(CombatAttackCards.new(), _deck(["warden_shield_bash"]),
		blocked, armored, "warden_shield_bash", 1,
		[_hit(1, 8, 8, 0, {"weak": 1})], 2, 1, 37, 0,
		"Shield Bash with fully absorbed hit still retaliates and applies Weak")
	var lethal := _party()
	var near_death := _enemies([5])
	near_death._enemies[0]["thorns"] = 3
	_thorns_check_play(CombatAttackCards.new(), _deck(["warden_strike"]),
		lethal, near_death, "warden_strike", 1,
		[_hit(1, 6, 0, 5)], 1, 1, 37, 0,
		"lethal Strike retaliates from pre-hit Thorns 3 after enemy dies")
	var swapped := _party(["warden", "tinker", "seamstress"])
	var prick_foes := _enemies([20])
	prick_foes._enemies[0]["thorns"] = 3
	_check(swapped.gain_block(3, 1), "swapped Seamstress gains one Block in slot 3")
	_thorns_check_play(CombatAttackCards.new(), _deck(["seamstress_prick"]),
		swapped, prick_foes, "seamstress_prick", 1,
		[_hit(1, 3, 0, 3, {"bleed": 3})], 1, 3, 28, 0,
		"swapped Prick retaliates on owner slot 3, preserves Bleed 3")
	_check(swapped.get_hero(1).hp == 40 and swapped.get_hero(2).hp == 26,
		"swapped attack never redirects damage to original slot or another hero")
	var pop_party := _party()
	var pop_foes := _enemies([25])
	pop_foes._enemies[0]["thorns"] = 2
	_check(pop_party.gain_block(3, 1), "Pop Shot's Tinker owns one Block")
	_thorns_check_play(CombatAttackCards.new(), _deck(["tinker_pop_shot"]),
		pop_party, pop_foes, "tinker_pop_shot", 1,
		[_hit(1, 8, 0, 8)], 1, 3, 25, 0,
		"first Pop Shot +3 uses computed eight damage, Thorns 2")
	for value in [null, 0]:
		var plain := _party()
		var unthorned := _enemies([20])
		if value != null:
			unthorned._enemies[0]["thorns"] = value
		_thorns_check_play(CombatAttackCards.new(), _deck(["warden_strike"]),
			plain, unthorned, "warden_strike", 1,
			[_hit(1, 6, 0, 6)], 1, 1, 40, 0,
			"absent/zero Thorns never retaliates: " + str(value))


func _test_thorns_bomb_and_downed_owner() -> void:
	for third_slain in [false, true]:
		var tinker := _party()
		var foes := _enemies([30, 30, 30])
		foes._enemies[0]["thorns"] = 3
		foes._enemies[1]["thorns"] = 3
		_check(tinker.gain_block(3, 2) and foes.gain_block(2, 8),
			"Bomb: Tinker Block 2 and second target Block 8 set")
		var hits: Array = [_hit(1, 7, 0, 7), _hit(2, 7, 7, 0)]
		if third_slain:
			_check(foes.apply_damage(3, 30) and foes.is_slain(3),
				"slain third slot remains present but cannot receive Bomb")
		else:
			hits.append(_hit(3, 7, 0, 7))
		_thorns_check_play(CombatAttackCards.new(), _deck(["tinker_scrap_bomb"]),
			tinker, foes, "tinker_scrap_bomb", 0,
			hits, 2, 3, 22, 0,
			"real target-free Bomb: two Thorns 3, third %s" % (
				"slain" if third_slain else "living plain"))
	var low := _party()
	_check(low.apply_damage(3, 23) and low.get_hero(3).hp == 3,
		"low-HP Tinker remains living before Bomb")
	var three := _enemies([30, 30, 30])
	three._enemies[0]["thorns"] = 3
	three._enemies[1]["thorns"] = 3
	_thorns_check_play(CombatAttackCards.new(), _deck(["tinker_scrap_bomb"]),
		low, three, "tinker_scrap_bomb", 0,
		[_hit(1, 7, 0, 7), _hit(2, 7, 0, 7), _hit(3, 7, 0, 7)],
		2, 3, 0, 0, "downed Tinker never rolls back remaining Bomb recipients")


func _test_thorns_rejections() -> void:
	for value in [-3, 1.5, "3", true, null, [], {}]:
		for card_id in ["warden_strike", "tinker_scrap_bomb"]:
			var deck := _deck([card_id])
			var party := _party()
			var foes := _enemies([25, 25, 25])
			var slot := 1 if card_id == "warden_strike" else 2
			foes._enemies[slot - 1]["thorns"] = value
			var service := CombatAttackCards.new()
			var target := 1 if card_id == "warden_strike" else 0
			var before := _snapshot(deck, party, foes)
			_check(not service.forecast_attack(deck, party, foes, card_id).playable
				and _snapshot(deck, party, foes) == before,
				"malformed Thorns " + str(value) + " refuses forecast before mutation")
			_reject(service, deck, party, foes, card_id, target,
				"malformed Thorns " + str(value) + " at attacked slot " + str(slot))
			_check(not service._tinker._consumed,
				"malformed late Bomb Thorns cannot consume Tinker first-hit bonus")
	# Rejections with valid Thorns must still leave the entire ledger untouched.
	var foes := _enemies([30])
	foes._enemies[0]["thorns"] = 3
	var held := _deck(["warden_strike"])
	_reject(CombatAttackCards.new(), held, _party(), foes,
		"warden_strike", 0, "Thorns on unselected legal card")
	var spent := _deck(["warden_strike"])
	_check(spent.try_spend_energy(3), "unaffordable Thorns test pre-spends all three energy")
	_reject(CombatAttackCards.new(), spent, _party(), foes,
		"warden_strike", 1, "Thorns cannot fire on unaffordable card")
	var absent := _deck(["warden_strike"])
	_check(absent.discard_played("warden_strike"), "unheld Thorns test removes one copy")
	while absent.hand.has("warden_strike"):
		_check(absent.discard_played("warden_strike"), "remove second real Strike copy")
	_reject(CombatAttackCards.new(), absent, _party(), foes,
		"warden_strike", 1, "Thorns cannot fire on unheld card")
	var bad := _enemies([30, 30])
	bad._enemies[1]["thorns"] = -2
	var valid := _party()
	var bomb_deck := _deck(["tinker_scrap_bomb"])
	var resolver := CombatAttackCards.new()
	_reject(resolver, bomb_deck, valid, bad, "tinker_scrap_bomb", 0,
		"late malformed enemy prevents any Bomb hit, energy or latch mutation")
	bad._enemies[1]["thorns"] = 3
	_thorns_check_play(resolver, bomb_deck, valid, bad, "tinker_scrap_bomb", 0,
		[_hit(1, 7, 0, 7), _hit(2, 7, 0, 7)], 2, 3, 23, 0,
		"subsequent valid Bomb retains first-attack bonus after rejected batch")


## The same full-snapshot helper checks Enrage alongside authentic Thorns hits.
func _test_enrage_starter_hits() -> void:
	for id in CombatAttackCards.ATTACK_IDS:
		if id == "tinker_scrap_bomb":
			continue
		for blocked in [false, true]:
			var deck := _plus_deck(id) if id.ends_with("_plus") else _deck([id])
			var party := _party()
			var foes := _enemies([40, 40, 40])
			var target := 1 if id in ["warden_shield_bash", "warden_shield_bash_plus"] else 2
			for enemy in foes._enemies:
				enemy["enrage"] = true
				enemy["tag"] = {"preserved": [1, 2]}
			foes._enemies[target - 1]["thorns"] = 2
			var definition: Dictionary = StarterCards.new().get_definition(id)
			var damage: int = definition.effects.damage + (3 if id == "tinker_pop_shot" else 0)
			var statuses := {}
			if id in ["warden_shield_bash", "warden_shield_bash_plus"]:
				statuses = {"weak": 1}
			elif id == "seamstress_prick":
				statuses = {"bleed": 3}
			elif id == "seamstress_prick_plus":
				statuses = {"bleed": 4}
			if blocked:
				_check(foes.gain_block(target, damage + 1), "fully blocked Enrage fixture")
			var owner: int = 3 if id == "tinker_pop_shot" else (2 if id in ["seamstress_prick", "seamstress_prick_plus"] else 1)
			var owner_hp: int = party.get_hero(owner).hp - 2
			_thorns_check_play(CombatAttackCards.new(), deck, party, foes, id, target,
				[_hit(target, damage, damage if blocked else 0, 0 if blocked else damage, statuses)],
				definition.cost, owner, owner_hp, 0, id + ": Enrage on original target slot", {target: 1})
			_check(not foes.get_enemy(2 if target == 1 else 1).has("enrage_stacks")
				and not foes.get_enemy(3).has("enrage_stacks"), "untouched Enrage slots stay absent")
			# Real persisted stack is read before Weak/Exposed rounding and hero Block.
			_check(party.gain_block(1, 2), "phase recipient gains real Block")
			party._heroes[0]["statuses"] = {"exposed": 1}
			var before := _snapshot(deck, party, foes)
			var intents := [{"type": "attack", "enemy_position": target, "amount": 5, "target_position": 1}]
			var phase := CombatEnemyPhase.new().execute_phase(party, foes, intents)
			var expected := before.duplicate(true)
			var phase_damage := 7 if id in ["warden_shield_bash", "warden_shield_bash_plus"] else 10
			expected.party[0].block = 0
			expected.party[0].hp -= phase_damage - 2
			_check(phase == {"ok": true, "events": [{"type": "attack", "enemy_position": target,
				"target_position": 1, "applied": true}]}
				and _snapshot(deck, party, foes) == expected,
				"earned +2 precedes status modifiers/Block; exact phase snapshot preserves everything else")
	# Two held copies earn one stack per hit, including the transition to cap.
	var deck := _deck(["warden_strike", "warden_strike"])
	var party := _party()
	var foes := _enemies([40])
	foes._enemies[0].enrage = true
	foes._enemies[0].enrage_stacks = 1
	var attacks := CombatAttackCards.new()
	for stacks in [2, 3]:
		_thorns_check_play(attacks, deck, party, foes, "warden_strike", 1,
			[_hit(1, 6, 0, 6)], 1, 1, 40, 0, "each real Strike earns one stack", {1: stacks})


func _enrage_bomb_replay(seed_value: int, slain_middle: bool) -> Dictionary:
	var deck := _deck(["tinker_scrap_bomb"], seed_value)
	var party := _party()
	var foes := _enemies([40, 40, 40])
	foes._enemies[0].enrage = true
	foes._enemies[0].thorns = 3
	foes._enemies[1].enrage = true
	foes._enemies[1].enrage_stacks = 3
	foes._enemies[2].enrage = false
	foes._enemies[2].enrage_stacks = 2
	_check(foes.gain_block(1, 8), "Bomb fully blocked Enrage target")
	if slain_middle:
		_check(foes.apply_damage(2, 40), "Bomb retains slain capped original middle slot")
	var attacks := CombatAttackCards.new()
	var hits: Array = [_hit(1, 7, 7, 0)]
	if not slain_middle:
		hits.append(_hit(2, 7, 0, 7))
	hits.append(_hit(3, 7, 0, 7))
	_thorns_check_play(attacks, deck, party, foes, "tinker_scrap_bomb", 0,
		hits, 2, 3, 23, 0, "Bomb: blocked Enrage, capped/slain, false flag", {1: 1})
	_reject(attacks, deck, party, foes, "tinker_scrap_bomb", 0, "spent Bomb cannot earn stacks again")
	var before := _snapshot(deck, party, foes)
	var intents: Array = []
	for position in [1, 2, 3]:
		intents.append({"type": "attack", "enemy_position": position, "amount": 2, "target_position": position})
	var phase := CombatEnemyPhase.new().execute_phase(party, foes, intents)
	var expected := before.duplicate(true)
	expected.party[0].hp -= 4
	if not slain_middle:
		expected.party[1].hp -= 8
	expected.party[2].hp -= 2
	_check(phase.ok and phase.events.size() == 3
		and phase.events[1].applied == not slain_middle
		and _snapshot(deck, party, foes) == expected,
		"Bomb-earned stack, cap, false flag and slain source feed exact next phase")
	return {"before": before, "phase": phase, "after": _snapshot(deck, party, foes),
		"latch": attacks._tinker._consumed}


func _test_enrage_bomb_and_replay() -> void:
	for slain_middle in [false, true]:
		_check(_enrage_bomb_replay(76291, slain_middle) == _enrage_bomb_replay(76291, slain_middle),
			"same seed replays entire Enrage hit/phase sequence, piles, receipts, latch and RNG")
	for metadata in [{}, {"enrage": false}, {"enrage_stacks": 2},
			{"enrage": false, "enrage_stacks": 2}, {"enrage": true, "enrage_stacks": 3}]:
		var foes := _enemies([40])
		foes._enemies[0].merge(metadata)
		_thorns_check_play(CombatAttackCards.new(), _deck(["warden_strike"]), _party(), foes,
			"warden_strike", 1, [_hit(1, 6, 0, 6)], 1, 1, 40, 0,
			"non-Enrage/capped metadata remains exactly unchanged " + str(metadata))


func _test_enrage_rejections() -> void:
	var malformed: Array = []
	for value in [null, 0, 1, "true", [], {}]:
		malformed.append({"enrage": value})
	for value in [null, -1, 4, 1.0, "1", true, [], {}]:
		for flag in [true, false]:
			malformed.append({"enrage": flag, "enrage_stacks": value})
	for metadata in malformed:
		for id in ["seamstress_prick", "tinker_scrap_bomb"]:
			var deck := _deck([id])
			var party := _party()
			var foes := _enemies([40, 40, 40])
			foes._enemies[2].merge(metadata)
			var attacks := CombatAttackCards.new()
			_check(attacks._tinker.arm_path_bonus(2), "rejection fixture has unspent Path latch")
			var before := _snapshot(deck, party, foes)
			_check(not attacks.forecast_attack(deck, party, foes, id).playable
				and _snapshot(deck, party, foes) == before, "malformed Enrage forecast is pure refusal")
			_reject(attacks, deck, party, foes, id, 3 if id == "seamstress_prick" else 0,
				"malformed late Enrage recipient " + str(metadata))
			_check(attacks._tinker.path_bonus() == 2, "refusal also preserves armed Path bonus")
			foes._enemies[2].enrage = true
			foes._enemies[2].enrage_stacks = 0
			var accepted := attacks.play_attack(deck, party, foes, id, 3 if id == "seamstress_prick" else 0)
			_check(accepted.ok and foes.get_enemy(3).enrage_stacks == 1,
				"corrected same request succeeds once and earns exactly one stack")
	var foes := _enemies([40])
	foes._enemies[0].enrage = true
	var deck := _deck(["tinker_scrap_bomb"])
	var party := _party()
	var attacks := CombatAttackCards.new()
	_reject(attacks, deck, party, foes, "tinker_scrap_bomb", 1, "unplayable selected Bomb with Enrage")
	_check(deck.try_spend_energy(3), "Enrage unaffordable fixture spends real energy")
	_reject(attacks, deck, party, foes, "tinker_scrap_bomb", 0, "unaffordable Enrage hit")
	_check(deck.end_turn(), "Enrage stale-turn fixture ends actual turn")
	_reject(attacks, deck, party, foes, "tinker_scrap_bomb", 0, "stale-turn Enrage hit")


func _test_enrage_zero_damage() -> void:
	# Authored starter attacks all deal positive damage even under Weak. Exercise
	# the shared confirmed-hit seam with a real zero-damage bridge receipt instead
	# of changing authored balance or fabricating a successful receipt.
	var party := _party()
	var foes := _enemies([40])
	foes._enemies[0].enrage = true
	foes._enemies[0].thorns = 3
	var before := foes.get_enemy(1)
	var heroes := party.get_heroes()
	var receipt := CombatStatusAttacks.new().resolve_vs_enemy(foes, 1, 0, {}, {})
	_check(receipt == {"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0},
		"real bridge confirms a zero-damage hit")
	CombatAttackCards.new()._retaliate_hits(party, foes, 1, [_hit(1, receipt.damage,
		receipt.block_absorbed, receipt.hp_loss)], {1: before})
	_check(foes.get_enemy(1) == before and party.get_heroes() == heroes,
		"zero damage cannot award stacks or trigger Thorns")
	var phase := CombatEnemyPhase.new().execute_phase(party, foes,
		[{"type": "attack", "enemy_position": 1, "amount": 5, "target_position": 1}])
	_check(phase.ok and party.get_hero(1).hp == 35 and foes.get_enemy(1) == before,
		"next phase after zero hit reads no bonus and does not publish a stack")


func _thorns_replay(seed_value: int) -> Dictionary:
	var deck := _deck(["tinker_scrap_bomb", "warden_strike"], seed_value)
	var party := _party()
	var foes := _enemies([30, 30, 30])
	foes._enemies[0]["thorns"] = 3
	foes._enemies[1]["thorns"] = 3
	foes.gain_block(2, 8)
	party.gain_block(3, 2)
	var attacks := CombatAttackCards.new()
	var forecast := attacks.forecast_attack(deck, party, foes, "tinker_scrap_bomb")
	var before := _snapshot(deck, party, foes)
	var events := [
		attacks.play_attack(deck, party, foes, "tinker_scrap_bomb", 0),
		attacks.play_attack(deck, party, foes, "warden_strike", 1)
	]
	return {"forecast": forecast, "before": before, "events": events,
		"after": _snapshot(deck, party, foes), "latch": attacks._tinker._consumed}


func _test_thorns_seeded_replay() -> void:
	var first := _thorns_replay(63418)
	var second := _thorns_replay(63418)
	_check(first == second,
		"two genuine same-seed Thorns replays agree on hits, owner HP, Block, piles, turn and RNG")
	_check(first.forecast == {"playable": true, "requires_selection": false,
		"hits": [{"position": 1, "damage": 7}, {"position": 2, "damage": 7},
			{"position": 3, "damage": 7}]},
		"forecast of Thorns Bomb is pure damage without retaliation rows")
	_check(first.before.party[2].hp == 26 and first.before.party[2].block == 2
		and first.after.party[2].hp == 22 and first.after.party[2].block == 0
		and first.after.party[0].hp == 37,
		"two Bomb Thorns retaliations then Warden Strike Thorns damage actual owners")
	_check(first.events == [
		{"ok": true, "hits": [_hit(1, 7, 0, 7), _hit(2, 7, 7, 0), _hit(3, 7, 0, 7)]},
		{"ok": true, "hits": [_hit(1, 6, 0, 6)]}],
		"same-seed replay keeps exact ordered public hit payloads, no Thorns fields")
	_check(first.after.energy == 0 and first.after.state_energy == 0
		and first.after.discard.has("tinker_scrap_bomb")
		and first.after.discard.has("warden_strike") and first.latch,
		"two real paid cards, discarded copies, intact first-attack latch and active turn")


## Bridge receipt shape for the direct one-shot comparisons.
func _status_receipt(damage: int, absorbed: int, loss: int) -> Dictionary:
	return {"ok": true, "damage": damage, "block_absorbed": absorbed, "hp_loss": loss}


func _status_failure() -> Dictionary:
	return {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0}


func _bridge_reject_enemy(bridge: CombatStatusAttacks, enemies: CombatEnemies,
		position: int, base_damage: int, attacker: Dictionary, defender: Dictionary,
		label: String) -> void:
	var roster_before := enemies.get_enemies()
	var attacker_before := attacker.duplicate(true)
	var defender_before := defender.duplicate(true)
	_check(bridge.resolve_vs_enemy(enemies, position, base_damage, attacker, defender)
		== _status_failure(), "one-shot enemy refusal: " + label)
	_check(enemies.get_enemies() == roster_before,
		"one-shot enemy refusal leaves the roster unchanged: " + label)
	_check(attacker == attacker_before and defender == defender_before,
		"one-shot enemy refusal leaves the supplied maps unchanged: " + label)


func _bridge_reject_hero(bridge: CombatStatusAttacks, party: CombatParty,
		position: int, base_damage: int, attacker: Dictionary, defender: Dictionary,
		label: String) -> void:
	var roster_before := party.get_heroes()
	var attacker_before := attacker.duplicate(true)
	var defender_before := defender.duplicate(true)
	_check(bridge.resolve_vs_hero(party, position, base_damage, attacker, defender)
		== _status_failure(), "one-shot hero refusal: " + label)
	_check(party.get_heroes() == roster_before,
		"one-shot hero refusal leaves the roster unchanged: " + label)
	_check(attacker == attacker_before and defender == defender_before,
		"one-shot hero refusal leaves the supplied maps unchanged: " + label)


## AC1: the shipped one-shot defense tokens are role-aware on the shared status
## bridge. A Dodging attacker and an already-Blinded defender receive exactly the
## token-free Weak/Exposed/Tangled damage and the same Block-before-HP receipt,
## and neither token is spent, aged or mutated.
func _test_one_shot_token_bridge() -> void:
	var bridge := CombatStatusAttacks.new()
	var bases: Array[Dictionary] = [
		{"attack": {}, "defend": {}},
		{"attack": {"weak": 1}, "defend": {}},
		{"attack": {}, "defend": {"exposed": 1}},
		{"attack": {"weak": 1}, "defend": {"exposed": 1, "tangled": 2}},
	]
	for base in bases:
		var base_attack: Dictionary = base["attack"].duplicate(true)
		var base_defend: Dictionary = base["defend"].duplicate(true)
		var control_enemies := _enemies()
		var control_party := _party()
		_check(control_enemies.gain_block(1, 4) and control_party.gain_block(1, 6),
			"one-shot control fixtures hold genuine Block")
		seed(5521)
		var next_global := randi()
		seed(5521)
		var expected_enemy := bridge.resolve_vs_enemy(control_enemies, 1, 6,
			base_attack, base_defend)
		var expected_hero := bridge.resolve_vs_hero(control_party, 1, 8,
			base_attack, base_defend)
		_check(expected_enemy["ok"] and expected_hero["ok"]
			and expected_enemy["block_absorbed"] == 4
			and expected_hero["block_absorbed"] == 6,
			"token-free control lands a Block-before-HP hit: " + str(base))
		_check(randi() == next_global, "token-free bridge hit consumes no global RNG")
		var control_roster := control_enemies.get_enemies()
		var control_heroes := control_party.get_heroes()
		for token in [0, 1]:
			for placement in ["attacker", "defender", "both"]:
				var attack: Dictionary = base_attack.duplicate(true)
				var defend: Dictionary = base_defend.duplicate(true)
				if placement != "defender":
					attack["dodge_next_attack"] = token
				if placement != "attacker":
					defend["blind_next_attack"] = token
				var attack_before := attack.duplicate(true)
				var defend_before := defend.duplicate(true)
				_check((placement == "defender" or attack.get("dodge_next_attack") == token)
					and (placement == "attacker"
						or defend.get("blind_next_attack") == token),
					"one-shot %s token %d really places both role tokens"
						% [placement, token])
				var enemies := _enemies()
				var party := _party()
				_check(enemies.gain_block(1, 4) and party.gain_block(1, 6),
					"one-shot fixtures repeat the control Block")
				var rng := RandomNumberGenerator.new()
				rng.seed = 864213
				var rng_before := rng.state
				var enemy_result := bridge.resolve_vs_enemy(enemies, 1, 6, attack, defend)
				var hero_result := bridge.resolve_vs_hero(party, 1, 8, attack, defend)
				_check(enemy_result == expected_enemy and hero_result == expected_hero,
					"one-shot %s token %d keeps both receipts identical to the control"
						% [placement, token])
				_check(enemies.get_enemies() == control_roster
					and party.get_heroes() == control_heroes,
					"one-shot %s token %d leaves the same rosters as the control"
						% [placement, token])
				_check(attack == attack_before and defend == defend_before,
					"one-shot %s token %d is neither consumed nor mutated" % [placement, token])
				_check(rng.state == rng_before,
					"one-shot %s token %d leaves the run RNG untouched" % [placement, token])
	# The tokens also live on the authentic roster records: the bridge reads those
	# maps directly, still lands the plain receipt and leaves both tokens in place.
	var record_enemies := _enemies()
	var record_party := _party()
	record_party._heroes[0]["statuses"] = {"dodge_next_attack": 1}
	record_enemies._enemies[0]["statuses"] = {"blind_next_attack": 1}
	_check(record_enemies.gain_block(1, 4) and record_party.gain_block(1, 6),
		"record-backed one-shot fixtures hold genuine Block")
	var record_enemy_hit := bridge.resolve_vs_enemy(record_enemies, 1, 6,
		record_party.get_hero(1)["statuses"], record_enemies.get_enemy(1)["statuses"])
	var record_hero_hit := bridge.resolve_vs_hero(record_party, 1, 8,
		record_party.get_hero(1)["statuses"], record_enemies.get_enemy(1)["statuses"])
	_check(record_enemy_hit == _status_receipt(6, 4, 2)
		and record_hero_hit == _status_receipt(8, 6, 2),
		"record-backed Dodge/Blind hits keep the plain floor-rounded receipts")
	_check(record_party.get_hero(1)["statuses"] == {"dodge_next_attack": 1}
		and record_enemies.get_enemy(1)["statuses"] == {"blind_next_attack": 1},
		"both roster records keep their one-shot defense tokens after the hits")
	_check(record_party.get_hero(1)["hp"] == 38 and record_party.get_hero(1)["block"] == 0
		and record_enemies.get_enemy(1)["hp"] == 16
		and record_enemies.get_enemy(1)["block"] == 0,
		"record-backed one-shot hits spend Block before HP on both rosters")


## AC2: one authentic seeded Prick transaction from the living Seamstress at her
## real slot against a legal living target, optionally carrying the shipped
## one-shot tokens on the owner/target and optional caller-supplied snapshots.
func _one_shot_prick(seed_value: int, with_tokens: bool, supplied: bool) -> Dictionary:
	var service := CombatAttackCards.new()
	var deck := _deck(["seamstress_prick"], seed_value)
	var party := _party()
	var enemies := _enemies([40, 40, 40])
	_check(deck.hand.has("seamstress_prick") and deck.turn_active and deck.energy >= 1,
		"one-shot fixture holds the real Prick in an active paid turn")
	_check(party.get_hero(2)["id"] == "seamstress" and not party.is_downed(2),
		"one-shot fixture has the living Seamstress in her real slot")
	if with_tokens:
		party._heroes[1]["statuses"] = {"dodge_next_attack": 1}
		enemies._enemies[2]["statuses"] = {"blind_next_attack": 1}
	var attacker: Dictionary = {"dodge_next_attack": 1} if supplied else {}
	var defenders: Dictionary = {3: {"blind_next_attack": 1}} if supplied else {}
	var attacker_before := attacker.duplicate(true)
	var defenders_before := defenders.duplicate(true)
	var before := _snapshot(deck, party, enemies)
	var copies: int = deck.draw_pile.size() + deck.hand.size() + deck.discard_pile.size()
	var latch_before: bool = service._tinker._consumed
	var rng_before: int = deck._rng.state
	seed(66113)
	var next_global := randi()
	seed(66113)
	var forecast := service.forecast_attack(deck, party, enemies, "seamstress_prick",
		attacker, defenders)
	var receipt := service.play_attack(deck, party, enemies, "seamstress_prick", 3,
		attacker, defenders)
	return {"before": before, "forecast": forecast, "receipt": receipt,
		"after": _snapshot(deck, party, enemies), "copies": copies,
		"latch_before": latch_before, "latch": service._tinker._consumed,
		"rng_before": rng_before, "rng_after": deck._rng.state,
		"next_global": next_global, "global": randi(),
		"attacker": attacker, "attacker_before": attacker_before,
		"defenders": defenders, "defenders_before": defenders_before}


## AC2: the genuine held Prick with authentic Dodge on its owner and Blind on its
## enemy target succeeds exactly once, charges/discards once, preserves both
## defensive tokens and matches the token-free control receipt and RNG.
func _test_one_shot_token_held_card() -> void:
	var control := _one_shot_prick(8841, false, false)
	var tokens := _one_shot_prick(8841, true, false)
	var supplied := _one_shot_prick(8841, true, true)
	var expected_hit := _hit(3, 3, 0, 3, {"bleed": 3})
	_check(control["attacker"].is_empty() and control["defenders"].is_empty()
		and not control["before"]["party"][1].has("statuses")
		and not control["before"]["enemies"][2].has("statuses"),
		"the token-free control really carries no Dodge or Blind")
	_check(tokens["before"]["party"][1]["statuses"] == {"dodge_next_attack": 1}
		and tokens["before"]["enemies"][2]["statuses"] == {"blind_next_attack": 1}
		and supplied["attacker"] == {"dodge_next_attack": 1}
		and supplied["defenders"] == {3: {"blind_next_attack": 1}},
		"the token and supplied runs really carry the authentic Dodge and Blind")
	for run in [control, tokens, supplied]:
		_check(run["receipt"] == {"ok": true, "hits": [expected_hit]},
			"one-shot Prick keeps its normal confirmed Bleed 3 hit")
		_check(run["forecast"] == {"playable": true, "requires_selection": true,
			"hits": [{"position": 1, "damage": 3}, {"position": 2, "damage": 3},
				{"position": 3, "damage": 3}]},
			"one-shot Prick forecast offers every legal target at printed damage")
		_check(run["after"]["energy"] == 2 and run["after"]["state_energy"] == 2,
			"one-shot Prick charges exactly one energy")
		_check(run["after"]["discard"].count("seamstress_prick")
			== run["before"]["discard"].count("seamstress_prick") + 1,
			"one-shot Prick discards exactly one genuine held copy")
		_check(run["after"]["draw"].size() + run["after"]["hand"].size()
			+ run["after"]["discard"].size() == run["copies"],
			"one-shot Prick keeps every copied card in exactly one pile")
		_check(run["rng_after"] == run["rng_before"]
			and run["global"] == run["next_global"],
			"one-shot Prick leaves the seeded run and global RNG untouched")
		_check(not run["latch"] and not run["latch_before"],
			"one-shot Prick never touches Tinker's first-hit latch")
		_check(run["attacker"] == run["attacker_before"]
			and run["defenders"] == run["defenders_before"],
			"one-shot Prick never mutates the optional caller snapshots")
		_check(run["after"]["enemies"][2]["hp"] == 37
			and run["after"]["enemies"][2]["block"] == 0,
			"one-shot Prick lands its three damage on the living target")
		_check(run["after"]["enemies"][0] == run["before"]["enemies"][0]
			and run["after"]["enemies"][1] == run["before"]["enemies"][1],
			"one-shot Prick leaves the unselected enemy slots untouched")
	_check(control["after"]["enemies"][2]["statuses"] == {"bleed": 3},
		"token-free control applies exactly the printed plus passive Bleed 3")
	_check(tokens["after"]["enemies"][2]["statuses"] == {"blind_next_attack": 1, "bleed": 3}
		and supplied["after"]["enemies"][2]["statuses"]
			== {"blind_next_attack": 1, "bleed": 3},
		"the Blinded target keeps Blind 1 and still gains its Bleed 3")
	_check(tokens["after"]["party"][1]["statuses"] == {"dodge_next_attack": 1}
		and supplied["after"]["party"][1]["statuses"] == {"dodge_next_attack": 1},
		"the Dodging owner keeps Dodge 1 through the paid attack")
	_check(not control["after"]["party"][1].has("statuses"),
		"the token-free control owner gains no invented status")
	_check(tokens["after"]["party"][1]["hp"] == control["after"]["party"][1]["hp"]
		and tokens["after"]["party"][0] == control["after"]["party"][0]
		and tokens["after"]["party"][2] == control["after"]["party"][2],
		"one-shot tokens add no outgoing damage or incoming vulnerability")
	_check(tokens["receipt"] == control["receipt"]
		and supplied["receipt"] == control["receipt"]
		and tokens["forecast"] == control["forecast"]
		and supplied["forecast"] == control["forecast"],
		"token and caller-snapshot runs match the token-free control receipts")


## AC3: malformed 0/1 tokens, the wrong role for the damage path and every older
## unsupported status still fail closed on the shared bridge without mutating a
## roster, spending a miss/evasion token or drawing RNG.
func _test_one_shot_token_bridge_rejections() -> void:
	var bridge := CombatStatusAttacks.new()
	var enemies := _enemies()
	var party := _party()
	_check(enemies.gain_block(1, 4) and party.gain_block(1, 6),
		"one-shot rejection fixtures have living targets and genuine Block")
	var malformed: Array[Dictionary] = []
	for value in [-1, 2, 1.0, true, "1", null, [], {}]:
		malformed.append({"dodge_next_attack": value})
		malformed.append({"blind_next_attack": value})
	for statuses in malformed:
		_bridge_reject_enemy(bridge, enemies, 1, 6, statuses, {},
			"malformed attacker token " + str(statuses))
		_bridge_reject_enemy(bridge, enemies, 1, 6, {}, statuses,
			"malformed defender token " + str(statuses))
		_bridge_reject_hero(bridge, party, 1, 8, statuses, {},
			"malformed hero attacker token " + str(statuses))
		_bridge_reject_hero(bridge, party, 1, 8, {}, statuses,
			"malformed hero defender token " + str(statuses))
	# The opposite roles stay owned by the separate miss/evasion attempt path.
	for token in [0, 1]:
		_bridge_reject_enemy(bridge, enemies, 1, 6, {"blind_next_attack": token}, {},
			"enemy attacker Blind %d is not an ordinary hit" % token)
		_bridge_reject_enemy(bridge, enemies, 1, 6, {}, {"dodge_next_attack": token},
			"enemy defender Dodge %d is not an ordinary hit" % token)
		_bridge_reject_hero(bridge, party, 1, 8, {"blind_next_attack": token}, {},
			"hero attacker Blind %d is not an ordinary hit" % token)
		_bridge_reject_hero(bridge, party, 1, 8, {}, {"dodge_next_attack": token},
			"hero defender Dodge %d is not an ordinary hit" % token)
	for pairing in [
		{"attack": {"dodge_next_attack": 1, "blind_next_attack": 0}, "defend": {}},
		{"attack": {}, "defend": {"blind_next_attack": 1, "dodge_next_attack": 0}},
		{"attack": {"dodge_next_attack": 1, "poison": 1}, "defend": {}},
		{"attack": {}, "defend": {"blind_next_attack": 1, "poison": 1}},
		{"attack": {"dodge_next_attack": 1, 1: 2}, "defend": {}},
		{"attack": {}, "defend": {"blind_next_attack": 1, "Blind_Next_Attack": 1}},
	]:
		_bridge_reject_enemy(bridge, enemies, 1, 6, pairing["attack"], pairing["defend"],
			"legal token beside an illegal entry " + str(pairing))
		_bridge_reject_hero(bridge, party, 1, 8, pairing["attack"], pairing["defend"],
			"legal token beside an illegal hero entry " + str(pairing))
	for position in [-1, 0, 4, 100]:
		_bridge_reject_enemy(bridge, enemies, position, 6,
			{"dodge_next_attack": 1}, {"blind_next_attack": 1},
			"missing enemy slot %d with legal tokens" % position)
		_bridge_reject_hero(bridge, party, position, 8,
			{"dodge_next_attack": 1}, {"blind_next_attack": 1},
			"missing hero slot %d with legal tokens" % position)
	var slain := _enemies([40, 40, 40])
	_check(slain.apply_damage(2, 40) and slain.is_slain(2),
		"one-shot bridge fixture really has a slain enemy")
	_bridge_reject_enemy(bridge, slain, 2, 6, {"dodge_next_attack": 1},
		{"blind_next_attack": 1}, "slain enemy with legal tokens")
	var downed := _party()
	_check(downed.apply_damage(2, 30) and downed.is_downed(2),
		"one-shot bridge fixture really has a downed hero")
	_bridge_reject_hero(bridge, downed, 2, 8, {"dodge_next_attack": 1},
		{"blind_next_attack": 1}, "downed hero with legal tokens")
	for amount in [-1]:
		_bridge_reject_enemy(bridge, enemies, 1, amount, {"dodge_next_attack": 1},
			{"blind_next_attack": 1}, "negative damage with legal tokens")
		_bridge_reject_hero(bridge, party, 1, amount, {"dodge_next_attack": 1},
			{"blind_next_attack": 1}, "negative hero damage with legal tokens")
	# A legal token still resolves once the malformed fixture is corrected.
	var repaired := _enemies()
	_check(repaired.gain_block(1, 4), "repaired one-shot fixture has Block")
	_check(bridge.resolve_vs_enemy(repaired, 1, 6, {"dodge_next_attack": 1},
		{"blind_next_attack": 1}) == _status_receipt(6, 4, 2),
		"corrected one-shot request succeeds exactly once")


## AC3: the held-card preflight refuses every invalid supplied snapshot before
## energy, deck, roster, passive or RNG can change, and still accepts the legal
## token pair from the previous test.
func _test_one_shot_token_card_rejections() -> void:
	var card_cases: Array[Dictionary] = [
		{"attacker": {"blind_next_attack": 1}, "defenders": {},
			"label": "supplied attacker Blind 1"},
		{"attacker": {"blind_next_attack": 0}, "defenders": {},
			"label": "supplied attacker Blind 0"},
		{"attacker": {}, "defenders": {3: {"dodge_next_attack": 1}},
			"label": "supplied defender Dodge 1"},
		{"attacker": {}, "defenders": {3: {"dodge_next_attack": 0}},
			"label": "supplied defender Dodge 0"},
		{"attacker": {"dodge_next_attack": 1, "blind_next_attack": 0}, "defenders": {},
			"label": "supplied attacker carrying both tokens"},
		{"attacker": {}, "defenders": {3: {"blind_next_attack": 1, "dodge_next_attack": 1}},
			"label": "supplied defender carrying both tokens"},
		{"attacker": {"dodge_next_attack": 1, "poison": 1}, "defenders": {},
			"label": "legal attacker token beside an unsupported status"},
		{"attacker": {}, "defenders": {3: {"blind_next_attack": 1, "poison": 1}},
			"label": "legal defender token beside an unsupported status"},
		{"attacker": {}, "defenders": {"3": {"blind_next_attack": 1}},
			"label": "String defender slot with a legal token"},
		{"attacker": {}, "defenders": {4: {"blind_next_attack": 1}},
			"label": "unoccupied defender slot with a legal token"},
	]
	for value in [-1, 2, 1.0, true, "1", null, [], {}]:
		card_cases.append({"attacker": {"dodge_next_attack": value}, "defenders": {},
			"label": "malformed supplied attacker Dodge " + str(value)})
		card_cases.append({"attacker": {}, "defenders": {3: {"blind_next_attack": value}},
			"label": "malformed supplied defender Blind " + str(value)})
	for request in card_cases:
		var service := CombatAttackCards.new()
		var deck := _deck(["seamstress_prick"])
		var party := _party()
		var enemies := _enemies([40, 40, 40])
		var before := _snapshot(deck, party, enemies)
		seed(3781)
		var next_global := randi()
		seed(3781)
		_check(service.forecast_attack(deck, party, enemies, "seamstress_prick",
			request["attacker"], request["defenders"])
			== {"playable": false, "requires_selection": false, "hits": []},
			request["label"] + ": forecast refuses")
		_check(_snapshot(deck, party, enemies) == before and randi() == next_global,
			request["label"] + ": forecast changes no deck, roster, passive or RNG")
		seed(9107)
		var play_global := randi()
		seed(9107)
		_reject(service, deck, party, enemies, "seamstress_prick", 3,
			request["label"], request["attacker"], request["defenders"])
		_check(randi() == play_global,
			request["label"] + ": rejected play consumes no global RNG")
	var slain := _enemies([40, 40, 40])
	_check(slain.apply_damage(3, 40) and slain.is_slain(3),
		"one-shot held-card rejection target truly slain")
	_reject(CombatAttackCards.new(), _deck(["seamstress_prick"]), _party(), slain,
		"seamstress_prick", 3, "slain target with legal Dodge/Blind tokens",
		{"dodge_next_attack": 1}, {3: {"blind_next_attack": 1}})
	for target in [0, 4]:
		_reject(CombatAttackCards.new(), _deck(["seamstress_prick"]), _party(),
			_enemies([40, 40, 40]), "seamstress_prick", target,
			"illegal target %d with legal Dodge/Blind tokens" % target,
			{"dodge_next_attack": 1}, {3: {"blind_next_attack": 1}})
	var downed := _party()
	_check(downed.apply_damage(2, 999) and downed.is_downed(2),
		"the one-shot owner is truly downed before the refusal")
	_reject(CombatAttackCards.new(), _deck(["seamstress_prick"]), downed,
		_enemies([40, 40, 40]), "seamstress_prick", 3,
		"downed Dodging owner with legal tokens", {"dodge_next_attack": 1},
		{3: {"blind_next_attack": 1}})
	var empty_energy := _deck(["seamstress_prick"])
	_check(empty_energy.try_spend_energy(3), "all energy spent before the one-shot refusal")
	_reject(CombatAttackCards.new(), empty_energy, _party(), _enemies([40, 40, 40]),
		"seamstress_prick", 3, "unaffordable Dodging owner with legal tokens",
		{"dodge_next_attack": 1}, {3: {"blind_next_attack": 1}})
	# The same preflight still accepts the corrected legal token pair, so none of
	# the refusals above can pass merely because every attack is broken.
	var legal_deck := _deck(["seamstress_prick"])
	var legal_party := _party()
	var legal_enemies := _enemies([40, 40, 40])
	legal_party._heroes[1]["statuses"] = {"dodge_next_attack": 1}
	legal_enemies._enemies[2]["statuses"] = {"blind_next_attack": 1}
	_check(CombatAttackCards.new().play_attack(legal_deck, legal_party, legal_enemies,
		"seamstress_prick", 3, {"dodge_next_attack": 1}, {3: {"blind_next_attack": 1}})
		== {"ok": true, "hits": [_hit(3, 3, 0, 3, {"bleed": 3})]},
		"the corrected supplied token pair still charges and lands the normal hit")
