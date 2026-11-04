extends SceneTree
## Visual-only stage profiles and mounted title/fight/return reuse. All RNG
## comparisons are against real authorities, never seeded cosmetic sampling.
## The atmosphere is texture-only: no particle emitter may exist anywhere in it.

const AMBIENT := preload("res://scripts/live_battle_ambient.gd")
const AMBIENT_SOURCE := "res://scripts/live_battle_ambient.gd"
var failures: Array[String] = []
var checks := 0
var app
var juice
var had_motion_setting := false
var saved_motion_setting: Variant


func _initialize() -> void:
	_run.call_deferred()


func _check(valid: bool, reason: String) -> void:
	checks += 1
	if not valid:
		failures.append(reason)


func _frames() -> void:
	for i in range(3):
		await process_frame


func _click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		root.push_input(event, true)
	await _frames()


## Every particle emitter under (never including) the given node.
func _particles(of: Node) -> Array:
	var found: Array = []
	for kind in ["CPUParticles2D", "GPUParticles2D"]:
		for child in of.find_children("*", kind, true, false):
			found.append(child)
	return found


func _snapshot() -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(),
		app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.run_rng.seed, app.run_rng.state, app.enemy_intents.get_intents(),
		app.enemy_attacks.duplicate(true), app.enemy_intents._turn_index,
		app.session_gold]


func _select_fight() -> bool:
	for candidate in range(1, 25):
		app.run_seed = candidate
		await _click(app.start_button)
		preload("res://tests/party_choice.gd").choose(app)
		var selected: Button = null
		if app.run_map != null:
			for id in app.run_map.get_legal_choices():
				if app.run_map.get_node(id).get("type") != "Fight":
					continue
				for button in app.route_buttons:
					if button.get_meta("route_id") == id and not button.disabled:
						selected = button
						break
				if selected != null:
					break
		if selected != null:
			await _click(selected)
			if app.deck != null and app.party != null and app.enemies != null \
					and is_instance_valid(app.battle_view):
				return true
		app._return_to_title()
		await _frames()
	return false


func _profiles() -> void:
	var sample = AMBIENT.new()
	root.add_child(sample)
	seed(76543)
	var next_random: int = randi()
	seed(76543)
	var expected := [
		["Fight", 0, "pollen"], ["Fight", 1, "pollen"],
		["Fight", 3, "pollen"], ["Fight", 4, "leaves"],
		["Fight", 6, "leaves"], ["Fight", 7, "fireflies"],
		["Fight", 9, "fireflies"], ["Fight", 10, "snow"],
		["Fight", 11, "snow"], ["Elite", 5, "ash"], ["Boss", 12, "scraps"],
	]
	for row in expected:
		_check(AMBIENT.profile_for(row[0], row[1]) == row[2],
			"admitted %s floor %d selects %s" % row)
		_check(sample.configure(row[0], row[1], false) and sample.profile == row[2]
			and sample.visible_budget() == sample.NORMAL_BUDGET
			and sample.get_child_count() == 0 and _particles(sample).is_empty(),
			"each authored area configures a texture-only atmosphere with no emitter nodes")
		_geometry(sample, String(row[2]))
		_added_geometry(String(row[2]))
	for row in [["Fight", -1], ["Fight", 12], ["Elite", -1], ["Elite", 0],
			["Elite", 12], ["Boss", -1], ["Boss", 0], ["Boss", 11],
			["Boss", 13], ["Rest", 5], ["", 5]]:
		_check(AMBIENT.profile_for(row[0], row[1]).is_empty()
			and not sample.configure(row[0], row[1], false)
			and sample.profile.is_empty() and sample.visible_budget() == 0
			and sample.motif_metadata().is_empty() and not sample.visible
			and sample.get_child_count() == 0 and _particles(sample).is_empty(),
			"invalid routed scene %s floor %d remains without ambience" % row)
	_check(randi() == next_random,
		"all six profile activations and rejected mappings avoid the global RNG")
	var source := FileAccess.get_file_as_string(AMBIENT_SOURCE)
	_check(not source.is_empty() and not source.contains("Particles2D")
		and not source.contains("ParticleProcessMaterial")
		and source.contains("draw_texture_rect(light_texture")
		and source.contains("draw_texture_rect(felt_texture")
		and source.contains("if light_texture != null:")
		and source.contains("if felt_texture != null:"),
		"renderer preserves both original authored images and constructs no emitter")
	for texture in ["fluff_texture", "wisp_texture", "vignette_texture"]:
		_check(source.contains("draw_texture_rect(" + texture)
			and source.contains("if " + texture + " != null:")
			and source.contains(texture + " = _load_texture("),
			"optional image is cached once and drawn only when available: " + texture)
	_check(not source.contains("draw_rect(") and not source.contains("draw_circle(")
		and not source.contains("RandomNumberGenerator") and not source.contains("rand"),
		"stage dressing uses only textures and deterministic arithmetic")
	sample.retire()
	sample.free()


