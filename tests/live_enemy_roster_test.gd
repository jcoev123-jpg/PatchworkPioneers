extends SceneTree

var failures: Array[String] = []
var checks := 0
const SOURCE := "res://data/enemies/starter_enemies.json"
const FIXTURE := "user://live_enemy_roster_invalid.json"
const ROSTER_ART := preload("res://scripts/live_enemy_roster.gd")
## Authored battle scene per admitted route kind; selection must never come from screen text.
const BACKDROP_ART := {
	"Fight": "res://assets/paper/backgrounds/battle_meadow.png",
	"Elite": "res://assets/paper/backgrounds/battle_ruins.png",
	"Boss": "res://assets/paper/backgrounds/battle_boss.png",
}
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


## The source of one indented Puppet method, up to the next method, for draw-path inspection.
func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var body := source.substr(start)
	return body.left(body.find("\n\tfunc "))


## Idle presentation: every living actor advances its own subtle bob and breathing pose
## inside its art band, while target rectangles, pinned names, intent badges, controls,
## combat state and RNG stay exactly as they were.
func _idle_motion(app, presenter, expect_fallback: bool = false) -> void:
	_check(is_instance_valid(presenter.panel) and presenter.enemies != null
		and not presenter._puppets.is_empty()
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
		"idle pose exercise runs on every actual mounted hero and enemy")
	if not is_instance_valid(presenter.panel) or presenter.enemies == null or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var tweens: int = get_processed_tweens().size()
	var hit_rects: Array[Rect2] = []
	var tag_rects: Array[Rect2] = []
	var tag_texts: Array[String] = []
	var badge_rects: Array[Rect2] = []
	var badge_texts: Array[String] = []
	var control_rects: Array[Rect2] = []
	for puppet in presenter._puppets:
		hit_rects.append(puppet.get_global_rect())
	for tag in presenter._hero_tags:
		tag_rects.append(tag.get_global_rect())
		tag_texts.append(tag.text)
	for label in presenter._labels:
		tag_rects.append(label.get_global_rect())
		tag_texts.append(label.text)
	for badge in presenter._badges:
		badge_rects.append(badge.get_global_rect())
		badge_texts.append(badge.readable_text)
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		control_rects.append(control.get_global_rect())
	var standing: Array = []
	for puppet in presenter._puppets:
		puppet.idle_phase = 0.0
		_check(puppet.is_processing(), "mounted puppet runs its idle frame tick: " + puppet.name)
		_check(puppet.find_children("*", "Timer", true, false).is_empty(),
			"idle motion schedules no timer under the actor: " + puppet.name)
		if not puppet.fallen:
			standing.append(puppet)
	_check(standing.size() == presenter._puppets.size(),
		"idle pose exercise starts with every mounted actor standing")
	if standing.is_empty():
		return
	# Stable distinct phases: no two actors bob or breathe in step.
	for first in range(standing.size()):
		for second in range(first + 1, standing.size()):
			_check(not is_equal_approx(standing[first].idle_offset(), standing[second].idle_offset())
				and not is_equal_approx(standing[first].idle_bob(), standing[second].idle_bob()),
				"each actor keeps its own deterministic idle phase")
	var fallback_seen := false
	for puppet in standing:
		var band: Rect2 = puppet.art_band()
		var inset: float = puppet.art_safety_inset()
		_check(band.size.y > 0.0 and inset >= puppet.IDLE_BOB_PIXELS,
			"art band reserves room for the bob and breathing swell: " + puppet.name)
		var low := 0.0
		var high := 0.0
		var breath_low := 1.0
		var breath_high := 1.0
		var height_low := 0.0
		var height_high := 0.0
		var first_pose := Rect2()
		var moved := false
		puppet.idle_phase = 0.0
		# Six seconds of real 0.2 s frames covers a whole bob and breathing cycle.
		for step in range(31):
			var bob: float = puppet.idle_bob()
			var breath: float = puppet.idle_breath()
			low = minf(low, bob)
			high = maxf(high, bob)
			breath_low = minf(breath_low, breath)
			breath_high = maxf(breath_high, breath)
			var posed: Rect2 = puppet.posed_actor_rect()
			_check(posed.size.x > 0.0 and posed.size.y > 0.0 and band.grow(-0.5).encloses(posed),
				"animated artwork stays wholly inside its art band with a safety inset: " + puppet.name)
			_check(absf(bob) <= puppet.IDLE_BOB_PIXELS + 0.001
				and absf(breath - 1.0) <= puppet.IDLE_BREATHE + 0.001,
				"idle pose stays a couple of pixels and about one percent: " + puppet.name)
			if step == 0:
				first_pose = posed
				height_low = posed.size.y
				height_high = posed.size.y
			else:
				height_low = minf(height_low, posed.size.y)
				height_high = maxf(height_high, posed.size.y)
				if absf(posed.position.y - first_pose.position.y) > 0.5:
					moved = true
			puppet._process(0.2)
		_check(high - low >= 2.0 and high - low <= 3.0
			and high >= puppet.IDLE_BOB_PIXELS * 0.9 and low <= -puppet.IDLE_BOB_PIXELS * 0.9,
			"living actor bobs two to three pixels above and below its rest pose: " + puppet.name)
		_check(breath_high - 1.0 >= 0.009 and 1.0 - breath_low >= 0.009,
			"living actor breathes about one percent in both directions: " + puppet.name)
		_check(height_high - height_low >= 1.0,
			"breathing visibly changes the drawn artwork height: " + puppet.name)
		_check(moved, "real frame deltas advance the drawn pose: " + puppet.name)
		var phase: float = puppet.idle_phase
		puppet._process(0.25)
		_check(is_equal_approx(puppet.idle_phase, phase + 0.25),
			"idle phase advances by the real delta: " + puppet.name)
		if puppet.current_texture() == null:
			fallback_seen = true
			_check(puppet.posed_image_rect() == Rect2() and puppet.posed_fallback_rect().size.y > 0.0,
				"missing art advances the drawn fallback pose: " + puppet.name)
		else:
			_check(puppet.posed_image_rect().size.y > 0.0
				and puppet.posed_actor_rect().is_equal_approx(puppet.posed_image_rect()),
				"supplied art draw path uses the same shared pose: " + puppet.name)
	_check(fallback_seen == expect_fallback,
		"the drawn fallback animates exactly when an actor has no supplied art")
	for puppet in presenter._puppets:
		puppet._process(0.4)
	var after_hit: Array[Rect2] = []
	for puppet in presenter._puppets:
		after_hit.append(puppet.get_global_rect())
	_check(after_hit == hit_rects, "idle art never moves an actor's complete target rectangle")
	var after_tag_rects: Array[Rect2] = []
	var after_tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		after_tag_rects.append(tag.get_global_rect())
		after_tag_texts.append(tag.text)
	for label in presenter._labels:
		after_tag_rects.append(label.get_global_rect())
		after_tag_texts.append(label.text)
	_check(after_tag_rects == tag_rects and after_tag_texts == tag_texts,
		"pinned hero and enemy names keep their exact place and text while art moves")
	var after_badge_rects: Array[Rect2] = []
	var after_badge_texts: Array[String] = []
	for badge in presenter._badges:
		after_badge_rects.append(badge.get_global_rect())
		after_badge_texts.append(badge.readable_text)
	_check(after_badge_rects == badge_rects and after_badge_texts == badge_texts,
		"intent badges keep their exact place and caption while art moves")
	var after_control_rects: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		after_control_rects.append(control.get_global_rect())
	_check(after_control_rects == control_rects,
		"hand, actions and the enemy roster panel stay put while art moves")
	_check(_snapshot(app) == before,
		"idle presentation changes no HP/Block, deck, energy, turn, intents or run RNG")
	_check(get_processed_tweens().size() == tweens,
		"idle motion creates no tween that outlives the frame")
	# Source inspection: both draw paths really apply the pose, with no timers or RNG.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var actor_body := _function_body(source, "func _draw_actor(")
	var fallback_body := _function_body(source, "func _draw_fallback(")
	_check(actor_body.contains("idle_transform(") and fallback_body.contains("idle_transform(")
		and actor_body.find("idle_transform(") < actor_body.find("draw_texture_rect("),
		"source applies the idle pose before drawing both the texture and the fallback")
	_check(source.contains("func _process(delta: float) -> void:") and source.contains("advance_idle(delta)")
		and source.contains("idle_phase += delta") and not source.contains("create_tween")
		and not source.contains("Timer.new") and not source.contains("randi(")
		and not source.contains("randf("),
		"idle animation advances a per-instance delta phase without tweens, timers or RNG")


