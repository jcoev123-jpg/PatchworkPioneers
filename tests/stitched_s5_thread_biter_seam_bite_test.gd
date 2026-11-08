extends SceneTree
## Canonical S5 foe data through the same catalog, chooser and rules used in battle.
## Bounded witness search uses only genuine turns; each selected schedule is replayed.
const SEED_FIRST := 1
const SEED_END := 65
const BITE := {"id": "thread_bite", "name": "Thread Bite", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 87, "dmg": [3, 5], "crit": 0, "effects": {"bleed": 1, "snip": 1},
	"self_move": 0, "move": "attack2"}
const LINT := {"id": "lint_spit", "name": "Lint Spit", "kind": "debuff",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [0, 0], "crit": 0, "effects": {"exposed": 1, "fray": 4},
	"self_move": 0, "move": "skill"}
var failures: Array[String] = []
var checks := 0
var catalog: Dictionary
var preview: Dictionary


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/stitched/s2_preview.json"))
	_check(catalog.get("ok", false) and parsed is Dictionary, "canonical catalog and preview load")
	if catalog.get("ok", false) and parsed is Dictionary:
		preview = parsed
		_contract()
		_witnesses()
		var first := _rotation(19)
		_check(first == _rotation(19), "AC4: three-round chooser schedule replays receipts/state/RNG")
	for failure in failures:
		printerr(failure)
	print("stitched_s5_thread_biter_seam_bite_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _record(records: Array, id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and record.get("id") == id:
			return record
	return {}


func _json_equal(actual: Variant, expected: Variant) -> bool:
	# JSON numbers are floats; normalize the independently written integer contracts too.
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))


func _contract() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	_check(raw is Array, "AC1: real enemy JSON is an array")
	if not raw is Array:
		return
	var biter := _record(raw, "thread_biter")
	var crab := _record(raw, "scissor_crab")
	_check(not biter.is_empty() and not crab.is_empty(), "AC1: named biter and untouched neighbor exist")
	if biter.is_empty() or crab.is_empty():
		return
	var expected_profile := {"max_hp": 15, "speed": 4, "dodge": 5, "acc": 0, "prot": 2,
		"is_boss": false, "turns_per_round": 1, "trophy": "thread_biter_lint_gland",
		"abilities": [BITE, LINT]}
	_check(_json_equal(biter.get("stitched"), expected_profile), "AC1: independent complete raw Stitched contract and move order")
	var legacy := biter.duplicate(true)
	legacy.erase("stitched")
	_check(_json_equal(legacy, {"id": "thread_biter", "name": "Thread Biter", "max_hp": 15, "drain": true,
		"art_path": "res://assets/paper/enemies/thread_biter.png", "intent": {
			"target": "lowest_living_hp", "actions": [{"type": "attack", "amount": 5, "weight": 2},
				{"type": "attack", "amount": 6, "weight": 1, "move": "attack2"},
				{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
				{"type": "block", "amount": 2, "weight": 1}]}}), "AC1: legacy record is unchanged")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "thread_biter")
	var expected_foe := expected_profile.duplicate(true)
	expected_foe.erase("trophy")
	expected_foe.merge({"id": "thread_biter", "name": "Thread Biter", "drain": true})
	for ability in expected_foe.abilities:
		ability["launch_mask"] = StitchedParts.rank_mask(ability.launch)
		ability["target_mask"] = StitchedParts.rank_mask(ability.target)
		ability["mark_damage"] = 0
	_check(foe == expected_foe, "AC1: foe_for preserves exact stats and both independently authored abilities")
	_check(StitchedEnemyCatalog.trophy_for(catalog, "thread_biter") == "thread_biter_lint_gland",
		"AC1: exact biter trophy is unchanged")
	var neighbor := StitchedEnemyCatalog.foe_for(catalog, "scissor_crab")
	_check(neighbor.get("max_hp") == 22 and neighbor.get("speed") == 5 and neighbor.get("dodge") == 6
		and neighbor.get("acc") == 0 and neighbor.get("prot") == 8 and neighbor.get("is_boss") == false
		and neighbor.get("turns_per_round") == 1 and crab.get("max_hp") == 26
		and StitchedEnemyCatalog.trophy_for(catalog, "scissor_crab") == "scissor_crab_claw_arm",
		"AC1: named neighbor's legacy HP, Stitched stats and trophy are unchanged")
	_check(neighbor.get("abilities", []).size() == 2
		and neighbor.abilities[0].id == "pinch" and neighbor.abilities[0].effects == {"bleed": 2}
		and neighbor.abilities[1].id == "thread_snip" and neighbor.abilities[1].effects == {"snip": 1},
		"AC1: named neighbor's authored effects and order are unchanged")


