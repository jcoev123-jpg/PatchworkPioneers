extends SceneTree
## Canonical Moth Queen Moth Veil (multi-target ally Dodge) through the real enemy catalog,
## the seeded StitchedRules battle, StitchedFoeIntent and the public turn actions.
##
## The Queen's wing dust shields her and every living accompanying foe for one turn. Every
## witness comes from authentic seeded turns (pass_turn, use_foe_ability, use_part), never
## from a fabricated effect call or an unseeded roll.

const BOSSES := "res://data/enemies/boss.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const DUST := {
	"id": "queen_dust", "name": "Queen Dust", "kind": "ranged",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 85, "dmg": [3, 5], "crit": 0, "effects": {"weak": 1, "blind": 1},
	"self_move": 0, "move": "attack2",
}
const DIVE := {
	"id": "queen_dive", "name": "Pin Crown Dive", "kind": "melee",
	"launch": [1, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [6, 8], "crit": 0,
	"effects": {"tangled": 2, "snip": 1, "mark": 3},
	"self_move": 0, "move": "attack3",
}
const DEVOUR := {
	"id": "queen_devour", "name": "Devour", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [7, 9], "crit": 0, "mark_damage": 3, "effects": {"bleed": 2},
	"self_move": 0, "move": "attack4",
}
const VEIL := {
	"id": "moth_veil", "name": "Moth Veil", "kind": "buff",
	"launch": [1, 3], "target": [1, 2, 3, 4], "target_side": "ally", "multi": true,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"dodge": 8, "duration": 1},
	"self_move": 0, "move": "skill",
}
const LEGACY := {
	"target": "front", "actions": [
		{"type": "attack", "amount": 5, "weight": 4},
		{"type": "summon", "amount": 0, "weight": 2},
		{"type": "attack", "amount": 6, "hits": 2, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 9, "move": "attack3", "weight": 1},
		{"type": "attack", "amount": 10, "move": "attack4", "weight": 1},
	],
}
const PAIR := ["moth_queen", "scissor_crab"]
const TRIO := ["moth_queen", "scissor_crab", "moth_scribe"]

var failures: Array[String] = []
var checks := 0
## False while a bounded seed probe looks for a battle whose authentic order can witness the
## one-turn buff; those probes must not record assertions.
var recording := true


func _initialize() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	_expect(catalog.get("ok", false), "the real enemy/part catalog validates")
	_test_source(catalog)
	if catalog.get("ok", false):
		_test_combat(catalog, PAIR)
		_test_combat(catalog, TRIO)
		_test_launch_refusal(catalog)
		_test_emergency_priority(catalog, PAIR, "scissor_crab", "rank-one")
		_test_emergency_priority(catalog, ["scissor_crab", "moth_scribe", "moth_queen"],
			"scissor_crab", "rank-three")
		_test_emergency_negatives(catalog)
	if failures.is_empty():
		print("stitched_s5_moth_queen_veil_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s5_moth_queen_veil_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> bool:
	if recording:
		checks += 1
		if not condition:
			failures.append(message)
	return condition


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _ability(unit: Dictionary, ability_id: String) -> Dictionary:
	for ability in unit.get("abilities", []):
		if str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _ability_ids(unit: Dictionary) -> Array:
	var ids: Array = []
	for ability in unit.get("abilities", []):
		ids.append(str(ability.get("id", "")))
	return ids


func _test_source(catalog: Dictionary) -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSSES))
	_expect(records is Array, "AC1: the boss source parses as an array")
	if not records is Array:
		return
	var matches: Array = records.filter(func(record: Dictionary) -> bool: return record.get("id") == "moth_queen")
	_expect(matches.size() == 1, "AC1: exactly one Moth Queen record")
	if matches.size() != 1:
		return
	var queen: Dictionary = matches[0]
	_expect(queen.get("name") == "Moth Queen" and int(queen.get("max_hp", 0)) == 90
		and queen.get("art_path") == "res://assets/paper/enemies/moth_queen.png"
		and queen.get("intent") == _json(LEGACY),
		"AC1: the Queen keeps her name, legacy HP, art and all five legacy actions")
	var expected := {"max_hp": 90, "speed": 6, "dodge": 10, "acc": 0, "prot": 4, "is_boss": true,
		"turns_per_round": 2, "trophy": "moth_queen_wing_crown",
		"abilities": [DUST, DIVE, DEVOUR, VEIL]}
	_expect(queen.get("stitched") == _json(expected),
		"AC1: exact Veil kit preserved; Dive carries Tangled 2, SNIP 1 and Mark 3, Devour carries Mark damage 3")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "moth_queen")
	_expect(not foe.is_empty(), "AC1: the canonical Queen foe loads")
	if foe.is_empty():
		return
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_expect(foe.get(key) == expected[key], "AC1: the loaded Queen stat stays exact: " + key)
	_expect(StitchedEnemyCatalog.trophy_for(catalog, "moth_queen") == "moth_queen_wing_crown",
		"AC1: the Queen keeps her wing-crown trophy")
	var normalized: Array = []
	for ability in [DUST, DIVE, DEVOUR, VEIL]:
		var validated := StitchedParts.validate_ability(ability)
		_expect(validated.get("ok", false), "AC1: the independent expected ability validates")
		if validated.get("ok", false):
			normalized.append(validated["ability"])
	_expect(foe.get("abilities") == normalized,
		"AC1: the loader exposes the exact normalized legal kit in authored order")
	var veil := _ability(foe, "moth_veil")
	_expect(not veil.is_empty(), "AC1: Moth Veil is in the normalized Queen kit")
	if not veil.is_empty():
		_expect(veil.get("name") == "Moth Veil" and veil.get("kind") == "buff"
			and veil.get("launch") == [1, 3] and veil.get("target") == [1, 2, 3, 4]
			and veil.get("target_side") == "ally" and veil.get("multi") == true
			and int(veil.get("acc", 0)) == 100 and veil.get("dmg") == [0, 0]
			and int(veil.get("crit", -1)) == 0 and veil.get("effects") == {"dodge": 8, "duration": 1}
			and int(veil.get("self_move", -1)) == 0 and veil.get("move") == "skill"
			and int(veil.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
			and int(veil.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3, 4]),
			"AC1: Veil keeps launch [1,3], ACC 100, 0 damage and Dodge 8 / 1, now on every ally rank")
	for expected_move in [DUST, DIVE, DEVOUR]:
		var ability := _ability(foe, str(expected_move["id"]))
		_expect(not ability.is_empty() and ability.get("launch") == expected_move["launch"]
			and ability.get("target") == expected_move["target"]
			and ability.get("target_side") == expected_move["target_side"]
			and ability.get("multi") == expected_move["multi"] and int(ability.get("acc", 0)) == int(expected_move["acc"])
			and ability.get("dmg") == expected_move["dmg"]
			and ability.get("effects") == expected_move["effects"]
			and ability.get("move") == expected_move["move"],
			"AC1: the Queen's other named move stays literal: " + str(expected_move["id"]))
	var behemoth := StitchedEnemyCatalog.foe_for(catalog, "patchwork_behemoth")
	_expect(not behemoth.is_empty() and int(behemoth.get("max_hp", 0)) == 84
		and int(behemoth.get("speed", 0)) == 5 and int(behemoth.get("prot", 0)) == 10
		and StitchedEnemyCatalog.trophy_for(catalog, "patchwork_behemoth") == "patchwork_behemoth_heart_torso"
		and _ability_ids(behemoth) == ["behemoth_maul", "stuffing_hurl", "rope_lash", "stitch_ward"],
		"AC1: Patchwork Behemoth keeps its id, stats, trophy and named moves")
	var colossus := StitchedEnemyCatalog.foe_for(catalog, "sewing_machine_colossus")
	_expect(not colossus.is_empty() and int(colossus.get("max_hp", 0)) == 96
		and int(colossus.get("speed", 0)) == 4 and int(colossus.get("prot", 0)) == 14
		and StitchedEnemyCatalog.trophy_for(catalog, "sewing_machine_colossus") == "sewing_machine_colossus_needle_arm"
		and _ability_ids(colossus) == ["colossus_treadle", "colossus_bobbin", "colossus_barrage", "colossus_guard"],
		"AC1: Sewing-Machine Colossus keeps its id, stats, trophy and named moves")
	_expect(ResourceLoader.exists("res://assets/paper/enemies/moth_queen.png"),
		"AC1: the existing Queen sprite carries the move (no new art)")


