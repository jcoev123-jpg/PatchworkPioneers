extends SceneTree
## Seeded S1b contract: actual S1a four-hero, three-foe battles with the same
## validated parts catalog, turn transaction API, and one seeded RNG.

const FIXTURE := "res://tests/fixtures/stitched_s1a_parts.json"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_candle()
	_test_fray()
	_test_resolves()
	_test_battle_fray()
	_test_seams()
	_test_thread()
	_test_replay()
	_test_enemy_effects()
	_test_enemy_modifiers()
	_test_reckless_guard()
	_test_stun_clock()
	_test_mode_independence()
	if failures.is_empty():
		print("stitched_s1b_rules_test: PASS (", checks, " checks)")
	else:
		for error in failures:
			printerr(error)
		print("stitched_s1b_rules_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _ability(id: String, kind: String, effects: Dictionary = {}, damage: Array = [1, 1], critical: int = 0) -> Dictionary:
	return {
		"id": id, "name": id, "kind": kind, "launch": [1, 2, 3, 4],
		"target": [1, 2, 3, 4], "target_side": "enemy", "acc": 100,
		"dmg": damage, "crit": critical, "effects": effects, "move": "attack",
	}

func _hero(id: String, speed: int, head: String, arms: String, torso: String, legs: String) -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "max_hp": 40, "speed": speed,
		"dodge": 0, "acc": 0, "prot": 0,
		"parts": {"head": head, "arms": arms, "torso": torso, "legs": legs},
	}

func _config(seed_value: int, light: int = 100, special: String = "") -> Dictionary:
	var catalog := StitchedParts.load_catalog(FIXTURE)
	_check(bool(catalog["ok"]), "AC1: authored S1a part catalog loads")
	var parts: Array = catalog["parts"]
	parts.append({
		"id": "s1b_test_head", "name": "Test Needle", "owner": "any", "slot": "head",
		"stat": {"crit": 95}, "ability": _ability("needle_hit", "melee", {}, [5, 5], 0),
		"tiers": {}, "text": "A reliable test melee attack.",
	})
	var heal := _ability("mend_across", "heal", {"heal": 5}, [0, 0])
	heal["target_side"] = "ally"
	parts.append({
		"id": "s1b_test_heal", "name": "Test Mending", "owner": "any", "slot": "torso",
		"stat": {"max_hp": 2}, "ability": heal,
		"tiers": {}, "text": "A test of legal cross-thread healing.",
	})
	var heroes := [
		_hero("warden", 8, "s1b_test_head", "warden_arm_shield_bash", "warden_torso_quilt", "warden_legs_stride"),
		_hero("seamstress", 7, "warden_head_button_eye", "warden_arm_brace", "s1b_test_heal", "any_legs_stitch_step"),
		_hero("tinker", 6, "any_head_needle_pin", "any_arm_red_thread", "warden_torso_rivet", "warden_legs_stride"),
		_hero("monk", 5, "s1b_test_head", "warden_arm_brace", "any_torso_felt_coat", "any_legs_stitch_step"),
	]
	var foes: Array = []
	for i in range(3):
		var effects: Dictionary = {}
		var critical := 0
		if special == "crit":
			critical = 100
		elif special == "snip" and i == 0:
			effects = {"snip": 1}
		elif special == "shove" and i == 0:
			effects = {"push": 1}
		elif special == "pull" and i == 0:
			effects = {"pull": 1}
		elif special == "tear" and i == 0:
			effects = {"tear": 1}
		elif special == "fray":
			effects = {"fray": 7}
		var dmg := [2, 2]
		if special == "heavy" and i == 0:
			dmg = [55, 55]
		if special == "modifiers" and i == 0:
			dmg = [10, 10]
		foes.append({
			"id": "foe_%d" % i, "name": "Foe %d" % i, "max_hp": 30,
			"speed": i + 1, "dodge": 0, "acc": 0, "prot": 0,
			"abilities": [_ability("foe_hit", "melee", effects, dmg, critical)],
		})
	if special == "modifiers":
		foes[0]["abilities"][0]["acc"] = 70
	return {"seed": seed_value, "parts": parts, "heroes": heroes, "foes": foes, "candle": light}

func _battle(seed_value: int, light: int = 100, special: String = "") -> StitchedRules:
	var built := StitchedRules.create(_config(seed_value, light, special))
	_check(bool(built["ok"]), "AC1: four real heroes and three foes build: " + str(built["error"]))
	if not built["ok"]:
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3, "AC1: true 4v3 precondition")
	return battle

func _to(battle: StitchedRules, actor_id: String, limit: int = 110) -> bool:
	for step in range(limit):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor_id:
			return true
		if not bool(battle.pass_turn()["ok"]):
			return false
	return not battle.is_over() and battle.current_actor_id() == actor_id

func _to_side(battle: StitchedRules, side: String, limit: int = 110) -> bool:
	for step in range(limit):
		if battle.is_over():
			return false
		if battle.current_side() == side:
			return true
		if not bool(battle.pass_turn()["ok"]):
			return false
	return false

func _snapshot(battle: StitchedRules) -> String:
	return JSON.stringify(battle.state_snapshot())

