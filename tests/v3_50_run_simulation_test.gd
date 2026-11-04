extends "res://tests/m05_50_run_simulation_test.gd"
## First mixed-party V3 cohort. Reuses the genuine M05 run, never its admission
## fixture or historical balance target. No seed is searched/replaced for wins.

func _initialize() -> void:
	_test_v3_refusals()
	_test_carry_tokens()
	var first: Array[Dictionary] = []
	var parties := {}
	var heroes := {}
	for value in range(1, SEED_COUNT + 1):
		var trial := _run_seed(value)
		_check(trial.get("ok", false), "V3 seed %d: %s" % [value, trial.get("error", "")])
		if not trial.get("ok", false):
			continue
		first.append(trial)
		var admission: Dictionary = trial.admission
		var ids: Array = admission.hero_ids.duplicate()
		ids.sort()
		parties[JSON.stringify(ids)] = true
		_check(admission == RunV3PartyAdmission.admit(admission.hero_ids), "canonical HP/order/deck receipt")
		_check(admission.party.size() == 3 and admission.deck.size() == 12, "three heroes and twelve canonical starters")
		for id in admission.hero_ids:
			heroes[id] = heroes.get(id, 0) + 1
		_check(trial.won != trial.lost and trial.floor >= 1 and trial.floor <= 12,
			"exactly one authentic terminal result at reached floor")
		_check(not trial.won or trial.floor == 12, "victory requires actual floor-12 Boss")
		var replay := _run_seed(value)
		_check(replay.get("ok", false) and replay == trial,
			"full seed replay: admission/routes/payments/effects/rewards/events/stops/patch/stitch/RNG/outcome")
		print("V3 seed=%d party=%s outcome=%s floor=%d route=%s RNG=%s replay=%s" % [value,
			JSON.stringify(admission.hero_ids), "VICTORY" if trial.won else "DEFEAT", trial.floor,
			JSON.stringify(trial.route), trial.rng, "PASS" if replay == trial else "FAIL"])
	_check(first.size() == SEED_COUNT and parties.size() == SEED_COUNT, "fifty distinct seeded three-hero admissions")
	for id in RunV3PartyAdmission.HERO_IDS:
		_check(heroes.get(id, 0) > 0, "non-vacuous cohort membership " + id)
	if first.size() == SEED_COUNT:
		_report_v3(first, heroes)
	print("v3_50_run_simulation_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _admit_run(value: int, rng: RandomNumberGenerator) -> Dictionary:
	var combinations: Array[Array] = []
	var ids := RunV3PartyAdmission.HERO_IDS
	for a in range(ids.size()):
		for b in range(a + 1, ids.size()):
			for c in range(b + 1, ids.size()):
				combinations.append([ids[a], ids[b], ids[c]])
	# Coprime stride traverses the 56 combinations without replacement. The
	# same run RNG chooses pick order (including default-seat ties) before map.
	var picks: Array = combinations[((value - 1) * 17) % combinations.size()].duplicate()
	for index in range(picks.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap: String = picks[index]
		picks[index] = picks[other]
		picks[other] = swap
	return RunV3PartyAdmission.admit(picks)


func _choose_extra(strategy: M05SeededRunStrategy, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, rejected: Array) -> Dictionary:
	var decision := strategy.choose_v3_card(deck, party, enemies, rejected)
	# As in M05, cease defensive cycling when no supported damage line remains.
	if not decision.is_empty() and decision.service in ["party_heal", "shelter", "knit", "sew", "dodge", "fear", "feint"] \
			and not _has_damage_line(deck.draw_pile + deck.hand + deck.discard_pile, {},
				party.get_heroes(), enemies.get_enemies()):
		return {}
	return decision


func _play_extra(deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, decision: Dictionary) -> Dictionary:
	# Authenticate the dispatch key too: callers cannot route an unsupported ID
	# through an unrelated service, even when its printed descriptor looks alike.
	if M05SeededRunStrategy.V3_SERVICES.get(decision.get("id")) != decision.get("service"):
		return {"ok": false}
	var id: String = decision.id
	var target: int = decision.target
	match decision.service:
		"party_heal":
			var selections := {}
			for hero in party.get_heroes():
				if hero.hp > 0:
					var debuff := _cleanse(hero)
					if not debuff.is_empty(): selections[hero.position] = debuff
			return CombatLanternMonkPartyCards.new().play_card(deck, party, id, target, selections)
		"shelter": return CombatLanternMonkPoleShelterCards.new().play_card(deck, party, id, target, _cleanse(party.get_hero(target)))
		"lunge": return CombatRagDuelistLungeCards.new().play_card(deck, party, enemies, id, target)
		"riposte": return CombatRagDuelistRiposteCards.new().play_card(deck, party, id)
		"feint": return CombatRagDuelistFeintCards.new().play_card(deck, party, enemies, id, target)
		"dodge": return CombatRagDuelistDodgeCards.new().play_card(deck, party, id, target)
		"fork": return CombatScarecrowPitchforkCards.new().play_card(deck, party, enemies, id, target)
		"fear": return CombatScarecrowFearCards.new().play_card(deck, party, enemies, id, target)
		"crow": return CombatScarecrowCrowCards.new().play_card(deck, party, enemies, id, target)
		"bolas": return CombatYarnRangerBolasCards.new().play_card(deck, party, enemies, id, target)
		"knit": return CombatYarnRangerKnitCards.new().play_card(deck, party, id, target)
		"pop": return CombatButtonGolemPopCards.new().play_card(deck, party, enemies, id, target)
		"roll": return CombatButtonGolemRollCards.new().play_card(deck, party, id, target)
		"sew": return CombatButtonGolemSewCards.new().play_card(deck, party, id, target)
	return {"ok": false}


func _cleanse(hero: Dictionary) -> String:
	for key in ["bleed", "weak", "exposed"]:
		if hero.get("statuses", {}).get(key, 0) > 0:
			return key
	return ""


func _has_damage_line(deck_ids: Array, descriptors: Dictionary, heroes: Array, enemies: Array) -> bool:
	var supported: Array = deck_ids.filter(func(id): return not StarterCards.new().get_definition(id).is_empty() \
		or descriptors.has(id) or M05SeededRunStrategy.V3_SERVICES.has(id))
	return super._has_damage_line(supported, descriptors, heroes, enemies)


func _test_v3_refusals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 348
	var admission := RunV3PartyAdmission.admit(["lantern_monk", "yarn_ranger", "button_golem"])
	_check(admission.ok, "negative fixtures use real chosen-owner admission")
	var party := CombatParty.new(admission.party)
	var deck := CombatDeck.new(admission.deck, rng)
	var enemies := CombatEnemies.new([{"id": "target", "max_hp": 20}])
	_check(deck.start_turn(), "negative fixture active real hand")
	var strategy := M05SeededRunStrategy.new()
	for id in ["unknown", "lantern_monk_wick_spark", "yarn_ranger_needle_nock", "button_golem_starter_button_fist", "scarecrow_fork_jab"]:
		var before := _combat_snapshot(deck, party, enemies, rng)
		var receipt := _play_extra(deck, party, enemies, {"id": id, "target": 1, "service": "fork"})
		_check(not receipt.get("ok", true) and before == _combat_snapshot(deck, party, enemies, rng),
			"unsupported/spoofed/missing-owner play never succeeds or spends " + id)
	_check(deck.try_spend_energy(deck.energy), "negative fixture spends actual turn energy")
	var before := _combat_snapshot(deck, party, enemies, rng)
	_check(strategy.choose_v3_card(deck, party, enemies, []).is_empty(), "no unaffordable V3 decision")
	_check(before == _combat_snapshot(deck, party, enemies, rng), "selection never mutates combat/RNG")
	# A real held, affordable card proves the positive resolver and its exact
	# payment, then the same card exercises each refusal from genuine state.
	for condition in ["legal", "spent", "no_energy", "downed", "wrong_slot", "wrong_target", "rejected"]:
		var selected := RunV3PartyAdmission.admit(["warden", "button_golem", "yarn_ranger"])
		var actors := CombatParty.new(selected.party)
		var held := CombatDeck.new(["yarn_ranger_wool_bolas"], rng)
		var foes := CombatEnemies.new([{"id": "target", "max_hp": 20}])
		_check(held.start_turn() and held.hand.has("yarn_ranger_wool_bolas") and actors.get_hero(3).id == "yarn_ranger",
			"real held V3 refusal prerequisites " + condition)
		if condition == "no_energy": _check(held.try_spend_energy(3), "real no-energy boundary")
		if condition == "downed": _check(actors.apply_damage(3, 100), "real downed owner")
		if condition == "wrong_slot":
			actors = CombatParty.new([selected.party[2], selected.party[1], selected.party[0]])
			_check(actors.get_hero(1).id == "yarn_ranger", "real wrong FROM lineup")
		var source := _combat_snapshot(held, actors, foes, rng)
		var candidate := strategy.choose_v3_card(held, actors, foes,
			["yarn_ranger_wool_bolas"] if condition == "rejected" else [])
		_check(source == _combat_snapshot(held, actors, foes, rng), "read-only V3 selection " + condition)
		if condition in ["no_energy", "downed", "wrong_slot", "rejected"]:
			_check(candidate.is_empty(), "V3 selection refuses " + condition)
		if condition == "rejected": continue
		var result := _play_extra(held, actors, foes, {"id": "yarn_ranger_wool_bolas", "service": "bolas",
			"target": 2 if condition == "wrong_target" else 1})
		if condition in ["legal", "spent"]:
			_check(result.get("ok", false) and held.energy == 2 and held.hand.is_empty()
				and held.discard_pile == ["yarn_ranger_wool_bolas"] and foes.get_enemy(1).hp == 18
				and foes.get_enemy(1).statuses.tangled == 1 and str(rng.state) == source[6], "authentic V3 hit/payment/discard/status/RNG")
			var committed := _combat_snapshot(held, actors, foes, rng)
			_check(not _play_extra(held, actors, foes, {"id": "yarn_ranger_wool_bolas", "service": "bolas", "target": 1}).ok
				and committed == _combat_snapshot(held, actors, foes, rng), "spent V3 play cannot replay")
		else:
			_check(not result.get("ok", true) and source == _combat_snapshot(held, actors, foes, rng), "exact no-mutation V3 refusal " + condition)


func _test_carry_tokens() -> void:
	var admitted := RunV3PartyAdmission.admit(["warden", "rag_duelist", "lantern_monk"])
	_check(admitted.ok, "carry token fixture has canonical mixed-party admission")
	var heroes := CombatParty.new(admitted.party).get_heroes()
	for statuses in [{"riposte": 2}, {"dodge_next_attack": 1}, {"blind_next_attack": 1},
		{"tangled": 1}, {"riposte": -1}, {"dodge_next_attack": 2}, {"riposte": 1.0}, {"unknown": 1}]:
		var ending := heroes.duplicate(true)
		ending[0]["statuses"] = statuses.duplicate(true)
		var original := ending.duplicate(true)
		var valid: bool = statuses in [{"riposte": 2}, {"dodge_next_attack": 1}, {"blind_next_attack": 1}, {"tangled": 1}]
		# Variant equality coalesces int/float; validity must keep types exact.
		if statuses.get("riposte") is float: valid = false
		var carry := RunPartyCarryover.new(ending)
		_check(carry.is_valid() == valid and ending == original, "carry token type/shape admission " + str(statuses))
		var torn := RunTornMending.new(heroes)
		var before := torn.read_state()
		var receipt := torn.observe_battle_end("tokens", heroes, ending)
		_check(receipt.ok == valid and ending == original, "Torn observation uses actual combat token vocabulary " + str(statuses))
		var wardrobe := RunPatchWardrobe.new(ending, [], RunAuthoredPatchDefinitions.load_definitions(), 0, 0, admitted.deck, 348, true)
		_check(wardrobe.is_valid() == valid, "wardrobe retains exact combat-token validation " + str(statuses))
		if valid:
			var source := torn.read_state()
			_check(CombatPatchAttackRules.new().bind_wardrobe(wardrobe, torn)
				and CombatM05HeadPatchRules.new().bind_wardrobe(wardrobe, torn)
				and CombatShopPatchRules.new().bind_wardrobe(wardrobe, torn), "mixed-owner patch bindings accept real combat tokens")
			var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m04_coat_patches.json"))
			var projected := RunPatchCoatRules.project_health(source, wardrobe, coats)
			_check(projected.ok and projected.heroes == ending and torn.read_state() == source,
				"coat projection accepts tokens without ticking or mutating them")
		if not valid:
			_check(torn.read_state() == before, "malformed token observation is atomic")


func _report_v3(trials: Array[Dictionary], heroes: Dictionary) -> void:
	var wins := 0
	var losses := {}
	var mandatory := {}
	var optional := {}
	var derived := {}
	var unsupported := {}
	var plays := {}
	var rewards := 0
	var stitches := 0
	var sews := 0
	var events := 0
	var total_floors := 0
	for trial in trials:
		total_floors += trial.floor
		wins += 1 if trial.won else 0
		if trial.lost:
			losses[trial.floor] = losses.get(trial.floor, 0) + 1
		for id in trial.admission.deck:
			if StarterCards.new().get_definition(id).is_empty() and not M05SeededRunStrategy.V3_SERVICES.has(id):
				unsupported[id] = true
		for event in trial.extra_plays:
			var id: String = event.decision.id
			plays[id] = plays.get(id, 0) + 1
		rewards += trial.reward_visits.size()
		stitches += trial.stitches
		sews += trial.sews
		events += trial.event_visits.size()
		if trial.won:
			var seen := {}
			for id in trial.deck:
				if seen.has(id): continue
				seen[id] = true
				if trial.descriptors.has(id):
					var descriptor: Dictionary = trial.descriptors[id]
					var pair: String = descriptor.first_half.id + " / " + descriptor.second_half.id
					if not seen.has(pair):
						derived[pair] = derived.get(pair, 0) + 1
						seen[pair] = true
				else:
					var counts: Dictionary = mandatory if trial.admission.deck.has(id) else optional
					counts[id] = counts.get(id, 0) + 1
	_check(rewards > 0 and events > 0 and sews > 0 and stitches > 0 and not plays.is_empty(),
		"non-vacuous real reward/event/patch/stitch/V3 play receipts across cohort")
	print("V3 seeds: 1-50; hero admissions: ", JSON.stringify(heroes))
	print("V3 actual wins: %d/50; losses by actual floor: %s" % [wins, JSON.stringify(losses)])
	print("V3 average reached floor: %.2f" % (float(total_floors) / trials.size()))
	var numeric_gate := wins >= 10 and wins <= 22
	var spread := losses.size() > 1 and losses.keys().any(func(floor_number): return floor_number < 12)
	print("V3 observed 10-22 numeric diagnostic: %s; loss spread: %s" % ["PASS" if numeric_gate else "FAIL", "PASS" if spread else "FAIL"])
	_check(numeric_gate and spread, "V3 BAL 10-22/50 wins and genuine early multi-floor losses in 2-3-foe routed fights")
	print("V3 mandatory starter winning-deck presence once/deck / %d: %s" % [wins, JSON.stringify(mandatory)])
	print("V3 optional acquired winning-deck presence once/deck / %d: %s" % [wins, JSON.stringify(optional)])
	print("V3 derived stitched winning-deck presence by actual halves once/deck / %d: %s" % [wins, JSON.stringify(derived)])
	print("V3 literal no-card-over-half rule: unresolved; ", "NOT_EVALUABLE" if wins == 0 else ("FAIL" if (mandatory.values() + optional.values() + derived.values()).any(func(n): return n * 2 > wins) else "PASS"))
	print("V3 unsupported starter IDs (never successful): ", JSON.stringify(unsupported.keys()))
	print("V3 real extra plays: ", JSON.stringify(plays))
	print("V3 receipt coverage: rewards=%d events=%d sewn=%d stitched=%d" % [rewards, events, sews, stitches])
