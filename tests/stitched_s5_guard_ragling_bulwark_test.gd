extends SceneTree
## Canonical Guard Ragling: its self-Thorns move works from either legal launch rank,
## rejects wrong self-targets / illegal launches without spending turns or RNG, and
## answers an actual equipped-hero strike in a seeded four-doll battle.

const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const STARTER_PATH := "res://data/enemies/starter_enemies.json"
const SEED := 59622

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_guard_ragling_bulwark_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _run() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: authentic S5 foe/part catalogs load: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		_finish()
		return
	_test_source_contract(catalog)
	_test_front_rank(catalog)
	var first := _rank_two_trial(catalog)
	var replay := _rank_two_trial(catalog)
	_check(not first.is_empty() and first == replay,
		"AC3: identical seed, natural turns, legal action, refusal, damage, RNG and final snapshots replay exactly")
	_test_illegal_launch(catalog)
	_finish()


func _test_source_contract(catalog: Dictionary) -> void:
	var raw: Variant = _read_json(STARTER_PATH)
	_check(raw is Array and not (raw as Array).is_empty(), "AC1: source starter catalog parses")
	if not raw is Array:
		return
	var guard: Dictionary = {}
	var ragling: Dictionary = {}
	for entry in raw:
		if not entry is Dictionary:
			continue
		if str(entry.get("id", "")) == "ragling_guard":
			guard = entry
		elif str(entry.get("id", "")) == "ragling":
			ragling = entry
	_check(not guard.is_empty() and not ragling.is_empty(),
		"AC1: both originally named starter records remain")
	if guard.is_empty():
		return
	var profile: Dictionary = guard.get("stitched", {})
	var actions: Array = profile.get("abilities", [])
	var expected := {
		"id": "button_bulwark", "name": "Button Bulwark", "kind": "buff",
		"launch": [1, 2], "target": [1, 2], "target_side": "self",
		"multi": false, "acc": 100, "dmg": [0, 0], "crit": 0,
		"effects": {"thorns": 2}, "self_move": 0, "move": "skill",
	}
	_check(guard.get("name") == "Guard Ragling" and guard.get("max_hp") == 12
		and guard.get("art_path") == "res://assets/paper/enemies/ragling_guard.png"
		and guard.get("intent", {}).get("target") == "front"
		and guard.get("intent", {}).get("actions", []).size() == 4,
		"AC1: legacy Guard Ragling name, HP, art and four intent actions survive")
	_check(profile.get("max_hp") == 12 and profile.get("speed") == 3
		and profile.get("dodge") == 4 and profile.get("acc") == 0
		and profile.get("prot") == 6 and profile.get("is_boss") == false
		and profile.get("turns_per_round") == 1
		and profile.get("trophy") == "ragling_guard_button_plate",
		"AC1: every other Guard Ragling Stitched profile field is intact")
	var padding: Dictionary = actions[0] if not actions.is_empty() else {}
	_check(actions.size() == 2 and str(padding.get("id", "")) == "padding_bash"
		and JSON.stringify(padding.get("launch", [])) == JSON.stringify(JSON.parse_string("[1,2]"))
		and JSON.stringify(padding.get("target", [])) == JSON.stringify(JSON.parse_string("[1]"))
		and int(padding.get("effects", {}).get("exposed", 0)) == 1
		and JSON.stringify(padding.get("dmg", [])) == JSON.stringify(JSON.parse_string("[3,4]")),
		"AC1: existing Padding Bash keeps its slot and unchanged combat fields")
	# JSON.parse_string produces float values for source numbers, unlike GDScript int literals.
	var expected_from_json: Dictionary = JSON.parse_string(JSON.stringify(expected))
	_check(actions.size() >= 2 and actions[1] == expected_from_json,
		"AC1: authored Button Bulwark matches the previous exact fields except target [1,2]")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "ragling_guard")
	var validated := StitchedParts.validate_ability(expected)
	_check(not foe.is_empty() and bool(validated.get("ok", false))
		and foe.get("abilities", []).size() == 2
		and foe["abilities"][1] == validated.get("ability")
		and StitchedParts.ranks_allowed(int(foe["abilities"][1]["target_mask"]), 2),
		"AC1: canonical loader publishes the precise new Button Bulwark rank-2 self-target")
	_check(not ragling.is_empty() and ragling.get("name") == "Ragling"
		and ragling.get("stitched", {}).get("abilities", []).size() == 2
		and str(ragling["stitched"]["abilities"][0].get("id", "")) == "rag_rake"
		and str(ragling["stitched"]["abilities"][1].get("id", "")) == "loose_thread",
		"AC1: earlier Ragling actions remain named and present")


