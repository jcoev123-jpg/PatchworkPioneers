extends SceneTree
## Deterministic real-deck and real-roster D2-1 Bleed pool regression.

var failures: Array[String] = []
var checks := 0
var service := CombatSeamstressPoolBleed.new()


func _initialize() -> void:
	_test_running_stitch()
	_test_hemorrhage()
	_test_blanket_and_red_thread()
	_test_failed_plays()
	_test_seeded_trace()
	for failure in failures:
		printerr(failure)
	print("combat_seamstress_pool_bleed_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _party(seamstress_position: int = 2) -> CombatParty:
	var ids := ["warden", "seamstress", "tinker"]
	ids.erase("seamstress")
	ids.insert(seamstress_position - 1, "seamstress")
	var definitions: Array[Dictionary] = []
	var hp := {"warden": 40, "seamstress": 30, "tinker": 26}
	for id in ids:
		definitions.append({"id": id, "max_hp": hp[id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(seamstress_position)["id"] == "seamstress",
		"fixture has unique living Seamstress at current position %d" % seamstress_position)
	return party


func _enemies(count: int = 3, max_hp: int = 12) -> CombatEnemies:
	var definitions: Array[Dictionary] = []
	for index in range(count):
		definitions.append({"id": "foe%d" % (index + 1), "max_hp": max_hp})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == count,
		"fixture has %d real original enemy slots" % count)
	return enemies


func _deck(ids: Array[String], seed_value: int = 217) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cards: Array[String] = StarterCards.new().get_starting_deck()
	# Only actual starter IDs and the real authored pool IDs are put in the deck.
	cards.append_array(ids)
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		"fixture starts a genuine shared-deck, three-energy turn")
	for id in ids:
		while not deck.hand.has(id) and not deck.draw_pile.is_empty():
			_check(deck.draw_extra(1) == 1, "real extra draw obtains " + id)
		_check(deck.hand.has(id), "fixture holds the actual catalog ID " + id)
	return deck


func _fixture(id: String, owner_position: int = 2, enemy_count: int = 3,
		enemy_hp: int = 12) -> Dictionary:
	return {"deck": _deck([id]), "party": _party(owner_position),
		"enemies": _enemies(enemy_count, enemy_hp)}


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	return {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "turn": deck.turn_active,
		"energy": deck.energy, "combat_turn": deck.combat_state.player_turn_active,
		"combat_energy": deck.combat_state.energy, "rng": deck._rng.state,
		"party": party.get_heroes() if party != null else [],
		"enemies": enemies.get_enemies() if enemies != null else []}


func _hit(position: int, damage: int, block: int, hp_loss: int,
		statuses: Dictionary) -> Dictionary:
	return {"position": position, "damage": damage, "block_absorbed": block,
		"hp_loss": hp_loss, "statuses": statuses}


## Construct the expected full post-state independently of resolver output.
## In particular, zero Bleed deltas do not create a new status key.
func _accept(f: Dictionary, id: String, target: int, hits: Array,
		cost: int, label: String) -> void:
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	var before := _snapshot(deck, party, enemies)
	_check(before.turn and before.energy == 3 and before.hand.has(id)
		and before.party.size() == 3 and before.enemies.size() > 0,
		label + ": actual playable preconditions")
	var result := service.play_card(deck, party, enemies, id, target)
	_check(result == {"ok": true, "hits": hits}, label + ": exact emitted hits")
	var expected: Dictionary = before.duplicate(true)
	expected.hand.erase(id)
	expected.discard.append(id)
	expected.energy -= cost
	expected.combat_energy -= cost
	for hit in hits:
		var enemy: Dictionary = expected.enemies[hit.position - 1]
		enemy["hp"] -= hit.hp_loss
		enemy["block"] -= hit.block_absorbed
		for status in hit.statuses:
			if hit.statuses[status] == 0:
				continue
			if not enemy.has("statuses"):
				enemy["statuses"] = {}
			enemy["statuses"][status] = enemy["statuses"].get(status, 0) + hit.statuses[status]
	_check(_snapshot(deck, party, enemies) == expected,
		label + ": exact full piles, energy, RNG, party and enemy snapshot")


func _reject(f: Dictionary, id: String, target: int, label: String) -> void:
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	var before := _snapshot(deck, party, enemies)
	_check(service.play_card(deck, party, enemies, id, target) == {"ok": false, "hits": []},
		label + ": fail closed")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": no card, energy, roster, status or RNG mutation")


