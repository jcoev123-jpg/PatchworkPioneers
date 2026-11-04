extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_tear_and_replay()
	_test_reordered_battle_end()
	_test_mend_guards()
	_test_rest_and_new_tear()
	_test_tinker_floor()
	_test_defeat_and_bad_battles()
	_test_vital_receipts()
	_test_hero_gated_vitals()
	_test_deterministic_rng()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("run_torn_mending_test: PASS (", checks, " checks)")
	else:
		for error in failures:
			printerr(error)
		print("run_torn_mending_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _starter() -> Array:
	var source := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	_check(not source.is_empty(), "real starter JSON is readable")
	if source.is_empty():
		return []
	var data: Variant = JSON.parse_string(source)
	_check(typeof(data) == TYPE_ARRAY and data.size() == 3, "authored three-hero data parsed")
	if typeof(data) != TYPE_ARRAY or data.size() != 3:
		return []
	var definitions := []
	for hero in data:
		definitions.append({"id": hero["id"], "max_hp": int(hero["max_hp"]),
			"art_path": hero["art_path"],
			"metadata": {"owner": hero["id"], "tags": [{"fabric": "felt"}]}})
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "real CombatParty creates three living starting heroes")
	if not party.is_valid():
		return []
	var heroes: Array = party.get_heroes()
	for i in range(3):
		heroes[i]["statuses"] = {"bleed": i, "weak": 0, "exposed": 0}
	_check(heroes[0]["id"] == "warden" and heroes[0]["max_hp"] == 40
		and heroes[0]["position"] == 1 and heroes[0]["hp"] == 40
		and heroes[1]["id"] == "seamstress" and heroes[1]["max_hp"] == 30
		and heroes[1]["position"] == 2 and heroes[2]["id"] == "tinker"
		and heroes[2]["max_hp"] == 26 and heroes[2]["position"] == 3,
		"authored identity, slot, full HP and original maxima are preconditions")
	return heroes


func _new_service() -> RunTornMending:
	var original := _starter()
	if original.size() != 3:
		return RunTornMending.new()
	var untouched: Array = original.duplicate(true)
	var service := RunTornMending.new(original)
	_check(service.is_valid(), "starter constructs a valid M04 service")
	_check(original == untouched, "constructor does not mutate input")
	_check(service.has_method("observe_battle_end") and service.has_method("choose_mend")
		and service.has_method("apply_rest") and service.has_method("read_state"),
		"public scene-free transaction methods exist")
	return service


func _down(service: RunTornMending, node_id: String, index: int) -> Dictionary:
	var before: Array = service.read_state()["heroes"]
	var ended: Array = before.duplicate(true)
	ended[index]["hp"] = 0
	ended[index]["block"] = 9
	var result: Dictionary = service.observe_battle_end(node_id, before, ended)
	_check(result.get("ok") == true, node_id + " legal downing is witnessed")
	return result


func _reject(service: RunTornMending, label: String, action: Callable,
		expected_result: Dictionary = {}) -> void:
	var prior: Dictionary = service.read_state()
	var result: Dictionary = action.call()
	_check(result.get("ok") == false and result.get("heroes") == [],
		label + ": rejects with no proposed heroes")
	if not expected_result.is_empty():
		_check(result == expected_result, label + ": unchanged scrap proposal")
	_check(service.read_state() == prior, label + ": no state, count or receipt consumed")


func _test_tear_and_replay() -> void:
	var original := _starter()
	if original.size() != 3:
		return
	var service := RunTornMending.new(original)
	var start: Array = service.read_state()["heroes"]
	var ended: Array = start.duplicate(true)
	ended[0]["hp"] = 0
	ended[0]["block"] = 6
	ended[0]["statuses"]["bleed"] = 3
	ended[1]["block"] = 4
	var actual := service.observe_battle_end("fight_first", start, ended)
	_check(actual["ok"], "first battle accepted")
	var expected := ended.duplicate(true)
	expected[0]["max_hp"] = 37
	for hero in expected:
		hero["block"] = 0
	_check(actual["heroes"] == expected, "exact tear changes only Warden maximum and boundary Block")
	_check(service.read_state()["tear_counts"] == {"warden": 1, "seamstress": 0, "tinker": 0}
		and not service.read_state()["defeated"], "Warden one tear, surviving run")
	_check(original[0]["max_hp"] == 40 and original[0]["hp"] == 40,
		"original starter input never mutated")
	var recorded := service.read_state()
	_check(service.observe_battle_end("fight_first", start, ended)["ok"]
		and service.read_state() == recorded,
		"identical battle receipt is idempotent, no extra -3")
	var downed_start: Array = recorded["heroes"].duplicate(true)
	var still_downed: Array = downed_start.duplicate(true)
	_check(service.observe_battle_end("fight_second", downed_start, still_downed)["ok"],
		"distinct witnessed battle with same torn hero accepted")
	_check(service.read_state()["heroes"] == expected
		and service.read_state()["tear_counts"]["warden"] == 1,
		"torn->torn observation across node cannot apply tear again")
	_reject(service, "reused battle node with different end",
		func(): return service.observe_battle_end("fight_first", start, still_downed))
	var owned := service.read_state()
	actual["heroes"][0]["max_hp"] = 999
	actual["heroes"][0]["statuses"]["bleed"] = 999
	owned["heroes"][0]["metadata"]["tags"][0]["fabric"] = "changed"
	owned["tear_counts"]["warden"] = 100
	start[0]["hp"] = 999
	ended[0]["statuses"]["bleed"] = 999
	_check(service.read_state()["heroes"] == expected
		and service.read_state()["tear_counts"]["warden"] == 1,
		"returned/source nested structures never alias stored snapshots")



