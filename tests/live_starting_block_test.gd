extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _deck(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(),
		deck.discard_pile.duplicate(), deck.energy, deck.turn_active]


func _snapshot(app) -> Array:
	return [app.party.get_heroes(), _deck(app.deck), app.run_rng.state,
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(), app.intent_label.text,
		app.enemies.get_enemies()]


func _visible(app, hp: Array, block: Array, target: int) -> void:
	var meters = app.get_node("LiveCombatMeters")
	meters._sync_battle()
	_check(is_instance_valid(meters.row) and meters.row.get_child_count() >= 3, "real hero meters mounted")
	if is_instance_valid(meters.row) and meters.row.get_child_count() >= 3:
		for index in range(3):
			var meter = meters.row.get_child(index)
			var actor: Dictionary = app.party.get_hero(index + 1)
			_check(meter.hp_text.is_visible_in_tree() and meter.hp_text.text == "%d/%d" % [actor.hp, actor.max_hp]
				and meter.block_badge.visible == (actor.block > 0)
				and (actor.block == 0 or (meter.block_text.is_visible_in_tree()
					and meter.block_text.text == "%d" % actor.block)),
				"visible meter retains exact authoritative HP and Block")

	_check(app.hero_panels.size() == 3, "three mounted hero panels")
	for index in range(3):
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(hero.hp == hp[index] and hero.block == block[index], "exact live HP and Block")
		if index >= app.hero_panels.size():
			continue
		var panel = app.hero_panels[index]
		_check(is_instance_valid(panel) and app.battle_view.is_ancestor_of(panel), "panel mounted in real battle")
		if not is_instance_valid(panel):
			continue
		var label = panel.get_child(0) if panel.get_child_count() > 0 else null
		_check(label is Label and not label.visible, "mounted hero label visible")
		if label is Label:
			_check(label.text == "%d - %s\nHP: %d/%d | Block: %d" % [
				index + 1, hero.name, hp[index], hero.max_hp, block[index]], "mounted text matches expected HP and Block")
	_check(is_instance_valid(app.intent_label), "mounted intent exists")
	if is_instance_valid(app.intent_label):
		_check(not app.intent_label.visible and app.battle_view.is_ancestor_of(app.intent_label), "intent mounted and visible")
		_check(app.intent_label.text == "Intent: Enemy 1 -> Hero %d (%s): 1 damage; Enemy 2: 1 Block" % [
			target, ["Warden", "Seamstress", "Tinker"][target - 1]], "authored rotating intent text")
	_check(app.enemy_attacks == [{"enemy_position": 1, "type": "attack", "amount": 1,
		"target_position": target}, {"enemy_position": 2, "type": "block", "amount": 1}],
		"authored attack cycle and Guard Block schedule")


func _ready_session(app) -> bool:
	var ready: bool = app.party is CombatParty and app.party.is_valid() and app.deck is CombatDeck \
		and app.run_rng != null and app.enemy_intents is CombatEnemyIntents \
		and is_instance_valid(app.battle_view) and is_instance_valid(app.end_turn_button) \
		and is_instance_valid(app.return_button)
	_check(ready, "M01 fixture creates complete valid session and controls")
	_check(app.round_flow is CombatRoundFlow, "M01 fixture creates coordinator")
	if app.round_flow != null:
		_check(app.round_flow._started and app.round_flow._deck == app.deck
			and app.round_flow._party == app.party and app.round_flow._enemies == app.enemies
			and app.round_flow._intents == app.enemy_intents and app.round_flow._result == app.battle_result,
			"started coordinator binds every authoritative live model")
	return ready


func _duplicate(app) -> void:
	var before := _snapshot(app)
	var party: CombatParty = app.party
	var deck: CombatDeck = app.deck
	var rng: RandomNumberGenerator = app.run_rng
	var selector: CombatEnemyIntents = app.enemy_intents
	var battle: MarginContainer = app.battle_view
	var flow: CombatRoundFlow = app.round_flow
	app.start_button.pressed.emit()
	_check(app.party == party and app.deck == deck and app.run_rng == rng
		and app.enemy_intents == selector and app.battle_view == battle, "duplicate Start Run preserves session objects")
	_check(_snapshot(app) == before, "duplicate Start Run cannot grant Block or mutate state")
	_check(app.round_flow == flow, "duplicate Start preserves single coordinator")


func _rejected(app) -> void:
	_check(app.party == null and app.deck == null and app.run_rng == null and app.round_flow == null,
		"invalid party creates no session or recipient of opening grant")
	_check(app.battle_view == null and app.hero_panels.is_empty() and app.enemy_intents == null
		and app.enemy_attacks.is_empty(), "invalid party publishes no battle, panels or intent")
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "rejected start retains focused title")


