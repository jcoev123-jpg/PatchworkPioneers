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
		app.enemies.get_enemies(), app.enemy_intents._turn_index, app.battle_result.get_outcome()]


## The Guard Ragling now authors Block 5, a right shield rush and a real
## six-point Jab and seven-point Bash. This mounted phase suite pins the fight to the Guard's own
## authored Block alternative so every End Turn stays deterministic; the shipped
## record is asserted to really carry all four alternatives before narrowing it.
func _pin_authored_guard(app) -> bool:
	var source: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(app.STARTER_ENEMIES_PATH))
	_check(source is Array and not source.is_empty(), "shipped starter enemy catalog parses")
	if not source is Array:
		return false
	var records: Array = []
	var guard_block: Dictionary = {}
	for record in source:
		if not record is Dictionary:
			_check(false, "shipped starter enemy records are dictionaries")
			return false
		var copy: Dictionary = record.duplicate(true)
		if copy.get("id") == "ragling_guard":
			var actions = copy.get("intent", {}).get("actions", [])
			_check(actions is Array and actions.size() == 4,
				"shipped Guard Ragling authors exactly four weighted alternatives")
			if not actions is Array:
				return false
			for raw in actions:
				if CombatEnemyIntents.weighted_action(raw).get("action", {}).get("type") == "block":
					guard_block = raw.duplicate(true)
			_check(int(guard_block.get("amount", 0)) == 5,
				"the Guard's own Block alternative is exactly five")
			if guard_block.is_empty():
				return false
			copy["intent"] = {"target": "front", "actions": [guard_block]}
		records.append(copy)
	_check(records.size() == source.size() and not guard_block.is_empty(),
		"pinned catalog keeps every shipped enemy record")
	var path := "user://live_enemy_phase_guard.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "pinned catalog opens outside the repository")
	if file == null:
		return false
	file.store_string(JSON.stringify(records))
	file.close()
	app.starter_enemies_path = path
	return app._load_enemy_definitions().size() == records.size()


## The authored front policy sends the Ragling at the front living hero.
func _front_target(app) -> int:
	for index in range(CombatParty.PARTY_SIZE):
		if app.party.get_hero(index + 1).hp > 0:
			return index + 1
	return 1


func _visible(app, target: int = -1, expected_amount: int = 5, guard_block: int = 5) -> void:
	if target < 1:
		target = _front_target(app)
	app.get_node("LiveCombatMeters")._sync_battle()
	_check(is_instance_valid(app.intent_label), "mounted intent label exists")
	if is_instance_valid(app.intent_label):
		_check(not app.intent_label.visible and app.battle_view.is_ancestor_of(app.intent_label),
			"legacy intent source remains mounted without a duplicate sentence")
		_check(app.intent_label.text == "Intent: Enemy 1 -> Hero %d (%s): %d damage; Enemy 2: %d Block" % [
			target, ["Warden", "Seamstress", "Tinker"][target - 1], expected_amount, guard_block],
			"visible intent accurately describes authored source, target and damage: "
			+ app.intent_label.text)
	_check(app.enemy_attacks == [{"enemy_position": 1, "type": "attack", "amount": expected_amount,
		"target_position": target}, {"enemy_position": 2, "type": "block", "amount": guard_block}]
		and app.enemy_attacks == app.enemy_intents.get_intents(),
		"retained snapshot matches current selector and expected step: "
		+ str(app.enemy_attacks))
	_check(app.hero_panels.size() == 3, "all hero panels mounted")
	for index in range(app.hero_panels.size()):
		var panel = app.hero_panels[index]
		_check(is_instance_valid(panel) and panel.get_child_count() > 0, "hero panel has content")
		if not is_instance_valid(panel) or panel.get_child_count() == 0:
			continue
		var label = panel.get_child(0)
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(label is Label and not label.visible and panel.is_visible_in_tree(), "hero source text is retained behind the visible puppet and meter")
		if label is Label:
			_check(label.text.contains("HP: %d/%d | Block: %d" % [hero.hp, hero.max_hp, hero.block]),
				"hero display reflects actual HP and Block")
	var meters = app.get_node("LiveCombatMeters").row
	_check(is_instance_valid(meters) and meters.get_child_count() == 3 + app.enemies.get_enemies().size(), "actual meters mounted for every actor")
	if is_instance_valid(meters):
		var actors: Array = app.party.get_heroes() + app.enemies.get_enemies()
		for index in range(actors.size()):
			var meter = meters.get_child(index)
			var actor: Dictionary = actors[index]
			_check(meter.is_visible_in_tree() and meter.hp_text.is_visible_in_tree()
				and meter.hp_text.text == "%d/%d" % [actor.hp, actor.max_hp]
				and meter.block_badge.visible == (actor.block > 0)
				and (actor.block == 0 or meter.block_text.is_visible_in_tree())
				and meter.block_text.text == ("%d" % actor.block if actor.block > 0 else ""),
				"one visible authoritative HP/Block readout per actor")
	_check(app.hand_view.get_child_count() == app.deck.hand.size(), "hand display refreshed")
	var presenter = app.get_node("LiveEnemyRoster")
	_check(presenter.enemies == app.enemies and is_instance_valid(presenter.panel), "one shared mounted enemy roster")
	if is_instance_valid(presenter.panel):
		var labels: Array[Node] = presenter.panel.find_children("EnemyState*", "Label", true, false)
		_check(labels.size() == 2, "both enemy controls mounted")
		for index in range(labels.size()):
			var enemy: Dictionary = app.enemies.get_enemy(index + 1)
			_check(labels[index].is_visible_in_tree() and labels[index].text == String(enemy.name),
				"mounted enemy name tag preserves identity without duplicate HP/Block")
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
	for special in [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
		{"type": "buff", "amount": 3}]:
		for field in special:
			for bad in [null, true, 0.5, "1", 1e30]:
				var malformed: Dictionary = special.duplicate(true)
				malformed[field] = bad
				fixtures.append(JSON.stringify([valid, {"enemy_position": 2, "pattern": [special, malformed]}]))
		var extra: Dictionary = special.duplicate(true)
		extra["extra"] = 1
		fixtures.append(JSON.stringify([valid, {"enemy_position": 2, "pattern": [special, extra]}]))
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
		_fixture_start(app)
		_rejected(app)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app.starter_attacks_path = path
	_fixture_start(app)
	_rejected(app)
	app.starter_attacks_path = app.STARTER_ATTACKS_PATH
	# Individually valid but incomplete schedules also reject atomically.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([valid]))
	file.close()
	app.starter_attacks_path = path
	_fixture_start(app)
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
	_check(_pin_authored_guard(app),
		"mounted starter fight is pinned to the Guard's own authored Block alternative")
	_invalid_sources(app)
	var source: Array[String] = []
	source.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var first_trace: Array = []
	for session in range(2):
		_fixture_start(app)
		_check(app.party is CombatParty and app.deck is CombatDeck and app.run_rng != null,
			"real Start Run creates complete session")
		_check(app.enemy_intents != null and app.enemy_intents.is_bound()
			and app.enemy_attacks == app.enemy_intents.get_intents()
			and app.enemy_attacks.size() == app.enemies.get_enemies().size(),
			"real Start binds one authored weighted announcement per original enemy slot")
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
		_check(app.round_flow != null and app.round_flow._started
			and app.round_flow._deck == app.deck and app.round_flow._party == app.party
			and app.round_flow._enemies == app.enemies and app.round_flow._intents == app.enemy_intents
			and app.round_flow._result == app.battle_result, "mounted End Turn owns started authoritative coordinator")
		var flow: CombatRoundFlow = app.round_flow
		for field in ["_deck", "_party", "_enemies", "_intents", "_result"]:
			var bound = flow.get(field)
			flow.set(field, null)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == before and not app.end_turn_button.disabled,
				"stale coordinator binding rejects without changing surviving models: " + field)
			flow.set(field, bound)
		app.round_flow = null
		app.end_turn_button.pressed.emit()
		_check(_snapshot(app) == before and not app.end_turn_button.disabled, "missing coordinator fails closed")
		app.round_flow = flow
		flow._started = false
		app.end_turn_button.pressed.emit()
		_check(_snapshot(app) == before and not app.end_turn_button.disabled,
			"coordinator rejection restores button and preserves all session state")
		flow._started = true
		_fixture_start(app)
		_check(_snapshot(app) == before, "duplicate Start Run cannot execute attacks or replace session")
		for turn in range(12):
			_check(app.deck.try_spend_energy(2) and reference.try_spend_energy(2), "spend actual shared energy")
			before = _snapshot(app)
			_check(not app.deck.try_spend_energy(2) and not app.deck.start_turn(), "failed spend and duplicate start reject")
			_check(_snapshot(app) == before, "rejected actions preserve hero, piles, energy and RNG")
			var blocked := turn % 4 < 2
			if blocked:
				_check(app.party.gain_block(1, 3) and app.party.gain_block(2, 4) and app.party.gain_block(3, 2), "gain real Block in every target slot")
				_check(reference_party.gain_block(1, 3) and reference_party.gain_block(2, 4) and reference_party.gain_block(3, 2), "reference Block fixture")
			var target := _front_target(app)
			var heroes: Array = app.party.get_heroes()
			_check(CombatEnemyAttacks.new().execute_attacks(reference_party, [{"enemy_position": 1,
				"target_position": target, "amount": 5}]).ok, "reference resolves announced Ragling hit first")
			_check(CombatEnemyBlocks.execute_blocks(reference_enemies, [{"type": "block",
				"enemy_position": 2, "amount": 5}]).ok, "reference resolves Guard Block second")
			_check(reference.end_turn(), "reference ends hand after successful enemy actions")
			_check(reference.start_turn() and reference_party.start_player_turn(), "reference deck and party advance")
			app.end_turn_button.pressed.emit()
			var completed := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == completed, "duplicate End Turn in same input dispatch stays inert")
			await process_frame
			_check(app.party.get_heroes() == reference_party.get_heroes()
				and app.enemies.get_enemies() == reference_enemies.get_enemies(), "complete party and enemy transition matches merged services")
			_check(app.enemies.get_enemy(2).block == (turn + 1) * 5 and app.enemies.get_enemy(1).block == 0,
				"living Guard gains exactly its five authored Block per phase; Ragling gains none")
			_check(app.party.get_hero(target).hp == maxi(0, heroes[target - 1].hp - maxi(0, 5 - heroes[target - 1].block)), "front living target takes exactly one hit using Block before HP")
			for position in range(1, 4):
				_check(app.party.get_hero(position).block == 0, "next player turn clears all Block")
			for position in range(1, 4):
				if position != target:
					_check(app.party.get_hero(position).hp == heroes[position - 1].hp, "only announced hero takes damage")
			_check(_deck(app.deck) == _deck(reference) and app.run_rng.state == rng.state,
				"enemy phase consumes no RNG; deck, discard, draw and three energy cadence unchanged")
			_check(app.enemy_intents._turn_index == turn + 1, "successful phase advances selector exactly once")
			_visible(app)
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
		# Do not retain the coordinator while checking release of its actors.
		flow = null
		var old_flow: WeakRef = weakref(app.round_flow)
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
		_check(app.round_flow == null and old_flow.get_ref() == null, "Return releases live coordinator")
		_check(old_party.get_ref() == null, "old party released")
		_check(app.enemies == null and old_enemies.get_ref() == null, "app and presenter release old enemy roster")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "return restores title and keyboard focus")
		await process_frame
		_check(not is_instance_id_valid(intent_id), "old mounted intent freed")
	await _slain_sources(app)
	await _cue_refresh(app)
	await _status_damage(app)
	await _mounted_blind(app)
	await _mixed_rejection_replay(app)
	await _mounted_ram_charge(app)
	await _mounted_ram_guard_redirect(app)
	await _mounted_thread_lash(app)
	app.starter_enemies_path = app.STARTER_ENEMIES_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://live_enemy_phase_guard.json"))
	app.free()
	await _mounted_scavenger_wallet()
	await _mounted_scavenger_moves()
	_finish()