## A downed or slain actor keeps the existing tilt and tint with no idle motion at all.
func _fallen_stillness(puppets: Array) -> void:
	for puppet in puppets:
		_check(puppet.fallen, "fallen stillness runs on a genuinely downed/slain actor: " + puppet.name)
		if not puppet.fallen:
			continue
		var phase: float = puppet.idle_phase
		var pose: Rect2 = puppet.posed_actor_rect()
		puppet._process(0.5)
		_check(is_equal_approx(puppet.idle_phase, phase),
			"fallen actor stops advancing its idle phase: " + puppet.name)
		_check(is_equal_approx(puppet.idle_bob(), 0.0) and is_equal_approx(puppet.idle_breath(), 1.0),
			"fallen actor keeps no bob or breathing: " + puppet.name)
		_check(puppet.posed_actor_rect() == pose,
			"fallen actor's drawn artwork stays perfectly still: " + puppet.name)
		puppet._process(1.0)
		_check(puppet.posed_actor_rect() == pose and is_equal_approx(puppet.idle_phase, phase),
			"further frame deltas leave the fallen actor motionless: " + puppet.name)


## A freshly mounted battle builds new puppets that start their idle phase at rest.
func _at_rest(puppets: Array) -> bool:
	if puppets.is_empty():
		return false
	for puppet in puppets:
		if not is_instance_valid(puppet) or not is_equal_approx(puppet.idle_phase, 0.0):
			return false
	return true


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
	_backdrop(app, presenter)
	_assert_badges(app, presenter, 1)
	_check(not app.intent_label.visible and not app.intent_label.text.is_empty(), "redundant legacy sentence is hidden while authoritative source remains")
	_check(presenter._puppets.size() == 3 + presenter.enemies.get_enemies().size(), "one presenter puppet for every actual actor")
	for puppet in presenter._puppets:
		_check(is_instance_valid(puppet) and puppet.is_visible_in_tree() and puppet.mouse_filter == Control.MOUSE_FILTER_IGNORE and puppet.focus_mode == Control.FOCUS_NONE, "mounted puppet is visible and input inert")
		_check(puppet.facing == (1.0 if puppet.name.begins_with("Hero") else -1.0), "actor puppet faces inward")
	_assert_actor_art(app, presenter)
	_idle_motion(app, presenter)
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


