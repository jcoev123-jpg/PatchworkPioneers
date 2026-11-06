extends SceneTree
## Canonical catalog -> real seeded rules -> mounted battle driver. No substitute combat engine.

const MANTIS := "shearwing_mantis"
const HERO_IDS := ["warden", "seamstress", "tinker", "lantern_monk"]
var failures: Array[String] = []
var checks := 0
var catalog: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _run() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)), "canonical catalog validates: " + str(catalog.get("error")))
	if bool(catalog.get("ok", false)):
		_test_authored()
		_test_slash()
		_test_sweep()
		_test_refusals()
		_test_intent_and_replay()
		await _test_live_driver()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_shearwing_line_cut_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_authored() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	_check(parsed is Array and not parsed.is_empty(), "authored run enemy JSON is a nonempty array")
	if not parsed is Array:
		return
	var raw: Dictionary = {}
	for record in parsed:
		if record.get("id") == MANTIS:
			raw = record
	_check(not raw.is_empty(), "Mantis is present in the real catalog")
	if raw.is_empty():
		return
	var slash := {"id": "shear_slash", "name": "Shear Slash", "kind": "melee",
		"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
		"acc": 86, "dmg": [4, 6], "crit": 0, "effects": {"snip": 1}, "self_move": 0, "move": "attack2"}
	var wing := {"id": "wing_shear", "name": "Wing Shear", "kind": "debuff",
		"launch": [1, 3], "target": [1, 2, 3], "target_side": "enemy", "multi": true,
		"acc": 88, "dmg": [0, 0], "crit": 0, "effects": {"bleed": 2}, "self_move": 0, "move": "skill"}
	_check(raw["stitched"] == JSON.parse_string(JSON.stringify({"max_hp": 26, "speed": 6, "dodge": 7, "acc": 0, "prot": 2,
		"is_boss": false, "turns_per_round": 1, "trophy": "shearwing_mantis_shear_wing",
		"abilities": [slash, wing]})), "exact authored Stitched profile including both complete moves and trophy")
	var legacy := raw.duplicate(true)
	legacy.erase("stitched")
	_check(legacy == JSON.parse_string(JSON.stringify({"id": MANTIS, "name": "Shearwing Mantis", "max_hp": 26,
		"chew_block_on_attack": true, "art_path": "res://assets/paper/enemies/shearwing_mantis.png",
		"intent": {"target": "front", "actions": [
			{"type": "snip_block", "amount": 0, "weight": 2},
			{"type": "attack", "amount": 8, "weight": 3},
			{"type": "attack", "amount": 6, "hits": 2, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 9, "move": "attack3", "weight": 1}]}})),
		"entire legacy Mantis record remains unchanged")
	var foe := StitchedEnemyCatalog.foe_for(catalog, MANTIS)
	_check(not foe.is_empty() and foe.get("max_hp") == 26 and foe.get("speed") == 6
		and foe.get("dodge") == 7 and foe.get("acc") == 0 and foe.get("prot") == 2
		and foe.get("is_boss") == false and foe.get("turns_per_round") == 1
		and StitchedEnemyCatalog.trophy_for(catalog, MANTIS) == "shearwing_mantis_shear_wing",
		"foe_for resolves unchanged canonical stats and foreign trophy")
	for authored in [slash, wing]:
		var validated := StitchedParts.validate_ability(authored)
		_check(bool(validated.get("ok", false)), "authored move validates through real parts validator")
		if bool(validated.get("ok", false)):
			_check(foe["abilities"].has(validated["ability"]), "foe_for carries the exact validated authored move")


func _config(seed_value: int, launch_rank: int = 1) -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stitched/s2_preview.json"))
	_check(config.get("heroes", []).size() == 4 and not config.get("parts", []).is_empty(),
		"real S2 four-doll / sewn-part input exists")
	config["seed"] = seed_value
	config["parts"].append_array(catalog["parts"].duplicate(true))
	var foes: Array = [StitchedEnemyCatalog.foe_for(catalog, "ragling"),
		StitchedEnemyCatalog.foe_for(catalog, "scissor_crab")]
	foes.insert(launch_rank - 1, StitchedEnemyCatalog.foe_for(catalog, MANTIS))
	# Exercise both legal fight-entry sizes, without altering any foe's stats or kit.
	if launch_rank == 2:
		foes.pop_back()
	config["foes"] = foes
	return config


func _battle(seed_value: int, launch_rank: int = 1) -> StitchedRules:
	var built := StitchedRules.create(_config(seed_value, launch_rank))
	_check(bool(built.get("ok", false)), "canonical 4v2/3 battle builds: " + str(built.get("error")))
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.is_valid() and battle.get_heroes().size() == 4
		and battle.get_foes().size() == (2 if launch_rank == 2 else 3), "nonvacuous live battle preconditions")
	return battle


