extends SceneTree
## The forecast is compared with two independent real CombatStitchedCards plays.
## All fixtures are Rest-crafted from shipped cards and shipped starter rosters.

const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const BOMB := "tinker_scrap_bomb"
const BRACE := "warden_brace"
const MEND := "seamstress_mend"
const TUNE := "tinker_tune_up"

var checks := 0
var failures: Array[String] = []
var forecast := CombatStitchedEffectForecast.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_warden_block_forecasts()
	_test_separate_targets()
	_test_late_failure_and_retry()
	_test_patches_and_both_orders()
	_test_support_and_area()
	_test_draw_and_seeded_replay()
	_test_rejections()
	_test_real_torn_and_mend()
	_test_pool_heal_forecasts()
	_test_pool_self_forecasts()
	_test_four_foe_forecast()
	_test_borrowed_button_stitched_parity()
	_test_borrowed_button_spent_latch()
	_test_borrowed_button_negatives()
	await _test_mounted_warden_blocks()
	await _test_mounted_pool_self()
	for failure in failures:
		printerr(failure)
	print("combat_stitched_effect_forecast_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Real app, metadata, target preview, forecast and deferred commit callbacks.
## Only the earned-card setup is supplied here; every battle model stays live.
func _test_mounted_warden_blocks() -> void:
	root.size = Vector2i(1280, 720)
	for id in CombatStitchedTargetPreview.WARDEN_BLOCK_IDS:
		for reverse in [false, true]:
			var app = load("res://scenes/app.tscn").instantiate()
			root.add_child(app)
			await process_frame
			_check(app._start_battle(), "real app mounts active battle for Warden stitch")
			var rest := RunRestStitchCards.new([POP if reverse else id, id if reverse else POP], {}, 3)
			var made := rest.choose_stitch(0, 1, rest.get_snapshot())
			_check(made.ok and rest.is_consumed(), "mounted hand uses genuine cross-owner Rest receipt")
			app.run_deck.assign(made.deck)
			app.run_stitch_descriptors = made.descriptors.duplicate(true)
			app.run_scraps = made.remaining_scraps
			app.run_next_stitch_id = made.next_stitch_id
			app.deck.hand.assign(made.deck)
			app.deck.draw_pile.clear()
			app.deck.discard_pile.clear()
			app._refresh_hand()
			await process_frame
			await process_frame
			var presenter = app.get_node("LiveAttackPreview")
			var panel: Control = null
			for child in app.hand_view.get_children():
				if child.get_child(0).text == made.stitched_id:
					panel = child
			_check(panel != null and presenter._bindings.has(panel), "real held composite has a bound gameplay panel")
			var admission: Dictionary = presenter._stitch_preview(made.stitched_id)
			_check(admission.get("playable", false) and admission.halves.size() == 2, "production live preview admits canonical Warden pool half")
			if panel != null and admission.get("playable", false):
				if reverse:
					# Run authorities precede battle-opening Block (Vanguard).
					var bound := {"party": CombatParty.new(_authored("res://data/heroes/starter_party.json")),
						"service": CombatStitchedCards.new()}
					_bind_warden_blocks(bound)
					_check(app.get_node("LiveSupportHand")._heal_cards.bind_patch_wardrobe(
						bound.wardrobe, bound.torn), "mounted support authority carries genuine stacked Warden patches")
				var metadata = app.get_node("LiveSupportHand")._metadata
				_check(metadata.get_facts(panel).get("halves", []) == made.descriptor.half_ids,
					"mounted metadata preserves genuine ordered halves")
				var before := [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.energy,
					app.deck.hand.duplicate(), app.deck.discard_pile.duplicate(), app.run_rng.state]
				presenter._armed = panel
				presenter._selected = panel
				presenter._arm_stitch()
				presenter._choose_stitch(1, "enemy")
				var projected: Dictionary = presenter.current_forecast.duplicate(true)
				_check(projected.get("playable", false), "real chosen-target cue has complete forecast")
				_check(before == [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.energy,
					app.deck.hand, app.deck.discard_pile, app.run_rng.state], "live forecast spends nothing before deferred commit")
				await process_frame
				await process_frame
				_check(presenter.last_event.get("ok", false), "real deferred stitched commit succeeds")
				if projected.get("playable", false):
					_check(projected.projected.heroes == app.party.get_heroes()
						and projected.projected.enemies == app.enemies.get_enemies()
						and projected.projected.energy == app.deck.energy
						and projected.projected.discard_pile == app.deck.discard_pile
						and projected.projected.rng_state == app.run_rng.state, "mounted forecast exactly equals published battle state")
				for hero in app.party.get_heroes():
					var expected: int = (13 if id.ends_with("_plus") else 10) if id.begins_with("warden_bastion") else ((7 if id.ends_with("_plus") else 5) if hero.id == "warden" else (3 if id.ends_with("_plus") else 2))
					if reverse and id.begins_with("warden_hold") and hero.id == "warden":
						expected += 4
					_check(hero.block == before[0][hero.position - 1].block + expected, "mounted commit grants every authored Block recipient")
			app.queue_free()
			await process_frame


func _test_mounted_pool_self() -> void:
	for id in CombatPoolEnergyCards.SUPPORTED_IDS + CombatStitchedCards.SPARE_PARTS_IDS:
		for reverse in [false, true]:
			var app = load("res://scenes/app.tscn").instantiate()
			root.add_child(app)
			await process_frame
			_check(app._start_battle(), "mounted self stitch active battle")
			var rest := RunRestStitchCards.new([BRACE if reverse else id, id if reverse else BRACE], {}, 3)
			var made := rest.choose_stitch(0, 1, rest.get_snapshot())
			_check(made.ok and rest.is_consumed(), "mounted self stitch genuine receipt")
			app.run_deck.assign(made.deck)
			app.run_stitch_descriptors = made.descriptors.duplicate(true)
			app.run_scraps = made.remaining_scraps
			app.run_next_stitch_id = made.next_stitch_id
			app.deck.hand.assign(made.deck)
			app.deck.draw_pile.assign([POP, PRICK, MEND, TUNE])
			app.deck.discard_pile.clear()
			app._refresh_hand()
			await process_frame
			await process_frame
			var presenter = app.get_node("LiveAttackPreview")
			var panel: Control = null
			for child in app.hand_view.get_children():
				if child.get_child(0).text == made.stitched_id:
					panel = child
			_check(panel != null and presenter._bindings.has(panel), "new self stitch bound to real hand")
			var admission: Dictionary = presenter._stitch_preview(made.stitched_id)
			_check(admission.get("playable", false), "mounted gate admits " + id)
			if panel != null and admission.get("playable", false):
				var before := [app.party.get_heroes(), app.deck.energy, app.deck.hand.duplicate(), app.run_rng.state]
				presenter._armed = panel
				presenter._selected = panel
				presenter._arm_stitch()
				_check(presenter._choices == [0, 0], "mounted halves automatically choose target zero")
				presenter._choose_stitch(0)
				var projected: Dictionary = presenter.current_forecast.duplicate(true)
				_check(projected.get("playable", false) and before == [app.party.get_heroes(), app.deck.energy, app.deck.hand, app.run_rng.state],
					"mounted complete forecast spends nothing")
				await process_frame
				await process_frame
				_check(presenter.last_event.get("ok", false), "mounted deferred self stitch commits")
				if projected.get("playable", false):
					_check(projected.projected.heroes == app.party.get_heroes() and projected.projected.energy == app.deck.energy
						and projected.projected.hand == app.deck.hand and projected.projected.discard_pile == app.deck.discard_pile
						and projected.projected.rng_state == app.run_rng.state, "mounted self effects equal forecast")
			app.queue_free()
			await process_frame


func _test_pool_self_forecasts() -> void:
	for id in CombatPoolEnergyCards.SUPPORTED_IDS + CombatStitchedCards.SPARE_PARTS_IDS:
		var overclock: bool = id in CombatPoolEnergyCards.OVERCLOCK_IDS
		var trance: bool = id in CombatPoolEnergyCards.TRANCE_IDS
		var draws: int = (3 if id.ends_with("_plus") else 2) if trance else (0 if overclock else 1)
		for reverse in [false, true]:
			for seed_value in [0, 101, 9527]:
				var outcomes: Array = []
				for replay in range(2):
					var c := _fixture(BRACE if reverse else id, id if reverse else BRACE, seed_value)
					c.deck.discard_pile.assign([POP, PRICK, MEND, TUNE])
					var before := _state(c)
					# Independent Fisher-Yates and draw oracle, including exact RNG state.
					var oracle := RandomNumberGenerator.new()
					oracle.seed = c.deck._rng.seed
					oracle.state = c.deck._rng.state
					var pile: Array = before.discard_pile.duplicate()
					var expected_hand: Array = []
					if draws > 0:
						for index in range(pile.size() - 1, 0, -1):
							var other := oracle.randi_range(0, index)
							var saved: String = pile[index]
							pile[index] = pile[other]
							pile[other] = saved
						for index in range(draws):
							expected_hand.append(pile.pop_back())
					var result := _compare(c, 0, 0, id + ": self forecast both orders")
					if not result.playable:
						continue
					_check(result.cost == 2 and result.projected.energy == (2 if overclock or trance else 1),
						"one composite charge plus authored energy gain")
					_check(result.projected.heroes[0].block == 7
						and result.projected.heroes[2].hp == (23 if overclock else 26)
						and result.projected.heroes[2].block == (0 if overclock or trance else (4 if id.ends_with("_plus") else 3)),
						"exact Brace, owner self-damage and Spare Parts Block")
					_check(result.projected.hand == expected_hand and result.projected.rng_state == oracle.state
						and result.projected.draw_pile == (pile if draws > 0 else [])
						and result.projected.discard_pile == ([c.id] if draws > 0 else [POP, PRICK, MEND, TUNE, c.id]),
						"exact authored draw, seeded shuffle and single composite discard")
					outcomes.append(result)
				_check(outcomes.size() == 2 and outcomes[0] == outcomes[1], "nonvacuous independent seeded replay")
			var bad := _fixture(BRACE if reverse else id, id if reverse else BRACE)
			_reject(bad, 1 if not reverse else 0, 1 if reverse else 0, "nonzero self target")
			var before_bad := _whole(bad)
			_check(not _real(bad, 1 if not reverse else 0, 1 if reverse else 0).ok and _whole(bad) == before_bad,
				"bad target commit also atomic")
			_check(bad.deck.try_spend_energy(2), "authentic insufficient composite payment")
			_reject(bad, 0, 0, "insufficient energy despite printed gain")
			before_bad = _whole(bad)
			_check(not _real(bad, 0, 0).ok and _whole(bad) == before_bad, "unaffordable commit atomic")
		var late := _fixture(id, BRACE)
		late.deck.discard_pile.assign([POP, PRICK, MEND, TUNE])
		_check(late.party.gain_block(1, CombatParty.MAX_INT), "real second-half Brace overflow")
		_reject(late, 0, 0, "rollback earlier energy/damage/Block/draw and shuffle")
		var before_late := _whole(late)
		_check(not _real(late, 0, 0).ok and _whole(late) == before_late, "real late overflow rolls back all authorities")


## AC2: on an opted-in four-foe roster the detached forecast must equal the real
## committed energy, HP/Block/status, hand, enemy and RNG results, must never
## mutate the source, and must reproduce exactly from the same seed. AC3: every
## unauthored target, unsweepable area half and unopted roster fails closed with
## the same no-spend result in the matching real commit.
func _test_four_foe_forecast() -> void:
	for seed_value in [0, 42401]:
		for reverse in [false, true]:
			var outcomes: Array = []
			for attempt in range(2):
				var c := _fixture(POP if reverse else PRICK, PRICK if reverse else POP, seed_value)
				c.enemies = _four_foes()
				var foes_before: Array = c.enemies.get_enemies()
				var label := "four-foe forecast seed %d order %s" % [seed_value, str(reverse)]
				var result := _compare(c, 2 if reverse else 1, 1 if reverse else 2, label)
				_check(result.get("playable", false), label + ": real two-half play is forecast")
				if result.get("playable", false):
					var projected: Dictionary = result.projected
					_check(result.cost == 2 and projected.energy == 1
						and projected.discard_pile == [c.id] and projected.hand.is_empty(),
						label + ": one capped payment and exactly one discard")
					var projected_foes: Array = projected.enemies
					_check(projected_foes.size() == 4
						and projected_foes[3].position == 4
						and projected_foes[2].hp == foes_before[2].hp
						and projected_foes[3].hp == foes_before[3].hp,
						label + ": all four enemy slots projected, untargeted slots untouched")
					_check(projected.heroes == c.party.get_heroes()
						and projected.rng_state == c.deck._rng.state,
						label + ": committed party and RNG equal the projection")
				outcomes.append(result)
			_check(outcomes.size() == 2 and outcomes[0].get("playable", false)
				and outcomes[0] == outcomes[1],
				"repeated seeds reproduce the exact four-foe receipt")

	# Unauthored targets and a failed second half refuse without any spend.
	var c := _fixture(PRICK, POP)
	c.enemies = _four_foes()
	_reject(c, 4, 0, "four-foe forecast refuses an unauthored first target")
	_reject(c, 1, 4, "four-foe forecast refuses an unauthored second target")
	_reject(c, 1, 0, "four-foe forecast refuses a missing second target")
	var before := _whole(c)
	_check(_real(c, 1, 4) == {"ok": false, "halves": []} and _whole(c) == before,
		"the matching real commit refuses the same play without spending")

	# A starter area half cannot sweep a living slot outside its authored TO
	# positions; once that foe dies the forecast and the commit agree again.
	var area := _fixture(PRICK, BOMB, 42406)
	area.enemies = _four_foes()
	_reject(area, 1, 0, "four-foe forecast refuses an unsweepable starter area half")
	var area_before := _whole(area)
	_check(_real(area, 1, 0) == {"ok": false, "halves": []} and _whole(area) == area_before,
		"the same area refusal publishes no Block, damage, spend or latch")
	_check(area.enemies.apply_damage(4, 999) and area.enemies.apply_damage(4, 999)
		and area.enemies.is_slain(4),
		"fourth foe genuinely slain (its one authored revival spent)")
	var allowed := _compare(area, 1, 0, "four-foe area forecast after the fourth foe dies")
	_check(allowed.get("playable", false)
		and (allowed.projected.enemies as Array).size() == 4
		and area.enemies.is_slain(4),
		"area half forecasts and commits once only its authored slots stay alive")

	# An unopted four-record roster at the default capacity fails closed.
	var unopted := _fixture(PRICK, POP, 42403)
	unopted.enemies = _unopted_four_foes()
	_check(not unopted.enemies.is_valid() and unopted.enemies.get_enemies().size() == 4,
		"unopted fixture really holds four records at the default three capacity")
	_reject(unopted, 1, 2, "unopted four-slot roster refuses the forecast")
	var unopted_before := _whole(unopted)
	_check(_real(unopted, 1, 2) == {"ok": false, "halves": []} and _whole(unopted) == unopted_before,
		"the unopted roster refuses the real commit with no state change")
	_check(unopted.enemies.get_enemies().size() == 4,
		"unopted refusal never compacts or drops the fourth record")


func _test_warden_block_forecasts() -> void:
	for id in CombatStitchedTargetPreview.WARDEN_BLOCK_IDS:
		for reverse in [false, true]:
			var c := _fixture(POP if reverse else id, id if reverse else POP, 262)
			var result := _compare(c, 1 if reverse else 0, 0 if reverse else 1, "Warden full Block forecast " + id)
			if result.playable:
				for hero in result.projected.heroes:
					var expected: int = (13 if id.ends_with("_plus") else 10) if id.begins_with("warden_bastion") else ((7 if id.ends_with("_plus") else 5) if hero.id == "warden" else (3 if id.ends_with("_plus") else 2))
					_check(hero.block == expected, "forecast preserves complete authored Block effects")
		var c := _fixture(POP, id)
		_check(c.party.gain_block(2, CombatParty.MAX_INT), "forecast later-half overflow exists")
		_reject(c, 1, 0, "Warden overflow forecast discards earlier attack/latch")
		var before := _whole(c)
		_check(not _real(c, 1, 0).ok and _whole(c) == before, "real overflow matches forecast rollback")
		c = _fixture(id, POP)
		_check(c.party.apply_damage(2, 999), "forecast recipient downed")
		var living := _compare(c, 0, 1, "Warden skips downed forecast")
		_check(living.playable and living.projected.heroes[1].block == 0, "downed Block remains zero")
		for reverse in [false, true]:
			c = _fixture(POP if reverse else id, id if reverse else POP)
			_bind_warden_blocks(c)
			var patched := _compare(c, 1 if reverse else 0, 0 if reverse else 1, "stacked Warden patches forecast")
			var expected: int = (13 if id.ends_with("_plus") else 10) if id.begins_with("warden_bastion") else (11 if id.ends_with("_plus") else 9)
			_check(patched.playable and patched.projected.heroes[0].block == expected, "ARM and HEAD add four only to authored self Block")
		c = _fixture(id, POP)
		_bind_warden_blocks(c)
		_check(c.wardrobe.start_rest("forecast-stale", c.wardrobe.get_snapshot()).ok, "forecast has genuinely changed wardrobe after binding")
		_reject(c, 0, 1, "stale Warden patches refuse forecast")
		var stale_before := _whole(c)
		_check(not _real(c, 0, 1).ok and _whole(c) == stale_before, "stale Warden commit matches no-spend forecast refusal")


func _bind_warden_blocks(c: Dictionary) -> void:
	c.torn = RunTornMending.new(c.party.get_heroes())
	c.wardrobe = RunPatchWardrobe.new(c.party.get_heroes(),
		["hemguard_cuff", "reinforced_browband"],
		[{"id": "hemguard_cuff", "slot": "ARM"}, {"id": "reinforced_browband", "slot": "HEAD"}], 5)
	_check(c.torn.is_valid() and c.wardrobe.is_valid(), "valid Warden patch authorities")
	for patch in [{"id": "hemguard_cuff", "slot": "ARM"}, {"id": "reinforced_browband", "slot": "HEAD"}]:
		_check(c.wardrobe.sew(patch.id, "warden", patch.slot, "forecast-" + patch.id,
			c.wardrobe.get_snapshot()).ok, "genuine sewn Warden Block patch")
	_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn), "forecast uses real bound Block patches")


