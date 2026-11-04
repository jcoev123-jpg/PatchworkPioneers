extends SceneTree
## S4 Scarecrow: eight independent Stitched parts tested against real seeded S2 4v3 rules.
## The shipped preview is read-only: rank 2 is replaced only in memory.
const CATALOG_PATH := "res://data/parts/scarecrow_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const STARTERS := {
	"head": "scarecrow_head_sack_glare",
	"arms": "scarecrow_arms_fork_jab",
	"torso": "scarecrow_torso_straw_padding",
	"legs": "scarecrow_legs_crow_dive",
}
const ALTERNATES := {
	"head": "scarecrow_head_crow_flock",
	"arms": "scarecrow_arms_harvest_fright",
	"torso": "scarecrow_torso_straw_wrap",
	"legs": "scarecrow_legs_crow_peck",
}
const IDS := [
	"scarecrow_head_sack_glare", "scarecrow_arms_fork_jab",
	"scarecrow_torso_straw_padding", "scarecrow_legs_crow_dive",
	"scarecrow_head_crow_flock", "scarecrow_arms_harvest_fright",
	"scarecrow_torso_straw_wrap", "scarecrow_legs_crow_peck",
]
const ENEMY_IDS := ["fray_scavenger", "scissor_crab", "moth_scribe"]
const OTHER_HERO_IDS := ["warden", "tinker", "lantern_monk"]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_each_tier()
	_test_area_and_effects()
	_test_guard_and_dodge()
	_test_mark_damage()
	_test_rejections()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s4_scarecrow_parts_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(CATALOG_PATH)


func _config(selected: String = "", tier: int = 1, seed_value: int = 501041) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		_check(false, "real shipped four-hero S2 preview must parse")
		return {}
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		_check(false, "Scarecrow catalog validates: " + str(cat.get("error", "")))
		return {}
	var config: Dictionary = parsed
	_check(str(config["heroes"][1]["id"]) == "seamstress", "rank-2 preview hero is the only replacement")
	var gear: Dictionary = {}
	for slot in STARTERS:
		var id: String = STARTERS[slot]
		if not selected.is_empty() and cat["by_id"].has(selected) and str(cat["by_id"][selected]["slot"]) == slot:
			id = selected
		gear[slot] = {"id": id, "tier": tier}
	config["heroes"][1] = {
		"id": "scarecrow", "name": "Scarecrow", "max_hp": 32, "speed": 6,
		"dodge": 7, "acc": 6, "prot": 0, "parts": gear,
	}
	config["parts"].append_array(cat["parts"])
	config["seed"] = seed_value
	return config


func _battle(selected: String = "", tier: int = 1, seed_value: int = 501041) -> StitchedRules:
	var config := _config(selected, tier, seed_value)
	if config.is_empty():
		return null
	var built := StitchedRules.create(config)
	_check(bool(built.get("ok", false)), "AC2: real S2 rules setup: " + str(built.get("error", "")))
	if not bool(built.get("ok", false)):
		return null
	var b: StitchedRules = built["battle"]
	var heroes: Array = b.get_heroes()
	var foes: Array = b.get_foes()
	_check(heroes.size() == 4 and foes.size() == 3 and int(b.get_unit("scarecrow").get("rank", -1)) == 2,
		"AC2: four actual heroes, three actual foes, Scarecrow at legal rank 2")
	for id in OTHER_HERO_IDS:
		_check(not b.get_unit(id).is_empty(), "AC2: other shipped preview hero retained: " + id)
	for id in ENEMY_IDS:
		_check(not b.get_unit(id).is_empty(), "AC2: actual shipped foe retained: " + id)
	_check(b.get_unit("scarecrow").get("parts", {}).size() == 4,
		"AC2: Scarecrow starts with four fully equipped parts")
	return b


func _to(b: StitchedRules, actor_id: String, limit: int = 55) -> bool:
	for step in range(limit):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id:
			return true
		if not bool(b.pass_turn().get("ok", false)):
			return false
	return false


