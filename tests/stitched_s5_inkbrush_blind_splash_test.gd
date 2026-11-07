extends SceneTree
## S5 Inkbrush Imp rear-rank Blinding Ink splash.
##
## The shipped run roster's single Inkbrush Imp changes one authored action: Blinding Ink now reaches
## hero ranks 2/3/4 with independent rolls and applies Blind 1 only on a hit, while Ink Lash stays the
## single-target Exposed opener. Everything is exercised through the real StitchedEnemyCatalog, the
## real StitchedFoeIntent projection and StitchedRules' public turns (pass_turn, use_foe_ability,
## use_part) on the real four-doll preview party with button_guard rank 1, the Imp rank 2 and ragling
## rank 3. Per-ID source lookups only: no catalog total or ordered all-ID list.

const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const IMP := "inkbrush_imp"
const GUARD := "button_guard"
const RAGLING := "ragling"
const SEED_LIMIT := 24
const TURN_LIMIT := 96

const INK_LASH := {
	"id": "ink_lash", "name": "Ink Lash", "kind": "ranged",
	"launch": [2, 3, 4], "target": [1, 3], "target_side": "enemy", "multi": false,
	"acc": 87, "dmg": [3, 4], "crit": 0, "effects": {"exposed": 1},
	"self_move": 0, "move": "attack2",
}
const BLINDING_INK := {
	"id": "blinding_ink", "name": "Blinding Ink", "kind": "debuff",
	"launch": [2, 3, 4], "target": [2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 88, "dmg": [0, 0], "crit": 0, "effects": {"blind": 1},
	"self_move": 0, "move": "skill",
}
const LEGACY := {"target": "lowest_living_hp", "actions": [
	{"type": "debuff", "amount": 2, "status": "exposed", "weight": 2},
	{"type": "attack", "amount": 6, "weight": 3},
	{"type": "debuff", "amount": 1, "status": "blind_next_attack", "weight": 2},
	{"type": "attack", "amount": 7, "move": "attack2", "weight": 1},
	{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1},
]}
const PROFILE := {
	"max_hp": 23, "speed": 5, "dodge": 9, "acc": 0, "prot": 0,
	"is_boss": false, "turns_per_round": 1, "trophy": "inkbrush_imp_ink_horn",
	"abilities": [INK_LASH, BLINDING_INK],
}

var failures: Array[String] = []
var checks := 0
var _catalog: Dictionary = {}
var _preview: Dictionary = {}
var _parts_by_id: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"the real enemy catalog loads: " + str(_catalog.get("error", "")))
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_preview = preview if preview is Dictionary else {}
	_check(not _preview.is_empty() and _preview.get("heroes", []).size() == 4,
		"the shipped preview authors the real four-doll party")
	if not bool(_catalog.get("ok", false)) or _preview.is_empty():
		_finish()
		return
	for part in _preview.get("parts", []):
		if part is Dictionary:
			_parts_by_id[str(part.get("id", ""))] = part
	for part in _catalog.get("parts", []):
		if part is Dictionary:
			_parts_by_id[str(part.get("id", ""))] = part
	_test_source()
	_test_rejections()
	_test_imp_turn_refusals()
	var witnesses := _scan_seeds()
	if int(witnesses.get("combined", -1)) > 0:
		_test_blinding_cast(int(witnesses["combined"]))
		_test_blind_consequence(int(witnesses["combined"]))
		await _test_live_driver(int(witnesses["combined"]))
	_test_absent_rear_rank()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_inkbrush_blind_splash_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _ability_of(unit: Dictionary, ability_id: String) -> Dictionary:
	for ability in unit.get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


# ---------------------------------------------------------------- fixtures

func _config(seed_value: int, heroes: Array = []) -> Dictionary:
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var party: Array = heroes.duplicate(true) if not heroes.is_empty() \
		else _preview["heroes"].duplicate(true)
	var foes: Array = []
	for enemy_id in [GUARD, IMP, RAGLING]:
		foes.append(StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id)))
	return {
		"mode": "stitched",
		"seed": seed_value,
		"candle": 100,
		"heroes": party,
		"parts": parts,
		"foes": foes,
	}