# Public legal Pass actions reach the real speed-rolled turn; never set a turn pointer/round.
func _to(battle: StitchedRules, actor: String, minimum_round: int = 1) -> bool:
	for step in range(60):
		if battle.is_over():
			break
		if battle.current_actor_id() == actor and battle.round_number() >= minimum_round:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			break
	_check(false, "failed to reach legal turn for " + actor)
	return false


func _refuse(battle: StitchedRules, action: Callable, error: String) -> void:
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipt: Dictionary = action.call()
	_check(not bool(receipt.get("ok", true)) and str(receipt.get("error", "")) == error,
		"exact existing refusal contract: " + error + " / " + str(receipt))
	_check(battle.state_snapshot() == state and battle.rng_state() == rng,
		"refusal preserves every unit, cut, status, turn, order and RNG")


func _test_slash() -> void:
	var hits := 0
	var misses := 0
	var duplicate_hits := 0
	for launch in [1, 2]:
		for rank in [1, 2]:
			var local_hits := 0
			var local_misses := 0
			for seed_value in range(1, 49):
				var b := _battle(seed_value, launch)
				if b == null or not _to(b, MANTIS):
					return
				var target_id: String = HERO_IDS[rank - 1]
				var before := b.get_unit(target_id)
				var allies := b.get_heroes().duplicate(true)
				var receipt := b.use_foe_ability("shear_slash", rank)
				_check(bool(receipt.get("ok", false)) and receipt.get("actor") == MANTIS
					and receipt.get("results", []).size() == 1, "legal Slash emits exactly one real result")
				if receipt.get("results", []).size() != 1:
					return
				var result: Dictionary = receipt["results"][0]
				_check(result["target"] == target_id and result["target_rank"] == rank, "Slash targets requested front rank")
				for ally in allies:
					if ally["id"] != target_id:
						_check(b.get_unit(ally["id"]) == ally, "Slash leaves every untargeted ally unchanged")
				if not bool(result["hit"]):
					misses += 1
					local_misses += 1
					_check(result["damage"] == 0 and not result.has("snip") and result["statuses"].is_empty()
						and b.thread_cuts().is_empty() and b.get_unit(target_id) == before, "genuine Slash miss has no damage/cut/status")
					continue
				hits += 1
				local_hits += 1
				var damages: Array = []
				for base in ([StitchedRules.crit_damage(6)] if result["crit"] else [4, 5, 6]):
					damages.append(StitchedRules.apply_protection(base, int(before["prot"])))
				_check(damages.has(result["damage"]) and int(result["damage"]) > 0
					and int(b.get_unit(target_id)["hp"]) == int(before["hp"]) - int(result["damage"]),
					"landed Slash deals canonical 4-6 / critical damage through actual PROT")
				_check(result.get("snip") == {"ok": true, "action": "snip", "hero": target_id, "after_rank": rank}
					and b.thread_cuts() == {target_id: rank}, "Slash cuts exactly the boundary behind struck hero")
				# A second landed Slash must leave the same single cut, not duplicate it.
				if _to(b, MANTIS, b.round_number() + 1):
					var repeated := b.use_foe_ability("shear_slash", rank)
					if bool(repeated["results"][0]["hit"]):
						duplicate_hits += 1
						_check(repeated["results"][0]["snip"].get("ok") == false, "already cut boundary refuses duplicate SNIP")
					_check(b.thread_cuts() == {target_id: rank}, "repeated Slash leaves one exact cut")
				var neighbor: String = HERO_IDS[rank]
				if not _to(b, neighbor):
					return
				_refuse(b, func(): return b.move(-1), "thread cut blocks the swap")
				_refuse(b, func(): return b.re_tie(), "this hero's thread is not snipped")
				if not _to(b, target_id):
					return
				_refuse(b, func(): return b.move(1), "the snipped hero cannot move")
				var old_round := b.round_number()
				var old_index := int(b.state_snapshot()["turn_index"])
				var tied := b.re_tie()
				_check(tied == {"ok": true, "action": "re_tie", "actor": target_id} and b.thread_cuts().is_empty()
					and ((b.round_number() == old_round and int(b.state_snapshot()["turn_index"]) == old_index + 1)
						or (b.round_number() == old_round + 1 and int(b.state_snapshot()["turn_index"]) == 0)),
					"own on-turn RE-TIE clears the cut and spends exactly one turn")
				if _to(b, neighbor):
					_check(bool(b.move(-1).get("ok", false)), "same crossing move succeeds after RE-TIE")
			_check(local_hits > 0 and local_misses > 0, "hit and miss witnesses for each Slash launch/target pair")
	_check(hits > 0 and misses > 0 and duplicate_hits > 0, "nonvacuous Slash hits, misses and repeated landed cuts")


