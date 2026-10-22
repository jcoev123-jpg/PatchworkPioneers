extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _state(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(), app.deck.energy,
		app.deck.turn_active, app.run_rng.state, app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true),
		app.enemy_intents._turn_index, app.battle_result.get_outcome()]


func _meters(app) -> Array[CombatActorMeter]:
	var result: Array[CombatActorMeter] = []
	for node in app.find_children("*", "VBoxContainer", true, false):
		if node is CombatActorMeter:
			result.append(node)
	return result


func _incoming(app, position: int) -> String:
	var meters := _meters(app)
	if meters.size() < position or position < 1:
		return ""
	var label := meters[position - 1].get_node_or_null("Padding/Content/IncomingForecast") as Label
	return label.text if label != null else ""


func _visible(app) -> void:
	var meters := _meters(app)
	_check(meters.size() == 5, "exactly five real actor meters")
	if meters.size() != 5:
		return
	var actors: Array = app.party.get_heroes() + app.enemies.get_enemies()
	for index in range(5):
		var meter := meters[index]
		var actor: Dictionary = actors[index]
		var heading := "%d. %s" % [actor.position, actor.name]
		if actor.hp == 0:
			heading += " — DOWNED" if index < 3 else " — SLAIN"
		_check(meter.actor_heading.text == heading, "ordered exact actor heading %d" % index)
		_check(meter.hp_text.text == "HP: %d/%d" % [actor.hp, actor.max_hp]
			and meter.hp_bar.value == actor.hp and meter.hp_bar.max_value == actor.max_hp,
			"exact HP text and bar %d" % index)
		_check(meter.block_text.text == "Block: %d" % actor.block and meter.block_bar.value == actor.block
			and meter.block_bar.max_value == maxi(1, maxi(actor.max_hp, actor.block)), "exact Block %d" % index)
		var status := meter.get_node_or_null("Padding/Content/StatusText") as Label
		_check(status != null and status == meter.status_text,
			"mounted real actor has its persistent StatusText")
		if status != null:
			var active: Array[String] = []
			var statuses: Dictionary = actor.get("statuses", {})
			for name in ["bleed", "weak", "exposed"]:
				if statuses.get(name, 0) > 0:
					active.append("%s %d" % [name.capitalize(), statuses[name]])
			var expected_status := "Statuses: none" if active.is_empty() else "Statuses: " + " · ".join(active)
			_check(status.text == expected_status,
				"mounted status line retains exact authoritative counts")
			_check(status.get_parent() == meter.get_node("Padding/Content")
				and status.focus_mode == Control.FOCUS_NONE,
				"status line belongs to mounted meter, remains keyboard-inert")
		var modifier := meter.get_node_or_null("Padding/Content/ModifierExplanation") as Label
		_check(modifier != null and modifier == meter.modifier_explanation, "real actor has one modifier explanation")
		var expected_rules: Array[String] = []
		if actor.hp > 0:
			var mods: Dictionary = actor.get("statuses", {})
			if mods.get("weak", 0) > 0:
				expected_rules.append("Weak: -25% attack damage")
			if mods.get("exposed", 0) > 0:
				expected_rules.append("Exposed: +50% attack damage taken")
		if modifier != null:
			_check(modifier.text == "\n".join(expected_rules) and not modifier.visible
				and status.tooltip_text == "\n".join(expected_rules),
				"slot-local rules match only the living authoritative actor")
			_check(modifier.focus_mode == Control.FOCUS_NONE and modifier.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"modifier line cannot receive input")
			_check(meter.get_node("Padding/Content").find_children("ModifierExplanation", "Label", false, false).size() == 1,
				"one permanent modifier explanation per slot")
		var warning := meter.get_node_or_null("Padding/Content/BleedWarning") as Label
		_check(warning != null and warning == meter.bleed_warning,
			"mounted real actor has its single persistent BleedWarning")
		var expected_bleed := ""
		var tick := CombatStatuses.new().end_owner_turn(actor.hp, actor.block, actor.get("statuses", {}).duplicate(true))
		_check(tick["ok"] and tick["block"] == actor.block,
			"read-only pure owner tick accepts live actor without Block changes")
		if actor.hp > 0 and actor.get("statuses", {}).get("bleed", 0) > 0:
			expected_bleed = "Bleed next: -%d HP (bypasses Block)%s" % [
				tick["bleed_hp_loss"], " — LETHAL" if tick["hp"] == 0 else ""]
		if warning != null:
			_check(warning.text == expected_bleed and warning.visible == not expected_bleed.is_empty(),
				"live next-owner-turn Bleed warning matches pure rule or hides")
			_check(warning.focus_mode == Control.FOCUS_NONE
				and warning.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"live Bleed warning cannot receive keyboard or mouse input")
		_check(meter.get_node("Padding/Content").get_child_count() == (9 if index < 3 else 8)
			and meter.get_node("Padding/Content").find_children("ModifierExplanation", "Label", false, false).size() == 1
			and meter.get_node("Padding/Content").find_children("StatusText", "Label", false, false).size() == 1
			and meter.get_node("Padding/Content").find_children("BleedWarning", "Label", false, false).size() == 1,
			"one status, one Bleed warning, five original controls and hero-only forecast")
		var line := meter.get_node_or_null("Padding/Content/IncomingForecast") as Label
		_check((line != null) == (index < 3), "forecast exists on hero meters only, never enemy meters")
		if line != null:
			_check(line.get_parent() == meter.get_node("Padding/Content")
				and line.text != "" and line.focus_mode == Control.FOCUS_NONE,
				"hero forecast is an inert line inside its existing meter")
		var controls: Array[Control] = [meter, meter.actor_heading, meter.hp_text,
			meter.hp_bar, meter.block_text, meter.block_bar]
		if line != null:
			controls.append(line)
		if status != null:
			controls.append(status)
		if modifier != null and status != null:
			var host: Control = app.hero_panels[index] if index < 3 else app.get_node("LiveEnemyRoster")._labels[index - 3]
			_check(host.is_visible_in_tree() and host.tooltip_text == status.text + "\n" + modifier.text,
				"original actor control exposes exact status and modifier rules without duplicate stage text")
			if index >= 3:
				_check(host.mouse_filter == Control.MOUSE_FILTER_IGNORE and host.focus_mode == Control.FOCUS_NONE,
					"enemy target label stays pointer-inert so target selection is untouched")
			_check(meter.get_global_rect().encloses(status.get_global_rect()), "visible status counts fit the actor meter")
		if warning != null and warning.visible:
			controls.append(warning)
			_check(meter.get_global_rect().encloses(warning.get_global_rect())
				and warning.size.x >= 180 and warning.size.y >= 9,
				"Bleed text stays readable within compact actor card: %s %s" % [meter.name, warning.get_global_rect()])
			_check(not warning.get_global_rect().intersects(meter.block_bar.get_global_rect())
				and not warning.get_global_rect().intersects(meter.hp_bar.get_global_rect())
				and (line == null or not warning.get_global_rect().intersects(line.get_global_rect()))
				and (modifier == null or not modifier.visible or not warning.get_global_rect().intersects(modifier.get_global_rect())),
				"Bleed warning never covers bars or existing IncomingForecast")
		for control in controls:
			_check(control.is_visible_in_tree() and control.size.x > 0 and control.size.y > 0,
				"meter controls visibly mounted")
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
				"meter controls fit viewport: %s %s at %s" % [meter.name, control.name, control.get_global_rect()])
			if control == status:
				# The single status line is the rules cue: pointer-hoverable only
				# while it has rules, and never keyboard-focusable.
				_check(control.focus_mode == Control.FOCUS_NONE
					and control.mouse_filter == (Control.MOUSE_FILTER_STOP
						if not control.tooltip_text.is_empty() else Control.MOUSE_FILTER_IGNORE),
					"status rule cue is hoverable only with rules and keyboard-inert")
			else:
				_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE,
					"meters never intercept mouse or keyboard")
		for control in [app.hero_view, app.hand_view, app.end_turn_button, app.return_button]:
			_check(not meter.get_global_rect().intersects(control.get_global_rect()), "meters do not obstruct controls")
		for other in meters:
			if other != meter:
				_check(not meter.get_global_rect().intersects(other.get_global_rect()), "meter rectangles do not overlap")
	for control in [app.hero_view, app.hand_view, app.end_turn_button, app.return_button]:
		_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
			"existing battle controls fit viewport: %s at %s" % [control.name, control.get_global_rect()])
	_check(app.end_turn_button.focus_next == app.end_turn_button.get_path_to(app.return_button), "existing Tab cycle")


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames()


