class_name CombatPinned
extends RefCounted
## Per-enemy Pinned token rule: records which hero pinned each enemy; a later
## pin replaces the earlier one. A successful cross-hero attack consumes the
## token once and grants +5 damage before Weak/Exposed. Same-hero attacks,
## failed attempts, and previews never consume. Tokens persist across turns and
## clear only on explicit combat reset.

var _pinner_by_position: Dictionary = {}


func _init() -> void:
	_pinner_by_position = {}


## Attempts to pin the enemy at the given position with the given pinner ID.
## Returns true on success. Only living enemies at valid positions can be pinned.
func pin_enemy(enemies: CombatEnemies, position: int, pinner_id: String) -> bool:
	if enemies == null or not enemies.is_valid():
		return false
	if not _valid_pinner_id(pinner_id):
		return false
	if not enemies._valid_position(position):
		return false
	if enemies.is_slain(position):
		return false
	_pinner_by_position[position] = pinner_id
	return true


## Returns the pinner ID for the enemy at the given position, or empty string if none.
func pinner_for_enemy(position: int) -> String:
	if not _pinner_by_position.has(position):
		return ""
	return _pinner_by_position[position]


## Returns the cross-hero bonus (+5) that would apply if the given attacker
## attacks the enemy at the given position. Returns 0 if no pin, if the attacker
## is the same as the pinner, or if the target is invalid/dead. Does not consume.
func bonus_for_attack(enemies: CombatEnemies, position: int, attacker_id: String) -> int:
	if enemies == null or not enemies.is_valid():
		return 0
	if not _valid_pinner_id(attacker_id):
		return 0
	if not enemies._valid_position(position):
		return 0
	if enemies.is_slain(position):
		return 0
	var pinner: String = _pinner_by_position.get(position, "")
	if pinner.is_empty() or pinner == attacker_id:
		return 0
	return 5


## Consumes the pin after a confirmed successful cross-hero attack.
## Returns true if the pin was consumed, false otherwise.
## Previews (hit_confirmed=false), same-hero attacks, and missing pins never consume.
## Allows consumption on a lethal confirmed hit (enemy reaches 0 HP).
func consume_after_attack(position: int, attacker_id: String, hit_confirmed: bool) -> bool:
	if not hit_confirmed:
		return false
	if not _valid_pinner_id(attacker_id):
		return false
	if not _pinner_by_position.has(position):
		return false
	var pinner: String = _pinner_by_position[position]
	if pinner == attacker_id:
		return false
	_pinner_by_position.erase(position)
	return true


## Removes any token on the given position. A lethal confirmed attack clears the
## pin it would otherwise leave on a slain enemy. Returns true when a token was
## removed; missing tokens are a no-op.
func clear_pin(position: int) -> bool:
	if not _pinner_by_position.has(position):
		return false
	_pinner_by_position.erase(position)
	return true


## Clears all pinned tokens. Called at combat end.
func reset_combat() -> void:
	_pinner_by_position.clear()


func _valid_pinner_id(pinner_id: String) -> bool:
	return pinner_id is String and not pinner_id.is_empty() and pinner_id in ["warden", "seamstress", "tinker"]