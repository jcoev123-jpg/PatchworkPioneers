extends SceneTree
## S5 authored Drain through the real catalogs, rules and seeded turn flow.
## Every witness is reached with genuine pass_turn / use_part / use_foe_ability decisions.
const SEEDS_PRIMARY := 320
const SEEDS_NEGATIVE := 120
const RUN_ENEMIES := "res://data/enemies/run_enemies.json"
const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
var failures: Array[String] = []
var checks := 0
var catalog: Dictionary
var preview: Dictionary


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(bool(catalog.get("ok", false)) and parsed is Dictionary, "canonical enemy catalog and preview load")
	if bool(catalog.get("ok", false)) and parsed is Dictionary:
		preview = parsed
		_contract()
		_catalog_fail_closed()
		var primary := _find_primary()
		_verify_primary(primary)
		_verify_each_authored_drainer()
		var guard := _find_guard()
		_verify_guard(guard)
		_verify_non_drainer()
		_verify_full_health()
		_verify_zero_damage()
		_verify_miss()
		_verify_self_action()
		_verify_zero_hp_target()
		_verify_counter_kill()
		_verify_replay_and_draws(primary)
	for failure in failures:
		printerr(failure)
	print("stitched_s5_enemy_drain_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _record(records: Array, id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and str(record.get("id", "")) == id:
			return record
	return {}


func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# ---------------------------------------------------------------- AC1 authored source

func _contract() -> void:
	var run: Variant = _read_json(RUN_ENEMIES)
	var elites: Variant = _read_json(ELITES)
	_check(run is Array and elites is Array, "AC1: real normal and elite enemy catalogs are arrays")
	if not (run is Array and elites is Array):
		return
	var biter := _record(run, "thread_biter")
	var bat := _record(run, "bobbin_bat")
	var leech := _record(elites, "spool_leech")
	var crab := _record(run, "scissor_crab")
	_check(biter.get("drain") == true and bat.get("drain") == true and leech.get("drain") == true,
		"AC1: the three canonical records still author a boolean drain")
	_check(not crab.has("drain"), "AC1: the scissor crab source stays unflagged")
	for enemy_id in ["thread_biter", "bobbin_bat", "spool_leech"]:
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id))
		_check(foe.get("drain") == true,
			"AC1: foe_for carries the authored drain trait for " + str(enemy_id))
		var battle := _battle(11, [str(enemy_id), "scissor_crab"])
		_check(battle != null, "AC1: a real four-hero battle builds with " + str(enemy_id))
		if battle != null:
			_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 2,
				"AC1: four legitimate heroes and two canonical foes for " + str(enemy_id))
			_check(battle.get_unit(str(enemy_id)).get("drain") == true,
				"AC1: StitchedRules.create carries drain into the real foe unit")
			_check(not bool(battle.get_unit("scissor_crab").get("drain", false)),
				"AC1: the unflagged scissor crab foe unit is non-draining")
	# The Thread Biter source contract stays exact in its own test; here the non-drainer is explicit.
	var crab_foe := StitchedEnemyCatalog.foe_for(catalog, "scissor_crab")
	_check(not crab_foe.has("drain") and not bool(crab_foe.get("drain", false)),
		"AC1: unflagged foe_for output remains non-draining rather than defaulting true")


func _catalog_fail_closed() -> void:
	for probe in [["malformed string", "yes"], ["malformed number", 1], ["malformed object", {}]]:
		var built := _build_with_authored_drain("thread_biter", probe[1])
		_check(bool(built.get("ok", false)), "AC1: " + str(probe[0]) + " drain does not invalidate the catalog")
		if bool(built.get("ok", false)):
			_check(not bool(StitchedEnemyCatalog.foe_for(built, "thread_biter").get("drain", false)),
				"AC1: " + str(probe[0]) + " drain fails closed instead of turning on by truthiness")
	var absent := _build_with_authored_drain("thread_biter", null)
	_check(bool(absent.get("ok", false))
		and not bool(StitchedEnemyCatalog.foe_for(absent, "thread_biter").get("drain", false)),
		"AC1: absent drain remains off")
	var authored := _build_with_authored_drain("thread_biter", true)
	_check(bool(authored.get("ok", false))
		and StitchedEnemyCatalog.foe_for(authored, "thread_biter").get("drain") == true,
		"AC1: a boolean true authored drain still propagates")


