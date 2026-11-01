extends SceneTree

var failures: Array[String] = []
var checks := 0
var service := CombatAttackTargeting.new()

const ATTACK_IDS := [
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]
const POOL_STRIKE_IDS := [
	"warden_brass_buckle", "warden_brass_buckle_plus",
	"seamstress_thread_whip", "seamstress_thread_whip_plus",
]
const SUPPORT_IDS := [
	"warden_brace", "seamstress_mend", "seamstress_stitch_up", "tinker_tune_up"
]
const CONTROL_IDS := [
	"seamstress_needle_pin", "seamstress_needle_pin_plus",
	"seamstress_snag", "seamstress_snag_plus",
	"seamstress_unpick", "seamstress_unpick_plus"
]
const SNAG_IDS := ["seamstress_snag", "seamstress_snag_plus"]


func _initialize() -> void:
	_test_authored_cards_and_freshness()
	_test_slain_positions()
	_test_hand_energy_and_turn()
	_test_owner_positions_and_downed()
	_test_unsupported_and_invalid()
	_test_pool_strikes()
	_test_seamstress_controls()
	_test_pool_combos_targeting()
	_test_pool_combo_forecasts()
	_test_seeded_replay()
	_test_upgraded_starter_targeting()
	for failure in failures:
		printerr(failure)
	print("combat_attack_targeting_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _deck(cards: Array[String], seed_value: int = 3271, start: bool = true) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(cards, rng)
	_check(deck.draw_pile.size() == cards.size(), "real deck initialized with all supplied cards")
	if start:
		_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
			"real seeded CombatDeck starts turn with three energy")
		_check(deck.hand.size() == mini(5, cards.size()), "real draw-five filled held hand")
	return deck


func _five_attacks() -> CombatDeck:
	var cards: Array[String] = []
	cards.assign(ATTACK_IDS)
	var deck := _deck(cards)
	for id in ATTACK_IDS:
		_check(deck.hand.has(id), "five-card draw holds offensive card " + id)
	return deck


func _party(order: Array[String] = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var definitions: Array = []
	for id in order:
		var max_hp := 40
		if id == "seamstress":
			max_hp = 30
		elif id == "tinker":
			max_hp = 26
		definitions.append({"id": id, "max_hp": max_hp, "tags": ["fixture"]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"party fixture is valid and actually has three heroes")
	return party


func _enemies(count: int = 3) -> CombatEnemies:
	var definitions: Array = []
	for i in range(count):
		definitions.append({"id": "synthetic_%d" % (i + 1), "max_hp": 12 + i,
			"tags": ["fixture"]})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == count,
		"real CombatEnemies fixture has " + str(count) + " occupied slots")
	return enemies


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var state := {}
	if deck != null:
		state["deck"] = [
			deck.draw_pile.duplicate(true), deck.hand.duplicate(true),
			deck.discard_pile.duplicate(true), deck.turn_active, deck.energy,
			deck.combat_state.player_turn_active, deck.combat_state.energy,
			deck._rng.seed, deck._rng.state
		]
	if party != null:
		state["party"] = party.get_heroes().duplicate(true)
	if enemies != null:
		state["enemies"] = enemies.get_enemies().duplicate(true)
	return state


func _assert_preview(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, expected_playable: bool, expected_selection: bool,
		expected_positions: Array, label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var preview := service.get_preview(deck, party, enemies, card_id)
	var keys := preview.keys()
	keys.sort()
	_check(keys == ["playable", "requires_selection", "target_positions"],
		label + ": exactly the three public response keys")
	_check(typeof(preview.get("playable")) == TYPE_BOOL
		and typeof(preview.get("requires_selection")) == TYPE_BOOL,
		label + ": boolean response values")
	_check(preview.get("target_positions") is Array
		and (preview["target_positions"] as Array).get_typed_builtin() == TYPE_INT,
		label + ": typed Array[int] target list")
	_check(preview == {
		"playable": expected_playable, "requires_selection": expected_selection,
		"target_positions": expected_positions
	}, label + ": exact playable, choice and position values")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": all hand/piles/energy/turn/HP/Block/RNG unchanged")
	var second := service.get_preview(deck, party, enemies, card_id)
	_check(second == preview, label + ": repeated preview is deterministic")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": repeated preview still has no side effects")


func _reject(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		id: String, label: String) -> void:
	_assert_preview(deck, party, enemies, id, false, false, [], label)


func _test_authored_cards_and_freshness() -> void:
	var deck := _five_attacks()
	var party := _party()
	var enemies := _enemies()
	_check(party.gain_block(2, 4) and enemies.gain_block(3, 2)
		and enemies.apply_damage(3, 3), "fixture includes nonzero Block and injured living enemy")
	_check(enemies.get_enemy(3)["hp"] == 13 and enemies.get_enemy(3)["block"] == 0,
		"damage from Block leaves enemy 3 living in its original slot")
	var catalog := StarterCards.new()
	# Verify concrete definitions rather than assuming a five-ID catalog or reauthoring rules.
	for id in ATTACK_IDS:
		var definition := catalog.get_definition(id)
		_check(not definition.is_empty() and definition["owner"] in ["warden", "seamstress", "tinker"],
			id + ": authoritative catalog owner exists")
		_check(definition["cost"] is int and definition["cost"] <= deck.energy
			and definition["from_positions"].has(
				1 if id.begins_with("warden") else 2 if id == "seamstress_prick" else 3),
			id + ": authoritative catalog permits the actual living owner")
		_check(definition["target_kind"] == ("enemy_all" if id == "tinker_scrap_bomb" else "enemy_single"),
			id + ": authoritative catalog kind")
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1, 2],
		"Strike reaches only front two enemies")
	_assert_preview(deck, party, enemies, "warden_shield_bash", true, true, [1],
		"Shield Bash reaches only enemy 1")
	_assert_preview(deck, party, enemies, "seamstress_prick", true, true, [1, 2, 3],
		"Prick reaches every living position as individual choices")
	_assert_preview(deck, party, enemies, "tinker_pop_shot", true, true, [1, 2, 3],
		"Pop Shot reaches every living position as individual choices")
	_assert_preview(deck, party, enemies, "tinker_scrap_bomb", true, false, [1, 2, 3],
		"Scrap Bomb affects every living enemy without target selection")

	var before := _snapshot(deck, party, enemies)
	var single := service.get_preview(deck, party, enemies, "warden_strike")
	(single["target_positions"] as Array).clear()
	(single["target_positions"] as Array).append(99)
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1, 2],
		"caller mutation of single-target result cannot poison next preview")
	var area := service.get_preview(deck, party, enemies, "tinker_scrap_bomb")
	(area["target_positions"] as Array).remove_at(0)
	(area["target_positions"] as Array).append(99)
	_assert_preview(deck, party, enemies, "tinker_scrap_bomb", true, false, [1, 2, 3],
		"caller mutation of affected-position result cannot poison next preview")
	_check(_snapshot(deck, party, enemies) == before,
		"mutation of returned lists cannot alter any model or RNG state")


