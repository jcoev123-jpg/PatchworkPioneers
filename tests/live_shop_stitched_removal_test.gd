extends "res://tests/live_stitched_next_fight_test.gd"
## Earn a cross-owner stitch at the real Rest, retire it through routed Shop
## controls, then admit the surviving ledger to a connected Rest and battle.

var fixture_gold := 500
var fixture_count := 0


func _prepare_shop_receipt(fixture: Dictionary, keyboard: bool) -> String:
	if not await _routed_win(fixture, false):
		return ""
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	await _click(_route_action(fixture.elite.back()))
	if not await _win_earned_elite():
		return ""
	await _click(app.reward_buttons[3])
	_check(app.run_scraps == 3, "genuine Fight and Elite claims fund Rest stitch")
	# Inject only funding/history before Rest captures its completed-visit guards.
	app.session_gold = fixture_gold
	app.run_removal_count = fixture_count
	await _click(app.continue_button)
	await _click(_route_action(fixture.rest.back()))
	_check(app.rest_stitch != null and app.rest_stitch.is_valid() and not app.rest_stitch_button.disabled,
		"connected Rest offers genuine funded stitch")
	if app.rest_stitch == null or app.rest_stitch_button.disabled:
		return ""
	var source: Dictionary = app._stitch_snapshot()
	var first: int = app.run_deck.find("seamstress_prick")
	var second: int = app.run_deck.find("tinker_pop_shot")
	_check(first >= 0 and second >= 0, "cross-owner original cards are owned")
	if first < 0 or second < 0:
		return ""
	var oracle := RunRestStitchCards.new(source.deck, source.descriptors, source.remaining_scraps, source.next_stitch_id)
	var made := oracle.choose_stitch(first, second, source)
	_check(made.ok, "canonical Rest service issues authentic cross-owner receipt")
	await _select_stitch(app.rest_stitch_first, first, keyboard)
	await _select_stitch(app.rest_stitch_second, second, keyboard)
	if keyboard:
		app.rest_stitch_button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(app.rest_stitch_button)
	_check(app.rest_stitch.is_consumed() and app._stitch_snapshot() == oracle.get_snapshot(),
		"real Rest controls commit the exact canonical receipt")
	await _click(app.rest_continue_button)
	return made.stitched_id if app.rest_stitch.is_consumed() else ""


func _shop_fixture() -> Dictionary:
	for value in range(1, 20001):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for elite in map.get_node(fight).outgoing:
				if map.get_node(elite).type != "Elite":
					continue
				for rest in map.get_node(elite).outgoing:
					if map.get_node(rest).type != "Rest":
						continue
					for shop in map.get_node(rest).outgoing:
						if map.get_node(shop).type != "Shop":
							continue
						for later in map.get_node(shop).outgoing:
							if map.get_node(later).type != "Rest":
								continue
							for battle in map.get_node(later).outgoing:
								if map.get_node(battle).type != "Fight":
									continue
								map.choose_node(fight)
								var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
								if entry.get("encounter_id") == "starter_attacks":
									return {"seed": value, "fight": fight, "elite": [elite], "rest": [rest],
										"shop": shop, "later": later, "battle": battle}
								map.undo_choice(fight, [])
	return {}


func _ledger_state() -> Array:
	return [_admission_state(), app.session_gold, app.run_removal_count,
		app.run_trinkets.duplicate(),
		app.shop_visit.get_state() if app.shop_visit != null else {},
		app.shop_purchases.get_state() if app.shop_purchases != null else {},
		app.shop_purchases.get_stock() if app.shop_purchases != null else {}]


func _reject_shop(callbacks: Array[Callable], reason: String) -> void:
	var before := _ledger_state()
	for callback in callbacks:
		callback.call()
	_check(_ledger_state() == before, reason + " preserves deck, descriptors, cursor, wallet, count, route and RNG")


func _select_shop_row(group: String, row: int, keyboard: bool) -> void:
	await _frames()
	var gallery = app.get_node("LiveVisitCardTiles")
	var tiles: Array = gallery.removal_tiles() if group == "removal" else gallery.offer_tiles()
	var selected: Button
	for tile in tiles:
		if gallery.tile_row(tile) == row:
			selected = tile
	_check(selected != null, "actual mounted " + group + " row exists")
	if selected == null:
		return
	gallery.gallery_scroll().ensure_control_visible(selected)
	await _frames()
	if keyboard:
		selected.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(selected)
	_check((app.shop_cards.selected if group == "removal" else app.shop_offers.selected) == row,
		"physical input selects exact backing row")


