class_name CombatTinkerV3TurretCards
extends RefCounted
## Scene-free paid resolver for Tinker's Wind-up Turret and Wind-up Turret+ (V3-1).
##
## The hunched goggled scrap-tinker bolts a clockwork turret onto the floor behind the line: it costs two
## energy, is cast only from the back seat (FROM 3), targets self, deals no damage on deployment, and then
## fires 3 (Wind-up Turret) or 4 (Wind-up Turret+) raw damage at a RANDOM living enemy at the END of each
## player turn for exactly three turns. The turret is a summoned gadget effect, never the enemy-summon
## keyword, and it reads and spends no Combat Scrap and no run-wallet `scraps`.
##
## The authored V3TinkerPoolCards catalog stays authoritative: the caller supplies a held ID and a self-target
## indication (0, no enemy selected), never a card record, a cost, a damage figure, a duration or an effect
## payload. Each ID is authenticated against its own printed record before anything is paid, so a forged,
## rewritten, relinked or foreign record is refused instead of resolving as a turret.
##
## A confirmed play pays the printed cost once, discards exactly one held copy and returns a DETACHED pending
## instance carrying exactly three remaining end-of-player-turn beats and the authenticated per-tick damage.
## Neither the play nor the construction of that instance draws RNG or touches any enemy: the turret fires
## only when a FUTURE battle owner calls tick_turret at its own end-of-player-turn boundary, with the real
## CombatEnemies roster and the existing caller-seeded run RNG.
##
## A tick chooses uniformly from the LIVING enemies' actual slots (1-3) through that supplied RNG only when at
## least two are alive, hits exactly one of them with the stored damage through CombatEnemies.apply_damage
## (Block before HP) and returns a detached receipt plus next state. One living enemy is hit without a
## needless RNG call; zero living enemies do no damage, consume no RNG and still spend the scheduled beat. After
## three ticks the instance is expired and a fourth tick is inert. Slain slots keep their id and position,
## are never resurrected and are never retargeted. Two independently deployed instances never share a counter.
##
## A shot is a confirmed hit for the Enrage keyword: any positive damage (a blow fully absorbed by Block
## included) commits one stack on an `enrage: true` target through CombatEnemyKeywordRules, capped at three,
## so that foe's next real attack gains the keyword's bonus. Every living candidate's Enrage metadata is
## checked before a target is chosen, the RNG is drawn or any state changes, so malformed metadata refuses
## the whole tick.
##
## This is callable rules-layer behaviour only. Admitting these two IDs to the mounted hand, preserving
## battle-local pending turrets and calling the tick on the real end-of-player-turn path are a later,
## separately owned wiring task.

const OWNER := "tinker"
const TARGET_KIND := "self"
## Wind-up Turret prints target_kind "self": 0 is the only legal recipient (no enemy slot is selected).
const SELF_TARGET := 0
const TURRET_KIND := "wind_up_turret"
const TICK_BOUNDARY := "end_player_turn"
const DURATION_TURNS := 3
const FROM_POSITIONS := [3]
const TO_POSITIONS := []

## The two authentic printings and the exact catalog line each one must still carry. `damage` is the printed
## per-tick damage, `duration_turns` the printed number of end-of-player-turn ticks and `effects` the complete
## authored effect dictionary (no extra or missing keys, typed values only).
const CARDS := {
	"tinker_v3_wind_up_turret": {
		"cost": 2,
		"from_positions": [3],
		"damage": 3,
		"duration_turns": 3,
		"is_upgrade": false,
		"upgrade_id": "tinker_v3_wind_up_turret_plus",
		"effects": {"turret": {"damage": 3, "duration_turns": 3,
			"tick": "end_player_turn", "target_kind": "enemy_random",
			"living_targets_only": true, "rng_source": "run"}},
	},
	"tinker_v3_wind_up_turret_plus": {
		"cost": 2,
		"from_positions": [3],
		"damage": 4,
		"duration_turns": 3,
		"is_upgrade": true,
		"base_id": "tinker_v3_wind_up_turret",
		"effects": {"turret": {"damage": 4, "duration_turns": 3,
			"tick": "end_player_turn", "target_kind": "enemy_random",
			"living_targets_only": true, "rng_source": "run"}},
	},
}

