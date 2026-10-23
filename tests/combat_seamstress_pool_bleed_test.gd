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
	_test_m05_head_patches()
	_test_ac1_bloodline_and_unselected_parity()
	_test_ac2_unpicker_all_eight_cards()
	_test_ac3_unpicker_thresholds_skips_and_forecast()
	_test_ac4_unpicker_rejections_and_fail_closed()
	_test_ac1_and_ac2_red_bobbin_cuff_bleed()
	_test_red_bobbin_cuff_unpicker_path()
	_test_red_bobbin_cuff_ac4_negatives()
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
	var ts_torn = ctx_torn.torn.read_state()
	var ws_torn = ctx_torn.wardrobe.get_snapshot()
	ctx_torn.wardrobe.refresh_run_context(ts_torn.heroes, ws_torn.owned, ws_torn.scraps, ws_torn.gold, ws_torn.cards, ws_torn)
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


func _unravel_fixture(enemies: CombatEnemies, default_tier: String = "normal") -> CombatUnravel:
	var unravel := CombatUnravel.new()
	var tiers := {}
	for i in range(enemies.get_enemies().size()):
		tiers[i + 1] = default_tier
	var ok: bool = unravel.bind_roster(enemies, tiers)
	_check(ok, "unravel roster bound successfully")
	return unravel


func _gauge_snapshot(unravel: CombatUnravel, enemy_count: int = 3) -> Dictionary:
	if unravel == null:
		return {}
	var out := {}
	for pos in range(1, enemy_count + 1):
		out[pos] = unravel.get_snapshot(pos)
	return out


func _accept_unpicker(resolver: CombatSeamstressPoolBleed, unravel: CombatUnravel,
		f: Dictionary, id: String, target: int, hits: Array, cost: int,
		expected_deltas: Dictionary, label: String) -> void:
	var deck: CombatDeck = f.deck
	var party: CombatParty = f.party
	var enemies: CombatEnemies = f.enemies
	var before := _snapshot(deck, party, enemies)
	var before_gauges := _gauge_snapshot(unravel, enemies.get_enemies().size())
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
	var after_gauges := _gauge_snapshot(unravel, enemies.get_enemies().size())
	for pos in before_gauges:
		var delta: int = expected_deltas.get(pos, 0)
		var exp_g: int = mini(before_gauges[pos]["threshold"], before_gauges[pos]["gauge"] + delta)
		_check(after_gauges[pos]["gauge"] == exp_g,
			label + ": position %d gauge %d -> %d (expected %d)" % [pos, before_gauges[pos]["gauge"], after_gauges[pos]["gauge"], exp_g])
		var exp_unravelled: bool = exp_g >= before_gauges[pos]["threshold"]
		_check(after_gauges[pos]["unravelled"] == exp_unravelled
			and after_gauges[pos]["skip_pending"] == exp_unravelled,
			label + ": position %d threshold reached flags" % pos)


func _test_m05_head_patches() -> void:
	# AC1/AC2: bloodstitch_bonnet gives +1 Bleed, button_glass_visor gives +1 Exposed.
	var party := _party(2)
	var ctx_bonnet := _head_context(party, "seamstress", "bloodstitch_bonnet")
	var w_bonnet: RunPatchWardrobe = ctx_bonnet.wardrobe

	var ctx_visor := _head_context(party, "seamstress", "button_glass_visor")
	var w_visor: RunPatchWardrobe = ctx_visor.wardrobe

	var resolver_bonnet := CombatSeamstressPoolBleed.new()
	resolver_bonnet.bind_patch_wardrobe(w_bonnet, ctx_bonnet.torn)
	
	var resolver_visor := CombatSeamstressPoolBleed.new()
	resolver_visor.bind_patch_wardrobe(w_visor, ctx_visor.torn)

	# 1. Running Stitch base
	var f1 := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver_bonnet, f1, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 5})], 1, "bonnet adds +1 bleed to running stitch (3 + 1 passive + 1 bonnet)")
	var f2 := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver_visor, f2, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 4})], 1, "visor adds 0 exposed to running stitch (has none)")

	# 2. Red Thread base
	var f3 := _fixture("seamstress_red_thread", 2)
	_accept_custom(resolver_bonnet, f3, "seamstress_red_thread", 1,
		[_hit(1, 0, 0, 0, {"bleed": 8, "exposed": 1})], 2, "bonnet adds +1 bleed to red thread (6 + 1 passive + 1 bonnet)")
	var f4 := _fixture("seamstress_red_thread", 2)
	_accept_custom(resolver_visor, f4, "seamstress_red_thread", 1,
		[_hit(1, 0, 0, 0, {"bleed": 7, "exposed": 2})], 2, "visor adds +1 exposed to red thread (1 + 1 visor)")

	# 3. Combined ARM + HEAD
	var party_comb := _party(2)
	var ctx_comb := _head_context(party_comb, "seamstress", "bloodstitch_bonnet")
	var w_comb: RunPatchWardrobe = ctx_comb.wardrobe
	var r = w_comb.sew("red_bobbin_cuff", "seamstress", "ARM", "sew_cuff_comb", w_comb.get_snapshot())
	_check(r.get("ok", false), "sew cuff on combined")
	var resolver_comb := CombatSeamstressPoolBleed.new()
	resolver_comb.bind_patch_wardrobe(w_comb, ctx_comb.torn)
	
	var f5 := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver_comb, f5, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 6})], 1, "bonnet + cuff adds +2 bleed to running stitch (3 + 1 passive + 1 cuff + 1 bonnet)")

	# 4. Unpicker + Bonnet
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("unpicker")
	var resolver_unp := CombatSeamstressPoolBleed.new(receipt)
	resolver_unp.bind_patch_wardrobe(w_bonnet, ctx_bonnet.torn)
	
	var f6 := _fixture("seamstress_running_stitch", 2)
	var unravel := _unravel_fixture(f6.enemies)
	resolver_unp.bind_unravel(unravel)
	_accept_unpicker(resolver_unp, unravel, f6, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 4})], 1, {1: 2, 2: 0, 3: 0}, "unpicker bonnet gives 4 bleed (3 + 1 bonnet, no passive) and +2 unravel")


