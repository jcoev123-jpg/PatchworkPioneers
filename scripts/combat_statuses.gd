class_name CombatStatuses
extends RefCounted
## Pure, actor-local rules. No entrypoint changes a caller's status dictionary.
## Bleed, Weak, Exposed and Tangled counts represent remaining *owner* turns,
## including the current turn. Riposte is not an N-turn counter: N is the
## counterdamage returned by each confirmed hit during its single owner turn.

const MAX_INT := 9223372036854775807


## Invalid damage or status data fails closed to zero, never an unmodified attack.
## Integer quotient/remainder arithmetic floors ONCE and avoids overflow.
## A positive-base attack adds Tangled's flat +2 after the Weak/Exposed floor,
## once per attack regardless of the defender's stack count.
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
	var adjusted: int = whole * numerator + partial
	if base_damage > 0 and defender_statuses.get("tangled", 0) > 0:
		if adjusted > MAX_INT - 2:
			return 0
		adjusted += 2
	return adjusted


## Riposte N means "when hit, strike back N". N is damage, never a duration: an
## active Riposte may counter every separate confirmed hit during its one owner
## turn, then expires completely at that owner's turn end.
## The authoritative caller owns hit confirmation, eligibility and the actual
## damage transaction; this pure projection only reports the counterdamage.
## Invalid status input, an unconfirmed (skipped) hit, and no/zero Riposte all
## return 0. Nothing here mutates HP, Block, RNG, cards, statuses or attackers.
func riposte_damage_for_confirmed_hit(statuses: Dictionary, hit_confirmed: bool) -> int:
	if not hit_confirmed or not _valid_statuses(statuses):
		return 0
	var riposte: int = statuses.get("riposte", 0)
	if riposte <= 0:
		return 0
	return riposte


## One affected actor's turn ends. Bleed is direct HP loss, never Block damage.
## Weak, Exposed and Tangled expire at this boundary, after applying during this turn.
## Riposte is removed completely after this one owner turn, whatever its N was.
## Invalid state returns ok=false and an independent, unchanged deep snapshot.
func end_owner_turn(hp: int, block: int, statuses: Dictionary) -> Dictionary:
	var next_statuses: Dictionary = statuses.duplicate(true)
	if hp < 0 or block < 0 or not _valid_statuses(statuses):
		return {"ok": false, "hp": hp, "block": block, "statuses": next_statuses, "bleed_hp_loss": 0}

	var loss: int = mini(hp, statuses.get("bleed", 0))
	next_statuses.clear()
	for name in ["bleed", "weak", "exposed", "tangled"]:
		var remaining: int = statuses.get(name, 0)
		if remaining > 1:
			next_statuses[name] = remaining - 1
	return {"ok": true, "hp": hp - loss, "block": block, "statuses": next_statuses, "bleed_hp_loss": loss}


func _valid_statuses(statuses: Dictionary) -> bool:
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed", "tangled", "riposte"]:
			return false
		var count = statuses[name]
		if not count is int or count < 0:
			return false
	return true
