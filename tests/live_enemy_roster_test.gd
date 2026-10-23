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
			"mounted actor keeps its own paired attack-pose image for committed plays")
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
		# The authored Elite/Boss texture goes through the same mounting/draw geometry as a
		# starter actor: bottom on the one foot line, with its contact shadow. Presentation
		# is restored immediately, so the live battle keeps its own actor art.
		var host = presenter._puppets[0]
		var saved_id: String = host.actor_id
		var saved_idle: Texture2D = host.idle_texture
		var saved_attack: Texture2D = host.attack_texture
		host.bind_actor(actor_id, art)
		_check(host.image_rect().size.y > 0.0
			and absf(host.actor_rest_bottom() - host.foot_line()) <= 0.01
			and host.contact_shadow_rect().size.x > 0.0,
			"authored Elite/Boss art rests on the shared foot line with a contact shadow: " + actor_id)
		host.bind_actor(saved_id, {"idle": saved_idle, "attack": saved_attack})
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


## The routed Fight stage advances by the admitted node's own integer floor: meadow 1-3,
## woods 4-6, marsh 7-9, peaks 10-11. A standalone battle (no map, no floor) keeps the
## meadow, while an invalid floor or missing file keeps the drawn quilt.
func _fight_areas(app, presenter, backdrop) -> void:
	var expected := {
		"Meadow": "res://assets/paper/backgrounds/battle_meadow.png",
		"Woods": "res://assets/paper/backgrounds/battle_woods.png",
		"Marsh": "res://assets/paper/backgrounds/battle_marsh.png",
		"Peaks": "res://assets/paper/backgrounds/battle_peaks.png",
	}
	var bands := [["Meadow", 1, 3], ["Woods", 4, 6], ["Marsh", 7, 9], ["Peaks", 10, 11]]
	var installed: Dictionary = {}
	for band in bands:
		var area_name: String = band[0]
		for floor_number in range(int(band[1]), int(band[2]) + 1):
			_check(ROSTER_ART.fight_area_name(floor_number) == area_name
				and ROSTER_ART.fight_backdrop_path(floor_number) == expected[area_name]
				and ROSTER_ART.stage_backdrop_path("Fight", floor_number) == expected[area_name],
				"routed Fight floor %d selects the %s area" % [floor_number, area_name])
		_check(ResourceLoader.exists(expected[area_name]),
			"the committed %s landscape really loads" % area_name)
		var loaded: Texture2D = presenter.stage_texture(expected[area_name])
		_check(loaded != null and loaded.resource_path == expected[area_name]
			and not installed.has(loaded.resource_path),
			"the %s area loads its own distinct committed texture" % area_name)
		installed[expected[area_name]] = true
	_check(installed.size() == expected.size(), "all four authored landscapes are distinct")
	# Standalone: no run map and no floor, so the normal meadow stage stays.
	_check(ROSTER_ART.stage_backdrop_path("Fight", ROSTER_ART.STANDALONE_FLOOR) == expected["Meadow"]
		and app.run_map == null and backdrop.battle_kind == "Fight"
		and backdrop.stage_texture.resource_path == expected["Meadow"],
		"a standalone battle keeps the meadow without any run map")
	# Invalid or absent data selects nothing and keeps the quilt, never another area.
	for floor_number in [ROSTER_ART.INVALID_FLOOR, 12, 13, 99]:
		_check(ROSTER_ART.fight_area_name(floor_number) == ""
			and ROSTER_ART.fight_backdrop_path(floor_number) == ""
			and ROSTER_ART.stage_backdrop_path("Fight", floor_number) == "",
			"floor %d has no Fight area and keeps the quilt" % floor_number)
	_check(ROSTER_ART.stage_backdrop_path("Fight", ROSTER_ART.INVALID_FLOOR) == ""
		and presenter.stage_texture(ROSTER_ART.fight_backdrop_path(ROSTER_ART.INVALID_FLOOR)) == null
		and presenter.stage_texture("res://assets/paper/backgrounds/fabricated_missing_area.png") == null
		and presenter.stage_texture("") == null,
		"invalid floors and missing area files load nothing and cannot crash")
	# Kind identity is retained: Elite and Boss keep their own scenes on every floor.
	for kind in ["Elite", "Boss"]:
		for floor_number in [1, 5, 8, 11, 12]:
			_check(ROSTER_ART.stage_backdrop_path(kind, floor_number) == BACKDROP_ART[kind],
				kind + " keeps its own scene on floor %d" % floor_number)
	# A new Fight on another floor is a new stage selection, not the same kind.
	_check(ROSTER_ART.stage_key("Fight", 1) != ROSTER_ART.stage_key("Fight", 4)
		and ROSTER_ART.stage_key("Fight", 4) != ROSTER_ART.stage_key("Fight", 7)
		and ROSTER_ART.stage_key("Fight", 7) != ROSTER_ART.stage_key("Fight", 10)
		and ROSTER_ART.stage_key("Fight", 10) == ROSTER_ART.stage_key("Fight", 10)
		and ROSTER_ART.stage_key("Elite", 5) != ROSTER_ART.stage_key("Fight", 5),
		"the stage selection key carries the area floor, not only the kind")


