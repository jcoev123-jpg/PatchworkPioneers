extends SceneTree
## Canonical thorn-line buffs through the live catalog, intent service and public battle actions.

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const CASES := [
	{"id": "needle_briar_guard", "name": "Needle Briar Guard", "buff": "briar_wall",
		"buff_name": "Briar Wall", "thorns": 3, "hp": 42, "prot": 10,
		"trophy": "needle_briar_guard_briar"},
	{"id": "pincushion_matriarch", "name": "Pincushion Matriarch", "buff": "pin_crown",
		"buff_name": "Pin Crown", "thorns": 4, "hp": 44, "prot": 8,
		"trophy": "pincushion_matriarch_crown"},
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(catalog.get("ok", false), "AC1: canonical enemy and enemy-part catalogs validate")
	if catalog.get("ok", false):
		for spec in CASES:
			_test_source(catalog, spec)
			_test_line_and_replay(catalog, spec)
			_test_reactions(catalog, spec)
	if failures.is_empty():
		print("stitched_s5_thorn_line_defense_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s5_thorn_line_defense_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _buff(spec: Dictionary) -> Dictionary:
	return {"id": spec.buff, "name": spec.buff_name, "kind": "buff", "launch": [1, 3],
		"target": [1, 2, 3, 4], "target_side": "ally", "multi": true, "acc": 100,
		"dmg": [0, 0], "crit": 0, "effects": {"thorns": spec.thorns}, "self_move": 0, "move": "guard"}


func _attack(spec: Dictionary) -> Dictionary:
	if spec.id == "needle_briar_guard":
		return {"id": "briar_thrust", "name": "Briar Thrust", "kind": "melee", "launch": [1, 3],
			"target": [1], "target_side": "enemy", "multi": false, "acc": 86, "dmg": [4, 5],
			"crit": 0, "effects": {"bleed": 2}, "self_move": 0, "move": "attack2"}
	return {"id": "matriarch_burst", "name": "Matriarch Burst", "kind": "melee", "launch": [1, 4],
		"target": [1, 2, 3], "target_side": "enemy", "multi": false, "acc": 85, "dmg": [3, 4],
		"crit": 0, "mark_damage": 3, "effects": {"mark": 3}, "self_move": 0, "move": "attack2"}


func _legacy(spec: Dictionary) -> Dictionary:
	var actions: Array = [
		{"type": "debuff", "amount": 2, "status": "bleed", "weight": 2},
		{"type": "block", "amount": 8, "weight": 2},
		{"type": "attack", "amount": 9, "weight": 3},
		{"type": "attack", "amount": 8, "hits": 2, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
	]
	if spec.id == "pincushion_matriarch":
		actions = [actions[2], actions[0], {"type": "block", "amount": 9, "weight": 2},
			actions[3], {"type": "attack", "amount": 10, "move": "attack3", "weight": 1}]
	return {"target": "front", "actions": actions}


func _test_source(catalog: Dictionary, spec: Dictionary) -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITES))
	_check(records is Array, "AC1: real elite source array exists")
	if not records is Array:
		return
	var matches: Array = records.filter(func(record: Dictionary) -> bool: return record.get("id") == spec.id)
	_check(matches.size() == 1, "AC1: unique named source record " + spec.id)
	if matches.size() != 1:
		return
	var profile := {"max_hp": spec.hp, "speed": 3, "dodge": 4, "acc": 0, "prot": spec.prot,
		"is_boss": false, "turns_per_round": 1, "trophy": spec.trophy, "abilities": [_attack(spec), _buff(spec)]}
	var expected := {"id": spec.id, "name": spec.name, "max_hp": spec.hp, "thorns": spec.thorns,
		"art_path": "res://assets/paper/enemies/%s.png" % spec.id, "intent": _legacy(spec), "stitched": profile}
	_check(matches[0] == JSON.parse_string(JSON.stringify(expected)),
		"AC1: exact identity/stats/legacy intent/art/trophy/attack and multi thorn buff: " + spec.id)
	var foe := StitchedEnemyCatalog.foe_for(catalog, spec.id)
	_check(not foe.is_empty() and catalog.enemies[spec.id].tier == "elite"
		and StitchedEnemyCatalog.trophy_for(catalog, spec.id) == spec.trophy, "AC1: canonical elite and trophy")
	for field in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(field) == profile[field], "AC1: normalized original stat " + field)
	var normalized: Array = []
	for raw in profile.abilities:
		var validated := StitchedParts.validate_ability(raw)
		_check(validated.get("ok", false), "AC1: independent exact ability validates: " + raw.id)
		if validated.get("ok", false):
			normalized.append(validated.ability)
	_check(foe.get("abilities") == normalized, "AC1: actual catalog normalizes both exact abilities")
	if normalized.size() == 2:
		_check(normalized[1].launch_mask == StitchedParts.rank_mask([1, 3])
			and normalized[1].target_mask == StitchedParts.rank_mask([1, 2, 3, 4]),
			"AC1: normalized masks preserve the original authored launch and target arrays")


