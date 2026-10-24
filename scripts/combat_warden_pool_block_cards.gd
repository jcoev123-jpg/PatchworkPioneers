class_name CombatWardenPoolBlockCards
extends RefCounted
## Scene-free resolver for the five pure-Block Warden reward cards and upgrades.
## Catalog metadata is authoritative; callers supply only a held ID and target.

const SUPPORTED_KINDS := {
	"warden_hold_the_line": "self",
	"warden_patch_guard": "ally_single",
	"warden_quick_darn": "self",
	"warden_iron_hem": "self",
	"warden_bastion_quilt": "party_all",
}

var _binding_attempted: bool = false
var _binding_valid: bool = false
var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}
var _patch_rules: CombatPatchAttackRules = null
var _head_rules: CombatM05HeadPatchRules = null


## Authenticates and snapshots a genuine wardrobe and torn ledger for wearer effects.
func bind_patch_wardrobe(wardrobe: Variant, torn: Variant,
		expected_wardrobe: Variant = null, expected_torn: Variant = null) -> bool:
	_binding_attempted = true
	_binding_valid = false
	_wardrobe = null
	_torn = null
	_wardrobe_snapshot = {}
	_torn_snapshot = {}
	_patch_rules = null
	_head_rules = null

	if not (wardrobe is RunPatchWardrobe) or not (torn is RunTornMending):
		return false
	if not wardrobe.is_valid() or not torn.is_valid():
		return false

	var snap: Dictionary = wardrobe.get_snapshot()
	var torn_state: Dictionary = torn.read_state()

	if expected_wardrobe != null:
		if typeof(expected_wardrobe) != TYPE_DICTIONARY or expected_wardrobe != snap:
			return false
	if expected_torn != null:
		if typeof(expected_torn) != TYPE_DICTIONARY or expected_torn != torn_state:
			return false

	var rules := CombatPatchAttackRules.new()
	if not rules.bind_wardrobe(wardrobe, torn):
		return false

	var head_rules := CombatM05HeadPatchRules.new()
	if not head_rules.bind_wardrobe(wardrobe, torn):
		return false

	_wardrobe = wardrobe
	_torn = torn
	_wardrobe_snapshot = snap.duplicate(true)
	_torn_snapshot = torn_state.duplicate(true)
	_patch_rules = rules
	_head_rules = head_rules
	_binding_valid = true
	return true


func is_patch_binding_valid() -> bool:
	if not _binding_attempted:
		return true
	if not _binding_valid or _wardrobe == null or _torn == null:
		return false
	if not _wardrobe.is_valid() or not _torn.is_valid():
		return false
	if _wardrobe.get_snapshot() != _wardrobe_snapshot:
		return false
	if _torn.read_state() != _torn_snapshot:
		return false
	if _patch_rules == null or not _patch_rules.is_valid():
		return false
	if _head_rules == null or not _head_rules.read_projection().get("ok", false):
		return false
	return true


func get_patches() -> CombatPatchAttackRules:
	return _patch_rules


func get_head_patches() -> CombatM05HeadPatchRules:
	return _head_rules


func get_head_rules() -> CombatM05HeadPatchRules:
	return _head_rules


func get_wardrobe() -> RunPatchWardrobe:
	return _wardrobe


func get_torn() -> RunTornMending:
	return _torn