func _mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await _frames()


func _hover(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()


func _exercise_live_bleed(app, presenter) -> void:
	# Exercise real mounted services, not a test-only presenter or mutated reader copy.
	var before := _state(app)
	var original_heroes: Array = app.party.get_heroes()
	var original_enemies: Array = app.enemies.get_enemies()
	var meters := _meters(app)
	_check(meters.size() == 5 and app.party.get_hero(1)["block"] == 6
		and app.enemies.get_enemy(1)["hp"] > 2,
		"live Bleed precondition: five authoritative living slots, six Warden Block")
	if meters.size() != 5 or app.enemies.get_enemy(1)["hp"] <= 2:
		return
	var ids: Array[int] = []
	var warning_ids: Array[int] = []
	var modifier_ids: Array[int] = []
	for meter in meters:
		ids.append(meter.get_instance_id())
		warning_ids.append(meter.bleed_warning.get_instance_id())
		modifier_ids.append(meter.modifier_explanation.get_instance_id())
	for index in range(3):
		app.party._heroes[index]["statuses"] = [
			{"bleed": 3, "weak": 1, "exposed": 2},
			{"bleed": 2, "exposed": 1},
			{"bleed": 1}][index].duplicate(true)
	_check(app.enemies.apply_damage(1, app.enemies.get_enemy(1)["hp"] - 2)
		and app.enemies.apply_statuses({
			1: {"bleed": 3, "weak": 1, "exposed": 2},
			2: {"bleed": 2, "exposed": 1}}),
		"enemy low HP and mixed-status stacks applied through real enemy APIs")
	_check(app.party.get_hero(1)["statuses"]["bleed"] == 3
		and app.enemies.get_enemy(1)["hp"] == 2
		and app.enemies.get_enemy(1)["statuses"]["bleed"] == 3,
		"actual live Warden/enemy reader snapshots contain Bleed")
	presenter._sync_battle()
	await _frames()
	_visible(app)
	_check(meters[0].modifier_explanation.text == "Weak: -25% attack damage\nExposed: +50% attack damage taken"
		and meters[1].modifier_explanation.text == "Exposed: +50% attack damage taken"
		and meters[2].modifier_explanation.text.is_empty() and not meters[2].modifier_explanation.visible
		and meters[3].modifier_explanation.text == meters[0].modifier_explanation.text
		and meters[4].modifier_explanation.text == meters[1].modifier_explanation.text,
		"all five live status lines follow their own actors")
	# The enemy rules must be reachable from the mounted stage, not just stored
	# on a pointer-inert roster label: hover the actual visible status cue.
	for index in [3, 4]:
		var cue: Label = meters[index].status_text
		_check(cue.mouse_filter == Control.MOUSE_FILTER_STOP
			and cue.mouse_default_cursor_shape == Control.CURSOR_HELP
			and cue.focus_mode == Control.FOCUS_NONE,
			"enemy status cue accepts pointer hover while staying keyboard-inert")
		await _hover(cue)
		_check(root.gui_get_hovered_control() == cue,
			"real pointer hover reaches the visible enemy status line")
		_check(cue.tooltip_text == meters[index].modifier_explanation.text
			and not cue.tooltip_text.is_empty(),
			"hovered enemy status line exposes its exact explanation")
	_check(meters[3].status_text.tooltip_text == "Weak: -25% attack damage\nExposed: +50% attack damage taken"
		and meters[4].status_text.tooltip_text == "Exposed: +50% attack damage taken"
		and app.get_node("LiveEnemyRoster")._labels[0].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"enemy Weak and Exposed rules are exact and reachable without touching target labels")
	var before_swap := _state(app)
	var preview := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
	_check(preview["ok"] and preview["heroes"].size() == 3 and _state(app) == before_swap,
		"real adjacent living swap preview succeeds without mutation")
	if preview["ok"]:
		for index in range(3):
			app.party._heroes[index] = preview["heroes"][index].duplicate(true)
		presenter._sync_battle()
		await _frames()
		_visible(app)
		_check(app.party.get_hero(1)["id"] == "seamstress" and app.party.get_hero(2)["id"] == "warden"
			and meters[0].modifier_explanation.text == "Exposed: +50% attack damage taken"
			and meters[1].modifier_explanation.text == "Weak: -25% attack damage\nExposed: +50% attack damage taken",
			"modifier text tracks hero identity after legal adjacent position swap")
		var reverse := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
		_check(reverse["ok"], "legal reverse movement exists")
		if reverse["ok"]:
			for index in range(3):
				app.party._heroes[index] = reverse["heroes"][index].duplicate(true)
		presenter._sync_battle()
		await _frames()
		_visible(app)
		_check(_state(app) == before_swap, "reverse movement restores exact state and RNG")
	_check(meters[0].bleed_warning.text == "Bleed next: -3 HP (bypasses Block)"
		and meters[0].block_text.text == "Block: 6"
		and meters[3].bleed_warning.text == "Bleed next: -2 HP (bypasses Block) — LETHAL"
		and meters[2].bleed_warning.text == "Bleed next: -1 HP (bypasses Block)"
		and meters[4].bleed_warning.text == "Bleed next: -2 HP (bypasses Block)",
		"all five live warnings, enemy lethal clamp and unaffected starting Block")
	var live_before_refresh := _state(app)
	var incoming_before := [_incoming(app, 1), _incoming(app, 2), _incoming(app, 3)]
	seed(95323)
	var expected_global := randi()
	seed(95323)
	for repeat in range(5):
		presenter._sync_battle()
		await process_frame
		for index in range(5):
			_check(meters[index].get_instance_id() == ids[index]
				and meters[index].bleed_warning.get_instance_id() == warning_ids[index]
				and meters[index].modifier_explanation.get_instance_id() == modifier_ids[index]
				and meters[index].get_node("Padding/Content").get_child_count() == (9 if index < 3 else 8),
				"read-only live refresh never allocates another warning or meter")
	_check(_state(app) == live_before_refresh and randi() == expected_global
		and incoming_before == [_incoming(app, 1), _incoming(app, 2), _incoming(app, 3)],
		"repeated Bleed forecasts preserve full state, seeded/global RNG and separate incoming labels")
	# Advance the authoritative owner-side snapshots using existing pure batch rules.
	# This tests the real mounted refresh after the owner-turn boundary without
	# adding a production status persistence API or changing round-flow ownership.
	var batch := CombatStatusTurnBatch.new()
	for turn in range(3):
		var hero_turn := batch.tick_side("heroes", app.party.get_heroes())
		var enemy_turn := batch.tick_side("enemies", app.enemies.get_enemies())
		_check(hero_turn["ok"] and enemy_turn["ok"]
			and hero_turn["actors"].size() == 3 and enemy_turn["actors"].size() == 2,
			"both real actor rosters have an authoritative owner-turn tick")
		if not hero_turn["ok"] or not enemy_turn["ok"]:
			break
		for index in range(3):
			app.party._heroes[index] = hero_turn["actors"][index].duplicate(true)
		for index in range(2):
			app.enemies._enemies[index] = enemy_turn["actors"][index].duplicate(true)
		var after_owner_turn := _state(app)
		presenter._sync_battle()
		_visible(app)
		_check(_state(app) == after_owner_turn,
			"post-owner-boundary visual refresh never applies a second Bleed tick")
		for index in range(5):
			_check(meters[index].get_instance_id() == ids[index]
				and meters[index].bleed_warning.get_instance_id() == warning_ids[index]
				and meters[index].modifier_explanation.get_instance_id() == modifier_ids[index],
				"owner-turn refresh retains every persistent warning identity")
		if turn == 0:
			_check(meters[0].modifier_explanation.text == "Exposed: +50% attack damage taken"
				and not meters[1].modifier_explanation.visible
				and not meters[3].modifier_explanation.visible
				and not meters[4].modifier_explanation.visible,
				"owner tick removes Weak and expired enemy stacks, keeps living Exposed")
			_check(app.enemies.is_slain(1) and not meters[3].bleed_warning.visible
				and meters[3].bleed_warning.text.is_empty()
				and meters[0].bleed_warning.text == "Bleed next: -2 HP (bypasses Block)"
				and not meters[2].bleed_warning.visible,
				"lethal enemy Bleed hides on slain slot; Bleed one expires after boundary")
		elif turn == 1:
			_check(not meters[0].modifier_explanation.visible and meters[0].modifier_explanation.text.is_empty(),
				"second owner tick expires Exposed explanation")
		elif turn == 2:
			for meter in meters:
				_check(not meter.modifier_explanation.visible and meter.modifier_explanation.text.is_empty(),
					"all weak and exposed descriptions are cleared after expiry")
				_check(not meter.bleed_warning.visible and meter.bleed_warning.text.is_empty(),
					"all expired Bleed stacks remove active warnings without removing labels")
	# Restore the identical authoritative session so the existing attack/replay
	# assertions still run on the authored opening state, not synthetic combat.
	for index in range(3):
		app.party._heroes[index] = original_heroes[index].duplicate(true)
	for index in range(2):
		app.enemies._enemies[index] = original_enemies[index].duplicate(true)
	presenter._sync_battle()
	_visible(app)
	_check(_state(app) == before and incoming_before != [],
		"live status probe restores complete authored combat, intents, deck and RNG")
	for index in range(5):
		_check(meters[index].bleed_warning.text.is_empty()
			and not meters[index].bleed_warning.visible
			and meters[index].modifier_explanation.text.is_empty()
			and not meters[index].modifier_explanation.visible,
			"clearing real statuses immediately hides every old warning")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await _frames()
	var presenter = app.get_node_or_null("LiveCombatMeters")
	_check(presenter != null and is_instance_valid(app.start_button), "mounted presenter and Start Run exist")
	if presenter == null or not is_instance_valid(app.start_button):
		app.free()
		_finish()
		return
	_check(app.title_view.is_visible_in_tree() and _meters(app).is_empty(), "title has no meters")
	app.starter_party_path = "user://missing_meter_party/invalid.json"
	_fixture_start(app)
	await _frames()
	_check(app.deck == null and app.party == null and app.enemies == null and presenter.row == null,
		"failed actual Start Run creates no partial meters or rules")
	app._end_turn()
	await _frames()
	_check(_meters(app).is_empty(), "inactive End Turn has no presentation")
	app.starter_party_path = app.STARTER_PARTY_PATH
	var replay: Array = []
	for session in range(2):
		_fixture_start(app)
		await _frames()
		_check(app.deck is CombatDeck and app.party is CombatParty and app.enemies is CombatEnemies
			and app.run_rng != null and is_instance_valid(app.battle_view), "real keyboard Start Run constructs battle")
		if app.deck == null or app.party == null or app.enemies == null:
			break
		_check(app.party.get_hero(1).name == "Warden" and app.party.get_hero(1).block == 6
			and app.enemies.get_enemy(2).name == "Guard Ragling", "authored five-actor preconditions")
		# Explicit failure probes ensure missing controls/wrong values cannot pass vacuously.
		if "--inject-missing-control" in OS.get_cmdline_user_args():
			presenter.row.get_child(0).free()
			_visible(app)
			app.free()
			_finish()
			return
		if "--inject-wrong-value" in OS.get_cmdline_user_args():
			presenter.row.get_child(0).hp_bar.value = 1
			_visible(app)
			app.free()
			_finish()
			return
		_visible(app)
		# Inject only into an existing mounted view: no invented live status persistence.
		var model_before_status := _state(app)
		var active_meters := _meters(app)
		_check(active_meters.size() == 5, "synthetic status probes have five real mounted meters")
		if active_meters.size() == 5:
			for index in [1, 3]:
				var side := "hero" if index == 1 else "enemy"
				var snapshot: Dictionary = app.party.get_hero(2) if index == 1 else app.enemies.get_enemy(1)
				var unmodified := snapshot.duplicate(true)
				snapshot["statuses"] = {"exposed": 2, "bleed": 3, "weak": 1}
				var snapshot_before := snapshot.duplicate(true)
				var meter := active_meters[index]
				var label_id := meter.status_text.get_instance_id()
				_check(meter.show_actor(snapshot, side)
					and meter.status_text.text == "Statuses: Bleed 3 · Weak 1 · Exposed 2",
					"mounted %s displays supplied synthetic status counters" % side)
				_check(snapshot == snapshot_before and not unmodified.has("statuses"),
					"synthetic %s statuses never alter source snapshot" % side)
				var displayed := meter.status_text.text
				_check(meter.show_actor(snapshot, side) and meter.status_text.text == displayed
					and meter.status_text.get_instance_id() == label_id,
					"duplicate mounted status update retains one stable label")
				var invalid := snapshot.duplicate(true)
				invalid["statuses"] = {"bleed": -1}
				_check(not meter.show_actor(invalid, side) and not meter.visible
					and meter.status_text.text.is_empty() and meter.bleed_warning.text.is_empty()
					and not meter.bleed_warning.visible,
					"invalid mounted status map clears prior positive stack")
				presenter._sync_battle()
				_check(meter.visible and meter.status_text.text == "Statuses: none"
					and meter.bleed_warning.text.is_empty() and not meter.bleed_warning.visible
					and meter.status_text.get_instance_id() == label_id,
					"next authoritative frame restores honest neutral live fallback")
			_check(_state(app) == model_before_status,
				"mounted synthetic/invalid/authoritative view refresh never mutates models or run RNG")
			_visible(app)
		_check(_incoming(app, 1) == "Incoming: 1 Block, 0 HP"
			and _incoming(app, 2) == "Incoming: none"
			and _incoming(app, 3) == "Incoming: none",
			"authored opening Warden absorbs Ragling one, Guard Block contributes zero")
		await _exercise_live_bleed(app, presenter)
		var initial := _state(app)
		if session == 0:
			replay = initial
		else:
			_check(initial == replay, "same-seed replay restores full initial state")
		var ids: Array[int] = []
		for meter in _meters(app):
			ids.append(meter.get_instance_id())
		_fixture_start(app)
		await _frames()
		for frame in range(8):
			presenter._sync_battle()
			await process_frame
		_check(_state(app) == initial and _meters(app).size() == 5, "duplicate frames/start never spend or duplicate")
		for index in range(_meters(app).size()):
			_check(_meters(app)[index].get_instance_id() == ids[index], "refresh reuses existing nodes")
		app.end_turn_button.disabled = true
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(_state(app) == initial, "disabled End Turn has no state changes")
		app.end_turn_button.disabled = false
		await _mouse(app.end_turn_button)
		_check(app.party.get_hero(1).hp == 40 and app.party.get_hero(1).block == 0
			and app.enemies.get_enemy(2).block == 1, "actual turn absorbs attack and executes second enemy Block")
		_visible(app)
		_check(_incoming(app, 1) == "Incoming: none"
			and _incoming(app, 2) == "Incoming: 0 Block, 1 HP",
			"real End Turn reveals next Ragling intent at fixed Seamstress position")
		# Direct valid model changes must refresh without app refresh callbacks.
		_check(app.party.gain_block(2, 7) and app.party.apply_damage(2, 3), "valid hero Block absorption")
		_check(app.party.apply_damage(3, 999) and app.enemies.gain_block(1, 8)
			and app.enemies.apply_damage(1, 3) and app.enemies.apply_damage(2, 1), "valid HP/Block, enemy Block absorption and zero HP mutations")
		var before := _state(app)
		await _frames()
		_visible(app)
		_check(_incoming(app, 2) == "Incoming: 1 Block, 0 HP",
			"real living attacker forecasts against changed Seamstress Block")
		_check(_state(app) == before, "display refresh preserves every model, energy, piles, intents and RNG")
		_check(app.party.apply_damage(2, 999) and app.party.is_downed(2),
			"live downed target remains at position two")
		await _frames()
		_visible(app)
		_check(_incoming(app, 2) == "DOWNED" and _incoming(app, 1) == "Incoming: none"
			and _incoming(app, 3) == "DOWNED",
			"downed target is not retargeted and never has a plausible incoming line")
		_check(app.enemies.apply_damage(1, 999) and app.enemies.is_slain(1),
			"real Ragling source is slain in retained position one")
		before = _state(app)
		await _frames()
		_visible(app)
		_check(_incoming(app, 1) == "Incoming: none" and _incoming(app, 2) == "DOWNED"
			and _incoming(app, 3) == "DOWNED",
			"slain attacker removes forecasts on surviving hero slots")
		_check(_state(app) == before, "slain-attacker refresh is entirely read-only")
		var valid_intents = app.enemy_intents
		app.enemy_intents = null
		presenter._sync_battle()
		_check(_incoming(app, 1) == "Incoming: unavailable"
			and _incoming(app, 3) == "DOWNED"
			and _incoming(app, 2) == "DOWNED",
			"missing intent interface fails closed without believable hero damage")
		app.enemy_intents = valid_intents
		presenter._sync_battle()
		# Each source identity change tears down the old presentation, even with identical values.
		for source in ["party", "enemies", "deck"]:
			var old_ids: Array[int] = []
			for meter in _meters(app):
				old_ids.append(meter.get_instance_id())
			if source == "party":
				app.party = CombatParty.new(app._load_party_definitions())
			elif source == "enemies":
				app.enemies = CombatEnemies.new(app._load_enemy_definitions())
			else:
				app.deck = CombatDeck.new(["warden_brace"], app.run_rng)
				app.deck.start_turn()
			await _frames()
			_visible(app)
			for id in old_ids:
				_check(not is_instance_id_valid(id), "source replacement frees stale meters: " + source)
		# Invalid/inactive sources clear synchronously; restoring a valid source rebuilds once.
		for source in ["party", "enemies", "deck", "hidden"]:
			var before_rejection := _state(app)
			var party: CombatParty = app.party
			var enemies: CombatEnemies = app.enemies
			var deck: CombatDeck = app.deck
			if source == "party":
				app.party = CombatParty.new([])
			elif source == "enemies":
				app.enemies = CombatEnemies.new([])
			elif source == "deck":
				app.deck = null
			else:
				app.battle_view.hide()
			presenter._sync_battle()
			_check(presenter.row == null and _meters(app).is_empty(), "invalid/inactive source clears meters: " + source)
			app.party = party
			app.enemies = enemies
			app.deck = deck
			app.battle_view.show()
			await _frames()
			_visible(app)
			_check(_state(app) == before_rejection, "rejection/rebuild leaves surviving models unchanged")
		var final_ids: Array[int] = []
		for meter in _meters(app):
			final_ids.append(meter.get_instance_id())
		await _mouse(app.return_button)
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
			and presenter.row == null and _meters(app).is_empty(), "real Return clears presentation and restores focus")
		for id in final_ids:
			_check(not is_instance_id_valid(id), "Return frees old meter")
	await _status_end_turns(app, presenter)
	app.free()
	await _frames()
	_finish()