func _slain_sources(app) -> void:
	for slain in [1, 2]:
		_fixture_start(app)
		_check(app.enemies != null and app.party != null and app.deck != null, "slain-source case starts real session")
		if app.enemies == null or app.party == null or app.deck == null:
			return
		_check(app.enemies.apply_damage(slain, 12) and app.enemies.is_slain(slain), "announced source really slain")
		var before_frame := _snapshot(app)
		await process_frame
		await process_frame
		_check(is_instance_valid(app.intent_label) and not app.intent_label.visible,
			"slain-source intent remains mounted before End Turn")
		_check(app.intent_label.text == ("Intent: Enemy 2: 5 Block" if slain == 1
			else "Intent: Enemy 1 -> Hero 1 (Warden): 5 damage"),
			"slain source disappears on rendered frame before End Turn")
		var after_frame := _snapshot(app)
		before_frame[5] = after_frame[5]
		_check(before_frame == after_frame, "intent frame refresh changes no models, selector, deck or RNG")
		# Remove opening protection so a spurious slain-source attack cannot hide in Block.
		_check(app.party.start_player_turn(), "clear opening Block for slain-source check")
		var heroes: Array = app.party.get_heroes()
		var expected_heroes := heroes.duplicate(true)
		if slain != 1:
			expected_heroes[0].hp -= 5
		var expected_enemies: Array = app.enemies.get_enemies()
		if slain != 2:
			expected_enemies[1].block += 5
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
			and app.enemy_attacks[0].target_position == 1, "slain-source turn advances intent exactly once")
		_check(app.intent_label.text == ("Intent: Enemy 2: 5 Block" if slain == 1
			else "Intent: Enemy 1 -> Hero 1 (Warden): 5 damage"), "living source displays exact next intent")
		_check(app.party.get_hero(1).hp == heroes[0].hp - (0 if slain == 1 else 5), "only living Ragling attacks")
		_check(app.enemies.get_enemy(2).block == (0 if slain == 2 else 5), "only living Guard gains its five Block")
		_check(app.enemies.get_enemy(slain).hp == 0 and app.enemies.get_enemy(slain).position == slain,
			"slain source retains its original slot")
		_check(not app.intent_label.text.contains("Enemy %d" % slain), "slain source no longer announces an action")
		var presenter = app.get_node("LiveEnemyRoster")
		_check(presenter.enemies == app.enemies and is_instance_valid(presenter.panel), "slain source remains in mounted shared roster")
		if is_instance_valid(presenter.panel):
			var labels: Array[Node] = presenter.panel.find_children("EnemyState*", "Label", true, false)
			_check(labels.size() == 2
				and labels[slain - 1].text == String(app.enemies.get_enemy(slain).name)
				and presenter._badges[slain - 1].icon_mode == "slain",
				"mounted slain actor keeps its short name tag and slain badge")
		app.return_button.pressed.emit()
		await process_frame


func _cue_refresh(app) -> void:
	_fixture_start(app)
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