func _build_with_authored_drain(enemy_id: String, value: Variant) -> Dictionary:
	var documents: Array = []
	for entry in StitchedEnemyCatalog.CATALOGS:
		var parsed: Variant = _read_json(str(entry["path"]))
		if not parsed is Array:
			return {}
		var records: Array = []
		for raw in parsed:
			var record: Dictionary = (raw as Dictionary).duplicate(true)
			if str(record.get("id", "")) == enemy_id:
				if value == null:
					record.erase("drain")
				else:
					record["drain"] = value
			records.append(record)
		documents.append({"path": str(entry["path"]), "tier": str(entry["tier"]), "entries": records})
	var phase_two: Variant = _read_json(StitchedEnemyCatalog.PHASE_TWO_PATH)
	var parts_document: Variant = _read_json(StitchedEnemyCatalog.PARTS_PATH)
	if not phase_two is Dictionary or not parts_document is Dictionary:
		return {}
	return StitchedEnemyCatalog.build_catalog(documents, phase_two, parts_document.get("parts", []))


# ---------------------------------------------------------------- real battle helpers

func _battle(seed_value: int, foe_ids: Array, hero_order: Array = [],
		strip_drain: bool = false) -> StitchedRules:
	var foes: Array = []
	for enemy_id in foe_ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id))
		if foe.is_empty():
			return null
		if strip_drain:
			foe.erase("drain")
		foes.append(foe)
	return _build(seed_value, foes, hero_order)


func _build(seed_value: int, foes: Array, hero_order: Array) -> StitchedRules:
	var config: Dictionary = preview.duplicate(true)
	config.parts.append_array(catalog.parts)
	config.seed = seed_value
	config.candle = 100
	config.foes = foes
	if not hero_order.is_empty():
		var by_id: Dictionary = {}
		for hero in config.heroes:
			by_id[str(hero["id"])] = hero
		var ordered: Array = []
		for hero_id in hero_order:
			if not by_id.has(str(hero_id)):
				return null
			ordered.append(by_id[str(hero_id)])
		config.heroes = ordered
	var made := StitchedRules.create(config)
	if not bool(made.get("ok", false)):
		return null
	return made["battle"]


## Pass genuine turns until the requested actor is current. Returns false on a dead end.
func _to(battle: StitchedRules, actor_id: String, receipts: Array, limit: int = 60) -> bool:
	for step in range(limit):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor_id:
			return true
		var passed := battle.pass_turn()
		receipts.append(passed)
		if not bool(passed.get("ok", false)):
			return false
	return false


func _units_by_id(snapshot: Dictionary) -> Dictionary:
	var units: Dictionary = {}
	for unit in snapshot.get("units", []):
		units[str(unit["id"])] = unit
	return units


func _has_status(statuses: Array, name: String, duration: int) -> bool:
	for status in statuses:
		if status is Dictionary and str(status.get("status", "")) == name \
				and int(status.get("duration", -1)) == duration:
			return true
	return false


# ---------------------------------------------------------------- primary drain witness

