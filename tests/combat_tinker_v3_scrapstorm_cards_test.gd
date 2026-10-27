extends SceneTree
## Deterministic headless test for Tinker's paid Scrapstorm / Scrapstorm+ area attack (V3-1).
##
## Scrapstorm is the second Combat Scrap spender in the Tinker V3 pool: two energy, cast only from the
## back seat, one 3-damage (4 for the '+') raw hit on EACH living enemy in authored slots 1-3 plus one
## more per Combat Scrap SPENT, spending at most three and keeping any surplus. Combat Scrap lives on
## Tinker's own authoritative hero record and is never the run wallet's `scraps`.
##
## Every case below runs the real seeded CombatDeck, CombatParty and CombatEnemies models with the
## genuine V3TinkerPoolCards IDs through CombatTinkerV3OverloadCards' named Scrapstorm preflight and
## paid play. The service is rules-layer only: registering these IDs on the live hand/reward flow is a
## later, separately owned wiring task, so no case here claims live player availability and none
## preloads an unowned live file. Legacy Overload / Overload+ stays exactly as it was, which the last
## section re-proves against its own single-target contract.

const CombatDeck = preload("res://scripts/combat_deck.gd")
const CombatParty = preload("res://scripts/combat_party.gd")
const CombatEnemies = preload("res://scripts/combat_enemies.gd")
const CombatTinkerV3OverloadCards = preload("res://scripts/combat_tinker_v3_overload_cards.gd")

const SCRAPSTORM := "tinker_v3_scrapstorm"
const SCRAPSTORM_PLUS := "tinker_v3_scrapstorm_plus"
const SCRAPSTORM_IDS: Array[String] = [SCRAPSTORM, SCRAPSTORM_PLUS]
const OVERLOAD := "tinker_v3_overload"
const OVERLOAD_PLUS := "tinker_v3_overload_plus"

## The paid area fixtures: three authored slots, the middle one already slain, the two living ones
## carrying different Block so per-target absorption is distinguishable.
const SLAIN_SLOT := 2
const FRONT_BLOCK := 2
const BACK_BLOCK := 5
const FRONT_MAX_HP := 30
const SLAIN_MAX_HP := 20
const BACK_MAX_HP := 24

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_catalog_contract()
	_test_paid_area_plays()
	_test_area_roster_shapes()
	_test_refusals()
	_test_legacy_overload_untouched()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("combat_tinker_v3_scrapstorm_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_tinker_v3_scrapstorm_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent spend and damage arithmetic for the two Scrapstorm printings (never read back from the
## resolver): spend is min(3, counter) and every living enemy takes base + 1 per scrap spent.
func _table(card_id: String) -> Dictionary:
	var base := 4 if card_id == SCRAPSTORM_PLUS else 3
	var spend := {0: 0, 1: 1, 2: 2, 3: 3, 4: 3}
	var raw := {}
	for scrap in spend:
		raw[scrap] = base + int(spend[scrap])
	return {"base": base, "spend": spend, "raw": raw}


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real three-hero party (distinct IDs) with the living Tinker in the named seat. The Tinker holds
## `scrap` Combat Scrap on his own record; each teammate keeps a distinct non-zero counter of its own.
func _party(tinker_position: int, scrap: int) -> CombatParty:
	var roster: Array = []
	var others: Array[String] = ["warden", "seamstress"]
	var next_other := 0
	for index in range(3):
		if index + 1 == tinker_position:
			roster.append({"id": "tinker", "max_hp": 26})
		else:
			roster.append({"id": others[next_other], "max_hp": 40 - next_other * 6})
			next_other += 1
	var party := CombatParty.new(roster)
	if not party.is_valid() or party.get_hero(tinker_position).get("id") != "tinker":
		_check(false, "fixture could not build a party with the Tinker in seat " + str(tinker_position))
		return party
	party._heroes[tinker_position - 1]["combat_scrap"] = scrap
	for index in range(3):
		if index + 1 != tinker_position:
			party._heroes[index]["combat_scrap"] = 2
	_check(party.get_hero(tinker_position).get("combat_scrap") == scrap,
		"the Tinker fixture really holds " + str(scrap) + " Combat Scrap")
	return party


## A genuine seeded CombatDeck already in a real turn, guaranteed to hold each named card while
## keeping `supply` further filler cards in the shared draw pile.
func _deck(held_ids: Array, seed_value: int, supply: int) -> CombatDeck:
	var ids: Array[String] = []
	for card_id in held_ids:
		ids.append(str(card_id))
	for index in range(supply):
		ids.append("v3_scrapstorm_filler_" + str(index))
	var deck := CombatDeck.new(ids, _rng(seed_value))
	_check(deck.start_turn() and deck.energy == 3,
		"fixture starts a real three-energy shared turn for " + str(held_ids))
	var hand_slot := 0
	for card_id: String in held_ids:
		if deck.hand.has(card_id):
			continue
		var source: int = deck.draw_pile.find(card_id)
		if source < 0:
			continue
		while hand_slot < deck.hand.size() and deck.hand[hand_slot] in held_ids:
			hand_slot += 1
		if hand_slot >= deck.hand.size():
			continue
		var swap: String = deck.hand[hand_slot]
		deck.draw_pile[source] = swap
		deck.hand[hand_slot] = card_id
		hand_slot += 1
	for card_id: String in held_ids:
		_check(deck.hand.has(card_id), "fixture hand really holds " + card_id)
	_check(deck.discard_pile.is_empty(), "fixture discard starts empty")
	return deck


## The area fixture: three authored slots, the middle one slain, the living front and back slots
## carrying different Block.
func _area_enemies(front_block: int = FRONT_BLOCK, back_block: int = BACK_BLOCK) -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "straw_dummy", "max_hp": FRONT_MAX_HP},
		{"id": "quilt_hog", "max_hp": SLAIN_MAX_HP},
		{"id": "bobbin_wraith", "max_hp": BACK_MAX_HP},
	])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"the area fixture really is a valid three-slot roster")
	_check(enemies.gain_block(1, front_block), "the area fixture really grants the front enemy Block")
	_check(enemies.apply_damage(SLAIN_SLOT, SLAIN_MAX_HP) and enemies.is_slain(SLAIN_SLOT),
		"the area fixture really has a slain middle enemy")
	_check(enemies.gain_block(3, back_block), "the area fixture really grants the back enemy Block")
	return enemies


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var snapshot: Dictionary = {
		"deck_present": deck != null, "party_present": party != null,
		"enemies_present": enemies != null,
	}
	if deck != null:
		snapshot["turn"] = deck.turn_active
		snapshot["energy"] = deck.energy
		snapshot["state_energy"] = deck.combat_state.energy
		snapshot["state_turn"] = deck.combat_state.player_turn_active
		snapshot["hand"] = deck.hand.duplicate()
		snapshot["draw"] = deck.draw_pile.duplicate()
		snapshot["discard"] = deck.discard_pile.duplicate()
		snapshot["rng_state"] = deck._rng.state if deck._rng != null else -1
	if party != null:
		snapshot["party"] = party.get_heroes()
		snapshot["party_valid"] = party.is_valid()
	if enemies != null:
		snapshot["enemies"] = enemies.get_enemies()
		snapshot["enemies_valid"] = enemies.is_valid()
	return snapshot


