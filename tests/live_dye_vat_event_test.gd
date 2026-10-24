extends "res://tests/live_quiet_spool_route_test.gd"
## Mounted third routed Event: the authored, transactional Dye Vat. The first two
## Events stay Quiet Spool and Moth Infestation; later Events keep the placeholder.
## Every Dye Vat entry, rejection and commit here goes through the real route UI,
## the real run ledger and the scene-free RunDyeVatOutcome service.

const DYE_EVENT_PATH := "res://data/events/dye_vat.json"


## A genuine seeded run: starter Fight, four consecutive Events, then a Fight.
func _dye_fixture() -> Dictionary:
	var kinds: Array = ["Fight", "Event", "Event", "Event", "Event", "Fight"]
	for value in range(1, 30000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var path := _find_path(map, map.get_legal_choices(), kinds)
		if path.is_empty():
			continue
		map.choose_node(path[0])
		var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng,
			RunFightEncounterSelection.new())
		if selected.get("encounter_id") == "starter_attacks":
			return {"seed": value, "fight": path[0], "path": path.slice(1)}
	return {}


## A genuine zero-fight opening route with three consecutive Events.
func _opening_dye_fixture() -> Dictionary:
	for value in range(1, 30000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var path := _find_path(map, map.get_legal_choices(), ["Event", "Event", "Event"])
		if not path.is_empty():
			return {"seed": value, "path": path}
	return {}


func _dye_state() -> Array:
	var state := _event_state()
	state.append_array([app._dye_vat_completed, app.dye_vat_panel, app._dye_vat_outcome,
		app._dye_vat_outcome.is_claimed() if app._dye_vat_outcome != null else false,
		app._dye_vat_node, app._dye_vat_context.duplicate(), app._dye_vat_picker,
		app._dye_vat_picker.get_instance_id() if is_instance_valid(app._dye_vat_picker) else 0,
		app._dye_vat_picker_item_indices(),
		app._dye_vat_picker.get_selected_items() if is_instance_valid(app._dye_vat_picker) \
			else PackedInt32Array()])
	return state


func _reject_dye(callback: Callable, reason: String) -> void:
	var before := _dye_state()
	if callback.is_valid():
		callback.call()
	_check(_dye_state() == before, reason + " preserves the whole run, map, ledger and RNG")


func _authored_dye_choices() -> Array:
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(DYE_EVENT_PATH))
	_check(record is Dictionary and record.get("id") == "dye_vat", "authored Dye Vat record is readable")
	return (record as Dictionary).get("choices", []) if record is Dictionary else []


func _pool_base_name(card_id: String) -> String:
	return String(RunPoolCardRewardOffers.resolve_reward_definition(card_id).get("display_name", ""))


## Claims the genuine Fight reward whose authored pool base the Dye Vat can upgrade.
func _claim_upgradeable_reward(keyboard: bool) -> String:
	var offered: Array = app.fight_reward_offers
	var index := -1
	for candidate in range(offered.size()):
		var offered_id := String(offered[candidate].get("id", ""))
		if not RunDyeVatOutcome.resolve_authored_pool_upgrade(offered_id).is_empty():
			index = candidate
			break
	_check(index >= 0, "the real Fight reward offers an authored pool base eligible for the Dye Vat")
	if index < 0:
		return ""
	var base_id := String(offered[index].id)
	if keyboard:
		app.reward_buttons[index].grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(app.reward_buttons[index])
	_check(app.fight_reward_claimed and app.run_deck.count(base_id) == 1,
		"the claimed authored pool base enters the real run deck exactly once")
	return base_id