func _test_slain_positions() -> void:
	var deck := _five_attacks()
	var party := _party()
	var enemies := _enemies()
	_check(enemies.apply_damage(2, 999) and enemies.is_slain(2)
		and enemies.get_enemy(2)["position"] == 2
		and enemies.get_enemy(3)["position"] == 3
		and not enemies.is_victorious(),
		"killing slot 2 preserves position of surviving slot 3, not victory")
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1],
		"Strike never compacts enemy 3 into slain slot 2")
	_assert_preview(deck, party, enemies, "warden_shield_bash", true, true, [1],
		"Shield Bash unaffected by slain enemy 2")
	for id in ["seamstress_prick", "tinker_pop_shot"]:
		_assert_preview(deck, party, enemies, id, true, true, [1, 3],
			id + ": only occupied living position IDs")
	_assert_preview(deck, party, enemies, "tinker_scrap_bomb", true, false, [1, 3],
		"area affected positions skip slain slot 2")

	_check(enemies.apply_damage(1, 999) and enemies.is_slain(1)
		and not enemies.is_victorious(), "two slain enemies leave last enemy alive")
	_reject(deck, party, enemies, "warden_strike", "Strike lacks any living enemy in reach")
	_reject(deck, party, enemies, "warden_shield_bash", "Shield Bash lacks a living enemy 1")
	for id in ["seamstress_prick", "tinker_pop_shot"]:
		_assert_preview(deck, party, enemies, id, true, true, [3],
			id + ": back-only living enemy remains targetable")
	_assert_preview(deck, party, enemies, "tinker_scrap_bomb", true, false, [3],
		"area no-choice still applies to lone surviving back enemy")
	_check(enemies.apply_damage(3, 999) and enemies.is_victorious()
		and enemies.get_enemies().size() == 3, "final enemy dies but all slots remain")
	for id in ATTACK_IDS:
		_reject(deck, party, enemies, id, id + ": all slain cannot be played")

	var one := _enemies(1)
	_assert_preview(deck, party, one, "tinker_scrap_bomb", true, false, [1],
		"one-enemy encounter gives area preview with one affected slot")
	_check(one.apply_damage(1, 999) and one.is_victorious(), "single enemy final death")
	_reject(deck, party, one, "tinker_scrap_bomb", "single slain enemy rejects area")
	var two := _enemies(2)
	_check(two.apply_damage(1, 999) and not two.is_victorious(),
		"two-enemy roster is not victorious after first kill")
	_assert_preview(deck, party, two, "warden_strike", true, true, [2],
		"remaining second slot can be targeted without compaction")


func _test_hand_energy_and_turn() -> void:
	var party := _party()
	var enemies := _enemies()
	var deck := _deck(["warden_strike", "tinker_pop_shot"])
	_reject(deck, party, enemies, "warden_shield_bash", "authored card absent from hand")
	_check(deck.discard_played("warden_strike") and not deck.hand.has("warden_strike"),
		"fixture removes actual held Strike copy through real deck API")
	_reject(deck, party, enemies, "warden_strike", "played/discarded copy no longer held")

	deck = _five_attacks()
	_check(deck.try_spend_energy(2) and deck.energy == 1, "one-energy fixture")
	_reject(deck, party, enemies, "warden_shield_bash", "Shield Bash cost two is unaffordable at one")
	_reject(deck, party, enemies, "tinker_scrap_bomb", "Scrap Bomb cost two is unaffordable at one")
	_assert_preview(deck, party, enemies, "seamstress_prick", true, true, [1, 2, 3],
		"cost-one Prick still affordable at one energy")
	_check(deck.try_spend_energy(1) and deck.energy == 0, "zero-energy fixture")
	for id in ATTACK_IDS:
		_reject(deck, party, enemies, id, id + ": zero energy rejects all attacks")

	var cards: Array[String] = []
	cards.assign(ATTACK_IDS)
	deck = _deck(cards, 17, false)
	_check(not deck.turn_active, "pre-start turn is genuinely inactive")
	_reject(deck, party, enemies, "warden_strike", "inactive turn before initial draw")
	_check(deck.start_turn() and deck.hand.size() == 5, "turn activation actually draws five")
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1, 2],
		"same deck allows preview while player turn active")
	_check(deck.end_turn() and not deck.turn_active and deck.hand.is_empty()
		and deck.discard_pile.size() == 5, "real end turn discards unplayed hand")
	_reject(deck, party, enemies, "warden_strike", "inactive turn after discard")
	_check(deck.start_turn(), "later turn starts with real discard reshuffle")
	_assert_preview(deck, party, enemies, "warden_shield_bash", true, true, [1],
		"new turn restores held copies and energy")


func _test_owner_positions_and_downed() -> void:
	var deck := _five_attacks()
	var enemies := _enemies()
	var party := _party(["seamstress", "warden", "tinker"])
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1, 2],
		"Warden moved to slot 2 still can Strike")
	_reject(deck, party, enemies, "warden_shield_bash", "Warden slot 2 cannot Shield Bash")
	_assert_preview(deck, party, enemies, "seamstress_prick", true, true, [1, 2, 3],
		"Seamstress slot 1 can Prick")

	party = _party(["seamstress", "tinker", "warden"])
	_reject(deck, party, enemies, "warden_strike", "Warden slot 3 cannot Strike")
	_reject(deck, party, enemies, "warden_shield_bash", "Warden slot 3 cannot Shield Bash")
	_assert_preview(deck, party, enemies, "tinker_pop_shot", true, true, [1, 2, 3],
		"Tinker slot 2 can Pop Shot")
	_reject(deck, party, enemies, "tinker_scrap_bomb", "Tinker slot 2 cannot Scrap Bomb")

	party = _party(["tinker", "warden", "seamstress"])
	_reject(deck, party, enemies, "tinker_pop_shot", "Tinker slot 1 cannot Pop Shot")
	_reject(deck, party, enemies, "tinker_scrap_bomb", "Tinker slot 1 cannot Scrap Bomb")
	_assert_preview(deck, party, enemies, "seamstress_prick", true, true, [1, 2, 3],
		"Seamstress slot 3 can Prick")

	# Every actual owner is checked independently, not by a hard-coded index.
	for owner in ["warden", "seamstress", "tinker"]:
		party = _party()
		var index := (["warden", "seamstress", "tinker"] as Array).find(owner) + 1
		_check(party.apply_damage(index, 999) and party.is_downed(index),
			owner + ": fixture actually downs card owner")
		for id in ATTACK_IDS:
			if StarterCards.new().get_definition(id)["owner"] == owner:
				_reject(deck, party, enemies, id, id + ": downed actual owner cannot attack")
	party = _party(["seamstress", "tinker", "outsider"])
	_reject(deck, party, enemies, "warden_strike", "no Warden owner in otherwise valid party")
	_reject(deck, party, enemies, "warden_shield_bash", "no Warden for Shield Bash")
	party = _party(["warden", "tinker", "outsider"])
	_reject(deck, party, enemies, "seamstress_prick", "no Seamstress owner in otherwise valid party")
	party = _party(["warden", "seamstress", "outsider"])
	_reject(deck, party, enemies, "tinker_pop_shot", "no Tinker owner for Pop Shot")
	_reject(deck, party, enemies, "tinker_scrap_bomb", "no Tinker owner for Scrap Bomb")


