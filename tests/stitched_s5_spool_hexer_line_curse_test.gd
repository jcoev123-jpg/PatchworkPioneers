extends SceneTree
## S5 Spool Hexer line-wide Spool Curse contract.
##
## One authored change (the Curse's multi flag) turns the elite's spool-wide curse into a
## four-doll debuff. This test builds its fixtures from the real StitchedEnemyCatalog and
## data/stitched/s2_preview.json, advances real initiative with hero PASS and legal foe
## actions, and then checks the live projection and the real action receipt: one independent
## 90-base-ACC hit/miss per living doll, hit-only Exposed 2, no direct damage, a real landed
## +50% follow-up, natural miss/hit witnesses inside a bounded seed sweep, refusal/no-spend
## negatives, the untargetable doll, the mounted battle-screen driver and an exact replay.

const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const ELITE_PATH := "res://data/enemies/m04_elites.json"
const HEXER := "spool_hexer"
const CURSE := "spool_curse"
## Spool Hexer at foe rank 1 plus two other distinct legal elites, ordered so each can launch
## its own attack from its rolled foe rank (Bailiff Snip from rank 2, Briar Thrust from rank 3).
const COHORT := ["spool_hexer", "scissor_bailiff", "needle_briar_guard"]
const CURSE_ACC := 90
const SEED_LIMIT := 40

var failures: Array[String] = []
var checks := 0
var _catalog: Dictionary = {}
var _preview: Dictionary = {}
var _witness_seed := -1


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var preview: Variant = _read_json(PREVIEW_PATH)
	_preview = preview if preview is Dictionary else {}
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"the real enemy catalog loads: " + str(_catalog.get("error", "")))
	_check(not _preview.is_empty() and _preview.get("heroes", []).size() == 4,
		"the shipped preview authors the four-doll party")
	if not bool(_catalog.get("ok", false)) or _preview.is_empty():
		_finish()
		return
	_test_authored_record()
	_test_out_of_turn_refusal()
	_test_live_projection_and_line()
	_test_untargetable_line()
	await _test_mounted_driver()
	_test_replay()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_spool_hexer_line_curse_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _elite_record(enemy_id: String) -> Dictionary:
	var parsed: Variant = _read_json(ELITE_PATH)
	if not parsed is Array:
		return {}
	for raw in parsed:
		if raw is Dictionary and str(raw.get("id", "")) == enemy_id:
			return raw
	return {}


func _ability_of(unit: Dictionary, ability_id: String) -> Dictionary:
	for ability in unit.get("abilities", []):
		if str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _without_exposed(statuses: Dictionary) -> Dictionary:
	var copy: Dictionary = statuses.duplicate(true)
	copy.erase("exposed")
	return copy


# ---------------------------------------------------------------- fixtures

func _config(seed_value: int, foes: Array, heroes: Array = []) -> Dictionary:
	var parts: Array = _catalog["parts"].duplicate(true)
	parts.append_array(_preview["parts"].duplicate(true))
	var party: Array = heroes.duplicate(true) if not heroes.is_empty() \
		else _preview["heroes"].duplicate(true)
	return {
		"mode": "stitched",
		"seed": seed_value,
		"candle": 100,
		"heroes": party,
		"parts": parts,
		"foes": foes,
	}


func _foes() -> Array:
	var foes: Array = []
	for foe_id in COHORT:
		foes.append(StitchedEnemyCatalog.foe_for(_catalog, str(foe_id)))
	return foes


func _make_battle(seed_value: int, heroes: Array = []) -> Dictionary:
	var foes := _foes()
	for foe in foes:
		if foe.is_empty():
			return {"ok": false, "error": "a cohort foe is missing from the catalog", "battle": null}
	return StitchedRules.create(_config(seed_value, foes, heroes))


## One real turn: a hero PASS, or the foe's own authoritative next legal action.
func _step(battle: StitchedRules) -> Dictionary:
	if battle.is_over():
		return {"ok": false, "error": "the battle is over"}
	if battle.current_side() == "hero":
		return battle.pass_turn()
	var actor := battle.get_unit(battle.current_actor_id())
	var intent := StitchedFoeIntent.choose(battle, actor)
	if intent.is_empty() or bool(intent.get("pass", true)):
		return battle.pass_turn()
	return battle.use_foe_ability(str(intent["ability_id"]), int(intent["target_rank"]))