func _battle(catalog: Dictionary, seed_value: int, ids: Array) -> StitchedRules:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_expect(preview is Dictionary, "the shipped four-doll preview exists")
	if not preview is Dictionary:
		return null
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id))
		_expect(not foe.is_empty(), "a real canonical foe loads: " + str(enemy_id))
		foes.append(foe)
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"])
	var created := StitchedRules.create({"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": preview["heroes"].duplicate(true), "parts": parts, "foes": foes})
	_expect(created.get("ok", false), "the real seeded battle builds: " + str(created.get("error")))
	if not created.get("ok", false):
		return null
	var battle: StitchedRules = created["battle"]
	_expect(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size(),
		"four dolls face two or three canonical foes")
	return battle


## Passes authentic turns until the Queen owns a live turn. Every other turn also asks for
## Moth Veil and proves the wrong side/wrong foe refusal spends no state, turn or RNG.
func _reach_queen(battle: StitchedRules, target_round: int, receipts: Array) -> bool:
	for step in range(240):
		if battle.is_over():
			break
		var actor_id := battle.current_actor_id()
		if actor_id == "moth_queen":
			if battle.round_number() == target_round:
				return true
			if battle.round_number() > target_round:
				break
		else:
			var actor := battle.get_unit(actor_id)
			var snapshot := battle.state_snapshot()
			var rng := battle.rng_state()
			var wrong := battle.use_foe_ability("moth_veil", 1)
			var error := "it is not a foe turn" if str(actor.get("side", "")) == "hero" \
				else "the foe has no ability moth_veil"
			_expect(not wrong.get("ok", true) and wrong.get("error") == error
				and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
				"AC4: a wrong-side/wrong-turn Veil request is refused without state/RNG/turn spend")
			receipts.append(wrong)
		var passed := battle.pass_turn()
		if not _expect(passed.get("ok", false), "AC4: a legal pass advances the real turn"):
			return false
		receipts.append(passed)
	_expect(false, "AC4: a bounded pass schedule reaches the Queen's round-%d turn" % target_round)
	return false


func _test_combat(catalog: Dictionary, ids: Array) -> void:
	recording = false
	var chosen := 0
	for seed_value in range(1, 81):
		if not _veil_script(catalog, seed_value, ids).is_empty():
			chosen = seed_value
			break
	recording = true
	_expect(chosen > 0, "AC2/AC3: a seeded %d-foe battle witnesses the veil, a real hit chance and every expiry"
		% ids.size())
	if chosen == 0:
		return
	var first := _veil_script(catalog, chosen, ids)
	_expect(not first.is_empty(), "AC2/AC3: the recorded seeded veil script completes")
	if first.is_empty():
		return
	recording = false
	var replay := _veil_script(catalog, chosen, ids)
	recording = true
	_expect(not replay.is_empty() and first == replay,
		"AC5: the same seed and legal action script replay receipts, snapshots, order and RNG exactly")