func _test_reordered_battle_end() -> void:
	var service := _new_service()
	if not service.is_valid():
		return
	var start: Array = service.read_state()["heroes"]
	var party := CombatParty.new(start)
	_check(party.is_valid() and party.get_heroes() == start,
		"move test uses an actual CombatParty holding the witnessed starter roster")
	if not party.is_valid() or party.get_heroes() != start:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 67219
	var cards: Array[String] = ["witnessed_swap"]
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.hand.has("witnessed_swap"),
		"witnessed movement card is really held during an active turn")
	var preview := CombatPositionSwaps.preview_adjacent_swap(party, 1, 1)
	_check(preview["ok"] and preview["heroes"][0]["id"] == "seamstress"
		and preview["heroes"][1]["id"] == "warden" and party.get_heroes() == start,
		"actual position-swap preview reorders without touching its combat party")
	var move_definition := {"id": "witnessed_swap", "owner": "warden", "cost": 1,
		"from_positions": [1], "action_kind": "adjacent_swap", "direction": 1}
	var played := CombatPositionSwaps.play_move_card(deck, party, "witnessed_swap", move_definition)
	_check(played and deck.energy == 2 and deck.discard_pile == ["witnessed_swap"],
		"real paid movement card commits one adjacent hero swap")
	if not played:
		return
	_check(party.get_heroes() == preview["heroes"] and party.get_hero(2)["id"] == "warden",
		"real combat party has the same moved actor records as the preview")
	_check(party.apply_damage(2, 40) and party.is_downed(2),
		"real CombatParty damage downs Warden at his new slot 2")
	party._heroes[1]["statuses"]["bleed"] = 4
	party._heroes[1]["block"] = 7
	var ending: Array = party.get_heroes()
	var original_end: Array = ending.duplicate(true)
	var expected: Array = ending.duplicate(true)
	expected[1]["max_hp"] = 37
	for hero in expected:
		hero["block"] = 0

	var foreign: Array = ending.duplicate(true)
	foreign[0]["id"] = "interloper"
	var duplicate: Array = ending.duplicate(true)
	duplicate[0]["id"] = "warden"
	var wrong_slot: Array = ending.duplicate(true)
	wrong_slot[0]["position"] = 2
	var wrong_max: Array = ending.duplicate(true)
	wrong_max[0]["max_hp"] = 31
	var wrong_moved_max: Array = ending.duplicate(true)
	wrong_moved_max[1]["max_hp"] = 39
	var unordered_without_positions: Array = start.duplicate(true)
	unordered_without_positions[0] = ending[0].duplicate(true)
	unordered_without_positions[1] = ending[1].duplicate(true)
	unordered_without_positions[0]["position"] = 2
	unordered_without_positions[1]["position"] = 1
	for malformed in [foreign, duplicate, wrong_slot, wrong_max,
			wrong_moved_max, unordered_without_positions]:
		_reject(service, "malformed moved roster",
			func(): return service.observe_battle_end("moved_fight", start, malformed))
	var moved_start: Array = start.duplicate(true)
	moved_start[0] = preview["heroes"][0].duplicate(true)
	moved_start[1] = preview["heroes"][1].duplicate(true)
	_reject(service, "battle start must still equal witnessed held order",
		func(): return service.observe_battle_end("moved_fight", moved_start, ending))
	var result := service.observe_battle_end("moved_fight", start, ending)
	_check(result["ok"] and result["heroes"] == expected,
		"real moved battle accepted: exact ordered roster, only Warden -3 and all Block reset")
	_check(service.read_state()["tear_counts"] == {"warden": 1, "seamstress": 0, "tinker": 0}
		and result["heroes"][0]["id"] == "seamstress"
		and result["heroes"][1]["id"] == "warden"
		and result["heroes"][1]["position"] == 2
		and result["heroes"][1]["hp"] == 0
		and result["heroes"][1]["statuses"]["bleed"] == 4
		and result["heroes"][1]["metadata"] == start[0]["metadata"],
		"the tear and statuses/metadata stay with Warden's ID, now at position 2")
	_check(start[0]["hp"] == 40 and ending == original_end,
		"witnessed start and ending snapshots are unmodified")
	var prior: Dictionary = service.read_state()
	_check(service.observe_battle_end("moved_fight", start, ending)["ok"]
		and service.read_state() == prior, "replayed reordered battle cannot tear twice")
	_reject(service, "reused moved battle node with changed HP",
		func(): return service.observe_battle_end("moved_fight", start, start))
	_reject(service, "wrong old slot used for moved Warden Mend",
		func(): return service.choose_mend("after_move", "move_receipt",
			"warden", 1, 2, prior["heroes"], true),
		{"ok": false, "heroes": [], "remaining_scraps": 2})
	var mended := service.choose_mend("after_move", "move_receipt", "warden",
		2, 2, prior["heroes"], true)
	_check(mended["ok"] and mended["remaining_scraps"] == 0
		and mended["heroes"][1]["id"] == "warden"
		and mended["heroes"][1]["hp"] == 9 and mended["heroes"][1]["max_hp"] == 37
		and mended["heroes"][0] == expected[0],
		"map Mend locates newly slotted torn Warden and revives 37/0 to 37/9")
	var down_again := _down(service, "after_move_again", 1)
	_check(down_again["ok"] and down_again["heroes"][1]["id"] == "warden"
		and down_again["heroes"][1]["max_hp"] == 34
		and service.read_state()["tear_counts"]["warden"] == 2,
		"new battle tears the moved and mended Warden a second time, not his old neighbor")
	var before_rest: Array = service.read_state()["heroes"]
	var oracle := RunRestRecovery.new(before_rest).choose_heal()
	var rested := service.apply_rest("moved_rest", before_rest, true)
	_check(oracle["ok"] and rested["ok"] and rested["heroes"] == oracle["heroes"]
		and rested["heroes"][1]["id"] == "warden"
		and rested["heroes"][1]["position"] == 2
		and rested["heroes"][1]["max_hp"] == 34
		and rested["heroes"][1]["hp"] == 11,
		"Rest delegates real recovery at moved position 2, retaining both tears")

	var shoved_service := _new_service()
	if not shoved_service.is_valid():
		return
	var shove_start: Array = shoved_service.read_state()["heroes"]
	var shoved_party := CombatParty.new(shove_start)
	var enemies := CombatEnemies.new([{"id": "shover", "max_hp": 8}])
	_check(shoved_party.is_valid() and enemies.is_valid()
		and shoved_party.get_heroes() == shove_start,
		"enemy shove test uses real healthy starter combat party and live enemy")
	if not shoved_party.is_valid() or not enemies.is_valid():
		return
	var shove := CombatEnemySpecialActions.new().execute_actions(shoved_party, enemies,
		[{"type": "shove", "enemy_position": 1, "amount": 0,
			"target_position": 1, "direction": 1}])
	_check(shove["ok"] and shove["events"].size() == 1
		and shove["events"][0]["applied"] and shoved_party.get_hero(2)["id"] == "warden",
		"real enemy shove commits Warden from slot 1 to slot 2")
	_check(shoved_party.apply_damage(2, 40) and shoved_party.is_downed(2),
		"real post-shove damage downs the actor now in slot 2")
	var shoved_end := shoved_party.get_heroes()
	var shove_result := shoved_service.observe_battle_end("enemy_shove", shove_start, shoved_end)
	var shove_expected: Array = shoved_end.duplicate(true)
	shove_expected[1]["max_hp"] = 37
	for hero in shove_expected:
		hero["block"] = 0
	_check(shove_result["ok"] and shove_result["heroes"] == shove_expected
		and shoved_service.read_state()["tear_counts"] == {"warden": 1, "seamstress": 0, "tinker": 0},
		"actual enemy shove is an accepted witnessed battle and tears Warden by ID")