## Reaches the run's third Event through the first two real Event transactions.
## reward: claim the eligible pool base; feed: Moth sacrifice (+2 scraps) instead
## of Escape; duplicate: a second genuine copy for duplicate-occurrence coverage.
func _reach_dye_vat(fixture: Dictionary, reward: bool, feed: bool, duplicate: bool,
		keyboard_claim: bool = false) -> Dictionary:
	app.run_seed = fixture.seed
	if not await _routed_win(fixture, false):
		return {}
	var base_id := ""
	if reward:
		base_id = await _claim_upgradeable_reward(keyboard_claim)
		if base_id.is_empty():
			return {}
		if duplicate:
			var reordered: Array = app.run_deck.duplicate()
			reordered.insert(1, base_id)
			app.run_deck.assign(reordered)
			_check(app.run_deck.count(base_id) == 2, "two genuine copies of the source card sit in the live deck")
	else:
		await _click(app.reward_buttons[3])
		_check(app.fight_reward_claimed, "skipping the reward still leaves the real route")
	await _click(app.continue_button)
	var after_reward: int = app.run_scraps
	# First Event: the unchanged Quiet Spool, Watch for exactly one scrap.
	await _click(_route_action(fixture.path[0]))
	_check(app.quiet_spool_panel != null, "the first routed Event is still the Quiet Spool")
	if not is_instance_valid(app.quiet_spool_panel):
		return {}
	await _click(app.quiet_spool_panel.get_choice_buttons()[0])
	_check(app.run_scraps == after_reward + 1, "the unchanged Quiet Spool Watch funds exactly one scrap")
	# Second Event: the unchanged Moth Infestation; Feed one ordinary card or Escape.
	await _click(_route_action(fixture.path[1]))
	_check(app.moth_panel != null, "the second routed Event is still the Moth Infestation")
	if not is_instance_valid(app.moth_panel):
		return {}
	if feed:
		var list: ItemList = app._moth_picker
		var feed_row := -1
		for row in range(list.item_count):
			var index: int = list.get_item_metadata(row)
			if index >= 0 and index < app.run_deck.size() and app.run_deck[index] != base_id \
				and catalog.has_card(app.run_deck[index]):
				feed_row = row
				break
		_check(feed_row >= 0, "a genuine ordinary starter slot is available to feed")
		if feed_row < 0:
			return {}
		list.select(feed_row)
		list.item_selected.emit(feed_row)
		await _click(app.moth_panel.get_choice_buttons()[0])
		_check(app.run_scraps == after_reward + 1 + RunMothInfestationOutcome.SACRIFICE_SCRAP_GAIN,
			"the unchanged Moth Feed adds exactly two scraps")
		if not base_id.is_empty():
			_check(app.run_deck.count(base_id) == (2 if duplicate else 1),
				"feeding an ordinary card preserves every copy of the eligible base")
	else:
		await _click(app.moth_panel.get_choice_buttons()[2])
		_check(app.run_scraps == after_reward + 1, "the unchanged Moth Escape leaves the wallet alone")
	_check(app.moth_panel == null and app.route_view != null,
		"the second Event disposes its panel and restores the real route")
	return {"base_id": base_id, "after_reward": after_reward, "scraps": app.run_scraps}