## One complete seeded veil script: round-four chooser projection, a refused rank/turn/launch,
## the multi-target Dodge receipt, a real hero hit chance against the buff, and each recipient's
## one-turn expiry through public turns.
func _veil_script(catalog: Dictionary, seed_value: int, ids: Array) -> Dictionary:
	var battle := _battle(catalog, seed_value, ids)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _reach_queen(battle, 4, receipts):
		return {}
	var expected_ranks: Array = []
	for index in range(ids.size()):
		expected_ranks.append(index + 1)
		var starting := battle.get_unit(str(ids[index]))
		_expect(not starting.is_empty() and int(starting.get("rank", 0)) == index + 1,
			"AC2: " + str(ids[index]) + " starts in foe rank %d" % (index + 1))
	_expect(battle.turn_order().count("moth_queen") == 2,
		"AC3: the boss keeps exactly two seeded turns in the round")

	for rank in [0, 5]:
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var rejected := battle.use_foe_ability("moth_veil", rank)
		_expect(not rejected.get("ok", true) and rejected.get("error") == "no legal target in rank %d" % rank
			and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
			"AC4: target rank %d is refused without state/RNG/turn spend" % rank)
		receipts.append(rejected)

	# The real projection for the Queen's genuine round-four rotation.
	var before_intent := battle.state_snapshot()
	var rng_intent := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	_expect(before_intent == battle.state_snapshot() and rng_intent == battle.rng_state(),
		"AC4: the chooser never changes battle state or RNG")
	_expect(not intent.is_empty() and intent.get("pass") == false
		and intent.get("ability_id") == "moth_veil" and intent.get("ability_name") == "Moth Veil"
		and intent.get("ability_kind") == "buff" and intent.get("target_side") == "foe"
		and intent.get("affected_ranks") == expected_ranks and intent.get("multi") == true
		and int(intent.get("base_acc", 0)) == 100 and intent.get("base_damage") == [0, 0]
		and int(intent.get("base_crit", -1)) == 0
		and intent.get("base_effects") == {"dodge": 8, "duration": 1},
		"AC4: the chooser advertises Moth Veil on every occupied foe rank with Dodge 8 / 1")
	_expect(int(intent.get("target_rank", 0)) == 1,
		"AC4: the projection aims at the first ally rank")
	if intent.get("ability_id") != "moth_veil":
		return {}
	if not intent.get("base_effects", {}).is_empty():
		intent["base_effects"]["dodge"] = 99
	_expect(StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen")).get("base_effects")
		== {"dodge": 8, "duration": 1}, "AC4: editing a projection cannot edit the live ability")
	for bogus in [{}, battle.get_unit("warden")]:
		var ignored := StitchedFoeIntent.choose(battle, bogus)
		_expect(ignored.is_empty() and before_intent == battle.state_snapshot()
			and rng_intent == battle.rng_state(),
			"AC4: a pass/detached/hero projection request is refused without mutation")

	var foes_before: Array = battle.get_foes()
	var hero_dodge: Dictionary = {}
	for hero in battle.get_heroes():
		hero_dodge[str(hero["id"])] = StitchedRules.effective_dodge(hero)
	var base_dodge: Dictionary = {}
	for foe in foes_before:
		base_dodge[str(foe["id"])] = int(foe["dodge"])

	var round_before := battle.round_number()
	var rng_before := battle.rng_state()
	var order_before := battle.turn_order()
	var receipt: Dictionary = battle.use_foe_ability("moth_veil", 1)
	receipts.append(receipt)
	if not _expect(receipt.get("ok", false) and receipt.get("actor") == "moth_queen"
		and receipt.get("ability") == "moth_veil" and receipt.get("results", []).size() == ids.size(),
		"AC2: one Moth Veil resolves once for every living foe"):
		return {}
	if round_before == battle.round_number():
		_expect(battle.rng_state() == rng_before, "AC3: the veil inside a round draws no RNG")
		_expect(battle.turn_order() == order_before, "AC3: the veil never changes the seeded turn order")
	elif not recording:
		return {}

	var ranks: Array = []
	var targets: Array = []
	for result in receipt["results"]:
		ranks.append(int(result["target_rank"]))
		targets.append(str(result["target"]))
		var old: Dictionary = {}
		for foe in foes_before:
			if str(foe["id"]) == str(result["target"]):
				old = foe
		_expect(not old.is_empty() and int(old["rank"]) == int(result["target_rank"]),
			"AC2: each receipt names the foe in its own rank")
		var now := battle.get_unit(str(result["target"]))
		_expect(result.get("target_side") == "foe" and result.get("hit") == true
			and int(result.get("damage", -1)) == 0 and int(result.get("target_hp", -1)) == int(old["hp"])
			and not result.has("roll") and result.get("crit") == false,
			"AC2: veil is a 0-damage hit that never rolls to hit")
		_expect(result.get("statuses") == [{"status": "dodge", "amount": 8, "duration": 1}],
			"AC2: the receipt reports exactly Dodge 8 / duration 1")
		# The self-cast turn already consumed the Queen's skip, so her protection survives it.
		_expect(now.get("dodge_buff") == {"amount": 8, "turns": 1, "skip": false},
			"AC2/AC3: the temporary buff is installed and the self-cast skip is spent")
		_expect(int(now["dodge"]) == int(old["dodge"])
			and StitchedRules.effective_dodge(now) == int(old["dodge"]) + 8,
			"AC3: effective Dodge rises by eight while the permanent stat stays")
		_expect(int(now["hp"]) == int(old["hp"]) and not now["statuses"].has("dodge"),
			"AC2: no HP damage or permanent status leaks into the foe")
	ranks.sort()
	targets.sort()
	var expected_ids: Array = ids.duplicate()
	expected_ids.sort()
	_expect(ranks == expected_ranks, "AC2: every occupied foe rank gets the veil with no empty-rank result")
	_expect(targets == expected_ids, "AC2: each living foe is veiled exactly once")
	for hero in battle.get_heroes():
		_expect(hero["dodge_buff"].is_empty()
			and StitchedRules.effective_dodge(hero) == int(hero_dodge.get(str(hero["id"]), -1))
			and not hero["statuses"].has("dodge"), "AC2: the veil never buffs a hero")
	for foe in battle.get_foes():
		var old: Dictionary = {}
		for before in foes_before:
			if str(before["id"]) == str(foe["id"]):
				old = before
		_expect(not old.is_empty() and foe["name"] == old["name"] and int(foe["rank"]) == int(old["rank"])
			and int(foe["hp"]) == int(old["hp"]) and int(foe["max_hp"]) == int(old["max_hp"])
			and foe["abilities"] == old["abilities"],
			"AC3: " + str(foe["id"]) + " keeps its identity, HP, rank and authored actions")

	var witnessed := _witness_turns(battle, receipts, ids, base_dodge)
	if not bool(witnessed.get("hit", false)):
		return {}
	for foe_id in ids:
		if not bool(witnessed.get("expired", {}).get(foe_id, false)):
			return {}
	return {"receipts": receipts, "order": battle.turn_order(), "heroes": battle.get_heroes().duplicate(true),
		"foes": battle.get_foes().duplicate(true), "state": battle.state_snapshot(), "rng": battle.rng_state()}


