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
		app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true), app.intent_label.text,
		app.enemies.get_enemies(), app.enemy_intents._turn_index]


func _visible(app, target: int = 1) -> void:
	_check(is_instance_valid(app.intent_label), "mounted intent label exists")
	if is_instance_valid(app.intent_label):
		_check(app.intent_label.is_visible_in_tree() and app.battle_view.is_ancestor_of(app.intent_label),
			"intent is mounted and visible in battle")
		_check(app.intent_label.text == "Intent: Enemy 1 -> Hero %d (%s): 1 damage; Enemy 2: 1 Block" % [
			target, "Warden" if target == 1 else "Seamstress"],
			"visible intent accurately describes authored source, target and damage")
	_check(app.enemy_attacks == [{"enemy_position": 1, "type": "attack", "amount": 1,
		"target_position": target}, {"enemy_position": 2, "type": "block", "amount": 1}]
		and app.enemy_attacks == app.enemy_intents.get_intents(),
		"retained snapshot matches current selector and expected step")
	_check(app.hero_panels.size() == 3, "all hero panels mounted")
	for index in range(app.hero_panels.size()):
		var panel = app.hero_panels[index]
		_check(is_instance_valid(panel) and panel.get_child_count() > 0, "hero panel has content")
		if not is_instance_valid(panel) or panel.get_child_count() == 0:
			continue
		var label = panel.get_child(0)
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(label is Label and label.is_visible_in_tree(), "hero text is visible")
		if label is Label:
			_check(label.text.contains("HP: %d/%d | Block: %d" % [hero.hp, hero.max_hp, hero.block]),
				"hero display reflects actual HP and Block")
	_check(app.hand_view.get_child_count() == app.deck.hand.size(), "hand display refreshed")
	var presenter = app.get_node("LiveEnemyRoster")
	_check(presenter.enemies == app.enemies and is_instance_valid(presenter.panel), "one shared mounted enemy roster")
	if is_instance_valid(presenter.panel):
		var labels: Array[Node] = presenter.panel.find_children("*", "Label", true, false)
		_check(labels.size() == 2, "both enemy controls mounted")
		for index in range(labels.size()):
			var enemy: Dictionary = app.enemies.get_enemy(index + 1)
			_check(labels[index].is_visible_in_tree() and labels[index].text == "Enemy %d - %s\nHP: %d/%d | Block: %d" % [
				enemy.position, enemy.name, enemy.hp, enemy.max_hp, enemy.block], "mounted enemy HP/Block reflect result")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()], "pile display refreshed")


