extends SceneTree
## Selected-three route Fight -> genuine held-card pointer/keyboard actions.
const IDS := ["tinker_v3_cog_shot", "tinker_v3_cog_shot_plus",
	"tinker_v3_scrap_bomb", "tinker_v3_scrap_bomb_plus"]
var app
var view
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _frames() -> void:
	await process_frame
	await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = down
		root.push_input(e, true)
	await _frames()


func _click(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "visible physical input recipient")
	if not is_instance_valid(control):
		return
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at
		e.pressed = down
		e.button_index = MOUSE_BUTTON_LEFT
		root.push_input(e, true)
	await _frames()


func _panel(id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == id:
			return panel
	return null


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.party._heroes.duplicate(true),
		app.enemies._enemies.duplicate(true), app.run_scraps, app.run_rng.seed,
		app.run_rng.state, view._play._tinker._consumed, view._play._tinker._path_bonus,
		app.battle_result.get_outcome(), app.enemy_intents.get_intents(),
		app.deck.exhausted.duplicate(), app.deck.turn_active,
		view._pinned._pinner_by_position.duplicate(true)]


func _begin(id: String, tinker: bool = true) -> bool:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 13906
	await _click(app.start_button)
	var picks := ["warden", "seamstress", "tinker"] if tinker else ["warden", "seamstress", "lantern_monk"]
	preload("res://tests/party_choice.gd").choose(app, picks)
	await _frames()
	_check(app._party_receipt == RunV3PartyAdmission.admit(picks) and app.run_map != null,
		"real selected-three admission precedes Fight")
	var fight: Button = null
	for button in app.route_buttons:
		if not button.disabled and button.get_meta("route_kind", "") == "Fight":
			fight = button
			break
	_check(fight != null, "seed exposes genuine opening Fight")
	if fight == null:
		return false
	await _click(fight)
	view = app.get_node("LiveAttackPreview")
	var ready: bool = app.deck != null and app.party != null and app.enemies != null
	_check(ready, "routed Fight mounts real combat objects")
	if not ready:
		return false
	_check(app.deck._rng == app.run_rng and app.party.is_valid() and app.enemies.is_valid(), "real shared seeded RNG and valid actors")
	for i in range(2):
		app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(2) == 2, "two actual held copies drawn")
	app._refresh_hand()
	await _frames()
	_check(_panel(id) != null, "authentic printing has real hand panel")
	return _panel(id) != null


func _leave() -> void:
	app.free()
	await _frames()


func _arm(id: String, keyboard: bool) -> void:
	if keyboard:
		for i in range(app.deck.hand.size() + 1):
			await _key(KEY_P)
			if view._armed == _panel(id):
				break
	else:
		# Press only: releasing an area card commits target-free attacks.
		var panel := _panel(id)
		var at := panel.get_global_rect().get_center()
		var e := InputEventMouseButton.new()
		e.position = at
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		root.push_input(e, true)
		await _frames()
	_check(view._armed == _panel(id), "physical input arms held instance")


func _positive(id: String, keyboard: bool, hooks: bool = false, gap: bool = false, seat: int = 3) -> Dictionary:
	if not await _begin(id):
		return {}
	var area: bool = id.contains("scrap_bomb")
	var target := 0 if area else 1
	_check(app.party.get_hero(3).id == "tinker" and app.enemies.get_enemies().size() >= 2,
		"living admitted Tinker and multiple original enemy slots")
	if seat == 2:
		var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
		_check(swap.ok, "actual legal middle-seat swap")
		app.party._heroes.assign(swap.heroes)
		_check(app.party.get_hero(2).id == "tinker", "Tinker occupies actual middle seat")
	for enemy in app.enemies._enemies:
		enemy.max_hp = 90
		enemy.hp = 90
		enemy.block = 2
	if gap:
		app.enemies.apply_damage(1, 10000)
		target = 0 if area else 2
	if hooks:
		app.party._heroes[seat - 1].statuses = {"weak": 1}
		for enemy in app.enemies._enemies:
			enemy.statuses = {"exposed": 1}
			enemy.thorns = 2
			enemy.enrage = true
	else:
		# Isolate canonical printed resolver comparison; hook case separately
		# proves the established first attack/status/retaliation path remains live.
		view._play._tinker._consumed = true
	app.party._heroes[seat - 1].combat_scrap = 4
	app.party._heroes[0].combat_scrap = 8
	var before := _state()
	var rng := RandomNumberGenerator.new()
	rng.seed = before[7]
	rng.state = before[8]
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before[0])
	deck.hand.assign(before[1])
	deck.discard_pile.assign(before[2])
	deck.combat_state.start_player_turn()
	deck.combat_state.energy = before[3]
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign(before[4].duplicate(true))
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	enemies._enemies.assign(before[5].duplicate(true))
	var oracle := CombatTinkerV3StarterAttackCards.new().play_card(deck, party, enemies, id, target)
	_check(oracle.ok and not oracle.hits.is_empty(), "authenticated isolated oracle genuinely applies")
	var preview: Dictionary = view._target_preview(id)
	var living: Array = []
	for enemy in before[5]:
		if enemy.hp > 0:
			living.append(enemy.position)
	_check(preview.playable and preview.requires_selection == not area and preview.target_positions == living,
		"only printed living original slots preview")
	await _arm(id, keyboard)
	_check(_state() == before, "arming/forecast never mutates combat or RNG")
	if area:
		if keyboard:
			await _key(KEY_ENTER)
		else:
			var e := InputEventMouseButton.new()
			e.position = _panel(id).get_global_rect().get_center()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = false
			root.push_input(e, true)
			await _frames()
	elif keyboard:
		await _key(KEY_1 + target - 1)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[target - 1])
	var paid: Dictionary = view.last_event.duplicate(true)
	_check(paid.get("ok", false) and paid.get("card_id") == id, "real shared-hand commit succeeds " + id)
	if not paid.get("ok", false):
		await _leave()
		return {}
	_check(app.deck.draw_pile == deck.draw_pile and app.deck.hand == deck.hand
		and app.deck.discard_pile == deck.discard_pile and app.deck.energy == deck.energy,
		"exact one-copy payment/piles match accepted resolver")
	_check(app.deck.hand.count(id) == 1 and app.deck.energy == before[3] - V3TinkerStarterCards.new().get_definition(id).cost,
		"one held copy and printed energy")
	_check(app.party.get_hero(seat).combat_scrap == 5 and app.party.get_hero(1).combat_scrap == 8
		and app.run_scraps == before[6] and app.run_rng.state == before[8], "one Tinker combat scrap; wallet and RNG unchanged")
	var normalized := paid.duplicate(true)
	for hit in normalized.hits:
		hit.erase("damage")
		hit.erase("statuses")
	if not hooks:
		_check(normalized == oracle and app.party.get_heroes() == party.get_heroes()
			and app.enemies.get_enemies() == enemies.get_enemies(), "exact canonical receipt and HP/Block/rosters match isolated resolver")
	else:
		var expected_positions: Array = living if area else [target]
		_check(paid.hits.size() == expected_positions.size(), "one live hit per actual recipient")
		for i in range(paid.hits.size()):
			var hit: Dictionary = paid.hits[i]
			var pos: int = expected_positions[i]
			var damage := CombatStatuses.new().adjusted_attack_damage(oracle.raw_damage + 3, {"weak": 1}, {"exposed": 1})
			_check(hit.position == pos and hit.damage == damage and hit.block_absorbed == 2
				and hit.hp_loss == damage - 2 and app.enemies.get_enemy(pos).enrage_stacks == 1,
				"live passive/status arithmetic, Block, HP and Enrage per original hit")
		_check(app.party.get_hero(seat).hp == before[4][seat - 1].hp - 2 * paid.hits.size()
			and view._play._tinker._consumed, "Thorns retaliates per hit and shared first-hit latch consumed")
	var after := _state()
	await _key(KEY_1)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(_state() == after, "replayed target input cannot pay remaining duplicate")
	await _leave()
	return paid


