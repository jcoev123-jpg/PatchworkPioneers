extends SceneTree
## S5 Spool Leech: the canonical elite's Drain Thread sews Weak 2, Mark 3 and 6 fray onto the
## doll it reaches, and the following Leech Bite hunts that Mark for its authored +4. The
## feature is data only: the existing StitchedFoeIntent chooser, StitchedRules action path and
## StitchedBattleScreen automatic foe driver already carry it.
##
## Deterministic and bounded: seeded public Pass/foe turns only, a bounded witness search, one
## explicit read-only selector fixture that plants a Mark status (test-only, clearly labelled),
## and two identical mounted replays through the real screen driver. No combat receipt is
## manufactured by editing HP or RNG.

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const ENEMY_PARTS := "res://data/parts/enemy_parts.json"
const LEECH := "spool_leech"
const RAGLING := "ragling"
const BITE := "leech_bite"
const DRAIN := "drain_thread"
const MARK := 3
const MARK_BONUS := 4
const FRAY := 6
const SEED_LIMIT := 40
const PROT_OVERRIDE := 40
const MOUNTED_SEED := 1
const PASS_LIMIT := 24

var checks := 0
var failures: Array[String] = []
var _catalog: Dictionary = {}
var _preview: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITES))
	_check(raw is Array, "AC1: the real elite catalog parses as an array")
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"AC1: canonical Stitched enemy catalog validates: " + str(_catalog.get("error", "")))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(parsed is Dictionary, "real S2 hero and part preview parses")
	if not raw is Array or not bool(_catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	_preview = parsed
	_test_source_contract(raw)
	_test_catalog_contract(raw)
	_test_trophy_part_unchanged()
	var witnesses := _search_witnesses()
	_test_drain_receipt(witnesses)
	_test_mark_countdown(witnesses)
	_test_marked_bite(witnesses)
	_test_unmarked_bite(witnesses)
	_test_crit_bite(witnesses)
	_test_protected_bite(witnesses)
	_test_rules_replay(witnesses)
	_test_mark_selection()
	_test_rejections()
	await _test_stage_driver()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_spool_leech_mark_drain_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


# ---------------------------------------------------------------- AC1 canonical record

func _bite_source() -> Dictionary:
	return {
		"id": BITE,
		"name": "Leech Bite",
		"kind": "melee",
		"launch": [1, 2],
		"target": [1, 2],
		"target_side": "enemy",
		"multi": false,
		"acc": 86,
		"dmg": [4, 6],
		"crit": 0,
		"mark_damage": MARK_BONUS,
		"effects": {"bleed": 1},
		"self_move": 0,
		"move": "attack2",
	}


func _drain_source() -> Dictionary:
	return {
		"id": DRAIN,
		"name": "Drain Thread",
		"kind": "debuff",
		"launch": [1, 3],
		"target": [1, 2],
		"target_side": "enemy",
		"multi": false,
		"acc": 90,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"weak": 2, "mark": MARK, "fray": FRAY},
		"self_move": 0,
		"move": "skill",
	}


## The authored record before this change, stated independently of the edited JSON.
func _original_bite() -> Dictionary:
	var bite := _bite_source()
	bite["target"] = [1]
	bite.erase("mark_damage")
	return bite


func _original_drain() -> Dictionary:
	var drain := _drain_source()
	drain["effects"] = {"weak": 2}
	return drain


func _leech_record() -> Dictionary:
	return {
		"id": LEECH,
		"name": "Spool Leech",
		"max_hp": 42,
		"drain": true,
		"chew_block_on_attack": true,
		"art_path": "res://assets/paper/enemies/spool_leech.png",
		"intent": {
			"target": "lowest_living_hp",
			"actions": [
				{"type": "attack", "amount": 8, "weight": 4},
				{"type": "debuff", "status": "weak", "amount": 2, "weight": 2},
				{"type": "block", "amount": 6, "weight": 1},
				{"type": "attack", "amount": 6, "hits": 2, "move": "attack2", "weight": 1},
				{"type": "attack", "amount": 10, "move": "attack3", "weight": 1},
			],
		},
		"stitched": {
			"max_hp": 42,
			"speed": 4,
			"dodge": 5,
			"acc": 0,
			"prot": 6,
			"is_boss": false,
			"turns_per_round": 1,
			"trophy": "spool_leech_maw",
			"abilities": [_bite_source(), _drain_source()],
		},
	}


func _records_with_id(raw: Array, enemy_id: String) -> Array:
	return raw.filter(func(record: Variant) -> bool:
		return record is Dictionary and str(record.get("id", "")) == enemy_id)


func _ability_of(record: Dictionary, ability_id: String) -> Dictionary:
	for ability in record.get("stitched", {}).get("abilities", []):
		if str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _without(source: Dictionary, keys: Array) -> Dictionary:
	var copy := source.duplicate(true)
	for key in keys:
		copy.erase(key)
	return copy


func _test_source_contract(raw: Array) -> void:
	var matches := _records_with_id(raw, LEECH)
	_check(matches.size() == 1, "AC1: exactly one source record carries the Spool Leech ID")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	var expected: Variant = JSON.parse_string(JSON.stringify(_leech_record()))
	_check(record == expected,
		"AC1: identity, 42 HP, drain flags, legacy lowest_living_hp intent, art, 4/5/6/0 stats, trophy and both actions stay exact")
	var bite := _ability_of(record, BITE)
	var drain := _ability_of(record, DRAIN)
	_check(_norm(bite) == _norm(_bite_source()),
		"AC1: Leech Bite keeps its authored fields and only gains target ranks 1-2 plus +4 versus Mark")
	_check(_norm(drain) == _norm(_drain_source()),
		"AC1: Drain Thread keeps its authored fields and its effects become Weak 2 + Mark 3 + Fray 6")
	_check(_norm(_without(bite, ["target", "mark_damage"]))
		== _norm(_without(_original_bite(), ["target", "mark_damage"]))
		and _norm(_without(drain, ["effects"])) == _norm(_without(_original_drain(), ["effects"])),
		"AC1: no field other than Bite target/Mark bonus and Drain effects changed from the original action")
	_check(_norm(bite) != _norm(_original_bite()) and _norm(drain) != _norm(_original_drain()),
		"AC1: the two stated deltas are real, not an echo of unchanged data")
	# Independent validator agreement, not an echo of the catalog loader.
	var bite_valid := StitchedParts.validate_ability(bite, "test leech bite")
	var drain_valid := StitchedParts.validate_ability(drain, "test drain thread")
	_check(bool(bite_valid.get("ok", false))
		and int(bite_valid.ability.get("mark_damage", 0)) == MARK_BONUS
		and bite_valid.ability.get("target") == [1, 2]
		and int(bite_valid.ability.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2])
		and int(bite_valid.ability.get("acc", 0)) == 86
		and bite_valid.ability.get("dmg") == [4, 6]
		and bite_valid.ability.get("effects") == {"bleed": 1},
		"AC1: StitchedParts.validate_ability normalizes Bite ranks 1-2 and its +4 Mark bonus")
	_check(bool(drain_valid.get("ok", false))
		and drain_valid.ability.get("effects") == {"weak": 2, "mark": MARK, "fray": FRAY}
		and int(drain_valid.ability.get("acc", 0)) == 90
		and drain_valid.ability.get("dmg") == [0, 0]
		and drain_valid.ability.get("launch") == [1, 3],
		"AC1: StitchedParts.validate_ability normalizes Drain Thread's Weak/Mark/Fray effects")


