extends SceneTree
## S5 Needle Marshal: Iron Discipline wards the most wounded living allied foe.
##
## The canonical elite's third authored action now adds temporary Dodge 8 for two of the
## target's turns beside its Thorns 2. StitchedFoeIntent chooses that single target by the
## lowest current HP/max_hp fraction (exact ties to the lower rank) instead of the ordinary
## nearest legal rank. Every combat witness below comes from the real StitchedRules public
## API on a seeded four-doll battle; only the explicit comparator fixtures set HP, and the
## round value, so the Marshal's own round-3 rotation selects the ward without inventing a
## turn. No battle state or RNG is touched by the projection itself.

const ELITES := "res://data/enemies/m04_elites.json"
const PREVIEW := "res://data/stitched/s2_preview.json"
const MARSHAL := "needle_marshal"
const WARD := "iron_discipline"
const HEXER := "spool_hexer"
const BAILIFF := "scissor_bailiff"
const RAGLING := "ragling"
const SEED_LIMIT := 120
const ALLY_EFFECTS := {"thorns": 2, "dodge": 8, "duration": 2}
const INTENT_KEYS := [
	"foe_id", "foe_name", "ability_id", "ability_name", "ability_kind", "target_rank",
	"target_side", "affected_ranks", "multi", "pass", "stun", "base_acc", "base_damage",
	"base_crit", "base_mark_damage", "base_effects",
]
const PRICK := {
	"id": "marshal_prick", "name": "Marshal Prick", "kind": "melee",
	"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
	"acc": 87, "dmg": [4, 6], "crit": 0, "effects": {"bleed": 1, "mark": 3},
	"self_move": 0, "move": "attack2",
}
const VOLLEY := {
	"id": "marshal_volley", "name": "Marshal Volley", "kind": "ranged",
	"launch": [1, 4], "target": [1, 3], "target_side": "enemy", "multi": false,
	"acc": 85, "dmg": [3, 5], "crit": 0, "mark_damage": 3, "effects": {},
	"self_move": 0, "move": "attack3",
}
const IRON := {
	"id": WARD, "name": "Iron Discipline", "kind": "buff",
	"launch": [1, 3], "target": [1, 2, 3, 4], "target_side": "ally", "multi": false,
	"acc": 100, "dmg": [0, 0], "crit": 0, "effects": ALLY_EFFECTS,
	"self_move": 0, "move": "guard",
}

var checks := 0
var failures: Array[String] = []
## False while a bounded seed probe looks for a battle whose authentic turns can witness the
## live ward and its two-turn expiry; probes never record assertions.
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
	_test_loaded_catalog()
	_test_wounded_policy()
	_test_other_abilities()
	_test_no_ward_fallbacks()
	_test_live_ward()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_marshal_wounded_discipline_test: ",
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


# ---------------------------------------------------------------- AC1 canonical record

func _test_source(raw: Array) -> void:
	var matches: Array = raw.filter(func(record: Variant) -> bool:
		return record is Dictionary and str(record.get("id", "")) == MARSHAL)
	_check(matches.size() == 1, "AC1: the elite source holds exactly one Needle Marshal record")
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	_check(record.get("name") == "Needle Marshal" and int(record.get("max_hp", 0)) == 28
		and record.get("art_path") == "res://assets/paper/enemies/needle_marshal.png",
		"AC1: the Marshal keeps its name, legacy HP and existing art")
	var profile: Dictionary = record.get("stitched", {})
	var stats := {"max_hp": 28, "speed": 5, "dodge": 6, "acc": 0, "prot": 6,
		"is_boss": false, "turns_per_round": 1, "trophy": "needle_marshal_sash"}
	for key in stats:
		_check(profile.get(key) == stats[key],
			"AC1: the Marshal profile keeps its authored " + str(key))
	var abilities: Array = profile.get("abilities", [])
	_check(abilities.size() == 3
		and _ability_ids({"abilities": abilities}) == ["marshal_prick", "marshal_volley", WARD],
		"AC1: the three authored actions keep their order")
	if abilities.size() != 3:
		return
	_check(_json(abilities[0]) == _json(PRICK),
		"AC1: Marshal Prick keeps every authored field")
	_check(_json(abilities[1]) == _json(VOLLEY),
		"AC1: Marshal Volley keeps every authored field")
	_check(_json(abilities[2]) == _json(IRON),
		"AC1: Iron Discipline changes only to Thorns 2 plus Dodge 8 for two turns")
	var validated := StitchedParts.validate_ability(_json(IRON))
	_check(bool(validated.get("ok", false))
		and validated["ability"]["effects"] == ALLY_EFFECTS,
		"AC1: StitchedParts validates the paired Dodge/duration ward effects")
	# Every neighbouring elite record must still resolve, validate and keep its own trophy.
	# ID presence only: a shared catalog must not hard-code its total.
	var neighbours := 0
	for candidate in raw:
		if not candidate is Dictionary:
			continue
		var candidate_id := str(candidate.get("id", ""))
		if candidate_id == MARSHAL:
			continue
		neighbours += 1
		var foe := StitchedEnemyCatalog.foe_for(_catalog, candidate_id)
		var candidate_profile: Dictionary = candidate.get("stitched", {})
		var abilities_valid := true
		for ability in candidate_profile.get("abilities", []):
			abilities_valid = abilities_valid \
				and bool(StitchedParts.validate_ability(ability).get("ok", false))
		_check(not foe.is_empty() and str(foe.get("id", "")) == candidate_id
			and StitchedEnemyCatalog.trophy_for(_catalog, candidate_id)
				== str(candidate_profile.get("trophy", ""))
			and abilities_valid,
			"AC1: every other elite keeps its own id, trophy and valid authored kit: " + candidate_id)
	_check(neighbours >= 2, "AC1: non-vacuous neighbour coverage beside the Marshal")
	for required in [HEXER, BAILIFF, "zipper_hauler", "needle_briar_guard",
			"spool_snarekeeper", "pincushion_matriarch", "spool_leech"]:
		_check(_catalog["foes"].has(required),
			"AC1: untouched elite id still resolves: " + required)


