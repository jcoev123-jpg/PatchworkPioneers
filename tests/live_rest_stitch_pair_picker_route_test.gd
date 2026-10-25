extends "res://tests/live_rest_stitch_choice_test.gd"


func _assert_heading(label: Label, expected: String, font_size: int) -> void:
	_check(label != null and label.is_inside_tree() and label.is_visible_in_tree(),
		"heading is mounted and visible")
	if label == null:
		return
	_check(label.text == expected, "heading retains exact authored text")
	_check(label.theme == null and not label.has_theme_font_override("font")
		and label.theme_type_variation == "PatchHeading",
		"heading inherits PatchHeading without a local theme or font")
	var font := label.get_theme_font("font")
	_check(font == app.get_theme_font("font", "PatchHeading"),
		"mounted heading resolves the inherited project heading font")
	while font is FontVariation:
		font = (font as FontVariation).base_font
	_check(font != null and font.resource_path == "res://assets/fonts/LondrinaSolid-Regular.ttf",
		"mounted heading resolves Londrina Solid Regular")
	_check(label.get_theme_font_size("font_size") == font_size,
		"heading preserves compact font size")


func _assert_tile_names(tiles: Array[Button], entries: Array[Dictionary]) -> void:
	_check(not tiles.is_empty() and tiles.size() == entries.size(),
		"mounted name checks cover every canonical option")
	for i in range(mini(tiles.size(), entries.size())):
		var tile := tiles[i]
		var entry := entries[i]
		var authored := RunRestStitchCards.resolve_card_definition(entry["id"])
		var from_positions: Array = authored.get("from_positions", []) if not authored.is_empty() else []
		var effect_line := ""
		if not authored.is_empty():
			effect_line = CardShortRules.line(authored)
		_check(not authored.is_empty() and not effect_line.is_empty()
			and entry["name"] == authored.get("display_name")
			and tile.get_meta("index") == entry["index"]
			and tile.get_meta("id") == entry["id"]
			and tile.get_meta("name") == entry["name"],
			"tile identity and authored name match canonical entry")
		_check(tile.tooltip_text == LiveRestStitchPairPicker.from_positions_tooltip(from_positions) + "\nEffect: " + effect_line,
			"tile tooltip matches canonical FROM and authored effect")
		_check(tile.tooltip_text.begins_with("Owner FROM:") and not tile.tooltip_text.contains("TO:"),
			"tile tooltip describes owner FROM positions, not enemy TO")
		for pos in [1, 2, 3]:
			var pip := tile.find_child("From%d" % pos, true, false) as Control
			_check(pip != null and pip.is_inside_tree(), "tile mounts From%d pip" % pos)
			if pip != null:
				var is_active: bool = from_positions.has(pos)
				_check(bool(pip.get_meta("active", false)) == is_active,
					"pip %d active matches canonical from_positions: %s" % [pos, entry["id"]])
				var num := pip.find_child("PipNum", true, false) as Label
				_check(num != null and num.text == str(pos), "pip %d displays readable numeral" % pos)
		_assert_heading(tile.get_node_or_null("CardName") as Label, entry["name"], 16)
		var fallback := tile.find_child("CardNameFallback", true, false) as Label
		if fallback != null:
			_assert_heading(fallback, entry["name"], 10)


func _assert_picker_names(picker: LiveRestStitchPairPicker) -> void:
	_assert_heading(picker.get_node_or_null("StitchPickerHeading") as Label,
		"REST • STITCH TWO ORIGINAL CARDS", 18)
	_assert_tile_names(picker.first_tiles, picker._model.first_options())