func _geometry(layer, family: String) -> void:
	var bounds := Vector2(1000, 300)
	var initial: Array = AMBIENT.motifs_for(family, bounds, 0.0, false)
	_check(initial.size() == 30 and layer.visible_budget() == layer.NORMAL_BUDGET,
		"normal budget includes thirty texture placements")
	_check(initial == AMBIENT.motifs_for(family, bounds, 0.0, false),
		"pure texture placement repeats exactly")
	for time in [0.0, 1.0, 30.0, 60.0, 119.99, 120.0, 100000.0]:
		var marks: Array = AMBIENT.motifs_for(family, bounds, time, false)
		_check(marks.size() == 30, "motion retains thirty texture placements")
		for mark in marks:
			var rect: Rect2 = mark["rect"]
			_check(Rect2(Vector2.ZERO, bounds).encloses(rect)
				and rect.get_center().is_equal_approx(mark["center"]),
				"whole drifting image stays inside the stage")
			_check(rect.size.x >= 6.0 and rect.size.x <= 14.0 and rect.size.x == rect.size.y,
				"felt texture remains six to fourteen pixels across")
			var tint: Color = mark["color"]
			var palette: Color = AMBIENT.PROFILE_COLORS[family]
			_check(tint.r == palette.r and tint.g == palette.g and tint.b == palette.b
				and tint.a >= 0.36 and tint.a <= 0.72,
				"felt fades subtly within its admitted palette")
	var reduced: Array = AMBIENT.motifs_for(family, bounds, 0.0, true)
	_check(reduced.size() == 7 and reduced[0]["color"].a < initial[0]["color"].a,
		"Fast reduces texture count and opacity")
	var moving: Array = AMBIENT.motifs_for(family, bounds, 1.0, false)
	var fast_moving: Array = AMBIENT.motifs_for(family, bounds, 1.0, true)
	var normal_distance: float = initial[0]["center"].distance_to(moving[0]["center"])
	_check(normal_distance > 0.0 and normal_distance < 1.0
		and reduced[0]["center"].distance_to(fast_moving[0]["center"]) < normal_distance
		and initial[0]["color"].a != moving[0]["color"].a,
		"texture sway and fading advance slowly, with attenuated Fast drift")
	_check(AMBIENT.light_alpha(0.0, false) != AMBIENT.light_alpha(1.0, false)
		and AMBIENT.light_alpha(1.0, true) < AMBIENT.light_alpha(1.0, false),
		"warm image pulses and dims in Fast")
	_check(layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"texture rendering creates no extra or particle nodes")
	initial[0]["rect"] = Rect2(9999, 9999, 1, 1)
	_check(AMBIENT.motifs_for(family, bounds, 0.0, false)[0]["rect"] != initial[0]["rect"],
		"returned placement cannot mutate subsequent draws")
	_check(AMBIENT.motifs_for("invalid", bounds, 0.0, false).is_empty()
		and AMBIENT.motifs_for(family, Vector2(39, 39), 0.0, false).is_empty(),
		"invalid profiles and tiny bounds have no texture placement")


