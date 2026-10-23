extends SceneTree
## Deterministic headless test for CombatWardenPathCards (D2-5 / M06).
## Builds genuine RunWardenPathChoice receipts, inserts the authored Path card
## into a real seeded CombatDeck hand, and proves Bulwark Brace and Lance Pin
## spend/consume once, change only their legal targets, and fail closed with a
## fully unchanged deck, party, enemy roster, Pinned tokens and run RNG.
## Scene-free service test only: it does not claim live hand/app wiring.

const BULWARK_BRACE_ID := "warden_bulwark_brace"
const LANCE_PIN_ID := "warden_lance_pin"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_bulwark_brace()
	_test_ac2_lance_pin()
	_test_ac3_rejections()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("combat_warden_path_cards_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


# ---------------------------------------------------------------- fixtures

func _receipt(path_id: String) -> Dictionary:
	var choice := RunWardenPathChoice.new()
	_check(choice.is_valid(), "authored Warden Path record is valid")
	var receipt := choice.choose(path_id)
	_check(receipt.get("ok", false), "genuine %s receipt" % path_id)
	return receipt


func _party(warden_position: int = 1, warden_statuses: Dictionary = {}) -> CombatParty:
	var ids := ["warden", "seamstress", "tinker"]
	ids.erase("warden")
	ids.insert(warden_position - 1, "warden")
	var max_hp := {"warden": 40, "seamstress": 30, "tinker": 26}
	var definitions: Array = []
	for id in ids:
		var definition := {"id": id, "max_hp": max_hp[id]}
		if id == "warden" and not warden_statuses.is_empty():
			definition["statuses"] = warden_statuses.duplicate(true)
		definitions.append(definition)
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "three-hero party is valid")
	return party


## Builds a real roster; a requested 0 HP is authored as 1 max HP then damaged,
## because authored enemies always construct with positive max HP.
func _enemies(hp: Array = [20, 20, 20]) -> CombatEnemies:
	var definitions: Array = []
	for index in hp.size():
		definitions.append({"id": "foe_%d" % index, "max_hp": maxi(int(hp[index]), 1)})
	var roster := CombatEnemies.new(definitions)
	_check(roster.is_valid(), "enemy roster is valid")
	for index in hp.size():
		var missing := int(definitions[index]["max_hp"]) - int(hp[index])
		if missing > 0:
			_check(roster.apply_damage(index + 1, missing), "fixture enemy damage applies")
	return roster


## Real seeded deck holding the authored Path card in the shared hand.
func _deck_with_card(card_id: String, seed_value: int) -> CombatDeck:
	var cards := StarterCards.new().get_starting_deck()
	cards.append(card_id)
	return _start_deck(cards, card_id, seed_value)


## Deck proposed by a genuine claim: the unchanged 12 starter cards + Path card.
func _deck_from_receipt(receipt: Dictionary, seed_value: int) -> CombatDeck:
	var cards: Array[String] = []
	for card_id in receipt.get("starter_deck", []):
		cards.append(str(card_id))
	return _start_deck(cards, str(receipt.get("card", {}).get("id", "")), seed_value)


func _start_deck(cards: Array[String], card_id: String, seed_value: int) -> CombatDeck:
	_check(cards.size() == RunWardenPathChoice.STARTER_DECK_SIZE + 1,
		"test deck is the 12 starter cards plus one Path card")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn(), "shared-hand turn starts")
	_check(deck.hand.size() == CombatDeck.TURN_DRAW, "turn draws five cards")
	var draws := 0
	while not deck.hand.has(card_id) and draws < cards.size():
		deck.draw_extra(1)
		draws += 1
	_check(deck.hand.has(card_id), "Path card %s is held in the shared hand" % card_id)
	return deck


func _pins(pinned: CombatPinned) -> Dictionary:
	var out := {}
	for position in range(1, CombatEnemies.MAX_ENEMIES + 1):
		out[position] = pinned.pinner_for_enemy(position)
	return out


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned) -> Dictionary:
	return {
		"draw": deck.draw_pile.duplicate(),
		"hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"energy": deck.energy,
		"active": deck.turn_active,
		"rng": deck._rng.state,
		"party": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"pins": _pins(pinned),
	}