func _status_damage(app) -> void:
	for case in [
		{"weak": 1, "exposed": 0, "damage": 3},
		{"weak": 0, "exposed": 2, "damage": 7},
		{"weak": 1, "exposed": 2, "damage": 5},
		{"weak": 0, "exposed": 0, "damage": 5},
		{"weak": 0, "exposed": 1, "damage": 5},
		{"weak": 1, "exposed": 2, "damage": 5, "downed": true}]:
		var replay: Array = []
		for session in range(2):
			app.run_seed = 35035
			_fixture_start(app)
			await process_frame
			var bound: bool = app.party != null and app.enemies != null and app.deck != null \
				and app.round_flow != null and is_instance_valid(app.end_turn_button) \
				and app.end_turn_button.is_visible_in_tree() and not app.end_turn_button.disabled
			_check(bound, "status damage uses mounted active End Turn and authoritative services")
			if not bound:
				return
			# A five-damage schedule fixture exposes rounding and HP loss through
			# Block; it is an explicit legacy schedule with no authored policy, so
			# the mounted battle executes its exact beats.
			var legacy := CombatEnemyIntents.new([
				{"enemy_position": 1, "pattern": [
					{"type": "attack", "amount": 5, "target_position": 1},
					{"type": "attack", "amount": 5, "target_position": 2},
					{"type": "attack", "amount": 5, "target_position": 3}]},
				{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}])
			_check(legacy.is_valid(), "five-damage status fixture schedule validates")
			for enemy in app.enemies._enemies:
				enemy.erase("intent")
			app.enemy_intents = legacy
			app.round_flow._intents = legacy
			app.enemy_attacks = legacy.get_intents()
			app._refresh_intents()
			var hero: Dictionary = app.party._heroes[0]
			hero.block = 2
			if case.weak > 0:
				app.enemies._enemies[0]["statuses"] = {"weak": 1}
			if case.exposed > 0:
				hero["statuses"] = {"exposed": case.exposed}
			if case.get("downed", false):
				_check(app.party.apply_damage(1, 999) and app.party.is_downed(1), "mounted announced target is genuinely downed")
			var before := _snapshot(app)
			_check(before[3][0].amount == 5 and before[5].contains("5 damage"), "displayed intent retains base damage")
			# A late invalid status must not spend the hand or apply the earlier attack.
			app.enemies._enemies[1]["statuses"] = {"weak": -1}
			var invalid := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == invalid and not app.end_turn_button.disabled, "mounted invalid status preserves every actor, deck, intent, result and RNG")
			app.enemies._enemies[1].erase("statuses")
			_check(_snapshot(app) == before, "restored fixture is identical before successful button dispatch")
			var expected := before.duplicate(true)
			expected[0][0].hp = 0 if case.get("downed", false) else hero.hp - maxi(0, case.damage - 2)
			expected[0][0].block = 0
			if hero.has("statuses"):
				expected[0][0].statuses = {"exposed": 1} if case.exposed == 2 else {}
			if case.weak > 0:
				expected[6][0].statuses = {}
			expected[6][1].block = 1
			var rng := RandomNumberGenerator.new()
			rng.seed = app.run_seed
			var cards: Array[String] = []
			cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
			var oracle := CombatDeck.new(cards, rng)
			_check(oracle.start_turn() and oracle.end_turn() and oracle.start_turn(), "mounted damage deck oracle advances one hand")
			expected[1] = _deck(oracle)
			expected[2] = rng.state
			expected[3][0].target_position = 2
			expected[4][0].target_position = 2
			expected[5] = "Intent: Enemy 1 -> Hero 2 (Seamstress): 5 damage; Enemy 2: 1 Block"
			expected[7] = 1
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == expected, "mounted Weak/Exposed exact complete transition: " + str(case))
			var after := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == after, "duplicate status-modified End Turn is inert in same dispatch")
			await process_frame
			_check(_snapshot(app) == after, "rendered status transition preserves authoritative state and base announcements")
			var trace: Array = [before, after]
			if session == 0:
				replay = trace
			else:
				_check(trace == replay, "mounted status actor/deck/intent/result snapshots replay exactly")
			app.return_button.pressed.emit()
			await process_frame


func _mixed_rejection_replay(app) -> void:
	var replay: Array = []
	for session in range(2):
		app.run_seed = 56056
		_fixture_start(app)
		await process_frame
		var bound: bool = app.party != null and app.enemies != null and app.deck != null \
			and app.enemy_intents != null and app.round_flow != null \
			and is_instance_valid(app.end_turn_button) and app.end_turn_button.is_visible_in_tree() \
			and not app.end_turn_button.disabled
		_check(bound, "mixed rejection starts a complete mounted seeded fight")
		if not bound:
			return
		_check(app.party.start_player_turn(), "clear opening protection to expose actual mixed attack HP loss")
		app.party._heroes[0]["statuses"] = {"exposed": 2}
		app.enemies._enemies[0]["statuses"] = {"weak": 2}
		app._refresh_party()
		_visible(app)
		var first: Dictionary = app.party._heroes[0]
		var guard: Dictionary = app.enemies._enemies[1]
		# This explicit mixed fixture is a legacy one-beat schedule with no authored
		# target policy, so every rejection below exercises the phase transaction.
		var legacy := CombatEnemyIntents.new([
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 1}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}])
		_check(legacy.is_valid(), "mixed rejection schedule validates")
		for enemy in app.enemies._enemies:
			enemy.erase("intent")
		app.enemy_intents = legacy
		app.round_flow._intents = legacy
		app.enemy_attacks = legacy.get_intents()
		app._refresh_intents()
		var legal: Dictionary = app.enemy_intents._definitions[1].pattern[0].duplicate(true)
		var trace: Array = [_snapshot(app)]
		for rejection in ["malformed", "overflow"]:
			if rejection == "malformed":
				app.enemy_intents._definitions[1].pattern[0]["extra"] = true
			else:
				_check(app.enemies.gain_block(2, CombatEnemies.MAX_INT), "living later Block source is at capacity")
			var before := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == before and not app.end_turn_button.disabled,
				"actual End Turn rejects later " + rejection + " without actor, deck, selector or RNG changes")
			_check(is_same(app.party._heroes[0], first) and is_same(app.enemies._enemies[1], guard),
				"mounted rejected mixed phase retains actor dictionaries")
			trace.append(_snapshot(app))
			if rejection == "malformed":
				app.enemy_intents._definitions[1].pattern[0] = legal.duplicate(true)
			else:
				guard.block = 3
			await process_frame
		app.end_turn_button.pressed.emit()
		_check(app.party.get_hero(1).hp == first.max_hp - 1 and app.party.get_hero(1).block == 0
			and app.enemies.get_enemy(2).block == 4 and app.enemies.get_enemy(1).block == 0
			and app.enemy_intents._turn_index == 1,
			"legal mixed End Turn after both rejections attacks and grants Block exactly once")
		await process_frame
		_visible(app, -1, 1, 1)
		trace.append(_snapshot(app))
		if session == 0:
			replay = trace.duplicate(true)
		else:
			_check(trace == replay, "seeded mounted rejection/recovery phase, party, enemy and hand replay exactly")
		app.return_button.pressed.emit()
		await process_frame


func _mounted_thread_lash(app) -> void:
	var biter := {}
	for record in RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(
			"res://data/enemies/run_enemies.json")):
		if record.id == "thread_biter":
			biter = record
	var guards: Array = JSON.parse_string(FileAccess.get_file_as_string("user://live_enemy_phase_guard.json"))
	var guard := {}
	for record in guards:
		if record.id == "ragling_guard":
			guard = record
	_check(not biter.is_empty() and not guard.is_empty(), "mounted Lash uses genuine Biter and pinned authored Guard")
	if biter.is_empty() or guard.is_empty():
		return
	var path := "user://live_enemy_phase_thread_lash.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "mounted Lash fixture writes outside repository")
	if file == null:
		return
	file.store_string(JSON.stringify([biter, guard]))
	file.close()
	app.starter_enemies_path = path
	for amount in [5, 6]:
		_fixture_start(app)
		await process_frame
		_check(app.enemies != null and app.enemy_intents.is_bound(), "mounted genuine Biter binds weighted scheduler")
		if app.enemies == null or not app.enemy_intents.is_bound():
			break
		for turn in range(64):
			var action: Dictionary = app.enemy_intents.get_intents()[0]
			if action.type == "attack" and action.amount == amount:
				break
			_check(app.enemy_intents.advance_turn(), "mounted Lash seeks real cached attack")
		app.enemy_attacks = app.enemy_intents.get_intents()
		app._refresh_intents()
		var attack: Dictionary = app.enemy_attacks[0]
		_check(attack.type == "attack" and attack.amount == amount
			and attack.get("move", "") == ("attack2" if amount == 6 else ""), "real selected five/six precondition")
		_check(app.enemies.apply_damage(1, 10), "real Drain source wounded before End Turn")
		for hero in app.party._heroes:
			hero.block = 0
		var target: int = attack.target_position
		var hp: int = app.party.get_hero(target).hp
		var authored: Dictionary = app.enemies._enemies[0].intent.duplicate(true)
		# Stale to the actor, even though RoundFlow still owns the exact cache.
		for action in app.enemies._enemies[0].intent.actions:
			if action.type == "attack" and int(action.amount) == amount:
				action.amount = amount + 2
		var before := _snapshot(app)
		app.end_turn_button.pressed.emit()
		_check(_snapshot(app) == before and not app.end_turn_button.disabled,
			"stale authored pair rejects mounted End Turn atomically including hand and RNG")
		app.enemies._enemies[0].intent = authored
		app.end_turn_button.pressed.emit()
		await process_frame
		_check(app.party.get_hero(target).hp == hp - amount
			and app.enemies.get_enemy(1).hp == 5 + amount,
			"real mounted End Turn deals five/six once and Drains actual HP loss")
		app.return_button.pressed.emit()
		await process_frame
	app.starter_enemies_path = "user://live_enemy_phase_guard.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Discover through the shipped Fight router and weighted scheduler, never inject