func _test_ac1_bloodline_and_unselected_parity() -> void:
	# AC1: Bloodline preserves +1 Bleed on positive printed Bleed, exactly matching unselected baseline.
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("bloodline")
	_check(receipt.get("ok") == true, "bloodline receipt created")
	var resolver := CombatSeamstressPoolBleed.new()
	_check(resolver.bind_choice(receipt), "bind_choice returns true for valid bloodline receipt")
	_check(resolver.is_valid_choice(), "is_valid_choice is true for bloodline")
	_check(resolver.get_path_id() == "bloodline", "get_path_id returns bloodline")

	# Test all 8 card IDs across both baseline service and bloodline resolver
	for upgraded in [false, true]:
		var r_id := "seamstress_running_stitch" + ("_plus" if upgraded else "")
		var r_dmg := 3 if upgraded else 2
		var r_bleed := 5 if upgraded else 4
		var f_r := _fixture(r_id, 2)
		_accept_custom(resolver, f_r, r_id, 1, [_hit(1, r_dmg, 0, r_dmg, {"bleed": r_bleed})], 1,
			r_id + " bloodline +1 bleed parity")

		var h_id := "seamstress_hemorrhage_hem" + ("_plus" if upgraded else "")
		var h_cost := 1 if upgraded else 2
		var f_h := _fixture(h_id, 2)
		_check(f_h.enemies.apply_statuses({1: {"bleed": 3}}), h_id + " bloodline seed bleed")
		_accept_custom(resolver, f_h, h_id, 1, [_hit(1, 0, 0, 0, {"bleed": 3})], h_cost,
			h_id + " bloodline doubles 3 to 6 without +1")

		var b_id := "seamstress_blanket_stitch" + ("_plus" if upgraded else "")
		var b_bleed := 4 if upgraded else 3
		var f_b := _fixture(b_id, 2, 3)
		var b_hits: Array = [
			_hit(1, 0, 0, 0, {"bleed": b_bleed}),
			_hit(2, 0, 0, 0, {"bleed": b_bleed}),
			_hit(3, 0, 0, 0, {"bleed": b_bleed}),
		]
		_accept_custom(resolver, f_b, b_id, 0, b_hits, 2, b_id + " bloodline area +1 bleed parity")

		var t_id := "seamstress_red_thread" + ("_plus" if upgraded else "")
		var t_bleed := 9 if upgraded else 7
		var f_t := _fixture(t_id, 2)
		_accept_custom(resolver, f_t, t_id, 1, [_hit(1, 0, 0, 0, {"bleed": t_bleed, "exposed": 1})], 2,
			t_id + " bloodline single +1 bleed parity")


func _test_ac2_unpicker_all_eight_cards() -> void:
	# AC2: Unpicker applies raw printed Bleed and adds +2 Unravel to each living enemy receiving positive Bleed.
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("unpicker")
	_check(receipt.get("ok") == true, "unpicker receipt created")

	# 1. Running Stitch & Running Stitch+
	for upgraded in [false, true]:
		var id := "seamstress_running_stitch" + ("_plus" if upgraded else "")
		var base_dmg := 3 if upgraded else 2
		var printed_bleed := 4 if upgraded else 3

		var resolver := CombatSeamstressPoolBleed.new(receipt)
		_check(resolver.get_path_id() == "unpicker", id + ": resolver has unpicker path")
		var f := _fixture(id, 2)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		_accept_unpicker(resolver, unravel, f, id, 1,
			[_hit(1, base_dmg, 0, base_dmg, {"bleed": printed_bleed})],
			1, {1: 2, 2: 0, 3: 0}, id + " unpicker printed bleed +2 unravel")

	# 2. Hemorrhage Hem & Hemorrhage Hem+ (Positive Bleed)
	for upgraded in [false, true]:
		var id := "seamstress_hemorrhage_hem" + ("_plus" if upgraded else "")
		var cost := 1 if upgraded else 2
		var resolver := CombatSeamstressPoolBleed.new(receipt)
		var f := _fixture(id, 2)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		_check(f.enemies.apply_statuses({2: {"bleed": 4}}), id + " unpicker preloaded bleed 4")
		_accept_unpicker(resolver, unravel, f, id, 2,
			[_hit(2, 0, 0, 0, {"bleed": 4})],
			cost, {1: 0, 2: 2, 3: 0}, id + " unpicker doubles 4 to 8 and +2 unravel")
		_check(f.enemies.get_enemy(2)["statuses"]["bleed"] == 8, id + " enemy has doubled bleed 8")

	# 3. Hemorrhage Hem & Hemorrhage Hem+ (Zero Bleed -> N = 0 grants 0 Unravel)
	for upgraded in [false, true]:
		var id := "seamstress_hemorrhage_hem" + ("_plus" if upgraded else "")
		var cost := 1 if upgraded else 2
		var resolver := CombatSeamstressPoolBleed.new(receipt)
		var f := _fixture(id, 2)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		_accept_unpicker(resolver, unravel, f, id, 1,
			[_hit(1, 0, 0, 0, {"bleed": 0})],
			cost, {1: 0, 2: 0, 3: 0}, id + " zero bleed grants 0 unravel")
		_check(f.enemies.get_enemy(1).get("statuses", {}).get("bleed", 0) == 0, id + " bleed remains 0")

	# 4. Blanket Stitch & Blanket Stitch+
	for upgraded in [false, true]:
		var id := "seamstress_blanket_stitch" + ("_plus" if upgraded else "")
		var printed_bleed := 3 if upgraded else 2
		var resolver := CombatSeamstressPoolBleed.new(receipt)
		var f := _fixture(id, 2, 3)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		var hits: Array = [
			_hit(1, 0, 0, 0, {"bleed": printed_bleed}),
			_hit(2, 0, 0, 0, {"bleed": printed_bleed}),
			_hit(3, 0, 0, 0, {"bleed": printed_bleed}),
		]
		_accept_unpicker(resolver, unravel, f, id, 0, hits,
			2, {1: 2, 2: 2, 3: 2}, id + " unpicker area printed bleed and +2 unravel to all 3")

	# 5. Red Thread & Red Thread+
	for upgraded in [false, true]:
		var id := "seamstress_red_thread" + ("_plus" if upgraded else "")
		var printed_bleed := 8 if upgraded else 6
		var resolver := CombatSeamstressPoolBleed.new(receipt)
		var f := _fixture(id, 2)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		_accept_unpicker(resolver, unravel, f, id, 3,
			[_hit(3, 0, 0, 0, {"bleed": printed_bleed, "exposed": 1})],
			2, {1: 0, 2: 0, 3: 2}, id + " unpicker red thread printed bleed 6/8 and +2 unravel")


