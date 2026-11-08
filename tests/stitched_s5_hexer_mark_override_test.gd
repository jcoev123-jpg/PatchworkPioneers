extends SceneTree
## S5 Spool Hexer live Mark-triggered Hex Bolt priority.
##
## The canonical elite's Hex Bolt is its authored answer to a Marked doll. When the ordinary
## round rotation would raise Spool Curse or sew Thread Tag, a living doll already carrying an
## active Mark makes the chooser interrupt that rotation with the real Hex Bolt instead.
##
## Everything is deterministic and headless: the real enemy catalog, the shipped four-doll
## preview, genuinely seeded StitchedRules battles and only the public seeded action path. One
## clearly labelled read-only selector fixture plants an active Mark status to choose a turn and
## target; no HP, roll or receipt is ever manufactured. The receipt proof advances real turns
## with PASS and lands the chosen bolt through use_foe_ability().

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const HEXER := "spool_hexer"
const PARTNER := "ragling"
const BOLT := "hex_bolt"
const CURSE := "spool_curse"
const TAG := "thread_tag"
const MARK := 3
const MARK_BONUS := 3
const SEED_LIMIT := 60

const BOLT_SOURCE := {
	"id": "hex_bolt", "name": "Hex Bolt", "kind": "ranged",
	"launch": [1, 4], "target": [1, 3], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [4, 5], "crit": 0, "mark_damage": 3, "effects": {"weak": 1},
	"self_move": 0, "move": "attack2",
}
const CURSE_SOURCE := {
	"id": "spool_curse", "name": "Spool Curse", "kind": "debuff",
	"launch": [1, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "multi": true,
	"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"exposed": 2},
	"self_move": 0, "move": "skill",
}
const TAG_SOURCE := {
	"id": "thread_tag", "name": "Thread Tag", "kind": "debuff",
	"launch": [1, 2, 3, 4], "target": [1, 2, 3], "target_side": "enemy", "multi": false,
	"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"mark": 3},
	"self_move": 0, "move": "skill",
}

var checks := 0
var failures: Array[String] = []
var _catalog: Dictionary = {}
var _preview: Dictionary = {}
var _witnesses: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _run() -> void:
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"the real enemy catalog loads: " + str(_catalog.get("error", "")))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(parsed is Dictionary and parsed.get("heroes", []).size() == 4,
		"the shipped preview authors the real four-doll party")
	if not bool(_catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	_preview = parsed
	_test_authored_record()
	_test_curse_rotation_priority()
	_test_tag_rotation_priority()
	_test_disallowed_launch()
	_test_bolt_receipt()
	_test_other_foes_and_refusals()
	_test_replay()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_hexer_mark_override_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _norm(value: Variant) -> Variant:
	if value is Array:
		var array: Array = []
		for item in value:
			array.append(_norm(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[key] = _norm(value[key])
		return dictionary
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return value


func _ability(unit: Dictionary, ability_id: String) -> Dictionary:
	for ability in unit.get("abilities", []):
		if str(ability.get("id", "")) == ability_id:
			return ability
	return {}


# ---------------------------------------------------------------- AC1 authored contract

func _test_authored_record() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITES))
	_check(parsed is Array, "AC1: the canonical elite source parses as an array")
	if not parsed is Array:
		return
	var matches: Array = []
	for record in parsed:
		if record is Dictionary and str(record.get("id", "")) == HEXER:
			matches.append(record)
	_check(matches.size() == 1, "AC1: exactly one Spool Hexer record remains authored")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	_check(str(record.get("name", "")) == "Spool Hexer" and int(record.get("max_hp", 0)) == 24
		and str(record.get("art_path", "")) == "res://assets/paper/enemies/spool_hexer.png",
		"AC1: the legacy HP, name and figure are unchanged")
	var profile: Dictionary = record.get("stitched", {})
	_check(int(profile.get("max_hp", 0)) == 24 and int(profile.get("speed", -1)) == 6
		and int(profile.get("dodge", -1)) == 7 and int(profile.get("acc", -1)) == 0
		and int(profile.get("prot", -1)) == 2 and not bool(profile.get("is_boss", true))
		and int(profile.get("turns_per_round", 0)) == 1
		and str(profile.get("trophy", "")) == "spool_hexer_spool",
		"AC1: the elite keeps its shipped stats, single turn and spool trophy")
	var authored: Array = profile.get("abilities", [])
	_check(authored.size() == 3 and _norm(authored[0]) == _norm(BOLT_SOURCE)
		and _norm(authored[1]) == _norm(CURSE_SOURCE) and _norm(authored[2]) == _norm(TAG_SOURCE),
		"AC1: all three authored moves keep their exact shipped values, Hex Bolt included")
	var foe := StitchedEnemyCatalog.foe_for(_catalog, HEXER)
	_check(not foe.is_empty(), "AC1: the real loader resolves the Spool Hexer")
	if foe.is_empty():
		return
	_check(StitchedEnemyCatalog.trophy_for(_catalog, HEXER) == "spool_hexer_spool",
		"AC1: the loaded elite still drops its own spool trophy")
	var bolt := _ability(foe, BOLT)
	var validated: Variant = StitchedParts.validate_ability(BOLT_SOURCE)
	_check(not bolt.is_empty() and bool(validated.get("ok", false))
		and bolt == validated.get("ability", {}),
		"AC1: the loaded Hex Bolt is exactly the normalized authored bolt")
	if bolt.is_empty():
		return
	for rank in range(1, 5):
		_check(StitchedParts.ranks_allowed(int(bolt["launch_mask"]), rank) == [1, 4].has(rank),
			"AC1: the authored Hex Bolt launches from its authored ranks 1 and 4 (rank %d)" % rank)
		_check(StitchedParts.ranks_allowed(int(bolt["target_mask"]), rank) == [1, 3].has(rank),
			"AC1: the authored Hex Bolt reaches only ranks 1 and 3 (rank %d)" % rank)
	# The two debuff rotations it interrupts are still the shipped actions.
	_check(_norm(_ability(foe, CURSE)) == _norm(StitchedParts.validate_ability(CURSE_SOURCE).ability)
		and _norm(_ability(foe, TAG)) == _norm(StitchedParts.validate_ability(TAG_SOURCE).ability),
		"AC1: Spool Curse and Thread Tag keep their exact shipped records")


# ---------------------------------------------------------------- fixtures

func _config(seed_value: int, order: Array = [HEXER, PARTNER]) -> Dictionary:
	var foes: Array = []
	for enemy_id in order:
		foes.append(StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id)))
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	return {"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": _preview["heroes"].duplicate(true), "parts": parts, "foes": foes}


