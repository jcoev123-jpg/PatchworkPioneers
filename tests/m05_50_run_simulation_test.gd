extends SceneTree
## Fifty independent, real-service runs; no fixture kills or outcome injection.

const SEED_COUNT := 50
const TURN_CAP := 80
const ACTION_CAP := 16
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
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
			"every independently recreated seed has identical routes, floor, outcome, RNG, stitch/sew and deck")
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
	var no_effect_visits := 0
	var won := false
	var lost := false
	var action_total := 0
	var trace: Array[String] = []
	for floor_index in range(RunMap.FLOOR_COUNT):
		if carry.read_state().heroes.filter(func(h): return h.hp > 0).is_empty():
			return _fail("run continued without living party")
		var legal := map.get_legal_choices()
		var choice := strategy.choose_route(map, carry.read_state().heroes,
			scraps, stitches, fights, elites)
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
			if not attacks.bind_patch_wardrobe(wardrobe, carry.torn) 					or not support.bind_patch_wardrobe(wardrobe, carry.torn) 					or not stitched.bind_patch_wardrobe(wardrobe, carry.torn):
				return _fail("genuinely worn patch rules binding")
			attacks.start_player_turn()
			var terminal := ""
			for turn in range(TURN_CAP):
				var rejected_ids: Array = []
				for action_index in range(ACTION_CAP):
					action_total += 1
					var decision := strategy.choose_card(combat_deck, party, enemies,
						attacks, run_cards, rejected_ids)
					if decision.is_empty():
						break
					var before := _combat_snapshot(combat_deck, party, enemies, rng)
					var accepted := false
					match decision.kind:
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
					plays += 1
					if before[0] <= combat_deck.energy and decision.kind != "support":
						return _fail("paid combat did not charge energy")
					if combat_deck.discard_pile.count(decision.id) <= before[2].count(decision.id):
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
		else:
			# No unsupported Event/Treasure outcome or phantom Shop purchase.
			no_effect_visits += 1
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
		"battles": battles, "no_effect_visits": no_effect_visits,
		"gold": gold, "scraps": scraps, "actions": action_total}


func _combat_snapshot(deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, rng: RandomNumberGenerator) -> Array:
	return [deck.energy, deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.draw_pile.duplicate(), party.get_heroes(), enemies.get_enemies(), str(rng.state)]


func _report(trials: Array[Dictionary]) -> void:
	var wins := 0
	var floor_total := 0
	var stitches := 0
	var sews := 0
	var picks := 0
	var skips := 0
	var plays := 0
	var phases := 0
	var no_effect := 0
	var frequencies := {}
	for trial in trials:
		wins += 1 if trial.won else 0
		floor_total += trial.floor
		stitches += trial.stitches
		sews += trial.sews
		picks += trial.picks
		skips += trial.skips
		plays += trial.plays
		phases += trial.phases
		no_effect += trial.no_effect_visits
		_check(trial.route.size() == trial.floor and trial.floor >= 1 and trial.floor <= 12,
			"terminal route length equals actual reached floor")
		_check(trial.gold >= 0 and trial.scraps >= 0 and trial.actions <= 12 * TURN_CAP * ACTION_CAP,
			"wallet and finite action cap")
		if trial.won:
			var seen := {}
			for card_id in trial.deck:
				seen[card_id] = true
			for card_id in seen:
				frequencies[card_id] = frequencies.get(card_id, 0) + 1
	_check(plays > 0 and phases > 0 and picks > 0 and skips > 0,
		"nonzero genuine charged/discarded play, enemy phase, reward pick and skip")
	_check(stitches > 0 and sews > 0,
		"cohort must actually commit a Rest stitch and an owned patch sew")
	_check(wins >= 0 and wins <= SEED_COUNT and floor_total >= SEED_COUNT,
		"aggregate arithmetic bounds")
	print("M05 balance: wins=%d/%d (%.1f%%), average reached floor=%.2f/12" %
		[wins, SEED_COUNT, float(wins) * 100.0 / SEED_COUNT, float(floor_total) / SEED_COUNT])
	print("M05 participation: stitches=%d sews=%d picks=%d skips=%d plays=%d enemy_phases=%d" %
		[stitches, sews, picks, skips, plays, phases])
	print("M05 no-effect Shop/Event/Treasure traversals=%d; generic events and unpurchased stock not simulated" %
		no_effect)
	if wins == 0:
		print("M05 winning-deck card frequency: n/a (no winning decks)")
	else:
		print("M05 winning-deck card frequency (%d winning decks, presence counted once/deck):" % wins)
		var ids: Array = frequencies.keys()
		ids.sort()
		for id in ids:
			_check(frequencies[id] <= wins, "per-card winning-deck denominator")
			print("  %s: %d/%d (%.1f%%)" % [
				id, frequencies[id], wins, float(frequencies[id]) * 100.0 / wins])
