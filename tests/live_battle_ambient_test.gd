extends SceneTree
## Visual-only stage profiles and mounted title/fight/return reuse. All RNG
## comparisons are against real authorities, never seeded cosmetic sampling.

const AMBIENT := preload("res://scripts/live_battle_ambient.gd")
var failures: Array[String] = []
var checks := 0
var app
var juice


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
	var fixed_lint = sample.lint
	var fixed_weather = sample.weather
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
			and sample.lint == fixed_lint and sample.weather == fixed_weather
			and sample.weather.seed == sample.PROFILE_SEEDS[row[2]]
			and sample.weather.emitting and sample.lint.emitting
			and sample.visible_budget() == sample.NORMAL_BUDGET,
			"each authored area configures distinct, pooled, fixed-seed web CPU weather")
		_geometry(sample, String(row[2]))
	for row in [["Fight", -1], ["Fight", 12], ["Elite", -1], ["Elite", 0],
			["Elite", 12], ["Boss", -1], ["Boss", 0], ["Boss", 11],
			["Boss", 13], ["Rest", 5], ["", 5]]:
		_check(AMBIENT.profile_for(row[0], row[1]).is_empty()
			and not sample.configure(row[0], row[1], false)
			and sample.profile.is_empty() and not sample.weather.emitting
			and not sample.lint.emitting and sample.visible_budget() == 0
			and sample.motif_metadata().is_empty() and not sample.visible,
			"invalid routed scene %s floor %d remains without ambience" % row)
	_check(randi() == next_random,
		"all six profile activations and rejected mappings avoid the global RNG")
	sample.retire()
	sample.free()