func _test_loaded_catalog() -> void:
	var foe := StitchedEnemyCatalog.foe_for(_catalog, MARSHAL)
	_check(not foe.is_empty(), "AC1: the canonical Marshal foe loads")
	if foe.is_empty():
		return
	var stats := {"max_hp": 28, "speed": 5, "dodge": 6, "acc": 0, "prot": 6,
		"is_boss": false, "turns_per_round": 1}
	for key in stats:
		_check(foe.get(key) == stats[key], "AC1: loaded Marshal stat stays exact: " + str(key))
	_check(int(foe["dodge"]) == 6,
		"AC1: the temporary ward never raises the Marshal's permanent Dodge")
	_check(_ability_ids(foe) == ["marshal_prick", "marshal_volley", WARD],
		"AC1: the loader exposes the three authored actions in order")
	var ward := _ability(foe, WARD)
	_check(not ward.is_empty() and ward.get("name") == "Iron Discipline"
		and ward.get("kind") == "buff" and ward.get("launch") == [1, 3]
		and ward.get("target") == [1, 2, 3, 4] and ward.get("target_side") == "ally"
		and ward.get("multi") == false and int(ward.get("acc", 0)) == 100
		and ward.get("dmg") == [0, 0] and int(ward.get("crit", -1)) == 0
		and ward.get("effects") == ALLY_EFFECTS and int(ward.get("self_move", -1)) == 0
		and ward.get("move") == "guard"
		and int(ward.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 3])
		and int(ward.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3, 4]),
		"AC1: Iron Discipline keeps its launch, ally ranks, ACC 100, zero damage and guard pose")


# ---------------------------------------------------------------- battle fixtures

func _fixture(ids: Array, seed_value: int) -> StitchedRules:
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


## Controlled comparator fixture: set current HP and the round the rotation reads. The ward
## rotation offset is (round - 1) % 3, so round 3 selects the Marshal's third action.
func _select_ward_round(battle: StitchedRules) -> void:
	battle._round = 3
	_check((battle.round_number() - 1) % 3 == 2
		and str(battle.get_unit(MARSHAL)["abilities"][2]["id"]) == WARD,
		"fixture: round 3 rotates the Marshal to Iron Discipline")


func _set_hp(battle: StitchedRules, unit_id: String, hp: int) -> void:
	battle._units[unit_id]["hp"] = hp


func _status_entry(statuses: Array, status_name: String) -> Dictionary:
	for entry in statuses:
		if str(entry.get("status", "")) == status_name:
			return entry
	return {}