func _test_candle() -> void:
	var edges := [
		[0, "snuffed", 40, 0, 25, 100, "foe", 25],
		[1, "dark", 30, 10, 15, 75, "", 0],
		[25, "dark", 30, 10, 15, 75, "", 0],
		[26, "gloom", 20, 5, 10, 50, "", 0],
		[50, "gloom", 20, 5, 10, 50, "", 0],
		[51, "dim", 10, 0, 0, 25, "", 0],
		[75, "dim", 10, 0, 0, 25, "", 0],
		[76, "bright", 0, 0, 0, 0, "hero", 15],
		[100, "bright", 0, 0, 0, 0, "hero", 15],
	]
	for row in edges:
		var band := StitchedS1BEffects.candle_band(int(row[0]))
		_check(not band.is_empty(), "AC4: candle band exists at " + str(row[0]))
		if band.is_empty():
			continue
		var keys := ["name", "fray_percent", "enemy_acc", "enemy_damage_percent", "loot_percent", "opening_side", "opening_percent"]
		for i in range(keys.size()):
			_check(band[keys[i]] == row[i + 1], "AC4: exact " + keys[i] + " at candle " + str(row[0]))
		_check(StitchedS1BEffects.fray_gain(10, int(row[0])) == int(10 + int(row[2]) / 10), "AC4: candle fray projection")
	var battle := _battle(21)
	if battle == null:
		return
	_check(battle.candle() == 100 and battle.candle_band()["name"] == "bright", "AC4: seeded battle begins Bright 100")
	var before := _snapshot(battle)
	_check(not bool(battle.adjust_candle("node", 5)["ok"]) and _snapshot(battle) == before, "AC4: bad node delta is atomic")
	_check(int(battle.adjust_candle("node")["after"]) == 92, "AC4: entering node costs eight")
	_check(int(battle.adjust_candle("event", -100)["after"]) == 0, "AC4: event decrease clamps at zero")
	_check(int(battle.adjust_candle("peddler")["after"]) == 25, "AC4: candle stub restores 25")
	_check(int(battle.adjust_candle("campfire")["after"]) == 75, "AC4: wick restores 50")
	_check(int(battle.adjust_candle("event", 100)["after"]) == 100, "AC4: event increase clamps at 100")
	for candle_value in [0, 100]:
		var witnessed: Dictionary = {}
		for seed_value in range(1, 90):
			var a := _battle(seed_value, candle_value)
			var b := _battle(seed_value, candle_value)
			if a == null or b == null:
				return
			var opening := a.opening_strike()
			_check(opening == b.opening_strike() and a.turn_order() == b.turn_order() and a.rng_state() == b.rng_state(), "AC4: opening draw replays at " + str(candle_value))
			witnessed[str(opening["triggered"])] = true
			if witnessed.has("true") and witnessed.has("false"):
				break
		_check(witnessed.has("true") and witnessed.has("false"), "AC4: triggered and untriggered seeded openings at " + str(candle_value))

func _test_fray() -> void:
	var b := _battle(3)
	if b == null:
		return
	var before := _snapshot(b)
	_check(not bool(b.apply_fray_event("unknown", 4)["ok"]) and _snapshot(b) == before, "AC1: unknown fray target is RNG-atomic")
	_check(not bool(b.apply_fray_event("warden", 0)["ok"]) and _snapshot(b) == before, "AC1: zero fray event is RNG-atomic")
	_check(not bool(b.apply_fray_event("warden", 4, "wrong")["ok"]) and _snapshot(b) == before, "AC1: unknown fray source is RNG-atomic")
	var first := b.apply_fray_event("warden", 200)
	_check(bool(first["ok"]) and str(first["transition"]) == "hanging", "AC1: fray 200 enters Hanging")
	var warden := b.get_unit("warden")
	_check(int(warden["hp"]) == 0 and bool(warden["hanging"]) and int(warden["fray"]) == 150, "AC1: 200 resets fray to 150 and HP to zero")
	_check(int(b.get_unit("seamstress")["fray"]) == 8, "AC1: first Hanging adds eight to ally")
	var lost := b.apply_fray_event("warden", 50)
	_check(str(lost["transition"]) == "lost" and bool(b.get_unit("warden")["lost"]), "AC1: fray 200 while Hanging loses doll")
	_check(int(b.get_unit("seamstress")["fray"]) == 33, "AC1: loss adds 25 to surviving allies")
	_check(not bool(b.apply_fray_event("warden", 10)["ok"]), "AC1: cannot fray a lost doll")
	var dark := _battle(10, 1)
	if dark != null:
		var delta := dark.apply_fray_event("warden", 10)
		_check(int(delta["change"]) == 13, "AC1: dark candle increases fray gain by 30 percent")
		_check(int(dark.apply_fray_event("warden", -7, "unpicker")["after"]) == 6, "AC1: Unpicker relief is not multiplied")

func _find_resolve(mood: String, hero_id: String) -> StitchedRules:
	for seed_value in range(1, 250):
		var b := _battle(seed_value)
		if b == null:
			return null
		var receipt := b.apply_fray_event(hero_id, 100)
		if str(receipt["transition"]) == mood:
			return b
	return null

func _event_seen(b: StitchedRules, mood: String, action: String) -> bool:
	for event in b.turn_events():
		if str(event.get("mood", "")) == mood and str(event.get("action", "")) == action:
			return true
	return false