func _check(yes: bool, message: String) -> void:
	checks += 1
	if not yes:
		failures.append(message)


func _authored(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Array and not parsed.is_empty(), "real authored resource " + path)
	if not parsed is Array:
		return []
	for entry in parsed:
		_check(entry is Dictionary and entry.get("max_hp") is float
			and entry["max_hp"] == floor(entry["max_hp"]), "integral starter HP")
		entry["max_hp"] = int(entry["max_hp"])
	return parsed


## The four explicitly admitted authored foes (two shipped starter enemies and the
## two shipped tough normals), selected by ID under the existing literal opt-in.
func _four_foes() -> CombatEnemies:
	var catalog := _authored("res://data/enemies/starter_enemies.json")
	catalog.append_array(_authored("res://data/enemies/v3_tough_normals.json"))
	var selected: Array = []
	for required in ["ragling", "ragling_guard", "spindle_ram", "razor_ribbon_wraith"]:
		var matches: Array = catalog.filter(func(entry): return entry is Dictionary and entry.get("id") == required)
		_check(matches.size() == 1, "authored four-foe source present exactly once: " + required)
		if matches.size() == 1:
			selected.append(matches[0])
	var enemies := CombatEnemies.new(selected, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.is_valid() and enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
		and enemies.get_enemies().size() == 4
		and enemies.get_enemies().map(func(foe): return foe.get("position")) == [1, 2, 3, 4],
		"explicit opt-in roster really holds four authored occupied slots")
	return enemies


