extends "res://tests/live_rest_stitch_choice_test.gd"

func _guided_fixture() -> Dictionary:
	for value in range(1, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			var elite := _path_to(map, fight, "Elite")
			if elite.is_empty():
				continue
			var rest := _path_to(map, elite.back(), "Rest")
			if rest.is_empty():
				continue
			var later := _path_to(map, rest.back(), "Rest")
			if later.is_empty():
				continue
			map.choose_node(fight)
			var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
			map.undo_choice(fight, [])
			if selected.get("encounter_id") == "starter_attacks":
				return {"seed": value, "fight": fight, "elite": elite, "rest_path": rest, "later_rest": later}
	return {}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _guided_fixture()
	_check(not fixture.is_empty(), "seeded Fight -> Elite -> Rest fixture exists")
	if fixture.is_empty():
		await _finish_guided()
		return
	var replay: Array = []
	var retained: Callable
	for session in range(7):
		seed(820082)
		var global_next := randi()
		seed(820082)
		if not await _routed_win(fixture, false):
			break
		_check(app.run_scraps == 0 and app.run_stitch_descriptors.is_empty() and app.run_next_stitch_id == 1, "new run has no free scraps or descriptors")
		var claim: Callable = app.reward_buttons[3].pressed.get_connections()[0].callable
		var rng_before: int = app.run_rng.state
		await _click(app.reward_buttons[3])
		_check(app.run_scraps == 1 and app.run_rng.state == rng_before, "opening Fight Skip awards exactly one scrap without RNG")
		claim.call()
		app._observe_battle_result()
		_check(app.run_scraps == 1, "duplicate claim and observation cannot mint scraps")
		await _click(app.continue_button)
		var path: Array = fixture.elite.duplicate()
		var elite: String = path.pop_back()
		await _visit_path(path, false)
		await _click(_route_action(elite))
		_check(app.run_map.get_current_node_id() == elite and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE, "actual routed Elite mounted")
		for enemy in app.enemies.get_enemies():
			_check(app.enemies.apply_damage(enemy.position, 9999), "defeat real Elite actor")
		app._observe_battle_result()
		await _frames()
		_check(app.reward_buttons.size() == 4 and app.multi_fight_rewards != null, "Elite reward controls exist")
		if app.reward_buttons.size() != 4:
			break
		rng_before = app.run_rng.state
		claim = app.reward_buttons[3].pressed.get_connections()[0].callable
		await _click(app.reward_buttons[3])
		_check(app.run_scraps == 3 and app.run_rng.state == rng_before, "Elite Skip adds exactly two scraps without RNG")
		claim.call()
		_check(app.run_scraps == 3, "duplicate Elite claim inert")

		if session == 6:
			var sewing = app.get_node("LiveElitePatchSewing")
			_check(sewing.hero_buttons.size() == 3, "real Elite drop can be sewn")
			await _click(sewing.hero_buttons[0])
		await _click(app.continue_button)
		await _visit_path(fixture.rest_path.slice(0, -1), false)
		await _click(_route_action(fixture.rest_path.back()))
		_check(app.rest_stitch != null and app.rest_stitch.is_valid() and not app.rest_stitch_button.disabled, "earned purse admits real Rest stitch")
		if app.rest_stitch == null:
			break
		_bounds(app.rest_view)


		if session == 6:
			await _resew_affordability()
			await _click(app.rest_back_button)
			_check(randi() == global_next, "re-sew and rejected guided entries preserve global RNG")
			continue
		var opener: Callable = app.rest_stitch_guided_button.pressed.get_connections()[0].callable
		var before := _stitch_state()
		if retained.is_valid():
			_reject_stitch(retained, "prior Rest callback")
		if session % 2 == 0:
			await _click(app.rest_stitch_guided_button)
		else:
			app.rest_stitch_button.grab_focus()
			await _key(KEY_TAB)
			_check(app.rest_stitch_guided_button.has_focus(), "Tab reaches guided action")
			await _key(KEY_ENTER)
		var picker: LiveRestStitchPairPicker = app.rest_stitch_picker
		_check(picker != null and app.rest_stitch_overlay.get_parent() == app, "guided picker mounts as sibling overlay")
		if picker == null:
			break
		_check(picker._model._service == app.rest_stitch and picker._model.source_snapshot() == app._rest_stitch_source, "picker binds exact real service and receipt")
		for control in [picker, picker.first_selector, picker.second_selector, picker.confirm_button, app.rest_stitch_overlay.get_node("DismissStitch")]:
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "guided controls bounded")
		await _key(KEY_TAB)
		_check(picker.first_selector.has_focus(), "Tab from Back reaches first original")
		var a: int = app.run_deck.rfind("warden_strike")
		var b: int = app.run_deck.find("seamstress_prick")
		_check(a > 0 and b > a, "duplicate original and authored cross-owner partner exist")
		var row_a := -1
		for i in range(picker.first_selector.item_count):
			if picker.first_selector.get_item_metadata(i) == a:
				row_a = i
		_check(row_a >= 0, "duplicate original appears by exact index")
		await _select_stitch(picker.first_selector, row_a, session % 2 == 1)
		var row_b := -1
		for i in range(picker.second_selector.item_count):
			if picker.second_selector.get_item_metadata(i) == b:
				row_b = i
		_check(row_b >= 0, "eligible cross-owner partner appears")
		await _select_stitch(picker.second_selector, row_b, session % 2 == 1)
		var preview: Dictionary = picker._current_pair()
		_check(not preview.is_empty(), "physically selected pair produces preview")
		if preview.is_empty():
			break
		_check(preview.first_half == catalog.get_definition(app.run_deck[a]) and preview.second_half == catalog.get_definition(app.run_deck[b]), "preview preserves complete authored halves")
		_check(picker.first_half_label.text == picker._half_lines("First", preview.first_half) and picker.second_half_label.text == picker._half_lines("Second", preview.second_half), "mounted labels show selected authored halves")
		_check(_stitch_state() == before, "opening and physical selections spend nothing or consume RNG")
		var callback: Callable = picker.stitch_requested.get_connections()[0].callable
		var source: Dictionary = app._stitch_snapshot()
		var request: Callable = callback.bind(a, b, source)
		for args in [[a, a, source], [b, a, source], [-1, b, source], [a, b, {}]]:
			_reject_stitch(callback.bind(args[0], args[1], args[2]), "forged displayed pair or receipt")
		var foreign := LiveRestStitchPairPicker.new()
		_reject_stitch(app._guided_stitch_at_rest.bind(a, b, source, foreign, app.rest_stitch_overlay, app.rest_stitch), "foreign picker")
		foreign.free()
		var other := Control.new()
		_reject_stitch(app._guided_stitch_at_rest.bind(a, b, source, picker, other, app.rest_stitch), "foreign overlay")
		other.free()
		var other_service := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
		_reject_stitch(app._guided_stitch_at_rest.bind(a, b, source, picker, app.rest_stitch_overlay, other_service), "foreign service")
		app.run_scraps += 1
		_reject_stitch(request, "stale authoritative purse")
		app.run_scraps -= 1
		var receipt: Dictionary = app.rest_stitch._source_snapshot.duplicate(true)
		app.rest_stitch._source_snapshot.receipt = "forged"
		_reject_stitch(request, "stale service receipt")
		app.rest_stitch._source_snapshot = receipt
		app.party_carryover._rest_ids.append(app.run_map.get_current_node_id())
		_reject_stitch(request, "stale carryover")
		app.party_carryover._rest_ids.pop_back()
		# Patch opening is forbidden while this overlay owns input.
		app._open_rest_patches(app.rest_patch_button)
		_check(app.rest_patch_overlay == null, "patch overlay cannot overlap guided picker")
		var dismiss: Callable = app.rest_stitch_overlay.get_node("DismissStitch").pressed.get_connections()[0].callable
		if session < 2:
			var oracle := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
			_check(oracle.choose_stitch(a, b, source).ok, "independent transaction oracle accepts")
			if session == 0:
				await _click(picker.confirm_button)
			else:
				picker.second_selector.grab_focus()
				await _key(KEY_TAB)
				_check(picker.confirm_button.has_focus(), "Tab reaches guided confirmation")
				await _key(KEY_ENTER)
			_check(app._stitch_snapshot() == oracle.get_snapshot() and app.run_scraps == 0, "exact oracle ledger and three scrap transaction")
			_check(app.rest_stitch_overlay == null and app.rest_stitch_picker == null and app.rest_stitch.is_consumed(), "successful commit disposes picker")
			_check(not app.rest_continue_button.disabled and app.rest_stitch_guided_button.disabled, "exclusive choice preserves Continue")
			_reject_stitch(request, "duplicate guided confirmation")
			var state := _stitch_state()
			if session == 0:
				replay = state.duplicate(true)
			else:
				_check(state == replay, "same seed mouse and keyboard replay match all ledgers and RNG")
			await _click(app.rest_continue_button)
			_check(app.route_view != null and not app.rest_view.visible, "guided Stitch continues to real map")
			_reject_stitch(request, "confirmation after Continue")
			_reject_stitch(opener, "opening after Continue")

			await _visit_path(fixture.later_rest.slice(0, -1), false)
			await _click(_route_action(fixture.later_rest.back()))
			_check(app.rest_view.visible and app.run_map.get_current_node_id() == fixture.later_rest.back(), "later Rest reached through real map controls")
			_check(app.rest_stitch_guided_button.disabled, "zero scraps disables later guided entry")
			_reject_stitch(request, "prior visit confirmation at later Rest")
			_reject_stitch(opener, "prior visit opener at later Rest")
			var overlay = app.rest_stitch_overlay
			dismiss.call()
			_check(app.rest_stitch_overlay == overlay, "prior visit dismissal inert")
			await _click(app.rest_back_button)
		elif session < 4:
			# Retained primary callbacks may commit; that must invalidate the overlay.
			var action: Button = app.rest_heal_button if session == 2 else app.rest_upgrade_button
			action.pressed.get_connections()[0].callable.call()
			_check(app.rest_stitch_overlay == null and not app.rest_continue_button.disabled, "competing primary choice disposes picker")
			_reject_stitch(request, "guided confirmation after Heal/Upgrade")
			_reject_stitch(opener, "guided opening after Heal/Upgrade")
			_check(app.run_scraps == 3, "Heal/Upgrade spends no scraps")
			await _click(app.rest_back_button)
		elif session == 4:
			await _click(app.rest_stitch_overlay.get_node("DismissStitch"))
			_check(app.rest_stitch_overlay == null and _stitch_state() == before, "dismissal is free")
			_reject_stitch(request, "dismissed confirmation")
			# Reopening makes old dismissal and confirmation inert.
			await _click(app.rest_stitch_guided_button)
			var current = app.rest_stitch_overlay
			dismiss.call()
			_reject_stitch(request, "old picker after reopening")
			_check(app.rest_stitch_overlay == current, "old dismiss cannot close replacement")
			app.rest_stitch_first.select(a)
			app.rest_stitch_second.select(b)
			app.rest_stitch_button.pressed.get_connections()[0].callable.call()
			_check(app.rest_stitch.is_consumed() and app.rest_stitch_overlay == null, "direct Stitch also disposes guided picker")
			_reject_stitch(request, "guided after direct Stitch")
			await _click(app.rest_back_button)
		else:
			app.rest_back_button.pressed.get_connections()[0].callable.call()
		var cleared := [app.run_deck.duplicate(), app.run_scraps, app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id]
		request.call()
		opener.call()
		dismiss.call()
		_check(cleared == [[], 0, {}, 1] and cleared == [app.run_deck, app.run_scraps, app.run_stitch_descriptors, app.run_next_stitch_id] and app.rest_stitch_overlay == null, "title callbacks cannot mutate cleared run")
		retained = request
		_check(randi() == global_next, "guided route preserves global RNG")
	await _finish_guided()


