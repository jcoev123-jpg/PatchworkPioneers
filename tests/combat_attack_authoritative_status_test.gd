extends SceneTree
## Source-of-truth regression: every modifier below lives on the real actor.

const ATTACK_IDS := [
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_all_five_sources()
	_test_tinker_sequencing_and_bomb_slots()
	_test_swapped_identity()
	_test_confirmed_status_and_turn_boundary()
	_test_fail_closed_and_purity()
	_test_seeded_replay()
	for failure in failures:
		printerr(failure)
	print("combat_attack_authoritative_status_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(party.is_valid() and party.get_hero(1).hp == 40
		and party.get_hero(2).hp == 30 and party.get_hero(3).hp == 26,
		"actual starter hero identities and maximum HP")
	_check(party.gain_block(1, 6), "Warden starts with six combat-opening Block")
	return party


func _enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "foe_a", "max_hp": 60},
		{"id": "foe_b", "max_hp": 60},
		{"id": "foe_c", "max_hp": 60}])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"real three-enemy roster has stable slots")
	return enemies


func _deck(wanted: Array, seed_value: int = 3817) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var authored := StarterCards.new().get_starting_deck()
	var deck := CombatDeck.new(authored, rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.hand.size() == 5,
		"seeded authentic deck starts 3-energy/5-draw turn")
	var tries := 0
	while not _has_copies(deck.hand, wanted) and not deck.draw_pile.is_empty():
		deck.draw_extra(1)
		tries += 1
		if tries > authored.size():
			break
	_check(_has_copies(deck.hand, wanted), "all requested authored copies held")
	_check(deck.hand.size() + deck.draw_pile.size() + deck.discard_pile.size() == authored.size(),
		"starter deck multiset size conserved")
	return deck


func _has_copies(hand: Array[String], wanted: Array) -> bool:
	var remaining := hand.duplicate()
	for id in wanted:
		var at := remaining.find(id)
		if at == -1:
			return false
		remaining.remove_at(at)
	return true