func _invalid_sources(app) -> void:
	var path := "user://live_enemy_phase_invalid.json"
	var action := {"type": "attack", "target_position": 1, "amount": 1}
	var valid := {"enemy_position": 1, "pattern": [action]}
	var fixtures: Array[String] = ["{", "{}", "[]", "[null]", "[1]", "[{}]",
		JSON.stringify([valid, valid])]
	for field in valid:
		var missing := valid.duplicate(true)
		missing.erase(field)
		fixtures.append(JSON.stringify([missing]))
		for bad in [null, true, "1", 0.5, -1, 1e30]:
			var record := valid.duplicate(true)
			record[field] = bad
			fixtures.append(JSON.stringify([record]))
	for bad in [0, 4]:
		fixtures.append(JSON.stringify([{"enemy_position": bad, "pattern": [action]}]))
	for bad in [[], {}, [null], [1], [{}]]:
		fixtures.append(JSON.stringify([{"enemy_position": 1, "pattern": bad}]))
	for field in action:
		var missing := action.duplicate()
		missing.erase(field)
		fixtures.append(JSON.stringify([{"enemy_position": 1, "pattern": [action, missing]}]))
		for bad in [null, true, "1", 0.5, -1, 1e30]:
			var invalid := action.duplicate()
			invalid[field] = bad
			fixtures.append(JSON.stringify([{"enemy_position": 1, "pattern": [action, invalid]}]))
	for invalid in [{"type": "attack", "target_position": 0, "amount": 1},
		{"type": "attack", "target_position": 4, "amount": 1},
		{"type": "block", "amount": 1, "target_position": 1}, {"type": "heal", "amount": 1},
		{"type": "attack", "target_position": 1, "amount": 1, "extra": 0}]:
		# A valid first step must never hide an invalid later step or record.
		fixtures.append(JSON.stringify([{"enemy_position": 1, "pattern": [action, invalid]}]))
		fixtures.append(JSON.stringify([valid, {"enemy_position": 2, "pattern": [invalid]}]))
	fixtures.append(JSON.stringify([{"enemy_position": 1, "pattern": [action], "extra": 0}]))
	fixtures.append(JSON.stringify([{"enemy_position": 1, "target_position": 1, "amount": 1}]))
	var guard := {"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}
	# Malformed Block steps must reject even when the attack and both positions are valid.
	for bad in [{"type": "block", "amount": -1}, {"type": "block", "amount": 0.5},
		{"type": "block", "amount": true}, {"type": "block", "amount": 1e30},
		{"type": "block"}, {"type": "block", "amount": 1, "extra": 0}]:
		fixtures.append(JSON.stringify([valid, {"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}, bad]}]))
	fixtures.append(JSON.stringify([valid, {"enemy_position": 3, "pattern": guard.pattern}]))
	for source in fixtures:
		# Keep the other source valid so rejection exercises bad data rather than a missing Guard.
		var parser := JSON.new()
		parser.parse(source)
		var parsed = parser.data
		if parsed is Array and parsed.size() == 1:
			parsed.append(guard)
			source = JSON.stringify(parsed)
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "negative fixture opens outside repository")
		if file == null:
			continue
		file.store_string(source)
		file.close()
		app.starter_attacks_path = path
		app.start_button.pressed.emit()
		_rejected(app)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app.starter_attacks_path = path
	app.start_button.pressed.emit()
	_rejected(app)
	app.starter_attacks_path = app.STARTER_ATTACKS_PATH
	# Individually valid but incomplete schedules also reject atomically.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([valid]))
	file.close()
	app.starter_attacks_path = path
	app.start_button.pressed.emit()
	_rejected(app)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app.starter_attacks_path = app.STARTER_ATTACKS_PATH


func _rejected(app) -> void:
	_check(app.deck == null and app.party == null and app.run_rng == null and app.enemies == null,
		"invalid or missing phase rejects before session creation")
	_check(app.battle_view == null and app.intent_label == null and app.enemy_attacks.is_empty() and app.enemy_intents == null,
		"rejection leaves no partial battle or intent")
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "rejection retains title and focus")
	app._end_turn()
	_check(app.deck == null and app.party == null, "inactive title End Turn is inert")


func _run() -> void:
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(is_instance_valid(app.start_button) and app.start_button.is_visible_in_tree(), "real title Start Run mounted")
	if not is_instance_valid(app.start_button):
		app.free()
		_finish()
		return
	_invalid_sources(app)
	var source: Array[String] = []
	source.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var first_trace: Array = []
	for session in range(2):
		app.start_button.pressed.emit()
		_check(app.party is CombatParty and app.deck is CombatDeck and app.run_rng != null,
			"real Start Run creates complete session")
		_check(is_instance_valid(app.end_turn_button) and is_instance_valid(app.return_button), "real battle controls exist")
		if app.party == null or app.deck == null or app.run_rng == null or not is_instance_valid(app.end_turn_button) or not is_instance_valid(app.return_button):
			app.free()
			_finish()
			return
		await process_frame
		_check(app.end_turn_button.is_visible_in_tree() and app.end_turn_button.has_focus(), "End Turn visible and keyboard focused")
		if "--inject-wrong-intent" in OS.get_cmdline_user_args():
			app.intent_label.text = "wrong"
		if "--inject-missing-intent" in OS.get_cmdline_user_args():
			app.intent_label.free()
		_visible(app)
		if not failures.is_empty():
			app.free()
			_finish()
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = app.run_seed
		var reference := CombatDeck.new(source, rng)
		_check(reference.start_turn(), "reference turn starts")
		var reference_party := CombatParty.new(app._load_party_definitions())
		CombatStartingBlock.new(reference_party).apply()
		var reference_enemies := CombatEnemies.new(app._load_enemy_definitions())
		var trace: Array = [_snapshot(app)]
		var before := _snapshot(app)
		app.start_button.pressed.emit()
		_check(_snapshot(app) == before, "duplicate Start Run cannot execute attacks or replace session")
		for turn in range(12):
			_check(app.deck.try_spend_energy(2) and reference.try_spend_energy(2), "spend actual shared energy")
			before = _snapshot(app)
			_check(not app.deck.try_spend_energy(2) and not app.deck.start_turn(), "failed spend and duplicate start reject")
			_check(_snapshot(app) == before, "rejected actions preserve hero, piles, energy and RNG")
			var blocked := turn % 4 < 2
			if blocked:
				_check(app.party.gain_block(1, 3) and app.party.gain_block(2, 4), "gain real front and middle Block")
				_check(reference_party.gain_block(1, 3) and reference_party.gain_block(2, 4), "reference Block fixture")
			var target := turn % 2 + 1
			var heroes: Array = app.party.get_heroes()
			_check(CombatEnemyAttacks.new().execute_attacks(reference_party, [{"enemy_position": 1,
				"target_position": target, "amount": 1}]).ok, "reference resolves announced Ragling hit first")
			_check(CombatEnemyBlocks.execute_blocks(reference_enemies, [{"type": "block",
				"enemy_position": 2, "amount": 1}]).ok, "reference resolves Guard Block second")
			_check(reference.end_turn(), "reference ends hand after successful enemy actions")
			_check(reference.start_turn() and reference_party.start_player_turn(), "reference deck and party advance")
			app.end_turn_button.pressed.emit()
			var completed := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == completed, "duplicate End Turn in same input dispatch stays inert")
			await process_frame
			_check(app.party.get_heroes() == reference_party.get_heroes()
				and app.enemies.get_enemies() == reference_enemies.get_enemies(), "complete party and enemy transition matches merged services")
			_check(app.enemies.get_enemy(2).block == turn + 1 and app.enemies.get_enemy(1).block == 0,
				"living Guard gains exactly one Block per phase; Ragling gains none")
			_check(app.party.get_hero(target).hp == heroes[target - 1].hp - (0 if blocked else 1), "cycling target takes exactly one hit using Block before HP")
			for position in range(1, 4):
				_check(app.party.get_hero(position).block == 0, "next player turn clears all Block")
			for position in range(1, 4):
				if position != target:
					_check(app.party.get_hero(position).hp == heroes[position - 1].hp, "only announced hero takes damage")
			_check(_deck(app.deck) == _deck(reference) and app.run_rng.state == rng.state,
				"enemy phase consumes no RNG; deck, discard, draw and three energy cadence unchanged")
			_check(app.enemy_intents._turn_index == turn + 1, "successful phase advances selector exactly once")
			_visible(app, (turn + 1) % 2 + 1)
			trace.append(_snapshot(app))
		# A stale announcement and an overflowing Block both fail before any hand or attack mutation.
		before = _snapshot(app)
		app.enemy_attacks[1].enemy_position = 3
		var corrupt := _snapshot(app)
		app.end_turn_button.pressed.emit()
		_check(_snapshot(app) == corrupt, "invalid announced source rejects atomically")
		app.enemy_attacks = app.enemy_intents.get_intents()
		_check(_snapshot(app) == before, "restoring snapshot changes no run state")
		# A structurally valid but stale amount must also fail the authoritative equality guard.
		app.enemy_attacks[0].amount += 1
		corrupt = _snapshot(app)
		app.end_turn_button.pressed.emit()
		_check(_snapshot(app) == corrupt, "valid-shaped stale announcement preserves complete state")
		app.enemy_attacks = app.enemy_intents.get_intents()
		var prior_block: int = app.enemies.get_enemy(2).block
		_check(app.enemies.gain_block(2, CombatEnemies.MAX_INT - prior_block), "overflow fixture reaches maximum Block")
		before = _snapshot(app)
		_check(app.deck.turn_active and not app.end_turn_button.disabled
			and app.enemy_attacks == app.enemy_intents.get_intents(), "late overflow reaches service with active hand and authoritative intents")
		app.end_turn_button.pressed.emit()
		_check(_snapshot(app) == before, "overflowing later Block cannot end hand or apply earlier attack")
		_check(not app.end_turn_button.disabled, "rejected batch leaves End Turn available")
		_check(app.enemies.apply_damage(2, CombatEnemies.MAX_INT - prior_block), "restore valid Block before control rejection cases")
		_check(app.enemies.get_enemies() == reference_enemies.get_enemies(), "control cases have otherwise valid enemy state")
		# A mounted but inactive, hidden or disabled control must have no effects.
		for mode in ["disabled", "hidden", "missing", "foreign", "inactive"]:
			if mode == "disabled":
				app.end_turn_button.disabled = true
			elif mode == "hidden":
				app.battle_view.hide()
			elif mode == "inactive":
				_check(app.deck.end_turn(), "enter actual inactive deck phase")
			before = _snapshot(app)
			if mode == "missing":
				app._end_turn()
			elif mode == "foreign":
				app._end_turn(app.return_button)
			else:
				app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == before, "inactive/hidden/disabled button cannot damage, spend, draw or change RNG")
			app.end_turn_button.disabled = false
			app.battle_view.show()
		if session == 0:
			first_trace = trace
		else:
			_check(trace == first_trace, "fresh same-seed run replays every hero, deck and RNG snapshot")
		var old_button: Button = app.end_turn_button
		var old_party: WeakRef = weakref(app.party)
		var old_selector: WeakRef = weakref(app.enemy_intents)
		var old_enemies: WeakRef = weakref(app.enemies)
		var intent_id: int = app.intent_label.get_instance_id()
		app.return_button.pressed.emit()
		old_button.pressed.emit()
		_check(app.deck == null and app.party == null and app.run_rng == null and app.battle_view == null,
			"return tears down session; detached button cannot resurrect it")
		_check(app.enemy_attacks.is_empty() and app.intent_label == null and app.enemy_intents == null,
			"return clears selector, intent data and label")
		_check(old_selector.get_ref() == null, "old selector released")
		_check(old_party.get_ref() == null, "old party released")
		_check(app.enemies == null and old_enemies.get_ref() == null, "app and presenter release old enemy roster")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "return restores title and keyboard focus")
		await process_frame
		_check(not is_instance_id_valid(intent_id), "old mounted intent freed")
	await _slain_sources(app)
	await _cue_refresh(app)
	app.free()
	_finish()