func _test_resolves() -> void:
	for mood in ["steadfast", "frantic", "hollow", "bitter", "reckless", "cowering"]:
		var hero_id := "tinker" if mood == "reckless" else ("monk" if mood == "cowering" else "warden")
		var b := _find_resolve(mood, hero_id)
		_check(b != null, "AC1: seeded 25/75 resolve reached " + mood)
		if b == null:
			continue
		_check(str(b.get_unit(hero_id)["resolve"]) == mood, "AC1: " + mood + " state is stored on real hero")
		if mood == "steadfast":
			_check(int(b.get_unit(hero_id)["fray"]) == 45, "AC1: Steadfast drops to 45")
			_check(StitchedS1BEffects.steadfast_damage(10) == 11, "AC1: Steadfast damage +10%")
			_check(_to(b, hero_id), "AC1: Steadfast actor takes a real turn")
			_check(int(b.get_unit("seamstress")["fray"]) == 0, "AC1: Steadfast party calm floors at zero")
			_check(not bool(b.end_floor()["ok"]), "AC1: active floor refuses early cleanup")
		elif mood == "bitter":
			_check(_to(b, hero_id), "AC1: Bitter hero reaches its real turn")
			_check(_event_seen(b, "bitter", "fray"), "AC1: Bitter frays its adjacent ally on turn")
			_check(int(b.get_unit("seamstress")["fray"]) == 4, "AC1: Bitter applies exactly four adjacent fray")
		elif mood == "reckless":
			_check(_to(b, "tinker"), "AC1: Reckless turn is present after automatic movement")
			# The move consumes the first turn; an event is the nonvacuous witness.
			_check(_event_seen(b, "reckless", "move") or int(b.get_unit("tinker")["rank"]) == 2, "AC1: Reckless moves forward")
		elif mood == "cowering":
			_check(_to(b, "monk"), "AC1: Cowering actor can act at rear")
			var before := _snapshot(b)
			var refused := b.use_part("s1b_test_head", 5)
			_check(not bool(refused["ok"]) and _snapshot(b) == before, "AC1: illegal Cowering melee target never rolls")
			var seen_refusal := false
			for turn in range(25):
				if not _to(b, "monk"):
					break
				var attack := b.use_part("s1b_test_head", 1)
				if str(attack.get("action", "")) == "refused":
					seen_refusal = true
					break
			_check(seen_refusal, "AC1: Cowering refusal occurs at seeded 30% on legal melee")
		elif mood in ["frantic", "hollow"]:
			# Ten full rounds give many 30% opportunities without altering the test state.
			for tick in range(100):
				if b.is_over() or _event_seen(b, mood, "ability" if mood == "frantic" else "pass"):
					break
				b.pass_turn()
			_check(_event_seen(b, mood, "ability" if mood == "frantic" else "pass"), "AC1: " + mood + " acts with seeded 30% chance")
			if mood == "frantic":
				var real_action := false
				for event in b.turn_events():
					if str(event.get("mood", "")) == "frantic":
						real_action = bool(event.get("receipt", {}).get("ok", false))
				_check(real_action, "AC1: Frantic actually resolves a legal part action")
		if mood in ["frantic", "hollow", "bitter", "reckless", "cowering"]:
			var recovery := b.apply_fray_event(hero_id, -60, "event")
			_check(bool(recovery["ok"]) and str(b.get_unit(hero_id)["resolve"]) == "", "AC1: Unravelled clears below fifty")

func _test_battle_fray() -> void:
	var witness := false
	for seed_value in range(1, 65):
		var b := _battle(seed_value, 100, "crit")
		if b == null or not _to_side(b, "foe"):
			return
		var attack := b.use_foe_ability("foe_hit", 1)
		if bool(attack["results"][0]["hit"]):
			_check(bool(attack["results"][0]["crit"]), "AC1: authored enemy guaranteed crit hits")
			_check(int(b.get_unit("warden")["fray"]) == 10, "AC1: enemy crit adds exactly ten target fray")
			witness = true
			break
	_check(witness, "AC1: live foe crit witness found")
	var hero_crit := false
	for seed_value in range(1, 40):
		var b := _battle(seed_value)
		if b == null:
			return
		b.apply_fray_event("warden", 10)
		if not _to(b, "warden"):
			continue
		var receipt := b.use_part("s1b_test_head", 1)
		if receipt["ok"] and bool(receipt["results"][0]["hit"]):
			_check(bool(receipt["results"][0]["crit"]), "AC1: equipped hero crit actually occurred")
			_check(int(b.get_unit("warden")["fray"]) == 7, "AC1: hero crit relieves three")
			hero_crit = true
			break
	_check(hero_crit, "AC1: actual hero critical hit witnessed")
	var round_battle := _battle(35)
	if round_battle != null:
		for tick in range(90):
			if round_battle.round_number() >= 9 or round_battle.is_over():
				break
			round_battle.pass_turn()
		_check(round_battle.round_number() == 9, "AC1: actual 4v3 round nine reached")
		for hero in round_battle.get_heroes():
			_check(int(hero["fray"]) == 3, "AC1: round after eight adds three fray per hero")
	var kills: Dictionary = {}
	for seed_value in range(1, 70):
		var b := _battle(seed_value)
		if b == null:
			return
		# Replace only this foe's authored max HP at construction on the next seed below.
		var cfg := _config(seed_value)
		cfg["foes"][0]["max_hp"] = 1
		var built := StitchedRules.create(cfg)
		if not built["ok"]:
			continue
		b = built["battle"]
		_check(_to(b, "warden"), "AC1: killer hero gets a real turn")
		var kill := b.use_part("s1b_test_head", 1)
		if not kill["ok"] or kill["results"].is_empty():
			continue
		var result: Dictionary = kill["results"][0]
		if result.has("kill_relief_roll"):
			var relieved := int(result["kill_relief_roll"]) <= 50
			_check((int(result.get("kill_fray_relief", 0)) == 3) == relieved, "AC1: seeded 50% kill relief is exact")
			kills[str(relieved)] = true
		if kills.has("true") and kills.has("false"):
			break
	_check(kills.has("true") and kills.has("false"), "AC1: both seeded kill-relief outcomes reached")

