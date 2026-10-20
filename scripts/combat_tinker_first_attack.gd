class_name CombatTinkerFirstAttack
extends RefCounted
## Isolated helper for Tinker's per-player-turn first successful attack +3 bonus.
## Scene-free and stateless aside from one consumed flag; never mutates game state.

var _consumed: bool = false


func start_player_turn() -> void:
	_consumed = false


func bonus_for_attack(card_id: String) -> int:
	if _consumed:
		return 0
	if not _is_eligible_tinker_attack(card_id):
		return 0
	return 3


func record_successful_attack(card_id: String) -> bool:
	if _consumed:
		return false
	if not _is_eligible_tinker_attack(card_id):
		return false
	_consumed = true
	return true


func _is_eligible_tinker_attack(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var catalog := StarterCards.new()
	var definition: Dictionary = catalog.get_definition(card_id)
	if definition.is_empty():
		return false
	if definition.get("id") != card_id:
		return false
	if definition.get("owner") != "tinker":
		return false
	var target_kind := str(definition.get("target_kind", ""))
	if target_kind != "enemy_single" and target_kind != "enemy_all":
		return false
	var effects = definition.get("effects")
	if not (effects is Dictionary):
		return false
	var damage = effects.get("damage")
	if not (damage is int) or int(damage) < 0:
		return false
	return true