func _stale_and_forged() -> void:
	if not await _begin(IDS[0]):
		return
	await _arm(IDS[0], true)
	var old := _panel(IDS[0])
	var callback: Callable = view._bindings[old].input
	app.hand_view.remove_child(old)
	app._refresh_hand()
	await _frames()
	_check(not view._bindings.has(old) and old.gui_input.get_connections().is_empty(), "stale mounted panel is unbound")
	var before := _state()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	callback.call(e)
	await _key(KEY_1)
	_check(_state() == before, "captured stale panel callback and target input inert")
	old.free()
	for forged in ["tinker_v3_cog_shot_forged", "tinker_v3_scrap_bomb_plus_plus", "tinker_v3_cog_shot+"]:
		app.deck.draw_pile.append(forged)
		_check(app.deck.draw_extra(1) == 1, "unsupported card actually held")
		app._refresh_hand()
		await _frames()
		var panel := _panel(forged)
		_check(panel != null and not view._targeting.supports(forged) and not view._bindings.has(panel), "forged/unsupported printing never attack-bound")
		before = _state()
		await _click(panel)
		await _key(KEY_1)
		_check(_state() == before, "forged/unsupported input has no payment or battle mutation " + forged)
	await _leave()


func _negative(id: String, mode: String) -> void:
	if not await _begin(id, mode != "missing"):
		return
	await _arm(id, true)
	var panel := _panel(id)
	var hand: Array = app.deck.hand.duplicate()
	var token: int = view._token
	var turn: int = view._turn
	var original: String = app.enemies.get_enemy(1).id
	var target := 0 if id.contains("scrap_bomb") else 1
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"owner": app.party.apply_damage(3, 10000)
		"enemy":
			for enemy in app.enemies._enemies:
				enemy.hp = 0
		"seat":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
			app.party._heroes.assign(swap.heroes)
			swap = CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
			app.party._heroes.assign(swap.heroes)
			_check(app.party.get_hero(1).id == "tinker", "real illegal front seat")
		"unheld": app.deck.discard_played(id)
		"token": token -= 1
		"hand": app.deck.hand.reverse()
		"turn": turn -= 1
		"replaced":
			app.enemies._enemies[0].id = "replacement"
			# Target-free Bomb has no selected enemy identity to become stale.
			target = 1
		"overflow": app.party._heroes[2].combat_scrap = CombatParty.MAX_INT
	var before := _state()
	var last: Dictionary = view.last_event.duplicate(true)
	view._queued = true
	view._commit(panel, id, target, token, app.party, app.enemies, app.battle_result,
		app.run_rng, turn, original, panel.get_index(), app.deck, hand, app.run_map, view._pinned)
	_check(_state() == before and view.last_event == last, id + " atomic refusal " + mode)
	await _leave()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _stale_and_forged()
	for id in IDS:
		var mouse := await _positive(id, false)
		var keyboard := await _positive(id, true)
		_check(not mouse.is_empty() and mouse == keyboard, "seeded mouse/keyboard replay exact " + id)
		await _positive(id, true, true)
		await _positive(id, true, false, true, 2 if id.contains("cog_shot") else 3)
		for mode in ["missing", "seat", "owner", "enemy", "energy", "unheld", "token", "hand", "turn", "replaced", "overflow"]:
			await _negative(id, mode)
	for failure in failures:
		printerr(failure)
	print("live_tinker_v3_starter_attacks_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