## Project and independently witness one ward choice. Read-only and output-shape checks run
## for every case so a selector that mutated state or invented a forecast would fail here.
func _assert_ward(battle: StitchedRules, expected_rank: int, note: String) -> Dictionary:
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(MARSHAL))
	_check(battle.state_snapshot() == state and battle.rng_state() == rng,
		note + " never mutates the battle or consumes RNG")
	_check(str(choice.get("ability_id", "")) == WARD
		and str(choice.get("ability_name", "")) == "Iron Discipline"
		and str(choice.get("ability_kind", "")) == "buff"
		and int(choice.get("target_rank", 0)) == expected_rank
		and choice.get("affected_ranks") == [expected_rank]
		and str(choice.get("target_side", "")) == "foe"
		and not bool(choice.get("multi", true)) and not bool(choice.get("pass", true)),
		note + " projects Iron Discipline on rank %d only" % expected_rank)
	_check(choice.get("base_damage") == [0, 0] and int(choice.get("base_acc", -1)) == 100
		and int(choice.get("base_crit", -1)) == 0 and int(choice.get("base_mark_damage", -1)) == 0
		and _json(choice.get("base_effects")) == _json(ALLY_EFFECTS),
		note + " exposes authored base numbers only, never a hit or damage forecast")
	var keys: Array = choice.keys()
	var shape := keys.size() == INTENT_KEYS.size()
	for key in keys:
		shape = shape and str(key) in INTENT_KEYS
	_check(shape, note + " adds no output key to the intent dictionary")
	return choice


# ---------------------------------------------------------------- AC2 faction targeting

