extends SceneTree
## Real seeded map -> Walk choice -> visit -> routed battle, plus fail-closed boundaries.

var checks := 0
var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func act(session: StitchedRunSession, kind: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"kind": kind, "actor": session.walk.snapshot().viewpoint}
	command.merge(extra)
	var result := session.walk_act(command, session.snapshot())
	check(result.get("ok") == true, "live Walk accepts " + str(command))
	return result


func step(session: StitchedRunSession) -> Dictionary:
	if session.walk.tug_unresolved():
		return act(session, "tug", {"target": session.walk.snapshot().tug.id, "choice": "yield"})
	return act(session, "forward")


func finish(session: StitchedRunSession) -> Dictionary:
	var last := {}
	for guard in 30:
		if session.phase != "walk":
			break
		last = step(session)
		if not last.get("ok", false):
			break
	check(session.phase in ["visit", "battle"], "Walk reaches its actual destination")
	return last


func roundtrip(session: StitchedRunSession, label: String) -> void:
	var document := StitchedRunSave.capture(session)
	check(not document.is_empty(), label + " captures a consistent run")
	if document.is_empty():
		return
	var restored := StitchedRunSave.restore(bytes_to_var(var_to_bytes(document)))
	check(restored != null, label + " replays successfully")
	if restored != null:
		check(restored.snapshot() == session.snapshot() and restored.journal == session.journal,
			label + " preserves full state, RNG, receipts and journal")
	var forged := document.duplicate(true)
	forged.state.walk.carry.append({"kind": "bleed", "target": "seamstress", "amount": 2})
	forged.digest = StitchedRunSave._digest(forged)
	check(StitchedRunSave.restore(forged) == null, label + " rejects a rehashed forged carry")


func approach(seed_number: int, node_id: String, item: String = "") -> StitchedRunSession:
	var session := StitchedRunSession.start(seed_number)
	check(session != null, "seeded run starts")
	if session == null:
		return null
	# Only protection boundary cases need a supplied pocket fixture; live replay
	# witnesses below start from the unmodified, generated run.
	if not item.is_empty():
		session.pockets.warden = [item]
		session._seal()
	check(session.enable_walks(), "run enables its real Walk route")
	check(session.choices().has(node_id), "witness node is a legal generated map choice")
	check(session.enter(node_id, session.snapshot()), "session enters witness map node")
	check(session.phase == "walk" and session.walk != null, "live session owns a real Walk")
	if session.walk == null:
		return null
	var bag := ragbag(session)
	check(not bag.is_empty(), "generated Walk contains a Ragbag")
	if bag.is_empty():
		return null
	for guard in 20:
		if session.walk.snapshot().step == bag.step:
			return session
		step(session)
	check(false, "Ragbag approach terminates")
	return null


func ragbag(session: StitchedRunSession) -> Dictionary:
	for curio in session.walk.snapshot().curios:
		if curio.id == RunStitchedRagbagBleedEvent.CURIO_ID:
			return curio
	return {}


func bleeds(carries: Array) -> Array:
	return carries.filter(func(effect: Dictionary): return effect.kind == "bleed")


func traps(effects: Array) -> Array:
	return effects.filter(func(effect: Dictionary): return effect.kind == "curio_trap")


func reached(seed_number: int, node_id: String) -> StitchedRunSession:
	var session := approach(seed_number, node_id)
	if session == null:
		return null
	act(session, "curio", {"target": ragbag(session).instance, "choice": "reach"})
	check(traps(session.walk.snapshot().pending).size() == 1, "seed witnesses exactly one real biting trap")
	return session