## The exact area outcome, computed independently: two energy, the held copy moved to discard, the
## spent (not the whole) counter removed from the Tinker and one raw hit through Block to each living
## authored slot in ascending order.
func _expected_area(before: Dictionary, card_id: String, seat: int, spent: int, raw: int,
		live_positions: Array) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 2
	expected["state_energy"] = int(expected["state_energy"]) - 2
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) == 1, "expected snapshot: exactly one played copy is held")
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	var owner: Dictionary = expected["party"][seat - 1]
	_check(int(owner.get("combat_scrap", -1)) >= spent,
		"expected snapshot: the Tinker really holds at least the spent Combat Scrap")
	owner["combat_scrap"] = int(owner.get("combat_scrap", 0)) - spent
	for position in live_positions:
		var enemy: Dictionary = expected["enemies"][position - 1]
		_check(int(enemy["hp"]) > 0, "expected snapshot: slot " + str(position) + " is really living")
		var absorbed: int = mini(int(enemy["block"]), raw)
		enemy["block"] = int(enemy["block"]) - absorbed
		enemy["hp"] = maxi(0, int(enemy["hp"]) - (raw - absorbed))
	return expected


## AC1 catalog half: exactly the authored Scrapstorm pair is accepted, field by field, and every
## altered or foreign record is refused.
func _test_catalog_contract() -> void:
	var catalog := V3TinkerPoolCards.new()
	var resolver := CombatTinkerV3OverloadCards.new()
	var expected := {
		SCRAPSTORM: {"display": "Scrapstorm", "damage": 3, "is_upgrade": false},
		SCRAPSTORM_PLUS: {"display": "Scrapstorm+", "damage": 4, "is_upgrade": true},
	}
	for card_id: String in SCRAPSTORM_IDS:
		var row: Dictionary = expected[card_id]
		var damage: int = row["damage"]
		var effects := {"damage": damage, "combat_scrap_spend_max": 3,
			"bonus_damage_per_combat_scrap": 1, "living_targets_only": true}
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " is authored in the v3 Tinker catalog")
		if record.is_empty():
			continue
		_check(record.get("display_name") == row["display"], card_id + " display name")
		_check(record.get("owner") == "tinker", card_id + " is owned by Tinker")
		_check(record.get("rarity") == "rare", card_id + " is rare")
		_check(record.get("cost") == 2, card_id + " prints cost 2")
		_check(record.get("from_positions") == [3], card_id + " prints FROM 3")
		_check(record.get("target_kind") == "enemy_all", card_id + " targets the whole enemy line")
		_check(record.get("to_positions") == [1, 2, 3], card_id + " prints TO 1-3")
		_check(record.get("effects") == effects,
			card_id + " prints " + str(damage) + " damage + 1 per spent scrap, at most 3, living only")
		_check(record.get("starting_copies") == 0, card_id + " is never a starter copy")
		_check(not record.has("upgrade_of"), card_id + " links with base_id/upgrade_id/is_upgrade")
		_check(record.get("base_id") == SCRAPSTORM and record.get("upgrade_id") == SCRAPSTORM_PLUS
			and record.get("is_upgrade") == row["is_upgrade"],
			card_id + " preserves the base/+ link")
		_check(not record.get("effects", {}).has("scraps")
			and not record.get("effects", {}).has("scrap_cost"),
			card_id + " never reads or spends wallet scraps")
		_check(resolver.is_supported_scrapstorm(card_id),
			card_id + " is a supported Scrapstorm card")
		_check(CombatTinkerV3OverloadCards.is_authentic_scrapstorm_definition(record, card_id),
			card_id + " passes the Scrapstorm authenticator")
		_check(CombatTinkerV3OverloadCards.scrapstorm_definition(card_id) == record,
			card_id + " resolves to its exact detached catalog record")

	# Detached: mutating a resolved record cannot rewrite what the next resolution returns.
	var sample: Dictionary = CombatTinkerV3OverloadCards.scrapstorm_definition(SCRAPSTORM)
	_check(not sample.is_empty(), "Scrapstorm resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["damage"] = 900
		sample["effects"]["combat_scrap_spend_max"] = 99
		sample["from_positions"].clear()
		sample["cost"] = 0
		_check(CombatTinkerV3OverloadCards.scrapstorm_definition(SCRAPSTORM)
			== catalog.get_definition(SCRAPSTORM),
			"a mutated Scrapstorm definition cannot poison later resolutions")

	# Every other v3 Tinker card (base and plus) is unrelated to the Scrapstorm service.
	var unrelated: Array[String] = []
	for base_id in catalog.get_pool_card_ids():
		if not SCRAPSTORM_IDS.has(base_id):
			unrelated.append(base_id)
		var upgrade_id: String = catalog.get_upgrade_id(base_id)
		if not upgrade_id.is_empty() and not SCRAPSTORM_IDS.has(upgrade_id):
			unrelated.append(upgrade_id)
	_check(unrelated.has("tinker_v3_brass_casing") and unrelated.has(OVERLOAD)
		and unrelated.has("tinker_v3_wind_up_turret_plus"),
		"unrelated-card fixture really contains other authentic v3 Tinker cards (precondition)")
	for other_id: String in unrelated:
		_check(CombatTinkerV3OverloadCards.scrapstorm_definition(other_id).is_empty(),
			other_id + " does not resolve as Scrapstorm")
		_check(not resolver.is_supported_scrapstorm(other_id),
			other_id + " is not a supported Scrapstorm card")

	# Forged spellings and non-string IDs never resolve as Scrapstorm.
	var forged: Array = ["tinker_scrapstorm", "tinker_v3_scrapstorm+", "tinker_v3_scrapstorm_plus_plus",
		"tinker_v3_scrapstorm_", "scrapstorm", "TINKER_V3_SCRAPSTORM", "",
		"tinker_v3_missing_card", StringName(SCRAPSTORM), null, 0, 3.5, false, [], {}]
	for other_id: Variant in forged:
		_check(CombatTinkerV3OverloadCards.scrapstorm_definition(other_id).is_empty(),
			"forged or non-string ID never resolves as Scrapstorm: " + str(other_id))
		_check(not resolver.is_supported_scrapstorm(other_id),
			"forged or non-string ID is never a supported Scrapstorm: " + str(other_id))

	# Adversarial copies of the real record: each altered contract field is refused.
	var base_record: Dictionary = catalog.get_definition(SCRAPSTORM)
	_check(not base_record.is_empty()
		and CombatTinkerV3OverloadCards.is_authentic_scrapstorm_definition(base_record, SCRAPSTORM),
		"authenticator positive fixture really is the authored Scrapstorm")
	var mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["damage"] = 5,
		func(record: Dictionary) -> void: record["effects"]["damage"] = 3.0,
		func(record: Dictionary) -> void: record["effects"]["combat_scrap_spend_max"] = 4,
		func(record: Dictionary) -> void: record["effects"]["combat_scrap_spend_max"] = "3",
		func(record: Dictionary) -> void: record["effects"]["bonus_damage_per_combat_scrap"] = 2,
		func(record: Dictionary) -> void: record["effects"]["bonus_damage_per_combat_scrap"] = true,
		func(record: Dictionary) -> void: record["effects"]["living_targets_only"] = false,
		func(record: Dictionary) -> void: record["effects"]["living_targets_only"] = 1,
		func(record: Dictionary) -> void: record["effects"].erase("living_targets_only"),
		func(record: Dictionary) -> void: record["effects"]["scraps"] = 1,
		func(record: Dictionary) -> void: record["rarity"] = "common",
		func(record: Dictionary) -> void: record["cost"] = 1,
		func(record: Dictionary) -> void: record["cost"] = 2.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["from_positions"] = [1, 2, 3],
		func(record: Dictionary) -> void: record["to_positions"] = [],
		func(record: Dictionary) -> void: record["target_kind"] = "enemy_single",
		func(record: Dictionary) -> void: record["is_upgrade"] = true,
		func(record: Dictionary) -> void: record["upgrade_of"] = SCRAPSTORM,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record.erase("effects"),
	]
	for index in range(mutations.size()):
		var tampered: Dictionary = base_record.duplicate(true)
		mutations[index].call(tampered)
		_check(not CombatTinkerV3OverloadCards.is_authentic_scrapstorm_definition(tampered, SCRAPSTORM),
			"tampered Scrapstorm record " + str(index) + " is refused")
	_check(not CombatTinkerV3OverloadCards.is_authentic_scrapstorm_definition(
		catalog.get_definition(SCRAPSTORM_PLUS), SCRAPSTORM),
		"an upgraded record cannot authenticate as its base ID")
	_check(not CombatTinkerV3OverloadCards.is_authentic_scrapstorm_definition(
		catalog.get_definition(SCRAPSTORM), SCRAPSTORM_PLUS),
		"a base record cannot authenticate as its upgraded ID")


