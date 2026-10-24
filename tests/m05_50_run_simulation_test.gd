extends SceneTree
## Fifty independent, real-service runs; no fixture kills or outcome injection.

const SEED_COUNT := 50
const TURN_CAP := 80
const ACTION_CAP := 16
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_earned_pool_fixture()
	var start_ms := Time.get_ticks_msec()
	var seeds: Array[int] = []
	var first: Array[Dictionary] = []
	for value in range(1, SEED_COUNT + 1):
		seeds.append(value)
		var trial := _run_seed(value)
		_check(trial.get("ok", false), "seed %d first run: %s" % [value, trial.get("error", "")])
		if not trial.get("ok", false):
			break
		first.append(trial)
	_check(seeds.size() == SEED_COUNT and _unique_count(seeds) == SEED_COUNT,
		"exactly 50 distinct seeds 1..50")
	if failures.is_empty():
		var second: Array[Dictionary] = []
		for value in range(1, SEED_COUNT + 1):
			var replay := _run_seed(value)
			_check(replay.get("ok", false), "seed %d independent replay: %s" % [value, replay.get("error", "")])
			if not replay.get("ok", false):
				break
			second.append(replay)
		_check(first.size() == SEED_COUNT and first == second,
			"every independent replay matches routes, Event records/choices/receipts/wallets/RNG, Shop stock/receipts, combat, stitch/sew and deck")
	if failures.is_empty():
		_report(first)
	var elapsed := Time.get_ticks_msec() - start_ms
	print("m05_50_run_simulation_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks; ", elapsed, " ms)")
	for failure in failures:
		printerr("M05 baseline: ", failure)
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _unique_count(values: Array) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func _load_party() -> CombatParty:
	var records: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	if not records is Array:
		return null
	for hero in records:
		if not hero is Dictionary:
			return null
		hero["max_hp"] = int(hero.get("max_hp", 0))
	return CombatParty.new(records)