## an action or narrow the Scavenger's policy.
func _wallet_route_fixture(move: String = "") -> Dictionary:
	var receipt := RunV3PartyAdmission.admit(["warden", "seamstress", "tinker"])
	_check(receipt.ok, "wallet route has genuine party admission")
	for seed_value in range(1, 4097):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var treasure := ""
		for id in map.get_legal_choices():
			if map.get_node(id).type == "Treasure":
				treasure = id
				break
		if treasure.is_empty() or not map.choose_node(treasure):
			continue
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			map.choose_node(id)
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
			if entry.get("success", false):
				var cards: Array[String] = []
				cards.assign(receipt.deck)
				var deck := CombatDeck.new(cards, rng)
				if entry.intents.bind_battle(entry.enemies, CombatParty.new(receipt.party), rng):
					for action in entry.intents.get_intents():
						if (move.is_empty() and action.type == "steal_gold") or (not move.is_empty()
								and entry.enemies.get_enemy(action.enemy_position).id == "fray_scavenger"
								and action.get("move", "") == move):
							return {"seed": seed_value, "id": id, "source": action.enemy_position, "treasure": treasure}
			break
	return {}


func _mounted_scavenger_moves() -> void:
	for move in ["attack2", "attack3"]:
		var fixture := _wallet_route_fixture(move)
		_check(not fixture.is_empty(), "connected seeded Fight witnesses " + move)
		if fixture.is_empty():
			continue
		var replay: Array = []
		for repeat_index in range(2):
			var app = load("res://scenes/app.tscn").instantiate()
			root.add_child(app)
			await process_frame
			app.run_seed = fixture.seed
			app.start_button.pressed.emit()
			preload("res://tests/party_choice.gd").choose(app)
			for button in app.route_buttons:
				if button.get_meta("route_id") == fixture.treasure:
					button.pressed.emit()
					break
			app.session_gold = 9
			for button in app.route_buttons:
				if button.get_meta("route_id") == fixture.id:
					button.pressed.emit()
					break
			await process_frame
			_check(app.round_flow != null and app.run_map.get_current_node_id() == fixture.id
				and app.enemy_intents.is_bound() and app.enemy_intents._rng == app.run_rng
				and app.enemies.get_enemy(fixture.source).id == "fray_scavenger"
				and not app.enemies.is_slain(fixture.source), "mounted live Scavenger uses single run RNG")
			if app.round_flow == null or app.enemy_attacks.size() < fixture.source:
				app.free()
				continue
			var cached: Array = app.enemy_attacks.duplicate(true)
			var action: Dictionary = cached[fixture.source - 1]
			var amount := 6 if move == "attack2" else 7
			var target := 1
			for position in range(1, 4):
				if app.party.get_hero(position).hp > 0 and app.party.get_hero(position).hp < app.party.get_hero(target).hp:
					target = position
			_check(action == {"enemy_position": fixture.source, "type": "attack",
				"amount": amount, "move": move, "target_position": target}, "real cache retains named move and lowest-HP front tie target")
			var before := _snapshot(app)
			_check(app.enemy_intents.get_intents() == cached and app.enemy_intents.get_intents() == cached
				and _snapshot(app) == before, "mounted repeated announcement reads are pure")
			var presenter = app.get_node("LiveEnemyRoster")
			var pose: Dictionary = presenter._move_catalog.lookup_enemy("fray_scavenger", action,
				"res://assets/paper/enemies/fray_scavenger_attack.png")
			var title := "Pin Flick" if move == "attack2" else "Sack Swing"
			_check(pose.get("name") == title and pose.get("pose") == move
				and pose.get("art") == (pose.get("named_art") if pose.get("art_available") else
					"res://assets/paper/enemies/fray_scavenger_attack.png")
				and presenter._badges[fixture.source - 1].tooltip_text.contains(title)
				and _snapshot(app) == before, "mounted named pose receipt and badge preserve authored name and fallback")
			for position in range(1, app.enemies.get_enemies().size() + 1):
				if position != fixture.source:
					_check(app.enemies.apply_damage(position, 999), "isolate named attack by slaying other sources")
			_check(app.party.start_player_turn() and app.party.gain_block(target, 3), "real three Block before named hit")
			var heroes: Array = app.party.get_heroes()
			# Forged and stale snapshots must fail before any gameplay/RNG changes.
			for forged in ["unknown", "attack2" if move == "attack3" else "attack3"]:
				app.enemy_attacks[fixture.source - 1].move = forged
				before = _snapshot(app)
				app._end_turn(app.end_turn_button)
				_check(_snapshot(app) == before and app.session_gold == 9, "forged move refuses without mutation")
			app.enemy_attacks = cached.duplicate(true)
			app.end_turn_button.pressed.emit()
			_check(app.session_gold == 9 and app.round_flow.get_gold() == 9, "named attack never debits wallet")
			for position in range(1, 4):
				_check(app.party.get_hero(position).hp == heroes[position - 1].hp - (amount - 3 if position == target else 0)
					and app.party.get_hero(position).block == 0, "mounted exact Block-before-HP named damage")
			before = _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == before and app.session_gold == 9, "named attack duplicate submission inert")
			var trace := [_snapshot(app), app.session_gold]
			if replay.is_empty():
				replay = trace
			else:
				_check(trace == replay, "named attack same-seed mounted replay")
			app.free()
			await process_frame


