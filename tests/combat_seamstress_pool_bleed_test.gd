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
	_test_forecast_parity()
	_test_forecast_rejections()
	_test_worn_attack_patches()
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


## Each candidate is a catalog-defined, held card in an active seeded deck.
## Independently derive the expected numeric damage/statuses, then compare
## the projection against a separately prepared authoritative transaction.
func _forecast_seed(f: Dictionary, position: int) -> void:
	f.party._heroes[1]["statuses"] = {"weak": 1}
	_check(f.enemies.apply_statuses({position: {"bleed": 3, "exposed": 1}}),
		"forecast preloads authentic Bleed and Exposed")
	_check(f.enemies.gain_block(position, 2),
		"forecast preloads authentic defender Block")


func _test_forecast_parity() -> void:
	for slug in ["running_stitch", "hemorrhage_hem", "red_thread"]:
		for upgraded in [false, true]:
			var id: String = "seamstress_" + slug + ("_plus" if upgraded else "")
			var definition: Dictionary = SeamstressPoolCards.new().get_definition(id)
			_check(definition.get("id") == id and definition.target_kind == "enemy_single"
				and definition.from_positions.has(2) and definition.to_positions.has(1)
				and definition.to_positions.has(2), "catalog forecast contract " + id)
			for position in [1, 2]:
				var f := _fixture(id)
				var committed := _fixture(id)
				_forecast_seed(f, position)
				_forecast_seed(committed, position)
				var before := _snapshot(f.deck, f.party, f.enemies)
				_check(before == _snapshot(committed.deck, committed.party, committed.enemies),
					"independent identical seeded authoritative fixture " + id)
				var base_damage: int = int(definition.effects.get("damage", 0))
				@warning_ignore("integer_division")
				var adjusted: int = base_damage * 9 / 8
				var absorbed: int = mini(2, adjusted)
				var hp_loss: int = mini(12, adjusted - absorbed)
				var next_bleed := 6 if slug == "hemorrhage_hem" else \
					3 + int(definition.effects.get("bleed", 0)) + 1
				var next_exposed := 2 if slug == "red_thread" else 1
				var expected := {"ok": true, "position": position, "cost": definition.cost,
					"damage": adjusted, "block_absorbed": absorbed, "hp_loss": hp_loss,
					"bleed_before": 3, "bleed_after": next_bleed,
					"exposed_before": 1, "exposed_after": next_exposed}
				for repeat in range(3):
					_check(service.forecast_single(f.deck, f.party, f.enemies, id, position)
						== expected, "pure exact catalog forecast " + id + " slot %d" % position)
					_check(_snapshot(f.deck, f.party, f.enemies) == before,
						"repeat forecast retains energy, piles, actors, statuses and RNG " + id)
				var event: Dictionary = service.play_card(
					committed.deck, committed.party, committed.enemies, id, position)
				_check(event.get("ok", false) and event.hits.size() == 1,
					"matching real resolution succeeded " + id)
				if event.get("ok", false) and event.hits.size() == 1:
					var hit: Dictionary = event.hits[0]
					_check(hit.position == expected.position and hit.damage == expected.damage
						and hit.block_absorbed == expected.block_absorbed
						and hit.hp_loss == expected.hp_loss,
						"forecast damage parity vs actual play " + id)
					var after: Dictionary = committed.enemies.get_enemy(position)
					_check(after.hp == before.enemies[position - 1].hp - expected.hp_loss
						and after.block == 2 - expected.block_absorbed
						and after.get("statuses", {}).get("bleed", 0) == next_bleed
						and after.get("statuses", {}).get("exposed", 0) == next_exposed,
						"forecast status, HP and Block parity " + id)
					_check(committed.party.get_heroes() == before.party
						and committed.deck.energy == 3 - int(definition.cost)
						and committed.deck._rng.state == before.rng,
						"real play ages no statuses and uses no RNG " + id)
	# Zero Bleed must never gain Seamstress's passive through Hem doubling.
	for id in ["seamstress_hemorrhage_hem", "seamstress_hemorrhage_hem_plus"]:
		var zero := _fixture(id)
		var before := _snapshot(zero.deck, zero.party, zero.enemies)
		var forecast := service.forecast_single(zero.deck, zero.party, zero.enemies, id, 1)
		_check(forecast.ok and forecast.bleed_before == 0 and forecast.bleed_after == 0
			and forecast.damage == 0 and _snapshot(zero.deck, zero.party, zero.enemies) == before,
			"zero Hem preview stays zero without any passive or mutation " + id)
		_check(service.play_card(zero.deck, zero.party, zero.enemies, id, 1).ok
			and zero.enemies.get_enemy(1).get("statuses", {}).get("bleed", 0) == 0,
			"zero Hem committed status agrees with forecast " + id)


