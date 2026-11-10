extends SceneTree
## S8f: with walks on, every non-boss map node is reached through a seeded Walk whose
## consequences reach the next battle, and a save taken mid-Walk replays exactly.

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _walk_step(session: StitchedRunSession) -> Dictionary:
	var walk := session.walk
	var actor: String = walk.snapshot().viewpoint
	var command := {"kind": "forward", "actor": actor}
	if walk.tug_unresolved():
		command = {"kind": "tug", "actor": actor, "target": walk.snapshot().tug.id, "choice": "yield"}
	return session.walk_act(command, session.snapshot())


func _roundtrip(session: StitchedRunSession, label: String) -> void:
	var before := session.snapshot()
	var document := StitchedRunSave.capture(session)
	_check(not document.is_empty(), label + " captures")
	var restored := StitchedRunSave.restore(bytes_to_var(var_to_bytes(document)))
	_check(restored != null and restored.snapshot() == before, label + " restores the exact Walk, RNG and carry")
	if restored != null and restored.phase == "walk":
		var a := _walk_step(session)
		var b := _walk_step(restored)
		_check(a.get("ok") == true and b.get("ok") == true and restored.snapshot() == session.snapshot(),
			label + " the restored Walk continues on the same seeded path")
	var forged := document.duplicate(true)
	forged.state.walk.enabled = false
	forged.digest = StitchedRunSave._digest(forged)
	_check(StitchedRunSave.restore(forged) == null, label + " a run cannot quietly switch its Walk mode")


func _run_seed(seed_number: int) -> void:
	var session := StitchedRunSession.start(seed_number)
	_check(session != null, "seed %d starts" % seed_number)
	if session == null:
		return
	_check(session.enable_walks() and session.walks_enabled and session.is_consistent(), "new runs opt into Walks")
	var entered := 0
	var guard := 0
	while entered < 3 and guard < 400:
		guard += 1
		match session.phase:
			"map":
				var choices := session.choices()
				var pick := ""
				for id in choices:
					if session.map.get_node(id).type != "Boss":
						pick = id
						break
				if pick.is_empty():
					break
				var node_type: String = session.map.get_node(pick).type
				var rng_before := session.rng.state
				_check(session.enter(pick, session.snapshot()), "seed %d enters %s" % [seed_number, node_type])
				_check(session.phase == "walk" and session.walk != null, "a %s node is reached through a Walk" % node_type)
				_check(session.walk.snapshot().area == session.walk_area(), "the corridor follows the floor")
				_check(session.rng.state != rng_before, "the Walk draws from the run RNG")
				entered += 1
				if entered == 1:
					_walk_step(session)
					_roundtrip(session, "seed %d mid-Walk" % seed_number)
			"walk":
				var stale := session.snapshot()
				stale.candle += 1
				_check(session.walk_act({"kind": "forward", "actor": session.walk.snapshot().viewpoint}, stale).ok == false,
					"a stale snapshot cannot move the Walk")
				var receipt := _walk_step(session)
				_check(receipt.get("ok") == true, "seed %d Walk step: %s" % [seed_number, receipt.get("error", "")])
				if receipt.get("ok") != true:
					return
				if session.phase != "walk":
					_check(session.walk == null and session.phase in ["battle", "visit"] and session.is_consistent(),
						"a finished Walk opens its node")
					_check(session.walk_receipts.size() == entered, "each Walk leaves a receipt")
					_roundtrip(session, "seed %d after Walk" % seed_number)
			"battle":
				# Leave the fight by retreating: the Walk's job ends once the battle is open.
				return
			"visit":
				var actions := session.visit_actions()
				var leave := -1
				for index in actions.size():
					if actions[index].id == "leave" and actions[index].enabled:
						leave = index
				if leave < 0:
					return
				session.choose_visit(actions[leave].id, actions[leave].arguments, session.snapshot())
			_:
				return
	_check(entered >= 1, "seed %d reached at least one node" % seed_number)


## A seeded visit Walk with a genuinely unresolved shadow leaves the bridge's
## validated arrival waiting for the next battle; null when this seed has none.
func _deferred(seed_number: int) -> StitchedRunSession:
	var session := StitchedRunSession.start(seed_number)
	if session == null or not session.enable_walks():
		return null
	var pick := ""
	for id in session.choices():
		var node_type: String = session.map.get_node(id).type
		if node_type != "Boss" and not node_type in ["Fight", "Elite"]:
			pick = id
			break
	if pick.is_empty() or not session.enter(pick, session.snapshot()):
		return null
	if session.phase != "walk" or session.walk == null:
		return null
	for guard in 30:
		if session.phase != "walk":
			break
		if _walk_step(session).get("ok") != true:
			return null
	if session.phase != "visit" or session.walk_arrival.is_empty():
		return null
	return session


