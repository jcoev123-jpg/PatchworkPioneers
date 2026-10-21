extends "res://tests/live_rest_route_entry_test.gd"
## Mounted input victories plus adversarial identity boundaries on the real session.

var entry: Dictionary = {}
var exercised_entry := false
var old_callbacks: Array[Callable] = []
var pointer_plays := 0
var key_plays := 0


func _choose(id: String, keyboard: bool) -> bool:
	# Refresh fixtures before real card selection, since turns clear Block/tick statuses.
	for position in [1, 2, 3]:
		if not app.party.is_downed(position):
			_check(app.party.gain_block(position, 100), "live held-card fixture has Block")
			app.party._heroes[position - 1]["statuses"] = {"weak": 2, "exposed": 2}
	if keyboard:
		key_plays += 1
	else:
		pointer_plays += 1
	return await super._choose(id, keyboard)


func _click(control: Control) -> void:
	await super._click(control)
	if app.party_carryover == null or exercised_entry:
		return
	exercised_entry = true
	entry = app.party_carryover.read_state()
	_check(entry.ok and entry.completed_fights.is_empty() and entry.completed_rests.is_empty(),
		"real Fight entry initializes a valid empty ledger")
	_check(entry.heroes == _block_free_party() and app.run_heroes.is_empty(),
		"ledger starts from actual party before any fixture mutation; no published victory")
	var before := _snapshot()
	_check(not app._commit_fight_carryover(), "active result cannot commit")
	app._observe_battle_result()
	for callback in old_callbacks:
		callback.call()
	_check(_snapshot() == before, "active observation and old callbacks spend and complete nothing")
	# Keep transient Block and statuses present at victory without altering balance data.
	for position in [1, 2, 3]:
		_check(app.party.gain_block(position, 100), "live party receives transient Block fixture")
		app.party._heroes[position - 1]["statuses"] = {"weak": 2, "exposed": 2}
	_check(app.party_carryover.read_state() == entry, "combat changes cannot mutate entry ledger")


func _snapshot() -> Array:
	return [_persistent(), app.party_carryover.read_state(), app.run_map.get_floors(),
		app.fight_reward_offers.duplicate(true), app.fight_reward_gold, app.fight_reward_claimed,
		app.encounter_id, app._battle_closed]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "legal seeded routed Fight fixture exists")
	if fixture.is_empty():
		await _finish_carryover()
		return
	var replay: Array = []
	var previous: RunPartyCarryover
	for session in range(2):
		exercised_entry = false
		if not await _routed_win(fixture, false):
			break
		var ledger: RunPartyCarryover = app.party_carryover
		_check(ledger != previous, "restart allocates a fresh ledger")
		var heroes := _block_free_party()
		_check(app.party.get_hero(3).block > 0 and not heroes[2].statuses.is_empty(),
			"victory fixture retains nonzero Block and statuses")
		_check(app.run_heroes == heroes and ledger.read_state().heroes == heroes,
			"exact HP, positions, statuses survive and only transient Block is cleared")
		_check(ledger.read_state().completed_fights == [fixture.fight]
			and ledger.read_state().completed_rests.is_empty(), "only actual committed Fight node latched")
		var before := _snapshot()
		for repeat in range(3):
			_check(not app._commit_fight_carryover(), "duplicate commit rejects")
			app._observe_battle_result()
			app._build_card_reward()
		_check(_snapshot() == before, "duplicate observation preserves map, deck, gold, RNG and encounter")
		if session == 0:
			replay = before.duplicate(true)
		else:
			_check(before == replay, "fresh same-seed input replay reproduces exact complete snapshot")
		var detached := ledger.read_state()
		detached.heroes[0].hp = 0
		detached.heroes[2].statuses.clear()
		app.run_heroes[0].hp = 0
		_check(ledger.read_state().heroes == heroes and app.party.get_hero(1).hp == heroes[0].hp,
			"ledger reads and published survivors are detached from ledger and combat")
		app.run_heroes = heroes.duplicate(true)
		old_callbacks = [app.reward_buttons[0].pressed.get_connections()[0].callable]
		await _click(app.reward_buttons[3])
		_check(app.fight_reward_claimed and is_instance_valid(app.continue_button), "Skip still exposes Continue")
		old_callbacks.append(app.continue_button.pressed.get_connections()[0].callable)
		previous = ledger
		var saved := ledger.read_state()
		await _click(app.return_button)
		for callback in old_callbacks:
			callback.call()
		_check(app.party_carryover == null and app.run_heroes.is_empty() and app.run_map == null
			and ledger.read_state() == saved, "Return disposes session ledger and stale callbacks are inert")
	_check(pointer_plays > 0 and key_plays > 0, "victories use both mouse and keyboard held-card input")
	await _identity_rejections(fixture)
	await _defeat(fixture)
	await _click(app.start_button)
	_check(app.deck != null and app.run_map == null and app.party_carryover == null
		and app.run_heroes.is_empty(), "direct Start is independent")
	await _click(app.return_button)
	await _finish_carryover()


func _enter(fixture: Dictionary) -> void:
	exercised_entry = true
	app.run_seed = fixture.seed
	await _click(app.route_button)
	for button in app.route_buttons:
		if button.get_meta("route_id") == fixture.fight:
			await _click(button)
			break
	_check(app.deck != null and app.party_carryover != null, "negative probe has real mounted Fight")