func _test_unsupported_and_invalid() -> void:
	var party := _party()
	var enemies := _enemies()
	var cards: Array[String] = []
	cards.assign(SUPPORT_IDS)
	cards.append("invented_enemy_attack")
	var deck := _deck(cards)
	for id in SUPPORT_IDS:
		_check(StarterCards.new().has_card(id) and deck.hand.has(id),
			id + ": supported catalog card is actually held")
		_reject(deck, party, enemies, id, id + ": support never gains enemy targets")
	_check(deck.hand.has("invented_enemy_attack"), "unknown card is deliberately held")
	_reject(deck, party, enemies, "invented_enemy_attack", "unknown even when held")
	_reject(deck, party, enemies, "", "empty ID fails closed")
	deck = _five_attacks()
	_reject(deck, null, enemies, "warden_strike", "null party preserves surviving deck and enemies")
	_reject(null, party, enemies, "warden_strike", "null deck preserves party and enemies")
	_reject(deck, party, null, "warden_strike", "null enemies preserves deck and party")
	_reject(deck, CombatParty.new([]), enemies, "warden_strike", "invalid empty party")
	_reject(deck, party, CombatEnemies.new([]), "warden_strike", "invalid empty enemy roster")
	_reject(deck, party, CombatEnemies.new([
		{"id": "duplicate", "max_hp": 12}, {"id": "duplicate", "max_hp": 12}
	]), "warden_strike", "invalid duplicate enemy roster")
	_reject(deck, CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26}
	]), enemies, "warden_strike", "invalid duplicate-owner party")


func _test_pool_strikes() -> void:
	# The starter enumeration mounted regressions iterate must stay starter-only.
	for id in POOL_STRIKE_IDS:
		_check(service.is_pool_strike(id) and service.supports(id),
			id + ": recognised as an authored pool strike")
		_check(not CombatAttackTargeting.ATTACK_IDS.has(id),
			id + ": never expands the starter ATTACK_IDS enumeration")
		var record := service.pool_definition(id)
		var owner_id := "warden" if id.begins_with("warden_") else "seamstress"
		_check(record.get("id") == id and record.get("owner") == owner_id,
			id + ": exact catalog record through the targeting lookup")
		_check(record.get("cost") == 1 and record.get("target_kind") == "enemy_single"
			and record.get("to_positions") == [1, 2], id + ": authored cost, kind and TO slots")
	for id in ATTACK_IDS:
		_check(service.supports(id) and not service.is_pool_strike(id),
			id + ": starter attack stays a starter attack")
	for id in ["warden_hold_the_line", "warden_patch_guard", "seamstress_darning", "tinker_tune_up"]:
		_check(not service.is_pool_strike(id) and not service.supports(id)
			and service.pool_definition(id).is_empty(), id + ": non-strike pool/support card stays rejected")

	var deck := _pool_strike_deck()
	var party := _party()
	var enemies := _enemies()
	for id in POOL_STRIKE_IDS:
		_assert_preview(deck, party, enemies, id, true, true, [1, 2],
			id + ": both authored enemy slots selectable")

	# Authored FROM slots: Brass Buckle reaches the front two heroes only.
	var middle := _party(["seamstress", "warden", "tinker"])
	for id in ["warden_brass_buckle", "warden_brass_buckle_plus"]:
		_assert_preview(deck, middle, enemies, id, true, true, [1, 2],
			id + ": Warden in slot two may play")
	var back := _party(["seamstress", "tinker", "warden"])
	for id in ["warden_brass_buckle", "warden_brass_buckle_plus"]:
		_reject(deck, back, enemies, id, id + ": Warden in forbidden slot three")
	# Thread Whip is authored from every hero slot.
	_assert_preview(deck, back, enemies, "seamstress_thread_whip", true, true, [1, 2],
		"Thread Whip from slot one")
	var seamstress_back := _party(["warden", "tinker", "seamstress"])
	_assert_preview(deck, seamstress_back, enemies, "seamstress_thread_whip_plus", true, true, [1, 2],
		"Thread Whip+ from slot three")

	# Missing and downed owners fail closed.
	_reject(deck, _party(["seamstress", "tinker", "outsider"]), enemies, "warden_brass_buckle",
		"no Warden owner for Brass Buckle")
	_reject(deck, _party(["warden", "tinker", "outsider"]), enemies, "seamstress_thread_whip",
		"no Seamstress owner for Thread Whip")
	var downed := _party()
	_check(downed.apply_damage(1, 999) and downed.is_downed(1), "Warden truly downed")
	_reject(deck, downed, enemies, "warden_brass_buckle", "downed Warden cannot Brass Buckle")
	_check(downed.apply_damage(2, 999) and downed.is_downed(2), "Seamstress truly downed")
	_reject(deck, downed, enemies, "seamstress_thread_whip", "downed Seamstress cannot Thread Whip")

	# Cost is paid from the real shared deck.
	var poor := _pool_strike_deck()
	_check(poor.try_spend_energy(3) and poor.energy == 0, "zero-energy pool deck")
	for id in POOL_STRIKE_IDS:
		_reject(poor, party, enemies, id, id + ": cost one unaffordable at zero energy")
	var absent := _pool_strike_deck()
	for id in POOL_STRIKE_IDS:
		_check(absent.discard_played(id), "remove actual held " + id)
		_reject(absent, party, enemies, id, id + ": absent held copy")
	_reject(deck, party, enemies, "warden_brass_buckle_missing", "unknown pool-like ID fails closed")

	# Slain and absent slots keep their original numbering.
	_check(enemies.apply_damage(2, 999) and enemies.is_slain(2), "slot two slain in place")
	for id in POOL_STRIKE_IDS:
		_assert_preview(deck, party, enemies, id, true, true, [1], id + ": slain slot two excluded")
	_check(enemies.apply_damage(1, 999) and enemies.is_slain(1), "slot one also slain")
	for id in POOL_STRIKE_IDS:
		_reject(deck, party, enemies, id, id + ": only enemy three lies outside the authored TO slots")
	var lone := _enemies(1)
	for id in POOL_STRIKE_IDS:
		_assert_preview(deck, party, lone, id, true, true, [1], id + ": lone front enemy stays legal")
	var two := _enemies(2)
	_check(two.apply_damage(1, 999) and not two.is_victorious(), "front enemy slain in a two-enemy roster")
	for id in POOL_STRIKE_IDS:
		_assert_preview(deck, party, two, id, true, true, [2], id + ": surviving slot two stays targetable")

	# Returned lists stay detached, exactly like starter previews.
	var before := _snapshot(deck, party, two)
	var preview := service.get_preview(deck, party, two, "warden_brass_buckle")
	(preview["target_positions"] as Array).clear()
	(preview["target_positions"] as Array).append(99)
	_assert_preview(deck, party, two, "warden_brass_buckle", true, true, [2],
		"caller mutation of a pool result cannot poison the next preview")
	_check(_snapshot(deck, party, two) == before, "pool preview mutation leaves every model and RNG intact")


