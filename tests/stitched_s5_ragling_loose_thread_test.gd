extends SceneTree
## S5 Ragling contract: canonical Loose Thread frays and snips in actual seeded
## S2 four-doll/two-foe turns, with hit/miss, refusals and full replay coverage.

const PREVIEW := "res://data/stitched/s2_preview.json"
const STARTERS := "res://data/enemies/starter_enemies.json"
const RAKE := {"id": "rag_rake", "name": "Rag Rake", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [4, 6], "crit": 0, "effects": {},
	"self_move": 0, "move": "attack"}
const THREAD := {"id": "loose_thread", "name": "Loose Thread", "kind": "debuff",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [0, 0], "crit": 0, "effects": {"fray": 5, "snip": 1},
	"self_move": 0, "move": "skill"}
const SHUNT := {"id": "shield_shunt", "name": "Shield Shunt", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [4, 6], "crit": 0, "effects": {"push": 1, "fray": 5},
	"self_move": 0, "move": "skill"}
var checks := 0
var failures: Array[String] = []
var catalog: Dictionary = {}
var preview: Dictionary = {}


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(bool(catalog.get("ok", false)) and data is Dictionary,
		"AC1: real S5 catalog and S2 preview both load")
	if bool(catalog.get("ok", false)) and data is Dictionary:
		preview = data
		_source_contract()
		_rake_contract()
		_seeded_contract()
		_refusals()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_ragling_loose_thread_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _record(records: Array, id: String) -> Dictionary:
	for entry in records:
		if entry is Dictionary and entry.get("id") == id:
			return entry
	return {}


func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


func _source_contract() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(STARTERS))
	_check(data is Array, "AC1: canonical starter source is an array")
	if not data is Array:
		return
	var raw := _record(data, "ragling")
	var neighbor := _record(data, "ragling_guard")
	_check(not raw.is_empty() and not neighbor.is_empty(),
		"AC1: required Ragling and Guard Ragling source records exist")
	if raw.is_empty() or neighbor.is_empty():
		return
	var expected := {"id": "ragling", "name": "Ragling", "max_hp": 12,
		"art_path": "res://assets/paper/enemies/ragling.png",
		"intent": {"target": "front", "actions": [{"type": "attack", "amount": 5, "weight": 3}]},
		"stitched": {"max_hp": 12, "speed": 4, "dodge": 8, "acc": 0, "prot": 0,
			"is_boss": false, "turns_per_round": 1, "trophy": "ragling_tatter_claw",
			"abilities": [RAKE, THREAD]}}
	_check(_same(raw, expected),
		"AC1: full legacy Ragling record and two-move Stitched kit exact with only Rag Rake damage [4,6] changed")
	_check(_same(neighbor, {"id": "ragling_guard", "name": "Guard Ragling", "max_hp": 12,
		"art_path": "res://assets/paper/enemies/ragling_guard.png",
		"intent": {"target": "front", "actions": [
			{"type": "block", "amount": 5, "weight": 3},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
			{"type": "attack", "amount": 6, "weight": 1},
			{"type": "attack", "amount": 7, "weight": 1, "move": "attack2"}]},
		"stitched": {"max_hp": 12, "speed": 3, "dodge": 4, "acc": 0, "prot": 6,
			"is_boss": false, "turns_per_round": 1, "trophy": "ragling_guard_button_plate",
			"abilities": [
				{"id": "padding_bash", "name": "Padding Bash", "kind": "melee",
					"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
					"acc": 86, "dmg": [3, 4], "crit": 0, "effects": {"exposed": 1},
					"self_move": 0, "move": "attack2"},
				{"id": "button_bulwark", "name": "Button Bulwark", "kind": "buff",
					"launch": [1, 2], "target": [1, 2], "target_side": "self", "multi": false,
					"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"thorns": 2},
					"self_move": 0, "move": "skill"},
				SHUNT]}}),
		"AC1: Guard Ragling source keeps both old moves and appends the exact Shield Shunt")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "ragling")
	_check(not foe.is_empty() and foe.get("id") == "ragling" and foe.get("max_hp") == 12
		and foe.get("speed") == 4 and foe.get("dodge") == 8 and foe.get("acc") == 0
		and foe.get("prot") == 0 and foe.get("turns_per_round") == 1
		and StitchedEnemyCatalog.trophy_for(catalog, "ragling") == "ragling_tatter_claw",
		"AC1: canonical loader preserves stats and unique trophy")
	var expected_moves: Array = [RAKE, THREAD]
	_check(foe.get("abilities", []).size() == 2, "AC1: only the original two abilities exist")
	for i in range(mini(foe.get("abilities", []).size(), expected_moves.size())):
		var checked := StitchedParts.validate_ability(expected_moves[i])
		_check(bool(checked.get("ok", false)) and foe["abilities"][i] == checked.get("ability", {}),
			"AC1: source-loaded move %d is precisely the independently validated authored move" % i)


