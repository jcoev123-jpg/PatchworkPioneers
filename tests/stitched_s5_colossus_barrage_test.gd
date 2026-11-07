extends SceneTree
## Canonical barrage through the catalog, displayed intent and live seeded rules.

const BOSS := "sewing_machine_colossus"
const BARRAGE := "colossus_barrage"
const TROPHY := "sewing_machine_colossus_needle_arm"
const PREVIEW := "res://data/stitched/s2_preview.json"
const BURST := {
	"id": BARRAGE, "name": "Needle Barrage", "kind": "ranged", "launch": [1, 4],
	"target": [1, 2, 3], "target_side": "enemy", "multi": true, "acc": 80,
	"dmg": [2, 3], "crit": 0, "effects": {"bleed": 1}, "self_move": 0, "move": "attack4",
}
const TREADLE := {
	"id": "colossus_treadle", "name": "Treadle Stomp", "kind": "melee", "launch": [1, 3],
	"target": [1], "target_side": "enemy", "multi": false, "acc": 84,
	"dmg": [6, 9], "crit": 0, "effects": {"stun": 1}, "self_move": 0, "move": "attack2",
}
const BOBBIN := {
	"id": "colossus_bobbin", "name": "Bobbin Shot", "kind": "ranged", "launch": [1, 4],
	"target": [3, 4], "target_side": "enemy", "multi": false, "acc": 80,
	"dmg": [4, 6], "crit": 0, "effects": {"pull": 1}, "self_move": 0, "move": "attack3",
}
const GUARD := {
	"id": "colossus_guard", "name": "Iron Tread", "kind": "buff", "launch": [1, 3],
	"target": [1], "target_side": "self", "multi": false, "acc": 100,
	"dmg": [0, 0], "crit": 0, "effects": {"thorns": 4}, "self_move": 0, "move": "guard",
}
const LEGACY := {"target": "front", "actions": [
	{"type": "attack", "amount": 6, "hits": 2, "weight": 4},
	{"type": "block", "amount": 5, "weight": 2},
	{"type": "debuff", "amount": 1, "status": "weak", "weight": 1},
	{"type": "attack", "amount": 9, "move": "attack2", "weight": 1},
	{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1},
	{"type": "attack", "amount": 10, "move": "attack4", "weight": 1},
]}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(catalog.get("ok", false), "canonical catalog validates")
	_source(catalog)
	if catalog.get("ok", false):
		var witnesses := {"hit": 0, "miss": 0, "crit": 0, "tick": 0, "mixed": 0}
		for seed_value in range(1, 25):
			var first := _trace(catalog, seed_value, witnesses)
			_check(not first.is_empty() and first == _trace(catalog, seed_value, {}),
				"equal seed/turns replay complete receipts, state, order and RNG")
		for key in witnesses:
			_check(witnesses[key] > 0, "genuine seeded witness: " + key)
		_invalid_launch(catalog)
		_absent(catalog)
		_hanging(catalog)
		_dead(catalog)
		_treadle(catalog)
	if failures.is_empty():
		print("stitched_s5_colossus_barrage_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s5_colossus_barrage_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _source(catalog: Dictionary) -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/boss.json"))
	_check(records is Array, "real boss JSON parses")
	if not records is Array:
		return
	var matches: Array = records.filter(func(r: Dictionary) -> bool: return r.get("id") == BOSS)
	_check(matches.size() == 1, "exactly one named Colossus")
	if matches.size() != 1:
		return
	var boss: Dictionary = matches[0]
	_check(boss.get("name") == "Sewing-Machine Colossus" and boss.get("max_hp") == 96
		and boss.get("art_path") == "res://assets/paper/enemies/sewing_machine_colossus.png"
		and boss.get("intent") == JSON.parse_string(JSON.stringify(LEGACY)), "legacy identity/stats/intent intact")
	var expected := {"max_hp": 96, "speed": 4, "dodge": 3, "acc": 0, "prot": 14,
		"is_boss": true, "turns_per_round": 2, "trophy": TROPHY,
		"abilities": [TREADLE, BOBBIN, BURST, GUARD]}
	_check(boss.get("stitched") == JSON.parse_string(JSON.stringify(expected)),
		"canonical kit and order; Treadle Stun 1 and remaining Colossus abilities intact")
	var foe := StitchedEnemyCatalog.foe_for(catalog, BOSS)
	_check(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, BOSS) == TROPHY,
		"named canonical foe and unchanged trophy load")
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_check(foe.get(key) == expected[key], "loaded stat: " + key)
	var normalized: Array = []
	for ability in [TREADLE, BOBBIN, BURST, GUARD]:
		var validated := StitchedParts.validate_ability(ability)
		_check(validated.get("ok", false), "authored ability validates")
		if validated.get("ok", false):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized, "loader exposes exact normalized kit")
	if normalized.size() == 4:
		_check(normalized[2]["launch_mask"] == StitchedParts.rank_mask([1, 4])
			and normalized[2]["target_mask"] == StitchedParts.rank_mask([1, 2, 3]), "literal normalized rank masks")