func _control_deck() -> CombatDeck:
	var cards: Array[String] = []
	cards.assign(CONTROL_IDS)
	var deck := _deck(cards, 7331)
	_check(deck.draw_extra(1) == 1 and deck.hand.size() == CONTROL_IDS.size(),
		"real seeded draw holds all six authored control variants")
	for id in CONTROL_IDS:
		_check(deck.hand.has(id), "real hand holds authored control " + id)
	return deck


## The six authored Seamstress enemy-control variants join the read-only picker
## through their exact catalog records, while leaving starter-only ATTACK_IDS
## and every other card family's admission untouched.
func _test_seamstress_controls() -> void:
	var control_catalog := SeamstressPoolCards.new()
	for id in CONTROL_IDS:
		_check(service.is_seamstress_control(id) and service.supports(id),
			id + ": recognised as an authored Seamstress control card")
		_check(not CombatAttackTargeting.ATTACK_IDS.has(id),
			id + ": never expands the starter ATTACK_IDS enumeration")
		_check(not service.is_pool_strike(id) and not service.is_heavy_pool_attack(id)
			and not service.is_sight_glass(id),
			id + ": keeps its own resolver family")
		var record := service.control_definition(id)
		var authored: Dictionary = control_catalog.get_definition(id)
		_check(record.get("id") == id and record.get("owner") == "seamstress"
			and record.get("cost") == authored.get("cost")
			and record.get("target_kind") == "enemy_single"
			and record.get("to_positions") == [1, 2, 3]
			and record.get("from_positions") == authored.get("from_positions")
			and record.get("effects") == authored.get("effects"),
			id + ": exact authored cost, FROM/TO slots and effects through the picker")
		_check(record.get("cost") == 1 and not (record.get("effects", {}) as Dictionary).is_empty(),
			id + ": cost one with its authored effect record")

	var deck := _control_deck()
	var party := _party()
	var enemies := _enemies()
	for id in CONTROL_IDS:
		_assert_preview(deck, party, enemies, id, true, true, [1, 2, 3],
			id + ": every living enemy slot is a real choice")

	# Snag is authored from the middle or back hero slot only.
	for id in SNAG_IDS:
		_reject(deck, _party(["seamstress", "warden", "tinker"]), enemies, id,
			id + ": forbidden front Seamstress slot")
		for owner_slot in [2, 3]:
			var order: Array[String] = ["warden", "seamstress", "tinker"]
			if owner_slot == 3:
				order = ["warden", "tinker", "seamstress"]
			_assert_preview(deck, _party(order), enemies, id, true, true, [1, 2, 3],
				id + ": authored slot %d allows the cast" % owner_slot)
	# Needle Pin and Unpick are authored from every hero slot.
	for id in [CONTROL_IDS[0], CONTROL_IDS[1], CONTROL_IDS[4], CONTROL_IDS[5]]:
		for order in [["seamstress", "warden", "tinker"], ["warden", "tinker", "seamstress"]]:
			var typed_order: Array[String] = []
			typed_order.assign(order)
			_assert_preview(deck, _party(typed_order), enemies, id, true, true, [1, 2, 3],
				id + ": castable from the real owner slot")

	# Missing and downed owners fail closed.
	for id in CONTROL_IDS:
		_reject(deck, _party(["warden", "tinker", "outsider"]), enemies, id,
			id + ": no Seamstress owner in an otherwise valid party")
		var downed := _party()
		_check(downed.apply_damage(2, 999) and downed.is_downed(2), "Seamstress truly downed")
		_reject(deck, downed, enemies, id, id + ": downed Seamstress cannot cast")

	# Cost is paid from the real shared deck.
	var poor := _control_deck()
	_check(poor.try_spend_energy(3) and poor.energy == 0, "zero-energy control deck")
	for id in CONTROL_IDS:
		_reject(poor, party, enemies, id, id + ": cost one unaffordable at zero energy")
	var absent := _control_deck()
	for id in CONTROL_IDS:
		_check(absent.discard_played(id), "remove actual held " + id)
		_reject(absent, party, enemies, id, id + ": absent held copy")

	# Slain and absent slots keep their original numbering.
	_check(enemies.apply_damage(2, 999) and enemies.is_slain(2), "slot two slain in place")
	for id in CONTROL_IDS:
		_assert_preview(deck, party, enemies, id, true, true, [1, 3],
			id + ": slain slot two excluded and never compacted")
	_check(enemies.apply_damage(1, 999) and enemies.is_slain(1), "slot one also slain")
	for id in CONTROL_IDS:
		_assert_preview(deck, party, enemies, id, true, true, [3],
			id + ": only the surviving back slot is selectable")
	var lone := _enemies(1)
	for id in CONTROL_IDS:
		_assert_preview(deck, party, lone, id, true, true, [1],
			id + ": lone front enemy stays legal")
	_check(lone.apply_damage(1, 999) and lone.is_victorious(), "lone enemy truly slain")
	for id in CONTROL_IDS:
		_reject(deck, party, lone, id, id + ": no living control target")

	# Snag's Weak preflight excludes an overflowing slot without hiding the rest.
	var overflow := _enemies()
	overflow._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	_assert_preview(deck, party, overflow, "seamstress_snag", true, true, [2, 3],
		"Snag skips only the Weak-saturated slot")
	_assert_preview(deck, party, overflow, "seamstress_unpick", true, true, [1, 2, 3],
		"Unpick never applies Weak and keeps the saturated slot")

	# Returned lists stay detached, exactly like the other picker families.
	var before := _snapshot(deck, party, overflow)
	var preview := service.get_preview(deck, party, overflow, "seamstress_unpick")
	(preview["target_positions"] as Array).clear()
	(preview["target_positions"] as Array).append(99)
	_assert_preview(deck, party, overflow, "seamstress_unpick", true, true, [1, 2, 3],
		"caller mutation of a control result cannot poison the next preview")
	_check(_snapshot(deck, party, overflow) == before, "control preview mutation leaves models and RNG intact")

	# Other pool families and unknown IDs stay out of control admission.
	for id in ["seamstress_darning", "seamstress_blanket_stitch", "seamstress_thread_whip",
			"seamstress_hemorrhage_hem", "tinker_sight_glass", "invented_control"]:
		_check(not service.is_seamstress_control(id)
			and service.control_definition(id).is_empty(),
			id + ": not an authored Seamstress control card")
	for id in ["seamstress_darning", "seamstress_blanket_stitch", "seamstress_hemorrhage_hem"]:
		_check(not service.supports(id), id + ": other Seamstress pool card stays unsupported here")
	_check(service.control_definition("").is_empty(), "empty control ID fails closed")


func _pool_strike_deck(seed_value: int = 4211) -> CombatDeck:
	var cards: Array[String] = []
	cards.assign(POOL_STRIKE_IDS)
	var deck := _deck(cards, seed_value)
	for id in POOL_STRIKE_IDS:
		_check(deck.hand.has(id), "real seeded draw holds pool strike " + id)
	return deck


