extends "res://tests/live_shop_continuation_test.gd"
## Mounted legal Fight/reward/Rest continuation and retained-input rejection.


func _rest_fixture(kind: String) -> Dictionary:
	for value in range(1, 12000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng: int = rng.state
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for rest in map.get_node(fight).outgoing:
				if map.get_node(rest).type != "Rest":
					continue
				var next_id := ""
				var has_combat_choice := false
				for next in map.get_node(rest).outgoing:
					has_combat_choice = has_combat_choice or map.get_node(next).type in ["Fight", "Elite", "Boss"]
					if map.get_node(next).type == kind:
						next_id = next
				if not has_combat_choice or next_id.is_empty():
					continue
				rng.state = opening_rng
				if not map.choose_node(fight):
					continue
				var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
				if selected.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": fight, "rest": rest, "next": next_id}
				map.undo_choice(fight, [])
	return {}


func _rest_state() -> Array:
	var state: Array = _continuation_state() if app.run_map != null else [
		app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
		app.run_removal_count, app.run_rng, app.deck, app.party, app.enemies,
		app.shop_visit, app.shop_purchases, app.title_view.visible]
	return [app.run_scraps, app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id, state, app.run_map.get_floors() if app.run_map != null else [],
		app.rest_recovery.is_consumed() if app.rest_recovery != null else false,
		app._rest_heroes.duplicate(true), app._rest_committed_heroes.duplicate(true),
		app._rest_route.duplicate(), app.rest_view.visible if is_instance_valid(app.rest_view) else false,
		app.rest_continue_button.disabled if is_instance_valid(app.rest_continue_button) else true,
		app.route_view, app.route_buttons.duplicate()]


func _reject_rest(callback: Callable, reason: String) -> void:
	var before := _rest_state()
	callback.call()
	_check(_rest_state() == before, reason + " leaves full run/visit/map/RNG unchanged")


## The same gallery is mounted by the real Rest route, with one upgrade
## group. Direction keys scroll and change focus, never choose or spend.
func _check_rest_direction_keys() -> void:
	var gallery = _visit_tiles()
	var tiles: Array[Button] = gallery.upgrade_tiles()
	_check(gallery.is_gallery_mounted() and gallery.gallery_kind() == "Rest"
		and tiles.size() >= 4 and not app.rest_upgrade_cards.disabled,
		"Rest arrow test has real mounted, enabled multi-choice upgrade gallery")
	if tiles.size() < 4:
		return
	var before := _rest_state()
	var initial_selection: int = app.rest_upgrade_cards.selected
	var emitted := [0]
	app.rest_upgrade_cards.item_selected.connect(func(_row: int): emitted[0] += 1)
	tiles[0].grab_focus()
	await _frames()
	var focus_stitch = tiles[0].get_node_or_null("FocusStitch")
	_check(tiles[0].has_focus() and focus_stitch != null and focus_stitch.is_stitching()
		and Rect2(Vector2.ZERO, tiles[0].size).encloses(focus_stitch.perimeter_rect()),
		"Rest keyboard focus paints the inset sewn border within the card")
	await _key(KEY_UP)
	_check(tiles[0].has_focus(), "Rest Up at first upgrade row stays in the group")
	await _key(KEY_DOWN)
	_check(tiles[1].has_focus(), "Rest Down focuses adjacent upgrade")
	await _key(KEY_RIGHT)
	await _key(KEY_LEFT)
	_check(tiles[1].has_focus(), "horizontal Rest arrows cannot escape upgrade cards")
	await _key(KEY_UP)
	_check(tiles[0].has_focus(), "Rest Up returns to previous enabled upgrade")
	var scroll: ScrollContainer = gallery.gallery_scroll()
	tiles.back().grab_focus()
	await _frames()
	_check(scroll.scroll_vertical > 0
		and scroll.get_global_rect().encloses(tiles.back().get_global_rect())
		and tiles.back().get_node("FocusStitch").is_stitching(),
		"last Rest upgrade scrolls full sewn focus frame into view")
	await _key(KEY_DOWN)
	_check(tiles.back().has_focus(), "Rest Down at end does not wrap into Heal or Upgrade")
	tiles[0].grab_focus()
	app.rest_upgrade_cards.set_item_disabled(1, true)
	await _frames()
	await _key(KEY_DOWN)
	_check(tiles[2].has_focus() and tiles[1].disabled,
		"Rest Down skips disabled canonical upgrade row")
	app.rest_upgrade_cards.set_item_disabled(1, false)
	await _frames()
	_check(_rest_state() == before and app.rest_upgrade_cards.selected == initial_selection
		and emitted == [0], "Rest arrows preserve chosen row, run wallet, deck, RNG and route")
	_check(not gallery.tile_details(tiles[2]).selected and tiles[2].has_focus(),
		"Rest SELECTED label remains distinct from keyboard focus")
	await _key(KEY_ENTER)
	_check(app.rest_upgrade_cards.selected == 2 and emitted == [1]
		and gallery.tile_details(tiles[2]).selected and _rest_state() == before,
		"Enter selects one focused Rest row via OptionButton without upgrading")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var stale: Array[Callable] = []
	for kind in ["Rest", "Shop"]:
		var fixture := _rest_fixture(kind)
		_check(not fixture.is_empty(), "real seeded graph supports Rest -> " + kind + " alongside a combat outgoing choice")
		if fixture.is_empty():
			continue
		var replay: Array = []
		for session in range(2):
			seed(620062)
			var global_next := randi()
			seed(620062)
			if not await _routed_win(fixture, false):
				break
			for callback in stale:
				_reject_rest(callback, "previous run input")
			await _click(app.reward_buttons[0])
			_check(app.fight_reward_claimed, "real reward claimed before leaving Fight")
			await _click(app.continue_button)
			# Carry a nonzero prior-removal count; no removal transaction is bypassed.
			app.run_removal_count = 2
			var entry := _route_action(fixture.rest)
			if entry == null:
				break
			await _click(entry)
			_check(app.rest_recovery != null and is_instance_valid(app.rest_continue_button), "Rest mounts live recovery and Continue")
			if app.rest_recovery == null or not is_instance_valid(app.rest_continue_button):
				break
			_bounds(app.rest_view)
			await _check_rest_direction_keys()
			var button: Button = app.rest_continue_button
			var visit: RunRestRecovery = app.rest_recovery
			var map: RunMap = app.run_map
			var prior: Array[String] = map.get_route()
			var exit: Callable = button.pressed.get_connections()[0].callable
			var heal: Callable = app.rest_heal_button.pressed.get_connections()[0].callable
			var back: Callable = app.rest_back_button.pressed.get_connections()[0].callable
			_check(button.disabled and not visit.is_consumed(), "Continue unavailable before healing")
			var before := _rest_state()
			await _click(button)
			button.pressed.emit()
			_check(_rest_state() == before and app.route_view == null, "premature physical and emitted Continue are inert")
			var oracle := RunRestRecovery.new(app.run_heroes).choose_heal()
			_check(oracle.ok, "valid living party supplies independent heal oracle")
			if session == 0:
				await _click(app.rest_heal_button)
			else:
				app.rest_heal_button.grab_focus()
				await _key(KEY_ENTER)
			_check(visit.is_consumed() and app.rest_heal_button.disabled and not button.disabled
				and app.run_heroes == oracle.heroes, "one visible Heal commits exact HP and enables Continue")
			_reject_rest(heal, "duplicate Heal")
			var saved_heroes: Array = app.run_heroes.duplicate(true)
			app.run_heroes[0].hp -= 1
			_check(app._rest_committed_heroes == saved_heroes, "committed snapshot independent of live nested heroes")
			_reject_rest(exit, "mutated healed HP")
			app.run_heroes = saved_heroes.duplicate(true)
			for invalid in [[], _defeated(saved_heroes)]:
				app.run_heroes = invalid
				_reject_rest(exit, "invalid or defeated roster")
			app.run_heroes = saved_heroes.duplicate(true)
			var empty_route: Array[String] = []
			_reject_rest(app._continue_from_rest.bind(RunRestRecovery.new(saved_heroes), weakref(map), prior, button), "foreign visit")
			_reject_rest(app._continue_from_rest.bind(visit, weakref(RunMap.new()), prior, button), "foreign map")
			_reject_rest(app._continue_from_rest.bind(visit, weakref(map), empty_route, button), "foreign route")
			_reject_rest(app._continue_from_rest.bind(visit, weakref(map), prior, app.rest_back_button), "foreign control")
			var replacement := RunMap.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = fixture.seed
			replacement.generate(rng)
			_check(replacement.choose_node(fixture.fight) and replacement.choose_node(fixture.rest), "replacement map has same valid route")
			app.run_map = replacement
			_reject_rest(exit, "replaced map identity")
			app.run_map = map
			map._nodes[fixture.rest].type = "Shop"
			_reject_rest(exit, "changed current type")
			map._nodes[fixture.rest].type = "Rest"
			map._route.append(fixture.next)
			_reject_rest(exit, "advanced route")
			map._route.pop_back()
			button.disabled = true
			_reject_rest(exit, "disabled control")
			button.disabled = false
			button.hide()
			_reject_rest(exit, "hidden control")
			button.show()
			app.rest_view.hide()
			_reject_rest(exit, "hidden visit")
			app.rest_view.show()
			before = _persistent()
			if session == 0:
				await _click(button)
			else:
				app.rest_back_button.grab_focus()
				await _key(KEY_TAB)
				_check(button.has_focus(), "Tab from Return reaches enabled Continue")
				await _key(KEY_SPACE)
			_check(app.route_view != null and not app.rest_view.visible and button.disabled, "Continue hides Rest and opens one connected chooser")
			if app.route_view == null:
				break
			_check(_persistent() == before, "Continue preserves exact run and combat state")
			await _check_connected_book()
			_bounds(app.route_view)
			for callback in [exit, heal, back]:
				_reject_rest(callback, "hidden previous visit callback")
			var shown: Array[String] = []
			for action in app.route_buttons:
				var id: String = action.get_meta("route_id")
				var node_kind: String = map.get_node(id).type
				shown.append(id)
				_check(action.get_meta("route_kind") == node_kind and action.text == app.route_kind_label(node_kind) and action.disabled == (node_kind not in ["Rest", "Shop", "Event", "Treasure", "SewingCircle", "Campfire", "PatchStall", "Fight", "Elite", "Boss"]), "only supported true adjacent ID/type enabled")
				if action.disabled:
					var rejected := _rest_state()
					await _click(action)
					action.pressed.emit()
					_check(_rest_state() == rejected, "unsupported route input inert")
			_check(shown == map.get_legal_choices(), "exact outgoing route IDs in map order")
			_check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(), "visible route keyboard focus")
			var next := _route_action(fixture.next)
			if next == null:
				break
			var choose: Callable = next.pressed.get_connections()[0].callable
			var edges: Array = map._nodes[fixture.rest].outgoing.duplicate()
			map._nodes[fixture.rest].outgoing.erase(fixture.next)
			_reject_rest(choose, "removed outgoing edge")
			map._nodes[fixture.rest].outgoing = edges
			app.run_heroes[0].hp -= 1
			_reject_rest(choose, "mutated committed party at chooser")
			app.run_heroes = saved_heroes.duplicate(true)
			var stock := _stock_oracle() if kind == "Shop" else {}
			var old_view: int = app.rest_view.get_instance_id()
			before = _persistent()
			if session == 0:
				await _click(next)
			else:
				next.grab_focus()
				await _key(KEY_ENTER)
			_check(app.run_map == map and map.get_route() == prior + [fixture.next], "same map advances exactly one floor")
			_check(_persistent().slice(0, 3) == before.slice(0, 3) and app.run_removal_count == 2, "next visit retains exact healed heroes/deck/gold/nonzero removals")
			if kind == "Shop":
				_check(app.shop_visit != null and app.shop_purchases != null, "next actual Shop mounted")
				if app.shop_purchases != null:
					_check(app.shop_purchases.get_stock() == stock.stock and app.run_rng.state == stock.state, "Shop draws exactly once from ongoing run RNG")
				_bounds(app.shop_view)
			else:
				_check(not is_instance_id_valid(old_view) and app.rest_recovery != visit
					and not app.rest_recovery.is_consumed() and app.rest_continue_button.disabled
					and app._rest_committed_heroes.is_empty(), "next Rest frees hidden old view and resets recovery/Continue/snapshot")
				_check(app.run_rng.state == before[3], "next Rest consumes no run RNG")
				_bounds(app.rest_view)
			for callback in [exit, heal, back, choose]:
				_reject_rest(callback, "stale prior visit and repeated route")
			if kind == "Rest":
				oracle = RunRestRecovery.new(app.run_heroes).choose_heal()
				await _click(app.rest_heal_button)
				_check(app.run_heroes == oracle.heroes and not app.rest_continue_button.disabled, "next Rest can heal and continue independently")
			if session == 0:
				replay = _continuation_state()
			else:
				_check(_continuation_state() == replay, "mouse/keyboard seeded replay reproduces full run and services")
			stale = [exit, heal, back, choose]
			await _click(app.rest_back_button if kind == "Rest" else app.shop_back_button)
			_check(app.title_view.visible and app.run_map == null and app.run_rng == null and app.rest_recovery == null
				and app.rest_continue_button == null and app._rest_committed_heroes.is_empty()
				and app.run_heroes.is_empty() and app.run_deck.is_empty() and app.session_gold == 0 and app.run_removal_count == 0,
				"Return fully resets continued run and Rest references")
			for callback in stale:
				_reject_rest(callback, "post-title input")
			_check(app.run_map == null and app.run_rng == null and app.title_view.visible, "post-title callbacks inert")
			_check(randi() == global_next, "entire continued run consumes no global RNG")
	_check(app._start_battle(), "explicit standalone M01 fixture starts")
	await _frames()
	_check(app.deck != null and app.run_map == null and app.rest_recovery == null, "standalone M01 fixture mounts independent battle")
	_check(not stale.is_empty(), "continued visit supplies retained callbacks for standalone fixture")
	var standalone := _state()
	for callback in stale:
		_reject_rest(callback, "old visit input against standalone M01 fixture")
	_check(_state() == standalone and app.run_map == null and app.rest_recovery == null
		and app.shop_visit == null and app.shop_purchases == null and app.party_carryover == null,
		"retained inputs preserve standalone combat without reviving map, Rest, Shop or torn state")
	await _click(app.return_button)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_continuation_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
