extends "res://tests/live_shop_route_entry_test.gd"
## Real seeded Fight -> reward -> Shop -> connected noncombat visit.

const PROJECTED_LABELS := {"Campfire": "Campfire", "Peddler": "Peddler",
	"SewingCircle": "Sewing Circle", "PatchStall": "Patch Stall", "Unpicker": "Unpicker",
	"Fight": "Fight", "Elite": "Elite fight", "Boss": "Boss fight", "Event": "Event", "Treasure": "Treasure"}

## A deliberately tall autowrapped equipment preview, used only to exercise the
## bounded Shop rail. It never enters game data; it stands in for the longest
## authored conditional patch preview, the content that used to push Return below
## the 1280x720 window.
const LONG_PATCH_PREVIEW := "Switchback Button (Head slot)\nEffect: " \
	+ "Once per player turn, when a different living hero's committed card or stitched half immediately precedes this living wearer's committed card or half, this wearer gains 2 Block; same-owner repeats and rejected plays never set it up. " \
	+ "This deliberately long probe sentence is repeated so the autowrapped preview is unmistakably taller than the bounded card, exactly like the longest authored conditional patch text. " \
	+ "Once per player turn, when a different living hero's committed card or stitched half immediately precedes this living wearer's committed card or half, this wearer gains 2 Block. " \
	+ "Same-owner repeats and rejected plays never set it up, and every further line of this probe keeps wrapping inside the preview's own column. " \
	+ "The bounded card scrolls this text so the fixed action rows below it never leave the 1280x720 window. " \
	+ "Inactive while wearer is torn."


func _continuation_fixture(kind: String, first_seed: int = 1, last_seed: int = 2000) -> Dictionary:
	for value in range(first_seed, last_seed):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng := rng.state
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for shop in map.get_node(fight).outgoing:
				if map.get_node(shop).type != "Shop":
					continue
				for next in map.get_node(shop).outgoing:
					if map.get_node(next).type != kind:
						continue
					rng.state = opening_rng
					map.choose_node(fight)
					var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
					if selected.get("encounter_id") == "starter_attacks":
						return {"seed": value, "fight": fight, "shop": shop, "next": next}
					map.undo_choice(fight, [])
	return {}


func _continuation_state() -> Array:
	return [_persistent(), app.run_removal_count,
		app.peddler_visit.read_state() if app.peddler_visit != null else {},
		app.peddler_visit.read_state().state if app.peddler_visit != null else {},
		app.peddler_visit.read_state().stock if app.peddler_visit != null else {}]