func _test_catalog_contract(raw: Array) -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, LEECH)
	_check(not foe.is_empty() and str(foe.get("name", "")) == "Spool Leech"
		and int(foe.get("max_hp", 0)) == 42 and int(foe.get("speed", -1)) == 4
		and int(foe.get("dodge", -1)) == 5 and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 6 and foe.get("is_boss") == false
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: loaded Spool Leech keeps 42 HP / SPEED 4 / DODGE 5 / ACC 0 / PROT 6 / one turn / no boss")
	_check(StitchedEnemyCatalog.trophy_for(_catalog, LEECH) == "spool_leech_maw"
		and _catalog.enemies.get(LEECH, {}).get("tier") == "elite",
		"AC1: the unique Leech Maw trophy and elite tier are unchanged")
	var bite_valid := StitchedParts.validate_ability(_bite_source())
	var drain_valid := StitchedParts.validate_ability(_drain_source())
	var abilities: Array = foe.get("abilities", [])
	_check(abilities.size() == 2
		and bool(bite_valid.get("ok", false)) and bool(drain_valid.get("ok", false))
		and abilities[0] == bite_valid.ability and abilities[1] == drain_valid.ability,
		"AC1: the real loader normalizes exactly the two authored actions in their authored order")
	# Every required elite ID still resolves, and neighbours keep their own kits. No
	# total-count or ordered-list oracle: other coders extend this catalog in parallel.
	for required in ["needle_marshal", "spool_hexer", "scissor_bailiff", "zipper_hauler",
			"pincushion_matriarch", LEECH]:
		var loaded := StitchedEnemyCatalog.foe_for(_catalog, required)
		_check(not loaded.is_empty() and str(loaded.get("id", "")) == required,
			"AC1: original elite ID still resolves: " + required)
	var neighbours := 0
	for record in raw:
		if not record is Dictionary or str(record.get("id", "")) == LEECH:
			continue
		neighbours += 1
		var neighbour_id := str(record.get("id", ""))
		var abilities_valid := true
		for ability in record.get("stitched", {}).get("abilities", []):
			abilities_valid = abilities_valid \
				and bool(StitchedParts.validate_ability(ability).get("ok", false))
		_check(_catalog.foes.has(neighbour_id)
			and StitchedEnemyCatalog.trophy_for(_catalog, neighbour_id)
				== str(record.get("stitched", {}).get("trophy", ""))
			and abilities_valid,
			"AC1: neighbour elite remains loaded with its own profile and trophy: " + neighbour_id)
	_check(neighbours >= 2, "AC1: non-vacuous neighbour coverage beside the edited Leech")


func _test_trophy_part_unchanged() -> void:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_PARTS))
	_check(document is Dictionary and document.get("parts") is Array,
		"AC1: the foreign enemy part catalog parses")
	if not document is Dictionary or not document.get("parts") is Array:
		return
	var matches: Array = (document["parts"] as Array).filter(func(part: Variant) -> bool:
		return part is Dictionary and str(part.get("id", "")) == "spool_leech_maw")
	_check(matches.size() == 1, "AC1: exactly one Leech Maw wearable part is authored")
	if matches.size() != 1:
		return
	var expected: Variant = JSON.parse_string(JSON.stringify({
		"id": "spool_leech_maw",
		"name": "Leech Maw",
		"slot": "arms",
		"owner": "any",
		"stat": {"dmg": 2},
		"ability": {
			"id": "leech_bite",
			"name": "Leech Bite",
			"kind": "melee",
			"launch": [1, 2],
			"target": [1],
			"target_side": "enemy",
			"multi": false,
			"acc": 86,
			"dmg": [4, 6],
			"crit": 0,
			"effects": {"bleed": 1},
			"self_move": 0,
			"move": "attack2",
		},
		"tiers": {
			"2": {"stat": {"dmg": 3}, "ability": {"dmg": [5, 7]}},
			"3": {"stat": {"dmg": 4}, "ability": {"dmg": [6, 8]}},
		},
		"text": "Bite the front foe with a rubbery leech maw.",
	}))
	_check(matches[0] == expected,
		"AC1: the foreign Leech Maw loot reward keeps its front-only Bite, damage and stitch tiers")
	var worn: Dictionary = _catalog.parts_by_id.get("spool_leech_maw", {})
	_check(not worn.is_empty() and worn.get("ability", {}).get("target") == [1]
		and int(worn.get("ability", {}).get("mark_damage", 0)) == 0
		and int(worn.get("tiers", {}).get("2", {}).get("ability", {}).get("dmg", [0, 0])[1]) == 7
		and int(worn.get("tiers", {}).get("3", {}).get("ability", {}).get("dmg", [0, 0])[0]) == 6,
		"AC1: the normalized loot part never gains the enemy kit's ranks or Mark bonus")


# ---------------------------------------------------------------- seeded battle fixture

func _make_battle(seed_value: int, prot_override: int = -1) -> StitchedRules:
	var heroes: Array = _preview["heroes"].duplicate(true)
	if prot_override >= 0:
		heroes[0]["prot"] = prot_override
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var foes: Array = [
		StitchedEnemyCatalog.foe_for(_catalog, LEECH),
		StitchedEnemyCatalog.foe_for(_catalog, RAGLING),
	]
	if foes[0].is_empty() or foes[1].is_empty():
		return null
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": heroes, "parts": parts, "foes": foes,
	})
	return built["battle"] if bool(built.get("ok", false)) else null


func _hero_id_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _snapshot_units(battle: StitchedRules) -> Dictionary:
	var units := {}
	for hero in battle.get_heroes():
		units[str(hero["id"])] = battle.get_unit(str(hero["id"]))
	for foe in battle.get_foes():
		units[str(foe["id"])] = battle.get_unit(str(foe["id"]))
	return units