func _wound_and_attack(seed_value: int, foe_id: String, part_id: String, ability_id: String,
		target_rank: int, strip_drain: bool = false, hero_order: Array = []) -> Dictionary:
	var battle := _battle(seed_value, [foe_id, "scissor_crab"], hero_order, strip_drain)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _to(battle, "warden", receipts):
		return {}
	var wound := battle.use_part(part_id, 1)
	receipts.append(wound)
	if not bool(wound.get("ok", false)) or (wound.get("results", []) as Array).is_empty():
		return {}
	var wound_hit: Dictionary = wound["results"][0]
	if not bool(wound_hit.get("hit", false)) or int(wound_hit.get("damage", 0)) <= 0:
		return {"wounded": false}
	if not _to(battle, foe_id, receipts):
		return {}
	var before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var receipt := battle.use_foe_ability(ability_id, target_rank)
	receipts.append(receipt)
	var after := battle.state_snapshot()
	if not bool(receipt.get("ok", false)) or (receipt.get("results", []) as Array).is_empty():
		return {}
	var hit: Dictionary = receipt["results"][0]
	var units_before := _units_by_id(before)
	var units_after := _units_by_id(after)
	var foe_before: Dictionary = units_before.get(foe_id, {})
	var foe_after: Dictionary = units_after.get(foe_id, {})
	var target_id := str(hit.get("target", ""))
	var target_before: Dictionary = units_before.get(target_id, {})
	var missing := int(foe_before.get("max_hp", 0)) - int(foe_before.get("hp", 0))
	var direct_loss := maxi(0, int(target_before.get("hp", 0)) - int(hit.get("target_hp", 0)))
	var gain := mini(maxi(0, missing), direct_loss) if bool(hit.get("hit", false)) else 0
	return {
		"seed": seed_value,
		"battle": battle,
		"receipts": receipts,
		"wound": wound_hit,
		"hit": hit,
		"before": before,
		"after": after,
		"rng_before": rng_before,
		"rng_after": battle.rng_state(),
		"foe_before": foe_before,
		"foe_after": foe_after,
		"foe_id": foe_id,
		"target_id": target_id,
		"target_before": target_before,
		"missing": missing,
		"direct_loss": direct_loss,
		"gain": gain,
		"units_before": units_before,
		"units_after": units_after,
	}


func _find_primary() -> Dictionary:
	var first_hit: Dictionary = {}
	var first_cap: Dictionary = {}
	for seed_value in range(1, SEEDS_PRIMARY + 1):
		var trace := _wound_and_attack(seed_value, "thread_biter", "warden_legs_hold", "thread_bite", 1)
		if trace.is_empty() or not bool(trace.get("hit", {}).get("hit", false)):
			continue
		if int(trace.get("direct_loss", 0)) <= 0 or int(trace.get("gain", 0)) <= 0:
			continue
		if first_hit.is_empty():
			first_hit = trace
			print("primary drain witness seed: ", seed_value)
		if int(trace["gain"]) < int(trace["direct_loss"]) and first_cap.is_empty():
			first_cap = trace
			print("capped drain witness seed: ", seed_value)
		if not first_hit.is_empty() and not first_cap.is_empty():
			break
	if not first_cap.is_empty():
		first_hit["cap"] = first_cap
	return first_hit


func _verify_primary(trace: Dictionary) -> void:
	_check(not trace.is_empty(), "AC2: a seeded real hero wound and confirmed draining bite exist")
	if trace.is_empty():
		return
	var hit: Dictionary = trace["hit"]
	var foe_before: Dictionary = trace["foe_before"]
	var foe_after: Dictionary = trace["foe_after"]
	_check(int(trace["direct_loss"]) > 0 and int(trace["gain"]) > 0,
		"AC2: the genuine bite removed HP and the wounded foe healed")
	_check(int(foe_after.get("hp", -1)) == int(foe_before.get("hp", -2)) + int(trace["gain"]),
		"AC2: the foe restores exactly min(missing HP, actual target HP loss)")
	_check(int(hit.get("drain", 0)) == int(trace["gain"]),
		"AC2: the hit receipt reports the actual amount restored")
	_check(int(hit.get("target_hp", -1)) == int(trace["target_before"].get("hp", 0)) - int(trace["direct_loss"]),
		"AC2: target HP before/after equals the actual direct loss")
	_check(int(hit.get("damage", 0)) == int(trace["direct_loss"]),
		"AC2: direct loss equals the post-PROT advertised damage on a living doll")
	var statuses: Array = hit.get("statuses", [])
	_check(_has_status(statuses, "bleed", 1),
		"AC2: the authored Bleed application still follows the drained bite")
	_check(int(trace["foe_before"].get("hp", 0)) < int(trace["foe_before"].get("max_hp", 0)),
		"AC2: the drainer was genuinely wounded before its turn")
	_assert_other_units_unchanged(trace, "AC2")
	var cap: Dictionary = trace.get("cap", {})
	if not cap.is_empty():
		_check(int(cap["gain"]) < int(cap["direct_loss"])
			and int(cap["gain"]) == int(cap["missing"])
			and int(cap["foe_after"].get("hp", -1)) == int(cap["foe_before"].get("max_hp", 0)),
			"AC2: a capped witness heals only its missing HP and never overheals")