func battle_ticks(session: StitchedRunSession, target: String) -> void:
	var battle := session.battle
	check(battle != null and battle.is_valid(), "routed battle has real units")
	if battle == null:
		return
	var input := {}
	for hero in session.battle_config.heroes:
		if hero.id == target:
			input = hero
	check(not input.is_empty() and input.statuses == {"bleed": 2}, "matching live hero enters construction with Bleed 2")
	if input.is_empty():
		return
	var unit := battle.get_unit(target)
	check(not unit.is_empty() and unit.prot > 0 and unit.hp > 3, "damage witness is living and has actual PROT")
	var ticks := 1 if battle.current_actor_id() == target else 0
	check(unit.statuses.get("bleed", 0) == 2 - ticks and unit.hp == input.hp - 2 * ticks,
		"visible unit reflects construction and any immediate opening tick")
	for hero in battle.get_heroes():
		if hero.id != target:
			check(not hero.statuses.has("bleed"), "another hero never receives the Ragbag Bleed")
	for guard in 40:
		var hp: int = battle.get_unit(target).hp
		check(session.is_consistent(), "session is consistent before admitted pass")
		check(battle.owner_session.get_ref() == session and session.battle == battle and session.phase == "battle",
			"battle retains its owning live session")
		var result := battle.use_foe_ability(battle.get_unit(StitchedRules.WALK_MIMIC_ID).abilities[0].id, 4) \
			if battle.current_actor_id() == StitchedRules.WALK_MIMIC_ID else battle.pass_turn()
		check(result.get("ok") == true, "real admitted turn advances: " + str(result))
		if result.get("ok") != true:
			break
		if battle.current_actor_id() == target:
			ticks += 1
			var damage := 2 if ticks == 1 else 1 if ticks == 2 else 0
			check(battle.get_unit(target).hp == hp - damage, "canonical turn-start Bleed ignores PROT and decays")
			if ticks == 3:
				break
	check(ticks == 3 and battle.get_unit(target).hp == input.hp - 3
		and not battle.get_unit(target).statuses.has("bleed"), "two ticks total three damage, then no duplicate application")
	roundtrip(session, "after actual turn-start damage")


func live(seed_number: int, first: String, fight: String) -> Dictionary:
	var session := approach(seed_number, first)
	if session == null:
		return {}
	roundtrip(session, "before reach")
	var bag := ragbag(session)
	act(session, "curio", {"target": bag.instance, "choice": "reach"})
	var reached_state := session.walk.snapshot()
	var pending_traps := traps(reached_state.pending)
	check(pending_traps.size() == 1, "unprotected reach witnesses a trap")
	if pending_traps.size() != 1:
		return {}
	check(pending_traps[0].target == "warden" and not pending_traps[0].consumed,
		"authentic pending trap belongs to the reaching doll")
	roundtrip(session, "after reach before settlement")
	var last := finish(session)
	check(session.phase == "visit" and session.pending.node_id == first, "Ragbag Walk reaches its real visit")
	check(bleeds(session.walk_carry) == [{"kind": "bleed", "target": "warden", "amount": 2}],
		"settlement publishes exactly one validated detached carry")
	var saved_pending: Array = session.walk_receipts.back().pending
	var expected_pending: Array = last.snapshot.pending.duplicate(true)
	for effect in expected_pending:
		if effect.kind == "curio_trap" or effect.kind == "machine":
			effect.consumed = true
	check(saved_pending == expected_pending, "saved receipt consumes the trap and preserves all unrelated Walk effects")
	if seed_number == 21:
		check(session.rng.state == last.snapshot.rng, "trap settlement and Sewing Circle consume no extra RNG draws")
	var detached := session.snapshot()
	detached.walk.carry[0].amount = 99
	detached.walk.receipts.back().pending.clear()
	check(bleeds(session.walk_carry)[0].amount == 2 and not session.walk_receipts.back().pending.is_empty(),
		"carry and consumption receipt are detached from exported snapshots")
	roundtrip(session, "carry waiting at visit")
	var carry := session.walk_carry.duplicate(true)
	check(session.choose_visit("leave", [], session.snapshot()), "real visit Leave returns to map")
	check(session.walk_carry == carry, "intervening visit never spends any battle carry")
	roundtrip(session, "carry after visit")
	check(session.choices().has(fight) and session.map.get_node(fight).type in ["Fight", "Elite"],
		"next battle is a legal generated Fight or Elite")
	check(session.enter(fight, session.snapshot()), "next routed battle enters through its own Walk")
	finish(session)
	check(session.phase == "battle" and session.walk_carry.is_empty(), "successful battle consumes carries once")
	roundtrip(session, "live battle arrival")
	battle_ticks(session, "warden")
	return session.snapshot()


func safe_choices() -> void:
	for mode in ["leave", "pins", "dye"]:
		var session := approach(21, "f01_n3", "" if mode == "leave" else mode)
		if session == null:
			continue
		var bag := ragbag(session)
		if mode != "leave":
			act(session, "use_item", {"slot": 0, "target": bag.instance if mode == "pins" else "warden"})
		act(session, "curio", {"target": bag.instance, "choice": "leave" if mode == "leave" else "reach"})
		check(traps(session.walk.snapshot().pending).is_empty(), mode + " creates no trap")
		finish(session)
		check(bleeds(session.walk_carry).is_empty(), mode + " creates no Bleed carry")
		check(session.choose_visit("leave", [], session.snapshot()) and session.enter("f02_n3", session.snapshot()),
			mode + " continues through the real next fight")
		finish(session)
		check(session.battle != null, mode + " opens a real battle")
		if session.battle != null:
			check(session.battle.get_heroes().all(func(hero): return not hero.statuses.has("bleed")),
				mode + " never grants Bleed to a battle unit")