func _battle(catalog: Dictionary, seed_value: int, ids: Array = [BOSS, "ragling", "ragling_guard"],
		lost_ranks: Array = [], low_hp: bool = false) -> StitchedRules:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(config.get("heroes", []).size() == 4 and not config.get("parts", []).is_empty(),
		"shipped four equipped heroes and parts exist")
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	config["foes"] = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, enemy_id)
		_check(not foe.is_empty(), "real catalog foe exists: " + str(enemy_id))
		config["foes"].append(foe)
	for rank in lost_ranks:
		# Public carried-run schema represents a genuinely absent doll, with no ghost equipment.
		config["heroes"][rank - 1].merge({"hp": 0, "lost": true, "parts": {}}, true)
	if low_hp:
		config["heroes"][0]["hp"] = 1
	var created := StitchedRules.create(config)
	_check(created.get("ok", false), "real ranked battle creates: " + str(created.get("error")))
	if not created.get("ok", false):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.turn_order().count(BOSS) == 2, "boss has two seeded turns")
	return battle


func _refuse(b: StitchedRules, rank: int, error: String, ability_id: String = BARRAGE) -> Dictionary:
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var receipt := b.use_foe_ability(ability_id, rank)
	_check(not receipt.get("ok", true) and receipt.get("error") == error
		and before == b.state_snapshot() and rng == b.rng_state(),
		"refusal preserves HP/statuses/turn/receipts/RNG: " + error)
	return receipt


func _reach(b: StitchedRules, actor: String, receipts: Array, round_value: int = 1) -> bool:
	for step in range(100):
		if b.is_over():
			break
		if b.current_actor_id() == actor and b.round_number() >= round_value:
			return true
		if b.current_actor_id() != BOSS:
			var error := "it is not a foe turn" if b.current_side() == "hero" else "the foe has no ability " + BARRAGE
			receipts.append(_refuse(b, 1, error))
		var passed := b.pass_turn()
		_check(passed.get("ok", false), "real initiative advances by Pass")
		receipts.append(passed)
	_check(false, "reaches actual actor/round: " + actor)
	return false


func _intent(b: StitchedRules, receipts: Array, ranks: Array) -> Dictionary:
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var prior_receipts := receipts.duplicate(true)
	var intent := StitchedFoeIntent.choose(b, b.get_unit(BOSS))
	_check(before == b.state_snapshot() and rng == b.rng_state() and prior_receipts == receipts,
		"displayed intent is a pure read including turn and receipts")
	_check(b.round_number() == 3 and intent.get("ability_id") == BARRAGE
		and intent.get("ability_name") == "Needle Barrage" and intent.get("multi") == true
		and intent.get("affected_ranks") == ranks and intent.get("base_damage") == [2, 3]
		and intent.get("base_effects") == {"bleed": 1} and intent.get("base_acc") == 80
		and intent.get("target_side") == "hero" and not intent.get("pass", true),
		"round three canonical intent predicts eligible barrage exactly")
	return intent