func _route_action(id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	_check(false, "required connected control exists: " + id)
	return null


func _check_connected_book() -> void:
	_check(app._can_choose_connected_route() and not app.run_map.get_route().is_empty(), "book has a genuine completed route context")
	var book: Control = app.route_book_backdrop
	_check(is_instance_valid(book) and book.is_visible_in_tree() and app.route_view.name == "ConnectedBookChoices"
		and not app.route_view is Container, "connected choices mount the existing book with independent sewn patches")
	if not is_instance_valid(book):
		return
	var floor_number: int = app.run_map.get_node(app.run_map.get_current_node_id()).floor
	_check(book.get_node("FloorCue").text == "Floor %02d" % floor_number
		and book.get_node("FloorCue").get_meta("floor_number") == floor_number
		and book.get_node("AreaCue").text == RunRouteAtlas.area_for_floor(floor_number), "book identifies the actual current floor and area")
	var slate := book.get_node("PartySlate")
	for index in range(app.run_heroes.size()):
		var hero: Dictionary = app.run_heroes[index]
		var row := slate.get_node("HeroRow" + str(index))
		_check(row.get_node("HeroName").text == hero.name
			and row.get_node("Health").text == "HP %d / %d" % [hero.hp, hero.max_hp], "left page reflects canonical carried hero")
	_check(slate.get_node("Resources").text == "Deck: %d cards\nGold: %d\nScraps: %d" % [app.run_deck.size(), app.session_gold, app.run_scraps], "left page reflects actual deck and wallets on three supply lines")
	var ids: Array = []
	var actions: Array[Control] = []
	for button in app.route_buttons:
		var id: String = button.get_meta("route_id")
		var kind: String = app.run_map.get_node(id).type
		var projected: String = {"Rest": "Campfire", "Shop": "Peddler"}.get(kind, kind)
		ids.append(id)
		_check(button.get_parent() == app.route_view and button.get_meta("route_kind") == kind
			and button.text == PROJECTED_LABELS.get(projected, projected)
			and button.get_meta("v3_kind") == projected
			and button.get_child_count() == 2, "friendly sewn node keeps exact legal identity, projected kind and token/stitches")
		_check_connected_token(button, projected)
		if not button.disabled:
			actions.append(button)
	_check(not ids.is_empty() and ids == app.run_map.get_legal_choices(), "book shows precisely the real legal choices")
	for button in app.map_mend_buttons:
		_check(button.get_parent() == app.route_view, "Mend remains a direct guarded chooser child")
		if not button.disabled:
			actions.append(button)
	actions.append(app.route_view.get_node("PatchSummaryScroll"))
	actions.append(app.route_map_button)
	actions.append(app.route_back_button)
	var before := _continuation_state()
	actions[0].grab_focus()
	for index in range(actions.size()):
		_check(actions[index].has_focus(), "physical Tab visits every connected action and patch summary")
		await _key(KEY_TAB)
	_check(actions[0].has_focus(), "connected keyboard order wraps to the first route")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.shift_pressed = true
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()
	_check(actions.back().has_focus(), "reverse Tab reaches title exit")
	_check(_continuation_state() == before, "focus traversal preserves route, ledgers and RNG")


func _check_connected_token(button: Button, projected: String) -> void:
	var token = button.get_node_or_null("Token")
	var stitch = button.get_node_or_null("Stitch")
	_check(token != null and stitch != null, "connected choice mounts token and stitch")
	if token == null or stitch == null:
		return
	var path: String = {"Campfire": "res://assets/paper/ui/map_node_campfire.png",
		"Peddler": "res://assets/paper/ui/map_node_peddler.png"}.get(projected, RunRouteAtlas.node_token_path(projected))
	_check(token.token_kind == projected and token.art_path == path and token.get_meta("art_path") == path
		and stitch.get_meta("route_kind") == projected, "connected token art and stitch use independent projected kind")
	var texture: Texture2D = token.token_texture
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		_check(texture == load(path), "connected choice loads matching present art")
	token.token_texture = null
	_check(token.uses_drawn_fallback() and button.is_visible_in_tree()
		and token.token_rect().has_area() and Rect2(Vector2.ZERO, button.size).encloses(token.token_rect())
		and token.mouse_filter == Control.MOUSE_FILTER_IGNORE and token.focus_mode == Control.FOCUS_NONE,
		"deliberate missing connected texture leaves readable inert fallback inside control")
	if projected == "Campfire":
		var plan: Dictionary = token.fallback_plan()
		_check(plan.get("emblem") == "flame_logs" and plan.get("glyph") == ""
			and plan.get("art_bottom", 999.0) <= 52.0,
			"projected Campfire fallback is its fitted flame and logs pictogram")
	elif projected == "Peddler":
		_check(token.fallback_plan().is_empty() and token.patch_colour == Color("#7d7150")
			and token.thread_colour == Color("#e4d59a"), "projected Peddler fallback retains its felt and thread")
	_check(stitch.thread_colour == token.thread_colour
		and button.get_theme_stylebox("normal").border_color == token.thread_colour,
		"connected projected thread agrees on patch, stitch and token")
	var font: Font = button.get_theme_font("font")
	_check(font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		button.get_theme_font_size("font_size")).x <= button.size.x - 72
		and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "projected connected caption and patch fit viewport")
	token.token_texture = texture
	token.queue_redraw()


func _bounds(view: Control) -> void:
	_check(view.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(view.get_global_rect()), "visit fits viewport")
	for control in view.get_children():
		if control is Control:
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "every mounted visit control fits viewport")


