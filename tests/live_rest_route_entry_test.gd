extends "res://tests/live_legal_starter_fight_test.gd"
## Drive the shipped scene with physical inputs; recovery edge cases use combat fixtures.

const VISIT_ART := preload("res://scripts/live_enemy_roster.gd")


func _check_visit_actions(view: Control, actions: Array, captions: Array) -> void:
	_check(actions.size() == captions.size() and not actions.is_empty(),
		"live action audit has canonical buttons and expected captions")
	for index in range(actions.size()):
		var button: Button = actions[index]
		_check(is_instance_valid(button) and button.get_parent() == view
			and button.is_visible_in_tree() and button.text == captions[index],
			"canonical mounted action has exact caption: " + captions[index])
		_check(button.theme_type_variation == &"PatchHeadingButton"
			and button.get_theme_font_size("font_size") == 20
			and button.pressed.get_connections().size() == 1,
			"concise action keeps sewn heading skin, 20px font and one callback")


func _check_rest_actions() -> void:
	_check_visit_actions(app.rest_view, [app.rest_heal_button, app.rest_upgrade_button,
		app.rest_stitch_button, app.rest_stitch_guided_button, app.rest_patch_button,
		app.rest_continue_button, app.rest_back_button],
		["Heal", "Upgrade", "Stitch (3 scraps)", "Guided Stitch (3 scraps)",
		"Re-sew (1 scrap)", "Continue", "Return"])
	for button in [app.rest_heal_button, app.rest_upgrade_button,
			app.rest_stitch_button, app.rest_stitch_guided_button]:
		_check(button.tooltip_text.contains("Choose one: Heal, Upgrade or Stitch."),
			"Rest action explains the shared one-choice rule")
	var gallery = app.get_node("LiveVisitCardTiles")
	_check(gallery.is_gallery_mounted() and gallery.gallery_kind() == "Rest"
		and app.rest_upgrade_cards.item_count > 0
		and gallery.upgrade_tiles().size() == app.rest_upgrade_cards.item_count,
		"real Rest retains every canonical upgrade tile")
	var selector: OptionButton = app.rest_upgrade_cards
	_check(selector.is_visible_in_tree() and not selector.disabled
		and selector.modulate.a == 0.0 and selector.focus_mode == Control.FOCUS_NONE
		and selector.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Rest canonical upgrade selector stays masked and validated")
	_check(app.rest_stitch.is_valid() and not app.rest_heal_button.disabled
		and not app.rest_upgrade_button.disabled and app.rest_continue_button.disabled,
		"fresh Rest offers Heal and Upgrade and requires a choice before Continue")
	_check(app.rest_stitch_button.disabled == (app.run_scraps < 3)
		and app.rest_stitch_guided_button.disabled == (app.run_scraps < 3),
		"direct and guided Stitch availability follows the three-scrap wallet")
	var before := _rest_preview_state()
	var tiles: Array = gallery.upgrade_tiles()
	if not tiles.is_empty():
		tiles.back().grab_focus()
		await _key(KEY_TAB)
		_check(app.rest_upgrade_button.has_focus(),
			"Tab reaches canonical Upgrade from the last real upgrade tile")
	_check(_rest_preview_state() == before, "action and focus inspection spends nothing")


## AC2: the physical Rest visit displays its committed camp scene behind the same usable
## controls, with a cover crop and no pointer or keyboard capture.
func _check_rest_backdrop() -> int:
	var bed = app.visit_backdrop
	_check(is_instance_valid(bed) and bed.get_parent() == app
		and bed.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and bed.focus_mode == Control.FOCUS_NONE,
		"Rest visit mounts one inert full-screen art bed")
	if not is_instance_valid(bed):
		return 0
	var expected := "res://assets/paper/backgrounds/rest_camp.png"
	_check(VISIT_ART.visit_backdrop_path("Rest") == expected and bed.visit_kind == "Rest"
		and bed.has_image() == ResourceLoader.exists(expected)
		and (not bed.has_image() or bed.visit_texture.resource_path == expected),
		"Rest visit draws its own committed camp scene")
	_check(bed.get_index() < app.rest_view.get_index(),
		"Rest art bed is drawn behind the usable Rest controls")
	var view: Rect2 = bed.view_rect()
	_check(view.size.x > 0.0 and view.size.y > 0.0
		and Rect2(Vector2.ZERO, app.size).is_equal_approx(view)
		and Rect2(0, 0, 1280, 720).encloses(bed.get_global_rect()),
		"Rest art bed fills the whole 1280x720 visit, not one control box")
	var drawn: Rect2 = bed.image_rect()
	var visible: Rect2 = bed.image_crop()
	var pixels: Vector2 = bed.texture_size()
	_check(bed.has_image() and drawn.encloses(view)
		and is_equal_approx(drawn.size.x / drawn.size.y, pixels.x / pixels.y),
		"Rest camp scene covers the view without stretching")
	_check(visible.position.x >= 0.0 and visible.position.y >= 0.0
		and visible.end.x <= pixels.x + 0.01 and visible.end.y <= pixels.y + 0.01
		and is_equal_approx(visible.size.x * (drawn.size.x / pixels.x), view.size.x),
		"Rest camp scene crops only the centred window that fills the view")
	# Safe missing-art fallback: no image still leaves the opaque slate, never a crash.
	var missing = VISIT_ART.VisitBackdrop.new()
	root.add_child(missing)
	missing.bind_visit("Rest", VISIT_ART._load_art_texture(
		"res://assets/paper/backgrounds/fabricated_missing_camp.png"))
	_check(missing.view_rect().size.x > 0.0 and not missing.has_image()
		and missing.image_rect() == Rect2() and missing.image_crop() == Rect2()
		and missing.slate_color().a >= 1.0,
		"missing camp art keeps the opaque slate and draws no cover image")
	missing.free()
	_check(VISIT_ART.visit_backdrop_path("Unknown") == ""
		and app.visit_backdrop_texture("Unknown") == null
		and VISIT_ART.visit_backdrop_path("") == "",
		"an unknown visit kind selects no art and cannot crash")
	return bed.get_instance_id()


func _fixture() -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng := rng.state
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			var rest := false
			var unsupported := false
			for next in map.get_node(id).outgoing:
				rest = rest or map.get_node(next).type == "Rest"
				unsupported = unsupported or map.get_node(next).type not in ["Rest", "Shop", "Event", "Treasure"]
			if rest and unsupported:
				rng.state = opening_rng
				map.choose_node(id)
				var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
				if selected.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": id}
				map.undo_choice(id, [])
	return {}


func _persistent() -> Array:
	return [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
		app.run_rng.state, app.run_map.get_route(), _state()]


func _block_free_party() -> Array:
	var heroes: Array = app.party.get_heroes()
	for hero in heroes:
		hero.block = 0
	return heroes


func _rest_preview_state() -> Array:
	return [_persistent(), app.party_carryover.read_state(), app.rest_recovery._roster.duplicate(true),
		app.rest_recovery.is_consumed(), app.rest_upgrade.is_consumed(), app.rest_stitch.get_snapshot(),
		app.rest_stitch.is_consumed(), app._rest_committed_heroes.duplicate(true),
		app._rest_committed_deck.duplicate()]


func _check_rest_forecast() -> void:
	var before := _rest_preview_state()
	var oracle := RunRestHealPreview.preview(app.run_heroes)
	_check(oracle.ok and oracle.forecasts.size() == 3, "real eligible Rest has three oracle forecasts")
	var lines: PackedStringArray = app.rest_hp_label.text.split("\n")
	_check(lines.size() == oracle.forecasts.size(), "visible rows cover every forecast exactly once")
	if not oracle.ok or lines.size() != oracle.forecasts.size():
		return
	for index in range(oracle.forecasts.size()):
		var forecast: Dictionary = oracle.forecasts[index]
		var hero: Dictionary = oracle.heroes[index]
		var expected := "%s  %d/%d HP  -  " % [forecast.id.capitalize(), forecast.hp_before, hero.max_hp]
		if forecast.revived:
			expected += "Revive +%d to %d/%d" % [forecast.hp_delta, forecast.hp_after, hero.max_hp]
		elif forecast.hp_delta == 0:
			expected += "Full health"
		else:
			expected += "Heal +%d to %d/%d" % [forecast.hp_delta, forecast.hp_after, hero.max_hp]
		_check(lines[index] == expected, "visible current HP and compact service forecast match exactly")
	for repeat in range(3):
		app._refresh_rest_hp()
		_check(app.rest_hp_label.text.split("\n") == lines, "repeated preview remains fresh and identical")
	_check(_rest_preview_state() == before, "preview preserves models, ledger, services, RNG and choice eligibility")
	for control in [app.rest_view] + app.rest_view.get_children():
		if control is Control:
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "forecast and every Rest control fit viewport")
	_check(app.rest_hp_label.size.x >= app.rest_hp_label.get_minimum_size().x,
		"complete forecast text fits label without clipping")
	var ribbons := app.rest_view.get_node_or_null("RestPartyRibbons") as PanelContainer
	_check(ribbons != null and app.rest_hp_label.get_parent() == ribbons,
		"referenced live Label is mounted in the real left-rail sewn summary")
	if ribbons == null:
		return
	_check(ribbons.is_visible_in_tree() and app.rest_hp_label.is_visible_in_tree()
		and app.rest_hp_label.get_line_count() == 3,
		"exactly three hero status lines are visible")
	_check(ribbons.mouse_filter == Control.MOUSE_FILTER_IGNORE and ribbons.focus_mode == Control.FOCUS_NONE
		and app.rest_hp_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and app.rest_hp_label.focus_mode == Control.FOCUS_NONE,
		"summary and text cannot capture pointer or keyboard actions")
	var ink: Color = app.rest_hp_label.get_theme_color("font_color")
	var style: StyleBox = ribbons.get_theme_stylebox("panel")
	var backing := Color.TRANSPARENT
	if style is StyleBoxFlat:
		backing = style.bg_color
	var rows := ribbons.get_node("HeroRibbons") as VBoxContainer
	_check(rows != null and rows.get_child_count() == 3
		and rows.mouse_filter == Control.MOUSE_FILTER_IGNORE, "three inert sewn hero ribbons are mounted")
	for index in range(rows.get_child_count()):
		var row := rows.get_child(index) as NinePatchRect
		_check(row != null and row.get_meta("hero_id") == oracle.forecasts[index].id
			and row.mouse_filter == Control.MOUSE_FILTER_IGNORE and row.focus_mode == Control.FOCUS_NONE,
			"ribbon identities follow the service hero ordering without intercepting input")
		var art_path: String = ribbons.get_meta("art_path")
		_check((row.texture != null) == ResourceLoader.exists(art_path, "Texture2D")
			and (row.texture == null or row.texture.resource_path == art_path),
			"each hero ribbon reuses sewn nameplate art with an optional missing-art fallback")
		_check(row.modulate == backing and backing.a == 1.0,
			"ribbon tint and opaque backing bound the brightest possible fabric texel")
		_check(ribbons.get_global_rect().encloses(row.get_global_rect())
			and row.size.y >= app.rest_hp_label.get_theme_font("font").get_height(20),
			"each complete text line has its own compact ribbon inside the summary")
	_check(app.rest_hp_label.get_theme_font_size("font_size") >= 18
		and (ink.srgb_to_linear().get_luminance() + 0.05) / (backing.srgb_to_linear().get_luminance() + 0.05) >= 4.5,
		"large cream ink has high contrast against the dark sewn backing")
	_check(Rect2(0, 0, 1280, 720).encloses(app.rest_hp_label.get_global_rect())
		and ribbons.get_global_rect().encloses(app.rest_hp_label.get_global_rect())
		and app.rest_hp_label.size.y >= app.rest_hp_label.get_minimum_size().y,
		"all three complete hero lines fit the summary and viewport")
	for control in app.rest_view.get_children():
		if control is Control and control != ribbons and control.is_visible_in_tree():
			_check(not ribbons.get_global_rect().intersects(control.get_global_rect()),
				"summary leaves every selector and action unobscured")


