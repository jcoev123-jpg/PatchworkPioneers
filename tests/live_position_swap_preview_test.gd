extends SceneTree

## The read-only adjacent-swap service survives without any debug Preview control in the
## real battle: proposals are deterministic, detached, free, and reject invalid rosters,
## while the real paid movement card still spends energy and reorders living actors.

var failures: Array[String] = []
var checks := 0
var app


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _click(control: Control) -> void:
	var rect := control.get_global_rect()
	_check(root.get_visible_rect().encloses(rect), "whole clickable control inside 1280x720: " + control.name)
	var motion := InputEventMouseMotion.new()
	motion.position = rect.get_center()
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = rect.get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _snapshot() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.party.get_heroes() if app.party != null else null,
		app.enemies.get_enemies(), app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index, app.run_rng.seed, app.run_rng.state,
		app.battle_result.get_outcome(), app.session_gold, app._battle_closed]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	_check(app.start_button.has_focus() and app.deck == null, "real title is initial entry")
	var replay: Array = []
	var stale: Callable
	# Initial battle plus two same-seed title restarts.
	for session in range(3):
		_fixture_start(app)
		await _frames()
		_check(app.deck != null and app.party != null and app.enemies != null
			and app.deck.turn_active and app.battle_result.can_continue(),
			"title creates a real active seeded battle")
		if app.deck == null or app.party == null:
			app.free()
			_finish()
			return
		if stale.is_valid():
			var before_stale := _snapshot()
			stale.call()
			_check(_snapshot() == before_stale and app.deck != null,
				"old Return callback rejected after restart")
		stale = app.return_button.pressed.get_connections()[0].callable
		_no_debug_controls()
		_action_corner()
		await _tab_loop()
		var trace: Array = [_snapshot()]
		trace.append(await _service_cases())
		await _paid_move_case()
		trace.append(_snapshot())
		await _end_turn_case()
		trace.append(_snapshot())
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "same-seed restart replays every proposal, paid move and End Turn exactly")
		# The terminal roster changes nothing for a detached proposal, even before observation.
		if session == 2:
			for position in [1, 2, 3]:
				if not app.party.is_downed(position):
					_check(app.party.apply_damage(position, 10000), "complete real defeat")
		else:
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 10000), "complete real victory")
		var terminal := _snapshot()
		var terminal_proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
		var terminal_unchanged: bool = _snapshot() == terminal
		_check(terminal_unchanged and (terminal_proposal.get("ok") == false if session == 2
			else terminal_proposal.get("ok") == true),
			"unobserved terminal proposal is read-only and cannot spend or move")
		await _frames()
		_check(app._battle_closed and app.battle_result.is_finished() and not app.deck.turn_active
			and app.return_button.has_focus(), "actual combat closure preserves focused Return")
		var view_id: int = app.battle_view.get_instance_id()
		await _key(KEY_ENTER)
		_check(app.deck == null and app.battle_view == null and not is_instance_id_valid(view_id),
			"keyboard Return frees the battle view")
		_check(app.start_button.has_focus() and app.title_view.is_visible_in_tree(), "Return restores title focus")
		stale.call()
		_check(app.deck == null and app.title_view.is_visible_in_tree(), "closed stale Return callback inert")
	app.free()
	_finish()


## No Preview swap button and no Preview-only cue may exist in the real mounted battle.
func _no_debug_controls() -> void:
	var preview_buttons: Array = []
	for button in app.find_children("*", "Button", true, false):
		if String(button.text).to_lower().contains("preview"):
			preview_buttons.append(button)
	_check(preview_buttons.is_empty(), "no Preview swap button is mounted in a real battle")
	var preview_cues: Array = []
	for label in app.find_children("*", "Label", true, false):
		var text := String(label.text)
		if text.contains("Preview only") or text.contains("Swap preview"):
			preview_cues.append(label)
	_check(preview_cues.is_empty(), "no Preview-only cue is mounted in a real battle")
	_check(app.hand_view.get_child_count() == app.deck.hand.size(), "every real held card still mounts")
	_check(app.pile_label.is_visible_in_tree(), "pile counts stay mounted without the debug row")


