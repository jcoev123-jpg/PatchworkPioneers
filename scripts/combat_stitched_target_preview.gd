class_name CombatStitchedTargetPreview
extends RefCounted
## Read-only, scene-free choices for each half of a genuinely held Rest stitch.
## These are CURRENT choices, not a promise that half two remains legal after
## half one's effects. The later atomic resolver must revalidate both halves.

const POOL_HEAL_IDS = [
	"seamstress_darning", "seamstress_darning_plus",
	"seamstress_thimble_tea", "seamstress_thimble_tea_plus",
	"seamstress_field_mend", "seamstress_field_mend_plus",
]

var _catalog := StarterCards.new()
var _pool := SeamstressPoolCards.new()


func get_preview(ledger: Variant, ledger_snapshot: Variant, deck: Variant,
		party: Variant, enemies: Variant, stitched_id: Variant) -> Dictionary:
	var rejected := _rejected()
	if not ledger is RunRestStitchCards or not deck is CombatDeck \
			or not party is CombatParty or not enemies is CombatEnemies:
		return rejected
	if typeof(ledger_snapshot) != TYPE_DICTIONARY or typeof(stitched_id) != TYPE_STRING:
		return rejected
	var rest: RunRestStitchCards = ledger
	var hand: CombatDeck = deck
	var heroes: CombatParty = party
	var foes: CombatEnemies = enemies
	var id: String = stitched_id
	if id.is_empty() or not id.begins_with(RunRestStitchCards.ID_PREFIX):
		return rejected
	if not rest.is_valid() or not hand.turn_active or hand.combat_state == null or hand._rng == null:
		return rejected
	if not heroes.is_valid() or not foes.is_valid() or foes.is_defeated():
		return rejected
	if not hand.hand.has(id):
		return rejected

	# The supplied optimistic ledger receipt must be exact, including registry,
	# deck, scraps and allocator. Rebuild an independent validator so even a
	# mutated in-memory descriptor/receipt cannot be passed off as authored.
	var current: Dictionary = rest.get_snapshot()
	if ledger_snapshot != current:
		return rejected
	var registry: Variant = current.get("descriptors")
	if typeof(registry) != TYPE_DICTIONARY or not registry.has(id):
		return rejected
	var descriptor: Variant = registry[id]
	if typeof(descriptor) != TYPE_DICTIONARY or descriptor.get("id") != id:
		return rejected
	var verified := RunRestStitchCards.new(current.get("deck"), registry,
			current.get("remaining_scraps"), current.get("next_stitch_id"))
	if not verified.is_valid() or verified.get_snapshot() != current:
		return rejected
	var cost: Variant = descriptor.get("cost")
	if typeof(cost) != TYPE_INT or cost < 0 or cost > CombatState.TURN_ENERGY or hand.energy < cost:
		return rejected

	# CombatParty/CombatEnemies constructors validate their initial roster, but
	# state may have been changed since; never trust is_valid() alone.
	var party_slots: Array[Dictionary] = heroes.get_heroes()
	var enemy_slots: Array[Dictionary] = foes.get_enemies()
	if not _valid_party(party_slots) or not _valid_enemies(enemy_slots):
		return rejected
	var owner_gate: Dictionary = rest.preview_play(id, party_slots)
	if not owner_gate.get("ok", false) or owner_gate.get("cost") != cost:
		return rejected
	var first: Variant = owner_gate.get("first_half")
	var second: Variant = owner_gate.get("second_half")
	if typeof(first) != TYPE_DICTIONARY or typeof(second) != TYPE_DICTIONARY:
		return rejected
	if first != descriptor.get("first_half") or second != descriptor.get("second_half"):
		return rejected

	var first_choice := _half_preview(first, 0, party_slots, enemy_slots)
	if first_choice.is_empty():
		return rejected
	var second_choice := _half_preview(second, 1, party_slots, enemy_slots)
	if second_choice.is_empty():
		return rejected
	return {
		"playable": true,
		"stitched_id": id,
		"cost": cost,
		"first_half": first_choice,
		"second_half": second_choice,
		"halves": [first_choice.duplicate(true), second_choice.duplicate(true)],
	}


