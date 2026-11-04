extends SceneTree
## Scene-free S6 admission contract, including a real seeded S1a rules witness.

const IDS := [
	"warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem",
]
const HP := {
	"warden": 40, "seamstress": 30, "tinker": 26, "lantern_monk": 30,
	"rag_duelist": 32, "scarecrow": 34, "yarn_ranger": 27, "button_golem": 48,
}
const NAMES := {
	"warden": "Warden", "seamstress": "Seamstress", "tinker": "Tinker",
	"lantern_monk": "Lantern Monk", "rag_duelist": "Rag Duelist",
	"scarecrow": "Scarecrow", "yarn_ranger": "Yarn Ranger", "button_golem": "Button Golem",
}
const PREVIEW := "res://data/stitched/s2_preview.json"
const LEGACY := "res://data/heroes/starter_party.json"
const ROSTER := "res://data/heroes/v3_party_roster.json"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_all_picks()
	_test_preference_collisions()
	_test_invalid_picks()
	_test_rng_and_detachment()
	_test_roster_validation()
	_test_seeded_rules_witness()
	if failures.is_empty():
		print("stitched_s6_party_pick_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s6_party_pick_test: FAIL (", failures.size(), "/", checks, ")")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _failed(picks: Variant, sources: Variant = null) -> void:
	var result := StitchedPartyAdmission.admit(picks, sources)
	_check(result == {"ok": false, "heroes": [], "hero_ids": []},
		"invalid input has an empty failed receipt: " + str(picks))


func _assert_party(picks: Array, label: String) -> Dictionary:
	var result := StitchedPartyAdmission.admit(picks)
	_check(bool(result.get("ok", false)), label + ": admits valid four")
	if not result.get("ok", false):
		return {}
	_check(not result.has("deck") and not result.has("cards") and not result.has("party"),
		label + ": receipt contains no card payload")
	var heroes: Array = result["heroes"]
	var hero_ids: Array = result["hero_ids"]
	_check(heroes.size() == 4 and hero_ids.size() == 4, label + ": four distinct ranks")
	if heroes.size() != 4 or hero_ids.size() != 4:
		return {}
	var seen := {}
	for index in range(4):
		var hero: Dictionary = heroes[index]
		var id: String = str(hero.get("id", ""))
		_check(not seen.has(id) and id in picks, label + ": exactly one selected identity " + id)
		seen[id] = true
		_check(hero.get("name") == NAMES.get(id) and hero.get("max_hp") == HP.get(id),
			label + ": canonical identity and HP " + id)
		_check(hero.get("rank") == index + 1 and hero_ids[index] == id,
			label + ": rank-ordered receipt " + str(index + 1))
		_check(hero.keys().size() == 4 and not hero.has("parts") and not hero.has("starter_cards"),
			label + ": bare hero needs kit later, no cards")
	_check(seen.size() == 4, label + ": each selected hero appears once")
	return result


func _test_all_picks() -> void:
	var combinations := 0
	for a in range(IDS.size()):
		for b in range(a + 1, IDS.size()):
			for c in range(b + 1, IDS.size()):
				for d in range(c + 1, IDS.size()):
					_assert_party([IDS[a], IDS[b], IDS[c], IDS[d]], "four-of-eight " + str(combinations))
					combinations += 1
	_check(combinations == 70, "all 70 four-of-eight groups were exercised")


func _test_preference_collisions() -> void:
	var a := _assert_party(["rag_duelist", "button_golem", "warden", "yarn_ranger"], "three front claims")
	_check(a.get("hero_ids", []) == ["rag_duelist", "button_golem", "yarn_ranger", "warden"],
		"first front claim wins; displaced heroes fill unused ranks in pick order")
	var b := _assert_party(["button_golem", "rag_duelist", "seamstress", "scarecrow"], "front/rear ties")
	_check(b.get("hero_ids", []) == ["button_golem", "seamstress", "rag_duelist", "scarecrow"],
		"earlier preference wins each seat, displaced duelist precedes scarecrow")
	var c := _assert_party(["scarecrow", "lantern_monk", "seamstress", "warden"], "rank two pileup")
	_check(c.get("hero_ids", []) == ["warden", "scarecrow", "lantern_monk", "seamstress"],
		"three second-rank claims occupy ranks two through four by pick order")


