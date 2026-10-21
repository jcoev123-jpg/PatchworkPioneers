extends "res://tests/live_elite_reward_continuation_test.gd"
## Physical routed Shop transactions, persistent wardrobe and complete rejection guards.

var wardrobe: RunPatchWardrobe


func _sequence_fixture(kinds: Array, first_seed: int = 1, direct_last: bool = false) -> Dictionary:
	for value in range(first_seed, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			var paths := []
			var source: String = first
			for kind in kinds:
				var path := _path_to(map, source, kind)
				if path.is_empty():
					break
				paths.append(path)
				source = path.back()
			if paths.size() != kinds.size():
				continue
			if direct_last and paths.back().size() != 1:
				continue
			map.choose_node(first)
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
			if entry.get("encounter_id") == "starter_attacks":
				return {"seed": value, "fight": first, "paths": paths}
	return {}


func _patch_state() -> Array:
	return [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.run_trinkets.duplicate(),
		app.session_gold, app.run_scraps, app.run_removal_count, app.run_rng.state,
		app.run_map.get_route(), app.run_map.get_floors(), app.party_carryover.read_state(),
		app.party_carryover.torn.read_state(), app.party_carryover._receipts.duplicate(true),
		app.shop_visit.get_state(), app.shop_purchases.get_state(), app.shop_purchases.get_stock(),
		wardrobe.get_snapshot(), app.party_carryover._wardrobe]


func _reject_buy(callback: Callable, reason: String) -> void:
	var before := _patch_state()
	callback.call()
	_check(_patch_state() == before, reason + " leaves all ledgers, history and RNG unchanged")


func _activate(control: Control, keyboard: bool) -> void:
	if keyboard:
		control.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(control)


func _reach(path: Array, keyboard: bool) -> void:
	var transit := path.duplicate()
	var destination: String = transit.pop_back()
	await _visit_path(transit, keyboard)
	await _activate(_route_action(destination), keyboard)


func _settle_battle(keyboard: bool, down_position: int = 0, reward_index: int = 3) -> void:
	_check(app.party != null and app.enemies != null and not app._battle_closed,
		"connected combat fixture has real live actors")
	if down_position > 0:
		_check(app.party.apply_damage(down_position, 9999), "genuine combat downs wearer")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999), "defeat genuine mounted enemy")
	app._observe_battle_result()
	await _frames()
	_check(app.reward_buttons.size() == 4, "genuine victory offers reward and Skip")
	if app.reward_buttons.size() == 4:
		await _activate(app.reward_buttons[reward_index], keyboard)
	_check(app.fight_reward_claimed and is_instance_valid(app.continue_button), "reward commits once")


