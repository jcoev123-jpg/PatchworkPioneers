extends SceneTree
## S5 Scissor Bailiff: Unpick Verdict hunts an already-torn seam.
##
## The canonical elite's natural lawful third action (round rotation 3, 6, ...) may reach hero
## ranks 1 and 2. Its intent now prefers a partly torn doll (one or two of head/arms/legs torn)
## at the lowest legal rank, then the first legal doll that still owns an untorn limb, and only
## then the ordinary nearest legal attack so the authored 2-3 damage can still land. Every torn
## witness below is a real public `tear_part` preparation on a genuinely seeded battle; the
## LOST, stunned, dead and wrong-launch negatives never fabricate a target. Intent reads are
## proven to leave snapshot, turn order, current turn and RNG untouched, and the projected action
## is then committed through the public `use_foe_ability` so hits, misses and Tear all stay real.

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const BAILIFF := "scissor_bailiff"
const CRAB := "scissor_crab"
const UNPICK := "bailiff_unpick"
const SNIP := {
	"id": "bailiff_snip", "name": "Bailiff Snip", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 86, "dmg": [4, 6], "crit": 0, "effects": {"bleed": 2},
	"self_move": 0, "move": "attack2",
}
const SEIZE := {
	"id": "seize_thread", "name": "Seize Thread", "kind": "debuff",
	"launch": [1, 3], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [0, 0], "crit": 0, "effects": {"snip": 1},
	"self_move": 0, "move": "skill",
}
const UNPICK_RECORD := {
	"id": UNPICK, "name": "Unpick Verdict", "kind": "melee",
	"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
	"acc": 88, "dmg": [2, 3], "crit": 0, "effects": {"tear": 1},
	"self_move": 0, "move": "attack3",
}
const LEGACY := {
	"target": "front", "actions": [
		{"type": "snip_block", "amount": 0, "weight": 2},
		{"type": "debuff", "amount": 2, "status": "bleed", "weight": 2},
		{"type": "attack", "amount": 9, "weight": 2},
		{"type": "attack", "amount": 8, "hits": 2, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
	],
}
const LIMBS := ["head", "arms", "legs"]
const INTENT_KEYS := [
	"foe_id", "foe_name", "ability_id", "ability_name", "ability_kind", "target_rank",
	"target_side", "affected_ranks", "multi", "pass", "stun", "base_acc", "base_damage",
	"base_crit", "base_mark_damage", "base_effects",
]
const SEED_LIMIT := 32

var checks := 0
var failures: Array[String] = []
## False while a bounded seed probe looks for a battle whose authentic turns can witness the
## live hit and miss; probes never record assertions.
var recording := true
var _catalog: Dictionary = {}
var _preview: Dictionary = {}


func _initialize() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ELITES))
	_check(raw is Array, "AC1: the real elite catalog parses as an array")
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_catalog.get("ok", false)),
		"AC1: canonical enemy catalog validates: " + str(_catalog.get("error", "")))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_check(parsed is Dictionary, "the shipped four-doll preview parses")
	if not raw is Array or not bool(_catalog.get("ok", false)) or not parsed is Dictionary:
		_finish()
		return
	_preview = parsed
	_test_source(raw)
	_test_loaded_kit()
	_test_intact_rotation()
	_test_priority()
	_test_negatives()
	_test_live_action()
	_test_live_driver()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_bailiff_open_seam_priority_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, note: String) -> bool:
	if recording:
		checks += 1
		if not ok:
			failures.append(note)
	return ok


func _check(ok: bool, note: String) -> void:
	_expect(ok, note)


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


# ---------------------------------------------------------------- AC1 canonical source

func _test_source(raw: Array) -> void:
	var matches: Array = raw.filter(func(record: Variant) -> bool:
		return record is Dictionary and str(record.get("id", "")) == BAILIFF)
	_check(matches.size() == 1, "AC1: the elite source holds exactly one Scissor Bailiff record")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	_check(record.get("name") == "Scissor Bailiff" and int(record.get("max_hp", 0)) == 36
		and record.get("bleed_on_attack") == true and record.get("chew_block_on_attack") == true
		and record.get("art_path") == "res://assets/paper/enemies/scissor_bailiff.png"
		and record.get("intent") == _json(LEGACY),
		"AC1: name, legacy HP, flags, art and all five legacy actions stay exact")
	var expected := {"max_hp": 36, "speed": 4, "dodge": 5, "acc": 0, "prot": 8, "is_boss": false,
		"turns_per_round": 1, "trophy": "scissor_bailiff_shears",
		"abilities": [SNIP, SEIZE, UNPICK_RECORD]}
	_check(record.get("stitched") == _json(expected),
		"AC1: the exact profile, Snip and Seize Thread, and Unpick Verdict are unchanged")
	# Neighbouring elites still resolve with their own id and trophy; ID presence only.
	var neighbours := 0
	for candidate in raw:
		if not candidate is Dictionary or str(candidate.get("id", "")) == BAILIFF:
			continue
		neighbours += 1
		var foe := StitchedEnemyCatalog.foe_for(_catalog, str(candidate["id"]))
		_check(not foe.is_empty()
			and StitchedEnemyCatalog.trophy_for(_catalog, str(candidate["id"]))
				== str(candidate.get("stitched", {}).get("trophy", "")),
			"AC1: every other elite still resolves with its own trophy: " + str(candidate["id"]))
	_check(neighbours >= 2, "AC1: non-vacuous neighbour coverage beside the Bailiff")


