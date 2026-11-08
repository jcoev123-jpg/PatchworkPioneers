extends SceneTree
## Scissor Crab Thread Snip: the chooser spends the snip on the closest LEGAL seam that is
## still whole, falls through to Pinch when every reachable seam is cut, and passes when
## nothing is left. Genuine seeded battles drive the real catalog, chooser and rules; the
## isolated cut-state fixtures are labelled and always exercise real legality authority.

const CRAB := "scissor_crab"
const OTHER := "ragling"
const PINCH := {
	"id": "pinch", "name": "Pinch", "kind": "melee",
	"launch": [1, 2, 3], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [3, 6], "crit": 0, "effects": {"bleed": 2},
	"self_move": 0, "move": "attack2",
}
const SNIP := {
	"id": "thread_snip", "name": "Thread Snip", "kind": "debuff",
	"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "enemy", "multi": false,
	"acc": 92, "dmg": [0, 0], "crit": 0, "effects": {"snip": 1},
	"self_move": 0, "move": "skill",
}

var catalog: Dictionary = {}
var preview: Dictionary = {}
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stitched/s2_preview.json"))
	_check(bool(catalog.get("ok", false)) and parsed is Dictionary,
		"canonical enemy catalog and shipped preview both load")
	if bool(catalog.get("ok", false)) and parsed is Dictionary:
		preview = parsed
		_contract()
		_fresh_thread_progression()
		_missed_snip()
		_isolated_rank_scenarios()
		_pinch_first_round()
		_retied_seam()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_scissor_crab_uncut_thread_priority_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _record(records: Array, id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and str(record.get("id", "")) == id:
			return record
	return {}


## JSON numbers load as floats; normalize both sides before comparing an authored contract.
func _json_equal(actual: Variant, expected: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))


# ---------------------------------------------------------------- AC1 source contract

func _contract() -> void:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	_check(raw is Array, "AC1: the real enemy catalog is an array")
	if not raw is Array:
		return
	var crab := _record(raw, CRAB)
	_check(not crab.is_empty(), "AC1: canonical Scissor Crab record exists")
	if crab.is_empty():
		return
	var expected_profile := {
		"max_hp": 22, "speed": 5, "dodge": 6, "acc": 0, "prot": 8,
		"is_boss": false, "turns_per_round": 1, "trophy": "scissor_crab_claw_arm",
		"abilities": [PINCH, SNIP],
	}
	_check(_json_equal(crab.get("stitched"), expected_profile),
		"AC1: Scissor Crab keeps its exact profile and both authored ability records")
	var legacy := crab.duplicate(true)
	legacy.erase("stitched")
	_check(_json_equal(legacy, {
		"id": "scissor_crab", "name": "Scissor Crab", "max_hp": 26,
		"chew_block_on_attack": true,
		"art_path": "res://assets/paper/enemies/scissor_crab.png",
		"intent": {"target": "front", "actions": [
			{"type": "snip_block", "amount": 0, "weight": 2},
			{"type": "attack", "amount": 6, "hits": 2, "weight": 3},
			{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "hits": 2, "move": "attack3", "weight": 1},
		]},
	}), "AC1: the legacy Scissor Crab record is unchanged")
	var foe := StitchedEnemyCatalog.foe_for(catalog, CRAB)
	var expected_foe := expected_profile.duplicate(true)
	expected_foe.erase("trophy")
	expected_foe.merge({"id": CRAB, "name": "Scissor Crab"})
	for ability in expected_foe["abilities"]:
		ability["launch_mask"] = StitchedParts.rank_mask(ability["launch"])
		ability["target_mask"] = StitchedParts.rank_mask(ability["target"])
		ability["mark_damage"] = 0
	_check(foe == expected_foe,
		"AC1: foe_for preserves the exact stats, both actions, effects and derived masks")
	_check(StitchedEnemyCatalog.trophy_for(catalog, CRAB) == "scissor_crab_claw_arm",
		"AC1: the Scissor Crab trophy is unchanged")
	var abilities: Array = foe.get("abilities", [])
	_check(abilities.size() == 2 and abilities[0]["id"] == "pinch"
		and abilities[0]["target_mask"] == StitchedParts.rank_mask([1, 2])
		and abilities[0]["launch_mask"] == StitchedParts.rank_mask([1, 2, 3])
		and abilities[1]["id"] == "thread_snip"
		and abilities[1]["target_mask"] == StitchedParts.rank_mask([1, 2, 3])
		and abilities[1]["launch_mask"] == StitchedParts.rank_mask([1, 2, 3]),
		"AC1: Pinch reaches ranks 1-2 and Thread Snip ranks 1-3 from ranks 1-3")
	# Shared catalogs grow in parallel: require the ids we depend on, never a total.
	var required_ids := ["scissor_crab", "ragling", "thread_biter", "spool_stalker"]
	var present := 0
	for enemy_id in required_ids:
		if catalog.get("foes", {}).has(enemy_id):
			present += 1
	_check(present == required_ids.size(),
		"AC1: every required canonical foe still validates in the loaded catalog")
	_check(catalog.get("order", []).has(CRAB) and catalog.get("enemies", {}).has(CRAB),
		"AC1: the loaded catalog still owns the Scissor Crab")