func _geometry(layer, family: String) -> void:
	var bounds := Vector2(1000, 300)
	var initial: Array = AMBIENT.motifs_for(family, bounds, 0.0, false)
	_check(initial.size() == 30 and layer.visible_budget() >= 25
		and layer.visible_budget() <= 40, "normal budget includes thirty actual silhouettes")
	_check(initial == AMBIENT.motifs_for(family, bounds, 0.0, false),
		"pure geometry and placement repeat exactly")
	for time in [0.0, 1.0, 30.0, 60.0, 119.99, 120.0, 100000.0]:
		var marks: Array = AMBIENT.motifs_for(family, bounds, time, false)
		_check(marks.size() == 30, "motion retains thirty drawn motifs")
		for i in range(marks.size()):
			var mark: Dictionary = marks[i]
			var vertices: PackedVector2Array = mark["vertices"]
			_check(vertices.size() >= 4 and vertices == AMBIENT.motif_geometry(family, i),
				"drawn motif uses the pure family silhouette")
			var rect := Rect2(vertices[0], Vector2.ZERO)
			for vertex in vertices:
				rect = rect.expand(vertex)
				_check(Rect2(Vector2.ZERO, bounds).has_point(mark["center"] + vertex),
					"whole moving motif stays inside the stage")
			_check(rect.size.x >= 6.0 and rect.size.x <= 14.0
				and rect.size.y >= 6.0 and rect.size.y <= 14.0,
				"felt silhouettes span six to fourteen pixels in both axes")
			_check(mark["color"] == Color(AMBIENT.PROFILE_COLORS[family], 0.72),
				"visible felt uses its area palette")
	var reduced: Array = AMBIENT.motifs_for(family, bounds, 0.0, true)
	_check(reduced.size() == 7 and reduced[0]["color"].a < initial[0]["color"].a,
		"Fast reduces actual shape count and opacity")
	var moving: Array = AMBIENT.motifs_for(family, bounds, 1.0, false)
	var fast_moving: Array = AMBIENT.motifs_for(family, bounds, 1.0, true)
	var normal_distance: float = initial[0]["center"].distance_to(moving[0]["center"])
	_check(normal_distance > 0.0 and normal_distance < 1.0
		and reduced[0]["center"].distance_to(fast_moving[0]["center"]) < normal_distance,
		"motion is slow and further reduced in Fast")
	_check(layer.get_child_count() == 2, "geometry creates no extra nodes")
	var detached: PackedVector2Array = initial[0]["vertices"]
	detached[0] = Vector2(9999, 9999)
	_check(AMBIENT.motif_geometry(family, 0)[0] != detached[0],
		"returned geometry cannot mutate subsequent draws")
	for other in AMBIENT.PROFILE_COLORS:
		if other != family:
			_check(AMBIENT.motif_geometry(family, 0) != AMBIENT.motif_geometry(other, 0),
				"each area has a distinct silhouette family")


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
		"one correctly sized ambient is immediately above the dim/vignette bed: index=%d/%d, size=%s, battle=%s" % [layer.get_index(), roster.backdrop.get_index(), layer.size, app.battle_view.size])
	var actor_branch: Node = roster.battle_row
	_check(is_instance_valid(actor_branch) and actor_branch.is_ancestor_of(app.hero_view),
		"real stage row contains the hero actors")
	while actor_branch.get_parent() != app.battle_view:
		actor_branch = actor_branch.get_parent()
	_check(layer.get_index() < actor_branch.get_index(),
		"light and edge vignette render behind both actor rows")
	_check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and layer.focus_mode == Control.FOCUS_NONE
		and layer.lint is CPUParticles2D and layer.weather is CPUParticles2D
		and layer.lint.texture == null and layer.weather.texture == null
		and layer.lint.use_fixed_seed and layer.weather.use_fixed_seed,
		"CPU emitters are texture-free, fixed-seed and incapable of taking input")
	_check(layer.lint.emitting and layer.weather.emitting
		and layer.visible_budget() <= 40 and layer.visible_budget() >= 25
		and layer.motif_metadata().size() == 30 and layer.get_child_count() == 2,
		"normal atmosphere is visibly active and within the particle budget")
	for mark in layer.motif_metadata():
		for vertex in mark["vertices"]:
			_check(Rect2(Vector2.ZERO, layer.size).has_point(mark["center"] + vertex),
				"real 1280x720 stage contains each complete felt silhouette")
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
	_check(_snapshot() == state and juice.history.size() == receipt_count
		and juice.flight_history.size() == flights and juice.live_cues() == cues,
		"repeated visual refresh consumes no party/deck/enemy/run state or gameplay cue")
	_check(randi() == global_sample, "refresh does not consume even Godot's global RNG")
	# Real mounted toggle: Fast changes only this same layer's budget and opacity.
	var original_lint = layer.lint
	var original_weather = layer.weather
	seed(58231)
	global_sample = randi()
	seed(58231)
	await _click(juice.fast_button)
	_check(juice.fast_animations and layer.fast
		and layer.lint == original_lint and layer.weather == original_weather
		and layer.visible_budget() <= 12 and layer.visible_budget() < layer.NORMAL_BUDGET
		and layer.motif_metadata().size() == 7 and layer.get_child_count() == 2
		and layer.weather.color.a < 0.4 and layer.lint.color.a < 0.3,
		"Fast uses the same emitters with less weather and dimmer intensity")
	_check(_snapshot() == state, "Fast does not change real combat or its seeded RNG")
	await _click(juice.fast_button)
	_check(not juice.fast_animations and not layer.fast
		and layer.visible_budget() <= 40 and layer.motif_metadata().size() == 30
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


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_profiles()
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
	var lint = layer.lint
	var weather = layer.weather
	_check(layer.get_parent() == juice and layer.profile.is_empty()
		and not lint.emitting and not weather.emitting
		and app.find_children("LiveBattleAmbient", "Control", true, false).size() == 1,
		"title has one parked inert atmosphere, no battle weather")
	for attempt in range(2):
		if not await _select_fight():
			_check(false, "physical Start and legal route button mount a real Fight")
			break
		await _frames()
		_check(juice.ambient == layer and layer.lint == lint and layer.weather == weather,
			"fresh fight reuses the exact original emission resources")
		await _mounted()
		var old_battle = app.battle_view
		seed(70213)
		var return_sample := randi()
		seed(70213)
		app._return_to_title()
		await _frames()
		_check(app.deck == null and app.title_view.is_visible_in_tree()
			and juice.ambient == layer and layer.get_parent() == juice
			and layer.profile.is_empty() and not lint.emitting and not weather.emitting
			and layer.motif_metadata().is_empty() and layer.visible_budget() == 0
			and not juice.bound and juice.overlay == null,
			"title retires all ambient emission and the old battle binding")
		_check(not is_instance_valid(old_battle)
			and app.find_children("LiveBattleAmbient", "Control", true, false).size() == 1,
			"old battle is freed without an orphaned or duplicated ambient")
		_check(randi() == return_sample, "Return parks pooled resources without global RNG drift")
	app.free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("live_battle_ambient_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for reason in failures:
			printerr("FAIL: " + reason)
		printerr("live_battle_ambient_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