func _state(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	return {"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"active": deck.turn_active, "rng": deck._rng.state, "rng_seed": deck._rng.seed,
		"party": party.get_heroes(), "enemies": enemies.get_enemies(),
		"victory": enemies.is_victorious()}


func _owner_weak(party: CombatParty, owner: String) -> void:
	var matches := 0
	for hero in party._heroes:
		if hero["id"] == owner:
			hero["statuses"] = {"weak": 1, "bleed": 1}
			matches += 1
	_check(matches == 1, "fixture Weak belongs to one actual owner: " + owner)


func _forecast_pure(service: CombatAttackCards, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, id: String, attacker: Dictionary = {},
		defenders: Dictionary = {}) -> Dictionary:
	var before := _state(deck, party, enemies)
	var latch := service._tinker._consumed
	seed(56187)
	var next_global := randi()
	seed(56187)
	var result := service.forecast_attack(deck, party, enemies, id, attacker, defenders)
	_check(service.forecast_attack(deck, party, enemies, id, attacker, defenders) == result,
		id + ": repeated forecast is deterministic")
	_check(_state(deck, party, enemies) == before and service._tinker._consumed == latch,
		id + ": repeated forecasts preserve every model and latch")
	_check(randi() == next_global, id + ": forecast leaves real global RNG untouched")
	return result


func _test_all_five_sources() -> void:
	var free := {"warden_strike": 6, "warden_shield_bash": 8, "seamstress_prick": 3,
		"tinker_pop_shot": 8, "tinker_scrap_bomb": 7}
	var with_weak_exposed := {"warden_strike": 6, "warden_shield_bash": 9,
		"seamstress_prick": 3, "tinker_pop_shot": 9, "tinker_scrap_bomb": 7}
	for id in ATTACK_IDS:
		for affected in [false, true]:
			var deck := _deck([id])
			var party := _party()
			var enemies := _enemies()
			var service := CombatAttackCards.new()
			var definition := StarterCards.new().get_definition(id)
			if affected:
				_owner_weak(party, definition.owner)
				enemies._enemies[0]["statuses"] = {"exposed": 1, "bleed": 2}
				enemies._enemies[2]["statuses"] = {"exposed": 1}
			_check(enemies.gain_block(1, 2), id + ": living target really has Block")
			var expected: int = with_weak_exposed[id] if affected else free[id]
			# Deliberately conflicting but well-formed snapshots cannot override actors.
			var stale_owner := {"weak": 0, "exposed": 4} if affected else {"weak": 7}
			var stale_targets := {1: {"exposed": 0}, 2: {"exposed": 5}} if affected else {1: {"exposed": 8}}
			var forecast := _forecast_pure(service, deck, party, enemies, id,
				stale_owner, stale_targets)
			var positions := [1, 2, 3] if id == "tinker_scrap_bomb" else [1]
			var expected_hits := []
			for position in positions:
				var damage: int = expected
				if id == "tinker_scrap_bomb" and position == 2 and affected:
					damage = 5 # floor(7*3/4); slot 2 is not Exposed.
				expected_hits.append({"position": position, "damage": damage})
			if id != "tinker_scrap_bomb":
				_check({"position": 1, "damage": expected} in forecast.hits
					and forecast.requires_selection, id + ": single-target forecast uses real counters")
			else:
				_check(forecast.hits == expected_hits and not forecast.requires_selection,
					"Bomb forecast independently modifies all three recipients in slot order")
			var before := _state(deck, party, enemies)
			var target := 0 if id == "tinker_scrap_bomb" else 1
			var event := service.play_attack(deck, party, enemies, id, target, stale_owner, stale_targets)
			_check(event.ok and event.hits.size() == positions.size(),
				id + ": paid action resolves every authorized recipient")
			if not event.ok:
				continue
			for hit in event.hits:
				var want: int = expected
				if id == "tinker_scrap_bomb" and hit.position == 2 and affected:
					want = 5
				var block: int = 2 if hit.position == 1 else 0
				var applied := {"weak": 1} if id == "warden_shield_bash" else (
					{"bleed": 3} if id == "seamstress_prick" else {})
				_check(hit.damage == want and hit.block_absorbed == mini(block, want)
					and hit.hp_loss == want - mini(block, want)
					and hit.statuses == applied, id + ": exact modified attack, Block and status event")
				var enemy := enemies.get_enemy(hit.position)
				_check(enemy.hp == 60 - hit.hp_loss and enemy.block == block - hit.block_absorbed,
					id + ": authoritative enemy HP and Block reflect hit")
				var prior: Dictionary = before.enemies[hit.position - 1]
				var status_before: Dictionary = prior.get("statuses", {})
				var statuses_after: Dictionary = status_before.duplicate()
				for name in applied:
					statuses_after[name] = statuses_after.get(name, 0) + applied[name]
				_check(enemy.get("statuses", {}) == statuses_after,
					id + ": status persists once, neither status ages")
			_check(deck.energy == 3 - definition.cost
				and deck.discard_pile.size() == before.discard.size() + 1
				and deck.hand.size() == before.hand.size() - 1
				and deck._rng.state == before.rng
				and party.get_heroes() == before.party,
				id + ": single spend/discard, no party or RNG mutation")
			_check(enemies.get_enemies().size() == 3, id + ": original roster size retained")


func _test_tinker_sequencing_and_bomb_slots() -> void:
	var service := CombatAttackCards.new()
	var deck := _deck(["tinker_pop_shot", "tinker_pop_shot"])
	var party := _party()
	var enemies := _enemies()
	_owner_weak(party, "tinker")
	enemies._enemies[0]["statuses"] = {"exposed": 1}
	enemies._enemies[1]["statuses"] = {"exposed": 1}
	for entry in [{"position": 1, "damage": 9}, {"position": 2, "damage": 5}]:
		var forecast := _forecast_pure(service, deck, party, enemies, "tinker_pop_shot")
		_check(entry in forecast.hits, "Pop Shot forecast sees correct first-attack latch")
		var result := service.play_attack(deck, party, enemies, "tinker_pop_shot", entry.position)
		_check(result.ok and result.hits[0].damage == entry.damage,
			"first Pop Shot 9, second Pop Shot 5 using one final floor")
	_check(deck.energy == 1 and service._tinker._consumed,
		"first attack applies bonus once, both Pop Shots paid")
	var before_reset := _state(deck, party, enemies)
	service.start_player_turn()
	_check(_state(deck, party, enemies) == before_reset and not service._tinker._consumed,
		"Tinker reset affects only attack latch")
	_check(deck.end_turn() and deck.start_turn(), "new player turn advances deck")
	for i in range(12):
		if deck.hand.has("tinker_pop_shot"):
			break
		deck.draw_extra(1)
	_check(deck.hand.has("tinker_pop_shot"), "held copy for reset Tinker test")
	var renewed := service.play_attack(deck, party, enemies, "tinker_pop_shot", 1)
	_check(renewed.ok and renewed.hits[0].damage == 9, "new player turn restores +3")

	var bombs := CombatAttackCards.new()
	var bomb_deck := _deck(["tinker_scrap_bomb"])
	var bomb_party := _party()
	var foes := _enemies()
	_owner_weak(bomb_party, "tinker")
	_check(foes.apply_damage(2, 60) and foes.is_slain(2), "middle enemy slain in-place")
	foes._enemies[2]["statuses"] = {"exposed": 1}
	var forecast_bomb := _forecast_pure(bombs, bomb_deck, bomb_party, foes,
		"tinker_scrap_bomb")
	_check(forecast_bomb.hits == [{"position": 1, "damage": 5},
		{"position": 3, "damage": 7}], "slain slot skipped; Weak/Exposed computed separately")
	var events := bombs.play_attack(bomb_deck, bomb_party, foes, "tinker_scrap_bomb")
	_check(events.ok and events.hits.map(func(e): return e.damage) == [5, 7]
		and events.hits.map(func(e): return e.position) == [1, 3],
		"target-free Bomb resolves noncompact original slot identities")
	_check(foes.get_enemy(2).hp == 0 and foes.get_enemy(2).position == 2,
		"skipped slain enemy remains unchanged in position 2")


func _test_swapped_identity() -> void:
	for entry in [
		{"mover": 1, "owner": "warden", "card": "warden_strike", "damage": 6},
		{"mover": 3, "owner": "tinker", "card": "tinker_pop_shot", "damage": 9}
	]:
		var party := _party()
		var direction := 1 if entry.mover == 1 else -1
		var proposed := CombatPositionSwaps.preview_adjacent_swap(party, entry.mover, direction)
		_check(proposed.ok and proposed.heroes.size() == 3,
			"existing adjacent swap validates legal living movement")
		if not proposed.ok:
			continue
		party._heroes.assign(proposed.heroes)
		_owner_weak(party, entry.owner)
		var moved := party.get_hero(2)
		_check(moved.id == entry.owner and moved.statuses.weak == 1,
			"real current slot 2 carries moved owner status")
		var enemies := _enemies()
		enemies._enemies[0]["statuses"] = {"exposed": 1}
		var deck := _deck([entry.card])
		var service := CombatAttackCards.new()
		var forecast := _forecast_pure(service, deck, party, enemies, entry.card)
		_check({"position": 1, "damage": entry.damage} in forecast.hits,
			"moved actor forecast resolves status by owner ID")
		var result := service.play_attack(deck, party, enemies, entry.card, 1)
		_check(result.ok and result.hits[0].damage == entry.damage,
			"moved actor committed attack resolves status by owner ID")


func _test_confirmed_status_and_turn_boundary() -> void:
	for id in ["seamstress_prick", "warden_shield_bash"]:
		var deck := _deck([id])
		var party := _party()
		var foes := _enemies()
		var amount := 3 if id == "seamstress_prick" else 1
		var status := "bleed" if id == "seamstress_prick" else "weak"
		_check(foes.gain_block(1, 100), "positive Block fully absorbs status hit")
		var service := CombatAttackCards.new()
		var before := _forecast_pure(service, deck, party, foes, id)
		_check(before.playable and foes.get_enemy(1).get("statuses", {}).is_empty(),
			"status preview never applies its on-hit counter")
		var hit := service.play_attack(deck, party, foes, id, 1)
		_check(hit.ok and hit.hits[0].hp_loss == 0
			and foes.get_enemy(1).statuses == {status: amount},
			"paid blocked hit persists exactly one passive-adjusted status")
		var original := foes.get_enemies()
		var tick := CombatStatusTurnBatch.new().tick_side("enemies", original)
		_check(tick.ok and tick.actors[0].get("statuses", {}) == (
			{status: amount - 1} if amount > 1 else {}),
			"owner-boundary status decremented exactly once")
		_check(tick.actors[0].hp == 60 - (amount if status == "bleed" else 0)
			and tick.actors[0].block == 100 - hit.hits[0].block_absorbed,
			"Bleed bypasses remaining Block; Weak does not deal direct HP damage")
		_check(foes.get_enemies() == original, "batch proposal and forecast do not age live actors")
		var again := service.play_attack(deck, party, foes, id, 1)
		_check(not again.ok and foes.get_enemy(1).statuses == {status: amount},
			"unheld replay cannot double-apply status")


func _test_fail_closed_and_purity() -> void:
	for bad in [{"weak": -1}, {"weak": 0.5}, {"poison": 1}, {2: 1}]:
		var deck := _deck(["tinker_scrap_bomb"])
		var party := _party()
		var enemies := _enemies()
		party._heroes[2]["statuses"] = bad
		var service := CombatAttackCards.new()
		var before := _state(deck, party, enemies)
		_check(not _forecast_pure(service, deck, party, enemies,
			"tinker_scrap_bomb").playable, "invalid actual owner counters forecast reject")
		_check(not service.play_attack(deck, party, enemies, "tinker_scrap_bomb").ok
			and _state(deck, party, enemies) == before and not service._tinker._consumed,
			"invalid owner counters reject before any mutation")
	for bad in [{"exposed": -1}, {"exposed": 1.5}, {"other": 4}]:
		var deck := _deck(["tinker_scrap_bomb"])
		var party := _party()
		var enemies := _enemies()
		enemies._enemies[2]["statuses"] = bad
		var service := CombatAttackCards.new()
		var before := _state(deck, party, enemies)
		_check(not service.play_attack(deck, party, enemies, "tinker_scrap_bomb").ok
			and not _forecast_pure(service, deck, party, enemies,
				"tinker_scrap_bomb").playable
			and _state(deck, party, enemies) == before,
			"invalid late actual defender counter rejects batch atomically")
	var deck := _deck(["tinker_scrap_bomb"])
	var party := _party()
	var foes := _enemies()
	var service := CombatAttackCards.new()
	var before := _state(deck, party, foes)
	for legacy in [{"weak": -1}, {"weak": 1.5}, {"bleed": "1"}, {"other": 1}]:
		_check(not service.play_attack(deck, party, foes, "tinker_scrap_bomb",
			0, legacy).ok, "malformed legacy attacker rejected")
		_check(not service.forecast_attack(deck, party, foes,
			"tinker_scrap_bomb", legacy).playable, "malformed legacy forecast rejected")
	for legacy in [{3: {"exposed": -1}}, {3: {"exposed": 0.4}}, {4: {}}, {"3": {}}]:
		_check(not service.play_attack(deck, party, foes, "tinker_scrap_bomb",
			0, {}, legacy).ok, "malformed legacy recipient rejected")
	_check(_state(deck, party, foes) == before and not service._tinker._consumed,
		"legacy malformed input leaves deck, full roster, latch and RNG unchanged")
	foes._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	deck = _deck(["warden_shield_bash"])
	before = _state(deck, party, foes)
	_check(not service.play_attack(deck, party, foes, "warden_shield_bash", 1).ok
		and not _forecast_pure(service, deck, party, foes, "warden_shield_bash").playable
		and _state(deck, party, foes) == before,
		"status addition overflow rejected before spending or altering actor")


func _replay(seed_value: int) -> Dictionary:
	var deck := _deck(["tinker_pop_shot", "seamstress_prick"], seed_value)
	var party := _party()
	var foes := _enemies()
	_owner_weak(party, "tinker")
	foes._enemies[1]["statuses"] = {"exposed": 1}
	var service := CombatAttackCards.new()
	var first := service.play_attack(deck, party, foes, "tinker_pop_shot", 2)
	var next := service.play_attack(deck, party, foes, "seamstress_prick", 3)
	return {"first": first, "next": next, "state": _state(deck, party, foes)}


func _test_seeded_replay() -> void:
	var a := _replay(378119)
	var b := _replay(378119)
	_check(a == b and a.first.ok and a.first.hits[0].damage == 9
		and a.next.ok and a.next.hits[0].statuses == {"bleed": 3},
		"same-seed two paid authored attacks replay exact events and complete state")