func _battle(catalog: Dictionary, enemy_ids: Array, seed_value: int) -> StitchedRules:
	var preview: Variant = _read_json(PREVIEW_PATH)
	_check(preview is Dictionary, "AC2: canonical four-hero preview exists")
	if not preview is Dictionary:
		return null
	var config: Dictionary = preview
	var foes: Array = []
	for enemy_id in enemy_ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id))
		_check(not foe.is_empty(), "AC2: foe_for resolves " + str(enemy_id))
		if foe.is_empty():
			return null
		foes.append(foe)
	var parts: Array = catalog["parts"].duplicate(true)
	parts.append_array(config["parts"].duplicate(true))
	var created := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": config["heroes"].duplicate(true), "parts": parts, "foes": foes,
	})
	_check(bool(created.get("ok", false)),
		"AC2: public StitchedRules.create accepts real preview heroes and canonical foes: "
		+ str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == enemy_ids.size()
		and battle.outcome() == "ongoing", "AC2: all four real heroes and requested foes are alive")
	return battle


func _drive_to(battle: StitchedRules, target_id: String) -> bool:
	for step in range(24):
		if battle.is_over():
			return false
		if battle.current_actor_id() == target_id:
			return true
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			return false
	return false


func _test_front_rank(catalog: Dictionary) -> void:
	var battle := _battle(catalog, ["ragling_guard", "ragling"], SEED + 1)
	if battle == null:
		return
	_check(int(battle.get_unit("ragling_guard").get("rank", 0)) == 1,
		"AC1: front-rank Guard starts at legal rank 1")
	var reached := _drive_to(battle, "ragling_guard")
	_check(reached, "AC1: public pass_turn advances to the front-rank Guard's own turn")
	if not reached:
		return
	var receipt := battle.use_foe_ability("button_bulwark", 1)
	_check(bool(receipt.get("ok", false)) and receipt.get("actor") == "ragling_guard"
		and receipt.get("ability") == "button_bulwark"
		and receipt.get("results", []).size() == 1
		and receipt.get("results", [])[0].get("target") == "ragling_guard",
		"AC1: Guard legitimately casts its self-buff from rank 1")
	_check(int(battle.get_unit("ragling_guard").get("statuses", {}).get("thorns", 0)) == 2,
		"AC1: rank-1 casting still grants real Thorns 2")


