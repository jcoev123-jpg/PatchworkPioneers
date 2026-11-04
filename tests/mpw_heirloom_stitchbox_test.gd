extends SceneTree
## P12 remains catalog-authenticated; both completed-run Heirlooms are payable
## at the real Peddler, while Shared Hem remains live on held Brace.

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _has(records: Array, id: String, slot: String) -> bool:
	var count := 0
	for record in records:
		if record is Dictionary and record.get("id") == id and record.get("slot") == slot:
			count += 1
	return count == 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var texts := []
	var catalogs := []
	for path in RunAuthoredPatchDefinitions.CATALOG_PATHS:
		var raw := FileAccess.get_file_as_string(path)
		_check(not raw.is_empty(), "catalog exists: " + path)
		texts.append(raw)
		catalogs.append(JSON.parse_string(raw))
	_check(catalogs.size() == RunAuthoredPatchDefinitions.CATALOG_PATHS.size(),
		"nonvacuous full authored catalog")
	var full := RunAuthoredPatchDefinitions.project_catalogs(catalogs)
	var locked := RunAuthoredPatchDefinitions.project_eligible_power_catalogs(catalogs, false)
	var unlocked := RunAuthoredPatchDefinitions.project_eligible_power_catalogs(catalogs, true)
	for spec in [{"id": "needle_echo", "slot": "HEAD"},
			{"id": "shared_hem", "slot": "ARM"}]:
		_check(_has(full, spec.id, spec.slot) and _has(unlocked, spec.id, spec.slot),
			"both real definitions validate and eligible IDs project: " + spec.id)
		_check(not _has(locked, spec.id, spec.slot)
			and not _has(RunAuthoredPatchDefinitions.load_power_definitions(), spec.id, spec.slot),
			"first-run locked candidates never leak: " + spec.id)
	_check(not locked.is_empty() and unlocked.size() == locked.size() + 2,
		"both candidates are additive to existing authored power IDs")
	_check(unlocked == RunAuthoredPatchDefinitions.load_eligible_power_definitions(true)
		and unlocked == RunAuthoredPatchDefinitions.eligible_power_definitions_from_json_texts(texts, true),
		"pure record, JSON and disk eligible projections agree")
	_check(RunAuthoredPatchDefinitions.project_eligible_power_catalogs(catalogs, "true").is_empty(),
		"malformed eligibility refuses before publishing powers")
	var original := catalogs.duplicate(true)
	for index in range(2):
		for field in RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED[original[8][index].id]:
			var bad := original.duplicate(true)
			bad[8][index].erase(field)
			_check(RunAuthoredPatchDefinitions.project_catalogs(bad).is_empty()
				and RunAuthoredPatchDefinitions.project_eligible_power_catalogs(bad, true).is_empty(),
				"missing authored P12 metadata fails closed: " + field)
	_check(catalogs == original, "negative copies never mutate the shipped catalog")
	var samples := [{"id": "shared_hem", "price": 100},
		{"id": "relay_bobbin", "price": 100},
		{"id": "needle_echo", "price": 100},
		{"id": "stitched_badge", "price": 100}]
	var wallet := {"gold": 250, "deck": ["warden_strike"], "inventory": []}
	var wallet_before := wallet.duplicate(true)
	var candidates_before := samples.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 48125
	var state_before := rng.state
	var gated := RunShopStockOffers.filter_patch_candidates(samples, false)
	var eligible := RunShopStockOffers.filter_patch_candidates(samples, true)
	_check(gated.ok and gated.candidates.size() == 1
		and gated.candidates[0].id == "relay_bobbin",
		"locked pre-draw stock filters both Heirlooms and inert starter")
	_check(eligible.ok and eligible.candidates.size() == 3
		and eligible.candidates.any(func(c): return c.id == "needle_echo")
		and eligible.candidates.any(func(c): return c.id == "shared_hem"),
		"eligible pre-draw projection allows both with unchanged ordinary prices")
	var backwards := samples.duplicate(true)
	backwards.reverse()
	_check(RunShopStockOffers.filter_patch_candidates(backwards, true) == eligible,
		"unlocked candidate projection is order-independent and deterministic")
	eligible.candidates[0].price = 1
	_check(RunShopStockOffers.filter_patch_candidates(samples, true).candidates[0].price == 100,
		"projected candidates are detached from caller and later reads")
	for bad in [null, "not array", [{"id": "needle_echo", "price": -1}],
			[{"id": "needle_echo", "price": 100}, {"id": "needle_echo", "price": 100}],
			[{"id": "needle_echo", "price": 99.5}],
			[{"id": "unknown", "price": 100}]]:
		var rejected := RunShopStockOffers.filter_patch_candidates(bad, true)
		_check(not rejected.ok and rejected.candidates.is_empty(),
			"malformed/stale candidate refuses without partial output")
	_check(not RunShopStockOffers.filter_patch_candidates(samples, 1).ok,
		"invalid eligibility flag fails closed")
	_check(rng.state == state_before and wallet == wallet_before and samples == candidates_before,
		"all projection and refusal paths leave RNG, gold, deck and inventory unchanged")

	# The default locked Peddler still withholds both. Only an explicit
	# saved completed-run profile may admit the implemented ARM Hem.
	var party := ["warden", "seamstress", "tinker"]
	var cards := [{"id": "warden_strike", "price": 50},
		{"id": "seamstress_prick", "price": 50},
		{"id": "tinker_pop_shot", "price": 50}]
	var real := RunShopStockOffers.generate_peddler_stock(rng, party, cards, samples, [])
	_check(real.ok and real.patches.size() == 1 and real.patches[0].id == "relay_bobbin",
		"locked Peddler preserves its single ordinary patch despite P12 candidates")
	var offered_hem := false
	var offered_needle := false
	for seed_value in range(1, 70):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		var stock := RunShopStockOffers.generate_peddler_stock(probe, party, cards, samples, [], true)
		_check(stock.ok and stock.patches.size() == 1
			and ["relay_bobbin", "needle_echo", "shared_hem"].has(stock.patches[0].id),
			"unlocked Peddler selects a single legitimate patch")
		if stock.patches[0].id == "shared_hem":
			offered_hem = offered_hem or stock.patches[0].price == 100
		if stock.patches[0].id == "needle_echo":
			offered_needle = offered_needle or stock.patches[0].price == 100
	_check(offered_hem and offered_needle,
		"authentic unlocked stock draws either canonical 100-gold Heirloom")

	# App envelope accepts old two-field records and new versioned records,
	# without adding fields to RunDifficulty itself.
	var app: Variant = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	for _i in range(3):
		await process_frame
	var legacy := {"selected_tier": 0, "highest_cleared_tier": -1}
	_check(app.difficulty_state() == legacy and not app.heirloom_unlocked,
		"fresh mounted app starts with strictly two-field difficulty and locked P12")
	_check(app.restore_profile_state(legacy) and not app.heirloom_unlocked
		and app.difficulty_state() == legacy, "legacy profile restores with locked P12")
	var envelope := {"version": 1, "difficulty": legacy.duplicate(true), "heirloom_unlocked": true}
	_check(app.restore_profile_state(envelope) and app.heirloom_unlocked
		and app.difficulty_state() == legacy, "valid new envelope atomically restores eligibility")
	var before: Dictionary = app.profile_state()
	for bad_profile in [{"version": 2, "difficulty": legacy, "heirloom_unlocked": false},
			{"version": 1, "difficulty": {"selected_tier": 2, "highest_cleared_tier": -1},
				"heirloom_unlocked": false},
			{"version": 1, "difficulty": legacy, "heirloom_unlocked": 1},
			{"version": 1, "difficulty": legacy, "heirloom_unlocked": false, "extra": 1},
			{"selected_tier": 0, "highest_cleared_tier": -1, "heirloom_unlocked": true}]:
		_check(not app.restore_profile_state(bad_profile) and app.profile_state() == before,
			"malformed profile rejects atomically and retains unlock and difficulty")
	await _test_routed_peddler_to_battle(app)
	await _test_routed_needle_echo_purchase(app)
	app.free()
	_test_heirloom_needle()
	_test_heirloom_v3_red_thread()
	_test_heirloom_hem()
	_test_heirloom_binding_and_immutability()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("mpw_heirloom_stitchbox_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## P12 second slice: actual model-backed, scene-free battle receipts. This is
## deliberately not a shop mount or a live hand power.


func _heirloom_fixture(needle_owner: String = "warden",
		hem_owner: String = "seamstress") -> Dictionary:
	var admission := RunV3PartyAdmission.admit(["warden", "seamstress", "tinker"])
	_check(admission.ok and admission.party.size() == 3 and admission.deck.size() > 0,
		"nonvacuous canonical V3 admission with real starter deck")
	var party := CombatParty.new(admission.party)
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(),
		["needle_echo", "shared_hem"], RunAuthoredPatchDefinitions.load_definitions(),
		5, 125, admission.deck, 19651)
	_check(party.is_valid() and torn.is_valid() and wardrobe.is_valid(),
		"actual party, tear ledger and owned authored definitions")
	_check(wardrobe.sew("needle_echo", needle_owner, "HEAD",
		"sew_needle", wardrobe.get_snapshot()).ok, "canonical Needle HEAD sewn")
	_check(wardrobe.sew("shared_hem", hem_owner, "ARM",
		"sew_hem", wardrobe.get_snapshot()).ok, "canonical Hem ARM sewn")
	var foes := CombatEnemies.new([{"id": "heirloom_target", "max_hp": 100}])
	var pins := CombatPinned.new()
	var rules := CombatHeirloomPatchTriggers.new()
	_check(foes.is_valid() and rules.bind_battle(wardrobe, torn, party, foes, pins)
		and rules.start_player_turn(), "real battle binding and explicit turn start")
	var rng := RandomNumberGenerator.new()
	rng.seed = 38671
	var deck := CombatDeck.new(admission.deck, rng)
	return {"party": party, "torn": torn, "wardrobe": wardrobe, "foes": foes,
		"pins": pins, "rules": rules, "rng": rng, "deck": deck}




