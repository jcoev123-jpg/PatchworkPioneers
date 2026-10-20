extends SceneTree

var failures: Array[String] = []
var checks := 0
const SOURCE := "res://data/enemies/starter_enemies.json"
const FIXTURE := "user://live_enemy_roster_invalid.json"


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _snapshot(app) -> Array:
	return [app.party.get_heroes(), app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.run_rng.state, app.enemy_intents.get_intents(), app.enemies.get_enemies()]


func _visible(app, presenter) -> void:
	_check(presenter.enemies is CombatEnemies, "real battle has CombatEnemies")
	_check(is_instance_valid(presenter.panel), "enemy panel exists")
	if presenter.enemies == null or not is_instance_valid(presenter.panel):
		return
	_check(presenter.enemies.is_valid(), "roster valid")
	_check(presenter.enemies == app.enemies, "app and presenter share the identical authoritative model")
	var guard: Dictionary = app.enemies.get_enemy(2)
	_check(guard.get("id") == "ragling_guard" and guard.get("name") == "Guard Ragling"
		and guard.get("hp") == 12 and guard.get("max_hp") == 12 and guard.get("block") == 0,
		"authored position-two Guard Ragling starts at 12 HP and zero Block")
	_check(app.intent_label.text == "Intent: Enemy 1 -> Hero 1 (Warden): 1 damage; Enemy 2: 1 Block",
		"real start announces both authored intents")
	var ragling := presenter.enemies.get_enemy(1) as Dictionary
	_check(ragling.get("id") == "ragling" and ragling.get("position") == 1 and
		ragling.get("hp") == 12 and ragling.get("max_hp") == 12 and ragling.get("block") == 0,
		"authored position-one ragling is living at 12/12 HP and zero Block")
	_check(not presenter.enemies.is_slain(1), "ragling living")
	_check(presenter.panel.is_visible_in_tree() and app.battle_view.is_ancestor_of(presenter.panel),
		"enemy panel visibly mounted inside battle")
	var labels: Array[Node] = presenter.panel.find_children("*", "Label", true, false)
	_check(labels.size() == presenter.enemies.get_enemies().size(), "every roster entry has readable text")
	_check(not labels.is_empty(), "enemy text exists")
	if not labels.is_empty():
		_check(labels[0].is_visible_in_tree() and labels[0].text == "Enemy 1 - Ragling\nHP: 12/12 | Block: 0",
			"visible placeholder identifies ragling and exact HP/Block")
		var rect: Rect2 = labels[0].get_global_rect()
		_check(rect.size.x > 0 and rect.size.y > 0 and Rect2(0, 0, 1280, 720).encloses(rect),
			"enemy label fits target viewport")
	_check(labels.size() >= 2, "Guard label exists")
	if labels.size() >= 2:
		_check(labels[1].is_visible_in_tree() and labels[1].text == "Enemy 2 - Guard Ragling\nHP: 12/12 | Block: 0",
			"visible Guard placeholder identifies exact HP and Block")
		_check(Rect2(0, 0, 1280, 720).encloses(labels[1].get_global_rect()), "Guard fits target viewport")
	_check(app.end_turn_button.is_visible_in_tree() and app.return_button.is_visible_in_tree(),
		"real battle actions stay visible")
	_check(Rect2(0, 0, 1280, 720).encloses(app.return_button.get_global_rect()), "return action fits viewport")
	_check(app.end_turn_button.focus_next == app.end_turn_button.get_path_to(app.return_button),
		"keyboard action navigation retained")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	var reference = scene.instantiate()
	var reference_presenter = reference.get_node("LiveEnemyRoster")
	reference.remove_child(reference_presenter)
	reference_presenter.free()
	root.add_child(reference)
	root.add_child(app)
	await process_frame
	var presenter = app.get_node_or_null("LiveEnemyRoster")
	_check(presenter != null and is_instance_valid(app.start_button), "scene presenter and real Start Run exist")
	if presenter == null or not is_instance_valid(app.start_button):
		app.free()
		reference.free()
		_finish()
		return
	_check(app.start_button.is_visible_in_tree() and not app.start_button.disabled and
		presenter.enemies == null and presenter.panel == null, "title is actionable without premature roster")
	var first_trace: Array = []
	for session in range(2):
		app.start_button.pressed.emit()
		reference.start_button.pressed.emit()
		await process_frame
		await process_frame
		_check(app.deck is CombatDeck and app.party is CombatParty and app.run_rng != null,
			"real Start Run constructs deck, party and RNG")
		if app.deck == null or app.party == null or app.run_rng == null:
			break
		if "--inject-missing-control" in OS.get_cmdline_user_args():
			presenter.panel.free()
		if "--inject-wrong-value" in OS.get_cmdline_user_args():
			presenter.enemies.apply_damage(1, 1)
		_visible(app, presenter)
		if not failures.is_empty():
			app.free()
			reference.free()
			_finish()
			return
		var roster_ref: WeakRef = weakref(presenter.enemies)
		var panel_id: int = presenter.panel.get_instance_id() if is_instance_valid(presenter.panel) else 0
		var before := _snapshot(app)
		app.start_button.pressed.emit()
		await process_frame
		_check(presenter.enemies == roster_ref.get_ref() and is_instance_valid(presenter.panel) and
			presenter.panel.get_instance_id() == panel_id, "duplicate Start Run retains same roster and panel")
		_check(app.battle_view.find_children("EnemyRosterPanel", "PanelContainer", true, false).size() == 1,
			"exactly one presenter panel per battle")
		_check(_snapshot(app) == before, "duplicate Start Run preserves all gameplay state")
		var trace: Array = []
		for turn in range(12):
			_check(_snapshot(app) == _snapshot(reference), "presenter leaves hero/deck/energy/RNG trace intact")
			_check(presenter.enemies == app.enemies and app.enemies.get_enemies() == reference.enemies.get_enemies(),
				"observed roster matches battle without presenter")
			_check(app.enemies.get_enemy(1).hp == 12 and app.enemies.get_enemy(2).hp == 12
				and app.enemies.get_enemy(1).block == 0 and app.enemies.get_enemy(2).block == turn,
				"only Guard's announced Block changes the live roster")
			trace.append([_snapshot(app), presenter.enemies.get_enemies() if presenter.enemies != null else []])
			_check(app.deck.try_spend_energy(2) and reference.deck.try_spend_energy(2), "real shared energy spend")
			app.end_turn_button.pressed.emit()
			reference.end_turn_button.pressed.emit()
			await process_frame
		if session == 0:
			first_trace = trace
		else:
			_check(trace == first_trace, "fresh same-seed session reproduces roster and full gameplay trace")
		reference.return_button.pressed.emit()
		app.return_button.pressed.emit()
		_check(presenter.enemies == null and presenter.panel == null and roster_ref.get_ref() == null,
			"Return to Title immediately releases roster and detaches panel")
		await process_frame
		_check(not is_instance_id_valid(panel_id), "old panel freed")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "title and keyboard focus restored")
	await _invalid_sources(app, reference, presenter)
	# A valid multi-entry source proves the whole list is parsed, without fixing catalog totals.
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify([{"id": "first", "name": "First", "max_hp": 3, "art_path": "unused"},
		{"id": "second", "name": "Second", "max_hp": 7, "art_path": "unused"}]))
	file.close()
	app.starter_enemies_path = FIXTURE
	app.start_button.pressed.emit()
	await process_frame
	_check(presenter.enemies != null and presenter.enemies.get_enemy(2).get("id") == "second",
		"complete valid list creates later enemy")
	_check(is_instance_valid(presenter.panel) and presenter.panel.find_children("*", "Label", true, false).size() == 2,
		"multi-entry fixture mounts every enemy")
	app.return_button.pressed.emit()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	app.free()
	reference.free()
	_finish()


