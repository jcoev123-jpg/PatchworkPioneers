extends SceneTree
## S5 Pincushion Matriarch: the canonical elite's pin barrage Marks a doll and its later
## bursts hunt that Mark, through the real seeded rules and the read-only foe intent.
##
## Deterministic and bounded: one seeded battle per run, public Pass/foe-ability turns only,
## and a bounded seed search for natural hit, miss, crit, protected and expired-Mark
## witnesses. No state is edited to manufacture a combat receipt; only the explicit intent
## selection fixture plants a Mark status on an already-built living doll.

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const MATRIARCH := "pincushion_matriarch"
const MARSHAL := "needle_marshal"
const BURST := "matriarch_burst"
const CROWN := "pin_crown"
const MARK_BONUS := 3
const SEED_LIMIT := 160
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
	_check(parsed is Dictionary, "real S2 hero and part preview parses")
	if not raw is Array or not bool(_catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	_preview = parsed
	_test_source_contract(raw)
	_test_catalog_contract(raw)
	var witnesses := _search_witnesses()
	_test_marked_burst(witnesses)
	_test_crit_burst(witnesses)
	_test_expired_and_miss(witnesses)
	_test_protected_burst(witnesses)
	_test_mark_selection()
	_test_other_actions()
	_test_rejects_and_stale_foes()
	_test_replay(witnesses)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_matriarch_mark_hunt_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


# ---------------------------------------------------------------- AC1 canonical record

func _burst_source() -> Dictionary:
	return {
		"id": BURST,
		"name": "Matriarch Burst",
		"kind": "melee",
		"launch": [1, 4],
		"target": [1, 2, 3],
		"target_side": "enemy",
		"multi": false,
		"acc": 85,
		"dmg": [3, 4],
		"crit": 0,
		"mark_damage": MARK_BONUS,
		"effects": {"mark": MARK_BONUS},
		"self_move": 0,
		"move": "attack2",
	}


func _crown_source() -> Dictionary:
	return {
		"id": CROWN,
		"name": "Pin Crown",
		"kind": "buff",
		"launch": [1, 3],
		"target": [1, 2, 3, 4],
		"target_side": "ally",
		"multi": true,
		"acc": 100,
		"dmg": [0, 0],
		"crit": 0,
		"effects": {"thorns": 4},
		"self_move": 0,
		"move": "guard",
	}


func _matriarch_record() -> Dictionary:
	return {
		"id": MATRIARCH,
		"name": "Pincushion Matriarch",
		"max_hp": 44,
		"thorns": 4,
		"art_path": "res://assets/paper/enemies/pincushion_matriarch.png",
		"intent": {
			"target": "front",
			"actions": [
				{"type": "attack", "amount": 9, "weight": 3},
				{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
				{"type": "block", "amount": 9, "weight": 2},
				{"type": "attack", "amount": 8, "hits": 2, "move": "attack2", "weight": 1},
				{"type": "attack", "amount": 10, "move": "attack3", "weight": 1},
			],
		},
		"stitched": {
			"max_hp": 44,
			"speed": 3,
			"dodge": 4,
			"acc": 0,
			"prot": 8,
			"is_boss": false,
			"turns_per_round": 1,
			"trophy": "pincushion_matriarch_crown",
			"abilities": [_burst_source(), _crown_source()],
		},
	}


func _records_with_id(raw: Array, enemy_id: String) -> Array:
	return raw.filter(func(record: Variant) -> bool:
		return record is Dictionary and str(record.get("id", "")) == enemy_id)


func _test_source_contract(raw: Array) -> void:
	var matches := _records_with_id(raw, MATRIARCH)
	_check(matches.size() == 1, "AC1: exactly one source record carries the Matriarch ID")
	if matches.size() != 1:
		return
	var expected: Variant = JSON.parse_string(JSON.stringify(_matriarch_record()))
	_check(matches[0] == expected,
		"AC1: identity, 44 HP, thorns, legacy intent, art, 3/4/8 stats, trophy, Burst and full Crown stay exact")
	var burst := {}
	var crown := {}
	for ability in matches[0].get("stitched", {}).get("abilities", []):
		if str(ability.get("id", "")) == BURST:
			burst = ability
		elif str(ability.get("id", "")) == CROWN:
			crown = ability
	_check(_norm(burst) == _norm(_burst_source()),
		"AC1: only Matriarch Burst gains MARK 3 / mark_damage 3; ACC/ranks/pose stay authored")
	var unmarked_burst := _burst_source()
	unmarked_burst.erase("mark_damage")
	unmarked_burst["effects"] = {}
	_check(_norm(burst) != _norm(unmarked_burst),
		"AC1: the MARK fields are the only change from the original Burst")
	_check(_norm(crown) == _norm(_crown_source()),
		"AC1: Pin Crown is byte-for-byte its original ally-side multi buff")
	# Independent validator agreement, not an echo of the catalog loader.
	var validated := StitchedParts.validate_ability(burst, "test matriarch burst")
	_check(bool(validated.get("ok", false))
		and int(validated.ability.get("mark_damage", 0)) == MARK_BONUS
		and validated.ability.get("effects") == {"mark": MARK_BONUS}
		and int(validated.ability.get("acc", 0)) == 85
		and validated.ability.get("dmg") == [3, 4],
		"AC1: StitchedParts.validate_ability normalizes the authored MARK 3 / +3 bonus")


func _test_catalog_contract(raw: Array) -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, MATRIARCH)
	_check(not foe.is_empty() and str(foe.get("name", "")) == "Pincushion Matriarch"
		and int(foe.get("max_hp", 0)) == 44 and int(foe.get("speed", -1)) == 3
		and int(foe.get("dodge", -1)) == 4 and int(foe.get("acc", -1)) == 0
		and int(foe.get("prot", -1)) == 8 and foe.get("is_boss") == false
		and int(foe.get("turns_per_round", 0)) == 1,
		"AC1: normalized canonical profile keeps 44 HP / SPEED 3 / DODGE 4 / ACC 0 / PROT 8")
	_check(StitchedEnemyCatalog.trophy_for(_catalog, MATRIARCH) == "pincushion_matriarch_crown"
		and _catalog.enemies.get(MATRIARCH, {}).get("tier") == "elite",
		"AC1: the unique crown trophy and elite tier are unchanged")
	var burst_valid := StitchedParts.validate_ability(_burst_source())
	var crown_valid := StitchedParts.validate_ability(_crown_source())
	var abilities: Array = foe.get("abilities", [])
	_check(abilities.size() == 2
		and bool(burst_valid.get("ok", false)) and bool(crown_valid.get("ok", false))
		and abilities[0] == burst_valid.ability and abilities[1] == crown_valid.ability,
		"AC1: the real loader normalizes exactly the two authored actions in order")
	# Every neighbouring elite stays present and valid by ID; no total-count oracle.
	var neighbours := 0
	for record in raw:
		if not record is Dictionary:
			continue
		if str(record.get("id", "")) == MATRIARCH:
			continue
		neighbours += 1
		var neighbour_id := str(record.get("id", ""))
		var neighbour := StitchedEnemyCatalog.foe_for(_catalog, neighbour_id)
		var abilities_valid := true
		for ability in record.get("stitched", {}).get("abilities", []):
			abilities_valid = abilities_valid and bool(StitchedParts.validate_ability(ability).get("ok", false))
		_check(not neighbour.is_empty() and neighbour["id"] == neighbour_id
			and StitchedEnemyCatalog.trophy_for(_catalog, neighbour_id)
				== str(record.get("stitched", {}).get("trophy", ""))
			and abilities_valid,
			"AC1: neighbour elite remains valid with its own ID and trophy: " + neighbour_id)
	_check(neighbours >= 2, "AC1: non-vacuous neighbour coverage beside the edited Matriarch")
	for neighbour_id in ["needle_marshal", "spool_hexer", "scissor_bailiff", "zipper_hauler"]:
		_check(_catalog.foes.has(neighbour_id),
			"AC1: original elite ID still resolves: " + neighbour_id)


# ---------------------------------------------------------------- seeded battle fixture

func _make_battle(seed_value: int, prot_override: int = -1) -> StitchedRules:
	var heroes: Array = _preview["heroes"].duplicate(true)
	if prot_override >= 0:
		heroes[0]["prot"] = prot_override
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var foes: Array = [
		StitchedEnemyCatalog.foe_for(_catalog, MATRIARCH),
		StitchedEnemyCatalog.foe_for(_catalog, MARSHAL),
	]
	if foes[0].is_empty() or foes[1].is_empty():
		return null
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": heroes, "parts": parts, "foes": foes,
	})
	if not bool(built.get("ok", false)):
		return null
	return built["battle"]