## Follow the actual map -> Fight reward -> mounted Peddler purchase/sew ->
## next Fight hand. This is deliberately a different witness from the detached
## receipt checks below: no local shop service or surrogate Pinned is substituted.
func _test_routed_peddler_to_battle(app) -> void:
	_check(app.heirloom_unlocked and app.deck == null and app.run_map == null,
		"real Peddler witness begins idle with restored completed-run eligibility")
	var purchased := false
	var eligible_routes := 0
	for seed_value in range(1, 5000):
		# Find an authored connected Fight -> Shop -> Fight without changing the
		# graph, any candidate stock or the run RNG after admission.
		var graph := RunMap.new()
		var graph_rng := RandomNumberGenerator.new()
		graph_rng.seed = seed_value
		graph.generate(graph_rng)
		var first_id := ""
		var shop_id := ""
		var next_id := ""
		for initial in graph.get_legal_choices():
			if graph.get_node(initial).get("type") != "Fight":
				continue
			for middle in graph.get_node(initial).get("outgoing", []):
				if graph.get_node(middle).get("type") != "Shop":
					continue
				for following in graph.get_node(middle).get("outgoing", []):
					if graph.get_node(following).get("type") == "Fight":
						first_id = initial
						shop_id = middle
						next_id = following
						break
				if not next_id.is_empty():
					break
			if not next_id.is_empty():
				break
		if next_id.is_empty():
			continue
		eligible_routes += 1
		app.run_seed = seed_value
		app.route_button.pressed.emit()
		await process_frame
		await process_frame
		if app.run_map == null:
			preload("res://tests/party_choice.gd").choose(app)
			await process_frame
			await process_frame
		var fight_button: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == first_id:
				fight_button = button
		if fight_button == null or fight_button.disabled or not fight_button.is_visible_in_tree():
			_check(false, "authentic first Fight route admits playable mounted control")
			return
		fight_button.pressed.emit()
		await process_frame
		await process_frame
		if not app._current_carryover_fight() or app.enemies == null:
			_check(false, "real first battle admission succeeds before Peddler")
			return
		# Settle the prerequisite victory through authoritative enemy HP and
		# the app's real outcome/reward route, not by fabricating reward receipts.
		for enemy in app.enemies.get_enemies():
			_check(app.enemies.apply_damage(enemy.position, 999),
				"authentic enemy model accepts prerequisite victory damage")
		app._observe_battle_result()
		await process_frame
		await process_frame
		if not app._battle_closed or app.fight_rewards == null or app.reward_buttons.size() < 4:
			_check(false, "real Fight reward opens on confirmed enemy defeat")
			return
		app.reward_buttons[3].pressed.emit()
		await process_frame
		if app.continue_button == null:
			_check(false, "genuine reward Skip provides connected Continue")
			return
		app.continue_button.pressed.emit()
		await process_frame
		await process_frame
		var shop_button: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == shop_id:
				shop_button = button
		if shop_button == null or shop_button.disabled:
			_check(false, "genuine post-victory Shop is a connected actionable tile")
			return
		# Same funded boundary as existing mounted Peddler tests: purchase still
		# goes through the real wallet, quote, visit and wardrobe checks.
		app.session_gold = maxi(app.session_gold, 200)
		shop_button.pressed.emit()
		await process_frame
		await process_frame
		if app.peddler_visit == null or app.shop_view == null:
			_check(false, "real Peddler opens with authenticated stock")
			return
		var stock: Dictionary = app.peddler_visit.read_state().stock
		_check(stock.trinkets.size() == 1 and not stock.trinkets[0].id.is_empty(),
			"real Peddler keeps its one authentic patch slot")
		if stock.trinkets[0].id != "shared_hem":
			app._return_to_title()
			await process_frame
			await process_frame
			continue
		var wallet_before: int = app.session_gold
		var rng_before: int = app.run_rng.state
		var carry := app.party_carryover as RunTornCarryover
		_check(stock.trinkets[0].price == 100 and not app.run_trinkets.has("shared_hem")
			and app.peddler_buttons.size() == 4
			and not app.peddler_buttons[3].disabled and carry != null,
			"nonvacuous real Hem offer is 100g, unowned and payable at mounted Peddler")
		app.peddler_heroes.select(1)
		_check(app.run_heroes[1].id == "seamstress",
			"real patch wearer selector targets different living hero")
		app.peddler_buttons[3].pressed.emit()
		await process_frame
		await process_frame
		var wardrobe: RunPatchWardrobe = carry._wardrobe
		_check(app.peddler_visit.is_consumed() and app.peddler_receipt.get("ok", false)
			and app.peddler_receipt.id == "shared_hem"
			and app.session_gold == wallet_before - 100 and app.run_rng.state == rng_before
			and app.run_trinkets.has("shared_hem") and wardrobe != null
			and wardrobe.get_snapshot().worn.seamstress.ARM == "shared_hem"
			and carry.can_bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
			"real Peddler purchase spends exactly 100g and persists canonical sewn ARM")
		var next_button: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == next_id:
				next_button = button
		_check(next_button != null and not next_button.disabled,
			"post-Peddler connected Fight remains actionable")
		if next_button == null:
			return
		next_button.pressed.emit()
		await process_frame
		await process_frame
		var presenter = app.get_node("LiveSupportHand")
		var attack = app.get_node("LiveAttackPreview")
		_check(app._current_carryover_fight() and app.deck.turn_active
			and presenter._heirloom != null and presenter._heirloom.is_current()
			and presenter._heirloom_pinned == attack._pinned
			and presenter._heirloom._wardrobe == wardrobe,
			"next routed battle binds bought Hem to real party and battle Pinned")
		if presenter._heirloom == null:
			return
		if not app.deck.hand.has("warden_brace"):
			app.deck.draw_pile.append("warden_brace")
			_check(app.deck.draw_extra(1) == 1,
				"genuine deck draws authenticated Brace into post-Peddler hand")
			app._refresh_hand()
			await process_frame
			await process_frame
		var brace_panel: Control = null
		for panel in app.hand_view.get_children():
			if panel.get_child_count() > 0 and panel.get_child(0) is Label \
					and panel.get_child(0).text == "warden_brace":
				brace_panel = panel
		_check(brace_panel != null and presenter._bindings.has(brace_panel)
			and app.party.get_hero(1).hp > 0 and app.party.get_hero(2).hp > 0,
			"real mounted held Brace and living different sewn wearer exist")
		if brace_panel == null:
			return
		var before_warden: int = app.party.get_hero(1).block
		var before_seamstress: int = app.party.get_hero(2).block
		var before_energy: int = app.deck.energy
		var before_discard: int = app.deck.discard_pile.count("warden_brace")
		var point := brace_panel.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click, true)
		await process_frame
		await process_frame
		_check(app.party.get_hero(1).block == before_warden + 7
			and app.party.get_hero(2).block == before_seamstress + 1
			and app.deck.energy == before_energy - 1
			and app.deck.discard_pile.count("warden_brace") == before_discard + 1,
			"real post-purchase held Brace pays once and grants exact Hem Block to wearer")
		purchased = true
		break
	_check(purchased, "deterministic connected Peddler seed buys Hem and plays next Fight (%d eligible routes)" % eligible_routes)
	if app.run_map != null:
		app._return_to_title()
		await process_frame