func _status_end_turns(app, presenter) -> void:
	for scenario in ["weak", "exposed2", "exposed1", "combined", "bleed_slot", "lethal_bleed"]:
		var replay: Array = []
		for session in range(2):
			_fixture_start(app)
			await _frames()
			_check(app.party != null and app.round_flow != null and app.deck.turn_active
				and _meters(app).size() == 5, scenario + ": actual Start mounts authoritative active fight")
			if app.party == null or app.round_flow == null:
				return
			if scenario in ["weak", "combined"]:
				app.enemies._enemies[0]["statuses"] = {"weak": 1}
			if scenario in ["exposed2", "combined"]:
				app.party._heroes[0]["statuses"] = {"exposed": 2, "bleed": 2}
			if scenario == "exposed1":
				app.party._heroes[0]["statuses"] = {"exposed": 1}
			if scenario in ["bleed_slot", "lethal_bleed"]:
				for index in range(3 if scenario == "lethal_bleed" else 1):
					app.party._heroes[index]["hp"] = 2
					app.party._heroes[index]["statuses"] = {"bleed": 3}
			var before := _state(app)
			var heroes: Array = app.party.get_heroes()
			var prediction := CombatIncomingAttackPreview.new().forecast(heroes,
				app.enemies.get_enemies(), app.enemy_intents.get_intents())
			_check(prediction["ok"], scenario + ": live forecast valid")
			seed(49099)
			var expected_global := randi()
			seed(49099)
			for refresh in range(4):
				presenter._sync_battle()
				await _frames()
			_check(_state(app) == before and randi() == expected_global, scenario + ": live refresh preserves all state and both RNGs")
			_visible(app)
			if not prediction["ok"]:
				return
			for index in range(3):
				var predicted: Dictionary = prediction["heroes"][index]
				_check(_incoming(app, index + 1) == ("Incoming: none" if predicted["incoming"] == 0 else
					"Incoming: %d Block, %d HP" % [predicted["block_absorbed"], predicted["hp_lost"]]), scenario + ": mounted label displays attack-only forecast")
			if session == 0:
				await _mouse(app.end_turn_button)
			else:
				app.end_turn_button.grab_focus()
				await _key(KEY_SPACE)
			_check(not app.deck.turn_active if scenario == "lethal_bleed" else app.enemy_intents._turn_index == 1,
				scenario + ": actual mouse/keyboard End Turn processed")
			for index in range(3):
				var predicted: Dictionary = prediction["heroes"][index]
				var actual: Dictionary = app.party.get_hero(index + 1)
				var bleed_loss: int = mini(heroes[index]["hp"], heroes[index].get("statuses", {}).get("bleed", 0))
				_check(actual["hp"] == predicted["hp_remaining"]
					and heroes[index]["hp"] - actual["hp"] == predicted["hp_lost"] + bleed_loss,
					scenario + ": live committed HP equals attack plus separate Bleed")
				_check(actual["block"] == (predicted["block_remaining"] if scenario == "lethal_bleed" else 0)
					and predicted["block_remaining"] == heroes[index]["block"] - predicted["block_absorbed"],
					scenario + ": live Block matches absorption and new-turn reset")
			_check(app.enemies.get_enemy(2)["block"] == (0 if scenario == "lethal_bleed" else 1),
				scenario + ": owner defeat skips enemy Block as well as attacks")
			var after := _state(app)
			if session == 0:
				replay = after
			else:
				_check(after == replay, scenario + ": same-seed mouse/keyboard replay full state")
			await _mouse(app.return_button)
			_check(app.title_view.is_visible_in_tree() and presenter.row == null, scenario + ": actual Return clears session")


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_combat_meters_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