func _battle(seed_value: int) -> StitchedRules:
	var config := preview.duplicate(true)
	config.parts.append_array(catalog.parts)
	config.seed = seed_value
	config.candle = 100
	config.foes = [StitchedEnemyCatalog.foe_for(catalog, "thread_biter"),
		StitchedEnemyCatalog.foe_for(catalog, "ragling")]
	var made := StitchedRules.create(config)
	_check(made.get("ok", false), "real four-hero/two-canonical-foe battle builds: " + str(made.get("error")))
	if not made.get("ok", false):
		return null
	var b: StitchedRules = made.battle
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 2 and b.candle() == 100,
		"nonvacuous four occupied hero ranks, two foes and BRIGHT candle")
	for index in range(4):
		var hero := b.get_unit(str(preview.heroes[index].id))
		_check(hero.get("rank") == index + 1 and hero.get("hp", 0) > 0
			and hero.get("parts", {}).size() == 4, "real living hero with four preview parts at rank %d" % (index + 1))
	_check(b.get_unit("thread_biter").rank == 1 and b.get_unit("ragling").rank == 2,
		"canonical biter and ragling occupy foe ranks 1 and 2")
	return b


func _to(b: StitchedRules, actor: String, receipts: Array) -> bool:
	for step in range(30):
		if b.is_over():
			break
		if b.current_actor_id() == actor:
			return true
		var passed := b.pass_turn()
		receipts.append(passed)
		if not passed.get("ok", false):
			break
	_check(false, "bounded public pass_turn schedule reaches " + actor)
	return false


func _trace(seed_value: int, ability: String, target_rank: int) -> Dictionary:
	var b := _battle(seed_value)
	var receipts: Array = []
	if b == null or not _to(b, "thread_biter", receipts):
		return {}
	var target := "warden" if target_rank == 1 else "seamstress"
	var before := b.get_unit(target)
	var state := b.state_snapshot()
	var rng := b.rng_state()
	if ability == "lint_spit":
		var refused := b.use_foe_ability(ability, 4)
		receipts.append(refused)
		_check(not refused.get("ok", true) and b.current_actor_id() == "thread_biter"
			and b.state_snapshot() == state and b.rng_state() == rng,
			"AC3: occupied wrong rank 4 refuses with identical turn/state/RNG")
	var receipt := b.use_foe_ability(ability, target_rank)
	receipts.append(receipt)
	_check(receipt.get("ok", false) and receipt.get("results", []).size() == 1,
		"one genuine legal ability receipt")
	if not receipt.get("ok", false) or receipt.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = receipt.results[0]
	var after := b.get_unit(target)
	if not hit.hit:
		_check(hit.has("roll") and hit.roll > hit.hit_chance and hit.damage == 0
			and hit.statuses.is_empty() and not hit.has("snip") and not hit.has("fray_event")
			and after.hp == before.hp and after.statuses == before.statuses
			and after.fray == before.fray and b.thread_cuts().is_empty(),
			"AC4: real rolled miss has no damage/Bleed/Exposed/Fray/Snip: " + ability)
	elif ability == "lint_spit":
		_check(hit.target_rank == 2 and hit.damage == 0 and after.hp == before.hp
			and hit.statuses == [{"status": "exposed", "duration": 1}]
			and after.fray == before.fray + 4 and hit.get("fray_event", {}).get("change") == 4
			and not hit.has("snip") and b.thread_cuts().is_empty(),
			"AC3: landed rank-2 lint gives Exposed 1, exactly +4 Fray, no HP damage or cut")
	else:
		# Independent seeded draw prediction, never supplied to the battle's RNG.
		var oracle := RandomNumberGenerator.new()
		oracle.state = rng
		_check(oracle.randi_range(1, 100) == hit.roll, "AC2: seeded genuine hit roll")
		var critical := oracle.randi_range(1, 100) <= 5
		var base := 7 if critical else oracle.randi_range(3, 5)
		var expected_damage := base - int(base * mini(80, int(before.prot)) / 100.0)
		_check(hit.crit == critical and hit.damage == expected_damage and hit.damage > 0
			and hit.target_hp == before.hp - expected_damage
			and hit.statuses == [{"status": "bleed", "duration": 1}]
			and hit.get("snip", {}).get("ok", false) and hit.snip.after_rank == 1
			and b.thread_cuts() == {"warden": 1}, "AC2: seeded post-PROT damage, Bleed 1 and actual front cut")
	return {"hit": hit.hit, "retained_status": after.statuses.get("bleed" if ability == "thread_bite" else "exposed", 0),
		"receipts": receipts, "state": b.state_snapshot(), "rng": b.rng_state(), "battle": b}


