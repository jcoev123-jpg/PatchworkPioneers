extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _cards(deck: CombatDeck) -> Array[String]:
	var cards := deck.draw_pile + deck.hand + deck.discard_pile
	cards.sort()
	return cards


func _run() -> void:
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	if "--inject-missing-control" in OS.get_cmdline_user_args():
		app.start_button.free()
	_check(is_instance_valid(app.start_button), "Start run button exists")
	if not is_instance_valid(app.start_button):
		app.free()
		_finish()
		return
	_check(app.start_button.is_visible_in_tree() and not app.start_button.disabled,
		"Start run is available")
	_check(app.deck == null, "no deck before Start run")
	app.start_button.pressed.emit()
	_check(app.deck is CombatDeck and app.run_rng != null, "button creates live deck and run RNG")
	_check(is_instance_valid(app.end_turn_button), "End Turn button exists")
	if app.deck == null or app.run_rng == null or not is_instance_valid(app.end_turn_button):
		app.free()
		_finish()
		return
	var deck: CombatDeck = app.deck
	_check(deck.combat_state is CombatState, "live deck uses actual CombatState")
	var state := deck.combat_state
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	_check(source is Array and not source.is_empty(), "starter source is nonempty")
	if not source is Array or source.is_empty():
		app.free()
		_finish()
		return
	source.sort()
	for turn in range(12):
		if turn == 0 and "--inject-wrong-energy" in OS.get_cmdline_user_args():
			state.energy = 2
		_check(app.deck == deck and deck.combat_state == state, "same live deck and state retained")
		_check(deck.turn_active and state.player_turn_active and deck.energy == 3 and state.energy == 3,
			"real turn %d grants exactly three energy" % turn)
		_check(deck.hand.size() == 5 and app.hand_view.get_child_count() == deck.hand.size(),
			"real turn has five cards and matching visible panels")
		_check(_cards(deck) == source, "live turn conserves every starter card copy")
		_check(app.end_turn_button.is_visible_in_tree() and not app.end_turn_button.disabled,
			"End Turn is available")
		var rng_before: int = app.run_rng.state
		var piles_before := [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate()]
		_check(deck.try_spend_energy(2) and deck.energy == 1 and state.energy == 1,
			"live spending uses shared state")
		_check(not deck.start_turn() and deck.energy == 1, "duplicate live start cannot refill")
		_check(not deck.try_spend_energy(-1) and not deck.try_spend_energy(2), "live invalid costs rejected")
		_check(app.run_rng.state == rng_before and
			[deck.draw_pile, deck.hand, deck.discard_pile] == piles_before and deck.energy == 1,
			"live spending and rejections preserve piles and RNG")
		app.end_turn_button.pressed.emit()
		_check(deck.energy == 3 and state.energy == 3 and deck.turn_active,
			"End Turn button refreshes shared energy immediately")
		_check(_cards(deck) == source, "End Turn button conserves all card copies")
		await process_frame
	# Observe the cleared phase directly on the same live object; the button otherwise
	# completes end/start synchronously, which the repeated turns above exercise.
	_check(deck.end_turn() and deck.energy == 0 and not state.player_turn_active,
		"live end clears remaining energy and deactivates")
	_check(deck.hand.is_empty() and _cards(deck) == source, "live end discards and conserves cards")
	_check(not deck.try_spend_energy(0), "live inactive spending fails")
	_check(deck.start_turn() and deck.energy == 3, "live next start refreshes energy")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_energy_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