func _test_mend_guards() -> void:
	var service := _new_service()
	if not service.is_valid():
		return
	_down(service, "battle_mend", 0)
	var torn: Array = service.read_state()["heroes"]
	var torn_copy: Array = torn.duplicate(true)
	var no_spend := {"ok": false, "heroes": [], "remaining_scraps": 2}
	_reject(service, "combat-time", func(): return service.choose_mend(
		"map_a", "decision_a", "warden", 1, 2, torn, false), no_spend)
	_reject(service, "bad map context type", func(): return service.choose_mend(
		"map_a", "decision_a", "warden", 1, 2, torn, "true"), no_spend)
	_reject(service, "living actor", func(): return service.choose_mend(
		"map_a", "decision_a", "seamstress", 2, 2, torn, true), no_spend)
	_reject(service, "unknown id", func(): return service.choose_mend(
		"map_a", "decision_a", "stranger", 1, 2, torn, true), no_spend)
	_reject(service, "wrong slot", func(): return service.choose_mend(
		"map_a", "decision_a", "warden", 2, 2, torn, true), no_spend)
	_reject(service, "bad currency", func(): return service.choose_mend(
		"map_a", "decision_a", "warden", 1, 1, torn, true),
		{"ok": false, "heroes": [], "remaining_scraps": 1})
	_reject(service, "negative currency", func(): return service.choose_mend(
		"map_a", "decision_a", "warden", 1, -1, torn, true),
		{"ok": false, "heroes": [], "remaining_scraps": -1})
	_reject(service, "fractional currency", func(): return service.choose_mend(
		"map_a", "decision_a", "warden", 1, 2.5, torn, true))
	_reject(service, "missing receipt", func(): return service.choose_mend(
		"map_a", "", "warden", 1, 2, torn, true), no_spend)
	var stale: Array = torn.duplicate(true)
	stale[1]["hp"] = 29
	_reject(service, "stale optimistic roster", func(): return service.choose_mend(
		"map_a", "decision_a", "warden", 1, 2, stale, true), no_spend)
	var healed := service.choose_mend("map_a", "decision_a", "warden", 1, 2, torn, true)
	var expected: Array = torn.duplicate(true)
	expected[0]["hp"] = 9
	_check(healed == {"ok": true, "heroes": expected, "remaining_scraps": 0},
		"37-max Warden mends to floor(25%) 9 and spends precisely two scraps")
	_check(service.read_state()["heroes"] == expected
		and service.read_state()["tear_counts"]["warden"] == 1,
		"mend leaves permanent loss, slots, statuses, metadata and other heroes intact")
	_check(service.read_state()["completed_mends"] == ["decision_a"],
		"successful map transaction consumes its one receipt")
	_check(torn == torn_copy and torn[0]["hp"] == 0, "mend input still torn")
	_reject(service, "repeated receipt", func(): return service.choose_mend(
		"map_other", "decision_a", "warden", 1, 2, expected, true), no_spend)
	_reject(service, "same map node, different receipt", func(): return service.choose_mend(
		"map_a", "decision_new", "warden", 1, 2, expected, true), no_spend)
	_reject(service, "already living", func(): return service.choose_mend(
		"map_other", "decision_new", "warden", 1, 2, expected, true), no_spend)
	var mut := service.read_state()
	healed["heroes"][0]["metadata"]["tags"][0]["fabric"] = "bad"
	mut["completed_mends"].append("intrusion")
	_check(service.read_state()["heroes"] == expected
		and service.read_state()["completed_mends"] == ["decision_a"],
		"mend outputs and state reads are completely detached")