func _invalid_sources(app, reference, presenter) -> void:
	var valid := {"id": "valid", "name": "Valid", "max_hp": 12, "art_path": "unused"}
	var fixtures: Array[String] = ["{", "{}", "[]", "[null]", "[1]", "[{}]", JSON.stringify([valid, valid])]
	for field in valid:
		var missing := valid.duplicate()
		missing.erase(field)
		fixtures.append(JSON.stringify([valid, missing]))
	for hp in [null, true, "12", 0, -1, 0.5, 12.5, 1e30]:
		var bad := valid.duplicate()
		bad.id = "later"
		bad.max_hp = hp
		fixtures.append(JSON.stringify([valid, bad]))
	for id in [null, true, 1, ""]:
		var bad := valid.duplicate()
		bad.id = id
		fixtures.append(JSON.stringify([valid, bad]))
	fixtures.append(JSON.stringify([valid, {"id": "b", "max_hp": 1, "name": "B", "art_path": "unused"},
		{"id": "c", "max_hp": 1, "name": "C", "art_path": "unused"},
		{"id": "d", "max_hp": 1, "name": "D", "art_path": "unused"}]))
	# Missing path first, then malformed files, all through the actual player path.
	var paths: Array[String] = ["user://missing_roster_directory/enemies.json"]
	for fixture in fixtures:
		paths.append(FIXTURE)
	for index in range(paths.size()):
		if index > 0:
			var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
			_check(file != null, "external negative fixture opens")
			if file == null:
				continue
			file.store_string(fixtures[index - 1])
			file.close()
		app.starter_enemies_path = paths[index]
		reference.start_button.pressed.emit()
		app.start_button.grab_focus()
		app.start_button.pressed.emit()
		await process_frame
		_check(app.deck == null and app.party == null and app.run_rng == null and app.enemies == null,
			"bad roster rejects every run object atomically")
		_check(presenter.enemies == null and presenter.panel == null and app.battle_view == null,
			"invalid complete source creates no partial roster or panel")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "invalid roster retains actionable title")
		app._end_turn()
		_check(app.deck == null and app.party == null and app.enemies == null, "invalid roster End Turn remains inert")
		# Correcting the source permits a fresh start, with no leaked state from rejection.
		app.starter_enemies_path = SOURCE
		app.start_button.pressed.emit()
		await process_frame
		_check(app.deck != null and app.enemies != null and presenter.enemies == app.enemies,
			"corrected source starts complete shared model")
		if app.deck != null and app.enemies != null:
			_check(_snapshot(app) == _snapshot(reference), "rejected source cannot leak hero, enemy, deck, energy or RNG state")
			app.end_turn_button.pressed.emit()
			reference.end_turn_button.pressed.emit()
			_check(_snapshot(app) == _snapshot(reference), "corrected run End Turn matches clean reference")
		reference.return_button.pressed.emit()
		app.return_button.pressed.emit()
		_check(presenter.enemies == null and presenter.panel == null, "invalid battle teardown inert")
		await process_frame


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_roster_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
