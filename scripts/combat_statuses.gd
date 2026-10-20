class_name CombatStatuses
extends RefCounted
## Pure, actor-local rules. Neither entrypoint changes a caller's status dictionary.
## Status counts represent remaining *owner* turns, including the current turn.

const MAX_INT := 9223372036854775807


## Invalid damage or status data fails closed to zero, never an unmodified attack.
## Integer quotient/remainder arithmetic floors ONCE and avoids overflow.
func adjusted_attack_damage(base_damage: int, attacker_statuses: Dictionary, defender_statuses: Dictionary) -> int:
	if base_damage < 0 or not _valid_statuses(attacker_statuses) or not _valid_statuses(defender_statuses):
		return 0

	var weak: bool = attacker_statuses.get("weak", 0) > 0
	var exposed: bool = defender_statuses.get("exposed", 0) > 0
	var numerator := 1
	var denominator := 1
	if weak and exposed:
		numerator = 9
		denominator = 8
	elif weak:
		numerator = 3
		denominator = 4
	elif exposed:
		numerator = 3
		denominator = 2

	@warning_ignore("integer_division")
	var whole: int = base_damage / denominator
	@warning_ignore("integer_division")
	var partial: int = (base_damage % denominator) * numerator / denominator
	@warning_ignore("integer_division")
	if whole > (MAX_INT - partial) / numerator:
		return 0
	return whole * numerator + partial


## One affected actor's turn ends. Bleed is direct HP loss, never Block damage.
## Weak and Exposed expire at this boundary, after applying during this turn.
## Invalid state returns ok=false and an independent, unchanged deep snapshot.
func end_owner_turn(hp: int, block: int, statuses: Dictionary) -> Dictionary:
	var next_statuses: Dictionary = statuses.duplicate(true)
	if hp < 0 or block < 0 or not _valid_statuses(statuses):
		return {"ok": false, "hp": hp, "block": block, "statuses": next_statuses, "bleed_hp_loss": 0}

	var loss: int = mini(hp, statuses.get("bleed", 0))
	next_statuses.clear()
	for name in ["bleed", "weak", "exposed"]:
		var remaining: int = statuses.get(name, 0)
		if remaining > 1:
			next_statuses[name] = remaining - 1
	return {"ok": true, "hp": hp - loss, "block": block, "statuses": next_statuses, "bleed_hp_loss": loss}


func _valid_statuses(statuses: Dictionary) -> bool:
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed"]:
			return false
		var count = statuses[name]
		if not count is int or count < 0:
			return false
	return true