func _make_battle(seed_value: int, heroes: Array = []) -> StitchedRules:
	var config := _config(seed_value, heroes)
	for foe in config["foes"]:
		if foe is Dictionary and foe.is_empty():
			_check(false, "the real catalog resolves button_guard, inkbrush_imp and ragling")
			return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)),
		"real seeded 4v3 battle creates for seed %d: %s"
			% [seed_value, str(created.get("error", ""))])
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
		and int(battle.get_unit(IMP)["rank"]) == 2
		and int(battle.get_unit(GUARD)["rank"]) == 1
		and int(battle.get_unit(RAGLING)["rank"]) == 3,
		"button_guard rank 1, Inkbrush Imp rank 2 and ragling rank 3 are the real foe ranks")
	return battle


## One real turn: hero PASS, otherwise the foe's own authoritative legal action.
func _step(battle: StitchedRules) -> Dictionary:
	if battle.is_over():
		return {"ok": false, "error": "the battle is over"}
	if battle.current_side() == "hero":
		return battle.pass_turn()
	var actor := battle.get_unit(battle.current_actor_id())
	var intent := StitchedFoeIntent.choose(battle, actor)
	if intent.is_empty() or bool(intent.get("pass", true)):
		return battle.pass_turn()
	return battle.use_foe_ability(str(intent["ability_id"]), int(intent["target_rank"]))


## Advance real public turns until the requested actor holds its turn in the requested round.
func _advance(battle: StitchedRules, target_round: int, actor_id: String, receipts: Array) -> bool:
	for step in range(TURN_LIMIT):
		if battle.is_over():
			return false
		if battle.round_number() > target_round:
			return false
		if battle.round_number() == target_round and battle.current_actor_id() == actor_id:
			return true
		var receipt := _step(battle)
		if not bool(receipt.get("ok", false)):
			return false
		receipts.append(receipt)
	return false


func _hero_at(battle: StitchedRules, rank: int) -> Dictionary:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return hero
	return {}


# ---------------------------------------------------------------- AC1 the one authored change