func _test_wounded_policy() -> void:
	# An injured rank-2 ally beats the full-HP front rank.
	var battle := _fixture([HEXER, BAILIFF, MARSHAL], 31)
	if battle != null:
		_select_ward_round(battle)
		_set_hp(battle, HEXER, 24)
		_set_hp(battle, BAILIFF, 9)
		_set_hp(battle, MARSHAL, 28)
		_check(9 * 24 == 24 * 9 and 9 * 1 < 36, "fixture: rank 2 is exactly one quarter of its maximum")
		_assert_ward(battle, 2, "AC2: an injured rank-2 ally outranks a full-HP rank 1")
	# A wounded rank-3 ally beats a healthier rank-1 caster.
	var front := _fixture([MARSHAL, HEXER, BAILIFF], 32)
	if front != null:
		_select_ward_round(front)
		_set_hp(front, MARSHAL, 28)
		_set_hp(front, HEXER, 24)
		_set_hp(front, BAILIFF, 9)
		_check(int(front.get_unit(MARSHAL)["rank"]) == 1,
			"fixture: the Marshal itself stands in rank 1")
		_assert_ward(front, 3, "AC2: a wounded rank-3 ally outranks the healthier rank-1 caster")
	# Two unequal maximum-HP allies compare fractions, not absolute HP.
	var fractions := _fixture([HEXER, BAILIFF, MARSHAL], 33)
	if fractions != null:
		_select_ward_round(fractions)
		_set_hp(fractions, HEXER, 12)   # 12/24 = 0.500
		_set_hp(fractions, BAILIFF, 17)  # 17/36 = 0.472
		_set_hp(fractions, MARSHAL, 28)
		_check(17 > 12 and 17 * 24 < 12 * 36,
			"fixture: rank 2 holds more absolute HP but a smaller fraction")
		_assert_ward(fractions, 2,
			"AC2: the smaller HP/max_hp fraction wins over lower absolute HP")
	# An exact tie goes to the lower rank, compared with integer cross-products.
	var tie := _fixture([HEXER, BAILIFF, MARSHAL], 34)
	if tie != null:
		_select_ward_round(tie)
		_set_hp(tie, HEXER, 12)    # 12/24 = 0.5
		_set_hp(tie, BAILIFF, 18)  # 18/36 = 0.5
		_set_hp(tie, MARSHAL, 28)
		_check(12 * 36 == 18 * 24, "fixture: the two fractions are an exact integer tie")
		_assert_ward(tie, 1, "AC2: an exact fraction tie favors the lower foe rank")
	# The caster is eligible when its own health is the lowest fraction.
	var caster := _fixture([HEXER, BAILIFF, MARSHAL], 35)
	if caster != null:
		_select_ward_round(caster)
		_set_hp(caster, HEXER, 24)
		_set_hp(caster, BAILIFF, 36)
		_set_hp(caster, MARSHAL, 4)   # 4/28 = 0.143
		_check(4 * 36 < 24 * 28 and 4 * 24 < 36 * 28,
			"fixture: the caster alone holds the smallest fraction")
		var choice := _assert_ward(caster, 3,
			"AC2: the Marshal is a legal ward target when it is the most wounded ally")
		_check(str(choice.get("foe_id", "")) == MARSHAL,
			"AC2: the self-ward still names the authoritative Marshal actor")
	# A dead ally behind a scrap heap is never a ward.
	var fallen := _fixture([HEXER, BAILIFF, MARSHAL], 36)
	if fallen != null:
		_select_ward_round(fallen)
		_set_hp(fallen, HEXER, 0)
		fallen._units[HEXER]["dead"] = true
		fallen._heaps.append({"id": "heap:test", "side": "heap", "rank": 1,
			"hp": 5, "max_hp": 5, "foe_id": HEXER})
		_set_hp(fallen, BAILIFF, 12)
		_set_hp(fallen, MARSHAL, 28)
		var actor := fallen.get_unit(MARSHAL)
		var ward := _ability(actor, WARD)
		_check(not fallen._legal_targets(actor, ward, 1).is_empty()
			and str(fallen._legal_targets(actor, ward, 1)[0]["side"]) == "heap",
			"fixture: rank 1 still returns its scrap heap to the ordinary legality API")
		_assert_ward(fallen, 2, "AC2: a scrap heap is never warded even when it fills the rank")
		fallen._heaps.clear()
		_check(fallen._legal_targets(actor, ward, 1).is_empty(),
			"fixture: a dead ally without scrap leaves a truly empty rank")
		_assert_ward(fallen, 2, "AC2: an empty rank is never warded")
	# A lost ally is never a ward, though the ordinary legality API still returns it.
	var lost := _fixture([HEXER, BAILIFF, MARSHAL], 37)
	if lost != null:
		_select_ward_round(lost)
		_set_hp(lost, HEXER, 24)
		_set_hp(lost, BAILIFF, 1)
		lost._units[BAILIFF]["lost"] = true
		_set_hp(lost, MARSHAL, 28)
		var actor := lost.get_unit(MARSHAL)
		var ward := _ability(actor, WARD)
		var legal := lost._legal_targets(actor, ward, 2)
		_check(not legal.is_empty() and str(legal[0]["id"]) == BAILIFF,
			"fixture: the lost ally is still returned by ordinary legality")
		_assert_ward(lost, 1, "AC2: a lost ally is never warded despite the smallest fraction")
	# Empty ranks and heaps leave only the real foes; an all-healthy line keeps rank 1.
	var empty := _fixture([HEXER, RAGLING, MARSHAL], 38)
	if empty != null:
		_select_ward_round(empty)
		_check(empty.get_foes().size() == 3
			and int(empty.get_unit(HEXER)["rank"]) == 1
			and int(empty.get_unit(RAGLING)["rank"]) == 2
			and int(empty.get_unit(MARSHAL)["rank"]) == 3,
			"fixture: a three-foe line occupies ranks 1-3 with the Marshal in its legal rank 3")
		var choice := _assert_ward(empty, 1,
			"AC2: an all-healthy line keeps the ordinary front-rank choice")
		_check(int(choice.get("target_rank", 0)) in [1, 2, 3],
			"AC2: an empty rank 4 is never invented")
		_set_hp(empty, HEXER, 0)
		empty._units[HEXER]["dead"] = true
		empty._heaps.append({"id": "heap:hexer", "side": "heap", "rank": 1,
			"hp": 5, "max_hp": 5, "foe_id": HEXER})
		_set_hp(empty, RAGLING, 6)  # 6/12 = 0.5
		_assert_ward(empty, 2, "AC2: a dead ally behind scrap is skipped for a living rank 2")
	var healthy := _fixture([HEXER, BAILIFF, MARSHAL], 39)
	if healthy != null:
		_select_ward_round(healthy)
		_check(int(healthy.get_unit(MARSHAL)["hp"]) == 28
			and int(healthy.get_unit(HEXER)["hp"]) == 24
			and int(healthy.get_unit(BAILIFF)["hp"]) == 36,
			"fixture: every ally is at full health")
		_assert_ward(healthy, 1,
			"AC2: an all-healthy party preserves the nearest front-rank behavior")


# ---------------------------------------------------------------- AC4 untouched policies