func _test_catalog() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: real JSON validates through StitchedParts")
	if not bool(cat.get("ok", false)):
		return
	var seen: Dictionary = {}
	var abilities: Dictionary = {}
	var counts := {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	for id in IDS:
		_check(cat["by_id"].has(id), "AC1: required part exists: " + id)
	for part in cat["parts"]:
		var id := str(part["id"])
		var slot := str(part["slot"])
		_check(id in IDS and not seen.has(id) and str(part["owner"]) == "scarecrow",
			"AC1: unique Scarecrow-owned source-inspired part " + id)
		seen[id] = true
		if counts.has(slot):
			counts[slot] += 1
		_check(str(part["ability"]["id"]).begins_with("scarecrow_")
			and not abilities.has(str(part["ability"]["id"])),
			"AC1: independent unique ability for " + id)
		abilities[str(part["ability"]["id"])] = true
		var base: Dictionary = part["ability"]
		_check(str(base["move"]) in StitchedParts.MOVE_POSES
			and int(base["launch_mask"]) == StitchedParts.rank_mask(base["launch"])
			and int(base["target_mask"]) == StitchedParts.rank_mask(base["target"])
			and int(base["launch_mask"]) != 0 and int(base["target_mask"]) != 0,
			"AC1: legal launch/target masks and existing animation pose for " + id)
		_check(part["tiers"].has("2") and part["tiers"].has("3"),
			"AC1: both higher stitch tiers authored for " + id)
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var stat := StitchedParts.stat_at_tier(part, tier)
			_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
				"AC1: tier %d validates for %s" % [tier, id])
			_check(not stat.is_empty(), "AC1: slot stat present at tier %d %s" % [tier, id])
			for key in stat:
				_check(str(key) in StitchedParts.SLOT_STATS[slot],
					"AC1: each tier stat is legal for " + slot)
			_check(tier == 1 or ability != base,
				"AC1: tier %d improves a native ability for %s" % [tier, id])
			for key in ["draw", "block", "cost", "cannot_buff_next_turn", "ignore_block", "max_hp_loss", "pull_forward"]:
				_check(not ability.has(key) and not ability["effects"].has(key),
					"AC1: no unsupported retired card effect " + key + " on " + id)
		var malformed: Dictionary = part.duplicate(true)
		malformed["tiers"]["4"] = {"ability": {"acc": 99}}
		_check(not bool(StitchedParts.validate_part(malformed).get("ok", false)),
			"AC3: illegal tier IV override fails closed for " + id)
	for slot in counts:
		_check(int(counts[slot]) == 2, "AC1: exactly two Scarecrow " + slot + " options")
		_check(str(cat["by_id"][STARTERS[slot]]["slot"]) == slot and
			str(cat["by_id"][ALTERNATES[slot]]["slot"]) == slot,
			"AC1: four named starters and four named alternates slot correctly")
	for id in [ALTERNATES["head"], ALTERNATES["arms"]]:
		_check(bool(cat["by_id"][id]["ability"]["multi"])
			and cat["by_id"][id]["ability"]["target"] == [1, 2, 3]
			and str(cat["by_id"][id]["ability"]["target_side"]) == "enemy",
			"AC1: crowd move hits first three foe ranks with native multi " + id)
	_check(int(cat["by_id"][STARTERS["legs"]]["ability"]["mark_damage"]) > 0
		and int(cat["by_id"][ALTERNATES["legs"]]["ability"]["mark_damage"]) > 0,
		"AC1: crow moves use implemented mark_damage, not ignore_block")
	_check(cat["by_id"][ALTERNATES["torso"]]["ability"]["effects"].has("duration"),
		"AC1: Straw Wrap has paired duration for temporary Dodge")
	var invalid_dodge: Dictionary = cat["by_id"][ALTERNATES["torso"]].duplicate(true)
	invalid_dodge["tiers"]["2"]["ability"]["effects"] = {"dodge": 9}
	_check(not bool(StitchedParts.validate_part(invalid_dodge).get("ok", false)),
		"AC3: Dodge without duration rejects even in a tier override")
	var invalid_rank: Dictionary = cat["by_id"][ALTERNATES["arms"]].duplicate(true)
	invalid_rank["ability"]["target"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(invalid_rank).get("ok", false)),
		"AC3: out-of-bounds target rank rejects at validation")


