extends SceneTree
## Mounted drawn cards, real input and an independent neutral-status resolver oracle.

const IDS := ["tinker_v3_overload", "tinker_v3_overload_plus"]
const SEED := 13906
var app
var view
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _frames() -> void:
	await process_frame
	await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
	await _frames()


func _click(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "visible mouse recipient")
	if not is_instance_valid(control):
		return
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await _frames()


func _panel(id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label and panel.get_child(0).text == id:
			return panel
	return null


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.seed, app.run_rng.state,
		app.run_scraps, app.battle_result.get_outcome(), app._battle_closed,
		view._play._tinker._consumed, view._pinned._pinner_by_position.duplicate(true),
		app.enemy_intents.get_intents()]


func _begin(id: String, scrap: int = 3, seat: int = 3, copies: int = 1) -> bool:
	_check(app.deck == null, "title before genuine battle entry")
	app.run_seed = SEED
	var started: bool = app._start_battle()
	await _frames()
	var ready: bool = started and app.deck is CombatDeck and app.party is CombatParty \
		and app.enemies is CombatEnemies and app.enemy_intents != null \
		and app.battle_result != null and app.deck._rng == app.run_rng
	_check(ready, "mounted battle has real deck, actors, outcome and seeded RNG")
	if not ready:
		return false
	if seat == 2:
		var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
		_check(swap.get("ok", false), "legal adjacent swap to middle")
		app.party._heroes.assign(swap.heroes)
	_check(app.party.get_hero(seat).id == "tinker" and not app.party.is_downed(seat), "living actual Tinker seat")
	app.party._heroes[seat - 1]["combat_scrap"] = scrap
	app.party._heroes[0]["combat_scrap"] = 7
	_check(app.enemies.gain_block(1, 4), "real enemy Block established through model")
	for i in range(copies):
		app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(copies) == copies and app.deck.hand.count(id) == copies,
		"authentic printing genuinely drawn into shared hand")
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and view._bindings.has(panel), "actual hand binds Overload")
	if panel == null:
		return false
	_check(panel.gui_input.get_connections().size() == 1
		and not app.get_node("LiveSupportHand")._bindings.has(panel), "one input owner")
	return true


func _leave() -> void:
	await _click(app.return_button)
	_check(app.deck == null and view._bindings.is_empty() and view._overload_hud == null, "battle retires HUD and callbacks")


func _oracle(id: String, slot: int, before: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = before[7]
	rng.state = before[8]
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before[0])
	deck.hand.assign(before[1])
	deck.discard_pile.assign(before[2])
	deck.combat_state.energy = before[3]
	deck.combat_state.player_turn_active = before[4]
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign(before[5].duplicate(true))
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	enemies._enemies.assign(before[6].duplicate(true))
	var event := CombatTinkerV3OverloadCards.new().play_card(deck, party, enemies, id, slot)
	return {"event": event, "draw": deck.draw_pile, "hand": deck.hand, "discard": deck.discard_pile,
		"energy": deck.energy, "heroes": party.get_heroes(), "enemies": enemies.get_enemies(), "rng": rng.state}