func _unchanged(before: Dictionary, after: Dictionary) -> bool:
	return _deep_equal(before, after)


func _deep_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var left_array: Array = a
		var right_array: Array = b
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not _deep_equal(left_array[index], right_array[index]):
				return false
		return true
	if a is Dictionary:
		var left_dict: Dictionary = a
		var right_dict: Dictionary = b
		if left_dict.size() != right_dict.size():
			return false
		for key in left_dict:
			if not right_dict.has(key):
				return false
			if not _deep_equal(left_dict[key], right_dict[key]):
				return false
		return true
	return a == b


func _assert_rejected(service: CombatWardenPathCards, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: String, target_position: int, receipt: Dictionary,
		pinned: CombatPinned, label: String) -> void:
	var before := _snapshot(deck, party, enemies, pinned)
	var result := service.play(deck, party, enemies, card_id, target_position, receipt, pinned)
	_check(result.get("ok", false) == false, label + ": rejected")
	_check(_unchanged(before, _snapshot(deck, party, enemies, pinned)),
		label + ": deck/party/enemies/pins/RNG unchanged")


# ------------------------------------------------------------------- AC1

func _test_ac1_bulwark_brace() -> void:
	var service := CombatWardenPathCards.new()
	var receipt := _receipt("bulwark")
	_check(receipt.get("card", {}).get("id") == BULWARK_BRACE_ID,
		"AC1: Bulwark receipt carries Bulwark Brace")

	# The living current Warden may stand in any current position 1-3.
	for warden_position: int in [1, 2, 3]:
		var deck := _deck_from_receipt(receipt, 4200 + warden_position)
		deck.combat_state.energy = 1
		var party := _party(warden_position)
		var enemies := _enemies()
		var pinned := CombatPinned.new()
		var before := _snapshot(deck, party, enemies, pinned)
		var result := service.play(
			deck, party, enemies, BULWARK_BRACE_ID, 0, receipt, pinned)

		_check(result.get("ok", false), "AC1: Bulwark Brace accepted from position %d" % warden_position)
		_check(result.get("energy_spent") == 1, "AC1: spends exactly one energy")
		_check(deck.energy == before["energy"] - 1, "AC1: energy charged exactly once")
		_check(result.get("discarded") == BULWARK_BRACE_ID, "AC1: discards the held copy")
		_check(deck.hand.size() == before["hand"].size() - 1, "AC1: exactly one hand copy consumed")
		_check(deck.hand.count(BULWARK_BRACE_ID) == before["hand"].count(BULWARK_BRACE_ID) - 1,
			"AC1: the consumed copy is the Bulwark Brace")
		_check(deck.discard_pile.size() == before["discard"].size() + 1,
			"AC1: exactly one discard added")
		_check(deck.discard_pile[-1] == BULWARK_BRACE_ID, "AC1: discarded card is Bulwark Brace")
		_check(deck.draw_pile == before["draw"], "AC1: draw pile untouched")
		_check(deck._rng.state == before["rng"], "AC1: no seeded RNG advance on play")
		_check(result.get("block_gained") == 9, "AC1: reports exactly 9 Block")
		_check(result.get("pinner") == "", "AC1: self card never pins")

		# Block goes ONLY to the living current Warden.
		for position in range(1, CombatParty.PARTY_SIZE + 1):
			var hero := party.get_hero(position)
			if position == warden_position:
				_check(hero.get("block", 0) == 9, "AC1: Warden in slot %d gains 9 Block" % position)
				_check(hero.get("hp", 0) == 40, "AC1: Warden HP untouched")
			else:
				_check(hero.get("block", 0) == 0, "AC1: hero in slot %d gains no Block" % position)
		_check(_deep_equal(enemies.get_enemies(), before["enemies"]),
			"AC1: enemies untouched by the self card")
		_check(_deep_equal(_pins(pinned), before["pins"]), "AC1: no Pinned token appears")

		# A double click / replay must not spend, discard or grant Block twice.
		var after := _snapshot(deck, party, enemies, pinned)
		var replay := service.play(
			deck, party, enemies, BULWARK_BRACE_ID, 0, receipt, pinned)
		_check(replay.get("ok", false) == false, "AC1: replay rejected after the copy was discarded")
		_check(_unchanged(after, _snapshot(deck, party, enemies, pinned)),
			"AC1: replay mutates nothing (double click safe)")
		_check(party.get_hero(warden_position).get("block", 0) == 9,
			"AC1: replay never stacks a second 9 Block")

	# A self card must not be committed against an enemy slot.
	var wrong_target_deck := _deck_from_receipt(receipt, 4300)
	wrong_target_deck.combat_state.energy = 1
	_assert_rejected(service, wrong_target_deck, _party(), _enemies(), BULWARK_BRACE_ID, 1,
		receipt, CombatPinned.new(), "AC1: self card with enemy target")