func _forecast_reject(f: Dictionary, id: String, position: int, reason: String) -> void:
	var before := _snapshot(f.deck, f.party, f.enemies)
	for repeat in range(2):
		_check(not service.forecast_single(f.deck, f.party, f.enemies, id, position)
			.get("ok", false), "forecast rejects " + reason)
		_check(_snapshot(f.deck, f.party, f.enemies) == before,
			"rejected forecast never spends or changes statuses/RNG " + reason)


func _test_forecast_rejections() -> void:
	var running := "seamstress_running_stitch"
	_forecast_reject(_fixture(running), "unknown", 1, "unknown card")
	_forecast_reject(_fixture(running), "seamstress_needle_pin", 1, "unsupported card")
	_forecast_reject(_fixture("seamstress_blanket_stitch"),
		"seamstress_blanket_stitch", 0, "area forecast")
	_forecast_reject(_fixture("seamstress_red_thread"), running, 1, "card not held")
	_forecast_reject(_fixture(running), running, 0, "missing position")
	_forecast_reject(_fixture(running), running, 4, "out-of-range position")
	_forecast_reject(_fixture(running, 2, 1), running, 2, "absent original slot")
	var inactive := _fixture(running)
	_check(inactive.deck.end_turn(), "forecast inactive turn staged")
	_forecast_reject(inactive, running, 1, "inactive turn")
	var unaffordable := _fixture("seamstress_red_thread")
	_check(unaffordable.deck.try_spend_energy(2), "forecast energy exhausted with real spend")
	_forecast_reject(unaffordable, "seamstress_red_thread", 1, "unaffordable card")
	var downed := _fixture(running)
	_check(downed.party.apply_damage(2, 30), "forecast owner downed authentically")
	_forecast_reject(downed, running, 1, "dead owner")
	var invalid_source := _fixture(running)
	invalid_source.party._heroes[1]["position"] = 4
	_forecast_reject(invalid_source, running, 1, "source position illegal")
	var slain := _fixture(running)
	_check(slain.enemies.apply_damage(1, 12), "forecast target slain authentically")
	_forecast_reject(slain, running, 1, "slain target")
	var overflow := _fixture("seamstress_red_thread")
	_check(overflow.enemies.apply_statuses({1: {"bleed": CombatEnemies.MAX_INT - 3}}),
		"forecast large Bleed stack staged legally")
	_forecast_reject(overflow, "seamstress_red_thread", 1, "stack overflow")
	var hem_overflow := _fixture("seamstress_hemorrhage_hem")
	_check(hem_overflow.enemies.apply_statuses({1: {"bleed": CombatEnemies.MAX_INT}}),
		"forecast Hem maximum Bleed staged legally")
	_forecast_reject(hem_overflow, "seamstress_hemorrhage_hem", 1, "double overflow")
	var bad_status := _fixture(running)
	bad_status.enemies._enemies[1]["statuses"] = {"exposed": "invalid"}
	_forecast_reject(bad_status, running, 1, "malformed other enemy status")


func _patch_context(party: CombatParty, wearer: String = "seamstress",
		sew_button: bool = true, sew_arm: bool = true) -> Dictionary:
	var raw_attacks: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(raw_attacks is Array, "m04_attack_patches catalog is an array")
	var definitions: Array[Dictionary] = []
	for entry in raw_attacks:
		if entry is Dictionary and entry.get("id") in ["button_eye", "pincushion_arm"]:
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var owned: Array = []
	if sew_button:
		owned.append("button_eye")
	if sew_arm:
		owned.append("pincushion_arm")
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, definitions, 3)
	_check(torn.is_valid() and wardrobe.is_valid(), "genuine run patch ledgers valid")
	if sew_button:
		var result: Dictionary = wardrobe.sew("button_eye", wearer, "HEAD",
			"sew_button_eye", wardrobe.get_snapshot())
		_check(result.get("ok", false) and wardrobe.get_snapshot()["worn"][wearer]["HEAD"] == "button_eye",
			"Button Eye sewn on " + wearer + " HEAD slot")
	if sew_arm:
		var result: Dictionary = wardrobe.sew("pincushion_arm", wearer, "ARM",
			"sew_pincushion_arm", wardrobe.get_snapshot())
		_check(result.get("ok", false) and wardrobe.get_snapshot()["worn"][wearer]["ARM"] == "pincushion_arm",
			"Pincushion Arm sewn on " + wearer + " ARM slot")
	return {"wardrobe": wardrobe, "torn": torn}