## AC1: one real held play pays 2 energy, spends min(3, counter), discards exactly one copy and lands
## the printed raw damage on each living enemy in authored slots 1-3 through that enemy's own Block.
func _test_paid_area_plays() -> void:
	var resolver := CombatTinkerV3OverloadCards.new()
	var seed_value := 512000
	for card_id: String in SCRAPSTORM_IDS:
		var table := _table(card_id)
		for scrap: int in [0, 1, 2, 3, 4]:
			var spent: int = table["spend"][scrap]
			var raw: int = table["raw"][scrap]
			_check(spent == mini(3, scrap),
				card_id + " spends min(3, " + str(scrap) + ") = " + str(spent))
			_check(raw == int(table["base"]) + spent,
				card_id + " deals its printed base plus one per spent scrap")
			_area_case(resolver, card_id, scrap, seed_value,
				card_id + " with " + str(scrap) + " Combat Scrap")
			seed_value += 1

	# A fresh Tinker has no stored counter at all: absent reads as zero, spends nothing, still deals
	# its printed base damage and stores an explicit spent zero.
	var fresh_party := _party(3, 0)
	fresh_party._heroes[2].erase("combat_scrap")
	_check(not fresh_party.get_hero(3).has("combat_scrap"),
		"absent-counter fixture really has no stored Combat Scrap")
	var fresh_deck := _deck([SCRAPSTORM], 512100, 5)
	var fresh_enemies := _area_enemies()
	var fresh: Dictionary = resolver.play_scrapstorm_card(fresh_deck, fresh_party, fresh_enemies,
		SCRAPSTORM)
	_check(fresh.get("ok") == true and fresh.get("combat_scrap_before") == 0
		and fresh.get("combat_scrap_spent") == 0 and fresh.get("combat_scrap_after") == 0
		and fresh.get("raw_damage") == 3,
		"an absent counter plays as zero and stores an explicit spent zero")
	_check(fresh_party.get_hero(3).get("combat_scrap") == 0
		and fresh_enemies.get_enemy(1).get("hp") == FRONT_MAX_HP - 1
		and fresh_enemies.get_enemy(3).get("hp") == BACK_MAX_HP,
		"the absent-counter play deals its printed 3 through the living slots' own Block")