func _test_source() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN))
	_check(parsed is Array, "AC1: " + RUN + " parses as a JSON array")
	if not parsed is Array:
		return
	var matches: Array = parsed.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and str(entry.get("id", "")) == IMP)
	_check(matches.size() == 1, "AC1: exactly one shipped Inkbrush Imp record")
	if matches.size() != 1:
		return
	var imp: Dictionary = matches[0]
	_check(str(imp.get("name", "")) == "Inkbrush Imp" and int(imp.get("max_hp", 0)) == 23
		and str(imp.get("art_path", "")) == "res://assets/paper/enemies/inkbrush_imp.png",
		"AC1: Imp name, HP 23 and sprite path stay exact")
	_check(imp.get("intent") == _json(LEGACY),
		"AC1: the entire legacy weighted intent (Exposed 2, attacks, Blind 1) stays exact")
	_check(imp.get("stitched") == _json(PROFILE),
		"AC1: the exact Stitched profile keeps its stats, trophy, Ink Lash then Blinding Ink")
	var abilities: Array = imp.get("stitched", {}).get("abilities", [])
	_check(abilities.size() == 2 and str(abilities[0].get("id", "")) == "ink_lash"
		and str(abilities[1].get("id", "")) == "blinding_ink",
		"AC1: Ink Lash stays the opener and Blinding Ink stays the second action")
	if abilities.size() == 2:
		_check(abilities[0] == _json(INK_LASH),
			"AC1: Ink Lash keeps its exact record beside the changed action")
		_check(abilities[1] == _json(BLINDING_INK),
			"AC1: Blinding Ink's only change is target [2,3,4] and multi true")
	# Independent validation of the authored result, not an echo of the loader.
	var lash := StitchedParts.validate_ability(INK_LASH)
	_check(bool(lash.get("ok", false)), "AC1: unchanged Ink Lash still validates")
	var ink := StitchedParts.validate_ability(BLINDING_INK)
	_check(bool(ink.get("ok", false)), "AC1: Blinding Ink validates as a StitchedParts ability")
	if bool(lash.get("ok", false)):
		var lash_ability: Dictionary = lash["ability"]
		_check(lash_ability.get("target") == [1, 3]
			and int(lash_ability.get("target_mask", 0)) == StitchedParts.rank_mask([1, 3])
			and not bool(lash_ability.get("multi", true))
			and lash_ability.get("dmg") == [3, 4]
			and lash_ability.get("effects") == {"exposed": 1},
			"AC1: Ink Lash remains single-target [1,3] for 3-4 with Exposed 1")
	if bool(ink.get("ok", false)):
		var ink_ability: Dictionary = ink["ability"]
		_check(ink_ability.get("target") == [2, 3, 4]
			and int(ink_ability.get("target_mask", 0)) == StitchedParts.rank_mask([2, 3, 4])
			and int(ink_ability.get("launch_mask", 0)) == StitchedParts.rank_mask([2, 3, 4])
			and bool(ink_ability.get("multi", false))
			and ink_ability.get("kind") == "debuff"
			and int(ink_ability.get("acc", -1)) == 88
			and ink_ability.get("dmg") == [0, 0]
			and ink_ability.get("effects") == {"blind": 1}
			and str(ink_ability.get("move", "")) == "skill",
			"AC1: validated Blinding Ink reaches rear ranks 2/3/4 as a multi 0-damage Blind")
		for rank in range(0, 6):
			_check(StitchedParts.ranks_allowed(int(ink_ability["target_mask"]), rank)
				== (rank in [2, 3, 4]),
				"AC1: Blinding Ink target mask admits only hero rank %d" % rank)
	# The canonical loader exposes exactly the same normalized kit.
	var foe := StitchedEnemyCatalog.foe_for(_catalog, IMP)
	_check(not foe.is_empty(), "AC1: the real catalog still resolves inkbrush_imp")
	if not foe.is_empty():
		_check(str(foe.get("name", "")) == "Inkbrush Imp"
			and int(foe.get("max_hp", 0)) == 23 and int(foe.get("speed", -1)) == 5
			and int(foe.get("dodge", -1)) == 9 and int(foe.get("acc", -1)) == 0
			and int(foe.get("prot", -1)) == 0 and not bool(foe.get("is_boss", true))
			and int(foe.get("turns_per_round", 0)) == 1,
			"AC1: the loaded foe keeps the exact shipped stats and one turn")
		_check(StitchedEnemyCatalog.trophy_for(_catalog, IMP) == "inkbrush_imp_ink_horn",
			"AC1: the Imp keeps its authored ink horn trophy")
		if bool(lash.get("ok", false)) and bool(ink.get("ok", false)):
			_check(foe.get("abilities") == [lash["ability"], ink["ability"]],
				"AC1: the loader publishes exactly the validated Ink Lash then Blinding Ink kit")
		var loaded := _ability_of(foe, "blinding_ink")
		_check(not loaded.is_empty() and loaded.get("target") == [2, 3, 4]
			and bool(loaded.get("multi", false)) and loaded.get("effects") == {"blind": 1}
			and loaded.get("dmg") == [0, 0] and loaded.get("acc") == 88,
			"AC1: foe_for exposes the normalized rear-rank Blind record")
		_check(not bool(_ability_of(foe, "ink_lash").get("multi", true))
			and _ability_of(foe, "ink_lash").get("target") == [1, 3],
			"AC1: the change never leaks onto the Ink Lash opener")
	_check(str(_catalog.get("enemies", {}).get(IMP, {}).get("tier", "")) == "normal",
		"AC1: the Imp remains a normal-tier canonical foe")
	# A named earlier source foe stays in the roster; no catalog total or full ID order is asserted.
	_check(not StitchedEnemyCatalog.foe_for(_catalog, GUARD).is_empty(),
		"AC1: the earlier button_guard source foe stays present")


# ---------------------------------------------------------------- AC2 the seeded live cast

## Walk a fresh real battle to the Imp's round-two turn and commit Blinding Ink at the projected rank.
func _cast_trace(seed_value: int) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _advance(battle, 2, IMP, receipts):
		return {}
	var actor := battle.get_unit(IMP)
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var intent := StitchedFoeIntent.choose(battle, actor)
	var quiet := state == battle.state_snapshot() and rng == battle.rng_state() \
		and order == battle.turn_order()
	if intent.is_empty() or bool(intent.get("pass", true)):
		return {"quiet": quiet, "intent": intent, "receipt": {}, "ok": false}
	var heroes: Array = battle.get_heroes().duplicate(true)
	var foes: Array = battle.get_foes().duplicate(true)
	var receipt := battle.use_foe_ability("blinding_ink", int(intent.get("target_rank", 0)))
	receipts.append(receipt)
	return {
		"ok": bool(receipt.get("ok", false)),
		"battle": battle,
		"intent": intent,
		"receipt": receipt,
		"heroes": heroes,
		"foes": foes,
		"actor": actor,
		"quiet": quiet,
		"receipts": receipts,
		"round": battle.round_number(),
	}