func _positive(id: String, scrap: int, seat: int, keyboard: bool) -> Dictionary:
	if not await _begin(id, scrap, seat, 2):
		return {}
	var before := _state()
	if keyboard:
		for i in range(app.deck.hand.size() + 1):
			await _key(KEY_P)
			if view._armed == _panel(id):
				break
	else:
		await _click(_panel(id))
	_check(view._armed == _panel(id), "real mouse/P armed actual drawn printing")
	var forecast: Dictionary = view._target_preview(id)
	var expected := (3 + 4 * scrap) if id.ends_with("_plus") else (2 + 3 * scrap)
	var living: Array[int] = []
	for slot in range(1, app.enemies.get_enemies().size() + 1):
		if not app.enemies.is_slain(slot):
			living.append(slot)
	_check(not living.is_empty() and forecast.playable and forecast.target_positions == living,
		"only original living slots 1-3 offered")
	for hit in forecast.hits:
		_check(hit.damage == expected and hit.combat_scrap_spent == scrap, "exact printed Scrap arithmetic")
	_check(_state() == before, "forecast and selection mutate no piles, actors, wallet, RNG or latches")
	_check(view.current_forecast == forecast and view.cue.text.contains("1: %d damage" % expected)
		and view.cue.text.contains("Combat Scrap %d -> 0" % scrap), "authentic mounted damage and consumption forecast")
	_check(view.cue.is_visible_in_tree() and root.get_visible_rect().encloses(view.cue.get_global_rect()), "forecast within 1280x720")
	var oracle := _oracle(id, 1, before)
	_check(oracle.event.ok and oracle == _oracle(id, 1, before), "independent resolver same-seed deterministic replay")
	if keyboard:
		await _key(KEY_1)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(view.last_event == oracle.event, "live receipt equals independent resolver")
	_check(app.deck.draw_pile == oracle.draw and app.deck.hand == oracle.hand
		and app.deck.discard_pile == oracle.discard and app.deck.energy == oracle.energy,
		"all live piles and energy match oracle")
	_check(app.party.get_heroes() == oracle.heroes and app.enemies.get_enemies() == oracle.enemies,
		"complete live party and enemy snapshots match independent oracle")
	_check(app.deck.energy == before[3] - 1 and app.deck.hand.count(id) == 1
		and app.deck.discard_pile.count(id) == before[2].count(id) + 1, "one energy, one copy; duplicate remains")
	_check(view.last_event.hits.size() == 1 and view.last_event.block_absorbed == mini(4, expected)
		and view.last_event.hp_loss == mini(int(before[6][0].hp), maxi(0, expected - 4)), "exact single Block-absorbed hit")
	_check(app.party.get_hero(seat).combat_scrap == 0 and app.party.get_hero(1).combat_scrap == 7
		and app.run_scraps == before[9] and app.run_rng.state == before[8], "only Tinker's counter spent; wallet and RNG untouched")
	_check(view._play._tinker._consumed == before[12] and view._pinned._pinner_by_position == before[13], "no duplicate passive or Pinned benefit")
	_check(view._overload_hud.is_visible_in_tree()
		and view._overload_hud.text.contains("Tinker Combat Scrap: 0")
		and view._overload_hud.text.contains("spent %d Combat Scrap" % scrap)
		and root.get_visible_rect().encloses(view._overload_hud.get_global_rect()), "mounted resource HUD refreshes spent counter")
	_check(_panel(id) != null and view._bindings.has(_panel(id)), "remaining real copy rebound")
	var after := _state()
	await _key(KEY_1)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(_state() == after, "repeat input cannot play remaining duplicate without selection")
	var result: Dictionary = view.last_event.duplicate(true)
	await _leave()
	return result