func _test_each_tier() -> void:
	var hit_witness: Dictionary = {}
	var damage_witness: Dictionary = {}
	for id in IDS:
		hit_witness[id] = 0
		damage_witness[id] = 0
		for tier in [1, 2, 3]:
			var b := _battle(id, tier, 501042 + tier)
			if b == null:
				continue
			_check(_to(b, "scarecrow"), "AC2: Scarecrow has actual scheduled turn for %s tier %d" % [id, tier])
			if b.current_actor_id() != "scarecrow":
				continue
			var ability: Dictionary = StitchedParts.ability_at_tier(_catalog()["by_id"][id], tier)
			var before := b.state_snapshot()
			var cast := b.use_part(id, 1)
			_check(bool(cast.get("ok", false)) and str(cast.get("actor", "")) == "scarecrow"
				and str(cast.get("part", "")) == id and str(cast.get("ability", "")) == str(ability["id"]),
				"AC2: equipped %s tier %d executes from actual rank 2" % [id, tier])
			if not bool(cast.get("ok", false)):
				continue
			var receipts: Array = cast.get("results", [])
			_check(not receipts.is_empty() and b.state_snapshot() != before,
				"AC2: authoritative state and receipt changed for " + id)
			var expected_count := 3 if bool(ability["multi"]) else 1
			var targets: Dictionary = {}
			for receipt in receipts:
				targets[str(receipt["target"])] = true
			_check(receipts.size() == expected_count and targets.size() == expected_count,
				"AC2: every target resolves once in %s" % id)
			for receipt in receipts:
				if not bool(receipt.get("hit", false)):
					continue
				hit_witness[id] += 1
				if str(ability["target_side"]) == "enemy":
					_check(str(receipt["target_side"]) == "foe", "AC2: attack receipt targets a real foe")
					if int(receipt.get("damage", 0)) > 0:
						damage_witness[id] += 1
					for key in ability["effects"]:
						if key == "duration":
							continue
						_check(receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == str(key)),
							"AC2: landed native " + str(key) + " appears in authoritative receipt for " + id)
						# _advance_turn can immediately tick a tier-I one-turn status when that
						# struck foe becomes the next actor; tier II+ must still persist.
						if tier > 1:
							_check(int(b.get_unit(str(receipt["target"]))["statuses"].get(key, 0)) > 0,
								"AC2: tier II/III native " + str(key) + " persists in real foe state for " + id)
				elif id == STARTERS["torso"]:
					_check(str(receipt["target"]) == "warden"
						and str(b.get_unit("scarecrow")["guard_target"]) == "warden"
						and receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == "guard"),
						"AC2: Guard targets actual Warden and appears in authoritative receipt")
				elif id == ALTERNATES["torso"]:
					_check(str(receipt["target"]) == "warden"
						and int(b.get_unit("warden")["dodge_buff"].get("amount", 0)) > 0
						and receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == "dodge"),
						"AC2: temporary Dodge exists on real ally and in receipt")
	for id in IDS:
		_check(int(hit_witness[id]) > 0, "AC2: nonvacuous hit/status witness across three tiers for " + id)
	for id in [STARTERS["arms"], STARTERS["legs"], ALTERNATES["arms"], ALTERNATES["legs"]]:
		_check(int(damage_witness[id]) > 0, "AC2: nonvacuous actual enemy damage for " + id)


func _test_area_and_effects() -> void:
	for id in [ALTERNATES["head"], ALTERNATES["arms"]]:
		var witnessed := false
		for seed_value in range(501100, 501140):
			var b := _battle(id, 2, seed_value)
			if b == null or not _to(b, "scarecrow"):
				continue
			var cast := b.use_part(id, 1)
			if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 3:
				continue
			var distinct: Dictionary = {}
			var landed := 0
			for receipt in cast["results"]:
				var target_id := str(receipt["target"])
				distinct[target_id] = true
				if bool(receipt.get("hit", false)) and int(b.get_unit(target_id)["statuses"].get("weak", 0)) > 0:
					landed += 1
			witnessed = distinct.has("fray_scavenger") and distinct.has("scissor_crab") and distinct.has("moth_scribe") and landed == 3
			if witnessed:
				break
		_check(witnessed, "AC2: seeded %s Weakens three distinct actual foes in one area cast" % id)
	var bleed := false
	for seed_value in range(501141, 501170):
		var b := _battle(STARTERS["arms"], 1, seed_value)
		if b == null or not _to(b, "scarecrow"):
			continue
		var before := int(b.get_unit("fray_scavenger")["hp"])
		var jab := b.use_part(STARTERS["arms"], 1)
		if bool(jab.get("ok", false)) and jab.get("results", []).size() == 1:
			var hit: Dictionary = jab["results"][0]
			bleed = bool(hit.get("hit", false)) and int(hit.get("damage", 0)) > 0
			bleed = bleed and int(b.get_unit("fray_scavenger")["hp"]) < before
			bleed = bleed and int(b.get_unit("fray_scavenger")["statuses"].get("bleed", 0)) > 0
			bleed = bleed and hit.get("statuses", []).any(func(s): return str(s.get("status", "")) == "bleed")
			if bleed:
				break
	_check(bleed, "AC2: genuine Fork Jab deals foe HP damage and applies Bleed in state and receipt")