func _test_ac3_unpicker_thresholds_skips_and_forecast() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("unpicker")

	# 1. Blanket Stitch with dead middle slot (at least two living enemies and dead middle slot)
	for upgraded in [false, true]:
		var b_id := "seamstress_blanket_stitch" + ("_plus" if upgraded else "")
		var printed_bleed := 3 if upgraded else 2
		var resolver := CombatSeamstressPoolBleed.new(receipt)
		var f := _fixture(b_id, 2, 3)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		# Slain middle slot (slot 2)
		_check(f.enemies.apply_damage(2, 999) and f.enemies.is_slain(2), "middle slot slain")
		var expected_hits: Array = [
			_hit(1, 0, 0, 0, {"bleed": printed_bleed}),
			_hit(3, 0, 0, 0, {"bleed": printed_bleed}),
		]
		_accept_unpicker(resolver, unravel, f, b_id, 0, expected_hits,
			2, {1: 2, 2: 0, 3: 2}, b_id + " dead middle slot gets 0 bleed and 0 unravel")
		_check(f.enemies.get_enemy(2).get("statuses", {}).get("bleed", 0) == 0, "slain slot got no bleed")
		_check(unravel.get_snapshot(2)["gauge"] == 0, "slain slot gauge unchanged")

	# 2. Normal (8), Elite (12), Boss (16) thresholds just below threshold
	var tiers := ["normal", "elite", "boss"]
	var initial_thresholds := [8, 12, 16]
	for idx in range(3):
		var tier: String = tiers[idx]
		var thresh: int = initial_thresholds[idx]
		var below: int = thresh - 2 # just 2 below threshold, so +2 reaches it exactly

		var f := _fixture("seamstress_running_stitch", 2, 1)
		var unravel := CombatUnravel.new()
		_check(unravel.bind_roster(f.enemies, {1: tier}), "bind " + tier + " roster")
		_check(unravel.apply_unravel(f.enemies, 1, below), "set gauge to " + str(below))
		_check(unravel.get_snapshot(1)["gauge"] == below, "gauge is just below threshold")

		var resolver := CombatSeamstressPoolBleed.new(receipt, unravel)
		var pre_snap := _snapshot(f.deck, f.party, f.enemies)
		var res: Dictionary = resolver.play_card(f.deck, f.party, f.enemies, "seamstress_running_stitch", 1)
		_check(res.get("ok", false), tier + " card play succeeded")

		var snap := unravel.get_snapshot(1)
		_check(snap["gauge"] == thresh and snap["unravelled"] == true and snap["skip_pending"] == true,
			tier + " gauge reached threshold, queued skip")

		# Assert one skip queued and consumed:
		_check(unravel.consume_action_skip(f.enemies, 1) == true, tier + " consume skip returns true")
		var post_consume := unravel.get_snapshot(1)
		_check(post_consume["gauge"] == 0 and post_consume["threshold"] == thresh + 4
			and post_consume["unravelled"] == false and post_consume["skip_pending"] == false,
			tier + " skip consumed resets gauge to 0, clears unravelled, threshold +4")
		# Only one skip was queued:
		_check(unravel.consume_action_skip(f.enemies, 1) == false, tier + " second skip consume returns false")

		# Assert no immediate extra bleed tick at card resolution
		var enemy_statuses: Dictionary = f.enemies.get_enemy(1).get("statuses", {})
		_check(enemy_statuses.get("bleed", 0) == 3, tier + " bleed is exactly printed 3, not decremented by tick")
		_check(f.enemies.get_enemy(1)["hp"] == 12 - 2, tier + " HP lost only attack damage, no bleed tick")
		_check(f.deck._rng.state == pre_snap.rng, tier + " no RNG change")

	# 3. Forecast before play is side-effect-free and path-correct
	for slug in ["running_stitch", "hemorrhage_hem", "red_thread"]:
		for upgraded in [false, true]:
			var id: String = "seamstress_" + slug + ("_plus" if upgraded else "")
			var def: Dictionary = SeamstressPoolCards.new().get_definition(id)
			var f := _fixture(id, 2)
			var committed := _fixture(id, 2)
			_forecast_seed(f, 1)
			_forecast_seed(committed, 1)

			var unravel_f := _unravel_fixture(f.enemies)
			var unravel_c := _unravel_fixture(committed.enemies)
			var resolver_f := CombatSeamstressPoolBleed.new(receipt, unravel_f)
			var resolver_c := CombatSeamstressPoolBleed.new(receipt, unravel_c)

			var snap_before := _snapshot(f.deck, f.party, f.enemies)
			var gauge_before := _gauge_snapshot(unravel_f)

			var base_dmg: int = int(def.effects.get("damage", 0))
			@warning_ignore("integer_division")
			var adj_dmg: int = base_dmg * 9 / 8
			var abs_dmg: int = mini(2, adj_dmg)
			var hp_loss: int = mini(12, adj_dmg - abs_dmg)

			var exp_bleed: int
			if slug == "hemorrhage_hem":
				exp_bleed = 6 # 3 doubled
			else:
				# raw printed bleed without +1
				exp_bleed = 3 + int(def.effects.get("bleed", 0))
			var exp_exp: int = 2 if slug == "red_thread" else 1

			var expected_fc := {
				"ok": true, "position": 1, "cost": def.cost,
				"damage": adj_dmg, "block_absorbed": abs_dmg, "hp_loss": hp_loss,
				"bleed_before": 3, "bleed_after": exp_bleed,
				"exposed_before": 1, "exposed_after": exp_exp
			}

			# Assert forecast output matches expected path-dependent bleed
			var fc := resolver_f.forecast_single(f.deck, f.party, f.enemies, id, 1)
			_check(fc == expected_fc, id + " unpicker forecast reflects raw bleed " + str(exp_bleed))

			# Assert forecast was side-effect-free (no deck, party, enemy, gauge, or RNG mutation)
			_check(_snapshot(f.deck, f.party, f.enemies) == snap_before, id + " forecast mutated no state")
			_check(_gauge_snapshot(unravel_f) == gauge_before, id + " forecast mutated no gauges")

			# Commit on committed fixture and check parity
			var event := resolver_c.play_card(committed.deck, committed.party, committed.enemies, id, 1)
			_check(event.get("ok", false) and event.hits.size() == 1, id + " matching play succeeded")
			var enemy_c: Dictionary = committed.enemies.get_enemy(1)
			_check(enemy_c.get("statuses", {}).get("bleed", 0) == exp_bleed, id + " committed bleed parity")
			_check(enemy_c.get("statuses", {}).get("exposed", 0) == exp_exp, id + " committed exposed parity")
			_check(unravel_c.get_snapshot(1)["gauge"] == 2, id + " committed gauge +2")