func _verify_each_authored_drainer() -> void:
	for spec in [["bobbin_bat", "bobbin_dive"], ["spool_leech", "leech_bite"]]:
		var found: Dictionary = {}
		for seed_value in range(1, SEEDS_NEGATIVE + 1):
			var trace := _wound_and_attack(seed_value, str(spec[0]), "warden_legs_hold",
				str(spec[1]), 1)
			if trace.is_empty() or not bool(trace.get("hit", {}).get("hit", false)):
				continue
			if int(trace.get("direct_loss", 0)) <= 0 or int(trace.get("gain", 0)) <= 0:
				continue
			found = trace
			break
		_check(not found.is_empty(),
			"AC1/AC2: a seeded real confirmed hit heals " + str(spec[0]))
		if found.is_empty():
			continue
		var hit: Dictionary = found["hit"]
		_check(int(found["foe_after"].get("hp", -1))
			== int(found["foe_before"].get("hp", -2)) + int(found["gain"])
			and int(hit.get("drain", 0)) == int(found["gain"]),
			"AC1/AC2: " + str(spec[0]) + " restores its actual struck HP loss, capped and receipted")
		print(str(spec[0]), " drain witness seed: ", int(found["seed"]))


func _assert_other_units_unchanged(trace: Dictionary, label: String) -> void:
	var foe_id := str(trace.get("foe_id", ""))
	var target_id := str(trace.get("target_id", ""))
	for unit_id in trace["units_before"]:
		if str(unit_id) == foe_id or str(unit_id) == target_id:
			continue
		var before: Dictionary = trace["units_before"][unit_id]
		var after: Dictionary = trace["units_after"].get(unit_id, {})
		_check(int(before.get("hp", -1)) == int(after.get("hp", -2))
			and int(before.get("max_hp", -1)) == int(after.get("max_hp", -2)),
			label + ": unrelated unit HP stays unchanged: " + str(unit_id))


# ---------------------------------------------------------------- Guard interception

func _guard_trace(seed_value: int) -> Dictionary:
	var order := ["warden", "tinker", "seamstress", "lantern_monk"]
	var battle := _battle(seed_value, ["thread_biter", "scissor_crab"], order)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _to(battle, "warden", receipts):
		return {}
	var wound := battle.use_part("warden_legs_hold", 1)
	receipts.append(wound)
	if not bool(wound.get("ok", false)) or (wound.get("results", []) as Array).is_empty():
		return {}
	var wound_hit: Dictionary = wound["results"][0]
	if not bool(wound_hit.get("hit", false)) or int(wound_hit.get("damage", 0)) <= 0:
		return {}
	if not _to(battle, "tinker", receipts):
		return {}
	var brace := battle.use_part("warden_arm_brace", 1)
	receipts.append(brace)
	if not bool(brace.get("ok", false)):
		return {}
	if int(battle.get_unit("tinker").get("statuses", {}).get("guard", 0)) <= 0:
		return {}
	if str(battle.get_unit("tinker").get("guard_target", "")) != "warden":
		return {}
	if not _to(battle, "thread_biter", receipts):
		return {}
	var tinker_before := battle.get_unit("tinker").duplicate(true)
	var warden_before := battle.get_unit("warden").duplicate(true)
	var before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var receipt := battle.use_foe_ability("thread_bite", 1)
	receipts.append(receipt)
	var after := battle.state_snapshot()
	if not bool(receipt.get("ok", false)) or (receipt.get("results", []) as Array).is_empty():
		return {}
	var hit: Dictionary = receipt["results"][0]
	var units_before := _units_by_id(before)
	var units_after := _units_by_id(after)
	var foe_before: Dictionary = units_before.get("thread_biter", {})
	var foe_after: Dictionary = units_after.get("thread_biter", {})
	var missing := int(foe_before.get("max_hp", 0)) - int(foe_before.get("hp", 0))
	var direct_loss := maxi(0, int(tinker_before.get("hp", 0)) - int(hit.get("target_hp", 0)))
	var gain := mini(maxi(0, missing), direct_loss) if bool(hit.get("hit", false)) else 0
	return {
		"seed": seed_value,
		"receipts": receipts,
		"wound": wound_hit,
		"brace": brace,
		"hit": hit,
		"before": before,
		"after": after,
		"rng_before": rng_before,
		"rng_after": battle.rng_state(),
		"foe_before": foe_before,
		"foe_after": foe_after,
		"foe_id": "thread_biter",
		"target_id": "tinker",
		"target_before": tinker_before,
		"warden_before": warden_before,
		"warden_after": battle.get_unit("warden").duplicate(true),
		"missing": missing,
		"direct_loss": direct_loss,
		"gain": gain,
		"units_before": units_before,
		"units_after": units_after,
	}


