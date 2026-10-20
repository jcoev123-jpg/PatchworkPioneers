extends SceneTree

## Reordered-party integration checks use the real authored, seeded battle services.
## The fixture exchanges committed actor dictionaries, not a free player move.
var failures: Array[String] = []
var checks := 0

const HERO_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/starter_enemies.json"
const INTENT_PATH := "res://data/encounters/starter_attacks.json"


func _initialize() -> void:
	_test_opening_rejections()
	_test_adjacent_replays()
	_test_position_targeting()
	_test_status_owners()
	_test_downed_occupancy()
	_test_poststart_rejections()
	for failure in failures:
		printerr(failure)
	print("combat_round_flow_permutation_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _authored(path: String) -> Array:
	var source := FileAccess.get_file_as_string(path)
	var records = JSON.parse_string(source)
	_check(not source.is_empty() and records is Array and not records.is_empty(),
		"authored catalog exists and is nonempty: " + path)
	if not records is Array:
		return []
	# Godot JSON numeric values are floats; constructor data needs real ints.
	for record in records:
		if not record is Dictionary:
			continue
		for field in ["max_hp", "enemy_position"]:
			if record.get(field) is float:
				_check(record[field] == floorf(record[field]),
					"authored integer field has no fractional value")
				record[field] = int(record[field])
		for action in record.get("pattern", []):
			if action is Dictionary:
				for field in ["amount", "target_position"]:
					if action.get(field) is float:
						_check(action[field] == floorf(action[field]),
							"authored intent integer field is integral")
						action[field] = int(action[field])
	return records


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _fight(seed_value: int = 6123) -> Dictionary:
	var cards := StarterCards.new().get_starting_deck()
	var deck := CombatDeck.new(cards, _rng(seed_value))
	var party := CombatParty.new(_authored(HERO_PATH))
	var enemies := CombatEnemies.new(_authored(ENEMY_PATH))
	var intents := CombatEnemyIntents.new(_authored(INTENT_PATH))
	var result := CombatBattleResult.new(party, enemies)
	var flow := CombatRoundFlow.new(deck, party, enemies, intents, result)
	_check(party.is_valid() and enemies.is_valid() and intents.is_valid()
		and result.can_continue(), "all actual fight models construct and remain active")
	_check(party.get_heroes().map(func(h: Dictionary): return h["id"])
		== ["warden", "seamstress", "tinker"]
		and [party.get_hero(1)["hp"], party.get_hero(2)["hp"],
			party.get_hero(3)["hp"]] == [40, 30, 26],
		"initial authored Warden/Seamstress/Tinker identities and HP")
	_check(enemies.get_enemies().size() == 2
		and enemies.get_enemy(1).get("id") == "ragling"
		and enemies.get_enemy(2).get("id") == "ragling_guard"
		and enemies.get_enemy(1).get("hp") == 12,
		"authored two-enemy roster exists")
	_check(intents.get_intents() == [
		{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 1},
		{"enemy_position": 2, "type": "block", "amount": 1}],
		"authored first attack targets occupied hero slot 1; guard Blocks")
	_check(cards.has("warden_shield_bash") and cards.has("tinker_pop_shot")
		and cards.count("warden_shield_bash") == 1
		and cards.count("tinker_pop_shot") == 2,
		"starter attack membership and copy counts remain authored")
	return {"cards": cards, "deck": deck, "party": party, "enemies": enemies,
		"intents": intents, "result": result, "flow": flow}


func _snapshot(fight: Dictionary) -> Dictionary:
	var deck: CombatDeck = fight.deck
	var flow: CombatRoundFlow = fight.flow
	var intents: CombatEnemyIntents = fight.intents
	return {
		"heroes": fight.party.get_heroes(),
		"enemies": fight.enemies.get_enemies(),
		"draw": deck.draw_pile.duplicate(true),
		"hand": deck.hand.duplicate(true),
		"discard": deck.discard_pile.duplicate(true),
		"energy": deck.energy,
		"turn_active": deck.turn_active,
		"state_energy": deck.combat_state.energy,
		"state_turn": deck.combat_state.player_turn_active,
		"rng_seed": deck._rng.seed,
		"rng_state": deck._rng.state,
		"intents": intents.get_intents(),
		"definitions": intents._definitions.duplicate(true),
		"intent_index": intents._turn_index,
		"outcome": fight.result.get_outcome(),
		"flow_outcome": flow.get_outcome(),
		"result_binding": flow._result == fight.result,
		"started": flow._started,
		"opening_consumed": flow._opening_block._consumed
	}


func _reject(fight: Dictionary, start: bool, label: String) -> void:
	var before := _snapshot(fight)
	_check(not (fight.flow.begin_fight() if start else fight.flow.end_turn()),
		label + ": forbidden round transition returns false")
	_check(_snapshot(fight) == before,
		label + ": full party/deck/enemies/intents/result/passive/RNG snapshot unchanged")


func _exchange(party: CombatParty, left: int) -> void:
	# Emulate an exchange that the position service ALREADY committed.
	_check(left == 1 or left == 2, "fixture exchange always between adjacent slots")
	var a: Dictionary = party._heroes[left - 1]
	var b: Dictionary = party._heroes[left]
	party._heroes[left - 1] = b
	party._heroes[left] = a
	b["position"] = left
	a["position"] = left + 1


func _ids(party: CombatParty) -> Array:
	var result := []
	for index in range(3):
		var hero: Dictionary = party.get_hero(index + 1)
		_check(hero.get("position") == index + 1,
			"each exchanged identity has its current authoritative position")
		result.append(hero.get("id"))
	_check(result.size() == 3 and result.has("warden")
		and result.has("seamstress") and result.has("tinker")
		and result.count("warden") == 1 and result.count("seamstress") == 1
		and result.count("tinker") == 1, "original unique identities still occupy all slots")
	return result


func _test_opening_rejections() -> void:
	for scenario in ["swap12", "swap23", "reverse", "substitute",
			"missing_id", "duplicate_id", "position", "status", "downed_warden"]:
		var fight := _fight(830)
		match scenario:
			"swap12": _exchange(fight.party, 1)
			"swap23": _exchange(fight.party, 2)
			"reverse":
				_exchange(fight.party, 1)
				_exchange(fight.party, 2)
				_exchange(fight.party, 1)
			"substitute": fight.party._heroes[0]["id"] = "outsider"
			"missing_id": fight.party._heroes[1].erase("id")
			"duplicate_id": fight.party._heroes[2]["id"] = "warden"
			"position": fight.party._heroes[1]["position"] = 1
			"status": fight.party._heroes[0]["statuses"] = {"bleed": 1.5}
			"downed_warden":
				_check(fight.party.apply_damage(1, 40)
					and not fight.party.is_defeated(), "opening downed Warden has living allies")
		_reject(fight, true, "prestart malformed or nonopening: " + scenario)
		_check(not fight.flow._opening_block._consumed,
			"no rejected opening consumes one-time passive")
	var fight := _fight(830)
	var deck_oracle := CombatDeck.new(fight.cards, _rng(830))
	_check(fight.flow.begin_fight() and deck_oracle.start_turn(),
		"correct authored formation begins exactly once")
	_check(fight.party.get_hero(1)["block"] == 6 and fight.party.get_hero(1)["hp"] == 40
		and fight.party.get_hero(2)["block"] == 0
		and fight.party.get_hero(3)["block"] == 0
		and fight.flow._opening_block._consumed, "Warden alone receives exactly six opening Block")
	_check(fight.deck.hand.size() == 5 and fight.deck.energy == 3
		and fight.deck.hand == deck_oracle.hand
		and fight.deck.draw_pile == deck_oracle.draw_pile
		and fight.deck._rng.state == deck_oracle._rng.state,
		"authoritative seeded draw-five/three-energy opening equals independent oracle")
	_reject(fight, true, "repeat opening is always inert")


func _test_adjacent_replays() -> void:
	for path in [[1], [2], [1, 2, 2, 1], [1, 2, 1]]:
		var first: Array = []
		for repeat in range(2):
			var fight := _fight(1993)
			_check(fight.flow.begin_fight(), "authored fight began before permitted exchanges")
			for hero in fight.party._heroes:
				hero["metadata"] = {"owner": hero["id"], "tags": [hero["id"], "kept"]}
			# After opening Block is granted, inflict distinctive wounds without
			# clobbering the opening passive's identity.
			_check(fight.party.apply_damage(2, 3)
				and fight.party.apply_damage(3, 4),
				"Seamstress and Tinker enter exchange with identity-bound wounds")
			var before_by_id := {}
			for hero in fight.party.get_heroes():
				before_by_id[hero.id] = hero
			for left in path:
				_exchange(fight.party, left)
			var order := _ids(fight.party)
			_check(order != [] and fight.flow.observe_result() == CombatBattleResult.ACTIVE,
				"valid reordered fight result remains observable")
			for hero in fight.party.get_heroes():
				var previous: Dictionary = before_by_id[hero.id]
				_check(hero.hp == previous.hp and hero.block == previous.block
					and hero.metadata == previous.metadata,
					"HP/Block/nested metadata follow actor identity through exchanges")
			var before := _snapshot(fight)
			var occupant: String = fight.party.get_hero(1)["id"]
			var original_hp: int = fight.party.get_hero(1)["hp"]
			var block: int = fight.party.get_hero(1)["block"]
			var oracle := CombatDeck.new(fight.cards, _rng(1993))
			_check(oracle.start_turn() and oracle.end_turn() and oracle.start_turn(),
				"independent seeded deck oracle crosses first round")
			_check(fight.flow.end_turn(), "post-exchange End Turn accepts current formation")
			_check(fight.party.get_hero(1)["id"] == occupant
				and fight.party.get_hero(1)["hp"] == original_hp - (0 if block > 0 else 1),
				"first announced attack damages PRESENT occupant of slot 1, respecting Block")
			_check(fight.party.get_hero(1)["block"] == 0
				and fight.party.get_hero(2)["block"] == 0
				and fight.party.get_hero(3)["block"] == 0,
				"next player turn clears every hero Block; Warden passive never retriggers")
			_check(fight.deck.hand == oracle.hand
				and fight.deck.draw_pile == oracle.draw_pile
				and fight.deck.discard_pile == oracle.discard_pile
				and fight.deck.energy == 3 and fight.deck.turn_active
				and fight.deck._rng.state == oracle._rng.state,
				"one shared seeded hand is discarded and next draw-five equals oracle")
			_check(fight.intents._turn_index == 1
				and fight.intents.get_intents()[0]["target_position"] == 2
				and fight.enemies.get_enemy(2)["block"] == 1,
				"source-ordered first enemy attack and guard Block; next target slot 2")
			_check(fight.flow.observe_result() == CombatBattleResult.ACTIVE
				and fight.flow.get_outcome() == CombatBattleResult.ACTIVE,
				"post-exchange outcome stays active")
			var slot2_id: String = fight.party.get_hero(2)["id"]
			var hp2: int = fight.party.get_hero(2)["hp"]
			_check(oracle.end_turn() and oracle.start_turn()
				and fight.flow.end_turn(), "second owner/enemy phase completes with seeded refill")
			_check(fight.party.get_hero(2)["id"] == slot2_id
				and fight.party.get_hero(2)["hp"] == hp2 - 1,
				"second announced attack follows current occupant of slot 2")
			_check(fight.intents._turn_index == 2
				and fight.enemies.get_enemy(2)["block"] == 2
				and fight.deck.hand == oracle.hand and fight.deck.draw_pile == oracle.draw_pile
				and fight.deck.discard_pile == oracle.discard_pile
				and fight.deck.energy == 3 and fight.deck._rng.state == oracle._rng.state,
				"two rounds preserve ordered scheduler, guard Block and seeded reshuffle")
			var after := _snapshot(fight)
			var trace := [before, after]
			if repeat == 0:
				first = trace
			else:
				_check(trace == first, "two independent seeded exchanges replay full state: " + str(path))


func _seed_for_attack_hand() -> int:
	for seed_value in range(256):
		var deck := CombatDeck.new(StarterCards.new().get_starting_deck(), _rng(seed_value))
		deck.start_turn()
		if deck.hand.has("warden_shield_bash") and deck.hand.has("tinker_pop_shot"):
			return seed_value
	return -1


func _test_position_targeting() -> void:
	var seed_value := _seed_for_attack_hand()
	_check(seed_value >= 0, "found deterministic authored opening hand with Shield Bash and Pop Shot")
	if seed_value < 0:
		return
	var fight := _fight(seed_value)
	var targeter := CombatAttackTargeting.new()
	_check(fight.flow.begin_fight() and fight.deck.hand.has("warden_shield_bash")
		and fight.deck.hand.has("tinker_pop_shot"), "real seeded five-card hand holds both attacks")
	var deck: CombatDeck = fight.deck
	var party: CombatParty = fight.party
	var enemies: CombatEnemies = fight.enemies
	var catalog := StarterCards.new()
	_check(catalog.get_definition("warden_shield_bash")["from_positions"] == [1]
		and catalog.get_definition("warden_shield_bash")["to_positions"] == [1]
		and catalog.get_definition("warden_shield_bash")["cost"] == 2
		and catalog.get_definition("tinker_pop_shot")["from_positions"] == [2, 3]
		and catalog.get_definition("tinker_pop_shot")["cost"] == 1,
		"targeter uses unchanged authored positional restrictions and costs")
	var before := _snapshot(fight)
	_check(targeter.get_preview(deck, party, enemies, "warden_shield_bash") == {
		"playable": true, "requires_selection": true, "target_positions": [1]}
		and targeter.get_preview(deck, party, enemies, "tinker_pop_shot") == {
		"playable": true, "requires_selection": true, "target_positions": [1, 2]},
		"both attacks valid with initial owners")
	_check(_snapshot(fight) == before, "attack previews never consume hand, status or RNG")
	_exchange(party, 1)
	_check(not targeter.get_preview(deck, party, enemies, "warden_shield_bash")["playable"]
		and targeter.get_preview(deck, party, enemies, "tinker_pop_shot")["playable"],
		"Warden slot 2 loses Shield Bash legality; Tinker slot 3 keeps Pop Shot")
	_exchange(party, 2)
	_exchange(party, 1)
	_check(_ids(party) == ["tinker", "seamstress", "warden"]
		and not targeter.get_preview(deck, party, enemies, "tinker_pop_shot")["playable"],
		"Tinker at slot 1 cannot play Pop Shot")
	_exchange(party, 1)
	_exchange(party, 2)
	_exchange(party, 1)
	_check(_ids(party) == ["warden", "seamstress", "tinker"]
		and targeter.get_preview(deck, party, enemies, "warden_shield_bash")["playable"]
		and targeter.get_preview(deck, party, enemies, "tinker_pop_shot")["playable"],
		"adjacent reversals restore both actual-owner attack permissions")
	_check(fight.flow.end_turn() and fight.intents._turn_index == 1,
		"card preview sequence does not disable authoritative round boundary")


func _test_status_owners() -> void:
	var fight := _fight(4231)
	_check(fight.flow.begin_fight(), "status fight begins from strict authored formation")
	var party: CombatParty = fight.party
	_exchange(party, 1)
	var warden: Dictionary = party._heroes[1]
	var seamstress: Dictionary = party._heroes[0]
	warden["statuses"] = {"bleed": 2, "weak": 2, "exposed": 2}
	warden["metadata"] = {"owner": "warden", "deep": ["intact"]}
	seamstress["statuses"] = {"exposed": 2}
	var initial := _snapshot(fight)
	_check(warden["block"] == 6 and warden["hp"] == 40
		and seamstress["position"] == 1, "opening Block stays on reordered Warden")
	_check(fight.flow.end_turn(), "first reordered owner status tick and phase run")
	_check(warden["hp"] == 38 and warden["block"] == 0
		and warden["statuses"] == {"bleed": 1, "weak": 1, "exposed": 1}
		and warden["metadata"] == {"owner": "warden", "deep": ["intact"]},
		"Bleed 2 bypasses Warden's six Block, statuses age by owner and metadata stays")
	_check(seamstress["hp"] == 29 and seamstress["statuses"] == {"exposed": 1},
		"slot-one Seamstress takes first announced attack after Exposed adjustment")
	_check(party.get_hero(2)["id"] == "warden"
		and fight.intents.get_intents()[0]["target_position"] == 2,
		"next enemy intent now targets Warden's current slot 2")
	_check(fight.flow.end_turn(), "second post-exchange status tick and phase run")
	_check(warden["hp"] == 36 and warden["block"] == 0
		and warden["statuses"] == {} and seamstress["statuses"] == {}
		and seamstress["hp"] == 29,
		"second Bleed 1 plus slot-two attack lowers Warden to 36; Weak/Exposed expire")
	_check(initial["opening_consumed"] and fight.flow._opening_block._consumed
		and party.get_hero(1)["id"] == "seamstress"
		and party.get_hero(2)["id"] == "warden"
		and fight.flow.observe_result() == CombatBattleResult.ACTIVE,
		"two owner turns neither teleport heroes nor repeat Warden passive")


func _test_downed_occupancy() -> void:
	var seed_value := _seed_for_attack_hand()
	if seed_value < 0:
		_check(false, "downed test needs real hand seed")
		return
	var fight := _fight(seed_value)
	_check(fight.flow.begin_fight(), "downed case begins with valid opening formation")
	_exchange(fight.party, 1)
	_check(fight.party.apply_damage(1, 30) and fight.party.is_downed(1)
		and not fight.party.is_defeated()
		and fight.party.get_hero(1)["id"] == "seamstress",
		"post-exchange Seamstress drops to zero and retains front occupied slot")
	var before := _snapshot(fight)
	_check(fight.flow.observe_result() == CombatBattleResult.ACTIVE
		and _snapshot(fight) == before, "downed hero does not invalidate active result observation")
	_check(not CombatAttackTargeting.new().get_preview(fight.deck, fight.party, fight.enemies,
		"seamstress_prick")["playable"], "downed Seamstress cannot attack even when card requested")
	_check(fight.flow.end_turn() and fight.party.get_hero(1)["hp"] == 0
		and fight.party.get_hero(1)["id"] == "seamstress"
		and fight.party.get_hero(2)["id"] == "warden"
		and fight.party.get_hero(2)["block"] == 0
		and fight.intents._turn_index == 1, "slot-one attack skips downed occupant; Warden stays in slot 2")
	_check(fight.flow.end_turn() and fight.party.get_hero(1)["hp"] == 0
		and fight.party.get_hero(2)["hp"] == 39
		and fight.flow.observe_result() == CombatBattleResult.ACTIVE,
		"second attack hits surviving Warden in slot 2, downed slot remains occupied")


func _test_poststart_rejections() -> void:
	for scenario in ["duplicate", "unknown", "missing_id", "id_number",
			"position_duplicate", "position_missing", "position_zero",
			"position_fraction", "position_wrong", "missing_hp", "hp_type",
			"missing_block", "bad_status_type", "bad_status_count",
			"bad_status_name", "enemy_position", "enemy_status",
			"intent_count", "intent_position", "wrong_result_binding"]:
		var fight := _fight(5439)
		_check(fight.flow.begin_fight(), "negative fixture starts valid seeded fight")
		_exchange(fight.party, 1)
		fight.party._heroes[1]["statuses"] = {"bleed": 2}
		fight.party._heroes[1]["metadata"] = {"deep": ["keep"]}
		match scenario:
			"duplicate": fight.party._heroes[2]["id"] = "warden"
			"unknown": fight.party._heroes[2]["id"] = "unknown"
			"missing_id": fight.party._heroes[2].erase("id")
			"id_number": fight.party._heroes[2]["id"] = 123
			"position_duplicate": fight.party._heroes[2]["position"] = 2
			"position_missing": fight.party._heroes[2].erase("position")
			"position_zero": fight.party._heroes[2]["position"] = 0
			"position_fraction": fight.party._heroes[2]["position"] = 2.5
			"position_wrong": fight.party._heroes[0]["position"] = 3
			"missing_hp": fight.party._heroes[2].erase("hp")
			"hp_type": fight.party._heroes[2]["hp"] = "26"
			"missing_block": fight.party._heroes[2].erase("block")
			"bad_status_type": fight.party._heroes[2]["statuses"] = []
			"bad_status_count": fight.party._heroes[2]["statuses"] = {"weak": 1.5}
			"bad_status_name": fight.party._heroes[2]["statuses"] = {"poison": 1}
			"enemy_position": fight.enemies._enemies[1]["position"] = 1
			"enemy_status": fight.enemies._enemies[1]["statuses"] = {"bleed": -1}
			"intent_count": fight.intents._definitions.remove_at(1)
			"intent_position": fight.intents._definitions[1]["enemy_position"] = 3
			"wrong_result_binding":
				var other := _fight(5439)
				fight.flow._result = other.result
		_reject(fight, false, "post-start rejected state: " + scenario)
		var before := _snapshot(fight)
		_check(fight.flow.observe_result() == CombatBattleResult.UNRESOLVED
			and _snapshot(fight) == before,
			"bad post-start roster/binding cannot be observed or mutate result: " + scenario)