func _test_heirloom_needle() -> void:
	for wearer in ["warden", "seamstress", "tinker"]:
		var f := _heirloom_fixture(wearer)
		var rules: CombatHeirloomPatchTriggers = f.rules
		var foes: CombatEnemies = f.foes
		var pins: CombatPinned = f.pins
		var other := "seamstress" if wearer != "seamstress" else "tinker"
		_check(not rules.quote_needle_hit(wearer, 1).ok,
			"unpinned target gives no Needle quote: " + wearer)
		_check(not rules.quote_needle_hit("impostor", 1).ok
			and not rules.quote_needle_hit(other, 1).ok
			and not rules.quote_needle_hit(wearer, 0).ok,
			"nonwearers and invalid target fail closed: " + wearer)
		_check(pins.pin_enemy(foes, 1, other), "real pinned precondition: " + wearer)
		var pre := foes.get_enemy(1)
		var pin_pre := pins.pinner_for_enemy(1)
		var quote := rules.quote_needle_hit(wearer, 1)
		_check(quote.ok and quote.bonus_damage == 1 and pre.hp > 0 and pin_pre == other,
			"provisional +1 for each wearer's first pinned attack")
		var hit := CombatStatusAttacks.new().resolve_vs_enemy(foes, 1,
			2 + quote.bonus_damage + pins.bonus_for_attack(foes, 1, wearer), {}, {})
		_check(hit.ok and hit.hp_loss > 0 and foes.get_enemy(1).hp < pre.hp,
			"real positive hit reached enemy through status/HP model")
		_check(pins.consume_after_attack(1, wearer, hit.ok),
			"real cross-owner hit consumed Pinned, before Needle finish")
		_check(pins.pinner_for_enemy(1) == "" and rules.finish_needle_hit(quote, hit),
			"confirmed original pin survives consumption for Needle latch")
		_check(not rules.finish_needle_hit(quote, hit)
			and not rules.quote_needle_hit(wearer, 1).ok,
			"replayed and repeated first hit cannot double claim")
		_check(rules.start_player_turn() and pins.pin_enemy(foes, 1, other)
			and rules.quote_needle_hit(wearer, 1).bonus_damage == 1,
			"explicit next turn resets Needle, preserves pin API")

	var f := _heirloom_fixture()
	var rules: CombatHeirloomPatchTriggers = f.rules
	var foes: CombatEnemies = f.foes
	var pins: CombatPinned = f.pins
	_check(pins.pin_enemy(foes, 1, "seamstress"), "pin for non-contact negatives")
	var failed := rules.quote_needle_hit("warden", 1)
	_check(failed.ok and not rules.finish_needle_hit(failed,
		{"ok": false, "damage": 999, "hp_loss": 1, "block_absorbed": 0}),
		"failed play and preview never latch Needle")
	var fake_quote := rules.quote_needle_hit("warden", 1)
	_check(fake_quote.ok and not rules.finish_needle_hit(fake_quote,
		{"ok": true, "damage": 5, "hp_loss": 5, "block_absorbed": 0}),
		"forged positive receipt without enemy model delta cannot latch")
	var zero_quote := rules.quote_needle_hit("warden", 1)
	var zero_hit := CombatStatusAttacks.new().resolve_vs_enemy(foes, 1, 0, {}, {})
	_check(zero_hit.ok and zero_hit.hp_loss == 0 and zero_hit.block_absorbed == 0
		and not rules.finish_needle_hit(zero_quote, zero_hit),
		"successful zero-contact resolution is not a confirmed hit")
	_check(foes.gain_block(1, 25), "real positive enemy Block model setup")
	var block_quote := rules.quote_needle_hit("warden", 1)
	var block_hit := CombatStatusAttacks.new().resolve_vs_enemy(foes, 1,
		3 + block_quote.bonus_damage, {}, {})
	_check(block_hit.ok and block_hit.block_absorbed == 4 and block_hit.hp_loss == 0
		and rules.finish_needle_hit(block_quote, block_hit),
		"positive fully Block-absorbed real hit latches Needle once")
	_check(not rules.finish_needle_hit(block_quote, block_hit),
		"Block-only receipt replay is inert")

	var same := _heirloom_fixture()
	_check(same.pins.pin_enemy(same.foes, 1, "warden"),
		"wearer may legitimately place the target's Pin")
	var self_quote: Dictionary = same.rules.quote_needle_hit("warden", 1)
	var self_hit := CombatStatusAttacks.new().resolve_vs_enemy(same.foes, 1,
		2 + self_quote.bonus_damage, {}, {})
	_check(self_quote.ok and self_hit.ok and self_hit.hp_loss > 0
		and not same.pins.consume_after_attack(1, "warden", true)
		and same.pins.pinner_for_enemy(1) == "warden"
		and same.rules.finish_needle_hit(self_quote, self_hit),
		"same-pinner confirmed hit earns Needle without consuming own Pin")
	var dead := _heirloom_fixture()
	_check(dead.foes.apply_damage(1, 100), "genuine lethal target prerequisite")
	_check(not dead.rules.quote_needle_hit("warden", 1).ok,
		"dead target never quotes Needle")
	_check(dead.party.apply_damage(1, 500), "genuine downed wearer prerequisite")
	_check(not dead.rules.quote_needle_hit("warden", 1).ok,
		"downed attacker never quotes")




