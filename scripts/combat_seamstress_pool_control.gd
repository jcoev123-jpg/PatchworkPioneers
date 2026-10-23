class_name CombatSeamstressPoolControl
extends RefCounted
## D2-1: standalone, data-driven resolver for six Seamstress enemy-control
## pool cards. Live battle-hand dispatch is intentionally a later task.

const NEEDLE_IDS := ["seamstress_needle_pin", "seamstress_needle_pin_plus"]
const SNAG_IDS := ["seamstress_snag", "seamstress_snag_plus"]
const UNPICK_IDS := ["seamstress_unpick", "seamstress_unpick_plus"]

## Optional battle-scoped reference, shared with CombatAttackCards. A present
## but invalid binding rejects every cast instead of silently going vanilla.
var _patches: CombatPatchAttackRules = null


func bind_patch_rules(patches: CombatPatchAttackRules) -> void:
	_patches = patches


## Read-only projection for the live forecast. Never consumes the shared latch.
func needle_patch_preview() -> Dictionary:
	if _patches != null and not _patches.is_valid():
		return {"ok": false}
	return {"ok": true,
		"damage_bonus": 0 if _patches == null else _patches.damage_bonus("seamstress"),
		"statuses": {} if _patches == null else _patches.exposed_for_first_hit("seamstress")}


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, unravel: CombatUnravel, card_id: String,
		target_position: int) -> Dictionary:
	# Validate every authority, including all status records, before spending
	# energy or moving the single played card to the discard pile.
	if deck == null or party == null or enemies == null \
			or (_patches != null and not _patches.is_valid()):
		return {"ok": false}
	if not party.is_valid() or not enemies.is_valid():
		return {"ok": false}
	if card_id not in NEEDLE_IDS and card_id not in SNAG_IDS and card_id not in UNPICK_IDS:
		return {"ok": false}
	var definition: Dictionary = SeamstressPoolCards.new().get_definition(card_id)
	if definition.is_empty() or definition.get("owner") != "seamstress" \
			or definition.get("target_kind") != "enemy_single":
		return {"ok": false}
	var cost: int = definition["cost"]
	if not deck.turn_active or not deck.hand.has(card_id) or deck.energy < cost:
		return {"ok": false}
	if not CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())["ok"] \
			or not CombatStatusTurnBatch.new().tick_side("enemies", enemies.get_enemies())["ok"]:
		return {"ok": false}

	var actor: Dictionary = {}
	var seamstress_count := 0
	for hero: Dictionary in party.get_heroes():
		if hero["id"] == "seamstress":
			seamstress_count += 1
			actor = hero
	if seamstress_count != 1 or actor["hp"] <= 0 \
			or actor["position"] not in definition["from_positions"]:
		return {"ok": false}
	if target_position not in definition["to_positions"] \
			or enemies.get_enemy(target_position).is_empty() \
			or enemies.is_slain(target_position):
		return {"ok": false}

	var effects: Dictionary = definition["effects"]
	var is_needle: bool = card_id in NEEDLE_IDS
	var is_snag: bool = card_id in SNAG_IDS
	var unravel_charge: int = 0
	# A correctly roster-bound gauge must be preflighted even for Snag:
	# otherwise a failed charge could leave a Weak-only partial play.
	if is_needle:
		if pinned == null:
			return {"ok": false}
	else:
		if unravel == null or not unravel._validate_roster_and_position(enemies, target_position):
			return {"ok": false}
		var gauge: Dictionary = unravel.get_snapshot(target_position)
		if not gauge.get("gauge") is int or not gauge.get("threshold") is int \
				or gauge["gauge"] < 0 or gauge["threshold"] <= 0 \
				or gauge["gauge"] > gauge["threshold"] \
				or not gauge.get("unravelled") is bool \
				or not gauge.get("skip_pending") is bool:
			return {"ok": false}
		if not effects.get("unravel") is int or effects["unravel"] <= 0:
			return {"ok": false}
		unravel_charge = int(effects["unravel"])
		if _patches != null:
			unravel_charge += _patches.card_unravel_bonus("seamstress", card_id)
		if gauge["gauge"] > CombatStatuses.MAX_INT - unravel_charge:
			return {"ok": false}
		if is_snag and not enemies.can_apply_statuses(
				{target_position: {"weak": int(effects["weak"])}}):
			return {"ok": false}

	var pin_bonus := 0
	var patch_damage := 0
	var patch_statuses: Dictionary = {}
	if is_needle:
		var projection := needle_patch_preview()
		if not projection.ok:
			return {"ok": false}
		patch_damage = projection.damage_bonus
		patch_statuses = projection.statuses
		# Confirm first-hit Exposed capacity before any damage, spend or pin.
		if not enemies.can_apply_statuses({target_position: patch_statuses}):
			return {"ok": false}
		pin_bonus = pinned.bonus_for_attack(enemies, target_position, "seamstress")
		if int(effects["damage"]) > CombatStatuses.MAX_INT - patch_damage - pin_bonus:
			return {"ok": false}

	# Both operations are guaranteed by the preflight, and neither draws cards
	# nor touches the caller's run RNG.
	deck.try_spend_energy(cost)
	deck.discard_played(card_id)

	var result: Dictionary = {
		"ok": true, "card_id": card_id, "target_position": target_position,
		"damage": 0, "block_absorbed": 0, "hp_loss": 0,
		"pinned_bonus": 0, "pinner": "", "weak_applied": 0,
		"unravel_applied": 0, "unravel_snapshot": {}
	}
	if is_needle:
		var attack: Dictionary = CombatStatusAttacks.new().resolve_vs_enemy(
			enemies, target_position, int(effects["damage"]) + patch_damage + pin_bonus,
			actor.get("statuses", {}), enemies.get_enemy(target_position).get("statuses", {}))
		result["damage"] = attack["damage"]
		result["block_absorbed"] = attack["block_absorbed"]
		result["hp_loss"] = attack["hp_loss"]
		result["pinned_bonus"] = pin_bonus
		if pin_bonus > 0:
			pinned.consume_after_attack(target_position, "seamstress", true)
		if not enemies.is_slain(target_position):
			pinned.pin_enemy(enemies, target_position, "seamstress")
		result["pinner"] = pinned.pinner_for_enemy(target_position)
		# Post-hit: the new Exposed cannot amplify this attack itself.
		if not patch_statuses.is_empty():
			enemies.apply_statuses({target_position: patch_statuses})
		if _patches != null:
			_patches.record_successful_attack("seamstress")
	else:
		var added: int = unravel_charge
		unravel.apply_unravel(enemies, target_position, added)
		result["unravel_applied"] = added
		if is_snag:
			enemies.apply_statuses({target_position: {"weak": int(effects["weak"])}})
			result["weak_applied"] = int(effects["weak"])
		result["unravel_snapshot"] = unravel.get_snapshot(target_position)
	return result