func _test_seams() -> void:
	var b := _battle(100)
	if b == null:
		return
	_check(not bool(b.mend_part("warden", "head", 9, 1)["ok"]), "AC2: no mending in battle")
	var first := b.apply_fray_event("warden", 200)
	var torn: Array = []
	var hero := b.get_unit("warden")
	for slot in StitchedParts.SLOTS:
		if bool(hero["parts"][slot]["torn"]):
			torn.append(slot)
	_check(torn.size() == 1 and str(torn[0]) != "torso", "AC2: first Hanging tears one seeded non-torso equipped part")
	_check(not bool(hero["parts"]["torso"]["torn"]), "AC2: torso can never tear")
	_check(bool(first["ok"]) and bool(hero["hanging"]), "AC2: torn seam is in the live Hanging transaction")
	_check(_to(b, "warden"), "AC2: Hanging hero still receives a real turn")
	var part_id := str(hero["parts"][torn[0]]["id"])
	var state := _snapshot(b)
	_check(not bool(b.use_part(part_id, 1)["ok"]) and _snapshot(b) == state, "AC2: torn ability refuses without spending RNG or turn")
	var finished := false
	for attempt in range(20):
		if not _to_side(b, "hero"):
			break
		var result := b.retreat()
		if bool(result["ok"]) and bool(result["success"]):
			finished = true
			break
	_check(finished and b.outcome() == "retreated", "AC2: finished real fight exposes Sewing Circle mending")
	if finished:
		var snapshot := _snapshot(b)
		_check(not bool(b.mend_part("warden", str(torn[0]), 0, 1)["ok"]) and _snapshot(b) == snapshot, "AC2: unaffordable mend is no-spend atomic")
		_check(bool(b.mend_part("warden", str(torn[0]), 3, 2)["ok"]), "AC2: paid Sewing Circle mend succeeds")
		_check(not bool(b.get_unit("warden")["parts"][torn[0]]["torn"]), "AC2: mending restores the formerly torn part")
		_check(not bool(b.mend_part("warden", str(torn[0]), 3, 2)["ok"]), "AC2: untorn part is ineligible")
	var lost_battle := _battle(102)
	if lost_battle == null:
		return
	for id in ["warden", "seamstress"]:
		lost_battle.apply_fray_event(id, 200)
		lost_battle.apply_fray_event(id, 50)
	_check(lost_battle.satchel().size() == 6, "AC2: two lost dolls store at most six parts")
	_check(bool(lost_battle.get_unit("warden")["lost"]) and bool(lost_battle.get_unit("seamstress")["lost"]), "AC2: two lost dolls are actually unpicked")
	_check(not bool(lost_battle.mend_part("warden", "head", 20, 1)["ok"]), "AC2: lost doll cannot be mended")
	var direct := _battle(110)
	if direct != null and _to_side(direct, "foe"):
		var before := direct.get_unit("tinker")
		var tear := direct.tear_part("tinker")
		_check(bool(tear["ok"]) and str(tear["slot"]) != "torso", "AC2: elite direct tear hits non-torso equipped part")
		_check(not bool(before["parts"][tear["slot"]]["torn"]) and bool(direct.get_unit("tinker")["parts"][tear["slot"]]["torn"]), "AC2: direct tear is a real mutation")
		var prior := _snapshot(direct)
		_check(not bool(direct.tear_part("missing")["ok"]) and _snapshot(direct) == prior, "AC2: invalid elite tear is RNG atomic")

func _test_thread() -> void:
	var b := _battle(15)
	if b == null or not _to_side(b, "foe"):
		return
	var cut := b.snip_thread("warden")
	_check(bool(cut["ok"]) and int(cut["after_rank"]) == 1 and b.thread_cuts().size() == 1, "AC3: live foe snips behind named front hero")
	_check(_to(b, "seamstress"), "AC3: healer reaches real turn after cut")
	var before := _snapshot(b)
	_check(not bool(b.use_part("s1b_test_heal", 1)["ok"]) and _snapshot(b) == before, "AC3: cross-cut ally heal is atomic refusal")
	_check(not bool(b.use_part("warden_arm_brace", 1)["ok"]) and _snapshot(b) == before, "AC3: cross-cut Guard is atomic refusal")
	_check(not bool(b.move(-1)["ok"]) and _snapshot(b) == before, "AC3: adjacent swap across cut is atomic refusal")
	_check(_to(b, "warden"), "AC3: snipped hero reaches a turn")
	var state := _snapshot(b)
	_check(not bool(b.move(1)["ok"]) and _snapshot(b) == state, "AC3: snipped hero cannot move")
	_check(bool(b.re_tie()["ok"]) and b.thread_cuts().is_empty(), "AC3: own Re-tie costs turn and clears cut")
	_check(_to(b, "seamstress"), "AC3: healer reaches a second turn after Re-tie")
	var restored_heal := b.use_part("s1b_test_heal", 1)
	_check(bool(restored_heal["ok"]), "AC3: same legal heal reaches across restored thread: " + str(restored_heal))
	var shift_battle := _battle(17)
	if shift_battle != null and _to_side(shift_battle, "foe"):
		_check(bool(shift_battle.snip_thread("tinker")["ok"]), "AC3: foe can cut behind rank three")
		_check(_to(shift_battle, "tinker"), "AC3: cut owner reaches turn")
		var immutable := _snapshot(shift_battle)
		_check(not bool(shift_battle.use_part("warden_legs_stride", 3)["ok"]) and _snapshot(shift_battle) == immutable, "AC3: self-movement cannot move snipped hero")
	var finish := _battle(19)
	if finish != null and _to_side(finish, "foe"):
		_check(bool(finish.snip_thread("warden")["ok"]), "AC3: fight-end cleanup starts with real cut")
		var retreated := false
		for retry in range(20):
			if not _to_side(finish, "hero"):
				break
			var result := finish.retreat()
			if bool(result["ok"]) and bool(result["success"]):
				retreated = true
				break
		_check(retreated and finish.thread_cuts().is_empty(), "AC3: retreat clears all cuts at fight end")