func _rejections(id: String) -> void:
	for mode in ["seat", "downed", "missing", "energy", "absent", "negative", "float", "string",
		"killed", "replaced", "hand", "session", "turn", "deck", "map", "rng", "token", "closed"]:
		if not await _begin(id):
			return
		var panel := _panel(id)
		await _click(panel)
		_check(view._armed == panel, "rejection begins with actual armed panel: " + mode)
		var hand: Array = app.deck.hand.duplicate()
		var target: String = app.enemies.get_enemy(1).id
		var turn: int = view._turn
		var token: int = view._token
		var deck = app.deck
		var map = app.run_map
		match mode:
			"seat":
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
				app.party._heroes.assign(swap.heroes)
				swap = CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
				app.party._heroes.assign(swap.heroes)
				_check(app.party.get_hero(1).id == "tinker", "illegal front owner")
			"downed":
				_check(app.party.apply_damage(3, 10000) and app.party.is_downed(3), "downed owner")
			"missing":
				app.party._heroes[2].id = "absent_tinker"
			"energy":
				app.deck.combat_state.energy = 0
			"absent":
				_check(app.deck.discard_played(id) and not app.deck.hand.has(id), "card actually absent")
			"negative":
				app.party._heroes[2].combat_scrap = -1
			"float":
				app.party._heroes[2].combat_scrap = 3.0
			"string":
				app.party._heroes[2].combat_scrap = "3"
			"killed":
				_check(app.enemies.apply_damage(1, 10000) and app.enemies.is_slain(1), "queued target actually killed")
				_check(not view._target_preview(id).target_positions.has(1), "slain slot omitted")
			"replaced":
				app.enemies._enemies[0].id = "replacement"
			"hand":
				app.deck.hand.reverse()
			"session":
				view._session = []
			"turn":
				view._turn += 1
			"deck":
				deck = null
			"map":
				map = RefCounted.new()
			"rng":
				app.deck._rng = RandomNumberGenerator.new()
				app.deck._rng.seed = 8
			"token":
				token -= 1
			"closed":
				app._battle_closed = true
		var before := _state()
		var last: Dictionary = view.last_event.duplicate(true)
		view._queued = true
		view._commit(panel, id, 1, token, app.party, app.enemies, app.battle_result,
			app.run_rng, turn, target, panel.get_index(), deck, hand, map, view._pinned)
		_check(_state() == before and view.last_event == last, "queued refusal has no mutation: " + mode)
		# Drain the same stale callback again, before any frame can rebind a session.
		view._commit(panel, id, 1, token, app.party, app.enemies, app.battle_result,
			app.run_rng, turn, target, panel.get_index(), deck, hand, map, view._pinned)
		_check(_state() == before, "repeat stale input inert: " + mode)
		await _leave()


func _stale_and_retry() -> void:
	if not await _begin(IDS[0]):
		return
	var old := _panel(IDS[0])
	var captured: Callable = view._bindings[old].input
	app.hand_view.remove_child(old)
	app._refresh_hand()
	await _frames()
	_check(not view._bindings.has(old) and old.gui_input.get_connections().is_empty(), "obsolete panel disconnected")
	var before := _state()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	captured.call(event)
	await _key(KEY_1)
	_check(_state() == before, "captured removed-panel callback inert")
	old.free()
	app.deck.combat_state.energy = 0
	await _click(_panel(IDS[0]))
	before = _state()
	await _key(KEY_1)
	_check(_state() == before, "no-energy real input spends nothing")
	app.deck.combat_state.energy = 3
	await _click(_panel(IDS[0]))
	before = _state()
	var oracle := _oracle(IDS[0], 1, before)
	await _key(KEY_1)
	_check(view.last_event == oracle.event and app.deck.energy == 2, "valid deterministic retry after refusal")
	await _leave()


func _outcome() -> void:
	if not await _begin(IDS[1], 3):
		return
	for slot in range(2, app.enemies.get_enemies().size() + 1):
		_check(app.enemies.apply_damage(slot, 10000), "slay other original enemies")
	app.enemies._enemies[0].hp = 1
	_check(app.battle_result.can_continue() and not app.enemies.is_slain(1), "genuine final living target before hit")
	await _click(_panel(IDS[1]))
	await _key(KEY_1)
	_check(view.last_event.get("ok", false) and app.enemies.is_victorious()
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY and app._battle_closed,
		"real successful attack refresh publishes victory through existing outcome pipeline")
	await _leave()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "actual shipped scene")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	view = app.get_node_or_null("LiveAttackPreview")
	_check(view != null, "real presenter mounted")
	if view == null:
		app.free()
		_finish()
		return
	for id in IDS:
		for scrap in [0, 3]:
			for seat in [2, 3]:
				var first := await _positive(id, scrap, seat, seat == 2)
				var replay := await _positive(id, scrap, seat, seat == 2)
				_check(not first.is_empty() and first == replay, "same-seed mounted replay")
		await _rejections(id)
	await _stale_and_retry()
	await _outcome()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_tinker_v3_overload_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