## Grounding: whichever artwork an actor draws rests its bottom edge on one shared foot
## line above the pinned tag, with a fixed soft contact shadow and a dark rim drawn behind
## it. Both are draw calls inside the input-inert puppet, so names, target rectangles and
## intent badges keep working and no combat model or RNG is touched.
func _staging(app, presenter) -> void:
	_check(is_instance_valid(presenter.backdrop) and not presenter._puppets.is_empty()
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
		"staging assertions run on every actual mounted actor")
	if not is_instance_valid(presenter.backdrop) or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var shadow_body := _function_body(source, "func _draw_contact_shadow(")
	var rim_body := _function_body(source, "func _draw_silhouette(")
	var puppet_draw := _function_body(source, "func _draw() -> void:")
	_check(shadow_body.contains("contact_shadow_rect()") and shadow_body.contains("oval_points(")
		and shadow_body.contains("draw_colored_polygon("),
		"source draws the contact shadow as soft ovals from its fixed rest-pose rectangle")
	_check(rim_body.contains("idle_transform(") and rim_body.contains("RIM_INK")
		and rim_body.contains("draw_texture_rect(") and rim_body.contains("_draw_fallback_shapes(true)"),
		"source draws one dark rim copy behind both supplied art and the drawn fallback")
	_check(not shadow_body.contains("add_child") and not rim_body.contains("add_child")
		and not shadow_body.contains("Control.new") and not rim_body.contains("Control.new"),
		"the shadow and rim are drawn, never mounted as extra controls")
	_check(puppet_draw.find("_draw_contact_shadow()") >= 0
		and puppet_draw.find("_draw_silhouette()") >= 0
		and puppet_draw.find("_draw_actor(") >= 0
		and puppet_draw.find("_draw_fallback()") >= 0
		and puppet_draw.find("_draw_tag()") >= 0
		and puppet_draw.find("_draw_contact_shadow()") < puppet_draw.find("_draw_silhouette()")
		and puppet_draw.find("_draw_silhouette()") < puppet_draw.find("_draw_actor(")
		and puppet_draw.find("_draw_silhouette()") < puppet_draw.find("_draw_fallback()")
		and puppet_draw.find("_draw_actor(") < puppet_draw.find("_draw_tag()")
		and puppet_draw.find("_draw_fallback()") < puppet_draw.find("_draw_tag()"),
		"source draw order is contact shadow, dark rim, actor artwork, then the pinned tag")
	var screen_feet: Array[float] = []
	for puppet in presenter._puppets:
		var band: Rect2 = puppet.art_band()
		var tag_band: Rect2 = puppet.tag_band()
		_check(band.size.y > 0.0 and tag_band.size.y > 0.0
			and puppet.foot_line() > band.position.y
			and puppet.foot_line() < band.end.y + 0.01
			and tag_band.position.y >= band.end.y - 0.01,
			"the shared foot line sits above the pinned name/HP tag inside the art band: " + puppet.name)
		_check(puppet.art_inset() >= puppet.IDLE_BOB_PIXELS
			and is_equal_approx(puppet.foot_line(), band.end.y - puppet.art_inset()),
			"the foot line keeps the bob/breathing safety inset clear of the tag band: " + puppet.name)
		_check(absf(puppet.actor_rest_bottom() - puppet.foot_line()) <= 0.01,
			"whichever artwork is bound, its bottom edge rests on the foot line: " + puppet.name)
		screen_feet.append(puppet.get_global_rect().position.y + puppet.actor_rest_bottom())
		var shadow: Rect2 = puppet.contact_shadow_rect()
		_check(shadow.size.x > 0.0 and shadow.size.y > 0.0
			and band.grow(0.01).encloses(shadow)
			and is_equal_approx(shadow.get_center().x, puppet.size.x * 0.5)
			and not shadow.intersects(puppet.tag_band().grow(-0.01)),
			"each actor has one soft oval contact shadow on its foot line, clear of its tag: " + puppet.name)
		puppet.idle_phase = 0.0
		var rest_shadow := shadow
		var rest_pose: Rect2 = puppet.posed_actor_rect()
		puppet._process(0.37)
		puppet._process(0.41)
		_check(puppet.contact_shadow_rect() == rest_shadow,
			"the contact shadow stays exactly still while the artwork breathes and bobs: " + puppet.name)
		_check(rest_pose.size.y > 0.0 and puppet.posed_actor_rect() != rest_pose,
			"real frame deltas still move the grounded artwork: " + puppet.name)
		puppet.idle_phase = 0.0
	var first: float = screen_feet[0]
	var spread := 0.0
	for value in screen_feet:
		spread = maxf(spread, absf(value - first))
	_check(spread <= 0.51,
		"every mounted hero and enemy stands on the same 1280x720 screen foot line")
	var hem: Rect2 = presenter.backdrop.hem_rect()
	var hem_global_y: float = presenter.backdrop.get_global_rect().position.y + hem.position.y
	_check(hem.size.y > 0.0 and hem_global_y > first
		and hem_global_y - first <= presenter.STAGE_TAG_HEIGHT + 16.0,
		"that common foot line is just above the stitched quilt hem, under the pinned tags")
	_check(_snapshot(app) == before,
		"grounding, contact shadow and rim reads change no combat state or RNG")


