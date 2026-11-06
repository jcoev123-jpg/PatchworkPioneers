extends SceneTree
## S4 Button Golem: validate the authored catalog and exercise real seeded S2 battle rules.
## A copied preview replaces only rank-2 Seamstress; no shipped roster or preview is changed.
const CATALOG_PATH := "res://data/parts/button_golem_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const STARTERS := {
	"head": "button_golem_head_loose_pop",
	"arms": "button_golem_arms_button_fist",
	"torso": "button_golem_torso_seam_resew",
	"legs": "button_golem_legs_threadwheel_roll",
}
const ALTERNATES := {
	"head": "button_golem_head_buttonhole_snag",
	"arms": "button_golem_arms_popping_volley",
	"torso": "button_golem_torso_eyelet_guard",
	"legs": "button_golem_legs_button_roll",
}
const IDS := [
	"button_golem_head_loose_pop", "button_golem_arms_button_fist",
	"button_golem_torso_seam_resew", "button_golem_legs_threadwheel_roll",
	"button_golem_head_buttonhole_snag", "button_golem_arms_popping_volley",
	"button_golem_torso_eyelet_guard", "button_golem_legs_button_roll",
]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_all_tiers()
	_test_mark_bonus()
	_test_volley()
	_test_volley_rank_four()
	_test_volley_mark_bonus()
	_test_volley_miss()
	_test_guard_interception()
	_test_wheels()
	_test_illegal()
	_test_replay()
	for f in failures:
		printerr(f)
	print("stitched_s4_button_golem_parts_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(CATALOG_PATH)


func _config(selected: String = "", tier: int = 1, seed_value: int = 503041) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	_check(parsed is Dictionary, "AC2: real preview parses")
	if not parsed is Dictionary:
		return {}
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)), "AC1: catalog validates: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		return {}
	var cfg: Dictionary = parsed
	_check(str(cfg["heroes"][1]["id"]) == "seamstress", "AC2: rank 2 is original Seamstress")
	var equipped := {}
	for slot in STARTERS:
		var id: String = STARTERS[slot]
		if catalog["by_id"].has(selected) and str(catalog["by_id"][selected]["slot"]) == slot:
			id = selected
		equipped[slot] = {"id": id, "tier": tier}
	cfg["heroes"][1] = {
		"id": "button_golem", "name": "Button Golem", "max_hp": 36,
		"speed": 5, "dodge": 6, "acc": 6, "prot": 0, "parts": equipped,
	}
	cfg["parts"].append_array(catalog["parts"])
	cfg["seed"] = seed_value
	return cfg


func _battle(selected: String = "", tier: int = 1, seed_value: int = 503041) -> StitchedRules:
	var cfg := _config(selected, tier, seed_value)
	if cfg.is_empty():
		return null
	var built := StitchedRules.create(cfg)
	_check(bool(built.get("ok", false)), "AC2: real rules create: " + str(built.get("error", "")))
	if not bool(built.get("ok", false)):
		return null
	var b: StitchedRules = built["battle"]
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
		and int(b.get_unit("button_golem").get("rank", -1)) == 2
		and b.get_unit("button_golem").get("parts", {}).size() == 4,
		"AC2: actual 4v3 with rank-two four-part Golem")
	for id in ["warden", "tinker", "lantern_monk", "fray_scavenger", "scissor_crab", "moth_scribe"]:
		_check(not b.get_unit(id).is_empty(), "AC2: original real unit retained: " + id)
	return b


func _to(b: StitchedRules, id: String, maximum: int = 60) -> bool:
	for step in range(maximum):
		if b.is_over():
			return false
		if b.current_actor_id() == id:
			return true
		if not bool(b.pass_turn().get("ok", false)):
			return false
	return false


func _rank_for(id: String) -> int:
	if id == STARTERS["torso"] or id == STARTERS["legs"] or id == ALTERNATES["legs"]:
		return 2
	return 1


func _power(a: Dictionary, id: String) -> int:
	if id == STARTERS["head"]:
		return int(a["effects"].get("mark", 0))
	if id == STARTERS["arms"]:
		return int(a.get("mark_damage", 0))
	if id == STARTERS["torso"]:
		return int(a["effects"].get("thorns", 0))
	if id == STARTERS["legs"] or id == ALTERNATES["legs"]:
		return int(a["effects"].get("dodge", 0))
	if id == ALTERNATES["head"]:
		return int(a["effects"].get("tangled", 0))
	if id == ALTERNATES["arms"]:
		return int(a["dmg"][0])
	return int(a["effects"].get("guard", 0))