func _test_ac4_unpicker_rejections_and_fail_closed() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt_u: Dictionary = choice.choose("unpicker")

	# 1. Missing or invalid path selection
	var r_null := CombatSeamstressPoolBleed.new()
	_check(not r_null.bind_choice(null), "null choice returns false")
	_check(not r_null.is_valid_choice(), "is_valid_choice false on null")
	var f1 := _fixture("seamstress_running_stitch", 2)
	_reject_custom(r_null, f1, "seamstress_running_stitch", 1, "null choice fails closed")
	_check(not r_null.forecast_single(f1.deck, f1.party, f1.enemies, "seamstress_running_stitch", 1).ok,
		"null choice forecast fails closed")

	var r_empty := CombatSeamstressPoolBleed.new()
	_check(not r_empty.bind_choice({}), "empty dict choice returns false")
	_reject_custom(r_empty, f1, "seamstress_running_stitch", 1, "empty choice fails closed")

	var r_bogus := CombatSeamstressPoolBleed.new()
	_check(not r_bogus.bind_choice({"path_id": "bogus"}), "bogus dict choice returns false")
	_reject_custom(r_bogus, f1, "seamstress_running_stitch", 1, "bogus choice fails closed")

	var r_unclaimed := CombatSeamstressPoolBleed.new()
	var unclaimed := RunSeamstressPathChoice.new()
	_check(not r_unclaimed.bind_choice(unclaimed), "unclaimed choice returns false")
	_reject_custom(r_unclaimed, f1, "seamstress_running_stitch", 1, "unclaimed choice fails closed")

	# 2. Retry after unsuccessful selection
	var retry_resolver := CombatSeamstressPoolBleed.new()
	_check(not retry_resolver.bind_choice("not_a_choice"), "initial bad binding fails")
	var f_retry := _fixture("seamstress_running_stitch", 2)
	var u_retry := _unravel_fixture(f_retry.enemies)
	retry_resolver.bind_unravel(u_retry)
	_reject_custom(retry_resolver, f_retry, "seamstress_running_stitch", 1, "failed selection play rejected")
	# Now retry with valid selection:
	_check(retry_resolver.bind_choice(receipt_u), "retry with valid unpicker receipt succeeds")
	_check(retry_resolver.is_valid_choice(), "is_valid_choice is now true")
	_accept_unpicker(retry_resolver, u_retry, f_retry, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 3})], 1, {1: 2, 2: 0, 3: 0}, "retried play succeeds")

	# 3. Unpicker with unbound or wrong-roster CombatUnravel
	# a) No unravel bound at all
	var r_nounravel := CombatSeamstressPoolBleed.new(receipt_u)
	var f_no_u := _fixture("seamstress_running_stitch", 2)
	_reject_custom(r_nounravel, f_no_u, "seamstress_running_stitch", 1, "unpicker without unravel fails closed")
	_check(not r_nounravel.forecast_single(f_no_u.deck, f_no_u.party, f_no_u.enemies, "seamstress_running_stitch", 1).ok,
		"unpicker without unravel forecast fails closed")

	# b) Unravel with no roster bound
	var r_unbound_u := CombatSeamstressPoolBleed.new(receipt_u, CombatUnravel.new())
	var f_unbound_u := _fixture("seamstress_running_stitch", 2)
	_reject_custom(r_unbound_u, f_unbound_u, "seamstress_running_stitch", 1, "unbound unravel roster fails closed")
	_check(not r_unbound_u.forecast_single(f_unbound_u.deck, f_unbound_u.party, f_unbound_u.enemies, "seamstress_running_stitch", 1).ok,
		"unbound unravel forecast fails closed")

	# c) Unravel bound to DIFFERENT CombatEnemies roster
	var r_wrong_roster := CombatSeamstressPoolBleed.new(receipt_u)
	var other_enemies := _enemies(3)
	var other_unravel := _unravel_fixture(other_enemies)
	r_wrong_roster.bind_unravel(other_unravel)
	var f_wrong := _fixture("seamstress_running_stitch", 2)
	_reject_custom(r_wrong_roster, f_wrong, "seamstress_running_stitch", 1, "wrong roster unravel fails closed")
	_check(not r_wrong_roster.forecast_single(f_wrong.deck, f_wrong.party, f_wrong.enemies, "seamstress_running_stitch", 1).ok,
		"wrong roster forecast fails closed")

	# 4. Illegal held-card conditions under Unpicker (fail-closed, no mutation)
	var u_resolver := CombatSeamstressPoolBleed.new(receipt_u)
	var f_active := _fixture("seamstress_running_stitch", 2)
	var u_active := _unravel_fixture(f_active.enemies)
	u_resolver.bind_unravel(u_active)

	# Missing card from hand
	_reject_custom(u_resolver, f_active, "seamstress_red_thread", 1, "unheld card rejected")

	# Insufficient energy
	var f_energy := _fixture("seamstress_red_thread", 2)
	var u_energy := _unravel_fixture(f_energy.enemies)
	var r_energy := CombatSeamstressPoolBleed.new(receipt_u, u_energy)
	_check(f_energy.deck.try_spend_energy(2), "spend 2 energy")
	_reject_custom(r_energy, f_energy, "seamstress_red_thread", 1, "underfunded rejected")

	# Downed Seamstress
	var f_dead := _fixture("seamstress_running_stitch", 2)
	var u_dead := _unravel_fixture(f_dead.enemies)
	var r_dead := CombatSeamstressPoolBleed.new(receipt_u, u_dead)
	_check(f_dead.party.apply_damage(2, 999), "down seamstress")
	_reject_custom(r_dead, f_dead, "seamstress_running_stitch", 1, "downed owner rejected")

	# Misplaced Seamstress (Blanket Stitch from pos 1 is illegal)
	var f_pos := _fixture("seamstress_blanket_stitch", 1)
	var u_pos := _unravel_fixture(f_pos.enemies)
	var r_pos := CombatSeamstressPoolBleed.new(receipt_u, u_pos)
	_reject_custom(r_pos, f_pos, "seamstress_blanket_stitch", 0, "out of position rejected")

	# Slain chosen target
	var f_slain := _fixture("seamstress_running_stitch", 2)
	var u_slain := _unravel_fixture(f_slain.enemies)
	var r_slain := CombatSeamstressPoolBleed.new(receipt_u, u_slain)
	_check(f_slain.enemies.apply_damage(1, 999), "kill target 1")
	_reject_custom(r_slain, f_slain, "seamstress_running_stitch", 1, "slain target rejected")

	# Out of bounds target (target 4)
	_reject_custom(u_resolver, f_active, "seamstress_running_stitch", 4, "out of bounds target rejected")

	# Status overflow
	var f_of := _fixture("seamstress_running_stitch", 2)
	var u_of := _unravel_fixture(f_of.enemies)
	var r_of := CombatSeamstressPoolBleed.new(receipt_u, u_of)
	_check(f_of.enemies.apply_statuses({1: {"bleed": CombatEnemies.MAX_INT - 2}}), "preload max bleed")
	_reject_custom(r_of, f_of, "seamstress_running_stitch", 1, "status overflow rejected")

	# Lethal Running Stitch: target is slain by damage, receives bleed status on slain slot, but gets NO unravel
	var f_lethal := _fixture("seamstress_running_stitch", 2, 1, 2) # 2 HP enemy
	var u_lethal := _unravel_fixture(f_lethal.enemies)
	var r_lethal := CombatSeamstressPoolBleed.new(receipt_u, u_lethal)
	var lethal_res := r_lethal.play_card(f_lethal.deck, f_lethal.party, f_lethal.enemies, "seamstress_running_stitch", 1)
	_check(lethal_res.get("ok", false) and f_lethal.enemies.is_slain(1), "target was slain by running stitch")
	_check(f_lethal.enemies.get_enemy(1).get("statuses", {}).get("bleed", 0) == 3, "slain slot got bleed 3")
	_check(u_lethal.get_snapshot(1)["gauge"] == 0, "slain slot got no unravel gauge delta")

	# 5. Attack patches under Unpicker
	# Pincushion Arm +1 damage
	var party_p := _party(2)
	var ctx_p := _patch_context(party_p, "seamstress", false, true)
	var resolver_p := CombatSeamstressPoolBleed.new(receipt_u)
	_check(resolver_p.bind_patch_wardrobe(ctx_p.wardrobe, ctx_p.torn), "bind wardrobe")
	var f_p := _fixture("seamstress_running_stitch", 2)
	var u_p := _unravel_fixture(f_p.enemies)
	resolver_p.bind_unravel(u_p)
	_accept_unpicker(resolver_p, u_p, f_p, "seamstress_running_stitch", 1,
		[_hit(1, 3, 0, 3, {"bleed": 3})], 1, {1: 2, 2: 0, 3: 0}, "unpicker with pincushion arm deals 3 damage and +2 unravel")

	# Button Eye Exposed 1 on first hit
	var party_be := _party(2)
	var ctx_be := _patch_context(party_be, "seamstress", true, false)
	var resolver_be := CombatSeamstressPoolBleed.new(receipt_u)
	_check(resolver_be.bind_patch_wardrobe(ctx_be.wardrobe, ctx_be.torn), "bind button eye")
	var f_be := _fixture("seamstress_running_stitch", 2)
	var u_be := _unravel_fixture(f_be.enemies)
	resolver_be.bind_unravel(u_be)
	_accept_unpicker(resolver_be, u_be, f_be, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 3, "exposed": 1})], 1, {1: 2, 2: 0, 3: 0},
		"unpicker with button eye applies exposed 1 on first hit")


