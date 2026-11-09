extends SceneTree
## S5 Spool Leech double seam: the canonical elite's authored Drain Thread is a multi-target
## action over its own target ranks 1-2, so one Stitched turn reaches both legal front dolls,
## each with its own seeded hit. A miss in one rank never carries Weak/Mark/Fray into it, and a
## rank without a living legal doll is never invented. The following Leech Bite keeps its
## authored Mark pursuit, +4 Mark damage, 4-6 damage, ACC 86, Bleed 1 and HP drain.
##
## Deterministic and bounded: real catalog data, the real StitchedRules/StitchedFoeIntent
## projection, public Passes and committed use_foe_ability actions. The only planted state is a
## clearly labelled LOST doll used to prove the "one legal rank" seam; no receipt is forged.

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
const SEED_LIMIT := 80
const PASS_LIMIT := 200

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
	_check(parsed is Dictionary and parsed.get("heroes") is Array,
		"real S2 hero and part preview parses")
	if not raw is Array or not bool(_catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	_preview = parsed
	_test_authored_record(raw)
	_test_two_rank_seam()
	_test_single_rank_seam()
	_test_fail_closed()
	_test_mark_follow_up()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_spool_leech_double_seam_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


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


func _differing_keys(a: Dictionary, b: Dictionary) -> Array:
	var keys: Dictionary = {}
	for key in a:
		keys[key] = true
	for key in b:
		keys[key] = true
	var differing: Array = []
	for key in keys:
		if _norm(a.get(key)) != _norm(b.get(key)):
			differing.append(str(key))
	differing.sort()
	return differing


# ---------------------------------------------------------------- AC1 authored record

## The canonical Drain Thread exactly as this task authors it: the only two-rank change.
func _authored_drain() -> Dictionary:
	return {
		"id": DRAIN,
		"name": "Drain Thread",
		"kind": "debuff",
		"launch": [1, 3],
		"target": [1, 2],
		"target_side": "enemy",
		"multi": true,
		"acc": 90,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"weak": 2, "mark": MARK, "fray": FRAY},
		"self_move": 0,
		"move": "skill",
	}


## The same record as it shipped before this change: everything but the seam is identical.
func _shipped_drain() -> Dictionary:
	var drain := _authored_drain()
	drain["multi"] = false
	return drain


func _authored_bite() -> Dictionary:
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


func _records_with_id(raw: Array, enemy_id: String) -> Array:
	return raw.filter(func(record: Variant) -> bool:
		return record is Dictionary and str(record.get("id", "")) == enemy_id)


