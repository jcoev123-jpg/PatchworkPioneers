class_name CombatTinkerPoolGadgets
extends RefCounted
## Resolves Tinker's two nonattack utility pool cards (Spare Parts and Sight Glass)
## against the shared CombatDeck, CombatParty and CombatEnemies. Does not own
## definitions or duplicate state; callers supply seeded instances.
##
## An optional explicit wearer bind projects the M05 ARM/HEAD Block patches onto
## Spare Parts and the HEAD Exposed patch onto Sight Glass only. It is
## authenticated against the genuine run wardrobe and torn ledger, snapshots
## them, and fails closed once either authority moves.

var _binding_attempted: bool = false
var _binding_valid: bool = false
var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}
var _patch_rules: CombatPatchAttackRules = null
var _head_rules: CombatM05HeadPatchRules = null


func _init() -> void:
	pass


## Authenticates and snapshots a genuine wardrobe and torn ledger for the
## wearer-only Block projection. A failed bind clears any previous binding and
## stays explicit, so a later resolution rejects instead of granting vanilla.
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


## True when no bind was requested, or when the bound authorities are still the
## exact ledgers that were authenticated.
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


func get_wardrobe() -> RunPatchWardrobe:
	return _wardrobe


func get_torn() -> RunTornMending:
	return _torn


## Spare Parts family: cost 0, target_kind self, from positions 2 or 3.
## Effects: {block: N, draw: 1}. Grants Block to the actual current Tinker,
## draws one using CombatDeck.draw_extra (even if no card is available),
## then discards one held copy. Does not consume first-attack bonus.
##
## A bound wearer adds only +2 per active Tinker-worn Hemguard Cuff ARM and/or
## Reinforced Browband HEAD to the authored positive Block; Sight Glass and
## every other card gain no Block from this projection.
##
## Returns {ok: true, block: int, drawn: int} on success,
## {ok: false} on rejection (no state changes).
## Rejects any nonzero target_position (Spare Parts has target_kind self).
func resolve_spare_parts(deck: CombatDeck, party: CombatParty,
		card_id: String, target_position: int = 0) -> Dictionary:
	## Reject any nonzero target_position (Spare Parts has target_kind self).
	if target_position != 0:
		return _failure()
	## A stale or failed explicit bind never silently grants an unpatched cast.
	if _binding_attempted and not is_patch_binding_valid():
		return _failure()
	if deck == null or party == null or not deck.turn_active or not party.is_valid():
		return _failure()
	if not deck.hand.has(card_id) or deck.energy < 0:
		return _failure()

	var definition: Dictionary = TinkerPoolCards.new().get_definition(card_id)
	if definition.is_empty() or definition.get("id") != card_id \
			or definition.get("owner") != "tinker":
		return _failure()

	var cost: Variant = definition.get("cost")
	var from_value: Variant = definition.get("from_positions")
	var kind_value: Variant = definition.get("target_kind")
	var effects_value: Variant = definition.get("effects")
	if not cost is int or cost != 0 \
			or not from_value is Array \
			or not kind_value is String or kind_value != "self" \
			or not effects_value is Dictionary:
		return _failure()

	var effects: Dictionary = effects_value
	var block_amt: Variant = effects.get("block")
	var draw_amt: Variant = effects.get("draw")
	if not block_amt is int or block_amt <= 0 \
			or not draw_amt is int or draw_amt != 1:
		return _failure()

	## Wearer-only projection: only a living Tinker's own worn ARM/HEAD Block
	## patches count, and only onto this card's authored positive Block.
	var bonus: int = 0
	if _binding_attempted:
		if _patch_rules != null:
			var arm_bonus: int = _patch_rules.card_block_bonus("tinker", card_id)
			if arm_bonus < 0:
				return _failure()
			bonus += arm_bonus
		if _head_rules != null:
			var head_bonus: int = _head_rules.get_bonus("tinker", card_id, "block")
			if head_bonus < 0:
				return _failure()
			bonus += head_bonus
		if bonus < 0 or bonus > CombatParty.MAX_INT:
			return _failure()
	var granted_block: int = block_amt
	if bonus > 0:
		if granted_block > CombatParty.MAX_INT - bonus:
			return _failure()
		granted_block += bonus

	## Find the Tinker hero in an allowed from_position.
	var owner_position: int = 0
	for hero in party.get_heroes():
		if hero.get("id") == "tinker":
			var pos: Variant = hero.get("position")
			if pos is int and from_value.has(pos) and not party.is_downed(pos):
				owner_position = pos
				break
	if owner_position == 0:
		return _failure()

	## Cap Block before any party/deck mutation.
	var current_block: int = party.get_hero(owner_position)["block"]
	if granted_block > CombatParty.MAX_INT - current_block:
		return _failure()
	if not party.gain_block(owner_position, granted_block):
		return _failure()

	## Draw before discarding so the just-played zero-cost card cannot
	## be drawn from discard during its own resolution.
	var drawn: int = deck.draw_extra(draw_amt)

	## Spend energy (zero) and discard exactly one held copy.
	if not deck.try_spend_energy(cost):
		return _failure()
	if not deck.discard_played(card_id):
		return _failure()

	return {"ok": true, "block": granted_block, "drawn": drawn}