func _negative_inputs(callback: Callable) -> void:
	var picker: OptionButton = app.shop_patch_offers
	var heroes: OptionButton = app.shop_patch_heroes
	for control in [app.shop_patch_buy_button, picker, heroes]:
		control.disabled = true
		_reject_buy(callback, "disabled control")
		control.disabled = false
		control.hide()
		_reject_buy(callback, "hidden control")
		control.show()
	var id: Variant = picker.get_item_metadata(0)
	for forged in ["unstocked", app.shop_purchases.get_stock().trinkets[1].id, 12]:
		picker.set_item_metadata(0, forged)
		_reject_buy(callback, "forged stock selection")
	picker.set_item_metadata(0, id)
	var text := picker.get_item_text(0)
	picker.set_item_text(0, "forged 1 gold quote")
	_reject_buy(callback, "forged price")
	picker.set_item_text(0, text)
	var owner: Variant = heroes.get_item_metadata(0)
	heroes.set_item_metadata(0, "foreign")
	_reject_buy(callback, "wrong hero")
	heroes.set_item_metadata(0, owner)
	var slot: String = wardrobe._definitions[id]
	wardrobe._definitions[id] = "COAT" if slot != "COAT" else "HEAD"
	_reject_buy(callback, "drifted authored slot")
	wardrobe._definitions[id] = slot
	app.session_gold += 1
	_reject_buy(callback, "drifted purse cannot auto-repair")
	app.session_gold -= 1
	app.run_scraps += 1
	_reject_buy(callback, "drifted scraps")
	app.run_scraps -= 1
	app.run_deck.append("warden_strike")
	_reject_buy(callback, "drifted deck")
	app.run_deck.pop_back()
	app.run_heroes[0].hp -= 1
	_reject_buy(callback, "drifted roster")
	app.run_heroes[0].hp += 1
	app.shop_purchases._state.gold += 1
	_reject_buy(callback, "drifted purchase ledger")
	app.shop_purchases._state.gold -= 1
	wardrobe._gold += 1
	_reject_buy(callback, "drifted wardrobe cannot auto-repair")
	wardrobe._gold -= 1
	wardrobe._operations.append("forged-operation")
	_reject_buy(callback, "drifted operation history")
	wardrobe._operations.pop_back()
	var rng_state: int = app.run_rng.state
	app.run_rng.randi()
	_reject_buy(callback, "drifted run RNG")
	app.run_rng.state = rng_state
	var map: RunMap = app.run_map
	var other := RunMap.new()
	other._floor_ids = map._floor_ids.duplicate(true)
	other._nodes = map._nodes.duplicate(true)
	other._route = map.get_route()
	app.run_map = other
	_reject_buy(callback, "foreign same-graph map")
	app.run_map = map
	var node := map.get_current_node_id()
	map._nodes[node].outgoing.append("foreign")
	_reject_buy(callback, "graph drift")
	map._nodes[node].outgoing.pop_back()
	map._route.pop_back()
	_reject_buy(callback, "stale route")
	map._route.append(node)
	app.shop_view.hide()
	_reject_buy(callback, "hidden view")
	app.shop_view.show()
	var view: VBoxContainer = app.shop_view
	var foreign_view := VBoxContainer.new()
	app.shop_view = foreign_view
	_reject_buy(callback, "replaced view")
	app.shop_view = view
	foreign_view.free()
	_reject_buy(app._buy_shop_patch.bind(app.shop_visit, app.shop_purchases, app.shop_buy_button), "foreign action")
	_reject_buy(app._buy_shop_patch.bind(RunShopVisit.new([], 0, 0), app.shop_purchases, app.shop_patch_buy_button), "foreign visit")
	var carry: RunTornCarryover = app.party_carryover
	var previous := carry._wardrobe
	carry._wardrobe = RunPatchWardrobe.new()
	_reject_buy(callback, "carryover cannot accept this wardrobe")
	carry._wardrobe = previous


func _purchase(index: int, keyboard: bool, wearer: int = -1) -> void:
	if wearer < 0:
		wearer = index
	var before := _patch_state()
	var stock: Dictionary = app.shop_purchases.get_stock()
	var offer: Dictionary = stock.trinkets[index]
	_check(not offer.sold and offer.price == 100 and app.session_gold >= 100,
		"selected genuine 100 gold offer is affordable and unsold")
	await _pick(app.shop_patch_offers, index, keyboard)
	await _pick(app.shop_patch_heroes, wearer, keyboard)
	if keyboard:
		app.shop_patch_heroes.grab_focus()
		await _key(KEY_TAB)
		_check(app.shop_patch_buy_button.has_focus(), "physical Tab reaches sew action from hero picker")
		await _key(KEY_ENTER)
	else:
		await _click(app.shop_patch_buy_button)
	var state := wardrobe.get_snapshot()
	_check(state.worn[app.run_heroes[wearer].id][state.definitions[offer.id]] == offer.id,
		"paid patch is immediately sewn into selected hero authored slot")
	_check(app.session_gold == before[3] - 100 and state.gold == app.session_gold
		and app.run_deck == before[1] and app.run_rng.state == before[6]
		and state.operation_ids.size() == before[15].operation_ids.size() + 1,
		"exactly one charge and operation, unchanged deck and RNG")
	stock.trinkets[index].sold = true
	_check(app.shop_purchases.get_stock() == stock and app.party_carryover._wardrobe == wardrobe,
		"only selected stock sold and same wardrobe bound")
	_check(app.shop_visit.get_state().trinkets == state.owned
		and app.shop_purchases.get_state().trinkets == state.owned and app.run_trinkets == state.owned
		and app.shop_visit.get_state().gold == state.gold and app.shop_purchases.get_state().gold == state.gold,
		"all complete ownership and gold ledgers agree")
	_reject_buy(app.shop_patch_buy_button.pressed.get_connections()[0].callable, "sold offer replay")
	app.shop_patch_buy_button.disabled = false
	_reject_buy(app.shop_patch_buy_button.pressed.get_connections()[0].callable, "forced enabled sold offer")
	app._refresh_shop()


