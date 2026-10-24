extends "res://tests/live_rest_stitch_choice_test.gd"
## Earn three scraps and stitch through real controls, then draw the owned
## composite from the next routed Fight's actual deck. No manufactured IDs.
var _stale_card_input: Callable
var captured_forecast: Dictionary = {}
var forecast_before: Array = []


func _capture_forecast() -> void:
	if presenter.current_forecast.get("playable", false):
		_check(_complete_state() == forecast_before, "live forecast spends no cards energy passives or RNG before commit")
		captured_forecast = presenter.current_forecast.duplicate(true)
		_check(presenter.cue.text.contains("Projected"), "real cue displays current ordered forecast")


func _frames() -> void:
	# Two rendered headless frames settle deferred actions and container layout.
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	super._check(condition, message)
	if not condition:
		printerr(message)


func _panel(id: String):
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == id:
			return panel
	return null


## The real presenter must name both ledger halves, in order, on its detailed
## battle-hand face while keeping the shared cost, two-part tooltip and input.
func _stitched_face(id: String, pair: Array, metadata) -> void:
	var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
	_check(ledger.is_valid(), "held composite is backed by the real Rest ledger")
	if not ledger.is_valid():
		return
	var descriptor: Dictionary = ledger.get_snapshot().descriptors.get(id, {})
	_check(descriptor.get("half_ids", []) == pair and int(descriptor.get("cost", -1)) >= 0,
		"real ledger preserves authored half order and shared cost")
	var first: Dictionary = metadata.definition(str(pair[0]))
	var second: Dictionary = metadata.definition(str(pair[1]))
	var first_name: String = str(first.get("display_name", ""))
	var second_name: String = str(second.get("display_name", ""))
	_check(not first.is_empty() and not second.is_empty() and not first_name.is_empty()
		and not second_name.is_empty() and first.get("owner") != second.get("owner"),
		"both authored halves have names and different owners")
	var first_colour: Color = metadata._owner_color(str(first.get("owner", "")))
	var second_colour: Color = metadata._owner_color(str(second.get("owner", "")))
	_check(first_colour != second_colour and first_colour != metadata.INK and second_colour != metadata.INK,
		"each authored half keeps its own distinct owner colour")
	var panel = _panel(id)
	_check(panel != null and is_instance_valid(panel) and metadata._bindings.has(panel),
		"genuine composite panel is bound before any play")
	if panel == null or not is_instance_valid(panel) or not metadata._bindings.has(panel):
		return
	var facts: Dictionary = metadata.get_facts(panel)
	_check(facts.get("halves", []) == pair and facts.get("cost") == descriptor.get("cost"),
		"bound face facts carry the ledger's ordered halves and shared cost")
	var tooltip: String = panel.tooltip_text
	_check(tooltip.begins_with("1. " + first_name + ";") and tooltip.contains("\n2. " + second_name + ";"),
		"two-part tooltip names each authored half in resolution order")
	_check(tooltip.contains(metadata.base_effect_text(str(pair[0])))
		and tooltip.contains(metadata.base_effect_text(str(pair[1]))),
		"each tooltip part keeps that half's complete authored rules")
	# Each half keeps its own terse authored effect, in ledger order, and the
	# mounted composite summary shows first then second without a from/target row.
	var first_line: String = metadata.short_line(str(pair[0]))
	var second_line: String = metadata.short_line(str(pair[1]))
	_check(not first_line.is_empty() and not second_line.is_empty()
		and first_line != second_line,
		"each stitched half keeps a distinct terse effect: " + id)
	for line in [first_line, second_line]:
		_check(not line.contains("BASE") and not line.contains("Unknown"),
			"stitched half face line stays terse: " + id)
		for banned in ["From", "Target", "living", "pick 1", "front", "middle", "back"]:
			_check(not line.contains(banned),
				"stitched half face prints no '%s': %s" % [banned, id])
	_check(str(metadata.get_facts(panel).get("rules", "")) == "1. %s · 2. %s" % [first_line, second_line],
		"composite face summary keeps first then second authored effect: " + id)
	# The real battle hand keeps the detailed, noncompact face: both ordered halves
	# get the renderer's three-line geometry instead of the compact one-row fallback.
	var real_geometry: Dictionary = metadata.get_geometry(panel)
	var real_rows: Array = real_geometry.get("halves", [])
	_check(not bool(real_geometry.get("compact", true)) and panel.size.y >= 160.0,
		"real held stitched panel uses the detailed tall face")
	_check(is_equal_approx(panel.size.y, app.hand_view.custom_minimum_size.y),
		"held card height is the hand row's own authoritative height")
	_check(real_rows.size() == 2, "detailed face keeps one sewn region per authored half")
	if real_rows.size() == 2:
		var first_row: Rect2 = real_rows[0]
		var second_row: Rect2 = real_rows[1]
		var real_bounds := Rect2(Vector2.ZERO, panel.size)
		_check(first_row.size.y >= 30.0 and second_row.size.y >= 30.0,
			"both halves get the renderer's detailed row height, not a compact strip")
		_check(real_bounds.encloses(first_row) and real_bounds.encloses(second_row)
			and first_row.position.y < second_row.position.y,
			"both detailed stitched halves fit the real panel in ledger order")
	# The compact one-row fallback still exists for shorter mounted panels.
	var min_size: Vector2 = panel.custom_minimum_size
	var tall_height: float = panel.size.y
	var draws: int = int(metadata._bindings[panel]["draw_count"])
	panel.custom_minimum_size = Vector2(min_size.x, 96.0)
	await _frames()
	var geometry: Dictionary = metadata.get_geometry(panel)
	_check(panel.size.y < 120.0 and bool(geometry.get("compact", false)),
		"shorter mounted panel falls back to the compact battle-hand face")
	var rows: Array = geometry.get("halves", [])
	var bounds := Rect2(Vector2.ZERO, panel.size)
	_check(rows.size() == 2, "compact face reserves one sewn row per authored half")
	if rows.size() == 2:
		_check(rows[0].position.y < rows[1].position.y and rows[0].end.y <= rows[1].position.y
			and rows[1].end.y <= geometry["footer"].end.y + 0.01
			and rows[0].size.y >= 20.0 and bounds.encloses(rows[0]) and bounds.encloses(rows[1]),
			"both sewn rows fit the real face in first then second order")
	_check(metadata.get_facts(panel).get("halves", []) == pair, "compact face keeps the ledger half order")
	var binding: Dictionary = metadata._bindings[panel]
	_check(binding["id"] == id and panel.draw.is_connected(binding["draw"])
		and panel.draw.get_connections().size() == 1, "compact face keeps the single draw callback")
	_check(int(binding["draw_count"]) > draws, "real CanvasItem actually redrew the compact face")
	_check(panel.gui_input.get_connections().size() == 1 and not panel.get_child(0).visible,
		"compact face keeps one gameplay handler and the hidden identity")
	panel.custom_minimum_size = min_size
	await _frames()
	_check(is_equal_approx(panel.size.y, tall_height) and not bool(metadata.get_geometry(panel).get("compact", true)),
		"real hand layout restores its tall face after the compact check")