## AC1/AC2: the third Event opens the authored Dye Vat through a real enabled route
## control, then Immerse upgrades exactly the keyboard-selected duplicate occurrence
## for three scraps and that upgraded deck enters the next routed battle.
func _dye_immerse_outcomes() -> void:
	var fixture := _dye_fixture()
	_check(not fixture.is_empty(), "seeded real Fight -> four Events -> Fight fixture exists")
	if fixture.is_empty():
		return
	var built := await _reach_dye_vat(fixture, true, true, true, false)
	if built.is_empty():
		return
	var base_id := String(built.get("base_id", ""))
	var plus_id := String(RunDyeVatOutcome.resolve_authored_pool_upgrade(base_id).get("upgrade_id", ""))
	_check(not plus_id.is_empty() and plus_id != base_id, "the source card has an authored '+' identity")
	var deck_before: Array = app.run_deck.duplicate()
	var scraps_before: int = app.run_scraps
	var descriptors_before: Dictionary = app.run_stitch_descriptors.duplicate(true)
	var cursor_before: int = app.run_next_stitch_id
	var gold_before: int = app.session_gold
	var heroes_before: Array = app.run_heroes.duplicate(true)
	var rng_before: int = app.run_rng.state
	_check(scraps_before == int(built.get("after_reward", -1)) + 1
		+ RunMothInfestationOutcome.SACRIFICE_SCRAP_GAIN and scraps_before >= RunDyeVatOutcome.UPGRADE_SCRAP_COST,
		"the genuine Fight reward and first two Events fund exactly one immerse")
	seed(730073)
	var global_next := randi()
	seed(730073)
	var third := _route_action(fixture.path[2])
	_check(third != null and not third.disabled and third.get_meta("route_kind") == "Event",
		"the third Event is an actual enabled route choice")
	if third == null:
		return
	var entry: Callable = third.pressed.get_connections()[0].callable
	await _click(third)
	var panel: LiveEventChoicePanel = app.dye_vat_panel
	_check(panel != null and panel.has_open_event() and app.route_view == null
		and not app._can_choose_connected_route(),
		"the third Event mounts the authored Dye Vat and blocks routing")
	if panel == null:
		return
	_check(panel.title_label.text == "The Dye Vat", "the Dye Vat record is selected by its stable authored ID")
	var panel_id: int = _check_event_backdrop(panel, "third Event")
	var buttons := panel.get_choice_buttons()
	var authored := _authored_dye_choices()
	_check(buttons.size() == 3 and authored.size() == 3
		and buttons[0].text == String(authored[0].get("text", "")) + "\nScraps -3"
		and buttons[1].text == String(authored[1].get("text", "")) + "\nScraps +1"
		and buttons[2].text == String(authored[2].get("text", "")) + "\nNo change to gold or scraps.",
		"the mounted screen shows the three authored Dye Vat choices")
	var picker: ItemList = app._dye_vat_picker
	var options: Array = app._dye_vat_outcome.get_immerse_options()
	_check(app._dye_vat_picker.has_focus(), "the eligible-occurrence selector owns initial keyboard focus")
	_check(is_instance_valid(picker) and options.size() == 2 and picker.item_count == 2,
		"the selector projects both duplicate eligible occurrences")
	if not is_instance_valid(picker) or picker.item_count != 2:
		return
	var copies: Array = []
	for row in range(picker.item_count):
		var index: int = picker.get_item_metadata(row)
		_check(index >= 0 and index < app.run_deck.size() and app.run_deck[index] == base_id,
			"row %d is an actual eligible deck occurrence" % row)
		_check(picker.get_item_text(row) == "Deck #%d: %s" % [index + 1, _pool_base_name(base_id)],
			"row %d shows the genuine source card name and position" % row)
		copies.append(index)
	_check(copies.size() == 2 and copies[0] != copies[1] and copies[0] < copies[1],
		"duplicate IDs stay two distinct, ordered deck occurrences")
	_check(app._dye_vat_picker_item_indices() == [int(options[0].get("index")), int(options[1].get("index"))],
		"the selector rows are exactly the service's finalized projection")
	_check(not buttons[0].disabled and not buttons[1].disabled and not buttons[2].disabled,
		"affordable Immerse, Skim and Leave are all usable")
	var commit: Callable = panel.choice_committed.get_connections()[0].callable
	var immerse_click: Callable = buttons[0].pressed.get_connections()[0].callable
	var before := _dye_state()
	_reject_dye(commit.bind("dye_vat", "immerse"), "forged unclaimed Immerse signal")
	_reject_dye(commit.bind("dye_vat", "skim_dye"), "forged unclaimed Skim signal")
	_reject_dye(entry, "duplicate third-Event entry request")
	var foreign := RunMap.new()
	_reject_dye(app._commit_dye_vat.bind("dye_vat", "immerse", panel, app._dye_vat_outcome,
		weakref(foreign)), "cross-run commit callback")
	_check(_dye_state() == before, "forged Dye Vat input changes nothing")
	# No selection: Immerse is forbidden while a genuine occurrence exists.
	picker.deselect_all()
	app._refresh_dye_vat_choices()
	_check(buttons[0].disabled, "Immerse is disabled with no selected occurrence")
	_reject_dye(commit.bind("dye_vat", "immerse"), "no-selection Immerse cannot claim")
	picker.select(0)
	app._refresh_dye_vat_choices()
	_check(not buttons[0].disabled and app._dye_vat_selected_index() == copies[0],
		"selecting an eligible occurrence re-enables Immerse")
	# A forged row that points at a real but ineligible starter never selects.
	var starter_index := -1
	for index in range(app.run_deck.size()):
		if catalog.has_card(app.run_deck[index]):
			starter_index = index
			break
	_check(starter_index >= 0, "a genuine starter slot exists as the forged-row target")
	var saved_meta: Variant = picker.get_item_metadata(0)
	picker.set_item_metadata(0, starter_index)
	picker.select(0)
	app._refresh_dye_vat_choices()
	_check(app._dye_vat_selected_index() == null and buttons[0].disabled,
		"a forged non-eligible row is not a valid selection")
	await _click(buttons[0])
	_check(app.dye_vat_panel == panel and not panel._selector.is_claimed()
		and app.run_deck == deck_before and app.run_scraps == scraps_before,
		"a forged row cannot spend, upgrade or latch the visit")
	picker.set_item_metadata(0, saved_meta)
	picker.select(0)
	app._refresh_dye_vat_choices()
	_check(app._dye_vat_selected_index() == copies[0], "restoring the row selects the genuine occurrence")
	# Keyboard: the later duplicate row, Tab to Immerse, Enter to commit.
	var chosen: int = copies[1]
	picker.grab_focus()
	await _key(KEY_DOWN)
	_check(picker.get_selected_items().size() == 1 and int(picker.get_selected_items()[0]) == 1,
		"physical arrow keys select the later duplicate row")
	_check(app._dye_vat_selected_index() == chosen, "the keyboard selection keeps its exact deck index")
	await _key(KEY_TAB)
	_check(buttons[0].has_focus(), "Tab reaches Immerse from the selector")
	await _key(KEY_ENTER)
	_check(app.dye_vat_panel == null and app._dye_vat_completed and app.route_view != null,
		"Immerse disposes the panel and restores the connected route")
	_check(not is_instance_id_valid(panel_id), "Immerse frees the third Event art bed with its panel")
	var expected: Array = deck_before.duplicate()
	expected[chosen] = plus_id
	_check(app.run_deck == expected,
		"Immerse replaces exactly the chosen occurrence with the authored plus")
	_check(app.run_deck.count(base_id) == 1 and app.run_deck.count(plus_id) == 1,
		"the other genuine copy and every unrelated card survive")
	_check(app.run_scraps == scraps_before - RunDyeVatOutcome.UPGRADE_SCRAP_COST
		and app.run_scraps == int(built.get("after_reward", -1)),
		"Immerse spends exactly three scraps once")
	_check(app.run_stitch_descriptors == descriptors_before and app.run_next_stitch_id == cursor_before
		and app.session_gold == gold_before and app.run_heroes == heroes_before
		and app.run_rng.state == rng_before,
		"Immerse preserves descriptors, cursor, gold, heroes and RNG")
	_check(String(RunRestStitchCards.resolve_card_definition(plus_id).get("id", "")) == plus_id,
		"the upgraded occurrence resolves to its authored definition")
	var settled := _dye_state()
	for callback in [commit.bind("dye_vat", "immerse"), commit.bind("dye_vat", "leave"), immerse_click, entry]:
		_reject_dye(callback, "replayed Dye Vat input after Immerse")
	_check(_dye_state() == settled, "duplicate or stale Dye Vat input changes nothing")
	# A later Event keeps the no-effect placeholder past the Dye Vat.
	var later := _route_action(fixture.path[3])
	_check(later != null and not later.disabled and later.get_meta("route_kind") == "Event",
		"the Event after the Dye Vat is an enabled placeholder choice")
	if later == null:
		return
	var later_route: Array = app.run_map.get_route()
	var later_deck: Array = app.run_deck.duplicate()
	var later_resources := _effects()
	await _click(later)
	_check(app.dye_vat_panel == null and app.quiet_spool_panel == null and app.moth_panel == null
		and app.run_map.get_route() == later_route + [fixture.path[3]] and app.route_view != null
		and app.run_deck == later_deck and _effects() == later_resources,
		"a later Event keeps the no-effect placeholder")
	# AC2 re-entry: the upgraded deck enters the next genuinely routed battle.
	var next := _route_action(fixture.path[4])
	_check(next != null and not next.disabled, "the routed Fight after the Dye Vat is an enabled choice")
	if next == null:
		return
	await _click(next)
	_check(app.deck != null and app.party != null and app.party.is_valid(),
		"the next routed battle mounts after the Dye Vat")
	if app.deck == null:
		return
	var piles: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
	var sorted_piles := piles.duplicate()
	sorted_piles.sort()
	var sorted_run: Array = app.run_deck.duplicate()
	sorted_run.sort()
	_check(piles.size() == app.run_deck.size() and sorted_piles == sorted_run,
		"the battle holds exactly the immersed run deck")
	_check(piles.count(plus_id) == 1 and piles.count(base_id) == 1,
		"the upgraded occurrence enters the next routed battle")
	_check(randi() == global_next, "Dye Vat entry, rejection and commit preserve the actual global RNG")
	app._return_to_title()
	await _frames()
	_check(app.dye_vat_panel == null and app._dye_vat_context.is_empty() and app._dye_vat_picker == null
		and not app._dye_vat_completed and app._dye_vat_node.is_empty(),
		"the title return releases every Dye Vat binding")


