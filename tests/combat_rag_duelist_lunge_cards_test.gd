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
		# V3-2 enemy keywords on the chosen foe: one Thorns retaliation against the
		# MOVED Duelist and one Enrage stack for that same foe, per confirmed hit.
		for seat in [2, 3]:
			for target in [1, 2]:
				for mode in ["plain", "thorns", "thorns_blocked", "thorns_lethal", "combined"]:
					_keyword_hit(id, seat, target, mode)
		for target in [1, 2]:
			for stacks in [0, 2, 3]:
				_keyword_hit(id, 2, target, "enrage", stacks)
		_second_hit(id)
	for problem in ["front", "missing_owner", "downed_owner", "downed_neighbor",
			"tangled_owner", "tangled_neighbor", "invalid_target", "dead_target", "missing_slot",
			"no_copy", "no_energy", "unknown", "inactive", "bad_status", "bad_enemy_status",
			"bad_hp", "duplicate_owner",
			"keyword_front", "keyword_downed_owner", "keyword_tangled_owner",
			"keyword_tangled_neighbor", "keyword_invalid_target", "keyword_dead_target",
			"keyword_no_copy", "keyword_no_energy", "keyword_unknown", "keyword_inactive",
			"keyword_bad_thorns", "keyword_bad_enrage", "keyword_bad_enrage_stacks"]:
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


## A genuine deck, legal three-hero party and two living enemies, plus the chosen
## foe's authored V3-2 keyword metadata. Thorns 3 against a Duelist holding exactly
## 2 Block is the canonical probe: 2 Block absorbed and 1 HP lost by the MOVED
## Duelist. `plain` keeps an explicit zero Thorns so the old Lunge result is
## unchanged; `enrage` carries no Thorns key at all.
func _keyword_fixture(id: String, seat: int, target: int, mode: String,
		pre_stacks: int = 0) -> Dictionary:
	var f := _fixture(id, seat)
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	_check(party.start_player_turn() and party.gain_block(seat, 2),
		"keyword fixture: living Duelist holding exactly two Block")
	var victim: Dictionary = enemies._enemies[target - 1]
	match mode:
		"plain": victim["thorns"] = 0
		"enrage": pass
		_: victim["thorns"] = 3
	if mode in ["combined", "enrage"]:
		victim["enrage"] = true
		victim["enrage_stacks"] = pre_stacks
	# The combined fixture also keeps the canonical status math live on both sides,
	# so a keyworded Lunge still buys floor(printed * Exposed * Weak) + Tangled 2.
	if mode == "combined":
		party._heroes[seat - 1]["statuses"]["weak"] = 2
		victim["statuses"] = {"exposed": 1, "tangled": 2}
	if mode == "thorns_blocked":
		_check(enemies.gain_block(target, 100), "keyword fixture: real enemy Block")
	if mode == "thorns_lethal":
		victim["block"] = 0
		victim["hp"] = 1
	return f