## Faces and tooltips take each half's authored catalog name, so a Rest-upgraded
## half keeps its "+" instead of degrading to a base name or a raw ID.
func _authored_upgrade_names() -> void:
	var metadata = app.get_node("LiveSupportHand")._metadata
	var upgraded: Dictionary = metadata.definition("warden_strike_plus")
	_check(upgraded.get("display_name") == "Strike+" and metadata.base_effect_text("warden_strike_plus").begins_with("Strike+; Warden; 1 energy"),
		"authored '+' upgrade half keeps its authored name and cost")
	var deck: Array[String] = ["warden_strike_plus", "seamstress_prick", "tinker_pop_shot"]
	var ledger := RunRestStitchCards.new(deck, {}, 3, 1)
	_check(ledger.is_valid(), "authored upgraded-half fixture is a valid Rest ledger")
	if not ledger.is_valid():
		return
	var made := ledger.choose_stitch(0, 1, ledger.get_snapshot())
	var made_descriptor: Dictionary = made.get("descriptor", {})
	_check(bool(made.get("ok", false))
		and made_descriptor.get("half_ids", []) == ["warden_strike_plus", "seamstress_prick"],
		"real stitched ledger preserves an upgraded first half")
	if not bool(made.get("ok", false)):
		return
	var tooltip: String = metadata.stitched_tooltip(made_descriptor.get("half_ids", []))
	_check(tooltip.begins_with("1. Strike+; Warden; 1 energy") and tooltip.contains("\n2. Prick; Seamstress; 1 energy"),
		"two-part stitched tooltip keeps upgraded and base half names in order")
	_check(tooltip.contains("BASE deal 7 damage") and tooltip.contains("BASE deal 3 damage")
		and not tooltip.contains("BASE deal 6 damage"), "stitched tooltip states each half's own authored effect")
	# The upgraded half keeps its own terse face line beside the base half.
	_check(metadata.short_line("warden_strike_plus") == "7 dmg"
		and metadata.short_line("warden_strike") == "6 dmg"
		and metadata.short_line("seamstress_prick") == "3 dmg · Bleed 3",
		"stitched halves keep their own terse authored amounts")
	var made_pair: Array = made_descriptor.get("half_ids", [])
	_check(made_pair.size() == 2
		and metadata.short_line(str(made_pair[0])) == "7 dmg"
		and metadata.short_line(str(made_pair[1])) == "3 dmg · Bleed 3",
		"real stitched pair keeps both terse half effects in order")


