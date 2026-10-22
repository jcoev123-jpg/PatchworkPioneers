class_name CombatAttackTargeting
extends RefCounted
## Read-only legal-enemy preview for the five authored starter attacks plus the
## four plain reward-pool strikes. The eventual play resolver must independently
## validate its committed target.

const ATTACK_IDS := [
	"warden_strike_plus",
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

var _warden_pool := WardenPoolCards.new()
var _seamstress_pool := SeamstressPoolCards.new()


## Reward-pool plain strikes deliberately stay OUT of ATTACK_IDS: mounted
## regressions iterate that starter list and must keep covering starters only.
## The pool resolver's own table remains the single authority for the IDs.
func is_pool_strike(card_id: String) -> bool:
	return CombatPoolPlainStrikes.SUPPORTED_IDS.has(card_id)


## Heavy pool attacks have their own resolver, never the starter or plain-strike list.
func is_heavy_pool_attack(card_id: String) -> bool:
	return CombatWardenPoolHeavyAttacks.SUPPORTED_CARD_IDS.has(card_id)


## True for every attack this read-only preview can describe.
func supports(card_id: String) -> bool:
	return ATTACK_IDS.has(card_id) or is_pool_strike(card_id) or is_heavy_pool_attack(card_id)


## Exact authored pool record: catalog ID and owner must agree with the prefix.
func pool_definition(card_id: String) -> Dictionary:
	if not is_pool_strike(card_id):
		return {}
	var warden := card_id.begins_with("warden_")
	var owner_id := "warden" if warden else "seamstress"
	var definition: Dictionary = (_warden_pool.get_definition(card_id) if warden
		else _seamstress_pool.get_definition(card_id))
	if definition.get("id") != card_id or definition.get("owner") != owner_id:
		return {}
	return definition


## Authored Warden heavy attacks: one damage packet or exactly two hits.
func heavy_definition(card_id: String) -> Dictionary:
	if not is_heavy_pool_attack(card_id):
		return {}
	var definition: Dictionary = _warden_pool.get_definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "warden":
		return {}
	return definition


func _valid_heavy_effects(card_id: String, definition: Dictionary) -> bool:
	var effects: Variant = definition.get("effects")
	if not effects is Dictionary:
		return false
	var damage: Variant = effects.get("damage")
	if not damage is int or damage <= 0:
		return false
	if card_id in [CombatWardenPoolHeavyAttacks.PIN_AND_POUND_ID,
			CombatWardenPoolHeavyAttacks.PIN_AND_POUND_PLUS_ID]:
		return effects.size() == 2 and effects.get("hits") is int and effects["hits"] == 2
	return effects.size() == 1


## Pool records carry one damage effect and, for Brass Buckle only, its own
## Block gain. Mirror the resolver contract so a malformed record never previews
## as playable. Block is never a second target-damage packet.
func _valid_pool_effects(card_id: String, definition: Dictionary) -> bool:
	var effects: Variant = definition.get("effects")
	if not effects is Dictionary:
		return false
	var damage: Variant = effects.get("damage")
	var block: Variant = effects.get("block", 0)
	if not damage is int or damage <= 0 or not block is int or block < 0:
		return false
	var warden := card_id.begins_with("warden_")
	if warden != (block > 0):
		return false
	return effects.size() == (2 if warden else 1)


func get_preview(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String) -> Dictionary:
	var target_positions: Array[int] = []
	var rejected := {
		"playable": false,
		"requires_selection": false,
		"target_positions": target_positions
	}
	if deck == null or party == null or enemies == null:
		return rejected
	if not deck.turn_active or not party.is_valid() or not enemies.is_valid():
		return rejected
	if not supports(card_id) or not deck.hand.has(card_id):
		return rejected

	# Consult the authored catalog for all card rules, not a parallel rules table.
	var pool := is_pool_strike(card_id)
	var heavy := is_heavy_pool_attack(card_id)
	var definition: Dictionary = (pool_definition(card_id) if pool else
		heavy_definition(card_id) if heavy else StarterCards.new().get_definition(card_id))
	if definition.is_empty():
		return rejected
	var owner = definition.get("owner")
	var cost = definition.get("cost")
	var from_positions = definition.get("from_positions")
	var to_positions = definition.get("to_positions")
	var target_kind = definition.get("target_kind")
	if not owner is String or owner.is_empty():
		return rejected
	if not cost is int or cost < 0 or deck.energy < cost:
		return rejected
	if not from_positions is Array or from_positions.is_empty():
		return rejected
	if not to_positions is Array or to_positions.is_empty():
		return rejected
	if target_kind != "enemy_single" and target_kind != "enemy_all":
		return rejected
	if pool and not _valid_pool_effects(card_id, definition):
		return rejected
	if heavy and not _valid_heavy_effects(card_id, definition):
		return rejected
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return rejected
	for position in to_positions:
		if not position is int or position < 1 or position > CombatEnemies.MAX_ENEMIES:
			return rejected

	# Positions come from the actual (possibly reordered) roster; missing or
	# ambiguous owners fail closed. Downed heroes remain in their slots.
	var owner_position := 0
	var owner_count := 0
	for hero in party.get_heroes():
		if hero.get("id") == owner:
			owner_count += 1
			owner_position = hero.get("position", 0)
	if owner_count != 1 or owner_position == 0:
		return rejected
	if party.is_downed(owner_position) or not from_positions.has(owner_position):
		return rejected

	# Scan slots in position order, never compacting slain or absent enemies.
	# For enemy_all these are affected slots, not selectable target choices.
	for position in range(1, CombatEnemies.MAX_ENEMIES + 1):
		if not to_positions.has(position):
			continue
		if enemies.get_enemy(position).is_empty() or enemies.is_slain(position):
			continue
		target_positions.append(position)
	if target_positions.is_empty():
		return rejected
	return {
		"playable": true,
		"requires_selection": target_kind == "enemy_single",
		"target_positions": target_positions
	}