func _test_sweep() -> void:
	var ticks := 0
	for launch in [1, 3]:
		var hit_ranks: Dictionary = {}
		var miss_ranks: Dictionary = {}
		var mixed := 0
		for seed_value in range(1, 49):
			var b := _battle(seed_value, launch)
			if b == null or not _to(b, MANTIS):
				return
			var before := b.get_heroes().duplicate(true)
			var receipt := b.use_foe_ability("wing_shear", 1 + seed_value % 3)
			_check(bool(receipt.get("ok", false)) and receipt.get("results", []).size() == 3,
				"Wing Shear checks all three occupied front ranks independently")
			var landed := 0
			var ranks: Array = []
			for result in receipt.get("results", []):
				var rank := int(result["target_rank"])
				ranks.append(rank)
				var target_id := str(result["target"])
				_check(rank >= 1 and rank <= 3 and target_id == HERO_IDS[rank - 1]
					and result["damage"] == 0 and not result["crit"] and result.has("roll")
					and result["target_hp"] == before[rank - 1]["hp"], "each sweep result has its own hit roll and zero direct damage")
				if result["hit"]:
					landed += 1
					hit_ranks[rank] = true
					_check(result["statuses"] == [{"status": "bleed", "duration": 2}], "confirmed Wing hit applies exactly Bleed 2")
				else:
					miss_ranks[rank] = true
					_check(result["statuses"].is_empty() and b.get_unit(target_id)["statuses"].is_empty(), "Wing miss applies no Bleed")
				# use_foe_ability advances into the next actor, which may already have ticked.
				var ticked: bool = result["hit"] and b.current_actor_id() == target_id
				_check(int(b.get_unit(target_id)["hp"]) == int(before[rank - 1]["hp"]) - (2 if ticked else 0)
					and int(b.get_unit(target_id)["statuses"].get("bleed", 0)) == (1 if ticked else (2 if result["hit"] else 0)),
					"actual post-action status/HP distinguishes immediate own-turn tick from direct damage")
			_check(ranks == [1, 2, 3] and b.get_unit(HERO_IDS[3]) == before[3] and b.thread_cuts().is_empty(),
				"rank four has no result or mutation and sweep never SNIPs")
			if landed > 0 and landed < 3:
				mixed += 1
			# Visit the next start for ALL hit heroes in turn order (not in rank order,
			# which could wrap a round and tick one hero twice before inspecting it).
			var pending: Dictionary = {}
			for result in receipt.get("results", []):
				if result["hit"]:
					pending[result["target"]] = int(result["target_rank"])
			for step in range(15):
				var actor := b.current_actor_id()
				if pending.has(actor):
					var unit := b.get_unit(actor)
					_check(int(unit["hp"]) == int(before[int(pending[actor]) - 1]["hp"]) - 2
						and unit["statuses"].get("bleed") == 1, "true next hero turn ticks Bleed 2 and counts down to 1")
					if int(unit["prot"]) > 0:
						ticks += 1
					pending.erase(actor)
				if pending.is_empty():
					break
				_check(bool(b.pass_turn().get("ok", false)), "legal Pass reaches next Bleed turn start")
			_check(pending.is_empty(), "every landed sweep target reaches its real next turn start")
		_check(hit_ranks.has(1) and hit_ranks.has(2) and hit_ranks.has(3)
			and miss_ranks.has(1) and miss_ranks.has(2) and miss_ranks.has(3) and mixed > 0,
			"each legal Wing launch has hits/misses at every rank and mixed sweep witnesses")
	_check(ticks > 0, "nonvacuous Bleed ticks ignore positive PROT on real equipped heroes")
	_test_protected_bleed()
	var vacant := _battle(93, 3)
	if vacant != null:
		_lose(vacant, HERO_IDS[1])
		if _to(vacant, MANTIS):
			var choice := StitchedFoeIntent.choose(vacant, vacant.get_unit(MANTIS))
			var receipt := vacant.use_foe_ability("wing_shear", 1)
			var ranks: Array = []
			for result in receipt.get("results", []):
				ranks.append(result["target_rank"])
			_check(choice.get("affected_ranks") == [1, 3] and ranks == [1, 3]
				and vacant.get_unit(HERO_IDS[1])["statuses"].is_empty(), "partial vacancy is skipped by both intent and actual sweep")


