extends SceneTree

var failures: Array[String] = []
var checks := 0

const HEROES_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/starter_enemies.json"
const INTENTS_PATH := "res://data/encounters/starter_attacks.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_special_round_atomicity()
	_test_lazy_coordinator_variants()
	_test_lazy_coordinator_combo()
	_test_lazy_coordinator_rejections()
	_test_bound_reaction_rounds()
	_test_bound_reaction_movement_and_skips()
	_test_bound_reaction_rejections_and_replay()
	_test_opening_and_rounds()
	_test_path_openings()
	_test_terminal_victory()
	_test_terminal_defeat()
	_test_rejections()
	_test_additional_boundaries()
	_test_seeded_replay()
	_test_status_turns()
	_test_enemy_status_turns()
	_test_status_damage()
	_test_reordered_status_turn()
	await _test_mounted_enemy_status_turn()
	if failures.is_empty():
		print("combat_round_flow_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_round_flow_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_json(path: String) -> Array:
	var contents := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(contents)
	_check(not contents.is_empty() and parsed is Array and not parsed.is_empty(),
		"actual authored file loads as nonempty array: " + path)
	if parsed is Array:
		# JSON.parse_string decodes JSON numbers as float; the existing
		# combat constructors deliberately demand typed integer values.
		# Mirror the app's numeric normalization for the *authored* files.
		for entry in parsed:
			if not entry is Dictionary:
				continue
			for field in ["max_hp", "enemy_position"]:
				if entry.has(field) and entry[field] is float:
					entry[field] = int(entry[field])
			if entry.has("pattern") and entry["pattern"] is Array:
				for action in entry["pattern"]:
					if action is Dictionary:
						for field in ["amount", "target_position"]:
							if action.has(field) and action[field] is float:
								action[field] = int(action[field])
		return parsed
	return []


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _fight(seed_value: int = 509, hero_defs: Array = [],
		enemy_defs: Array = [], intent_defs: Array = [],
		path_receipt: Variant = null) -> Dictionary:
	if hero_defs.is_empty():
		hero_defs = _load_json(HEROES_PATH)
	if enemy_defs.is_empty():
		enemy_defs = _load_json(ENEMIES_PATH)
	if intent_defs.is_empty():
		intent_defs = _load_json(INTENTS_PATH)
	var cards := StarterCards.new().get_starting_deck()
	var rng := _rng(seed_value)
	var deck := CombatDeck.new(cards, rng)
	var party := CombatParty.new(hero_defs)
	var enemies := CombatEnemies.new(enemy_defs)
	var scheduler := CombatEnemyIntents.new(intent_defs)
	var result := CombatBattleResult.new(party, enemies)
	# Keep exercising the untouched legacy constructor for unselected runs.
	var flow: CombatRoundFlow
	if path_receipt == null:
		flow = CombatRoundFlow.new(deck, party, enemies, scheduler, result)
	else:
		flow = CombatRoundFlow.new(deck, party, enemies, scheduler, result,
			null, null, path_receipt)
	return {"deck": deck, "rng": rng, "party": party, "enemies": enemies,
		"intents": scheduler, "result": result, "flow": flow, "cards": cards}


func _preconditions(fight: Dictionary) -> void:
	var party: CombatParty = fight["party"]
	var enemies: CombatEnemies = fight["enemies"]
	var scheduler: CombatEnemyIntents = fight["intents"]
	var deck: CombatDeck = fight["deck"]
	_check(party.is_valid() and party.get_heroes().size() == 3
		and party.get_hero(1)["id"] == "warden" and party.get_hero(1)["hp"] == 40
		and party.get_hero(2)["id"] == "seamstress" and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["id"] == "tinker" and party.get_hero(3)["hp"] == 26,
		"three actual authored and living heroes occupy fixed slots 1-3")
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2
		and enemies.get_enemy(1)["id"] == "ragling" and enemies.get_enemy(1)["hp"] == 12
		and enemies.get_enemy(2)["id"] == "ragling_guard"
		and enemies.get_enemy(2)["hp"] == 12,
		"both actual encounter enemies occupy fixed slots 1-2 at HP12")
	_check(scheduler.is_valid() and scheduler.get_intents() == [
		{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 1},
		{"enemy_position": 2, "type": "block", "amount": 1}],
		"precondition: authored fixed-cycle attack and Block are announced")
	_check(deck.draw_pile.size() == fight["cards"].size() and deck.energy == 0
		and deck.hand.is_empty() and deck.discard_pile.is_empty()
		and fight["result"].get_outcome() == CombatBattleResult.ACTIVE,
		"seeded real shared deck shuffled once and battle is initially active")
	var original: Array = fight["cards"].duplicate()
	original.sort()
	for required in ["warden_strike", "warden_brace", "warden_shield_bash",
			"seamstress_prick", "seamstress_mend", "seamstress_stitch_up",
			"tinker_pop_shot", "tinker_scrap_bomb", "tinker_tune_up"]:
		_check(original.has(required), "authored shared deck includes " + required)


func _deck_snapshot(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(),
		deck.discard_pile.duplicate(), deck.energy, deck.turn_active,
		deck.combat_state.energy, deck.combat_state.player_turn_active,
		deck._rng.state]


func _snapshot(fight: Dictionary) -> Array:
	var flow: CombatRoundFlow = fight["flow"]
	var party: CombatParty = fight["party"]
	var enemies: CombatEnemies = fight["enemies"]
	var intents: CombatEnemyIntents = fight["intents"]
	var result: CombatBattleResult = fight["result"]
	var deck: CombatDeck = fight["deck"]
	return [party.get_heroes(), enemies.get_enemies(), _deck_snapshot(deck),
		intents.get_intents(), intents._turn_index, result.get_outcome(),
		flow._started, flow._opening_block._consumed]


func _conserved(fight: Dictionary) -> void:
	var deck: CombatDeck = fight["deck"]
	var actual: Array = []
	actual.append_array(deck.draw_pile)
	actual.append_array(deck.hand)
	actual.append_array(deck.discard_pile)
	actual.sort()
	var original: Array = fight["cards"].duplicate()
	original.sort()
	_check(actual == original, "every original shared card copy remains in exactly one pile")


func _reject(fight: Dictionary, action: Callable, name: String) -> void:
	var before := _snapshot(fight)
	_check(not action.call(), name + " returns false")
	_check(_snapshot(fight) == before, name + " leaves all actors, piles, energy, "
		+ "intent index, result, opening latch and RNG unchanged")


func _test_opening_and_rounds() -> void:
	var fight := _fight()
	_preconditions(fight)
	var flow: CombatRoundFlow = fight["flow"]
	var deck: CombatDeck = fight["deck"]
	var party: CombatParty = fight["party"]
	var enemies: CombatEnemies = fight["enemies"]
	var intents: CombatEnemyIntents = fight["intents"]
	var oracle := CombatDeck.new(StarterCards.new().get_starting_deck(), _rng(509))
	_check(flow.has_method("begin_fight") and flow.has_method("end_turn")
		and flow.has_method("observe_result"), "all three public coordinator operations exist")
	_reject(fight, flow.end_turn, "never-begun end")
	var before := _snapshot(fight)
	_check(flow.observe_result() == CombatBattleResult.UNRESOLVED
		and _snapshot(fight) == before, "never-begun observation is inert")
	_check(flow.begin_fight(), "first fight begins exactly once")
	_check(oracle.start_turn(), "independent deck cadence starts once")
	_check(_deck_snapshot(deck) == _deck_snapshot(oracle) and deck.hand.size() == 5
		and deck.energy == 3, "opening hand, energy, piles and RNG equal deck oracle")
	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 6
		and party.get_hero(2)["hp"] == 30 and party.get_hero(2)["block"] == 0
		and party.get_hero(3)["hp"] == 26 and party.get_hero(3)["block"] == 0,
		"opening Warden receives exactly one +6 after player Block reset")
	_check(intents._turn_index == 0 and intents.get_intents()[0]["target_position"] == 1,
		"no advance before first enemy phase")
	before = _snapshot(fight)
	_check(flow.observe_result() == CombatBattleResult.ACTIVE
		and _snapshot(fight) == before, "active observation reads outcome without mutations")
	_reject(fight, flow.begin_fight, "duplicate begin")
	_conserved(fight)

	var rng_after_opening: int = deck._rng.state
	for turn in range(1, 9):
		var prior_rng: int = deck._rng.state
		_check(flow.end_turn(), "end turn %d resolves one phase" % turn)
		_check(oracle.end_turn() and oracle.start_turn(), "oracle deck turn %d" % turn)
		_check(_deck_snapshot(deck) == _deck_snapshot(oracle)
			and deck.hand.size() == 5 and deck.energy == 3 and deck.turn_active,
			"turn %d exact hand/piles, energy and injected RNG match independent oracle" % turn)
		_check(intents._turn_index == turn and
			intents.get_intents()[0]["target_position"] == (turn % 3 + 1),
			"turn %d advances once to the next fixed-cycle announced attack" % turn)
		_check(enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(1)["block"] == 0
			and enemies.get_enemy(2)["hp"] == 12 and enemies.get_enemy(2)["block"] == turn,
			"turn %d executes exactly one Block for living guard" % turn)
		var warden_hits := (turn + 2) / 3
		var seamstress_hits := (turn + 1) / 3
		var tinker_hits := turn / 3
		_check(party.get_hero(1)["hp"] == 40 - maxi(0, int(warden_hits) - 1)
			and party.get_hero(1)["block"] == 0
			and party.get_hero(2)["hp"] == 30 - int(seamstress_hits)
			and party.get_hero(2)["block"] == 0
			and party.get_hero(3)["hp"] == 26 - int(tinker_hits) and party.get_hero(3)["block"] == 0,
			"turn %d resolves one point attack, opening Block once, then resets hero Block" % turn)
		_check(flow.get_outcome() == CombatBattleResult.ACTIVE
			and flow.observe_result() == CombatBattleResult.ACTIVE,
			"turn %d remains active and observable" % turn)
		_conserved(fight)
		if turn == 1:
			_check(party.get_hero(1)["hp"] == 40 and enemies.get_enemy(2)["block"] == 1,
				"AC2 first attack fully absorbed by opening Block and guard gains 1")
			_check(deck._rng.state == rng_after_opening and deck.draw_pile.size() == 2
				and deck.discard_pile.size() == 5,
				"first end is a 7-to-2 draw with no premature reshuffle")
		if turn == 2:
			_check(party.get_hero(2)["hp"] == 29 and enemies.get_enemy(2)["block"] == 2,
				"AC2 second attack hits Seamstress exactly once")
			_check(deck._rng.state != prior_rng and deck.draw_pile.size() == 7
				and deck.discard_pile.is_empty(),
				"second end genuinely refills 10 discarded cards with seeded shuffle")


