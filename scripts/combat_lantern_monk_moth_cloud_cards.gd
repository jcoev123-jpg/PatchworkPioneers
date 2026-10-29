class_name CombatLanternMonkMothCloudCards
extends RefCounted
## Scene-free paid resolver for the Lantern Monk's area Moth Cloud printings (V3-1).
##
## Moth Cloud is the Monk's v3 RARE reward: the base printing costs 2, Moth Cloud+ costs 1, both come
## only from the Monk's middle or rear seat (FROM [2, 3]), target every enemy (`enemy_all`, TO [1, 2, 3])
## and print exactly `{"blind_next_attack": true, "exhaust": true}`. The round lantern-bearing monk's
## cloud of moths Blinds the whole enemy line and then Exhausts itself out of this battle.
##
## Blind is the shared one-shot "this enemy's NEXT attack misses" marker, never a skipped turn, a
## duration or a stack. On the authoritative enemy record it is the canonical integer token
## `blind_next_attack: 1` (0 is inert), the same shape `CombatStatuses`, `CombatStatusTurnBatch` and
## `CombatEnemyPhase` already validate and consume. A currently armed 1 stays 1; casting the card
## itself never spends the token, and neither an owner-turn tick nor a nonattack action consumes it.
## Only the existing `CombatEnemyPhase` attack beat spends it, and that loop is not modified here.
##
## Enemy slots never compact on death. Every LIVING slot 1-3 receives the token; a slain slot keeps its
## record, position, HP, Block and statuses untouched. No target slot is selected for an area card:
## the caller may omit it or pass 0, and any nonzero selection is refused.
##
## Energy is charged through the shared CombatDeck's real spend, and exactly one authenticated held
## copy moves from `hand` to this battle's `exhausted` pile (never to `discard_pile`); no exhaust
## method is added to CombatDeck and no seeded RNG value is drawn.
##
## The catalog stays authoritative: the caller supplies only the held card ID and no cost, seat,
## token or effect. The whole exact base/'+' printing pair is authenticated from LanternMonkPoolCards
## before anything is charged, and every party hero, enemy slot and affected status map is validated
## before the first mutation. Every refusal is a pure no-op.
##
## This is callable rules-layer behaviour only. No live hand, reward, app, run-deck or view path is
## registered here; that wiring is a later, separately owned task.

const OWNER := "lantern_monk"
const TARGET_KIND := "enemy_all"
const BLIND_STATUS_KEY := "blind_next_attack"
const BLIND_TOKEN := 1
## `enemy_all` selects no slot at all; the printed TO list is the whole living roster.
const NO_TARGET_SLOT := 0
const TO_POSITIONS: Array[int] = [1, 2, 3]
const FROM_POSITIONS: Array[int] = [2, 3]
## Every authentic printing is the same area Blind-and-Exhaust effect; only the cost differs.
const EFFECTS := {"blind_next_attack": true, "exhaust": true}

## One-shot integer tokens: absent or 0 is inert, 1 is armed. Nothing else is a legal shape.
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]
## The N-turn counters the shared combat status rules accept (non-negative ints).
const COUNTER_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]

## The two authentic printings and the exact catalog line each must still carry. Everything except
## the cost and the base/'+' link is identical between them.
const CARDS := {
	"lantern_monk_moth_cloud": {
		"display_name": "Moth Cloud",
		"cost": 2,
		"upgrade_id": "lantern_monk_moth_cloud_plus",
	},
	"lantern_monk_moth_cloud_plus": {
		"display_name": "Moth Cloud+",
		"cost": 1,
		"upgrade_of": "lantern_monk_moth_cloud",
	},
}

var _catalog := LanternMonkPoolCards.new()


## The single paid transaction: authenticate the exact printing pair, preflight the whole request,
## then charge, Exhaust exactly one held copy and arm one Blind token on every living enemy slot.
## A refusal changes no deck, party, enemy, status or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = NO_TARGET_SLOT) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the owner sits in its authored seat, every hero and enemy record
	# is well formed and at least one living enemy exists. Keep the defensive returns so an
	# unexpected model change still fails closed rather than paying for a partial effect.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	var id: String = plan["card_id"]
	var hand_index: int = deck.hand.find(id)
	if hand_index < 0:
		return _refusal("card_not_held")
	# Exhaust, never discard: the copy leaves this battle's circulation for the run deck to reclaim.
	deck.exhausted.append(deck.hand[hand_index])
	deck.hand.remove_at(hand_index)

	var receipts: Array[Dictionary] = []
	for position: int in plan["targets"]:
		# The real authoritative record, never a detached get_enemy copy.
		var record: Dictionary = enemies._enemies[position - 1]
		if not record.has("statuses"):
			record["statuses"] = {}
		var statuses: Dictionary = record["statuses"]
		var blind_before: int = int(statuses.get(BLIND_STATUS_KEY, 0))
		# Set/keep the one-shot token at exactly 1; never a second stack and never spent by this cast.
		statuses[BLIND_STATUS_KEY] = BLIND_TOKEN
		receipts.append({
			"position": position,
			"id": str(record["id"]),
			"blind_before": blind_before,
			"blind_after": BLIND_TOKEN,
			"already_blinded": blind_before == BLIND_TOKEN,
		})

	return {
		"ok": true,
		"reason": "applied",
		"card_id": id,
		"cost": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"target_kind": TARGET_KIND,
		"target_position": NO_TARGET_SLOT,
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"exhausted_card_id": id,
		"blinded_positions": plan["targets"].duplicate(),
		"enemies": receipts,
	}