## AC3: an eligible base with fewer than three scraps cannot Immerse, while Leave
## keeps the deck and wallet exactly unchanged.
func _dye_unaffordable_outcomes() -> void:
	var fixture := _dye_fixture()
	if fixture.is_empty():
		return
	var built := await _reach_dye_vat(fixture, true, false, false, true)
	if built.is_empty():
		return
	var base_id := String(built.get("base_id", ""))
	_check(not RunDyeVatOutcome.resolve_authored_pool_upgrade(base_id).is_empty(),
		"the run genuinely owns an eligible base")
	var probe := RunDyeVatOutcome.new(app.run_deck, app.run_stitch_descriptors, 3, app.run_next_stitch_id)
	_check(probe.is_valid() and probe.get_immerse_options().size() == 1,
		"the same deck has one eligible occurrence once three scraps are available")
	var deck_before: Array = app.run_deck.duplicate()
	var scraps_before: int = app.run_scraps
	_check(scraps_before == int(built.get("after_reward", -1)) + 1
		and scraps_before < RunDyeVatOutcome.UPGRADE_SCRAP_COST,
		"the unchanged first two Events leave fewer than three scraps")
	var third := _route_action(fixture.path[2])
	if third == null:
		return
	third.grab_focus()
	await _key(KEY_ENTER)
	var panel: LiveEventChoicePanel = app.dye_vat_panel
	_check(panel != null and panel.has_open_event() and app.route_view == null,
		"keyboard entry mounts the authored Dye Vat")
	if panel == null:
		return
	_check_event_backdrop(panel, "unaffordable third Event")
	var buttons := panel.get_choice_buttons()
	var picker: ItemList = app._dye_vat_picker
	_check(is_instance_valid(picker) and picker.item_count == 0,
		"below three scraps the selector offers no immerse occurrence")
	_check(buttons[0].disabled, "unaffordable Immerse is disabled")
	_check(not buttons[1].disabled and not buttons[2].disabled, "Skim and Leave stay usable")
	_check(is_instance_valid(picker) and picker.item_count == 0
		and panel.find_child("DyeVatPrompt", true, false) != null
		and panel.find_child("DyeVatPrompt", true, false).text.contains("needs 3 scraps"),
		"the prompt explains the exact missing scrap cost")
	var before := _dye_state()
	var commit: Callable = panel.choice_committed.get_connections()[0].callable
	await _click(buttons[0])
	_reject_dye(commit.bind("dye_vat", "immerse"), "forged unaffordable Immerse signal")
	_check(_dye_state() == before and not panel._selector.is_claimed(),
		"unaffordable Immerse cannot claim, upgrade, spend or route")
	await _click(buttons[2])
	_check(app.dye_vat_panel == null and app._dye_vat_completed and app.route_view != null,
		"Leave disposes the panel and restores the connected route")
	_check(app.run_deck == deck_before and app.run_scraps == scraps_before,
		"Leave changes no card and no scrap")
	_reject_dye(commit.bind("dye_vat", "leave"), "replayed Leave after completion")
	app._return_to_title()
	await _frames()