func _test_rest_and_new_tear() -> void:
	var service := _new_service()
	if not service.is_valid():
		return
	var initial: Array = service.read_state()["heroes"]
	var ended: Array = initial.duplicate(true)
	ended[0]["hp"] = 0
	ended[1]["hp"] = 17
	ended[0]["statuses"]["exposed"] = 2
	_check(service.observe_battle_end("fight_rest", initial, ended)["ok"],
		"first witnessed tear and second actor's wounds committed")
	var current: Array = service.read_state()["heroes"]
	_check(current[0]["max_hp"] == 37 and current[0]["hp"] == 0
		and current[1]["hp"] == 17, "Rest fixture is a real post-tear snapshot")
	_reject(service, "Rest while in combat", func(): return service.apply_rest(
		"rest_one", current, false))
	var stale: Array = initial.duplicate(true)
	_reject(service, "Rest with stale prior maximum", func(): return service.apply_rest(
		"rest_one", stale, true))
	var oracle := RunRestRecovery.new(current)
	var from_oracle: Dictionary = oracle.choose_heal()
	_check(from_oracle["ok"] and oracle.is_consumed(), "independent real Rest service returns heal")
	var recovered := service.apply_rest("rest_one", current, true)
	_check(recovered["ok"] and recovered["heroes"] == from_oracle["heroes"],
		"M04 delegates Rest to RunRestRecovery rather than duplicating its rule")
	_check(recovered["heroes"][0]["hp"] == 12 and recovered["heroes"][0]["max_hp"] == 37
		and recovered["heroes"][1]["hp"] == 26 and recovered["heroes"][1]["max_hp"] == 30
		and recovered["heroes"][2]["hp"] == 26,
		"Rest revives Warden 1+floor(37*30%)=12 and heals others to caps")
	_check(service.read_state()["tear_counts"]["warden"] == 1
		and service.read_state()["completed_rests"] == ["rest_one"],
		"Rest preserves tear count and consumes one node")
	_reject(service, "repeat Rest", func(): return service.apply_rest(
		"rest_one", recovered["heroes"], true))
	_reject(service, "battle node cannot be reused for Rest", func(): return service.apply_rest(
		"fight_rest", recovered["heroes"], true))
	var down_again := _down(service, "fight_after_rest", 0)
	_check(down_again["heroes"][0]["max_hp"] == 34 and down_again["heroes"][0]["hp"] == 0
		and service.read_state()["tear_counts"]["warden"] == 2,
		"new tear after true Rest recovery reduces 37 to 34")
	var at_34: Array = service.read_state()["heroes"]
	var second := service.choose_mend("map_after_rest", "receipt_new", "warden", 1, 5, at_34, true)
	_check(second["ok"] and second["remaining_scraps"] == 3
		and second["heroes"][0]["hp"] == 8 and second["heroes"][0]["max_hp"] == 34,
		"fresh mend after distinct tear gives 8 HP, exact 5->3 scraps")
	var third := _down(service, "fight_after_mend", 0)
	_check(third["heroes"][0]["max_hp"] == 31
		and service.read_state()["tear_counts"]["warden"] == 3,
		"mend revival also re-arms later genuine downing")