func _ability_of(record: Dictionary, ability_id: String) -> Dictionary:
	for ability in record.get("stitched", {}).get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _test_authored_record(raw: Array) -> void:
	var matches := _records_with_id(raw, LEECH)
	_check(matches.size() == 1, "AC1: exactly one source record carries the Spool Leech ID")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	var drain := _ability_of(record, DRAIN)
	var bite := _ability_of(record, BITE)
	_check(not drain.is_empty() and not bite.is_empty()
		and _norm(bite) == _norm(_authored_bite())
		and _norm(drain) == _norm(_authored_drain()),
		"AC1: Drain Thread is authored exactly as launch 1-3 / target 1-2 / ACC 90 / [0,0] / Weak 2 + Mark 3 + Fray 6 with multi")
	_check(_differing_keys(drain, _shipped_drain()) == ["multi"]
		and bool(drain.get("multi", false))
		and not bool(_shipped_drain().get("multi", true)),
		"AC1: the ONLY authored Drain Thread delta from the shipped record is multi false -> true")
	_check(_differing_keys(bite, _authored_bite()).is_empty()
		and not bool(bite.get("multi", true)),
		"AC1: Leech Bite is untouched and stays a single-target Mark hunter")
	# The record's identity, legacy intent and Stitched profile are all still authored.
	var profile: Dictionary = record.get("stitched", {})
	_check(str(record.get("name", "")) == "Spool Leech"
		and int(record.get("max_hp", 0)) == 42
		and record.get("drain") == true
		and record.get("chew_block_on_attack") == true
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/spool_leech.png"
		and record.get("intent", {}).get("target") == "lowest_living_hp"
		and (record.get("intent", {}).get("actions", []) as Array).size() == 5,
		"AC1: name, 42 HP, drain/chew flags, art and the legacy five-action intent stay exact")
	_check(int(profile.get("max_hp", 0)) == 42 and int(profile.get("speed", -1)) == 4
		and int(profile.get("dodge", -1)) == 5 and int(profile.get("acc", -1)) == 0
		and int(profile.get("prot", -1)) == 6 and profile.get("is_boss") == false
		and int(profile.get("turns_per_round", 0)) == 1
		and str(profile.get("trophy", "")) == "spool_leech_maw"
		and (profile.get("abilities", []) as Array).size() == 2,
		"AC1: the Stitched profile keeps 42/4/5/0/6, one turn, no boss, the Leech Maw trophy and two actions")
	# Independent validation and the real loader agree with the authored numbers.
	var validated := StitchedParts.validate_ability(drain, "test drain thread")
	var normalized: Dictionary = validated.get("ability", {})
	_check(bool(validated.get("ok", false)) and bool(normalized.get("multi", false))
		and normalized.get("target") == [1, 2]
		and int(normalized.get("target_mask", -1)) == StitchedParts.rank_mask([1, 2])
		and normalized.get("launch") == [1, 3]
		and int(normalized.get("acc", -1)) == 90
		and normalized.get("dmg") == [0, 0]
		and int(normalized.get("mark_damage", -1)) == 0
		and normalized.get("effects") == {"weak": 2, "mark": MARK, "fray": FRAY},
		"AC1: StitchedParts normalizes the two-rank seam, its masks, ACC, damage and effects")
	var foe := StitchedEnemyCatalog.foe_for(_catalog, LEECH)
	var abilities: Array = foe.get("abilities", [])
	_check(not foe.is_empty() and abilities.size() == 2
		and str(abilities[0].get("id", "")) == BITE
		and str(abilities[1].get("id", "")) == DRAIN
		and bool(abilities[1].get("multi", false))
		and abilities[1] == normalized,
		"AC1: the real loader exposes both authored actions in order with the two-rank Drain Thread")
	_check(StitchedEnemyCatalog.trophy_for(_catalog, LEECH) == "spool_leech_maw"
		and _catalog.enemies.get(LEECH, {}).get("tier") == "elite",
		"AC1: the unique Leech Maw trophy and elite tier are unchanged")
	# Every other elite keeps its own kit and trophy; no total-count or ordered-list oracle.
	var neighbours := 0
	for neighbor in raw:
		if not neighbor is Dictionary or str(neighbor.get("id", "")) == LEECH:
			continue
		neighbours += 1
		var neighbor_id := str(neighbor.get("id", ""))
		var kit_valid := true
		for ability in neighbor.get("stitched", {}).get("abilities", []):
			kit_valid = kit_valid and bool(StitchedParts.validate_ability(ability).get("ok", false))
		_check(_catalog.foes.has(neighbor_id)
			and StitchedEnemyCatalog.trophy_for(_catalog, neighbor_id)
				== str(neighbor.get("stitched", {}).get("trophy", ""))
			and kit_valid,
			"AC1: every other elite still loads its own authored kit and trophy: " + neighbor_id)
	_check(neighbours >= 7, "AC1: non-vacuous coverage of the seven other elites beside the Leech")
	for required in ["needle_marshal", "spool_hexer", "scissor_bailiff", "zipper_hauler",
			"pincushion_matriarch", "spool_snarekeeper", "spool_stalker"]:
		_check(_catalog.foes.has(required),
			"AC1: named old elite ID still resolves: " + required)
	var parts_document: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_PARTS))
	_check(parts_document is Dictionary and (parts_document.get("parts", []) as Array).any(
		func(part: Variant) -> bool:
			return part is Dictionary and str(part.get("id", "")) == "spool_leech_maw"),
		"AC1: the Leech Maw loot part is still authored in the foreign enemy catalog")


# ---------------------------------------------------------------- seeded battle fixture

func _make_battle(seed_value: int) -> StitchedRules:
	var heroes: Array = _preview["heroes"].duplicate(true)
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


## Legal public Passes (either side) until the Leech's own turn of the wanted round.
func _to_leech(battle: StitchedRules, wanted_round: int) -> bool:
	for _step in range(PASS_LIMIT):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > wanted_round:
			return false
		if battle.current_actor_id() == LEECH and battle.round_number() == wanted_round:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