func _run_seed(value: int) -> Dictionary:
	var strategy := M05SeededRunStrategy.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var map := RunMap.new()
	if not map.generate(rng):
		return _fail("map generation")
	var initial := _load_party()
	if initial == null or not initial.is_valid():
		return _fail("authored hero roster")
	var carry := RunTornCarryover.new(initial.get_heroes())
	if not carry.is_valid():
		return _fail("torn carryover")
	var deck_ids: Array[String] = []
	var starter: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	if not starter is Array:
		return _fail("starter deck JSON")
	deck_ids.assign(starter)
	var gold := 0
	var scraps := 0
	var descriptors := {}
	var next_stitch_id := 1
	var owned: Array[String] = []
	var shop_catalog: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	if shop_catalog.get("cards", []).is_empty() or shop_catalog.get("trinkets", []).is_empty():
		return _fail("authored priced Shop catalog")
	var patch_defs := RunAuthoredPatchDefinitions.load_definitions()
	if patch_defs.is_empty():
		return _fail("shipped patch catalog")
	var patch_candidates: Array[String] = []
	for item in patch_defs:
		if item.id not in M05SeededRunStrategy.EFFECTIVE_PATCH_EXCLUSIONS:
			patch_candidates.append(item.id)
	var wardrobe := RunPatchWardrobe.new(carry.read_state().heroes, owned,
		patch_defs, scraps, gold, deck_ids, value)
	if not wardrobe.is_valid() or not carry.bind_wardrobe(
			wardrobe, carry.torn, wardrobe.get_snapshot()):
		return _fail("authentic initial wardrobe/carryover binding")
	var selector := RunFightEncounterSelection.new()
	var battles := 0
	var fights := 0
	var elites := 0
	var plays := 0
	var phases := 0
	var picks := 0
	var skips := 0
	var stitches := 0
	var sews := 0
	var treasure_visits := 0
	var event_visits: Array[Dictionary] = []
	var event_history: Array[String] = []
	var shop_visits: Array[Dictionary] = []
	var purchased_ids: Array[String] = []
	var acquired_ids: Array[String] = []
	var earned_plays: Array[Dictionary] = []
	var unaffordable_checks := 0
	var won := false
	var lost := false
	var action_total := 0
	var trace: Array[String] = []
	for floor_index in range(RunMap.FLOOR_COUNT):
		if carry.read_state().heroes.filter(func(h): return h.hp > 0).is_empty():
			return _fail("run continued without living party")
		var legal := map.get_legal_choices()
		var choice := strategy.choose_route(map, carry.read_state().heroes,
			scraps, stitches, fights, elites, gold, shop_catalog.cards)
		if not legal.has(choice) or not map.choose_node(choice):
			return _fail("illegal connected route on floor %d" % [floor_index + 1])
		if map.get_current_floor() != floor_index + 1 				or map.get_route().size() != floor_index + 1:
			return _fail("route prefix mismatch")
		trace.append(choice)
		var node := map.get_node(choice)
		var kind: String = node.type
		if kind in ["Fight", "Elite", "Boss"]:
			battles += 1
			var admitted := RunStitchedBattleHandEntry.new().admit_next_fight(
				deck_ids, descriptors, scraps, next_stitch_id,
				RunRestStitchCards.new(deck_ids, descriptors, scraps, next_stitch_id).get_snapshot().receipt, rng)
			if not admitted.get("ok", false):
				return _fail("authentic run deck admission %s" % choice)
			var combat_deck: CombatDeck = admitted.combat_deck
			var run_cards: RunRestStitchCards = admitted.run_cards
			var party := carry.create_next_fight_party()
			if party == null or not party.is_valid():
				return _fail("canonical carried party admission %s" % choice)
			var entered := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
			if not entered.get("success", false) or entered.node_type != kind:
				return _fail("typed authored encounter admission %s" % choice)
			var enemies: CombatEnemies = entered.enemies
			var intents: CombatEnemyIntents = entered.intents
			if not intents.bind_battle(enemies, party, rng):
				return _fail("live weighted enemy announcement %s" % choice)
			var tiers := {}
			for position in range(1, enemies.get_enemies().size() + 1):
				tiers[position] = "boss" if kind == "Boss" else ("elite" if kind == "Elite" else "normal")
			var unravel := CombatUnravel.new()
			if not unravel.bind_roster(enemies, tiers):
				return _fail("Unravel roster")
			var result := CombatBattleResult.new(party, enemies)
			var flow := CombatRoundFlow.new(combat_deck, party, enemies, intents, result, unravel)
			if not flow.begin_fight() or not carry.begin_battle(choice, result, party):
				return _fail("genuine combat start and observed carryover %s" % choice)
			if combat_deck.energy != CombatState.TURN_ENERGY or combat_deck.hand.size() != 5:
				return _fail("turn draws five with three energy")
			var attacks := CombatAttackCards.new()
			var support := CombatSupportCards.new()
			var stitched := CombatStitchedCards.new(attacks)
			var plain := CombatPoolPlainStrikes.new()
			var heavy := CombatWardenPoolHeavyAttacks.new()
			if not attacks.bind_patch_wardrobe(wardrobe, carry.torn) 					or not support.bind_patch_wardrobe(wardrobe, carry.torn) 					or not stitched.bind_patch_wardrobe(wardrobe, carry.torn) \
					or not plain.bind_patch_wardrobe(wardrobe, carry.torn) \
					or not heavy.bind_patch_wardrobe(wardrobe, carry.torn):
				return _fail("genuinely worn patch rules binding")
			attacks.start_player_turn()
			var terminal := ""
			for turn in range(TURN_CAP):
				var rejected_ids: Array = []
				for action_index in range(ACTION_CAP):
					action_total += 1
					var decision := strategy.choose_card(combat_deck, party, enemies,
						attacks, run_cards, plain, heavy, rejected_ids)
					if decision.is_empty():
						break
					var before := _combat_snapshot(combat_deck, party, enemies, rng)
					var accepted := false
					var pool_receipt := {}
					match decision.kind:
						"earned_pool":
							if not acquired_ids.has(decision.id):
								return _fail("unearned pool card selected from hand")
							pool_receipt = (heavy.play_attack(combat_deck, party, enemies,
								decision.id, decision.target) if heavy.is_supported_card(decision.id)
								else plain.play_card(combat_deck, party, enemies, decision.id, decision.target))
							accepted = pool_receipt.get("ok", false)
						"attack":
							accepted = attacks.play_attack(combat_deck, party, enemies,
								decision.id, decision.target).get("ok", false)
						"support":
							var def := StarterCards.new().get_definition(decision.id)
							var effect := "draw"
							var amount: int = def.effects.get("draw", 0)
							if def.effects.has("block"):
								effect = "self_block" if def.target_kind == "self" else "ally_block"
								amount = def.effects.block
							elif def.effects.has("heal"):
								effect = "ally_heal"
								amount = def.effects.heal
							var normalized := {"id": decision.id, "owner_id": def.owner,
								"cost": def.cost, "from_positions": def.from_positions,
								"effect": effect, "amount": amount}
							accepted = support.play_support(combat_deck, party, normalized, decision.target)
						"stitched":
							accepted = stitched.play_stitched(combat_deck, party, enemies,
								run_cards, decision.id, decision.first, decision.second).get("ok", false)
					if not accepted:
						if before != _combat_snapshot(combat_deck, party, enemies, rng):
							return _fail("rejected card mutated paid combat/RNG")
						rejected_ids.append(decision.id)
						continue
					if decision.kind == "earned_pool":
						var definition := strategy._pool_definition(decision.id)
						if not _pool_transition_valid(before, combat_deck, party, enemies,
								rng, decision, definition, pool_receipt):
							return _fail("earned pool receipt/payment/roster transition")
						earned_plays.append({"id": decision.id, "target": decision.target,
							"receipt": pool_receipt.duplicate(true), "battle": choice})
					plays += 1
					if before[0] <= combat_deck.energy and decision.kind != "support":
						return _fail("paid combat did not charge energy")
					if decision.kind == "support":
						# Draw support can refill from discard before its own discard.
						var oracle_rng := RandomNumberGenerator.new()
						oracle_rng.state = int(before[6])
						var oracle := CombatDeck.new([], oracle_rng)
						oracle.hand.assign(before[1])
						oracle.discard_pile.assign(before[2])
						oracle.draw_pile.assign(before[3])
						oracle.combat_state.player_turn_active = true
						var definition := StarterCards.new().get_definition(decision.id)
						oracle.draw_extra(int(definition.effects.get("draw", 0)))
						if not oracle.discard_played(decision.id) or oracle.hand != combat_deck.hand \
								or oracle.draw_pile != combat_deck.draw_pile or oracle.discard_pile != combat_deck.discard_pile \
								or oracle_rng.state != rng.state or combat_deck.energy != before[0] - definition.cost:
							return _fail("support exact draw/refill, one payment and one discard")
					elif combat_deck.discard_pile.count(decision.id) <= before[2].count(decision.id):
						return _fail("confirmed card not discarded")
					if flow.observe_result() != CombatBattleResult.ACTIVE:
						break
				terminal = flow.get_outcome()
				if terminal != CombatBattleResult.ACTIVE:
					break
				var before_turn: int = intents._turn_index
				if not flow.end_turn():
					return _fail("bounded authoritative enemy turn refused %s" % choice)
				if intents._turn_index > before_turn:
					phases += 1
					attacks.start_player_turn()
				terminal = flow.observe_result()
				if terminal != CombatBattleResult.ACTIVE:
					break
			if terminal not in [CombatBattleResult.VICTORY, CombatBattleResult.DEFEAT]:
				return _fail("encounter exceeded %d real turns %s" % [TURN_CAP, choice])
			if terminal == CombatBattleResult.DEFEAT:
				if not party.is_defeated() or enemies.is_victorious():
					return _fail("non-authentic defeat")
				lost = true
				break
			if not enemies.is_victorious() or party.is_defeated():
				return _fail("non-authentic victory")
			if kind == "Boss":
				won = true
				break
			var reward := RunMultiFightRewards.new(map, rng, carry, deck_ids, gold,
				owned, RunPoolCardRewardOffers.get_authored_base_candidates(),
				patch_candidates, descriptors, next_stitch_id)
			var offer := reward.prepare(choice, result, party)
			if not offer.get("ok", false) or offer.offers.size() != 3:
				return _fail("genuine weighted three-card victory offer")
			var selected := strategy.choose_reward(offer.offers, value, picks)
			var settled := reward.choose(choice, selected)
			if not settled.get("ok", false):
				return _fail("genuine reward pick/skip failed")
			if not carry.apply_reward(choice, result, party).get("ok", false):
				return _fail("torn carryover failed to publish witnessed settlement")
			if not selected.is_empty():
				acquired_ids.append(selected)
			picks += 1 if not selected.is_empty() else 0
			skips += 1 if selected.is_empty() else 0
			deck_ids.assign(settled.state.deck)
			gold = settled.state.gold
			owned.assign(settled.state.trinkets)
			scraps += 2 if kind == "Elite" else 1
			fights += 1 if kind == "Fight" else 0
			elites += 1 if kind == "Elite" else 0
			if not wardrobe.refresh_run_context(carry.read_state().heroes,
					owned, scraps, gold, deck_ids, wardrobe.get_snapshot()):
				return _fail("post-victory wardrobe context")
			var sew := strategy.choose_sew(wardrobe, carry.read_state().heroes)
			if not sew.is_empty():
				var receipt := wardrobe.sew(sew.patch_id, sew.hero_id, sew.slot,
					"sew_%s" % choice, wardrobe.get_snapshot())
				if not receipt.get("ok", false) or receipt.receipt.kind != "sew":
					return _fail("eligible owned Elite patch rejected sewing")
				sews += 1
		elif kind == "Rest":
			if not wardrobe.start_rest(choice, wardrobe.get_snapshot()).get("ok", false):
				return _fail("Rest wardrobe opening")
			var pair := strategy.choose_stitch(deck_ids, carry.read_state().heroes, scraps)
			if not pair.is_empty():
				var rest := RunRestStitchCards.new(deck_ids, descriptors, scraps, next_stitch_id)
				if not rest.is_valid():
					return _fail("real Rest stitch ledger")
				var stitched_receipt := rest.choose_stitch(pair.first, pair.second, rest.get_snapshot())
				if not stitched_receipt.get("ok", false) or not rest.is_consumed():
					return _fail("legal cross-owner Rest stitching")
				deck_ids.assign(stitched_receipt.deck)
				descriptors = stitched_receipt.descriptors.duplicate(true)
				scraps = stitched_receipt.remaining_scraps
				next_stitch_id = stitched_receipt.next_stitch_id
				stitches += 1
				if not wardrobe.refresh_run_context(carry.read_state().heroes,
						owned, scraps, gold, deck_ids, wardrobe.get_snapshot()):
					return _fail("stitched wardrobe context")
			elif not carry.choose_rest_heal(choice).get("ok", false):
				return _fail("authentic Rest heal/revive")
			if not wardrobe.end_rest(choice, wardrobe.get_snapshot()).get("ok", false):
				return _fail("Rest wardrobe closing")
		elif kind == "Shop":
			var party_ids: Array[String] = []
			for hero in carry.read_state().heroes:
				party_ids.append(hero.id)
			var offers := RunShopStockOffers.generate(rng, party_ids,
				shop_catalog.cards, shop_catalog.trinkets, owned)
			if not offers.get("ok", false) or offers.cards.size() != 5 or offers.trinkets.size() != 2:
				return _fail("seven authored seeded Shop offers")
			var shop := RunShopPurchases.new(party_ids, deck_ids, owned, gold, offers.cards, offers.trinkets)
			if not shop.is_valid():
				return _fail("authoritative Shop purchase admission")
			var before := _shop_snapshot(shop, rng)
			if not _shop_rejects(shop, "unlisted_card", rng):
				return _fail("unlisted Shop choice mutated state/stock/RNG")
			for listing in shop.get_stock().cards:
				if listing.price > gold:
					if not _shop_rejects(shop, listing.id, rng):
						return _fail("unaffordable Shop choice mutated state/stock/RNG")
					unaffordable_checks += 1
			var selected := strategy.choose_shop_card(shop.get_stock(), gold)
			var reversed_stock := shop.get_stock()
			reversed_stock.cards.reverse()
			if selected != strategy.choose_shop_card(shop.get_stock(), gold) \
					or selected != strategy.choose_shop_card(reversed_stock, gold) or before != _shop_snapshot(shop, rng):
				return _fail("Shop strategy not repeatable/read-only")
			var paid := {}
			if not selected.is_empty():
				var bought := shop.buy("card", selected)
				var expected_stock: Dictionary = before[1].duplicate(true)
				var price := -1
				for listing in expected_stock.cards:
					if listing.id == selected:
						price = listing.price
						listing.sold = true
				var expected_state: Dictionary = before[0].duplicate(true)
				expected_state.deck.append(selected)
				expected_state.gold -= price
				if price < 0 or not bought.get("ok", false) or bought.get("receipt", {}) != {
						"kind": "card", "id": selected, "price": price} or bought.state != expected_state \
						or bought.stock != expected_stock or shop.get_state() != expected_state \
						or shop.get_stock() != expected_stock or str(rng.state) != before[2]:
					return _fail("Shop receipt must add exactly one card and spend its listed price once")
				if not _shop_rejects(shop, selected, rng):
					return _fail("repeated Shop purchase mutated state/stock/RNG")
				# Publish only the authenticated service result; stitch registry/cursor stay intact.
				deck_ids.assign(bought.state.deck)
				gold = bought.state.gold
				owned.assign(bought.state.trinkets)
				paid = bought.receipt.duplicate(true)
				purchased_ids.append(paid.id)
				acquired_ids.append(paid.id)
				if not wardrobe.refresh_run_context(carry.read_state().heroes,
						owned, scraps, gold, deck_ids, wardrobe.get_snapshot()):
					return _fail("post-purchase wardrobe context")
			else:
				if shop.get_stock().cards.any(func(listing): return not listing.sold and listing.price <= gold) \
						or before != _shop_snapshot(shop, rng):
					return _fail("unaffordable Shop must leave all authorities unchanged")
			shop_visits.append({"node": choice, "offers": offers.duplicate(true),
				"before": before, "after": _shop_snapshot(shop, rng), "receipt": paid})
		elif kind == "Event":
			var before := _event_snapshot(map, carry, wardrobe, deck_ids,
				descriptors, next_stitch_id, gold, scraps, owned, rng, event_history)
			var visit := _visit_event(event_visits.size(), strategy, deck_ids,
				descriptors, next_stitch_id, gold, scraps, rng, event_history)
			if not visit.get("ok", false):
				return visit
			# Only generic admission draws RNG; choice services never mutate authorities.
			var unchanged := before.duplicate(true)
			unchanged[10] = str(rng.state)
			if unchanged != _event_snapshot(map, carry, wardrobe, deck_ids,
					descriptors, next_stitch_id, gold, scraps, owned, rng, event_history):
				return _fail("Event service mutated caller authorities")
			gold = visit.wallet.gold
			scraps = visit.wallet.scraps
			if visit.generic:
				event_history.append(visit.record.id)
			if not wardrobe.refresh_run_context(carry.read_state().heroes,
					owned, scraps, gold, deck_ids, wardrobe.get_snapshot()):
				return _fail("post-Event authoritative wardrobe refresh")
			var expected := before.duplicate(true)
			expected[2] = wardrobe.get_snapshot()
			expected[6] = gold
			expected[7] = scraps
			expected[10] = str(rng.state)
			expected[11] = event_history.duplicate()
			var after := _event_snapshot(map, carry, wardrobe, deck_ids,
				descriptors, next_stitch_id, gold, scraps, owned, rng, event_history)
			var context := wardrobe.get_snapshot()
			if after != expected or context.gold != gold or context.scraps != scraps \
					or context.cards != deck_ids or context.heroes != carry.read_state().heroes \
					or context.owned != owned:
				return _fail("Event changed unrelated authority or left stale wardrobe")
			visit["node"] = choice
			visit["before"] = before
			visit["after"] = after
			event_visits.append(visit)
		elif kind == "Treasure":
			treasure_visits += 1
		else:
			return _fail("unsupported route kind")
		if gold < 0 or scraps < 0 or not RunRestStitchCards.new(
				deck_ids, descriptors, scraps, next_stitch_id).is_valid():
			return _fail("negative wallet or forged durable run deck")
	if not won and not lost:
		return _fail("12-floor terminal reached without genuine Boss result")
	if plays == 0 or phases == 0 or battles == 0:
		return _fail("vacuous combat: no accepted charged plays or enemy phase")
	return {"ok": true, "seed": value, "floor": map.get_current_floor(),
		"route": trace, "won": won, "lost": lost, "rng": str(rng.state),
		"deck": deck_ids.duplicate(), "stitches": stitches, "sews": sews,
		"plays": plays, "phases": phases, "picks": picks, "skips": skips,
		"battles": battles, "treasure_visits": treasure_visits, "event_visits": event_visits,
		"shop_visits": shop_visits, "purchased_ids": purchased_ids,
		"acquired_ids": acquired_ids, "earned_plays": earned_plays,
		"unaffordable_checks": unaffordable_checks,
		"gold": gold, "scraps": scraps, "actions": action_total}