## The same four authored records forced into the DEFAULT three-slot capacity.
func _unopted_four_foes() -> CombatEnemies:
	var catalog := _authored("res://data/enemies/starter_enemies.json")
	catalog.append_array(_authored("res://data/enemies/v3_tough_normals.json"))
	var records: Array = []
	for required in ["ragling", "ragling_guard", "spindle_ram", "razor_ribbon_wraith"]:
		var matches: Array = catalog.filter(func(entry): return entry is Dictionary and entry.get("id") == required)
		if matches.size() == 1:
			records.append(matches[0])
	var enemies := CombatEnemies.new(records.slice(0, 3))
	_check(enemies.is_valid() and enemies.get_capacity() == CombatEnemies.MAX_ENEMIES,
		"default three-capacity roster is valid before a fourth record appears")
	var roster: Array[Dictionary] = []
	for index in range(records.size()):
		var foe: Dictionary = records[index].duplicate(true)
		foe["position"] = index + 1
		foe["hp"] = foe["max_hp"]
		foe["block"] = 0
		roster.append(foe)
	enemies._enemies = roster
	return enemies


func _fixture(first: String, second: String, seed_value: int = 9527) -> Dictionary:
	var catalogue := StarterCards.new()
	var a := RunRestStitchCards.resolve_card_definition(first)
	var b := RunRestStitchCards.resolve_card_definition(second)
	_check(not a.is_empty() and not b.is_empty() and a.owner != b.owner,
		"two genuine cross-owner half definitions")
	var starter_cards: Array[String] = [first, second, "warden_strike"]
	var rest := RunRestStitchCards.new(starter_cards, {}, 3)
	_check(rest.is_valid(), "valid Rest seed ledger")
	var choice := rest.choose_stitch(0, 1, rest.get_snapshot())
	_check(choice.get("ok", false) and rest.is_consumed()
		and choice.descriptor.half_ids == [first, second]
		and choice.descriptor.cost == mini(3, maxi(a.cost, b.cost) + 1)
		and choice.remaining_scraps == 0,
		"real three-scrap Rest creates ordered unupgradable composite")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new([choice.stitched_id], rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand == [choice.stitched_id], "held composite in seeded active turn")
	var party := CombatParty.new(_authored("res://data/heroes/starter_party.json"))
	var enemies := CombatEnemies.new(_authored("res://data/enemies/starter_enemies.json"))
	_check(party.is_valid() and enemies.is_valid()
		and party.get_hero(1).id == "warden" and party.get_hero(1).max_hp == 40
		and party.get_hero(2).id == "seamstress" and party.get_hero(2).max_hp == 30
		and party.get_hero(3).id == "tinker" and party.get_hero(3).max_hp == 26
		and enemies.get_enemy(1).id == "ragling" and enemies.get_enemy(1).hp == 12
		and enemies.get_enemy(2).id == "ragling_guard" and enemies.get_enemy(2).hp == 12,
		"actual three starter heroes and two 12-HP enemy slots")
	var attacks := CombatAttackCards.new()
	return {"rest": rest, "id": choice.stitched_id, "deck": deck,
		"party": party, "enemies": enemies, "attacks": attacks,
		"service": CombatStitchedCards.new(attacks),
		"wardrobe": null, "torn": null, "button_heals": null}