func _test_path_openings() -> void:
	# Actual authored claims, not synthetic mode flags, drive each seeded fight.
	var bulwark := RunWardenPathChoice.new().choose("bulwark")
	var vanguard := RunWardenPathChoice.new().choose("vanguard")
	_check(bulwark.get("ok") == true and bulwark.get("path_id") == "bulwark"
		and vanguard.get("ok") == true and vanguard.get("path_id") == "vanguard",
		"both positive fixtures are genuine single-claim Warden Path receipts")
	var options: Array[Dictionary] = [
		{"name": "unselected", "receipt": null, "block": 6},
		{"name": "bulwark", "receipt": bulwark, "block": 10},
		{"name": "vanguard", "receipt": vanguard, "block": 0},
	]
	for option in options:
		var name: String = option["name"]
		var amount: int = option["block"]
		var fight := _fight(42617, [], [], [], option["receipt"])
		_preconditions(fight)
		var party: CombatParty = fight["party"]
		var deck: CombatDeck = fight["deck"]
		var flow: CombatRoundFlow = fight["flow"]
		var intents: CombatEnemyIntents = fight["intents"]
		var enemies: CombatEnemies = fight["enemies"]
		var oracle := CombatDeck.new(fight["cards"], _rng(42617))
		_check(party.gain_block(1, 4) and party.gain_block(2, 2)
			and party.gain_block(3, 3), name + " starts with genuine inherited hero Block")
		var expected_heroes := party.get_heroes()
		for hero in expected_heroes:
			hero["block"] = 0
		expected_heroes[0]["block"] = amount
		var original_enemies := enemies.get_enemies()
		var original_intents := intents.get_intents()
		seed(42617)
		var global_next := randi()
		seed(42617)
		_check(flow.begin_fight() and oracle.start_turn(),
			name + " seeded admission and independent first turn succeed")
		_check(party.get_heroes() == expected_heroes
			and flow._opening_block.is_consumed(),
			name + " resets inherited Block then applies exactly " + str(amount)
			+ " Warden opening Block once; no other actor or status changes")
		_check(_deck_snapshot(deck) == _deck_snapshot(oracle)
			and deck.hand.size() == 5 and deck.energy == 3,
			name + " opens with five exact seeded cards, three energy and matching RNG")
		_check(enemies.get_enemies() == original_enemies
			and intents.get_intents() == original_intents and intents._turn_index == 0
			and fight["result"].get_outcome() == CombatBattleResult.ACTIVE,
			name + " leaves enemy roster, turn-zero intent and result unchanged")
		_check(randi() == global_next, name + " opening consumes no global RNG")
		_reject(fight, flow.begin_fight, name + " duplicate battle entry")
		_check(flow.end_turn() and oracle.end_turn() and oracle.start_turn(),
			name + " commits first enemy phase and next seeded draw")
		_check(_deck_snapshot(deck) == _deck_snapshot(oracle)
			and deck.hand.size() == 5 and deck.energy == 3
			and intents._turn_index == 1,
			name + " continues with exact seeded turn cadence")
		_check(party.get_hero(1)["hp"] == (39 if name == "vanguard" else 40)
			and party.get_hero(1)["block"] == 0
			and party.get_hero(2)["hp"] == 30 and party.get_hero(2)["block"] == 0
			and party.get_hero(3)["hp"] == 26 and party.get_hero(3)["block"] == 0
			and flow._opening_block.is_consumed(),
			name + " absorbs opening attack iff it had Block and never re-grants it")
		_reject(fight, flow.begin_fight, name + " reentry after turn transition")
		_conserved(fight)

		# A downed Warden does not block an otherwise legitimate fight start.
		var downed := _fight(42618, [], [], [], option["receipt"])
		var downed_party: CombatParty = downed["party"]
		_check(downed_party.apply_damage(1, 40)
			and downed_party.is_downed(1) and not downed_party.is_defeated(),
			name + " downed fixture keeps two other living heroes")
		var downed_heroes := downed_party.get_heroes()
		var downed_oracle := CombatDeck.new(downed["cards"], _rng(42618))
		_check(downed["flow"].begin_fight() and downed_oracle.start_turn()
			and downed_party.get_heroes() == downed_heroes
			and downed_party.get_hero(1)["block"] == 0
			and not downed["flow"]._opening_block.is_consumed(),
			name + " starts a genuine downed-Warden fight without opening grant")
		_check(_deck_snapshot(downed["deck"]) == _deck_snapshot(downed_oracle)
			and downed["deck"].hand.size() == 5 and downed["deck"].energy == 3
			and downed["intents"]._turn_index == 0,
			name + " downed admission preserves the same seed and turn-zero intents")
		_reject(downed, downed["flow"].begin_fight, name + " downed duplicate begin")

	# Rejections must occur before clearing even inherited Block, drawing cards,
	# advancing an intent, latching a result, or spending either RNG.
	var forged_block := bulwark.duplicate(true)
	forged_block["passive"]["starting_block"] = 16
	var forged_vanguard := vanguard.duplicate(true)
	forged_vanguard["passive"]["once_per_turn"] = false
	var wrong_owner := bulwark.duplicate(true)
	wrong_owner["owner"] = "tinker"
	var wrong_path := bulwark.duplicate(true)
	wrong_path["path_id"] = "vanguard"
	var claimant := RunWardenPathChoice.new()
	_check(claimant.choose("vanguard").get("ok") == true,
		"invalid replay receipt comes from a previously successful real claim")
	var replayed := claimant.choose("vanguard")
	var bad_receipts: Array[Dictionary] = [
		{"name": "tampered Bulwark", "receipt": forged_block},
		{"name": "tampered Vanguard", "receipt": forged_vanguard},
		{"name": "foreign Warden owner", "receipt": wrong_owner},
		{"name": "wrong Path identity", "receipt": wrong_path},
		{"name": "replayed claim", "receipt": replayed},
		{"name": "non-dictionary", "receipt": "vanguard"},
		{"name": "empty receipt", "receipt": {}},
	]
	for bad in bad_receipts:
		var refused := _fight(42619, [], [], [], bad["receipt"])
		_preconditions(refused)
		_check(refused["party"].gain_block(1, 4)
			and refused["party"].get_hero(1)["block"] == 4,
			bad["name"] + " refusal has meaningful inherited Block to preserve")
		_reject_invalid(refused, bad["name"] + " optional Path receipt")
		_check(refused["party"].get_hero(1)["block"] == 4,
			bad["name"] + " rejected before Block reset")

	# A structurally sized but non-authored Warden must not silently begin
	# without a grant (the standalone helper already rejects that identity).
	var wrong_hp := _fight(42620, [], [], [], bulwark)
	wrong_hp["party"]._heroes[0]["max_hp"] = 41
	_check(wrong_hp["party"].is_valid(), "wrong-HP party is structurally three actors")
	_reject_invalid(wrong_hp, "non-authored Warden max HP")


func _test_terminal_victory() -> void:
	var fight := _fight(817)
	_preconditions(fight)
	var flow: CombatRoundFlow = fight["flow"]
	var enemies: CombatEnemies = fight["enemies"]
	_check(flow.begin_fight() and flow.end_turn(), "victory fixture has a real active second turn")
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1)
		and not enemies.is_victorious(), "first actual enemy is slain; guard still survives")
	var before := _snapshot(fight)
	_check(flow.observe_result() == CombatBattleResult.ACTIVE
		and _snapshot(fight) == before, "one enemy slain leaves fight active without mutations")
	_check(enemies.apply_damage(2, 13) and enemies.is_victorious()
		and enemies.get_enemy(2)["position"] == 2,
		"second enemy dies through its real 1 Block and HP, retains original slot")
	var party_before = fight["party"].get_heroes()
	var enemy_before = enemies.get_enemies()
	var deck_before = _deck_snapshot(fight["deck"])
	var intents_before = fight["intents"].get_intents()
	_check(flow.observe_result() == CombatBattleResult.VICTORY
		and fight["result"].get_outcome() == CombatBattleResult.VICTORY
		and fight["party"].get_heroes() == party_before
		and enemies.get_enemies() == enemy_before
		and _deck_snapshot(fight["deck"]) == deck_before
		and fight["intents"].get_intents() == intents_before,
		"victory observation latches without changing actors, deck, scheduler or RNG")
	_reject(fight, flow.end_turn, "victory end")
	_reject(fight, flow.begin_fight, "victory begin")
	before = _snapshot(fight)
	_check(flow.observe_result() == CombatBattleResult.VICTORY
		and _snapshot(fight) == before, "repeated victory read cannot restart play")


func _test_terminal_defeat() -> void:
	var fight := _fight(910)
	_preconditions(fight)
	var flow: CombatRoundFlow = fight["flow"]
	var party: CombatParty = fight["party"]
	_check(flow.begin_fight(), "defeat fixture starts seeded shared fight")
	_check(party.apply_damage(1, 46) and party.is_downed(1)
		and party.apply_damage(2, 30) and party.is_downed(2)
		and not party.is_defeated(), "two genuine hero deaths leave living Tinker")
	var before := _snapshot(fight)
	_check(flow.observe_result() == CombatBattleResult.ACTIVE
		and _snapshot(fight) == before, "two downed heroes do not finish the fight")
	_check(party.apply_damage(3, 26) and party.is_defeated()
		and party.get_hero(1)["position"] == 1 and party.get_hero(2)["position"] == 2
		and party.get_hero(3)["position"] == 3, "third hero death keeps fixed party slots")
	var before_observe := _snapshot(fight)
	_check(flow.observe_result() == CombatBattleResult.DEFEAT
		and fight["result"].get_outcome() == CombatBattleResult.DEFEAT
		and party.get_heroes() == before_observe[0]
		and fight["enemies"].get_enemies() == before_observe[1]
		and _deck_snapshot(fight["deck"]) == before_observe[2]
		and fight["intents"].get_intents() == before_observe[3],
		"defeat observation latches without touching players, enemies, deck or scheduler")
	_reject(fight, flow.end_turn, "defeat end")
	_reject(fight, flow.begin_fight, "defeat begin")
	before = _snapshot(fight)
	_check(flow.observe_result() == CombatBattleResult.DEFEAT
		and _snapshot(fight) == before, "repeated defeat observation remains inert")