## One funded Scrapstorm transaction on real fixtures, plus an identical same-seed replay and the
## consumed copy's refused re-claim.
func _area_case(resolver: CombatTinkerV3OverloadCards, card_id: String, scrap: int,
		seed_value: int, label: String) -> void:
	var table := _table(card_id)
	var spent: int = table["spend"][scrap]
	var raw: int = table["raw"][scrap]
	var party := _party(3, scrap)
	var deck := _deck([card_id], seed_value, 5)
	var enemies := _area_enemies()
	var wallet := {"gold": 11, "scraps": 6}
	var wallet_before: Dictionary = wallet.duplicate(true)
	var rng_before: int = deck._rng.state
	var before := _snapshot(deck, party, enemies)
	_check(bool(before["turn"]) and int(before["energy"]) == 3 and int(before["state_energy"]) == 3,
		label + ": fixture really has an active three-energy turn")

	# The pure preflight accepts the same request and changes nothing.
	var plan: Dictionary = resolver.preflight_scrapstorm(deck, party, enemies, card_id)
	_check(plan.get("ok") == true and plan.get("reason") == "legal",
		label + ": read-only preflight accepts the funded play")
	_check(plan.get("raw_damage") == raw and plan.get("base_damage") == table["base"]
		and plan.get("combat_scrap_spent") == spent
		and plan.get("combat_scrap_after") == scrap - spent,
		label + ": preflight reports the independent damage and the spent/remaining scrap")
	_check(plan.get("targets") != null
		and (plan["targets"] as Array).size() == 2
		and (plan["targets"] as Array)[0]["position"] == 1
		and (plan["targets"] as Array)[1]["position"] == 3,
		label + ": preflight lists only the two living slots in authored order")
	_check(_snapshot(deck, party, enemies) == before, label + ": preflight changed no battle state")

	var result: Dictionary = resolver.play_scrapstorm_card(deck, party, enemies, card_id)
	_check(result.get("ok") == true and result.get("reason") == "applied",
		label + ": authorized paid play")
	_check(result.get("card_id") == card_id and result.get("cost") == 2,
		label + ": receipt names the authentic card and its two energy")
	_check(result.get("owner_position") == 3 and result.get("target_kind") == "enemy_all",
		label + ": receipt reports the real back-seat owner and the whole enemy line")
	_check(result.get("combat_scrap_before") == scrap
		and result.get("combat_scrap_spend_max") == 3
		and result.get("combat_scrap_spent") == spent
		and result.get("combat_scrap_after") == scrap - spent,
		label + ": receipt reports at most three spent and the surplus retained")
	_check(result.get("base_damage") == table["base"]
		and result.get("bonus_damage_per_combat_scrap") == 1
		and result.get("damage_from_combat_scrap") == spent,
		label + ": receipt reports the printed base and the one-per-spent-scrap bonus")
	_check(result.get("raw_damage") == raw and result.get("damage") == raw,
		label + ": exactly " + str(raw) + " raw damage to every living enemy")

	# Per-target Block absorption and HP loss, independently recomputed from the pre-play roster.
	var hits: Array = result.get("hits", [])
	_check(hits.size() == 2 and result.get("targets_hit") == [1, 3]
		and result.get("targets_hit_count") == 2,
		label + ": one ordered hit per living authored slot")
	var block_total := 0
	var hp_total := 0
	var expected_live: Array = [1, 3]
	for index in range(expected_live.size()):
		var position: int = expected_live[index]
		var enemy_before: Dictionary = before["enemies"][position - 1]
		var absorbed: int = mini(int(enemy_before["block"]), raw)
		var loss: int = mini(int(enemy_before["hp"]), raw - absorbed)
		block_total += absorbed
		hp_total += loss
		if index >= hits.size():
			continue
		var hit: Dictionary = hits[index]
		_check(hit.get("position") == position and hit.get("raw_damage") == raw,
			label + ": hit " + str(index) + " names slot " + str(position) + " with " + str(raw))
		_check(hit.get("block_before") == int(enemy_before["block"])
			and hit.get("block_absorbed") == absorbed
			and hit.get("block_after") == int(enemy_before["block"]) - absorbed,
			label + ": slot " + str(position) + " Block absorbed " + str(absorbed))
		_check(hit.get("hp_before") == int(enemy_before["hp"])
			and hit.get("hp_loss") == loss
			and hit.get("hp_after") == int(enemy_before["hp"]) - loss,
			label + ": slot " + str(position) + " lost " + str(loss) + " HP after Block")
		_check(hit.get("statuses") == {}, label + ": slot " + str(position) + " gained no statuses")
	_check(result.get("block_absorbed") == block_total and result.get("hp_loss") == hp_total,
		label + ": receipt totals match the per-target absorption and loss")

	_check(result.get("energy_before") == 3 and result.get("energy_after") == 1,
		label + ": receipt reports the exact two-energy payment")
	_check(not result.has("scraps") and not result.has("wallet"),
		label + ": receipt carries no wallet state")
	_check(deck.energy == 1, label + ": exactly two energy were paid")
	_check(deck.hand.count(card_id) == 0 and deck.discard_pile == [card_id],
		label + ": exactly the held copy reached the discard")
	_check(deck._rng.state == rng_before, label + ": no RNG was consumed")
	_check(wallet == wallet_before, label + ": the run wallet's scraps are never modified")
	_check(party._heroes[2].get("combat_scrap") == scrap - spent,
		label + ": only the spent scrap left the Tinker's own record")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		label + ": the Tinker's HP and Block are untouched")
	_check(party.get_hero(1).get("combat_scrap") == 2
		and party.get_hero(2).get("combat_scrap") == 2,
		label + ": teammate counters are untouched")
	_check(enemies.is_slain(SLAIN_SLOT)
		and enemies.get_enemy(SLAIN_SLOT) == before["enemies"][SLAIN_SLOT - 1],
		label + ": the slain middle enemy was never attacked")
	for position in expected_live:
		var enemy_before: Dictionary = before["enemies"][position - 1]
		var absorbed: int = mini(int(enemy_before["block"]), raw)
		var loss: int = mini(int(enemy_before["hp"]), raw - absorbed)
		_check(enemies.get_enemy(position).get("hp") == int(enemy_before["hp"]) - loss
			and enemies.get_enemy(position).get("block") == int(enemy_before["block"]) - absorbed,
			label + ": slot " + str(position) + " ended with the independently computed HP/Block")
	_check(_snapshot(deck, party, enemies)
		== _expected_area(before, card_id, 3, spent, raw, [1, 3]),
		label + ": exact hand, piles, energy, turn, party, counters, enemies and RNG state")

	# The consumed copy cannot be claimed a second time.
	var after := _snapshot(deck, party, enemies)
	var replay_claim: Dictionary = resolver.play_scrapstorm_card(deck, party, enemies, card_id)
	_check(replay_claim.get("ok") == false and replay_claim.get("reason") == "card_not_held",
		label + ": a second claim of the consumed copy is refused")
	_check(_snapshot(deck, party, enemies) == after,
		label + ": the refused re-claim changed nothing")

	# Same seed, same fixtures: an identical replay of the whole transaction.
	var replay_party := _party(3, scrap)
	var replay_deck := _deck([card_id], seed_value, 5)
	var replay_enemies := _area_enemies()
	var replay_result: Dictionary = resolver.play_scrapstorm_card(replay_deck, replay_party,
		replay_enemies, card_id)
	_check(replay_result == result, label + ": the same seed replays the identical receipt")
	_check(_snapshot(replay_deck, replay_party, replay_enemies) == after,
		label + ": the same seed replays the identical battle and RNG state")