## AC3: no eligible base at all still opens the genuine screen, cannot Immerse and
## pays exactly one scrap for Skim. Malformed authored records fail closed.
func _dye_no_base_outcomes() -> void:
	var fixture := _opening_dye_fixture()
	_check(not fixture.is_empty(), "seeded zero-fight opening route reaches three Events")
	if fixture.is_empty():
		return
	app.run_seed = fixture.seed
	await _click(app.start_button)
	await _click(_route_action(fixture.path[0]))
	_check(app.quiet_spool_panel != null, "the opening route's first Event is the Quiet Spool")
	if not is_instance_valid(app.quiet_spool_panel):
		return
	await _click(app.quiet_spool_panel.get_choice_buttons()[1])
	_check(app.run_scraps == 0, "Ignore leaves a zero-scrap wallet")
	await _click(_route_action(fixture.path[1]))
	_check(app.moth_panel != null, "the opening route's second Event is the Moth Infestation")
	if not is_instance_valid(app.moth_panel):
		return
	await _click(app.moth_panel.get_choice_buttons()[2])
	_check(app.moth_panel == null and app.run_scraps == 0, "Escape leaves the wallet at zero")
	for index in range(app.run_deck.size()):
		_check(RunDyeVatOutcome.resolve_authored_pool_upgrade(app.run_deck[index]).is_empty(),
			"the starter deck genuinely owns no eligible pool base")
	var starter_probe := RunDyeVatOutcome.new(app.run_deck, app.run_stitch_descriptors, 3, app.run_next_stitch_id)
	_check(starter_probe.is_valid() and starter_probe.get_immerse_options().is_empty(),
		"even with three scraps the starter-only deck offers no eligible base")
	# Fail-closed authored data: malformed or retuned records never enter the node.
	var broken := OS.get_environment("TEMP").path_join("dye_vat_route_invalid.json")
	for malformed in ["{}", "not JSON", '{"id":"dye_vat"}',
		'{"id":"dye_vat","title":"Vat","description":"V","choices":[{"id":"immerse","text":"I","outcome":{"gold":0,"scraps":-3}},{"id":"skim_dye","text":"S","outcome":{"gold":0,"scraps":1}}]}',
		'{"id":"dye_vat","title":"Vat","description":"V","choices":[{"id":"immerse","text":"I","outcome":{"gold":1,"scraps":-3}},{"id":"skim_dye","text":"S","outcome":{"gold":0,"scraps":1}},{"id":"leave","text":"L","outcome":{"gold":0,"scraps":0}}]}',
		'{"id":"dye_vat","title":"Vat","description":"V","choices":[{"id":"immerse","text":"I","outcome":{"gold":0,"scraps":-2}},{"id":"skim_dye","text":"S","outcome":{"gold":0,"scraps":1}},{"id":"leave","text":"L","outcome":{"gold":0,"scraps":0}}]}',
		'{"id":"dye_vat","title":"Vat","description":"V","choices":[{"id":"immerse","text":"I","outcome":{"gold":0,"scraps":-3}},{"id":"skim_dye","text":"S","outcome":{"gold":0,"scraps":1}},{"id":"leave","text":"L","outcome":{"gold":0,"scraps":2}}]}']:
		var file := FileAccess.open(broken, FileAccess.WRITE)
		_check(file != null, "external malformed Dye Vat fixture writable")
		if file == null:
			continue
		file.store_string(malformed)
		file.close()
		app.dye_vat_catalog_path = broken
		var route_before: Array = app.run_map.get_route()
		var before := _dye_state()
		await _click(_route_action(fixture.path[2]))
		_check(app.dye_vat_panel == null and app.run_map.get_route() == route_before
			and _dye_state() == before and is_instance_valid(app.route_view),
			"malformed or retuned authored Dye Vat record rejects before entry")
	DirAccess.remove_absolute(broken)
	app.dye_vat_catalog_path = DYE_EVENT_PATH
	var deck_before: Array = app.run_deck.duplicate()
	var third := _route_action(fixture.path[2])
	if third == null:
		return
	await _click(third)
	var panel: LiveEventChoicePanel = app.dye_vat_panel
	_check(panel != null and panel.has_open_event() and app.route_view == null
		and not app._can_choose_connected_route(),
		"the third Event still mounts the Dye Vat with no eligible base")
	if panel == null:
		return
	_check_event_backdrop(panel, "no-base third Event")
	var buttons := panel.get_choice_buttons()
	var picker: ItemList = app._dye_vat_picker
	_check(is_instance_valid(picker) and picker.item_count == 0 and buttons[0].disabled,
		"no eligible base leaves Immerse disabled and the selector empty")
	_check(not buttons[1].disabled and not buttons[2].disabled, "Skim and Leave remain usable")
	var commit: Callable = panel.choice_committed.get_connections()[0].callable
	await _click(buttons[0])
	_check(app.dye_vat_panel == panel and not panel._selector.is_claimed(),
		"no-base Immerse cannot claim")
	_reject_dye(commit.bind("dye_vat", "immerse"), "forged no-base Immerse signal")
	await _click(buttons[1])
	_check(app.dye_vat_panel == null and app._dye_vat_completed and app.route_view != null,
		"Skim disposes the panel and restores the connected route")
	_check(app.run_deck == deck_before and app.run_scraps == RunDyeVatOutcome.SKIM_SCRAP_GAIN,
		"Skim pays exactly one scrap and changes no card")
	_reject_dye(commit.bind("dye_vat", "skim_dye"), "replayed Skim after completion")
	app._return_to_title()
	await _frames()
	_check(app.dye_vat_panel == null and app._dye_vat_context.is_empty() and not app._dye_vat_completed,
		"the title return resets Dye Vat eligibility")