func _test_seeded_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var cards: Array[String] = []
		cards.assign(ATTACK_IDS)
		var deck := _deck(cards, seed_value)
		var party := _party()
		var enemies := _enemies()
		var before := _snapshot(deck, party, enemies)
		var first: Array = []
		for id in ATTACK_IDS:
			first.append(service.get_preview(deck, party, enemies, id))
		for id in ATTACK_IDS:
			var preview := service.get_preview(deck, party, enemies, id)
			_check(preview == first[ATTACK_IDS.find(id)],
				"seed " + str(seed_value) + ": repeated " + id + " yields same preview")
		_check(_snapshot(deck, party, enemies) == before,
			"seed " + str(seed_value) + ": preview sequence consumes no RNG or model state")


const COMBO_IDS := [
	"warden_pinning_jab", "warden_pinning_jab_plus",
	"warden_seam_breaker", "warden_seam_breaker_plus",
	"tinker_spool_launcher", "tinker_spool_launcher_plus",
	"tinker_snip_the_seam", "tinker_snip_the_seam_plus",
]


func _combo_battle(card_id: String, options: Dictionary = {}) -> Dictionary:
	var cards: Array[String] = []
	for i in range(5):
		cards.append(card_id)
	var deck := _deck(cards, 6721)
	_check(deck.hand.has(card_id), card_id + ": real seeded five-card hand")
	var order: Array[String] = ["warden", "seamstress", "tinker"]
	if options.has("order"):
		order.assign(options["order"])
	var party := _party(order)
	var definitions: Array = []
	for i in range(3):
		definitions.append({"id": "combo_enemy_%d" % (i + 1), "max_hp": 90})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid(), "three independent living combat enemy slots exist")
	var pinned := CombatPinned.new()
	var unravel := CombatUnravel.new()
	_check(unravel.bind_roster(enemies, {1: "normal", 2: "elite", 3: "boss"}),
		"genuine three-tier Unravel bound to the exact enemy instance")
	var first := CombatTinkerFirstAttack.new()
	var target: int = options.get("target", 1)
	var charge: int = options.get("charge", 0)
	if charge > 0:
		_check(unravel.apply_unravel(enemies, target, charge),
			"charge seeded with real CombatUnravel.apply_unravel")
	var owner: String = options.get("pinner", "")
	if not owner.is_empty():
		_check(pinned.pin_enemy(enemies, target, owner),
			"pin owner seeded with real CombatPinned.pin_enemy")
	if options.get("spent_first", false):
		_check(first.record_successful_attack("tinker_pop_shot"),
			"first attack latch consumed by an actual Tinker attack ID")
	if options.get("weak", false):
		var owner_position: int = 1 if card_id.begins_with("warden_") else 3
		for hero in party.get_heroes():
			if hero["id"] == ("warden" if owner_position == 1 else "tinker"):
				owner_position = hero["position"]
		party._heroes[owner_position - 1]["statuses"] = {"weak": 2}
	if options.get("exposed", false):
		_check(enemies.apply_statuses({target: {"exposed": 2}}),
			"Exposed seeded with authoritative enemy status API")
	if options.get("block", 0) > 0:
		_check(enemies.gain_block(target, options["block"]),
			"Block seeded through enemy API")
	if options.get("hp", 90) < 90:
		_check(enemies.apply_damage(target, 90 - int(options["hp"])),
			"near-lethal target seeded through enemy damage API")
	return {"deck": deck, "party": party, "enemies": enemies,
		"pinned": pinned, "unravel": unravel, "first": first}


func _combo_state(fixture: Dictionary) -> Dictionary:
	var deck: CombatDeck = fixture["deck"]
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var pinned: CombatPinned = fixture["pinned"]
	var unravel: CombatUnravel = fixture["unravel"]
	var first: CombatTinkerFirstAttack = fixture["first"]
	var gauges: Dictionary = {}
	for i in range(1, enemies.get_enemies().size() + 1):
		gauges[i] = unravel.get_snapshot(i)
	return {
		"battle": _snapshot(deck, party, enemies),
		"pinned": pinned._pinner_by_position.duplicate(true),
		"tiers": unravel._tiers_by_position.duplicate(true),
		"gauges": gauges,
		"bound_identity": unravel._bound_enemies == enemies,
		"first_consumed": first._consumed
	}


func _combo_preview(fixture: Dictionary, id: String, position: int = 0) -> Dictionary:
	return CombatPoolComboAttackPreview.new().get_preview(
		fixture["deck"], fixture["party"], fixture["enemies"],
		fixture["pinned"], fixture["unravel"], fixture["first"], id, position)


func _combo_assert_refusal(fixture: Dictionary, id: String, target: int, label: String) -> void:
	var before: Dictionary = _combo_state(fixture)
	var forecast: Dictionary = _combo_preview(fixture, id, target)
	_check(forecast.get("playable") == false and forecast.get("targets", [99]).is_empty()
		and forecast.get("target_positions", [99]).is_empty(),
		label + ": unavailable, no advertised hit or slot")
	_check(_combo_state(fixture) == before, label + ": refusal leaves entire battle and RNG unchanged")


func _test_pool_combos_targeting() -> void:
	var warden_catalog := WardenPoolCards.new()
	var tinker_catalog := TinkerPoolCards.new()
	for id in COMBO_IDS:
		var warden: bool = id.begins_with("warden_")
		var definition: Dictionary = (warden_catalog.get_definition(id) if warden
			else tinker_catalog.get_definition(id))
		_check(not definition.is_empty() and service.is_pool_combo_attack(id)
			and service.supports(id), id + ": exact supported authored combo ID")
		_check(service.combo_definition(id) == definition,
			id + ": picker returns independently copied complete catalog record")
		_check(not CombatAttackTargeting.ATTACK_IDS.has(id)
			and not service.is_pool_strike(id) and not service.is_heavy_pool_attack(id),
			id + ": starter and other pool lists unchanged")
		var deck_fixture: Dictionary = _combo_battle(id)
		var targets: Array = [1] if id.begins_with("warden_pinning_jab") else \
			[1, 2] if id.begins_with("warden_") else [1, 2, 3]
		_assert_preview(deck_fixture["deck"], deck_fixture["party"], deck_fixture["enemies"],
			id, true, true, targets, id + ": exact original authored targets")
		var wrong_order: Array[String] = []
		wrong_order.assign(["seamstress", "tinker", "warden"] if warden else
			["tinker", "warden", "seamstress"])
		var wrong: CombatParty = _party(wrong_order)
		_reject(deck_fixture["deck"], wrong, deck_fixture["enemies"], id,
			id + ": owner in forbidden position")
		var movable_order: Array[String] = []
		movable_order.assign(["seamstress", "warden", "tinker"] if warden else
			["warden", "tinker", "seamstress"])
		_assert_preview(deck_fixture["deck"], _party(movable_order), deck_fixture["enemies"],
			id, true, true, targets, id + ": legal owner swap")
		var downed: CombatParty = _party()
		var owner_position: int = 1 if warden else 3
		_check(downed.apply_damage(owner_position, 999) and downed.is_downed(owner_position),
			"actual combo owner downed")
		_reject(deck_fixture["deck"], downed, deck_fixture["enemies"], id,
			id + ": downed owner")
		var poor: Dictionary = _combo_battle(id)
		var cost: int = definition["cost"]
		if cost == 2:
			_check(poor["deck"].try_spend_energy(2) and poor["deck"].energy == 1,
				"cost two fixture has one energy remaining")
			_reject(poor["deck"], poor["party"], poor["enemies"], id,
				id + ": energy one refuses cost two")
		_check(poor["deck"].try_spend_energy(poor["deck"].energy)
			and poor["deck"].energy == 0, "cost one/two fixture reaches zero energy")
		_reject(poor["deck"], poor["party"], poor["enemies"], id,
			id + ": energy zero refusal")
		var absent: Dictionary = _combo_battle(id)
		while absent["deck"].hand.has(id):
			_check(absent["deck"].discard_played(id), id + ": discarded genuine held card")
		_reject(absent["deck"], absent["party"], absent["enemies"], id,
			id + ": no held card")
		var spent: Dictionary = _combo_battle(id)
		_check(spent["deck"].end_turn() and not spent["deck"].turn_active,
			id + ": turn genuinely ended")
		_reject(spent["deck"], spent["party"], spent["enemies"], id,
			id + ": ended-turn rejection")
		var dead: Dictionary = _combo_battle(id)
		_check(dead["enemies"].apply_damage(1, 999) and dead["enemies"].is_slain(1),
			id + ": original slot one slain in place")
		if id.begins_with("warden_pinning_jab"):
			_reject(dead["deck"], dead["party"], dead["enemies"], id,
				id + ": only pinned target slain")
		else:
			var survivors: Array = [2] if warden else [2, 3]
			_assert_preview(dead["deck"], dead["party"], dead["enemies"],
				id, true, true, survivors, id + ": original slots never compact")
	_check(not service.supports("tinker_shrapnel_seam")
		and service.combo_definition("tinker_shrapnel_seam").is_empty()
		and not service.supports("warden_pinning_jab_fake")
		and not service.supports("unknown_never_authored"),
		"unrelated area and invented IDs remain unsupported")