func _test_tinker_floor() -> void:
	var service := _new_service()
	if not service.is_valid():
		return
	for i in range(7):
		var result := _down(service, "tinker_fight_%d" % i, 2)
		var expected_max := maxi(10, 26 - 3 * (i + 1))
		_check(result["heroes"][2]["max_hp"] == expected_max,
			"Tinker new downing %d clips max to %d" % [i, expected_max])
		_check(service.read_state()["tear_counts"]["tinker"] == i + 1,
			"one tear counted per unique legitimate Tinker downing")
		if i < 6:
			var state: Array = service.read_state()["heroes"]
			var mended := service.choose_mend("tinker_map_%d" % i, "tinker_receipt_%d" % i,
				"tinker", 3, 2, state, true)
			_check(mended["ok"] and mended["remaining_scraps"] == 0
				and mended["heroes"][2]["hp"] == maxi(1, expected_max / 4),
				"Tinker genuinely mends and becomes living before next tear")
	_check(service.read_state()["heroes"][2]["max_hp"] == 10,
		"floor 10 persists even after a seventh downing")


func _test_defeat_and_bad_battles() -> void:
	var service := _new_service()
	if not service.is_valid():
		return
	var start: Array = service.read_state()["heroes"]
	var wrong_id: Array = start.duplicate(true)
	wrong_id[1]["id"] = "intruder"
	var wrong_slot: Array = start.duplicate(true)
	wrong_slot[0]["position"] = 3
	var wrong_max: Array = start.duplicate(true)
	wrong_max[0]["max_hp"] = 41
	var revived: Array = start.duplicate(true)
	revived[0]["hp"] = -1
	var wrong_start: Array = start.duplicate(true)
	wrong_start[0]["hp"] = 39
	var bad_types: Array = start.duplicate(true)
	bad_types[2]["hp"] = 1.5
	var bad_status: Array = start.duplicate(true)
	bad_status[1]["statuses"]["bleed"] = -1
	for bad in [wrong_id, wrong_slot, wrong_max, revived, bad_types, bad_status]:
		_reject(service, "incompatible post-battle roster",
			func(): return service.observe_battle_end("possible", start, bad))
	_reject(service, "incompatible start", func(): return service.observe_battle_end(
		"possible", wrong_start, start))
	_reject(service, "missing battle id", func(): return service.observe_battle_end(
		" ", start, start))
	_check(service.observe_battle_end("possible", start, start)["ok"],
		"invalid attempts did not consume the battle node")
	var first: Array = service.read_state()["heroes"]
	var ended: Array = first.duplicate(true)
	ended[0]["hp"] = 0
	ended[1]["hp"] = 0
	_check(service.observe_battle_end("two_down", first, ended)["ok"],
		"run with two torn heroes but one living hero stays active")
	var two_down: Array = service.read_state()["heroes"]
	var illegal_revival: Array = two_down.duplicate(true)
	illegal_revival[0]["hp"] = 1
	_reject(service, "battle cannot revive previously torn", func():
		return service.observe_battle_end("illegal_revival", two_down, illegal_revival))
	var final: Array = two_down.duplicate(true)
	final[2]["hp"] = 0
	_check(service.observe_battle_end("defeat", two_down, final)["ok"],
		"all three downing recorded as terminal defeat")
	var dead: Dictionary = service.read_state()
	_check(dead["defeated"] and dead["heroes"].all(func(h): return h["hp"] == 0),
		"terminal state has all three genuinely downed actors")
	_reject(service, "terminal map cannot revive with scraps", func():
		return service.choose_mend("after_loss", "loss_receipt", "warden", 1, 99,
			dead["heroes"], true),
		{"ok": false, "heroes": [], "remaining_scraps": 99})
	_reject(service, "terminal Rest cannot revive", func():
		return service.apply_rest("rest_after_loss", dead["heroes"], true))
	_reject(service, "terminal battle cannot recur", func():
		return service.observe_battle_end("another", dead["heroes"], dead["heroes"]))
	var invalid := RunTornMending.new([])
	_check(not invalid.is_valid() and invalid.read_state()["heroes"].is_empty(),
		"invalid constructor never becomes a live run")