func _reject_invalid(fight: Dictionary, name: String) -> void:
	var before := _snapshot(fight)
	var flow: CombatRoundFlow = fight["flow"]
	_check(not flow.begin_fight(), name + " refuses to begin")
	_check(_snapshot(fight) == before, name + " preserves all supplied models and RNG")
	_check(not flow.end_turn() and _snapshot(fight) == before,
		name + " cannot execute a never-started enemy phase")


func _test_rejections() -> void:
	var alternate_defs := _load_json(HEROES_PATH)
	alternate_defs[0].id = "alternate_front"
	var alternate := _fight(39, alternate_defs)
	_check(alternate["party"].is_valid() and alternate["party"].get_hero(1)["id"] == "alternate_front",
		"replacement-front negative remains otherwise structurally valid")
	_reject_invalid(alternate, "substituted Warden cannot start authored initial trio")
	for slots in [[1, 0, 2], [0, 2, 1], [2, 1, 0]]:
		var authored := _load_json(HEROES_PATH)
		var reordered := _fight(39, [authored[slots[0]], authored[slots[1]], authored[slots[2]]])
		var warden_slot: int = slots.find(0) + 1
		_check(reordered["party"].is_valid() and reordered["party"].get_hero(warden_slot)["id"] == "warden",
			"permutation contains the authored Warden at his present slot")
		var oracle := CombatDeck.new(reordered["cards"], _rng(39))
		_check(reordered["flow"].begin_fight() and oracle.start_turn(),
			"unique authored permutation starts successfully")
		for position in range(1, 4):
			_check(reordered["party"].get_hero(position)["block"] == (6 if position == warden_slot else 0),
				"only current Warden position receives six Block")
		_check(reordered["deck"].hand == oracle.hand and reordered["deck"].energy == 3
			and _deck_snapshot(reordered["deck"]) == _deck_snapshot(oracle),
			"permuted opening uses the same seeded draw and three energy")
		_reject(reordered, reordered["flow"].begin_fight, "permuted repeat opening")
	var mismatched := _fight(40, [], [], [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 1}]}])
	_check(mismatched["intents"].is_valid() and mismatched["enemies"].get_enemies().size() == 2,
		"missing-source negative fixture is a genuinely valid but mismatched schedule")
	_reject_invalid(mismatched, "missing enemy 2 scheduler")
	var phantom := _fight(41, [], [], [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 3, "pattern": [{"type": "block", "amount": 1}]}])
	_check(phantom["intents"].is_valid(), "phantom-slot schedule independently valid")
	_reject_invalid(phantom, "gap and phantom enemy 3")
	var invalid_schedule := _fight(43, [], [], [
		{"enemy_position": 1, "pattern": []}])
	_check(not invalid_schedule["intents"].is_valid(), "invalid scheduler is really invalid")
	_reject_invalid(invalid_schedule, "malformed scheduler")
	var wrong_result := _fight(44)
	var other := _fight(44)
	wrong_result["flow"] = CombatRoundFlow.new(wrong_result["deck"],
		wrong_result["party"], wrong_result["enemies"], wrong_result["intents"], other["result"])
	_check(wrong_result["result"].can_continue() and other["result"].can_continue(),
		"mismatched result observes a separate otherwise-active fight")
	_reject_invalid(wrong_result, "outcome bound to another roster")
	var prior_deck := _fight(45)
	_check(prior_deck["deck"].start_turn(), "external deck begins before coordinator")
	_reject_invalid(prior_deck, "already active shared deck")
	var old_deck := _fight(46)
	_check(old_deck["deck"].start_turn() and old_deck["deck"].end_turn()
		and not old_deck["deck"].discard_pile.is_empty(),
		"used shared deck has discard pile despite inactive turn")
	_reject_invalid(old_deck, "previously used shared deck")
	var exhausted := _fight(47)
	_check(exhausted["flow"].begin_fight(), "external-closed deck test first begins")
	_check(exhausted["deck"].end_turn(), "external actor closes original deck turn")
	_reject(exhausted, exhausted["flow"].end_turn, "duplicate/external close")
	var unobserved := _fight(48)
	_check(unobserved["flow"].begin_fight()
		and unobserved["enemies"].apply_damage(1, 12)
		and unobserved["enemies"].apply_damage(2, 12),
		"unobserved victory fixture has both enemies truly dead")
	var actors_before = unobserved["party"].get_heroes()
	var deck_before = _deck_snapshot(unobserved["deck"])
	var intents_before = unobserved["intents"].get_intents()
	_check(not unobserved["flow"].end_turn()
		and unobserved["result"].get_outcome() == CombatBattleResult.VICTORY
		and unobserved["party"].get_heroes() == actors_before
		and _deck_snapshot(unobserved["deck"]) == deck_before
		and unobserved["intents"].get_intents() == intents_before,
		"unobserved lethal action fails closed before enemy action or hand discard")
	var null_flow := CombatRoundFlow.new()
	_check(not null_flow.begin_fight() and not null_flow.end_turn()
		and null_flow.observe_result() == CombatBattleResult.UNRESOLVED,
		"unbound coordinator is entirely inert")


func _trace(seed_value: int) -> Array:
	var fight := _fight(seed_value)
	_preconditions(fight)
	var flow: CombatRoundFlow = fight["flow"]
	var history: Array = []
	_check(flow.begin_fight(), "seeded replay fight begins")
	history.append(_snapshot(fight))
	for turn in range(7):
		_check(flow.end_turn(), "seeded replay successful turn %d" % turn)
		history.append(_snapshot(fight))
	return history


func _test_seeded_replay() -> void:
	var first := _trace(271828)
	var second := _trace(271828)
	_check(first.size() == 8 and second.size() == 8
		and first == second, "fresh identical seeded fights replay all actors, piles, "
		+ "energy, intent indices, observed results, opening latch and RNG exactly")
	_check(first[0][2] != first[2][2] and first[1][4] == 1
		and first[2][4] == 2, "trace truly progresses through refills and announcements")


func _test_status_turns() -> void:
	var replay: Array = []
	for session in range(2):
		var fight := _fight(509)
		var flow: CombatRoundFlow = fight["flow"]
		var party: CombatParty = fight["party"]
		_check(flow.begin_fight(), "status fixture begins real seeded fight")
		var hero: Dictionary = party._heroes[0]
		hero["statuses"] = {"bleed": 2, "weak": 2, "exposed": 1}
		hero["fixture_metadata"] = {"kept": [1, 2]}
		var expected := party.get_heroes()
		expected[0]["hp"] = 38
		expected[0]["block"] = 0
		expected[0]["statuses"] = {"bleed": 1, "weak": 1}
		_check(flow.end_turn() and party.get_heroes() == expected,
			"Bleed bypasses opening Block, ages statuses and preserves every other hero field")
		_check(hero == expected[0], "accepted tick updates existing authoritative dictionary reference")
		var trace: Array = [_snapshot(fight)]
		_check(party.apply_damage(1, 999) and party.apply_damage(2, 999),
			"terminal status fixture downs first two heroes")
		party._heroes[2]["hp"] = 2
		party._heroes[2]["block"] = 9
		party._heroes[2]["statuses"] = {"bleed": 2}
		var before := _snapshot(fight)
		_check(flow.end_turn() and flow.get_outcome() == CombatBattleResult.DEFEAT,
			"final living hero Bleed freezes defeat")
		var after := _snapshot(fight)
		_check(party.get_hero(3)["hp"] == 0 and party.get_hero(3)["block"] == 9
			and party.get_hero(3)["statuses"] == {"bleed": 1}
			and after[1] == before[1] and after[3] == before[3] and after[4] == before[4]
			and after[2][0] == before[2][0] and after[2][1] == []
			and after[2][2] == before[2][2] + before[2][1]
			and after[2][3] == 0 and not after[2][4] and after[2][7] == before[2][7],
			"status defeat discards exactly once without enemy Block, reset, intent advance or RNG/draw")
		_reject(fight, flow.end_turn, "repeated status-terminal end")
		_conserved(fight)
		trace.append(after)
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "seeded status success and terminal traces replay completely")
	for scenario in ["status_type", "negative", "fraction", "unknown", "position", "duplicate_id", "missing_hp", "hp_type", "enemy_status_type", "enemy_negative", "enemy_fraction", "enemy_unknown", "enemy_position", "enemy_duplicate_id", "enemy_missing_hp", "enemy_hp_type", "overflow", "bad_action"]:
		var fight := _fight(509)
		var flow: CombatRoundFlow = fight["flow"]
		var party: CombatParty = fight["party"]
		_check(flow.begin_fight(), "otherwise-valid rejection fight begins: " + scenario)
		party._heroes[0]["statuses"] = {"bleed": 2}
		fight["enemies"]._enemies[0]["statuses"] = {"bleed": 1}
		match scenario:
			"status_type": party._heroes[2]["statuses"] = []
			"negative": party._heroes[2]["statuses"] = {"weak": -1}
			"fraction": party._heroes[2]["statuses"] = {"bleed": 1.5}
			"unknown": party._heroes[2]["statuses"] = {"poison": 1}
			"position": party._heroes[2]["position"] = 2
			"duplicate_id": party._heroes[2]["id"] = "warden"
			"missing_hp": party._heroes[2].erase("hp")
			"hp_type": party._heroes[2]["hp"] = "26"
			"enemy_status_type": fight["enemies"]._enemies[1]["statuses"] = []
			"enemy_negative": fight["enemies"]._enemies[1]["statuses"] = {"weak": -1}
			"enemy_fraction": fight["enemies"]._enemies[1]["statuses"] = {"bleed": 1.5}
			"enemy_unknown": fight["enemies"]._enemies[1]["statuses"] = {"poison": 1}
			"enemy_position": fight["enemies"]._enemies[1]["position"] = 1
			"enemy_duplicate_id": fight["enemies"]._enemies[1]["id"] = "ragling"
			"enemy_missing_hp": fight["enemies"]._enemies[1].erase("hp")
			"enemy_hp_type": fight["enemies"]._enemies[1]["hp"] = "12"
			"overflow": fight["enemies"]._enemies[1]["block"] = CombatEnemies.MAX_INT
			"bad_action": fight["intents"]._definitions[1]["pattern"][0]["amount"] = -1
		_reject(fight, flow.end_turn, "whole status/phase preflight: " + scenario)