func _pick(picker: OptionButton, index: int, keyboard: bool) -> void:
	await _activate(picker, keyboard)
	var popup := picker.get_popup()
	_check(popup.visible, "physical input opens real patch/hero popup")
	if keyboard:
		await _key(KEY_HOME)
		for step in range(index):
			await _key(KEY_DOWN)
		await _key(KEY_ENTER)
	else:
		var point := Vector2(popup.position) + Vector2(popup.size.x * 0.5,
			popup.size.y * (index + 0.5) / picker.item_count)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		await _frames()
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
		await _frames()
	_check(picker.selected == index and not popup.visible, "physical popup selects exact real item")


func _poor_and_replacement() -> void:
	var fixture := _sequence_fixture(["Shop"])
	_check(not fixture.is_empty(), "real opening Fight leads to replacement/poor Shop")
	if fixture.is_empty():
		return
	for funded in [false, true]:
		if not await _routed_win(fixture, false):
			return
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		var old_patch := ""
		var target := 0
		if funded:
			app.session_gold = 500
			var stock := _stock_oracle()
			var replacement_id := ""
			for i in range(2):
				var id: String = stock.stock.trinkets[i].id
				if id in ["stitched_badge", "spare_spool"]:
					replacement_id = id
					target = i
					old_patch = "button_eye" if id == "stitched_badge" else "pincushion_arm"
					break
			_check(not replacement_id.is_empty(), "real stock contains a patch with an authored occupied-slot fixture")
			var definitions := []
			for path in ["initial_patch_slots", "m04_attack_patches", "m04_coat_patches"]:
				for record in JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/%s.json" % path)):
					definitions.append({"id": record.id, "slot": record.slot})
			app.run_trinkets.assign([old_patch])
			wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, definitions,
				app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
			_check(wardrobe.sew(old_patch, app.run_heroes[target].id,
				wardrobe.get_snapshot().definitions[old_patch], "fixture:prior-wear", wardrobe.get_snapshot()).ok,
				"genuine authored old ownership is sewn before Shop")
			_check(app.party_carryover.bind_wardrobe(wardrobe, app.party_carryover.torn, wardrobe.get_snapshot()),
				"real carryover accepts existing worn fixture")
		await _reach(fixture.paths[0], false)
		wardrobe = app._shop_wardrobe
		var callback: Callable = app.shop_patch_buy_button.pressed.get_connections()[0].callable
		if not funded:
			_check(app.session_gold < 100 and app.shop_patch_buy_button.disabled,
				"natural reward cannot afford paid patch")
			var before := _patch_state()
			callback.call()
			await _click(app.shop_patch_buy_button)
			await _activate(app.shop_patch_buy_button, true)
			app.shop_patch_buy_button.disabled = false
			callback.call()
			_check(_patch_state() == before, "unaffordable callback/mouse/keyboard/forced action cannot spend")
		else:
			var before := wardrobe.get_snapshot()
			await _purchase(target, false)
			var after := wardrobe.get_snapshot()
			var expected_owned: Array = before.owned.duplicate()
			expected_owned.erase(old_patch)
			expected_owned.append(app.shop_purchases.get_stock().trinkets[target].id)
			_check(after.owned == expected_owned and app.run_trinkets == expected_owned
				and after.scraps == before.scraps + 1 and app.run_scraps == after.scraps,
				"replacement destroys only displaced ownership and grants exactly one scrap")
			var expected_worn: Dictionary = before.worn.duplicate(true)
			var bought: String = app.shop_purchases.get_stock().trinkets[target].id
			expected_worn[app.run_heroes[target].id][after.definitions[bought]] = bought
			_check(after.worn == expected_worn and after.operation_ids.slice(0, -1) == before.operation_ids,
				"replacement retains all other assignments and prior operation history")
			await _purchase(1 - target, false)
			var deck: Array = app.run_deck.duplicate()
			deck.erase(deck[app.shop_cards.selected])
			var gold: int = app.session_gold
			await _click(app.shop_remove_button)
			_check(app.run_deck == deck and app.session_gold == gold - 75
				and wardrobe.get_snapshot().cards == deck and wardrobe.get_snapshot().gold == app.session_gold,
				"patch-first removal synchronizes only committed wardrobe context")
		await _click(app.shop_back_button)
		callback.call()
		_check(app.run_map == null and app.session_gold == 0, "Shop title discards retained purchase callback")