func _results_by_rank(receipt: Dictionary) -> Dictionary:
	var by_rank := {}
	for result in receipt.get("results", []):
		by_rank[int(result.get("target_rank", 0))] = result
	return by_rank


## One genuine round-two Drain Thread: Passes to the Leech's turn, a read-only forecast, then
## the public commit. Snapshots bracket only the action itself.
func _drain_dossier(seed_value: int) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null or not _to_leech(battle, 2):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	if str(intent.get("ability_id", "")) != DRAIN:
		return {}
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var repeated := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	if _norm(repeated) != _norm(intent) or battle.state_snapshot() != state \
			or battle.rng_state() != rng:
		return {}
	var units_before := _snapshot_units(battle)
	var receipt := battle.use_foe_ability(DRAIN, int(intent.get("target_rank", 0)))
	if not bool(receipt.get("ok", false)):
		return {}
	return {
		"seed": seed_value,
		"battle": battle,
		"intent": intent,
		"receipt": receipt,
		"results": _results_by_rank(receipt),
		"units_before": units_before,
		"units_after": _snapshot_units(battle),
		"actor_after": battle.current_actor_id(),
	}


# ---------------------------------------------------------------- AC2 both front ranks

func _test_two_rank_seam() -> void:
	var witnesses := {"both_hit": {}, "split": {}, "both_miss": {}}
	for seed_value in range(1, SEED_LIMIT + 1):
		if not witnesses["both_hit"].is_empty() and not witnesses["split"].is_empty() \
				and not witnesses["both_miss"].is_empty():
			break
		var dossier := _drain_dossier(seed_value)
		if dossier.is_empty():
			continue
		var results: Dictionary = dossier["results"]
		if not results.has(1) or not results.has(2):
			continue
		var hits := [bool(results[1].get("hit", false)), bool(results[2].get("hit", false))]
		if hits == [true, true] and witnesses["both_hit"].is_empty():
			witnesses["both_hit"] = dossier
		elif hits == [true, false] or hits == [false, true]:
			if witnesses["split"].is_empty():
				witnesses["split"] = dossier
		elif hits == [false, false] and witnesses["both_miss"].is_empty():
			witnesses["both_miss"] = dossier
	for key in witnesses:
		_check(not witnesses[key].is_empty(),
			"non-vacuous: bounded real seed witness for the two-rank seam: " + key)
	var both: Dictionary = witnesses["both_hit"]
	if not both.is_empty():
		_check_landed(both)
	var split: Dictionary = witnesses["split"]
	if not split.is_empty():
		_check_split(split)
	var missed: Dictionary = witnesses["both_miss"]
	if not missed.is_empty():
		_check_missed(missed)