func _accept_custom(resolver: CombatSeamstressPoolBleed, f: Dictionary, id: String, target: int,
		hits: Array, cost: int, label: String) -> void:
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	var before := _snapshot(deck, party, enemies)
	_check(before.turn and before.energy == 3 and before.hand.has(id)
		and before.party.size() == 3 and before.enemies.size() > 0,
		label + ": actual playable preconditions")
	var result := resolver.play_card(deck, party, enemies, id, target)
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


func _reject_custom(resolver: CombatSeamstressPoolBleed, f: Dictionary, id: String,
		target: int, label: String) -> void:
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	var before := _snapshot(deck, party, enemies)
	_check(resolver.play_card(deck, party, enemies, id, target) == {"ok": false, "hits": []},
		label + ": fail closed")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": no card, energy, roster, status or RNG mutation")


func _test_worn_attack_patches() -> void:
	# AC1: Living Seamstress with Pincushion Arm gets +1 damage before Weak/Exposed and Block.
	for upgraded in [false, true]:
		var id := "seamstress_running_stitch" + ("_plus" if upgraded else "")
		var base_dmg := 3 if upgraded else 2
		var patched_dmg := base_dmg + 1
		var bleed := 5 if upgraded else 4

		# Pincushion Arm only (no Button Eye) to isolate damage math
		var party := _party(2)
		var ctx := _patch_context(party, "seamstress", false, true)
		var resolver := CombatSeamstressPoolBleed.new()
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
			and resolver._patches.is_valid()
			and resolver._patches.damage_bonus("seamstress") == 1
			and resolver._patches.damage_bonus("warden") == 0
			and resolver._patches.damage_bonus("tinker") == 0,
			id + ": binds valid Pincushion Arm to Seamstress")

		var normal := _fixture(id, 2)
		_accept_custom(resolver, normal, id, 1, [_hit(1, patched_dmg, 0, patched_dmg, {"bleed": bleed})],
			1, id + ": Pincushion Arm +1 damage (deals %d vs unpatched %d)" % [patched_dmg, base_dmg])

		var blocked := _fixture(id, 2)
		_check(blocked.enemies.gain_block(2, 2), id + ": two Block preloaded on target")
		_accept_custom(resolver, blocked, id, 2,
			[_hit(2, patched_dmg, 2, patched_dmg - 2, {"bleed": bleed})],
			1, id + ": Block absorbs before HP with patched damage")

		# Status multipliers before/after floor:
		# Weak: 25% less outgoing damage (3/4); Exposed: 50% more incoming damage (3/2); Both: 9/8; all floor.
		var modified := _fixture(id, 2)
		modified.party._heroes[1]["statuses"] = {"weak": 1}
		_check(modified.enemies.apply_statuses({3: {"exposed": 1}}), id + ": exposed defender preloaded")
		@warning_ignore("integer_division")
		var expected_mod_dmg: int = patched_dmg * 9 / 8
		_accept_custom(resolver, modified, id, 3,
			[_hit(3, expected_mod_dmg, 0, expected_mod_dmg, {"bleed": bleed})],
			1, id + ": Pincushion +1 applied before Weak/Exposed single final floor")

		var weak_only := _fixture(id, 2)
		weak_only.party._heroes[1]["statuses"] = {"weak": 1}
		@warning_ignore("integer_division")
		var expected_weak: int = patched_dmg * 3 / 4
		_accept_custom(resolver, weak_only, id, 1,
			[_hit(1, expected_weak, 0, expected_weak, {"bleed": bleed})],
			1, id + ": Weak only floor(damage * 3 / 4)")

		var exposed_only := _fixture(id, 2)
		_check(exposed_only.enemies.apply_statuses({1: {"exposed": 1}}), id + ": exposed defender preloaded")
		@warning_ignore("integer_division")
		var expected_exposed: int = patched_dmg * 3 / 2
		_accept_custom(resolver, exposed_only, id, 1,
			[_hit(1, expected_exposed, 0, expected_exposed, {"bleed": bleed})],
			1, id + ": Exposed only floor(damage * 3 / 2)")

	# AC2: Button Eye sewn to HEAD: first successful attack in combat applies Exposed 1 AFTER hit damage.
	for upgraded in [false, true]:
		var id := "seamstress_running_stitch" + ("_plus" if upgraded else "")
		var base_dmg := 3 if upgraded else 2
		var patched_dmg := base_dmg + 1
		var bleed := 5 if upgraded else 4

		var party := _party(2)
		var ctx := _patch_context(party, "seamstress", true, true)
		var resolver := CombatSeamstressPoolBleed.new()
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
			and resolver._patches.is_valid()
			and resolver._patches.exposed_for_first_hit("seamstress") == {"exposed": 1},
			id + ": binds valid Button Eye and Pincushion Arm")

		# First hit with pre-existing Exposed on defender:
		# Hit damage must use pre-existing Exposed (not boosted by Button Eye).
		# Then Button Eye adds Exposed 1, so defender ends up with Exposed 2.
		var first_fixture := _fixture(id, 2)
		_check(first_fixture.enemies.apply_statuses({1: {"exposed": 1}}), id + ": target starts with Exposed 1")
		@warning_ignore("integer_division")
		var hit1_dmg: int = patched_dmg * 3 / 2 # uses existing Exposed 1
		_accept_custom(resolver, first_fixture, id, 1,
			[_hit(1, hit1_dmg, 0, hit1_dmg, {"bleed": bleed, "exposed": 1})],
			1, id + ": first hit applies Button Eye Exposed 1 after hit damage without self-boosting")
		_check(first_fixture.enemies.get_enemy(1)["statuses"] == {"bleed": bleed, "exposed": 2},
			id + ": target has pre-existing 1 + Button Eye 1 = 2 Exposed")
		_check(resolver._patches.latch_snapshot().get("seamstress") == true,
			id + ": Button Eye latch is consumed after first successful hit")
		_check(resolver._patches.exposed_for_first_hit("seamstress").is_empty(),
			id + ": exposed_for_first_hit returns empty after latch consumed")

		# Second hit in same combat does NOT reapply Button Eye, but retains Pincushion Arm:
		var second_fixture := _fixture(id, 2)
		_check(second_fixture.enemies.gain_block(2, 1), id + ": second target setup")
		_accept_custom(resolver, second_fixture, id, 2,
			[_hit(2, patched_dmg, 1, patched_dmg - 1, {"bleed": bleed})],
			1, id + ": second attack in combat retains Pincushion Arm but applies no Button Eye Exposed")
		_check(second_fixture.enemies.get_enemy(2).get("statuses", {}).get("exposed", 0) == 0,
			id + ": second target received no Exposed")

	# Button Eye latch is NOT consumed by forecast, refused plays, or pure status cards.
	var party2 := _party(2)
	var ctx2 := _patch_context(party2, "seamstress", true, true)
	var resolver2 := CombatSeamstressPoolBleed.new()
	resolver2.bind_patch_wardrobe(ctx2.wardrobe, ctx2.torn)

	# 1. Forecast pure reads
	var f_prev := _fixture("seamstress_running_stitch", 2)
	var prev_before := _snapshot(f_prev.deck, f_prev.party, f_prev.enemies)
	for repeat in range(3):
		var fc: Dictionary = resolver2.forecast_single(f_prev.deck, f_prev.party, f_prev.enemies, "seamstress_running_stitch", 1)
		_check(fc.ok and fc.damage == 3 and fc.exposed_before == 0 and fc.exposed_after == 1,
			"forecast shows patched damage 3 and Button Eye Exposed 0 -> 1")
		_check(_snapshot(f_prev.deck, f_prev.party, f_prev.enemies) == prev_before,
			"forecast mutates no deck, actors, statuses or RNG")
		_check(resolver2._patches.latch_snapshot().get("seamstress") == false,
			"forecast does not consume Button Eye latch")

	# 2. Refused plays do not consume latch
	var f_rej := _fixture("seamstress_running_stitch", 2)
	_check(f_rej.deck.try_spend_energy(3), "drain energy for rejection")
	_reject_custom(resolver2, f_rej, "seamstress_running_stitch", 1, "unaffordable Running Stitch")
	_check(resolver2._patches.latch_snapshot().get("seamstress") == false,
		"refused play does not consume Button Eye latch")

	# 3. Pure status cards do not consume latch
	# Hemorrhage Hem:
	var f_hem := _fixture("seamstress_hemorrhage_hem", 2)
	_check(f_hem.enemies.apply_statuses({1: {"bleed": 2}}), "hem status preloaded")
	_accept_custom(resolver2, f_hem, "seamstress_hemorrhage_hem", 1,
		[_hit(1, 0, 0, 0, {"bleed": 2})], 2, "Hemorrhage Hem doubles bleed without latch")
	_check(resolver2._patches.latch_snapshot().get("seamstress") == false,
		"Hemorrhage Hem deals no attack damage and does not consume Button Eye")

	# Red Thread: deals 0 damage, applies bleed + authored exposed 1
	var f_red := _fixture("seamstress_red_thread", 2)
	_accept_custom(resolver2, f_red, "seamstress_red_thread", 1,
		[_hit(1, 0, 0, 0, {"bleed": 7, "exposed": 1})], 2, "Red Thread authored exposed without patch latch")
	_check(resolver2._patches.latch_snapshot().get("seamstress") == false,
		"Red Thread does not consume Button Eye latch")

	# Blanket Stitch: area bleed
	var f_blanket := _fixture("seamstress_blanket_stitch", 2, 2)
	_accept_custom(resolver2, f_blanket, "seamstress_blanket_stitch", 0,
		[_hit(1, 0, 0, 0, {"bleed": 3}), _hit(2, 0, 0, 0, {"bleed": 3})], 2, "Blanket Stitch area bleed")
	_check(resolver2._patches.latch_snapshot().get("seamstress") == false,
		"Blanket Stitch does not consume Button Eye latch")

	# Now Running Stitch FINALLY consumes the latch:
	var f_final := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver2, f_final, "seamstress_running_stitch", 1,
		[_hit(1, 3, 0, 3, {"bleed": 4, "exposed": 1})], 1, "Running Stitch consumes preserved latch")
	_check(resolver2._patches.latch_snapshot().get("seamstress") == true,
		"Button Eye latch is finally consumed")

	# AC4: Negative / isolation tests
	# 1. Foreign wearer (patches sewn to Warden only)
	var party_w := _party(2)
	var ctx_w := _patch_context(party_w, "warden", true, true)
	var resolver_w := CombatSeamstressPoolBleed.new()
	_check(resolver_w.bind_patch_wardrobe(ctx_w.wardrobe, ctx_w.torn)
		and resolver_w._patches.damage_bonus("seamstress") == 0
		and resolver_w._patches.exposed_for_first_hit("seamstress").is_empty(),
		"wardrobe sewn to Warden yields 0 bonus for Seamstress")
	var f_w := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver_w, f_w, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 4})], 1, "Warden patch wearer gives no bonus to Seamstress")

	# 2. Torn Seamstress: patches inactive
	var party_torn := _party(2)
	var ctx_torn := _patch_context(party_torn, "seamstress", true, true)
	var start_torn: Array = ctx_torn.torn.read_state().heroes
	_check(party_torn.apply_damage(2, 999) and party_torn.is_downed(2), "down seamstress to record tear")
	_check(ctx_torn.torn.observe_battle_end("seamstress_tear_check", start_torn, party_torn.get_heroes()).ok,
		"torn ledger records downed seamstress")
	# Heal in combat party so she can legally act in the test
	party_torn.heal(2, 30)
	var resolver_torn := CombatSeamstressPoolBleed.new()
	_check(resolver_torn.bind_patch_wardrobe(ctx_torn.wardrobe, ctx_torn.torn)
		and resolver_torn._patches.damage_bonus("seamstress") == 0
		and resolver_torn._patches.exposed_for_first_hit("seamstress").is_empty(),
		"torn Seamstress has inactive patch projection")
	var f_torn := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver_torn, f_torn, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 4})], 1, "torn Seamstress attacks with unpatched stats")

	# 3. Invalid explicit binding fails closed
	var bad_resolver := CombatSeamstressPoolBleed.new()
	_check(not bad_resolver.bind_patch_wardrobe(null, null), "null binding returns false")
	_check(bad_resolver._patches != null and not bad_resolver._patches.is_valid(),
		"explicitly bad binding sets invalid patches")
	var f_bad := _fixture("seamstress_running_stitch", 2)
	_reject_custom(bad_resolver, f_bad, "seamstress_running_stitch", 1, "invalid binding play fails closed")
	_check(not bad_resolver.forecast_single(f_bad.deck, f_bad.party, f_bad.enemies, "seamstress_running_stitch", 1).ok,
		"invalid binding forecast fails closed")