func _added_geometry(family: String) -> void:
	for bounds in [Vector2(40, 40), Vector2(1000, 300), Vector2(1280, 720)]:
		for art in ["fluff", "wisp"]:
			for image_size in [Vector2(120, 60), Vector2(30, 150)]:
				var initial: Array = AMBIENT.drifts_for(family, art, bounds, 0.0, false, image_size)
				var reduced: Array = AMBIENT.drifts_for(family, art, bounds, 0.0, true, image_size)
				_check(initial.size() == (6 if art == "fluff" else 4)
					and reduced.size() == (2 if art == "fluff" else 1), "added art has finite normal/Fast budgets")
				for time in [-1.0, 0.0, 1.0, 60.0, 119.99, 120.0, 100000.0]:
					for fast_mode in [false, true]:
						var marks: Array = AMBIENT.drifts_for(family, art, bounds, time, fast_mode, image_size)
						_check(marks == AMBIENT.drifts_for(family, art, bounds, time, fast_mode, image_size),
							"added placement repeats exactly")
						for mark in marks:
							var rect: Rect2 = mark["rect"]
							_check(Rect2(Vector2.ZERO, bounds).encloses(rect) and rect.end.y < bounds.y * 0.60
								and is_equal_approx(rect.size.x / rect.size.y, image_size.x / image_size.y)
								and mark["color"].a > 0 and mark["color"].a <= (0.10 if fast_mode else 0.24),
								"complete aspect-safe faint sprite stays above feet/HUD")
				var moving: Array = AMBIENT.drifts_for(family, art, bounds, 1.0, false, image_size)
				var fast_moving: Array = AMBIENT.drifts_for(family, art, bounds, 1.0, true, image_size)
				var distance: float = initial[0]["rect"].position.distance_to(moving[0]["rect"].position)
				_check(distance > 0 and reduced[0]["rect"].position.distance_to(fast_moving[0]["rect"].position) < distance
					and reduced[0]["color"].a < initial[0]["color"].a, "Fast dims and attenuates added drift")
		var shade: Dictionary = AMBIENT.vignette_for(family, bounds, false, Vector2(1600, 900))
		_check(not shade.is_empty() and Rect2(Vector2.ZERO, bounds).encloses(shade["rect"])
			and is_equal_approx(shade["rect"].size.aspect(), 1600.0 / 900.0)
			and is_equal_approx(shade["color"].a, 0.10)
			and is_equal_approx(AMBIENT.vignette_for(family, bounds, true, Vector2(1600, 900))["color"].a, 0.05),
			"vignette fits stage without stretching and remains faint in both modes")
	for row in [["invalid", "fluff", Vector2(1000, 300), Vector2.ONE],
			[family, "bad", Vector2(1000, 300), Vector2.ONE],
			[family, "wisp", Vector2(39, 300), Vector2.ONE],
			[family, "fluff", Vector2(1000, 300), Vector2.ZERO]]:
		_check(AMBIENT.drifts_for(row[0], row[1], row[2], 0.0, false, row[3]).is_empty(),
			"invalid art/profile/extent fails closed")
	_check(AMBIENT.vignette_for("invalid", Vector2(1000, 300), false, Vector2.ONE).is_empty()
		and AMBIENT.vignette_for(family, Vector2(39, 300), false, Vector2.ONE).is_empty()
		and AMBIENT.vignette_for(family, Vector2(1000, 300), false, Vector2.ZERO).is_empty(),
		"invalid vignette inputs fail closed")