func _check_landed(dossier: Dictionary) -> void:
	var battle: StitchedRules = dossier["battle"]
	var intent: Dictionary = dossier["intent"]
	var results: Dictionary = dossier["results"]
	var before: Dictionary = dossier["units_before"]
	var after: Dictionary = dossier["units_after"]
	_check(str(intent.get("ability_id", "")) == DRAIN
		and bool(intent.get("multi", false))
		and intent.get("affected_ranks") == [1, 2]
		and str(intent.get("target_side", "")) == "hero"
		and int(intent.get("target_rank", 0)) in [1, 2]
		and int(intent.get("base_acc", -1)) == 90
		and intent.get("base_damage") == [0, 0]
		and intent.get("base_effects") == {"weak": 2, "mark": MARK, "fray": FRAY},
		"AC2: the round-two projection announces one multi-target drain over exactly hero ranks 1-2")
	_check(results.size() == 2
		and str(results[1].get("target", "")) == _hero_id_at(battle, 1)
		and str(results[2].get("target", "")) == _hero_id_at(battle, 2),
		"AC2: the committed action returns its own result for each living front-rank doll")
	_check(int(results[1].get("hit_chance", -1)) != int(results[2].get("hit_chance", -2))
		or int(results[1].get("roll", -1)) != int(results[2].get("roll", -1)),
		"AC2: each front rank rolls its own seeded hit instead of sharing one all-party result")
	for rank in [1, 2]:
		var result: Dictionary = results[rank]
		var target_id := str(result["target"])
		var target_before: Dictionary = before.get(target_id, {})
		var target_after: Dictionary = after.get(target_id, {})
		_check(bool(result.get("hit", false)) and int(result.get("damage", -1)) == 0
			and int(result.get("target_hp", -1)) == int(target_before.get("hp", -2))
			and result.get("statuses") == [
				{"status": "weak", "duration": 2}, {"status": "mark", "duration": MARK}]
			and str((result.get("fray_event") as Dictionary).get("actor", "")) == target_id
			and int((result.get("fray_event") as Dictionary).get("change", 0)) == FRAY,
			"AC2: the confirmed rank-%d hit deals zero damage and sews Weak 2 + Mark 3 + 6 Fray" % rank)
		_check(int(target_after.get("hp", -1)) == int(target_before.get("hp", -2))
			and int(target_after.get("fray", -1)) == int(target_before.get("fray", -2)) + FRAY,
			"AC2: the rank-%d doll really gains its own 6 Fray and loses no HP" % rank)
		# The live doll carries the authored clock, minus only its own immediate start-turn tick.
		var tick := 1 if str(dossier["actor_after"]) == target_id else 0
		_check(int(target_after.get("statuses", {}).get("mark", 0)) == maxi(0, MARK - tick)
			and int(target_after.get("statuses", {}).get("weak", 0)) == maxi(0, 2 - tick),
			"AC2: the rank-%d doll really carries Weak 2 and Mark 3 in its own status line" % rank)
	# Ranks 3 and 4 sit outside the authored seam: no status, no Fray, no HP from the drain.
	for hero in battle.get_heroes():
		var hero_id := str(hero["id"])
		if int(hero["rank"]) <= 2:
			continue
		_check(int(hero.get("statuses", {}).get("mark", 0)) == 0
			and int(hero.get("statuses", {}).get("weak", 0)) == 0
			and int(hero.get("fray", -1))
				== int((before.get(hero_id, {}) as Dictionary).get("fray", -2)),
			"AC2: illegal rank %d gains no Weak, Mark or Fray: %s" % [int(hero["rank"]), hero_id])
	var touched: Array = []
	for unit_id in before:
		if unit_id in [str(results[1]["target"]), str(results[2]["target"]), LEECH]:
			continue
		if _norm(before[unit_id]) != _norm(after.get(unit_id, {})):
			touched.append(unit_id)
	_check(touched.is_empty(), "AC2: the two-rank drain changes no other unit at all")


func _check_split(dossier: Dictionary) -> void:
	var results: Dictionary = dossier["results"]
	var before: Dictionary = dossier["units_before"]
	var after: Dictionary = dossier["units_after"]
	var hit_rank := 1 if bool(results[1].get("hit", false)) else 2
	var miss_rank := 2 if hit_rank == 1 else 1
	var hit: Dictionary = results[hit_rank]
	var miss: Dictionary = results[miss_rank]
	var miss_id := str(miss["target"])
	var miss_before: Dictionary = before.get(miss_id, {})
	var miss_after: Dictionary = after.get(miss_id, {})
	_check(bool(hit.get("hit", false)) and not bool(miss.get("hit", true)),
		"AC2: one seeded seam roll lands and the other misses in the same real action")
	_check(int(hit.get("damage", -1)) == 0 and hit.get("statuses") == [
			{"status": "weak", "duration": 2}, {"status": "mark", "duration": MARK}]
		and (miss.get("statuses", [-1]) as Array).is_empty() and not miss.has("fray_event"),
		"AC2: the hit rank sews its statuses while the missed rank carries none of them")
	_check(int(miss_after.get("statuses", {}).get("mark", 0)) == 0
		and int(miss_after.get("statuses", {}).get("weak", 0)) == 0
		and int(miss_after.get("fray", -1)) == int(miss_before.get("fray", -2)),
		"AC2: a missed front doll gains no hidden Weak, Mark or Fray from its partner's hit")
	_check(int(hit.get("hit_chance", -1)) > 0 and int(miss.get("hit_chance", -1)) > 0
		and int(miss.get("roll", 0)) > int(miss.get("hit_chance", 0)),
		"AC2: the missed rank's own seeded roll really exceeded its own hit chance")