func _party_fixtures(app) -> void:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_PARTY_PATH))
	var invalid := definitions.duplicate(true)
	invalid[1].id = invalid[0].id
	var path := "user://live_starting_block_party.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "external party fixture opens")
	if file == null:
		return
	file.store_string(JSON.stringify(invalid))
	file.close()
	app.starter_party_path = path
	seed(1827)
	var expected := randi()
	seed(1827)
	_check(not app._start_battle(), "duplicate-ID party rejects standalone M01 start")
	_check(randi() == expected, "duplicate-ID party rejection preserves global RNG")
	_rejected(app)
	# A structurally valid substitute for Warden must now fail the strict
	# one-time authored opening; no session or passive grant can leak.
	definitions[0].id = "alternate_front"
	var normalized := definitions.duplicate(true)
	for hero in normalized:
		hero["max_hp"] = int(hero["max_hp"])
	_check(CombatParty.new(normalized).is_valid(),
		"alternate-front party is structurally valid after authored JSON numeric normalization")
	file = FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "alternate fixture opens")
	if file != null:
		file.store_string(JSON.stringify(definitions))
		file.close()
		seed(1827)
		expected = randi()
		seed(1827)
		_check(not app._start_battle(), "alternate-front party rejects standalone M01 start")
		_check(randi() == expected, "alternate-front rejection preserves global RNG")
		_rejected(app)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app.starter_party_path = path
	seed(1827)
	expected = randi()
	seed(1827)
	_check(not app._start_battle(), "missing party rejects standalone M01 start")
	_check(randi() == expected, "missing party rejection preserves global RNG")
	_rejected(app)
	app.starter_party_path = app.STARTER_PARTY_PATH


func _run() -> void:
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(is_instance_valid(app.start_button), "real title Start Run exists")
	if not is_instance_valid(app.start_button):
		app.free()
		_finish()
		return
	_check(app.start_button.is_visible_in_tree() and app.start_button.has_focus(), "real Start Run available and focused")
	_party_fixtures(app)
	var source: Array[String] = []
	source.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var first_trace: Array = []
	for session in range(2):
		_check(app._start_battle(), "standalone M01 opening-Block fixture starts successfully")
		if not _ready_session(app):
			app.free()
			_finish()
			return
		await process_frame
		_check(app.end_turn_button.is_visible_in_tree() and not app.end_turn_button.disabled
			and app.end_turn_button.has_focus(), "actual End Turn is available and focused")
		if "--inject-wrong-text" in OS.get_cmdline_user_args():
			app.hero_panels[0].get_child(0).text = "wrong"
		if "--inject-missing-panel" in OS.get_cmdline_user_args():
			app.hero_panels.pop_back().free()
		_visible(app, [40, 30, 26], [6, 0, 0], 1)
		var rng := RandomNumberGenerator.new()
		rng.seed = app.run_seed
		var reference := CombatDeck.new(source, rng)
		_check(reference.start_turn(), "reference initial turn starts")
		_check(_deck(app.deck) == _deck(reference) and app.run_rng.state == rng.state
			and app.deck.energy == 3, "opening grant does not spend energy, change deck or consume RNG")
		var trace: Array = [_snapshot(app)]
		_duplicate(app)
		app._refresh_party()
		_check(_snapshot(app) == trace[0], "refresh cannot reapply opening grant")
		for turn in range(3):
			_check(app.deck.try_spend_energy(2) and reference.try_spend_energy(2), "spend shared energy before real End Turn")
			app.end_turn_button.pressed.emit()
			await process_frame
			_check(reference.end_turn() and reference.start_turn(), "reference advances")
			# The authored front policy always sends the Ragling at the front
			# living hero; the opening Block absorbs the first hit exactly.
			_visible(app, [[40, 30, 26], [39, 30, 26], [38, 30, 26]][turn], [0, 0, 0], 1)
			_check(_deck(app.deck) == _deck(reference) and app.run_rng.state == rng.state
				and app.deck.energy == 3, "enemy attack and Block reset preserve deterministic deck, RNG and energy")
			_duplicate(app)
			trace.append(_snapshot(app))
		if session == 0:
			first_trace = trace
		else:
			_check(trace == first_trace, "same-seed restart repeats heroes, deck, energy, RNG and all intents")
		var old_party: WeakRef = weakref(app.party)
		var old_flow: WeakRef = weakref(app.round_flow)
		var old_button: Button = app.end_turn_button
		app.return_button.pressed.emit()
		old_button.pressed.emit()
		_rejected(app)
		_check(old_party.get_ref() == null, "return releases old party and its grant")
		_check(old_flow.get_ref() == null, "Return releases coordinator and its actor bindings")
		await process_frame
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_starting_block_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