func _test_enemy_status_turns() -> void:
	var replay: Array = []
	for session in range(2):
		var fight := _fight(3030)
		_preconditions(fight)
		var flow: CombatRoundFlow = fight["flow"]
		var enemies: CombatEnemies = fight["enemies"]
		var party: CombatParty = fight["party"]
		_check(flow.begin_fight(), "enemy status fixture begins real seeded fight")
		party._heroes[0]["block"] = 0
		party._heroes[1]["statuses"] = {"weak": 3, "exposed": 2}
		_check(enemies.apply_damage(1, 11), "first enemy lives at one HP before its announced attack")
		enemies._enemies[0]["statuses"] = {"bleed": 1}
		var guard: Dictionary = enemies._enemies[1]
		guard["statuses"] = {"bleed": 3, "weak": 2, "exposed": 1}
		guard["fixture_metadata"] = {"kept": [1, 2]}
		var before := _snapshot(fight)
		var expected := before.duplicate(true)
		expected[0][0]["hp"] = 39
		expected[0][1]["statuses"] = {"weak": 2, "exposed": 1}
		expected[1][0]["hp"] = 0
		expected[1][0]["statuses"] = {}
		expected[1][1]["hp"] = 9
		expected[1][1]["block"] = 1
		expected[1][1]["statuses"] = {"bleed": 2, "weak": 1}
		var oracle := CombatDeck.new(StarterCards.new().get_starting_deck(), _rng(3030))
		_check(oracle.start_turn() and oracle.end_turn() and oracle.start_turn(),
			"independent seeded deck oracle advances one round")
		expected[2] = _deck_snapshot(oracle)
		expected[3] = [
			{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 2},
			{"enemy_position": 2, "type": "block", "amount": 1}]
		expected[4] = 1
		_check(flow.end_turn() and _snapshot(fight) == expected,
			"announced attack happens before lethal Bleed; guard gains Block then loses exactly 3 HP, all counters age once")
		_check(guard == expected[1][1], "enemy tick preserves authoritative dictionary identity and metadata")
		var trace: Array = [before, _snapshot(fight)]
		_check(enemies.is_slain(1) and not enemies.is_victorious()
			and enemies.apply_damage(2, 8) and enemies.get_enemy(2)["hp"] == 2,
			"second round has only guard alive with exactly lethal Bleed and no Block")
		before = _snapshot(fight)
		expected = before.duplicate(true)
		expected[0][1]["statuses"] = {"weak": 1}
		expected[1][1]["hp"] = 0
		expected[1][1]["block"] = 1
		expected[1][1]["statuses"] = {"bleed": 1}
		expected[2][1] = []
		expected[2][2] = before[2][2] + before[2][1]
		expected[2][3] = 0
		expected[2][4] = false
		expected[2][5] = 0
		expected[2][6] = false
		expected[5] = CombatBattleResult.VICTORY
		_check(flow.end_turn() and _snapshot(fight) == expected,
			"final enemy Bleed latches victory, closes hand once, freezes intents, energy, draw and RNG")
		_reject(fight, flow.end_turn, "repeated enemy Bleed victory end")
		_conserved(fight)
		trace.append(_snapshot(fight))
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "two seeded enemy-status runs replay exact actors, deck, intents, result and RNG")

	var defeat := _fight(3031)
	var flow: CombatRoundFlow = defeat["flow"]
	_check(flow.begin_fight() and defeat["party"].apply_damage(2, 999)
		and defeat["party"].apply_damage(3, 999)
		and defeat["enemies"].apply_damage(2, 12), "phase defeat fixture leaves one living actor per side")
	defeat["party"]._heroes[0]["hp"] = 1
	defeat["party"]._heroes[0]["block"] = 0
	defeat["enemies"]._enemies[0]["hp"] = 1
	defeat["enemies"]._enemies[0]["statuses"] = {"bleed": 1}
	var before := _snapshot(defeat)
	var expected := before.duplicate(true)
	expected[0][0]["hp"] = 0
	expected[1][0]["hp"] = 0
	expected[1][0]["statuses"] = {}
	expected[2][1] = []
	expected[2][2] = before[2][2] + before[2][1]
	expected[2][3] = 0
	expected[2][4] = false
	expected[2][5] = 0
	expected[2][6] = false
	expected[5] = CombatBattleResult.DEFEAT
	_check(flow.end_turn() and _snapshot(defeat) == expected,
		"announced lethal phase latches defeat before enemy Bleed, with no next turn or RNG")
	_reject(defeat, flow.end_turn, "repeated phase defeat after enemy Bleed")