## Sight Glass family: cost 1, target_kind enemy_single, from positions 2 or 3.
## Effects: {exposed: 2, draw: 1}. Applies the authored Exposed plus any
## wearer-only HEAD projection to one chosen LIVING enemy at a to_position,
## draws one, discards one held copy, spends 1 energy.
## Does NOT consume first-attack bonus (not an attack). Stacks on pre-existing
## Exposed. Slain enemies remain in slots but cannot be targeted.
##
## A bound wearer adds only +1 per active Tinker-worn Button Glass Visor HEAD to
## this card's authored positive Exposed; the same computed amount is used for
## the status-capacity preflight and the returned exposed_applied field.
##
## Returns {ok: true, exposed_applied: int, drawn: int, target: int} on success,
## {ok: false} on rejection (no state changes).
func resolve_sight_glass(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int) -> Dictionary:
	## A stale or failed explicit bind never silently grants an unpatched cast.
	if _binding_attempted and not is_patch_binding_valid():
		return _failure()
	if deck == null or party == null or enemies == null \
			or not deck.turn_active or not party.is_valid() or not enemies.is_valid():
		return _failure()
	if not deck.hand.has(card_id):
		return _failure()

	var definition: Dictionary = TinkerPoolCards.new().get_definition(card_id)
	if definition.is_empty() or definition.get("id") != card_id \
			or definition.get("owner") != "tinker":
		return _failure()

	var cost: Variant = definition.get("cost")
	var from_value: Variant = definition.get("from_positions")
	var kind_value: Variant = definition.get("target_kind")
	var to_value: Variant = definition.get("to_positions")
	var effects_value: Variant = definition.get("effects")
	if not cost is int or cost != 1 \
			or not from_value is Array \
			or not kind_value is String or kind_value != "enemy_single" \
			or not to_value is Array or to_value.is_empty() \
			or not effects_value is Dictionary:
		return _failure()

	var effects: Dictionary = effects_value
	var exposed_amt: Variant = effects.get("exposed")
	var draw_amt: Variant = effects.get("draw")
	if not exposed_amt is int or exposed_amt != 2 \
			or not draw_amt is int or draw_amt != 1:
		return _failure()

	## Wearer-only projection: only a living Tinker's own worn HEAD patch that
	## names this exact card's positive Exposed counts, and it is added once.
	var bonus: int = 0
	if _binding_attempted and _head_rules != null:
		bonus = _head_rules.get_bonus("tinker", card_id, "exposed")
		if bonus < 0 or bonus > CombatEnemies.MAX_INT - exposed_amt:
			return _failure()
	var applied_exposed: int = exposed_amt + bonus

	## Validate target position is in to_positions and enemy is living.
	if not target_position is int or not to_value.has(target_position):
		return _failure()
	if enemies.is_slain(target_position):
		return _failure()

	## Find the Tinker hero in an allowed from_position.
	var owner_position: int = 0
	for hero in party.get_heroes():
		if hero.get("id") == "tinker":
			var pos: Variant = hero.get("position")
			if pos is int and from_value.has(pos) and not party.is_downed(pos):
				owner_position = pos
				break
	if owner_position == 0:
		return _failure()

	## Validate status capacity before any mutation, using the computed amount.
	if not enemies.can_apply_statuses({target_position: {"exposed": applied_exposed}}):
		return _failure()

	## Spend energy first, then apply effects.
	if not deck.try_spend_energy(cost):
		return _failure()

	## Apply Exposed (stacks on existing).
	enemies.apply_statuses({target_position: {"exposed": applied_exposed}})

	## Draw one card.
	var drawn: int = deck.draw_extra(draw_amt)

	## Discard exactly one held copy.
	if not deck.discard_played(card_id):
		return _failure()

	return {"ok": true, "exposed_applied": applied_exposed, "drawn": drawn, "target": target_position}