func _unsewn_elite_before_shop() -> void:
	var fixture := _sequence_fixture(["Elite", "Shop", "Elite"])
	_check(not fixture.is_empty(), "real path supports skipped Elite sew before Shop and later Elite")
	if fixture.is_empty() or not await _routed_win(fixture, false):
		return
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	app.session_gold = 500
	await _reach(fixture.paths[0], false)
	await _settle_battle(false)
	var sewing = app.get_node("LiveElitePatchSewing")
	_check(sewing.wardrobe != null and sewing.hero_buttons.size() == 3
		and app.party_carryover._wardrobe == null,
		"prior Elite really offers sewing but player leaves it unbound")
	await _click(app.continue_button)
	await _reach(fixture.paths[1], false)
	wardrobe = app._shop_wardrobe
	var available := -1
	for i in range(2):
		if not app.shop_purchases.get_stock().trinkets[i].sold:
			available = i
			break
	_check(available >= 0, "later Shop has genuine unowned stock")
	if available >= 0:
		await _purchase(available, false)
	await _click(app.shop_continue_button)
	await _reach(fixture.paths[2], false)
	await _settle_battle(false)
	_check(sewing.wardrobe == wardrobe and sewing.hero_buttons.size() == 3
		and sewing._eligible(), "confirmed later Elite adopts bound Shop ledger after earlier skipped sewing")
	await _click(sewing.hero_buttons[2])
	_check(wardrobe.get_snapshot().operation_ids.size() == 2, "Shop and later Elite retain exactly two sew operations")
	await _click(app.continue_button)
	await _click(app.route_back_button)