## Genuine V3 starter/pool attack metadata, single-hit Block/HP contact and
## the paid red-thread resolver share the original Heirloom authority.
func _test_heirloom_v3_red_thread() -> void:
	var ids := CombatHeirloomPatchTriggers.NEEDLE_V3_RED_THREAD
	_check(ids.size() == 4 and not ids.has("seamstress_v3_scarlet_knot"),
		"four exact V3 attack printings, no status-only Scarlet Knot")
	var first_replay: Dictionary = {}
	for id in ids:
		var service := CombatSeamstressV3RedThreadCards.new()
		var authored: Dictionary = (V3SeamstressStarterCards.new().get_definition(id)
			if id.begins_with("seamstress_v3_thread_prick")
			else V3SeamstressPoolCards.new().get_definition(id))
		_check(service.is_authentic_card(id) and not authored.is_empty()
			and authored.get("effects", {}).get("damage", 0) > 0,
			"authentic starter/pool V3 strike printing: " + id)
		for pinner in ["seamstress", "warden"]:
			var f := _heirloom_fixture("seamstress")
			var rules: CombatHeirloomPatchTriggers = f.rules
			var foes: CombatEnemies = f.foes
			var deck: CombatDeck = f.deck
			_check(deck.combat_state.start_player_turn() and foes.get_enemy(1).hp > 0
				and f.party.get_hero(2).hp > 0 and f.pins.pin_enemy(foes, 1, pinner),
				"nonvacuous V3 attacker, target, active paid deck and real " + pinner + " Pin")
			deck.hand.append(id)
			if pinner == "warden":
				_check(foes.gain_block(1, 40), "real V3 Block-absorbed contact")
			var before := foes.get_enemy(1)
			var rng_before: int = f.rng.state
			var quote: Dictionary = rules.quote_needle_hit("seamstress", 1, id)
			_check(quote.get("ok", false) and quote.get("bonus_damage", 0) == 1
				and rules.authorizes_needle_hit(quote, f.party, foes, id, 1),
				"exact V3 ID authorized before spend: " + id)
			var receipt := service.play_card(deck, f.party, foes, id, 1, rules, quote)
			var after := foes.get_enemy(1)
			var expected: int = int(authored.effects.damage) + 1
			_check(receipt.get("ok", false) and receipt.get("printed_damage") == authored.effects.damage
				and receipt.get("base_damage") == expected and receipt.get("damage") == expected
				and receipt.get("block_absorbed") == mini(before.block, expected)
				and receipt.get("hp_loss") == mini(before.hp, maxi(0, expected - before.block))
				and after.hp == before.hp - receipt.hp_loss
				and after.block == before.block - receipt.block_absorbed,
				"sealed +1 is pre-status raw damage and real Block/HP contact: " + id)
			_check(receipt.get("bleed_applied") == int(authored.effects.bleed) + 1
				and int(after.get("statuses", {}).get("bleed", 0)) == int(before.get("statuses", {}).get("bleed", 0)) + int(authored.effects.bleed) + 1
				and deck.discard_pile.count(id) == 1 and deck.hand.count(id) == 0
				and deck.energy == 2 and f.rng.state == rng_before
				and rules._needle_used and rules._pending_needle.is_empty(),
				"status, one payment, unchanged RNG and once-per-turn latch: " + id)
			_check(not rules.quote_needle_hit("seamstress", 1, id).ok,
				"V3 repeat cannot reclaim spent Needle")
			_check(rules.start_player_turn() and rules.quote_needle_hit("seamstress", 1, id).ok,
				"V3 next player turn re-arms without RNG")
			if pinner == "seamstress":
				_check(f.pins.pinner_for_enemy(1) == "seamstress",
					"same-pinner's real Pin remains assigned")
			var observation := {"receipt": receipt, "after": after, "rng": f.rng.state}
			if pinner == "warden":
				if first_replay.has(id):
					_check(first_replay[id] == observation, "same-seed V3 replay: " + id)
				else:
					first_replay[id] = observation

	for id in ["seamstress_v3_scarlet_knot", "seamstress_v3_scarlet_knot_plus"]:
		var f := _heirloom_fixture("seamstress")
		_check(f.pins.pin_enemy(f.foes, 1, "warden")
			and not f.rules.quote_needle_hit("seamstress", 1, id).ok,
			"authentic status-only Scarlet cannot quote Needle: " + id)
	var invalid := _heirloom_fixture("seamstress")
	_check(invalid.pins.pin_enemy(invalid.foes, 1, "warden"), "stale V3 quote pin prerequisite")
	invalid.deck.combat_state.start_player_turn()
	var id: String = ids[0]
	invalid.deck.hand.append(id)
	_check(not invalid.rules.quote_needle_hit("warden", 1, id).ok
		and not invalid.rules.quote_needle_hit("seamstress", 0, id).ok
		and not invalid.rules.quote_needle_hit("seamstress", 1, "seamstress_v3_fake").ok,
		"wrong owner, slot and forged catalog ID fail before a quote")
	var stale: Dictionary = invalid.rules.quote_needle_hit("seamstress", 1, id)
	_check(stale.ok and invalid.pins.clear_pin(1), "real Pin removed after quote")
	var before_deck := [invalid.deck.hand.duplicate(), invalid.deck.discard_pile.duplicate(),
		invalid.deck.energy, invalid.foes.get_enemies(), invalid.rng.state]
	var refused := CombatSeamstressV3RedThreadCards.new().play_card(invalid.deck,
		invalid.party, invalid.foes, id, 1, invalid.rules, stale)
	_check(not refused.ok and invalid.rules._pending_needle.is_empty()
		and not invalid.rules._needle_used
		and before_deck == [invalid.deck.hand, invalid.deck.discard_pile,
			invalid.deck.energy, invalid.foes.get_enemies(), invalid.rng.state],
		"stale V3 quote cancels with zero card, HP, Block, status, RNG or latch change")
	_check(invalid.pins.pin_enemy(invalid.foes, 1, "warden"), "payment refusal real Pin")
	invalid.deck.combat_state.energy = 0
	var unaffordable: Dictionary = invalid.rules.quote_needle_hit("seamstress", 1, id)
	var unpaid := [invalid.deck.hand.duplicate(), invalid.deck.discard_pile.duplicate(),
		invalid.foes.get_enemies(), invalid.rng.state]
	var no_pay := CombatSeamstressV3RedThreadCards.new().play_card(invalid.deck,
		invalid.party, invalid.foes, id, 1, invalid.rules, unaffordable)
	_check(unaffordable.ok and not no_pay.ok and not invalid.rules._needle_used
		and invalid.rules._pending_needle.is_empty()
		and unpaid == [invalid.deck.hand, invalid.deck.discard_pile,
			invalid.foes.get_enemies(), invalid.rng.state],
		"failed genuine payment cannot spend, injure, bleed, draw RNG or consume latch")
	invalid.deck.combat_state.energy = 3
	var genuine: Dictionary = invalid.rules.quote_needle_hit("seamstress", 1, id)
	var tampered_quote: Dictionary = genuine.duplicate(true)
	tampered_quote["card_id"] = "seamstress_v3_scarlet_knot"
	var immutable := [invalid.deck.hand.duplicate(), invalid.deck.discard_pile.duplicate(),
		invalid.deck.energy, invalid.foes.get_enemies(), invalid.rng.state]
	var forged := CombatSeamstressV3RedThreadCards.new().play_card(invalid.deck,
		invalid.party, invalid.foes, id, 1, invalid.rules, tampered_quote)
	_check(genuine.ok and not forged.ok and not invalid.rules._needle_used
		and invalid.rules._pending_needle.is_empty()
		and immutable == [invalid.deck.hand, invalid.deck.discard_pile,
			invalid.deck.energy, invalid.foes.get_enemies(), invalid.rng.state],
		"tampered Scarlet-claim quote is refused atomically before red-thread payment")
	var altered := CombatSeamstressV3RedThreadCards.new()._catalog_definition(id)
	altered["effects"]["damage"] = int(altered.effects.damage) + 20
	_check(not CombatSeamstressV3RedThreadCards.new()._authentic(
		altered, id, CombatSeamstressV3RedThreadCards.CARDS[id]),
		"forged printed damage cannot authenticate as the genuine V3 catalog line")
	var no_pin := _heirloom_fixture("seamstress")
	var wrong_wearer := _heirloom_fixture("warden")
	var dead := _heirloom_fixture("seamstress")
	_check(not no_pin.rules.quote_needle_hit("seamstress", 1, id).ok
		and wrong_wearer.pins.pin_enemy(wrong_wearer.foes, 1, "warden")
		and not wrong_wearer.rules.quote_needle_hit("seamstress", 1, id).ok,
		"unpinned V3 target and genuinely wrong sewn wearer cannot quote")
	_check(dead.foes.apply_damage(1, 100)
		and not dead.rules.quote_needle_hit("seamstress", 1, id).ok,
		"dead original enemy cannot receive V3 Needle entitlement")
	var torn_v3 := _heirloom_fixture("seamstress")
	var torn_before: Dictionary = torn_v3.torn.read_state()
	var torn_after: Array = torn_before.heroes.duplicate(true)
	torn_after[1]["hp"] = 0
	_check(torn_v3.torn.observe_battle_end("v3-torn", torn_before.heroes, torn_after).ok
		and not torn_v3.rules.is_current()
		and not torn_v3.rules.quote_needle_hit("seamstress", 1, id).ok,
		"genuine torn Seamstress ledger cancels V3 Needle authority")