func _assert_missing_art_names(picker: LiveRestStitchPairPicker) -> void:
	var entries := picker._model.first_options()
	_check(not entries.is_empty(), "fallback fixture has a canonical authored option")
	if entries.is_empty():
		return
	# Change only a detached presentation entry's art lookup ID. No shipped art
	# is removed, and this fixture never enters the model or transaction path.
	var entry := entries[0].duplicate(true)
	entry["id"] = "__typography_missing_art_fixture__/card"
	for first in [true, false]:
		var tile := picker._create_card_tile(entry, first)
		picker.add_child(tile)
		_assert_heading(tile.get_node_or_null("CardName") as Label, entries[0]["name"], 16)
		_assert_heading(tile.find_child("CardNameFallback", true, false) as Label,
			entries[0]["name"], 10)
		_check(tile.get_meta("name") == entries[0]["name"],
			"missing-art tile retains canonical name metadata in both stages")
		_check(tile.tooltip_text == "Owner FROM: none",
			"missing-art tile tooltip indicates no active positions")
		_check(tile.get_meta("from_positions", [1]) == [],
			"missing-art tile has empty canonical from_positions")
		_check(tile.get_meta("cost") == entries[0]["cost"] and tile.get_meta("owner") == entries[0]["owner"],
			"missing-art tile retains cost and owner")
		for pos in [1, 2, 3]:
			var pip := tile.find_child("From%d" % pos, true, false) as Control
			_check(pip != null and not pip.get_meta("active", false),
				"missing-art tile never invents active position %d" % pos)
			var num := pip.find_child("PipNum", true, false) as Label
			_check(num != null and num.text == str(pos),
				"missing-art pip %d displays readable inactive numeral" % pos)
		tile.free()