func _timeline() -> Dictionary:
	var service := RunTornMending.new(_starter())
	_check(service.is_valid(), "replay starts valid real party")
	if not service.is_valid():
		return {}
	var begin: Array = service.read_state()["heroes"]
	var downed: Array = begin.duplicate(true)
	downed[0]["hp"] = 0
	var a := service.observe_battle_end("battle_one", begin, downed)
	var after: Array = service.read_state()["heroes"]
	var failed := service.choose_mend("camp", "receipt", "warden", 1, 1, after, true)
	var mended := service.choose_mend("camp", "receipt", "warden", 1, 2, after, true)
	var healed := service.apply_rest("rest_next", service.read_state()["heroes"], true)
	var again := _down(service, "battle_again", 0)
	return {"a": a, "failed": failed, "mended": mended, "healed": healed,
		"again": again, "state": service.read_state()}


func _test_deterministic_rng() -> void:
	seed(716832)
	var expected_global := randi()
	seed(716832)
	var local := RandomNumberGenerator.new()
	local.seed = 91257
	var local_state: int = local.state
	var first := _timeline()
	var second := _timeline()
	_check(first == second and not first.is_empty(), "complete independently reconstructed sequence replays exactly")
	_check(first["state"]["tear_counts"]["warden"] == 2
		and first["mended"]["remaining_scraps"] == 0
		and first["again"]["heroes"][0]["max_hp"] == 34,
		"replay covers real tear, rejected spend, mend, Rest and second tear")
	_check(local.state == local_state and randi() == expected_global,
		"accepted and rejected transactions consume neither local nor global RNG")


func _test_vital_receipts() -> void:
	var pool := RunV3VitalEventRotation.new().get_vital_events()
	_check(not pool.is_empty(), "shipped vitality pool available")
	for record in pool:
		for choice in record.choices:
			var service := _new_service()
			_down(service, "prior_battle", 0)
			var old := service.read_state()
			var hero: Dictionary = old.heroes[1]
			var snapshot := {"gold": 100, "scraps": 100,
				"hero": {"id": hero.id, "hp": hero.hp, "max_hp": hero.max_hp}}
			var claim := RunEventChoice.new(record).choose_with_vitals(choice.id, snapshot)
			if not claim.ok:
				continue
			var forged := claim.duplicate(true)
			forged.state.hero.hp = 0
			_reject(service, "forged vitality", func(): return service.apply_vital_event(
				"vital", record, forged, snapshot, old))
			_reject(service, "used battle node", func(): return service.apply_vital_event(
				"prior_battle", record, claim, snapshot, old))
			var wrong := snapshot.duplicate(true)
			wrong.hero = {"id": old.heroes[2].id, "hp": old.heroes[2].hp, "max_hp": old.heroes[2].max_hp}
			var wrong_claim := RunEventChoice.new(record).choose_with_vitals(choice.id, wrong)
			_reject(service, "later living actor cannot replace first", func(): return service.apply_vital_event(
				"vital", record, wrong_claim, wrong, old))
			_check(service.apply_vital_event("vital", record, claim, snapshot, old).ok, "authored vitality accepted")
			var expected := old.duplicate(true)
			expected.heroes[1].max_hp += int(choice.outcome.max_hp)
			expected.heroes[1].hp = mini(hero.hp + int(choice.outcome.hp), expected.heroes[1].max_hp)
			expected.completed_vital_events.append("vital")
			for actor in expected.heroes:
				expected.vital_cap_offsets[actor.id] = int(choice.outcome.max_hp) if actor.id == hero.id else 0
			_check(service.read_state() == expected, "only first living vitals and distinct receipt change; tears retained")
			_reject(service, "duplicate vitality", func(): return service.apply_vital_event(
				"vital", record, claim, snapshot, service.read_state()))
			_reject(service, "stale expected ledger", func(): return service.apply_vital_event(
				"another", record, claim, snapshot, old))
			_reject(service, "vital node cannot Rest", func(): return service.apply_rest(
				"vital", service.read_state().heroes, true))
			_check(service.apply_rest("later_rest", service.read_state().heroes, true).ok,
				"Rest remains valid after authored HP and cap changes")