func _hero_id_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _record_step(battle: StitchedRules, trace: Variant, receipt: Dictionary) -> void:
	if trace == null:
		return
	var steps := trace as Array
	steps.append({
		"receipt": receipt.duplicate(true),
		"round": battle.round_number(),
		"actor_after": battle.current_actor_id(),
		"order": battle.turn_order(),
		"rng": battle.rng_state(),
	})


## Legal public Passes until the Matriarch's next turn. Captures the marked doll's status at
## the start of each of its own turns, and reports false if the battle ends first.
func _advance_to_matriarch(
	battle: StitchedRules, trace: Variant, watch_id: String, marks_seen: Array
) -> bool:
	for _step in range(160):
		if battle == null or battle.is_over():
			return false
		var actor_id := battle.current_actor_id()
		if actor_id == MATRIARCH:
			return true
		if not watch_id.is_empty() and actor_id == watch_id:
			marks_seen.append(int(battle.get_unit(actor_id).get("statuses", {}).get("mark", 0)))
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			return false
		_record_step(battle, trace, passed)
	return false


func _run_cycle(seed_value: int, prot_override: int = -1, record_trace: bool = false) -> Dictionary:
	var battle := _make_battle(seed_value, prot_override)
	if battle == null:
		return {"ok": false, "fail": "build"}
	var trace: Variant = null
	if record_trace:
		trace = []
	if not _advance_to_matriarch(battle, trace, "", []):
		return {"ok": false, "fail": "reach first turn"}
	var start_round := battle.round_number()
	var intent1 := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	if str(intent1.get("ability_id", "")) != BURST:
		return {"ok": false, "fail": "first turn is not Burst"}
	var attacker := battle.get_unit(MATRIARCH)
	var rank1 := int(intent1.get("target_rank", 0))
	var target1_id := _hero_id_at(battle, rank1)
	var target1_before := battle.get_unit(target1_id)
	var burst1 := battle.use_foe_ability(BURST, rank1)
	_record_step(battle, trace, burst1)
	if not bool(burst1.get("ok", false)) or burst1.get("results", []).size() != 1:
		return {"ok": false, "fail": "first burst"}
	var hit1: Dictionary = burst1["results"][0]
	var target1_mark := int(battle.get_unit(target1_id).get("statuses", {}).get("mark", 0))
	var marks_seen: Array = []
	if not _advance_to_matriarch(battle, trace, target1_id, marks_seen):
		return {"ok": false, "fail": "reach second turn"}
	if battle.round_number() != start_round + 1:
		return {"ok": false, "fail": "second turn is not the next round"}
	var intent2 := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	if str(intent2.get("ability_id", "")) != CROWN:
		return {"ok": false, "fail": "second turn is not Pin Crown"}
	var foes_before := battle.get_foes().duplicate(true)
	var crown := battle.use_foe_ability(CROWN, int(intent2.get("target_rank", 0)))
	_record_step(battle, trace, crown)
	if not bool(crown.get("ok", false)):
		return {"ok": false, "fail": "pin crown"}
	var thorns_after: Dictionary = {}
	for old in foes_before:
		thorns_after[str(old["id"])] = int(
			battle.get_unit(str(old["id"])).get("statuses", {}).get("thorns", 0))
	if not _advance_to_matriarch(battle, trace, target1_id, marks_seen):
		return {"ok": false, "fail": "reach third turn"}
	if battle.round_number() != start_round + 2:
		return {"ok": false, "fail": "third turn is not two rounds later"}
	var intent3 := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	if str(intent3.get("ability_id", "")) != BURST:
		return {"ok": false, "fail": "third turn is not Burst"}
	var rank3 := int(intent3.get("target_rank", 0))
	var target3_id := _hero_id_at(battle, rank3)
	var target3_before := battle.get_unit(target3_id)
	var attacker_statuses: Dictionary = battle.get_unit(MATRIARCH).get("statuses", {}).duplicate(true)
	var burst3 := battle.use_foe_ability(BURST, rank3)
	_record_step(battle, trace, burst3)
	if not bool(burst3.get("ok", false)) or burst3.get("results", []).size() != 1:
		return {"ok": false, "fail": "third burst"}
	var hit3: Dictionary = burst3["results"][0]
	return {
		"ok": true,
		"seed": seed_value,
		"battle": battle,
		"trace": trace,
		"start_round": start_round,
		"intent1": intent1,
		"rank1": rank1,
		"target1_id": target1_id,
		"target1_before": target1_before,
		"burst1": burst1,
		"hit1": hit1,
		"target1_mark_after": target1_mark,
		"marks_seen": marks_seen,
		"intent2": intent2,
		"crown": crown,
		"thorns_after": thorns_after,
		"intent3": intent3,
		"rank3": rank3,
		"target3_id": target3_id,
		"target3_before": target3_before,
		"attacker_statuses": attacker_statuses,
		"burst3": burst3,
		"hit3": hit3,
		"mark_before3": int(target3_before.get("statuses", {}).get("mark", 0)),
	}


