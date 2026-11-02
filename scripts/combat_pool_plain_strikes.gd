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
var _patches: CombatPatchAttackRules = null
var _head_patches: CombatM05HeadPatchRules = null
var _mitt: CombatFrayfinderMitt = null
var _binding_attempted := false
var _binding_valid := false
var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}


## An explicit invalid binding disables casting instead of dropping the bonus.
## Both wearer projections must accept the SAME genuine run ledgers: the M04/M05
## ARM powers (Pincushion Arm, Hemguard Cuff) and the M05 HEAD powers.
func bind_patch_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending) -> bool:
	_binding_attempted = true
	_binding_valid = false
	_wardrobe = null
	_torn = null
	_wardrobe_snapshot = {}
	_torn_snapshot = {}
	# A failed attempt still leaves a real, invalid rule set behind so callers
	# can inspect it instead of receiving null.
	_patches = CombatPatchAttackRules.new()
	_head_patches = CombatM05HeadPatchRules.new()
	if wardrobe == null or torn == null or not wardrobe.is_valid() or not torn.is_valid():
		return false
	var arm_rules := CombatPatchAttackRules.new()
	if not arm_rules.bind_wardrobe(wardrobe, torn):
		return false
	var head_rules := CombatM05HeadPatchRules.new()
	if not head_rules.bind_wardrobe(wardrobe, torn):
		return false
	_wardrobe = wardrobe
	_torn = torn
	_wardrobe_snapshot = wardrobe.get_snapshot()
	_torn_snapshot = torn.read_state()
	_patches = arm_rules
	_head_patches = head_rules
	_binding_valid = true
	return true


## An explicit binding is only usable while every stored authority still
## describes the same run ledgers. Rejected or drifted bindings never fall back
## to unpatched play; an unbound resolver keeps its historic printed behaviour.
func is_patch_binding_valid() -> bool:
	if not _binding_attempted:
		return true
	if not _binding_valid or _patches == null or _head_patches == null:
		return false
	if not _patches.is_valid() or not _head_patches.read_projection().get("ok", false):
		return false
	if _wardrobe == null or _torn == null or not _wardrobe.is_valid() or not _torn.is_valid():
		return false
	return _wardrobe.get_snapshot() == _wardrobe_snapshot \
		and _torn.read_state() == _torn_snapshot


func _init(arg1: Variant = null, arg2: Variant = null, arg3: Variant = null) -> void:
	for arg in [arg1, arg2, arg3]:
		if arg is CombatPinned:
			_pinned = arg
		elif arg is CombatPatchAttackRules:
			_patches = arg
		elif arg is CombatFrayfinderMitt:
			_mitt = arg


func set_pinned(pinned: CombatPinned) -> void:
	_pinned = pinned


func get_pinned() -> CombatPinned:
	return _pinned


func set_patches(patches: CombatPatchAttackRules) -> void:
	_patches = patches


func get_patches() -> CombatPatchAttackRules:
	return _patches


func set_mitt(mitt: CombatFrayfinderMitt) -> void:
	_mitt = mitt


func get_mitt() -> CombatFrayfinderMitt:
	return _mitt


func bind_mitt(mitt: CombatFrayfinderMitt) -> void:
	_mitt = mitt


func get_head_patches() -> CombatM05HeadPatchRules:
	return _head_patches


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, pinned: Variant = null,
		patches: Variant = null, mitt: Variant = null, quote: Dictionary = {},
		needle_rules: CombatHeirloomPatchTriggers = null,
		needle_quote: Dictionary = {}) -> Dictionary:
	var result := _play_card(deck, party, enemies, card_id, target_position,
		pinned, patches, mitt, quote, false, 0, needle_rules, needle_quote)
	if needle_rules != null and not needle_quote.is_empty():
		if result.get("ok", false):
			needle_rules.finish_needle_hit(needle_quote, result)
		else:
			needle_rules.cancel_needle_hit()
	return result