## A confirmed routed Fight between two Shops hands its committed reward to the
## very wardrobe the first Shop bound; otherwise every second-Shop action fails.
func _shop_fight_shop() -> void:
	var fixture := _sequence_fixture(["Shop", "Fight", "Shop"])
	_check(not fixture.is_empty(), "real seeded route supports Shop -> Fight -> Shop")
	if fixture.is_empty() or not await _routed_win(fixture, false):
		return
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	app.session_gold = 500 # Funding only; the route, stock and rewards are real.
	await _reach(fixture.paths[0], false)
	var bound: RunPatchWardrobe = app._shop_wardrobe
	wardrobe = bound
	_check(bound != null and bound.is_valid(), "first Shop offers a real wardrobe")
	if bound == null:
		return
	var first_id: String = app.shop_purchases.get_stock().trinkets[0].id
	await _purchase(0, false)
	_check(app.party_carryover._wardrobe == bound, "first paid patch binds that wardrobe to the run")
	var sewn: Dictionary = bound.get_snapshot()
	var wearer: String = app.run_heroes[0].id
	_check(sewn.worn[wearer][sewn.definitions[first_id]] == first_id,
		"first paid patch is sewn to the chosen wearer before Continue")
	var scraps: int = app.run_scraps
	var purse: int = app.session_gold
	var deck: Array = app.run_deck.duplicate()
	await _click(app.shop_continue_button)
	await _reach(fixture.paths[1], false)
	await _settle_battle(false, 0, 0)
	var committed_gold: int = app.session_gold
	var committed_deck: Array = app.run_deck.duplicate()
	var committed_owned: Array = app.run_trinkets.duplicate()
	var committed_heroes: Array = app.run_heroes.duplicate(true)
	_check(committed_gold > purse and app.run_scraps == scraps + 1
		and committed_deck.size() == deck.size() + 1,
		"real Fight victory pays gold, exactly one scrap and one claimed card")
	var at_claim: Dictionary = bound.get_snapshot()
	_check(at_claim.gold == committed_gold and at_claim.scraps == app.run_scraps
		and at_claim.cards == committed_deck and at_claim.owned == committed_owned
		and at_claim.heroes == committed_heroes,
		"the committed reward synchronises the bound wardrobe before the next route")
	await _click(app.continue_button)
	await _reach(fixture.paths[2], false)
	_check(app._shop_wardrobe == bound and app.party_carryover._wardrobe == bound,
		"second Shop adopts the identical wardrobe object after the rewarded Fight")
	var synced: Dictionary = bound.get_snapshot()
	_check(synced.gold == committed_gold and synced.scraps == app.run_scraps
		and synced.cards == committed_deck and synced.owned == committed_owned
		and synced.heroes == committed_heroes and synced.seed == sewn.seed
		and synced.rest_id == "",
		"reward synchronises the bound wardrobe's exact gold, scraps, deck, ownership and heroes")
	_check(app._shop_patch_current(), "the committed reward keeps every second-Shop action current")
	_check(synced.worn == sewn.worn and synced.operation_ids == sewn.operation_ids
		and synced.definitions == sewn.definitions,
		"reward synchronisation preserves worn slots, definitions and sewing history")
	var rng: int = app.run_rng.state
	var remaining := -1
	for i in range(2):
		if not app.shop_purchases.get_stock().trinkets[i].sold:
			remaining = i
			break
	_check(remaining >= 0, "second Shop stocks a genuinely unsold patch")
	if remaining >= 0:
		var second_id: String = app.shop_purchases.get_stock().trinkets[remaining].id
		await _purchase(remaining, true)
		var after_sew: Dictionary = bound.get_snapshot()
		_check(after_sew.worn[app.run_heroes[remaining].id][after_sew.definitions[second_id]] == second_id
			and after_sew.worn[wearer][after_sew.definitions[first_id]] == first_id
			and after_sew.operation_ids.size() == sewn.operation_ids.size() + 1
			and after_sew.operation_ids.slice(0, sewn.operation_ids.size()) == sewn.operation_ids,
			"second paid patch sews once after the Fight and appends to preserved history")
	var card: Dictionary = app.shop_purchases.get_stock().cards[0]
	var buying: Array = app.run_deck.duplicate()
	purse = app.session_gold
	app.shop_offers.select(0)
	app.shop_offers.item_selected.emit(0)
	_check(not card.sold and purse >= card.price and not app.shop_buy_button.disabled,
		"second Shop still sells an affordable card after the Fight")
	await _click(app.shop_buy_button)
	_check(app.run_deck == buying + [card.id] and app.session_gold == purse - card.price
		and bound.get_snapshot().cards == app.run_deck and bound.get_snapshot().gold == app.session_gold,
		"ordinary card purchase charges once and synchronises the same wardrobe")
	var removing: Array = app.run_deck.duplicate()
	removing.erase(removing[app.shop_cards.selected])
	purse = app.session_gold
	_check(app.shop_visit.get_state().removal_available and not app.shop_remove_button.disabled,
		"second Shop removal is genuinely available after the Fight")
	await _click(app.shop_remove_button)
	_check(app.run_deck == removing and app.session_gold == purse - 75
		and bound.get_snapshot().cards == app.run_deck and bound.get_snapshot().gold == app.session_gold,
		"single removal after the Fight charges 75 and synchronises the same wardrobe")
	_check(app.run_rng.state == rng and app.party_carryover._wardrobe == bound,
		"second-Shop paid actions consume no RNG and keep the same bound wardrobe")
	await _click(app.shop_continue_button)
	await _click(app.route_back_button)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var sewing = app.get_node("LiveElitePatchSewing")
	var retained: Array[Callable] = []
	var saw_coat := false
	for elite_first in [false, true]:
		var kinds := ["Elite", "Shop", "Fight"] if elite_first else ["Shop", "Fight", "Elite"]
		var fixture := _sequence_fixture(kinds)
		_check(not fixture.is_empty(), "generated real route supports order " + str(kinds))
		if fixture.is_empty():
			continue
		var replay: Array = []
		for session in range(2):
			var keyboard := session == 1
			seed(102102)
			var global_next := randi()
			seed(102102)
			if not await _routed_win(fixture, false):
				break
			await _activate(app.reward_buttons[3], keyboard)
			await _activate(app.continue_button, keyboard)
			app.session_gold = 500 # Fund the real transaction before a wardrobe exists.
			if elite_first:
				await _reach(fixture.paths[0], keyboard)
				await _settle_battle(keyboard)
				_check(sewing.hero_buttons.size() == 3, "pre-Shop Elite has real sewing choices")
				await _activate(sewing.hero_buttons[0], keyboard)
				wardrobe = sewing.wardrobe
				await _activate(app.continue_button, keyboard)
			await _reach(fixture.paths[1 if elite_first else 0], keyboard)
			_check(app.shop_view.is_visible_in_tree() and app.shop_patch_offers.item_count == 2,
				"real routed entry mounts both actual offers")
			wardrobe = app._shop_wardrobe
			_check(wardrobe != null and wardrobe.is_valid(), "real wardrobe exists")
			if wardrobe == null:
				break
			for control in [app.shop_view, app.shop_patch_offers, app.shop_patch_heroes,
				app.shop_patch_buy_button, app.shop_continue_button, app.shop_back_button]:
				_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
					"all Shop controls fit 1280x720")
			var callback: Callable = app.shop_patch_buy_button.pressed.get_connections()[0].callable
			for old in retained:
				_reject_buy(old, "prior run callback")
			_negative_inputs(callback)
			# Card/removal commit before patches; the opposite order is covered below.
			await _activate(app.shop_buy_button, keyboard)
			await _activate(app.shop_remove_button, keyboard)
			for i in range(2):
				var offer: Dictionary = app.shop_purchases.get_stock().trinkets[i]
				if not offer.sold:
					saw_coat = saw_coat or offer.id == "quilted_coat"
					await _purchase(i, keyboard)
			await _activate(app.shop_buy_button, keyboard) # sold card is harmless
			app.shop_offers.select(1)
			app.shop_offers.item_selected.emit(1)
			var old_gold: int = app.session_gold
			await _activate(app.shop_buy_button, keyboard)
			_check(app.session_gold == old_gold - app.shop_purchases.get_stock().cards[1].price,
				"card purchase remains usable after patch commits")
			var worn: Dictionary = wardrobe.get_snapshot().worn
			var observation := _patch_state()
			# Object identities are deliberately omitted from deterministic replay.
			observation.pop_back()
			if session == 0:
				replay = observation
			else:
				_check(observation == replay, "mouse/keyboard same-seed complete ledgers and RNG replay identically")
			retained.append(callback)
			await _activate(app.shop_continue_button, keyboard)
			_reject_buy(callback, "Shop Continue retires action")
			await _reach(fixture.paths[2 if elite_first else 1], keyboard)
			_check(app.party_carryover._wardrobe == wardrobe and wardrobe.get_snapshot().worn == worn,
				"same assignments persist into next routed Fight")
			var base: Array = app.party_carryover.read_state().heroes
			for hero in app.party.get_heroes():
				var original: Dictionary = base.filter(func(h): return h.id == hero.id)[0]
				var bonus := 6 if worn[hero.id].COAT == "quilted_coat" else 0
				_check(hero.max_hp == original.max_hp + bonus and hero.hp == original.hp,
					"next Fight +6 cap applies only to coat wearer without healing")
			var down_position := 1
			for hero in app.party.get_heroes():
				if worn[hero.id].COAT == "quilted_coat":
					down_position = hero.position
			var down_owner: String = app.party.get_hero(down_position).id
			_check(worn[down_owner].values().any(func(id): return id != ""), "tear fixture actually wears a purchased patch")
			await _settle_battle(keyboard, down_position)
			var active := wardrobe.project_active(app.party_carryover.torn.read_state())
			_check(active.ok and active.active[down_owner].is_empty() and wardrobe.get_snapshot().worn == worn,
				"genuine tear suppresses downed wearer's patches without deleting assignments")
			var projected: CombatParty = app.party_carryover.create_next_fight_party()
			_check(projected != null and projected.get_hero(down_position).hp == 0
				and projected.get_hero(down_position).max_hp == app.run_heroes[down_position - 1].max_hp,
				"torn wearer's next battle cap excludes the inactive coat bonus")
			await _activate(app.continue_button, keyboard)
			if not elite_first:
				await _reach(fixture.paths[2], keyboard)
				await _settle_battle(keyboard)
				_check(sewing.wardrobe == wardrobe and sewing.hero_buttons.size() == 3,
					"later Elite presenter reuses previously bound Shop wardrobe")
				var gold: int = app.session_gold
				await _activate(sewing.hero_buttons[2], keyboard)
				_check(sewing.wardrobe == wardrobe and app.session_gold == gold
					and wardrobe.get_snapshot().operation_ids.size() >= 3,
					"later genuine Elite free sew retains Shop operation history")
				await _activate(app.continue_button, keyboard)
			_check(randi() == global_next, "UI, rejection and combat use no global randomness")
			await _activate(app.route_back_button, keyboard)
			for old in retained:
				old.call()
			_check(app.run_map == null and app._shop_wardrobe == null and app.run_trinkets.is_empty()
				and app.session_gold == 0, "title/reset discards callbacks and wardrobe")
	_check(saw_coat, "real Shop routes actually purchased the authored coat")
	await _poor_and_replacement()
	await _unsewn_elite_before_shop()
	await _shop_fight_shop()
	await _badge_fights()
	await _finish_patches()