func _head_context(party: CombatParty, wearer: String = "seamstress",
		head_patch_id: String = "bloodstitch_bonnet") -> Dictionary:
	var raw_head: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m05_head_patches.json"))
	var raw_arm: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m05_arm_support_patches.json"))
	var raw_atk: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m04_attack_patches.json"))
	var definitions: Array[Dictionary] = []
	for entry in raw_head:
		if entry is Dictionary and entry.has("id") and entry.has("slot"):
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
	for entry in raw_arm:
		if entry is Dictionary and entry.has("id") and entry.has("slot"):
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
	for entry in raw_atk:
		if entry is Dictionary and entry.has("id") and entry.has("slot"):
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var owned: Array = [head_patch_id, "red_bobbin_cuff"]
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, definitions, 3)
	wardrobe.sew(head_patch_id, wearer, "HEAD", "sew_" + head_patch_id, wardrobe.get_snapshot())
	return {"wardrobe": wardrobe, "torn": torn}


func _cuff_context(party: CombatParty, wearer: String = "seamstress",
		sew_cuff: bool = true, arm_patch_id: String = "red_bobbin_cuff") -> Dictionary:
	var raw_attacks: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	var raw_supports: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_arm_support_patches.json"))
	_check(raw_attacks is Array and raw_supports is Array, "patch catalogs are arrays")
	var definitions: Array[Dictionary] = []
	for entry in raw_attacks:
		if entry is Dictionary and entry.has("id") and entry.has("slot"):
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
	for entry in raw_supports:
		if entry is Dictionary and entry.has("id") and entry.has("slot"):
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var owned: Array = []
	if not arm_patch_id.is_empty():
		owned.append(arm_patch_id)
	if arm_patch_id != "red_bobbin_cuff":
		owned.append("red_bobbin_cuff")
	if not owned.has("loose_thread_glove"):
		owned.append("loose_thread_glove")
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, definitions, 3)
	_check(torn.is_valid() and wardrobe.is_valid(), "genuine run patch ledgers valid")
	if sew_cuff and not arm_patch_id.is_empty():
		var result: Dictionary = wardrobe.sew(arm_patch_id, wearer, "ARM",
			"sew_" + arm_patch_id, wardrobe.get_snapshot())
		_check(result.get("ok", false) and wardrobe.get_snapshot()["worn"][wearer]["ARM"] == arm_patch_id,
			arm_patch_id + " sewn on " + wearer + " ARM slot")
	return {"wardrobe": wardrobe, "torn": torn}