func _test_status_damage() -> void:
	# Explicit expected amounts catch single-floor rounding (5 * 9/8 = 5),
	# owner timing, zero damage, and attacks on fixed downed slots.
	for case in [
		{"weak": 1, "exposed": 0, "damage": 3},
		{"weak": 0, "exposed": 2, "damage": 7},
		{"weak": 1, "exposed": 2, "damage": 5},
		{"weak": 0, "exposed": 0, "damage": 5},
		{"weak": 0, "exposed": 1, "damage": 5},
		{"weak": 1, "exposed": 2, "damage": 5, "downed": true},
		{"weak": 1, "exposed": 2, "damage": 5, "bleed_down": true},
		{"weak": 1, "exposed": 0, "damage": 0, "base": 1}]:
		var replay: Array = []
		for session in range(2):
			var base_damage: int = case.get("base", 5)
			var fight := _fight(35035, [], [], [
				{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
				{"enemy_position": 1, "pattern": [{"type": "attack", "amount": base_damage, "target_position": 1}]}])
			var flow: CombatRoundFlow = fight.flow
			_check(flow.begin_fight(), "status damage fixture begins with real seeded services")
			var hero: Dictionary = fight.party._heroes[0]
			hero.block = 2
			if case.weak > 0:
				fight.enemies._enemies[0]["statuses"] = {"weak": case.weak}
			if case.exposed > 0:
				hero["statuses"] = {"exposed": case.exposed}
			if case.get("downed", false):
				_check(fight.party.apply_damage(1, 999) and fight.party.is_downed(1), "target really downed")
			if case.get("bleed_down", false):
				hero.hp = 1
				hero.statuses["bleed"] = 1
			var before := _snapshot(fight)
			var expected := before.duplicate(true)
			var downed: bool = case.get("downed", false) or case.get("bleed_down", false)
			expected[0][0].hp = 0 if downed else hero.hp - maxi(0, case.damage - hero.block)
			expected[0][0].block = 0
			if hero.has("statuses"):
				expected[0][0].statuses = {"exposed": 1} if case.exposed == 2 else {}
			if case.weak > 0:
				expected[1][0].statuses = {}
			expected[1][1].block = 1
			var oracle := CombatDeck.new(StarterCards.new().get_starting_deck(), _rng(35035))
			_check(oracle.start_turn() and oracle.end_turn() and oracle.start_turn(), "damage oracle advances exactly one hand")
			expected[2] = _deck_snapshot(oracle)
			expected[4] = 1
			_check(flow.end_turn() and _snapshot(fight) == expected,
				"exact Weak/Exposed damage, Block, ticks, ordered intents, deck, result and RNG: " + str(case))
			var trace: Array = [before, _snapshot(fight)]
			# Weak 1 has expired and Exposed 1 expires before the next attack.
			before = _snapshot(fight)
			expected = before.duplicate(true)
			if not downed:
				expected[0][0].hp -= base_damage
			if hero.has("statuses"):
				expected[0][0].statuses = {}
			expected[1][1].block = 2
			_check(oracle.end_turn() and oracle.start_turn(), "second damage oracle includes seeded reshuffle")
			expected[2] = _deck_snapshot(oracle)
			expected[4] = 2
			_check(flow.end_turn() and _snapshot(fight) == expected, "next attack uses expired statuses with exact full snapshot")
			trace.append(_snapshot(fight))
			if session == 0:
				replay = trace
			else:
				_check(trace == replay, "entire status damage timeline replays from identical seed")


func _test_reordered_status_turn() -> void:
	# Same Warden/Seamstress swap as the physical trace; a 5-point attack
	# distinguishes one combined floor (5) from intermediate floors (4).
	for exposed in [2, 1]:
		var replay: Array = []
		for session in range(2):
			var fight := _fight(42, [], [], [
				{"enemy_position": 1, "pattern": [
					{"type": "attack", "amount": 5, "target_position": 1},
					{"type": "attack", "amount": 5, "target_position": 2}]},
				{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}])
			var flow: CombatRoundFlow = fight.flow
			var party: CombatParty = fight.party
			var deck: CombatDeck = fight.deck
			_check(party.is_valid() and fight.enemies.is_valid() and fight.intents.is_valid()
				and flow.begin_fight() and party.get_hero(1).block == 6,
				"pure reordered fixture begins with real authored actors and opening Block")
			party._heroes[0].hp = 32
			party._heroes[0].block = 4
			party._heroes[0]["statuses"] = {"bleed": 3, "weak": 2, "exposed": 1}
			party._heroes[1].hp = 20
			party._heroes[1].block = 2
			party._heroes[1]["statuses"] = {"bleed": 2, "exposed": exposed}
			fight.enemies._enemies[0]["statuses"] = {"weak": 1}
			deck.hand.assign(["warden_backstep", "warden_strike"])
			var before := _snapshot(fight)
			var moved := before.duplicate(true)
			moved[0][0] = before[0][1].duplicate(true)
			moved[0][1] = before[0][0].duplicate(true)
			moved[0][0].position = 1
			moved[0][1].position = 2
			moved[2][1].remove_at(0)
			moved[2][2].append("warden_backstep")
			moved[2][3] = 2
			moved[2][5] = 2
			_check(CombatPositionSwaps.play_move_card(deck, party, "warden_backstep",
				M02PositionCards.new().get_definition("warden_backstep"))
				and _snapshot(fight) == moved, "pure paid swap preserves every actor field/status by ID and spends exactly once")
			var expected := moved.duplicate(true)
			# Bleed 2 happens before the attack; Exposed 1 expires first.
			var damage := 5 if exposed == 2 else 3
			expected[0][0].hp = 20 - 2 - (damage - 2)
			expected[0][0].statuses = {"bleed": 1, "exposed": 1} if exposed == 2 else {"bleed": 1}
			expected[0][1].hp = 32 - 3
			expected[0][1].statuses = {"bleed": 2, "weak": 1}
			for hero in expected[0]:
				hero.block = 0
			expected[1][0].statuses = {}
			expected[1][1].block = 1
			# Independently advance only the deck cadence, copying the post-play
			# piles and RNG; no combat/status helper computes the HP oracle.
			var rng := _rng(42)
			rng.state = fight.rng.state
			var oracle := CombatDeck.new([], rng)
			oracle.draw_pile.assign(deck.draw_pile)
			oracle.hand.assign(deck.hand)
			oracle.discard_pile.assign(deck.discard_pile)
			oracle.combat_state.energy = 2
			oracle.combat_state.player_turn_active = true
			_check(oracle.end_turn() and oracle.start_turn(), "independent post-swap deck advances once")
			expected[2] = _deck_snapshot(oracle)
			expected[3][0].target_position = 2
			expected[4] = 1
			_check(flow.end_turn() and _snapshot(fight) == expected,
				"reordered owner tick then Weak/Exposed single-floor attack, exact Block/reset, deck, intents, latch and RNG: " + str(exposed))
			var trace: Array = [before, moved, _snapshot(fight)]
			if session == 0:
				replay = trace
			else:
				_check(trace == replay, "pure reordered status timeline replays completely")


func _test_mounted_enemy_status_turn() -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.run_seed = 3030
	_fixture_start(app)
	await process_frame
	var bound: bool = app.round_flow != null and app.enemies != null \
		and app.round_flow._enemies == app.enemies and app.round_flow._deck == app.deck \
		and app.end_turn_button != null and app.end_turn_button.is_visible_in_tree() \
		and not app.end_turn_button.disabled
	_check(bound, "mounted Start binds real coordinator, enemy roster, deck and reachable End Turn")
	if bound:
		app.enemies._enemies[1]["statuses"] = {"bleed": 3, "weak": 2, "exposed": 1}
		app.end_turn_button.pressed.emit()
		await process_frame
		_check(app.enemies.get_enemy(2)["hp"] == 9
			and app.enemies.get_enemy(2)["block"] == 1
			and app.enemies.get_enemy(2)["statuses"] == {"bleed": 2, "weak": 1}
			and app.deck.turn_active and app.enemy_intents._turn_index == 1,
			"mounted End Turn applies post-action enemy tick through authoritative coordinator")
		_check(app.enemies.apply_damage(1, 12) and app.enemies.apply_damage(2, 8),
			"mounted victory fixture leaves only guard alive at two HP")
		app.end_turn_button.pressed.emit()
		await process_frame
		_check(app.round_flow.get_outcome() == CombatBattleResult.VICTORY
			and app.result_label.is_visible_in_tree() and app.end_turn_button.disabled
			and app.deck.hand.is_empty() and not app.deck.turn_active
			and app.enemy_intents._turn_index == 1,
			"mounted enemy Bleed victory closes player hand and displays terminal result")
	app.free()
	await process_frame


func _test_additional_boundaries() -> void:
	var initial_block := _fight(57)
	var party: CombatParty = initial_block["party"]
	var flow: CombatRoundFlow = initial_block["flow"]
	_check(party.gain_block(1, 4) and party.gain_block(2, 7)
		and party.gain_block(3, 2), "starter Block-reset fixture truly has prior hero Block")
	_check(flow.begin_fight() and party.get_hero(1)["block"] == 6
		and party.get_hero(2)["block"] == 0 and party.get_hero(3)["block"] == 0,
		"begin clears every hero Block BEFORE applying just Warden's opening 6")
	_reject(initial_block, flow.begin_fight, "repeated begin after prior Block reset")

	var dead_source := _fight(58)
	var dead_flow: CombatRoundFlow = dead_source["flow"]
	var enemies: CombatEnemies = dead_source["enemies"]
	var dead_party: CombatParty = dead_source["party"]
	_check(dead_flow.begin_fight() and enemies.apply_damage(1, 12)
		and enemies.is_slain(1) and enemies.get_enemy(2)["hp"] == 12,
		"living guard remains in place after first attacker slain by real damage")
	_check(dead_flow.observe_result() == CombatBattleResult.ACTIVE,
		"partial victory keeps active transition allowed")
	var before_heroes := dead_party.get_heroes()
	# The next player turn legitimately clears the unused opening Warden Block.
	before_heroes[0]["block"] = 0
	_check(dead_flow.end_turn() and dead_party.get_heroes() == before_heroes
		and enemies.get_enemy(1)["hp"] == 0 and enemies.get_enemy(2)["block"] == 1
		and dead_source["intents"]._turn_index == 1,
		"dead source does not attack, living guard Blocks, scheduler still advances")
	_conserved(dead_source)

	var overflow := _fight(59)
	var overflow_flow: CombatRoundFlow = overflow["flow"]
	var overflow_enemies: CombatEnemies = overflow["enemies"]
	_check(overflow_flow.begin_fight()
		and overflow_enemies.gain_block(2, CombatEnemies.MAX_INT)
		and overflow_enemies.get_enemy(2)["block"] == CombatEnemies.MAX_INT,
		"real guard reaches maximum representable Block, phase would reject overflow")
	_reject(overflow, overflow_flow.end_turn,
		"invalid whole phase rejects before any hand/actor/intent/RNG transition")
	_reject(overflow, overflow_flow.end_turn, "repeat overflow end is equally inert")

	var down_warden := _fight(62)
	var down_party: CombatParty = down_warden["party"]
	_check(down_party.apply_damage(1, 40) and down_party.is_downed(1)
		and not down_party.is_defeated()
		and down_warden["result"].can_continue(),
		"downed Warden pre-start has other living heroes and an ACTIVE result")
	var down_oracle := CombatDeck.new(down_warden["cards"], _rng(62))
	_check(down_warden["flow"].begin_fight() and down_oracle.start_turn(),
		"downed Warden with living allies starts a fresh fight")
	_check(down_party.get_hero(1)["hp"] == 0 and down_party.get_hero(1)["block"] == 0
		and down_warden["deck"].energy == 3 and down_warden["deck"].hand.size() == 5
		and _deck_snapshot(down_warden["deck"]) == _deck_snapshot(down_oracle)
		and not down_warden["flow"]._opening_block._consumed,
		"downed Warden stays at zero and gets no passive, with exact seeded draw")
	_reject(down_warden, down_warden["flow"].begin_fight, "downed Warden repeat opening")
	_check(down_warden["flow"].end_turn() and down_party.get_hero(1)["hp"] == 0
		and down_party.get_hero(1)["block"] == 0,
		"later turn cannot grant belated Warden Block or revive downed occupant")

	var invalid_heroes := _fight(60, [{"id": "warden", "max_hp": 0}])
	_check(not invalid_heroes["party"].is_valid()
		and invalid_heroes["result"].get_outcome() == CombatBattleResult.UNRESOLVED,
		"invalid combat party leaves result non-playable")
	_reject_invalid(invalid_heroes, "invalid party with valid enemy deck and schedule")
	var invalid_enemies := _fight(61, [], [{"id": "ragling", "max_hp": -3}])
	_check(not invalid_enemies["enemies"].is_valid()
		and invalid_enemies["result"].get_outcome() == CombatBattleResult.UNRESOLVED,
		"invalid enemy roster is inert and result unresolved")
	_reject_invalid(invalid_enemies, "invalid enemies with valid party deck and schedule")


func _test_special_round_atomicity() -> void:
	var fight := _fight(540, [], [], [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 999, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"}]}])
	_check(fight.flow.begin_fight(), "mixed coordinator starts authoritative authored actors")
	var before: Array = [fight.party.get_heroes(), fight.enemies.get_enemies(), fight.deck.hand.duplicate(),
		fight.deck.draw_pile.duplicate(), fight.deck.discard_pile.duplicate(), fight.deck.energy,
		fight.deck.turn_active, fight.rng.state, fight.intents._turn_index, fight.result.get_outcome()]
	_check(not fight.flow.end_turn(), "coordinator rejects attack then dead-target debuff")
	_check(before == [fight.party.get_heroes(), fight.enemies.get_enemies(), fight.deck.hand.duplicate(),
		fight.deck.draw_pile.duplicate(), fight.deck.discard_pile.duplicate(), fight.deck.energy,
		fight.deck.turn_active, fight.rng.state, fight.intents._turn_index, fight.result.get_outcome()],
		"late special rejection preserves actors hand piles energy turn selector outcome and RNG")
	fight.intents._definitions[0].pattern[0] = {"type": "shove", "amount": 0, "target_position": 1, "direction": 1}
	_check(fight.flow.end_turn() and fight.party.get_hero(1).id == "seamstress"
		and fight.party.get_hero(1).statuses == {"bleed": 2} and fight.intents._turn_index == 1,
		"coordinator commits swap and new-occupant debuff before next draw")


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")



## Catalog-derived five-card hand: the turn opener must draw every reaction
## through CombatDeck itself, not accept a fabricated post-phase reaction.
func _warden_reaction_fight(seed_value: int, held: Array[String], schedule: Array,
		with_unravel: bool = false, lazy: bool = false) -> Dictionary:
	_check(held.size() == CombatDeck.TURN_DRAW, "reaction fixture has five genuinely drawn cards")
	var catalog := WardenPoolCards.new()
	for id in held:
		if id.begins_with("warden_draw_fire") or id.begins_with("warden_counter_stitch"):
			var definition: Dictionary = catalog.get_definition(id)
			_check(not definition.is_empty() and definition.owner == "warden"
				and definition.cost == 1 and definition.target_kind == "self",
				"precondition: reaction card comes from real WardenPoolCards: " + id)
	var rng := _rng(seed_value)
	var deck := CombatDeck.new(held, rng)
	var party := CombatParty.new(_load_json(HEROES_PATH))
	var enemies := CombatEnemies.new(_load_json(ENEMIES_PATH))
	var intents := CombatEnemyIntents.new(schedule)
	var result := CombatBattleResult.new(party, enemies)
	var reactions: CombatWardenGuardReactions = null if lazy else CombatWardenGuardReactions.new()
	var unravel: CombatUnravel = null
	if with_unravel:
		unravel = CombatUnravel.new()
		_check(unravel.bind_roster(enemies, {1: "normal", 2: "elite"}),
			"precondition: real Unravel bound to both original enemy slots")
	var flow := CombatRoundFlow.new(deck, party, enemies, intents, result, unravel,
		null if lazy else reactions)
	_check(party.is_valid() and party.get_hero(1).id == "warden"
		and party.get_hero(2).id == "seamstress" and party.get_hero(3).id == "tinker"
		and enemies.is_valid() and enemies.get_enemies().size() == 2
		and intents.is_valid() and intents.get_intents().size() == 2
		and result.can_continue() and flow._reactions == (null if lazy else reactions),
		"precondition: bound coordinator owns the exact seeded services and reaction identity")
	return {"deck": deck, "rng": rng, "party": party, "enemies": enemies,
		"intents": intents, "result": result, "flow": flow, "cards": held,
		"reactions": reactions, "unravel": unravel}


func _warden_reaction_snapshot(fight: Dictionary) -> Array:
	var reactions: CombatWardenGuardReactions = fight.reactions
	var snapshot: Array = [_snapshot(fight), reactions.is_guarding(), reactions.get_thorns(),
		fight.intents._definitions.duplicate(true)]
	var unravel: CombatUnravel = fight.unravel
	if unravel != null:
		snapshot.append([unravel.get_snapshot(1), unravel.get_snapshot(2)])
	return snapshot.duplicate(true)


func _warden_paid_card(fight: Dictionary, id: String) -> void:
	var deck: CombatDeck = fight.deck
	var party: CombatParty = fight.party
	var reactions: CombatWardenGuardReactions = fight.reactions
	var card: Dictionary = WardenPoolCards.new().get_definition(id)
	var old_block: int = party.get_hero(1).block
	var old_energy: int = deck.energy
	var old_rng: int = deck._rng.state
	var old_discard: int = deck.discard_pile.size()
	_check(deck.turn_active and deck.hand.has(id) and old_energy >= card.cost
		and party.get_hero(1).id == "warden" and not party.is_downed(1),
		"precondition: paid Warden card is held, affordable, alive and legal: " + id)
	_check(fight.flow.play_warden_reaction_card(id),
		"coordinator paid and discarded catalog reaction: " + id)
	_check(fight.flow._reactions != null
		and (reactions == null or fight.flow._reactions == reactions),
		"coordinator retains its first successful battle-local authority")
	fight["reactions"] = fight.flow._reactions
	_check(party.get_hero(1).block == old_block + card.effects.block
		and deck.energy == old_energy - card.cost and not deck.hand.has(id)
		and deck.discard_pile.size() == old_discard + 1
		and deck.discard_pile.back() == id and deck._rng.state == old_rng,
		"paid card adds exact authored Block, consumes energy/card once, never draws RNG: " + id)


func _test_bound_reaction_rounds() -> void:
	for upgraded in [false, true]:
		var draw_id := "warden_draw_fire_plus" if upgraded else "warden_draw_fire"
		var counter_id := "warden_counter_stitch_plus" if upgraded else "warden_counter_stitch"
		# Announcements deliberately supplied backward, scheduler and phase sort
		# by original enemy slot. Weak/Exposed affect the *redirected* Warden.
		var schedule: Array = [
			{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 10, "target_position": 3}]},
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 20, "target_position": 2}]}]
		var fight := _warden_reaction_fight(41044 if not upgraded else 41045,
			[draw_id, counter_id, "warden_strike", "seamstress_prick", "tinker_pop_shot"], schedule)
		var flow: CombatRoundFlow = fight.flow
		var party: CombatParty = fight.party
		var enemies: CombatEnemies = fight.enemies
		var reactions: CombatWardenGuardReactions = fight.reactions
		_check(flow.begin_fight() and fight.deck.hand.size() == 5 and fight.deck.energy == 3
			and party.get_hero(1).block == 6
			and fight.deck.hand.has(draw_id) and fight.deck.hand.has(counter_id)
			and fight.intents.get_intents()[0].enemy_position == 1,
			"real seeded five-card fight opens with both catalog reactions, opening Block and sorted beats")
		_warden_paid_card(fight, draw_id)
		_warden_paid_card(fight, counter_id)
		var thorns := 4 if upgraded else 3
		var ward_block := 21 if upgraded else 17
		_check(party.get_hero(1).block == ward_block and reactions.is_guarding()
			and reactions.get_thorns() == thorns and fight.deck.energy == 1,
			"both modes coexist after real paid plays with base/upgraded authored Block and Thorns")
		party._heroes[0]["statuses"] = {"exposed": 2}
		enemies._enemies[0]["statuses"] = {"weak": 1}
		_check(enemies.gain_block(1, 2), "first attacker has two real Block before Thorns")
		var before := _warden_reaction_snapshot(fight)
		var owner_tick: Dictionary = CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
		_check(owner_tick.ok and flow._phase_is_executable(owner_tick.actors, fight.intents.get_intents())
			and _warden_reaction_snapshot(fight) == before,
			"reaction-aware whole-phase preflight is read-only, including reactions, actors and RNG")
		_check(flow.end_turn(), "authoritative round commits both redirected enemy attacks and retaliation")
		_check(party.get_hero(1).hp == (24 if upgraded else 20)
			and party.get_hero(1).block == 0 and party.get_hero(1).statuses == {"exposed": 1}
			and party.get_hero(2).hp == 30 and party.get_hero(2).block == 0
			and party.get_hero(3).hp == 26 and party.get_hero(3).block == 0,
			"enemy Weak and actual Warden Exposed produce 22 then 15 damage; allies protected, Block spent first")
		_check(enemies.get_enemy(1).hp == (10 if upgraded else 11)
			and enemies.get_enemy(1).block == 0 and enemies.get_enemy(1).get("statuses", {}) == {}
			and enemies.get_enemy(2).hp == (8 if upgraded else 9)
			and fight.intents._turn_index == 1,
			"each attacker takes exactly one Thorns hit, first through 2 Block; original slots survive")
		_check(not reactions.is_guarding() and reactions.get_thorns() == 0
			and fight.deck.turn_active and fight.deck.energy == 3
			and fight.deck.hand.size() == 5 and flow.get_outcome() == CombatBattleResult.ACTIVE,
			"modes expire only at the next successfully opened player turn")
		_conserved(fight)