func _check_missed(dossier: Dictionary) -> void:
	var results: Dictionary = dossier["results"]
	var before: Dictionary = dossier["units_before"]
	var after: Dictionary = dossier["units_after"]
	for rank in [1, 2]:
		var miss_id := str(results[rank]["target"])
		_check(not bool(results[rank].get("hit", true))
			and (results[rank].get("statuses", [-1]) as Array).is_empty()
			and not results[rank].has("fray_event")
			and int(results[rank].get("damage", -1)) == 0,
			"AC2: a natural rank-%d miss sews nothing at all" % rank)
		_check(int(after.get(miss_id, {}).get("fray", -1))
			== int(before.get(miss_id, {}).get("fray", -2))
			and int(after.get(miss_id, {}).get("statuses", {}).get("mark", 0)) == 0,
			"AC2: the missed rank-%d doll carries no Mark and no Fray afterwards" % rank)


# ---------------------------------------------------------------- AC3 one legal rank

## TEST-ONLY STATE FIXTURE: makes an already-built front doll LOST so the seam has one legal
## rank left. Nothing else is planted; the action, receipt and statuses are the real ones.
func _test_single_rank_seam() -> void:
	var only_front := _make_battle(7)
	if only_front == null or not _to_leech(only_front, 2):
		_check(false, "AC3: the single-rank seam battle still reaches a real Leech turn")
		return
	var rank1 := _hero_id_at(only_front, 1)
	var rank2 := _hero_id_at(only_front, 2)
	_check(not rank1.is_empty() and not rank2.is_empty(),
		"AC3: both front-rank dolls are present before the LOST fixture")
	only_front._units[rank2]["lost"] = true
	var lost_before := only_front.get_unit(rank2)
	var intent := StitchedFoeIntent.choose(only_front, only_front.get_unit(LEECH))
	_check(str(intent.get("ability_id", "")) == DRAIN
		and intent.get("affected_ranks") == [1]
		and bool(intent.get("multi", false)),
		"AC3: with only rank 1 legally present the drain projects exactly that one rank")
	var receipt := only_front.use_foe_ability(DRAIN, int(intent.get("target_rank", 0)))
	var results: Array = receipt.get("results", [])
	_check(bool(receipt.get("ok", false)) and results.size() == 1
		and int(results[0].get("target_rank", 0)) == 1
		and str(results[0].get("target", "")) == rank1,
		"AC3: the public action affects only the one legal rank and invents no second victim")
	_check(_norm(only_front.get_unit(rank2)) == _norm(lost_before),
		"AC3: the LOST front doll never receives the drain's statuses or Fray")

	var only_back := _make_battle(7)
	if only_back == null or not _to_leech(only_back, 2):
		_check(false, "AC3: the mirrored single-rank seam battle reaches a real Leech turn")
		return
	var back_rank1 := _hero_id_at(only_back, 1)
	var back_rank2 := _hero_id_at(only_back, 2)
	# TEST-ONLY STATE FIXTURE: the nearer front doll is LOST, rank 2 is the only seam left.
	only_back._units[back_rank1]["lost"] = true
	var lost_one := only_back.get_unit(back_rank1)
	var mirrored := StitchedFoeIntent.choose(only_back, only_back.get_unit(LEECH))
	_check(str(mirrored.get("ability_id", "")) == DRAIN
		and mirrored.get("affected_ranks") == [2]
		and bool(mirrored.get("multi", false)),
		"AC3: with only rank 2 legally present the drain projects exactly that one rank")
	var mirrored_receipt := only_back.use_foe_ability(DRAIN, int(mirrored.get("target_rank", 0)))
	var mirrored_results: Array = mirrored_receipt.get("results", [])
	_check(bool(mirrored_receipt.get("ok", false)) and mirrored_results.size() == 1
		and int(mirrored_results[0].get("target_rank", 0)) == 2
		and str(mirrored_results[0].get("target", "")) == back_rank2,
		"AC3: the mirrored action affects only the surviving legal rank")
	_check(_norm(only_back.get_unit(back_rank1)) == _norm(lost_one),
		"AC3: the LOST nearer doll never receives the drain's statuses or Fray")

	var empty_seam := _make_battle(7)
	if empty_seam == null or not _to_leech(empty_seam, 2):
		_check(false, "AC3: the empty-seam battle reaches a real Leech turn")
		return
	# TEST-ONLY STATE FIXTURE: no legal front rank remains at all.
	empty_seam._units[_hero_id_at(empty_seam, 1)]["lost"] = true
	empty_seam._units[_hero_id_at(empty_seam, 2)]["lost"] = true
	var empty_intent := StitchedFoeIntent.choose(empty_seam, empty_seam.get_unit(LEECH))
	var state := empty_seam.state_snapshot()
	var rng := empty_seam.rng_state()
	var refused := empty_seam.use_foe_ability(DRAIN, 1)
	_check(bool(empty_intent.get("pass", false)) and not bool(empty_intent.get("multi", true)),
		"AC3: with no legal front rank the projection announces no invented Drain Thread")
	_check(not bool(refused.get("ok", true))
		and str(refused.get("error", "")).contains("no legal target")
		and empty_seam.state_snapshot() == state and empty_seam.rng_state() == rng,
		"AC3: the empty seam refuses the action without spending the RNG or mutating state")