## One battle stage: the authored paper scene of this fight covers the whole battle view,
## and the complete drawn quilt with its ground hem remains whenever no image is available.
func _backdrop(app, presenter) -> void:
	var backdrop = presenter.backdrop
	_check(is_instance_valid(backdrop) and backdrop.name == "BattleStageBackdrop"
		and is_instance_valid(presenter._battle) and backdrop.get_parent() == presenter._battle
		and backdrop.get_index() == 0,
		"one stage backdrop owns the battle view behind both lineups")
	if not is_instance_valid(backdrop):
		return
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and backdrop.focus_mode == Control.FOCUS_NONE,
		"battle backdrop never takes pointer or keyboard input")
	# Selection: exactly one authored scene per admitted route kind, none for anything else.
	_check(ROSTER_ART.backdrop_path("Fight") == BACKDROP_ART["Fight"]
		and ROSTER_ART.backdrop_path("Elite") == BACKDROP_ART["Elite"]
		and ROSTER_ART.backdrop_path("Boss") == BACKDROP_ART["Boss"],
		"each battle kind selects only its own authored backdrop")
	_check(ROSTER_ART.backdrop_path("Rest") == "" and ROSTER_ART.backdrop_path("") == ""
		and ROSTER_ART.backdrop_path("Unknown") == "" and ROSTER_ART.backdrop_path("fight") == "",
		"unknown or malformed battle kinds select no backdrop")
	_check(app.run_map == null and backdrop.battle_kind == "Fight",
		"standalone battle selects the normal Fight backdrop")
	var fight_path: String = BACKDROP_ART["Fight"]
	_check(backdrop.has_image() == ResourceLoader.exists(fight_path),
		"the mounted Fight image is shown only when the authored file is present")
	if backdrop.has_image():
		_check(backdrop.stage_texture.resource_path == fight_path,
			"the mounted Fight stage draws its own authored image")
	_cover(app, presenter, backdrop)
	_fallback(app, presenter, backdrop)


