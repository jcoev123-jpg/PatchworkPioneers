extends "res://tests/live_m04_event_wallet_batch_test.gd"
## Real admission, four special Events, weighted Parcel, and connected Fight.


func _parcel_path(map: RunMap, choices: Array, events: int, terminal: String = "Fight") -> Array:
	for id in choices:
		var node := map.get_node(id)
		if events == 0:
			if node.type == terminal:
				return [id]
			if node.type == "Treasure":
				var onward := _parcel_path(map, node.outgoing, 0, terminal)
				if not onward.is_empty():
					return [id] + onward
			continue
		if node.type not in ["Event", "Treasure", "Campfire", "Unpicker", "Rest"]:
			continue
		var tail := _parcel_path(map, node.outgoing, events - (1 if node.type == "Event" else 0), terminal)
		if not tail.is_empty():
			return [id] + tail
	return []


func _parcel_fixture(terminal: String = "Fight", stitched: bool = false) -> Dictionary:
	var ids := RunM04EventRotation.new(_combined_catalog()).get_generic_event_ids()
	ids.append("frayed_debt_parcel")
	ids.sort()
	var hints: Array = preload("res://tests/event_wallet_hints.gd").SEEDS.duplicate()
	hints.push_front(39502)
	if terminal == "Unpicker":
		hints.push_front(159691)
	hints.append_array(range(1, 500000))
	for value in hints:
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var path := _parcel_path(map, map.get_legal_choices(), 5, terminal)
		if path.is_empty():
			continue
		var toll := RunNeedleToll.new({"heroes": CombatParty.new(app._load_party_definitions()).get_heroes(),
			"wallet": {"gold": 0, "scraps": 0}, "deck": app._load_starter_deck()}, rng)
		if not toll.pay_toll("warden").ok:
			continue
		var before := rng.state
		if ids[rng.randi_range(0, ids.size() - 1)] != "frayed_debt_parcel":
			continue
		var events: Array = []
		var transit := {}
		var treasures: Array = []
		for id in path.slice(0, -1):
			if map.get_node(id).type != "Event":
				treasures.append(id)
			else:
				transit[id] = treasures.duplicate()
				treasures.clear()
				events.append(id)
		return {"seed": value, "path": events, "transit": transit, "fight": path[-1], "terminal": terminal, "stitched": stitched, "after": treasures, "before_draw": before}
	return {}


func _parcel_state() -> Array:
	return [_wallet_state(), app._frayed_debt_source(), app._frayed_debt_seen,
		app._frayed_debt_receipt.duplicate(true), app.frayed_debt_panel]


func _traverse_treasures(fixture: Dictionary, target: String) -> void:
	for id in fixture.transit[target]:
		await _parcel_transit(id)


func _parcel_transit(id: String) -> void:
	var before: Array = [app.run_deck.duplicate(), app.run_heroes.duplicate(true), _wallet(), app.run_rng.state]
	var kind: String = app.run_map.get_node(id).type
	await _click(_route_action(id))
	if kind in ["Campfire", "Rest"]:
		await _click(app.campfire_leave_button)
	elif kind == "Unpicker":
		await _click(app.unpicker_leave_button)
	_check([app.run_deck, app.run_heroes, _wallet(), app.run_rng.state] == before
		and app.run_map.get_current_node_id() == id, "legal free transit preserves source and RNG")


func _deny_parcel(callback: Callable, message: String) -> void:
	var before := _parcel_state()
	callback.call()
	_check(_parcel_state() == before, message + " preserves route, ledgers and RNG")


func _reach(f: Dictionary, _funded: bool = true) -> void:
	app.run_seed = f.seed
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	_check(app.run_map != null and app._party_receipt == RunV3PartyAdmission.admit(_party_ids()), "actual canonical three-of-eight admission")
	for index in range(4):
		await _traverse_treasures(f, f.path[index])
		await _click(_route_action(f.path[index]))
		var panel: LiveEventChoicePanel = [app.quiet_spool_panel, app.moth_panel, app.dye_vat_panel, app.needle_toll_panel][index]
		_check(is_instance_valid(panel), "genuine routed special prerequisite")
		if not is_instance_valid(panel):
			return
		await _click(panel.get_choice_buttons()[[0, 2, 1, 0][index]])
		if index == 0 and f.stitched:
			_install_stitched_fixture()
		if index == 0 and f.terminal == "Unpicker":
			app.session_gold = 100
		if index == 3:
			_check(is_instance_valid(app.needle_toll_panel) and app._needle_toll_outcome.is_paid(), "real paid toll draws precede Parcel")
			await _click(app.needle_toll_panel.get_choice_buttons()[2])
	await _traverse_treasures(f, f.path[4])