func _test_loaded_kit() -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, BAILIFF)
	_check(not foe.is_empty() and _catalog["enemies"][BAILIFF]["tier"] == "elite"
		and StitchedEnemyCatalog.trophy_for(_catalog, BAILIFF) == "scissor_bailiff_shears",
		"AC1: the canonical elite foe, tier and trophy load")
	if foe.is_empty():
		return
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		var expected := {"max_hp": 36, "speed": 4, "dodge": 5, "acc": 0, "prot": 8,
			"is_boss": false, "turns_per_round": 1}
		_check(foe.get(key) == expected[key], "AC1: loaded Bailiff stat stays exact: " + key)
	var normalized: Array = []
	for ability in [SNIP, SEIZE, UNPICK_RECORD]:
		var validated := StitchedParts.validate_ability(ability)
		_check(bool(validated.get("ok", false)), "AC1: the independent expected ability validates")
		if bool(validated.get("ok", false)):
			normalized.append(validated["ability"])
	_check(foe.get("abilities") == normalized,
		"AC1: the loader exposes the exact normalized legal kit in authored order")
	_check(_ability_ids(foe) == ["bailiff_snip", "seize_thread", UNPICK],
		"AC1: the three authored abilities keep their order")
	var unpick := _ability(foe, UNPICK)
	_check(not unpick.is_empty() and unpick.get("name") == "Unpick Verdict"
		and unpick.get("kind") == "melee" and unpick.get("launch") == [1, 2]
		and unpick.get("target") == [1, 2] and unpick.get("target_side") == "enemy"
		and unpick.get("multi") == false and int(unpick.get("acc", 0)) == 88
		and unpick.get("dmg") == [2, 3] and int(unpick.get("crit", -1)) == 0
		and unpick.get("effects") == {"tear": 1}
		and int(unpick.get("self_move", -1)) == 0 and unpick.get("move") == "attack3"
		and int(unpick.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
		and int(unpick.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2]),
		"AC1: Unpick Verdict keeps launch/target [1,2], ACC 88, 2-3 damage and Tear 1")


# ---------------------------------------------------------------- fixtures

func _battle(seed_value: int, ids: Array = [BAILIFF, CRAB]) -> StitchedRules:
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id))
		if foe.is_empty():
			return null
		foes.append(foe)
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": _preview["heroes"].duplicate(true), "parts": parts, "foes": foes,
	})
	_check(bool(built.get("ok", false)),
		"the real seeded battle builds: " + str(built.get("error", "")))
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size(),
		"four dolls face the %d canonical foes" % ids.size())
	return battle


func _hero_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _torn_limbs(hero: Dictionary) -> Array:
	var torn: Array = []
	for slot in LIMBS:
		var part: Variant = hero.get("parts", {}).get(slot, {})
		if part is Dictionary and bool(part.get("torn", false)):
			torn.append(slot)
	torn.sort()
	return torn


## Passes authentic turns until the Bailiff's live round-3 turn. Earlier Bailiff turns are
## projected too, so the authored rotation stays witnessed. Every projection is proven
## read-only; the returned array holds the round 1, 2 and 3 intents.
func _to_round_three(battle: StitchedRules, receipts: Array) -> Array:
	var intents: Array = []
	for _step in range(160):
		if battle.is_over():
			return []
		if battle.current_actor_id() == BAILIFF:
			if not _expect(int(battle.round_number()) == intents.size() + 1,
					"fixture: the Bailiff takes one real turn in round %d" % (intents.size() + 1)):
				return []
			var state := battle.state_snapshot()
			var rng := battle.rng_state()
			var order := battle.turn_order()
			var current := battle.current_actor_id()
			var round_value := battle.round_number()
			var intent := StitchedFoeIntent.choose(battle, battle.get_unit(BAILIFF))
			_expect(state == battle.state_snapshot() and rng == battle.rng_state()
				and order == battle.turn_order() and current == battle.current_actor_id()
				and round_value == battle.round_number(),
				"the Bailiff projection leaves snapshot, turn order, actor and RNG untouched")
			intents.append(intent)
			if int(battle.round_number()) >= 3:
				return intents
		var passed := battle.pass_turn()
		if not _expect(bool(passed.get("ok", false)),
				"fixture: a lawful pass advances to the next real turn"):
			return []
		receipts.append(passed)
	return []