func _paid_card(index: int, keyboard: bool) -> void:
	# Let the presenter rebuild its tiles for the post-removal stock/ledger.
	await _frames()
	var stock: Dictionary = app.shop_purchases.get_stock()
	var offer: Dictionary = stock.cards[index]
	var expected: Array = app.run_deck.duplicate()
	expected.append(offer.id)
	var gold: int = app.session_gold - offer.price
	var rng: int = app.run_rng.state
	_check(not offer.sold and gold >= 0, "post-removal purchase fixture is unsold and affordable")
	var listing_tile = _tile_for("offer", index)
	_check(listing_tile != null, "the paid listing owns one sewn offer tile")
	if listing_tile == null:
		return
	if keyboard:
		await _select_tile_by_key(listing_tile)
	else:
		await _click_tile(listing_tile)
	_check(app.shop_offers.selected == index, "real sewn tile selects the paid listing")
	_check(not app.shop_offers.disabled and not app.shop_buy_button.disabled, "valid visit keeps selected affordable stock enabled")
	if keyboard:
		listing_tile.grab_focus()
		for step in range(_visit_tiles().offer_tiles().size() + 2):
			if app.shop_buy_button.has_focus():
				break
			await _key(KEY_TAB)
		_check(app.shop_buy_button.has_focus(), "Tab reaches Buy from the offer tiles after removal")
		await _key(KEY_ENTER)
	else:
		await _click(app.shop_buy_button)
	stock.cards[index].sold = true
	_check(app.run_deck == expected and app.session_gold == gold and app.run_rng.state == rng and app.shop_purchases.get_stock() == stock, "live purchase charges exact price, appends one card and changes only selected sold marker without RNG")
	var ledger: Dictionary = app.shop_visit.get_state()
	var purchases: Dictionary = app.shop_purchases.get_state()
	_check(ledger.deck == expected and purchases.deck == expected and ledger.gold == gold and purchases.gold == gold and ledger.trinkets == purchases.trinkets, "live purchase and visit ledgers agree exactly")
	var before := _continuation_state()
	app.shop_buy_button.pressed.emit()
	_check(_continuation_state() == before, "sold live purchase cannot replay or spend again")