func _pool_transition_valid(before: Array, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, rng: RandomNumberGenerator, decision: Dictionary,
		definition: Dictionary, receipt: Dictionary) -> bool:
	if definition.is_empty() or not receipt.get("ok", false) or receipt.get("hits", []).is_empty():
		return false
	if deck.energy != before[0] - definition.cost or str(rng.state) != before[6] \
			or deck.hand.count(decision.id) != before[1].count(decision.id) - 1 \
			or deck.discard_pile.count(decision.id) != before[2].count(decision.id) + 1 \
			or deck.draw_pile != before[3]:
		return false
	var target := int(decision.get("target", 0))
	if target < 1 or target > before[5].size():
		return false
	var old_enemy: Dictionary = before[5][target - 1]
	var new_enemy: Dictionary = enemies.get_enemy(target)
	var absorbed := 0
	var hp_loss := 0
	for hit in receipt.hits:
		if hit.position != target or hit.damage <= 0:
			return false
		absorbed += int(hit.block_absorbed)
		hp_loss += int(hit.hp_loss)
	if old_enemy.block - new_enemy.block != absorbed or old_enemy.hp - new_enemy.hp != hp_loss:
		return false
	for index in range(before[5].size()):
		if index + 1 != target and before[5][index] != enemies.get_enemy(index + 1):
			return false
	var old_heroes: Array = before[4]
	var new_heroes := party.get_heroes()
	var block_deltas: Dictionary = receipt.get("block_deltas", {})
	for index in range(old_heroes.size()):
		var old_hero: Dictionary = old_heroes[index]
		var new_hero: Dictionary = new_heroes[index]
		if new_hero.hp != old_hero.hp or new_hero.block - old_hero.block != int(
				block_deltas.get(old_hero.position, 0)):
			return false
	return true