func _test_protected_bleed() -> void:
	var witnesses := 0
	for seed_value in range(1, 13):
		var config := _config(seed_value)
		# The ordinary party's low PROT rounds a two-point direct hit back to two.
		# Use a carried high-PROT fixture to distinguish bypass from that rounding.
		# All four authored heroes, sewn parts and canonical foes remain real inputs.
		config["heroes"][0]["prot"] = 80
		var built := StitchedRules.create(config)
		_check(built.get("ok") == true, "high-PROT carried party builds through real rules")
		if not bool(built.get("ok", false)):
			return
		var b: StitchedRules = built["battle"]
		if not _to(b, MANTIS):
			return
		var before := b.get_unit(HERO_IDS[0])
		_check(int(before["prot"]) >= 80 and StitchedRules.apply_protection(2, int(before["prot"])) == 1,
			"PROT fixture would reduce a direct two-point hit to one")
		var receipt := b.use_foe_ability("wing_shear", 1)
		if bool(receipt["results"][0]["hit"]) and _to(b, HERO_IDS[0]):
			witnesses += 1
			_check(int(b.get_unit(HERO_IDS[0])["hp"]) == int(before["hp"]) - 2
				and b.get_unit(HERO_IDS[0])["statuses"].get("bleed") == 1,
				"actual own-turn Bleed loses two through PROT that would reduce direct damage")
	_check(witnesses > 0, "nonvacuous high-PROT bleed bypass witness")


func _lose(b: StitchedRules, hero_id: String) -> void:
	_check(bool(b.apply_fray_event(hero_id, 200).get("ok", false)), "public fray event enters Hanging")
	_check(bool(b.apply_fray_event(hero_id, 200).get("ok", false)) and b.get_unit(hero_id).get("lost") == true,
		"public fray event creates a genuine vacant rank")


func _test_refusals() -> void:
	for launch in [1, 2, 3]:
		var b := _battle(51, launch)
		if b == null:
			return
		if _to(b, HERO_IDS[0]):
			_refuse(b, func(): return b.use_foe_ability("shear_slash", 1), "it is not a foe turn")
		if not _to(b, MANTIS):
			return
		for ability in ["shear_slash", "wing_shear"]:
			if (ability == "shear_slash" and launch == 3) or (ability == "wing_shear" and launch == 2):
				_refuse(b, func(): return b.use_foe_ability(ability, 1), "ability cannot launch from rank %d" % launch)
			else:
				for rank in ([0, 3, 4, 5] if ability == "shear_slash" else [0, 4, 5]):
					_refuse(b, func(): return b.use_foe_ability(ability, rank), "no legal target in rank %d" % rank)
		_check(bool(b.pass_turn()["ok"]), "leave Mantis's turn normally")
		if _to(b, "ragling"):
			_refuse(b, func(): return b.use_foe_ability("shear_slash", 1), "the foe has no ability shear_slash")
	# Single-target vacancy refuses. Multi-target refusal requires ALL authored ranks vacant:
	# its existing gate permits any authored aim rank while another affected rank is occupied.
	var empty := _battle(83)
	if empty == null:
		return
	_lose(empty, HERO_IDS[0])
	if _to(empty, MANTIS):
		_refuse(empty, func(): return empty.use_foe_ability("shear_slash", 1), "no legal target in rank 1")
	_lose(empty, HERO_IDS[1])
	_lose(empty, HERO_IDS[2])
	if _to(empty, MANTIS):
		for rank in [1, 2, 3]:
			_refuse(empty, func(): return empty.use_foe_ability("wing_shear", rank), "no legal target in rank %d" % rank)
		_check(StitchedFoeIntent.choose(empty, empty.get_unit(MANTIS)).get("pass") == true, "no occupied target projects PASS")
	var gated := _battle(71)
	if gated == null or not _to(gated, MANTIS):
		return
	gated.pass_turn()
	# Status/death fixture edits occur BETWEEN turns; the real turn-entry gate must skip them.
	gated._units[MANTIS]["statuses"]["stun"] = 1
	var state := gated.state_snapshot()
	var rng := gated.rng_state()
	var stunned := StitchedFoeIntent.choose(gated, gated.get_unit(MANTIS))
	_check(stunned.get("stun") == true and stunned.get("pass") == true
		and stunned.get("affected_ranks").is_empty() and not stunned.has("base_effects")
		and gated.state_snapshot() == state and gated.rng_state() == rng, "stunned intent is passive and has no invented threat")
	var skipped := false
	for step in range(20):
		if gated.get_unit(MANTIS)["statuses"].get("stun_resist", 0) == 1:
			skipped = true
			break
		gated.pass_turn()
	_check(skipped and gated.current_actor_id() != MANTIS and gated.thread_cuts().is_empty(), "true stun turn-entry consumes Mantis turn without attack")
	var error := "it is not a foe turn" if gated.current_side() == "hero" else "the foe has no ability shear_slash"
	_refuse(gated, func(): return gated.use_foe_ability("shear_slash", 1), error)
	gated._units[MANTIS]["hp"] = 0
	gated._units[MANTIS]["dead"] = true
	state = gated.state_snapshot()
	rng = gated.rng_state()
	for actor in [{}, {"id": "missing"}, gated.get_unit(HERO_IDS[0]), gated.get_unit(MANTIS)]:
		_check(StitchedFoeIntent.choose(gated, actor).is_empty(), "no current foe / wrong side / dead foe has no intent")
	_check(gated.state_snapshot() == state and gated.rng_state() == rng, "empty and dead intent calls preserve full state and RNG")
	for step in range(15):
		_check(gated.current_actor_id() != MANTIS, "dead Mantis never receives a turn")
		gated.pass_turn()
	_refuse(gated, func(): return gated.use_foe_ability("wing_shear", 1),
		"it is not a foe turn" if gated.current_side() == "hero" else "the foe has no ability wing_shear")