func _test_catalog() -> void:
	var c := _catalog()
	_check(bool(c.get("ok", false)), "AC1: eight-part JSON validates")
	if not bool(c.get("ok", false)):
		return
	_check(c["parts"].size() == 8, "AC1: exactly eight Golem parts")
	var seen := {}
	var moves := {}
	var counts := {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	for p in c["parts"]:
		var id := str(p["id"])
		var slot := str(p["slot"])
		_check(id in IDS and not seen.has(id) and str(p["owner"]) == "button_golem",
			"AC1: unique expected Golem part " + id)
		seen[id] = true
		counts[slot] += 1
		var a: Dictionary = p["ability"]
		_check(not moves.has(str(a["id"])) and str(a["id"]).begins_with("button_golem_"),
			"AC1: unique native ability id " + id)
		moves[str(a["id"])] = true
		_check(str(a["move"]) in StitchedParts.MOVE_POSES and
			int(a["launch_mask"]) == StitchedParts.rank_mask(a["launch"]) and
			int(a["target_mask"]) == StitchedParts.rank_mask(a["target"]) and
			int(a["launch_mask"]) > 0 and int(a["target_mask"]) > 0,
			"AC1: valid named pose and real rank masks " + id)
		_check(p["tiers"].has("2") and p["tiers"].has("3"), "AC1: both improvement tiers " + id)
		for tier in [1, 2, 3]:
			var at := StitchedParts.ability_at_tier(p, tier)
			var stats := StitchedParts.stat_at_tier(p, tier)
			_check(bool(StitchedParts.validate_ability(at).get("ok", false)),
				"AC1: tier %d ability validates %s" % [tier, id])
			_check(not stats.is_empty(), "AC1: tier %d slot stat exists %s" % [tier, id])
			for key in stats:
				_check(str(key) in StitchedParts.SLOT_STATS[slot],
					"AC1: tier %d stat matches %s slot" % [tier, slot])
			if tier > 1:
				_check(_power(at, id) > _power(StitchedParts.ability_at_tier(p, tier - 1), id),
					"AC1: each tier improves a real supported number %s" % id)
			for invalid in ["block", "spend_block", "buttons_popped", "hit_count",
				"independent_hits", "block_per_button_popped", "damage_per_button_popped"]:
				_check(not at.has(invalid) and not at["effects"].has(invalid),
					"AC1: no ignored retired card mechanic " + id)
	for slot in counts:
		_check(counts[slot] == 2 and c["by_id"].has(STARTERS[slot])
			and c["by_id"].has(ALTERNATES[slot])
			and str(c["by_id"][STARTERS[slot]]["slot"]) == slot
			and str(c["by_id"][ALTERNATES[slot]]["slot"]) == slot,
			"AC1: exact two starter/pool look pairing for " + slot)
	_test_volley_catalog(c)
	_check(c["by_id"][STARTERS["arms"]]["ability"]["mark_damage"] > 0,
		"AC1: Button Fist consumes native Mark synergy")
	for id in [STARTERS["legs"], ALTERNATES["legs"]]:
		var a: Dictionary = c["by_id"][id]["ability"]
		_check(a["target_side"] == "self" and a["effects"].has("dodge")
			and a["effects"].has("duration") and abs(int(a["self_move"])) == 1,
			"AC1: wheel is bounded adjacent self-move plus temporary Dodge")
	var illegal: Dictionary = c["by_id"][ALTERNATES["head"]].duplicate(true)
	illegal["ability"]["target"] = [1, 5]
	_check(not bool(StitchedParts.validate_part(illegal).get("ok", false)),
		"AC3: illegal rank rejects schema validation")
	illegal = c["by_id"][STARTERS["legs"]].duplicate(true)
	illegal["tiers"]["2"]["ability"]["effects"] = {"dodge": 8}
	_check(not bool(StitchedParts.validate_part(illegal).get("ok", false)),
		"AC3: Dodge without duration rejects tier validation")
	illegal = c["by_id"][STARTERS["head"]].duplicate(true)
	illegal["tiers"]["4"] = {"ability": {"acc": 100}}
	_check(not bool(StitchedParts.validate_part(illegal).get("ok", false)),
		"AC3: illegal IV tier rejected")
	_check(not bool(StitchedParts.build_catalog([c["parts"][0], c["parts"][0]]).get("ok", false)),
		"AC3: duplicate part IDs fail closed")


func _test_all_tiers() -> void:
	for id in IDS:
		for tier in [1, 2, 3]:
			var witnessed := false
			for seed_value in range(503051, 503067):
				var b := _battle(id, tier, seed_value)
				if b == null or not _to(b, "button_golem"):
					continue
				var ability: Dictionary = StitchedParts.ability_at_tier(_catalog()["by_id"][id], tier)
				var before := b.state_snapshot()
				var hp_before := {}
				for foe_id in ["fray_scavenger", "scissor_crab", "moth_scribe"]:
					hp_before[foe_id] = int(b.get_unit(foe_id)["hp"])
				var cast := b.use_part(id, _rank_for(id))
				_check(bool(cast.get("ok", false)) and str(cast.get("actor", "")) == "button_golem"
					and str(cast.get("part", "")) == id and str(cast.get("ability", "")) == str(ability["id"]),
					"AC2: live scheduled %s tier %d action resolves" % [id, tier])
				if not bool(cast.get("ok", false)):
					continue
				var results: Array = cast.get("results", [])
				var expected := 3 if bool(ability["multi"]) else 1
				var distinct := {}
				for receipt in results:
					distinct[str(receipt["target"])] = true
				_check(results.size() == expected and distinct.size() == expected
					and b.state_snapshot() != before,
					"AC2: genuine state change and one receipt per target %s tier %d" % [id, tier])
				for receipt in results:
					if not bool(receipt.get("hit", false)):
						continue
					var target_id := str(receipt["target"])
					if str(ability["target_side"]) == "enemy":
						_check(str(receipt["target_side"]) == "foe"
							and target_id in ["fray_scavenger", "scissor_crab", "moth_scribe"],
							"AC2: foe hit uses actual S2 enemy")
						if int(ability["dmg"][1]) > 0:
							_check(int(receipt.get("damage", 0)) > 0
								and int(receipt.get("target_hp", -1)) == maxi(0, int(hp_before[target_id]) - int(receipt["damage"]))
								and int(b.get_unit(target_id)["hp"]) == int(receipt["target_hp"]),
								"AC2: native damage receipt matches real foe HP aftermath")
						if id == STARTERS["head"] or id == ALTERNATES["head"]:
							var status := "mark" if id == STARTERS["head"] else "tangled"
							_check(receipt["statuses"].any(func(s): return str(s.get("status", "")) == status)
								and int(b.get_unit(target_id)["statuses"].get(status, 0)) > 0,
								"AC2: native hostile status receipt and persistent real-foe state " + status)
					elif id == ALTERNATES["torso"]:
						_check(str(b.get_unit("button_golem")["guard_target"]) == "warden"
							and receipt["statuses"].any(func(s): return str(s.get("status", "")) == "guard"),
							"AC2: ally Guard and guard-target authoritative state")
					elif id == STARTERS["torso"]:
						_check(int(b.get_unit("button_golem")["statuses"].get("thorns", 0)) > 0
							and receipt["statuses"].any(func(s): return str(s.get("status", "")) == "thorns"),
							"AC2: native self Thorns persisted")
					else:
						_check(int(b.get_unit("button_golem")["dodge_buff"].get("amount", 0)) > 0
							and receipt["statuses"].any(func(s): return str(s.get("status", "")) == "dodge")
							and bool(cast.get("self_move", {}).get("ok", false)),
							"AC2: wheel's actual Dodge and swap receipt")
					witnessed = true
				if witnessed:
					break
			_check(witnessed, "AC2: each %s tier %d actually hits/executes, not vacuous" % [id, tier])


func _test_mark_bonus() -> void:
	var witnessed := false
	for seed_value in range(503180, 503240):
		var marked := _battle(STARTERS["arms"], 3, seed_value)
		var plain := _battle(STARTERS["arms"], 3, seed_value)
		if marked == null or plain == null or not _to(marked, "button_golem") or not _to(plain, "button_golem"):
			continue
		var first := marked.use_part(STARTERS["head"], 1)
		if first != plain.use_part(STARTERS["head"], 1) or not bool(first.get("ok", false)):
			continue
		if first.get("results", []).is_empty() or not bool(first["results"][0].get("hit", false)):
			continue
		plain._units["fray_scavenger"]["statuses"].erase("mark")
		if not _to(marked, "button_golem") or not _to(plain, "button_golem"):
			continue
		if int(marked.get_unit("fray_scavenger")["statuses"].get("mark", 0)) <= 0:
			continue
		if marked.rng_state() != plain.rng_state():
			continue
		var boosted := marked.use_part(STARTERS["arms"], 1)
		var base := plain.use_part(STARTERS["arms"], 1)
		if not bool(boosted.get("ok", false)) or not bool(base.get("ok", false)):
			continue
		var a: Dictionary = boosted["results"][0]
		var n: Dictionary = base["results"][0]
		if bool(a.get("hit", false)) and bool(n.get("hit", false)):
			witnessed = (int(a["damage"]) > int(n["damage"])
				and marked.rng_state() == plain.rng_state())
			if witnessed:
				break
	_check(witnessed, "AC2: matched seeded real Marked fist hit exceeds otherwise identical unmarked hit")


func _test_volley() -> void:
	var witnessed := false
	for seed_value in range(503240, 503300):
		var b := _battle(ALTERNATES["arms"], 2, seed_value)
		if b == null or not _to(b, "button_golem"):
			continue
		var cast := b.use_part(ALTERNATES["arms"], 1)
		if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 3:
			continue
		var distinct := {}
		var ranks := {}
		var hits := 0
		for r in cast["results"]:
			distinct[str(r["target"])] = true
			ranks[int(r["target_rank"])] = true
			if bool(r["hit"]) and int(r["damage"]) > 0:
				hits += 1
		witnessed = (distinct.has("fray_scavenger") and distinct.has("scissor_crab")
			and distinct.has("moth_scribe") and hits == 3
			and ranks.has(1) and ranks.has(2) and ranks.has(3) and not ranks.has(4)
			and b.get_foes().size() == 3)
		if witnessed:
			break
	_check(witnessed, "AC2: real Popping Volley hits each of three unique foes exactly once")


## A real 4v3 preview battle with Popping Volley equipped on the rank-2 Golem, then the
## existing third foe moved into enemy rank 4 in this battle's own memory only. Rank 3 stays
## vacant, ranks 1 and 2 keep their real foes, and exactly three foes remain.
func _rank_four_battle(tier: int, seed_value: int) -> StitchedRules:
	var cfg := _config(ALTERNATES["arms"], tier, seed_value)
	if cfg.is_empty():
		return null
	var built := StitchedRules.create(cfg)
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	if not battle._units.has("moth_scribe"):
		return null
	battle._units["moth_scribe"]["rank"] = 4
	return battle


## One real scheduled Golem turn on the relocated fixture, with the pre/post snapshots needed
## for a same-seed replay check.
func _rank_four_cast(tier: int, seed_value: int) -> Dictionary:
	var battle := _rank_four_battle(tier, seed_value)
	if battle == null or not _to(battle, "button_golem"):
		return {}
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var moth_hp := int(battle.get_unit("moth_scribe")["hp"])
	var cast := battle.use_part(ALTERNATES["arms"], 4)
	return {
		"battle": battle,
		"cast": cast,
		"before": before,
		"rng_before": rng,
		"after": battle.state_snapshot(),
		"rng_after": battle.rng_state(),
		"moth_hp": moth_hp,
		"seed": seed_value,
	}


func _test_volley_rank_four() -> void:
	for tier in [1, 2, 3]:
		var structure := {}
		var landed := {}
		var landed_seed := 0
		for seed_value in range(504500, 504560):
			var attempt := _rank_four_cast(tier, seed_value)
			if attempt.is_empty():
				continue
			var attempt_battle: StitchedRules = attempt["battle"]
			if (int(attempt_battle.get_unit("moth_scribe")["rank"]) != 4
				or bool(attempt_battle.get_unit("moth_scribe")["dead"])
				or int(attempt_battle.get_unit("fray_scavenger")["rank"]) != 1
				or int(attempt_battle.get_unit("scissor_crab")["rank"]) != 2
				or attempt_battle.get_foes().any(func(foe): return int(foe["rank"]) == 3)):
				continue
			var cast: Dictionary = attempt["cast"]
			if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 3:
				continue
			if structure.is_empty():
				structure = attempt
			var moth := _receipt_for(cast["results"], "moth_scribe")
			if not moth.is_empty() and bool(moth.get("hit", false)) and int(moth.get("damage", 0)) > 0:
				landed = attempt
				landed_seed = seed_value
				break
		_check(not structure.is_empty(),
			"AC2: tier %d reaches a real rank-4 volley cast in a bounded seed range" % tier)
		if structure.is_empty():
			continue
		var battle: StitchedRules = structure["battle"]
		var cast: Dictionary = structure["cast"]
		var ranks := {}
		var targets := {}
		var foes_only := true
		for receipt in cast["results"]:
			ranks[int(receipt["target_rank"])] = true
			targets[str(receipt["target"])] = true
			foes_only = foes_only and str(receipt["target_side"]) == "foe"
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
			and int(battle.get_unit("button_golem")["rank"]) == 2,
			"AC2: tier %d keeps the real four-hero/three-foe battle with the Golem in rank 2" % tier)
		_check(int(battle.get_unit("moth_scribe")["rank"]) == 4
			and int(battle.get_unit("fray_scavenger")["rank"]) == 1
			and int(battle.get_unit("scissor_crab")["rank"]) == 2
			and battle.get_foes().all(func(foe): return int(foe["rank"]) != 3),
			"AC2: tier %d only the existing Moth Scribe stands in enemy rank 4 and rank 3 is empty" % tier)
		_check(cast["results"].size() == 3 and ranks.size() == 3
			and ranks.has(1) and ranks.has(2) and ranks.has(4) and not ranks.has(3),
			"AC2: tier %d volley receipts exactly the occupied ranks 1, 2 and 4" % tier)
		_check(targets.size() == 3 and targets.has("fray_scavenger")
			and targets.has("scissor_crab") and targets.has("moth_scribe") and foes_only,
			"AC2: tier %d volley receipts each living foe once on the enemy side" % tier)
		_check(str(cast.get("actor", "")) == "button_golem"
			and str(cast.get("part", "")) == ALTERNATES["arms"]
			and str(cast.get("ability", "")) == "button_golem_arms_popping_volley_move",
			"AC2: tier %d rank-4 volley runs as the equipped Golem arms action" % tier)
		_check(int(structure["before"].get("turn_index", -1)) != int(structure["after"].get("turn_index", -2))
			or int(structure["before"].get("round", -1)) != int(structure["after"].get("round", -2)),
			"AC2: tier %d accepted rank-4 volley spends one scheduled turn" % tier)
		_check(battle.current_actor_id() != "button_golem",
			"AC2: tier %d the Golem no longer holds the turn after the volley" % tier)
		_check(structure["before"] != structure["after"]
			and int(structure["rng_before"]) != int(structure["rng_after"]),
			"AC2: tier %d the accepted volley changes authoritative state and seeded RNG" % tier)
		_check(not landed.is_empty(),
			"AC2: tier %d bounded fixed-seed volley lands real damage on the rank-4 foe" % tier)
		if landed.is_empty():
			continue
		var landed_battle: StitchedRules = landed["battle"]
		var moth_hit := _receipt_for(landed["cast"]["results"], "moth_scribe")
		var moth := landed_battle.get_unit("moth_scribe")
		_check(not moth_hit.is_empty() and bool(moth_hit.get("hit", false))
			and int(moth_hit.get("damage", 0)) > 0 and int(moth_hit.get("target_rank", 0)) == 4
			and int(moth["hp"]) == int(landed["moth_hp"]) - int(moth_hit["damage"])
			and int(moth_hit.get("target_hp", -1)) == int(moth["hp"]),
			"AC2: tier %d landed rank-4 receipt drops the real Moth Scribe HP" % tier)
		var replay := _rank_four_cast(tier, landed_seed)
		_check(not replay.is_empty() and replay["cast"] == landed["cast"]
			and replay["before"] == landed["before"] and replay["after"] == landed["after"]
			and int(replay["rng_after"]) == int(landed["rng_after"]),
			"AC2: tier %d equal-seed replay reproduces the receipt, snapshot and RNG" % tier)
	# AC3: the untouched three-foe preview genuinely has no foe at enemy rank 4. A multi volley
	# receipts only the occupied ranks its mask allows, so aiming there adds no phantom rear
	# target; aims outside an authored mask and single-target rear aims are atomic refusals.
	var plain := _battle(ALTERNATES["arms"], 1, 504561)
	if plain == null or not _to(plain, "button_golem"):
		_check(false, "AC3: untouched preview reaches a real Golem turn")
	else:
		_check(plain.get_foes().all(func(foe): return int(foe["rank"]) != 4),
			"AC3: untouched preview genuinely has no foe in enemy rank 4")
		_reject(plain, ALTERNATES["arms"], 0, "volley target rank zero")
		_reject(plain, ALTERNATES["arms"], 5, "volley target rank five")
		_reject(plain, STARTERS["head"], 4, "single-target Loose Button Pop has no rank-four target")
		_reject(plain, ALTERNATES["head"], 4, "Buttonhole Snag's authored mask excludes rank four")
		var before := plain.state_snapshot()
		var rng := plain.rng_state()
		var anchored := plain.use_part(ALTERNATES["arms"], 4)
		var anchored_ranks := {}
		var anchored_targets := {}
		if bool(anchored.get("ok", false)):
			for receipt in anchored["results"]:
				anchored_ranks[int(receipt["target_rank"])] = true
				anchored_targets[str(receipt["target"])] = true
		_check(bool(anchored.get("ok", false)) and anchored.get("results", []).size() == 3
			and anchored_targets.size() == 3 and anchored_ranks.has(1) and anchored_ranks.has(2)
			and anchored_ranks.has(3) and not anchored_ranks.has(4)
			and plain.current_actor_id() != "button_golem"
			and before != plain.state_snapshot() and rng != plain.rng_state(),
			"AC3: a vacant enemy rank 4 yields no phantom receipt and still spends the one turn")
	var torn_cfg := _config(ALTERNATES["arms"], 1, 504562)
	if not torn_cfg.is_empty():
		torn_cfg["heroes"][1]["parts"]["arms"]["torn"] = true
		var torn_built := StitchedRules.create(torn_cfg)
		_check(bool(torn_built.get("ok", false)), "AC3: torn volley equipment builds before its cast")
		if bool(torn_built.get("ok", false)):
			var torn: StitchedRules = torn_built["battle"]
			if _to(torn, "button_golem"):
				_reject(torn, ALTERNATES["arms"], 4, "torn Popping Volley")
			else:
				_check(false, "AC3: torn volley battle reaches the Golem turn")
	var bare := _battle("", 1, 504563)
	if bare == null or not _to(bare, "button_golem"):
		_check(false, "AC3: unequipped volley battle reaches the Golem turn")
	else:
		_reject(bare, ALTERNATES["arms"], 4, "Popping Volley not equipped")
	for hero_rank in [3, 4]:
		var cfg := _config(ALTERNATES["arms"], 1, 504564 + hero_rank)
		if cfg.is_empty():
			_check(false, "AC3: rank-%d Golem configuration builds" % hero_rank)
			continue
		var golem: Dictionary = cfg["heroes"].pop_at(1)
		cfg["heroes"].insert(hero_rank - 1, golem)
		var made := StitchedRules.create(cfg)
		_check(bool(made.get("ok", false)), "AC3: rank-%d Golem battle builds" % hero_rank)
		if not bool(made.get("ok", false)):
			continue
		var rear: StitchedRules = made["battle"]
		if not _to(rear, "button_golem"):
			_check(false, "AC3: rank-%d Golem receives its scheduled turn" % hero_rank)
			continue
		_check(int(rear.get_unit("button_golem")["rank"]) == hero_rank,
			"AC3: the Golem really stands in hero rank %d" % hero_rank)
		_reject(rear, ALTERNATES["arms"], 1, "volley cannot launch from hero rank %d" % hero_rank)