## Every living authored slot is covered, and only the slots the roster actually has: an all-living
## three-slot line, a two-slot line and a line whose front slot is already down.
func _test_area_roster_shapes() -> void:
	var resolver := CombatTinkerV3OverloadCards.new()

	# Three living enemies: the whole line takes the hit, in ascending slot order.
	var full := CombatEnemies.new([
		{"id": "straw_dummy", "max_hp": 12},
		{"id": "quilt_hog", "max_hp": 12},
		{"id": "bobbin_wraith", "max_hp": 12},
	])
	_check(full.is_valid() and full.gain_block(2, 3), "three-living fixture really grants middle Block")
	_paid_roster_case(resolver, full, SCRAPSTORM, 0, [1, 2, 3], 522001,
		"three living enemies")

	# Two-slot line: no third authored slot exists, so only slots 1-2 are hit.
	var pair := CombatEnemies.new([
		{"id": "straw_dummy", "max_hp": 20},
		{"id": "quilt_hog", "max_hp": 20},
	])
	_check(pair.is_valid() and pair.gain_block(2, 1), "two-enemy fixture really grants back Block")
	_paid_roster_case(resolver, pair, SCRAPSTORM_PLUS, 4, [1, 2], 522002, "two living enemies")

	# Front slot down: the two back slots take the hit and the corpse is left exactly as it was.
	var front_down := _area_enemies(0, 4)
	_check(front_down.apply_damage(1, FRONT_MAX_HP) and front_down.is_slain(1),
		"front-down fixture really has a slain front enemy")
	_paid_roster_case(resolver, front_down, SCRAPSTORM, 2, [3], 522003, "slain front enemy")


