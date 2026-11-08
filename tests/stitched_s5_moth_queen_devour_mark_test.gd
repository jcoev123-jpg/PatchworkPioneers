extends SceneTree
## Moth Queen marked-prey Devour priority (S5 enemy rule depth, Design v4 Stitched).
##
## After her own Pin Crown Dive sews a Mark, the real Queen seizes the legal Marked doll with
## her authored Devour even when the ordinary round rotation would raise Queen Dust or Moth
## Veil. Everything here runs on the canonical enemy catalog, the shipped four-doll preview and
## the public seeded StitchedRules actions; no damage, RNG or resolver is forced.

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
const REAR_QUEEN := ["scissor_crab", "moth_scribe", "moth_queen"]
const SECOND_RANK_QUEEN := ["scissor_crab", "moth_queen"]

var failures: Array[String] = []
var checks := 0
## False while a bounded seed probe looks for an authentic witness; those probes air no checks.
var recording := true
var catalog: Dictionary = {}
var preview: Dictionary = {}
## The first seed whose real Dive both lands and leaves a later round-one Queen turn with an
## active Mark and a clean Devour witness.
var witness_seed := 0


func _initialize() -> void:
	catalog = StitchedEnemyCatalog.load_catalog()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_expect(bool(catalog.get("ok", false)) and parsed is Dictionary,
		"the real enemy/part catalog and four-doll preview both load")
	if bool(catalog.get("ok", false)) and parsed is Dictionary:
		preview = parsed
		_test_source()
		witness_seed = _find_devour_witness()
		_expect(witness_seed > 0,
			"AC2: a bounded real seed witnesses Dive, its Mark and a later clean Devour hit")
		if witness_seed > 0:
			_test_dive_then_devour()
			_test_live_driver()
		_test_priority(witness_seed)
		_test_dive_offset_priority(witness_seed)
		_test_emergency_still_first(witness_seed)
		_test_rank_two_launch(witness_seed)
		_test_invalid_launch(witness_seed)
		_test_other_foes_and_refusals(witness_seed)
	if failures.is_empty():
		print("stitched_s5_moth_queen_devour_mark_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s5_moth_queen_devour_mark_test: FAIL (", failures.size(), " failures)")
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


# ---------------------------------------------------------------- AC1 authored contract

