class_name CombatTinkerPathRules
extends RefCounted
## D2-5 Tinker-only detached projections. The combat caller validates target,
## hand, position/HP, actual damage and energy spend before reporting success.
## available_energy is the PRE-SPEND balance; this class never charges it.

var _path_id: String = ""
var _path_card_id: String = ""
var _turn_active: bool = false
var _first_attack := CombatTinkerFirstAttack.new()
var _clockwork_used: bool = false
var _scope_armed: bool = false
var _pending_energy: int = 0
var _ready_energy: int = 0


func _init(selected_path_id: String = "") -> void:
	var choice := RunTinkerPathChoice.new()
	var path: Dictionary = choice.get_definition(selected_path_id)
	if not path.is_empty():
		_path_id = selected_path_id
		_path_card_id = str(path["card"]["id"])


func is_valid_path() -> bool:
	return not _path_id.is_empty()


## Turn start is idempotent until end_player_turn is called. Wind-up credits
## become claimable now but are not applied to a caller's energy by this class.
func start_player_turn() -> bool:
	if not is_valid_path() or _turn_active:
		return false
	_turn_active = true
	_first_attack.start_player_turn()
	_clockwork_used = false
	_scope_armed = false
	_ready_energy += _pending_energy
	_pending_energy = 0
	return true


func end_player_turn() -> bool:
	if not _turn_active:
		return false
	_turn_active = false
	_scope_armed = false
	return true


## A claim is one-shot, independent of preview, and never applies energy itself.
func take_next_turn_energy_bonus() -> int:
	if not _turn_active or not is_valid_path():
		return 0
	var bonus: int = _ready_energy
	_ready_energy = 0
	return bonus


## The authored Clockwork reduction for this card at this position, evaluated
## WITHOUT the caller's energy balance. The live hand asks this before any
## printed-cost affordability check, then threads the same number into the real
## resolver, so a discounted card stays castable at the energy the player has.
func discount_for(card_id: String, tinker_position: int, tinker_hp: int) -> int:
	if not is_valid_path() or not _turn_active or tinker_hp <= 0 			or tinker_position < 1 or tinker_position > 3:
		return 0
	var definition: Dictionary = _resolve_card(card_id)
	if definition.is_empty() or definition.get("owner") != "tinker":
		return 0
	return _discount_for_definition(definition, tinker_position)


func _discount_for_definition(definition: Dictionary, tinker_position: int) -> int:
	var positions: Variant = definition.get("from_positions")
	var printed: Variant = definition.get("cost")
	if not (positions is Array) or not positions.has(tinker_position) 			or not (printed is int) or printed < 0:
		return 0
	if _path_id == "clockwork" and not _clockwork_used and printed >= 2:
		return 1
	return 0


func preview(card_id: String, tinker_position: int, tinker_hp: int,
		available_energy: int) -> Dictionary:
	if not is_valid_path() or not _turn_active or tinker_hp <= 0 			or tinker_position < 1 or tinker_position > 3 or available_energy < 0:
		return {"ok": false}
	var definition: Dictionary = _resolve_card(card_id)
	if definition.is_empty() or definition.get("owner") != "tinker":
		return {"ok": false}
	var positions: Variant = definition.get("from_positions")
	var printed: Variant = definition.get("cost")
	if not (positions is Array) or not positions.has(tinker_position) 			or not (printed is int) or printed < 0:
		return {"ok": false}
	var discount: int = _discount_for_definition(definition, tinker_position)
	var cost: int = maxi(0, printed - discount)
	if available_energy < cost:
		return {"ok": false}
	var attack: bool = _is_attack(definition)
	# The native +3 and the armed Scope +4 are separate latches: the first hit of
	# the turn can already be spent while a later Scope still owes its own bonus.
	var sharpshot_bonus: int = 0
	var scope_bonus: int = 0
	if _path_id == "sharpshot" and attack:
		sharpshot_bonus = _first_attack.first_hit_bonus()
		scope_bonus = _first_attack.path_bonus()
	var arms_scope: bool = card_id == _path_card_id and _path_id == "sharpshot"
	var scope_amount: int = 0
	if arms_scope:
		var effects: Variant = definition.get("effects")
		if effects is Dictionary:
			scope_amount = int((effects as Dictionary).get("next_attack_damage_bonus", 0))
	return {
		"ok": true, "card_id": card_id, "printed_cost": printed, "cost": cost,
		"discount": discount, "is_attack": attack, "sharpshot_bonus": sharpshot_bonus,
		"scope_bonus": scope_bonus, "damage_bonus": sharpshot_bonus + scope_bonus,
		"arms_scope": arms_scope, "scope_amount": scope_amount,
		"next_turn_energy": 1 if card_id == _path_card_id and _path_id == "clockwork" else 0
	}


## Commit only AFTER the caller has actually succeeded in playing this card.
## Revalidates the authored position/cost/energy; false or illegal commits are inert.
func commit_successful(card_id: String, tinker_position: int, tinker_hp: int,
		available_energy: int, play_succeeded: bool = false) -> Dictionary:
	if not play_succeeded:
		return {"ok": false}
	var result: Dictionary = preview(card_id, tinker_position, tinker_hp, available_energy)
	if not result.get("ok", false):
		return result
	if _path_id == "clockwork" and result["discount"] == 1:
		_clockwork_used = true
	if result["is_attack"]:
		if _path_id == "sharpshot":
			_first_attack.record_successful_attack(card_id)
			_scope_armed = false
	if result["arms_scope"]:
		# Scope arms the NEXT qualifying Tinker attack, even after this turn's
		# native first hit was already spent.
		_first_attack.arm_path_bonus(int(result.get("scope_amount", 0)))
		_scope_armed = _first_attack.path_bonus() > 0
	if result["next_turn_energy"] > 0:
		_pending_energy += int(result["next_turn_energy"])
	return result


func _resolve_card(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	if card_id == _path_card_id:
		return RunTinkerPathChoice.new().get_card_definition(card_id)
	var definition: Dictionary = StarterCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = TinkerPoolCards.new().get_definition(card_id)
	return definition


func _is_attack(definition: Dictionary) -> bool:
	if definition.get("owner") != "tinker":
		return false
	if not ["enemy_single", "enemy_all", "enemy_random"].has(
			definition.get("target_kind", "")):
		return false
	var effects: Variant = definition.get("effects")
	if not (effects is Dictionary):
		return false
	var damage: Variant = effects.get("damage")
	return (damage is int) and damage >= 0