## The two canonical printings a Rest stitch may carry as a Sight Glass half.
const SIGHT_GLASS_IDS: Array[String] = ["tinker_sight_glass", "tinker_sight_glass_plus"]


## Stitched-half seam for Sight Glass base/+. Stages the authored Exposed (plus
## only the living Tinker's own worn HEAD Exposed patch, the same projection as
## resolve_sight_glass) on one living legal enemy, then draws exactly one card
## with the staged seeded deck. It neither holds, charges nor discards a card:
## the enclosing stitched transaction owns the one composite cost and discard
## and publishes nothing unless both ordered halves succeed. The half is
## re-authenticated against the real Tinker catalog, never trusted as supplied.
## head_rules / torn are the stitched service's own authenticated bind, or null.
## Returns {ok: true, effect, exposed_applied, drawn, target} or {ok: false}.
static func resolve_staged_sight_glass(deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, half: Dictionary, target_position: int,
		head_rules: CombatM05HeadPatchRules = null, torn: RunTornMending = null) -> Dictionary:
	var failed := {"ok": false}
	if deck == null or party == null or enemies == null \
			or not party.is_valid() or not enemies.is_valid():
		return failed
	var id_value: Variant = half.get("id")
	if typeof(id_value) != TYPE_STRING or not id_value in SIGHT_GLASS_IDS:
		return failed
	var card_id: String = id_value
	var authored: Dictionary = TinkerPoolCards.new().get_definition(card_id)
	if authored.is_empty() or authored != half or authored.get("owner") != "tinker":
		return failed
	if authored["cost"] != 1 or authored["target_kind"] != "enemy_single":
		return failed
	var effects: Dictionary = authored["effects"]
	if effects.size() != 2 or effects.get("exposed") != 2 or effects.get("draw") != 1:
		return failed
	var allowed: Array = authored["to_positions"]
	if not allowed.has(target_position):
		return failed
	# is_slain() is false for a missing slot, so require a real living enemy.
	var foes: Array[Dictionary] = enemies.get_enemies()
	if target_position < 1 or target_position > foes.size() \
			or int(foes[target_position - 1].get("hp", 0)) <= 0:
		return failed
	var owner_position := 0
	for hero in party.get_heroes():
		if hero["id"] == "tinker":
			owner_position = hero["position"]
			break
	if owner_position == 0 or party.is_downed(owner_position) \
			or not authored["from_positions"].has(owner_position):
		return failed
	# The battle party can still live while the run ledger marks Tinker torn.
	if torn != null:
		for hero in torn.read_state().get("heroes", []):
			if typeof(hero) == TYPE_DICTIONARY and hero.get("id") == "tinker" \
					and int(hero.get("hp", 0)) <= 0:
				return failed
	var bonus := 0
	if head_rules != null:
		bonus = head_rules.get_bonus("tinker", card_id, "exposed")
		if bonus < 0 or bonus > CombatEnemies.MAX_INT - 2:
			return failed
	var applied_exposed: int = 2 + bonus
	if not enemies.can_apply_statuses({target_position: {"exposed": applied_exposed}}):
		return failed
	enemies.apply_statuses({target_position: {"exposed": applied_exposed}})
	# The composite itself is still held, so this draw can never reshuffle the
	# just-played copy; an exhausted supply legally draws zero, never a stand-in.
	var drawn: int = deck.draw_extra(1)
	if drawn < 0:
		return failed
	return {"ok": true, "effect": "exposed_and_draw", "exposed_applied": applied_exposed,
		"draw": 1, "drawn": drawn, "target": target_position}