## Applies one deterministic preparation plan through public rules where possible. Each entry
## names a hero rank, how many public tears to make, and whether to mark it LOST or dead.
func _prepare(battle: StitchedRules, plan: Array, receipts: Array) -> bool:
	for step in plan:
		var hero_id := _hero_at(battle, int(step.get("rank", 0)))
		if hero_id.is_empty():
			return false
		for _tear in range(int(step.get("tears", 0))):
			var torn := battle.tear_part(hero_id)
			if not bool(torn.get("ok", false)) or str(torn.get("hero", "")) != hero_id:
				return false
			receipts.append(torn)
		if bool(step.get("lost", false)):
			battle._units[hero_id]["lost"] = true
		if bool(step.get("dead", false)):
			battle._units[hero_id]["hp"] = 0
			battle._units[hero_id]["dead"] = true
	return true


## Projects the Bailiff's Unpick Verdict and independently witnesses the whole choice shape.
func _assert_unpick(battle: StitchedRules, expected_rank: int, note: String) -> Dictionary:
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var current := battle.current_actor_id()
	var round_value := battle.round_number()
	var actor := battle.get_unit(BAILIFF)
	var choice := StitchedFoeIntent.choose(battle, actor)
	_check(state == battle.state_snapshot() and rng == battle.rng_state()
		and order == battle.turn_order() and current == battle.current_actor_id()
		and round_value == battle.round_number(),
		note + " never mutates the battle, turn or RNG")
	_check(str(choice.get("ability_id", "")) == UNPICK
		and str(choice.get("ability_name", "")) == "Unpick Verdict"
		and str(choice.get("ability_kind", "")) == "melee"
		and int(choice.get("target_rank", 0)) == expected_rank
		and choice.get("affected_ranks") == [expected_rank]
		and str(choice.get("target_side", "")) == "hero"
		and not bool(choice.get("multi", true)) and not bool(choice.get("pass", true)),
		note + " projects Unpick Verdict on rank %d only" % expected_rank)
	_check(choice.get("base_damage") == [2, 3] and int(choice.get("base_acc", -1)) == 88
		and int(choice.get("base_crit", -1)) == 0 and int(choice.get("base_mark_damage", -1)) == 0
		and _json(choice.get("base_effects")) == _json({"tear": 1}),
		note + " exposes authored base numbers only, never a hit or damage forecast")
	var keys: Array = choice.keys()
	var shape := keys.size() == INTENT_KEYS.size()
	for key in keys:
		shape = shape and str(key) in INTENT_KEYS
	_check(shape, note + " adds no output key to the intent dictionary")
	var legal := battle._legal_targets(actor, _ability(actor, UNPICK), expected_rank)
	_check(not legal.is_empty() and str(legal[0].get("id", "")) == _hero_at(battle, expected_rank)
		and str(legal[0].get("side", "")) == "hero",
		note + " chooses a genuinely legal living hero in that rank")
	return choice


func _assert_pass(battle: StitchedRules, note: String) -> void:
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(BAILIFF))
	_check(state == battle.state_snapshot() and rng == battle.rng_state()
		and order == battle.turn_order(),
		note + " never mutates the battle, turn or RNG")
	_check(bool(choice.get("pass", false)) and str(choice.get("ability_id", "")) == ""
		and int(choice.get("target_rank", -1)) == 0
		and choice.get("affected_ranks", [1]).is_empty()
		and not choice.has("base_damage") and not choice.has("base_effects"),
		note + " preserves the original pass with no fabricated target or base numbers")


# ---------------------------------------------------------------- AC1 intact rotation