## Share only the enclosing transaction's detached wearer latches/projection.
static func stage_for_stitch(attacks: CombatAttackCards) -> CombatPoolPlainStrikes:
	var staged := CombatPoolPlainStrikes.new()
	staged._patches = attacks._patches
	staged._head_patches = attacks._head_rules
	return staged


## Canonical half only; no ordinary play, payment, discard or run RNG access.
func resolve_staged_half(party: CombatParty, enemies: CombatEnemies,
		half: Dictionary, target_position: int, base_bonus: int = 0) -> Dictionary:
	var card_id: String = half.get("id", "")
	if card_id not in SUPPORTED_IDS or base_bonus not in [0, 2]:
		return _failure()
	var authored: Dictionary = (WardenPoolCards.new().get_definition(card_id)
		if card_id.begins_with("warden_") else SeamstressPoolCards.new().get_definition(card_id))
	if half != authored:
		return _failure()
	return _play_card(null, party, enemies, card_id, target_position,
		null, null, null, {}, true, base_bonus)


func _play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, pinned: Variant = null,
		patches: Variant = null, mitt: Variant = null, quote: Dictionary = {},
		staged: bool = false, base_bonus: int = 0,
		needle_rules: CombatHeirloomPatchTriggers = null,
		needle_quote: Dictionary = {}) -> Dictionary:
	var active_pinned: CombatPinned = _pinned
	var active_patches: CombatPatchAttackRules = _patches
	var active_mitt: CombatFrayfinderMitt = _mitt
	var active_quote: Dictionary = quote.duplicate(true)

	for arg in [pinned, patches, mitt]:
		if arg is CombatPinned:
			active_pinned = arg
		elif arg is CombatPatchAttackRules:
			active_patches = arg
		elif arg is CombatFrayfinderMitt:
			active_mitt = arg
		elif arg is Dictionary and active_quote.is_empty():
			active_quote = (arg as Dictionary).duplicate(true)

	if (deck == null and not staged) or party == null or enemies == null or not SUPPORTED_IDS.has(card_id):
		return _failure()
	if not is_patch_binding_valid():
		return _failure()
	if active_patches != null and not active_patches.is_current():
		return _failure()
	if _head_patches != null and not _head_patches.read_projection().get("ok", false):
		return _failure()
	if not staged and (deck.combat_state == null or deck._rng == null or not deck.turn_active or not deck.hand.has(card_id)):
		return _failure()
	if not party.is_valid() or not enemies.is_valid():
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
	if not cost is int or cost < 0 or cost > CombatState.TURN_ENERGY:
		return _failure()
	if not staged and cost > deck.energy:
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
	var patch_damage: int = 0 if active_patches == null else active_patches.damage_bonus(owner_id)
	var patch_first_status: Dictionary = {} if active_patches == null else active_patches.exposed_for_first_hit(owner_id)
	var patch_exposed: int = int(patch_first_status.get("exposed", 0))

	var mitt_bonus := base_bonus
	if active_mitt != null:
		if not active_mitt.is_valid():
			return _failure()
		if active_quote.is_empty():
			active_quote = active_mitt.quote_pool_hit(card_id, target_position)
		if active_quote.get("bonus") == 2:
			var authorized: int = active_mitt.authorize_pool_hit(active_quote, deck, party,
				enemies, card_id, target_position)
			if authorized != 2:
				return _failure()
			mitt_bonus = 2
		elif active_quote.get("bonus") != 0:
			return _failure()
	elif not active_quote.is_empty() and active_quote.get("bonus", 0) != 0:
		return _failure()

	# Only an authenticated paid quote grants Needle; stitched halves never
	# receive the quote or an implicit Heirloom bonus.
	var needle_bonus := 0
	if staged and (needle_rules != null or not needle_quote.is_empty()):
		return _failure()
	if needle_rules != null and not needle_quote.is_empty():
		if not needle_rules.authorizes_needle_hit(needle_quote, party, enemies,
				card_id, target_position):
			return _failure()
		needle_bonus = 1
	elif not needle_quote.is_empty():
		return _failure()
	if damage > CombatStatuses.MAX_INT - 5 - patch_damage - mitt_bonus - needle_bonus:
		return _failure()
	if warden_card and block_amount <= 0:
		return _failure()
	if not warden_card and (effects.has("block") or block_amount != 0):
		return _failure()

	# Each worn M05 Block patch adds +2 to the WARDEN's own Block gain only.
	# The ARM projection is Hemguard Cuff; the HEAD projection is Reinforced
	# Browband. A damage-only card never gains Block from either.
	var block_bonus: int = 0
	if warden_card:
		if active_patches != null:
			var arm_bonus: int = active_patches.card_block_bonus(owner_id, card_id)
			if arm_bonus < 0:
				return _failure()
			block_bonus += arm_bonus
		if _head_patches != null:
			var head_bonus: int = _head_patches.get_bonus(owner_id, card_id, "block")
			if head_bonus < 0:
				return _failure()
			block_bonus += head_bonus
		if block_bonus > CombatParty.MAX_INT - block_amount:
			return _failure()
	var final_block: int = block_amount + block_bonus

	# Validate authoritative full rosters (including status shapes) before
	# any debit or hit. Keep their original slots after other actors fall.
	var heroes: Array[Dictionary] = party.get_heroes()
	var foes: Array[Dictionary] = enemies.get_enemies()
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes)["ok"] \
			or not CombatStatusTurnBatch.new().tick_side("enemies", foes, enemies.get_capacity())["ok"]:
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
	if not _attacks._valid_statuses(owner.get("statuses", {})) \
			or not _attacks._valid_statuses(target.get("statuses", {})):
		return _failure()
	if owner["block"] > CombatParty.MAX_INT or target["block"] > CombatEnemies.MAX_INT:
		return _failure()
	# Brass Buckle's full gain (printed plus worn Block patches) must fit
	# BEFORE damage, energy or card movement.
	if warden_card and final_block > CombatParty.MAX_INT - owner["block"]:
		return _failure()
	if patch_exposed > 0 and not enemies.can_apply_statuses({target_position: {"exposed": patch_exposed}}):
		return _failure()

	# Every mutator is now guaranteed to accept its operation.
	# No shuffle, extra draw, or RNG read occurs on this path.
	if not staged:
		if not deck.try_spend_energy(cost):
			return _failure()
		deck.discard_played(card_id)
	var pin_bonus: int = 0
	if active_pinned != null:
		pin_bonus = active_pinned.bonus_for_attack(enemies, target_position, owner_id)
	var hit: Dictionary = _attacks.resolve_vs_enemy(enemies, target_position,
		damage + pin_bonus + patch_damage + mitt_bonus + needle_bonus,
		owner.get("statuses", {}), target.get("statuses", {}))
	if not hit.get("ok", false):
		return _failure()
	var hit_statuses: Dictionary = {}
	if hit.get("ok", false):
		if active_pinned != null:
			active_pinned.consume_after_attack(target_position, owner_id, true)
		if patch_exposed > 0:
			enemies.apply_statuses({target_position: {"exposed": patch_exposed}})
			hit_statuses["exposed"] = patch_exposed
		if active_patches != null:
			active_patches.record_successful_attack(owner_id)
	var block_deltas: Dictionary = {}
	if warden_card:
		party.gain_block(owner_position, final_block)
		block_deltas[owner_position] = final_block
	var receipt := {"ok": true, "hits": [{
		"position": target_position, "damage": hit["damage"],
		"block_absorbed": hit["block_absorbed"], "hp_loss": hit["hp_loss"],
		"statuses": hit_statuses,
	}], "block_deltas": block_deltas}
	if active_mitt != null and active_quote.has("seal"):
		active_mitt.consume_confirmed_hit(active_quote, receipt)
	return receipt


func _failure() -> Dictionary:
	return {"ok": false, "hits": [], "block_deltas": {}}