func _battle(seed_value: int, ragling_at_back: bool = false) -> StitchedRules:
	var config := preview.duplicate(true)
	config["seed"] = seed_value
	config["candle"] = 100
	config["parts"].append_array(catalog["parts"].duplicate(true))
	var ragling := StitchedEnemyCatalog.foe_for(catalog, "ragling")
	var guard := StitchedEnemyCatalog.foe_for(catalog, "ragling_guard")
	config["foes"] = [guard, ragling] if ragling_at_back else [ragling, guard]
	var made := StitchedRules.create(config)
	_check(bool(made.get("ok", false)), "AC2: canonical 4v2 battle creates: " + str(made.get("error")))
	if not made.get("ok", false):
		return null
	var b: StitchedRules = made["battle"]
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 2 and b.candle() == 100
		and b.get_unit("ragling").get("rank") == (2 if ragling_at_back else 1),
		"AC2: living four S2 heroes, both real foes and known rank are present")
	for i in range(4):
		var hero: Dictionary = b.get_unit(str(preview["heroes"][i]["id"]))
		_check(hero.get("rank") == i + 1 and hero.get("hp", 0) > 0
			and hero.get("parts", {}).size() == 4,
			"AC2: hero %d occupies real rank with all four S2 sewn parts" % (i + 1))
	return b


func _to(b: StitchedRules, actor_id: String, minimum_round: int = 1) -> bool:
	for step in range(80):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id and b.round_number() >= minimum_round:
			return true
		if not b.pass_turn().get("ok", false):
			return false
	return false


func _reject_unchanged(b: StitchedRules, receipt: Dictionary, before: Dictionary, rng: int,
		note: String) -> void:
	_check(not receipt.get("ok", true) and b.state_snapshot() == before and b.rng_state() == rng,
		"AC3: rejected " + note + " leaves entire battle, turn, thread and RNG unchanged")


func _shoot(seed_value: int) -> Dictionary:
	var b := _battle(seed_value)
	if b == null or not _to(b, "ragling", 2):
		_check(false, "AC2: Ragling reaches its actual round-two foe turn")
		return {}
	var unit := b.get_unit("ragling")
	var initial := b.get_unit("warden")
	_check(b.current_side() == "foe" and b.round_number() >= 2
		and int(initial.get("fray", -1)) == 0 and b.thread_cuts().is_empty(),
		"AC2: real turn has intact thread and a zero-fray living target")
	var state := b.state_snapshot()
	var rng := b.rng_state()
	var intent := StitchedFoeIntent.choose(b, unit)
	_check(intent.get("ability_id") == "loose_thread" and intent.get("target_rank") == 1
		and intent.get("target_side") == "hero" and intent.get("affected_ranks") == [1]
		and intent.get("base_damage") == [0, 0] and intent.get("base_acc") == 88
		and intent.get("base_effects") == {"fray": 5, "snip": 1}
		and not intent.get("pass", true), "AC2: real read-only intent projects the legal Snip+Fray kit")
	_check(b.state_snapshot() == state and b.rng_state() == rng,
		"AC3: legal foe intent consumes no state or RNG")
	var receipt := b.use_foe_ability("loose_thread", 1)
	_check(receipt.get("ok", false) and receipt.get("actor") == "ragling"
		and receipt.get("ability") == "loose_thread" and receipt.get("results", []).size() == 1,
		"AC2: actual canonical foe dispatch commits one target receipt")
	if receipt.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = receipt["results"][0]
	var after := b.get_unit("warden")
	_check(hit.get("target") == "warden" and hit.get("target_rank") == 1
		and hit.has("roll") and hit.get("hit") == (int(hit.get("roll", 101)) <= int(hit.get("hit_chance", 0)))
		and hit.get("damage") == 0 and hit.get("target_hp") == initial.get("hp")
		and not hit.get("crit", true), "AC2/AC3: zero-damage debuff has real bounded hit roll")
	if hit.get("hit", false):
		_check(int(after.get("fray", -1)) == int(initial.get("fray", -1)) + 5
			and hit.get("fray_event", {}).get("change") == 5
			and hit.get("snip") == {"ok": true, "action": "snip", "hero": "warden", "after_rank": 1}
			and b.thread_cuts() == {"warden": 1} and hit.get("statuses", []).is_empty(),
			"AC2: landed Loose Thread applies exactly Fray 5 and a cut behind rank one")
	else:
		_check(after == initial and b.thread_cuts().is_empty()
			and not hit.has("snip") and not hit.has("fray_event")
			and hit.get("statuses", []).is_empty() and hit.get("damage") == 0,
			"AC3: real miss applies neither Fray nor Snip nor another side effect")
	return {"hit": hit.get("hit", false), "receipt": receipt, "snapshot": b.state_snapshot(),
		"rng": b.rng_state(), "battle": b}


