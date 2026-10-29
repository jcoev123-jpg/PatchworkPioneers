class_name CombatLanternMonkBlindStrikeCards
extends RefCounted
## Scene-free paid resolver for the Lantern Monk's three single-target lantern flashes (V3-1).
##
## Six exact printings make up this one card family: the dedicated starter Wick Spark (`lantern_monk_wick_spark`,
## base and '+', from LanternMonkStarterCards) and the reward-pool Wick Flicker and Snuff Flame (base and '+',
## from LanternMonkPoolCards). Every printing costs 1, comes only from the round lantern-bearing Monk's middle or
## rear seat (FROM [2, 3]), targets exactly one enemy (`enemy_single`, TO [1, 2, 3]) and lands one printed damage
## hit, then Blinds that enemy. Snuff Flame additionally leaves it Exposed.
##
## Blind is the shared one-shot "this enemy's NEXT attack misses" marker, never a skipped turn, a duration or a
## stack. On the authoritative enemy record it is the canonical integer token `blind_next_attack: 1` (0 is inert),
## the same shape `CombatStatuses`, `CombatStatusTurnBatch` and `CombatEnemyPhase` already validate and consume. The
## starter prints the descriptor as `blind: 1` and the pool cards print `blind_next_attack: true`; BOTH project to
## that same one-shot status. A cast re-arms it at exactly 1 and never spends it, so an already-armed 1 stays 1.
## Neither this cast nor an owner-turn status tick consumes it: only the existing `CombatEnemyPhase` attack beat
## does, and that loop is not modified here.
##
## Damage reuses `CombatStatusAttacks.resolve_vs_enemy` for exactly ONE hit against the real `CombatEnemies` roster,
## using the attacker's and defender's authoritative pre-hit status snapshots. The shared rules own Weak (-25%),
## Exposed (+50%), Tangled (+2) and Block-before-HP. Blind is added only after the successful hit (even when Block
## absorbed it), and Snuff Flame's Exposed is added after the hit too, so that new Exposed never boosts its own
## damage. Both `CombatStatuses` and `CombatStatusAttacks` accept a wider or narrower status vocabulary per role, so
## the legal one-shot Dodge on the attacker and Blind on the defender are bridged while those non-damage tokens stay
## on the original actors unchanged. No status is aged, spent or removed by this service.
##
## `CombatEnemies.apply_statuses` supports Exposed but not the one-shot Blind, so the Blind token is persisted
## directly on the authoritative selected enemy record after Exposed's whole-roster preflight (`can_apply_statuses`)
## has already passed; every other enemy and every other status stays exactly as it was and the original slot is
## kept. Nothing here draws, shuffles or advances the run RNG, so a refusal (and a cast) leaves it untouched.
##
## The catalogs stay authoritative: the caller supplies only the held card ID and an enemy position, never a cost,
## seat, effect or damage magnitude. The whole exact base/'+' printing pair is authenticated from the catalog that
## owns it before anything is charged, and the party, enemy roster, every status map, the target and the Exposed
## overflow are all validated before the first mutation. Every refusal is a pure no-op.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand, rewards, run deck,
## battle HUD or the app flow; wiring them into the real live attack dispatcher is a later, separately owned task.

const OWNER := "lantern_monk"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS: Array[int] = [2, 3]
const TO_POSITIONS: Array[int] = [1, 2, 3]
const BLIND_STATUS_KEY := "blind_next_attack"
const DODGE_STATUS_KEY := "dodge_next_attack"
const BLIND_TOKEN := 1
## `blind: 1` is the starter's printed descriptor and `blind_next_attack: true` the pool's; both mean one Blind.
const STARTER_BLIND_KEY := "blind"