# ---------------------------------------------------------------- battle fixtures

func _make_battle(seed_value: int) -> StitchedRules:
	var config: Dictionary = preview.duplicate(true)
	config["parts"].append_array(catalog["parts"].duplicate(true))
	config["seed"] = seed_value
	config["candle"] = 100
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(catalog, CRAB),
		StitchedEnemyCatalog.foe_for(catalog, OTHER),
	]
	var made := StitchedRules.create(config)
	if not bool(made.get("ok", false)):
		return null
	return made["battle"]


func _to(b: StitchedRules, actor_id: String, minimum_round: int, receipts: Array) -> bool:
	for step in range(120):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id and b.round_number() >= minimum_round:
			return true
		var passed := b.pass_turn()
		receipts.append(passed)
		if not bool(passed.get("ok", false)):
			return false
	return false


func _hero_id_at(b: StitchedRules, rank: int) -> String:
	for hero in b.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _choose_readonly(b: StitchedRules, note: String) -> Dictionary:
	var state := b.state_snapshot()
	var rng := b.rng_state()
	var cuts := b.thread_cuts()
	var choice := StitchedFoeIntent.choose(b, b.get_unit(CRAB))
	_check(b.state_snapshot() == state and b.rng_state() == rng and b.thread_cuts() == cuts,
		note + ": the chooser spends no turn and draws no RNG")
	return choice


func _landed_snip(b: StitchedRules, receipt: Dictionary, hero_id: String, rank: int,
		expected_cuts: Dictionary) -> bool:
	if not bool(receipt.get("ok", false)) or str(receipt.get("ability", "")) != "thread_snip":
		return false
	var results: Array = receipt.get("results", [])
	if results.size() != 1 or not bool(results[0].get("hit", false)):
		return false
	var snip: Dictionary = results[0].get("snip", {})
	if not bool(snip.get("ok", false)) or str(snip.get("hero", "")) != hero_id \
			or int(snip.get("after_rank", 0)) != rank:
		return false
	var cuts := b.thread_cuts()
	if cuts.size() != expected_cuts.size():
		return false
	for id in expected_cuts:
		if int(cuts.get(id, 0)) != int(expected_cuts[id]):
			return false
	return true


# ---------------------------------------------------------------- AC2/AC3/AC4 progression