func _test_source() -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSSES))
	_expect(records is Array, "AC1: the canonical boss source parses as an array")
	if not records is Array:
		return
	var matches: Array = records.filter(func(record: Dictionary) -> bool:
		return record.get("id") == "moth_queen")
	_expect(matches.size() == 1, "AC1: exactly one Moth Queen record remains authored")
	if matches.size() != 1:
		return
	var queen: Dictionary = matches[0]
	_expect(queen.get("name") == "Moth Queen" and int(queen.get("max_hp", 0)) == 90
		and queen.get("art_path") == "res://assets/paper/enemies/moth_queen.png"
		and queen.get("intent") == _json(LEGACY),
		"AC1: the Queen keeps her name, legacy HP, art and all five legacy actions")
	var expected := {"max_hp": 90, "speed": 6, "dodge": 10, "acc": 0, "prot": 4,
		"is_boss": true, "turns_per_round": 2, "trophy": "moth_queen_wing_crown",
		"abilities": [DUST, DIVE, DEVOUR, VEIL]}
	_expect(queen.get("stitched") == _json(expected),
		"AC1: the exact canonical Stitched profile is untouched, including the four authored moves")
	var foe := StitchedEnemyCatalog.foe_for(catalog, "moth_queen")
	_expect(not foe.is_empty() and StitchedEnemyCatalog.trophy_for(catalog, "moth_queen")
		== "moth_queen_wing_crown",
		"AC1: the canonical Queen foe and her wing-crown trophy load")
	if foe.is_empty():
		return
	for key in ["max_hp", "speed", "dodge", "acc", "prot", "is_boss", "turns_per_round"]:
		_expect(foe.get(key) == expected[key], "AC1: the loaded Queen stat stays exact: " + key)
	var normalized: Array = []
	for ability in [DUST, DIVE, DEVOUR, VEIL]:
		var validated := StitchedParts.validate_ability(ability)
		_expect(validated.get("ok", false),
			"AC1: the independent canonical ability validates: " + str(ability["id"]))
		if validated.get("ok", false):
			normalized.append(validated["ability"])
	_expect(foe.get("abilities") == normalized,
		"AC1: the loader exposes the exact normalized legal kit in authored order")
	var dive := _ability(foe, "queen_dive")
	_expect(not dive.is_empty() and dive.get("effects") == {"tangled": 2, "snip": 1, "mark": 3}
		and dive.get("launch") == [1, 3] and dive.get("target") == [1, 2],
		"AC1: Pin Crown Dive still carries the authored Mark 3 beside Tangled 2 and Snip 1")
	var devour := _ability(foe, "queen_devour")
	_expect(not devour.is_empty() and str(devour.get("name", "")) == "Devour"
		and str(devour.get("kind", "")) == "melee" and str(devour.get("target_side", "")) == "enemy"
		and devour.get("launch") == [1, 2] and devour.get("target") == [1, 2]
		and devour.get("multi") == false and int(devour.get("acc", 0)) == 85
		and devour.get("dmg") == [7, 9] and int(devour.get("crit", -1)) == 0
		and int(devour.get("mark_damage", 0)) == 3 and devour.get("effects") == {"bleed": 2}
		and int(devour.get("self_move", -1)) == 0 and str(devour.get("move", "")) == "attack4",
		"AC1: Devour keeps launch/target ranks 1-2, ACC 85, 7-9, Mark bonus 3 and Bleed 2")
	if not devour.is_empty():
		_expect(int(devour.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and int(devour.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and StitchedParts.ranks_allowed(int(devour["launch_mask"]), 1)
			and StitchedParts.ranks_allowed(int(devour["launch_mask"]), 2)
			and not StitchedParts.ranks_allowed(int(devour["launch_mask"]), 3)
			and not StitchedParts.ranks_allowed(int(devour["launch_mask"]), 4),
			"AC1: the real Devour masks allow ranks 1-2 only, so a rear Queen can never launch it")


# ---------------------------------------------------------------- fixtures

func _config(seed_value: int, ids: Array) -> Dictionary:
	var foes: Array = []
	for enemy_id in ids:
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id))
		_expect(not foe.is_empty(), "a real canonical foe loads: " + str(enemy_id))
		foes.append(foe)
	var parts: Array = preview["parts"].duplicate(true)
	parts.append_array(catalog["parts"].duplicate(true))
	return {"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": preview["heroes"].duplicate(true), "parts": parts, "foes": foes}


func _battle(seed_value: int, ids: Array = PAIR) -> StitchedRules:
	var created := StitchedRules.create(_config(seed_value, ids))
	_expect(created.get("ok", false),
		"the real seeded battle builds: " + str(created.get("error")))
	if not created.get("ok", false):
		return null
	var battle: StitchedRules = created["battle"]
	_expect(battle.get_heroes().size() == 4 and battle.get_foes().size() == ids.size(),
		"four dolls face the authored foes")
	return battle


## Passes authentic public turns until the Queen owns a turn (optionally in a wanted round).
func _to_queen(battle: StitchedRules, wanted_round: int = 0) -> bool:
	for step in range(240):
		if battle.is_over():
			return false
		if battle.current_actor_id() == "moth_queen" \
				and (wanted_round == 0 or battle.round_number() == wanted_round):
			return true
		if wanted_round > 0 and battle.round_number() > wanted_round:
			return false
		if not _expect(battle.pass_turn().get("ok", false), "a legal pass advances the real turn"):
			return false
	return false


func _hero_at(battle: StitchedRules, rank: int) -> String:
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
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor.get("rank", 0))):
			continue
		if not battle._self_move_gate(actor, ability).is_empty():
			continue
		for rank in range(1, 5):
			if not battle._legal_targets(actor, ability, rank).is_empty():
				return str(ability.get("id", ""))
	return ""


func _single_result(receipt: Dictionary) -> Dictionary:
	var results: Array = receipt.get("results", [])
	return results[0] if results.size() == 1 else {}


func _restore(battle: StitchedRules, baseline: Dictionary) -> void:
	for unit_id in baseline:
		battle._units[unit_id] = baseline[unit_id].duplicate(true)