## Public turns only: a hero's real attack proves the buffed effective Dodge feeds hit chance,
## then each recipient spends its own turn and its one-turn veil expires.
func _witness_turns(battle: StitchedRules, receipts: Array, ids: Array, base_dodge: Dictionary) -> Dictionary:
	var hit := false
	var expired: Dictionary = {}
	for foe_id in ids:
		expired[foe_id] = false
	for step in range(200):
		if battle.is_over():
			break
		var actor_id := battle.current_actor_id()
		var actor := battle.get_unit(actor_id)
		if str(actor.get("side", "")) == "foe":
			if not actor["dodge_buff"].is_empty():
				_expect(StitchedRules.effective_dodge(actor) == int(actor["dodge"]) + 8
					and int(actor["dodge"]) == int(base_dodge.get(actor_id, -1)),
					"AC3: " + actor_id + "'s veil is still active at its own turn")
				var passed := battle.pass_turn()
				receipts.append(passed)
				if not _expect(passed.get("ok", false), "AC3: a legal pass spends the veil holder's turn"):
					break
				var after := battle.get_unit(actor_id)
				_expect(after["dodge_buff"].is_empty()
					and StitchedRules.effective_dodge(after) == int(base_dodge.get(actor_id, -1))
					and int(after["dodge"]) == int(base_dodge.get(actor_id, -1)),
					"AC3: " + actor_id + "'s one-turn veil expires after its turn and leaves no permanent Dodge")
				expired[actor_id] = true
			else:
				var passed_other := battle.pass_turn()
				receipts.append(passed_other)
				if not _expect(passed_other.get("ok", false), "AC3: a legal pass advances a foe turn"):
					break
		else:
			if not hit:
				var target_id := ""
				for foe_id in ids:
					var foe := battle.get_unit(str(foe_id))
					if not foe["dodge_buff"].is_empty():
						target_id = str(foe_id)
						break
				if not target_id.is_empty():
					var spent := _attack_buffed(battle, target_id, receipts)
					if spent == 1:
						hit = true
						continue
					if spent == 2:
						continue
			var passed_hero := battle.pass_turn()
			receipts.append(passed_hero)
			if not _expect(passed_hero.get("ok", false), "AC3: a legal pass advances a hero turn"):
				break
		var done := hit
		for foe_id in ids:
			done = done and bool(expired.get(foe_id, false))
		if done:
			break
	_expect(hit, "AC3: a real hero attack resolves against a veil-buffed foe")
	for foe_id in ids:
		_expect(bool(expired.get(foe_id, false)),
			"AC3: " + str(foe_id) + "'s veil lifetime ends through its own public turn")
	return {"hit": hit, "expired": expired}


## One real hero part attack at the buffed foe. Returns 1 when the target's result witnessed
## the hit chance, 2 when the turn was spent on a different outcome, 0 when no part could fire.
func _attack_buffed(battle: StitchedRules, foe_id: String, receipts: Array) -> int:
	var foe := battle.get_unit(foe_id)
	var foe_rank := int(foe["rank"])
	var hero := battle.get_unit(battle.current_actor_id())
	var before_dodge := StitchedRules.effective_dodge(foe)
	var base_dodge := int(foe["dodge"])
	var accuracy := int(hero["acc"])
	var streak := int(hero["miss_streak"])
	for slot in ["arms", "head", "legs", "torso"]:
		var equipped: Dictionary = hero["parts"].get(slot, {})
		if equipped.is_empty() or bool(equipped.get("torn", false)):
			continue
		var ability := StitchedParts.ability_at_tier(battle._parts[equipped["id"]], int(equipped["tier"]))
		if ability.is_empty() or str(ability["target_side"]) != "enemy" or int(ability["dmg"][1]) <= 0:
			continue
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(hero["rank"])):
			continue
		if not StitchedParts.ranks_allowed(int(ability["target_mask"]), foe_rank):
			continue
		if not battle._self_move_gate(hero, ability).is_empty():
			continue
		var receipt := battle.use_part(str(equipped["id"]), foe_rank)
		if not receipt.get("ok", false):
			continue  # A refused part changed nothing, so the next one may still fire.
		receipts.append(receipt)
		var found := false
		for result in receipt.get("results", []):
			if str(result.get("target", "")) != foe_id:
				continue
			found = true
			var expected := StitchedRules.hit_chance(int(ability["acc"]) + accuracy, before_dodge, streak)
			var unbuffed := StitchedRules.hit_chance(int(ability["acc"]) + accuracy, base_dodge, streak)
			_expect(int(result.get("hit_chance", -1)) == expected,
				"AC3: the real attack's hit chance uses the target's effective Dodge")
			_expect(before_dodge == base_dodge + 8 and unbuffed == expected + 8,
				"AC3: the veil's +8 lowers that real hit chance by exactly eight points")
			_expect(result.has("roll") and result.get("hit") == (int(result["roll"]) <= int(result["hit_chance"])),
				"AC3: the seeded roll still resolves against the real hit chance")
		return 1 if found else 2
	return 0


## A Queen standing outside her launch ranks [1,3] cannot veil, and the refused attempt
## leaves her turn and the whole battle untouched.
func _test_launch_refusal(catalog: Dictionary) -> void:
	recording = true
	var battle := _battle(catalog, 5, ["ragling", "moth_queen"])
	if battle == null:
		return
	var receipts: Array = []
	for step in range(120):
		if battle.is_over() or battle.current_actor_id() == "moth_queen":
			break
		if not _expect(battle.pass_turn().get("ok", false), "AC4: a legal pass reaches the rank-2 Queen"):
			return
	_expect(battle.current_actor_id() == "moth_queen", "AC4: the authentic Queen reaches a real turn")
	if battle.current_actor_id() != "moth_queen":
		return
	_expect(int(battle.get_unit("moth_queen")["rank"]) == 2, "AC4: the authentic Queen stands in foe rank 2")
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var rejected := battle.use_foe_ability("moth_veil", 1)
	_expect(not rejected.get("ok", true) and rejected.get("error") == "ability cannot launch from rank 2"
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: a launch rank outside [1,3] is refused without state/RNG/turn spend")
	receipts.append(rejected)
	var valid := battle.use_foe_ability("queen_devour", 1)
	_expect(valid.get("ok", false) and valid.get("ability") == "queen_devour",
		"AC4: the refused veil leaves the Queen's real turn intact")
## ------------------------------------------------------------------ Emergency escort veil.
##
## A critically wounded living escort makes the real Queen project Moth Veil ahead of the
## round's ordinary rotation. Every wound below is dealt by an authentic hero part attack in
## the seeded battle; nothing here edits _units or fabricates an effect receipt.

func _test_emergency_priority(catalog: Dictionary, ids: Array, escort_id: String, note: String) -> void:
	var chosen := _find_emergency_seed(catalog, ids, escort_id)
	_expect(chosen > 0, "AC1/AC2: a bounded seeded %s Queen battle honestly wounds an escort" % note)
	if chosen == 0:
		return
	var first := _emergency_script(catalog, chosen, ids, escort_id, true)
	_expect(not first.is_empty(), "AC1/AC2: the real %s emergency Veil script completes" % note)
	if first.is_empty():
		return
	recording = false
	var replay := _emergency_script(catalog, chosen, ids, escort_id, true)
	recording = true
	_expect(not replay.is_empty() and first == replay,
		"AC4: identical seed, wounds, legal turns and cast replay the %s intent, receipts, state and RNG" % note)
	_driver_emergency(catalog, chosen, ids, escort_id, note)


## The real mounted battle screen's own foe driver must commit the same emergency Veil, not
## only the read-only projection: the screen already dispatches choose() through
## StitchedRules.use_foe_ability().
func _driver_emergency(catalog: Dictionary, seed_value: int, ids: Array, escort_id: String,
		note: String) -> void:
	var stage := StitchedBattleScreen.new()
	var started := stage.begin(_screen_config(catalog, seed_value, ids))
	_expect(started and stage.battle != null,
		"AC1: the live battle screen accepts the %s emergency fight" % note)
	if stage.battle == null:
		stage.free()
		return
	var setup_receipts: Array = []
	if not _wound_escort(stage.battle, escort_id, setup_receipts) \
			or not _to_queen(stage.battle, 3, setup_receipts):
		_expect(false, "AC1: the live screen fight reaches the %s emergency Queen turn" % note)
		stage.free()
		return
	stage._drive_foes()
	var veiled := false
	for receipt in stage.receipts:
		if str(receipt.get("actor", "")) != "moth_queen" \
				or str(receipt.get("ability", "")) != "moth_veil":
			continue
		veiled = bool(receipt.get("ok", false)) \
			and receipt.get("results", []).size() == ids.size()
	_expect(veiled, "AC1/AC2: the live foe driver commits the %s emergency Moth Veil" % note)
	stage.free()


func _screen_config(catalog: Dictionary, seed_value: int, ids: Array) -> Dictionary:
	var preview: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	if not preview is Dictionary:
		return {}
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id))
		if foe.is_empty():
			return {}
		foes.append(foe)
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"])
	return {"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": preview["heroes"].duplicate(true), "parts": parts, "foes": foes}