func _test_intact_rotation() -> void:
	var battle := _battle(3)
	if battle == null:
		return
	var receipts: Array = []
	var intents := _to_round_three(battle, receipts)
	if intents.size() != 3:
		_check(false, "AC1: the intact seeded battle reaches the Bailiff's round-three turn")
		return
	_check(str(intents[0].get("ability_id", "")) == "bailiff_snip"
		and str(intents[1].get("ability_id", "")) == "seize_thread",
		"AC1: rounds one and two keep the original authored action rotation")
	var verdict: Dictionary = intents[2]
	_check(str(verdict.get("ability_id", "")) == UNPICK
		and str(verdict.get("ability_name", "")) == "Unpick Verdict"
		and str(verdict.get("ability_kind", "")) == "melee"
		and not bool(verdict.get("pass", true))
		and int(verdict.get("target_rank", 0)) == 1
		and str(verdict.get("target_side", "")) == "hero"
		and int(verdict.get("base_acc", -1)) == 88
		and verdict.get("base_damage") == [2, 3]
		and _json(verdict.get("base_effects")) == _json({"tear": 1}),
		"AC1: a fully intact round-three turn still announces Unpick Verdict on rank 1")
	for hero in battle.get_heroes():
		_check(_torn_limbs(hero).is_empty() and not bool(hero.get("lost", false)),
			"AC1: the intact fixture really has four fully stitched, living dolls")
	verdict["base_effects"]["tear"] = 9
	_check(_json(StitchedFoeIntent.choose(battle, battle.get_unit(BAILIFF)).get("base_effects"))
		== _json({"tear": 1}),
		"AC1: editing a projection cannot edit the live ability")


# ---------------------------------------------------------------- AC2/AC3 priority cases

func _test_priority() -> void:
	var seed_value := _playing_seed()
	var cases := [
		{"plan": [{"rank": 2, "tears": 1}], "rank": 2,
			"note": "AC2: a partly torn rank 2 outranks an intact rank 1"},
		{"plan": [{"rank": 2, "tears": 2}], "rank": 2,
			"note": "AC2: two torn seams are still a partial doll and outrank an intact rank 1"},
		{"plan": [{"rank": 1, "tears": 1}, {"rank": 2, "tears": 1}], "rank": 1,
			"note": "AC2: two partly torn dolls keep the lower rank 1"},
		{"plan": [{"rank": 1, "tears": 2}, {"rank": 2, "tears": 1}], "rank": 1,
			"note": "AC2: an equally partial lower rank 1 wins"},
		{"plan": [{"rank": 1, "tears": 1}, {"rank": 2, "tears": 3}], "rank": 1,
			"note": "AC2: a partly torn rank 1 beats a fully torn rank 2"},
		{"plan": [{"rank": 1, "tears": 3}], "rank": 2,
			"note": "AC3: a fully torn rank 1 yields the intact tearable rank 2"},
		{"plan": [{"rank": 2, "tears": 3}], "rank": 1,
			"note": "AC3: a fully torn rank 2 keeps the intact rank 1"},
		{"plan": [{"rank": 1, "tears": 3}, {"rank": 2, "tears": 3}], "rank": 1,
			"note": "AC3: with no tearable hero the ordinary first legal attack survives, not a pass"},
		{"plan": [{"rank": 3, "tears": 1}], "rank": 1,
			"note": "AC3: a torn rank 3 is never chosen from a legal rank 1/2 launch"},
	]
	for entry in cases:
		var battle := _battle(seed_value)
		if battle == null:
			continue
		var receipts: Array = []
		var note := str(entry["note"])
		if _to_round_three(battle, receipts).size() != 3:
			_check(false, note + ": reaches the Bailiff's round-three turn")
			continue
		if not _prepare(battle, entry["plan"], receipts):
			_check(false, note + ": lawful tear preparation succeeds")
			continue
		var expected_torn := {}
		for step in entry["plan"]:
			expected_torn[int(step["rank"])] = mini(3, int(step.get("tears", 0)))
		for rank in expected_torn:
			var prepared := battle.get_unit(_hero_at(battle, rank))
			_check(_torn_limbs(prepared).size() == int(expected_torn[rank]),
				note + ": rank %d carries exactly %d torn seams" % [rank, int(expected_torn[rank])])
		if int(entry["rank"]) == 1 and entry["plan"].size() == 2 \
				and int(entry["plan"][0].get("tears", 0)) == 3 \
				and int(entry["plan"][1].get("tears", 0)) == 3:
			_check(_torn_limbs(battle.get_unit(_hero_at(battle, 1))).size() == 3
				and _torn_limbs(battle.get_unit(_hero_at(battle, 2))).size() == 3,
				note + ": neither reachable doll owns an untorn seam")
		_assert_unpick(battle, int(entry["rank"]), note)
		var again := StitchedFoeIntent.choose(battle, battle.get_unit(BAILIFF))
		_check(again == StitchedFoeIntent.choose(battle, battle.get_unit(BAILIFF)),
			note + ": repeated reads project the identical choice")