func _test_ac1_and_ac2_red_bobbin_cuff_bleed() -> void:
	# AC1 & AC2: Under default/Bloodline passive, Red Bobbin Cuff in ARM grants +1 Bleed
	# to each originally Bleed-positive card (Running Stitch 5/6, Blanket Stitch 4/5 per foe, Red Thread 8/10).
	# Hemorrhage Hem doubles N -> 2N and gets 0 cuff bonus.
	var party := _party(2)
	var ctx := _cuff_context(party, "seamstress", true, "red_bobbin_cuff")
	var resolver := CombatSeamstressPoolBleed.new()
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
		and resolver._patches.is_valid(), "valid Red Bobbin Cuff binding")
	_check(resolver._patches.card_bleed_bonus("seamstress", "seamstress_running_stitch") == 1,
		"cuff grants +1 bleed bonus to running stitch")
	_check(resolver._patches.card_bleed_bonus("seamstress", "seamstress_blanket_stitch") == 1,
		"cuff grants +1 bleed bonus to blanket stitch")
	_check(resolver._patches.card_bleed_bonus("seamstress", "seamstress_red_thread") == 1,
		"cuff grants +1 bleed bonus to red thread")
	_check(resolver._patches.card_bleed_bonus("seamstress", "seamstress_hemorrhage_hem") == 0,
		"cuff grants 0 bleed bonus to hemorrhage hem")

	# 1. Running Stitch base (2 dmg, 5 bleed) and plus (3 dmg, 6 bleed)
	for upgraded in [false, true]:
		var id: String = "seamstress_running_stitch" + ("_plus" if upgraded else "")
		var base_dmg := 3 if upgraded else 2
		var exp_bleed := 6 if upgraded else 5 # 4/3 printed + 1 passive + 1 cuff

		# Forecast parity
		var f_fc := _fixture(id, 2)
		_forecast_seed(f_fc, 1)
		var snap_fc_before := _snapshot(f_fc.deck, f_fc.party, f_fc.enemies)
		var exp_fc := {
			"ok": true, "position": 1, "cost": 1,
			"damage": 3 if upgraded else 2, # floor(base * 9/8) with Weak on hero and Exposed on enemy
			"block_absorbed": 2, "hp_loss": 1 if upgraded else 0,
			"bleed_before": 3, "bleed_after": 3 + exp_bleed,
			"exposed_before": 1, "exposed_after": 1
		}
		for repeat in range(3):
			var fc := resolver.forecast_single(f_fc.deck, f_fc.party, f_fc.enemies, id, 1)
			_check(fc == exp_fc, id + " cuff forecast reflects +1 cuff bleed")
			_check(_snapshot(f_fc.deck, f_fc.party, f_fc.enemies) == snap_fc_before,
				id + " forecast is side-effect-free")

		# Real play
		var normal := _fixture(id, 2)
		_accept_custom(resolver, normal, id, 1,
			[_hit(1, base_dmg, 0, base_dmg, {"bleed": exp_bleed})], 1,
			id + " cuff deals %d damage and %d bleed" % [base_dmg, exp_bleed])

		# Block absorbs before HP
		var blocked := _fixture(id, 2)
		_check(blocked.enemies.gain_block(2, 2), id + " target has 2 Block")
		_accept_custom(resolver, blocked, id, 2,
			[_hit(2, base_dmg, 2, base_dmg - 2, {"bleed": exp_bleed})], 1,
			id + " cuff hit preserves Block absorbs before HP")

	# 2. Blanket Stitch base (4 bleed per living enemy) and plus (5 bleed per living enemy)
	for upgraded in [false, true]:
		var id: String = "seamstress_blanket_stitch" + ("_plus" if upgraded else "")
		var exp_bleed := 5 if upgraded else 4 # 3/2 printed + 1 passive + 1 cuff

		# Hits all 3 living enemies
		var f3 := _fixture(id, 2, 3)
		var hits3: Array = [
			_hit(1, 0, 0, 0, {"bleed": exp_bleed}),
			_hit(2, 0, 0, 0, {"bleed": exp_bleed}),
			_hit(3, 0, 0, 0, {"bleed": exp_bleed})
		]
		_accept_custom(resolver, f3, id, 0, hits3, 2,
			id + " cuff applies %d bleed to all 3 living enemies" % exp_bleed)

		# Dead middle slot skips slain enemy and hits only living slots
		var f_dead := _fixture(id, 2, 3)
		_check(f_dead.enemies.apply_damage(2, 999) and f_dead.enemies.is_slain(2), "middle slot slain")
		var hits_dead: Array = [
			_hit(1, 0, 0, 0, {"bleed": exp_bleed}),
			_hit(3, 0, 0, 0, {"bleed": exp_bleed})
		]
		_accept_custom(resolver, f_dead, id, 0, hits_dead, 2,
			id + " cuff skips dead middle enemy")
		_check(f_dead.enemies.get_enemy(2).get("statuses", {}).get("bleed", 0) == 0,
			id + " dead enemy received 0 bleed")

	# 3. Red Thread base (8 bleed, Exposed 1) and plus (10 bleed, Exposed 1)
	for upgraded in [false, true]:
		var id: String = "seamstress_red_thread" + ("_plus" if upgraded else "")
		var exp_bleed := 10 if upgraded else 8 # 8/6 printed + 1 passive + 1 cuff

		# Forecast parity
		var f_rt_fc := _fixture(id, 2)
		_forecast_seed(f_rt_fc, 1)
		var exp_rt_fc := {
			"ok": true, "position": 1, "cost": 2,
			"damage": 0, "block_absorbed": 0, "hp_loss": 0,
			"bleed_before": 3, "bleed_after": 3 + exp_bleed,
			"exposed_before": 1, "exposed_after": 2 # +1 from authored exposed
		}
		var fc_rt := resolver.forecast_single(f_rt_fc.deck, f_rt_fc.party, f_rt_fc.enemies, id, 1)
		_check(fc_rt == exp_rt_fc, id + " cuff forecast reflects %d bleed and +1 exposed" % exp_bleed)

		# Real play
		var f_rt := _fixture(id, 2)
		_accept_custom(resolver, f_rt, id, 1,
			[_hit(1, 0, 0, 0, {"bleed": exp_bleed, "exposed": 1})], 2,
			id + " cuff applies %d bleed and authored Exposed 1" % exp_bleed)

	# 4. Hemorrhage Hem base and plus: doubles N -> 2N, gets ZERO cuff bonus
	for upgraded in [false, true]:
		var id: String = "seamstress_hemorrhage_hem" + ("_plus" if upgraded else "")
		var cost := 1 if upgraded else 2

		# Target with existing Bleed 3: doubles to 6 (delta 3, no +1 cuff bonus)
		var f_h := _fixture(id, 2)
		_check(f_h.enemies.apply_statuses({1: {"bleed": 3}}), id + " seed bleed 3")
		var fc_h := resolver.forecast_single(f_h.deck, f_h.party, f_h.enemies, id, 1)
		_check(fc_h.ok and fc_h.bleed_before == 3 and fc_h.bleed_after == 6,
			id + " forecast doubles 3 -> 6 without cuff bonus")
		_accept_custom(resolver, f_h, id, 1,
			[_hit(1, 0, 0, 0, {"bleed": 3})], cost,
			id + " doubles existing bleed without cuff bonus")
		_check(f_h.enemies.get_enemy(1)["statuses"]["bleed"] == 6, id + " final bleed is exactly 6")

		# Target with Bleed 0: stays 0
		var f_zero := _fixture(id, 2)
		var fc_zero := resolver.forecast_single(f_zero.deck, f_zero.party, f_zero.enemies, id, 1)
		_check(fc_zero.ok and fc_zero.bleed_before == 0 and fc_zero.bleed_after == 0,
			id + " forecast 0 remains 0")
		_accept_custom(resolver, f_zero, id, 1,
			[_hit(1, 0, 0, 0, {"bleed": 0})], cost,
			id + " 0 bleed remains 0")

	# 5. Bloodline path: identical +1 Bleed passive preserved alongside cuff
	var choice := RunSeamstressPathChoice.new()
	var b_receipt := choice.choose("bloodline")
	var b_resolver := CombatSeamstressPoolBleed.new(b_receipt)
	_check(b_resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "bind wardrobe to bloodline resolver")
	_check(b_resolver.get_path_id() == "bloodline", "resolver path is bloodline")
	var f_b_run := _fixture("seamstress_running_stitch", 2)
	_accept_custom(b_resolver, f_b_run, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 5})], 1, "bloodline with cuff yields 5 bleed")
	var f_b_blanket := _fixture("seamstress_blanket_stitch", 2, 2)
	_accept_custom(b_resolver, f_b_blanket, "seamstress_blanket_stitch", 0,
		[_hit(1, 0, 0, 0, {"bleed": 4}), _hit(2, 0, 0, 0, {"bleed": 4})], 2,
		"bloodline with cuff yields 4 bleed to both foes")