## Round 1 is Pinch-first, round 2 is Snip-first. Three genuine landed snips cut ranks 1, 2
## and 3; the next Snip-first round (8) must fall through to Pinch at rank 1.
func _progression(seed_value: int) -> Dictionary:
	var b := _make_battle(seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	var choices: Array = []
	var cut_states: Array = []
	if not _to(b, CRAB, 2, receipts):
		return {}
	var rank_one := _hero_id_at(b, 1)
	var rank_two := _hero_id_at(b, 2)
	var rank_three := _hero_id_at(b, 3)
	if rank_one.is_empty() or rank_two.is_empty() or rank_three.is_empty():
		return {}
	var state_before := b.state_snapshot()
	var rng_before := b.rng_state()
	var first := StitchedFoeIntent.choose(b, b.get_unit(CRAB))
	choices.append(first)
	if str(first.get("ability_id", "")) != "thread_snip" \
			or int(first.get("target_rank", 0)) != 1 or b.thread_cuts().size() != 0 \
			or b.state_snapshot() != state_before or b.rng_state() != rng_before:
		return {}
	var first_receipt := b.use_foe_ability("thread_snip", 1)
	receipts.append(first_receipt)
	if not _landed_snip(b, first_receipt, rank_one, 1, {rank_one: 1}):
		return {}
	cut_states.append(b.thread_cuts())
	if not _to(b, CRAB, 4, receipts):
		return {}
	var second_state := b.state_snapshot()
	var second_rng := b.rng_state()
	var second := StitchedFoeIntent.choose(b, b.get_unit(CRAB))
	choices.append(second)
	if str(second.get("ability_id", "")) != "thread_snip" \
			or int(second.get("target_rank", 0)) != 2 \
			or b.state_snapshot() != second_state or b.rng_state() != second_rng:
		return {}
	var second_receipt := b.use_foe_ability("thread_snip", 2)
	receipts.append(second_receipt)
	if not _landed_snip(b, second_receipt, rank_two, 2, {rank_one: 1, rank_two: 2}):
		return {}
	cut_states.append(b.thread_cuts())
	if not _to(b, CRAB, 6, receipts):
		return {}
	var third_state := b.state_snapshot()
	var third_rng := b.rng_state()
	var third := StitchedFoeIntent.choose(b, b.get_unit(CRAB))
	choices.append(third)
	if str(third.get("ability_id", "")) != "thread_snip" \
			or int(third.get("target_rank", 0)) != 3 \
			or b.state_snapshot() != third_state or b.rng_state() != third_rng:
		return {}
	var third_receipt := b.use_foe_ability("thread_snip", 3)
	receipts.append(third_receipt)
	if not _landed_snip(b, third_receipt, rank_three, 3,
			{rank_one: 1, rank_two: 2, rank_three: 3}):
		return {}
	cut_states.append(b.thread_cuts())
	if not _to(b, CRAB, 8, receipts):
		return {}
	var fallback_state := b.state_snapshot()
	var fallback_rng := b.rng_state()
	var fallback := StitchedFoeIntent.choose(b, b.get_unit(CRAB))
	choices.append(fallback)
	if str(fallback.get("ability_id", "")) != "pinch" \
			or int(fallback.get("target_rank", 0)) != 1 or b.thread_cuts().size() != 3 \
			or b.state_snapshot() != fallback_state or b.rng_state() != fallback_rng:
		return {}
	var pinch := b.use_foe_ability("pinch", 1)
	receipts.append(pinch)
	if not bool(pinch.get("ok", false)) or str(pinch.get("ability", "")) != "pinch":
		return {}
	return {
		"choices": choices, "receipts": receipts, "cut_states": cut_states,
		"rank_ids": [rank_one, rank_two, rank_three],
		"state": b.state_snapshot(), "rng": b.rng_state(),
	}


func _fresh_thread_progression() -> void:
	var witness := 0
	for seed_value in range(1, 161):
		if not _progression(seed_value).is_empty():
			witness = seed_value
			break
	_check(witness > 0,
		"AC2: a bounded seed search finds three genuine snips then a Pinch fallthrough")
	if witness == 0:
		return
	print("Scissor Crab uncut-thread progression witness seed: ", witness)
	var first := _progression(witness)
	var replay := _progression(witness)
	_check(not first.is_empty() and first == replay,
		"AC5: the same-seed 4v2 progression replays receipts, intents, cuts, state and RNG")
	if first.is_empty():
		return
	var choices: Array = first["choices"]
	_check(choices.size() == 4
		and str(choices[0].get("ability_id", "")) == "thread_snip"
		and int(choices[0].get("target_rank", 0)) == 1
		and choices[0].get("affected_ranks") == [1]
		and str(choices[1].get("ability_id", "")) == "thread_snip"
		and int(choices[1].get("target_rank", 0)) == 2
		and choices[1].get("affected_ranks") == [2]
		and str(choices[2].get("ability_id", "")) == "thread_snip"
		and int(choices[2].get("target_rank", 0)) == 3
		and choices[2].get("affected_ranks") == [3]
		and str(choices[3].get("ability_id", "")) == "pinch"
		and int(choices[3].get("target_rank", 0)) == 1,
		"AC2/AC3: cut ranks 1-3 are skipped in order; an all-cut Snip round becomes Pinch 1")
	var snip: Dictionary = choices[0]
	_check(str(snip.get("ability_name", "")) == "Thread Snip"
		and str(snip.get("ability_kind", "")) == "debuff"
		and str(snip.get("target_side", "")) == "hero"
		and not bool(snip.get("multi", true))
		and int(snip.get("base_acc", -1)) == 92
		and snip.get("base_damage") == [0, 0] and int(snip.get("base_crit", -1)) == 0
		and snip.get("base_effects") == {"snip": 1},
		"AC2: a fresh Snip reports its exact authored fields and affected ranks")
	var pinch: Dictionary = choices[3]
	_check(str(pinch.get("ability_name", "")) == "Pinch"
		and str(pinch.get("ability_kind", "")) == "melee"
		and int(pinch.get("base_acc", -1)) == 86
		and pinch.get("base_damage") == [3, 6]
		and pinch.get("base_effects") == {"bleed": 2},
		"AC3: the fallthrough is the authored Pinch with its exact numbers")
	var rank_ids: Array = first["rank_ids"]
	var cut_states: Array = first["cut_states"]
	_check(cut_states.size() == 3
		and cut_states[0].size() == 1 and int(cut_states[0].get(rank_ids[0], 0)) == 1
		and cut_states[1].size() == 2 and int(cut_states[1].get(rank_ids[0], 0)) == 1
		and int(cut_states[1].get(rank_ids[1], 0)) == 2
		and cut_states[2].size() == 3 and int(cut_states[2].get(rank_ids[2], 0)) == 3,
		"AC4: each landed snip cuts only its selected intact boundary")
	var snips: Array = []
	for receipt in first["receipts"]:
		if receipt is Dictionary and str(receipt.get("ability", "")) == "thread_snip":
			snips.append(receipt)
	_check(snips.size() == 3,
		"AC4: three genuine Thread Snip actions actually executed through the rules")
	for index in range(mini(3, snips.size())):
		var result: Dictionary = snips[index]["results"][0]
		_check(bool(result.get("hit", false)) and result.get("snip", {}).get("ok", false)
			and int(result.get("snip", {}).get("after_rank", 0)) == index + 1,
			"AC4: landed snip %d confirms exactly the rank-%d cut" % [index + 1, index + 1])
	_check(first["state"]["thread_cuts"].size() == 3,
		"AC4: the final state snapshot carries exactly the three genuine cuts")


## The same Snip turn on a seed where the roll misses: no cut, no damage, no statuses, but
## the turn and its RNG draw are spent.
func _miss_run(seed_value: int) -> Dictionary:
	var b := _make_battle(seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	if not _to(b, CRAB, 2, receipts):
		return {}
	var hero_id := _hero_id_at(b, 1)
	if hero_id.is_empty():
		return {}
	var before := b.get_unit(hero_id)
	var state := b.state_snapshot()
	var rng := b.rng_state()
	var choice := StitchedFoeIntent.choose(b, b.get_unit(CRAB))
	if str(choice.get("ability_id", "")) != "thread_snip" \
			or int(choice.get("target_rank", 0)) != 1:
		return {}
	if b.state_snapshot() != state or b.rng_state() != rng:
		return {}
	var receipt := b.use_foe_ability("thread_snip", 1)
	receipts.append(receipt)
	var results: Array = receipt.get("results", [])
	if not bool(receipt.get("ok", false)) or results.size() != 1 \
			or bool(results[0].get("hit", true)):
		return {}
	var after := b.get_unit(hero_id)
	if b.thread_cuts().size() != 0 or after.get("hp") != before.get("hp") \
			or after.get("statuses") != before.get("statuses") \
			or after.get("fray") != before.get("fray"):
		return {}
	return {
		"choice": choice, "receipts": receipts, "turn_spent": b.current_actor_id() != CRAB,
		"state": b.state_snapshot(), "rng": b.rng_state(),
	}


func _missed_snip() -> void:
	var witness := 0
	for seed_value in range(1, 161):
		var trace := _miss_run(seed_value)
		if not trace.is_empty():
			witness = seed_value
			break
	_check(witness > 0, "AC4: a bounded seed search witnesses a natural Thread Snip miss")
	if witness == 0:
		return
	print("Scissor Crab natural-miss witness seed: ", witness)
	var first := _miss_run(witness)
	var replay := _miss_run(witness)
	_check(not first.is_empty() and first == replay,
		"AC5: the same-seed snip miss replays receipts, choice, state and RNG")
	if first.is_empty():
		return
	var executed: Array = first["receipts"]
	var receipt: Dictionary = executed[executed.size() - 1]
	var result: Dictionary = receipt["results"][0]
	_check(not bool(result.get("hit", true)) and int(result.get("damage", -1)) == 0
		and result.get("statuses", [1]).is_empty() and not result.has("snip")
		and first["state"]["thread_cuts"].is_empty(),
		"AC4: a natural miss deals no damage, applies no effect and cuts no thread")
	_check(bool(first["turn_spent"]),
		"AC4: the missed snip still spends the foe's genuine turn")
	_check(str(first["choice"].get("ability_id", "")) == "thread_snip"
		and int(first["choice"].get("target_rank", 0)) == 1,
		"AC4: the miss was a real fresh-rank-1 intent, not a fabricated hit")


# ---------------------------------------------------------------- isolated rank fixtures

func _isolated_battle() -> StitchedRules:
	var b := _make_battle(7)
	if b == null:
		return null
	var receipts: Array = []
	if not _to(b, CRAB, 2, receipts):
		return null
	return b


func _isolated_rank_scenarios() -> void:
	var b := _isolated_battle()
	_check(b != null, "AC2: an isolated seeded battle reaches the Snip-first round")
	if b == null:
		return
	var one := _hero_id_at(b, 1)
	var two := _hero_id_at(b, 2)
	var three := _hero_id_at(b, 3)
	var four := _hero_id_at(b, 4)
	_check(not one.is_empty() and not two.is_empty() and not three.is_empty() \
		and not four.is_empty() and b.thread_cuts().is_empty(),
		"AC2: precondition: four living dolls, no cuts, Snip rotated first")
	var fresh := _choose_readonly(b, "AC2 fresh seam")
	_check(str(fresh.get("ability_id", "")) == "thread_snip"
		and int(fresh.get("target_rank", 0)) == 1 and fresh.get("affected_ranks") == [1],
		"AC2: with every seam whole, Snip selects the closest legal rank 1")
	# Labelled cut-state fixtures: only the battle's own id-keyed cut map changes.
	b._thread_cuts[one] = 1
	var second := _choose_readonly(b, "AC2 rank one cut")
	_check(str(second.get("ability_id", "")) == "thread_snip"
		and int(second.get("target_rank", 0)) == 2 and second.get("affected_ranks") == [2],
		"AC2: a seam cut behind rank 1 makes fresh rank 2 the Snip target")
	b._thread_cuts[two] = 2
	var third := _choose_readonly(b, "AC2 ranks one and two cut")
	_check(str(third.get("ability_id", "")) == "thread_snip"
		and int(third.get("target_rank", 0)) == 3 and third.get("affected_ranks") == [3],
		"AC2: cut ranks 1 and 2 make fresh rank 3 the Snip target")
	b._thread_cuts[three] = 3
	var fallback := _choose_readonly(b, "AC3 every legal seam cut")
	_check(str(fallback.get("ability_id", "")) == "pinch"
		and int(fallback.get("target_rank", 0)) == 1
		and str(fallback.get("target_side", "")) == "hero"
		and fallback.get("affected_ranks") == [1],
		"AC3: with every reachable seam cut, Snip falls through to Pinch rank 1")

	# A dead non-LOST doll is still reported by legality, yet is never a fresh seam.
	var dead_battle := _isolated_battle()
	if dead_battle != null:
		var dead_one := _hero_id_at(dead_battle, 1)
		dead_battle._units[dead_one]["dead"] = true
		dead_battle._units[dead_one]["hp"] = 0
		var snip_ability: Dictionary = StitchedEnemyCatalog.foe_for(catalog, CRAB)["abilities"][1]
		_check(dead_battle._legal_targets(dead_battle._units[CRAB], snip_ability, 1).size() == 1,
			"AC2: precondition: legality still reports the dead rank-1 doll")
		var dead_choice := _choose_readonly(dead_battle, "AC2 dead rank one")
		_check(str(dead_choice.get("ability_id", "")) == "thread_snip"
			and int(dead_choice.get("target_rank", 0)) == 2,
			"AC2: a dead rank-1 doll is never selected for a fresh seam")

	# A LOST doll leaves its rank empty for legality, so the next living seam is chosen.
	var lost_battle := _isolated_battle()
	if lost_battle != null:
		var lost_one := _hero_id_at(lost_battle, 1)
		lost_battle._units[lost_one]["lost"] = true
		var lost_choice := _choose_readonly(lost_battle, "AC2 lost rank one")
		_check(str(lost_choice.get("ability_id", "")) == "thread_snip"
			and int(lost_choice.get("target_rank", 0)) == 2,
			"AC2: a LOST or empty rank 1 is skipped for the next fresh seam")

	# Only a cut Snip-rank doll remains and Pinch has no rank 1/2 target: pass. The intact
	# rank-4 doll is alive but outside Thread Snip's authored reach.
	var pass_battle := _isolated_battle()
	if pass_battle != null:
		var pass_one := _hero_id_at(pass_battle, 1)
		var pass_two := _hero_id_at(pass_battle, 2)
		var pass_three := _hero_id_at(pass_battle, 3)
		var pass_four := _hero_id_at(pass_battle, 4)
		pass_battle._units[pass_one]["lost"] = true
		pass_battle._units[pass_two]["lost"] = true
		pass_battle._thread_cuts[pass_three] = 3
		var snip: Dictionary = StitchedEnemyCatalog.foe_for(catalog, CRAB)["abilities"][1]
		_check(not pass_four.is_empty() and int(pass_battle.get_unit(pass_four)["hp"]) > 0
			and pass_battle._legal_targets(pass_battle._units[CRAB], snip, 4).is_empty()
			and pass_battle._legal_targets(pass_battle._units[CRAB], snip, 3).size() == 1,
			"AC2: precondition: rank 4 is intact but outside Snip's authored reach")
		var pass_choice := _choose_readonly(pass_battle, "AC3 pass fallthrough")
		_check(bool(pass_choice.get("pass", false))
			and str(pass_choice.get("ability_id", "x")) == ""
			and int(pass_choice.get("target_rank", -1)) == 0
			and pass_choice.get("affected_ranks", [1]).is_empty()
			and not pass_choice.has("base_damage"),
			"AC3: a cut Snip-rank doll with no Pinch rank passes without a fake target")

	# The narrow branch belongs only to the Scissor Crab: a cut front seam does not change
	# another foe's ordinary nearest-legal attack.
	var other_battle := _isolated_battle()
	if other_battle != null:
		var other_one := _hero_id_at(other_battle, 1)
		other_battle._thread_cuts[other_one] = 1
		var state := other_battle.state_snapshot()
		var rng := other_battle.rng_state()
		var other_choice := StitchedFoeIntent.choose(other_battle, other_battle.get_unit(OTHER))
		_check(str(other_choice.get("ability_id", "")) == "rag_rake"
			and int(other_choice.get("target_rank", 0)) == 1
			and other_battle.state_snapshot() == state and other_battle.rng_state() == rng,
			"AC3: an unrelated foe keeps its ordinary nearest-legal selector on a cut seam")


# ---------------------------------------------------------------- rotation and RE-TIE

func _pinch_first_round() -> void:
	var b := _make_battle(11)
	var receipts: Array = []
	_check(b != null and _to(b, CRAB, 1, receipts),
		"AC3: a seeded battle reaches the Pinch-first round")
	if b == null:
		return
	var one := _hero_id_at(b, 1)
	_check(b.round_number() == 1 and not one.is_empty(),
		"AC3: precondition: round one is Pinch-first with a living rank 1")
	b._thread_cuts[one] = 1
	var choice := _choose_readonly(b, "AC3 Pinch-first rotation")
	_check(str(choice.get("ability_id", "")) == "pinch"
		and int(choice.get("target_rank", 0)) == 1,
		"AC3: a Pinch-first round keeps Pinch, never a front-of-rotation Snip override")
	b._units[CRAB]["statuses"]["stun"] = 1
	var stunned := _choose_readonly(b, "AC3 stunned Scissor Crab")
	_check(bool(stunned.get("stun", false)) and bool(stunned.get("pass", true))
		and str(stunned.get("ability_id", "x")) == ""
		and int(stunned.get("target_rank", -1)) == 0,
		"AC3: a stunned Scissor Crab still announces no action")
	b._units[CRAB]["statuses"].erase("stun")


func _retie_cycle(seed_value: int) -> Dictionary:
	var b := _make_battle(seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	if not _to(b, CRAB, 2, receipts):
		return {}
	var hero_id := _hero_id_at(b, 1)
	if hero_id.is_empty():
		return {}
	var first := StitchedFoeIntent.choose(b, b.get_unit(CRAB))
	if str(first.get("ability_id", "")) != "thread_snip" \
			or int(first.get("target_rank", 0)) != 1:
		return {}
	var cut := b.use_foe_ability("thread_snip", 1)
	receipts.append(cut)
	if not _landed_snip(b, cut, hero_id, 1, {hero_id: 1}):
		return {}
	var cuts_before := b.thread_cuts()
	if not _to(b, hero_id, 1, receipts):
		return {}
	var re_tie := b.re_tie()
	receipts.append(re_tie)
	if not bool(re_tie.get("ok", false)) or str(re_tie.get("actor", "")) != hero_id \
			or not b.thread_cuts().is_empty():
		return {}
	var cuts_after := b.thread_cuts()
	if not _to(b, CRAB, 4, receipts):
		return {}
	var again := StitchedFoeIntent.choose(b, b.get_unit(CRAB))
	if str(again.get("ability_id", "")) != "thread_snip" \
			or int(again.get("target_rank", 0)) != 1:
		return {}
	return {
		"choices": [first, again], "receipts": receipts,
		"cuts_before": cuts_before, "cuts_after": cuts_after, "hero": hero_id,
		"state": b.state_snapshot(), "rng": b.rng_state(),
	}


func _retied_seam() -> void:
	var witness := 0
	for seed_value in range(1, 161):
		if not _retie_cycle(seed_value).is_empty():
			witness = seed_value
			break
	_check(witness > 0, "AC4: a bounded seed search witnesses a real RE-TIE reopening a seam")
	if witness == 0:
		return
	print("Scissor Crab RE-TIE witness seed: ", witness)
	var first := _retie_cycle(witness)
	var replay := _retie_cycle(witness)
	_check(not first.is_empty() and first == replay,
		"AC5: the RE-TIE cycle replays receipts, intents, cuts, state and RNG")
	if first.is_empty():
		return
	_check(int(first["cuts_before"].get(first["hero"], 0)) == 1
		and first["cuts_after"].is_empty()
		and int(first["choices"][0].get("target_rank", 0)) == 1
		and int(first["choices"][1].get("target_rank", 0)) == 1,
		"AC4: after a real RE-TIE the lowest rank becomes a legal fresh Snip target again")