func _find_emergency_seed(catalog: Dictionary, ids: Array, escort_id: String) -> int:
	recording = false
	var found := 0
	for seed_value in range(1, 49):
		if not _emergency_script(catalog, seed_value, ids, escort_id, false).is_empty():
			found = seed_value
			break
	recording = true
	return found


## One complete emergency script: authentic hero hits wound a real escort to at most half HP,
## the Queen's live projection then prioritises Veil over its rotation, the real cast veils
## every living foe, an already-veiled escort drops the emergency, and each veil expires at
## the recipient's own public turn.
func _emergency_script(catalog: Dictionary, seed_value: int, ids: Array, escort_id: String,
		deep: bool) -> Dictionary:
	var battle := _battle(catalog, seed_value, ids)
	if battle == null:
		return {}
	var receipts: Array = []
	var wound := _wound_escort(battle, escort_id, receipts)
	if not bool(wound.get("ok", false)):
		return {}
	if not _to_queen(battle, 3, receipts):
		return {}
	var queen := battle.get_unit("moth_queen")
	var escort := battle.get_unit(escort_id)
	var round_value := battle.round_number()
	var expected := _expected_rotation(battle, queen)
	if expected.is_empty() or expected == "moth_veil":
		return {}
	if int(queen.get("rank", 0)) not in [1, 3]:
		return {}
	if not _is_critical_escort(escort):
		return {}
	_expect(int(wound.get("hits", 0)) > 0,
		"AC1: authentic legal hero hits, not a forged wound, lowered the real escort")
	_expect(round_value >= 1 and round_value <= 3,
		"AC1: the emergency turn is a real round where the ordinary rotation is not Veil")
	var occupied := _occupied_foe_ranks(battle, ids)
	if occupied.is_empty():
		return {}
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, queen)
	_expect(snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: the emergency projection mutates no state and draws no RNG")
	_expect(not intent.is_empty() and not bool(intent.get("pass", true))
		and str(intent.get("ability_id", "")) == "moth_veil"
		and str(intent.get("ability_name", "")) == "Moth Veil"
		and str(intent.get("ability_kind", "")) == "buff"
		and str(intent.get("target_side", "")) == "foe"
		and intent.get("affected_ranks") == occupied
		and bool(intent.get("multi", false))
		and int(intent.get("base_acc", 0)) == 100
		and intent.get("base_damage") == [0, 0]
		and int(intent.get("base_crit", -1)) == 0
		and intent.get("base_effects") == {"dodge": 8, "duration": 1},
		"AC1: critically wounded escort makes the real Queen project Moth Veil on every living foe rank")
	_expect(str(intent.get("ability_id", "")) != expected,
		"AC1: Veil outranks the ordinary round rotation (%s, not %s)" % [expected, intent.get("ability_id")])
	_expect(int(intent.get("target_rank", 0)) == 1,
		"AC1: the projected Veil aims at the first legal ally rank")
	if str(intent.get("ability_id", "")) != "moth_veil":
		return {}
	var live_probe := intent.duplicate(true)
	live_probe["base_effects"]["dodge"] = 99
	_expect(StitchedFoeIntent.choose(battle, queen).get("base_effects") == {"dodge": 8, "duration": 1}
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: editing a detached emergency projection cannot edit the live ability or battle")

	var foes_before: Array = battle.get_foes()
	var base_dodge: Dictionary = {}
	for foe in foes_before:
		base_dodge[str(foe["id"])] = int(foe["dodge"])
	var hero_dodge: Dictionary = {}
	for hero in battle.get_heroes():
		hero_dodge[str(hero["id"])] = StitchedRules.effective_dodge(hero)
	var order_before := battle.turn_order()
	var receipt: Dictionary = battle.use_foe_ability("moth_veil", int(intent["target_rank"]))
	receipts.append(receipt)
	if not _expect(receipt.get("ok", false) and receipt.get("actor") == "moth_queen"
		and receipt.get("ability") == "moth_veil" and receipt.get("results", []).size() == ids.size(),
		"AC2: the projected Moth Veil really commits once for every living foe"):
		return {}
	_expect(battle.turn_order() == order_before and battle.turn_order().count("moth_queen") == 2,
		"AC2: the emergency cast leaves the seeded order and both boss turns intact")
	var ranks: Array = []
	for result in receipt["results"]:
		ranks.append(int(result["target_rank"]))
		var old: Dictionary = {}
		for foe in foes_before:
			if str(foe["id"]) == str(result["target"]):
				old = foe
		_expect(not old.is_empty() and int(old["rank"]) == int(result["target_rank"]),
			"AC2: each veil receipt names the real foe in its own rank")
		var now := battle.get_unit(str(result["target"]))
		_expect(result.get("target_side") == "foe" and result.get("hit") == true
			and int(result.get("damage", -1)) == 0 and int(result.get("target_hp", -1)) == int(old["hp"])
			and not result.has("roll") and result.get("crit") == false,
			"AC2: veil remains a 0-damage hit that never rolls")
		_expect(result.get("statuses") == [{"status": "dodge", "amount": 8, "duration": 1}],
			"AC2: the receipt reports exactly Dodge 8 / duration 1")
		_expect(now.get("dodge_buff") == {"amount": 8, "turns": 1, "skip": false},
			"AC2: the temporary buff is installed with the self-cast skip spent")
		_expect(int(now["hp"]) == int(old["hp"]) and int(now["rank"]) == int(old["rank"])
			and int(now["dodge"]) == int(old["dodge"])
			and StitchedRules.effective_dodge(now) == int(old["dodge"]) + 8
			and not now["statuses"].has("dodge"),
			"AC2: the veil raises effective Dodge by eight without damage, rank or permanent status")
		_expect(now["abilities"] == old["abilities"],
			"AC2: the cast never rewrites an authored ability")
	ranks.sort()
	_expect(ranks == occupied, "AC2: every occupied foe rank gains the veil and no empty heap does")
	for hero in battle.get_heroes():
		_expect(hero["dodge_buff"].is_empty()
			and StitchedRules.effective_dodge(hero) == int(hero_dodge.get(str(hero["id"]), -1))
			and not hero["statuses"].has("dodge"), "AC2: the emergency veil never buffs a doll")
	if deep:
		_expect(battle.state_snapshot() != snapshot, "AC2: the committed cast is a real state change")

	# The same real battle now carries an already-veiled, still-wounded escort: the emergency
	# must be off at the Queen's next turn, restoring the ordinary round rotation.
	var second_queen := _to_queen(battle, 3, receipts)
	if not second_queen:
		return {}
	var veiled_escort := battle.get_unit(escort_id)
	if not _has_active_veil(veiled_escort):
		return {}
	var expected_second := _expected_rotation(battle, battle.get_unit("moth_queen"))
	if expected_second.is_empty() or expected_second == "moth_veil":
		return {}
	var second_snapshot := battle.state_snapshot()
	var second_rng := battle.rng_state()
	var second_intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	_expect(second_snapshot == battle.state_snapshot() and second_rng == battle.rng_state(),
		"AC4: the already-veiled projection never mutates state or RNG")
	_expect(str(second_intent.get("ability_id", "")) == expected_second
		and str(second_intent.get("ability_id", "")) != "moth_veil",
		"AC3: an already temporary-Dodge-protected wounded escort restores the ordinary rotation")
	_expect(int(veiled_escort.get("hp", 0)) > 0
		and 2 * int(veiled_escort.get("hp", 0)) <= int(veiled_escort.get("max_hp", 0))
		and _has_active_veil(veiled_escort),
		"AC3: the escort is still critically wounded while its temp Dodge keeps the emergency off")

	if not _expire_veil(battle, receipts, ids, base_dodge):
		return {}
	return {"receipts": receipts, "order": battle.turn_order(), "state": battle.state_snapshot(),
		"rng": battle.rng_state(), "heroes": battle.get_heroes().duplicate(true),
		"foes": battle.get_foes().duplicate(true), "round": round_value,
		"expected": expected, "hits": int(wound.get("hits", 0)),
		"wound_hp": int(escort["hp"]), "wound_max": int(escort["max_hp"])}


func _wound_escort(battle: StitchedRules, escort_id: String, receipts: Array) -> Dictionary:
	var hits := 0
	for step in range(180):
		if battle.is_over():
			return {}
		var escort := battle.get_unit(escort_id)
		if escort.is_empty() or bool(escort.get("dead", false)) or bool(escort.get("lost", false)) \
				or int(escort.get("hp", 0)) <= 0:
			return {}
		if _is_critical_escort(escort):
			return {"ok": hits > 0, "hits": hits}
		var actor := battle.get_unit(battle.current_actor_id())
		if str(actor.get("side", "")) == "hero":
			var receipt := _attack_foe(battle, actor, escort_id)
			if receipt.is_empty():
				var passed := battle.pass_turn()
				receipts.append(passed)
				if not bool(passed.get("ok", false)):
					return {}
			else:
				receipts.append(receipt)
				for result in receipt.get("results", []):
					if str(result.get("target", "")) == escort_id \
							and bool(result.get("hit", false)) and int(result.get("damage", 0)) > 0:
						hits += 1
		else:
			var passed_other := battle.pass_turn()
			receipts.append(passed_other)
			if not bool(passed_other.get("ok", false)):
				return {}
	return {}


## One real hero part attack on the escort. Returns {} when no worn part can legally fire.
func _attack_foe(battle: StitchedRules, hero: Dictionary, foe_id: String) -> Dictionary:
	var foe := battle.get_unit(foe_id)
	if foe.is_empty() or bool(foe.get("dead", false)) or int(foe.get("hp", 0)) <= 0:
		return {}
	var foe_rank := int(foe.get("rank", 0))
	for slot in ["arms", "head", "legs", "torso"]:
		var equipped: Dictionary = hero.get("parts", {}).get(slot, {})
		if equipped.is_empty() or bool(equipped.get("torn", false)):
			continue
		if not battle._parts.has(str(equipped.get("id", ""))):
			continue
		var ability := StitchedParts.ability_at_tier(
			battle._parts[str(equipped["id"])], int(equipped.get("tier", 1)))
		if ability.is_empty() or str(ability.get("target_side", "")) != "enemy" \
				or int(ability.get("dmg", [0, 0])[1]) <= 0:
			continue
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(hero.get("rank", 0))):
			continue
		if not StitchedParts.ranks_allowed(int(ability["target_mask"]), foe_rank):
			continue
		if not battle._self_move_gate(hero, ability).is_empty():
			continue
		var receipt := battle.use_part(str(equipped["id"]), foe_rank)
		if bool(receipt.get("ok", false)):
			return receipt
	return {}


func _is_critical_escort(unit: Dictionary) -> bool:
	if unit.is_empty() or str(unit.get("side", "")) != "foe":
		return false
	if bool(unit.get("dead", false)) or bool(unit.get("lost", false)):
		return false
	var hp := int(unit.get("hp", 0))
	var maximum := int(unit.get("max_hp", 0))
	if hp <= 0 or maximum <= 0:
		return false
	if 2 * hp > maximum:
		return false
	var buff: Variant = unit.get("dodge_buff", {})
	if buff is Dictionary and not buff.is_empty() \
			and int(buff.get("amount", 0)) > 0 and int(buff.get("turns", 0)) > 0:
		return false
	return true


func _has_active_veil(unit: Dictionary) -> bool:
	var buff: Variant = unit.get("dodge_buff", {})
	return buff is Dictionary and not buff.is_empty() \
		and int(buff.get("amount", 0)) > 0 and int(buff.get("turns", 0)) > 0


func _occupied_foe_ranks(battle: StitchedRules, ids: Array) -> Array:
	var ranks: Array = []
	for enemy_id in ids:
		var foe := battle.get_unit(str(enemy_id))
		if foe.is_empty() or bool(foe.get("dead", false)) or bool(foe.get("lost", false)) \
				or int(foe.get("hp", 0)) <= 0:
			continue
		ranks.append(int(foe.get("rank", 0)))
	ranks.sort()
	return ranks


## The Queen's ordinary round-rotated first legal ability, computed independently from the
## canonical authored kit and the same public legality authority the chooser uses.
func _expected_rotation(battle: StitchedRules, queen: Dictionary) -> String:
	var authored: Array = queen.get("abilities", [])
	if authored.is_empty():
		return ""
	var offset := (battle.round_number() - 1) % authored.size()
	for step in range(authored.size()):
		var ability: Dictionary = authored[(offset + step) % authored.size()]
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(queen.get("rank", 0))):
			continue
		if not battle._self_move_gate(queen, ability).is_empty():
			continue
		for rank in range(1, 5):
			if not battle._legal_targets(queen, ability, rank).is_empty():
				return str(ability.get("id", ""))
	return ""