## The complete, closed key set of a detached pending turret instance. Anything else is a foreign or
## tampered shape and is refused without touching the roster or the RNG.
const PENDING_KEYS := ["kind", "card_id", "damage", "duration_turns", "remaining",
	"tick", "target_kind", "living_targets_only", "rng_source"]

const _CATALOG := preload("res://data/cards/v3_tinker_pool_cards.gd")

var _catalog := _CATALOG.new()
var _keywords := CombatEnemyKeywordRules.new()


## True only for the two authentic catalog printings. Pure lookup; nothing is charged or mutated and no RNG
## is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return is_authentic_definition(_catalog.get_definition(id), id)


## A detached, shape-checked turret definition from V3TinkerPoolCards, or {} for anything else. Unrelated
## cards, forged spellings, tampered records and the v2 Tinker pool all resolve to {}.
static func turret_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not CARDS.has(id):
		return {}
	var definition: Dictionary = _CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return {}
	return definition


## The record must still carry exactly the authored line: id, Tinker owner, the printed integer cost, the
## self target, the exact FROM seat and empty TO line, exactly the printed effect dictionary (typed integers,
## boolean and strings, no extra or missing keys) and the base/"+" link expressed with V3TinkerPoolCards'
## base_id/upgrade_id/is_upgrade fields. A stray `upgrade_of` is a foreign shape.
static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if typeof(definition.get("cost")) != TYPE_INT or definition["cost"] != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _matches_authored(definition.get("from_positions"), card["from_positions"]):
		return false
	if not _matches_authored(definition.get("to_positions"), TO_POSITIONS):
		return false
	if not _matches_authored(definition.get("effects"), card["effects"]):
		return false
	if definition.has("upgrade_of"):
		return false
	var base_id: String = id.trim_suffix("_plus") if card["is_upgrade"] else id
	if definition.get("base_id") != base_id:
		return false
	if definition.get("upgrade_id") != base_id + "_plus":
		return false
	if typeof(definition.get("is_upgrade")) != TYPE_BOOL:
		return false
	return definition["is_upgrade"] == card["is_upgrade"]


## Recursive exact-shape comparison: every level must carry the authored keys, values and Variant types, so
## `3.0`, `"3"` or a missing/extra key never authenticates as the printed record.
static func _matches_authored(value: Variant, expected: Variant) -> bool:
	if typeof(expected) == TYPE_DICTIONARY:
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var actual: Dictionary = value
		var wanted: Dictionary = expected
		if actual.size() != wanted.size():
			return false
		for key in wanted:
			if not actual.has(key):
				return false
			if not _matches_authored(actual[key], wanted[key]):
				return false
		return true
	if typeof(expected) == TYPE_ARRAY:
		if typeof(value) != TYPE_ARRAY:
			return false
		var actual_items: Array = value
		var wanted_items: Array = expected
		if actual_items.size() != wanted_items.size():
			return false
		for index in range(wanted_items.size()):
			if not _matches_authored(actual_items[index], wanted_items[index]):
				return false
		return true
	if typeof(value) != typeof(expected):
		return false
	return value == expected


## Read-only preflight of the whole deployment: authenticates the held ID, the inactive/active boundary, the
## complete roster, the unique living Tinker in the authored back seat, the self target and the energy.
## Returns a detached plan or a refusal receipt; no state changes and no RNG is touched.
func preflight(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = SELF_TARGET) -> Dictionary:
	if deck == null or party == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	# Fetch the authored record from the catalog that owns this ID before anything is paid.
	var definition: Dictionary = turret_definition(id)
	if definition.is_empty():
		return _refusal("catalog_mismatch")
	var card: Dictionary = CARDS[id]

	# Validate the complete roster, then bind the owner by hero ID to its ACTUAL current slot. A swapped seat
	# grants no false authority and a second Tinker is a malformed roster, never a second owner.
	var heroes: Array[Dictionary] = party.get_heroes()
	var seen_ids: Array[String] = []
	var owner_position := 0
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id = hero.get("id")
		var position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		var block = hero.get("block")
		if not hero_id is String or hero_id.is_empty() or seen_ids.has(hero_id):
			return _refusal("invalid_party")
		if not position is int or position != index + 1:
			return _refusal("invalid_party")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_party")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_party")
		if not block is int or block < 0:
			return _refusal("invalid_party")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1

	if owner_position == 0:
		return _refusal("owner_missing")
	# Wind-up Turret prints FROM 3: only the back seat may deploy it.
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# These cards print target_kind self: only the Tinker himself is a legal recipient.
	if not target_position is int or target_position != SELF_TARGET:
		return _refusal("invalid_target")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")
	var damage: int = int(card["damage"])
	var duration: int = int(card["duration_turns"])
	if damage <= 0 or duration != DURATION_TURNS:
		return _refusal("catalog_mismatch")

	return {
		"ok": true,
		"reason": "legal",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": owner_position,
		"damage": damage,
		"duration_turns": duration,
		"energy_before": deck.energy,
	}


