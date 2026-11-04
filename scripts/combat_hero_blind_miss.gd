class_name CombatHeroBlindMiss
extends RefCounted
## Paid, deterministic one-shot miss for a real held ordinary attack.
## The mounted caller authenticates its panel, battle, target and preview before
## entering this scene-free transaction. No combat hit resolver is invoked.

const KEY := "blind_next_attack"
## The only two printings whose targets are chosen while the card resolves.
## Blind skips the whole attempted card, so no recipient is ever sampled.
const RICOCHET_IDS: Array[String] = ["tinker_ricochet", "tinker_ricochet_plus"]

## A missing token is not handled. Malformed owner statuses fail closed.
## Nonattack cards never read or consume Blind.
func attempt(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target: int, definition: Dictionary, discount: int = 0) -> Dictionary:
	var failure := {"handled": true, "ok": false, "reason": "invalid_blind_attack"}
	# Random-target Ricochet is admitted only as its exact authored printing.
	var ricochet := is_authentic_ricochet(card_id, definition)
	if not ricochet and not is_ordinary_attack(definition, card_id):
		return {"handled": false, "ok": false}
	if deck == null or party == null or enemies == null or deck.combat_state == null \
			or deck._rng == null or not deck.turn_active or not party.is_valid() \
			or not enemies.is_valid() or not deck.hand.has(card_id):
		return failure
	var owner: String = definition["owner"]
	var owner_position := 0
	for hero in party.get_heroes():
		if hero.get("id") == owner:
			if owner_position != 0:
				return failure
			owner_position = int(hero.get("position", 0))
	if owner_position < 1 or owner_position > CombatParty.PARTY_SIZE:
		return failure
	var hero: Dictionary = party.get_hero(owner_position)
	if hero.get("hp", 0) <= 0 or not definition["from_positions"].has(owner_position):
		return failure
	var statuses: Variant = hero.get("statuses", {})
	if not statuses is Dictionary or not CombatStatuses.new()._valid_statuses(statuses):
		return failure
	var blind: int = statuses.get(KEY, 0)
	if blind == 0:
		return {"handled": false, "ok": false}
	if blind != 1:
		return failure
	var kind: String = definition["target_kind"]
	if kind == "enemy_single":
		if target < 1 or target > enemies.get_enemies().size() \
				or not definition["to_positions"].has(target) or enemies.is_slain(target):
			return failure
	elif kind == "enemy_all":
		if target != 0:
			return failure
		if not has_living_target(enemies, definition["to_positions"]):
			return failure
	elif kind == "enemy_random" and ricochet:
		# Ricochet selects a new living foe per hit only while resolving, so the
		# caller may never preselect one and a missed card samples no target.
		if target != 0:
			return failure
		if not has_living_target(enemies, definition["to_positions"]):
			return failure
	else:
		return failure
	var printed: int = definition["cost"]
	if discount < 0 or discount > printed:
		return failure
	var cost: int = printed - discount
	if deck.energy < cost:
		return failure
	# No writes precede complete preflight; these two operations cannot reject
	# under the checked, synchronous turn and held-card preconditions.
	if not deck.try_spend_energy(cost):
		return failure
	if not deck.discard_played(card_id):
		return failure
	party._heroes[owner_position - 1]["statuses"].erase(KEY)
	return {"handled": true, "ok": true, "miss": true, "card_id": card_id,
		"owner_position": owner_position, "target_position": target,
		"cost": cost, "hits": [], "damage": 0, "hp_loss": 0,
		"block_absorbed": 0, "reason": "blind_miss"}


## Enemy-targeted support/control cards do not qualify just because they
## select an enemy. Require a positive printed damage effect as well.
static func is_ordinary_attack(definition: Dictionary, card_id: String) -> bool:
	if card_id.is_empty() or definition.get("id") != card_id \
			or not definition.get("owner") is String \
			or not definition.get("cost") is int or definition["cost"] < 0 \
			or not definition.get("from_positions") is Array \
			or not definition.get("to_positions") is Array \
			or definition.get("target_kind") not in ["enemy_single", "enemy_all"]:
		return false
	var effects: Variant = definition.get("effects")
	return effects is Dictionary and effects.get("damage") is int and effects["damage"] > 0


## Only the two catalog Ricochet printings may miss as a random-target card, and
## only when the caller's descriptor is the full unchanged authored definition:
## a forged or edited copy is never a Ricochet. The authored pool is read here,
## so no caller can admit another card, target kind or effect shape.
static func is_authentic_ricochet(card_id: String, definition: Dictionary) -> bool:
	if not RICOCHET_IDS.has(card_id) or definition.is_empty():
		return false
	var authored := TinkerPoolCards.new().get_definition(card_id)
	if authored.is_empty() or definition != authored:
		return false
	var effects: Variant = authored.get("effects")
	if not effects is Dictionary or not effects.get("damage") is int or effects["damage"] <= 0 \
			or effects.get("hit_count") != 3 or effects.get("random_target_each_hit") != true \
			or effects.get("rng_source") != "run" or effects.get("living_targets_only") != true:
		return false
	return authored.get("owner") == "tinker" and authored.get("cost") == 1 \
		and authored.get("target_kind") == "enemy_random"


## Ricochet and area cards need at least one living foe in the authored TO slots.
static func has_living_target(enemies: CombatEnemies, to_positions: Array) -> bool:
	if enemies == null:
		return false
	for enemy in enemies.get_enemies():
		if enemy.get("hp", 0) > 0 and to_positions.has(enemy.get("position")):
			return true
	return false


## Stitched attacks need ordered-half miss semantics. For now a blinded hero
## attempting one of those halves rejects the whole composite before payment.
static func blocks_stitched(party: CombatParty, first: Dictionary, second: Dictionary) -> bool:
	if party == null or not party.is_valid():
		return true
	for half in [first, second]:
		var effects: Variant = half.get("effects")
		if not effects is Dictionary or not effects.get("damage") is int \
				or effects["damage"] <= 0:
			continue
		if half.get("target_kind") not in ["enemy_single", "enemy_all", "enemy_random"]:
			continue
		for hero in party.get_heroes():
			if hero.get("id") == half.get("owner"):
				var statuses: Variant = hero.get("statuses", {})
				if not statuses is Dictionary or not CombatStatuses.new()._valid_statuses(statuses):
					return true
				if statuses.get(KEY, 0) == 1:
					return true
	return false