func _test_bound_reaction_movement_and_skips() -> void:
	var schedule: Array = [
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 20, "target_position": 1}]}]
	var fight := _warden_reaction_fight(41046,
		["warden_draw_fire", "warden_counter_stitch", "warden_backstep",
		"warden_strike", "seamstress_prick"], schedule)
	_check(fight.flow.begin_fight(), "real movement fixture begins")
	_warden_paid_card(fight, "warden_draw_fire")
	_warden_paid_card(fight, "warden_counter_stitch")
	_check(fight.deck.hand.has("warden_backstep") and fight.deck.energy == 1
		and CombatPositionSwaps.play_move_card(fight.deck, fight.party, "warden_backstep",
			M02PositionCards.new().get_definition("warden_backstep"))
		and fight.party.get_hero(2).id == "warden"
		and fight.party.get_hero(1).id == "seamstress",
		"paid real adjacent move repositions Warden to 2 before the phase")
	fight.party._heroes[1]["statuses"] = {"exposed": 2}
	_check(fight.flow.end_turn() and fight.party.get_hero(2).hp == 27
		and fight.party.get_hero(2).block == 0
		and fight.party.get_hero(2).statuses == {"exposed": 1}
		and fight.party.get_hero(1).hp == 30
		and fight.enemies.get_enemy(1).hp == 9 and fight.enemies.get_enemy(2).block == 1,
		"Guarding follows Warden ID into slot 2, applies new owner's Exposed, Thorns and sorted Block")
	_check(not fight.reactions.is_guarding() and fight.reactions.get_thorns() == 0,
		"moved owner's reaction modes clear at accepted turn opening")
	_conserved(fight)

	# An already-downed announced victim remains ineligible; Guarding never
	# pulls the attack toward Warden, but a later living target still redirects.
	var skips := _warden_reaction_fight(41047,
		["warden_draw_fire", "warden_counter_stitch", "warden_strike",
			"seamstress_prick", "tinker_pop_shot"], [
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 90, "target_position": 2}]},
			{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 20, "target_position": 3}]}])
	_check(skips.flow.begin_fight(), "downed victim round fixture begins")
	_warden_paid_card(skips, "warden_draw_fire")
	_warden_paid_card(skips, "warden_counter_stitch")
	_check(skips.party.apply_damage(2, 30) and skips.party.is_downed(2),
		"precondition: announced Seamstress target is already downed")
	_check(skips.flow.end_turn() and skips.party.get_hero(1).hp == 37
		and skips.party.get_hero(1).block == 0 and skips.party.get_hero(2).hp == 0
		and skips.party.get_hero(3).hp == 26
		and skips.enemies.get_enemy(1).hp == 12
		and skips.enemies.get_enemy(2).hp == 9,
		"first downed target not redirected or retaliated; second living-target attack redirects")
	_conserved(skips)

	var slain := _warden_reaction_fight(41048,
		["warden_draw_fire", "warden_counter_stitch", "warden_strike",
			"seamstress_prick", "tinker_pop_shot"], [
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 20, "target_position": 2}]},
			{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 99, "target_position": 3}]}])
	_check(slain.flow.begin_fight(), "slain-source round fixture begins")
	_warden_paid_card(slain, "warden_draw_fire")
	_warden_paid_card(slain, "warden_counter_stitch")
	_check(slain.enemies.apply_damage(2, 12) and slain.enemies.is_slain(2)
		and not slain.enemies.is_victorious(), "precondition: second original source slain before its announced beat")
	_check(slain.flow.end_turn() and slain.party.get_hero(1).hp == 37
		and slain.party.get_hero(3).hp == 26 and slain.enemies.get_enemy(1).hp == 9
		and slain.enemies.get_enemy(2).hp == 0,
		"source 1 attacks/retaliates and later slain source 2's 99-point beat is skipped")
	_conserved(slain)

	var unravel := _warden_reaction_fight(41049,
		["warden_draw_fire", "warden_counter_stitch", "warden_strike",
			"seamstress_prick", "tinker_pop_shot"], [
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 60, "target_position": 2}]},
			{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 20, "target_position": 3}]}], true)
	_check(unravel.flow.begin_fight(), "bound Unravel reaction round begins")
	_warden_paid_card(unravel, "warden_draw_fire")
	_warden_paid_card(unravel, "warden_counter_stitch")
	_check(unravel.unravel.apply_unravel(unravel.enemies, 1, 8)
		and unravel.enemies.apply_statuses({2: {"bleed": 1}})
		and unravel.unravel.get_snapshot(1).skip_pending,
		"precondition: normal source queued skip and second source has real Bleed")
	_check(unravel.flow.end_turn() and unravel.party.get_hero(1).hp == 37
		and unravel.party.get_hero(2).hp == 30 and unravel.party.get_hero(3).hp == 26
		and unravel.enemies.get_enemy(1).hp == 12
		and unravel.enemies.get_enemy(2).hp == 8
		and unravel.unravel.get_snapshot(1).threshold == 12
		and unravel.unravel.get_snapshot(1).gauge == 0
		and not unravel.unravel.get_snapshot(1).skip_pending
		and unravel.unravel.get_snapshot(2).threshold == 12
		and unravel.unravel.get_snapshot(2).gauge == 1,
		"Unravel skip avoids first attack, raises normal threshold by 4; second hit retaliates and Bleed +1 gauge")
	_conserved(unravel)


