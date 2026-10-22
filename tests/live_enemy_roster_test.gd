extends SceneTree

var failures: Array[String] = []
var checks := 0
const SOURCE := "res://data/enemies/starter_enemies.json"
const FIXTURE := "user://live_enemy_roster_invalid.json"
const ROSTER_ART := preload("res://scripts/live_enemy_roster.gd")
## Supplied owner art by authoritative ID; the view must never choose these by name or slot.
const IDLE_ART := {
	"warden": "res://assets/paper/heroes/warden.png",
	"seamstress": "res://assets/paper/heroes/seamstress.png",
	"tinker": "res://assets/paper/heroes/tinker.png",
	"ragling": "res://assets/paper/enemies/ragling.png",
	"ragling_guard": "res://assets/paper/enemies/ragling_guard.png",
	"fray_scavenger": "res://assets/paper/enemies/fray_scavenger.png",
	"button_guard": "res://assets/paper/enemies/button_guard.png",
	"spool_stalker": "res://assets/paper/enemies/spool_stalker.png",
	"seam_ripper": "res://assets/paper/enemies/seam_ripper.png",
	"needle_marshal": "res://assets/paper/enemies/needle_marshal.png",
	"spool_hexer": "res://assets/paper/enemies/spool_hexer.png",
	"patchwork_behemoth": "res://assets/paper/boss/patchwork_behemoth.png",
}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _input_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
		await process_frame


func _input_mouse(control: Control) -> void:
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
		await process_frame
		await process_frame


func _snapshot(app) -> Array:
	return [app.party.get_heroes(), app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.run_rng.state, app.enemy_intents.get_intents(), app.enemies.get_enemies()]


## Every mounted puppet must show the supplied idle art of the authoritative ID currently in its
## slot, keep the paired attack resource unused, and preserve proportional placement.
func _assert_actor_art(app, presenter) -> void:
	var paths: Array[String] = []
	for puppet in presenter._puppets:
		var definition: Dictionary = app.party.get_hero(puppet.slot) if puppet.facing > 0.0 \
			else presenter.enemies.get_enemy(puppet.slot)
		var actor_id: String = definition.get("id") if definition.get("id") is String else ""
		_check(not actor_id.is_empty() and puppet.actor_id == actor_id,
			"puppet binds the authoritative actor ID in its slot, never a name or slot number")
		if actor_id.is_empty() or not IDLE_ART.has(actor_id):
			continue
		var idle_path: String = IDLE_ART[actor_id]
		var attack_path: String = idle_path.trim_suffix(".png") + "_attack.png"
		var texture: Texture2D = puppet.current_texture()
		_check(texture != null and texture.resource_path == idle_path,
			"mounted actor renders its own supplied idle image: " + actor_id)
		_check(puppet.attack_texture != null and puppet.attack_texture.resource_path == attack_path,
			"mounted actor keeps its paired attack-pose resource for a committed future event")
		_check(texture != null and not paths.has(texture.resource_path),
			"actors never share another actor's image: " + actor_id)
		paths.append(texture.resource_path if texture != null else "")
		var rect: Rect2 = puppet.image_rect()
		_check(texture != null and rect.size.x > 0.0 and rect.size.y >= 40.0,
			"supplied art is readable at battle size: " + actor_id)
		_check(texture != null and is_equal_approx(rect.size.x / rect.size.y,
			float(texture.get_width()) / float(texture.get_height())),
			"supplied art keeps its own proportions: " + actor_id)
		_check(rect.position.x >= 0.0 and rect.position.y >= 0.0 \
			and rect.end.x <= puppet.size.x + 0.01 and rect.end.y <= puppet.size.y + 0.01,
			"supplied art stays inside its input-inert control: " + actor_id)
	# Resolver coverage for IDs that are not in this battle, including the distinct Guard Ragling.
	for actor_id in ["needle_marshal", "spool_hexer", "patchwork_behemoth", "ragling_guard"]:
		var resolved: Dictionary = ROSTER_ART.art_paths(actor_id)
		_check(resolved.get("idle") == IDLE_ART[actor_id]
			and resolved.get("attack") == IDLE_ART[actor_id].trim_suffix(".png") + "_attack.png",
			"authoritative ID resolver maps idle and attack paths: " + actor_id)
		var art: Dictionary = presenter.art_for(actor_id)
		_check(art.get("idle") is Texture2D and art.idle.resource_path == resolved.idle
			and art.get("attack") is Texture2D and art.attack.resource_path == resolved.attack,
			"resolved Elite/Boss art loads both poses: " + actor_id)
	_check(IDLE_ART["ragling"] != IDLE_ART["ragling_guard"],
		"Guard Ragling has its own supplied image, not the base ragling")
	var fabricated := "fabricated_unknown_actor"
	_check(ROSTER_ART.art_paths(fabricated).is_empty() and presenter.art_for(fabricated).is_empty(),
		"a fabricated actor ID resolves no art and stays on the drawn fallback")
	_check(ROSTER_ART._load_art_texture("res://assets/paper/enemies/fabricated_missing.png") == null
		and ROSTER_ART._load_art_texture("") == null,
		"missing or empty art paths load no texture and cannot crash presentation")