func _trace(seed_value: int) -> Dictionary:
	var b := _battle(seed_value, 26, "fray")
	var receipts: Array = []
	if b == null:
		return {}
	for step in range(55):
		if b.is_over():
			break
		var actor := b.current_actor_id()
		var receipt: Dictionary = {}
		if b.current_side() == "hero":
			if actor == "warden":
				receipt = b.use_part("s1b_test_head", 1)
				if not receipt["ok"]:
					receipt = b.pass_turn()
			else:
				receipt = b.pass_turn()
		else:
			receipt = b.use_foe_ability("foe_hit", 1)
		receipts.append(receipt)
	return {"receipts": receipts, "snapshot": b.state_snapshot(), "steps": receipts.size()}

func _test_replay() -> void:
	var first := _trace(5704)
	var second := _trace(5704)
	_check(int(first.get("steps", 0)) > 15, "AC1/3: replay actually drives real S1a turns and attacks")
	_check(first == second, "AC1/3: two identical seeded S1b 4v3 traces replay exactly")

func _test_enemy_effects() -> void:
	# These are authored enemy ability effects applied through the S1a hit path,
	# not direct calls to their internal implementation.
	for special in ["snip", "tear", "shove", "pull", "fray", "heavy"]:
		var witnessed := false
		for seed_value in range(1, 65):
			var light := 26 if special == "fray" else 100
			var b := _battle(seed_value, light, special)
			if b == null or not _to(b, "foe_0"):
				continue
			var target_rank := 3 if special in ["shove", "pull"] else 1
			var before_target := b.get_unit("tinker" if target_rank == 3 else "warden")
			var result := b.use_foe_ability("foe_hit", target_rank)
			if not result["ok"] or result["results"].is_empty():
				continue
			var hit: Dictionary = result["results"][0]
			if not bool(hit["hit"]):
				continue
			witnessed = true
			match special:
				"snip":
					_check(bool(hit.get("snip", {}).get("ok", false)) and b.thread_cuts().has("warden"), "AC3: authored enemy Snip cuts behind hit hero")
				"tear":
					_check(bool(hit.get("tear", {}).get("ok", false)) and not bool(b.get_unit("warden")["parts"]["torso"]["torn"]), "AC2: authored elite Rip tears a non-torso part")
				"shove":
					_check(bool(hit.get("shift", {}).get("ok", false)), "AC3: hit enemy shove swaps adjacent heroes")
					_check(int(before_target["rank"]) == 3 and int(b.get_unit("tinker")["rank"]) == 4, "AC3: shove moves rank three hero back")
				"pull":
					_check(bool(hit.get("shift", {}).get("ok", false)) and int(b.get_unit("tinker")["rank"]) == 2, "AC3: hit enemy pull moves rank three hero forward")
				"fray":
					_check(int(b.get_unit("warden")["fray"]) == 9, "AC1: enemy fray attack applies candle-adjusted seven to nine")
					_check(int(hit.get("fray_event", {}).get("change", 0)) == 9, "AC1: real foe effect receipt exposes exact fray delta")
				"heavy":
					var unit := b.get_unit("warden")
					_check(int(unit["hp"]) == 0 and bool(unit["hanging"]), "AC2: real enemy hit first enters Hanging at zero")
					_check(bool(hit.get("tear", {}).get("ok", false)), "AC2: real first Hanging hit tears a seeded part")
					_check(int(b.get_unit("seamstress")["fray"]) == 8, "AC1: real first Hanging frays an ally by eight")
			break
		_check(witnessed, "AC1/2/3: nonvacuous enemy " + special + " hit witness")
	var illegal := _config(49)
	illegal["foes"][0]["abilities"][0]["effects"] = {"snip": 2}
	_check(not bool(StitchedRules.create(illegal)["ok"]), "AC3: malformed two-step Snip effect is fail-closed")
	var cower := _find_resolve("cowering", "tinker")
	if cower != null:
		_check(_to(cower, "tinker"), "AC1: Cowering at rank three advances turns")
		_check(_event_seen(cower, "cowering", "move") and int(cower.get_unit("tinker")["rank"]) == 4, "AC1: Cowering moves backwards before manual action")