func machine_and_direct() -> void:
	var session := reached(21, "f01_n3")
	if session == null:
		return
	for guard in 20:
		if session.walk.snapshot().whirr == 100:
			break
		act(session, "look_back")
	check(session.walk.snapshot().whirr == 100, "real Walk reaches the Machine threshold alongside a trap")
	finish(session)
	check(bleeds(session.walk_carry).size() == 1 and session.walk_carry.filter(func(e): return e.kind == "machine").size() == 1,
		"claiming Bleed preserves the simultaneous Machine toll")
	check(traps(session.walk_receipts.back().pending)[0].consumed
		and session.walk_receipts.back().pending.filter(func(e): return e.kind == "machine")[0].consumed,
		"saved receipt records both independent claims as consumed")
	roundtrip(session, "Machine and Ragbag receipt")
	var direct := approach(1, "f01_n0")
	if direct == null:
		return
	act(direct, "switch", {"target": "seamstress"})
	act(direct, "curio", {"target": ragbag(direct).instance, "choice": "reach"})
	check(traps(direct.walk.snapshot().pending).size() == 1, "another reaching doll also witnesses a genuine trap")
	finish(direct)
	check(direct.phase == "battle" and direct.battle != null, "Ragbag also routes directly into the current Fight")
	if direct.battle != null:
		for hero in direct.battle_config.heroes:
			check(hero.statuses == ({"bleed": 2} if hero.id == "seamstress" else {}),
				"direct fight applies Bleed only to the actual switched reacher")
	roundtrip(direct, "direct Fight with another reacher")


func invalid_traps() -> void:
	for mode in ["amount", "source", "doll", "wrong_curio", "unresolved", "duplicate", "consumed", "wrong_kind"]:
		var session := reached(21, "f01_n3")
		if session == null:
			continue
		var state: Dictionary = session.walk._state
		var entries := traps(state.pending)
		if entries.size() != 1:
			continue
		var trap: Dictionary = entries[0]
		match mode:
			"amount": trap.effects.amount = 2.5
			"source": trap.source = "not_a_placed_instance"
			"doll": trap.target = "not_a_party_doll"
			"wrong_curio": state.curios[0].id = "pin_nest"
			"unresolved": state.curios[0].resolved = false
			"duplicate": state.pending.append(trap.duplicate(true))
			"consumed": trap.consumed = true
			"wrong_kind": trap.kind = "curio_loot"
		var before := session.snapshot()
		check(not session.is_consistent(), "public session detects " + mode + " tampering")
		check(not session.walk_act({"kind": "forward", "actor": "warden"}, before).ok,
			"public route refuses tampered trap")
		# Settlement now authenticates a genuinely completed Walk (the S8c bridge plan),
		# so complete this Walk at its own boundary before probing settlement with the
		# real settled doll/context data; the public route above is rightly refused.
		for guard in 30:
			if session.walk.snapshot().phase != "walking":
				break
			var actor: String = session.walk.snapshot().viewpoint
			var command := {"kind": "forward", "actor": actor}
			if session.walk.tug_unresolved():
				command = {"kind": "tug", "actor": actor, "target": session.walk.snapshot().tug.id, "choice": "yield"}
			if not session.walk.act(command, session.walk.snapshot()).ok:
				break
		check(session.walk.snapshot().phase == "complete", mode + " probe Walk reaches genuine completion")
		var ok := session._finish_walk()
		check(ok == (mode in ["consumed", "wrong_kind"]), mode + " settlement fails closed or ignores unrelated/consumed effects")
		check(bleeds(session.walk_carry).is_empty(), mode + " never publishes Bleed")


## A seeded visit Walk whose shadow is still unresolved leaves the bridge's
## genuinely validated arrival waiting for the next battle; null when this seed
## has none, so callers search candidates for a witness.
func deferred_arrival(seed_number: int) -> StitchedRunSession:
	var session := StitchedRunSession.start(seed_number)
	if session == null or not session.enable_walks():
		return null
	var pick := ""
	for id in session.choices():
		var node_type: String = session.map.get_node(id).type
		if node_type != "Boss" and not (node_type in ["Fight", "Elite"]):
			pick = id
			break
	if pick.is_empty() or not session.enter(pick, session.snapshot()):
		return null
	if session.phase != "walk" or session.walk == null:
		return null
	for guard in 30:
		if session.phase != "walk":
			break
		var walker := session.walk
		var actor: String = walker.snapshot().viewpoint
		var command := {"kind": "forward", "actor": actor}
		if walker.tug_unresolved():
			command = {"kind": "tug", "actor": actor, "target": walker.snapshot().tug.id, "choice": "yield"}
		if session.walk_act(command, session.snapshot()).get("ok") != true:
			return null
	if session.phase != "visit" or session.walk_arrival.is_empty():
		return null
	return session