func _test_volley_catalog(c: Dictionary) -> void:
	var part: Dictionary = c["by_id"][ALTERNATES["arms"]]
	_check(str(part["id"]) == "button_golem_arms_popping_volley"
		and str(part["owner"]) == "button_golem" and str(part["slot"]) == "arms"
		and int(part["stat"].get("dmg", 0)) == 2,
		"AC1: Popping Volley keeps its id, owner, arms slot and dmg stat")
	var rows := [
		{"tier": 1, "dmg": [2, 3], "mark": 2},
		{"tier": 2, "dmg": [3, 4], "mark": 3},
		{"tier": 3, "dmg": [4, 6], "mark": 4},
	]
	for row in rows:
		var tier := int(row["tier"])
		var at := StitchedParts.ability_at_tier(part, tier)
		var target_mask := int(at["target_mask"])
		var launch_mask := int(at["launch_mask"])
		_check(str(at["id"]) == "button_golem_arms_popping_volley_move"
			and str(at["kind"]) == "ranged" and str(at["target_side"]) == "enemy"
			and bool(at["multi"]) and at["launch"] == [1, 2] and at["target"] == [1, 2, 3, 4]
			and launch_mask == StitchedParts.rank_mask([1, 2])
			and target_mask == StitchedParts.rank_mask([1, 2, 3, 4])
			and int(at["acc"]) == 89 and at["dmg"] == row["dmg"] and int(at["crit"]) == 0
			and int(at["self_move"]) == 0 and at["effects"] == {} and str(at["move"]) == "attack2",
			"AC1: Popping Volley keeps native ranks/ACC/damage/pose at tier %d" % tier)
		_check(int(at["mark_damage"]) == int(row["mark"]),
			"AC1: Popping Volley tier %d authored mark_damage is %d" % [tier, int(row["mark"])])
		for rank in [1, 2]:
			_check(StitchedParts.ranks_allowed(launch_mask, rank)
				and StitchedParts.ranks_allowed(target_mask, rank),
				"AC1: Popping Volley tier %d launches from and reaches rank %d" % [tier, rank])
		for rank in [3, 4]:
			_check(not StitchedParts.ranks_allowed(launch_mask, rank)
				and StitchedParts.ranks_allowed(target_mask, rank),
				"AC1: Popping Volley tier %d reaches foe rank %d but cannot launch there" % [tier, rank])
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(target_mask, rank),
				"AC1: Popping Volley tier %d never targets rank %d" % [tier, rank])
	var text := str(part["text"]).to_lower()
	_check(text.contains("occupied") and text.contains("marked")
		and text.contains("extra damage") and not text.contains("three foe ranks"),
		"AC1: Popping Volley text names every occupied rank and the Marked extra damage")
	var unchanged := {
		STARTERS["head"]: {"launch": [1, 2], "target": [1, 2], "stat": {"acc": 5}},
		STARTERS["arms"]: {"launch": [1, 2], "target": [1, 2], "stat": {"dmg": 1}},
		STARTERS["torso"]: {"launch": [1, 2, 3], "target": [1, 2, 3], "stat": {"max_hp": 6, "prot": 3}},
		STARTERS["legs"]: {"launch": [1, 2, 3], "target": [1, 2, 3], "stat": {"speed": 2}},
		ALTERNATES["head"]: {"launch": [1, 2], "target": [1, 2, 3], "stat": {"crit": 4}},
		ALTERNATES["torso"]: {"launch": [1, 2, 3], "target": [1, 2, 3, 4], "stat": {"max_hp": 5, "prot": 5}},
		ALTERNATES["legs"]: {"launch": [2, 3, 4], "target": [2, 3, 4], "stat": {"dodge": 5}},
	}
	for id in unchanged:
		for tier in [1, 2, 3]:
			var at := StitchedParts.ability_at_tier(c["by_id"][id], tier)
			var stat := StitchedParts.stat_at_tier(c["by_id"][id], tier)
			_check(at["launch"] == unchanged[id]["launch"] and at["target"] == unchanged[id]["target"]
				and int(at["launch_mask"]) == StitchedParts.rank_mask(unchanged[id]["launch"])
				and int(at["target_mask"]) == StitchedParts.rank_mask(unchanged[id]["target"])
				and stat == unchanged[id]["stat"],
				"AC1: %s keeps its authored ranks and slot stat at tier %d" % [id, tier])
	var loose: Dictionary = c["by_id"][STARTERS["head"]]
	_check(int(StitchedParts.ability_at_tier(loose, 1)["effects"]["mark"]) == 2
		and int(StitchedParts.ability_at_tier(loose, 2)["effects"]["mark"]) == 3
		and int(StitchedParts.ability_at_tier(loose, 3)["effects"]["mark"]) == 4,
		"AC1: Loose Button Pop keeps its Mark 2/3/4")
	var fist: Dictionary = c["by_id"][STARTERS["arms"]]
	_check(int(StitchedParts.ability_at_tier(fist, 1)["mark_damage"]) == 3
		and int(StitchedParts.ability_at_tier(fist, 2)["mark_damage"]) == 5
		and int(StitchedParts.ability_at_tier(fist, 3)["mark_damage"]) == 7,
		"AC1: Button Fist keeps its Mark bonus 3/5/7")