func _buy_stitch_shop(row: int, keyboard: bool) -> void:
	var stock: Dictionary = app.shop_purchases.get_stock()
	var offer: Dictionary = stock.cards[row]
	var deck_before: Array = app.run_deck.duplicate()
	var gold_before: int = app.session_gold
	var registry: Dictionary = app.run_stitch_descriptors.duplicate(true)
	var cursor: int = app.run_next_stitch_id
	_check(not offer.sold and gold_before >= offer.price, "purchase is unsold and funded")
	await _select_shop_row("offer", row, keyboard)
	if keyboard:
		app.shop_buy_button.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(app.shop_buy_button)
	stock.cards[row].sold = true
	_check(app.run_deck == deck_before + [offer.id] and app.session_gold == gold_before - offer.price
		and app.shop_purchases.get_stock() == stock and app.run_stitch_descriptors == registry
		and app.run_next_stitch_id == cursor and app._current_shop_ledger(),
		"purchase preserves stitch ownership and cursor while publishing exact paid card and sold marker")
	_reject_shop([app.shop_buy_button.pressed.get_connections()[0].callable], "sold purchase replay")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _shop_fixture()
	_check(not fixture.is_empty(), "seeded Fight-Elite-Rest-Shop-Rest-Fight route exists")
	var stale: Array[Callable] = []
	var replay: Array = []
	if not fixture.is_empty():
		for session in range(4):
			var keyboard := session == 1
			var poor := session == 2
			fixture_gold = 74 if poor else 500
			fixture_count = 2 if keyboard else 0
			var stitched := await _prepare_shop_receipt(fixture, keyboard)
			_check(not stitched.is_empty() and app.run_stitch_descriptors.has(stitched),
				"genuine mounted Rest receipt owns the cross-owner composite")
			if stitched.is_empty():
				break
			_reject_shop(stale, "previous-session retained callbacks")
			var entry = _route_action(fixture.shop)
			_check(entry != null, "connected Shop control exists")
			if entry == null:
				break
			var enter: Callable = entry.pressed.get_connections()[0].callable
			var registry: Dictionary = app.run_stitch_descriptors.duplicate(true)
			app.run_stitch_descriptors[stitched].cost += 1
			_reject_shop([enter], "forged descriptor refuses Shop entry")
			_check(app.shop_visit == null, "forged entry never mounts a Shop")
			app.run_stitch_descriptors = registry.duplicate(true)
			app.run_next_stitch_id = 1
			_reject_shop([enter], "stale allocator refuses Shop entry")
			app.run_next_stitch_id = 2
			await _click(entry)
			_check(app.shop_visit != null and app.shop_purchases != null and app._current_shop_ledger()
				and app._shop_patch_current(), "real Shop mounts synchronized stitched visit, purchase and wardrobe ledgers")
			if app.shop_visit == null or app.shop_purchases == null:
				break
			var remove: Callable = app.shop_remove_button.pressed.get_connections()[0].callable
			var buy: Callable = app.shop_buy_button.pressed.get_connections()[0].callable
			var exit: Callable = app.shop_continue_button.pressed.get_connections()[0].callable
			stale = [remove, buy, exit]
			for field in ["run_stitch_descriptors", "run_next_stitch_id"]:
				var saved: Variant = app.get(field)
				app.set(field, {} if field == "run_stitch_descriptors" else 3)
				_reject_shop(stale, "stale live " + field + " blocks removal, buying and Continue")
				app.set(field, saved)
			app.shop_purchases._state.gold += 1
			_reject_shop([remove, buy], "stale purchase ledger")
			app.shop_purchases._state.gold -= 1
			app.shop_cards.select(-1)
			_reject_shop([remove], "unavailable selection")
			app.shop_cards.select(0)
			app.shop_cards.set_item_text(0, "stitched_999999")
			_reject_shop([remove], "forged selected row")
			app.shop_cards.set_item_text(0, app.run_deck[0])
			if not poor:
				await _buy_stitch_shop(0, keyboard)
			var target: String = "warden_strike" if keyboard else stitched
			var row: int = app.run_deck.find(target)
			_check(row >= 0 and app.run_deck.count(stitched) == 1, "selected owned card and separate composite are real")
			await _select_shop_row("removal", row, keyboard)
			var before := _ledger_state()
			var expected: Array = app.run_deck.duplicate()
			expected.erase(target)
			var descriptors: Dictionary = registry.duplicate(true)
			if not keyboard:
				descriptors.erase(stitched)
			var gold: int = app.session_gold
			var count: int = app.run_removal_count
			if keyboard:
				app.shop_remove_button.grab_focus()
				await _key(KEY_ENTER)
			else:
				await _click(app.shop_remove_button)
			if poor:
				_check(_ledger_state() == before and app.shop_visit.get_state().removal_available,
					"insufficient funds leave entire authentic composite and all ledgers unchanged")
				_reject_shop([remove], "insufficient funds callback")
			else:
				_check(app.run_deck == expected and app.run_stitch_descriptors == descriptors
					and app.run_next_stitch_id == 2 and app.session_gold == gold - 75 - 25 * count
					and app.run_removal_count == count + 1, "physical Remove atomically publishes exact five-field retirement and rising debit")
				var visit: Dictionary = app.shop_visit.get_state()
				var purchases: Dictionary = app.shop_purchases.get_state()
				_check(visit.deck == expected and visit.descriptors == descriptors and visit.next_stitch_id == 2
					and visit.gold == app.session_gold and visit.prior_removals == count + 1 and visit.status == "used"
					and purchases.deck == expected and purchases.gold == app.session_gold
					and app.shop_purchases.get_stock() == before[6] and app.run_trinkets == before[3]
					and app.run_rng.state == before[0][0][0][3] and app._shop_patch_current(),
					"both ledgers, stock, trinkets, RNG and wardrobe agree after removal")
				_reject_shop([remove], "repeated removal callback")
				app.shop_remove_button.disabled = false
				app.shop_cards.disabled = false
				_reject_shop([remove], "forced enabled repeated removal")
				app._refresh_shop()
				var after_removal := _ledger_state()
				await _click(app.shop_remove_button)
				app.shop_remove_button.grab_focus()
				await _key(KEY_SPACE)
				_check(_ledger_state() == after_removal, "repeated mouse and keyboard removal cannot debit or remove twice")
				await _buy_stitch_shop(1, keyboard)
				_check(app.shop_remove_button.disabled, "post-removal purchase keeps one-use removal disabled")
				if session == 0:
					replay = [app._stitch_snapshot(), app.session_gold, app.run_removal_count,
						app.run_rng.state, app.run_map.get_route(), app.shop_visit.get_state(),
						app.shop_purchases.get_state(), app.shop_purchases.get_stock()]
				elif session == 3:
					_check([app._stitch_snapshot(), app.session_gold, app.run_removal_count,
						app.run_rng.state, app.run_map.get_route(), app.shop_visit.get_state(),
						app.shop_purchases.get_state(), app.shop_purchases.get_stock()] == replay,
						"same seeded mounted Rest-Shop timeline replays complete ledgers and RNG")
			await _click(app.shop_continue_button)
			_check(app.route_view != null and app.shop_visit.get_state().status == "closed", "real Continue closes Shop into connected route")
			_reject_shop(stale, "closed Shop callbacks")
			await _click(_route_action(fixture.later))
			_check(app.rest_stitch != null and app.rest_stitch.is_valid()
				and app.rest_stitch.get_snapshot() == app._stitch_snapshot(), "connected later Rest accepts exact surviving ledger")
			_reject_shop(stale, "old Shop callbacks in later Rest")
			await _click(app.rest_heal_button)
			await _click(app.rest_continue_button)
			await _click(_route_action(fixture.battle))
			_check(app.run_map.get_current_node_id() == fixture.battle and app.battle_view.is_visible_in_tree()
				and app.deck != null and app.deck.hand.size() == 5, "connected battle admits surviving stitched ledger through real route")
			_reject_shop(stale, "old Shop callbacks in later battle")
			await _click(app.return_button)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_stitched_removal_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