# ------------------------------------------------------------------- AC2

func _test_ac2_lance_pin() -> void:
	var service := CombatWardenPathCards.new()
	var receipt := _receipt("vanguard")
	_check(receipt.get("card", {}).get("id") == LANCE_PIN_ID,
		"AC2: Vanguard receipt carries Lance Pin")

	# Slot 1 or 2: 6 base damage with normal Block-before-HP.
	for target_position: int in [1, 2]:
		var deck := _deck_from_receipt(receipt, 5100 + target_position)
		deck.combat_state.energy = 1
		var party := _party(1)
		var enemies := _enemies([20, 20, 20])
		var pinned := CombatPinned.new()
		_check(enemies.gain_block(target_position, 5), "AC2: target has 5 Block")
		var before := _snapshot(deck, party, enemies, pinned)
		var result := service.play(
			deck, party, enemies, LANCE_PIN_ID, target_position, receipt, pinned)

		_check(result.get("ok", false), "AC2: Lance Pin accepted against slot %d" % target_position)
		_check(result.get("energy_spent") == 1, "AC2: costs exactly one energy")
		_check(deck.energy == before["energy"] - 1, "AC2: energy charged exactly once")
		_check(result.get("discarded") == LANCE_PIN_ID, "AC2: discards the held copy")
		_check(deck.hand.size() == before["hand"].size() - 1, "AC2: exactly one hand copy consumed")
		_check(deck.discard_pile.size() == before["discard"].size() + 1,
			"AC2: exactly one discard added")
		_check(deck._rng.state == before["rng"], "AC2: no seeded RNG advance on play")
		_check(result.get("target_position") == target_position, "AC2: reports the chosen target")
		_check(result.get("damage") == 6, "AC2: exactly 6 base damage")
		_check(result.get("block_absorbed") == 5, "AC2: damage uses Block before HP")
		_check(result.get("hp_loss") == 1, "AC2: only 1 HP lost through 5 Block")
		_check(enemies.get_enemy(target_position)["hp"] == 19, "AC2: surviving target at 19 HP")
		_check(enemies.get_enemy(target_position)["block"] == 0, "AC2: target Block consumed")
		_check(result.get("pinned_bonus") == 0, "AC2: no bonus without a prior pin")
		_check(result.get("pinned_applied") == true, "AC2: pin applied to a surviving target")
		_check(result.get("pinner") == "warden", "AC2: pin belongs to the Warden")
		_check(pinned.pinner_for_enemy(target_position) == "warden",
			"AC2: Warden-owned Pinned token exists")
		var hits: Array = result.get("hits", [])
		_check(hits.size() == 1, "AC2: one hit reported")
		if hits.size() == 1:
			_check(hits[0].get("position") == target_position, "AC2: hit names the chosen target")
			_check(hits[0].get("damage") == 6, "AC2: hit row carries the 6 damage")
			_check(hits[0].get("pinned_applied") == true, "AC2: hit row reports the applied pin")
		_check(_deep_equal(party.get_heroes(), before["party"]), "AC2: party untouched by the attack")
		for other in range(1, CombatEnemies.MAX_ENEMIES + 1):
			if other != target_position:
				_check(enemies.get_enemy(other)["hp"] == 20, "AC2: other enemies untouched")

		# Prospective bonus: the Warden gets no +5 from its own pin, another hero does.
		_check(pinned.bonus_for_attack(enemies, target_position, "warden") == 0,
			"AC2: same-owner prospective Pinned bonus is 0")
		_check(pinned.bonus_for_attack(enemies, target_position, "seamstress") == 5,
			"AC2: different hero gets the prospective +5")
		_check(pinned.pinner_for_enemy(target_position) == "warden",
			"AC2: previewing never consumes the token")

	# Weak on the Warden: floor(6 * 3/4) = 4.
	_test_status_hit({"weak": 1}, {}, 4, "AC2: Weak -25% floor")
	_test_status_hit({}, {"exposed": 1}, 9, "AC2: Exposed +50%")

	# Both at once: floor(6 * 9/8) = 6 (not 13 or 12).
	var both_deck := _deck_from_receipt(receipt, 5400)
	both_deck.combat_state.energy = 1
	var both_party := _party(1, {"weak": 1})
	var both_enemies := _enemies([20, 20, 20])
	_check(both_enemies.apply_statuses({1: {"exposed": 1}}), "AC2: Exposed fixture applies")
	var both_pinned := CombatPinned.new()
	var both := service.play(
		both_deck, both_party, both_enemies, LANCE_PIN_ID, 1, receipt, both_pinned)
	_check(both.get("ok", false), "AC2: Weak+Exposed hit commits")
	_check(both.get("damage") == 6, "AC2: Weak+Exposed floors once to 6")

	# Cross-owner pin: +5 BEFORE Weak/Exposed => floor(11 * 3/4) = 8.
	var cross_deck := _deck_from_receipt(receipt, 5500)
	cross_deck.combat_state.energy = 1
	var cross_party := _party(1, {"weak": 1})
	var cross_enemies := _enemies([20, 20, 20])
	var cross_pinned := CombatPinned.new()
	_check(cross_pinned.pin_enemy(cross_enemies, 1, "seamstress"), "AC2: cross-owner pin fixture")
	var cross_before := _snapshot(cross_deck, cross_party, cross_enemies, cross_pinned)
	var cross := service.play(
		cross_deck, cross_party, cross_enemies, LANCE_PIN_ID, 1, receipt, cross_pinned)
	_check(cross.get("ok", false), "AC2: attack consumes a cross-owner pin")
	_check(cross.get("pinned_bonus") == 5, "AC2: cross-owner Pinned contributes +5")
	_check(cross.get("damage") == 8, "AC2: +5 is added before Weak scaling")
	_check(cross_enemies.get_enemy(1)["hp"] == 12, "AC2: 8 damage reached 20 HP")
	_check(cross_pinned.pinner_for_enemy(1) == "warden",
		"AC2: old pin replaced by the Warden's pin")
	_check(cross_deck.hand.size() == cross_before["hand"].size() - 1,
		"AC2: cross-owner hit still discards once")

	# Same owner (Warden) pin: no +5, token stays Warden-owned.
	var same_deck := _deck_from_receipt(receipt, 5600)
	same_deck.combat_state.energy = 1
	var same_party := _party(1)
	var same_enemies := _enemies([20, 20, 20])
	var same_pinned := CombatPinned.new()
	_check(same_pinned.pin_enemy(same_enemies, 1, "warden"), "AC2: same-owner pin fixture")
	var same := service.play(
		same_deck, same_party, same_enemies, LANCE_PIN_ID, 1, receipt, same_pinned)
	_check(same.get("ok", false), "AC2: Warden may attack its own pin")
	_check(same.get("pinned_bonus") == 0, "AC2: same-owner pin gives no bonus")
	_check(same.get("damage") == 6, "AC2: same-owner hit deals the plain 6")
	_check(same_pinned.pinner_for_enemy(1) == "warden", "AC2: same-owner pin remains")

	# Lethal hit: no pin may remain on the slain enemy (own or cross-owner).
	for owner in ["warden", "seamstress"]:
		var pin_owner := str(owner)
		var lethal_deck := _deck_from_receipt(receipt, 5700)
		lethal_deck.combat_state.energy = 1
		var lethal_party := _party(1)
		var lethal_enemies := _enemies([6, 20])
		var lethal_pinned := CombatPinned.new()
		_check(lethal_pinned.pin_enemy(lethal_enemies, 1, pin_owner),
			"AC2: lethal %s pin fixture" % pin_owner)
		var lethal := service.play(
			lethal_deck, lethal_party, lethal_enemies, LANCE_PIN_ID, 1, receipt, lethal_pinned)
		_check(lethal.get("ok", false), "AC2: lethal hit commits (%s pin)" % pin_owner)
		_check(lethal_enemies.is_slain(1), "AC2: target is slain")
		_check(lethal.get("pinned_applied") == false, "AC2: no pin applied on a lethal hit")
		_check(lethal.get("pinner") == "", "AC2: no pinner reported on a lethal hit")
		_check(lethal_pinned.pinner_for_enemy(1) == "",
			"AC2: lethal hit clears the %s pin on the corpse" % pin_owner)

	# Forecast is pure and projects the target list plus per-target damage.
	var forecast_deck := _deck_from_receipt(receipt, 5800)
	forecast_deck.combat_state.energy = 1
	var forecast_party := _party(1)
	var forecast_enemies := _enemies([20, 20, 20])
	var forecast_pinned := CombatPinned.new()
	_check(forecast_pinned.pin_enemy(forecast_enemies, 2, "seamstress"),
		"AC2: forecast pin fixture")
	var forecast_before := _snapshot(forecast_deck, forecast_party, forecast_enemies, forecast_pinned)
	var forecast := service.forecast(
		forecast_deck, forecast_party, forecast_enemies, LANCE_PIN_ID, receipt, forecast_pinned)
	_check(forecast.get("ok", false) and forecast.get("playable", false),
		"AC2: forecast is playable")
	_check(forecast.get("target_positions") == [1, 2], "AC2: forecast offers slots 1 and 2")
	_check(forecast.get("requires_selection") == true, "AC2: forecast requires a target choice")
	_check(forecast.get("expected_damage") == 6, "AC2: forecast damage for slot 1 excludes the slot 2 pin")
	_check(forecast.get("pinned_bonus") == 0, "AC2: forecast slot 1 has no bonus")
	var targets: Array = forecast.get("targets", [])
	_check(targets.size() == 2, "AC2: forecast reports both targets")
	if targets.size() == 2:
		_check(targets[1].get("position") == 2, "AC2: second forecast target is slot 2")
		_check(targets[1].get("pinned_bonus") == 5, "AC2: forecast projects the cross-owner +5")
		_check(targets[1].get("expected_damage") == 11, "AC2: forecast applies +5 before statuses")
	_check(_unchanged(forecast_before, _snapshot(
		forecast_deck, forecast_party, forecast_enemies, forecast_pinned)),
		"AC2: forecast mutates nothing (HP/Block/hand/pin/RNG)")