## Real initiative until the Hexer holds its turn in the requested round.
func _reach_hexer_turn(battle: StitchedRules, target_round: int) -> bool:
	for step in range(96):
		if battle.is_over():
			return false
		if battle.round_number() > target_round:
			return false
		if battle.round_number() == target_round and battle.current_actor_id() == HEXER:
			return true
		if not bool(_step(battle).get("ok", false)):
			return false
	return false


func _living_hero_snapshot(battle: StitchedRules) -> Dictionary:
	var units: Dictionary = {}
	for hero in battle.get_heroes():
		if not bool(hero["lost"]):
			units[str(hero["id"])] = hero.duplicate(true)
	return units


## True when a hero's turn precedes this foe in the rolled order (the live plate is readable then).
func _hero_precedes(battle: StitchedRules, order: Array, foe_id: String) -> bool:
	var index := order.find(foe_id)
	if index < 0:
		return false
	for i in range(index):
		var unit := battle.get_unit(str(order[i]))
		if str(unit.get("side", "")) == "hero":
			return true
	return false


## True when the curse landed on the front doll the other foes' rank-1 attacks reach.
func _front_doll_hit(receipt: Dictionary) -> bool:
	for result in receipt.get("results", []):
		if int(result.get("target_rank", 0)) == 1:
			return bool(result.get("hit", false))
	return false


# ---------------------------------------------------------------- AC1 the one authored change