## Cover geometry: one image fills the whole battle view without stretching, and the
## source it crops is only the centred window that window can show.
func _cover(app, presenter, backdrop) -> void:
	var view: Rect2 = backdrop.view_rect()
	var global_view := Rect2(backdrop.get_global_rect().position + view.position, view.size)
	_check(view.size.x > 0.0 and view.size.y > 0.0
		and global_view.is_equal_approx(app.battle_view.get_global_rect()),
		"the backdrop fills the whole battle view, not one actor box")
	_check(Rect2(0, 0, 1280, 720).is_equal_approx(global_view),
		"the battle view fills the 1280x720 screen edge to edge")
	for control in [app.hero_view, presenter.panel, app.hand_view, app.end_turn_button]:
		_check(global_view.encloses(control.get_global_rect()),
			"one stage image spans lineups, meters, hand and actions: " + control.name)
	_check(backdrop.get_index() == 0 and app.hand_view.get_parent().get_index() > 0,
		"the stage is drawn before every battle control and the free hand")
	var column: Node = app.hand_view.get_parent()
	var meters = app.get_node_or_null("LiveCombatMeters")
	_check(column.get_index() > backdrop.get_index() and column.is_ancestor_of(app.hero_view)
		and is_instance_valid(meters) and is_instance_valid(meters.row)
		and global_view.encloses(meters.row.get_global_rect())
		and global_view.encloses(presenter._badges[0].get_global_rect()),
		"actor targets, HP ribbons and intent badges all draw above the same one stage")
	# Pure cover math, independent of whether the authored files are installed.
	var square_view := Rect2(0, 0, 1280, 720)
	var square_cover: Rect2 = ROSTER_ART.cover_rect(square_view, Vector2(1000, 1000))
	var square_crop: Rect2 = ROSTER_ART.crop_rect(square_view, Vector2(1000, 1000))
	_check(square_cover.encloses(square_view)
		and is_equal_approx(square_cover.size.x / square_cover.size.y, 1.0),
		"cover math fills the view without stretching a square image")
	_check(square_crop.size.x <= 1000.0 and square_crop.size.y <= 1000.0
		and square_crop.position.x >= 0.0 and square_crop.position.y >= 0.0
		and square_crop.end.x <= 1000.01 and square_crop.end.y <= 1000.01
		and is_equal_approx(square_crop.size.x / square_crop.size.y, 1280.0 / 720.0),
		"cover crops only a centred window that keeps the view's proportions")
	var wide_cover: Rect2 = ROSTER_ART.cover_rect(square_view, Vector2(2000, 500))
	var wide_crop: Rect2 = ROSTER_ART.crop_rect(square_view, Vector2(2000, 500))
	_check(wide_cover.encloses(square_view)
		and is_equal_approx(wide_cover.size.x / wide_cover.size.y, 4.0)
		and wide_crop.size.x <= 2000.01 and wide_crop.size.y <= 500.01
		and wide_crop.end.x <= 2000.01 and wide_crop.end.y <= 500.01,
		"a wide image also covers the view by cropping instead of distorting")
	_check(ROSTER_ART.cover_rect(Rect2(), Vector2(10, 10)) == Rect2()
		and ROSTER_ART.crop_rect(Rect2(0, 0, 10, 10), Vector2.ZERO) == Rect2(),
		"an empty view or texture draws no cover image")
	if not backdrop.has_image():
		return
	var texture_size: Vector2 = backdrop.texture_size()
	var drawn: Rect2 = backdrop.image_rect()
	var visible: Rect2 = backdrop.image_crop()
	_check(drawn.encloses(view) and is_equal_approx(drawn.size.x / drawn.size.y,
		texture_size.x / texture_size.y),
		"the mounted image covers the battle view at its own proportions")
	_check(visible.position.x >= 0.0 and visible.position.y >= 0.0
		and visible.end.x <= texture_size.x + 0.01 and visible.end.y <= texture_size.y + 0.01,
		"the mounted image crops inside its own texture")
	var scale: float = drawn.size.x / texture_size.x
	_check(is_equal_approx(visible.size.x * scale, view.size.x)
		and is_equal_approx(visible.size.y * scale, view.size.y),
		"the cropped window is drawn exactly over the whole battle view")
	var hem: Rect2 = backdrop.hem_rect()
	_check(hem.size.x > 0.0 and is_equal_approx(hem.size.y, presenter.STAGE_HEM_HEIGHT)
		and Rect2(0, 0, 1280, 720).encloses(
			Rect2(backdrop.get_global_rect().position + hem.position, hem.size)),
		"the quiet ground hem stays above the image inside 1280x720")