func _receipt_for(results: Array, target_id: String) -> Dictionary:
	for receipt in results:
		if str(receipt.get("target", "")) == target_id:
			return receipt
	return {}


## True when the same raw pre-PROT base can produce both receipts: the control damage
## through native PROT, and the Marked damage with the authored bonus added before PROT.
func _mark_bonus_through_protection(
	control_damage: int, marked_damage: int, prot: int, bonus: int
) -> bool:
	for raw in range(0, 201):
		if StitchedRules.apply_protection(raw, prot) == control_damage \
			and StitchedRules.apply_protection(raw + bonus, prot) == marked_damage:
			return true
	return false


func _test_volley_mark_bonus() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(ALTERNATES["arms"]):
		_check(false, "AC2: Popping Volley catalog available for the Mark battle")
		return
	var foe_ids := ["fray_scavenger", "scissor_crab", "moth_scribe"]
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(catalog["by_id"][ALTERNATES["arms"]], tier)
		var bonus := int(ability["mark_damage"])
		var witnessed := false
		for seed_value in range(503600, 503760):
			var marked := _battle(ALTERNATES["arms"], tier, seed_value)
			var plain := _battle(ALTERNATES["arms"], tier, seed_value)
			if marked == null or plain == null:
				continue
			if not _to(marked, "button_golem") or not _to(plain, "button_golem"):
				continue
			var mark_cast := marked.use_part(STARTERS["head"], 1)
			var control_cast := plain.use_part(STARTERS["head"], 1)
			if mark_cast != control_cast or not bool(mark_cast.get("ok", false)):
				continue
			var mark_results: Array = mark_cast.get("results", [])
			if mark_results.size() != 1 or not bool(mark_results[0].get("hit", false)):
				continue
			var target_id := str(mark_results[0]["target"])
			if int(marked.get_unit(target_id)["statuses"].get("mark", 0)) <= 0:
				continue
			# Both siblings applied the same real head action; only the control loses its Mark.
			plain._units[target_id]["statuses"].erase("mark")
			if not _to(marked, "button_golem") or not _to(plain, "button_golem"):
				continue
			if marked.current_actor_id() != "button_golem" or plain.current_actor_id() != "button_golem":
				continue
			if marked.rng_state() != plain.rng_state():
				continue
			if int(marked.get_unit(target_id)["statuses"].get("mark", 0)) <= 0:
				continue
			var hp_before := int(marked.get_unit(target_id)["hp"])
			if hp_before != int(plain.get_unit(target_id)["hp"]):
				continue
			var boosted := marked.use_part(ALTERNATES["arms"], 1)
			var base := plain.use_part(ALTERNATES["arms"], 1)
			if not bool(boosted.get("ok", false)) or not bool(base.get("ok", false)):
				continue
			var boosted_results: Array = boosted.get("results", [])
			var base_results: Array = base.get("results", [])
			if boosted_results.size() != 3 or base_results.size() != 3:
				continue
			var marked_hit := _receipt_for(boosted_results, target_id)
			var control_hit := _receipt_for(base_results, target_id)
			if marked_hit.is_empty() or control_hit.is_empty():
				continue
			# A witness needs a genuine successful hit on the Marked foe in both siblings.
			if not bool(marked_hit.get("hit", false)) or not bool(control_hit.get("hit", false)):
				continue
			var seen := {}
			var ranks := {}
			for receipt in boosted_results:
				var seen_id := str(receipt["target"])
				seen[seen_id] = int(seen.get(seen_id, 0)) + 1
				ranks[int(receipt["target_rank"])] = true
			var others_equal := true
			for other_id in foe_ids:
				if other_id == target_id:
					continue
				var other_marked := _receipt_for(boosted_results, other_id)
				var other_base := _receipt_for(base_results, other_id)
				others_equal = others_equal and not other_marked.is_empty() \
					and not other_base.is_empty() and other_marked == other_base
			var marked_damage := int(marked_hit["damage"])
			var control_damage := int(control_hit["damage"])
			var prot := int(marked.get_unit(target_id).get("prot", 0))
			var spread := false
			for other_id in foe_ids:
				if other_id != target_id \
					and int(marked.get_unit(other_id)["statuses"].get("mark", 0)) > 0:
					spread = true
			_check(seen.size() == 3 and seen.values().all(func(count): return int(count) == 1)
				and ranks.size() == 3 and ranks.has(1) and ranks.has(2) and ranks.has(3),
				"AC2: tier %d volley hits each eligible rank once with no phantom rank four" % tier)
			_check(others_equal,
				"AC2: tier %d unmarked foes take identical damage in both sibling battles" % tier)
			_check(marked_damage > control_damage
				and _mark_bonus_through_protection(control_damage, marked_damage, prot, bonus),
				"AC2: tier %d Marked foe takes the authored +%d pre-PROT damage" % [tier, bonus])
			_check(int(marked.get_unit(target_id)["hp"]) == hp_before - marked_damage
				and int(plain.get_unit(target_id)["hp"]) == hp_before - control_damage,
				"AC2: tier %d final HP reflects the matched receipt damage" % tier)
			_check(int(marked.get_unit(target_id)["statuses"].get("mark", 0)) > 0 and not spread,
				"AC2: tier %d Mark stays on its foe and never spreads" % tier)
			_check(marked.rng_state() == plain.rng_state(),
				"AC2: tier %d matched seeds keep identical RNG after the volley" % tier)
			witnessed = true
			break
		_check(witnessed, "AC2: tier %d witnesses a real Marked Popping Volley hit" % tier)