func _test_earned_pool_fixture() -> void:
	var cases := [
		["warden_brass_buckle", 1, [1, 2], [1, 2], 5, 4, 1],
		["warden_brass_buckle_plus", 1, [1, 2], [1, 2], 7, 6, 1],
		["seamstress_thread_whip", 1, [1, 2, 3], [1, 2], 6, 0, 1],
		["seamstress_thread_whip_plus", 1, [1, 2, 3], [1, 2], 8, 0, 1],
		["warden_heavy_thimble", 2, [1], [1, 2], 11, 0, 1],
		["warden_heavy_thimble_plus", 2, [1], [1, 2], 15, 0, 1],
		["warden_pin_and_pound", 2, [1], [1, 2, 3], 9, 0, 2],
		["warden_pin_and_pound_plus", 2, [1], [1, 2, 3], 12, 0, 2],
	]
	var strategy := M05SeededRunStrategy.new()
	for row in cases:
		var id: String = row[0]
		var definition := strategy._pool_definition(id)
		_check(definition.get("cost") == row[1] and definition.get("from_positions") == row[2] \
			and definition.get("to_positions") == row[3] \
			and definition.get("effects", {}).get("damage") == row[4] \
			and definition.get("effects", {}).get("block", 0) == row[5] \
			and definition.get("effects", {}).get("hits", 1) == row[6],
			"pool authored cost/FROM/TO/effects " + id)
		var rng := RandomNumberGenerator.new()
		rng.seed = 8401
		var deck := CombatDeck.new([id], rng)
		var party := CombatParty.new([
			{"id": "warden", "max_hp": 40},
			{"id": "seamstress", "max_hp": 30},
			{"id": "tinker", "max_hp": 26}])
		var enemies := CombatEnemies.new([
			{"id": "foe_1", "max_hp": 50},
			{"id": "foe_2", "max_hp": 50},
			{"id": "foe_3", "max_hp": 50}])
		_check(deck.start_turn() and deck.hand.has(id) and party.is_valid() and enemies.is_valid(),
			"pool real held-card fixture " + id)
		_check(enemies.gain_block(1, 3), "pool real enemy Block fixture " + id)
		var plain := CombatPoolPlainStrikes.new()
		var heavy := CombatWardenPoolHeavyAttacks.new()
		var decision := strategy.choose_card(deck, party, enemies, CombatAttackCards.new(),
			RunRestStitchCards.new(StarterCards.new().get_starting_deck(), {}, 0, 1),
			plain, heavy, [])
		_check(decision.get("kind") == "earned_pool" and decision.get("id") == id \
			and decision.get("target") == 1, "pool strategy chooses legal held card " + id)
		var before := _combat_snapshot(deck, party, enemies, rng)
		var receipt := (heavy.play_attack(deck, party, enemies, id, 1)
			if heavy.is_supported_card(id) else plain.play_card(deck, party, enemies, id, 1))
		_check(_pool_transition_valid(before, deck, party, enemies, rng, decision,
			definition, receipt), "pool resolver one charge/discard and receipt " + id)
		var hits: Array = receipt.get("hits", [])
		_check(hits.size() == row[6], "pool real hit count " + id)
		if hits.size() == row[6]:
			for hit_index in range(hits.size()):
				_check(hits[hit_index].damage == row[4] \
					and hits[hit_index].block_absorbed == (3 if hit_index == 0 else 0),
					"pool authored hit and Block absorption " + id)
		if row[5] > 0:
			_check(party.get_hero(1).block == row[5], "Brass Buckle owner Block " + id)
		# A second cast of the spent copy is a resolver refusal, not a second action.
		var spent := _combat_snapshot(deck, party, enemies, rng)
		var denied := (heavy.play_attack(deck, party, enemies, id, 1)
			if heavy.is_supported_card(id) else plain.play_card(deck, party, enemies, id, 1))
		_check(not denied.get("ok", true) and spent == _combat_snapshot(deck, party, enemies, rng),
			"spent pool copy rejects without mutation " + id)
	_test_pool_negative_positions()


