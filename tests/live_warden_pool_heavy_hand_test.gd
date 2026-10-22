extends SceneTree
## Mounted D2-1 Warden heavy attacks: real panels, player input and pure oracle.

const IDS := ["warden_heavy_thimble", "warden_heavy_thimble_plus",
	"warden_pin_and_pound", "warden_pin_and_pound_plus"]
const SEED := 42

var failures: Array[String] = []
var checks := 0
var app
var presenter


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	await process_frame
	await process_frame
	await process_frame


func _keyboard(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _click(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "real click target on screen")
	if not is_instance_valid(control):
		return
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _panel(id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() and panel.get_child(0) is Label and panel.get_child(0).text == id:
			return panel
	return null


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.deck.combat_state.energy, app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.battle_result.get_outcome(), app.deck._rng.seed, app.deck._rng.state]


func _oracle(id: String, position: int, snapshot: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(snapshot[11])
	rng.state = int(snapshot[12])
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(snapshot[0])
	deck.hand.assign(snapshot[1])
	deck.discard_pile.assign(snapshot[2])
	deck.combat_state.player_turn_active = bool(snapshot[4])
	deck.combat_state.energy = int(snapshot[5])
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((snapshot[6] as Array).duplicate(true))
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	enemies._enemies.assign((snapshot[7] as Array).duplicate(true))
	var event: Dictionary = CombatWardenPoolHeavyAttacks.new().play_attack(deck, party, enemies, id, position)
	return {"event": event, "draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"seed": rng.seed, "rng": rng.state}


func _start(id: String) -> bool:
	_check(app.deck == null, "start from real title")
	app.run_seed = SEED
	_check(app._start_battle(), "seeded scene battle starts")
	await _frames()
	var ready: bool = app.deck != null and app.deck.turn_active and app.party != null \
		and app.enemies != null and app.battle_result != null and app.run_rng != null \
		and app.enemy_intents != null and is_instance_valid(app.hand_view)
	_check(ready, "all real mounted combat models present")
	if not ready:
		return false
	# Earned catalog card flows through the real shared deck draw and hand build.
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == id,
		"real shared deck draws an actual held heavy card " + id)
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and presenter._bindings.has(panel) and presenter._eligible(panel),
		"held heavy instance bound to live presenter " + id)
	_check(not app.get_node("LiveSupportHand")._bindings.has(panel),
		"heavy attack has no duplicate support handler " + id)
	return panel != null


func _return() -> void:
	if app.deck != null:
		await _click(app.return_button)
	_check(app.deck == null and presenter.cue == null and presenter._bindings.is_empty(),
		"real Return closes and unbinds heavy targeting")


func _key_select(id: String) -> bool:
	for index in range(app.deck.hand.size() + 1):
		await _keyboard(KEY_P)
		if presenter._armed == _panel(id):
			return true
	return false


func _third_enemy() -> void:
	var definitions: Array = app._load_enemy_definitions()
	definitions.append({"id": "heavy_third", "name": "Third Ragling", "max_hp": 25,
		"art_path": String(definitions[0].art_path)})
	app.enemies = CombatEnemies.new(definitions)
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	_check(app.enemies.is_valid() and app.enemies.get_enemies().size() == 3
		and not app.enemies.is_slain(3), "third target actually living in mounted roster")
	app._refresh_enemy_roster()
	presenter._sync_battle()


func _play(id: String, keyboard: bool, position: int, special: String = "") -> void:
	if not await _start(id):
		return
	var definition := WardenPoolCards.new().get_definition(id)
	_check(definition.id == id and definition.owner == "warden"
		and definition.cost == 2 and definition.from_positions == [1]
		and definition.target_kind == "enemy_single", "real heavy catalog identity and cost " + id)
	if position == 3:
		_third_enemy()
	if special == "status":
		app.party._heroes[0]["statuses"] = {"weak": 1}
		_check(app.enemies.apply_statuses({position: {"exposed": 1}})
			and app.enemies.gain_block(position, 6), "real Weak/Exposed and enemy Block")
	elif special == "lethal":
		var hp: int = int(app.enemies.get_enemy(position).hp)
		_check(hp > 4 and app.enemies.apply_damage(position, hp - 4)
			and not app.enemies.is_slain(position), "target has four HP before two-hit lethal")
	await _frames()
	var panel := _panel(id)
	if keyboard:
		_check(await _key_select(id), "P cycles to physical held card " + id)
	else:
		await _click(panel)
	_check(presenter._armed == panel and presenter._eligible(panel), "real card armed " + id)
	var before := _state()
	var legal: Array = []
	for enemy in app.enemies.get_enemies():
		if not app.enemies.is_slain(int(enemy.position)) and definition.to_positions.has(enemy.position):
			legal.append(int(enemy.position))
	var preview: Dictionary = presenter._targeting.get_preview(app.deck, app.party, app.enemies, id)
	_check(preview.playable and preview.requires_selection and preview.target_positions == legal,
		"only authored living enemy positions offered " + id)
	_check(not CombatAttackTargeting.ATTACK_IDS.has(id)
		and not presenter._targeting.is_pool_strike(id)
		and presenter._targeting.is_heavy_pool_attack(id), "heavy category stays isolated " + id)
	var per_hit: int = CombatStatuses.new().adjusted_attack_damage(
		int(definition.effects.damage), app.party.get_hero(1).get("statuses", {}),
		app.enemies.get_enemy(position).get("statuses", {}))
	var count: int = int(definition.effects.get("hits", 1))
	_check(presenter.cue.text.contains(definition.display_name + " | 2 energy")
		and presenter.cue.text.contains("%d: " % position)
		and presenter.cue.text.contains(
			"2 hits x %d damage each" % per_hit if count == 2 else "%d damage" % per_hit),
		"cue has catalog name cost exact per-hit damage and multiplicity " + id)
	_check(presenter.cue.is_visible_in_tree()
		and presenter.cue.get_line_count() <= 2, "1280x720 cue stays on two lines " + id)
	_check(_state() == before, "preview does not mutate Block/HP/hand/RNG " + id)
	var oracle := _oracle(id, position, before)
	_check(oracle.event.ok, "independent detached heavy resolver accepts " + id)
	if keyboard:
		await _keyboard(KEY_1 + position - 1)
	else:
		var labels: Array = app.get_node("LiveEnemyRoster")._labels
		_check(labels.size() >= position, "mouse target label exists " + id)
		if labels.size() >= position:
			await _click(labels[position - 1])
	_check(presenter.last_event == oracle.event, "live hit events match independent resolver " + id)
	_check(app.deck.hand == oracle.hand and app.deck.draw_pile == oracle.draw
		and app.deck.discard_pile == oracle.discard and app.deck.energy == oracle.energy,
		"live piles and energy equal detached oracle " + id)
	_check(app.party.get_heroes() == oracle.heroes and app.enemies.get_enemies() == oracle.enemies,
		"complete mounted HP Block and statuses equal detached oracle " + id)
	_check(app.deck._rng.seed == oracle.seed and app.deck._rng.state == oracle.rng
		and app.deck._rng == app.run_rng and app.deck._rng.state == int(before[12]),
		"real injected RNG untouched by live heavy play " + id)
	_check(app.deck.energy == int(before[3]) - 2
		and app.deck.discard_pile.count(id) == int(before[2].count(id)) + 1
		and app.deck.hand.count(id) == int(before[1].count(id)) - 1,
		"exactly one 2-energy charge and one discard " + id)
	_check(presenter.last_event.hits.size() == (1 if special == "lethal" else count),
		"correct sequential hit count / lethal truncation " + id)
	var after := _state()
	await _keyboard(KEY_1 + position - 1)
	_check(_state() == after, "consumed heavy card cannot double spend " + id)
	await _return()


func _negative(id: String, scenario: String) -> void:
	if not await _start(id):
		return
	var panel := _panel(id)
	# Arm first to also test commit-time invalidation of a real pending choice.
	await _click(panel)
	_check(presenter._armed == panel, "negative starts with armed held card " + scenario)
	match scenario:
		"zero", "one":
			app.deck.combat_state.energy = 0 if scenario == "zero" else 1
			_check(app.deck.energy < 2, "unaffordable hand state " + scenario)
		"downed":
			_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1),
				"real Warden downed")
		"moved":
			var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
			_check(proposal.ok, "real adjacent owner move legal")
			if proposal.ok:
				app.party._heroes.assign(proposal.heroes)
			_check(app.party.get_hero(2).id == "warden", "Warden genuinely no longer front")
		"dead":
			_check(app.enemies.apply_damage(2, 10000) and app.enemies.is_slain(2),
				"chosen slot genuinely slain")
		"absent":
			_check(app.deck.discard_played(id) and not app.deck.hand.has(id), "held card actually absent")
		"cancel":
			await _keyboard(KEY_ESCAPE)
			_check(presenter._armed == null, "Esc actually disarmed card")
		"rebuild":
			var obsolete := panel
			app._refresh_hand()
			await _frames()
			_check(not presenter._bindings.has(obsolete), "obsolete panel disconnected after rebuild")
		"turn":
			app.deck.combat_state.player_turn_active = false
			_check(not app.deck.turn_active, "turn truly expired")
	await _frames()
	var before := _state()
	var target := 2
	var current: Control = _panel(id)
	var shown: Dictionary = presenter._targeting.get_preview(app.deck, app.party, app.enemies, id)
	if scenario in ["zero", "one", "downed", "moved", "absent", "turn"]:
		_check(not shown.playable, "invalid heavy preview rejects " + scenario)
	elif scenario == "dead":
		_check(shown.playable and 2 not in shown.target_positions,
			"slain slot omitted but other target remains alive")
	await _keyboard(KEY_2)
	_check(_state() == before, "keyboard rejected without mutation " + scenario)
	if scenario != "rebuild":
		var labels: Array = app.get_node("LiveEnemyRoster")._labels
		if labels.size() >= target:
			await _click(labels[target - 1])
		_check(_state() == before, "pointer rejected without mutation " + scenario)
	elif current != null:
		_check(current != panel, "rebuilt instance differs from stale panel")
	await _return()