## VIS V5 attack pose: each living mounted actor owns one short, bounded lunge in its own
## facing direction with its authored `_attack` image when that image exists (the same
## idle art or the drawn puppet when it does not), then returns exactly to idle. The pose
## lives only in the drawn transform, so target rectangles, pinned names, intent badges,
## the hand and the action row stay put and no HP, deck, energy, turn, intent or RNG value
## moves. A fallen actor and a detached puppet never start one.
func _attack_pose(app, presenter) -> void:
	_check(is_instance_valid(presenter.panel) and presenter.enemies != null
		and not presenter._puppets.is_empty()
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
		"attack-pose checks run on every actual mounted actor")
	if not is_instance_valid(presenter.panel) or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var tweens: int = get_processed_tweens().size()
	var puppet_rects: Array[Rect2] = []
	for puppet in presenter._puppets:
		puppet_rects.append(puppet.get_global_rect())
	var tag_rects: Array[Rect2] = []
	var tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		tag_rects.append(tag.get_global_rect())
		tag_texts.append(tag.text)
	for label in presenter._labels:
		tag_rects.append(label.get_global_rect())
		tag_texts.append(label.text)
	var badge_rects: Array[Rect2] = []
	var badge_texts: Array[String] = []
	for badge in presenter._badges:
		badge_rects.append(badge.get_global_rect())
		badge_texts.append(badge.readable_text)
	var control_rects: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		control_rects.append(control.get_global_rect())
	var living: Array = []
	for puppet in presenter._puppets:
		if not puppet.fallen:
			living.append(puppet)
	_check(not living.is_empty(), "the live battle mounts at least one standing actor")
	for puppet in living:
		_check(not puppet.attacking() and is_equal_approx(puppet.attack_shape(), 0.0)
			and is_equal_approx(puppet.attack_lunge(), 0.0)
			and puppet.pose_texture() == puppet.current_texture(),
			"a standing actor starts at plain idle before any committed hit: " + puppet.name)
		_check(not puppet.trigger_attack(0.0) and not puppet.trigger_attack(-0.5)
			and not puppet.attacking(), "a zero or negative pose span never starts a lunge: " + puppet.name)
		_check(puppet.trigger_attack(30.0) and puppet.attacking()
			and puppet.attack_span <= puppet.ATTACK_MAX_SECONDS,
			"one committed pose is bounded to the approved span: " + puppet.name)
		puppet.cancel_attack()
		_check(not puppet.attacking() and puppet.pose_texture() == puppet.current_texture()
			and puppet.posed_actor_rect() == (puppet.posed_image_rect()
				if puppet.current_texture() != null else puppet.posed_fallback_rect()),
			"cancelling the pose returns the actor exactly to its idle drawing: " + puppet.name)
		var phase: float = puppet.idle_phase
		var rest_pose: Rect2 = puppet.posed_actor_rect()
		var idle_texture: Texture2D = puppet.current_texture()
		var attack_texture: Texture2D = puppet.attack_texture
		_check(puppet.trigger_attack(0.6) and puppet.attacking(),
			"a committed hit starts exactly one attack pose: " + puppet.name)
		if attack_texture != null:
			_check(puppet.pose_texture() == attack_texture
				and puppet.pose_texture().resource_path == idle_texture.resource_path.trim_suffix(".png") + "_attack.png",
				"the pose draws this actor's own authored attack image: " + puppet.name)
		else:
			_check(puppet.pose_texture() == idle_texture,
				"an actor without attack art keeps its idle drawing during the pose: " + puppet.name)
		puppet._process(puppet.attack_span * 0.5)
		var peak: Rect2 = puppet.posed_actor_rect()
		var pose: Transform2D = puppet.idle_transform(Vector2.ZERO, 1.0)
		_check(puppet.attacking() and is_equal_approx(puppet.attack_shape(), 1.0)
			and puppet.attack_lunge() * puppet.facing >= 4.0,
			"the pose lunges toward the other lineup in this actor's own facing: " + puppet.name)
		_check(is_equal_approx(pose.x.x, puppet.facing * puppet.attack_stretch())
			and is_equal_approx(pose.y.y, puppet.idle_breath() * puppet.attack_squash())
			and puppet.attack_stretch() > 1.0 and puppet.attack_squash() < 1.0,
			"the drawn pose adds paper stretch and squash to the lunge: " + puppet.name)
		_check((peak.get_center().x - rest_pose.get_center().x) * puppet.facing
			>= absf(puppet.attack_lunge()) - 0.01,
			"the lunge moves only the drawn artwork, not the actor control: " + puppet.name)
		_check(puppet.get_global_rect() == puppet_rects[presenter._puppets.find(puppet)],
			"the complete actor target rectangle never moves during a pose: " + puppet.name)
		puppet._process(puppet.ATTACK_MAX_SECONDS)
		_check(not puppet.attacking() and is_equal_approx(puppet.attack_span, 0.0)
			and puppet.pose_texture() == idle_texture,
			"the pose ends by itself within 0.6 s and returns to idle art: " + puppet.name)
		puppet.idle_phase = phase
		_check(puppet.posed_actor_rect() == rest_pose,
			"after the pose the actor stands exactly where it did before: " + puppet.name)
		puppet._process(0.1)
		_check(not puppet.attacking() and is_equal_approx(puppet.attack_shape(), 0.0),
			"a settled pose never replays on later frames: " + puppet.name)
		puppet.idle_phase = phase
	# An actor whose authored attack image is missing keeps its supplied idle art and
	# still performs the same bounded lunge.
	var host = living[0]
	var saved_attack: Texture2D = host.attack_texture
	var host_phase: float = host.idle_phase
	host.attack_texture = null
	var host_rest: Rect2 = host.posed_actor_rect()
	_check(host.trigger_attack(0.6) and host.pose_texture() == host.current_texture(),
		"a supplied actor missing only its attack image poses with its idle art")
	host._process(host.attack_span * 0.5)
	_check(host.posed_actor_rect() != host_rest and host.attack_lunge() * host.facing >= 4.0,
		"the missing-attack-image pose still lunges the drawn artwork")
	host.cancel_attack()
	host.attack_texture = saved_attack
	host.idle_phase = host_phase
	# The drawn puppet (no supplied art at all) owns the same pose.
	var saved_id: String = host.actor_id
	var saved_idle: Texture2D = host.idle_texture
	host.bind_actor("fabricated_pose_actor", {})
	var drawn_rest: Rect2 = host.posed_fallback_rect()
	_check(host.current_texture() == null and host.pose_texture() == null
		and host.trigger_attack(0.6) and host.attacking(),
		"an actor with no supplied art at all still performs the drawn attack pose")
	host._process(host.attack_span * 0.5)
	_check(host.posed_fallback_rect() != drawn_rest and host.attack_lunge() * host.facing >= 4.0,
		"the drawn fallback puppet lunges exactly like a supplied image")
	host.cancel_attack()
	host.bind_actor(saved_id, {"idle": saved_idle, "attack": saved_attack})
	host.idle_phase = host_phase
	# Source inspection: the realistic pose is real draw work, with no tween, timer or RNG.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var pose_body := _function_body(source, "func trigger_attack(")
	var advance_body := _function_body(source, "func advance_attack(")
	var actor_body := _function_body(source, "func _draw_actor(")
	var puppet_draw := _function_body(source, "func _draw() -> void:")
	_check(pose_body.contains("attack_span = clampf(") and pose_body.contains("ATTACK_MAX_SECONDS")
		and pose_body.contains("if fallen")
		and advance_body.contains("attack_remaining = maxf(") and advance_body.contains("cancel_attack()")
		and not pose_body.contains("create_tween") and not advance_body.contains("create_tween")
		and not pose_body.contains("Timer.new") and not advance_body.contains("Timer.new")
		and not pose_body.contains("randi(") and not advance_body.contains("randf("),
		"the pose is a bounded delta-driven state, never a tween, timer or RNG draw")
	_check(puppet_draw.contains("pose_texture()") and actor_body.contains("pose_rect(")
		and actor_body.contains("idle_transform(")
		and actor_body.find("idle_transform(") < actor_body.find("draw_texture_rect("),
		"the actor draw path uses the pose image and the one shared pose transform")
	# Every mounted control keeps its exact place, caption and target.
	var after_puppets: Array[Rect2] = []
	for puppet in presenter._puppets:
		after_puppets.append(puppet.get_global_rect())
	_check(after_puppets == puppet_rects,
		"no actor target rectangle moves during any pose")
	var after_tags: Array[Rect2] = []
	var after_tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		after_tags.append(tag.get_global_rect())
		after_tag_texts.append(tag.text)
	for label in presenter._labels:
		after_tags.append(label.get_global_rect())
		after_tag_texts.append(label.text)
	_check(after_tags == tag_rects and after_tag_texts == tag_texts,
		"pinned hero and enemy names keep their exact place and text during poses")
	var after_badges: Array[Rect2] = []
	var after_badge_texts: Array[String] = []
	for badge in presenter._badges:
		after_badges.append(badge.get_global_rect())
		after_badge_texts.append(badge.readable_text)
	_check(after_badges == badge_rects and after_badge_texts == badge_texts,
		"intent badges keep their exact place and caption during poses")
	var after_controls: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		after_controls.append(control.get_global_rect())
	_check(after_controls == control_rects,
		"hand, actions and the enemy roster panel stay put during poses")
	_check(_snapshot(app) == before,
		"a committed attack pose changes no HP/Block, deck, energy, turn, intent or run RNG")
	_check(get_processed_tweens().size() == tweens,
		"the attack pose creates no tween that outlives the frame")