func _test_pool_negative_positions() -> void:
	var strategy := M05SeededRunStrategy.new()
	for id in ["warden_brass_buckle", "warden_heavy_thimble"]:
		var heavy := CombatWardenPoolHeavyAttacks.new()
		var plain := CombatPoolPlainStrikes.new()
		for condition in ["wrong_owner_slot", "downed_owner", "no_energy", "dead_target", "invalid_target", "out_of_range"]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 481
			var deck := CombatDeck.new([id], rng)
			var order := ["seamstress", "tinker", "warden"] if condition == "wrong_owner_slot" \
				else ["warden", "seamstress", "tinker"]
			var defs: Array = []
			for hero_id in order:
				defs.append({"id": hero_id, "max_hp": 30})
			var party := CombatParty.new(defs)
			var enemies := CombatEnemies.new([
				{"id": "foe_1", "max_hp": 30},
				{"id": "foe_2", "max_hp": 30},
				{"id": "foe_3", "max_hp": 30}])
			_check(deck.start_turn() and deck.hand.has(id) and party.is_valid() \
				and enemies.is_valid(), "non-vacuous pool refusal fixture " + condition + id)
			if condition == "downed_owner":
				party.apply_damage(1, 30)
			elif condition == "no_energy":
				deck.try_spend_energy(3)
			elif condition == "dead_target":
				for position in [1, 2]:
					enemies.apply_damage(position, 30)
			_check((condition != "wrong_owner_slot" or party.get_hero(3).id == "warden") \
				and (condition != "downed_owner" or party.is_downed(1)) \
				and (condition != "no_energy" or deck.energy == 0) \
				and (condition != "dead_target" or (enemies.is_slain(1) and enemies.is_slain(2))),
				"pool refusal condition is real " + condition + id)
			var target := (0 if condition == "invalid_target" else (3 if condition == "out_of_range" else 1))
			var before := _combat_snapshot(deck, party, enemies, rng)
			if condition not in ["out_of_range", "invalid_target"]:
				var decision := strategy.choose_card(deck, party, enemies,
					CombatAttackCards.new(), RunRestStitchCards.new(
						StarterCards.new().get_starting_deck(), {}, 0, 1),
					plain, heavy, [])
				_check(decision.is_empty(), "strategy skips invalid pool card " + condition + id)
			var denied := (heavy.play_attack(deck, party, enemies, id, target)
				if heavy.is_supported_card(id) else plain.play_card(deck, party, enemies, id, target))
			_check(not denied.get("ok", true) and before == _combat_snapshot(deck, party, enemies, rng),
				"pool resolver refusal preserves combat/RNG " + condition + id)