func _install_stitched_fixture() -> void:
	# An earned composite fixture is installed only after genuine route admission.
	var stitch := RunRestStitchCards.new(app.run_deck, {}, 3, 1)
	var second := -1
	for index in range(1, app.run_deck.size()):
		if RunRestStitchCards.resolve_card_definition(app.run_deck[index]).owner != RunRestStitchCards.resolve_card_definition(app.run_deck[0]).owner:
			second = index
			break
	_check(second >= 0, "genuine different-owner stitch inputs")
	var sewn := stitch.choose_stitch(0, second, stitch.get_snapshot())
	_check(sewn.ok and not sewn.descriptors.is_empty() and sewn.next_stitch_id > 1, "nonempty valid earned stitched ledger prerequisite")
	app.run_deck.assign(sewn.deck)
	app.run_stitch_descriptors = sewn.descriptors
	app.run_next_stitch_id = sewn.next_stitch_id
	app.run_scraps = sewn.remaining_scraps


func _parcel_visit(f: Dictionary, branch: int, keyboard: bool) -> Array:
	await _reach(f)
	var before: Dictionary = app._frayed_debt_source()
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var ids := RunM04EventRotation.new(_combined_catalog()).get_generic_event_ids()
	ids.append("frayed_debt_parcel")
	ids.sort()
	_check(ids[rng.randi_range(0, ids.size() - 1)] == "frayed_debt_parcel", "one authored-weight ticket among eligible generic outcomes")
	var oracle := RunFrayedDebtParcel.new()
	_check(oracle.prepare(before, rng).ok, "real current Rest ledger prepares independent offers")
	var entry: Callable = _route_action(f.path[4]).pressed.get_connections()[0].callable
	await _click(_route_action(f.path[4]))
	var panel: LiveEventChoicePanel = app.frayed_debt_panel
	_check(is_instance_valid(panel) and app.route_view == null, "legal Event mounts Parcel and gates route")
	if not is_instance_valid(panel):
		app._return_to_title()
		await _frames()
		return []
	var offers: Array = app._frayed_debt_outcome.get_offers()
	_check(offers.size() == 2 and offers == oracle.get_offers() and offers[0].id != offers[1].id
		and app.run_rng.state == rng.state, "distinct offers and exact selection/preparation RNG replay")
	for card in offers:
		_check(card == RunPoolCardRewardOffers.resolve_reward_definition(card.id)
			and card.rarity == "uncommon" and _party_ids().has(card.owner)
			and not card.id.ends_with("_plus"), "selected-party authored uncommon base")
	for button in panel.get_choice_buttons():
		_check(button.is_visible_in_tree() and not button.disabled
			and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "readable mouse and keyboard ticket")
	var commit: Callable = panel.choice_committed.get_connections()[0].callable
	var choice: String = offers[branch].id if branch < 2 else "safe_exit"
	_deny_parcel(entry, "duplicate route")
	_deny_parcel(commit.bind("frayed_debt_parcel", choice), "signal before panel claim")
	_deny_parcel(commit.bind("frayed_debt_parcel", "forged"), "forged choice")
	panel.choice_committed.disconnect(commit)
	if keyboard:
		await _key(KEY_1 + branch)
	else:
		await _click(panel.get_choice_buttons()[branch])
	_check(panel._selector.is_claimed() and panel._committed_choice.choice_id == choice
		and app._frayed_debt_source() == before, "panel only emits intent without applying service")
	var state: int = app.run_rng.state
	app.run_rng.randi()
	_deny_parcel(commit.bind("frayed_debt_parcel", choice), "stale RNG")
	app.run_rng.state = state
	app.run_scraps += 1
	_deny_parcel(commit.bind("frayed_debt_parcel", choice), "stale ledger")
	app.run_scraps -= 1
	var original: RunMap = app.run_map
	app.run_map = RunMap.new()
	_deny_parcel(commit.bind("frayed_debt_parcel", choice), "foreign route source")
	app.run_map = original
	var record := panel._selector.get_event()
	var selector := panel._selector
	panel._selector = RunEventChoice.new(record)
	_deny_parcel(commit.bind("frayed_debt_parcel", choice), "replaced offer selector")
	panel._selector = selector
	commit.call("frayed_debt_parcel", choice)
	var expected := oracle.choose(choice, before)
	_check(expected.ok and app.frayed_debt_panel == null and is_instance_valid(app.route_view)
		and app._frayed_debt_seen and app._frayed_debt_receipt == expected
		and app.run_deck == expected.deck and app.run_scraps == expected.remaining_scraps
		and app.run_stitch_descriptors == before.descriptors and app.run_next_stitch_id == before.next_stitch_id
		and app.run_rng.state == state, "exact once receipt atomically closes to actual map")
	_deny_parcel(commit.bind("frayed_debt_parcel", choice), "repeated claim")
	_deny_parcel(entry, "stale route entry")
	for seed_value in range(8):
		var detached := RandomNumberGenerator.new()
		detached.seed = seed_value
		var selection: Dictionary = app._select_generic_event(app._load_wallet_event_catalog(), detached)
		_check(selection.ok and selection.event.id != "frayed_debt_parcel", "once-per-run Parcel excluded after either branch")
	var replay: Array = [offers, expected, app.run_rng.state, app.run_map.get_route()]
	if branch < 2 and app.frayed_debt_panel == null:
		for id in f.after:
			await _parcel_transit(id)
		var source_deck: Array = app.run_deck.duplicate()
		if f.terminal == "Unpicker":
			# Funding was installed before subsequent route snapshots were bound.
			await _click(_route_action(f.fight))
			var unpicker: LiveUnpickerPanel = app.unpicker_view
			_check(is_instance_valid(unpicker) and app.unpicker_visit.is_valid(), "claimed curse reaches real connected Unpicker")
			if is_instance_valid(unpicker):
				var source: Dictionary = app.unpicker_visit.read_state()
				var curse_index: int = source.deck.find("frayed_debt")
				_check(curse_index >= 0 and source.gold >= source.price, "owned curse and payable removal prerequisite")
				var row: int = unpicker._canonical_ids().find("frayed_debt")
				_check(row >= 0 and row < unpicker.card_buttons.size(), "curse has an authenticated distinct-card row")
				if row < 0 or row >= unpicker.card_buttons.size():
					return []
				unpicker.card_buttons[row].grab_focus()
				await _frames()
				await _key(KEY_ENTER)
				_check(unpicker._selected_id == "frayed_debt" and not unpicker.remove_button.disabled, "curse selects ordinary paid removal")
				await _click(unpicker.remove_button)
				var remaining := source_deck.duplicate()
				remaining.erase("frayed_debt")
				_check(app.run_deck == remaining and app.session_gold == 100 - source.price
					and app.run_removal_count == 1 and app.run_scraps == expected.remaining_scraps
					and app.run_stitch_descriptors == expected.descriptors and app.run_next_stitch_id == expected.next_stitch_id,
					"mounted Unpicker debits exact price and removes only curse preserving stitched ledger")
			app._return_to_title()
			await _frames()
			return replay
		var entry_fight: Callable = _route_action(f.fight).pressed.get_connections()[0].callable
		var foreign: Dictionary = RunV3PartyAdmission.admit(["yarn_ranger", "scarecrow", "lantern_monk"])
		for forged in ["forged_ownerless", foreign.deck[0]]:
			app.run_deck.append(forged)
			_deny_parcel(entry_fight, "forged or unselected-owner source card")
			app.run_deck.pop_back()
		await _click(_route_action(f.fight))
		_check(app.run_map.get_current_node_id() == f.fight and app.deck != null, "real next connected Fight admits claimed cursed deck")
		if app.run_map.get_current_node_id() == f.fight:
			var deck: CombatDeck = app.deck
			_check(deck.hand.size() + deck.exhausted.count("frayed_debt") == CombatDeck.TURN_DRAW,
				"real opening hand counts the curse against the five draw slots")
			for turn in range(source_deck.size()):
				if deck.exhausted.has("frayed_debt"):
					break
				var prior_hand := deck.hand.size()
				var prior_exhaust := deck.exhausted.size()
				var drawn := deck.draw_extra(1)
				_check(deck.hand.size() - prior_hand + deck.exhausted.size() - prior_exhaust == 1
					and drawn == deck.hand.size() - prior_hand, "curse uses its draw slot without replacement")
			_check(deck.exhausted.count("frayed_debt") == 1 and not deck.hand.has("frayed_debt")
				and not deck.draw_pile.has("frayed_debt") and app.run_deck == source_deck, "curse exhausts for Fight and remains run-owned")
			var visit := RunUnpickerVisit.new("unpicker", app.run_deck, 100, 0, app.run_stitch_descriptors, app.run_next_stitch_id)
			var source := visit.read_state()
			var removed := visit.remove_card("frayed_debt", source.visit_id, source.node_id, source)
			_check(visit.is_valid() and removed.ok and removed.gold == 100 - source.price
				and not removed.deck.has("frayed_debt") and removed.prior_removals == 1, "ordinary Unpicker removal remains payable")
	app._return_to_title()
	await _frames()
	return replay