## True only for the two authentic catalog printings. Pure lookup; nothing is charged or mutated
## and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return _authentic_pair(id, CARDS[id])


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
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
	if not _authentic_pair(id, card):
		return _refusal("catalog_mismatch")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")
	# An area card selects nothing; both the omitted default and an explicit 0 are accepted.
	if target_position != NO_TARGET_SLOT:
		return _refusal("invalid_target")

	# Verify the complete party roster and every hero's authoritative status shape, then bind the
	# owner by hero ID to its actual current slot. Swapping seats grants no false authority.
	var heroes: Array[Dictionary] = party.get_heroes()
	if heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	var owner_position := 0
	var seen_ids: Array[String] = []
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
		if not _valid_status_shape(hero.get("statuses", {})):
			return _refusal("malformed_statuses")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1

	# The shared turn-batch validator must also accept every authoritative hero record and map.
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes).get("ok", false):
		return _refusal("invalid_party")
	if owner_position == 0:
		return _refusal("owner_missing")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# The full enemy roster must still be the vocabulary the shared status rules accept (unknown
	# keys, wrong Variant types, negative counters and a non-0/1 Blind or Dodge token all fail).
	var roster: Array[Dictionary] = enemies.get_enemies()
	if roster.is_empty() or roster.size() > CombatEnemies.MAX_ENEMIES:
		return _refusal("invalid_enemies")
	if not CombatStatusTurnBatch.new().tick_side("enemies", roster).get("ok", false):
		return _refusal("malformed_statuses")

	# `enemy_all` arms every enemy that is alive now, in roster order, with no slot chosen. Validate
	# each affected slot and its status map completely before the first mutation.
	var targets: Array[int] = []
	for index in range(roster.size()):
		var position: int = index + 1
		var enemy: Dictionary = roster[index]
		if enemy.get("position") != position:
			return _refusal("invalid_enemies")
		var hp = enemy.get("hp")
		var block = enemy.get("block")
		if not hp is int or not block is int or block < 0:
			return _refusal("invalid_enemies")
		if not _valid_status_shape(enemy.get("statuses", {})):
			return _refusal("malformed_statuses")
		if int(hp) > 0:
			targets.append(position)
	if targets.is_empty():
		return _refusal("no_living_enemies")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"targets": targets,
		"energy_before": deck.energy,
	}


## The status shape the shared combat rules accept: named N-turn counters with non-negative int
## counts and the two one-shot tokens as integer 0/1. Anything else fails closed before mutation.
func _valid_status_shape(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	var values: Dictionary = statuses
	for name in values:
		if not name is String or (name as String).is_empty():
			return false
		var count = values[name]
		if not count is int:
			return false
		if name in ONE_SHOT_STATUS_KEYS:
			if int(count) != 0 and int(count) != 1:
				return false
			continue
		if not COUNTER_STATUS_KEYS.has(name) or int(count) < 0:
			return false
	return true


## Reads the exact authored records from LanternMonkPoolCards and proves BOTH printings of the pair
## still carry their whole authored line, so a rewritten catalog (extra effect, another seat, target,
## cost, rarity, starter copies, art path or a broken upgrade link) can never be paid for as this
## effect. Both printings are authenticated for either requested ID before payment.
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


## The one catalog read of this service, so a test double can prove that a rewritten catalog record
## is refused rather than paid for. Production always reads the real Lantern Monk pool.
func _catalog_definition(card_id: String) -> Dictionary:
	return _catalog.get_definition(card_id)


## The exact contract for one printing: identity, printed name, Monk owner, printed cost, the
## `enemy_all` target with the authored FROM/TO slots, the complete effect dictionary with exact
## Variant types, zero starting copies, rare rarity, base-only reward eligibility, the base art path
## and the base/'+' link. Any missing, extra, retyped or altered field refuses.
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
	if not _same_value(definition.get("effects"), EFFECTS):
		return false
	if definition.get("rarity") != "rare":
		return false
	var starting_copies: Variant = definition.get("starting_copies")
	if not starting_copies is int or starting_copies != 0:
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or bool(reward_eligible) != (not card.has("upgrade_of")):
		return false
	if definition.get("illustration_path") != "res://assets/paper/cards/lantern_monk_moth_cloud.png":
		return false
	# The base and "+" records must still point at each other, so a copied or relinked record
	# cannot be paid for under the other printing's ID.
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


## Typed equality rejects coercible metadata (e.g. a String "1" or an int 1 standing in for the
## boolean Blind descriptor, or a bool standing in for an int cost) as well as changed effects.
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
