extends "res://tests/live_shop_patch_sewing_test.gd"
## Real rewarded route; no injected scraps. Existing attack patch is a prior-owned
## save fixture sewn through the public ledger, alongside actual Elite drops.


func _rest_state() -> Array:
	return [wardrobe.get_snapshot(), app.run_heroes.duplicate(true), app.run_deck.duplicate(),
		app.run_trinkets.duplicate(), app.session_gold, app.run_scraps, app.run_rng.state,
		app.run_map.get_route(), app.party_carryover.read_state(), app.party_carryover.torn.read_state(),
		app._stitch_snapshot(), app.rest_stitch.get_snapshot(), app.rest_stitch.is_consumed(),
		app.rest_recovery.is_consumed(), app.rest_upgrade.is_consumed()]


## The master face a mounted control resolves through the installed theme.
func _picker_face_path(control: Control) -> String:
	if not is_instance_valid(control):
		return ""
	var font: Font = control.get_theme_font("font")
	while font is FontVariation and (font as FontVariation).base_font != null:
		font = (font as FontVariation).base_font
	return font.resource_path if font != null else ""


func _check_picker_typography(picker: LiveRestPatchResewPicker) -> void:
	var heading := "res://assets/fonts/LondrinaSolid-Regular.ttf"
	var body := "res://assets/fonts/PatrickHand-Regular.ttf"
	_check(picker.banner_label.theme_type_variation == "PatchHeading"
		and picker.banner_label.get_theme_font_size("font_size") >= 26
		and picker.source_heading.theme_type_variation == "PatchHeading"
		and picker.destination_heading.theme_type_variation == "PatchHeading"
		and picker.source_heading.get_theme_font_size("font_size") >= 18
		and picker.destination_heading.get_theme_font_size("font_size") >= 18
		and _picker_face_path(picker.banner_label) == heading
		and _picker_face_path(picker.source_heading) == heading
		and _picker_face_path(picker.destination_heading) == heading,
		"live Rest re-sew headings wear the installed Londrina PatchHeading face")
	_check(picker.confirm_button.theme_type_variation == "PatchHeadingButton"
		and _picker_face_path(picker.confirm_button) == heading
		and picker.confirm_button.is_visible_in_tree()
		and not picker.confirm_button.pressed.get_connections().is_empty(),
		"live Confirm re-sew button wears PatchHeadingButton and keeps its signal")
	_check(picker
		.find_children("*", "Label", true, false)
		.filter(func(node): return node.theme_type_variation == "PatchHeading").size() == 3,
		"live picker reserves the heading face for exactly its banner and two sections")
	for label in [picker.scraps_label, picker.preview_label, picker.feedback_label]:
		_check(label.theme_type_variation == "" and _picker_face_path(label) == body,
			"live picker body text keeps the inherited Patrick Hand face")


func _request(patch: String, source: String, target: String, keyboard: bool) -> void:
	var picker: LiveRestPatchResewPicker = app.rest_patch_picker
	var found := false
	for i in range(picker._sources.size()):
		if picker._sources[i] == {"patch_id": patch, "from_hero": source}:
			await _activate(picker._source_buttons[i], keyboard)
			for j in range(picker._destinations.size()):
				if picker._destinations[j].to_hero == target:
					await _activate(picker._destination_buttons[j], keyboard)
					found = true
					break
			break
	_check(found and not picker.confirm_button.disabled, "actual picker offers requested transfer")
	if not found:
		return
	var before := wardrobe.get_snapshot()
	var expected: Dictionary = before.worn.duplicate(true)
	var slot: String = before.definitions[patch]
	expected[source][slot] = before.worn[target][slot]
	expected[target][slot] = patch
	var stale: Callable = picker.re_sew_requested.get_connections()[0].callable.bind(
		patch, source, target, app.run_map.get_current_node_id(), before)
	await _activate(picker.confirm_button, keyboard)
	var after := wardrobe.get_snapshot()
	_check(after.worn == expected and after.scraps == before.scraps - 1
		and app.run_scraps == after.scraps and after.owned == before.owned
		and after.heroes == before.heroes and after.gold == before.gold and after.cards == before.cards,
		"MOVE/SWAP charges one scrap and preserves all unrelated owned/run state")
	_check(after.operation_ids.size() == before.operation_ids.size() + 1
		and after.operation_ids.slice(0, -1) == before.operation_ids,
		"visit transaction appends a fresh operation ID")
	_check(picker._snapshot == after and picker.scraps_label.text == "Scraps: %d" % after.scraps,
		"mounted picker refreshes its exact ledger and purse")
	var state := _rest_state()
	picker._pending = true
	stale.call()
	_check(_rest_state() == state, "duplicate snapshot request is entirely side-effect-free")
	picker._pending = false