func _test_heirloom_hem() -> void:
	for wearer in ["warden", "seamstress", "tinker"]:
		var f := _heirloom_fixture("warden", wearer)
		var rules: CombatHeirloomPatchTriggers = f.rules
		var party: CombatParty = f.party
		var source := "warden" if wearer != "warden" else "tinker"
		var source_position := 1 if source == "warden" else 3
		var wearer_position := 1 if wearer == "warden" else (2 if wearer == "seamstress" else 3)
		_check(not rules.begin_block_gain(wearer).ok
			and not rules.begin_block_gain("outsider").ok,
			"self-gain and unknown source never quote Hem: " + wearer)
		var zero := rules.begin_block_gain(source)
		_check(zero.ok and party.gain_block(source_position, 0)
			and rules.finish_block_gain(zero) == 0,
			"real zero Block gain never awards Hem")
		var quote := rules.begin_block_gain(source)
		var before := party.get_hero(source_position)
		var wearer_before := party.get_hero(wearer_position)
		_check(quote.ok and before.hp > 0 and wearer_before.hp > 0,
			"both live real party actors required for block observation")
		_check(party.gain_block(source_position, 3)
			and party.get_hero(source_position).block == before.block + 3,
			"source truly receives positive model Block")
		_check(rules.finish_block_gain(quote) == 1
			and party.get_hero(wearer_position).block == wearer_before.block + 1,
			"Hem grants exactly +1 through living wearer's model")
		_check(rules.finish_block_gain(quote) == 0
			and not rules.begin_block_gain(source).ok,
			"Hem replay and same-turn second grant both inert")
		_check(party.start_player_turn() and rules.start_player_turn(),
			"real party Block and heirloom turn reset")
		var next := rules.begin_block_gain(source)
		_check(next.ok and party.gain_block(source_position, 2)
			and rules.finish_block_gain(next) == 1
			and party.get_hero(wearer_position).block == 1,
			"next turn Hem can grant once again")

	var f := _heirloom_fixture()
	var rules: CombatHeirloomPatchTriggers = f.rules
	var party: CombatParty = f.party
	var stale := rules.begin_block_gain("tinker")
	_check(stale.ok and rules.start_player_turn() and party.gain_block(3, 1)
		and rules.finish_block_gain(stale) == 0,
		"old-turn pending Block observation cannot replay")
	var downed := rules.begin_block_gain("tinker")
	_check(downed.ok and party.apply_damage(3, 500)
		and rules.finish_block_gain(downed) == 0,
		"source downed during observation earns nothing")
	_check(party.apply_damage(2, 500), "down genuine Hem wearer")
	_check(not rules.begin_block_gain("warden").ok,
		"dead Hem wearer cannot quote or receive grant")




