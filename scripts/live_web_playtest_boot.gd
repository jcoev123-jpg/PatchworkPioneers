extends Node
## Opt-in exported-web fixtures. Ordinary startup never allocates a run or RNG.

const SCREENS := ["title", "base", "map", "battle", "reward", "shop", "rest", "event", "results"]
const GOLD := 100
const SCRAPS := 10
var preview_ready := false
var _busy := false
var _preview_map: WeakRef


## Preserve ordinary zero-wallet admission; authorize only this preview's map.
func has_opening_wallet(app) -> bool:
	var preview: bool = _preview_map != null and _preview_map.get_ref() == app.run_map
	return app.session_gold == (GOLD if preview else 0) and app.run_scraps == (SCRAPS if preview else 0)


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	var requested := screen_from_query(JavaScriptBridge.eval("window.location.search"))
	if requested.is_empty():
		return
	await get_tree().process_frame
	var app = get_tree().current_scene
	if app != null and app.scene_file_path == "res://scenes/app.tscn":
		await enter_preview(app, requested)


## Read only one exact allowlisted screen value; ambiguous duplicates fail closed.
func screen_from_query(query: Variant) -> String:
	if not query is String:
		return ""
	var found: Array[String] = []
	for field in query.trim_prefix("?").split("&"):
		var pair: PackedStringArray = field.split("=", true, 1)
		if pair[0].uri_decode() == "screen":
			found.append(pair[1].uri_decode() if pair.size() == 2 else "")
	return found[0] if found.size() == 1 and found[0] in SCREENS else ""


## Uses the same mounted controls/services as normal play; also runs without JS.
func enter_preview(app, screen: String) -> bool:
	if screen not in SCREENS or _busy or not is_instance_valid(app) \
		or not app.is_node_ready() or app.run_map != null or app.deck != null \
		or not _visible(app.title_view):
		return false
	_busy = true
	preview_ready = false
	if screen == "base":
		# The village preview mounts the real Base and allocates no run at all.
		app.base_button.pressed.emit()
		if not _visible(app.base_screen) or not app.base_screen.has_open_village():
			_busy = false
			return false
	elif screen != "title":
		app.run_seed = {"rest": 10, "shop": 14, "event": 6}.get(screen, 1)
		app.start_button.pressed.emit()
		if app.run_map == null or not _visible(app.route_view):
			_busy = false
			return false
		# Set before admission, so visit ledgers capture these authoritative values.
		app.session_gold = GOLD
		app.run_scraps = SCRAPS
		_preview_map = weakref(app.run_map)
		if screen != "map":
			var route: String = {"rest": "f01_n1", "shop": "f01_n3", "event": "f01_n1"}.get(screen, "f01_n0")
			for button in app.route_buttons:
				if button.get_meta("route_id") == route and not button.disabled:
					button.pressed.emit()
					break
		if screen in ["reward", "results"] and app.battle_result != null:
			if screen == "reward":
				for enemy in app.enemies.get_enemies():
					app.enemies.apply_damage(enemy.position, enemy.hp + enemy.block)
			else:
				for hero in app.party.get_heroes():
					app.party.apply_damage(hero.position, hero.hp + hero.block)
			app._observe_battle_result()
	if not _expected_view(app, screen):
		_busy = false
		return false
	# Web waits for actual submitted frames, not merely deferred layout callbacks.
	for frame in range(2):
		await get_tree().process_frame
		if OS.has_feature("web"):
			await RenderingServer.frame_post_draw
	if not is_instance_valid(app) or not _expected_view(app, screen):
		_busy = false
		return false
	preview_ready = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pioneersReady = true")
	_busy = false
	return true


func _visible(view) -> bool:
	return is_instance_valid(view) and view.is_inside_tree() and view.is_visible_in_tree()


func _expected_view(app, screen: String) -> bool:
	match screen:
		"title":
			return _visible(app.title_view) and app.run_map == null and app.deck == null
		"base":
			return _visible(app.base_screen) and app.base_screen.has_open_village() \
				and not _visible(app.title_view) and app.run_map == null \
				and app.deck == null and app.run_rng == null and app.run_deck.is_empty()
		"map":
			return _visible(app.route_view) and app.run_map != null and app.run_map.get_route().is_empty()
		"battle":
			return _visible(app.battle_view) and app.battle_result != null and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		"reward":
			return _visible(app.reward_choice_panel) and app.reward_choice_panel.has_open_rewards() \
				and app.battle_result.get_outcome() == CombatBattleResult.VICTORY and not app.fight_reward_claimed
		"results":
			return _visible(app.terminal_result_panel) and app.terminal_result_panel.has_open_result() \
				and app.battle_result.get_outcome() == CombatBattleResult.DEFEAT and app.reward_choice_panel == null
		"rest":
			return _visible(app.rest_view) and app.rest_recovery != null
		"shop":
			return _visible(app.shop_view) and app.shop_visit != null
		"event":
			return _visible(app.quiet_spool_panel) and app.quiet_spool_panel.has_open_event()
	return false