func _rank_two_trial(catalog: Dictionary) -> Dictionary:
	var battle := _battle(catalog, ["ragling", "ragling_guard"], SEED)
	if battle == null:
		return {}
	_check(int(battle.get_unit("ragling_guard").get("rank", 0)) == 2,
		"AC2: Guard actually occupies foe rank 2 behind a canonical Ragling")
	var initial := battle.state_snapshot()
	var reached := _drive_to(battle, "ragling_guard")
	_check(reached, "AC2: natural initiative/pass_turn reaches rank-2 Guard's own action")
	if not reached:
		return {}
	_check(battle.current_side() == "foe"
		and int(battle.get_unit("ragling_guard").get("hp", 0)) > 0,
		"AC2: a living rank-2 Guard owns the turn rather than a synthetic target")
	var before_refusal := battle.state_snapshot()
	var rng_before_refusal := battle.rng_state()
	var refused := battle.use_foe_ability("button_bulwark", 1)
	_check(refused.get("ok") == false and refused.get("actor") == "ragling_guard"
		and str(refused.get("error", "")).contains("no legal target"),
		"AC3: rank-2 Guard may not self-target another rank, even one on the allowed mask")
	_check(battle.state_snapshot() == before_refusal
		and battle.rng_state() == rng_before_refusal
		and battle.current_actor_id() == "ragling_guard",
		"AC3: refused wrong-rank target spends no turn, RNG or any battle state")
	var cast := battle.use_foe_ability("button_bulwark", 2)
	_check(cast.get("ok") == true and cast.get("actor") == "ragling_guard"
		and cast.get("ability") == "button_bulwark" and cast.get("results", []).size() == 1,
		"AC2: rank-2 Guard spends its own foe turn casting the canonical Bulwark")
	if not bool(cast.get("ok", false)) or cast.get("results", []).is_empty():
		return {}
	var buff: Dictionary = cast["results"][0]
	_check(buff.get("target") == "ragling_guard" and buff.get("target_rank") == 2
		and buff.get("hit") == true and buff.get("statuses", []).has(
			{"status": "thorns", "duration": 2}),
		"AC2: successful self-target receipt confirms Thorns 2 on rank 2")
	_check(int(battle.get_unit("ragling_guard").get("statuses", {}).get("thorns", 0)) == 2,
		"AC2: rank-2 Guard has actual Thorns 2 state after its turn")
	var passes: Array = []
	var strike: Dictionary = {}
	var attacker_id := ""
	var attacker_hp := -1
	var target_hp := -1
	for step in range(20):
		if battle.is_over():
			break
		var actor_id := battle.current_actor_id()
		var actor := battle.get_unit(actor_id)
		var part_id := ""
		if actor_id == "warden":
			part_id = "warden_head_iron_helm"
		elif actor_id == "seamstress" or actor_id == "lantern_monk":
			part_id = "any_head_needle_pin"
		if str(actor.get("side", "")) == "hero" and not part_id.is_empty():
			var worn: Dictionary = actor.get("parts", {}).get("head", {})
			_check(str(worn.get("id", "")) == part_id and not bool(worn.get("torn", true)),
				"AC2 precondition: live striker has the correct intact equipped head part")
			_check(int(battle.get_unit("ragling_guard").get("rank", 0)) == 2
				and int(battle.get_unit("ragling_guard").get("statuses", {}).get("thorns", 0)) == 2,
				"AC2 precondition: rank-2 Guard remains living and actively thorned before impact")
			attacker_id = actor_id
			attacker_hp = int(actor.get("hp", 0))
			target_hp = int(battle.get_unit("ragling_guard").get("hp", 0))
			strike = battle.use_part(part_id, 2)
			break
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			break
		passes.append(passed)
	_check(not strike.is_empty() and bool(strike.get("ok", false))
		and strike.get("actor_side") == "hero" and strike.get("actor") == attacker_id
		and strike.get("target") == "ragling_guard" and strike.get("results", []).size() == 1,
		"AC2: authentic equipped hero makes a legal rank-2 ability attack after the buff")
	if not bool(strike.get("ok", false)) or strike.get("results", []).is_empty():
		return {}
	var hit: Dictionary = strike["results"][0]
	var guard_after := battle.get_unit("ragling_guard")
	_check(hit.get("target") == "ragling_guard" and hit.get("hit") == true
		and int(hit.get("damage", 0)) > 0 and target_hp > int(guard_after.get("hp", 0))
		and int(guard_after.get("hp", 0)) > 0 and not bool(guard_after.get("dead", false)),
		"AC2 precondition: real damage connects and Guard remains alive for retaliation")
	_check(int(hit.get("thorns", 0)) == 2
		and int(battle.get_unit(attacker_id).get("hp", -1)) == attacker_hp - 2,
		"AC2: the confirmed legal hero hit triggers exactly 2 actual retaliation HP damage")
	return {
		"initial": initial, "before_refusal": before_refusal, "refusal": refused,
		"cast": cast, "passes": passes, "strike": strike,
		"final": battle.state_snapshot(), "rng": battle.rng_state(),
	}


func _test_illegal_launch(catalog: Dictionary) -> void:
	var battle := _battle(catalog, ["ragling", "moth_scribe", "ragling_guard"], SEED + 2)
	if battle == null:
		return
	_check(int(battle.get_unit("ragling_guard").get("rank", 0)) == 3,
		"AC3: third canonical foe slot puts Guard at rank 3")
	var reached := _drive_to(battle, "ragling_guard")
	_check(reached, "AC3: real three-foe turn ordering reaches living rank-3 Guard")
	if not reached:
		return
	var before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var refused := battle.use_foe_ability("button_bulwark", 3)
	_check(refused.get("ok") == false and refused.get("actor") == "ragling_guard"
		and str(refused.get("error", "")).contains("cannot launch"),
		"AC3: Bulwark's launch rank 3 remains illegal even when targeting itself")
	_check(battle.state_snapshot() == before and battle.rng_state() == rng_before
		and battle.current_actor_id() == "ragling_guard",
		"AC3: rank-3 launch refusal consumes no turn, state or RNG")