func _battle(seed_value: int, order: Array = [HEXER, PARTNER]) -> StitchedRules:
	for enemy_id in order:
		if StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id)).is_empty():
			_check(false, "a real canonical foe loads beside the Hexer: " + str(enemy_id))
			return null
	var created := StitchedRules.create(_config(seed_value, order))
	_check(bool(created.get("ok", false)),
		"the real seeded 4v2 fight builds: " + str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 2,
		"four living dolls face the Hexer and its partner")
	return battle


## Real legal public passes until the Hexer holds its own turn in the wanted round. Nothing is
## rolled and no status is written here; only the ordinary PASS action advances the fight.
func _advance_silent(battle: StitchedRules, wanted_round: int) -> bool:
	for step in range(200):
		if battle == null or battle.is_over():
			return false
		if battle.round_number() > wanted_round:
			return false
		if battle.current_actor_id() == HEXER and battle.round_number() == wanted_round:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


func _hero_at_rank(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


## The actor's ordinary round-rotated first legal ability, computed independently from the
## canonical authored kit and the same public legality authority the chooser uses.
func _rotation(battle: StitchedRules, actor: Dictionary) -> String:
	var authored: Array = actor.get("abilities", [])
	if authored.is_empty():
		return ""
	var offset := (battle.round_number() - 1) % authored.size()
	for step in range(authored.size()):
		var ability: Dictionary = authored[(offset + step) % authored.size()]
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor.get("rank", 0))) \
				or not battle._self_move_gate(actor, ability).is_empty():
			continue
		for rank in range(1, 5):
			if not battle._legal_targets(actor, ability, rank).is_empty():
				return str(ability.get("id", ""))
	return ""


func _baseline(battle: StitchedRules) -> Dictionary:
	var saved: Dictionary = {}
	for hero in battle.get_heroes():
		saved[str(hero["id"])] = hero.duplicate(true)
	for foe in battle.get_foes():
		saved[str(foe["id"])] = foe.duplicate(true)
	return saved


