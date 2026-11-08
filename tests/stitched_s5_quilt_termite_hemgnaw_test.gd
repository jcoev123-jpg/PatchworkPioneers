extends SceneTree
## S5 Quilt Termite: a thread-chewing Quilt Chew (Bleed 1 + Snip 1) and a new back-rank
## Lint Spit (Blind 1 + Exposed 1), proven through the shipped enemy catalog, the shipped
## read-only intent projection and the real StitchedRules public turn methods on the real
## four-doll preview party.
##
## Per-ID source lookups only: this test never asserts a catalog total or a full ordered
## enemy-id list, so a parallel lane adding another foe cannot break it. Legacy intent,
## stats, flags, art and trophy are compared byte-for-byte in content against independent
## copies; the Termite Swarm record is compared unchanged and exercised in a real battle.

const RUN := "res://data/enemies/run_enemies.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const TERMITE := "quilt_termite"
const RAGLING := "ragling"
const SEED_FIRST := 1
const SEED_LAST := 65
const TURN_LIMIT := 48

const QUILT_CHEW := {
	"id": "quilt_chew", "name": "Quilt Chew", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 87, "dmg": [3, 4], "crit": 0, "effects": {"bleed": 1, "snip": 1},
	"self_move": 0, "move": "attack2",
}
const TERMITE_SWARM := {
	"id": "termite_swarm", "name": "Termite Swarm", "kind": "buff",
	"launch": [1, 3], "target": [1, 3], "target_side": "self", "multi": false,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"dodge": 4, "duration": 1},
	"self_move": 0, "move": "skill",
}
const LINT_SPIT := {
	"id": "termite_lint_spit", "name": "Lint Spit", "kind": "ranged",
	"launch": [2, 3, 4], "target": [2, 3, 4], "target_side": "enemy", "multi": false,
	"acc": 84, "dmg": [2, 3], "crit": 0, "effects": {"blind": 1, "exposed": 1},
	"self_move": 0, "move": "attack3",
}
const LEGACY := {
	"id": "quilt_termite", "name": "Quilt Termite", "max_hp": 26,
	"split_on_death": true, "chew_block_on_attack": true,
	"art_path": "res://assets/paper/enemies/quilt_termite.png",
	"intent": {
		"target": "front",
		"actions": [
			{"type": "attack", "amount": 6, "weight": 4},
			{"type": "block", "amount": 5, "weight": 1},
			{"type": "debuff", "status": "exposed", "amount": 1, "weight": 1},
			{"type": "attack", "amount": 6, "hits": 2, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
		],
	},
}
const PROFILE := {
	"max_hp": 26, "speed": 4, "dodge": 5, "acc": 0, "prot": 4,
	"is_boss": false, "turns_per_round": 1, "trophy": "quilt_termite_mandible",
	"abilities": [QUILT_CHEW, TERMITE_SWARM, LINT_SPIT],
}

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary
var preview: Dictionary


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(bool(catalog.get("ok", false)) and parsed is Dictionary,
		"the real enemy catalog and the real four-doll preview load: " + str(catalog.get("error", "")))
	if bool(catalog.get("ok", false)) and parsed is Dictionary:
		preview = parsed
		_contract()
		var chew := _chew_witnesses()
		if int(chew.get("hit", 0)) > 0:
			_chew_cut_consequence(int(chew["hit"]))
		var lint := _lint_witnesses()
		if int(lint.get("ok", 0)) > 0:
			_lint_natural(int(lint["ok"]))
		_lint_legal_ranks()
		_refusals()
		var rotation_seed := 19
		var first := _rotation(rotation_seed)
		var replay := _rotation(rotation_seed)
		_check(not first.is_empty() and first == replay,
			"AC4: three genuine rounds of Chew/Swarm/Chew replay identical receipts/state/RNG")
	for failure in failures:
		printerr(failure)
	print("stitched_s5_quilt_termite_hemgnaw_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _json_equal(actual: Variant, expected: Variant) -> bool:
	return _json(actual) == _json(expected)


func _ability_of(unit: Dictionary, ability_id: String) -> Dictionary:
	for ability in unit.get("abilities", []):
		if ability is Dictionary and str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _hero_at(battle: StitchedRules, rank: int) -> Dictionary:
	for hero in battle.get_heroes():
		if int(hero.get("rank", 0)) == rank:
			return hero
	return {}


# ---------------------------------------------------------------- AC1 the canonical record

func _contract() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN))
	_check(raw is Array, "AC1: " + RUN + " parses as a JSON array")
	if not raw is Array:
		return
	var matches: Array = raw.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and str(entry.get("id", "")) == TERMITE)
	_check(matches.size() == 1, "AC1: exactly one shipped Quilt Termite record")
	if matches.size() != 1:
		return
	var termite: Dictionary = matches[0]
	# The whole legacy record (everything beside "stitched") must be unchanged.
	var legacy := termite.duplicate(true)
	legacy.erase("stitched")
	_check(_json_equal(legacy, LEGACY),
		"AC1: name, HP 26, split_on_death, chew_block_on_attack, art and the entire legacy intent are unchanged")
	# The exact Stitched profile: unchanged stats/trophy/swarm and one appended third action.
	_check(_json_equal(termite.get("stitched"), PROFILE),
		"AC1: the exact Stitched profile keeps every stat, flag and trophy and authors Chew, Swarm, Lint Spit")
	var abilities: Array = termite.get("stitched", {}).get("abilities", [])
	_check(abilities.size() == 3
		and str(abilities[0].get("id", "")) == "quilt_chew"
		and str(abilities[1].get("id", "")) == "termite_swarm"
		and str(abilities[2].get("id", "")) == "termite_lint_spit",
		"AC1: Quilt Chew stays first, Termite Swarm stays second and one Lint Spit is appended third")
	if abilities.size() == 3:
		_check(_json_equal(abilities[0], QUILT_CHEW),
			"AC1: Quilt Chew's only change is effects Bleed 1 plus Snip 1; ACC 87 and damage 3-4 stay")
		_check(_json_equal(abilities[1], TERMITE_SWARM),
			"AC1: the original Termite Swarm Dodge 4 / duration 1 record is byte-equivalent in content")
		_check(_json_equal(abilities[2], LINT_SPIT),
			"AC1: the appended Lint Spit authors launch/target ranks 2-4, ACC 84, damage 2-3, Blind 1 + Exposed 1")
	# Independent validation of the authored result.
	var chew := StitchedParts.validate_ability(QUILT_CHEW)
	var swarm := StitchedParts.validate_ability(TERMITE_SWARM)
	var lint := StitchedParts.validate_ability(LINT_SPIT)
	_check(bool(chew.get("ok", false)), "AC1: Quilt Chew validates as a StitchedParts ability")
	_check(bool(swarm.get("ok", false)), "AC1: Termite Swarm still validates as a StitchedParts ability")
	_check(bool(lint.get("ok", false)), "AC1: the new Lint Spit validates as a StitchedParts ability")
	if bool(chew.get("ok", false)):
		var c: Dictionary = chew["ability"]
		_check(c.get("effects") == {"bleed": 1, "snip": 1}
			and c.get("target") == [1]
			and int(c.get("target_mask", 0)) == StitchedParts.rank_mask([1])
			and int(c.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and int(c.get("acc", -1)) == 87 and c.get("dmg") == [3, 4]
			and not bool(c.get("multi", true)) and str(c.get("move", "")) == "attack2",
			"AC1: validated Quilt Chew is a single front-rank 3-4 bite with Bleed 1 and Snip 1")
	if bool(swarm.get("ok", false)):
		var s: Dictionary = swarm["ability"]
		_check(s.get("effects") == {"dodge": 4, "duration": 1}
			and s.get("target_side") == "self" and s.get("dmg") == [0, 0],
			"AC1: validated Termite Swarm remains a self Dodge 4 / duration 1 buff")
	if bool(lint.get("ok", false)):
		var l: Dictionary = lint["ability"]
		_check(l.get("effects") == {"blind": 1, "exposed": 1}
			and l.get("target") == [2, 3, 4]
			and int(l.get("target_mask", 0)) == StitchedParts.rank_mask([2, 3, 4])
			and int(l.get("launch_mask", 0)) == StitchedParts.rank_mask([2, 3, 4])
			and not bool(l.get("multi", true))
			and str(l.get("kind", "")) == "ranged"
			and int(l.get("acc", -1)) == 84
			and l.get("dmg") == [2, 3]
			and str(l.get("move", "")) == "attack3",
			"AC1: validated Lint Spit is a single-target rear-rank Blind 1 + Exposed 1 spit")
		for rank in range(0, 6):
			_check(StitchedParts.ranks_allowed(int(l["target_mask"]), rank)
				== (rank in [2, 3, 4]),
				"AC1: Lint Spit's target mask admits only hero rank %d" % rank)
			_check(StitchedParts.ranks_allowed(int(l["launch_mask"]), rank)
				== (rank in [2, 3, 4]),
				"AC1: Lint Spit's launch mask admits only foe rank %d" % rank)
	# The canonical loader exposes the same normalized kit.
	var foe := StitchedEnemyCatalog.foe_for(catalog, TERMITE)
	_check(not foe.is_empty(), "AC1: the real catalog still resolves quilt_termite")
	if not foe.is_empty():
		var expected_foe := PROFILE.duplicate(true)
		expected_foe.erase("trophy")
		expected_foe.merge({"id": TERMITE, "name": "Quilt Termite"})
		for ability in expected_foe["abilities"]:
			ability["launch_mask"] = StitchedParts.rank_mask(ability["launch"])
			ability["target_mask"] = StitchedParts.rank_mask(ability["target"])
			ability["mark_damage"] = 0
		_check(_json_equal(foe, expected_foe),
			"AC1: foe_for preserves the exact stats and the independently authored three-action kit")
		_check(str(foe.get("name", "")) == "Quilt Termite"
			and int(foe.get("max_hp", 0)) == 26 and int(foe.get("speed", -1)) == 4
			and int(foe.get("dodge", -1)) == 5 and int(foe.get("acc", -1)) == 0
			and int(foe.get("prot", -1)) == 4 and not bool(foe.get("is_boss", true))
			and int(foe.get("turns_per_round", 0)) == 1,
			"AC1: the loaded foe keeps HP 26, SPEED 4, DODGE 5, ACC 0, PROT 4 and one normal turn")
		_check(StitchedEnemyCatalog.trophy_for(catalog, TERMITE) == "quilt_termite_mandible",
			"AC1: the Quilt Termite keeps its authored mandible trophy")
	_check(str(catalog.get("enemies", {}).get(TERMITE, {}).get("tier", "")) == "normal",
		"AC1: the Quilt Termite remains a normal-tier canonical foe")
	# Neighbouring canonical foes keep their own required actions, by id only.
	var biter := StitchedEnemyCatalog.foe_for(catalog, "thread_biter")
	_check(not biter.is_empty()
		and _ability_of(biter, "thread_bite").get("effects") == {"bleed": 1, "snip": 1}
		and not _ability_of(biter, "lint_spit").is_empty(),
		"AC1: Thread Biter keeps its own thread_bite and differently shaped lint_spit")
	_check(_ability_of(biter, "termite_lint_spit").is_empty(),
		"AC1: the new termite_lint_spit id never leaks onto the Thread Biter")
	var imp := StitchedEnemyCatalog.foe_for(catalog, "inkbrush_imp")
	_check(not imp.is_empty() and not _ability_of(imp, "blinding_ink").is_empty(),
		"AC1: Inkbrush Imp keeps its own blinding_ink")
	# Move art stays the existing authored pose; no new move-poses record is needed.
	var poses: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/art/move_poses.json"))
	var termite_poses: Dictionary = {}
	if poses is Dictionary and poses.get("enemies") is Dictionary \
			and poses["enemies"].get(TERMITE) is Dictionary:
		termite_poses = poses["enemies"][TERMITE]
	_check(not termite_poses.is_empty()
		and str(termite_poses.get("attack2", {}).get("art", "")) \
			== "res://assets/paper/enemies/quilt_termite_attack2.png"
		and str(termite_poses.get("skill", {}).get("art", "")) \
			== "res://assets/paper/enemies/quilt_termite_skill.png"
		and str(termite_poses.get("attack3", {}).get("art", "")) \
			== "res://assets/paper/enemies/quilt_termite_attack3.png",
		"AC1: the shipped attack2/skill/attack3 move poses and art paths stay unchanged")


# ---------------------------------------------------------------- fixtures

func _config(seed_value: int, foe_ids: Array, heroes: Array = []) -> Dictionary:
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"].duplicate(true))
	var party: Array = heroes.duplicate(true) if not heroes.is_empty() \
		else preview["heroes"].duplicate(true)
	var foes: Array = []
	for enemy_id in foe_ids:
		foes.append(StitchedEnemyCatalog.foe_for(catalog, str(enemy_id)))
	return {
		"mode": "stitched",
		"seed": seed_value,
		"candle": 100,
		"heroes": party,
		"parts": parts,
		"foes": foes,
	}


func _battle(seed_value: int, foe_ids: Array, heroes: Array = []) -> StitchedRules:
	var config := _config(seed_value, foe_ids, heroes)
	for foe in config["foes"]:
		if foe is Dictionary and foe.is_empty():
			_check(false, "the real catalog resolves every named canonical foe")
			return null
	var made := StitchedRules.create(config)
	_check(bool(made.get("ok", false)),
		"real seeded four-doll/two-canonical-foe battle builds: " + str(made.get("error", "")))
	if not bool(made.get("ok", false)):
		return null
	var battle: StitchedRules = made["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 2 \
		and battle.candle() == 100,
		"nonvacuous four occupied hero ranks, two foes and a BRIGHT candle")
	_check(int(battle.get_unit(TERMITE).get("rank", 0)) == foe_ids.find(TERMITE) + 1,
		"the canonical Quilt Termite occupies the requested foe rank")
	for index in range(4):
		var hero := battle.get_unit(str(preview["heroes"][index]["id"]))
		var rank_ok := int(hero.get("rank", 0)) == index + 1
		if heroes.is_empty():
			_check(rank_ok and int(hero.get("hp", 0)) > 0
				and int(hero.get("parts", {}).size()) == 4,
				"real living hero with four preview parts at rank %d" % (index + 1))
		else:
			_check(rank_ok, "custom fixture hero keeps rank %d" % (index + 1))
	return battle


## Advance genuine public turns (passing anyone else) until the requested actor holds its
## turn. Every step is a real pass_turn receipt and keeps the RNG single-sourced.
func _to(battle: StitchedRules, actor: String, receipts: Array) -> bool:
	for step in range(TURN_LIMIT):
		if battle.is_over():
			break
		if battle.current_actor_id() == actor:
			return true
		var passed := battle.pass_turn()
		receipts.append(passed)
		if not bool(passed.get("ok", false)):
			break
	_check(false, "bounded public pass_turn schedule reaches " + actor)
	return false


func _to_round(battle: StitchedRules, target_round: int, actor: String, receipts: Array) -> bool:
	for step in range(TURN_LIMIT * 2):
		if battle.is_over():
			return false
		if battle.round_number() > target_round:
			return false
		if battle.round_number() == target_round and battle.current_actor_id() == actor:
			return true
		var passed := battle.pass_turn()
		receipts.append(passed)
		if not bool(passed.get("ok", false)):
			return false
	return false


# ---------------------------------------------------------------- AC2 Quilt Chew

## One genuine Quilt Chew from a rank-1 termite at hero rank 1, with the seeded roll
## independently predicted. `cut_before` is the uncut-thread control.
func _chew_trace(seed_value: int) -> Dictionary:
	var battle := _battle(seed_value, [TERMITE, RAGLING])
	if battle == null:
		return {}
	var receipts: Array = []
	if not _to(battle, TERMITE, receipts):
		return {}
	_check(int(battle.round_number()) == 1 and battle.thread_cuts().is_empty(),
		"AC2: the uncut-thread control starts the first termite turn with no cut")
	var actor := battle.get_unit(TERMITE)
	var before := battle.get_unit("warden")
	var cut_before := battle.thread_cuts()
	var rng := battle.rng_state()
	var receipt := battle.use_foe_ability("quilt_chew", 1)
	receipts.append(receipt)
	if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 1:
		_check(false, "AC2: a real Quilt Chew receipt lands on exactly one doll")
		return {}
	var result: Dictionary = receipt["results"][0]
	var after := battle.get_unit("warden")
	var chance := StitchedRules.hit_chance(
		87 + int(actor.get("acc", 0)) + int(battle.candle_band().get("enemy_acc", 0)),
		StitchedRules.effective_dodge(before), int(actor.get("miss_streak", 0)))
	_check(str(result.get("target", "")) == "warden"
		and int(result.get("target_rank", 0)) == 1
		and str(result.get("target_side", "")) == "hero"
		and int(result.get("hit_chance", -1)) == chance,
		"AC2: Quilt Chew aims only at the front-rank doll with authored ACC 87 against real DODGE")
	if bool(result.get("hit", false)):
		# Independent seeded damage prediction, never supplied to the battle's RNG.
		var oracle := RandomNumberGenerator.new()
		oracle.state = rng
		_check(oracle.randi_range(1, 100) == int(result.get("roll", 0)),
			"AC2: seeded genuine Quilt Chew hit roll")
		var critical := oracle.randi_range(1, 100) <= 5
		var maximum := int(QUILT_CHEW["dmg"][1])
		var base := StitchedRules.crit_damage(maximum) if critical \
			else oracle.randi_range(int(QUILT_CHEW["dmg"][0]), maximum)
		base += int(actor.get("dmg_bonus", 0))
		base = StitchedS1BEffects.enemy_damage(base, battle.candle())
		var marked := int(before.get("statuses", {}).get("mark", 0)) > 0
		var damage := StitchedRules.damage_after_modifiers(base,
			actor.get("statuses", {}), before.get("statuses", {}), marked, 0,
			int(before.get("prot", 0)))
		var damage_ok: bool = bool(result.get("crit", false)) == critical \
			and int(result.get("damage", -1)) == damage and damage > 0 \
			and int(result.get("target_hp", -1)) == int(before.get("hp", -2)) - damage
		_check(damage_ok, "AC2: seeded post-PROT Quilt Chew damage really wounds the front doll")
		# The applied status is the receipt's; a front doll that acts immediately has already
		# ticked Bleed on its own turn start, which is still positive proof of application.
		var applied: bool = result.get("statuses", []) == [{"status": "bleed", "duration": 1}]
		var retained := int(after.get("statuses", {}).get("bleed", 0))
		var ticked: bool = retained == 0 and battle.current_actor_id() == "warden" \
			and int(after.get("hp", -1)) == int(result.get("target_hp", -2)) - 1
		_check(applied and (retained == 1 or ticked),
			"AC2: a landed Quilt Chew applies exactly Bleed 1 and the real doll carries or ticks it")
		_check(bool(result.get("snip", {}).get("ok", false))
			and int(result.get("snip", {}).get("after_rank", 0)) == 1
			and battle.thread_cuts() == {"warden": 1},
			"AC2: a landed Quilt Chew really cuts the party thread behind the front doll")
	else:
		_check(int(result.get("roll", 0)) > chance
			and int(result.get("damage", -1)) == 0
			and result.get("statuses", []).is_empty()
			and not result.has("snip")
			and int(after.get("hp", -1)) == int(before.get("hp", -2))
			and after.get("statuses", {}) == before.get("statuses", {})
			and battle.thread_cuts() == cut_before,
			"AC4: a genuine rolled Quilt Chew miss applies no damage, Bleed or Snip")
	return {
		"ok": true,
		"hit": bool(result.get("hit", false)),
		"cut_before": cut_before,
		"receipts": receipts,
		"state": battle.state_snapshot(),
		"rng": battle.rng_state(),
		"battle": battle,
	}


func _chew_witnesses() -> Dictionary:
	var hit_seed := 0
	var miss_seed := 0
	for seed_value in range(SEED_FIRST, SEED_LAST + 1):
		var trace := _chew_trace(seed_value)
		if trace.is_empty():
			return {}
		if bool(trace["hit"]) and trace["cut_before"].is_empty() and hit_seed == 0:
			hit_seed = seed_value
		if not bool(trace["hit"]) and miss_seed == 0:
			miss_seed = seed_value
		if hit_seed > 0 and miss_seed > 0:
			break
	_check(hit_seed > 0 and miss_seed > 0,
		"AC2: the bounded seed cohort witnesses both a landed and a missed Quilt Chew")
	print("Quilt Chew witness seeds: hit=", hit_seed, ", miss=", miss_seed)
	for seed_value in [hit_seed, miss_seed]:
		if seed_value == 0:
			continue
		var first := _chew_trace(seed_value)
		var replay := _chew_trace(seed_value)
		first.erase("battle")
		replay.erase("battle")
		_check(not first.is_empty() and first == replay,
			"AC4: the selected Quilt Chew schedule exactly replays receipts/state/RNG")
	return {"hit": hit_seed, "miss": miss_seed}


## The cut is real: the snipped front doll cannot move across its own cut and draws no RNG;
## RE-TIE clears it exactly as the shipped thread rule does.
func _chew_cut_consequence(seed_value: int) -> void:
	var battle := _battle(seed_value, [TERMITE, RAGLING])
	if battle == null:
		return
	var receipts: Array = []
	if not _to(battle, TERMITE, receipts):
		return
	receipts.append(battle.use_foe_ability("quilt_chew", 1))
	_check(battle.thread_cuts() == {"warden": 1},
		"AC2: the witness Chew leaves the real thread cut behind the front doll")
	if not _to(battle, "warden", receipts):
		return
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var blocked := battle.move(1)
	receipts.append(blocked)
	_check(not bool(blocked.get("ok", true))
		and str(blocked.get("error", "")).contains("snipped")
		and before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: the snipped front doll's cross-cut move rejects atomically without RNG draw")
	var repaired := battle.re_tie()
	receipts.append(repaired)
	_check(bool(repaired.get("ok", false)) and repaired.get("actor") == "warden"
		and battle.thread_cuts().is_empty(),
		"AC2: the owner's RE-TIE clears the Quilt Chew cut and spends its turn")


# ---------------------------------------------------------------- AC3 Lint Spit

## One genuine Lint Spit from a rank-2 termite at the requested living hero rank.
func _lint_trace(seed_value: int, target_rank: int, heroes: Array = []) -> Dictionary:
	var battle := _battle(seed_value, [RAGLING, TERMITE], heroes)
	if battle == null:
		return {}
	var receipts: Array = []
	if not _to(battle, TERMITE, receipts):
		return {}
	_check(int(battle.get_unit(TERMITE).get("rank", 0)) == 2,
		"AC3: the Lint Spit witness casts from a real rank-2 Quilt Termite")
	var probe := _hero_at(battle, target_rank)
	if probe.is_empty():
		_check(false, "AC3: the requested living hero rank %d exists" % target_rank)
		return {}
	var target_id := str(probe["id"])
	# get_heroes() returns live references; a deep copy is the honest pre-action reading.
	var target := battle.get_unit(target_id)
	var actor := battle.get_unit(TERMITE)
	var heroes_before: Array = battle.get_heroes().duplicate(true)
	var rng := battle.rng_state()
	var receipt := battle.use_foe_ability("termite_lint_spit", target_rank)
	receipts.append(receipt)
	if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 1:
		_check(false, "AC3: a real Lint Spit receipt resolves on exactly one doll")
		return {}
	var result: Dictionary = receipt["results"][0]
	var after := battle.get_unit(target_id)
	var chance := StitchedRules.hit_chance(
		84 + int(actor.get("acc", 0)) + int(battle.candle_band().get("enemy_acc", 0)),
		StitchedRules.effective_dodge(target), int(actor.get("miss_streak", 0)))
	_check(str(result.get("target", "")) == target_id
		and int(result.get("target_rank", 0)) == target_rank
		and str(result.get("target_side", "")) == "hero"
		and int(result.get("hit_chance", -1)) == chance,
		"AC3: Lint Spit resolves as one single-target rear spit at the requested living hero rank")
	if bool(result.get("hit", false)):
		var oracle := RandomNumberGenerator.new()
		oracle.state = rng
		_check(oracle.randi_range(1, 100) == int(result.get("roll", 0)),
			"AC3: seeded genuine Lint Spit hit roll")
		var critical := oracle.randi_range(1, 100) <= 5
		var maximum := int(LINT_SPIT["dmg"][1])
		var base := StitchedRules.crit_damage(maximum) if critical \
			else oracle.randi_range(int(LINT_SPIT["dmg"][0]), maximum)
		base += int(actor.get("dmg_bonus", 0))
		base = StitchedS1BEffects.enemy_damage(base, battle.candle())
		var marked := int(target.get("statuses", {}).get("mark", 0)) > 0
		var damage := StitchedRules.damage_after_modifiers(base,
			actor.get("statuses", {}), target.get("statuses", {}), marked, 0,
			int(target.get("prot", 0)))
		var damage_ok: bool = bool(result.get("crit", false)) == critical \
			and int(result.get("damage", -1)) == damage and damage > 0 \
			and int(result.get("target_hp", -1)) == int(target.get("hp", -2)) - damage
		_check(damage_ok, "AC3: a landed Lint Spit deals its seeded post-PROT 2-3 base damage")
		var status_ok: bool = _count_status(result.get("statuses", []), "blind") == 1 \
			and _count_status(result.get("statuses", []), "exposed") == 1 \
			and result.get("statuses", []).size() == 2
		_check(status_ok, "AC3: a landed Lint Spit records exactly Blind 1 and Exposed 1")
		# Blind waits for the doll's own attack and stays. Exposed is a start-of-turn clock,
		# so a doll that takes the very next turn has already ticked it down once.
		var exposed_after: int = int(after.get("statuses", {}).get("exposed", 0))
		var exposed_ticked: bool = exposed_after == 0 and battle.current_actor_id() == target_id
		_check(int(after.get("statuses", {}).get("blind", 0)) == 1
			and (exposed_after == 1 or exposed_ticked),
			"AC3: the hit doll really carries Blind 1 and Exposed 1 (or its immediate tick)")
	else:
		_check(int(result.get("roll", 0)) > chance
			and int(result.get("damage", -1)) == 0
			and result.get("statuses", []).is_empty()
			and int(after.get("hp", -1)) == int(target.get("hp", -2))
			and after.get("statuses", {}) == target.get("statuses", {}),
			"AC4: a genuine Lint Spit miss leaves no damage, Blind or Exposed")
	# The spit never splashes: every other doll keeps its exact HP and statuses.
	for hero in heroes_before:
		var hero_id := str(hero.get("id", ""))
		if hero_id == target_id:
			continue
		var now := battle.get_unit(hero_id)
		_check(not now.is_empty() and int(now.get("hp", -1)) == int(hero.get("hp", -2))
			and now.get("statuses", {}) == hero.get("statuses", {}),
			"AC3: Lint Spit leaves %s untouched, never a party-wide splash" % hero_id)
	return {
		"ok": true,
		"hit": bool(result.get("hit", false)),
		"target_id": target_id,
		"target_rank": target_rank,
		"retained_exposed": int(after.get("statuses", {}).get("exposed", 0)),
		"receipts": receipts,
		"state": battle.state_snapshot(),
		"rng": battle.rng_state(),
		"battle": battle,
	}


func _count_status(statuses: Array, name: String) -> int:
	var total := 0
	for entry in statuses:
		if entry is Dictionary and str(entry.get("status", "")) == name:
			total += 1
	return total


func _lint_witnesses() -> Dictionary:
	var hit_seed := 0
	var miss_seed := 0
	for seed_value in range(SEED_FIRST, SEED_LAST + 1):
		var trace := _lint_trace(seed_value, 3)
		if trace.is_empty():
			return {}
		if bool(trace["hit"]) and int(trace.get("retained_exposed", 0)) == 1 and hit_seed == 0:
			hit_seed = seed_value
		if not bool(trace["hit"]) and miss_seed == 0:
			miss_seed = seed_value
		if hit_seed > 0 and miss_seed > 0:
			break
	_check(hit_seed > 0 and miss_seed > 0,
		"AC3: the bounded seed cohort witnesses both a landed and a missed rear-rank Lint Spit")
	print("Lint Spit witness seeds: hit=", hit_seed, ", miss=", miss_seed)
	for seed_value in [hit_seed, miss_seed]:
		if seed_value == 0:
			continue
		var first := _lint_trace(seed_value, 3)
		var replay := _lint_trace(seed_value, 3)
		first.erase("battle")
		replay.erase("battle")
		_check(not first.is_empty() and first == replay,
			"AC4: the selected Lint Spit schedule exactly replays receipts/state/RNG")
	return {"ok": hit_seed, "hit": hit_seed, "miss": miss_seed}


## A genuine hit at rear hero rank 3 is not enough on its own: the same rank-2 termite can
## also reach living hero ranks 2 and 4, still as one target at a time.
func _lint_legal_ranks() -> void:
	for rank in [2, 3, 4]:
		var trace := _lint_trace(7, rank)
		_check(not trace.is_empty() and int(trace.get("target_rank", 0)) == rank
			and int(trace.get("target_rank", 0)) != 1,
			"AC3: a rank-2 Quilt Termite can legally spit at living hero rank %d" % rank)


## The shipped live chooser picks the authored third action once the termite stands in rank
## 2, projecting exactly one legal doll and never a splash.
func _lint_natural(seed_value: int) -> void:
	var battle := _battle(seed_value, [RAGLING, TERMITE])
	if battle == null:
		return
	var receipts: Array = []
	if not _to_round(battle, 2, TERMITE, receipts):
		_check(false, "AC3: a genuine second-round termite turn is reachable")
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(TERMITE))
	_check(state == battle.state_snapshot() and rng == battle.rng_state(),
		"AC4: the read-only intent projection spends no state, order or RNG")
	_check(not bool(intent.get("pass", true))
		and str(intent.get("ability_id", "")) == "termite_lint_spit"
		and str(intent.get("ability_name", "")) == "Lint Spit"
		and str(intent.get("ability_kind", "")) == "ranged"
		and str(intent.get("target_side", "")) == "hero"
		and int(intent.get("target_rank", 0)) == 2
		and intent.get("affected_ranks", []) == [2]
		and not bool(intent.get("multi", true))
		and int(intent.get("base_acc", -1)) == 84
		and intent.get("base_damage") == [2, 3]
		and intent.get("base_effects") == {"blind": 1, "exposed": 1},
		"AC3: the shipped chooser projects Lint Spit as one rear target, skipping the rank-1-only swarm")
	var receipt := battle.use_foe_ability(str(intent.get("ability_id", "")),
		int(intent.get("target_rank", 0)))
	receipts.append(receipt)
	_check(bool(receipt.get("ok", false)) and receipt.get("ability") == "termite_lint_spit"
		and receipt.get("results", []).size() == 1,
		"AC3: the advertised Lint Spit executes through the real rules as one target")


# ---------------------------------------------------------------- AC4 refusals

func _refusals() -> void:
	# Wrong turn and wrong side on a hero turn.
	var battle := _battle(3, [RAGLING, TERMITE])
	if battle == null:
		return
	for step in range(TURN_LIMIT):
		if battle.is_over() or battle.current_side() == "hero":
			break
		battle.pass_turn()
	_check(battle.current_side() == "hero", "AC4: a real hero turn precedes the wrong-turn probes")
	_check_silent_refusal(battle, "termite_lint_spit", 3, "not a foe turn",
		"AC4: Lint Spit during a hero turn is refused without Snip/Blind/Exposed or RNG")
	_check_silent_refusal(battle, "quilt_chew", 1, "not a foe turn",
		"AC4: Quilt Chew during a hero turn is refused without Snip or RNG")
	# Wrong foe: only the Quilt Termite owns the new action.
	var other_foe := ""
	for step in range(TURN_LIMIT):
		if battle.is_over():
			break
		if battle.current_side() == "foe" and battle.current_actor_id() != TERMITE:
			other_foe = battle.current_actor_id()
			break
		battle.pass_turn()
	_check(not other_foe.is_empty(), "AC4: ragling genuinely gets its own foe turn")
	if not other_foe.is_empty():
		_check_silent_refusal(battle, "termite_lint_spit", 3, "has no ability",
			"AC4: another foe cannot spend the Quilt Termite's Lint Spit")
		# Wrong side: hero actions are refused during that genuine foe turn.
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var wrong_move := battle.move(1)
		var wrong_part := battle.use_part("warden_arm_shield_bash", 1)
		_check(not bool(wrong_move.get("ok", true))
			and str(wrong_move.get("error", "")) == "it is not a hero turn"
			and not bool(wrong_part.get("ok", true))
			and str(wrong_part.get("error", "")) == "it is not a hero turn"
			and before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC4: wrong-side hero actions refuse with unchanged state, turn and RNG")
	# Wrong rank, dead target and a rank-1 termite that cannot launch Lint Spit.
	var not_launch := _battle(11, [TERMITE, RAGLING])
	if not_launch != null:
		var receipts: Array = []
		if _to(not_launch, TERMITE, receipts):
			_check_silent_refusal(not_launch, "termite_lint_spit", 3,
				"ability cannot launch from rank 1",
				"AC3/4: a rank-1 Quilt Termite cannot launch Lint Spit")
			_check_silent_refusal(not_launch, "termite_lint_spit", 1,
				"ability cannot launch from rank 1",
				"AC3/4: an illegal Lint Spit never applies Blind or Exposed from rank 1")
	var rank_battle := _battle(13, [RAGLING, TERMITE])
	if rank_battle != null:
		var receipts: Array = []
		if _to(rank_battle, TERMITE, receipts):
			_check_silent_refusal(rank_battle, "termite_lint_spit", 1,
				"no legal target in rank 1",
				"AC3/4: Lint Spit cannot target hero rank 1")
			for rank in [0, 5]:
				_check_silent_refusal(rank_battle, "termite_lint_spit", rank,
					"no legal target in rank %d" % rank,
					"AC4: hero rank %d is rejected atomically with no status or RNG spend" % rank)
			var legal := rank_battle.use_foe_ability("termite_lint_spit", 2)
			_check(bool(legal.get("ok", false)) and legal.get("results", []).size() == 1,
				"AC4: the refused casts leave the legal rear-rank spit available")
	# A lost/absent rank 3 doll is never a Lint Spit target.
	var party: Array = preview["heroes"].duplicate(true)
	party[2].merge({"hp": 0, "lost": true, "parts": {}}, true)
	var lost_id := str(party[2]["id"])
	var absent := _battle(5, [RAGLING, TERMITE], party)
	if absent != null:
		var receipts: Array = []
		if _to(absent, TERMITE, receipts):
			_check(bool(absent.get_unit(lost_id).get("lost", false))
				and int(absent.get_unit(lost_id).get("hp", -1)) == 0,
				"AC4: the rear doll really is absent before the spit")
			_check_silent_refusal(absent, "termite_lint_spit", 3,
				"no legal target in rank 3",
				"AC4: Lint Spit cannot target a dead/absent hero rank 3")
			var ghost := absent.get_unit(lost_id)
			var legal := absent.use_foe_ability("termite_lint_spit", 2)
			_check(bool(legal.get("ok", false)) and legal.get("results", []).size() == 1,
				"AC4: the legal spit still resolves on the living rank 2 doll")
			_check(absent.get_unit(lost_id) == ghost,
				"AC4: the absent doll stays completely untouched by the rejected spit")


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


# ---------------------------------------------------------------- AC1/AC4 rank-1 rotation

## Three genuine round-rotated turns at rank 1: Chew, the unchanged Swarm and Chew again,
## because Lint Spit's launch masks exclude rank 1. Receipts, state and RNG replay exactly.
func _rotation(seed_value: int) -> Dictionary:
	var battle := _battle(seed_value, [TERMITE, RAGLING])
	if battle == null:
		return {}
	var receipts: Array = []
	var seen: Array = []
	for round_value in range(1, 4):
		if not _to(battle, TERMITE, receipts):
			return {}
		_check(int(battle.round_number()) == round_value,
			"AC4: genuine natural round %d" % round_value)
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit(TERMITE))
		_check(before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC4: read-only intent projection spends no state or RNG in round %d" % round_value)
		var authored: Dictionary = QUILT_CHEW if round_value != 2 else TERMITE_SWARM
		var expected_side := "foe" if authored["target_side"] == "self" else "hero"
		_check(not bool(intent.get("pass", true))
			and str(intent.get("ability_id", "")) == authored["id"]
			and str(intent.get("ability_name", "")) == authored["name"]
			and str(intent.get("ability_kind", "")) == authored["kind"]
			and str(intent.get("target_side", "")) == expected_side
			and int(intent.get("target_rank", 0)) == 1
			and intent.get("affected_ranks", []) == [1]
			and not bool(intent.get("multi", true))
			and int(intent.get("base_acc", -1)) == authored["acc"]
			and intent.get("base_damage") == authored["dmg"]
			and intent.get("base_effects") == authored["effects"],
			"AC1/AC4: round %d projects the authored action and base numbers" % round_value)
		var executed := battle.use_foe_ability(str(intent.get("ability_id", "")),
			int(intent.get("target_rank", 0)))
		receipts.append(executed)
		_check(bool(executed.get("ok", false))
			and executed.get("ability") == authored["id"]
			and executed.get("results", []).size() == 1,
			"AC1/AC4: the advertised round-%d action executes through the real rules" % round_value)
		if round_value == 2:
			var results: Array = executed.get("results", [])
			var buffed := battle.get_unit(TERMITE)
			_check(results.size() == 1
				and results[0].get("statuses", [])
					== [{"status": "dodge", "amount": 4, "duration": 1}]
				and int(buffed.get("dodge_buff", {}).get("amount", 0)) == 4
				and int(buffed.get("dodge_buff", {}).get("turns", 0)) == 1
				and StitchedRules.effective_dodge(buffed) == int(buffed.get("dodge", 0)) + 4,
				"AC4: the unchanged Termite Swarm still grants real Dodge 4 for one turn")
		seen.append(executed.get("ability"))
	_check(seen == ["quilt_chew", "termite_swarm", "quilt_chew"],
		"AC1/AC4: rank-1 rotation observes Chew then unchanged Swarm and never launches Lint Spit")
	return {"receipts": receipts, "state": battle.state_snapshot(), "rng": battle.rng_state()}
