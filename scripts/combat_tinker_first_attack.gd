class_name CombatTinkerFirstAttack
extends RefCounted
## Isolated helper for Tinker's per-player-turn first successful attack +3 bonus.
## Scene-free and stateless aside from the native first-hit latch and the one-shot
## Path bonus the selected Tinker Path can arm independently of that latch.

const NATIVE_BONUS := 3

var _consumed: bool = false
## One-shot extra damage armed by the selected Tinker Path's Scope card. It rides
## on the NEXT qualifying Tinker attack and is spent with it. It is deliberately
## independent of the native first-hit +3: Scope played after this turn's first
## hit still lands its exact authored bonus, and the forecast always agrees.
var _path_bonus: int = 0


func start_player_turn() -> void:
	_consumed = false
	_path_bonus = 0


## The native +3 still owed to this turn's first confirmed hit; zero once spent.
func first_hit_bonus() -> int:
	return 0 if _consumed else NATIVE_BONUS


func bonus_for_attack(card_id: String) -> int:
	if not _is_eligible_tinker_attack(card_id):
		return 0
	return first_hit_bonus() + _path_bonus


## Arms the authored Path extra on this turn's next qualifying Tinker attack.
## Independent of the native first-hit latch, so Scope may arm after that hit has
## already landed. Never stacks twice before the armed bonus is spent.
func arm_path_bonus(amount: int) -> bool:
	if amount <= 0 or _path_bonus != 0:
		return false
	_path_bonus = amount
	return true


func path_bonus() -> int:
	return _path_bonus


## Spends the native +3 on this turn's first qualifying hit, and any armed Path
## extra on the next one. True when this confirmed hit consumed something.
func record_successful_attack(card_id: String) -> bool:
	if not _is_eligible_tinker_attack(card_id):
		return false
	var consumed := false
	if not _consumed:
		_consumed = true
		consumed = true
	if _path_bonus != 0:
		_path_bonus = 0
		consumed = true
	return consumed


func _is_eligible_tinker_attack(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var definition: Dictionary = StarterCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = TinkerPoolCards.new().get_definition(card_id)
	if definition.is_empty():
		return false
	if definition.get("id") != card_id:
		return false
	if definition.get("owner") != "tinker":
		return false
	var target_kind := str(definition.get("target_kind", ""))
	if target_kind != "enemy_single" and target_kind != "enemy_all" \
			and target_kind != "enemy_random":
		return false
	var effects = definition.get("effects")
	if not (effects is Dictionary):
		return false
	var damage = effects.get("damage")
	if not (damage is int) or int(damage) < 0:
		return false
	return true