func _playing_seed() -> int:
	recording = false
	var found := 0
	for seed_value in range(1, 17):
		var battle := _battle(seed_value)
		if battle == null:
			continue
		if _to_round_three(battle, []).size() == 3:
			found = seed_value
			break
	recording = true
	return found if found > 0 else 3


# ---------------------------------------------------------------- AC3 negatives

func _test_negatives() -> void:
	var seed_value := _playing_seed()
	# A LOST rank 1 is never a candidate even when the rank 2 seam is partly torn.
	var lost_front := _battle(seed_value)
	if lost_front != null:
		var receipts: Array = []
		if _to_round_three(lost_front, receipts).size() == 3 \
				and _prepare(lost_front, [{"rank": 1, "lost": true},
					{"rank": 2, "tears": 1}], receipts):
			_check(bool(lost_front.get_unit(_hero_at(lost_front, 1)).get("lost", false)),
				"AC3: the rank-1 doll is genuinely LOST in the fixture")
			_assert_unpick(lost_front, 2,
				"AC3: a LOST rank 1 never hides the partly torn rank 2")
	# A LOST rank 2 is never selected even with a partly torn seam of its own.
	var lost_partial := _battle(seed_value)
	if lost_partial != null:
		var receipts: Array = []
		if _to_round_three(lost_partial, receipts).size() == 3 \
				and _prepare(lost_partial, [{"rank": 2, "tears": 1},
					{"rank": 2, "lost": true}], receipts):
			_assert_unpick(lost_partial, 1,
				"AC3: a LOST partly torn rank 2 is skipped for the intact rank 1")
	# A dead rank 2 seam is never unpicked; the intact rank 1 keeps the ordinary choice.
	var dead_partial := _battle(seed_value)
	if dead_partial != null:
		var receipts: Array = []
		if _to_round_three(dead_partial, receipts).size() == 3 \
				and _prepare(dead_partial, [{"rank": 2, "tears": 1},
					{"rank": 2, "dead": true}], receipts):
			_check(not dead_partial.is_over(),
				"AC3: the dead-doll fixture leaves the real battle running")
			_assert_unpick(dead_partial, 1,
				"AC3: a dead partly torn rank 2 is skipped for the living intact rank 1")
	# No legal rank 1/2 doll at all keeps the original pass; ranks 3 and 4 are unreachable.
	var sealed := _battle(seed_value)
	if sealed != null:
		var receipts: Array = []
		if _to_round_three(sealed, receipts).size() == 3 \
				and _prepare(sealed, [{"rank": 1, "lost": true},
					{"rank": 2, "lost": true}], receipts):
			_check(not sealed.is_over() and _hero_at(sealed, 3) != "",
				"AC3: two LOST dolls leave living rank 3/4 dolls behind a real running battle")
			_assert_pass(sealed,
				"AC3: no legal target in Unpick's reach preserves the original pass")
	# The projected action itself cannot reach a rank 3/4 doll.
	if sealed != null:
		var before := sealed.state_snapshot()
		var rng := sealed.rng_state()
		for rank in [3, 4]:
			var rejected := sealed.use_foe_ability(UNPICK, rank)
			_check(not bool(rejected.get("ok", true))
				and rejected.get("error") == "no legal target in rank %d" % rank
				and before == sealed.state_snapshot() and rng == sealed.rng_state(),
				"AC3: direct Unpick on rank %d is refused without state/RNG/turn spend" % rank)
	# Wrong launch: an authentic rank-3 Bailiff can never announce Unpick.
	var wrong_launch := _battle(71, [CRAB, "moth_scribe", BAILIFF])
	if wrong_launch != null:
		var receipts: Array = []
		if _to_round_three(wrong_launch, receipts).size() == 3:
			var actor := wrong_launch.get_unit(BAILIFF)
			_check(int(actor.get("rank", 0)) == 3
				and not StitchedParts.ranks_allowed(
					int(_ability(actor, UNPICK)["launch_mask"]), 3),
				"AC3: the authentic Bailiff stands outside Unpick's launch ranks")
			var prepared := _prepare(wrong_launch, [{"rank": 2, "tears": 1}], receipts)
			var state := wrong_launch.state_snapshot()
			var rng := wrong_launch.rng_state()
			var choice := StitchedFoeIntent.choose(wrong_launch, actor)
			_check(prepared and state == wrong_launch.state_snapshot()
				and rng == wrong_launch.rng_state()
				and str(choice.get("ability_id", "")) != UNPICK
				and str(choice.get("ability_id", "")) == "seize_thread"
				and int(choice.get("target_rank", 0)) == 1,
				"AC3: a torn seam never forces an illegal Unpick; the rotation keeps Seize Thread")
			var rejected := wrong_launch.use_foe_ability(UNPICK, 1)
			_check(not bool(rejected.get("ok", true))
				and rejected.get("error") == "ability cannot launch from rank 3"
				and state == wrong_launch.state_snapshot() and rng == wrong_launch.rng_state(),
				"AC3: the invalid launch is refused without state, RNG or turn spend")
	# A stunned Bailiff reports STUN and never fabricates a seam target.
	var stunned := _battle(seed_value)
	if stunned != null:
		var receipts: Array = []
		if _to_round_three(stunned, receipts).size() == 3 \
				and _prepare(stunned, [{"rank": 2, "tears": 1}], receipts):
			stunned._units[BAILIFF]["statuses"]["stun"] = 1
			var state := stunned.state_snapshot()
			var rng := stunned.rng_state()
			var choice := StitchedFoeIntent.choose(stunned, stunned.get_unit(BAILIFF))
			_check(bool(choice.get("stun", false)) and str(choice.get("ability_id", "")) == ""
				and int(choice.get("target_rank", -1)) == 0
				and not choice.has("base_damage") and not choice.has("base_effects")
				and state == stunned.state_snapshot() and rng == stunned.rng_state(),
				"AC3: a stunned Bailiff reports STUN with no target and no state/RNG spend")
	# Detached, empty and cross-side requests keep the original fail-closed behavior.
	var wrong_actor := _battle(seed_value)
	if wrong_actor != null:
		var receipts: Array = []
		if _to_round_three(wrong_actor, receipts).size() == 3 \
				and _prepare(wrong_actor, [{"rank": 1, "tears": 1}], receipts):
			var state := wrong_actor.state_snapshot()
			var rng := wrong_actor.rng_state()
			_check(StitchedFoeIntent.choose(wrong_actor, {}).is_empty()
				and StitchedFoeIntent.choose(wrong_actor,
					wrong_actor.get_unit(_hero_at(wrong_actor, 1))).is_empty()
				and state == wrong_actor.state_snapshot() and rng == wrong_actor.rng_state(),
				"AC3: empty and wrong-side actors project nothing and change nothing")
			var crab := StitchedFoeIntent.choose(wrong_actor,
				wrong_actor.get_unit(CRAB))
			_check(str(crab.get("ability_id", "")) == "pinch"
				and int(crab.get("target_rank", 0)) == 1
				and str(crab.get("foe_id", "")) == CRAB,
				"AC3: another foe keeps its own ordinary nearest-rank policy beside the Bailiff")
			_check(state == wrong_actor.state_snapshot() and rng == wrong_actor.rng_state(),
				"AC3: the other foe's projection also leaves state and RNG untouched")


