class_name RunNormalAttackFloorScaling
extends RefCounted
## Pure, stateless floor-band scaling for authored NORMAL enemy attack amounts and max HP.
## Floors 1-4 x1.0, 5-8 x1.25, 9-11 x1.5 with integer truncation; floor 12 is a Boss.
## Elite, Boss, Block, status, DOT, hero and counter-damage are out of scope.

static func scale_normal_attack(base_amount: Variant, floor_number: Variant) -> Dictionary:
	if typeof(base_amount) != TYPE_INT or typeof(floor_number) != TYPE_INT:
		return {"ok": false, "amount": 0}

	var base: int = base_amount
	var floor: int = floor_number
	if base < 5 or base > 9 or floor < 1 or floor > 11:
		return {"ok": false, "amount": 0}

	var amount: int
	if floor <= 4:
		amount = base
	elif floor <= 8:
		@warning_ignore("integer_division")
		amount = base * 5 / 4
	else:
		@warning_ignore("integer_division")
		amount = base * 3 / 2

	return {"ok": true, "amount": amount}


static func scale_normal_max_hp(base_max_hp: Variant, floor_number: Variant) -> Dictionary:
	if typeof(base_max_hp) != TYPE_INT or typeof(floor_number) != TYPE_INT:
		return {"ok": false, "max_hp": 0}

	var base: int = base_max_hp
	var floor: int = floor_number
	if base < 1 or floor < 1 or floor > 11:
		return {"ok": false, "max_hp": 0}

	var max_hp: int
	if floor <= 4:
		max_hp = base
	elif floor <= 8:
		@warning_ignore("integer_division")
		max_hp = base * 5 / 4
	else:
		@warning_ignore("integer_division")
		max_hp = base * 3 / 2

	if max_hp < 1:
		return {"ok": false, "max_hp": 0}
	return {"ok": true, "max_hp": max_hp}


static func scale_normal_stats(base_max_hp: Variant, base_attack: Variant, floor_number: Variant) -> Dictionary:
	var hp_result := scale_normal_max_hp(base_max_hp, floor_number)
	var attack_result := scale_normal_attack(base_attack, floor_number)
	if not bool(hp_result.get("ok", false)) or not bool(attack_result.get("ok", false)):
		return {"ok": false, "max_hp": 0, "attack": 0}
	return {"ok": true, "max_hp": int(hp_result["max_hp"]), "attack": int(attack_result["amount"])}