func _named_gated_service(picks: Array) -> RunTornMending:
	var admission := RunV3PartyAdmission.admit(picks)
	_check(admission.ok and admission.party.size() == 3, "canonical trio admission")
	if not admission.ok:
		return RunTornMending.new()
	var party := CombatParty.new(admission.party)
	_check(party.is_valid(), "canonical CombatParty for hero gate")
	var service := RunTornMending.new(party.get_heroes())
	_check(service.is_valid(), "canonical named trio has authentic full HP")
	return service


func _later_slot_party(required: String) -> Array:
	match required:
		"warden": return ["rag_duelist", "warden", "tinker"]
		"lantern_monk": return ["warden", "lantern_monk", "tinker"]
		"rag_duelist": return ["warden", "rag_duelist", "tinker"]
		"scarecrow": return ["warden", "scarecrow", "tinker"]
		"yarn_ranger": return ["warden", "seamstress", "yarn_ranger"]
		"button_golem": return ["warden", "button_golem", "tinker"]
		_: return ["warden", "seamstress", "tinker"]


func _vital_opening(state: Dictionary, required: String, gold: int = 60, scraps: int = 6) -> Dictionary:
	for actor in state.heroes:
		if actor.id == required:
			return {"gold": gold, "scraps": scraps, "hero": {
				"id": actor.id, "hp": actor.hp, "max_hp": actor.max_hp}}
	return {}