func _mounted_scavenger_wallet() -> void:
	var fixture := _wallet_route_fixture()
	_check(not fixture.is_empty(), "real routed Fight can announce Scavenger theft on entry")
	if fixture.is_empty():
		return
	var replay: Array = []
	for gold in [0, 1, 9, 9, 5]:
		var app = load("res://scenes/app.tscn").instantiate()
		root.add_child(app)
		await process_frame
		app.run_seed = fixture.seed
		app.start_button.pressed.emit()
		preload("res://tests/party_choice.gd").choose(app)
		_check(app.run_map != null and app.route_view != null, "wallet test entered real run chooser")
		if app.run_map == null:
			app.free()
			return
		for button in app.route_buttons:
			if button.get_meta("route_id") == fixture.treasure:
				button.pressed.emit()
				break
		_check(app.run_map.get_current_node_id() == fixture.treasure, "real Treasure route precedes funded Fight fixture")
		app.session_gold = gold
		var route_action: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == fixture.id:
				route_action = button
		_check(route_action != null, "wallet route has mounted Fight action")
		if route_action == null:
			app.free()
			return
		route_action.pressed.emit()
		await process_frame
		_check(app.round_flow != null and app.enemies.get_enemy(fixture.source).id == "fray_scavenger"
			and app.round_flow.get_gold() == gold, "real Fight binds carried wallet and authored Scavenger")
		if app.round_flow == null:
			app.free()
			return
		var theft: Dictionary = app.enemy_attacks[fixture.source - 1]
		_check(theft == {"type": "steal_gold", "amount": 2, "enemy_position": fixture.source},
			"mounted Fight really cached non-targeted two-gold theft")
		var presenter = app.get_node("LiveEnemyRoster")
		var badge = presenter._badges[fixture.source - 1]
		_check(badge.is_visible_in_tree() and badge.readable_text == "Steal 2 gold"
			and badge.target_position == 0 and badge.policy_cue.is_empty()
			and badge.icon_mode == "steal_gold" and badge.tooltip_text.contains("run wallet")
			and app.intent_label.text.contains("Steal 2 gold"), "mounted badge and label disclose theft before payment")
		# Remove the other living sources through real damage to isolate this action.
		for index in range(app.enemies.get_enemies().size()):
			if index + 1 != fixture.source:
				_check(app.enemies.apply_damage(index + 1, 999), "other source is truly slain")
		var heroes: Array = app.party.get_heroes()
		var cached: Array = app.enemy_attacks.duplicate(true)
		app.enemy_attacks = []
		var before := _snapshot(app)
		app._end_turn(app.end_turn_button)
		_check(_snapshot(app) == before and app.session_gold == gold, "stale mounted theft rejects without state/RNG/wallet changes")
		app.enemy_attacks = cached
		app.end_turn_button.pressed.emit()
		var balance: int = maxi(0, gold - 2)
		_check(app.session_gold == balance and app.round_flow.get_gold() == balance,
			"one mounted accepted End Turn publishes floored run wallet")
		before = _snapshot(app)
		app.end_turn_button.pressed.emit()
		_check(_snapshot(app) == before and app.session_gold == balance, "duplicate input cannot debit or advance anything twice")
		for index in range(3):
			_check(app.party.get_hero(index + 1).hp == heroes[index].hp, "isolated live theft never damages heroes")
		if gold == 9:
			var trace := [_snapshot(app), app.session_gold]
			if replay.is_empty():
				replay = trace
			else:
				_check(trace == replay, "real routed wallet and RNG replay with same seed")
		if gold == 5:
			for position in range(1, 4):
				_check(app.party.apply_damage(position, 999), "defeat witness really downs each hero")
			app._observe_battle_result()
			_check(app._battle_closed and app.battle_result.get_outcome() == CombatBattleResult.DEFEAT
				and app.session_gold == balance, "defeat preserves committed reduced wallet")
			app.free()
			await process_frame
			continue
		_check(app.enemies.apply_damage(fixture.source, 999), "finish genuine Fight after theft")
		app._observe_battle_result()
		_check(app._battle_closed and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
			and app._routed_reward_service() != null, "victory opens real onward reward service")
		var offering = app._routed_reward_service()
		if offering != null:
			var carried_gold: int = offering.read_state().gold if offering is RunMultiFightRewards else offering._starting_gold
			_check(carried_gold == balance, "subsequent run reward wallet reads reduced balance")
			var award: int = app.fight_reward_gold
			app.reward_buttons[3].pressed.emit()
			_check(app.session_gold == balance + award and app.fight_reward_claimed,
				"real reward settlement preserves theft and adds only earned gold")
			app.continue_button.pressed.emit()
			_check(app.route_view != null and app.route_view.is_visible_in_tree()
				and app.session_gold == balance + award, "onward run chooser preserves settled wallet")
		app.free()
		await process_frame


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_phase_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")


func _mounted_blind(app) -> void:
	_fixture_start(app)
	await process_frame
	var presenter = app.get_node("LiveEnemyRoster")
	_check(app.enemy_intents.is_bound() and app.enemies.get_enemy(1).hp > 0
		and app.enemy_intents._enemies == app.enemies
		and presenter.enemies == app.enemies and presenter._badges.size() == 2
		and presenter._admitted_ids.size() == 2
		and app.enemy_attacks == app.enemy_intents.get_intents()
		and app.enemy_attacks[0].get("type") == "attack",
		"mounted living attacker, identity-matched puppet and authentic bound attack")
	if presenter._badges.size() != 2 or app.enemy_attacks.is_empty():
		app.return_button.pressed.emit()
		await process_frame
		return
	var badge: LiveEnemyIntentBadge = presenter._badges[0]
	var action: Dictionary = app.enemy_attacks[0].duplicate(true)
	var source_id: String = app.enemies.get_enemy(1).id
	var puppet = presenter._puppets[CombatParty.PARTY_SIZE]
	_check(puppet.actor_id == source_id and presenter._admitted_ids[0] == source_id
		and action.get("enemy_position") == badge.source_position,
		"Blind preview uses the genuinely bound source and puppet")
	var ordinary := badge.readable_text
	_check(not badge.blind_miss and badge.amount == action.amount
		and badge.target_position == action.target_position and not ordinary.contains("MISS"),
		"unblinded mounted attack starts with its ordinary real forecast")
	# Remove opening protection with a real party operation so missed HP and Block
	# are observable separately from the following player-turn Block reset.
	_check(app.party.start_player_turn(), "real party clears initial Block before Blind witness")
	app.enemies._enemies[0].statuses = {"blind_next_attack": 1}
	var before_render := _snapshot(app)
	presenter._refresh()
	_check(_snapshot(app) == before_render, "Blind badge refresh does not spend turn, actors, deck or RNG")
	_check(badge.blind_miss and badge.readable_text == "BLIND · MISS"
		and badge.intent_type == "attack" and badge.amount == action.amount
		and badge.target_position == action.target_position
		and badge.tooltip_text.contains("entire next attempted attack")
		and badge.tooltip_text.contains(LiveEnemyIntentBadge.hero_target_label(action.target_position))
		and badge.tooltip_text.contains("No hero HP or Block")
		and badge.tooltip_text.contains("Without Blind:"),
		"mounted Blind source advertises entire miss with genuine attack/target only in hover: " + str([badge.blind_miss, badge.readable_text, badge.tooltip_text, presenter._admitted_ids, puppet.actor_id, app.enemy_intents._enemies == app.enemies, presenter._bound_unravel(app) != null, action]))
	_check(badge.size.x >= LiveEnemyIntentBadge.BADGE_WIDTH
		and badge.size.y == LiveEnemyIntentBadge.BADGE_HEIGHT
		and badge.caption_text_area().grow(0.5).encloses(badge.caption_text_rect())
		and badge.caption_rect().grow(0.5).encloses(badge.caption_text_rect())
		and badge.caption_font_size() >= LiveEnemyIntentBadge.CAPTION_MIN_FONT,
		"mounted sewn Blind MISS caption fits its original 192x28 patch: " + str([badge.size, badge.caption_text_area(), badge.caption_text_rect(), badge.caption_rect(), badge.caption_font_size()]))
	# A stale/rebound admitted source must never borrow the current enemy's Blind.
	# Refresh corrects a puppet's art ID automatically, so use the presenter's
	# battle-admission identity ledger to simulate the stale binding.
	presenter._admitted_ids[0] = "other_enemy"
	presenter._refresh()
	_check(not badge.blind_miss and not badge.readable_text.contains("MISS"),
		"stale admitted identity cannot borrow the real enemy's Blind")
	presenter._admitted_ids[0] = source_id
	presenter._refresh()
	_check(badge.blind_miss and _snapshot(app) == before_render,
		"restoring source admission identity restores view without model or RNG drift")
	var hp_before: Array = app.party.get_heroes().map(func(h): return h.hp)
	var block_before: Array = app.party.get_heroes().map(func(h): return h.block)
	var rng_before: int = app.run_rng.state
	_check(block_before == [0, 0, 0], "real Blind attempt begins with zero hero Block")
	app.end_turn_button.pressed.emit()
	_check(app.party.get_heroes().map(func(h): return h.hp) == hp_before
		and app.party.get_heroes().map(func(h): return h.block) == block_before
		and app.enemies.get_enemy(1).statuses == {} and app.enemy_intents._turn_index == 1,
		"actual legal End Turn consumes Blind once; attempted attack costs no HP or Block")
	await process_frame
	var after_resolution := _snapshot(app)
	presenter._refresh()
	_check(_snapshot(app) == after_resolution and app.run_rng.state == rng_before,
		"consumed Blind refresh cannot change actors, announcement, deck or seeded RNG")
	var next_action: Dictionary = app.enemy_intents.get_intents()[0]
	_check(next_action.get("type") == "attack" and not badge.blind_miss
		and badge.amount == next_action.amount and badge.target_position == next_action.target_position
		and badge.readable_text == ordinary and badge.tooltip_text.contains("damage aimed at")
		and not badge.tooltip_text.contains("Blind:"),
		"next unblinded live attack restores exact original amount, target and caption")
	# Malformed Blind is invalid for combat, but the view must also refuse a fake MISS.
	app.enemies._enemies[0].statuses = {"blind_next_attack": 2}
	var malformed := _snapshot(app)
	presenter._refresh()
	_check(not badge.blind_miss and badge.readable_text == ordinary
		and _snapshot(app) == malformed,
		"malformed two-stack Blind cannot create a false MISS or drift RNG")
	app.end_turn_button.pressed.emit()
	_check(_snapshot(app) == malformed and not app.end_turn_button.disabled,
		"mounted malformed Blind rejects without turn/RNG/actor mutation")
	app.enemies._enemies[0].statuses = {}
	_check(app.enemy_intents._turn_index == after_resolution[7],
		"malformed Blind never advanced cached schedule")
	presenter._refresh()
	_check(not badge.blind_miss and badge.readable_text == ordinary,
		"clearing malformed metadata retains the exact normal attack forecast")
	await process_frame
	app.return_button.pressed.emit()
	await process_frame