func _combo_compare_oracle(id: String, options: Dictionary) -> void:
	var source: Dictionary = _combo_battle(id, options)
	var oracle: Dictionary = _combo_battle(id, options)
	var target: int = options.get("target", 1)
	var label: String = id + " target %d options %s" % [target, str(options)]
	var actual_before: Dictionary = _combo_state(source)
	var preflight: bool
	if id.begins_with("warden_"):
		preflight = CombatWardenPoolComboAttacks.new().can_play(
			oracle["deck"], oracle["party"], oracle["enemies"], oracle["pinned"],
			oracle["unravel"], id, target)
	else:
		preflight = CombatTinkerPoolUnravelAttacks.new(
			oracle["first"], oracle["unravel"], oracle["pinned"]).can_play(
			oracle["deck"], oracle["party"], oracle["enemies"], id, target)
	_check(preflight and actual_before["bound_identity"], label + ": actual resolver can-play")
	var forecast: Dictionary = _combo_preview(source, id, target)
	_check(forecast.get("playable", false) and forecast.get("requires_selection", false)
		and forecast.get("targets", []).size() == 1,
		label + ": one inspectable forecast for chosen legal target")
	_check(_combo_state(source) == actual_before,
		label + ": immediately after forecast full deck, actors, pins, gauges, RNG, latch unchanged")
	if not forecast.get("playable", false) or forecast.get("targets", []).size() != 1:
		return
	var predicted: Dictionary = forecast["targets"][0]
	var before_gauge: Dictionary = oracle["unravel"].get_snapshot(target)
	var prior_owner: String = oracle["pinned"].pinner_for_enemy(target)
	var prior_pin_bonus: int = oracle["pinned"].bonus_for_attack(oracle["enemies"],
		target, "warden" if id.begins_with("warden_") else "tinker")
	var oracle_result: Dictionary
	if id.begins_with("warden_"):
		oracle_result = CombatWardenPoolComboAttacks.new().play_attack(
			oracle["deck"], oracle["party"], oracle["enemies"], oracle["pinned"],
			oracle["unravel"], id, target)
	else:
		oracle_result = CombatTinkerPoolUnravelAttacks.new(
			oracle["first"], oracle["unravel"], oracle["pinned"]).play_attack(
			oracle["deck"], oracle["party"], oracle["enemies"], id, target)
	_check(oracle_result.get("ok", false), label + ": detached real combat resolver paid and hit")
	if not oracle_result.get("ok", false):
		return
	var hit: Dictionary = oracle_result["hits"][0]
	var after_enemy: Dictionary = oracle["enemies"].get_enemy(target)
	_check(predicted["position"] == target and predicted["damage"] == hit["damage"]
		and predicted["block_absorbed"] == hit["block_absorbed"]
		and predicted["hp_loss"] == hit["hp_loss"]
		and predicted["hp_after"] == after_enemy["hp"]
		and predicted["block_after"] == after_enemy["block"],
		label + ": exact authoritative damage, absorbed Block, HP loss and final stats")
	_check(predicted["pin_bonus"] == prior_pin_bonus
		and predicted["pin_owner_before"] == prior_owner
		and predicted["pin_owner_after"] == oracle["pinned"].pinner_for_enemy(target)
		and predicted["pin_consumed"] == (prior_pin_bonus > 0),
		label + ": genuine Pinned bonus, same-owner persistence, repin or consumption")
	var charged_by_resolver: int = (hit.get("unravel_added", 0)
		if id.begins_with("warden_") else hit.get("unravel", 0))
	_check(predicted["unravel_before"] == before_gauge
		and predicted["unravel_after"] == oracle["unravel"].get_snapshot(target)
		and predicted["unravel_added"] == charged_by_resolver,
		label + ": exact authoritative Unravel gauge charge and snapshot")
	var actual_first_bonus: int = 0
	if id.begins_with("tinker_") and not options.get("spent_first", false):
		actual_first_bonus = 3
	_check(predicted["tinker_first_attack_bonus"] == actual_first_bonus,
		label + ": shared Tinker first-attack latch accurately reported")
	if id.begins_with("tinker_snip_the_seam"):
		var empowered: bool = before_gauge["unravelled"] or before_gauge["skip_pending"] \
			or before_gauge["gauge"] * 2 >= before_gauge["threshold"]
		_check(predicted["conditional_empowered"] == empowered,
			label + ": Snip half-threshold and Unravelled branch reported")
	if predicted["unravel_after"]["skip_pending"] and after_enemy["hp"] > 0:
		_check(oracle["unravel"].consume_action_skip(oracle["enemies"], target)
			and predicted["after_action_skip"] == oracle["unravel"].get_snapshot(target),
			label + ": queued skip forecasts exact reset to 0 and threshold +4")
	else:
		_check(predicted["after_action_skip"].is_empty(),
			label + ": no invented skip consumption")
	var followup: Dictionary = _combo_preview(source, id, target)
	_check(forecast == followup and _combo_state(source) == actual_before,
		label + ": deterministic independent repeat, zero live writes")
	(predicted["unravel_after"] as Dictionary)["gauge"] = -999
	(forecast["target_positions"] as Array).clear()
	_check(_combo_preview(source, id, target) == followup
		and _combo_state(source) == actual_before,
		label + ": caller corrupting returned nested gauge and slots cannot poison preview")