func _restore(battle: StitchedRules, baseline: Dictionary) -> void:
	for unit_id in baseline:
		battle._units[unit_id] = baseline[unit_id].duplicate(true)


# ---------------------------------------------------------------- chooser priority cases

## One read-only chooser case on a real Hexer turn. `setup` mutates the authoritative unit
## records only where genuine prior damage, movement or statuses would have, then the chooser
## must name `expected` while the ordinary rotation is `rotation`. Two identical projections
## must spend neither battle state nor RNG.
func _case(battle: StitchedRules, baseline: Dictionary, setup: Callable,
		expected: String, expected_rank: int, rotation: String, note: String) -> void:
	_restore(battle, baseline)
	setup.call()
	var hexer := battle.get_unit(HEXER)
	_check(_rotation(battle, hexer) == rotation,
		note + ": the fixture's ordinary rotation is " + rotation)
	var before_state := battle.state_snapshot()
	var before_rng := battle.rng_state()
	var first := StitchedFoeIntent.choose(battle, hexer)
	var second := StitchedFoeIntent.choose(battle, hexer)
	_check(_norm(first) == _norm(second) and before_state == battle.state_snapshot()
		and before_rng == battle.rng_state(),
		note + ": two identical projections spend no battle state or RNG")
	_check(not first.is_empty() and str(first.get("ability_id", "")) == expected
		and not bool(first.get("pass", true)),
		note + ": the chooser selects " + expected)
	if str(first.get("ability_id", "")) != expected:
		return
	if expected == BOLT:
		_check(expected_rank > 0 and int(first.get("target_rank", 0)) == expected_rank
			and first.get("affected_ranks") == [expected_rank],
			note + ": the chosen legal target rank is %d" % expected_rank)
		_check(str(first.get("ability_name", "")) == "Hex Bolt"
			and str(first.get("ability_kind", "")) == "ranged"
			and str(first.get("target_side", "")) == "hero"
			and not bool(first.get("multi", true))
			and int(first.get("base_acc", -1)) == 88
			and first.get("base_damage") == [4, 5]
			and int(first.get("base_crit", -1)) == 0
			and int(first.get("base_mark_damage", -1)) == MARK_BONUS
			and first.get("base_effects") == {"weak": 1},
			note + ": the projection advertises unchanged authored ACC 88, 4-5, +3 vs Mark and Weak 1")
	else:
		var ability := _ability(hexer, expected)
		var chosen_rank := 0
		for rank in range(1, 5):
			if not battle._legal_targets(hexer, ability, rank).is_empty():
				chosen_rank = rank
				break
		var expected_ranks: Array = []
		if chosen_rank > 0:
			for target in battle._legal_targets(hexer, ability, chosen_rank):
				if not expected_ranks.has(int(target["rank"])):
					expected_ranks.append(int(target["rank"]))
		expected_ranks.sort()
		_check(not ability.is_empty() and first.get("affected_ranks") == expected_ranks
			and bool(first.get("multi", false)) == bool(ability.get("multi", false))
			and int(first.get("base_mark_damage", -1)) == int(ability.get("mark_damage", 0)),
			note + ": the fallback keeps the exact ordinary " + expected + " projection")


