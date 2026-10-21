extends SceneTree

const EXPECTED := {
	"warden_strike": 2, "warden_brace": 1, "warden_shield_bash": 1,
	"seamstress_prick": 2, "seamstress_mend": 1, "seamstress_stitch_up": 1,
	"tinker_pop_shot": 2, "tinker_scrap_bomb": 1, "tinker_tune_up": 1,
}

var failures: Array[String] = []
var checks := 0
var starts := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _snapshot(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(),
		deck.discard_pile.duplicate(), deck.turn_active]


func _copies(cards: Array) -> Dictionary:
	var result := {}
	for card in cards:
		result[card] = result.get(card, 0) + 1
	return result


func _visible(app) -> void:
	_check(app.battle_view != null and app.battle_view.is_visible_in_tree(), "battle mounted and visible")
	_check(app.hand_view != null and app.hand_view.is_visible_in_tree(), "hand mounted and visible")
	if app.hand_view == null:
		return
	_check(app.hand_view.get_child_count() == 5, "five visible card panels")
	var ids: Array[String] = []
	for panel in app.hand_view.get_children():
		_check(panel is PanelContainer and panel.is_visible_in_tree(), "visible placeholder panel")
		var label = panel.get_child(0) if panel.get_child_count() > 0 else null
		_check(label is Label and label.is_visible_in_tree(), "visible card label exists")
		if label is Label:
			ids.append(label.text)
	_check(ids == app.deck.hand, "visible IDs match actual hand in order")
	_check(app.pile_label != null and app.pile_label.is_visible_in_tree(), "visible pile counts exist")
	if app.pile_label != null:
		_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()], "visible counts match actual piles")
	_check(app.deck.hand.size() == 5 and app.deck.turn_active, "five actual cards in active turn")
	_check(_copies(app.deck.draw_pile + app.deck.hand + app.deck.discard_pile) == EXPECTED,
		"all twelve starter copies conserved")


func _run() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	_check(source is Array, "starter JSON is an array")
	if not source is Array:
		_finish()
		return
	_check(_copies(source) == EXPECTED, "starter multiplicities match design exactly")
	var cards: Array[String] = []
	cards.assign(source)
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(app.title_label.text == "Patchwork Pioneers" and app.title_label.is_visible_in_tree(), "title retained")
	_check(app.start_button != null and app.start_button.is_visible_in_tree(), "Start run mounted")
	_check(app.start_button.has_focus(), "title starts with keyboard focus")
	_check(app.deck == null and app.run_rng == null and app.battle_view == null, "initial session empty")
	app.start_run_requested.connect(func(): starts += 1)
	app.run_seed = 42
	var first_trace: Array = []
	for session in range(2):
		_fixture_start(app)
		_check(starts == 0, "fixture does not emit seeded Start; duplicate Start still emits")
		_check(app.deck != null and app.run_rng != null, "Start run creates real session objects")
		if app.deck == null or app.run_rng == null:
			app.free()
			_finish()
			return
		_check(not app.title_view.is_visible_in_tree(), "title hidden in battle")
		_check(app.end_turn_button.has_focus(), "End Turn receives keyboard focus")
		_check(app.end_turn_button.focus_mode == Control.FOCUS_ALL and
			app.return_button.focus_mode == Control.FOCUS_ALL, "battle actions support keyboard and mouse")
		var actions: Array = [app.end_turn_button, app.return_button]
		actions.append_array(app.swap_preview_buttons)
		_check(actions.size() == 4, "both preview controls join battle actions")
		for index in range(actions.size()):
			_check(actions[index].get_node(actions[index].focus_next) == actions[(index + 1) % actions.size()] and
				actions[index].get_node(actions[index].focus_previous) == actions[(index - 1 + actions.size()) % actions.size()],
				"complete forward and reverse keyboard action cycle")
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var reference := CombatDeck.new(cards, rng)
		reference.start_turn()
		var trace: Array = []
		var deck_ref: WeakRef = weakref(app.deck)
		var rng_ref: WeakRef = weakref(app.run_rng)
		var view_id: int = app.battle_view.get_instance_id()
		var child_count: int = app.get_child_count()
		# A second request while active cannot replace the current session.
		app._start_run()
		_check(app.deck == deck_ref.get_ref() and app.get_child_count() == child_count, "duplicate start preserves session")
		for turn in range(12):
			if session == 0 and turn == 0:
				if "--inject-wrong-count" in OS.get_cmdline_user_args():
					app.pile_label.text = "wrong"
				if "--inject-missing-control" in OS.get_cmdline_user_args():
					app.hand_view.get_child(0).free()
			_visible(app)
			_check(_snapshot(app.deck) == _snapshot(reference), "UI lifecycle matches real deck reference")
			_check(app.run_rng.state == rng.state, "UI uses only the session RNG")
			trace.append(_snapshot(app.deck))
			if turn == 0:
				_check(app.deck.draw_pile.size() == 7 and app.deck.discard_pile.is_empty(), "opening piles 7/0")
			if turn == 1:
				_check(app.deck.draw_pile.size() == 2 and app.deck.discard_pile == trace[0][1], "first end discards entire opening hand")
			if turn == 2:
				_check(app.deck.draw_pile.size() == 7 and app.deck.discard_pile.is_empty(), "third hand crosses seeded reshuffle")
			if turn < 11:
				_check(reference.end_turn() and reference.start_turn(), "reference turn advances")
				app.end_turn_button.pressed.emit()
				await process_frame
		if session == 0:
			first_trace = trace
		else:
			_check(trace == first_trace, "fresh fixed-seed session replays every opening and later pile")
		app.return_button.pressed.emit()
		await process_frame
		_check(app.deck == null and app.run_rng == null, "return clears session references")
		_check(deck_ref.get_ref() == null and rng_ref.get_ref() == null, "return releases deck and RNG")
		_check(not is_instance_id_valid(view_id), "battle view removed and freed")
		_check(app.battle_view == null and app.hand_view == null and app.pile_label == null and
			app.end_turn_button == null and app.return_button == null, "battle control references cleared")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "return restores visible focused title")
		app._end_turn()
		app._return_to_title()
		_check(app.deck == null and app.get_child_count() == child_count - 1, "inactive actions do not recreate stale session")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