func _witnesses() -> void:
	for action in [["thread_bite", 1], ["lint_spit", 2]]:
		var hit_seed := 0
		var miss_seed := 0
		for seed_value in range(SEED_FIRST, SEED_END):
			var trace := _trace(seed_value, action[0], action[1])
			if trace.is_empty():
				return
			if trace.hit and trace.retained_status == 1 and hit_seed == 0:
				hit_seed = seed_value
			if not trace.hit and miss_seed == 0:
				miss_seed = seed_value
			if hit_seed > 0 and miss_seed > 0:
				break
		_check(hit_seed > 0 and miss_seed > 0, "nonvacuous landed status and separate real miss: " + str(action[0]))
		print(action[0], " witness seeds: hit=", hit_seed, ", miss=", miss_seed)
		for seed_value in [hit_seed, miss_seed]:
			if seed_value == 0:
				continue
			var first := _trace(seed_value, action[0], action[1])
			var replay := _trace(seed_value, action[0], action[1])
			first.erase("battle")
			replay.erase("battle")
			_check(first == replay, "AC4: selected hit/miss schedule exactly replays receipts/state/RNG")
	# Keep the first cut until another landed bite, then repair it on its owner's turn.
	var repeated_seed := 0
	for seed_value in range(SEED_FIRST, SEED_END):
		var first := _cut_cycle(seed_value)
		if not first.is_empty():
			repeated_seed = seed_value
			_check(first == _cut_cycle(seed_value), "AC2/4: repeated bite, refusal, RE-TIE and restored move replay exactly")
			break
	_check(repeated_seed > 0, "AC2: nonvacuous repeated landed bite and RE-TIE witness")
	print("repeat bite/RE-TIE witness seed: ", repeated_seed)


func _cut_cycle(seed_value: int) -> Dictionary:
	var trace := _trace(seed_value, "thread_bite", 1)
	if trace.is_empty() or not trace.hit:
		return {}
	var b: StitchedRules = trace.battle
	var receipts: Array = trace.receipts
	if not _to(b, "thread_biter", receipts):
		return {}
	var second := b.use_foe_ability("thread_bite", 1)
	receipts.append(second)
	_check(second.get("ok", false) and second.get("results", []).size() == 1, "AC2: repeated bite executes on genuine next foe turn")
	if not second.get("ok", false) or second.results.is_empty() or not second.results[0].hit:
		return {}
	_check(not second.results[0].snip.ok and b.thread_cuts() == {"warden": 1},
		"AC2: repeated landed bite cannot duplicate an existing cut")
	if not _to(b, "warden", receipts):
		return {}
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var blocked := b.move(1)
	receipts.append(blocked)
	_check(not blocked.get("ok", true) and b.state_snapshot() == before and b.rng_state() == rng,
		"AC2: cut hero's cross-cut move rejects atomically without RNG draw")
	var repaired := b.re_tie()
	receipts.append(repaired)
	_check(repaired.get("ok", false) and repaired.get("actor") == "warden"
		and b.thread_cuts().is_empty() and b.current_actor_id() != "warden",
		"AC2: owner's RE-TIE clears cut and consumes its turn")
	if not _to(b, "warden", receipts):
		return {}
	var restored := b.move(1)
	receipts.append(restored)
	_check(restored.get("ok", false), "AC2: repaired thread permits the same move on next own turn")
	return {"receipts": receipts, "state": b.state_snapshot(), "rng": b.rng_state()}


func _rotation(seed_value: int) -> Dictionary:
	var b := _battle(seed_value)
	var receipts: Array = []
	var seen: Array = []
	if b == null:
		return {}
	for round_value in range(1, 4):
		if not _to(b, "thread_biter", receipts):
			return {}
		_check(b.round_number() == round_value, "AC4: genuine natural round %d" % round_value)
		var before := b.state_snapshot()
		var intent := StitchedFoeIntent.choose(b, b.get_unit("thread_biter"))
		var authored: Dictionary = BITE if round_value != 2 else LINT
		_check(not intent.get("pass", true) and intent.get("ability_id") == authored.id
			and intent.get("ability_name") == authored.name and intent.get("ability_kind") == authored.kind
			and intent.get("target_rank") == 1 and intent.get("target_side") == "hero"
			and intent.get("affected_ranks") == [1] and intent.get("multi") == false
			and intent.get("base_acc") == authored.acc and intent.get("base_damage") == authored.dmg
			and intent.get("base_crit") == authored.crit and intent.get("base_effects") == authored.effects
			and b.state_snapshot() == before, "AC4: read-only exact round-rotated authored BASE intent")
		var executed := b.use_foe_ability(str(intent.get("ability_id", "")), int(intent.get("target_rank", 0)))
		_check(executed.get("ok", false) and executed.get("ability") == authored.id
			and executed.get("results", []).size() == 1, "AC4: advertised action executes through real rules")
		receipts.append(executed)
		seen.append(executed.get("ability"))
	_check(seen == ["thread_bite", "lint_spit", "thread_bite"], "AC4: three observed round intents execute Bite/Lint/Bite")
	return {"receipts": receipts, "state": b.state_snapshot(), "rng": b.rng_state()}