func _hover(control: Control) -> void:
	for point in [Vector2(2, 2), control.get_global_rect().get_center()]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		await _frames()


func _snapshot() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index, app.run_rng.state, app.battle_result.get_outcome()]


func _return() -> void:
	await _click(app.return_button)
	_check(app.deck == null and presenter.cue == null and presenter._bindings.is_empty(), "Return clears live selection")


func _hand_fixture() -> Dictionary:
	for value in range(1, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for elite in map.get_node(fight).outgoing:
				if map.get_node(elite).type != "Elite":
					continue
				for rest in map.get_node(elite).outgoing:
					if map.get_node(rest).type != "Rest":
						continue
					for next in map.get_node(rest).outgoing:
						if map.get_node(next).type != "Fight":
							continue
						map.choose_node(fight)
						var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
						if entry.get("encounter_id") == "starter_attacks":
							return {"seed": value, "fight": fight, "elite": [elite], "rest": [rest], "next": next}
						map.undo_choice(fight, [])
	return {}


func _earn(fixture: Dictionary, pair: Array, keyboard: bool) -> String:
	if not await _routed_win(fixture, false):
		return ""
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	await _visit_path(fixture.elite.slice(0, -1), keyboard)
	await _click(_route_action(fixture.elite.back()))
	_check(app.enemies != null and app.run_map.get_current_node_id() == fixture.elite.back(), "actual Elite earns stitch purse")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999), "defeat mounted Elite")
	app._observe_battle_result()
	await _frames()
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	await _visit_path(fixture.rest.slice(0, -1), keyboard)
	await _click(_route_action(fixture.rest.back()))
	_check(app.run_scraps == 3 and app.rest_stitch != null and app.rest_stitch.is_valid(), "earned three scraps at connected Rest")
	await _select_stitch(app.rest_stitch_first, app.run_deck.find(pair[0]), keyboard)
	await _select_stitch(app.rest_stitch_second, app.run_deck.find(pair[1]), keyboard)
	await _click(app.rest_stitch_button)
	_check(app.run_scraps == 0 and app.run_stitch_descriptors.size() == 1, "real Rest action allocates composite")
	if app.run_stitch_descriptors.is_empty():
		return ""
	var id: String = app.run_stitch_descriptors.keys()[0]
	_check(app.run_stitch_descriptors[id].half_ids == pair, "authentic ordered half IDs")
	await _click(app.rest_continue_button)
	await _click(_route_action(fixture.next))
	_check(app.deck != null and app.battle_result.can_continue(), "next connected Fight mounted")
	_check(app.deck.turn_active and (app.deck.hand.has(id) or app.deck.draw_pile.has(id)), "active next Fight contains earned composite")
	if not app.deck.turn_active or not (app.deck.hand.has(id) or app.deck.draw_pile.has(id)):
		return ""
	while not app.deck.hand.has(id) and not app.deck.draw_pile.is_empty():
		_check(app.deck.draw_extra(1) == 1, "draw actual owned composite")
	app._refresh_hand()
	await _frames()
	_check(_panel(id) != null and presenter._bindings.has(_panel(id)), "held ordered panel bound to production presenter")
	await _stitched_face(id, pair, app.get_node("LiveSupportHand")._metadata)
	if _stale_card_input.is_valid():
		var before := _complete_state()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		_stale_card_input.call(event)
		await _key(KEY_1)
		_check(_complete_state() == before, "retained freed panel callback rejects after restart")
	return id


