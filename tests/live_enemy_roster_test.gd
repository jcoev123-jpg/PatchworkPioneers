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
		var drawn: Rect2 = Rect2(rect.position + badge.patch_rect().position, badge.patch_rect().size)
		_check(rect.size.x >= 192 and rect.size.y >= badge.custom_minimum_size.y - 0.01
			and Rect2(0, 0, 1280, 720).encloses(rect), "badge has visible area within the viewport")
		# Cycle 127: the control is inset inside the intent band, and the drawn patch is
		# complete below the viewport's upper edge, so no stitch is sliced off.
		_check(drawn.position.y >= 8.0 and drawn.end.y <= rect.end.y + 0.01
			and Rect2(0, 0, 1280, 720).encloses(drawn),
			"badge's drawn paper patch sits inside the viewport with a safe top margin")
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
	_check(labels.size() == presenter.enemies.get_enemies().size(), "every roster entry has one pinned name tag")
	_check(presenter.panel.find_children("*", "Label", true, false).size() == labels.size(),
		"pinned tags stay the only Labels under the enemy roster")
	_check(not labels.is_empty(), "enemy text exists")
	if not labels.is_empty():
		_check(labels[0].is_visible_in_tree() and labels[0].text == "Ragling",
			"pinned tag names the ragling without a long slot sentence")
		var rect: Rect2 = labels[0].get_global_rect()
		_check(rect.size.x > 0 and rect.size.y > 0 and Rect2(0, 0, 1280, 720).encloses(rect),
			"enemy name tag fits target viewport")
	_check(labels.size() >= 2, "Guard tag exists")
	if labels.size() >= 2:
		_check(labels[1].is_visible_in_tree() and labels[1].text == "Guard Ragling",
			"pinned tag names the Guard without a long slot sentence")
		_check(Rect2(0, 0, 1280, 720).encloses(labels[1].get_global_rect()), "Guard tag fits target viewport")
	_name_tags(app, presenter)
	_quilt(presenter)
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