## Public turns only. Each veiled foe keeps the +8 at its own turn, then its one-turn veil
## expires and leaves the permanent Dodge stat untouched. Heroes only pass, so a wounded
## escort is never killed here.
func _expire_veil(battle: StitchedRules, receipts: Array, ids: Array, base_dodge: Dictionary) -> bool:
	var expired: Dictionary = {}
	for foe_id in ids:
		expired[str(foe_id)] = false
	for step in range(240):
		if battle.is_over():
			return false
		var actor := battle.get_unit(battle.current_actor_id())
		var actor_id := str(actor.get("id", ""))
		if str(actor.get("side", "")) == "foe" and _has_active_veil(actor):
			var base := int(base_dodge.get(actor_id, -1))
			_expect(StitchedRules.effective_dodge(actor) == base + 8,
				"AC2: " + actor_id + "'s emergency veil still feeds effective Dodge at its own turn")
			var passed := battle.pass_turn()
			receipts.append(passed)
			if not _expect(passed.get("ok", false), "AC2: a legal pass spends the veil holder's turn"):
				return false
			var after := battle.get_unit(actor_id)
			_expect(after.get("dodge_buff", {}).is_empty()
				and StitchedRules.effective_dodge(after) == base and int(after.get("dodge", -1)) == base,
				"AC2: " + actor_id + "'s emergency veil expires after its turn with no permanent Dodge")
			expired[actor_id] = true
		else:
			var passed_other := battle.pass_turn()
			receipts.append(passed_other)
			if not _expect(passed_other.get("ok", false), "AC2: a legal pass advances an unveiled turn"):
				return false
		var done := true
		for foe_id in ids:
			done = done and bool(expired.get(str(foe_id), false))
		if done:
			return true
	return false