func _return_race(id: String) -> void:
	await _click(app.end_turn_button)
	while app.deck.turn_active and not app.deck.hand.has(id) and (app.deck.draw_pile.has(id) or app.deck.discard_pile.has(id)):
		_check(app.deck.draw_extra(1) == 1, "real redraw for Return race")
	app._refresh_hand()
	await _frames()
	_check(app.deck.hand.has(id) and presenter._bindings.has(_panel(id)), "Return race has genuine held actionable composite")
	_stale_card_input = presenter._bindings[_panel(id)].input
	await _arm(id, true)
	await _key(KEY_1)
	var deck: CombatDeck = app.deck
	var party: CombatParty = app.party
	var enemies: CombatEnemies = app.enemies
	var rng: RandomNumberGenerator = app.run_rng
	var before := [deck.hand.duplicate(), deck.draw_pile.duplicate(), deck.discard_pile.duplicate(), deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state]
	var event := InputEventKey.new()
	event.keycode = KEY_1
	event.pressed = true
	root.push_input(event, true)
	_check(presenter._queued, "second target genuinely queued immediately before physical Return")
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = app.return_button.get_global_rect().get_center()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
	await _frames()
	_check(app.deck == null and presenter._choices.is_empty(), "Return invalidates pending composite")
	_check([deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state] == before, "Return race preserves all surviving old models and RNG")


func _deferred_rejections(id: String) -> void:
	for reason in ["receipt", "panel", "turn", "session", "target"]:
		await _arm(id, false)
		await _key(KEY_1)
		var event := InputEventKey.new()
		event.keycode = KEY_1
		event.pressed = true
		root.push_input(event, true)
		_check(presenter._queued, "real second target queued before deferred " + reason)
		_check(presenter.current_forecast.get("playable", false) and presenter.cue.text.contains("Projected"),
			"live ordered projection is displayed before the deferred commit: " + reason)
		var party: CombatParty = app.party
		var turn: int = app.enemy_intents._turn_index
		var foes: Array = app.enemies.get_enemies()
		match reason:
			"receipt": app.run_scraps = 1
			"panel": app._refresh_hand()
			"turn": app.enemy_intents._turn_index += 1
			"session": app.party = CombatParty.new(app.party.get_heroes())
			"target": app.enemies._enemies[0].id += "_replaced"
		var staged := _complete_state()
		await _frames()
		_check(_complete_state() == staged, "deferred " + reason + " revalidated without mutation")
		_check(presenter.cue != null and not presenter.cue.text.contains("Projected")
			and not presenter.current_forecast.get("playable", false) and presenter._armed == null
			and presenter._choices.is_empty() and presenter._receipt.is_empty(),
			"stale " + reason + " rejection retires the projection and armed cue")
		app.party = party
		app.enemy_intents._turn_index = turn
		app.enemies._enemies.assign(foes)
		app.run_scraps = 0
		app._refresh_hand()
		await _frames()
	await _arm(id, false)
	await _key(KEY_1)
	await _click(app.end_turn_button)
	_check(presenter._armed == null and presenter._choices.is_empty() and app.enemy_intents._turn_index > 0, "actual End Turn invalidates partial target choice")
	while app.deck.turn_active and not app.deck.hand.has(id) and (app.deck.draw_pile.has(id) or app.deck.discard_pile.has(id)):
		_check(app.deck.draw_extra(1) == 1, "redraw composite for legal retry after actual turn")
	app._refresh_hand()
	await _frames()


func _arm(id: String, keyboard: bool) -> void:
	if keyboard:
		for attempt in range(app.deck.hand.size() + 1):
			await _key(KEY_P)
			if presenter._armed == _panel(id):
				break
	else:
		await _click(_panel(id))
	_check(presenter._armed == _panel(id) or presenter.last_event.get("ok", false), "physical input selects composite")


func _pick(position: int, side: String, keyboard: bool) -> void:
	if keyboard:
		await _key(KEY_1 + position - 1)
	elif side == "ally":
		await _click(app.hero_panels[position - 1])
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])


func _complete_state() -> Array:
	return [_snapshot(), app._stitch_snapshot(), presenter._play._tinker._consumed,
		presenter._play._patches._consumed.duplicate(true) if presenter._play._patches != null else null]