func _test_bound_reaction_rejections_and_replay() -> void:
	var bad := _warden_reaction_fight(41050,
		["warden_draw_fire", "warden_counter_stitch", "warden_strike",
			"seamstress_prick", "tinker_pop_shot"], [
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 60, "target_position": 2}]},
			{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 2,
				"status": "bleed", "target_position": 1}]}])
	var reactions: CombatWardenGuardReactions = bad.reactions
	reactions.guarding = true
	reactions.thorns = 3
	_check(bad.flow.begin_fight() and not reactions.is_guarding()
		and reactions.get_thorns() == 0 and bad.party.get_hero(1).block == 6,
		"first accepted begin clears stale modes and preserves one-shot opening Block")
	_warden_paid_card(bad, "warden_draw_fire")
	_warden_paid_card(bad, "warden_counter_stitch")
	_check(bad.party.get_hero(1).block == 17 and reactions.is_guarding()
		and reactions.get_thorns() == 3
		and bad.intents.get_intents()[0].target_position == 2
		and bad.intents.get_intents()[1].target_position == 1,
		"precondition: paid Guarding redirects 60 damage onto Warden, making later debuff target downed")
	var before := _warden_reaction_snapshot(bad)
	_check(not bad.flow.end_turn() and _warden_reaction_snapshot(bad) == before,
		"bound whole-phase preflight rejects late downed-target debuff with zero live card/actor/RNG/mode/turn changes")
	_check(bad.flow.observe_result() == CombatBattleResult.ACTIVE
		and _warden_reaction_snapshot(bad) == before,
		"result observation cannot expire either active reaction mode")
	_check(not bad.flow.end_turn() and _warden_reaction_snapshot(bad) == before,
		"repeated invalid end turn cannot discard hand, consume RNG or clear Guarding/Thorns")
	# An invalid reaction authority must fail closed before accepting a turn.
	reactions.thorns = -1
	before = _warden_reaction_snapshot(bad)
	_check(not bad.flow.end_turn() and _warden_reaction_snapshot(bad) == before,
		"malformed reaction authority rejects turn without mutating any bound state")
	reactions.thorns = 3
	bad.intents._definitions[1].pattern[0] = {"type": "block", "amount": 1}
	_check(bad.flow.end_turn() and bad.party.is_downed(1)
		and bad.party.get_hero(2).hp == 30 and bad.enemies.get_enemy(1).hp == 9
		and bad.enemies.get_enemy(2).block == 1 and bad.intents._turn_index == 1
		and not reactions.is_guarding() and reactions.get_thorns() == 0
		and bad.deck.turn_active, "once late action is repaired the phase commits, then clears both modes")

	# Two independent replays per fixed seed, including the run RNG, exact
	# paid hand, both reaction modes, enemy/hero rosters and turn advancement.
	for seed_value in [41051, 41052]:
		var baseline: Array = []
		for session in range(2):
			var fight := _warden_reaction_fight(seed_value,
				["warden_counter_stitch_plus", "warden_draw_fire_plus",
					"warden_strike", "seamstress_prick", "tinker_pop_shot"], [
					{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 9, "target_position": 3}]},
					{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 18, "target_position": 2}]}])
			_check(fight.flow.begin_fight(), "replay fixture begins first seeded turn")
			_warden_paid_card(fight, "warden_draw_fire_plus")
			_warden_paid_card(fight, "warden_counter_stitch_plus")
			var trace: Array = [_warden_reaction_snapshot(fight)]
			_check(fight.flow.end_turn() and fight.intents._turn_index == 1
				and fight.party.get_hero(2).hp == 30
				and fight.enemies.get_enemy(1).hp == 8
				and fight.enemies.get_enemy(2).hp == 8,
				"seeded paid replay resolves two ordered redirected hits and upgraded Thorns")
			trace.append(_warden_reaction_snapshot(fight))
			if session == 0:
				baseline = trace
			else:
				_check(trace == baseline, "independent same-seed replay matches paid cards, actors, intents, RNG, modes and turns")
			_conserved(fight)

	# No optional binding is still the original unbound attack path; even a
	# reaction-free bound flow has the same actor, deck and RNG result.
	var plain := _fight(41053, [], [], [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 7, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 4, "target_position": 3}]}])
	var without_modes := _fight(41053, [], [], [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 7, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 4, "target_position": 3}]}])
	var inert_reactions := CombatWardenGuardReactions.new()
	without_modes.flow._reactions = inert_reactions
	_check(plain.flow._reactions == null and without_modes.flow._reactions == inert_reactions
		and plain.flow.begin_fight() and without_modes.flow.begin_fight(),
		"legacy constructor remains unbound and optional untouched modes admit same valid fight")
	_check(plain.flow.end_turn() and without_modes.flow.end_turn()
		and _snapshot(plain) == _snapshot(without_modes)
		and plain.party.get_hero(1).hp == 40
		and plain.party.get_hero(2).hp == 23 and plain.party.get_hero(3).hp == 22
		and not inert_reactions.is_active(),
		"unbound phase retains exact original damage and seeded parity with inactive binding")


## The default coordinator is intentionally unbound until its first accepted
## paid reaction. These scenarios must not call the reaction rule service
## directly; all damage passes through CombatRoundFlow.end_turn.
func _test_lazy_coordinator_variants() -> void:
	var ids: Array[String] = ["warden_draw_fire", "warden_draw_fire_plus",
		"warden_counter_stitch", "warden_counter_stitch_plus"]
	for index in range(ids.size()):
		var id: String = ids[index]
		var is_draw: bool = id.begins_with("warden_draw_fire")
		var upgraded: bool = id.ends_with("_plus")
		var block_gain: int = (8 if upgraded else 6) if is_draw else (7 if upgraded else 5)
		var thorns_gain: int = 0 if is_draw else (4 if upgraded else 3)
		var seed_value: int = 51000 + index
		var held: Array[String] = [id, "warden_strike", "seamstress_prick",
			"tinker_pop_shot", "warden_brace"]
		var schedule: Array = [
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 9, "target_position": 2}]},
			{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 20, "target_position": 1}]}]
		var fight := _warden_reaction_fight(seed_value, held, schedule, false, true)
		var flow: CombatRoundFlow = fight.flow
		_check(flow._reactions == null and flow.begin_fight()
			and flow._reactions == null and fight.deck.hand.size() == 5
			and fight.deck.hand.has(id) and fight.deck.energy == 3
			and fight.party.get_hero(1).block == 6,
			"AC1/2: default coordinator starts with no authority and real seeded held " + id)
		var rng_before: int = fight.rng.state
		var unspent: Array = _snapshot(fight)
		_warden_paid_card(fight, id)
		var authority: CombatWardenGuardReactions = flow._reactions
		_check(authority != null and fight.deck.energy == 2
			and fight.deck.discard_pile == [id] and not fight.deck.hand.has(id)
			and fight.party.get_hero(1).block == 6 + block_gain
			and authority.is_guarding() == is_draw and authority.get_thorns() == thorns_gain
			and fight.rng.state == rng_before
			and _snapshot(fight) != unspent,
			"AC1/2: successful first paid " + id + " lazily binds exact Block and mode")
		# The block on source 2 is consumed by Thorns before enemy HP; no
		# unrelated attacker is damaged by Counter-stitch without Guarding.
		_check(fight.enemies.gain_block(2, 2),
			"AC2 precondition: attacker really owns two Block before retaliation")
		var oracle := CombatDeck.new(held, _rng(seed_value))
		_check(oracle.start_turn() and oracle.try_spend_energy(1)
			and oracle.discard_played(id) and oracle.end_turn()
			and oracle.start_turn(),
			"AC1/2: independent same-seed hand and energy oracle completes its turn")
		_check(flow.end_turn() and flow._reactions == authority
			and flow.get_outcome() == CombatBattleResult.ACTIVE,
			"AC1/2: real announced enemy phase completes and same authority is retained")
		if is_draw:
			_check(fight.party.get_hero(1).hp == (25 if upgraded else 23)
				and fight.party.get_hero(2).hp == 30 and fight.party.get_hero(3).hp == 26
				and fight.enemies.get_enemy(1).hp == 12
				and fight.enemies.get_enemy(2).hp == 12
				and fight.enemies.get_enemy(2).block == 2,
				"AC1: ally's 9 hit redirected; Warden takes both 9+20 after 6+card Block: " + id)
		else:
			_check(fight.party.get_hero(1).hp == (33 if upgraded else 31)
				and fight.party.get_hero(2).hp == 21 and fight.party.get_hero(3).hp == 26
				and fight.enemies.get_enemy(1).hp == 12
				and fight.enemies.get_enemy(2).hp == (10 if upgraded else 11)
				and fight.enemies.get_enemy(2).block == 0,
				"AC2: ally gets 9, Warden's 6+card Block absorbs 20; only its attacker takes Thorns through 2 Block: " + id)
		_check(fight.party.get_hero(1).block == 0
			and not authority.is_active() and not authority.is_guarding()
			and authority.get_thorns() == 0 and flow._reactions == authority
			and fight.intents._turn_index == 1 and fight.deck.turn_active
			and fight.deck.energy == 3 and fight.deck.hand.size() == 5
			and _deck_snapshot(fight.deck) == _deck_snapshot(oracle),
			"AC1/2: accepted next turn resets Block and modes; seeded deck/RNG exactly replay: " + id)
		_conserved(fight)