func _rake_shoot(seed_value: int) -> Dictionary:
	var b := _battle(seed_value)
	if b == null or not _to(b, "ragling"):
		_check(false, "AC2: Ragling reaches a genuine legal attack turn")
		return {}
	var actor := b.get_unit("ragling")
	var target := b.get_unit("warden")
	var ready := b.current_side() == "foe" and int(actor.get("rank", -1)) == 1 \
		and int(target.get("rank", -1)) == 1 and int(target.get("hp", 0)) > 6 \
		and b.thread_cuts().is_empty()
	_check(ready, "AC2: four-hero/two-foe attack has a living front-rank target and legal launcher")
	if not ready:
		return {}
	var receipt := b.use_foe_ability("rag_rake", 1)
	_check(receipt.get("ok", false) and receipt.get("actor") == "ragling" \
		and receipt.get("actor_side") == "foe" and receipt.get("ability") == "rag_rake" \
		and receipt.get("results", []).size() == 1,
		"AC2: actual foe ability dispatch returns one Rag Rake attack receipt")
	if receipt.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = receipt["results"][0]
	var after := b.get_unit("warden")
	_check(hit.get("target") == "warden" and hit.get("target_rank") == 1 \
		and hit.has("roll") and hit.get("hit") == (int(hit.get("roll", 101)) <= int(hit.get("hit_chance", 0))),
		"AC2: Rag Rake targets the actual front-rank doll and rolls to hit")
	if hit.get("hit", false):
		var allowed_damage: Array = []
		for amount in range(4, 7):
			var base := StitchedS1BEffects.enemy_damage(
				amount + int(actor.get("dmg_bonus", 0)), b.candle())
			allowed_damage.append(StitchedRules.damage_after_modifiers(
				base, actor.get("statuses", {}), target.get("statuses", {}), false, 0,
				int(target.get("prot", 0))))
		var critical_base := StitchedS1BEffects.enemy_damage(
			StitchedRules.crit_damage(6) + int(actor.get("dmg_bonus", 0)), b.candle())
		var critical_damage := StitchedRules.damage_after_modifiers(
			critical_base, actor.get("statuses", {}), target.get("statuses", {}), false, 0,
			int(target.get("prot", 0)))
		var rule_damage := int(hit.get("damage", -1)) == critical_damage if hit.get("crit", false) \
			else allowed_damage.has(int(hit.get("damage", -1)))
		_check(rule_damage and int(hit.get("damage", 0)) > 0 \
			and int(target.get("hp", -1)) - int(after.get("hp", -1)) == int(hit.get("damage", 0)) \
			and int(hit.get("target_hp", -1)) == int(after.get("hp", -1)) \
			and not hit.has("snip") and not hit.has("fray_event") \
			and b.thread_cuts().is_empty(),
			"AC2: hit uses authored [4,6], true crit/PROT/candle rules and actual HP loss; no Thread effects")
	else:
		_check(int(hit.get("damage", -1)) == 0 and after == target \
			and not hit.has("snip") and not hit.has("fray_event") \
			and b.thread_cuts().is_empty(),
			"AC2: missed Rag Rake does not damage, snip or fray")
	return {"hit": bool(hit.get("hit", false)), "receipt": receipt,
		"snapshot": b.state_snapshot(), "rng": b.rng_state()}