## Committed-hit recoil: one short, bounded, damped horizontal wobble of the drawn artwork
## only. It combines with a committed lunge, works for missing art, settles exactly back to
## idle, cancels on a rebind or a fall, and never moves a target, a pinned name, an intent
## badge or an action control.
func _recoil(app, presenter) -> void:
	_check(is_instance_valid(presenter.panel) and presenter.enemies != null
		and not presenter._puppets.is_empty()
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
		"recoil checks run on every actual mounted actor")
	if not is_instance_valid(presenter.panel) or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var tweens: int = get_processed_tweens().size()
	var puppet_rects: Array[Rect2] = []
	for puppet in presenter._puppets:
		puppet_rects.append(puppet.get_global_rect())
	var tag_rects: Array[Rect2] = []
	var tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		tag_rects.append(tag.get_global_rect())
		tag_texts.append(tag.text)
	for label in presenter._labels:
		tag_rects.append(label.get_global_rect())
		tag_texts.append(label.text)
	var badge_rects: Array[Rect2] = []
	var badge_texts: Array[String] = []
	for badge in presenter._badges:
		badge_rects.append(badge.get_global_rect())
		badge_texts.append(badge.readable_text)
	var control_rects: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		control_rects.append(control.get_global_rect())
	var standing: Array = []
	for puppet in presenter._puppets:
		if not puppet.fallen:
			standing.append(puppet)
	_check(not standing.is_empty(), "the live battle mounts at least one standing actor for recoil")
	for puppet in standing:
		_check(not puppet.recoiling() and is_equal_approx(puppet.recoil_shape(), 0.0)
			and is_equal_approx(puppet.recoil_pixels(), 0.0),
			"a standing actor starts at rest with no recoil: " + puppet.name)
		_check(not puppet.trigger_recoil(0.0) and not puppet.trigger_recoil(-0.5)
			and not puppet.recoiling(),
			"a zero or negative recoil span never starts a shake: " + puppet.name)
		_check(puppet.trigger_recoil(30.0) and puppet.recoiling()
			and puppet.recoil_span <= puppet.RECOIL_MAX_SECONDS,
			"one committed HP loss starts a recoil bounded to the approved span: " + puppet.name)
		puppet.cancel_recoil()
		var phase: float = puppet.idle_phase
		var rest_pose: Rect2 = puppet.posed_actor_rect()
		var idle_texture: Texture2D = puppet.current_texture()
		_check(not puppet.recoiling() and puppet.posed_actor_rect() == rest_pose,
			"cancelling a recoil returns the actor exactly to its idle drawing: " + puppet.name)
		_check(puppet.trigger_recoil(0.6) and puppet.recoiling() and not puppet.attacking(),
			"a committed HP loss starts exactly one recoil: " + puppet.name)
		puppet._process(puppet.recoil_span * 0.25)
		var peak: Rect2 = puppet.posed_actor_rect()
		var expected: float = -puppet.facing * puppet.recoil_back_pixels() * 0.75
		_check(puppet.recoiling() and absf(puppet.recoil_pixels() - expected) <= 0.01
			and absf(puppet.recoil_pixels()) >= 1.5,
			"the recoil shoves the drawn artwork by its own bounded amplitude: " + puppet.name)
		_check(absf(peak.get_center().x - rest_pose.get_center().x) >= 1.5
			and (peak.get_center().x - rest_pose.get_center().x) * puppet.facing < 0.0,
			"the recoil is kicked away from this actor's own facing: " + puppet.name)
		_check(puppet.pose_texture() == idle_texture,
			"a recoil alone draws the actor's own idle artwork: " + puppet.name)
		_check(puppet.get_global_rect() == puppet_rects[presenter._puppets.find(puppet)],
			"the complete actor target rectangle never moves during a recoil: " + puppet.name)
		# It combines with a committed lunge instead of replacing or cancelling it.
		_check(puppet.trigger_attack(0.6) and puppet.attacking() and puppet.recoiling(),
			"a recoil can overlap an active committed lunge: " + puppet.name)
		puppet._process(puppet.ATTACK_MAX_SECONDS / 2.0)
		var combined: Transform2D = puppet.idle_transform(Vector2.ZERO, 1.0)
		_check(puppet.attacking() and puppet.recoiling()
			and is_equal_approx(combined.origin.x, puppet.attack_lunge() + puppet.recoil_pixels())
			and absf(puppet.attack_lunge()) >= 1.0 and absf(puppet.recoil_pixels()) >= 0.5,
			"the shared drawing transform carries the lunge and the recoil together: " + puppet.name)
		puppet._process(puppet.RECOIL_MAX_SECONDS)
		_check(not puppet.recoiling() and is_equal_approx(puppet.recoil_span, 0.0)
			and is_equal_approx(puppet.recoil_pixels(), 0.0),
			"the recoil ends by itself within 0.6 s: " + puppet.name)
		puppet.cancel_attack()
		puppet.idle_phase = phase
		_check(puppet.posed_actor_rect() == rest_pose,
			"a settled recoil puts the artwork back exactly where it rested: " + puppet.name)
		puppet._process(0.1)
		_check(not puppet.recoiling() and is_equal_approx(puppet.recoil_shape(), 0.0),
			"a settled recoil never replays on later frames: " + puppet.name)
		puppet.idle_phase = phase
	# The drawn fallback (no supplied art at all) recoils exactly like supplied art.
	var host = standing[0]
	var host_phase: float = host.idle_phase
	var saved_id: String = host.actor_id
	var saved_idle: Texture2D = host.idle_texture
	var saved_attack: Texture2D = host.attack_texture
	host.bind_actor("fabricated_recoil_actor", {})
	_check(host.current_texture() == null and not host.recoiling(),
		"an actor without supplied art starts settled and unshaken")
	var drawn_rest: Rect2 = host.posed_fallback_rect()
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"an actor with no supplied art at all still performs the drawn recoil")
	host._process(host.recoil_span * 0.25)
	var drawn_peak: Rect2 = host.posed_fallback_rect()
	_check(drawn_peak != drawn_rest and absf(drawn_peak.get_center().x - drawn_rest.get_center().x) >= 1.5
		and (drawn_peak.get_center().x - drawn_rest.get_center().x) * host.facing < 0.0,
		"the drawn fallback puppet recoils exactly like a supplied image")
	host._process(host.RECOIL_MAX_SECONDS)
	host.idle_phase = host_phase
	_check(not host.recoiling() and host.posed_fallback_rect() == drawn_rest,
		"the drawn fallback settles exactly back to its rest pose")
	# A rebind drops a recoil in flight, so one actor never finishes another's shake.
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"a live recoil is in flight before the rebind")
	host.bind_actor(saved_id, {"idle": saved_idle, "attack": saved_attack})
	_check(not host.recoiling() and is_equal_approx(host.recoil_pixels(), 0.0)
		and host.actor_id == saved_id,
		"rebinding a different actor ID cancels the recoil in flight")
	host.idle_phase = host_phase
	# Presentation teardown settles every recoil immediately.
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"a live recoil is in flight before presentation teardown")
	presenter.cancel_poses()
	_check(not host.recoiling() and is_equal_approx(host.recoil_pixels(), 0.0),
		"presentation teardown settles every recoil immediately")
	host.idle_phase = host_phase
	# A fallen actor neither starts nor keeps a recoil.
	var saved_fallen: bool = host.fallen
	host.fallen = true
	_check(not host.trigger_recoil(0.6) and not host.recoiling(),
		"a fallen actor never starts a hit recoil")
	host.fallen = false
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"the same actor starts a recoil again once it stands")
	host.fallen = true
	host._process(0.1)
	_check(not host.recoiling() and is_equal_approx(host.recoil_pixels(), 0.0),
		"falling mid-recoil cancels it instead of leaving a stale shake")
	host.fallen = saved_fallen
	host.idle_phase = host_phase
	# Mounted lookup by side plus authoritative ID; anything else fails closed.
	var hero_host = presenter._puppets[0]
	var enemy_host = presenter._puppets[CombatParty.PARTY_SIZE]
	_check(not hero_host.actor_id.is_empty() and not enemy_host.actor_id.is_empty()
		and hero_host.actor_id != enemy_host.actor_id,
		"the live battle binds distinct authoritative hero and enemy IDs")
	_check(presenter.puppet_for("hero", hero_host.actor_id) == hero_host
		and presenter.puppet_for("enemy", enemy_host.actor_id) == enemy_host,
		"the mounted lookup resolves each side's own puppet by authoritative ID")
	_check(presenter.puppet_for("enemy", hero_host.actor_id) == null
		and presenter.puppet_for("hero", enemy_host.actor_id) == null
		and presenter.puppet_for("bogus", hero_host.actor_id) == null
		and presenter.puppet_for("hero", "") == null
		and presenter.puppet_for("hero", "fabricated_missing_actor") == null,
		"the mounted lookup fails closed for the wrong side, an unknown side and a stale ID")
	_check(presenter.hero_puppet(hero_host.actor_id) == hero_host
		and presenter.hero_puppet(enemy_host.actor_id) == null,
		"the existing hero lookup keeps its fail-closed identity")
	var duplicate = presenter._puppets[1]
	var duplicate_id: String = duplicate.actor_id
	duplicate.actor_id = hero_host.actor_id
	_check(presenter.puppet_for("hero", hero_host.actor_id) == null
		and presenter.hero_puppet(hero_host.actor_id) == null,
		"an ambiguous duplicate binding resolves no puppet instead of picking one")
	duplicate.actor_id = duplicate_id
	_check(presenter.puppet_for("hero", hero_host.actor_id) == hero_host,
		"restoring the binding restores the same mounted lookup")
	enemy_host.fallen = true
	_check(presenter.puppet_for("enemy", enemy_host.actor_id) == null,
		"a fallen actor's puppet is never resolved for a hit reaction")
	enemy_host.fallen = false
	# Source inspection: a bounded delta-driven draw pose, never a tween, timer or RNG.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var trigger_body := _function_body(source, "func trigger_recoil(")
	var advance_body := _function_body(source, "func advance_recoil(")
	var transform_body := _function_body(source, "func idle_transform(")
	var bind_body := _function_body(source, "func bind_actor(")
	var cancel_body := _function_body(source, "func cancel_poses() -> void:")
	_check(trigger_body.contains("recoil_span = clampf(") and trigger_body.contains("RECOIL_MAX_SECONDS")
		and trigger_body.contains("if fallen")
		and advance_body.contains("recoil_remaining = maxf(") and advance_body.contains("cancel_recoil()")
		and not trigger_body.contains("create_tween") and not advance_body.contains("create_tween")
		and not trigger_body.contains("Timer.new") and not advance_body.contains("Timer.new")
		and not trigger_body.contains("randi(") and not advance_body.contains("randf("),
		"the recoil is a bounded delta-driven state, never a tween, timer or RNG draw")
	_check(transform_body.contains("attack_lunge() + recoil_pixels()")
		and not transform_body.contains("position =") and not transform_body.contains("offset_"),
		"the one shared draw transform carries the recoil and never moves the Control")
	_check(bind_body.contains("cancel_recoil()") and cancel_body.contains("puppet.cancel_recoil()"),
		"a rebind and presentation teardown both drop a recoil in flight")
	# Every mounted control keeps its exact place, caption and target.
	var after_puppets: Array[Rect2] = []
	for puppet in presenter._puppets:
		after_puppets.append(puppet.get_global_rect())
	_check(after_puppets == puppet_rects, "no actor target rectangle moves during any recoil")
	var after_tags: Array[Rect2] = []
	var after_tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		after_tags.append(tag.get_global_rect())
		after_tag_texts.append(tag.text)
	for label in presenter._labels:
		after_tags.append(label.get_global_rect())
		after_tag_texts.append(label.text)
	_check(after_tags == tag_rects and after_tag_texts == tag_texts,
		"pinned hero and enemy names keep their exact place and text during recoils")
	var after_badges: Array[Rect2] = []
	var after_badge_texts: Array[String] = []
	for badge in presenter._badges:
		after_badges.append(badge.get_global_rect())
		after_badge_texts.append(badge.readable_text)
	_check(after_badges == badge_rects and after_badge_texts == badge_texts,
		"intent badges keep their exact place and caption during recoils")
	var after_controls: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		after_controls.append(control.get_global_rect())
	_check(after_controls == control_rects,
		"hand, actions and the enemy roster panel stay put during recoils")
	_check(_snapshot(app) == before,
		"a committed hit recoil changes no HP/Block, deck, energy, turn, intent or run RNG")
	_check(get_processed_tweens().size() == tweens,
		"the hit recoil creates no tween that outlives the frame")