func _test_authored_record() -> void:
	var raw := _elite_record(HEXER)
	_check(not raw.is_empty(), "AC1: the authored Spool Hexer record parses")
	if raw.is_empty():
		return
	var abilities: Array = raw.get("stitched", {}).get("abilities", [])
	_check(abilities.size() == 3, "AC1: the Hexer still authors exactly its three existing moves")
	var authored: Dictionary = {}
	for ability in abilities:
		if ability is Dictionary and str(ability.get("id", "")) == CURSE:
			authored = ability
	_check(not authored.is_empty(), "AC1: Spool Curse is still authored")
	var expected := {
		"id": "spool_curse",
		"name": "Spool Curse",
		"kind": "debuff",
		"launch": [1, 4],
		"target": [1, 2, 3, 4],
		"target_side": "enemy",
		"multi": true,
		"acc": 90,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"exposed": 2},
		"self_move": 0,
		"move": "skill",
	}
	_check(authored.size() == expected.size(),
		"AC1: Spool Curse adds no field beyond its shipped record")
	for key in expected:
		if expected[key] is Array:
			var got: Array = []
			for value in authored.get(key, []):
				got.append(int(value))
			var want: Array = []
			for value in expected[key]:
				want.append(int(value))
			_check(got == want, "AC1: authored Spool Curse keeps " + str(key))
		elif expected[key] is Dictionary:
			var got_effects: Dictionary = authored.get(key, {})
			var want_effects: Dictionary = expected[key]
			_check(got_effects.size() == want_effects.size(),
				"AC1: authored Spool Curse keeps exactly its " + str(key))
			for effect in want_effects:
				_check(int(got_effects.get(effect, -1)) == int(want_effects[effect]),
					"AC1: authored Spool Curse keeps " + str(key) + " " + str(effect))
		else:
			_check(authored.get(key) == expected[key],
				"AC1: authored Spool Curse keeps " + str(key))
	# The single authored delta is the multi flag: every other shipped value above is untouched.
	_check(bool(authored.get("multi", false)),
		"AC1: the only authored change is the curse reaching the whole line (multi true)")
	var normalized: Variant = StitchedParts.validate_ability(authored)
	_check(bool(normalized.get("ok", false)) and not (normalized.get("ability", {}) as Dictionary).is_empty(),
		"AC1: the authored curse validates as a StitchedParts ability")
	var foe := StitchedEnemyCatalog.foe_for(_catalog, HEXER)
	_check(not foe.is_empty(), "AC1: the real loader resolves the Spool Hexer")
	if foe.is_empty():
		return
	_check(_ability_of(foe, CURSE) == normalized.get("ability", {}),
		"AC1: the loader publishes exactly the authored curse, masks included")
	_check(str(foe.get("name", "")) == "Spool Hexer" and int(foe.get("max_hp", 0)) == 24
		and int(foe.get("speed", -1)) == 6 and int(foe.get("dodge", -1)) == 7
		and int(foe.get("acc", -1)) == 0 and int(foe.get("prot", -1)) == 2
		and not bool(foe.get("is_boss", true)) and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the Hexer keeps its shipped stats and its single turn")
	_check(StitchedEnemyCatalog.trophy_for(_catalog, HEXER) == "spool_hexer_spool",
		"AC1: the Hexer keeps its own foreign trophy")
	var bolt := {
		"id": "hex_bolt", "name": "Hex Bolt", "kind": "ranged", "launch": [1, 4],
		"target": [1, 3], "target_side": "enemy", "multi": false, "acc": 88,
		"dmg": [4, 5], "crit": 0, "mark_damage": 3, "effects": {"weak": 1},
		"self_move": 0, "move": "attack2",
	}
	var tag := {
		"id": "thread_tag", "name": "Thread Tag", "kind": "debuff", "launch": [1, 2, 3, 4],
		"target": [1, 2, 3], "target_side": "enemy", "multi": false, "acc": 90,
		"dmg": [0, 0], "crit": 0, "effects": {"mark": 3}, "self_move": 0, "move": "skill",
	}
	for pair in [[bolt, "Hex Bolt"], [tag, "Thread Tag"]]:
		var validated: Variant = StitchedParts.validate_ability(pair[0])
		_check(bool(validated.get("ok", false))
			and _ability_of(foe, str(pair[0]["id"])) == validated.get("ability", {}),
			"AC1: " + str(pair[1]) + " is still exactly the shipped single-target move")
	_check(not bool(_ability_of(foe, "hex_bolt").get("multi", true))
		and int(_ability_of(foe, "hex_bolt").get("mark_damage", 0)) == 3
		and not bool(_ability_of(foe, "thread_tag").get("multi", true)),
		"AC1: neither Hex Bolt nor Thread Tag became a multi action")
	var raw_legacy: Dictionary = raw.get("intent", {})
	var legacy_actions := [
		{"type": "attack", "amount": 9, "weight": 1},
		{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 10, "move": "attack3", "weight": 1},
		{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
		{"type": "debuff", "amount": 1, "status": "weak", "weight": 1},
	]
	var authored_actions: Array = raw_legacy.get("actions", [])
	_check(raw_legacy.get("target") == "random" and authored_actions.size() == legacy_actions.size(),
		"AC1: the legacy card intent keeps its target and action count")
	for index in range(mini(authored_actions.size(), legacy_actions.size())):
		var action: Dictionary = authored_actions[index]
		_check(action.size() == legacy_actions[index].size(),
			"AC1: legacy action %d keeps exactly its shipped fields" % index)
		for key in legacy_actions[index]:
			_check(action.get(key) == legacy_actions[index][key],
				"AC1: legacy action value unchanged: " + str(key))
	_check(int(raw.get("max_hp", 0)) == 24 and str(raw.get("name", "")) == "Spool Hexer"
		and str(raw.get("art_path", "")) == "res://assets/paper/enemies/spool_hexer.png",
		"AC1: legacy HP, name and sprite path are unchanged")
	# Two neighbouring elites keep their own independent contracts.
	for neighbour in [
		["needle_marshal", 28, 5, 6, 6, "needle_marshal_sash",
			["marshal_prick", "marshal_volley", "iron_discipline"]],
		["scissor_bailiff", 36, 4, 5, 8, "scissor_bailiff_shears",
			["bailiff_snip", "seize_thread", "bailiff_unpick"]],
	]:
		var other := StitchedEnemyCatalog.foe_for(_catalog, str(neighbour[0]))
		var ids: Array = []
		for ability in other.get("abilities", []):
			ids.append(str(ability.get("id", "")))
			_check(not bool(ability.get("multi", true)),
				"AC1: no multi flag leaks to " + str(neighbour[0]))
		_check(int(other.get("max_hp", 0)) == int(neighbour[1])
			and int(other.get("speed", -1)) == int(neighbour[2])
			and int(other.get("dodge", -1)) == int(neighbour[3])
			and int(other.get("prot", -1)) == int(neighbour[4])
			and StitchedEnemyCatalog.trophy_for(_catalog, str(neighbour[0])) == str(neighbour[5])
			and ids == neighbour[6],
			"AC1: unchanged neighbour elite " + str(neighbour[0]))


# ---------------------------------------------------------------- AC4 out-of-turn refusal

func _test_out_of_turn_refusal() -> void:
	var created := _make_battle(3)
	_check(bool(created.get("ok", false)), "AC4: the out-of-turn fixture builds from the real catalog")
	if not bool(created.get("ok", false)):
		return
	var battle: StitchedRules = created["battle"]
	for step in range(16):
		if battle.is_over() or battle.current_side() == "hero":
			break
		_step(battle)
	_check(battle.current_side() == "hero", "AC4: a real hero turn precedes the out-of-turn probe")
	var before := battle.state_snapshot()
	var before_rng := battle.rng_state()
	var before_order := battle.turn_order()
	var refused := battle.use_foe_ability(CURSE, 1)
	_check(not bool(refused.get("ok", true)) and str(refused.get("error", "")).contains("not a foe turn"),
		"AC4: casting the curse during a hero turn is refused")
	_check(before == battle.state_snapshot() and before_rng == battle.rng_state()
		and before_order == battle.turn_order(),
		"AC4: the out-of-turn refusal spends no turn, state or RNG")


# ---------------------------------------------------------------- AC2/AC3 the live line curse

func _test_live_projection_and_line() -> void:
	var hit_results := 0
	var miss_results := 0
	var curse_seeds := 0
	for seed_value in range(1, SEED_LIMIT + 1):
		var created := _make_battle(seed_value)
		if not bool(created.get("ok", false)):
			_check(false, "AC2: seeded 4v3 fixture builds for seed %d: %s"
				% [seed_value, str(created.get("error", ""))])
			continue
		var battle: StitchedRules = created["battle"]
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
			"AC2: a living four-doll party faces three foes")
		if not _reach_hexer_turn(battle, 2):
			continue
		var ready := true
		for hero in battle.get_heroes():
			ready = ready and not bool(hero["lost"]) and int(hero["hp"]) > 0 \
				and int(hero["statuses"].get("exposed", 0)) == 0
		if not ready:
			continue
		var round_order := battle.turn_order()
		var receipt := battle.use_foe_ability(CURSE, 1)
		if not bool(receipt.get("ok", false)):
			continue
		curse_seeds += 1
		var hits := 0
		var misses := 0
		for result in receipt.get("results", []):
			if bool(result.get("hit", false)):
				hits += 1
				hit_results += 1
			else:
				misses += 1
				miss_results += 1
		# Bounded natural witnesses: the same round-2 curse really hits and really misses, the
		# front doll the other foes attack is hit, and a seeded hero turn precedes the Hexer
		# so the live plate can be read while the curse is still forecast.
		if hits > 0 and misses > 0 and _front_doll_hit(receipt) \
				and _hero_precedes(battle, round_order, HEXER) and _witness_seed < 0:
			_witness_seed = seed_value
	_check(hit_results > 0 and miss_results > 0,
		"AC2: the bounded seed sweep naturally witnesses both curse hits and curse misses")
	_check(_witness_seed > 0, "AC2: one unmodified seed carries a hit and a miss in the same line")
	_check(curse_seeds >= 2, "AC2: the sweep really resolves more than one live curse")
	if _witness_seed < 0:
		return
	var rebuilt := _make_battle(_witness_seed)
	if not bool(rebuilt.get("ok", false)):
		_check(false, "AC2: the witness seed rebuilds deterministically")
		return
	var battle: StitchedRules = rebuilt["battle"]
	_check(_reach_hexer_turn(battle, 2),
		"AC2: real hero PASS and legal foe actions reach the Hexer's round-2 turn")
	var actor_before := battle.get_unit(HEXER)
	_check(battle.round_number() == 2 and battle.current_actor_id() == HEXER,
		"AC2: the authoritative round-2 actor is the Spool Hexer itself")
	var pre_units := _living_hero_snapshot(battle)
	_check(pre_units.size() == 4, "AC2: all four dolls are alive and unExposed before the curse")
	for hero_id in pre_units:
		_check(int(pre_units[hero_id]["statuses"].get("exposed", 0)) == 0,
			"AC2: doll %s starts the curse line unExposed" % str(hero_id))
	# AC3: the live projection is truthful and costs nothing.
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(HEXER))
	_check(str(intent.get("ability_id", "")) == CURSE and str(intent.get("foe_id", "")) == HEXER,
		"AC3: the chooser forecasts Spool Curse")
	_check(bool(intent.get("multi", false)), "AC3: the forecast is truthfully multi")
	_check(intent.get("affected_ranks", []) == [1, 2, 3, 4],
		"AC3: the forecast names the whole four-rank doll line")
	_check(str(intent.get("target_side", "")) == "hero" and int(intent.get("target_rank", 0)) == 1,
		"AC3: the forecast aims at the hero line from its nearest legal rank")
	_check(int(intent.get("base_acc", -1)) == CURSE_ACC and intent.get("base_damage", []) == [0, 0]
		and intent.get("base_effects", {}) == {"exposed": 2}
		and int(intent.get("base_crit", -1)) == 0 and int(intent.get("base_mark_damage", -1)) == 0,
		"AC3: the forecast discloses authored 90 ACC, zero damage and Exposed 2 only")
	for repeat in range(3):
		_check(StitchedFoeIntent.choose(battle, battle.get_unit(HEXER)) == intent,
			"AC3: repeated projection is identical")
	_check(snapshot == battle.state_snapshot() and rng == battle.rng_state()
		and order == battle.turn_order(),
		"AC3: projection changes no state, RNG draw or turn order")
	# AC4: illegal masks and unknown ids are refused before any spend.
	var before_refusals := battle.state_snapshot()
	var before_refusal_rng := battle.rng_state()
	var rank_zero := battle.use_foe_ability(CURSE, 0)
	var rank_five := battle.use_foe_ability(CURSE, 5)
	var unknown := battle.use_foe_ability("not_a_move", 1)
	_check(not bool(rank_zero.get("ok", true)) and not bool(rank_five.get("ok", true))
		and not bool(unknown.get("ok", true)),
		"AC4: out-of-mask ranks 0 and 5 and an unknown action are refused")
	_check(before_refusals == battle.state_snapshot() and before_refusal_rng == battle.rng_state(),
		"AC4: refused casts spend no turn, state or RNG")
	# The real action.
	var curse_round := battle.round_number()
	var receipt := battle.use_foe_ability(CURSE, 1)
	_check_curse_receipt(battle, receipt, pre_units, actor_before, "AC2")
	# AC3: real Exposed ticks and a real +50% follow-up.
	_track_exposure(battle, receipt, order, curse_round, "AC3")