func _test_pool_combo_forecasts() -> void:
	for id in COMBO_IDS:
		_combo_compare_oracle(id, {"target": 1})
		_combo_compare_oracle(id, {"target": 1, "pinner": "tinker" if id.begins_with("warden_")
			else "warden", "weak": true, "exposed": true, "block": 9})
		if not id.begins_with("warden_pinning_jab"):
			_combo_compare_oracle(id, {"target": 2, "charge": 6, "spent_first": true})
		if id.begins_with("tinker_"):
			_combo_compare_oracle(id, {"target": 3, "charge": 8, "exposed": true})
	_combo_compare_oracle("warden_pinning_jab", {"target": 1, "pinner": "warden"})
	_combo_compare_oracle("warden_pinning_jab_plus", {"target": 1, "pinner": "seamstress"})
	_combo_compare_oracle("warden_pinning_jab", {"target": 1, "pinner": "tinker", "hp": 1})
	_combo_compare_oracle("warden_seam_breaker", {"target": 1, "charge": 4})
	_combo_compare_oracle("warden_seam_breaker_plus", {"target": 2, "charge": 11})
	_combo_compare_oracle("tinker_spool_launcher_plus", {"target": 3, "charge": 15})
	_combo_compare_oracle("tinker_spool_launcher", {"target": 1, "charge": 7})
	_combo_compare_oracle("tinker_spool_launcher", {"target": 1, "hp": 1})
	# Snip below/at half in each tier, and while already Unravelled.
	for id in ["tinker_snip_the_seam", "tinker_snip_the_seam_plus"]:
		for item in [[1, 3], [1, 4], [1, 8], [2, 5], [2, 6], [2, 12],
				[3, 7], [3, 8], [3, 16]]:
			_combo_compare_oracle(id, {"target": item[0], "charge": item[1]})
	var fixture: Dictionary = _combo_battle("tinker_spool_launcher")
	var first_snapshot: Dictionary = _combo_state(fixture)
	var all_targets: Dictionary = _combo_preview(fixture, "tinker_spool_launcher")
	_check(all_targets["playable"] and all_targets["target_positions"] == [1, 2, 3]
		and all_targets["targets"].size() == 3,
		"one forecast exposes every living original slot, with distinct per-target details")
	_check(_combo_state(fixture) == first_snapshot, "full multi-target simulation never commits")
	_combo_assert_refusal(fixture, "invented_not_a_card", 1, "genuinely unknown ID")
	_combo_assert_refusal(fixture, "tinker_shrapnel_seam", 1, "unrelated area attack")
	_combo_assert_refusal(fixture, "tinker_spool_launcher", 4, "illegal target slot")
	_combo_assert_refusal(fixture, "tinker_spool_launcher", -1, "negative target slot")
	var other_roster: CombatEnemies = _enemies()
	var mismatched: CombatUnravel = CombatUnravel.new()
	_check(mismatched.bind_roster(other_roster, {1: "normal", 2: "elite", 3: "boss"}),
		"gauge bound to genuinely different roster")
	var original_unravel: CombatUnravel = fixture["unravel"]
	fixture["unravel"] = mismatched
	_combo_assert_refusal(fixture, "tinker_spool_launcher", 1, "mismatched gauge roster")
	fixture["unravel"] = CombatUnravel.new()
	_combo_assert_refusal(fixture, "tinker_spool_launcher", 1, "unbound gauge")
	fixture["unravel"] = original_unravel
	fixture["unravel"]._gauges.erase(1)
	_combo_assert_refusal(fixture, "tinker_spool_launcher", 1, "missing current gauge slot")
	fixture = _combo_battle("warden_pinning_jab")
	fixture["unravel"]._gauges[1]["threshold"] = 9
	_combo_assert_refusal(fixture, "warden_pinning_jab", 1, "corrupt non-authoritative threshold")
	fixture = _combo_battle("warden_seam_breaker")
	_check(fixture["deck"].try_spend_energy(2) and fixture["deck"].energy == 1,
		"Seam Breaker insufficient energy precondition")
	_combo_assert_refusal(fixture, "warden_seam_breaker", 1, "cost-two at one energy")
	fixture = _combo_battle("tinker_spool_launcher")
	_check(fixture["party"].apply_damage(3, 999) and fixture["party"].is_downed(3),
		"Tinker physically downed before effect forecast")
	_combo_assert_refusal(fixture, "tinker_spool_launcher", 1, "downed source")
	fixture = _combo_battle("warden_pinning_jab")
	_check(fixture["enemies"].apply_damage(1, 999) and fixture["enemies"].is_slain(1),
		"pinned Jab only possible target slain before effect forecast")
	_combo_assert_refusal(fixture, "warden_pinning_jab", 1, "slain target")
	fixture = _combo_battle("tinker_snip_the_seam")
	_check(fixture["deck"].end_turn(), "turn ended through deck API")
	_combo_assert_refusal(fixture, "tinker_snip_the_seam", 1, "ended player turn")
	fixture = _combo_battle("tinker_snip_the_seam")
	while fixture["deck"].hand.has("tinker_snip_the_seam"):
		_check(fixture["deck"].discard_played("tinker_snip_the_seam"),
			"all Snips really removed from hand")
	_combo_assert_refusal(fixture, "tinker_snip_the_seam", 1, "out-of-hand Snip")
	fixture = _combo_battle("tinker_spool_launcher")
	var before: Dictionary = _combo_state(fixture)
	var rejected: Dictionary = CombatPoolComboAttackPreview.new().get_preview(
		fixture["deck"], fixture["party"], fixture["enemies"],
		fixture["pinned"], fixture["unravel"], null, "tinker_spool_launcher")
	_check(not rejected["playable"] and rejected["targets"].is_empty()
		and _combo_state(fixture) == before,
		"missing first-attack latch fails closed without side effects")