func _baseline(battle: StitchedRules) -> Dictionary:
	var saved: Dictionary = {}
	for hero in battle.get_heroes():
		saved[str(hero["id"])] = hero.duplicate(true)
	for foe in battle.get_foes():
		saved[str(foe["id"])] = foe.duplicate(true)
	return saved


# ---------------------------------------------------------------- chooser priority cases

## One read-only chooser case on a real Queen turn. `setup` mutates the authoritative unit
## records the way genuine prior damage, status ticks or movement would, then the chooser must
## name `expected` at `expected_rank` while the ordinary rotation is `rotation`.
func _case(battle: StitchedRules, baseline: Dictionary, setup: Callable,
		expected: String, expected_rank: int, rotation: String, note: String) -> void:
	_restore(battle, baseline)
	setup.call()
	var queen := battle.get_unit("moth_queen")
	_expect(_rotation(battle, queen) == rotation,
		note + ": the fixture's ordinary rotation is " + rotation)
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var first := StitchedFoeIntent.choose(battle, queen)
	var second := StitchedFoeIntent.choose(battle, queen)
	_expect(first == second and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
		note + ": two identical projections spend no battle state or RNG")
	_expect(not first.is_empty() and str(first.get("ability_id", "")) == expected
		and not bool(first.get("pass", true)),
		note + ": the chooser selects " + expected)
	if expected_rank > 0:
		_expect(int(first.get("target_rank", 0)) == expected_rank,
			note + ": the chosen target rank is %d" % expected_rank)
		if expected == "moth_veil":
			var occupied: Array = []
			for foe in battle.get_foes():
				if not bool(foe.get("dead", false)) and not bool(foe.get("lost", false)) \
						and int(foe.get("hp", 0)) > 0:
					occupied.append(int(foe.get("rank", 0)))
			occupied.sort()
			_expect(first.get("affected_ranks") == occupied,
				note + ": the veil still covers every living foe rank")
		else:
			_expect(first.get("affected_ranks") == [expected_rank],
				note + ": the chosen legal rank is %d" % expected_rank)
	if expected == "queen_devour":
		_expect(str(first.get("ability_name", "")) == "Devour"
			and str(first.get("ability_kind", "")) == "melee"
			and str(first.get("target_side", "")) == "hero"
			and not bool(first.get("multi", true))
			and int(first.get("base_acc", 0)) == 85
			and first.get("base_damage") == [7, 9]
			and int(first.get("base_mark_damage", 0)) == 3
			and int(first.get("base_crit", -1)) == 0
			and first.get("base_effects") == {"bleed": 2},
			note + ": projects canonical Devour ACC 85, 7-9, Mark bonus 3 and Bleed 2")
	elif expected == "moth_veil":
		_expect(str(first.get("ability_kind", "")) == "buff"
			and str(first.get("target_side", "")) == "foe"
			and bool(first.get("multi", false))
			and int(first.get("base_acc", 0)) == 100
			and first.get("base_damage") == [0, 0]
			and first.get("base_effects") == {"dodge": 8, "duration": 1},
			note + ": the fail-closed fallback stays the canonical Moth Veil")
	elif expected == "queen_dust":
		_expect(int(first.get("base_acc", 0)) == 85 and first.get("base_damage") == [3, 5]
			and first.get("base_effects") == {"weak": 1, "blind": 1},
			note + ": the fail-closed fallback stays canonical Queen Dust")