func _textures(layer) -> void:
	for entry in [[AMBIENT.FELT_PATH, layer.felt_texture], [AMBIENT.LIGHT_PATH, layer.light_texture],
			[AMBIENT.FLUFF_PATH, layer.fluff_texture], [AMBIENT.WISP_PATH, layer.wisp_texture],
			[AMBIENT.VIGNETTE_PATH, layer.vignette_texture]]:
		if FileAccess.file_exists(entry[0]):
			_check(entry[1] is Texture2D and entry[1].resource_path == entry[0]
				and entry[1].get_width() > 0 and entry[1].get_height() > 0,
				"supplied art is an admitted imported texture: " + entry[0])
	_check(layer.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"texture-only layer keeps linear filtering and owns no particle node")
	_check(AMBIENT._load_texture("res://assets/paper/vfx/unavailable_ambient.png") == null,
		"missing optional texture fails quietly")


func _mounted() -> void:
	var roster = app.get_node_or_null("LiveEnemyRoster")
	_check(is_instance_valid(roster) and is_instance_valid(roster.backdrop)
		and roster.backdrop.has_image(), "live fight has a mounted authored roster backdrop")
	if not is_instance_valid(roster) or not is_instance_valid(roster.backdrop):
		return
	var layer = juice.ambient
	_check(juice.bound and layer.get_parent() == app.battle_view
		and layer.profile == AMBIENT.profile_for(roster._backdrop_kind,
			roster._backdrop_floor) and not layer.profile.is_empty(),
		"actual battle admission wires its roster-approved area into ambience")
	_check(layer.get_index() == roster.backdrop.get_index() + 1
		and layer.get_global_rect() == roster.backdrop.get_global_rect()
		and layer.size.x > 900.0 and layer.size.y > 200.0,
		"one correctly sized ambient is immediately above the backdrop: index=%d/%d, size=%s, battle=%s" % [layer.get_index(), roster.backdrop.get_index(), layer.size, app.battle_view.size])
	var actor_branch: Node = roster.battle_row
	_check(is_instance_valid(actor_branch) and actor_branch.is_ancestor_of(app.hero_view),
		"real stage row contains the hero actors")
	while actor_branch.get_parent() != app.battle_view:
		actor_branch = actor_branch.get_parent()
	_check(layer.get_index() < actor_branch.get_index(),
		"light and felt render behind both actor rows")
	_check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and layer.focus_mode == Control.FOCUS_NONE
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"mounted ambience owns no particle node and cannot take input")
	_textures(layer)
	_check(layer.visible_budget() == layer.NORMAL_BUDGET
		and layer.motif_metadata().size() == 30
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"normal atmosphere is visibly active with thirty drawn marks and no emitter")
	for mark in layer.motif_metadata():
		_check(Rect2(Vector2.ZERO, layer.size).encloses(mark["rect"]),
			"real 1280x720 stage contains each complete felt image")
	_check(app.battle_view.find_children("LiveBattleAmbient", "Control", true, false).size() == 1,
		"only one ambient layer belongs to the mounted stage")
	var state := _snapshot()
	var receipt_count: int = juice.history.size()
	var flights: int = juice.flight_history.size()
	var cues: int = juice.live_cues()
	var global_sample: int
	seed(119837)
	global_sample = randi()
	seed(119837)
	for repeat in range(5):
		juice._sync()
		layer._process(0.016)
		layer.queue_redraw()
		await process_frame
	var saved_felt = layer.felt_texture
	var saved_light = layer.light_texture
	var saved_added := [layer.fluff_texture, layer.wisp_texture, layer.vignette_texture]
	# Exercise the real draw path even before the art pipeline supplies the files.
	# A temporary texture stays in memory; no image assets are created or edited.
	var placeholder := GradientTexture2D.new()
	placeholder.width = 120
	placeholder.height = 60
	layer.fluff_texture = placeholder
	layer.wisp_texture = placeholder
	layer.vignette_texture = placeholder
	_check(layer.added_metadata().size() == 11, "mounted normal draw admits all three optional art families")
	layer.queue_redraw()
	await process_frame
	layer.set_fast(true)
	_check(layer.added_metadata().size() == 4, "mounted Fast thins added art on the same layer")
	layer.queue_redraw()
	await process_frame
	layer.set_fast(false)
	layer.fluff_texture = null
	_check(layer.added_metadata().size() == 5, "missing fluff preserves wisps and vignette")
	layer.wisp_texture = null
	_check(layer.added_metadata().size() == 1, "missing wisps preserves vignette")
	layer.vignette_texture = null
	layer.felt_texture = null
	layer.light_texture = null
	_check(layer.configure(roster._backdrop_kind, roster._backdrop_floor, false)
		and layer.felt_texture == null and layer.light_texture == null
		and layer.profile == AMBIENT.profile_for(roster._backdrop_kind, roster._backdrop_floor)
		and layer.added_metadata().is_empty()
		and layer.motif_metadata().size() == 30
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"admitted battle with missing textures quietly draws no image family")
	layer.queue_redraw()
	await process_frame
	layer.felt_texture = saved_felt
	layer.light_texture = saved_light
	layer.fluff_texture = saved_added[0]
	layer.wisp_texture = saved_added[1]
	layer.vignette_texture = saved_added[2]
	_check(not layer.configure("Rest", 5, false) and not layer.visible
		and layer.profile.is_empty() and layer.motif_metadata().is_empty()
		and layer.added_metadata().is_empty()
		and layer.visible_budget() == 0
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"invalid route retires real mounted ambience")
	juice._sync()
	_check(layer.profile == AMBIENT.profile_for(roster._backdrop_kind, roster._backdrop_floor)
		and layer.felt_texture == saved_felt and layer.light_texture == saved_light
		and [layer.fluff_texture, layer.wisp_texture, layer.vignette_texture] == saved_added
		and layer.visible_budget() == layer.NORMAL_BUDGET
		and layer.motif_metadata().size() == 30,
		"authentic route restores cached resources and thirty drawn marks")
	_check(_snapshot() == state and juice.history.size() == receipt_count
		and juice.flight_history.size() == flights and juice.live_cues() == cues,
		"repeated visual refresh consumes no party/deck/enemy/run state or gameplay cue")
	_check(randi() == global_sample, "refresh does not consume even Godot's global RNG")
	# Real mounted toggle: Fast only thins and dims this same texture layer.
	var normal_alpha: float = layer.motif_metadata()[0]["color"].a
	seed(58231)
	global_sample = randi()
	seed(58231)
	await _click(juice.fast_button)
	var fast_marks: Array = layer.motif_metadata()
	_check(juice.fast_animations and layer.fast
		and layer.visible_budget() == layer.FAST_BUDGET
		and layer.visible_budget() < layer.NORMAL_BUDGET
		and fast_marks.size() == 7 and fast_marks[0]["color"].a < normal_alpha
		and AMBIENT.light_alpha(layer._time, true) < AMBIENT.light_alpha(layer._time, false)
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"Fast keeps the same texture layer with fewer, dimmer marks")
	_check(_snapshot() == state, "Fast does not change real combat or its seeded RNG")
	await _click(juice.fast_button)
	_check(not juice.fast_animations and not layer.fast
		and layer.visible_budget() == layer.NORMAL_BUDGET
		and layer.motif_metadata().size() == 30
		and layer.get_child_count() == 0 and _particles(layer).is_empty()
		and _snapshot() == state,
		"normal mode restores bounded decor without a gameplay mutation")
	# Pointer motion over the light's own hero-side center must hit the underlying UI.
	var motion := InputEventMouseMotion.new()
	motion.position = layer.get_global_rect().position + layer.size * Vector2(0.26, 0.62)
	root.push_input(motion, true)
	await process_frame
	_check(root.gui_get_hovered_control() != layer,
		"hero-side glow never intercepts a real pointer hit test")
	_check(randi() == global_sample, "real Fast toggles and drawing avoid global RNG drift")
	await _reduced_motion(layer, roster)