func _test_other_abilities() -> void:
	# Round 1 rotates to Marshal Prick: still the nearest legal hero rank even with an
	# injured rear ally that the ward policy would prefer.
	var prick := _fixture([MARSHAL, HEXER, BAILIFF], 41)
	if prick != null:
		prick._round = 1
		_set_hp(prick, BAILIFF, 6)
		var choice := StitchedFoeIntent.choose(prick, prick.get_unit(MARSHAL))
		_check(str(choice.get("ability_id", "")) == "marshal_prick"
			and int(choice.get("target_rank", 0)) == 1
			and choice.get("affected_ranks") == [1],
			"AC4: Marshal Prick keeps first-legal-rank rotation and never seeks the bruised ally")
	# Round 2 rotates to Marshal Volley: rank 1 first, rank 3 when the front doll is lost.
	var volley := _fixture([MARSHAL, HEXER, BAILIFF], 42)
	if volley != null:
		volley._round = 2
		var first := StitchedFoeIntent.choose(volley, volley.get_unit(MARSHAL))
		_check(str(first.get("ability_id", "")) == "marshal_volley"
			and int(first.get("target_rank", 0)) == 1,
			"AC4: Marshal Volley scans the front hero rank first")
		var front := _hero_id_at(volley, 1)
		volley._units[front]["lost"] = true
		var next := StitchedFoeIntent.choose(volley, volley.get_unit(MARSHAL))
		_check(str(next.get("ability_id", "")) == "marshal_volley"
			and int(next.get("target_rank", 0)) == 3,
			"AC4: Marshal Volley falls to its next legal hero rank, not a phantom")
	# Multi-target and pull abilities keep their own scans beside the Marshal.
	var multi := _fixture([HEXER, MARSHAL, "needle_briar_guard"], 43)
	if multi != null:
		multi._round = 2
		var choice := StitchedFoeIntent.choose(multi, multi.get_unit("needle_briar_guard"))
		_check(str(choice.get("ability_id", "")) == "briar_wall"
			and bool(choice.get("multi", false))
			and choice.get("affected_ranks") == [1, 2, 3],
			"AC4: a multi-target ally buff still covers every living foe rank")
	var pull := _fixture(["spool_snarekeeper", MARSHAL, RAGLING], 44)
	if pull != null:
		pull._round = 2
		var choice := StitchedFoeIntent.choose(pull, pull.get_unit("spool_snarekeeper"))
		_check(str(choice.get("ability_id", "")) == "spool_snare"
			and int(choice.get("target_rank", 0)) == 4
			and choice.get("affected_ranks") == [4],
			"AC4: a pull still scans the deepest legal doll rank first")
	# Mark hunting is untouched: a marked rear doll is chosen over the living front.
	var hunt := _fixture([HEXER, MARSHAL, RAGLING], 45)
	if hunt != null:
		hunt._round = 1
		var rear := _hero_id_at(hunt, 3)
		hunt._units[rear]["statuses"]["mark"] = 3
		var choice := StitchedFoeIntent.choose(hunt, hunt.get_unit(HEXER))
		_check(str(choice.get("ability_id", "")) == "hex_bolt"
			and int(choice.get("target_rank", 0)) == 3,
			"AC4: the existing Mark hunter still prefers the closest already-Marked rank")
		hunt._units[rear]["statuses"].erase("mark")
		var plain := StitchedFoeIntent.choose(hunt, hunt.get_unit(HEXER))
		_check(int(plain.get("target_rank", 0)) == 1,
			"AC4: without a Mark the same attack returns to rank 1")