func play_card(deck: CombatDeck, party: CombatParty, card_id: String,
		target_position: int = 0) -> Dictionary:
	var rejected := {"ok": false}
	if _binding_attempted and not is_patch_binding_valid():
		return rejected
	if deck == null or party == null or not party.is_valid():
		return rejected
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return rejected
	if not deck.hand.has(card_id):
		return rejected

	var base_id: String = card_id.trim_suffix("_plus")
	if not SUPPORTED_KINDS.has(base_id) or (card_id != base_id and card_id != base_id + "_plus"):
		return rejected
	var definition: Dictionary = WardenPoolCards.new().get_definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "warden":
		return rejected
	var cost = definition.get("cost")
	var from_positions = definition.get("from_positions")
	var to_positions = definition.get("to_positions")
	var kind = definition.get("target_kind")
	var effects = definition.get("effects")
	if not cost is int or cost < 0 or cost > CombatState.TURN_ENERGY or cost > deck.energy:
		return rejected
	if not from_positions is Array or from_positions.is_empty() or not to_positions is Array:
		return rejected
	if not to_positions.is_empty() or kind != SUPPORTED_KINDS[base_id]:
		return rejected
	for position in from_positions:
		if not position is int or position < 1 or position > CombatParty.PARTY_SIZE:
			return rejected
	if not effects is Dictionary:
		return rejected

	# Fail closed if the catalog ever gains a mixed/status effect: this
	# service must not silently implement just its Block portion.
	var block_amount := 0
	var other_amount := 0
	if base_id == "warden_hold_the_line":
		if effects.size() != 2 or not effects.has("block") or not effects.has("other_ally_block"):
			return rejected
		if not effects["block"] is int or not effects["other_ally_block"] is int:
			return rejected
		block_amount = effects["block"]
		other_amount = effects["other_ally_block"]
	elif base_id == "warden_bastion_quilt":
		if effects.size() != 1 or not effects.has("block_all") or not effects["block_all"] is int:
			return rejected
		block_amount = effects["block_all"]
	else:
		if effects.size() != 1 or not effects.has("block") or not effects["block"] is int:
			return rejected
		block_amount = effects["block"]
	if block_amount <= 0 or (base_id == "warden_hold_the_line" and other_amount <= 0):
		return rejected

	# Verify actual current slots, living status and Block capacity before
	# modifying either authoritative object.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	var seen_ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var id = hero.get("id")
		var position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		var block = hero.get("block")
		if not id is String or id.is_empty() or seen_ids.has(id):
			return rejected
		if not position is int or position != index + 1:
			return rejected
		if not hp is int or not max_hp is int or max_hp <= 0 or hp < 0 or hp > max_hp:
			return rejected
		if not block is int or block < 0 or block > CombatParty.MAX_INT:
			return rejected
		seen_ids.append(id)
		if id == "warden":
			owner_position = index + 1
	if owner_position == 0 or not from_positions.has(owner_position):
		return rejected
	if heroes[owner_position - 1]["hp"] == 0:
		return rejected

	var bonus := 0
	if _binding_attempted:
		if _patch_rules != null:
			var arm_bonus: int = _patch_rules.card_block_bonus("warden", card_id)
			if arm_bonus < 0:
				return rejected
			bonus += arm_bonus
		if _head_rules != null:
			var head_bonus: int = _head_rules.get_bonus("warden", card_id, "block")
			if head_bonus < 0:
				return rejected
			bonus += head_bonus
		if bonus < 0 or bonus > CombatParty.MAX_INT:
			return rejected

	var final_block_amount := block_amount
	if bonus > 0 and effects.has("block"):
		if final_block_amount > CombatParty.MAX_INT - bonus:
			return rejected
		final_block_amount += bonus

	var recipients: Dictionary = {}  # current position -> Block gained
	match kind:
		"self":
			if target_position != 0:
				return rejected
			recipients[owner_position] = final_block_amount
			if base_id == "warden_hold_the_line":
				for hero in heroes:
					if hero["id"] != "warden" and hero["hp"] > 0:
						recipients[hero["position"]] = other_amount
		"ally_single":
			if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
				return rejected
			if heroes[target_position - 1]["hp"] == 0:
				return rejected
			recipients[target_position] = final_block_amount
		"party_all":
			if target_position != 0:
				return rejected
			for hero in heroes:
				if hero["hp"] > 0:
					recipients[hero["position"]] = final_block_amount
		_:
			return rejected

	for position in recipients:
		var amount: int = recipients[position]
		var current_block: int = heroes[position - 1]["block"]
		if amount > CombatParty.MAX_INT - current_block:
			return rejected

	# These operations cannot fail after full preflight: exact hand copy,
	# active turn, affordable cost and every living recipient were checked.
	if not deck.try_spend_energy(cost):
		return rejected
	deck.discard_played(card_id)
	for position in recipients:
		party.gain_block(position, recipients[position])
	return {"ok": true, "block_deltas": recipients.duplicate(true)}