func _rejections(id: String) -> void:
	# Each failure begins with a genuine, held, affordable, living-owner card.
	for reason in ["cancel", "rebuild", "energy", "downed", "misplaced", "forged", "unowned", "unheld", "turn", "receipt", "target"]:
		await _arm(id, false)
		await _key(KEY_1)
		_check(presenter._choices.size() == 1, "first required target captured before " + reason)
		var energy: int = app.deck.energy
		var heroes: Array = app.party.get_heroes()
		var enemies: Array = app.enemies.get_enemies()
		var registry: Dictionary = app.run_stitch_descriptors.duplicate(true)
		var hand: Array = app.deck.hand.duplicate()
		match reason:
			"cancel": await _key(KEY_ESCAPE)
			"rebuild": app._refresh_hand()
			"energy": app.deck.combat_state.energy = 0
			"downed": app.party._heroes[1].hp = 0
			"misplaced":
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
				_check(swap.ok, "legal owner displacement fixture")
				app.party._heroes.assign(swap.heroes)
			"forged": app.run_stitch_descriptors[id].cost = 0
			"unowned": app.run_stitch_descriptors.clear()
			"unheld": app.deck.hand.erase(id)
			"turn": app.deck.combat_state.player_turn_active = false
			"receipt": app.run_scraps += 1
			"target": app.enemies._enemies[0].position = 3
		var before := _complete_state()
		await _key(KEY_1)
		_check(_complete_state() == before, reason + " rejects without partial effects, spend, RNG or passive drift")
		if reason in ["forged", "unowned"]:
			var stale_panel = _panel(id)
			var stale_metadata = app.get_node("LiveSupportHand")._metadata
			_check(stale_panel != null and stale_metadata.get_facts(stale_panel).get("known", true) == false,
				"stale " + reason + " descriptor rebinds the held card to the honest unknown face")
			_check(stale_panel != null and stale_panel.tooltip_text == "Unknown card",
				"stale " + reason + " descriptor tooltip invents no rules")
		app.deck.combat_state.energy = energy
		app.deck.combat_state.player_turn_active = true
		app.party._heroes.assign(heroes)
		app.enemies._enemies.assign(enemies)
		app.run_stitch_descriptors = registry
		app.deck.hand.assign(hand)
		app.run_scraps = 0
		app._refresh_hand()
		await _frames()
	# First half kills the selected second target: only the transaction can
	# discover this later failure. It must roll back damage AND Bleed/passives.
	var enemies: Array = app.enemies.get_enemies()
	app.enemies._enemies[0].hp = 1
	await _arm(id, false)
	await _key(KEY_1)
	var before := _complete_state()
	await _key(KEY_1)
	_check(not presenter.last_event.get("ok", true) and _complete_state() == before, "second-half killed target atomically rolls back real first-half hit")
	app.enemies._enemies.assign(enemies)
	app._refresh_hand()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _hand_fixture()
	print("stitched route fixture: ", fixture)
	_check(not fixture.is_empty(), "seeded earned-stitch-to-Fight route exists")
	if fixture.is_empty():
		await _finish_hand()
		return
	_authored_upgrade_names()
	for pair in [["warden_shield_bash", "seamstress_prick"], ["seamstress_mend", "tinker_pop_shot"], ["seamstress_stitch_up", "tinker_scrap_bomb"], ["warden_brace", "tinker_tune_up"], ["tinker_pop_shot", "seamstress_prick"], ["tinker_scrap_bomb", "seamstress_mend"]]:
		var replay: Array = []
		for keyboard in [false, true]:
			print("stitched pair: ", pair, " keyboard=", keyboard)
			seed(105105)
			var global_next := randi()
			seed(105105)
			var id := await _earn(fixture, pair, keyboard)
			if id.is_empty():
				await _finish_hand()
				return
			if pair[0] == "warden_shield_bash":
				await _rejections(id)
				await _deferred_rejections(id)
				# Hemhook can shove the Warden out of the opening slot on the real End Turn.
				# A position-restricted stitch must then reject; restore a legal adjacent
				# party ordering for the subsequent complete two-half transaction oracle.
				if app.party.get_hero(1).get("id") != "warden":
					var displaced: Array[Dictionary] = app.party.get_heroes()
					var displaced_ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
					var displaced_preview := CombatStitchedTargetPreview.new().get_preview(displaced_ledger, app._stitch_snapshot(), app.deck, app.party, app.enemies, id)
					_check(not displaced_preview.playable, "authored enemy shove makes the front-owner stitch unplayable")
					var restore := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
					_check(restore.ok and displaced[0].id == "seamstress" and displaced[1].id == "warden", "real enemy shove has two living adjacent heroes that may legally swap back")
					if restore.ok:
						app.party._heroes.assign(restore.heroes)
						app._refresh_party()
						await _frames()
						_check(app.party.get_hero(1).id == "warden" and app.party.get_hero(2).id == "seamstress" and app.party.get_hero(1).hp == displaced[1].hp and app.party.get_hero(2).hp == displaced[0].hp, "restoring legal positions retains each displaced hero's HP")
			_check(app.party.apply_damage(1, 7), "healing has real missing HP")
			app._refresh_party()
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.gain_block(enemy.position, 20), "blocked enemies survive ordered hits")
			if pair in [["tinker_pop_shot", "seamstress_prick"], ["seamstress_mend", "tinker_pop_shot"]]:
				while not app.deck.hand.has("tinker_pop_shot") and not app.deck.draw_pile.is_empty():
					_check(app.deck.draw_extra(1) == 1, "real draw of surviving ordinary Tinker copy")
				app._refresh_hand()
				await _frames()
				_check(app.deck.hand.has("tinker_pop_shot"), "shared passive test has real held ordinary attack")
			var rng := RandomNumberGenerator.new()
			rng.state = app.run_rng.state
			var deck := CombatDeck.new([], rng)
			deck.hand.assign(app.deck.hand)
			deck.draw_pile.assign(app.deck.draw_pile)
			deck.discard_pile.assign(app.deck.discard_pile)
			deck.combat_state.energy = app.deck.energy
			deck.combat_state.player_turn_active = true
			var party := CombatParty.new(app.party.get_heroes())
			party._heroes = app.party.get_heroes()
			var enemies := CombatEnemies.new(app.enemies.get_enemies())
			enemies._enemies = app.enemies.get_enemies()
			var attacks := CombatAttackCards.new()
			attacks.start_player_turn()
			var shared_service = presenter._play
			if pair[0] == "tinker_pop_shot":
				var ordinary := attacks.play_attack(deck, party, enemies, "tinker_pop_shot", 1)
				await _click(_panel("tinker_pop_shot"))
				await _key(KEY_1)
				_check(presenter.last_event == ordinary and ordinary.hits[0].damage == 8, "ordinary attack first consumes shared Tinker bonus")
				await _arm(id, false)
				await _key(KEY_1)
				var old_party: CombatParty = app.party
				var old_result: CombatBattleResult = app.battle_result
				app.party = CombatParty.new(app.party.get_heroes())
				app.battle_result = CombatBattleResult.new(app.party, app.enemies)
				await _frames()
				_check(presenter._armed == null and presenter._choices.is_empty() and presenter._play == shared_service and presenter._play._tinker._consumed, "session change cancels pending choices without resetting consumed passive")
				app.party = old_party
				app.battle_result = old_result
				await _frames()
			var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
			var preview := CombatStitchedTargetPreview.new().get_preview(ledger, app._stitch_snapshot(), app.deck, app.party, app.enemies, id)
			_check(preview.playable and preview.halves.size() == 2, "genuine descriptor has two legal half shapes")
			if not preview.playable:
				await _finish_hand()
				return
			var targets: Array[int] = []
			for half in preview.halves:
				targets.append((half.target_positions.back() if targets.size() == 1 else half.target_positions[0]) if half.requires_selection else 0)
			var expected := CombatStitchedCards.new(attacks).play_stitched(deck, party, enemies, ledger, id, targets[0], targets[1])
			_check(expected.ok, "independent scene-free transaction succeeds")
			var metadata = app.get_node("LiveSupportHand")._metadata
			var facts: Dictionary = metadata.get_facts(_panel(id))
			_check(facts.get("halves", []) == pair and facts.cost == preview.cost and not _panel(id).get_child(0).visible, "mounted cream composite has descriptor-backed ordered halves and hidden identity")
			await _hover(_panel(id))
			_check(_panel(id).get_child(0).text == id and presenter.cue.text.contains("%d energy" % preview.cost)
				and presenter.cue.text.begins_with(catalog.get_definition(pair[0]).display_name + " / " + catalog.get_definition(pair[1]).display_name), "unchanged ID label and ordered names/cost in actual cue")
			_check(Rect2(0, 0, 1280, 720).encloses(presenter.cue.get_global_rect()), "stitched cue fits mounted viewport")
			for index in range(2):
				var half: Dictionary = preview.halves[index]
				var legal := str(half.target_positions) if half.requires_selection else "automatic (0), slots " + str(half.affected_positions)
				_check(presenter.cue.text.contains("%d: %s %s" % [index + 1, half.side, legal]), "cue exposes each exact legal per-half target shape")
			forecast_before = _complete_state()
			captured_forecast = {}
			presenter.forecast_updated.connect(_capture_forecast)
			await _arm(id, keyboard)
			for index in range(2):
				if preview.halves[index].requires_selection:
					await _pick(targets[index], preview.halves[index].side, keyboard)
			if keyboard and targets == [0, 0]:
				await _key(KEY_SPACE)
			presenter.forecast_updated.disconnect(_capture_forecast)
			_check(captured_forecast.get("playable", false) and captured_forecast.get("halves", []) == expected.halves, "routed live forecast predicts exact ordered committed effects")
			if captured_forecast.get("playable", false):
				var projected: Dictionary = captured_forecast.projected
				_check([projected.hand, projected.draw_pile, projected.discard_pile, projected.energy, projected.heroes, projected.enemies, projected.rng_state, projected.tinker_consumed] == [app.deck.hand, app.deck.draw_pile, app.deck.discard_pile, app.deck.energy, app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state, presenter._play._tinker._consumed], "live chosen-target projection equals complete actual commit including passive and RNG")
			_check(presenter.last_event == expected, "physical composite event matches exact ordered oracle")
			_check([app.deck.hand, app.deck.draw_pile, app.deck.discard_pile, app.deck.energy, app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state]
				== [deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state], "complete HP/Block/Bleed/deck/energy/RNG transition equals oracle")
			_check(presenter._play._tinker._consumed == attacks._tinker._consumed, "same attack authority consumes exact Tinker bonus")
			_check(presenter._play == shared_service, "composite retains the ordinary attack service across hand rebuild")
			if pair[0] == "seamstress_mend":
				var ordinary := attacks.play_attack(deck, party, enemies, "tinker_pop_shot", 1)
				await _click(_panel("tinker_pop_shot"))
				await _key(KEY_1)
				_check(presenter.last_event == ordinary and ordinary.hits[0].damage == 5, "composite consumes bonus once before ordinary attack")
				_check([app.deck.hand, app.deck.discard_pile, app.deck.energy, app.enemies.get_enemies()] == [deck.hand, deck.discard_pile, deck.energy, enemies.get_enemies()], "mixed composite/ordinary exact state")
			for index in range(3):
				var hero: Dictionary = app.party.get_hero(index + 1)
				_check(app.hero_panels[index].get_child(0).text.contains("HP: %d/%d | Block: %d" % [hero.hp, hero.max_hp, hero.block]), "exact hero HP and Block refreshed")
			for enemy in app.enemies.get_enemies():
				var roster = app.get_node("LiveEnemyRoster")
				var tag: Label = roster._labels[enemy.position - 1]
				_check(tag.text == String(enemy.name),
					"exact enemy name tag agrees with resolved oracle")
				if enemy.hp == 0:
					_check(roster._badges[enemy.position - 1].icon_mode == "slain"
						and roster._badges[enemy.position - 1].readable_text == "SLAIN",
						"a slain enemy announces its death on the intent badge")
				var meter = app.get_node("LiveCombatMeters").row.get_child(2 + enemy.position)
				_check(meter.hp_text.is_visible_in_tree() and meter.hp_text.text == "%d/%d" % [enemy.hp, enemy.max_hp]
					and meter.block_badge.visible == (enemy.block > 0)
					and meter.block_text.text == ("%d" % enemy.block if enemy.block > 0 else ""),
					"exact visible enemy HP and Block display agrees with resolved oracle")
			var trace := [_snapshot(), presenter.last_event.duplicate(true), app._stitch_snapshot()]
			if replay.is_empty():
				replay = trace
			else:
				_check(trace == replay, "seeded mouse/keyboard full-state replay")
			if pair[0] == "warden_shield_bash":
				await _return_race(id)
			else:
				await _return()
			_check(randi() == global_next, "earned route and cast preserve global RNG")
	await _finish_hand()


func _finish_hand() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_stitched_hand_play_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