func _test_enemy_modifiers() -> void:
	# Different opening rolls may shift hit RNG, so require a confirmed hit in each
	# band rather than treating a miss as a vacuous damage check.
	for sample in [[100, 70], [75, 70], [50, 75], [25, 80], [0, 70]]:
		var candle_value := int(sample[0])
		var witnessed := false
		for seed_value in range(1, 100):
			var b := _battle(seed_value, candle_value, "modifiers")
			if b == null or not _to(b, "foe_0"):
				continue
			var target_before := b.get_unit("warden")
			var receipt := b.use_foe_ability("foe_hit", 1)
			if not receipt["ok"] or receipt["results"].is_empty():
				continue
			var attack: Dictionary = receipt["results"][0]
			if not bool(attack["hit"]):
				continue
			witnessed = true
			_check(int(attack["hit_chance"]) == StitchedRules.hit_chance(int(sample[1]), int(target_before["dodge"]), 0), "AC4: actual foe hit chance includes band ACC at " + str(candle_value))
			var raw_damage := StitchedS1BEffects.enemy_damage(10, candle_value)
			var expected := StitchedRules.apply_protection(raw_damage, int(target_before["prot"]))
			_check(int(attack["damage"]) == expected, "AC4: actual foe damage includes candle increase before PROT at " + str(candle_value))
			break
		_check(witnessed, "AC4: real hit witnessed at candle " + str(candle_value))


func _test_reckless_guard() -> void:
	var b := _find_resolve("reckless", "warden")
	if b == null:
		return
	_check(_to(b, "seamstress"), "AC1: guarding ally gets a real turn")
	var guarded := b.use_part("warden_arm_brace", 1)
	_check(bool(guarded["ok"]), "AC1: ally Guard is successfully in effect")
	if not guarded["ok"]:
		return
	_check(_to(b, "foe_0"), "AC1: enemy gets a real turn while guard is active")
	var before := b.get_unit("seamstress")
	_check(int(before["statuses"].get("guard", 0)) > 0, "AC1: guardian remains active at attack time")
	var attack := b.use_foe_ability("foe_hit", 1)
	if attack["ok"] and not attack["results"].is_empty():
		var target: Dictionary = attack["results"][0]
		_check(str(target["target"]) == "warden" and not target.has("guarded_by"), "AC1: Reckless target ignores an actual allied Guard")


func _test_mode_independence() -> void:
	var setting: Variant = ProjectSettings.get_setting("patchwork/combat_mode")
	var reference: Dictionary = {}
	for old_setting in [null, "cards", "banana", 42, {}]:
		ProjectSettings.set_setting("patchwork/combat_mode", old_setting)
		_check(not _config(5704).has("mode"), "AC4: S1b fixture genuinely omits mode")
		var trace := _trace(5704)
		_check(int(trace.get("steps", 0)) > 15, "AC4: no-mode S1b replay exercises real turns")
		if reference.is_empty():
			reference = trace
		_check(trace == reference, "AC4: S1b seeded trace ignores retired setting " + str(old_setting))
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = 20
	for forged in ["cards", "unknown", 42, false, null, [], {}]:
		var cfg := _config(20)
		cfg["mode"] = forged
		cfg["run_rng"] = run_rng
		var before := run_rng.state
		var blocked := StitchedRules.create(cfg)
		_check(not blocked["ok"] and blocked["battle"] == null and not str(blocked["error"]).is_empty(),
			"AC4: S1b rejects forged explicit mode " + str(forged))
		_check(run_rng.state == before, "AC4: rejected S1b mode cannot spend run RNG")
	ProjectSettings.set_setting("patchwork/combat_mode", setting)