func _booth_state() -> Array:
	return [_wallet(), app.run_deck.duplicate(), app.run_stitch_descriptors.duplicate(true),
		app.run_next_stitch_id, app.run_removal_count, app.run_rng.state,
		app.run_map, app.run_map.get_route(), app._debt_booth_seen,
		app._debt_booth_receipt.duplicate(true), app.debt_booth_panel,
		app._debt_booth_service.is_claimed() if app._debt_booth_service != null else false,
		app.route_view, app._wallet_event_history.duplicate(),
		app._vital_event_history.duplicate()]


func _deny_booth(callback: Callable, label: String) -> void:
	var before := _booth_state()
	if callback.is_valid():
		callback.call()
	_check(_booth_state() == before, label + " cannot change wallet, stitched ledger, map, RNG or visit")


func _arrive_at_post_parcel_event(f: Dictionary, has_curse: bool, gold: int, scraps: int) -> void:
	await _reach(f)
	var entry := _route_action(f.path[4])
	_check(is_instance_valid(entry), "genuine fifth Event route choice is mounted")
	if not is_instance_valid(entry):
		return
	await _click(entry)
	var parcel: LiveEventChoicePanel = app.frayed_debt_panel
	_check(is_instance_valid(parcel) and app._frayed_debt_outcome != null,
		"real fifth Event opens weighted Frayed Debt Parcel")
	if not is_instance_valid(parcel):
		return
	var offers: Array = app._frayed_debt_outcome.get_offers()
	_check(offers.size() == 2, "Parcel has two genuine selected-party reward offers")
	if offers.size() != 2:
		return
	await _click(parcel.get_choice_buttons()[0 if has_curse else 2])
	_check(app._frayed_debt_seen and app.frayed_debt_panel == null
		and app.run_deck.count(MpwFrayedDebt.CARD_ID) == (1 if has_curse else 0),
		"real Parcel reward creates one canonical owned curse, while exit creates none")
	# Wallet boundary fixtures vary only funding; entry, curse and stitched
	# descriptors come from the genuine routed run and accepted Parcel service.
	app.session_gold = gold
	app.run_scraps = scraps
	for id in f.after:
		await _parcel_transit(id)
	_check(app.run_map.get_legal_choices().has(f.fight)
		and app.run_map.get_node(f.fight).type == "Event"
		and is_instance_valid(_route_action(f.fight)),
		"real sixth connected Event is legal with an actionable route button")