func _event_snapshot(map: RunMap, carry: RunTornCarryover, wardrobe: RunPatchWardrobe,
		deck: Array, descriptors: Dictionary, cursor: int, gold: int, scraps: int,
		owned: Array, rng: RandomNumberGenerator, history: Array) -> Array:
	return [map.get_route(), carry.read_state(), wardrobe.get_snapshot(), deck.duplicate(),
		descriptors.duplicate(true), cursor, gold, scraps, owned.duplicate(),
		carry.torn.read_state(), str(rng.state), history.duplicate()]


func _special_choice(service: RefCounted, index: int, event_id: String,
		choice_id: String, scraps: int) -> Dictionary:
	if index == 0:
		return service.choose(event_id, choice_id, scraps)
	return service.choose(event_id, choice_id)


func _event_service_snapshot(service: RefCounted, index: int) -> Array:
	if index == 0:
		return [service.is_consumed()]
	if index == 1:
		return [service.is_consumed(), service.get_deck(), service.get_descriptors(),
			service.get_next_stitch_id(), service.get_scraps()]
	if index == 2:
		return [service.get_snapshot()]
	return [service.is_claimed(), service.get_event()]


func _visit_event(index: int, strategy: M05SeededRunStrategy, deck: Array,
		descriptors: Dictionary, cursor: int, gold: int, scraps: int,
		rng: RandomNumberGenerator, history: Array) -> Dictionary:
	var record := {}
	var selected := ""
	var service: RefCounted
	var wallet := {"gold": gold, "scraps": scraps}
	var rng_before := str(rng.state)
	if index < 3:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/events/m04_events.json"))
		if index == 0:
			for item in document.events:
				if item.id == "quiet_spool":
					record = item.duplicate(true)
			selected = "watch"
			service = RunQuietSpoolOutcome.new()
		elif index == 1:
			record = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/moth_infestation.json"))
			selected = "escape"
			service = RunMothInfestationOutcome.new(deck, descriptors, cursor, scraps)
			if not service.is_valid():
				return _fail("Moth admission requires genuine ledger")
		else:
			record = RunDyeVatOutcome.load_authored_event()
			selected = "skim_dye"
			service = RunDyeVatOutcome.new(deck, descriptors, scraps, cursor)
			if not service.is_valid():
				return _fail("Dye admission requires genuine ledger")
	else:
		var rotation := RunM04EventRotation.new()
		if not rotation.is_catalog_valid():
			return _fail("generic authored Event rotation")
		# Invalid/exhausted rotation cannot spend RNG, even before a real draw.
		if rotation.select_event(rng, [17]).ok \
				or rotation.select_event(rng, rotation.get_generic_event_ids()).ok \
				or str(rng.state) != rng_before:
			return _fail("rejected Event admission spent RNG")
		var oracle_rng := RandomNumberGenerator.new()
		oracle_rng.state = rng.state
		var eligible := rotation.get_generic_events().filter(func(item): return not history.has(item.id))
		if eligible.is_empty():
			return _fail("generic Event eligible pool exhausted")
		var expected: Dictionary = eligible[oracle_rng.randi_range(0, eligible.size() - 1)]
		var selection := rotation.select_event(rng, history)
		if not selection.ok or selection.event != expected or rng.state != oracle_rng.state \
				or history.has(selection.event.id):
			return _fail("generic Event must use shared RNG and exclude prior history")
		record = selection.event
		service = RunEventChoice.new(record)
	if record.is_empty() or not RunEventChoice.new(record).is_valid():
		return _fail("non-vacuous authored Event record")
	var choice_rng := str(rng.state)
	var forecast := RunEventChoice.new(record).preview_wallet_choices(wallet)
	if not forecast.ok or forecast.choices.is_empty():
		return _fail("Event affordability forecast")
	var rejected: Dictionary
	var unclaimed := _event_service_snapshot(service, index)
	if index < 3:
		rejected = _special_choice(service, index, record.id, "unlisted_choice", scraps)
	else:
		rejected = service.choose_with_wallet("unlisted_choice", wallet)
	if rejected.ok or unclaimed != _event_service_snapshot(service, index) or str(rng.state) != choice_rng:
		return _fail("invalid Event choice accepted or spent ledger/RNG")
	var unaffordable := 0
	if index >= 3:
		for entry in forecast.choices:
			if not entry.affordable:
				var denied: Dictionary = service.choose_with_wallet(entry.choice_id, wallet)
				if denied.ok or denied.wallet != wallet or unclaimed != _event_service_snapshot(service, index) \
						or str(rng.state) != choice_rng:
					return _fail("unaffordable Event must not spend or latch")
				denied.wallet.gold = -123
				if wallet != {"gold": gold, "scraps": scraps}:
					return _fail("rejected Event wallet aliases caller")
				unaffordable += 1
		selected = strategy.choose_event_choice(forecast)
		var reversed := forecast.duplicate(true)
		reversed.choices.reverse()
		if selected.is_empty() or selected != strategy.choose_event_choice(forecast) \
				or selected != strategy.choose_event_choice(reversed):
			return _fail("Event strategy deterministic choice/tie break")
	var matches: Array = forecast.choices.filter(func(item): return item.choice_id == selected)
	if matches.size() != 1 or not matches[0].affordable:
		return _fail("chosen Event forecast must be affordable")
	var authored: Array = record.choices.filter(func(item): return item.id == selected)
	var expected_wallet := {"gold": gold + int(authored[0].outcome.gold),
		"scraps": scraps + int(authored[0].outcome.scraps)}
	var receipt: Dictionary
	var duplicate: Dictionary
	var committed: Array
	if index < 3:
		receipt = _special_choice(service, index, record.id, selected, scraps)
		committed = _event_service_snapshot(service, index)
		duplicate = _special_choice(service, index, record.id, selected, expected_wallet.scraps)
		if receipt.get("scraps", -1) != expected_wallet.scraps:
			return _fail("special Event authored scrap delta")
		if index > 0 and (receipt.get("deck") != deck or receipt.get("descriptors") != descriptors \
				or receipt.get("next_stitch_id") != cursor):
			return _fail("special Event must preserve full stitch ledger")
		if duplicate.get("scraps", -1) != (expected_wallet.scraps if index < 2 else scraps):
			return _fail("repeated special Event changed ledger")
	else:
		receipt = service.choose_with_wallet(selected, wallet)
		committed = _event_service_snapshot(service, index)
		duplicate = service.choose_with_wallet(selected, expected_wallet)
		if receipt.get("wallet") != expected_wallet or duplicate.wallet != expected_wallet:
			return _fail("generic Event exact authored settlement once")
	if not receipt.ok or receipt.event_id != record.id or receipt.choice_id != selected \
			or duplicate.ok or committed != _event_service_snapshot(service, index) \
			or matches[0].wallet != expected_wallet or str(rng.state) != choice_rng \
			or wallet != {"gold": gold, "scraps": scraps}:
		return _fail("Event receipt/duplicate/forecast/RNG invariants")
	var detached: Dictionary = service.get_event() if index >= 3 else record.duplicate(true)
	detached.choices.clear()
	if record.choices.is_empty() or (index >= 3 and service.get_event() != record):
		return _fail("Event record must remain detached")
	var saved_receipt := receipt.duplicate(true)
	if receipt.has("deck"):
		receipt.deck.append("detachment_probe")
		receipt.descriptors["detachment_probe"] = {}
	if receipt.has("wallet"):
		receipt.wallet.gold = -123
	if committed != _event_service_snapshot(service, index) or wallet != {"gold": gold, "scraps": scraps}:
		return _fail("Event receipt aliases live state")
	return {"ok": true, "generic": index >= 3, "record": record.duplicate(true),
		"receipt": saved_receipt, "wallet": expected_wallet.duplicate(),
		"forecast": forecast.duplicate(true), "unaffordable": unaffordable,
		"rng_before": rng_before, "rng_after": str(rng.state)}


