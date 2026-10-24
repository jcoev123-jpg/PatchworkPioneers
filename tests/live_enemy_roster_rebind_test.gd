extends SceneTree
## Mounted presenter-only rebinding; battle routing remains outside this contract.

const ROSTER_ART := preload("res://scripts/live_enemy_roster.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _snapshot(app, models: Array, schedules: Array) -> Array:
	var result: Array = [app.party, app.party.get_heroes(), app.deck,
		app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.run_rng, app.run_rng.seed, app.run_rng.state,
		app.enemies, app.enemy_intents, app.enemy_attacks.duplicate(true), app.run_heroes.duplicate(true),
		app.run_deck.duplicate(), app.session_gold, app.battle_result, app.round_flow]
	for model in models:
		result.append(model.get_enemies())
	for schedule in schedules:
		result.append([schedule._definitions.duplicate(true), schedule._turn_index, schedule.get_intents()])
	result.append([app.run_map.get_floors(), app.run_map.get_route()] if app.run_map != null else null)
	return result


func _controls(presenter) -> Array:
	var result: Array = [presenter.battle_row, presenter.panel]
	result.append_array(presenter._labels)
	result.append_array(presenter._badges)
	return result


func _ids(controls: Array) -> Array:
	var result: Array = []
	for control in controls:
		result.append(control.get_instance_id())
	return result


func _detached(controls: Array) -> void:
	for control in controls:
		_check(is_instance_valid(control) and not control.is_inside_tree(),
			"old wrapper/panel/label/badge immediately detached")
	_check(controls[0].get_parent() == null and controls[1].get_parent() == null,
		"old wrapper and panel have no parent")


func _freed(ids: Array) -> void:
	for id in ids:
		_check(not is_instance_id_valid(id), "old presentation node freed after frame")


func _mounted(app, presenter) -> bool:
	var valid: bool = is_instance_valid(presenter.panel) and is_instance_valid(presenter.battle_row)
	_check(valid, "real roster wrapper and panel mounted")
	if not valid:
		return false
	var roster: Array = app.enemies.get_enemies()
	_check(presenter.enemies == app.enemies and presenter._heroes == app.hero_view,
		"presenter observes authoritative enemy and hero-row identities")
	_check(app.battle_view.find_children("BattleActorSides", "HBoxContainer", true, false).size() == 1
		and app.battle_view.find_children("EnemyRosterPanel", "PanelContainer", true, false).size() == 1,
		"exactly one wrapper and panel in the unchanged battle")
	_check(app.hero_view.get_parent() == presenter.battle_row and presenter.battle_row.get_child_count() == 2,
		"app-owned hero targets are one side of the wrapper")
	_assert_stage(app, presenter)
	var labels: Array = presenter.panel.find_children("EnemyState*", "Label", true, false)
	var badges: Array = presenter.panel.find_children("EnemyIntent*", "Control", true, false)
	var count_matches: bool = labels.size() == roster.size() and badges.size() == roster.size() \
		and presenter._labels.size() == roster.size() and presenter._badges.size() == roster.size()
	_check(count_matches, "exactly one label and badge for each replacement enemy")
	if not count_matches:
		return false
	var intents: Array = app.enemy_intents.get_intents()
	_check(intents.size() == roster.size(), "matching real scheduler supplies every replacement source")
	if intents.size() != roster.size():
		return false
	var meters = app.get_node("LiveCombatMeters").row
	_check(is_instance_valid(meters) and meters.get_child_count() == 3 + roster.size(),
		"replacement roster retains exactly its real hero and enemy meters")
	if not is_instance_valid(meters) or meters.get_child_count() != 3 + roster.size():
		return false
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		var label: Label = presenter._labels[index]
		var badge: LiveEnemyIntentBadge = presenter._badges[index]
		_check(label == labels[index] and label.is_visible_in_tree() and label.name == "EnemyState%d" % enemy.position
			and label.text == String(enemy.name),
			"replacement name tag has exact identity and position")
		var puppet := presenter.panel.find_child("EnemyPuppet%d" % enemy.position, true, false) as Control
		_check(is_instance_valid(puppet) and label.get_parent() == puppet
			and label.get_global_rect().is_equal_approx(puppet.get_global_rect())
			and label.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and label.focus_mode == Control.FOCUS_NONE,
			"target label is the pointer-inert aiming region over its own actor")
		var meter = meters.get_child(3 + index)
		_check(meter.is_visible_in_tree() and meter.hp_text.is_visible_in_tree()
			and meter.hp_text.text == "%d/%d" % [enemy.hp, enemy.max_hp]
			and meter.hp_bar.value == enemy.hp and meter.hp_bar.max_value == enemy.max_hp
			and meter.block_badge.visible == (enemy.block > 0)
			and meter.block_text.text == ("%d" % enemy.block if enemy.block > 0 else "")
			and meter.block_bar.value == enemy.block,
			"replacement meter displays exact authoritative HP and Block")
		var action: Dictionary = intents[index]
		_check(badge == badges[index] and badge.is_visible_in_tree()
			and badge.name == "EnemyIntent%d" % enemy.position and badge.source_position == enemy.position
			and action.enemy_position == enemy.position and badge.intent_type == "attack"
			and badge.amount == action.amount and badge.target_position == action.target_position
			and badge.readable_text == "Hit %d: %s" % [action.amount, {1: "Front", 2: "Middle", 3: "Back"}[action.target_position]],
			"replacement badge announces compatible authoritative source, amount and target")
		# Stable mounted contract: the whole sewn patch, not only the Control, sits clear of
		# the viewport's upper edge and above its own actor art, and stays pointer/focus inert.
		var badge_rect: Rect2 = badge.get_global_rect()
		var actor_rect: Rect2 = puppet.get_global_rect() if is_instance_valid(puppet) else Rect2()
		var art_rect: Rect2 = puppet.get_global_transform() * puppet.rest_drawn_rect()
		var clearance: float = maxf(ROSTER_ART.INTENT_ART_CLEARANCE,
			puppet.art_safety_inset() + ROSTER_ART.Puppet.RIM_RADIUS)
		var expected_top: float = maxf(actor_rect.position.y,
			maxf(ROSTER_ART.STAGE_INTENT_SAFE_MARGIN, art_rect.position.y - clearance - badge_rect.size.y))
		var patch_rect: Rect2 = Rect2(badge_rect.position + badge.patch_rect().position,
			badge.patch_rect().size)
		_check(badge.tooltip_text.contains("%d damage" % action.amount)
			and badge.tooltip_text.contains("Hero %d" % action.target_position)
			and not badge.tooltip_text.contains("Target policy"),
			"replacement badge exposes fresh intent tooltip without stale text")
		_check(is_instance_valid(puppet) and badge.is_visible_in_tree()
			and badge.mouse_filter == Control.MOUSE_FILTER_PASS
			and badge.focus_mode == Control.FOCUS_NONE
			and badge_rect.size.x >= badge.custom_minimum_size.x - 0.01
			and badge_rect.size.y >= badge.custom_minimum_size.y - 0.01
			and art_rect.has_area()
			and is_equal_approx(badge_rect.position.y, expected_top)
			and badge_rect.end.y <= art_rect.position.y + 0.01
			and actor_rect.grow(0.01).encloses(badge_rect)
			and Rect2(0, 0, 1280, 720).encloses(badge_rect),
			"replacement intent ticket belongs to its resting artwork inside its source slot")
		_check(badge_rect.grow(0.01).encloses(patch_rect)
			and patch_rect.end.y <= art_rect.position.y + 0.01
			and Rect2(0, 0, 1280, 720).encloses(patch_rect),
			"drawn intent patch is complete, not cut by the upper edge, and never covers actor art")
	return true


## The unboxed stage contract: one shared large actor height, no frames, one quilt backdrop.
func _assert_stage(app, presenter) -> void:
	_check(ROSTER_ART.STAGE_ACTOR_HEIGHT >= 180, "shared stage minimum is a large character height")
	_check(ROSTER_ART.STAGE_INTENT_BAND > 0.0 and ROSTER_ART.STAGE_INTENT_BAND < ROSTER_ART.STAGE_ACTOR_HEIGHT,
		"stage reserves only a small band above the art for the intent badge")
	_check(ROSTER_ART.STAGE_INTENT_SAFE_MARGIN > 0.0
		and ROSTER_ART.STAGE_INTENT_SAFE_MARGIN < ROSTER_ART.STAGE_INTENT_BAND,
		"intent band keeps a positive viewport-safe margin under the screen's upper edge")
	var hero_height := 0.0
	var enemy_height := 0.0
	for puppet in presenter._puppets:
		_check(puppet.custom_minimum_size.y == ROSTER_ART.STAGE_ACTOR_HEIGHT
			and puppet.size.y >= ROSTER_ART.STAGE_ACTOR_HEIGHT,
			"mounted puppet keeps the shared large stage height: " + puppet.name)
		if puppet.facing > 0.0:
			hero_height = puppet.size.y
		else:
			enemy_height = puppet.size.y
		var texture: Texture2D = puppet.current_texture()
		var global_art: Rect2 = puppet.get_global_transform() * puppet.rest_drawn_rect()
		var global_shadow: Rect2 = puppet.get_global_transform() * puppet.contact_shadow_rect()
		_check(global_art.has_area() and global_art.end.y >= 400.0 and global_art.end.y <= 440.0
			and absf(global_art.end.y - global_shadow.get_center().y) <= global_shadow.size.y
			and Rect2(0, 0, 1280, 720).encloses(global_art)
			and Rect2(0, 0, 1280, 720).encloses(global_shadow),
			"rebound art/fallback and fixed shadow share the near-meadow screen ground: " + puppet.name)
		if texture == null:
			_check(puppet.art_band().size.y >= 100.0,
				"art-missing actor keeps a large drawn fallback stage: " + puppet.name)
			continue
		var rect: Rect2 = puppet.image_rect()
		_check(rect.size.y >= 120.0 and rect.size.y <= puppet.art_band().size.y + 0.01,
			"shipped art fills the enlarged stage: " + puppet.name)
		_check(is_equal_approx(rect.size.x / rect.size.y,
			float(texture.get_width()) / float(texture.get_height())),
			"enlarged art keeps its own proportions: " + puppet.name)
		_check(rect.position.y >= ROSTER_ART.STAGE_INTENT_BAND - 0.01
			and rect.end.y <= puppet.size.y + 0.01,
			"enlarged art stays below the badge band and inside its stage slot: " + puppet.name)
	_check(hero_height >= 180.0 and enemy_height >= 180.0 and is_equal_approx(hero_height, enemy_height),
		"heroes and enemies share the same actual stage height")
	_check(app.hero_view.get_global_rect().end.x <= presenter.panel.get_global_rect().position.x
		and not app.hero_view.get_global_rect().intersects(presenter.panel.get_global_rect()),
		"heroes stay left of the enemy lineup")
	_check(presenter.panel.get_theme_stylebox("panel") is StyleBoxEmpty,
		"enemy roster draws no rectangular box")
	for slot in app.hero_panels:
		_check(slot.get_theme_stylebox("panel") is StyleBoxEmpty,
			"hero stage slot draws no rectangular box")
	_check(app.theme != null and app.theme.get_stylebox("panel", "PanelContainer") is StyleBoxFlat,
		"the shared theme keeps its framed panel for other screens")
	_check(is_instance_valid(presenter.backdrop) and presenter.backdrop.name == "BattleStageBackdrop"
		and presenter.backdrop.get_parent() == app.battle_view and presenter.backdrop.get_index() == 0
		and app.battle_view.find_children("BattleStageBackdrop", "Control", true, false).size() == 1,
		"exactly one quilt stage is drawn behind the actors")
	if not is_instance_valid(presenter.backdrop):
		return
	_check(presenter.backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and presenter.backdrop.focus_mode == Control.FOCUS_NONE,
		"quilt stage never takes pointer or keyboard input")
	var row: Rect2 = presenter.battle_row.get_global_rect()
	_check(presenter.backdrop.stage_rect().size.is_equal_approx(row.size)
		and presenter.backdrop.stage_rect().position.is_equal_approx(
			row.position - presenter.backdrop.get_global_rect().position),
		"quilt stage follows the real actor row")
	_check(presenter.battle_row.get_global_rect().end.y <= app.hand_view.get_global_rect().position.y,
		"quilt stage stays above the hand")
	for control in [presenter.battle_row, presenter.panel, app.hand_view,
			app.end_turn_button, app.return_button]:
		var rect: Rect2 = control.get_global_rect()
		_check(rect.size.x > 0.0 and rect.size.y > 0.0 and Rect2(0, 0, 1280, 720).encloses(rect),
			"large stage keeps this control unclipped at 1280x720: " + control.name)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var presenter = app.get_node("LiveEnemyRoster")
	_fixture_start(app)
	await process_frame
	await process_frame
	_check(app.deck != null and app.party != null and app.run_rng != null and app.enemies != null
		and is_instance_valid(presenter.panel), "Start Run constructs real battle and mounted presenter")
	if app.deck == null or app.enemies == null or not is_instance_valid(presenter.panel):
		app.free()
		_finish()
		return
	# The seeded starter fight is the real shipped-art battle this stage must present.
	_assert_stage(app, presenter)
	var seeded_art := 0
	for puppet in presenter._puppets:
		if puppet.current_texture() == null:
			continue
		seeded_art += 1
		_check(puppet.image_rect().size.y >= 180.0,
			"seeded battle draws shipped art at the full stage height: " + puppet.name)
	_check(seeded_art == presenter._puppets.size(), "every seeded actor really binds its shipped art")
	var first_backdrop_id: int = presenter.backdrop.get_instance_id() \
		if is_instance_valid(presenter.backdrop) else 0
	_check(first_backdrop_id != 0, "real seeded battle mounts the quilt stage")
	var battle = app.battle_view
	var heroes = app.hero_view
	var slots: Array = app.hero_panels.duplicate()
	var hero_parent = presenter._hero_parent
	var hero_index: int = presenter._hero_index
	var hero_flags: int = presenter._hero_flags
	var models: Array = [app.enemies]
	var schedules: Array = [app.enemy_intents]
	# Distinct same-count and larger models, with recognizably different stats and announcements.
	for count in [2, 3]:
		var definitions: Array = []
		var patterns: Array = []
		for index in range(count):
			definitions.append({"id": "rebound_%d_%d" % [count, index],
				"name": "New%d_%d" % [count, index], "max_hp": 20 + count + index, "art_path": "unused"})
			patterns.append({"enemy_position": index + 1, "pattern": [
				{"type": "attack", "amount": count + index, "target_position": index + 1},
				{"type": "attack", "amount": 10 + index, "target_position": 3 - index}]})
		var replacement := CombatEnemies.new(definitions)
		var schedule := CombatEnemyIntents.new(patterns)
		_check(replacement.is_valid() and schedule.is_valid(), "separately constructed valid replacement services")
		_check(schedule.advance_turn(), "exercise advanced announcement and preserve scheduler index")
		for position in range(1, count + 1):
			_check(replacement.apply_damage(position, position) and replacement.gain_block(position, position + 2),
				"replacement has distinct non-default HP/Block")
		models.append(replacement)
		schedules.append(schedule)
		var old := _controls(presenter)
		var old_ids := _ids(old)
		app.enemies = replacement
		app.enemy_intents = schedule
		var before := _snapshot(app, models, schedules)
		# Call the real app refresh hook before a frame to inspect immediate detachment.
		app._refresh_enemy_roster()
		_detached(old)
		_check(_snapshot(app, models, schedules) == before, "rebind preserves all old/new authoritative state")
		await process_frame
		await process_frame
		_freed(old_ids)
		_check(app.battle_view == battle and app.hero_view == heroes and app.hero_panels == slots,
			"two-to-two/two-to-three keeps battle and original app hero targets")
		if not _mounted(app, presenter):
			break
		var stable_ids := _ids(_controls(presenter))
		var stable_backdrop: int = presenter.backdrop.get_instance_id()
		for refresh in range(4):
			app._refresh_enemy_roster()
			await process_frame
		_check(_ids(_controls(presenter)) == stable_ids, "unchanged models preserve wrapper, panel, labels and badges")
		_check(is_instance_valid(presenter.backdrop) and presenter.backdrop.get_instance_id() == stable_backdrop
			and battle.find_children("BattleStageBackdrop", "Control", true, false).size() == 1,
			"repeated frame refresh never duplicates the quilt stage")
		_check(_snapshot(app, models, schedules) == before, "repeated frame refresh consumes no state or RNG")
		_mounted(app, presenter)
	# A different hero row on the same battle must also invalidate the fast path.
	var alternate := HBoxContainer.new()
	hero_parent.add_child(alternate)
	var old := _controls(presenter)
	var old_ids := _ids(old)
	app.hero_view = alternate
	var before := _snapshot(app, models, schedules)
	app._refresh_enemy_roster()
	_detached(old)
	_check(heroes.get_parent() == hero_parent and heroes.get_index() == hero_index
		and heroes.size_flags_horizontal == hero_flags and presenter._heroes == alternate,
		"hero-row replacement returns original app controls and binds new identity")
	app.hero_view = heroes
	app._refresh_enemy_roster()
	_check(alternate.get_parent() == hero_parent, "replaced hero row returned to its app-owned parent")
	alternate.queue_free()
	await process_frame
	_freed(old_ids)
	_check(_snapshot(app, models, schedules) == before, "hero-row rebinding is presentation only")
	_mounted(app, presenter)
	old = _controls(presenter)
	old_ids = _ids(old)
	var current_backdrop_id: int = presenter.backdrop.get_instance_id() \
		if is_instance_valid(presenter.backdrop) else 0
	var active_model = app.enemies
	app.enemies = null
	before = _snapshot(app, models, schedules)
	app._refresh_enemy_roster()
	_detached(old)
	_check(presenter.enemies == null and presenter.panel == null and presenter.battle_row == null
		and presenter._labels.is_empty() and presenter._badges.is_empty(), "null model clears stale roster")
	_check(presenter.backdrop == null and battle.find_children("BattleStageBackdrop", "Control", true, false).is_empty(),
		"null model clears the quilt stage with the roster")
	_check(heroes.get_parent() == hero_parent and heroes.get_index() == hero_index
		and heroes.size_flags_horizontal == hero_flags and app.hero_panels == slots,
		"null cleanup returns identical app-owned hero targets with original layout")
	await process_frame
	_freed(old_ids)
	_check(not is_instance_id_valid(current_backdrop_id), "cleared quilt stage is freed, not reused")
	_check(_snapshot(app, models, schedules) == before, "null observation preserves surviving services and RNG")
	_check(battle.find_children("BattleActorSides", "HBoxContainer", true, false).is_empty()
		and battle.find_children("EnemyRosterPanel", "PanelContainer", true, false).is_empty(), "null leaves no stale wrappers")
	app.enemies = active_model
	# Automatic _process observation remounts without a manual presenter call.
	await process_frame
	await process_frame
	_mounted(app, presenter)
	_check(is_instance_valid(presenter.backdrop) and presenter.backdrop.get_instance_id() != current_backdrop_id,
		"remount builds one fresh quilt stage instead of reusing the removed one")
	old_ids = _ids(_controls(presenter))
	var hero_id: int = heroes.get_instance_id()
	var returned_backdrop_id: int = presenter.backdrop.get_instance_id()
	app.return_button.pressed.emit()
	_check(presenter.enemies == null and presenter.panel == null and presenter.battle_row == null
		and presenter.backdrop == null, "return-to-title immediately clears rebound presentation and stage")
	await process_frame
	_freed(old_ids)
	_check(not is_instance_id_valid(returned_backdrop_id), "return frees the quilt stage")
	_check(not is_instance_id_valid(hero_id) and app.title_view.is_visible_in_tree(), "title frees app-owned old battle heroes")
	_fixture_start(app)
	await process_frame
	await process_frame
	_check(app.enemies != null and is_instance_valid(presenter.panel) and presenter.enemies == app.enemies
		and app.enemies != active_model and app.hero_view != null, "restart mounts fresh authoritative roster and heroes")
	_check(is_instance_valid(presenter.backdrop) and presenter.backdrop.get_parent() == app.battle_view
		and presenter.backdrop.get_index() == 0
		and app.battle_view.find_children("BattleStageBackdrop", "Control", true, false).size() == 1,
		"restart contains exactly one quilt stage, never a duplicated decoration")
	_assert_stage(app, presenter)
	_check(presenter._labels.size() == 2 and presenter._badges.size() == 2
		and presenter._labels[0].text == "Ragling", "restart contains original starter identities only")
	app.return_button.pressed.emit()
	await process_frame
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_roster_rebind_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