## Small pinned name tags: the authoritative short name, input inert, below the art band
## and clear of the meter row and the intent badges.
func _name_tags(app, presenter) -> void:
	_check(presenter._hero_tags.size() == app.hero_panels.size(),
		"every mounted hero puppet carries one pinned name tag")
	var enemies: Array[Dictionary] = presenter.enemies.get_enemies()
	var troops: Array = presenter._puppets.slice(CombatParty.PARTY_SIZE)
	_check(troops.size() == enemies.size() and presenter._labels.size() == enemies.size(),
		"one pinned tag per mounted enemy puppet")
	for index in range(mini(troops.size(), presenter._labels.size())):
		var puppet = troops[index]
		var label: Label = presenter._labels[index]
		var name: String = enemies[index].get("name", "")
		_check(not name.is_empty() and label.text == name,
			"enemy tag is exactly the authoritative short name: " + name)
		_check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.focus_mode == Control.FOCUS_NONE,
			"enemy tag stays input inert while the actor keeps its own hit target")
		_check(label.get_global_rect().position.is_equal_approx(puppet.get_global_rect().position)
			and label.get_global_rect().size.is_equal_approx(puppet.get_global_rect().size),
			"enemy tag keeps the complete enemy hit rectangle")
		_check(puppet.tag_band().size.y > 0.0
			and puppet.tag_band().end.y <= puppet.size.y + 0.01
			and puppet.art_band().end.y <= puppet.tag_band().position.y + 0.01,
			"enemy art band stops above the pinned name tag")
		_check(puppet.get_theme_default_font().get_string_size(name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= puppet.size.x - 16.0,
			"short enemy tag fits its column without clipping: " + name)
		if index < presenter._badges.size():
			var tag_band_global := Rect2(puppet.get_global_rect().position + puppet.tag_band().position,
				puppet.tag_band().size)
			_check(not tag_band_global.intersects(presenter._badges[index].get_global_rect()),
				"enemy pinned tag band stays clear of its intent badge")
	for index in range(presenter._hero_tags.size()):
		var tag: Label = presenter._hero_tags[index]
		var puppet = presenter._puppets[index]
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(tag.is_visible_in_tree() and tag.text == hero.get("name", ""),
			"hero tag is exactly the authoritative short name")
		_check(tag.mouse_filter == Control.MOUSE_FILTER_IGNORE and tag.focus_mode == Control.FOCUS_NONE,
			"hero tag stays input inert")
		_check(tag.get_global_rect().size.y > 0.0
			and puppet.get_global_rect().encloses(tag.get_global_rect())
			and puppet.art_band().end.y <= puppet.tag_band().position.y + 0.01,
			"hero tag sits inside its actor below the stand-in art")
		_check(puppet.get_theme_default_font().get_string_size(hero.get("name", ""),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= puppet.size.x - 16.0,
			"short hero tag fits its column without clipping")
	var meters = app.get_node("LiveCombatMeters")
	if is_instance_valid(meters.row) and not presenter._labels.is_empty():
		_check(not presenter._labels[0].get_global_rect().intersects(meters.row.get_global_rect()),
			"pinned actor tags stay clear of the HP/Block/status meter row")


## One continuous quilt: axis-aligned strips sharing every edge, one stitched hem,
## and no tilted patch polygons left in the stage source.
func _quilt(presenter) -> void:
	var backdrop = presenter.backdrop
	_check(is_instance_valid(backdrop) and backdrop.name == "BattleStageBackdrop"
		and is_instance_valid(presenter._battle) and backdrop.get_parent() == presenter._battle,
		"one quilted stage backdrop owns the stage behind both lineups")
	if not is_instance_valid(backdrop):
		return
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE and backdrop.focus_mode == Control.FOCUS_NONE,
		"quilted stage never takes pointer or keyboard input")
	var global_row: Rect2 = presenter.battle_row.get_global_rect()
	var row: Rect2 = Rect2(global_row.position - backdrop.get_global_rect().position, global_row.size)
	var cloth: Rect2 = backdrop.quilt_cloth()
	var patches: Array[Rect2] = backdrop.quilt_rects()
	var columns: int = presenter.STAGE_QUILT_COLUMNS.size() - 1
	var rows: int = presenter.STAGE_QUILT_ROWS.size() - 1
	_check(columns >= 2 and rows >= 1 and patches.size() == columns * rows,
		"quilt is one continuous field of shared patches")
	_check(cloth.size.y > 0.0 and is_equal_approx(cloth.position.x, row.position.x)
		and is_equal_approx(cloth.size.x, row.size.x),
		"quilted cloth spans the whole actor row edge to edge")
	var covered := 0.0
	for index in range(patches.size()):
		var patch: Rect2 = patches[index]
		covered += patch.get_area()
		_check(patch.size.x > 0.0 and patch.size.y > 0.0 and cloth.encloses(patch),
			"quilt patch is a real axis-aligned piece inside the cloth")
		if index % columns < columns - 1:
			var right: Rect2 = patches[index + 1]
			_check(is_equal_approx(patch.end.x, right.position.x)
				and is_equal_approx(patch.position.y, right.position.y)
				and is_equal_approx(patch.size.y, right.size.y),
				"neighbouring quilt patches share an unbroken vertical seam")
		if index + columns < patches.size():
			var below: Rect2 = patches[index + columns]
			_check(is_equal_approx(patch.end.y, below.position.y)
				and is_equal_approx(patch.position.x, below.position.x)
				and is_equal_approx(patch.size.x, below.size.x),
				"stacked quilt patches share an unbroken horizontal seam")
	_check(is_equal_approx(covered, cloth.get_area()),
		"quilt patches tile the cloth with no gap or overlap")
	var seams: Array[PackedVector2Array] = backdrop.quilt_seams()
	_check(seams.size() == maxi(0, columns - 1) + maxi(0, rows - 1),
		"every internal patch edge is stitched exactly once")
	var stitched := cloth.grow(0.01)
	for seam in seams:
		_check(seam.size() == 2 and stitched.has_point(seam[0]) and stitched.has_point(seam[1]),
			"quilt seam stays inside the continuous cloth")
	_check(is_equal_approx(cloth.end.y + presenter.STAGE_HEM_HEIGHT, row.end.y),
		"exactly one stitched hem grounds the quilt")
	_check(Rect2(0, 0, 1280, 720).encloses(Rect2(backdrop.get_global_rect().position + row.position, row.size)),
		"whole quilted stage fits 1280x720")
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	_check(not source.contains("STAGE_PATCHES") and not source.contains("func _patch(")
		and source.contains("func quilt_rects()") and source.contains("func quilt_seams()"),
		"source draws one quilt instead of three tilted trapezoids")


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


func _three_enemy_fixture() -> Dictionary:
	for value in range(1, 1025):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng: int = rng.state
		for id in map.get_legal_choices():
			if map.get_node(id).get("type") != "Fight":
				continue
			rng.state = opening_rng
			if not map.choose_node(id):
				continue
			var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
			map.undo_choice(id, [])
			if selected.get("success", false) and selected["enemies"].get_enemies().size() == 3:
				return {"seed": value, "fight": id, "encounter": selected["encounter_id"]}
	return {}


func _typed_stage(app, presenter) -> void:
	var fixture := _three_enemy_fixture()
	_check(not fixture.is_empty(), "live seeded Fight rotation includes an authentic three-enemy roster")
	if fixture.is_empty():
		return
	app.run_seed = fixture.seed
	app.start_button.pressed.emit()
	await process_frame
	var route_button: Button = null
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.fight:
			route_button = candidate
			break
	_check(route_button != null and not route_button.disabled, "three-enemy Fight has a real enabled route control")
	if route_button == null:
		return
	route_button.pressed.emit()
	await process_frame
	await process_frame
	_check(app.enemies != null and app.enemies.get_enemies().size() == 3,
		"seeded production Fight exercises three typed enemies, not the standalone fixture")
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
		_check(presenter._labels[index].text == String(actor.get("name", ""))
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