func _test_no_ward_fallbacks() -> void:
	# A stunned Marshal proposes no ward at all.
	var stunned := _fixture([HEXER, MARSHAL, BAILIFF], 46)
	if stunned != null:
		_select_ward_round(stunned)
		stunned._units[MARSHAL]["statuses"]["stun"] = 1
		var choice := StitchedFoeIntent.choose(stunned, stunned.get_unit(MARSHAL))
		_check(bool(choice.get("stun", false)) and str(choice.get("ability_id", "")) == ""
			and int(choice.get("target_rank", -1)) == 0
			and not choice.has("base_damage") and not choice.has("base_effects"),
			"AC4: a stunned Marshal reports STUN with no ward, target or base numbers")
	# A Marshal that cannot launch Iron Discipline uses the next legal authored action.
	var unlaunchable := _fixture([MARSHAL, HEXER, BAILIFF], 47)
	if unlaunchable != null:
		unlaunchable._round = 3
		unlaunchable._units[MARSHAL]["rank"] = 4
		_check(StitchedParts.ranks_allowed(
			int(_ability(unlaunchable.get_unit(MARSHAL), WARD)["launch_mask"]), 4) == false,
			"fixture: rank 4 is outside Iron Discipline's authored launch ranks")
		var choice := StitchedFoeIntent.choose(unlaunchable, unlaunchable.get_unit(MARSHAL))
		_check(str(choice.get("ability_id", "")) == "marshal_volley"
			and int(choice.get("target_rank", 0)) == 1,
			"AC4: an unlaunchable ward falls through to the next legal authored action")
	# No eligible ally means no ward rank; the public chooser keeps its fail-closed shape.
	var no_ally := _fixture([HEXER, BAILIFF, MARSHAL], 48)
	if no_ally != null:
		_select_ward_round(no_ally)
		_set_hp(no_ally, HEXER, 0)
		no_ally._units[HEXER]["dead"] = true
		_set_hp(no_ally, BAILIFF, 0)
		no_ally._units[BAILIFF]["dead"] = true
		no_ally._units[MARSHAL]["lost"] = true
		var actor := no_ally.get_unit(MARSHAL)
		_check(StitchedFoeIntent._wounded_ally_rank(no_ally, actor, _ability(actor, WARD)) == 0,
			"AC4: the ward selector yields no rank when the only legal ally is the lost caster")
		_check(StitchedFoeIntent.choose(no_ally, no_ally.get_unit(MARSHAL)).is_empty(),
			"AC4: a lost Marshal has no selectable ward, preserving the fail-closed intent")
	# A dead Marshal proposes nothing at all.
	var dead := _fixture([HEXER, BAILIFF, MARSHAL], 50)
	if dead != null:
		_select_ward_round(dead)
		_set_hp(dead, MARSHAL, 0)
		dead._units[MARSHAL]["dead"] = true
		var before := dead.state_snapshot()
		var rng := dead.rng_state()
		_check(StitchedFoeIntent.choose(dead, dead.get_unit(MARSHAL)).is_empty()
			and dead.state_snapshot() == before and dead.rng_state() == rng,
			"AC4: a dead Marshal proposes no ward and changes nothing")
	# A caster that alone survives still wards itself rather than the scrap heaps behind it.
	var alone := _fixture([MARSHAL, HEXER], 49)
	if alone != null:
		_select_ward_round(alone)
		_set_hp(alone, HEXER, 0)
		alone._units[HEXER]["dead"] = true
		alone._heaps.append({"id": "heap:test", "side": "heap", "rank": 2,
			"hp": 5, "max_hp": 5, "foe_id": HEXER})
		_assert_ward(alone, 1,
			"AC4: with only the caster left the ward lands on the living Marshal, never scrap")


# ---------------------------------------------------------------- AC3 live seeded ward

func _hero_id_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _test_live_ward() -> void:
	recording = false
	var chosen := 0
	for seed_value in range(1, SEED_LIMIT + 1):
		if not _live_script(seed_value).is_empty():
			chosen = seed_value
			break
	recording = true
	_check(chosen > 0,
		"AC3: a seeded 4-hero/3-foe battle witnesses the live ward and its two-turn expiry")
	if chosen == 0:
		return
	var first := _live_script(chosen)
	_check(not first.is_empty(), "AC3: the recorded seeded ward script completes every witness")
	if first.is_empty():
		return
	recording = false
	var replay := _live_script(chosen)
	recording = true
	_check(not replay.is_empty() and _json(first) == _json(replay),
		"AC3: the same seed and legal action script replay receipts, state and RNG exactly")


## One real hero strike at the given foe rank. Returns 1 when it wounded Hexer, 2 when a
## legal attack spent the turn without wounding it, 0 when no equipped part could fire.
func _strike_rank(battle: StitchedRules, target_rank: int, receipts: Array) -> int:
	var hero := battle.get_unit(battle.current_actor_id())
	if str(hero.get("side", "")) != "hero":
		return 0
	for slot in StitchedParts.SLOTS:
		var worn: Dictionary = hero.get("parts", {}).get(slot, {})
		if worn.is_empty() or bool(worn.get("torn", false)):
			continue
		var definition: Dictionary = battle._parts.get(str(worn["id"]), {})
		var ability := StitchedParts.ability_at_tier(definition, int(worn["tier"]))
		if ability.is_empty() or str(ability.get("target_side", "")) != "enemy" \
				or int(ability["dmg"][1]) <= 0:
			continue
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(hero["rank"])) \
				or not StitchedParts.ranks_allowed(int(ability["target_mask"]), target_rank):
			continue
		if not battle._self_move_gate(hero, ability).is_empty():
			continue
		if battle._legal_targets(hero, ability, target_rank).is_empty():
			continue
		var receipt := battle.use_part(str(worn["id"]), target_rank)
		if not bool(receipt.get("ok", false)):
			continue
		receipts.append(receipt)
		for result in receipt.get("results", []):
			if str(result.get("target", "")) == HEXER and bool(result.get("hit", false)) \
					and int(result.get("damage", 0)) > 0:
				return 1
		return 2
	return 0


