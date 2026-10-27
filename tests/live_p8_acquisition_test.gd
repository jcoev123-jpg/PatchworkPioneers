extends "res://tests/live_elite_patch_sewing_test.gd"
## Real full-catalog visits, paid acquisition/sewing and mounted committed casts.
## As in the existing funded Shop fixtures, stage gold/owned authored cards before
## Continue freezes the route context. Select a reproducible run-RNG state before
## the stock boundary; never inject a stock, hit, drop, receipt or successful play.


func _rare_state(patch_id: String, elite: bool) -> int:
	var owners: Array[String] = []
	for hero in app.run_heroes:
		owners.append(hero.id)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	for value in range(1, 10000):
		var candidate := RandomNumberGenerator.new()
		candidate.seed = value
		var initial := candidate.state
		if elite:
			candidate.randi_range(25, 35)
			RunPoolCardRewardOffers.generate_for_living(candidate, owners, owners,
				app._reward_candidate_records(owners))
			var ids: Array = app._catalog_trinket_ids()
			ids.sort()
			# Independent ticket expansion, using the complete shipped pool.
			var tickets: Array[String] = []
			for id in ids:
				for ticket in range(10 if id in ["relay_bobbin", "hearth_lining"] else 100):
					tickets.append(id)
			if not tickets.is_empty() and tickets[candidate.randi_range(0, tickets.size() - 1)] == patch_id:
				return initial
		else:
			var generated := RunShopStockOffers.generate_peddler_stock(candidate, owners,
				source.cards, source.trinkets, [])
			if generated.ok and generated.patches[0].id == patch_id:
				return initial
	return -1


func _draw_owned(ids: Array) -> bool:
	for id in ids:
		while not app.deck.hand.has(id) and not app.deck.draw_pile.is_empty():
			_check(app.deck.draw_extra(1) == 1, "draw an actual owned card")
		_check(app.deck.hand.has(id), "P8 real deck holds " + id)
		if not app.deck.hand.has(id):
			return false
	app._refresh_hand()
	await _frames()
	return true


func _p8_attack(id: String, position: int) -> void:
	_check(await _choose(id, true), "P8 keyboard selects held " + id)
	await _key(KEY_1 + position - 1)
	_check(presenter.last_event.get("ok", false), "P8 real resolver confirms " + id)


func _p8_combat(patch_id: String, wearer: String) -> Array:
	var carry := app.party_carryover as RunTornCarryover
	_check(app.deck != null and not app._battle_closed and carry != null,
		"P8 acquisition continued into actual live Fight")
	if app.deck == null or carry == null:
		return []
	var wardrobe: RunPatchWardrobe = carry._wardrobe
	var slot := "HEAD" if patch_id == "relay_bobbin" else "COAT"
	_check(wardrobe != null and wardrobe.get_snapshot().worn[wearer][slot] == patch_id,
		"P8 purchased assignment reaches the equipped battle wearer")
	if wardrobe == null:
		return []
	var rng_before: int = app.run_rng.state
	if patch_id == "relay_bobbin":
		if not await _draw_owned(["tinker_spring_trap", "warden_brass_buckle"]):
			return []
		_check(presenter._pinned._wardrobe == wardrobe, "Relay binds actual carried wardrobe")
		var target := 1
		for foe in app.enemies.get_enemies():
			if foe.hp > app.enemies.get_enemy(target).hp:
				target = foe.position
		var opening_energy: int = app.deck.energy
		await _p8_attack("tinker_spring_trap", target)
		_check(presenter._pinned.pinner_for_enemy(target) == "tinker"
			and app.deck.energy == opening_energy - 1, "actual paid wearer card places its token")
		var energy: int = app.deck.energy
		var count: int = app.deck.discard_pile.count("warden_brass_buckle")
		_check(await _choose("warden_brass_buckle", true), "real cross-owner forecast")
		_check(app.deck.energy == energy and not presenter._pinned._relay_used,
			"preview awards no shared energy")
		await _key(KEY_1 + target - 1)
		_check(presenter.last_event.ok and app.deck.energy == energy
			and app.deck.discard_pile.count("warden_brass_buckle") == count + 1
			and presenter._pinned._relay_used and presenter._pinned.pinner_for_enemy(target) == "",
			"confirmed paid cross-hero cast consumes actual token and refunds exactly one energy")
		var settled: int = app.deck.energy
		_check(not presenter._pinned.finish_confirmed_cast(presenter.last_event)
			and app.deck.energy == settled, "duplicate real receipt cannot refund again")
	else:
		if not await _draw_owned(["warden_brace", "seamstress_prick", "tinker_pop_shot"]):
			return []
		var quilt: CombatQuiltBonus = app._quilt_bonus
		_check(quilt._hearth_wardrobe == wardrobe, "Hearth binds actual carried wardrobe")
		var position := 0
		for hero in app.party.get_heroes():
			if hero.id == wearer:
				position = hero.position
		_check(position > 0 and app.party.heal(position, 999)
			and app.party.apply_damage(position, app.party.get_hero(position).block + 1)
			and app.party.get_hero(position).hp == app.party.get_hero(position).max_hp - 1,
			"wound real living wearer for capped heal")
		var hp: int = app.party.get_hero(position).hp
		app._refresh_hand()
		_check(app.party.get_hero(position).hp == hp and not quilt._hearth_used,
			"passive refresh cannot simulate an earned Quilt")
		var brace
		for panel in app.hand_view.get_children():
			if panel.get_child(0).text == "warden_brace":
				brace = panel
		_check(brace != null, "held Warden support panel exists")
		if brace == null:
			return []
		brace.grab_focus()
		await _key(KEY_ENTER)
		await _p8_attack("seamstress_prick", 1)
		_check(app.party.get_hero(position).hp == hp and not quilt._hearth_used,
			"two committed owners do not earn Quilt or Hearth")
		await _p8_attack("tinker_pop_shot", 2)
		_check(quilt.get_patch_progress().awarded and quilt._hearth_used
			and app.party.get_hero(position).hp == mini(app.party.get_hero(position).max_hp, hp + 2),
			"third actual paid owner earns Quilt and heals only wearer to capped HP")
		var healed: int = app.party.get_hero(position).hp
		app._refresh_hand()
		_check(app.party.get_hero(position).hp == healed, "duplicate refresh does not heal again")
		_check(app.run_rng.state == rng_before, "Hearth committed cards consume no RNG")
		await _click(app.end_turn_button)
		_check(app._quilt_bonus == quilt and quilt._hearth_used
			and not quilt.get_patch_progress().awarded, "real next turn keeps Hearth spent while refreshing Quilt")
	if patch_id == "relay_bobbin":
		_check(app.run_rng.state == rng_before, "Relay committed cards consume no RNG")
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.energy,
		app.deck.hand.duplicate(), app.deck.discard_pile.duplicate()]