## One curse receipt against the real state: independent rolls, hit-only Exposed 2, no damage.
func _check_curse_receipt(battle: StitchedRules, receipt: Dictionary, pre_units: Dictionary,
		actor_before: Dictionary, label: String) -> void:
	_check(bool(receipt.get("ok", false)) and str(receipt.get("ability", "")) == CURSE
		and str(receipt.get("actor", "")) == HEXER and str(receipt.get("actor_side", "")) == "foe",
		label + ": the real foe action commits as the Spool Hexer's Spool Curse")
	var results: Array = receipt.get("results", [])
	_check(results.size() == pre_units.size(),
		label + ": one independent hit/miss receipt for every living doll on the line")
	var acc := CURSE_ACC + int(actor_before.get("acc", 0)) \
		+ int(battle.candle_band().get("enemy_acc", 0))
	var streak := int(actor_before.get("miss_streak", 0))
	var ranks: Array = []
	for result in results:
		var target_id := str(result.get("target", ""))
		ranks.append(int(result.get("target_rank", 0)))
		_check(pre_units.has(target_id), label + ": the receipt names a real living doll")
		if not pre_units.has(target_id):
			continue
		var before: Dictionary = pre_units[target_id]
		var chance := StitchedRules.hit_chance(acc, StitchedRules.effective_dodge(before), streak)
		_check(int(result.get("hit_chance", -1)) == chance,
			label + ": doll %s rolls its own canonical 90-base-ACC chance" % target_id)
		_check(bool(result.get("hit", false)) == (int(result.get("roll", -1)) <= chance),
			label + ": doll %s hit/miss comes from its own seeded roll" % target_id)
		streak = 0 if bool(result.get("hit", false)) else streak + 1
		_check(str(result.get("target_side", "")) == "hero"
			and int(result.get("target_rank", 0)) == int(before.get("rank", -1)),
			label + ": doll %s keeps its real side and rank" % target_id)
		_check(int(result.get("damage", -1)) == 0 and not bool(result.get("crit", true)),
			label + ": the curse deals no direct damage to doll %s" % target_id)
		_check(int(result.get("target_hp", -1)) == int(before.get("hp", -2)),
			label + ": the curse leaves doll %s at its real HP" % target_id)
		var expected_statuses: Array = (
			[{"status": "exposed", "duration": 2}] if bool(result.get("hit", false)) else [])
		_check(result.get("statuses", []) == expected_statuses,
			label + ": only a confirmed curse hit applies Exposed 2 to doll %s" % target_id)
	ranks.sort()
	var expected_ranks: Array = []
	for hero_id in pre_units:
		expected_ranks.append(int(pre_units[hero_id]["rank"]))
	expected_ranks.sort()
	_check(ranks == expected_ranks, label + ": the receipt covers exactly the living ranks")
	for result in results:
		var target_id := str(result.get("target", ""))
		var after := battle.get_unit(target_id)
		_check((int(after["statuses"].get("exposed", 0)) > 0) == bool(result.get("hit", false)),
			label + ": the real doll state is Exposed only where the receipt hit")
		_check(int(after["hp"]) == int(pre_units[target_id]["hp"]),
			label + ": no doll loses HP to the line curse")