func _test_invalid_picks() -> void:
	_failed(null)
	_failed("warden")
	_failed({})
	_failed([])
	_failed(["warden", "seamstress", "tinker"])
	_failed(["warden", "seamstress", "tinker", "lantern_monk", "rag_duelist"])
	_failed(["warden", "warden", "seamstress", "tinker"])
	_failed(["warden", "seamstress", "tinker", "unknown"])
	_failed(["warden", "seamstress", "tinker", 1])
	_failed(["warden", "seamstress", "tinker", null])
	_failed(["warden", "seamstress", "tinker", StringName("lantern_monk")])
	_failed(["warden", "seamstress", "tinker", ""])
	_failed(["Warden", "seamstress", "tinker", "lantern_monk"])
	_failed(["warden", "seamstress", "tinker", "lantern_monk"], {"unknown": []})
	_failed(["warden", "seamstress", "tinker", "lantern_monk"], "bad sources")


func _test_rng_and_detachment() -> void:
	var picks := ["button_golem", "rag_duelist", "scarecrow", "lantern_monk"]
	var first := _assert_party(picks, "rng/detachment reference")
	seed(7981)
	var next_global := randi()
	seed(7981)
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = 773531
	var before_run := run_rng.state
	var second := StitchedPartyAdmission.admit(picks)
	_check(randi() == next_global, "admission does not draw from global RNG")
	_check(run_rng.state == before_run, "admission does not use a caller run RNG")
	_check(first == second, "same selection replays byte-for-byte identically")
	if not first.get("ok", false):
		return
	first["hero_ids"][0] = "fake"
	first["heroes"][0]["name"] = "Spoiled"
	first["heroes"][0]["max_hp"] = -9
	first["heroes"].append({"id": "fake"})
	var third := StitchedPartyAdmission.admit(picks)
	_check(third == second, "mutated receipt and nested hero do not contaminate future admission")
	_check(third["heroes"] != first["heroes"], "returned arrays and dictionaries are detached")


func _test_roster_validation() -> void:
	var legacy: Variant = _read(LEGACY)
	var roster: Variant = _read(ROSTER)
	_check(legacy is Array and roster is Array, "both authored sources exist")
	if not legacy is Array or not roster is Array:
		return
	var picks := ["warden", "seamstress", "rag_duelist", "yarn_ranger"]
	var valid := StitchedPartyAdmission.admit(picks, {"legacy": legacy.duplicate(true), "roster": roster.duplicate(true)})
	_check(valid.get("ok", false), "complete canonical data fixture is accepted")
	var bad: Array = legacy.duplicate(true)
	bad.append(bad[0].duplicate(true))
	_failed(picks, {"legacy": bad})
	bad = legacy.duplicate(true)
	bad.remove_at(0)
	_failed(picks, {"legacy": bad})
	bad = legacy.duplicate(true)
	bad[0]["name"] = "   "
	_failed(picks, {"legacy": bad})
	bad = legacy.duplicate(true)
	bad[1]["max_hp"] = 0
	_failed(picks, {"legacy": bad})
	bad = legacy.duplicate(true)
	bad[2]["id"] = "outsider"
	_failed(picks, {"legacy": bad})
	bad = legacy.duplicate(true)
	bad[0]["max_hp"] = "40"
	_failed(picks, {"legacy": bad})
	bad = legacy.duplicate(true)
	bad[0]["name"] = "Counterfeit"
	_failed(picks, {"legacy": bad})
	bad = roster.duplicate(true)
	bad.append(bad[0].duplicate(true))
	_failed(picks, {"roster": bad})
	bad = roster.duplicate(true)
	bad.remove_at(4)
	_failed(picks, {"roster": bad})
	bad = roster.duplicate(true)
	bad[4]["name"] = ""
	_failed(picks, {"roster": bad})
	bad = roster.duplicate(true)
	bad[2]["max_hp"] = -1
	_failed(picks, {"roster": bad})
	bad = roster.duplicate(true)
	bad[3]["max_hp"] = 21.5
	_failed(picks, {"roster": bad})
	bad = roster.duplicate(true)
	bad[2]["default_position"] = 5
	_failed(picks, {"roster": bad})
	bad = roster.duplicate(true)
	bad[4]["default_position"] = 1.5
	_failed(picks, {"roster": bad})
	bad = roster.duplicate(true)
	bad[0]["id"] = "seamstress"
	_failed(picks, {"roster": bad})
	bad = roster.duplicate(true)
	bad[4]["max_hp"] = 99
	_failed(picks, {"roster": bad})
	_check(StitchedPartyAdmission.admit(picks).get("ok", false),
		"negative fixtures never mutate shipped admissions")