func _assert_badges(app, presenter, expected_target: int = -1) -> void:
	if not is_instance_valid(presenter.panel) or presenter.enemies == null:
		_check(false, "badge assertions require a mounted real battle")
		return
	var roster: Array[Dictionary] = presenter.enemies.get_enemies()
	var intents: Array[Dictionary] = app.enemy_intents.get_intents()
	var by_position := {}
	for action in intents:
		by_position[action["enemy_position"]] = action
	var mounted: Array[Node] = presenter.panel.find_children("EnemyIntent*", "Control", true, false)
	_check(mounted.size() == roster.size() and presenter._badges.size() == roster.size(),
		"exactly one mounted intent badge per source roster position")
	if mounted.size() != roster.size() or presenter._badges.size() != roster.size():
		return
	var meters: Array[CombatActorMeter] = []
	for candidate in app.find_children("*", "VBoxContainer", true, false):
		if candidate is CombatActorMeter:
			meters.append(candidate)
	_check(meters.size() == 5, "all three hero and two enemy HP/Block meters remain mounted")
	var positions: Array[int] = []
	var modes: Array[String] = []
	for badge in presenter._badges:
		_check(badge is LiveEnemyIntentBadge and badge in mounted and badge.is_visible_in_tree(),
			"live badge is the drawn Control mounted under the battle roster")
		var position: int = badge.source_position
		positions.append(position)
		_check(position >= 1 and position <= roster.size() and
			roster[position - 1].position == position, "badge source_position matches its enemy")
		_check(by_position.has(position), "authoritative scheduler supplies this enemy position")
		if not by_position.has(position):
			continue
		var announced: Dictionary = by_position[position]
		_check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"drawn badge and text never intercept pointer events")
		_check(not badge.readable_text.is_empty() and badge.get_theme_default_font() != null and
			badge.get_theme_default_font().get_string_size(badge.readable_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= badge.size.x - 64,
			"drawn readable intent fits within its badge")
		var rect: Rect2 = badge.get_global_rect()
		_check(rect.size.x >= 192 and rect.size.y >= 36 and
			Rect2(0, 0, 1280, 720).encloses(rect), "badge has visible area within the viewport")
		_check(not rect.intersects(app.end_turn_button.get_global_rect()) and
			not rect.intersects(app.return_button.get_global_rect()) and
			not rect.intersects(app.hand_view.get_global_rect()),
			"roster intent badge does not cover hand or battle controls")
		_check(rect.size.x >= 64 + badge.get_theme_default_font().get_string_size(badge.readable_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, "badge's drawn caption area has adequate width")
		for meter in meters:
			_check(not rect.intersects(meter.get_global_rect()), "intent badge does not cover HP/Block meter")
		if app.enemies.is_slain(position):
			_check(badge.icon_mode == "slain" and badge.readable_text == "SLAIN" and
				badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0,
				"slain enemy has muted SLAIN icon and no active announced action")
		else:
			var kind: String = announced["type"]
			var amount: int = announced["amount"]
			var target: int = announced.get("target_position", 0)
			var message := "ATK %d > H%d" % [amount, target] if kind == "attack" else "BLOCK +%d" % amount
			_check(badge.icon_mode == kind and badge.intent_type == kind and badge.amount == amount and
				badge.target_position == target and badge.readable_text == message,
				"badge mode, text, damage/Block and target equal authoritative copied intent")
			if position == 1 and expected_target != -1:
				_check(kind == "attack" and amount == 1 and target == expected_target and
					badge.readable_text == "ATK 1 > H%d" % expected_target,
					"ragling next announced target follows real End Turn scheduler")
			if position == 2:
				_check(kind == "block" and amount == 1 and target == 0 and
					badge.readable_text == "BLOCK +1",
					"living Guard always announces upcoming +1 Block, not accumulated Block")
		modes.append(badge.icon_mode)
	_check(positions == [1, 2], "two unique badges preserve authored enemy source positions")
	if not app.enemies.is_slain(1):
		_check("attack" in modes and "block" in modes and modes[0] != modes[1],
			"attack spear and Block shield use visibly distinct modes")
	var before: Array = _snapshot(app)
	presenter._refresh()
	_check(_snapshot(app) == before, "badge refresh does not mutate HP/Block, deck, energy, turn, intents or run RNG")
	seed(92741)
	var next_global: int = randi()
	seed(92741)
	presenter._refresh()
	_check(randi() == next_global, "badge refresh consumes no global RNG")


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
	var labels: Array[Label] = presenter._labels
	_check(labels.size() == presenter.enemies.get_enemies().size(), "every roster entry has original readable state label")
	_check(presenter.panel.find_children("*", "Label", true, false).size() == labels.size(),
		"drawn badges preserve the legacy two original state Labels")
	_check(not labels.is_empty(), "enemy text exists")
	if not labels.is_empty():
		_check(labels[0].is_visible_in_tree() and labels[0].text == "Enemy 1 - Ragling",
			"visible placeholder identifies ragling and exact HP/Block")
		var rect: Rect2 = labels[0].get_global_rect()
		_check(rect.size.x > 0 and rect.size.y > 0 and Rect2(0, 0, 1280, 720).encloses(rect),
			"enemy label fits target viewport")
	_check(labels.size() >= 2, "Guard label exists")
	if labels.size() >= 2:
		_check(labels[1].is_visible_in_tree() and labels[1].text == "Enemy 2 - Guard Ragling",
			"visible Guard placeholder identifies exact HP and Block")
		_check(Rect2(0, 0, 1280, 720).encloses(labels[1].get_global_rect()), "Guard fits target viewport")
	_assert_badges(app, presenter, 1)
	_check(not app.intent_label.visible and not app.intent_label.text.is_empty(), "redundant legacy sentence is hidden while authoritative source remains")
	_check(presenter._puppets.size() == 3 + presenter.enemies.get_enemies().size(), "one presenter puppet for every actual actor")
	for puppet in presenter._puppets:
		_check(is_instance_valid(puppet) and puppet.is_visible_in_tree() and puppet.mouse_filter == Control.MOUSE_FILTER_IGNORE and puppet.focus_mode == Control.FOCUS_NONE, "mounted puppet is visible and input inert")
		_check(puppet.facing == (1.0 if puppet.name.begins_with("Hero") else -1.0), "actor puppet faces inward")
	_assert_actor_art(app, presenter)
	_check(app.end_turn_button.is_visible_in_tree() and app.return_button.is_visible_in_tree(),
		"real battle actions stay visible")
	_check(Rect2(0, 0, 1280, 720).encloses(app.return_button.get_global_rect()), "return action fits viewport")
	_check(app.end_turn_button.focus_next == app.end_turn_button.get_path_to(app.return_button),
		"keyboard action navigation retained")
	_check(app.end_turn_button.focus_mode != Control.FOCUS_NONE and
		app.return_button.focus_mode != Control.FOCUS_NONE and
		app.end_turn_button.mouse_filter != Control.MOUSE_FILTER_IGNORE and
		app.return_button.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"keyboard and pointer controls still receive input")
	_geometry(app, presenter)


func _geometry(app, presenter) -> void:
	_check(is_instance_valid(presenter.battle_row), "horizontal battle wrapper exists")
	if not is_instance_valid(presenter.battle_row):
		return
	var left: Rect2 = app.hero_view.get_global_rect()
	var right: Rect2 = presenter.panel.get_global_rect()
	_check(app.hero_view.get_parent() == presenter.battle_row and
		presenter.panel.get_parent() == presenter.battle_row and
		presenter.battle_row.get_child_count() == 2,
		"same app-owned hero row and original enemy panel are the two sides")
	_check(left.end.x <= right.position.x and not left.intersects(right) and
		is_equal_approx(left.position.y, right.position.y), "heroes left and enemies right share one horizontal row")
	_check(app.hero_panels.size() == 3 and presenter._labels.size() == 2, "five original actor slots exist")
	var controls: Array[Control] = [app.hero_view, presenter.panel, app.hand_view,
		app.end_turn_button, app.return_button, app.pile_label]
	for index in range(app.hero_panels.size()):
		var slot: PanelContainer = app.hero_panels[index]
		_check(slot.get_parent() == app.hero_view and slot.get_index() == index and
			slot.get_child(0).text.begins_with("%d - %s" % [index + 1, app.party.get_hero(index + 1).name]),
			"hero slot retains authoritative ordered identity")
		controls.append(slot)
		_check(not slot.get_child(0).visible, "legacy hero HP/Block source is hidden, not duplicated")
	for label in presenter._labels:
		controls.append(label)
	for control in controls:
		var rect := control.get_global_rect()
		_check(control.is_visible_in_tree() and rect.size.x > 0 and rect.size.y > 0 and
			Rect2(0, 0, 1280, 720).encloses(rect), "bounded visible battle control: " + control.name)
		if control is Label:
			_check(control.get_minimum_size().x <= rect.size.x, "actor and intent text has readable width")
	for lower in [app.hand_view, app.end_turn_button, app.return_button]:
		_check(presenter.battle_row.get_global_rect().end.y <= lower.get_global_rect().position.y,
			"actor sides stay above usable hand and actions")


func _mouse_attack(app, reference, presenter) -> void:
	var chosen: Control
	var target := 0
	var card_id := ""
	for card in app.hand_view.get_children():
		var id: String = card.get_child(0).text
		var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, id)
		if preview.playable and preview.requires_selection and not preview.target_positions.is_empty():
			chosen = card
			target = preview.target_positions.back()
			card_id = id
			break
	_check(chosen != null and target > 0, "real seeded hand supplies a playable targeted attack")
	if chosen == null or target == 0:
		return
	var before := _snapshot(app)
	await _input_mouse(chosen)
	_check(_snapshot(app) == before, "mouse card selection alone changes no combat state")
	await _input_mouse(presenter._labels[target - 1])
	var result := CombatAttackCards.new().play_attack(reference.deck, reference.party, reference.enemies, card_id, target)
	_check(result.ok and _snapshot(app) != before, "mouse enemy selection commits a real attack")
	_check(_snapshot(app) == _snapshot(reference), "mouse attack preserves complete reference HP/Block, piles, energy and RNG")


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
		_fixture_start(app)
		_fixture_start(reference)
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
		var heroes = app.hero_view
		var hero_slots: Array = app.hero_panels.duplicate()
		var original_parent = presenter._hero_parent
		var old_row_id: int = presenter.battle_row.get_instance_id()
		var old_panel_id: int = presenter.panel.get_instance_id()
		presenter._clear()
		_check(is_instance_valid(heroes) and heroes.get_parent() == original_parent and
			app.hero_panels == hero_slots, "explicit clear restores same app-owned heroes and slots")
		presenter._sync_battle()
		await process_frame
		await process_frame
		_check(not is_instance_id_valid(old_row_id) and not is_instance_id_valid(old_panel_id),
			"clear/remount frees temporary wrapper and panel")
		_check(app.hero_view == heroes and app.hero_panels == hero_slots, "remount retains hero node identities")
		_geometry(app, presenter)
		var state_before_repair := _snapshot(app)
		presenter.panel.free()
		presenter._refresh()
		presenter._sync_battle()
		await process_frame
		await process_frame
		_check(app.hero_view == heroes and app.hero_panels == hero_slots and
			_snapshot(app) == state_before_repair, "destroyed enemy panel remount preserves app heroes and full combat state")
		_geometry(app, presenter)
		var roster_ref: WeakRef = weakref(presenter.enemies)
		var row_id: int = presenter.battle_row.get_instance_id()
		var panel_id: int = presenter.panel.get_instance_id() if is_instance_valid(presenter.panel) else 0
		var before := _snapshot(app)
		_fixture_start(app)
		await process_frame
		_check(presenter.enemies == roster_ref.get_ref() and is_instance_valid(presenter.panel) and
			presenter.panel.get_instance_id() == panel_id, "duplicate Start Run retains same roster and panel")
		_check(app.battle_view.find_children("EnemyRosterPanel", "PanelContainer", true, false).size() == 1,
			"exactly one presenter panel per battle")
		_check(presenter._badges.size() == 2, "duplicate Start Run cannot add intent badges")
		_check(presenter.battle_row.get_instance_id() == row_id and
			app.battle_view.find_children("BattleActorSides", "HBoxContainer", true, false).size() == 1,
			"duplicate Start retains exactly one horizontal wrapper")
		_check(_snapshot(app) == before, "duplicate Start Run preserves all gameplay state")
		var trace: Array = []
		for turn in range(12):
			_check(_snapshot(app) == _snapshot(reference), "presenter leaves hero/deck/energy/RNG trace intact")
			_check(presenter.enemies == app.enemies and app.enemies.get_enemies() == reference.enemies.get_enemies(),
				"observed roster matches battle without presenter")
			_check(app.enemies.get_enemy(1).hp == 12 and app.enemies.get_enemy(2).hp == 12
				and app.enemies.get_enemy(1).block == 0 and app.enemies.get_enemy(2).block == turn,
				"only Guard's announced Block changes the live roster")
			_assert_badges(app, presenter, turn % 3 + 1)
			trace.append([_snapshot(app), presenter.enemies.get_enemies() if presenter.enemies != null else []])
			_check(app.deck.try_spend_energy(2) and reference.deck.try_spend_energy(2), "real shared energy spend")
			if turn == 0:
				await _input_mouse(app.end_turn_button)
			elif turn == 1:
				app.end_turn_button.grab_focus()
				await _input_key(KEY_ENTER)
			else:
				app.end_turn_button.pressed.emit()
			reference.end_turn_button.pressed.emit()
			await process_frame
			_assert_badges(app, presenter, (turn + 1) % 3 + 1)
			_check(_snapshot(app) == _snapshot(reference),
				"real pointer/keyboard End Turn matches same exact reference state")
		await _mouse_attack(app, reference, presenter)
		_geometry(app, presenter)
		var announced_before_death: Array[Dictionary] = app.enemy_intents.get_intents()
		var guard_before_death: Dictionary = app.enemies.get_enemy(2)
		_check(app.enemies.apply_damage(1, 100), "real CombatEnemies.apply_damage slays only ragling")
		presenter._refresh()
		_check(app.enemies.is_slain(1) and not app.enemies.is_slain(2) and
			app.enemies.get_enemy(2) == guard_before_death and
			app.enemy_intents.get_intents() == announced_before_death,
			"slaying ragling leaves guard and the schedule intact")
		_assert_badges(app, presenter)
		_check(app.enemies.apply_damage(2, 100), "final enemy damage exercises terminal layout")
		await process_frame
		await process_frame
		_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY and
			app.reward_buttons.size() == 4, "terminal geometry uses real victory and reward controls")
		_geometry(app, presenter)
		_assert_badges(app, presenter)
		if session == 0:
			first_trace = trace
		else:
			_check(trace == first_trace, "fresh same-seed session reproduces roster and full gameplay trace")
		reference.return_button.pressed.emit()
		app.return_button.pressed.emit()
		_check(presenter.enemies == null and presenter.panel == null and roster_ref.get_ref() == null and
			presenter._badges.is_empty(), "Return immediately releases roster, panel and badges")
		await process_frame
		_check(not is_instance_id_valid(panel_id), "old panel freed")
		_check(not is_instance_id_valid(row_id) and not is_instance_valid(heroes) and
			presenter.battle_row == null, "Return frees old wrapper and app-owned battle with no orphan heroes")
		presenter._refresh()
		_check(presenter._badges.is_empty() and presenter.panel == null,
			"no-session refresh cannot resummon stale callbacks or badges")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "title and keyboard focus restored")
	await _invalid_sources(app, reference, presenter)
	# A valid multi-entry source proves the whole list is parsed, without fixing catalog totals.
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify([{"id": "first", "name": "First", "max_hp": 3, "art_path": "unused"},
		{"id": "second", "name": "Second", "max_hp": 7, "art_path": "unused"}]))
	file.close()
	app.starter_enemies_path = FIXTURE
	_fixture_start(app)
	await process_frame
	_check(presenter.enemies != null and presenter.enemies.get_enemy(2).get("id") == "second",
		"complete valid list creates later enemy")
	_check(is_instance_valid(presenter.panel) and presenter._labels.size() == 2 and
		presenter._badges.size() == 2 and
		presenter.panel.find_children("*", "Label", true, false).size() == 2,
		"multi-entry fixture mounts both original labels and both drawn intent badges")
	_check(presenter.enemies.get_enemy(1).get("id") == "first"
		and presenter.enemies.get_enemy(2).get("id") == "second",
		"fabricated IDs are the authoritative actors of this mounted fixture")
	var fallback: Array = presenter._puppets.slice(3)
	_check(fallback.size() == 2, "fabricated-ID battle mounts one puppet per enemy")
	for index in range(fallback.size()):
		var puppet = fallback[index]
		_check(puppet.actor_id == presenter.enemies.get_enemy(index + 1).get("id")
			and puppet.idle_texture == null and puppet.attack_texture == null
			and puppet.image_rect() == Rect2(),
			"an unknown mounted actor ID falls back to the drawn puppet without textures")
	_assert_badges(app, presenter, 1)
	app.return_button.pressed.emit()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	await process_frame
	app.starter_enemies_path = SOURCE
	await _typed_stage(app, presenter)
	app.free()
	reference.free()
	_finish()


