extends "res://tests/live_tinker_path_hand_test.gd"
## Genuine village -> Fight -> authored reward -> later Fight -> fresh Fight.
## Inherited helpers only provide real mouse/keyboard input and mounted lookup.

const HEAVIES := ["warden_heavy_thimble", "warden_pin_and_pound"]


func _warden_fixture(id: String, path: String) -> Dictionary:
	var owners: Array[String] = ["warden", "seamstress", "tinker"]
	for value in range(1, 600):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			for second in map.get_node(first).outgoing:
				if map.get_node(second).type != "Fight":
					continue
				for third in map.get_node(second).outgoing:
					if map.get_node(third).type != "Fight":
						continue
					var oracle := _oracle(value, first,
						["warden_lance_pin" if path == "vanguard" else "warden_bulwark_brace"])
					if oracle.is_empty():
						continue
					var party := CombatParty.new(app._load_party_definitions())
					var foes := CombatEnemies.new(app._load_enemy_definitions())
					var result := CombatBattleResult.new(party, foes)
					for foe in foes.get_enemies():
						foes.apply_damage(foe.position, 9999)
					result.evaluate()
					rng.state = oracle.rng_state
					var reward := RunFightVictoryRewards.new(result, rng,
						["warden", "seamstress", "tinker"],
						app._reward_candidate_records(owners),
						StarterCards.new().get_starting_deck(), 0, false)
					var prepared := reward.prepare()
					for offer in prepared.get("offers", []):
						if offer.id == id:
							return {"seed": value, "node_id": first, "second": second, "third": third}
	return {}


func _warden_world() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state,
		presenter._pinned._pinner_by_position.duplicate(true),
		presenter._vanguard.current_turn() if presenter._vanguard != null else 0,
		presenter._vanguard._used if presenter._vanguard != null else false]


func _win_and_leave(reward_id: String = "") -> void:
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(enemy.position, 9999)
	app._observe_battle_result()
	await _frames()
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app.reward_buttons.size() == 4, "real victory mounts genuine reward")
	var index := 3
	for i in range(app.fight_reward_offers.size()):
		if app.fight_reward_offers[i].id == reward_id:
			index = i
	_check(reward_id.is_empty() or index < 3, "requested heavy is genuinely offered")
	await _click(app.reward_buttons[index])
	_check(reward_id.is_empty() or app.run_deck.has(reward_id), "reward really joins canonical run deck")
	await _click(app.continue_button)


func _hold(id: String) -> bool:
	while not app.deck.hand.has(id) and (not app.deck.draw_pile.is_empty() or not app.deck.discard_pile.is_empty()):
		_check(app.deck.draw_extra(1) == 1, "draw an owned card from admitted battle deck")
	app._refresh_hand()
	await _frames()
	_check(app.deck.hand.has(id) and _panel(id) != null, "authored owned heavy is held and mounted")
	return _panel(id) != null


func _cast(id: String, slot: int = 1) -> void:
	await _click(_panel(id))
	await _key(KEY_1 if slot == 1 else KEY_2)
	_check(presenter.last_event.get("ok", false), "physical held-card input pays through real heavy resolver")


func _entry(fixture: Dictionary, path: String) -> void:
	app.run_seed = fixture.seed
	await _click(app.base_button)
	var view: BaseScreen = app.base_screen
	_check(view != null and view.warden_buttons.size() == 2, "mounted village offers Warden choices")
	app._base_warden_path_choice("forged", weakref(view))
	_check(not app.run_warden_path_choice.is_claimed(), "invalid choice does not consume claim")
	var target: Button = view.warden_buttons[0 if path == "bulwark" else 1]
	# Walk the village's real focus graph to its non-first Warden option.
	for attempt in range(16):
		if target.has_focus():
			break
		await _key(KEY_TAB)
	_check(target.has_focus(), "Tab reaches authored Warden option")
	await _key(KEY_ENTER)
	_check(view.selected_warden_path_id() == path and app.run_warden_path_choice.is_claimed(),
		"keyboard selection claims one authoritative setup receipt")
	var receipt: Dictionary = app.run_warden_path_choice.get_receipt()
	app._base_warden_path_choice("bulwark" if path == "vanguard" else "vanguard", weakref(view))
	_check(app.run_warden_path_choice.get_receipt() == receipt and app.run_warden_path_receipt.is_empty(),
		"duplicate cannot replace setup; run receipt waits for Set out")
	await _click(view.set_out_button)
	_check(app.run_warden_path_receipt == receipt
		and RunWardenPathChoice.authenticate_receipt(app.run_warden_path_receipt).ok,
		"Set out commits exact authenticated receipt")
	var rng_before: int = app.run_rng.state
	var route_before: Array = app.run_map.get_route()
	app.run_warden_path_receipt["display_name"] = "forged"
	await _click(_route_button(fixture.node_id))
	_check(app.deck == null and app.run_map.get_route() == route_before
		and app.run_rng.state == rng_before and app.route_view.is_visible_in_tree(),
		"forged run receipt refuses routed admission without route/RNG mutation")
	app.run_warden_path_receipt = receipt.duplicate(true)
	await _click(_route_button(fixture.node_id))
	presenter = app.get_node("LiveAttackPreview")
	_check(app._combo_battle_current() and presenter._deck == app.deck, "genuine routed battle owns live models")
	_check(app.party.get_hero(1).block == (0 if path == "vanguard" else 10), "distinct authored Path opening Block")
	var selected := "warden_lance_pin" if path == "vanguard" else "warden_bulwark_brace"
	var other := "warden_bulwark_brace" if path == "vanguard" else "warden_lance_pin"
	var battle_cards: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
	_check(battle_cards.count(selected) == 1 and not battle_cards.has(other)
		and not app.run_deck.has(selected) and not app.run_deck.has(other),
		"only the selected Path card enters the battle, never the run deck")