func _state(c: Dictionary) -> Dictionary:
	var a: CombatAttackCards = c.attacks
	return {
		"draw_pile": c.deck.draw_pile.duplicate(),
		"hand": c.deck.hand.duplicate(),
		"discard_pile": c.deck.discard_pile.duplicate(),
		"energy": c.deck.energy,
		"turn_active": c.deck.turn_active,
		"rng_seed": c.deck._rng.seed,
		"rng_state": c.deck._rng.state,
		"heroes": c.party.get_heroes(),
		"enemies": c.enemies.get_enemies(),
		"tinker_consumed": a._tinker._consumed,
		"patch_latches": {} if a._patches == null else a._patches.latch_snapshot(),
	}


func _whole(c: Dictionary) -> Dictionary:
	var a: CombatAttackCards = c.attacks
	return {
		"combat": _state(c),
		"rest": c.rest.get_snapshot(),
		"rest_consumed": c.rest.is_consumed(),
		"wardrobe": {} if c.wardrobe == null else c.wardrobe.get_snapshot(),
		"torn": {} if c.torn == null else c.torn.read_state(),
		"patch_active": {} if a._patches == null else a._patches.active_snapshot(),
		"support_wardrobe_snapshot": c.service._support._wardrobe_snapshot.duplicate(true),
		"support_torn_snapshot": c.service._support._torn_snapshot.duplicate(true),
		"button": {} if c.get("button_heals") == null \
			or c.button_heals._borrowed_button == null else {
			"state": c.button_heals._borrowed_button.read_state(),
			"receipt_number": c.button_heals._heal_receipt_number,
			"bound_party": c.button_heals._button_party == c.party,
			"pending": c.button_heals._pending_new_party,
		},
	}


func _peek(c: Dictionary, first_target: Variant, second_target: Variant,
		expected: Variant = null) -> Dictionary:
	var receipt: Variant = c.rest.get_snapshot() if expected == null else expected
	return forecast.get_forecast(c.rest, receipt, c.deck, c.party, c.enemies,
		c.id, first_target, second_target, c.service)


func _real(c: Dictionary, a: int, b: int) -> Dictionary:
	return c.service.play_stitched(c.deck, c.party, c.enemies, c.rest, c.id, a, b)


func _compare(c: Dictionary, a: int, b: int, label: String) -> Dictionary:
	var before := _whole(c)
	var first := _peek(c, a, b)
	var second := _peek(c, a, b)
	_check(first.playable and first.halves.size() == 2
		and first.projected.size() > 0, label + ": full two-half forecast")
	_check(first == second, label + ": repeated unchanged forecast is deterministic")
	_check(_whole(c) == before, label + ": no original model, Rest, RNG, wardrobe or latch changed")
	if not first.playable:
		return first
	var real := _real(c, a, b)
	_check(real.ok and real.halves == first.halves, label + ": exact committed ordered half events")
	_check(_state(c) == first.projected, label + ": exact post-commit combat and RNG state")
	_check(c.rest.get_snapshot() == before.rest and
		(c.wardrobe == null or c.wardrobe.get_snapshot() == before.wardrobe),
		label + ": real play does not spend run scraps or wardrobe")
	# Returned nested dictionaries are truly independent, not shallow aliases.
	var clean := first.duplicate(true)
	first.halves[0]["ok"] = false
	first.projected.heroes[0]["hp"] = -99
	first.projected.enemies[0]["hp"] = -99
	_check(_peek_after_play_does_not_change_prior(second, clean),
		label + ": returned deep copies cannot alter older outcomes or real state")
	return clean


func _peek_after_play_does_not_change_prior(second: Dictionary, clean: Dictionary) -> bool:
	return second == clean and second.halves[0].ok and second.projected.heroes[0].hp >= 0


func _reject(c: Dictionary, a: Variant, b: Variant, label: String,
		expected: Variant = null) -> void:
	var before := _whole(c)
	var result := _peek(c, a, b, expected)
	_check(result == {"playable": false, "stitched_id": "", "cost": 0,
		"halves": [], "projected": {}}, label + ": atomic empty rejection")
	_check(_peek(c, a, b, expected) == result and _whole(c) == before,
		label + ": stable refusal, no input state or RNG/latch/ledger changes")


func _test_separate_targets() -> void:
	for seed_value in [7, 9527]:
		var c := _fixture(PRICK, POP, seed_value)
		var outcome := _compare(c, 1, 2, "Prick first / Pop second seed " + str(seed_value))
		_check(outcome.cost == 2 and outcome.projected.energy == 1
			and outcome.projected.discard_pile == [c.id]
			and outcome.projected.hand.is_empty(), "two cost-one halves charged once")
		_check(outcome.halves == [
			{"ok": true, "hits": [{"position": 1, "damage": 3,
				"block_absorbed": 0, "hp_loss": 3, "statuses": {"bleed": 3}}]},
			{"ok": true, "hits": [{"position": 2, "damage": 8,
				"block_absorbed": 0, "hp_loss": 8, "statuses": {}}]}],
			"Prick 3/Bleed 3 and first Pop 8 exact events")
		_check(outcome.projected.enemies[0].hp == 9
			and outcome.projected.enemies[1].hp == 4
			and outcome.projected.tinker_consumed, "enemy slots and Tinker latch")
		var backwards := _fixture(POP, PRICK, seed_value)
		var reverse := _compare(backwards, 2, 1, "Pop then Prick seed " + str(seed_value))
		_check(reverse.halves[0].hits[0].damage == 8
			and reverse.halves[1].hits[0].statuses == {"bleed": 3},
			"authored order preserved both ways")


func _test_late_failure_and_retry() -> void:
	var c := _fixture(PRICK, POP)
	_check(c.enemies.apply_damage(1, 9) and c.enemies.get_enemy(1).hp == 3
		and c.enemies.get_enemy(2).hp == 12, "real first target in lethal range")
	var offered := CombatStitchedTargetPreview.new().get_preview(c.rest,
		c.rest.get_snapshot(), c.deck, c.party, c.enemies, c.id)
	_check(offered.playable and offered.second_half.target_positions.has(1),
		"late-slain target originally selectable")
	_reject(c, 1, 1, "late second-half target dies from first Prick")
	var good := _compare(c, 1, 2, "legal retry after late failure")
	_check(good.playable and good.projected.enemies[0].hp == 0
		and good.projected.enemies[1].hp == 4, "legal retry commits one composite")
	c = _fixture(PRICK, POP)
	c.enemies.apply_damage(1, 12)
	_reject(c, 1, 2, "already slain first target")
	c = _fixture(PRICK, POP)
	c.enemies.apply_damage(2, 12)
	_reject(c, 1, 2, "already slain second target")