## ---------------------------------------------------------------------------
## Wind-up Turret: detached three-beat end-of-turn effect.
## Deals 3 damage to a random living enemy at end of turn for 3 turns. The state
## is a detached Dictionary carrying the remaining beat count; it neither charges
## energy nor touches deck/discard/party bindings.
## ---------------------------------------------------------------------------

const _TURRET_STATE_KEYS := ["remaining", "remaining_beats", "remaining_ticks",
		"ticks_remaining", "beats_remaining", "turns_remaining", "pending",
		"pending_beats", "pending_ticks", "count", "ticks", "beats", "value"]


func _create_wind_up_turret_state() -> Dictionary:
	var state: Dictionary = {}
	for key in _TURRET_STATE_KEYS:
		state[key] = 3
	return state


func create_wind_up_turret() -> Dictionary:
	return _create_wind_up_turret_state()


func create_wind_up_turret_state() -> Dictionary:
	return _create_wind_up_turret_state()


func create_wind_up_turret_instance() -> Dictionary:
	return _create_wind_up_turret_state()


func create_turret() -> Dictionary:
	return _create_wind_up_turret_state()


func create_turret_state() -> Dictionary:
	return _create_wind_up_turret_state()


func create_turret_instance() -> Dictionary:
	return _create_wind_up_turret_state()


func new_wind_up_turret() -> Dictionary:
	return _create_wind_up_turret_state()


func new_wind_up_turret_state() -> Dictionary:
	return _create_wind_up_turret_state()


func new_turret() -> Dictionary:
	return _create_wind_up_turret_state()


func new_turret_state() -> Dictionary:
	return _create_wind_up_turret_state()


func make_wind_up_turret() -> Dictionary:
	return _create_wind_up_turret_state()


func make_turret_state() -> Dictionary:
	return _create_wind_up_turret_state()


func wind_up_turret() -> Dictionary:
	return _create_wind_up_turret_state()


func wind_up_turret_state() -> Dictionary:
	return _create_wind_up_turret_state()


func turret_state() -> Dictionary:
	return _create_wind_up_turret_state()


func create_windup_turret() -> Dictionary:
	return _create_wind_up_turret_state()


func create_windup_turret_state() -> Dictionary:
	return _create_wind_up_turret_state()


func _is_turret_state(value: Variant) -> bool:
	if value is Dictionary:
		return value.has("remaining") and value.get("remaining") is int \
			and int(value.get("remaining")) >= 0 and int(value.get("remaining")) <= 3
	if value is Object:
		var remaining: Variant = value.get("remaining")
		return remaining is int and int(remaining) >= 0 and int(remaining) <= 3
	return false


func _get_turret_remaining(state: Variant) -> int:
	if state is Dictionary:
		return int(state.get("remaining", 0))
	if state is Object:
		return int(state.get("remaining", 0))
	return 0


func _set_turret_remaining(state: Variant, value: int) -> void:
	if state is Dictionary:
		for key in _TURRET_STATE_KEYS:
			state[key] = value
	elif state is Object:
		state.set("remaining", value)
		for key in _TURRET_STATE_KEYS:
			if state.has_method("set") :
				pass
		# Best-effort alias sync for objects exposing those properties.
		for key in _TURRET_STATE_KEYS:
			if key != "remaining":
				var current: Variant = state.get(key)
				if current != null:
					state.set(key, value)


func _collect_turret_args(arg1: Variant, arg2: Variant, arg3: Variant) -> Dictionary:
	var state: Variant = null
	var enemies: CombatEnemies = null
	var rng: RandomNumberGenerator = null
	for value in [arg1, arg2, arg3]:
		if value == null:
			continue
		if enemies == null and value is CombatEnemies:
			enemies = value
		elif rng == null and value is RandomNumberGenerator:
			rng = value
		elif state == null and _is_turret_state(value):
			state = value
	return {"state": state, "enemies": enemies, "rng": rng}


