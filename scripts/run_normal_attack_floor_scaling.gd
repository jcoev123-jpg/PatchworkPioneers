class_name RunNormalAttackFloorScaling
extends RefCounted
## Pure, stateless floor-band scaling for authored NORMAL enemy attack amounts.
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