func _badge_service_checks() -> void:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	for hero in definitions:
		hero.max_hp = int(hero.max_hp)
	var heroes := CombatParty.new(definitions).get_heroes()
	var slots: Array = JSON.parse_string(FileAccess.get_file_as_string(
		CombatShopPatchRules.SLOTS_CATALOG))
	for owned in [[], ["stitched_badge"]]:
		var carry := RunTornCarryover.new(heroes)
		var clothes := RunPatchWardrobe.new(heroes, owned, slots, 0)
		_check(carry.bind_wardrobe(clothes, carry.torn, clothes.get_snapshot()),
			"scene-free unowned/unsewn wardrobe genuinely binds")
		var before := [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()]
		var party := carry.create_next_fight_party()
		_check(party != null and party.has_meta("shop_patch_projection"), "bound party carries optional projection")
		if party == null:
			continue
		var rules: CombatShopPatchRules = party.get_meta("shop_patch_projection").rules
		for hero in party.get_heroes():
			_check(rules.opening_block_bonus(hero.id) == 0, "unowned/unsewn grants no Badge bonus")
		_check([carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()] == before,
			"party creation never mutates persistent ledgers")
		var fight := _badge_flow(party)
		var projection: Dictionary = party.get_meta("shop_patch_projection")
		var mismatched := projection.duplicate(true)
		mismatched.heroes[1].hp -= 1
		for invalid in [[], {}, {"rules": 3}, {"rules": CombatShopPatchRules.new(), "heroes": heroes}, mismatched]:
			party.set_meta("shop_patch_projection", invalid)
			var state := _badge_flow_state(fight)
			_check(not fight.flow.begin_fight() and _badge_flow_state(fight) == state,
				"invalid optional projection rejects before deck, RNG, actors or one-shot mutations")
		party.set_meta("shop_patch_projection", projection)
		_check(fight.flow.begin_fight() and party.get_hero(1).block == 6
			and party.get_hero(2).block == 0 and party.get_hero(3).block == 0,
			"unowned/unsewn battle begins with base Block only after rejected starts")
		if not owned.is_empty():
			_check(clothes.sew("stitched_badge", "warden", "HEAD", "after-projection", clothes.get_snapshot()).ok,
				"wardrobe can sew after old party projection was made")
			_check(rules.opening_block_bonus("warden") == 0
				and carry.create_next_fight_party().get_meta("shop_patch_projection").rules.opening_block_bonus("warden") == 3,
				"battle projection stays detached while next factory freshly binds current sewing")
		var another := carry.create_next_fight_party()
		party.get_meta("shop_patch_projection").heroes[0].hp -= 1
		_check(another.get_meta("shop_patch_projection").heroes == heroes
			and carry.create_next_fight_party().get_meta("shop_patch_projection").heroes == heroes,
			"each factory projection is detached from other parties and ledgers")
		clothes._heroes[0].hp -= 1
		var stale := [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()]
		_check(carry.create_next_fight_party() == null
			and [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()] == stale,
			"stale wardrobe rejects party creation without repairing either ledger")
		clothes._heroes[0].hp += 1
		carry.torn._heroes[0].hp -= 1
		var torn_stale := [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()]
		_check(carry.create_next_fight_party() == null
			and [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()] == torn_stale,
			"torn drift rejects without mutating either ledger")
	var unbound := RunTornCarryover.new(heroes).create_next_fight_party()
	_check(unbound != null and not unbound.has_meta("shop_patch_projection"), "unbound runs retain absent projection")
	var vanilla := _badge_flow(unbound)
	_check(vanilla.flow.begin_fight() and unbound.get_hero(1).block == 6,
		"unbound combat preserves existing opening Block")