## VIS V5 fall settle: a witnessed living-to-zero HP transition eases only that actor's
## drawn artwork from upright into the existing still fallen pose. `fallen` stays
## authoritative at once, every control, pinned name, intent badge and target rectangle
## keeps its exact place, and no combat value, deck, energy, intent or run RNG moves.
func _fall_settle(app, presenter) -> void:
	_check(is_instance_valid(presenter.panel) and presenter.enemies != null
		and not presenter._puppets.is_empty(),
		"fall settle checks run on every actual mounted actor")
	if not is_instance_valid(presenter.panel) or presenter.enemies == null or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var tweens: int = get_processed_tweens().size()
	var host = null
	for puppet in presenter._puppets:
		if puppet.facing < 0.0 and not puppet.fallen and not puppet.actor_id.is_empty():
			host = puppet
			break
	_check(host != null, "a living enemy puppet is mounted for the fall settle")
	if host == null:
		return
	var control_rect: Rect2 = host.get_global_rect()
	var label: Label = host.get_child(0) as Label
	var tag_rect: Rect2 = label.get_global_rect() if is_instance_valid(label) else Rect2()
	var tag_text: String = label.text if is_instance_valid(label) else ""
	var rest: Rect2 = host.posed_actor_rect()
	_check(not host.fallen and not host.settling_fall()
		and is_equal_approx(host.fallen_tilt(), 0.0) and is_equal_approx(host.fall_shape(), 1.0),
		"a standing actor is upright with no fall settle in flight")
	_check(not host.settle_fall(0.0) and not host.settle_fall(-0.5) and not host.settling_fall(),
		"a zero or negative fall span never starts a settle")
	# The transition itself: fallen is authoritative immediately, and the drawn tilt starts
	# upright so the artwork really eases into the existing fallen pose.
	var phase: float = host.idle_phase
	host.fallen = true
	_check(not host.trigger_attack(0.6) and not host.attacking()
		and not host.trigger_recoil(0.6) and not host.recoiling(),
		"a fallen actor rejects a committed pose and a hit recoil at once")
	_check(host.settle_fall(30.0) and host.settling_fall()
		and host.fall_span <= host.FALL_MAX_SECONDS and host.fall_span > 0.0,
		"one witnessed fall starts a settle bounded to the approved span")
	_check(is_equal_approx(host.fall_shape(), 0.0) and is_equal_approx(host.fallen_tilt(), 0.0)
		and host.posed_actor_rect().get_center().distance_to(rest.get_center()) <= 2.0,
		"the settling artwork starts upright, where the standing actor rested")
	var tilts: Array[float] = [0.0]
	for step in range(4):
		host._process(host.fall_span * 0.25 if step == 0 else 0.1)
		tilts.append(host.fallen_tilt())
		_check(host.posed_actor_rect().size.x > 0.0 and host.posed_actor_rect().size.y > 0.0,
			"the settling fall keeps drawing the actor's own artwork: " + host.name)
		_check(host.get_global_rect() == control_rect,
			"the settling fall never moves the actor target: " + host.name)
	var grew := true
	for index in range(1, tilts.size()):
		if absf(tilts[index]) <= absf(tilts[index - 1]) or absf(tilts[index]) > host.FALL_TILT + 0.001:
			grew = false
	_check(grew, "the drawn tilt eases monotonically into the existing fallen tilt")
	host._process(host.FALL_MAX_SECONDS)
	var settled: Rect2 = host.posed_actor_rect()
	_check(not host.settling_fall()
		and is_equal_approx(host.fallen_tilt(), -host.FALL_TILT * host.facing)
		and is_equal_approx(host.idle_bob(), 0.0),
		"the settled fall matches the existing still fallen tilt exactly")
	host._process(0.5)
	_check(host.posed_actor_rect() == settled and is_equal_approx(host.idle_phase, phase),
		"a settled fall leaves the artwork perfectly still with no idle motion")
	_check(is_instance_valid(label) and label.get_global_rect() == tag_rect
		and label.text == tag_text and label.is_visible_in_tree(),
		"the pinned name keeps its exact place and text through the fall: " + host.name)
	# The mounted lookup used for targeting keeps its fail-closed fallen rule, while the
	# fall reaction may still address exactly this actor by its own side and ID.
	_check(presenter.puppet_for("enemy", host.actor_id) == null
		and presenter.hero_puppet(host.actor_id) == null,
		"a fallen actor is still never resolved for targeting")
	_check(presenter.presented_puppet("enemy", host.actor_id) == host,
		"presentation still resolves exactly the fallen actor its own hit left mounted")
	_check(presenter.presented_puppet("hero", host.actor_id) == null
		and presenter.presented_puppet("bogus", host.actor_id) == null
		and presenter.presented_puppet("enemy", "") == null
		and presenter.presented_puppet("enemy", "fabricated_missing_actor") == null,
		"the presentation lookup fails closed for the wrong side, an unknown side and a stale ID")
	_check(presenter.presented_puppet("enemy", host.actor_id) == host
		and presenter.settle_fall("enemy", host.actor_id, 0.6) and host.settling_fall(),
		"the fall reaction and the presentation lookup agree on the same fallen puppet")
	_check(not presenter.settle_fall("hero", host.actor_id, 0.6)
		and not presenter.settle_fall("bogus", host.actor_id, 0.6)
		and not presenter.settle_fall("enemy", "", 0.6)
		and not presenter.settle_fall("enemy", "fabricated_missing_actor", 0.6),
		"the fall lookup fails closed for the wrong side, an unknown side and a stale ID")
	var duplicate = null
	for puppet in presenter._puppets:
		if puppet != host and is_equal_approx(puppet.facing, host.facing):
			duplicate = puppet
			break
	_check(duplicate != null, "a second puppet of the same side exists for the ambiguous binding")
	if duplicate != null:
		var duplicate_id: String = duplicate.actor_id
		duplicate.actor_id = host.actor_id
		_check(not presenter.settle_fall("enemy", host.actor_id, 0.6)
			and presenter.presented_puppet("enemy", host.actor_id) == null,
			"an ambiguous duplicate binding settles and presents no puppet")
		duplicate.actor_id = duplicate_id
	host.cancel_fall()
	_check(not host.settling_fall()
		and is_equal_approx(host.fallen_tilt(), -host.FALL_TILT * host.facing),
		"cancelling a settle leaves the existing still fallen pose")
	# Standing up drops the settle at once and the artwork is upright again.
	host.fallen = false
	host._process(0.1)
	_check(not host.settling_fall() and is_equal_approx(host.fallen_tilt(), 0.0),
		"a revived actor drops the fall settle and draws upright")
	host.idle_phase = phase
	# Rebind: a fresh actor ID never inherits another actor's settle.
	host.fallen = true
	_check(host.settle_fall(0.6) and host.settling_fall(),
		"a live fall settle is in flight before the rebind")
	host.bind_actor("fabricated_fall_actor", {})
	_check(not host.settling_fall(),
		"rebinding a different actor ID cancels the settle in flight")
	host.fallen = false
	host.bind_actor(String(presenter.enemies.get_enemy(host.slot).get("id")),
		presenter.art_for(String(presenter.enemies.get_enemy(host.slot).get("id"))))
	host.idle_phase = phase
	_check(is_equal_approx(host.fallen_tilt(), 0.0) and host.posed_actor_rect() != Rect2(),
		"the restored standing actor draws its own idle pose again")
	# Source inspection: the tilt is interpolated inside the one shared draw transform, with
	# no tween, timer, RNG or Control movement, and the fall is a bounded delta-driven state.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var transform_body := _function_body(source, "func idle_transform(")
	var fall_body := _function_body(source, "func advance_fall(")
	var tilt_body := _function_body(source, "func fallen_tilt(")
	var settle_body := _function_body(source, "func settle_fall(")
	_check(transform_body.contains("fallen_tilt()")
		and transform_body.contains("attack_lunge() + recoil_pixels()")
		and not transform_body.contains("position =") and not transform_body.contains("offset_"),
		"the one shared draw transform carries the settled fall and never moves the Control")
	_check(settle_body.contains("fall_span = clampf(") and settle_body.contains("FALL_MAX_SECONDS")
		and fall_body.contains("fall_remaining = maxf(") and fall_body.contains("cancel_fall()")
		and tilt_body.contains("-FALL_TILT * facing * fall_shape()"),
		"the fall is a bounded, delta-driven, facing-correct drawing state")
	_check(not settle_body.contains("create_tween") and not fall_body.contains("create_tween")
		and not settle_body.contains("Timer.new") and not fall_body.contains("Timer.new")
		and not settle_body.contains("randi(") and not fall_body.contains("randf(")
		and not transform_body.contains("create_tween"),
		"the fall settle draws no tween, timer or RNG")
	_check(_snapshot(app) == before,
		"the fall settle changes no HP/Block, deck, energy, turn, intent or run RNG")
	_check(get_processed_tweens().size() == tweens,
		"the fall settle creates no tween that outlives the frame")


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


