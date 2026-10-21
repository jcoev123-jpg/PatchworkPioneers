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
		forecasts.append({
			"id": next["id"],
			"hp_before": hp_before,
			"hp_after": hp_after,
			"hp_delta": hp_after - hp_before,
			"revived": hp_before == 0,
		})
	return {"ok": true, "heroes": predicted, "forecasts": forecasts}