func _test_priority(seed_value: int) -> void:
	if seed_value <= 0:
		return
	var battle := _battle(seed_value, PAIR)
	if battle == null:
		return
	if not _to_queen(battle, 4):
		_expect(false, "AC1: the bounded witness seed reaches a real round-four Queen turn")
		return
	var queen := battle.get_unit("moth_queen")
	_expect(int(queen.get("rank", 0)) == 1 and battle.round_number() == 4
		and _rotation(battle, queen) == "moth_veil",
		"AC1: the real rank-one Queen's ordinary round-four rotation is Moth Veil")
	var baseline := _baseline(battle)
	var rank_one := _hero_at(battle, 1)
	var rank_two := _hero_at(battle, 2)
	_expect(not rank_one.is_empty() and not rank_two.is_empty(),
		"AC1: the fixture carries distinct living dolls in ranks one and two")
	if rank_one.is_empty() or rank_two.is_empty():
		return
	# An active Mark on the second rank beats both the nearer unmarked front doll and the veil.
	_case(battle, baseline, func() -> void:
		battle._units[rank_two]["statuses"]["mark"] = 3, "queen_devour", 2, "moth_veil",
		"AC1: a round-four active Mark overrides the ordinary Moth Veil rotation")
	# Two active Marks keep the nearest legal front rank, never the deeper one.
	_case(battle, baseline, func() -> void:
		battle._units[rank_one]["statuses"]["mark"] = 3
		battle._units[rank_two]["statuses"]["mark"] = 3, "queen_devour", 1, "moth_veil",
		"AC1: equal legal Marks keep the nearest front rank, not merely the first occupied one")
	# No Mark anywhere restores the exact ordinary rotation.
	_case(battle, baseline, func() -> void: pass, "moth_veil", -1, "moth_veil",
		"AC3: no current Mark leaves the ordinary Moth Veil rotation untouched")
	# An expired/zero Mark is not a Mark.
	_case(battle, baseline, func() -> void:
		battle._units[rank_two]["statuses"]["mark"] = 0, "moth_veil", -1, "moth_veil",
		"AC3: an expired Mark invents no Devour")
	# A Mark beyond Devour's authored rank-two reach can never be seized.
	var rank_three := _hero_at(battle, 3)
	if not rank_three.is_empty():
		_case(battle, baseline, func() -> void:
			battle._units[rank_three]["statuses"]["mark"] = 3, "moth_veil", -1, "moth_veil",
			"AC3: a Marked rank-three doll is out of Devour's reach and is never chosen")
	# A Marked but zero-HP hanging doll is not living prey.
	_case(battle, baseline, func() -> void:
		battle._units[rank_two]["statuses"]["mark"] = 3
		battle._units[rank_two]["hp"] = 0
		battle._units[rank_two]["hanging"] = true, "moth_veil", -1, "moth_veil",
		"AC3: a Marked but non-living zero-HP doll is excluded")
	# A Marked but LOST doll has left the fight.
	_case(battle, baseline, func() -> void:
		battle._units[rank_two]["statuses"]["mark"] = 3
		battle._units[rank_two]["lost"] = true
		battle._units[rank_two]["hp"] = 0, "moth_veil", -1, "moth_veil",
		"AC3: a Marked but LOST doll is excluded")
	_restore(battle, baseline)
	var restored := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	_expect(str(restored.get("ability_id", "")) == "moth_veil"
		and str(restored.get("ability_id", "")) != "queen_devour",
		"AC3: restoring the authoritative ranks restores the ordinary veil fallback")


## A second real offset: the Queen's round-two rotation would be Pin Crown Dive, yet an active
## Mark still turns the read-only choice into Devour.
func _test_dive_offset_priority(seed_value: int) -> void:
	if seed_value <= 0:
		return
	var battle := _battle(seed_value, PAIR)
	if battle == null:
		return
	if not _to_queen(battle, 2):
		_expect(false, "AC1: the bounded witness seed reaches a real round-two Queen turn")
		return
	var queen := battle.get_unit("moth_queen")
	_expect(int(queen.get("rank", 0)) == 1 and _rotation(battle, queen) == "queen_dive",
		"AC1: the rank-one Queen's ordinary round-two rotation is Pin Crown Dive")
	var baseline := _baseline(battle)
	var rank_one := _hero_at(battle, 1)
	if rank_one.is_empty():
		return
	_case(battle, baseline, func() -> void:
		battle._units[rank_one]["statuses"]["mark"] = 3, "queen_devour", 1, "queen_dive",
		"AC1: an active Mark overrides the Dive rotation with the authored Devour")
	_restore(battle, baseline)


# ---------------------------------------------------------------- AC3 emergency veil still first