func _test_seeded_rules_witness() -> void:
	var preview: Variant = _read(PREVIEW)
	_check(preview is Dictionary, "the published S2 preview is loadable")
	if not preview is Dictionary:
		return
	var catalog := StitchedParts.build_catalog(preview.get("parts"))
	_check(bool(catalog.get("ok", false)), "preview part catalog is fully valid: " + str(catalog.get("error")))
	if not catalog.get("ok", false):
		return
	var generic: Dictionary = preview["heroes"][1]["parts"]
	for slot in StitchedParts.SLOTS:
		_check(generic.has(slot) and catalog["by_id"].has(generic[slot]),
			"preview generic " + slot + " fits an authored part")
	var admitted := _assert_party(["button_golem", "rag_duelist", "scarecrow", "lantern_monk"], "battle witness")
	if not admitted.get("ok", false):
		return
	var fitted: Array = []
	for hero in admitted["heroes"]:
		var configured: Dictionary = hero.duplicate(true)
		for stat in ["speed", "dodge", "acc", "prot"]:
			configured[stat] = preview["heroes"][1][stat]
		configured["parts"] = generic.duplicate(true)
		fitted.append(configured)
	var foes: Array = preview["foes"]
	_check(foes.size() == 3 and fitted.size() == 4, "actual four heroes and all three preview foes exist")
	if foes.size() != 3:
		return
	for count in [2, 3]:
		var config := {
			"mode": "stitched", "seed": 4952026, "parts": preview["parts"].duplicate(true),
			"heroes": fitted.duplicate(true), "foes": foes.slice(0, count).duplicate(true),
		}
		var build_a := StitchedRules.create(config)
		var build_b := StitchedRules.create(config)
		_check(bool(build_a.get("ok", false)) and bool(build_b.get("ok", false)),
			"seeded preview " + str(count) + "-foe fight builds: " + str(build_a.get("error")))
		if not build_a.get("ok", false) or not build_b.get("ok", false):
			continue
		var battle_a: StitchedRules = build_a["battle"]
		var battle_b: StitchedRules = build_b["battle"]
		_check(battle_a.is_valid() and battle_a.get_heroes().size() == 4 and battle_a.get_foes().size() == count,
			"witness includes all real admitted ranks and correct foe count")
		for index in range(4):
			var expected: Dictionary = admitted["heroes"][index]
			var actual := battle_a.get_unit(expected["id"])
			_check(actual.get("rank") == index + 1 and actual.get("base_max_hp") == expected["max_hp"],
				"rules honour admitted " + str(expected["id"]) + " at rank " + str(index + 1))
		_check(battle_a.state_snapshot() == battle_b.state_snapshot() and battle_a.turn_order() == battle_b.turn_order(),
			"equal seed and admitted party give equal initial state/turns")
		for _i in range(4):
			var a := battle_a.pass_turn()
			var b := battle_b.pass_turn()
			_check(a == b and bool(a.get("ok", false)) and battle_a.state_snapshot() == battle_b.state_snapshot(),
				"seeded preview turns replay consistently")
