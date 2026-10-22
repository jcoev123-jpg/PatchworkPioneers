extends "res://tests/live_shop_patch_sewing_test.gd"
## Real Shop sewing -> routed Fight -> physical held Mend input.


func _support_state() -> Array:
	return [app.party.get_heroes(), app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.run_rng.state, app.run_heroes.duplicate(true), app.run_deck.duplicate(),
		app.run_trinkets.duplicate(), app.session_gold, app.run_scraps,
		wardrobe.get_snapshot(), app.party_carryover.torn.read_state()]


func _held_mend() -> Control:
	# Use deck APIs to expose the actual held instance without manufacturing a card
	# or overflowing the mounted hand. No enemy phase is needed for this fixture.
	for attempt in range(40):
		for panel in app.hand_view.get_children():
			if panel.get_child(0).text == "seamstress_mend":
				return panel
		for id in app.deck.hand.duplicate():
			_check(app.deck.discard_played(id), "fixture discards through real deck API")
		_check(app.deck.draw_extra(5) > 0, "fixture draws actual shuffled cards")
		app._refresh_hand()
		await _frames()
	_check(false, "real deck contains held Mend")
	return null


func _meter() -> void:
	for index in range(3):
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(app.hero_panels[index].get_child(0).text == "%d - %s\nHP: %d/%d | Block: %d%s" % [
			hero.position, hero.name, hero.hp, hero.max_hp, hero.block,
			"\nDOWNED" if hero.hp == 0 else ""], "actual visible hero meter matches HP")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"actual visible pile counts match")


func _mend(keyboard: bool, amount: int, damage: int = 12, reject: bool = false) -> void:
	var panel := await _held_mend()
	if panel == null:
		return
	_check(app.party.apply_damage(3, damage), "living target takes genuine damage")
	_check(app.party.get_hero(3).hp > 0, "wounded target remains alive")
	app._refresh_party()
	await _frames()
	var before := _support_state()
	await _activate(panel, keyboard)
	var support = app.get_node("LiveSupportHand")
	if not app.party.is_downed(2):
		_check(support._pending.get("choosing", false), "physical held Mend opens living ally controls")
		await _activate(app.hero_panels[2], keyboard)
	if reject:
		_check(_support_state() == before, "rejected Mend preserves HP, all piles, wallet, wardrobe and RNG")
	else:
		var expected := before.duplicate(true)
		expected[0][2].hp = mini(expected[0][2].max_hp, expected[0][2].hp + amount)
		expected[1].erase("seamstress_mend")
		expected[3].append("seamstress_mend")
		expected[4] -= 1
		_check(_support_state() == expected, "Mend heals %d capped HP, charges/discards once, preserves every run ledger and RNG" % amount)
		_check(support.energy_label.text == "Energy\n%d" % app.deck.energy, "visible energy matches one charge")
	_meter()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := {}
	var spool := -1
	var next_seed := 1
	for attempt in range(20):
		fixture = _sequence_fixture(["Shop", "Fight", "Fight"], next_seed, true)
		_check(not fixture.is_empty(), "genuine map has Shop and two connected Fights")
		if fixture.is_empty() or not await _routed_win(fixture, false):
			await _finish_patches()
			return
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		app.session_gold = 500
		await _reach(fixture.paths[0], false)
		for i in range(app.shop_patch_offers.item_count):
			if app.shop_purchases.get_stock().trinkets[i].id == "spare_spool":
				spool = i
		next_seed = fixture.seed + 1
		await _click(app.shop_back_button)
		if spool >= 0:
			break
	_check(spool >= 0, "real generated Shop stocks Spare Spool")
	if spool < 0:
		await _finish_patches()
		return
	var retired: Callable
	for mode in ["seamstress", "warden", "no_purchase", "unsewn", "bad_binding"]:
		var replay: Array = []
		for keyboard in [false, true]:
			seed(110110)
			var global_next := randi()
			seed(110110)
			if not await _routed_win(fixture, false):
				break
			await _activate(app.reward_buttons[3], keyboard)
			await _activate(app.continue_button, keyboard)
			app.session_gold = 500
			await _reach(fixture.paths[0], keyboard)
			wardrobe = app._shop_wardrobe
			if mode != "no_purchase":
				await _purchase(spool, keyboard, 0 if mode == "warden" else 1)
			if mode == "unsewn":
				# Own the genuine purchased item but leave its slot empty.
				wardrobe._worn.seamstress.ARM = ""
				_check(wardrobe.get_snapshot().owned.has("spare_spool")
					and wardrobe.project_active(app.party_carryover.torn.read_state()).active.seamstress.is_empty(),
					"owned unsewn fixture has no active Spool")
			await _activate(app.shop_continue_button, keyboard)
			await _reach(fixture.paths[1], keyboard)
			var support = app.get_node("LiveSupportHand")
			_check(app.party != null and app.round_flow._started and app._current_carryover_fight(), "real authoritative routed Fight is running")
			_check(app.party_carryover._wardrobe == (null if mode == "no_purchase" else wardrobe),
				"Fight uses genuine purchased wardrobe or absent legacy binding")
			var adapter = support._play
			var panel := await _held_mend()
			if retired.is_valid():
				var state := _support_state()
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = true
				retired.call(event)
				await _frames()
				_check(_support_state() == state, "retired prior battle/run control cannot mutate current state")
			retired = support._bindings[panel]
			if mode == "bad_binding":
				# Drift after admission: frame updates must not silently rebind it.
				wardrobe._gold += 1
				await _frames()
				_check(support._play == adapter, "frame sync retains the original combat binding")
			await _mend(keyboard, 7 if mode == "seamstress" else 5, 12, mode == "bad_binding")
			var trace := [_support_state()]
			if mode == "bad_binding":
				wardrobe._gold -= 1
				_check(not support._play.bind_patch_wardrobe(null, null), "invalid explicit adapter binding fails")
				await _mend(keyboard, 0, 1, true)
			else:
				app.deck.energy = 3
				# Bring target to full HP then wound by two: bonus must cap.
				_check(app.party.heal(3, 999), "full HP fixture uses party API")
				await _mend(keyboard, 7 if mode == "seamstress" else 5, 2)
			await _settle_battle(keyboard, 2 if mode == "seamstress" else 0)
			await _activate(app.continue_button, keyboard)
			await _reach(fixture.paths[2], keyboard)
			_check(support._play != adapter, "second connected Fight receives a fresh adapter")
			if mode == "seamstress":
				_check(app.party.is_downed(2) and wardrobe.project_active(app.party_carryover.torn.read_state()).active.seamstress.is_empty(), "genuinely torn downed owner has no active patch")
				await _mend(keyboard, 0, 1, true)
			else:
				await _mend(keyboard, 7 if mode == "bad_binding" else 5, 12)
			trace.append(_support_state())
			if keyboard:
				_check(trace == replay, "same seed mouse/keyboard replay matches full combat, ledgers and RNG")
			else:
				replay = trace
			_check(randi() == global_next, "route, support, rejection and replay consume no global RNG")
			await _activate(app.return_button, keyboard)
			_check(app.party_carryover == null and app.deck == null and support._play == null,
				"return/restart clears prior run authority and support binding")
	await _finish_patches()


func _finish_patches() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_spare_spool_support_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