# ---------------------------------------------------------------- AC3 fail-closed paths

func _test_fail_closed() -> void:
	var battle := _make_battle(11)
	if battle == null or not _to_leech(battle, 2):
		_check(false, "AC3: the fail-closed battle reaches a real round-two Leech turn")
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	for bad_rank in [0, 3, 4, 5, -1]:
		var off_rank := battle.use_foe_ability(DRAIN, bad_rank)
		_check(not bool(off_rank.get("ok", true))
			and str(off_rank.get("error", "")).contains("no legal target")
			and battle.state_snapshot() == state and battle.rng_state() == rng,
			"AC3: Drain Thread in rank %d is refused before any roll" % bad_rank)
	var unknown := battle.use_foe_ability("not_an_authored_ability", 1)
	_check(not bool(unknown.get("ok", true)) and battle.state_snapshot() == state
		and battle.rng_state() == rng,
		"AC3: an unauthored Leech action is refused with identical state and RNG")
	# Wrong turn: a fresh real battle held on a doll's turn refuses the foe action outright.
	var other := _make_battle(11)
	var hero_turn := other != null
	for _step in range(PASS_LIMIT):
		if other == null or other.is_over():
			hero_turn = false
			break
		if other.current_side() == "hero":
			break
		if not bool(other.pass_turn().get("ok", false)):
			hero_turn = false
			break
	if not hero_turn:
		_check(false, "AC3: the wrong-turn battle really reaches a public doll turn")
	else:
		var hero_state := other.state_snapshot()
		var hero_rng := other.rng_state()
		var wrong_turn := other.use_foe_ability(DRAIN, 1)
		_check(not bool(wrong_turn.get("ok", true))
			and str(wrong_turn.get("error", "")).contains("not a foe turn")
			and other.state_snapshot() == hero_state and other.rng_state() == hero_rng,
			"AC3: Drain Thread out of turn fails closed without spending state or RNG")
	# Detached and dead projections never invent an intent.
	var authoritative := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	var stale := battle.get_unit(LEECH)
	stale["abilities"] = []
	_check(_norm(StitchedFoeIntent.choose(battle, stale)) == _norm(authoritative),
		"AC3: a detached stale Leech dictionary cannot forge an empty kit")
	_check(StitchedFoeIntent.choose(battle, {}).is_empty()
		and StitchedFoeIntent.choose(battle, {"id": "ghost_foe"}).is_empty()
		and StitchedFoeIntent.choose(null, battle.get_unit(LEECH)).is_empty(),
		"AC3: empty, impostor and null-actor projections invent no intent")
	battle._units[LEECH]["dead"] = true
	battle._units[LEECH]["hp"] = 0
	_check(StitchedFoeIntent.choose(battle, battle.get_unit(LEECH)).is_empty(),
		"AC3: a dead Leech has no selectable intent")
	battle._units[LEECH]["dead"] = false
	battle._units[LEECH]["hp"] = int(battle._units[LEECH]["max_hp"])
	_check(not authoritative.is_empty(),
		"AC3: the restored live Leech projects a real intent again")


# ---------------------------------------------------------------- AC3 Mark follow-up