## AC3: Exposed counts down at each recipient's own turn start and a real follow-up hit is +50%.
func _track_exposure(battle: StitchedRules, curse: Dictionary,
		order: Array, curse_round: int, label: String) -> void:
	var hexer_index := order.find(HEXER)
	var hit_ids: Array = []
	for result in curse.get("results", []):
		if bool(result.get("hit", false)):
			hit_ids.append(str(result.get("target", "")))
	_check(not hit_ids.is_empty(), label + ": the witness curse lands at least one hit")
	_check(hit_ids.size() < int(curse.get("results", []).size()),
		label + ": the witness curse also misses at least one doll")
	var base: Dictionary = {}
	for hero_id in hit_ids:
		base[hero_id] = int(battle.get_unit(str(hero_id))["statuses"].get("exposed", 0))
		_check(int(base[hero_id]) >= 1, label + ": a hit doll really carries Exposed now")
	var seen_turns := 0
	var decrements := 0
	var observed_ids: Dictionary = {}
	var expired: Dictionary = {}
	var exposed_hit: Dictionary = {}
	# Stop before the Hexer's next curse (round 5 of its four-round rotation).
	for step in range(200):
		if battle.is_over() or battle.round_number() > curse_round + 2:
			break
		if battle.current_side() == "hero":
			var actor_id := battle.current_actor_id()
			if hit_ids.has(actor_id):
				var observed := int(battle.get_unit(actor_id)["statuses"].get("exposed", 0))
				# One countdown step per turn start since the curse: every living doll takes
				# exactly one turn a round, plus its own later turn in the curse round when it
				# stood behind the Hexer there (a consumed mood turn is still a turn start).
				var starts := battle.round_number() - curse_round
				if order.find(actor_id) > hexer_index:
					starts += 1
				var expected := maxi(0, 2 - starts)
				_check(observed == expected,
					label + ": Exposed counts down one at doll %s's own turn start" % actor_id)
				seen_turns += 1
				observed_ids[actor_id] = true
				if observed < 2:
					decrements += 1
				if observed == 0:
					expired[actor_id] = true
			battle.pass_turn()
			continue
		var units_before: Dictionary = {}
		for hero in battle.get_heroes():
			units_before[str(hero["id"])] = hero.duplicate(true)
		var actor_before := battle.get_unit(battle.current_actor_id())
		var receipt := _step(battle)
		if not bool(receipt.get("ok", false)) or not exposed_hit.is_empty():
			continue
		for result in receipt.get("results", []):
			if str(result.get("target_side", "")) != "hero" or not bool(result.get("hit", false)) \
					or int(result.get("damage", 0)) <= 0:
				continue
			var target_id := str(result.get("target", ""))
			var before: Dictionary = units_before.get(target_id, {})
			if int(before.get("statuses", {}).get("exposed", 0)) <= 0:
				continue
			exposed_hit = {
				"result": result,
				"before": before,
				"actor": actor_before,
				"ability": _ability_of(actor_before, str(receipt.get("ability", ""))),
				"candle": battle.candle(),
			}
			break
	_check(seen_turns > 0 and decrements > 0, label + ": Exposed really counts down in play")
	for hero_id in hit_ids:
		if bool(battle.get_unit(str(hero_id)).get("lost", false)):
			continue  # a lost doll leaves combat and its statuses are cleared
		_check(bool(observed_ids.get(hero_id, false)),
			label + ": cursed doll %s really takes its own later turn" % str(hero_id))
		_check(bool(expired.get(hero_id, false)),
			label + ": Exposed on doll %s ends when its duration runs out" % str(hero_id))
	if exposed_hit.is_empty():
		_check(false, label + ": a real landed follow-up really strikes an Exposed doll")
		return
	var result: Dictionary = exposed_hit["result"]
	var before: Dictionary = exposed_hit["before"]
	var actor: Dictionary = exposed_hit["actor"]
	var ability: Dictionary = exposed_hit["ability"]
	var candle := int(exposed_hit["candle"])
	_check(not ability.is_empty() and int(ability.get("dmg", [0, 0])[1]) > 0,
		label + ": the follow-up is an authored direct attack")
	if ability.is_empty():
		return
	var marked := int(before.get("statuses", {}).get("mark", 0)) > 0
	var mark_damage := int(ability.get("mark_damage", 0))
	var power := int(before.get("prot", 0))
	var bonus := int(actor.get("dmg_bonus", 0))
	var candidates: Array = [[StitchedRules.crit_damage(int(ability["dmg"][1])) + bonus, true]]
	for roll in range(int(ability["dmg"][0]), int(ability["dmg"][1]) + 1):
		candidates.append([roll + bonus, false])
	var matched := false
	for candidate in candidates:
		if bool(candidate[1]) != bool(result.get("crit", false)):
			continue
		var base_value := StitchedS1BEffects.enemy_damage(int(candidate[0]), candle)
		var expected := StitchedRules.damage_after_modifiers(base_value, actor.get("statuses", {}),
			before.get("statuses", {}), marked, mark_damage, power)
		if expected != int(result.get("damage", -1)):
			continue
		matched = true
		var control := StitchedRules.damage_after_modifiers(base_value, actor.get("statuses", {}),
			_without_exposed(before.get("statuses", {})), marked, mark_damage, power)
		_check(int(result["damage"]) > control,
			label + ": Exposed adds its +50% over the same attack without Exposed")
	_check(matched, label + ": the real damage matches StitchedRules.damage_after_modifiers")