func _record_step(battle: StitchedRules, trace: Variant, receipt: Dictionary) -> void:
	if trace == null:
		return
	(trace as Array).append({
		"receipt": receipt.duplicate(true),
		"round": battle.round_number(),
		"actor_after": battle.current_actor_id(),
		"order": battle.turn_order(),
		"rng": battle.rng_state(),
	})


## Legal public Passes until the Leech's next turn. While waiting, the watched doll's statuses
## are captured at the start of each of its own turns (its countdown already ticked there).
func _advance_to_leech(
	battle: StitchedRules, trace: Variant, watch_id: String, ticks: Array
) -> bool:
	for _step in range(200):
		if battle == null or battle.is_over():
			return false
		var actor_id := battle.current_actor_id()
		if actor_id == LEECH:
			return true
		if not watch_id.is_empty() and actor_id == watch_id:
			var unit := battle.get_unit(actor_id)
			ticks.append({
				"round": battle.round_number(),
				"mark": int(unit.get("statuses", {}).get("mark", 0)),
				"weak": int(unit.get("statuses", {}).get("weak", 0)),
				"fray": int(unit.get("fray", 0)),
				"hp": int(unit.get("hp", 0)),
			})
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			return false
		_record_step(battle, trace, passed)
	return false


## A real round-one Bite, round-two Drain Thread, round-three Bite through public turns. The
## source action order makes the Leech choose those actions in those rounds; the heroes only
## Pass, so every receipt is the Leech's own authored contribution.
func _run_cycle(seed_value: int, prot_override: int = -1, record_trace: bool = false) -> Dictionary:
	var battle := _make_battle(seed_value, prot_override)
	if battle == null:
		return {"ok": false, "fail": "build"}
	var trace: Variant = [] if record_trace else null
	if not _advance_to_leech(battle, trace, "", []):
		return {"ok": false, "fail": "reach the first Leech turn"}
	var start_round := battle.round_number()
	var intent1 := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	if str(intent1.get("ability_id", "")) != BITE:
		return {"ok": false, "fail": "the first Leech turn is not Leech Bite"}
	var rank1 := int(intent1.get("target_rank", 0))
	var units_before_bite1 := _snapshot_units(battle)
	var bite1 := battle.use_foe_ability(BITE, rank1)
	_record_step(battle, trace, bite1)
	if not bool(bite1.get("ok", false)) or (bite1.get("results", []) as Array).size() != 1:
		return {"ok": false, "fail": "the first Leech Bite resolves"}
	if not _advance_to_leech(battle, trace, "", []):
		return {"ok": false, "fail": "reach the second Leech turn"}
	if battle.round_number() != start_round + 1:
		return {"ok": false, "fail": "the second Leech turn is not the next round"}
	var intent2 := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	if str(intent2.get("ability_id", "")) != DRAIN:
		return {"ok": false, "fail": "the second Leech turn is not Drain Thread"}
	var drain_rank := int(intent2.get("target_rank", 0))
	# Snapshot immediately around the Drain Thread so only its own effects can differ.
	var units_before := _snapshot_units(battle)
	var drain := battle.use_foe_ability(DRAIN, drain_rank)
	_record_step(battle, trace, drain)
	if not bool(drain.get("ok", false)) or (drain.get("results", []) as Array).size() != 1:
		return {"ok": false, "fail": "the round-two Drain Thread resolves"}
	var units_after := _snapshot_units(battle)
	var actor_after_drain := battle.current_actor_id()
	var drain_result: Dictionary = (drain["results"] as Array)[0]
	var drain_target_id := str(drain_result["target"])
	var ticks: Array = []
	if not _advance_to_leech(battle, trace, drain_target_id, ticks):
		return {"ok": false, "fail": "reach the third Leech turn"}
	if battle.round_number() != start_round + 2:
		return {"ok": false, "fail": "the third Leech turn is not two rounds later"}
	var intent3 := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	if str(intent3.get("ability_id", "")) != BITE:
		return {"ok": false, "fail": "the third Leech turn is not Leech Bite"}
	var rank3 := int(intent3.get("target_rank", 0))
	var target3_before := battle.get_unit(_hero_id_at(battle, rank3))
	var attacker_statuses: Dictionary = battle.get_unit(LEECH).get("statuses", {}).duplicate(true)
	var bite3 := battle.use_foe_ability(BITE, rank3)
	_record_step(battle, trace, bite3)
	if not bool(bite3.get("ok", false)) or (bite3.get("results", []) as Array).size() != 1:
		return {"ok": false, "fail": "the third Leech Bite resolves"}
	return {
		"ok": true,
		"seed": seed_value,
		"battle": battle,
		"trace": trace,
		"start_round": start_round,
		"intent1": intent1,
		"rank1": rank1,
		"bite1": bite1,
		"hit1": (bite1["results"] as Array)[0],
		"units_before_bite1": units_before_bite1,
		"intent2": intent2,
		"drain_rank": drain_rank,
		"drain": drain,
		"drain_result": drain_result,
		"drain_target_id": drain_target_id,
		"units_before": units_before,
		"units_after": units_after,
		"actor_after_drain": actor_after_drain,
		"ticks": ticks,
		"intent3": intent3,
		"rank3": rank3,
		"target3_id": _hero_id_at(battle, rank3),
		"target3_before": target3_before,
		"attacker_statuses": attacker_statuses,
		"bite3": bite3,
		"hit3": (bite3["results"] as Array)[0],
		"mark_before3": int(target3_before.get("statuses", {}).get("mark", 0)),
		"weak_before3": int(target3_before.get("statuses", {}).get("weak", 0)),
	}


func _search_witnesses() -> Dictionary:
	var found := {"hit": {}, "two_ticks": {}, "miss": {}, "crit": {}}
	for seed_value in range(1, SEED_LIMIT + 1):
		if not found["hit"].is_empty() and not found["two_ticks"].is_empty() \
				and not found["miss"].is_empty() and not found["crit"].is_empty():
			break
		var dossier := _run_cycle(seed_value)
		if not bool(dossier.get("ok", false)):
			continue
		var drain_result: Dictionary = dossier["drain_result"]
		var hit1: Dictionary = dossier["hit1"]
		var hit3: Dictionary = dossier["hit3"]
		var drained := bool(drain_result.get("hit", false))
		var marked_bite := bool(hit3.get("hit", false)) and int(dossier["mark_before3"]) > 0
		if found["hit"].is_empty() and drained and marked_bite \
				and not bool(hit3.get("crit", false)) and (dossier["ticks"] as Array).size() >= 1:
			found["hit"] = dossier
		if found["two_ticks"].is_empty() and drained and marked_bite \
				and (dossier["ticks"] as Array).size() >= 2:
			found["two_ticks"] = dossier
		if found["miss"].is_empty() and not drained and bool(hit1.get("hit", false)) \
				and bool(hit3.get("hit", false)) and int(dossier["mark_before3"]) == 0:
			found["miss"] = dossier
		if found["crit"].is_empty() and drained and marked_bite \
				and bool(hit3.get("crit", false)):
			found["crit"] = dossier
	for key in found:
		_check(not found[key].is_empty(),
			"non-vacuous: bounded real seed witness is reachable: " + key)
	return found