func _illegal_thimble_slot() -> void:
	if not await _start("warden_heavy_thimble"):
		return
	_third_enemy()
	await _frames()
	await _click(_panel("warden_heavy_thimble"))
	var preview: Dictionary = presenter._targeting.get_preview(
		app.deck, app.party, app.enemies, "warden_heavy_thimble")
	_check(preview.target_positions == [1, 2] and app.enemies.get_enemy(3).hp > 0,
		"living third enemy remains outside Heavy Thimble's authored TO slots")
	var before := _state()
	await _keyboard(KEY_3)
	_check(_state() == before, "out-of-range keyboard slot three never charges")
	var labels: Array = app.get_node("LiveEnemyRoster")._labels
	_check(labels.size() == 3, "live roster contains third pointer target")
	if labels.size() == 3:
		await _click(labels[2])
	_check(_state() == before, "out-of-range pointer slot three never charges")
	await _keyboard(KEY_ESCAPE)
	var cancelled := _state()
	await _keyboard(KEY_1)
	_check(_state() == cancelled, "cancelled Heavy Thimble cannot commit")
	await _return()


func _stale_commit() -> void:
	if not await _start("warden_pin_and_pound"):
		return
	var panel := _panel("warden_pin_and_pound")
	await _click(panel)
	var before := _state()
	var last: Dictionary = presenter.last_event.duplicate(true)
	for issue in ["turn", "session", "panel"]:
		presenter._armed = panel
		presenter._queued = true
		var original_session: Array = presenter._session.duplicate()
		if issue == "session":
			presenter._session = []
		if issue == "panel":
			presenter._token += 1
		presenter._commit(panel, "warden_pin_and_pound", 1,
			presenter._token - (1 if issue == "panel" else 0),
			app.party, app.enemies, app.battle_result, app.run_rng,
			presenter._turn + (1 if issue == "turn" else 0))
		_check(_state() == before and presenter.last_event == last,
			"stale " + issue + " callback never charges or publishes")
		presenter._session = original_session
		presenter._queued = false
	await _keyboard(KEY_ESCAPE)
	var cancelled := _state()
	await _keyboard(KEY_1)
	_check(_state() == cancelled, "cancelled selection remains inert")
	await _return()
	var retired = presenter.last_event.duplicate(true)
	await _keyboard(KEY_1)
	_check(app.deck == null and presenter.last_event == retired,
		"closed battle rejects keyboard attacks")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene exists")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	_check(presenter != null and app.deck == null, "presenter mounted on title screen")
	if presenter == null:
		app.free()
		_finish()
		return
	await _play(IDS[0], false, 2)
	await _play(IDS[1], true, 1, "status")
	await _play(IDS[2], false, 3)
	await _play(IDS[3], true, 2, "lethal")
	for scenario in ["zero", "one", "downed", "moved", "dead", "absent", "cancel", "rebuild", "turn"]:
		await _negative("warden_pin_and_pound", scenario)
	await _illegal_thimble_slot()
	await _stale_commit()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_warden_pool_heavy_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