func _badge_flow(party: CombatParty) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	var deck := CombatDeck.new(StarterCards.new().get_starting_deck(), rng)
	var enemies := CombatEnemies.new([{"id": "opening_probe", "max_hp": 20}])
	var intents := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 0}]}])
	var result := CombatBattleResult.new(party, enemies)
	return {"party": party, "deck": deck, "enemies": enemies, "intents": intents,
		"result": result, "rng": rng, "flow": CombatRoundFlow.new(deck, party, enemies, intents, result)}


func _badge_flow_state(f: Dictionary) -> Array:
	return [f.party.get_heroes(), f.enemies.get_enemies(), f.deck.draw_pile.duplicate(),
		f.deck.hand.duplicate(), f.deck.discard_pile.duplicate(), f.deck.energy, f.deck.turn_active,
		f.rng.state, f.intents.get_intents(), f.intents._turn_index, f.result.get_outcome(),
		f.flow._started, f.flow._opening_block._consumed]


func _badge_fights() -> void:
	_badge_service_checks()
	var fixture := {}
	var next_seed := 1
	var badge := -1
	# Find a real generated route whose real stock contains the Badge. Never
	# replace stock or patch definitions to manufacture a positive case.
	for attempt in range(20):
		fixture = _sequence_fixture(["Shop", "Fight", "Fight"], next_seed, true)
		_check(not fixture.is_empty(), "generated route supports Badge and inactive follow-up Fight")
		if fixture.is_empty() or not await _routed_win(fixture, false):
			return
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		app.session_gold = 500
		await _reach(fixture.paths[0], false)
		for i in range(app.shop_patch_offers.item_count):
			if app.shop_purchases.get_stock().trinkets[i].id == "stitched_badge":
				badge = i
		next_seed = fixture.seed + 1
		await _click(app.shop_back_button)
		if badge >= 0:
			break
	_check(badge >= 0, "real seeded Shop stock guarantees a purchasable Stitched Badge")
	if badge < 0:
		return
	for wearer in [0, 1]:
		var replay: Array = []
		for keyboard in [false, true]:
			if not await _routed_win(fixture, false):
				return
			await _activate(app.reward_buttons[3], keyboard)
			await _activate(app.continue_button, keyboard)
			app.session_gold = 500
			await _reach(fixture.paths[0], keyboard)
			wardrobe = app._shop_wardrobe
			await _purchase(badge, keyboard, wearer)
			var persistent := [app.run_heroes.duplicate(true), app.run_deck.duplicate(),
				app.run_trinkets.duplicate(), app.session_gold, app.run_scraps]
			await _activate(app.shop_continue_button, keyboard)
			# The route callback must fail closed on a stale bound wardrobe.
			var transit: Array = fixture.paths[1].duplicate()
			var destination: String = transit.pop_back()
			await _visit_path(transit, keyboard)
			var action: Button = _route_action(destination)
			var callback: Callable = action.pressed.get_connections()[0].callable
			wardrobe._heroes[wearer].hp -= 1
			_reject_entry(callback, "stale wardrobe rejects real Fight entry")
			var stale := _patch_state()
			_check(app.party_carryover.create_next_fight_party() == null and _patch_state() == stale,
				"stale factory leaves run RNG and every persistent ledger unchanged")
			wardrobe._heroes[wearer].hp += 1
			var oracle := _oracle(destination)
			await _activate(action, keyboard)
			_check(app.party != null and app.round_flow._started and _mounted_state() == oracle,
				"real mounted Fight starts with exact seeded entry state")
			for hero in app.party.get_heroes():
				var expected := (6 if hero.id == "warden" else 0) + (3 if hero.position == wearer + 1 else 0)
				_check(hero.block == expected, "Badge adds exactly 3 only to its wearer at first entry")
			_check([app.run_heroes, app.run_deck, app.run_trinkets, app.session_gold, app.run_scraps] == persistent,
				"opening Badge preserves persistent heroes, deck, ownership and currency")
			var live := {"party": app.party, "enemies": app.enemies, "deck": app.deck,
				"rng": app.run_rng, "intents": app.enemy_intents, "result": app.battle_result,
				"flow": app.round_flow}
			var trace := [_badge_flow_state(live)]
			var duplicate := _badge_flow_state(live)
			_check(not app.round_flow.begin_fight() and _badge_flow_state(live) == duplicate,
				"duplicate begin cannot stack Badge, change actors or consume RNG")
			_check(app.round_flow.end_turn(), "real Badge battle advances through enemy phase")
			for hero in app.party.get_heroes():
				_check(hero.block == 0, "normal next-turn reset removes all opening Block")
			trace.append(_badge_flow_state(live))
			await _settle_battle(keyboard, wearer + 1)
			await _activate(app.continue_button, keyboard)
			await _reach(fixture.paths[2], keyboard)
			var down: Dictionary = app.party.get_hero(wearer + 1)
			_check(down.hp == 0 and down.block == 0
				and wardrobe.get_snapshot().worn[down.id].HEAD == "stitched_badge",
				"next mounted Fight grants zero to genuinely downed inactive Badge wearer")
			trace.append(_mounted_state())
			trace.append([app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.run_trinkets.duplicate(),
				app.session_gold, app.run_scraps, wardrobe.get_snapshot()])
			if keyboard:
				_check(trace == replay, "Badge mouse/keyboard replay agrees on full combat and persistent state")
			else:
				replay = trace
			await _settle_battle(keyboard)
			await _activate(app.continue_button, keyboard)
			await _activate(app.route_back_button, keyboard)


func _finish_patches() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_patch_sewing_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
