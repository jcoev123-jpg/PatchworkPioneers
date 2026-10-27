extends SceneTree

const PRINTINGS := {
	"rag_duelist_rapier_lunge": 5, "rag_duelist_rapier_lunge_plus": 7,
	"rag_duelist_needle_lunge": 6, "rag_duelist_needle_lunge_plus": 8,
}
var service := CombatRagDuelistLungeCards.new()
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	for id: String in PRINTINGS:
		var definition := service._catalog_definition(id)
		_check(not definition.is_empty() and service._authentic(definition, id), id + " authentic")
		_check(definition.get("owner") == "rag_duelist" and definition.get("cost") == 1
			and definition.get("from_positions") == [2, 3]
			and definition.get("to_positions") == [1, 2]
			and definition.get("target_kind") == "enemy_single"
			and definition.get("effects") == {"damage": PRINTINGS[id], "move_self_forward": 1},
			id + " exact printed line")
		var upgraded := id.ends_with("_plus")
		var starter := id.contains("rapier")
		_check(definition.get("starting_copies") == (1 if starter and not upgraded else 0)
			and definition.get("reward_eligible") == (not starter and not upgraded), id + " flags")
		_check(definition.get("upgrade_of" if upgraded else "upgrade_id")
			== (id.trim_suffix("_plus") if upgraded else id + "_plus"), id + " upgrade link")
		for field in ["id", "owner", "cost", "from_positions", "to_positions", "target_kind", "effects"]:
			var altered := definition.duplicate(true)
			altered.erase(field)
			_check(not service._authentic(altered, id), id + " rejects missing " + field)
		var altered := definition.duplicate(true)
		altered["effects"]["draw"] = 1
		_check(not service._authentic(altered, id), id + " rejects extra effect")
		for field in ["cost", "from_positions", "to_positions", "effects"]:
			altered = definition.duplicate(true)
			match field:
				"cost": altered[field] = 1.0
				"from_positions": altered[field] = [2.0, 3.0]
				"to_positions": altered[field] = [1.0, 2.0]
				"effects": altered[field]["damage"] = float(PRINTINGS[id])
			_check(not service._authentic(altered, id), id + " rejects altered type " + field)
		for seat in [2, 3]:
			for target in [1, 2]:
				for mode in ["ordinary", "statuses", "lethal", "blocked", "stable_slot"]:
					_success(id, seat, target, mode)
	for problem in ["front", "missing_owner", "downed_owner", "downed_neighbor",
			"tangled_owner", "tangled_neighbor", "invalid_target", "dead_target", "missing_slot",
			"no_copy", "no_energy", "unknown", "inactive", "bad_status", "bad_enemy_status",
			"bad_hp", "duplicate_owner"]:
		_rejection(problem)
	_check(not service.is_supported_card(null) and not service.is_supported_card(1)
		and not service.is_supported_card("rag_duelist_feather_feint"), "unsupported IDs")
	for failure in failures:
		printerr(failure)
	print("combat_rag_duelist_lunge_cards_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _fixture(id: String, seat: int = 2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 325
	var deck := CombatDeck.new([id, "filler_a", "filler_b", "filler_c", "filler_d", "filler_e"], rng)
	_check(deck.start_turn(), "fixture active turn")
	deck.draw_extra(1)
	_check(deck.hand.count(id) == 1 and deck.try_spend_energy(2), "fixture holds real copy, one energy")
	var definitions: Array = []
	for position in range(1, 4):
		definitions.append({"id": "rag_duelist" if position == seat else "ally_" + str(position),
			"max_hp": 30, "statuses": {"bleed": position}, "metadata": {"cloth": [position, "felt"]}})
	var party := CombatParty.new(definitions)
	for position in range(1, 4):
		party.apply_damage(position, position)
		party.gain_block(position, position + 1)
	var enemies := CombatEnemies.new([
		{"id": "enemy_a", "max_hp": 30, "statuses": {}, "metadata": ["a"]},
		{"id": "enemy_b", "max_hp": 30, "statuses": {}, "metadata": ["b"]},
		{"id": "enemy_c", "max_hp": 30, "statuses": {}, "metadata": ["c"]}])
	_check(enemies.gain_block(1, 2) and enemies.gain_block(2, 3), "fixture real enemy Block")
	return {"deck": deck, "party": party, "enemies": enemies}


func _snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f.deck
	return {"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy, "active": deck.turn_active,
		"rng": deck._rng.state, "seed": deck._rng.seed,
		"heroes": f.party.get_heroes(), "enemies": f.enemies.get_enemies()}


func _success(id: String, seat: int, target: int, mode: String) -> void:
	var f := _fixture(id, seat)
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	if mode == "statuses":
		party._heroes[seat - 1]["statuses"]["weak"] = 2
		enemies._enemies[target - 1]["statuses"] = {"exposed": 2, "tangled": 3}
	if mode == "lethal":
		enemies.apply_damage(target, 31)
		_check(not enemies.is_slain(target), "lethal fixture still living")
	if mode == "blocked":
		enemies.gain_block(target, 100)
	if mode == "stable_slot" and target == 2:
		enemies.apply_damage(1, 100)
	var before := _snapshot(f)
	var mover: Dictionary = party._heroes[seat - 1]
	var neighbor: Dictionary = party._heroes[seat - 2]
	var expected_heroes: Array = before.heroes.duplicate(true)
	expected_heroes[seat - 2] = before.heroes[seat - 1].duplicate(true)
	expected_heroes[seat - 1] = before.heroes[seat - 2].duplicate(true)
	expected_heroes[seat - 2]["position"] = seat - 1
	expected_heroes[seat - 1]["position"] = seat
	# Independent application through the established status-aware attack service.
	var oracle := CombatEnemies.new(before.enemies)
	oracle._enemies.assign(before.enemies.duplicate(true))
	var expected_hit := CombatStatusAttacks.new().resolve_vs_enemy(oracle, target, PRINTINGS[id],
		before.heroes[seat - 1].statuses, before.enemies[target - 1].statuses)
	_check(expected_hit.ok, "oracle genuinely attacks")
	var result := service.play_card(deck, party, enemies, id, target)
	var label := "%s seat=%d target=%d %s" % [id, seat, target, mode]
	_check(result.get("ok", false) and result.get("cost") == 1
		and result.get("damage") == expected_hit.damage
		and result.get("hp_loss") == expected_hit.hp_loss
		and result.get("block_absorbed") == expected_hit.block_absorbed, label + " one ordinary hit")
	_check(enemies.get_enemies() == oracle.get_enemies(), label + " exact target HP/Block and unaffected enemies")
	_check(party.get_heroes() == expected_heroes, label + " complete hero records swapped only")
	_check(is_same(party._heroes[seat - 2], mover) and is_same(party._heroes[seat - 1], neighbor),
		label + " authoritative dictionary identities")
	var expected_hand: Array = before.hand.duplicate()
	expected_hand.erase(id)
	_check(deck.energy == 0 and deck.hand == expected_hand and deck.discard_pile == [id]
		and deck.draw_pile == before.draw and deck._rng.state == before.rng, label + " paid/discarded once, no RNG")
	var after := _snapshot(f)
	_check(not service.play_card(deck, party, enemies, id, target).get("ok", false)
		and _snapshot(f) == after, label + " replay inert")


func _rejection(problem: String) -> void:
	var id: String = PRINTINGS.keys()[0]
	var f := _fixture(id, 1 if problem == "front" else 2)
	var target := 1
	match problem:
		"missing_owner": f.party._heroes[1]["id"] = "other"
		"downed_owner": f.party.apply_damage(2, 100)
		"downed_neighbor": f.party.apply_damage(1, 100)
		"tangled_owner": f.party._heroes[1]["statuses"]["tangled"] = 1
		"tangled_neighbor": f.party._heroes[0]["statuses"]["tangled"] = 1
		"invalid_target": target = 3
		"dead_target": f.enemies.apply_damage(1, 100)
		"missing_slot":
			f.enemies = CombatEnemies.new([{"id": "only", "max_hp": 10}])
			target = 2
		"no_copy": f.deck.discard_played(id)
		"no_energy": f.deck.try_spend_energy(1)
		"unknown":
			id = "rag_duelist_feather_feint"
			f.deck.hand.append(id)
		"inactive": f.deck.end_turn()
		"bad_status": f.party._heroes[1]["statuses"] = 3
		"bad_enemy_status": f.enemies._enemies[0]["statuses"] = {"weak": "1"}
		"bad_hp": f.party._heroes[1]["hp"] = -1
		"duplicate_owner": f.party._heroes[0]["id"] = "rag_duelist"
	var before := _snapshot(f)
	for attempt in range(2):
		_check(not service.play_card(f.deck, f.party, f.enemies, id, target).get("ok", false),
			problem + " refused " + str(attempt))
		_check(_snapshot(f) == before, problem + " full no-write/RNG snapshot")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