func _scan_seeds() -> Dictionary:
	var hit_results := 0
	var miss_results := 0
	var resolved := 0
	var combined := -1
	for seed_value in range(1, SEED_LIMIT + 1):
		var trace := _cast_trace(seed_value)
		if not bool(trace.get("ok", false)):
			continue
		resolved += 1
		var results: Array = trace["receipt"].get("results", [])
		var ranks: Array = []
		var hits := 0
		var misses := 0
		var hit_after_imp := false
		var order: Array = trace["battle"].turn_order()
		var imp_index := order.find(IMP)
		for result in results:
			ranks.append(int(result.get("target_rank", 0)))
			if bool(result.get("hit", false)):
				hits += 1
				if order.find(str(result.get("target", ""))) > imp_index:
					hit_after_imp = true
			else:
				misses += 1
		_check(results.size() == 3 and ranks == [2, 3, 4],
			"AC2: seed %d resolves exactly one Blinding Ink receipt per hero rank 2, 3 and 4"
				% seed_value)
		hit_results += hits
		miss_results += misses
		if hits > 0 and misses > 0 and hit_after_imp and combined < 0:
			combined = seed_value
	_check(resolved >= SEED_LIMIT - 2,
		"AC2: the bounded 1-24 seed cohort really reaches the Imp's round-two action")
	_check(hit_results > 0 and miss_results > 0,
		"AC3: the seed cohort naturally witnesses both splash hits and splash misses")
	_check(combined > 0, "AC3: one unmodified seed carries a hit and a miss in the same splash")
	return {"combined": combined, "hits": hit_results, "misses": miss_results}


func _test_blinding_cast(seed_value: int) -> void:
	var trace := _cast_trace(seed_value)
	if not bool(trace.get("ok", false)):
		_check(false, "AC2: the witness seed reaches a real Blinding Ink turn")
		return
	var battle: StitchedRules = trace["battle"]
	var intent: Dictionary = trace["intent"]
	var receipt: Dictionary = trace["receipt"]
	_check(bool(trace.get("quiet", false)),
		"AC2: the live intent projection spends no state, turn order or RNG")
	_check(int(trace.get("round", 0)) == 2, "AC2: the action is the Imp's genuine round-two turn")
	_check(str(intent.get("foe_id", "")) == IMP
		and str(intent.get("ability_id", "")) == "blinding_ink"
		and str(intent.get("ability_name", "")) == "Blinding Ink"
		and str(intent.get("ability_kind", "")) == "debuff"
		and str(intent.get("target_side", "")) == "hero"
		and int(intent.get("target_rank", 0)) == 2
		and intent.get("affected_ranks", []) == [2, 3, 4]
		and bool(intent.get("multi", false))
		and int(intent.get("base_acc", -1)) == 88
		and intent.get("base_damage") == [0, 0]
		and intent.get("base_effects") == {"blind": 1}
		and not bool(intent.get("pass", true)),
		"AC2: the chooser names Blinding Ink, hero side, multi and living rear ranks 2/3/4")
	# The unchanged opener really happened first, through the same public driver.
	var opener: Dictionary = {}
	for previous in trace.get("receipts", []):
		if str(previous.get("actor", "")) == IMP \
				and str(previous.get("ability", "")) == "ink_lash":
			opener = previous
	_check(not opener.is_empty(), "AC3: the genuine public Ink Lash opener was committed first")
	if not opener.is_empty():
		var results: Array = opener.get("results", [])
		_check(results.size() == 1, "AC3: the Ink Lash opener stays single-target, never multi")
		if results.size() == 1:
			var result: Dictionary = results[0]
			_check(int(result.get("target_rank", 0)) == 1
				and str(result.get("target_side", "")) == "hero"
				and bool(result.get("hit", false)) == (int(result.get("roll", 101))
					<= int(result.get("hit_chance", 0))),
				"AC3: Ink Lash still reaches only the nearest legal hero rank 1")
			if bool(result.get("hit", false)):
				_check(result.get("statuses", []) == [{"status": "exposed", "duration": 1}],
					"AC3: a landed Ink Lash still applies Exposed 1")
			else:
				_check(result.get("statuses", []).is_empty(),
					"AC3: a missed Ink Lash applies no Exposed")
	var actor: Dictionary = trace["actor"]
	_check(_ability_of(actor, "ink_lash").get("target") == [1, 3]
		and not bool(_ability_of(actor, "ink_lash").get("multi", true))
		and _ability_of(actor, "ink_lash").get("dmg") == [3, 4]
		and _ability_of(actor, "ink_lash").get("effects") == {"exposed": 1},
		"AC3: the live kit still authors the single-target 3-4 Exposed Ink Lash")
	_check(str(receipt.get("actor", "")) == IMP
		and str(receipt.get("ability", "")) == "blinding_ink",
		"AC2: the public action commits as the Inkbrush Imp's Blinding Ink")
	_check_result_receipt(battle, receipt, trace["heroes"], trace["foes"], actor, "AC2")