func _rejected() -> Dictionary:
	return {
		"playable": false, "stitched_id": "", "cost": 0,
		"first_half": {}, "second_half": {}, "halves": [],
	}


func _valid_party(slots: Array[Dictionary]) -> bool:
	if slots.size() != CombatParty.PARTY_SIZE:
		return false
	var ids: Array[String] = []
	for index in range(slots.size()):
		var hero: Dictionary = slots[index]
		var id: Variant = hero.get("id")
		var position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		if typeof(id) != TYPE_STRING or not id in ["warden", "seamstress", "tinker"] or ids.has(id):
			return false
		if typeof(position) != TYPE_INT or position != index + 1:
			return false
		if typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT or max_hp <= 0 or hp < 0 or hp > max_hp:
			return false
		ids.append(id)
	return ids.size() == CombatParty.PARTY_SIZE


func _valid_enemies(slots: Array[Dictionary]) -> bool:
	if slots.is_empty() or slots.size() > CombatEnemies.MAX_ENEMIES:
		return false
	var ids: Array[String] = []
	for index in range(slots.size()):
		var enemy: Dictionary = slots[index]
		var id: Variant = enemy.get("id")
		var position: Variant = enemy.get("position")
		var hp: Variant = enemy.get("hp")
		var max_hp: Variant = enemy.get("max_hp")
		if typeof(id) != TYPE_STRING or id.is_empty() or ids.has(id):
			return false
		if typeof(position) != TYPE_INT or position != index + 1:
			return false
		if typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT or max_hp <= 0 or hp < 0 or hp > max_hp:
			return false
		ids.append(id)
	return true


func _half_preview(half: Dictionary, index: int, party_slots: Array[Dictionary],
		enemy_slots: Array[Dictionary]) -> Dictionary:
	var id: Variant = half.get("id")
	var owner: Variant = half.get("owner")
	if typeof(id) != TYPE_STRING or typeof(owner) != TYPE_STRING:
		return {}
	# The Rest validator already checked the full descriptor; read target
	# shape from the real authored card, never from a caller-supplied half.
	var authored := _catalog.get_definition(id)
	if authored.is_empty() and id in POOL_HEAL_IDS:
		authored = _pool.get_definition(id)
	if authored.is_empty() or authored != half:
		return {}
	var kind: String = authored["target_kind"]
	var allowed: Array = authored["to_positions"]
	var owner_position := 0
	for hero in party_slots:
		if hero["id"] == owner:
			owner_position = hero["position"]
	if owner_position == 0:
		return {}

	var choices: Array[int] = []
	var affected: Array[int] = []
	var side := "none"
	var select := false
	match kind:
		"enemy_single", "enemy_all":
			side = "enemy"
			select = kind == "enemy_single"
			for enemy in enemy_slots:
				var position: int = enemy["position"]
				if enemy["hp"] > 0 and allowed.has(position):
					if select:
						choices.append(position)
					else:
						affected.append(position)
			# Both attack kinds need at least one living eligible enemy.
			if choices.is_empty() and affected.is_empty():
				return {}
		"ally_single":
			side = "ally"
			select = true
			for hero in party_slots:
				if hero["hp"] > 0 and (allowed.is_empty() or allowed.has(hero["position"])):
					choices.append(hero["position"])
			if choices.is_empty():
				return {}
		"party_all":
			side = "ally"
			for hero in party_slots:
				if hero["hp"] > 0:
					affected.append(hero["position"])
			if affected.is_empty():
				return {}
		"self":
			side = "ally"
			affected.append(owner_position)
		"none":
			pass
		_:
			return {}
	return {
		"index": index, "order": "first" if index == 0 else "second",
		"card_id": id, "owner": owner, "target_kind": kind,
		"side": side, "requires_selection": select,
		"target_positions": choices, "affected_positions": affected,
	}