func _battle(catalog: Dictionary, spec: Dictionary, seed_value: int, count: int) -> StitchedRules:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(preview is Dictionary, "real S2 hero/part preview exists")
	if not preview is Dictionary:
		return null
	var ids: Array = [spec.id, "scissor_crab"]
	if count == 3:
		ids.append("moth_scribe")
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, enemy_id)
		_check(not foe.is_empty(), "canonical foe exists: " + enemy_id)
		foes.append(foe)
	var parts: Array = preview.parts.duplicate(true)
	parts.append_array(catalog.parts)
	var created := StitchedRules.create({"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": preview.heroes.duplicate(true), "parts": parts, "foes": foes})
	_check(created.get("ok", false), "canonical seeded battle creates: " + str(created.get("error")))
	if not created.get("ok", false):
		return null
	var battle: StitchedRules = created.battle
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == count, "AC2: real four-hero/foe group")
	for index in range(count):
		var foe := battle.get_unit(ids[index])
		_check(foe.rank == index + 1 and foe.hp == foe.max_hp and foe.hp > 0 and not foe.dead
			and foe.statuses.is_empty(), "AC2: living unbuffed foe in authored formation")
	return battle


func _reject(battle: StitchedRules, ability_id: String, rank: int, error: String, receipts: Array,
		hero_api: bool = false) -> void:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipt := battle.use_part(ability_id, rank) if hero_api else battle.use_foe_ability(ability_id, rank)
	_check(not receipt.get("ok", true) and receipt.get("error") == error
		and before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: rejection preserves complete state/RNG/action: " + error)
	receipts.append(receipt)


func _reach(battle: StitchedRules, actor_id: String, round_value: int, buff_id: String, receipts: Array) -> bool:
	for step in range(32):
		if battle.current_actor_id() == actor_id and battle.round_number() == round_value:
			return true
		if battle.round_number() > round_value or battle.is_over():
			break
		var actor := battle.get_unit(battle.current_actor_id())
		if actor.side == "hero":
			_reject(battle, buff_id, 1, "it is not a foe turn", receipts)
		elif actor.id != actor_id:
			_reject(battle, buff_id, 1, "the foe has no ability " + buff_id, receipts)
		var receipt := battle.pass_turn()
		_check(receipt.get("ok", false), "advance real turns by legal public pass")
		receipts.append(receipt)
	_check(false, "must reach round %d actor %s" % [round_value, actor_id])
	return false


func _project(battle: StitchedRules, spec: Dictionary, count: int) -> Dictionary:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(spec.id))
	var ranks: Array = [1, 2, 3] if count == 3 else [1, 2]
	_check(intent.get("ability_id") == spec.buff and intent.get("ability_name") == spec.buff_name
		and intent.get("ability_kind") == "buff" and intent.get("multi") == true and not intent.get("pass", true)
		and intent.get("target_side") == "foe" and intent.get("target_rank") == 1
		and intent.get("affected_ranks") == ranks and intent.get("base_acc") == 100
		and intent.get("base_damage") == [0, 0] and intent.get("base_effects") == {"thorns": spec.thorns},
		"AC4: round-2 intent projects exact multi ally buff on occupied foe ranks")
	_check(before == battle.state_snapshot() and rng == battle.rng_state(), "AC4: projection is state/RNG read-only")
	var edited := intent.duplicate(true)
	edited.base_effects.thorns = 99
	edited.affected_ranks.append(4)
	_check(StitchedFoeIntent.choose(battle, battle.get_unit(spec.id)) == intent
		and before == battle.state_snapshot() and rng == battle.rng_state(), "AC4: projection data cannot mutate live kit")
	return intent