# An accepted witness always goes through the public, seeded four-hero/three-foe
# combat actions. Failed hits and turns skipped before observation are not counted.
func _stun_clock_case(seed_value: int, victim_side: String, lethal: bool = false, guard: bool = false) -> Dictionary:
	var config := _config(seed_value)
	var timed := {"stun": 1, "bleed": 2, "weak": 2, "exposed": 2}
	if victim_side == "foe":
		for part in config["parts"]:
			if str(part["id"]) == "s1b_test_head":
				part["ability"]["effects"] = timed.duplicate()
				part["ability"]["dmg"] = [0, 0]
		if lethal:
			config["foes"][0]["max_hp"] = 2  # Direct hit is zero; Bleed-2 makes the heap.
	else:
		config["foes"][0]["abilities"][0]["effects"] = timed.duplicate()
		config["foes"][0]["abilities"][0]["dmg"] = [0, 0]
		if lethal:
			config["heroes"][0]["hp"] = 2  # Carried HP, not an already-Hanging fixture.
		if guard:
			for part in config["parts"]:
				if str(part["id"]) == "warden_arm_brace":
					part["ability"]["effects"]["guard"] = 1
	var built := StitchedRules.create(config)
	if not bool(built["ok"]):
		return {}
	var b: StitchedRules = built["battle"]
	if b.get_heroes().size() != 4 or b.get_foes().size() != 3:
		return {}
	var victim_id := "foe_0" if victim_side == "foe" else ("seamstress" if guard else "warden")
	var guard_receipt: Dictionary = {}
	if guard:
		if not _to(b, "seamstress"):
			return {}
		guard_receipt = b.use_part("warden_arm_brace", 1)
		if not bool(guard_receipt.get("ok", false)):
			return {}
		var guarding := b.get_unit("seamstress")
		if int(guarding["statuses"].get("guard", 0)) != 1 or str(guarding["guard_target"]) != "warden":
			return {}
	if not _to(b, "warden" if victim_side == "foe" else "foe_0"):
		return {}
	var attack: Dictionary = b.use_part("s1b_test_head", 1) if victim_side == "foe" else b.use_foe_ability("foe_hit", 2 if guard else 1)
	if not bool(attack.get("ok", false)) or attack.get("results", []).is_empty():
		return {}
	var hit: Dictionary = attack["results"][0]
	if not bool(hit.get("hit", false)) or str(hit.get("target", "")) != victim_id:
		return {}
	var before := b.get_unit(victim_id)
	var statuses: Dictionary = before["statuses"]
	for key in timed:
		if int(statuses.get(key, 0)) != int(timed[key]):
			return {}
	if guard and int(statuses.get("guard", 0)) != 1:
		return {}
	if int(before["hp"]) <= 0:
		return {}  # Direct lethal damage is not a Bleed-turn witness.
	var pre_invalid := b.state_snapshot()
	var rng_pre_invalid := b.rng_state()
	var wrong: Dictionary = b.use_part("not_equipped_stun_probe", 1) if b.current_side() == "hero" else b.use_foe_ability("not_an_enemy_ability", 1)
	var atomic := not bool(wrong.get("ok", false)) and b.state_snapshot() == pre_invalid and b.rng_state() == rng_pre_invalid
	var actors: Array = []
	var receipts: Array = []
	var states: Array = [pre_invalid]
	var orders: Array = [b.turn_order()]
	var rngs: Array = [rng_pre_invalid]
	var witnessed_skip := false
	for _step in range(55):
		if int(b.get_unit(victim_id)["statuses"].get("stun", 0)) == 0:
			witnessed_skip = true
			break
		if b.is_over() or b.current_actor_id() == victim_id:
			break
		actors.append(b.current_actor_id())
		var passing := b.pass_turn()
		if not bool(passing.get("ok", false)):
			break
		receipts.append(passing)
		states.append(b.state_snapshot())
		orders.append(b.turn_order())
		rngs.append(b.rng_state())
	if not witnessed_skip or actors.is_empty() or victim_id in actors:
		return {}
	var after := b.get_unit(victim_id)
	var trace := {
		"seed": seed_value, "victim_side": victim_side, "lethal": lethal, "guard": guard,
		"guard_receipt": guard_receipt, "attack": attack, "wrong": wrong,
		"actors": actors, "receipts": receipts, "states": states,
		"orders": orders, "rng_states": rngs, "final_snapshot": b.state_snapshot(),
		"final_rng": b.rng_state(),
	}
	return {
		"battle": b, "before": before, "after": after, "atomic": atomic,
		"trace": trace, "hit": hit, "actors": actors, "guard": guard_receipt,
	}