func _booth_visit(f: Dictionary, branch: int, keyboard: bool) -> Array:
	await _arrive_at_post_parcel_event(f, true, 25, 3)
	var opening: Dictionary = app._debt_booth_source()
	var source_rng: int = app.run_rng.state
	var oracle := RunV3DebtRedemptionEvent.new()
	_check(opening.deck.count(MpwFrayedDebt.CARD_ID) == 1
		and oracle.prepare(opening).ok, "valid genuine curse and six-key opening snapshot")
	if not oracle.is_valid():
		app._return_to_title()
		await _frames()
		return []
	var entry: Callable = _route_action(f.fight).pressed.get_connections()[0].callable
	await _click(_route_action(f.fight))
	var panel: LiveEventChoicePanel = app.debt_booth_panel
	_check(is_instance_valid(panel) and app.route_view == null
		and app.run_map.get_current_node_id() == f.fight,
		"live sixth Event mounts authored Booth and suspends route")
	if not is_instance_valid(panel):
		app._return_to_title()
		await _frames()
		return []
	var forecast := oracle.preview_choices()
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3 and panel._wallet_mode
		and panel._selector.get_event().id == RunV3DebtRedemptionEvent.EVENT_ID
		and not app._debt_booth_seen and app.run_rng.state == source_rng,
		"three real Booth tickets, no RNG draw or premature visit latch")
	for index in range(buttons.size()):
		_check(buttons[index].is_visible_in_tree() and not buttons[index].disabled
			and Rect2(0, 0, 1280, 720).encloses(buttons[index].get_global_rect())
			and panel._wallet_previews[forecast.choices[index].id].affordable
			and buttons[index].focus_mode == Control.FOCUS_ALL,
			"all funded Booth controls visible, enabled and keyboard accessible")
	var ids := ["cut_debt", "sell_offcuts", "leave"]
	var choice: String = ids[branch]
	var expected := oracle.choose(choice, opening)
	_check(expected.ok, "independent Booth service settles selected authored branch")
	var commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	_deny_booth(entry, "duplicate route opening")
	_deny_booth(commit.bind({"ok": true, "event_id": RunV3DebtRedemptionEvent.EVENT_ID,
		"choice_id": choice, "wallet": {"gold": 25, "scraps": 3}}), "forged preclaim signal")
	panel.wallet_choice_committed.disconnect(commit)
	if keyboard:
		await _key(KEY_1 + branch)
	else:
		await _click(buttons[branch])
	var claim: Dictionary = panel._committed_choice.duplicate(true)
	_check(panel._selector.is_claimed() and claim.get("choice_id") == choice
		and app._debt_booth_source() == opening and app.run_rng.state == source_rng,
		"panel claim emits intent only; run ledger and RNG remain unchanged")
	# Every stale source or forged panel context fails before service.choose().
	app.run_rng.randi()
	_deny_booth(commit.bind(claim), "stale RNG")
	app.run_rng.state = source_rng
	app.run_scraps += 1
	_deny_booth(commit.bind(claim), "stale opening ledger")
	app.run_scraps -= 1
	var source_map: RunMap = app.run_map
	app.run_map = RunMap.new()
	_deny_booth(commit.bind(claim), "foreign map")
	app.run_map = source_map
	var selector := panel._selector
	panel._selector = RunEventChoice.new(selector.get_event())
	_deny_booth(commit.bind(claim), "replaced panel selector")
	panel._selector = selector
	commit.call(claim)
	_check(app._debt_booth_seen and app.debt_booth_panel == null
		and is_instance_valid(app.route_view) and app.run_map.get_current_node_id() == f.fight
		and app.run_rng.state == source_rng and app._debt_booth_receipt == expected,
		"one accepted choice returns to the actual connected map without extra RNG")
	_check(app._debt_booth_source() == expected.snapshot
		and app.run_deck.count(MpwFrayedDebt.CARD_ID) == (0 if branch == 0 else 1)
		and app.run_stitch_descriptors == opening.descriptors
		and app.run_next_stitch_id == opening.next_stitch_id
		and app.run_removal_count == opening.prior_removals,
		"Booth commits exact service deck, wallet, descriptors, cursor and removal count")
	_check(app.session_gold == [7, 45, 25][branch] and app.run_scraps == [3, 1, 3][branch],
		"Cut costs 18 gold; Sell trades 2 scraps for 20 gold; Leave costs nothing")
	_deny_booth(commit.bind(claim), "replayed committed choice")
	_deny_booth(entry, "stale pressed route entry")
	var choices: Array = app.run_map.get_legal_choices()
	_check(not choices.is_empty() and is_instance_valid(_route_action(choices[0])),
		"Booth closure exposes at least one usable onward route node")
	var replay := [expected, app.run_rng.state, app.run_map.get_route(), choices]
	app._return_to_title()
	await _frames()
	_check(not app._debt_booth_seen and app.debt_booth_panel == null,
		"new-run lifecycle clears Booth visit latch and mounted panel")
	return replay


