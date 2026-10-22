class_name CombatWardenPoolComboAttacks
extends RefCounted
## Resolves Warden's Pinning Jab / Seam Breaker and their upgrades.
## The caller supplies shared battle-scoped Pinned and bound Unravel services.

const WARDEN_ID := "warden"
const SUPPORTED_CARD_IDS: Array[String] = [
	"warden_pinning_jab", "warden_pinning_jab_plus",
	"warden_seam_breaker", "warden_seam_breaker_plus",
]


func is_supported_card(card_id: String) -> bool:
	return SUPPORTED_CARD_IDS.has(card_id)


func get_supported_card_ids() -> Array[String]:
	return SUPPORTED_CARD_IDS.duplicate()


## Read-only admission: no energy, card, HP, Block, gauge, pin or RNG mutation.
func can_play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, unravel: CombatUnravel, card_id: String,
		target_position: int) -> bool:
	if deck == null or party == null or enemies == null or pinned == null or unravel == null:
		return false
	if not deck.turn_active or not party.is_valid() or not enemies.is_valid():
		return false
	if party.is_defeated() or enemies.is_victorious() or not is_supported_card(card_id):
		return false
	var definition: Dictionary = WardenPoolCards.new().get_definition(card_id)
	if definition.is_empty() or definition.get("owner") != WARDEN_ID \
			or definition.get("target_kind") != "enemy_single":
		return false
	var cost: int = definition.get("cost", -1)
	var effects: Dictionary = definition.get("effects", {})
	var base_damage: int = effects.get("damage", -1)
	if cost < 0 or cost > CombatState.TURN_ENERGY or base_damage <= 0:
		return false
	if card_id.begins_with("warden_pinning_jab"):
		if effects.get("pinned") != true:
			return false
	elif not effects.get("unravel") is int or effects["unravel"] <= 0:
		return false
	if not deck.hand.has(card_id) or deck.energy < cost:
		return false

	var warden: Dictionary = {}
	var count: int = 0
	for hero: Dictionary in party.get_heroes():
		if hero.get("id") == WARDEN_ID:
			count += 1
			warden = hero
	if count != 1:
		return false
	var from_position: int = warden.get("position", 0)
	if party.is_downed(from_position) or not definition.get("from_positions", []).has(from_position):
		return false
	if not _valid_actor_statuses(warden):
		return false
	if not definition.get("to_positions", []).has(target_position):
		return false
	var target: Dictionary = enemies.get_enemy(target_position)
	if target.is_empty() or enemies.is_slain(target_position) or not _valid_actor_statuses(target):
		return false
	# The snapshot alone could belong to another roster: verify the identity
	# and living slot using CombatUnravel's own nonmutating guard.
	if not unravel._validate_roster_and_position(enemies, target_position):
		return false
	if not _valid_gauge(unravel.get_snapshot(target_position)):
		return false
	return true


## One paid hit, then pin consumption and the surviving target's new effect.
## Existing Pinned +5 is calculated BEFORE Weak/Exposed final-floor arithmetic.
func play_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, unravel: CombatUnravel, card_id: String,
		target_position: int) -> Dictionary:
	if not can_play(deck, party, enemies, pinned, unravel, card_id, target_position):
		return _failure(card_id, target_position)
	var definition: Dictionary = WardenPoolCards.new().get_definition(card_id)
	var effects: Dictionary = definition["effects"]
	var cost: int = definition["cost"]
	var attacker: Dictionary = {}
	for hero: Dictionary in party.get_heroes():
		if hero.get("id") == WARDEN_ID:
			attacker = hero
			break
	var defender: Dictionary = enemies.get_enemy(target_position)
	var bonus: int = pinned.bonus_for_attack(enemies, target_position, WARDEN_ID)
	var base_damage: int = effects["damage"] + bonus
	var attacker_statuses: Dictionary = attacker.get("statuses", {})
	var defender_statuses: Dictionary = defender.get("statuses", {})

	# All expected failure conditions were checked before spending.
	if not deck.try_spend_energy(cost):
		return _failure(card_id, target_position)
	if not deck.discard_played(card_id):
		return _failure(card_id, target_position)
	var result: Dictionary = CombatStatusAttacks.new().resolve_vs_enemy(
		enemies, target_position, base_damage, attacker_statuses, defender_statuses)
	if not result.get("ok", false):
		return _failure(card_id, target_position)

	# Cross-owner pins are consumed even when the confirmed hit is lethal.
	var consumed: bool = pinned.consume_after_attack(target_position, WARDEN_ID, true)
	var surviving: bool = not enemies.is_slain(target_position)
	var applied_pin: bool = false
	var charged: int = 0
	if surviving:
		if effects.has("pinned"):
			applied_pin = pinned.pin_enemy(enemies, target_position, WARDEN_ID)
		else:
			charged = effects["unravel"]
			unravel.apply_unravel(enemies, target_position, charged)
	return {
		"ok": true,
		"card_id": card_id,
		"target_position": target_position,
		"hits": [{
			"position": target_position,
			"damage": result["damage"],
			"block_absorbed": result["block_absorbed"],
			"hp_loss": result["hp_loss"],
			"pin_bonus": bonus,
			"pin_consumed": consumed,
			"pin_applied": applied_pin,
			"unravel_added": charged,
			"unravel_snapshot": unravel.get_snapshot(target_position),
		}],
	}


func play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned, unravel: CombatUnravel, card_id: String,
		target_position: int) -> Dictionary:
	return play_attack(deck, party, enemies, pinned, unravel, card_id, target_position)


func _valid_actor_statuses(actor: Dictionary) -> bool:
	var statuses: Variant = actor.get("statuses", {})
	if not statuses is Dictionary:
		return false
	for key: Variant in statuses:
		if not key is String or key not in ["bleed", "weak", "exposed"]:
			return false
		if not statuses[key] is int or statuses[key] < 0:
			return false
	return true


func _valid_gauge(gauge: Dictionary) -> bool:
	if not gauge.has_all(["gauge", "threshold", "unravelled", "skip_pending"]):
		return false
	if not gauge["gauge"] is int or not gauge["threshold"] is int:
		return false
	if not gauge["unravelled"] is bool or not gauge["skip_pending"] is bool:
		return false
	return gauge["gauge"] >= 0 and gauge["threshold"] > 0 \
		and gauge["gauge"] <= gauge["threshold"] \
		and gauge["unravelled"] == gauge["skip_pending"]


func _failure(card_id: String, target_position: int) -> Dictionary:
	return {"ok": false, "card_id": card_id, "target_position": target_position, "hits": []}