# ---------------------------------------------------------------- AC4 a lost doll leaves the line

func _test_untargetable_line() -> void:
	var party: Array = _preview["heroes"].duplicate(true)
	var lost: Dictionary = party[0].duplicate(true)
	lost["parts"] = {}
	lost["hp"] = 0
	lost["lost"] = true
	lost.erase("statuses")
	lost.erase("fray")
	lost.erase("resolve")
	party[0] = lost
	var created := _make_battle(5, party)
	_check(bool(created.get("ok", false)),
		"AC4: the three-doll fixture builds from the real catalog: " + str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return
	var battle: StitchedRules = created["battle"]
	var lost_id := str(party[0]["id"])
	_check(bool(battle.get_unit(lost_id).get("lost", false)),
		"AC4: the front doll really is lost before the curse")
	if not _reach_hexer_turn(battle, 2):
		_check(false, "AC4: the three-doll battle reaches the Hexer's round-2 turn")
		return
	var pre_units := _living_hero_snapshot(battle)
	_check(pre_units.size() == 3 and not pre_units.has(lost_id),
		"AC4: only three dolls remain targetable")
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(HEXER))
	_check(intent.get("affected_ranks", []) == [2, 3, 4],
		"AC4: the forecast excludes the lost front rank")
	var actor_before := battle.get_unit(HEXER)
	var receipt := battle.use_foe_ability(CURSE, int(intent.get("target_rank", 2)))
	_check(bool(receipt.get("ok", false)) and receipt.get("results", []).size() == 3,
		"AC4: the line curse returns three receipts, never a ghost fourth")
	var ranks: Array = []
	for result in receipt.get("results", []):
		ranks.append(int(result.get("target_rank", 0)))
		_check(str(result.get("target", "")) != lost_id,
			"AC4: a lost doll never receives a curse receipt")
	_check(ranks == [2, 3, 4], "AC4: the remaining living ranks keep their real order")
	_check_curse_receipt(battle, receipt, pre_units, actor_before, "AC4")