func _test_volley_miss() -> void:
	var witnessed := false
	for seed_value in range(503760, 503900):
		var b := _battle(ALTERNATES["arms"], 1, seed_value)
		if b == null or not _to(b, "button_golem"):
			continue
		var cast := b.use_part(ALTERNATES["arms"], 1)
		if not bool(cast.get("ok", false)):
			continue
		var missed := false
		var clean := true
		for receipt in cast.get("results", []):
			if bool(receipt.get("hit", false)):
				continue
			missed = true
			clean = clean and int(receipt.get("damage", -1)) == 0 \
				and receipt.get("statuses", []).is_empty() \
				and int(receipt.get("target_hp", -1)) == int(b.get_unit(str(receipt["target"]))["hp"])
		if missed:
			witnessed = clean
			break
	_check(witnessed, "AC2: a real Popping Volley miss deals no damage and applies no status")


func _test_guard_interception() -> void:
	var intercepted := false
	for seed_value in range(503300, 503390):
		var b := _battle(ALTERNATES["torso"], 3, seed_value)
		if b == null or not _to(b, "button_golem"):
			continue
		var guard_cast := b.use_part(ALTERNATES["torso"], 1)
		if not bool(guard_cast.get("ok", false)) or b.get_unit("button_golem")["guard_target"] != "warden":
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var incoming := b.use_foe_ability("sack_swing", 1)
		if bool(incoming.get("ok", false)) and incoming.get("results", []).size() == 1:
			var hit: Dictionary = incoming["results"][0]
			intercepted = (str(hit.get("guarded_by", "")) == "button_golem"
				and str(hit.get("target", "")) == "button_golem")
			if intercepted:
				break
	_check(intercepted, "AC2: real foe strike on rank-one Warden redirected to Golem guarding ally")


