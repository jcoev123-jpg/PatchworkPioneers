class_name StitchedWalkMimicBattle
extends RefCounted
## One-shot S8c bridge. Its single live entry point is the routed session's
## completed Walk (StitchedRunSession._finish_walk plans, its _open_battle admits
## and commits); tests exercise the same validation through create. Pending
## dictionaries are never an input authority. Other Walk effects remain deferred.


## Derive the arrival plan's complete contents from a genuinely complete Walk
## state: the authenticated ambush flag, one cut rank per wrongly-snipped doll,
## and the settled doll facts. Never mutates and never draws randomness.
static func _derive(state: Dictionary) -> Dictionary:
	var cuts := {}
	var mimic := false
	var vitality := {}
	var carry: Array = []
	for doll in state.dolls:
		vitality[doll.id] = doll.max_hp
		carry.append({"id": doll.id, "hp": doll.hp, "fray": doll.get("fray", 0),
			"lost": doll.lost, "resolve": doll.get("resolve", "")})
	for effect in state.pending:
		if effect.consumed:
			continue
		if effect.kind == "mimic":
			mimic = true
		elif effect.kind == "cut_thread":
			for doll in state.dolls:
				if doll.id == effect.target:
					cuts[doll.id] = doll.rank
	return {"ok": true, "error": "", "battle": null, "mimic": mimic, "cuts": cuts,
		"vitality": vitality, "carry": carry, "rng": state.get("rng")}


## Validated, detached arrival plan from a genuinely completed Walk. Never mutates
## the Walk and never draws randomness. Returns {ok, error, battle: null, mimic, cuts,
## vitality, carry, rng}: mimic is the authenticated ambush flag, cuts maps each
## wrongly-snipped doll id to its Walk rank, vitality and carry pin the settled doll
## facts, and rng is the Walk's sealed RNG state.
static func plan(walk: Variant, expected: Dictionary) -> Dictionary:
	if not walk is StitchedWalkRules or walk._rng == null or walk._battle_consumed:
		return _reject("missing or consumed Walk")
	var state: Dictionary = walk.snapshot()
	if state != expected or state.get("phase") != "complete" or walk._rng.state != state.get("rng"):
		return _reject("stale or incomplete Walk")
	return _derive(state)


## Revalidate a stored plan against its still-unspent completed Walk at battle
## time. The Walk's own sealed state pins the plan (later Walks may have advanced
## the shared run RNG, so only the seal is compared): the Walk must still produce
## exactly this complete plan, so forged, partial or stale plans refuse. Never
## mutates the Walk and never draws randomness.
static func revalidate(walk: Variant, arrival: Variant) -> bool:
	if not walk is StitchedWalkRules or walk._rng == null or walk._battle_consumed:
		return false
	if not arrival is Dictionary or arrival.get("ok") != true:
		return false
	var state: Dictionary = walk.snapshot()
	if state.get("phase") != "complete" or state.get("rng") != arrival.get("rng"):
		return false
	return _derive(state) == arrival


## The merged next-battle plan from per-Walk plans: one 20-fray amount per genuine
## wrong SNIP, so repeated wrong SNIPs on one doll all pay, while the cut itself
## is presented once for RE-TIE, plus any Walk's authenticated ambush flag.
static func merged(plans: Array) -> Dictionary:
	var mimic := false
	var cuts := {}
	var amounts := {}
	for one in plans:
		if not one is Dictionary or one.get("ok") != true or not one.get("cuts") is Dictionary:
			return {}
		mimic = mimic or bool(one.get("mimic", false))
		for doll_id in one.cuts:
			cuts[doll_id] = one.cuts[doll_id]
			amounts[doll_id] = int(amounts.get(doll_id, 0)) + 20
	return {"ok": true, "error": "", "battle": null, "mimic": mimic, "cuts": cuts,
		"amounts": amounts}


## Fail-closed session admission for the next battle's bridge plan: `published` is
## the session's saved merged plan and `entries` pairs each still-live completed
## Walk with the plan its own settlement validated. Every entry must still be its
## Walk's genuine complete unspent plan and the merged plan must equal `published`
## exactly; anything else admits nothing. Never mutates and never draws randomness.
static func admit(published: Variant, entries: Variant) -> Dictionary:
	if not published is Dictionary or not entries is Array:
		return {}
	var plans: Array = []
	for entry in entries:
		if not entry is Dictionary or not revalidate(entry.get("walk"), entry.get("plan")):
			return {}
		plans.append(entry.plan)
	var admission := merged(plans)
	if published.is_empty() and entries.is_empty():
		return admission
	return admission if admission == published else {}


## Commit a successful plan against its Walk: consume the one-shot mimic/cut
## descriptors and seal the borrowed RNG into the Walk's own state. The plan must
## still be this Walk's genuine complete unspent plan and the run RNG must be the
## Walk's own borrowed generator; a refusal touches nothing.
static func commit(walk: Variant, arrival: Dictionary, rng_state: int) -> bool:
	if not revalidate(walk, arrival):
		return false
	if walk._rng.state != rng_state:
		return false
	for effect in walk._state.pending:
		if effect.kind in ["mimic", "cut_thread"]:
			effect.consumed = true
	walk._battle_consumed = true
	walk._state.revision += 1
	walk._state.rng = walk._rng.state
	return true


## Authenticated one-shot bridge for a caller-supplied combat config: plan the
## arrival, dress the config from the plan, build the plain rules battle, commit.
static func create(walk: Variant, expected: Dictionary, config: Dictionary) -> Dictionary:
	var arrival := plan(walk, expected)
	if not arrival.ok:
		return arrival
	# Reject caller-authored bridge options and RNG substitutions, even if harmless.
	for key in ["walk_mimic", "walk_cuts", "walk_vitality", "run_rng"]:
		if config.has(key):
			return _reject("reserved combat option: " + key)
	if not config.get("heroes") is Array or config.heroes.size() != arrival.carry.size():
		return _reject("combat party does not match Walk")
	var payload := config.duplicate(true)
	payload.walk_vitality = arrival.vitality.duplicate(true)
	for index in arrival.carry.size():
		var doll: Dictionary = arrival.carry[index]
		if not payload.heroes[index] is Dictionary or payload.heroes[index].get("id") != doll.id:
			return _reject("combat ranks do not match Walk")
		# Carry settled HP/fray verbatim, including wrong-SNIP's already-paid +20.
		for key in ["hp", "fray", "lost", "resolve"]:
			payload.heroes[index][key] = doll[key]
	payload.walk_mimic = arrival.mimic
	payload.walk_cuts = arrival.cuts.duplicate(true)
	var trial := RandomNumberGenerator.new()
	trial.state = arrival.rng
	payload.run_rng = trial
	var result := StitchedRules.create(payload)
	if not result.ok:
		return result
	# Commit only after complete validation, then borrow the single run RNG.
	walk._rng.state = trial.state
	result.battle._rng = walk._rng
	if not commit(walk, arrival, trial.state):
		return _reject("bridge commit failed")
	return result


static func _reject(error: String) -> Dictionary:
	return {"ok": false, "error": error, "battle": null}