## ------------------------------------------------------------------ Emergency negatives.

func _test_emergency_negatives(catalog: Dictionary) -> void:
	_expect(_no_damage_negative(catalog), "AC3: no wounded escort keeps the ordinary round rotation")
	_expect(_above_half_negative(catalog), "AC3: an escort above half HP keeps the ordinary rotation")
	_expect(_dead_escort_negative(catalog), "AC3: a dead escort never forces Veil while its living peer is healthy")
	_expect(_solo_queen_negative(catalog), "AC3: a battle with no living escort has the emergency rule off")
	_expect(_illegal_rank_negative(catalog), "AC3: a rank-two Queen never forces an illegal Veil")


func _no_damage_negative(catalog: Dictionary) -> bool:
	var seed_value := _find_negative_seed(catalog, PAIR, "no_damage")
	if seed_value == 0:
		return false
	var battle := _battle(catalog, seed_value, PAIR)
	if battle == null:
		return false
	var receipts: Array = []
	if not _to_queen(battle, 3, receipts):
		return false
	var escort := battle.get_unit("scissor_crab")
	_expect(int(escort.get("hp", 0)) == int(escort.get("max_hp", 0))
		and escort.get("dodge_buff", {}).is_empty(),
		"AC3: the no-damage fixture really reaches the Queen with full, unbuffed escorts")
	var expected := _expected_rotation(battle, battle.get_unit("moth_queen"))
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	_expect(not expected.is_empty() and expected != "moth_veil"
		and str(intent.get("ability_id", "")) == expected
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: with no wounded escort the chooser keeps the original rotation")
	return true


func _above_half_negative(catalog: Dictionary) -> bool:
	var seed_value := _find_negative_seed(catalog, PAIR, "above_half")
	if seed_value == 0:
		return false
	var battle := _battle(catalog, seed_value, PAIR)
	if battle == null:
		return false
	var receipts: Array = []
	if not _one_hit_above_half(battle, "scissor_crab", receipts):
		return false
	if not _to_queen(battle, 3, receipts):
		return false
	var escort := battle.get_unit("scissor_crab")
	_expect(int(escort.get("hp", 0)) > 0 and 2 * int(escort.get("hp", 0)) > int(escort.get("max_hp", 0))
		and escort.get("dodge_buff", {}).is_empty(),
		"AC3: a real landed hit leaves the escort alive, unbuffed and above half HP")
	var expected := _expected_rotation(battle, battle.get_unit("moth_queen"))
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	_expect(not expected.is_empty() and expected != "moth_veil"
		and str(intent.get("ability_id", "")) == expected
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: an escort above half HP never triggers the emergency veil")
	return true


func _one_hit_above_half(battle: StitchedRules, escort_id: String, receipts: Array) -> bool:
	for step in range(140):
		if battle.is_over():
			return false
		var escort := battle.get_unit(escort_id)
		if escort.is_empty() or bool(escort.get("dead", false)) or int(escort.get("hp", 0)) <= 0:
			return false
		if 2 * int(escort.get("hp", 0)) <= int(escort.get("max_hp", 0)):
			return false
		var actor := battle.get_unit(battle.current_actor_id())
		if str(actor.get("side", "")) == "hero":
			var receipt := _attack_foe(battle, actor, escort_id)
			if receipt.is_empty():
				var passed := battle.pass_turn()
				receipts.append(passed)
				if not bool(passed.get("ok", false)):
					return false
			else:
				receipts.append(receipt)
				var landed := false
				for result in receipt.get("results", []):
					if str(result.get("target", "")) == escort_id and bool(result.get("hit", false)) \
							and int(result.get("damage", 0)) > 0:
						landed = true
				if landed:
					var after := battle.get_unit(escort_id)
					return not bool(after.get("dead", false)) and int(after.get("hp", 0)) > 0 \
						and 2 * int(after.get("hp", 0)) > int(after.get("max_hp", 0)) \
						and after.get("dodge_buff", {}).is_empty()
		else:
			var passed_other := battle.pass_turn()
			receipts.append(passed_other)
			if not bool(passed_other.get("ok", false)):
				return false
	return false


func _dead_escort_negative(catalog: Dictionary) -> bool:
	var ids := ["scissor_crab", "moth_scribe", "moth_queen"]
	var seed_value := _find_negative_seed(catalog, ids, "dead_escort")
	if seed_value == 0:
		return false
	var battle := _battle(catalog, seed_value, ids)
	if battle == null:
		return false
	var receipts: Array = []
	if not _kill_escort(battle, "scissor_crab", receipts):
		return false
	if not _to_queen(battle, 3, receipts):
		return false
	var dead := battle.get_unit("scissor_crab")
	var living := battle.get_unit("moth_scribe")
	_expect(bool(dead.get("dead", false)) and int(dead.get("hp", -1)) == 0,
		"AC3: the dead escort really fell to authentic hero hits")
	_expect(not bool(living.get("dead", false)) and int(living.get("hp", 0)) > 0
		and 2 * int(living.get("hp", 0)) > int(living.get("max_hp", 0)),
		"AC3: the surviving peer is alive and above half HP, so only the dead record looks wounded")
	var expected := _expected_rotation(battle, battle.get_unit("moth_queen"))
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	_expect(not expected.is_empty() and expected != "moth_veil"
		and str(intent.get("ability_id", "")) == expected
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: a dead escort never satisfies the emergency, even with 2*HP <= max")
	return true


func _solo_queen_negative(catalog: Dictionary) -> bool:
	var seed_value := _find_negative_seed(catalog, PAIR, "solo_queen")
	if seed_value == 0:
		return false
	var battle := _battle(catalog, seed_value, PAIR)
	if battle == null:
		return false
	var receipts: Array = []
	if not _kill_escort(battle, "scissor_crab", receipts):
		return false
	if not _to_queen(battle, 3, receipts):
		return false
	var living_escorts := 0
	for foe in battle.get_foes():
		if str(foe.get("id", "")) == "moth_queen":
			continue
		if not bool(foe.get("dead", false)) and not bool(foe.get("lost", false)) \
				and int(foe.get("hp", 0)) > 0:
			living_escorts += 1
	_expect(living_escorts == 0, "AC3: the real two-foe fight is reduced to the Queen alone")
	var expected := _expected_rotation(battle, battle.get_unit("moth_queen"))
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	_expect(not expected.is_empty() and expected != "moth_veil"
		and str(intent.get("ability_id", "")) == expected
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: a solo Queen never enters the emergency branch")
	return true


func _illegal_rank_negative(catalog: Dictionary) -> bool:
	var ids := ["ragling", "moth_queen"]
	var seed_value := _find_negative_seed(catalog, ids, "illegal_rank")
	if seed_value == 0:
		return false
	var battle := _battle(catalog, seed_value, ids)
	if battle == null:
		return false
	var receipts: Array = []
	if not _wound_escort(battle, "ragling", receipts):
		return false
	if not _to_queen(battle, 3, receipts):
		return false
	var queen := battle.get_unit("moth_queen")
	_expect(int(queen.get("rank", 0)) == 2,
		"AC3: the authentic Queen stands in illegal veil launch rank 2")
	var expected := _expected_rotation(battle, queen)
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, queen)
	_expect(not expected.is_empty() and expected != "moth_veil"
		and str(intent.get("ability_id", "")) == expected
		and str(intent.get("ability_id", "")) != "moth_veil"
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: the Queen in rank 2 keeps the rotation and never asks for an illegal Veil")
	var rejected := battle.use_foe_ability("moth_veil", 1)
	_expect(not bool(rejected.get("ok", true))
		and rejected.get("error") == "ability cannot launch from rank 2"
		and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: the direct rank-two Veil remains refused with no state or RNG spend")
	return true


func _kill_escort(battle: StitchedRules, escort_id: String, receipts: Array) -> bool:
	for step in range(280):
		if battle.is_over():
			return false
		var escort := battle.get_unit(escort_id)
		if bool(escort.get("dead", false)) or int(escort.get("hp", 0)) <= 0:
			return true
		var actor := battle.get_unit(battle.current_actor_id())
		if str(actor.get("side", "")) == "hero":
			var receipt := _attack_foe(battle, actor, escort_id)
			if receipt.is_empty():
				var passed := battle.pass_turn()
				receipts.append(passed)
				if not bool(passed.get("ok", false)):
					return false
			else:
				receipts.append(receipt)
		else:
			var passed_other := battle.pass_turn()
			receipts.append(passed_other)
			if not bool(passed_other.get("ok", false)):
				return false
	return false


func _find_negative_seed(catalog: Dictionary, ids: Array, kind: String) -> int:
	recording = false
	var found := 0
	for seed_value in range(1, 97):
		if _negative_script(catalog, seed_value, ids, kind):
			found = seed_value
			break
	recording = true
	return found


func _negative_script(catalog: Dictionary, seed_value: int, ids: Array, kind: String) -> bool:
	var battle := _battle(catalog, seed_value, ids)
	if battle == null:
		return false
	var receipts: Array = []
	match kind:
		"no_damage":
			if not _to_queen(battle, 3, receipts):
				return false
		"above_half":
			if not _one_hit_above_half(battle, "scissor_crab", receipts):
				return false
			if not _to_queen(battle, 3, receipts):
				return false
		"dead_escort":
			if not _kill_escort(battle, "scissor_crab", receipts):
				return false
			if not _to_queen(battle, 3, receipts):
				return false
			var peer := battle.get_unit("moth_scribe")
			if bool(peer.get("dead", false)) or int(peer.get("hp", 0)) <= 0 \
					or 2 * int(peer.get("hp", 0)) <= int(peer.get("max_hp", 0)):
				return false
		"solo_queen":
			if not _kill_escort(battle, "scissor_crab", receipts):
				return false
			if not _to_queen(battle, 3, receipts):
				return false
		"illegal_rank":
			if not _wound_escort(battle, "ragling", receipts):
				return false
			if not _to_queen(battle, 3, receipts):
				return false
			if int(battle.get_unit("moth_queen").get("rank", 0)) != 2:
				return false
		_:
			return false
	var expected := _expected_rotation(battle, battle.get_unit("moth_queen"))
	if expected.is_empty() or expected == "moth_veil":
		return false
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	if str(intent.get("ability_id", "")) != expected:
		return false
	return true


func _to_queen(battle: StitchedRules, max_round: int, receipts: Array) -> bool:
	for step in range(160):
		if battle.is_over():
			return false
		if battle.current_actor_id() == "moth_queen":
			return battle.round_number() <= max_round
		if battle.round_number() > max_round:
			return false
		var passed := battle.pass_turn()
		receipts.append(passed)
		if not bool(passed.get("ok", false)):
			return false
	return false