func _find_guard() -> Dictionary:
	for seed_value in range(1, SEEDS_NEGATIVE + 1):
		var trace := _guard_trace(seed_value)
		if trace.is_empty():
			continue
		if not bool(trace.get("hit", {}).get("hit", false)):
			continue
		if int(trace.get("direct_loss", 0)) <= 0 or int(trace.get("gain", 0)) <= 0:
			continue
		print("guard drain witness seed: ", seed_value)
		return trace
	return {}


func _verify_guard(trace: Dictionary) -> void:
	_check(not trace.is_empty(), "AC2: a seeded Guard-intercepted draining bite exists")
	if trace.is_empty():
		return
	var hit: Dictionary = trace["hit"]
	_check(str(hit.get("guarded_by", "")) == "tinker" and str(hit.get("target", "")) == "tinker",
		"AC2: the real Guard received the hit aimed at the warden")
	_check(int(trace["warden_after"].get("hp", -1)) == int(trace["warden_before"].get("hp", -2)),
		"AC2: the guarded warden's HP stays unchanged")
	_check(int(trace["direct_loss"]) > 0 and int(trace["gain"]) > 0,
		"AC2: the guardian's actual HP loss feeds the drain")
	_check(int(trace["foe_after"].get("hp", -1))
		== int(trace["foe_before"].get("hp", -2)) + int(trace["gain"]),
		"AC2: the drainer restores min(missing HP, guardian HP loss)")
	_check(int(hit.get("drain", 0)) == int(trace["gain"]),
		"AC2: the Guard-intercepted hit receipt reports the restored amount")
	_assert_other_units_unchanged(trace, "AC2")


# ---------------------------------------------------------------- AC3 negative witnesses

func _verify_non_drainer() -> void:
	var trace: Dictionary = {}
	for seed_value in range(1, SEEDS_NEGATIVE + 1):
		var battle := _battle(seed_value, ["scissor_crab", "ragling"])
		if battle == null:
			continue
		var receipts: Array = []
		if not _to(battle, "warden", receipts):
			continue
		var wound := battle.use_part("warden_legs_hold", 1)
		receipts.append(wound)
		if not bool(wound.get("ok", false)) or (wound.get("results", []) as Array).is_empty():
			continue
		if not bool(wound["results"][0].get("hit", false)):
			continue
		if int(wound["results"][0].get("damage", 0)) <= 0 or not _to(battle, "scissor_crab", receipts):
			continue
		var before := battle.get_unit("scissor_crab")
		var receipt := battle.use_foe_ability("pinch", 1)
		var after := battle.get_unit("scissor_crab")
		if not bool(receipt.get("ok", false)) or (receipt.get("results", []) as Array).is_empty():
			continue
		var hit: Dictionary = receipt["results"][0]
		if not bool(hit.get("hit", false)) or int(hit.get("damage", 0)) <= 0:
			continue
		trace = {"before": before, "after": after, "hit": hit}
		print("non-drainer control seed: ", seed_value)
		break
	_check(not trace.is_empty(), "AC3: a seeded non-draining attack witness exists")
	if trace.is_empty():
		return
	_check(int(trace["before"].get("hp", -1)) == int(trace["after"].get("hp", -2))
		and not trace["hit"].has("drain"),
		"AC3: a non-drainer never heals from confirmed attack damage")


