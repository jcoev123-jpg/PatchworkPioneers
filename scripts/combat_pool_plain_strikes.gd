class_name CombatPoolPlainStrikes
extends RefCounted
## Scene-free resolver for Brass Buckle and Thread Whip (base and +).
## Catalogs supply the rules; the shared deck and rosters own every mutation.

const SUPPORTED_IDS := [
	"warden_brass_buckle", "warden_brass_buckle_plus",
	"seamstress_thread_whip", "seamstress_thread_whip_plus",
]

var _attacks := CombatStatusAttacks.new()
var _pinned: CombatPinned = null


func _init(pinned: CombatPinned = null) -> void:
	_pinned = pinned


func set_pinned(pinned: CombatPinned) -> void:
	_pinned = pinned


func get_pinned() -> CombatPinned:
	return _pinned


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, pinned: CombatPinned = null) -> Dictionary:
	var active_pinned: CombatPinned = pinned if pinned != null else _pinned
	if deck == null or party == null or enemies == null or not SUPPORTED_IDS.has(card_id):
		return _failure()
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _failure()
	if not party.is_valid() or not enemies.is_valid() or not deck.hand.has(card_id):
		return _failure()

	var warden_card: bool = card_id.begins_with("warden_")
	var definition: Dictionary = (WardenPoolCards.new().get_definition(card_id)
		if warden_card else SeamstressPoolCards.new().get_definition(card_id))
	var owner_id := "warden" if warden_card else "seamstress"
	if definition.get("id") != card_id or definition.get("owner") != owner_id:
		return _failure()
	var cost: Variant = definition.get("cost")
	var from_positions: Variant = definition.get("from_positions")
	var to_positions: Variant = definition.get("to_positions")
	var effects: Variant = definition.get("effects")
	if not cost is int or cost < 0 or cost > CombatState.TURN_ENERGY or cost > deck.energy:
		return _failure()
	if not from_positions is Array or not to_positions is Array:
		return _failure()
	if definition.get("target_kind") != "enemy_single" or not to_positions.has(target_position):
		return _failure()
	if not effects is Dictionary or effects.size() != (2 if warden_card else 1):
		return _failure()
	var damage: Variant = effects.get("damage")
	var block_amount: Variant = effects.get("block", 0)
	if not damage is int or damage <= 0 or not block_amount is int:
		return _failure()
	if damage > CombatStatuses.MAX_INT - 5:
		return _failure()
	if warden_card and block_amount <= 0:
		return _failure()
	if not warden_card and (effects.has("block") or block_amount != 0):
		return _failure()

	# Validate authoritative full rosters (including status shapes) before
	# any debit or hit. Keep their original slots after other actors fall.
	var heroes: Array[Dictionary] = party.get_heroes()
	var foes: Array[Dictionary] = enemies.get_enemies()
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes)["ok"] \
			or not CombatStatusTurnBatch.new().tick_side("enemies", foes)["ok"]:
		return _failure()
	var owner: Dictionary = {}
	for hero in heroes:
		if hero["id"] == owner_id:
			owner = hero
			break
	if owner.is_empty() or owner["hp"] == 0 or not from_positions.has(owner["position"]):
		return _failure()
	var owner_position: int = owner["position"]
	if target_position < 1 or target_position > foes.size():
		return _failure()
	var target: Dictionary = foes[target_position - 1]
	if target["hp"] == 0 or target["position"] != target_position:
		return _failure()
	if owner["block"] > CombatParty.MAX_INT or target["block"] > CombatEnemies.MAX_INT:
		return _failure()
	# Brass Buckle's gain must fit BEFORE damage, energy or card movement.
	if warden_card and block_amount > CombatParty.MAX_INT - owner["block"]:
		return _failure()

	# Every mutator is now guaranteed to accept its operation.
	# No shuffle, extra draw, or RNG read occurs on this path.
	if not deck.try_spend_energy(cost):
		return _failure()
	deck.discard_played(card_id)
	var pin_bonus: int = 0
	if active_pinned != null:
		pin_bonus = active_pinned.bonus_for_attack(enemies, target_position, owner_id)
	var hit: Dictionary = _attacks.resolve_vs_enemy(enemies, target_position, damage + pin_bonus,
		owner.get("statuses", {}), target.get("statuses", {}))
	if active_pinned != null and hit.get("ok", false):
		active_pinned.consume_after_attack(target_position, owner_id, true)
	var block_deltas: Dictionary = {}
	if warden_card:
		party.gain_block(owner_position, block_amount)
		block_deltas[owner_position] = block_amount
	return {"ok": true, "hits": [{
		"position": target_position, "damage": hit["damage"],
		"block_absorbed": hit["block_absorbed"], "hp_loss": hit["hp_loss"],
		"statuses": {},
	}], "block_deltas": block_deltas}


func _failure() -> Dictionary:
	return {"ok": false, "hits": [], "block_deltas": {}}