func _test_wheels() -> void:
	for id in [STARTERS["legs"], ALTERNATES["legs"]]:
		var b := _battle(id, 2, 503391)
		if b == null or not _to(b, "button_golem"):
			_check(false, "AC2: wheel has scheduled hero turn " + id)
			continue
		var direction := 1 if id == STARTERS["legs"] else -1
		var neighbour := "tinker" if direction == 1 else "warden"
		var before := int(StitchedRules.effective_dodge(b.get_unit("button_golem")))
		var cast := b.use_part(id, 2)
		var moved: Dictionary = cast.get("self_move", {})
		_check(bool(cast.get("ok", false)) and bool(moved.get("ok", false))
			and int(moved.get("from", -1)) == 2 and int(moved.get("to", -1)) == 2 + direction
			and str(moved.get("swapped", "")) == neighbour
			and int(b.get_unit("button_golem")["rank"]) == 2 + direction
			and int(b.get_unit(neighbour)["rank"]) == 2,
			"AC2: wheel ability swaps the real adjacent ally, never an arbitrary ally")
		_check(int(b.get_unit("button_golem")["dodge_buff"].get("amount", 0)) > 0
			and int(b.get_unit("button_golem")["dodge_buff"].get("turns", 0)) > 0
			and int(StitchedRules.effective_dodge(b.get_unit("button_golem"))) > before,
			"AC2: wheel gains genuine temporary Dodge alongside movement")