func _test_heirloom_binding_and_immutability() -> void:
	var f := _heirloom_fixture()
	var rules: CombatHeirloomPatchTriggers = f.rules
	var wardrobe: RunPatchWardrobe = f.wardrobe
	var torn: RunTornMending = f.torn
	var party: CombatParty = f.party
	var foes: CombatEnemies = f.foes
	var pins: CombatPinned = f.pins
	var rng: RandomNumberGenerator = f.rng
	var deck: CombatDeck = f.deck
	var money_before := wardrobe.get_snapshot()
	var deck_before := {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy}
	var seed_before := rng.state
	_check(pins.pin_enemy(foes, 1, "tinker"), "pin preserved across rebind")
	var pin_before := pins.pinner_for_enemy(1)
	var pending := rules.quote_needle_hit("warden", 1)
	_check(pending.ok and rules.bind_battle(wardrobe, torn, party, foes, pins)
		and rules.start_player_turn() and not rules.finish_needle_hit(pending,
			{"ok": true, "damage": 1, "hp_loss": 1, "block_absorbed": 0}),
		"rebinding cancels older Needle receipt and restores fresh entitlement")
	_check(rules.quote_needle_hit("warden", 1).bonus_damage == 1,
		"new bind restores Needle exactly once")
	_check(rules.begin_block_gain("warden").ok,
		"new bind restores unused Hem entitlement")
	_check(money_before == wardrobe.get_snapshot() and rng.state == seed_before
		and pin_before == pins.pinner_for_enemy(1)
		and deck_before == {"draw": deck.draw_pile, "hand": deck.hand,
			"discard": deck.discard_pile, "energy": deck.energy},
		"binding, quote, resets and rejected replay preserve gold, scraps, run deck, Pinned and RNG")

	var stale_quote := rules.quote_needle_hit("warden", 1)
	var prior := wardrobe.get_snapshot()
	_check(wardrobe.refresh_run_context(prior.heroes, prior.owned,
		prior.scraps, prior.gold + 1, prior.cards, prior),
		"genuine run receipt refresh invalidates bound wardrobe")
	_check(not rules.is_current() and not rules.finish_needle_hit(stale_quote,
		{"ok": true, "damage": 1, "hp_loss": 1, "block_absorbed": 0})
		and not rules.begin_block_gain("tinker").ok,
		"stale wardrobe refuses all receipts and no free power")
	_check(not rules.bind_battle(null, torn, party, foes, pins)
		and not rules.quote_needle_hit("warden", 1).ok,
		"failed rebind clears all prior authority")

	var torn_f := _heirloom_fixture()
	var torn_state: Dictionary = torn_f.torn.read_state()
	var ending: Array = torn_state.heroes.duplicate(true)
	ending[1]["hp"] = 0
	_check(torn_f.torn.observe_battle_end("authentic-down", torn_state.heroes, ending).ok,
		"actual torn ledger combat-end receipt downed a wearer")
	_check(not torn_f.rules.is_current()
		and not torn_f.rules.begin_block_gain("warden").ok,
		"stale torn snapshot refuses without mutation")
	var new_state: Dictionary = torn_f.torn.read_state()
	var wbefore: Dictionary = torn_f.wardrobe.get_snapshot()
	_check(torn_f.wardrobe.refresh_run_context(new_state.heroes, wbefore.owned,
		wbefore.scraps, wbefore.gold, wbefore.cards, wbefore),
		"authentic wardrobe refresh reconciles torn record")
	var reconciled_party := CombatParty.new(new_state.heroes)
	_check(reconciled_party.is_valid() and torn_f.rules.bind_battle(torn_f.wardrobe, torn_f.torn,
		reconciled_party, torn_f.foes, torn_f.pins) and torn_f.rules.start_player_turn()
		and not torn_f.rules.begin_block_gain("warden").ok,
		"rebinding torn wearer remains inactive, even if combat party still has HP")
	var wrong := RunPatchWardrobe.new(party.get_heroes(), ["needle_echo"],
		[{"id": "needle_echo", "slot": "ARM"}], 2)
	_check(wrong.is_valid() and wrong.sew("needle_echo", "warden", "ARM",
		"wrong", wrong.get_snapshot()).ok, "nonvacuous incorrectly slotted wardrobe")
	_check(not rules.bind_battle(wrong, torn, party, foes, pins),
		"authored wrong-slot equipment fails closed at binding")

	var outsider := RunV3PartyAdmission.admit(["warden", "tinker", "rag_duelist"])
	_check(outsider.ok, "independently admitted alternative V3 trio")
	var other_party := CombatParty.new(outsider.party)
	_check(other_party.is_valid() and not rules.bind_battle(
		wardrobe, torn, other_party, foes, pins),
		"different valid party cannot reuse unrelated wardrobe and torn ledger")