func _search_witnesses() -> Dictionary:
	var found := {"hit": {}, "crit": {}, "expired": {}, "miss": {}}
	for seed_value in range(1, SEED_LIMIT + 1):
		if (not found["hit"].is_empty() and not found["crit"].is_empty()
				and not found["expired"].is_empty() and not found["miss"].is_empty()):
			break
		var dossier := _run_cycle(seed_value)
		if not bool(dossier.get("ok", false)):
			continue
		var hit1: Dictionary = dossier["hit1"]
		var hit3: Dictionary = dossier["hit3"]
		if (found["hit"].is_empty() and bool(hit3.get("hit", false))
				and int(dossier["mark_before3"]) > 0 and not bool(hit3.get("crit", false))):
			found["hit"] = dossier
		if (found["crit"].is_empty() and bool(hit3.get("hit", false))
				and int(dossier["mark_before3"]) > 0 and bool(hit3.get("crit", false))):
			found["crit"] = dossier
		if (found["expired"].is_empty() and bool(hit1.get("hit", false))
				and bool(hit3.get("hit", false)) and int(dossier["mark_before3"]) == 0):
			found["expired"] = dossier
		if found["miss"].is_empty() and not bool(hit1.get("hit", true)):
			found["miss"] = dossier
	for key in found:
		_check(not found[key].is_empty(),
			"non-vacuous bounded seed witness is reachable: " + key)
	return found