func _trace(catalog: Dictionary, seed_value: int, witnesses: Dictionary) -> Dictionary:
	var b := _battle(catalog, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	if not _reach(b, BOSS, receipts, 3):
		return {}
	var intent := _intent(b, receipts, [1, 2, 3])
	for rank in [0, 4, 5]:
		receipts.append(_refuse(b, rank, "no legal target in rank %d" % rank))
	var before := b.get_heroes().duplicate(true)
	var actor := b.get_unit(BOSS)
	var turn := int(b.state_snapshot()["turn_index"])
	var receipt := b.use_foe_ability(str(intent.get("ability_id", "")), 1)
	receipts.append(receipt)
	_check(receipt.get("ok", false) and receipt.get("actor") == BOSS
		and receipt.get("ability") == BARRAGE and receipt.get("results", []).size() == 3,
		"one canonical action resolves three independent targets")
	_check(b.round_number() == 3 and b.state_snapshot()["turn_index"] == turn + 1,
		"barrage spends exactly one of two boss turns")
	var ranks: Array = []
	var streak := int(actor["miss_streak"])
	var tick_id := ""
	var hit_count := 0
	for result in receipt.get("results", []):
		var rank := int(result["target_rank"])
		ranks.append(rank)
		var old: Dictionary = before[rank - 1]
		_check(result["target"] == old["id"], "receipt names actual ranked doll")
		var chance := StitchedRules.hit_chance(80 + int(actor["acc"]) + int(b.candle_band()["enemy_acc"]),
			StitchedRules.effective_dodge(old), streak)
		_check(result["hit_chance"] == chance and result["hit"] == (result["roll"] <= chance),
			"independent ACC roll with miss-streak modifier")
		streak = 0 if result["hit"] else streak + 1
		if result["hit"]:
			hit_count += 1
			var bases: Array = [StitchedRules.crit_damage(3)] if result["crit"] else [2, 3]
			var damages: Array = []
			for base in bases:
				var scaled := StitchedS1BEffects.enemy_damage(base + int(actor["dmg_bonus"]), b.candle())
				damages.append(StitchedRules.damage_after_modifiers(scaled, actor["statuses"], old["statuses"], false, 0, old["prot"]))
			_check(damages.has(result["damage"]) and result["target_hp"] == old["hp"] - result["damage"],
				"rolled 2-3 or crit after candle/modifiers/PROT")
			_check(result["statuses"] == [{"status": "bleed", "duration": 1}], "confirmed hit alone applies Bleed 1")
			if not witnesses.is_empty():
				witnesses["hit"] += 1
				witnesses["crit"] += int(result["crit"])
			# Advancing the action may already have entered this target's next turn.
			var now := b.get_unit(str(old["id"]))
			if now["statuses"].has("bleed"):
				_check(now["hp"] == result["target_hp"], "hit HP and pending Bleed match live state")
				if int(now["prot"]) > 0:
					tick_id = str(old["id"])
			else:
				_check(b.current_actor_id() == old["id"] and now["hp"] == result["target_hp"] - 1,
					"immediate next turn already ticks Bleed without PROT cut")
		else:
			var now := b.get_unit(str(old["id"]))
			_check(result["damage"] == 0 and result["statuses"].is_empty() and now == old,
				"miss deals no damage or Bleed")
			if not witnesses.is_empty():
				witnesses["miss"] += 1
	ranks.sort()
	_check(ranks == [1, 2, 3] and b.get_unit("lantern_monk") == before[3], "each front rank once; real rank four doll untouched")
	if not witnesses.is_empty() and hit_count > 0 and hit_count < 3:
		witnesses["mixed"] += 1
	if not tick_id.is_empty():
		var old := b.get_unit(tick_id)
		_check(old["prot"] > 0 and old["statuses"].get("bleed") == 1, "protected doll carries landed Bleed")
		if _reach(b, tick_id, receipts):
			var ticked := b.get_unit(tick_id)
			_check(ticked["hp"] == old["hp"] - 1 and ticked["prot"] == old["prot"]
				and not ticked["statuses"].has("bleed"), "next own turn consumes Bleed 1 and ignores PROT")
			if not witnesses.is_empty():
				witnesses["tick"] += 1
	return {"receipts": receipts, "intent": intent, "state": b.state_snapshot(), "order": b.turn_order(), "rng": b.rng_state()}


func _invalid_launch(catalog: Dictionary) -> void:
	for ids in [["ragling", BOSS], ["ragling", "ragling_guard", BOSS]]:
		var b := _battle(catalog, 71, ids)
		if b != null and _reach(b, BOSS, []):
			var rank := int(b.get_unit(BOSS)["rank"])
			_check(rank in [2, 3], "boss actually occupies illegal launch rank")
			_refuse(b, 1, "ability cannot launch from rank %d" % rank)


func _absent(catalog: Dictionary) -> void:
	for missing in [[2], [1, 2, 3]]:
		var b := _battle(catalog, 17, [BOSS, "ragling"], missing)
		if b == null or not _reach(b, BOSS, [], 3):
			continue
		var back := b.get_unit("lantern_monk")
		_check(not back["lost"] and back["rank"] == 4 and b.turn_order().has(back["id"]), "safe back doll is a legal participant")
		if missing.size() == 1:
			_intent(b, [], [1, 3])
			var receipt := b.use_foe_ability(BARRAGE, 1)
			var ranks: Array = []
			for result in receipt.get("results", []):
				ranks.append(result["target_rank"])
			_check(receipt.get("ok", false) and ranks == [1, 3], "absent rank shrinks real action and intent")
		else:
			var intent := StitchedFoeIntent.choose(b, b.get_unit(BOSS))
			_check(intent.get("ability_id") == "colossus_guard" and intent.get("affected_ranks") == [1]
				and intent.get("target_side") == "foe",
				"without front targets driver selects a different legal move")
			_refuse(b, 1, "no legal target in rank 1")
		_check(back == b.get_unit("lantern_monk"), "no ghost barrage on rank four")


func _hanging(catalog: Dictionary) -> void:
	var landed := 0
	for seed_value in range(1, 9):
		var b := _battle(catalog, seed_value, [BOSS, "ragling"], [], true)
		if b == null or not _reach(b, BOSS, []):
			continue
		var receipt := b.use_foe_ability(BARRAGE, 1)
		_check(receipt.get("ok", false) and receipt.get("results", []).size() == 3, "low HP still uses real barrage")
		if not receipt.get("ok", false):
			continue
		var first: Dictionary = receipt["results"][0]
		if first["hit"]:
			landed += 1
			var hero := b.get_unit("warden")
			_check(first["damage"] > 1 and first["target_hp"] == 0 and first["hanging"]
				and not first["lost"] and not first.has("seam_roll") and hero["hanging"] and not hero["lost"],
				"near-zero front doll enters Hanging; no invented death or extra hit")
	_check(landed > 0, "non-vacuous landed Hanging witness")


func _dead(catalog: Dictionary) -> void:
	var b := _battle(catalog, 17, [BOSS, "ragling"])
	if b == null:
		return
	# Kill the actual 96-HP boss through equipped public hero attacks; normal foes Pass.
	for step in range(600):
		if b.get_unit(BOSS)["dead"] or b.is_over():
			break
		var acted := false
		if b.current_side() == "hero":
			var hero := b.get_unit(b.current_actor_id())
			for slot in StitchedParts.SLOTS:
				var part: Dictionary = hero["parts"][slot]
				var entry: Dictionary = b._parts[part["id"]]
				var ability := StitchedParts.ability_at_tier(entry, int(part["tier"]))
				if ability["target_side"] == "enemy" and ability["dmg"][1] > 0 and ability["self_move"] == 0 \
						and StitchedParts.ranks_allowed(ability["launch_mask"], hero["rank"]) \
						and StitchedParts.ranks_allowed(ability["target_mask"], b.get_unit(BOSS)["rank"]):
					var receipt := b.use_part(str(part["id"]), int(b.get_unit(BOSS)["rank"]))
					_check(receipt.get("ok", false), "equipped public attack damages actual boss")
					acted = true
					break
		if not acted:
			_check(b.pass_turn().get("ok", false), "pass while reaching boss death")
	var dead := b.get_unit(BOSS)
	_check(dead["dead"] and dead["hp"] == 0 and not b.is_over(), "boss genuinely dead with living normal ally")
	var before := b.state_snapshot()
	var rng := b.rng_state()
	_check(StitchedFoeIntent.choose(b, dead).is_empty() and before == b.state_snapshot() and rng == b.rng_state(),
		"dead boss cannot project an intent or spend RNG")
	var error := "it is not a foe turn" if b.current_side() == "hero" else "the foe has no ability " + BARRAGE
	_refuse(b, 1, error)

# The Colossus's other front-only action uses the same public damage/Stun
# transaction as any equipped ability. Discover both real hit and miss seeds;
# never force rolls or inject statuses into a battle.
func _treadle(catalog: Dictionary) -> void:
	var seen := {"hit": false, "miss": false}
	for seed_value in range(1, 301):
		var first := _treadle_trace(catalog, seed_value)
		if first.is_empty():
			continue
		var key := "hit" if first["hit"] else "miss"
		if seen[key]:
			continue
		seen[key] = true
		var replay := _treadle_trace(catalog, seed_value)
		_check(first == replay, "Treadle complete same-seed " + key + " replay: action/pass receipts, snapshots, order, RNG")
		if seen["hit"] and seen["miss"]:
			break
	_check(seen["hit"], "bounded real Colossus Treadle hit with damage, Stun and a skipped turn")
	_check(seen["miss"], "bounded real Colossus Treadle miss without a Stun or skipped turn")
	_treadle_refusals(catalog)


func _treadle_trace(catalog: Dictionary, seed_value: int) -> Dictionary:
	var b := _battle(catalog, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	if not _reach(b, BOSS, receipts):
		return {}
	# Require a living rank-one doll whose next turn is still in this round.
	# This proves an actual skip instead of inferring one from a status flag.
	var order := b.turn_order()
	var boss_slot := int(b.state_snapshot()["turn_index"])
	var front_slot := order.find("warden", boss_slot + 1)
	var front := b.get_unit("warden")
	if front_slot < 0 or front_slot >= order.size() - 1 or int(front["rank"]) != 1 \
			or int(front["hp"]) <= 16 or bool(front["hanging"]) or bool(front["lost"]) \
			or not front["statuses"].is_empty():
		return {}
	var actor := b.get_unit(BOSS)
	_check(b.current_actor_id() == BOSS and b.current_side() == "foe" and b.round_number() == 1,
		"Treadle reaches the actual rank-one Colossus turn")
	var chance := StitchedRules.hit_chance(84 + int(actor["acc"]) + int(b.candle_band()["enemy_acc"]),
		StitchedRules.effective_dodge(front), int(actor["miss_streak"]))
	var action := b.use_foe_ability("colossus_treadle", 1)
	receipts.append(action)
	var results: Array = action.get("results", [])
	_check(action.get("ok", false) and action.get("actor") == BOSS
		and action.get("ability") == "colossus_treadle" and results.size() == 1,
		"real Colossus Treadle resolves one front rank and spends a boss turn")
	if not action.get("ok", false) or results.size() != 1:
		return {}
	var result: Dictionary = results[0]
	var landed := bool(result.get("hit", false))
	_check(result.get("target") == "warden" and result.get("target_rank") == 1
		and result.get("hit_chance") == chance and result.get("hit") == (int(result.get("roll", 101)) <= chance),
		"Treadle public receipt proves real rank-one target and seeded ACC/roll")
	var now := b.get_unit("warden")
	_check(now["hp"] > 0 and not now["hanging"] and not now["lost"],
		"Treadle front doll remains healthy so Hanging cannot impersonate Stun")
	if landed:
		_check(int(result["damage"]) > 0 and int(result["target_hp"]) == int(front["hp"]) - int(result["damage"])
			and int(now["hp"]) == int(result["target_hp"])
			and result["statuses"] == [{"status": "stun", "duration": 1}],
			"confirmed Treadle hit deals live HP damage and applies exactly Stun 1")
	else:
		_check(result["damage"] == 0 and result["statuses"].is_empty()
			and result["target_hp"] == front["hp"] and now == front,
			"genuine Treadle miss causes no damage, status or front doll mutation")
	var snapshots: Array = [{"state": b.state_snapshot(), "order": b.turn_order(), "rng": b.rng_state()}]
	# Pass every intervening real actor; _enter_turn automatically consumes the
	# stunned rank-one actor before any request can be issued on its behalf.
	for step in range(20):
		if b.is_over() or int(b.state_snapshot()["turn_index"]) >= front_slot:
			break
		_check(b.current_actor_id() != "warden", "front doll not active before its initiative slot")
		var pass_receipt := b.pass_turn()
		_check(pass_receipt.get("ok", false), "advance toward the real front doll initiative slot")
		receipts.append(pass_receipt)
		snapshots.append({"state": b.state_snapshot(), "order": b.turn_order(), "rng": b.rng_state()})
	var at_slot := int(b.state_snapshot()["turn_index"])
	now = b.get_unit("warden")
	if landed:
		_check(at_slot > front_slot and b.current_actor_id() != "warden"
			and not now["statuses"].has("stun") and int(now["statuses"].get("stun_resist", 0)) == 1,
			"exactly one rank-one turn is skipped and canonical Stun Resist is granted")
		_check(now["hp"] == result["target_hp"], "skipped turn inflicts no extra direct damage")
		# At its next *eligible* turn, the doll may act again; the temporary
		# resist has counted down naturally (no direct state manipulation).
		var returned := false
		for step in range(36):
			if b.is_over():
				break
			if b.current_actor_id() == "warden":
				returned = true
				break
			var next := b.pass_turn()
			_check(next.get("ok", false), "advance to front doll's next eligible turn")
			receipts.append(next)
			snapshots.append({"state": b.state_snapshot(), "order": b.turn_order(), "rng": b.rng_state()})
		_check(returned, "front doll resumes a real turn after one skipped initiative")
		if returned:
			now = b.get_unit("warden")
			_check(not now["statuses"].has("stun") and not now["statuses"].has("stun_resist"),
				"temporary Stun Resist expires on the doll's next eligible turn")
			var resumed := b.pass_turn()
			_check(resumed.get("ok", false) and resumed.get("actor") == "warden",
				"previously stunned front doll can spend its next normal turn")
			receipts.append(resumed)
			snapshots.append({"state": b.state_snapshot(), "order": b.turn_order(), "rng": b.rng_state()})
	else:
		_check(at_slot == front_slot and b.current_actor_id() == "warden"
			and not now["statuses"].has("stun") and not now["statuses"].has("stun_resist"),
			"Treadle miss does not consume the target's scheduled turn or grant resistance")
		if b.current_actor_id() == "warden":
			var available := b.pass_turn()
			_check(available.get("ok", false) and available.get("actor") == "warden",
				"unhit front doll acts on its original scheduled turn")
			receipts.append(available)
			snapshots.append({"state": b.state_snapshot(), "order": b.turn_order(), "rng": b.rng_state()})
	return {
		"hit": landed, "seed": seed_value, "receipts": receipts, "snapshots": snapshots,
		"state": b.state_snapshot(), "order": b.turn_order(), "rng": b.rng_state(),
	}


func _treadle_refusals(catalog: Dictionary) -> void:
	var b := _battle(catalog, 41)
	if b != null and _reach(b, BOSS, []):
		for rank in [0, 2, 5]:
			_refuse(b, rank, "no legal target in rank %d" % rank, "colossus_treadle")
		_check(b.current_actor_id() == BOSS, "invalid Treadle ranks cannot spend the Colossus turn")
	var missing := _battle(catalog, 41, [BOSS, "ragling"], [1])
	if missing != null and _reach(missing, BOSS, []):
		_check(missing.get_unit("warden")["lost"] and missing.get_unit("seamstress")["hp"] > 0,
			"rank-one doll genuinely absent while other heroes live")
		_refuse(missing, 1, "no legal target in rank 1", "colossus_treadle")
	for wrong_id in ["warden", "ragling"]:
		var wrong := _battle(catalog, 41)
		if wrong == null or not _reach(wrong, wrong_id, []):
			continue
		var error := "it is not a foe turn" if wrong_id == "warden" else "the foe has no ability colossus_treadle"
		_check(wrong.current_actor_id() == wrong_id, "off-turn actor truly owns initiative: " + wrong_id)
		_refuse(wrong, 1, error, "colossus_treadle")