## One complete seeded script on a fresh canonical 4v3 battle: lawful turns to the Marshal's
## round-3 ward, one provoking hero strike, the real Iron Discipline action, every unbuffed
## bystander, then the ally's own two turns for the expiry. Returns {} when any witness is
## missing so the bounded probe can try the next seed.
func _live_script(seed_value: int) -> Dictionary:
	var battle := _fixture([MARSHAL, RAGLING, HEXER], seed_value)
	if battle == null:
		return {}
	var receipts: Array = []
	var opening_marshal := battle.get_unit(MARSHAL)
	var opening_hexer := battle.get_unit(HEXER)
	var opening_ragling := battle.get_unit(RAGLING)
	_expect(int(opening_marshal.get("rank", 0)) == 1 and int(opening_ragling.get("rank", 0)) == 2
		and int(opening_hexer.get("rank", 0)) == 3,
		"AC3 precondition: the canonical trio fills foe ranks 1-3")
	_expect(int(opening_hexer["hp"]) == int(opening_hexer["max_hp"])
		and int(opening_marshal["hp"]) == int(opening_marshal["max_hp"])
		and int(opening_ragling["hp"]) == int(opening_ragling["max_hp"]),
		"AC3 precondition: all three allies start at full health")
	var injured := false
	var reached := false
	for _step in range(240):
		if battle.is_over():
			break
		var actor_id := battle.current_actor_id()
		if actor_id == MARSHAL and battle.round_number() == 3:
			reached = true
			break
		if battle.round_number() > 3:
			break
		var actor := battle.get_unit(actor_id)
		if not injured and str(actor.get("side", "")) == "hero":
			var struck := _strike_rank(battle, 3, receipts)
			if struck == 1:
				injured = true
				continue
			if struck == 2:
				continue
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			break
		receipts.append(passed)
	if not _expect(reached and injured,
		"AC3: lawful seeded turns reach the Marshal's round-3 ward after a real wound"):
		return {}
	var marshal := battle.get_unit(MARSHAL)
	var hexer_before := battle.get_unit(HEXER)
	var ragling_before := battle.get_unit(RAGLING)
	var permanent := int(hexer_before["dodge"])
	_expect(int(hexer_before["hp"]) < int(hexer_before["max_hp"]),
		"AC3 precondition: a real hero strike left the rank-3 ally wounded")
	_expect(int(hexer_before["hp"]) * int(ragling_before["max_hp"])
			< int(ragling_before["hp"]) * int(hexer_before["max_hp"])
		and int(hexer_before["hp"]) * int(marshal["max_hp"])
			< int(marshal["hp"]) * int(hexer_before["max_hp"]),
		"AC3 precondition: the wounded rank-3 ally owns the lowest HP/max_hp fraction")
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var intent := StitchedFoeIntent.choose(battle, marshal)
	_expect(state == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: the live projection consumes no state, turn or RNG")
	_expect(str(intent.get("ability_id", "")) == WARD
		and int(intent.get("target_rank", 0)) == 3
		and intent.get("affected_ranks") == [3]
		and str(intent.get("target_side", "")) == "foe"
		and str(intent.get("ability_kind", "")) == "buff"
		and not bool(intent.get("multi", true)) and not bool(intent.get("pass", true)),
		"AC3: the authentic round-3 rotation projects Iron Discipline on the wounded rank 3")
	var hero_dodge: Dictionary = {}
	for hero in battle.get_heroes():
		hero_dodge[str(hero["id"])] = StitchedRules.effective_dodge(hero)
	var ward := battle.use_foe_ability(str(intent["ability_id"]), int(intent["target_rank"]))
	receipts.append(ward)
	if not _expect(bool(ward.get("ok", false)) and str(ward.get("actor", "")) == MARSHAL
		and str(ward.get("ability", "")) == WARD and ward.get("results", []).size() == 1,
		"AC3: the real foe action resolves Iron Discipline once for the chosen rank"):
		return {}
	_expect(battle.is_over() or battle.current_actor_id() != MARSHAL,
		"AC3: the ward spends exactly the Marshal's one turn")
	var result: Dictionary = ward["results"][0]
	_expect(str(result.get("target", "")) == HEXER and int(result.get("target_rank", 0)) == 3
		and str(result.get("target_side", "")) == "foe" and bool(result.get("hit", false))
		and int(result.get("damage", -1)) == 0
		and int(result.get("target_hp", -1)) == int(hexer_before["hp"])
		and not bool(result.get("crit", true)) and not result.has("roll"),
		"AC3: the ward is a confirmed 0-damage action on exactly the wounded rank-3 ally")
	var statuses: Array = result.get("statuses", [])
	var thorns := _status_entry(statuses, "thorns")
	var dodge := _status_entry(statuses, "dodge")
	_expect(statuses.size() == 2 and int(thorns.get("duration", -1)) == 2
		and int(dodge.get("amount", -1)) == 8 and int(dodge.get("duration", -1)) == 2,
		"AC3: the real receipt names Thorns 2 and temporary Dodge 8 for two turns")
	var hexer_after := battle.get_unit(HEXER)
	# The ward lands as Thorns 2; if the ally's next turn has already begun, the ordinary
	# start-of-turn clock has taken that status to its last tick, which is still active.
	_expect(int(hexer_after["statuses"].get("thorns", 0)) > 0
		and hexer_after["dodge_buff"] == {"amount": 8, "turns": 2, "skip": false}
		and int(hexer_after["dodge"]) == permanent
		and StitchedRules.effective_dodge(hexer_after) == permanent + 8,
		"AC3: the chosen ally carries active Thorns and Dodge +8 for two own turns, permanent Dodge intact")
	_expect(int(hexer_after["hp"]) == int(hexer_before["hp"])
		and int(hexer_after["rank"]) == 3,
		"AC3: the ward deals no damage and does not move the ally")
	for foe in battle.get_foes():
		if str(foe["id"]) == HEXER:
			continue
		_expect(int(foe["statuses"].get("thorns", 0)) == 0 and foe["dodge_buff"].is_empty()
			and StitchedRules.effective_dodge(foe) == int(foe["dodge"]),
			"AC3: healthy allied foe " + str(foe["id"]) + " remains unbuffed")
	for hero in battle.get_heroes():
		_expect(hero["dodge_buff"].is_empty()
			and int(hero["statuses"].get("thorns", 0)) == 0
			and StitchedRules.effective_dodge(hero) == int(hero_dodge.get(str(hero["id"]), -1)),
			"AC3: no hero receives the ward: " + str(hero["id"]))
	var first_turn := false
	var expired := false
	for _step in range(240):
		if battle.is_over():
			break
		var actor_id := battle.current_actor_id()
		var actor := battle.get_unit(actor_id)
		if actor_id == HEXER and not first_turn:
			_expect(actor["dodge_buff"] == {"amount": 8, "turns": 2, "skip": false}
				and StitchedRules.effective_dodge(actor) == permanent + 8,
				"AC3: the ward is still active when the ally takes its first own turn")
			var passed := battle.pass_turn()
			receipts.append(passed)
			if not _expect(bool(passed.get("ok", false)),
					"AC3: a lawful pass spends the ally's first warded turn"):
				return {}
			var after := battle.get_unit(HEXER)
			first_turn = true
			_expect(after["dodge_buff"] == {"amount": 8, "turns": 1, "skip": false}
				and StitchedRules.effective_dodge(after) == permanent + 8,
				"AC3: the first own turn clocks the ward from two to one and keeps Dodge +8")
			continue
		if actor_id == HEXER and first_turn:
			_expect(actor["dodge_buff"] == {"amount": 8, "turns": 1, "skip": false}
				and StitchedRules.effective_dodge(actor) == permanent + 8,
				"AC3: the ward survives into the ally's second own turn")
			var second := battle.pass_turn()
			receipts.append(second)
			if not _expect(bool(second.get("ok", false)),
					"AC3: a lawful pass spends the ally's second warded turn"):
				return {}
			var gone := battle.get_unit(HEXER)
			expired = true
			_expect(gone["dodge_buff"].is_empty()
				and StitchedRules.effective_dodge(gone) == permanent
				and int(gone["dodge"]) == permanent,
				"AC3: the second own turn expires the ward and leaves permanent Dodge untouched")
			break
		var advance := battle.pass_turn()
		if not bool(advance.get("ok", false)):
			break
		receipts.append(advance)
	if not _expect(first_turn and expired,
		"AC3: the two-turn ward clocks down through the ally's own lawful turns"):
		return {}
	return {
		"receipts": receipts.duplicate(true),
		"order": battle.turn_order(),
		"state": battle.state_snapshot(),
		"rng": battle.rng_state(),
		"marshal": battle.get_unit(MARSHAL),
		"hexer": battle.get_unit(HEXER),
		"ragling": battle.get_unit(RAGLING),
	}