## Every authentic printing with the exact catalog line it must still carry. `damage` is the printed positive raw
## hit; `exposed` is the printed post-hit Exposed addition (0 when the card adds none). `catalog` names the one
## catalog allowed to own the ID, so a copied or relinked record in the other catalog is never paid for.
const CARDS := {
	"lantern_monk_wick_spark": {
		"catalog": "starter",
		"display_name": "Wick Spark",
		"cost": 1,
		"damage": 4,
		"exposed": 0,
		"effects": {"damage": 4, "blind": 1},
		"starting_copies": 1,
		"reward_eligible": false,
		"upgrade_id": "lantern_monk_wick_spark_plus",
	},
	"lantern_monk_wick_spark_plus": {
		"catalog": "starter",
		"display_name": "Wick Spark+",
		"cost": 1,
		"damage": 6,
		"exposed": 0,
		"effects": {"damage": 6, "blind": 1},
		"starting_copies": 0,
		"reward_eligible": false,
		"upgrade_of": "lantern_monk_wick_spark",
	},
	"lantern_monk_wick_flicker": {
		"catalog": "pool",
		"display_name": "Wick Flicker",
		"cost": 1,
		"damage": 4,
		"exposed": 0,
		"effects": {"damage": 4, "blind_next_attack": true},
		"starting_copies": 0,
		"reward_eligible": true,
		"rarity": "common",
		"upgrade_id": "lantern_monk_wick_flicker_plus",
	},
	"lantern_monk_wick_flicker_plus": {
		"catalog": "pool",
		"display_name": "Wick Flicker+",
		"cost": 1,
		"damage": 6,
		"exposed": 0,
		"effects": {"damage": 6, "blind_next_attack": true},
		"starting_copies": 0,
		"reward_eligible": false,
		"rarity": "common",
		"upgrade_of": "lantern_monk_wick_flicker",
	},
	"lantern_monk_snuff_flame": {
		"catalog": "pool",
		"display_name": "Snuff Flame",
		"cost": 1,
		"damage": 3,
		"exposed": 1,
		"effects": {"damage": 3, "blind_next_attack": true, "exposed": 1},
		"starting_copies": 0,
		"reward_eligible": true,
		"rarity": "uncommon",
		"upgrade_id": "lantern_monk_snuff_flame_plus",
	},
	"lantern_monk_snuff_flame_plus": {
		"catalog": "pool",
		"display_name": "Snuff Flame+",
		"cost": 1,
		"damage": 4,
		"exposed": 2,
		"effects": {"damage": 4, "blind_next_attack": true, "exposed": 2},
		"starting_copies": 0,
		"reward_eligible": false,
		"rarity": "uncommon",
		"upgrade_of": "lantern_monk_snuff_flame",
	},
}

var _statuses := CombatStatuses.new()
var _attacks := CombatStatusAttacks.new()


## The single paid transaction: authenticate the exact printing pair, preflight the whole request, then charge the
## printed cost, discard exactly one genuine held copy and resolve one printed hit followed by the printed statuses.
## A refusal changes no deck, party, enemy, status or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, enemy_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, enemy_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the exact held ID is
	# affordable, the owner sits in an authored seat, the selected slot is a living original enemy slot, whole
	# status maps are well formed and every status application fits. Keep the defensive returns so an unexpected
	# model change still fails closed rather than paying for a partial effect.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var target: int = int(plan["enemy_position"])
	# Exactly ONE real hit through the shared status bridge, with the authoritative pre-hit snapshots. The bridge
	# owns Weak/Exposed/Tangled rounding and Block-before-HP.
	var hit: Dictionary = _attacks.resolve_vs_enemy(enemies, target, int(plan["base_damage"]),
		plan["attacker_statuses"], plan["defender_statuses"])
	if not hit.get("ok", false):
		return _refusal("hit_failed")
	# The real authoritative record, never a detached get_enemy copy. Blind is one-shot: never a second stack and
	# never spent by this cast.
	var record: Dictionary = enemies._enemies[target - 1]
	if not record.has("statuses"):
		record["statuses"] = {}
	var statuses: Dictionary = record["statuses"]
	var blind_before: int = int(statuses.get(BLIND_STATUS_KEY, 0))
	statuses[BLIND_STATUS_KEY] = BLIND_TOKEN
	# Snuff Flame's Exposed lands only after the hit, so it can never boost its own damage. Preflighted above.
	var exposed_added: int = int(plan["exposed"])
	if exposed_added > 0 and not enemies.apply_statuses({target: {"exposed": exposed_added}}):
		return _refusal("status_failed")
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"target_kind": TARGET_KIND,
		"target_position": target,
		"target_id": str(record.get("id", "")),
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"base_damage": int(plan["base_damage"]),
		"damage": int(hit["damage"]),
		"block_absorbed": int(hit["block_absorbed"]),
		"hp_loss": int(hit["hp_loss"]),
		"hp_before": int(plan["hp_before"]),
		"hp_after": int(record["hp"]),
		"block_before": int(plan["block_before"]),
		"block_after": int(record["block"]),
		"blind_before": blind_before,
		"blind_after": BLIND_TOKEN,
		"blind_already_active": blind_before == BLIND_TOKEN,
		"exposed_applied": exposed_added,
		"exposed_after": int(statuses.get("exposed", 0)),
	}


## True only for the six authentic catalog printings. Pure lookup; nothing is charged or mutated and no RNG is
## touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return _authentic_pair(id, CARDS[id])