func _check_rest_hp_only() -> void:
	var expected: PackedStringArray = []
	for hero in app.run_heroes:
		expected.append("%s  %d/%d HP" % [hero.id.capitalize(), hero.hp, hero.max_hp])
	_check(app.rest_hp_label.text == "\n".join(expected), "completed or rejected forecast shows current HP only")


func _routed_win(fixture: Dictionary, downed: bool, capped_survivor: bool = false) -> bool:
	app.run_seed = fixture.seed
	await _click(app.route_button)
	var fight: Button
	for button in app.route_buttons:
		if button.get_meta("route_id") == fixture.fight:
			fight = button
	_check(fight != null and not fight.disabled, "seeded opening Fight is a real enabled node")
	if fight == null:
		return false
	await _click(fight)
	_check(app.deck != null and app.party.is_valid(), "routed input mounts real combat")
	if app.deck == null:
		return false
	if downed:
		_check(app.party.apply_damage(3, 999) and app.party.is_downed(3), "fixture downs Tinker in actual combat")
		_check(app.party.apply_damage(2, 1) and not app.party.is_downed(2),
			"fixture wounds a living Seamstress for the numeric Heal forecast")
	var before := _persistent()
	app._continue_to_rest_route(null, weakref(app.run_map), null)
	_check(_persistent() == before and app.route_view == null, "active combat cannot continue or heal")
	for turn in range(20):
		if app._battle_closed:
			break
		if capped_survivor:
			_check(app.party.heal(2, 999), "fixture tops up living survivor before final card inputs")
			app.party._heroes[1].statuses = {"exposed": 2}
		for play in range(3):
			var id := ""
			var target := 0
			for held in app.deck.hand:
				# This recovery fixture needs its capped/status witness at the
				# final card action, before an owner-turn tick can change it.
				if capped_survivor and catalog.get_definition(held).effects.has("bleed"):
					continue
				var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, held)
				if preview.playable and preview.requires_selection:
					id = held
					target = preview.target_positions.back()
					break
			if id.is_empty():
				break
			if not await _choose(id, play % 2 == 1):
				return false
			await _key(KEY_1 if target == 1 else KEY_2)
			if app._battle_closed:
				break
		if app._battle_closed:
			break
		await _click(app.end_turn_button)
	var won: bool = app.battle_result.get_outcome() == CombatBattleResult.VICTORY
	_check(won and app.fight_rewards != null, "seeded routed fight wins using legal held-card inputs")
	return won and app.fight_rewards != null


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "actual seeded graph offers connected Rest and unsupported choices")
	if fixture.is_empty():
		_finish_rest()
		return
	var old_continue: Callable
	var old_route: Callable
	var old_heal: Callable
	var old_back: Callable
	var replay: Array = []
	var replay_forecast := ""
	for session in range(4):
		seed(380038)
		var global_next := randi()
		seed(380038)
		if not await _routed_win(fixture, session == 1):
			break
		_check(app.run_heroes == _block_free_party() and app.run_heroes.size() == 3,
			"routed victory saves complete independent three-hero run snapshot")
		var copy: Array = app.run_heroes.duplicate(true)
		var combat_copy: Array = app.party.get_heroes()
		_check(app.party.apply_damage(1, 1), "probe combat snapshot independence")
		_check(app.run_heroes == copy and app.party.get_heroes() != copy, "combat mutation cannot alias run heroes")
		app.party._heroes.assign(combat_copy)
		var before := _persistent()
		app._continue_to_rest_route(app.fight_rewards, weakref(app.run_map), null)
		_check(_persistent() == before and app.continue_button == null, "unclaimed reward offers no Continue")
		if session == 1:
			app.reward_buttons[3].grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(app.reward_buttons[0])
		_check(app.fight_reward_claimed and is_instance_valid(app.continue_button), "claim or Skip exposes Continue")
		if not is_instance_valid(app.continue_button):
			break
		copy = app.run_heroes.duplicate(true)
		_check(copy[2].max_hp == (23 if session == 1 else 26), "reward applies a tear only to newly downed Tinker")
		before = _persistent()
		for stale in [old_continue, old_route, old_heal, old_back]:
			if stale.is_valid():
				stale.call()
		_check(_persistent() == before and app.battle_view.visible, "old session callbacks preserve fresh victory")
		old_continue = app.continue_button.pressed.get_connections()[0].callable
		if session == 0:
			replay = before.duplicate(true)
		elif session == 2:
			_check(before == replay, "fresh routed restart deterministically replays complete victory state")
		app.fight_reward_claimed = false
		_check(app.fight_rewards != null and not app.fight_reward_claimed, "current routed service with unclaimed latch fixture")
		app._continue_to_rest_route(app.fight_rewards, weakref(app.run_map), app.continue_button)
		_check(_persistent() == before and app.route_view == null, "unclaimed reward rejects with current real Continue control")
		app.fight_reward_claimed = true
		app._continue_to_rest_route(app.fight_rewards, weakref(RunMap.new()), app.continue_button)
		_check(_persistent() == before and app.route_view == null, "wrong map identity cannot continue")
		# Invalid and defeated snapshots reject before mounting or advancing the map.
		for invalid in [[], [{"id": "bad"}], _defeated(copy)]:
			app.run_heroes = invalid.duplicate(true)
			var invalid_before := _persistent()
			old_continue.call()
			_check(_persistent() == invalid_before and app.route_view == null, "invalid/defeated run cannot enter Rest")
		app.run_heroes = copy.duplicate(true)
		var live_party: CombatParty = app.party
		for invalid_party in [CombatParty.new([]), _defeated_party()]:
			app.party = invalid_party
			var rejected_before := _persistent()
			old_continue.call()
			_check(_persistent() == rejected_before and app.route_view == null,
				"invalid/defeated combat party cannot leave Fight with enabled Continue")
		app.party = live_party
		if session == 0:
			await _click(app.continue_button)
		else:
			app.return_button.grab_focus()
			await _key(KEY_TAB)
			_check(app.continue_button.has_focus(), "Tab reaches Continue after claimed reward")
			await _key(KEY_ENTER)
		_check(app.route_view != null and not app.battle_view.visible, "Continue presents connected route")
		if app.route_view == null:
			break
		before = _persistent()
		old_continue.call()
		var rest: Button
		var shown: Array[String] = []
		for button in app.route_buttons:
			var id: String = button.get_meta("route_id")
			shown.append(id)
			_check(button.disabled == (app.run_map.get_node(id).type not in ["Rest", "Shop", "Event", "Treasure", "Fight", "Elite", "Boss"]), "only supported connected controls enabled")
			if button.disabled:
				await _click(button)
				button.grab_focus()
				await _key(KEY_ENTER)
				button.pressed.emit()
			elif app.run_map.get_node(id).type == "Rest":
				rest = button
		_check(shown == app.run_map.get_legal_choices(), "all and only real connected choices are shown")
		_check(rest != null and _persistent() == before, "disabled controls and duplicate Continue mutate nothing")
		if rest == null:
			break
		old_route = rest.pressed.get_connections()[0].callable
		old_back = app.route_back_button.pressed.get_connections()[0].callable
		var parent_id: String = app.run_map.get_current_node_id()
		var outgoing: Array = app.run_map._nodes[parent_id].outgoing.duplicate()
		app.run_map._nodes[parent_id].outgoing.erase(rest.get_meta("route_id"))
		old_route.call()
		_check(_persistent() == before and app.rest_view == null, "enabled mounted Rest revalidates legal connection at activation")
		app.run_map._nodes[parent_id].outgoing = outgoing
		app._choose_rest_route("f12_n0", weakref(app.run_map), app.run_map.get_route(), rest)
		app._choose_rest_route(rest.get_meta("route_id"), weakref(RunMap.new()), app.run_map.get_route(), rest)
		_check(_persistent() == before, "unconnected node and wrong-map callback are inert")
		if session == 2:
			await _click(app.route_back_button)
			old_route.call()
			old_continue.call()
			_check(app.title_view.visible and app.run_map == null and app.run_heroes.is_empty(), "route Back and stale callbacks clear run")
			continue
		var rest_id: String = rest.get_meta("route_id")
		# Two real visits with insufficient scraps, then a funded replay visit.
		if session == 3:
			app.run_scraps = 3
		if session == 0:
			await _click(rest)
		else:
			app.route_back_button.grab_focus()
			await _key(KEY_TAB)
			_check(root.gui_get_focus_owner() in app.route_buttons and not root.gui_get_focus_owner().disabled,
				"keyboard navigation skips disabled nodes")
			rest.grab_focus()
			await _key(KEY_ENTER)
		_check(app.rest_view != null and app.run_map.get_route() == [fixture.fight, rest_id], "Rest advances map exactly once")
		if app.rest_view == null:
			break
		var bed_id: int = _check_rest_backdrop()
		await _check_rest_actions()
		var heading := app.rest_view.get_node_or_null("RestTitle") as Label
		_check(heading != null and heading.text == "Rest camp - Floor %d" % app.run_map.get_node(rest_id).floor
			and not heading.text.contains(rest_id) and heading.is_visible_in_tree()
			and heading.theme_type_variation == &"PatchHeading", "real Rest has a player-facing themed camp title")
		_check_rest_forecast()
		if session == 0:
			replay_forecast = app.rest_hp_label.text
		elif session == 3:
			_check(app.rest_hp_label.text == replay_forecast, "returned run replays fresh identical forecasts")
		_check(app.rest_hp_label.text.contains("Revive") == (session == 1), "downed visit revives; fresh living visit has no stale revival")
		_check(RunRestHealPreview.preview(copy).forecasts[2].hp_delta == 0 if session != 1 else
			RunRestHealPreview.preview(copy).forecasts[2].revived, "mounted cases cover full-HP cap and downed recovery")
		_check(app.rest_hp_label.text.contains("Full health") if session != 1 else
			app.rest_hp_label.text.contains("Revive +"), "mounted full-health and revive cases use compact wording")
		if session == 1:
			_check(copy.any(func(hero): return hero.hp > 0 and hero.hp < hero.max_hp)
				and app.rest_hp_label.text.contains("Heal +"), "damaged living hero mounts a numeric Heal forecast")
		before = _persistent()
		old_route.call()
		old_back.call()
		old_continue.call()
		_check(_persistent() == before and app.rest_view.visible, "duplicate route and stale route Back are inert")
		var visit: RunRestRecovery = app.rest_recovery
		old_heal = app.rest_heal_button.pressed.get_connections()[0].callable
		var live_map: RunMap = app.run_map
		var replacement := RunMap.new()
		var replacement_rng := RandomNumberGenerator.new()
		replacement_rng.seed = fixture.seed
		replacement.generate(replacement_rng)
		_check(replacement.choose_node(fixture.fight) and replacement.choose_node(rest_id), "wrong map has otherwise identical valid Rest route")
		app.run_map = replacement
		var wrong_map_before := _persistent()
		app._refresh_rest_hp()
		_check_rest_hp_only()
		old_heal.call()
		_check(_persistent() == wrong_map_before and not visit.is_consumed(), "Heal rejects different map identity with identical route")
		app.run_map = live_map
		app._heal_at_rest(RunRestRecovery.new(copy), app.rest_heal_button)
		_check(_persistent() == before and not visit.is_consumed(), "wrong visit rejects without consumption")
		app.run_heroes = _defeated(copy)
		var invalid_before := _persistent()
		app._refresh_rest_hp()
		_check_rest_hp_only()
		old_heal.call()
		_check(_persistent() == invalid_before and not visit.is_consumed(), "changed defeated snapshot cannot heal")
		app.run_heroes = copy.duplicate(true)
		app._refresh_rest_hp()
		_check_rest_forecast()
		var expected_heal := RunRestRecovery.new(copy).choose_heal()
		_check(expected_heal.ok, "independent service oracle is valid")
		if "--inject-wrong-hp" in OS.get_cmdline_user_args():
			expected_heal.heroes[0].hp = -1
		if session == 0:
			await _click(app.rest_heal_button)
		else:
			app.rest_heal_button.grab_focus()
			await _key(KEY_ENTER)
		_check(visit.is_consumed() and app.rest_heal_button.disabled and app.run_heroes == expected_heal.heroes,
			"visible Heal commits service exact result once")
		_check(app.rest_upgrade_button.disabled and app.rest_stitch_button.disabled
			and app.rest_stitch_guided_button.disabled and not app.rest_continue_button.disabled,
			"consumed Rest disables competing choices and enables Continue")
		_check_rest_hp_only()
		app._refresh_rest_hp()
		_check_rest_hp_only()
		var ledger: Dictionary = app.party_carryover.read_state()
		_check(ledger.ok and ledger.heroes == expected_heal.heroes and ledger.completed_rests == [rest_id],
			"mounted Heal also commits exact heroes and current Rest once to persistent ledger")
		for index in range(3):
			var hero: Dictionary = app.run_heroes[index]
			_check(hero.hp == mini(hero.max_hp, (1 if copy[index].hp == 0 else copy[index].hp) + int(hero.max_hp * 0.3)), "exact capped 30% and revive arithmetic")
			_check(app.rest_hp_label.text.contains("%s  %d/%d HP" % [hero.id.capitalize(), hero.hp, hero.max_hp]), "on-screen persistent HP updated")
		_check(copy[2].hp == 0 if session == 1 else copy[2].hp == copy[2].max_hp, "fixture exercises downed revive or full-HP cap")
		var after := _persistent()
		_check(after.slice(1) == before.slice(1), "heal preserves inventory/gold/RNG/route and all combat state")
		old_heal.call()
		app.rest_heal_button.pressed.emit()
		_check(_persistent() == after, "duplicate Heal does not apply twice")
		old_back = app.rest_back_button.pressed.get_connections()[0].callable
		await _click(app.rest_back_button)
		for stale in [old_continue, old_route, old_heal, old_back]:
			stale.call()
		_check(app.title_view.visible and app.run_heroes.is_empty() and app.run_map == null
			and app.rest_recovery == null and app.rest_view == null and app.rest_hp_label == null
			and app.deck == null, "Return clears run and forecast and post-Return inputs are inert")
		_check(app.visit_backdrop == null and not is_instance_id_valid(bed_id),
			"Return releases the Rest art bed with its visit")
		_check(randi() == global_next, "entire route/rest path leaves global RNG unchanged")
	_check(app._start_battle(), "explicit standalone M01 fixture starts")
	await _frames()
	_check(app.deck != null and app.run_map == null and app.run_heroes.is_empty() and app.rest_recovery == null,
		"standalone M01 fixture remains independent after Rest Return")
	await _click(app.return_button)
	_finish_rest()


func _defeated(heroes: Array) -> Array:
	var result := heroes.duplicate(true)
	for hero in result:
		hero.hp = 0
	return result


func _defeated_party() -> CombatParty:
	var result := CombatParty.new(app._load_party_definitions())
	for position in [1, 2, 3]:
		result.apply_damage(position, 999)
	return result


func _finish_rest() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_route_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
