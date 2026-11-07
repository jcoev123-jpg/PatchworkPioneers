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
	"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [6, 8], "crit": 0, "effects": {"tangled": 2, "snip": 1},
	"self_move": 0, "move": "attack3",
}
const DEVOUR := {
	"id": "queen_devour", "name": "Devour", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [7, 9], "crit": 0, "effects": {"bleed": 2},
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
		"AC1: exact Veil kit preserved; Dive now carries only Tangled 2")
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