func _test_curse_rotation_priority() -> void:
	var battle := _battle(37)
	if battle == null:
		return
	if not _advance_silent(battle, 2):
		_check(false, "AC1: the real seeded fight reaches the Hexer's round-two turn")
		return
	var hexer := battle.get_unit(HEXER)
	_check(battle.round_number() == 2 and battle.current_actor_id() == HEXER
		and _rotation(battle, hexer) == CURSE,
		"AC1: the real rank-one Hexer's ordinary round-two rotation is Spool Curse")
	var baseline := _baseline(battle)
	var rank_one := _hero_at_rank(battle, 1)
	var rank_two := _hero_at_rank(battle, 2)
	var rank_three := _hero_at_rank(battle, 3)
	var rank_four := _hero_at_rank(battle, 4)
	_check(not rank_one.is_empty() and not rank_two.is_empty() and not rank_three.is_empty()
		and not rank_four.is_empty(),
		"AC1: the fixture carries distinct living dolls in all four hero ranks")
	if rank_one.is_empty() or rank_two.is_empty() or rank_three.is_empty() or rank_four.is_empty():
		return
	# AC1: a Mark on the reachable third rank interrupts the line-wide Spool Curse.
	_case(battle, baseline, func() -> void:
		battle._units[rank_three]["statuses"]["mark"] = MARK, BOLT, 3, CURSE,
		"AC1: an active Mark in reachable rank 3 overrides the Spool Curse rotation")
	# Both authored reach ranks Marked: the nearer rank 1 wins.
	_case(battle, baseline, func() -> void:
		battle._units[rank_one]["statuses"]["mark"] = MARK
		battle._units[rank_three]["statuses"]["mark"] = MARK, BOLT, 1, CURSE,
		"AC1: two legal Marks keep the nearer rank 1, not the deeper rank 3")
	# AC2 negatives: a Mark outside the bolt's authored reach never invents a bolt.
	_case(battle, baseline, func() -> void:
		battle._units[rank_two]["statuses"]["mark"] = MARK, CURSE, -1, CURSE,
		"AC2: a Mark only in rank 2 is out of Hex Bolt's reach and never chosen")
	_case(battle, baseline, func() -> void:
		battle._units[rank_four]["statuses"]["mark"] = MARK, CURSE, -1, CURSE,
		"AC2: a Mark only in rank 4 is out of Hex Bolt's reach and never chosen")
	_case(battle, baseline, func() -> void:
		battle._units[rank_two]["statuses"]["mark"] = MARK
		battle._units[rank_four]["statuses"]["mark"] = MARK, CURSE, -1, CURSE,
		"AC2: Marks only in ranks 2 and 4 leave the Spool Curse rotation untouched")
	# AC2: an expired or absent Mark is not prey.
	_case(battle, baseline, func() -> void:
		battle._units[rank_three]["statuses"]["mark"] = 0, CURSE, -1, CURSE,
		"AC2: an expired zero Mark invents no Hex Bolt")
	_case(battle, baseline, func() -> void: pass, CURSE, -1, CURSE,
		"AC2: no Mark at all leaves the ordinary Spool Curse rotation untouched")
	# AC2: a Marked but non-living or departed doll is not prey.
	_case(battle, baseline, func() -> void:
		battle._units[rank_three]["statuses"]["mark"] = MARK
		battle._units[rank_three]["hp"] = 0
		battle._units[rank_three]["hanging"] = true, CURSE, -1, CURSE,
		"AC2: a Marked but zero-HP Hanging doll is not reachable prey")
	_case(battle, baseline, func() -> void:
		battle._units[rank_three]["statuses"]["mark"] = MARK
		battle._units[rank_three]["lost"] = true
		battle._units[rank_three]["hp"] = 0, CURSE, -1, CURSE,
		"AC2: a Marked but LOST doll is not reachable prey")
	_case(battle, baseline, func() -> void:
		battle._units[rank_three]["statuses"]["mark"] = MARK
		battle._units[rank_three]["dead"] = true, CURSE, -1, CURSE,
		"AC2: a Marked but dead doll is not reachable prey")
	_restore(battle, baseline)
	var restored := StitchedFoeIntent.choose(battle, battle.get_unit(HEXER))
	_check(str(restored.get("ability_id", "")) == CURSE,
		"AC2: restoring the authoritative units restores the ordinary curse fallback")


func _test_tag_rotation_priority() -> void:
	var battle := _battle(38)
	if battle == null:
		return
	if not _advance_silent(battle, 3):
		_check(false, "AC1: the real seeded fight reaches the Hexer's round-three turn")
		return
	var hexer := battle.get_unit(HEXER)
	_check(battle.round_number() == 3 and battle.current_actor_id() == HEXER
		and _rotation(battle, hexer) == TAG,
		"AC1: the real Hexer's ordinary round-three rotation is Thread Tag")
	var baseline := _baseline(battle)
	var rank_one := _hero_at_rank(battle, 1)
	var rank_three := _hero_at_rank(battle, 3)
	if rank_one.is_empty() or rank_three.is_empty():
		_check(false, "AC1: the tag fixture carries the reachable ranks 1 and 3")
		return
	_case(battle, baseline, func() -> void:
		battle._units[rank_one]["statuses"]["mark"] = MARK, BOLT, 1, TAG,
		"AC1: an active Mark in reachable rank 1 interrupts the Thread Tag rotation")
	_case(battle, baseline, func() -> void:
		battle._units[rank_three]["statuses"]["mark"] = MARK, BOLT, 3, TAG,
		"AC1: an active Mark in reachable rank 3 interrupts the Thread Tag rotation")
	_case(battle, baseline, func() -> void: pass, TAG, -1, TAG,
		"AC2: no Mark at all leaves the ordinary Thread Tag rotation untouched")
	_restore(battle, baseline)