# ---------------------------------------------------------------- AC4 live hit/miss/Tear

func _test_live_action() -> void:
	recording = true
	var witnesses := {"hit": 0, "miss": 0, "tear": 0, "refused_tear": 0,
		"partial_rank2": 0, "sealed_rank1": 0}
	var replay_checked := 0
	for seed_value in range(1, SEED_LIMIT + 1):
		for sealed in [false, true]:
			var first := _live_script(seed_value, bool(sealed), witnesses)
			if first.is_empty():
				continue
			recording = false
			var replay := _live_script(seed_value, bool(sealed), {})
			recording = true
			_check(not replay.is_empty() and first == replay,
				"AC4: seed %d %s replays receipts, snapshots, turn order and RNG exactly"
					% [seed_value, "sealed" if bool(sealed) else "partial"])
			replay_checked += 1
	for key in witnesses:
		_check(witnesses[key] > 0, "AC4: non-vacuous seeded witness: " + str(key))
	_check(replay_checked >= 4,
		"AC4: several independent seeded actions replay identically")


func _test_live_driver() -> void:
	var seed_value := _playing_seed()
	var config := _screen_config(seed_value)
	_check(not config.is_empty(), "live driver: the canonical Bailiff fight config builds")
	if config.is_empty():
		return
	var stage := StitchedBattleScreen.new()
	var started := stage.begin(config)
	_check(started and stage.battle != null,
		"live driver: the real mounted battle screen accepts the Bailiff fight")
	if stage.battle == null:
		stage.free()
		return
	var setup_receipts: Array = []
	if _to_round_three(stage.battle, setup_receipts).size() != 3:
		_check(false, "live driver: the mounted fight reaches the Bailiff's round-three turn")
		stage.free()
		return
	var rank_two := _hero_at(stage.battle, 2)
	var torn := stage.battle.tear_part(rank_two)
	_check(bool(torn.get("ok", false)) and str(torn.get("hero", "")) == rank_two,
		"live driver: public preparation really tears the rank-2 seam")
	var before := stage.receipts.size()
	stage._drive_foes()
	var committed: Dictionary = {}
	for index in range(before, stage.receipts.size()):
		var item: Dictionary = stage.receipts[index]
		if str(item.get("actor", "")) == BAILIFF:
			committed = item
			break
	_check(str(committed.get("ability", "")) == UNPICK
		and committed.get("results", []).size() == 1
		and int(committed["results"][0].get("target_rank", 0)) == 2
		and str(committed["results"][0].get("target", "")) == rank_two,
		"live driver: the wired foe driver commits Unpick Verdict on the partly torn rank 2")
	stage.free()


