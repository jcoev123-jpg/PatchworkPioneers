class_name StitchedWalkMimicBattle
extends RefCounted
## One-shot S8c bridge. S8f will call this with the actual completed Walk.
## Pending dictionaries are never an input authority. Other Walk effects remain deferred.

static func create(walk: Variant, expected: Dictionary, config: Dictionary) -> Dictionary:
	if not walk is StitchedWalkRules or walk._rng == null or walk._battle_consumed:
		return _reject("missing or consumed Walk")
	var state: Dictionary = walk.snapshot()
	if state != expected or state.get("phase") != "complete" or walk._rng.state != state.get("rng"):
		return _reject("stale or incomplete Walk")
	# Reject caller-authored bridge options and RNG substitutions, even if harmless.
	for key in ["walk_mimic", "walk_cuts", "walk_vitality", "run_rng"]:
		if config.has(key):
			return _reject("reserved combat option: " + key)
	if not config.get("heroes") is Array or config.heroes.size() != state.dolls.size():
		return _reject("combat party does not match Walk")
	var payload := config.duplicate(true)
	payload.walk_vitality = {}
	for index in state.dolls.size():
		var doll: Dictionary = state.dolls[index]
		payload.walk_vitality[doll.id] = doll.max_hp
		if not payload.heroes[index] is Dictionary or payload.heroes[index].get("id") != doll.id:
			return _reject("combat ranks do not match Walk")
		# Carry settled HP/fray verbatim, including wrong-SNIP's already-paid +20.
		for key in ["hp", "fray", "lost", "resolve"]:
			payload.heroes[index][key] = doll.get(key, "" if key == "resolve" else 0)
	var cuts := {}
	var mimic := false
	for effect in state.pending:
		if effect.consumed:
			continue
		if effect.kind == "mimic":
			mimic = true
		elif effect.kind == "cut_thread":
			for doll in state.dolls:
				if doll.id == effect.target:
					cuts[doll.id] = doll.rank
	payload.walk_mimic = mimic
	payload.walk_cuts = cuts
	var trial := RandomNumberGenerator.new()
	trial.state = walk._rng.state
	payload.run_rng = trial
	var result := StitchedRules.create(payload)
	if not result.ok:
		return result
	# Commit only after complete validation, then borrow the single run RNG.
	walk._rng.state = trial.state
	result.battle._rng = walk._rng
	walk._battle_consumed = true
	for effect in walk._state.pending:
		if effect.kind in ["mimic", "cut_thread"]:
			effect.consumed = true
	walk._state.revision += 1
	walk._state.rng = walk._rng.state
	return result


static func _reject(error: String) -> Dictionary:
	return {"ok": false, "error": error, "battle": null}