func _slain_sources(app) -> void:
	for slain in [1, 2]:
		app.start_button.pressed.emit()
		_check(app.enemies != null and app.party != null and app.deck != null, "slain-source case starts real session")
		if app.enemies == null or app.party == null or app.deck == null:
			return
		_check(app.enemies.apply_damage(slain, 12) and app.enemies.is_slain(slain), "announced source really slain")
		var before_frame := _snapshot(app)
		await process_frame
		await process_frame
		_check(is_instance_valid(app.intent_label) and app.intent_label.is_visible_in_tree(),
			"slain-source intent remains mounted before End Turn")
		_check(app.intent_label.text == ("Intent: Enemy 2: 1 Block" if slain == 1
			else "Intent: Enemy 1 -> Hero 1 (Warden): 1 damage"),
			"slain source disappears on rendered frame before End Turn")
		var after_frame := _snapshot(app)
		before_frame[5] = after_frame[5]
		_check(before_frame == after_frame, "intent frame refresh changes no models, selector, deck or RNG")
		# Remove opening protection so a spurious slain-source attack cannot hide in Block.
		_check(app.party.start_player_turn(), "clear opening Block for slain-source check")
		var heroes: Array = app.party.get_heroes()
		var expected_heroes := heroes.duplicate(true)
		if slain != 1:
			expected_heroes[0].hp -= 1
		var expected_enemies: Array = app.enemies.get_enemies()
		if slain != 2:
			expected_enemies[1].block += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = app.run_seed
		var cards: Array[String] = []
		cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
		var reference := CombatDeck.new(cards, rng)
		_check(reference.start_turn() and reference.end_turn() and reference.start_turn(), "slain-source reference advances exactly one hand")
		app.end_turn_button.pressed.emit()
		_check(app.party.get_heroes() == expected_heroes and app.enemies.get_enemies() == expected_enemies
			and _deck(app.deck) == _deck(reference) and app.run_rng.state == rng.state,
			"slain-source full models, draw/discard, hand, energy and RNG match expected transition")
		_check(app.enemy_intents._turn_index == 1 and app.enemy_attacks == app.enemy_intents.get_intents()
			and app.enemy_attacks[0].target_position == 2, "slain-source turn advances intent exactly once")
		_check(app.intent_label.text == ("Intent: Enemy 2: 1 Block" if slain == 1
			else "Intent: Enemy 1 -> Hero 2 (Seamstress): 1 damage"), "living source displays exact next intent")
		_check(app.party.get_hero(1).hp == heroes[0].hp - (0 if slain == 1 else 1), "only living Ragling attacks")
		_check(app.enemies.get_enemy(2).block == (0 if slain == 2 else 1), "only living Guard gains Block")
		_check(app.enemies.get_enemy(slain).hp == 0 and app.enemies.get_enemy(slain).position == slain,
			"slain source retains its original slot")
		_check(not app.intent_label.text.contains("Enemy %d" % slain), "slain source no longer announces an action")
		var presenter = app.get_node("LiveEnemyRoster")
		_check(presenter.enemies == app.enemies and is_instance_valid(presenter.panel), "slain source remains in mounted shared roster")
		if is_instance_valid(presenter.panel):
			var labels: Array[Node] = presenter.panel.find_children("*", "Label", true, false)
			_check(labels.size() == 2 and labels[slain - 1].text.ends_with("SLAIN"), "mounted slain label refreshed")
		app.return_button.pressed.emit()
		await process_frame


