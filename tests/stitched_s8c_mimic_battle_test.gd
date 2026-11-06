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