func _test_emergency_still_first(seed_value: int) -> void:
	if seed_value <= 0:
		return
	var battle := _battle(seed_value, PAIR)
	if battle == null:
		return
	if not _to_queen(battle, 4):
		_expect(false, "AC3: the bounded witness seed reaches the emergency-check Queen turn")
		return
	var queen := battle.get_unit("moth_queen")
	_expect(int(queen.get("rank", 0)) == 1 and _rotation(battle, queen) == "moth_veil",
		"AC3: the emergency fixture starts from the real round-four Veil rotation")
	var baseline := _baseline(battle)
	var rank_two := _hero_at(battle, 2)
	var escort := battle.get_unit("scissor_crab")
	_expect(not rank_two.is_empty() and not escort.is_empty(),
		"AC3: the fixture carries a real Marked doll and a living escort")
	if rank_two.is_empty() or escort.is_empty():
		return
	var half := int(escort.get("max_hp", 0)) / 2
	_expect(half > 0, "AC3: the escort has a real maximum HP to wound to half")
	_case(battle, baseline, func() -> void:
		battle._units[rank_two]["statuses"]["mark"] = 3
		battle._units["scissor_crab"]["hp"] = half
		battle._units["scissor_crab"]["dodge_buff"] = {},
		"moth_veil", 1, "moth_veil",
		"AC3: a critically wounded un-veiled escort still outranks Devour")
	# Same wound, now temporarily Dodge-protected: the emergency is off and Devour seizes the Mark.
	_case(battle, baseline, func() -> void:
		battle._units[rank_two]["statuses"]["mark"] = 3
		battle._units["scissor_crab"]["hp"] = half
		battle._units["scissor_crab"]["dodge_buff"] = {"amount": 8, "turns": 1, "skip": false},
		"queen_devour", 2, "moth_veil",
		"AC3: a currently temporary-Dodge-protected escort no longer forces Veil")
	_restore(battle, baseline)


# ---------------------------------------------------------------- rank-two launch

func _test_rank_two_launch(seed_value: int) -> void:
	if seed_value <= 0:
		return
	var battle := _battle(seed_value, SECOND_RANK_QUEEN)
	if battle == null:
		return
	if not _to_queen(battle, 4):
		_expect(false, "AC1: the rank-two Queen reaches her real round-four turn")
		return
	var queen := battle.get_unit("moth_queen")
	_expect(int(queen.get("rank", 0)) == 2 and _rotation(battle, queen) == "queen_devour",
		"AC1: a rank-two Queen can only launch her authored Devour among the active moves")
	var baseline := _baseline(battle)
	var rank_one := _hero_at(battle, 1)
	if rank_one.is_empty():
		return
	_case(battle, baseline, func() -> void:
		battle._units[rank_one]["statuses"]["mark"] = 3, "queen_devour", 1, "queen_devour",
		"AC1: a legal rank-two Devour launch still selects the marked legal front rank")
	_restore(battle, baseline)
	var legal := battle.use_foe_ability("queen_devour", 1)
	_expect(bool(legal.get("ok", false)) and legal.get("ability") == "queen_devour"
		and legal.get("results", []).size() == 1,
		"AC1: the real rank-two Devour resolves through the public action")


# ---------------------------------------------------------------- AC3 illegal launch

func _test_invalid_launch(seed_value: int) -> void:
	if seed_value <= 0:
		return
	var battle := _battle(seed_value, REAR_QUEEN)
	if battle == null:
		return
	if not _to_queen(battle, 4):
		_expect(false, "AC3: the rear-rank Queen reaches her real round-four turn")
		return
	var queen := battle.get_unit("moth_queen")
	_expect(int(queen.get("rank", 0)) == 3
		and not StitchedParts.ranks_allowed(
			int(_ability(queen, "queen_devour").get("launch_mask", 0)), 3)
		and _rotation(battle, queen) == "moth_veil",
		"AC3: the real rank-three Queen cannot launch Devour, so her rotation is Moth Veil")
	var baseline := _baseline(battle)
	var rank_one := _hero_at(battle, 1)
	if rank_one.is_empty():
		return
	_case(battle, baseline, func() -> void:
		battle._units[rank_one]["statuses"]["mark"] = 3, "moth_veil", -1, "moth_veil",
		"AC3: an active Mark never invents an illegal Devour launch")
	var rank_two := _hero_at(battle, 2)
	if not rank_two.is_empty():
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var refused := battle.use_foe_ability("queen_devour", 2)
		_expect(not bool(refused.get("ok", true))
			and refused.get("error") == "ability cannot launch from rank 3"
			and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
			"AC3: the public Devour from an illegal rank is refused with no state or RNG spend")
	_restore(battle, baseline)


