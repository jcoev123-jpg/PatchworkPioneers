extends SceneTree

var failures: Array[String] = []
var checks := 0
var starter: Array = []


func _initialize() -> void:
	starter = _load_starter()
	if starter.size() != 3:
		_finish()
		return
	_test_public_contract_and_detachment()
	_test_legal_opening_fight()
	_test_legal_opening_rest()
	_test_witnessed_victory_and_rest()
	_test_failed_and_foreign_results()
	_test_invalid_and_defeated()
	_test_seeded_replay_and_rng()
	_test_coat_torn_carryover()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("run_party_carryover_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_party_carryover_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _load_starter() -> Array:
	var raw := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	_check(not raw.is_empty(), "actual starter_party.json loads")
	var records: Variant = JSON.parse_string(raw)
	_check(typeof(records) == TYPE_ARRAY and records.size() == 3, "authored party has three definitions")
	if typeof(records) != TYPE_ARRAY or records.size() != 3:
		return []
	var expected_ids := ["warden", "seamstress", "tinker"]
	var expected_hp := [40, 30, 26]
	for i in range(3):
		if not records[i] is Dictionary:
			_check(false, "starter definition must be dictionary")
			return []
		var hero: Dictionary = records[i]
		_check(hero.get("id") == expected_ids[i] and hero.get("max_hp") == expected_hp[i],
			"authored starter id/HP %d" % i)
		if not hero.get("max_hp") is float and not hero.get("max_hp") is int:
			return []
		hero["max_hp"] = int(hero["max_hp"])
	return records


func _party() -> CombatParty:
	var definitions := starter.duplicate(true)
	for hero in definitions:
		hero["metadata"] = {"tags": [hero["id"], {"weave": ["stitched", "felt"]}]}
	return CombatParty.new(definitions)


func _battle() -> Dictionary:
	var party := _party()
	var enemies := CombatEnemies.new([{"id": "rag", "max_hp": 7},
		{"id": "button", "max_hp": 9}])
	var result := CombatBattleResult.new(party, enemies)
	_check(party.is_valid() and enemies.is_valid()
		and result.get_outcome() == CombatBattleResult.ACTIVE,
		"real battle starts with valid living rosters and ACTIVE result")
	return {"party": party, "enemies": enemies, "result": result}


func _win(battle: Dictionary) -> void:
	var enemies: CombatEnemies = battle["enemies"]
	var result: CombatBattleResult = battle["result"]
	_check(enemies.apply_damage(1, 7) and enemies.is_dead(1),
		"first real enemy dies in its slot")
	_check(result.evaluate() == CombatBattleResult.ACTIVE,
		"witness first enemy death without victory")
	_check(enemies.apply_damage(2, 9) and enemies.is_victorious(),
		"last real enemy dies and roster is victorious")
	_check(result.get_outcome() == CombatBattleResult.ACTIVE,
		"outcome was not fabricated before evaluation")
	_check(result.evaluate() == CombatBattleResult.VICTORY,
		"evaluate observes true terminal VICTORY")


func _test_public_contract_and_detachment() -> void:
	var invalid := RunPartyCarryover.new()
	_check(invalid.has_method("read_state") and invalid.has_method("get_next_fight_heroes")
		and invalid.has_method("commit_victory") and invalid.has_method("choose_rest_heal")
		and invalid.has_method("is_valid") and invalid.has_method("create_next_fight_party"),
		"documented public API including party hydration is exposed")
	_check(not invalid.is_valid() and invalid.get_next_fight_heroes().is_empty()
		and invalid.create_next_fight_party() == null,
		"invalid construction has no usable next party")
	_check(invalid.read_state()["ok"] == false
		and invalid.choose_rest_heal("rest") == {"ok": false, "heroes": []},
		"invalid service cannot read an accepted state or heal")
	var party := _party()
	_check(party.is_valid(), "authored party constructs")
	var initial := party.get_heroes()
	var expected := initial.duplicate(true)
	var carry := RunPartyCarryover.new(initial)
	_check(carry.is_valid(), "initialization from real CombatParty snapshot succeeds")
	_check_initial_hydrations(carry, expected, "public initial contract")
	_check(carry.read_state()["heroes"] == expected
		and carry.get_next_fight_heroes() == expected, "initial identities, order, HP and metadata retained")
	initial[0]["hp"] = 1
	initial[0]["metadata"]["tags"][1]["weave"].clear()
	_check(carry.read_state()["heroes"] == expected, "initial source mutation cannot alias service")
	var read := carry.read_state()
	var next := carry.get_next_fight_heroes()
	read["heroes"][0]["hp"] = 0
	read["heroes"][0]["metadata"]["tags"][0] = "fake"
	read["completed_fights"].append("fake_fight")
	read["completed_rests"].append("fake_rest")
	next[1]["position"] = 99
	next[2]["metadata"]["tags"].clear()
	_check(carry.read_state()["heroes"] == expected
		and carry.get_next_fight_heroes() == expected
		and carry.read_state()["completed_fights"].is_empty()
		and carry.read_state()["completed_rests"].is_empty(),
		"read_state, visit lists and next-fight arrays are independently detached")


func _check_initial_hydrations(carry: RunPartyCarryover, expected: Array, context: String) -> Array:
	var before := carry.read_state()
	var first := carry.create_next_fight_party()
	var second := carry.create_next_fight_party()
	_check(first != null and second != null and first != second
		and first.is_valid() and second.is_valid(), context + ": two distinct valid initial parties")
	if first == null or second == null:
		return []
	_check(first.get_heroes() == expected and second.get_heroes() == expected
		and not first.is_defeated() and not second.is_defeated(),
		context + ": both parties retain exact healthy Block-free carry state")
	_check(carry.read_state() == before and before["completed_fights"].is_empty()
		and before["completed_rests"].is_empty(), context + ": no visit is recorded")
	return [first, second]


func _test_legal_opening_fight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4103
	var map := RunMap.new()
	_check(map.generate(rng) and map.get_route().is_empty(), "opening Fight map is generated and unvisited")
	var fight_id := ""
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			fight_id = node_id
			break
	_check(not fight_id.is_empty(), "seed 4103 offers a legal opening Fight")
	if fight_id.is_empty():
		return
	var source := _party()
	_check(source.is_valid(), "opening Fight uses actual authored starter party")
	var expected := source.get_heroes()
	var carry := RunPartyCarryover.new(expected)
	var ledger := carry.read_state()
	var rng_before := rng.state
	seed(74090)
	var expected_random := randi()
	seed(74090)
	var parties := _check_initial_hydrations(carry, expected, "before opening Fight admission")
	_check(rng.state == rng_before and map.get_route().is_empty(),
		"initial hydration neither consumes run RNG nor chooses a map node")
	if parties.size() != 2:
		return
	var entry := RunAuthoredBattleEntry.new()
	var selector := RunFightEncounterSelection.new()
	_check(entry.entry_current_battle(map, rng, selector) == {"success": false}
		and rng.state == rng_before and carry.read_state() == ledger
		and map.get_route().is_empty(),
		"hydrated initial parties do not bypass route admission or spend on failed entry")
	_check(map.choose_node(fight_id) and map.get_route() == [fight_id],
		"opening Fight is committed through legal map traversal")
	var opened := expected.duplicate(true)
	opened[0]["block"] = 6
	for party: CombatParty in parties:
		var battle := entry.entry_current_battle(map, rng, selector)
		_check(battle.get("success") == true and battle.get("node_type") == "Fight",
			"real authored opening Fight admits each hydrated party")
		if not battle.get("success", false):
			return
		var enemies: CombatEnemies = battle["enemies"]
		var intents: CombatEnemyIntents = battle["intents"]
		var result := CombatBattleResult.new(party, enemies)
		var deck := CombatDeck.new(StarterCards.new().get_starting_deck(), rng)
		var flow := CombatRoundFlow.new(deck, party, enemies, intents, result)
		_check(enemies.is_valid() and intents.is_valid()
			and result.get_outcome() == CombatBattleResult.ACTIVE and flow.begin_fight(),
			"each fresh party starts a real round with authored enemies, intents and starter deck")
		_check(party.get_heroes() == opened and not flow._opening_block.apply()
			and not flow.begin_fight() and party.get_heroes() == opened,
			"each battle grants exactly one Warden +6 via CombatStartingBlock")
	var first: CombatParty = parties[0]
	var second: CombatParty = parties[1]
	rng_before = rng.state
	_check(first.apply_damage(1, 7) and first.get_hero(1)["hp"] == 39,
		"first battle really loses HP after absorbing its six Block")
	first._heroes[0]["statuses"] = {"bleed": 2}
	first._heroes[0]["metadata"]["tags"][1]["weave"].clear()
	_check(second.get_heroes() == opened and source.get_heroes() == expected
		and carry.read_state() == ledger, "first party HP/status/nested mutations leave peer, source and carry intact")
	var first_before := first.get_heroes()
	_check(second.apply_damage(2, 1) and second.get_hero(2)["hp"] == 29,
		"second battle really loses HP independently")
	second._heroes[1]["statuses"] = {"weak": 3}
	second._heroes[1]["metadata"]["tags"].clear()
	_check(first.get_heroes() == first_before and carry.read_state() == ledger
		and source.get_heroes() == expected and rng.state == rng_before,
		"second party HP/status/nested mutations preserve peer, carry, source and run RNG")
	_check_initial_hydrations(carry, expected, "after both initial battles mutate")
	_check(rng.state == rng_before and randi() == expected_random,
		"initial hydration, opening Block and mutations consume no global RNG; rehydration spends no run RNG")


func _test_legal_opening_rest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var map := RunMap.new()
	_check(map.generate(rng) and map.get_route().is_empty(),
		"seed 6 generates an untraversed real map")
	var rest_id := ""
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Rest":
			rest_id = node_id
			break
	_check(not rest_id.is_empty(), "seed 6 offers a genuinely legal opening Rest")
	if rest_id.is_empty():
		return
	var rng_before := rng.state
	seed(74006)
	var expected_random := randi()
	seed(74006)
	var source := _party()
	_check(source.is_valid(), "opening Rest starts from authored valid heroes")
	var initial := source.get_heroes()
	initial[0]["statuses"] = {"bleed": 2, "weak": 1}
	initial[2]["statuses"] = {"exposed": 3}
	var carry := RunPartyCarryover.new(initial)
	_check(carry.is_valid(), "authored opening Rest carry is valid")
	_check_initial_hydrations(carry, initial, "before opening Rest")
	for bad_id in ["", "   ", " bad", "bad ", 5, null, [], {}]:
		_assert_rejected(carry, "opening malformed Rest " + str(bad_id),
			func(): return carry.choose_rest_heal(bad_id))
		_check_initial_hydrations(carry, initial, "after malformed opening Rest")
	_check(map.choose_node(rest_id) and map.get_route() == [rest_id]
		and map.get_current_node_id() == rest_id,
		"opening Rest is chosen through authoritative map traversal")
	var oracle := RunRestRecovery.new(initial)
	var expected_rest := oracle.choose_heal()
	_check(expected_rest["ok"] and oracle.is_consumed(),
		"authoritative Rest oracle successfully settles authored roster")
	var settled := carry.choose_rest_heal(rest_id)
	_check(settled["ok"] and settled["heroes"] == expected_rest["heroes"],
		"legal opening Rest settles via carryover Rest transaction")
	var ledger := carry.read_state()
	_check(ledger["completed_fights"].is_empty()
		and ledger["completed_rests"] == [rest_id]
		and ledger["heroes"] == expected_rest["heroes"],
		"successful opening Rest records exactly its ID with no completed Fight")
	_assert_rejected(carry, "opening duplicate Rest",
		func(): return carry.choose_rest_heal(rest_id))
	var first := carry.create_next_fight_party()
	var second := carry.create_next_fight_party()
	_check(first != null and second != null and first != second
		and first.is_valid() and second.is_valid(),
		"Rest alone permits two distinct valid three-hero combat parties")
	if first == null or second == null:
		return
	var expected: Array = expected_rest["heroes"]
	_check(first.get_heroes() == expected and second.get_heroes() == expected,
		"both Rest-only hydrations retain exact HP, positions, statuses and metadata")
	for hero in expected:
		_check(hero["block"] == 0, "Rest-only hydration has no transit Block")
	var opening := CombatStartingBlock.new(first)
	var opened := expected.duplicate(true)
	opened[0]["block"] = 6
	_check(opening.apply() and first.get_heroes() == opened
		and not opening.apply() and first.get_heroes() == opened
		and second.get_heroes() == expected and carry.read_state() == ledger,
		"combat startup alone grants once-only Warden +6, preserving other party and ledger")
	first._heroes[0]["statuses"]["bleed"] = 99
	first._heroes[0]["metadata"]["tags"][1]["weave"].clear()
	var first_before := first.get_heroes()
	_check(second.get_heroes() == expected and carry.read_state() == ledger,
		"first hydrated party nested mutations cannot alias second or ledger")
	_check(second.apply_damage(2, 1), "second hydrated party accepts real combat damage")
	second._heroes[2]["statuses"]["exposed"] = 99
	second._heroes[1]["metadata"]["tags"].clear()
	_check(first.get_heroes() == first_before and carry.read_state() == ledger,
		"second hydrated party HP and nested mutations cannot alias first or ledger")
	_check(map.get_route() == [rest_id] and rng.state == rng_before
		and randi() == expected_random,
		"Rest-only hydration, rejection and opening Block preserve route and run/global RNG")


func _test_witnessed_victory_and_rest() -> void:
	var battle := _battle()
	var party: CombatParty = battle["party"]
	var enemies: CombatEnemies = battle["enemies"]
	var carry := RunPartyCarryover.new(party.get_heroes())
	_check(carry.is_valid(), "carry starts from this real battle party")
	# The actual swap helper proves these living neighbors have an already-legal
	# adjacent exchange; install its proposed authoritative actor records.
	var proposal := CombatPositionSwaps.preview_adjacent_swap(party, 1, 1)
	_check(proposal.get("ok") == true, "real adjacent swap preview is legal")
	if proposal.get("ok") != true:
		return
	party._heroes = proposal["heroes"].duplicate(true)
	_check(party.get_hero(1)["id"] == "seamstress" and party.get_hero(2)["id"] == "warden",
		"authoritative actor order is genuinely exchanged")
	_check(party.apply_damage(2, 23) and party.get_hero(2)["hp"] == 17,
		"Warden is wounded to 17")
	_check(party.gain_block(2, 9) and party.apply_damage(2, 6)
		and party.get_hero(2)["block"] == 3 and party.get_hero(2)["hp"] == 17,
		"combat Block absorbs damage without touching Warden HP")
	_check(party.apply_damage(1, 2) and party.get_hero(1)["hp"] == 28,
		"Seamstress is wounded to 28")
	_check(party.apply_damage(3, 26) and party.is_downed(3) and not party.is_defeated(),
		"Tinker is downed at 0 while two heroes are alive")
	# Existing battle actors own statuses: this fixture injects valid actor-local
	# state because CombatParty has no public status application entrypoint.
	party._heroes[0]["statuses"] = {"exposed": 1}
	party._heroes[1]["statuses"] = {"bleed": 3, "weak": 2}
	party._heroes[2]["statuses"] = {"bleed": 1, "exposed": 4}
	var authoritative := party.get_heroes()
	_check(CombatStatusTurnBatch.new().tick_side("heroes", authoritative)["ok"] == true,
		"injected statuses obey the actual combat status schema")
	_check(battle["result"].get_outcome() == CombatBattleResult.ACTIVE
		and not enemies.is_victorious(), "fight not won before final enemy dies")
	_win(battle)
	var committed := carry.commit_victory("fight_a", battle["result"], party)
	_check(committed.get("ok") == true and committed.get("heroes", []).size() == 3,
		"witnessed victory commits three real heroes")
	var expected := authoritative.duplicate(true)
	for hero in expected:
		hero["block"] = 0
	_check(carry.get_next_fight_heroes() == expected
		and committed.get("heroes") == expected,
		"export matches full authoritative HP/IDs/positions/statuses/metadata minus combat Block")
	_check(carry.get_next_fight_heroes()[0]["id"] == "seamstress"
		and carry.get_next_fight_heroes()[1]["id"] == "warden"
		and carry.get_next_fight_heroes()[2]["hp"] == 0
		and carry.get_next_fight_heroes()[1]["block"] == 0,
		"order survives, Tinker remains downed, stale Warden Block is stripped")
	_check(carry.read_state()["completed_fights"] == ["fight_a"]
		and carry.read_state()["completed_rests"].is_empty(),
		"successful fight recorded once, Rest still open")
	# Two genuine CombatParty instances rehydrate the witnessed formation.
	var ledger_before_hydration := carry.read_state()
	var first_party := carry.create_next_fight_party()
	var second_party := carry.create_next_fight_party()
	_check(first_party != null and second_party != null
		and first_party != second_party and first_party.is_valid() and second_party.is_valid(),
		"witnessed victory constructs two distinct valid CombatParty owners")
	if first_party == null or second_party == null:
		return
	_check(first_party.get_heroes() == expected and second_party.get_heroes() == expected,
		"both parties fully retain HP, downed Tinker, order, statuses and nested metadata")
	_check(carry.read_state() == ledger_before_hydration
		and party.get_heroes() == authoritative,
		"hydration preserves ledger and original authoritative combat roster")
	var new_wave := CombatEnemies.new([{"id": "second_wave", "max_hp": 5}])
	var new_result := CombatBattleResult.new(first_party, new_wave)
	_check(new_wave.is_valid() and new_result.get_outcome() == CombatBattleResult.ACTIVE
		and not first_party.is_defeated(),
		"real new enemy fixture starts a nonterminal ACTIVE battle with a downed Tinker")
	var opening_first := CombatStartingBlock.new(first_party)
	var opening_second := CombatStartingBlock.new(second_party)
	_check(opening_first.apply(), "rehydrated slot-2 Warden gains opening Block")
	var opened := expected.duplicate(true)
	opened[1]["block"] = 6
	_check(first_party.get_heroes() == opened and second_party.get_heroes() == expected,
		"opening +6 hits only slot-2 Warden and does not alias the other battle")
	_check(not opening_first.apply() and first_party.get_heroes() == opened,
		"first battle opening passive cannot replay")
	_check(opening_second.apply() and second_party.get_heroes() == opened
		and not opening_second.apply(),
		"independent second battle has its own one-use 6 Block")
	_check(first_party.apply_damage(2, 7) and first_party.get_hero(2)["hp"] == 16
		and second_party.get_heroes() == opened
		and carry.get_next_fight_heroes() == expected
		and carry.read_state() == ledger_before_hydration,
		"independent battle mutation never aliases the other party or persistent ledger")
	committed["heroes"][1]["statuses"]["bleed"] = 999
	committed["heroes"][1]["metadata"]["tags"][1]["weave"].clear()
	_check(carry.get_next_fight_heroes() == expected,
		"commit result nested mutation does not affect persistent state")
	_assert_rejected(carry, "duplicate fight", func(): return carry.commit_victory("fight_a", battle["result"], party))
	# Independent Rest service is the healing oracle, not a hand-coded
	# alternate implementation. The starting order is now Seamstress/Warden/Tinker.
	var oracle := RunRestRecovery.new(expected)
	var oracle_result: Dictionary = oracle.choose_heal()
	_check(oracle_result.get("ok") == true and oracle.is_consumed(),
		"independent authoritative Rest fixture performs its choice")
	var recovered := carry.choose_rest_heal("rest_a")
	_check(recovered.get("ok") == true, "unique Rest ID accepts heal once")
	_check(recovered.get("heroes") == oracle_result.get("heroes")
		and carry.get_next_fight_heroes() == oracle_result.get("heroes"),
		"actual RunRestRecovery exactly determines carry heal")
	_check(carry.get_next_fight_heroes()[0]["hp"] == 30
		and carry.get_next_fight_heroes()[1]["hp"] == 29
		and carry.get_next_fight_heroes()[2]["hp"] == 8,
		"Seamstress +9 capped 30, Warden 17+12=29, downed Tinker 1+7=8")
	var revived_party := carry.create_next_fight_party()
	_check(revived_party != null and revived_party.is_valid()
		and revived_party.get_heroes() == oracle_result["heroes"]
		and revived_party.get_hero(3)["hp"] == 8,
		"third independent post-Rest CombatParty retains revived Tinker at precisely 8 HP")
	for i in range(3):
		var before_hero: Dictionary = expected[i]
		var after_hero: Dictionary = carry.get_next_fight_heroes()[i]
		_check(after_hero["id"] == before_hero["id"]
			and after_hero["position"] == before_hero["position"]
			and after_hero.get("statuses", {}) == before_hero.get("statuses", {})
			and after_hero["metadata"] == before_hero["metadata"]
			and after_hero["block"] == 0,
			"Rest preserves owner identity, slot, statuses, metadata and zero Block %d" % i)
	_check(carry.read_state()["completed_fights"] == ["fight_a"]
		and carry.read_state()["completed_rests"] == ["rest_a"],
		"distinct Fight and Rest visits recorded")
	recovered["heroes"][2]["hp"] = 999
	recovered["heroes"][0]["statuses"]["exposed"] = 100
	_check(carry.get_next_fight_heroes() == oracle_result["heroes"],
		"Rest result is detached even for nested statuses")
	_assert_rejected(carry, "duplicate Rest", func(): return carry.choose_rest_heal("rest_a"))
	# A distinct Rest node can heal again, capped, without incrementing statuses.
	var second_oracle := RunRestRecovery.new(carry.get_next_fight_heroes())
	var second_expected := second_oracle.choose_heal()
	var second := carry.choose_rest_heal("rest_b")
	_check(second["ok"] and second["heroes"] == second_expected["heroes"],
		"different Rest ID heals exactly once using the same oracle")
	# A legitimate Rest revives Tinker at 1 + floor(26 * 0.3) = 8,
	# without consuming his statuses or changing the carried slot order.
	var third_party := carry.create_next_fight_party()
	var rest_state := carry.get_next_fight_heroes()
	_check(third_party != null and third_party.is_valid()
		and third_party.get_heroes() == rest_state
		and third_party.get_hero(3)["hp"] == 15,
		"second unique Rest adds a further 7 to living Tinker, exactly 15 HP")
	# Now witness another real fight using the service, never manual hydration.
	var next_party := carry.create_next_fight_party()
	_check(next_party != null and next_party.is_valid()
		and next_party.get_heroes() == rest_state,
		"post-Rest new battle starts from the carried snapshot")
	if next_party == null:
		return
	var next_enemies := CombatEnemies.new([{"id": "second_wave", "max_hp": 5}])
	var next_result := CombatBattleResult.new(next_party, next_enemies)
	_check(next_result.get_outcome() == CombatBattleResult.ACTIVE
		and next_party.get_hero(1)["id"] == "seamstress"
		and next_party.get_hero(2)["id"] == "warden"
		and next_party.get_hero(3)["id"] == "tinker",
		"fresh witnessed fight begins with manually rehydrated persistent order")
	_check(next_party.apply_damage(2, 4)
		and next_enemies.apply_damage(1, 5)
		and next_result.evaluate() == CombatBattleResult.VICTORY,
		"second actual battle incurs HP loss and independently witnesses victory")
	var second_fight_expected := next_party.get_heroes()
	var second_fight := carry.commit_victory("fight_b", next_result, next_party)
	_check(second_fight["ok"]
		and carry.read_state()["completed_fights"] == ["fight_a", "fight_b"]
		and carry.read_state()["completed_rests"] == ["rest_a", "rest_b"],
		"subsequent real victory preserves separate, monotonic Fight/Rest histories")
	_check(second_fight["heroes"] == second_fight_expected
		and carry.get_next_fight_heroes()[1]["hp"] == 36
		and carry.get_next_fight_heroes()[1]["statuses"] == expected[1]["statuses"],
		"second fight preserves current HP, actor statuses and every field")



func _assert_rejected(carry: RunPartyCarryover, context: String, action: Callable) -> void:
	var before := carry.read_state()
	var actual: Dictionary = action.call()
	_check(actual == {"ok": false, "heroes": []}, context + ": rejected with no heroes")
	_check(carry.read_state() == before, context + ": full state and visits unchanged")


func _test_failed_and_foreign_results() -> void:
	var battle := _battle()
	var party: CombatParty = battle["party"]
	var result: CombatBattleResult = battle["result"]
	var carry := RunPartyCarryover.new(party.get_heroes())
	_assert_rejected(carry, "unobserved ACTIVE result",
		func(): return carry.commit_victory("fight", result, party))
	_check(battle["enemies"].apply_damage(1, 7) and battle["enemies"].apply_damage(2, 9),
		"kill enemies without observing victory")
	_assert_rejected(carry, "unevaluated result despite dead enemies",
		func(): return carry.commit_victory("fight", result, party))
	_check(result.evaluate() == CombatBattleResult.VICTORY, "valid retry witnesses victory")
	var foreign_party := _party()
	_assert_rejected(carry, "foreign party with same ids",
		func(): return carry.commit_victory("fight", result, foreign_party))
	var foreign_result := CombatBattleResult.new(foreign_party,
		CombatEnemies.new([{"id": "other", "max_hp": 1}]))
	_assert_rejected(carry, "ACTIVE foreign result",
		func(): return carry.commit_victory("fight", foreign_result, party))
	for bad_id in ["", "   ", " bad", "bad ", 5, null, [], {}]:
		_assert_rejected(carry, "malformed Fight ID " + str(bad_id),
			func(): return carry.commit_victory(bad_id, result, party))
		_assert_rejected(carry, "malformed Rest ID " + str(bad_id),
			func(): return carry.choose_rest_heal(bad_id))
	_check(carry.commit_victory("fight", result, party)["ok"]
		and carry.read_state()["completed_fights"] == ["fight"],
		"valid retry after all rejects succeeds exactly once")
	var defeated := _battle()
	var defeated_party: CombatParty = defeated["party"]
	var defeated_carry := RunPartyCarryover.new(defeated_party.get_heroes())
	for i in range(1, 4):
		_check(defeated_party.apply_damage(i, defeated_party.get_hero(i)["hp"]),
			"down a real hero in defeat fixture")
	_check(defeated_party.is_defeated()
		and defeated["result"].evaluate() == CombatBattleResult.DEFEAT,
		"battle result witnesses real DEFEAT with living enemies")
	_assert_rejected(defeated_carry, "DEFEAT result",
		func(): return defeated_carry.commit_victory("fight", defeated["result"], defeated_party))
	_check(defeated_carry.choose_rest_heal("bad")["ok"] == true,
		"living persisted roster still eligible for ordinary Rest after failed fight")


func _test_invalid_and_defeated() -> void:
	var base := _party().get_heroes()
	var bad_cases: Array = []
	var missing := base.duplicate(true)
	missing.pop_back()
	bad_cases.append(missing)
	var duplicate := base.duplicate(true)
	duplicate[1]["id"] = "warden"
	bad_cases.append(duplicate)
	var missing_id := base.duplicate(true)
	missing_id[0]["id"] = 1
	bad_cases.append(missing_id)
	for field in ["position", "hp", "max_hp", "block"]:
		var wrong_type := base.duplicate(true)
		wrong_type[0][field] = 1.5
		bad_cases.append(wrong_type)
	var wrong_slot := base.duplicate(true)
	wrong_slot[0]["position"] = 2
	bad_cases.append(wrong_slot)
	var overflow := base.duplicate(true)
	overflow[1]["hp"] = 31
	bad_cases.append(overflow)
	var negative := base.duplicate(true)
	negative[1]["block"] = -1
	bad_cases.append(negative)
	for status_bad in [{"bleed": -1}, {"weak": 1.5}, {"exposed": "1"},
			{"poison": 1}, {"bleed": 1, "unknown": 0}, []]:
		var invalid_status := base.duplicate(true)
		invalid_status[1]["statuses"] = status_bad
		bad_cases.append(invalid_status)
	var dead := base.duplicate(true)
	for hero in dead:
		hero["hp"] = 0
	bad_cases.append(dead)
	for i in range(bad_cases.size()):
		var invalid := RunPartyCarryover.new(bad_cases[i])
		_check(not invalid.is_valid() and invalid.get_next_fight_heroes().is_empty(),
			"malformed or defeated initial roster %d fails closed" % i)
		_check(invalid.create_next_fight_party() == null,
			"malformed initial roster %d cannot hydrate" % i)
		_check(invalid.read_state()["ok"] == false
			and invalid.choose_rest_heal("rest")["ok"] == false,
			"rejected initial roster has no usable continuation %d" % i)
	var battle := _battle()
	_win(battle)
	var party: CombatParty = battle["party"]
	var result: CombatBattleResult = battle["result"]
	for i in range(bad_cases.size() - 1): # all-downed separately below
		var altered := _battle()
		_win(altered)
		var real_party: CombatParty = altered["party"]
		var carry := RunPartyCarryover.new(real_party.get_heroes())
		real_party._heroes = bad_cases[i].duplicate(true)
		_assert_rejected(carry, "invalid authoritative roster %d" % i,
			func(): return carry.commit_victory("fight", altered["result"], real_party))
		_check(carry.choose_rest_heal("rest")["ok"],
			"valid Rest retry remains possible after invalid fight %d" % i)
	var mismatched := _battle()
	_win(mismatched)
	var mparty: CombatParty = mismatched["party"]
	var mcarry := RunPartyCarryover.new(mparty.get_heroes())
	mparty._heroes[0]["id"] = "intruder"
	_assert_rejected(mcarry, "valid schema but different id",
		func(): return mcarry.commit_victory("fight", mismatched["result"], mparty))
	mparty._heroes[0]["id"] = "warden"
	mparty._heroes[0]["max_hp"] = 41
	_assert_rejected(mcarry, "different max HP",
		func(): return mcarry.commit_victory("fight", mismatched["result"], mparty))
	mparty._heroes[0]["max_hp"] = 40
	_check(mcarry.commit_victory("fight", mismatched["result"], mparty)["ok"],
		"same still-unspent Fight ID is valid after repairing record")
	# Even after a witnessed victory, corrupt persisted actors must never
	# produce a partial or reset CombatParty, or change the visit ledger.
	var safe_held := mcarry.get_next_fight_heroes()
	var rest_carry := RunPartyCarryover.new(base)
	_check(rest_carry.choose_rest_heal("rest_only")["ok"]
		and rest_carry.read_state()["completed_fights"].is_empty()
		and rest_carry.create_next_fight_party() != null,
		"malformed Rest-only fixture first proves valid hydration without a Fight")
	var rest_safe := rest_carry.get_next_fight_heroes()
	var malformed_held: Array = []
	var changed_id := safe_held.duplicate(true)
	changed_id[0]["id"] = "intruder"
	malformed_held.append(changed_id)
	var changed_hp := safe_held.duplicate(true)
	changed_hp[0]["max_hp"] = 31
	malformed_held.append(changed_hp)
	var changed_slot := safe_held.duplicate(true)
	changed_slot[1]["position"] = 3
	malformed_held.append(changed_slot)
	var invalid_status := safe_held.duplicate(true)
	invalid_status[2]["statuses"] = {"bleed": -1}
	malformed_held.append(invalid_status)
	var stale_block := safe_held.duplicate(true)
	stale_block[0]["block"] = 8
	malformed_held.append(stale_block)
	var all_downed := safe_held.duplicate(true)
	for hero in all_downed:
		hero["hp"] = 0
	malformed_held.append(all_downed)
	for i in range(malformed_held.size()):
		var initial_carry := RunPartyCarryover.new(base)
		initial_carry._heroes = malformed_held[i].duplicate(true)
		var initial_before := initial_carry.read_state()
		_check(initial_carry.create_next_fight_party() == null
			and initial_carry.read_state() == initial_before,
			"invalid persisted initial state %d rejects hydration without mutation" % i)
		rest_carry._heroes = malformed_held[i].duplicate(true)
		var rest_before := rest_carry.read_state()
		_check(rest_carry.create_next_fight_party() == null
			and rest_carry.read_state() == rest_before,
			"invalid persisted Rest-only state %d rejects hydration without mutation" % i)
		if malformed_held[i] != stale_block: # Positive Block is rejected by hydration, not Rest.
			_assert_rejected(rest_carry, "malformed Rest-only roster %d" % i,
				func(): return rest_carry.choose_rest_heal("another_rest"))
		mcarry._heroes = malformed_held[i].duplicate(true)
		var held_before := mcarry.read_state()
		var observed_before: String = (mismatched["result"] as CombatBattleResult).get_outcome()
		var combat_before := mparty.get_heroes()
		_check(mcarry.create_next_fight_party() == null
			and mcarry.read_state() == held_before
			and mismatched["result"].get_outcome() == observed_before
			and mparty.get_heroes() == combat_before,
			"invalid persisted hero state %d rejects hydration without mutation" % i)
	rest_carry._heroes = rest_safe.duplicate(true)
	_check(rest_carry.create_next_fight_party() != null,
		"repairing Rest-only persisted roster restores hydration")
	mcarry._heroes = safe_held.duplicate(true)
	_check(mcarry.create_next_fight_party() != null
		and mcarry.get_next_fight_heroes() == safe_held,
		"correcting a malformed held roster restores valid independent construction")
	# Battle result latches victory: it must not license a newly defeated party.
	for i in range(1, 4):
		_check(party.apply_damage(i, party.get_hero(i)["hp"]), "down hero after terminal victory")
	_check(party.is_defeated() and result.get_outcome() == CombatBattleResult.VICTORY,
		"victory latch still reports VICTORY despite current party defeat")
	var defeat_carry := RunPartyCarryover.new(base)
	_assert_rejected(defeat_carry, "latched VICTORY with all heroes down",
		func(): return defeat_carry.commit_victory("fight", result, party))
	# Old downed actors cannot be conjured alive by an unrelated fresh battle.
	var down_battle := _battle()
	var down_party: CombatParty = down_battle["party"]
	var down_roster := down_party.get_heroes()
	down_roster[2]["hp"] = 0
	var down_carry := RunPartyCarryover.new(down_roster)
	_win(down_battle)
	_assert_rejected(down_carry, "downed hero cannot revive on victory",
		func(): return down_carry.commit_victory("fight", down_battle["result"], down_party))
	_check(down_carry.choose_rest_heal("rest")["ok"],
		"Rest can revive the same downed actor after failed victory")


func _replay(seed_value: int) -> Dictionary:
	seed(seed_value)
	var battle := _battle()
	var party: CombatParty = battle["party"]
	var carry := RunPartyCarryover.new(party.get_heroes())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var damage: int = rng.randi_range(2, 10)
	_check(party.apply_damage(1, damage), "seeded replay wounds Warden")
	party._heroes[0]["statuses"] = {"weak": rng.randi_range(1, 4)}
	_win(battle)
	var fight := carry.commit_victory("one", battle["result"], party)
	var rest := carry.choose_rest_heal("camp")
	_check(fight["ok"] and rest["ok"], "replay actually commits a victory and a Rest")
	return {"state": carry.read_state(), "fight": fight, "rest": rest,
		"rng": [rng.state, damage]}


func _test_seeded_replay_and_rng() -> void:
	var first := _replay(39591)
	var second := _replay(39591)
	_check(first == second, "independent fixed-seed real battles agree on HP, statuses, visits, output and RNG")
	_check(first["state"]["completed_fights"] == ["one"]
		and first["state"]["completed_rests"] == ["camp"],
		"replay covers both real node transitions, not a vacuous comparison")
	seed(82049)
	var expected_next := randi()
	seed(82049)
	var battle := _battle()
	var party: CombatParty = battle["party"]
	var carry := RunPartyCarryover.new(party.get_heroes())
	var active_result: CombatBattleResult = battle["result"]
	var start := carry.read_state()
	_check(not carry.commit_victory("fight", active_result, party)["ok"]
		and carry.read_state() == start, "RNG test includes rejected ACTIVE result")
	_win(battle)
	_check(carry.commit_victory("fight", active_result, party)["ok"]
		and carry.choose_rest_heal("rest")["ok"], "RNG test includes accepted transitions")
	var before_hydrate := carry.read_state()
	var hydrated := carry.create_next_fight_party()
	_check(hydrated != null and hydrated.is_valid()
		and hydrated.get_heroes() == before_hydrate["heroes"],
		"RNG fixture builds the real next-fight party from Rest")
	var opening := CombatStartingBlock.new(hydrated)
	_check(opening.apply() and not opening.apply()
		and hydrated.get_hero(1)["block"] == 6
		and carry.read_state() == before_hydrate,
		"RNG fixture grants one-time opening Block without changing carry")
	var after := carry.read_state()
	_check(not carry.commit_victory("fight", active_result, party)["ok"]
		and not carry.choose_rest_heal("rest")["ok"]
		and carry.read_state() == after, "RNG test also includes duplicate rejects")
	_check(randi() == expected_next, "success and rejection consume no global RNG")


func _test_coat_torn_carryover() -> void:
	var carry := RunTornCarryover.new(_party().get_heroes())
	var coats: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m04_coat_patches.json"))
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/initial_patch_slots.json"))
	for coat in coats:
		definitions.append({"id": coat.id, "slot": coat.slot})
	definitions.append({"id": "replacement", "slot": "COAT"})
	var wardrobe := RunPatchWardrobe.new(carry.get_next_fight_heroes(),
		["quilted_coat", "replacement"], definitions, 0, 0, [], 97, true)
	_check(wardrobe.is_valid() and carry.is_valid(), "coat fixture uses real valid ledgers")
	_check(wardrobe.sew("quilted_coat", "warden", "COAT", "sew", wardrobe.get_snapshot()).ok,
		"owned authored coat sews before binding")
	var before := [carry.read_state(), carry.torn.read_state(), wardrobe.get_snapshot()]
	var foreign_owner := RunTornMending.new(_party().get_heroes())
	_check(not carry.bind_wardrobe(wardrobe, foreign_owner, wardrobe.get_snapshot())
		and carry._wardrobe == null, "equivalent but foreign torn owner cannot bind")
	var stale := wardrobe.get_snapshot()
	stale.gold += 1
	_check(not carry.bind_wardrobe(wardrobe, carry.torn, stale)
		and [carry.read_state(), carry.torn.read_state(), wardrobe.get_snapshot()] == before,
		"stale binding preserves all ledgers")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()), "exact live wardrobe binds")
	var other := RunPatchWardrobe.new(carry.get_next_fight_heroes(), ["quilted_coat"], definitions, 0, 0, [], 97, true)
	_check(not carry.bind_wardrobe(other, carry.torn, other.get_snapshot()) and carry._wardrobe == wardrobe,
		"foreign wardrobe cannot replace live binding")
	seed(970097)
	var next_random := randi()
	seed(970097)
	for battle_index in range(4):
		var party := carry.create_next_fight_party()
		_check(party != null and party.is_valid(), "coat continuation creates actual party %d" % battle_index)
		if party == null:
			return
		var held := carry.read_state()
		var expected: Array = held.heroes.duplicate(true)
		if battle_index in [0, 2]:
			expected[0].max_hp += 6
		_check(party.get_heroes() == expected, "projection is exact, no healing or stacked cap %d" % battle_index)
		var enemies := CombatEnemies.new([{"id": "coat_target", "max_hp": 1}])
		var result := CombatBattleResult.new(party, enemies)
		var node := "coat_battle_%d" % battle_index
		party._heroes[0].max_hp += 1
		_check(not carry.begin_battle(node, result, party) and carry.read_state() == held,
			"forged admission cap fails without mutation")
		party._heroes[0].max_hp -= 1
		_check(carry.begin_battle(node, result, party), "repaired admission succeeds")
		if battle_index == 0:
			_check(party.apply_damage(1, 999), "wearer really becomes torn in combat")
		elif battle_index == 1:
			_check(party.get_hero(1).hp == 0 and party.get_hero(1).max_hp == 37
				and not party.heal(1, 999), "torn coat is inactive and combat heal cannot revive")
		elif battle_index == 2:
			_check(party.heal(1, 999) and party.get_hero(1).hp == 43,
				"legitimate revived wearer heals only to torn base plus six")
			var moved := CombatPositionSwaps.preview_adjacent_swap(party, 1, 1)
			_check(moved.ok, "coat fixture actually permutes wearer")
			if moved.ok:
				party._heroes.assign(moved.heroes)
		_check(enemies.apply_damage(1, 1) and result.evaluate() == CombatBattleResult.VICTORY,
			"coat battle witnesses real surviving victory")
		var foreign_party := carry.create_next_fight_party()
		_check(carry.preview_reward(node, result, foreign_party) == null
			and not carry.commit_victory(node, result, foreign_party).ok, "foreign battle party cannot settle")
		var raw := party.get_heroes()
		party._heroes[0].max_hp += 1
		_check(carry.preview_reward(node, result, party) == null
			and not carry.commit_victory(node, result, party).ok and carry.read_state() == held,
			"forged terminal cap fails before commit")
		party._heroes.assign(raw)
		_check(carry.preview_reward(node, result, party) != null
			and carry.commit_victory(node, result, party).ok
			and carry.apply_reward(node, result, party).ok, "valid settlement retry publishes base torn state")
		var settled := [carry.read_state(), carry.torn.read_state(), carry._receipts.duplicate(true)]
		_check(not carry.commit_victory(node, result, party).ok and not carry.apply_reward(node, result, party).ok
			and [carry.read_state(), carry.torn.read_state(), carry._receipts] == settled,
			"repeated callbacks cannot stack bonus or tear")
		var wearer: Dictionary = carry.get_next_fight_heroes().filter(func(h): return h.id == "warden")[0]
		_check(wearer.max_hp == 37 and carry.torn.read_state().tear_counts.warden == 1,
			"base tear counted once, coat never persisted")
		if battle_index == 1:
			_check(carry.choose_rest_heal("coat_rest").ok, "authoritative Rest legitimately revives wearer")
		elif battle_index == 2:
			_check(wearer.hp == 37 and wearer.position == 2, "settlement clamps over-base HP by moved identity")
			_check(wardrobe.sew("replacement", "warden", "COAT", "replace", wardrobe.get_snapshot()).ok,
				"legitimate replacement removes worn coat")
	_check(randi() == next_random, "projection, battle admission, settlement and rejection use no global RNG")
	carry.clear_wardrobe(wardrobe)
	_check(carry._wardrobe == null and carry.create_next_fight_party().get_heroes() == carry.get_next_fight_heroes(),
		"clearing binding removes projection entirely")