func _patches(c: Dictionary) -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(records is Array, "authored M04 patch catalog")
	var definitions: Array = []
	for entry in records:
		if entry.get("id") in ["button_eye", "pincushion_arm"]:
			definitions.append({"id": entry.id, "slot": entry.slot})
	_check(definitions.size() == 2, "both authored attack patches present")
	var torn := RunTornMending.new(c.party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(),
		["button_eye", "pincushion_arm"], definitions, 4)
	_check(wardrobe.is_valid() and torn.is_valid(), "genuine wardrobe and tear services")
	_check(wardrobe.sew("button_eye", "seamstress", "HEAD", "forecast-eye",
		wardrobe.get_snapshot()).ok, "sew real Button Eye to Seamstress")
	_check(wardrobe.sew("pincushion_arm", "tinker", "ARM", "forecast-arm",
		wardrobe.get_snapshot()).ok, "sew real Pincushion Arm to Tinker")
	_check(c.attacks.bind_patch_wardrobe(wardrobe, torn)
		and c.service.bind_patch_wardrobe(wardrobe, torn),
		"existing attack and support transactions bind genuine patch ledgers")
	c.wardrobe = wardrobe
	c.torn = torn


func _test_patches_and_both_orders() -> void:
	for seed_value in [9, 9527]:
		for reversed in [false, true]:
			var c := _fixture(POP if reversed else PRICK,
				PRICK if reversed else POP, seed_value)
			_patches(c)
			var before := _whole(c)
			var result := _compare(c, 1, 1,
				"actual wearer Exposed and ARM, reversed=" + str(reversed))
			_check(result.playable and before.patch_active.seamstress == ["button_eye"]
				and before.patch_active.tinker == ["pincushion_arm"],
				"real patch snapshot has correct distinct wearers")
			if reversed:
				_check(result.halves[0].hits[0].damage == 9
					and result.halves[1].hits[0].damage == 3
					and result.projected.enemies[0].statuses ==
						{"bleed": 3, "exposed": 1},
					"first Pop gets 5+3+1, later Prick grants Exposed")
			else:
				_check(result.halves[0].hits[0].statuses ==
						{"bleed": 3, "exposed": 1}
					and result.halves[1].hits[0].damage == 13
					and result.halves[1].hits[0].hp_loss == 9,
					"Exposed from Prick amplifies second Pop to floor(13.5)=13")
			_check(result.projected.patch_latches.seamstress
				and result.projected.tinker_consumed,
				"forecast projects consumed first-combat/turn latches")
	# An already-used Tinker latch must be forecast as already used.
	var spent := _fixture(PRICK, POP)
	_patches(spent)
	spent.attacks._tinker._consumed = true
	spent.attacks._patches._consumed.seamstress = true
	var saved := _whole(spent)
	var depleted := _compare(spent, 1, 2, "inherited prior Tinker/HEAD latch")
	_check(depleted.halves[0].hits[0].statuses == {"bleed": 3}
		and depleted.halves[1].hits[0].damage == 6
		and saved.combat.tinker_consumed, "no imaginary first attack reactivation")


func _test_support_and_area() -> void:
	for reverse in [false, true]:
		var c := _fixture(MEND if reverse else BRACE, BRACE if reverse else MEND)
		_check(c.party.apply_damage(3, 3) and c.party.get_hero(3).hp == 23,
			"capped Mend recipient starts down 3 HP")
		var result := _compare(c, 3 if reverse else 0,
			0 if reverse else 3, "Brace/Mend ordered support")
		_check(result.projected.heroes[0].block == 7
			and result.projected.heroes[2].hp == 26
			and result.projected.energy == 1,
			"+7 self Block, healing capped at max HP, one charge")
	var c := _fixture(PRICK, BOMB)
	var result := _compare(c, 1, 0, "Prick then target-free Scrap Bomb")
	_check(result.cost == 3 and result.projected.energy == 0
		and result.projected.enemies[0].hp == 2
		and result.projected.enemies[1].hp == 5
		and result.halves[1].hits.size() == 2
		and result.halves[1].hits[0].damage == 7
		and result.halves[1].hits[1].damage == 7,
		"7-damage Tinker bomb on every living eligible slot")
	c = _fixture(PRICK, BOMB)
	_check(c.enemies.apply_damage(1, 9), "first hit kills the first Bomb slot")
	var survivors := _compare(c, 1, 0, "Bomb skips newly slain target")
	_check(survivors.halves[1].hits.size() == 1
		and survivors.halves[1].hits[0].position == 2,
		"authoritative area resolver excludes first-half kill")
	c = _fixture(BOMB, PRICK)
	var backward := _compare(c, 0, 2, "Bomb then Prick reverse order")
	_check(backward.halves[0].hits.size() == 2
		and backward.halves[1].hits[0].position == 2,
		"reverse order uses target-free half first")


func _test_draw_and_seeded_replay() -> void:
	for seed_value in [0, 101, 9527]:
		var copies: Array = []
		for duplicate in range(2):
			var c := _fixture(TUNE, "seamstress_stitch_up", seed_value)
			c.deck.draw_pile.clear()
			c.deck.discard_pile.assign(["warden_strike", PRICK, BRACE])
			var before := _whole(c)
			var outcome := _compare(c, 0, 1, "seeded reshuffle " + str(seed_value))
			_check(outcome.playable and outcome.projected.hand.size() == 1
				and outcome.projected.discard_pile == [c.id]
				and outcome.projected.rng_state != before.combat.rng_state
				and outcome.projected.heroes[0].block == 5
				and outcome.projected.energy == 1,
				"Tune Up draws one after seeded Fisher-Yates reshuffle")
			copies.append(outcome)
		_check(copies[0] == copies[1], "independent real/rest RNG matches for seed " + str(seed_value))
	var no_refill := _fixture(TUNE, BRACE)
	no_refill.deck.draw_pile.assign([POP])
	var direct := _compare(no_refill, 0, 0, "Tune Up direct draw")
	_check(direct.projected.hand == [POP] and direct.projected.discard_pile == [no_refill.id],
		"no redraw of self/composite, original pile consumed")


func _test_rejections() -> void:
	var c := _fixture(PRICK, POP)
	_reject(c, 0, 2, "missing first target")
	_reject(c, 1, 0, "missing late target after first hit")
	_reject(c, 1, 3, "unoccupied second slot")
	_reject(c, 4, 2, "out-of-range first target")
	_reject(c, "1", 2, "wrong target Variant type")
	var stale: Dictionary = c.rest.get_snapshot()
	stale.remaining_scraps += 1
	_reject(c, 1, 2, "stale Rest optimistic receipt", stale)
	_check(_compare(c, 1, 2, "legal real play after every rejected target").playable,
		"rejections never prevent legitimate committed card")
	c = _fixture(PRICK, POP)
	c.deck.try_spend_energy(2)
	_reject(c, 1, 2, "insufficient energy")
	c = _fixture(PRICK, POP)
	c.deck.end_turn()
	_reject(c, 1, 2, "inactive turn")
	c = _fixture(PRICK, POP)
	c.deck.discard_played(c.id)
	_reject(c, 1, 2, "unheld composite")
	c = _fixture(PRICK, POP)
	var forged: Dictionary = c.rest.get_snapshot()
	forged.descriptors[c.id].second_half.effects.damage = 999
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors, 0, 2)
	_check(not c.rest.is_valid(), "forged Rest descriptor genuinely invalid")
	_reject(c, 1, 2, "forged Rest descriptor")
	for owner in [2, 3]:
		c = _fixture(PRICK, POP)
		_check(c.party.apply_damage(owner, c.party.get_hero(owner).hp)
			and c.party.is_downed(owner), "real downed original owner")
		_reject(c, 1, 2, "downed/torn owner " + str(owner))
	c = _fixture(PRICK, BOMB)
	var slots: Array = c.party.get_heroes()
	c.party = CombatParty.new([slots[0], slots[2], slots[1]])
	_check(c.party.get_hero(2).id == "tinker", "wrong original Tinker from slot")
	_reject(c, 1, 0, "wrong from-position for second half")
	c = _fixture("warden_strike", POP)
	slots = c.party.get_heroes()
	c.party = CombatParty.new([slots[2], slots[1], slots[0]])
	_reject(c, 1, 2, "wrong from-position for first half")
	c = _fixture(PRICK, "warden_shield_bash")
	_reject(c, 2, 2, "forbidden authored Warden second target")
	c = _fixture(PRICK, POP)
	c.enemies._enemies[0]["statuses"] = {"bleed": CombatEnemies.MAX_INT}
	_reject(c, 1, 2, "early overflow rejects before any forecast outcome")
	c = _fixture(PRICK, "warden_shield_bash")
	c.enemies._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	_reject(c, 2, 1, "late status overflow rolls back first-half damage")
	c = _fixture(PRICK, POP)
	var before := _whole(c)
	_check(not forecast.get_forecast(null, c.rest.get_snapshot(), c.deck,
		c.party, c.enemies, c.id, 1, 2).playable
		and not forecast.get_forecast(c.rest, c.rest.get_snapshot(), null,
			c.party, c.enemies, c.id, 1, 2).playable
		and _whole(c) == before, "null run ledger/deck fail safely")