func _test_guard_and_dodge() -> void:
	var guarded := false
	for seed_value in range(501180, 501220):
		var b := _battle(STARTERS["torso"], 2, seed_value)
		if b == null or not _to(b, "scarecrow"):
			continue
		var cast := b.use_part(STARTERS["torso"], 1)
		if not bool(cast.get("ok", false)) or str(b.get_unit("scarecrow")["guard_target"]) != "warden":
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var attack := b.use_foe_ability("sack_swing", 1)
		if bool(attack.get("ok", false)) and attack.get("results", []).size() == 1:
			guarded = str(attack["results"][0].get("guarded_by", "")) == "scarecrow"
			if guarded:
				break
	_check(guarded, "AC2: foe strike on Warden redirects to Scarecrow's actual Guard")
	var dodge := _battle(ALTERNATES["torso"], 2, 501221)
	if dodge != null and _to(dodge, "scarecrow"):
		var before := int(StitchedRules.effective_dodge(dodge.get_unit("warden")))
		var cast := dodge.use_part(ALTERNATES["torso"], 1)
		var after := dodge.get_unit("warden")
		_check(bool(cast.get("ok", false)) and after.get("dodge_buff", {}).get("amount", 0) == 8
			and int(after["dodge_buff"].get("turns", 0)) == 2
			and int(StitchedRules.effective_dodge(after)) > before
			and cast.get("results", []).size() == 1
			and cast["results"][0].get("statuses", []).any(func(s): return str(s.get("status", "")) == "dodge"),
			"AC2: tier-II Straw Wrap grants bounded temporary Dodge with receipt to real Warden")


func _test_mark_damage() -> void:
	for crow_part in [STARTERS["legs"], ALTERNATES["legs"]]:
		var witnessed := false
		for seed_value in range(501230, 501300):
			var marked := _battle(crow_part, 1, seed_value)
			var plain := _battle(crow_part, 1, seed_value)
			if marked == null or plain == null or not _to(marked, "scarecrow") or not _to(plain, "scarecrow"):
				continue
			var mark_cast := marked.use_part(STARTERS["head"], 1)
			var twin_cast := plain.use_part(STARTERS["head"], 1)
			if mark_cast != twin_cast or not bool(mark_cast.get("ok", false)) or mark_cast.get("results", []).is_empty():
				continue
			if not bool(mark_cast["results"][0].get("hit", false)):
				continue
			plain._units["fray_scavenger"]["statuses"].erase("mark")
			if not _to(marked, "scarecrow") or not _to(plain, "scarecrow"):
				continue
			if int(marked.get_unit("fray_scavenger")["statuses"].get("mark", 0)) <= 0:
				continue
			if marked.rng_state() != plain.rng_state():
				continue
			var enhanced := marked.use_part(crow_part, 1)
			var normal := plain.use_part(crow_part, 1)
			if not bool(enhanced.get("ok", false)) or not bool(normal.get("ok", false)):
				continue
			if enhanced.get("results", []).is_empty() or normal.get("results", []).is_empty():
				continue
			if bool(enhanced["results"][0].get("hit", false)) and bool(normal["results"][0].get("hit", false)):
				witnessed = int(enhanced["results"][0]["damage"]) > int(normal["results"][0]["damage"])
				witnessed = witnessed and marked.rng_state() == plain.rng_state()
				if witnessed:
					break
		_check(witnessed, "AC2: actual Sack Glare Mark adds damage to %s at matched RNG" % crow_part)