## Pure authenticated definition query: the detached catalog record for a supported printing, or {} when the ID is
## unknown, unsupported or its authored record/pair no longer matches. Nothing is charged or mutated.
func get_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not CARDS.has(id):
		return {}
	var definition: Dictionary = _catalog_definition(id)
	if not _authentic_pair(id, CARDS[id]):
		return {}
	return definition


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, enemy_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null:
		return _refusal("invalid_deck")
	if not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if not enemies.is_valid():
		return _refusal("invalid_enemies")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	var card: Dictionary = CARDS[id]
	# The source catalog is authoritative: a rewritten, relinked or foreign record can never be paid for.
	if not _authentic_pair(id, card):
		return _refusal("catalog_mismatch")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Verify the complete party roster, every hero's authoritative status shape, then bind the one distinct owner by
	# hero ID to its actual current slot. A swapped seat, duplicated owner or torn ally is handled explicitly.
	var heroes: Array[Dictionary] = party.get_heroes()
	if heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	var owner_position := 0
	var owner_count := 0
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id = hero.get("id")
		var position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		var block = hero.get("block")
		if not hero_id is String or hero_id.is_empty():
			return _refusal("invalid_party")
		if not position is int or position != index + 1:
			return _refusal("invalid_party")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_party")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_party")
		if not block is int or block < 0:
			return _refusal("invalid_party")
		if not _valid_status_shape(hero.get("statuses", {})):
			return _refusal("malformed_statuses")
		if hero_id == OWNER:
			owner_count += 1
			owner_position = index + 1
	# The shared turn-batch validator must also accept every authoritative hero record and status map.
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes).get("ok", false):
		return _refusal("invalid_party")
	if owner_count != 1:
		return _refusal("owner_missing" if owner_count == 0 else "duplicate_owner")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# The whole enemy roster must still be the vocabulary the shared status rules accept (unknown keys, wrong
	# Variant types, negative counters and a non-0/1 Blind or Dodge token all fail), and every slot must keep its
	# original position.
	var roster: Array[Dictionary] = enemies.get_enemies()
	if roster.is_empty() or roster.size() > CombatEnemies.MAX_ENEMIES:
		return _refusal("invalid_enemies")
	var seen_enemy_ids: Array[String] = []
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		var enemy_id = enemy.get("id")
		var hp = enemy.get("hp")
		var max_hp = enemy.get("max_hp")
		var block = enemy.get("block")
		if not enemy_id is String or enemy_id.is_empty() or seen_enemy_ids.has(enemy_id):
			return _refusal("invalid_enemies")
		seen_enemy_ids.append(enemy_id)
		if enemy.get("position") != index + 1:
			return _refusal("invalid_enemies")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_enemies")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_enemies")
		if not block is int or block < 0:
			return _refusal("invalid_enemies")
		if not _valid_status_shape(enemy.get("statuses", {})):
			return _refusal("malformed_statuses")
	if not CombatStatusTurnBatch.new().tick_side("enemies", roster).get("ok", false):
		return _refusal("malformed_statuses")

	# `enemy_single` names one original slot inside the printed TO list; positions never compact on death.
	if not TO_POSITIONS.has(enemy_position) or enemy_position > roster.size():
		return _refusal("invalid_target")
	if int(roster[enemy_position - 1]["hp"]) == 0:
		return _refusal("target_slain")

	# Bridge the authoritative snapshots into the shared attack validator's per-role vocabulary. The legal one-shot
	# Dodge on the attacker and Blind on the defender are admitted there; the opposite role token is left on the
	# original actor and never passed to the narrower validator or consumed.
	var attacker_statuses: Dictionary = _attacker_snapshot(heroes[owner_position - 1].get("statuses", {}))
	var defender_statuses: Dictionary = _defender_snapshot(roster[enemy_position - 1].get("statuses", {}))
	if not _attacks._valid_attacker_statuses(attacker_statuses):
		return _refusal("malformed_statuses")
	if not _attacks._valid_defender_statuses(defender_statuses):
		return _refusal("malformed_statuses")

	# The printed post-hit Exposed must be representable on this enemy; verify the addition before paying.
	var exposed: int = int(card["exposed"])
	if exposed > 0 and not enemies.can_apply_statuses({enemy_position: {"exposed": exposed}}):
		return _refusal("exposed_overflow")

	var target: Dictionary = roster[enemy_position - 1]
	var target_statuses: Dictionary = target.get("statuses", {})
	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"enemy_position": enemy_position,
		"base_damage": int(card["damage"]),
		"exposed": exposed,
		"attacker_statuses": attacker_statuses,
		"defender_statuses": defender_statuses,
		"energy_before": deck.energy,
		"hp_before": int(target["hp"]),
		"block_before": int(target["block"]),
		"blind_before": int(target_statuses.get(BLIND_STATUS_KEY, 0)),
	}


