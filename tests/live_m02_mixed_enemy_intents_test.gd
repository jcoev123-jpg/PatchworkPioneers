extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

## Unticketed badge caption for one authoritative announcement.
func _badge_caption(action: Dictionary) -> String:
	var rank := {1: "Front", 2: "Middle", 3: "Back"}
	var target := int(action.get("target_position", 0))
	match String(action.get("type", "")):
		"attack":
			return "Hit %d: %s" % [int(action.get("amount", 0)), rank.get(target, "")]
		"block":
			return "Block +%d" % int(action.get("amount", 0))
		"buff":
			return "Buff +%d Block" % int(action.get("amount", 0))
		"debuff":
			return "%s %d: %s" % [String(action.get("status", "")).capitalize(),
				int(action.get("amount", 0)), rank.get(target, "")]
		"shove":
			return "Shove %s %s" % [rank.get(target, ""),
				"back" if int(action.get("direction", 0)) == 1 else "forward"]
	return ""


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
			["Shove Front back", "Exposed 2: Front"],
			["Buff +3 Block", "Hit 5: Front"],
			["Block +2", "Bleed 2: Middle"],
			["Weak 2: Back", "Hit 4: Back"],
			["Shove Middle forward", "Block +1"]]
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
	await _debuff_hovers(app)
	await _caption_readability(app)
	await _heading_fonts(app)
	await _policy_badges(app)
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
	_check(badge.icon_mode == "shove" and badge.readable_text == "Shove Front back"
		and _icon_fits(badge, ""), "real shove intent keeps the sewn glyph")
	_check(second.icon_mode == "debuff" and second.readable_text == "Exposed 2: Front"
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
	var texts := {"attack": "Hit 5: Middle", "block": "Block +3",
		"buff": "Buff +2 Block", "debuff": "Weak 2: Front"}
	var expected_tooltips := {
		"attack": "5 damage aimed at Hero 2 (middle).",
		"block": "3 Block on the acting enemy.",
		"buff": "2 Block on the acting enemy.",
		"debuff": "Weak 2 to Hero 1 (front) — for 2 turns, -25% outgoing attack damage; damage is rounded down, minimum 0."
	}
	for mode in ["attack", "block", "buff", "debuff"]:
		var action := _action_for(mode)
		var original := action.duplicate(true)
		badge.show_intent(action, false)
		_check(badge.icon_mode == mode and badge.intent_type == mode
			and badge.readable_text == texts[mode] and _icon_fits(badge, paths[mode]),
			"each announced mode selects its own committed HUD icon: " + mode)
		_check(action == original, "icon selection never mutates the copied announcement")
		_check(badge.tooltip_text == expected_tooltips[mode],
			"each announced mode formats its truthful hover explanation: " + mode)
	var attack := _action_for("attack")
	# A textured action followed by every fallback mode must clear the old texture.
	badge.show_intent(attack, false)
	_check(_icon_fits(badge, paths["attack"]), "attack art binds before the fallback transitions")
	badge.show_intent({"type": "shove", "amount": 0, "target_position": 2, "direction": 1}, false)
	_check(badge.icon_mode == "shove" and badge.readable_text == "Shove Middle back"
		and badge.amount == 0 and badge.target_position == 2 and _icon_fits(badge, ""),
		"shove clears the preceding HUD texture for its sewn glyph")
	_check(badge.tooltip_text == "Push back Hero 2 (middle).", "shove explains direction and target")
	badge.show_intent(attack, false)
	badge.show_intent(attack, false, true)
	_check(badge.icon_mode == "unravelled" and badge.readable_text == "UNRAVELLED"
		and badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0
		and _icon_fits(badge, ""), "Unravelled clears the preceding HUD texture")
	_check(badge.tooltip_text == "Unravelled: next action is skipped.", "Unravelled explains action is skipped")
	badge.show_intent(attack, false)
	badge.show_intent(attack, true)
	_check(badge.icon_mode == "slain" and badge.readable_text == "SLAIN"
		and badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0
		and _icon_fits(badge, ""), "slain clears the preceding HUD texture")
	_check(badge.tooltip_text == "Slain: no action.", "slain explains no action")
	badge.show_intent(attack, false)
	badge.show_intent({"type": "mystery", "amount": 4}, false)
	_check(badge.icon_mode == "none" and badge.readable_text == "NO ACTION"
		and _icon_fits(badge, ""), "unknown action clears the preceding HUD texture")
	_check(badge.tooltip_text == "No action.", "mystery resets tooltip to no action")
	# Unavailable art: the real fallback for an image or import the art pipeline has not
	# delivered. The authoritative text, amount and target stay exactly as announced.
	badge.show_intent(attack, false)
	var saved_root: String = badge.icon_root
	badge.icon_root = "res://assets/paper/ui/absent/"
	badge.show_intent(attack, false)
	_check(badge.icon_mode == "attack" and badge.readable_text == "Hit 5: Middle"
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
	_check(badge.tooltip_text == "Slain: no action.", "mounted slain badge shows truthful hover text")
	_check(badge.mouse_filter == Control.MOUSE_FILTER_PASS
		and badge.focus_mode == Control.FOCUS_NONE and badge.get_child_count() == 0,
		"the iconed badge takes safe hover filter, no focus, and mounts no child control")
	var hover_motion := InputEventMouseMotion.new()
	hover_motion.position = badge.get_global_rect().get_center()
	root.push_input(hover_motion, true)
	var click_press := InputEventMouseButton.new()
	click_press.button_index = MOUSE_BUTTON_LEFT
	click_press.position = hover_motion.position
	click_press.pressed = true
	root.push_input(click_press, true)
	var click_release := InputEventMouseButton.new()
	click_release.button_index = MOUSE_BUTTON_LEFT
	click_release.position = hover_motion.position
	click_release.pressed = false
	root.push_input(click_release, true)
	await process_frame
	_check(_snapshot(app) == slain_state, "pointer hover and click on badge cannot mutate combat state or RNG")
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


## Cycle 199: the three authored enemy debuffs explain their real rule on the hover of the
## badge the player sees in the battle. Every announcement is a copied presentation input:
## captions, amounts, targets and icons stay exactly as announced, and no combat state,
## scheduler or RNG value moves.
func _debuff_hovers(app) -> void:
	_fixture_start(app)
	await process_frame
	await process_frame
	var presenter = app.get_node_or_null("LiveEnemyRoster")
	_check(app.deck != null and app.enemy_intents != null and is_instance_valid(presenter)
		and presenter._badges.size() == 2, "debuff hover checks run on the real mounted battle")
	if app.deck == null or not is_instance_valid(presenter) or presenter._badges.size() != 2:
		return
	var before := _snapshot(app)
	var badge = presenter._badges[0]
	# Independent expectations, written from the design rules rather than the presenter:
	# Bleed bypasses Block and decrements 2 to 1; Weak is -25% outgoing for 2 turns;
	# Exposed is +50% incoming for 1 turn; both round damage down to a minimum of 0.
	var cases := [
		[{"type": "debuff", "amount": 2, "status": "bleed", "target_position": 1},
			"Bleed 2: Front",
			"Bleed 2 to Hero 1 (front) — that hero loses 2 HP at its turn end, ignoring Block; Bleed then decreases by 1 (from 2 to 1)."],
		[{"type": "debuff", "amount": 2, "status": "weak", "target_position": 1},
			"Weak 2: Front",
			"Weak 2 to Hero 1 (front) — for 2 turns, -25% outgoing attack damage; damage is rounded down, minimum 0."],
		[{"type": "debuff", "amount": 1, "status": "exposed", "target_position": 2},
			"Exposed 1: Middle",
			"Exposed 1 to Hero 2 (middle) — for 1 turn, +50% incoming attack damage; damage is rounded down, minimum 0."]]
	for row in cases:
		var action: Dictionary = row[0]
		var original := action.duplicate(true)
		badge.show_intent(action, false)
		_check(badge.is_visible_in_tree() and badge.intent_type == "debuff"
			and badge.readable_text == row[1] and badge.amount == action.amount
			and badge.target_position == action.target_position
			and badge.policy_cue.is_empty()
			and _icon_fits(badge, "res://assets/paper/ui/intent_debuff.png"),
			"mounted debuff keeps its exact caption, amount, target and icon: " + row[1])
		_check(badge.tooltip_text == row[2],
			"mounted debuff hover explains its authored rule: " + row[1])
		_check(action == original, "debuff hover never mutates the copied announcement: " + row[1])
	# Each rule carries the numbers the player needs, not just a generic sentence.
	badge.show_intent(cases[0][0], false)
	var bleed_tip: String = badge.tooltip_text
	_check(bleed_tip.contains("Hero 1 (front)") and bleed_tip.contains("2 HP")
		and bleed_tip.contains("turn end") and bleed_tip.contains("ignoring Block")
		and bleed_tip.contains("decreases by 1") and bleed_tip.contains("from 2 to 1"),
		"Bleed hover names the hero, HP, turn end, Block bypass and the decrement")
	badge.show_intent(cases[1][0], false)
	_check(badge.tooltip_text.contains("Hero 1 (front)") and badge.tooltip_text.contains("2 turns")
		and badge.tooltip_text.contains("-25% outgoing attack damage")
		and badge.tooltip_text.contains("rounded down, minimum 0"),
		"Weak hover names the hero, duration, outgoing reduction and rounded damage")
	badge.show_intent(cases[2][0], false)
	_check(badge.tooltip_text.contains("Hero 2 (middle)") and badge.tooltip_text.contains("1 turn,")
		and badge.tooltip_text.contains("+50% incoming attack damage")
		and badge.tooltip_text.contains("rounded down, minimum 0"),
		"Exposed hover names the hero, duration, incoming increase and rounded damage")
	# A real target policy still appends its own explanation after the rule.
	var policy_bleed := {"type": "debuff", "amount": 2, "status": "bleed", "target_position": 1}
	var policy_original := policy_bleed.duplicate(true)
	badge.show_intent(policy_bleed, false, false, "front")
	_check(badge.tooltip_text == String(cases[0][2])
		+ "\nTarget policy (FRONT): picks the front living hero."
		and badge.policy_cue == "Front" and policy_bleed == policy_original
		and _caption_readable(badge),
		"a debuff hover keeps the readable rule and appends its target policy")
	# A status this badge does not describe keeps the neutral generic fallback.
	var unknown := {"type": "debuff", "amount": 3, "status": "snagged", "target_position": 2}
	var unknown_original := unknown.duplicate(true)
	badge.show_intent(unknown, false)
	_check(badge.readable_text == "Snagged 3: Middle" and badge.intent_type == "debuff"
		and badge.tooltip_text == "Snagged 3 to Hero 2 (middle)."
		and not badge.tooltip_text.contains("Block")
		and not badge.tooltip_text.contains("rounded down")
		and unknown == unknown_original,
		"an unknown status keeps the neutral generic hover")
	_check(_snapshot(app) == before, "every debuff hover explanation is presentation only")
	presenter._refresh()
	_check(_snapshot(app) == before and badge.readable_text == "Shove Front back"
		and badge.tooltip_text == "Push back Hero 1 (front)."
		and badge.policy_cue.is_empty() and _icon_fits(badge, ""),
		"a refresh restores the real announcement after the debuff hovers")
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


## One channel of relative luminance, for a real ink-to-backing contrast measurement.
func _channel(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


func _contrast(first: Color, second: Color) -> float:
	var high: float = maxf(0.2126 * _channel(first.r) + 0.7152 * _channel(first.g)
		+ 0.0722 * _channel(first.b), 0.2126 * _channel(second.r) + 0.7152 * _channel(second.g)
		+ 0.0722 * _channel(second.b))
	var low: float = minf(0.2126 * _channel(first.r) + 0.7152 * _channel(first.g)
		+ 0.0722 * _channel(first.b), 0.2126 * _channel(second.r) + 0.7152 * _channel(second.g)
		+ 0.0722 * _channel(second.b))
	return (high + 0.05) / (low + 0.05)


## A mounted caption is really readable: fitted text inside its dark plaque at a bounded
## size, high-contrast cream ink, and any target-policy cue as its own 13 px ticket beside
## it. Both sewn pieces are measured with the badge's own effective Font, never a guessed
## body face. A compact policy caption keeps a 14 px action floor instead of dropping to 11.
func _caption_readable(badge) -> bool:
	var font: Font = badge.caption_font()
	if font == null or badge.readable_text.is_empty():
		return false
	var size_px: int = badge.caption_font_size()
	var text: Rect2 = badge.caption_text_rect()
	var plaque: Rect2 = badge.caption_rect()
	var tag: Rect2 = badge.policy_rect()
	var floor_px: int = 14 if not badge.policy_cue.is_empty() \
		else LiveEnemyIntentBadge.CAPTION_MIN_FONT
	var fits: bool = size_px >= floor_px \
		and size_px <= LiveEnemyIntentBadge.CAPTION_MAX_FONT \
		and text.size.x > 0.0 and text.size.y > 0.0 \
		and is_equal_approx(text.size.x, font.get_string_size(badge.readable_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x) \
		and badge.caption_text_area().grow(0.01).encloses(text) \
		and plaque.grow(0.01).encloses(text) \
		and Rect2(Vector2.ZERO, badge.size).grow(0.01).encloses(plaque) \
		and plaque.position.x > badge.patch_rect().end.x \
		and _contrast(badge.caption_ink(), LiveEnemyIntentBadge.CAPTION_FILL) >= 7.0
	if not fits:
		return false
	if badge.policy_cue.is_empty():
		return tag == Rect2() and badge.policy_text_rect() == Rect2()
	var ticket_font: Font = badge.policy_font()
	if tag.size.x <= 0.0 or ticket_font == null or LiveEnemyIntentBadge.POLICY_FONT < 13:
		return false
	var policy_text: Rect2 = badge.policy_text_rect()
	return Rect2(Vector2.ZERO, badge.size).grow(0.01).encloses(tag) \
		and not text.intersects(tag) and not plaque.intersects(tag) \
		and tag.grow(0.01).encloses(policy_text) \
		and is_equal_approx(policy_text.size.x, ticket_font.get_string_size(badge.policy_cue,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LiveEnemyIntentBadge.POLICY_FONT).x) \
		and _contrast(LiveEnemyIntentBadge.POLICY_INK, LiveEnemyIntentBadge.POLICY_FILL) >= 4.5


## The two sewn pieces of one mounted badge are really bounded inside its intent band and
## never share pixels: the painted action text, its dark plaque and the separate rust ticket.
## Measured on the real 192x28 band, so a longer target-priority wording cannot quietly
## run under the ticket or out of the badge.
func _band_pieces_fit(badge) -> bool:
	var band := Rect2(Vector2.ZERO, badge.size).grow(0.01)
	var text: Rect2 = badge.caption_text_rect()
	var plaque: Rect2 = badge.caption_rect()
	var tag: Rect2 = badge.policy_rect()
	return text.size.x > 0.0 and tag.size.x > 0.0 and tag.size.y > 0.0 \
		and band.encloses(text) and band.encloses(plaque) and band.encloses(tag) \
		and not text.intersects(tag) and not plaque.intersects(tag) \
		and badge.caption_text_area().end.x <= tag.position.x


## The rust ticket is measured exactly as its own 13 px cue plus its felt padding, so the
## displayed target-priority wording is the one the drawing code really paints.
func _ticket_fits(badge, label: String) -> bool:
	var font: Font = badge.policy_font()
	var tag: Rect2 = badge.policy_rect()
	if font == null or tag.size.x <= 0.0 or tag.size.y <= 0.0 or badge.policy_cue != label:
		return false
	var text: Rect2 = badge.policy_text_rect()
	return is_equal_approx(text.size.x, font.get_string_size(label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LiveEnemyIntentBadge.POLICY_FONT).x) \
		and is_equal_approx(tag.size.x, text.size.x + LiveEnemyIntentBadge.POLICY_PAD * 2.0) \
		and tag.grow(0.01).encloses(text)


## Cycle 183: every mounted caption sits on its own dark sewn plaque in fitted cream ink,
## and a target-policy cue keeps a separate readable ticket instead of being painted across
## the caption. A long debuff, a long shove, a policy cue and unavailable icon art all stay
## inside the same intent band with the committed art or sewn glyph still visible, and no
## combat state, scheduler or RNG value moves.
func _caption_readability(app) -> void:
	_fixture_start(app)
	await process_frame
	await process_frame
	var presenter = app.get_node_or_null("LiveEnemyRoster")
	_check(app.deck != null and app.enemy_intents != null and is_instance_valid(presenter)
		and presenter._badges.size() == 2, "caption checks run on the real mounted battle")
	if app.deck == null or not is_instance_valid(presenter) or presenter._badges.size() != 2:
		return
	var before := _snapshot(app)
	var shove = presenter._badges[0]
	var debuff = presenter._badges[1]
	# The real first announcement: a shove with its sewn glyph and an Exposed debuff with
	# its committed art, both under the larger fitted caption on the dark plaque.
	_check(shove.readable_text == "Shove Front back" and _icon_fits(shove, "")
		and debuff.readable_text == "Exposed 2: Front"
		and _icon_fits(debuff, "res://assets/paper/ui/intent_debuff.png"),
		"real shove glyph and debuff art are mounted before the caption checks")
	_check(shove.caption_font_size() > 14 and debuff.caption_font_size() > 14
		and _caption_readable(shove) and _caption_readable(debuff),
		"both real captions use the larger bounded size on their dark plaques")
	_check(shove.policy_cue.is_empty() and shove.policy_rect() == Rect2()
		and debuff.policy_cue.is_empty() and debuff.policy_rect() == Rect2(),
		"the unbound live schedule announces no policy ticket of its own")
	# A long authoritative debuff beside a real policy: the compact action stays at its
	# 14 px floor or larger, never runs under the policy ticket and never leaves the band.
	var long_debuff := {"type": "debuff", "amount": 2, "status": "exposed", "target_position": 1}
	var original := long_debuff.duplicate(true)
	shove.show_intent(long_debuff, false, false, "exposed")
	_check(shove.readable_text == "Exposed 2 → 1" and shove.intent_type == "debuff"
		and shove.amount == 2 and shove.target_position == 1
		and shove.policy_cue == "Exposed" and long_debuff == original,
		"long debuff keeps its exact amount and destination in the compact policy caption")
	_check(_caption_readable(shove) and shove.caption_font_size() >= 14,
		"the long debuff caption and its policy cue both fit the same intent band")
	_check(shove.caption_rect().position.x > shove.patch_rect().end.x
		and not shove.caption_text_rect().intersects(shove.policy_rect())
		and not shove.caption_rect().intersects(shove.policy_rect())
		and shove.policy_rect().size.y <= shove.caption_area_rect().size.y,
		"the caption plaque and policy ticket stay distinguishable inside the same band")
	_check(_icon_fits(shove, "res://assets/paper/ui/intent_debuff.png"),
		"the long debuff keeps its committed icon art visible")
	# A long shove caption with the longest targeting cue, still inside the same band.
	shove.show_intent({"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
		false, false, "lowest_living_hp")
	_check(shove.readable_text == "Shove 3 forward" and shove.policy_cue == "Aim low HP"
		and shove.intent_type == "shove" and shove.target_position == 3
		and _caption_readable(shove) and _icon_fits(shove, ""),
		"a long shove caption fits beside its aiming ticket and keeps the sewn glyph")
	_check(_ticket_fits(shove, "Aim low HP"),
		"the mounted aiming ticket measures as its own bounded sewn piece")
	# The narrowest sewn band (one column of a three-enemy stage) still fits: the compact
	# action falls back to its tight measured form instead of crossing the ticket.
	var mounted_size: Vector2 = shove.size
	shove.size = Vector2(LiveEnemyIntentBadge.BADGE_WIDTH, LiveEnemyIntentBadge.BADGE_HEIGHT)
	shove.show_intent({"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
		false, false, "lowest_living_hp")
	_check(shove.readable_text == "Shove 3 fwd" and shove.caption_font_size() >= 14
		and _caption_readable(shove),
		"the narrowest sewn band falls back to the tight shove form without clipping")
	_check(_band_pieces_fit(shove) and _ticket_fits(shove, "Aim low HP"),
		"the narrow shove caption and aiming ticket stay bounded and disjoint at 192x28")
	# The longest authored debuff beside the longest ticket, in that same narrow band: the
	# measured ladder steps to its tight form, so amount and hero number stay whole.
	shove.show_intent({"type": "debuff", "amount": 2, "status": "exposed", "target_position": 1},
		false, false, "lowest_living_hp")
	_check(shove.readable_text == "Exposed 2→1" and shove.policy_cue == "Aim low HP"
		and shove.amount == 2 and shove.target_position == 1
		and _caption_readable(shove) and _band_pieces_fit(shove),
		"a long debuff keeps its exact amount and hero number at 192x28 beside the aiming ticket")
	_check(shove.tooltip_text.contains("Hero 1 (front)")
		and shove.tooltip_text.contains("aims at the living hero with the lowest current HP"),
		"the narrow debuff hover still names the hero and the current-HP aiming rule")
	shove.size = mounted_size
	# Unavailable icon art: the real missing-image fallback keeps the sewn glyph under the
	# same readable caption, plaque and policy ticket.
	var saved_root: String = shove.icon_root
	shove.icon_root = "res://assets/paper/ui/absent/"
	shove.show_intent(long_debuff, false, false, "front")
	_check(shove.icon_texture == null and _icon_fits(shove, "")
		and shove.readable_text == "Exposed 2 → 1" and shove.amount == 2
		and shove.target_position == 1 and shove.policy_cue == "Front"
		and _caption_readable(shove),
		"unavailable icon art keeps the sewn-glyph fallback under the readable caption")
	shove.icon_root = saved_root
	_check(_snapshot(app) == before,
		"every caption, plaque and policy transition is presentation only")
	presenter._refresh()
	_check(_snapshot(app) == before and shove.readable_text == "Shove Front back"
		and shove.policy_cue.is_empty() and _caption_readable(shove)
		and _icon_fits(shove, "")
		and _icon_fits(debuff, "res://assets/paper/ui/intent_debuff.png"),
		"a refresh restores the real announcements with their real icons and captions")
	app.return_button.pressed.emit()
	await process_frame


## AC1: the mounted sewn ticket takes the already-shipped PatchHeading display face for a
## short genuine attack, block or buff caption, keeps the readable body face for a phrase
## the display face cannot fit at the full short-action size, falls back to that body face
## when the display file is unavailable, and measures/paints each sewn piece with the one
## Font it really uses. Every transition stays presentation only: no combat state, tooltip
## rule or RNG value moves.
func _heading_fonts(app) -> void:
	_fixture_start(app)
	await process_frame
	await process_frame
	var presenter = app.get_node_or_null("LiveEnemyRoster")
	_check(app.deck != null and app.enemy_intents != null and is_instance_valid(presenter)
		and presenter._badges.size() == 2, "heading checks run on the real mounted battle")
	if app.deck == null or not is_instance_valid(presenter) or presenter._badges.size() != 2:
		return
	var before := _snapshot(app)
	var badge = presenter._badges[0]
	var mounted_size: Vector2 = badge.size
	var body: Font = badge.get_theme_default_font()
	var heading: Font = badge.heading_font()
	_check(body != null and heading != null and heading != body
		and badge.inherited_theme() != null
		and heading.resource_path == "res://assets/fonts/LondrinaSolid-Regular.ttf",
		"the mounted badge resolves the shipped PatchHeading face beside the body face")
	# A Theme with no authored PatchHeading, and a missing file, resolve no display face at
	# all instead of silently standing the body face in as a heading.
	var bare := Theme.new()
	bare.default_font = body
	_check(LiveEnemyIntentBadge.patch_heading_face(bare) == null
		and LiveEnemyIntentBadge.patch_heading_face(null) == null
		and LiveEnemyIntentBadge.load_heading_font("res://assets/fonts/absent.ttf") == null
		and LiveEnemyIntentBadge.load_heading_font("") == null,
		"a Theme without PatchHeading and a missing file resolve no display face")
	# Short genuine attack, block and buff announcements: the whole phrase fits the plaque
	# at the full short-action size in the display face, measured with that exact Font.
	var short_cases := [
		[{"type": "attack", "amount": 5, "target_position": 2}, "Hit 5: Middle"],
		[{"type": "block", "amount": 3}, "Block +3"],
		[{"type": "buff", "amount": 2}, "Buff +2 Block"]]
	for row in short_cases:
		var action: Dictionary = row[0]
		var original := action.duplicate(true)
		badge.show_intent(action, false)
		_check(badge.readable_text == row[1] and badge.caption_font() == heading
			and badge.caption_font_size() == LiveEnemyIntentBadge.CAPTION_MAX_FONT
			and is_equal_approx(badge.caption_text_rect().size.x, heading.get_string_size(row[1],
				HORIZONTAL_ALIGNMENT_LEFT, -1, badge.caption_font_size()).x)
			and _caption_readable(badge) and action == original,
			"short mounted caption measures and paints with the sewn display face: " + row[1])
	# A longer genuine phrase the display face cannot fit at that size keeps the readable
	# body face, still inside the same sewn plaque and above the bounded floor.
	badge.size = Vector2(LiveEnemyIntentBadge.BADGE_WIDTH, LiveEnemyIntentBadge.BADGE_HEIGHT)
	badge.show_intent({"type": "shove", "amount": 0, "target_position": 2, "direction": -1}, false)
	_check(badge.readable_text == "Shove Middle forward" and badge.caption_font() == body
		and badge.caption_font_size() > 14 and _caption_readable(badge),
		"a long authentic caption keeps the readable body face instead of a clipped heading")
	badge.size = mounted_size
	# A genuine weighted debuff with its separate ticket: both sewn pieces measure and paint
	# with one resolved face each, and the 13 px ticket never touches the fitted caption.
	badge.show_intent({"type": "debuff", "amount": 2, "status": "weak", "target_position": 1},
		false, false, "lowest_living_hp")
	var ticket_face: Font = badge.policy_font()
	_check(ticket_face == body and badge.policy_cue == "Aim low HP"
		and is_equal_approx(badge.policy_text_rect().size.x, ticket_face.get_string_size(
			"Aim low HP", HORIZONTAL_ALIGNMENT_LEFT, -1,
			LiveEnemyIntentBadge.POLICY_FONT).x)
		and is_equal_approx(badge.policy_rect().size.x, badge.policy_text_rect().size.x
			+ LiveEnemyIntentBadge.POLICY_PAD * 2.0)
		and not badge.caption_text_rect().intersects(badge.policy_rect())
		and _caption_readable(badge),
		"a weighted debuff ticket measures and paints with its one resolved face")
	# The resolver's shipped fallback is a real mounted Control too: a badge with no
	# PatchHeading Theme above it takes the committed Londrina file, and when that file is
	# unavailable it keeps the readable body face without losing the announcement.
	var saved_path: String = badge.heading_font_path
	var short_attack := {"type": "attack", "amount": 5, "target_position": 2}
	var bare_badge := LiveEnemyIntentBadge.new()
	bare_badge.size = Vector2(LiveEnemyIntentBadge.BADGE_WIDTH, LiveEnemyIntentBadge.BADGE_HEIGHT)
	root.add_child(bare_badge)
	await process_frame
	bare_badge.show_intent(short_attack, false)
	_check(bare_badge.inherited_theme() == null and bare_badge.get_theme_default_font() == body
		and bare_badge.heading_font() == heading and bare_badge.caption_font() == heading
		and bare_badge.readable_text == "Hit 5: Middle" and _caption_readable(bare_badge),
		"a badge without a mounted heading Theme takes the shipped display file")
	bare_badge.heading_font_path = "res://assets/fonts/absent.ttf"
	bare_badge.show_intent(short_attack, false)
	_check(bare_badge.heading_font() == null and bare_badge.caption_font() == body
		and bare_badge.policy_font() == body and bare_badge.readable_text == "Hit 5: Middle"
		and bare_badge.caption_font_size() > 0 and _caption_readable(bare_badge),
		"an unavailable heading face falls back to the readable body face")
	bare_badge.heading_font_path = saved_path
	bare_badge.show_intent(short_attack, false)
	_check(bare_badge.heading_font() == heading and bare_badge.caption_font() == heading
		and _caption_readable(bare_badge),
		"restoring the shipped face restores the display voice")
	bare_badge.free()
	# Source inspection: one effective Font is measured and painted in every caption path,
	# and the policy ticket keeps the same rule.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_intent_badge.gd")
	var face_body := _body(source, "func caption_font() -> Font:")
	var fit_body := _body(source, "func caption_font_size() -> int:")
	var text_body := _body(source, "func caption_text_rect() -> Rect2:")
	var compact_body := _body(source, "func _apply_compact_caption() -> void:")
	var draw_body := _body(source, "func _draw_caption() -> void:")
	var ticket_body := _body(source, "func policy_rect() -> Rect2:")
	var ticket_text_body := _body(source, "func policy_text_rect() -> Rect2:")
	_check(face_body.contains("heading_font()")
		and face_body.contains("get_theme_default_font()")
		and face_body.contains("get_string_size(")
		and fit_body.contains("caption_font()") and fit_body.contains("get_string_size(")
		and text_body.contains("caption_font()")
		and compact_body.contains("caption_font()")
		and draw_body.contains("caption_font()") and draw_body.contains("caption_font_size()")
		and draw_body.find("draw_string(font") >= 0,
		"source measures and paints the caption with one effective Font")
	_check(ticket_body.contains("policy_font()") and ticket_text_body.contains("policy_font()")
		and draw_body.contains("policy_font()")
		and draw_body.find("draw_string(policy") > draw_body.find("policy_font()"),
		"source measures and paints the policy ticket with one effective Font")
	_check(_snapshot(app) == before, "heading and fallback caption transitions are presentation only")
	presenter._refresh()
	_check(_snapshot(app) == before and _caption_readable(badge),
		"a refresh restores the real announcements after the heading checks")
	app.return_button.pressed.emit()
	await process_frame


## AC1/AC2: a genuine mounted weighted fight — the live admission's own bound scheduler
## on the real roster, party and run RNG — announces each authored target policy on its
## original enemy slot. The compact action keeps the exact amount, target and shove
## direction at 14 px or more beside a 13 px ticket, inside the same sewn intent band;
## the no-ticket block beside it keeps its full caption, and every hover still names the
## full target, amount and rule. Nothing here changes a rule, a roll or combat state.
func _policy_badges(app) -> void:
	_fixture_start(app)
	await process_frame
	await process_frame
	var presenter = app.get_node_or_null("LiveEnemyRoster")
	_check(app.deck != null and app.enemy_intents != null and app.round_flow != null
		and is_instance_valid(presenter) and presenter._badges.size() == 2,
		"policy badge checks run on the real mounted battle")
	if app.deck == null or not is_instance_valid(presenter) or presenter._badges.size() != 2:
		return
	var flow: CombatRoundFlow = app.round_flow
	var old_intents: CombatEnemyIntents = app.enemy_intents
	var old_unravel: CombatUnravel = flow._unravel
	var old_roster: Array[Dictionary] = app.enemies.get_enemies()
	var old_attacks: Array = app.enemy_attacks.duplicate(true)
	var old_rng: int = app.run_rng.state
	var before := _snapshot(app)
	# The battle's own gauge service, bound to this exact mounted roster: the same
	# authority the live attack preview shares with the round flow once a gauge card is
	# played, so the read-only policy path is the one the player really gets.
	var gauge := CombatUnravel.new()
	_check(gauge.bind_roster(app.enemies, {1: "normal", 2: "normal"}),
		"fixture binds the real mounted roster's own gauge service")
	flow._unravel = gauge
	# Representative attack, Weak, Exposed and shove announcements, one per authored
	# policy, with the independent short caption the player should read.
	var cases := [
		["front", {"type": "attack", "amount": 5}, "Hit 5 → %d", "damage aimed at"],
		["lowest_living_hp", {"type": "debuff", "amount": 2, "status": "weak"},
			"Weak 2 → %d", "-25% outgoing attack damage"],
		["exposed", {"type": "debuff", "amount": 2, "status": "exposed"},
			"Exposed 2 → %d", "+50% incoming attack damage"],
		["random", {"type": "shove", "amount": 0, "direction": 1}, "Shove %d back", "Push back"]]
	var full_block := ""
	for row in cases:
		var policy: String = row[0]
		var body: Dictionary = row[1].duplicate(true)
		body["weight"] = 1
		app.enemies._enemies[0]["intent"] = {"target": policy, "actions": [body]}
		# The unticketed source needs a genuine non-target action to show a full
		# caption beside the ticket: the Guard's own authored five Block binds as
		# one alternative, exactly like its real weighted Block choice.
		app.enemies._enemies[1]["intent"] = {"target": "front",
			"actions": [{"type": "block", "amount": 5, "weight": 1}]}
		var schedule := CombatEnemyIntents.new(old_intents._definitions.duplicate(true))
		_check(schedule.bind_battle(app.enemies, app.party, app.run_rng),
			"test-authored %s weighted schedule binds the real mounted roster" % policy)
		if not schedule.is_bound():
			continue
		app.enemy_intents = schedule
		flow._intents = schedule
		flow._battle_intents = schedule
		var cached: Array[Dictionary] = schedule.get_intents()
		app.enemy_attacks = cached
		var state_before: int = app.run_rng.state
		presenter._refresh()
		var badge = presenter._badges[0]
		var unticketed = presenter._badges[1]
		var announced: Dictionary = cached[0]
		var target: int = announced.get("target_position", 0)
		# The forced unticketed Guard alternative the mounted roster carries.
		var unticketed_action: Dictionary = {}
		for action in cached:
			if action.get("enemy_position") == 2:
				unticketed_action = action
		full_block = _badge_caption(unticketed_action)
		var label: String = LiveEnemyIntentBadge.POLICY_LABELS[policy]
		var expected := String(row[2]) % target
		var rule := String(row[3])
		if String(body["type"]) == "shove":
			var dir := "back" if int(announced.get("direction", 0)) == 1 else "forward"
			expected = "Shove %d %s" % [target, dir]
			rule = "Push %s" % ("back" if int(announced.get("direction", 0)) == 1 else "front")
		_check(presenter._bound_unravel(app) == gauge,
			"the mounted %s fight exposes its bound gauge and weighted scheduler" % policy)
		_check(schedule.is_bound() and announced.get("enemy_position") == 1
			and announced.get("type") == body["type"] and target in [1, 2, 3]
			and badge.is_visible_in_tree() and badge.policy_cue == label,
			"real weighted %s action announces its own mounted policy ticket" % policy)
		_check(badge.readable_text == expected and badge.intent_type == body["type"]
			and badge.amount == body["amount"] and badge.target_position == target,
			"compact %s caption keeps the exact amount and destination: %s" % [policy, expected])
		_check(_caption_readable(badge) and badge.caption_font_size() >= 14
			and LiveEnemyIntentBadge.POLICY_FONT >= 13
			and badge.caption_text_rect().size.y > 0.0
			and badge.policy_text_rect().size.y > 0.0,
			"compact %s action reads at 14 px or more beside a 13 px or larger ticket" % policy)
		_check(not badge.caption_text_rect().intersects(badge.policy_rect())
			and not badge.caption_rect().intersects(badge.policy_rect())
			and Rect2(Vector2.ZERO, badge.size).grow(0.01).encloses(badge.caption_rect())
			and Rect2(Vector2.ZERO, badge.size).grow(0.01).encloses(badge.policy_rect())
			and badge.policy_rect().end.x <= badge.caption_area_rect().end.x + 0.01,
			"compact %s caption, plaque and ticket stay disjoint inside the sewn band" % policy)
		_check(is_equal_approx(badge.size.y, LiveEnemyIntentBadge.BADGE_HEIGHT)
			and Rect2(0, 0, 1280, 720).encloses(badge.get_global_rect()),
			"compact %s badge keeps its mounted intent band inside the viewport" % policy)
		# The ticket changes only the displayed caption: the full hover still names the
		# exact target, amount, rule and policy. A shove announces direction and hero.
		var tip: String = badge.tooltip_text
		var mentions_amount: bool = body["type"] == "shove" or tip.contains(str(body.amount))
		_check(tip.contains(LiveEnemyIntentBadge.hero_target_label(target))
			and mentions_amount and tip.contains("Target policy (%s)" % label.to_upper())
			and tip.contains(rule),
			"compact %s caption keeps the full amount, target, rule and policy hover" % policy)
		# The block source beside it has no ticket, so it keeps its exact full caption.
		_check(unticketed.policy_cue.is_empty() and unticketed.policy_rect() == Rect2()
			and unticketed.readable_text == full_block and unticketed.caption_font_size() > 14
			and _caption_readable(unticketed),
			"the unticketed %s source keeps its full readable caption" % policy)
		for repeat in range(3):
			presenter._refresh()
		_check(schedule.get_intents() == cached and app.run_rng.state == state_before,
			"repeated %s policy presentation is scheduler and RNG inert" % policy)
	# Restore the real fixture exactly: roster metadata, authoritative scheduler, gauge,
	# announcements and RNG, with nothing left behind by the presentation checks.
	app.enemies._enemies.assign(old_roster.duplicate(true))
	app.enemy_intents = old_intents
	flow._intents = old_intents
	flow._battle_intents = old_intents
	flow._unravel = old_unravel
	app.enemy_attacks = old_attacks
	app.run_rng.state = old_rng
	presenter._refresh()
	_check(_snapshot(app) == before and app.enemy_intents == old_intents,
		"policy badge fixture restores roster, announcements, gauge and RNG exactly")
	app.return_button.pressed.emit()
	await process_frame


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
		preload("res://tests/legacy_card_app_fixture.gd").enable(target)
		target.start_run_requested.emit()
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