# ---------------------------------------------------------------- AC3 the mounted live driver

func _test_mounted_driver() -> void:
	if _witness_seed < 0:
		_check(false, "AC3: a witness seed exists for the mounted driver")
		return
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(_config(_witness_seed, _foes())),
		"AC3: the real battle screen admits the seeded 4v3 elite fight")
	if stage.battle == null:
		stage.free()
		return
	root.add_child(stage)
	await process_frame
	var battle := stage.battle
	var curse_receipt: Dictionary = {}
	var disclosed_ranks: Array = []
	var plate_text := ""
	# Real player Pass presses until the round-2 hero turn whose plate forecasts the curse.
	for step in range(24):
		if battle.is_over() or battle.round_number() >= 2 or not curse_receipt.is_empty():
			break
		if battle.current_side() != "hero":
			break
		stage._action_buttons["pass"].pressed.emit()
		for receipt in stage.receipts:
			if str(receipt.get("actor", "")) == HEXER and str(receipt.get("ability", "")) == CURSE:
				curse_receipt = receipt
	var opened := battle.round_number() == 2 and battle.current_side() == "hero" \
		and curse_receipt.is_empty()
	_check(opened, "AC3: the witness seed opens round two on a real hero turn")
	if opened:
		stage._refresh()
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit(HEXER))
		disclosed_ranks = intent.get("affected_ranks", [])
		var ticket: StitchedFoeIntentPlate = stage._foe_tickets[1]
		plate_text = ticket.secondary.text
		_check(ticket.visible and stage._foe_intents.get(1, {}) == intent,
			"AC3: the mounted plate displays the authoritative curse forecast")
		_check(ticket.tooltip_text.contains("ALL legal HERO ranks 1, 2, 3, 4"),
			"AC3: the disclosure names every cursed doll rank")
		for step in range(16):
			if battle.is_over() or not curse_receipt.is_empty():
				break
			if battle.current_side() != "hero":
				break
			stage._action_buttons["pass"].pressed.emit()
			for receipt in stage.receipts:
				if str(receipt.get("actor", "")) == HEXER \
						and str(receipt.get("ability", "")) == CURSE:
					curse_receipt = receipt
	_check(disclosed_ranks == [1, 2, 3, 4] and plate_text == "HERO RANKS 1,2,3,4",
		"AC3: the live plate shows the actual four-rank target line")
	_check(not curse_receipt.is_empty(),
		"AC3: the mounted foe driver executes the forecast in real play")
	if not curse_receipt.is_empty():
		var results: Array = curse_receipt.get("results", [])
		_check(results.size() == 4,
			"AC3: the live driver resolves the curse against all four living dolls")
		var hits := 0
		var misses := 0
		for result in results:
			_check(bool(result.get("hit", false)) or result.get("statuses", []).is_empty(),
				"AC3: a live miss leaves the doll unExposed")
			_check(not bool(result.get("hit", false))
				or result.get("statuses", []) == [{"status": "exposed", "duration": 2}],
				"AC3: a live hit applies Exposed 2")
			_check(int(result.get("damage", -1)) == 0,
				"AC3: the live curse deals no direct damage")
			if bool(result.get("hit", false)):
				hits += 1
			else:
				misses += 1
		_check(hits > 0 and misses > 0,
			"AC3: the mounted witness really includes both a live hit and a live miss")
		# The live driver keeps the shipped rotation around the changed action.
		var cycle: Array = []
		for receipt in stage.receipts:
			if str(receipt.get("actor", "")) == HEXER:
				cycle.append(str(receipt.get("ability", "")))
		_check(cycle.slice(0, 2) == ["hex_bolt", CURSE],
			"AC3: the live cycle keeps Hex Bolt then the line-wide Spool Curse")
	stage.free()
	await process_frame


