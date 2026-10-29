extends "res://tests/live_attack_preview_test.gd"

## Mounted, actual hand-panel Tether starter integrations. The attack following
## the link runs the real paid Warden Strike resolver, not a forged hit receipt.
const TETHERS := ["seamstress_v3_tether_loop", "seamstress_v3_tether_loop_plus"]


func _hold_tether(id: String) -> bool:
	if not await _start(_seed_for("warden_strike")):
		return false
	_check(app.enemies.get_enemies().size() >= 2 and app.party.get_hero(2).id == "seamstress"
		and app.deck.energy >= 2, "authentic living owner, enemy pair and energy")
	if app.enemies.get_enemies().size() < 2:
		return false
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has(id), "Tether copy truly drawn into shared hand")
	app._refresh_hand()
	await _frames()
	_check(_panel(id) != null and presenter._bindings.has(_panel(id)), "Tether bound to an actual held panel")
	return _panel(id) != null


func _arm_tether(panel: Control, keyboard: bool) -> void:
	if not keyboard:
		await _click(panel)
		return
	for i in range(app.deck.hand.size() + 2):
		if presenter._armed == panel:
			break
		await _key(KEY_P)
	_check(presenter._armed == panel, "keyboard P cycles to exact held Tether panel")


func _choose_foe(pos: int, keyboard: bool) -> void:
	if keyboard:
		await _key(KEY_1 + pos - 1)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[pos - 1])


func _success(id: String, keyboard: bool, blocked_primary: bool, reverse: bool = false) -> void:
	if not await _hold_tether(id):
		return
	var panel: Control = _panel(id)
	var primary_position: int = 2 if reverse else 1
	var partner_position: int = 1 if reverse else 2
	var definition := V3SeamstressStarterCards.new().get_definition(id)
	var tooltip: String = panel.tooltip_text
	_check(tooltip.contains(definition.display_name) and tooltip.contains("%d energy" % definition.cost)
		and tooltip.contains("two distinct living") and tooltip.contains("50%"),
		"authentic cost, TWO targets and echo semantics printed on real hand face")
	_check(app.get_node("LiveSupportHand")._metadata.short_line(id).contains("Link 2"), "drawn short rule tells two-target link")
	var before := _snapshot()
	var token: int = presenter._token
	var hand_before: Array = app.deck.hand.duplicate()
	await _arm_tether(panel, keyboard)
	var selected_token: int = presenter._token
	await _choose_foe(1, keyboard)
	_check(presenter._tether_positions == [1] and _snapshot() == before,
		"first mounted choice changes only target selection")
	await _choose_foe(2, keyboard)
	var expected := before.duplicate(true)
	expected[0].erase(id)
	expected[2].append(id)
	expected[3] -= int(definition.cost)
	_check(_snapshot() == expected, "pair alone pays exactly once, discards one and does zero damage/RNG")
	_check(presenter._tether_link.get("ok", false) and presenter._tether_link.first_position == 1
		and presenter._tether_link.second_position == 2 and presenter._tether_link.card_id == id,
		"authoritative helper admitted actual IDs and two original positions")
	_check(presenter._tether_positions.is_empty() and presenter._token != token,
		"committed callback retired, repeat input cannot pay again")
	var accepted := _snapshot()
	# A retired deferred callback cannot pay or install another link.
	presenter._commit_tether(panel, id, selected_token, [1, 2],
		[presenter._tether_link.first_id, presenter._tether_link.second_id],
		0, app.deck, hand_before, presenter._session.duplicate(),
		presenter._turn, app.run_map)
	_check(_snapshot() == accepted, "retired pair callback cannot repay or relink")
	await _key(KEY_1)
	_check(_snapshot() == accepted, "unarmed repeated target input is inert")
	var hit_panel: Control = _panel("warden_strike")
	_check(hit_panel != null and app.deck.energy >= 1, "next confirmed paid starter hit available")
	if hit_panel == null:
		await _return()
		return
	# A real secondary Block reserve must be absorbed before any echoed HP.
	_check(app.enemies.gain_block(partner_position, 2), "partner genuinely gains 2 Block")
	if blocked_primary:
		_check(app.enemies.gain_block(primary_position, 100), "primary genuinely fully blocked")
	app._refresh_enemy_roster()
	await _frames()
	var primary_before: Dictionary = app.enemies.get_enemy(primary_position)
	var partner_before: Dictionary = app.enemies.get_enemy(partner_position)
	await _click(hit_panel)
	await _click(app.get_node("LiveEnemyRoster")._labels[primary_position - 1])
	var actual: Dictionary = presenter.last_event
	_check(actual.get("ok", false) and actual.get("hits", []).size() > 0,
		"true paid Warden strike returns an actual hit receipt")
	var hp_loss: int = int(actual.get("hits", [{}])[0].get("hp_loss", 0))
	var echo_damage: int = hp_loss / 2
	var partner_after: Dictionary = app.enemies.get_enemy(partner_position)
	_check(app.enemies.get_enemy(primary_position).hp == primary_before.hp - hp_loss,
		"primary HP loss is actual paid attack damage, not a preview")
	_check(partner_after.block == maxi(0, partner_before.block - echo_damage)
		and partner_after.hp == partner_before.hp - maxi(0, echo_damage - partner_before.block),
		"exact floor-half echo consumes secondary Block before HP")
	_check((hp_loss == 0 and not actual.has("tether_echo")) or
		(hp_loss > 0 and actual.has("tether_echo") and actual.tether_echo.get("applied", false)),
		"fully blocked primary inert; positive HP loss uses confirmed echo")
	_check(app.deck.energy == 3 - definition.cost - 1
		and app.deck.discard_pile.count(id) == expected[2].count(id)
		and app.deck.hand.count(id) == hand_before.count(id) - 1,
		"one paid link and one subsequent paid hit, never second echo attack")
	await _return()
	_check(presenter._tether_link.is_empty(), "battle exit retires authoritative link")