func _test_running_stitch() -> void:
	for upgraded in [false, true]:
		var id := "seamstress_running_stitch" + ("_plus" if upgraded else "")
		var base := 3 if upgraded else 2
		var bleed := 5 if upgraded else 4
		var normal := _fixture(id, 1 if upgraded else 2)
		_accept(normal, id, 1, [_hit(1, base, 0, base, {"bleed": bleed})],
			1, id + " normal FROM 1/2")

		var blocked := _fixture(id, 3)
		_check(blocked.enemies.gain_block(3, 2), id + " two Block preloaded")
		_accept(blocked, id, 3, [_hit(3, base, 2, base - 2, {"bleed": bleed})],
			1, id + " FROM 3, Block before HP")

		var modified := _fixture(id)
		modified.party._heroes[1]["statuses"] = {"weak": 1}
		_check(modified.enemies.apply_statuses({2: {"exposed": 1}}),
			id + " defender Exposed preloaded")
		# CombatStatuses floors once: floor(printed damage * 9 / 8).
		_accept(modified, id, 2, [_hit(2, 3 if upgraded else 2, 0,
			3 if upgraded else 2, {"bleed": bleed})], 1,
			id + " persisted Weak and Exposed, single final floor")

		var lethal := _fixture(id, 2, 1, 1)
		_accept(lethal, id, 1, [_hit(1, base, 0, 1, {"bleed": bleed})],
			1, id + " lethal status remains on slain slot")
		_check(lethal.enemies.is_victorious() and
			lethal.enemies.get_enemy(1).get("statuses", {}).get("bleed") == bleed,
			id + " retained lethal on-hit status without revival")


func _test_hemorrhage() -> void:
	for upgraded in [false, true]:
		var id := "seamstress_hemorrhage_hem" + ("_plus" if upgraded else "")
		var cost := 1 if upgraded else 2
		var positive := _fixture(id, 1 if upgraded else 3)
		_check(positive.enemies.apply_statuses({2: {"bleed": 3, "weak": 2, "exposed": 1}}),
			id + " real status seed")
		_accept(positive, id, 2, [_hit(2, 0, 0, 0, {"bleed": 3})], cost,
			id + " doubles three to six, no passive bonus")
		_check(positive.enemies.get_enemy(2)["statuses"] ==
			{"bleed": 6, "weak": 2, "exposed": 1},
			id + " unrelated statuses retained")

		var zero := _fixture(id)
		_check(zero.enemies.apply_statuses({1: {"bleed": 0, "weak": 1}}),
			id + " zero-bleed seed accepted")
		_accept(zero, id, 1, [_hit(1, 0, 0, 0, {"bleed": 0})], cost,
			id + " zero remains zero and still pays once")


func _test_blanket_and_red_thread() -> void:
	for upgraded in [false, true]:
		var blanket := "seamstress_blanket_stitch" + ("_plus" if upgraded else "")
		var amount := 4 if upgraded else 3
		for count in [1, 2, 3]:
			var f := _fixture(blanket, 3 if upgraded else 2, count)
			var hits: Array = []
			for position in range(1, count + 1):
				hits.append(_hit(position, 0, 0, 0, {"bleed": amount}))
			_accept(f, blanket, 0, hits, 2, blanket + " all %d living foes" % count)
		var gap := _fixture(blanket)
		_check(gap.enemies.apply_damage(2, 12) and gap.enemies.is_slain(2),
			blanket + " middle slot slain in original roster")
		_check(gap.enemies.apply_statuses({3: {"bleed": 2}}),
			blanket + " later slot has previous Bleed")
		_accept(gap, blanket, 0, [_hit(1, 0, 0, 0, {"bleed": amount}),
			_hit(3, 0, 0, 0, {"bleed": amount})], 2,
			blanket + " skips slain middle, stacks slot 3")

		var red := "seamstress_red_thread" + ("_plus" if upgraded else "")
		var red_bleed := 9 if upgraded else 7
		var single := _fixture(red, 1 if upgraded else 3)
		_check(single.enemies.gain_block(3, 4) and
			single.enemies.apply_statuses({3: {"bleed": 2, "exposed": 2, "weak": 1}}),
			red + " existing Block and status stacks")
		_accept(single, red, 3, [_hit(3, 0, 0, 0,
			{"bleed": red_bleed, "exposed": 1})], 2,
			red + " stacks only recipient, no direct hit")