## Runs one full Lance Pin commit with the given actor/defender statuses.
func _test_status_hit(warden_statuses: Dictionary, enemy_statuses: Dictionary,
		expected_damage: int, label: String) -> void:
	var service := CombatWardenPathCards.new()
	var receipt := _receipt("vanguard")
	var deck := _deck_from_receipt(receipt, 5300 + expected_damage)
	deck.combat_state.energy = 1
	var party := _party(1, warden_statuses)
	var enemies := _enemies([20, 20, 20])
	for status in enemy_statuses:
		_check(enemies.apply_statuses({1: {status: int(enemy_statuses[status])}}),
			label + ": defender status fixture")
	var result := service.play(
		deck, party, enemies, LANCE_PIN_ID, 1, receipt, CombatPinned.new())
	_check(result.get("ok", false), label + ": status hit commits")
	_check(result.get("damage") == expected_damage, label + ": status-adjusted damage")
	_check(enemies.get_enemy(1)["hp"] == 20 - expected_damage, label + ": HP follows damage")


# ------------------------------------------------------------------- AC3

func _test_ac3_rejections() -> void:
	var service := CombatWardenPathCards.new()
	var bulwark := _receipt("bulwark")
	var vanguard := _receipt("vanguard")

	# Mismatched / forged receipts.
	var forged_effect := bulwark.duplicate(true)
	(forged_effect["card"] as Dictionary)["effects"] = {"block": 999}
	var forged_effect_deck := _deck_with_card(BULWARK_BRACE_ID, 6100)
	forged_effect_deck.combat_state.energy = 1
	_assert_rejected(service, forged_effect_deck, _party(), _enemies(), BULWARK_BRACE_ID, 0,
		forged_effect, CombatPinned.new(), "AC3: forged 999 Block receipt")

	var other_card := bulwark.duplicate(true)
	(other_card["card"] as Dictionary)["id"] = LANCE_PIN_ID
	var other_card_deck := _deck_with_card(BULWARK_BRACE_ID, 6101)
	other_card_deck.combat_state.energy = 1
	_assert_rejected(service, other_card_deck, _party(), _enemies(), BULWARK_BRACE_ID, 0,
		other_card, CombatPinned.new(), "AC3: receipt smuggling the other Path card")

	var forged_owner := bulwark.duplicate(true)
	forged_owner["owner"] = "seamstress"
	var forged_owner_deck := _deck_with_card(BULWARK_BRACE_ID, 6102)
	forged_owner_deck.combat_state.energy = 1
	_assert_rejected(service, forged_owner_deck, _party(), _enemies(), BULWARK_BRACE_ID, 0,
		forged_owner, CombatPinned.new(), "AC3: forged owner receipt")

	var claimed_twice := RunWardenPathChoice.new()
	_check(claimed_twice.choose("bulwark").get("ok", false), "AC3: first claim succeeds")
	var rejected_claim := claimed_twice.choose("bulwark")
	_check(rejected_claim.get("ok", false) == false, "AC3: replayed claim receipt is a rejection")
	var rejected_claim_deck := _deck_with_card(BULWARK_BRACE_ID, 6103)
	rejected_claim_deck.combat_state.energy = 1
	_assert_rejected(service, rejected_claim_deck, _party(), _enemies(), BULWARK_BRACE_ID, 0,
		rejected_claim, CombatPinned.new(), "AC3: failed claim receipt")

	# The Vanguard receipt can never cast Bulwark Brace, even when it is held.
	var wrong_path_deck := _deck_with_card(BULWARK_BRACE_ID, 6200)
	wrong_path_deck.combat_state.energy = 1
	_assert_rejected(service, wrong_path_deck, _party(), _enemies(), BULWARK_BRACE_ID, 0,
		vanguard, CombatPinned.new(), "AC3: wrong-Path receipt for Bulwark Brace")

	# The Bulwark receipt can never cast Lance Pin.
	var cross_card_deck := _deck_with_card(LANCE_PIN_ID, 6201)
	cross_card_deck.combat_state.energy = 1
	_assert_rejected(service, cross_card_deck, _party(), _enemies([20, 20]), LANCE_PIN_ID, 1,
		bulwark, CombatPinned.new(), "AC3: wrong-Path receipt for Lance Pin")

	# Absent/unheld card: only the unmodified 12 starter cards.
	var unheld_cards := StarterCards.new().get_starting_deck()
	var unheld_rng := RandomNumberGenerator.new()
	unheld_rng.seed = 6300
	var unheld_deck := CombatDeck.new(unheld_cards, unheld_rng)
	_check(unheld_deck.start_turn(), "AC3: unheld fixture turn starts")
	_check(not unheld_deck.hand.has(BULWARK_BRACE_ID), "AC3: Bulwark Brace is genuinely unheld")
	unheld_deck.combat_state.energy = 3
	_assert_rejected(service, unheld_deck, _party(), _enemies(), BULWARK_BRACE_ID, 0,
		bulwark, CombatPinned.new(), "AC3: unheld card")

	# Inactive turn.
	var inactive_deck := _deck_from_receipt(bulwark, 6400)
	inactive_deck.combat_state.energy = 1
	_check(inactive_deck.combat_state.end_player_turn(), "AC3: turn ends")
	_assert_rejected(service, inactive_deck, _party(), _enemies(), BULWARK_BRACE_ID, 0,
		bulwark, CombatPinned.new(), "AC3: inactive turn")

	# Downed Warden (0 HP) cannot play.
	var downed_deck := _deck_from_receipt(bulwark, 6500)
	downed_deck.combat_state.energy = 1
	var downed_party := _party(1)
	_check(downed_party.apply_damage(1, 999), "AC3: Warden takes lethal damage")
	_check(downed_party.is_downed(1), "AC3: Warden is genuinely downed")
	_assert_rejected(service, downed_deck, downed_party, _enemies(), BULWARK_BRACE_ID, 0,
		bulwark, CombatPinned.new(), "AC3: downed Warden")

	# Warden moved out of Lance Pin's authored position 1 (party slot 2).
	var moved_deck := _deck_from_receipt(vanguard, 6600)
	moved_deck.combat_state.energy = 1
	var moved_party := _party(2)
	_check(moved_party.get_hero(2).get("id") == "warden", "AC3: Warden genuinely moved to slot 2")
	_assert_rejected(service, moved_deck, moved_party, _enemies([20, 20]), LANCE_PIN_ID, 1,
		vanguard, CombatPinned.new(), "AC3: Warden out of position")

	# No energy.
	var no_energy_deck := _deck_from_receipt(bulwark, 6700)
	no_energy_deck.combat_state.energy = 0
	_assert_rejected(service, no_energy_deck, _party(), _enemies(), BULWARK_BRACE_ID, 0,
		bulwark, CombatPinned.new(), "AC3: no energy")

	# Dead, illegal-slot and absent enemy targets.
	var dead_deck := _deck_from_receipt(vanguard, 6800)
	dead_deck.combat_state.energy = 1
	_assert_rejected(service, dead_deck, _party(), _enemies([0, 20]), LANCE_PIN_ID, 1,
		vanguard, CombatPinned.new(), "AC3: dead enemy target")

	var illegal_slot_deck := _deck_from_receipt(vanguard, 6801)
	illegal_slot_deck.combat_state.energy = 1
	_assert_rejected(service, illegal_slot_deck, _party(), _enemies([20, 20, 20]), LANCE_PIN_ID, 3,
		vanguard, CombatPinned.new(), "AC3: enemy slot outside authored 1-2")

	var absent_slot_deck := _deck_from_receipt(vanguard, 6802)
	absent_slot_deck.combat_state.energy = 1
	_assert_rejected(service, absent_slot_deck, _party(), _enemies([20]), LANCE_PIN_ID, 2,
		vanguard, CombatPinned.new(), "AC3: empty enemy slot 2")

	# Already-finished battle.
	var finished_deck := _deck_from_receipt(vanguard, 6900)
	finished_deck.combat_state.energy = 1
	var finished_enemies := _enemies([6])
	_check(finished_enemies.apply_damage(1, 6), "AC3: last enemy slain")
	_check(finished_enemies.is_victorious(), "AC3: battle is genuinely finished")
	_assert_rejected(service, finished_deck, _party(), finished_enemies, LANCE_PIN_ID, 1,
		vanguard, CombatPinned.new(), "AC3: finished battle")

	# A rejected attempt leaves the same objects usable for the correct choice.
	var retry_deck := _deck_from_receipt(bulwark, 7000)
	retry_deck.combat_state.energy = 1
	var retry_party := _party(1)
	var retry_enemies := _enemies()
	var retry_pinned := CombatPinned.new()
	var retry_before := _snapshot(retry_deck, retry_party, retry_enemies, retry_pinned)
	var rejected := service.play(retry_deck, retry_party, retry_enemies, BULWARK_BRACE_ID, 0,
		forged_effect, retry_pinned)
	_check(rejected.get("ok", false) == false, "AC3: forged attempt is rejected")
	_check(_unchanged(retry_before, _snapshot(retry_deck, retry_party, retry_enemies, retry_pinned)),
		"AC3: rejected attempt spends nothing and advances no RNG")
	var retried := service.play(retry_deck, retry_party, retry_enemies, BULWARK_BRACE_ID, 0,
		bulwark, retry_pinned)
	_check(retried.get("ok", false), "AC3: correct choice still works after a rejection")
	_check(retry_party.get_hero(1).get("block", 0) == 9, "AC3: retried Bulwark Brace grants 9 Block")
	_check(retry_deck.energy == 0, "AC3: retried play charges its single energy")