func _assert_live_caption(picker: LiveRestStitchPairPicker, a: int, b: int,
		first_name: String, second_name: String, deck_count: int, scraps_left: int,
		label: String) -> void:
	var preview := picker._current_pair()
	_check(not preview.is_empty() and preview == picker._model.preview(a, b),
		label + " mounted selection matches the detached authoritative forecast")
	if preview.is_empty():
		return
	var expected := "Sew %s (copy #%d) + %s (copy #%d)\n%d → %d shared cards • 3 scraps spent • %d remaining\nSewn card cannot upgrade or stitch again" % [
		first_name, a + 1, second_name, b + 1, deck_count, deck_count - 1, scraps_left]
	var caption := picker.consequence_label.text
	_check(caption == expected and picker.consequence_label.get_line_count() <= 3,
		label + " mounts exact ordered one-based copies, deck delta, spend, balance and restriction")
	_check(not caption.contains("0-based") and not caption.contains("stitched_")
		and not caption.contains(str(preview["first_id"]))
		and not caption.contains(str(preview["second_id"])),
		label + " never exposes internal card IDs or zero-based terminology")
	_check(preview["first_index"] == a and preview["second_index"] == b
		and preview["deck_before_count"] == deck_count
		and preview["deck_after_count"] == deck_count - 1
		and preview["scrap_cost"] == 3 and preview["remaining_scraps"] == scraps_left,
		label + " preserves true zero-based authoritative indices and economics")


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
		_assert_picker_names(picker)
		if session == 0:
			_assert_missing_art_names(picker)
		_check(picker._model._service == app.rest_stitch and picker._model.source_snapshot() == app._rest_stitch_source, "picker binds exact real service and receipt")
		for control in [picker, picker.first_tile_scroll, picker.second_tile_scroll, picker.confirm_button, app.rest_stitch_overlay.get_node("DismissStitch")]:
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "guided controls bounded")
		await _key(KEY_TAB)
		_check(picker.first_tiles[0].has_focus(), "Tab from Back reaches first original tile")
		var a: int = app.run_deck.rfind("warden_strike")
		var b: int = app.run_deck.find("seamstress_prick")
		var other_a: int = app.run_deck.find("warden_strike")
		_check(a > 0 and b > a and other_a != a, "duplicate original and authored cross-owner partner exist")
		var tile_a := picker.first_tile_for_index(a)
		var tile_other_a := picker.first_tile_for_index(other_a)
		_check(tile_a != null and tile_other_a != null and tile_a != tile_other_a, "distinct duplicate occurrences are preserved as distinct first tiles")
		_check(tile_a.is_visible_in_tree() and tile_other_a.is_visible_in_tree(), "duplicate original card tiles are mounted and visible")
		if session % 2 == 0:
			await _click(tile_a)
		else:
			tile_a.grab_focus()
			_check(tile_a.has_focus(), "first card tile has keyboard focus")
			await _key(KEY_ENTER)
		_check(picker.second_tile_scroll.visible and not picker.first_tile_scroll.visible, "second tile scroll displayed after first choice")
		await _frames()
		_check(picker.second_tiles.size() > 0 and picker.second_tiles[0].has_focus(), "focus automatically moves to first visible second tile")

		if session == 1:
			picker.change_first_button.grab_focus()
			await _key(KEY_ENTER)
			await _frames()
			_check(picker.first_tile_scroll.visible and not picker.second_tile_scroll.visible, "Change First returns to first row")
			_check(picker.first_tiles.size() > 0 and picker.first_tiles[0].has_focus(), "focus automatically returns to first visible first tile")
			_check(picker.confirm_button.disabled, "discarded prior pair cannot be confirmed")
			
			var temp_tile = picker.first_tile_for_index(other_a)
			temp_tile.grab_focus()
			await _key(KEY_ENTER)
			await _frames()
			_check(picker.second_tile_scroll.visible, "second tile scroll displayed after alternate first choice")
			_check(picker.second_tiles.size() > 0 and picker.second_tiles[0].has_focus(), "focus automatically moves to second tile again")
			
			picker.change_first_button.grab_focus()
			await _key(KEY_ENTER)
			await _frames()
			
			tile_a.grab_focus()
			await _key(KEY_ENTER)
			await _frames()

		var expected_second_options: Array = picker._model.second_options(a)
		_assert_tile_names(picker.second_tiles, picker._model.second_options(a))
		_check(picker.second_tiles.size() == expected_second_options.size(), "second_tiles populated with exact second_options count")
		var second_indices: Array[int] = []
		var no_same_owner := true
		for s_tile in picker.second_tiles:
			var idx: int = s_tile.get_meta("index")
			second_indices.append(idx)
			var card_id: String = app.run_deck[idx]
			var def: Dictionary = catalog.get_definition(card_id)
			if not def.is_empty() and def.get("owner", "") == catalog.get_definition(app.run_deck[a]).get("owner", ""):
				no_same_owner = false
		_check(no_same_owner, "second_tiles contain no same-owner cards")
		var expected_indices: Array[int] = []
		for opt in expected_second_options:
			expected_indices.append(opt.index)
		_check(second_indices == expected_indices, "second_tiles populated only with second_options(a)")
		var tile_b := picker.second_tile_for_index(b)
		_check(tile_b != null and tile_b.is_visible_in_tree(), "eligible cross-owner partner tile exists")
		if session % 2 == 0:
			await _click(tile_b)
		else:
			tile_b.grab_focus()
			_check(tile_b.has_focus(), "second card tile has keyboard focus")
			await _key(KEY_ENTER)
		var preview: Dictionary = picker._current_pair()
		_check(not preview.is_empty(), "physically selected pair produces preview (first=%d second=%d, select=%d/%d, available=%s, visible=%s)" % [
			picker._selected_first_index, picker._selected_second_index,
			picker.first_selector.selected, picker.second_selector.selected,
			str(picker._model.is_available()), str(picker.is_visible_in_tree())])
		if preview.is_empty():
			break
		_check(preview.first_half == catalog.get_definition(app.run_deck[a]) and preview.second_half == catalog.get_definition(app.run_deck[b]), "preview preserves complete authored halves")
		_check(picker.first_half_label.text == picker._half_lines("First", preview.first_half) and picker.second_half_label.text == picker._half_lines("Second", preview.second_half), "mounted labels show selected authored halves")
		var forecast_source: Dictionary = app._stitch_snapshot()
		var forecast_oracle := RunRestStitchCards.new(
			forecast_source["deck"].duplicate(true), forecast_source["descriptors"].duplicate(true),
			forecast_source["remaining_scraps"], forecast_source["next_stitch_id"])
		_check(forecast_oracle.is_valid() and forecast_oracle.get_snapshot() == forecast_source,
			"real route forecast has complete independent authoritative source")
		var forecast_committed := forecast_oracle.choose_stitch(a, b, forecast_source.duplicate(true))
		_check(forecast_committed.get("ok", false)
			and preview["projection"] == forecast_committed
			and preview["resulting_deck"] == forecast_committed["deck"]
			and preview["descriptor"] == forecast_committed["descriptor"]
			and preview["next_stitch_id"] == forecast_committed["next_stitch_id"]
			and preview["remaining_scraps"] == forecast_committed["remaining_scraps"]
			and preview["consumed_indices"] == [a, b]
			and preview["consumed_ids"] == [app.run_deck[a], app.run_deck[b]],
			"mounted real Rest forecast equals independently committed full ledger and exact duplicate indices")
		_check(picker.summary_label.text.contains(preview["descriptor"]["display_name"])
			and picker.summary_label.text.contains("%d energy" % preview["descriptor"]["cost"])
			and picker.summary_label.text.contains("3 scraps"),
			"live summary retains joined authored name, capped energy and stitch price")
		_assert_live_caption(picker, a, b, "Strike", "Prick",
			forecast_source["deck"].size(), forecast_committed["remaining_scraps"],
			"physically selected real Rest Strike / Prick")
		_check(_stitch_state() == before and app.rest_stitch.get_snapshot() == forecast_source
			and not app.rest_stitch.is_consumed(), "opening and physical selections spend nothing or consume RNG")
		# The physical pair above is already proven. Now inspect the two real
		# duplicate Strike copies and Prick / Pop Shot on this same routed picker.
		if session == 0:
			for strike_copy in [other_a, a]:
				picker._on_first_tile_pressed(strike_copy)
				picker._on_second_tile_pressed(b)
				_assert_live_caption(picker, strike_copy, b, "Strike", "Prick",
					app.run_deck.size(), app.run_scraps - 3,
					"routed Strike / Prick duplicate copy #%d" % (strike_copy + 1))
			var pop_index: int = app.run_deck.find("tinker_pop_shot")
			_check(pop_index >= 0, "routed starter deck contains Pop Shot partner")
			if pop_index >= 0:
				picker._on_first_tile_pressed(b)
				picker._on_second_tile_pressed(pop_index)
				_assert_live_caption(picker, b, pop_index, "Prick", "Pop Shot",
					app.run_deck.size(), app.run_scraps - 3, "routed Prick / Pop Shot")
			picker._on_first_tile_pressed(a)
			picker._on_second_tile_pressed(b)
			_check(picker._current_pair() == preview and _stitch_state() == before,
				"alternate rendered previews restore original exact pair without spend or RNG mutation")
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
				await _key(KEY_TAB)
				_check(picker.confirm_button.has_focus(), "Tab reaches guided confirmation")
				await _key(KEY_ENTER)
			_check(app._stitch_snapshot() == oracle.get_snapshot()
				and app._stitch_snapshot() == forecast_oracle.get_snapshot()
				and app.run_scraps == forecast_committed["remaining_scraps"],
				"forecast displayed before physical input matches exact single real Rest commitment")
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
			var reopened: LiveRestStitchPairPicker = app.rest_stitch_picker
			_check(reopened != null and reopened != picker, "dismissed picker is replaced by a fresh mounted picker")
			if reopened != null:
				_assert_picker_names(reopened)
				await _click(reopened.first_tile_for_index(a))
				_assert_tile_names(reopened.second_tiles, reopened._model.second_options(a))
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
	_check(not picker._source_buttons.is_empty(), "real sewn source exists")
	if picker._source_buttons.is_empty():
		return
	await _click(picker._source_buttons[0])
	_check(picker.source_selector.selected == 0 and picker._source_buttons[0].button_pressed,
		"mouse selects the first sewn patch source")
	_check(not picker._destination_buttons.is_empty(), "real transfer destination exists")
	if picker._destination_buttons.is_empty():
		return
	await _click(picker._destination_buttons[0])
	_check(picker.destination_selector.selected == 0 and picker._destination_buttons[0].button_pressed,
		"mouse selects the first sewn recipient")
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
