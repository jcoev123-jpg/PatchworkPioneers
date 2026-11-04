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
	_check(c["by_id"][ALTERNATES["arms"]]["ability"]["multi"]
		and c["by_id"][ALTERNATES["arms"]]["ability"]["target"] == [1, 2, 3],
		"AC1: Popping Volley has three separate foe targets, no double-hit")
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
		var hits := 0
		for r in cast["results"]:
			distinct[str(r["target"])] = true
			if bool(r["hit"]) and int(r["damage"]) > 0:
				hits += 1
		witnessed = (distinct.has("fray_scavenger") and distinct.has("scissor_crab")
			and distinct.has("moth_scribe") and hits == 3)
		if witnessed:
			break
	_check(witnessed, "AC2: real Popping Volley hits each of three unique foes exactly once")


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