## A seeded visit Walk whose shadow is wrongly SNIPPED leaves a genuine cut (and
## the unresolved mimic) waiting for the next battle; null when this seed has none.
func _deferred_cut(seed_number: int) -> StitchedRunSession:
	var session := StitchedRunSession.start(seed_number)
	if session == null or not session.enable_walks():
		return null
	var pick := ""
	for id in session.choices():
		var node_type: String = session.map.get_node(id).type
		if node_type != "Boss" and not node_type in ["Fight", "Elite"]:
			pick = id
			break
	if pick.is_empty() or not session.enter(pick, session.snapshot()):
		return null
	if session.phase != "walk" or session.walk == null:
		return null
	var shadow: Dictionary = session.walk.snapshot().get("shadow", {})
	if shadow.is_empty() or not bool(shadow.get("present", false)):
		return null
	while session.phase == "walk" and session.walk.snapshot().step < int(shadow.step):
		if _walk_step(session).get("ok") != true:
			return null
	if session.phase != "walk":
		return null
	if session.walk_act({"kind": "look_back", "actor": session.walk.snapshot().viewpoint},
			session.snapshot()).get("ok") != true:
		return null
	if not session.walk.shadow_visible():
		return null
	var snip := session.walk_act({"kind": "snip", "actor": session.walk.snapshot().viewpoint,
		"target": session.heroes[1].id}, session.snapshot())
	if snip.get("ok") != true:
		return null
	for guard in 30:
		if session.phase != "walk":
			break
		if _walk_step(session).get("ok") != true:
			return null
	if session.phase != "visit" or session.walk_arrival.is_empty() or session.walk_arrival.cuts.is_empty():
		return null
	return session


## The bridge's genuine deferred arrival carries the mimic to the next battle
## alongside the ordinary carries; a wrong SNIP's cut pays its own 20 fray.
func _carry() -> void:
	var session: StitchedRunSession = null
	for candidate in 32:
		session = _deferred(candidate)
		if session != null:
			break
	_check(session != null, "a genuine deferred mimic arrival witness exists")
	if session == null:
		return
	var target: String = session.heroes[1].id
	session.walk_carry = [{"kind": "machine", "extra_foes": 1, "party_fray": 10},
		{"kind": "fray", "target": target, "amount": 15}]
	var before := {}
	for hero in session.heroes:
		before[hero.id] = int(hero.fray)
	_check(session._open_battle("Fight"), "a battle opens with the Walk's carry and arrival")
	var units: Dictionary = session.battle._units
	_check(units.has(StitchedRules.WALK_MIMIC_ID), "the uncaught mimic arrives as One Doll Too Many")
	_check(int(units[target].fray) >= before[target] + 25, "Walk fray and the Machine's toll reach the fight")
	_check(session.walk_carry.is_empty() and session.walk_arrival.is_empty(),
		"carry and arrival are spent by exactly one battle")
	var cut: StitchedRunSession = null
	for candidate in 32:
		cut = _deferred_cut(candidate)
		if cut != null:
			break
	_check(cut != null, "a genuine deferred cut arrival witness exists")
	if cut == null:
		return
	var cut_id: String = cut.heroes[1].id
	_check(cut._open_battle("Fight"), "a cut thread opens a battle")
	_check(cut.battle._thread_cuts.has(cut_id) and int(cut.battle._units[cut_id].fray) >= 20,
		"a cut thread arrives cut and pays its 20 fray")
	_check(cut.battle._units.has(StitchedRules.WALK_MIMIC_ID),
		"the wrongly snipped shadow still ambushes the same battle")


func _legacy() -> void:
	var session := StitchedRunSession.start(11)
	var document := StitchedRunSave.capture(session)
	document.state.erase("walk")
	document.digest = StitchedRunSave._digest(document)
	var restored := StitchedRunSave.restore(document)
	_check(restored != null and not restored.walks_enabled, "pre-S8f saves load without Walks")
	_check(not session.walks_enabled and session.enter(session.choices()[0], session.snapshot()) and session.phase != "walk",
		"runs without Walks still enter nodes directly")


func _init() -> void:
	# Owner 11-10 retired fray and Wren's hand actions in live fights; this legacy test still covers them.
	StitchedRules.fray_enabled = true
	StitchedRules.wren_hands = true
	for seed_number in [3, 42, 901]:
		_run_seed(seed_number)
	_carry()
	_legacy()
	if failures.is_empty():
		print("stitched_s8f_routed_walk_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s8f_routed_walk_test: FAIL (%d of %d)" % [failures.size(), checks])
		quit(1)