# ---------------------------------------------------------------- AC3 other foes and refusals

func _test_other_foes_and_refusals(seed_value: int) -> void:
	if seed_value <= 0:
		return
	var battle := _battle(seed_value, PAIR)
	if battle == null:
		return
	if not _to_queen(battle, 4):
		return
	var crab := battle.get_unit("scissor_crab")
	_expect(not crab.is_empty(), "AC3: the escort foe really exists beside the Queen")
	if not crab.is_empty():
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var first := StitchedFoeIntent.choose(battle, crab)
		var second := StitchedFoeIntent.choose(battle, crab)
		var own := _ability_ids(crab)
		_expect(first == second and snapshot == battle.state_snapshot() and rng == battle.rng_state(),
			"AC3: an unrelated foe's projection is read-only and identical twice")
		_expect(not first.is_empty() and own.has(str(first.get("ability_id", "")))
			and str(first.get("ability_id", "")) == _rotation(battle, crab)
			and str(first.get("ability_id", "")) != "queen_devour",
			"AC3: an unrelated foe keeps exactly its own existing rotation choice")
	# A stunned Queen announces no attack and invents no prey.
	var baseline := _baseline(battle)
	var rank_two := _hero_at(battle, 2)
	if not rank_two.is_empty():
		_restore(battle, baseline)
		battle._units[rank_two]["statuses"]["mark"] = 3
		battle._units["moth_queen"]["statuses"]["stun"] = 1
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var stunned := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
		_expect(bool(stunned.get("stun", false)) and bool(stunned.get("pass", false))
			and str(stunned.get("ability_id", "")) == "" and snapshot == battle.state_snapshot()
			and rng == battle.rng_state(),
			"AC3: a stunned Queen reports no action and invents no Devour")
	_restore(battle, baseline)
	# A Queen-less fight never grows a Devour branch, and a stale Queen record is fail-closed.
	var without := _battle(seed_value, ["scissor_crab", "moth_scribe"])
	if without != null:
		var crab_two := without.get_unit("scissor_crab")
		if not crab_two.is_empty():
			var snapshot := without.state_snapshot()
			var rng := without.rng_state()
			var choice := StitchedFoeIntent.choose(without, crab_two)
			_expect(not choice.is_empty() and _ability_ids(crab_two).has(str(choice.get("ability_id", "")))
				and str(choice.get("ability_id", "")) != "queen_devour"
				and snapshot == without.state_snapshot() and rng == without.rng_state(),
				"AC3: a Queen-less fight keeps the ordinary foe choices untouched")
		var stale_snapshot := without.state_snapshot()
		var stale_rng := without.rng_state()
		_expect(StitchedFoeIntent.choose(without, {"id": "moth_queen", "side": "foe"}).is_empty()
			and StitchedFoeIntent.choose(without, {}).is_empty()
			and stale_snapshot == without.state_snapshot() and stale_rng == without.rng_state(),
			"AC3: an absent or detached Queen request is refused without state or RNG spend")


# ---------------------------------------------------------------- AC2 genuine Dive then Devour