## AC2: the Hexer built into the second foe rank genuinely cannot launch its authored Hex Bolt
## (its launch ranks are 1 and 4). A reachable Mark must never invent that bolt; the ordinary
## legal rotation applies and the public action refuses the illegal launch with no spend.
func _test_disallowed_launch() -> void:
	var battle := _battle(39, [PARTNER, HEXER])
	if battle == null:
		return
	if not _advance_silent(battle, 2):
		_check(false, "AC2: the rank-two Hexer fixture reaches its real round-two turn")
		return
	var hexer := battle.get_unit(HEXER)
	var bolt := _ability(hexer, BOLT)
	_check(int(hexer.get("rank", 0)) == 2
		and not StitchedParts.ranks_allowed(int(bolt.get("launch_mask", 0)), 2),
		"AC2: the real rank-two Hexer cannot launch its authored Hex Bolt")
	_check(_rotation(battle, hexer) == TAG,
		"AC2: its ordinary legal round-two fallback is the authored Thread Tag")
	var baseline := _baseline(battle)
	var rank_three := _hero_at_rank(battle, 3)
	if rank_three.is_empty():
		_check(false, "AC2: the rank-two fixture carries a reachable rank-three doll")
		return
	battle._units[rank_three]["statuses"]["mark"] = MARK
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(HEXER))
	_check(str(choice.get("ability_id", "")) == TAG and not bool(choice.get("pass", true))
		and state == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: a Mark never invents an unlaunchable bolt; the legal tag rotation applies")
	state = battle.state_snapshot()
	rng = battle.rng_state()
	var refused := battle.use_foe_ability(BOLT, 3)
	_check(not bool(refused.get("ok", true))
		and str(refused.get("error", "")).contains("cannot launch")
		and state == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: the public bolt from the unlaunchable rank is refused before any roll")
	_restore(battle, baseline)


# ---------------------------------------------------------------- AC3 the real bolt receipt

func _single_result(receipt: Dictionary) -> Dictionary:
	var results: Array = receipt.get("results", [])
	return results[0] if results.size() == 1 else {}


## One genuine round-two Hexer turn: real initiative passes, then the read-only selector fixture
## plants an active Mark in the reachable rank 3 so the chooser selects that authored bolt. The
## chosen bolt is then resolved through the public foe action exactly as the live driver does.
func _bolt_trace(seed_value: int) -> Dictionary:
	var battle := _battle(seed_value)
	if battle == null:
		return {}
	if not _advance_silent(battle, 2):
		return {}
	var hexer := battle.get_unit(HEXER)
	if _rotation(battle, hexer) != CURSE:
		return {}
	var rank_three := _hero_at_rank(battle, 3)
	var victim := battle.get_unit(rank_three)
	if rank_three.is_empty() or victim.is_empty() or bool(victim.get("lost", false)) \
			or int(victim.get("hp", 0)) <= 0:
		return {}
	# TEST-ONLY SELECTOR FIXTURE: plant an active Mark on an already-built living doll solely to
	# select this target. The receipt below is the real seeded foe action, never manufactured.
	battle._units[rank_three]["statuses"]["mark"] = MARK
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit(HEXER))
	if str(intent.get("ability_id", "")) != BOLT or int(intent.get("target_rank", 0)) != 3:
		return {}
	var actor_before := battle.get_unit(HEXER).duplicate(true)
	var victim_before := battle.get_unit(rank_three).duplicate(true)
	var state_before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var receipt := battle.use_foe_ability(BOLT, 3)
	var result := _single_result(receipt)
	if not bool(receipt.get("ok", false)) or result.is_empty():
		return {}
	return {
		"seed": seed_value, "battle": battle, "intent": intent, "receipt": receipt,
		"result": result, "actor_before": actor_before, "victim_before": victim_before,
		"victim_id": rank_three, "state_before": state_before, "rng_before": rng_before,
		"actor_after": battle.current_actor_id(),
	}


func _find_bolt_witnesses() -> Dictionary:
	var found := {"hit": {}, "miss": {}}
	for seed_value in range(1, SEED_LIMIT + 1):
		if not found["hit"].is_empty() and not found["miss"].is_empty():
			break
		var trace := _bolt_trace(seed_value)
		if trace.is_empty():
			continue
		var result: Dictionary = trace["result"]
		if bool(result.get("hit", false)) and found["hit"].is_empty():
			found["hit"] = trace
		elif not bool(result.get("hit", true)) and found["miss"].is_empty():
			found["miss"] = trace
	for key in found:
		_check(not found[key].is_empty(),
			"AC3: a bounded real seed witnesses the authored Hex Bolt " + key)
	return found


func _check_bolt_hit(trace: Dictionary) -> void:
	var battle: StitchedRules = trace["battle"]
	var actor: Dictionary = trace["actor_before"]
	var victim: Dictionary = trace["victim_before"]
	var result: Dictionary = trace["result"]
	var receipt: Dictionary = trace["receipt"]
	_check(str(receipt.get("ability", "")) == BOLT and str(receipt.get("actor", "")) == HEXER
		and str(receipt.get("actor_side", "")) == "foe",
		"AC3: the selected bolt resolves as the Spool Hexer's own public foe action")
	_check(str(result.get("target", "")) == str(trace["victim_id"])
		and str(result.get("target_side", "")) == "hero"
		and int(result.get("target_rank", 0)) == 3,
		"AC3: the receipt names the reachable Marked rank-three doll")
	var chance := StitchedRules.hit_chance(
		88 + int(actor.get("acc", 0)) + int(battle.candle_band()["enemy_acc"]),
		StitchedRules.effective_dodge(victim), int(actor.get("miss_streak", 0)))
	_check(result.has("roll") and int(result.get("hit_chance", -1)) == chance
		and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
		"AC3: the bolt keeps its ordinary seeded ACC 88 / Dodge hit roll")
	var clean := int(victim.get("statuses", {}).get("exposed", 0)) == 0 \
		and int(victim.get("statuses", {}).get("tangled", 0)) == 0 \
		and int(victim.get("statuses", {}).get("weak", 0)) == 0 \
		and int(actor.get("statuses", {}).get("weak", 0)) == 0
	_check(clean, "AC3: the witness marked hit is a clean direct base, so the delta is the Mark alone")
	var bases: Array = [StitchedRules.crit_damage(5)] if bool(result.get("crit", false)) else [4, 5]
	var marked_values: Array = []
	var unmarked_values: Array = []
	for base in bases:
		var scaled := StitchedS1BEffects.enemy_damage(
			int(base) + int(actor.get("dmg_bonus", 0)), battle.candle())
		marked_values.append(StitchedRules.damage_after_modifiers(scaled, actor["statuses"],
			victim["statuses"], true, MARK_BONUS, int(victim.get("prot", 0))))
		unmarked_values.append(StitchedRules.damage_after_modifiers(scaled, actor["statuses"],
			victim["statuses"], false, MARK_BONUS, int(victim.get("prot", 0))))
	_check(marked_values.has(int(result.get("damage", -1))),
		"AC3: a landed bolt deals the canonical marked value through the real rules")
	var mark_explains := true
	for value in unmarked_values:
		if marked_values.has(value):
			mark_explains = false
	_check(mark_explains and not unmarked_values.has(int(result.get("damage", -1))),
		"AC3: only the authored +3 versus Mark explains this hit, never an unmarked value")
	_check(int(result.get("target_hp", -1))
		== int(victim.get("hp", 0)) - int(result.get("damage", 0)),
		"AC3: the receipt reports the doll's real HP after the hit")
	_check(result.get("statuses") == [{"status": "weak", "duration": 1}],
		"AC3: a landed bolt applies exactly the authored Weak 1")
	var after := battle.get_unit(str(trace["victim_id"]))
	# The public action spends the Hexer's turn; if the struck doll enters its own turn next, its
	# start-of-turn tick already took one from the fresh Weak. Nothing else may change it.
	var ticked := str(trace["actor_after"]) == str(trace["victim_id"])
	_check(int(after.get("statuses", {}).get("weak", 0)) == 1 - (1 if ticked else 0),
		"AC3: the real struck doll carries the Weak it was dealt, minus only its own immediate tick")


func _check_bolt_miss(trace: Dictionary) -> void:
	var battle: StitchedRules = trace["battle"]
	var actor: Dictionary = trace["actor_before"]
	var victim: Dictionary = trace["victim_before"]
	var result: Dictionary = trace["result"]
	var chance := StitchedRules.hit_chance(
		88 + int(actor.get("acc", 0)) + int(battle.candle_band()["enemy_acc"]),
		StitchedRules.effective_dodge(victim), int(actor.get("miss_streak", 0)))
	_check(result.has("roll") and int(result.get("hit_chance", -1)) == chance
		and bool(result.get("hit", true)) == (int(result.get("roll", 101)) <= chance),
		"AC3: the natural miss is its own seeded roll, not a forced outcome")
	_check(int(result.get("damage", -1)) == 0
		and int(result.get("target_hp", -1)) == int(victim.get("hp", -2))
		and bool(result.get("crit", true)) == false,
		"AC3: a miss deals no damage and reports no crit")
	_check(result.get("statuses", [-1]) == [],
		"AC3: a miss applies no Weak and no other false status")
	var after := battle.get_unit(str(trace["victim_id"]))
	var ticked := str(trace["actor_after"]) == str(trace["victim_id"])
	var expected_mark := MARK - (1 if ticked else 0)
	_check(int(after.get("hp", -1)) == int(victim.get("hp", -2))
		and int(after.get("statuses", {}).get("weak", 0))
			== int(victim.get("statuses", {}).get("weak", 0))
		and int(after.get("statuses", {}).get("mark", 0)) == expected_mark,
		"AC3: the missed doll keeps its real HP and statuses, minus only its own immediate tick")
	var before_turn: Dictionary = trace["state_before"]
	_check(battle.current_actor_id() != HEXER or battle.round_number() > int(before_turn["round"])
		or int(battle.state_snapshot()["turn_index"]) > int(before_turn["turn_index"]),
		"AC3: the public action still spends the Hexer's turn on a miss")


func _test_bolt_receipt() -> void:
	_witnesses = _find_bolt_witnesses()
	if not _witnesses["hit"].is_empty():
		_check_bolt_hit(_witnesses["hit"])
	if not _witnesses["miss"].is_empty():
		_check_bolt_miss(_witnesses["miss"])


# ---------------------------------------------------------------- AC2/AC4 refusals, other foes

func _test_other_foes_and_refusals() -> void:
	var battle := _battle(37)
	if battle == null:
		return
	if not _advance_silent(battle, 2):
		_check(false, "AC2: the refusal fixture reaches the real round-two Hexer turn")
		return
	var baseline := _baseline(battle)
	var rank_three := _hero_at_rank(battle, 3)
	if rank_three.is_empty():
		_check(false, "AC2: the refusal fixture carries a reachable rank-three doll")
		return
	# AC4: an unrelated living foe beside the Hexer keeps its own existing rotation, Mark or not.
	_restore(battle, baseline)
	var partner := battle.get_unit(PARTNER)
	var plain := StitchedFoeIntent.choose(battle, partner)
	_check(not partner.is_empty() and str(plain.get("ability_id", "")) == _rotation(battle, partner)
		and str(plain.get("ability_id", "")) != BOLT,
		"AC4: the partner foe keeps exactly its own ordinary rotation choice")
	battle._units[rank_three]["statuses"]["mark"] = MARK
	var marked := StitchedFoeIntent.choose(battle, battle.get_unit(PARTNER))
	_check(_norm(marked) == _norm(plain),
		"AC4: the Hexer's Mark priority never leaks to another foe's projection")
	_restore(battle, baseline)
	# AC2: a stunned Hexer announces STUN and invents no bolt.
	battle._units[rank_three]["statuses"]["mark"] = MARK
	battle._units[HEXER]["statuses"]["stun"] = 1
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var stunned := StitchedFoeIntent.choose(battle, battle.get_unit(HEXER))
	_check(bool(stunned.get("stun", false)) and bool(stunned.get("pass", true))
		and str(stunned.get("ability_id", "")) == ""
		and not stunned.has("base_damage") and not stunned.has("base_effects")
		and state == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: a stunned Hexer reports no action and invents no Hex Bolt")
	_restore(battle, baseline)
	# AC2: dead, detached and empty foe records never invent an intent.
	state = battle.state_snapshot()
	rng = battle.rng_state()
	_check(StitchedFoeIntent.choose(battle, {}).is_empty()
		and StitchedFoeIntent.choose(battle, {"id": "ghost_foe"}).is_empty()
		and state == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: an empty or detached foe request is refused without state or RNG spend")
	battle._units[HEXER]["dead"] = true
	battle._units[HEXER]["hp"] = 0
	_check(StitchedFoeIntent.choose(battle, battle.get_unit(HEXER)).is_empty(),
		"AC2: a dead Hexer has no selectable intent")
	_restore(battle, baseline)
	var restored := StitchedFoeIntent.choose(battle, battle.get_unit(HEXER))
	_check(str(restored.get("ability_id", "")) == CURSE,
		"AC2: the restored Hexer returns to its ordinary curse rotation without a Mark")


# ---------------------------------------------------------------- AC4 exact replay

## One legal seeded transcript: heroes PASS, every foe acts through the unchanged chooser, and on
## the Hexer's round-two turn the read-only selector fixture plants the reachable Mark so the
## new priority is really exercised. It returns the chosen abilities, targets, receipts and the
## final state/RNG so two fresh runs can be compared exactly.
func _transcript(seed_value: int) -> Dictionary:
	var battle := _battle(seed_value)
	if battle == null:
		return {}
	var choices: Array = []
	var receipts: Array = []
	for step in range(240):
		if battle.is_over() or battle.round_number() > 4:
			break
		if battle.current_side() == "hero":
			receipts.append(battle.pass_turn())
			continue
		var actor := battle.get_unit(battle.current_actor_id())
		if str(actor.get("id", "")) == HEXER and battle.round_number() == 2:
			var rank_three := _hero_at_rank(battle, 3)
			if not rank_three.is_empty():
				battle._units[rank_three]["statuses"]["mark"] = MARK
		var intent := StitchedFoeIntent.choose(battle, actor)
		choices.append({
			"round": battle.round_number(), "foe": str(actor.get("id", "")),
			"ability": str(intent.get("ability_id", "")),
			"target": int(intent.get("target_rank", 0)),
			"pass": bool(intent.get("pass", true)),
		})
		if bool(intent.get("pass", true)):
			receipts.append(battle.pass_turn())
		else:
			receipts.append(battle.use_foe_ability(
				str(intent["ability_id"]), int(intent["target_rank"])))
	return {"choices": choices, "receipts": receipts, "state": battle.state_snapshot(),
		"rng": battle.rng_state(), "order": battle.turn_order()}


func _test_replay() -> void:
	if _witnesses.get("hit", {}).is_empty():
		return
	var seed_value := int(_witnesses["hit"]["seed"])
	var first := _transcript(seed_value)
	var second := _transcript(seed_value)
	_check(not first.is_empty() and not first["receipts"].is_empty(),
		"AC4: the replay fixture executes real public turns and receipts")
	if first.is_empty():
		return
	var override_choice := {}
	for choice in first["choices"]:
		if str(choice.get("foe", "")) == HEXER and int(choice.get("round", 0)) == 2 \
				and str(choice.get("ability", "")) == BOLT and int(choice.get("target", 0)) == 3:
			override_choice = choice
			break
	_check(not override_choice.is_empty(),
		"AC4: the legal transcript really records the new Mark-triggered round-two bolt")
	var bolt_receipts := 0
	for receipt in first["receipts"]:
		if str(receipt.get("actor", "")) == HEXER and str(receipt.get("ability", "")) == BOLT:
			bolt_receipts += 1
	_check(bolt_receipts > 0,
		"AC4: the transcript commits a real Hex Bolt through the public foe action")
	_check(_norm(first["choices"]) == _norm(second["choices"])
		and _norm(first["receipts"]) == _norm(second["receipts"])
		and first["state"] == second["state"] and first["rng"] == second["rng"]
		and first["order"] == second["order"],
		"AC4: the same seed and legal actions replay identical choices, targets, receipts, state and RNG")
