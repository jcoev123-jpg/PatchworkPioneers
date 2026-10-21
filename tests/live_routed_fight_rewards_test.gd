extends "res://tests/live_rest_route_entry_test.gd"
## Real route and held-card combat; independent reward draw arithmetic.

var expected_offers: Array = []
var expected_award := 0
var expected_rng := 0
var retained_rewards: Array[Callable] = []
var active_checked := false


func _persistent() -> Array:
	return super._persistent() + [app.run_scraps, app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id]


func _click(control: Control) -> void:
	await super._click(control)
	if not active_checked and app.battle_result != null and not app._battle_closed:
		active_checked = true
		var before := _persistent()
		var unprepared := RunFightVictoryRewards.new(app.battle_result, app.run_rng,
			["warden", "seamstress", "tinker"], catalog.get_all_card_ids(), app.run_deck, app.session_gold, false)
		_check(not unprepared.choose("").ok and not unprepared.prepare().ok, "active/unprepared service rejects")
		app._build_card_reward()
		app._claim_card_reward("", app.return_button, unprepared)
		for callback in retained_rewards:
			callback.call()
		_check(_persistent() == before and app.fight_rewards == null and app.reward_buttons.is_empty(),
			"active preparation, claims and previous-session callbacks never pay or consume RNG")