## A downed or slain actor is authoritative at once: the existing tilt and tint, no idle
## motion and every attack/recoil rejection. Only the one bounded settling of the drawn
## artwork may run; it must end exactly at the existing still fallen pose and every target
## rectangle must stay fixed.
func _fallen_stillness(puppets: Array) -> void:
	for puppet in puppets:
		_check(puppet.fallen, "fallen stillness runs on a genuinely downed/slain actor: " + puppet.name)
		if not puppet.fallen:
			continue
		var phase: float = puppet.idle_phase
		var control_rect: Rect2 = puppet.get_global_rect()
		var immediate: Rect2 = puppet.posed_actor_rect()
		_check(not puppet.trigger_attack(0.6) and not puppet.attacking()
			and puppet.posed_actor_rect() == immediate,
			"a fallen actor never starts a committed attack pose: " + puppet.name)
		_check(not puppet.trigger_recoil(0.6) and not puppet.recoiling()
			and puppet.posed_actor_rect() == immediate,
			"a fallen actor never starts a hit recoil: " + puppet.name)
		_check(puppet.fall_span <= puppet.FALL_MAX_SECONDS,
			"a fall settle is bounded to the approved span: " + puppet.name)
		puppet._process(puppet.FALL_MAX_SECONDS)
		var pose: Rect2 = puppet.posed_actor_rect()
		_check(not puppet.settling_fall()
			and is_equal_approx(puppet.fallen_tilt(), -puppet.FALL_TILT * puppet.facing),
			"a settled fall ends exactly at the existing still fallen tilt: " + puppet.name)
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
		_check(puppet.get_global_rect() == control_rect,
			"falling never moves the actor's own control or target rectangle: " + puppet.name)
		_check(not puppet.trigger_attack(0.6) and not puppet.attacking()
			and puppet.posed_actor_rect() == pose,
			"a fallen actor never starts a committed attack pose: " + puppet.name)
		_check(not puppet.trigger_recoil(0.6) and not puppet.recoiling()
			and puppet.posed_actor_rect() == pose,
			"a fallen actor never starts a hit recoil: " + puppet.name)