func _test_real_torn_and_mend() -> void:
	var c := _fixture(PRICK, POP)
	_patches(c)
	var start: Array = c.torn.read_state().heroes
	var end := start.duplicate(true)
	end[1]["hp"] = 0
	_check(c.torn.observe_battle_end("real-tear", start, end).ok,
		"real battle tear downs the sewn Button Eye owner")
	var worn: Dictionary = c.wardrobe.get_snapshot()
	_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes,
		worn.owned, worn.scraps, worn.gold, worn.cards, worn),
		"refresh real patch context from torn roster")
	c.party._heroes.assign(c.torn.read_state().heroes)
	_check(c.wardrobe.project_active(c.torn.read_state()).active.seamstress.is_empty()
		and c.wardrobe.get_snapshot().worn.seamstress.HEAD == "button_eye",
		"torn wearer retains sewing but cannot use the patch")
	_check(c.attacks.bind_patch_wardrobe(c.wardrobe, c.torn)
		and c.service.bind_patch_wardrobe(c.wardrobe, c.torn),
		"torn attack and support projections bind")
	_reject(c, 1, 2, "genuine torn/downed owner may not play the composite")
	var run_state: Dictionary = c.torn.read_state()
	var mended: Dictionary = c.torn.choose_mend("real-mend", "fresh-mend-receipt",
		"seamstress", 2, 2, run_state.heroes, true)
	_check(mended.ok and mended.heroes[1].hp > 0
		and mended.heroes[1].max_hp == 27,
		"real two-scrap torn mending restores living Seamstress")
	worn = c.wardrobe.get_snapshot()
	_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes,
		worn.owned, worn.scraps, worn.gold, worn.cards, worn),
		"refresh restored wearer from real mend")
	c.party._heroes.assign(c.torn.read_state().heroes)
	_check(c.attacks.bind_patch_wardrobe(c.wardrobe, c.torn)
		and c.service.bind_patch_wardrobe(c.wardrobe, c.torn),
		"fresh battle rebinds restored wearer")
	var healed := _compare(c, 1, 2, "real sewn owner mended then played")
	_check(healed.playable and healed.halves[0].hits[0].statuses ==
		{"bleed": 3, "exposed": 1}
		and healed.halves[1].hits[0].damage == 9,
		"restored Button Eye and ARM powers return on their genuine owners")

func _bind_pool_spool(c: Dictionary, wearer: String) -> void:
	var slots: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		CombatShopPatchRules.SLOTS_CATALOG))
	_check(slots is Array and not slots.is_empty(), "real authored ARM patch slots")
	var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(), ["spare_spool"], slots, 5)
	var torn := RunTornMending.new(c.party.get_heroes())
	_check(wardrobe.is_valid() and torn.is_valid(), "real valid pool forecast patch ledgers")
	_check(wardrobe.sew("spare_spool", wearer, "ARM", "pool-spool",
		wardrobe.get_snapshot()).ok, "real owner-specific Spool sew receipt")
	_check(c.service.bind_patch_wardrobe(wardrobe, torn,
		wardrobe.get_snapshot(), torn.read_state()),
		"forecast binds original optimistic wardrobe/torn receipts")
	c.wardrobe = wardrobe
	c.torn = torn


func _test_pool_heal_forecasts() -> void:
	var pool := SeamstressPoolCards.new()
	for id in CombatStitchedTargetPreview.POOL_HEAL_IDS:
		var definition: Dictionary = pool.get_definition(id)
		_check(not definition.is_empty() and definition ==
			RunRestStitchCards.resolve_card_definition(id), "canonical pool base/+ " + id)
		var field: bool = id in CombatSeamstressPoolHeals.FIELD_MEND_IDS
		var counterpart: String = POP if field else BRACE
		for reverse in [false, true]:
			for mode in ["unbound", "seamstress", "warden"]:
				var first: String = counterpart if reverse else id
				var second: String = id if reverse else counterpart
				var c := _fixture(first, second, 3501)
				if mode != "unbound":
					_bind_pool_spool(c, mode)
				_check(c.party.apply_damage(1, 12)
					and c.party.apply_damage(2, 9)
					and c.party.apply_damage(3, 10),
					id + ": three genuine wounds before forecast")
				var first_target: int = (2 if field else 0) if reverse else (0 if field else 1)
				var second_target: int = (0 if field else 1) if reverse else (2 if field else 0)
				var initial := _whole(c)
				var result := _compare(c, first_target, second_target,
					id + " forecast order " + str(reverse) + " wearer " + mode)
				var healing: int = definition.effects.heal + (2 if mode == "seamstress" else 0)
				var block: int = definition.effects.get("block", 0)
				var half: Dictionary = result.halves[1 if reverse else 0] if result.playable else {}
				var slots: Array = [1, 2, 3] if field else [1]
				_check(result.playable and half == {
					"ok": true, "effect": "party_heal" if field else "ally_heal",
					"amount": healing, "block": block, "affected_positions": slots
					}, id + ": exact forecast ordered healing effect and patch amount")
				if not result.playable:
					continue
				_check(result.cost == (3 if field else 2)
					and result.projected.energy == (0 if field else 1)
					and result.projected.hand.is_empty()
					and result.projected.discard_pile == [c.id]
					and result.projected.rng_state == initial.combat.rng_state
					and result.projected.rng_seed == initial.combat.rng_seed,
					id + ": identical energy, once-only discard and unadvanced RNG")
				_check(result.projected.heroes[0].hp == 28 + healing
					and result.projected.heroes[1].hp == (21 + healing if field else 21)
					and result.projected.heroes[2].hp == (16 + healing if field else 16)
					and result.projected.heroes[0].block == (0 if field else 7 + block),
					id + ": exact healed slots, unaffected recipients, independent Block")
	# A later failed half must not publish first-half HP/Block, nor a patch
	# latch, deck spend or seeded RNG movement.
	var late := _fixture("seamstress_darning_plus", BRACE)
	_bind_pool_spool(late, "seamstress")
	_check(late.party.apply_damage(2, 10)
		and late.party.gain_block(1, CombatParty.MAX_INT),
		"first heal legal, genuine late Brace overflow precondition")
	_reject(late, 2, 0, "later Brace overflow rolls back patched Darning+ forecast")
	var before := _whole(late)
	_check(_real(late, 2, 0) == {"ok": false, "halves": []}
		and _whole(late) == before, "same late failure in real committed transaction")
	_check(late.party.start_player_turn(), "real hero Block reset permits retry")
	_check(_compare(late, 2, 0, "successful Darning+ retry after late overflow").playable,
		"no rejected latches poison valid retry")
	var drawn := _fixture(TUNE, "seamstress_darning")
	_bind_pool_spool(drawn, "seamstress")
	drawn.deck.discard_pile.assign(["warden_strike", POP, BRACE])
	_check(drawn.party.apply_damage(1, 9)
		and drawn.party.gain_block(1, CombatParty.MAX_INT),
		"authentic seeded draw first and late Darning overflow")
	_reject(drawn, 0, 1, "draw/reshuffle then second Darning overflow")
	before = _whole(drawn)
	_check(_real(drawn, 0, 1) == {"ok": false, "halves": []}
		and _whole(drawn) == before,
		"real second-half failure preserves all piles and seeded RNG")
	var party_all := _fixture("seamstress_field_mend_plus", BRACE)
	_bind_pool_spool(party_all, "seamstress")
	_check(party_all.party.apply_damage(3, 26) and party_all.party.is_downed(3)
		and party_all.party.apply_damage(1, 8), "Field Mend genuine torn beneficiary")
	var survived := _compare(party_all, 0, 0, "party-all forecast skips downed Tinker")
	_check(survived.playable and survived.halves[0].affected_positions == [1, 2]
		and survived.projected.heroes[2].hp == 0
		and survived.projected.heroes[0].hp == 40,
		"Field Mend+ per-recipient patched healing caps HP without revival")
	var invalid := _fixture("seamstress_field_mend", BRACE)
	_bind_pool_spool(invalid, "seamstress")
	_reject(invalid, 1, 0, "party-all nonzero caller target rejected without changes")