func _verify_full_health() -> void:
	for seed_value in range(1, SEEDS_NEGATIVE + 1):
		var battle := _battle(seed_value, ["thread_biter", "scissor_crab"])
		if battle == null:
			continue
		var receipts: Array = []
		if not _to(battle, "thread_biter", receipts):
			continue
		var before := battle.get_unit("thread_biter")
		if int(before.get("hp", 0)) != int(before.get("max_hp", -1)):
			continue
		var receipt := battle.use_foe_ability("thread_bite", 1)
		if not bool(receipt.get("ok", false)) or (receipt.get("results", []) as Array).is_empty():
			continue
		var hit: Dictionary = receipt["results"][0]
		if not bool(hit.get("hit", false)) or int(hit.get("damage", 0)) <= 0:
			continue
		var after := battle.get_unit("thread_biter")
		_check(int(after.get("hp", -1)) == int(before.get("hp", -2)) and not hit.has("drain"),
			"AC3: a full-health drainer heals nothing from its confirmed attack")
		print("full-health witness seed: ", seed_value)
		return
	_check(false, "AC3: a seeded full-health draining attack witness exists")


func _verify_zero_damage() -> void:
	for seed_value in range(1, SEEDS_NEGATIVE + 1):
		var trace := _wound_and_attack(seed_value, "thread_biter", "warden_legs_hold", "lint_spit", 2)
		if trace.is_empty() or not bool(trace.get("hit", {}).get("hit", false)):
			continue
		var hit: Dictionary = trace["hit"]
		if int(hit.get("damage", -1)) != 0:
			continue
		_check(int(trace["foe_after"].get("hp", -1)) == int(trace["foe_before"].get("hp", -2))
			and not hit.has("drain"),
			"AC3: a zero-damage debuff never restores HP even on a wounded drainer")
		_check(int(trace["target_before"].get("hp", -1)) == int(hit.get("target_hp", -2)),
			"AC3: the zero-damage target keeps its exact HP")
		print("zero-damage debuff witness seed: ", seed_value)
		return
	_check(false, "AC3: a seeded zero-damage lint witness exists")


func _verify_miss() -> void:
	for seed_value in range(1, SEEDS_NEGATIVE + 1):
		var trace := _wound_and_attack(seed_value, "thread_biter", "warden_legs_hold", "thread_bite", 1)
		if trace.is_empty() or bool(trace.get("hit", {}).get("hit", true)):
			continue
		var hit: Dictionary = trace["hit"]
		_check(int(trace["foe_after"].get("hp", -1)) == int(trace["foe_before"].get("hp", -2))
			and not hit.has("drain") and int(hit.get("damage", -1)) == 0,
			"AC3: a real rolled miss heals nothing and deals no damage")
		print("miss witness seed: ", seed_value)
		return
	_check(false, "AC3: a seeded real miss witness exists")


## No canonical draining foe authors a self/ally action, so this focused probe pairs the real
## Fray Scavenger self buff with the optional trait on that same real foe. It proves the
## non-enemy-target path cannot drain and changes no authored catalog data.
func _verify_self_action() -> void:
	for seed_value in range(1, SEEDS_NEGATIVE + 1):
		var battle := _battle(seed_value, ["fray_scavenger", "ragling"])
		if battle == null:
			continue
		var receipts: Array = []
		if not _to(battle, "warden", receipts):
			continue
		var wound := battle.use_part("warden_legs_hold", 1)
		receipts.append(wound)
		if not bool(wound.get("ok", false)) or (wound.get("results", []) as Array).is_empty():
			continue
		if not bool(wound["results"][0].get("hit", false)) or int(wound["results"][0].get("damage", 0)) <= 0:
			continue
		battle._units["fray_scavenger"]["drain"] = true
		if not _to(battle, "fray_scavenger", receipts):
			continue
		var before := battle.get_unit("fray_scavenger")
		var self_receipt := battle.use_foe_ability("rag_cloak", 1)
		receipts.append(self_receipt)
		if not bool(self_receipt.get("ok", false)) or (self_receipt.get("results", []) as Array).is_empty():
			continue
		var after := battle.get_unit("fray_scavenger")
		var hit: Dictionary = self_receipt["results"][0]
		_check(int(after.get("hp", -1)) == int(before.get("hp", -2))
			and not hit.has("drain") and int(hit.get("damage", -1)) == 0,
			"AC3: a real self/ally action never drains or restores HP")
		print("self-action witness seed: ", seed_value)
		return
	_check(false, "AC3: a seeded self/ally action witness exists")


