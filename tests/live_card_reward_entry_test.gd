extends "res://tests/live_legal_starter_fight_test.gd"
## Reuse physical input helpers, never a test-only fight or reward transaction.


func _win() -> Array:
	app.start_button.grab_focus()
	await _key(KEY_ENTER)
	_check(app.deck != null and app.party.is_valid() and app.enemies.is_valid(), "title starts valid live fight")
	if app.deck == null:
		return []
	_check(app.run_deck == catalog.get_starting_deck(), "independent inventory copies validated starter IDs")
	_check(app.card_reward == null and app.reward_buttons.is_empty(), "ACTIVE has no offering or controls")
	var trace: Array = [_state()]
	for turn in range(20):
		if turn > 0:
			var id := ""
			var position := 0
			for held in app.deck.hand:
				var definition := catalog.get_definition(held)
				if definition.get("target_kind") != "enemy_single":
					continue
				for target in [2, 1]:
					if target in definition.to_positions and app.enemies.get_enemy(target).hp > 0:
						id = held
						position = target
						break
				if not id.is_empty():
					break
			if not id.is_empty():
				if not await _choose(id, false):
					return []
				var rng := RandomNumberGenerator.new()
				rng.state = app.run_rng.state
				var payout := rng.randi_range(10, 20)
				await _key(KEY_1 if position == 1 else KEY_2)
				trace.append(_state())
				if app.battle_result.get_outcome() == CombatBattleResult.VICTORY:
					_check(app.session_gold == payout and app.run_rng.state == rng.state,
						"closure spends exactly the gold draw; fixed offering spends no RNG")
					break
		await _click(app.end_turn_button)
		trace.append(_state())
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY and app._battle_closed,
		"legal held-card play reaches closed victory")
	return trace


func _offering() -> bool:
	var ready: bool = app.card_reward != null and app.card_reward.is_valid() and app.reward_buttons.size() == 4
	_check(ready, "victory has a real valid transaction and four mounted actions")
	if not ready:
		return false
	var ids: Array = []
	for index in range(4):
		var button: Button = app.reward_buttons[index]
		_check(button.is_visible_in_tree() and not button.disabled and button.focus_mode == Control.FOCUS_ALL
			and button.get_global_rect().has_area() and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()),
			"reward action visible, focusable and fits viewport: %d" % index)
		_check(button.pressed.get_connections().size() == 1, "one handler per reward button")
		if index < 3:
			var offer: Dictionary = app.card_reward._offered_cards[index]
			var definition := catalog.get_definition(offer.id)
			_check(not definition.is_empty() and definition.owner == offer.owner
				and button.text == "%s - %s" % [offer.owner.capitalize(), definition.display_name],
				"real catalog ID and visible owner/card label")
			ids.append(offer.id)
		else:
			_check(button.text == "Skip", "Skip explicitly labelled")
	_check(ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "three distinct card IDs")
	_check(Rect2(0, 0, 1280, 720).encloses(app.return_button.get_global_rect()),
		"Return fits with rewards: " + str(app.return_button.get_global_rect()))
	return true


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	_check(app.title_view.is_visible_in_tree() and app.run_deck.is_empty() and app.card_reward == null,
		"mounted title has no reward state")
	var replay: Array = []
	var retained: Callable
	var previous_service: RunCardRewardChoice
	for session in range(3):
		seed(340034)
		var global_next := randi()
		seed(340034)
		var trace := await _win()
		if session == 0:
			replay = trace
		else:
			_check(trace.size() > 5 and trace == replay, "clean deterministic title-to-victory replay")
		if not _offering():
			break
		var before := _state()
		var inventory: Array = app.run_deck.duplicate()
		var service: RunCardRewardChoice = app.card_reward
		var first: Button = app.reward_buttons[0]
		if retained.is_valid():
			retained.call()
			_check(app.run_deck == inventory and not service.is_claimed() and _state() == before,
				"old offering callback cannot claim a fresh session")
		app._claim_card_reward("unknown", first, service)
		app._claim_card_reward("", first, service)
		_check(app.run_deck == inventory and not service.is_claimed() and _state() == before,
			"invalid ID and mismatched button reject without spending claim")
		retained = first.pressed.get_connections()[0].callable
		if session == 0:
			await _click(first)
			inventory.append(service._offered_cards[0].id)
		elif session == 1:
			# Traverse the actual terminal focus cycle from Return to Skip.
			app.return_button.grab_focus()
			for step in range(4):
				await _key(KEY_TAB)
			_check(app.reward_buttons[3].has_focus(), "keyboard reaches Skip from Return")
			await _key(KEY_ENTER)
		else:
			# Leave one offering unclaimed and exercise retained activation after Return.
			previous_service = service
		if session < 2:
			_check(service.is_claimed() and app.run_deck == inventory, "choice appends exactly one copy; Skip preserves exact inventory")
			for button in app.reward_buttons:
				_check(button.disabled, "valid choice or Skip disables every reward action")
				button.pressed.emit()
			retained.call()
			app._observe_battle_result()
			_check(app.card_reward == service and app.run_deck == inventory and _state() == before,
				"duplicate claims and repeated observation preserve inventory and complete terminal fight")
		var old_button: WeakRef = weakref(first)
		await _click(app.return_button)
		retained.call()
		_check(app.card_reward == null and app.reward_buttons.is_empty() and app.run_deck.is_empty()
			and app.deck == null and app.run_rng == null and old_button.get_ref() == null,
			"Return clears service, inventory and controls; post-return callback is inert")
		_check(randi() == global_next, "whole run and reward path preserve global RNG")
	_check(previous_service != null and not previous_service.is_claimed(), "post-return callback cannot consume even an unclaimed old offer")
	# A valid defeat has no reward entry, including when owners are downed.
	await _click(app.start_button)
	for position in [1, 2, 3]:
		_check(app.party.apply_damage(position, 999), "defeat fixture downs actual party hero")
	await _frames()
	_check(app.battle_result.get_outcome() == CombatBattleResult.DEFEAT and app.card_reward == null
		and app.reward_buttons.is_empty() and app.hand_view.get_child_count() == 0, "DEFEAT has no reward service or controls")
	await _click(app.return_button)
	# Downed owners remain legitimate members of a victorious party.
	await _click(app.start_button)
	_check(app.party.apply_damage(1, 999), "downed-owner victory has an actual downed hero")
	for position in [1, 2]:
		_check(app.enemies.apply_damage(position, 999), "downed-owner victory slays actual enemy")
	await _frames()
	if _offering():
		var inventory: Array = app.run_deck.duplicate()
		inventory.append("warden_strike")
		await _click(app.reward_buttons[0])
		_check(app.run_deck == inventory, "downed Warden's catalog card can be claimed")
	await _click(app.return_button)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_card_reward_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