## Unknown kinds and missing files keep the complete drawn quilt and its sewn hem; the
## whole fallback is inspected on the real mounted stage and then restored.
func _fallback(app, presenter, backdrop) -> void:
	var before: Array = _snapshot(app)
	backdrop.bind_battle("Unknown", presenter.backdrop_texture("Unknown"))
	_check(not backdrop.has_image() and backdrop.image_rect() == Rect2()
		and backdrop.image_crop() == Rect2(),
		"an unknown battle kind leaves no image and no cover draw")
	_check(presenter.backdrop_texture("Unknown") == null and presenter.backdrop_texture("") == null
		and ROSTER_ART._load_art_texture("res://assets/paper/backgrounds/fabricated_missing.png") == null
		and ROSTER_ART._load_art_texture("") == null,
		"missing, fabricated or empty backdrop paths load nothing and cannot crash")
	var global_row: Rect2 = presenter.battle_row.get_global_rect()
	var row: Rect2 = Rect2(global_row.position - backdrop.get_global_rect().position, global_row.size)
	var cloth: Rect2 = backdrop.quilt_cloth()
	var patches: Array[Rect2] = backdrop.quilt_rects()
	var columns: int = presenter.STAGE_QUILT_COLUMNS.size() - 1
	var rows: int = presenter.STAGE_QUILT_ROWS.size() - 1
	_check(columns >= 2 and rows >= 1 and patches.size() == columns * rows,
		"the fallback is one continuous field of shared patches")
	_check(cloth.size.y > 0.0 and is_equal_approx(cloth.position.x, row.position.x)
		and is_equal_approx(cloth.size.x, row.size.x),
		"fallback cloth spans the whole actor row edge to edge")
	var covered := 0.0
	for index in range(patches.size()):
		var patch: Rect2 = patches[index]
		covered += patch.get_area()
		_check(patch.size.x > 0.0 and patch.size.y > 0.0 and cloth.encloses(patch),
			"fallback quilt patch is a real axis-aligned piece inside the cloth")
		if index % columns < columns - 1:
			var right: Rect2 = patches[index + 1]
			_check(is_equal_approx(patch.end.x, right.position.x)
				and is_equal_approx(patch.position.y, right.position.y)
				and is_equal_approx(patch.size.y, right.size.y),
				"neighbouring fallback patches share an unbroken vertical seam")
		if index + columns < patches.size():
			var below: Rect2 = patches[index + columns]
			_check(is_equal_approx(patch.end.y, below.position.y)
				and is_equal_approx(patch.position.x, below.position.x)
				and is_equal_approx(patch.size.x, below.size.x),
				"stacked fallback patches share an unbroken horizontal seam")
	_check(is_equal_approx(covered, cloth.get_area()),
		"fallback patches tile the cloth with no gap or overlap")
	var seams: Array[PackedVector2Array] = backdrop.quilt_seams()
	_check(seams.size() == maxi(0, columns - 1) + maxi(0, rows - 1),
		"every internal fallback patch edge is stitched exactly once")
	var stitched := cloth.grow(0.01)
	for seam in seams:
		_check(seam.size() == 2 and stitched.has_point(seam[0]) and stitched.has_point(seam[1]),
			"fallback quilt seam stays inside the continuous cloth")
	var hem: Rect2 = backdrop.hem_rect()
	_check(hem.size.x > 0.0 and is_equal_approx(hem.size.y, presenter.STAGE_HEM_HEIGHT)
		and is_equal_approx(cloth.end.y, hem.position.y)
		and is_equal_approx(hem.end.y, row.end.y),
		"exactly one stitched hem grounds the fallback quilt")
	_check(Rect2(0, 0, 1280, 720).encloses(
		Rect2(backdrop.get_global_rect().position + hem.position, hem.size)),
		"the fallback hem stays inside 1280x720")
	_check(_snapshot(app) == before,
		"backdrop selection, fallback and cover calculation change no combat state or RNG")
	# Source inspection: both branches exist and the quiet hem is drawn above either one.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var stage_source := source.substr(source.find("class StageBackdrop extends Control:"))
	var draw_body := stage_source.substr(stage_source.find("func _draw() -> void:"))
	draw_body = draw_body.left(draw_body.find("\n\tfunc "))
	_check(draw_body.find("_draw_backdrop_image()") >= 0
		and draw_body.find("_draw_quilt()") >= 0
		and draw_body.find("_draw_backdrop_image()") < draw_body.find("_draw_ground_hem()")
		and draw_body.find("_draw_quilt()") < draw_body.find("_draw_ground_hem()"),
		"source draws the stage scene or the fallback quilt first and the quiet hem above it")
	_check(source.contains("draw_texture_rect_region(stage_texture, view_rect(), image_crop())"),
		"source cover-draws the authored image into the whole battle view")
	_check(not source.contains("STAGE_PATCHES") and not source.contains("func _patch(")
		and source.contains("func quilt_rects()") and source.contains("func quilt_seams()")
		and source.contains("func _draw_ground_hem()"),
		"source keeps one quilt instead of tilted trapezoids and one shared hem")
	backdrop.bind_battle("Fight", presenter.backdrop_texture("Fight"))
	_check(backdrop.battle_kind == "Fight"
		and backdrop.has_image() == ResourceLoader.exists(BACKDROP_ART["Fight"]),
		"the live battle restores its own backdrop after the fallback check")


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
		var tick_phase: float = presenter._puppets[0].idle_phase
		await process_frame
		await process_frame
		_check(presenter._puppets[0].idle_phase > tick_phase,
			"mounted idle loop advances from the real frame delta of its own actor")
		var heroes = app.hero_view
		var hero_slots: Array = app.hero_panels.duplicate()
		var original_parent = presenter._hero_parent
		var old_row_id: int = presenter.battle_row.get_instance_id()
		var old_panel_id: int = presenter.panel.get_instance_id()
		var old_puppet_ids: Array[int] = []
		for puppet in presenter._puppets:
			old_puppet_ids.append(puppet.get_instance_id())
		presenter._clear()
		_check(is_instance_valid(heroes) and heroes.get_parent() == original_parent and
			app.hero_panels == hero_slots, "explicit clear restores same app-owned heroes and slots")
		_check(presenter._puppets.is_empty(), "clear releases every animated puppet")
		presenter._sync_battle()
		_check(_at_rest(presenter._puppets),
			"a fresh mount builds new puppets whose idle phase starts at rest")
		await process_frame
		await process_frame
		var stale_puppets := 0
		for id in old_puppet_ids:
			if is_instance_id_valid(id):
				stale_puppets += 1
		_check(stale_puppets == 0, "remount leaves no stale animated puppet behind")
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
		var backdrop_id: int = presenter.backdrop.get_instance_id() if is_instance_valid(presenter.backdrop) else 0
		var before := _snapshot(app)
		var puppet_ids: Array[int] = []
		for puppet in presenter._puppets:
			puppet_ids.append(puppet.get_instance_id())
		_fixture_start(app)
		await process_frame
		_check(presenter.enemies == roster_ref.get_ref() and is_instance_valid(presenter.panel) and
			presenter.panel.get_instance_id() == panel_id, "duplicate Start Run retains same roster and panel")
		var same_puppets: bool = presenter._puppets.size() == puppet_ids.size()
		for index in range(mini(presenter._puppets.size(), puppet_ids.size())):
			same_puppets = same_puppets and presenter._puppets[index].get_instance_id() == puppet_ids[index]
		_check(same_puppets and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
			"duplicate Start Run keeps one animated puppet per actual actor, with no duplicate")
		_check(app.battle_view.find_children("EnemyRosterPanel", "PanelContainer", true, false).size() == 1,
			"exactly one presenter panel per battle")
		_check(presenter._badges.size() == 2, "duplicate Start Run cannot add intent badges")
		_check(backdrop_id != 0 and is_instance_valid(presenter.backdrop)
			and presenter.backdrop.get_instance_id() == backdrop_id
			and app.battle_view.find_children("BattleStageBackdrop", "Control", true, false).size() == 1,
			"duplicate Start Run retains exactly one battle backdrop")
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
		var slain_puppets: Array = []
		for puppet in presenter._puppets:
			if puppet.facing < 0.0 and puppet.slot == 1:
				slain_puppets.append(puppet)
		_check(slain_puppets.size() == 1 and slain_puppets[0].fallen,
			"the slain ragling's own puppet reflects genuine fallen state")
		_fallen_stillness(slain_puppets)
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
		_check(presenter._puppets.is_empty(), "Return removes every animated puppet with no surviving idle loop")
		await process_frame
		_check(not is_instance_id_valid(panel_id), "old panel freed")
		_check(not is_instance_id_valid(row_id) and not is_instance_valid(heroes) and
			presenter.battle_row == null, "Return frees old wrapper and app-owned battle with no orphan heroes")
		presenter._refresh()
		_check(presenter._badges.is_empty() and presenter.panel == null,
			"no-session refresh cannot resummon stale callbacks or badges")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "title and keyboard focus restored")
	await _bound_skip_badges(app, presenter)
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
	_idle_motion(app, presenter, true)
	app.return_button.pressed.emit()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	await process_frame
	app.starter_enemies_path = SOURCE
	await _typed_stage(app, presenter)
	app.free()
	reference.free()
	_finish()