func _cue_refresh(app) -> void:
	app.start_button.pressed.emit()
	_check(app.enemies != null and app.enemy_intents != null and is_instance_valid(app.intent_label),
		"cue refresh has real mounted roster, selector and label")
	if app.enemies == null or app.enemy_intents == null or not is_instance_valid(app.intent_label):
		return
	var initial := _snapshot(app)
	app.enemy_attacks[0].amount += 10
	var stale := _snapshot(app)
	app._refresh_intents()
	_check(app.intent_label.text == initial[5] and _snapshot(app) == stale,
		"label uses authoritative cues despite stale cached attack without mutating state")
	app.enemy_attacks = app.enemy_intents.get_intents()
	var selector: CombatEnemyIntents = app.enemy_intents
	var roster: CombatEnemies = app.enemies
	for mode in ["missing_selector", "invalid_selector", "missing_roster", "invalid_roster", "mismatched_roster"]:
		if mode == "missing_selector":
			app.enemy_intents = null
		elif mode == "invalid_selector":
			app.enemy_intents = CombatEnemyIntents.new([])
		elif mode == "missing_roster":
			app.enemies = null
		elif mode == "invalid_roster":
			app.enemies = CombatEnemies.new([])
		else:
			app.enemies = CombatEnemies.new([app._load_enemy_definitions()[0]])
		app._refresh_intents()
		_check(app.intent_label.text == "Intent: none", "cue label fails closed: " + mode)
		app.enemy_intents = selector
		app.enemies = roster
	app._refresh_intents()
	_check(_snapshot(app) == initial, "cue reads preserve complete original session")
	var label: Label = app.intent_label
	app.intent_label = null
	app._refresh_intents()
	app.intent_label = label
	_check(_snapshot(app) == initial, "missing label refresh is inert")
	app.return_button.pressed.emit()
	await process_frame
	app._refresh_intents()
	_check(app.intent_label == null and app.enemies == null, "title refresh cannot recreate session")


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_phase_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