func _paid_roster_case(resolver: CombatTinkerV3OverloadCards, enemies: CombatEnemies,
		card_id: String, scrap: int, expected_positions: Array, seed_value: int,
		label: String) -> void:
	var table := _table(card_id)
	var spent: int = table["spend"][scrap]
	var raw: int = table["raw"][scrap]
	var party := _party(3, scrap)
	var deck := _deck([card_id], seed_value, 5)
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = resolver.play_scrapstorm_card(deck, party, enemies, card_id)
	_check(result.get("ok") == true and result.get("reason") == "applied",
		label + ": paid play applies")
	_check(result.get("targets_hit") == expected_positions
		and (result.get("hits", []) as Array).size() == expected_positions.size(),
		label + ": exactly the living authored slots " + str(expected_positions) + " were hit")
	_check(result.get("raw_damage") == raw and result.get("combat_scrap_after") == scrap - spent,
		label + ": independent raw damage and retained scrap")
	_check(_snapshot(deck, party, enemies)
		== _expected_area(before, card_id, 3, spent, raw, expected_positions),
		label + ": only the living slots changed, with their own Block before HP")


## AC2: every failed identity, turn, owner, seat, target, hand, energy, counter or roster precondition
## is refused with its reason and mutates no deck, party, enemy, counter or RNG state.
func _test_refusals() -> void:
	var resolver := CombatTinkerV3OverloadCards.new()
	var party := _party(3, 3)
	var deck := _deck([SCRAPSTORM], 523100, 5)
	var enemies := _area_enemies()

	_rejected_scrapstorm(resolver, null, party, enemies, SCRAPSTORM, 0, "invalid_request",
		"null deck")
	_rejected_scrapstorm(resolver, deck, null, enemies, SCRAPSTORM, 0, "invalid_request",
		"null party")
	_rejected_scrapstorm(resolver, deck, party, null, SCRAPSTORM, 0, "invalid_request",
		"null enemies")

	# An inactive turn is never paid, even with a real copy in hand.
	var inactive := CombatDeck.new([SCRAPSTORM], _rng(523101))
	inactive.hand.append(SCRAPSTORM)
	_check(not inactive.turn_active and inactive.hand.has(SCRAPSTORM),
		"inactive fixture really holds a copy outside a turn")
	_rejected_scrapstorm(resolver, inactive, party, enemies, SCRAPSTORM, 0, "inactive_turn",
		"inactive turn")

	# Unsupported card identities: other authentic Tinker cards, v2 cards, forged spellings.
	var wrong_ids: Array = ["tinker_v3_brass_casing", "tinker_v3_brass_casing_plus",
		"tinker_v3_gear_brace", "tinker_v3_spare_screws", OVERLOAD, OVERLOAD_PLUS,
		"tinker_v3_wind_up_turret", "tinker_spare_parts", "tinker_v3_scrapstorm+",
		"tinker_v3_scrapstorm_plus_plus", "tinker_v3_scrapstorm_", "scrapstorm",
		"TINKER_V3_SCRAPSTORM", "", StringName(SCRAPSTORM), null, 0, 3.5, false, [], {}]
	for wrong_id: Variant in wrong_ids:
		_rejected_scrapstorm(resolver, deck, party, enemies, wrong_id, 0, "unsupported_card",
			"unsupported ID " + str(wrong_id))
	# An authentic Scrapstorm+ the hand does not hold is still unheld.
	_rejected_scrapstorm(resolver, deck, party, enemies, SCRAPSTORM_PLUS, 0, "card_not_held",
		"authentic but unheld Scrapstorm+")

	# The printed cost is two: one energy is not enough and nothing is partially charged.
	var poor := _deck([SCRAPSTORM], 523102, 5)
	poor.combat_state.energy = 1
	_check(poor.energy == 1 and poor.hand.has(SCRAPSTORM),
		"short-energy fixture really holds a copy with one energy")
	_rejected_scrapstorm(resolver, poor, party, enemies, SCRAPSTORM, 0, "insufficient_energy",
		"one energy")

	# Scrapstorm prints FROM 3: neither the front nor the middle seat is a legal owner.
	for seat in [1, 2]:
		var wrong_seat_party := _party(seat, 3)
		var wrong_seat_deck := _deck([SCRAPSTORM], 523103 + seat, 5)
		_rejected_scrapstorm(resolver, wrong_seat_deck, wrong_seat_party, enemies, SCRAPSTORM, 0,
			"owner_illegal_position", "Scrapstorm from seat " + str(seat))

	# A party without Tinker never authorizes the play.
	var absent_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "yarn_ranger", "max_hp": 28}])
	_check(absent_owner.is_valid() and absent_owner.get_hero(3).get("id") == "yarn_ranger",
		"absent-owner fixture is a valid party without a Tinker")
	_rejected_scrapstorm(resolver, deck, absent_owner, enemies, SCRAPSTORM, 0, "owner_missing",
		"absent Tinker")

	# A second Tinker identity is a malformed roster, never a second owner.
	var duplicate := _party(3, 3)
	duplicate._heroes[0]["id"] = "tinker"
	_check(duplicate.get_hero(1).get("id") == "tinker" and duplicate.get_hero(3).get("id") == "tinker",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_scrapstorm(resolver, deck, duplicate, enemies, SCRAPSTORM, 0, "invalid_party",
		"duplicate Tinker identity")
	var bad_hp := _party(3, 3)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_scrapstorm(resolver, deck, bad_hp, enemies, SCRAPSTORM, 0, "invalid_party",
		"malformed hero HP")
	var short_party := CombatParty.new([{"id": "tinker", "max_hp": 26}])
	_rejected_scrapstorm(resolver, deck, short_party, enemies, SCRAPSTORM, 0, "invalid_party",
		"invalid one-hero party")

	# A torn (downed) owner may not fire.
	var torn_owner := _party(3, 3)
	_check(torn_owner.apply_damage(3, 26) and torn_owner.is_downed(3),
		"torn-owner fixture really has a downed Tinker")
	_rejected_scrapstorm(resolver, deck, torn_owner, enemies, SCRAPSTORM, 0, "owner_downed",
		"downed Tinker")

	# `enemy_all` accepts no caller-chosen slot.
	for slot: int in [1, 2, 3, -1, 99]:
		_rejected_scrapstorm(resolver, deck, party, enemies, SCRAPSTORM, slot, "invalid_target",
			"caller-chosen target slot " + str(slot))

	# An all-slain roster is structurally valid but offers nothing to hit. The fixture's Block absorbs
	# first, so each living slot needs its Block plus its full HP to go down.
	var all_slain := _area_enemies()
	_check(all_slain.apply_damage(1, FRONT_MAX_HP + FRONT_BLOCK)
		and all_slain.apply_damage(3, BACK_MAX_HP + BACK_BLOCK)
		and all_slain.is_defeated(),
		"all-slain fixture really has no living enemy left")
	_rejected_scrapstorm(resolver, deck, party, all_slain, SCRAPSTORM, 0, "no_living_targets",
		"all enemies slain")

	# Invalid or malformed enemy rosters fail closed.
	var empty_roster := CombatEnemies.new([])
	_check(not empty_roster.is_valid(), "empty-roster fixture really is invalid")
	_rejected_scrapstorm(resolver, deck, party, empty_roster, SCRAPSTORM, 0, "invalid_enemies",
		"empty enemy roster")
	var bad_enemy_hp := _area_enemies()
	bad_enemy_hp._enemies[0]["hp"] = 999
	_rejected_scrapstorm(resolver, deck, party, bad_enemy_hp, SCRAPSTORM, 0, "invalid_enemies",
		"malformed enemy HP")

	# A malformed stored counter is never coerced into a legal number.
	var text_counter := _party(3, 3)
	text_counter._heroes[2]["combat_scrap"] = "3"
	_rejected_scrapstorm(resolver, deck, text_counter, enemies, SCRAPSTORM, 0,
		"malformed_combat_scrap", "string Combat Scrap")
	var negative_counter := _party(3, 3)
	negative_counter._heroes[2]["combat_scrap"] = -1
	_rejected_scrapstorm(resolver, deck, negative_counter, enemies, SCRAPSTORM, 0,
		"malformed_combat_scrap", "negative Combat Scrap")
	var float_counter := _party(3, 3)
	float_counter._heroes[2]["combat_scrap"] = 1.0
	_rejected_scrapstorm(resolver, deck, float_counter, enemies, SCRAPSTORM, 0,
		"malformed_combat_scrap", "float Combat Scrap")

	# A huge but valid counter is clamped by the printed cap instead of overflowing: exactly three
	# are spent, the surplus stays, and the damage is the printed 3 + 3.
	var huge_party := _party(3, CombatParty.MAX_INT)
	var huge_deck := _deck([SCRAPSTORM], 523110, 5)
	var huge_enemies := _area_enemies()
	var huge: Dictionary = resolver.play_scrapstorm_card(huge_deck, huge_party, huge_enemies,
		SCRAPSTORM)
	_check(huge.get("ok") == true
		and huge.get("combat_scrap_before") == CombatParty.MAX_INT
		and huge.get("combat_scrap_spent") == 3
		and huge.get("combat_scrap_after") == CombatParty.MAX_INT - 3
		and huge.get("raw_damage") == 6,
		"a counter above the cap spends exactly three and retains the surplus")
	_check(huge_party.get_hero(3).get("combat_scrap") == CombatParty.MAX_INT - 3,
		"the surplus Combat Scrap stays on the Tinker's own record")
	_check(huge_enemies.get_enemy(1).get("hp") == FRONT_MAX_HP - 4
		and huge_enemies.get_enemy(3).get("hp") == BACK_MAX_HP - 1,
		"the capped play still deals its full printed damage to both living enemies")

	# The shared fixture deck, party and roster survived every refusal untouched.
	_check(deck.energy == 3 and deck.hand.has(SCRAPSTORM) and deck.discard_pile.is_empty()
		and party.get_hero(3).get("combat_scrap") == 3
		and enemies.get_enemy(1).get("hp") == FRONT_MAX_HP
		and enemies.get_enemy(1).get("block") == FRONT_BLOCK
		and enemies.get_enemy(3).get("block") == BACK_BLOCK,
		"every refusal left the shared fixture deck, party and enemies untouched")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry: Dictionary = resolver.play_scrapstorm_card(deck, party, enemies, SCRAPSTORM)
	_check(retry.get("ok") == true and retry.get("raw_damage") == 6
		and retry.get("combat_scrap_spent") == 3 and retry.get("combat_scrap_after") == 0,
		"the authentic play then succeeds once with 6 raw damage on three spent scrap")
	_check(deck.energy == 1 and deck.discard_pile == [SCRAPSTORM]
		and party.get_hero(3).get("combat_scrap") == 0
		and enemies.get_enemy(1).get("hp") == FRONT_MAX_HP - 4
		and enemies.get_enemy(3).get("hp") == BACK_MAX_HP - 1,
		"the retry paid two energy, spent the capped scrap and hit both living enemies")
	_rejected_scrapstorm(resolver, deck, party, enemies, SCRAPSTORM, 0, "card_not_held",
		"a second claim of the same copy")


## AC2 second half: the accepted single-target Overload / Overload+ contract is untouched by the new
## area spender, and neither card resolves through the other's path.
func _test_legacy_overload_untouched() -> void:
	var resolver := CombatTinkerV3OverloadCards.new()
	_check(not resolver.is_supported_card(SCRAPSTORM)
		and not resolver.is_supported_card(SCRAPSTORM_PLUS),
		"legacy Overload lookup never accepts a Scrapstorm ID")
	_check(not resolver.is_supported_scrapstorm(OVERLOAD)
		and not resolver.is_supported_scrapstorm(OVERLOAD_PLUS),
		"Scrapstorm lookup never accepts an Overload ID")
	_check(CombatTinkerV3OverloadCards.overload_definition(SCRAPSTORM).is_empty()
		and CombatTinkerV3OverloadCards.overload_definition(SCRAPSTORM_PLUS).is_empty(),
		"neither Scrapstorm ID resolves as an Overload definition")

	# A real held, seeded turn: the area spender refuses the single-target ID outright.
	var party := _party(3, 3)
	var deck := _deck([OVERLOAD, SCRAPSTORM], 524100, 5)
	var enemies := _area_enemies()
	_rejected_scrapstorm(resolver, deck, party, enemies, OVERLOAD, 0, "unsupported_card",
		"Scrapstorm path refuses Overload")
	_rejected_scrapstorm(resolver, deck, party, enemies, OVERLOAD_PLUS, 0, "unsupported_card",
		"Scrapstorm path refuses Overload+")

	# Legacy Overload from the same deck still pays one energy, spends the whole counter and hits only
	# the one chosen living enemy through its Block.
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = resolver.play_card(deck, party, enemies, OVERLOAD, 1)
	_check(result.get("ok") == true and result.get("reason") == "applied"
		and result.get("raw_damage") == 11 and result.get("cost") == 1,
		"legacy Overload still resolves its 2 + 3 x 3 damage for one energy")
	_check(result.get("combat_scrap_before") == 3 and result.get("combat_scrap_after") == 0
		and result.get("target_position") == 1,
		"legacy Overload still spends the whole counter on its one chosen enemy")
	_check(deck.energy == 2 and deck.discard_pile == [OVERLOAD]
		and deck.hand.count(SCRAPSTORM) == 1,
		"legacy Overload paid one energy and discarded only its own copy")
	_check(party.get_hero(3).get("combat_scrap") == 0, "legacy Overload spent the counter")
	_check(enemies.get_enemy(1).get("hp") == FRONT_MAX_HP - 9
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(3).get("hp") == BACK_MAX_HP
		and enemies.get_enemy(3).get("block") == BACK_BLOCK,
		"legacy Overload hit only its chosen enemy and left the rest of the line alone")
	_check(deck._rng.state == int(before["rng_state"]), "legacy Overload consumed no RNG")

	# The surviving Scrapstorm copy still plays afterwards from the same real hand; Overload left the
	# front enemy alive, so both living slots take its printed base damage.
	var area: Dictionary = resolver.play_scrapstorm_card(deck, party, enemies, SCRAPSTORM)
	_check(area.get("ok") == true and area.get("raw_damage") == 3
		and area.get("targets_hit") == [1, 3] and area.get("combat_scrap_after") == 0,
		"the surviving Scrapstorm then hits both living enemies for its printed base damage")
	_check(deck.energy == 0 and deck.discard_pile == [OVERLOAD, SCRAPSTORM]
		and enemies.get_enemy(1).get("hp") == FRONT_MAX_HP - 12
		and enemies.get_enemy(3).get("block") == BACK_BLOCK - 3,
		"the later Scrapstorm paid its own two energy and absorbed into the back enemy's Block")


## A refusal on real fixtures: both the pure preflight and the paid play return the reason and leave
## every deck, party, enemy, counter and RNG value exactly as it was.
func _rejected_scrapstorm(resolver: CombatTinkerV3OverloadCards, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: Variant, target: int,
		reason: String, label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var plan: Dictionary = resolver.preflight_scrapstorm(deck, party, enemies, card_id, target)
	_check(plan.get("ok") == false and plan.get("reason") == reason,
		label + ": pure preflight also refuses with " + reason)
	_check(_snapshot(deck, party, enemies) == before, label + ": preflight itself changed no state")
	var result: Dictionary = resolver.play_scrapstorm_card(deck, party, enemies, card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": unchanged energy, hand, piles, turn, party, counters, enemies and RNG")
