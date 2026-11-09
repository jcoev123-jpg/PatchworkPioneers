extends SceneTree
## S5 Needle Marshal: the canonical elite's Marshal Prick pins one doll with Bleed 1 + MARK 3,
## and the following Marshal Volley hunts that pin for its authored +3.
##
## Deterministic and bounded. Every combat witness comes from the real StitchedEnemyCatalog,
## the shipped four-doll preview and the public StitchedRules turn/foe-ability API on seeded
## battles. Only the explicitly labelled selector/rejection fixtures plant a combat-only Mark
## status or a rank to isolate an unmarked reach; no resolver receipt or RNG draw is faked.
## The expired-Mark witness instead spends real legal turns until the authored Mark runs out.

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const MARSHAL := "needle_marshal"
const RAGLING := "ragling"
const PRICK := "marshal_prick"
const VOLLEY := "marshal_volley"
const WARD := "iron_discipline"
const MARK := 3
const MARK_BONUS := 3
const BLEED := 1
const SEED_LIMIT := 200
const PROT_OVERRIDE := 40

var checks := 0
var failures: Array[String] = []
var _catalog: Dictionary = {}
var _preview: Dictionary = {}


func _initialize() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITES))
	_check(raw is Array, "AC1: the real elite catalog parses as an array")
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"AC1: canonical Stitched enemy catalog validates: " + str(_catalog.get("error", "")))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(parsed is Dictionary, "the shipped four-doll preview parses")
	if not raw is Array or not bool(_catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	_preview = parsed
	_test_source_contract(raw)
	_test_catalog_contract(raw)
	var witnesses := _search_witnesses()
	var expired := _search_expired()
	_test_prick_receipt(witnesses)
	_test_marked_volley(witnesses)
	_test_missed_prick(witnesses)
	_test_volley_miss(witnesses)
	_test_bleed_tick(witnesses)
	_test_expired_volley(expired)
	_test_selector_fixtures()
	_test_rejections()
	_test_replay(witnesses)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_marshal_pin_volley_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


# ---------------------------------------------------------------- AC1 authored records

func _prick_source() -> Dictionary:
	return {
		"id": PRICK, "name": "Marshal Prick", "kind": "melee",
		"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
		"acc": 87, "dmg": [4, 6], "crit": 0, "effects": {"bleed": BLEED, "mark": MARK},
		"self_move": 0, "move": "attack2",
	}


func _volley_source() -> Dictionary:
	return {
		"id": VOLLEY, "name": "Marshal Volley", "kind": "ranged",
		"launch": [1, 4], "target": [1, 3], "target_side": "enemy", "multi": false,
		"acc": 85, "dmg": [3, 5], "crit": 0, "mark_damage": MARK_BONUS, "effects": {},
		"self_move": 0, "move": "attack3",
	}


func _iron_source() -> Dictionary:
	return {
		"id": WARD, "name": "Iron Discipline", "kind": "buff",
		"launch": [1, 3], "target": [1, 2, 3, 4], "target_side": "ally", "multi": false,
		"acc": 100, "dmg": [0, 0], "crit": 0,
		"effects": {"thorns": 2, "dodge": 8, "duration": 2},
		"self_move": 0, "move": "guard",
	}


## The authored record before this change: Prick had Bleed 1 only; Volley had no Mark bonus.
func _original_prick() -> Dictionary:
	var prick := _prick_source()
	prick["effects"] = {"bleed": BLEED}
	return prick


func _original_volley() -> Dictionary:
	var volley := _volley_source()
	volley.erase("mark_damage")
	return volley


func _marshal_record() -> Dictionary:
	return {
		"id": MARSHAL,
		"name": "Needle Marshal",
		"max_hp": 28,
		"thorns": 3,
		"bleed_on_attack": true,
		"enrage": true,
		"art_path": "res://assets/paper/enemies/needle_marshal.png",
		"intent": {
			"target": "front",
			"actions": [
				{"type": "attack", "amount": 5, "weight": 2},
				{"type": "attack", "amount": 4, "move": "attack2", "weight": 1},
				{"type": "attack", "amount": 6, "move": "attack3", "weight": 1},
				{"type": "buff", "amount": 3, "weight": 1},
				{"type": "shove", "amount": 0, "direction": 1, "weight": 1},
			],
		},
		"stitched": {
			"max_hp": 28,
			"speed": 5,
			"dodge": 6,
			"acc": 0,
			"prot": 6,
			"is_boss": false,
			"turns_per_round": 1,
			"trophy": "needle_marshal_sash",
			"abilities": [_prick_source(), _volley_source(), _iron_source()],
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
	var matches := _records_with_id(raw, MARSHAL)
	_check(matches.size() == 1, "AC1: exactly one source record carries the Needle Marshal ID")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	_check(_norm(record) == _norm(_marshal_record()),
		"AC1: the whole Marshal record stays exact apart from Prick's Mark 3 and Volley's +3")
	var prick := _ability_of(record, PRICK)
	var volley := _ability_of(record, VOLLEY)
	var ward := _ability_of(record, WARD)
	_check(_norm(prick) == _norm(_prick_source()),
		"AC1: Marshal Prick authors exactly Bleed 1 plus Mark 3 beside its shipped numbers")
	_check(_norm(volley) == _norm(_volley_source()),
		"AC1: Marshal Volley authors exactly mark_damage 3 beside its shipped numbers")
	_check(_norm(ward) == _norm(_iron_source()),
		"AC1: Iron Discipline keeps its Thorns 2 / Dodge 8 / two-turn ward unchanged")
	_check(_norm(_without(prick, ["effects"])) == _norm(_without(_original_prick(), ["effects"]))
		and _norm(prick["effects"]) != _norm(_original_prick()["effects"]),
		"AC1: only Prick's effects changed: Bleed 1 gained Mark 3 and nothing else moved")
	_check(_norm(_without(volley, ["mark_damage"])) == _norm(_original_volley())
		and int(volley.get("mark_damage", 0)) == MARK_BONUS,
		"AC1: only Volley's mark_damage 3 was added; every other field is its original")
	# Independent validator agreement, not an echo of the catalog loader.
	var prick_valid := StitchedParts.validate_ability(prick, "test marshal prick")
	var volley_valid := StitchedParts.validate_ability(volley, "test marshal volley")
	_check(bool(prick_valid.get("ok", false))
		and int(prick_valid.ability.get("acc", 0)) == 87
		and prick_valid.ability.get("dmg") == [4, 6]
		and prick_valid.ability.get("effects") == {"bleed": BLEED, "mark": MARK}
		and int(prick_valid.ability.get("mark_damage", -1)) == 0,
		"AC1: the validator normalizes Prick's Bleed 1 + Mark 3 and no Mark bonus")
	_check(bool(volley_valid.get("ok", false))
		and int(volley_valid.ability.get("mark_damage", 0)) == MARK_BONUS
		and volley_valid.ability.get("target") == [1, 3]
		and int(volley_valid.ability.get("target_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and volley_valid.ability.get("effects") == {}
		and int(volley_valid.ability.get("acc", 0)) == 85
		and volley_valid.ability.get("dmg") == [3, 5],
		"AC1: the validator normalizes Volley's sparse ranks 1/3 and its authored +3")
	# The other two Marshal actions never carry a Mark or Mark bonus of their own.
	_check(int(prick.get("mark_damage", 0)) == 0 and int(ward.get("mark_damage", 0)) == 0
		and not ward["effects"].has("mark"),
		"AC1: only the two named Marshal actions carry Mark data")


func _test_catalog_contract(raw: Array) -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, MARSHAL)
	_check(not foe.is_empty() and str(foe.get("name", "")) == "Needle Marshal"
		and int(foe.get("max_hp", 0)) == 28 and int(foe.get("speed", -1)) == 5
		and int(foe.get("dodge", -1)) == 6 and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 6 and foe.get("is_boss") == false
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: the canonical profile keeps 28 HP / SPEED 5 / DODGE 6 / ACC 0 / PROT 6")
	_check(StitchedEnemyCatalog.trophy_for(_catalog, MARSHAL) == "needle_marshal_sash"
		and _catalog.enemies.get(MARSHAL, {}).get("tier") == "elite",
		"AC1: the sash trophy and elite tier are unchanged")
	var prick_valid := StitchedParts.validate_ability(_prick_source())
	var volley_valid := StitchedParts.validate_ability(_volley_source())
	var ward_valid := StitchedParts.validate_ability(_iron_source())
	var abilities: Array = foe.get("abilities", [])
	_check(abilities.size() == 3
		and bool(prick_valid.get("ok", false)) and bool(volley_valid.get("ok", false))
		and bool(ward_valid.get("ok", false))
		and abilities[0] == prick_valid.ability and abilities[1] == volley_valid.ability
		and abilities[2] == ward_valid.ability,
		"AC1: the real loader normalizes exactly Prick, Volley and Iron Discipline in order")
	var ids: Array = []
	for ability in abilities:
		ids.append(str(ability.get("id", "")))
	_check(ids == [PRICK, VOLLEY, WARD],
		"AC1: the Marshal keeps its authored opening rotation")
	# Every neighbouring elite still resolves and validates, by ID only (no shared total).
	var neighbours := 0
	for candidate in raw:
		if not candidate is Dictionary:
			continue
		var neighbour_id := str(candidate.get("id", ""))
		if neighbour_id == MARSHAL:
			continue
		neighbours += 1
		var neighbour := StitchedEnemyCatalog.foe_for(_catalog, neighbour_id)
		var valid_kit := true
		for ability in candidate.get("stitched", {}).get("abilities", []):
			valid_kit = valid_kit and bool(StitchedParts.validate_ability(ability).get("ok", false))
		_check(not neighbour.is_empty() and str(neighbour.get("id", "")) == neighbour_id
			and StitchedEnemyCatalog.trophy_for(_catalog, neighbour_id)
				== str(candidate.get("stitched", {}).get("trophy", ""))
			and valid_kit,
			"AC1: neighbour elite keeps its own kit, ID and trophy: " + neighbour_id)
	_check(neighbours >= 2, "AC1: non-vacuous neighbour coverage beside the Marshal")
	for required in ["spool_hexer", "scissor_bailiff", "zipper_hauler",
			"pincushion_matriarch", "spool_leech"]:
		_check(_catalog.get("foes", {}).has(required)
			and not StitchedEnemyCatalog.foe_for(_catalog, required).is_empty(),
			"AC1: named elite ID still resolves: " + required)


# ---------------------------------------------------------------- seeded battle fixture

func _make_battle(seed_value: int, prot_override: int = -1) -> StitchedRules:
	var heroes: Array = _preview["heroes"].duplicate(true)
	if prot_override >= 0:
		heroes[0]["prot"] = prot_override
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var foes: Array = []
	for enemy_id in [MARSHAL, RAGLING]:
		var foe := StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id))
		if foe.is_empty():
			return null
		foes.append(foe)
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": heroes, "parts": parts, "foes": foes,
	})
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	if battle.get_heroes().size() != 4 or battle.get_foes().size() != 2:
		return null
	return battle


func _hero_id_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _actor_ability(actor: Dictionary, ability_id: String) -> Dictionary:
	for ability in actor.get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


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


## Legal public Passes until the Marshal's own turn of the wanted round. While waiting, the
## watched doll's statuses are captured at the start of each of its own turns (its countdown
## already ticked there). Returns false when the battle ends or the round is overshot.
func _advance_to_marshal(
	battle: StitchedRules, wanted_round: int, trace: Variant = null,
	watch_id: String = "", observations: Variant = null
) -> bool:
	for _step in range(260):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > wanted_round:
			return false
		var actor_id := battle.current_actor_id()
		if actor_id == MARSHAL and battle.round_number() == wanted_round:
			return true
		if not watch_id.is_empty() and actor_id == watch_id and observations != null:
			var unit := battle.get_unit(actor_id)
			(observations as Array).append({
				"round": battle.round_number(),
				"mark": int(unit.get("statuses", {}).get("mark", 0)),
				"bleed": int(unit.get("statuses", {}).get("bleed", 0)),
				"hp": int(unit.get("hp", 0)),
			})
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			return false
		_record_step(battle, trace, passed)
	return false


## A real Prick on the Marshal's round-one turn and a real Volley on its round-two turn.
## Prick misses still continue to the Volley so the miss witness also proves the later
## unmarked hit adds nothing. Returns {} when the canonical rotation cannot be followed.
func _run_cycle(seed_value: int, record_trace: bool = false) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null:
		return {}
	var trace: Variant = [] if record_trace else null
	if not _advance_to_marshal(battle, 1, trace):
		return {}
	var start_round := battle.round_number()
	var intent1 := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	if str(intent1.get("ability_id", "")) != PRICK:
		return {}
	var rank1 := int(intent1.get("target_rank", 0))
	var victim_id := _hero_id_at(battle, rank1)
	if rank1 != 1 or victim_id.is_empty():
		return {}
	var victim_before := battle.get_unit(victim_id)
	var prick := battle.use_foe_ability(PRICK, rank1)
	_record_step(battle, trace, prick)
	if not bool(prick.get("ok", false)) or (prick.get("results", []) as Array).size() != 1:
		return {}
	var prick_hit: Dictionary = (prick["results"] as Array)[0]
	var prick_target := str(prick_hit.get("target", ""))
	var prick_tick := 1 if battle.current_actor_id() == prick_target else 0
	var mark_after_prick := int(
		battle.get_unit(prick_target).get("statuses", {}).get("mark", 0))
	if not bool(prick_hit.get("hit", false)):
		var missed := _finish_cycle(battle, start_round + 1, trace, prick_target, [])
		if missed.is_empty():
			return {}
		missed["seed"] = seed_value
		missed["prick"] = prick
		missed["prick_hit"] = prick_hit
		missed["victim_id"] = prick_target
		missed["victim_before"] = victim_before
		missed["victim_rank"] = rank1
		missed["mark_after_prick"] = mark_after_prick
		missed["miss"] = "prick"
		return missed
	var observations: Array = []
	if not _advance_to_marshal(battle, start_round + 1, trace, prick_target, observations):
		return {}
	var intent2 := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	if str(intent2.get("ability_id", "")) != VOLLEY:
		return {}
	var rank2 := int(intent2.get("target_rank", 0))
	var attacker_before := battle.get_unit(MARSHAL)
	var victim_before_volley := battle.get_unit(prick_target)
	var mark_before_volley := int(
		victim_before_volley.get("statuses", {}).get("mark", 0))
	var volley := battle.use_foe_ability(VOLLEY, rank2)
	_record_step(battle, trace, volley)
	if not bool(volley.get("ok", false)) or (volley.get("results", []) as Array).size() != 1:
		return {}
	return {
		"ok": true,
		"seed": seed_value,
		"battle": battle,
		"trace": trace,
		"start_round": start_round,
		"intent1": intent1,
		"prick": prick,
		"prick_hit": prick_hit,
		"victim_id": prick_target,
		"victim_before": victim_before,
		"victim_rank": rank1,
		"prick_tick_after": prick_tick,
		"mark_after_prick": mark_after_prick,
		"observations": observations,
		"intent2": intent2,
		"rank2": rank2,
		"attacker_before": attacker_before,
		"victim_before_volley": victim_before_volley,
		"mark_before_volley": mark_before_volley,
		"volley": volley,
		"volley_hit": (volley["results"] as Array)[0],
	}


## The round-two Volley half of a cycle whose Prick missed.
func _finish_cycle(
	battle: StitchedRules, wanted_round: int, trace: Variant, victim_id: String,
	observations: Array
) -> Dictionary:
	if not _advance_to_marshal(battle, wanted_round, trace, victim_id, observations):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	if str(intent.get("ability_id", "")) != VOLLEY:
		return {}
	var rank := int(intent.get("target_rank", 0))
	var attacker_before := battle.get_unit(MARSHAL)
	var victim_before := battle.get_unit(victim_id)
	var mark_before := int(victim_before.get("statuses", {}).get("mark", 0))
	var volley := battle.use_foe_ability(VOLLEY, rank)
	_record_step(battle, trace, volley)
	if not bool(volley.get("ok", false)) or (volley.get("results", []) as Array).size() != 1:
		return {}
	return {
		"ok": true,
		"battle": battle,
		"trace": trace,
		"observations": observations,
		"intent2": intent,
		"rank2": rank,
		"attacker_before": attacker_before,
		"victim_before_volley": victim_before,
		"mark_before_volley": mark_before,
		"volley": volley,
		"volley_hit": (volley["results"] as Array)[0],
	}


func _search_witnesses() -> Dictionary:
	var found := {"hit": {}, "prick_miss": {}, "volley_miss": {}}
	for seed_value in range(1, SEED_LIMIT + 1):
		if not found["hit"].is_empty() and not found["prick_miss"].is_empty() \
				and not found["volley_miss"].is_empty():
			break
		var dossier := _run_cycle(seed_value)
		if dossier.is_empty():
			continue
		var vhit: Dictionary = dossier["volley_hit"]
		if str(dossier.get("miss", "")) == "prick":
			if found["prick_miss"].is_empty():
				found["prick_miss"] = dossier
			continue
		if found["hit"].is_empty() and bool(vhit.get("hit", false)) \
				and int(dossier["mark_before_volley"]) > 0 \
				and not bool(vhit.get("crit", false)):
			found["hit"] = dossier
		if found["volley_miss"].is_empty() and not bool(vhit.get("hit", true)):
			found["volley_miss"] = dossier
	for key in found:
		_check(not found[key].is_empty(),
			"bounded non-vacuous real seed witness is reachable: " + key)
	return found


## Five real rounds with only public Passes after the opening Prick: the authored Mark 3 has
## expired by the Marshal's round-five Volley, so the pinned victim is unmarked again.
func _late_volley_cycle(seed_value: int) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null:
		return {}
	if not _advance_to_marshal(battle, 1):
		return {}
	var intent1 := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	if str(intent1.get("ability_id", "")) != PRICK:
		return {}
	var rank1 := int(intent1.get("target_rank", 0))
	var victim_id := _hero_id_at(battle, rank1)
	var start_round := battle.round_number()
	var prick := battle.use_foe_ability(PRICK, rank1)
	if not bool(prick.get("ok", false)) or (prick.get("results", []) as Array).size() != 1:
		return {}
	var prick_hit: Dictionary = (prick["results"] as Array)[0]
	if not bool(prick_hit.get("hit", false)):
		return {}
	var observations: Array = []
	if not _advance_to_marshal(battle, start_round + 4, null, victim_id, observations):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	if str(intent.get("ability_id", "")) != VOLLEY:
		return {}
	var rank := int(intent.get("target_rank", 0))
	var attacker_before := battle.get_unit(MARSHAL)
	var victim_before := battle.get_unit(victim_id)
	var mark_before := int(victim_before.get("statuses", {}).get("mark", 0))
	var volley := battle.use_foe_ability(VOLLEY, rank)
	if not bool(volley.get("ok", false)) or (volley.get("results", []) as Array).size() != 1:
		return {}
	return {
		"ok": true,
		"seed": seed_value,
		"battle": battle,
		"prick_hit": prick_hit,
		"victim_id": victim_id,
		"observations": observations,
		"intent": intent,
		"rank": rank,
		"attacker_before": attacker_before,
		"victim_before_volley": victim_before,
		"mark_before_volley": mark_before,
		"volley": volley,
		"volley_hit": (volley["results"] as Array)[0],
	}


func _search_expired() -> Dictionary:
	for seed_value in range(1, SEED_LIMIT + 1):
		var dossier := _late_volley_cycle(seed_value)
		if dossier.is_empty():
			continue
		var hit: Dictionary = dossier["volley_hit"]
		if bool(hit.get("hit", false)) and not bool(hit.get("crit", false)) \
				and int(dossier["mark_before_volley"]) == 0:
			return dossier
	_check(false, "AC3: a real five-round seed reaches an expired-Mark Volley that hits")
	return {}


# ---------------------------------------------------------------- AC2 Prick receipt

func _status_entry(statuses: Array, status_name: String) -> Dictionary:
	for entry in statuses:
		if str(entry.get("status", "")) == status_name:
			return entry
	return {}


func _test_prick_receipt(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var hit: Dictionary = dossier["prick_hit"]
	var victim_id := str(dossier["victim_id"])
	var before: Dictionary = dossier["victim_before"]
	_check(bool(hit.get("hit", false)) and str(hit.get("target", "")) == victim_id
		and int(hit.get("target_rank", 0)) == int(dossier["victim_rank"])
		and str(hit.get("target_side", "")) == "hero",
		"AC2: a real Marshal Prick confirms its hit on the actual rank-one doll")
	_check(int(hit.get("damage", -1)) == int(before.get("hp", 0)) - int(hit.get("target_hp", -2)),
		"AC2: the confirmed Prick's HP loss equals its reported direct damage")
	var statuses: Array = hit.get("statuses", [])
	var bleed := _status_entry(statuses, "bleed")
	var mark := _status_entry(statuses, "mark")
	_check(statuses.size() == 2 and int(bleed.get("duration", -1)) == BLEED
		and int(mark.get("duration", -1)) == MARK,
		"AC2: the same actual victim receives Bleed 1 and MARK 3 together")
	_check(int(dossier["mark_after_prick"]) == MARK - int(dossier["prick_tick_after"])
		and int(dossier["mark_after_prick"]) > 0,
		"AC2: the reached doll really carries its Mark, minus only its own immediate start-turn tick")
	_check(int(before.get("statuses", {}).get("mark", 0)) == 0
		and int(before.get("statuses", {}).get("bleed", 0)) == 0,
		"AC2: the Prick's victim was unmarked and unbled before the pin")
	for hero in battle.get_heroes():
		if str(hero["id"]) == victim_id:
			continue
		var live := battle.get_unit(str(hero["id"]))
		_check(int(live.get("statuses", {}).get("mark", 0)) == 0
			and int(live.get("statuses", {}).get("bleed", 0)) == 0,
			"AC2: no other rank doll inherits the Prick's Mark or Bleed: " + str(hero["id"]))
	_check(bool(str(dossier["intent1"].get("ability_id", "")) == PRICK)
		and dossier["intent1"].get("base_effects") == {"bleed": BLEED, "mark": MARK}
		and int(dossier["intent1"].get("base_mark_damage", -1)) == 0,
		"AC2: the live intent announces the exact authored pin without a Mark bonus")


# ---------------------------------------------------------------- AC2 marked Volley

## The direct bases this hit could have rolled: the authored range plus the attacker's flat
## bonus, scaled by the real candle band exactly like the resolver (identity at candle 100),
## or the crit formula when the receipt says the hit critted.
func _bases(
	battle: StitchedRules, attacker: Dictionary, ability: Dictionary, crit: bool
) -> Array[int]:
	var raw: Array[int] = []
	if crit:
		raw.append(StitchedRules.crit_damage(int(ability["dmg"][1])))
	else:
		for value in range(int(ability["dmg"][0]), int(ability["dmg"][1]) + 1):
			raw.append(value)
	var bases: Array[int] = []
	for value in raw:
		var base := value + int(attacker.get("dmg_bonus", 0))
		if str(attacker.get("side", "")) == "foe":
			base = StitchedS1BEffects.enemy_damage(base, battle.candle())
		bases.append(base)
	return bases


func _matching_bases(
	battle: StitchedRules, attacker: Dictionary, ability: Dictionary,
	attacker_statuses: Dictionary, defender: Dictionary, marked: bool,
	damage: int, crit: bool
) -> Array[int]:
	var matched: Array[int] = []
	for base in _bases(battle, attacker, ability, crit):
		if int(StitchedRules.damage_after_modifiers(
				base, attacker_statuses, defender.get("statuses", {}), marked, MARK_BONUS,
				int(defender.get("prot", 0)))) == damage:
			matched.append(base)
	return matched


func _test_marked_volley(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var victim_id := str(dossier["victim_id"])
	var mark_before := int(dossier["mark_before_volley"])
	var before: Dictionary = dossier["victim_before_volley"]
	var attacker: Dictionary = dossier["attacker_before"]
	var hit: Dictionary = dossier["volley_hit"]
	var intent: Dictionary = dossier["intent2"]
	var ability := _actor_ability(attacker, VOLLEY)
	_check(mark_before > 0, "AC2: the authored Mark survives to the Marshal's Volley turn")
	_check(not ability.is_empty() and int(ability.get("mark_damage", 0)) == MARK_BONUS
		and str(intent.get("ability_id", "")) == VOLLEY
		and int(intent.get("target_rank", 0)) == int(dossier["victim_rank"])
		and intent.get("affected_ranks") == [int(dossier["victim_rank"])]
		and int(intent.get("base_mark_damage", -1)) == MARK_BONUS
		and intent.get("base_effects") == {},
		"AC2/AC3: the live Volley hunts the pinned doll and exposes exactly its authored +3")
	_check(bool(hit.get("hit", false)) and str(hit.get("target", "")) == victim_id
		and (hit.get("statuses", [-1]) as Array).is_empty(),
		"AC2: the Volley confirms its hit on that same doll and applies no extra status")
	var damage := int(hit.get("damage", -1))
	_check(damage == int(before.get("hp", 0)) - int(hit.get("target_hp", -2))
		and damage > 0,
		"AC2: the marked Volley's real HP loss equals its reported direct damage")
	var matched := _matching_bases(battle, attacker, ability, attacker.get("statuses", {}),
		before, true, damage, bool(hit.get("crit", false)))
	_check(not matched.is_empty(),
		"AC2: the Volley's real damage equals the marked formula on its rolled base")
	var prot := int(before.get("prot", 0))
	for base in matched:
		var marked_final := int(StitchedRules.damage_after_modifiers(
			base, attacker.get("statuses", {}), before.get("statuses", {}), true,
			MARK_BONUS, prot))
		var unmarked_final := int(StitchedRules.damage_after_modifiers(
			base, attacker.get("statuses", {}), before.get("statuses", {}), false,
			MARK_BONUS, prot))
		_check(marked_final == damage and unmarked_final < marked_final,
			"AC2: the authored +3 is added to the direct base before Weak/Exposed/Tangled/PROT")
		if prot == 0:
			_check(damage == base + MARK_BONUS and unmarked_final == base,
				"AC2: with no PROT the marked Volley deals exactly its rolled base plus 3")
	var mark_tick := 1 if battle.current_actor_id() == victim_id else 0
	_check(int(battle.get_unit(victim_id).get("statuses", {}).get("mark", 0))
			== maxi(0, mark_before - mark_tick),
		"AC2: a Volley hit spends no Mark; only the doll's own start-turn clock ticks it")
	for hero in battle.get_heroes():
		if str(hero["id"]) == victim_id:
			continue
		_check(int(battle.get_unit(str(hero["id"])).get("statuses", {}).get("mark", 0)) == 0,
			"AC2: the Volley's Mark hunt never marks another doll: " + str(hero["id"]))
	# The pinned doll's own turns count the Mark down one at a time while it stays marked.
	var observations: Array = dossier["observations"]
	var stepping := mark_before == MARK - observations.size()
	for index in range(observations.size()):
		stepping = stepping and int(observations[index]["mark"]) == MARK - (index + 1)
	_check(stepping, "AC2: MARK ticks down exactly one per own doll turn before the Volley")


# ---------------------------------------------------------------- AC2/AC3 honest misses

func _test_missed_prick(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("prick_miss", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var hit: Dictionary = dossier["prick_hit"]
	var victim_id := str(dossier["victim_id"])
	var before: Dictionary = dossier["victim_before"]
	_check(str(dossier.get("miss", "")) == "prick" and not bool(hit.get("hit", true))
		and int(hit.get("roll", 0)) > int(hit.get("hit_chance", 0))
		and int(hit.get("damage", -1)) == 0
		and (hit.get("statuses", [-1]) as Array).is_empty()
		and int(hit.get("target_hp", -1)) == int(before.get("hp", -2)),
		"AC2/AC3: a natural Prick miss deals no damage, no Bleed and no Mark")
	_check(int(dossier["mark_after_prick"]) == 0
		and int(battle.get_unit(victim_id).get("statuses", {}).get("mark", 0)) == 0,
		"AC2: the missed doll really carries no Mark afterwards")
	var vhit: Dictionary = dossier["volley_hit"]
	_check(int(dossier["mark_before_volley"]) == 0,
		"AC3: a missed pin leaves the later Volley with no Mark to hunt")
	if bool(vhit.get("hit", false)):
		var attacker: Dictionary = dossier["attacker_before"]
		var before_v: Dictionary = dossier["victim_before_volley"]
		var matched := _matching_bases(battle, attacker, _actor_ability(attacker, VOLLEY),
			attacker.get("statuses", {}), before_v, false, int(vhit["damage"]),
			bool(vhit.get("crit", false)))
		_check(not matched.is_empty(),
			"AC3: the later unmarked Volley hit matches only the unmarked formula")
		for base in matched:
			_check(int(StitchedRules.damage_after_modifiers(
					base, attacker.get("statuses", {}), before_v.get("statuses", {}), true,
					MARK_BONUS, int(before_v.get("prot", 0)))) > int(vhit["damage"]),
				"AC3: no phantom +3 is credited after a missed Prick")
	for hero in battle.get_heroes():
		_check(int(battle.get_unit(str(hero["id"])).get("statuses", {}).get("mark", 0)) == 0,
			"AC3: no doll is Marked by a missed pin: " + str(hero["id"]))


func _test_volley_miss(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("volley_miss", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var hit: Dictionary = dossier["volley_hit"]
	var before: Dictionary = dossier["victim_before_volley"]
	var mark_before := int(dossier["mark_before_volley"])
	_check(not bool(hit.get("hit", true)) and int(hit.get("roll", 0)) > int(hit.get("hit_chance", 0))
		and int(hit.get("damage", -1)) == 0
		and (hit.get("statuses", [-1]) as Array).is_empty()
		and int(hit.get("target_hp", -1)) == int(before.get("hp", -2)),
		"AC3: a natural Volley miss deals no damage, no status and no Mark bonus")
	var mark_tick := 1 if battle.current_actor_id() == str(dossier["victim_id"]) else 0
	_check(int(battle.get_unit(str(dossier["victim_id"])).get("statuses", {}).get("mark", 0))
			== maxi(0, mark_before - mark_tick),
		"AC3: a missed Volley spends no Mark and leaves the pin intact")


# ---------------------------------------------------------------- AC2 Bleed ignores PROT

## One confirmed Prick, then only public Passes until the pinned doll's own turn: the Bleed
## tick is the only thing that can change its HP, and it lands on that doll's turn alone.
func _bleed_cycle(seed_value: int, prot_override: int) -> Dictionary:
	var battle := _make_battle(seed_value, prot_override)
	if battle == null:
		return {}
	if not _advance_to_marshal(battle, 1):
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	if str(intent.get("ability_id", "")) != PRICK:
		return {}
	var rank := int(intent.get("target_rank", 0))
	var victim_id := _hero_id_at(battle, rank)
	var receipt := battle.use_foe_ability(PRICK, rank)
	if not bool(receipt.get("ok", false)) or (receipt.get("results", []) as Array).size() != 1:
		return {}
	var hit: Dictionary = (receipt["results"] as Array)[0]
	if not bool(hit.get("hit", false)):
		return {}
	var party_hp: Dictionary = {}
	for hero in battle.get_heroes():
		party_hp[str(hero["id"])] = int(battle.get_unit(str(hero["id"])).get("hp", 0))
	var arrived := false
	for _step in range(160):
		if battle.is_over():
			break
		if battle.current_actor_id() == victim_id:
			arrived = true
			break
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			break
	if not arrived:
		return {}
	var after := battle.get_unit(victim_id)
	return {
		"ok": true,
		"battle": battle,
		"receipt": receipt,
		"hit": hit,
		"victim_id": victim_id,
		"party_hp": party_hp,
		"after": after,
	}


func _test_bleed_tick(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var seed_value := int(dossier["seed"])
	var normal := _bleed_cycle(seed_value, -1)
	var protected := _bleed_cycle(seed_value, PROT_OVERRIDE)
	_check(not normal.is_empty() and not protected.is_empty(),
		"AC2: a confirmed Prick reaches the pinned doll's own turn for the Bleed tick")
	if normal.is_empty() or protected.is_empty():
		return
	for cycle in [normal, protected]:
		var hit: Dictionary = cycle["hit"]
		var after: Dictionary = cycle["after"]
		var before_hp := int(hit.get("target_hp", -1))
		_check(int(after.get("hp", -2)) == before_hp - BLEED,
			"AC2: Bleed 1 ticks exactly once on the affected doll's own turn")
		_check(int(after.get("statuses", {}).get("bleed", 0)) == 0
			and int(after.get("statuses", {}).get("mark", 0)) == MARK - 1,
			"AC2: that own turn also clocks the Bleed out and the Mark down one")
		for hero in cycle["battle"].get_heroes():
			var hero_id := str(hero["id"])
			if hero_id == str(cycle["victim_id"]):
				continue
			_check(int(cycle["battle"].get_unit(hero_id).get("hp", 0))
					== int(cycle["party_hp"].get(hero_id, -1))
				and int(cycle["battle"].get_unit(hero_id).get("statuses", {}).get("bleed", 0)) == 0,
				"AC2: no other doll loses HP or gains Bleed: " + hero_id)
	_check(int(protected["battle"].get_unit(str(protected["victim_id"])).get("prot", 0)) >= PROT_OVERRIDE,
		"AC2: the protected control really wears more PROT than the authored front doll")
	_check(int(protected["hit"].get("damage", -1)) < int(normal["hit"].get("damage", -1)),
		"AC2: PROT cuts the direct Prick damage while the Bleed tick still ignores it")


# ---------------------------------------------------------------- AC3 expired Mark

func _test_expired_volley(expired: Dictionary) -> void:
	if expired.is_empty():
		return
	var battle: StitchedRules = expired["battle"]
	var victim_id := str(expired["victim_id"])
	var hit: Dictionary = expired["volley_hit"]
	var before: Dictionary = expired["victim_before_volley"]
	var attacker: Dictionary = expired["attacker_before"]
	_check(int(expired["mark_before_volley"]) == 0
		and int(before.get("statuses", {}).get("mark", 0)) == 0
		and int(before.get("statuses", {}).get("bleed", 0)) == 0,
		"AC3: five real rounds later the authored pin has expired from the doll")
	var observations: Array = expired["observations"]
	var stepping := observations.size() >= MARK
	for index in range(observations.size()):
		stepping = stepping and int(observations[index]["mark"]) == maxi(0, MARK - (index + 1))
	_check(stepping, "AC3: the Mark clocks down through those real own turns to zero")
	_check(str(expired["intent"].get("ability_id", "")) == VOLLEY
		and int(expired["intent"].get("base_mark_damage", -1)) == MARK_BONUS,
		"AC3: the expired-Mark Volley keeps its authored reach and announces its +3")
	_check(bool(hit.get("hit", false)) and not bool(hit.get("crit", false))
		and (hit.get("statuses", [-1]) as Array).is_empty(),
		"AC3: the expired-Mark witness is a real confirmed Volley hit with no appended status")
	var damage := int(hit.get("damage", -1))
	_check(damage == int(before.get("hp", 0)) - int(hit.get("target_hp", -2)),
		"AC3: the expired-Mark hit's HP loss equals its reported damage")
	var matched := _matching_bases(battle, attacker, _actor_ability(attacker, VOLLEY),
		attacker.get("statuses", {}), before, false, damage, false)
	_check(not matched.is_empty(),
		"AC3: the expired-Mark hit matches only the unmarked formula: no phantom +3")
	for base in matched:
		_check(int(StitchedRules.damage_after_modifiers(
				base, attacker.get("statuses", {}), before.get("statuses", {}), true,
				MARK_BONUS, int(before.get("prot", 0)))) > damage,
			"AC3: had the Mark still applied, this hit would have dealt the authored +3")
	_check(int(battle.get_unit(victim_id).get("statuses", {}).get("mark", 0)) == 0,
		"AC3: the unmarked hit never re-attaches a Mark")


# ---------------------------------------------------------------- AC3 selector fixtures

## TEST-ONLY SELECTOR FIXTURE: plants a Mark on already-built living dolls solely to isolate
## StitchedFoeIntent's existing, unmodified Mark hunt and its authored rank reach. Every
## applied-status and damage receipt elsewhere came from real public actions.
func _test_selector_fixtures() -> void:
	var battle := _make_battle(37)
	if battle == null:
		_check(false, "AC3: the real selector battle builds")
		return
	if not _advance_to_marshal(battle, 2):
		_check(false, "AC3: the real selector battle reaches the Marshal's Volley turn")
		return
	var rank1 := _hero_id_at(battle, 1)
	var rank2 := _hero_id_at(battle, 2)
	var rank3 := _hero_id_at(battle, 3)
	_check(not rank1.is_empty() and not rank2.is_empty() and not rank3.is_empty(),
		"AC3: the first three hero ranks are occupied")
	var plain := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	_check(str(plain.get("ability_id", "")) == VOLLEY
		and int(plain.get("target_rank", 0)) == 1
		and int(plain.get("base_mark_damage", -1)) == MARK_BONUS,
		"AC3: with no live Mark the Volley keeps the nearest authored rank 1")
	battle._units[rank3]["statuses"]["mark"] = MARK
	battle._units[rank2]["statuses"]["mark"] = MARK
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var hunted := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	_check(str(hunted.get("ability_id", "")) == VOLLEY
		and int(hunted.get("target_rank", 0)) == 3
		and hunted.get("affected_ranks") == [3],
		"AC3: the existing Mark hunt prefers the authored rank 3 over an out-of-reach rank 2")
	_check(battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3: forecast only, no state, turn or RNG is spent by the selector")
	battle._units[rank3]["statuses"].erase("mark")
	var fallback := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	_check(int(fallback.get("target_rank", 0)) == 1,
		"AC3: an out-of-mask Mark cannot steal the Volley's legal rank 1")
	battle._units[rank2]["statuses"].erase("mark")
	battle._units[rank1]["statuses"]["mark"] = MARK
	var closest := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	_check(int(closest.get("target_rank", 0)) == 1 and closest.get("affected_ranks") == [1],
		"AC3: a live legal Mark at rank 1 keeps the nearest marked hunt")
	battle._units[rank1]["statuses"].erase("mark")


# ---------------------------------------------------------------- AC3 fail-closed actions

func _test_rejections() -> void:
	var battle := _make_battle(37)
	if battle == null:
		return
	var reached := _advance_to_marshal(battle, 2)
	_check(reached, "AC3: a real Marshal Volley turn is reached for the refusal checks")
	if not reached:
		return
	var rank2 := _hero_id_at(battle, 2)
	battle._units[rank2]["statuses"]["mark"] = MARK
	# Snapshots are taken after the labelled test-only Mark so only the refused command can
	# change anything.
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var actor := battle.current_actor_id()
	var off_mask := battle.use_foe_ability(VOLLEY, 2)
	_check(not bool(off_mask.get("ok", true))
		and str(off_mask.get("error", "")).contains("no legal target")
		and battle.state_snapshot() == state and battle.rng_state() == rng
		and battle.turn_order() == order and battle.current_actor_id() == actor,
		"AC3: a marked out-of-mask Volley rank is refused with no state, turn or RNG spend")
	var off_prick := battle.use_foe_ability(PRICK, 3)
	_check(not bool(off_prick.get("ok", true))
		and str(off_prick.get("error", "")).contains("no legal target")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3: Marshal Prick refuses a rank outside its authored front rank")
	var unknown := battle.use_foe_ability("not_an_authored_ability", 1)
	_check(not bool(unknown.get("ok", true))
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3: an unauthorized ability ID is refused with identical state and RNG")
	var was_rank := int(battle.get_unit(MARSHAL)["rank"])
	battle._units[MARSHAL]["rank"] = 3
	var unlaunchable := battle.use_foe_ability(PRICK, 1)
	battle._units[MARSHAL]["rank"] = was_rank
	_check(not bool(unlaunchable.get("ok", true))
		and str(unlaunchable.get("error", "")).contains("cannot launch")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3: a Prick the Marshal cannot launch from rank 3 is refused before any roll")
	battle._units[rank2]["statuses"].erase("mark")
	# Off-turn: spend the Marshal's Volley turn, then try a foe action on a hero's turn.
	var spent := battle.use_foe_ability(VOLLEY, 1)
	_check(bool(spent.get("ok", false)),
		"AC3: the Marshal's own legal Volley spends its real turn")
	var off_turn_checked := false
	if bool(spent.get("ok", false)):
		for _step in range(12):
			if battle.is_over() or battle.current_side() == "hero":
				break
			if not bool(battle.pass_turn().get("ok", false)):
				break
		if battle.current_side() == "hero":
			var hero_state := battle.state_snapshot()
			var hero_rng := battle.rng_state()
			var hero_actor := battle.current_actor_id()
			var off_turn := battle.use_foe_ability(PRICK, 1)
			off_turn_checked = true
			_check(not bool(off_turn.get("ok", true))
				and battle.state_snapshot() == hero_state
				and battle.rng_state() == hero_rng and battle.current_actor_id() == hero_actor,
				"AC3: an off-turn foe action is refused with no turn or RNG drift")
	_check(off_turn_checked, "AC3: a real hero turn was reached for the off-turn refusal")


# ---------------------------------------------------------------- AC4 seeded replay

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


func _test_replay(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var seed_value := int(dossier["seed"])
	var first := _run_cycle(seed_value, true)
	var second := _run_cycle(seed_value, true)
	_check(not first.is_empty() and not second.is_empty(),
		"AC4: both identical-seed lawful combo cycles complete")
	if first.is_empty() or second.is_empty():
		return
	_check(_norm(first["trace"]) == _norm(second["trace"]),
		"AC4: identical seeds replay every receipt, round, actor order and RNG position")
	_check(_norm(first["battle"].state_snapshot()) == _norm(second["battle"].state_snapshot())
		and first["battle"].turn_order() == second["battle"].turn_order()
		and first["battle"].rng_state() == second["battle"].rng_state(),
		"AC4: full snapshots, turn order and RNG state match exactly")
	_check((first["trace"] as Array).size() >= 6,
		"AC4: non-vacuous: the replay includes real Passes plus Prick and Volley")