func _sew_attack_patches() -> void:
	app.run_trinkets.append_array(["frayfinder_mitt", "button_eye"])
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		[{"id": "frayfinder_mitt", "slot": "ARM"}, {"id": "button_eye", "slot": "HEAD"}],
		app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid(), "authored owned patches create valid run wardrobe")
	for patch in [["frayfinder_mitt", "ARM"], ["button_eye", "HEAD"]]:
		_check(wardrobe.sew(patch[0], "warden", patch[1], "vanguard:" + patch[0],
			wardrobe.get_snapshot()).ok, "genuine wardrobe sew " + patch[0])
	_check(app.party_carryover.bind_wardrobe(wardrobe, app.party_carryover.torn,
		wardrobe.get_snapshot()), "run carryover authenticates sewn wardrobe before admission")


func _case(id: String, path: String, patched: bool = false, lethal: bool = false) -> void:
	app = load(APP_SCENE).instantiate()
	root.add_child(app)
	await _frames()
	var fixture := _warden_fixture(id, path)
	_check(not fixture.is_empty(), "seeded three-Fight route genuinely offers " + id)
	if fixture.is_empty():
		await _dispose()
		return
	await _entry(fixture, path)
	await _win_and_leave(id)
	if patched:
		_sew_attack_patches()
	await _click(_route_button(fixture.second))
	await _frames()
	_check(app.run_deck.has(id) and app._combo_battle_current(), "claimed heavy admitted into true next fight")
	_check((presenter._vanguard != null) == (path == "vanguard"), "only Vanguard binds passive")
	if not await _hold(id):
		await _dispose()
		return
	if patched:
		_check(presenter._fray != null and presenter._fray.is_valid(), "routed attack owns genuine Mitt authority")
		_check(presenter._unravel.apply_unravel(app.enemies, 1, 4), "raise shared battle gauge to authored Mitt threshold")
		_check(presenter._fray.quote_heavy_hit(id, 1).get("bonus") == 2, "genuine first Mitt bonus is armed")
	if lethal:
		app.enemies.apply_damage(1, app.enemies.get_enemy(1).hp - 1)
		_check(app.enemies.get_enemy(1).hp == 1, "lethal target is still living before commit")
	var before := _warden_world()
	presenter._hover(_panel(id))
	presenter._refresh()
	_check(_warden_world() == before, "hover never pins, pays or changes RNG/latch")
	_check(not presenter._resolve_attack(app.party, app.enemies, "warden_heavy_thimble_forged", 1).get("ok", false),
		"forged card rejected")
	_check(_warden_world() == before, "forged card is atomic")
	_check(not presenter._resolve_attack(app.party, app.enemies, id, 0).get("ok", false), "invalid original target rejected")
	_check(_warden_world() == before, "bad target is atomic")
	var old_map = app.run_map
	# Retain an actual queued callback, then make its route stale before dispatch.
	await _click(_panel(id))
	var panel := _panel(id)
	presenter._queued = true
	app.run_map = RunMap.new()
	presenter._commit(panel, id, 1, presenter._token, app.party, app.enemies, app.battle_result,
		app.run_rng, app.enemy_intents._turn_index,
		app.enemies.get_enemy(1).id, panel.get_index(), app.deck, app.deck.hand.duplicate(), old_map, presenter._pinned)
	app.run_map = old_map
	_check(_warden_world() == before, "stale queued route cannot spend or pin")
	presenter._cancel_choice()
	# A queued callback from a different announced turn is inert as well.
	await _click(_panel(id))
	presenter._queued = true
	presenter._commit(panel, id, 1, presenter._token, app.party, app.enemies, app.battle_result,
		app.run_rng, app.enemy_intents._turn_index - 1, app.enemies.get_enemy(1).id,
		panel.get_index(), app.deck, app.deck.hand.duplicate(), app.run_map, presenter._pinned)
	_check(_warden_world() == before, "stale queued turn cannot spend, pin or change RNG")
	presenter._cancel_choice()
	var energy: int = app.deck.energy
	var rng: int = app.run_rng.state
	var hp: int = app.enemies.get_enemy(1).hp
	await _cast(id)
	_check(app.deck.energy == energy - 2 and app.run_rng.state == rng
		and app.deck.discard_pile.has(id), "confirmed heavy pays and discards once without RNG")
	_check(presenter.last_event.get("hits", []).size() == (2 if id == HEAVIES[1] and not lethal else 1), "all living-target authored heavy hits finish")
	if patched:
		_check(presenter._fray.latch_snapshot().get("warden", false)
			and presenter.last_event.hits[0].statuses.get("exposed") == 1,
			"same paid hit consumes Mitt and Button Eye before Vanguard confirmation")
	if path == "vanguard":
		_check(presenter._vanguard._used, "first confirmed hit spends per-turn entitlement")
		_check(presenter._pinned.pinner_for_enemy(1) == ("warden" if app.enemies.get_enemy(1).hp > 0 else ""),
			"original living target pinned after complete paid hit, corpse never pinned")
		_check(app.enemies.get_enemy(1).hp < hp, "real target took damage")
		var spent := _warden_world()
		presenter.advance_warden_turn()
		presenter._sync_battle()
		_check(_warden_world() == spent, "duplicate turn callback and redraw cannot rearm")
		# A real failed End Turn preflight leaves used latch and every authority intact.
		var announced: Array = app.enemy_attacks
		app.enemy_attacks = []
		app._end_turn(app.end_turn_button)
		app.enemy_attacks = announced
		_check(_warden_world() == spent, "failed End Turn cannot spend RNG or rearm")
		# Refused replay with no energy cannot manufacture a second pin.
		_check(not presenter._resolve_attack(app.party, app.enemies, id, 2).get("ok", false), "unheld/underfunded repeat refuses")
		_check(_warden_world() == spent, "refused second heavy leaves all state unchanged")
		var serial: int = presenter._vanguard.current_turn()
		await _click(app.end_turn_button)
		_check(app.deck.turn_active and presenter._vanguard.current_turn() == serial + 1
			and not presenter._vanguard._used, "successful End Turn deals new hand and re-arms once")
		if await _hold(id):
			# The untouched second original slot survives the first heavy.
			_check(not app.enemies.is_slain(2), "next-turn target is genuinely living")
			await _cast(id, 2)
			_check(presenter._vanguard._used and presenter._pinned.pinner_for_enemy(2)
				== ("warden" if not app.enemies.is_slain(2) else ""), "next turn confirmed heavy earns its own pin")
	else:
		_check(presenter._pinned._pinner_by_position.is_empty(), "Bulwark retains original heavy behavior")
	var retired = presenter._vanguard
	await _win_and_leave()
	await _click(_route_button(fixture.third))
	await _frames()
	if path == "vanguard":
		_check(retired != null and not retired._bound and presenter._vanguard != retired
			and presenter._vanguard.current_turn() == 1 and not presenter._vanguard._used
			and presenter._pinned._pinner_by_position.is_empty(), "new routed fight retires old binding and starts fresh")
		var intent_turn: int = app.enemy_intents._turn_index
		app.run_warden_path_receipt["display_name"] = "stale authority"
		await _click(app.end_turn_button)
		_check(app.enemy_intents._turn_index == intent_turn + 1
			and presenter._vanguard.current_turn() == 1,
			"even successful new-hand transition cannot rearm an invalid Path authority")
	await _click(app.return_button)
	_check(app.run_warden_path_choice == null and app.run_warden_path_receipt.is_empty()
		and presenter._vanguard == null, "return retires receipt and combat binding")
	await _dispose()


