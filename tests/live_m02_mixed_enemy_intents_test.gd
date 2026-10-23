extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _snapshot(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(), app.deck.energy,
		app.deck.turn_active, app.run_rng.state, app.enemy_intents._turn_index,
		app.enemy_attacks.duplicate(true), app.battle_result.get_outcome()]

func _set_actions(app, first: Dictionary, second: Dictionary) -> void:
	app.enemy_intents = CombatEnemyIntents.new([
		{"enemy_position": 2, "pattern": [second]}, {"enemy_position": 1, "pattern": [first]}])
	_check(app.enemy_intents.is_valid(), "otherwise valid late-action fixture")
	app.round_flow._intents = app.enemy_intents
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()


## The live hero meters the player sees: one Incoming line per presented slot.
func _incoming(app) -> Array:
	var texts: Array = []
	var presenter = app.get_node_or_null("LiveCombatMeters")
	if presenter == null or presenter.row == null or presenter.row.get_child_count() < CombatParty.PARTY_SIZE:
		return texts
	for index in range(CombatParty.PARTY_SIZE):
		var line = presenter.row.get_child(index).get_node_or_null("Padding/Content/IncomingForecast")
		texts.append("" if line == null else line.text)
	return texts

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/app.tscn").instantiate()
	app.starter_attacks_path = "res://data/encounters/m02_mixed_intents.json"
	root.add_child(app)
	await process_frame
	var replay: Array = []
	for session in range(2):
		app.run_seed = 54054
		_fixture_start(app)
		await process_frame
		_check(app.party != null and app.enemies != null and app.round_flow != null
			and app.deck.turn_active and app.end_turn_button.is_visible_in_tree(), "real mixed fight mounted")
		if app.party == null or app.deck == null:
			app.free()
			quit(1)
			return
		var definitions: Array = app._load_enemy_schedule()
		var scheduler := CombatEnemyIntents.new(definitions)
		_check(scheduler.is_valid(), "authored complete mixed pattern loads")
		var original := definitions.duplicate(true)
		definitions[0].pattern[0].direction = -1
		var reference := CombatEnemyIntents.new(original)
		for turn in range(11):
			_check(scheduler.get_intents() == reference.get_intents(), "entire timeline and wrap replay")
			var isolated := scheduler.get_intents()
			isolated[0].amount = 999
			_check(scheduler.get_intents() == reference.get_intents(), "announcements detached")
			scheduler.advance_turn()
			reference.advance_turn()
		var trace: Array = [_snapshot(app)]
		var warden: Dictionary = app.party._heroes[0]
		warden["metadata"] = {"retained": [1, 2]}
		warden["statuses"] = {"weak": 3}
		var expected_text := [
			"Intent: Enemy 1: Shove Hero 1 back; Enemy 2 -> Hero 1: Exposed 2",
			"Intent: Enemy 1: Buff +3 Block; Enemy 2 -> Hero 1 (Seamstress): 5 damage",
			"Intent: Enemy 1: 2 Block; Enemy 2 -> Hero 2: Bleed 2",
			"Intent: Enemy 1 -> Hero 3: Weak 2; Enemy 2 -> Hero 3 (Tinker): 4 damage",
			"Intent: Enemy 1: Shove Hero 2 front; Enemy 2: 1 Block"]
		var badges := [
			["H1 PUSH BACK", "EXPOSED 2 > H1"],
			["BUFF +3 BLK", "ATK 5 > H1"],
			["BLOCK +2", "BLEED 2 > H2"],
			["WEAK 2 > H3", "ATK 4 > H3"],
			["H2 PUSH FRONT", "BLOCK +1"]]
		# Committed HUD icon per presented source: shove keeps the sewn glyph, block uses
		# the authored defend art, and every other announced kind its own texture.
		var icons := [
			["", "res://assets/paper/ui/intent_debuff.png"],
			["res://assets/paper/ui/intent_buff.png", "res://assets/paper/ui/intent_attack.png"],
			["res://assets/paper/ui/intent_defend.png", "res://assets/paper/ui/intent_debuff.png"],
			["res://assets/paper/ui/intent_debuff.png", "res://assets/paper/ui/intent_attack.png"],
			["", "res://assets/paper/ui/intent_defend.png"]]
		for turn in range(5):
			app._refresh_intents()
			await process_frame
			_check(app.intent_label.text == expected_text[turn], "exact mounted mixed text")
			var presenter = app.get_node("LiveEnemyRoster")
			_check(presenter._badges.size() == 2, "two mounted source badges")
			var cues := CombatIntentCues.new().get_cues(app.enemy_intents, app.enemies)
			for index in range(2):
				var badge = presenter._badges[index]
				_check(badge.is_visible_in_tree() and badge.readable_text == badges[turn][index]
					and badge.icon_mode == cues[index].icon_key, "typed readable badge")
				_check(badge.icon_art_path() == icons[turn][index]
					and LiveEnemyIntentBadge.icon_path_for(cues[index].icon_key) == icons[turn][index],
					"committed HUD icon or sewn glyph matches the presented intent kind")
				_check(_icon_fits(badge, icons[turn][index]),
					"selected HUD art keeps its proportions inside the sewn icon area")
				_check(Rect2(0, 0, 1280, 720).encloses(badge.get_global_rect()), "badge fits viewport")
			_check(Rect2(0, 0, 1280, 720).encloses(app.end_turn_button.get_global_rect()), "End Turn fits viewport")
			await process_frame
			var incoming := _incoming(app)
			_check(incoming.size() == CombatParty.PARTY_SIZE
				and not incoming.has("Incoming: unavailable"),
				"mounted mixed kinds never fall back to unavailable: turn " + str(turn))
			if turn == 0:
				_check(incoming == ["Incoming: none", "Incoming: none", "Incoming: none"],
					"mounted shove and Exposed turn forecasts no hero attack damage")
			elif turn == 1:
				_check(incoming == ["Incoming: 0 Block, 7 HP", "Incoming: none", "Incoming: none"],
					"mounted buff and attack forecast the shove moved Exposed front hero only")
			elif turn == 3:
				_check(incoming == ["Incoming: none", "Incoming: none", "Incoming: 0 Block, 4 HP"],
					"mounted Weak and attack forecast the fixed back hero only")
			var before := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(app.enemy_intents._turn_index == turn + 1, "phase commits and advances once")
			var after := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == after, "duplicate dispatch inert")
			if turn == 0:
				_check(app.party.get_hero(1).id == "seamstress" and app.party.get_hero(1).get("statuses", {}) == {"exposed": 2}, "debuff binds new occupant after earlier shove")
				_check(is_same(app.party._heroes[1], warden) and warden.get("statuses", {}) == {"weak": 2}
					and warden.metadata == {"retained": [1, 2]}, "status and metadata follow original actor identity")
			if turn == 1:
				_check(app.enemies.get_enemy(1).block == 3 and app.party.get_hero(1).hp == before[0][0].hp - 7, "buff and Exposed attack resolve original base amount")
			if turn == 2:
				_check(app.party.get_hero(2).get("statuses", {}) == {"bleed": 2} and app.enemies.get_enemy(1).block == 5, "Bleed applies after owner tick; Block adds")
			trace.append(after)
			await process_frame
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "same seed full actors deck turn announcements RNG replay")
		app.return_button.pressed.emit()
		await process_frame
	await _badge_icons(app)
	await _rejections(app)
	app.free()
	for failure in failures:
		printerr(failure)
	print("live_m02_mixed_enemy_intents_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _rejections(app) -> void:
	for mode in ["late_shove", "late_debuff", "overflow", "status_overflow", "stale", "roster", "dead"]:
		_fixture_start(app)
		await process_frame
		_check(app.party != null and app.deck.turn_active, "negative fixture mounted active")
		var attack := {"type": "attack", "amount": 5, "target_position": 1}
		var debuff := {"type": "debuff", "amount": 1, "status": "weak", "target_position": 1}
		if mode == "late_shove":
			_set_actions(app, attack, {"type": "shove", "amount": 0, "target_position": 1, "direction": 1})
			app.party._heroes[1].hp = 0
		elif mode == "late_debuff":
			_set_actions(app, {"type": "attack", "amount": 999, "target_position": 1}, debuff)
		elif mode == "overflow":
			_set_actions(app, attack, {"type": "buff", "amount": 1})
			app.enemies._enemies[1].block = CombatEnemies.MAX_INT
		elif mode == "status_overflow":
			_set_actions(app, attack, debuff)
			app.party._heroes[0]["statuses"] = {"weak": CombatParty.MAX_INT}
			app.enemy_intents._definitions[0].pattern[0].amount = 2
			app.enemy_attacks = app.enemy_intents.get_intents()
		elif mode == "stale":
			app.enemy_attacks[0].direction = -1
		elif mode == "roster":
			app.enemies._enemies[1].position = 1
		elif mode == "dead":
			app.enemies._enemies[0].hp = 0
		var before := _snapshot(app)
		app.end_turn_button.pressed.emit()
		if mode == "dead":
			_check(app.party.get_hero(1).id == "warden" and app.party.get_hero(1).get("statuses", {}) == {"exposed": 2}
				and app.enemy_intents._turn_index == 1, "slain shove source inert; living debuff still acts")
		else:
			_check(_snapshot(app) == before and not app.end_turn_button.disabled, "full atomic rejection: " + mode)
		app.return_button.pressed.emit()
		await process_frame


## Presentation-only HUD icon transitions on the real mounted battle: every announced
## mode selects its own committed texture inside the sewn icon area, and shove,
## Unravelled, slain, an unknown action or unavailable art returns to a drawn glyph
## without ever showing the preceding action's texture. No combat state or RNG moves.
func _badge_icons(app) -> void:
	_fixture_start(app)
	await process_frame
	await process_frame
	var presenter = app.get_node_or_null("LiveEnemyRoster")
	_check(app.deck != null and app.enemy_intents != null and is_instance_valid(presenter)
		and presenter._badges.size() == 2, "icon transitions run on the real mounted battle")
	if app.deck == null or not is_instance_valid(presenter) or presenter._badges.size() != 2:
		return
	var badge = presenter._badges[0]
	var second = presenter._badges[1]
	# Real first announcement of this battle: shove source keeps the glyph, the debuff
	# source draws its committed art, with unchanged captions.
	_check(badge.icon_mode == "shove" and badge.readable_text == "H1 PUSH BACK"
		and _icon_fits(badge, ""), "real shove intent keeps the sewn glyph")
	_check(second.icon_mode == "debuff" and second.readable_text == "EXPOSED 2 > H1"
		and _icon_fits(second, "res://assets/paper/ui/intent_debuff.png"),
		"real debuff intent draws its committed HUD art")
	_check(LiveEnemyIntentBadge.icon_path_for("attack") == "res://assets/paper/ui/intent_attack.png"
		and LiveEnemyIntentBadge.icon_path_for("block") == "res://assets/paper/ui/intent_defend.png"
		and LiveEnemyIntentBadge.icon_path_for("buff") == "res://assets/paper/ui/intent_buff.png"
		and LiveEnemyIntentBadge.icon_path_for("debuff") == "res://assets/paper/ui/intent_debuff.png",
		"attack, block, buff and debuff map to their own committed HUD icons")
	_check(LiveEnemyIntentBadge.icon_path_for("shove").is_empty()
		and LiveEnemyIntentBadge.icon_path_for("unravelled").is_empty()
		and LiveEnemyIntentBadge.icon_path_for("slain").is_empty()
		and LiveEnemyIntentBadge.icon_path_for("none").is_empty()
		and LiveEnemyIntentBadge.icon_path_for("").is_empty()
		and LiveEnemyIntentBadge.icon_path_for("mystery").is_empty(),
		"shove, Unravelled, slain and unknown modes select no texture")
	var before := _snapshot(app)
	var paths := {"attack": "res://assets/paper/ui/intent_attack.png",
		"block": "res://assets/paper/ui/intent_defend.png",
		"buff": "res://assets/paper/ui/intent_buff.png",
		"debuff": "res://assets/paper/ui/intent_debuff.png"}
	var texts := {"attack": "ATK 5 > H2", "block": "BLOCK +3",
		"buff": "BUFF +2 BLK", "debuff": "WEAK 2 > H1"}
	for mode in ["attack", "block", "buff", "debuff"]:
		var action := _action_for(mode)
		var original := action.duplicate(true)
		badge.show_intent(action, false)
		_check(badge.icon_mode == mode and badge.intent_type == mode
			and badge.readable_text == texts[mode] and _icon_fits(badge, paths[mode]),
			"each announced mode selects its own committed HUD icon: " + mode)
		_check(action == original, "icon selection never mutates the copied announcement")
	var attack := _action_for("attack")
	# A textured action followed by every fallback mode must clear the old texture.
	badge.show_intent(attack, false)
	_check(_icon_fits(badge, paths["attack"]), "attack art binds before the fallback transitions")
	badge.show_intent({"type": "shove", "amount": 0, "target_position": 2, "direction": 1}, false)
	_check(badge.icon_mode == "shove" and badge.readable_text == "H2 PUSH BACK"
		and badge.amount == 0 and badge.target_position == 2 and _icon_fits(badge, ""),
		"shove clears the preceding HUD texture for its sewn glyph")
	badge.show_intent(attack, false)
	badge.show_intent(attack, false, true)
	_check(badge.icon_mode == "unravelled" and badge.readable_text == "UNRAVELLED"
		and badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0
		and _icon_fits(badge, ""), "Unravelled clears the preceding HUD texture")
	badge.show_intent(attack, false)
	badge.show_intent(attack, true)
	_check(badge.icon_mode == "slain" and badge.readable_text == "SLAIN"
		and badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0
		and _icon_fits(badge, ""), "slain clears the preceding HUD texture")
	badge.show_intent(attack, false)
	badge.show_intent({"type": "mystery", "amount": 4}, false)
	_check(badge.icon_mode == "none" and badge.readable_text == "NO ACTION"
		and _icon_fits(badge, ""), "unknown action clears the preceding HUD texture")
	# Unavailable art: the real fallback for an image or import the art pipeline has not
	# delivered. The authoritative text, amount and target stay exactly as announced.
	badge.show_intent(attack, false)
	var saved_root: String = badge.icon_root
	badge.icon_root = "res://assets/paper/ui/absent/"
	badge.show_intent(attack, false)
	_check(badge.icon_mode == "attack" and badge.readable_text == "ATK 5 > H2"
		and badge.amount == 5 and badge.target_position == 2 and _icon_fits(badge, ""),
		"unavailable icon art keeps the readable attack glyph and exact announcement")
	_check(LiveEnemyIntentBadge.load_icon_texture("res://assets/paper/ui/absent/intent_attack.png") == null
		and LiveEnemyIntentBadge.load_icon_texture("") == null,
		"missing or empty icon paths load no texture and cannot crash")
	badge.icon_root = saved_root
	badge.show_intent(attack, false)
	_check(_icon_fits(badge, paths["attack"]), "restoring the art root rebinds the committed icon")
	_check(_snapshot(app) == before, "every icon and glyph transition is presentation only")
	presenter._refresh()
	_check(_snapshot(app) == before and _icon_fits(badge, "")
		and _icon_fits(second, "res://assets/paper/ui/intent_debuff.png"),
		"a refresh restores the real announcements and their icons")
	# A real slain transition through the authoritative roster, then the mounted badge.
	_check(app.enemies.apply_damage(1, 999) and app.enemies.is_slain(1),
		"real damage transaction slays the announced source")
	var slain_state := _snapshot(app)
	presenter._refresh()
	_check(badge.icon_mode == "slain" and badge.readable_text == "SLAIN"
		and badge.icon_art_path().is_empty() and badge.icon_texture_rect() == Rect2()
		and badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0,
		"the slain source shows only its sewn glyph, never its preceding action art")
	_check(_snapshot(app) == slain_state, "slain badge presentation changes no state or RNG")
	_check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and badge.focus_mode == Control.FOCUS_NONE and badge.get_child_count() == 0,
		"the iconed badge takes no pointer or keyboard input and mounts no child control")
	# Source inspection: the icon draw is guarded by the retained drawn-glyph fallback.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_intent_badge.gd")
	var draw_body := _body(source, "func _draw() -> void:")
	var glyph_body := _body(source, "func _draw_glyph() -> void:")
	_check(draw_body.contains("icon_texture_rect()") and draw_body.contains("draw_texture_rect(")
		and draw_body.find("_draw_glyph()") > draw_body.find("draw_texture_rect("),
		"source draws the committed icon and keeps the drawn-glyph fallback")
	_check(glyph_body.contains("icon_mode == \"shove\"")
		and glyph_body.contains("elif icon_mode == \"unravelled\"")
		and glyph_body.contains("elif icon_mode == \"slain\""),
		"source retains readable sewn glyphs for shove, Unravelled and slain")
	app.return_button.pressed.emit()
	await process_frame