## One authentic script: the real rank-one Queen's round-one Pin Crown Dive into hero rank two,
## then her next real round-one turn. It returns {} unless the Dive landed, the Mark survives,
## the ordinary rotation is Queen Dust, the chosen Devour hits, and its damage is only
## explicable by the canonical Mark bonus (with Bleed 2 on the surviving doll).
func _devour_trace(seed_value: int, deep: bool) -> Dictionary:
	var battle := _battle(seed_value, PAIR)
	if battle == null:
		return {}
	if not _to_queen(battle, 1):
		return {}
	var queen := battle.get_unit("moth_queen")
	if int(queen.get("rank", 0)) != 1:
		return {}
	var dive := battle.use_foe_ability("queen_dive", 2)
	var dive_result := _single_result(dive)
	if not bool(dive.get("ok", false)) or dive_result.is_empty() \
			or str(dive_result.get("target", "")) != "seamstress" \
			or not bool(dive_result.get("hit", false)):
		return {}
	if deep:
		_expect(dive_result.get("statuses") == [{"status": "tangled", "duration": 2},
			{"status": "mark", "duration": 3}]
			and dive_result.get("snip", {}).get("ok") == true,
			"AC2: the genuine Dive receipt applies Tangled 2, Snip 1 and Mark 3")
	if not _to_queen(battle, 1):
		return {}
	var victim := battle.get_unit("seamstress")
	var victim_before := victim.duplicate(true)
	if victim_before.get("dead", false) or victim_before.get("lost", false) \
			or int(victim_before.get("hp", 0)) <= 0 \
			or int(victim_before.get("statuses", {}).get("mark", 0)) <= 0:
		return {}
	var rotation := _rotation(battle, battle.get_unit("moth_queen"))
	if rotation != "queen_dust":
		return {}
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	var replay := StitchedFoeIntent.choose(battle, battle.get_unit("moth_queen"))
	if intent != replay or snapshot != battle.state_snapshot() or rng != battle.rng_state():
		return {}
	if str(intent.get("ability_id", "")) != "queen_devour" \
			or int(intent.get("target_rank", 0)) != 2:
		return {}
	if deep:
		_expect(int(victim_before["statuses"].get("mark", 0)) > 0,
			"AC2: the genuine Dive's Mark is still active on the later Queen turn")
		_expect(rotation == "queen_dust", "AC2: the ordinary round-one rotation would be Queen Dust")
		_expect(str(intent.get("ability_id", "")) == "queen_devour"
			and str(intent.get("ability_name", "")) == "Devour"
			and str(intent.get("ability_kind", "")) == "melee"
			and str(intent.get("target_side", "")) == "hero"
			and int(intent.get("target_rank", 0)) == 2
			and intent.get("affected_ranks") == [2] and not bool(intent.get("multi", true))
			and int(intent.get("base_acc", 0)) == 85 and intent.get("base_damage") == [7, 9]
			and int(intent.get("base_mark_damage", 0)) == 3
			and intent.get("base_effects") == {"bleed": 2},
			"AC1: the marked prey overrides the Dust rotation with canonical rank-two Devour")
	var before_turn := battle.state_snapshot()
	var living_queen := battle.get_unit("moth_queen")
	var chance := StitchedRules.hit_chance(
		85 + int(living_queen.get("acc", 0)) + int(battle.candle_band()["enemy_acc"]),
		StitchedRules.effective_dodge(victim_before), int(living_queen.get("miss_streak", 0)))
	var devour := battle.use_foe_ability("queen_devour", 2)
	var result := _single_result(devour)
	if not bool(devour.get("ok", false)) or result.is_empty() \
			or not bool(result.get("hit", false)):
		return {}
	if deep:
		_expect(result.has("roll") and int(result.get("hit_chance", -1)) == chance
			and bool(result.get("hit", false)) == (int(result.get("roll", 101)) <= chance),
			"AC2: the Devour keeps the ordinary seeded ACC 85 / Dodge hit roll")
		_expect(int(result.get("damage", 0)) > 0
			and (battle.current_actor_id() != "moth_queen"
				or battle.round_number() > int(before_turn["round"])
				or int(battle.state_snapshot()["turn_index"]) > int(before_turn["turn_index"])),
			"AC2: the public Devour resolves one hit and consumes the Queen's turn normally")
	var actor := battle.get_unit("moth_queen")
	var bases: Array = [StitchedRules.crit_damage(9)] if bool(result.get("crit", false)) else [7, 8, 9]
	var marked_values: Array = []
	var unmarked_values: Array = []
	for base in bases:
		var scaled := StitchedS1BEffects.enemy_damage(
			int(base) + int(actor.get("dmg_bonus", 0)), battle.candle())
		marked_values.append(StitchedRules.damage_after_modifiers(
			scaled, actor["statuses"], victim_before["statuses"], true,
			int(_ability(actor, "queen_devour").get("mark_damage", 0)),
			int(victim_before.get("prot", 0))))
		unmarked_values.append(StitchedRules.damage_after_modifiers(
			scaled, actor["statuses"], victim_before["statuses"], false,
			int(_ability(actor, "queen_devour").get("mark_damage", 0)),
			int(victim_before.get("prot", 0))))
	var clean := true
	for value in unmarked_values:
		if marked_values.has(value):
			clean = false
	if deep:
		_expect(marked_values.has(int(result.get("damage", -1))),
			"AC2: the Devour damage is the canonical marked value through the real rules")
		_expect(clean and not unmarked_values.has(int(result.get("damage", -1))),
			"AC2: only the eligible +3 Mark damage explains this hit, never a fixed number")
		_expect(int(result.get("target_hp", -1))
			== int(victim_before.get("hp", 0)) - int(result.get("damage", 0)),
			"AC2: the receipt reports the victim's real HP after the hit")
		_expect(result.get("statuses") == [{"status": "bleed", "duration": 2}],
			"AC2: a landed Devour applies exactly the authored Bleed 2")
	var after := battle.get_unit("seamstress")
	if deep:
		var bleed := int(after.get("statuses", {}).get("bleed", 0))
		_expect((bleed == 2 and int(after.get("hp", -1)) == int(result.get("target_hp", -2)))
			or (bleed == 1 and int(after.get("hp", -1)) == int(result.get("target_hp", -2)) - 2),
			"AC2: the marked doll survives to carry Bleed, honouring its start-of-turn tick")
	return {"seed": seed_value, "receipts": [dive, devour], "intent": intent,
		"state": battle.state_snapshot(), "rng": battle.rng_state(),
		"heroes": battle.get_heroes().duplicate(true), "foes": battle.get_foes().duplicate(true),
		"mark": int(victim_before["statuses"].get("mark", 0)), "rotation": rotation,
		"marked_values": marked_values, "unmarked_values": unmarked_values, "clean": clean}