## One splash receipt: one independent rollable result per reached living rear rank, hit-only Blind 1.
func _check_result_receipt(battle: StitchedRules, receipt: Dictionary, heroes_before: Array,
		foes_before: Array, actor: Dictionary, label: String) -> void:
	var results: Array = receipt.get("results", [])
	_check(results.size() == 3,
		label + ": exactly one result per reached living rear rank")
	var acc := 88 + int(actor.get("acc", 0)) + int(battle.candle_band().get("enemy_acc", 0))
	var streak := int(actor.get("miss_streak", 0))
	var ranks: Array = []
	var before_by_id: Dictionary = {}
	for hero in heroes_before:
		before_by_id[str(hero["id"])] = hero
	for result in results:
		var target_id := str(result.get("target", ""))
		var before: Dictionary = before_by_id.get(target_id, {})
		ranks.append(int(result.get("target_rank", 0)))
		_check(not before.is_empty() and int(before.get("rank", 0)) >= 2
			and int(before.get("rank", 0)) == int(result.get("target_rank", 0))
			and str(result.get("target_side", "")) == "hero",
			label + ": the receipt names a real living doll in hero ranks 2-4")
		if before.is_empty():
			continue
		var chance := StitchedRules.hit_chance(acc, StitchedRules.effective_dodge(before), streak)
		_check(int(result.get("hit_chance", -1)) == chance
			and result.has("roll")
			and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
			label + ": doll %s rolls its own independent seeded ACC/DODGE chance" % target_id)
		streak = 0 if bool(result.get("hit", false)) else streak + 1
		_check(int(result.get("damage", -1)) == 0 and not bool(result.get("crit", true)),
			label + ": Blinding Ink deals no direct HP damage to doll %s" % target_id)
		_check(int(result.get("target_hp", -1)) == int(before.get("hp", -2)),
			label + ": doll %s keeps its real HP" % target_id)
		var expected: Array = [{"status": "blind", "duration": 1}] \
			if bool(result.get("hit", false)) else []
		_check(result.get("statuses", []) == expected,
			label + ": only a confirmed hit splashes Blind 1 onto doll %s" % target_id)
		var now := battle.get_unit(target_id)
		_check(int(now.get("hp", -1)) == int(before.get("hp", -2))
			and int(now.get("statuses", {}).get("blind", 0))
				== (1 if bool(result.get("hit", false)) else 0),
			label + ": doll %s's real state carries Blind 1 only where the ink hit" % target_id)
	ranks.sort()
	_check(ranks == [2, 3, 4], label + ": the splash covers exactly living ranks 2, 3 and 4")
	var front := _hero_at(battle, 1)
	_check(not front.is_empty() and int(front.get("statuses", {}).get("blind", 0)) == 0,
		label + ": the rank-1 doll is never an ink victim")
	var front_before: Dictionary = before_by_id.get(str(front.get("id", "")), {})
	_check(not front_before.is_empty()
		and int(front.get("hp", -1)) == int(front_before.get("hp", -2)),
		label + ": the untouched rank-1 doll loses no HP")
	for result in results:
		_check(int(result.get("target_rank", 0)) != 1,
			label + ": no receipt resolves against hero rank 1")
	# A debuff on the hero line never wounds or blinds the foe line.
	for old in foes_before:
		var foe_id := str(old.get("id", ""))
		var now := battle.get_unit(foe_id)
		_check(not now.is_empty() and int(now.get("hp", -1)) == int(old.get("hp", -2))
			and int(now.get("statuses", {}).get("blind", 0)) == 0,
			label + ": Blinding Ink leaves foe %s unharmed and unblinded" % foe_id)


