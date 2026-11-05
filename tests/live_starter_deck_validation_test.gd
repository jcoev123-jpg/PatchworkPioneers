extends SceneTree

const FIXTURE := "user://live_starter_deck_validation.json"
const UNREADABLE := "user://live_starter_deck_validation_directory"
const STARTER_ORACLE := preload("res://tests/starter_fight_oracle.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _write(text: String) -> bool:
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	_check(file != null, "temporary JSON fixture opens")
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _clear_session(app) -> void:
	_check(app.deck == null and app.run_rng == null and app.party == null and app.enemies == null,
		"no deck, RNG, party or enemies remain")
	_check(app.enemy_intents == null and app.enemy_attacks.is_empty() and app.battle_result == null
		and app.victory_gold == null and app.session_gold == 0 and not app._battle_closed,
		"no selector, result or reward session remains")
	_check(app.battle_view == null and app.hand_view == null and app.hero_view == null
		and app.hero_panels.is_empty() and app.result_label == null and app.return_button == null
		and app.end_turn_button == null, "no partial battle view or actions")
	_check(app.title_view.is_visible_in_tree() and app.start_button.is_visible_in_tree()
		and not app.start_button.disabled and app.start_button.has_focus(), "title visible and keyboard actionable")


func _reject(app, path: String) -> void:
	app.starter_deck_path = path
	# Observe the same global stream that an accidental unseeded shuffle would consume.
	seed(1827)
	var expected := randi()
	seed(1827)
	_check(not app._start_battle(), "invalid or missing deck rejects standalone M01 start")
	_check(randi() == expected, "rejected M01 start does not consume global RNG")
	_clear_session(app)


func _snapshot(deck: CombatDeck, rng: RandomNumberGenerator) -> Array:
	return [deck.hand.duplicate(), deck.draw_pile.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck.turn_active, rng.seed, rng.state]


func _session(app, source: Array[String]) -> Array:
	_check(app._start_battle(), "standalone M01 deck fixture starts successfully")
	_check(app.deck != null and app.run_rng != null and app.party != null and app.enemies != null
		and app.enemy_intents != null and app.battle_result != null, "M01 fixture creates all session models")
	_check(is_instance_valid(app.battle_view) and is_instance_valid(app.return_button)
		and is_instance_valid(app.end_turn_button), "M01 fixture mounts battle and Return actions")
	if app.deck == null or app.run_rng == null or app.party == null or app.enemies == null \
		or not is_instance_valid(app.return_button) or not is_instance_valid(app.end_turn_button):
		return []
	_check(app.party.is_valid() and app.party.get_heroes().size() == 3, "three valid live heroes")
	_check(app.enemies.is_valid() and app.enemies.get_enemies().size() == 2, "two valid live enemies")
	_check(app.deck.hand.size() == 5 and app.deck.energy == 3 and app.deck.turn_active,
		"opening five held cards and exact three energy")
	_check(app.battle_view.is_visible_in_tree() and not app.title_view.visible
		and app.hand_view.get_child_count() == 5, "playable battle replaces title")
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_seed
	var reference := CombatDeck.new(source, rng)
	_check(reference.start_turn(), "reference starts")
	var trace: Array = []
	for turn in range(4):
		var before := _snapshot(app.deck, app.run_rng)
		_check(before == _snapshot(reference, rng), "authored source order preserved through seeded shuffle and refill")
		trace.append(before)
		var identities := [app.deck, app.run_rng, app.party, app.enemies, app.enemy_intents, app.battle_result, app.battle_view]
		var heroes: Array = app.party.get_heroes()
		var enemies: Array = app.enemies.get_enemies()
		app.start_run_requested.emit()
		_check(identities == [app.deck, app.run_rng, app.party, app.enemies, app.enemy_intents, app.battle_result, app.battle_view]
			and before == _snapshot(app.deck, app.run_rng) and heroes == app.party.get_heroes()
			and enemies == app.enemies.get_enemies(), "repeated Start preserves session identity and state")
		_check(app.deck.try_spend_energy(2) and reference.try_spend_energy(2), "spend live shared energy")
		var spent := _snapshot(app.deck, app.run_rng)
		_check(not app.deck.try_spend_energy(2) and _snapshot(app.deck, app.run_rng) == spent, "failed spend is inert")
		app.end_turn_button.pressed.emit()
		await process_frame
		_check(reference.end_turn() and reference.start_turn(), "reference advances turn")
	trace.append(_snapshot(app.deck, app.run_rng))
	_check(trace.back() == _snapshot(reference, rng), "final full deck and RNG snapshot matches reference")
	app.return_button.pressed.emit()
	await process_frame
	_clear_session(app)
	return trace


func _run() -> void:
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(STARTER_ORACLE.pin_guard_block(app, "user://live_starter_deck_guard.json"),
		"shipped Guard Ragling pinned to its own authored Block alternative")
	_check(is_instance_valid(app.start_button), "mounted Start button exists")
	if not is_instance_valid(app.start_button):
		app.free()
		_finish()
		return
	_clear_session(app)
	_check(app.starter_deck_path == app.STARTER_DECK_PATH, "default exported path is authored deck")
	var authored: Array[String] = []
	authored.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var normal: Array = await _session(app, authored)
	_check(not normal.is_empty(), "authored start exercised")
	var canonical := StarterCards.new().get_starting_deck()
	_check(not canonical.is_empty(), "catalog starting deck exists")
	if canonical.is_empty():
		app.free()
		_finish()
		return
	var non_string: Array = []
	non_string.append_array(canonical)
	non_string[0] = 7
	var unknown := canonical.duplicate()
	unknown[0] = "unknown_starter_card"
	var empty_id := canonical.duplicate()
	empty_id[0] = ""
	var extra := canonical.duplicate()
	extra.append(canonical[0])
	var wrong_counts := canonical.duplicate()
	for card in canonical:
		if card != canonical[0]:
			wrong_counts[0] = card
			break
	for text in ["{", "{}", "null", "42", "\"card\"", "[]", "",
		JSON.stringify(non_string), JSON.stringify(unknown), JSON.stringify(empty_id),
		JSON.stringify(canonical.slice(1)), JSON.stringify(extra), JSON.stringify(wrong_counts)]:
		if _write(text):
			_reject(app, FIXTURE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	_check(not FileAccess.file_exists(FIXTURE), "missing fixture really absent")
	_reject(app, FIXTURE)
	_check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(UNREADABLE)) == OK, "unreadable directory fixture created")
	_check(DirAccess.dir_exists_absolute(UNREADABLE) and FileAccess.open(UNREADABLE, FileAccess.READ) == null,
		"directory cannot be opened as a deck file")
	_reject(app, UNREADABLE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(UNREADABLE))
	var reordered := authored.duplicate()
	reordered.reverse()
	_check(reordered != authored, "valid permutation actually changes source order")
	if _write(JSON.stringify(reordered)):
		app.starter_deck_path = FIXTURE
		app.run_seed = 9217
		var first: Array = await _session(app, reordered)
		var replay: Array = await _session(app, reordered)
		_check(not first.is_empty() and first == replay, "same seed and source replay complete hand/piles/energy/RNG trace")
	app.free()
	_finish()


func _finish() -> void:
	for path in [FIXTURE, UNREADABLE]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "fixture cleaned")
	for failure in failures:
		printerr(failure)
	print("live_starter_deck_validation_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