func _reject(b: StitchedRules, part: String, rank: int, reason: String) -> void:
	var actor := b.current_actor_id()
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var refused := b.use_part(part, rank)
	_check(not bool(refused.get("ok", false)) and not str(refused.get("error", "")).is_empty()
		and actor == b.current_actor_id() and snapshot == b.state_snapshot() and rng == b.rng_state(),
		"AC3: no-turn/no-state/no-RNG illegal action: " + reason)


func _test_illegal() -> void:
	var bad := _config()
	if bad.is_empty():
		return
	bad["heroes"][1]["parts"]["arms"] = {"id": STARTERS["head"], "tier": 1}
	_check(not bool(StitchedRules.create(bad).get("ok", false)), "AC3: wrong-slot head in arms refused")
	bad = _config()
	bad["heroes"][1]["parts"]["head"] = {"id": STARTERS["head"], "tier": 4}
	_check(not bool(StitchedRules.create(bad).get("ok", false)), "AC3: invalid equipment tier refused")
	bad = _config()
	bad["heroes"][1]["parts"]["head"] = {"id": "button_golem_missing", "tier": 1}
	_check(not bool(StitchedRules.create(bad).get("ok", false)), "AC3: unknown equipment refused")
	bad = _config()
	bad["heroes"][1]["parts"]["head"]["torn"] = true
	var torn_built := StitchedRules.create(bad)
	_check(bool(torn_built.get("ok", false)), "AC3: torn legal equipment builds before rejecting its cast")
	if bool(torn_built.get("ok", false)):
		var torn: StitchedRules = torn_built["battle"]
		if _to(torn, "button_golem"):
			_reject(torn, STARTERS["head"], 1, "torn part")
		else:
			_check(false, "AC3: torn-part actual scheduled turn")
	var b := _battle()
	if b == null or not _to(b, "button_golem"):
		_check(false, "AC3: invalid target real turn")
		return
	_reject(b, STARTERS["head"], 4, "enemy target outside rank mask")
	_reject(b, STARTERS["head"], 0, "invalid rank zero")
	_reject(b, STARTERS["torso"], 1, "self-only torso cannot target other ally")
	_reject(b, ALTERNATES["head"], 1, "not equipped")
	_reject(b, "button_golem_nonexistent", 1, "missing part")
	var acted := b.use_part(STARTERS["head"], 1)
	_check(bool(acted.get("ok", false)), "AC3: legal action does spend the turn")
	if bool(acted.get("ok", false)):
		_reject(b, STARTERS["head"], 1, "off turn")
	var rear := _config(ALTERNATES["head"])
	if not rear.is_empty():
		var doll: Dictionary = rear["heroes"].pop_at(1)
		rear["heroes"].append(doll)
		var made := StitchedRules.create(rear)
		_check(bool(made.get("ok", false)), "AC3: rank-four preview party is legal setup")
		if bool(made.get("ok", false)):
			var b4: StitchedRules = made["battle"]
			if _to(b4, "button_golem"):
				_reject(b4, ALTERNATES["head"], 1, "illegal launch from rank four")
			else:
				_check(false, "AC3: rank four receives scheduled turn")
	for id in [STARTERS["legs"], ALTERNATES["legs"]]:
		var wheel := _battle(id, 2, 503394)
		if wheel == null or not _to(wheel, "button_golem"):
			_check(false, "AC3: wheel preconditions")
			continue
		var neighbour := "tinker" if id == STARTERS["legs"] else "warden"
		wheel._units[neighbour]["statuses"]["tangled"] = 2
		_check(int(wheel.get_unit(neighbour)["statuses"].get("tangled", 0)) > 0,
			"AC3: genuine adjacent tangled blocker is in state")
		_reject(wheel, id, 2, "mandatory self_move blocked by Tangled adjacent hero")


func _trace(seed_value: int) -> Dictionary:
	var b := _battle("", 3, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	for pair in [[STARTERS["head"], 1], [STARTERS["arms"], 1],
		[STARTERS["torso"], 2], [STARTERS["legs"], 2]]:
		if not _to(b, "button_golem"):
			break
		receipts.append(b.use_part(str(pair[0]), int(pair[1])))
	return {"receipts": receipts, "state": b.state_snapshot(), "rng": b.rng_state()}


func _test_replay() -> void:
	var a := _trace(503919)
	var b := _trace(503919)
	_check(not a.is_empty() and a == b and a.get("receipts", []).size() == 4,
		"AC3: full four-slot trace replays actions, RNG and authoritative state")
	for action in a.get("receipts", []):
		_check(bool(action.get("ok", false)), "AC3: every replay action truly resolved")