func _test_failed_plays() -> void:
	var running := "seamstress_running_stitch"
	var blanket := "seamstress_blanket_stitch"
	_reject(_fixture(running), "seamstress_needle_pin", 1, "unsupported authored ID")
	_reject(_fixture(running), "totally_unknown", 1, "unknown ID")
	_reject(_fixture(blanket), running, 1, "genuinely absent held card")
	var inactive := _fixture(running)
	_check(inactive.deck.end_turn() and not inactive.deck.turn_active,
		"inactive turn fixture ended normally")
	_reject(inactive, running, 1, "inactive player turn")
	var energy := _fixture(blanket)
	_check(energy.deck.try_spend_energy(2) and energy.deck.energy == 1,
		"insufficient-energy fixture real spend")
	_reject(energy, blanket, 0, "insufficient energy")
	var downed := _fixture(running)
	_check(downed.party.apply_damage(2, 30) and downed.party.is_downed(2),
		"actual Seamstress downed")
	_reject(downed, running, 1, "downed owner")
	_reject(_fixture(blanket, 1), blanket, 0, "Blanket FROM front illegal")
	var target := _fixture(running)
	_reject(target, running, 0, "missing selected enemy")
	_reject(target, running, 4, "invalid selected enemy position")
	_reject(_fixture(running, 2, 1), running, 3, "empty original enemy slot")
	_check(target.enemies.apply_damage(2, 12) and target.enemies.is_slain(2),
		"slain target fixture prepared")
	_reject(target, running, 2, "slain chosen target")
	_reject(_fixture(blanket), blanket, 1, "area rejects selected target")
	var victorious := _fixture(blanket, 2, 1)
	_check(victorious.enemies.apply_damage(1, 12) and victorious.enemies.is_victorious(),
		"no living targets fixture prepared")
	_reject(victorious, blanket, 0, "no eligible enemy in victorious fight")
	var overflow := _fixture(blanket)
	_check(overflow.enemies.apply_statuses({3: {"bleed": CombatEnemies.MAX_INT - 2}}),
		"legal large counter in later area recipient")
	_reject(overflow, blanket, 0, "late area overflow atomically rejected")
	var doubling := _fixture("seamstress_hemorrhage_hem")
	_check(doubling.enemies.apply_statuses({1: {"bleed": CombatEnemies.MAX_INT}}),
		"max status preloaded through real roster")
	_reject(doubling, "seamstress_hemorrhage_hem", 1, "Hem doubled counter overflow")
	var malformed := _fixture(running)
	malformed.enemies._enemies[1]["statuses"] = {"bleed": "invalid"}
	_check(not malformed.enemies.can_apply_statuses({}), "malformed late roster is detected")
	_reject(malformed, running, 1, "inconsistent late status record")


func _trace(seed_value: int) -> Dictionary:
	var deck := _deck(["seamstress_running_stitch", "seamstress_blanket_stitch"], seed_value)
	var party := _party()
	var enemies := _enemies()
	_check(enemies.gain_block(1, 1) and enemies.apply_statuses({3: {"bleed": 2}}),
		"replay initial enemy Block and Bleed seeded")
	var first := service.play_card(deck, party, enemies, "seamstress_running_stitch", 1)
	var second := service.play_card(deck, party, enemies, "seamstress_blanket_stitch", 0)
	_check(first == {"ok": true, "hits": [_hit(1, 2, 1, 1, {"bleed": 4})]}
		and second == {"ok": true, "hits": [
			_hit(1, 0, 0, 0, {"bleed": 3}),
			_hit(2, 0, 0, 0, {"bleed": 3}),
			_hit(3, 0, 0, 0, {"bleed": 3})]},
		"replay real mixed two-card trace succeeds with exact rules")
	return {"first": first, "second": second, "final": _snapshot(deck, party, enemies)}


func _test_seeded_trace() -> void:
	var a := _trace(99421)
	var b := _trace(99421)
	_check(a == b, "same seed reproduces all events, full piles, RNG, parties and enemies")