func _script(catalog: Dictionary, spec: Dictionary, seed_value: int, count: int, protected: bool = true) -> Dictionary:
	var battle := _battle(catalog, spec, seed_value, count)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _reach(battle, spec.id, 1, spec.buff, receipts):
		return {}
	var first := StitchedFoeIntent.choose(battle, battle.get_unit(spec.id))
	_check(first.get("ability_id") == _attack(spec).id, "AC4: round 1 keeps original attack rotation")
	receipts.append(battle.pass_turn())
	if not _reach(battle, spec.id, 2, spec.buff, receipts):
		return {}
	_check(battle.get_unit(spec.id).rank == 1, "AC2: round-2 caster occupies rank 1")
	var intent := _project(battle, spec, count)
	for rank in [0, 5]:
		_reject(battle, spec.buff, rank, "no legal target in rank %d" % rank, receipts)
	_reject(battle, "not_an_authored_ability", 1, "the foe has no ability not_an_authored_ability", receipts)
	_reject(battle, "warden_head_iron_helm", 1, "it is not a hero turn", receipts, true)
	var foes_before := battle.get_foes().duplicate(true)
	var heroes_before := battle.get_heroes().duplicate(true)
	for foe in foes_before:
		_check(foe.statuses.is_empty() and foe.hp == foe.max_hp, "AC2: every target still alive and unbuffed on caster turn")
	var buff := battle.use_foe_ability(spec.buff, 4) if protected else battle.pass_turn()
	receipts.append(buff)
	_check(buff.get("ok", false), "AC2: legal round-2 action commits after rejected attempts")
	var full_line := true
	if protected:
		_check(buff.get("actor") == spec.id and buff.get("ability") == spec.buff
			and buff.get("results", []).size() == count, "AC2: empty selected rank 4 resolves exactly the occupied allies")
		var targets: Array = []
		for hit in buff.get("results", []):
			targets.append(hit.target)
			_check(hit.target_side == "foe" and hit.target_rank >= 1 and hit.target_rank <= count
				and hit.hit and not hit.crit and hit.damage == 0
				and hit.statuses == [{"status": "thorns", "duration": spec.thorns}], "AC2: exact no-damage thorn receipt per ally")
		for old in foes_before:
			var now := battle.get_unit(old.id)
			# Public ability use enters the next actor's turn, ticking that actor's statuses once.
			var expected := int(spec.thorns) - (1 if battle.current_actor_id() == old.id else 0)
			_check(targets.count(old.id) == 1 and now.statuses == {"thorns": expected}
				and now.hp == old.hp and now.rank == old.rank and not now.dead,
				"AC2: actual ally snapshot has exact Thorns with only its own turn tick; HP/rank unchanged")
			full_line = full_line and now.statuses.thorns == spec.thorns
		_check(battle.get_heroes() == heroes_before and battle.get_foes().size() == count
			and not buff.has("self_move"), "AC2: heroes unchanged, no phantom foe, no caster movement")
	var buff_state := battle.state_snapshot()
	# Warden's real equipped head attack can hit rank-2 Scissor Crab and has no self-damage.
	for step in range(16):
		if battle.current_actor_id() == "warden":
			break
		var passed := battle.pass_turn()
		_check(passed.get("ok", false), "AC3: public turns reach Warden after the buff")
		receipts.append(passed)
	_check(battle.current_actor_id() == "warden", "AC3: real Warden attack turn reached")
	var attacker := battle.get_unit("warden")
	var target := battle.get_unit("scissor_crab")
	var thorns := int(target.statuses.get("thorns", 0))
	_check(attacker.rank == 1 and attacker.prot > 0 and attacker.hp > spec.thorns
		and target.rank == 2 and target.hp == target.max_hp and not target.dead,
		"AC3: healthy armoured attacker and living protected ally, not caster")
	_check(thorns > 0 if protected else thorns == 0, "AC3: positive protection versus unbuffed control")
	var attack := battle.use_part("warden_head_iron_helm", 2)
	receipts.append(attack)
	_check(attack.get("ok", false) and attack.get("results", []).size() == 1, "AC3: genuine equipped hero attack resolves")
	if not attack.get("ok", false) or attack.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = attack.results[0]
	var after := battle.get_unit("warden")
	var foe_after := battle.get_unit("scissor_crab")
	_check(hit.target == "scissor_crab" and hit.hit == (hit.roll <= hit.hit_chance)
		and foe_after.hp > 0 and not foe_after.dead, "AC3: natural hit/miss roll against a surviving protected ally")
	if hit.hit:
		_check(hit.damage > 0 and foe_after.hp == target.hp - hit.damage, "AC3: landed attack really damages the ally")
		if protected:
			_check(hit.get("thorns") == thorns and after.hp == attacker.hp - thorns,
				"AC3: confirmed hit returns exactly current Thorns despite attacker PROT")
		else:
			_check(not hit.has("thorns") and after.hp == attacker.hp, "AC3: landed unbuffed control has no return damage")
	else:
		_check(not hit.has("thorns") and hit.damage == 0 and foe_after.hp == target.hp and after.hp == attacker.hp,
			"AC3: natural miss carries no Thorns or HP damage")
	return {"receipts": receipts, "intent": intent, "buff_state": buff_state, "state": battle.state_snapshot(),
		"rng": battle.rng_state(), "hit": hit.hit, "thorns": thorns, "full_line": full_line}