func _refusal(mode: String) -> void:
	var id := TETHERS[0]
	if not await _hold_tether(id):
		return
	var panel: Control = _panel(id)
	if mode in ["admit_energy", "admit_seat", "admit_downed", "admit_targets"]:
		match mode:
			"admit_energy": app.deck.combat_state.energy = 1
			"admit_seat":
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
				_check(swap.ok, "valid real hero swap")
				app.party._heroes.assign(swap.heroes)
			"admit_downed": _check(app.party.apply_damage(2, 10000), "Seamstress really downed")
			"admit_targets": _check(app.enemies.apply_damage(2, 10000), "one enemy really slain")
		var before := _snapshot()
		await _click(panel)
		_check(_snapshot() == before and presenter._tether_link.is_empty(),
			"unpayable admission never arms or mutates: " + mode)
		await _return()
		return
	await _click(panel)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(presenter._tether_positions == [1], "first target picked before refusal: " + mode)
	if mode == "duplicate":
		var before := _snapshot()
		await _click(app.get_node("LiveEnemyRoster")._labels[0])
		_check(presenter._tether_positions == [1] and _snapshot() == before,
			"duplicate second target cannot admit or spend")
		await _key(KEY_ESCAPE)
		_check(presenter._tether_positions.is_empty() and _snapshot() == before,
			"escape cancels pending pair without mutation")
	elif mode == "cancel":
		var before := _snapshot()
		await _key(KEY_ESCAPE)
		await _click(app.get_node("LiveEnemyRoster")._labels[1])
		_check(presenter._tether_link.is_empty() and _snapshot() == before,
			"cancelled choice cannot be resumed by stale physical target")
	else:
		# Queue actual deferred commit and corrupt a genuine precondition BEFORE
		# the callback runs. Each refusal compares the same live objects.
		var stale: int = presenter._token
		presenter._choose_tether(2)
		match mode:
			"energy": app.deck.combat_state.energy = 1
			"owner": _check(app.party.apply_damage(2, 10000), "owner genuinely downed")
			"seat":
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
				_check(swap.ok, "legitimate position change")
				app.party._heroes.assign(swap.heroes)
			"dead": _check(app.enemies.apply_damage(2, 10000), "partner genuinely killed")
			"replace": app.enemies._enemies[1].id = "replacement"
			"hand": _check(app.deck.discard_played(id), "queued original held copy removed")
			"battle": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
			"turn": app.enemy_intents._turn_index += 1
			"panel": app._refresh_hand()
		var before := _snapshot()
		await _frames()
		_check(_snapshot() == before and presenter._tether_link.is_empty(),
			"stale pair refusal is fully atomic, including RNG: " + mode)
		await _key(KEY_ESCAPE)
		_check(presenter._token != stale, "stale selection token retired")
	await _return()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	for id in TETHERS:
		for keyboard in [false, true]:
			await _success(id, keyboard, false)
		await _success(id, false, true)
		await _success(id, false, false, true)
	for mode in ["duplicate", "cancel", "energy", "owner", "seat", "dead", "replace", "hand", "battle",
			"turn", "panel", "admit_energy", "admit_seat", "admit_downed", "admit_targets"]:
		await _refusal(mode)
	app.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_seamstress_tether_loop_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