func _key(code: Key) -> void:
	var rng_before := 0
	var was_active: bool = app.battle_result != null and not app._battle_closed
	if was_active:
		rng_before = app.run_rng.state
	await super._key(code)
	if was_active and app._battle_closed and app.battle_result.get_outcome() == CombatBattleResult.VICTORY:
		var oracle := RandomNumberGenerator.new()
		oracle.seed = app.run_rng.seed
		oracle.state = rng_before
		expected_award = oracle.randi_range(10, 20)
		var pool: Array[String] = []
		var owners: Array = []
		for hero in app.party.get_heroes():
			owners.append(hero.id)
		for id in catalog.get_all_card_ids():
			if catalog.get_definition(id).owner in owners:
				pool.append(id)
		pool.sort()
		expected_offers = []
		for pick in range(3):
			var index := oracle.randi_range(0, pool.size() - 1)
			var id: String = pool.pop_at(index)
			expected_offers.append({"id": id, "owner": catalog.get_definition(id).owner})
		expected_rng = oracle.state


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "seeded real Fight fixture exists")
	if fixture.is_empty():
		await _finish_rewards()
		return
	var stale: Array[Callable] = []
	var replay: Array = []
	for session in range(3):
		active_checked = false
		if not await _routed_win(fixture, false):
			break
		_check(not expected_offers.is_empty() and app.fight_reward_offers == expected_offers
			and app.fight_reward_gold == expected_award and expected_award >= 10 and expected_award <= 20
			and app.run_rng.state == expected_rng, "independent oracle: one gold draw then three distinct sorted-pool draws")
		_check(app.run_scraps == 0, "new run and pending rewards have no scraps")
		_check(app.session_gold == 0 and not app.fight_reward_claimed and app.card_reward == null
			and not app.victory_gold.is_claimed(), "routed prepare never pays or uses separate demo transactions")
		_check(app.reward_buttons.size() == 4 and app.result_label.text.contains("Pending gold: %d" % expected_award),
			"four mounted choices and pending award are visible")
		if app.reward_buttons.size() != 4:
			break
		for index in range(4):
			var button: Button = app.reward_buttons[index]
			_check(button.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()),
				"all reward controls fit viewport")
			if index < 3:
				_check(button.get_parent().get_node("OwnerLabel").text == expected_offers[index].owner.capitalize() and button.get_parent().get_node("IdLabel").text == expected_offers[index].id,
					"visible actual authored ID and owner")
		var before := _persistent()
		var service: RunFightVictoryRewards = app.fight_rewards
		for repeat in range(3):
			app._observe_battle_result()
			app._build_card_reward()
			_check(service.prepare().offers == expected_offers, "prepare is idempotent")
		_check(_persistent() == before and app.fight_rewards == service and app.reward_buttons.size() == 4,
			"observation and rebuild never reroll or duplicate controls")
		for callback in stale:
			callback.call()
		var foreign := ""
		for id in catalog.get_all_card_ids():
			if id not in expected_offers.map(func(offer): return offer.id):
				foreign = id
		_check(not foreign.is_empty(), "foreign authored ID fixture exists")
		app._claim_card_reward(foreign, app.reward_buttons[0], service)
		app._claim_card_reward(expected_offers[1].id, app.reward_buttons[0], service)
		app._claim_card_reward(expected_offers[0].id, app.return_button, service)
		_check(not service.choose(foreign).ok, "service also rejects foreign authored ID")
		var original_offer: Dictionary = app.fight_reward_offers[0].duplicate()
		var original_text: String = app.reward_buttons[0].text
		app.fight_reward_offers[0] = {"id": foreign, "owner": catalog.get_definition(foreign).owner}
		app.reward_buttons[0].text = foreign
		app._claim_card_reward(foreign, app.reward_buttons[0], service)
		app.fight_reward_offers[0] = original_offer
		app.reward_buttons[0].text = original_text
		app._continue_to_rest_route(service, weakref(app.run_map), null)
		_check(_persistent() == before and not app.fight_reward_claimed and app.continue_button == null,
			"foreign, mismatched, stale and unclaimed inputs grant nothing or consume RNG")
		var party_before: CombatParty = app.party
		app.party = _defeated_party()
		var defeated_before := _persistent()
		app.reward_buttons[0].pressed.emit()
		_check(_persistent() == defeated_before and not app.fight_reward_claimed, "defeated party cannot claim prepared victory")
		app.party = party_before
		var callbacks: Array[Callable] = []
		for button in app.reward_buttons:
			callbacks.append(button.pressed.get_connections()[0].callable)
		var owned: Array = app.run_deck.duplicate()
		if session == 1:
			app.reward_buttons[2].grab_focus()
			await _key(KEY_TAB)
			_check(app.reward_buttons[3].has_focus(), "Tab reaches Skip")
			await _key(KEY_ENTER)
		else:
			await _click(app.reward_buttons[0])
			owned.append(expected_offers[0].id)
		_check(app.fight_reward_claimed and app.run_deck == owned and app.session_gold == expected_award
			and app.run_heroes == _block_free_party() and app.run_rng.state == expected_rng,
			"physical choice/Skip publishes exactly owned deck and one award; heroes/RNG preserved")
		_check(app.run_scraps == 1, "Fight pick and Skip grant exactly one scrap")
		_check(is_instance_valid(app.continue_button), "successful transaction creates Continue")
		if not is_instance_valid(app.continue_button):
			break
		var after := _persistent()
		for button in app.reward_buttons:
			_check(button.disabled, "claim disables each reward action")
			button.disabled = false
		for callback in callbacks:
			callback.call()
		_check(not service.choose("").ok and _persistent() == after, "forced duplicate callbacks and service replay pay nothing")
		if session == 0:
			replay = after.duplicate(true)
		elif session == 2:
			_check(after == replay and app.fight_reward_offers == expected_offers, "same-seed restart repeats offers, award, deck, heroes and RNG")
		stale = callbacks
		stale.append(app.continue_button.pressed.get_connections()[0].callable)
		retained_rewards = stale
		await _click(app.return_button)
		for callback in stale:
			callback.call()
		_check(app.fight_rewards == null and not app.fight_reward_claimed and app.fight_reward_offers.is_empty()
			and app.session_gold == 0 and app.run_deck.is_empty() and app.title_view.visible,
			"Return clears service/latch and retained callbacks cannot restore rewards")
	await _finish_rewards()


func _finish_rewards() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_routed_fight_rewards_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