# ---------------------------------------------------------------- AC4 exact replay

func _transcript(seed_value: int) -> Dictionary:
	var created := _make_battle(seed_value)
	if not bool(created.get("ok", false)):
		return {}
	var battle: StitchedRules = created["battle"]
	var receipts: Array = []
	for step in range(200):
		if battle.is_over() or battle.round_number() > 5:
			break
		var receipt := _step(battle)
		if not bool(receipt.get("ok", false)):
			break
		receipts.append(receipt)
	return {
		"receipts": receipts,
		"snapshot": battle.state_snapshot(),
		"rng": battle.rng_state(),
		"order": battle.turn_order(),
	}


func _test_replay() -> void:
	if _witness_seed < 0:
		_check(false, "AC4: a witness seed exists for the replay")
		return
	var first := _transcript(_witness_seed)
	var second := _transcript(_witness_seed)
	_check(not first.is_empty() and not first["receipts"].is_empty(),
		"AC4: the replay fixture really executes authored actions")
	var curses := 0
	for receipt in first.get("receipts", []):
		if str(receipt.get("ability", "")) != CURSE:
			continue
		curses += 1
		if curses == 1:
			_check(receipt.get("results", []).size() == 4,
				"AC4: the first replayed curse keeps its four independent receipts")
		for result in receipt.get("results", []):
			_check(bool(result.get("hit", false)) == (result.get("statuses", []) != []),
				"AC4: every replayed curse result applies Exposed only on a hit")
	_check(curses > 0, "AC4: the replay really contains the line-wide curse")
	_check(first == second,
		"AC4: the same seed and actions replay identical receipts, statuses, HP, order and RNG")