## End Turn stays prominent; Return and Fast form one compact sewn corner.
func _action_corner() -> void:
	var juice = app.get_node_or_null("LiveCombatJuice")
	_check(is_instance_valid(app.action_corner) and app.action_corner.name == "BattleActionCorner"
		and is_instance_valid(app.action_corner_row), "secondary actions mount in one named sewn corner")
	_check(is_instance_valid(app.end_turn_button) and not app.action_corner.is_ancestor_of(app.end_turn_button),
		"End Turn stays the prominent action outside the compact corner")
	_check(app.action_corner.is_ancestor_of(app.return_button), "Return sits inside the compact corner")
	_check(juice != null and is_instance_valid(juice.fast_button)
		and app.action_corner_row.is_ancestor_of(juice.fast_button),
		"the real Fast button sits in the same compact corner")
	_check(app.action_corner.has_theme_stylebox_override("panel"),
		"the corner is a sewn felt patch")
	var stitches: Array = app.action_corner.find_children("BattleActionCornerStitch", "Control", true, false)
	_check(stitches.size() == 1 and stitches[0].mouse_filter == Control.MOUSE_FILTER_IGNORE
		and stitches[0].focus_mode == Control.FOCUS_NONE,
		"one inert stitch overlay decorates the corner")
	_check(app.return_button.custom_minimum_size.x < app.end_turn_button.custom_minimum_size.x
		and juice.fast_button.custom_minimum_size.x <= app.end_turn_button.custom_minimum_size.x,
		"both secondary actions stay shorter than the prominent End Turn")
	_check(app.return_button.text == "Return" and juice.fast_button.text == "Fast: Off",
		"both secondary actions use short labels")
	_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(app.action_corner.get_global_rect()),
		"whole sewn corner fits 1280x720")


func _tab_loop() -> void:
	var juice = app.get_node_or_null("LiveCombatJuice")
	var actions: Array = [app.end_turn_button, app.return_button, juice.fast_button]
	for control in actions:
		_check(control.focus_mode == Control.FOCUS_ALL and not control.disabled,
			"mouse and keyboard action enabled: " + control.name)
	app.end_turn_button.grab_focus()
	for index in range(1, actions.size() + 1):
		await _key(KEY_TAB)
		_check(actions[index % actions.size()].has_focus(), "forward physical Tab loop")
	for index in range(1, actions.size() + 1):
		await _key(KEY_TAB, true)
		_check(actions[(actions.size() - index) % actions.size()].has_focus(), "reverse physical Tab loop")