func _reject_without_spend(b: StitchedRules, id: String, rank: int, label: String) -> void:
	var actor := b.current_actor_id()
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var result := b.use_part(id, rank)
	_check(not bool(result.get("ok", false)) and str(result.get("error", "")) != ""
		and b.current_actor_id() == actor and b.state_snapshot() == snapshot and b.rng_state() == rng,
		"AC3: " + label + " rejects with unchanged actor, state and RNG")


func _test_rejections() -> void:
	var bad := _config()
	if bad.is_empty():
		return
	bad["heroes"][1]["parts"]["arms"] = {"id": STARTERS["head"], "tier": 1}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: mismatched head in arms slot rejected at battle creation")
	bad = _config()
	bad["heroes"][1]["parts"]["head"] = {"id": STARTERS["head"], "tier": 4}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: invalid tier IV rejected at battle creation")
	bad = _config()
	bad["heroes"][1]["parts"]["head"] = {"id": "scarecrow_head_missing", "tier": 1}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: unknown part rejected at battle creation")
	bad = _config()
	bad["heroes"][1]["parts"]["arms"] = {"id": STARTERS["arms"], "tier": 1, "torn": true}
	var torn_built := StitchedRules.create(bad)
	_check(bool(torn_built.get("ok", false)), "AC3: torn Scarecrow equipment permitted at setup")
	if bool(torn_built.get("ok", false)):
		var torn: StitchedRules = torn_built["battle"]
		if _to(torn, "scarecrow"):
			_reject_without_spend(torn, STARTERS["arms"], 1, "torn part")
		else:
			_check(false, "AC3: torn part has actual turn witness")
	var b := _battle()
	if b == null or not _to(b, "scarecrow"):
		_check(false, "AC3: invalid-action witness has an actual turn")
		return
	for action in [[STARTERS["arms"], 3], [STARTERS["head"], 4], [STARTERS["torso"], 0], [ALTERNATES["arms"], 1], ["scarecrow_missing", 1]]:
		_reject_without_spend(b, str(action[0]), int(action[1]),
			"illegal enemy target rank / ally side target / unequipped part " + str(action))
	var played := b.use_part(STARTERS["head"], 1)
	_check(bool(played.get("ok", false)), "AC3: legal Scarecrow action actually spends turn")
	if bool(played.get("ok", false)):
		_reject_without_spend(b, STARTERS["arms"], 1, "wrong active side / off-turn Scarecrow action")
	# The real remaining preview heroes are kept; only an in-memory rank rearrangement
	# puts Scarecrow in rank 4, which Crow Flock cannot launch from.
	var rear := _config(ALTERNATES["head"])
	if rear.is_empty():
		return
	var scarecrow: Dictionary = rear["heroes"].pop_at(1)
	rear["heroes"].append(scarecrow)
	var built := StitchedRules.create(rear)
	_check(bool(built.get("ok", false)), "AC3: genuine rank-4 Scarecrow party is a valid 4v3 battle")
	if bool(built.get("ok", false)):
		var back: StitchedRules = built["battle"]
		if _to(back, "scarecrow"):
			_reject_without_spend(back, ALTERNATES["head"], 1, "wrong launch rank 4")
		else:
			_check(false, "AC3: rank-4 launch gate receives an actual scheduled turn")


func _trace(seed_value: int) -> Dictionary:
	var b := _battle("", 2, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	for action in [[STARTERS["head"], 1], [STARTERS["arms"], 2], [STARTERS["torso"], 1], [STARTERS["legs"], 1]]:
		if not _to(b, "scarecrow"):
			break
		receipts.append(b.use_part(str(action[0]), int(action[1])))
	return {"receipts": receipts, "snapshot": b.state_snapshot(), "rng": b.rng_state()}


func _test_replay() -> void:
	var first := _trace(501919)
	var second := _trace(501919)
	_check(not first.is_empty() and first == second and first.get("receipts", []).size() == 4,
		"AC3: equal seeded four-part traces replay exact receipts, battle state and RNG")
	for receipt in first.get("receipts", []):
		_check(bool(receipt.get("ok", false)), "AC3: every replayed action actually executes")