func _booth_refusals(f: Dictionary) -> void:
	await _arrive_at_post_parcel_event(f, true, 17, 1)
	var source: Dictionary = app._debt_booth_source()
	var original: Dictionary = app.run_stitch_descriptors.duplicate(true)
	# Invalid stitched registry must refuse entry even with a real curse.
	app.run_stitch_descriptors["stitch_invalid"] = {"owners": []}
	var before := _booth_state()
	await _click(_route_action(f.fight))
	_check(_booth_state() == before and app.debt_booth_panel == null,
		"invalid stitched descriptor ledger refuses route with no spend or RNG")
	app.run_stitch_descriptors = original
	await _click(_route_action(f.fight))
	var panel: LiveEventChoicePanel = app.debt_booth_panel
	_check(is_instance_valid(panel) and app._debt_booth_source() == source,
		"restored valid canonical ledger opens genuine Booth")
	if not is_instance_valid(panel):
		app._return_to_title()
		await _frames()
		return
	var buttons := panel.get_choice_buttons()
	var preview: Dictionary = app._debt_booth_service.preview_choices()
	_check(buttons.size() == 3 and buttons[0].disabled and buttons[1].disabled
		and not buttons[2].disabled and not preview.by_id.cut_debt.affordable
		and not preview.by_id.sell_offcuts.affordable,
		"17 gold cannot pay 18 and one scrap cannot pay two, Leave is enabled")
	var denied: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	_deny_booth(denied.bind({"ok": true, "event_id": RunV3DebtRedemptionEvent.EVENT_ID,
		"choice_id": "cut_debt", "wallet": {"gold": 0, "scraps": 1}}),
		"forged unaffordable Cut receipt")
	await _key(KEY_1)
	await _key(KEY_2)
	await _click(buttons[0])
	await _click(buttons[1])
	_check(app._debt_booth_source() == source and not app._debt_booth_seen
		and app.debt_booth_panel == panel and app.run_rng.state == app._debt_booth_context[6],
		"disabled keyboard and mouse choices cannot claim, debit, advance or draw RNG")
	await _key(KEY_3)
	_check(app._debt_booth_seen and app._debt_booth_receipt.choice_id == "leave"
		and app._debt_booth_source() == source and is_instance_valid(app.route_view),
		"unaﬀordable visit may Leave freely and returns to real map")
	app._return_to_title()
	await _frames()