# ---------------------------------------------------------------- damage witnesses

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


func _matching_bases_for(
	attacker: Dictionary, ability: Dictionary, attacker_statuses: Dictionary,
	defender: Dictionary, marked: bool, damage: int, crit: bool
) -> Array[int]:
	var matched: Array[int] = []
	var candidates := _bases(attacker, ability, crit)
	for base in candidates:
		if int(StitchedRules.damage_after_modifiers(
				base, attacker_statuses, defender.get("statuses", {}), marked, MARK_BONUS,
				int(defender.get("prot", 0)))) == damage:
			matched.append(base)
	return matched


func _test_marked_burst(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var attacker := battle.get_unit(MATRIARCH)
	var ability := _actor_ability(attacker, BURST)
	var intent1: Dictionary = dossier["intent1"]
	var hit1: Dictionary = dossier["hit1"]
	var hit3: Dictionary = dossier["hit3"]
	var before1: Dictionary = dossier["target1_before"]
	var before3: Dictionary = dossier["target3_before"]
	var target1_id := str(dossier["target1_id"])
	_check(int(before1.get("statuses", {}).get("mark", 0)) == 0,
		"AC2: the first Matriarch Burst really strikes an unmarked doll")
	_check(int(intent1.get("base_mark_damage", 0)) == MARK_BONUS
		and intent1.get("base_effects") == {"mark": MARK_BONUS}
		and int(intent1.get("base_acc", 0)) == 85 and intent1.get("base_damage") == [3, 4]
		and str(intent1.get("ability_kind", "")) == "melee"
		and not bool(intent1.get("multi", true)) and bool(hit1.get("hit", false)),
		"AC2/AC3: the live intent announces the exact authored Burst with MARK 3 and +3")
	_check(hit1.get("statuses") == [{"status": "mark", "duration": MARK_BONUS}],
		"AC2: a confirmed Burst receipt applies MARK 3 only after its damage")
	_check(int(dossier["target1_mark_after"]) == MARK_BONUS
		- (1 if str(battle.current_actor_id()) == target1_id else 0),
		"AC2: the real target carries MARK 3, minus only its own next start-turn tick")
	_check(int(hit1.get("damage", -1)) == int(before1.get("hp", 0)) - int(hit1.get("target_hp", 0)),
		"AC2: the first burst's real HP loss equals its reported direct damage")
	var first_matches := _matching_bases_for(
		attacker, ability, {}, before1, false, int(hit1["damage"]), bool(hit1.get("crit", false)))
	_check(not first_matches.is_empty(),
		"AC2: an unmarked first Burst matches only the unmarked direct-damage formula")
	for base in first_matches:
		_check(int(StitchedRules.damage_after_modifiers(base, {}, {}, true, MARK_BONUS, 0))
			== base + MARK_BONUS
			and int(StitchedRules.damage_after_modifiers(base, {}, {}, false, MARK_BONUS, 0))
				== base,
			"AC2: the authored mark bonus is exactly +3 on the direct base")
		var marked_damage := int(StitchedRules.damage_after_modifiers(
			base, {}, before1.get("statuses", {}), true, MARK_BONUS, int(before1.get("prot", 0))))
		_check(marked_damage > int(hit1["damage"]),
			"AC2: the unmarked first burst never profits from the mark it just applied")
	# Round two: Pin Crown still guards the foe line with THORNS 4.
	var crown: Dictionary = dossier["crown"]
	_check(str(dossier["intent2"].get("ability_id", "")) == CROWN
		and bool(dossier["intent2"].get("multi", false))
		and dossier["intent2"].get("base_effects") == {"thorns": 4},
		"AC2: the unchanged round-two intent is the ally-side Pin Crown")
	_check(crown.get("results", []).size() == 2,
		"AC2: Pin Crown reaches both living foe ranks, not the hero line")
	var crown_thorns := true
	for result in crown.get("results", []):
		crown_thorns = crown_thorns and str(result.get("target_side", "")) == "foe" \
			and bool(result.get("hit", false)) and int(result.get("damage", -1)) == 0 \
			and result.get("statuses") == [{"status": "thorns", "duration": 4}]
	_check(crown_thorns, "AC2: every Crown receipt is a zero-damage THORNS 4 foe buff")
	var thorns_after: Dictionary = dossier["thorns_after"]
	for foe_id in thorns_after:
		var expected := 4 - (1 if str(battle.current_actor_id()) == foe_id else 0)
		_check(int(thorns_after[foe_id]) == expected,
			"AC2: real foe state keeps THORNS 4 with only its own start-turn tick")
	for hero in battle.get_heroes():
		_check(int(hero.get("statuses", {}).get("thorns", 0)) == 0,
			"AC2: Pin Crown never puts THORNS on the hero side")
	# Round three: the marked target is hunted and takes exactly the +3 base bonus.
	_check(int(dossier["mark_before3"]) > 0,
		"AC2: the Mark is still live when the third-round Burst is chosen")
	_check(int(dossier["intent3"].get("target_rank", 0)) == int(dossier["rank3"])
		and int(dossier["rank3"]) == 1,
		"AC3: the marked closest legal doll is selected, not a blind nearest scan")
	var third_matches := _matching_bases_for(
		attacker, ability, dossier["attacker_statuses"], before3, true,
		int(hit3["damage"]), bool(hit3.get("crit", false)))
	_check(not third_matches.is_empty(),
		"AC2: the third Burst's real damage equals the marked formula on its rolled base")
	for base in third_matches:
		_check(int(StitchedRules.damage_after_modifiers(
				base, dossier["attacker_statuses"], before3.get("statuses", {}), true,
				MARK_BONUS, int(before3.get("prot", 0)))) == int(hit3["damage"]),
			"AC2: the marked third Burst adds exactly the authored +3 before PROT")
	_check(int(hit3.get("damage", -1))
		== int(before3.get("hp", 0)) - int(hit3.get("target_hp", 0)),
		"AC2: the marked third burst's real HP loss equals its reported damage")
	var seen: Array = dossier["marks_seen"]
	var stepping := true
	for index in range(1, seen.size()):
		stepping = stepping and int(seen[index]) == int(seen[index - 1]) - 1
	_check(seen.size() >= 1 and stepping
		and seen.all(func(value: Variant) -> bool: return int(value) >= 0),
		"AC2: MARK ticks down exactly one per own doll turn, never on an arbitrary clock")


func _test_crit_burst(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("crit", {})
	if dossier.is_empty():
		return
	var battle: StitchedRules = dossier["battle"]
	var hit3: Dictionary = dossier["hit3"]
	var before3: Dictionary = dossier["target3_before"]
	var attacker := battle.get_unit(MATRIARCH)
	var base := StitchedRules.crit_damage(4) + int(attacker.get("dmg_bonus", 0))
	var expected := int(StitchedRules.damage_after_modifiers(
		base, dossier["attacker_statuses"], before3.get("statuses", {}), true,
		MARK_BONUS, int(before3.get("prot", 0))))
	_check(bool(hit3.get("crit", false)) and int(hit3.get("damage", -1)) == expected,
		"AC2: a critical marked Burst is floor(1.5 x max) + 3, then PROT")
	_check(int(StitchedRules.damage_after_modifiers(
			base, dossier["attacker_statuses"], before3.get("statuses", {}), false,
			MARK_BONUS, int(before3.get("prot", 0)))) < expected,
		"AC2: the critical hit's bonus is the Mark, not a changed crit formula")


func _test_expired_and_miss(witnesses: Dictionary) -> void:
	var expired: Dictionary = witnesses.get("expired", {})
	if not expired.is_empty():
		var battle: StitchedRules = expired["battle"]
		var hit3: Dictionary = expired["hit3"]
		var before3: Dictionary = expired["target3_before"]
		_check(bool(hit3.get("hit", false)) and int(expired["mark_before3"]) == 0,
			"AC2: the expired-Mark witness really strikes an unmarked doll")
		var matched := _matching_bases_for(
			battle.get_unit(MATRIARCH), _burst_source(), expired["attacker_statuses"],
			before3, false, int(hit3["damage"]), bool(hit3.get("crit", false)))
		_check(not matched.is_empty(),
			"AC2: an expired Mark gives no phantom +3; damage matches the unmarked formula")
		for base in matched:
			_check(int(StitchedRules.damage_after_modifiers(
					base, expired["attacker_statuses"], before3.get("statuses", {}), true,
					MARK_BONUS, int(before3.get("prot", 0)))) > int(hit3["damage"]),
				"AC2: had the Mark still applied, this hit would have dealt the +3")
		_check(str(expired["intent3"].get("target_rank", 0)) == "1"
			and int(expired["rank3"]) == 1,
			"AC3: with no live marked candidate the chooser keeps the nearest rank-1 scan")
	var miss: Dictionary = witnesses.get("miss", {})
	if miss.is_empty():
		return
	var missed_battle: StitchedRules = miss["battle"]
	var hit1: Dictionary = miss["hit1"]
	var before1: Dictionary = miss["target1_before"]
	_check(not bool(hit1.get("hit", true)) and int(hit1.get("damage", -1)) == 0
		and hit1.get("statuses", [-1]).is_empty()
		and int(hit1.get("target_hp", -1)) == int(before1.get("hp", -2))
		and int(before1.get("statuses", {}).get("mark", 0)) == 0,
		"AC2: a natural miss deals no damage and applies neither MARK nor a bonus")
	_check(int(miss["target1_mark_after"]) == 0,
		"AC2: the missed doll really carries no MARK afterwards")
	var hit3: Dictionary = miss["hit3"]
	if bool(hit3.get("hit", false)):
		var matched := _matching_bases_for(
			missed_battle.get_unit(MATRIARCH), _burst_source(), miss["attacker_statuses"],
			miss["target3_before"], false, int(hit3["damage"]), bool(hit3.get("crit", false)))
		_check(int(miss["mark_before3"]) == 0 and not matched.is_empty(),
			"AC2: after a missed first Burst the later hit is unmarked with no +3")


func _test_protected_burst(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var normal: Dictionary = _run_cycle(int(dossier["seed"]))
	var protected: Dictionary = _run_cycle(int(dossier["seed"]), PROT_OVERRIDE)
	_check(bool(normal.get("ok", false)) and bool(protected.get("ok", false)),
		"AC2: the same seed replays with a raised PROT hero for a protected witness")
	if not bool(normal.get("ok", false)) or not bool(protected.get("ok", false)):
		return
	var normal_hit3: Dictionary = normal["hit3"]
	var protected_hit3: Dictionary = protected["hit3"]
	var before3: Dictionary = protected["target3_before"]
	_check(bool(normal_hit3.get("hit", false)) and bool(protected_hit3.get("hit", false))
		and bool(normal_hit3.get("crit", false)) == bool(protected_hit3.get("crit", false))
		and int(normal_hit3.get("roll", -1)) == int(protected_hit3.get("roll", -2)),
		"AC2: PROT changes only mitigation, not the seeded hit/crit roll")
	_check(int(before3.get("prot", 0)) >= PROT_OVERRIDE,
		"AC2: the protected witness really wears more PROT than the authored doll")
	var matched := _matching_bases_for(
		protected["battle"].get_unit(MATRIARCH), _actor_ability(
			protected["battle"].get_unit(MATRIARCH), BURST), protected["attacker_statuses"],
		before3, true, int(protected_hit3["damage"]), bool(protected_hit3.get("crit", false)))
	_check(not matched.is_empty(),
		"AC2: protected marked damage is the protected cut of base + 3")
	var prot := int(before3.get("prot", 0))
	for base in matched:
		var marked_final := int(StitchedRules.apply_protection(base + MARK_BONUS, prot))
		var unmarked_final := int(StitchedRules.apply_protection(base, prot))
		_check(marked_final == int(protected_hit3["damage"])
			and marked_final >= unmarked_final and marked_final - unmarked_final < MARK_BONUS,
			"AC2: PROT cuts the already-added +3, so the final gain is smaller but present")


# ---------------------------------------------------------------- explicit selection fixture

func _advance_silent(battle: StitchedRules, actor_id: String, wanted_round: int = 0) -> bool:
	for _step in range(160):
		if battle == null or battle.is_over():
			return false
		if battle.current_actor_id() == actor_id \
				and (wanted_round == 0 or battle.round_number() == wanted_round):
			return true
		if wanted_round > 0 and battle.round_number() > wanted_round:
			return false
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


func _test_mark_selection() -> void:
	var battle := _make_battle(37)
	if battle == null:
		_check(false, "AC3: real mark-selection battle builds")
		return
	if not _advance_silent(battle, MATRIARCH, 1):
		_check(false, "AC3: real mark-selection battle reaches the Matriarch's Burst turn")
		return
	var actor := battle.get_unit(MATRIARCH)
	var rank1 := _hero_id_at(battle, 1)
	var rank2 := _hero_id_at(battle, 2)
	var rank3 := _hero_id_at(battle, 3)
	var rank4 := _hero_id_at(battle, 4)
	_check(not rank1.is_empty() and not rank2.is_empty(),
		"AC3: the front and second legal hero ranks are occupied")
	battle._units[rank2]["statuses"]["mark"] = MARK_BONUS
	battle._units[rank3]["statuses"]["mark"] = MARK_BONUS
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	var legal_ranks: Array[int] = []
	for rank in range(1, 5):
		if not battle._legal_targets(actor, battle.get_unit(MATRIARCH)["abilities"][0], rank).is_empty():
			legal_ranks.append(rank)
	_check(legal_ranks.has(1) and legal_ranks.has(2),
		"AC3: non-vacuous legal target set includes the unmarked front and a marked rank")
	_check(str(choice.get("ability_id", "")) == BURST
		and int(choice.get("target_rank", 0)) == 2
		and choice.get("affected_ranks") == [2]
		and str(choice.get("target_side", "")) == "hero"
		and not bool(choice.get("multi", true))
		and int(choice.get("base_acc", -1)) == 85
		and choice.get("base_damage") == [3, 4]
		and int(choice.get("base_mark_damage", -1)) == MARK_BONUS
		and choice.get("base_effects") == {"mark": MARK_BONUS}
		and int(choice.get("base_crit", -1)) == 0
		and bool(choice.get("base_effects").has("mark")),
		"AC3: the read-only intent prefers the closest already-MARKed legal rank 2")
	var repeated := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(_norm(repeated) == _norm(choice) and battle.state_snapshot() == state
		and battle.rng_state() == rng,
		"AC3: repeated forecasts mutate neither state, marks, turn nor RNG")
	# A marked ally, an illegal rank or a scrap heap never steal the hunt.
	battle._units[rank2]["statuses"].erase("mark")
	battle._units[rank3]["statuses"].erase("mark")
	battle._units[MARSHAL]["statuses"]["mark"] = MARK_BONUS
	battle._units[rank4]["statuses"]["mark"] = MARK_BONUS
	battle._heaps.append({"id": "heap:test", "side": "heap", "rank": 3,
		"hp": 5, "max_hp": 5, "foe_id": "gone"})
	var illegal := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(int(illegal.get("target_rank", 0)) == 1
		and illegal.get("affected_ranks") == [1],
		"AC3: a marked ally, an out-of-mask rank 4 or a scrap heap is never preferred")
	battle._heaps.clear()
	battle._units[rank4]["statuses"].erase("mark")
	battle._units[MARSHAL]["statuses"].erase("mark")
	# Only rank 2 still marked, but now LOST: the hunt must fall back to rank 1.
	battle._units[rank2]["statuses"]["mark"] = MARK_BONUS
	battle._units[rank2]["lost"] = true
	var lost_choice := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(int(lost_choice.get("target_rank", 0)) == 1
		and not bool(lost_choice.get("pass", true)),
		"AC3: a lost marked doll is not a legal hunt target")
	battle._units[rank2]["lost"] = false
	battle._units[rank2]["statuses"].erase("mark")
	var nearest := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(int(nearest.get("target_rank", 0)) == 1 and nearest.get("affected_ranks") == [1],
		"AC3: with no legal marked candidate the original nearest rank-1 scan returns")
	# A stunned or unlaunchable Matriarch forecasts no invented attack.
	battle._units[MATRIARCH]["statuses"]["stun"] = 1
	var stunned := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(bool(stunned.get("stun", false)) and str(stunned.get("ability_id", "")) == ""
		and int(stunned.get("target_rank", -1)) == 0 and not stunned.has("base_damage"),
		"AC3: a stunned Matriarch reports STUN without a fake ability or target")
	battle._units[MATRIARCH]["statuses"].erase("stun")
	battle._units[MARSHAL]["rank"] = 4
	battle._units[MATRIARCH]["rank"] = 2
	var blocked := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(bool(blocked.get("pass", false)) and not bool(blocked.get("stun", false))
		and str(blocked.get("ability_id", "")) == "" and int(blocked.get("target_rank", -1)) == 0,
		"AC3: unlaunchable Kit reports PASS and invents no attack")
	battle._units[MATRIARCH]["rank"] = 1
	battle._units[MARSHAL]["rank"] = 2
	var restored := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(int(restored.get("target_rank", 0)) == 1,
		"AC3: restored formation returns to the nearest legal rank-1 choice")


func _test_other_actions() -> void:
	# An ordinary non-Mark foe attack keeps its own nearest legal target despite a Mark.
	var battle := _make_battle_with([MATRIARCH, "zipper_hauler"], 37)
	if battle == null:
		return
	var reached := _advance_silent(battle, "zipper_hauler", 1)
	_check(reached, "AC3: non-vacuous ordinary other-foe attack turn is reached")
	if reached:
		battle._units[_hero_id_at(battle, 2)]["statuses"]["mark"] = MARK_BONUS
		var state := battle.state_snapshot()
		var rng := battle.rng_state()
		var hauler := battle.get_unit("zipper_hauler")
		var choice := StitchedFoeIntent.choose(battle, hauler)
		_check(str(choice.get("ability_id", "")) == "hauler_slam"
			and int(choice.get("target_rank", 0)) == 1 and choice.get("affected_ranks") == [1]
			and int(choice.get("base_mark_damage", -1)) == 0,
			"AC3: an ordinary other-foe attack does not hunt a Marked rank")
		_check(battle.state_snapshot() == state and battle.rng_state() == rng,
			"AC3: the ordinary-foe choice stays read-only")
	# A pull still reels the deepest legal rank, whatever carries a Mark.
	var pull_battle := _make_battle_with(["spool_snarekeeper", "zipper_hauler"], 11)
	if pull_battle == null:
		return
	var pull_reached := _advance_silent(pull_battle, "spool_snarekeeper", 2)
	_check(pull_reached, "AC3: non-vacuous pull turn is reached")
	if pull_reached:
		pull_battle._units[_hero_id_at(pull_battle, 1)]["statuses"]["mark"] = MARK_BONUS
		pull_battle._units[_hero_id_at(pull_battle, 4)]["statuses"]["mark"] = MARK_BONUS
		var pull_state := pull_battle.state_snapshot()
		var pull_rng := pull_battle.rng_state()
		var pull := StitchedFoeIntent.choose(pull_battle, pull_battle.get_unit("spool_snarekeeper"))
		_check(str(pull.get("ability_id", "")) == "spool_snare"
			and int(pull.get("target_rank", 0)) == 4 and pull.get("affected_ranks") == [4]
			and int(pull.get("base_mark_damage", -1)) == 0,
			"AC3: a pull keeps its deepest-first legal rank and no mark hunt")
		_check(pull_battle.state_snapshot() == pull_state and pull_battle.rng_state() == pull_rng,
			"AC3: the pull projection is read-only")


func _make_battle_with(enemy_ids: Array, seed_value: int) -> StitchedRules:
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var foes: Array = []
	for enemy_id in enemy_ids:
		var foe := StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id))
		if foe.is_empty():
			return null
		foes.append(foe)
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": _preview["heroes"].duplicate(true), "parts": parts, "foes": foes,
	})
	return built["battle"] if bool(built.get("ok", false)) else null