func _test_line_and_replay(catalog: Dictionary, spec: Dictionary) -> void:
	for count in [3, 2]:
		var exact_line := false
		for seed_value in [3, 17]:
			var first := _script(catalog, spec, seed_value, count)
			var replay := _script(catalog, spec, seed_value, count)
			_check(not first.is_empty() and first == replay, "AC4: fixed-seed actions/receipts/snapshots/RNG replay identically")
			exact_line = exact_line or first.get("full_line", false)
		# Find an initiative order where the next actor is a hero so all post-buff counts remain exact.
		for seed_value in range(1, 65):
			if exact_line:
				break
			exact_line = _script(catalog, spec, seed_value, count).get("full_line", false)
		_check(exact_line, "AC2: non-vacuous %d-foe snapshot with every ally at exactly authored Thorns" % count)


func _test_reactions(catalog: Dictionary, spec: Dictionary) -> void:
	var hit_seed := 0
	var miss_seed := 0
	for seed_value in range(1, 65):
		var result := _script(catalog, spec, seed_value, 3)
		if result.is_empty() or result.thorns != spec.thorns:
			continue
		if result.hit and hit_seed == 0:
			hit_seed = seed_value
		elif not result.hit and miss_seed == 0:
			miss_seed = seed_value
		if hit_seed > 0 and miss_seed > 0:
			break
	_check(hit_seed > 0 and miss_seed > 0, "AC3: bounded search finds both full-amount hit and genuine miss witnesses: " + spec.buff)
	for seed_value in [hit_seed, miss_seed]:
		if seed_value == 0:
			continue
		var protected := _script(catalog, spec, seed_value, 3)
		var control := _script(catalog, spec, seed_value, 3, false)
		_check(not control.is_empty() and protected.hit == control.hit and control.thorns == 0,
			"AC3: matched seeded unbuffed control preserves hit outcome without retaliation")
		print(spec.buff, " ", "hit" if protected.hit else "miss", " witness seed=", seed_value)