func _visual_frame(layer) -> Array:
	return [layer.motif_metadata(), layer.added_metadata(), layer.critter_metadata(),
		AMBIENT.light_alpha(layer._time, layer.fast)]


func _reduced_motion(layer, roster) -> void:
	_check(layer.is_visible_in_tree() and layer.is_processing() and layer.size.x > 900.0,
		"reduced-motion witness is the actual visible running battle renderer")
	var state := _snapshot()
	var hit_rects := [layer.get_global_rect(), app.hero_view.get_global_rect(),
		juice.fast_button.get_global_rect()]
	var saved_added := [layer.fluff_texture, layer.wisp_texture, layer.vignette_texture]
	var saved_strips: Dictionary = layer.critter_strips.duplicate()
	# In-memory witnesses ensure optional art and multi-cell critters exercise
	# metadata even before the art pipeline provides a particular strip.
	var texture := GradientTexture2D.new()
	texture.width = 480
	texture.height = 60
	layer.fluff_texture = texture
	layer.wisp_texture = texture
	layer.vignette_texture = texture
	for family in AMBIENT.CRITTERS.PLACEMENTS:
		for spot in AMBIENT.CRITTERS.PLACEMENTS[family]:
			layer.critter_strips[spot[0]] = texture
	seed(39271)
	var next_global := randi()
	seed(39271)
	for fast_mode in [false, true]:
		juice.fast_animations = fast_mode
		juice._sync()
		layer._process(0.37)
		_check(layer._time > 0.0 and not layer.critter_metadata().is_empty()
			and layer.added_metadata().size() == (4 if fast_mode else 11),
			"all atmospheric families have nonempty mounted witnesses before toggle")
		ProjectSettings.set_setting("accessibility/reduced_motion", true)
		# Direct ticks must obey the setting even before the next frame watcher.
		layer._process(3.0)
		var neutral := _visual_frame(layer)
		_check(layer._time == 0.0 and not layer.is_processing()
			and layer.is_visible_in_tree() and not layer.profile.is_empty()
			and neutral[0] == AMBIENT.motifs_for(layer.profile, layer.size, 0.0, fast_mode)
			and layer.visible_budget() == (7 if fast_mode else 30),
			"mid-flight reduced motion resets to authored zero without removing art or budget")
		await _frames()
		layer._process(91.0)
		_check(_visual_frame(layer) == neutral and layer._time == 0.0,
			"elapsed frames and direct ticks preserve motifs, drifts, critters and light")
		_check(layer.configure(roster._backdrop_kind, roster._backdrop_floor, fast_mode)
			and _visual_frame(layer) == neutral and not layer.is_processing(),
			"same-scene refresh cannot restart a reduced-motion clock")
		ProjectSettings.set_setting("accessibility/reduced_motion", false)
		await _frames()
		_check(layer.is_processing() and layer._time > 0.0 and _visual_frame(layer) != neutral,
			"setting alone rearms deterministic movement on the same layer")
		_check(layer.motif_metadata() == AMBIENT.motifs_for(layer.profile, layer.size,
			layer._time, fast_mode), "resumed motion retains original placement arithmetic")
	# A setting-only toggle must also stop the real processor without manual ticks.
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	await _frames()
	_check(layer._time == 0.0 and not layer.is_processing(),
		"mounted frame watcher observes runtime setting changes without host refresh")
	app.battle_view.hide()
	await _frames()
	app.battle_view.show()
	await _frames()
	_check(layer.is_visible_in_tree() and layer._time == 0.0 and not layer.is_processing(),
		"show while reduced motion remains enabled preserves the neutral frame")
	app.battle_view.hide()
	await _frames()
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	layer._process(7.0)
	_check(not layer.is_visible_in_tree() and not layer.is_processing() and layer._time == 0.0
		and not process_frame.is_connected(layer._sync_motion),
		"hidden ancestor leaves neither animation nor a setting poll active")
	app.battle_view.show()
	await _frames()
	_check(layer.is_visible_in_tree() and layer.is_processing() and layer._time > 0.0,
		"show after hidden setting toggle rearms the original renderer")
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	layer.configure_visit_scraps()
	var visit_frame := _visual_frame(layer)
	layer._process(8.0)
	_check(layer._visit_dressing and layer.profile == "scraps" and layer._time == 0.0
		and not layer.is_processing() and layer.visible_budget() == 7
		and _visual_frame(layer) == visit_frame,
		"visit configure also respects the static frame without changing Event host policy")
	layer.retire()
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	layer._process(5.0)
	_check(layer.profile.is_empty() and not layer.visible and not layer.is_processing()
		and layer._time == 0.0 and not process_frame.is_connected(layer._sync_motion),
		"retirement removes clock and watcher and cannot resurrect on setting toggle")
	juice.fast_animations = false
	juice._sync()
	await _frames()
	_check(juice.ambient == layer and layer.is_visible_in_tree() and layer.is_processing()
		and layer.profile == AMBIENT.profile_for(roster._backdrop_kind, roster._backdrop_floor)
		and app.battle_view.find_children("LiveBattleAmbient", "Control", true, false).size() == 1
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"real host rebinds one renderer with one setting watcher and no added nodes")
	_check(_snapshot() == state and randi() == next_global
		and [layer.get_global_rect(), app.hero_view.get_global_rect(),
			juice.fast_button.get_global_rect()] == hit_rects
		and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE and layer.focus_mode == Control.FOCUS_NONE,
		"all motion lifecycle transitions preserve combat, RNG, hit rectangles and input policy")
	layer.fluff_texture = saved_added[0]
	layer.wisp_texture = saved_added[1]
	layer.vignette_texture = saved_added[2]
	layer.critter_strips = saved_strips