func battle_boundary() -> void:
	var session: StitchedRunSession = null
	var seed_number := -1
	for candidate in 32:
		session = deferred_arrival(candidate)
		if session != null:
			seed_number = candidate
			break
	check(session != null, "a genuine deferred arrival witness exists")
	if session == null:
		return
	var kept_arrival := session.walk_arrival.duplicate(true)
	var control := deferred_arrival(seed_number)
	check(control != null and control.snapshot() == session.snapshot(),
		"deferred arrival witness replays deterministically")
	if control == null:
		return
	check(session.choose_visit("leave", [], session.snapshot())
		and control.choose_visit("leave", [], control.snapshot()),
		"both witnesses leave their genuine visits")
	check(session.walk_arrival == kept_arrival, "leaving the visit preserves the deferred arrival")
	var target: String = session.heroes[1].id
	session.heroes[1].statuses = {"bleed": 5}
	session.walk_carry = [{"kind": "bleed", "target": target, "amount": 2},
		{"kind": "fray", "target": target, "amount": 15}]
	control.heroes[1].statuses = {"bleed": 5}
	control.walk_carry = session.walk_carry.slice(1).duplicate(true)
	check(session._open_battle("Fight") and control._open_battle("Fight"), "carry and RNG control battles construct")
	check(session.battle_config.heroes[1].statuses.bleed == 5, "max merge preserves stronger existing Bleed")
	check(session.battle.state_snapshot() == control.battle.state_snapshot() and session.rng.state == control.rng.state,
		"Bleed merge adds no RNG draws and preserves mimic/fray carries")
	check(session.walk_carry.is_empty() and session.walk_arrival.is_empty(),
		"successful setup spends carry and arrival")
	session.heroes[1].statuses.clear()
	check(session._open_battle("Elite") and session.battle_config.heroes[1].statuses.is_empty()
		and session.battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty(),
		"another battle cannot reuse the spent trap or arrival")
	for carry in [{"kind": "bleed", "target": target, "amount": 2.0},
			{"kind": "bleed", "target": target, "amount": 0},
			{"kind": "bleed", "target": target, "amount": -2},
			{"kind": "bleed", "target": "missing", "amount": 2}]:
		var invalid := deferred_arrival(seed_number)
		if invalid == null:
			check(false, "invalid carry witness constructs")
			continue
		check(invalid.choose_visit("leave", [], invalid.snapshot()), "invalid carry witness leaves its visit")
		invalid.walk_carry = [carry.duplicate(true)]
		var before := invalid.walk_carry.duplicate(true)
		var arrival := invalid.walk_arrival.duplicate(true)
		check(not invalid._open_battle("Fight") and invalid.battle == null and invalid.walk_carry == before
			and invalid.walk_arrival == arrival,
			"invalid carry refuses setup without spending any carry or arrival")
	var failed := deferred_arrival(seed_number)
	check(failed != null, "failed setup witness constructs")
	if failed == null:
		return
	check(failed.choose_visit("leave", [], failed.snapshot()), "failed setup witness leaves its visit")
	failed.walk_carry = [{"kind": "bleed", "target": "warden", "amount": 2}]
	var pending_arrival := failed.walk_arrival.duplicate(true)
	failed.heroes[2].parts.clear()
	check(not failed._open_battle("Fight") and failed.battle == null and failed.walk_carry.size() == 1
		and failed.walk_arrival == pending_arrival,
		"battle construction failure retains the validated Bleed carry and arrival")


func _init() -> void:
	var first := live(21, "f01_n3", "f02_n3")
	check(not first.is_empty() and first == live(21, "f01_n3", "f02_n3"), "independent seeded live replay matches exactly")
	check(not live(45, "f01_n1", "f02_n1").is_empty(), "real Elite route exercises the same carry")
	safe_choices()
	machine_and_direct()
	invalid_traps()
	battle_boundary()
	if failures.is_empty():
		print("stitched_s8f_live_ragbag_bleed_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s8f_live_ragbag_bleed_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