## A freshly mounted battle builds new puppets that start their idle phase at rest.
func _at_rest(puppets: Array) -> bool:
	if puppets.is_empty():
		return false
	for puppet in puppets:
		if not is_instance_valid(puppet) or not is_equal_approx(puppet.idle_phase, 0.0):
			return false
	return true


## The authored front policy's living target, read from the real party.
func _front_target(app) -> int:
	for index in range(CombatParty.PARTY_SIZE):
		if app.party.get_hero(index + 1).hp > 0:
			return index + 1
	return 1


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
	_staging(app, presenter)
	_idle_motion(app, presenter)
	_attack_pose(app, presenter)
	_recoil(app, presenter)
	_fall_settle(app, presenter)
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
	_fight_areas(app, presenter, backdrop)
	var fight_path: String = BACKDROP_ART["Fight"]
	_check(backdrop.has_image() == ResourceLoader.exists(fight_path),
		"the mounted Fight image is shown only when the authored file is present")
	if backdrop.has_image():
		_check(backdrop.stage_texture.resource_path == fight_path,
			"the mounted Fight stage draws its own authored image")
	_ground_wash(presenter, backdrop, backdrop.has_image())
	_cover(app, presenter, backdrop)
	# The same stage is used by every admitted kind, so the authored Elite and Boss scenes
	# take the same wash, frame and cover geometry when they are installed.
	for kind in ["Elite", "Boss"]:
		backdrop.bind_battle(kind, presenter.backdrop_texture(kind))
		_check(backdrop.battle_kind == kind
			and backdrop.has_image() == ResourceLoader.exists(BACKDROP_ART[kind]),
			"the mounted stage admits the " + kind + " scene only when it is present")
		if backdrop.has_image():
			var typed_cover: Rect2 = backdrop.image_rect()
			_check(typed_cover.encloses(backdrop.view_rect())
				and is_equal_approx(typed_cover.size.x / typed_cover.size.y,
					backdrop.texture_size().x / backdrop.texture_size().y),
				"the " + kind + " scene keeps its cover-crop geometry on the live stage")
		_ground_wash(presenter, backdrop, backdrop.has_image())
	backdrop.bind_battle("Fight", presenter.backdrop_texture("Fight"))
	_check(backdrop.battle_kind == "Fight",
		"the live battle restores its own Fight scene after the typed scene check")
	_fallback(app, presenter, backdrop)


