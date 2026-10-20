class_name RunVictoryGold
extends RefCounted
## One-shot seeded gold payout after an observed victorious fight.
## Bound to a CombatBattleResult on construction; never mutates rosters or RNG
## except for the single authorised payout draw.

const NORMAL_MIN := 10
const NORMAL_MAX := 20
const ELITE_MIN := 25
const ELITE_MAX := 35

var _result: CombatBattleResult = null
var _claimed: bool = false


func _init(result: CombatBattleResult = null) -> void:
	_result = result


## Claim the single gold payout for this observed fight. Returns 0 and keeps the
## claim open for unobserved, non-victorious, null, or invalid inputs.
func claim_gold(is_elite: bool, run_rng: RandomNumberGenerator) -> int:
	if _claimed:
		return 0
	if _result == null or not is_instance_valid(_result):
		return 0
	if run_rng == null or not is_instance_valid(run_rng):
		return 0
	# Only an already-observed VICTORY may pay. get_outcome() does not reevaluate
	# or observe a new terminal state, so unobserved fights stay unpaid.
	if _result.get_outcome() != CombatBattleResult.VICTORY:
		return 0
	var minimum := ELITE_MIN if is_elite else NORMAL_MIN
	var maximum := ELITE_MAX if is_elite else NORMAL_MAX
	var gold := run_rng.randi_range(minimum, maximum)
	_claimed = true
	return gold


func is_claimed() -> bool:
	return _claimed