## Real public path: round-one Bite, round-two Drain Thread, then the Warden's own Iron Helm
## Bash (an authentic equipped part action) wounds the Leech so its authored HP drain shows,
## and public Passes reach the round-three Bite that hunts the Marked doll.
func _follow_cycle(seed_value: int) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null:
		return {}
	if not _to_leech(battle, 1):
		return {}
	var first_intent := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	if str(first_intent.get("ability_id", "")) != BITE:
		return {}
	var first_bite := battle.use_foe_ability(BITE, int(first_intent.get("target_rank", 0)))
	if not bool(first_bite.get("ok", false)) or (first_bite.get("results", []) as Array).size() != 1:
		return {}
	if not _to_leech(battle, 2):
		return {}
	var drain_intent := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	if str(drain_intent.get("ability_id", "")) != DRAIN:
		return {}
	var drain := battle.use_foe_ability(DRAIN, int(drain_intent.get("target_rank", 0)))
	var drain_results: Array = drain.get("results", [])
	if not bool(drain.get("ok", false)) or drain_results.size() != 2 \
			or not bool(drain_results[0].get("hit", false)) \
			or not bool(drain_results[1].get("hit", false)):
		return {}
	var rank1 := _hero_id_at(battle, 1)
	if str(drain_results[0].get("target", "")) != rank1:
		return {}
	if not _wound_then_reach_leech(battle, 3):
		return {}
	var leech_before: Dictionary = battle.get_unit(LEECH)
	if int(leech_before.get("hp", 0)) >= int(leech_before.get("max_hp", 0)):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(LEECH))
	if str(intent.get("ability_id", "")) != BITE:
		return {}
	var target_rank := int(intent.get("target_rank", 0))
	var target_before: Dictionary = battle.get_unit(_hero_id_at(battle, target_rank))
	var attacker_statuses: Dictionary = battle.get_unit(LEECH).get("statuses", {}).duplicate(true)
	var bite := battle.use_foe_ability(BITE, target_rank)
	if not bool(bite.get("ok", false)) or (bite.get("results", []) as Array).size() != 1:
		return {}
	return {
		"seed": seed_value,
		"battle": battle,
		"drain": drain,
		"drain_result": drain_results[0],
		"intent": intent,
		"target_rank": target_rank,
		"target_id": str(target_before.get("id", "")),
		"target_before": target_before,
		"attacker": battle.get_unit(LEECH).duplicate(true),
		"attacker_statuses": attacker_statuses,
		"leech_before": leech_before,
		"leech_after": battle.get_unit(LEECH),
		"bite": bite,
		"hit": (bite.get("results", []) as Array)[0],
		"actor_after": battle.current_actor_id(),
	}


## Passes until the Leech's turn of the wanted round, letting the Warden land one real equipped
## part attack on the Leech first so the authored drain-on-damage can be witnessed.
func _wound_then_reach_leech(battle: StitchedRules, wanted_round: int) -> bool:
	for _step in range(PASS_LIMIT):
		if battle.is_over() or battle.round_number() > wanted_round:
			return false
		if battle.current_actor_id() == LEECH and battle.round_number() == wanted_round:
			return true
		var leech := battle.get_unit(LEECH)
		if battle.current_actor_id() == "warden" \
				and int(leech.get("hp", 0)) >= int(leech.get("max_hp", 0)):
			# A real equipped part action, validated and committed by the rules core.
			var wound := battle.use_part("warden_head_iron_helm", 1)
			if not bool(wound.get("ok", false)):
				return false
			continue
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


func _matching_bases(attacker: Dictionary, ability: Dictionary,
		attacker_statuses: Dictionary, defender: Dictionary, damage: int, crit: bool) -> Array:
	var bases: Array = []
	var bonus := int(attacker.get("dmg_bonus", 0))
	if crit:
		bases.append(StitchedRules.crit_damage(int(ability["dmg"][1])) + bonus)
	else:
		for base in range(int(ability["dmg"][0]), int(ability["dmg"][1]) + 1):
			bases.append(base + bonus)
	var matched: Array = []
	for base in bases:
		if int(StitchedRules.damage_after_modifiers(int(base), attacker_statuses,
				defender.get("statuses", {}), true, MARK_BONUS, int(defender.get("prot", 0)))) == damage:
			matched.append(int(base))
	return matched