func _booth_no_curse(f: Dictionary) -> void:
	await _arrive_at_post_parcel_event(f, false, 25, 3)
	var rng_before: int = app.run_rng.state
	await _click(_route_action(f.fight))
	_check(app.debt_booth_panel == null and not app._debt_booth_seen
		and app.run_deck.count(MpwFrayedDebt.CARD_ID) == 0
		and is_instance_valid(app.wallet_event_panel) and app.run_rng.state != rng_before
		and app.run_map.get_current_node_id() == f.fight,
		"curse-free genuine route keeps regular RNG-backed generic wallet Event")
	if is_instance_valid(app.wallet_event_panel):
		var panel: LiveEventChoicePanel = app.wallet_event_panel
		var enabled: Array[Button] = []
		for button in panel.get_choice_buttons():
			if not button.disabled:
				enabled.append(button)
		_check(not enabled.is_empty(), "ordinary Event remains playable")
		if not enabled.is_empty():
			await _click(enabled[0])
			_check(is_instance_valid(app.route_view) and app.wallet_event_panel == null,
				"ordinary Event still returns to connected route after claim")
	app._return_to_title()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var fixture := _parcel_fixture()
	_check(not fixture.is_empty(), "seeded five-Event to Fight witness exists")
	if not fixture.is_empty():
		print("Parcel witness: ", fixture.seed)
		for branch in [0, 2]:
			var first := await _parcel_visit(fixture, branch, false)
			var second := await _parcel_visit(fixture, branch, true)
			_check(not first.is_empty() and first == second, "mouse/keyboard same-seed branch replay")
	var stitched_fixture := _parcel_fixture("Fight", true)
	_check(not stitched_fixture.is_empty(), "stitched Parcel to Fight witness exists")
	if not stitched_fixture.is_empty():
		print("Stitched Parcel witness: ", stitched_fixture.seed)
		var first := await _parcel_visit(stitched_fixture, 1, false)
		var second := await _parcel_visit(stitched_fixture, 1, true)
		_check(not first.is_empty() and first == second, "stitched second-offer same-seed replay")
	var unpicker_fixture := _parcel_fixture("Unpicker", true)
	_check(not unpicker_fixture.is_empty(), "seeded Parcel to Unpicker witness exists")
	if not unpicker_fixture.is_empty():
		print("Parcel Unpicker witness: ", unpicker_fixture.seed)
		await _parcel_visit(unpicker_fixture, 1, true)
	var booth_fixture := _parcel_fixture("Event", true)
	_check(not booth_fixture.is_empty(), "seeded post-Parcel sixth Event route witness exists")
	if not booth_fixture.is_empty():
		print("Booth witness: ", booth_fixture.seed)
		for branch in range(3):
			var mouse := await _booth_visit(booth_fixture, branch, false)
			var keys := await _booth_visit(booth_fixture, branch, true)
			_check(not mouse.is_empty() and mouse == keys,
				"funded Booth branch has identical mouse/keyboard replay: " + str(branch))
		await _booth_refusals(booth_fixture)
		await _booth_no_curse(booth_fixture)
	app.queue_free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_frayed_debt_parcel_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