func _test_stun_clock() -> void:
	# Both sides are actually struck and actually skipped in the real turn loop,
	# with two independent seed witnesses and matching full receipts/RNG per side.
	for side in ["hero", "foe"]:
		var witnessed := 0
		for seed_value in range(1, 110):
			var sample := _stun_clock_case(seed_value, side)
			if sample.is_empty():
				continue
			var again := _stun_clock_case(seed_value, side)
			_check(not again.is_empty() and sample["trace"] == again.get("trace", {}),
				"AC3: independent replay preserves %s receipts, snapshots, order and RNG at seed %d" % [side, seed_value])
			_check(bool(sample["atomic"]), "AC3: invalid %s action is state/RNG-atomic" % side)
			var before: Dictionary = sample["before"]
			var after: Dictionary = sample["after"]
			var active: Dictionary = after["statuses"]
			_check(int(before["hp"]) > 2 and int(after["hp"]) == int(before["hp"]) - 2,
				"AC1: stunned %s takes exactly first Bleed-2 HP loss" % side)
			_check(int(active.get("bleed", 0)) == 1 and int(active.get("weak", 0)) == 1
				and int(active.get("exposed", 0)) == 1 and int(active.get("stun", 0)) == 0,
				"AC1: stunned %s consumes Stun and decrements all three timed clocks once" % side)
			_check(int(active.get("stun_resist", 0)) == 1 and not bool(after["dead"])
				and not bool(after["hanging"]),
				"AC1/3: surviving %s gains fresh resistance after all other clocks" % side)
			var scheduled := false
			for order in sample["trace"]["orders"]:
				if str(after["id"]) in order:
					scheduled = true
			_check(scheduled and not sample["actors"].is_empty() and not (str(after["id"]) in sample["actors"])
				and str(sample["hit"]["target"]) == str(after["id"]),
				"AC1: rolled order includes struck %s, but its Stunned action is skipped" % side)
			witnessed += 1
			if witnessed == 2:
				break
		_check(witnessed == 2, "AC1/3: two distinct seeded %s Stun/Bleed/timed-status witnesses" % side)

	# Bleed, not direct attack damage, kills the stunned foe into exactly one heap;
	# a Stun on the Hanging doll must not create a phantom resist or second tear.
	for side in ["hero", "foe"]:
		var witnessed := false
		for seed_value in range(1, 110):
			var sample := _stun_clock_case(seed_value, side, true)
			if sample.is_empty():
				continue
			var b: StitchedRules = sample["battle"]
			var before: Dictionary = sample["before"]
			var after: Dictionary = sample["after"]
			_check(bool(sample["atomic"]), "AC3: lethal %s witness also rejects invalid actions atomically" % side)
			_check(int(before["hp"]) > 0 and int(after["hp"]) == 0
				and int(before["statuses"].get("stun", 0)) == 1,
				"AC2: %s entered the skipped turn alive and Stunned, then Bleed killed" % side)
			_check(int(after["statuses"].get("stun_resist", 0)) == 0
				and int(after["statuses"].get("stun", 0)) == 0,
				"AC2: lethal %s Bleed leaves neither Stun nor phantom resistance" % side)
			if side == "foe":
				var heaps := b.get_heaps()
				_check(bool(after["dead"]) and after["statuses"].is_empty(),
					"AC2: lethal foe clears timed statuses and is dead")
				_check(heaps.size() == 1 and str(heaps[0]["foe_id"]) == "foe_0"
					and int(heaps[0]["hp"]) == StitchedRules.heap_hp_for(int(after["max_hp"])),
					"AC2: lethal skipped foe leaves exactly one correctly sized heap")
				_check(b.current_actor_id() != "foe_0",
					"AC2: the Bleed-killed foe receives no phantom action")
			else:
				var torn := 0
				for slot in ["head", "arms", "legs"]:
					if bool(after["parts"][slot]["torn"]):
						torn += 1
				_check(bool(after["hanging"]) and not bool(after["lost"]) and torn == 1,
					"AC2: lethal skipped hero enters Hanging with exactly one non-torso tear")
				_check(int(b.get_unit("seamstress")["fray"]) == 8,
					"AC2: a single Hanging entry frays an ally exactly once")
				if _to(b, "warden"):
					var later := b.get_unit("warden")
					var later_torn := 0
					for slot in ["head", "arms", "legs"]:
						if bool(later["parts"][slot]["torn"]):
							later_torn += 1
					_check(bool(later["hanging"]) and later_torn == 1,
						"AC2: later Hanging turn does not tear a second part")
			var another := _stun_clock_case(seed_value, side, true)
			_check(not another.is_empty() and sample["trace"] == another.get("trace", {}),
				"AC3: lethal %s seeded receipt/snapshot/RNG replay is exact" % side)
			witnessed = true
			break
		_check(witnessed, "AC2: nonvacuous lethal %s Bleed/Stun witness" % side)

	var guard_seen := false
	for seed_value in range(1, 110):
		var guarded := _stun_clock_case(seed_value, "hero", false, true)
		if guarded.is_empty():
			continue
		var prev: Dictionary = guarded["before"]
		var now: Dictionary = guarded["after"]
		_check(bool(guarded["guard"].get("ok", false))
			and int(prev["statuses"].get("guard", 0)) == 1
			and str(prev["guard_target"]) == "warden",
			"AC2: real guard was active on seamstress before her Stunned turn")
		_check(not now["statuses"].has("guard") and str(now["guard_target"]) == "",
			"AC2: Guard countdown expires and clears its target on skipped turn")
		_check(int(now["statuses"].get("stun_resist", 0)) == 1,
			"AC1: expiring Guard does not suppress fresh Stun resistance")
		guard_seen = true
		break
	_check(guard_seen, "AC2: nonvacuous landed enemy Stun on guarded hero")

	# A second *landed* hit while resist stands is refused. Its clock then
	# falls off at the foe's following start, not at the stunned start.
	var refused_seen := false
	for seed_value in range(1, 110):
		var sample := _stun_clock_case(seed_value, "foe")
		if sample.is_empty():
			continue
		var b: StitchedRules = sample["battle"]
		var refused: Dictionary = {}
		var resisted := false
		for _step in range(55):
			if b.is_over() or int(b.get_unit("foe_0")["statuses"].get("stun_resist", 0)) != 1:
				break
			if b.current_actor_id() in ["warden", "monk"]:
				var attempt := b.use_part("s1b_test_head", 1)
				if bool(attempt.get("ok", false)) and not attempt["results"].is_empty() and bool(attempt["results"][0].get("hit", false)):
					refused = attempt
					for effect in attempt["results"][0]["statuses"]:
						if str(effect["status"]) == "stun" and bool(effect.get("refused", false)):
							resisted = true
					break
			else:
				if not bool(b.pass_turn()["ok"]):
					break
		if not resisted:
			continue
		_check(int(sample["after"]["statuses"].get("stun_resist", 0)) == 1
			and str(refused["results"][0]["target"]) == "foe_0",
			"AC3: the second landed Stun hits the same actively resistant foe")
		_check(int(b.get_unit("foe_0")["statuses"].get("stun", 0)) == 0,
			"AC3: resisted second hit does not reapply Stun")
		var countdown_seen := int(b.get_unit("foe_0")["statuses"].get("stun_resist", 0)) == 0
		for _step in range(55):
			if countdown_seen or b.is_over():
				break
			if not bool(b.pass_turn()["ok"]):
				break
			countdown_seen = int(b.get_unit("foe_0")["statuses"].get("stun_resist", 0)) == 0
		_check(countdown_seen, "AC3: resistance expires on foe's following start-of-turn")
		refused_seen = true
		break
	_check(refused_seen, "AC3: a second landed Stun is nonvacuously refused by resistance")
