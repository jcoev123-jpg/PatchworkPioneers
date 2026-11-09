extends SceneTree
## Playtest 11-09: letting the Walk's thread tug win tore a part off the rear doll above 0 HP. Owner 11-08:
## in S14 limbs come off only at 0 HP, so the tug opens a seam that bleeds at the next fight instead.

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _torn(session: StitchedRunSession) -> Array:
	var torn: Array = []
	for hero in session.heroes:
		for slot in hero.parts:
			if bool(hero.parts[slot].torn):
				torn.append("%s/%s" % [hero.id, slot])
	return torn


## Walks one seed's first non-boss node, always letting the tug win; returns the doll it pulled, or "".
func _yield_seed(seed_number: int, s14: bool) -> Dictionary:
	var session := StitchedRunSession.start(seed_number)
	if session == null or not session.enable_walks():
		return {}
	session.s14_enabled = s14
	var pick := ""
	for id in session.choices():
		if session.map.get_node(id).type in ["Fight", "Elite"]:
			pick = id
			break
	if pick.is_empty() or not session.enter(pick, session.snapshot()) or session.phase != "walk":
		return {}
	var torn_before := _torn(session)
	var pulled := ""
	for _step in 200:
		if session.phase != "walk":
			break
		var walk := session.walk
		var actor: String = walk.snapshot().viewpoint
		var command := {"kind": "forward", "actor": actor}
		if walk.tug_unresolved():
			command = {"kind": "tug", "actor": actor, "target": walk.snapshot().tug.id, "choice": "yield"}
		var receipt := session.walk_act(command, session.snapshot())
		if receipt.get("ok") != true:
			return {}
		for event in receipt.get("events", []):
			if event.get("kind") == "tug_torn":
				pulled = str(event.target)
	return {"session": session, "pulled": pulled, "torn_before": torn_before}


func _initialize() -> void:
	var seen := 0
	for seed_number in range(1, 40):
		var run := _yield_seed(seed_number, true)
		if run.is_empty() or run.pulled.is_empty():
			continue
		var session: StitchedRunSession = run.session
		if session.phase != "battle" or session.battle == null:
			continue
		seen += 1
		_check(_torn(session) == run.torn_before, "seed %d: the tug takes no part in S14" % seed_number)
		var unit: Dictionary = session.battle._units.get(run.pulled, {})
		_check(not unit.is_empty() and int(unit.statuses.get("bleed", 0)) >= 2,
			"seed %d: the pulled doll opens the fight bleeding" % seed_number)
		_check(session.walk_carry.is_empty(), "seed %d: the seam lands once, at that fight" % seed_number)
		if seen >= 3:
			break
	_check(seen > 0, "precondition: some seed's tug pulls a doll before a fight")

	for seed_number in range(1, 40):
		var run := _yield_seed(seed_number, false)
		if run.is_empty() or run.pulled.is_empty():
			continue
		var session: StitchedRunSession = run.session
		_check(_torn(session).size() > run.torn_before.size(), "card runs keep the old part tear")
		break

	for failure in failures:
		printerr("FAIL: ", failure)
	print("stitched_s14_walk_tug_seam_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