# ---------------------------------------------------------------- AC3 the shipped Blind consequence

## Take an offensive sewn part and spend it with the public use_part action.
func _attack_with(battle: StitchedRules, hero: Dictionary, receipts: Array) -> Dictionary:
	for slot in ["arms", "head", "legs", "torso"]:
		var equipped: Dictionary = hero.get("parts", {}).get(slot, {})
		if equipped.is_empty() or bool(equipped.get("torn", false)):
			continue
		var part: Dictionary = _parts_by_id.get(str(equipped.get("id", "")), {})
		var ability := StitchedParts.ability_at_tier(part, int(equipped.get("tier", 1)))
		if ability.is_empty() or str(ability.get("target_side", "")) != "enemy" \
				or int(ability.get("dmg", [0, 0])[1]) <= 0:
			continue
		for rank in range(1, 5):
			var receipt := battle.use_part(str(equipped["id"]), rank)
			if bool(receipt.get("ok", false)) and str(receipt.get("action", "")) != "refused":
				receipts.append(receipt)
				return receipt
	_check(false, "the doll has a legal offensive sewn part for its own turn")
	return {}


func _test_blind_consequence(seed_value: int) -> void:
	var first := _blind_consequence(seed_value)
	var replay := _blind_consequence(seed_value)
	_check(not first.is_empty() and first == replay,
		"AC4: the full splash/hit/miss/use_part trace replays identical receipts, state, order and RNG")


func _blind_consequence(seed_value: int) -> Dictionary:
	var battle := _make_battle(seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _advance(battle, 2, IMP, receipts):
		_check(false, "AC3: the witness battle reaches the Imp's round-two turn")
		return {}
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(IMP))
	var cast := battle.use_foe_ability("blinding_ink", int(intent.get("target_rank", 2)))
	receipts.append(cast)
	if not bool(cast.get("ok", false)):
		_check(false, "AC3: the witness splash commits")
		return {}
	var hit_id := ""
	var miss_id := ""
	var order: Array = battle.turn_order()
	var imp_index := order.find(IMP)
	for result in cast.get("results", []):
		if bool(result.get("hit", false)) and hit_id.is_empty() \
				and order.find(str(result.get("target", ""))) > imp_index:
			hit_id = str(result.get("target", ""))
	for result in cast.get("results", []):
		if not bool(result.get("hit", true)) and miss_id.is_empty():
			miss_id = str(result.get("target", ""))
	_check(not hit_id.is_empty() and not miss_id.is_empty(),
		"AC3: the witness splash naturally hits a doll that acts after the Imp and misses another")
	if hit_id.is_empty() or miss_id.is_empty():
		return {}
	var hit_first := false
	var hit_second := false
	var miss_checked := false
	for step in range(200):
		if battle.is_over():
			break
		var current := battle.current_actor_id()
		if current == hit_id and not hit_first:
			_check(battle.round_number() == 2,
				"AC3: the splashed doll's forced-miss attack happens in the cast round")
			var hero := battle.get_unit(hit_id)
			_check(int(hero.get("statuses", {}).get("blind", 0)) == 1,
				"AC3: the splashed doll still carries Blind at its own turn")
			var attack := _attack_with(battle, hero, receipts)
			if attack.is_empty():
				return {}
			var result: Dictionary = attack["results"][0]
			_check(bool(result.get("blinded", false)) and not bool(result.get("hit", true))
				and int(result.get("damage", -1)) == 0 and not result.has("roll"),
				"AC3: the doll's next real attack is forced to miss without a hit roll")
			_check(not battle.get_unit(hit_id).get("statuses", {}).has("blind"),
				"AC3: the forced miss consumes the Blind")
			hit_first = true
			continue
		if current == hit_id and hit_first and not hit_second:
			_check(battle.round_number() == 3,
				"AC3: the doll's later attack comes in the very next round, before another splash")
			var hero := battle.get_unit(hit_id)
			_check(not hero.get("statuses", {}).has("blind"),
				"AC3: Blind does not linger into the doll's next turn")
			var attack := _attack_with(battle, hero, receipts)
			if attack.is_empty():
				return {}
			var result: Dictionary = attack["results"][0]
			_check(not bool(result.get("blinded", false)) and result.has("roll")
				and not battle.get_unit(hit_id).get("statuses", {}).has("blind"),
				"AC3: a later attack is rolled normally instead of being suppressed")
			hit_second = true
			continue
		if current == miss_id and not miss_checked:
			var hero := battle.get_unit(miss_id)
			_check(not hero.get("statuses", {}).has("blind"),
				"AC3: a doll the ink missed carries no phantom Blind")
			var attack := _attack_with(battle, hero, receipts)
			if attack.is_empty():
				return {}
			var result: Dictionary = attack["results"][0]
			_check(not bool(result.get("blinded", false)) and result.has("roll"),
				"AC3: the missed doll's own attack is a normal seeded roll")
			miss_checked = true
			continue
		if hit_second and miss_checked:
			break
		var receipt := _step(battle)
		if not bool(receipt.get("ok", false)):
			break
		receipts.append(receipt)
	_check(hit_second and miss_checked,
		"AC3: the trace reaches both the blinded doll's two attacks and the missed doll's turn")
	return {
		"receipts": receipts,
		"state": battle.state_snapshot(),
		"order": battle.turn_order(),
		"rng": battle.rng_state(),
		"heroes": battle.get_heroes().duplicate(true),
	}