func _abandon() -> void:
	app = load(APP_SCENE).instantiate()
	root.add_child(app)
	await _frames()
	await _click(app.base_button)
	var old: BaseScreen = app.base_screen
	var stale: Callable = old.warden_path_choice_requested.get_connections()[0].callable
	await _click(old.warden_buttons[1])
	await _click(old.back_button)
	stale.call("bulwark")
	_check(app.run_warden_path_choice == null and app.run_warden_path_receipt.is_empty(), "Back and retained choice abandon setup")
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	_check(app.run_warden_path_receipt.is_empty(), "title-only Start run grants no Path")
	await _click(app.route_back_button)
	await _click(app.base_button)
	await _click(app.base_screen.warden_buttons[1])
	await _click(app.base_screen.set_out_button)
	await _click(app.route_back_button)
	_check(app.run_warden_path_receipt.is_empty() and app.base_screen != null
		and not app.run_warden_path_choice.is_claimed(), "abandoned opening restores fresh unclaimed village")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _abandon()
	for id in HEAVIES:
		await _case(id, "vanguard")
	await _case(HEAVIES[0], "bulwark")
	await _case(HEAVIES[0], "vanguard", true)
	await _case(HEAVIES[1], "vanguard", false, true)
	if failures.is_empty():
		print("live_warden_vanguard_route_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		quit(1)