## The stage is laid in under the actors: about one fifth of dark over whichever ground was
## painted, then a soft edge vignette. Both live in the backdrop's own draw pass, behind
## every actor, ribbon, badge and hand card, and never tint them.
func _ground_wash(presenter, backdrop, image_ground: bool) -> void:
	var ground: Rect2 = backdrop.view_rect() if image_ground else backdrop.quilt_cloth()
	_check(ground.size.x > 0.0 and ground.size.y > 0.0
		and backdrop.dim_rect().is_equal_approx(ground),
		"the whole painted ground, not one actor box, receives the dim wash")
	var wash: Color = backdrop.dim_color()
	_check(is_equal_approx(wash.a, 0.2) and wash.r < 0.2 and wash.g < 0.2 and wash.b < 0.2,
		"both the authored scene and the drawn quilt fallback are dimmed by about one fifth")
	var bands: Array[Rect2] = backdrop.vignette_rects()
	_check(bands.size() == presenter.STAGE_VIGNETTE_STEPS * 4,
		"the vignette builds one soft band per edge step")
	var area: Rect2 = ground.grow(0.01)
	for band in bands:
		_check(band.size.x > 0.0 and band.size.y > 0.0 and area.encloses(band),
			"every vignette band stays inside the dimmed ground")
	_check(backdrop.vignette_alpha(0) > backdrop.vignette_alpha(presenter.STAGE_VIGNETTE_STEPS - 1)
		and backdrop.vignette_alpha(presenter.STAGE_VIGNETTE_STEPS - 1) > 0.0,
		"the vignette is darkest at the rim and still fades softly toward the middle")
	var center: Vector2 = ground.get_center()
	var covers_center := false
	for band in bands:
		if band.has_point(center):
			covers_center = true
	_check(not covers_center, "vignette bands leave the middle of the stage clear for the actors")
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and backdrop.focus_mode == Control.FOCUS_NONE and backdrop.get_index() == 0,
		"the wash and vignette live in the input-inert stage behind every battle control")


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
	_ground_wash(presenter, backdrop, false)
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
	# Ordering: the painted ground is laid in before the hem, and the actor pass never
	# applies the stage wash, so only the backdrop is tinted.
	_check(draw_body.find("_draw_backdrop_image()") >= 0
		and draw_body.find("_draw_quilt()") >= 0
		and draw_body.find("_draw_dim()") > draw_body.find("_draw_backdrop_image()")
		and draw_body.find("_draw_dim()") > draw_body.find("_draw_quilt()")
		and draw_body.find("_draw_vignette()") > draw_body.find("_draw_dim()")
		and draw_body.find("_draw_ground_hem()") > draw_body.find("_draw_vignette()"),
		"source dims and vignettes the painted ground before the hem and every actor")
	var puppet_draw := _function_body(source, "func _draw() -> void:")
	_check(not puppet_draw.contains("_draw_dim") and not puppet_draw.contains("vignette"),
		"the actor draw pass never applies the stage wash or vignette to itself")
	backdrop.bind_battle("Fight", presenter.backdrop_texture("Fight"))
	_check(backdrop.battle_kind == "Fight"
		and backdrop.has_image() == ResourceLoader.exists(BACKDROP_ART["Fight"]),
		"the live battle restores its own backdrop after the fallback check")
	_ground_wash(presenter, backdrop, backdrop.has_image())


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
			_assert_badges(app, presenter, _front_target(app))
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
			_assert_badges(app, presenter, _front_target(app))
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
	file.store_string(JSON.stringify([{"id": "first", "name": "First", "max_hp": 3, "art_path": "unused",
		"intent": {"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 1}]}},
		{"id": "second", "name": "Second", "max_hp": 7, "art_path": "unused",
		"intent": {"target": "front", "actions": [{"type": "block", "amount": 1, "weight": 1}]}}]))
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
	_staging(app, presenter)
	_idle_motion(app, presenter, true)
	_attack_pose(app, presenter)
	_fall_settle(app, presenter)
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
		and app.enemy_intents._turn_index == 1
		and app.enemy_attacks == app.enemy_intents.get_intents(),
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
	var route_floor: int = int(app.run_map.get_node(app.run_map.get_current_node_id()).get("floor", 0))
	var stage_path: String = ROSTER_ART.stage_backdrop_path(route_kind, route_floor)
	_check(route_kind == "Fight" and is_instance_valid(presenter.backdrop)
		and presenter.backdrop.battle_kind == route_kind
		and stage_path == ROSTER_ART.fight_backdrop_path(route_floor)
		and presenter.backdrop.has_image() == ResourceLoader.exists(stage_path)
		and presenter.backdrop.stage_texture.resource_path == stage_path,
		"the seeded routed fight takes its backdrop from its real admitted floor")
	# The same one stage refreshes its scene when a new Fight is admitted on another
	# area floor, instead of comparing only the unchanged kind.
	var stage_id: int = presenter.backdrop.get_instance_id()
	var installed: Array[String] = []
	for floor_number in [4, 7, 10, 1]:
		app.run_map._nodes[app.run_map.get_current_node_id()].floor = floor_number
		presenter._sync_battle()
		var path: String = ROSTER_ART.fight_backdrop_path(floor_number)
		installed.append(path)
		_check(presenter.backdrop.get_instance_id() == stage_id
			and presenter.backdrop.battle_kind == "Fight"
			and presenter.backdrop.has_image() == ResourceLoader.exists(path)
			and presenter.backdrop.stage_texture.resource_path == path,
			"admitted floor %d refreshes the one Fight stage to its own area" % floor_number)
	app.run_map._nodes[app.run_map.get_current_node_id()].floor = route_floor
	presenter._sync_battle()
	_check(presenter.backdrop.get_instance_id() == stage_id
		and presenter.backdrop.stage_texture.resource_path == stage_path,
		"restoring the admitted floor returns the same stage to its own scene")
	_check(installed.size() == 4 and installed[0] != installed[1] and installed[1] != installed[2]
		and installed[2] != installed[3] and installed[3] == stage_path,
		"woods, marsh, peaks and its own meadow were really installed in turn")
	var before := _snapshot(app)
	var meters = app.get_node("LiveCombatMeters").row
	_check(presenter._puppets.size() == 6 and presenter._labels.size() == 3
		and meters.get_child_count() == 6, "mounted typed path has every puppet, target and real meter")
	_assert_actor_art(app, presenter)
	_staging(app, presenter)
	_idle_motion(app, presenter)
	_attack_pose(app, presenter)
	_recoil(app, presenter)
	_fall_settle(app, presenter)
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
	_policy_cue_cases(app, presenter)
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


## Real mounted seeded fight, swapping only test fixture metadata to bind four
## fresh, deterministic authored policies to the same original enemy slots.
func _policy_cue_cases(app, presenter) -> void:
	var old_intents: CombatEnemyIntents = app.enemy_intents
	var flow: CombatRoundFlow = app.round_flow
	var old_unravel: CombatUnravel = flow._unravel
	var old_roster: Array[Dictionary] = app.enemies.get_enemies()
	var old_rng: int = app.run_rng.state
	var before: Array = _snapshot(app)
	_check(old_intents != null and old_intents.is_bound() and old_roster.size() == 3
		and presenter._badges.size() == 3 and flow._started
		and presenter._bound_unravel(app) != null,
		"seeded live-policy fixture has bound scheduler, original slots and gauge")
	if not old_intents.is_bound() or old_roster.size() != 3 or presenter._bound_unravel(app) == null:
		return
	var patterns: Array = old_intents._definitions.duplicate(true)
	var types := [
		{"type": "attack", "amount": 4},
		{"type": "debuff", "amount": 2, "status": "exposed"},
		{"type": "shove", "amount": 0, "direction": 1},
		{"type": "attack", "amount": 5},
	]
	for policy_index in range(CombatEnemyIntents.TARGET_POLICIES.size()):
		var policy: String = CombatEnemyIntents.TARGET_POLICIES[policy_index]
		var first: Dictionary = types[policy_index].duplicate(true)
		first["weight"] = 1
		var extras := [
			{"type": "block", "amount": 2, "weight": 1},
			{"type": "buff", "amount": 2, "weight": 1},
		]
		app.enemies._enemies[0]["intent"] = {"target": policy, "actions": [first]}
		for index in range(1, 3):
			app.enemies._enemies[index]["intent"] = {"target": "front", "actions": [extras[index - 1]]}
		var schedule := CombatEnemyIntents.new(patterns)
		_check(schedule.bind_battle(app.enemies, app.party, app.run_rng),
			"test-authored %s schedule binds to the actual mounted roster and run RNG" % policy)
		if not schedule.is_bound():
			continue
		app.enemy_intents = schedule
		flow._intents = schedule
		flow._battle_intents = schedule
		var cached: Array[Dictionary] = schedule.get_intents()
		var state: int = app.run_rng.state
		presenter._refresh()
		for position in range(1, 4):
			var badge = presenter._badges[position - 1]
			var action: Dictionary = cached[position - 1]
			var expected_policy := CombatEnemyIntents.policy_for(app.enemies, position)
			var target: int = action.get("target_position", 0)
			var original_caption := ""
			match action.type:
				"attack": original_caption = "ATK %d > H%d" % [action.amount, target]
				"block": original_caption = "BLOCK +%d" % action.amount
				"buff": original_caption = "BUFF +%d BLK" % action.amount
				"debuff": original_caption = "%s %d > H%d" % [action.status.to_upper(), action.amount, target]
				"shove": original_caption = "H%d %s" % [target, "PUSH BACK" if action.direction == 1 else "PUSH FRONT"]
			var expected_cue: String = LiveEnemyIntentBadge.POLICY_LABELS.get(expected_policy, "") \
				if action.type in ["attack", "debuff", "shove"] else ""
			_check(badge.policy_cue == expected_cue and badge.readable_text == original_caption
				and badge.intent_type == action.type and badge.amount == action.amount
				and badge.target_position == target and badge.source_position == position,
				"%s action preserves exact caption/target and policy_for original slot %d" % [policy, position])
		for repeat in range(4):
			presenter._refresh()
		_check(schedule.get_intents() == cached and app.run_rng.state == state,
			"repeated policy read is cache/RNG-inert for %s" % policy)
		if policy_index == 0:
			var skip := CombatUnravel.new()
			_check(skip.bind_roster(app.enemies, {1: "normal", 2: "normal", 3: "normal"})
				and skip.apply_unravel(app.enemies, 1, 8), "fixture binds an authentic pending skip")
			flow._unravel = skip
			presenter._refresh()
			_check(presenter._badges[0].policy_cue.is_empty()
				and presenter._badges[0].readable_text == "UNRAVELLED",
				"pending skip suppresses both real policy and action")
			flow._unravel = old_unravel
			presenter._refresh()
			_check(presenter._badges[0].policy_cue == "FRONT", "cleared skip restores authored policy")
			_check(app.enemies.apply_damage(1, 999), "test fixture slays actual original enemy")
			presenter._refresh()
			_check(presenter._badges[0].policy_cue.is_empty()
				and presenter._badges[0].readable_text == "SLAIN",
				"slain cue overrides bound policy")
			app.enemies._enemies.assign(old_roster.duplicate(true))
			app.enemies._enemies[0]["intent"] = {"target": "front", "actions": [first]}
			presenter._refresh()
			_check(presenter._badges[0].policy_cue == "FRONT", "restored living source has cue")
	# An unbound legacy schedule and a missing authority never invent a policy.
	var legacy := CombatEnemyIntents.new(patterns)
	app.enemy_intents = legacy
	flow._intents = legacy
	flow._battle_intents = legacy
	presenter._refresh()
	_check(presenter._badges[0].policy_cue.is_empty(), "unbound fixture has no target-policy cue")
	app.enemy_intents = null
	presenter._refresh()
	_check(presenter._badges[0].policy_cue.is_empty(), "missing scheduler cannot retain a stale cue")
	app.enemies._enemies.assign(old_roster.duplicate(true))
	app.enemy_intents = old_intents
	flow._intents = old_intents
	flow._battle_intents = old_intents
	flow._unravel = old_unravel
	app.run_rng.state = old_rng
	presenter._refresh()
	_check(_snapshot(app) == before and app.enemy_intents == old_intents,
		"policy fixture restores HP, Block, statuses, deck, energy, original cached schedule and RNG")


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