## One real paid Lunge against a keyworded foe, checked against an independent
## oracle for the hit and a hand-computed before/after party and roster.
func _keyword_hit(id: String, seat: int, target: int, mode: String,
		pre_stacks: int = 0) -> void:
	var f := _keyword_fixture(id, seat, target, mode, pre_stacks)
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	var before := _snapshot(f)
	var label := "%s seat=%d target=%d %s stacks=%d" % [id, seat, target, mode, pre_stacks]
	var foe: Dictionary = before.enemies[target - 1]
	var enraged: bool = foe.get("enrage", false) == true
	var thorns_value: int = int(foe.get("thorns", 0))
	# Independent application through the established status-aware attack service.
	var oracle := CombatEnemies.new(before.enemies)
	oracle._enemies.assign(before.enemies.duplicate(true))
	var expected_hit := CombatStatusAttacks.new().resolve_vs_enemy(oracle, target, PRINTINGS[id],
		before.heroes[seat - 1].statuses, foe.statuses)
	_check(expected_hit.ok, label + " oracle genuinely attacks")
	if mode == "combined":
		_check(expected_hit.damage != PRINTINGS[id] and expected_hit.damage > 0,
			label + " canonical Weak/Exposed/Tangled really adjusted the printed damage")
	var expected_stacks: int = pre_stacks
	if enraged and expected_hit.damage > 0:
		expected_stacks = mini(pre_stacks + 1, CombatEnemyKeywordRules.ENRAGE_MAX_STACKS)
	var expect_enrage: bool = enraged and expected_hit.damage > 0 \
		and pre_stacks < CombatEnemyKeywordRules.ENRAGE_MAX_STACKS
	var expected_enemies: Array = oracle.get_enemies()
	if expect_enrage:
		expected_enemies[target - 1]["enrage_stacks"] = expected_stacks
	# The retaliation lands on the Duelist where he ends up, never on the ally that
	# takes his old slot; CombatParty absorbs it with his own Block first.
	var thorns_applied: bool = thorns_value > 0 and expected_hit.damage > 0
	var expected_heroes: Array = before.heroes.duplicate(true)
	expected_heroes[seat - 2] = before.heroes[seat - 1].duplicate(true)
	expected_heroes[seat - 1] = before.heroes[seat - 2].duplicate(true)
	expected_heroes[seat - 2]["position"] = seat - 1
	expected_heroes[seat - 1]["position"] = seat
	var moved: Dictionary = expected_heroes[seat - 2]
	var thorns_absorbed := 0
	var thorns_hp_loss := 0
	if thorns_applied:
		thorns_absorbed = mini(int(moved["block"]), thorns_value)
		thorns_hp_loss = thorns_value - thorns_absorbed
		moved["block"] = int(moved["block"]) - thorns_absorbed
		moved["hp"] = int(moved["hp"]) - thorns_hp_loss
	var ally: Dictionary = before.heroes[seat - 2]
	var result := service.play_card(deck, party, enemies, id, target)
	_check(result.get("ok", false) and result.get("cost") == 1
		and result.get("damage") == expected_hit.damage
		and result.get("hp_loss") == expected_hit.hp_loss
		and result.get("block_absorbed") == expected_hit.block_absorbed,
		label + " one confirmed hit with the exact printed/status damage")
	_check(enemies.get_enemies() == expected_enemies,
		label + " exact target HP/Block plus one reaction, non-targets untouched")
	_check(enemies.get_enemy(target).get("id") == foe.get("id"),
		label + " original target identity kept")
	_check(party.get_heroes() == expected_heroes,
		label + " exact before/after party: one swap and the Duelist's own retaliation")
	_check(int(party.get_hero(seat).get("hp", -1)) == int(ally["hp"])
		and int(party.get_hero(seat).get("block", -1)) == int(ally["block"]),
		label + " the swapped ally never takes the Thorns hit")
	_check(result.get("thorns_retaliation") == {"ok": true, "applied": thorns_applied,
		"thorns": thorns_value, "block_absorbed": thorns_absorbed, "hp_loss": thorns_hp_loss},
		label + " one Thorns retaliation receipt through the hero's own Block")
	_check(result.get("enrage_commit") == {"ok": true, "applied": expect_enrage,
		"enrage_stacks": expected_stacks, "attack_bonus": expected_stacks * 2},
		label + " one Enrage stack receipt, capped at three")
	_check(enemies.get_enemy(target).get("enrage_stacks", 0) == expected_stacks,
		label + " authoritative stack count on that same foe")
	var projected := service._keywords.project_enrage_action(enemies.get_enemy(target),
		{"type": "attack", "amount": 4})
	if enemies.is_slain(target):
		_check(not projected.ok and projected.attack_bonus == 0,
			label + " a slain foe is no longer a legal projection source")
	else:
		_check(projected.ok and projected.attack_bonus == expected_stacks * 2
			and projected.action.amount == 4 + expected_stacks * 2,
			label + " existing action projection pays +2 per stack (+6 ceiling)")
	var expected_hand: Array = before.hand.duplicate()
	expected_hand.erase(id)
	_check(deck.energy == 0 and deck.hand == expected_hand and deck.discard_pile == [id]
		and deck.draw_pile == before.draw and deck._rng.state == before.rng,
		label + " paid/discarded exactly once, no RNG")
	var after := _snapshot(f)
	_check(not service.play_card(deck, party, enemies, id, target).get("ok", false)
		and _snapshot(f) == after, label + " replay inert: no second hit or stack")


