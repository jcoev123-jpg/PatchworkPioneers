extends SceneTree

const Bridge = preload("res://scripts/stitched/walk/stitched_walk_mimic_battle.gd")
const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var checks := 0
var failures: Array[String] = []
var config: Dictionary
var dolls: Array = []
var pockets: Dictionary = {}


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stitched/s2_preview.json"))
	var base := StitchedRules.create(config)
	_check(base.ok and base.battle != null, "authentic Stitched preview combat validates")
	if not base.ok:
		quit(1)
		return
	for hero in base.battle.get_heroes():
		dolls.append({"id": hero.id, "rank": hero.rank, "hp": hero.max_hp,
			"max_hp": hero.max_hp, "fray": 7, "lost": false})
		pockets[hero.id] = ["starch"]
	var present_seed := -1
	var absent_seed := -1
	for seed_number in 32:
		var walk := _start(seed_number)
		_check(walk != null, "real seeded Walk starts")
		if walk.snapshot().shadow.present:
			present_seed = seed_number
		else:
			absent_seed = seed_number
	_check(present_seed >= 0 and absent_seed >= 0, "non-vacuous present and absent witnesses")
	if present_seed >= 0 and absent_seed >= 0:
		for outcome in ["unresolved", "correct", "wrong2", "wrong3", "wrong4", "absent"]:
			var seed_number := absent_seed if outcome == "absent" else present_seed
			var first := _outcome(seed_number, outcome)
			_check(first == _outcome(seed_number, outcome), "entire battle/Walk/receipt replay: " + outcome)
		_negatives(present_seed)
		_thresholds(present_seed)
	_routed()
	_commit_gates()
	_forged_arrival()
	_double_cut()
	_ordinary_gates()
	for failure in failures:
		printerr(failure)
	print("stitched_s8c_mimic_battle_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _start(seed_number: int) -> StitchedWalkRules:
	var random := RandomNumberGenerator.new()
	random.seed = seed_number
	return Walk.start(random, "walls", dolls, pockets, null, true)


func _act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> void:
	var command := {"kind": kind, "actor": walk.snapshot().viewpoint}
	command.merge(extra)
	_check(walk.act(command, walk.snapshot()).ok, "real Walk action " + kind)


func _complete(walk: StitchedWalkRules, outcome: String) -> void:
	if outcome == "correct" or outcome.begins_with("wrong"):
		while walk.snapshot().step < walk.snapshot().shadow.step:
			_act(walk, "forward")
		_act(walk, "look_back")
		_check(walk.shadow_visible(), "SNIP witness sees a real shadow")
		var target := "extra_thread_shadow"
		if outcome.begins_with("wrong"):
			target = dolls[int(outcome.right(1)) - 1].id
		_act(walk, "snip", {"target": target})
	while walk.snapshot().phase == "walking":
		_act(walk, "forward")


func _outcome(seed_number: int, outcome: String) -> Array:
	var walk := _start(seed_number)
	_complete(walk, outcome)
	var completed := walk.snapshot()
	var input := config.duplicate(true)
	var result := Bridge.create(walk, completed, input)
	_check(result.ok and result.battle != null, "completed Walk creates genuine combat: " + outcome)
	_check(input == config, "bridge never mutates caller's combat input")
	if not result.ok:
		return []
	var battle: StitchedRules = result.battle
	var control_rng := RandomNumberGenerator.new()
	control_rng.state = completed.rng
	var control_input := config.duplicate(true)
	control_input.run_rng = control_rng
	var control := StitchedRules.create(control_input)
	_check(control.ok and battle.rng_state() == control_rng.state,
		"creation continues exact run RNG state; special intruder takes no ordinary initiative draw")
	var trace: Array = [battle.state_snapshot()]
	var ambush := outcome != "correct" and outcome != "absent"
	_check(battle.get_foes().size() == config.foes.size() + (1 if ambush else 0), "only unresolved shadow adds the special intruder")
	for doll in completed.dolls:
		_check(battle.get_unit(doll.id).fray == doll.fray, "carry fray without paying wrong SNIP twice")
	for effect in walk.snapshot().pending:
		_check(effect.consumed, "mimic/cut descriptors consumed on successful creation")
	if ambush:
		_check(battle.round_number() == 1 and battle.current_actor_id() == StitchedRules.WALK_MIMIC_ID,
			"ambush is the special first-round first actor even with bright opening strikes")
		var before := battle.state_snapshot()
		_check(not battle.pass_turn().ok and not battle.snip_thread(dolls[0].id).ok, "intruder cannot substitute a pass or SNIP")
		_check(not battle.use_foe_ability("rag_rake", 1).ok, "intruder refuses a front-rank target")
		_check(not battle.use_foe_ability("forged", 4).ok, "intruder refuses a forged ability")
		_check(battle.state_snapshot() == before, "invalid intruder actions spend no RNG or turn")
		var attack := battle.use_foe_ability("rag_rake", 4)
		_check(attack.ok and attack.fled and attack.results.size() == 1 and attack.target == dolls[3].id,
			"one actual foe attack against the back-rank doll then automatic flee")
		_check(attack.results[0].has("roll"), "attack actually exercised the seeded hit resolver")
		_check(battle.get_unit(dolls[3].id).hp == completed.dolls[3].hp - attack.results[0].damage,
			"ambush damage is applied to the actual back-rank doll")
		trace.append(attack)
		_check(battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty() and battle.get_foes().size() == config.foes.size(), "intruder fully removed from foes and reward input")
		_check(battle.get_heaps().is_empty() and battle.satchel().is_empty(), "no ambush heap or part drop")
	else:
		_check(battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty(), "correct/absent shadow has no ambush")
	var cut_id := ""
	if outcome.begins_with("wrong"):
		var rank := int(outcome.right(1))
		cut_id = dolls[rank - 1].id
		_check(completed.dolls[rank - 1].fray == 27, "real wrong SNIP added exactly twenty fray once")
		_check(battle.thread_cuts() == {cut_id: rank}, "transfer exact cut boundary, including rank four")
	var tied := false
	for step in 40:
		if battle.round_number() >= 3:
			break
		_check(battle.current_actor_id() != StitchedRules.WALK_MIMIC_ID, "intruder never gets a later turn")
		if battle.current_actor_id() == cut_id and not tied:
			var before := battle.state_snapshot()
			_check(not battle.move(-1).ok and battle.state_snapshot() == before, "cut doll cannot move before RE-TIE")
			var receipt := battle.re_tie()
			_check(receipt.ok and battle.thread_cuts().is_empty(), "public RE-TIE clears transferred cut")
			trace.append(receipt)
			tied = true
		else:
			trace.append(battle.pass_turn())
	_check(battle.round_number() >= 3, "actually exercised subsequent combat rounds")
	_check(cut_id.is_empty() or tied, "wrong-SNIP doll actually took and used RE-TIE turn")
	_check(battle.get_heaps().is_empty() and battle.satchel().is_empty(), "still no intruder heap/drop after later rounds")
	var before_duplicate := battle.state_snapshot()
	_reject(walk, completed, config)
	_reject(walk, walk.snapshot(), config)
	_check(battle.state_snapshot() == before_duplicate, "duplicate creation preserves existing battle and shared RNG")
	trace.append(battle.state_snapshot())
	trace.append(walk.snapshot())
	return trace


func _reject(walk: StitchedWalkRules, expected: Dictionary, input: Dictionary) -> void:
	var before := walk.snapshot()
	var rng_before := walk._rng.state
	var caller := input.duplicate(true)
	var result := Bridge.create(walk, expected, input)
	_check(not result.ok and result.battle == null and not result.error.is_empty(), "invalid bridge request fails closed")
	_check(before == walk.snapshot() and walk._rng.state == rng_before and input == caller,
		"rejection preserves Walk, descriptors, RNG, and caller inputs")


func _negatives(seed_number: int) -> void:
	var walk := _start(seed_number)
	var stale := walk.snapshot()
	_reject(walk, stale, config)
	_complete(walk, "wrong4")
	_reject(walk, stale, config)
	var forged := walk.snapshot()
	forged.pending.clear()
	_reject(walk, forged, config)
	_check(not Bridge.create(walk.snapshot(), walk.snapshot(), config).ok, "pending snapshot cannot impersonate Walk object")
	_check(not Bridge.create(Walk.new(), {}, config).ok, "unstarted Walk rejected")
	_check(not Bridge.create(null, {}, config).ok, "null Walk rejected")
	for kind in ["four_foes", "part", "seed", "ids", "vitality", "walk_mimic", "walk_cuts", "walk_vitality", "run_rng"]:
		var invalid := config.duplicate(true)
		match kind:
			"four_foes": invalid.foes.append(invalid.foes[0].duplicate(true))
			"part": invalid.heroes[0].parts.head = "forged_part"
			"seed": invalid.seed = "forged"
			"ids": invalid.heroes.reverse()
			"vitality": invalid.heroes[0].max_hp += 1
			_: invalid[kind] = true
		_reject(walk, walk.snapshot(), invalid)
	var rng_before := walk._rng.state
	walk._rng.randi()
	_reject(walk, walk.snapshot(), config)
	walk._rng.state = rng_before
	_check(Bridge.create(walk, walk.snapshot(), config).ok, "valid retry succeeds after every rejected request")
	var with_item := _start(seed_number)
	_act(with_item, "use_item", {"slot": 0, "target": dolls[0].id})
	_complete(with_item, "unresolved")
	_check(Bridge.create(with_item, with_item.snapshot(), config).ok, "other deferred effects do not prevent mimic handoff")
	var effects: Array = with_item.snapshot().pending
	_check(effects.filter(func(effect): return effect.kind == "starch" and not effect.consumed).size() == 1,
		"handoff preserves unrelated pending item effect unconsumed for its own feature")


func _ordinary_gates() -> void:
	var invalid := config.duplicate(true)
	invalid.foes.append(invalid.foes[0].duplicate(true))
	_check(not StitchedRules.create(invalid).ok, "ordinary four-foe start still rejected")
	invalid.walk_mimic = true
	_check(not StitchedRules.create(invalid).ok, "mimic opt-in never legalizes four ordinary foes")
	invalid = config.duplicate(true)
	invalid.walk_mimic = "forged"
	_check(not StitchedRules.create(invalid).ok, "malformed intruder opt-in rejected")
	invalid = config.duplicate(true)
	invalid.walk_cuts = {"forged": 4}
	_check(not StitchedRules.create(invalid).ok, "forged combat cut rejected")


func _thresholds(seed_number: int) -> void:
	for starting_fray in [90, 190]:
		var replay: Array = []
		for repeat in 2:
			var party := dolls.duplicate(true)
			party[1].fray = starting_fray
			party[1].resolve = "bitter" if starting_fray == 190 else ""
			var random := RandomNumberGenerator.new()
			random.seed = seed_number
			var walk := Walk.start(random, "walls", party, pockets, null, true)
			_complete(walk, "wrong2")
			_check(walk.snapshot().dolls[1].fray == starting_fray + 20, "Walk has already paid the threshold-crossing SNIP")
			var dark := config.duplicate(true)
			dark.candle = 0
			var result := Bridge.create(walk, walk.snapshot(), dark)
			_check(result.ok and result.battle != null, "threshold-crossing wrong SNIP enters authentic combat")
			if not result.ok:
				continue
			var hero: Dictionary = result.battle.get_unit(dolls[1].id)
			if starting_fray == 90:
				_check((hero.fray == 110 and not hero.resolve.is_empty()) or (hero.fray == 45 and hero.resolve == "steadfast"),
					"settle one seeded resolve at exactly paid +20; SNUFFED never multiplies it again")
			else:
				_check(hero.fray == 150 and hero.hp == 0 and hero.hanging, "fray cap settles one Hanging transition")
			_check(result.battle.thread_cuts().get(dolls[1].id) == 2, "threshold settlement keeps the real cut")
			var snapshot: Dictionary = result.battle.state_snapshot()
			if repeat == 0:
				replay = [snapshot, walk.snapshot()]
			else:
				_check(replay == [snapshot, walk.snapshot()], "threshold transitions replay with the run RNG")


## The bridge's single live entry point: a genuinely completed routed Walk opens its
## Fight/Elite through the session, with the authenticated arrival and no flag-only path.
func _routed() -> void:
	var present_seed := -1
	var absent_seed := -1
	for seed_number in 32:
		var session := _routed_session(seed_number)
		if session == null:
			continue
		if bool(session.walk.snapshot().shadow.get("present", false)):
			present_seed = seed_number
		else:
			absent_seed = seed_number
		if present_seed >= 0 and absent_seed >= 0:
			break
	_check(present_seed >= 0 and absent_seed >= 0, "routed present and absent shadow witnesses exist")
	if present_seed < 0 or absent_seed < 0:
		return
	for outcome in ["unresolved", "correct", "wrong", "absent"]:
		var seed_number := absent_seed if outcome == "absent" else present_seed
		var first := _route_battle(seed_number, outcome)
		_check(first == _route_battle(seed_number, outcome), "entire routed session/battle/save replay: " + outcome)


## A fresh session standing at the start of a routed Fight/Elite Walk, or null.
func _routed_session(seed_number: int) -> StitchedRunSession:
	var session := StitchedRunSession.start(seed_number)
	if session == null or not session.enable_walks():
		return null
	var pick := ""
	for id in session.choices():
		if session.map.get_node(id).type in ["Fight", "Elite"]:
			pick = id
			break
	if pick.is_empty() or not session.enter(pick, session.snapshot()):
		return null
	if session.phase != "walk" or session.walk == null or not session.walk.snapshot().has("shadow"):
		return null
	return session


func _routed_step(session: StitchedRunSession) -> Dictionary:
	var actor: String = session.walk.snapshot().viewpoint
	var command := {"kind": "forward", "actor": actor}
	if session.walk.tug_unresolved():
		command = {"kind": "tug", "actor": actor, "target": session.walk.snapshot().tug.id, "choice": "yield"}
	return session.walk_act(command, session.snapshot())


func _route_battle(seed_number: int, outcome: String) -> Array:
	var session := _routed_session(seed_number)
	_check(session != null, "routed Fight/Elite Walk starts: " + outcome)
	if session == null:
		return []
	# Mid-Walk: a save replays exactly and forged or stale commands spend nothing.
	var mid := session.snapshot()
	var document := StitchedRunSave.capture(session)
	var restored := StitchedRunSave.restore(bytes_to_var(var_to_bytes(document)))
	_check(not document.is_empty() and restored != null and restored.snapshot() == mid,
		"mid-Walk save replays the routed Walk exactly: " + outcome)
	if restored != null and restored.phase == "walk" \
			and session.walk.snapshot().step < int(session.walk.snapshot().shadow.step):
		var mine := _routed_step(session)
		var theirs := _routed_step(restored)
		_check(mine.get("ok") == true and theirs.get("ok") == true and restored.snapshot() == session.snapshot(),
			"the restored mid-Walk continues the same seeded path: " + outcome)
	var pure := session.snapshot()
	var pure_rng := session.rng.state
	var stale := pure.duplicate(true)
	stale.candle += 1
	_check(not session.walk_act({"kind": "forward", "actor": session.walk.snapshot().viewpoint}, stale).ok,
		"a stale snapshot cannot move the routed Walk: " + outcome)
	_check(not session.walk_act({"kind": "snip", "actor": session.walk.snapshot().viewpoint,
		"target": "forged_doll"}, pure).ok, "a forged SNIP cannot spend the routed Walk: " + outcome)
	_check(session.snapshot() == pure and session.rng.state == pure_rng,
		"routed refusals leave the Walk, its descriptors and the RNG pure: " + outcome)
	if outcome != "absent":
		while session.phase == "walk" and session.walk.snapshot().step < int(session.walk.snapshot().shadow.step):
			var receipt := _routed_step(session)
			_check(receipt.get("ok") == true, "routed forward step: " + outcome)
			if receipt.get("ok") != true:
				return []
		if session.phase != "walk":
			_check(false, "the routed Walk reaches its shadow step: " + outcome)
			return []
		var look := session.walk_act({"kind": "look_back", "actor": session.walk.snapshot().viewpoint}, session.snapshot())
		_check(look.get("ok") == true and session.walk.shadow_visible(),
			"the routed SNIP witness sees the real shadow: " + outcome)
		if look.get("ok") != true:
			return []
		if outcome != "unresolved":
			var snip_target := "extra_thread_shadow"
			if outcome == "wrong":
				snip_target = session.heroes[1].id
			var snip := session.walk_act({"kind": "snip", "actor": session.walk.snapshot().viewpoint,
				"target": snip_target}, session.snapshot())
			_check(snip.get("ok") == true, "routed SNIP lands: " + outcome)
			if snip.get("ok") != true:
				return []
	var completed := {}
	while session.phase == "walk":
		var receipt := _routed_step(session)
		_check(receipt.get("ok") == true, "routed completing step: " + outcome)
		if receipt.get("ok") != true:
			return []
		var walked: Dictionary = receipt.get("snapshot", {})
		if walked.get("phase") == "complete":
			completed = walked
	if completed.is_empty() or session.phase != "battle" or session.battle == null:
		_check(false, "the genuinely completed routed Walk opens its Fight/Elite through the bridge: " + outcome)
		return []
	var battle = session.battle
	var ambush := outcome == "unresolved" or outcome == "wrong"
	_check(session.walk == null and session.walk_arrival.is_empty(),
		"one routed battle spends the bridge plan exactly once: " + outcome)
	_check(battle.owner_session.get_ref() == session, "the routed battle is run-owned: " + outcome)
	_check(battle.rng_state() == session.rng.state,
		"the routed battle continues the run's single RNG: " + outcome)
	var ordinary := battle.get_foes().filter(func(foe: Dictionary): return foe.id != StitchedRules.WALK_MIMIC_ID)
	_check(ordinary.size() in [2, 3] and battle.get_foes().size() == ordinary.size() + (1 if ambush else 0),
		"only the unresolved shadow adds the special intruder: " + outcome)
	var machine := int(completed.whirr) >= 100
	for doll in completed.dolls:
		var unit: Dictionary = battle.get_unit(doll.id)
		_check(not unit.is_empty() and int(unit.fray) >= int(doll.fray) and (machine or int(unit.fray) == int(doll.fray)),
			"the Walk's already-paid fray carries without paying a wrong SNIP twice: " + outcome)
	_check(session.journal.any(func(entry): return entry is Dictionary and entry.get("action") == "walk"),
		"the routed Walk records its commands in the run journal: " + outcome)
	var trace: Array = [battle.state_snapshot()]
	if ambush:
		_check(battle.round_number() == 1 and battle.current_actor_id() == StitchedRules.WALK_MIMIC_ID,
			"the routed intruder is the first-round first actor: " + outcome)
		var pristine := battle.state_snapshot()
		_check(not battle.pass_turn().ok and battle.state_snapshot() == pristine,
			"the routed intruder cannot substitute a pass: " + outcome)
		_check(not battle.use_foe_ability("rag_rake", 1).ok,
			"the routed intruder refuses a front-rank target: " + outcome)
		var living := battle.get_heroes().filter(func(hero: Dictionary): return not hero.lost)
		living.sort_custom(func(a: Dictionary, b: Dictionary): return a.rank < b.rank)
		var back: Dictionary = living.back()
		var back_id := str(back.id)
		var back_hp := int(back.hp)
		var attack := battle.use_foe_ability("rag_rake", int(back.rank))
		_check(attack.ok and attack.fled and attack.results.size() == 1 and str(attack.target) == back_id,
			"one actual back-rank ambush hit then automatic flee: " + outcome)
		if attack.ok:
			_check(int(battle.get_unit(back_id).hp) == back_hp - int(attack.results[0].damage),
				"the routed ambush damage lands on the actual back-rank doll: " + outcome)
			trace.append(attack)
		_check(battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty() and battle.get_heaps().is_empty(),
			"the routed intruder leaves no unit, heap or drop: " + outcome)
		var ambush_journal := session.journal.any(func(entry): return entry is Dictionary \
			and entry.get("action") == "battle" and entry.get("method") == "use_foe_ability")
		_check(ambush_journal, "the ambush records its command in the run journal: " + outcome)
	else:
		_check(battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty(),
			"a correct or absent shadow gives no ambush: " + outcome)
	var cut_id := ""
	if outcome == "wrong":
		cut_id = session.heroes[1].id
		_check(battle.thread_cuts() == {cut_id: 2}, "the wrong SNIP's paid cut carries exactly: " + outcome)
	var tied := false
	for step in 40:
		if battle.round_number() >= 3:
			break
		_check(battle.current_actor_id() != StitchedRules.WALK_MIMIC_ID,
			"no later intruder turn after the ambush: " + outcome)
		if battle.current_actor_id() == cut_id and not tied:
			var before := battle.state_snapshot()
			_check(not battle.move(-1).ok and battle.state_snapshot() == before,
				"the cut doll cannot move before RE-TIE: " + outcome)
			var receipt := battle.re_tie()
			_check(receipt.ok and battle.thread_cuts().is_empty(),
				"public RE-TIE clears the carried cut: " + outcome)
			if receipt.ok:
				trace.append(receipt)
			tied = true
		else:
			trace.append(battle.pass_turn())
	_check(battle.round_number() >= 3, "the routed battle plays deterministic legal follow-up rounds: " + outcome)
	_check(cut_id.is_empty() or tied, "the carried cut actually took its RE-TIE turn: " + outcome)
	_check(battle.get_heaps().is_empty(), "still no intruder heap or drop after later rounds: " + outcome)
	var after := session.snapshot()
	var saved := StitchedRunSave.capture(session)
	var reopened := StitchedRunSave.restore(bytes_to_var(var_to_bytes(saved)))
	_check(not saved.is_empty() and reopened != null and reopened.snapshot() == after,
		"a post-opening Continue save replays the routed bridge exactly: " + outcome)
	trace.append(battle.state_snapshot())
	trace.append(session.walk_receipts.duplicate(true))
	trace.append(session.journal.duplicate(true))
	# The spent plan cannot hand a second intruder to another battle.
	_check(session._open_battle("Elite") and session.battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty(),
		"another battle cannot reuse the consumed arrival: " + outcome)
	return trace

## commit admits only a complete plan that still matches its genuine unspent Walk.
func _commit_gates() -> void:
	var seed_number := -1
	for candidate in 32:
		var probe := _start(candidate)
		if probe != null and probe.snapshot().shadow.present:
			seed_number = candidate
			break
	_check(seed_number >= 0, "a present-shadow Walk witness exists")
	if seed_number < 0:
		return
	var walk := _start(seed_number)
	_complete(walk, "wrong2")
	var arrival := Bridge.plan(walk, walk.snapshot())
	_check(arrival.ok and not arrival.cuts.is_empty(), "a genuinely completed Walk plans its cut")
	if not arrival.ok:
		return
	var before := walk.snapshot()
	var rng_before: int = walk._rng.state
	_check(not Bridge.commit(walk, {"ok": true, "rng": arrival.rng}, rng_before),
		"commit refuses a forged plan carrying only ok and rng")
	var flipped := arrival.duplicate(true)
	flipped.mimic = not bool(flipped.mimic)
	_check(not Bridge.commit(walk, flipped, rng_before), "commit refuses a forged mimic flag")
	var forged_cuts := arrival.duplicate(true)
	forged_cuts.cuts = {"forged_doll": 4}
	_check(not Bridge.commit(walk, forged_cuts, rng_before), "commit refuses a forged cut map")
	_check(not Bridge.commit(walk, arrival, rng_before + 1), "commit refuses a substituted run RNG state")
	var stale := arrival.duplicate(true)
	walk._state.dolls[1].fray = int(walk._state.dolls[1].fray) + 1
	_check(not Bridge.commit(walk, stale, rng_before), "commit refuses a stale copied plan after its Walk moved on")
	walk._state.dolls[1].fray = int(walk._state.dolls[1].fray) - 1
	_check(walk.snapshot() == before and walk._rng.state == rng_before,
		"every refused commit leaves the Walk, its descriptors and the RNG exactly pure")
	_check(Bridge.commit(walk, arrival, rng_before), "the genuine complete plan commits once")
	_check(not Bridge.commit(walk, arrival, rng_before), "a consumed Walk rejects a replayed commit")
	_check(walk._battle_consumed, "commit consumes the Walk's one-shot bridge")


## A seeded noncombat Walk with a genuinely unresolved shadow leaves the bridge's
## validated arrival waiting for the next battle; null when this seed has none.
func _visit_session(seed_number: int) -> StitchedRunSession:
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
		if _routed_step(session).get("ok") != true:
			return null
	if session.phase != "visit" or session.walk_arrival.is_empty():
		return null
	return session


## A synthetic or malformed walk_arrival is not an authenticated plan: the bridge
## refuses it before any run RNG draw, and the genuine plan still opens once.
func _forged_arrival() -> void:
	var fresh := StitchedRunSession.start(11)
	_check(fresh != null, "a clean session starts")
	if fresh != null:
		var fresh_rng := fresh.rng.state
		for synthetic in [{"ok": true, "mimic": true, "cuts": {}},
				{"ok": true, "mimic": true, "cuts": {}, "amounts": {}},
				{"ok": true, "error": "", "battle": null, "mimic": true, "cuts": {}, "amounts": {}}]:
			fresh.walk_arrival = synthetic
			_check(not fresh._open_battle("Fight") and fresh.battle == null and fresh.rng.state == fresh_rng,
				"a synthetic walk_arrival without genuine Walks admits no forged intruder or RNG draw")
	var session: StitchedRunSession = null
	var seed_number := -1
	for candidate in 32:
		session = _visit_session(candidate)
		if session != null:
			seed_number = candidate
			break
	_check(session != null, "a genuine deferred arrival witness exists")
	if session == null:
		return
	var genuine: Dictionary = session.walk_arrival.duplicate(true)
	var pure := session.snapshot()
	var pure_rng := session.rng.state
	var pure_journal := session.journal.duplicate(true)
	var flipped := genuine.duplicate(true)
	flipped.mimic = not bool(flipped.mimic)
	var forged_cuts := genuine.duplicate(true)
	forged_cuts.cuts = {"forged_doll": 4}
	var malformed := genuine.duplicate(true)
	malformed.error = "forged"
	for forged in [{"ok": true, "rng": genuine.get("rng", 0)}, flipped, forged_cuts, malformed, {}]:
		session.walk_arrival = forged
		_check(not session._open_battle("Fight") and session.battle == null
			and session.rng.state == pure_rng and session.journal == pure_journal
			and session.receipts == pure.receipts and session.walk_carry == pure.walk.carry
			and session.walk_receipts == pure.walk.receipts,
			"a forged, partial or erased walk_arrival opens no battle and spends nothing")
	session.walk_arrival = genuine
	_check(session._open_battle("Fight") and session.battle != null
		and not session.battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty(),
		"the authentic plan still opens its ambush battle")
	# The routed caller admits and seals the freshly opened battle exactly this way.
	session.phase = "battle"
	session._lose_strings_if_due()
	session._seal()
	var living := session.battle.get_heroes().filter(func(hero): return not hero.lost)
	living.sort_custom(func(a, b): return a.rank < b.rank)
	var attack := session.battle.use_foe_ability("rag_rake", int(living.back().rank))
	var ambush_journal := session.journal.any(func(entry): return entry is Dictionary \
		and entry.get("action") == "battle" and entry.get("method") == "use_foe_ability")
	_check(attack.ok and ambush_journal,
		"the authentic plan's battle records its commands in the run journal")
	_check(session.walk_arrival.is_empty(), "the authentic plan is spent by exactly one battle")
	_check(session._open_battle("Elite") and session.battle.get_unit(StitchedRules.WALK_MIMIC_ID).is_empty(),
		"the spent plan cannot hand its intruder to another battle")


## Walk a visit Walk to its shadow and SNIP it: "wrong" cuts the rank-2 doll,
## "correct" cuts the real shadow. False when this Walk has no present shadow.
func _snip_visit_walk(session: StitchedRunSession, mode: String) -> bool:
	var state := session.walk.snapshot()
	if not state.has("shadow") or not bool(state.shadow.get("present", false)):
		return false
	while session.phase == "walk" and session.walk.snapshot().step < int(state.shadow.step):
		if _routed_step(session).get("ok") != true:
			return false
	if session.phase != "walk":
		return false
	var look := session.walk_act({"kind": "look_back", "actor": session.walk.snapshot().viewpoint},
		session.snapshot())
	if look.get("ok") != true or not session.walk.shadow_visible():
		return false
	var target: String = session.walk.snapshot().shadow.id if mode == "correct" else session.heroes[1].id
	var snip := session.walk_act({"kind": "snip", "actor": session.walk.snapshot().viewpoint,
		"target": target}, session.snapshot())
	if snip.get("ok") != true:
		return false
	for guard in 40:
		if session.phase != "walk":
			break
		if _routed_step(session).get("ok") != true:
			return false
	return session.phase == "visit"


## Leave the open visit through its real enabled Leave action.
func _leave_visit(session: StitchedRunSession) -> bool:
	if session.phase != "visit":
		return false
	for action in session.visit_actions():
		if action.id == "leave" and action.enabled:
			return session.choose_visit(action.id, action.arguments, session.snapshot())
	return false


## Two noncombat Walks, each SNIPPed in the given mode: the returned session stands
## on the map with the merged arrival waiting for the next battle; null if impossible.
func _double_route(seed_number: int, mode: String) -> StitchedRunSession:
	var session := StitchedRunSession.start(seed_number)
	if session == null or not session.enable_walks():
		return null
	for visit in 2:
		var pick := ""
		for id in session.choices():
			var node_type: String = session.map.get_node(id).type
			if node_type != "Boss" and not node_type in ["Fight", "Elite"]:
				pick = id
				break
		if pick.is_empty() or not session.enter(pick, session.snapshot()):
			return null
		if session.phase != "walk" or not _snip_visit_walk(session, mode):
			return null
		if session.phase != "visit" or not _leave_visit(session):
			return null
	return session


## Two genuine visit Walks' wrong SNIPs on one doll each pay their own 20 fray at
## the next battle, while the cut itself is presented once for RE-TIE.
func _double_cut() -> void:
	var seed_number := -1
	for candidate in 64:
		var probe := _double_route(candidate, "wrong")
		if probe == null:
			continue
		for id in probe.choices():
			if probe.map.get_node(id).type in ["Fight", "Elite"]:
				seed_number = candidate
				break
		if seed_number >= 0:
			break
	_check(seed_number >= 0, "a seeded two-visit cut route witness exists")
	if seed_number < 0:
		return
	var test_route := _double_route(seed_number, "wrong")
	var control := _double_route(seed_number, "correct")
	_check(test_route != null and control != null, "both cut routes replay deterministically")
	if test_route == null or control == null:
		return
	var cut_id: String = test_route.heroes[1].id
	_check(not test_route.walk_arrival.is_empty() and test_route.walk_arrival.cuts == {cut_id: 2}
		and test_route.walk_arrival.amounts == {cut_id: 40},
		"the merged plan counts one 20-fray amount per genuine wrong SNIP")
	_check(control.walk_arrival.is_empty(), "correct SNIPs defer no arrival")
	var waiting := test_route.snapshot()
	var waiting_save := StitchedRunSave.capture(test_route)
	var waiting_back := StitchedRunSave.restore(bytes_to_var(var_to_bytes(waiting_save)))
	_check(not waiting_save.is_empty() and waiting_back != null and waiting_back.snapshot() == waiting,
		"a Continue save replays the deferred doubled-cut arrival exactly")
	var fight := ""
	for id in test_route.choices():
		if test_route.map.get_node(id).type in ["Fight", "Elite"]:
			fight = id
			break
	_check(not fight.is_empty() and test_route.enter(fight, test_route.snapshot()),
		"the routed Fight enters through its own Walk")
	for guard in 40:
		if test_route.phase != "walk":
			break
		if _routed_step(test_route).get("ok") != true:
			_check(false, "the routed fight Walk completes")
			return
	_check(test_route.phase == "battle" and test_route.battle != null,
		"the doubled-cut plan opens the routed battle")
	if test_route.battle == null:
		return
	var battle = test_route.battle
	var hero_fray := 0
	for hero in test_route.heroes:
		if hero.id == cut_id:
			hero_fray = int(hero.fray)
	var test_fray := -1
	for hero in test_route.battle_config.heroes:
		if hero.id == cut_id:
			test_fray = int(hero.fray)
	_check(test_fray == hero_fray + 40,
		"two genuine wrong SNIPs pay their doll's baseline fray plus exactly 40")
	_check(battle.thread_cuts() == {cut_id: 2}, "the merged plan presents exactly one cut for RE-TIE")
	_check(int(battle.get_unit(cut_id).fray) >= test_fray, "the doubled fray reaches the actual battle unit")
	var tied := false
	for step in 60:
		if battle.round_number() >= 3:
			break
		_check(battle.current_actor_id() != StitchedRules.WALK_MIMIC_ID or tied or step == 0,
			"no later intruder turn after its one ambush")
		if battle.current_actor_id() == StitchedRules.WALK_MIMIC_ID:
			var living := battle.get_heroes().filter(func(hero): return not hero.lost)
			living.sort_custom(func(a, b): return a.rank < b.rank)
			var ambush := battle.use_foe_ability("rag_rake", int(living.back().rank))
			_check(ambush.ok and ambush.fled, "the merged plan's intruder ambushes once and flees")
		elif battle.current_actor_id() == cut_id and not tied:
			var before := battle.state_snapshot()
			_check(not battle.move(-1).ok and battle.state_snapshot() == before,
				"the cut doll cannot move before RE-TIE")
			var receipt := battle.re_tie()
			_check(receipt.ok and battle.thread_cuts().is_empty(),
				"public RE-TIE clears the merged cut once")
			tied = true
		else:
			battle.pass_turn()
	_check(battle.round_number() >= 3, "the doubled-cut battle plays real follow-up rounds")
	_check(tied, "the cut doll actually took its RE-TIE turn")
	var after := test_route.snapshot()
	var saved := StitchedRunSave.capture(test_route)
	var reopened := StitchedRunSave.restore(bytes_to_var(var_to_bytes(saved)))
	_check(not saved.is_empty() and reopened != null and reopened.snapshot() == after,
		"a post-RE-TIE Continue save replays the doubled-cut route exactly")