func _dismiss(keyboard: bool) -> void:
	await _activate(app.rest_patch_overlay.get_node("DismissResew"), keyboard)
	_check(app.rest_patch_overlay == null and app.rest_view.is_visible_in_tree(), "overlay dismisses back to primary Rest")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _sequence_fixture(["Elite", "Elite", "Rest", "Fight"])
	_check(not fixture.is_empty(), "seeded real route has two Elites, Rest and onward Fight")
	if fixture.is_empty():
		await _finish_patches()
		return
	var observations := {}
	for session in range(6):
		var keyboard := session >= 3
		var choice := session % 3
		seed(104104)
		var global_next := randi()
		seed(104104)
		if not await _routed_win(fixture, false):
			break
		await _activate(app.reward_buttons[3], keyboard)
		# Prior-owned save fixture uses the same complete authored slots as live rewards.
		var records := RunAuthoredPatchDefinitions.load_definitions()
		_check(not records.is_empty(), "complete authored reward wardrobe loads")
		app.run_trinkets.assign(["button_eye", "pincushion_arm"])
		wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, records,
			app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
		for id in app.run_trinkets:
			_check(wardrobe.sew(id, "tinker", wardrobe.get_snapshot().definitions[id],
				"prior:" + id, wardrobe.get_snapshot()).ok, "prior owned patch legitimately sewn")
		_check(app.party_carryover.bind_wardrobe(wardrobe, app.party_carryover.torn,
			wardrobe.get_snapshot()), "real carryover binds prior sewn ownership")
		await _activate(app.continue_button, keyboard)
		for index in range(2):
			await _reach(fixture.paths[index], keyboard)
			await _settle_battle(keyboard)
			var sewing = app.get_node("LiveElitePatchSewing")
			_check(sewing.hero_buttons.size() == 3, "real Elite claim exposes genuine patch sewing")
			if sewing.hero_buttons.size() != 3:
				await _finish_patches()
				return
			await _activate(sewing.hero_buttons[index], keyboard)
			wardrobe = sewing.wardrobe
			await _activate(app.continue_button, keyboard)
		_check(app.run_scraps >= 5 and app.party_carryover._wardrobe == wardrobe,
			"actual rewarded battles earned enough scraps and bound wardrobe")
		var state := wardrobe.get_snapshot()
		var patch := ""
		var source := ""
		for hero in ["warden", "seamstress"]:
			for slot in ["HEAD", "ARM"]:
				if state.worn[hero][slot] != "":
					patch = state.worn[hero][slot]
					source = hero
		_check(not patch.is_empty(), "actual Elite drops include head/arm patch")
		if patch.is_empty():
			break
		await _reach(fixture.paths[2], keyboard)
		_check(app._rest_wardrobe == wardrobe and wardrobe.get_snapshot().rest_id == app.run_map.get_current_node_id(), "legal Rest opens identical bound wardrobe")
		for control in [app.rest_view, app.rest_patch_button, app.rest_back_button, app.rest_continue_button]:
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "Rest actions fit viewport")
		# MOVE before the primary choice; SWAP after it, for all three choices.
		await _activate(app.rest_patch_button, keyboard)
		var picker: LiveRestPatchResewPicker = app.rest_patch_picker
		_check(picker != null and picker._wardrobe == wardrobe and picker._torn == app.party_carryover.torn, "mounted picker uses real owners")
		if picker == null:
			await _finish_patches()
			return
		for control in [picker.source_selector, picker.destination_selector, picker.confirm_button, app.rest_patch_overlay.get_node("DismissResew")]:
			_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "overlay input bounds fit viewport")
		_check_picker_typography(picker)
		await _key(KEY_TAB)
		_check(root.gui_get_focus_owner() == picker.source_selector, "Tab reaches source from dismiss control")
		var callback: Callable = picker.re_sew_requested.get_connections()[0].callable
		var before := _rest_state()
		picker._pending = true
		for args in [["foreign", source, "tinker"], [patch, source, source], [patch, "tinker", source]]:
			callback.call(args[0], args[1], args[2], app.run_map.get_current_node_id(), wardrobe.get_snapshot())
			_check(_rest_state() == before, "forged transfer preserves every ledger and RNG")
		app.run_scraps += 1
		var drifted := _rest_state()
		callback.call(patch, source, "tinker", app.run_map.get_current_node_id(), wardrobe.get_snapshot())
		_check(_rest_state() == drifted, "unsolicited purse drift fails closed")
		app.run_scraps -= 1
		var forged: Dictionary = wardrobe.get_snapshot()
		forged.scraps += 1
		callback.call(patch, source, "tinker", app.run_map.get_current_node_id(), forged)
		callback.call(patch, source, "tinker", "foreign_rest", wardrobe.get_snapshot())
		app._resew_at_rest(patch, source, "tinker", app.run_map.get_current_node_id(),
			wardrobe.get_snapshot(), picker, wardrobe, RunTornCarryover.new(app.run_heroes))
		_check(_rest_state() == before, "forged receipt, node and foreign owner cannot mutate state")
		picker._pending = false
		var empty := "seamstress" if source == "warden" else "warden"
		await _request(patch, source, empty, keyboard)
		_check(not app.rest_heal_button.disabled and not app.rest_upgrade_button.disabled, "transfer preserves primary choice")
		await _dismiss(keyboard)
		if choice == 0:
			await _activate(app.rest_heal_button, keyboard)
		elif choice == 1:
			await _activate(app.rest_upgrade_button, keyboard)
		else:
			var first_owner: String = catalog.get_definition(app.run_deck[0]).owner
			var second := -1
			for i in range(app.run_deck.size()):
				if catalog.get_definition(app.run_deck[i]).owner != first_owner:
					second = i
					break
			_check(second >= 0, "stitch has two real distinct owners")
			await _pick(app.rest_stitch_second, second, keyboard)
			await _activate(app.rest_stitch_button, keyboard)
		_check(app._current_completed_rest() and not app.rest_continue_button.disabled, "chosen primary commits once after MOVE")
		var receipt: Dictionary = app.rest_stitch.get_snapshot()
		var primary: Array = [app.rest_recovery, app.rest_recovery._roster.duplicate(true),
			app.rest_recovery.is_consumed(), app.rest_upgrade, app.rest_upgrade._deck.duplicate(), app.rest_upgrade.is_consumed()]
		await _activate(app.rest_patch_button, keyboard)
		await _request(patch, empty, "tinker", keyboard)
		_check((choice != 2 or app.rest_stitch.get_snapshot() == receipt) and app._current_completed_rest(), "SWAP preserves completed primary receipt and Continue")
		_check(primary == [app.rest_recovery, app.rest_recovery._roster,
			app.rest_recovery.is_consumed(), app.rest_upgrade, app.rest_upgrade._deck, app.rest_upgrade.is_consumed()],
			"re-sew preserves heal and upgrade service identities and completed results")
		if choice == 2:
			_check(app.run_scraps == 0 and app.rest_patch_picker.confirm_button.disabled, "earned purse exhausted and unaffordable picker disabled")
			before = _rest_state()
			app.rest_patch_picker._pending = true
			app.rest_patch_picker.re_sew_requested.emit(patch, "tinker", source,
				app.run_map.get_current_node_id(), wardrobe.get_snapshot())
			_check(_rest_state() == before, "forced unaffordable live request spends nothing")
			app.rest_patch_picker._pending = false
		await _dismiss(keyboard)
		before = _rest_state()
		for button in [app.rest_heal_button, app.rest_upgrade_button, app.rest_stitch_button]:
			button.pressed.emit()
		_check(_rest_state() == before, "primary actions remain once-only after re-sew")
		var observation := _rest_state()
		if keyboard:
			_check(observation == observations[choice], "same-seed mouse and keyboard ledgers and RNG replay")
		else:
			observations[choice] = observation
		if session == 5:
			await _activate(app.rest_patch_button, keyboard)
			var active := wardrobe.get_snapshot()
			var retained: Callable = app.rest_patch_picker.re_sew_requested.get_connections()[0].callable
			app._return_from_visit(app.rest_view)
			retained.call(patch, "tinker", source, active.rest_id, active)
			_check(app.rest_patch_overlay == null and app.rest_patch_picker == null
				and app._rest_wardrobe == null and wardrobe.get_snapshot() == active,
				"Return from open overlay clears UI/callbacks without closing or spending on discarded visit")
			_check(randi() == global_next, "Return consumes no global RNG")
			continue
		var worn: Dictionary = wardrobe.get_snapshot().worn
		await _activate(app.rest_continue_button, keyboard)
		_check(wardrobe.get_snapshot().rest_id == "" and app.route_view != null, "valid Continue closes visit and admits next route")
		var closed := wardrobe.get_snapshot()
		callback.call(patch, "tinker", source, closed.rest_ids.back(), closed)
		_check(wardrobe.get_snapshot() == closed, "stale closed overlay callback cannot spend")
		await _reach(fixture.paths[3], keyboard)
		_check(app.party_carryover._wardrobe == wardrobe and wardrobe.get_snapshot().worn == worn and app.party != null, "same assignments survive real onward Fight admission")
		_check(randi() == global_next, "accepted and rejected paths consume no global RNG")
		app._return_to_title()
		callback.call(patch, "tinker", source, closed.rest_ids.back(), closed)
		_check(app.rest_patch_picker == null and app._rest_wardrobe == null and wardrobe.get_snapshot() == closed, "Return clears UI/owner and retires callbacks")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_patch_resew_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