## The real app path, not a detached visit: completed-run unlock -> chosen
## Fight -> earned route -> one seeded Peddler -> chosen HEAD wearer. Exercise
## physical mouse and number-4 inputs against the mounted quote and sewing
## bridge, including stale/replay refusals and unchanged seeded RNG.
func _test_routed_needle_echo_purchase(app) -> void:
	_check(app.heirloom_unlocked and app.run_map == null and app.deck == null,
		"Needle Echo app witness starts at completed-run-unlocked title")
	for keyboard in [false, true]:
		var purchased := false
		var eligible_routes := 0
		for seed_value in range(1, 4000):
			var graph := RunMap.new()
			var graph_rng := RandomNumberGenerator.new()
			graph_rng.seed = seed_value
			graph.generate(graph_rng)
			var first_id := ""
			var shop_id := ""
			for initial in graph.get_legal_choices():
				if graph.get_node(initial).get("type") != "Fight":
					continue
				for middle in graph.get_node(initial).get("outgoing", []):
					if graph.get_node(middle).get("type") == "Shop":
						first_id = initial
						shop_id = middle
						break
				if not shop_id.is_empty():
					break
			if shop_id.is_empty():
				continue
			eligible_routes += 1
			app.run_seed = seed_value
			app.route_button.pressed.emit()
			await process_frame
			await process_frame
			if app.run_map == null:
				preload("res://tests/party_choice.gd").choose(app)
				await process_frame
				await process_frame
			var fight_button: Button = null
			for button in app.route_buttons:
				if button.get_meta("route_id") == first_id:
					fight_button = button
			_check(fight_button != null and not fight_button.disabled,
				"Needle witness enters genuinely connected first Fight")
			if fight_button == null:
				return
			fight_button.pressed.emit()
			await process_frame
			await process_frame
			_check(app._current_carryover_fight() and app.enemies != null,
				"Needle witness has a real mounted combat before Peddler")
			if app.enemies == null:
				return
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 999),
					"Needle route prerequisite fight resolves via real enemy ledger")
			app._observe_battle_result()
			await process_frame
			await process_frame
			_check(app._battle_closed and app.fight_rewards != null
				and app.reward_buttons.size() >= 4,
				"Needle route prerequisite opens legitimate victory rewards")
			if app.reward_buttons.size() < 4:
				return
			app.reward_buttons[3].pressed.emit()
			await process_frame
			_check(app.continue_button != null,
				"Needle route reward Skip legitimately continues")
			if app.continue_button == null:
				return
			app.continue_button.pressed.emit()
			await process_frame
			await process_frame
			var shop_button: Button = null
			for button in app.route_buttons:
				if button.get_meta("route_id") == shop_id:
					shop_button = button
			_check(shop_button != null and not shop_button.disabled,
				"Needle route enters a genuinely connected Shop tile")
			if shop_button == null:
				return
			app.session_gold = maxi(app.session_gold, 200)
			shop_button.pressed.emit()
			await process_frame
			await process_frame
			_check(app.peddler_visit != null and app.shop_view is LivePeddlerPanel
				and app.peddler_visit.is_open(),
				"Needle witness reaches live bound Peddler from app map")
			if app.peddler_visit == null or not app.peddler_visit.is_open():
				return
			var offered: Dictionary = app.peddler_visit.read_state()
			_check(offered.stock.trinkets.size() == 1,
				"live Peddler keeps its single patch slot")
			if offered.stock.trinkets[0].id != "needle_echo":
				app._return_to_title()
				await process_frame
				await process_frame
				continue
			var panel := app.shop_view as LivePeddlerPanel
			var wallet_before: int = app.session_gold
			var rng_before: int = app.run_rng.state
			var deck_before: Array = app.run_deck.duplicate(true)
			var owned_before: Array = app.run_trinkets.duplicate(true)
			var carry := app.party_carryover as RunTornCarryover
			var wardrobe: RunPatchWardrobe = app._peddler_wardrobe
			_check(wardrobe != null and wardrobe.is_valid(),
				"live Peddler has a real preflight sewing wardrobe")
			if wardrobe == null:
				return
			var sewn_before := wardrobe.get_snapshot()
			_check(offered.stock.trinkets[0].price == 100 and wallet_before >= 100
				and not owned_before.has("needle_echo")
				and panel.patch_button.get_meta("offer_id") == "needle_echo"
				and not panel.patch_button.disabled
				and panel.patch_button.text.contains("HEAD")
				and panel.patch_button.text.contains("100 gold")
				and panel.patch_button.tooltip_text.contains(LivePeddlerPanel.NEEDLE_ECHO_FULL),
				"live unlocked Peddler actually displays payable HEAD Needle +1 trigger")
			app.peddler_heroes.select(2)
			_check(app.peddler_heroes.selected == 2
				and app.peddler_heroes.get_item_metadata(2) == app.run_heroes[2].id
				and sewn_before.worn[app.run_heroes[2].id]["HEAD"] == "",
				"real wearer selector chooses an empty HEAD slot on third living hero")
			if keyboard:
				for down in [true, false]:
					var key_event := InputEventKey.new()
					key_event.keycode = KEY_4
					key_event.pressed = down
					root.push_input(key_event)
					await process_frame
			else:
				var point := panel.patch_button.get_global_rect().get_center()
				var motion := InputEventMouseMotion.new()
				motion.position = point
				root.push_input(motion, true)
				await process_frame
				for down in [true, false]:
					var click := InputEventMouseButton.new()
					click.button_index = MOUSE_BUTTON_LEFT
					click.position = point
					click.pressed = down
					root.push_input(click, true)
					await process_frame
			await process_frame
			await process_frame
			var sewn: Dictionary = wardrobe.get_snapshot()
			_check(app.peddler_visit.is_consumed() and app.peddler_receipt.get("ok") == true
				and app.peddler_receipt.id == "needle_echo" and app.peddler_receipt.price == 100
				and app.session_gold == wallet_before - 100
				and app.run_trinkets.has("needle_echo")
				and app.run_trinkets.size() == owned_before.size() + 1
				and sewn.worn[app.run_heroes[2].id]["HEAD"] == "needle_echo"
				and sewn.gold == app.session_gold and sewn.owned == app.run_trinkets
				and app.run_deck == deck_before and app.run_rng.state == rng_before
				and carry._wardrobe == wardrobe
				and carry.can_bind_wardrobe(wardrobe, carry.torn, sewn),
				"live mouse/key-4 settles one 100g HEAD purchase and durable selected wearer")
			var paid_state: Dictionary = app.peddler_visit.read_state()
			_check(not app.peddler_visit.choose_purchase(offered.node_id,
				offered.state, offered.stock, "trinket", "needle_echo").ok
				and not app.peddler_visit.leave(offered.node_id, offered.state, offered.stock).ok
				and app.peddler_visit.read_state() == paid_state
				and wardrobe.get_snapshot() == sewn
				and app.session_gold == wallet_before - 100
				and app.run_rng.state == rng_before,
				"stale buy/replay and post-buy Leave cannot double-spend or alter wardrobe/RNG")
			purchased = true
			app._return_to_title()
			await process_frame
			await process_frame
			break
		_check(purchased, "real routed Needle Echo %s purchase sews once (%d eligible routes)"
			% ["key-4" if keyboard else "mouse", eligible_routes])
	_check(app.run_map == null and app.heirloom_unlocked,
		"both Needle Echo mounted purchase routes return to unlocked title")