func _typed_stage(app, presenter) -> void:
	var boot = root.get_node("LiveWebPlaytestBoot")
	_check(await boot.enter_preview(app, "battle"), "fixed-seed preview enters the real routed typed fight")
	await process_frame
	await process_frame
	_check(app.enemies != null and app.enemies.get_enemies().size() == 3,
		"seed-one route exercises three typed enemies, not the standalone fixture")
	if app.enemies == null or app.enemies.get_enemies().size() != 3:
		return
	var before := _snapshot(app)
	var meters = app.get_node("LiveCombatMeters").row
	_check(presenter._puppets.size() == 6 and presenter._labels.size() == 3
		and meters.get_child_count() == 6, "mounted typed path has every puppet, target and real meter")
	_assert_actor_art(app, presenter)
	var actions: Array = app.enemy_intents.get_intents()
	for index in range(3):
		var actor: Dictionary = app.enemies.get_enemy(index + 1)
		var badge = presenter._badges[index]
		var action: Dictionary = actions[index]
		_check(presenter._labels[index].text == "Enemy %d - %s" % [actor.position, actor.name]
			and badge.source_position == actor.position and badge.intent_type == action.type
			and badge.amount == action.amount and badge.target_position == action.get("target_position", 0),
			"typed identity and complete authoritative intent survive mounted presentation")
		_check(Rect2(0, 0, 1280, 720).encloses(presenter._labels[index].get_global_rect())
			and badge.get_theme_default_font().get_string_size(badge.readable_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= badge.size.x - 64,
			"real typed name and short intent are readable inside the stage")
	# Exercise every distinct symbol and exact destination on a real mounted canvas.
	var badge = presenter._badges[0]
	for action in [{"type": "attack", "amount": 7, "target_position": 3},
		{"type": "block", "amount": 4}, {"type": "buff", "amount": 5},
		{"type": "debuff", "status": "exposed", "amount": 2, "target_position": 1},
		{"type": "shove", "amount": 0, "direction": -1, "target_position": 2}]:
		var original: Dictionary = action.duplicate(true)
		badge.show_intent(action, false)
		_check(badge.icon_mode == action.type and badge.intent_type == action.type
			and badge.amount == action.amount and badge.target_position == action.get("target_position", 0)
			and action == original, "all intent symbols preserve exact copied kind, amount and destination")
		_check(badge.get_theme_default_font().get_string_size(badge.readable_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= badge.size.x - 64,
			"each intent caption fits the three-enemy stage")
	presenter._refresh()
	_check(_snapshot(app) == before, "typed repeated refresh and every badge kind preserve all models and RNG")
	_check(app.party.apply_damage(1, 999) and app.enemies.apply_damage(2, 999), "typed fallen rendering has real downed and slain actors")
	presenter._refresh()
	_check(presenter._puppets[0].fallen and presenter._puppets[4].fallen
		and presenter._badges[1].icon_mode == "slain", "typed hero and enemy puppets reflect actual fallen state")
	_assert_actor_art(app, presenter)
	app.return_button.pressed.emit()
	await process_frame
	_check(presenter._puppets.is_empty() and presenter._badges.is_empty() and presenter.battle_row == null,
		"routed Return clears every typed puppet and badge")


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
		_fixture_start(reference)
		app.start_button.grab_focus()
		_fixture_start(app)
		await process_frame
		await process_frame
		_check(app.deck == null and app.party == null and app.run_rng == null and app.enemies == null,
			"bad roster rejects every run object atomically")
		_check(presenter.enemies == null and presenter.panel == null and presenter._badges.is_empty() and
			app.battle_view == null and presenter.battle_row == null,
			"invalid complete source creates no partial roster, wrapper, panel or badges")
		presenter._refresh()
		_check(presenter._badges.is_empty() and presenter.panel == null,
			"failed Start has no stale cue callback")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "invalid roster retains actionable title")
		app._end_turn()
		_check(app.deck == null and app.party == null and app.enemies == null, "invalid roster End Turn remains inert")
		# Correcting the source permits a fresh start, with no leaked state from rejection.
		app.starter_enemies_path = SOURCE
		_fixture_start(app)
		await process_frame
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
		_check(presenter.enemies == null and presenter.panel == null and presenter._badges.is_empty(),
			"invalid battle teardown also clears all intent cues")
		await process_frame


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_roster_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
