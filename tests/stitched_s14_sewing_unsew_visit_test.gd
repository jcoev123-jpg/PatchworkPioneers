extends SceneTree
## S14: a real, seeded Sewing Circle visit offers the free "unsew" choice for every owned effect
## patch sewn onto a living doll's signature, and choose_visit releases exactly that binding.

const HERO := "warden"
const ABILITY := "warden_arms_shield_catch"

var failures: Array[String] = []
var checks := 0
var _changed_count := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	var found := _find_circle()
	_check(not found.is_empty(), "bounded seed search finds a real accessible Sewing Circle")
	if not found.is_empty():
		_main_flow(int(found.seed), str(found.circle))
		_resew_flow(int(found.seed), str(found.circle))
		_lost_flow(int(found.seed), str(found.circle))
		_other_stop_flow()
	for message in failures:
		printerr(message)
	print("stitched_s14_sewing_unsew_visit_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _find_circle() -> Dictionary:
	for seed_number in 200:
		var candidate := StitchedRunSession.start(seed_number)
		if candidate == null:
			continue
		for id in candidate.choices():
			if candidate.map.get_node(id).type == "SewingCircle":
				return {"seed": seed_number, "circle": id}
	return {}


## Enter the real Sewing Circle stop of that seed.
func _enter(seed_number: int, circle_id: String) -> StitchedRunSession:
	var run := StitchedRunSession.start(seed_number)
	if run == null or not run.enter(circle_id, run.snapshot()) or run.phase != "visit" \
			or str(run.pending.get("service", "")) != "SewingCircle":
		return null
	return run


## Test-only ownership and wallet fixture (the same authentic award the S14 gate uses).
func _fixture(run: StitchedRunSession) -> Dictionary:
	var gold: Dictionary = run._award_ability_patch("elite", "gold")
	var wool: Dictionary = run._award_ability_patch("elite", "wool")
	run.scraps = 6
	run._open_visit("SewingCircle")
	run._seal()
	return {"gold": gold, "wool": wool}


func _sew_both(run: StitchedRunSession, items: Dictionary) -> bool:
	return run.socket_ability(int(items.gold.uid), HERO, ABILITY, 0, run.snapshot()) \
		and run.socket_ability(int(items.wool.uid), HERO, ABILITY, 0, run.snapshot())


func _unsew_actions(run: StitchedRunSession) -> Array:
	return run.visit_actions().filter(func(action: Dictionary) -> bool: return action.id == "unsew")


func _unsew_args(run: StitchedRunSession) -> Array:
	var args: Array = []
	for action in _unsew_actions(run):
		args.append(action.arguments)
	return args


func _other_ability() -> String:
	for slot in StitchedS14Abilities.kits()[HERO]:
		var entry: Dictionary = StitchedS14Abilities.kits()[HERO][slot]
		if str(entry.id) != ABILITY:
			return str(entry.id)
	return ""


func _on_changed() -> void:
	_changed_count += 1


## Everything except the sockets (and the visit's own step log) must be equal.
func _only_sockets_changed(before: Dictionary, after: Dictionary) -> bool:
	for key in before:
		if key in ["pending", "s14"]:
			continue
		if before[key] != after.get(key):
			return false
	for key in before.s14:
		if key != "sockets" and before.s14[key] != after.s14.get(key):
			return false
	return before.s14.sockets != after.s14.sockets


func _refused(run: StitchedRunSession, action: String, args: Array, expected: Dictionary, label: String) -> void:
	var snapshot := run.snapshot()
	var rng_before := run.rng.state
	var journal_before := run.journal.size()
	var steps_before: int = run.pending.get("steps", []).size()
	var result := run.choose_visit(action, args, expected)
	_check(not result and run.snapshot() == snapshot and run.rng.state == rng_before \
		and run.journal.size() == journal_before \
		and run.pending.get("steps", []).size() == steps_before, label)


func _main_flow(seed_number: int, circle_id: String) -> void:
	var run := _enter(seed_number, circle_id)
	_check(run != null, "real Sewing Circle is entered through enter()")
	if run == null:
		return
	# Nothing is sewn yet, so no unsew choice is advertised.
	_check(_unsew_actions(run).is_empty(), "no unsew choice without a socketed patch")
	var items := _fixture(run)
	_check(not items.gold.is_empty() and not items.wool.is_empty(), "authentic gold and wool patches are owned")
	_check(_sew_both(run, items), "paid socket path sews both patches onto the Warden signature")
	var gold_uid := int(items.gold.uid)
	var wool_uid := int(items.wool.uid)
	_check(run.ability_sockets.get(HERO, {}).get(ABILITY, []) == [gold_uid, wool_uid],
		"precondition: both owned patches are bound to the signature")
	# AC1: one concise unsew row per socketed uid, alongside the existing actions.
	var actions := run.visit_actions()
	_check(_unsew_args(run) == [[HERO, ABILITY, gold_uid], [HERO, ABILITY, wool_uid]],
		"visit offers exactly one unsew row per bound uid with [hero, ability, uid]")
	_check(_unsew_actions(run).all(func(action: Dictionary) -> bool: return action.enabled == true \
		and not str(action.text).is_empty()), "unsew rows are enabled and labelled")
	_check(actions.size() > 0 and actions.back().id == "leave", "free Leave still closes the offered list")
	_check(actions.any(func(action: Dictionary) -> bool: return action.id == "upgrade"),
		"existing paid Upgrade rows are still offered")

	# AC3: refusals leave everything identical.
	var live := run.snapshot()
	var other := _other_ability()
	_check(not other.is_empty(), "the Warden has another authored signature")
	_refused(run, "unsew", [HERO, ABILITY, 9999], live, "unowned uid is refused")
	_refused(run, "unsew", ["seamstress", ABILITY, gold_uid], live, "wrong hero is refused")
	_refused(run, "unsew", [HERO, other, gold_uid], live, "wrong ability is refused")
	_refused(run, "unsew", [HERO, ABILITY, float(gold_uid)], live, "float uid is refused")
	_refused(run, "unsew", [HERO, ABILITY], live, "short arguments are refused")
	_refused(run, "unsew", [HERO, ABILITY, str(gold_uid)], live, "string uid is refused")
	var forged := live.duplicate(true)
	forged["scraps"] = int(forged.scraps) + 5
	_refused(run, "unsew", [HERO, ABILITY, gold_uid], forged, "forged snapshot is refused")

	# AC2: the real choose_visit path.
	_changed_count = 0
	run.changed.connect(_on_changed)
	var before := run.snapshot()
	var inventory_before := JSON.stringify(run.ability_inventory, "", true)
	var rng_before := run.rng.state
	var journal_before := run.journal.size()
	var steps_before: int = run.pending.steps.size()
	var gold_item: Dictionary = items.gold.duplicate(true)
	_check(run.choose_visit("unsew", [HERO, ABILITY, gold_uid], before), "presently offered unsew is accepted")
	var after := run.snapshot()
	_check(run.phase == "visit" and str(run.pending.get("service", "")) == "SewingCircle" \
		and run.pending.node_id == circle_id, "the Sewing Circle visit stays open")
	_check(run.ability_sockets.get(HERO, {}).get(ABILITY, []) == [wool_uid],
		"exactly that one binding is released")
	_check(JSON.stringify(run.ability_inventory, "", true) == inventory_before \
		and run.ability_inventory.has(gold_item), "the same {uid,id,rarity} patch stays owned byte for byte")
	_check(_only_sockets_changed(before, after), "no gold, scraps, HP, parts, candle, fear, satchel or serial moved")
	_check(run.rng.state == rng_before, "the run RNG draws nothing")
	_check(run.scraps == int(before.scraps) and run.gold == int(before.gold), "no scraps or gold are charged")
	_check(run.journal.size() == journal_before + 1 and run.journal.back() == {"action": "visit", "id": "unsew",
		"arguments": [HERO, ABILITY, gold_uid]}, "one actual unsew command is journaled")
	_check(run.pending.steps.size() == steps_before + 1 and run.pending.steps.back().action == "unsew" \
		and run.pending.steps.back().arguments == [HERO, ABILITY, gold_uid], "one pending step is recorded")
	_check(_changed_count == 1, "the standard changed signal is emitted once")
	_check(run.is_consistent(), "the run is resealed")
	_check(_unsew_args(run) == [[HERO, ABILITY, wool_uid]] and run.visit_actions().back().id == "leave",
		"the refreshed visit offers only the remaining binding")
	_check(run._battle_sockets()[HERO][ABILITY] == [str(items.wool.id)],
		"the next battle loadout uses the remaining binding")

	# AC3: stale and replayed submissions.
	var current := run.snapshot()
	_refused(run, "unsew", [HERO, ABILITY, gold_uid], before, "stale snapshot is refused")
	_refused(run, "unsew", [HERO, ABILITY, gold_uid], current, "already-unsewn replay is refused")

	# The released patch is still owned and can be sewn again (the paid path, unchanged).
	var scraps_before_resew := run.scraps
	_check(run.socket_ability(gold_uid, HERO, ABILITY, 0, run.snapshot()) \
		and run.scraps == scraps_before_resew - StitchedRunSession.SEWING_COST,
		"the unsewn patch can be re-sewn through the paid socket path")
	_check(run.choose_visit("unsew", [HERO, ABILITY, gold_uid], run.snapshot()),
		"the re-sewn patch is offered and released again")

	# Second choice at the same visit.
	_check(run.choose_visit("unsew", [HERO, ABILITY, wool_uid], run.snapshot()), "a second unsew is accepted")
	_check(run.ability_sockets.get(HERO, {}).get(ABILITY, []).is_empty() and _unsew_actions(run).is_empty() \
		and run.ability_inventory.size() == 2 and run.phase == "visit",
		"after the last binding the visit offers no unsew and keeps both patches")
	_check(run._battle_sockets()[HERO][ABILITY].is_empty(), "the next battle loadout has no effect patch left")

	# Save/replay: the owned fixture is not a journaled event, so replay the journal into a
	# detached candidate that receives the same fixture at the same point.
	var saved := StitchedRunSave.capture(run)
	_check(not saved.is_empty() and saved.journal == run.journal and saved.state == run.snapshot() \
		and saved.digest == StitchedRunSave._digest(saved), "capture holds the journal and the exact state")
	var inventory_saved: Array = saved.state.s14.inventory
	_check(inventory_saved.has(gold_item) and inventory_saved.size() == 2, "the saved state keeps the unsewn patch owned")
	var clone := StitchedRunSession.start(run.seed_value, run.picks, run._initial, true)
	var replayed := clone != null
	if replayed:
		for index in run.journal.size():
			if not StitchedRunSave._replay(clone, run.journal[index]):
				replayed = false
				break
			if index == 0:
				_fixture(clone)
	_check(replayed and clone.snapshot() == run.snapshot() and clone.journal == run.journal \
		and clone.rng.state == run.rng.state, "journal replay reproduces sockets, inventory, history and RNG")

	# AC3: a closed visit refuses.
	_check(run.choose_visit("leave", [], run.snapshot()) and run.phase == "map", "free Leave closes the visit")
	_refused(run, "unsew", [HERO, ABILITY, gold_uid], run.snapshot(), "closed visit refuses unsew")
	_check(run.visit_actions().is_empty(), "a closed visit offers nothing")
	run.changed.disconnect(_on_changed)


## The released patch goes back on through the unchanged paid path to the same signature.
func _resew_flow(seed_number: int, circle_id: String) -> void:
	var run := _enter(seed_number, circle_id)
	if run == null:
		_check(false, "second Sewing Circle fixture enters")
		return
	var items := _fixture(run)
	_check(_sew_both(run, items), "resew fixture sews both patches")
	_check(run.choose_visit("unsew", [HERO, ABILITY, int(items.gold.uid)], run.snapshot()), "gold patch is released")
	_check(run.socket_ability(int(items.gold.uid), HERO, ABILITY, 0, run.snapshot()) \
		and run.ability_sockets[HERO][ABILITY] == [int(items.wool.uid), int(items.gold.uid)],
		"the released gold patch sews back onto the signature")


## A LOST doll's patch gets no unsew choice, and a forged one is refused.
func _lost_flow(seed_number: int, circle_id: String) -> void:
	var run := _enter(seed_number, circle_id)
	if run == null:
		_check(false, "LOST fixture Sewing Circle enters")
		return
	var items := _fixture(run)
	_check(_sew_both(run, items) and _unsew_actions(run).size() == 2, "LOST fixture starts with offered unsews")
	for hero in run.heroes:
		if hero.id == HERO:
			hero.hp = 0
			hero.hanging = false
			hero.lost = true
			hero.parts = {}
	_check(run._open_visit("SewingCircle"), "the visit reopens with a LOST doll")
	run._seal()
	_check(_unsew_actions(run).is_empty(), "no unsew choice is offered for a LOST doll")
	_refused(run, "unsew", [HERO, ABILITY, int(items.gold.uid)], run.snapshot(), "forged unsew for a LOST doll is refused")


## An unsew submitted at any other stop, or off the map, is refused.
func _other_stop_flow() -> void:
	for seed_number in 200:
		var run := StitchedRunSession.start(seed_number)
		if run == null:
			continue
		var stop_id := ""
		for id in run.choices():
			if run.map.get_node(id).type in ["Rest", "Shop"]:
				stop_id = id
				break
		if stop_id.is_empty():
			continue
		_refused(run, "unsew", [HERO, ABILITY, 1], run.snapshot(), "unsew on the map is refused")
		if not run.enter(stop_id, run.snapshot()) or run.phase != "visit":
			continue
		var gold: Dictionary = run._award_ability_patch("elite", "gold")
		run.ability_sockets = {HERO: {ABILITY: [int(gold.uid)]}}
		run._seal()
		_check(_unsew_actions(run).is_empty(), "another stop offers no unsew")
		_refused(run, "unsew", [HERO, ABILITY, int(gold.uid)], run.snapshot(), "unsew at another stop is refused")
		return
	_check(false, "bounded seed search finds a Campfire or Peddler stop")