func _trace(seed_value: int, launch: int) -> Array:
	var b := _battle(seed_value, launch)
	var trace: Array = []
	if b == null:
		return trace
	for step in range(35):
		var state := b.state_snapshot()
		var rng := b.rng_state()
		var choice := StitchedFoeIntent.choose(b, b.get_unit(MANTIS))
		_check(b.state_snapshot() == state and b.rng_state() == rng, "intent never mutates state or consumes RNG")
		var receipt: Dictionary
		if b.current_actor_id() == MANTIS:
			var expected_id := "wing_shear" if launch == 3 or (launch == 1 and b.round_number() % 2 == 0) else "shear_slash"
			_check(choice.get("ability_id") == expected_id and choice.get("multi") == (expected_id == "wing_shear")
				and choice.get("affected_ranks") == ([1, 2, 3] if expected_id == "wing_shear" else [1])
				and choice.get("base_effects") == ({"bleed": 2} if expected_id == "wing_shear" else {"snip": 1})
				and choice.get("base_damage") == ([0, 0] if expected_id == "wing_shear" else [4, 6]),
				"real round/launch rotation projects exact ability, multi, ranks, base effects and damage")
			receipt = b.use_foe_ability(str(choice["ability_id"]), int(choice["target_rank"]))
			var ranks: Array = []
			for result in receipt.get("results", []):
				ranks.append(result["target_rank"])
			_check(receipt.get("ok") == true and receipt.get("ability") == choice["ability_id"]
				and ranks == choice["affected_ranks"], "projected intent matches actual committed receipt")
		elif b.current_side() == "hero" and b.thread_cuts().has(b.current_actor_id()):
			receipt = b.re_tie()
		else:
			receipt = b.pass_turn()
		_check(receipt.get("ok") == true, "replay sequence uses only successful legal actions")
		trace.append({"receipt": receipt, "state": b.state_snapshot(), "rng": b.rng_state(), "order": b.turn_order()})
	return trace


func _test_intent_and_replay() -> void:
	for launch in [1, 2, 3]:
		for seed_value in [2, 11, 37]:
			var first := _trace(seed_value, launch)
			_check(first.size() == 35 and first == _trace(seed_value, launch), "same seed/actions replay whole receipts, snapshots, order and RNG exactly")


func _test_live_driver() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(_config(23)), "real battle screen begins with canonical Mantis and real S2 party")
	if screen.battle == null:
		screen.free()
		return
	root.add_child(screen)
	await process_frame
	var seen: Dictionary = {}
	for step in range(16):
		for receipt in screen.receipts:
			if receipt.get("actor") == MANTIS and receipt.get("action") == "ability":
				seen[receipt["ability"]] = true
				if receipt["ability"] == "wing_shear":
					_check(receipt.get("results", []).size() == 3, "mounted automatic foe driver commits actual front-three sweep")
		if seen.has("shear_slash") and seen.has("wing_shear"):
			break
		_check(screen.battle.current_side() == "hero" and bool(screen.submit_pass().get("ok", false)),
			"real player Pass drives seeded automatic foe turns")
	_check(seen.has("shear_slash") and seen.has("wing_shear"), "nonvacuous mounted live driver reaches both canonical Mantis moves")
	screen.free()