func _test_rejects_and_stale_foes() -> void:
	var battle := _make_battle(37)
	if battle == null:
		return
	var reached := _advance_silent(battle, MATRIARCH, 1)
	_check(reached, "AC4: non-vacuous real Matriarch turn is reached for refusals")
	if not reached:
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor := battle.get_unit(MATRIARCH)
	var wrong_rank := battle.use_foe_ability(BURST, 4)
	_check(not bool(wrong_rank.get("ok", true))
		and str(wrong_rank.get("error", "")).contains("no legal target")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC4: a wrong-rank Burst is refused with no state, turn or RNG spend")
	var wrong_ability := battle.use_foe_ability("not_an_authored_ability", 1)
	_check(not bool(wrong_ability.get("ok", true))
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC4: an unauthored ability is refused with identical state and RNG")
	battle._units[MATRIARCH]["rank"] = 2
	var unlaunchable := battle.use_foe_ability(BURST, 1)
	battle._units[MATRIARCH]["rank"] = 1
	_check(not bool(unlaunchable.get("ok", true))
		and str(unlaunchable.get("error", "")).contains("cannot launch")
		and battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC4: an unlaunchable Burst is refused before any roll or command")
	_check(StitchedFoeIntent.choose(battle, {}).is_empty()
		and StitchedFoeIntent.choose(battle, {"id": "ghost_foe"}).is_empty(),
		"AC3: empty and impostor foe dictionaries never invent an intent")
	var stale := battle.get_unit(MATRIARCH)
	stale["abilities"] = []
	stale["statuses"] = {"stun": 1}
	var authoritative := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	var from_stale := StitchedFoeIntent.choose(battle, stale)
	_check(_norm(from_stale) == _norm(authoritative)
		and str(from_stale.get("ability_id", "")) == BURST,
		"AC3: a detached stale foe dictionary cannot forge a stun or empty kit")
	battle._units[MATRIARCH]["dead"] = true
	battle._units[MATRIARCH]["hp"] = 0
	var dead := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(dead.is_empty(), "AC3: a dead foe has no selectable intent")
	battle._units[MATRIARCH]["dead"] = false
	battle._units[MATRIARCH]["hp"] = int(battle._units[MATRIARCH]["max_hp"])
	battle._units[MATRIARCH]["lost"] = true
	var lost := StitchedFoeIntent.choose(battle, battle.get_unit(MATRIARCH))
	_check(lost.is_empty(), "AC3: a lost foe has no selectable intent")
	battle._units[MATRIARCH]["lost"] = false
	_check(battle.state_snapshot() == state and battle.rng_state() == rng,
		"AC3/AC4: every failed forecast and refused command left the battle untouched")


func _test_replay(witnesses: Dictionary) -> void:
	var dossier: Dictionary = witnesses.get("hit", {})
	if dossier.is_empty():
		return
	var first := _run_cycle(int(dossier["seed"]), -1, true)
	var second := _run_cycle(int(dossier["seed"]), -1, true)
	_check(bool(first.get("ok", false)) and bool(second.get("ok", false)),
		"AC4: both identical-seed lawful cycles complete")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	_check(_norm(first["trace"]) == _norm(second["trace"]),
		"AC4: identical seeds replay every receipt, round, actor order and RNG position")
	_check(_norm(first["battle"].state_snapshot()) == _norm(second["battle"].state_snapshot())
		and first["battle"].turn_order() == second["battle"].turn_order()
		and first["battle"].rng_state() == second["battle"].rng_state(),
		"AC4: full final snapshots, turn order and RNG state match exactly")
	var receipt_count := (first["trace"] as Array).size()
	_check(receipt_count >= 6, "AC4: non-vacuous: the replay includes real Passes and three foe actions")