## AC1-AC3: a genuine mounted End Turn, not a detached phase stand-in,
## announces the Ram's two beats on the same real puppet and actor roster.
func _mounted_ram_charge(app) -> void:
	var catalog: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var starter: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("user://live_enemy_phase_guard.json"))
	_check(catalog is Array and starter is Array and starter.size() == 2,
		"AC1 live precondition: authentic Ram and pinned Guard catalogs load")
	if not catalog is Array or not starter is Array or starter.size() != 2:
		return
	var ram: Dictionary = {}
	for source in catalog:
		if source.get("id") == "spindle_ram":
			ram = source.duplicate(true)
	_check(ram.get("charge") == true
		and ram.get("intent", {}).get("actions", []).size() == 3
		and ram["intent"]["actions"][2].get("amount") == 8.0,
		"AC1 live precondition: genuine Ram authors Charge and attack 8")
	if ram.is_empty():
		return
	# Pin the *authentic* attack alternative (the other two are already
	# catalog-checked); the app, scheduler, CombatRoundFlow and HUD are real.
	ram["intent"]["actions"] = [ram["intent"]["actions"][2]]
	starter[0] = ram
	var fixture := "user://live_enemy_phase_ram.json"
	var file := FileAccess.open(fixture, FileAccess.WRITE)
	_check(file != null, "AC1 precondition: mounted fixture outside repo opens")
	if file == null:
		return
	file.store_string(JSON.stringify(starter))
	file.close()
	app.starter_enemies_path = fixture
	var traces: Array = []
	for run in range(2):
		app.run_seed = 39198
		_fixture_start(app)
		await process_frame
		var mounted: bool = app.deck != null and app.enemies != null \
			and app.party != null and app.enemy_intents != null and app.round_flow != null \
			and app.enemy_attacks.size() == 2 \
			and is_instance_valid(app.intent_label) \
			and is_instance_valid(app.end_turn_button)
		_check(mounted, "AC1 precondition: real seeded Start Run mounts two live actors and a hand")
		if not mounted:
			break
		var roster = app.get_node("LiveEnemyRoster")
		_check(app.enemies.get_enemy(1).get("id") == "spindle_ram"
			and app.enemies.get_enemy(2).get("id") == "ragling_guard"
			and roster.enemies == app.enemies and roster._badges.size() == 2
			and roster._admitted_ids[0] == "spindle_ram"
			and app.enemy_intents._enemies == app.enemies,
			"AC1 precondition: the HUD and bound scheduler use the genuine Ram at source 1")
		if roster._badges.size() < 2:
			app.return_button.pressed.emit()
			await process_frame
			break
		var badge: LiveEnemyIntentBadge = roster._badges[0]
		var start_rng: int = app.run_rng.state
		var oracle_rng := RandomNumberGenerator.new()
		oracle_rng.seed = app.run_seed
		var oracle_source: Array[String] = []
		oracle_source.assign(JSON.parse_string(
			FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
		var oracle_deck := CombatDeck.new(oracle_source, oracle_rng)
		_check(oracle_deck.start_turn() and oracle_rng.state == start_rng,
			"AC2 precondition: real seeded draw and independent deck oracle match at entry")
		_check(app.enemy_attacks[0].get("amount") == 0
			and app.enemy_attacks[0].get("target_position") == 1
			and app.enemy_attacks[0].get("enemy_position") == 1
			and app.intent_label.text.contains("Enemy 1 -> Hero 1 (Warden): 0 damage")
			and badge.amount == 0 and badge.source_position == 1
			and badge.charge_state == "wind_up"
			and badge.readable_text == "WIND UP: Front"
			and badge.tooltip_text.contains("deals 0 damage now and prepares a strike at floor(8 * 2.5) = 20 before status/Block mitigation")
			and badge.tooltip_text.contains("Hero 1 (front)")
			and not app.enemies.get_enemy(1).has("charge_pending"),
			"AC1: actual mounted Ram badge identifies WIND UP aimed at announced hero and hovers 0 now / 20 next")
		var pre_refresh_snapshot := _snapshot(app)
		roster._refresh()
		_check(_snapshot(app) == pre_refresh_snapshot
			and badge.readable_text == "WIND UP: Front"
			and badge.charge_state == "wind_up"
			and app.run_rng.state == start_rng,
			"AC1: view refresh preserves WIND UP presentation without state or RNG mutation")
		# Non-charge foe at seat 2 never shows WIND UP or CHARGE.
		var guard_badge: LiveEnemyIntentBadge = roster._badges[1]
		_check(guard_badge.charge_state == ""
			and not guard_badge.readable_text.contains("WIND UP")
			and not guard_badge.readable_text.contains("CHARGE"),
			"AC3: non-charge foe never falsely shows WIND UP or CHARGE")
		# Forged cached amount cannot bypass an unarmed wind-up on End Turn.
		app.enemy_attacks[0]["amount"] = 8
		var refused := _snapshot(app)
		app.end_turn_button.pressed.emit()
		_check(_snapshot(app) == refused
			and not app.enemies.get_enemy(1).has("charge_pending")
			and not app.end_turn_button.disabled,
			"AC3: mounted stale intent refuses End Turn without state or RNG publication")
		app.enemy_attacks = app.enemy_intents.get_intents()
		app._refresh_intents()
		roster._refresh()
		_check(badge.charge_state == "wind_up" and badge.readable_text == "WIND UP: Front",
			"AC1: restoring canonical announcement restores WIND UP badge")
		var hp: int = app.party.get_hero(1).get("hp")
		var guarded: int = app.party.get_hero(1).get("block")
		_check(hp == 40 and guarded == 6,
			"AC1 precondition: living Warden enters first beat with genuine opening Block")
		app.end_turn_button.pressed.emit()
		await process_frame
		_check(app.party.get_hero(1).get("hp") == hp
			and app.enemies.get_enemy(1).get("charge_pending") ==
				{"amount": 8, "target_position": 1}
			and app.enemy_attacks[0].get("amount") == 20
			and app.enemy_attacks[0].get("target_position") == 1
			and app.intent_label.text.contains("Enemy 1 -> Hero 1 (Warden): 20 damage")
			and badge.amount == 20
			and badge.charge_state == "strike"
			and badge.readable_text == "CHARGE 20: Front"
			and badge.tooltip_text.contains("2.5x base 8")
			and badge.tooltip_text.contains("Hero 1 (front)")
			and badge.tooltip_text.contains("Block/Weak/Exposed or redirects"),
			"AC2: actual End Turn commits wind-up, previews stored 20-damage strike with 2.5x hover")
		var pre_armed_refresh := _snapshot(app)
		roster._refresh()
		_check(_snapshot(app) == pre_armed_refresh
			and badge.readable_text == "CHARGE 20: Front"
			and badge.charge_state == "strike",
			"AC2: view refresh preserves CHARGE 20 presentation without model or RNG drift")
		var armed_rng: int = app.run_rng.state
		_check(oracle_deck.end_turn() and oracle_deck.start_turn()
			and oracle_rng.state == armed_rng,
			"AC2: zero-damage wind-up spends no RNG beyond genuine deck draw")
		app.end_turn_button.pressed.emit()
		await process_frame
		_check(app.party.get_hero(1).get("hp") == 20
			and app.party.get_hero(1).get("block") == 0
			and app.party.get_hero(2).get("hp") == 30
			and app.party.get_hero(3).get("hp") == 26
			and not app.enemies.get_enemy(1).has("charge_pending")
			and app.enemy_attacks[0].get("amount") == 0
			and app.enemy_attacks[0].get("target_position") == 1
			and badge.amount == 0
			and badge.charge_state == "wind_up"
			and badge.readable_text == "WIND UP: Front"
			and badge.tooltip_text.contains("deals 0 damage now and prepares a strike at floor(8 * 2.5) = 20 before status/Block mitigation"),
			"AC1/2: actual stored strike hits exactly 20 via live pipeline then resets to WIND UP")
		_check(oracle_deck.end_turn() and oracle_deck.start_turn()
			and app.run_rng.state == oracle_rng.state,
			"AC2: held strike and single-alternative Guard spend no RNG beyond deck draws")
		traces.append(_snapshot(app))
		app.return_button.pressed.emit()
		await process_frame
	_check(traces.size() == 2 and traces[0] == traces[1],
		"AC2: starting a fresh mounted fight resets Charge and replays same seed")
	# AC3: focused negative / precedence presentation checks
	var test_badge := LiveEnemyIntentBadge.new()
	test_badge.size = Vector2(LiveEnemyIntentBadge.BADGE_WIDTH, LiveEnemyIntentBadge.BADGE_HEIGHT)
	# 1. Compact policy ticket: CHARGE 20 and WIND UP produce compact captions with true target
	test_badge.show_intent({"type": "attack", "amount": 0, "target_position": 1}, false, false, "front", -1, {}, false,
		{"valid": true, "state": "wind_up", "base_amount": 8, "projected_damage": 20, "target_position": 1})
	_check(test_badge.readable_text == "WIND UP → 1" and test_badge.charge_state == "wind_up",
		"AC1: compact policy ticket produces WIND UP → 1")
	test_badge.show_intent({"type": "attack", "amount": 20, "target_position": 1}, false, false, "front", -1, {}, false,
		{"valid": true, "state": "strike", "base_amount": 8, "projected_damage": 20, "target_position": 1})
	_check(test_badge.readable_text == "CHARGE 20 → 1" and test_badge.charge_state == "strike",
		"AC2: compact policy ticket produces CHARGE 20 → 1")
	# 2. Slain source: SLAIN wins over charge context
	test_badge.show_intent({"type": "attack", "amount": 0, "target_position": 1}, true, false, "front", -1, {}, false,
		{"valid": true, "state": "wind_up", "base_amount": 8, "projected_damage": 20, "target_position": 1})
	_check(test_badge.readable_text == "SLAIN" and test_badge.charge_state == "" and test_badge.icon_mode == "slain",
		"AC3: slain source displays SLAIN and never shows WIND UP or CHARGE")
	# 3. Unravelled (skip pending): UNRAVELLED wins over charge context
	test_badge.show_intent({"type": "attack", "amount": 0, "target_position": 1}, false, true, "front", -1, {}, false,
		{"valid": true, "state": "wind_up", "base_amount": 8, "projected_damage": 20, "target_position": 1})
	_check(test_badge.readable_text == "UNRAVELLED" and test_badge.charge_state == "" and test_badge.icon_mode == "unravelled",
		"AC3: unravelled skip displays UNRAVELLED and never shows WIND UP or CHARGE")
	# 4. Blind unarmed charge wind-up: keep WIND UP caption and hover explaining Blind remains for later charged strike
	test_badge.show_intent({"type": "attack", "amount": 0, "target_position": 1}, false, false, "front", -1, {}, true,
		{"valid": true, "state": "wind_up", "base_amount": 8, "projected_damage": 20, "target_position": 1})
	_check(not test_badge.blind_miss and test_badge.readable_text == "WIND UP → 1"
		and test_badge.charge_state == "wind_up"
		and test_badge.tooltip_text.contains("deals 0 damage now")
		and test_badge.tooltip_text.contains("prepares a strike at floor(8 * 2.5) = 20")
		and test_badge.tooltip_text.contains("Blind remains for the later charged attack")
		and not test_badge.tooltip_text.contains("Blind: the entire next attempted attack")
		and not test_badge.tooltip_text.contains("Without Blind:"),
		"AC3: blind unarmed wind-up displays compact WIND UP and explains Blind remains for later strike")
	# 4a. Blind unarmed wind-up without policy ticket displays WIND UP: Front
	test_badge.show_intent({"type": "attack", "amount": 0, "target_position": 1}, false, false, "", -1, {}, true,
		{"valid": true, "state": "wind_up", "base_amount": 8, "projected_damage": 20, "target_position": 1})
	_check(not test_badge.blind_miss and test_badge.readable_text == "WIND UP: Front"
		and test_badge.charge_state == "wind_up"
		and test_badge.tooltip_text.contains("deals 0 damage now")
		and test_badge.tooltip_text.contains("Blind remains for the later charged attack"),
		"AC3: blind unarmed wind-up without policy ticket displays WIND UP: Front")
	# 4b. Blind armed strike: BLIND · MISS wins and explains the impending full miss
	test_badge.show_intent({"type": "attack", "amount": 20, "target_position": 1}, false, false, "front", -1, {}, true,
		{"valid": true, "state": "strike", "base_amount": 8, "projected_damage": 20, "target_position": 1})
	_check(test_badge.blind_miss and test_badge.readable_text == "BLIND · MISS"
		and test_badge.charge_state == "strike"
		and test_badge.tooltip_text.contains("Blind: the entire next attempted attack aimed at Hero 1 (front) will MISS")
		and test_badge.tooltip_text.contains("No hero HP or Block is lost to this attack")
		and test_badge.tooltip_text.contains("Without Blind: Charge strike: 20 damage (2.5x base 8)"),
		"AC3: blind armed strike displays BLIND · MISS with full strike miss hover")
	# 5. Non-attack action on charge foe retains ordinary cue
	var roster_script = load("res://scripts/live_enemy_roster.gd")
	var shove_action := {"type": "shove", "amount": 0, "target_position": 1, "direction": 1}
	_check(roster_script._charge_context(true, {"id": "spindle_ram", "charge": true, "position": 1, "intent": {"target": "front", "actions": [{"weight": 1.0, "action": {"type": "attack", "amount": 8}}]}}, shove_action).is_empty(),
		"AC3: charge foe shove returns empty charge context")
	test_badge.show_intent(shove_action, false, false, "front", -1, {}, false, {})
	_check(test_badge.readable_text == "Shove 1 back" and test_badge.charge_state == "",
		"AC3: shove retains ordinary presentation on charge foe")
	# 6. Mismatched pending state rejects fail-closed
	var ram_spec := {"id": "spindle_ram", "charge": true, "position": 1, "intent": {"target": "front", "actions": [{"weight": 1.0, "action": {"type": "attack", "amount": 8}}]}}
	var ram_wrong_amount: Dictionary = ram_spec.duplicate(true)
	ram_wrong_amount["charge_pending"] = {"amount": 999, "target_position": 1}
	_check(roster_script._charge_context(true, ram_wrong_amount, {"type": "attack", "amount": 20, "target_position": 1}).is_empty(),
		"AC3: mismatched pending amount rejects charge context")
	var ram_wrong_target: Dictionary = ram_spec.duplicate(true)
	ram_wrong_target["charge_pending"] = {"amount": 8, "target_position": 2}
	_check(roster_script._charge_context(true, ram_wrong_target, {"type": "attack", "amount": 20, "target_position": 1}).is_empty(),
		"AC3: mismatched pending target rejects charge context")
	_check(roster_script._charge_context(false, ram_spec, {"type": "attack", "amount": 0, "target_position": 1}).is_empty(),
		"AC3: untrusted source rejects charge context")
	# 7. Forged non-zero amount on unarmed charge foe returns empty charge context
	_check(roster_script._charge_context(true, ram_spec, {"type": "attack", "amount": 8, "target_position": 1}).is_empty(),
		"AC3: forged non-zero amount on unarmed charge foe returns empty charge context")
	test_badge.free()
	app.starter_enemies_path = "user://live_enemy_phase_guard.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))


## AC1-AC3 regression: verify mounted authentic 0-amount blinded Ram excludes Guard
## redirect while preserving WIND UP and Blind tooltip, verify ordinary non-Charge
## attack redirect, and verify armed 20-amount blinded strike excludes Guard redirect.
func _mounted_ram_guard_redirect(app) -> void:
	var catalog: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var starter: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(app.STARTER_ENEMIES_PATH))
	_check(catalog is Array and starter is Array and not starter.is_empty(),
		"guard redirect precondition: enemy catalogs load")
	if not catalog is Array or not starter is Array or starter.is_empty():
		return
	var ram: Dictionary = {}
	for source in catalog:
		if source.get("id") == "spindle_ram":
			ram = source.duplicate(true)
	_check(ram.get("charge") == true
		and ram.get("intent", {}).get("actions", []).size() == 3
		and ram["intent"]["actions"][2].get("amount") == 8.0,
		"guard redirect precondition: genuine Ram authors Charge and attack 8")
	if ram.is_empty():
		return
	ram["intent"]["actions"] = [ram["intent"]["actions"][2]]
	var ragling: Dictionary = {}
	for source in starter:
		if source.get("id") == "ragling":
			ragling = source.duplicate(true)
	_check(not ragling.is_empty(), "guard redirect precondition: ragling found")
	if ragling.is_empty():
		return
	var enemies_fixture: Array = [ram, ragling]
	var fixture_path := "user://live_enemy_phase_ram_guard.json"
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	_check(file != null, "guard redirect precondition: fixture file opens")
	if file == null:
		return
	file.store_string(JSON.stringify(enemies_fixture))
	file.close()
	app.starter_enemies_path = fixture_path
	app.run_seed = 39198
	_fixture_start(app)
	await process_frame
	var mounted: bool = app.deck != null and app.enemies != null \
		and app.party != null and app.enemy_intents != null and app.round_flow != null \
		and app.enemy_attacks.size() == 2
	_check(mounted, "guard redirect precondition: fight mounted with 2 enemies")
	if not mounted:
		app.starter_enemies_path = "user://live_enemy_phase_guard.json"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
		return
	var roster = app.get_node("LiveEnemyRoster")
	# Swap Warden to middle seat (hero 2) so an attack aimed at hero 1 is eligible for Guard redirect.
	var swap_preview: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
	_check(swap_preview.get("ok") == true, "guard redirect precondition: swap Warden to middle seat")
	if swap_preview.get("ok") == true:
		app.party._heroes.assign(swap_preview["heroes"])
		app._refresh_party()
	_check(app.party.get_hero(1).id == "seamstress" and app.party.get_hero(2).id == "warden",
		"guard redirect precondition: Warden is in seat 2 and Seamstress in seat 1")

	# Arm active Guard on reactions service
	if app.round_flow._reactions == null:
		app.round_flow._reactions = CombatWardenGuardReactions.new()
	app.round_flow._reactions.guarding = true
	_check(app.round_flow._reactions.is_guarding(), "guard redirect precondition: Guard is active")
	var redirect_preview: Dictionary = app.round_flow._reactions.preview_actual_recipient(app.party, 1)
	_check(redirect_preview.get("ok") == true and redirect_preview.get("eligible") == true \
		and redirect_preview.get("redirected") == true and redirect_preview.get("actual_target_position") == 2,
		"guard redirect precondition: attack aimed at hero 1 is eligible for redirect to Warden")

	# Give authentic Ram Blind token
	app.enemies._enemies[0].statuses = {"blind_next_attack": 1}

	var pre_refresh_snapshot := _snapshot(app)
	var pre_rng: int = app.run_rng.state
	roster._refresh()
	_check(_snapshot(app) == pre_refresh_snapshot and app.run_rng.state == pre_rng,
		"guard redirect: roster refresh does not mutate state or RNG")

	var ram_badge: LiveEnemyIntentBadge = roster._badges[0]
	var ragling_badge: LiveEnemyIntentBadge = roster._badges[1]

	# 1. Blinded Ram WIND UP: shows WIND UP, Blind preserved, NO Guard redirect line
	_check(ram_badge.charge_state == "wind_up"
		and not ram_badge.blind_miss
		and ram_badge.readable_text == "WIND UP: Front"
		and ram_badge.tooltip_text.contains("deals 0 damage now")
		and ram_badge.tooltip_text.contains("Blind remains for the later charged attack")
		and not ram_badge.tooltip_text.contains("Guard → Warden")
		and not ram_badge.tooltip_text.contains("redirected"),
		"AC3/Defect: blinded Ram wind-up displays WIND UP, preserves Blind, and excludes Guard redirect tooltip")

	# 2. Ordinary non-Charge attacker (Ragling): previews Guard redirect to Warden
	_check(ragling_badge.charge_state == ""
		and not ragling_badge.blind_miss
		and ragling_badge.target_position == 1
		and ragling_badge.tooltip_text.contains("Guard → Warden (hero 2): this announced attack is redirected from hero 1; normal Block/HP apply."),
		"Defect regression: ordinary non-Charge attack previews eligible Guard redirect to Warden")

	# 3. Advance turn: End Turn commits wind-up, retains Blind for charged strike
	app.end_turn_button.pressed.emit()
	await process_frame
	_check(app.enemies.get_enemy(1).get("charge_pending") == {"amount": 8, "target_position": 1}
		and app.enemies.get_enemy(1).get("statuses", {}).get("blind_next_attack") == 1
		and app.enemy_attacks[0].get("amount") == 20,
		"AC1/AC2: End Turn commits wind-up, retains Blind token and schedules 20 damage strike")

	# Re-arm Guard on the new player turn
	app.round_flow._reactions.guarding = true
	var armed_pre_refresh := _snapshot(app)
	var armed_rng: int = app.run_rng.state
	roster._refresh()
	_check(_snapshot(app) == armed_pre_refresh and app.run_rng.state == armed_rng,
		"guard redirect: armed blinded refresh does not mutate state or RNG")

	# 4. Armed 20-amount blinded strike: shows BLIND · MISS, hover explains full miss, NO Guard redirect line
	_check(ram_badge.amount == 20
		and ram_badge.charge_state == "strike"
		and ram_badge.blind_miss
		and ram_badge.readable_text == "BLIND · MISS"
		and ram_badge.tooltip_text.contains("Blind: the entire next attempted attack aimed at Hero 1 (front) will MISS")
		and ram_badge.tooltip_text.contains("Without Blind: Charge strike: 20 damage (2.5x base 8)")
		and not ram_badge.tooltip_text.contains("Guard → Warden")
		and not ram_badge.tooltip_text.contains("redirected"),
		"AC2/Defect: armed blinded strike shows BLIND · MISS with full miss hover and no Guard redirect")

	app.return_button.pressed.emit()
	await process_frame
	app.starter_enemies_path = "user://live_enemy_phase_guard.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