# ---------------------------------------------------------------- AC2 Drain Thread receipt

func _test_drain_receipt(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var intent2: Dictionary = dossier["intent2"]
	var drain_result: Dictionary = dossier["drain_result"]
	var target_id := str(dossier["drain_target_id"])
	var target_before: Dictionary = (dossier["units_before"] as Dictionary).get(target_id, {})
	var target_after: Dictionary = (dossier["units_after"] as Dictionary).get(target_id, {})
	_check(str(dossier["intent2"].get("ability_id", "")) == DRAIN
		and str(intent2.get("ability_kind", "")) == "debuff"
		and not bool(intent2.get("multi", true))
		and int(intent2.get("base_acc", -1)) == 90
		and intent2.get("base_damage") == [0, 0]
		and intent2.get("base_effects") == {"weak": 2, "mark": MARK, "fray": FRAY}
		and int(intent2.get("base_mark_damage", -1)) == 0
		and int(intent2.get("target_rank", 0)) == int(dossier["drain_rank"]),
		"AC2: the live round-two intent announces the exact authored zero-damage Drain Thread")
	_check(bool(drain_result.get("hit", false)) and int(drain_result.get("damage", -1)) == 0
		and int(drain_result.get("target_hp", -1)) == int(target_before.get("hp", -2))
		and drain_result.get("statuses") == [
			{"status": "weak", "duration": 2}, {"status": "mark", "duration": MARK}]
		and str((drain_result.get("fray_event") as Dictionary).get("actor", "")) == target_id
		and int((drain_result.get("fray_event") as Dictionary).get("change", 0)) == FRAY,
		"AC2: a confirmed Drain Thread hit deals zero damage, applies Weak 2 + Mark 3 and adds 6 fray to its one target")
	_check(int(target_before.get("fray", -1)) + FRAY == int(target_after.get("fray", -2))
		and int(target_after.get("hp", -1)) == int(target_before.get("hp", -2)),
		"AC2: the reached doll really gains exactly 6 fray and loses no HP")
	# Exactly the reached hero: every other unit keeps its full state during the action.
	var actor_after := str(dossier["actor_after_drain"])
	var off_target_changed: Array = []
	for unit_id in dossier["units_before"]:
		if unit_id == target_id or unit_id == LEECH:
			continue
		if _norm(dossier["units_before"][unit_id]) != _norm(dossier["units_after"][unit_id]):
			off_target_changed.append(unit_id)
	_check(off_target_changed.is_empty(),
		"AC2: Drain Thread changes no other hero or foe at all")
	var tick := 1 if actor_after == target_id else 0
	var before_statuses: Dictionary = target_before.get("statuses", {})
	_check(int(target_after.get("statuses", {}).get("mark", 0)) == maxi(0, MARK - tick)
		and int(target_after.get("statuses", {}).get("weak", 0)) == maxi(0, 2 - tick)
		and int(target_after.get("statuses", {}).get("bleed", 0))
			== maxi(0, int(before_statuses.get("bleed", 0)) - tick),
		"AC2: exactly the reached doll carries Weak and Mark, minus only its own immediate start-turn tick")
	for hero in battle.get_heroes():
		if str(hero["id"]) == target_id:
			continue
		_check(int(hero.get("statuses", {}).get("mark", 0)) == 0
			and int(hero.get("statuses", {}).get("weak", 0)) == 0,
			"AC2: no off-target doll is Marked or Weakened by Drain Thread")
	# The natural miss applies none of it.
	var miss: Dictionary = witnesses.get("miss", {})
	if miss.is_empty():
		return
	var miss_result: Dictionary = miss["drain_result"]
	var miss_target := str(miss["drain_target_id"])
	var miss_after: Dictionary = (miss["units_after"] as Dictionary).get(miss_target, {})
	_check(not bool(miss_result.get("hit", true)) and int(miss_result.get("damage", -1)) == 0
		and (miss_result.get("statuses", [-1]) as Array).is_empty()
		and not miss_result.has("fray_event"),
		"AC2: a natural Drain Thread miss applies no Weak, Mark or fray")
	_check(int(miss_after.get("statuses", {}).get("mark", 0)) == 0
		and int(miss_after.get("statuses", {}).get("weak", 0)) == 0,
		"AC2: the missed doll really carries no status afterwards")
	for hero in miss["battle"].get_heroes():
		_check(int(hero.get("fray", -1)) == int(
			(miss["units_before"] as Dictionary).get(str(hero["id"]), {}).get("fray", -2)),
			"AC2: a missed Drain Thread adds no fray to any doll: " + str(hero["id"]))


func _test_mark_countdown(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("two_ticks", {})
	if dossier.is_empty():
		return
	var start_round := int(dossier["start_round"])
	var ticks: Array = dossier["ticks"]
	_check(ticks.size() >= 2, "AC2: the witness really lets the marked doll take two own turns")
	var stepping := true
	for index in range(ticks.size()):
		var tick: Dictionary = ticks[index]
		stepping = stepping \
			and int(tick["mark"]) == maxi(0, MARK - (index + 1)) \
			and int(tick["weak"]) == maxi(0, 2 - (index + 1)) \
			and int(tick["fray"]) == FRAY \
			and int(tick["round"]) >= start_round + 1 \
			and int(tick["round"]) <= start_round + 2
	_check(stepping,
		"AC2: Mark and Weak tick down exactly one per real own turn, never on a fixed hero/foe speed clock")
	_check(int(dossier["mark_before3"]) == MARK - ticks.size()
		and int(dossier["weak_before3"]) == maxi(0, 2 - ticks.size()),
		"AC2: the follow-up Bite sees Mark 3 minus exactly the doll's own turn countdowns")
	_check(int(dossier["mark_before3"]) > 0,
		"AC2: the authored Mark 3 survives into the round-three Leech Bite in real turn order")


# ---------------------------------------------------------------- AC2/AC3 real Bite damage

func _norm(value: Variant) -> Variant:
	if value is Array:
		var array: Array = []
		for item in value:
			array.append(_norm(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[key] = _norm(value[key])
		return dictionary
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return value


## The direct bases this hit could have rolled: the authored range plus the attacker's flat
## arms bonus, or the crit formula when the receipt says the hit critted.
func _bases(attacker: Dictionary, ability: Dictionary, crit: bool) -> Array[int]:
	if crit:
		return [StitchedRules.crit_damage(int(ability["dmg"][1])) + int(attacker.get("dmg_bonus", 0))]
	var bases: Array[int] = []
	for value in range(int(ability["dmg"][0]), int(ability["dmg"][1]) + 1):
		bases.append(value + int(attacker.get("dmg_bonus", 0)))
	return bases


func _actor_ability(actor: Dictionary, ability_id: String) -> Dictionary:
	for ability in actor.get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _matching_bases(
	attacker: Dictionary, ability: Dictionary, attacker_statuses: Dictionary,
	defender: Dictionary, marked: bool, damage: int, crit: bool
) -> Array[int]:
	var matched: Array[int] = []
	for base in _bases(attacker, ability, crit):
		if int(StitchedRules.damage_after_modifiers(
				base, attacker_statuses, defender.get("statuses", {}), marked, MARK_BONUS,
				int(defender.get("prot", 0)))) == damage:
			matched.append(base)
	return matched


func _test_marked_bite(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var attacker := battle.get_unit(LEECH)
	var ability := _actor_ability(attacker, BITE)
	var hit3: Dictionary = dossier["hit3"]
	var before3: Dictionary = dossier["target3_before"]
	var intent3: Dictionary = dossier["intent3"]
	var target3_id := str(dossier["target3_id"])
	_check(int(dossier["mark_before3"]) > 0
		and int(intent3.get("target_rank", 0)) == int(dossier["rank3"])
		and target3_id == str(dossier["drain_target_id"]),
		"AC2/AC3: the round-three Bite again reaches the doll its Drain Thread Marked")
	_check(str(intent3.get("ability_id", "")) == BITE
		and str(intent3.get("ability_kind", "")) == "melee"
		and intent3.get("base_damage") == [4, 6]
		and int(intent3.get("base_mark_damage", -1)) == MARK_BONUS
		and intent3.get("base_effects") == {"bleed": 1}
		and intent3.get("affected_ranks") == [int(dossier["rank3"])],
		"AC3: the live intent announces the authored Bite with its exact +4 versus Mark")
	var matched := _matching_bases(attacker, ability, dossier["attacker_statuses"], before3,
		true, int(hit3["damage"]), bool(hit3.get("crit", false)))
	_check(bool(hit3.get("hit", false)) and not matched.is_empty()
		and int(hit3.get("damage", -1))
			== int(before3.get("hp", 0)) - int(hit3.get("target_hp", 0)),
		"AC2: the marked Bite's real HP loss equals damage_after_modifiers on its rolled base")
	var clean := int(before3.get("statuses", {}).get("exposed", 0)) == 0 \
		and int(before3.get("statuses", {}).get("tangled", 0)) == 0 \
		and int(dossier["attacker_statuses"].get("weak", 0)) == 0
	var prot := int(before3.get("prot", 0))
	for base in matched:
		var marked := int(StitchedRules.damage_after_modifiers(base, dossier["attacker_statuses"],
			before3.get("statuses", {}), true, MARK_BONUS, prot))
		var unmarked := int(StitchedRules.damage_after_modifiers(base, dossier["attacker_statuses"],
			before3.get("statuses", {}), false, MARK_BONUS, prot))
		_check(marked == int(hit3["damage"]) and unmarked < marked
			and (not clean or (marked == int(StitchedRules.apply_protection(base + MARK_BONUS, prot))
				and unmarked == int(StitchedRules.apply_protection(base, prot)))),
			"AC2: the authored +4 is added to the direct base before Weak/Exposed/Tangled/PROT")
	_check(clean, "AC2: the witness's marked hit is a clean direct base, so the delta is the Mark alone")
	# The round-one Bite struck the front line before any Drain Thread: no bonus.
	var hit1: Dictionary = dossier["hit1"]
	var bite1_target := str(hit1.get("target", ""))
	var before1: Dictionary = (dossier["units_before_bite1"] as Dictionary).get(bite1_target, {})
	var unmarked_matches := _matching_bases(attacker, ability,
		battle.get_unit(LEECH).get("statuses", {}), before1, false,
		int(hit1["damage"]), bool(hit1.get("crit", false)))
	_check(bite1_target == target3_id
		and int(before1.get("statuses", {}).get("mark", 0)) == 0
		and bool(hit1.get("hit", false)) and not unmarked_matches.is_empty(),
		"AC2: the earlier unmarked Bite against the same doll matches only the unmarked formula")


func _test_unmarked_bite(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("miss", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var hit3: Dictionary = dossier["hit3"]
	var before3: Dictionary = dossier["target3_before"]
	var matched := _matching_bases(battle.get_unit(LEECH), _actor_ability(battle.get_unit(LEECH), BITE),
		dossier["attacker_statuses"], before3, false, int(hit3["damage"]),
		bool(hit3.get("crit", false)))
	_check(int(dossier["mark_before3"]) == 0 and bool(hit3.get("hit", false))
		and not matched.is_empty(),
		"AC3: with no reachable Mark the Bite falls back to an unmarked hit with no bonus")
	for base in matched:
		_check(int(StitchedRules.damage_after_modifiers(base, dossier["attacker_statuses"],
				before3.get("statuses", {}), true, MARK_BONUS, int(before3.get("prot", 0))))
			> int(hit3["damage"]),
			"AC3: had a Mark been live this unmarked hit would have dealt the authored +4")


func _test_crit_bite(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("crit", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var attacker := battle.get_unit(LEECH)
	var hit3: Dictionary = dossier["hit3"]
	var before3: Dictionary = dossier["target3_before"]
	var base := StitchedRules.crit_damage(6) + int(attacker.get("dmg_bonus", 0))
	var expected := int(StitchedRules.damage_after_modifiers(base, dossier["attacker_statuses"],
		before3.get("statuses", {}), true, MARK_BONUS, int(before3.get("prot", 0))))
	_check(bool(hit3.get("crit", false)) and int(hit3.get("damage", -1)) == expected,
		"AC3: a critical marked Bite is floor(1.5 x max) + 4, then the usual modifiers")
	_check(int(StitchedRules.damage_after_modifiers(base, dossier["attacker_statuses"],
			before3.get("statuses", {}), false, MARK_BONUS, int(before3.get("prot", 0)))) < expected,
		"AC3: the critical hit's extra is the Mark, not a changed crit formula")


func _test_protected_bite(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var normal: Dictionary = _run_cycle(int(dossier["seed"]))
	var protected: Dictionary = _run_cycle(int(dossier["seed"]), PROT_OVERRIDE)
	_check(bool(normal.get("ok", false)) and bool(protected.get("ok", false)),
		"AC3: the same seed replays with a raised-PROT front doll as a protection control")
	if not bool(normal.get("ok", false)) or not bool(protected.get("ok", false)):
		return
	var normal_hit: Dictionary = normal["hit3"]
	var protected_hit: Dictionary = protected["hit3"]
	var before3: Dictionary = protected["target3_before"]
	_check(bool(normal_hit.get("hit", false)) and bool(protected_hit.get("hit", false))
		and bool(normal_hit.get("crit", false)) == bool(protected_hit.get("crit", false))
		and int(normal_hit.get("roll", -1)) == int(protected_hit.get("roll", -2)),
		"AC3: PROT changes only mitigation, never the seeded hit/crit roll")
	_check(int(before3.get("prot", 0)) >= PROT_OVERRIDE,
		"AC3: the control doll really wears more PROT than the authored front doll")
	var prot := int(before3.get("prot", 0))
	var matched := _matching_bases(protected["battle"].get_unit(LEECH),
		_actor_ability(protected["battle"].get_unit(LEECH), BITE), protected["attacker_statuses"],
		before3, true, int(protected_hit["damage"]), bool(protected_hit.get("crit", false)))
	_check(not matched.is_empty(),
		"AC3: protected marked damage is the protected cut of base + 4")
	for base in matched:
		var marked_final := int(StitchedRules.apply_protection(base + MARK_BONUS, prot))
		var unmarked_final := int(StitchedRules.apply_protection(base, prot))
		_check(marked_final == int(protected_hit["damage"])
			and marked_final > unmarked_final and marked_final - unmarked_final < MARK_BONUS,
			"AC3: PROT cuts the already-added +4, so the left-over gain is smaller but still present")


# ---------------------------------------------------------------- AC3 selector and refusals

## Passes every turn (foes included) until the Leech's own turn of the wanted round. Passing a
## foe turn spends it without acting, so this is a legal public path and changes no RNG odds.
func _advance_silent(battle: StitchedRules, wanted_round: int) -> bool:
	for _step in range(200):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > wanted_round:
			return false
		if battle.current_actor_id() == LEECH and battle.round_number() == wanted_round:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


## TEST-ONLY SELECTOR FIXTURE: plants a Mark status on already-built living dolls solely to
## isolate StitchedFoeIntent's precedence. Every applied-status and damage receipt above came
## from landed public actions; nothing here is shipped data or a combat outcome.
func _test_mark_selection() -> void:
	var battle := _make_battle(37)
	if battle == null:
		_check(false, "AC3: the real mark-selection battle builds")
		return
	if not _advance_silent(battle, 3):
		_check(false, "AC3: the real battle reaches the Leech's round-three Bite turn")
		return
	var leech := battle.get_unit(LEECH)
	var bite := _actor_ability(leech, BITE)
	var rank1 := _hero_id_at(battle, 1)
	var rank2 := _hero_id_at(battle, 2)
	var rank3 := _hero_id_at(battle, 3)
	_check(not rank1.is_empty() and not rank2.is_empty() and not rank3.is_empty(),
		"AC3: the front three legal hero ranks are occupied")
	var legal_ranks: Array[int] = []
	for rank in range(1, 5):
		if not battle._legal_targets(leech, bite, rank).is_empty():
			legal_ranks.append(rank)
	_check(legal_ranks.has(1) and legal_ranks.has(2) and not legal_ranks.has(3),
		"AC3: Bite's authored rank mask reaches 1-2 and refuses rank 3")
	# Test-only selector fixture: a marked reachable rank 2 and an unmarked nearer rank 1.
	battle._units[rank2]["statuses"]["mark"] = MARK
	battle._units[rank3]["statuses"]["mark"] = MARK
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	_check(str(choice.get("ability_id", "")) == BITE
		and int(choice.get("target_rank", 0)) == 2
		and choice.get("affected_ranks") == [2]
		and str(choice.get("target_side", "")) == "hero"
		and int(choice.get("base_acc", -1)) == 86
		and choice.get("base_damage") == [4, 6]
		and int(choice.get("base_mark_damage", -1)) == MARK_BONUS
		and choice.get("base_effects") == {"bleed": 1},
		"AC3: the read-only intent prefers the marked legal rank 2 over the nearer unmarked rank 1")
	var repeated := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	_check(_norm(repeated) == _norm(choice) and battle.state_snapshot() == state
		and battle.rng_state() == rng,
		"AC3: repeated forecasts mutate neither state, statuses, turn nor RNG")
	# An out-of-mask Mark cannot steal the hunt; closest Marked wins when both are legal.
	battle._units[rank3]["statuses"].erase("mark")
	battle._units[rank1]["statuses"]["mark"] = MARK
	var closest := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	_check(int(closest.get("target_rank", 0)) == 1 and closest.get("affected_ranks") == [1],
		"AC3: two legal marked dolls keep the closest rank, and an out-of-mask rank is never chosen")
	battle._units[rank1]["statuses"].erase("mark")
	battle._units[rank2]["statuses"].erase("mark")
	# Expired/no Mark: the ordinary nearest-legal-rank fallback returns.
	var nearest := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	_check(int(nearest.get("target_rank", 0)) == 1 and nearest.get("affected_ranks") == [1]
		and int(nearest.get("base_mark_damage", -1)) == MARK_BONUS,
		"AC3: expired or absent Mark falls back to the nearest legal rank with no invented target")
	# A lost marked doll is not a legal hunt target even while its Mark status remains.
	battle._units[rank2]["statuses"]["mark"] = MARK
	battle._units[rank2]["lost"] = true
	var lost := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	_check(int(lost.get("target_rank", 0)) == 1 and not bool(lost.get("pass", true)),
		"AC3: a lost marked doll cannot be hunted and the legal front rank returns")
	battle._units[rank2]["lost"] = false
	battle._units[rank2]["statuses"].erase("mark")
	# An unlaunchable Leech (rank 4, outside both abilities' launch ranks) forecasts PASS.
	battle._units[LEECH]["rank"] = 4
	var blocked := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	_check(bool(blocked.get("pass", false)) and not bool(blocked.get("stun", false))
		and str(blocked.get("ability_id", "")) == "" and int(blocked.get("target_rank", -1)) == 0
		and not blocked.has("base_damage"),
		"AC3: an unlaunchable Leech reports PASS and invents no attack or Mark bonus")
	battle._units[LEECH]["rank"] = 1
	_check(StitchedFoeIntent.choose(battle, {}).is_empty()
		and StitchedFoeIntent.choose(battle, {"id": "ghost_foe"}).is_empty(),
		"AC3: empty and impostor foe dictionaries never invent an intent")
	battle._units[LEECH]["dead"] = true
	battle._units[LEECH]["hp"] = 0
	_check(StitchedFoeIntent.choose(battle, battle.get_unit(LEECH)).is_empty(),
		"AC3: a dead Leech has no selectable intent")
	battle._units[LEECH]["dead"] = false
	battle._units[LEECH]["hp"] = int(battle._units[LEECH]["max_hp"])
	_check(str(StitchedFoeIntent.choose(battle, battle.get_unit(LEECH)).get("ability_id", "")) == BITE,
		"AC3: the restored Leech returns to its authored Bite intent")


func _test_rejections() -> void:
	var battle := _make_battle(37)
	if battle == null:
		return
	var reached := _advance_silent(battle, 3)
	_check(reached, "AC3: non-vacuous real Leech turn is reached for the refusal checks")
	if not reached:
		return
	battle._units[_hero_id_at(battle, 2)]["statuses"]["mark"] = MARK
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var ordered := battle.turn_order()
	var off_rank := battle.use_foe_ability(BITE, 3)
	_check(not bool(off_rank.get("ok", true))
		and str(off_rank.get("error", "")).contains("no legal target")
		and battle.state_snapshot() == state and battle.rng_state() == rng
		and battle.turn_order() == ordered,
		"AC3: an off-rank marked Bite is refused with no state, turn or RNG spend")
	var unknown := battle.use_foe_ability("not_an_authored_ability", 2)
	_check(not bool(unknown.get("ok", true))
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3: an unauthored Leech action is refused with identical state and RNG")
	var drain_off_rank := battle.use_foe_ability(DRAIN, 3)
	_check(not bool(drain_off_rank.get("ok", true))
		and str(drain_off_rank.get("error", "")).contains("no legal target")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3: Drain Thread outside its authored ranks is refused before any roll")
	battle._units[LEECH]["rank"] = 4
	var unlaunchable := battle.use_foe_ability(BITE, 1)
	battle._units[LEECH]["rank"] = 1
	_check(not bool(unlaunchable.get("ok", true))
		and str(unlaunchable.get("error", "")).contains("cannot launch")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3: a Bite the Leech cannot launch from rank 4 is refused before any roll")
	var stale := battle.get_unit(LEECH)
	stale["abilities"] = []
	var authoritative := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	var from_stale := StitchedFoeIntent.choose(battle, stale)
	_check(_norm(from_stale) == _norm(authoritative)
		and str(from_stale.get("ability_id", "")) == BITE
		and int(from_stale.get("target_rank", 0)) == 2,
		"AC3: a detached stale foe dictionary cannot forge an empty kit or another target")
	_check(battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3: every rejected command and detached forecast left the battle untouched")


# ---------------------------------------------------------------- AC4 real stage driver

func _stage_config() -> Dictionary:
	var config: Dictionary = StitchedBattleScreen.read_preview().duplicate(true)
	config["seed"] = MOUNTED_SEED
	config["candle"] = 100
	config["parts"].append_array(_catalog["parts"].duplicate(true))
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(_catalog, LEECH),
		StitchedEnemyCatalog.foe_for(_catalog, RAGLING),
	]
	return config


func _mount_stage() -> Dictionary:
	var host := Control.new()
	host.name = "SpoolLeechDriverHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var stage := StitchedBattleScreen.new()
	var started := stage.begin(_stage_config())
	_check(started, "AC4: the seeded Spool Leech battle starts through actual StitchedBattleScreen.begin")
	if not started:
		host.free()
		return {}
	host.add_child(stage)
	return {"host": host, "stage": stage}


## Hero Passes only: the screen's own _drive_foes resolves every foe turn. Each receipt is
## captured with the round and displayed intent that were current when the pass was submitted,
## and every doll's live statuses are recorded before each pass (post its own start-turn tick).
func _drive_stage(stage: StitchedBattleScreen) -> Dictionary:
	var battle := stage.battle
	var captured: Array = []
	var status_trace: Array = []
	for _step in range(PASS_LIMIT):
		if battle.is_over():
			break
		if battle.current_side() != "hero":
			break
		var snap := battle.state_snapshot()
		var heroes: Dictionary = {}
		for hero in battle.get_heroes():
			var live: Dictionary = battle.get_unit(str(hero["id"]))
			heroes[str(hero["id"])] = {
				"statuses": live.get("statuses", {}).duplicate(true),
				"hp": int(live.get("hp", 0)),
				"fray": int(live.get("fray", 0)),
			}
		status_trace.append({"round": int(snap["round"]), "heroes": heroes})
		var order: Array = snap["order"]
		var next_index := int(snap["turn_index"]) + 1
		var next_id := str(order[next_index]) if next_index < order.size() else ""
		var expected := {}
		if next_id == LEECH:
			for rank in range(1, 5):
				var projected: Dictionary = stage._foe_intents.get(rank, {})
				if str(projected.get("foe_id", "")) == LEECH:
					expected = projected.duplicate(true)
		var before := stage.receipts.size()
		var result := stage.submit_pass()
		_check(bool(result.get("ok", false)), "AC4: a public hero Pass spends exactly one hero turn")
		if not bool(result.get("ok", false)):
			break
		var expected_used := false
		for index in range(before, stage.receipts.size()):
			var receipt: Dictionary = stage.receipts[index]
			var is_first_ability := str(receipt.get("action", "")) == "ability" and not expected_used
			captured.append({
				"receipt": receipt.duplicate(true),
				"round": int(snap["round"]),
				"expected": expected.duplicate(true) if is_first_ability else {},
				"leech": str(receipt.get("actor", "")) == LEECH,
			})
			if is_first_ability:
				expected_used = true
		var leech_receipts := captured.filter(func(entry: Dictionary) -> bool:
			return bool(entry["leech"]) and str(entry["receipt"].get("ability", "")) != "")
		if leech_receipts.size() >= 3:
			break
	return {
		"captured": captured,
		"status_trace": status_trace,
		"battle": battle,
		"final_state": battle.state_snapshot(),
		"rng": battle.rng_state(),
		"intents": _norm(stage._foe_intents),
	}


## The last recorded live observation of one doll on or before a round.
func _observed_unit(status_trace: Array, hero_id: String, round_value: int) -> Dictionary:
	var found := {"statuses": {}, "hp": -1, "fray": 0}
	for entry in status_trace:
		if int(entry["round"]) <= round_value and (entry["heroes"] as Dictionary).has(hero_id):
			found = (entry["heroes"] as Dictionary)[hero_id].duplicate(true)
	return found


func _test_stage_driver() -> void:
	var first_mount := _mount_stage()
	if first_mount.is_empty():
		return
	await process_frame
	var first_stage: StitchedBattleScreen = first_mount["stage"]
	var first := _drive_stage(first_stage)
	var first_host: Control = first_mount["host"]
	var leech_actions: Array = first["captured"].filter(func(entry: Dictionary) -> bool:
		return bool(entry["leech"]) and str(entry["receipt"].get("ability", "")) != "")
	_check(leech_actions.size() >= 3,
		"AC4: the existing automatic foe driver resolves three real Leech turns")
	if leech_actions.size() >= 3:
		var abilities: Array = []
		var rounds: Array = []
		var intents_match := true
		for entry in leech_actions.slice(0, 3):
			abilities.append(str(entry["receipt"].get("ability", "")))
			rounds.append(int(entry["round"]))
			var expected: Dictionary = entry["expected"]
			var result: Dictionary = (entry["receipt"]["results"] as Array)[0]
			intents_match = intents_match \
				and str(expected.get("ability_id", "")) == str(entry["receipt"].get("ability", "")) \
				and int(expected.get("target_rank", 0)) == int(result.get("target_rank", -1))
		_check(abilities == [BITE, DRAIN, BITE],
			"AC4: the driver's Leech sequence is Leech Bite, Drain Thread, Leech Bite by authored rotation")
		_check(rounds.size() == 3 and rounds[1] == rounds[0] + 1 and rounds[2] == rounds[0] + 2,
			"AC4: those three driven Leech turns are consecutive real rounds")
		_check(intents_match,
			"AC4: every driven Leech action matches its displayed StitchedFoeIntent ability and target rank")
		var drain_entry: Dictionary = leech_actions[1]
		var drain_receipt: Dictionary = drain_entry["receipt"]
		var drain_result: Dictionary = (drain_receipt["results"] as Array)[0]
		var drained_id := str(drain_result.get("target", ""))
		var bitten_entry: Dictionary = leech_actions[2]
		var bitten_receipt: Dictionary = bitten_entry["receipt"]
		var bitten_result: Dictionary = (bitten_receipt["results"] as Array)[0]
		_check(str(drain_result.get("target", "")) == str(bitten_result.get("target", ""))
			and bool(drain_result.get("hit", false)) and bool(bitten_result.get("hit", false)),
			"AC4: the driven Drain Thread and follow-up Bite really reach the same doll")
		_check(int(drain_result.get("damage", -1)) == 0
			and drain_result.get("statuses") == [
				{"status": "weak", "duration": 2}, {"status": "mark", "duration": MARK}]
			and str((drain_result.get("fray_event") as Dictionary).get("actor", "")) == drained_id
			and int((drain_result.get("fray_event") as Dictionary).get("change", 0)) == FRAY,
			"AC4: the driven Drain Thread receipt commits Weak 2 + Mark 3 + 6 fray through the real enemy path")
		var battle: StitchedRules = first["battle"]
		var defender: Dictionary = battle.get_unit(drained_id)
		var attacker: Dictionary = battle.get_unit(LEECH)
		var bite_round := int(bitten_entry["round"])
		var observed := _observed_unit(first["status_trace"], drained_id, bite_round)
		var observed_statuses: Dictionary = observed.get("statuses", {})
		var marked := int(observed_statuses.get("mark", 0)) > 0
		_check(marked and int(observed_statuses.get("exposed", 0)) == 0
			and int(observed_statuses.get("tangled", 0)) == 0,
			"AC4: the driven follow-up Bite really lands while the Marked doll still carries its Mark")
		var prot := int(defender.get("prot", 0))
		var expected_damage := _matching_bases(attacker, _actor_ability(attacker, BITE), {},
			{"statuses": observed_statuses, "prot": prot}, marked,
			int(bitten_result.get("damage", -1)), bool(bitten_result.get("crit", false)))
		_check(not expected_damage.is_empty(),
			"AC4: the driven Bite's real damage equals the marked formula with its authored +4")
		for base in expected_damage:
			var marked_final := int(StitchedRules.damage_after_modifiers(base, {},
				observed_statuses, true, MARK_BONUS, prot))
			var unmarked_final := int(StitchedRules.damage_after_modifiers(base, {},
				observed_statuses, false, MARK_BONUS, prot))
			_check(marked_final == int(bitten_result["damage"]) and unmarked_final < marked_final,
				"AC4: the driven Bite's extra damage is exactly the authored Mark bonus")
		_check(int(observed.get("hp", -1)) - int(bitten_result.get("damage", 0))
			== int(bitten_result.get("target_hp", -2)),
			"AC4: the driven Bite's real HP loss equals its reported direct damage")
	first_host.free()

	# Same seed, same public inputs, same driver: identical intents, receipts, state and RNG.
	var second_mount := _mount_stage()
	if second_mount.is_empty():
		return
	await process_frame
	var second_stage: StitchedBattleScreen = second_mount["stage"]
	var second := _drive_stage(second_stage)
	var second_host: Control = second_mount["host"]
	_check(_norm(first["captured"]) == _norm(second["captured"]),
		"AC4: identical seeds replay every captured intent and receipt through the real screen driver")
	_check(first["final_state"] == second["final_state"] and first["rng"] == second["rng"]
		and first["intents"] == second["intents"],
		"AC4: identical seeds replay the same battle state, displayed intents and RNG position")
	_check((first["captured"] as Array).size() >= 6,
		"AC4: non-vacuous: the driven replay includes real hero Passes and foe receipts")
	second_host.free()


func _test_rules_replay(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var first := _run_cycle(int(dossier["seed"]), -1, true)
	var second := _run_cycle(int(dossier["seed"]), -1, true)
	_check(bool(first.get("ok", false)) and bool(second.get("ok", false)),
		"AC4: both identical-seed lawful rules cycles complete")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	_check(_norm(first["trace"]) == _norm(second["trace"]),
		"AC4: identical seeds replay every rules receipt, round, actor order and RNG position")
	_check(_norm(first["battle"].state_snapshot()) == _norm(second["battle"].state_snapshot())
		and first["battle"].turn_order() == second["battle"].turn_order()
		and first["battle"].rng_state() == second["battle"].rng_state(),
		"AC4: full rules snapshots, turn order and RNG state match exactly")
	_check((first["trace"] as Array).size() >= 6,
		"AC4: non-vacuous: the rules replay includes real Passes and three foe actions")