## The random stock is not guaranteed to contain a base pool card. Find a
## genuine uninterrupted battle/reward RNG stream that exercises paid carryover.
func _pool_continuation_fixture(kind: String) -> Dictionary:
	var first := 1
	for attempt in range(40):
		var candidate := _continuation_fixture(kind, first, 50000)
		if candidate.is_empty():
			return {}
		first = candidate.seed + 1
		if not await _routed_win(candidate, false):
			return {}
		await _click(app.reward_buttons[0 if kind == "Shop" else 3])
		await _click(app.continue_button)
		var stock: Dictionary = _stock_oracle().stock
		var found := _unsold_pool_offer_index(stock) >= 0
		app._return_to_title()
		await _frames()
		if found:
			return candidate
	return {}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var stale: Array[Callable] = []
	for kind in ["Rest", "Shop", "Fight"]:
		var fixture := await _pool_continuation_fixture(kind)
		_check(not fixture.is_empty(), "authentic Fight -> Peddler -> " + kind + " fixture")
		var replay: Array = []
		for session in range(2):
			if fixture.is_empty() or not await _routed_win(fixture, false):
				break
			await _click(app.reward_buttons[0 if kind == "Shop" else 3])
			await _click(app.continue_button)
			app.session_gold = 400
			var oracle := _stock_oracle()
			await _click(_route_action(fixture.shop))
			_check(app.peddler_visit != null and app.peddler_buttons.size() == 4, "Peddler mounts real visit")
			if app.peddler_visit == null:
				break
			_check(app.peddler_visit.read_state().stock == oracle.stock and app.run_rng.state == oracle.state, "ongoing RNG matches independent oracle")
			var before := _shop_state()
			for callback in stale:
				_retained_call(callback)
			_check(_shop_state() == before, "old callbacks reject in fresh visit")
			stale.clear()
			for action in app.peddler_buttons + [app.peddler_leave_button]:
				stale.append(action.pressed.get_connections()[0].callable)
			var index := _unsold_pool_offer_index(app.peddler_visit.read_state().stock)
			_check(index >= 0, "genuine stock includes base pool card")
			if index < 0:
				break
			var offer: Dictionary = app.peddler_visit.read_state().stock.cards[index]
			var expected: Array = app.run_deck.duplicate() + [offer.id]
			var rng: int = app.run_rng.state
			if session == 1:
				app.peddler_buttons[index].grab_focus()
				await _key(KEY_ENTER)
			else:
				await _click(app.peddler_buttons[index])
			_check(app.run_deck == expected and app.session_gold == 400 - offer.price and app.run_rng.state == rng
				and app.run_removal_count == 0, "single paid card persists without removal or RNG")
			_check(app.shop_view == null and app.peddler_visit.is_consumed() and app._can_choose_connected_route(), "paid visit admits connected route")
			await _check_connected_book()
			before = _shop_state()
			for callback in stale:
				_retained_call(callback)
			_check(_shop_state() == before, "consumed signals cannot alter route")
			var entry: Button = _route_action(fixture.next)
			var callback: Callable = entry.pressed.get_connections()[0].callable
			app.session_gold += 1
			var changed := _shop_state()
			_retained_call(callback)
			_check(_shop_state() == changed and app.route_view.is_visible_in_tree(), "drifted wallet refuses onward action")
			app.session_gold -= 1
			var witness: Array = app._peddler_witnesses[fixture.shop]
			app._peddler_witnesses.erase(fixture.shop)
			_check(not app._can_choose_connected_route(), "missing completion witness blocks route")
			_retained_call(callback)
			_check(app.run_map.get_current_node_id() == fixture.shop, "forged completion cannot enter next node")
			app._peddler_witnesses[fixture.shop] = witness
			_check(app._can_choose_connected_route(), "authentic completion remains retryable")
			await _click(entry)
			_check(app.run_map.get_current_node_id() == fixture.next and app.run_deck == expected, "real next node receives paid deck")
			if kind == "Fight":
				_check(app.party != null and app.deck != null and app.round_flow._started
					and app._current_carryover_fight(), "real next Fight starts canonical models")
			elif kind == "Shop":
				_check(app.peddler_visit.is_open() and app.peddler_visit.read_state().state.deck == expected, "next Peddler is fresh")
				await _click(app.peddler_leave_button)
			else:
				_check(app.campfire_visit != null and app.campfire_view.is_visible_in_tree(), "next Rest has real Campfire actions")
				# The undamaged party's Heal forecast gains nothing, so Heal is
				# disabled and the enabled Leave closes the stop instead.
				_check(app.campfire_heal_button.disabled and not app.campfire_leave_button.disabled,
					"next Rest shows its zero-gain Heal disabled")
				await _click(app.campfire_heal_button)
				_check(not app._campfire_closed
					and app.campfire_visit.read_state().status == RunCampfireVisit.OPEN,
					"disabled Heal cannot spend the next Rest")
				await _click(app.campfire_leave_button)
				_check(app._campfire_closed and app._can_choose_connected_route(), "next Rest Leave closes and admits onward play")
			var observation := [app.run_map.get_route(), app.run_deck.duplicate(), app.session_gold,
				app.run_rng.state, app.run_heroes.duplicate(true), app.run_trinkets.duplicate()]
			if session == 0:
				replay = observation
			else:
				_check(observation == replay, "mouse/keyboard replay matches next node state")
			app._return_to_title()
			await _frames()
			for old in stale:
				_retained_call(old)
			_check(app.peddler_visit == null and app.run_map == null and app.run_deck.is_empty(), "title clears service and stale actions")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_continuation_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _is_shop_base_pool(card_id: String) -> bool:
	return card_id in [
		"warden_hold_the_line", "warden_patch_guard", "warden_quick_darn",
		"warden_brass_buckle", "warden_iron_hem", "warden_bastion_quilt",
		"seamstress_thread_whip", "seamstress_running_stitch",
		"seamstress_darning", "seamstress_thimble_tea",
		"seamstress_hemorrhage_hem", "seamstress_blanket_stitch",
		"seamstress_field_mend", "seamstress_red_thread"
	]


func _unsold_pool_offer_index(stock: Dictionary) -> int:
	for index in range(stock.get("cards", []).size()):
		var offer: Dictionary = stock.cards[index]
		if not offer.sold and _is_shop_base_pool(String(offer.id)):
			return index
	return -1