## AC3: a latched panel choice with a drifted run context cannot settle, spend or
## route; a fresh same-seed run reaches the Dye Vat again.
func _dye_stale_context_outcome() -> void:
	var fixture := _dye_fixture()
	if fixture.is_empty():
		return
	var built := await _reach_dye_vat(fixture, true, true, true, false)
	if built.is_empty():
		return
	var base_id := String(built.get("base_id", ""))
	var third := _route_action(fixture.path[2])
	if third == null:
		return
	await _click(third)
	var panel: LiveEventChoicePanel = app.dye_vat_panel
	_check(panel != null and app._dye_vat_picker != null and app._dye_vat_picker.item_count == 2,
		"re-entered Dye Vat presents both eligible occurrences again")
	if panel == null:
		return
	_check(app._dye_vat_outcome.get_immerse_options().size() == 2
		and String(app.run_deck[app._dye_vat_picker.get_item_metadata(0)]) == base_id,
		"the fresh same-seed visit replays the same genuine projection")
	var buttons := panel.get_choice_buttons()
	var deck_before: Array = app.run_deck.duplicate()
	var scraps_before: int = app.run_scraps
	var route_before: Array = app.run_map.get_route()
	var rng_before: int = app.run_rng.state
	app.session_gold += 1
	await _click(buttons[0])
	_check(panel._selector.is_claimed() and not app._dye_vat_outcome.is_claimed(),
		"the actual panel signal reaches the stale-context rejection")
	_check(app.dye_vat_panel == panel and app.run_deck == deck_before
		and app.run_map.get_route() == route_before and app.run_scraps == scraps_before
		and app.run_rng.state == rng_before and not app._dye_vat_completed and app.route_view == null,
		"a drifted context cannot upgrade, spend, latch or route")
	_reject_dye(panel.choice_committed.get_connections()[0].callable.bind("dye_vat", "immerse"),
		"replayed stale Immerse signal")
	app._return_to_title()
	await _frames()


func _title_reset() -> void:
	app._return_to_title()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	await _dye_immerse_outcomes()
	await _title_reset()
	await _dye_unaffordable_outcomes()
	await _title_reset()
	await _dye_no_base_outcomes()
	await _title_reset()
	await _dye_stale_context_outcome()
	await _title_reset()
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_dye_vat_event_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