## Pending Unravel replaces only the readout, never the intent scheduler or
## input target. The original-slot authority is bound to this actual app flow.
func _bound_skip_badges(app, presenter) -> void:
	_fixture_start(app)
	await process_frame
	await process_frame
	_check(app.round_flow != null and app.round_flow._started and app.enemies.get_enemies().size() == 2
		and presenter._badges.size() == 2, "mounted original enemy slots exist before Unravel intent exercise")
	if app.round_flow == null or presenter._badges.size() != 2:
		return
	var service := CombatUnravel.new()
	_check(service.bind_roster(app.enemies, {1: "normal", 2: "normal"}),
		"active battle service binds original positions, not presented names")
	app.round_flow._unravel = service
	var announced: Array[Dictionary] = app.enemy_intents.get_intents()
	var initial_state := _snapshot(app)
	presenter._refresh()
	_check(_snapshot(app) == initial_state and presenter._badges[0].icon_mode == "attack"
		and presenter._badges[1].icon_mode == "block",
		"zero-gauge sourced original attacks and Block keep their old badge semantics")
	_check(service.apply_unravel(app.enemies, 1, 3) and service.apply_unravel(app.enemies, 1, 5)
		and service.get_snapshot(1).skip_pending, "genuinely roster-bound threshold queues one pending skip")
	presenter._refresh()
	var badge = presenter._badges[0]
	_check(badge.readable_text == "UNRAVELLED" and badge.icon_mode == "unravelled"
		and badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0,
		"scheduled attack/target is suppressed only in pending skip presentation")
	_check(presenter._badges[1].icon_mode == "block"
		and presenter._badges[1].readable_text == "BLOCK +1",
		"unskipped second source retains real block intent")
	var pending_model := _snapshot(app)
	for step in range(5):
		presenter._refresh()
	_check(_snapshot(app) == pending_model and app.enemy_intents.get_intents() == announced
		and service.get_snapshot(1).skip_pending,
		"five UI reads cannot consume the pending skip, mutate intents, decks, HP or RNG")
	_check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE and badge.focus_mode == Control.FOCUS_NONE,
		"the Unravelled mark cannot steal mouse or keyboard target input")
	await _input_mouse(badge)
	_check(_snapshot(app) == pending_model and service.get_snapshot(1).skip_pending,
		"actual pointer clicking the skip badge cannot play a card or consume the skip")
	var foreign := CombatUnravel.new()
	_check(foreign.bind_roster(CombatEnemies.new(app.enemies.get_enemies()),
		{1: "elite", 2: "boss"}), "mismatched roster is genuinely independently bound")
	app.round_flow._unravel = foreign
	presenter._refresh()
	_check(badge.icon_mode == "attack" and badge.readable_text == "ATK 1 > H1",
		"roster-mismatched pending authority falls back to unchanged scheduler intent")
	app.round_flow._unravel = null
	presenter._refresh()
	_check(badge.icon_mode == "attack" and badge.readable_text == "ATK 1 > H1",
		"missing authority preserves ordinary attack instead of stale UNRAVELLED")
	app.round_flow._unravel = service
	presenter._refresh()
	_check(badge.icon_mode == "unravelled", "restoring exact roster authority restores skip cue")
	app.end_turn_button.pressed.emit()
	await process_frame
	await process_frame
	presenter._refresh()
	_check(not service.get_snapshot(1).skip_pending and service.get_snapshot(1).threshold == 12
		and badge.icon_mode == "attack" and badge.readable_text.begins_with("ATK ")
		and app.enemy_intents.get_intents() != announced,
		"real End Turn consumes pending original slot once and badge re-announces the scheduler")
	_check(app.enemies.apply_damage(1, 999) and app.enemies.is_slain(1),
		"slain slot is an actual CombatEnemies transaction")
	_check(service.apply_unravel(app.enemies, 1, 8) == false,
		"service cannot charge an already slain original enemy")
	presenter._refresh()
	_check(badge.icon_mode == "slain" and badge.readable_text == "SLAIN",
		"slain precedence overrides all pending/announced action marks")
	var badge_id: int = badge.get_instance_id()
	app.return_button.pressed.emit()
	await process_frame
	_check(not is_instance_id_valid(badge_id) and presenter._badges.is_empty()
		and presenter.panel == null, "Return destroys badge so a new fight cannot inherit skip")


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
	var route_kind: String = app.run_map.get_node(app.run_map.get_current_node_id()).get("type", "")
	_check(route_kind == "Fight" and is_instance_valid(presenter.backdrop)
		and presenter.backdrop.battle_kind == route_kind
		and presenter.backdrop.has_image() == ResourceLoader.exists(BACKDROP_ART["Fight"]),
		"the seeded routed fight takes its backdrop from its real admitted route node")
	var before := _snapshot(app)
	var meters = app.get_node("LiveCombatMeters").row
	_check(presenter._puppets.size() == 6 and presenter._labels.size() == 3
		and meters.get_child_count() == 6, "mounted typed path has every puppet, target and real meter")
	_assert_actor_art(app, presenter)
	_idle_motion(app, presenter)
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
	_fallen_stillness([presenter._puppets[0], presenter._puppets[4]])
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