func _acquire(patch_id: String, elite: bool) -> Array:
	var fixture: Dictionary = _attack_fixture(1, 30000) if elite else _continuation_fixture("Fight", 1, 30000)
	_check(not fixture.is_empty(), "genuine connected acquisition-to-Fight topology exists")
	if fixture.is_empty() or not await _routed_win(fixture, false):
		return []
	await _click(app.reward_buttons[3])
	# Existing funded/owned-card fixture convention, before route admission.
	app.session_gold = 200
	app.run_deck.append_array(["tinker_spring_trap", "warden_brass_buckle"])
	var state := _rare_state(patch_id, elite)
	_check(state != -1, "bounded reproducible full-pool rare draw exists")
	if state == -1:
		return []
	if not elite:
		app.run_rng.state = state
	await _click(app.continue_button)
	var wearer := "tinker" if patch_id == "relay_bobbin" else "warden"
	if elite:
		var path: Array = fixture.paths[0].duplicate()
		var node: String = path.pop_back()
		await _visit_path(path, false)
		await _click(_route_action(node))
		_check(app.enemies != null and not app._battle_closed, "actual Elite source battle admitted")
		app.run_rng.state = state
		for enemy in app.enemies.get_enemies():
			_check(app.enemies.apply_damage(enemy.position, 9999), "defeat actual Elite source roster")
		app._observe_battle_result()
		await _frames()
		_check(app.fight_reward_trinket == patch_id, "full production Elite pool actually rolled P8")
		if app.fight_reward_trinket != patch_id:
			return []
		await _click(app.reward_buttons[3])
		var target: Button
		for button in sewing.hero_buttons:
			if button.get_meta("hero_id") == wearer:
				target = button
		_check(target != null and not target.disabled, "actual P8 Elite wearer is enabled")
		if target == null:
			return []
		await _click(target)
		await _click(app.continue_button)
		var next: Array = _path_to(app.run_map, node, "Fight")
		_check(not next.is_empty(), "sewn Elite drop has a connected next Fight")
		var fight: String = next.pop_back()
		await _visit_path(next, false)
		await _click(_route_action(fight))
	else:
		await _click(_route_action(fixture.shop))
		_check(app.peddler_visit != null and app.shop_view is LivePeddlerPanel,
			"actual Peddler panel and visit mounted")
		if app.peddler_visit == null:
			return []
		var stock: Dictionary = app.peddler_visit.read_state().stock
		_check(stock.cards.size() == 3 and stock.trinkets.size() == 1
			and stock.trinkets[0].id == patch_id and stock.trinkets[0].price == 100,
			"P8 competes for the sole existing Peddler slot at 100 gold")
		var index := -1
		for i in range(app.run_heroes.size()):
			if app.run_heroes[i].id == wearer:
				index = i
		_check(index >= 0, "P8 chosen wearer is in actual party")
		app.peddler_heroes.select(index)
		var gold: int = app.session_gold
		await _click(app.peddler_buttons[3])
		_check(app.peddler_receipt.get("id") == patch_id and app.session_gold == gold - 100
			and app.run_trinkets.has(patch_id), "actual Peddler receipt pays exact rare quote")
		await _click(_route_action(fixture.next))
	var result := await _p8_combat(patch_id, wearer)
	await _click(app.return_button)
	_check(app._quilt_bonus == null and presenter._pinned == null, "title clears both combat authorities")
	return result


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	sewing = app.get_node("LiveElitePatchSewing")
	for elite in [false, true]:
		for patch_id in ["relay_bobbin", "hearth_lining"]:
			var first := await _acquire(patch_id, elite)
			var replay := await _acquire(patch_id, elite)
			_check(not first.is_empty() and first == replay, "P8 mounted acquisition and combat replay exactly")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_p8_acquisition_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