## A real run wardrobe owning the authored P6 COAT patches, an authentic tear
## ledger and the genuine combat-bound healing service the mounted hand passes.
## Nothing here is a test-only stand-in: the shipping patch catalog, the real
## Rest stitch ledger and the real sewing transaction create every authority.
func _bind_button(c: Dictionary, wearer: String = "warden") -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		CombatBorrowedButton.CATALOG_PATH))
	_check(records is Array and not records.is_empty(), "authored M05 COAT patch catalog")
	var definitions: Array = []
	if records is Array:
		for entry in records:
			if entry.get("id") == "borrowed_button":
				definitions.append({"id": entry.id, "slot": entry.slot})
	_check(not definitions.is_empty() and definitions[0].slot == "COAT",
		"authored Borrowed Button COAT definition present")
	var torn := RunTornMending.new(c.party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(), ["borrowed_button"],
		definitions, 4)
	_check(wardrobe.is_valid() and torn.is_valid(),
		"genuine run wardrobe and untorn run ledger")
	if wearer != "":
		_check(wardrobe.sew("borrowed_button", wearer, "COAT", "forecast-p6-sew",
			wardrobe.get_snapshot()).ok, "Borrowed Button genuinely sewn to " + wearer)
	_check(c.service.bind_patch_wardrobe(wardrobe, torn)
		and c.attacks.bind_patch_wardrobe(wardrobe, torn),
		"stitched and attack transactions bind the real patch ledgers")
	var heals := CombatSeamstressPoolHeals.new()
	_check(heals.bind_patch_wardrobe(wardrobe, torn),
		"ordinary healing service binds the same authentic combat ledgers")
	c.service.bind_borrowed_button(heals)
	c.wardrobe = wardrobe
	c.torn = torn
	c.button_heals = heals
	_check(heals._borrowed_button != null and heals._heal_receipt_number == 0
		and heals._borrowed_button.read_state().awards == 0,
		"combat P6 notifier starts genuinely unspent and unobserved")


func _button_state(c: Dictionary) -> Dictionary:
	return c.button_heals._borrowed_button.read_state()


## AC1/AC2: a genuine Rest-created Mend/Brace composite on a sewn, living,
## wounded Warden must forecast exactly the real committed HP/Block, in both half
## orders, with plus-three P6 Block paid once through the real notifier.
func _test_borrowed_button_stitched_parity() -> void:
	for reverse in [false, true]:
		for seed_value in [6111, 9527]:
			var c := _fixture(BRACE if reverse else MEND, MEND if reverse else BRACE,
				seed_value)
			_bind_button(c)
			_check(c.party.apply_damage(1, 12) and c.party.get_hero(1).hp == 28,
				"living different-owner P6 wearer genuinely wounded")
			var label := "sewn stitched heal order " + str(reverse) + " seed " + str(seed_value)
			var result := _compare(c, 0 if reverse else 1, 1 if reverse else 0, label)
			_check(result.playable and result.cost == 2
				and result.projected.heroes[0].hp == 33
				and result.projected.heroes[0].block == 10
				and result.projected.heroes[1].hp == 30
				and result.projected.heroes[2].hp == 26,
				label + ": forecast projects 5 restored HP and 7 Brace plus exactly 3 P6")
			var state := _button_state(c)
			_check(c.party.get_hero(1).hp == 33 and c.party.get_hero(1).block == 10,
				label + ": real commit matches projected Warden HP/Block exactly")
			_check(state.awards == 1 and state.block_awarded == 3
				and state.wearer_id == "warden" and state.receipts.size() == 1
				and state.receipt_id.begins_with("stitched_half_%d:" % (1 if reverse else 0))
				and c.button_heals._heal_receipt_number == 1,
				label + ": one authenticated half receipt pays the shared notifier once")


## AC2: the spent latch is inherited, never re-armed or spent by a forecast, and
## repeated predictions preserve the real receipt identities and award facts.
func _test_borrowed_button_spent_latch() -> void:
	var c := _fixture(MEND, BRACE, 6112)
	_bind_button(c)
	_check(c.party.apply_damage(1, 12) and c.party.get_hero(1).hp == 28,
		"first genuine wound before two committed casts")
	var paid := _compare(c, 1, 0, "first sewn Mend/Brace pays the once-per-combat latch")
	_check(paid.playable and c.party.get_hero(1).hp == 33
		and c.party.get_hero(1).block == 10 and _button_state(c).awards == 1,
		"first real composite heals 5 and pays 7 Brace plus one 3-Block award")
	_check(c.deck.end_turn() and c.party.start_player_turn() and c.deck.start_turn()
		and c.deck.hand.has(c.id), "actual next turn redraws the same composite")
	_check(c.party.get_hero(1).block == 0, "turn boundary clears the first award Block")
	var saved := _whole(c)
	var receipts: Array = _button_state(c).receipts.duplicate()
	var repeats: Array = []
	for copy in range(2):
		repeats.append(_peek(c, 1, 0))
	_check(repeats[0].playable and repeats[0] == repeats[1] and _whole(c) == saved,
		"spent-latch forecasts repeat exactly and touch no real authority")
	_check(repeats[0].projected.heroes[0].hp == 38
		and repeats[0].projected.heroes[0].block == 7,
		"a spent latch projects only the authored 7 Brace Block")
	_check(_whole(c) == saved and _button_state(c).receipts == receipts
		and _button_state(c).awards == 1 and c.button_heals._heal_receipt_number == 1,
		"repeated forecasts preserve the real receipt IDs, counter and award")
	var real := _real(c, 1, 0)
	_check(real.ok and _state(c) == repeats[0].projected,
		"the second genuine commit matches the spent-latch forecast exactly")
	_check(c.party.get_hero(1).hp == 38 and c.party.get_hero(1).block == 7
		and _button_state(c).awards == 1 and _button_state(c).receipts.size() == 2,
		"a later genuine heal is observed but never awards P6 twice")

	# The next combat re-arms the retained service: the previous battle's spent
	# latch must neither suppress this battle's forecast nor leak its receipts.
	var next_party := CombatParty.new(_authored("res://data/heroes/starter_party.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113
	var next_deck := CombatDeck.new([c.id], rng)
	_check(next_party.is_valid() and next_deck.start_turn()
		and next_deck.hand == [c.id] and next_deck.energy == 3,
		"next genuine combat begins with the composite and three energy")
	c.party = next_party
	c.deck = next_deck
	_check(c.party.apply_damage(1, 12) and c.party.get_hero(1).hp == 28,
		"next battle wearer starts genuinely wounded")
	_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn)
		and c.button_heals.bind_patch_wardrobe(c.wardrobe, c.torn)
		and c.button_heals._pending_new_party and c.button_heals._button_party != c.party,
		"retained service authenticates a genuinely different battle party")
	var renewed := _compare(c, 1, 0, "next-combat rearm after a spent latch")
	_check(renewed.playable and renewed.projected.heroes[0].hp == 33
		and renewed.projected.heroes[0].block == 10
		and _button_state(c).awards == 1 and c.button_heals._heal_receipt_number == 1,
		"a new combat projects and commits one renewed 3-Block award")


