class_name RunRestHealPreview
extends RefCounted
## Read-only forecast for the HEAL choice of a future Rest visit.
## No live visit, run ledger, or RNG is touched.

static func preview(run_heroes: Variant) -> Dictionary:
	# The recovery service is the authority for both validation and HP arithmetic.
	# This temporary visit is discarded immediately after its one heal attempt.
	var visit := RunRestRecovery.new(run_heroes)
	var result: Dictionary = visit.choose_heal()
	if result.get("ok") != true:
		return {"ok": false, "heroes": [], "forecasts": []}

	var before: Array = run_heroes
	var predicted: Array = result["heroes"]  # Already deep-copied by RunRestRecovery.
	var forecasts: Array = []
	for i in range(predicted.size()):
		var previous: Dictionary = before[i]
		var next: Dictionary = predicted[i]
		var hp_before: int = int(previous["hp"])
		var hp_after: int = int(next["hp"])
		var max_hp: int = int(previous.get("max_hp", 0))
		var base_heal: int = (max_hp * 3) / 10
		var revive_hp: int = 1 if hp_before == 0 else 0
		var wasted_heal: int = max(0, hp_before + revive_hp + base_heal - hp_after)
		forecasts.append({
			"id": next["id"],
			"hp_before": hp_before,
			"hp_after": hp_after,
			"hp_delta": hp_after - hp_before,
			"revived": hp_before == 0,
			"max_hp": max_hp,
			"base_heal": base_heal,
			"revive_hp": revive_hp,
			"wasted_heal": wasted_heal,
		})
	return {"ok": true, "heroes": predicted, "forecasts": forecasts}