func _test_mark_follow_up() -> void:
	var witness: Dictionary = {}
	for seed_value in range(1, SEED_LIMIT + 1):
		var dossier := _follow_cycle(seed_value)
		if dossier.is_empty():
			continue
		if bool(dossier["hit"].get("hit", false)) and int(dossier["hit"].get("drain", 0)) > 0:
			witness = dossier
			break
	_check(not witness.is_empty(),
		"AC3: bounded real seeds reach a Marked doll, the next Leech Bite and its HP drain")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var intent: Dictionary = witness["intent"]
	var hit: Dictionary = witness["hit"]
	var target_before: Dictionary = witness["target_before"]
	var leech_before: Dictionary = witness["leech_before"]
	var leech_after: Dictionary = witness["leech_after"]
	var target_rank := int(witness["target_rank"])
	_check(int(target_before.get("statuses", {}).get("mark", 0)) > 0
		and target_rank == 1 and str(witness["target_id"])
			== str(witness["drain_result"].get("target", "")),
		"AC3: the next Leech Bite hunts the nearest legal doll the Drain Thread Marked")
	_check(int(intent.get("base_mark_damage", -1)) == MARK_BONUS
		and intent.get("base_damage") == [4, 6]
		and int(intent.get("base_acc", -1)) == 86
		and intent.get("base_effects") == {"bleed": 1}
		and intent.get("affected_ranks") == [target_rank]
		and not bool(intent.get("multi", true)),
		"AC3: the projected Bite keeps its authored single target, ACC 86, 4-6 damage, Bleed 1 and +4 Mark")
	var matched := _matching_bases(witness["attacker"], _actor_ability(witness["attacker"], BITE),
		witness["attacker_statuses"], target_before, int(hit.get("damage", -1)),
		bool(hit.get("crit", false)))
	_check(bool(hit.get("hit", false)) and not matched.is_empty()
		and int(hit.get("damage", -1))
			== int(target_before.get("hp", 0)) - int(hit.get("target_hp", 0)),
		"AC3: the marked Bite's real HP loss equals the marked damage formula")
	for base in matched:
		var marked_final := int(StitchedRules.damage_after_modifiers(base,
			witness["attacker_statuses"], target_before.get("statuses", {}), true, MARK_BONUS,
			int(target_before.get("prot", 0))))
		var unmarked_final := int(StitchedRules.damage_after_modifiers(base,
			witness["attacker_statuses"], target_before.get("statuses", {}), false, MARK_BONUS,
			int(target_before.get("prot", 0))))
		_check(marked_final == int(hit.get("damage", -1)) and unmarked_final < marked_final,
			"AC3: the +4 is the authored Mark bonus on the quoted direct base, not a changed formula")
	# Bleed 1 is the authored follow-up, minus only the victim's own immediate start-turn tick.
	var tick := 1 if str(witness["actor_after"]) == str(witness["target_id"]) else 0
	var statuses: Array = hit.get("statuses", [])
	_check(statuses.has({"status": "bleed", "duration": 1}),
		"AC3: a landed Bite still sews its authored Bleed 1")
	_check(int(battle.get_unit(str(witness["target_id"])).get("statuses", {}).get("bleed", 0))
		== maxi(0, 1 - tick),
		"AC3: the bitten doll carries Bleed 1 (minus only its own start-turn tick)")
	# Authored drain-on-damage: the wounded Leech restores exactly the HP it removed, capped.
	var direct_loss := int(target_before.get("hp", 0)) - int(hit.get("target_hp", 0))
	var missing := maxi(0, int(leech_before.get("max_hp", 0)) - int(leech_before.get("hp", 0)))
	_check(int(leech_before.get("hp", 0)) < int(leech_before.get("max_hp", 0))
		and int(hit.get("drain", 0)) == mini(missing, direct_loss)
		and int(leech_after.get("hp", 0))
			== int(leech_before.get("hp", 0)) + mini(missing, direct_loss),
		"AC3: the wounded Leech really drains the HP its Bite removed, capped by its missing HP")
	_check(int(hit.get("damage", -1)) > 0 and direct_loss > 0,
		"AC3: non-vacuous: the witnessed Bite really removed HP from the Marked doll")


func _actor_ability(actor: Dictionary, ability_id: String) -> Dictionary:
	for ability in actor.get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}