func _combat_snapshot(deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, rng: RandomNumberGenerator) -> Array:
	return [deck.energy, deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.draw_pile.duplicate(), party.get_heroes(), enemies.get_enemies(), str(rng.state)]


func _shop_snapshot(shop: RunShopPurchases, rng: RandomNumberGenerator) -> Array:
	return [shop.get_state(), shop.get_stock(), str(rng.state)]


func _shop_rejects(shop: RunShopPurchases, id: String, rng: RandomNumberGenerator) -> bool:
	var before := _shop_snapshot(shop, rng)
	var rejected := shop.buy("card", id)
	if rejected.get("ok", true) or rejected.has("receipt") or before != _shop_snapshot(shop, rng) \
			or rejected.state != before[0] or rejected.stock != before[1]:
		return false
	# Returned nested state must not alias the live purchase ledger.
	rejected.state.deck.append("detachment_probe")
	rejected.stock.cards[0].sold = not rejected.stock.cards[0].sold
	return before == _shop_snapshot(shop, rng)


func _report(trials: Array[Dictionary]) -> void:
	var wins := 0
	var floor_total := 0
	var stitches := 0
	var sews := 0
	var picks := 0
	var skips := 0
	var plays := 0
	var phases := 0
	var treasures := 0
	var specials := {}
	var generic := 0
	var event_unaffordable := 0
	var visits := 0
	var purchases := 0
	var unaffordable := 0
	var frequencies := {}
	var acquired := {}
	var winning_acquired := {}
	var earned_plays := 0
	var earned_receipts := []
	var starter_ids := StarterCards.new().get_starting_deck()
	for trial in trials:
		wins += 1 if trial.won else 0
		floor_total += trial.floor
		stitches += trial.stitches
		sews += trial.sews
		picks += trial.picks
		skips += trial.skips
		plays += trial.plays
		phases += trial.phases
		treasures += trial.treasure_visits
		for visit in trial.event_visits:
			if visit.generic:
				generic += 1
			else:
				specials[visit.record.id] = specials.get(visit.record.id, 0) + 1
			event_unaffordable += visit.unaffordable
			print("M05 seed=%d Event=%s choice=%s wallet=%s RNG=%s" % [trial.seed,
				visit.record.id, visit.receipt.choice_id, JSON.stringify(visit.wallet), visit.rng_after])
		visits += trial.shop_visits.size()
		purchases += trial.purchased_ids.size()
		for id in trial.acquired_ids:
			acquired[id] = acquired.get(id, 0) + 1
		for event in trial.earned_plays:
			_check(trial.acquired_ids.has(event.id) and event.receipt.get("ok", false) \
				and not event.receipt.get("hits", []).is_empty(),
				"accepted earned play has genuine acquired ID and hit receipt")
			earned_plays += 1
			earned_receipts.append({"seed": trial.seed, "id": event.id,
				"battle": event.battle, "receipt": event.receipt})
		unaffordable += trial.unaffordable_checks
		var receipts: Array = []
		for visit in trial.shop_visits:
			if not visit.receipt.is_empty():
				receipts.append(visit.receipt)
		print("M05 seed=%d Shop visits=%d paid=%s acquired=%s final_gold=%d RNG=%s" % [
			trial.seed, trial.shop_visits.size(), JSON.stringify(receipts),
			JSON.stringify(trial.purchased_ids), trial.gold, trial.rng])
		_check(trial.route.size() == trial.floor and trial.floor >= 1 and trial.floor <= 12,
			"terminal route length equals actual reached floor")
		_check(trial.gold >= 0 and trial.scraps >= 0 and trial.actions <= 12 * TURN_CAP * ACTION_CAP,
			"wallet and finite action cap")
		if trial.won:
			for id in trial.acquired_ids:
				winning_acquired[id] = true
			var seen := {}
			for card_id in trial.deck:
				seen[card_id] = true
			for card_id in seen:
				frequencies[card_id] = frequencies.get(card_id, 0) + 1
	_check(plays > 0 and phases > 0 and picks > 0 and skips > 0,
		"nonzero genuine charged/discarded play, enemy phase, reward pick and skip")
	_check(earned_plays > 0 and not earned_receipts.is_empty(),
		"cohort actually commits acquired supported pool attacks in later hands")
	_check(stitches > 0 and sews > 0,
		"cohort must actually commit a Rest stitch and an owned patch sew")
	_check(visits > 0 and purchases > 0 and unaffordable > 0,
		"cohort witnesses legal Shop visits, paid card receipts and unaffordable rejections")
	for event_id in ["quiet_spool", "moth_infestation", "dye_vat"]:
		_check(specials.get(event_id, 0) > 0, "cohort commits real special Event " + event_id)
	_check(generic > 0 and event_unaffordable > 0,
		"cohort commits seeded generic Event wallet choices and rejects unaffordable choices")
	_check(wins >= 0 and wins <= SEED_COUNT and floor_total >= SEED_COUNT,
		"aggregate arithmetic bounds")
	print("M05 balance: wins=%d/%d (%.1f%%), average reached floor=%.2f/12" %
		[wins, SEED_COUNT, float(wins) * 100.0 / SEED_COUNT, float(floor_total) / SEED_COUNT])
	print("M05 participation: stitches=%d sews=%d picks=%d skips=%d plays=%d enemy_phases=%d" %
		[stitches, sews, picks, skips, plays, phases])
	print("M05 Shop visits=%d paid card purchases=%d unaffordable rejections=%d" % [visits, purchases, unaffordable])
	print("M05 Events special=%s generic=%d unaffordable rejections=%d; no-effect Treasure=%d" %
		[JSON.stringify(specials), generic, event_unaffordable, treasures])
	print("M05 supported earned-pool coverage PARTIAL (other pool shapes deliberately unselected); acquired=%s accepted_plays=%d receipts=%s" % [
		JSON.stringify(acquired), earned_plays, JSON.stringify(earned_receipts)])
	print("M05 BAL win target 15-30/50 (30-60%%): %s (%d/50)" % [
		"PASS" if wins >= 15 and wins <= 30 else "FAIL", wins])
	if wins == 0:
		print("M05 literal no-card-over-half winning-deck gate: NOT_EVALUABLE (zero winners)")
		print("M05 mandatory starter / optional acquired frequency: NOT_EVALUABLE")
	else:
		var starter_frequencies := {}
		var optional_frequencies := {}
		var stitched_frequencies := {}
		var other_frequencies := {}
		var exceeds := false
		var ids: Array = frequencies.keys()
		ids.sort()
		for id in ids:
			_check(frequencies[id] <= wins, "per-card winning-deck denominator")
			if starter_ids.has(id):
				starter_frequencies[id] = frequencies[id]
			elif winning_acquired.has(id):
				optional_frequencies[id] = frequencies[id]
			elif str(id).begins_with(RunRestStitchCards.ID_PREFIX):
				stitched_frequencies[id] = frequencies[id]
			else:
				other_frequencies[id] = frequencies[id]
			if frequencies[id] * 2 > wins:
				exceeds = true
		print("M05 mandatory starter winning-deck presence (once/deck): %s / %d" % [
			JSON.stringify(starter_frequencies), wins])
		print("M05 optional acquired winning-deck presence (once/deck): %s / %d" % [
			JSON.stringify(optional_frequencies), wins])
		print("M05 derived stitched winning-deck presence (once/deck): %s / %d" % [
			JSON.stringify(stitched_frequencies), wins])
		_check(other_frequencies.is_empty(), "winning cards classified as starter, acquired or stitched")
		print("M05 literal no-card-over-half winning-deck gate: %s; fixed starter cards make this conflict unavoidable while retained in winning decks" % [
			"FAIL" if exceeds else "PASS"])
		print("M05 optional acquired-card over-half diagnostic: %s" % [
			"FAIL" if optional_frequencies.values().any(func(count): return count * 2 > wins) else "PASS"])