## The single paid deployment: preflight the whole request, then pay the printed energy, discard exactly one
## held copy and publish one independent detached pending instance with three remaining end-of-player-turn
## beats. No enemy is touched and no RNG is drawn. A refusal changes no deck, party or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = SELF_TARGET) -> Dictionary:
	var plan: Dictionary = preflight(deck, party, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above. Keep the defensive returns so an
	# unexpected model change still fails closed before the next write.
	var id: String = str(plan["card_id"])
	var cost: int = int(plan["cost"])
	if not deck.try_spend_energy(cost):
		return _refusal("insufficient_energy")
	if not deck.discard_played(id):
		return _refusal("card_not_held")
	var card: Dictionary = CARDS[id]
	var state: Dictionary = {
		"kind": TURRET_KIND,
		"card_id": id,
		"damage": int(card["damage"]),
		"duration_turns": int(card["duration_turns"]),
		"remaining": int(card["duration_turns"]),
		"tick": TICK_BOUNDARY,
		"target_kind": "enemy_random",
		"living_targets_only": true,
		"rng_source": "run",
	}
	return {
		"ok": true,
		"reason": "deployed",
		"card_id": id,
		"cost": cost,
		"owner_position": int(plan["owner_position"]),
		"target_position": int(plan["owner_position"]),
		"damage": int(card["damage"]),
		"duration_turns": int(card["duration_turns"]),
		"remaining": int(card["duration_turns"]),
		"immediate_damage": 0,
		"rng_consumed": false,
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"state": state.duplicate(true),
	}


## True only for a well-formed detached instance of either authentic printing with zero to three beats left
## (the expired zero included). Pure lookup: it neither mutates the instance nor touches a roster or RNG.
static func is_pending_instance(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = value
	if state.size() != PENDING_KEYS.size():
		return false
	for key in PENDING_KEYS:
		if not state.has(key):
			return false
	if state["kind"] != TURRET_KIND:
		return false
	if typeof(state["card_id"]) != TYPE_STRING:
		return false
	var card: Dictionary = CARDS.get(state["card_id"], {})
	if card.is_empty():
		return false
	if typeof(state["damage"]) != TYPE_INT or state["damage"] != card["damage"]:
		return false
	if typeof(state["duration_turns"]) != TYPE_INT or state["duration_turns"] != DURATION_TURNS:
		return false
	if typeof(state["remaining"]) != TYPE_INT:
		return false
	if int(state["remaining"]) < 0 or int(state["remaining"]) > DURATION_TURNS:
		return false
	if state["tick"] != TICK_BOUNDARY:
		return false
	if state["target_kind"] != "enemy_random":
		return false
	if typeof(state["living_targets_only"]) != TYPE_BOOL or state["living_targets_only"] != true:
		return false
	if state["rng_source"] != "run":
		return false
	return true


## One end-of-player-turn tick for ONE detached pending instance: choose a living enemy (the supplied run RNG
## picks uniformly only when at least two are alive), hit it once for the stored 3 or 4 through
## CombatEnemies.apply_damage so Block absorbs before HP, and return a detached receipt with the next state.
## A malformed or tampered instance, an invalid roster, a missing RNG or an already expired instance is
## refused with no change to the roster, the instance or the RNG.
func tick_turret(current: Variant, enemies: CombatEnemies, rng: RandomNumberGenerator) -> Dictionary:
	if enemies == null:
		return _refusal("invalid_enemies")
	if rng == null:
		return _refusal("invalid_rng")
	if not enemies.is_valid():
		return _refusal("invalid_enemies")
	var enemy_records: Array[Dictionary] = enemies.get_enemies()
	var seen_enemy_ids: Array[String] = []
	for index in range(enemy_records.size()):
		var enemy: Dictionary = enemy_records[index]
		var enemy_id = enemy.get("id")
		var enemy_position = enemy.get("position")
		var enemy_hp = enemy.get("hp")
		var enemy_max_hp = enemy.get("max_hp")
		var enemy_block = enemy.get("block")
		if not enemy_id is String or enemy_id.is_empty() or seen_enemy_ids.has(enemy_id):
			return _refusal("invalid_enemies")
		if not enemy_position is int or enemy_position != index + 1:
			return _refusal("invalid_enemies")
		if not enemy_max_hp is int or enemy_max_hp <= 0:
			return _refusal("invalid_enemies")
		if not enemy_hp is int or enemy_hp < 0 or enemy_hp > enemy_max_hp:
			return _refusal("invalid_enemies")
		if not enemy_block is int or enemy_block < 0:
			return _refusal("invalid_enemies")
		# Any living slot may be the random target, so its Enrage flag and stack count are checked here,
		# with the keyword's own validator, before a target is chosen or anything is spent.
		if enemy_hp > 0 and not _keywords.quote_enrage_after_hit(enemy,
				{"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0})["ok"]:
			return _refusal("invalid_enrage")
		seen_enemy_ids.append(enemy_id)

	if not is_pending_instance(current):
		return _refusal("invalid_turret")
	var state: Dictionary = current
	var remaining_before: int = int(state["remaining"])
	if remaining_before <= 0:
		return _refusal("turret_expired")
	var damage: int = int(state["damage"])

	# Living slots in ascending original position; a slain slot is never listed, resurrected or retargeted.
	var living: Array[int] = []
	for enemy in enemy_records:
		if int(enemy.get("hp", 0)) > 0:
			living.append(int(enemy.get("position", 0)))
	living.sort()

	var rng_state_before: int = rng.state
	var target: int = 0
	if living.size() >= 2:
		target = living[rng.randi_range(0, living.size() - 1)]
	elif living.size() == 1:
		target = living[0]

	var block_absorbed: int = 0
	var hp_loss: int = 0
	var target_id := ""
	var block_before: int = 0
	var hp_before: int = 0
	if target > 0:
		var enemy_before: Dictionary = enemies.get_enemy(target)
		target_id = str(enemy_before.get("id", ""))
		block_before = int(enemy_before.get("block", 0))
		hp_before = int(enemy_before.get("hp", 0))
		if not enemies.apply_damage(target, damage):
			return _refusal("damage_rejected")
		var enemy_after: Dictionary = enemies.get_enemy(target)
		block_absorbed = block_before - int(enemy_after.get("block", 0))
		hp_loss = hp_before - int(enemy_after.get("hp", 0))
		# The shot is the authentic Block-first hit on the frozen pre-hit record; Enrage reads that receipt.
		var hit := {"ok": true, "damage": damage, "block_absorbed": block_absorbed, "hp_loss": hp_loss}
		if not _keywords.commit_enrage_after_hit(enemies, target, enemy_before, hit)["ok"]:
			# Fail closed: put the slot and the RNG back so a refused tick leaves nothing behind.
			enemies._enemies[target - 1] = enemy_before.duplicate(true)
			rng.state = rng_state_before
			return _refusal("enrage_rejected")

	var next_state: Dictionary = state.duplicate(true)
	next_state["remaining"] = remaining_before - 1

	return {
		"ok": true,
		"reason": "ticked",
		"card_id": str(state["card_id"]),
		"damage": damage if target > 0 else 0,
		"stored_damage": damage,
		"tick": TICK_BOUNDARY,
		"remaining_before": remaining_before,
		"remaining": remaining_before - 1,
		"expired": remaining_before - 1 == 0,
		"living_positions": living.duplicate(),
		"target_position": target,
		"target_id": target_id,
		"enemy_block_before": block_before,
		"enemy_hp_before": hp_before,
		"block_absorbed": block_absorbed,
		"hp_loss": hp_loss,
		"damage_dealt": block_absorbed + hp_loss,
		"rng_consumed": rng.state != rng_state_before,
		"state": next_state,
	}


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