func _identity_rejections(fixture: Dictionary) -> void:
	await _enter(fixture)
	if app.deck == null:
		return
	# Witness a result synchronously, before the mounted observer can commit it.
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(enemy.position, 999)
	_check(app.battle_result.evaluate() == CombatBattleResult.VICTORY, "negative cases have evaluated real victory")
	var live_map: RunMap = app.run_map
	var live_party: CombatParty = app.party
	var live_result: CombatBattleResult = app.battle_result
	var replacement := RunMap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = fixture.seed
	replacement.generate(rng)
	_check(replacement.choose_node(fixture.fight), "wrong-map fixture has identical committed Fight")
	app.run_map = replacement
	_reject_unchanged("wrong map identity")
	app.run_map = live_map
	var prior: Array[String] = live_map.get_route()
	live_map._route.clear()
	_reject_unchanged("uncommitted node")
	live_map._route.assign(prior)
	var kind: String = live_map._nodes[fixture.fight].type
	live_map._nodes[fixture.fight].type = "Rest"
	_reject_unchanged("wrong node type")
	live_map._nodes[fixture.fight].type = kind
	app.party = CombatParty.new(app._load_party_definitions())
	_check(app.party.is_valid(), "wrong party is otherwise valid")
	_reject_unchanged("wrong party identity")
	app.party = live_party
	app.battle_result = CombatBattleResult.new(live_party, app.enemies)
	_reject_unchanged("wrong result identity")
	app.battle_result = live_result
	var before := _snapshot()
	_check(app._commit_fight_carryover(), "original witnessed session can commit after all rejections")
	var after := _snapshot()
	_check(after[0].slice(1) == before[0].slice(1) and after.slice(2) == before.slice(2),
		"handoff alone preserves complete combat, map, deck, gold, RNG, encounter and reward state")
	_check(app.run_heroes == _block_free_party()
		and app.party_carryover.read_state().completed_fights == [fixture.fight], "one restored commit publishes exact survivors")
	_check(not app._commit_fight_carryover() and _snapshot() == after, "unclosed duplicate cannot commit again")
	await _click(app.return_button)


func _reject_unchanged(label: String) -> void:
	var before := _snapshot()
	_check(not app._commit_fight_carryover(), label + " rejects commit")
	app._observe_battle_result()
	app._build_card_reward()
	_check(_snapshot() == before and app.party_carryover.read_state().completed_fights.is_empty()
		and app.run_heroes.is_empty() and app.fight_rewards == null, label + " preserves entire uncommitted run")


func _defeat(fixture: Dictionary) -> void:
	await _enter(fixture)
	if app.deck == null:
		return
	var ledger: RunPartyCarryover = app.party_carryover
	var initial := ledger.read_state()
	var owned: Array = app.run_deck.duplicate()
	var route: Array = app.run_map.get_route()
	for position in [1, 2, 3]:
		var hero: Dictionary = app.party.get_hero(position)
		_check(app.party.apply_damage(position, hero.hp + hero.block - 1), "defeat fixture leaves each real hero living at one HP")
	for turn in range(12):
		if app._battle_closed:
			break
		await _click(app.end_turn_button)
	_check(app.battle_result.get_outcome() == CombatBattleResult.DEFEAT and app._battle_closed,
		"mounted End Turn inputs reach an actual defeat")
	var panel: LiveRunTerminalResultPanel = app.terminal_result_panel
	_check(panel != null and panel.has_open_result() and panel.is_visible_in_tree()
		and panel.title_label.text == "Defeat"
		and panel.description_label.text == "The party has fallen. The run has ended."
		and app.act_outcome.get_state().run_status == RunActBattleOutcome.DEFEAT
		and app.act_outcome.get_state().pending_node_id == ""
		and app.act_outcome.get_state().settled_node_ids == route,
		"enemy-phase routed wipe settles and mounts genuine Defeat screen")
	_check(panel != null and panel.return_button.has_focus()
		and app.return_button.disabled and app.end_turn_button.disabled,
		"terminal panel owns focus and old battle actions are closed")
	var before := _snapshot()
	_check(not app._commit_fight_carryover(), "defeat cannot commit")
	app._observe_battle_result()
	for callback in old_callbacks:
		callback.call()
	_check(_snapshot() == before and ledger.read_state() == initial and app.run_heroes.is_empty()
		and app.run_deck == owned and app.run_map.get_route() == route and app.session_gold == 0
		and app.fight_rewards == null and app.reward_buttons.is_empty(), "defeat and stale callbacks never publish, pay or complete")
	if panel != null:
		app.return_button.pressed.emit()
		app._mount_terminal_result()
		_check(app.terminal_result_panel == panel and panel.get_parent() == app
			and app.get_children().count(panel) == 1 and _snapshot() == before,
			"stale battle Return and repeat mount cannot bypass or duplicate Defeat")
		await _click(panel.return_button)
		_check(app.terminal_result_panel == null and app.act_outcome == null
			and app.title_view.is_visible_in_tree(), "genuine Defeat panel Return tears down session")


func _finish_carryover() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_fight_carryover_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