func _test_red_bobbin_cuff_unpicker_path() -> void:
	# Under Unpicker path: passive +1 Bleed is replaced by +2 Unravel per enemy bled.
	# Red Bobbin Cuff still adds its +1 Bleed bonus to raw printed Bleed.
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("unpicker")
	_check(receipt.get("ok") == true, "unpicker receipt created")

	var party := _party(2)
	var ctx := _cuff_context(party, "seamstress", true, "red_bobbin_cuff")

	# 1. Running Stitch base & plus: printed + 1 cuff, no passive +1, +2 unravel
	for upgraded in [false, true]:
		var id: String = "seamstress_running_stitch" + ("_plus" if upgraded else "")
		var base_dmg := 3 if upgraded else 2
		var exp_bleed := 5 if upgraded else 4 # 4/3 printed + 1 cuff

		var resolver := CombatSeamstressPoolBleed.new(receipt)
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "bind wardrobe")
		var f := _fixture(id, 2)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		_accept_unpicker(resolver, unravel, f, id, 1,
			[_hit(1, base_dmg, 0, base_dmg, {"bleed": exp_bleed})],
			1, {1: 2, 2: 0, 3: 0}, id + " unpicker with cuff gives %d bleed and +2 unravel" % exp_bleed)

	# 2. Blanket Stitch base & plus: printed + 1 cuff to each living foe, +2 unravel to each living foe
	for upgraded in [false, true]:
		var id: String = "seamstress_blanket_stitch" + ("_plus" if upgraded else "")
		var exp_bleed := 4 if upgraded else 3 # 3/2 printed + 1 cuff

		var resolver := CombatSeamstressPoolBleed.new(receipt)
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "bind wardrobe")
		var f := _fixture(id, 2, 3)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		var hits: Array = [
			_hit(1, 0, 0, 0, {"bleed": exp_bleed}),
			_hit(2, 0, 0, 0, {"bleed": exp_bleed}),
			_hit(3, 0, 0, 0, {"bleed": exp_bleed}),
		]
		_accept_unpicker(resolver, unravel, f, id, 0, hits,
			2, {1: 2, 2: 2, 3: 2}, id + " unpicker area with cuff gives %d bleed and +2 unravel" % exp_bleed)

		# Slain middle slot
		var f_dead := _fixture(id, 2, 3)
		var u_dead := _unravel_fixture(f_dead.enemies)
		resolver.bind_unravel(u_dead)
		_check(f_dead.enemies.apply_damage(2, 999) and f_dead.enemies.is_slain(2), "slain slot 2")
		var dead_hits: Array = [
			_hit(1, 0, 0, 0, {"bleed": exp_bleed}),
			_hit(3, 0, 0, 0, {"bleed": exp_bleed}),
		]
		_accept_unpicker(resolver, u_dead, f_dead, id, 0, dead_hits,
			2, {1: 2, 2: 0, 3: 2}, id + " unpicker area dead middle slot gets 0 bleed and 0 unravel")

	# 3. Red Thread base & plus: printed + 1 cuff, Exposed 1, +2 unravel
	for upgraded in [false, true]:
		var id: String = "seamstress_red_thread" + ("_plus" if upgraded else "")
		var exp_bleed := 9 if upgraded else 7 # 8/6 printed + 1 cuff

		var resolver := CombatSeamstressPoolBleed.new(receipt)
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "bind wardrobe")
		var f := _fixture(id, 2)
		var unravel := _unravel_fixture(f.enemies)
		resolver.bind_unravel(unravel)
		_accept_unpicker(resolver, unravel, f, id, 1,
			[_hit(1, 0, 0, 0, {"bleed": exp_bleed, "exposed": 1})],
			2, {1: 2, 2: 0, 3: 0}, id + " unpicker red thread with cuff gives %d bleed and +2 unravel" % exp_bleed)

	# 4. Hemorrhage Hem under Unpicker with cuff: doubles N -> 2N, gets 0 cuff bonus
	var resolver_h := CombatSeamstressPoolBleed.new(receipt)
	_check(resolver_h.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "bind wardrobe")
	var f_h := _fixture("seamstress_hemorrhage_hem", 2)
	var u_h := _unravel_fixture(f_h.enemies)
	resolver_h.bind_unravel(u_h)
	_check(f_h.enemies.apply_statuses({1: {"bleed": 4}}), "preload bleed 4")
	_accept_unpicker(resolver_h, u_h, f_h, "seamstress_hemorrhage_hem", 1,
		[_hit(1, 0, 0, 0, {"bleed": 4})], 2, {1: 2, 2: 0, 3: 0},
		"unpicker hemorrhage doubles 4 -> 8 with +2 unravel and 0 cuff bonus")
	_check(f_h.enemies.get_enemy(1)["statuses"]["bleed"] == 8, "final bleed 8")


func _cuff_trace(seed_val: int) -> Dictionary:
	var deck := _deck(["seamstress_running_stitch", "seamstress_blanket_stitch"], seed_val)
	var party := _party(2)
	var enemies := _enemies(3)
	var ctx := _cuff_context(party, "seamstress", true, "red_bobbin_cuff")
	var resolver := CombatSeamstressPoolBleed.new()
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "bind trace wardrobe")
	var first := resolver.play_card(deck, party, enemies, "seamstress_running_stitch", 1)
	var second := resolver.play_card(deck, party, enemies, "seamstress_blanket_stitch", 0)
	_check(first.get("ok", false) and second.get("ok", false), "trace plays succeeded")
	return {"first": first, "second": second, "final": _snapshot(deck, party, enemies)}