## The status shape the shared combat rules accept: named N-turn counters with non-negative int counts, the two
## one-shot tokens as integer 0/1, and Fear (`cannot_buff_next_turn`) as the literal boolean true only. Anything
## else fails closed before mutation.
func _valid_status_shape(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	return _statuses._valid_statuses(statuses)


## A detached bridge-compatible view of the attacker's authoritative statuses. Dodge and every damage counter are
## admitted by CombatStatusAttacks for an attacker; a Blind token (which belongs to a defender) is left on the
## original hero record untouched.
func _attacker_snapshot(statuses: Dictionary) -> Dictionary:
	var projected: Dictionary = statuses.duplicate(true)
	projected.erase(BLIND_STATUS_KEY)
	return projected


## A detached bridge-compatible view of the defender's authoritative statuses. Blind and every damage counter are
## admitted for a defender; a Dodge token (which belongs to an attacker) is left on the original enemy record.
func _defender_snapshot(statuses: Dictionary) -> Dictionary:
	var projected: Dictionary = statuses.duplicate(true)
	projected.erase(DODGE_STATUS_KEY)
	return projected


## Reads the exact authored record from the catalog that owns this ID (never the other hero catalogs) and returns a
## detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return LanternMonkStarterCards.new().get_definition(card_id)
	if source == "pool":
		return LanternMonkPoolCards.new().get_definition(card_id)
	return {}


## Reads the exact authored records and proves BOTH printings of the pair still carry their whole authored line, so
## a rewritten catalog (extra effect, another seat, target, cost, rarity, copy count, art path or a broken upgrade
## link) can never be paid for as this effect. Both printings are authenticated for either requested ID.
func _authentic_pair(card_id: String, card: Dictionary) -> bool:
	var definition: Dictionary = _catalog_definition(card_id)
	if not _authentic_record(definition, card_id, card):
		return false
	if card.has("upgrade_id"):
		var plus_id: String = str(card["upgrade_id"])
		if not CARDS.has(plus_id):
			return false
		var plus: Dictionary = _catalog_definition(plus_id)
		if plus.get("upgrade_of") != card_id or plus.has("upgrade_id"):
			return false
		return _authentic_record(plus, plus_id, CARDS[plus_id])
	var base_id: String = str(card["upgrade_of"])
	if not CARDS.has(base_id):
		return false
	var base: Dictionary = _catalog_definition(base_id)
	if base.get("upgrade_id") != card_id or base.has("upgrade_of"):
		return false
	return _authentic_record(base, base_id, CARDS[base_id])


## The exact contract for one printing: identity, printed name, Monk owner, printed cost, the `enemy_single` target
## with the authored FROM/TO slots, the complete effect dictionary with exact Variant types, the copy count and
## reward flag the owning catalog prints, the base art path, the pool-only rarity and the base/'+' link. Any
## missing, extra, retyped or altered field refuses.
func _authentic_record(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id:
		return false
	if definition.get("display_name") != card["display_name"]:
		return false
	if definition.get("owner") != OWNER:
		return false
	if not definition.get("cost") is int or int(definition.get("cost")) != int(card["cost"]):
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _exact_positions(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _exact_positions(definition.get("to_positions"), TO_POSITIONS):
		return false
	if not _same_value(definition.get("effects"), card["effects"]):
		return false
	var starting_copies: Variant = definition.get("starting_copies")
	if not starting_copies is int or int(starting_copies) != int(card["starting_copies"]):
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or bool(reward_eligible) != bool(card["reward_eligible"]):
		return false
	var base_id: String = card_id.trim_suffix("_plus")
	if definition.get("illustration_path") != "res://assets/paper/cards/" + base_id + ".png":
		return false
	# The starter catalog prints no reward rarity; the pool prints exactly the authored one.
	if card.has("rarity"):
		if definition.get("rarity") != card["rarity"]:
			return false
	elif definition.has("rarity"):
		return false
	# The base and "+" records must still point at each other, so a copied or relinked record cannot be paid for
	# under the other printing's ID.
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## Typed equality rejects coercible metadata (e.g. a String "1" or an int 1 standing in for the boolean pool Blind
## descriptor, or a bool standing in for an int cost) as well as changed effects.
func _same_value(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		var expected_dict: Dictionary = expected
		if actual.size() != expected_dict.size():
			return false
		for key in expected_dict:
			if not (actual as Dictionary).has(key):
				return false
			if not _same_value(actual[key], expected_dict[key]):
				return false
		return true
	if expected is Array:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_value(actual[index], expected[index]):
				return false
		return true
	return actual == expected


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