func _finish_guided() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_stitch_pair_picker_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _resew_affordability() -> void:
	var wardrobe: RunPatchWardrobe = app._rest_wardrobe
	_check(wardrobe != null and app.run_scraps == 3 and not app.rest_stitch_guided_button.disabled, "earned three scraps and real sewn drop admit guided entry")
	if wardrobe == null:
		return
	var old_open: Callable = app.rest_stitch_guided_button.pressed.get_connections()[0].callable
	await _click(app.rest_stitch_guided_button)
	_check(app.rest_stitch_picker != null, "guided opens with persistent wardrobe")
	app.rest_patch_button.pressed.get_connections()[0].callable.call()
	_check(app.rest_patch_overlay == null, "actual eligible patch action excluded by guided overlay")
	await _click(app.rest_stitch_overlay.get_node("DismissStitch"))
	await _click(app.rest_patch_button)
	_check(app.rest_patch_picker != null, "patch overlay opens after guided dismissal")
	old_open.call()
	_check(app.rest_stitch_overlay == null, "guided excluded by patch overlay")
	var picker: LiveRestPatchResewPicker = app.rest_patch_picker
	_check(picker.source_selector.item_count > 0, "real sewn source exists")
	await _select_stitch(picker.source_selector, 0, false)
	_check(picker.destination_selector.item_count > 0, "real transfer destination exists")
	await _select_stitch(picker.destination_selector, 0, false)
	_check(not picker.confirm_button.disabled, "real re-sew available")
	var service: RunRestStitchCards = app.rest_stitch
	await _click(picker.confirm_button)
	_check(app.run_scraps == 2 and app.rest_stitch != service and app.rest_stitch_guided_button.disabled, "re-sew rebases service and disables unaffordable guided action")
	await _click(app.rest_patch_overlay.get_node("DismissResew"))
	_reject_stitch(old_open, "pre-rebase opener")
	app.rest_stitch_guided_button.pressed.emit()
	_check(app.rest_stitch_overlay == null and app.run_scraps == 2, "forced unaffordable opening remains inert")
	# A valid service with one owner has no legal pair, even with three scraps.
	var one_owner: Array[String] = ["warden_strike", "warden_strike"]
	var original: RunRestStitchCards = app.rest_stitch
	var original_source: Dictionary = app._rest_stitch_source
	app.rest_stitch = RunRestStitchCards.new(one_owner, {}, 3, 1)
	app._rest_stitch_source = app.rest_stitch.get_snapshot()
	_check(app.rest_stitch.is_valid(), "single-owner availability probe has a valid service")
	app._refresh_rest_stitch_guided()
	_check(app.rest_stitch_guided_button.disabled, "no legal cross-owner pair disables entry")
	app.rest_stitch = original
	app._rest_stitch_source = original_source
	app._refresh_rest_stitch_guided()
