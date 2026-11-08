extends RefCounted
## Run-time witness search for live route tests (owner 2026-11-08: "make the live tests find their witness
## seed and route at run time"). These tests used to replay one hard-coded seed and route, so any lane that
## added an Event or retuned a fight moved the outcome and failed the merge check, though each lane passed
## alone (a lane run tests only its related files). Now a map-only pass lists candidate [seed, route] pairs
## (map traversal draws no RNG, so this is cheap), the real mounted controls play each candidate, and the
## first one that genuinely meets the test's starting condition is its witness. No cheats: every fight is
## still played through the public battle controls.

const SEEDS := 300
const TRIES := 12


## Routes from the opening whose node types match `kinds` floor by floor, at most `limit`. Each entry is a
## type ("Fight"), "!Type" for any other type, an Array of types, or "" for any type. Choices are tried in
## `prefer` order (unlisted types after), then by id, so the first routes favour the preferred stops.
static func routes(map: RunMap, kinds: Array, limit := 2, prefer: Array = []) -> Array:
	var found: Array = []
	_walk(map, map.get_legal_choices(), kinds, [], found, limit, prefer)
	return found


static func _walk(map: RunMap, choices: Array, kinds: Array, path: Array, found: Array, limit: int, prefer: Array) -> void:
	if found.size() >= limit:
		return
	if path.size() == kinds.size():
		found.append(path.duplicate())
		return
	var ordered := choices.duplicate()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		var rank_a := _rank(prefer, str(map.get_node(a).type))
		var rank_b := _rank(prefer, str(map.get_node(b).type))
		return rank_a < rank_b or (rank_a == rank_b and a < b))
	for id in ordered:
		if not _fits(kinds[path.size()], str(map.get_node(id).type)):
			continue
		path.append(id)
		_walk(map, map.get_node(id).get("outgoing", []), kinds, path, found, limit, prefer)
		path.pop_back()
		if found.size() >= limit:
			return


static func _rank(prefer: Array, type: String) -> int:
	var index := prefer.find(type)
	return prefer.size() if index < 0 else index


static func _fits(want: Variant, type: String) -> bool:
	if want is Array:
		return want.has(type)
	var text := str(want)
	if text.begins_with("!"):
		return type != text.substr(1)
	return text.is_empty() or text == type


## [seed, route] candidates in seed order from `first`: up to `per_seed` matching routes of each seed's map,
## generated exactly as StitchedRunSession.start does.
static func candidates(kinds: Array, first := 0, per_seed := 1, prefer: Array = [], count := SEEDS) -> Array:
	var found: Array = []
	for seed_number in range(first, first + count):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_number
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for route in routes(map, kinds, per_seed, prefer):
			found.append([seed_number, route])
	return found


## Plays `route` on the mounted run through the public controls: each fight with test._win (it must end
## in victory), each other stop closed with test._finish_visit. The last node is entered and left open.
## {"ok", "why", "fights": [{"id", "acted", "outcome"}]}.
static func play_route(test: Object, app: Node, route: Array) -> Dictionary:
	var session: StitchedRunSession = app.stitched_run_session
	var fights: Array = []
	if session == null:
		return {"ok": false, "why": "no run session", "fights": fights}
	for index in route.size():
		var id := str(route[index])
		if session.phase != "map" or not test._press_route(app, id):
			return {"ok": false, "why": "could not enter " + id, "fights": fights}
		if index == route.size() - 1:
			break
		# A stop may open a fight (and a fight a stop), so settle until the map is back.
		for step in range(6):
			if session.phase == "battle":
				var stage: StitchedBattleScreen = app.stitched_run_battle
				if stage == null:
					return {"ok": false, "why": "no mounted battle at " + id, "fights": fights}
				var result: Dictionary = test._win(stage)
				fights.append({"id": id, "acted": int(result.acted), "outcome": stage.battle.outcome()})
				if stage.battle.outcome() != "victory":
					return {"ok": false, "why": "lost the fight at " + id, "fights": fights}
				stage._action_buttons["exit"].pressed.emit()
			elif session.phase == "visit":
				if not test._finish_visit(app):
					return {"ok": false, "why": "could not finish the stop at " + id, "fights": fights}
			else:
				break
		if session.phase != "map":
			return {"ok": false, "why": "stuck in " + session.phase + " after " + id, "fights": fights}
	return {"ok": true, "why": "", "fights": fights}


## The first candidate whose live play passes `accept` (Callable(app, played) -> bool), tried in order, at
## most `tries`. {"app", "seed", "route", "played"} with the app still mounted, or {} (trial apps freed).
static func first_played(test: Object, found: Array, accept: Callable, tries := TRIES) -> Dictionary:
	for candidate in found.slice(0, tries):
		var app: Node = await test._new_run(int(candidate[0]))
		var played := play_route(test, app, candidate[1])
		if played.ok and accept.call(app, played):
			return {"app": app, "seed": candidate[0], "route": candidate[1], "played": played}
		app.free()
		await test.process_frame
	return {}


## A live LOST witness: the first candidate whose opening Fight, played by passing until a doll is LOST and
## then fighting on with test._win, is won with exactly `lost` LOST dolls, and whose route goes on through
## `after` (default a Peddler then a Sewing Circle). `setup` (Callable(app)) runs before the fight.
## {"app", "seed", "route", "result"} with the app on the map after the fight, or {} (trial apps freed).
static func lost_fight(test: Object, after: Array = ["Shop", "SewingCircle"], lost := 1, setup := Callable(),
		tries := TRIES) -> Dictionary:
	for candidate in candidates(["Fight"] + after).slice(0, tries):
		var app: Node = await test._new_run(int(candidate[0]))
		var session: StitchedRunSession = app.stitched_run_session
		if session != null and setup.is_valid():
			setup.call(app)
		if session != null and test._press_route(app, str(candidate[1][0])) and app.stitched_run_battle != null:
			var stage: StitchedBattleScreen = app.stitched_run_battle
			for step in range(500):
				if stage.battle.is_over() or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost):
					break
				stage._action_buttons["pass"].pressed.emit()
			var result: Dictionary = test._win(stage)
			if stage.battle.outcome() == "victory" and int(result.acted) > 0:
				stage._action_buttons["exit"].pressed.emit()
				if session.phase == "map" and session.heroes.filter(func(hero: Dictionary): return hero.lost).size() == lost:
					return {"app": app, "seed": candidate[0], "route": candidate[1], "result": result}
		app.free()
		await test.process_frame
	return {}