func _verify_zero_hp_target() -> void:
	for seed_value in range(1, SEEDS_NEGATIVE + 1):
		var battle := _battle(seed_value, ["thread_biter", "scissor_crab"])
		if battle == null:
			continue
		var receipts: Array = []
		if not _to(battle, "warden", receipts):
			continue
		var wound := battle.use_part("warden_legs_hold", 1)
		receipts.append(wound)
		if not bool(wound.get("ok", false)) or (wound.get("results", []) as Array).is_empty():
			continue
		if not bool(wound["results"][0].get("hit", false)) or int(wound["results"][0].get("damage", 0)) <= 0:
			continue
		# The hanging doll keeps its turn and is still a legal target, but cannot lose HP again.
		battle._units["warden"]["hp"] = 0
		battle._units["warden"]["hanging"] = true
		if not _to(battle, "thread_biter", receipts):
			continue
		var before := battle.get_unit("thread_biter")
		var receipt := battle.use_foe_ability("thread_bite", 1)
		if not bool(receipt.get("ok", false)) or (receipt.get("results", []) as Array).is_empty():
			continue
		var hit: Dictionary = receipt["results"][0]
		if not bool(hit.get("hit", false)) or int(hit.get("target_hp", -1)) != 0:
			continue
		var after := battle.get_unit("thread_biter")
		_check(int(after.get("hp", -1)) == int(before.get("hp", -2)) and not hit.has("drain"),
			"AC3: a target already at 0 HP never yields extra drain")
		print("zero-HP target witness seed: ", seed_value)
		return
	_check(false, "AC3: a seeded already-at-zero target witness exists")


func _verify_counter_kill() -> void:
	var trace := _find_counter_kill()
	_check(not trace.is_empty(), "AC3: a seeded Thorns counter-kill witness exists")
	if trace.is_empty():
		return
	var hit: Dictionary = trace["hit"]
	_check(bool(hit.get("hit", false)) and int(hit.get("damage", 0)) > 0,
		"AC3: the counter-killed drainer's bite still landed")
	_check(int(hit.get("thorns", 0)) > 0 and int(hit.get("attacker_hp", -1)) == 0,
		"AC3: the victim's Thorns counter is what reduced the drainer to zero")
	_check(int(trace["foe_before"].get("hp", 0)) > 0 and int(trace["foe_before"].get("hp", 0)) <= 2,
		"AC3: the drainer was genuinely low before its last bite")
	_check(bool(trace["foe_after"].get("dead", false)) and int(trace["foe_after"].get("hp", -1)) == 0,
		"AC3: the drainer died to the victim's Thorns counter")
	_check(not hit.has("drain"),
		"AC3: a drainer killed by the counter never heals or revives")
	_check(int(trace["target_before"].get("hp", -1)) > int(hit.get("target_hp", -2)),
		"AC3: the counter-kill still dealt the confirmed direct damage")


func _find_counter_kill() -> Dictionary:
	for seed_value in range(1, SEEDS_NEGATIVE + 1):
		var trace := _counter_kill_trace(seed_value)
		if trace.is_empty():
			continue
		print("counter-kill witness seed: ", seed_value)
		return trace
	return {}