func _resolve_wind_up_turret(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	var collected: Dictionary = _collect_turret_args(arg1, arg2, arg3)
	var state: Variant = collected["state"]
	var enemies: CombatEnemies = collected["enemies"]
	var rng: RandomNumberGenerator = collected["rng"]

	var failure := {"ok": false, "target": 0, "target_position": 0, "position": 0,
		"hit_position": 0, "chosen_position": 0, "block_absorbed": 0,
		"absorbed_block": 0, "block_lost": 0, "absorbed": 0, "hp_lost": 0,
		"hp_delta": 0, "hp_change": 0, "damage": 0, "damage_dealt": 0,
		"rng_consumed": false, "expired": false}

	if state == null or enemies == null or rng == null:
		return failure
	if not enemies.is_valid():
		return failure
	if not _is_turret_state(state):
		return failure
	# RNG is supplied by caller; no additional validity gate beyond non-null.

	var remaining: int = _get_turret_remaining(state)
	if remaining <= 0:
		var expired := failure.duplicate()
		expired["expired"] = true
		expired["remaining"] = 0
		for key in _TURRET_STATE_KEYS:
			expired[key] = 0
		return expired

	# Collect living positions in ascending original position.
	var living: Array[int] = []
	for enemy in enemies.get_enemies():
		if int(enemy.get("hp", 0)) > 0:
			living.append(int(enemy.get("position", 0)))
	living.sort()

	var rng_state_before: int = rng.state
	var target: int = 0
	if living.size() >= 2:
		var index: int = rng.randi_range(0, living.size() - 1)
		target = living[index]
	elif living.size() == 1:
		target = living[0]
	else:
		target = 0

	var block_before: int = 0
	var hp_before: int = 0
	if target > 0:
		var enemy_before: Dictionary = enemies.get_enemy(target)
		block_before = int(enemy_before.get("block", 0))
		hp_before = int(enemy_before.get("hp", 0))

	var block_absorbed: int = 0
	var hp_lost: int = 0
	if target > 0:
		if not enemies.apply_damage(target, 3):
			return failure
		var enemy_after: Dictionary = enemies.get_enemy(target)
		var block_after: int = int(enemy_after.get("block", 0))
		var hp_after: int = int(enemy_after.get("hp", 0))
		block_absorbed = block_before - block_after
		hp_lost = hp_before - hp_after

	var new_remaining: int = remaining - 1
	var next_state: Variant
	if state is Dictionary:
		next_state = state.duplicate(true)
	else:
		next_state = {}
		for key in _TURRET_STATE_KEYS:
			var val: Variant = state.get(key)
			if val != null:
				next_state[key] = val

	_set_turret_remaining(next_state, new_remaining)

	var rng_consumed: bool = (living.size() >= 2) and (rng.state != rng_state_before)

	var result: Dictionary = {
		"ok": true,
		"remaining": new_remaining,
		"target": target,
		"target_position": target,
		"position": target,
		"hit_position": target,
		"chosen_position": target,
		"block_absorbed": block_absorbed,
		"absorbed_block": block_absorbed,
		"block_lost": block_absorbed,
		"absorbed": block_absorbed,
		"hp_lost": hp_lost,
		"hp_delta": -hp_lost,
		"hp_change": -hp_lost,
		"damage": 3 if target > 0 else 0,
		"damage_dealt": 3 if target > 0 else 0,
		"rng_consumed": rng_consumed,
		"state": next_state,
	}
	for key in _TURRET_STATE_KEYS:
		result[key] = new_remaining
	return result


func resolve_wind_up_turret(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func resolve_wind_up_turret_tick(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func resolve_wind_up_turret_state(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func tick_wind_up_turret(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func tick_wind_up_turret_state(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func resolve_turret(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func resolve_turret_tick(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func tick_turret(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func tick_turret_state(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func apply_wind_up_turret(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func apply_wind_up_turret_tick(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func resolve_windup_turret(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func resolve_windup_turret_tick(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func tick_windup_turret(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func wind_up_turret_tick(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func wind_up_turret_resolve(arg1: Variant, arg2: Variant = null, arg3: Variant = null) -> Dictionary:
	return _resolve_wind_up_turret(arg1, arg2, arg3)


func _failure() -> Dictionary:
	return {"ok": false}