## The nonbattle entry point must retain the shipped image imports, and must
## never change a battle budget, consume RNG or maintain a retired observer.
func _visit_scraps_profile() -> void:
	var layer = AMBIENT.new()
	root.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	layer.size = Vector2(940, 620)
	_check(layer.profile.is_empty() and layer.get_child_count() == 0,
		"visit ambient is a single initially inert texture Control")
	var original := [layer.felt_texture, layer.light_texture, layer.fluff_texture,
		layer.wisp_texture, layer.vignette_texture]
	seed(81204)
	var next_random := randi()
	seed(81204)
	layer.configure_visit_scraps()
	_check(layer.profile == "scraps" and layer._visit_dressing and layer.fast
		and layer.visible_budget() == 7 and layer.motif_metadata().size() == 7
		and is_equal_approx(layer.self_modulate.a, 0.42)
		and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and layer.focus_mode == Control.FOCUS_NONE
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"reused visit entry point places seven muted marks with no input or emitter")
	for tex in [AMBIENT.FELT_PATH, AMBIENT.LIGHT_PATH, AMBIENT.FLUFF_PATH,
			AMBIENT.WISP_PATH]:
		_check(ResourceLoader.exists(tex, "Texture2D"), "shipped VFX import is reachable: " + tex)
	_textures(layer)
	layer._process(0.63)
	_check(layer._time > 0.0 and layer.motif_metadata()
		== AMBIENT.motifs_for("scraps", layer.size, layer._time, true),
		"visit profile uses only delta-based existing deterministic placements")
	layer.felt_texture = null
	layer.light_texture = null
	layer.fluff_texture = null
	layer.wisp_texture = null
	layer.vignette_texture = null
	layer.queue_redraw()
	await _frames()
	_check(layer.profile == "scraps" and layer.visible_budget() == 7
		and layer.motif_metadata().size() == 7 and layer.get_child_count() == 0
		and _particles(layer).is_empty(),
		"missing every optional texture draws nothing and preserves renderer contract")
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	layer._process(2.0)
	_check(layer._time == 0.0 and not layer.is_processing()
		and layer.profile == "scraps", "existing renderer holds a neutral frame under reduced motion")
	layer.retire()
	_check(layer.profile.is_empty() and layer._time == 0.0
		and not layer.is_processing() and not process_frame.is_connected(layer._sync_motion)
		and layer.get_child_count() == 0 and _particles(layer).is_empty(),
		"retiring a visit removes profile, time and frame watcher without emitter")
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	await _frames()
	_check(layer.profile.is_empty() and not layer.is_processing()
		and not process_frame.is_connected(layer._sync_motion),
		"motion-setting changes cannot resurrect a retired visit")
	for i in range(original.size()):
		match i:
			0: layer.felt_texture = original[i]
			1: layer.light_texture = original[i]
			2: layer.fluff_texture = original[i]
			3: layer.wisp_texture = original[i]
			4: layer.vignette_texture = original[i]
	layer.configure_visit_scraps()
	_check(layer.profile == "scraps" and layer._time == 0.0
		and layer.visible_budget() == 7 and layer.is_processing(),
		"independent rebind resets the reused visit clock")
	layer.retire()
	_check(randi() == next_random, "visit configuration, redrawing and teardown consume no global RNG")
	layer.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	had_motion_setting = ProjectSettings.has_setting("accessibility/reduced_motion")
	saved_motion_setting = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	_profiles()
	await _visit_scraps_profile()
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	juice = app.get_node_or_null("LiveCombatJuice")
	_check(is_instance_valid(juice) and is_instance_valid(juice.ambient),
		"app _ready owns one preconstructed atmosphere before any run")
	if not is_instance_valid(juice) or not is_instance_valid(juice.ambient):
		app.free()
		_finish()
		return
	var layer = juice.ambient
	_check(layer.get_parent() == juice and layer.profile.is_empty()
		and layer.visible_budget() == 0
		and layer.get_child_count() == 0 and _particles(layer).is_empty()
		and app.find_children("LiveBattleAmbient", "Control", true, false).size() == 1,
		"title has one parked inert texture-only atmosphere")
	for attempt in range(2):
		if not await _select_fight():
			_check(false, "physical Start and legal route button mount a real Fight")
			break
		await _frames()
		_check(juice.ambient == layer
			and layer.get_child_count() == 0 and _particles(layer).is_empty(),
			"fresh fight reuses the exact original texture-only layer")
		await _mounted()
		var old_battle = app.battle_view
		seed(70213)
		var return_sample := randi()
		seed(70213)
		app._return_to_title()
		await _frames()
		_check(app.deck == null and app.title_view.is_visible_in_tree()
			and juice.ambient == layer and layer.get_parent() == juice
			and layer.profile.is_empty()
			and layer.motif_metadata().is_empty() and layer.visible_budget() == 0
			and layer.added_metadata().is_empty()
			and not layer.is_processing() and layer._time == 0.0
			and not process_frame.is_connected(layer._sync_motion)
			and layer.get_child_count() == 0 and _particles(layer).is_empty()
			and not juice.bound and juice.overlay == null,
			"title retires all ambient texture drawing and the old battle binding")
		_check(not is_instance_valid(old_battle)
			and app.find_children("LiveBattleAmbient", "Control", true, false).size() == 1,
			"old battle is freed without an orphaned or duplicated ambient")
		_check(randi() == return_sample, "Return parks the layer without global RNG drift")
	app.free()
	_finish()


func _finish() -> void:
	if had_motion_setting:
		ProjectSettings.set_setting("accessibility/reduced_motion", saved_motion_setting)
	else:
		ProjectSettings.clear("accessibility/reduced_motion")
	if failures.is_empty():
		print("live_battle_ambient_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for reason in failures:
			printerr("FAIL: " + reason)
		printerr("live_battle_ambient_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