# ---------------------------------------------------------------- AC4 refusals and absent ranks

func _test_rejections() -> void:
	var battle := _make_battle(3)
	if battle == null:
		return
	for step in range(16):
		if battle.is_over() or battle.current_side() == "hero":
			break
		_step(battle)
	_check(battle.current_side() == "hero", "AC4: a real hero turn precedes the out-of-turn probe")
	_check_silent_refusal(battle, "blinding_ink", 2, "not a foe turn",
		"AC4: Blinding Ink during a hero turn is refused with no spend")
	_check_silent_refusal(battle, "not_blinding_ink", 2, "not a foe turn",
		"AC4: an unauthored action during a hero turn is refused with no spend")
	var other_foe := ""
	for step in range(TURN_LIMIT):
		if battle.is_over() or battle.round_number() > 1:
			break
		if battle.current_side() == "foe" and battle.current_actor_id() != IMP:
			other_foe = battle.current_actor_id()
			break
		_step(battle)
	_check(not other_foe.is_empty(), "AC4: another living foe really gets a turn in round one")
	if not other_foe.is_empty():
		_check_silent_refusal(battle, "blinding_ink", 2, "has no ability",
			"AC4: another foe cannot spend the Imp's Blinding Ink")


func _check_silent_refusal(battle: StitchedRules, ability_id: String, rank: int,
		error_fragment: String, message: String) -> void:
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var receipt := battle.use_foe_ability(ability_id, rank)
	_check(not bool(receipt.get("ok", true))
		and str(receipt.get("error", "")).contains(error_fragment)
		and before == battle.state_snapshot() and rng == battle.rng_state()
		and order == battle.turn_order(),
		message + " (got %s)" % str(receipt.get("error", "")))


## On the Imp's own real turn, a rank-1 cast and an unauthored action are still refused atomically,
## leaving the authored rear-rank splash available.
func _test_imp_turn_refusals() -> void:
	var battle := _make_battle(7)
	if battle == null:
		return
	var receipts: Array = []
	if not _advance(battle, 2, IMP, receipts):
		_check(false, "AC4: the refusal fixture reaches the Imp's genuine round-two turn")
		return
	_check_silent_refusal(battle, "blinding_ink", 1, "no legal target in rank 1",
		"AC4: the Imp's own turn still refuses a hero-rank-1 Blinding Ink")
	_check_silent_refusal(battle, "not_blinding_ink", 2, "has no ability",
		"AC4: the Imp's own turn refuses an unauthored action")
	var receipt := battle.use_foe_ability("blinding_ink", 2)
	_check(bool(receipt.get("ok", false)) and receipt.get("results", []).size() == 3,
		"AC4: the refused casts leave the real rear-rank splash available")