## AC3: no award is projected for a full-HP recipient, the wearer's own heal, an
## unsewn or run-torn wearer, a foreign or stale COAT authority, or a composite
## whose later half fails; every rejection is atomic and leaves the latch alone.
func _test_borrowed_button_negatives() -> void:
	var c := _fixture(MEND, BRACE, 6113)
	_bind_button(c)
	var full := _compare(c, 1, 0, "full-HP different-owner Mend")
	_check(full.playable and full.projected.heroes[0].hp == 40
		and full.projected.heroes[0].block == 7 and _button_state(c).awards == 0
		and _button_state(c).receipts.is_empty(),
		"full-HP overheal projects no P6 receipt or Block")
	c = _fixture(MEND, BRACE, 6114)
	_bind_button(c, "seamstress")
	_check(c.party.apply_damage(2, 10) and c.party.get_hero(2).hp == 20,
		"sewn Seamstress genuinely wounded before her own Mend")
	var own := _compare(c, 2, 0, "own-hero stitched Mend")
	_check(own.playable and own.projected.heroes[1].hp == 25
		and own.projected.heroes[1].block == 0 and _button_state(c).awards == 0,
		"self-heal restores HP but never awards P6 Block")
	c = _fixture(MEND, BRACE, 6115)
	_bind_button(c, "")
	_check(c.party.apply_damage(1, 12), "owned but unsewn COAT witnesses a real heal")
	var unsewn := _compare(c, 1, 0, "owned but unsewn COAT")
	_check(unsewn.playable and unsewn.projected.heroes[0].hp == 33
		and unsewn.projected.heroes[0].block == 7 and _button_state(c).awards == 0,
		"unsewn patch projects no P6 Block")

	# The same authored content in a different wardrobe OBJECT is a foreign
	# authority: neither the forecast nor the real commit may pay it.
	c = _fixture(MEND, BRACE, 6116)
	_bind_button(c)
	_check(c.party.apply_damage(1, 12), "wounded wearer with a foreign-bound helper")
	var foreign := RunPatchWardrobe.new(c.torn.read_state().heroes, ["borrowed_button"],
		[{"id": "borrowed_button", "slot": "COAT"}], 4)
	_check(foreign.is_valid() and foreign.sew("borrowed_button", "warden", "COAT",
		"forecast-p6-foreign", foreign.get_snapshot()).ok,
		"independent authentic wardrobe genuinely sewn to Warden")
	_check(c.button_heals.bind_patch_wardrobe(foreign, c.torn),
		"helper rebound to the foreign wardrobe authority")
	var by_other := _compare(c, 1, 0, "foreign P6 authority")
	_check(by_other.playable and by_other.projected.heroes[0].block == 7
		and _button_state(c).awards == 0,
		"forecast and real commit both refuse a foreign COAT authority")

	# A wardrobe that advanced after the transaction bound it is stale: the whole
	# forecast and the matching real commit fail closed with no spend.
	c = _fixture(MEND, BRACE, 6117)
	_bind_button(c)
	_check(c.party.apply_damage(1, 12), "wounded wearer with a stale wardrobe authority")
	_check(c.wardrobe.start_rest("forecast-p6-stale", c.wardrobe.get_snapshot()).ok,
		"bound wardrobe advanced authentically")
	_reject(c, 1, 0, "stale P6 wardrobe authority")
	var stale_before := _whole(c)
	_check(_real(c, 1, 0) == {"ok": false, "halves": []} and _whole(c) == stale_before
		and _button_state(c).awards == 0,
		"the same stale authorities refuse the real commit without spending")

	# A genuinely late Brace overflow rolls back the earlier heal and P6 preview.
	var late := _fixture(MEND, BRACE, 6118)
	_bind_button(late)
	_check(late.party.apply_damage(1, 12), "wounded wearer before a late Brace overflow")
	_check(late.party.gain_block(1, CombatParty.MAX_INT - 6),
		"genuine near-limit Warden Block for the later Brace half")
	_reject(late, 1, 0, "later Brace overflow rolls back the first heal and P6 preview")
	var late_before := _whole(late)
	_check(_real(late, 1, 0) == {"ok": false, "halves": []}
		and _whole(late) == late_before and _button_state(late).awards == 0
		and _button_state(late).receipts.is_empty(),
		"the same rejected commit publishes no heal, receipt or latch")
	_check(late.party.start_player_turn(), "real Block reset clears the near-limit stack")
	var retry := _compare(late, 1, 0, "legal retry after the rolled-back later Brace")
	_check(retry.playable and retry.projected.heroes[0].hp == 33
		and retry.projected.heroes[0].block == 10 and _button_state(late).awards == 1,
		"the retry commits one heal, 7 Brace and one 3-Block P6 award")

	# A genuinely run-torn wearer keeps the COAT sewn but suspended.
	c = _fixture(MEND, BRACE, 6119)
	_bind_button(c)
	var start: Array = c.torn.read_state().heroes
	var finish: Array = start.duplicate(true)
	finish[0].hp = 0
	_check(c.torn.observe_battle_end("forecast-p6-tear", start, finish).ok,
		"real battle tear records the wearer's run death")
	var worn: Dictionary = c.wardrobe.get_snapshot()
	_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes, worn.owned,
		worn.scraps, worn.gold, worn.cards, worn),
		"wardrobe refreshes the genuinely torn run roster")
	var roster: Array = []
	for hero in c.torn.read_state().heroes:
		roster.append({"id": hero.id, "max_hp": hero.max_hp})
	c.party = CombatParty.new(roster)
	_check(c.party.is_valid() and c.party.get_hero(1).hp == 37
		and c.torn.read_state().heroes[0].hp == 0,
		"fresh battle party lives while the run ledger keeps the wearer torn")
	_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn)
		and c.button_heals.bind_patch_wardrobe(c.wardrobe, c.torn),
		"both combat authorities rebind to the exact torn ledger")
	_check(c.party.apply_damage(1, 8) and c.party.get_hero(1).hp == 29,
		"run-torn wearer is genuinely wounded in battle")
	var torn_result := _compare(c, 1, 0, "run-torn COAT wearer")
	_check(torn_result.playable and torn_result.projected.heroes[0].hp == 34
		and torn_result.projected.heroes[0].block == 7 and _button_state(c).awards == 0,
		"suspended run-torn COAT projects no P6 Block while keeping authored Brace")