func _counter_kill_trace(seed_value: int) -> Dictionary:
	var battle := _battle(seed_value, ["thread_biter", "scissor_crab"])
	if battle == null:
		return {}
	var receipts: Array = []
	var attackers := {
		"seamstress": "any_arm_red_thread",
		"tinker": "warden_torso_rivet",
	}
	for step in range(80):
		if battle.is_over():
			return {}
		var biter := battle.get_unit("thread_biter")
		if bool(biter.get("dead", false)) or int(biter.get("hp", 0)) <= 0:
			return {}
		var actor := battle.current_actor_id()
		if actor == "thread_biter":
			if int(biter.get("hp", 0)) > 2:
				receipts.append(battle.pass_turn())
				continue
			var warden := battle.get_unit("warden")
			if int(warden.get("statuses", {}).get("thorns", 0)) <= 0:
				return {}
			var before := battle.state_snapshot()
			var foe_before := biter.duplicate(true)
			var target_before := warden.duplicate(true)
			var receipt := battle.use_foe_ability("thread_bite", 1)
			receipts.append(receipt)
			var after := battle.state_snapshot()
			if not bool(receipt.get("ok", false)) or (receipt.get("results", []) as Array).is_empty():
				return {}
			var hit: Dictionary = receipt["results"][0]
			if not bool(hit.get("hit", false)):
				return {}
			var foe_after: Dictionary = _units_by_id(after).get("thread_biter", {})
			if not bool(foe_after.get("dead", false)) and int(foe_after.get("hp", 0)) > 0:
				return {}
			return {"seed": seed_value, "hit": hit, "foe_before": foe_before,
				"foe_after": foe_after, "target_before": target_before,
				"receipts": receipts, "before": before, "after": after}
		if actor == "warden":
			var thorns := int(battle.get_unit("warden").get("statuses", {}).get("thorns", 0))
			receipts.append(battle.use_part("warden_torso_quilt", 1) if thorns <= 0 else battle.pass_turn())
			continue
		if attackers.has(actor):
			var hp := int(biter.get("hp", 0))
			if hp > 2:
				if actor == "seamstress" and hp <= 5:
					receipts.append(battle.pass_turn())
				else:
					receipts.append(battle.use_part(str(attackers[actor]), 1))
			else:
				receipts.append(battle.pass_turn())
			continue
		receipts.append(battle.pass_turn())
	return {}


# ---------------------------------------------------------------- AC4 replay and draws

func _verify_replay_and_draws(primary: Dictionary) -> void:
	_check(not primary.is_empty(), "AC4: the replay check has a real drain witness")
	if primary.is_empty():
		return
	var seed_value := int(primary["seed"])
	var first := _wound_and_attack(seed_value, "thread_biter", "warden_legs_hold", "thread_bite", 1)
	var replay := _wound_and_attack(seed_value, "thread_biter", "warden_legs_hold", "thread_bite", 1)
	_check(not first.is_empty() and not replay.is_empty(), "AC4: the selected schedule replays")
	if first.is_empty() or replay.is_empty():
		return
	_check(first["receipts"] == replay["receipts"] and first["before"] == replay["before"]
		and first["after"] == replay["after"] and first["rng_after"] == replay["rng_after"],
		"AC4: the same seed and legal actions replay identical receipts, state and RNG")
	var control := _wound_and_attack(seed_value, "thread_biter", "warden_legs_hold", "thread_bite", 1,
		true)
	_check(not control.is_empty(), "AC4: the drain-free control battle builds and acts")
	if control.is_empty():
		return
	_check(first["rng_after"] == control["rng_after"]
		and first["hit"].get("roll") == control["hit"].get("roll")
		and first["hit"].get("crit") == control["hit"].get("crit")
		and first["hit"].get("damage") == control["hit"].get("damage")
		and first["hit"].get("target_hp") == control["hit"].get("target_hp")
		and first["hit"].get("statuses") == control["hit"].get("statuses"),
		"AC4: drain settles without an extra RNG draw or altered hit")
	_check(int(control["foe_after"].get("hp", -1)) == int(control["foe_before"].get("hp", -2)),
		"AC4: the same confirmed hit without the trait does not heal")