## Legal and rejected proposals: deterministic, detached, never spending or moving.
func _service_cases() -> Array:
	var trace: Array = []
	var living: Array = app.party.get_heroes()
	for pair in [1, 2]:
		var before := _snapshot()
		var first := CombatPositionSwaps.preview_adjacent_swap(app.party, pair, 1)
		var second := CombatPositionSwaps.preview_adjacent_swap(app.party, pair, 1)
		_check(first.get("ok") == true and first == second, "service proposal is deterministic: pair %d" % pair)
		var heroes: Array = first.get("heroes", [])
		_check(heroes.size() == CombatParty.PARTY_SIZE
			and heroes[pair - 1].get("id") == living[pair].get("id")
			and heroes[pair].get("id") == living[pair - 1].get("id"),
			"real adjacent pair is exchanged without touching other actors: pair %d" % pair)
		var ordered := true
		for index in range(heroes.size()):
			ordered = ordered and heroes[index].get("position") == index + 1
		_check(ordered, "proposal renumbers final positions 1..3: pair %d" % pair)
		var proposal_trace: Array = []
		for hero in heroes:
			proposal_trace.append([hero.get("id"), hero.get("position"), hero.get("hp")])
		trace.append([true, proposal_trace])
		# Mutating the proposal must never reach the authoritative roster.
		heroes[0]["hp"] = -1
		heroes[0]["statuses"] = {"bleed": 99}
		_check(app.party.get_heroes() == living, "proposal is a detached deep copy: pair %d" % pair)
		_check(_snapshot() == before, "legal proposal spends no energy and moves no actor: pair %d" % pair)
	# Invalid positions and directions fail closed without a copied roster.
	for args in [[0, 1], [4, 1], [1, 0], [1, 2], [2, -2], [3, 1]]:
		var mover: int = args[0]
		var direction: int = args[1]
		var rejected := CombatPositionSwaps.preview_adjacent_swap(app.party, mover, direction)
		_check(rejected.get("ok") == false and rejected.get("heroes", null) is Array
			and rejected.heroes.is_empty(),
			"off-board position or direction rejected: %d/%d" % [mover, direction])
	_check(app.party.get_heroes() == living, "invalid arguments leave every actor untouched")
	# A downed neighbour or mover rejects the proposal and never revives or moves anyone.
	var down_position := 2
	_check(app.party.apply_damage(down_position, 10000) and app.party.is_downed(down_position),
		"real neighbour is downed for the rejection case")
	var downed := _snapshot()
	seed(8124)
	var global_next := randi()
	seed(8124)
	for pair in [1, 2]:
		var rejected := CombatPositionSwaps.preview_adjacent_swap(app.party, pair, 1)
		_check(rejected.get("ok") == false and rejected.get("heroes", []).is_empty(),
			"proposal touching a downed actor is rejected: pair %d" % pair)
	_check(_snapshot() == downed and randi() == global_next,
		"downed rejection never spends, moves, revives or draws global RNG")
	app.party._heroes.assign(living)
	await _frames()
	_check(app.party.get_heroes() == living, "restored roster preserves every actor identity")
	# An invalid party model rejects instead of inventing a proposal.
	var original: CombatParty = app.party
	app.party = CombatParty.new([])
	var invalid := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
	_check(invalid.get("ok") == false and invalid.get("heroes", []).is_empty(),
		"invalid party model rejects every proposal")
	app.party = original
	await _frames()
	_check(app.party == original and app.party.get_heroes() == living,
		"the real party is restored unchanged after the invalid-model case")
	return trace


## The real paid movement card still spends one energy and reorders living actors.
func _paid_move_case() -> void:
	app.deck.hand.assign(["warden_backstep", "warden_shield_bash", "warden_strike"])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var panel: Control = app.hand_view.get_child(0)
	_check(app.hand_view.get_child_count() == 3 and panel.get_child(0).text == "warden_backstep",
		"real paid move card is mounted in the shared hand")
	var before := _snapshot()
	var expected := before.duplicate(true)
	var mover: Dictionary = expected[5][0]
	expected[5][0] = expected[5][1]
	expected[5][1] = mover
	for index in range(3):
		expected[5][index]["position"] = index + 1
	expected[0].remove_at(0)
	expected[2].append("warden_backstep")
	expected[3] -= 1
	seed(24680)
	var next := randi()
	seed(24680)
	await _click(panel)
	_check(_snapshot() == expected,
		"real paid move spends exactly one energy, moves both actors and discards once")
	_check(randi() == next, "real paid move draws no global RNG")
	_check(app.party.get_hero(1).id == "seamstress" and app.party.get_hero(2).id == "warden",
		"the paid move really reordered the living roster")
	var settled := _snapshot()
	var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
	_check(proposal.get("ok") == true and _snapshot() == settled,
		"the read-only proposal after the paid move moves and spends nothing")


## A real End Turn still advances the phase through the same service-free action.
func _end_turn_case() -> void:
	var before := _snapshot()
	await _click(app.end_turn_button)
	_check(app.enemy_intents._turn_index == int(before[9]) + 1 and app.deck.turn_active,
		"physical End Turn advances the real round and starts the next player turn")
	await _frames()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_position_swap_preview_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		preload("res://tests/legacy_card_app_fixture.gd").enable(target)
		target.start_run_requested.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