## Two separately held, paid thrusts each earn their own reaction on the same foe;
## no copied receipt or replay may borrow the first one.
func _second_hit(id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 881
	var cards: Array[String] = [id, id, "filler_a", "filler_b", "filler_c", "filler_d", "filler_e"]
	var deck := CombatDeck.new(cards, rng)
	var party := CombatParty.new([
		{"id": "ally_front", "max_hp": 30, "statuses": {}},
		{"id": "ally_middle", "max_hp": 30, "statuses": {}},
		{"id": "rag_duelist", "max_hp": 30, "statuses": {}}])
	var enemies := CombatEnemies.new([
		{"id": "thorned", "max_hp": 60, "statuses": {}, "thorns": 3, "enrage": true},
		{"id": "plain", "max_hp": 30}])
	_check(deck.start_turn() and deck.hand.count(id) == 2 and deck.draw_extra(2) == 2,
		"second-hit fixture: one active turn holds both paid copies")
	_check(deck.try_spend_energy(1) and deck.energy == 2,
		"second-hit fixture: exactly two energy left")
	_check(party.gain_block(3, 1), "second-hit fixture: the Duelist holds one Block")
	var state := {"deck": deck, "party": party, "enemies": enemies}
	var before := _snapshot(state)
	var label := id + " second paid hit"
	var duelist: Dictionary = before.heroes[2].duplicate(true)
	var near: Dictionary = before.heroes[1].duplicate(true)
	var far: Dictionary = before.heroes[0].duplicate(true)
	var first := service.play_card(deck, party, enemies, id, 1)
	_check(first.get("ok", false) and first.get("destination_position") == 2
		and first.get("thorns_retaliation", {}).get("hp_loss") == 2
		and first.get("enrage_commit", {}).get("enrage_stacks") == 1,
		label + " first thrust: one Block absorbed, one HP lost, one stack")
	duelist["position"] = 2
	near["position"] = 3
	duelist["block"] = 0
	duelist["hp"] = int(duelist["hp"]) - 2
	_check(party.get_heroes() == [far, duelist, near], label + " first thrust's exact party")
	_check(enemies.get_enemy(1).get("enrage_stacks", 0) == 1
		and int(enemies.get_enemy(1)["hp"]) == int(before.enemies[0]["hp"]) - int(first["damage"]),
		label + " first thrust's exact foe")
	var second := service.play_card(deck, party, enemies, id, 1)
	_check(second.get("ok", false) and second.get("destination_position") == 1
		and second.get("thorns_retaliation", {}).get("hp_loss") == 3
		and second.get("enrage_commit", {}).get("enrage_stacks") == 2,
		label + " second held paid thrust earns its own single reaction")
	duelist["position"] = 1
	far["position"] = 2
	duelist["hp"] = int(duelist["hp"]) - 3
	_check(party.get_heroes() == [duelist, far, near], label + " second thrust's exact party")
	var expected_enemies: Array = before.enemies.duplicate(true)
	expected_enemies[0]["hp"] = int(before.enemies[0]["hp"]) - int(first["damage"]) \
		- int(second["damage"])
	expected_enemies[0]["enrage_stacks"] = 2
	_check(enemies.get_enemies() == expected_enemies,
		label + " exact foe HP and two stacks, the plain foe untouched")
	_check(deck.energy == 0 and deck.hand.count(id) == 0 and deck.discard_pile == [id, id]
		and deck._rng.state == before.rng, label + " two separate payments, no RNG")
	var settled := _snapshot(state)
	_check(not service.play_card(deck, party, enemies, id, 1).get("ok", false)
		and _snapshot(state) == settled, label + " no third hit, stack or retaliation")


func _rejection(problem: String) -> void:
	var id: String = PRINTINGS.keys()[0]
	var keyword := problem.begins_with("keyword_")
	var mode := problem.trim_prefix("keyword_") if keyword else problem
	var f := _fixture(id, 1 if mode == "front" else 2)
	var target := 1
	if keyword:
		# The chosen foe really carries Thorns 3 and Enrage, and the Duelist really
		# holds Block, during every refusal: an admitted play would pay, move,
		# retaliate or gain a stack visibly in the snapshots below.
		f.enemies._enemies[0]["thorns"] = 3
		f.enemies._enemies[0]["enrage"] = true
		_check(f.party.start_player_turn() and f.party.gain_block(2, 2),
			"keyword refusal fixture has real Block")
	match mode:
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
		"bad_thorns": f.enemies._enemies[0]["thorns"] = "3"
		"bad_enrage": f.enemies._enemies[0]["enrage"] = 1
		"bad_enrage_stacks": f.enemies._enemies[0]["enrage_stacks"] = 4
	var before := _snapshot(f)
	for attempt in range(2):
		_check(not service.play_card(f.deck, f.party, f.enemies, id, target).get("ok", false),
			problem + " refused " + str(attempt))
		_check(_snapshot(f) == before, problem + " full no-write/RNG snapshot")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
