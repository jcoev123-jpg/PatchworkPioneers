class_name CombatAttackTargeting
extends RefCounted
## Read-only legal-enemy preview for the five authored starter attacks, the
## four plain reward-pool strikes and the six authored Seamstress control
## variants. The eventual play resolver must independently validate its
## committed target.

const SIGHT_GLASS_IDS := ["tinker_sight_glass", "tinker_sight_glass_plus"]

const ATTACK_IDS := [
	"warden_strike_plus", "warden_shield_bash_plus", "seamstress_prick_plus",
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

const TINKER_V3_IDS := ["tinker_v3_cog_shot", "tinker_v3_cog_shot_plus",
	"tinker_v3_scrap_bomb", "tinker_v3_scrap_bomb_plus"]

var _warden_pool := WardenPoolCards.new()
var _seamstress_pool := SeamstressPoolCards.new()
var _tinker_pool := TinkerPoolCards.new()


## Reward-pool plain strikes deliberately stay OUT of ATTACK_IDS: mounted
## regressions iterate that starter list and must keep covering starters only.
## The pool resolver's own table remains the single authority for the IDs.
func is_pool_strike(card_id: String) -> bool:
	return CombatPoolPlainStrikes.SUPPORTED_IDS.has(card_id)


## Heavy pool attacks have their own resolver, never the starter or plain-strike list.
func is_heavy_pool_attack(card_id: String) -> bool:
	return CombatWardenPoolHeavyAttacks.SUPPORTED_CARD_IDS.has(card_id)


## Only the authored single-target Pin/Unravel family enters this picker.
## Shrapnel Seam is an area attack and belongs to a separate integration.
const TINKER_COMBO_IDS: Array[String] = [
	"tinker_spool_launcher", "tinker_spool_launcher_plus",
	"tinker_snip_the_seam", "tinker_snip_the_seam_plus",
]


func is_pool_combo_attack(card_id: String) -> bool:
	return CombatWardenPoolComboAttacks.SUPPORTED_CARD_IDS.has(card_id) \
		or (TINKER_COMBO_IDS.has(card_id) \
		and CombatTinkerPoolUnravelAttacks.SUPPORTED_CARD_IDS.has(card_id))


func combo_definition(card_id: String) -> Dictionary:
	if not is_pool_combo_attack(card_id):
		return {}
	var warden: bool = CombatWardenPoolComboAttacks.SUPPORTED_CARD_IDS.has(card_id)
	var definition: Dictionary = (_warden_pool.get_definition(card_id) if warden \
		else _tinker_pool.get_definition(card_id))
	var owner_id: String = "warden" if warden else "tinker"
	if definition.get("id") != card_id or definition.get("owner") != owner_id \
			or definition.get("target_kind") != "enemy_single":
		return {}
	var cost: Variant = definition.get("cost")
	var from_slots: Variant = definition.get("from_positions")
	var to_slots: Variant = definition.get("to_positions")
	if not cost is int or cost < 0 or cost > CombatState.TURN_ENERGY \
			or not from_slots is Array or from_slots.is_empty() \
			or not to_slots is Array or to_slots.is_empty():
		return {}
	for position in from_slots:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return {}
	for position in to_slots:
		if not position is int or position < 1 or position > CombatEnemies.MAX_ENEMIES:
			return {}
	var effects: Variant = definition.get("effects")
	if not effects is Dictionary or not effects.get("damage") is int or effects["damage"] <= 0:
		return {}
	if card_id.begins_with("warden_pinning_jab"):
		if effects.size() != 2 or effects.get("pinned") != true:
			return {}
	elif card_id.begins_with("tinker_snip_the_seam"):
		var condition: Variant = effects.get("conditional_damage")
		if effects.size() != 2 or not condition is Dictionary \
				or not condition.get("damage") is int or condition["damage"] <= 0 \
				or condition.get("operator") != "or" or not condition.get("conditions") is Array:
			return {}
	else:
		if effects.size() != 2 or not effects.get("unravel") is int \
				or effects["unravel"] <= 0:
			return {}
	return definition


## These two enemy-targeted utilities are not damage attacks, and must not
## enter the starter-only ATTACK_IDS. The live picker shares this preview.
func is_sight_glass(card_id: String) -> bool:
	return card_id in SIGHT_GLASS_IDS


## The six authored Seamstress enemy-control variants (Needle Pin, Snag and
## Unpick, each base and '+') stay out of the starter-only ATTACK_IDS too.
## Their own resolver remains the single authority for effects.
func is_seamstress_control(card_id: String) -> bool:
	return card_id in CombatSeamstressPoolControl.NEEDLE_IDS \
		or card_id in CombatSeamstressPoolControl.SNAG_IDS \
		or card_id in CombatSeamstressPoolControl.UNPICK_IDS


## Exact authored control record: catalog ID, owner, single living enemy target
## and the effect shape its resolver consumes. A malformed record never
## previews as playable, so the picker cannot advertise a cast that would fail.
func control_definition(card_id: String) -> Dictionary:
	if not is_seamstress_control(card_id):
		return {}
	var definition: Dictionary = _seamstress_pool.get_definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "seamstress" \
			or definition.get("target_kind") != "enemy_single":
		return {}
	var cost: Variant = definition.get("cost")
	if not cost is int or cost < 0:
		return {}
	var from_positions: Variant = definition.get("from_positions")
	var to_positions: Variant = definition.get("to_positions")
	if not from_positions is Array or from_positions.is_empty() \
			or not to_positions is Array or to_positions.is_empty():
		return {}
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return {}
	for position in to_positions:
		if not position is int or position < 1 or position > CombatEnemies.MAX_ENEMIES:
			return {}
	if not _valid_control_effects(card_id, definition):
		return {}
	return definition


## Needle Pin is one positive damage packet plus a pin; Snag is one gauge charge
## plus Weak; Unpick is exactly one gauge charge. No extra fields are admitted.
func _valid_control_effects(card_id: String, definition: Dictionary) -> bool:
	var effects: Variant = definition.get("effects")
	if not effects is Dictionary:
		return false
	if card_id in CombatSeamstressPoolControl.NEEDLE_IDS:
		var damage: Variant = effects.get("damage")
		var pinned: Variant = effects.get("pinned")
		return effects.size() == 2 and damage is int and damage > 0 \
			and pinned is bool and pinned == true
	if card_id in CombatSeamstressPoolControl.SNAG_IDS:
		var unravel: Variant = effects.get("unravel")
		var weak: Variant = effects.get("weak")
		return effects.size() == 2 and unravel is int and unravel > 0 \
			and weak is int and weak > 0
	if card_id in CombatSeamstressPoolControl.UNPICK_IDS:
		var charge: Variant = effects.get("unravel")
		return effects.size() == 1 and charge is int and charge > 0
	return false


func sight_glass_definition(card_id: String) -> Dictionary:
	if not is_sight_glass(card_id):
		return {}
	var definition: Dictionary = _tinker_pool.get_definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "tinker":
		return {}
	return definition


## True for enemy-targeted actions this read-only preview can describe.
func supports(card_id: String) -> bool:
	return ATTACK_IDS.has(card_id) or TINKER_V3_IDS.has(card_id) or is_pool_strike(card_id) or is_heavy_pool_attack(card_id) \
		or is_sight_glass(card_id) or is_seamstress_control(card_id) or is_pool_combo_attack(card_id)


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


## The utility has precisely these authored fields; no hit/damage packet.
func _valid_sight_glass(definition: Dictionary) -> bool:
	var effects: Variant = definition.get("effects")
	return definition.get("cost") == 1 and definition.get("target_kind") == "enemy_single" \
		and definition.get("from_positions") == [2, 3] \
		and definition.get("to_positions") == [1, 2, 3] \
		and effects is Dictionary and effects.size() == 2 \
		and effects.get("exposed") == 2 and effects.get("draw") == 1


func get_preview(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: String,
		cost_discount: int = 0) -> Dictionary:
	var target_positions: Array[int] = []
	var rejected := {
		"playable": false,
		"requires_selection": false,
		"target_positions": target_positions
	}
	if deck == null or party == null or enemies == null:
		return rejected
	if TINKER_V3_IDS.has(card_id):
		# Authenticate against the accepted resolver BEFORE roster readers can
		# settle revivals. Each single choice must independently pass preflight.
		var service := CombatTinkerV3StarterAttackCards.new()
		var area: bool = card_id.contains("scrap_bomb")
		for position in ([0] if area else [1, 2, 3]):
			var plan := service.preflight(deck, party, enemies, card_id, position, cost_discount)
			if plan.ok:
				for target in plan.targets:
					target_positions.append(target.position)
		return {"playable": not target_positions.is_empty(),
			"requires_selection": not area and not target_positions.is_empty(),
			"target_positions": target_positions}
	if not deck.turn_active or not party.is_valid() or not enemies.is_valid():
		return rejected
	if not supports(card_id) or not deck.hand.has(card_id):
		return rejected

	# Consult the authored catalog for all card rules, not a parallel rules table.
	var pool := is_pool_strike(card_id)
	var heavy := is_heavy_pool_attack(card_id)
	var sight := is_sight_glass(card_id)
	var control := is_seamstress_control(card_id)
	var combo := is_pool_combo_attack(card_id)
	var definition: Dictionary = (pool_definition(card_id) if pool else
		heavy_definition(card_id) if heavy else
		sight_glass_definition(card_id) if sight else
		control_definition(card_id) if control else
		combo_definition(card_id) if combo else StarterCards.new().get_definition(card_id))
	if definition.is_empty():
		return rejected
	var owner = definition.get("owner")
	var cost = definition.get("cost")
	var from_positions = definition.get("from_positions")
	var to_positions = definition.get("to_positions")
	var target_kind = definition.get("target_kind")
	if not owner is String or owner.is_empty():
		return rejected
	if not cost is int or cost < 0:
		return rejected
	# An authored reduction is only ever the one Clockwork point on a card whose
	# PRINTED cost is at least two. Anything else is a caller bug and fails closed.
	if cost_discount < 0 or cost_discount > 1 \
			or (cost_discount > 0 and cost < 2):
		return rejected
	var effective_cost: int = cost - cost_discount
	if deck.energy < effective_cost:
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
	if sight and not _valid_sight_glass(definition):
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
	var all_bomb: bool = card_id == CombatAreaAttacks.SCRAP_BOMB_ID and target_kind == "enemy_all"
	for position in range(1, enemies.get_enemies().size() + 1):
		if not all_bomb and not to_positions.has(position):
			continue
		if enemies.get_enemy(position).is_empty() or enemies.is_slain(position):
			continue
		if sight and not enemies.can_apply_statuses({position: {"exposed": 2}}):
			continue
		if control and card_id in CombatSeamstressPoolControl.SNAG_IDS \
				and not enemies.can_apply_statuses(
					{position: {"weak": int(definition["effects"]["weak"])}}):
			continue
		target_positions.append(position)
	if target_positions.is_empty():
		return rejected
	return {
		"playable": true,
		"requires_selection": target_kind == "enemy_single",
		"target_positions": target_positions
	}