func _test_lazy_coordinator_combo() -> void:
	var held: Array[String] = ["warden_draw_fire", "warden_counter_stitch",
		"warden_strike", "seamstress_prick", "tinker_pop_shot"]
	var schedule: Array = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 8, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 7, "target_position": 1}]}]
	var fight := _warden_reaction_fight(52001, held, schedule, false, true)
	_check(fight.flow.begin_fight() and fight.flow._reactions == null
		and fight.deck.hand.has("warden_draw_fire")
		and fight.deck.hand.has("warden_counter_stitch"), "AC3: lazy combo starts fully paid")
	_warden_paid_card(fight, "warden_draw_fire")
	var first: CombatWardenGuardReactions = fight.flow._reactions
	_warden_paid_card(fight, "warden_counter_stitch")
	_check(fight.flow._reactions == first and first.is_guarding()
		and first.get_thorns() == 3 and fight.party.get_hero(1).block == 17
		and fight.deck.energy == 1 and fight.deck.discard_pile.size() == 2,
		"AC3: second accepted card reuses first battle-local authority, both modes coexist")
	_check(fight.flow.end_turn() and fight.party.get_hero(1).hp == 40
		and fight.party.get_hero(1).block == 0
		and fight.party.get_hero(2).hp == 30 and fight.party.get_hero(3).hp == 26
		and fight.enemies.get_enemy(1).hp == 9 and fight.enemies.get_enemy(2).hp == 9
		and not first.is_active() and fight.flow._reactions == first
		and fight.intents._turn_index == 1,
		"AC3: guarded 8+7 absorbed before HP, both enemies retaliated, next turn expires both")
	_check(fight.deck.hand.has("warden_draw_fire") and fight.deck.energy == 3,
		"AC3 precondition: recycled original card genuinely reappears next turn")
	_warden_paid_card(fight, "warden_draw_fire")
	_check(fight.flow._reactions == first and first.is_guarding()
		and first.get_thorns() == 0 and fight.party.get_hero(1).block == 6,
		"AC3: same authority accepts following-turn card without inheriting expired Thorns")
	_check(fight.flow.end_turn() and fight.party.get_hero(1).hp == 31
		and fight.party.get_hero(2).hp == 30 and fight.enemies.get_enemy(1).hp == 9
		and fight.enemies.get_enemy(2).hp == 9 and not first.is_active(),
		"AC3: following phase redirects but has no residual Thorns; next accepted turn expires Guarding")
	_conserved(fight)
	var next_fight := _warden_reaction_fight(52002, held, schedule, false, true)
	_check(next_fight.flow._reactions == null and next_fight.flow.begin_fight()
		and next_fight.flow._reactions == null and next_fight.party.get_hero(1).block == 6
		and next_fight.deck.energy == 3,
		"AC3: independent new fight has no previous battle's mode or authority")
	_warden_paid_card(next_fight, "warden_counter_stitch")
	_check(next_fight.flow._reactions != first
		and next_fight.flow._reactions.get_thorns() == 3
		and not next_fight.flow._reactions.is_guarding()
		and not first.is_active(), "AC3: next encounter creates a distinct paid authority")


func _lazy_reject(fight: Dictionary, card_id: Variant, name: String) -> void:
	var flow: CombatRoundFlow = fight.flow
	var existing: CombatWardenGuardReactions = flow._reactions
	var modes: Array = [] if existing == null else [existing.is_guarding(), existing.get_thorns()]
	var before: Array = _snapshot(fight)
	var schedule: Array = fight.intents._definitions.duplicate(true)
	for attempt in range(2):
		_check(not flow.play_warden_reaction_card(card_id),
			"AC4: " + name + " rejected attempt " + str(attempt + 1))
		_check(_snapshot(fight) == before and fight.intents._definitions == schedule
			and flow._reactions == existing
			and (existing == null or [existing.is_guarding(), existing.get_thorns()] == modes),
			"AC4: " + name + " preserves authority, both modes, actors, piles, intents, result and RNG")


func _test_lazy_coordinator_rejections() -> void:
	var held: Array[String] = ["warden_draw_fire", "warden_counter_stitch",
		"warden_backstep", "warden_strike", "seamstress_prick"]
	var schedule: Array = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 3, "target_position": 1}]}]
	var pre := _warden_reaction_fight(53000, held, schedule, false, true)
	_lazy_reject(pre, "warden_draw_fire", "never-begun coordinator")
	var bad := _warden_reaction_fight(53001, held, schedule, false, true)
	_check(bad.flow.begin_fight() and bad.flow._reactions == null
		and bad.deck.hand.has("warden_draw_fire") and bad.deck.energy == 3,
		"AC4: real active lazy rejection fixture starts with eligible held card")
	_lazy_reject(bad, "warden_iron_hem", "unapproved held/non-reaction card ID")
	_lazy_reject(bad, "warden_draw_fire_plus", "valid reaction ID absent from hand")
	_lazy_reject(bad, 17, "non-string ID")
	_lazy_reject(bad, "", "empty ID")
	_lazy_reject(bad, null, "null ID")
	_warden_paid_card(bad, "warden_draw_fire")
	_lazy_reject(bad, "warden_draw_fire", "stale/repeated already-discarded copy")
	var authority: CombatWardenGuardReactions = bad.flow._reactions
	_check(authority.is_guarding() and bad.deck.try_spend_energy(2)
		and bad.deck.energy == 0 and bad.deck.hand.has("warden_counter_stitch"),
		"AC4 precondition: valid Guarding remains but second held reaction is unaffordable")
	_lazy_reject(bad, "warden_counter_stitch", "insufficient energy with existing Guarding")
	authority.thorns = CombatParty.MAX_INT
	_lazy_reject(bad, "warden_counter_stitch", "near-capacity reaction authority")
	authority.thorns = 0

	var moved := _warden_reaction_fight(53002, held, schedule, false, true)
	_check(moved.flow.begin_fight() and moved.deck.hand.has("warden_backstep")
		and CombatPositionSwaps.play_move_card(moved.deck, moved.party, "warden_backstep",
			M02PositionCards.new().get_definition("warden_backstep"))
		and moved.party.get_hero(2).id == "warden"
		and moved.party.get_hero(2).block == 6 and moved.deck.energy == 2,
		"AC4 precondition: authentic paid swap moves living Warden to slot 2")
	_lazy_reject(moved, "warden_draw_fire", "Draw Fire forbidden at Warden slot 2")
	_check(moved.flow.play_warden_reaction_card("warden_counter_stitch")
		and moved.flow._reactions != null and moved.flow._reactions.get_thorns() == 3
		and moved.party.get_hero(2).block == 11 and moved.deck.energy == 1
		and moved.deck.discard_pile.has("warden_counter_stitch"),
		"AC2/4: authentic coordinator Counter-stitch remains legal from slot 2")
	_lazy_reject(moved, "warden_draw_fire", "Draw Fire still forbidden after paid Thorns")

	var down := _warden_reaction_fight(53003, held, schedule, false, true)
	_check(down.flow.begin_fight() and down.party.apply_damage(1, 100)
		and down.party.is_downed(1) and not down.party.is_defeated(),
		"AC4 precondition: Warden down, two real allies alive")
	_lazy_reject(down, "warden_draw_fire", "downed card owner")

	var empty_energy := _warden_reaction_fight(53004, held, schedule, false, true)
	_check(empty_energy.flow.begin_fight() and empty_energy.deck.try_spend_energy(3)
		and empty_energy.deck.energy == 0, "AC4 precondition: fully spent active turn")
	_lazy_reject(empty_energy, "warden_draw_fire", "fully spent shared energy")

	var inactive := _warden_reaction_fight(53005, held, schedule, false, true)
	_check(inactive.flow.begin_fight() and inactive.deck.end_turn()
		and not inactive.deck.turn_active, "AC4 precondition: hand already closed externally")
	_lazy_reject(inactive, "warden_draw_fire", "inactive player turn")

	var done := _warden_reaction_fight(53006, held, schedule, false, true)
	_check(done.flow.begin_fight() and done.enemies.apply_damage(1, 12)
		and done.enemies.apply_damage(2, 12) and done.enemies.is_victorious()
		and done.result.get_outcome() == CombatBattleResult.ACTIVE,
		"AC4 precondition: all enemies slain while result remains unobserved")
	_lazy_reject(done, "warden_draw_fire", "unobserved terminal battle must not evaluate")
	_check(done.result.evaluate() == CombatBattleResult.VICTORY,
		"AC4 precondition: explicitly observed completed battle")
	_lazy_reject(done, "warden_draw_fire", "latched victory")

	var stale := _warden_reaction_fight(53007, held, schedule, false, true)
	_check(stale.flow.begin_fight(), "AC4 precondition: valid bound starter fight")
	var original_deck: CombatDeck = stale.flow._deck
	var alien_deck := CombatDeck.new(held, _rng(53007))
	_check(alien_deck.start_turn() and alien_deck.hand.has("warden_draw_fire"),
		"AC4 precondition: replacement deck itself has a genuine eligible hand")
	stale.flow._deck = alien_deck
	_lazy_reject(stale, "warden_draw_fire", "replacement active deck, stale coordinator")
	stale.flow._deck = original_deck
	var original_result: CombatBattleResult = stale.flow._result
	stale.flow._result = CombatBattleResult.new(stale.party,
		CombatEnemies.new([{"id": "other", "max_hp": 10}]))
	_lazy_reject(stale, "warden_draw_fire", "battle result bound to other enemy roster")
	stale.flow._result = original_result
	var original_intents: CombatEnemyIntents = stale.flow._intents
	stale.flow._intents = CombatEnemyIntents.new(schedule)
	_lazy_reject(stale, "warden_draw_fire", "replacement valid intent scheduler")
	stale.flow._intents = original_intents
	var malformed := CombatWardenGuardReactions.new()
	malformed.thorns = -1
	stale.flow._reactions = malformed
	_lazy_reject(stale, "warden_draw_fire", "malformed bound Thorns authority")
	stale.flow._reactions = null
	_check(stale.flow.play_warden_reaction_card("warden_draw_fire")
		and stale.flow._reactions != null and stale.flow._reactions.is_guarding(),
		"AC4: valid state after repaired stale bindings still admits a paid card")