## One complete announcement per typed mode, used only for presentation transitions.
func _action_for(mode: String) -> Dictionary:
	if mode == "attack":
		return {"type": "attack", "amount": 5, "target_position": 2}
	if mode == "block":
		return {"type": "block", "amount": 3}
	if mode == "buff":
		return {"type": "buff", "amount": 2}
	if mode == "debuff":
		return {"type": "debuff", "amount": 2, "status": "weak", "target_position": 1}
	return {}


## A selected HUD texture fills the sewn icon area at its own proportions and stays
## inside the paper patch; the glyph fallback draws no texture at all.
func _icon_fits(badge, path: String) -> bool:
	var drawn: Rect2 = badge.icon_texture_rect()
	if path.is_empty():
		return badge.icon_texture == null and drawn == Rect2()
	if badge.icon_texture == null or badge.icon_art_path() != path:
		return false
	var pixels := Vector2(badge.icon_texture.get_width(), badge.icon_texture.get_height())
	return pixels.x > 0.0 and pixels.y > 0.0 \
		and drawn.size.x > 0.0 and drawn.size.y > 0.0 \
		and is_equal_approx(drawn.size.x / drawn.size.y, pixels.x / pixels.y) \
		and badge.icon_rect().grow(0.01).encloses(drawn) \
		and badge.patch_rect().grow(0.01).encloses(drawn)


## Source of one top-level badge method, up to the next method.
func _body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var body := source.substr(start)
	return body.left(body.find("\nfunc "))


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
	else:
		var started: bool = target._start_battle()
		_check(started == (target.deck != null), "standalone fixture reports admission consistently")
	if target.deck != null:
		var legacy := CombatEnemyIntents.new(target._load_enemy_schedule())
		_check(legacy.is_valid() and not legacy.is_bound(),
			"live M02 fixture explicitly reinstalls independent legacy schedule")
		target.enemy_intents = legacy
		target.round_flow._intents = legacy
		target.enemy_attacks = legacy.get_intents()
		target._refresh_intents()