func _find_devour_witness() -> int:
	recording = false
	var found := 0
	for seed_value in range(1, 97):
		var trace := _devour_trace(seed_value, false)
		if trace.is_empty() or not bool(trace.get("clean", false)):
			continue
		found = seed_value
		break
	recording = true
	return found


func _test_dive_then_devour() -> void:
	var first := _devour_trace(witness_seed, true)
	_expect(not first.is_empty(), "AC2: the recorded Dive-then-Devour script completes")
	if first.is_empty():
		return
	recording = false
	var replay := _devour_trace(witness_seed, true)
	recording = true
	_expect(not replay.is_empty() and first == replay,
		"AC2: the same seed and public actions replay intents, receipts, snapshot and RNG exactly")


# ---------------------------------------------------------------- live mounted foe driver

## The real mounted battle screen's own foe driver already dispatches StitchedFoeIntent.choose
## through StitchedRules.use_foe_ability; on the witnessed later turn it must commit the same
## marked Devour, not only project it.
func _test_live_driver() -> void:
	var stage := StitchedBattleScreen.new()
	var started := stage.begin(_config(witness_seed, PAIR))
	_expect(started and stage.battle != null,
		"AC2: the real battle screen accepts the canonical boss fight")
	if stage.battle == null:
		stage.free()
		return
	var battle := stage.battle
	var dive_ok := false
	if _to_queen(battle, 1):
		var dive := battle.use_foe_ability("queen_dive", 2)
		var dive_result := _single_result(dive)
		dive_ok = bool(dive.get("ok", false)) and not dive_result.is_empty() \
			and bool(dive_result.get("hit", false))
	_expect(dive_ok, "AC2: the live screen's real Dive lands and sews the Mark")
	if not dive_ok or not _to_queen(battle, 1):
		_expect(false, "AC2: the live screen fight reaches the later marked Queen turn")
		stage.free()
		return
	var before := stage.receipts.size()
	stage._drive_foes()
	var receipt: Dictionary = {}
	for index in range(before, stage.receipts.size()):
		var item: Dictionary = stage.receipts[index]
		if str(item.get("actor", "")) == "moth_queen" \
				and str(item.get("ability", "")) == "queen_devour":
			receipt = item
			break
	var result := _single_result(receipt)
	_expect(not receipt.is_empty() and not result.is_empty(),
		"AC2: the unchanged live foe driver commits exactly one real Devour")
	_expect(str(result.get("target", "")) == "seamstress" and int(result.get("target_rank", 0)) == 2
		and bool(result.get("hit", false)) and int(result.get("damage", 0)) > 0
		and result.get("statuses") == [{"status": "bleed", "duration": 2}],
		"AC2: the live driver bites the marked rank-two prey with real damage and Bleed 2")
	stage.free()