func _test_absent_rear_rank() -> void:
	var party: Array = _preview["heroes"].duplicate(true)
	party[3].merge({"hp": 0, "lost": true, "parts": {}}, true)
	var lost_id := str(party[3]["id"])
	var battle := _make_battle(5, party)
	if battle == null:
		return
	var receipts: Array = []
	if not _advance(battle, 2, IMP, receipts):
		_check(false, "AC4: the absent-doll battle reaches the Imp's round-two turn")
		return
	_check(bool(battle.get_unit(lost_id).get("lost", false))
		and int(battle.get_unit(lost_id).get("hp", -1)) == 0,
		"AC4: the rear doll really is absent before the splash")
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(IMP))
	_check(state == battle.state_snapshot() and rng == battle.rng_state()
		and order == battle.turn_order(),
		"AC4: the projection over the absent roster spends no state, order or RNG")
	_check(str(intent.get("ability_id", "")) == "blinding_ink"
		and bool(intent.get("multi", false))
		and intent.get("affected_ranks", []) == [2, 3]
		and int(intent.get("target_rank", 0)) == 2,
		"AC4: the forecast names only living rear ranks 2 and 3, never the ghost")
	var ghost := battle.get_unit(lost_id)
	for rank in [0, 1, 5]:
		var before := battle.state_snapshot()
		var before_rng := battle.rng_state()
		var denied := battle.use_foe_ability("blinding_ink", rank)
		_check(not bool(denied.get("ok", true))
			and str(denied.get("error", "")) == "no legal target in rank %d" % rank
			and before == battle.state_snapshot() and before_rng == battle.rng_state(),
			"AC4: hero rank %d is rejected atomically with no action or RNG spend (got %s)"
				% [rank, str(denied.get("error", ""))])
	var receipt := battle.use_foe_ability("blinding_ink", int(intent.get("target_rank", 2)))
	_check(bool(receipt.get("ok", false)) and receipt.get("results", []).size() == 2,
		"AC4: the legal splash still returns two receipts, never a ghost third")
	var ranks: Array = []
	for result in receipt.get("results", []):
		ranks.append(int(result.get("target_rank", 0)))
		_check(str(result.get("target", "")) != lost_id,
			"AC4: the absent doll never receives a splash receipt or Blind")
	ranks.sort()
	_check(ranks == [2, 3], "AC4: the other living rear ranks 2 and 3 are still reached")
	_check(battle.get_unit(lost_id) == ghost,
		"AC4: the absent doll's HP, partless state and statuses stay completely untouched")


# ---------------------------------------------------------------- AC2 the shipped live foe driver

func _test_live_driver(seed_value: int) -> void:
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(_config(seed_value)),
		"AC2: the real battle screen admits the seeded Inkbrush Imp fight")
	if stage.battle == null:
		stage.free()
		return
	root.add_child(stage)
	await process_frame
	var battle := stage.battle
	var live: Dictionary = {}
	for step in range(40):
		if battle == null or battle.is_over() or not live.is_empty():
			break
		if battle.current_side() != "hero":
			break
		stage.submit_pass()
		for receipt in stage.receipts:
			if str(receipt.get("actor", "")) == IMP \
					and str(receipt.get("ability", "")) == "blinding_ink":
				live = receipt
	_check(not live.is_empty(),
		"AC2: the shipped live foe driver executes Blinding Ink in real play")
	if not live.is_empty():
		var results: Array = live.get("results", [])
		var ranks: Array = []
		var hits := 0
		var misses := 0
		for result in results:
			ranks.append(int(result.get("target_rank", 0)))
			_check(int(result.get("damage", -1)) == 0,
				"AC2: the live splash deals no direct damage")
			_check(result.has("roll"),
				"AC2: every live splash target receives its own seeded roll")
			_check(not bool(result.get("hit", false))
				or result.get("statuses", []) == [{"status": "blind", "duration": 1}],
				"AC2: a live hit applies exactly Blind 1")
			_check(bool(result.get("hit", false))
				or result.get("statuses", []).is_empty(),
				"AC2: a live miss applies no Blind")
			if bool(result.get("hit", false)):
				hits += 1
			else:
				misses += 1
		ranks.sort()
		_check(results.size() == 3 and ranks == [2, 3, 4],
			"AC2: the live driver reaches exactly hero ranks 2, 3 and 4")
		_check(hits + misses == 3, "AC2: the live splash records one rolled result per doll")
	var cycle: Array = []
	for receipt in stage.receipts:
		if str(receipt.get("actor", "")) == IMP:
			cycle.append(str(receipt.get("ability", "")))
	_check(cycle.has("ink_lash") and cycle.has("blinding_ink"),
		"AC2: the live driver keeps Ink Lash then Blinding Ink in the authored order")
	stage.free()
	await process_frame