func _test_hero_gated_vitals() -> void:
	var records: Array = RunV3HeroVitalEventGate.load_shipped_catalog().get("events", [])
	_check(not records.is_empty(), "canonical hero-gated records load")
	var seen: Dictionary = {}
	for record in records:
		var required: String = record.required_hero
		for choice in record.choices:
			var service := _named_gated_service(_later_slot_party(required))
			if not service.is_valid():
				continue
			var old := service.read_state()
			var target := -1
			var ids: Array = []
			for index in range(old.heroes.size()):
				ids.append(old.heroes[index].id)
				if old.heroes[index].id == required:
					target = index
			_check(target > 0, record.id + " required living hero behind another living actor")
			if target < 0:
				continue
			var snapshot := _vital_opening(old, required)
			var snapshot_copy := snapshot.duplicate(true)
			var gate := RunV3HeroVitalEventGate.new(ids)
			_check(gate.is_valid(), "valid shipped gate " + record.id)
			if not gate.is_valid():
				continue
			var visit := gate.enter(record, snapshot)
			_check(visit != null and visit.is_valid(), "genuine named visit " + record.id)
			if visit == null:
				continue
			var receipt := visit.choose_with_vitals(choice.id)
			_check(receipt.ok, "real one-claim gated receipt " + record.id + "/" + choice.id)
			if not receipt.ok:
				continue
			var forged := receipt.duplicate(true)
			forged.state.hero.hp = 0
			_reject(service, "forged named receipt", func(): return service.apply_vital_event(
				"named_vital", record, forged, snapshot, old))
			var stale_opening := snapshot.duplicate(true)
			stale_opening.hero.max_hp += 1
			_reject(service, "mismatched named snapshot", func(): return service.apply_vital_event(
				"named_vital", record, receipt, stale_opening, old))
			_check(service.apply_vital_event("named_vital", record, receipt, snapshot, old).ok,
				"authenticated required owner settles " + record.id + "/" + choice.id)
			var expected := old.duplicate(true)
			var outcome: Dictionary = choice.outcome
			var original: Dictionary = old.heroes[target]
			expected.heroes[target].max_hp = original.max_hp + int(outcome.max_hp)
			expected.heroes[target].hp = mini(original.hp + int(outcome.hp), expected.heroes[target].max_hp)
			expected.completed_vital_events.append("named_vital")
			for actor in old.heroes:
				expected.vital_cap_offsets[actor.id] = int(outcome.max_hp) if actor.id == required else 0
			_check(service.read_state() == expected,
				"only named later-slot actor changes and canonical cap offsets/one node persist " + record.id)
			_check(receipt.state.gold == snapshot.gold + int(outcome.gold)
				and receipt.state.scraps == snapshot.scraps + int(outcome.scraps)
				and receipt.state.hero.hp == expected.heroes[target].hp
				and receipt.state.hero.max_hp == expected.heroes[target].max_hp,
				"exact authored wallet HP/max-HP receipt " + record.id)
			_check(snapshot == snapshot_copy, "detached original snapshot is unchanged")
			_reject(service, "gated replay", func(): return service.apply_vital_event(
				"named_vital", record, receipt, snapshot, service.read_state()))
			_reject(service, "gated stale ledger", func(): return service.apply_vital_event(
				"another", record, receipt, snapshot, old))
			seen[record.id] = true
	for required_event_id in [
		"v3_warden_buckle_heart_ward", "v3_seamstress_crimson_quilt_surgeon",
		"v3_tinker_copper_needle_greenhouse", "v3_lantern_monk_thimble_moon_vigil",
		"v3_rag_duelist_velvet_straw_mender", "v3_scarecrow_strawheart_alarm",
		"v3_yarn_ranger_starladder_bolas", "v3_button_golem_rivet_choir",
		"v3_tinker_blunderbuss_fuse_well",
	]:
		_check(seen.has(required_event_id),
			"required authored gated record exercised for all its choices: " + required_event_id)

	var seam_record: Dictionary = {}
	for record in records:
		if record.required_hero == "seamstress":
			seam_record = record
			break
	_check(not seam_record.is_empty(), "Seamstress negative event exists")
	if seam_record.is_empty():
		return
	var service := _named_gated_service(["warden", "seamstress", "tinker"])
	var old := service.read_state()
	var opening := _vital_opening(old, "seamstress")
	var visit := RunV3HeroVitalEventGate.new(["warden", "seamstress", "tinker"]).enter(seam_record, opening)
	_check(visit != null, "negative cases use a real canonical visit")
	if visit == null:
		return
	var receipt := visit.choose_with_vitals("stitch_wound")
	_check(receipt.ok, "negative witness carries genuine receipt")
	if not receipt.ok:
		return
	var edited := seam_record.duplicate(true)
	edited.erase("required_hero")
	_reject(service, "known event stripped required owner", func(): return service.apply_vital_event(
		"vital", edited, receipt, opening, old))
	edited = seam_record.duplicate(true)
	edited.required_hero = "tinker"
	_reject(service, "known event forged required owner", func(): return service.apply_vital_event(
		"vital", edited, receipt, opening, old))
	edited = seam_record.duplicate(true)
	edited.choices[0].outcome.hp += 1
	_reject(service, "known event forged choice outcome", func(): return service.apply_vital_event(
		"vital", edited, receipt, opening, old))
	edited = seam_record.duplicate(true)
	edited.id = "unknown_forged_gated_record"
	_reject(service, "unknown event cannot claim gated targeting", func(): return service.apply_vital_event(
		"vital", edited, receipt, opening, old))
	var wrong := opening.duplicate(true)
	wrong.hero = {"id": old.heroes[0].id, "hp": old.heroes[0].hp, "max_hp": old.heroes[0].max_hp}
	_reject(service, "first actor cannot replace required owner", func(): return service.apply_vital_event(
		"vital", seam_record, receipt, wrong, old))
	var insolvent := opening.duplicate(true)
	insolvent.gold = 0
	_reject(service, "unaffordable gate price", func(): return service.apply_vital_event(
		"vital", seam_record, receipt, insolvent, old))
	_reject(service, "wrong claimed choice", func(): return service.apply_vital_event(
		"vital", seam_record, {"choice_id": "leave"}, opening, old))
	var absent := _named_gated_service(["warden", "lantern_monk", "tinker"])
	_reject(absent, "required hero absent", func(): return absent.apply_vital_event(
		"absent", seam_record, receipt, opening, absent.read_state()))
	_down(service, "tear_seamstress", 1)
	_reject(service, "required hero Torn", func(): return service.apply_vital_event(
		"vital", seam_record, receipt, opening, service.read_state()))