func _test_upgraded_starter_targeting() -> void:
	# Authoritative admission
	_check(service.supports("seamstress_prick_plus"), "seamstress_prick_plus is supported")
	_check(service.supports("warden_shield_bash_plus"), "warden_shield_bash_plus is supported")
	_check(CombatAttackTargeting.ATTACK_IDS.has("seamstress_prick_plus"), "seamstress_prick_plus in ATTACK_IDS")
	_check(CombatAttackTargeting.ATTACK_IDS.has("warden_shield_bash_plus"), "warden_shield_bash_plus in ATTACK_IDS")

	# Unsupported upgrades fail closed
	for unsupported_id in ["tinker_pop_shot_plus", "tinker_scrap_bomb_plus", "warden_brace_plus", "seamstress_mend_plus"]:
		_check(not service.supports(unsupported_id), unsupported_id + " is not supported")
		_check(not CombatAttackTargeting.ATTACK_IDS.has(unsupported_id), unsupported_id + " not in ATTACK_IDS")

	# Real deck with upgraded cards
	var catalog := StarterCards.new()
	var starting_cards := catalog.get_starting_deck()
	var prick_idx := starting_cards.find("seamstress_prick")
	var upgraded_prick := RunRestCardUpgrade.new(starting_cards, {"seamstress_prick": "seamstress_prick_plus"}).choose_upgrade(prick_idx)
	_check(upgraded_prick.ok, "upgraded prick created via Rest upgrade")
	var bash_idx := (upgraded_prick.deck as Array[String]).find("warden_shield_bash")
	var upgraded_both := RunRestCardUpgrade.new(upgraded_prick.deck, {"warden_shield_bash": "warden_shield_bash_plus"}).choose_upgrade(bash_idx)
	_check(upgraded_both.ok, "upgraded both cards via Rest upgrade")

	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var deck := CombatDeck.new(upgraded_both.deck, rng)
	_check(deck.start_turn() and deck.energy == 3, "start turn with 3 energy")
	while (not deck.hand.has("seamstress_prick_plus") or not deck.hand.has("warden_shield_bash_plus")) and not deck.draw_pile.is_empty():
		deck.draw_extra(1)
	_check(deck.hand.has("seamstress_prick_plus") and deck.hand.has("warden_shield_bash_plus"),
		"both upgraded cards held in real hand")

	# AC1: Seamstress Prick+
	# Living Seamstress in positions 1, 2, or 3 reaches all living enemies in positions 1, 2, 3
	for pos in [1, 2, 3]:
		var party_order: Array[String] = []
		if pos == 1:
			party_order.assign(["seamstress", "warden", "tinker"])
		elif pos == 2:
			party_order.assign(["warden", "seamstress", "tinker"])
		else:
			party_order.assign(["warden", "tinker", "seamstress"])
		var party := _party(party_order)
		var enemies := _enemies(3)
		_assert_preview(deck, party, enemies, "seamstress_prick_plus", true, true, [1, 2, 3],
			"Prick+ from Seamstress position %d reaches [1, 2, 3]" % pos)

	# Slain enemy slots: skips slain slot 2 -> [1, 3]
	var foes := _enemies(3)
	_check(foes.apply_damage(2, 999) and foes.is_slain(2), "slay enemy 2")
	_assert_preview(deck, _party(), foes, "seamstress_prick_plus", true, true, [1, 3],
		"Prick+ skips slain enemy 2")
	_check(foes.apply_damage(1, 999) and foes.is_slain(1), "slay enemy 1")
	_assert_preview(deck, _party(), foes, "seamstress_prick_plus", true, true, [3],
		"Prick+ targets surviving enemy 3")
	_check(foes.apply_damage(3, 999) and foes.is_victorious(), "slay enemy 3 (all slain)")
	_reject(deck, _party(), foes, "seamstress_prick_plus", "Prick+ all slain rejects")

	# Negative checks for Prick+
	var downed_seamstress := _party()
	_check(downed_seamstress.apply_damage(2, 999) and downed_seamstress.is_downed(2), "down Seamstress")
	_reject(deck, downed_seamstress, _enemies(), "seamstress_prick_plus", "Prick+ downed Seamstress rejects")

	var absent_seamstress_order: Array[String] = []
	absent_seamstress_order.assign(["warden", "tinker", "other"])
	var absent_seamstress := _party(absent_seamstress_order)
	_reject(deck, absent_seamstress, _enemies(), "seamstress_prick_plus", "Prick+ absent Seamstress rejects")

	# AC2: Warden Shield Bash+
	# Cost 2, FROM [1], TO [1]
	var warden_front := _party()
	var standard_foes := _enemies(3)
	_assert_preview(deck, warden_front, standard_foes, "warden_shield_bash_plus", true, true, [1],
		"Shield Bash+ exposes only position 1")

	# Warden in position 2 or 3 is rejected
	var warden_mid_order: Array[String] = []
	warden_mid_order.assign(["seamstress", "warden", "tinker"])
	_reject(deck, _party(warden_mid_order), standard_foes, "warden_shield_bash_plus",
		"Shield Bash+ Warden in position 2 rejects")
	var warden_back_order: Array[String] = []
	warden_back_order.assign(["seamstress", "tinker", "warden"])
	_reject(deck, _party(warden_back_order), standard_foes, "warden_shield_bash_plus",
		"Shield Bash+ Warden in position 3 rejects")

	# Downed Warden
	var downed_warden := _party()
	_check(downed_warden.apply_damage(1, 999) and downed_warden.is_downed(1), "down Warden")
	_reject(deck, downed_warden, standard_foes, "warden_shield_bash_plus", "Shield Bash+ downed Warden rejects")

	# Absent Warden
	var absent_warden_order: Array[String] = []
	absent_warden_order.assign(["seamstress", "tinker", "other"])
	var absent_warden := _party(absent_warden_order)
	_reject(deck, absent_warden, standard_foes, "warden_shield_bash_plus", "Shield Bash+ absent Warden rejects")

	# Enemy 1 slain: Shield Bash+ reaches only slot 1, so even with enemies 2 & 3 alive, it rejects!
	var foe_1_slain := _enemies(3)
	_check(foe_1_slain.apply_damage(1, 999) and foe_1_slain.is_slain(1), "slay enemy 1")
	_reject(deck, warden_front, foe_1_slain, "warden_shield_bash_plus",
		"Shield Bash+ rejects when enemy 1 is slain")

	# Energy checks:
	# Cost 2 for Shield Bash+: affordable at 2 energy, rejected at 1 energy
	var two_energy_deck := CombatDeck.new(upgraded_both.deck, rng)
	_check(two_energy_deck.start_turn() and two_energy_deck.try_spend_energy(1), "spend 1 energy -> 2 remain")
	while not two_energy_deck.hand.has("warden_shield_bash_plus") and not two_energy_deck.draw_pile.is_empty():
		two_energy_deck.draw_extra(1)
	_assert_preview(two_energy_deck, warden_front, standard_foes, "warden_shield_bash_plus", true, true, [1],
		"Shield Bash+ affordable at 2 energy")
	_check(two_energy_deck.try_spend_energy(1) and two_energy_deck.energy == 1, "spend 1 energy -> 1 remains")
	_reject(two_energy_deck, warden_front, standard_foes, "warden_shield_bash_plus",
		"Shield Bash+ unaffordable at 1 energy")

	# Cost 1 for Prick+: affordable at 1 energy, rejected at 0 energy
	while not two_energy_deck.hand.has("seamstress_prick_plus") and not two_energy_deck.draw_pile.is_empty():
		two_energy_deck.draw_extra(1)
	_assert_preview(two_energy_deck, _party(), standard_foes, "seamstress_prick_plus", true, true, [1, 2, 3],
		"Prick+ affordable at 1 energy")
	_check(two_energy_deck.try_spend_energy(1) and two_energy_deck.energy == 0, "spend 1 energy -> 0 remain")
	_reject(two_energy_deck, _party(), standard_foes, "seamstress_prick_plus",
		"Prick+ unaffordable at 0 energy")

	# Inactive turn
	var inactive := CombatDeck.new(upgraded_both.deck, rng)
	_reject(inactive, _party(), standard_foes, "seamstress_prick_plus", "Prick+ inactive turn")
	_reject(inactive, warden_front, standard_foes, "warden_shield_bash_plus", "Shield Bash+ inactive turn")

	# Absent hand card
	var unheld_deck := _deck(["warden_strike"])
	_reject(unheld_deck, _party(), standard_foes, "seamstress_prick_plus", "Prick+ not in hand")
	_reject(unheld_deck, warden_front, standard_foes, "warden_shield_bash_plus", "Shield Bash+ not in hand")