func _screen_config(seed_value: int, ids: Array = [BAILIFF, CRAB]) -> Dictionary:
	var parts: Array = _preview["parts"].duplicate(true)
	parts.append_array(_catalog["parts"].duplicate(true))
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id))
		if foe.is_empty():
			return {}
		foes.append(foe)
	return {"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": _preview["heroes"].duplicate(true), "parts": parts, "foes": foes}


## One complete seeded script on a fresh canonical battle: lawful turns to the Bailiff's
## round-three turn, a real public tear preparation, the read-only projection, then the real
## public Unpick Verdict. Returns {} when a precondition is missing so the bounded probe can
## try the next seed.
func _live_script(seed_value: int, sealed: bool, witnesses: Dictionary) -> Dictionary:
	var battle := _battle(seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	var intents := _to_round_three(battle, receipts)
	if intents.size() != 3:
		return {}
	if str(intents[0].get("ability_id", "")) != "bailiff_snip" \
			or str(intents[1].get("ability_id", "")) != "seize_thread":
		return {}
	var target_rank := 1 if sealed else 2
	if sealed:
		for rank in [1, 2]:
			var hero_id := _hero_at(battle, rank)
			for _tear in range(3):
				var torn := battle.tear_part(hero_id)
				if not bool(torn.get("ok", false)):
					return {}
				receipts.append(torn)
	else:
		var hero_id := _hero_at(battle, 2)
		var torn := battle.tear_part(hero_id)
		if not bool(torn.get("ok", false)):
			return {}
		receipts.append(torn)
	var target_id := _hero_at(battle, target_rank)
	if target_id.is_empty():
		return {}
	var target_before := battle.get_unit(target_id)
	var actor := battle.get_unit(BAILIFF)
	if int(target_before.get("hp", 0)) <= 0:
		return {}
	if sealed:
		_expect(_torn_limbs(target_before).size() == 3,
			"AC4: the sealed rank %d doll is fully torn before the verdict" % target_rank)
	else:
		_expect(_torn_limbs(target_before).size() == 1,
			"AC4: the partial rank 2 doll carries exactly one torn seam")
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var order := battle.turn_order()
	var current := battle.current_actor_id()
	var intent := StitchedFoeIntent.choose(battle, actor)
	if not _expect(state == battle.state_snapshot() and rng == battle.rng_state()
			and order == battle.turn_order() and current == battle.current_actor_id(),
			"AC4: the projection itself never changes state, turn order, actor or RNG"):
		return {}
	if not _expect(str(intent.get("ability_id", "")) == UNPICK
			and int(intent.get("target_rank", 0)) == target_rank
			and intent.get("affected_ranks") == [target_rank]
			and not bool(intent.get("pass", true)),
			"AC4: the lawful projection selects the prepared rank %d" % target_rank):
		return {}
	if not _expect(battle.get_unit(target_id)["hp"] == target_before["hp"]
			and battle.get_unit(target_id)["parts"] == target_before["parts"],
			"AC4: the projection itself deals no damage and tears nothing"):
		return {}
	var others_before := {}
	for hero in battle.get_heroes():
		if str(hero["id"]) == target_id:
			continue
		others_before[str(hero["id"])] = {"hp": int(hero["hp"]),
			"parts": hero["parts"].duplicate(true)}
	var receipt := battle.use_foe_ability(UNPICK, int(intent["target_rank"]))
	receipts.append(receipt)
	if not _expect(bool(receipt.get("ok", false)) and str(receipt.get("actor", "")) == BAILIFF
			and str(receipt.get("ability", "")) == UNPICK
			and receipt.get("results", []).size() == 1,
			"AC4: the projected Unpick Verdict commits one real target receipt"):
		return {}
	var hit: Dictionary = receipt["results"][0]
	var acc := 88 + int(actor["acc"]) + int(battle.candle_band()["enemy_acc"])
	if not _expect(str(hit.get("target", "")) == target_id
			and int(hit.get("target_rank", 0)) == target_rank
			and int(hit.get("hit_chance", -1)) == StitchedRules.hit_chance(
				acc, StitchedRules.effective_dodge(target_before), actor["miss_streak"])
			and bool(hit.get("hit", false)) == (int(hit.get("roll", -1)) <= int(hit["hit_chance"])),
			"AC4: the real authored ACC 88 roll lands on the selected doll"):
		return {}
	var after := battle.get_unit(target_id)
	if bool(hit.get("hit", false)):
		var bases: Array = [StitchedRules.crit_damage(3)] if bool(hit.get("crit", false)) else [2, 3]
		var damages: Array = []
		for base in bases:
			var dealt := StitchedS1BEffects.enemy_damage(base + int(actor.get("dmg_bonus", 0)),
				battle.candle())
			damages.append(StitchedRules.damage_after_modifiers(dealt, actor["statuses"],
				target_before["statuses"], false, 0, target_before["prot"]))
		_expect(damages.has(int(hit.get("damage", -1)))
			and int(after["hp"]) == int(target_before["hp"]) - int(hit["damage"])
			and int(hit.get("target_hp", -1)) == int(after["hp"]),
			"AC4: a real hit deals the authored 2-3 damage after PROT, crit and candle")
		_expect(hit.has("enemy_crit_fray") == bool(hit.get("crit", false)),
			"AC4: only a critical Unpick adds elite critical fray")
		var tear: Dictionary = hit.get("tear", {})
		if sealed:
			_expect(tear == {"ok": false, "action": "tear", "actor": target_id,
					"error": "no untorn non-torso part"}
				and _torn_limbs(after) == _torn_limbs(target_before)
				and not bool(after["parts"]["torso"]["torn"]),
				"AC4: a fully unpicked doll returns the contained refusal and keeps its torso")
			if not witnesses.is_empty():
				witnesses["refused_tear"] += 1
		else:
			var torn_after := _torn_limbs(after)
			var new_slots: Array = torn_after.duplicate()
			for slot in _torn_limbs(target_before):
				new_slots.erase(slot)
			_expect(bool(tear.get("ok", false)) and new_slots.size() == 1
				and LIMBS.has(new_slots[0]) and str(tear.get("slot", "")) == str(new_slots[0])
				and tear == {"ok": true, "action": "tear", "hero": target_id,
					"slot": tear.get("slot"),
					"part": str(target_before["parts"][new_slots[0]]["id"])}
				and not bool(after["parts"]["torso"]["torn"]),
				"AC4: a real hit tears exactly one further non-torso seam with a receipt")
			if bool(tear.get("ok", false)):
				if not witnesses.is_empty():
					witnesses["tear"] += 1
		if not witnesses.is_empty():
			witnesses["hit"] += 1
			if sealed:
				witnesses["sealed_rank1"] += 1
			else:
				witnesses["partial_rank2"] += 1
	else:
		_expect(int(hit.get("damage", -1)) == 0 and not bool(hit.get("crit", true))
			and not hit.has("tear") and int(hit.get("target_hp", -1)) == int(target_before["hp"])
			and after["parts"] == target_before["parts"],
			"AC4: a natural seeded miss deals no damage and tears nothing")
		if not witnesses.is_empty():
			witnesses["miss"] += 1
	for hero in battle.get_heroes():
		if str(hero["id"]) == target_id:
			continue
		var original: Dictionary = others_before.get(str(hero["id"]), {})
		_expect(not original.is_empty() and int(hero["hp"]) == int(original["hp"])
			and hero["parts"] == original["parts"],
			"AC4: uninvolved doll " + str(hero["id"]) + " keeps HP and seams unchanged")
	_expect(not bool(after.get("lost", false)) and not bool(hit.get("lost", false)),
		"AC4: one Unpick never makes the target LOST")
	_expect(battle.satchel().is_empty(), "AC4: a tear alone never fills the satchel")
	return {"receipts": receipts.duplicate(true), "intents": intents.duplicate(true),
		"order": battle.turn_order(), "state": battle.state_snapshot(),
		"rng": battle.rng_state(), "target": battle.get_unit(target_id),
		"actor": battle.get_unit(BAILIFF), "round": battle.round_number()}