func _rake_contract() -> void:
	var witnessed := false
	for seed_value in range(1, 65):
		var first := _rake_shoot(seed_value)
		if first.is_empty():
			return
		if not first["hit"]:
			continue
		witnessed = true
		var again := _rake_shoot(seed_value)
		_check(not again.is_empty() and first["receipt"] == again.get("receipt") \
			and first["snapshot"] == again.get("snapshot") and first["rng"] == again.get("rng"),
			"AC2: same legal Rag Rake seed/actions replay identical receipt, battle state and RNG")
		break
	_check(witnessed, "AC2: bounded real Rag Rake hit witness exists")


func _seeded_contract() -> void:
	var saw_hit := false
	var saw_miss := false
	for seed_value in range(1, 97):
		var first := _shoot(seed_value)
		if first.is_empty():
			return
		var again := _shoot(seed_value)
		_check(not again.is_empty() and first["receipt"] == again.get("receipt")
			and first["snapshot"] == again.get("snapshot") and first["rng"] == again.get("rng"),
			"AC3: exactly replayed seeded result, complete battle state and RNG: %d" % seed_value)
		if first["hit"] and not saw_hit:
			saw_hit = true
			var b: StitchedRules = first["battle"]
			_check(_to(b, "warden"), "AC2: snipped owner gets an actual hero turn")
			var state := b.state_snapshot()
			var rng := b.rng_state()
			_reject_unchanged(b, b.move(1), state, rng, "Move while snipped")
			var turn_before := b.state_snapshot()
			var tied := b.re_tie()
			var turn_after := b.state_snapshot()
			_check(tied == {"ok": true, "action": "re_tie", "actor": "warden"}
				and b.thread_cuts().is_empty()
				and (turn_after["round"] != turn_before["round"]
					or turn_after["turn_index"] != turn_before["turn_index"]),
				"AC2: the snipped doll alone Re-ties, consuming a real turn")
			_check(_to(b, "warden"), "AC2: Re-tied doll reaches its next real turn")
			_check(b.move(1).get("ok", false) and b.get_unit("warden").get("rank") == 2,
				"AC2: same formerly blocked Move now legally changes ranks")
		elif not first["hit"]:
			saw_miss = true
		if saw_hit and saw_miss:
			break
	_check(saw_hit and saw_miss, "AC2/AC3: bounded real seeded hit AND miss witnesses both exist")


func _refusals() -> void:
	var b := _battle(31)
	if b == null:
		return
	_check(b.current_side() == "hero", "AC3: hero-side wrong-actor precondition is real")
	var before := b.state_snapshot()
	var rng := b.rng_state()
	_reject_unchanged(b, b.use_foe_ability("loose_thread", 1), before, rng,
		"hero actor calls foe ability")
	_check(_to(b, "ragling", 2), "AC3: Ragling reaches legitimate foe turn for bad-target checks")
	before = b.state_snapshot()
	rng = b.rng_state()
	_reject_unchanged(b, b.use_foe_ability("not_a_move", 1), before, rng, "unknown ability")
	_reject_unchanged(b, b.use_foe_ability("rag_rake", 2), before, rng,
		"Rag Rake cannot target rank two")
	for rank in [0, 3, 4, 5]:
		_reject_unchanged(b, b.use_foe_ability("loose_thread", rank), before, rng,
			"illegal target rank %d" % rank)
	# Remove a real hero through Fray/Hanging/Lost, leaving a legal target mask
	# rank unoccupied. The following refusal cannot consume the actual foe turn.
	var empty := _battle(33)
	if empty != null:
		empty.apply_fray_event("seamstress", 200)
		empty.apply_fray_event("seamstress", 50)
		_check(empty.get_unit("seamstress").get("lost", false)
			and _to(empty, "ragling", 2), "AC3: legal target rank two has no living doll")
		before = empty.state_snapshot()
		rng = empty.rng_state()
		_reject_unchanged(empty, empty.use_foe_ability("loose_thread", 2), before, rng,
			"valid rank with no living target")
	var rear := _battle(37, true)
	if rear != null:
		_check(_to(rear, "ragling", 2) and rear.get_unit("ragling").get("rank") == 2,
			"AC3: actual Ragling at illegal launch rank two gets its foe turn")
		before = rear.state_snapshot()
		rng = rear.rng_state()
		_reject_unchanged(rear, rear.use_foe_ability("loose_thread", 1), before, rng,
			"illegal actor launch rank")
		var projected := StitchedFoeIntent.choose(rear, rear.get_unit("ragling"))
		_check(projected.get("ability_id") != "loose_thread"
			and rear.state_snapshot() == before and rear.rng_state() == rng,
			"AC3: legal intent never falsely projects Loose Thread from rank two")