func _test_red_bobbin_cuff_ac4_negatives() -> void:
	# AC4: Negatives, isolation, fail-closed, not once-per-turn latch, fixed-seed replay.
	# 1. Cuff on another wearer (Warden wears red_bobbin_cuff in ARM):
	var party_w := _party(2)
	var ctx_w := _cuff_context(party_w, "warden", true, "red_bobbin_cuff")
	var resolver_w := CombatSeamstressPoolBleed.new()
	_check(resolver_w.bind_patch_wardrobe(ctx_w.wardrobe, ctx_w.torn), "bind warden-worn cuff")
	_check(resolver_w._patches.card_bleed_bonus("seamstress", "seamstress_running_stitch") == 0,
		"Warden wearing cuff grants Seamstress 0 bleed bonus")
	_check(resolver_w._patches.card_bleed_bonus("warden", "seamstress_running_stitch") == 0,
		"Warden cannot get bonus on Seamstress's card")
	var f_w := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver_w, f_w, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 4})], 1, "unpatched bleed 4 when Warden wears cuff")
	var f_w_area := _fixture("seamstress_blanket_stitch", 2, 2)
	_accept_custom(resolver_w, f_w_area, "seamstress_blanket_stitch", 0,
		[_hit(1, 0, 0, 0, {"bleed": 3}), _hit(2, 0, 0, 0, {"bleed": 3})], 2,
		"unpatched bleed 3 when Warden wears cuff")

	# 2. Torn Seamstress: patch effects inactive
	var party_t := _party(2)
	var ctx_t := _cuff_context(party_t, "seamstress", true, "red_bobbin_cuff")
	var start_torn: Array = ctx_t.torn.read_state().heroes
	_check(party_t.apply_damage(2, 999) and party_t.is_downed(2), "down seamstress to record tear")
	_check(ctx_t.torn.observe_battle_end("seamstress_cuff_tear", start_torn, party_t.get_heroes()).ok,
		"record torn seamstress")
	var ts_t = ctx_t.torn.read_state()
	var ws_t = ctx_t.wardrobe.get_snapshot()
	ctx_t.wardrobe.refresh_run_context(ts_t.heroes, ws_t.owned, ws_t.scraps, ws_t.gold, ws_t.cards, ws_t)
	party_t.heal(2, 30) # restore hp so she can legally play
	var resolver_t := CombatSeamstressPoolBleed.new()
	_check(resolver_t.bind_patch_wardrobe(ctx_t.wardrobe, ctx_t.torn), "bind torn wardrobe")
	_check(resolver_t._patches.card_bleed_bonus("seamstress", "seamstress_running_stitch") == 0,
		"torn seamstress gets 0 cuff bleed bonus")
	var f_t := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver_t, f_t, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 4})], 1, "torn seamstress deals unpatched bleed 4")

	# 3. Downed Seamstress during combat: play fails closed
	var f_down := _fixture("seamstress_running_stitch", 2)
	var ctx_down := _cuff_context(f_down.party, "seamstress", true, "red_bobbin_cuff")
	var resolver_down := CombatSeamstressPoolBleed.new()
	resolver_down.bind_patch_wardrobe(ctx_down.wardrobe, ctx_down.torn)
	_check(f_down.party.apply_damage(2, 30) and f_down.party.is_downed(2), "down seamstress in battle")
	_reject_custom(resolver_down, f_down, "seamstress_running_stitch", 1, "downed seamstress fails closed")
	_check(not resolver_down.forecast_single(f_down.deck, f_down.party, f_down.enemies, "seamstress_running_stitch", 1).ok,
		"downed seamstress forecast fails closed")

	# 4. Re-sewn / replaced cuff: loose_thread_glove sewn over ARM slot
	var party_rep := _party(2)
	var ctx_rep := _cuff_context(party_rep, "seamstress", true, "red_bobbin_cuff")
	# Re-sew loose_thread_glove onto ARM
	var wardrobe_rep: RunPatchWardrobe = ctx_rep.wardrobe
	var snap_rep: Dictionary = wardrobe_rep.get_snapshot()
	var resew: Dictionary = wardrobe_rep.sew("loose_thread_glove", "seamstress", "ARM", "resew_glove", snap_rep)
	_check(resew.get("ok", false) and wardrobe_rep.get_snapshot()["worn"]["seamstress"]["ARM"] == "loose_thread_glove",
		"loose_thread_glove replaced red_bobbin_cuff on ARM")
	var resolver_rep := CombatSeamstressPoolBleed.new()
	_check(resolver_rep.bind_patch_wardrobe(ctx_rep.wardrobe, ctx_rep.torn), "bind updated wardrobe")
	_check(resolver_rep._patches.card_bleed_bonus("seamstress", "seamstress_running_stitch") == 0,
		"replaced cuff gives 0 bleed bonus")
	var f_rep := _fixture("seamstress_running_stitch", 2)
	_accept_custom(resolver_rep, f_rep, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 4})], 1, "replaced cuff results in unpatched 4 bleed")

	# 5. Invalid explicit binding fails closed
	var resolver_bad := CombatSeamstressPoolBleed.new()
	_check(not resolver_bad.bind_patch_wardrobe(null, null), "null wardrobe fails binding")
	_check(resolver_bad._patches != null and not resolver_bad._patches.is_valid(), "patches invalid")
	var f_bad := _fixture("seamstress_running_stitch", 2)
	_reject_custom(resolver_bad, f_bad, "seamstress_running_stitch", 1, "invalid binding fails closed")
	_check(not resolver_bad.forecast_single(f_bad.deck, f_bad.party, f_bad.enemies, "seamstress_running_stitch", 1).ok,
		"invalid binding forecast fails closed")

	# 6. Not a once-per-turn latch: bonus applies on EVERY cast/recipient
	var party_rpt := _party(2)
	var ctx_rpt := _cuff_context(party_rpt, "seamstress", true, "red_bobbin_cuff")
	var resolver_rpt := CombatSeamstressPoolBleed.new()
	resolver_rpt.bind_patch_wardrobe(ctx_rpt.wardrobe, ctx_rpt.torn)
	var f_rpt := _fixture("seamstress_running_stitch", 2, 3)
	f_rpt.deck.hand.append("seamstress_blanket_stitch")
	# First cast: Running stitch -> Bleed 5
	_accept_custom(resolver_rpt, f_rpt, "seamstress_running_stitch", 1,
		[_hit(1, 2, 0, 2, {"bleed": 5})], 1, "first cast gets cuff bonus")
	# Second cast in same turn: Blanket stitch -> Bleed 4 to EACH living enemy
	f_rpt.deck.combat_state.energy = 3
	var hits_rpt: Array = [
		_hit(1, 0, 0, 0, {"bleed": 4}),
		_hit(2, 0, 0, 0, {"bleed": 4}),
		_hit(3, 0, 0, 0, {"bleed": 4}),
	]
	_accept_custom(resolver_rpt, f_rpt, "seamstress_blanket_stitch", 0, hits_rpt, 2,
		"second cast in same turn retains cuff bonus for all recipients")

	# 7. Seeded replay determinism
	var t1 := _cuff_trace(777123)
	var t2 := _cuff_trace(777123)
	_check(t1 == t2, "seeded traces with cuff match exactly across all fields and RNG")

